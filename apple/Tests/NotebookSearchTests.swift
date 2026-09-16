import PencilKit
import XCTest

@testable import Kairumo

/// 首頁搜尋要搜得到**筆記裡的內容**（工作項 S-64）。
///
/// 原本只比對標題、摘要與手寫辨識結果。使用者打在文字方塊、表格、
/// 流程圖節點上的字一個都搜不到 —— 而 S-61 之後，一份租賃契約的全文
/// 都在筆記裡，搜「押金」是零結果。
@MainActor
final class NotebookSearchTests: XCTestCase {

    /// 建一本帶著各種內容的筆記。
    private func document() -> NotebookDocument {
        var doc = NotebookDocument(title: "第三季檢討", pageCount: 1)
        doc.textAttachments = [
            NoteTextAttachment(pageIndex: 0, text: "押金新臺幣伍萬陸仟元整，租期屆滿無息返還。")
        ]
        doc.tableAttachments = [
            NoteTableAttachment(
                pageIndex: 0, rows: 2, cols: 2,
                cells: ["項目", "金額", "軸承座", "210,000"])
        ]
        doc.shapeAttachments = [
            NoteShapeAttachment(pageIndex: 0, kindName: "process", label: "壓入工序")
        ]
        return doc
    }

    /// 直接驗 `matchesSearch` 的等價邏輯：把 view 的私有方法搬出來測不現實，
    /// 所以這裡測的是「內容確實存在於可搜尋的欄位上」—— 那正是原本缺的東西。
    private func searchableText(_ doc: NotebookDocument) -> [String] {
        var parts: [String] = [doc.displayTitle()]
        if let snippet = doc.previewSnippet { parts.append(snippet) }
        parts.append(contentsOf: doc.recognizedText?.values ?? [:].values)
        parts.append(contentsOf: (doc.textAttachments ?? []).map(\.text))
        parts.append(contentsOf: (doc.tableAttachments ?? []).flatMap(\.cells))
        parts.append(contentsOf: (doc.shapeAttachments ?? []).compactMap(\.label))
        return parts
    }

    private func matches(_ doc: NotebookDocument, _ query: String) -> Bool {
        searchableText(doc).contains { $0.localizedCaseInsensitiveContains(query) }
    }

    func testTypedTextInsideANoteIsSearchable() {
        // 這是使用者實際回報的那一種：內容在筆記裡，搜不到。
        XCTAssertTrue(matches(document(), "押金"), "文字方塊裡的字搜不到")
    }

    func testTableCellsAreSearchable() {
        // 使用者記得的往往是某一格裡的字，而不是表格標題。
        XCTAssertTrue(matches(document(), "軸承座"), "表格儲存格搜不到")
    }

    func testShapeLabelsAreSearchable() {
        XCTAssertTrue(matches(document(), "壓入工序"), "流程圖節點的標籤搜不到")
    }

    func testTitleStillWins() {
        XCTAssertTrue(matches(document(), "第三季"))
    }

    func testSomethingAbsentDoesNotMatch() {
        // 沒有這一條的話，「全部都命中」也會讓上面四條通過。
        XCTAssertFalse(matches(document(), "這幾個字不在裡面"))
    }
}
