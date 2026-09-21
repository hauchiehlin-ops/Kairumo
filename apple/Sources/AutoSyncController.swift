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
//  - 前景時每 12 秒拉一次 —— P1 之後那是**一個** HTTP 請求，
//    沒有變動就是空回應
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

    private let scheduler = FfiSyncScheduler.create()
    private var timer: Timer?
    private var monitor: NWPathMonitor?
    private var wasOnline = true
    private var store: SyncableNotebookStore?
    private var deviceId: UInt32 = 0
    private var started = false

    /// 單調時鐘的毫秒數。**不要用 `Date()`** —— 系統校時會讓它往回跳。
    private var nowMs: UInt64 { UInt64(ProcessInfo.processInfo.systemUptime * 1000) }

    private init() {}

    /// App 啟動時呼叫一次。
    func start(store: SyncableNotebookStore, deviceId: UInt32) {
        self.store = store
        self.deviceId = deviceId
        guard !started else { return }
        started = true

        // 前景心跳。間隔由核心給 —— 兩個平台照同一個數字。
        let interval = Double(syncPeriodicIntervalMs()) / 1000.0
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.heartbeat() }
        }
        // 使用者捲動清單時 run loop 會切到 tracking mode，預設的計時器
        // 在那段時間完全不會觸發 —— 症狀是「一邊滑一邊就不同步了」。
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        startNetworkMonitor()
        observeLifecycle()
        request(.foreground)
    }

    /// 送一個觸發事件進排程器。
    public func request(_ trigger: FfiSyncTrigger) {
        scheduler.request(trigger: trigger, nowMs: nowMs)
        needsSignIn = scheduler.isBlockedOnAuth()
        pump()
    }

    /// 本機存檔之後呼叫。**會去抖動**，連續存檔只會推一次。
    public func noteLocalEdit() {
        request(.localEdit)
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
            scheduler.finish(outcome: outcome, nowMs: nowMs)
            needsSignIn = scheduler.isBlockedOnAuth()
            if outcome == .success { lastSuccessAt = nowMs }
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
        if await GoogleAuth.shared.isSignedIn {
            guard let report = await NotebookSyncCoordinator.runDrive(
                store: store, deviceId: deviceId)
            else {
                lastMessage = "尚未登入"
                return .needsReauth
            }
            return finishMessage(report: report)
        }
        if let folder = CloudSyncFolder.resolveFolder() {
            let scoped = folder.startAccessingSecurityScopedResource()
            defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
            let report = await NotebookSyncCoordinator.run(
                store: store, folder: folder, deviceId: deviceId)
            return finishMessage(report: report)
        }
        // 沒設定任何同步方式：不是錯誤，也不該一直重試。
        lastMessage = ""
        return .success
    }

    private func finishMessage(report: NotebookSyncCoordinator.Report) -> FfiSyncOutcome {
        if let failure = report.failures.first {
            lastMessage = "\(failure.key)：\(failure.value)"
            // 權杖問題由 runDrive 內部處理成登出；這裡一律當成可重試，
            // 排程器會自己退避。
            return .transient
        }
        lastMessage = report.isNoOp
            ? "已是最新"
            : "上傳 \(report.uploaded)、下載 \(report.downloaded)"
        if !report.isNoOp || report.newNotebooks > 0 {
            SyncHistory.markGoogleSynced()
        }
        return .success
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
                if online && !self.wasOnline {
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
            Task { @MainActor in self?.request(.background) }
        }
        #endif
    }
}
