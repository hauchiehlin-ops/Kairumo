import XCTest
@testable import Kairumo

/// 預載範例筆記本不參與同步，而且過去被同步合併成兩份的內容會被一次性重設乾淨。
@MainActor
final class SeedNotebookSyncTests: XCTestCase {
    private func makeStore() -> NotebookStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-seed-tests-\(UUID().uuidString)")
        let store = NotebookStore(testDocumentsRoot: dir)
        store.loadData()
        if store.notebooks.isEmpty {
            store.seedDefaultNotebooks()
        }
        store.backfillEmptySeedNotebooks()
        return store
    }

    /// 使用者回報：Mac 上永遠少一本《Kairumo(功能範例)》—— 新安裝、手動加回、同步之後都一樣。
    /// 走一次「新安裝 → 重開 App → 同步收尾」，五本範例都要還在。
    func testAllFiveSamplesSurviveARelaunchAndASyncPass() async {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-seed-tests-\(UUID().uuidString)")
        let first = NotebookStore(testDocumentsRoot: dir)
        first.loadData()
        if first.notebooks.isEmpty { first.seedDefaultNotebooks() }
        first.backfillEmptySeedNotebooks()
        let ids = ["seed-welcome-notebook-v1", "seed-meeting-notebook-v1", "seed-feature-showcase-v1",
                   "seed-kairumo-manual-v1", "seed-drafting-example-v1"]
        for id in ids {
            XCTAssertTrue(first.notebooks.contains { $0.id.lowercased() == id }, "新安裝就少了 \(id)")
        }
        await first.finishPreparingForProfileSwitch()

        let relaunched = NotebookStore(testDocumentsRoot: dir)
        relaunched.loadData()
        relaunched.backfillEmptySeedNotebooks()
        relaunched.repairSyncedSeedDuplicates()
        relaunched.syncPurgeDeletedNotebooks(AccountSyncStore.shared.deletedNotebookIds)
        for id in ids {
            XCTAssertTrue(relaunched.visibleNotebooks.contains { $0.id.lowercased() == id }, "重開／同步之後少了 \(id)")
        }
    }

    func testEverySeedIsDeviceLocalAndUserNotebooksAreNot() {
        for id in ["seed-welcome-notebook-v1", "seed-feature-showcase-v1", "seed-kairumo-manual-v1",
                   "seed-drafting-example-v1", "seed-meeting-notebook-v1", "SEED-FEATURE-SHOWCASE-V1"] {
            XCTAssertTrue(NotebookPackageBridge.isDeviceLocalSeed(id), "\(id) 應該是各裝置自己產生的範例")
        }
        for id in [UUID().uuidString, "my-notebook", "seed-my-own", "uitest-matrix-notebook"] {
            XCTAssertFalse(NotebookPackageBridge.isDeviceLocalSeed(id), "\(id) 是使用者的筆記本，要照常同步")
        }
    }

    func testSeedsNeverEnterTheSyncList() {
        let store = makeStore()
        XCTAssertTrue(store.notebooks.contains { $0.id == "seed-feature-showcase-v1" }, "前提：範例存在")
        let synced = store.syncNotebooks.map(\.id)
        XCTAssertFalse(synced.contains { NotebookPackageBridge.isDeviceLocalSeed($0) }, "範例進了同步清單：\(synced)")
    }

    /// 使用者回報：重新安裝後「我的筆記」是空的。某台裝置刪過範例，墓碑留在雲端索引裡，
    /// 新裝置剛產生的範例被它藏起來、丟進回收桶。範例不同步，索引的刪除紀錄不能碰到它。
    func testADeletionRecordInTheSyncIndexNeverHidesOrTrashesASample() {
        let store = makeStore()
        let id = "seed-feature-showcase-v1"
        AccountSyncStore.shared.recordDeletion(id: id)
        XCTAssertFalse(AccountSyncStore.shared.isDeleted(id: id), "範例的刪除不寫進同步索引")
        XCTAssertFalse(store.isHiddenBySync(id), "範例不會被同步索引藏起來")
        XCTAssertTrue(store.visibleNotebooks.contains { $0.id == id }, "首頁看得到範例")
        store.syncPurgeDeletedNotebooks([id])
        XCTAssertTrue(store.notebooks.contains { $0.id == id }, "同步不會把範例丟進回收桶")
    }

    /// 只有 Apple 失效的那一種：範例在舊索引裡掛在某個資料夾底下，那個資料夾後來被刪了。
    /// Apple 首頁會藏起「祖先被刪」的項目（Android 首頁不看索引，所以 Android 看得到）。
    func testASampleUnderADeletedFolderInTheIndexStaysVisible() {
        let store = makeStore()
        let id = "seed-kairumo-manual-v1"
        let folder = UUID().uuidString.lowercased()
        AccountSyncStore.shared.record(id: folder, title: "舊資料夾", parentId: nil, isFolder: true)
        AccountSyncStore.shared.record(id: id, title: "手冊", parentId: folder, isFolder: false)
        AccountSyncStore.shared.recordDeletion(id: folder)
        XCTAssertFalse(store.isHiddenBySync(id), "範例不會因為索引裡的資料夾被刪而被藏起來")
        XCTAssertTrue(store.visibleNotebooks.contains { $0.id == id })
    }

    /// 使用者回報：從回收桶還原的筆記本出現在「繼續」，卻不在「全部筆記」。它帶著刪除前的資料夾，
    /// 那個資料夾已經不在了，樹上無處可放。
    func testANotebookWhoseFolderIsGoneShowsAsUnfiled() {
        let store = makeStore()
        var mine = NotebookDocument(title: "還原的筆記", pageCount: 1)
        mine.folderId = "folder-that-was-deleted"
        store.notebooks.append(mine)
        XCTAssertNil(store.treeFolderId(of: mine))
        XCTAssertTrue(store.notebooks(in: nil).contains { $0.id == mine.id }, "放在「未分類」")

        // 從回收桶還原時直接放回「未分類」。
        store.deleteNotebook(id: mine.id)
        XCTAssertTrue(store.restoreNotebook(id: mine.id))
        XCTAssertNil(store.notebooks.first { $0.id == mine.id }?.folderId)
    }

    func testAFolderWhoseParentIsGoneShowsAtTheTop() {
        let store = makeStore()
        let orphan = store.createFolder(name: "孤兒資料夾", parentId: "parent-that-was-deleted")
        XCTAssertTrue(store.subfolders(of: nil).contains { $0.id == orphan.id })
    }

    func testRestoredNotebookAndNewFolderSurviveSyncReconciliation() {
        let store = makeStore()
        let syncStore = AccountSyncStore.shared
        defer { syncStore.resetLocalSyncState(account: "test") }

        let oldFolder = store.createFolder(name: "舊圖學資料夾")
        var note = NotebookDocument(title: "圖學範例副本", pageCount: 1)
        note.folderId = oldFolder.id
        store.notebooks.append(note)
        syncStore.record(id: note.id, title: note.title, parentId: oldFolder.id, isFolder: false)

        // 先刪筆記本進回收桶，再刪舊資料夾
        store.deleteNotebook(id: note.id)
        store.deleteFolder(id: oldFolder.id)

        // 從回收桶還原後，必須立刻出現在 visibleNotebooks（「全部筆記」）
        XCTAssertTrue(store.restoreNotebook(id: note.id))
        XCTAssertFalse(store.isHiddenBySync(note.id))
        XCTAssertTrue(store.visibleNotebooks.contains { $0.id == note.id })

        // 重新建立新資料夾並將圖學範例加進去，經過多輪同步收斂後資料夾與範例都不得消失
        let newFolder = store.createFolder(name: "圖學資料夾", parentId: oldFolder.id)
        store.moveNotebook(id: "seed-drafting-example-v1", toFolderId: newFolder.id)
        store.moveNotebook(id: note.id, toFolderId: newFolder.id)

        store.reconcileFoldersAndAssignmentsFromSync()
        store.reconcileFoldersAndAssignmentsFromSync()

        XCTAssertTrue(store.folders.contains { $0.id.caseInsensitiveCompare(newFolder.id) == .orderedSame }, "新資料夾在同步收斂後不得消失")
        let drafting = store.visibleNotebooks.first { $0.id == "seed-drafting-example-v1" }
        XCTAssertNotNil(drafting)
        XCTAssertEqual(drafting?.folderId?.lowercased(), newFolder.id.lowercased())
    }

    func testAnOrdinaryNotebookStillSyncs() {
        let store = makeStore()
        let mine = NotebookDocument(title: "我的筆記", pageCount: 1)
        store.notebooks.append(mine)
        XCTAssertTrue(store.syncNotebooks.contains { $0.id == mine.id })
    }

    /// 過去同步把「各裝置各自產生、id 不同」的同一份內容合併成兩份：重設之後只剩標準那一份。
    func testDuplicatedSeedContentIsResetToTheCanonicalCopy() throws {
        let store = makeStore()
        let id = "seed-feature-showcase-v1"
        let index = try XCTUnwrap(store.notebooks.firstIndex { $0.id == id })
        let canonicalTexts = store.notebooks[index].textAttachments?.count ?? 0
        let canonicalShapes = store.notebooks[index].shapeAttachments?.count ?? 0
        XCTAssertGreaterThan(canonicalTexts, 0)

        // 模擬被合併成兩份：每個物件再複製一份（新的 id）。
        let texts = store.notebooks[index].textAttachments ?? []
        let shapes = store.notebooks[index].shapeAttachments ?? []
        func reId<T: Codable>(_ item: T) -> T {
            var json = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(item))) as? [String: Any] ?? [:]
            json["id"] = UUID().uuidString
            return try! JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: json))
        }
        store.notebooks[index].textAttachments = texts + texts.map(reId)
        store.notebooks[index].shapeAttachments = shapes + shapes.map(reId)
        XCTAssertEqual(store.notebooks[index].textAttachments?.count, canonicalTexts * 2)

        // 舊版使用者：還沒做過這次重設。
        ProfileDefaults.current.set(0, forKey: "seed.contentGeneration")
        store.backfillEmptySeedNotebooks()

        let healed = try XCTUnwrap(store.notebooks.first { $0.id == id })
        XCTAssertEqual(healed.textAttachments?.count, canonicalTexts, "文字物件還是重複的")
        XCTAssertEqual(healed.shapeAttachments?.count, canonicalShapes, "形狀物件還是重複的")
        XCTAssertEqual(healed.pageCount, 4)
    }

    /// 重設只做一次：之後使用者在範例上加的東西不會每次啟動都被清掉。
    func testTheResetRunsOnlyOnce() throws {
        let store = makeStore()
        let id = "seed-feature-showcase-v1"
        ProfileDefaults.current.set(0, forKey: "seed.contentGeneration")
        store.backfillEmptySeedNotebooks() // 第一次：重設並記下世代
        let index = try XCTUnwrap(store.notebooks.firstIndex { $0.id == id })
        let before = store.notebooks[index].textAttachments?.count ?? 0
        store.notebooks[index].textAttachments = (store.notebooks[index].textAttachments ?? [])
            + [NoteTextAttachment(pageIndex: 0, text: "使用者加的", fontSize: 12, isBold: false,
                                  alignmentRaw: "left", textColorHex: "#000000", backgroundColorHex: "clear",
                                  hasBorder: false, x: 10, y: 10, width: 100, height: 20)]
        store.backfillEmptySeedNotebooks() // 第二次：不該再動
        XCTAssertEqual(store.notebooks.first { $0.id == id }?.textAttachments?.count, before + 1)
    }

    /// 標準內容本身不能有重複：同一頁、同一段文字、同一個位置不該出現兩次。
    func testCanonicalSeedContentHasNoDuplicateObjects() {
        let store = makeStore()
        for doc in store.notebooks where NotebookPackageBridge.isDeviceLocalSeed(doc.id) {
            var seen = Set<String>()
            for t in doc.textAttachments ?? [] {
                let key = "\(t.pageIndex)|\(t.text)|\(Int(t.x))|\(Int(t.y))"
                XCTAssertTrue(seen.insert(key).inserted, "\(doc.id) 的文字物件重複：\(t.text.prefix(20))")
            }
            var shapeKeys = Set<String>()
            for sh in doc.shapeAttachments ?? [] {
                let key = "\(sh.pageIndex)|\(sh.label)|\(sh.kindName)|\(Int(sh.x))|\(Int(sh.y))|\(Int(sh.width))|\(Int(sh.height))"
                XCTAssertTrue(shapeKeys.insert(key).inserted, "\(doc.id) 的形狀物件重複：\(sh.label.prefix(20))")
            }
            let ids = (doc.textAttachments ?? []).map(\.id) + (doc.shapeAttachments ?? []).map(\.id)
            XCTAssertEqual(ids.count, Set(ids).count, "\(doc.id) 有重複的物件 id")
        }
    }

    /// 驗證若「歡迎使用Kairumo」被膨脹成 9 頁、「課堂與會議記錄」被膨脹成 15 頁，自癒能收斂回 3 頁並重整確定性 ID
    func testInflatedMeetingAndWelcomeNotebooksAreHealedToStandardCounts() throws {
        let store = makeStore()
        let welcomeIdx = try XCTUnwrap(store.notebooks.firstIndex { $0.id == "seed-welcome-notebook-v1" })
        let meetingIdx = try XCTUnwrap(store.notebooks.firstIndex { $0.id == "seed-meeting-notebook-v1" })

        // 模擬跨裝置 CRDT 膨脹成 9 頁與 15 頁
        store.notebooks[welcomeIdx].pageCount = 9
        store.notebooks[welcomeIdx].pagesData = Array(repeating: Data(), count: 9)
        store.notebooks[welcomeIdx].pageIds = (0..<9).map { _ in UUID().uuidString.lowercased() }

        store.notebooks[meetingIdx].pageCount = 15
        store.notebooks[meetingIdx].pagesData = Array(repeating: Data(), count: 15)
        store.notebooks[meetingIdx].pageIds = (0..<15).map { _ in UUID().uuidString.lowercased() }

        let didHeal = store.healInflatedSeedNotebooksIfNeeded()
        XCTAssertTrue(didHeal, "應該觸發自癒修復")

        let healedWelcome = try XCTUnwrap(store.notebooks.first { $0.id == "seed-welcome-notebook-v1" })
        XCTAssertEqual(healedWelcome.pageCount, 3, "歡迎筆記應收斂回標準 3 頁")
        XCTAssertEqual(healedWelcome.pagesData.count, 3)
        XCTAssertEqual(healedWelcome.pageIds, NotebookPackageBridge.deterministicSeedPageIds(for: "seed-welcome-notebook-v1"))

        let healedMeeting = try XCTUnwrap(store.notebooks.first { $0.id == "seed-meeting-notebook-v1" })
        XCTAssertEqual(healedMeeting.pageCount, 3, "會議記錄應收斂回標準 3 頁")
        XCTAssertEqual(healedMeeting.pagesData.count, 3)
        XCTAssertEqual(healedMeeting.pageIds, NotebookPackageBridge.deterministicSeedPageIds(for: "seed-meeting-notebook-v1"))
    }

    /// 驗證範例筆記（如圖學範例）在「另存可編輯副本」後，專業筆刷、原題題目線、輔助線及文字物件皆完整保留
    func testSaveCopyPreservesDraftingExampleStrokesAndObjects() throws {
        let store = makeStore()
        let id = "seed-drafting-example-v1"
        guard let original = store.notebooks.first(where: { $0.id == id }) else {
            XCTFail("Drafting example missing")
            return
        }
        let originalProCount = ProInkStore.load(in: store.drawingsDirectory, notebookId: id, page: 0).count
        XCTAssertGreaterThan(originalProCount, 0, "Page 0 should have drafted strokes")
        let originalTextCount = original.textAttachments?.count ?? 0
        XCTAssertGreaterThan(originalTextCount, 0, "Drafting example should have text attachments")

        store.beginSampleSession(id)
        let copy = store.finishSampleSession(id, choice: .saveCopy)
        XCTAssertNotNil(copy)
        guard let copy else { return }

        // 驗證複本有在清單第一位
        XCTAssertEqual(store.notebooks.first?.id, copy.id)

        // 驗證新筆記的磁碟筆跡檔有被正確複製並可載入
        let copyProCount = ProInkStore.load(in: store.drawingsDirectory, notebookId: copy.id, page: 0).count
        XCTAssertEqual(copyProCount, originalProCount, "Copy must preserve pro ink strokes")

        // 驗證文字與物件完整繼承
        XCTAssertEqual(copy.textAttachments?.count, originalTextCount, "Copy must preserve text attachments")

        // 驗證核心套件成功產生
        let packageURL = store.corePackagesDirectory.appending(path: "\(copy.id).padnote")
        XCTAssertTrue(FileManager.default.fileExists(atPath: packageURL.path), "Package should exist")
    }
}

/// 打開（讀取）範例筆記本的套件不能慢：編輯器在主執行緒上做這件事（切換畫筆時會存檔並讀基準），
/// 慢到被系統看門狗殺掉就是「工具列全部點不動」。
@MainActor
final class SeedPackageOpenCostTests: XCTestCase {
    func testReadingEachSeedPackageIsFast() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-seed-cost-\(UUID().uuidString)")
        let store = NotebookStore(testDocumentsRoot: dir)
        store.loadData()
        store.backfillEmptySeedNotebooks()

        for doc in store.notebooks where NotebookPackageBridge.isDeviceLocalSeed(doc.id) {
            let drawings = (0..<doc.pageCount).map { store.loadDrawing(notebookId: doc.id, pageIndex: $0) }
            let package = dir.appendingPathComponent("\(doc.id).padnote")
            try? FileManager.default.removeItem(at: package)
            try NotebookPackageBridge.export(document: doc, drawings: drawings, to: package, deviceId: 0xA1)

            let started = Date()
            _ = try NotebookPackageBridge.drawings(fromPackageAt: package, deviceId: 0xA1)
            let elapsed = Date().timeIntervalSince(started)
            print("SEEDCOST \(doc.id) \(String(format: "%.3f", elapsed))s")
            XCTAssertLessThan(elapsed, 1.5, "\(doc.id) 讀取套件要 \(elapsed) 秒，主執行緒上做這件事會卡死")
        }
    }
}
