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

    /// 驗證手繪工具鍵操作與文字模式下點擊方格打字
    func testDrawingToolsAndTypeModeGridTap() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        let card = app.staticTexts["Welcome to Kairumo"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        sleep(2)
        assertAlive(app, "進入筆記編輯器")

        let canvas = app.descendants(matching: .any)["kairumo.canvas"].firstMatch
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
        XCTAssertTrue(app.descendants(matching: .any)["kairumo.canvas"].waitForExistence(timeout: 15), "找不到畫布")
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

        let canvas = app.descendants(matching: .any).matching(identifier: "kairumo.canvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 15), "點了卡片之後沒進到編輯器")

        ScreenAudit.check(app, screen: "editor", allowMissing: Self.editorNotWiredYet)
    }

    /// 棘輪：還沒接上識別碼的控制項。**只准縮小**。
    ///
    /// 這裡放著的每一項都代表「規格說要有、實際上稽核找不到」。清空的辦法是
    /// 去把 `accessibilityIdentifier` 補上，不是把項目搬進來。
    static let homeNotWiredYet: Set<String> = [
        "home.identity.edit",
        "home.recordings.open_folder",
        "home.notebooks.sort",
        "home.notebooks.rename_root",
        "home.cloud.signin",
        "home.data.folder",
    ]
    /// 編輯器的棘輪。**大部分不是「沒接上」，是「藏在選單／浮層裡」** ——
    /// `insert.*` 在插入選單、`export.*` 在匯出選單、`text.*` 只有打字模式才有、
    /// `sidebar.*` 要先展開側欄。單一畫面狀態的稽核看不到它們。
    ///
    /// 正確的解是為每個選單各加一段稽核（開啟選單 → 稽核 → 關閉），
    /// 記在 docs/TODO.md 的 S-259。在那之前這些放在這裡，稽核仍然守住
    /// 編輯器基礎狀態的 28 個控制項。
    ///
    /// `editor.canvas` 是另一回事：識別碼寫在程式碼裡
    /// （NotebookEditorView.swift:3369），但實際渲染的是另一個分支的
    /// `kairumo.canvas` —— **識別碼掛在沒被顯示的那個視圖上**。
    /// 掃原始碼的閘門看不見這種，執行期稽核看得見。
    static let editorNotWiredYet: Set<String> = [
        "editor.insert.assets",
        "editor.insert.audio",
        "editor.insert.image",
        "editor.insert.math",
        "editor.insert.chart",
        "editor.insert.table",
        "editor.insert.shape",
        "editor.insert.model3d",
        "editor.insert.theme_tools",
        "editor.insert.refine_sketch",
        "editor.insert.comment_pin",
        "editor.insert.collaborate",
        "editor.insert.recognize",
        "editor.insert.ai_summary",
        "editor.export.pdf",
        "editor.export.image",
        "editor.export.print",
        "editor.export.share",
        "editor.text.add_box",
        "editor.text.studio",
        "editor.text.bold",
        "editor.text.italic",
        "editor.text.underline",
        "editor.text.align_left",
        "editor.text.align_center",
        "editor.text.align_right",
        "editor.text.snap_grid",
        "editor.text.layer_forward",
        "editor.text.layer_backward",
        "editor.text.symbols",
        "editor.text.select",
        "editor.text.link",
        "editor.text.undo",
        "editor.text.redo",
        "editor.sidebar.tab.pages",
        "editor.sidebar.tab.folders",
        "editor.sidebar.list",
        "editor.sidebar.thumb_smaller",
        "editor.sidebar.thumb_larger",
        "editor.canvas",
    ]
}
