import XCTest

/// 重現「操作筆記頁或筆記本就閃退」的冒煙測試。
/// 每一步都在 app 仍存活時才繼續，崩潰會讓後續查詢失敗並記錄在報告中。
final class SmokeUITests: XCTestCase {

    private var app: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

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
        self.app = app
        return app
    }

    private func assertAlive(_ app: XCUIApplication, _ step: String) {
        XCTAssertEqual(app.state, .runningForeground, "App 在這一步之後不在前景：\(step)")
    }

    func testOpenNotebookAndPageOperations() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        // 1. 從首頁開啟一則筆記
        guard openSeedNotebook(app) else { return }
        sleep(2)
        assertAlive(app, "開啟筆記")

        // 2. 開啟筆記結構側欄
        let structure = app.buttons["editor.sidebar_toggle"].firstMatch
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

        // 兩個入口都在首頁導覽列上（不必捲動），用識別碼找：標籤是圖示按鈕的
        // 系統標籤，語言不同就不同。
        let manual = app.buttons["home.docs.manual"].firstMatch
        XCTAssertTrue(manual.waitForExistence(timeout: 8), "首頁找不到「操作手冊」入口")
        manual.tap()
        sleep(3)
        assertAlive(app, "開啟操作手冊")

        // 文件彈窗的標題列應該出現「Done」
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 8), "手冊彈窗沒有出現")
        done.tap()
        sleep(1)

        let privacy = app.buttons["home.docs.privacy"].firstMatch
        XCTAssertTrue(privacy.waitForExistence(timeout: 5), "首頁找不到「隱私權政策」入口")
        privacy.tap()
        sleep(3)
        assertAlive(app, "開啟隱私權政策")
    }

    /// 收合左側結構欄之後，畫布不能比展開時窄，而且側欄清單真的收起來了。
    ///
    /// 這條原本斷言「畫布寬度 > 視窗的 85%」。整頁模式之後那不成立了：
    /// 頁面是「寬高兩個比例取較小者」等比縮放（整張 A4 一定看得完），
    /// 手機直向時工具列吃掉大半高度，紙本來就只有視窗的七成寬。
    /// 「撐滿」不是這個版面的承諾；承諾的是**側欄不該佔走畫布的空間**。
    func testCanvasExpandsWhenSidebarCollapses() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        guard openSeedNotebook(app) else { return }
        sleep(3)

        // **不指定型別。** 原本查的是 `scrollViews` —— 畫布確實是
        // `PKCanvasView`（UIScrollView 的子類），但整頁模式把它套上縮放
        // 之後，XCUITest 樹裡它就不再以 ScrollView 出現，測試於是說
        // 「找不到畫布」而畫面上明明有。識別字才是我們保證的東西。
        let canvas = app.descendants(matching: .any)["editor.canvas"].firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 8), "找不到畫布：\n\(app.debugDescription)")

        let structure = app.buttons["editor.sidebar_toggle"].firstMatch
        XCTAssertTrue(structure.waitForExistence(timeout: 5), "找不到筆記結構按鈕")

        // 量最寬的那一個：`editor.canvas` 同時掛在工作區容器與裡面的 `PKCanvasView` 上。
        func canvasWidth() -> CGFloat {
            app.descendants(matching: .any).matching(identifier: "editor.canvas")
                .allElementsBoundByIndex.map { $0.frame.width }.max() ?? 0
        }
        // 側欄清單只在展開時才存在。
        func sidebarIsOpen() -> Bool {
            app.descendants(matching: .any).matching(identifier: "editor.sidebar.list")
                .firstMatch.waitForExistence(timeout: 2)
        }

        // 側欄可能預設展開（iPad）或收合（iPhone）—— 先確保它是收合的。
        if sidebarIsOpen() {
            structure.tap()
            sleep(2)
        }
        XCTAssertFalse(sidebarIsOpen(), "點了結構按鈕之後側欄還開著")
        let collapsed = canvasWidth()

        structure.tap()
        sleep(2)
        XCTAssertTrue(sidebarIsOpen(), "再點一次結構按鈕，側欄沒有展開")
        let expanded = canvasWidth()

        XCTAssertGreaterThan(collapsed, 0, "收合狀態量不到畫布寬度")
        XCTAssertGreaterThanOrEqual(
            collapsed, expanded - 1,
            "側欄收合後畫布反而比展開時窄：收合 \(collapsed) / 展開 \(expanded)")
        assertAlive(app, "收合側欄")
    }

    /// 文字模式與手繪模式**共用同一塊紙**，而且文字模式打的字回到手繪模式後
    /// 仍然點得到、可以再編輯。
    ///
    /// # 這條守的是什麼
    ///
    /// 使用者回報兩件事：
    /// 1. 選了紙張樣板（如「橫線筆記」），切到文字模式後樣板消失、變成全白頁，
    ///    頁面也不置中、可用區域的框線不見了。
    /// 2. 文字模式打的字，切回手繪模式會變成文字方塊，卻點不動、拖不動。
    ///
    /// 兩者同一個根因：文字模式被換成獨立的 `WordDocumentEditorView`，整塊工作區
    /// （樣板、置中、框線、物件層）都不在了。這條在 22fbc58 修過一次，
    /// e479503 又把它「恢復」回來。
    ///
    /// 樣板本身是 UIKit 繪出來的、查不到，所以這裡守的是它的**必要條件**：
    /// 文字模式下畫布與手繪模式是同一塊、位置與大小不變（沒有換成另一個視圖）。
    func testTextModeSharesThePaperAndItsTextBoxesStayEditableInDrawMode() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        let newNote = app.descendants(matching: .any)
            .matching(identifier: "home.action.new_note").firstMatch
        guard newNote.waitForExistence(timeout: 15) else {
            return XCTFail("首頁找不到新增筆記入口")
        }
        newNote.tap()
        let confirm = app.descendants(matching: .any)
            .matching(identifier: "new_notebook.confirm").firstMatch
        guard confirm.waitForExistence(timeout: 10) else {
            return XCTFail("新增筆記表單沒有確認按鈕")
        }
        confirm.tap()

        // `editor.canvas` 同時掛在工作區容器與裡面那張紙（`PKCanvasView`）上；
        // 紙是比較窄的那一個。
        func paperFrame() -> CGRect {
            app.descendants(matching: .any).matching(identifier: "editor.canvas")
                .allElementsBoundByIndex
                .map(\.frame)
                .filter { $0.width > 0 }
                .min { $0.width < $1.width } ?? .zero
        }
        let canvas = app.descendants(matching: .any)["editor.canvas"].firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 15), "建立筆記後沒有進入畫布")
        sleep(1)
        let windowMidX = app.windows.firstMatch.frame.midX
        XCTAssertGreaterThan(paperFrame().width, 0, "手繪模式量不到畫布")
        XCTAssertEqual(paperFrame().midX, windowMidX, accuracy: 24, "手繪模式下頁面沒有置中")

        // 1. 切到文字模式：還是同一塊畫布、頁面仍置中。
        //
        // 紙的**大小**在兩個模式下不同是正常的：文字模式的工具列比較高，整頁模式
        // 取寬高兩個比例的較小者縮放。所以不比大小，比的是「還在」與「置中」。
        let typeMode = app.descendants(matching: .any)
            .matching(identifier: "portal.type").firstMatch
        guard typeMode.waitForExistence(timeout: 10) else {
            return XCTFail("找不到文字模式按鈕 portal.type")
        }
        typeMode.tap()
        XCTAssertTrue(
            canvas.waitForExistence(timeout: 10),
            "切到文字模式後畫布不見了 —— 工作區被換成另一個視圖（樣板、置中、框線都會跟著沒有）")
        sleep(1)
        XCTAssertEqual(paperFrame().midX, windowMidX, accuracy: 24, "文字模式下頁面沒有置中")

        // 2. 在文字模式打字。
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3)).tap()
        let inlineEditor = app.descendants(matching: .any)
            .matching(identifier: "editor.text.inline_editor").firstMatch
        guard inlineEditor.waitForExistence(timeout: 10) else {
            return XCTFail("文字模式點擊頁面後沒有出現就地文字編輯器")
        }
        let sentinel = "MoveMe"
        inlineEditor.typeText(sentinel)

        // 3. 回手繪模式：文字方塊還在，點它要能再編輯。
        let drawMode = app.descendants(matching: .any)
            .matching(identifier: "portal.draw").firstMatch
        guard drawMode.waitForExistence(timeout: 10) else {
            return XCTFail("找不到手繪模式按鈕 portal.draw")
        }
        drawMode.tap()
        sleep(1)
        let box = app.staticTexts[sentinel].firstMatch
        guard box.waitForExistence(timeout: 10) else {
            return XCTFail("回到手繪模式後找不到剛打的文字方塊")
        }
        box.tap()
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "editor.text.inline_editor")
                .firstMatch.waitForExistence(timeout: 10),
            "手繪模式下點文字方塊沒有進入編輯")
        // 那一下單擊不能被 PencilKit 當成一筆 —— 單擊要與繪圖手勢同時辨識，
        // 前提是它不會多出一個點。
        XCTAssertEqual(Self.strokeCount(in: app), 0, "點文字方塊多畫出了一筆")

        // 4. 移動：拖曳只在「不在編輯中」時生效，所以先離開編輯狀態
        //    （切到手繪再切回文字），再把方塊拖到別處。
        app.descendants(matching: .any).matching(identifier: "portal.draw").firstMatch.tap()
        sleep(1)
        typeMode.tap()
        sleep(1)
        let movable = app.staticTexts[sentinel].firstMatch
        guard movable.waitForExistence(timeout: 10) else {
            return XCTFail("回到文字模式後找不到文字方塊")
        }
        let before = movable.frame
        movable.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(
                forDuration: 0.2,
                thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)))
        sleep(1)
        let after = app.staticTexts[sentinel].firstMatch.frame
        XCTAssertGreaterThan(
            abs(after.midY - before.midY), 20,
            "拖曳之後文字方塊沒有移動：\(before) → \(after)")
        assertAlive(app, "手繪模式再編輯、文字模式移動文字方塊")
    }

    /// 回收桶的完整路徑：刪除 → 進回收桶 → 還原 → 再刪除 → 永久刪除。
    ///
    /// # 這條守的是什麼
    ///
    /// 單元測試證明了背後的搬檔案與規則，但**沒有人真的點過回收桶畫面**。
    /// 這裡從使用者的位置走一遍：首頁卡片長按選單刪除、診斷畫面裡的回收桶入口、
    /// 還原、永久刪除。畫面能編譯、入口不擋別的東西，都不等於它點得動。
    ///
    /// 用一個一次性的標題找卡片，不依賴種子筆記；最後以永久刪除收尾，
    /// 不在模擬器上留下垃圾（墓碑仍在索引裡，那是設計）。
    func testTrashRoundTripFromTheHomeScreen() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        let title = "TrashProbe-\(UUID().uuidString.prefix(8))"

        // 1. 建立一本有獨特標題的筆記本，然後回首頁。
        let newNote = app.descendants(matching: .any)
            .matching(identifier: "home.action.new_note").firstMatch
        guard newNote.waitForExistence(timeout: 15) else {
            return XCTFail("首頁找不到新增筆記入口")
        }
        newNote.tap()
        let field = app.descendants(matching: .any)
            .matching(identifier: "new_notebook.title.field").firstMatch
        guard field.waitForExistence(timeout: 10) else {
            return XCTFail("新增筆記表單沒有出現")
        }
        // 預設標題是有內容的，要先清掉。點欄位**最右邊**讓游標落在文字尾端，再用刪除鍵
        // 一個一個刪 —— 不用「全選」：原生文字欄位的編輯選單抓不到。
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        if let existing = field.value as? String, !existing.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        field.typeText(title)
        app.descendants(matching: .any).matching(identifier: "new_notebook.confirm")
            .firstMatch.tap()
        let home = app.descendants(matching: .any).matching(identifier: "editor.home").firstMatch
        guard home.waitForExistence(timeout: 15) else {
            return XCTFail("建立筆記後沒有進入編輯器")
        }
        home.tap()

        // 首頁那張卡片。卡片在摺線下面，要捲到看得到。
        func card() -> XCUIElement {
            app.descendants(matching: .any)
                .matching(NSPredicate(
                    format: "identifier BEGINSWITH 'home.notebooks.card.' AND label CONTAINS %@",
                    title))
                .firstMatch
        }
        func scrollToCard() -> Bool {
            var scrolls = 0
            while !(card().exists && card().isHittable) && scrolls < 12 {
                app.swipeUp()
                scrolls += 1
            }
            return card().exists && card().isHittable
        }
        func waitGone(_ element: XCUIElement, _ message: String) {
            let gone = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"), object: element)
            XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed, message)
        }

        // 用原生選單項目的標籤找（與 InsertToolsAudit 同一個理由：Menu 交給 UIKit 之後，
        // 型別化的查詢會 type mismatch）。
        func deleteFromCardMenu() -> Bool {
            guard scrollToCard() else { return false }
            card().press(forDuration: 1.2)
            // 先用按鈕查詢：在首頁這麼大的階層上，`descendants(matching: .any)` 一次
            // 快照要好幾十秒（實測整段刪除拖了兩分鐘）。找不到才退回萬用查詢。
            let button = app.buttons["Delete Item"].firstMatch
            if button.waitForExistence(timeout: 5) {
                button.tap()
                return true
            }
            let item = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", "Delete Item")).firstMatch
            guard item.waitForExistence(timeout: 5) else { return false }
            item.tap()
            return true
        }

        /// 回傳 `nil` 表示成功，否則是**卡在哪一步**。三種失敗長得一樣（都是「開不了回收桶」），
        /// 但原因完全不同，分開講才知道該修哪裡。
        func openTrash() -> String? {
            let started = Date()
            func log(_ step: String) {
                print("TRASHTEST \(step) +\(Int(Date().timeIntervalSince(started)))s")
            }
            let diagnostics = app.buttons["home.diagnostics"].firstMatch
            var ups = 0
            while !diagnostics.isHittable && ups < 4 { app.swipeDown(); ups += 1 }
            guard diagnostics.waitForExistence(timeout: 10), diagnostics.isHittable else {
                return "首頁找不到（或點不到）診斷入口 home.diagnostics"
            }
            log("diagnostics ready")
            diagnostics.tap()
            // 診斷頁是一張很長的表單，SwiftUI 的 List 沒捲到就不算繪那一列。
            let entry = app.buttons["settings.trash"].firstMatch
            var scrolls = 0
            while !(entry.exists && entry.isHittable) && scrolls < 15 {
                app.swipeUp()
                scrolls += 1
            }
            log("scrolled \(scrolls)x, entry exists=\(entry.exists) hittable=\(entry.isHittable)")
            guard entry.exists, entry.isHittable else {
                return "診斷頁往下捲了 \(scrolls) 次，找不到（或點不到）回收桶入口 settings.trash"
            }
            entry.tap()
            // 用「完成」按鈕當作回收桶已開啟的訊號，不用 `trash.sheet`：那個識別碼掛在
            // `NavigationStack` 這個容器上，SwiftUI 不會把容器的識別碼暴露出來。
            guard app.buttons["trash.done"].firstMatch.waitForExistence(timeout: 10) else {
                return "點了回收桶入口，但回收桶畫面沒有出現（找不到 trash.done）"
            }
            log("trash open")
            return nil
        }

        func closeTrash() {
            app.buttons["trash.done"].firstMatch.tap()
            app.buttons["diagnostics.close"].firstMatch.tap()
        }

        func trashRow() -> XCUIElement {
            app.descendants(matching: .any).matching(identifier: "trash.row")
                .containing(NSPredicate(format: "label == %@", title)).firstMatch
        }

        // 2. 刪除 → 卡片消失。
        XCTAssertTrue(deleteFromCardMenu(), "首頁卡片的長按選單沒有「刪除」")
        waitGone(card(), "刪除之後卡片還在首頁")

        // 3. 進回收桶 → 看得到它 → 還原。
        XCTAssertNil(openTrash(), "開不了回收桶")
        XCTAssertTrue(trashRow().waitForExistence(timeout: 10), "剛刪掉的筆記本不在回收桶裡")
        trashRow().buttons["trash.restore"].firstMatch.tap()
        waitGone(trashRow(), "還原之後它還在回收桶裡")
        closeTrash()

        // 4. 回到首頁：卡片回來了。
        XCTAssertTrue(scrollToCard(), "還原之後首頁沒有這本筆記本")

        // 5. 再刪一次 → 回收桶 → 永久刪除（二次確認）。
        XCTAssertTrue(deleteFromCardMenu(), "還原之後的卡片沒有「刪除」選項")
        waitGone(card(), "第二次刪除之後卡片還在首頁")
        XCTAssertNil(openTrash(), "第二次開不了回收桶")
        XCTAssertTrue(trashRow().waitForExistence(timeout: 10), "第二次刪掉的不在回收桶裡")
        trashRow().buttons["trash.deleteForever"].firstMatch.tap()
        let confirm = app.alerts.buttons["Delete Permanently"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "永久刪除沒有二次確認")
        confirm.tap()
        waitGone(trashRow(), "永久刪除之後它還在回收桶裡")
        closeTrash()
        assertAlive(app, "回收桶完整路徑")
    }

    /// 從全新的筆記本驗證「手寫 → 文字 → 點頁面 → 直接輸入」完整路徑。
    ///
    /// 過去這條測試只點 `editor.mode` 容器，再點一下畫布，最後只確認 App
    /// 沒有閃退。即使模式根本沒切換、文字框根本沒建立，測試仍會通過。
    /// 這裡必須真的找到 TextEditor、輸入文字並讀回值，才算功能落地。
    func testDrawingToolsAndTypeModeGridTap() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        let newNote = app.descendants(matching: .any)
            .matching(identifier: "home.action.new_note").firstMatch
        guard newNote.waitForExistence(timeout: 15) else {
            return XCTFail("首頁找不到新增筆記入口")
        }
        newNote.tap()

        let title = app.descendants(matching: .any)
            .matching(identifier: "new_notebook.title.field").firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10), "新增筆記表單沒有出現")

        let confirm = app.descendants(matching: .any)
            .matching(identifier: "new_notebook.confirm").firstMatch
        guard confirm.waitForExistence(timeout: 10) else {
            return XCTFail("新增筆記表單沒有確認按鈕")
        }
        confirm.tap()

        let canvas = app.descendants(matching: .any)["editor.canvas"].firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 15), "建立筆記後沒有進入畫布")

        // 新筆記預設是手繪模式；先確認手繪工具真的可操作。
        let penTool = app.descendants(matching: .any)["editor.tool.pen"].firstMatch
        if penTool.waitForExistence(timeout: 5) {
            penTool.tap()
            assertAlive(app, "點選鋼筆工具")
        }

        // 必須點真正的文字模式按鈕，不能再點沒有動作的容器。
        let typeMode = app.descendants(matching: .any)
            .matching(identifier: "portal.type").firstMatch
        guard typeMode.waitForExistence(timeout: 10) else {
            return XCTFail("找不到文字模式按鈕 portal.type")
        }
        typeMode.tap()

        // 點空白頁面後，應立即出現並聚焦內嵌 TextEditor。
        let coordinate = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.45))
        coordinate.tap()

        let inlineEditor = app.descendants(matching: .any)
            .matching(identifier: "editor.text.inline_editor").firstMatch
        guard inlineEditor.waitForExistence(timeout: 10) else {
            return XCTFail("文字模式點擊空白頁後沒有建立就地文字編輯器")
        }
        let sentinel = "Word style typing works"
        // 不可再補點一次 TextEditor：第一次點頁面就必須已經取得焦點。
        inlineEditor.typeText(sentinel)

        let value = inlineEditor.value as? String ?? ""
        XCTAssertTrue(value.contains(sentinel), "TextEditor 沒有收到輸入；目前值：\(value)")
        assertAlive(app, "文字模式即點即書")
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

        // 診斷頁是一張很長的表單，轉換區段離頂端很遠。SwiftUI 的 List 沒捲到就
        // 不算繪那一列，所以「找不到」不代表沒有 —— 往下捲到它出現而且點得到。
        let convert = app.buttons["migration.run"]
        var scrolls = 0
        while !(convert.exists && convert.isHittable) && scrolls < 15 {
            app.swipeUp()
            scrolls += 1
        }
        guard convert.exists, convert.isHittable else {
            return XCTFail("診斷頁往下捲了 \(scrolls) 次，還是找不到轉換按鈕")
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

        // 在 iPhone (compact) 上，因為頂端工具列放不下所有文字標籤按鈕，
        // 系統會自動將它們折疊進「更多」選單（OverflowBarButtonItem）。
        // 如果這個選單存在，我們必須點開它才能讓畫面稽核找到裡面的控制項。
        let overflowById = app.buttons["OverflowBarButtonItem"].firstMatch
        let overflowByLabel = app.navigationBars.buttons["More"].firstMatch
        if overflowById.exists {
            overflowById.tap()
            _ = app.collectionViews.firstMatch.waitForExistence(timeout: 2)
        } else if overflowByLabel.exists {
            overflowByLabel.tap()
            _ = app.collectionViews.firstMatch.waitForExistence(timeout: 2)
        }

        ScreenAudit.check(app, screen: "home", allowMissing: Self.homeNotWiredYet)
    }

    /// 編輯器：同上。
    func testEditorScreenControlsAreReachable() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        // 共用 helper 以 `home.notebooks.card.seed-welcome-notebook-v1` 找卡片，
        // 不依賴語言；卡片在 LazyVGrid 摺線下方時也會先捲到節點建立為止。
        guard openSeedNotebook(app) else { return }

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

        guard openSeedNotebook(app) else { return }

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

        guard openSeedNotebook(app) else { return }

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

        guard openSeedNotebook(app) else { return }

        let canvas = app.descendants(matching: .any)["editor.canvas"].firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 15), "找不到畫布")

        let before = Self.strokeCount(in: app)

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

        let afterDraw = Self.strokeCount(in: app)
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

        guard openSeedNotebook(app) else { return }

        let canvasAgain = app.descendants(matching: .any)["editor.canvas"].firstMatch
        XCTAssertTrue(canvasAgain.waitForExistence(timeout: 15), "重新開啟之後找不到畫布")
        sleep(2)

        XCTAssertGreaterThanOrEqual(
            Self.strokeCount(in: app), afterDraw,
            "**筆跡沒有留下來。** 離開前畫布上有 \(afterDraw) 筆，"
                + "重新開啟之後剩 \(Self.strokeCount(in: app)) 筆。")
    }

    /// 只畫一筆然後停住 —— **不離開編輯器**。
    ///
    /// 把「畫得進去嗎」「存得下去嗎」「離開再回來還在嗎」三件事拆開。
    /// 合在一條裡的話，紅燈只說得出「最後沒了」，說不出是哪一段掉的。
    func testInkProbeDrawOnly() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        guard openSeedNotebook(app) else { return }

        let canvas = app.descendants(matching: .any)["editor.canvas"].firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 15), "找不到畫布")

        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.45))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.55))
        start.press(forDuration: 0.4, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.4)
        sleep(4)

        XCTAssertGreaterThan(Self.strokeCount(in: app), 0, "畫不進去")
    }

    /// 畫一筆 → 回首頁 → **停在首頁**。
    ///
    /// 與 `testInkProbeDrawOnly` 合起來夾出「是離開時掉的，還是重新開啟時
    /// 掉的」。檔案內容由外面的腳本檢查 —— 測試本身只負責把 App 開到那個
    /// 狀態。
    func testInkProbeDrawThenLeave() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        guard openSeedNotebook(app) else { return }

        let canvas = app.descendants(matching: .any)["editor.canvas"].firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 15), "找不到畫布")

        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.45))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.55))
        start.press(forDuration: 0.4, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.4)
        sleep(4)
        XCTAssertGreaterThan(Self.strokeCount(in: app), 0, "畫不進去")

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
    ///
    /// **要掃過所有 `editor.canvas`，不能用 `firstMatch`。** 這個識別字同時掛在
    /// 外層的 SwiftUI 容器與裡面的 `PKCanvasView` 上，讀數只在後者；
    /// `firstMatch` 拿到哪一個由樹序決定，拿到容器就永遠讀不到。
    static func strokeCount(in app: XCUIApplication) -> Int {
        let matches = app.descendants(matching: .any).matching(identifier: "editor.canvas")
        for element in matches.allElementsBoundByIndex {
            guard let value = element.value as? String,
                  let range = value.range(of: "strokes:")
            else { continue }
            return Int(value[range.upperBound...].prefix(while: \.isNumber)) ?? -1
        }
        return -1
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

        guard openSeedNotebook(app) else { return }

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

        guard openSeedNotebook(app) else { return }

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
    /// 入口在「更多」選單裡。選單項目的 identifier 進不了 UIKit 算繪的
    /// 無障礙樹，但英文標籤仍在，所以沿用 InsertToolsAudit 的原生選單捲動
    /// helper，實際走一次使用者路徑，而不是用啟動旗標跳過入口。
    func testToolbarCustomizationControlsAreReachable() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        guard openSeedNotebook(app) else { return }

        let more = app.descendants(matching: .any)
            .matching(identifier: "editor.more").firstMatch
        guard more.waitForExistence(timeout: 15), more.isHittable else {
            return XCTFail("編輯器上沒有可操作的「更多」選單")
        }
        more.tap()
        let firstMenuItem = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Asset Library")).firstMatch
        if !firstMenuItem.waitForExistence(timeout: 3) {
            if more.isHittable {
                more.tap()
                _ = firstMenuItem.waitForExistence(timeout: 3)
            }
        }
        guard ScreenAudit.tapMenuItem(app, label: "Customize Toolbar") else {
            return XCTFail("「更多」選單裡找不到 Customize Toolbar")
        }

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
