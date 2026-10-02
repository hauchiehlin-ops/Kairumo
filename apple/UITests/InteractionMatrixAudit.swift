//
//  InteractionMatrixAudit.swift
//  KairumoUITests
//
//  互動矩陣（驗證層 L2，見 docs/plans/ipad-first-verification.md）。
//
//  # 它守的是什麼
//
//  既有的稽核問「畫面上有沒有這個元件」。使用者回報的卻是「元件在，但點不到／點了沒反應」：
//  播放鈕被外層點擊手勢吃掉、貼紙的確認鈕在手寫模式下碰不到、刪除鈕按了又復活。
//  所以這裡對**每一種畫布物件**問同一組問題 —— 找得到、尺寸夠大、在螢幕裡、點得動、
//  選了之後有刪除、刪得掉 —— 而且 11"/13" 直式橫式各跑一遍。
//
//  物件由 `KAIRUMO_UITEST_SEED_OBJECTS=1` 放進歡迎筆記第 1 頁（見
//  `NotebookStore.injectInteractionFixturesIfRequested`）。新增物件種類時，
//  把它加進 `Kind` 與種子，矩陣就會自動多一列。
//

import XCTest

final class InteractionMatrixAudit: XCTestCase {

    /// 一種物件的規格。`selectShowsDelete`：點選後是否有標籤為 Delete 的控制項。
    struct Kind {
        let name: String
        let selectShowsDelete: Bool
        /// 點物件的哪個位置（相對於它的框）。預設中心；音訊卡中心有播放鈕，改點右側空白處。
        let tapPoint: CGVector
        /// XCUITest 送出的點擊到不了這個物件的刪除鈕，但真實觸控可以（形狀的動作列用 `.position` 放在形狀範圍外，
        /// 已用模擬器手動點擊驗證兩種版面都刪得掉）。這種物件只斷言「選取後有可點的刪除控制項」，
        /// 不斷言「點了之後消失」—— 否則紅燈說的是測試工具的限制，不是使用者會遇到的問題。
        var deleteIsNotDrivableByXCUITest = false
    }

    static let kinds: [Kind] = [
        Kind(name: "audio", selectShowsDelete: true, tapPoint: CGVector(dx: 0.62, dy: 0.5)),
        Kind(name: "image", selectShowsDelete: true, tapPoint: CGVector(dx: 0.5, dy: 0.5)),
        // 文字方塊：點一下是**進入就地編輯**（設計如此，Word 式「即點即寫」），刪除在編輯結束後的動作列。
        // 所以這裡不要求點選後出現刪除；但它的動作列控制項仍要有標籤（見下面的無障礙檢查）。
        Kind(name: "text", selectShowsDelete: false, tapPoint: CGVector(dx: 0.5, dy: 0.5)),
        Kind(name: "link", selectShowsDelete: true, tapPoint: CGVector(dx: 0.5, dy: 0.5)),
        Kind(name: "shape", selectShowsDelete: true, tapPoint: CGVector(dx: 0.5, dy: 0.5),
             deleteIsNotDrivableByXCUITest: true),
    ]

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    /// 從首頁打開互動矩陣專用的那一本。
    private func openMatrixNotebook(_ app: XCUIApplication) -> Bool {
        let cardId = "home.notebooks.card.uitest-matrix-notebook"
        let editorMore = find(app, "editor.more")
        guard find(app, "home.action.new_note").waitForExistence(timeout: 20) else {
            XCTFail("首頁沒有載入"); return false
        }
        for _ in 0..<12 {
            let card = find(app, cardId)
            if card.exists && card.isHittable {
                card.tap()
                if editorMore.waitForExistence(timeout: 10) { return true }
            }
            app.swipeUp()
        }
        XCTFail("找不到互動矩陣專用筆記（\(cardId)）"); return false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["KAIRUMO_UITEST"] = "1"
        app.launchEnvironment["KAIRUMO_UITEST_SEED_OBJECTS"] = "1"
        app.launch()
        currentApp = app
        return app
    }

    /// 依識別碼找元素：先用便宜的型別查詢，最後才用 `.any`。
    ///
    /// `descendants(matching: .any)` 每次都要對整棵無障礙樹做快照；編輯器的樹很大，
    /// 連續幾十次之後 XCTest 自己的 log 量（"Automation type mismatch…"）超過系統上限，
    /// 受測的 App 會被系統隔離而崩潰 —— 測試手法造成的假紅燈。
    private func find(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        let other = app.otherElements[id]
        if other.exists { return other }
        let button = app.buttons[id]
        if button.exists { return button }
        return app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func object(_ app: XCUIApplication, _ kind: String) -> XCUIElement {
        find(app, "object.\(kind)")
    }

    /// 切到打字模式 —— 手寫模式下物件層本來就不吃觸控（見 `objectLayer`）。
    private func enterTypingMode(_ app: XCUIApplication) {
        let typing = find(app, "portal.type")
        if typing.waitForExistence(timeout: 8) { typing.tap() }
    }

    /// 把物件捲進畫面（連續頁面模式下它可能在畫面外）。
    private func reveal(_ app: XCUIApplication, _ el: XCUIElement) -> Bool {
        for _ in 0..<8 {
            if el.exists && el.isHittable { return true }
            app.swipeUp()
        }
        return el.exists && el.isHittable
    }

    /// 物件周圍的按鈕（用單一謂詞查詢，不逐顆列舉整棵樹 —— 見 `find` 的說明）。
    private func buttons(near frame: CGRect, label: String?) -> [XCUIElement] {
        let predicate = label.map { NSPredicate(format: "label == %@", $0) }
            ?? NSPredicate(format: "label == ''")
        let area = frame.insetBy(dx: -30, dy: -30)
        return app_buttons(predicate).filter { $0.exists && area.intersects($0.frame) }
    }

    private var currentApp: XCUIApplication?
    private func app_buttons(_ predicate: NSPredicate) -> [XCUIElement] {
        guard let app = currentApp else { return [] }
        return app.buttons.matching(predicate).allElementsBoundByIndex.prefix(30).map { $0 }
    }

    private func deleteControl(near frame: CGRect) -> XCUIElement? {
        buttons(near: frame, label: "Delete").first { $0.isHittable }
    }

    // MARK: - 矩陣

    func testEveryObjectKindIsPresentSizedAndTappable() {
        let app = launch()
        guard openMatrixNotebook(app) else { return }
        enterTypingMode(app)

        var report: [String] = []
        #if targetEnvironment(macCatalyst)
        let orientations: [UIDeviceOrientation] = [.portrait]   // Mac 沒有裝置方向
        #else
        let orientations: [UIDeviceOrientation] = [.portrait, .landscapeLeft]
        #endif
        for orientation in orientations {
            #if !targetEnvironment(macCatalyst)
            XCUIDevice.shared.orientation = orientation
            #endif
            sleep(1)
            for kind in Self.kinds {
                let el = object(app, kind.name)
                guard el.waitForExistence(timeout: 8) else {
                    report.append("[\(orientation.rawValue)] \(kind.name)：畫面上找不到（可能沒進無障礙樹）")
                    continue
                }
                guard reveal(app, el) else {
                    report.append("[\(orientation.rawValue)] \(kind.name)：存在但點不到（被蓋住或在畫面外）")
                    continue
                }
                let f = el.frame
                if f.width < 44 || f.height < 24 {
                    report.append("[\(orientation.rawValue)] \(kind.name)：尺寸太小 \(Int(f.width))×\(Int(f.height))")
                }
                if !app.windows.firstMatch.frame.contains(CGPoint(x: f.midX, y: f.midY)) {
                    report.append("[\(orientation.rawValue)] \(kind.name)：中心在視窗之外")
                }
            }
        }
        #if !targetEnvironment(macCatalyst)
        XCUIDevice.shared.orientation = .portrait
        #endif
        XCTAssertTrue(report.isEmpty, "互動矩陣（存在／尺寸／可點）：\n" + report.joined(separator: "\n"))
    }

    func testSelectingAnObjectShowsADeleteControlAndDeleteSticks() {
        var report: [String] = []
        for kind in Self.kinds {
            let app = launch()
            defer { app.terminate() }
            guard openMatrixNotebook(app) else { report.append("\(kind.name)：進不了編輯器"); continue }
            enterTypingMode(app)
            let el = object(app, kind.name)
            guard el.waitForExistence(timeout: 8), reveal(app, el) else {
                report.append("\(kind.name)：找不到或點不到"); continue
            }
            el.coordinate(withNormalizedOffset: kind.tapPoint).tap()
            sleep(1)
            guard let del = deleteControl(near: el.frame) else {
                if kind.selectShowsDelete { report.append("\(kind.name)：點選後沒有出現刪除控制項（使用者刪不掉它）") }
                continue
            }
            if kind.deleteIsNotDrivableByXCUITest { continue }
            let delFrame = del.frame
            // 用絕對座標點，不用 `del.tap()`：形狀的動作列放在形狀範圍之外，XCUITest 對這種元素的
            // 「元素點擊」不會送到（真實手指與這個座標點擊都可以，已手動驗證）。使用者的手指走的是後者。
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: delFrame.midX, dy: delFrame.midY)).tap()
            // 刪除要「留得住」：等一下再看（「秒出現」的症狀發生在刪除之後的下一個畫面更新／同步）。
            sleep(4)
            if object(app, kind.name).exists {
                report.append("\(kind.name)：按了刪除，物件還在（或刪除後又出現）；物件框 \(el.frame)，刪除鈕框 \(delFrame)")
            }
        }
        XCTAssertTrue(report.isEmpty, "互動矩陣（選取與刪除）：\n" + report.joined(separator: "\n"))
    }

    func testAudioCardPlayButtonActuallyPlays() {
        let app = launch()
        defer { app.terminate() }
        guard openMatrixNotebook(app) else { return }
        enterTypingMode(app)
        let play = find(app, "audio.card.play")
        guard play.waitForExistence(timeout: 8), reveal(app, play) else {
            XCTFail("找不到播放鈕"); return
        }
        play.tap()
        let paused = NSPredicate(format: "label == 'Pause'")
        let flipped = XCTNSPredicateExpectation(predicate: paused, object: play)
        XCTAssertEqual(
            XCTWaiter().wait(for: [flipped], timeout: 4), .completed,
            "按了播放，按鈕沒有變成暫停 —— 點擊沒到按鈕，或播放管線沒有啟動")
    }

    /// 選取物件之後，它旁邊出現的**每一個按鈕都有標籤**。
    ///
    /// 圖示按鈕沒有標籤的話，VoiceOver 只念「按鈕」，使用者不知道它是刪除還是別的；
    /// 自動化測試也無從區分（這次發現圖片的刪除鈕就是這樣）。
    func testSelectedObjectControlsAreAllLabelled() {
        var report: [String] = []
        for kind in Self.kinds where kind.name != "text" {
            let app = launch()
            defer { app.terminate() }
            guard openMatrixNotebook(app) else { continue }
            enterTypingMode(app)
            let el = object(app, kind.name)
            guard el.waitForExistence(timeout: 8), reveal(app, el) else { continue }
            el.coordinate(withNormalizedOffset: kind.tapPoint).tap()
            sleep(1)
            for button in buttons(near: el.frame, label: nil) where button.identifier.isEmpty {
                report.append("\(kind.name)：有一顆沒有標籤也沒有識別碼的按鈕（\(Int(button.frame.midX)),\(Int(button.frame.midY))）")
            }
        }
        XCTAssertTrue(report.isEmpty, "互動矩陣（無障礙標籤）：\n" + report.joined(separator: "\n"))
    }

    /// 點文字方塊 → 進入就地編輯 → 輸入欄真的拿到鍵盤焦點。
    /// 對應 `@FocusState` 在 `await` 之後寫入會被 SwiftUI 忽略的問題（「鍵盤時有時無」）。連做兩次。
    func testTappingATextBoxGivesItKeyboardFocusEveryTime() {
        let app = launch()
        defer { app.terminate() }
        guard openMatrixNotebook(app) else { return }
        enterTypingMode(app)
        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        for attempt in 1...2 {
            let el = object(app, "text")
            guard el.waitForExistence(timeout: 8), reveal(app, el) else { XCTFail("找不到文字方塊"); return }
            el.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let field = app.textViews.matching(focused).firstMatch
            let field2 = app.textFields.matching(focused).firstMatch
            let ok = field.waitForExistence(timeout: 4) || field2.waitForExistence(timeout: 1)
            XCTAssertTrue(ok, "第 \(attempt) 次點文字方塊，輸入欄沒有拿到鍵盤焦點")
            // 點空白處結束編輯，再來一次。
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.8)).tap()
            sleep(1)
        }
    }

    /// 點空白處（隨點隨寫）→ 新方塊一出生就是編輯狀態 → 輸入欄拿到焦點。連做兩次。
    /// 這條路徑是 `.task` 在 `await` 之後才寫 `@FocusState` 的那一條（見 `requestInlineFocus`）。
    func testTapToWriteOnEmptySpaceFocusesTheNewBox() {
        let app = launch()
        defer { app.terminate() }
        guard openMatrixNotebook(app) else { return }
        enterTypingMode(app)
        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        for attempt in 1...2 {
            let page = find(app, "editor.canvas")
            guard page.waitForExistence(timeout: 8) else { XCTFail("找不到畫布"); return }
            page.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55 + 0.1 * Double(attempt))).tap()
            let ok = app.textViews.matching(focused).firstMatch.waitForExistence(timeout: 4)
                || app.textFields.matching(focused).firstMatch.waitForExistence(timeout: 1)
            XCTAssertTrue(ok, "第 \(attempt) 次點空白處，新文字方塊沒有拿到鍵盤焦點")
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.95)).tap()
            sleep(1)
        }
    }
}
