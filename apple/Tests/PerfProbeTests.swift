//
//  PerfProbeTests.swift
//  KairumoTests
//
//  延遲量測本身的正確性：百分位、超標計數、環形緩衝上限，以及預算的合理順序。
//

import XCTest
@testable import Kairumo

final class PerfProbeTests: XCTestCase {

    func testStatsReportPercentilesAndOverBudgetCount() {
        let probe = PerfProbe()
        for ms in [1.0, 2, 3, 4, 5, 6, 7, 8, 9, 100] { probe.record(.strokeEnd, ms: ms) }
        let s = probe.stats(.strokeEnd)
        XCTAssertEqual(s.count, 10)
        XCTAssertEqual(s.maxMs, 100)
        XCTAssertEqual(s.p50Ms, 5)
        XCTAssertEqual(s.overBudget, 2, "預算 8 ms：9 與 100 超標")
    }

    func testEmptyPointReportsNothing() {
        XCTAssertEqual(PerfProbe().stats(.pageSwitch), PerfProbe.Stats())
    }

    func testRingBufferIsBounded() {
        let probe = PerfProbe()
        for _ in 0..<1000 { probe.record(.toolSwitch, ms: 1) }
        XCTAssertEqual(probe.stats(.toolSwitch).count, 256)
    }

    func testMeasureRecordsAndReturnsValue() {
        let probe = PerfProbe()
        let v = probe.measure(.pageLoad) { 42 }
        XCTAssertEqual(v, 42)
        XCTAssertEqual(probe.stats(.pageLoad).count, 1)
    }

    func testBudgetsAreSane() {
        for p in PerfPoint.allCases { XCTAssertGreaterThan(p.budgetMs, 0) }
        XCTAssertLessThan(PerfPoint.strokeEnd.budgetMs, PerfPoint.pageSwitch.budgetMs)
        XCTAssertLessThanOrEqual(PerfPoint.pageSave.budgetMs + PerfPoint.pageLoad.budgetMs, PerfPoint.pageSwitch.budgetMs * 1.0 + 0.0001)
    }
}
