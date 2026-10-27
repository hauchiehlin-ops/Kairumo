import PencilKit
import XCTest
@testable import Kairumo

/// 編輯器的筆跡增量寫入（背景佇列上跑的那一段）：不重複、不漏、失敗會回報。
final class CoreInkFlushTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("core-ink-flush-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func stroke(_ seed: Int) -> PKStroke {
        var points: [PKStrokePoint] = []
        for i in 0..<8 {
            let x: CGFloat = 20 + CGFloat(seed) * 30 + CGFloat(i) * 5
            let y: CGFloat = 40 + CGFloat(i * i)
            let size = CGSize(width: 3, height: 3)
            points.append(PKStrokePoint(
                location: CGPoint(x: x, y: y), timeOffset: TimeInterval(i) * 0.01,
                size: size, opacity: 1, force: 0.5, azimuth: 0, altitude: CGFloat.pi / 2))
        }
        let path = PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 1_700_000_000))
        return PKStroke(ink: PKInk(.pen, color: .black), path: path)
    }

    private var document: NotebookDocument { NotebookDocument(title: "Test", pageCount: 1) }

    func testTheFirstFlushWritesTheWholePageAndALaterOneOnlyTheNewStrokes() throws {
        let package = dir.appendingPathComponent("a.padnote")
        let drawingFile = dir.appendingPathComponent("a_p0.drawing")
        let one = PKDrawing(strokes: [stroke(0), stroke(1)])
        let two = PKDrawing(strokes: [stroke(0), stroke(1), stroke(2)])

        // 第一次：套件還不存在，基準不知道（nil）→ 整頁都是新增。
        XCTAssertTrue(CoreInkFlush.apply(
            [.init(page: 0, drawing: one, drawingFileURL: drawingFile, cachedBaseline: nil)],
            document: document, package: package, baselineDirectory: dir, deviceId: 0xA1).isEmpty)
        XCTAssertEqual(try NotebookPackageBridge.drawings(fromPackageAt: package, deviceId: 0xA1)[0].strokes.count, 2)

        // 第二次：編輯器樂觀地把基準設成上一版 → 只追加多出來的那一筆。
        XCTAssertTrue(CoreInkFlush.apply(
            [.init(page: 0, drawing: two, drawingFileURL: drawingFile, cachedBaseline: one)],
            document: document, package: package, baselineDirectory: dir, deviceId: 0xA1).isEmpty)
        XCTAssertEqual(try NotebookPackageBridge.drawings(fromPackageAt: package, deviceId: 0xA1)[0].strokes.count, 3,
                       "第二次不該把前兩筆再寫一次")
    }

    func testUnknownBaselineIsReadFromThePackageSoNothingIsWrittenTwice() throws {
        let package = dir.appendingPathComponent("b.padnote")
        let drawingFile = dir.appendingPathComponent("b_p0.drawing")
        let one = PKDrawing(strokes: [stroke(0), stroke(1)])
        _ = CoreInkFlush.apply([.init(page: 0, drawing: one, drawingFileURL: drawingFile, cachedBaseline: nil)],
                               document: document, package: package, baselineDirectory: dir, deviceId: 0xA1)
        // 基準被清掉（例如同步匯入之後）→ 從套件讀回來，同一版再存一次不該新增任何東西。
        _ = CoreInkFlush.apply([.init(page: 0, drawing: one, drawingFileURL: drawingFile, cachedBaseline: nil)],
                               document: document, package: package, baselineDirectory: dir, deviceId: 0xA1)
        XCTAssertEqual(try NotebookPackageBridge.drawings(fromPackageAt: package, deviceId: 0xA1)[0].strokes.count, 2)
    }

    func testAFailedWriteIsReportedSoTheCallerCanRetry() throws {
        // 套件路徑的上層是一個**檔案**，建立不了目錄 → 寫入必定失敗。
        let blocker = dir.appendingPathComponent("blocker")
        try Data("x".utf8).write(to: blocker)
        let package = blocker.appendingPathComponent("c.padnote")
        let drawingFile = dir.appendingPathComponent("c_p0.drawing")
        let drawing = PKDrawing(strokes: [stroke(0)])
        let failed = CoreInkFlush.apply(
            [.init(page: 0, drawing: drawing, drawingFileURL: drawingFile, cachedBaseline: nil)],
            document: document, package: package, baselineDirectory: dir, deviceId: 0xA1)
        XCTAssertEqual(failed.map(\.page), [0])
    }
}

/// 同步重讀時的三方合併：磁碟上是別台合併過的新內容，畫面上有這台還沒寫出去的筆畫。
/// 做錯的後果就是使用者回報的「寫好的字消失、過一會兒又出現」或「別台的筆畫被蓋掉」。
final class InkMergeTests: XCTestCase {
    private func stroke(_ seed: Int) -> PKStroke {
        var points: [PKStrokePoint] = []
        for i in 0..<6 {
            points.append(PKStrokePoint(
                location: CGPoint(x: 10 + CGFloat(seed) * 25 + CGFloat(i) * 4, y: 30 + CGFloat(i * i)),
                timeOffset: TimeInterval(i) * 0.01, size: CGSize(width: 3, height: 3),
                opacity: 1, force: 0.5, azimuth: 0, altitude: CGFloat.pi / 2))
        }
        return PKStroke(ink: PKInk(.pen, color: .black),
                        path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 1_700_000_000)))
    }

    private func keys(_ drawing: PKDrawing) -> [String] {
        drawing.strokes.map { StrokeDelta.Identity($0).key }.sorted()
    }

    func testStrokesWrittenBeforeTheImportSurviveAndRemoteStrokesAppear() {
        let base = PKDrawing(strokes: [stroke(0)])
        let local = PKDrawing(strokes: [stroke(0), stroke(1)])          // 這台剛寫了 1，還沒寫出去
        let disk = PKDrawing(strokes: [stroke(0), stroke(2)])           // 別台寫了 2
        let merged = InkMerge.merged(disk: disk, local: local, base: base)
        XCTAssertEqual(keys(merged), keys(PKDrawing(strokes: [stroke(0), stroke(1), stroke(2)])))
    }

    func testStrokesErasedHereStayErasedAndRemoteErasuresAreKept() {
        let base = PKDrawing(strokes: [stroke(0), stroke(1), stroke(2)])
        let local = PKDrawing(strokes: [stroke(0), stroke(2)])          // 這台擦了 1
        let disk = PKDrawing(strokes: [stroke(1), stroke(2)])           // 別台擦了 0
        let merged = InkMerge.merged(disk: disk, local: local, base: base)
        XCTAssertEqual(keys(merged), keys(PKDrawing(strokes: [stroke(2)])))
    }

    func testNothingLocalMeansTheDiskWins() {
        let base = PKDrawing(strokes: [stroke(0)])
        let disk = PKDrawing(strokes: [stroke(0), stroke(3)])
        XCTAssertEqual(InkMerge.merged(disk: disk, local: base, base: base), disk)
    }

    func testStrokesAlreadyOnDiskAreNotDuplicated() {
        let base = PKDrawing(strokes: [stroke(0)])
        let local = PKDrawing(strokes: [stroke(0), stroke(1)])
        let disk = PKDrawing(strokes: [stroke(0), stroke(1)])           // 匯出時已經帶出去了
        XCTAssertEqual(InkMerge.merged(disk: disk, local: local, base: base).strokes.count, 2)
    }

    func testUnknownBaselineNeverDropsLocalStrokes() {
        let local = PKDrawing(strokes: [stroke(0), stroke(1)])
        let disk = PKDrawing(strokes: [stroke(2)])
        let merged = InkMerge.merged(disk: disk, local: local, base: nil)
        XCTAssertEqual(keys(merged), keys(PKDrawing(strokes: [stroke(0), stroke(1), stroke(2)])))
    }
}

@MainActor
final class PageInkStoreTests: XCTestCase {
    private var tempDir: URL!
    private var store: NotebookStore!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("page-ink-store-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = NotebookStore(testDocumentsRoot: tempDir)
    }

    override func tearDownWithError() throws {
        PageInkStore.purgeAll()
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func makeStroke(_ seed: Int) -> PKStroke {
        var points: [PKStrokePoint] = []
        for i in 0..<6 {
            points.append(PKStrokePoint(
                location: CGPoint(x: 10 + CGFloat(seed) * 20 + CGFloat(i) * 4, y: 30 + CGFloat(i * i)),
                timeOffset: TimeInterval(i) * 0.01, size: CGSize(width: 3, height: 3),
                opacity: 1, force: 0.5, azimuth: 0, altitude: CGFloat.pi / 2))
        }
        let path = PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 1_700_000_000))
        return PKStroke(ink: PKInk(.pen, color: .black), path: path)
    }

    /// 使用者以橡皮擦或全選刪除清空某一頁所有筆跡時，PageInkStore 必須確實更新為空畫布，
    /// 絕不可因防空安全閥將空畫布丟棄，導致存檔後重新開啟筆記本時筆跡仍在。
    func testErasingAllStrokesUpdatesInMemoryDrawingAndPermitsEmptyDrawing() {
        let doc = NotebookDocument(id: "test-ink-erase", title: "Test Erase", pageCount: 1)
        store.notebooks = [doc]
        let inkStore = PageInkStore.store(for: doc, store: store)

        // 模擬落筆：寫入一筆手寫字
        let drawn = PKDrawing(strokes: [makeStroke(1)])
        inkStore.updateDrawing(drawn, for: 0)
        XCTAssertEqual(inkStore.drawing(for: 0).strokes.count, 1)

        // 模擬橡皮擦將手繪筆跡全部擦除（0 筆劃）
        let erased = PKDrawing()
        inkStore.updateDrawing(erased, for: 0)

        // 驗證記憶體快取已確實更新為 0 筆劃，未被誤判拒收
        XCTAssertEqual(inkStore.drawing(for: 0).strokes.count, 0,
                       "橡皮擦擦掉所有筆跡後，drawing(for:) 必須是 0 筆劃的空畫布")

        // 登記待寫入核心套件，確認 pendingCoreFlushJobs 回傳的是空畫布而非舊筆畫
        inkStore.markPendingCoreFlush(for: 0)
        let jobs = inkStore.pendingCoreFlushJobs(notebook: doc)
        XCTAssertEqual(jobs.count, 1)
        XCTAssertEqual(jobs.first?.drawing.strokes.count, 0,
                       "flush 任務傳遞的必須是擦拭後的 0 筆畫畫布")
    }
}
