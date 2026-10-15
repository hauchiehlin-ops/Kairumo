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
    // profile-scope: profile 每個設定檔各有一份狀態，切換時必須重設
    public static let shared = CollaborationManager()

    public let oplogReceived = PassthroughSubject<RemoteOplogEvent, Never>()
    /// 兩人同時選取同一個物件、而對方勝出：本機要放手（設計 §5.3）。值是物件 id 與對方名字。
    public let leaseLost = PassthroughSubject<(id: String, holder: String), Never>()
    /// 中繼的暫存已經補不回漏掉的那一段（設計 §7）：編輯器向其他成員要整份狀態。
    public let stateSyncNeeded = PassthroughSubject<Void, Never>()
    /// 看過的最大中繼序號（同一個房間裡重連時從這裡補發）。
    private var lastSeq: UInt64 = 0
    /// 還在用舊協定的參與者（送的是整頁筆跡、整個物件、沒有時鐘）。混用會單向同步，要提示更新。
    @Published public var outdatedPeerIds: Set<String> = []

    @Published public var status: CollaborationStatus = .disconnected
    @Published public var currentRoomId: String = ""
    @Published public var isHost: Bool = false
    @Published public var peers: [CollaboratorPeer] = []
    @Published public var latencyMs: Int = 18
    @Published public var serverAddress: String {
        didSet {
            ProfileDefaults.current.set(serverAddress, forKey: "kairumo_relay_server_url")
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
    /// 本機中繼服務在 Tailscale 虛擬私有網路上的位址（給不同網段／遠端隊友連線）
    @Published public var tailscaleRelayAddress: String? = nil

    /// 內建中繼起不來的原因。**要顯示給使用者看**，不要只 print。
    ///
    /// 起不來的症狀是「連線中斷，正在自動重新連線」無限轉圈，而真正的原因
    /// 是這台裝置根本沒有開成房間。在 macOS 沙盒下，少了
    /// `com.apple.security.network.server` 權限就是這個症狀。
    @Published public var localRelayFailure: String? = nil
    /// Bonjour mDNS 廣播被系統隱私拒絕（NoAuth -65555），但純 TCP 監聽仍運作中。
    @Published public var isBonjourDegraded: Bool = false

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
    /// Lamport 時鐘（設計 §3）。送出時 +1；收到時取最大值。
    public private(set) var lamportClock: UInt64 = 0
    /// 收過的操作 id（去重）。合併規則本來就冪等，這只是省掉重複的工。
    private var seenOpIds: Set<String> = []
    private var seenOpOrder: [String] = []
    /// 選取（編輯租約）續約計時器：持有期間每秒重送一次在場資訊（設計 §5.1）。
    private var leaseRenewTimer: Timer?

    /// 這一次送出要用的時鐘值。
    public func nextLamport() -> UInt64 {
        lamportClock += 1
        return lamportClock
    }

    /// 編輯租約多久沒續約就算失效（對方當機或斷線時，物件不能永遠鎖住）。
    public static let leaseTimeout: TimeInterval = 5

    /// 在場資訊裡「正在這個方塊打字」的選取 id 前綴（設計 §8.3）。
    ///
    /// 打字不是獨佔的：文字內容以字元 CRDT 合併，兩個人可以同時打。所以它不算租約，
    /// 只用來讓別人看得到「誰正在這裡打字」。
    public static let typingPrefix = "text:"

    /// 選取 id 的正規形式（設計 §8.1）：Apple 的附件 id 是大寫 UUID、Android 是核心的小寫 id，
    /// 不正規化的話兩個平台的編輯鎖互相看不見。收到時與比對時都過這一關。
    nonisolated public static func canonicalSelection(_ id: String) -> String {
        if id.hasPrefix(typingPrefix) {
            return typingPrefix + NotebookPackageBridge.stableBlockId(String(id.dropFirst(typingPrefix.count)))
        }
        return NotebookPackageBridge.stableBlockId(id)
    }

    /// 正在這個文字方塊打字的人（不含自己）。
    public func typingPeers(for id: String) -> [CollaboratorPeer] {
        let now = Date()
        return peers.filter {
            $0.selectedId == Self.canonicalSelection(Self.typingPrefix + id)
                && now.timeIntervalSince($0.lastActive) < Self.leaseTimeout
        }
    }

    /// 誰正在編輯這個物件（租約有效、而且對方勝出）。沒有人就回 nil。
    ///
    /// 兩人同時選取時以使用者 id 較小者為準 —— 每一台都算得出同一個答案，不必另外協商。
    public func leaseHolder(for id: String) -> CollaboratorPeer? {
        let now = Date()
        let wanted = Self.canonicalSelection(id)
        return peers.first { peer in
            guard peer.selectedId == wanted, now.timeIntervalSince(peer.lastActive) < Self.leaseTimeout else { return false }
            return mySelectedId.map(Self.canonicalSelection) != wanted || peer.userId < currentUserId
        }
    }

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
        let savedServer = ProfileDefaults.current.string(forKey: "kairumo_relay_server_url")
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

    /// 取得帶有 E2EE 金鑰與伺服器位址的安全邀請連結
    public func inviteLink(forTailscale: Bool = false) -> String {
        let baseLink = collabInviteLink(roomId: currentRoomId, keyBase64: roomKeyBase64 ?? "")
        let targetServer: String?
        if isHostingLocalRelay {
            if forTailscale, let ts = tailscaleRelayAddress {
                targetServer = ts
            } else {
                targetServer = lanRelayAddress ?? tailscaleRelayAddress
            }
        } else {
            targetServer = Self.isLoopbackHost(URL(string: serverAddress)?.host) ? nil : serverAddress
        }
        if let s = targetServer, !s.isEmpty {
            if let hashIdx = baseLink.firstIndex(of: "#") {
                let prefix = baseLink[..<hashIdx]
                let fragment = baseLink[hashIdx...]
                let delimiter = prefix.contains("?") ? "&" : "?"
                let encodedServer = s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
                return "\(prefix)\(delimiter)server=\(encodedServer)\(fragment)"
            } else {
                let delimiter = baseLink.contains("?") ? "&" : "?"
                let encodedServer = s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
                return "\(baseLink)\(delimiter)server=\(encodedServer)"
            }
        }
        return baseLink
    }

    /// 取得帶有 E2EE 金鑰與伺服器位址的安全邀請連結（預設區網）
    public var encryptedInviteLink: String {
        inviteLink(forTailscale: false)
    }

    /// 取得 Tailscale 跨網段安全邀請連結（若已連線 Tailscale 則提供）
    public var tailscaleInviteLink: String? {
        tailscaleRelayAddress != nil ? inviteLink(forTailscale: true) : nil
    }

    /// 從輸入字串中解析伺服器位址（若有提供）
    public static func extractServerUrl(from text: String) -> String? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: cleaned),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let val = components.queryItems?.first(where: { $0.name == "server" })?.value,
           !val.isEmpty {
            return val
        }
        if let range = cleaned.range(of: "server=") {
            let sub = cleaned[range.upperBound...]
            let endIdx = sub.firstIndex(where: { $0 == "&" || $0 == "#" || $0.isWhitespace }) ?? sub.endIndex
            let rawVal = String(sub[..<endIdx])
            let extracted = rawVal.removingPercentEncoding ?? rawVal
            if !extracted.isEmpty {
                return extracted
            }
        }
        return nil
    }

    /// 從輸入字串中解析乾淨的房間代碼
    public static func extractRoomId(from text: String) -> String {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: cleaned),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let val = components.queryItems?.first(where: { $0.name == "room" })?.value,
           !val.isEmpty {
            return val
        }
        let invite = collabParseInvite(text: cleaned)
        if let ampIdx = invite.roomId.firstIndex(of: "&") {
            return String(invite.roomId[..<ampIdx])
        }
        return invite.roomId
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
        let trimmed = roomId.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. 若輸入包含 server 參數，立即套用該伺服器位址
        if let serverParam = Self.extractServerUrl(from: trimmed) {
            self.serverAddress = serverParam
        } else if Self.isLoopbackHost(URL(string: self.serverAddress)?.host) {
            // 2. 若本地仍為 127.0.0.1，檢查是否有局域網掃描到的房間
            let targetRoomId = Self.extractRoomId(from: trimmed)
            if let matched = LocalSyncDiscovery.shared.discoveredRooms.first(where: { $0.roomId == targetRoomId }) {
                self.serverAddress = matched.serverUrl
            } else if let firstDiscovered = LocalSyncDiscovery.shared.discoveredRooms.first {
                self.serverAddress = firstDiscovered.serverUrl
            }
        }

        let cleanedRoomId = Self.extractRoomId(from: trimmed)
        guard !cleanedRoomId.isEmpty else { return }

        let invite = collabParseInvite(text: trimmed)
        if !invite.keyBase64.isEmpty {
            setRoomKey(base64: invite.keyBase64)
        }
        connect(roomId: cleanedRoomId, asHost: false)
    }

    /// 連線至中繼伺服器
    public func connect(roomId: String, asHost: Bool, isReconnecting: Bool = false) {
        userInitiatedDisconnect = false

        if !isReconnecting {
            disconnect(userInitiated: false)
            reconnectAttempt = 0
            self.currentRoomId = roomId
            // 新的房間從頭來；斷線重連回同一個房間則從看過的序號接著補。
            self.lastSeq = 0
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
            self.lastErrorMessage = L10n.f("collab_err_bad_address", serverAddress)
            self.status = .disconnected
            return
        }

        // 位址指向本機時，只有發起者（Host）才啟動中繼服務。
        // 加入者若指向本機，代表沒有配置正確的主機區網 IP，必須提醒使用者而不是在本地開空房間。
        if Self.isLoopbackHost(url.host) {
            if asHost {
                startLocalRelayIfNeeded(port: UInt16(url.port ?? 9002), roomId: roomId)
            } else {
                print("⚠️ [Collab] 加入者不能將 127.0.0.1 視為中繼位址，請使用邀請連結或輸入房主的區網 IP (如 ws://192.168.x.x:9002)")
                self.lastErrorMessage = LocalizationManager.shared.localized("collab_err_guest_loopback")
                self.status = .disconnected
                return
            }
        } else {
            isHostingLocalRelay = false
            lanRelayAddress = nil
            tailscaleRelayAddress = nil
        }
        lastErrorMessage = nil

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        // 預設上限 1 MB：一張照片（base64 後）就超過，整條連線會被斷掉。與中繼的 64 MB 一致。
        task.maximumMessageSize = 64 * 1024 * 1024
        self.webSocketTask = task
        task.resume()

        startListening()
        startPingTimer()

        // 發送 Join 申請（附帶裝置型號後綴，即使登錄同一個 Google 帳號也能清晰辨識）
        #if os(macOS) || targetEnvironment(macCatalyst)
        let deviceTag = "Mac"
        #elseif os(iOS)
        let deviceTag = (UIDevice.current.userInterfaceIdiom == .pad) ? "iPad" : "iPhone"
        #else
        let deviceTag = "Device"
        #endif
        let rawName = AccountManager.shared.profile.displayName
        let myName = "\(rawName) (\(deviceTag))"
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
    private func startLocalRelayIfNeeded(port: UInt16, roomId: String? = nil) {
        // **真正的狀態是非同步來的。** `start()` 回傳成功只代表 NWListener
        // 建得起來；能不能聽要等 `stateUpdateHandler`。在此之前這裡樂觀地
        // 設成 true 就不管了 —— 監聽其實失敗時，畫面照樣說「正在擔任中繼」。
        LocalRelayServer.shared.onStateChange = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready(let boundPort, let isBonjourActive):
                self.isHostingLocalRelay = true
                self.isBonjourDegraded = !isBonjourActive
                self.localRelayFailure = nil
                let addrs = LocalRelayServer.availableIPv4Addresses()
                self.lanRelayAddress = addrs.lan.map { "ws://\($0):\(boundPort)" }
                self.tailscaleRelayAddress = addrs.tailscale.map { "ws://\($0):\(boundPort)" }
            case .failed(let why):
                self.isHostingLocalRelay = false
                self.isBonjourDegraded = false
                self.lanRelayAddress = nil
                self.tailscaleRelayAddress = nil
                self.localRelayFailure = String(
                    format: LocalizationManager.shared.localized("local_relay_failed"), why)
            }
        }

        #if os(macOS) || targetEnvironment(macCatalyst)
        let deviceTag = "Mac"
        #elseif os(iOS)
        let deviceTag = (UIDevice.current.userInterfaceIdiom == .pad) ? "iPad" : "iPhone"
        #else
        let deviceTag = "Device"
        #endif
        let myHostName = "\(AccountManager.shared.profile.displayName) (\(deviceTag))"

        switch LocalRelayServer.shared.start(port: port, roomId: roomId, hostName: myHostName) {
        case .success:
            // 這裡**先不宣稱在聽** —— 要等 `.ready` 回來才算。
            break
        case .failure(let error):
            isHostingLocalRelay = false
            lanRelayAddress = nil
            tailscaleRelayAddress = nil
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
                tailscaleRelayAddress = nil
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
            self.lastErrorMessage = L10n.f("collab_err_unreachable", serverAddress)
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
            // 新版中繼以序號補發（不會漏掉時鐘較小但較晚到的操作）；舊版中繼忽略 last_seq，
            // 照 last_lamport = 0 從頭補 —— 合併規則冪等，重複收到沒有副作用（設計 §7）。
            "last_lamport": 0,
            "last_seq": lastSeq
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
        leaseRenewTimer?.invalidate()
        leaseRenewTimer = nil
        if selectedId != nil {
            leaseRenewTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, let id = self.mySelectedId else { return }
                    self.sendSelectionPresence(id)
                }
            }
        }
        guard case .connected = status else { return }
        sendSelectionPresence(selectedId)
    }

    private func sendSelectionPresence(_ selectedId: String?) {
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

    /// 廣播一個操作（物件修改、筆跡增刪），支援 E2EE 加密與離線佇列。回傳這個操作的時鐘值。
    ///
    /// **時鐘由這裡統一配發**（設計 §3）。以前呼叫端可以自己帶、預設值是 1，結果每一筆都是 1。
    /// 操作 id 放在 payload 裡：三份中繼都原樣轉送 payload，但不見得保留外層的其他欄位。
    @discardableResult
    public func broadcastOplog(kind: String, payload: [String: Any], lamport explicit: UInt64? = nil) -> UInt64 {
        // 呼叫端需要事先知道時鐘值時（物件合併要用同一個時戳記錄本機的欄位），
        // 先以 `nextLamport()` 取得再傳進來；其餘一律由這裡配發。
        let lamport = explicit ?? nextLamport()
        maxKnownLamport = max(maxKnownLamport, lamport)
        var stamped = payload
        stamped["op_id"] = UUID().uuidString

        let (finalPayload, isEncrypted) = encryptPayload(stamped)

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
        return lamport
    }

    // MARK: - 舊協定（已停用）
    //
    // 物件的新增、修改、刪除與討論圖釘改由編輯器的單一入口（`commitNotebook`）比對後以
    // `obj_patch` 送出（見 `CollabObjectSync`）：每一種修改都會送、帶時鐘、以欄位為單位合併。
    // 以前這幾個方法散落在各個操作裡手動呼叫，漏掉的（框選搬移、圖層、復原…）就不會同步；
    // 而且收到的一方以到達順序覆蓋，兩人同時改同一個物件時兩邊結果不同。
    // 保留簽名讓既有呼叫端照常編譯，內容不再送出 —— 同一個修改送兩次（新舊各一）
    // 會讓舊格式以到達順序覆蓋新格式的合併結果。

    /// 已停用（見上方說明）。
    public func broadcastAttachmentUpsert(type: String, itemDict: [String: Any]) {}

    /// 已停用（見上方說明）。
    public func broadcastAttachmentDelete(id: String, type: String) {}

    /// 已停用（見上方說明）。
    public func broadcastCommentUpsert(pinDict: [String: Any]) {}

    /// 已停用（見上方說明）。
    public func broadcastCommentResolve(pinId: String, isResolved: Bool) {}

    /// 已停用（見上方說明）。
    public func broadcastCommentDelete(pinId: String) {}

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
                    self.lastErrorMessage = L10n.errorText(error)
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
            // 第一次進這個房間、而且裡面有人：向他們要整份狀態（這台的檔案可能比較舊，設計 §7）。
            if lastSeq == 0, !peers.isEmpty { stateSyncNeeded.send(()) }

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
            let selectedId = (json["selected_id"] as? String).map(Self.canonicalSelection)

            if let idx = peers.firstIndex(where: { $0.userId == uid }) {
                peers[idx].cursor = PeerCursor(x: x, y: y, isDrawing: isDrawing, tool: tool, selectedId: selectedId)
                peers[idx].selectedId = selectedId
                peers[idx].lastActive = Date()
                // 兩人同時選了同一個物件：使用者 id 較小者勝（每一台算出同一個答案）。
                // 「正在打字」不是獨佔的（字元 CRDT 會合併），不參與搶奪。
                if let sel = selectedId, let mine = mySelectedId, sel == Self.canonicalSelection(mine),
                   !sel.hasPrefix(Self.typingPrefix), uid < currentUserId {
                    leaseLost.send((id: mine, holder: peers[idx].userName))
                }
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
            let isEncrypted = (json["encrypted"] as? Bool) ?? false
            if let seq = (json["seq"] as? NSNumber)?.uint64Value { lastSeq = max(lastSeq, seq) }
            deliver(userId: uid, kind: kind, rawPayload: rawPayload, lamport: lamport, isEncrypted: isEncrypted)

        case "oplog_batch":
            if let batch = json["oplogs"] as? [[String: Any]] {
                for item in batch {
                    if let seq = (item["seq"] as? NSNumber)?.uint64Value { lastSeq = max(lastSeq, seq) }
                    if let uid = item["user_id"] as? String,
                       let kind = item["kind"] as? String,
                       let rawPayload = item["payload"] as? [String: Any] {
                        let lamport = (item["lamport"] as? NSNumber)?.uint64Value ?? 0
                        let isEncrypted = (item["encrypted"] as? Bool) ?? false
                        // 補發會包含自己送過的：自己的修改本機早就套用了。
                        guard uid != currentUserId else { continue }
                        deliver(userId: uid, kind: kind, rawPayload: rawPayload, lamport: lamport, isEncrypted: isEncrypted)
                    }
                }
            }
            if (json["truncated"] as? Bool) == true { stateSyncNeeded.send(()) }

        case "room_closed":
            disconnect()

        case "pong":
            // 心跳回覆正常
            break

        default:
            break
        }
    }

    /// 收到一個操作：推進時鐘、去重、標記舊版參與者，再交給編輯器。
    private func deliver(userId uid: String, kind: String, rawPayload: [String: Any], lamport: UInt64, isEncrypted: Bool) {
        lamportClock = max(lamportClock, lamport)
        maxKnownLamport = max(maxKnownLamport, lamport)
        guard let payload = decryptPayload(rawPayload, isEncrypted: isEncrypted) else { return }
        if let opId = payload["op_id"] as? String {
            guard !seenOpIds.contains(opId) else { return }
            seenOpIds.insert(opId)
            seenOpOrder.append(opId)
            if seenOpOrder.count > 4000 {
                seenOpIds.remove(seenOpOrder.removeFirst())
            }
        }
        if Self.legacyKinds.contains(kind), !outdatedPeerIds.contains(uid) {
            outdatedPeerIds.insert(uid)
        }
        oplogReceived.send(RemoteOplogEvent(userId: uid, kind: kind, payload: payload, lamport: lamport))
    }

    /// 舊協定的操作種類。收到就代表對方的版本較舊。
    static let legacyKinds: Set<String> = [
        "attachment_upsert", "attachment_delete", "drawing_replace", "stroke_delta",
        "comment_upsert", "comment_resolve", "comment_delete",
    ]

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

// MARK: - 設定檔切換

extension CollaborationManager: ProfileScoped {
    func prepareForProfileSwitch() async {
        // 離開房間、關掉自己開的中繼。房間是用這個設定檔的身分與金鑰進的。
        disconnect()
        LocalRelayServer.shared.stop()
        isHostingLocalRelay = false
        lanRelayAddress = nil
        tailscaleRelayAddress = nil
    }

    func resetForProfileSwitch() {
        status = .disconnected
        currentRoomId = ""
        isHost = false
        peers = []
        roomKeyBase64 = nil
        lastErrorMessage = nil
        localRelayFailure = nil
        isBonjourDegraded = false
        queuedOplogCount = 0
        offlineOplogQueue.removeAll()
        reconnectAttempt = 0
        maxKnownLamport = 0
        lamportClock = 0
        lastSeq = 0
        seenOpIds.removeAll()
        seenOpOrder.removeAll()
        outdatedPeerIds.removeAll()
        leaseRenewTimer?.invalidate()
        leaseRenewTimer = nil
        serverAddress = ProfileDefaults.current.string(forKey: "kairumo_relay_server_url")
            ?? collabTuning().defaultServer
    }
}
