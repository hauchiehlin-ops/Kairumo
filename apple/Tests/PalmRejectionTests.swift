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
    // MARK: - 點選留下的墨點（TapDotRetraction）

    /// 一筆以 `began` 開始、持續 `duration` 秒、取樣點從 `from` 移到 `to` 的筆畫。
    private func stroke(
        from: CGPoint, to: CGPoint, began: Date, duration: TimeInterval = 0.08,
        width: CGFloat = 4
    ) -> PKStroke {
        let points = (0..<4).map { i -> PKStrokePoint in
            let t = CGFloat(i) / 3
            return PKStrokePoint(
                location: CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t),
                timeOffset: duration * Double(t),
                size: CGSize(width: width, height: width),
                opacity: 1, force: 1, azimuth: 1, altitude: 1.2)
        }
        return PKStroke(
            ink: PKInk(.marker, color: .black),
            path: PKStrokePath(controlPoints: points, creationDate: began))
    }

    func testATapDotFromAThickPenIsRetracted() {
        // 原本看 renderBounds < 10pt：麥克筆點出來的點比這大，永遠收不掉。
        let tapped = Date()
        let tap = CGPoint(x: 200, y: 300)
        let dot = stroke(from: tap, to: CGPoint(x: 201, y: 300), began: tapped.addingTimeInterval(-0.1), width: 30)
        let cleaned = TapDotRetraction.retracting(PKDrawing(strokes: [dot]), near: tap, tappedAt: tapped)
        XCTAssertTrue(cleaned.strokes.isEmpty)
    }

    func testARealStrokeUnderTheTapIsKept() {
        // 手指點物件之前剛好畫過一條線：那是使用者寫的，不是墨點。
        let tapped = Date()
        let tap = CGPoint(x: 200, y: 300)
        let line = stroke(from: CGPoint(x: 150, y: 300), to: CGPoint(x: 250, y: 300), began: tapped.addingTimeInterval(-0.1))
        let cleaned = TapDotRetraction.retracting(PKDrawing(strokes: [line]), near: tap, tappedAt: tapped)
        XCTAssertEqual(cleaned.strokes.count, 1)
    }

    func testAPeriodWrittenEarlierIsKept() {
        // 一秒前用 Pencil 點的句號就在附近：結束得早，不是這一下留下的。
        let tapped = Date()
        let tap = CGPoint(x: 200, y: 300)
        let period = stroke(from: tap, to: tap, began: tapped.addingTimeInterval(-1.2), duration: 0.05)
        let cleaned = TapDotRetraction.retracting(PKDrawing(strokes: [period]), near: tap, tappedAt: tapped)
        XCTAssertEqual(cleaned.strokes.count, 1)
    }

    func testADotFarFromTheTapIsKept() {
        let tapped = Date()
        let dot = stroke(from: CGPoint(x: 400, y: 300), to: CGPoint(x: 400, y: 300), began: tapped.addingTimeInterval(-0.1))
        let cleaned = TapDotRetraction.retracting(PKDrawing(strokes: [dot]), near: CGPoint(x: 200, y: 300), tappedAt: tapped)
        XCTAssertEqual(cleaned.strokes.count, 1)
    }

    func testAStrokeStartedAfterTheTapIsKept() {
        // 收回會延後重試；重試期間 Pencil 新點下去的那一點不能被收掉。
        let tapped = Date()
        let tap = CGPoint(x: 200, y: 300)
        let later = stroke(from: tap, to: tap, began: tapped.addingTimeInterval(0.05))
        let cleaned = TapDotRetraction.retracting(PKDrawing(strokes: [later]), near: tap, tappedAt: tapped)
        XCTAssertEqual(cleaned.strokes.count, 1)
    }

    func testADoubleTapRetractsBothDotsButNothingElse() {
        let tapped = Date()
        let tap = CGPoint(x: 200, y: 300)
        let writing = stroke(from: CGPoint(x: 20, y: 20), to: CGPoint(x: 120, y: 60), began: tapped.addingTimeInterval(-3))
        let first = stroke(from: tap, to: tap, began: tapped.addingTimeInterval(-0.4))
        let second = stroke(from: CGPoint(x: 202, y: 301), to: CGPoint(x: 202, y: 301), began: tapped.addingTimeInterval(-0.08))
        let cleaned = TapDotRetraction.retracting(
            PKDrawing(strokes: [writing, first, second]), near: tap, tappedAt: tapped, maxCount: 2)
        XCTAssertEqual(cleaned.strokes.count, 1)
        XCTAssertEqual(cleaned.strokes.first?.path.creationDate, writing.path.creationDate)
    }

    func testASingleTapRetractsOnlyOneDot() {
        let tapped = Date()
        let tap = CGPoint(x: 200, y: 300)
        let first = stroke(from: tap, to: tap, began: tapped.addingTimeInterval(-0.4))
        let second = stroke(from: tap, to: tap, began: tapped.addingTimeInterval(-0.08))
        let cleaned = TapDotRetraction.retracting(PKDrawing(strokes: [first, second]), near: tap, tappedAt: tapped)
        XCTAssertEqual(cleaned.strokes.count, 1)
        XCTAssertEqual(cleaned.strokes.first?.path.creationDate, first.path.creationDate)
    }
}
