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
