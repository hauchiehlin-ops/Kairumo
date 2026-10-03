import XCTest

@testable import Kairumo

/// 自動清理（`StorageSweeper`）：該清的清掉，不該動的絕不動。
final class StorageSweeperTests: XCTestCase {

    private var dir: URL!
    private let now = Date()

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sweeper-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    @discardableResult
    private func make(_ name: String, bytes: Int = 100, ageHours: Double) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try Data(count: bytes).write(to: url)
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-ageHours * 3600)], ofItemAtPath: url.path)
        return url
    }

    func testOldTempItemsAreSweptAndYoungOnesKept() throws {
        let old = try make("share_old.pdf", bytes: 500, ageHours: 5)
        let young = try make("share_new.pdf", ageHours: 0.2)
        let plan = StorageSweeper.plan(in: dir, minAge: StorageSweeper.tempMinAge, now: now)
        XCTAssertEqual(plan.items.map(\.lastPathComponent), ["share_old.pdf"])
        XCTAssertEqual(plan.bytes, 500)
        let done = StorageSweeper.execute(plan)
        XCTAssertEqual(done.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: young.path), "還很新的暫存檔被清掉了（可能正在使用）")
    }

    func testAFolderWithAFreshFileInsideIsNotConsideredOld() throws {
        // 同步的暫存資料夾：資料夾本身的時間很舊，但裡面剛寫過檔案 —— 還在用。
        let folder = dir.appendingPathComponent("pull-active", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let inner = folder.appendingPathComponent("a.oplog")
        try Data(count: 10).write(to: inner)
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-10 * 3600)], ofItemAtPath: folder.path)
        let plan = StorageSweeper.plan(in: dir, minAge: StorageSweeper.tempMinAge, now: now)
        XCTAssertTrue(plan.items.isEmpty, "裡面還有新檔案的資料夾被當成舊的")
    }

    func testAnOldFolderIsSweptWithItsContentsCounted() throws {
        let folder = dir.appendingPathComponent("import-stale", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let inner = folder.appendingPathComponent("x.bin")
        try Data(count: 2048).write(to: inner)
        let old = now.addingTimeInterval(-9 * 3600)
        try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: inner.path)
        try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: folder.path)
        let plan = StorageSweeper.plan(in: dir, minAge: StorageSweeper.tempMinAge, now: now)
        XCTAssertEqual(plan.items.count, 1)
        XCTAssertEqual(plan.bytes, 2048)
        XCTAssertEqual(StorageSweeper.execute(plan).bytes, 2048)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
    }

    func testOnlyStalePartialModelDownloadsAreSwept() throws {
        let stale = try make("whisper.partial", bytes: 300, ageHours: 15 * 24)
        let resuming = try make("other.partial", ageHours: 2 * 24)
        let finished = try make("whisper.bin", bytes: 300, ageHours: 40 * 24)
        let plan = StorageSweeper.plan(in: dir, minAge: StorageSweeper.partialMinAge, now: now) {
            $0.hasSuffix(".partial")
        }
        XCTAssertEqual(plan.items.map(\.lastPathComponent), ["whisper.partial"])
        StorageSweeper.execute(plan)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: resuming.path), "還在續傳窗口內的殘檔被清掉了")
        XCTAssertTrue(FileManager.default.fileExists(atPath: finished.path), "下載完成的模型被當成殘檔清掉了")
    }

    func testMissingDirectoryIsHarmless() {
        let plan = StorageSweeper.plan(in: dir.appendingPathComponent("nope"), minAge: 0)
        XCTAssertTrue(plan.items.isEmpty)
    }

    /// 回收桶期滿要在「從不同步」的情況下也會清（原本只在同步跑完一輪之後才呼叫）。
    @MainActor
    func testExpiredTrashIsPurgedWithoutAnySync() async {
        let store = NotebookStore(testDocumentsRoot: dir)
        let report = await StorageSweeper.sweepAtLaunch(store: store)
        XCTAssertEqual(report.trashPurged, 0)   // 沒有東西期滿也不會出錯
    }
}
