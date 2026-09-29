//
//  FocusSyncController.swift
//  Kairumo
//
//  秒同步：**焦點通道**與**區網直連**（Apple）。
//
//  # 為什麼有第二條通道
//
//  `AutoSyncController` 排的是整庫一輪：匯出每一本、changes.list、中繼資料、
//  逐本同步、匯入、垃圾回收。成本跟筆記本數量成正比，而且一輪跑完才跑下一輪，
//  所以「改一個字要多久才到另一台」取決於整個資料庫有多大 —— 把輪詢週期調短
//  只會讓整輪更常空跑。
//
//  使用者感覺到慢的場景，幾乎都是**兩台裝置同時開著同一本筆記**。所以這裡另開
//  一條窄通道，只服務「現在開著的那一本」：
//
//  - 落筆之後 0.4 秒把增量寫進套件（編輯器）→ 0.25 秒去抖動 → 推
//  - 每秒問一次雲端（一個 changes.list），有變才拉這一本
//  - 區網上有另一台同帳號的裝置時，套件一寫好就**直接**傳給它，不等 Drive
//
//  節奏在核心的 `FfiFocusLane`，兩個平台照同一份；這裡只負責「發生了什麼」與
//  「現在該不該跑」。
//
//  # 與整庫通道的關係
//
//  共用同一份雲端快照（`CloudSync.makeSession()` 現在整個行程只有一個）與同一份
//  資料格式，**不共用任何排程狀態**。兩條通道只在「同一本筆記本的套件目錄」上會
//  撞在一起，所以核心有一把每本一把的鎖（`NotebookLock`）：整庫通道遇到焦點
//  通道拿著的那一本就略過（同步是冪等的，下一輪再看），匯入則等它放鎖。
//
//  # 時間用單調時鐘
//
//  與 `AutoSyncController` 相同：`systemUptime`，不是 `Date()`。
//

import Foundation
import Network
#if canImport(UIKit)
    import UIKit
#endif

@MainActor
public final class FocusSyncController: ObservableObject {
    public static let shared = FocusSyncController()

    /// 目前有幾台區網對端直連中。介面可以顯示「區網直連」。
    @Published public private(set) var lanPeerCount = 0
    /// 最近一次**有工作**的一輪的總耗時（毫秒）。給同步醫生看。
    @Published public private(set) var lastWorkRoundMs = 0

    private let lane = FfiFocusLane.create()
    private var store: SyncableNotebookStore?
    private var deviceId: UInt32 = 0
    private var started = false
    private var wake: Task<Void, Never>?
    private var link: LanLink?
    private var lanStarting = false
    /// 區網收到東西之後的匯入要一個一個來，而且合併成一次。
    private var lanImporting = false
    private var lanImportQueue: [String] = []
    private var lastPersistMs: UInt64 = 0

    private var nowMs: UInt64 {
        UInt64(ProcessInfo.processInfo.systemUptime * 1000)
    }

    private init() {}

    // MARK: - 啟動與事件

    /// App 啟動時呼叫一次（`AutoSyncController.start` 之後）。
    func start(store: SyncableNotebookStore, deviceId: UInt32) {
        self.store = store
        self.deviceId = deviceId
        guard !started else { return }
        started = true
        #if canImport(UIKit)
            NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.lane.noteRemoteHint(nowMs: self?.nowMs ?? 0)
                    self?.reschedule()
                    self?.ensureLan()
                }
            }
            // iOS 進背景就會凍結 socket；先收掉，回來再建。
            NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.stopLan() }
            }
        #endif
        ensureLan()
    }

    /// 打開／離開一本筆記時呼叫。`nil` = 回到首頁。
    public func setFocus(_ notebookId: String?) {
        lane.setFocus(notebookId: notebookId?.lowercased(), nowMs: nowMs)
        link?.setFocused(notebookId?.lowercased())
        reschedule()
        if notebookId != nil { ensureLan() }
    }

    /// 焦點筆記本存檔完成（**落盤之後**）。
    public func noteLocalEdit() {
        lane.noteLocalEdit(nowMs: nowMs)
        reschedule()
    }

    /// 重新登入了。
    public func noteSignedIn() {
        lane.noteSignedIn(nowMs: nowMs)
        reschedule()
        ensureLan()
    }

    // MARK: - 排程

    /// 排一次「到點再問」。每次事件之後、每輪結束之後都重排，舊的那個作廢。
    ///
    /// 不用固定週期的計時器：沒有焦點筆記本時完全不醒來（首頁、進背景），
    /// 有的時候則精確地睡到下一個該動的時間點。
    private func reschedule() {
        wake?.cancel()
        let due = lane.nextDueInMs(nowMs: nowMs)
        guard due != UInt64.max else { return }
        wake = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: due * 1_000_000)
            guard !Task.isCancelled else { return }
            self?.pump()
        }
    }

    private func pump() {
        guard let store, let run = lane.poll(nowMs: nowMs) else {
            reschedule()
            return
        }
        Task { @MainActor in
            let outcome = await runRound(run, store: store)
            lane.finish(notebookId: run.notebookId, outcome: outcome, nowMs: nowMs)
            reschedule()
        }
    }

    private func runRound(_ run: FfiFocusRun, store: SyncableNotebookStore) async -> FfiFocusOutcome {
        guard await GoogleAuth.shared.isSignedIn else { return .needsReauth }
        // 重置雲端／回收正在動整個雲端：這時候推東西上去只會被它們半途蓋掉。
        let holder = syncGateHolder()
        if holder == "wipe-cloud" || holder == "reclaim" { return .busy }
        guard let session = await CloudSync.makeSession() else { return .needsReauth }
        guard let ticket = NotebookLock.tryEnter(run.notebookId, label: "focus") else {
            return .busy
        }
        defer { NotebookLock.leave(run.notebookId, ticket: ticket) }

        let link = self.link
        let report = await NotebookSyncCoordinator.runFocusRound(
            store: store,
            deviceId: deviceId,
            notebookId: run.notebookId,
            push: run.push,
            session: session,
            afterExport: { link?.announce(run.notebookId) }
        )

        if !report.ok {
            SyncLogger.logAsync(
                "【焦點同步】\(run.notebookId.prefix(8))… 失敗：\(report.error)",
                source: .googleDrive
            )
            if report.needsReauth {
                await GoogleAuth.shared.signOut()
                return .needsReauth
            }
            return .transient
        }

        let didWork = report.hadWork || report.downloaded > 0 || report.uploaded > 0
        if didWork {
            // 量出來才知道慢在哪：只有真的做了事的那幾輪才寫，閒置輪詢每秒一次不能洗版。
            let total = report.exportMs + report.driveMs + report.importMs
            lastWorkRoundMs = total
            SyncLogger.logAsync(
                "【焦點同步】\(run.notebookId.prefix(8))… 上傳 \(report.uploaded)、下載 \(report.downloaded)"
                    + "（匯出 \(report.exportMs)ms、雲端 \(report.driveMs)ms、匯入 \(report.importMs)ms）",
                source: .googleDrive
            )
            for warning in report.warnings {
                SyncLogger.logAsync(
                    "【焦點同步】\(run.notebookId.prefix(8))… \(warning)", source: .googleDrive
                )
            }
            // 快照落地，但不要每輪都存 —— 它可能有幾千筆，序列化不便宜。
            if nowMs - lastPersistMs > 15_000 {
                lastPersistMs = nowMs
                await CloudSync.persist(session)
            }
        }

        if report.downloaded > 0 {
            AutoSyncController.shared.noteRemoteActivity()
            return .pulled
        }
        // 雲端有**別的**東西動了（別本筆記、索引）而這一本沒事：叫整庫通道去看。
        // 用 `remoteChanges`（快照真的改變的）而不是原始變更數 —— 自己剛上傳的
        // 檔案也會出現在 changes.list，不能因為它就叫醒整庫。
        if report.remoteChanges > 0, !report.hadWork {
            AutoSyncController.shared.request(.periodic)
        }
        return .success
    }

    // MARK: - 區網直連

    /// 已登入、有焦點、App 在前景時建立區網節點。**失敗一律安靜略過** ——
    /// 區網是加法，沒有它 Drive 那條路照常運作。
    private func ensureLan() {
        guard store != nil, link == nil, !lanStarting else { return }
        lanStarting = true
        Task { @MainActor [weak self] in
            defer { self?.lanStarting = false }
            guard let self else { return }
            guard await GoogleAuth.shared.isSignedIn,
                  let account = await GoogleAuth.shared.accountEmail
            else { return }

            // 金鑰以雲端為準：兩台裝置同時第一次建立時可能各握著不同的一把，
            // 而握手失敗是靜默的。每次啟動讀一次（一個 GET）就會收斂。
            var key: Data?
            if let session = await CloudSync.makeSession() {
                let result = await Task.detached(priority: .utility) { session.lanKey() }.value
                if result.ok { key = result.key }
            }
            if let key {
                LanKeychain.save(key, account: account)
            } else {
                key = LanKeychain.load(account: account)
            }
            guard let key, let store = self.store else { return }
            do {
                let link = try LanLink(
                    key: key, deviceId: self.deviceId,
                    packagesDirectory: store.syncPackagesDirectory,
                    owner: self
                )
                link.setFocused(self.lane.focused())
                self.link = link
                link.start()
            } catch {
                SyncLogger.logAsync("【區網直連】啟動失敗：\(error)", source: .googleDrive)
            }
        }
    }

    private func stopLan() {
        link?.stop()
        link = nil
        lanPeerCount = 0
    }

    fileprivate func lanPeersChanged(_ count: Int) {
        lanPeerCount = count
        if count > 0 {
            SyncLogger.logAsync("【區網直連】已連上 \(count) 台裝置", source: .googleDrive)
        }
    }

    /// 區網對端把新檔案寫進了套件。
    fileprivate func lanReceived(_ notebookId: String) {
        let id = notebookId.lowercased()
        if !lanImportQueue.contains(id) { lanImportQueue.append(id) }
        guard !lanImporting else { return }
        lanImporting = true
        Task { @MainActor [weak self] in
            await self?.drainLanImports()
        }
    }

    private func drainLanImports() async {
        defer { lanImporting = false }
        while let id = lanImportQueue.first {
            lanImportQueue.removeFirst()
            guard let store else { continue }
            // 焦點通道正在跑這一本的話等它放鎖；它自己也會在有下載時匯入，
            // 但區網寫進去的檔案它不知道，所以這裡不能略過。
            guard let ticket = await NotebookLock.enter(id, label: "lan-import", waitMs: 8_000)
            else {
                SyncLogger.logAsync(
                    "【區網直連】\(id.prefix(8))… 忙碌中，稍後再匯入", source: .googleDrive
                )
                lanImportQueue.append(id)
                try? await Task.sleep(nanoseconds: 500_000_000)
                continue
            }
            let started = ContinuousClock.now
            let ok = await NotebookSyncCoordinator.importReceived(
                store: store, deviceId: deviceId, notebookId: id
            )
            NotebookLock.leave(id, ticket: ticket)
            if ok {
                let parts = started.duration(to: ContinuousClock.now).components
                SyncLogger.logAsync(
                    "【區網直連】\(id.prefix(8))… 收到並匯入（\(parts.seconds * 1000 + parts.attoseconds / 1_000_000_000_000_000)ms）",
                    source: .googleDrive
                )
                AutoSyncController.shared.noteRemoteActivity()
            }
        }
    }
}

// MARK: - 區網金鑰的鑰匙圈

/// 區網金鑰放鑰匙圈，不放 UserDefaults：它是能讀到全部同步資料的同一個信任等級。
enum LanKeychain {
    private static let service = "com.kairumo.padnote.lankey"

    static func load(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data, data.count == 32
        else { return nil }
        return data
    }

    static func save(_ key: Data, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        // 先刪再加，理由同 `KeychainTokens.save`：SecItemUpdate 在項目不存在時
        // 會失敗，而且很容易被當成「存好了」。
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = key
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }
}

// MARK: - 區網連線（發現 + 宿主）

/// 區網節點的平台側：Bonjour 發現，以及核心要的宿主回呼。
///
/// **只有「發現」是平台的事** —— 協定、加密、去重、重連全部在核心的
/// `FfiLanNode`（兩個平台一份實作）。這裡只把「這個位址有一台同帳號的裝置」
/// 交給核心。
///
/// 核心從**自己的網路執行緒**呼叫這個類別的方法，所以它不是 `@MainActor`，
/// 而且不能在回呼裡做重活。
final class LanLink: FfiLanHost, @unchecked Sendable {
    private let node: FfiLanNode
    private let deviceId: UInt32
    private let packagesDirectory: URL
    private weak var owner: FocusSyncController?

    private let lock = NSLock()
    private var focused: String?
    /// 發現到的對端：裝置 id → (位址, 埠)。斷線之後照這份重連。
    private var known: [UInt32: (host: String, port: UInt16)] = [:]
    private var peerCount = 0

    private let queue = DispatchQueue(label: "com.kairumo.lan.discovery")
    private var browser: NWBrowser?
    private var service: NetService?
    private var retryTimer: DispatchSourceTimer?
    private var resolving = Set<String>()

    init(key: Data, deviceId: UInt32, packagesDirectory: URL, owner: FocusSyncController) throws {
        // 先建一個空殼再換上節點：`FfiLanNode.start` 需要 host 物件，
        // 而 host 需要節點。用兩段式初始化打破循環。
        self.deviceId = deviceId
        self.packagesDirectory = packagesDirectory
        self.owner = owner
        let proxy = LanHostProxy()
        self.node = try FfiLanNode.start(key: key, deviceId: deviceId, host: proxy)
        proxy.target = self
    }

    func start() {
        let tag = node.tagHex()
        let port = node.port()
        let deviceId = self.deviceId
        DispatchQueue.main.async { [weak self] in
            // NetService 需要 run loop，放在主執行緒。
            let service = NetService(
                domain: "local.", type: lanServiceType() + ".", name: "kairumo-\(deviceId)",
                port: Int32(port)
            )
            service.setTXTRecord(NetService.data(fromTXTRecord: [
                "d": Data("\(deviceId)".utf8),
                "t": Data(tag.utf8),
            ]))
            service.publish()
            self?.service = service
        }
        startBrowsing(tag: tag)
        startRetryTimer()
    }

    func stop() {
        retryTimer?.cancel()
        retryTimer = nil
        browser?.cancel()
        browser = nil
        let service = self.service
        DispatchQueue.main.async { service?.stop() }
        self.service = nil
        node.stop()
    }

    func setFocused(_ notebookId: String?) {
        lock.lock()
        focused = notebookId
        lock.unlock()
    }

    func announce(_ notebookId: String) {
        node.announce(notebookId: notebookId)
    }

    // MARK: 發現

    private func startBrowsing(tag: String) {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let type = lanServiceType()
        let browser = NWBrowser(
            for: .bonjourWithTXTRecord(type: type, domain: "local."), using: parameters
        )
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            for result in results {
                guard case let .bonjour(txt) = result.metadata,
                      let d = txt["d"], let peer = UInt32(d),
                      txt["t"] == tag,
                      peer != self.deviceId,
                      // 只有裝置 id 較小的一方主動連（見核心 `should_initiate`）。
                      lanShouldInitiate(myDevice: self.deviceId, peerDevice: peer)
                else { continue }
                self.resolve(result.endpoint, peer: peer)
            }
        }
        browser.start(queue: queue)
        self.browser = browser
    }

    /// Bonjour 給的是服務名稱，核心要的是位址與埠。開一條 NWConnection 讓系統
    /// 解析，`ready` 之後讀對端位址就立刻收掉。
    private func resolve(_ endpoint: NWEndpoint, peer: UInt32) {
        let key = "\(endpoint)"
        lock.lock()
        let busy = !resolving.insert(key).inserted
        lock.unlock()
        if busy { return }

        let connection = NWConnection(to: endpoint, using: .tcp)
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            switch state {
            case .ready:
                if case let .hostPort(host, port)? = connection.currentPath?.remoteEndpoint {
                    var address = "\(host)"
                    // 系統會在位址後面附介面名（`192.168.1.5%en0`）。IPv4 不需要它，
                    // 而 `getaddrinfo` 對它的處理各平台不一。
                    if case .ipv4 = host, let cut = address.firstIndex(of: "%") {
                        address = String(address[..<cut])
                    }
                    self.remember(peer: peer, host: address, port: port.rawValue)
                }
                connection.cancel()
                self.doneResolving(key)
            case .failed, .cancelled:
                self.doneResolving(key)
            default:
                break
            }
        }
        connection.start(queue: queue)
        // 解析不出來（對方剛離線）就不要永遠佔著這個標記。
        queue.asyncAfter(deadline: .now() + 5) { [weak self, weak connection] in
            connection?.cancel()
            self?.doneResolving(key)
        }
    }

    private func doneResolving(_ key: String) {
        lock.lock()
        resolving.remove(key)
        lock.unlock()
    }

    private func remember(peer: UInt32, host: String, port: UInt16) {
        lock.lock()
        known[peer] = (host, port)
        lock.unlock()
        node.connect(peerDevice: peer, host: host, port: port)
    }

    /// 斷線之後照已知的位址重連。核心的 `connect` 可以重複呼叫 ——
    /// 已經連著的直接略過。
    private func startRetryTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 3, repeating: 3)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let snapshot = self.known
            let connected = self.peerCount
            self.lock.unlock()
            guard connected < snapshot.count else { return }
            for (peer, address) in snapshot {
                self.node.connect(peerDevice: peer, host: address.host, port: address.port)
            }
        }
        timer.resume()
        retryTimer = timer
    }

    // MARK: FfiLanHost（核心的網路執行緒呼叫）

    func focusedNotebook() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return focused
    }

    func packagePath(notebookId: String) -> String? {
        let url = packagesDirectory.appending(path: "\(notebookId.lowercased()).padnote")
        // 沒有這本就回 nil：區網不負責建立整本筆記，那是整庫同步的事。
        return FileManager.default.fileExists(atPath: url.path) ? url.path : nil
    }

    func onReceived(notebookId: String, files _: UInt32) {
        Task { @MainActor [weak owner] in owner?.lanReceived(notebookId) }
    }

    func onPeersChanged(count: UInt32) {
        lock.lock()
        peerCount = Int(count)
        lock.unlock()
        Task { @MainActor [weak owner] in owner?.lanPeersChanged(Int(count)) }
    }
}

/// `FfiLanNode.start` 需要 host、host 需要節點：這個轉接把循環打破。
private final class LanHostProxy: FfiLanHost, @unchecked Sendable {
    weak var target: LanLink?

    func focusedNotebook() -> String? { target?.focusedNotebook() }
    func packagePath(notebookId: String) -> String? { target?.packagePath(notebookId: notebookId) }
    func onReceived(notebookId: String, files: UInt32) {
        target?.onReceived(notebookId: notebookId, files: files)
    }
    func onPeersChanged(count: UInt32) { target?.onPeersChanged(count: count) }
}
