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
}
