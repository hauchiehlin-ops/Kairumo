import XCTest

@testable import Kairumo

/// 鍵盤命令的分派（工作項 S-64）。
///
/// # 這組測試涵蓋哪一半、不涵蓋哪一半
///
/// 一個快捷鍵要能用，有兩段：
///
/// 1. **按鍵被系統送到 App 的命令上** —— 這一段是 `buildMenu(with:)` 與
///    SwiftUI 的 `.commands`。模擬器沒有硬體鍵盤，XCUITest 送不出 ⌘ 組合鍵，
///    所以**這一段是在 Mac Catalyst 上以選單列實測**的（選單項目存在、
///    按下去處理常式真的被呼叫），不在這裡。
/// 2. **命令被收到之後，畫面真的有反應** —— 這一段就是這裡測的。
///
/// 把第二段釘住是有意義的：中間那條通知的名稱打錯、payload 型別改了、
/// 或某個畫面忘了訂閱，都會讓快捷鍵**安靜地**失效，而那正是這個功能
/// 前兩次實作失敗的方式。
final class AppCommandTests: XCTestCase {

    private func expectNotification(
        _ name: Notification.Name,
        whenPerforming selector: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Notification? {
        let delegate = KairumoAppDelegate()
        var received: Notification?
        let token = NotificationCenter.default.addObserver(
            forName: name, object: nil, queue: nil
        ) { received = $0 }
        defer { NotificationCenter.default.removeObserver(token) }

        delegate.perform(Selector(selector))
        XCTAssertNotNil(
            received, "呼叫 \(selector) 之後沒有收到 \(name.rawValue)", file: file, line: line)
        return received
    }

    // ⇧⌘N 與 ⌘F 不在 delegate 上：「檔案」選單是 SwiftUI 從 `WindowGroup`
    // 產生的，delegate 插進去的項目會被它重建時蓋掉，所以那兩個命令走
    // `.commands`（見 `KairumoApp`）。它們送出的通知名稱在這裡釘住 ——
    // 名稱打錯的話，選單按得下去但畫面不會有反應。
    func testHomeCommandsHaveDistinctNotificationNames() {
        XCTAssertNotEqual(AppCommand.newNotebook, AppCommand.focusSearch)
        XCTAssertEqual(AppCommand.newNotebook.rawValue, "kairumo.command.newNotebook")
        XCTAssertEqual(AppCommand.focusSearch.rawValue, "kairumo.command.focusSearch")
    }

    func testToggleModeCommandPostsItsNotification() {
        _ = expectNotification(
            AppCommand.toggleEditorMode, whenPerforming: "commandToggleEditorMode")
    }

    func testEachToolCommandCarriesItsOwnIndex() {
        // ⌘1 是第 0 個工具。九個工具各有各的 selector —— 共用一個的話，
        // UIKit 會因為選單識別碼重複而在建立選單時直接把 App 打掉（踩過）。
        for index in 0..<EditorToolType.allCases.count where index < 9 {
            let note = expectNotification(
                AppCommand.selectTool, whenPerforming: "commandTool\(index + 1)")
            XCTAssertEqual(
                note?.object as? Int, index,
                "commandTool\(index + 1) 應該帶索引 \(index)")
        }
    }

    func testThereIsASelectorForEveryTool() {
        // 工具列以後加了第十支筆時，這條會提醒要補 selector ——
        // 不補的話那支筆就是沒有快捷鍵，而且不會有任何錯誤。
        XCTAssertLessThanOrEqual(
            EditorToolType.allCases.count, 9,
            "工具數超過 9 個了，AppCommands 的 selector 清單要跟著補")
    }
}
