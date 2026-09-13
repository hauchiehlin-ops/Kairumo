//
//  InkLatencyMeterTests.swift
//  KairumoTests
//
//  筆尖延遲的量測。
//
//  # 這組測試在守什麼
//
//  這個量測的**唯一用途**是同一台裝置上的前後對比。所以最重要的一條，
//  是它與 Android 端的演算法逐字相同 —— 兩邊算法不同的話，同一台裝置上的
//  兩個數字沒有可比性，而那正是它存在的理由。
//
//  其次是那些會讓數字變成垃圾的輸入：負的時間差（時鐘來源不同步）、
//  空樣本、以及 p=100 的邊界（用 count*p/100 會越界）。
//

import XCTest
@testable import Kairumo

@MainActor
final class InkLatencyMeterTests: XCTestCase {

    private func meter(_ deltasMs: [Double]) -> InkLatencyMeter {
        let meter = InkLatencyMeter()
        for delta in deltasMs {
            // 事件在 0，現在在 delta —— 直接控制時間差。
            meter.record(eventTimestamp: 0, now: delta / 1000.0)
        }
        return meter
    }

    func testAnEmptyMeterReportsNothingRatherThanZeroMilliseconds() {
        // 回 "0.0ms" 的話，使用者會以為延遲是零，而不是「還沒量到」。
        let meter = InkLatencyMeter()
        XCTAssertEqual(meter.count, 0)
        XCTAssertEqual(meter.summaryMs(), "—")
        XCTAssertEqual(meter.percentileUs(50), 0)
    }

    func testSamplesAreRecordedInMicroseconds() {
        let meter = meter([10])
        XCTAssertEqual(meter.count, 1)
        XCTAssertEqual(meter.percentileUs(50), 10_000, accuracy: 100)
    }

    func testNegativeDeltasAreDropped() {
        // 負值代表時鐘來源不同步（模擬器上會這樣）。記錄它只會汙染統計。
        let meter = InkLatencyMeter()
        meter.record(eventTimestamp: 1.0, now: 0.5)
        XCTAssertEqual(meter.count, 0)
    }

    func testThePercentilePicksTheFirstSampleNotBelowP() {
        // 演算法與 Android 端逐字相同：`((count - 1) * p) / 100`。
        let meter = meter([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        XCTAssertEqual(meter.percentileUs(0), 1_000, accuracy: 50)
        XCTAssertEqual(meter.percentileUs(50), 5_000, accuracy: 50)
        XCTAssertEqual(meter.percentileUs(100), 10_000, accuracy: 50)
    }

    func testPercentile100DoesNotGoOutOfBounds() {
        // 用 count*p/100 的話，p=100 會越界 —— 那是 Android 端註解裡點名的坑。
        let meter = meter([1, 2, 3])
        XCTAssertEqual(meter.percentileUs(100), 3_000, accuracy: 50)
    }

    func testOutOfRangePercentilesAreClamped() {
        let meter = meter([1, 2, 3])
        XCTAssertEqual(meter.percentileUs(-10), meter.percentileUs(0))
        XCTAssertEqual(meter.percentileUs(999), meter.percentileUs(100))
    }

    func testSamplesAreUnsortedOnInputButSortedForThePercentile() {
        // 進來的順序是使用者書寫的順序，不是大小順序。
        let meter = meter([10, 1, 5])
        XCTAssertEqual(meter.percentileUs(0), 1_000, accuracy: 50)
        XCTAssertEqual(meter.percentileUs(100), 10_000, accuracy: 50)
    }

    func testTheOldestSampleIsDroppedWhenFull() {
        // 不設上限的話，寫一整天的筆記會讓這個陣列無限長大。
        let meter = InkLatencyMeter(capacity: 3)
        for delta in [1.0, 2.0, 3.0, 4.0] {
            meter.record(eventTimestamp: 0, now: delta / 1000.0)
        }
        XCTAssertEqual(meter.count, 3)
        XCTAssertEqual(meter.percentileUs(0), 2_000, accuracy: 50, "最舊的那筆沒有被丟掉")
    }

    func testClearingRemovesEverything() {
        let meter = meter([1, 2, 3])
        meter.clear()
        XCTAssertEqual(meter.count, 0)
    }

    func testTheSummaryFormatMatchesAndroid() {
        // 格式不一樣的話，兩邊的截圖擺在一起比不了。
        let meter = meter([10, 20, 30])
        let summary = meter.summaryMs()
        XCTAssertTrue(summary.contains("p50"), summary)
        XCTAssertTrue(summary.contains("p95"), summary)
        XCTAssertTrue(summary.contains("3 樣本"), summary)
        XCTAssertTrue(summary.contains("ms"), summary)
    }

    // MARK: - 輸入診斷

    func testDiagnosticsStartEmptyRatherThanLying() {
        // 顯示一個假的預設值的話，看的人會以為那是真的量到的。
        let diagnostics = InkInputDiagnostics()
        XCTAssertEqual(diagnostics.snapshot.lastTouchType, "—")
        XCTAssertEqual(diagnostics.snapshot.coalescedCount, 0)
    }

    func testDiagnosticsExposeTheLinesTheDiagnosticPageNeeds() {
        // 出問題時要看得到輸入本身長什麼樣 —— 是筆還是手指、有沒有壓力、
        // 有沒有取到中間的取樣點。
        let labels = InkInputDiagnostics().lines().map(\.0)
        XCTAssertTrue(labels.contains("輸入裝置"))
        XCTAssertTrue(labels.contains("壓力"))
        XCTAssertTrue(labels.contains("聯合取樣點"), "快速書寫變折線就是靠這個數字發現的")
        XCTAssertTrue(labels.contains("筆尖延遲"))
    }
}
