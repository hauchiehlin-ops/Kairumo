//
//  ObjectLockUITests.swift
//  KairumoUITests
//
//  鎖定在畫布上：鎖得上，也**找得到、解得開**。
//
//  使用者回報「鎖得上卻看不到解鎖的入口」：角落的鎖頭原本掛在物件 `.position(...)` 之後，
//  外框是整個頁面，鎖頭被放到頁面右上角（畫面外）；手寫模式下點鎖定的物件也沒有任何反應。
//  這裡守住：鎖頭在物件角落（兩種模式都看得到）、點鎖頭就出現「解除鎖定」、按了真的解開。
//
//  物件由 `KAIRUMO_UITEST_SEED_OBJECTS=1` 放進專用筆記第 1 頁（見 `InteractionMatrixAudit`），
//  `KAIRUMO_UITEST_SEED_LOCKED=1` 讓其中的圖片一開始就鎖住。
//

import XCTest

final class ObjectLockUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func find(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        let button = app.buttons[id]
        if button.exists { return button }
        let other = app.otherElements[id]
        if other.exists { return other }
        return app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func openMatrixNotebook(_ app: XCUIApplication) {
        let cardId = "home.notebooks.card.uitest-matrix-notebook"
        XCTAssertTrue(find(app, "home.action.new_note").waitForExistence(timeout: 20), "首頁沒有載入")
        for _ in 0..<12 {
            let card = find(app, cardId)
            if card.exists && card.isHittable {
                card.tap()
                if find(app, "editor.more").waitForExistence(timeout: 10) { return }
            }
            app.swipeUp()
        }
        XCTFail("找不到互動矩陣專用筆記（\(cardId)）")
    }

    func testALockedObjectShowsItsLockAtTheCornerAndUnlocks() {
        let app = XCUIApplication()
        app.launchEnvironment["KAIRUMO_UITEST"] = "1"
        app.launchEnvironment["KAIRUMO_UITEST_SEED_OBJECTS"] = "1"
        app.launchEnvironment["KAIRUMO_UITEST_SEED_LOCKED"] = "1" // 圖片一開始就鎖住
        app.launch()
        openMatrixNotebook(app)

        let typing = find(app, "portal.type")
        XCTAssertTrue(typing.waitForExistence(timeout: 8))
        typing.tap()

        let image = find(app, "object.image")
        XCTAssertTrue(image.waitForExistence(timeout: 8), "找不到圖片物件")
        let frame = image.frame

        // 1. 鎖頭在物件的角落，而且在畫面裡。
        let badge = app.buttons["object.lock.badge"]
        XCTAssertTrue(badge.waitForExistence(timeout: 4), "鎖定的物件看不到鎖頭")
        XCTAssertTrue(frame.insetBy(dx: -40, dy: -40).contains(CGPoint(x: badge.frame.midX, y: badge.frame.midY)),
                      "鎖頭不在物件角落：物件 \(frame)，鎖頭 \(badge.frame)")
        XCTAssertTrue(badge.isHittable, "鎖頭點不到")

        // 2. 手寫模式下也看得到鎖頭（看得出它鎖住了）。
        let draw = find(app, "portal.draw")
        XCTAssertTrue(draw.waitForExistence(timeout: 4))
        draw.tap()
        XCTAssertTrue(badge.waitForExistence(timeout: 2), "手寫模式下也要看得出物件鎖住了")
        // 手寫模式下「手指點一下鎖定的物件 → 切到打字模式並給解鎖鈕」無法用 XCUITest 驗：
        // 它在手寫模式送出的座標點擊會被 PencilKit 當成落筆（畫出一個點），不會走到單擊辨識。
        // 這一段用模擬器的真實觸控手動驗證過。這裡回到打字模式，從鎖頭解鎖。
        typing.tap()

        // 3. 點鎖頭：出現「解除鎖定」。
        XCTAssertTrue(badge.waitForExistence(timeout: 2))
        badge.tap()
        let prompt = app.buttons["object.unlock.prompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 4), "點了鎖頭，沒有出現「解除鎖定」")

        // 4. 按下去就解開：鎖頭消失。
        prompt.tap()
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: badge)
        waitForExpectations(timeout: 4)
    }

    /// 鎖定只鎖位置：鎖定的物件照樣點得到、選得起來（才能編輯、複製），但拖不動。
    ///
    /// 以前鎖定是整個不接觸控：表格的儲存格改不了，Mac 上表格也找不到解除鎖定的選單。
    func testALockedObjectIsStillSelectableButCannotBeDragged() {
        let app = XCUIApplication()
        app.launchEnvironment["KAIRUMO_UITEST"] = "1"
        app.launchEnvironment["KAIRUMO_UITEST_SEED_OBJECTS"] = "1"
        app.launchEnvironment["KAIRUMO_UITEST_SEED_LOCKED"] = "1" // 圖片一開始就鎖住
        app.launch()
        openMatrixNotebook(app)

        let typing = find(app, "portal.type")
        XCTAssertTrue(typing.waitForExistence(timeout: 8))
        typing.tap()

        let image = find(app, "object.image")
        XCTAssertTrue(image.waitForExistence(timeout: 8), "找不到圖片物件")
        XCTAssertTrue(app.buttons["object.lock.badge"].waitForExistence(timeout: 4), "圖片應該是鎖定的")
        // 量的是圖片相對於另一個（沒鎖的）物件的位置：拖過鎖定的物件會捲動頁面，兩者一起動。
        let reference = find(app, "object.shape")
        XCTAssertTrue(reference.waitForExistence(timeout: 4), "找不到作為參考的形狀")
        func offset() -> CGPoint {
            CGPoint(x: image.frame.minX - reference.frame.minX, y: image.frame.minY - reference.frame.minY)
        }
        let before = offset()

        // 1. 點得到：選取之後出現物件動作（複製）。
        image.tap()
        XCTAssertTrue(app.buttons["object.action.copy"].waitForExistence(timeout: 3),
                      "鎖定的物件也要能選取（選取後應出現「複製」）")

        // 2. 拖不動。
        let start = image.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.2, thenDragTo: start.withOffset(CGVector(dx: 120, dy: 90)))
        let after = offset()
        XCTAssertEqual(after.x, before.x, accuracy: 2, "鎖定的物件被拖動了：\(before) → \(after)")
        XCTAssertEqual(after.y, before.y, accuracy: 2, "鎖定的物件被拖動了：\(before) → \(after)")
    }

    /// 物件剪下／複製／貼上：手繪與打字兩種模式、單頁與連續兩種頁面型態，
    /// 貼到同一頁或其他頁的任意位置都要成立。
    func testCutCopyPasteObjectAcrossModesAndPages() throws {
        let app = XCUIApplication()
        app.launchEnvironment["KAIRUMO_UITEST"] = "1"
        app.launchEnvironment["KAIRUMO_UITEST_SEED_OBJECTS"] = "1"
        app.launch()
        openMatrixNotebook(app)

        func saveShot(_ name: String) {
            let data = XCUIScreen.main.screenshot().pngRepresentation
            try? data.write(to: URL(fileURLWithPath: "/tmp/\(name).png"))
        }
        let images = app.descendants(matching: .any).matching(identifier: "object.image")
        let workspace = app.descendants(matching: .any).matching(identifier: "editor.workspace").firstMatch
        let typing = find(app, "portal.type")
        let drawMode = find(app, "portal.draw")
        let displayModeBtn = find(app, "editor.page.display_mode")
        let cutBtn = app.buttons["editor.object.cut"]
        let copyBtn = app.buttons["editor.object.copy"]
        let pasteBtn = app.buttons["editor.object.paste"]
        let pasteAtTapBtn = app.buttons["editor.object.paste_at_location"]
        let cancelPlaceBtn = app.buttons["editor.object.paste.cancel_place"]

        func setDisplayMode(_ mode: String) {
            XCTAssertTrue(displayModeBtn.waitForExistence(timeout: 4))
            if (displayModeBtn.value as? String) != mode { displayModeBtn.tap() }
            XCTAssertEqual(displayModeBtn.value as? String, mode)
        }
        func waitForCount(_ expected: Int, _ message: String) {
            let predicate = NSPredicate(format: "count == %d", expected)
            let exp = XCTNSPredicateExpectation(predicate: predicate, object: images)
            XCTAssertEqual(XCTWaiter().wait(for: [exp], timeout: 4), .completed,
                           "\(message)（預期 \(expected)，實際 \(images.count)）")
        }
        func pasteAtTap(_ offset: CGVector) {
            XCTAssertTrue(pasteAtTapBtn.waitForExistence(timeout: 3), "剪貼簿有內容時應顯示「點選位置貼上」")
            pasteAtTapBtn.tap()
            XCTAssertTrue(cancelPlaceBtn.waitForExistence(timeout: 3), "應進入點選位置貼上狀態")
            workspace.coordinate(withNormalizedOffset: offset).tap()
            XCTAssertTrue(cancelPlaceBtn.waitForNonExistence(timeout: 3), "點一下之後應結束點選位置貼上狀態")
        }

        // 1. 單頁 + 打字：選取圖片 → 複製 → 點選位置貼到同一頁
        setDisplayMode("single")
        XCTAssertTrue(typing.waitForExistence(timeout: 8))
        typing.tap()
        let image = find(app, "object.image")
        XCTAssertTrue(image.waitForExistence(timeout: 8))
        waitForCount(1, "第 1 頁一開始應只有 1 張圖片")
        image.tap()
        XCTAssertTrue(cutBtn.waitForExistence(timeout: 3), "選取物件後應顯示「剪下」")
        XCTAssertTrue(copyBtn.waitForExistence(timeout: 3), "選取物件後應顯示「複製」")
        copyBtn.tap()
        XCTAssertTrue(pasteBtn.waitForExistence(timeout: 3), "複製後應顯示「貼上」")
        pasteAtTap(CGVector(dx: 0.65, dy: 0.65))
        saveShot("ipad_1_single_type_pasted_same_page")
        waitForCount(2, "單頁打字模式：點選位置貼到同一頁")

        // 2. 單頁 + 手繪：剪下剛貼上的那份 → 換到第 2 頁 → 點選位置貼上
        XCTAssertTrue(drawMode.waitForExistence(timeout: 3))
        drawMode.tap()
        XCTAssertTrue(cutBtn.waitForExistence(timeout: 3), "手繪模式下選取中的物件也要能剪下")
        cutBtn.tap()
        waitForCount(1, "剪下之後第 1 頁應少一張圖片")
        find(app, "editor.page.add").tap()
        let next = find(app, "editor.page.next")
        XCTAssertTrue(next.waitForExistence(timeout: 3))
        next.tap()
        waitForCount(0, "第 2 頁一開始是空白的")
        drawMode.tap()
        pasteAtTap(CGVector(dx: 0.5, dy: 0.45))
        saveShot("ipad_2_single_draw_pasted_page2")
        waitForCount(1, "單頁手繪模式：剪下後貼到第 2 頁任意位置")

        // 3. 單頁 + 手繪：「貼上」直接貼到目前頁（第 2 頁）
        drawMode.tap()
        pasteBtn.tap()
        waitForCount(2, "單頁手繪模式：「貼上」到目前頁")

        // 4. 連續 + 打字：點選位置貼上
        setDisplayMode("continuous")
        typing.tap()
        let beforeContinuousType = images.count
        pasteAtTap(CGVector(dx: 0.3, dy: 0.8))
        saveShot("ipad_3_continuous_type_pasted")
        waitForCount(beforeContinuousType + 1, "連續頁面打字模式：點選位置貼上")

        // 5. 連續 + 手繪：點選位置貼上（手繪模式下的點擊不能被畫成墨點、也不能漏接）
        drawMode.tap()
        let beforeContinuousDraw = images.count
        pasteAtTap(CGVector(dx: 0.7, dy: 0.3))
        saveShot("ipad_4_continuous_draw_pasted")
        waitForCount(beforeContinuousDraw + 1, "連續頁面手繪模式：點選位置貼上")

        // 6. 連續 + 手繪：剪下 → 貼上（剪貼後數量不變）
        XCTAssertTrue(cutBtn.waitForExistence(timeout: 3))
        cutBtn.tap()
        waitForCount(beforeContinuousDraw, "連續頁面手繪模式：剪下")
        pasteBtn.tap()
        waitForCount(beforeContinuousDraw + 1, "連續頁面手繪模式：剪下後貼上")
        saveShot("ipad_5_continuous_draw_cut_paste")

        setDisplayMode("single")
    }
}
