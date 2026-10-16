import PencilKit
import XCTest
@testable import Kairumo

/// iPad 上把錄音改名，整條同步（匯出 → 搬檔 → 匯入）跑起來，另一台裝置有沒有收到新名字。
/// 與 `RecordingRenameTwoDeviceTests` 不同：這裡走的是**真正的同步主流程**（`NotebookSyncCoordinator.run`），
/// 包含「沒有變動就不重做」的判斷 —— 改名不在文件裡，那個判斷最容易把它略過。
@MainActor
final class RecordingRenameSyncRoundTests: XCTestCase {
    private var workDir: URL!
    private var cloud: URL!
    private var ipad: FakeStore!
    private var mac: FakeStore!
    private let ipadId: UInt32 = 0xA1
    private let macId: UInt32 = 0xB2

    override func setUpWithError() throws {
        workDir = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("kairumo-rename-\(UUID().uuidString)", isDirectory: true)
        cloud = workDir.appendingPathComponent("Cloud", isDirectory: true)
        try FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)
        ipad = FakeStore(root: workDir.appendingPathComponent("iPad", isDirectory: true))
        mac = FakeStore(root: workDir.appendingPathComponent("Mac", isDirectory: true))
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: workDir) }

    @discardableResult
    private func sync(_ store: FakeStore, _ id: UInt32) async -> NotebookSyncCoordinator.Report {
        await NotebookSyncCoordinator.run(store: store, folder: cloud, deviceId: id)
    }

    private func record(_ title: String, file: String, notebook: String?) -> AudioRecordingRecord {
        AudioRecordingRecord(title: title, durationSeconds: 6, fileName: file, linkedNotebookId: notebook)
    }

    private func putAudio(_ store: FakeStore, notebookId: String, name: String) throws {
        let dir = store.syncPackagesDirectory
            .appendingPathComponent("\(notebookId.lowercased()).padnote/media/audio")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(repeating: 9, count: 4096).write(to: dir.appendingPathComponent(name))
    }

    /// `renameRecording` 做的事：清單改名、名字直接寫進套件、筆記本標成有修改。
    private func rename(_ store: FakeStore, notebookId: String, file: String, to name: String, device: UInt32) {
        if let index = store.recordings.firstIndex(where: { $0.fileName == file }) { store.recordings[index].title = name }
        let package = store.syncPackagesDirectory.appendingPathComponent("\(notebookId.lowercased()).padnote")
        XCTAssertTrue(NotebookPackageBridge.writeRecordingTitle(
            packagePath: package.path, fileName: file, title: name, deviceId: device))
        if let index = store.documents.firstIndex(where: { $0.id == notebookId }) {
            store.documents[index].lastModifiedDate = Date()
        }
    }

    private func scenario(inbox: Bool) async throws {
        let notebookId = inbox ? recordingInboxNotebookId() : UUID().uuidString.lowercased()
        var note = NotebookDocument(id: notebookId, title: inbox ? "錄音收件匣" : "會議", pageCount: 1)
        note.hasRecording = true
        ipad.documents = [note]
        let file = "ipad-take.opus"
        ipad.recordings = [record("語音錄音與對齊 2026/10/13 晚上 8:50", file: file, notebook: notebookId)]

        // 第一輪：筆記本與錄音都出去。
        await sync(ipad, ipadId)
        try putAudio(ipad, notebookId: notebookId, name: file)
        await sync(ipad, ipadId)
        await sync(mac, macId)

        // 使用者在 iPad 上把錄音改名。
        rename(ipad, notebookId: notebookId, file: file, to: "週會錄音", device: ipadId)
        _ = await sync(ipad, ipadId)
        _ = await sync(mac, macId)

        let delivered = mac.appliedTitles.contains { $0[file] == "週會錄音" }
        XCTAssertTrue(delivered, "改名沒有到 Mac。Mac 收到過的名字：\(mac.appliedTitles)")
    }

    func testARenamedInboxRecordingReachesTheOtherDevice() async throws {
        try await scenario(inbox: true)
    }

    func testARenamedRecordingInAnOrdinaryNotebookReachesTheOtherDevice() async throws {
        try await scenario(inbox: false)
    }

    /// 連續改兩次名（第二次是在第一次已經同步過之後）。
    func testRenamingTwiceKeepsGoing() async throws {
        let notebookId = recordingInboxNotebookId()
        var note = NotebookDocument(id: notebookId, title: "錄音收件匣", pageCount: 1)
        note.hasRecording = true
        ipad.documents = [note]
        let file = "twice.opus"
        ipad.recordings = [record("語音錄音與對齊 2026/10/13 晚上 8:50", file: file, notebook: notebookId)]
        await sync(ipad, ipadId)
        try putAudio(ipad, notebookId: notebookId, name: file)
        await sync(ipad, ipadId)
        await sync(mac, macId)

        for name in ["第一版名字", "第二版名字"] {
            rename(ipad, notebookId: notebookId, file: file, to: name, device: ipadId)
            await sync(ipad, ipadId)
            await sync(mac, macId)
            XCTAssertTrue(mac.appliedTitles.contains { $0[file] == name }, "「\(name)」沒有到 Mac：\(mac.appliedTitles)")
        }
    }
}

/// 使用者回報：「每同步一次，頁數就一直擴增」（課堂與會議記錄 18 → 36 → 48 頁）。
/// 三台裝置輪流編輯、同步同一本筆記好幾輪，頁數必須一直是原本那幾頁。
@MainActor
final class PageCountStabilityTests: XCTestCase {
    private var workDir: URL!
    private var cloud: URL!
    private var devices: [(store: FakeStore, id: UInt32)] = []

    override func setUpWithError() throws {
        workDir = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("kairumo-pages-\(UUID().uuidString)", isDirectory: true)
        cloud = workDir.appendingPathComponent("Cloud", isDirectory: true)
        try FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)
        devices = [("iPad", 0xA1), ("Mac", 0xB2), ("iPhone", 0xC3)].map { name, id in
            (FakeStore(root: workDir.appendingPathComponent(name, isDirectory: true)), UInt32(id))
        }
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: workDir) }

    private func stroke(_ x: CGFloat) -> PKStroke {
        let points = (0..<4).map {
            PKStrokePoint(location: CGPoint(x: x + CGFloat($0) * 10, y: 50), timeOffset: TimeInterval($0) * 0.01,
                          size: CGSize(width: 3, height: 3), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()))
    }

    private func pageCounts(_ id: String) -> [Int] {
        devices.map { $0.store.documents.first { $0.id == id }?.pageCount ?? -1 }
    }

    private func run(document: NotebookDocument, everyoneHasItFromTheStart: Bool) async throws {
        let id = document.id
        devices[0].store.documents = [document]
        if everyoneHasItFromTheStart {
            for d in devices.dropFirst() { d.store.documents = [document] }
        }
        for round in 0..<5 {
            for (i, d) in devices.enumerated() {
                if let index = d.store.documents.firstIndex(where: { $0.id == id }) {
                    var ink = d.store.syncLoadDrawing(notebookId: id, pageIndex: 0)
                    ink.strokes.append(stroke(CGFloat(round * 40 + i * 10)))
                    d.store.syncSaveDrawing(notebookId: id, pageIndex: 0, drawing: ink)
                    d.store.documents[index].lastModifiedDate = Date()
                }
                _ = await NotebookSyncCoordinator.run(store: d.store, folder: cloud, deviceId: d.id)
            }
            let counts = pageCounts(id)
            XCTAssertEqual(counts, [3, 3, 3], "第 \(round + 1) 輪之後頁數：\(counts)")
        }
    }

    func testANotebookCreatedOnOneDeviceKeepsItsPages() async throws {
        let doc = NotebookDocument(title: "會議", pageCount: 3)
        try await run(document: doc, everyoneHasItFromTheStart: false)
    }

    /// 舊版的筆記沒有記頁面 id（`pageIds == nil`），而且每台都有同一本（例如舊版同步過的範例）。
    func testALegacyNotebookEveryDeviceAlreadyHasKeepsItsPages() async throws {
        var doc = NotebookDocument(title: "課堂與會議記錄", pageCount: 3)
        doc.pageIds = nil
        try await run(document: doc, everyoneHasItFromTheStart: true)
    }

    /// 刪掉的頁要在每一台都刪掉，而且之後幾輪不會被別台的 oplog 加回來。
    /// 以前 Apple 刪頁只是「重建的 oplog 裡沒有這一頁」，別台檔案裡的 `AddPage` 一合併就把它帶回來；
    /// 而且套件比工作副本多頁時根本不匯出，下一次匯入直接把刪掉的頁蓋回來。
    func testADeletedPageStaysDeletedOnEveryDevice() async throws {
        let doc = NotebookDocument(title: "刪頁", pageCount: 3)
        let id = doc.id
        devices[0].store.documents = [doc]
        for _ in 0..<2 {
            for d in devices { _ = await NotebookSyncCoordinator.run(store: d.store, folder: cloud, deviceId: d.id) }
        }
        XCTAssertEqual(pageCounts(id), [3, 3, 3])

        // 和 `NotebookStore.deletePage` 一樣：沒記頁面 id 的先採用套件裡的那批。
        var mine = devices[0].store.documents[0]
        var ids = try XCTUnwrap(devices[1].store.documents.first?.pageIds)
        let removed = ids.remove(at: 1)
        mine.pageIds = ids
        mine.pageCount = 2
        mine.lastModifiedDate = Date()
        devices[0].store.documents[0] = mine
        SyncDeletedPages.record([removed], id)
        defer { SyncDeletedPages.setPending([], id) }

        for round in 0..<4 {
            for d in devices { _ = await NotebookSyncCoordinator.run(store: d.store, folder: cloud, deviceId: d.id) }
            XCTAssertEqual(pageCounts(id), [2, 2, 2], "第 \(round + 1) 輪之後頁數：\(pageCounts(id))")
        }
        for d in devices {
            XCTAssertFalse(d.store.documents[0].pageIds?.contains(removed) ?? true)
        }
    }
}

