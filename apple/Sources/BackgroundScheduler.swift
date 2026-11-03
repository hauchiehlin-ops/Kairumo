//
//  BackgroundScheduler.swift
//  Kairumo
//
//  背景工作的唯一排程器（即時響應架構 · 通道三）。
//
//  # 為什麼
//
//  預取、解碼、縮圖、同步各自判斷「現在可不可以做」，哪一處忘了讓路，筆跡就卡一下。
//  這裡把規則收成一份：工作分四級，**書寫中，預取與維護一律暫停**，停手後才繼續；
//  互動級（使用者正在等的）永遠不被暫停。與裝置無關 —— 慢的裝置只是做得比較久，不會搶到筆。
//
//  工作在背景佇列執行，**不得碰 UI 與 @MainActor 狀態**；結果要用主執行緒回呼交回。
//

import Foundation
import QuartzCore

enum BackgroundPriority: Int, Comparable, Sendable {
    /// 使用者正在等結果（不受書寫暫停影響）。
    case interactive = 0
    /// 目前畫面上看得到、等一下就要用的。書寫中暫停。
    case visible = 1
    /// 預測下一步會用的（相鄰頁的筆跡解碼）。書寫中暫停。
    case prefetch = 2
    /// 可以晚點做的（整理、預熱）。書寫中暫停。
    case maintenance = 3

    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    var qos: DispatchQoS.QoSClass {
        switch self {
        case .interactive: return .userInitiated
        case .visible: return .utility
        case .prefetch, .maintenance: return .background
        }
    }
}

final class BackgroundScheduler: @unchecked Sendable {
    // profile-scope: device 排程器本身不含使用者資料
    static let shared = BackgroundScheduler()

    /// 現在是不是「筆正在忙」。預設讀畫布的書寫活動；測試可以換掉。
    var inkBusy: @Sendable () -> Bool = {
        // 單一 Double／Int 的讀取，過期一個週期只會讓工作多等一輪，不需要鎖。
        CanvasTouchState.isActivelyInking(cooldownSeconds: 0.5)
    }

    /// 書寫中，被暫停的工作隔多久再看一次。
    var retryInterval: TimeInterval = 0.15

    private let lock = NSLock()
    private var queues: [BackgroundPriority: DispatchQueue] = [:]
    private var inFlight: [String: Bool] = [:]

    private func queue(_ p: BackgroundPriority) -> DispatchQueue {
        lock.lock(); defer { lock.unlock() }
        if let q = queues[p] { return q }
        let q = DispatchQueue(label: "kairumo.bg.\(p.rawValue)", qos: DispatchQoS(qosClass: p.qos, relativePriority: 0))
        queues[p] = q
        return q
    }

    /// 排一件工作。`key` 相同且前一件還沒做完時不重複排（預取常被連續觸發）。
    func submit(_ priority: BackgroundPriority, key: String? = nil, _ work: @escaping @Sendable () -> Void) {
        if let key {
            lock.lock()
            if inFlight[key] == true { lock.unlock(); return }
            inFlight[key] = true
            lock.unlock()
        }
        run(priority, key: key, work)
    }

    private func run(_ priority: BackgroundPriority, key: String?, _ work: @escaping @Sendable () -> Void) {
        let q = queue(priority)
        q.async { [self] in
            if priority != .interactive, inkBusy() {
                q.asyncAfter(deadline: .now() + retryInterval) { [self] in
                    run(priority, key: key, work)
                }
                return
            }
            work()
            if let key { lock.lock(); inFlight[key] = nil; lock.unlock() }
        }
    }
}

/// 相鄰頁／可見頁筆跡的背景預取。
enum PagePrefetcher {
    /// 在主執行緒呼叫（只算路徑，檔案工作在背景）。
    @MainActor
    static func prefetch(pages: [Int], notebookId: String, store: NotebookStore, priority: BackgroundPriority = .prefetch) {
        let dir = store.drawingsDirectory
        for page in pages where page >= 0 {
            let url = dir.appending(path: "\(notebookId)_p\(page).drawing")
            PerfProbe.shared.count(.prefetchScheduled)
            BackgroundScheduler.shared.submit(priority, key: url.path) {
                NotebookStore.prefetchDrawing(at: url)
            }
        }
    }

    /// 目前頁前後各 `radius` 頁（不含目前頁，已在記憶體）。
    static func neighbors(of page: Int, pageCount: Int, radius: Int = 2) -> [Int] {
        guard pageCount > 1 else { return [] }
        return (1...radius).flatMap { [page + $0, page - $0] }.filter { $0 >= 0 && $0 < pageCount }
    }
}
