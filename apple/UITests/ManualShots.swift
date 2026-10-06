import XCTest

/// 操作手冊的截圖。**平常不跑**：沒有設 `KAIRUMO_SHOTS_DIR` 就跳過。
///
/// 用法（iPad mini，尺寸與既有手冊截圖一致）：
/// `TEST_RUNNER_KAIRUMO_SHOTS_DIR=<資料夾> TEST_RUNNER_KAIRUMO_SHOTS_LANG=zh-Hant xcodebuild test … -only-testing:KairumoUITests/ManualShots`
/// 每張存成 `<資料夾>/<語系>_<名稱>.png`，再由 `scripts/manual_shots.py` 縮成手冊用的 744×1133。
final class ManualShots: XCTestCase {
    private var app: XCUIApplication!
    private var dir = ""
    private var lang = "en"

    override func setUpWithError() throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        dir = env["KAIRUMO_SHOTS_DIR"] ?? ""
        lang = env["KAIRUMO_SHOTS_LANG"] ?? "en"
        try XCTSkipIf(dir.isEmpty, "只有要重拍手冊截圖時才跑（需要 KAIRUMO_SHOTS_DIR）")
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func shot(_ name: String) {
        sleep(1)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? png.write(to: URL(fileURLWithPath: "\(dir)/\(lang)_\(name).png"))
    }

    private func reveal(_ id: String) -> XCUIElement {
        let el = element(id)
        var tries = 0
        while !el.exists && tries < 8 { app.swipeUp(); tries += 1 }
        tries = 0
        while !el.exists && tries < 10 { app.swipeDown(); tries += 1 }
        return el
    }

    private func canvas() -> XCUIElement {
        let matches = app.descendants(matching: .any).matching(identifier: "editor.canvas")
        for el in matches.allElementsBoundByIndex where (el.value as? String)?.contains("pro:") == true { return el }
        return matches.firstMatch
    }

    private func at(_ fx: Double, _ fy: Double) -> XCUICoordinate {
        let f = canvas().frame
        return app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: Double(f.minX) + Double(f.width) * fx, dy: Double(f.minY) + Double(f.height) * fy))
    }

    private func openToolbox() {
        let tools = element("draft.tools")
        XCTAssertTrue(tools.waitForExistence(timeout: 10))
        tools.tap()
        XCTAssertTrue(element("draft.tool.dimLinear").waitForExistence(timeout: 10), "工具箱沒有打開")
    }

    private func closeToolbox() {
        if element("draft.toolbox.close").exists { element("draft.toolbox.close").tap() }
        _ = element("draft.bar").waitForExistence(timeout: 5)
    }

    private func enterDrafting() {
        let tool = element("editor.ink.drafting")
        XCTAssertTrue(tool.waitForExistence(timeout: 15))
        // 工具列剛出現時第一下點擊偶爾會被吃掉：最多點三次，每次都先處理第一次使用的提示。
        for _ in 0..<3 {
            sleep(1)
            tool.tap()
            let alert = app.alerts.firstMatch
            if alert.waitForExistence(timeout: 3) { alert.buttons.firstMatch.tap() }
            if element("draft.bar").waitForExistence(timeout: 6) { return }
        }
        try? app.debugDescription.write(toFile: "\(dir)/debug-tree.txt", atomically: true, encoding: .utf8)
        shot("debug-fail")
        XCTFail("找不到製圖列（樹已存到 debug-tree.txt）")
    }

    func testTakeTheDraftingShots() throws {
        app = XCUIApplication()
        app.launchEnvironment["KAIRUMO_UITEST"] = "1"
        app.launchEnvironment["KAIRUMO_UITEST_LANGUAGE"] = lang
        app.launch()
        XCTAssertTrue(element("home.action.new_note").waitForExistence(timeout: 20))
        element("home.action.new_note").tap()
        XCTAssertTrue(element("new_notebook.confirm").waitForExistence(timeout: 10))
        element("new_notebook.confirm").tap()
        XCTAssertTrue(element("editor.canvas").waitForExistence(timeout: 20))
        enterDrafting()

        // 立體輔助：預設的 U 形，插入三視圖（先看一眼設定畫面）。
        element("draft.solidStudio").tap()
        XCTAssertTrue(element("solid.tab").waitForExistence(timeout: 10))
        shot("solidstudio")
        // 玻璃盒：拉到展開一半。
        element("solid.tab").buttons.element(boundBy: 2).tap()
        let slider = reveal("solid.glass.t")
        XCTAssertTrue(slider.exists)
        slider.adjust(toNormalizedSliderPosition: 0.55)
        shot("glassbox")
        // 3D 匯出。
        _ = reveal("solid.export.usdz")
        shot("solidexport")
        // 插入三視圖。
        element("solid.tab").buttons.element(boundBy: 0).tap()
        element("solid.insert").tap()
        XCTAssertTrue(element("editor.canvas").waitForExistence(timeout: 10))
        sleep(1)
        enterDrafting()

        // 尺寸標註 + 工具箱。
        openToolbox()
        element("draft.tool.dimLinear").tap()
        sleep(1)
        at(0.22, 0.30).tap()
        at(0.52, 0.30).tap()
        at(0.37, 0.24).press(forDuration: 0.2, thenDragTo: at(0.37, 0.21))
        sleep(1)
        openToolbox()
        shot("drafttools")
        // 編輯工具。
        _ = reveal("draft.tool.trim")
        shot("draftedit")
        // 匯出本頁圖形。
        _ = reveal("draft.export.svg")
        shot("draftexport")
        closeToolbox()

        // 尺規：量角器，按住外圈讀角度。
        openToolbox()
        reveal("draft.inst.protractor").tap()
        sleep(1)
        let box = (element("editor.canvas").value as? String) ?? ""
        _ = box
        shot("draftaids_placed")
        // 在量角器外圈 60° 方向按住。位置從畫布讀數取。
        let matches = app.descendants(matching: .any).matching(identifier: "editor.canvas").allElementsBoundByIndex
        for el in matches {
            guard let v = el.value as? String, let r = v.range(of: "instW:") else { continue }
            let nums = v[r.upperBound...].prefix(while: { $0 != " " }).split(separator: ",").compactMap { Double($0) }
            if nums.count == 4 {
                let cx = nums[0] + nums[2] / 2, cy = nums[1] + nums[3]
                let rad = nums[2] / 2 * 0.85
                let a = 60.0 * Double.pi / 180
                app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                    .withOffset(CGVector(dx: cx + rad * cos(a), dy: cy - rad * sin(a))).press(forDuration: 0.3)
                break
            }
        }
        shot("draftaids")
        if element("draft.inst.remove").exists { element("draft.inst.remove").tap() }

        // 練習題：補第三視圖，批改空白頁並顯示答案。
        openToolbox()
        reveal("draft.practice.start.complete_view").tap()
        XCTAssertTrue(element("draft.practice.card").waitForExistence(timeout: 8))
        sleep(1)
        element("draft.practice.grade").tap()
        sleep(1)
        element("draft.practice.answer").tap()
        shot("draftpractice")
    }

    /// 一筆從 (x1,y1) 到 (x2,y2) 的線，尾端按住不放，讓「形狀吸附」把它拉直。
    private func holdLine(_ a: (Double, Double), _ b: (Double, Double)) {
        at(a.0, a.1).press(forDuration: 0.1, thenDragTo: at(b.0, b.1), withVelocity: .slow, thenHoldForDuration: 0.8)
    }

    /// 手把手教學章節的截圖：新增套件 → 製圖列 → 第一條線 → 隱藏線與圖層 → 三視圖 → 標註 → 圖框。
    func testTakeTheGuideShots() throws {
        app = XCUIApplication()
        app.launchEnvironment["KAIRUMO_UITEST"] = "1"
        app.launchEnvironment["KAIRUMO_UITEST_LANGUAGE"] = lang
        app.launch()
        XCTAssertTrue(element("home.action.new_note").waitForExistence(timeout: 20))
        element("home.action.new_note").tap()
        XCTAssertTrue(element("new_notebook.confirm").waitForExistence(timeout: 10))
        _ = reveal("new_notebook.kit.drafting")
        shot("guide_kit")
        element("new_notebook.confirm").tap()
        XCTAssertTrue(element("editor.canvas").waitForExistence(timeout: 20))
        enterDrafting()
        shot("guide_bar")
        shot("drafting")

        element("draft.pen.thick").tap()
        holdLine((0.15, 0.58), (0.55, 0.59))
        holdLine((0.62, 0.50), (0.63, 0.72))
        shot("guide_snap")

        element("draft.pen.hidden").tap()
        holdLine((0.15, 0.68), (0.55, 0.69))
        element("draft.layer.2.visible").tap()
        shot("guide_hidden")
        element("draft.layer.2.visible").tap()

        element("draft.solidStudio").tap()
        XCTAssertTrue(element("solid.insert").waitForExistence(timeout: 10))
        element("solid.insert").tap()
        XCTAssertTrue(element("editor.canvas").waitForExistence(timeout: 10))
        sleep(1)
        enterDrafting()
        shot("guide_inserted")

        openToolbox()
        element("draft.tool.dimLinear").tap()
        sleep(1)
        at(0.134, 0.435).tap()
        at(0.41, 0.435).tap()
        at(0.27, 0.40).press(forDuration: 0.2, thenDragTo: at(0.27, 0.36))
        sleep(1)
        shot("guide_dim")

        openToolbox()
        // 往下捲到「圖框與標題欄」那一組（跟 reveal 一樣整個畫面往上滑）。
        app.swipeUp()
        shot("guide_frame")
    }
}
