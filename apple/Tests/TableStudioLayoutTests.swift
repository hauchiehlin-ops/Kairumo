import SwiftUI
import XCTest

@testable import Kairumo

/// 表格面板真的畫出了整張表（工作項 S-58）。
///
/// # 這條測試在防什麼
///
/// 原始故障只在 **Mac Catalyst** 出現：`Grid` 放進雙向 `ScrollView` 之後
/// **塌成一格** —— 使用者看到一個文字框，其餘行列完全不見，而下面的控制列
/// （合併、刪除欄列）還是好的，所以看起來像「表格壞了」。改用 VStack + HStack
/// 之後 iPad 上是對的，但**沒有人在 Catalyst 上真的看過**，這一項因此掛了很久。
///
/// 選單、無障礙樹都驗不到它：面板的內容在 Catalyst 的 AX 樹裡是空的。
/// 所以這裡**把畫面算繪出來量**——如果哪天又塌成一格，高度就不會隨列數增加。
@MainActor
final class TableStudioLayoutTests: XCTestCase {

    private func renderedSize(rows: Int, cols: Int) throws -> CGSize {
        let table = NoteTableAttachment(rows: rows, cols: cols)
        // 只算繪格子本身：整個面板包在 `NavigationStack` 裡，
        // `ImageRenderer` 對它回 nil。
        let renderer = ImageRenderer(
            content: TableStudioView(editing: table, onCommit: { _ in }).grid)
        let image = try XCTUnwrap(renderer.uiImage, "算繪不出畫面")
        return image.size
    }

    func testPanelGrowsWithRowCount() throws {
        let two = try renderedSize(rows: 2, cols: 3).height
        let six = try renderedSize(rows: 6, cols: 3).height
        // 實測一列 24pt（兩列 44pt、六列 140pt）。多四列至少要高出 80pt。
        // 塌成一格的話兩者會一樣高 —— 那正是要抓的故障。
        XCTAssertGreaterThan(
            six, two + 80,
            "六列的格子只比兩列高 \(six - two)pt —— 表格很可能又塌成一格了")
    }

    func testPanelGrowsWithColumnCount() throws {
        // 欄要橫向長出來。只驗高度的話，「每列只畫得出第一格」會漏掉。
        let three = try renderedSize(rows: 3, cols: 3).width
        let eight = try renderedSize(rows: 3, cols: 8).width
        // 一欄 120pt 寬加 4pt 間距；多五欄至少要寬出 500pt。
        XCTAssertGreaterThan(
            eight, three + 500,
            "八欄的格子只比三欄寬 \(eight - three)pt —— 欄可能沒有全部畫出來")
    }
}
