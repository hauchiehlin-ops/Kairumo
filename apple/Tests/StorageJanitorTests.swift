//
//  StorageJanitorTests.swift
//  KairumoTests
//
//  清理沒人用的檔案：該清的清掉，**不該動的一個都不能動**。
//

import PencilKit
import XCTest
@testable import Kairumo

final class StorageJanitorTests: XCTestCase {

    private var root: URL!
    private var attachments: URL!
    private var drawings: URL!
    private var baseline: URL!
    private let now = Date()

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-janitor-\(UUID().uuidString)", isDirectory: true)
        attachments = root.appendingPathComponent("Attachments")
        drawings = root.appendingPathComponent("Drawings")
        baseline = root.appendingPathComponent("SyncBaseline")
        for dir in [attachments!, drawings!, baseline!] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private func write(_ name: String, in dir: URL, bytes: Int = 100, ageDays: Double) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try Data(repeating: 1, count: bytes).write(to: url)
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-ageDays * 86_400)], ofItemAtPath: url.path)
        return url
    }

    private func writeDrawing(_ name: String, strokes: Int, ageDays: Double) throws -> URL {
        var list: [PKStroke] = []
        for i in 0 ..< strokes {
            let points = (0 ..< 4).map {
                PKStrokePoint(location: CGPoint(x: CGFloat($0) * 5 + CGFloat(i), y: 10), timeOffset: Double($0) * 0.01,
                              size: CGSize(width: 3, height: 3), opacity: 1, force: 1, azimuth: 0, altitude: 1)
            }
            list.append(PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0))))
        }
        let url = drawings.appendingPathComponent(name)
        try PKDrawing(strokes: list).dataRepresentation().write(to: url)
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-ageDays * 86_400)], ofItemAtPath: url.path)
        return url
    }

    private func plan(
        notebooks: [StorageJanitor.NotebookInfo], referenced: Set<String> = [], protectedIds: Set<String> = []
    ) -> StorageJanitor.Plan {
        StorageJanitor.plan(
            attachmentsDirectory: attachments, pageDirectories: [drawings, baseline],
            notebooks: notebooks, protectedIds: protectedIds, referencedAttachments: referenced, now: now)
    }

    private func names(_ plan: StorageJanitor.Plan) -> Set<String> {
        Set(plan.files.map(\.lastPathComponent))
    }

    private let nb = StorageJanitor.NotebookInfo(id: "11111111-1111-1111-1111-111111111111", pageCount: 2)

    // MARK: 檔名

    func testOnlyRecognisedFileNamesAreEverTouched() {
        XCTAssertTrue(StorageJanitor.isAttachmentImageName("att_\(UUID().uuidString).png"))
        XCTAssertFalse(StorageJanitor.isAttachmentImageName("imp_\(UUID().uuidString).usdz"), "匯入檔不歸這裡管")
        XCTAssertFalse(StorageJanitor.isAttachmentImageName("att_notauuid.png"))
        XCTAssertFalse(StorageJanitor.isAttachmentImageName("photo.png"))
        XCTAssertEqual(StorageJanitor.pageFile(named: "abc_p3.drawing"), .init(notebookId: "abc", page: 3))
        XCTAssertEqual(StorageJanitor.pageFile(named: "a_b_p10.proink.json"), .init(notebookId: "a_b", page: 10))
        XCTAssertNil(StorageJanitor.pageFile(named: "notes.json"))
        XCTAssertNil(StorageJanitor.pageFile(named: "abc_pX.drawing"))
    }

    // MARK: 附件圖片

    func testAnUnreferencedOldAttachmentImageIsCleaned() throws {
        let orphan = "att_\(UUID().uuidString).png"
        let used = "att_\(UUID().uuidString).png"
        try write(orphan, in: attachments, bytes: 5_000, ageDays: 10)
        try write(used, in: attachments, ageDays: 10)
        let result = plan(notebooks: [nb], referenced: [used])
        XCTAssertEqual(names(result), [orphan])
        XCTAssertEqual(result.bytes, 5_000)
    }

    func testARecentAttachmentImageIsLeftAloneEvenIfNothingPointsToItYet() throws {
        // 復原、匯入進行中、另一台剛傳來還沒套用 —— 先被引用的機會要留給它們。
        let fresh = "att_\(UUID().uuidString).png"
        try write(fresh, in: attachments, ageDays: 1)
        XCTAssertTrue(plan(notebooks: [nb]).files.isEmpty)
    }

    func testImportedFilesAreNeverCleaned() throws {
        try write("imp_\(UUID().uuidString).usdz", in: attachments, ageDays: 100)
        try write("something.pdf", in: attachments, ageDays: 100)
        XCTAssertTrue(plan(notebooks: [nb]).files.isEmpty)
    }

    // MARK: 頁面筆跡

    func testAnEmptyPageBeyondThePageCountIsCleanedButOneWithInkIsKept() throws {
        try writeDrawing("\(nb.id)_p0.drawing", strokes: 2, ageDays: 5)
        try writeDrawing("\(nb.id)_p1.drawing", strokes: 0, ageDays: 5)
        let emptyBeyond = try writeDrawing("\(nb.id)_p2.drawing", strokes: 0, ageDays: 5)
        let inkBeyond = try writeDrawing("\(nb.id)_p3.drawing", strokes: 1, ageDays: 5)
        let result = plan(notebooks: [nb])
        XCTAssertEqual(names(result), [emptyBeyond.lastPathComponent], "只有超出頁數而且是空的才清")
        XCTAssertEqual(result.keptSuspicious.map(\.lastPathComponent), [inkBeyond.lastPathComponent],
                       "超出頁數卻有內容的是使用者看不到、但還在的資料，不能刪")
    }

    func testTheInboxNotebookKeepsOnlyItsFirstPage() throws {
        // 實機上看到錄音收件匣留著 p1…p5 的空檔案。
        let inbox = StorageJanitor.NotebookInfo(id: "a0d10000-0000-4000-8000-000000000001", pageCount: 1)
        try writeDrawing("\(inbox.id)_p0.drawing", strokes: 0, ageDays: 5)
        var junk: Set<String> = []
        for page in 1 ... 5 {
            junk.insert(try writeDrawing("\(inbox.id)_p\(page).drawing", strokes: 0, ageDays: 5).lastPathComponent)
        }
        XCTAssertEqual(names(plan(notebooks: [nb, inbox])), junk)
    }

    func testDrawingsOfAPermanentlyDeletedNotebookAreCleaned() throws {
        let gone = try writeDrawing("22222222-2222-2222-2222-222222222222_p0.drawing", strokes: 3, ageDays: 5)
        let base = try write("22222222-2222-2222-2222-222222222222_p0.drawing", in: baseline, ageDays: 5)
        XCTAssertEqual(Set(plan(notebooks: [nb]).files), [gone, base])
    }

    func testANotebookThatTheSyncIndexStillRemembersIsNotAnOrphan() throws {
        try writeDrawing("22222222-2222-2222-2222-222222222222_p0.drawing", strokes: 3, ageDays: 30)
        let result = plan(notebooks: [nb], protectedIds: ["22222222-2222-2222-2222-222222222222"])
        XCTAssertTrue(result.files.isEmpty, "載入失敗時，同步索引還記得的筆記本不能被當成垃圾")
    }

    func testARecentDrawingIsLeftAlone() throws {
        try writeDrawing("22222222-2222-2222-2222-222222222222_p0.drawing", strokes: 3, ageDays: 0.2)
        XCTAssertTrue(plan(notebooks: [nb]).files.isEmpty)
    }

    func testNothingIsCleanedWhenTheNotebookListIsEmpty() throws {
        // 筆記本清單載入失敗：「沒有任何東西被引用」會把全部資料當垃圾。
        try write("att_\(UUID().uuidString).png", in: attachments, ageDays: 100)
        try writeDrawing("22222222-2222-2222-2222-222222222222_p0.drawing", strokes: 3, ageDays: 100)
        XCTAssertTrue(plan(notebooks: []).files.isEmpty)
    }

    func testProInkFilesFollowTheSameRules() throws {
        let orphan = try write("22222222-2222-2222-2222-222222222222_p0.proink.json", in: drawings, ageDays: 5)
        let beyondEmpty = drawings.appendingPathComponent("\(nb.id)_p4.proink.json")
        try Data("[]".utf8).write(to: beyondEmpty)
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-5 * 86_400)], ofItemAtPath: beyondEmpty.path)
        XCTAssertEqual(Set(plan(notebooks: [nb]).files), [orphan, beyondEmpty])
    }

    // MARK: 執行

    func testExecuteRemovesExactlyThePlannedFiles() throws {
        let orphan = "att_\(UUID().uuidString).png"
        let keep = "att_\(UUID().uuidString).png"
        let orphanURL = try write(orphan, in: attachments, bytes: 300, ageDays: 10)
        let keepURL = try write(keep, in: attachments, ageDays: 10)
        let result = StorageJanitor.execute(plan(notebooks: [nb], referenced: [keep]))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.bytes, 300)
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphanURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: keepURL.path))
    }

    func testSyncIndexIdsAreReadFromAnyShape() {
        let json = #"{"notebooks":[{"id":"AAA","title":"x"}],"tombstones":[{"id":"BBB"}]}"#
        XCTAssertEqual(NotebookStore.notebookIds(inSyncIndex: json), ["AAA", "BBB"])
        XCTAssertTrue(NotebookStore.notebookIds(inSyncIndex: "not json").isEmpty)
    }
}
