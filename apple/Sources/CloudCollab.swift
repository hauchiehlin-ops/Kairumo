//
//  CloudCollab.swift
//  Kairumo
//
//  雲端協作：房主把一本筆記放進自己雲端硬碟的共享資料夾，協作者一鍵加入。
//
//  # 三條管道，一份資料
//
//  1. **共享雲端資料夾**（`FfiSyncSession.createShared`）：共同的底稿與跨網路通道。
//     每人寫自己的事件檔（檔名含裝置 id），不會互蓋；合併規則與一個人的多台裝置相同。
//  2. **點對點直連**（`FfiPeerLink`，WebRTC）：信令走共享資料夾，連上之後把剛寫出的
//     事件檔直接推給對方 —— 延遲從秒級降到百毫秒級。打不通就停在雲端輪詢。
//  3. **區網中繼**（`CollaborationManager`）：同一個網路時即時筆跡與游標。
//
//  三條送來的同一筆操作 id 相同，冪等；雲端是唯一的資料來源，其他兩條只是捷徑。
//
//  # 憑證
//
//  協作用 `drive.file`，與主帳號同步的 `drive.appdata` **分開存放**（Google 的挑選器規定
//  只能要 `drive.file` 一個權限）。協作者第一次加入時，在 Google 的挑選器裡確認那個資料夾。
//

import AuthenticationServices
import Combine
import Foundation
import UIKit

// MARK: - 協作憑證（drive.file）

/// 協作憑證存在 Keychain，帳號名與主帳號不同（`collab-drive-tokens`），依設定檔分開。
enum CollabKeychainTokens {
    private static let service = "com.kairumo.padnote.googleoauth"
    private static var account: String { ProfileContext.scopedAccount("collab-drive-tokens") }

    private struct Stored: Codable {
        let accessToken: String
        let refreshToken: String
        let expiresAtS: UInt64
    }

    static func load() -> FfiTokenSet {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let stored = try? JSONDecoder().decode(Stored.self, from: data)
        else { return FfiTokenSet(accessToken: "", refreshToken: "", expiresAtS: 0, error: "") }
        return FfiTokenSet(
            accessToken: stored.accessToken, refreshToken: stored.refreshToken,
            expiresAtS: stored.expiresAtS, error: "")
    }

    static func save(_ tokens: FfiTokenSet, previousRefresh: String) {
        let stored = Stored(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken.isEmpty ? previousRefresh : tokens.refreshToken,
            expiresAtS: tokens.expiresAtS)
        guard let data = try? JSONEncoder().encode(stored) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// 協作憑證的授權與換證。
@MainActor
final class CollabDriveAuth: NSObject, ObservableObject {
    // profile-scope: profile 憑證依設定檔存在 Keychain；切換時重讀
    static let shared = CollabDriveAuth()

    @Published private(set) var isAuthorized: Bool = !CollabKeychainTokens.load().refreshToken.isEmpty
    fileprivate var session: ASWebAuthenticationSession?

    struct Outcome {
        var ok = false
        var picked: [String] = []
        var error = ""
    }

    /// 開 Google 的授權畫面。`pickFolderId` 有值時是**挑選器**：預選那個資料夾，
    /// 使用者在同一個畫面裡登入、同意、確認。
    func authorize(pickFolderId: String = "", loginHint: String = "") async -> Outcome {
        let pkce = oauthNewPkce()
        guard !pkce.verifier.isEmpty else { return Outcome(error: "random_unavailable") }
        let urlString = oauthCollabAuthorizeUrl(
            platform: .apple, codeChallenge: pkce.challenge, state: pkce.state,
            loginHint: loginHint, pickFolderId: pickFolderId)
        guard let url = URL(string: urlString) else { return Outcome(error: "bad_authorize_url") }
        let callback: URL
        do {
            callback = try await present(url)
        } catch {
            return Outcome(error: "cancelled")
        }
        let parsed = oauthParseCallback(url: callback.absoluteString)
        guard parsed.error.isEmpty else { return Outcome(error: parsed.error) }
        guard parsed.state == pkce.state else { return Outcome(error: "state_mismatch") }
        guard !parsed.code.isEmpty else { return Outcome(error: "missing_code") }
        let body = oauthExchangeBody(platform: .apple, code: parsed.code, verifier: pkce.verifier)
        guard let json = await Self.post(body) else { return Outcome(error: "network_error") }
        let tokens = oauthParseTokenResponse(json: json, nowS: Self.nowS)
        guard tokens.error.isEmpty else { return Outcome(error: tokens.error) }
        CollabKeychainTokens.save(tokens, previousRefresh: CollabKeychainTokens.load().refreshToken)
        isAuthorized = true
        return Outcome(ok: true, picked: oauthParsePickedIds(url: callback.absoluteString))
    }

    /// 一個能用的 access token；必要時換證。nil = 要重新授權。
    func validAccessToken() async -> String? {
        let current = CollabKeychainTokens.load()
        if oauthIsAccessValid(tokens: current, nowS: Self.nowS) { return current.accessToken }
        let outcome = await Task.detached { Self.refreshOutcomeSync() }.value
        if outcome.fatal { isAuthorized = false }
        return outcome.token
    }

    /// 同步換證（背景 HTTP 執行緒收到 401 時用）。失敗**不會**影響主帳號。
    nonisolated static func refreshOutcomeSync() -> GoogleAuth.RefreshOutcome {
        let current = CollabKeychainTokens.load()
        guard !current.refreshToken.isEmpty else { return .init(token: nil, fatal: true) }
        guard let url = URL(string: oauthTokenEndpoint()) else { return .init(token: nil, fatal: false) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = oauthRefreshBody(platform: .apple, refreshToken: current.refreshToken)
            .data(using: .utf8)
        request.timeoutInterval = 15
        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var data: Data?
        URLSession.shared.dataTask(with: request) { d, _, _ in
            data = d
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + 16)
        guard let data, let json = String(data: data, encoding: .utf8) else {
            return .init(token: nil, fatal: false)
        }
        let refreshed = oauthParseTokenResponse(json: json, nowS: nowS)
        if !refreshed.error.isEmpty {
            let fatal = oauthNeedsReauth(error: refreshed.error) || refreshed.error.contains("invalid_grant")
            if fatal { CollabKeychainTokens.clear() }
            return .init(token: nil, fatal: fatal)
        }
        CollabKeychainTokens.save(refreshed, previousRefresh: current.refreshToken)
        return .init(token: refreshed.accessToken, fatal: false)
    }

    /// 給核心用的 HTTP（換證走協作憑證）。
    func makeHttp() async -> DriveHttpClient? {
        guard let token = await validAccessToken() else { return nil }
        return DriveHttpClient(accessToken: token, refresher: { Self.refreshOutcomeSync() })
    }

    func signOut() {
        CollabKeychainTokens.clear()
        isAuthorized = false
    }

    private func present(_ url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let lock = NSLock()
            nonisolated(unsafe) var done = false
            let finish: (Result<URL, Error>) -> Void = { result in
                lock.lock()
                defer { lock.unlock() }
                guard !done else { return }
                done = true
                continuation.resume(with: result)
            }
            let web = ASWebAuthenticationSession(
                url: url, callbackURLScheme: oauthUrlScheme(platform: .apple)
            ) { callback, error in
                if let callback { finish(.success(callback)) } else {
                    finish(.failure(error ?? CancellationError()))
                }
            }
            web.presentationContextProvider = self
            web.prefersEphemeralWebBrowserSession = false
            session = web
            if !web.start() { finish(.failure(CancellationError())) }
        }
    }

    private nonisolated static var nowS: UInt64 { UInt64(max(0, Date().timeIntervalSince1970)) }

    private static func post(_ body: String) async -> String? {
        guard let url = URL(string: oauthTokenEndpoint()) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)
        request.timeoutInterval = 30
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

extension CollabDriveAuth: ASWebAuthenticationPresentationContextProviding {
    // 與 `GoogleAuth` 相同：系統在主執行緒呼叫，類別本身是 MainActor。
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        return scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first ?? ASPresentationAnchor()
    }
}

// MARK: - 點對點的監聽轉接

private final class PeerListener: FfiPeerListener, @unchecked Sendable {
    let peer: UInt32
    weak var owner: CloudCollabManager?
    init(peer: UInt32, owner: CloudCollabManager) {
        self.peer = peer
        self.owner = owner
    }
    func onFrame(frame: Data) {
        let peer = self.peer
        Task { @MainActor [weak owner] in owner?.p2pReceived(frame, from: peer) }
    }
    func onState(state: FfiPeerState) {
        let peer = self.peer
        Task { @MainActor [weak owner] in owner?.p2pState(state, peer: peer) }
    }
}

// MARK: - 雲端協作管理

@MainActor
final class CloudCollabManager: ObservableObject {
    // profile-scope: profile 共享筆記清單依設定檔存在偏好設定；切換時重讀、停掉進行中的協作
    static let shared = CloudCollabManager()

    /// 這台裝置上的共享筆記。
    @Published private(set) var registry: [FfiSharedNotebook] = []
    /// 其他參與者現在在哪裡（同一本筆記）。
    @Published private(set) var presences: [FfiCloudPresence] = []
    /// 點對點直連中的對端數。
    @Published private(set) var directPeers = 0
    /// 最近一次的錯誤（語系鍵或已翻譯的文字）。
    @Published var lastError: String?
    /// 進行中的長工作（分享、加入）的說明。
    @Published private(set) var busyMessage: String?
    /// 外面送進來、等使用者確認的邀請（掃 QR Code、點連結）。
    @Published var pendingInvite: FfiCollabInviteV2?

    private let registryKey = "kairumo.cloudCollab.registry"
    private var sessions: [String: FfiSyncSession] = [:]
    private var focusedId: String?
    private var loop: Task<Void, Never>?
    private var lastRemoteChange = Date.distantPast
    private var lastLocalEdit = Date.distantPast
    private var localDirty = false
    private var lastPresenceAt = Date.distantPast
    private var myPage: UInt32 = 0
    private var mySelection = ""
    private var links: [UInt32: FfiPeerLink] = [:]
    private var linkOpenedAt: [UInt32: Date] = [:]
    private var connectedPeers: Set<UInt32> = []
    private var failedAt: [UInt32: Date] = [:]
    private var sentSizes: [String: UInt64] = [:]
    private var importPending = false

    private var deviceId: UInt32 { NotebookMigration.deviceId }
    private var store: SyncableNotebookStore { NotebookStore.shared }

    private init() {
        reloadRegistry()
    }

    // MARK: 清單

    private var registryJson: String {
        get { ProfileDefaults.current.string(forKey: registryKey) ?? "" }
        set {
            ProfileDefaults.current.set(newValue, forKey: registryKey)
            registry = sharedRegistryList(json: newValue)
        }
    }

    func reloadRegistry() {
        registry = sharedRegistryList(json: registryJson)
    }

    func shared(_ notebookId: String) -> FfiSharedNotebook? {
        sharedRegistryFind(json: registryJson, notebookId: notebookId)
    }

    private func packagePath(_ notebookId: String) -> String {
        store.syncPackagesDirectory.appending(path: "\(notebookId.lowercased()).padnote").path
    }

    private func session(for entry: FfiSharedNotebook) async -> FfiSyncSession? {
        if let s = sessions[entry.folderId] { return s }
        guard let http = await CollabDriveAuth.shared.makeHttp() else { return nil }
        let s = FfiSyncSession.createShared(http: http, folderId: entry.folderId, remoteIndexJson: "")
        sessions[entry.folderId] = s
        return s
    }

    // MARK: 房主：分享

    /// 把一本筆記分享出去。`email` 為空 = 「知道連結的人都能編輯」。回傳邀請連結。
    func share(notebookId: String, title: String, email: String) async -> String? {
        lastError = nil
        busyMessage = L10n.t("cloud_collab_sharing")
        defer { busyMessage = nil }
        if !CollabDriveAuth.shared.isAuthorized {
            let auth = await CollabDriveAuth.shared.authorize(loginHint: GoogleAuth.shared.accountEmail ?? "")
            guard auth.ok else {
                if auth.error != "cancelled" { lastError = L10n.t("cloud_collab_err_reauth") }
                return nil
            }
        }
        guard let http = await CollabDriveAuth.shared.makeHttp() else {
            lastError = L10n.t("cloud_collab_err_reauth")
            return nil
        }
        // 1. 資料夾：已經分享過就沿用。
        var entry = shared(notebookId)
        if entry == nil {
            let created = await Task.detached { collabDriveCreateFolder(http: http, title: title) }.value
            guard created.ok else {
                lastError = created.needsReauth ? L10n.t("cloud_collab_err_reauth") : L10n.coreText(created.error)
                return nil
            }
            entry = FfiSharedNotebook(
                notebookId: notebookId, folderId: created.id, roomId: "", keyBase64: "",
                role: "owner", title: title)
        }
        guard var entry else { return nil }
        // 2. 權限。
        let folder = entry.folderId
        let mail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let granted = await Task.detached {
            mail.isEmpty
                ? collabDriveGrantLink(http: http, folderId: folder)
                : collabDriveGrant(http: http, folderId: folder, email: mail)
        }.value
        guard granted.ok else {
            lastError = granted.error == "invalid_email"
                ? L10n.t("cloud_collab_err_email") : L10n.coreText(granted.error)
            return nil
        }
        // 3. 即時房間（同一個網路時自動升級）：沒有就開一間。
        let collab = CollaborationManager.shared
        if case .disconnected = collab.status { collab.createRoom() }
        for _ in 0..<30 where collab.roomKeyBase64 == nil || collab.currentRoomId.isEmpty {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        entry.roomId = collab.currentRoomId
        entry.keyBase64 = collab.roomKeyBase64 ?? ""
        registryJson = sharedRegistryUpsert(json: registryJson, entry: entry)
        // 4. 把整本推上共享資料夾。
        guard let s = await session(for: entry) else { return nil }
        let report = await pushRound(entry: entry, session: s)
        guard report.ok else {
            lastError = report.error
            return nil
        }
        let files = UInt32(packageOpFileSizes(packagePath: packagePath(notebookId)).count)
        return inviteLink(for: entry, minFiles: files)
    }

    /// 這本共享筆記的邀請連結（含所有可用的即時中繼位址）。
    func inviteLink(for entry: FfiSharedNotebook, minFiles: UInt32 = 0) -> String {
        let collab = CollaborationManager.shared
        let servers = [collab.lanRelayAddress, collab.tailscaleRelayAddress].compactMap { $0 }
        return collabInviteLinkV2(invite: FfiCollabInviteV2(
            roomId: entry.roomId.isEmpty ? collab.currentRoomId : entry.roomId,
            keyBase64: entry.keyBase64.isEmpty ? (collab.roomKeyBase64 ?? "") : entry.keyBase64,
            servers: servers, notebookId: entry.notebookId, driveFolderId: entry.folderId,
            title: entry.title, minFiles: minFiles))
    }

    func members(of entry: FfiSharedNotebook) async -> [FfiDriveMember] {
        guard let http = await CollabDriveAuth.shared.makeHttp() else { return [] }
        let folder = entry.folderId
        let result = await Task.detached { collabDriveMembers(http: http, folderId: folder) }.value
        return result.members
    }

    func revoke(_ member: FfiDriveMember, in entry: FfiSharedNotebook) async -> Bool {
        guard let http = await CollabDriveAuth.shared.makeHttp() else { return false }
        let folder = entry.folderId
        let pid = member.permissionId
        return await Task.detached { collabDriveRevoke(http: http, folderId: folder, permissionId: pid) }.value.ok
    }

    /// 不再共享（這台不再同步這個資料夾；雲端資料夾與他人的副本不動）。
    func stopSharing(_ notebookId: String) {
        if focusedId?.lowercased() == notebookId.lowercased() { setFocus(nil) }
        registryJson = sharedRegistryRemove(json: registryJson, notebookId: notebookId)
    }

    // MARK: 協作者：加入

    /// 收到邀請（`kairumo://collab?…&drive=…`）。有雲端資料夾的才由這裡處理。
    @discardableResult
    func offer(_ link: String) -> Bool {
        let invite = collabParseInviteV2(text: link)
        guard !invite.driveFolderId.isEmpty, !invite.notebookId.isEmpty else { return false }
        pendingInvite = invite
        return true
    }

    /// 一鍵加入：Google 挑選器確認資料夾 → 權限探測 → 整本下載 → 匯入 → 打開 → 自動接上即時中繼。
    func join(_ invite: FfiCollabInviteV2) async -> Bool {
        lastError = nil
        busyMessage = L10n.t("cloud_collab_joining")
        defer { busyMessage = nil }
        let auth = await CollabDriveAuth.shared.authorize(pickFolderId: invite.driveFolderId)
        guard auth.ok else {
            if auth.error != "cancelled" { lastError = L10n.t("cloud_collab_err_reauth") }
            return false
        }
        guard let http = await CollabDriveAuth.shared.makeHttp() else {
            lastError = L10n.t("cloud_collab_err_reauth")
            return false
        }
        let folder = invite.driveFolderId
        let minFiles = invite.minFiles
        let probe = await Task.detached {
            collabDriveProbe(http: http, folderId: folder, expectedMinFiles: minFiles)
        }.value
        guard probe.access == .ready else {
            lastError = L10n.t(probe.messageKey)
            return false
        }
        let entry = FfiSharedNotebook(
            notebookId: invite.notebookId, folderId: folder, roomId: invite.roomId,
            keyBase64: invite.keyBase64, role: "editor",
            title: invite.title.isEmpty ? probe.folderName : invite.title)
        registryJson = sharedRegistryUpsert(json: registryJson, entry: entry)
        guard let s = await session(for: entry) else { return false }
        let id = invite.notebookId
        let path = packagePath(id)
        let alreadyHere = store.syncNotebooks.contains { $0.id.caseInsensitiveCompare(id) == .orderedSame }
        if !alreadyHere {
            let title = entry.title
            let cloned = await Task.detached {
                s.cloneNotebook(
                    packagePath: path, notebookId: id.lowercased(), title: title,
                    nowUnixMs: UInt64(Date().timeIntervalSince1970 * 1000))
            }.value
            guard cloned.ok else {
                lastError = L10n.coreText(cloned.error)
                return false
            }
            guard await NotebookSyncCoordinator.importSharedClone(
                store: store, deviceId: deviceId, notebookId: id)
            else {
                lastError = L10n.t("cloud_collab_err_retry")
                return false
            }
        }
        NotificationCenter.default.post(name: AppCommand.openNotebook, object: id)
        // 即時中繼：依自己的網路排序，逐一試，連上就停。
        Task { @MainActor in await self.connectRelay(invite) }
        return true
    }

    private func connectRelay(_ invite: FfiCollabInviteV2) async {
        guard !invite.roomId.isEmpty, !invite.servers.isEmpty else { return }
        let ordered = collabOrderServers(
            servers: invite.servers, myIpv4: { let a = LocalRelayServer.availableIPv4Addresses(); return [a.lan, a.tailscale].compactMap { $0 } }())
        let collab = CollaborationManager.shared
        let timeout = UInt64(collabConnectTimeoutMs())
        for server in ordered {
            let link = collabInviteLinkV2(invite: FfiCollabInviteV2(
                roomId: invite.roomId, keyBase64: invite.keyBase64, servers: [server],
                notebookId: "", driveFolderId: "", title: "", minFiles: 0))
            collab.joinRoom(roomId: link)
            var waited: UInt64 = 0
            while waited < timeout {
                if case .connected = collab.status { return }
                try? await Task.sleep(nanoseconds: 100_000_000)
                waited += 100
            }
            if case .connected = collab.status { return }
            collab.disconnect()
        }
    }

    // MARK: 焦點與輪詢

    /// 打開／離開一本筆記。是共享筆記就開始雲端協作的輪詢與直連。
    func setFocus(_ notebookId: String?) {
        let next = notebookId.flatMap { shared($0) != nil ? $0 : nil }
        guard next?.lowercased() != focusedId?.lowercased() else { return }
        loop?.cancel()
        loop = nil
        closeLinks()
        presences = []
        focusedId = next
        sentSizes = [:]
        guard let next, let entry = shared(next) else { return }
        lastRemoteChange = Date()
        loop = Task { @MainActor [weak self] in await self?.run(entry) }
    }

    func noteLocalEdit() {
        guard focusedId != nil else { return }
        lastLocalEdit = Date()
        localDirty = true
        // 停筆一下再送（合併成一個檔），不必等下一次輪詢。
        let delay = UInt64(collabCloudFlushDelayMs())
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay * 1_000_000)
            self?.pushP2P()
        }
    }

    func notePresence(page: Int, selectedId: String?) {
        myPage = UInt32(max(0, page))
        mySelection = selectedId ?? ""
    }

    private var isForeground: Bool {
        UIApplication.shared.applicationState != .background
    }

    private func run(_ entry: FfiSharedNotebook) async {
        while !Task.isCancelled {
            guard let s = await session(for: entry) else {
                lastError = L10n.t("cloud_collab_err_reauth")
                return
            }
            let relayUp: Bool = { if case .connected = CollaborationManager.shared.status { return true }; return false }()
            let interval = collabCloudPollMs(
                foreground: isForeground, relayConnected: relayUp || !connectedPeers.isEmpty,
                secsSinceRemoteChange: UInt32(min(Date().timeIntervalSince(lastRemoteChange), 1e6)),
                secsSinceLocalEdit: UInt32(min(Date().timeIntervalSince(lastLocalEdit), 1e6)))
            if interval > 0, !CanvasTouchState.isActivelyInking() {
                let report = await pushRound(entry: entry, session: s)
                if report.downloaded > 0 { lastRemoteChange = Date() }
                if report.needsReauth { lastError = L10n.t("cloud_collab_err_reauth") }
                await presenceTick(entry: entry, session: s)
                if !relayUp { await p2pTick(entry: entry, session: s) }
            }
            let wait = interval > 0 ? UInt64(interval) : 5_000
            try? await Task.sleep(nanoseconds: wait * 1_000_000)
        }
    }

    private func pushRound(entry: FfiSharedNotebook, session s: FfiSyncSession) async -> NotebookSyncCoordinator.FocusReport {
        guard let ticket = await NotebookLock.enter(entry.notebookId, label: "cloud-collab", waitMs: 3_000) else {
            return NotebookSyncCoordinator.FocusReport()
        }
        defer { NotebookLock.leave(entry.notebookId, ticket: ticket) }
        let push = localDirty
        localDirty = false
        return await NotebookSyncCoordinator.runFocusRound(
            store: store, deviceId: deviceId, notebookId: entry.notebookId, push: push,
            session: s, afterExport: { Task { @MainActor in CloudCollabManager.shared.pushP2P() } })
    }

    // MARK: 在場

    private func presenceTick(entry: FfiSharedNotebook, session s: FfiSyncSession) async {
        let now = UInt64(Date().timeIntervalSince1970 * 1000)
        if Date().timeIntervalSince(lastPresenceAt) * 1000 >= Double(collabPresenceIntervalMs()) {
            lastPresenceAt = Date()
            let me = FfiCloudPresence(
                deviceId: deviceId, userName: AccountManager.shared.profile.displayName,
                colorHex: CollaborationManager.shared.myColorHex, pageIndex: myPage,
                selectedId: mySelection, updatedMs: now)
            let json = collabPresenceEncode(p: me)
            let path = collabPresencePath(deviceId: deviceId)
            _ = await Task.detached { s.putAux(path: path, data: Data(json.utf8)) }.value
            sendToPeers(p2pEncodePresence(json: json))
        }
        let files = await Task.detached { s.readAux(prefix: "presence/") }.value
        let mine = deviceId
        var seen: [UInt32: FfiCloudPresence] = Dictionary(uniqueKeysWithValues: presences.map { ($0.deviceId, $0) })
        for f in files {
            if let p = collabPresenceDecode(json: String(decoding: f.data, as: UTF8.self), nowMs: now),
               p.deviceId != mine,
               (seen[p.deviceId]?.updatedMs ?? 0) <= p.updatedMs {
                seen[p.deviceId] = p
            }
        }
        presences = seen.values
            .filter { collabPresenceDecode(json: collabPresenceEncode(p: $0), nowMs: now) != nil }
            .sorted { $0.userName < $1.userName }
    }

    // MARK: 點對點

    private struct Signal: Codable {
        let t: Double
        let sdp: String
    }

    private func p2pTick(entry: FfiSharedNotebook, session s: FfiSyncSession) async {
        let me = deviceId
        let files = await Task.detached { s.readAux(prefix: "signal/") }.value
        func signal(_ path: String) -> String? {
            guard let f = files.first(where: { $0.path == path }),
                  let sig = try? JSONDecoder().decode(Signal.self, from: f.data),
                  Date().timeIntervalSince1970 - sig.t < 90 else { return nil }
            return sig.sdp
        }
        for peer in presences.map(\.deviceId) {
            if connectedPeers.contains(peer) { continue }
            if let failed = failedAt[peer], Date().timeIntervalSince(failed) < 60 { continue }
            if p2pShouldOffer(myDevice: me, peerDevice: peer) {
                if let link = links[peer] {
                    // 等 answer；太久沒回就放棄這一次。
                    if let answer = signal(p2pSignalPath(fromDevice: peer, toDevice: me, answer: true)) {
                        _ = await Task.detached { link.applyAnswer(answerJson: answer) }.value
                    } else if Date().timeIntervalSince(linkOpenedAt[peer] ?? .distantPast) > 60 {
                        dropLink(peer, failed: true)
                    }
                    continue
                }
                guard let link = p2pNewLink(stunUrls: [], listener: PeerListener(peer: peer, owner: self)) else { continue }
                links[peer] = link
                linkOpenedAt[peer] = Date()
                let offer = await Task.detached { link.createOffer(timeoutMs: 4_000) }.value
                guard !offer.isEmpty, let data = try? JSONEncoder().encode(
                    Signal(t: Date().timeIntervalSince1970, sdp: offer)) else { continue }
                let path = p2pSignalPath(fromDevice: me, toDevice: peer, answer: false)
                _ = await Task.detached { s.putAux(path: path, data: data) }.value
            } else if links[peer] == nil,
                      let offer = signal(p2pSignalPath(fromDevice: peer, toDevice: me, answer: false)) {
                guard let link = p2pNewLink(stunUrls: [], listener: PeerListener(peer: peer, owner: self)) else { continue }
                links[peer] = link
                linkOpenedAt[peer] = Date()
                let answer = await Task.detached { link.acceptOffer(offerJson: offer, timeoutMs: 4_000) }.value
                guard !answer.isEmpty, let data = try? JSONEncoder().encode(
                    Signal(t: Date().timeIntervalSince1970, sdp: answer)) else { continue }
                let path = p2pSignalPath(fromDevice: me, toDevice: peer, answer: true)
                _ = await Task.detached { s.putAux(path: path, data: data) }.value
            }
        }
    }

    fileprivate func p2pState(_ state: FfiPeerState, peer: UInt32) {
        switch state {
        case .connected:
            connectedPeers.insert(peer)
            sentSizes = [:] // 新連上的對端：把目前所有事件檔推一次（對方已有的會被忽略）
            pushP2P()
        case .failed, .closed:
            dropLink(peer, failed: state == .failed)
        case .connecting:
            break
        }
        directPeers = connectedPeers.count
    }

    fileprivate func p2pReceived(_ frame: Data, from peer: UInt32) {
        guard let id = focusedId else { return }
        switch p2pDecodeFrame(frame: frame) {
        case .opFile(let notebookId, let name, let data):
            guard notebookId.lowercased() == id.lowercased() else { return }
            if packageIngestOpFile(packagePath: packagePath(id), name: name, data: data) {
                lastRemoteChange = Date()
                scheduleImport(id)
            }
        case .presence(let json):
            let now = UInt64(Date().timeIntervalSince1970 * 1000)
            if let p = collabPresenceDecode(json: json, nowMs: now), p.deviceId != deviceId {
                presences = (presences.filter { $0.deviceId != p.deviceId } + [p]).sorted { $0.userName < $1.userName }
            }
        case .unknown:
            break
        }
    }

    /// 收到的事件檔合併成一次匯入（連續收到好幾個檔時不要匯入好幾次）。
    private func scheduleImport(_ id: String) {
        guard !importPending else { return }
        importPending = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard let self else { return }
            self.importPending = false
            guard let ticket = await NotebookLock.enter(id, label: "p2p-import", waitMs: 3_000) else { return }
            _ = await NotebookSyncCoordinator.importReceived(store: self.store, deviceId: self.deviceId, notebookId: id)
            NotebookLock.leave(id, ticket: ticket)
        }
    }

    /// 把新的或變長的事件檔推給所有直連的對端。
    func pushP2P() {
        guard let id = focusedId, !connectedPeers.isEmpty else { return }
        let path = packagePath(id)
        let previous = sentSizes
        let peers = connectedPeers.compactMap { links[$0] }
        Task.detached(priority: .userInitiated) {
            var sent = previous
            for f in packageOpFileSizes(packagePath: path) where f.size > (previous[f.name] ?? 0) {
                let data = packageReadOpFile(packagePath: path, name: f.name)
                let frame = p2pEncodeOpFile(notebookId: id.lowercased(), name: f.name, data: data)
                guard !frame.isEmpty else { continue } // 太大：交給雲端
                for link in peers { _ = link.send(frame: frame) }
                sent[f.name] = f.size
            }
            let result = sent
            await MainActor.run { CloudCollabManager.shared.sentSizes = result }
        }
    }

    private func sendToPeers(_ frame: Data) {
        let peers = connectedPeers.compactMap { links[$0] }
        guard !peers.isEmpty else { return }
        Task.detached { for link in peers { _ = link.send(frame: frame) } }
    }

    private func dropLink(_ peer: UInt32, failed: Bool) {
        if let link = links.removeValue(forKey: peer) { Task.detached { link.close() } }
        connectedPeers.remove(peer)
        if failed { failedAt[peer] = Date() }
        directPeers = connectedPeers.count
    }

    private func closeLinks() {
        for peer in Array(links.keys) { dropLink(peer, failed: false) }
        failedAt = [:]
    }
}

// MARK: - 設定檔切換

extension CloudCollabManager: ProfileScoped {
    func resetForProfileSwitch() {
        setFocus(nil)
        sessions = [:]
        pendingInvite = nil
        lastError = nil
        reloadRegistry()
    }
}

extension CollabDriveAuth: ProfileScoped {
    func resetForProfileSwitch() {
        session = nil
        refreshAuthorizedFlag()
    }

    func refreshAuthorizedFlag() {
        isAuthorized = !CollabKeychainTokens.load().refreshToken.isEmpty
    }
}
