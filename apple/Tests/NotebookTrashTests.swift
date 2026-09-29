//
//  NotebookTrashTests.swift
//  KairumoTests
//
//  回收桶的檔案搬移（docs/plans/expiry-purge.md）。
//

import XCTest
@testable import Kairumo

/// # 這組測試守的是什麼
///
/// 軟刪除把套件**搬到 `TrashPackages/`**，而不是留在原地打記號。理由是同步與匯入有
/// 十幾處會列舉 `corePackagesDirectory`，任何一處漏判「已在回收桶」，這本筆記就會被
/// 當成新筆記匯回來 —— 刪掉的東西自己復活。所以最重要的一條性質是：
/// **進了回收桶的套件，不在任何會被列舉的目錄裡。**
///
/// 只測「搬檔案」這一層（`trashLocally` / `restoreLocally` / `purgeLocally`），
/// 不碰全域的同步索引（`AccountSyncStore.shared`），所以測試跑完不會在模擬器上
/// 留下任何墓碑。
@MainActor
final class NotebookTrashTests: XCTestCase {

    private func makeStore() -> NotebookStore {
        PageDeletionTests.isolatedStore()
    }

    private func makeDocument(id: String = UUID().uuidString) -> NotebookDocument {
        NotebookDocument(
            id: id,
            title: "待刪的筆記",
            pageCount: 1,
            pagesData: [Data()]
        )
    }

    /// 在 store 裡放一本筆記本，並在磁碟上建出它的套件與同步基準線（各放一個有內容的檔案）。
    @discardableResult
    private func seed(_ store: NotebookStore, id: String = UUID().uuidString, dirName: String? = nil)
        -> NotebookDocument
    {
        let doc = makeDocument(id: id)
        store.notebooks.append(doc)
        let name = "\(dirName ?? id).padnote"
        let fm = FileManager.default
        for base in [
            store.corePackagesDirectory,
            store.documentsDirectory.appending(path: "SyncBaseline"),
        ] {
            let dir = base.appending(path: name)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            try? Data("payload:\(id)".utf8).write(to: dir.appending(path: "marker.txt"))
        }
        return doc
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - 進回收桶

    func testTrashingMovesTheNotebookAndItsFilesOutOfTheLiveLocations() {
        let store = makeStore()
        let doc = seed(store)
        let name = "\(doc.id).padnote"

        XCTAssertTrue(store.trashLocally(id: doc.id))

        XCTAssertFalse(store.notebooks.contains { $0.id == doc.id }, "筆記本要從清單消失")
        XCTAssertEqual(store.trashedNotebooks.map(\.id), [doc.id])
        XCTAssertFalse(exists(store.corePackagesDirectory.appending(path: name)), "套件要離開原位")
        XCTAssertFalse(
            exists(store.documentsDirectory.appending(path: "SyncBaseline/\(name)")),
            "同步基準線要離開原位")
        XCTAssertTrue(
            exists(store.trashPackagesDirectory.appending(path: name).appending(path: "marker.txt")),
            "套件要在回收桶裡，而且內容還在")
        XCTAssertTrue(
            exists(store.trashPackagesDirectory.appending(path: "SyncBaseline/\(name)")))
    }

    /// **最重要的一條。** 同步會列舉這個目錄；回收桶裡的套件不能出現在裡面。
    func testATrashedPackageIsInvisibleToAnythingThatScansThePackagesDirectory() throws {
        let store = makeStore()
        let doc = seed(store)
        store.trashLocally(id: doc.id)

        let listed = (try? FileManager.default.contentsOfDirectory(
            at: store.corePackagesDirectory, includingPropertiesForKeys: nil)) ?? []
        XCTAssertFalse(
            listed.contains { $0.lastPathComponent.lowercased().hasPrefix(doc.id.lowercased()) },
            "回收桶裡的套件出現在會被同步列舉的目錄裡 —— 它會被當成新筆記匯回來")
    }

    func testTrashingAnUnknownNotebookDoesNothing() {
        let store = makeStore()
        XCTAssertFalse(store.trashLocally(id: "nope"))
        XCTAssertTrue(store.trashedNotebooks.isEmpty)
    }

    func testTrashingTwiceDoesNotDuplicateTheEntry() {
        let store = makeStore()
        let doc = seed(store)
        store.trashLocally(id: doc.id)
        // 第二次：已經不在清單裡，什麼都不該發生。
        XCTAssertFalse(store.trashLocally(id: doc.id))
        XCTAssertEqual(store.trashedNotebooks.count, 1)
    }

    func testTrashingTheActiveNotebookClearsTheActiveSelection() {
        let store = makeStore()
        let doc = seed(store)
        store.activeNotebookId = doc.id
        store.trashLocally(id: doc.id)
        XCTAssertNil(store.activeNotebookId, "還開著已刪除的那本，畫面會停在一本不存在的筆記上")
    }

    // MARK: - 還原

    func testRestoringPutsEverythingBack() {
        let store = makeStore()
        let doc = seed(store)
        let name = "\(doc.id).padnote"
        store.trashLocally(id: doc.id)

        XCTAssertTrue(store.restoreLocally(id: doc.id))

        XCTAssertTrue(store.notebooks.contains { $0.id == doc.id })
        XCTAssertTrue(store.trashedNotebooks.isEmpty)
        let restored = store.corePackagesDirectory.appending(path: name).appending(path: "marker.txt")
        XCTAssertEqual(
            try? String(contentsOf: restored, encoding: .utf8), "payload:\(doc.id)",
            "還原之後套件內容要與刪除前一模一樣")
        XCTAssertTrue(exists(store.documentsDirectory.appending(path: "SyncBaseline/\(name)")))
        XCTAssertFalse(exists(store.trashPackagesDirectory.appending(path: name)), "回收桶不該留殘骸")
    }

    func testRestoringSomethingThatIsNotInTheTrashDoesNothing() {
        let store = makeStore()
        XCTAssertFalse(store.restoreLocally(id: "nope"))
    }

    func testRestoringNeverCreatesADuplicateEntry() {
        let store = makeStore()
        let doc = seed(store)
        store.trashLocally(id: doc.id)
        // 不該發生，但發生了也不能讓清單出現兩筆同 id（ForEach 的識別會壞、畫面整片空白）。
        store.notebooks.append(doc)
        store.restoreLocally(id: doc.id)
        XCTAssertEqual(store.notebooks.filter { $0.id == doc.id }.count, 1)
    }

    // MARK: - 永久刪除

    func testPurgingRemovesTheRecordAndEveryCopyOnDisk() {
        let store = makeStore()
        let doc = seed(store)
        let name = "\(doc.id).padnote"
        store.trashLocally(id: doc.id)

        store.purgeLocally(id: doc.id)

        XCTAssertTrue(store.trashedNotebooks.isEmpty)
        XCTAssertFalse(exists(store.trashPackagesDirectory.appending(path: name)))
        XCTAssertFalse(exists(store.trashPackagesDirectory.appending(path: "SyncBaseline/\(name)")))
        XCTAssertFalse(store.restoreLocally(id: doc.id), "永久刪除之後不可能還原")
    }

    func testPurgingAlsoSweepsLeftoversInTheLiveLocations() {
        // 正常不會有東西留在原位；留了的話，就是沒刪乾淨。
        let store = makeStore()
        let doc = seed(store)
        let name = "\(doc.id).padnote"
        store.purgeLocally(id: doc.id)
        XCTAssertFalse(exists(store.corePackagesDirectory.appending(path: name)))
        XCTAssertFalse(exists(store.documentsDirectory.appending(path: "SyncBaseline/\(name)")))
    }

    func testEmptyingTheTrashPurgesEverythingInIt() {
        let store = makeStore()
        let a = seed(store)
        let b = seed(store)
        let kept = seed(store)
        store.trashLocally(id: a.id)
        store.trashLocally(id: b.id)

        XCTAssertEqual(store.emptyTrash(), 2)

        XCTAssertTrue(store.trashedNotebooks.isEmpty)
        XCTAssertTrue(store.notebooks.contains { $0.id == kept.id }, "沒進回收桶的不能被動到")
        XCTAssertTrue(
            exists(store.corePackagesDirectory.appending(path: "\(kept.id).padnote")))
    }

    // MARK: - 舊資料的 id 大小寫

    func testAnUppercaseIdWithALowercaseDirectoryIsStillMoved() {
        // 舊資料的 id 可能有大寫，而磁碟上的目錄名是小寫（或反過來）。
        let id = "ABCD-1234"
        let store = makeStore()
        seed(store, id: id, dirName: id.lowercased())

        XCTAssertTrue(store.trashLocally(id: id))
        XCTAssertFalse(
            exists(store.corePackagesDirectory.appending(path: "\(id.lowercased()).padnote")),
            "小寫目錄也要跟著進回收桶，否則同步會把它當成孤兒或新筆記")

        XCTAssertTrue(store.restoreLocally(id: id))
        XCTAssertTrue(
            exists(store.corePackagesDirectory.appending(path: "\(id.lowercased()).padnote")))
    }

    // MARK: - 持久化

    func testTheTrashSurvivesARestart() throws {
        let store = makeStore()
        let doc = seed(store)
        store.trashLocally(id: doc.id)
        store.persistData()

        // 寫檔在背景佇列，等它落盤。
        let trashFile = store.documentsDirectory.appending(path: "trash_v1.json")
        let deadline = Date().addingTimeInterval(5)
        while !exists(trashFile) && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertTrue(exists(trashFile), "回收桶沒有落盤")

        // 「重開 App」：同一個資料根目錄，新的 store。
        let reopened = NotebookStore(testDocumentsRoot: store.documentsDirectory)
        reopened.loadData()
        XCTAssertEqual(reopened.trashedNotebooks.map(\.id), [doc.id])
        XCTAssertTrue(reopened.restoreLocally(id: doc.id), "重開之後還原得回來")
    }
}
