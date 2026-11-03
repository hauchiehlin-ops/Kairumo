import XCTest
@testable import Kairumo

final class FrameGovernorTests: XCTestCase {
    private let target = 1.0 / 120

    private func feed(_ g: FrameGovernor, over: Int, ok: Int) {
        for _ in 0..<over { g.ingest(frameDuration: target * 3, target: target) }
        for _ in 0..<ok { g.ingest(frameDuration: target, target: target) }
    }

    func testSmoothFramesStayNormal() {
        let g = FrameGovernor()
        feed(g, over: 0, ok: 200)
        XCTAssertEqual(g.level, .normal)
        XCTAssertEqual(g.thumbnailScaleFactor, 1)
    }

    func testSustainedHitchesConstrainThenRecoverWithHysteresis() {
        let g = FrameGovernor()
        feed(g, over: 30, ok: 30)
        XCTAssertEqual(g.level, .constrained, "一半的幀都超時")
        XCTAssertLessThan(g.thumbnailScaleFactor, 1)
        XCTAssertGreaterThan(g.thumbnailGap, 0)
        // 持續約 16% 超時（低於進入門檻、高於離開門檻）：維持原狀，不來回跳。
        for _ in 0..<20 { feed(g, over: 1, ok: 5) }
        XCTAssertEqual(g.level, .constrained)
        feed(g, over: 0, ok: 60)
        XCTAssertEqual(g.level, .normal)
    }

    func testASingleHitchDoesNotConstrain() {
        let g = FrameGovernor()
        feed(g, over: 1, ok: 100)
        XCTAssertEqual(g.level, .normal)
    }
}
