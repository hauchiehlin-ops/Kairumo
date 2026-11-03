//
//  PerfProbe.swift
//  Kairumo
//
//  即時響應的量測基礎：每個「使用者會感覺到的動作」各有一個量測點與延遲預算。
//
//  為什麼需要：之前的優化都沒有數字可對照，守門機制只檢查寫法、不檢查「到底花了幾毫秒」。
//  這裡讓每個熱路徑（收筆、換工具、切頁、存頁、載頁、縮圖）
//  1. 在 Instruments 的 Points of Interest 看得到區間（`OSSignposter`）；
//  2. 在記憶體留下最近的耗時，算 p50 / p95 / 最大值，並與預算比對；
//  3. 超過預算的次數會累計，診斷與測試都可以直接讀。
//
//  量測本身必須比被量測的東西便宜得多：一次記錄只有兩個時間戳、一把短鎖、一個環形緩衝。
//  任何執行緒都可以呼叫。
//

import Foundation
import os

/// 使用者感覺得到的動作。新增熱路徑就在這裡加一個 case、補預算，
/// `scripts/check-latency-budget.py` 會確認每個 case 都真的有被量測。
enum PerfPoint: String, CaseIterable, Sendable {
    /// 收筆：`ProInk.endStroke` 從進入到交還主執行緒。
    case strokeEnd
    /// 換工具：`applyEditorTool` 整段。
    case toolSwitch
    /// 切頁：`switchToPage` 整段（使用者看到新頁之前主執行緒花的時間）。
    case pageSwitch
    /// 切頁中「存上一頁」那一段。
    case pageSave
    /// 切頁中「載入新頁」那一段。
    case pageLoad
    /// 縮圖在主執行緒上算繪的時間（快取未命中時）。
    case thumbnailRender

    /// 延遲預算（毫秒）。120Hz 一幀 8.3 ms、60Hz 16.7 ms；
    /// 預算以「不造成明顯掉幀或遲滯感」為準，換頁允許略高但必須在一次點擊的容忍內。
    var budgetMs: Double {
        switch self {
        case .strokeEnd: return 8
        case .toolSwitch: return 16
        case .pageSwitch: return 50
        case .pageSave: return 16
        case .pageLoad: return 33
        case .thumbnailRender: return 16
        }
    }
}

/// 與裝置速度無關的「次數型」成本計數。測試用它斷言：某個互動在主執行緒上
/// 不該發生的事（讀檔、同步算繪…）一次都沒有發生，且不隨筆記大小成長。
enum CostCounter: String, CaseIterable, Sendable {
    case prefetchScheduled
    case mainThreadDrawingLoad
    case thumbnailComposeOnMain
}

final class PerfProbe: @unchecked Sendable {
    // profile-scope: device 效能診斷，整台裝置共用
    static let shared = PerfProbe()

    struct Stats: Equatable {
        var count = 0
        var p50Ms = 0.0
        var p95Ms = 0.0
        var maxMs = 0.0
        var overBudget = 0
    }

    private static let capacity = 256
    private let signposter = OSSignposter(subsystem: "com.kairumo", category: "PointsOfInterest")
    private let log = Logger(subsystem: "com.kairumo", category: "perf")
    private let lock = NSLock()
    private var samples: [PerfPoint: [Double]] = [:]
    private var over: [PerfPoint: Int] = [:]

    /// 量一段同步工作。
    @discardableResult
    func measure<T>(_ point: PerfPoint, _ body: () throws -> T) rethrows -> T {
        let state = signposter.beginInterval("perf", id: signposter.makeSignpostID(), "\(point.rawValue)")
        let start = DispatchTime.now().uptimeNanoseconds
        defer {
            let ms = Double(DispatchTime.now().uptimeNanoseconds &- start) / 1_000_000
            signposter.endInterval("perf", state)
            record(point, ms: ms)
        }
        return try body()
    }

    private var counters: [CostCounter: Int] = [:]

    func count(_ c: CostCounter, by n: Int = 1) {
        lock.lock(); counters[c, default: 0] += n; lock.unlock()
    }

    func counter(_ c: CostCounter) -> Int {
        lock.lock(); defer { lock.unlock() }
        return counters[c] ?? 0
    }

    func record(_ point: PerfPoint, ms: Double) {
        lock.lock()
        var list = samples[point] ?? []
        if list.count >= Self.capacity { list.removeFirst() }
        list.append(ms)
        samples[point] = list
        let exceeded = ms > point.budgetMs
        if exceeded { over[point, default: 0] += 1 }
        lock.unlock()
        if exceeded {
            log.notice("over budget \(point.rawValue, privacy: .public): \(ms, format: .fixed(precision: 1)) ms > \(point.budgetMs, format: .fixed(precision: 0)) ms")
        }
    }

    func stats(_ point: PerfPoint) -> Stats {
        lock.lock()
        let list = samples[point] ?? []
        let overCount = over[point] ?? 0
        lock.unlock()
        guard !list.isEmpty else { return Stats() }
        let sorted = list.sorted()
        func pct(_ p: Int) -> Double { sorted[((sorted.count - 1) * p) / 100] }
        return Stats(count: list.count, p50Ms: pct(50), p95Ms: pct(95), maxMs: sorted.last ?? 0, overBudget: overCount)
    }

    /// 診斷用的多行摘要。
    func report() -> String {
        PerfPoint.allCases.map { point in
            let s = stats(point)
            guard s.count > 0 else { return "\(point.rawValue): —" }
            return String(format: "%@: p50 %.1f / p95 %.1f / max %.1f ms（預算 %.0f，超標 %d/%d）",
                          point.rawValue, s.p50Ms, s.p95Ms, s.maxMs, point.budgetMs, s.overBudget, s.count)
        }.joined(separator: "\n")
    }

    func reset() {
        lock.lock(); samples.removeAll(); over.removeAll(); counters.removeAll(); lock.unlock()
    }
}
