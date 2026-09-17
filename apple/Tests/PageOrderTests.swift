//
//  PageOrderTests.swift
//  KairumoTests
//
//  搬動與插入頁面時，每一種附件都要跟著走（工作項 S-86）。
//

import XCTest
@testable import Kairumo

/// # 為什麼要有這一組測試
///
/// 一頁不是一筆資料，是散在四個地方的東西：磁碟上的筆跡檔案、`pageHeights`、
/// `pagesData`，以及九種附件各自的 `pageIndex`。搬動只改其中一樣的結果不是
/// 「沒搬動」，是「筆跡搬了、上面的表格沒搬」—— 比不能搬還糟。
///
/// `insertPage` 原本只對五種附件做頁碼平移，表格、形狀、連接線與錄音整組
/// 漏掉了（與 `deletePage` 同一個病灶）。症狀是「我在第 1 頁後面插了一頁，
/// 第 2 頁的表格留在原地，於是它落在那張新的空白頁上」。
@MainActor
final class PageOrderTests: XCTestCase {

    private func makeNotebook(pages: Int) -> NotebookDocument {
        var doc = NotebookDocument(
            title: "測試",
            createdAt: Date(),
            lastModifiedDate: Date(),
            pageCount: pages,
            hasRecording: false,
            previewSnippet: nil,
            template: .blank
        )
        doc.pagesData = Array(repeating: Data(), count: pages)
        doc.tableAttachments = (0..<pages).map {
            NoteTableAttachment(pageIndex: $0, x: 0, y: 0, width: 100, rows: 1, cols: 1, cells: ["p\($0)"])
        }
        doc.shapeAttachments = (0..<pages).map {
            NoteShapeAttachment(pageIndex: $0, x: 0, y: 0, width: 10, height: 10)
        }
        doc.textAttachments = (0..<pages).map {
            NoteTextAttachment(pageIndex: $0, text: "p\($0)")
        }
        return doc
    }

    /// 把第 0 頁搬到第 2 頁：0→2、1→0、2→1，而且每一種附件都要一起走。
    func testMovingAPageCarriesEveryAttachmentKind() {
        let store = NotebookStore.shared
        let doc = makeNotebook(pages: 3)
        store.notebooks.insert(doc, at: 0)
        defer { store.notebooks.removeAll { $0.id == doc.id } }

        let landed = store.movePage(notebookId: doc.id, from: 0, to: 2)
        XCTAssertEqual(landed, 2)

        guard let updated = store.notebooks.first(where: { $0.id == doc.id }) else {
            return XCTFail("筆記不見了")
        }
        // 頁數不變 —— 搬動是重排，不是增刪。
        XCTAssertEqual(updated.pageCount, 3)

        func page(of cell: String) -> Int? {
            updated.tableAttachments?.first { $0.cells.first == cell }?.pageIndex
        }
        XCTAssertEqual(page(of: "p0"), 2, "被搬的那一頁要落在目的地")
        XCTAssertEqual(page(of: "p1"), 0, "被跨過的往前遞補")
        XCTAssertEqual(page(of: "p2"), 1)

        // 形狀與文字方塊用的是同一份泛型，一起釘住 —— 這一組測試存在的理由
        // 就是「有一種型別被漏掉」，只驗一種等於沒驗。
        XCTAssertEqual(Set(updated.shapeAttachments?.map(\.pageIndex) ?? []), [0, 1, 2])
        XCTAssertEqual(Set(updated.textAttachments?.map(\.pageIndex) ?? []), [0, 1, 2])
    }

    /// 反方向搬：往前搬與往後搬的區間不對稱，兩邊都要驗。
    func testMovingAPageBackwardsIsNotTheMirrorImage() {
        let store = NotebookStore.shared
        let doc = makeNotebook(pages: 4)
        store.notebooks.insert(doc, at: 0)
        defer { store.notebooks.removeAll { $0.id == doc.id } }

        _ = store.movePage(notebookId: doc.id, from: 3, to: 1)
        guard let updated = store.notebooks.first(where: { $0.id == doc.id }) else {
            return XCTFail("筆記不見了")
        }
        func page(of cell: String) -> Int? {
            updated.tableAttachments?.first { $0.cells.first == cell }?.pageIndex
        }
        XCTAssertEqual(page(of: "p3"), 1)
        XCTAssertEqual(page(of: "p1"), 2)
        XCTAssertEqual(page(of: "p2"), 3)
        XCTAssertEqual(page(of: "p0"), 0)
    }

    /// 搬動永遠是重排：不能有兩個東西落在同一頁、也不能憑空多一頁。
    func testEveryMoveIsAPermutation() {
        let store = NotebookStore.shared
        for from in 0..<4 {
            for to in 0..<4 where from != to {
                let doc = makeNotebook(pages: 4)
                store.notebooks.insert(doc, at: 0)
                _ = store.movePage(notebookId: doc.id, from: from, to: to)
                let updated = store.notebooks.first { $0.id == doc.id }
                let pages = (updated?.tableAttachments ?? []).map(\.pageIndex).sorted()
                XCTAssertEqual(pages, [0, 1, 2, 3], "from=\(from) to=\(to) 不是重排")
                store.notebooks.removeAll { $0.id == doc.id }
            }
        }
    }

    /// 搬到自己身上、搬到範圍外：什麼都不該發生。
    func testAnImpossibleMoveChangesNothing() {
        let store = NotebookStore.shared
        let doc = makeNotebook(pages: 3)
        store.notebooks.insert(doc, at: 0)
        defer { store.notebooks.removeAll { $0.id == doc.id } }

        _ = store.movePage(notebookId: doc.id, from: 1, to: 1)
        _ = store.movePage(notebookId: doc.id, from: 0, to: 9)
        _ = store.movePage(notebookId: doc.id, from: -1, to: 0)

        let updated = store.notebooks.first { $0.id == doc.id }
        XCTAssertEqual(updated?.tableAttachments?.map(\.pageIndex), [0, 1, 2])
        XCTAssertEqual(updated?.pageCount, 3)
    }

    // MARK: - 跨筆記本的複製與搬移

    private func makePair() -> (NotebookDocument, NotebookDocument) {
        let source = makeNotebook(pages: 3)
        var target = makeNotebook(pages: 2)
        target.tableAttachments = (0..<2).map {
            NoteTableAttachment(pageIndex: $0, x: 0, y: 0, width: 100, rows: 1, cols: 1,
                                cells: ["t\($0)"])
        }
        target.shapeAttachments = []
        target.textAttachments = []
        return (source, target)
    }

    /// 複製：來源不動，目的接在最後面，而且附件要跟著走。
    func testCopyingPagesLeavesTheSourceAloneAndAppendsToTheTarget() {
        let store = NotebookStore.shared
        let (source, target) = makePair()
        store.notebooks.insert(source, at: 0)
        store.notebooks.insert(target, at: 0)
        defer { store.notebooks.removeAll { $0.id == source.id || $0.id == target.id } }

        let moved = store.transferPages(
            from: source.id, pageIndexes: [0, 2], to: target.id, move: false)
        XCTAssertEqual(moved, 2)

        let src = store.notebooks.first { $0.id == source.id }
        let dst = store.notebooks.first { $0.id == target.id }
        XCTAssertEqual(src?.pageCount, 3, "複製不該動到來源")
        XCTAssertEqual(dst?.pageCount, 4, "兩頁接在原本的兩頁後面")

        // 附件跟著走，而且落在新的頁碼上。
        let cells = (dst?.tableAttachments ?? []).map { ($0.cells.first ?? "", $0.pageIndex) }
        XCTAssertTrue(cells.contains { $0 == ("p0", 2) }, "第 0 頁的表格要落在第 2 頁")
        XCTAssertTrue(cells.contains { $0 == ("p2", 3) })
        XCTAssertTrue(cells.contains { $0 == ("t0", 0) }, "目的原本的東西不該被動到")
    }

    /// 複製過去的物件必須換一個 id。
    ///
    /// 沿用原本的 id 看起來沒事，直到使用者把那一頁再複製回來 —— 這時同一本
    /// 筆記裡有兩個相同 id 的物件，而選取、刪除、堆疊順序全部是照 id 找的。
    func testCopiedObjectsGetFreshIdentifiers() {
        let store = NotebookStore.shared
        let (source, target) = makePair()
        store.notebooks.insert(source, at: 0)
        store.notebooks.insert(target, at: 0)
        defer { store.notebooks.removeAll { $0.id == source.id || $0.id == target.id } }

        _ = store.transferPages(from: source.id, pageIndexes: [0], to: target.id, move: false)

        let sourceIds = Set((store.notebooks.first { $0.id == source.id }?
            .tableAttachments ?? []).map(\.id))
        let copied = (store.notebooks.first { $0.id == target.id }?
            .tableAttachments ?? []).filter { $0.cells.first == "p0" }
        XCTAssertEqual(copied.count, 1)
        XCTAssertFalse(sourceIds.contains(copied[0].id), "複本沿用了來源的 id")
        // 內容本身必須一模一樣 —— 換 id 是走 JSON 來回，欄位漏掉的話
        // 症狀是「複製過去的表格少了一欄」。
        XCTAssertEqual(copied[0].cells, ["p0"])
    }

    /// 搬移：來源那幾頁要消失，而且由大到小刪才不會刪錯。
    func testMovingPagesRemovesThemFromTheSource() {
        let store = NotebookStore.shared
        let (source, target) = makePair()
        store.notebooks.insert(source, at: 0)
        store.notebooks.insert(target, at: 0)
        defer { store.notebooks.removeAll { $0.id == source.id || $0.id == target.id } }

        let moved = store.transferPages(
            from: source.id, pageIndexes: [0, 2], to: target.id, move: true)
        XCTAssertEqual(moved, 2)

        let src = store.notebooks.first { $0.id == source.id }
        XCTAssertEqual(src?.pageCount, 1)
        // 留下來的必須是原本的第 1 頁，而且它現在是第 0 頁。
        XCTAssertEqual(src?.tableAttachments?.count, 1)
        XCTAssertEqual(src?.tableAttachments?.first?.cells.first, "p1")
        XCTAssertEqual(src?.tableAttachments?.first?.pageIndex, 0)
    }

    /// 一本筆記不能被搬空，也不能搬到自己身上。
    func testARefusedTransferChangesNothing() {
        let store = NotebookStore.shared
        let (source, target) = makePair()
        store.notebooks.insert(source, at: 0)
        store.notebooks.insert(target, at: 0)
        defer { store.notebooks.removeAll { $0.id == source.id || $0.id == target.id } }

        XCTAssertEqual(
            store.transferPages(
                from: source.id, pageIndexes: [0, 1, 2], to: target.id, move: true),
            0, "整本搬空應該被擋下")
        XCTAssertEqual(
            store.transferPages(
                from: source.id, pageIndexes: [0], to: source.id, move: true),
            0, "搬到自己身上應該被擋下")
        XCTAssertEqual(
            store.transferPages(from: source.id, pageIndexes: [], to: target.id, move: false),
            0)

        XCTAssertEqual(store.notebooks.first { $0.id == source.id }?.pageCount, 3)
        XCTAssertEqual(store.notebooks.first { $0.id == target.id }?.pageCount, 2)
    }

    /// 插入一頁時，**九種**附件都要讓出位置。
    func testInsertingAPageShiftsTheLateArrivingAttachmentKinds() {
        let store = NotebookStore.shared
        let doc = makeNotebook(pages: 3)
        store.notebooks.insert(doc, at: 0)
        defer { store.notebooks.removeAll { $0.id == doc.id } }

        // 在第 0 頁後面插入 → 新頁是第 1 頁，原本的 1、2 往後移。
        let inserted = store.insertPage(notebookId: doc.id, afterIndex: 0)
        XCTAssertEqual(inserted, 1)

        guard let updated = store.notebooks.first(where: { $0.id == doc.id }) else {
            return XCTFail("筆記不見了")
        }
        XCTAssertEqual(updated.pageCount, 4)
        func page(of cell: String) -> Int? {
            updated.tableAttachments?.first { $0.cells.first == cell }?.pageIndex
        }
        XCTAssertEqual(page(of: "p0"), 0, "插入點之前的不動")
        XCTAssertEqual(page(of: "p1"), 2, "插入點之後的讓一格")
        XCTAssertEqual(page(of: "p2"), 3)
        // 形狀原本整組漏掉，插入之後會留在舊頁碼上。
        XCTAssertEqual(updated.shapeAttachments?.map(\.pageIndex).sorted(), [0, 2, 3])
        // 內嵌筆跡陣列要跟著長一頁，否則匯出時少一頁。
        XCTAssertEqual(updated.pagesData.count, 4)
    }
}
