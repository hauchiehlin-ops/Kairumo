//
//  InkInvariantMatrixAudit.swift
//  KairumoUITests
//
//  筆跡不變式矩陣（架構審視 P0，Layer 4）。
//
//  # 它守的是什麼
//
//  使用者回報：
//  1. 打開筆記本後，手繪模式下第一頁內容消失，點「一鍵恢復」才回來；切打字模式又消失。
//  2. 點擊任何一個頁面縮圖，該頁內容消失。
//  3. 固定／連續頁面切換後內容遺失。
//
//  傳統 UI 測試只檢查「按鈕找不找得到」。這份測試在每一次模式切換、縮圖跳頁、
//  版面切換之後，直接讀取畫布的 `strokes:N`，跟預先塞入的非對稱筆畫數比對 ——
//  只要發生任何「空白副本覆蓋」或「頁碼錯位」，測試立刻以確定性的數值失敗。
//

import XCTest

final class InkInvariantMatrixAudit: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["KAIRUMO_UITEST"] = "1"
        app.launchEnvironment["KAIRUMO_UITEST_SEED_INK"] = "1"
        app.launch()
        return app
    }

    private func find(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        let other = app.otherElements[id]
        if other.exists { return other }
        let button = app.buttons[id]
        if button.exists { return button }
        return app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func openInkNotebook(_ app: XCUIApplication) -> Bool {
        let cardId = "home.notebooks.card.uitest-ink-notebook"
        let editorMore = find(app, "editor.more")
        guard find(app, "home.action.new_note").waitForExistence(timeout: 30) else {
            XCTFail("首頁沒有載入")
            return false
        }
        for _ in 0..<12 {
            let card = find(app, cardId)
            if card.exists && card.isHittable {
                card.tap()
                if editorMore.waitForExistence(timeout: 20) { return true }
            }
            app.swipeUp()
        }
        XCTFail("找不到筆跡不變式專用筆記（\(cardId)）")
        return false
    }

    /// 從畫布無障礙值讀出目前筆畫數 `strokes:N`。
    ///
    /// ⚠️ 畫面上有多個容器都掛了 `editor.canvas`（SwiftUI 外層容器與底層 `PKCanvasView`），
    /// 只有真正的 `PKCanvasView`（型別為 ScrollView）在 `KAIRUMO_UITEST=1` 下會吐出
    /// `zoom:%.3f strokes:%d pro:%d` 讀數。這裡精確找到帶有 `strokes:` 的那一個。
    private func parseStrokeCount(_ app: XCUIApplication) -> Int? {
        let scrollViews = app.scrollViews.matching(identifier: "editor.canvas").allElementsBoundByIndex
        for el in scrollViews {
            if let val = el.value as? String, val.contains("strokes:") {
                let parts = val.split(separator: " ")
                for part in parts where part.hasPrefix("strokes:") {
                    return Int(part.dropFirst("strokes:".count))
                }
            }
        }
        let all = app.descendants(matching: .any).matching(identifier: "editor.canvas").allElementsBoundByIndex
        for el in all {
            if let val = el.value as? String, val.contains("strokes:") {
                let parts = val.split(separator: " ")
                for part in parts where part.hasPrefix("strokes:") {
                    return Int(part.dropFirst("strokes:".count))
                }
            }
        }
        return nil
    }

    /// 不變式 I1 & I2：切換手繪／打字模式不改變任何筆畫。
    func testModeSwitchingPreservesInk() throws {
        let app = launch()
        guard openInkNotebook(app) else { return }

        // 第 0 頁初始預設為 3 筆
        let initialStrokes = parseStrokeCount(app)
        XCTAssertEqual(initialStrokes, 3, "第 0 頁初次開啟時筆跡數量應為 3")

        // 切到打字模式
        let typeBtn = find(app, "portal.type")
        if typeBtn.waitForExistence(timeout: 8) {
            typeBtn.tap()
            Thread.sleep(forTimeInterval: 0.5)
            let typedStrokes = parseStrokeCount(app)
            XCTAssertEqual(typedStrokes, 3, "切換到打字模式後筆畫不准消失或歸零")
        }

        // 切回手繪模式
        let drawBtn = find(app, "portal.draw")
        if drawBtn.waitForExistence(timeout: 8) {
            drawBtn.tap()
            Thread.sleep(forTimeInterval: 0.5)
            let backStrokes = parseStrokeCount(app)
            XCTAssertEqual(backStrokes, 3, "切回手寫模式後筆畫必須完好留存")
        }
    }

    /// 不變式 I3：點擊側邊欄縮圖換頁，每一頁的筆跡都維持各自的數量（防序號錯位與覆蓋）。
    func testThumbnailPageSwitchingPreservesEachPagesInk() throws {
        let app = launch()
        guard openInkNotebook(app) else { return }

        // 打開側邊欄（若尚未展開）
        let sidebarToggle = find(app, "editor.sidebar_toggle")
        if sidebarToggle.waitForExistence(timeout: 5) && sidebarToggle.isHittable {
            sidebarToggle.tap()
        }

        // 點第 1 頁縮圖（預期 5 筆）
        let page1 = find(app, "sidebar.page.1")
        if page1.waitForExistence(timeout: 8) {
            page1.tap()
            Thread.sleep(forTimeInterval: 0.6)
            let p1Strokes = parseStrokeCount(app)
            XCTAssertEqual(p1Strokes, 5, "切換到第 1 頁後筆畫數應為 5")
        }

        // 點第 2 頁縮圖（預期 2 筆）
        let page2 = find(app, "sidebar.page.2")
        if page2.waitForExistence(timeout: 8) {
            page2.tap()
            Thread.sleep(forTimeInterval: 0.6)
            let p2Strokes = parseStrokeCount(app)
            XCTAssertEqual(p2Strokes, 2, "切換到第 2 頁後筆畫數應為 2")
        }

        // 回到第 0 頁（預期 3 筆，不能因為前面切換被空筆記蓋掉）
        let page0 = find(app, "sidebar.page.0")
        if page0.waitForExistence(timeout: 8) {
            page0.tap()
            Thread.sleep(forTimeInterval: 0.6)
            let p0Strokes = parseStrokeCount(app)
            XCTAssertEqual(p0Strokes, 3, "切回第 0 頁後筆畫數必須仍為 3")
        }
    }

    /// 不變式 I2：固定頁面與連續頁面切換後，筆跡完整性維持。
    func testDisplayModeTogglePreservesInk() throws {
        let app = launch()
        guard openInkNotebook(app) else { return }

        let initialStrokes = parseStrokeCount(app)
        XCTAssertEqual(initialStrokes, 3, "初始筆畫應為 3")

        let modeBtn = find(app, "editor.page.display_mode")
        if modeBtn.waitForExistence(timeout: 8) && modeBtn.isHittable {
            // 切換至連續模式
            modeBtn.tap()
            Thread.sleep(forTimeInterval: 0.8)
            let contStrokes = parseStrokeCount(app)
            XCTAssertEqual(contStrokes, 3, "切換至連續模式後第 0 頁筆畫數應為 3")

            // 切回單頁模式
            modeBtn.tap()
            Thread.sleep(forTimeInterval: 0.8)
            let singleStrokes = parseStrokeCount(app)
            XCTAssertEqual(singleStrokes, 3, "切回單頁模式後第 0 頁筆畫數應為 3")
        }
    }
}
