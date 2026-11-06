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
    /// 這間房屬於哪一本筆記。房間跟著筆記走：關掉那本（或在編輯器裡換到別本）就離開房間，
    /// 不然打開 B 時面板還掛著 A 的房間，QR Code 卻帶 B 的 id —— 對方掃了會把 A 的修改寫進 B。
    @Published public private(set) var roomNotebookId: String? = nil
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
    /// 從外面進來的協同邀請（相機掃 QR Code、點 `kairumo://collab?...`）。
    ///
    /// 不直接加入：使用者可能正開著別本筆記，要讓他看見是哪個房間、按「加入」才連。
    /// 編輯器看到它有值就打開協同面板，面板把連結帶進「加入房間」欄位。與 Android `CollabInvites` 同一套。
    @Published public var pendingInviteLink: String? = nil

    /// 是協同邀請就收下（回 true）。只認 `kairumo://collab`。
    @discardableResult
    public func offerInvite(_ link: String) -> Bool {
        let text = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.lowercased().hasPrefix("kairumo://collab") else { return false }
        pendingInviteLink = text
        return true
    }
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

    private var webSocketTask: CollabRelaySocket?
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
            targetServer = Self.isLoopbackHost(URL(string: activeServerAddress)?.host) ? nil : activeServerAddress
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

    /// 帶上「是哪一本筆記」的邀請連結（同一 Wi‑Fi／Tailscale／遠端中繼的 QR Code 用）。
    ///
    /// 舊版的連結只有房號、金鑰、位址：協作者用相機一掃，App 被叫起來之後不知道要打開
    /// 哪一本，只好停在首頁 —— 使用者看到的是「掃了沒反應」。補上 `nb`／`title`
    /// （與雲端共享同一個 v2 格式，由核心組字串，Android 相同，I6），收到的一端才能
    /// 直接打開（或建立）那本筆記並接上房間。
    public func notebookInviteLink(_ link: String, notebookId: String?, title: String) -> String {
        guard let notebookId, !notebookId.isEmpty, !link.isEmpty else { return link }
        var invite = collabParseInviteV2(text: link)
        guard !invite.roomId.isEmpty else { return link }
        invite.notebookId = notebookId
        invite.title = title
        return collabInviteLinkV2(invite: invite)
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
    public func createRoom(notebookId: String? = nil, server: String? = nil) {
        generateRoomKey()
        // 指定伺服器（雲端共享的房間開在公開中繼上）只用於這一場，不改使用者存的預設位址。
        serverOverride = server
        connect(roomId: collabNewRoomId(), asHost: true)
        roomNotebookId = notebookId?.lowercased()
    }

    /// 以既有的房號與金鑰當房主開房（雲端共享的房間：重開 App 之後沿用同一間，之前發出去的邀請照樣有效）。
    public func hostRoom(roomId: String, keyBase64: String, notebookId: String, server: String) {
        setRoomKey(base64: keyBase64)
        serverOverride = server
        connect(roomId: roomId, asHost: true)
        roomNotebookId = notebookId.lowercased()
    }

    // MARK: 公開中繼（跨網路）

    /// Kairumo 的公開中繼（Cloudflare Workers，見 `deploy/relay-cloudflare`）。與 Android
    /// `CollaborationManager.PUBLIC_RELAY_URL` 相同。空字串＝還沒部署：雲端共享照舊只用區網／Tailscale。
    public static let publicRelayURL = "wss://kairumo-relay.kairumo-relay.workers.dev"

    /// 這一場用的伺服器（加入邀請、或雲端共享開在公開中繼上）。`nil` = 用使用者存的 `serverAddress`。
    /// 不寫回 `serverAddress`：以前加入別人的房間會把對方的位址存成這台的預設，之後自己開房就連到別人那裡。
    private var serverOverride: String?

    /// 目前連線用的位址。
    public var activeServerAddress: String { serverOverride ?? serverAddress }

    /// 連線網址加上 `room=<房號>`：公開中繼（Cloudflare）以它決定房間；Rust 中繼不看網址，加了也無妨。
    static func relayURL(_ address: String, roomId: String) -> URL? {
        guard var parts = URLComponents(string: address) else { return nil }
        var items = (parts.queryItems ?? []).filter { $0.name != "room" }
        items.append(URLQueryItem(name: "room", value: roomId))
        parts.queryItems = items
        return parts.url
    }

    /// 關掉（或換掉）筆記本時呼叫：這間房是那本的就離開。
    ///
    /// 用 `disconnect` 而不是 `closeRoom`：房主只是關了筆記，不是要解散房間 ——
    /// `room_closed` 會讓雲端共享的協作者連同共享資料夾一起停掉（見 `handleIncomingMessage`）。
    /// 要結束整場協同請在面板按「結束協同」。
    public func leaveRoom(ifBoundTo notebookId: String) {
        guard let bound = roomNotebookId, bound == notebookId.lowercased() else { return }
        disconnect()
    }

    /// 加入既有協同房間
    public func joinRoom(roomId: String, notebookId: String? = nil) {
        let trimmed = roomId.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { if !currentRoomId.isEmpty { roomNotebookId = notebookId?.lowercased() } }

        // 1. 若輸入包含 server 參數，立即套用該伺服器位址
        //    （只用於這一場，見 `serverOverride`）
        if let serverParam = Self.extractServerUrl(from: trimmed) {
            self.serverOverride = serverParam
        } else if Self.isLoopbackHost(URL(string: self.serverAddress)?.host) {
            // 2. 若本地仍為 127.0.0.1，檢查是否有局域網掃描到的房間
            let targetRoomId = Self.extractRoomId(from: trimmed)
            if let matched = LocalSyncDiscovery.shared.discoveredRooms.first(where: { $0.roomId == targetRoomId }) {
                self.serverOverride = matched.serverUrl
            } else if let firstDiscovered = LocalSyncDiscovery.shared.discoveredRooms.first {
                self.serverOverride = firstDiscovered.serverUrl
            }
        } else {
            self.serverOverride = nil
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
        let address = activeServerAddress
        let check = collabCheckServer(url: address)
        if !check.ok {
            self.lastErrorMessage = LocalizationManager.shared.localized(check.reasonKey)
            self.status = .disconnected
            return
        }

        guard let url = URL(string: address), let socketURL = Self.relayURL(address, roomId: roomId) else {
            print("❌ 無效的 WebSocket 伺服器網址: \(address)")
            self.lastErrorMessage = L10n.f("collab_err_bad_address", address)
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

        // 明文 ws:// 走 Network.framework（不受 ATS 限制，Tailscale 的 100.x 位址才連得上），
        // wss:// 走 URLSession。見 CollabRelaySocket.swift。
        self.webSocketTask = CollabRelaySockets.open(socketURL)

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
            self.serverOverride = nil
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
        webSocketTask?.close()
        webSocketTask = nil

        self.status = .disconnected
        LiveInkStore.shared.clear()
        if userInitiated {
            self.currentRoomId = ""
            self.roomNotebookId = nil
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

        // 跨網路時的直連通道（見 `CloudCollabManager.sendRealtime`）。送到了就不必排離線佇列 ——
        // 持久化另有雲端資料夾負責。
        let viaDirect = jsonString(msg).map { CloudCollabManager.shared.sendRealtime($0) } ?? false
        if case .connected = status {
            sendJson(msg)
        } else if !viaDirect {
            offlineOplogQueue.append(msg)
            queuedOplogCount = offlineOplogQueue.count
        }
        return lamport
    }

    /// 從雲端直連收到的即時協同訊息（與中繼上的 `oplog` 同一份 JSON），交給與中繼相同的處理。
    func receiveRealtime(_ json: String) {
        guard let data = json.data(using: .utf8),
              var dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              (dict["type"] as? String) == "oplog" else { return }
        // 只收這個房間的：直連是以筆記本配對的，房號不同代表是另一場協同的殘留。
        if !currentRoomId.isEmpty, (dict["room_id"] as? String) != currentRoomId { return }
        dict["type"] = "peer_oplog"
        dict.removeValue(forKey: "seq") // 中繼的序號只屬於中繼
        if let text = jsonString(dict) { handleIncomingMessage(text) }
    }

    private func jsonString(_ dict: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - 書寫中即時串流（`live_ink`，見 CollabLiveInk.swift）

    /// 送出間隔：30 Hz。比這密對方畫不出差別，只是多耗電與頻寬。
    nonisolated static let liveInkInterval: CFTimeInterval = 1.0 / 30.0

    /// 連上房間、而且房間裡有別人：才值得記點送出。
    var isLiveInkReady: Bool {
        if case .connected = status, !peers.isEmpty { return true }
        return CloudCollabManager.shared.directPeers > 0
    }

    /// 送一段書寫中的點。**不配發時鐘、不排離線佇列**：它是暫態的，漏了就漏了，
    /// 正式筆畫（`ink_add`）提筆後照常送。種類以 `live_` 開頭，中繼不放進補發暫存。
    func sendLiveInk(_ payload: [String: Any]) {
        let (finalPayload, isEncrypted) = encryptPayload(payload)
        var msg: [String: Any] = [
            "type": "oplog",
            "room_id": currentRoomId,
            "user_id": currentUserId,
            "lamport": 0,
            "kind": "live_ink",
            "payload": finalPayload,
        ]
        if isEncrypted { msg["encrypted"] = true }
        if let text = jsonString(msg) { CloudCollabManager.shared.sendRealtime(text) }
        if case .connected = status { sendJson(msg) }
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
        webSocketTask?.send(jsonStr)
    }

    private func startListening() {
        guard let socket = webSocketTask else { return }
        socket.receive { [weak self] text, error in
            guard let self else { return }
            // 舊連線（已經換成新的一條）的回報不要再處理：會多排一次重連、或把新連線的狀態改掉。
            guard socket === self.webSocketTask else { return }
            if let text {
                if !text.isEmpty { self.handleIncomingMessage(text) }
                // 繼續持續監聽下一則訊息
                self.startListening()
                return
            }
            let failure = error ?? URLError(.networkConnectionLost)
            print("⚠️ WebSocket 接收中斷: \(failure.localizedDescription)")
            self.lastErrorMessage = L10n.errorText(failure)
            if !self.userInitiatedDisconnect {
                self.scheduleReconnect()
            } else {
                self.status = .disconnected
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
                LiveInkStore.shared.settle(userId: uid)
            }

        case "peer_oplog":
            guard let uid = json["user_id"] as? String,
                  let kind = json["kind"] as? String,
                  let rawPayload = json["payload"] as? [String: Any] else { return }
            let lamport = (json["lamport"] as? NSNumber)?.uint64Value ?? 0
            let isEncrypted = (json["encrypted"] as? Bool) ?? false
            if kind.hasPrefix("live_") {
                // 暫態：直接交給預覽層，不推進時鐘、不記 op id、不進編輯器的合併流程。
                if kind == "live_ink", let payload = decryptPayload(rawPayload, isEncrypted: isEncrypted) {
                    LiveInkStore.shared.receive(userId: uid, payload: payload)
                }
                return
            }
            if kind == "ink_add" { LiveInkStore.shared.settle(userId: uid) }
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
                        // 舊版中繼會把書寫中的預覽也存起來補發：早就過時了，不畫。
                        if kind.hasPrefix("live_") { continue }
                        deliver(userId: uid, kind: kind, rawPayload: rawPayload, lamport: lamport, isEncrypted: isEncrypted)
                    }
                }
            }
            if (json["truncated"] as? Bool) == true { stateSyncNeeded.send(()) }

        case "room_closed":
            disconnect(userInitiated: false)
            if let nid = CloudCollabManager.shared.focusedId {
                CloudCollabManager.shared.stopSharing(nid)
            }

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
        roomNotebookId = nil
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
