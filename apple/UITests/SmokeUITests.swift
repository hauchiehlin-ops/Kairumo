import XCTest

/// 重現「操作筆記頁或筆記本就閃退」的冒煙測試。
/// 每一步都在 app 仍存活時才繼續，崩潰會讓後續查詢失敗並記錄在報告中。
final class SmokeUITests: XCTestCase {

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        // 這個變數以前**沒有任何人讀**，測試設了等於沒設。現在
        // LocalizationManager 會認它，把語言釘在英文。
        //
        // 為什麼重要：這些測試原本靠顯示文字定位
        // （`app.staticTexts["User Manual"]`），於是模擬器當下是什麼語言
        // 就決定測試成敗 —— 拍完中文截圖之後整套就全紅了，而那跟程式對不對
        // 一點關係都沒有。間歇失敗的測試會在第三次紅的時候被關掉。
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
        let canvas = app.descendants(matching: .any)["editor.canvas"].firstMatch
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

    /// 驗證手繪工具鍵操作與文字模式下點擊方格打字
    func testDrawingToolsAndTypeModeGridTap() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        let card = app.staticTexts["Welcome to Kairumo"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        sleep(2)
        assertAlive(app, "進入筆記編輯器")

        let canvas = app.descendants(matching: .any)["editor.canvas"].firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 10), "找不到畫布")

        // 1. 測試各手繪工具鍵點擊響應
        let penTool = app.descendants(matching: .any)["editor.tool.pen"].firstMatch
        if penTool.waitForExistence(timeout: 5) {
            penTool.tap()
            assertAlive(app, "點選鋼筆工具")
        }

        let highlighterTool = app.descendants(matching: .any)["editor.tool.highlighter"].firstMatch
        if highlighterTool.exists {
            highlighterTool.tap()
            assertAlive(app, "點選螢光筆工具")
        }

        let eraserTool = app.descendants(matching: .any)["editor.tool.eraser"].firstMatch
        if eraserTool.exists {
            eraserTool.tap()
            assertAlive(app, "點選橡皮擦工具")
        }

        let lassoTool = app.descendants(matching: .any)["editor.tool.lasso"].firstMatch
        if lassoTool.exists {
            lassoTool.tap()
            assertAlive(app, "點選套索工具")
        }

        // 2. 切換至文字模式
        let modeSwitch = app.descendants(matching: .any)["editor.mode"].firstMatch
        if modeSwitch.waitForExistence(timeout: 5) {
            modeSwitch.tap()
            sleep(1)
            assertAlive(app, "切換模式")
        }

        // 3. 在畫布方格區域點擊
        let coordinate = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        coordinate.tap()
        sleep(1)
        assertAlive(app, "點擊畫布方格區域建立文字方塊")

        // 4. 回首頁
        let home = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'home' OR label CONTAINS[c] 'house'")).firstMatch
        if home.exists {
            home.tap()
            sleep(2)
            assertAlive(app, "回首頁")
        }
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
    private let outputDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("kairumo-mac-asc-raw")

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
        let window = app.windows.firstMatch
        let screenshot = window.exists ? window.screenshot() : app.screenshot()
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

        let record = app.descendants(matching: .any)["home.action.record"].firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 10), "找不到首頁錄音按鈕")
        record.tap()
        try capture("02-recording.png", app: app)
        app.typeKey(.escape, modifierFlags: [])
        sleep(1)

        let assets = app.descendants(matching: .any)["home.action.assets"].firstMatch
        XCTAssertTrue(assets.waitForExistence(timeout: 10), "找不到首頁素材圖庫按鈕")
        assets.tap()
        try capture("03-assets.png", app: app)
        app.typeKey(.escape, modifierFlags: [])
        sleep(1)

        let welcome = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Kairumo'")).firstMatch
        XCTAssertTrue(welcome.waitForExistence(timeout: 10), "找不到範例筆記卡片")
        welcome.tap()
        XCTAssertTrue(app.descendants(matching: .any)["editor.canvas"].waitForExistence(timeout: 15), "找不到畫布")
        try capture("04-editor-pen.png", app: app)

        let typeMode = app.staticTexts["打字模式"].firstMatch
        XCTAssertTrue(typeMode.waitForExistence(timeout: 8), "找不到打字模式切換")
        typeMode.tap()
        try capture("05-editor-typing.png", app: app)

    }
}

// MARK: - 畫面稽核（提案 ①）

extension SmokeUITests {

    /// 首頁：規格要求的控制項要在、而且點得到。
    ///
    /// 這條測試守的是「畫得出來卻點不到」—— 討論串面板與圖釘放置層都
    /// 栽在這上面，兩次都是盯著截圖才發現的。詳見 `ScreenAudit`。
    func testHomeScreenControlsAreReachable() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        ScreenAudit.check(app, screen: "home", allowMissing: Self.homeNotWiredYet)
    }

    /// 編輯器：同上。
    func testEditorScreenControlsAreReachable() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        // 種子筆記的標題。語言已經被 KAIRUMO_UITEST 釘在英文，所以這是確定的。
        //
        // 比較好的做法是給每張卡片一個識別碼（`home.notebooks.card.<id>`），
        // 那樣連語言都不必釘。目前卡片沒有 —— 只有整個清單有
        // `home.notebooks.list`。記在 docs/TODO.md 的 S-259。
        let card = app.staticTexts["Welcome to Kairumo"].firstMatch
        guard card.waitForExistence(timeout: 10) else {
            XCTFail("首頁找不到種子筆記，開不了編輯器")
            return
        }
        card.tap()

        let canvas = app.descendants(matching: .any).matching(identifier: "editor.canvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 15), "點了卡片之後沒進到編輯器")

        // 不是 `always` 的都不該在這一掃裡 —— 它們各自由會先互動的那幾條
        // 測試檢查。這份名單來自核心規格，不是手抄的（S-SPEC-MENUS）。
        ScreenAudit.check(
            app, screen: "editor",
            allowMissing: ScreenAudit.notAlwaysVisible(screen: "editor"))
    }

    /// 「更多」選單裡的十六個項目：打開之後要在、而且點得到。
    ///
    /// # 這條測試補的是 S-261d
    ///
    /// 在此之前，`editor.insert.*` 那一整批只有靜態對照閘門在守 ——
    /// 它掃的是原始碼裡有沒有寫出那個識別碼，所以「按鈕在、但按下去沒反應」
    /// 或「按鈕被蓋住點不到」它一律看不見。
    ///
    /// 沒有人寫這條測試的原因是：用識別碼找不到選單項目。實測
    /// （`MenuProbe`）查出真正的原因 —— SwiftUI 的 `Menu` 把項目交給 UIKit
    /// 的 `UIAction` 算繪，`.accessibilityIdentifier` 不會跟過去，
    /// 但**標籤會**。所以 `ScreenAudit` 現在找不到識別碼時會改用標籤找，
    /// 標籤同樣來自核心的字串表。
    func testMoreMenuItemsAreReachable() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        let card = app.staticTexts["Welcome to Kairumo"].firstMatch
        guard card.waitForExistence(timeout: 10) else {
            XCTFail("首頁找不到種子筆記，開不了編輯器")
            return
        }
        card.tap()

        let more = app.descendants(matching: .any).matching(identifier: "editor.more").firstMatch
        guard more.waitForExistence(timeout: 15) else {
            XCTFail("編輯器上沒有「更多」選單")
            return
        }
        more.tap()

        // 選單有展開動畫。太早掃會掃到一半，而**間歇失敗的閘門會被關掉**。
        let firstItem = app.buttons["Asset Library"].firstMatch
        XCTAssertTrue(firstItem.waitForExistence(timeout: 5), "「更多」選單沒有打開")

        // `requireHittable: false` —— 理由見 `ScreenAudit.checkOnly`。
        // 簡單說：選單的版面是 UIKit 排的，遮蔽這個 bug 類型在那裡不會發生，
        // 而底下幾項落在選單自己的捲動範圍外，點不到是正常的。
        ScreenAudit.checkOnly(
            app, screen: "editor",
            ids: ScreenAudit.controlIds(screen: "editor", revealedBy: "more_menu"),
            requireHittable: false, scrollToFind: true)
    }

    /// 匯出選單裡的四個項目：打開之後要在、而且是啟用的。
    ///
    /// 與 `testMoreMenuItemsAreReachable` 同一個做法、同一個理由（S-261d）。
    /// 分成兩條而不是合併成一條：兩張選單不能同時打開，而一條測試裡開關
    /// 兩次選單，失敗時分不出是哪一張沒開起來。
    func testExportMenuItemsAreReachable() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        let card = app.staticTexts["Welcome to Kairumo"].firstMatch
        guard card.waitForExistence(timeout: 10) else {
            XCTFail("首頁找不到種子筆記，開不了編輯器")
            return
        }
        card.tap()

        let share = app.descendants(matching: .any).matching(identifier: "editor.share").firstMatch
        guard share.waitForExistence(timeout: 15) else {
            XCTFail("編輯器上沒有匯出選單")
            return
        }
        share.tap()

        // 選單有展開動畫。太早掃會掃到一半，而**間歇失敗的閘門會被關掉**。
        let firstItem = app.buttons["Export PDF"].firstMatch
        XCTAssertTrue(firstItem.waitForExistence(timeout: 5), "匯出選單沒有打開")

        ScreenAudit.checkOnly(
            app, screen: "editor",
            ids: ScreenAudit.controlIds(screen: "editor", revealedBy: "export_menu"),
            requireHittable: false, scrollToFind: true)
    }
    /// **畫一筆、離開、回來 —— 那一筆還在嗎？**
    ///
    /// # 為什麼這條測試以前不存在
    ///
    /// 使用者一再回報「筆跡沒有自動儲存」，而每次查程式碼每一項都是對的：
    /// `recordDrawingEdit` 有存、`onDisappear` 有存、`scenePhase` 進背景
    /// 也有存。於是每一次都「修好了」，然後下一次又壞。
    ///
    /// 原因是**沒有任何東西守著它**：`testDrawingToolsAndTypeModeGridTap`
    /// 只點了工具再點一下畫布，不檢查任何東西留下來。一個沒有測試守著的
    /// 修正，等於一個還沒發生的回歸。
    ///
    /// 筆畫數從畫布的 `accessibilityValue` 讀（只在 `KAIRUMO_UITEST` 下掛）
    /// —— 與縮放倍率同一個做法、同一個理由。
    func testInkSurvivesLeavingAndReopeningTheNotebook() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        let card = app.staticTexts["Welcome to Kairumo"].firstMatch
        guard card.waitForExistence(timeout: 10) else {
            XCTFail("首頁找不到種子筆記，開不了編輯器")
            return
        }
        card.tap()

        let canvas = app.descendants(matching: .any)["editor.canvas"].firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 15), "找不到畫布")

        let before = Self.strokeCount(canvas)

        // 畫一筆。
        //
        // **PencilKit 對合成觸控很挑**：`tap()` 與快速的 `press+drag` 都
        // 產生不出筆畫（實測讀數一直是 strokes:0）。要壓住、慢慢拖、再停住
        // 一下才會被當成一筆。
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.45))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.55))
        start.press(
            forDuration: 0.4,
            thenDragTo: end,
            withVelocity: .slow,
            thenHoldForDuration: 0.4)

        // 去抖動是 1.2 秒，落盤再給一點餘裕。
        sleep(3)

        let afterDraw = Self.strokeCount(canvas)
        XCTAssertGreaterThan(
            afterDraw, before,
            "拖曳之後畫布上沒有多出筆畫 —— 這條測試的前提就不成立了")

        // 回首頁再進來。**這就是使用者做的事。**
        let home = app.descendants(matching: .any).matching(identifier: "editor.home").firstMatch
        guard home.waitForExistence(timeout: 10) else {
            XCTFail("編輯器上沒有回首頁的按鈕")
            return
        }
        home.tap()

        let cardAgain = app.staticTexts["Welcome to Kairumo"].firstMatch
        XCTAssertTrue(cardAgain.waitForExistence(timeout: 15), "回不到首頁")
        cardAgain.tap()

        let canvasAgain = app.descendants(matching: .any)["editor.canvas"].firstMatch
        XCTAssertTrue(canvasAgain.waitForExistence(timeout: 15), "重新開啟之後找不到畫布")
        sleep(2)

        XCTAssertGreaterThanOrEqual(
            Self.strokeCount(canvasAgain), afterDraw,
            "**筆跡沒有留下來。** 離開前畫布上有 \(afterDraw) 筆，"
                + "重新開啟之後剩 \(Self.strokeCount(canvasAgain)) 筆。")
    }

    /// 只畫一筆然後停住 —— **不離開編輯器**。
    ///
    /// 把「畫得進去嗎」「存得下去嗎」「離開再回來還在嗎」三件事拆開。
    /// 合在一條裡的話，紅燈只說得出「最後沒了」，說不出是哪一段掉的。
    func testInkProbeDrawOnly() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        let card = app.staticTexts["Welcome to Kairumo"].firstMatch
        guard card.waitForExistence(timeout: 10) else { XCTFail("找不到種子筆記"); return }
        card.tap()

        let canvas = app.descendants(matching: .any)["editor.canvas"].firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 15), "找不到畫布")

        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.45))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.55))
        start.press(forDuration: 0.4, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.4)
        sleep(4)

        XCTAssertGreaterThan(Self.strokeCount(canvas), 0, "畫不進去")
    }

    /// 畫一筆 → 回首頁 → **停在首頁**。
    ///
    /// 與 `testInkProbeDrawOnly` 合起來夾出「是離開時掉的，還是重新開啟時
    /// 掉的」。檔案內容由外面的腳本檢查 —— 測試本身只負責把 App 開到那個
    /// 狀態。
    func testInkProbeDrawThenLeave() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        let card = app.staticTexts["Welcome to Kairumo"].firstMatch
        guard card.waitForExistence(timeout: 10) else { XCTFail("找不到種子筆記"); return }
        card.tap()

        let canvas = app.descendants(matching: .any)["editor.canvas"].firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 15), "找不到畫布")

        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.45))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.55))
        start.press(forDuration: 0.4, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.4)
        sleep(4)
        XCTAssertGreaterThan(Self.strokeCount(canvas), 0, "畫不進去")

        let home = app.descendants(matching: .any).matching(identifier: "editor.home").firstMatch
        guard home.waitForExistence(timeout: 10) else { XCTFail("沒有回首頁的按鈕"); return }
        home.tap()
        XCTAssertTrue(
            app.staticTexts["Welcome to Kairumo"].firstMatch.waitForExistence(timeout: 15),
            "回不到首頁")
        sleep(3)
    }

    /// 從畫布的測試讀數裡取筆畫數。讀不到回 -1（與 0 分得開 ——
    /// 0 是「畫布上沒有筆畫」，-1 是「讀數根本沒掛上去」）。
    static func strokeCount(_ canvas: XCUIElement) -> Int {
        guard let value = canvas.value as? String,
              let range = value.range(of: "strokes:")
        else { return -1 }
        return Int(value[range.upperBound...].prefix(while: \.isNumber)) ?? -1
    }

    /// 打字模式那一套工具列。
    ///
    /// # 這條測試查出了什麼
    ///
    /// 第一次跑的時候，規格要求的十六個 `editor.text.*` 只找得到三個 ——
    /// 而原因不是識別碼沒掛，是**掛在一份沒有人算繪的程式碼上**：
    /// `typingToolbar` 帶著全部十六個識別碼，但全專案沒有任何地方引用它，
    /// 真正畫出來的是 `WordToolbarView`（一個文書處理工具列，
    /// 一個識別碼都沒有）。
    ///
    /// **靜態的跨平台對照閘門一直是綠的**，因為它掃的是原始碼裡有沒有那個
    /// 字串 —— 而那些字串就在死程式碼裡。這正是執行期稽核存在的理由，
    /// 也正是把這一整批藏在棘輪裡的代價：那時候的註解寫的是「藏在選單／
    /// 浮層裡，單一畫面狀態看不到」，對了一半，於是沒有人再往下查。
    ///
    /// 要檢查哪幾個來自核心規格（`reveal == typing_mode`），不是這裡手抄的
    /// 清單。
    func testTypingModeItemsAreReachable() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        let card = app.staticTexts["Welcome to Kairumo"].firstMatch
        guard card.waitForExistence(timeout: 10) else {
            XCTFail("首頁找不到種子筆記，開不了編輯器")
            return
        }
        card.tap()

        // `portal.type` 是 `DynamicPortalIsland` 裡那顆藥丸，而整座島掛著
        // `editor.mode` —— 先等島出現再找藥丸。
        let island = app.descendants(matching: .any)
            .matching(identifier: "editor.mode").firstMatch
        XCTAssertTrue(island.waitForExistence(timeout: 15), "編輯器上沒有模式切換")

        let type = app.descendants(matching: .any).matching(identifier: "portal.type").firstMatch
        guard type.waitForExistence(timeout: 10) else {
            XCTFail("找不到 portal.type —— 模式切換的子元素被合併掉了？")
            return
        }
        type.tap()

        ScreenAudit.checkOnly(
            app, screen: "editor",
            ids: ScreenAudit.controlIds(screen: "editor", revealedBy: "typing_mode"),
            requireHittable: false, scrollToFind: true)
    }

    /// 側欄展開之後才看得到的那幾項。
    func testSidebarItemsAreReachable() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        let card = app.staticTexts["Welcome to Kairumo"].firstMatch
        guard card.waitForExistence(timeout: 10) else {
            XCTFail("首頁找不到種子筆記，開不了編輯器")
            return
        }
        card.tap()

        let toggle = app.descendants(matching: .any)
            .matching(identifier: "editor.sidebar_toggle").firstMatch
        guard toggle.waitForExistence(timeout: 15) else {
            XCTFail("編輯器上沒有側欄開關")
            return
        }
        toggle.tap()

        // **側欄預設開在「資料夾」分頁**（`kairumo_editor_sidebar_tab`
        // 的預設值是 `folders`），而縮圖大小那兩顆住在「頁面」分頁的底部。
        // 不先切過去的話，它們根本沒被算繪 —— 稽核會報「少了控制項」，
        // 而那不是產品缺了東西，是測試沒走到那個狀態。
        let pagesTab = app.descendants(matching: .any)
            .matching(identifier: "editor.sidebar.tab.pages").firstMatch
        if pagesTab.waitForExistence(timeout: 5) {
            pagesTab.tap()
        }

        ScreenAudit.checkOnly(
            app, screen: "editor",
            ids: ScreenAudit.controlIds(screen: "editor", revealedBy: "sidebar"),
            requireHittable: false, scrollToFind: true)
    }




    /// 自訂工具列：十三個開關加上說明與還原，全部要在、而且點得到。
    ///
    /// 入口在「更多」選單裡，而 SwiftUI 的 `Menu` 內容**不會出現在
    /// XCUITest 的無障礙樹裡** —— 點開之後掃到的只有工具列那些控制項
    /// （實測過，失敗訊息裡列的二十個識別碼全是 `editor.*` 工具列的）。
    /// 所以這裡用啟動變數把表直接叫出來，驗的是**表本身**。
    ///
    /// 選單那顆入口因此沒有執行期測試守著，只有靜態的跨平台對照閘門
    /// （它掃得到 `editor.customize_toolbar` 這個字面值）。記在 S-261d。
    func testToolbarCustomizationControlsAreReachable() {
        let app = XCUIApplication()
        app.launchEnvironment["KAIRUMO_UITEST"] = "1"
        app.launchEnvironment["KAIRUMO_UITEST_TOOLBAR"] = "1"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        let card = app.staticTexts["Welcome to Kairumo"].firstMatch
        guard card.waitForExistence(timeout: 10) else {
            XCTFail("首頁找不到種子筆記，開不了編輯器")
            return
        }
        card.tap()

        let reset = app.descendants(matching: .any).matching(identifier: "toolbar.reset").firstMatch
        guard reset.waitForExistence(timeout: 15) else {
            XCTFail("自訂工具列沒有打開。現場有的："
                    + ScreenAudit.presentIdentifiers(app).joined(separator: ", "))
            return
        }

        ScreenAudit.check(app, screen: "toolbar", allowMissing: [])
    }

    /// 棘輪：還沒接上識別碼的控制項。**只准縮小**。
    ///
    /// 這裡放著的每一項都代表「規格說要有、實際上稽核找不到」。清空的辦法是
    /// 去把 `accessibilityIdentifier` 補上，不是把項目搬進來。
    /// 棘輪。**只准縮小。**
    ///
    /// 原本有 6 項，四個容器加上 `.accessibilityElement(children: .contain)`
    /// 之後剩這 2 項 —— 那個修正同時也是無障礙修正，見 HomeWorkbenchView
    /// 的說明。
    static let homeNotWiredYet: Set<String> = [
        // 空的。原本有 6 項，四個容器補上
        // `.accessibilityElement(children: .contain)` 之後剩 2 項（S-263），
        // 那兩項也在 2026-09-23 清掉了：
        //
        //   * home.recordings.open_folder —— 窄螢幕那個版面變體的按鈕
        //     **沒掛識別碼**，而 iPhone 上 ViewThatFits 選的就是它。
        //     兩個變體只接一邊的線。
        //   * home.data.folder —— Apple 首頁少了「選擇同步資料夾」那張卡，
        //     而 FolderSyncDetailSheet 早就做好、也接在 .sheet 上了，
        //     只是沒有任何地方打得開它。
    ]
}
