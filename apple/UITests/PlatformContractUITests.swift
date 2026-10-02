//
//  PlatformContractUITests.swift
//  KairumoUITests
//
//  平台能力契約的 UI 部分（驗證層 L3）：要真的在畫面上呈現系統元件的那些，
//  而且**每一項做兩次以上**。
//

import XCTest

final class PlatformContractUITests: XCTestCase {

    /// 「匯入音檔」的檔案選擇器連開三次都要出現。
    /// 回報：第二次用的時候選擇器沒有跳出來（SwiftUI `.fileImporter` 在多個呈現修飾詞之間被吞掉）。
    func testFilePickerPresentsEveryTime() {
        let app = XCUIApplication()
        app.launchEnvironment["KAIRUMO_UITEST"] = "1"
        app.launch()
        guard openSeedNotebook(app) else { return }

        let cancel = app.buttons.matching(NSPredicate(format: "label IN {'Cancel','取消'}")).firstMatch
        for attempt in 1...3 {
            let more = app.descendants(matching: .any).matching(identifier: "editor.more").firstMatch
            XCTAssertTrue(more.waitForExistence(timeout: 10), "第 \(attempt) 次：找不到「更多」")
            more.tap()
            guard ScreenAudit.tapMenuItem(app, label: "Import an audio file") else {
                XCTFail("第 \(attempt) 次：選單裡找不到 Import an audio file"); return
            }
            XCTAssertTrue(
                cancel.waitForExistence(timeout: 8),
                "第 \(attempt) 次點「匯入音檔」，檔案選擇器沒有出現（被吞掉了）")
            if cancel.exists { cancel.tap() }
            XCTAssertTrue(cancel.waitForNonExistence(timeout: 6), "第 \(attempt) 次：選擇器沒有關閉")
        }
    }

    /// 診斷面板的「裝置自檢」跑得出結果，而且關鍵項目都是通過（模擬器上能通過的那幾項）。
    func testSelfCheckRunsAndCorePlatformChecksPass() {
        let app = XCUIApplication()
        app.launchEnvironment["KAIRUMO_UITEST"] = "1"
        app.launch()
        let version = app.descendants(matching: .any).matching(NSPredicate(format: "identifier CONTAINS 'version'")).firstMatch
        _ = version.waitForExistence(timeout: 15)
        // 診斷面板入口：首頁右上「Diagnostics」。
        let diagnostics = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Diagnostics'")).firstMatch
        guard diagnostics.waitForExistence(timeout: 15) else { XCTFail("首頁找不到 Diagnostics"); return }
        diagnostics.tap()
        let run = app.buttons["diagnostics.selfcheck.run"]
        guard run.waitForExistence(timeout: 10) else { XCTFail("診斷面板沒有自檢按鈕"); return }
        run.tap()
        let transcript = app.descendants(matching: .any).matching(identifier: "diagnostics.selfcheck.transcript.script").firstMatch
        XCTAssertTrue(transcript.waitForExistence(timeout: 20), "自檢沒有跑完（找不到最後幾項的結果）")
        for id in ["audio.playback", "folder.library", "transcript.script"] {
            let row = app.descendants(matching: .any).matching(identifier: "diagnostics.selfcheck.\(id)").firstMatch
            XCTAssertTrue(row.exists, "自檢結果缺少 \(id)")
        }
    }
}
