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

        guard openSeedNotebook(app) else { return }
        guard element(app, "editor.more").waitForExistence(timeout: 15) else {
            XCTFail("進不到編輯器")
            return
        }

        let window = app.windows.firstMatch.frame
        var problems: [String] = []

        for sheet in Self.sheets {
            element(app, "editor.more").tap()
            let item = app.buttons[sheet.menuLabel].firstMatch
            _ = item.waitForExistence(timeout: 3)
                // 點得到才算數：只露一角的項目 `exists` 是 true，
                // 但點擊落在畫面外 —— 不報錯，卻什麼也沒發生。
            for _ in 0..<6 where !item.isHittable { app.swipeUp() }
            guard item.isHittable else {
                problems.append("\(sheet.menuLabel)：選單裡點不到")
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

    /// 編輯器在這個尺寸（與方向）下：不能沒有的控制項都完整在畫面上、點得到；
    /// 打字工具列、框選工具列出得來、點得到；打字時鍵盤不蓋住正在打的文字方塊。
    ///
    /// 每一步存一張截圖（`XCTAttachment`），給人眼看排版。
    func testEditorChromeFitsTheScreen() {
        let app = XCUIApplication()
        app.launchEnvironment["KAIRUMO_UITEST"] = "1"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        let newNote = element(app, "home.action.new_note")
        guard newNote.waitForExistence(timeout: 15) else { return XCTFail("首頁找不到新增筆記") }
        shot(app, "1-home")
        newNote.tap()
        let confirm = element(app, "new_notebook.confirm")
        guard confirm.waitForExistence(timeout: 10) else { return XCTFail("新增筆記表單沒有確認鈕") }
        confirm.tap()
        guard element(app, "editor.more").waitForExistence(timeout: 15) else { return XCTFail("進不到編輯器") }
        sleep(1)

        var problems: [String] = []
        let orientations: [UIDeviceOrientation] = UIDevice.current.userInterfaceIdiom == .pad
            ? [.portrait, .landscapeLeft] : [.portrait]
        for orientation in orientations {
            XCUIDevice.shared.orientation = orientation
            sleep(1)
            let tag = orientation == .portrait ? "portrait" : "landscape"
            problems += auditEditor(app, tag: tag)
        }
        XCUIDevice.shared.orientation = .portrait

        XCTAssertTrue(
            problems.isEmpty,
            "編輯器在這個尺寸下有問題：\n" + problems.joined(separator: "\n"))
    }

    private func auditEditor(_ app: XCUIApplication, tag: String) -> [String] {
        var problems: [String] = []
        func mustFit(_ ids: [String], _ step: String) {
            let window = app.windows.firstMatch.frame
            for id in ids {
                let e = element(app, id)
                guard e.exists else { problems.append("[\(tag)] \(step) → \(id)：不存在"); continue }
                if !window.contains(e.frame) {
                    problems.append("[\(tag)] \(step) → \(id)：被切掉（元素 \(e.frame)，視窗 \(window)）")
                } else if !e.isHittable {
                    problems.append("[\(tag)] \(step) → \(id)：在畫面上卻點不到（被蓋住）")
                }
            }
        }

        // 1. 手繪模式：離開、模式切換、更多、復原／重做。
        if element(app, "portal.draw").exists { element(app, "portal.draw").tap(); sleep(1) }
        shot(app, "2-draw-\(tag)")
        mustFit(["editor.home", "editor.more", "portal.draw", "portal.type"], "手繪模式")
        // 復原：至少要有一顆**不用捲就看得到、點得到**的（頂列或筆具列都可以）。
        // 手機上筆具列是一條左右捲的列，它那一顆可能在捲動範圍的另一端 —— 那沒關係，
        // 只要頂列那一顆在畫面上。
        let window = app.windows.firstMatch.frame
        let visibleUndo = ["editor.compact.undo", "editor.ink.undo"].contains { id in
            let e = element(app, id)
            return e.exists && window.contains(e.frame) && e.isHittable
        }
        if !visibleUndo { problems.append("[\(tag)] 手繪模式 → 沒有一顆復原鈕是看得到、點得到的") }

        // 2. 打字模式：工具列出得來；點畫布開始打字時，鍵盤不能蓋住文字方塊。
        element(app, "portal.type").tap()
        sleep(1)
        shot(app, "3-type-\(tag)")
        mustFit(["editor.home", "editor.more", "editor.text.add_box"], "打字模式")
        let canvas = app.descendants(matching: .any).matching(identifier: "editor.canvas").firstMatch
        if canvas.exists {
            // 點在頁面**看得到的那一段**裡：橫向時頁面比螢幕高，按頁面比例算的點可能落在畫面外。
            let window = app.windows.firstMatch.frame
            let visible = canvas.frame.intersection(window)
            let point = CGPoint(x: visible.minX + visible.width * 0.4, y: visible.minY + min(160, visible.height * 0.35))
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point.x, dy: point.y)).tap()
            let editor = app.descendants(matching: .any).matching(identifier: "editor.text.inline_editor").firstMatch
            if editor.waitForExistence(timeout: 5) {
                editor.typeText("Responsive")
                sleep(1)
                shot(app, "4-typing-\(tag)")
                let keyboard = app.keyboards.firstMatch
                if keyboard.exists, keyboard.frame.height > 0, editor.frame.maxY > keyboard.frame.minY + 2 {
                    problems.append("[\(tag)] 打字 → 文字方塊被鍵盤蓋住（方塊 \(editor.frame)，鍵盤 \(keyboard.frame)）")
                }
            } else {
                problems.append("[\(tag)] 打字 → 點畫布沒有出現就地編輯器")
            }
        }

        // 3. 框選：工具列的全選、連續框選點得到（可以捲動，但要捲得到）。
        element(app, "portal.draw").tap()
        sleep(1)
        element(app, "editor.more").tap()
        let marquee = element(app, "editor.insert.marquee")
        if marquee.waitForExistence(timeout: 3) {
            for _ in 0..<6 where !marquee.isHittable { app.swipeUp() }
            if marquee.isHittable {
                marquee.tap()
                sleep(1)
                shot(app, "5-marquee-\(tag)")
                let window = app.windows.firstMatch.frame
                for id in ["editor.marquee.continuous", "editor.marquee.select_all"] {
                    let e = element(app, id)
                    if !e.exists { problems.append("[\(tag)] 框選 → \(id)：不存在"); continue }
                    // 完全在畫面外的元素問 isHittable 會直接拋錯 —— 先看位置。
                    if !window.contains(e.frame) {
                        problems.append("[\(tag)] 框選 → \(id)：一開始不在畫面上，要左右捲才找得到（\(e.frame)）")
                        let bar = app.scrollViews.containing(.button, identifier: id).firstMatch
                        for _ in 0..<4 where bar.exists && !window.contains(e.frame) { bar.swipeLeft() }
                        if !window.contains(e.frame) { problems.append("[\(tag)] 框選 → \(id)：捲了也找不到") }
                    }
                }
            } else {
                problems.append("[\(tag)] 更多選單裡點不到「框選」")
                app.tap()
            }
        } else {
            problems.append("[\(tag)] 更多選單沒有「框選」")
        }
        // 離開框選（再按一次選單裡的「框選」），回到乾淨狀態 —— 不離開的話，
        // 下一個方向的檢查一開始就停在框選模式，點畫布會被框選層接走。
        element(app, "editor.more").tap()
        let exitMarquee = element(app, "editor.insert.marquee")
        if exitMarquee.waitForExistence(timeout: 3) {
            for _ in 0..<6 where !exitMarquee.isHittable { app.swipeUp() }
            if exitMarquee.isHittable { exitMarquee.tap() } else { app.tap() }
        }
        sleep(1)
        if element(app, "portal.draw").exists { element(app, "portal.draw").tap() }
        return problems
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(UIDevice.current.name)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        // 結果包存不下來時（Xcode 有時寫不出 xcresult）也要看得到截圖：
        // 以 `TEST_RUNNER_KAIRUMO_SHOT_DIR` 指定一個資料夾，直接寫成 PNG。
        if let dir = ProcessInfo.processInfo.environment["KAIRUMO_SHOT_DIR"] {
            let safe = "\(UIDevice.current.name)-\(name)".replacingOccurrences(of: " ", with: "_")
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(safe).png"))
        }
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
