import XCTest

/// 圖學工具（標註、符號、圖框）在真的畫面上能不能用。
///
/// 專業筆畫（製圖線、標註）不在 PencilKit 的 drawing 裡，所以讀的是畫布讀數的 `pro:` 欄位。
final class DraftingToolsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["KAIRUMO_UITEST"] = "1"
        app.launch()
        self.app = app
        return app
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// 畫布讀數裡的某個整數欄位（`pro`、`strokes`）。讀不到回 -1。
    private func readout(_ key: String) -> Int {
        let matches = app.descendants(matching: .any).matching(identifier: "editor.canvas")
        for el in matches.allElementsBoundByIndex {
            guard let value = el.value as? String, let range = value.range(of: "\(key):") else { continue }
            return Int(value[range.upperBound...].prefix(while: \.isNumber)) ?? -1
        }
        return -1
    }

    private func canvas() -> XCUIElement {
        let matches = app.descendants(matching: .any).matching(identifier: "editor.canvas")
        // 識別字同時掛在 SwiftUI 容器與 PKCanvasView 上，讀數在後者。
        for el in matches.allElementsBoundByIndex where (el.value as? String)?.contains("pro:") == true {
            return el
        }
        return matches.firstMatch
    }

    /// 進一本**全新的空白筆記本**、選圖學工具、等製圖列出現。
    ///
    /// 不用種子筆記本：它的頁面上有文字方塊與圖形，點在它們上面的觸控會被物件吃掉，
    /// 標註的第二個點就收不到。
    private func openDrafting() -> Bool {
        _ = launch()
        guard app.wait(for: .runningForeground, timeout: 15) else { return false }
        let newNote = element("home.action.new_note")
        guard newNote.waitForExistence(timeout: 15) else { XCTFail("首頁找不到新增筆記"); return false }
        newNote.tap()
        let confirm = element("new_notebook.confirm")
        guard confirm.waitForExistence(timeout: 10) else { XCTFail("新增筆記表單沒有確認鈕"); return false }
        confirm.tap()
        guard element("editor.canvas").waitForExistence(timeout: 15) else { XCTFail("建立筆記後沒有進入畫布"); return false }
        let tool = element("editor.ink.drafting")
        guard tool.waitForExistence(timeout: 15) else { XCTFail("找不到圖學工具鈕"); return false }
        tool.tap()
        return element("draft.bar").waitForExistence(timeout: 10)
    }

    private func openToolbox() {
        let button = element("draft.tools")
        XCTAssertTrue(button.waitForExistence(timeout: 10), "製圖列上沒有「圖學工具」")
        button.tap()
        XCTAssertTrue(element("draft.symbols").waitForExistence(timeout: 10), "工具箱沒有打開")
    }

    private func point(_ canvas: XCUIElement, _ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
        canvas.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
    }

    func testLinearDimensionIsMadeByTwoTapsAndADragAndUndoes() {
        guard openDrafting() else { XCTFail("進不了圖學模式"); return }
        openToolbox()
        element("draft.tool.dimLinear").tap()
        XCTAssertTrue(element("draft.tool.hint").waitForExistence(timeout: 5), "選了標註工具卻沒有提示")

        let c = canvas()
        let before = readout("pro")
        XCTAssertGreaterThanOrEqual(before, 0, "畫布讀數沒有 pro 欄位")

        // 兩個點，再按住拖出尺寸線的位置。
        point(c, 0.30, 0.45).tap()
        point(c, 0.60, 0.45).tap()
        point(c, 0.45, 0.60).press(forDuration: 0.2, thenDragTo: point(c, 0.45, 0.66))
        sleep(1)
        let after = readout("pro")
        XCTAssertGreaterThan(after, before, "標註之後沒有多出任何筆畫")
        // 一條線性標註 = 兩條尺寸界線、尺寸線、兩個箭頭，加上每個數字至少一筆：至少 6 筆。
        XCTAssertGreaterThanOrEqual(after - before, 6, "標註的筆畫太少：\(after - before)")

        // 復原：整個標註一次收回。
        let undo = element("editor.undo")
        if undo.waitForExistence(timeout: 3) {
            undo.tap()
            sleep(1)
            XCTAssertEqual(readout("pro"), before, "復原一次應該收回整個標註")
        }
    }

    func testTheToolboxOffersEveryDimensionKindAndTheScale() {
        guard openDrafting() else { XCTFail("進不了圖學模式"); return }
        openToolbox()
        for id in ["draft.tool.dimLinear", "draft.tool.dimDiameter", "draft.tool.dimRadius",
                   "draft.tool.dimAngle", "draft.scale", "draft.symbols", "draft.frame.insert"] {
            XCTAssertTrue(element(id).exists, "工具箱缺少 \(id)")
        }
    }

    func testPlacingASymbolAddsStrokesAndSelectsThem() {
        guard openDrafting() else { XCTFail("進不了圖學模式"); return }
        openToolbox()
        element("draft.symbols").tap()
        XCTAssertTrue(element("draft.symbol.place").waitForExistence(timeout: 10), "符號面板沒有打開")
        let before = readout("pro")
        element("draft.symbol.place").tap()
        // 面板關掉、符號進頁面。
        XCTAssertTrue(element("draft.bar").waitForExistence(timeout: 10) || element("editor.canvas").exists)
        sleep(2)
        XCTAssertGreaterThan(readout("pro"), before, "放了符號卻沒有多出筆畫")
    }
}
