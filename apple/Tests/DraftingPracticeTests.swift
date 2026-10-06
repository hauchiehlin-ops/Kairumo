//
//  DraftingPracticeTests.swift
//  KairumoTests
//
//  練習題：出題、批改、標記、看答案。走真正的核心題庫與批改、真正的 `ProInkLayerView`。
//  對應 Android 的 `DraftingPracticeTest`。
//

import XCTest
@testable import Kairumo

@MainActor
final class DraftingPracticeTests: XCTestCase {
    private var workDir: URL!
    private var manager: UndoManager!
    private var layer: ProInkLayerView!
    private var session: PracticeSession { PracticeSession.shared }
    private let page = CGSize(width: 1600, height: 1132)
    private func l(_ key: String) -> String { LocalizationManager.shared.localized(key) }

    override func setUpWithError() throws {
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-practice-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        manager = UndoManager()
        manager.groupsByEvent = false
        newLayer()
        DraftingState.shared.use(notebook: "practice-\(UUID().uuidString)")
        DraftingState.shared.tool = .none
        session.end(layer: nil)
    }

    override func tearDownWithError() throws {
        session.end(layer: layer)
        DraftingState.shared.tool = .none
        try? FileManager.default.removeItem(at: workDir)
    }

    private func newLayer() {
        layer = ProInkLayerView(frame: CGRect(x: 0, y: 0, width: 1600, height: 1132))
        layer.undoManagerProvider = { [manager] in manager }
        // 每次用獨立的筆記本代號：同一個代號會把上一題存下的筆畫又讀回來。
        layer.load(directory: workDir, notebookId: "practice-\(UUID().uuidString)", pageIndex: 0)
    }

    @discardableResult
    private func start(_ kind: String, _ seed: UInt64 = 7) -> Bool {
        // 這個 UndoManager 不依 run loop 分組：每次會登記復原的動作都要自己包一組。
        manager.beginUndoGrouping()
        defer { manager.endUndoGrouping() }
        return session.start(kind: kind, seed: seed, layer: layer, pageSize: page)
    }

    /// 學生用製圖筆（頂層）把這些線畫上去：粗實線 2.6、隱藏線 1.4、細線 1.2、中心線 1.1。
    private func draw(_ lines: [FfiProblemLine], mutate: (Int, FfiProblemLine) -> FfiProblemLine = { $1 }) {
        let items = lines.enumerated().map { i, raw -> FfiSheetStroke in
            let line = mutate(i, raw)
            let width: Float = line.lineType == 1 ? 1.4 : (line.lineType == 2 ? 1.1 : (line.thin ? 1.2 : 2.6))
            return FfiSheetStroke(points: [line.a, line.b], layer: 3, lineType: line.lineType, width: width, colorHex: "#111827")
        }
        manager.beginUndoGrouping()
        layer.insertDrafted(items, origin: .zero)
        manager.endUndoGrouping()
    }

    // MARK: 出題

    func testStartingAProblemPutsTheGivenLinesOnTheBottomLayerAndShowsThePrompt() {
        for kind in ["complete_view", "iso_to_views", "section", "angle_judgement", "spot_error"] {
            newLayer()
            XCTAssertTrue(start(kind), kind)
            let p = session.problem!
            XCTAssertEqual(p.kind, kind)
            XCTAssertEqual(layer.ownStrokes.count, p.given.count, "題目線都放進頁面")
            XCTAssertTrue(layer.ownStrokes.allSatisfy { $0.layerId == 1 }, "題目線在底層")
            XCTAssertEqual(DraftingState.shared.toolHint, l("draft_prob_prompt_\(kind)"))
            XCTAssertTrue(session.isActive)
        }
        XCTAssertFalse(start("nope", 1))
    }

    func testTheSameSeedGivesTheSameProblemOnEveryDevice() {
        start("complete_view", 99)
        let first = session.problem!.given.map { [$0.a.x, $0.a.y] }
        newLayer()
        start("complete_view", 99)
        XCTAssertEqual(session.problem!.given.map { [$0.a.x, $0.a.y] }, first)
    }

    func testTheGivenLinesUndoAsOneAction() {
        manager.beginUndoGrouping()
        start("complete_view")
        manager.endUndoGrouping()
        XCTAssertFalse(layer.ownStrokes.isEmpty)
        manager.undo()
        XCTAssertEqual(layer.ownStrokes.count, 0)
    }

    // MARK: 批改

    func testDrawingTheModelAnswerScoresAHundredAndMarksNothing() {
        for kind in ["complete_view", "iso_to_views", "section"] {
            newLayer()
            start(kind)
            draw(session.problem!.answer)
            let s = session.grade(layer: layer)!
            XCTAssertEqual(s.score, 100, "\(kind) 標準答案要滿分")
            XCTAssertTrue(s.perfect, kind)
        }
    }

    func testAnEmptyPageScoresLowAndReportsMissingLines() {
        start("complete_view")
        let s = session.grade(layer: layer)!
        XCTAssertLessThan(s.score, 50)
        XCTAssertGreaterThan(s.missing, 0)
        XCTAssertFalse(s.perfect)
    }

    func testAMissingLineAWrongTypeAndAnExtraLineAreEachReported() {
        start("complete_view")
        draw(Array(session.problem!.answer.dropFirst()))
        XCTAssertEqual(session.grade(layer: layer)!.missing, 1)

        newLayer()
        start("complete_view")
        let answer = session.problem!.answer
        let solid = answer.firstIndex { $0.lineType == 0 && !$0.thin }!
        draw(answer) { i, line in i == solid ? FfiProblemLine(a: line.a, b: line.b, lineType: 1, thin: false) : line }
        let t = session.grade(layer: layer)!
        XCTAssertEqual(t.wrongType, 1)
        XCTAssertEqual(t.missing, 0)

        newLayer()
        start("complete_view")
        draw(session.problem!.answer)
        let area = session.problem!.answerArea!
        draw([FfiProblemLine(
            a: FfiPoint(x: area.x + 10, y: area.y + 12), b: FfiPoint(x: area.x + area.w - 10, y: area.y + area.h - 12),
            lineType: 0, thin: false)])
        XCTAssertEqual(session.grade(layer: layer)!.extra, 1)
    }

    func testAShiftedAnswerIsMisalignedNotMissingAndExtra() {
        start("complete_view")
        draw(session.problem!.answer.map {
            FfiProblemLine(a: FfiPoint(x: $0.a.x + 9, y: $0.a.y), b: FfiPoint(x: $0.b.x + 9, y: $0.b.y), lineType: $0.lineType, thin: $0.thin)
        })
        let s = session.grade(layer: layer)!
        XCTAssertGreaterThanOrEqual(s.misaligned, 2)
        XCTAssertEqual(s.extra, 0)
    }

    func testTheSectionNeedsHatchingAtTheRightAngle() {
        start("section")
        draw(session.problem!.answer.filter { !$0.thin })
        XCTAssertTrue(session.grade(layer: layer)!.hatchMissing)

        newLayer()
        start("section")
        draw(session.problem!.answer) { _, line in
            // 轉成垂直、從原線中點上下各 0.35 倍長度：還在作答範圍內、長度也夠，報的是「角度不對」而不是「畫太少」。
            if line.thin {
                let len = Float(hypot(line.b.x - line.a.x, line.b.y - line.a.y)) * 0.35
                let mx = (line.a.x + line.b.x) / 2, my = (line.a.y + line.b.y) / 2
                return FfiProblemLine(a: FfiPoint(x: mx, y: my - len), b: FfiPoint(x: mx, y: my + len), lineType: line.lineType, thin: true)
            }
            return line
        }
        XCTAssertTrue(session.grade(layer: layer)!.hatchAngle)
    }

    func testLinesOutsideTheAnswerAreaAreIgnored() {
        start("complete_view")
        draw(session.problem!.answer)
        draw([FfiProblemLine(a: FfiPoint(x: 30, y: 30), b: FfiPoint(x: 300, y: 30), lineType: 0, thin: false)])
        XCTAssertEqual(session.grade(layer: layer)!.score, 100)
    }

    func testShowAnswerDrawsTheModelAnswerAsAnOverlayOnly() {
        start("complete_view")
        let before = layer.ownStrokes.count
        session.showAnswer(layer: layer)
        XCTAssertTrue(session.answerShown)
        XCTAssertEqual(layer.ownStrokes.count, before, "看答案不改內容")
        session.clearMarks(layer: layer)
        XCTAssertFalse(session.answerShown)
    }

    // MARK: 選擇題與挑錯題

    func testTheAngleQuestionAcceptsOnlyTheRightChoice() {
        for seed in UInt64(1) ... 6 {
            newLayer()
            start("angle_judgement", seed)
            let right = Int(session.problem!.correct!)
            session.choose(1 - right)
            XCTAssertEqual(session.feedback, l("draft_prob_choice_wrong"))
            session.choose(right)
            XCTAssertEqual(session.feedback, l("draft_prob_choice_right"))
        }
    }

    func testSpotTheErrorNeedsTheKindAndThePlace() {
        start("spot_error", 5)
        let p = session.problem!
        let at = p.errorAt!
        let right = Int(p.correct!)
        session.choose(right)
        XCTAssertEqual(DraftingState.shared.tool, .problemSpot)
        XCTAssertEqual(session.feedback, l("draft_prob_spot_tap"))
        // 點得很遠：不對。
        session.spot(at: CGPoint(x: CGFloat(at.x) + 400, y: CGFloat(at.y)), layer: layer)
        XCTAssertEqual(session.feedback, l("draft_prob_spot_wrong"))
        XCTAssertEqual(DraftingState.shared.tool, .none)
        // 再選一次、點對。
        session.choose(right)
        session.spot(at: CGPoint(x: CGFloat(at.x) + 10, y: CGFloat(at.y) - 8), layer: layer)
        XCTAssertEqual(session.feedback, l("draft_prob_spot_right"))
        // 位置對、種類錯：不算對。
        session.choose((right + 1) % 4)
        session.spot(at: CGPoint(x: CGFloat(at.x), y: CGFloat(at.y)), layer: layer)
        XCTAssertEqual(session.feedback, l("draft_prob_spot_wrong"))
    }

    func testTheSpotToolRoutesTapsThroughTheToolController() {
        start("spot_error", 5)
        let p = session.problem!
        session.choose(Int(p.correct!))
        let at = CGPoint(x: CGFloat(p.errorAt!.x), y: CGFloat(p.errorAt!.y))
        DraftToolController.shared.handle(.began, at, layer: layer)
        DraftToolController.shared.handle(.ended, at, layer: layer)
        XCTAssertEqual(session.feedback, l("draft_prob_spot_right"))
    }

    func testEndingThePracticeClearsTheSession() {
        start("complete_view")
        session.grade(layer: layer)
        session.end(layer: layer)
        XCTAssertFalse(session.isActive)
        XCTAssertNil(session.summary)
        XCTAssertTrue(layer.ownStrokes.contains { $0.layerId == 1 }, "題目線是頁面內容，留著")
    }
}
