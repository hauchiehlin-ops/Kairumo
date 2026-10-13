import PencilKit
import XCTest
@testable import Kairumo

/// 兩台真的裝置的「錄音改名」：iPad 改名 → 寫進套件 → 雲端資料夾 → 另一台讀。
/// 單台裝置的測試全綠、使用者卻回報「改名一直傳不過去」，缺的就是這條：**兩台各自有自己的收件匣套件，
/// 合併之後，另一台去哪裡找名字**。
@MainActor
final class RecordingRenameTwoDeviceTests: XCTestCase {
    private var root: URL!
    private let ipad: UInt32 = 0xA1
    private let mac: UInt32 = 0xB2

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("rename-2dev-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    private var inboxId: String { recordingInboxNotebookId() }
    private func packageURL(_ device: String) -> URL {
        root.appendingPathComponent(device).appendingPathComponent("\(inboxId.lowercased()).padnote")
    }

    /// 與 `NotebookStore.packageSession` 同一條路：核心自己建一個有第一頁的套件。
    private func makeInbox(_ device: String, deviceId: UInt32) throws -> URL {
        let url = packageURL(device)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        _ = try PadnoteSession.create(path: url.path, title: "錄音收件匣", nowUnixMs: 1_791_900_000_000, deviceId: deviceId)
        return url
    }

    private func addFakeAudio(_ package: URL, name: String) throws {
        let dir = package.appendingPathComponent("media/audio")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(repeating: 7, count: 2048).write(to: dir.appendingPathComponent(name))
    }

    private func exportInputs(package: URL, deviceId: UInt32, titles: [String: String]) throws
        -> NotebookSyncCoordinator.ExportInputs
    {
        let work = package.deletingLastPathComponent()
        let baseline = work.appendingPathComponent("baseline")
        try FileManager.default.createDirectory(at: baseline, withIntermediateDirectories: true)
        var doc = NotebookDocument(id: inboxId, title: "錄音收件匣", pageCount: 1)
        doc.hasRecording = true
        return NotebookSyncCoordinator.ExportInputs(
            document: doc, package: package, baselineDirectory: baseline,
            attachmentsDirectory: work, drawingsDirectory: work, deviceId: deviceId,
            loadDrawing: { _, _ in PKDrawing() }, recordingTitles: titles)
    }

    func testARenameOnTheIPadReachesAMacThatAlreadyHasItsOwnInbox() throws {
        try runScenario(macCreatedFirst: true)
    }

    /// 兩個收件匣誰先建立，頁面順序就不同 —— 兩種順序都要找得到名字。
    func testTheSameWhenTheIPadInboxWasCreatedFirst() throws {
        try runScenario(macCreatedFirst: false)
    }

    private func runScenario(macCreatedFirst: Bool) throws {
        let cloud = root.appendingPathComponent("Cloud")
        try FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)

        // 兩台各自有自己的收件匣（Mac 以前錄過音，所以也有）。
        let ipadPkg: URL
        let macPkg: URL
        if macCreatedFirst {
            macPkg = try makeInbox("mac", deviceId: mac)
            Thread.sleep(forTimeInterval: 0.01)
            ipadPkg = try makeInbox("ipad", deviceId: ipad)
        } else {
            ipadPkg = try makeInbox("ipad", deviceId: ipad)
            Thread.sleep(forTimeInterval: 0.01)
            macPkg = try makeInbox("mac", deviceId: mac)
        }
        try addFakeAudio(macPkg, name: "mac-recording.opus")
        try addFakeAudio(ipadPkg, name: "ipad-recording.opus")

        // Mac 先同步上去一次（它的收件匣在雲端）。
        _ = try NotebookSyncCoordinator.exportOne(exportInputs(package: macPkg, deviceId: mac, titles: [:]))
        CloudSyncFolder.sync(localPackage: macPkg, into: cloud)

        // iPad 同步（拿到 Mac 的內容），然後使用者把自己的錄音改名，再同步。
        CloudSyncFolder.sync(localPackage: ipadPkg, into: cloud)
        _ = try NotebookSyncCoordinator.exportOne(
            exportInputs(package: ipadPkg, deviceId: ipad, titles: ["ipad-recording.opus": "週會錄音"]))
        CloudSyncFolder.sync(localPackage: ipadPkg, into: cloud)

        // Mac 再同步一輪，然後去找那個名字。
        CloudSyncFolder.sync(localPackage: macPkg, into: cloud)

        // 路 1：錄音清單掃描套件時讀名字（`refreshRecordings`）。
        let listed = NotebookStore.packageRecordingTitles(packageURL: macPkg)
        // 路 2：匯入整本筆記時讀名字（`importDocument` → `applyRecordingTitles`）。
        let imported = try NotebookPackageBridge.importDocument(fromPackageAt: macPkg, deviceId: mac)

        XCTAssertEqual(imported.recordingTitles["ipad-recording.opus"], "週會錄音", "匯入路徑讀不到 iPad 的改名")
        XCTAssertEqual(listed["ipad-recording.opus"], "週會錄音",
                       "錄音清單路徑讀不到 iPad 的改名（只看第一頁，而第一頁可能是 Mac 自己的）")
    }
}
