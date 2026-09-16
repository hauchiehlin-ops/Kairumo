//
//  InkLatencyMeter.swift
//  Kairumo
//
//  筆尖延遲的量測（Apple）。
//
//  # 它量的到底是什麼
//
//  從「這個觸控事件在硬體上發生的時刻」（`UITouch.timestamp`）到「這一幀真正
//  被顯示出來的時刻」（`CADisplayLink.targetTimestamp`）。**這不是筆尖到光子的
//  完整延遲** —— 面板本身的掃描與亮起時間量不到，那要靠高速攝影機。
//
//  說清楚這件事比給一個好看的數字重要：拿這個值去跟別家 App 的「延遲」比較，
//  只有在對方也用同一個定義時才有意義。它真正有用的地方是**同一台裝置上開關
//  某個選項的前後對比** —— 那個差值是真的。
//
//  # 為什麼 Apple 也需要一份
//
//  Android 早就有了（`InkLatencyMeter.kt`）。iPad 出問題時卻沒有等價的資訊
//  可看 —— 上一輪 Android 畫布全白那次，就是靠這條線找到原因的。
//  定義刻意與 Android 相同：兩邊的數字才比得起來。
//

import Foundation
import QuartzCore
import UIKit

/// 筆尖延遲的取樣。
///
/// 不是執行緒安全的 —— 觸控與畫面更新都在主執行緒上，加鎖只會讓量測本身
/// 影響到被量測的東西。
@MainActor
public final class InkLatencyMeter {

    private var samplesUs: [Int64] = []
    private let capacity: Int

    public init(capacity: Int = 512) {
        self.capacity = capacity
    }

    /// 記一次「這個事件的取樣時刻 → 現在」。
    ///
    /// `now` 預設是當下；有 `CADisplayLink` 時應該傳它的 `targetTimestamp`，
    /// 那才是這一幀真正會被看到的時刻。
    public func record(touch: UITouch, now: CFTimeInterval = CACurrentMediaTime()) {
        record(eventTimestamp: touch.timestamp, now: now)
    }

    public func record(eventTimestamp: CFTimeInterval, now: CFTimeInterval = CACurrentMediaTime()) {
        let delta = now - eventTimestamp
        // 負值代表時鐘來源不同步（模擬器上會這樣）。記錄它只會汙染統計。
        guard delta >= 0 else { return }
        if samplesUs.count >= capacity { samplesUs.removeFirst() }
        samplesUs.append(Int64(delta * 1_000_000))
    }

    public func clear() { samplesUs.removeAll() }

    public var count: Int { samplesUs.count }

    /// 第 `p` 百分位的延遲（微秒）。沒有樣本時回傳 0。
    ///
    /// 演算法與 Android 端逐字相同 —— 兩邊算法不同的話，同一台裝置上的
    /// 兩個數字沒有可比性，而那正是這個量測唯一的用途。
    public func percentileUs(_ p: Int) -> Int64 {
        guard !samplesUs.isEmpty else { return 0 }
        let sorted = samplesUs.sorted()
        // 取「不小於 p% 的第一個樣本」。用 count*p/100 會在 p=100 時越界。
        let index = ((sorted.count - 1) * min(max(p, 0), 100)) / 100
        return sorted[index]
    }

    /// 給使用者看的一行摘要。格式與 Android 端一致。
    public func summaryMs() -> String {
        guard !samplesUs.isEmpty else { return "—" }
        func ms(_ us: Int64) -> String { String(format: "%.1f", Double(us) / 1000.0) }
        return "p50 \(ms(percentileUs(50)))ms · p95 \(ms(percentileUs(95)))ms · \(samplesUs.count) 樣本"
    }
}

/// 觸控輸入的診斷。
///
/// 出問題時要看得到**輸入本身**長什麼樣：是筆還是手指、有沒有壓力、
/// 有沒有預測點。這些在 Android 端早就有，Apple 端一直沒有 ——
/// 於是 iPad 出問題時只能猜。
@MainActor
public final class InkInputDiagnostics {

    public struct Snapshot: Equatable {
        public var lastTouchType: String = "—"
        public var hasForce: Bool = false
        public var force: CGFloat = 0
        public var altitude: CGFloat = 0
        public var azimuth: CGFloat = 0
        /// 筆桿沿自身軸線的旋轉角，0–2π。只有 Pencil Pro 回報得出來。
        ///
        /// **診斷列是這一邊唯一看得到滾動角的地方**：PencilKit 的控制點沒有
        /// 這個欄位，所以它進不了筆畫（見 `InkInterop.rollAngle(of:)`）。
        /// 要確認手上那支筆到底有沒有回報滾動角，只能看這裡。
        public var roll: CGFloat = 0
        /// 這一次事件裡的聯合觸控點數（`coalescedTouches`）。
        ///
        /// 只拿到 1 就代表**沒有取到中間的取樣點** —— 快速書寫會變成折線，
        /// 而使用者說不出哪裡怪，只覺得字寫起來不順。
        public var coalescedCount: Int = 0
        /// 預測觸控點數（`predictedTouches`）。
        public var predictedCount: Int = 0
        public var activeTouches: Int = 0
    }

    /// App 共用的一份。
    ///
    /// 診斷是**跨畫面**的：使用者在編輯器裡寫字，接著到設定頁去看數字。
    /// 每個畫面各持有一份的話，設定頁看到的永遠是空的。
    public static let shared = InkInputDiagnostics()

    public private(set) var snapshot = Snapshot()
    public let latency = InkLatencyMeter()

    public init() {}

    /// 記下一次觸控事件的樣貌。
    public func record(touch: UITouch, event: UIEvent?, in view: UIView) {
        var next = Snapshot()
        next.lastTouchType = InkInputDiagnostics.describe(touch.type)
        next.hasForce = touch.maximumPossibleForce > 0
        next.force = touch.force
        next.altitude = touch.altitudeAngle
        next.azimuth = touch.azimuthAngle(in: view)
        next.roll = touch.kairumoRollAngle
        next.coalescedCount = event?.coalescedTouches(for: touch)?.count ?? 0
        next.predictedCount = event?.predictedTouches(for: touch)?.count ?? 0
        next.activeTouches = event?.allTouches?.count ?? 0
        snapshot = next

        latency.record(touch: touch)
    }

    private static func describe(_ type: UITouch.TouchType) -> String {
        switch type {
        case .direct: return "finger"
        case .pencil: return "pencil"
        case .indirect: return "indirect"
        case .indirectPointer: return "pointer"
        @unknown default: return "unknown"
        }
    }

    /// 給診斷頁看的幾行摘要。
    public func lines() -> [(String, String)] {
        [
            ("輸入裝置", snapshot.lastTouchType),
            ("壓力", snapshot.hasForce ? String(format: "%.2f", snapshot.force) : "不支援"),
            ("傾角", String(format: "%.2f", snapshot.altitude)),
            ("方位", String(format: "%.2f", snapshot.azimuth)),
            ("滾動", String(format: "%.2f", snapshot.roll)),
            ("聯合取樣點", "\(snapshot.coalescedCount)"),
            ("預測取樣點", "\(snapshot.predictedCount)"),
            ("同時觸控", "\(snapshot.activeTouches)"),
            ("筆尖延遲", latency.summaryMs())
        ]
    }
}
