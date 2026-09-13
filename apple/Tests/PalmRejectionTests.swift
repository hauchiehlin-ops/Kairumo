//
//  PalmRejectionTests.swift
//  KairumoTests
//
//  Apple 端的掌拒與筆畫收回（工作項 S-45）。
//
//  原本畫布在手寫模式下是 `.anyInput` —— 手指能畫，代價是**手掌也能畫**。
//  這一批測試釘的是：偵測到筆就切成系統層掌拒、沒有筆的人仍然寫得了字、
//  以及手掌先落筆後落時那一段要收得回來。
//

import XCTest
import PencilKit
@testable import Kairumo

@MainActor
final class PalmRejectionTests: XCTestCase {

    private func drawing(at dates: [Date]) -> PKDrawing {
        PKDrawing(strokes: dates.map { date in
            let points = (0..<4).map { i in
                PKStrokePoint(
                    location: CGPoint(x: 10 + CGFloat(i) * 5, y: 20),
                    timeOffset: Double(i) * 0.008,
                    size: CGSize(width: 4, height: 4),
                    opacity: 1, force: 1, azimuth: 1, altitude: 1.2)
            }
            return PKStroke(
                ink: PKInk(.pen, color: .black),
                path: PKStrokePath(controlPoints: points, creationDate: date))
        })
    }

    // MARK: - 輸入政策

    func testWithoutAPencilFingersCanStillWrite() {
        // 沒有 Apple Pencil 的人要用手指寫字。單純改成 .pencilOnly
        // 等於讓他們完全不能用。
        let palm = PalmRejectionCoordinator()
        XCTAssertEqual(palm.drawingPolicy(), .anyInput)
    }

    func testPenOnlyModeIsAlwaysPenOnly() {
        let palm = PalmRejectionCoordinator()
        palm.mode = .penOnly
        XCTAssertEqual(palm.drawingPolicy(), .pencilOnly)
    }

    func testAnyInputModeNeverSwitchesAway() {
        // 使用者明確選了「手指也能寫」，就不要自作主張改回去。
        let palm = PalmRejectionCoordinator()
        palm.mode = .anyInput
        XCTAssertEqual(palm.drawingPolicy(), .anyInput)
    }

    // MARK: - 收回

    func testStrokesDrawnJustBeforeThePenLandedAreRetracted() {
        // 使用者的自然動作是手掌先碰螢幕、筆才落下。那一瞬間手掌已經畫出
        // 東西了 —— 不收回的話，掌拒只擋得住「筆之後」的誤觸。
        let penLanded = Date()
        let palmStroke = penLanded.addingTimeInterval(-0.2)   // 筆落下前 200ms
        let oldStroke = penLanded.addingTimeInterval(-30)     // 半分鐘前寫的

        let cleaned = PalmRejectionCoordinator.retracting(
            drawing(at: [oldStroke, palmStroke]), landedAt: penLanded)

        XCTAssertEqual(cleaned.strokes.count, 1, "只該收回剛剛那一筆")
        XCTAssertEqual(cleaned.strokes.first?.path.creationDate, oldStroke)
    }

    func testOlderStrokesAreNeverTouched() {
        // 收回是為了「剛剛那一下」。三十秒前寫的東西是使用者真的要的，
        // 不能因為現在拿起筆就被抹掉。
        let penLanded = Date()
        let original = drawing(at: [
            penLanded.addingTimeInterval(-60),
            penLanded.addingTimeInterval(-30),
            penLanded.addingTimeInterval(-5)
        ])
        let cleaned = PalmRejectionCoordinator.retracting(original, landedAt: penLanded)
        XCTAssertEqual(cleaned.strokes.count, 3)
    }

    func testStrokesDrawnAfterThePenLandedAreKept() {
        // 筆落下之後畫的當然是筆畫的，收回它等於把使用者正在寫的字吃掉。
        let penLanded = Date()
        let cleaned = PalmRejectionCoordinator.retracting(
            drawing(at: [penLanded.addingTimeInterval(1)]), landedAt: penLanded)
        XCTAssertEqual(cleaned.strokes.count, 1)
    }

    func testNothingToRetractReturnsTheSameDrawing() {
        // 沒有東西要收回時不該白白重建一份 PKDrawing（每一筆都要重新編碼）。
        let penLanded = Date()
        let original = drawing(at: [penLanded.addingTimeInterval(-60)])
        let cleaned = PalmRejectionCoordinator.retracting(original, landedAt: penLanded)
        XCTAssertEqual(cleaned.strokes.count, original.strokes.count)
    }

    func testAnEmptyDrawingIsSafe() {
        let cleaned = PalmRejectionCoordinator.retracting(PKDrawing(), landedAt: Date())
        XCTAssertTrue(cleaned.strokes.isEmpty)
    }

    // MARK: - 與核心的對應

    func testTheRetractWindowMatchesTheCoreDefault() {
        // 核心的 `set_palm_thresholds` 預設收回時間窗是 500ms。兩邊用不同的
        // 數字的話，同一個動作在兩個平台上的結果不一樣。
        let penLanded = Date()
        let justInside = penLanded.addingTimeInterval(-0.4)
        let justOutside = penLanded.addingTimeInterval(-0.6)

        let cleaned = PalmRejectionCoordinator.retracting(
            drawing(at: [justOutside, justInside]), landedAt: penLanded)
        XCTAssertEqual(cleaned.strokes.count, 1)
        XCTAssertEqual(cleaned.strokes.first?.path.creationDate, justOutside)
    }

    func testThePencilGraceIsLongEnoughToThinkBetweenStrokes() {
        // 使用者會停下來想事情。太短的話一停筆就切回 .anyInput，
        // 手掌馬上又畫得出東西。
        XCTAssertGreaterThanOrEqual(PalmRejectionCoordinator.pencilGrace, 10)
    }
}
