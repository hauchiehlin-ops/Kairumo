//
//  InsertToolsAudit.swift
//  KairumoUITests
//
//  「插入」選單裡的每一個工具：打得開、視窗裝得下、按得到。
//
//  # 為什麼不是靠看截圖
//
//  使用者的要求是「務必讓使用者在操作上沒有看不到、點不到的情況」。
//  那兩件事**截圖最容易漏掉** —— 一個被螢幕邊緣切掉一半的確認鈕，
//  在截圖上看起來完全正常，直到有人真的去按它。
//
//  所以這裡量的是座標：每一張表打開之後，它的主要按鈕在不在視窗裡、
//  是不是完整的、點不點得到。
//
//  # 為什麼要跑三種尺寸
//
//  響應式的 bug 只在特定寬度出現。實測過的例子：「更多」選單最下面四項
//  在 iPhone 17 Pro 上被視窗下緣切掉，而在 18 Pro 上完全正常（S-261d）。
//  本機測一種尺寸、CI 測另一種，就會得到「本機全綠、CI 莫名其妙紅」。
//

import XCTest

final class InsertToolsAudit: XCTestCase {

    /// 「插入」選單裡每一個項目，以及打開之後畫面上必須出現的那個識別碼。
    ///
    /// 沒有識別碼可以認的就用標籤 —— 選單項目本身的識別碼進不了無障礙樹
    /// （SwiftUI 的 `Menu` 交給 UIKit 的 `UIAction` 算繪，見 S-261d）。
    /// 標籤寫的是英文，因為測試把語言釘在英文（`KAIRUMO_UITEST`）。
    ///
    /// 選單項目**只能用標籤找** —— SwiftUI 的 `Menu` 把項目交給 UIKit 的
    /// `UIAction` 算繪，`.accessibilityIdentifier` 不會跟過去（S-261d）。
    /// 所以這裡的字串必須與 `i18n/ui-strings.json` 的英文逐字相同；
    /// 對不上的症狀就是「選單裡找不到」，而那看起來像功能壞了。
    private static let tools: [(menuLabel: String, opened: String)] = [
        ("Asset Library", "assets.close"),
        ("Sticker Library", "stickers.cancel"),
        ("Insert Image", ""),          // 系統相片選擇器，不是我們的畫面
        ("Choose from Files", ""),     // 系統檔案挑選器，同上
        ("Import an audio file", ""),  // 系統檔案挑選器，同上
        ("Math Calculator", "math.close"),
        ("Chart Studio", "chart.close"),
        ("Insert 3D Model", "model3d.import"),
        // 這一項原本接錯：主選單呼叫的是 `insertDefaultShape()`，在
        // (200, 200) 默默塞一個矩形就結束，工作室從來沒被打開過 ——
        // 使用者回報的「點了沒反應」就是它。現在這條測試守著。
        ("Shapes & Flowcharts", "shape.cancel"),
        ("Theme Tools", "theme.close"),
    ]

    /// 插進畫布的 3D 模型**搬得動、也改得了大小**。
    ///
    /// # 為什麼要有這條
    ///
    /// 使用者回報「插入 3D 模型後，畫布上的物件無法移動、改變大小」。
    /// 查下去兩件事都是真的：
    ///
    ///   * **縮放根本沒有** —— 圖片、表格、圖表都有角落把手，只有 3D 卡片
    ///     沒有，卡片寬度寫死在 `.frame(width:)` 裡。
    ///   * 移動做得到，但唯一的入口是卡片頂端那條細手把；拖模型本體會被
    ///     旋轉手勢吃掉，所以直覺去拖就是拖不動。
    ///
    /// 這條守的是縮放把手真的在畫布上（那是補出來的那一半）。
    func testInsertedModelHasAResizeHandle() {
        let app = launch()
        guard openEditor(app) else {
            XCTFail("進不到編輯器")
            return
        }

        element(app, "editor.more").tap()
        let item = app.buttons["Insert 3D Model"].firstMatch
        _ = item.waitForExistence(timeout: 3)
        // **要 `isHittable`，不是 `exists`。** 露出一角的按鈕 `exists` 是 true，
        // 但 XCUITest 點的是元素中心 —— 中心在畫面外，點了等於沒點，
        // 而且**不會報錯**，測試要到很後面才以一個不相干的斷言失敗。
        // （這一輪就是這樣：CI 說「模型上沒有縮放把手」，真因是模型根本
        // 沒插進去，因為「插入畫布」在摺線下面。）
        for _ in 0..<6 where !item.isHittable { app.swipeUp() }
        guard item.isHittable else {
            XCTFail("「更多」選單裡的 Insert 3D Model 點不到")
            return
        }
        item.tap()

        // 「插入畫布」在面板底部，手機尺寸上要捲才看得到。
        // CI 的機器比本機慢，面板動畫與 SceneKit 第一次建場景都要時間 ——
        // 逾時抓太緊的話，紅燈說的是「找不到」，實際是「還沒到」。
        // **先確定面板真的開了，再捲。**
        //
        // 原本是「找不到就先滑八下」。面板開得比較慢的時候，那八下滑的是
        // **編輯器**：乾淨安裝預設連續捲動，每滑到底就自動補一頁
        // （`onReachedPageBottom`），焦點頁跟著一路往下跑。等面板終於開了、
        // 模型插進去，它落在二十幾頁之外 —— 卡片不在畫面上，把手當然找不到。
        //
        // CI 的紅燈長這樣：現場識別碼裡二十六個 `editor.canvas`、一個
        // `model3d.*` 都沒有。訊息說「模型上沒有縮放把手」，真因是
        // **模型插到別頁去了**。
        // 面板開了沒有，要用**一定畫得出來**的東西判斷。`model3d.insert`
        // 在 Form 底部的 Section 裡，而 SwiftUI 的 Form 不會算繪畫面外的列
        // —— 沒捲到它之前 `exists` 就是 false，拿它當「面板開了沒」會冤枉
        // 面板。`model3d.close` 在工具列上，永遠在。
        guard element(app, "model3d.close").waitForExistence(timeout: 25) else {
            XCTFail("點了 Insert 3D Model，3D 工作室沒打開")
            return
        }
        // **要捲在面板裡面。**
        //
        // `resizableSheet` 用的是 `[.medium, .large]`，預設只佔下半個螢幕。
        // `app.swipeUp()` 從整個 app 的中心滑 —— 那個點在面板**上面**，
        // 滑到的是編輯器：連續捲動模式每滑到底就自動補一頁，焦點頁一路往下，
        // 模型最後插到二十幾頁之外。（CI 的紅燈裡二十六個 `editor.canvas`
        // 就是這麼來的。）
        //
        // 所以用面板裡的 `model3d.close` 當錨點，往它上方拖。
        let close = element(app, "model3d.close")
        let insert = element(app, "model3d.insert")
        for _ in 0..<8 where !insert.isHittable {
            close.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 12))
                .press(
                    forDuration: 0.05,
                    thenDragTo: close.coordinate(
                        withNormalizedOffset: CGVector(dx: 0.5, dy: 3)))
            _ = insert.waitForExistence(timeout: 1)
        }
        guard insert.isHittable else {
            XCTFail(
                "3D 工作室裡的「插入畫布」點不到。現場的識別碼："
                    + liveIdentifiers(app).joined(separator: ", "))
            return
        }
        insert.tap()

        let handle = element(app, "model3d.resize")
        XCTAssertTrue(
            handle.waitForExistence(timeout: 15),
            "插進畫布的 3D 模型上沒有縮放把手 —— 使用者改不了它的大小。\n"
                + describeModel3d(app))
    }

    /// 錄音啟動失敗的時候，**畫面上要說一聲**。
    ///
    /// # 為什麼要能從外面把它弄壞
    ///
    /// `startRecording` 有三處會靜靜地回 false（權限被拒、開不了套件、
    /// 擷取啟動失敗），而按鈕原本是 `_ = await ...` —— 回傳值直接丟掉，
    /// 失敗時畫面上什麼都不會發生。使用者回報的就是「錄音鈕沒反應」。
    ///
    /// 這種「失敗路徑」不製造一次失敗是驗不到的，所以用啟動環境變數
    /// 強制它失敗。沒有這條測試的話，下一次有人把 `showCanvasNotice`
    /// 那一行刪掉，不會有任何東西變紅。
    func testRecordingFailureTellsTheUser() {
        let app = XCUIApplication()
        app.launchEnvironment["KAIRUMO_UITEST"] = "1"
        app.launchEnvironment["KAIRUMO_UITEST_FAIL_RECORDING"] = "1"
        app.launch()
        guard openEditor(app) else {
            XCTFail("進不到編輯器")
            return
        }

        element(app, "editor.record").tap()

        XCTAssertTrue(
            element(app, "editor.notice").waitForExistence(timeout: 6),
            "錄音啟動失敗了，畫面上卻什麼都沒說 —— 那就是「按了沒反應」。\n"
                + "現場的識別碼："
                + app.descendants(matching: .any).allElementsBoundByIndex
                    .prefix(50).map { $0.identifier }.filter { !$0.isEmpty }
                    .joined(separator: ", ")
                + "\n靜態文字："
                + app.staticTexts.allElementsBoundByIndex
                    .prefix(20).map { $0.label }.joined(separator: " | "))
    }

    /// 拿不到畫布的時候，貼紙要說一聲。
    ///
    /// 貼紙是貼成**筆跡**的（所以可以擦、可以套索搬走），那需要畫布在場。
    /// 原本是 `guard let canvas = canvasView else { return }` ——
    /// 使用者挑了一張貼紙、面板關上、畫布上什麼也沒有，沒有任何線索。
    func testStickerWithoutCanvasTellsTheUser() {
        let app = XCUIApplication()
        app.launchEnvironment["KAIRUMO_UITEST"] = "1"
        app.launchEnvironment["KAIRUMO_UITEST_NO_CANVAS"] = "1"
        app.launch()
        guard openEditor(app) else {
            XCTFail("進不到編輯器")
            return
        }

        element(app, "editor.more").tap()
        let item = app.buttons["Sticker Library"].firstMatch
        _ = item.waitForExistence(timeout: 3)
        // 點得到才算數：只露一角的項目 `exists` 是 true，但點擊落在畫面外
        // —— 不報錯，卻什麼也沒發生。
        for _ in 0..<6 where !item.isHittable { app.swipeUp() }
        guard item.isHittable else {
            XCTFail("「更多」選單裡的貼紙庫點不到")
            return
        }
        item.tap()

        // 挑第一張貼紙。內建那些的識別碼都是 `stickers.item`。
        let sticker = app.descendants(matching: .any)
            .matching(identifier: "stickers.item").firstMatch
        guard sticker.waitForExistence(timeout: 8) else {
            XCTFail("貼紙庫裡一張貼紙都沒有")
            return
        }
        sticker.tap()

        XCTAssertTrue(
            element(app, "editor.notice").waitForExistence(timeout: 6),
            "貼紙插不進去，畫面上卻什麼都沒說。\n現場的識別碼："
                + app.descendants(matching: .any).allElementsBoundByIndex
                    .prefix(50).map { $0.identifier }.filter { !$0.isEmpty }
                    .joined(separator: ", ")
                + "\n靜態文字："
                + app.staticTexts.allElementsBoundByIndex
                    .prefix(20).map { $0.label }.joined(separator: " | "))
    }

    /// 依識別碼找元素，**不掃整棵樹**。
    ///
    /// `descendants(matching: .any)` 會走完整棵無障礙樹，而這個 App 的樹
    /// 有好幾百個節點。在迴圈裡反覆這樣查的後果不只是慢 ——
    /// XCTest 每一次查詢都會發 signpost，量大到一個程度之後系統的
    /// log 子系統會把這個行程**隔離**（`LIBTRACE_CLIENT_QUARANTINED_DUE_TO_
    /// HIGH_LOGGING_VOLUME`），接著 XCTest 自己的 fault callback 會在
    /// strcmp(NULL) 上炸掉。實測過：iPad 上跑到第 40 秒左右 SIGSEGV。
    ///
    /// 按型別查只走那一類元素，量差一個數量級。按鈕優先 ——
    /// 我們掛識別碼的東西絕大多數是按鈕。
    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        let button = app.buttons[id]
        if button.exists { return button }
        let other = app.otherElements[id]
        if other.exists { return other }
        // 兩種都沒有才回退 —— 回退本身很貴，但只在真的找不到時發生一次。
        return app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["KAIRUMO_UITEST"] = "1"
        app.launch()
        return app
    }

    /// 關掉目前這張表，回到編輯器。
    ///
    /// 優先找每張表都有的取消／關閉鍵；找不到才用下滑手勢 ——
    /// 下滑在 `.presentationDetents` 的表單上不一定有效，而且會滑到
    /// 底下的畫布上（那會畫出一筆）。
    private func dismissSheet(_ app: XCUIApplication) {
        for id in ["assets.close", "stickers.cancel", "math.close", "shape.cancel",
                   "chart.close", "theme.close", "model3d.close"] {
            let button = element(app, id)
            if button.exists && button.isHittable {
                button.tap()
                return
            }
        }
        app.swipeDown()
    }

    private func openEditor(_ app: XCUIApplication) -> Bool {
        guard app.wait(for: .runningForeground, timeout: 15) else { return false }
        guard openSeedNotebook(app) else { return false }
        return element(app, "editor.more").waitForExistence(timeout: 15)
    }

    /// 每一張插入面板打開之後，畫面上要真的出現它的內容。
    ///
    /// 這一條抓的是「選單點了沒反應」—— 而那正是使用者回報的那一類。
    func testEveryInsertToolOpensSomething() {
        let app = launch()
        guard openEditor(app) else {
            XCTFail("進不到編輯器")
            return
        }

        var failures: [String] = []
        for tool in Self.tools where !tool.opened.isEmpty {
            let more = element(app, "editor.more")
            more.tap()

            // **一定要捲。** 這張選單有十九個項目，在手機上會捲動，
            // 而每開關一張表之後捲動位置都不一樣 —— 不捲的話同一條測試
            // 第一次過、第二次紅，而**間歇失敗的閘門會被關掉**。
            let item = app.buttons[tool.menuLabel].firstMatch
            _ = item.waitForExistence(timeout: 3)
                // 點得到才算數：只露一角的項目 `exists` 是 true，
                // 但點擊落在畫面外 —— 不報錯，卻什麼也沒發生。
            for _ in 0..<6 where !item.isHittable { app.swipeUp() }
            guard item.isHittable else {
                failures.append("\(tool.menuLabel)：選單裡點不到")
                // 關掉選單再試下一個 —— 開著的選單會擋住下一次點擊。
                app.tap()
                continue
            }
            item.tap()

            let opened = app.descendants(matching: .any)
                .matching(identifier: tool.opened).firstMatch
            if !opened.waitForExistence(timeout: 6) {
                failures.append("\(tool.menuLabel)：打開之後找不到 \(tool.opened)")
            }

            // **關閉一律用同一個動作，不要去點那個標記。**
            //
            // 第一版是「點 opened 那個元素來關掉它」，而 3D 那一項的標記
            // 是「從檔案選擇」—— 點下去會打開系統檔案挑選器然後整個卡住，
            // 後面每一個工具都找不到。症狀看起來像「Theme Tools 不見了」，
            // 而真正的原因在三個步驟之前。
            dismissSheet(app)
        }

        XCTAssertTrue(
            failures.isEmpty,
            "這些插入工具點了沒有打開東西：\n" + failures.joined(separator: "\n"))
    }

    /// 「從本機檔案匯入」那幾項真的在選單裡。
    ///
    /// **只找，不點。** 它們開的是系統檔案挑選器，而那個東西一旦打開就
    /// 會把整條測試卡住，後面每一項都找不到 —— 症狀是某個毫不相干的
    /// 工具「不見了」（上面那段註解記的就是這件事）。
    ///
    /// 這一條守的是一個很容易悄悄消失的東西：使用者手上那個檔案進得來
    /// 的那條路。它沒有自己的畫面可以檢查，所以沒有這條測試的話，
    /// 哪天選單重排把它擠掉了，不會有任何閘門變紅。
    func testLocalFileImportEntriesAreInTheMenu() {
        let app = launch()
        guard openEditor(app) else {
            XCTFail("進不到編輯器")
            return
        }
        element(app, "editor.more").tap()

        var missing: [String] = []
        for label in ["Choose from Files", "Import an audio file", "Insert 3D Model"] {
            let item = app.buttons[label].firstMatch
            if !item.waitForExistence(timeout: 3) {
                // **一定要捲。** 這張選單在手機上放不下所有項目。
                for _ in 0..<6 where !item.exists { app.swipeUp() }
            }
            if !item.exists { missing.append(label) }
        }

        XCTAssertTrue(
            missing.isEmpty,
            "插入選單裡找不到這幾項匯入入口：\n" + missing.joined(separator: "\n"))
    }
}

/// 現場所有有識別碼的元素。
///
/// **先過濾再截斷。** 原本寫的是 `.prefix(50).filter { !$0.isEmpty }` ——
/// 先截前五十個元素、再挑出有識別碼的，於是實際印出來只有十幾個，
/// 而且永遠是樹最前面那一段（工具列）。它害我把「傾印裡沒有 model3d.*」
/// 當成「模型沒插進去」的證據，追了兩層冤枉路。
func liveIdentifiers(_ app: XCUIApplication, limit: Int = 80) -> [String] {
    app.descendants(matching: .any).allElementsBoundByIndex
        .map { $0.identifier }
        .filter { !$0.isEmpty }
        .prefix(limit)
        .map { $0 }
}

/// 針對 3D 卡片問一個**明確的問題**，而不是傾印樹的前面一段。
///
/// 傾印會騙人：工具列加二十幾個 `editor.canvas` 就把額度吃光，卡片在更深的
///地方，於是「傾印裡沒有 model3d.*」看起來像「模型沒插進去」——
/// 而模型其實好端端地在畫布上（手動開模擬器截圖確認過）。
func describeModel3d(_ app: XCUIApplication) -> String {
    let anyModel = app.descendants(matching: .any)
        .matching(NSPredicate(format: "identifier BEGINSWITH 'model3d'"))
    let ids = anyModel.allElementsBoundByIndex.map { $0.identifier }
    return "\n樹裡 model3d.* 的數量：\(ids.count)"
        + (ids.isEmpty ? "（一個都沒有 —— 卡片可能沒插進去，也可能是整個子樹"
                         + "沒有進無障礙樹）" : "：" + ids.joined(separator: ", "))
        + "\n整棵樹的元素數：\(app.descendants(matching: .any).count)"
}
