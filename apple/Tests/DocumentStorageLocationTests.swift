//
//  DocumentStorageLocationTests.swift
//  KairumoTests
//

import XCTest
@testable import Kairumo

@MainActor
final class DocumentStorageLocationTests: XCTestCase {
    private var temporaryRoot: URL!

    override func setUpWithError() throws {
        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-storage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }

    func testDefaultLibraryNameIsUserVisibleAndStable() {
        XCTAssertEqual(DocumentStorageLocation.defaultFolderName, "Kairumo Doc")
    }

    func testMovingLibraryCopiesMetadataPackagesAndRecordings() throws {
        let source = temporaryRoot.appendingPathComponent("source", isDirectory: true)
        let destination = temporaryRoot.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(
            at: source.appendingPathComponent("Packages/note.padnote/doc/ops"),
            withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: source.appendingPathComponent("Kairumo Record"),
            withIntermediateDirectories: true)
        try Data("[]".utf8).write(to: source.appendingPathComponent("notebooks_v1.json"))
        try Data("operation".utf8).write(
            to: source.appendingPathComponent("Packages/note.padnote/doc/ops/a.oplog"))
        try Data("audio".utf8).write(
            to: source.appendingPathComponent("Kairumo Record/legacy.m4a"))

        try DocumentStorageLocation.copyDirectoryContents(from: source, to: destination)

        XCTAssertEqual(
            try String(contentsOf: destination.appendingPathComponent("notebooks_v1.json")),
            "[]")
        XCTAssertEqual(
            try String(contentsOf: destination.appendingPathComponent(
                "Packages/note.padnote/doc/ops/a.oplog")),
            "operation")
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: destination.appendingPathComponent("Kairumo Record/legacy.m4a").path))
    }

    func testLibraryManifestKeepsStableIdentityAfterCopy() throws {
        let source = temporaryRoot.appendingPathComponent("source", isDirectory: true)
        let destination = temporaryRoot.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let original = try DocumentStorageLocation.ensureManifest(in: source)

        try DocumentStorageLocation.copyDirectoryContents(from: source, to: destination)
        let copied = try DocumentStorageLocation.readManifest(in: destination)

        XCTAssertEqual(copied.libraryId, original.libraryId)
        XCTAssertEqual(copied.schemaVersion, 1)
    }

    // MARK: - iCloud、進度、驗證、清舊的

    private func makeLibrary(_ name: String, files: [String: String]) throws -> URL {
        let root = temporaryRoot.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for (relative, content) in files {
            let url = root.appendingPathComponent(relative)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(content.utf8).write(to: url)
        }
        return root
    }

    func testICloudDetection() {
        XCTAssertFalse(DocumentStorageLocation.isICloudSynced(temporaryRoot), "一般暫存目錄不該被當成 iCloud")
        let viaDrive = URL(fileURLWithPath:
            "/Users/someone/Library/Mobile Documents/com~apple~CloudDocs/Kairumo Doc")
        XCTAssertTrue(DocumentStorageLocation.isICloudSynced(viaDrive), "iCloud 雲碟的路徑要認得")
    }

    func testCopyReportsProgressAndVerifyAcceptsAGoodCopy() throws {
        let source = try makeLibrary("src", files: ["a.json": "1", "Packages/p/x.oplog": "22", "Attachments/i.png": "333"])
        let destination = temporaryRoot.appendingPathComponent("dst", isDirectory: true)
        let updates = LockedBox<[DocumentStorageLocation.MoveProgress]>([])
        try DocumentStorageLocation.copyLibrary(from: source, to: destination) { update in
            updates.mutate { $0.append(update) }
        }
        XCTAssertEqual(updates.value.last?.copiedFiles, 3)
        XCTAssertEqual(updates.value.last?.totalFiles, 3)
        XCTAssertNoThrow(try DocumentStorageLocation.verifyCopy(from: source, to: destination))
    }

    func testVerifyRejectsAMissingOrTruncatedFile() throws {
        let source = try makeLibrary("src2", files: ["a.json": "hello", "b.json": "world"])
        let destination = temporaryRoot.appendingPathComponent("dst2", isDirectory: true)
        try DocumentStorageLocation.copyLibrary(from: source, to: destination, progress: nil)

        try Data("he".utf8).write(to: destination.appendingPathComponent("a.json")) // 截短
        XCTAssertThrowsError(try DocumentStorageLocation.verifyCopy(from: source, to: destination),
                             "大小不同的檔案不能通過驗證")
        try Data("hello".utf8).write(to: destination.appendingPathComponent("a.json"))
        try FileManager.default.removeItem(at: destination.appendingPathComponent("b.json"))
        XCTAssertThrowsError(try DocumentStorageLocation.verifyCopy(from: source, to: destination),
                             "少一個檔案不能通過驗證")
    }

    func testCopyResumesWithoutRecopyingFilesThatAreAlreadyThere() throws {
        let source = try makeLibrary("src3", files: ["a.json": "same", "b.json": "data"])
        let destination = temporaryRoot.appendingPathComponent("dst3", isDirectory: true)
        try DocumentStorageLocation.copyLibrary(from: source, to: destination, progress: nil)
        let marker = destination.appendingPathComponent("a.json")
        let before = try FileManager.default.attributesOfItem(atPath: marker.path)[.modificationDate] as? Date
        Thread.sleep(forTimeInterval: 1.1)
        try DocumentStorageLocation.copyLibrary(from: source, to: destination, progress: nil)
        let after = try FileManager.default.attributesOfItem(atPath: marker.path)[.modificationDate] as? Date
        XCTAssertEqual(before, after, "已經在目的地、大小一樣的檔案不該重複複製")
    }

    func testCancellationStopsTheCopy() throws {
        let source = try makeLibrary("src4", files: (0..<50).reduce(into: [:]) { $0["f\($1).txt"] = "x" })
        let destination = temporaryRoot.appendingPathComponent("dst4", isDirectory: true)
        let task = Task.detached {
            try DocumentStorageLocation.copyLibrary(from: source, to: destination, progress: nil)
        }
        task.cancel()
        XCTAssertThrowsError(try { try awaitResult(task) }(), "取消要讓複製中止")
    }

    func testResetClearsTheLibraryButKeepsTheSpeechModels() throws {
        let root = try makeLibrary("resetMe", files: [
            "notebooks_v1.json": "[]", "Packages/p/x.oplog": "ops", "Attachments/a.png": "img",
            "models/whisper/model.bin": "big", "MigrationBackup-2026/old.json": "old",
        ])
        let result = DocumentStorageLocation.clearLibraryContents(at: root, keeping: ["models"])
        XCTAssertEqual(result.failed, 0)
        let left = Set((try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? [])
        XCTAssertEqual(left, ["models"], "除了保留的語音模型，其他都該被清掉")
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: root.appendingPathComponent("models/whisper/model.bin").path),
            "語音模型（幾百 MB）不該被刪")
    }

    func testResetOnlyTouchesTheRootsDirectChildren() throws {
        let outside = try makeLibrary("outside", files: ["precious.txt": "keep"])
        let root = try makeLibrary("inside", files: ["a.json": "1"])
        DocumentStorageLocation.clearLibraryContents(at: root)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: outside.appendingPathComponent("precious.txt").path), "不能往根目錄外面動")
    }

    func testOldLibraryIsRemovedOnlyWhenItIsTheSameLibrary() throws {
        let old = try makeLibrary("oldLib", files: ["notebooks_v1.json": "[]"])
        try DocumentStorageLocation.ensureManifest(in: old)
        let new = temporaryRoot.appendingPathComponent("newLib", isDirectory: true)
        try DocumentStorageLocation.copyLibrary(from: old, to: new, progress: nil)
        XCTAssertTrue(DocumentStorageLocation.removeOldLibraryIfSame(old, as: new), "同一份資料庫的舊副本該被移除")
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path))

        let mine = try makeLibrary("someoneElses", files: ["notes.txt": "important"])
        try DocumentStorageLocation.ensureManifest(in: mine)
        let other = try makeLibrary("unrelated", files: ["x": "y"])
        try DocumentStorageLocation.ensureManifest(in: other)
        XCTAssertFalse(DocumentStorageLocation.removeOldLibraryIfSame(mine, as: other), "識別碼不同的一律不碰")
        XCTAssertTrue(FileManager.default.fileExists(atPath: mine.path))

        let plain = try makeLibrary("noManifest", files: ["keep.txt": "me"])
        XCTAssertFalse(DocumentStorageLocation.removeOldLibraryIfSame(plain, as: new), "沒有識別檔的資料夾不碰")
        XCTAssertTrue(FileManager.default.fileExists(atPath: plain.path))
    }
}

/// 測試用的執行緒安全盒子（進度回呼可能來自別的執行緒）。
private final class LockedBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: T
    init(_ value: T) { storage = value }
    var value: T { lock.lock(); defer { lock.unlock() }; return storage }
    func mutate(_ body: (inout T) -> Void) { lock.lock(); body(&storage); lock.unlock() }
}

/// 同步等一個 detached 任務的結果（測試用）。
private func awaitResult(_ task: Task<Void, Error>) throws {
    let done = DispatchSemaphore(value: 0)
    var failure: Error?
    Task {
        do { try await task.value } catch { failure = error }
        done.signal()
    }
    done.wait()
    if let failure { throw failure }
}
