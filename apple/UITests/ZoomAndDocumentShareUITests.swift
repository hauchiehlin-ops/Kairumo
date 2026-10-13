//
//  ZoomAndDocumentShareUITests.swift
//  KairumoUITests
//
//  兩個「按鈕有沒有接上」的真實流程：
//  1. 畫布區的「顯示比例」選單：顯示全頁、實際大小，倍率要真的變。
//  2. 手冊與隱私權政策的「分享、匯出或列印」：選單出得來，匯出 PDF 會叫出系統分享表。

import XCTest

final class ZoomAndDocumentShareUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["KAIRUMO_UITEST"] = "1"
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        continueAfterFailure = false
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// 整頁的顯示比例：顯示全頁、50%、符合頁寬，畫布（整頁）的尺寸要真的跟著變。
    func testZoomMenuResizesTheWholePage() {
        let app = launch()
        guard openSeedNotebook(app) else { return }
        let canvas = app.scrollViews.matching(identifier: "editor.canvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 15), "找不到畫布")

        let menu = element(app, "editor.zoom.menu")
        XCTAssertTrue(menu.waitForExistence(timeout: 10), "頂端列沒有「畫布縮放」選單")

        func choose(_ id: String, title: String? = nil) {
            menu.tap()
            let item = title.map { app.buttons[$0].firstMatch } ?? element(app, id)
            XCTAssertTrue(item.waitForExistence(timeout: 5), "選單裡沒有 \(title ?? id)")
            item.tap()
            sleep(1)
        }

        choose("editor.zoom.fit_page")
        let whole = canvas.frame.width
        XCTAssertGreaterThan(whole, 50)

        choose("", title: "50%")
        let half = canvas.frame.width
        XCTAssertEqual(half, whole * 0.5, accuracy: whole * 0.08, "選 50% 之後整頁的寬度應該是全頁的一半（全頁 \(whole)，50% \(half)）")

        choose("editor.zoom.fit_width")
        let fitWidth = canvas.frame.width
        XCTAssertGreaterThanOrEqual(fitWidth, whole - 1, "「符合頁寬」不該比「顯示全頁」窄")
    }

    func testDocumentsCanBeExportedAndPrinted() {
        let app = launch()
        let manual = app.buttons["home.docs.manual"].firstMatch
        XCTAssertTrue(manual.waitForExistence(timeout: 10), "首頁找不到「操作手冊」入口")
        manual.tap()

        let share = element(app, "document.share.menu")
        XCTAssertTrue(share.waitForExistence(timeout: 10), "手冊視窗沒有「分享、匯出或列印」")
        sleep(3) // 等網頁載完，才有東西可以排版成 PDF
        share.tap()
        XCTAssertTrue(element(app, "document.print").waitForExistence(timeout: 5), "選單裡沒有「列印」")
        let export = element(app, "document.export.pdf")
        XCTAssertTrue(export.waitForExistence(timeout: 5), "選單裡沒有「匯出為 PDF」")
        export.tap()

        // 系統分享表（UIActivityViewController）
        let sheet = app.otherElements["ActivityListView"]
        let failedAlert = app.alerts.firstMatch
        let appeared = sheet.waitForExistence(timeout: 15)
        XCTAssertFalse(failedAlert.exists, "匯出 PDF 失敗的提示出現了")
        XCTAssertTrue(appeared, "匯出 PDF 之後沒有出現系統分享表")
    }
}
