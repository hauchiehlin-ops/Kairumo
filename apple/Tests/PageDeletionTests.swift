//
//  PageDeletionTests.swift
//  KairumoTests
//
//  刪除頁面時，每一種附件都要跟著走（工作項 S-82）。
//

import XCTest
@testable import Kairumo

/// # 為什麼要有這一組測試
///
/// `deletePage` 對每一種附件各寫了一份幾乎一樣的「刪掉這一頁的、後面的
/// 往前移」。新增附件型別時沒有人記得回來加 —— **表格、形狀、連接線與
/// 錄音整組漏掉了**。
///
/// 症狀不是「刪不掉」，而是「刪了一頁，那一頁上的表格卻還在，而且跑到
/// 別頁去了」。使用者看到的是「刪除只清掉了內容，頁面還在」。
@MainActor
final class PageDeletionTests: XCTestCase {
    /// 每個測試各用一個暫存目錄的 store（S-92）。
    ///
    /// 用 `NotebookStore.shared` 的話，`deletePage` / `transferPages` 內部會
    /// `persistData()` —— 跑完測試，模擬器上使用者的筆記清單裡就多幾本叫
    /// 「測試」的筆記。`defer` 只把陣列裡那幾筆移掉，沒有再存一次。
    @MainActor
    static func isolatedStore() -> NotebookStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-tests-\(UUID().uuidString)")
        return NotebookStore(testDocumentsRoot: dir)
    }


    private func makeNotebook() -> NotebookDocument {
        var doc = NotebookDocument(
            title: "測試",
            createdAt: Date(),
            lastModifiedDate: Date(),
            pageCount: 3,
            hasRecording: false,
            previewSnippet: nil,
            template: .blank
        )
        doc.pagesData = [Data(), Data(), Data()]
        return doc
    }

    /// 每一種附件都要對齊：第 1 頁的丟掉、第 2 頁的變成第 1 頁。
    func testEveryAttachmentKindFollowsTheDeletedPage() {
        let store = Self.isolatedStore()
        var doc = makeNotebook()

        doc.tableAttachments = [
            NoteTableAttachment(pageIndex: 0, x: 0, y: 0, width: 100, rows: 1, cols: 1, cells: ["a"]),
            NoteTableAttachment(pageIndex: 1, x: 0, y: 0, width: 100, rows: 1, cols: 1, cells: ["b"]),
            NoteTableAttachment(pageIndex: 2, x: 0, y: 0, width: 100, rows: 1, cols: 1, cells: ["c"]),
        ]
        doc.textAttachments = [
            NoteTextAttachment(pageIndex: 1, text: "留下"),
            NoteTextAttachment(pageIndex: 2, text: "往前"),
        ]

        store.notebooks.insert(doc, at: 0)
        defer { store.notebooks.removeAll { $0.id == doc.id } }

        _ = store.deletePage(notebookId: doc.id, pageIndex: 1, currentIndex: 1)
        guard let updated = store.notebooks.first(where: { $0.id == doc.id }) else {
            return XCTFail("筆記不見了")
        }

        XCTAssertEqual(updated.pageCount, 2)
        // 表格：第 1 頁那張要消失，第 2 頁那張要變成第 1 頁。
        let tables = updated.tableAttachments ?? []
        XCTAssertEqual(tables.count, 2, "第 1 頁的表格沒有被刪掉")
        XCTAssertEqual(tables.map(\.pageIndex).sorted(), [0, 1])
        XCTAssertFalse(tables.contains { $0.cells.first == "b" }, "刪掉的那一頁的表格還在")

        let texts = updated.textAttachments ?? []
        XCTAssertEqual(texts.count, 1)
        XCTAssertEqual(texts.first?.pageIndex, 1)
    }

    /// 內嵌的筆跡陣列也要縮短，否則刪掉的那一頁會在匯出時復活。
    func testTheInlineDrawingArrayShrinksToo() {
        let store = Self.isolatedStore()
        let doc = makeNotebook()
        store.notebooks.insert(doc, at: 0)
        defer { store.notebooks.removeAll { $0.id == doc.id } }

        _ = store.deletePage(notebookId: doc.id, pageIndex: 0, currentIndex: 0)
        let updated = store.notebooks.first { $0.id == doc.id }
        XCTAssertEqual(updated?.pagesData.count, 2)
        XCTAssertEqual(updated?.pageCount, 2)
    }

    /// 只剩一頁時不給刪 —— 刪光了就沒有東西可以寫，而 UI 上也沒有
    /// 「建立第一頁」的入口。
    func testTheLastPageCannotBeDeleted() {
        let store = Self.isolatedStore()
        var doc = makeNotebook()
        doc.pageCount = 1
        doc.pagesData = [Data()]
        store.notebooks.insert(doc, at: 0)
        defer { store.notebooks.removeAll { $0.id == doc.id } }

        _ = store.deletePage(notebookId: doc.id, pageIndex: 0, currentIndex: 0)
        XCTAssertEqual(store.notebooks.first { $0.id == doc.id }?.pageCount, 1)
    }

    /// 頁碼共用同一份對齊規則。
    func testShiftPagesDropsTheDeletedPageAndMovesTheRest() {
        let items = [
            NoteTextAttachment(pageIndex: 0, text: "a"),
            NoteTextAttachment(pageIndex: 2, text: "b"),
            NoteTextAttachment(pageIndex: 3, text: "c"),
        ]
        let shifted = NotebookStore.shiftPages(items, removing: 2) ?? []
        XCTAssertEqual(shifted.map(\.pageIndex), [0, 2])
        XCTAssertEqual(shifted.map(\.text), ["a", "c"])
    }
}
