//
//  CollaborationManager.swift
//  Kairumo
//
//  線上多人即時協同管理器（第一階段 MVP：輕量 WebSocket Relay + 雙通道通訊架構）
//

import SwiftUI
import Foundation
import Combine
import CryptoKit

/// 協同成員權限角色
public enum CollaboratorRole: String, Codable {
    case owner = "owner"
    case editor = "editor"
    case viewer = "viewer"

    public var localizedKey: String {
        switch self {
        case .owner: return "role_owner"
        case .editor: return "role_editor"
        case .viewer: return "role_viewer"
        }
    }
}

/// 游標與筆尖懸停狀態
public struct PeerCursor: Codable, Equatable {
    public var x: CGFloat
    public var y: CGFloat
    public var isDrawing: Bool
    public var tool: String
    public var selectedId: String?

    public init(x: CGFloat, y: CGFloat, isDrawing: Bool = false, tool: String = "pen", selectedId: String? = nil) {
        self.x = x
        self.y = y
        self.isDrawing = isDrawing
        self.tool = tool
        self.selectedId = selectedId
    }
}

/// 協同成員資料模型
public struct CollaboratorPeer: Identifiable, Codable, Equatable {
    public var id: String { userId }
    public let userId: String
    public let userName: String
    public let userColor: String
    public var role: CollaboratorRole
    public var cursor: PeerCursor?
    public var selectedId: String?
    public var lastActive: Date

    public init(userId: String, userName: String, userColor: String, role: CollaboratorRole, cursor: PeerCursor? = nil, selectedId: String? = nil, lastActive: Date = Date()) {
        self.userId = userId
        self.userName = userName
        self.userColor = userColor
        self.role = role
        self.cursor = cursor
        self.selectedId = selectedId
        self.lastActive = lastActive
    }
}

/// 即時協同連線狀態
public enum CollaborationStatus: Equatable {
    case disconnected
    case connecting
    case connected(roomId: String)
    case reconnecting(attempt: Int, maxAttempts: Int)
}

/// 遠端接收到的 CRDT Oplog 事件
public struct RemoteOplogEvent {
    public let userId: String
    public let kind: String
    public let payload: [String: Any]
    public let lamport: UInt64

    public init(userId: String, kind: String, payload: [String: Any], lamport: UInt64 = 0) {
        self.userId = userId
        self.kind = kind
        self.payload = payload
        self.lamport = lamport
    }
}

/// 線上多人協同核心管理器
@MainActor
public class CollaborationManager: ObservableObject {
    public static let shared = CollaborationManager()

    public let oplogReceived = PassthroughSubject<RemoteOplogEvent, Never>()

    @Published public var status: CollaborationStatus = .disconnected
    @Published public var currentRoomId: String = ""
    @Published public var isHost: Bool = false
    @Published public var peers: [CollaboratorPeer] = []
    @Published public var latencyMs: Int = 18
    @Published public var serverAddress: String {
        didSet {
            UserDefaults.standard.set(serverAddress, forKey: "kairumo_relay_server_url")
        }
    }

    // MARK: - 端對端加密 (Zero-Knowledge E2EE)
    @Published public var roomKeyBase64: String? = nil
    private var roomKey: SymmetricKey? = nil

    // MARK: - 離線暫存佇列與自動斷線重連
    @Published public var queuedOplogCount: Int = 0
    private var offlineOplogQueue: [[String: Any]] = []
    private var reconnectAttempt: Int = 0
    private let maxReconnectAttempts: Int = 5
    private var reconnectTimer: Timer?
    private var userInitiatedDisconnect: Bool = false
    public var maxKnownLamport: UInt64 = 0

    public let currentUserId: String = UUID().uuidString
    public let myColorHex: String

    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var lastPresenceSentTime: TimeInterval = 0
    private let presenceThrottleInterval: TimeInterval = 0.033 // 30Hz 頻率節流

    public init() {
        let savedServer = UserDefaults.standard.string(forKey: "kairumo_relay_server_url")
        self.serverAddress = savedServer ?? "ws://127.0.0.1:9002"

        // 為當前使用者生成固定的辨識色彩
        let colors = ["#007AFF", "#34C759", "#AF52DE", "#FF9500", "#FF2D55", "#5856D6"]
        self.myColorHex = colors.randomElement() ?? "#007AFF"
    }

    // MARK: - 端對端加密輔助函式

    /// 生成或重設 256 位元端對端加密房間金鑰
    @discardableResult
    public func generateRoomKey() -> String {
        let key = SymmetricKey(size: .bits256)
        self.roomKey = key
        let b64 = key.withUnsafeBytes { Data($0).base64EncodedString() }
        self.roomKeyBase64 = b64
        return b64
    }

    /// 設定或解析端對端加密金鑰
    public func setRoomKey(base64: String?) {
        guard let b64 = base64?.trimmingCharacters(in: .whitespacesAndNewlines),
              !b64.isEmpty,
              let keyData = Data(base64Encoded: b64),
              keyData.count == 32 else {
            self.roomKey = nil
            self.roomKeyBase64 = nil
            return
        }
        self.roomKey = SymmetricKey(data: keyData)
        self.roomKeyBase64 = b64
    }

    /// 使用 AES-256-GCM 進行端對端硬體加速加密
    public func encryptPayload(_ payload: [String: Any]) -> (encryptedPayload: [String: Any], isEncrypted: Bool) {
        guard let key = roomKey,
              let data = try? JSONSerialization.data(withJSONObject: payload) else {
            return (payload, false)
        }

        do {
            let sealed = try AES.GCM.seal(data, using: key)
            if let combined = sealed.combined {
                let cipherBase64 = combined.base64EncodedString()
                return (["ciphertext": cipherBase64], true)
            }
        } catch {
            print("⚠️ E2EE 加密失敗: \(error.localizedDescription)")
        }
        return (payload, false)
    }

    /// 解密接收到的遠端端對端加密 Payload
    public func decryptPayload(_ payload: [String: Any], isEncrypted: Bool) -> [String: Any]? {
        if !isEncrypted { return payload }
        guard let key = roomKey,
              let cipherBase64 = payload["ciphertext"] as? String,
              let cipherData = Data(base64Encoded: cipherBase64) else {
            return payload
        }

        do {
            let box = try AES.GCM.SealedBox(combined: cipherData)
            let decryptedData = try AES.GCM.open(box, using: key)
            if let dict = try JSONSerialization.jsonObject(with: decryptedData) as? [String: Any] {
                return dict
            }
        } catch {
            print("⚠️ E2EE 解密失敗（可能金鑰不相符）: \(error.localizedDescription)")
        }
        return nil
    }

    /// 取得帶有 E2EE 金鑰的安全邀請連結
    public var encryptedInviteLink: String {
        guard !currentRoomId.isEmpty else { return "" }
        if let key = roomKeyBase64 {
            return "kairumo://collab?room=\(currentRoomId)#key=\(key)"
        }
        return "kairumo://collab?room=\(currentRoomId)"
    }

    // MARK: - 連線與房間管理

    /// 建立新協同房間（作為房主 Owner）
    public func createRoom(noteId: String? = nil) {
        let prefix = "kairumo"
        let randomCode = String(UUID().uuidString.prefix(6)).lowercased()
        let newRoomId = "\(prefix)-\(randomCode)"
        generateRoomKey()
        connect(roomId: newRoomId, asHost: true)
    }

    /// 加入既有協同房間
    public func joinRoom(roomId: String) {
        let cleaned = roomId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        if cleaned.contains("#") {
            let parts = cleaned.components(separatedBy: "#")
            let parsedRoomId = parts[0].replacingOccurrences(of: "kairumo://collab?room=", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            var keyStr = parts[1]
            if keyStr.starts(with: "key=") {
                keyStr = String(keyStr.dropFirst(4))
            }
            setRoomKey(base64: keyStr)
            connect(roomId: parsedRoomId, asHost: false)
        } else {
            connect(roomId: cleaned, asHost: false)
        }
    }

    /// 連線至中繼伺服器
    public func connect(roomId: String, asHost: Bool, isReconnecting: Bool = false) {
        userInitiatedDisconnect = false

        if !isReconnecting {
            disconnect(userInitiated: false)
            reconnectAttempt = 0
            self.currentRoomId = roomId
            self.isHost = asHost
            self.peers.removeAll()
            self.status = .connecting
        }

        guard let url = URL(string: serverAddress) else {
            print("❌ 無效的 WebSocket 伺服器網址: \(serverAddress)")
            self.status = .disconnected
            return
        }

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        self.webSocketTask = task
        task.resume()

        startListening()
        startPingTimer()

        // 發送 Join 申請
        let myName = AccountManager.shared.profile.displayName
        let roleStr = asHost ? "owner" : "editor"
        let joinPayload: [String: Any] = [
            "type": "join",
            "room_id": roomId,
            "user_id": currentUserId,
            "user_name": myName,
            "user_color": myColorHex,
            "role": roleStr
        ]
        sendJson(joinPayload)
    }

    /// 主動中斷連線
    public func disconnect(userInitiated: Bool = true) {
        if userInitiated {
            self.userInitiatedDisconnect = true
            self.reconnectTimer?.invalidate()
            self.reconnectTimer = nil
            self.reconnectAttempt = 0
            self.offlineOplogQueue.removeAll()
            self.queuedOplogCount = 0
            self.roomKey = nil
            self.roomKeyBase64 = nil
        }

        if case .connected(let rid) = status {
            let leavePayload: [String: Any] = [
                "type": "leave",
                "room_id": rid,
                "user_id": currentUserId
            ]
            sendJson(leavePayload)
        }

        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil

        self.status = .disconnected
        if userInitiated {
            self.currentRoomId = ""
            self.isHost = false
            self.peers.removeAll()
        }
    }

    /// 房主關閉房間（終止全體協同）
    public func closeRoom() {
        guard isHost, !currentRoomId.isEmpty else {
            disconnect()
            return
        }

        let closePayload: [String: Any] = [
            "type": "close_room",
            "room_id": currentRoomId,
            "user_id": currentUserId
        ]
        sendJson(closePayload)
        disconnect()
    }

    /// 排程自動重新連線（指數退避）
    private func scheduleReconnect() {
        guard !userInitiatedDisconnect, !currentRoomId.isEmpty else { return }
        if reconnectAttempt >= maxReconnectAttempts {
            print("❌ 已達到最大重連次數 (\(maxReconnectAttempts))")
            self.status = .disconnected
            return
        }

        reconnectAttempt += 1
        self.status = .reconnecting(attempt: reconnectAttempt, maxAttempts: maxReconnectAttempts)

        let delay = min(pow(2.0, Double(reconnectAttempt - 1)), 16.0)
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, !self.userInitiatedDisconnect, !self.currentRoomId.isEmpty else { return }
                self.connect(roomId: self.currentRoomId, asHost: self.isHost, isReconnecting: true)
            }
        }
    }

    /// 手動立即重連
    public func forceReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        reconnectAttempt = 0
        connect(roomId: currentRoomId, asHost: isHost, isReconnecting: true)
    }

    /// 清空並依序重發離線期間累積的 Oplog
    private func drainOfflineQueue() {
        guard case .connected = status else { return }
        let queue = offlineOplogQueue
        offlineOplogQueue.removeAll()
        queuedOplogCount = 0

        for msg in queue {
            sendJson(msg)
        }
    }

    /// 請求中繼伺服器補發指定時鐘之後的遺漏 Oplog
    public func requestCatchup() {
        guard case .connected(let rid) = status else { return }
        let msg: [String: Any] = [
            "type": "catchup",
            "room_id": rid,
            "last_lamport": maxKnownLamport
        ]
        sendJson(msg)
    }

    // MARK: - 暫態廣播 (Presence) 與 Oplog

    public var mySelectedId: String? = nil
    private var lastCursorLocation: (x: CGFloat, y: CGFloat) = (0, 0)

    /// 廣播本地游標與筆劃狀態（自動 30Hz 節流防溢流），並支援攜帶物件軟鎖定狀態
    public func broadcastCursor(x: CGFloat, y: CGFloat, isDrawing: Bool, tool: String, selectedId: String? = nil) {
        guard case .connected(let rid) = status else { return }

        lastCursorLocation = (x, y)
        if let sel = selectedId {
            mySelectedId = sel
        }

        let now = Date().timeIntervalSince1970
        guard now - lastPresenceSentTime >= presenceThrottleInterval else { return }
        lastPresenceSentTime = now

        var payload: [String: Any] = [
            "type": "presence",
            "room_id": rid,
            "user_id": currentUserId,
            "cursor": [
                "x": Float(x),
                "y": Float(y),
                "is_drawing": isDrawing,
                "tool": tool
            ]
        ]
        if let sel = mySelectedId {
            payload["selected_id"] = sel
        }
        sendJson(payload)
    }

    /// 立即廣播物件選取/軟鎖定狀態
    public func broadcastSelection(selectedId: String?) {
        self.mySelectedId = selectedId
        guard case .connected(let rid) = status else { return }

        var payload: [String: Any] = [
            "type": "presence",
            "room_id": rid,
            "user_id": currentUserId,
            "cursor": [
                "x": Float(lastCursorLocation.x),
                "y": Float(lastCursorLocation.y),
                "is_drawing": false,
                "tool": "select"
            ]
        ]
        if let sel = selectedId {
            payload["selected_id"] = sel
        }
        sendJson(payload)
    }

    /// 廣播持久化 CRDT 操作（落筆完成或物件增刪），支援 E2EE 硬體加速加密與離線佇列
    public func broadcastOplog(kind: String, payload: [String: Any], lamport: UInt64 = 1) {
        maxKnownLamport = max(maxKnownLamport, lamport)

        let (finalPayload, isEncrypted) = encryptPayload(payload)

        var msg: [String: Any] = [
            "type": "oplog",
            "room_id": currentRoomId,
            "user_id": currentUserId,
            "lamport": lamport,
            "kind": kind,
            "payload": finalPayload
        ]
        if isEncrypted {
            msg["encrypted"] = true
        }

        if case .connected = status {
            sendJson(msg)
        } else {
            offlineOplogQueue.append(msg)
            queuedOplogCount = offlineOplogQueue.count
        }
    }

    /// 廣播附件新增或更新 (Text, Image, 3D)
    public func broadcastAttachmentUpsert(type: String, itemDict: [String: Any]) {
        let payload: [String: Any] = [
            "attachment_type": type,
            "item": itemDict
        ]
        broadcastOplog(kind: "attachment_upsert", payload: payload)
    }

    /// 廣播附件刪除
    public func broadcastAttachmentDelete(id: String, type: String) {
        let payload: [String: Any] = [
            "id": id,
            "attachment_type": type
        ]
        broadcastOplog(kind: "attachment_delete", payload: payload)
    }

    /// 廣播討論圖釘新增或回覆
    public func broadcastCommentUpsert(pinDict: [String: Any]) {
        broadcastOplog(kind: "comment_upsert", payload: ["pin": pinDict])
    }

    /// 廣播討論圖釘狀態切換 (已解決 / 重新開啟)
    public func broadcastCommentResolve(pinId: String, isResolved: Bool) {
        broadcastOplog(kind: "comment_resolve", payload: [
            "pin_id": pinId,
            "is_resolved": isResolved
        ])
    }

    /// 廣播討論圖釘刪除
    public func broadcastCommentDelete(pinId: String) {
        broadcastOplog(kind: "comment_delete", payload: ["pin_id": pinId])
    }

    // MARK: - 內部接收與心跳機制

    private func sendJson(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let jsonStr = String(data: data, encoding: .utf8) else { return }

        let message = URLSessionWebSocketTask.Message.string(jsonStr)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("⚠️ WebSocket 傳送失敗: \(error.localizedDescription)")
            }
        }
    }

    private func startListening() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.handleIncomingMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleIncomingMessage(text)
                        }
                    @unknown default:
                        break
                    }
                    // 繼續持續監聽下一則訊息
                    self.startListening()

                case .failure(let error):
                    print("⚠️ WebSocket 接收中斷: \(error.localizedDescription)")
                    if !self.userInitiatedDisconnect {
                        self.scheduleReconnect()
                    } else {
                        self.status = .disconnected
                    }
                }
            }
        }
    }

    private func handleIncomingMessage(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "joined":
            if let rid = json["room_id"] as? String {
                self.status = .connected(roomId: rid)
                self.reconnectAttempt = 0
                self.reconnectTimer?.invalidate()
                self.reconnectTimer = nil
                self.drainOfflineQueue()
                self.requestCatchup()
            }
            if let existingPeers = json["peers"] as? [[String: Any]] {
                for pDict in existingPeers {
                    parseAndAddPeer(pDict)
                }
            }

        case "peer_joined":
            if let pDict = json["peer"] as? [String: Any] {
                parseAndAddPeer(pDict)
            }

        case "peer_presence":
            guard let uid = json["user_id"] as? String,
                  let cursorDict = json["cursor"] as? [String: Any] else { return }

            let x = CGFloat((cursorDict["x"] as? NSNumber)?.floatValue ?? 0)
            let y = CGFloat((cursorDict["y"] as? NSNumber)?.floatValue ?? 0)
            let isDrawing = (cursorDict["is_drawing"] as? Bool) ?? false
            let tool = (cursorDict["tool"] as? String) ?? "pen"
            let selectedId = json["selected_id"] as? String

            if let idx = peers.firstIndex(where: { $0.userId == uid }) {
                peers[idx].cursor = PeerCursor(x: x, y: y, isDrawing: isDrawing, tool: tool, selectedId: selectedId)
                peers[idx].selectedId = selectedId
                peers[idx].lastActive = Date()
            }

        case "peer_left":
            if let uid = json["user_id"] as? String {
                peers.removeAll(where: { $0.userId == uid })
            }

        case "peer_oplog":
            guard let uid = json["user_id"] as? String,
                  let kind = json["kind"] as? String,
                  let rawPayload = json["payload"] as? [String: Any] else { return }
            let lamport = (json["lamport"] as? NSNumber)?.uint64Value ?? 0
            self.maxKnownLamport = max(self.maxKnownLamport, lamport)
            let isEncrypted = (json["encrypted"] as? Bool) ?? false

            if let decryptedPayload = decryptPayload(rawPayload, isEncrypted: isEncrypted) {
                let event = RemoteOplogEvent(userId: uid, kind: kind, payload: decryptedPayload, lamport: lamport)
                oplogReceived.send(event)
            }

        case "oplog_batch":
            if let batch = json["oplogs"] as? [[String: Any]] {
                for item in batch {
                    if let uid = item["user_id"] as? String,
                       let kind = item["kind"] as? String,
                       let rawPayload = item["payload"] as? [String: Any] {
                        let lamport = (item["lamport"] as? NSNumber)?.uint64Value ?? 0
                        self.maxKnownLamport = max(self.maxKnownLamport, lamport)
                        let isEncrypted = (item["encrypted"] as? Bool) ?? false
                        if let decryptedPayload = decryptPayload(rawPayload, isEncrypted: isEncrypted) {
                            let event = RemoteOplogEvent(userId: uid, kind: kind, payload: decryptedPayload, lamport: lamport)
                            oplogReceived.send(event)
                        }
                    }
                }
            }

        case "room_closed":
            disconnect()

        case "pong":
            // 心跳回覆正常
            break

        default:
            break
        }
    }

    private func parseAndAddPeer(_ dict: [String: Any]) {
        guard let uid = dict["user_id"] as? String,
              let name = dict["user_name"] as? String,
              let color = dict["user_color"] as? String else { return }

        let roleRaw = (dict["role"] as? String) ?? "editor"
        let role = CollaboratorRole(rawValue: roleRaw) ?? .editor

        if uid != currentUserId && !peers.contains(where: { $0.userId == uid }) {
            peers.append(CollaboratorPeer(userId: uid, userName: name, userColor: color, role: role))
        }
    }

    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sendJson(["type": "ping"])
            }
        }
    }
}
