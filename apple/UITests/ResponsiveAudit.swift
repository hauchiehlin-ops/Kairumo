//
//  ResponsiveAudit.swift
//  KairumoUITests
//
//  響應式版面：每一張表在這個尺寸下，該按的按鈕都完整在視窗裡。
//
//  # 為什麼要量座標，不是看截圖
//
//  使用者的要求是「務必讓使用者在操作上沒有看不到、點不到的情況」。
//  那兩件事**截圖最容易漏掉** —— 一個被螢幕邊緣切掉一半的確認鈕，
//  在截圖上看起來完全正常，直到有人真的去按它。
//
//  實測過的例子：「更多」選單最下面四項在 iPhone 17 Pro 上被視窗下緣
//  切掉，在 18 Pro 上完全正常（S-261d）。同一份程式碼、兩種尺寸、
//  兩種結果 —— 而那個差別只有量座標看得出來。
//
//  # 這條測試怎麼判定
//
//  「完整在視窗裡」：`visible.contains(element.frame)`，不是 `intersects`。
//  有重疊就放行的話，被邊緣切掉一半的按鈕會通過 —— 而那正是使用者
//  按不到的那一種。
//

import XCTest

final class ResponsiveAudit: XCTestCase {

    /// 每張表打開之後，必須**完整可見**的那些控制項。
    ///
    /// 只列關閉／確認這類「不按就出不去」的 —— 內容區被切掉可以捲，
    /// 但出不去的表單是死路。
    private static let sheets: [(menuLabel: String, mustFit: [String])] = [
        ("Asset Library", ["assets.close"]),
        ("Sticker Library", ["stickers.cancel", "stickers.tab"]),
        ("Math Calculator", ["math.close"]),
        ("Chart Studio", ["chart.close"]),
        ("Insert 3D Model", ["model3d.close", "model3d.import"]),
        ("Theme Tools", ["theme.close"]),
    ]

    func testEverySheetFitsTheScreen() {
        let app = XCUIApplication()
        app.launchEnvironment["KAIRUMO_UITEST"] = "1"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        let card = app.staticTexts["Welcome to Kairumo"].firstMatch
        guard card.waitForExistence(timeout: 10) else {
            XCTFail("首頁找不到種子筆記")
            return
        }
        card.tap()
        guard element(app, "editor.more").waitForExistence(timeout: 15) else {
            XCTFail("進不到編輯器")
            return
        }

        let window = app.windows.firstMatch.frame
        var problems: [String] = []

        for sheet in Self.sheets {
            element(app, "editor.more").tap()
            let item = app.buttons[sheet.menuLabel].firstMatch
            if !item.waitForExistence(timeout: 3) {
                for _ in 0..<6 where !item.exists { app.swipeUp() }
            }
            guard item.exists else {
                problems.append("\(sheet.menuLabel)：選單裡找不到")
                app.tap()
                continue
            }
            item.tap()

            for id in sheet.mustFit {
                let element = element(app, id)
                guard element.waitForExistence(timeout: 5) else {
                    problems.append("\(sheet.menuLabel) → \(id)：不存在")
                    continue
                }
                // **完整包含**，不是有重疊。被邊緣切掉一半的按鈕
                // `intersects` 會過，而那正是使用者按不到的那一種。
                if !window.contains(element.frame) {
                    problems.append(
                        "\(sheet.menuLabel) → \(id)：被切掉了"
                        + "（元素 \(element.frame)，視窗 \(window)）")
                } else if !element.isHittable {
                    problems.append("\(sheet.menuLabel) → \(id)：完整在畫面上卻點不到")
                }
            }
            dismiss(app)
        }

        XCTAssertTrue(
            problems.isEmpty,
            "這些控制項在這個尺寸下有問題：\n" + problems.joined(separator: "\n"))
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

    private func dismiss(_ app: XCUIApplication) {
        for id in ["assets.close", "stickers.cancel", "math.close",
                   "chart.close", "theme.close", "model3d.close"] {
            let b = element(app, id)
            if b.exists && b.isHittable { b.tap(); return }
        }
        app.swipeDown()
    }
}
