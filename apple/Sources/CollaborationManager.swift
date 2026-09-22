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

    /// 最近一次連線錯誤說明（給 UI 顯示，避免只剩無聲的「重連中」轉圈）
    @Published public var lastErrorMessage: String? = nil
    /// 本機是否正在提供內建中繼服務
    @Published public var isHostingLocalRelay: Bool = false
    /// 本機中繼服務在區域網路上的位址（給隊友輸入）
    @Published public var lanRelayAddress: String? = nil

    /// 內建中繼起不來的原因。**要顯示給使用者看**，不要只 print。
    ///
    /// 起不來的症狀是「連線中斷，正在自動重新連線」無限轉圈，而真正的原因
    /// 是這台裝置根本沒有開成房間。在 macOS 沙盒下，少了
    /// `com.apple.security.network.server` 權限就是這個症狀。
    @Published public var localRelayFailure: String? = nil

    // MARK: - 離線暫存佇列與自動斷線重連
    @Published public var queuedOplogCount: Int = 0
    private var offlineOplogQueue: [[String: Any]] = []
    private var reconnectAttempt: Int = 0
    // 節流、心跳與重連次數都取自核心 —— 兩邊數字不同會讓同一間房裡的
    // 兩台裝置行為不一致（一邊還在重連、一邊已經放棄）。
    private let maxReconnectAttempts: Int = Int(collabTuning().maxReconnectAttempts)
    private var reconnectTimer: Timer?
    private var userInitiatedDisconnect: Bool = false
    public var maxKnownLamport: UInt64 = 0

    public let currentUserId: String = UUID().uuidString

    /// 協作辨識色。取自使用者的身分設定 —— 舊版每次啟動隨機挑一個，
    /// 同一個人在隊友畫面上每次連線都換顏色，反而認不出來。
    public var myColorHex: String {
        AccountManager.shared.profile.colorHex
    }

    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var lastPresenceSentTime: TimeInterval = 0
    private let presenceThrottleInterval: TimeInterval =
        Double(collabTuning().presenceThrottleMs) / 1000.0

    public init() {
        let savedServer = UserDefaults.standard.string(forKey: "kairumo_relay_server_url")
        self.serverAddress = savedServer ?? collabTuning().defaultServer

    }

    // MARK: - 端對端加密輔助函式
    //
    // **金鑰與密文格式都在核心**（`collabEncrypt` / `collabDecrypt`）。
    // 原本這裡是 CryptoKit 的 `AES.GCM`，Android 沒有對應品；各寫一份的話
    // iPad 開的房間 Android 進得去卻每則訊息都解不開 —— 那種失敗極難查。
    // 核心那邊有一組用這台 Mac 的 CryptoKit 實際產出的密文當測試向量，
    // 確保兩邊真的相容，而不是「看起來都是 AES-GCM」。

    /// 生成或重設 256 位元端對端加密房間金鑰
    @discardableResult
    public func generateRoomKey() -> String {
        let b64 = collabGenerateRoomKey()
        self.roomKeyBase64 = b64.isEmpty ? nil : b64
        return b64
    }

    /// 設定或解析端對端加密金鑰
    public func setRoomKey(base64: String?) {
        guard let b64 = base64?.trimmingCharacters(in: .whitespacesAndNewlines),
              collabIsValidRoomKey(keyBase64: b64) else {
            self.roomKeyBase64 = nil
            return
        }
        self.roomKeyBase64 = b64
    }

    /// 使用 AES-256-GCM 進行端對端加密
    public func encryptPayload(_ payload: [String: Any]) -> (encryptedPayload: [String: Any], isEncrypted: Bool) {
        guard let key = roomKeyBase64,
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else {
            return (payload, false)
        }
        let cipher = collabEncrypt(keyBase64: key, plaintext: json)
        // 核心加密失敗時回空字串。改送明文而不是不送 ——
        // 少一則 oplog 是資料遺失，而使用者不會知道。
        guard !cipher.isEmpty else { return (payload, false) }
        return (["ciphertext": cipher], true)
    }

    /// 解密接收到的遠端 Payload。解不開時回 nil，呼叫端丟掉那則訊息。
    public func decryptPayload(_ payload: [String: Any], isEncrypted: Bool) -> [String: Any]? {
        if !isEncrypted { return payload }
        // **加密的訊息、手上沒金鑰 → 丟掉，不要把信封當內容傳下去。**
        //
        // 這裡原本回傳 `payload` 本身，而加密訊息的 payload 是
        // `{"ciphertext": "..."}` —— 沒有 `page_index`、沒有 `item`。
        // 於是下游每一個 `guard let ... else { return }` 都靜靜地失敗：
        // 訊息收到了、也「處理」了，畫面上什麼都沒發生，log 裡也沒有錯誤。
        // 實機症狀是「兩台都顯示已連線，對方畫的東西永遠不會出現」。
        // 回 nil 才會落到呼叫端的丟棄分支，也才對得上介面上那則
        // 「你只用房號加入」的警告。
        guard let key = roomKeyBase64,
              let cipherBase64 = payload["ciphertext"] as? String else {
            return nil
        }
        let plain = collabDecrypt(keyBase64: key, ciphertextBase64: cipherBase64)
        guard !plain.isEmpty,
              let data = plain.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // 解不開代表對方用的是另一把金鑰。把密文當內容寫進筆記
            // 只會在畫布上留下一串亂碼。
            return nil
        }
        return dict
    }

    /// 取得帶有 E2EE 金鑰的安全邀請連結
    public var encryptedInviteLink: String {
        collabInviteLink(roomId: currentRoomId, keyBase64: roomKeyBase64 ?? "")
    }

    // MARK: - 連線與房間管理

    /// 建立新協同房間（作為房主 Owner）
    // 原本收一個 `noteId`，而主體從沒讀過它、呼叫端也從沒傳過。
    // 房間與筆記本的關聯目前不存在 —— 拿掉參數讓這件事看得見。
    public func createRoom() {
        generateRoomKey()
        connect(roomId: collabNewRoomId(), asHost: true)
    }

    /// 加入既有協同房間
    public func joinRoom(roomId: String) {
        // 房號、連結、連結帶金鑰三種輸入都由核心解析 —— 使用者三種都會貼，
        // 而 Android 端要用同一套規則，否則同一個連結兩邊解出不同房號。
        let invite = collabParseInvite(text: roomId)
        guard !invite.roomId.isEmpty else { return }
        if !invite.keyBase64.isEmpty {
            setRoomKey(base64: invite.keyBase64)
        }
        connect(roomId: invite.roomId, asHost: false)
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

        // 明文的中繼只允許在自己的區網或本機。oplog 本身是端對端加密的，
        // 但房號、成員與流量樣態全是明文，而且明文 WebSocket 可以被中間人
        // 直接改寫或重導。判斷在核心，兩邊同一份 —— 各寫一次的話，同一個
        // 位址會在 iPad 上連得上、在 Android 上連不上。
        let check = collabCheckServer(url: serverAddress)
        if !check.ok {
            self.lastErrorMessage = LocalizationManager.shared.localized(check.reasonKey)
            self.status = .disconnected
            return
        }

        guard let url = URL(string: serverAddress) else {
            print("❌ 無效的 WebSocket 伺服器網址: \(serverAddress)")
            self.lastErrorMessage = "無效的協同伺服器位址：\(serverAddress)"
            self.status = .disconnected
            return
        }

        // 位址指向本機時，直接由這台裝置提供中繼服務。
        // 沒有這一步，預設的 ws://127.0.0.1:9002 後面根本沒有人在聽，
        // 連線一定失敗，畫面就永遠卡在「正在自動重新連線」。
        if Self.isLoopbackHost(url.host) {
            startLocalRelayIfNeeded(port: UInt16(url.port ?? 9002))
        } else {
            isHostingLocalRelay = false
            lanRelayAddress = nil
        }
        lastErrorMessage = nil

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

    /// 判斷位址是否指向本機（含未填主機名的情況）
    static func isLoopbackHost(_ host: String?) -> Bool {
        collabIsLoopbackHost(host: host ?? "")
    }

    /// 啟動內建中繼服務（冪等；已在執行中則直接沿用）
    private func startLocalRelayIfNeeded(port: UInt16) {
        // **真正的狀態是非同步來的。** `start()` 回傳成功只代表 NWListener
        // 建得起來；能不能聽要等 `stateUpdateHandler`。在此之前這裡樂觀地
        // 設成 true 就不管了 —— 監聽其實失敗時，畫面照樣說「正在擔任中繼」。
        LocalRelayServer.shared.onStateChange = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready(let boundPort):
                self.isHostingLocalRelay = true
                self.localRelayFailure = nil
                self.lanRelayAddress = LocalRelayServer.lanIPv4Address()
                    .map { "ws://\($0):\(boundPort)" }
            case .failed(let why):
                self.isHostingLocalRelay = false
                self.lanRelayAddress = nil
                self.localRelayFailure = String(
                    format: LocalizationManager.shared.localized("local_relay_failed"), why)
            }
        }

        switch LocalRelayServer.shared.start(port: port) {
        case .success:
            // 這裡**先不宣稱在聽** —— 要等 `.ready` 回來才算。
            break
        case .failure(let error):
            isHostingLocalRelay = false
            lanRelayAddress = nil
            // 埠被佔用通常代表已經有一個中繼（例如 `cargo run -p padnote-relay`）
            // 在聽，那就照常連過去，不是致命錯誤 —— 連上之後這個訊息會自己
            // 清掉。其餘的失敗（例如沙盒擋下監聽）則會一直留在畫面上。
            localRelayFailure = String(
                format: LocalizationManager.shared.localized("local_relay_failed"),
                error.localizedDescription)
        }
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
            if isHostingLocalRelay {
                LocalRelayServer.shared.stop()
                isHostingLocalRelay = false
                lanRelayAddress = nil
            }
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
            self.lastErrorMessage = "無法連上協同伺服器 \(serverAddress)，已停止重試。"
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
                    self.lastErrorMessage = error.localizedDescription
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
                // 連上了就沒有問題可報 —— 最常見的「監聽失敗」其實是埠被
                // 另一個中繼佔著（例如 `cargo run -p padnote-relay`），
                // 那種情況照樣連得上，不該對使用者跳警告。
                self.localRelayFailure = nil
                self.lastErrorMessage = nil
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
        pingTimer = Timer.scheduledTimer(
            withTimeInterval: Double(collabTuning().pingIntervalS),
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sendJson(["type": "ping"])
            }
        }
    }
}
