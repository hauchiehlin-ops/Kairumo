import XCTest

/// 兩台真正在跑的 App 共用同一個「雲端」時的行為。
///
/// # 怎麼用
///
/// 這不是一般的測試：每個 `testStepN_…` 是**多裝置劇本的一步**，要在指定的裝置上
/// 依序各跑一次（A 與 B 是兩台不同的模擬器）。劇本、跑法與為什麼需要它見
/// `docs/plans/expiry-purge.md` 與 `scripts/multi-device-ios.sh`。
///
/// 前置：`python3 scripts/fake-drive-server.py` 在跑。App 靠環境變數
/// `KAIRUMO_FAKE_DRIVE` 把 Google Drive 換成那個伺服器（見 `FakeDriveHook.swift`），
/// 所以模擬器上不必登入 Google，兩台裝置卻共用同一份雲端。
///
/// 步驟之間靠 `/tmp/kairumo-md/title.txt` 傳遞筆記本標題。
final class MultiDeviceUITests: XCTestCase {

    private static let dir = "/tmp/kairumo-md"
    private static let server = ProcessInfo.processInfo.environment["KAIRUMO_FAKE_DRIVE_URL"]
        ?? "http://127.0.0.1:8765"

    override func setUp() {
        continueAfterFailure = false
        try? FileManager.default.createDirectory(
            atPath: Self.dir, withIntermediateDirectories: true)
    }

    // MARK: - 共用

    private var titleFile: String { "\(Self.dir)/title.txt" }

    private func savedTitle() -> String {
        (try? String(contentsOfFile: titleFile, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["KAIRUMO_UITEST"] = "1"
        app.launchEnvironment["KAIRUMO_FAKE_DRIVE"] = Self.server
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        return app
    }

    /// 假雲端裡某個檔案的內容。沒有回 nil。
    private func cloudRead(_ name: String) -> String? {
        var comps = URLComponents(string: "\(Self.server)/_admin/read")!
        comps.queryItems = [URLQueryItem(name: "name", value: name)]
        var result: String?
        let done = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: comps.url!) { data, response, _ in
            if (response as? HTTPURLResponse)?.statusCode == 200, let data {
                result = String(data: data, encoding: .utf8)
            }
            done.signal()
        }.resume()
        _ = done.wait(timeout: .now() + 10)
        return result
    }

    /// 等雲端的筆記本索引出現某段文字（例如新標題）。`pattern` 是正規表示式 ——
    /// 假伺服器存的 JSON 有排版（`"deleted": true`，冒號後有空格），不能比對死字串。
    private func waitForCloudIndex(matching pattern: String, timeout: TimeInterval = 120) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let index = cloudRead("notebooks/index.json"),
               index.range(of: pattern, options: .regularExpression) != nil { return true }
            sleep(2)
        }
        return false
    }

    private func waitForCloudIndex(containing text: String, timeout: TimeInterval = 120) -> Bool {
        waitForCloudIndex(matching: NSRegularExpression.escapedPattern(for: text), timeout: timeout)
    }

    /// 假雲端裡（名字以 `prefix` 開頭的）檔案。
    private func cloudFiles(prefix: String) -> [String] {
        var result: [String] = []
        let done = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: URL(string: "\(Self.server)/_admin/files")!) { data, _, _ in
            if let data, let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                result = list.compactMap { $0["name"] as? String }.filter { $0.hasPrefix(prefix) }
            }
            done.signal()
        }.resume()
        _ = done.wait(timeout: .now() + 10)
        return result
    }

    /// 雲端裡兩台裝置的確認檔：`裝置 id（小寫） → seenLamport`。
    private func cloudAcks() -> [String: Int] {
        var acks: [String: Int] = [:]
        for name in cloudFiles(prefix: "sync/") where name.hasSuffix("/ack.json") {
            guard let text = cloudRead(name),
                  let json = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
                  let seen = json["seenLamport"] as? Int else { continue }
            acks[name.split(separator: "/")[1].lowercased()] = seen
        }
        return acks
    }

    /// 筆記本 id：從雲端索引裡用**標題前綴**找。劇本裡標題會被改好幾次
    /// （`…-RENAMED`、`…-RENAMED-ANDROID`），所以不能用整串比對。
    private func notebookId(titledWithPrefix prefix: String) -> String? {
        guard let text = cloudRead("notebooks/index.json"),
              let json = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
              let items = json["items"] as? [String: [String: Any]] else { return nil }
        return items.values.first { (($0["title"] as? String) ?? "").hasPrefix(prefix) }?["id"] as? String
    }

    /// 某本（標題前綴）的墓碑目前的時戳。沒有墓碑回 nil。
    private func tombstoneLamport(prefix: String) -> Int? {
        guard let text = cloudRead("notebooks/index.json"),
              let json = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
              let items = json["items"] as? [String: [String: Any]] else { return nil }
        return items.values.first {
            (($0["title"] as? String) ?? "").hasPrefix(prefix) && ($0["deleted"] as? Bool) == true
        }?["lamport"] as? Int
    }

    /// 開回收桶（診斷頁 → 回收桶）。回傳 nil 表示成功，否則是卡在哪一步。
    private func openTrash(_ app: XCUIApplication) -> String? {
        let diagnostics = app.buttons["home.diagnostics"].firstMatch
        var ups = 0
        while !diagnostics.isHittable && ups < 4 { app.swipeDown(); ups += 1 }
        guard diagnostics.waitForExistence(timeout: 10), diagnostics.isHittable else {
            return "首頁找不到（或點不到）診斷入口"
        }
        diagnostics.tap()
        let entry = app.buttons["settings.trash"].firstMatch
        var scrolls = 0
        while !(entry.exists && entry.isHittable) && scrolls < 15 { app.swipeUp(); scrolls += 1 }
        guard entry.exists, entry.isHittable else { return "診斷頁捲了 \(scrolls) 次仍找不到回收桶入口" }
        entry.tap()
        guard app.buttons["trash.done"].firstMatch.waitForExistence(timeout: 10) else {
            return "點了回收桶入口但畫面沒出現"
        }
        return nil
    }

    private func card(_ app: XCUIApplication, _ title: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(
                format: "identifier BEGINSWITH 'home.notebooks.card.' AND label CONTAINS %@", title))
            .firstMatch
    }

    private func scrollToCard(_ app: XCUIApplication, _ title: String) -> Bool {
        let element = card(app, title)
        var scrolls = 0
        while !(element.exists && element.isHittable) && scrolls < 12 {
            app.swipeUp()
            scrolls += 1
        }
        return element.exists && element.isHittable
    }

    /// 等首頁出現（或消失）某本筆記本的卡片。
    ///
    /// **要在捲下去之後檢查，不能在頂端檢查。** 有識別碼的卡片在「所有筆記本」那一區，
    /// 在摺線下面；SwiftUI 只繪製捲到附近的列，停在頂端時它根本不在無障礙樹裡 ——
    /// 第一版先捲回頂端才檢查，於是「明明收到了、錄影裡也看得到」卻回報沒收到。
    private func waitForCard(
        _ app: XCUIApplication, _ title: String, present: Bool, timeout: TimeInterval = 150
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            app.swipeUp()
            sleep(2)
            if card(app, title).exists == present { return true }
            app.swipeDown()
            sleep(3)
        }
        return false
    }

    private func menu(_ app: XCUIApplication, on title: String, choose label: String) -> Bool {
        guard scrollToCard(app, title) else { return false }
        card(app, title).press(forDuration: 1.2)
        let button = app.buttons[label].firstMatch
        if button.waitForExistence(timeout: 6) {
            button.tap()
            return true
        }
        let any = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label)).firstMatch
        guard any.waitForExistence(timeout: 5) else { return false }
        any.tap()
        return true
    }

    // MARK: - 劇本

    /// A：建立一本有獨特標題的筆記本，等它上傳到雲端。
    func testStep1_A_createsANotebook() {
        let title = "MD-\(UUID().uuidString.prefix(8))"
        try? title.write(toFile: titleFile, atomically: true, encoding: .utf8)
        let app = launch()

        let newNote = app.descendants(matching: .any)
            .matching(identifier: "home.action.new_note").firstMatch
        XCTAssertTrue(newNote.waitForExistence(timeout: 20), "首頁找不到新增筆記入口")
        newNote.tap()
        let field = app.descendants(matching: .any)
            .matching(identifier: "new_notebook.title.field").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        if let existing = field.value as? String, !existing.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        field.typeText(title)
        app.descendants(matching: .any).matching(identifier: "new_notebook.confirm")
            .firstMatch.tap()
        let home = app.descendants(matching: .any).matching(identifier: "editor.home").firstMatch
        XCTAssertTrue(home.waitForExistence(timeout: 20), "建立筆記後沒有進入編輯器")
        home.tap()

        XCTAssertTrue(
            waitForCloudIndex(containing: title),
            "A 建立的筆記本「\(title)」沒有出現在雲端索引裡（同步沒有把它傳上去）")
    }

    /// B：另一台裝置看得到 A 建立的筆記本。
    func testStep2_B_seesTheNotebook() {
        let title = savedTitle()
        XCTAssertFalse(title.isEmpty, "先在 A 跑 step1")
        let app = launch()
        XCTAssertTrue(waitForCard(app, title, present: true), "B 沒有收到 A 建立的筆記本「\(title)」")
    }

    /// A：更名，等新標題傳上雲端。
    func testStep3_A_renamesIt() {
        let title = savedTitle()
        let renamed = "\(title)-RENAMED"
        let app = launch()
        XCTAssertTrue(menu(app, on: title, choose: "Rename Notebook"), "卡片選單沒有「重新命名」")
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "沒有出現重新命名的輸入框")
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        if let existing = field.value as? String, !existing.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        field.typeText(renamed)
        app.alerts.buttons["Save"].firstMatch.tap()
        XCTAssertTrue(
            waitForCloudIndex(containing: renamed),
            "A 更名之後，新標題「\(renamed)」沒有出現在雲端索引裡")
    }

    /// B：**這一步在驗證更名有沒有傳到另一台。** 卡片必須換成新名字，而不是舊名字還在、
    /// 也不是多出一本新的。
    func testStep4_B_seesTheRename() {
        let title = savedTitle()
        let renamed = "\(title)-RENAMED"
        let app = launch()
        XCTAssertTrue(
            waitForCard(app, renamed, present: true),
            "B 沒有看到更名後的標題「\(renamed)」")
        // 舊名字不該還在 —— 否則就是「更名被當成新筆記」。
        XCTAssertFalse(
            card(app, title + " ").exists && !card(app, renamed).exists,
            "B 上舊標題還在")
    }

    /// A（iPad）：**Android 更名之後，這台看得到新標題。** 跨平台的更名要雙向都通。
    func testStep4b_A_seesTheAndroidRename() {
        let title = savedTitle()
        let app = launch()
        XCTAssertTrue(
            waitForCard(app, "\(title)-RENAMED-ANDROID", present: true),
            "Android 更名之後，iPad 沒有看到新標題「\(title)-RENAMED-ANDROID」")
    }

    /// A：刪除（進回收桶）。
    func testStep5_A_deletesIt() {
        let title = savedTitle()
        let app = launch()
        XCTAssertTrue(menu(app, on: title, choose: "Delete Item"), "卡片選單沒有「刪除」")
        XCTAssertTrue(
            waitForCloudIndex(matching: "\"deleted\"\\s*:\\s*true"),
            "A 刪除之後，雲端索引裡沒有出現墓碑")
    }

    /// B：卡片消失（別台刪的，這台也進回收桶）。
    func testStep6_B_seesTheDeletion() {
        let title = savedTitle()
        let app = launch()
        XCTAssertTrue(
            waitForCard(app, title, present: false),
            "A 刪掉之後，B 首頁的筆記本還在")
    }

    // MARK: - 清除：另一台落後時，雲端不能被清掉

    /// A：**在 B 還沒確認這個刪除的時候**清空回收桶。
    ///
    /// 本機馬上清掉，但雲端檔案必須**留著** —— B 可能還有沒上傳的內容，
    /// 而且它根本還不知道這本被刪了。畫面要說明是在等哪一台。
    func testStep7_A_emptiesTheTrashWhileBIsBehind() {
        let id = notebookId(titledWithPrefix: savedTitle())
        XCTAssertNotNil(id, "雲端索引裡找不到「\(savedTitle())」開頭的筆記本")
        let filesBefore = cloudFiles(prefix: "notebooks/\(id!)/")
        XCTAssertFalse(filesBefore.isEmpty, "雲端上這本沒有任何檔案，沒有東西可以驗證")

        let app = launch()
        XCTAssertNil(openTrash(app), "開不了回收桶")
        let empty = app.buttons["trash.emptyAction"].firstMatch
        XCTAssertTrue(empty.isEnabled, "回收桶裡應該有剛刪的那一本")
        empty.tap()
        app.alerts.buttons["Empty Trash"].firstMatch.tap()

        // 本機那一半：回收桶空了。
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "trash.empty")
                .firstMatch.waitForExistence(timeout: 20),
            "清空之後回收桶不是空的")

        // 雲端那一半：B 落後，所以**還在等**，畫面要講出來。
        let waiting = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Waiting for these devices'")).firstMatch
        XCTAssertTrue(waiting.waitForExistence(timeout: 90), "畫面沒有說明在等哪一台裝置")
        XCTAssertEqual(
            cloudFiles(prefix: "notebooks/\(id!)/").count, filesBefore.count,
            "B 還沒確認，雲端檔案卻被刪了")
    }

    /// B：同步到刪除，並發布確認。
    func testStep8_B_syncsTheDeletionAndConfirms() {
        let app = launch()
        XCTAssertTrue(
            waitForCard(app, savedTitle(), present: false),
            "A 刪掉之後，B 首頁的筆記本還在")
        // 確認檔要追上刪除的那一筆。時戳不能寫死 —— 加入 Android 之後每次更名都會讓它變大。
        // 這時至少 A 與 B 兩台要追上（Android 是第三台，它另有步驟）。
        let lamport = tombstoneLamport(prefix: savedTitle())
        XCTAssertNotNil(lamport, "雲端索引裡找不到墓碑")
        let deadline = Date().addingTimeInterval(90)
        var ok = false
        while Date() < deadline {
            let caughtUp = cloudAcks().values.filter { $0 >= lamport! }.count
            if caughtUp >= 2 { ok = true; break }
            sleep(3)
        }
        XCTAssertTrue(ok, "B 的確認檔沒有追上刪除（時戳 \(lamport!)）：\(cloudAcks())")
    }

    /// A：B 確認之後，**A 之前按下的「清空」要能完成雲端那一半**，不必再按一次。
    /// （清空之後回收桶是空的，按鈕是停用的 —— 使用者沒有第二次機會。）
    func testStep9_A_cloudIsPurgedOnceBHasConfirmed() {
        let id = notebookId(titledWithPrefix: savedTitle())
        XCTAssertNotNil(id)
        let app = launch()
        _ = app
        let deadline = Date().addingTimeInterval(150)
        while Date() < deadline {
            if cloudFiles(prefix: "notebooks/\(id!)/").isEmpty { return }
            sleep(3)
        }
        XCTFail("B 已經確認、A 也按過「清空」，雲端檔案卻還在：\(cloudFiles(prefix: "notebooks/\(id!)/"))")
    }

    /// B（iPhone）：A 按過「永久刪除」，這台的回收桶副本也該被清掉（不是永遠留著）。
    func testStep10_B_localCopyIsPurged() {
        let app = launch()
        XCTAssertNil(openTrash(app), "開不了回收桶")
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "trash.empty")
                .firstMatch.waitForExistence(timeout: 90),
            "A 要求永久刪除之後，這台的回收桶裡還留著那一本")
    }
}
