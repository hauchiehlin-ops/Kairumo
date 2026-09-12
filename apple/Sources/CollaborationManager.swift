//
//  CollaborationManager.swift
//  Kairumo
//
//  線上多人即時協同管理器（第一階段 MVP：輕量 WebSocket Relay + 雙通道通訊架構）
//

import SwiftUI
import Foundation
import Combine

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
    case reconnecting
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

    // MARK: - 連線與房間管理

    /// 建立新協同房間（作為房主 Owner）
    public func createRoom(noteId: String? = nil) {
        let prefix = "kairumo"
        let randomCode = String(UUID().uuidString.prefix(6)).lowercased()
        let newRoomId = "\(prefix)-\(randomCode)"
        connect(roomId: newRoomId, asHost: true)
    }

    /// 加入既有協同房間
    public func joinRoom(roomId: String) {
        let cleaned = roomId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        connect(roomId: cleaned, asHost: false)
    }

    /// 連線至中繼伺服器
    private func connect(roomId: String, asHost: Bool) {
        disconnect()

        guard let url = URL(string: serverAddress) else {
            print("❌ 無效的 WebSocket 伺服器網址: \(serverAddress)")
            return
        }

        self.status = .connecting
        self.currentRoomId = roomId
        self.isHost = asHost
        self.peers.removeAll()

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
    public func disconnect() {
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
        self.currentRoomId = ""
        self.isHost = false
        self.peers.removeAll()
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

    /// 廣播持久化 CRDT 操作（落筆完成或物件增刪）
    public func broadcastOplog(kind: String, payload: [String: Any], lamport: UInt64 = 1) {
        guard case .connected(let rid) = status else { return }

        let msg: [String: Any] = [
            "type": "oplog",
            "room_id": rid,
            "user_id": currentUserId,
            "lamport": lamport,
            "kind": kind,
            "payload": payload
        ]
        sendJson(msg)
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
                    if self.status != .disconnected {
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
                  let payload = json["payload"] as? [String: Any] else { return }
            let lamport = (json["lamport"] as? NSNumber)?.uint64Value ?? 0
            let event = RemoteOplogEvent(userId: uid, kind: kind, payload: payload, lamport: lamport)
            oplogReceived.send(event)

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
