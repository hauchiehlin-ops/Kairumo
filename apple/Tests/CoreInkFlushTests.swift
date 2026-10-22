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

    private var document: NotebookDocument { NotebookDocument(title: "測試", pageCount: 1) }

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
