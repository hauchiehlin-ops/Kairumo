//
//  SyncFixesTests.swift
//  KairumoTests
//
//  實機回報的同步問題：被登出、一直在同步、錄音卡片消失、日誌時間不對、錄音名稱帶筆記本名。
//

import PencilKit
import XCTest
@testable import Kairumo

/// 會呼叫 `persistData()` 的測試不能碰 `NotebookStore.shared`。
///
/// Apple 單元測試與後面的 UI 測試使用同一台 Simulator；shared store 寫進 App
/// container 後，即使 `defer` 把記憶體陣列還原，磁碟上的測試資料仍會留給下一個
/// `xcodebuild`。結果 UI 測試的種子筆記消失，所有要進編輯器的案例一起失敗。
@MainActor
private func isolatedNotebookStore() -> NotebookStore {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("kairumo-sync-tests-\(UUID().uuidString)", isDirectory: true)
    return NotebookStore(testDocumentsRoot: dir)
}

@MainActor
final class SyncFixesTests: XCTestCase {

    // MARK: 被登出

    func testADriveRateLimitIsNotTreatedAsAnAuthorisationFailure() {
        // 實測：兩台裝置開著一段時間之後雙雙被登出。Drive 用 403 回報速率限制，
        // 當成 PermissionDenied 會讓平台登出並**撤銷**授權。
        for reason in ["rateLimitExceeded", "userRateLimitExceeded", "sharingRateLimitExceeded", "quotaExceeded"] {
            let body = "{\"error\":{\"code\":403,\"errors\":[{\"reason\":\"\(reason)\"}]}}"
            let error = DriveHttpClient.classify(status: 403, path: "/files", detail: body)
            guard case .Backend = error else {
                return XCTFail("\(reason) 被當成授權問題：\(error)")
            }
            XCTAssertTrue(DriveHttpClient.isRateLimit(body: Data(body.utf8)))
        }
    }

    func testARealAuthorisationFailureStillAsksForASignIn() {
        let forbidden = "{\"error\":{\"code\":403,\"errors\":[{\"reason\":\"forbidden\"}]}}"
        guard case .PermissionDenied = DriveHttpClient.classify(status: 403, path: "/f", detail: forbidden) else {
            return XCTFail("真正的 403 要請使用者重新登入")
        }
        guard case .PermissionDenied = DriveHttpClient.classify(status: 401, path: "/f", detail: "") else {
            return XCTFail("401 要請使用者重新登入")
        }
        guard case .NotFound = DriveHttpClient.classify(status: 404, path: "/f", detail: "") else {
            return XCTFail("404 是找不到")
        }
        guard case .Backend = DriveHttpClient.classify(status: 503, path: "/f", detail: "") else {
            return XCTFail("5xx 是可重試的後端錯誤")
        }
    }

    // MARK: 日誌時間

    @MainActor
    func testALogLineKeepsTheTimeItHappenedNotTheTimeItWasWritten() {
        let logger = SyncLogger.shared
        logger.clear()
        let happened = Date(timeIntervalSinceNow: -240)
        logger.log("四分鐘前發生的事", at: happened)
        XCTAssertEqual(logger.entries.last?.timestamp, happened,
                       "日誌要記事件發生的時間；主執行緒忙時才輪到寫入，不能拿寫入時間當發生時間")
    }

    // MARK: 錄音名稱

    func testANewRecordingIsNotNamedAfterTheNotebook() {
        let title = NotebookStore.defaultRecordingTitle(at: Date(timeIntervalSince1970: 0))
        XCTAssertFalse(title.contains("mac建立"))
        XCTAssertTrue(title.hasPrefix(LocalizationManager.shared.localized("recording_suffix")),
                      "名稱應該以「錄音」開頭、後面接時間：\(title)")
    }

    // MARK: 匯入不吃掉剛新增的物件

    private func doc(audio: [String]) -> NotebookDocument {
        var d = NotebookDocument(title: "N", pageCount: 1)
        d.audioAttachments = audio.map { NoteAudioAttachment(id: $0, fileName: "\($0).opus", title: $0) }
        return d
    }

    private func snapshot(_ d: NotebookDocument) -> [String: Int] {
        ExportedObjectIds.fingerprints(of: d)
    }

    func testAnObjectAddedAfterTheExportSurvivesTheImport() {
        // 一輪同步是「匯出 → 等網路 → 匯入」，匯入是整份取代。等網路時使用者插了一段錄音，
        // 它不在匯出的套件裡，整份取代之後就消失了（回報：一同步錄音卡片就不見）。
        let exportedDoc = doc(audio: ["old"])
        let imported = doc(audio: ["old"])
        let local = doc(audio: ["old", "just-added"])
        let (merged, preserved) = NotebookSyncCoordinator.preservingLocalChanges(
            imported, local: local, exported: snapshot(exportedDoc))
        XCTAssertEqual(merged.audioAttachments?.map(\.id), ["old", "just-added"])
        XCTAssertTrue(preserved, "有保住新增物件時不能標成「已同步」，它還沒進套件")
    }

    func testAnObjectMovedAfterTheExportDoesNotJumpBack() {
        // 回報：畫布上的物件移不動，一同步就回到原位。移動發生在匯出之後、匯入之前，
        // 匯入的結果是舊位置。
        var exportedDoc = doc(audio: [])
        exportedDoc.textAttachments = [NoteTextAttachment(id: "t", text: "hi", x: 10, y: 10)]
        let imported = exportedDoc // 套件裡還是舊位置
        var local = exportedDoc
        local.textAttachments?[0].x = 300
        local.textAttachments?[0].y = 400
        let (merged, preserved) = NotebookSyncCoordinator.preservingLocalChanges(
            imported, local: local, exported: snapshot(exportedDoc))
        XCTAssertEqual(merged.textAttachments?.first?.x, 300)
        XCTAssertEqual(merged.textAttachments?.first?.y, 400)
        XCTAssertTrue(preserved, "移動還沒進套件，下一輪要匯出")
    }

    func testAnotherDevicesMoveIsAcceptedWhenIDidNotTouchTheObject() {
        // 我沒動過它（指紋與匯出當下相同），別台移動的結果要接受。
        var exportedDoc = doc(audio: [])
        exportedDoc.textAttachments = [NoteTextAttachment(id: "t", text: "hi", x: 10, y: 10)]
        var imported = exportedDoc
        imported.textAttachments?[0].x = 500
        let (merged, preserved) = NotebookSyncCoordinator.preservingLocalChanges(
            imported, local: exportedDoc, exported: snapshot(exportedDoc))
        XCTAssertEqual(merged.textAttachments?.first?.x, 500)
        XCTAssertFalse(preserved)
    }

    func testAnObjectAnotherDeviceDeletedStaysDeleted() {
        // 匯出當下就有、匯入結果沒有 = 別台刪掉的。補回去會讓刪除復活。
        let exportedDoc = doc(audio: ["gone"])
        let imported = doc(audio: [])
        let (merged, preserved) = NotebookSyncCoordinator.preservingLocalChanges(
            imported, local: exportedDoc, exported: snapshot(exportedDoc))
        XCTAssertTrue(merged.audioAttachments?.isEmpty ?? true)
        XCTAssertFalse(preserved)
    }

    func testWithoutAnExportSnapshotNothingIsTouched() {
        let imported = doc(audio: ["a"])
        let (merged, preserved) = NotebookSyncCoordinator.preservingLocalChanges(
            imported, local: doc(audio: ["a", "b"]), exported: nil)
        XCTAssertEqual(merged.audioAttachments?.map(\.id), ["a"], "沒有名單就分不出「新增」與「被刪」，不能補")
        XCTAssertFalse(preserved)
    }

    // MARK: - 資料夾結構與筆記所屬階層跨裝置收斂 (G-05)

    func testRemoteFolderStructureReconcilesToLocalStore() {
        let store = isolatedNotebookStore()
        let syncStore = AccountSyncStore.shared
        defer { syncStore.resetLocalSyncState(account: "test") }

        // 模擬遠端同步過來的 index.json：頂層資料夾 f_work，子資料夾 f_sub，筆記本 n1 在 f_sub
        syncStore.record(id: "f_work", title: "工作筆記", parentId: nil, isFolder: true)
        syncStore.record(id: "f_sub", title: "專案A", parentId: "f_work", isFolder: true)
        syncStore.record(id: "n1", title: "專案會議", parentId: "f_sub", isFolder: false)

        var note = NotebookDocument(id: "n1", title: "專案會議", pageCount: 1)
        note.folderId = nil // 本機尚未歸類
        store.notebooks = [note]
        store.folders = []

        store.reconcileFoldersAndAssignmentsFromSync()

        // 驗證本機 folders 陣列已同步建立
        XCTAssertEqual(store.folders.count, 2)
        let topFolders = store.subfolders(of: nil)
        XCTAssertEqual(topFolders.count, 1)
        XCTAssertEqual(topFolders.first?.name, "工作筆記")
        XCTAssertEqual(topFolders.first?.id, "f_work")

        let childFolders = store.subfolders(of: "f_work")
        XCTAssertEqual(childFolders.count, 1)
        XCTAssertEqual(childFolders.first?.name, "專案A")
        XCTAssertEqual(childFolders.first?.id, "f_sub")

        // 驗證筆記本已被歸入子資料夾
        XCTAssertEqual(store.notebooks.first?.folderId, "f_sub")
        let notesInSub = store.notebooks(in: "f_sub")
        XCTAssertEqual(notesInSub.count, 1)
        XCTAssertEqual(notesInSub.first?.id, "n1")

        // 驗證未分類筆記為空
        let unfiled = store.notebooks(in: nil)
        XCTAssertTrue(unfiled.isEmpty)
    }

    func testRemoteFolderRenameAndMoveConverges() {
        let store = isolatedNotebookStore()
        let syncStore = AccountSyncStore.shared
        defer { syncStore.resetLocalSyncState(account: "test") }

        syncStore.record(id: "f_proj", title: "原專案", parentId: nil, isFolder: true)
        syncStore.record(id: "n2", title: "開發筆記", parentId: nil, isFolder: false)

        let note = NotebookDocument(id: "n2", title: "開發筆記", pageCount: 1)
        store.notebooks = [note]
        store.folders = [FolderItem(id: "f_proj", name: "原專案", parentId: nil)]

        // 遠端更名與將筆記移入該資料夾
        syncStore.record(id: "f_proj", title: "全新專案名稱", parentId: nil, isFolder: true)
        syncStore.record(id: "n2", title: "開發筆記", parentId: "f_proj", isFolder: false)

        store.reconcileFoldersAndAssignmentsFromSync()

        XCTAssertEqual(store.folders.first?.name, "全新專案名稱")
        XCTAssertEqual(store.notebooks.first?.folderId, "f_proj")
        XCTAssertEqual(store.notebooks(in: "f_proj").count, 1)
    }

    func testRemoteFolderDeletionRemovesLocalFolder() {
        let store = isolatedNotebookStore()
        let syncStore = AccountSyncStore.shared
        defer { syncStore.resetLocalSyncState(account: "test") }

        syncStore.record(id: "f_trash", title: "要刪除的資料夾", parentId: nil, isFolder: true)
        store.folders = [FolderItem(id: "f_trash", name: "要刪除的資料夾", parentId: nil)]

        // 遠端標記刪除（墓碑）
        syncStore.recordDeletion(id: "f_trash")

        store.reconcileFoldersAndAssignmentsFromSync()

        XCTAssertTrue(store.folders.isEmpty)
        XCTAssertTrue(store.subfolders(of: nil).isEmpty)
    }
}

// MARK: - 錄音改名要跟著同步

@MainActor
final class RecordingRenameSyncTests: XCTestCase {

    private func record(_ title: String, file: String, id: String = UUID().uuidString) -> AudioRecordingRecord {
        AudioRecordingRecord(id: id, title: title, durationSeconds: 5, fileName: file)
    }

    private func notebook(cardTitle: String, file: String, recordingId: String) -> NotebookDocument {
        var doc = NotebookDocument(title: "N", pageCount: 1)
        doc.audioAttachments = [NoteAudioAttachment(recordingId: recordingId, fileName: file, title: cardTitle)]
        return doc
    }

    func testARenameMadeOnAnotherDeviceReachesTheRecordingList() {
        // Mac 改名 → 卡片名稱同步到 iPad；iPad 的清單用的是自己替同一個檔案產生的 id，
        // 所以只能用檔名對。
        let list = [record("錄音 10/1 06:33", file: "A.opus", id: "ipad-id")]
        let books = [notebook(cardTitle: "週會紀錄", file: "a.opus", recordingId: "mac-id")]
        let result = NotebookStore.adoptingCardTitles(list, notebooks: books)
        XCTAssertEqual(result.first?.title, "週會紀錄")
    }

    func testARecordingWithoutACardKeepsItsName() {
        let list = [record("我的錄音", file: "b.opus")]
        let result = NotebookStore.adoptingCardTitles(list, notebooks: [NotebookDocument(title: "N", pageCount: 1)])
        XCTAssertEqual(result.first?.title, "我的錄音")
    }

    func testAnEmptyCardTitleNeverBlanksTheList() {
        let list = [record("我的錄音", file: "c.opus")]
        let books = [notebook(cardTitle: "   ", file: "c.opus", recordingId: "x")]
        XCTAssertEqual(NotebookStore.adoptingCardTitles(list, notebooks: books).first?.title, "我的錄音")
    }

    func testRenamingARecordingMadeOnAnotherDeviceUpdatesItsCardToo() {
        // 卡片上的錄音 id 是建立那台裝置的；這台改名時要用檔名找到卡片，名字才會同步回去。
        let store = isolatedNotebookStore()

        let rec = record("舊名字", file: "d.opus", id: "ipad-id")
        store.recordings = [rec]
        store.notebooks = [notebook(cardTitle: "舊名字", file: "d.opus", recordingId: "mac-id")]
        store.renameRecording(id: "ipad-id", newTitle: "新名字")
        XCTAssertEqual(store.notebooks.first?.audioAttachments?.first?.title, "新名字")
        XCTAssertEqual(store.recordings.first?.title, "新名字")
    }
}

// MARK: - 沒有卡片的錄音，名字也跟著套件同步

@MainActor
final class RecordingTitleInPackageTests: XCTestCase {

    private var workDir: URL!
    private let deviceA: UInt32 = 0x0A0A0A0A
    private let deviceB: UInt32 = 0x0B0B0B0B

    override func setUpWithError() throws {
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-rectitle-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workDir)
    }

    private func doc() -> NotebookDocument { NotebookDocument(title: "R", pageCount: 1) }

    func testTheNameOfARecordingWithoutACardTravelsInThePackage() throws {
        let package = workDir.appendingPathComponent("t.padnote")
        try NotebookPackageBridge.export(
            document: doc(), drawings: [PKDrawing()], to: package, deviceId: deviceB,
            recordingTitles: ["a.opus": "週會紀錄"])
        let imported = try NotebookPackageBridge.importDocument(fromPackageAt: package, deviceId: deviceA)
        XCTAssertEqual(imported.recordingTitles["a.opus"], "週會紀錄")
        // 名字區塊不能被當成圖片載入，也不能變成多出來的物件。
        XCTAssertTrue(imported.document.attachments?.isEmpty ?? true)
    }

    func testARenameOnTheOtherDeviceWinsOverTheOriginalName() throws {
        let package = workDir.appendingPathComponent("rename.padnote")
        // Mac（B）錄的，名字 T0。
        try NotebookPackageBridge.export(
            document: doc(), drawings: [PKDrawing()], to: package, deviceId: deviceB,
            recordingTitles: ["a.opus": "T0"])
        // iPad（A）匯入後改名為 T1，再匯出。
        let first = try NotebookPackageBridge.importDocument(fromPackageAt: package, deviceId: deviceA)
        XCTAssertEqual(first.recordingTitles["a.opus"], "T0")
        try NotebookPackageBridge.exportPreservingOtherDevices(
            document: first.document, drawings: [PKDrawing()], to: package, deviceId: deviceA,
            pageIds: first.pageIds, recordingTitles: ["a.opus": "T1"])
        // Mac 還不知道，照舊匯出自己的 T0。
        try NotebookPackageBridge.exportPreservingOtherDevices(
            document: doc(), drawings: [PKDrawing()], to: package, deviceId: deviceB,
            pageIds: first.pageIds, recordingTitles: ["a.opus": "T0"])
        let merged = try NotebookPackageBridge.importDocument(fromPackageAt: package, deviceId: deviceB)
        XCTAssertEqual(merged.recordingTitles["a.opus"], "T1", "iPad 後改的名字要贏過 Mac 重匯出的舊名字")
    }

    func testImportedTitlesUpdateTheListButNotARenameMadeSinceTheExport() {
        let store = isolatedNotebookStore()
        store.recordings = [
            AudioRecordingRecord(title: "舊", durationSeconds: 1, fileName: "a.opus"),
            AudioRecordingRecord(title: "我剛改的", durationSeconds: 1, fileName: "b.opus"),
        ]
        store.applyRecordingTitles(
            ["a.opus": "別台改的", "b.opus": "別台對 b 的名字"],
            exported: ["a.opus": "舊", "b.opus": "匯出當時的名字"])
        XCTAssertEqual(store.recordings[0].title, "別台改的")
        XCTAssertEqual(store.recordings[1].title, "我剛改的", "匯出之後我又改過，不能被蓋掉")
    }

    func testRenamingARecordingMarksItsNotebookModifiedSoTheNextRoundExportsIt() {
        let store = isolatedNotebookStore()

        var book = NotebookDocument(title: "N", pageCount: 1)
        book.lastModifiedDate = Date(timeIntervalSince1970: 0)
        store.notebooks = [book]
        let rec = AudioRecordingRecord(
            id: "r1", title: "舊", durationSeconds: 1, fileName: "z.opus", linkedNotebookId: book.id)
        store.recordings = [rec]
        store.renameRecording(id: "r1", newTitle: "新")
        XCTAssertGreaterThan(store.notebooks[0].lastModifiedDate, Date(timeIntervalSince1970: 1),
                             "沒有卡片的錄音改名不動筆記，同步就以為沒有東西要匯出")
    }

    func testRenamingUnlinkedRecordingMarksInboxModified() {
        let store = isolatedNotebookStore()
        let rec = AudioRecordingRecord(
            id: "unlinked-1", title: "快速錄音", durationSeconds: 1, fileName: "quick.opus", linkedNotebookId: nil)
        store.recordings = [rec]
        store.renameRecording(id: "unlinked-1", newTitle: "自訂快速錄音")
        XCTAssertEqual(store.recordings[0].title, "自訂快速錄音")
        let inboxId = recordingInboxNotebookId()
        let inbox = store.notebooks.first { $0.id.caseInsensitiveCompare(inboxId) == .orderedSame }
        XCTAssertNotNil(inbox, "未關聯筆記本的錄音改名應自動歸入收件匣")
        XCTAssertGreaterThan(inbox?.lastModifiedDate ?? Date.distantPast, Date(timeIntervalSince1970: 1))
    }

    private func exportInputs(titles: [String: String], document: NotebookDocument) throws
        -> NotebookSyncCoordinator.ExportInputs
    {
        let baseline = workDir.appendingPathComponent("baseline", isDirectory: true)
        try FileManager.default.createDirectory(at: baseline, withIntermediateDirectories: true)
        return NotebookSyncCoordinator.ExportInputs(
            document: document,
            package: workDir.appendingPathComponent("sync.padnote"),
            baselineDirectory: baseline,
            attachmentsDirectory: workDir,
            drawingsDirectory: workDir,
            deviceId: deviceA,
            loadDrawing: { _, _ in PKDrawing() },
            recordingTitles: titles)
    }

    /// 實際同步走的是 `exportOne`，不是直接呼叫橋接層：它漏傳名字的時候，
    /// 橋接層的測試全綠，而別台永遠只看得到預設名稱。
    func testTheSyncExportWritesRecordingTitlesIntoThePackage() throws {
        let inputs = try exportInputs(titles: ["a.opus": "週會紀錄"], document: doc())
        _ = try NotebookSyncCoordinator.exportOne(inputs)
        let imported = try NotebookPackageBridge.importDocument(
            fromPackageAt: inputs.package, deviceId: deviceB)
        XCTAssertEqual(imported.recordingTitles["a.opus"], "週會紀錄")
    }

    /// 只有 manifest、沒有任何 oplog 的套件，檔案時間比工作副本新時，原本被判成
    /// 「已經包含」而永遠不匯出 —— 雲端清單有條目、卻永遠沒有內容。
    func testAPackageWithoutAnyOplogIsAlwaysExported() throws {
        let inputs = try exportInputs(titles: [:], document: doc())
        _ = try NotebookSyncCoordinator.exportOne(inputs)
        XCTAssertFalse(NotebookSyncCoordinator.workingCopyNeedsExport(inputs))
        // 模擬「只剩 manifest」：套件在、時間比工作副本新、但沒有任何操作記錄。
        let opsDir = inputs.package.appendingPathComponent("doc/ops")
        for url in try FileManager.default.contentsOfDirectory(at: opsDir, includingPropertiesForKeys: nil)
        where url.pathExtension == "oplog" {
            try FileManager.default.removeItem(at: url)
        }
        XCTAssertTrue(NotebookSyncCoordinator.workingCopyNeedsExport(inputs),
                      "沒有 oplog 的套件從來沒匯出過，不能因為時間較新就略過")
        _ = try NotebookSyncCoordinator.exportOne(inputs)
        XCTAssertFalse(NotebookSyncCoordinator.workingCopyNeedsExport(inputs))
    }

    func testANewOrRenamedTitleForcesAnExportEvenWhenThePackageLooksNewer() throws {
        let first = try exportInputs(titles: ["a.opus": "T0"], document: doc())
        _ = try NotebookSyncCoordinator.exportOne(first)
        XCTAssertFalse(NotebookSyncCoordinator.workingCopyNeedsExport(first),
                       "名字都已經在套件裡，不該白匯出")
        let renamed = try exportInputs(titles: ["a.opus": "T1"], document: doc())
        XCTAssertTrue(NotebookSyncCoordinator.workingCopyNeedsExport(renamed),
                      "改名之後套件的檔案時間較新，仍然要匯出")
        let added = try exportInputs(titles: ["a.opus": "T0", "b.opus": "新錄的"], document: doc())
        XCTAssertTrue(NotebookSyncCoordinator.workingCopyNeedsExport(added))
    }

    /// 移動／縮放膠帶只改物件：套件的檔案時間比文件新時，原本會被判成不必匯出，
    /// 下一次匯入就把舊位置蓋回來。
    func testMovingATapeForcesAnExportEvenWhenThePackageLooksNewer() throws {
        var book = doc()
        book.tapeAttachments = [NoteTapeAttachment(
            id: "11111111-1111-1111-1111-111111111111", pageIndex: 0,
            rect: CGRect(x: 10, y: 10, width: 100, height: 32))]
        let first = try exportInputs(titles: [:], document: book)
        _ = try NotebookSyncCoordinator.exportOne(first)
        XCTAssertFalse(NotebookSyncCoordinator.workingCopyNeedsExport(first), "沒改就不該白匯出")

        var moved = book
        moved.tapeAttachments?[0].rect = CGRect(x: 80, y: 200, width: 160, height: 32)
        moved.lastModifiedDate = Date(timeIntervalSince1970: 0)  // 比套件舊：只看檔案時間會判成不必匯出
        let after = try exportInputs(titles: [:], document: moved)
        XCTAssertTrue(NotebookSyncCoordinator.workingCopyNeedsExport(after))
    }

    /// Android 寫過物件寫法的 `rect`，Apple 原本整筆解不開；兩種寫法都要讀得出真正的位置與大小。
    func testTapeRectDecodesFromAppleArrayAndFromObjectForms() throws {
        let decoder = JSONDecoder()
        let apple = Data(##"{"id":"a","pageIndex":1,"rect":[[10,20],[100,30]],"isRevealed":true,"colorHex":"#FFD1DC"}"##.utf8)
        let a = try decoder.decode(NoteTapeAttachment.self, from: apple)
        XCTAssertEqual(a.rect, CGRect(x: 10, y: 20, width: 100, height: 30))
        let object = Data(#"{"id":"b","pageIndex":0,"rect":{"origin":{"x":5,"y":6},"size":{"width":70,"height":32}}}"#.utf8)
        let b = try decoder.decode(NoteTapeAttachment.self, from: object)
        XCTAssertEqual(b.rect, CGRect(x: 5, y: 6, width: 70, height: 32))
        // 來回編碼仍是 Apple 的寫法。
        let again = try decoder.decode(NoteTapeAttachment.self, from: try JSONEncoder().encode(a))
        XCTAssertEqual(again, a)
    }

    func testAddingARecordingMarksItsNotebookModified() {
        let store = isolatedNotebookStore()
        var book = NotebookDocument(title: "N", pageCount: 1)
        book.lastModifiedDate = Date(timeIntervalSince1970: 0)
        store.notebooks = [book]
        store.addRecording(
            title: "新錄音", durationSeconds: 3, fileName: "n.opus",
            linkedNotebookId: book.id.uppercased())
        XCTAssertGreaterThan(store.notebooks[0].lastModifiedDate, Date(timeIntervalSince1970: 1))
    }

    func testApplyRecordingTitlesUpdatesBothRecordingsAndCanvasCards() {
        let store = isolatedNotebookStore()
        store.recordings = [
            AudioRecordingRecord(title: "舊標題", durationSeconds: 5, fileName: "card.opus")
        ]
        var book = NotebookDocument(title: "測試本", pageCount: 1)
        book.audioAttachments = [
            NoteAudioAttachment(
                id: "card-1", pageIndex: 0, recordingId: "some-id",
                fileName: "card.opus", title: "舊標題", durationSeconds: 5,
                x: 0, y: 0, width: 100, height: 50, hasBorder: false, cornerRadius: 8
            )
        ]
        store.notebooks = [book]

        store.applyRecordingTitles(["card.opus": "遠端新標題"], exported: nil)
        XCTAssertEqual(store.recordings.first?.title, "遠端新標題")
        XCTAssertEqual(store.notebooks.first?.audioAttachments?.first?.title, "遠端新標題", "套用遠端錄音名稱時，畫布上的卡片也必須同步更新，防止後續覆蓋")
    }
}

/// 預載的《Kairumo手冊》：全部是手繪筆畫。資源（與 Android 同一份）要真的在 bundle 裡、
/// 解得出來，每一頁都有夠多的筆畫，而且填進筆記本之後沒有任何文字、形狀、圖片物件。
@MainActor
final class KairumoManualSeedTests: XCTestCase {

    func testTheInkResourceIsBundledAndHasFourPagesOfStrokes() {
        let drawings = SeedContent.kairumoManualDrawings()
        XCTAssertEqual(drawings.count, 4, "手冊資源沒有進 bundle 或解不開")
        for (index, drawing) in drawings.enumerated() {
            XCTAssertGreaterThan(drawing.strokes.count, 100, "第 \(index + 1) 頁的筆畫太少")
        }
    }

    /// 繁體與簡體中文都是手寫版：沒有任何文字方塊，每一頁筆畫夠多，每個段落有自己的顏色。
    func testTheChineseManualsAreInkOnlyAndUseDifferentColoursPerSection() {
        for language in [AppLanguage.zhHant, .zhHans] {
            assertInkOnlyManual(language)
        }
    }

    private func assertInkOnlyManual(_ language: AppLanguage) {
        let saved = LocalizationManager.snapshotLanguage
        defer { LocalizationManager.snapshotLanguage = saved }
        LocalizationManager.snapshotLanguage = language
        let drawings = SeedContent.kairumoManualDrawings(language: language)
        XCTAssertEqual(drawings.count, 4, "\(language)")
        for (index, drawing) in drawings.enumerated() {
            XCTAssertGreaterThan(drawing.strokes.count, 100, "\(language) 第 \(index + 1) 頁的筆畫太少")
        }
        var doc = NotebookDocument(id: SeedContent.kairumoManualId, title: SeedContent.kairumoManualTitle, pageCount: 4)
        SeedContent.fillKairumoManual(&doc)
        XCTAssertEqual(doc.pageCount, 4)
        XCTAssertTrue((doc.textAttachments ?? []).isEmpty)
        XCTAssertTrue((doc.shapeAttachments ?? []).isEmpty)
        XCTAssertTrue((doc.attachments ?? []).isEmpty)
        XCTAssertTrue((doc.tableAttachments ?? []).isEmpty)
        let colours = Set(drawings.flatMap { $0.strokes }.map { stroke -> String in
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            stroke.ink.color.getRed(&r, green: &g, blue: &b, alpha: &a)
            return String(format: "%02x%02x%02x", Int(r * 255), Int(g * 255), Int(b * 255))
        })
        XCTAssertGreaterThanOrEqual(colours.count, 5, "每個段落要有自己的顏色")
    }

    /// 英／日／韓／泰：同一套手繪插圖＋該語言排版的文字方塊（手寫只有中文：筆順資料只有漢字）。
    func testEveryOtherLanguageGetsTheSameIllustrationsWithTypedText() {
        let saved = LocalizationManager.snapshotLanguage
        defer { LocalizationManager.snapshotLanguage = saved }
        for language in [AppLanguage.en, .ja, .ko, .th] {
            LocalizationManager.snapshotLanguage = language
            var doc = NotebookDocument(id: SeedContent.kairumoManualId, title: "x", pageCount: 4)
            SeedContent.fillKairumoManual(&doc)
            XCTAssertEqual(doc.pageCount, 4, "\(language)")
            let texts = doc.textAttachments ?? []
            for page in 0..<4 {
                XCTAssertFalse(texts.filter { $0.pageIndex == page }.isEmpty, "\(language) 第 \(page + 1) 頁沒有文字方塊")
            }
            // 英／韓／泰的文字方塊裡不該混進漢字（日文本來就有漢字）。
            let han = texts.map(\.text).joined().unicodeScalars.filter { (0x4E00...0x9FFF).contains($0.value) }
            if language == .en || language == .th || language == .ko {
                XCTAssertTrue(han.isEmpty, "\(language) 的手冊文字裡混進了漢字")
            }
        }
    }

    func testTheManualTitleFollowsTheInterfaceLanguage() {
        let saved = LocalizationManager.snapshotLanguage
        defer { LocalizationManager.snapshotLanguage = saved }
        LocalizationManager.snapshotLanguage = .en
        XCTAssertEqual(LocalizationManager.localizedString("seed_manual_title"), "Kairumo Manual")
        LocalizationManager.snapshotLanguage = .zhHant
        XCTAssertEqual(LocalizationManager.localizedString("seed_manual_title"), SeedContent.kairumoManualTitle)
    }

    func testTheStrokeDataLicenceTravelsWithTheApp() {
        // 筆順資料來自 Arphic 字型（Arphic Public License）：授權全文要隨 App 一起散布。
        for name in ["ARPHICPL", "NOTICE", "OFL-NotoSansThai"] {
            let ext = name == "ARPHICPL" ? "TXT" : "txt"
            let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Templates")
                ?? Bundle.main.url(forResource: name, withExtension: ext)
            XCTAssertNotNil(url, "\(name).\(ext) 沒有進 bundle")
        }
    }

    func testTheLegacyTitleStaysRecognisable() {
        // 升級上來的舊筆記用這個固定的繁中名稱認出手冊並補上語系鍵。
        XCTAssertEqual(SeedContent.kairumoManualTitle, "Kairumo手冊")
    }
}

/// 橡皮擦擦掉的筆畫過一陣子又回來：匯出把這台的舊筆畫檔換掉，但同步看檔案大小，
/// 雲端較大的舊檔又被下載回來。本機要記住自己擦過什麼，匯入時濾掉。
final class ErasedInkLedgerTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("erased-ink-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func stroke(_ x: CGFloat) -> PKStroke {
        let points = (0 ..< 5).map { i in
            PKStrokePoint(location: CGPoint(x: x + CGFloat(i) * 10, y: 20), timeOffset: TimeInterval(i) * 0.01,
                          size: CGSize(width: 3, height: 3), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()))
    }

    func testAnErasedStrokeIsFilteredOutOfTheMergedDrawingAndAReDrawnOneIsNot() {
        let a = stroke(10), b = stroke(200)
        let baseline = PKDrawing(strokes: [a, b])
        let afterErase = PKDrawing(strokes: [b])
        let removed = StrokeDelta.removed(in: afterErase, since: baseline)
        XCTAssertEqual(removed.count, 1)

        ErasedInkLedger.record(removed: removed, added: [], in: dir, notebookId: "nb", page: 0)
        let erased = ErasedInkLedger.load(in: dir, notebookId: "nb", page: 0)
        XCTAssertEqual(erased.count, 1)

        // 同步合併回來的圖（雲端舊檔把 a 帶回來了）。
        let merged = PKDrawing(strokes: [a, b])
        let filtered = ErasedInkLedger.filtered(merged, erased: erased)
        XCTAssertEqual(filtered.strokes.count, 1, "擦掉的筆畫不能因為同步而復活")

        // 復原擦除（又把同一筆加回來）→ 從名單拿掉，之後不再濾。
        ErasedInkLedger.record(removed: [], added: [a], in: dir, notebookId: "nb", page: 0)
        XCTAssertTrue(ErasedInkLedger.load(in: dir, notebookId: "nb", page: 0).isEmpty)
    }

    func testRemovedFindsEverythingWhenTheDrawingIsEmptied() {
        let baseline = PKDrawing(strokes: [stroke(10), stroke(200)])
        XCTAssertEqual(StrokeDelta.removed(in: PKDrawing(), since: baseline).count, 2)
    }
}
