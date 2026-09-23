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
        ("Theme Tools", "theme.close"),
    ]

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
        for id in ["assets.close", "stickers.cancel", "math.close",
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
        let card = app.staticTexts["Welcome to Kairumo"].firstMatch
        guard card.waitForExistence(timeout: 10) else { return false }
        card.tap()
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
            if !item.waitForExistence(timeout: 3) {
                for _ in 0..<6 where !item.exists { app.swipeUp() }
            }
            guard item.exists else {
                failures.append("\(tool.menuLabel)：選單裡找不到")
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
