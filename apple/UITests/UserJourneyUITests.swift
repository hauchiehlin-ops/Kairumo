//
//  UserJourneyUITests.swift
//  KairumoUITests
//
//  使用者旅程測試（P0）：從使用者會點的地方一路點到結果，驗的是「好用」而不只是「按鈕在」。
//  與 Android 的 `UserJourneyTest` 一一對應。
//
//  # 與既有稽核測試的差別
//
//  既有稽核把斷言包在「找得到那顆按鈕才檢查」裡 —— 按鈕不見了測試照樣綠燈。
//  這裡**找不到就失敗**：使用者找不到的入口，就是壞掉的功能。
//
//  # 守的旅程
//
//  1. 工具列選了橡皮擦，畫下去就是在擦。
//  2. 自訂飛梭工具盤：在設定裡拿掉一格，叫出工具盤就看不到它；選工具盤上的橡皮擦一樣真的會擦
//     （以前工具盤直接改 `selectedTool`，沒走工具列那條路）。
//

import XCTest

final class UserJourneyUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["KAIRUMO_UITEST"] = "1"
        app.launchEnvironment["KAIRUMO_UITEST_SEED_INK"] = "1"
        app.launch()
    }

    private func element(_ id: String) -> XCUIElement {
        // SwiftUI Menu 項目由 UIKit 的 UIAction 算繪，.accessibilityIdentifier 會被剝離，
        // 只能用標籤查詢（見 ScreenAudit 與 InsertToolsAudit 的說明）。
        let labelMap: [String: String] = [
            "editor.customize_toolbar": "Customize Toolbar"
        ]
        func findElement() -> XCUIElement? {
            if let label = labelMap[id] {
                let btn = app.buttons[label].firstMatch
                if btn.exists { return btn }
                let byLabel = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
                if byLabel.exists { return byLabel }
            }
            let query = app.descendants(matching: .any).matching(identifier: id)
            for i in 0..<query.count {
                let el = query.element(boundBy: i)
                if el.exists && el.isHittable { return el }
            }
            if query.firstMatch.exists { return query.firstMatch }
            return nil
        }

        if let found = findElement() { return found }

        // 如果在選單裡（UIMenu 是 UICollectionView 算繪），向下捲動尋找摺線下的項目（同 ScreenAudit.exists）
        if app.collectionViews.firstMatch.exists {
            for _ in 0..<3 {
                app.collectionViews.firstMatch.swipeUp()
                Thread.sleep(forTimeInterval: 0.3)
                if let found = findElement() { return found }
            }
        }

        if let label = labelMap[id] {
            return app.buttons[label].firstMatch
        }
        return app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func tap(_ id: String, _ why: String, timeout: TimeInterval = 10) {
        let el = element(id)
        XCTAssertTrue(el.waitForExistence(timeout: timeout), "\(why)（找不到 \(id)）")
        el.tap()
        Thread.sleep(forTimeInterval: 1.5)
    }

    /// 在清單裡往下捲到看得到為止再點（設定畫面的飛梭工具盤區段可能在摺線下）。
    private func scrollAndTap(_ id: String, _ why: String) {
        // 先確定自訂工具列 sheet 已經開起來了，並等待過場動畫穩定
        let sheetList = element("toolbar.customization.list")
        XCTAssertTrue(sheetList.waitForExistence(timeout: 5), "自訂工具列未展開")
        Thread.sleep(forTimeInterval: 1.0)

        let el = element(id)
        if el.waitForExistence(timeout: 2) && el.isHittable {
            el.tap()
            Thread.sleep(forTimeInterval: 1.5)
            return
        }

        // 溫和向下滾動（每次只滑 25% 高度，避免整格飛出畫面外）
        for _ in 0..<8 {
            if sheetList.exists {
                let start = sheetList.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
                let end = sheetList.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
                start.press(forDuration: 0.05, thenDragTo: end)
            } else {
                app.swipeUp()
            }
            Thread.sleep(forTimeInterval: 0.5)
            if el.exists && el.isHittable {
                break
            }
        }
        XCTAssertTrue(el.waitForExistence(timeout: 5) && el.isHittable, "\(why)（找不到 \(id)）")
        el.tap()
        Thread.sleep(forTimeInterval: 1.5)
    }

    private func openInkNotebook() {
        XCTAssertTrue(element("home.action.new_note").waitForExistence(timeout: 30), "首頁沒有載入")
        let card = element("home.notebooks.card.uitest-ink-notebook")
        for _ in 0..<12 where !(card.exists && card.isHittable) { app.swipeUp() }
        XCTAssertTrue(card.exists, "找不到測試用的筆記")
        card.tap()
        XCTAssertTrue(element("editor.more").waitForExistence(timeout: 20), "打開筆記之後沒有進到編輯器")
        sleep(1)
    }

    /// 畫布回報的 `strokes:N`（`KAIRUMO_UITEST=1` 時，`PKCanvasView` 的無障礙值）。
    private func strokes() -> Int {
        for el in app.descendants(matching: .any).matching(identifier: "editor.canvas").allElementsBoundByIndex {
            guard let value = el.value as? String, value.contains("strokes:") else { continue }
            for part in value.split(separator: " ") where part.hasPrefix("strokes:") {
                if let n = Int(part.dropFirst("strokes:".count)) { return n }
            }
        }
        XCTFail("畫布沒有回報筆畫數（strokes:N）")
        return -1
    }

    private func canvasFrame() -> CGRect {
        for el in app.scrollViews.matching(identifier: "editor.canvas").allElementsBoundByIndex where el.exists {
            return el.frame
        }
        return element("editor.canvas").frame
    }

    /// 在畫布中段橫著畫（或擦）一筆。先壓 0.2 秒再拖：比長按叫出飛梭工具盤的 0.55 秒短。
    private func stroke(atHeight fy: CGFloat) {
        let f = canvasFrame()
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let from = origin.withOffset(CGVector(dx: f.minX + f.width * 0.25, dy: f.minY + f.height * fy))
        let to = origin.withOffset(CGVector(dx: f.minX + f.width * 0.75, dy: f.minY + f.height * fy))
        from.press(forDuration: 0.2, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.1)
        sleep(1)
    }

    /// 畫一筆並確認真的多了一筆：合成觸控偶爾整段被系統吞掉，那就再畫一次。
    private func drawOneStroke(atHeight fy: CGFloat) -> Int {
        let before = strokes()
        for _ in 0..<3 {
            stroke(atHeight: fy)
            if strokes() == before + 1 { return before }
        }
        XCTFail("用鋼筆畫了一筆，筆畫數沒有多一（\(before) → \(strokes())）")
        return before
    }

    private func resetRadialFromSettings() {
        tap("editor.more", "找不到「更多」選單")
        tap("editor.customize_toolbar", "「更多」選單裡找不到自訂工具列")
        scrollAndTap("radial.reset", "自訂工具列裡找不到「還原工具盤預設」")
        tap("toolbar.done", "自訂工具列沒有完成鈕")
        let sheet = element("toolbar.customization.list")
        _ = sheet.waitForNonExistence(timeout: 5)
    }

    private func eraserJourney() {
        openInkNotebook()
        tap("editor.ink.pen", "工具列上找不到鋼筆")
        let before = drawOneStroke(atHeight: 0.42)

        tap("editor.ink.eraser", "工具列上找不到橡皮擦")
        stroke(atHeight: 0.42)
        XCTAssertLessThanOrEqual(strokes(), before, "工具列選了橡皮擦，畫過那一筆應該擦掉它，而不是多畫一筆")
    }

    func testEraserPickedFromTheToolbarReallyErases() throws {
        eraserJourney()
    }

    /// P0: Apple 連續頁面模式也跑一條橡皮擦旅程（Android 已兩種模式都跑）。
    func testEraserPickedFromTheToolbarReallyErases_continuousPages() throws {
        openInkNotebook()
        let modeBtn = element("editor.page.display_mode")
        XCTAssertTrue(modeBtn.waitForExistence(timeout: 8), "找不到版面切換按鈕")
        modeBtn.tap()
        Thread.sleep(forTimeInterval: 1.0)

        tap("editor.ink.pen", "工具列上找不到鋼筆")
        let before = drawOneStroke(atHeight: 0.42)

        tap("editor.ink.eraser", "工具列上找不到橡皮擦")
        stroke(atHeight: 0.42)
        XCTAssertLessThanOrEqual(strokes(), before, "連續模式下工具列選了橡皮擦，畫過那一筆應該擦掉它")

        // 復原為單頁模式
        modeBtn.tap()
        Thread.sleep(forTimeInterval: 0.5)
    }

    func testCustomizedRadialMenuIsWhatTheMenuShows() throws {
        openInkNotebook()
        tap("editor.ink.pen", "工具列上找不到鋼筆")
        let before = drawOneStroke(atHeight: 0.58)

        // 設定：拿掉第一格（鋼筆，出廠預設八格之首）。
        tap("editor.more", "找不到「更多」選單")
        tap("editor.customize_toolbar", "「更多」選單裡找不到自訂工具列")
        scrollAndTap("radial.slot.0.remove", "自訂工具列裡找不到飛梭工具盤的槽位")
        tap("toolbar.done", "自訂工具列沒有完成鈕")
        let sheet = element("toolbar.customization.list")
        _ = sheet.waitForNonExistence(timeout: 5)

        // 叫出工具盤：拿掉的那一格不在，其餘照舊。
        tap("editor.radial_toggle", "工具列上找不到飛梭工具盤按鈕")
        XCTAssertTrue(element("radial.eraser").waitForExistence(timeout: 5), "工具盤上應該還有橡皮擦")
        let pen = element("radial.pen")
        XCTAssertFalse(pen.exists, "拿掉的鋼筆不該再出現在工具盤上")

        // 選工具盤上的橡皮擦：與工具列同一條路，真的會擦。
        let eraser = element("radial.eraser")
        XCTAssertTrue(eraser.waitForExistence(timeout: 5), "飛梭工具盤上找不到橡皮擦")
        eraser.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 1.5)
        stroke(atHeight: 0.58)
        XCTAssertLessThanOrEqual(strokes(), before, "從飛梭工具盤選了橡皮擦，畫過那一筆應該擦掉它")

        // 設定跟著帳號跑：測完還原，不然下一個測試（或開發者自己的裝置）工具盤就少一格。
        resetRadialFromSettings()
    }
}
