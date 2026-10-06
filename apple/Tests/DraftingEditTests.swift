//
//  DraftingEditTests.swift
//  KairumoTests
//
//  編輯工具（修剪、延伸、圓角、偏移、鏡射、陣列）：走真正的 `ProInkLayerView` 與 `DraftEditController`，
//  驗證結果寫進了檔案、復原與重做把檔案也還原。對應 Android 的 `DraftingEditTest`。
//

import XCTest
@testable import Kairumo

@MainActor
final class DraftingEditTests: XCTestCase {
    private var workDir: URL!
    private var manager: UndoManager!
    private var layer: ProInkLayerView!
    private var drafting: DraftingState { DraftingState.shared }
    private var editor: DraftEditController { DraftEditController.shared }

    override func setUpWithError() throws {
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-edit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        manager = UndoManager()
        manager.groupsByEvent = false
        layer = ProInkLayerView(frame: CGRect(x: 0, y: 0, width: 800, height: 1000))
        layer.undoManagerProvider = { [manager] in manager }
        layer.load(directory: workDir, notebookId: "edit", pageIndex: 0)
        drafting.use(notebook: "edit-\(UUID().uuidString)")
        drafting.tool = .none
        drafting.alignEnabled = false
        drafting.filletRadiusMm = 5
        drafting.offsetDistanceMm = 5
        editor.reset(layer: layer)
    }

    override func tearDownWithError() throws {
        drafting.alignEnabled = true
        drafting.tool = .none
        drafting.editSelection = []
        try? FileManager.default.removeItem(at: workDir)
    }

    // MARK: 工具

    /// 畫一條直線（頂層、製圖筆）。
    @discardableResult
    private func line(_ x0: Float, _ y0: Float, _ x1: Float, _ y1: Float, layerId: UInt8 = 3, lineType: UInt8 = 0) -> ProStroke {
        let item = FfiSheetStroke(
            points: [FfiPoint(x: x0, y: y0), FfiPoint(x: x1, y: y1)], layer: layerId, lineType: lineType,
            width: 1.2, colorHex: "#222222")
        manager.beginUndoGrouping()
        let made = layer.insertDrafted([item], origin: .zero)
        manager.endUndoGrouping()
        return made[0]
    }

    private func tap(_ tool: DraftTool, _ x: CGFloat, _ y: CGFloat) {
        manager.beginUndoGrouping()
        editor.handle(.began, CGPoint(x: x, y: y), tool: tool, layer: layer)
        editor.handle(.ended, CGPoint(x: x, y: y), tool: tool, layer: layer)
        manager.endUndoGrouping()
    }

    private func persisted() -> Int { ProInkStore.load(in: workDir, notebookId: "edit", page: 0).count }
    private func xs(_ s: ProStroke) -> [Float] { s.points.map(\.x) }
    private func ys(_ s: ProStroke) -> [Float] { s.points.map(\.y) }
    private func isHorizontal(_ s: ProStroke, at y: Float) -> Bool { ys(s).allSatisfy { abs($0 - y) < 0.5 } }
    private func l(_ key: String) -> String { LocalizationManager.shared.localized(key) }

    // MARK: 修剪

    func testTrimCutsAwayThePartBetweenCrossingsAndUndoesAndRedoes() {
        line(100, 200, 500, 200)
        line(300, 100, 300, 300)
        tap(.trim, 420, 200)
        XCTAssertEqual(layer.ownStrokes.count, 2)
        let horizontal = layer.ownStrokes.first { isHorizontal($0, at: 200) }!
        XCTAssertEqual(xs(horizontal).max()!, 300, accuracy: 0.6, "水平線在交點 x=300 收掉")
        XCTAssertEqual(xs(horizontal).min()!, 100, accuracy: 0.6)
        XCTAssertEqual(persisted(), 2)

        manager.undo()
        XCTAssertEqual(layer.ownStrokes.count, 2)
        XCTAssertEqual(layer.ownStrokes.flatMap(xs).max()!, 500, accuracy: 0.6, "復原之後水平線又長到 500")
        XCTAssertEqual(persisted(), 2)

        manager.redo()
        let again = layer.ownStrokes.filter { isHorizontal($0, at: 200) }
        XCTAssertEqual(again.flatMap(xs).max()!, 300, accuracy: 0.6, "重做又剪掉")
        XCTAssertEqual(persisted(), 2)
    }

    func testTrimTheMiddleLeavesTwoPieces() {
        line(100, 200, 500, 200)
        line(200, 100, 200, 300)
        line(400, 100, 400, 300)
        tap(.trim, 300, 200)
        XCTAssertEqual(layer.ownStrokes.count, 4, "左右兩段加兩條垂直線")
        manager.undo()
        XCTAssertEqual(layer.ownStrokes.count, 3)
    }

    func testTrimExplainsWhenThereIsNothingToCutAgainst() {
        line(100, 200, 500, 200)
        tap(.trim, 300, 200)
        XCTAssertEqual(layer.ownStrokes.count, 1)
        XCTAssertEqual(drafting.toolHint, l("draft_edit_no_crossing"))
        XCTAssertTrue(editor.consumeNotice())
        tap(.trim, 300, 700)
        XCTAssertEqual(drafting.toolHint, l("draft_edit_nothing"))
    }

    func testEditedStrokesKeepThePenLayerAndLineTypeOfTheOriginal() {
        line(100, 200, 500, 200, layerId: 2, lineType: 1)
        line(300, 100, 300, 300)
        tap(.trim, 420, 200)
        let cut = layer.ownStrokes.first { $0.layerId == 2 }!
        XCTAssertEqual(cut.lineTypeId, 1, "修剪之後仍是隱藏線")
        XCTAssertEqual(cut.colorRGBA.prefix(3), [0x22, 0x22, 0x22])
    }

    // MARK: 延伸

    func testExtendRunsTheNearEndToTheNearestLine() {
        line(100, 200, 250, 200)
        line(400, 100, 400, 300)
        line(600, 100, 600, 300)
        tap(.extend, 248, 202)
        let extended = layer.ownStrokes.first { isHorizontal($0, at: 200) }!
        XCTAssertEqual(xs(extended).max()!, 400, accuracy: 0.6, "延伸到最近的線")
        XCTAssertEqual(xs(extended).min()!, 100, accuracy: 0.6)
        XCTAssertEqual(layer.ownStrokes.count, 3)
        manager.undo()
        XCTAssertEqual(layer.ownStrokes.flatMap(xs).filter { $0 < 300 }.max()!, 250, accuracy: 0.6)
        XCTAssertEqual(persisted(), 3)
    }

    func testExtendExplainsWhenNothingLiesAhead() {
        line(100, 200, 250, 200)
        tap(.extend, 248, 202)
        XCTAssertEqual(drafting.toolHint, l("draft_edit_no_boundary"))
        XCTAssertEqual(layer.ownStrokes.count, 1)
    }

    // MARK: 圓角

    func testFilletJoinsTwoLinesWithAnArcAndUndoesAsOne() {
        line(100, 400, 300, 400)
        line(300, 400, 300, 200)
        tap(.fillet, 200, 400)
        tap(.fillet, 300, 300)
        XCTAssertEqual(layer.ownStrokes.count, 3, "兩條線加一段圓弧")
        let r = 5 * draftUnitsPerMm()
        let arc = layer.ownStrokes.first { (xs($0).max()! - xs($0).min()!) > 1 && (ys($0).max()! - ys($0).min()!) > 1 }!
        for p in arc.points {
            XCTAssertEqual(hypot(p.x - (300 - r), p.y - (400 - r)), r, accuracy: 0.6)
        }
        XCTAssertEqual(persisted(), 3)
        manager.undo()
        XCTAssertEqual(layer.ownStrokes.count, 2, "一次復原收回圓弧並還原兩條線")
        XCTAssertEqual(layer.ownStrokes.flatMap(xs).max()!, 300, accuracy: 0.6)
    }

    func testFilletRefusesParallelLinesWithAnExplanation() {
        line(100, 400, 300, 400)
        line(100, 300, 300, 300)
        tap(.fillet, 200, 400)
        tap(.fillet, 200, 300)
        XCTAssertEqual(layer.ownStrokes.count, 2)
        XCTAssertEqual(drafting.toolHint, l("draft_edit_fillet_fail"))
    }

    // MARK: 偏移

    func testOffsetAddsAParallelLineOnTheTappedSide() {
        line(100, 300, 400, 300)
        tap(.offset, 250, 300)
        tap(.offset, 250, 380)
        XCTAssertEqual(layer.ownStrokes.count, 2, "原來那條留著、多一條")
        let d = 5 * draftUnitsPerMm()
        let copy = layer.ownStrokes.last!
        for p in copy.points { XCTAssertEqual(p.y, 300 + d, accuracy: 0.6) }
        XCTAssertEqual(xs(copy).min()!, 100, accuracy: 0.6)
        XCTAssertEqual(persisted(), 2)
        manager.undo()
        XCTAssertEqual(layer.ownStrokes.count, 1)
    }

    // MARK: 鏡射

    func testMirrorCopiesTheSelectedLinesAcrossTheDraggedAxisWithALivePreview() {
        let original = line(100, 100, 200, 100)
        drafting.editSelection = [original.id]
        tap(.mirror, 400, 50)
        editor.handle(.began, CGPoint(x: 400, y: 250), tool: .mirror, layer: layer)
        editor.handle(.moved, CGPoint(x: 400, y: 260), tool: .mirror, layer: layer)
        XCTAssertEqual(layer.ownStrokes.count, 1, "預覽不算內容")
        manager.beginUndoGrouping()
        editor.handle(.ended, CGPoint(x: 400, y: 260), tool: .mirror, layer: layer)
        manager.endUndoGrouping()
        XCTAssertEqual(layer.ownStrokes.count, 2, "原件留著、多一份鏡射")
        let m = layer.ownStrokes.last!
        XCTAssertEqual(xs(m).min()!, 600, accuracy: 0.8, "鏡射過 x=400：100→700、200→600")
        XCTAssertEqual(xs(m).max()!, 700, accuracy: 0.8)
        XCTAssertEqual(persisted(), 2)
        manager.undo()
        XCTAssertEqual(layer.ownStrokes.count, 1)
    }

    func testMirrorAsksForASelectionFirst() {
        line(100, 100, 200, 100)
        drafting.editSelection = []
        tap(.mirror, 400, 50)
        XCTAssertEqual(layer.ownStrokes.count, 1)
        XCTAssertEqual(drafting.toolHint, l("draft_edit_need_selection"))
    }

    // MARK: 陣列

    func testARectangularArrayMakesRowsTimesColumnsMinusTheOriginal() {
        let original = line(100, 100, 160, 100)
        drafting.editSelection = [original.id]
        manager.beginUndoGrouping()
        let n = editor.applyRectArray(rows: 2, cols: 3, dxMm: 30, dyMm: 20, layer: layer)
        manager.endUndoGrouping()
        XCTAssertEqual(n, 5)
        XCTAssertEqual(layer.ownStrokes.count, 6)
        let unit = draftUnitsPerMm()
        XCTAssertTrue(layer.ownStrokes.contains {
            abs($0.points[0].x - (100 + 2 * 30 * unit)) < 0.8 && abs($0.points[0].y - (100 + 20 * unit)) < 0.8
        }, "第三欄第二列")
        XCTAssertEqual(persisted(), 6)
        manager.undo()
        XCTAssertEqual(layer.ownStrokes.count, 1, "整個陣列一次復原")
    }

    func testAPolarArraySpreadsCopiesAroundTheTappedCenter() {
        let original = line(400, 300, 460, 300)
        drafting.editSelection = [original.id]
        drafting.polarCount = 4
        drafting.polarTotalDeg = 360
        tap(.arrayPolar, 300, 300)
        XCTAssertEqual(layer.ownStrokes.count, 4)
        XCTAssertTrue(layer.ownStrokes.contains { abs($0.points[0].x - 200) < 0.8 && abs($0.points[0].y - 300) < 0.8 },
                      "轉 180° 的那份")
        XCTAssertEqual(persisted(), 4)
        manager.undo()
        XCTAssertEqual(layer.ownStrokes.count, 1)
    }
}
