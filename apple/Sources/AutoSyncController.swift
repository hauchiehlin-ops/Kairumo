//
//  AutoSyncController.swift
//  Kairumo
//
//  自動同步的觸發器（P2）。
//
//  # 之前缺的是什麼
//
//  同步流程本身早就寫好了，但**沒有人叫它**：`runDrive` 只掛在首頁那三顆
//  按鈕上。使用者在 iPad 寫完一段、拿起 Android 打開，看到的是舊內容 ——
//  不是同步壞了，是根本沒有跑。
//
//  「即時」不是把間隔調短，是**事件驅動**：
//
//  - 進前景、登入完成、網路恢復 → 立刻跑
//  - 本機存檔 → 去抖動 1.5 秒（使用者還在寫字時每一筆都推只是浪費電，
//    而且會拖慢正在編輯的那一本）
//  - 前景時每 60 秒整庫同步一次；**一輪週期同步發現與上一輪相比沒有變動，
//    就停止週期同步**，直到下一個事件（進前景、存檔、登入、網路恢復、
//    別的通道收到對方的東西）。開著的那一本走焦點通道，不靠這一檔
//
//  # 策略不在這裡
//
//  去抖動多久、退避多久、同時能跑幾個、暫時性錯誤與要重新登入怎麼分 ——
//  全部在核心的 `FfiSyncScheduler`，Android 用的是同一個物件。
//  兩邊各寫一份的話，使用者看到的不是「排程策略不同」，是「Android 比較慢」。
//
//  # 時間用單調時鐘
//
//  `request`/`tick` 收的是 `ProcessInfo.systemUptime` 換算的毫秒，
//  不是 `Date()`。使用者改時區或系統校時會讓牆上時間往前或往後跳，
//  而排程會因此卡住或暴衝。
//

import Foundation
import Network
#if canImport(BackgroundTasks)
    import BackgroundTasks
#endif
#if canImport(UIKit)
    import UIKit
#endif

@MainActor
public final class AutoSyncController: ObservableObject {
    public static let shared = AutoSyncController()

    /// 目前正在跑一輪同步。介面用它顯示轉圈。
    @Published public private(set) var isSyncing = false
    /// 最後一次的結果訊息（給「同步醫生」看）。
    @Published public private(set) var lastMessage: String = ""
    /// 停在「要重新登入」。介面該顯示登入提示，而不是「同步失敗」。
    @Published public private(set) var needsSignIn = false
    /// 最後一次成功同步的單調時間（毫秒）。
    @Published public private(set) var lastSuccessAt: UInt64?
    /// 最近一次成功同步的時間（供 UI 統一即時重繪）。
    @Published public private(set) var lastGoogleSyncDate: Date? = {
        let raw = UserDefaults.standard.double(forKey: "kairumo.sync.lastGoogleAt")
        return raw > 0 ? Date(timeIntervalSince1970: raw) : nil
    }()

    public func noteGoogleSynced(at date: Date = Date()) {
        lastGoogleSyncDate = date
    }

    /// 雲端清單裡有條目、卻沒有任何操作記錄的筆記本（id → 標題）。
    ///
    /// 本機沒有副本，所以清單上看不到、也就**沒有地方可以刪它**；而每一輪同步都
    /// 會對它報同一個錯。面板用這份名單提供「從雲端移除」。
    @Published public private(set) var emptyCloudNotebooks: [EmptyCloudNotebook] = []

    public struct EmptyCloudNotebook: Identifiable, Equatable {
        public let id: String
        public let title: String
    }

    func setEmptyCloudNotebooks(_ items: [EmptyCloudNotebook]) {
        if items != emptyCloudNotebooks { emptyCloudNotebooks = items }
    }

    public func setSyncing(_ syncing: Bool, message: String? = nil) {
        isSyncing = syncing
        if let message {
            lastMessage = message
        }
    }

    private let scheduler = FfiSyncScheduler.create()
    private var timer: Timer?
    private var monitor: NWPathMonitor?
    private var wasOnline = true
    private var store: SyncableNotebookStore?
    private var deviceId: UInt32 = 0
    private var started = false
    /// 最近一輪有沒有上傳、下載或新增東西。排程器據此決定要不要「安靜下來」
    /// （週期觸發的一輪沒有變動 → 不再排下一個週期）。
    private var roundChanged = true

    /// 單調時鐘的毫秒數。**不要用 `Date()`** —— 系統校時會讓它往回跳。
    private var nowMs: UInt64 {
        UInt64(ProcessInfo.processInfo.systemUptime * 1000)
    }

    private init() {}

    /// App 啟動時呼叫一次。
    func start(store: SyncableNotebookStore, deviceId: UInt32) {
        self.store = store
        self.deviceId = deviceId
        // 焦點通道與區網直連（秒同步）。整庫這條通道照舊，兩者互不依賴。
        FocusSyncController.shared.start(store: store, deviceId: deviceId)
        guard !started else { return }
        started = true

        // 前景心跳。間隔由核心給 —— 兩個平台照同一個數字。
        //
        // 心跳只是「問一下」，不是輪詢頻率：真正的節奏是核心的 60 秒週期，
        // 而且週期同步沒有變動就會安靜下來（見 `finishRound`）。
        // 心跳夠密，60 秒才不會實際變成 60～120 秒。
        startHeartbeat()

        startNetworkMonitor()
        observeLifecycle()
        // **背景任務的註冊不在這裡。** 見 `registerBackgroundTask()` ——
        // 它必須在 App 啟動完成之前呼叫，而 `start()` 是在畫面出現之後
        // 才被呼叫的。放在這裡會讓 App 一啟動就當掉。
        scheduleBackgroundTask()
        request(.foreground)
    }

    /// 啟動前景心跳（已經在跑就什麼也不做）。
    private func startHeartbeat() {
        guard timer == nil else { return }
        let interval = Double(syncHeartbeatIntervalMs()) / 1000.0
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.heartbeat() }
        }
        // 使用者捲動清單時 run loop 會切到 tracking mode，預設的計時器
        // 在那段時間完全不會觸發 —— 症狀是「一邊滑一邊就不同步了」。
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// 排程器休眠了（安靜之後連續兩次 8 分鐘守望掃描都沒有變化）：
    /// 停掉心跳計時器與背景更新排程。**不結束 App** —— iOS 不允許程式自己結束行程，
    /// 而且「同步沒有變化」不代表使用者沒在用。下一個事件會叫醒（見 `wakeSyncServices`）。
    private func sleepSyncServices() {
        timer?.invalidate()
        timer = nil
        #if canImport(BackgroundTasks) && !targetEnvironment(macCatalyst)
            guard !ProcessInfo.processInfo.isiOSAppOnMac else { return }
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.backgroundTaskId)
        #endif
    }

    /// 事件把休眠的同步服務叫醒：心跳與背景排程都重新開始。
    private func wakeSyncServices() {
        guard started, timer == nil else { return }
        startHeartbeat()
        scheduleBackgroundTask()
    }

    /// 背景同步的任務識別字。
    ///
    /// **必須與 `Info.plist` 的 `BGTaskSchedulerPermittedIdentifiers` 逐字相同。**
    /// 不一致時 iOS 不會報錯，只是那個任務永遠不會被喚醒 —— 而「永遠不會被
    /// 喚醒」與「有排但還沒輪到」在畫面上長得一模一樣。
    static let backgroundTaskId = "com.kairumo.padnote.sync.refresh"

    /// 送一個觸發事件進排程器。
    public func request(_ trigger: FfiSyncTrigger) {
        if trigger == .signedIn {
            FocusSyncController.shared.noteSignedIn()
        }
        scheduler.request(trigger: trigger, nowMs: nowMs)
        wakeSyncServices()
        needsSignIn = scheduler.isBlockedOnAuth()
        let due = scheduler.nextDueInMs(nowMs: nowMs)
        if due != UInt64.max, due > 0 {
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: due * 1_000_000)
                self?.pump()
            }
        } else {
            pump()
        }
    }

    /// 本機存檔之後呼叫。**會去抖動**，連續存檔只會推一次。
    public func noteLocalEdit() {
        request(.localEdit)
        // 開著的那一本走焦點通道，不必等整庫這一輪。
        FocusSyncController.shared.noteLocalEdit()
    }

    /// 焦點通道或區網直連**真的收到了對方的東西**。對方在動 ——
    /// 整庫通道若已安靜下來，要重新開始，其他筆記本的變動才不會等不到。
    public func noteRemoteActivity() {
        scheduler.noteRemoteChange(nowMs: nowMs)
        wakeSyncServices()
    }

    private func heartbeat() {
        scheduler.tick(nowMs: nowMs)
        pump()
    }

    /// 排程器說可以跑就跑一輪。
    private func pump() {
        guard let store else { return }
        guard scheduler.shouldStart(nowMs: nowMs) else { return }
        isSyncing = true
        Task { @MainActor in
            defer { isSyncing = false }
            let outcome = await runOneRound(store: store)
            scheduler.finishRound(outcome: outcome, changed: roundChanged, nowMs: nowMs)
            needsSignIn = scheduler.isBlockedOnAuth()
            if outcome == .success {
                lastSuccessAt = nowMs
            }
            if scheduler.isDormant() { sleepSyncServices() }
            // 這一輪結束後還有待辦（例如跑到一半又存了檔）就接著跑。
            scheduleNextWake()
        }
    }

    /// 排一次「到點再問」的喚醒。
    ///
    /// 每 100ms 醒來問一次也做得到，但在 iOS 上那是白白耗電。
    private func scheduleNextWake() {
        let due = scheduler.nextDueInMs(nowMs: nowMs)
        guard due != UInt64.max else { return }
        let seconds = max(0.05, Double(due) / 1000.0)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            self.pump()
        }
    }

    private func runOneRound(store: SyncableNotebookStore) async -> FfiSyncOutcome {
        // 不知道的時候當作有變動：寧可多跑一輪，也不要誤判成安靜而停掉。
        roundChanged = true
        if await GoogleAuth.shared.isSignedIn {
            guard let report = await NotebookSyncCoordinator.runDrive(
                store: store, deviceId: deviceId
            )
            else {
                lastMessage = L10n.t("not_signed_in")
                return .needsReauth
            }
            return finishMessage(report: report)
        }
        if let folder = CloudSyncFolder.resolveFolder() {
            let scoped = folder.startAccessingSecurityScopedResource()
            defer {
                if scoped {
                    folder.stopAccessingSecurityScopedResource()
                }
            }
            let report = await NotebookSyncCoordinator.run(
                store: store, folder: folder, deviceId: deviceId
            )
            return finishMessage(report: report)
        }
        // 沒設定任何同步方式：不是錯誤，也不該一直重試。
        lastMessage = ""
        roundChanged = false
        return .success
    }

    private func finishMessage(report: NotebookSyncCoordinator.Report) -> FfiSyncOutcome {
        // 被互斥閘擋下來的不是失敗，也不是「已是最新」—— 它根本沒跑。
        // 當成成功會讓排程器以為這一輪做完了，於是待辦被清掉。
        if report.wasSkipped {
            lastMessage = ""
            return .transient
        }
        roundChanged = !report.isNoOp || report.newNotebooks > 0
        if let failure = report.failures.first {
            lastMessage = SyncText.error("\(failure.key)：\(failure.value)")
            // 權杖問題由 runDrive 內部處理成登出；這裡一律當成可重試，
            // 排程器會自己退避。
            return .transient
        }
        lastMessage = report.isNoOp
            ? L10n.t("sync_up_to_date")
            : L10n.f("sync_result", report.uploaded, report.downloaded)
        // 同步可能把別台裝置的錄音寫進套件。不重掃的話，「最近錄音」
        // 那份清單看不到它們 —— 而那正是它最該顯示的東西。
        if report.downloaded > 0 || report.newNotebooks > 0 {
            NotebookStore.shared.refreshRecordings()
            // 真的拉到了對方的東西 = 對方在動：排程器重新開始週期同步。
            scheduler.noteRemoteChange(nowMs: nowMs)
        }
        if report.failures.isEmpty {
            SyncHistory.markGoogleSynced()
        }
        return .success
    }

    // MARK: - 背景

    /// 註冊並排一次背景更新。
    ///
    /// # 為什麼前景的計時器不夠
    ///
    /// iOS 會**直接凍結** App。使用者切走之前寫的最後一段要等他下次打開才會
    /// 上雲 —— 而他通常是在另一台裝置上發現那一段不見了。
    ///
    /// # 這是保底，不是主要路徑
    ///
    /// 系統決定什麼時候給你時間，可能好幾個小時才一次。真正的「即時」
    /// 靠前景觸發（進前景、存檔去抖動、週期拉取）。
    /// 註冊背景同步任務。
    ///
    /// # **必須在 App 啟動完成之前呼叫**
    ///
    /// `BGTaskScheduler.register` 只接受在 `application(_:didFinishLaunching…)`
    /// 回傳之前的註冊；晚一步就丟 `NSInternalInconsistencyException`
    /// （"All launch handlers must be registered before application finishes
    /// launching"），而那是**未捕捉的 Objective-C 例外 —— App 直接當掉**。
    ///
    /// 在此之前這一行藏在 `start()` 裡，而 `start()` 是在
    /// `onChange(of: scenePhase)` 變成 `.active` 時才呼叫的 —— 也就是畫面
    /// 都出來之後。那時候早就太晚了。
    ///
    /// **為什麼沒有早點發現**：所有既有的 UI 測試都只跑 iPhone 尺寸，
    /// 而那個尺寸下的啟動時序剛好讓它沒有觸發。iPad 一開就死。
    /// 響應式清查（不同尺寸跑同一套測試）第一輪就抓到了。
    ///
    /// 從 `KairumoApp.init` 呼叫。
    static func registerBackgroundTask() {
        #if canImport(BackgroundTasks) && !targetEnvironment(macCatalyst)
            guard !ProcessInfo.processInfo.isiOSAppOnMac else { return }
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: backgroundTaskId, using: nil
            ) { task in
                Task { @MainActor in
                    // 這個閉包活得比任何一次 start() 都久（它註冊在 App 啟動時），
                    // 所以拿單例而不是捕捉 self —— 捕捉的話會把一個
                    // 早該釋放的控制器留在記憶體裡。
                    let controller = AutoSyncController.shared
                    // **每次執行完都要再排下一次。** BGTaskScheduler 不會自己重複，
                    // 漏掉這一步的症狀是「背景同步只在安裝後動過一次」。
                    controller.scheduleBackgroundTask()
                    guard let store = controller.store else {
                        task.setTaskCompleted(success: true)
                        return
                    }
                    // 系統隨時會收回時間。被收回時要把任務標成未完成，
                    // 否則這次沒做完的事不會被重排。
                    task.expirationHandler = {
                        NotebookSyncCoordinator.cancelSync()
                    }
                    let outcome = await controller.runOneRound(store: store)
                    task.setTaskCompleted(success: outcome == .success)
                }
            }
        #endif
    }

    private func scheduleBackgroundTask() {
        #if canImport(BackgroundTasks) && !targetEnvironment(macCatalyst)
            guard !ProcessInfo.processInfo.isiOSAppOnMac else { return }
            let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskId)
            // 最早 15 分鐘後。給得比這個短沒有意義 —— 系統本來就不保證時間。
            request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
            try? BGTaskScheduler.shared.submit(request)
        #endif
    }

    // MARK: - 觸發來源

    private func startNetworkMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let online = path.status == .satisfied
                // 只在**由斷轉通**時觸發。每次路徑變動都觸發的話，
                // 切換 Wi-Fi/行動網路會連放好幾槍。
                if online, !self.wasOnline {
                    self.request(.networkRegained)
                }
                self.wasOnline = online
            }
        }
        monitor.start(queue: DispatchQueue(label: "kairumo.sync.network"))
        self.monitor = monitor
    }

    private func observeLifecycle() {
        #if canImport(UIKit)
            NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.request(.foreground) }
            }
            // 進背景前推一次：iOS 會直接凍結 App，沒推出去的內容要等下次開啟。
            NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.request(.background)
                    self?.scheduleBackgroundTask()
                }
            }
        #endif
    }
}
