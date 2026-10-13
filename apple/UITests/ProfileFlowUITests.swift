//
//  ProfileFlowUITests.swift
//  KairumoUITests
//
//  多設定檔（使用者）的**真實流程**：在模擬器上把 App 跑起來，從首頁的「切換使用者」開始，
//  建立使用者、設 PIN、切過去、切回來、被鎖擋住、刪除。
//
//  單元測試驗得出規則與引擎，驗不出「按鈕有沒有接上、畫面有沒有出來、切換之後首頁有沒有換成另一個人」——
//  那一層只有把 App 真的跑起來才看得到。

import XCTest

final class ProfileFlowUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["KAIRUMO_UITEST"] = "1"
        // 每個測試從「只有預設使用者」開始，不受上一輪留下的使用者影響。
        app.launchEnvironment["KAIRUMO_UITEST_RESET_PROFILES"] = "1"
        // 模擬器上未簽署的建置沒有 Keychain 權限：PIN 改存記憶體（產品環境存 Keychain）。
        app.launchEnvironment["KAIRUMO_UITEST_MEMORY_SECRETS"] = "1"
        // 模擬器的軟鍵盤可能是注音：英文名字會變成注音候選字。固定用英文鍵盤。
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                                "-AppleKeyboards", "(en_US@sw=QWERTY;hw=Automatic)"]
        continueAfterFailure = false
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func openPicker(_ app: XCUIApplication) {
        let button = element(app, "home.profile.switch")
        XCTAssertTrue(button.waitForExistence(timeout: 20), "首頁沒有「切換使用者」按鈕")
        button.tap()
        XCTAssertTrue(element(app, "profile.picker").waitForExistence(timeout: 10), "切換選單沒有出現")
    }

    /// 在選單裡建立一位使用者並切過去。回傳之後首頁橫幅上的名字應該是它。
    private func createUser(_ app: XCUIApplication, name: String, pin: String? = nil) {
        element(app, "profile.add").tap()
        let nameField = app.textFields["profile.create.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10), "新增畫面沒有名稱欄位")
        nameField.tap()
        nameField.typeText(name)
        if let pin {
            // 表單裡的 Toggle：點元素正中央點到的是文字標籤，不會切換。點最右邊的開關本體。
            let toggle = app.switches["profile.create.lock"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 5), "新增畫面沒有 PIN 開關")
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
            let pinField = app.secureTextFields["profile.create.pin"]
            XCTAssertTrue(pinField.waitForExistence(timeout: 5))
            pinField.tap()
            pinField.typeText(pin)
            let confirm = app.secureTextFields["profile.create.pin2"]
            confirm.tap()
            confirm.typeText(pin)
        }
        element(app, "profile.create.confirm").tap()
    }

    private func waitForHome(_ app: XCUIApplication, showing name: String, file: StaticString = #filePath, line: UInt = #line) {
        // 切換期間是等待畫面，之後整棵重建回首頁。
        XCTAssertTrue(
            app.staticTexts[name].firstMatch.waitForExistence(timeout: 30),
            "切換之後首頁沒有出現「\(name)」", file: file, line: line)
        XCTAssertTrue(element(app, "home.profile.switch").waitForExistence(timeout: 20), file: file, line: line)
    }

    func testCreateASecondUserSwitchToItAndBack() {
        let app = launch()
        openPicker(app)
        // 只有預設使用者：一列。
        XCTAssertTrue(element(app, "profile.row.default").exists)

        createUser(app, name: "Alex")
        waitForHome(app, showing: "Alex")

        // 切回預設使用者：選單裡兩列，目前使用中的是 Alex。
        openPicker(app)
        XCTAssertTrue(element(app, "profile.row.default").waitForExistence(timeout: 5))
        element(app, "profile.row.default").tap()
        // 預設使用者的名字是升級前的那個（測試環境下是「You」）。
        waitForHome(app, showing: "You")
    }

    func testALockedUserNeedsItsPINBeforeYouCanSwitchToIt() {
        let app = launch()
        openPicker(app)
        createUser(app, name: "Sam", pin: "2468")
        waitForHome(app, showing: "Sam")

        // 切回預設，再想切到 Sam：要先過 PIN。
        openPicker(app)
        element(app, "profile.row.default").tap()
        waitForHome(app, showing: "You")
        openPicker(app)
        let samRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'profile.row.' AND label CONTAINS 'Sam'")).firstMatch
        XCTAssertTrue(samRow.waitForExistence(timeout: 5), "選單裡找不到 Sam")
        samRow.tap()

        let pinField = app.secureTextFields["profile.unlock.pin"]
        if !pinField.waitForExistence(timeout: 10) {
            let lines = app.debugDescription.split(separator: "\n")
                .filter { $0.contains("identifier: 'profile") || $0.contains("Sheet") || $0.contains("Alert") || $0.contains("Popover") }
                .map { String($0.drop { $0 == " " }.prefix(140)) }
            XCTFail("鎖住的使用者沒有要求 PIN。相關元素：\n" + lines.prefix(60).joined(separator: "\n"))
            return
        }
        // 輸錯：不能切，並且有訊息。
        pinField.tap()
        pinField.typeText("1111")
        element(app, "profile.unlock.button").tap()
        XCTAssertTrue(element(app, "profile.unlock.message").waitForExistence(timeout: 5), "輸錯 PIN 沒有訊息")
        XCTAssertFalse(app.staticTexts["Sam"].firstMatch.waitForExistence(timeout: 1) && element(app, "home.profile.switch").exists
                       && app.staticTexts["You"].exists == false, "輸錯 PIN 不該切過去")
        // 輸對：切過去。
        pinField.tap()
        pinField.typeText("2468")
        element(app, "profile.unlock.button").tap()
        waitForHome(app, showing: "Sam")
    }

    func testDeletingAnInactiveUserRemovesItFromThePicker() {
        let app = launch()
        openPicker(app)
        createUser(app, name: "Temp")
        waitForHome(app, showing: "Temp")
        openPicker(app)
        element(app, "profile.row.default").tap()
        waitForHome(app, showing: "You")

        openPicker(app)
        let manage = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'profile.manage.' AND NOT identifier ENDSWITH '.default'")).firstMatch
        XCTAssertTrue(manage.waitForExistence(timeout: 5))
        manage.tap()
        let delete = element(app, "profile.edit.delete")
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "管理畫面沒有刪除鈕")
        XCTAssertTrue(delete.isEnabled, "沒在使用中的使用者應該可以刪")
        delete.tap()
        app.alerts.buttons.matching(NSPredicate(format: "label CONTAINS 'Delete'")).firstMatch.tap()

        // 回到選單：只剩預設使用者。
        XCTAssertTrue(element(app, "profile.picker").waitForExistence(timeout: 10))
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'profile.row.'")).count, 1,
            "刪除之後選單裡應該只剩預設使用者")
    }

    func testTheDefaultUserCannotBeDeleted() {
        let app = launch()
        openPicker(app)
        element(app, "profile.manage.default").tap()
        let delete = element(app, "profile.edit.delete")
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        XCTAssertFalse(delete.isEnabled, "預設使用者不能刪")
    }
}
