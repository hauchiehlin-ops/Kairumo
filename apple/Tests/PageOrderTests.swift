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
        let store = Self.isolatedStore()
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
        let store = Self.isolatedStore()
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
        let store = Self.isolatedStore()
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
        let store = Self.isolatedStore()
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
        let store = Self.isolatedStore()
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
        let store = Self.isolatedStore()
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
        let store = Self.isolatedStore()
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
        let store = Self.isolatedStore()
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
        let store = Self.isolatedStore()
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

    /// 首頁與筆記頁顯示的是同一段錄音；從首頁改名後，已插入的卡片也要一致。
    func testRenamingARecordingUpdatesHomeIndexAndInsertedCards() {
        let store = Self.isolatedStore()
        let recording = store.addRecording(
            title: "舊名稱", durationSeconds: 12, fileName: "audio.opus")
        var doc = makeNotebook(pages: 1)
        doc.audioAttachments = [NoteAudioAttachment(
            recordingId: recording.id,
            fileName: recording.fileName,
            title: recording.title,
            durationSeconds: recording.durationSeconds
        )]
        store.notebooks = [doc]

        store.renameRecording(id: recording.id, newTitle: "  訪談錄音  ")

        XCTAssertEqual(store.recordings.first?.title, "訪談錄音")
        XCTAssertEqual(store.notebooks.first?.audioAttachments?.first?.title, "訪談錄音")
    }

    func testSyncedSeedDuplicatesAreRepairedWithoutRestarting() {
        let store = Self.isolatedStore()
        var older = makeNotebook(pages: 1)
        older.title = "歡迎使用 Kairumo"
        older.titleKey = "seed_welcome_title"
        older.lastModifiedDate = Date(timeIntervalSince1970: 10)
        var newer = makeNotebook(pages: 1)
        newer.title = "歡迎使用 Kairumo"
        newer.titleKey = "seed_welcome_title"
        newer.lastModifiedDate = Date(timeIntervalSince1970: 20)
        store.notebooks = [older, newer]

        store.repairSyncedSeedDuplicates()

        XCTAssertEqual(store.notebooks.count, 1)
        XCTAssertEqual(store.notebooks.first?.id, newer.id)
    }

    // MARK: - 逐頁檔案與逐頁欄位跟著頁走

    /// 每一頁放一筆專業筆畫，用筆寬當「這是第幾頁」的記號。
    private func seedProInk(_ store: NotebookStore, _ doc: NotebookDocument) {
        for page in 0..<doc.pageCount {
            let stroke = ProStroke(tool: "charcoal", colorRGBA: [0, 0, 0, 255], baseWidth: Float(page + 1),
                                   points: [ProPoint(x: 0, y: 0, pressure: 1, tilt: 0, azimuth: 0, dtUs: 0),
                                            ProPoint(x: 10, y: 10, pressure: 1, tilt: 0, azimuth: 0, dtUs: 0)])
            ProInkStore.save([stroke], in: store.drawingsDirectory, notebookId: doc.id, page: page)
        }
    }

    private func proMarker(_ store: NotebookStore, _ doc: NotebookDocument, page: Int) -> [Float] {
        ProInkStore.load(in: store.drawingsDirectory, notebookId: doc.id, page: page).map(\.baseWidth)
    }

    /// 搬頁時專業筆畫（炭筆、蠟筆…）要跟著走。原本只搬 `.drawing`：PencilKit 的字搬過去了，炭筆字留在原頁。
    func testMovingAPageCarriesProInkAndPageKeyedFields() {
        let store = Self.isolatedStore()
        var doc = makeNotebook(pages: 3)
        doc.lockedObjectIdsByPage = ["0": ["locked-on-0"]]
        doc.tapeAttachments = [NoteTapeAttachment(pageIndex: 0, rect: .zero)]
        store.notebooks.insert(doc, at: 0)
        seedProInk(store, doc)

        store.movePage(notebookId: doc.id, from: 0, to: 2)

        XCTAssertEqual(proMarker(store, doc, page: 0), [2])
        XCTAssertEqual(proMarker(store, doc, page: 1), [3])
        XCTAssertEqual(proMarker(store, doc, page: 2), [1], "被搬的那一頁的專業筆畫要跟著到第 3 頁")
        let updated = store.notebooks.first { $0.id == doc.id }
        XCTAssertEqual(updated?.lockedObjectIdsByPage, ["2": ["locked-on-0"]])
        XCTAssertEqual(updated?.tapeAttachments?.first?.pageIndex, 2)
    }

    /// 刪頁：那一頁的專業筆畫一起刪掉，後面的往前補；原本留在磁碟上，跑到下一頁或被新頁撿回來。
    func testDeletingAPageDropsItsProInkAndShiftsTheRest() {
        let store = Self.isolatedStore()
        let doc = makeNotebook(pages: 3)
        store.notebooks.insert(doc, at: 0)
        seedProInk(store, doc)

        _ = store.deletePage(notebookId: doc.id, pageIndex: 0, currentIndex: 0)

        XCTAssertEqual(proMarker(store, doc, page: 0), [2])
        XCTAssertEqual(proMarker(store, doc, page: 1), [3])
        XCTAssertEqual(proMarker(store, doc, page: 2), [], "最後一頁的檔案要清掉，不然下一次新增的頁會撿到它")
    }

    /// 插頁：新頁是空白的，後面的專業筆畫往後讓一格。
    func testInsertingAPageShiftsProInk() {
        let store = Self.isolatedStore()
        let doc = makeNotebook(pages: 2)
        store.notebooks.insert(doc, at: 0)
        seedProInk(store, doc)

        _ = store.insertPage(notebookId: doc.id, afterIndex: 0)

        XCTAssertEqual(proMarker(store, doc, page: 0), [1])
        XCTAssertEqual(proMarker(store, doc, page: 1), [], "新插入的頁是空白的")
        XCTAssertEqual(proMarker(store, doc, page: 2), [2])
    }

    /// 複製頁：專業筆畫也要複製（換新 id），後面的往後讓一格。
    func testDuplicatingAPageCopiesProInkWithFreshIds() {
        let store = Self.isolatedStore()
        let doc = makeNotebook(pages: 2)
        store.notebooks.insert(doc, at: 0)
        seedProInk(store, doc)

        _ = store.duplicatePage(notebookId: doc.id, pageIndex: 0)

        XCTAssertEqual(proMarker(store, doc, page: 0), [1])
        XCTAssertEqual(proMarker(store, doc, page: 1), [1], "複本帶著原頁的專業筆畫")
        XCTAssertEqual(proMarker(store, doc, page: 2), [2])
        let original = ProInkStore.load(in: store.drawingsDirectory, notebookId: doc.id, page: 0).map(\.id)
        let copy = ProInkStore.load(in: store.drawingsDirectory, notebookId: doc.id, page: 1).map(\.id)
        XCTAssertTrue(Set(original).isDisjoint(with: copy), "複本沿用原本的 id 的話，擦掉一筆另一筆也跟著消失")
    }

    /// 還原到初始狀態：搬過、插過頁之後，逐頁檔案要排回原本的頁碼，這次新增的頁的檔案拿掉。
    func testRestoringPageFilesUndoesMovesAndDropsAddedPages() {
        let store = Self.isolatedStore()
        let doc = makeNotebook(pages: 3)
        store.notebooks.insert(doc, at: 0)
        seedProInk(store, doc)

        // 0 搬到 2，再在最前面後插一頁：目前是 [1, 新, 2, 0]（記號 2, -, 3, 1）。
        store.movePage(notebookId: doc.id, from: 0, to: 2)
        _ = store.insertPage(notebookId: doc.id, afterIndex: 0)
        XCTAssertEqual(proMarker(store, doc, page: 3), [1])

        store.restorePageFiles(notebookId: doc.id, origins: [1, nil, 2, 0])

        XCTAssertEqual(proMarker(store, doc, page: 0), [1])
        XCTAssertEqual(proMarker(store, doc, page: 1), [2])
        XCTAssertEqual(proMarker(store, doc, page: 2), [3])
        XCTAssertEqual(proMarker(store, doc, page: 3), [], "這次新增的頁的檔案要拿掉")
    }

    /// 新增、插入、複製頁面時，pageHeights 應填入該筆記的標準頁高（1132），而非舊版 1800，
    /// 否則設定頁會誤判需要「重新分頁」（needsRepagination == true）。
    func testAddingInsertingAndDuplicatingPagesUseStandardPageHeight() {
        let store = Self.isolatedStore()
        let doc = makeNotebook(pages: 1)
        store.notebooks.insert(doc, at: 0)
        defer { store.notebooks.removeAll { $0.id == doc.id } }

        _ = store.addPage(notebookId: doc.id)
        _ = store.insertPage(notebookId: doc.id, afterIndex: 0)
        _ = store.duplicatePage(notebookId: doc.id, pageIndex: 0)

        guard let updated = store.notebooks.first(where: { $0.id == doc.id }) else {
            return XCTFail("筆記不見了")
        }
        XCTAssertEqual(updated.pageHeights, Array(repeating: updated.pageSize.height, count: 4))
        XCTAssertFalse(PageRepagination.needsRepagination(updated))
    }
}
