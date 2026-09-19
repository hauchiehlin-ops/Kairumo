import XCTest

/// 重現「操作筆記頁或筆記本就閃退」的冒煙測試。
/// 每一步都在 app 仍存活時才繼續，崩潰會讓後續查詢失敗並記錄在報告中。
final class SmokeUITests: XCTestCase {

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["KAIRUMO_UITEST"] = "1"
        app.launch()
        return app
    }

    private func assertAlive(_ app: XCUIApplication, _ step: String) {
        XCTAssertEqual(app.state, .runningForeground, "App 在這一步之後不在前景：\(step)")
    }

    func testOpenNotebookAndPageOperations() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        // 1. 從首頁開啟一則筆記
        let card = app.staticTexts["Welcome to Kairumo"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "找不到首頁筆記卡片")
        card.tap()
        sleep(2)
        assertAlive(app, "開啟筆記")

        // 2. 開啟筆記結構側欄
        let structure = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sidebar' OR label CONTAINS[c] 'Split View'")).firstMatch
        if structure.waitForExistence(timeout: 5) {
            structure.tap()
            sleep(2)
            assertAlive(app, "開啟結構側欄")
        }

        // 3. 新增頁面
        let addPage = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Add Page' OR label CONTAINS[c] 'Add Next Page'")).firstMatch
        if addPage.waitForExistence(timeout: 5) {
            addPage.tap()
            sleep(2)
            assertAlive(app, "新增頁面")
        }

        // 4. 延長本頁
        let extend = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Extend'")).firstMatch
        if extend.exists {
            extend.tap()
            sleep(2)
            assertAlive(app, "延長頁面")
        }

        // 5. 回首頁
        let home = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'home' OR label CONTAINS[c] 'house'")).firstMatch
        if home.exists {
            home.tap()
            sleep(2)
            assertAlive(app, "回首頁")
        }
    }

    func testNoteCardMenu() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        // 首頁筆記卡片上的「⋯」選單
        let menu = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'ellipsis' OR label CONTAINS[c] 'More'")).firstMatch
        if menu.waitForExistence(timeout: 8) {
            menu.tap()
            sleep(2)
            assertAlive(app, "開啟筆記卡片選單")
        }
    }

    /// 首頁的「說明與條款」入口：手冊與隱私權政策必須可以打開（離線內建）
    func testBundledDocumentsOpenFromHome() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        // 往下捲到說明文件區塊
        let manual = app.staticTexts["User Manual"].firstMatch
        var tries = 0
        while !manual.exists && tries < 8 {
            app.swipeUp()
            tries += 1
        }
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "首頁找不到「操作手冊」入口")
        manual.tap()
        sleep(3)
        assertAlive(app, "開啟操作手冊")

        // 文件彈窗的標題列應該出現「Done」
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 8), "手冊彈窗沒有出現")
        done.tap()
        sleep(1)

        let privacy = app.staticTexts["Privacy Policy"].firstMatch
        XCTAssertTrue(privacy.waitForExistence(timeout: 5), "首頁找不到「隱私權政策」入口")
        privacy.tap()
        sleep(3)
        assertAlive(app, "開啟隱私權政策")
    }

    /// 收合左側結構欄之後，畫布必須撐滿視窗寬度
    func testCanvasExpandsWhenSidebarCollapses() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        let card = app.staticTexts["Welcome to Kairumo"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        sleep(3)

        // **不指定型別。** 原本查的是 `scrollViews` —— 畫布確實是
        // `PKCanvasView`（UIScrollView 的子類），但整頁模式把它套上縮放
        // 之後，XCUITest 樹裡它就不再以 ScrollView 出現，測試於是說
        // 「找不到畫布」而畫面上明明有。識別字才是我們保證的東西。
        let canvas = app.descendants(matching: .any)["kairumo.canvas"].firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 8), "找不到畫布：\n\(app.debugDescription)")
        let windowWidth = app.windows.firstMatch.frame.width

        // 側欄可能預設展開（iPad）或收合（iPhone）—— 先確保它是收合的
        let structure = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'sidebar' OR label CONTAINS[c] 'Split View'")
        ).firstMatch
        XCTAssertTrue(structure.waitForExistence(timeout: 5), "找不到筆記結構按鈕")

        if canvas.frame.width < windowWidth * 0.8 {
            structure.tap()
            sleep(2)
        }

        let width = canvas.frame.width
        XCTAssertGreaterThan(
            width, windowWidth * 0.85,
            "側欄收合後畫布沒有撐滿：畫布 \(width) / 視窗 \(windowWidth)"
        )
        assertAlive(app, "收合側欄")
    }
}

extension SmokeUITests {

    /// 跨平台格式轉換：從 UI 真的按下去，確認它會跑完並回報結果。
    ///
    /// 單元測試證明的是遷移邏輯對；這一條證明的是**使用者按得到、按了有反應**。
    /// 之前踩過的坑就是「能力建好了卻沒開到使用者面前」，等於沒建。
    func testMigrationRunsFromTheDiagnosticsSheet() {
        let app = XCUIApplication()
        app.launchEnvironment["KAIRUMO_UITEST"] = "1"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        // 診斷頁的入口在首頁頁尾的版本號上（S-74 把頭像選單整個拿掉了 ——
        // 它底下四個項目在首頁都已經有自己的入口）。
        let diagnostics = app.buttons["home.diagnostics"]
        guard diagnostics.waitForExistence(timeout: 10) else {
            return XCTFail("首頁找不到診斷入口（頁尾的版本號）")
        }
        // 頁尾在畫面外，要先捲到底才點得到。
        if !diagnostics.isHittable {
            app.swipeUp()
            app.swipeUp()
        }
        diagnostics.tap()
        sleep(2)
        XCTAssertEqual(app.state, .runningForeground, "開啟診斷頁後 App 不在前景")

        let convert = app.buttons["migration.run"]
        guard convert.waitForExistence(timeout: 5) else {
            return XCTFail("診斷頁裡找不到轉換按鈕")
        }
        convert.tap()

        // 轉換完成後狀態列會從「尚未轉換」變成「已轉換 N 本」
        let converted = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'converted' OR label CONTAINS[c] '已轉換'")
        ).firstMatch
        XCTAssertTrue(converted.waitForExistence(timeout: 30), "轉換沒有回報完成")

        // 把結果畫面留在測試報告裡：出問題時「當時螢幕長怎樣」比任何敘述都有用。
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "migration-result"
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertEqual(app.state, .runningForeground, "轉換之後 App 不在前景")

        // 失敗的話畫面上會有紅字說明；這裡確認沒有任何一本失敗
        let failed = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'failed' OR label CONTAINS[c] '失敗'")
        ).firstMatch
        if failed.exists {
            XCTAssertTrue(failed.label.contains("0"), "有筆記轉換失敗：\(failed.label)")
        }
    }
}

final class AppStoreMacScreenshotsUITests: XCTestCase {
    private let outputDirectory = URL(fileURLWithPath: "/Users/barretlin/GitProjects/Padnote/asc-macos-screenshots/raw")

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        for item in try FileManager.default.contentsOfDirectory(at: outputDirectory, includingPropertiesForKeys: nil) where item.pathExtension == "png" {
            try? FileManager.default.removeItem(at: item)
        }
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["KAIRUMO_UITEST"] = "1"
        app.launchArguments += [
            "-AppleLanguages", "(zh-Hant)",
            "-AppleLocale", "zh_TW",
            "-kairumo.app.language", "zh-Hant",
            "-kairumo.onboarding.seen.v1", "YES"
        ]
        app.launch()
        return app
    }

    private func capture(_ name: String, app: XCUIApplication) throws {
        sleep(1)
        let screenshot = app.screenshot()
        let url = outputDirectory.appendingPathComponent(name)
        try screenshot.pngRepresentation.write(to: url, options: .atomic)

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCaptureFiveMainMacScreenshots() throws {
        let app = launchApp()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        try capture("01-home.png", app: app)

        let newNote = app.descendants(matching: .any)["home.action.new_note"].firstMatch
        XCTAssertTrue(newNote.waitForExistence(timeout: 10), "找不到首頁新增筆記按鈕")
        newNote.tap()
        XCTAssertTrue(app.textFields["new_notebook.title.field"].waitForExistence(timeout: 10), "新增筆記頁沒有出現")
        try capture("02-new-notebook.png", app: app)

        let confirm = app.descendants(matching: .any)["new_notebook.confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "找不到新增筆記確認按鈕")
        confirm.tap()
        XCTAssertTrue(app.descendants(matching: .any)["kairumo.canvas"].waitForExistence(timeout: 15), "找不到畫布")
        try capture("03-editor-pen.png", app: app)

        let typeMode = app.staticTexts["打字模式"].firstMatch
        XCTAssertTrue(typeMode.waitForExistence(timeout: 8), "找不到打字模式切換")
        typeMode.tap()
        try capture("04-editor-typing.png", app: app)

        let drawMode = app.staticTexts["手繪模式"].firstMatch
        XCTAssertTrue(drawMode.waitForExistence(timeout: 8), "找不到手寫模式切換")
        drawMode.tap()
        let brush = app.descendants(matching: .any)["editor.ink.brush"].firstMatch
        XCTAssertTrue(brush.waitForExistence(timeout: 8), "找不到毛筆工具")
        brush.tap()
        try capture("05-editor-brush.png", app: app)
    }
}
