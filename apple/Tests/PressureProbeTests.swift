import XCTest
@testable import Kairumo

final class PressureProbeTests: XCTestCase {
    func testMouseLikeInputReportsNoPressure() {
        var probe = PressureProbe()
        for _ in 0..<5 { probe.record(input: "pointer", force: 0, maximumPossibleForce: 0) }
        XCTAssertFalse(probe.reportsPressure)
        XCTAssertEqual(probe.totalSamples, 5)
        XCTAssertEqual(probe.peakPressure, 0)
    }

    func testPressureIsNormalizedAndPeakIsRemembered() {
        var probe = PressureProbe()
        probe.record(input: "pencil", force: 1, maximumPossibleForce: 4)
        probe.record(input: "pencil", force: 3, maximumPossibleForce: 4)
        probe.record(input: "pencil", force: 0, maximumPossibleForce: 4) // 抬筆：壓力歸零，但最大值要留著
        XCTAssertTrue(probe.reportsPressure)
        XCTAssertEqual(probe.peakPressure, 0.75, accuracy: 0.001)
        XCTAssertEqual(probe.lastPressure, 0)
        XCTAssertEqual(probe.pressureSamples, 2)
        XCTAssertEqual(probe.totalSamples, 3)
    }

    func testCapabilityWithoutRealValuesDoesNotCount() {
        // 回報了 maximumPossibleForce，但每個取樣點壓力都是 0：對壓力感應沒用。
        var probe = PressureProbe()
        probe.record(input: "pointer", force: 0, maximumPossibleForce: 1)
        XCTAssertFalse(probe.reportsPressure)
    }

    func testForceAboveMaximumIsClampedToOne() {
        var probe = PressureProbe()
        probe.record(input: "pencil", force: 9, maximumPossibleForce: 4)
        XCTAssertEqual(probe.peakPressure, 1)
    }
}
