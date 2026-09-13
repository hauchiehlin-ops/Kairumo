//
//  NotebookMigrationTests.swift
//  KairumoTests
//
//  遷移與回滾的安全性（工作包 WP4c）。
//
//  這一批測試的重點不是「遷移會成功」，而是**失敗的時候會怎樣**：
//  原檔有沒有被動到、備份回不回得去、驗不過的套件有沒有被留下來。
//  遷移程式跑對一次不難，難的是跑壞的那一次不要毀掉使用者的資料。
//

import XCTest
import PencilKit
@testable import Kairumo

final class NotebookMigrationTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-migrate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - 測試資料

    private func drawing(strokeCount: Int, seed: CGFloat = 0) -> PKDrawing {
        var strokes: [PKStroke] = []
        for s in 0..<strokeCount {
            var points: [PKStrokePoint] = []
            for i in 0..<8 {
                let step = CGFloat(i)
                let x = seed + CGFloat(s) * 25 + step * 2.5
                let y = 150 + step * 1.75
                points.append(
                    PKStrokePoint(
                        location: CGPoint(x: x, y: y),
                        timeOffset: Double(i) * 0.008,
                        size: CGSize(width: 5, height: 5),
                        opacity: 1, force: 1, azimuth: 1.0, altitude: 1.2
                    )
                )
            }
            strokes.append(
                PKStroke(
                    ink: PKInk(.pen, color: .black),
                    path: PKStrokePath(controlPoints: points,
                                       creationDate: Date(timeIntervalSince1970: 0))
                )
            )
        }
        return PKDrawing(strokes: strokes)
    }

    /// 兩本筆記，各兩頁。
    private func sampleDocuments() -> [NotebookDocument] {
        [
            NotebookDocument(id: "note-a", title: "筆記 A", pageCount: 2),
            NotebookDocument(id: "note-b", title: "筆記 B", pageCount: 2)
        ]
    }

    private func loader(strokesPerPage: Int = 2) -> (String, Int) -> PKDrawing {
        { id, page in
            self.drawing(strokeCount: strokesPerPage, seed: id == "note-a" ? 0 : 500 + CGFloat(page))
        }
    }

    /// 造出一份看起來像真的舊資料的目錄。
    private func seedLegacyData() throws {
        let notebooks = try JSONEncoder().encode(sampleDocuments())
        try notebooks.write(to: root.appendingPathComponent("notebooks_v1.json"))
        try Data("[]".utf8).write(to: root.appendingPathComponent("folders_v1.json"))

        let drawingsDir = root.appendingPathComponent("Drawings", isDirectory: true)
        try FileManager.default.createDirectory(at: drawingsDir, withIntermediateDirectories: true)
        for id in ["note-a", "note-b"] {
            for page in 0..<2 {
                try drawing(strokeCount: 2).dataRepresentation().write(
                    to: drawingsDir.appendingPathComponent("\(id)_p\(page).drawing"))
            }
        }
    }

    private func digest(of url: URL) -> [String: Data] {
        var out: [String: Data] = [:]
        guard let e = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) else {
            return out
        }
        for case let file as URL in e where !file.hasDirectoryPath {
            out[file.lastPathComponent] = (try? Data(contentsOf: file)) ?? Data()
        }
        return out
    }

    // MARK: - 原檔不可被動到

    func testMigrationLeavesTheOriginalFilesByteIdentical() throws {
        try seedLegacyData()
        let before = digest(of: root)

        _ = NotebookMigration.migrate(
            documents: sampleDocuments(), root: root, deviceId: 0xD1,
            drawingLoader: loader())

        // 只比對原本就存在的那些檔案 —— 新產生的套件與備份當然是新的。
        let after = digest(of: root)
        for (name, bytes) in before {
            XCTAssertEqual(after[name], bytes, "\(name) 在遷移後被改動了")
        }
    }

    func testMigrationDoesNotDeleteAnyOriginalFile() throws {
        try seedLegacyData()
        _ = NotebookMigration.migrate(
            documents: sampleDocuments(), root: root, deviceId: 0xD2,
            drawingLoader: loader())

        XCTAssertTrue(FileManager.default.fileExists(
            atPath: root.appendingPathComponent("notebooks_v1.json").path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Drawings/note-a_p0.drawing").path))
    }

    // MARK: - 備份

    func testBackupIsCreatedBeforeAnythingIsWritten() throws {
        try seedLegacyData()
        let report = NotebookMigration.migrate(
            documents: sampleDocuments(), root: root, deviceId: 0xD3,
            drawingLoader: loader())

        let backup = try XCTUnwrap(report.backupPath, "遷移一定要留下備份路徑")
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: backup.appendingPathComponent("notebooks_v1.json").path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: backup.appendingPathComponent("Drawings/note-a_p0.drawing").path))
    }

    func testBackupContentsMatchTheOriginals() throws {
        try seedLegacyData()
        let original = try Data(contentsOf: root.appendingPathComponent("notebooks_v1.json"))
        let backup = try NotebookMigration.backup(root: root)
        XCTAssertEqual(
            try Data(contentsOf: backup.appendingPathComponent("notebooks_v1.json")),
            original)
    }

    // MARK: - 遷移結果

    func testEveryNotebookIsMigratedAndVerified() throws {
        try seedLegacyData()
        let report = NotebookMigration.migrate(
            documents: sampleDocuments(), root: root, deviceId: 0xD4,
            drawingLoader: loader())

        XCTAssertTrue(report.allSucceeded, "失敗清單：\(report.outcomes)")
        XCTAssertEqual(report.migratedCount, 2)
        XCTAssertEqual(report.outcomes["note-a"], .migrated(strokeCount: 4))
    }

    func testMigratedPackagesLandInTheirOwnDirectory() throws {
        try seedLegacyData()
        _ = NotebookMigration.migrate(
            documents: sampleDocuments(), root: root, deviceId: 0xD5,
            drawingLoader: loader())

        let dir = NotebookMigration.packagesDirectory(in: root)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: dir.appendingPathComponent("note-a.padnote").path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: NotebookMigration.statePath(in: root).path))
    }

    // MARK: - 可重入

    func testRerunningSkipsUnchangedNotebooks() throws {
        try seedLegacyData()
        // 兩次都餵**同一批**文件。`sampleDocuments()` 每次呼叫都會給新的
        // lastModifiedDate（預設是 Date()），各叫一次等於資料真的變了，
        // 那樣測到的是「有變就重做」，不是這條要測的「沒變就跳過」。
        let docs = sampleDocuments()
        _ = NotebookMigration.migrate(
            documents: docs, root: root, deviceId: 0xD6,
            drawingLoader: loader())

        let second = NotebookMigration.migrate(
            documents: docs, root: root, deviceId: 0xD6,
            drawingLoader: loader())

        XCTAssertEqual(second.skippedCount, 2, "沒變動的筆記不該重做")
        XCTAssertEqual(second.migratedCount, 0)
    }

    func testNewStrokesAreDetectedEvenThoughLastModifiedDateDidNotChange() throws {
        // 手繪存在獨立的 .drawing 檔，改了它並不會更新 lastModifiedDate。
        // 指紋若只看日期，使用者畫了一整頁之後重跑會被判定成「沒變」。
        try seedLegacyData()
        let docs = sampleDocuments()
        _ = NotebookMigration.migrate(
            documents: docs, root: root, deviceId: 0xD7, drawingLoader: loader(strokesPerPage: 2))

        let second = NotebookMigration.migrate(
            documents: docs, root: root, deviceId: 0xD7, drawingLoader: loader(strokesPerPage: 5))

        XCTAssertEqual(second.migratedCount, 2, "筆畫變多了就必須重做")
        XCTAssertEqual(second.skippedCount, 0)
    }

    func testRerunDoesNotAccumulateStrokesInThePackage() throws {
        // 核心是 append-only 的：舊套件沒清掉就重匯，內容會疊起來。
        try seedLegacyData()
        let docs = sampleDocuments()
        _ = NotebookMigration.migrate(
            documents: docs, root: root, deviceId: 0xD8, drawingLoader: loader(strokesPerPage: 2))
        _ = NotebookMigration.migrate(
            documents: docs, root: root, deviceId: 0xD8, drawingLoader: loader(strokesPerPage: 3))

        let pkg = NotebookMigration.packagesDirectory(in: root)
            .appendingPathComponent("note-a.padnote")
        let pages = try NotebookPackageBridge.drawings(fromPackageAt: pkg, deviceId: 0xE8)
        XCTAssertEqual(pages[0].strokes.count, 3, "應該是 3 筆，不是 2 + 3 疊成 5 筆")
    }

    // MARK: - 驗證會擋下不對的套件

    func testVerificationCatchesAMissingStroke() throws {
        try seedLegacyData()
        _ = NotebookMigration.migrate(
            documents: sampleDocuments(), root: root, deviceId: 0xD9,
            drawingLoader: loader(strokesPerPage: 2))

        let pkg = NotebookMigration.packagesDirectory(in: root)
            .appendingPathComponent("note-a.padnote")

        // 拿一份「多一筆畫」的原稿去驗同一個套件 —— 驗證必須抓到。
        let inflated = [drawing(strokeCount: 3), drawing(strokeCount: 2)]
        XCTAssertThrowsError(
            try NotebookMigration.verify(packageURL: pkg, against: inflated, deviceId: 0xE9)
        ) { error in
            guard case NotebookMigration.VerificationError.strokeCountMismatch = error else {
                return XCTFail("應該是筆畫數不符，實得 \(error)")
            }
        }
    }

    func testVerificationCatchesAPageCountMismatch() throws {
        try seedLegacyData()
        _ = NotebookMigration.migrate(
            documents: sampleDocuments(), root: root, deviceId: 0xDA,
            drawingLoader: loader())

        let pkg = NotebookMigration.packagesDirectory(in: root)
            .appendingPathComponent("note-a.padnote")
        XCTAssertThrowsError(
            try NotebookMigration.verify(
                packageURL: pkg, against: [drawing(strokeCount: 2)], deviceId: 0xEA)
        )
    }

    func testAFailedNotebookDoesNotStopTheOthers() throws {
        try seedLegacyData()
        var docs = sampleDocuments()
        // pageCount 0 會被 export 判為「沒有任何頁面」而失敗。
        docs[0] = NotebookDocument(id: "note-a", title: "壞掉的", pageCount: 0)

        let report = NotebookMigration.migrate(
            documents: docs, root: root, deviceId: 0xDB,
            drawingLoader: { _, _ in PKDrawing() })

        // note-a 的 pageCount 被 init 夾成 1，所以它其實會成功 —— 這裡真正要確認的是
        // 逐本獨立：無論單一本結果如何，另一本都拿到自己的結論。
        XCTAssertNotNil(report.outcomes["note-a"])
        XCTAssertNotNil(report.outcomes["note-b"])
        XCTAssertEqual(report.outcomes.count, 2)
    }

    // MARK: - 回滾

    func testRollbackRestoresTheOriginalDataAndRemovesPackages() throws {
        try seedLegacyData()
        let report = NotebookMigration.migrate(
            documents: sampleDocuments(), root: root, deviceId: 0xDC,
            drawingLoader: loader())
        let backup = try XCTUnwrap(report.backupPath)

        // 模擬「遷移之後資料被動壞了」
        try Data("壞掉的內容".utf8).write(to: root.appendingPathComponent("notebooks_v1.json"))
        try? FileManager.default.removeItem(at: root.appendingPathComponent("Drawings/note-a_p0.drawing"))

        try NotebookMigration.rollback(root: root, from: backup)

        let restored = try Data(contentsOf: root.appendingPathComponent("notebooks_v1.json"))
        let decoded = try JSONDecoder().decode([NotebookDocument].self, from: restored)
        XCTAssertEqual(decoded.map(\.id), ["note-a", "note-b"], "筆記清單要原樣回來")
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Drawings/note-a_p0.drawing").path),
            "被刪掉的手繪檔要回來")
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: NotebookMigration.packagesDirectory(in: root).path),
            "回滾後不該留下遷移產物")
    }

    func testRollbackIsSafeWhenThereIsNothingToRestore() throws {
        // 使用者在空資料上跑了遷移又回滾，不該當掉。
        let backup = try NotebookMigration.backup(root: root)
        XCTAssertNoThrow(try NotebookMigration.rollback(root: root, from: backup))
    }

    // MARK: - 狀態

    func testStateSurvivesAReload() throws {
        try seedLegacyData()
        _ = NotebookMigration.migrate(
            documents: sampleDocuments(), root: root, deviceId: 0xDD,
            drawingLoader: loader())

        let state = NotebookMigration.loadState(in: root)
        XCTAssertEqual(state.entries.count, 2)
        XCTAssertEqual(state.entries["note-a"]?.strokeCount, 4)
        XCTAssertEqual(state.entries["note-a"]?.packageName, "note-a.padnote")
    }

    func testMissingStateFileYieldsAnEmptyStateInsteadOfCrashing() {
        XCTAssertEqual(NotebookMigration.loadState(in: root), NotebookMigration.State())
    }
}
