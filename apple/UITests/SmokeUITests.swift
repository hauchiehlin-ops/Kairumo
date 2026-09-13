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

        let canvas = app.scrollViews["kairumo.canvas"].firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 8), "找不到畫布")
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
