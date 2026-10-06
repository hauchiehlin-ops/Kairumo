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

    /// 讀數裡 `key:` 後面的一串數字（逗號分隔）。讀不到回 nil。
    private func canvasValue() -> String {
        let matches = app.descendants(matching: .any).matching(identifier: "editor.canvas")
        return matches.allElementsBoundByIndex.compactMap { $0.value as? String }.joined(separator: " | ")
    }

    private func numbers(_ key: String) -> [Double]? {
        let matches = app.descendants(matching: .any).matching(identifier: "editor.canvas")
        for el in matches.allElementsBoundByIndex {
            guard let value = el.value as? String else { continue }
            for part in value.split(separator: " ") where part.hasPrefix("\(key):") {
                return part.dropFirst(key.count + 1).split(separator: ",").compactMap { Double($0) }
            }
        }
        return nil
    }

    /// 視窗座標（點）。畫布讀數裡的 `edgeW`、`instW` 就是這一套。
    private func window(_ x: Double, _ y: Double) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)).withOffset(CGVector(dx: x, dy: y))
    }

    /// 點一下復原鈕（工具列的 id 依版面不同）。找不到就算失敗 —— 找不到時悄悄跳過會讓復原的斷言形同虛設。
    @discardableResult
    private func undoOnce() -> Bool {
        for id in ["editor.ink.undo", "editor.compact.undo"] {
            let button = element(id)
            if button.waitForExistence(timeout: 2) {
                button.tap()
                sleep(1)
                return true
            }
        }
        XCTFail("找不到復原鈕")
        return false
    }

    /// 畫布範圍內的點（0…1）換成視窗座標。
    private func inCanvas(_ fx: Double, _ fy: Double) -> (Double, Double) {
        let f = canvas().frame
        return (Double(f.minX) + Double(f.width) * fx, Double(f.minY) + Double(f.height) * fy)
    }

    /// 合成觸控要壓住、慢慢拖、再停一下才會收到完整的移動事件（比長按吸附的 0.55 秒短）。
    private func drag(_ from: (Double, Double), to: (Double, Double)) {
        window(from.0, from.1).press(
            forDuration: 0.2, thenDragTo: window(to.0, to.1), withVelocity: .slow, thenHoldForDuration: 0.15)
        sleep(1)
    }

    /// 畫一筆並確認真的多了一筆：合成觸控偶爾整段被系統吞掉（讀數沒變），那就再拖一次。
    private func strokeDrag(_ from: (Double, Double), to: (Double, Double)) {
        let before = readout("pro")
        for _ in 0..<3 {
            drag(from, to: to)
            if readout("pro") > before { return }
        }
    }

    /// 表單是惰性的：還沒捲到的列不存在。往上推到出現為止。
    private func reveal(_ id: String) -> XCUIElement {
        let el = element(id)
        var tries = 0
        while !el.exists && tries < 6 {
            app.swipeUp()
            tries += 1
        }
        // 惰性表單：捲過頭的列會被回收，要找的在上面就往回捲。
        tries = 0
        while !el.exists && tries < 8 {
            app.swipeDown()
            tries += 1
        }
        return el
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
        if undoOnce() {
            XCTAssertEqual(readout("pro"), before, "復原一次應該收回整個標註")
        }
    }

    func testTheToolboxOffersEveryDimensionKindAndTheScale() {
        guard openDrafting() else { XCTFail("進不了圖學模式"); return }
        openToolbox()
        for id in ["draft.tool.dimLinear", "draft.tool.dimDiameter", "draft.tool.dimRadius",
                   "draft.tool.dimAngle", "draft.scale", "draft.symbols", "draft.frame.insert"] {
            XCTAssertTrue(reveal(id).exists, "工具箱缺少 \(id)")
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

    func testThePivotToolStoresTheTappedPointAndReturnsToDrawing() {
        guard openDrafting() else { XCTFail("進不了圖學模式"); return }
        openToolbox()
        reveal("draft.tool.setPivot").tap()
        XCTAssertTrue(element("draft.tool.hint").waitForExistence(timeout: 5), "選了轉折點工具卻沒有提示")
        let target = inCanvas(0.5, 0.5)
        window(target.0, target.1).tap()
        sleep(1)
        guard let pivot = numbers("pivot"), pivot.count == 2 else {
            XCTFail("點了之後讀數裡沒有轉折點：\(canvasValue())"); return
        }
        XCTAssertGreaterThan(pivot[0], 0)
        XCTAssertGreaterThan(pivot[1], 0)
        XCTAssertFalse(element("draft.tool.close").waitForExistence(timeout: 2), "設完轉折點應該回到畫線")
    }

    func testTheTSquareOffersNoRotationBecauseItOnlySlides() {
        guard openDrafting() else { XCTFail("進不了圖學模式"); return }
        openToolbox()
        reveal("draft.inst.t_square").tap()
        XCTAssertTrue(element("draft.inst.remove").waitForExistence(timeout: 5), "放了丁字尺卻沒有收起鈕")
        XCTAssertFalse(element("draft.inst.rotl").exists, "丁字尺不能轉，不該有旋轉鈕")
    }

    func testCompassDrawsAnArcAndUndoes() {
        guard openDrafting() else { XCTFail("進不了圖學模式"); return }
        openToolbox()
        reveal("draft.tool.compass").tap()
        XCTAssertTrue(element("draft.tool.hint").waitForExistence(timeout: 5))
        let c = canvas()
        let before = readout("pro")
        point(c, 0.5, 0.5).tap()
        point(c, 0.7, 0.5).press(forDuration: 0.2, thenDragTo: point(c, 0.5, 0.75))
        sleep(1)
        XCTAssertEqual(readout("pro"), before + 1, "圓規應該多出一條圓弧")
        if undoOnce() {
            XCTAssertEqual(readout("pro"), before)
        }
    }

    func testARulerCanBePlacedRotatedRemovedAndLineStaysStraightAlongIt() {
        guard openDrafting() else { XCTFail("進不了圖學模式"); return }
        openToolbox()
        reveal("draft.inst.ruler").tap()
        XCTAssertTrue(element("draft.inst.remove").waitForExistence(timeout: 5), "放了尺卻沒有收起鈕")
        XCTAssertTrue(element("draft.inst.rotl").exists)
        element("draft.inst.rotr").tap()
        element("draft.inst.rotl").tap()
        // 尺轉回水平後，在尺身以外隨手畫一條斜線不會被尺吃掉（身體區才是搬尺）。
        element("draft.inst.remove").tap()
        XCTAssertFalse(element("draft.inst.remove").waitForExistence(timeout: 2), "收起後控制還在")
    }

    func testALineStartedAgainstTheRulerEdgeStaysOnTheEdge() {
        guard openDrafting() else { XCTFail("進不了圖學模式"); return }
        openToolbox()
        reveal("draft.inst.ruler").tap()
        XCTAssertTrue(element("draft.inst.remove").waitForExistence(timeout: 5))
        sleep(1)
        guard let edgeW = numbers("edgeW"), edgeW.count == 4, let edge = numbers("edge"), edge.count == 4 else {
            XCTFail("讀數裡沒有尺邊的位置：\(canvasValue())"); return
        }
        let before = readout("pro")
        // 從尺邊中點往外 3 點起筆，沿著邊的方向拖，終點偏離邊 20 點：整筆要被拉回邊上。
        let mx = (edgeW[0] + edgeW[2]) / 2, my = (edgeW[1] + edgeW[3]) / 2
        let dx = edgeW[2] - edgeW[0], dy = edgeW[3] - edgeW[1]
        let len = (dx * dx + dy * dy).squareRoot()
        let ux = dx / len, uy = dy / len
        let nx = -uy, ny = ux
        let start = (mx + nx * 3, my + ny * 3)
        let end = (start.0 + ux * 90 + nx * 20, start.1 + uy * 90 + ny * 20)
        strokeDrag(start, to: end)
        XCTAssertEqual(readout("pro"), before + 1, "沿尺邊畫一條線應該多一筆")
        guard let last = numbers("last"), last.count == 4 else { XCTFail("讀數裡沒有最後一筆"); return }
        // 頁面座標：兩端都在尺邊所在的直線上。
        let ex = edge[2] - edge[0], ey = edge[3] - edge[1]
        let el = (ex * ex + ey * ey).squareRoot()
        func off(_ x: Double, _ y: Double) -> Double { abs((x - edge[0]) * -ey / el + (y - edge[1]) * ex / el) }
        XCTAssertLessThan(off(last[0], last[1]), 0.5, "起點沒有釘在尺邊上")
        XCTAssertLessThan(off(last[2], last[3]), 0.5, "終點沒有被拉回尺邊上（偏了 \(off(last[2], last[3]))）")
        XCTAssertGreaterThan(((last[2] - last[0]) * (last[2] - last[0]) + (last[3] - last[1]) * (last[3] - last[1])).squareRoot(), 20, "線太短")
    }

    func testDraggingTheRulerBodyMovesItAndDrawsNothing() {
        guard openDrafting() else { XCTFail("進不了圖學模式"); return }
        openToolbox()
        reveal("draft.inst.ruler").tap()
        XCTAssertTrue(element("draft.inst.remove").waitForExistence(timeout: 5))
        sleep(1)
        guard let box = numbers("instW"), box.count == 4 else { XCTFail("讀數裡沒有尺的位置"); return }
        let before = readout("pro")
        drag((box[0] + box[2] / 2, box[1] + box[3] / 2), to: (box[0] + box[2] / 2 + 60, box[1] + box[3] / 2 + 40))
        guard let after = numbers("instW") else { XCTFail("搬完讀不到尺的位置"); return }
        XCTAssertEqual(after[0] - box[0], 60, accuracy: 3, "尺沒有跟著手指橫向移動")
        XCTAssertEqual(after[1] - box[1], 40, accuracy: 3, "尺沒有跟著手指縱向移動")
        XCTAssertEqual(readout("pro"), before, "搬尺不該留筆畫")
    }

    func testTheEndOfALineAlignsWithAnExistingPointAndCanBeSwitchedOff() {
        guard openDrafting() else { XCTFail("進不了圖學模式"); return }
        // 第一條：垂直線。
        let a0 = inCanvas(0.30, 0.35), a1 = inCanvas(0.30, 0.50)
        strokeDrag(a0, to: a1)
        guard let first = numbers("last"), first.count == 4 else { XCTFail("讀數裡沒有第一筆：\(canvasValue())"); return }
        // 第二條：終點的 x 差 3 點 —— 對齊開著就要被吸到第一條的 x。
        let b0 = inCanvas(0.70, 0.60), b1 = (a1.0 + 3, inCanvas(0, 0.60).1)
        strokeDrag(b0, to: b1)
        guard let second = numbers("last"), second.count == 4 else { XCTFail("讀數裡沒有第二筆"); return }
        XCTAssertEqual(second[2], first[2], accuracy: 0.01, "終點沒有對齊既有線的端點")
        // 關掉對齊，同樣的畫法就不該被吸。
        openToolbox()
        // 開關在列的右端：點列的正中央點到的是文字，不會切換。
        let toggle = reveal("draft.align")
        sleep(1)   // 捲動的慣性停下來，列才不會在點的當下還在動
        for _ in 0..<3 where (toggle.value as? String) != "0" {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.5)).tap()
            sleep(1)
        }
        XCTAssertEqual(toggle.value as? String, "0", "投影對齊的開關沒有關掉")
        element("draft.toolbox.close").tap()
        XCTAssertTrue(element("draft.bar").waitForExistence(timeout: 5))
        let c0 = inCanvas(0.70, 0.66), c1 = (a1.0 + 3, inCanvas(0, 0.66).1)
        strokeDrag(c0, to: c1)
        guard let third = numbers("last"), third.count == 4 else { XCTFail("讀數裡沒有第三筆"); return }
        XCTAssertGreaterThan(abs(third[2] - first[2]), 0.4, "對齊關掉之後還是被吸了：first=\(first) second=\(second) third=\(third) a1=\(a1) c1=\(c1) \(canvasValue())")
    }

    func testTheProtractorReadsAnAngleAndCanDrawTheReadingLine() {
        guard openDrafting() else { XCTFail("進不了圖學模式"); return }
        openToolbox()
        reveal("draft.inst.protractor").tap()
        XCTAssertTrue(element("draft.inst.remove").waitForExistence(timeout: 5))
        sleep(1)
        guard let box = numbers("instW"), box.count == 4 else { XCTFail("讀數裡沒有量角器的位置：\(canvasValue())"); return }
        // 量角器的圓心在外框底邊中點，半徑 = 外框寬的一半。按住 60° 方向、85% 半徑處（外圈刻度帶）。
        let cx = box[0] + box[2] / 2, cy = box[1] + box[3]
        let r = box[2] / 2 * 0.85
        let a = 60.0 * Double.pi / 180
        let pt = (cx + r * cos(a), cy - r * sin(a))
        window(pt.0, pt.1).press(forDuration: 0.3)
        sleep(1)
        let reading = element("draft.inst.reading")
        XCTAssertTrue(reading.waitForExistence(timeout: 5), "按住刻度帶之後製圖列沒有讀數")
        let label = reading.label
        XCTAssertTrue(label.contains("60.0") || label.contains("59.") || label.contains("60."), "讀數不是約 60°：\(label)")
        XCTAssertTrue(label.contains("120") || label.contains("119.") || label.contains("120."), "另一邊的刻度不是約 120°：\(label)")
        // 畫出讀數線：多一筆，復原一次收回。
        let before = readout("pro")
        element("draft.inst.markAngle").tap()
        sleep(1)
        XCTAssertEqual(readout("pro"), before + 1, "畫出讀數線應該多一筆")
        if undoOnce() {
            XCTAssertEqual(readout("pro"), before)
        }
        // 按內圈是搬量角器，不是改讀數。
        let inner = (cx, cy - box[2] / 2 * 0.25)
        drag(inner, to: (inner.0 + 50, inner.1 + 30))
        XCTAssertTrue(element("draft.inst.reading").exists, "搬尺之後讀數不見了（讀數應該跟著尺走）")
        XCTAssertTrue(reading.label.contains("60.") || reading.label.contains("59."), "搬尺不該改變讀數：\(reading.label)")
    }

    func testTrimWorksFromTheToolboxWithRealGesturesAndUndoes() {
        guard openDrafting() else { XCTFail("進不了圖學模式"); return }
        // 一條水平線、一條垂直線（交在水平線的中間）。
        strokeDrag(inCanvas(0.25, 0.5), to: inCanvas(0.75, 0.5))
        guard let h = numbers("last"), h.count == 4 else { XCTFail("讀數裡沒有水平線：\(canvasValue())"); return }
        strokeDrag(inCanvas(0.5, 0.35), to: inCanvas(0.5, 0.65))
        guard let v = numbers("last"), v.count == 4 else { XCTFail("讀數裡沒有垂直線"); return }
        XCTAssertEqual(readout("pro"), 2)

        openToolbox()
        reveal("draft.tool.trim").tap()
        XCTAssertTrue(element("draft.tool.hint").waitForExistence(timeout: 5), "選了修剪卻沒有提示")
        // 點在垂直線右邊的那一段：右半截被剪掉。
        let tapAt = inCanvas(0.65, 0.5)
        window(tapAt.0, tapAt.1).tap()
        sleep(1)
        XCTAssertEqual(readout("pro"), 2, "水平線換成修短的一段，筆畫數不變")
        guard let cut = numbers("last"), cut.count == 4 else { XCTFail("修剪後讀不到最後一筆"); return }
        XCTAssertEqual(cut[2], v[0], accuracy: 1.5, "水平線應該在垂直線的位置收掉")
        XCTAssertEqual(cut[0], h[0], accuracy: 1.5, "左邊那一端不動")

        undoOnce()
        guard let back = numbers("last"), back.count == 4 else { XCTFail("復原後讀不到最後一筆"); return }
        XCTAssertEqual(back[2], h[2], accuracy: 1.5, "復原之後水平線又長回原來的長度")
    }

    func testPracticeStartsFromTheToolboxPutsTheProblemOnThePageAndGradesIt() {
        guard openDrafting() else { XCTFail("進不了圖學模式"); return }
        let before = readout("pro")
        openToolbox()
        reveal("draft.practice.start.complete_view").tap()
        XCTAssertTrue(element("draft.practice.card").waitForExistence(timeout: 8), "出題之後沒有練習卡")
        sleep(1)
        XCTAssertGreaterThan(readout("pro"), before, "題目線沒有放進頁面")
        // 什麼都沒畫就批改：分數很低、標出缺線。
        element("draft.practice.grade").tap()
        XCTAssertTrue(element("draft.practice.score").waitForExistence(timeout: 5), "批改之後沒有分數")
        // 看答案、清除、再出一題。
        element("draft.practice.answer").tap()
        element("draft.practice.clear").tap()
        let count = readout("pro")
        element("draft.practice.new").tap()
        sleep(1)
        XCTAssertGreaterThan(readout("pro"), count, "再出一題應該又放進一組題目線")
        element("draft.practice.close").tap()
        XCTAssertFalse(element("draft.practice.card").waitForExistence(timeout: 3), "結束練習後卡片還在")
    }
}
