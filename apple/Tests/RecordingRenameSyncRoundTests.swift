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
