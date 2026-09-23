//
//  NotebookPackageBridgeTests.swift
//  KairumoTests
//
//  把一本真的筆記寫成 `.padnote`，再從套件讀回來比對（工作包 WP4 的驗收）。
//
//  這份測試走的是完整的那條路：Swift 的 `NotebookDocument` → 核心套件 →
//  落到磁碟 → 重新開啟 → 讀回來。中間任何一段掉東西都會在這裡現形，
//  而不是等到使用者在 Android 上打開才發現。
//

import XCTest
import PencilKit
@testable import Kairumo

final class NotebookPackageBridgeTests: XCTestCase {

    private var workDir: URL!

    override func setUpWithError() throws {
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-bridge-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workDir)
    }

    // MARK: - 測試資料

    private func stroke(at x: CGFloat, color: UIColor) -> PKStroke {
        // 每個值先算好再放進去：整串內嵌算式會讓 Swift 的型別推導爆掉
        // （"unable to type-check this expression in reasonable time"）。
        var points: [PKStrokePoint] = []
        for i in 0..<12 {
            let step = CGFloat(i)
            let location = CGPoint(x: x + step * 3.5, y: 200 + step * 1.25)
            let side: CGFloat = 6 - step * 0.25
            points.append(
                PKStrokePoint(
                    location: location,
                    timeOffset: Double(i) * 0.008,
                    size: CGSize(width: side, height: side),
                    opacity: 1,
                    force: 1,
                    azimuth: 1.2,
                    altitude: 1.1
                )
            )
        }
        return PKStroke(
            ink: PKInk(.pen, color: color),
            path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0))
        )
    }

    /// 一本兩頁的筆記：手繪、文字方塊、圖片、以及被拉長的第二頁。
    private func sampleNotebook() -> (NotebookDocument, [PKDrawing]) {
        var doc = NotebookDocument(
            title: "跨平台測試筆記",
            pageCount: 2,
            template: .grid,
            textAttachments: [
                NoteTextAttachment(pageIndex: 0, text: "第一頁的重點", x: 120, y: 480),
                NoteTextAttachment(pageIndex: 1, text: "第二頁的重點", x: 60, y: 1_900)
            ]
        )
        // 頁面高度現在是固定的（PageGeometry）。這條測試原本驗的是
        // 「使用者拉長過的頁面高度要跟著檔案走」—— 那個功能已經移除，
        // 現在要驗的是「每一頁的高度都等於標準頁高」。

        let drawings = [
            PKDrawing(strokes: [stroke(at: 10, color: .red), stroke(at: 90, color: .blue)]),
            PKDrawing(strokes: [stroke(at: 40, color: .green)])
        ]
        return (doc, drawings)
    }

    // MARK: - 匯出

    func testExportWritesEveryPageStrokeAndTextBlock() throws {
        let (doc, drawings) = sampleNotebook()
        let summary = try NotebookPackageBridge.export(
            document: doc, drawings: drawings,
            to: workDir.appendingPathComponent("note.padnote"), deviceId: 0xA1)

        XCTAssertEqual(summary.pageCount, 2)
        XCTAssertEqual(summary.strokeCount, 3, "三筆畫一筆都不能少")
        XCTAssertEqual(summary.textBlockCount, 2)
    }

    func testExportedPackageExistsOnDisk() throws {
        let (doc, drawings) = sampleNotebook()
        let path = workDir.appendingPathComponent("ondisk.padnote")
        try NotebookPackageBridge.export(
            document: doc, drawings: drawings, to: path, deviceId: 0xA2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path.path),
                      "套件要真的落到磁碟，Android 才拿得到檔案")
    }

    // MARK: - 讀回比對

    func testStrokeGeometrySurvivesTheRoundTrip() throws {
        let (doc, drawings) = sampleNotebook()
        let path = workDir.appendingPathComponent("roundtrip.padnote")
        try NotebookPackageBridge.export(
            document: doc, drawings: drawings, to: path, deviceId: 0xA3)

        let readBack = try NotebookPackageBridge.drawings(fromPackageAt: path, deviceId: 0xB3)
        XCTAssertEqual(readBack.count, 2, "頁數必須一致")
        XCTAssertEqual(readBack[0].strokes.count, 2)
        XCTAssertEqual(readBack[1].strokes.count, 1)

        // 逐點比座標：這就是「座標與原稿一致」那句驗收條件本身。
        let original = drawings[0].strokes[0].path
        let restored = readBack[0].strokes[0].path
        XCTAssertEqual(restored.count, original.count)
        for i in 0..<original.count {
            XCTAssertEqual(restored[i].location.x, original[i].location.x,
                           accuracy: 1e-3, "第 \(i) 點 x")
            XCTAssertEqual(restored[i].location.y, original[i].location.y,
                           accuracy: 1e-3, "第 \(i) 點 y")
        }
    }

    func testStrokeColorSurvivesTheRoundTrip() throws {
        let (doc, drawings) = sampleNotebook()
        let path = workDir.appendingPathComponent("color.padnote")
        try NotebookPackageBridge.export(
            document: doc, drawings: drawings, to: path, deviceId: 0xA4)

        let readBack = try NotebookPackageBridge.drawings(fromPackageAt: path, deviceId: 0xB4)
        for index in 0..<2 {
            XCTAssertEqual(
                Array(InkInterop.rgba(from: readBack[0].strokes[index].ink.color)),
                Array(InkInterop.rgba(from: drawings[0].strokes[index].ink.color)),
                "第 \(index) 筆的顏色變了"
            )
        }
    }

    func testPageHeightSurvivesTheRoundTrip() throws {
        // 頁面高度仍然要寫進檔案：另一個平台才知道這份筆記用的是哪個頁面尺寸。
        let (doc, drawings) = sampleNotebook()
        let path = workDir.appendingPathComponent("height.padnote")
        try NotebookPackageBridge.export(
            document: doc, drawings: drawings, to: path, deviceId: 0xA5)

        let heights = try NotebookPackageBridge.pageHeights(fromPackageAt: path, deviceId: 0xB5)
        XCTAssertEqual(heights.count, 2)
        for height in heights {
            XCTAssertEqual(height, PageGeometry.height, accuracy: 0.5)
        }
    }

    // MARK: - 邊界

    func testMissingImageBytesSkipTheImageInsteadOfFailingTheExport() throws {
        // 缺一張圖，跟整本筆記匯不出去，對使用者是完全不同等級的損失。
        var doc = sampleNotebook().0
        doc.attachments = [NoteImageAttachment(fileName: "不存在.png", pageIndex: 0)]
        let summary = try NotebookPackageBridge.export(
            document: doc, drawings: sampleNotebook().1,
            to: workDir.appendingPathComponent("missing.padnote"), deviceId: 0xA6)
        XCTAssertEqual(summary.imageCount, 0)
        XCTAssertEqual(summary.strokeCount, 3, "其餘內容照樣要匯出")
    }

    func testImageWithBytesIsExported() throws {
        var doc = sampleNotebook().0
        doc.attachments = [NoteImageAttachment(fileName: "有.png", pageIndex: 0)]
        let png = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
            .image { _ in UIColor.orange.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 4, height: 4)) }
            .pngData()!

        let summary = try NotebookPackageBridge.export(
            document: doc, drawings: sampleNotebook().1,
            imageData: ["有.png": png],
            to: workDir.appendingPathComponent("image.padnote"), deviceId: 0xA7)
        XCTAssertEqual(summary.imageCount, 1)
    }

    func testEmptyDrawingsStillProduceAReadablePackage() throws {
        let doc = NotebookDocument(title: "空筆記", pageCount: 1)
        let path = workDir.appendingPathComponent("empty.padnote")
        try NotebookPackageBridge.export(
            document: doc, drawings: [PKDrawing()], to: path, deviceId: 0xA8)

        let readBack = try NotebookPackageBridge.drawings(fromPackageAt: path, deviceId: 0xB8)
        XCTAssertEqual(readBack.count, 1)
        XCTAssertTrue(readBack[0].strokes.isEmpty)
    }

    func testInkDeltaAppendAutosavesIntoThePackage() throws {
        let doc = NotebookDocument(title: "即時筆跡", pageCount: 1)
        let path = workDir.appendingPathComponent("autosave.padnote")
        let first = stroke(at: 10, color: .red)
        let second = stroke(at: 80, color: .blue)

        try NotebookPackageBridge.appendInkDelta(
            document: doc,
            pageIndex: 0,
            strokes: [first],
            to: path,
            deviceId: 0xC1)

        var readBack = try NotebookPackageBridge.drawings(fromPackageAt: path, deviceId: 0xC2)
        XCTAssertEqual(readBack.count, 1)
        XCTAssertEqual(readBack[0].strokes.count, 1)

        try NotebookPackageBridge.appendInkDelta(
            document: doc,
            pageIndex: 0,
            strokes: [second],
            to: path,
            deviceId: 0xC1)

        readBack = try NotebookPackageBridge.drawings(fromPackageAt: path, deviceId: 0xC2)
        XCTAssertEqual(readBack[0].strokes.count, 2)
        XCTAssertEqual(
            Array(InkInterop.rgba(from: readBack[0].strokes[1].ink.color)),
            Array(InkInterop.rgba(from: second.ink.color)))
    }

    /// 產生一份給 Android 開的交接檔。
    ///
    /// 這不是在測 Swift —— 它是整個 WP4 的驗收素材：iOS 這邊真的建一本筆記、
    /// 寫成套件，放在一個找得到的位置，接著在 Android 上打開來比對。
    /// 檔案刻意不刪除，也刻意用固定檔名（其餘測試用隨機目錄），
    /// 否則外面的腳本撈不到它。
    func testProduceHandoffPackageForAndroid() throws {
        let path = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kairumo-android-handoff.padnote")
        try? FileManager.default.removeItem(at: path)

        let (doc, drawings) = sampleNotebook()
        let summary = try NotebookPackageBridge.export(
            document: doc, drawings: drawings, to: path, deviceId: 0xF1)

        XCTAssertEqual(summary.strokeCount, 3)
        print("KAIRUMO_HANDOFF_PACKAGE=\(path.path)")
    }

    func testTemplateMapsToACorePageStyle() {
        // 對應表漏了哪個樣板，編譯器會抓；這裡確認幾個關鍵對應沒接反。
        XCTAssertEqual(NotebookPackageBridge.pageStyle(for: .cornell), .cornell)
        XCTAssertEqual(NotebookPackageBridge.pageStyle(for: .lined), .lined)
        XCTAssertEqual(NotebookPackageBridge.pageStyle(for: .isometricGrid), .grid)
        XCTAssertEqual(NotebookPackageBridge.pageStyle(for: .dotGridFine), .dotted)
    }
}
