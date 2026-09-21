//
//  NotebookSyncCoordinatorTests.swift
//  KairumoTests
//
//  兩台裝置、一個共用資料夾 —— 使用者要的「A 裝置寫、B 裝置打開就有」。
//
//  # 這組測試在守什麼
//
//  同步的錯誤只有在**兩台裝置**的情境下才看得出來，而且每一種的症狀都是
//  「看起來成功了，但東西不對」：
//
//  - 匯出放在搬檔之後 → 上傳的是上一輪的舊內容
//  - 沒有匯入這一步 → 檔案同步得很成功，另一台裝置上什麼也沒出現
//  - 匯出時洗掉對方的檔案 → 對方的編輯悄悄消失，沒有任何錯誤訊息
//  - 新筆記本走 updateNotebook → 本機沒有這個 id，被靜靜丟掉
//
//  沒有一項會跳出錯誤。所以這裡每一條都盯著「使用者最後看到什麼」。
//

import XCTest
import PencilKit
@testable import Kairumo

/// 一台裝置的儲存。用暫存目錄，與真正的 `NotebookStore` 單例無關。
@MainActor
final class FakeStore: SyncableNotebookStore {
    let root: URL
    var documents: [NotebookDocument] = []
    private var drawings: [String: PKDrawing] = [:]

    init(root: URL) {
        self.root = root
        for sub in ["Packages", "Attachments", "SyncBaseline"] {
            try? FileManager.default.createDirectory(
                at: root.appendingPathComponent(sub), withIntermediateDirectories: true)
        }
    }

    var syncNotebooks: [NotebookDocument] { documents }
    /// 全集（含被隱藏的）。測試裡沒有隱藏的概念，兩者相同。
    var allNotebooks: [NotebookDocument] { documents }
    var syncPackagesDirectory: URL { root.appendingPathComponent("Packages") }
    var syncAttachmentsDirectory: URL { root.appendingPathComponent("Attachments") }
    var syncBaselineDirectory: URL { root.appendingPathComponent("SyncBaseline") }

    func syncLoadDrawing(notebookId: String, pageIndex: Int) -> PKDrawing {
        drawings["\(notebookId)_\(pageIndex)"] ?? PKDrawing()
    }

    func syncSaveDrawing(notebookId: String, pageIndex: Int, drawing: PKDrawing) {
        drawings["\(notebookId)_\(pageIndex)"] = drawing
    }

    func syncUpsert(_ document: NotebookDocument) {
        if let index = documents.firstIndex(where: { $0.id == document.id }) {
            documents[index] = document
        } else {
            documents.append(document)
        }
    }
}

@MainActor
final class NotebookSyncCoordinatorTests: XCTestCase {

    private var workDir: URL!
    private var cloud: URL!
    private var alice: FakeStore!
    private var bob: FakeStore!
    private let aliceId: UInt32 = 0x0A11CE
    private let bobId: UInt32 = 0x0B0B

    override func setUpWithError() throws {
        workDir = FileManager.default.temporaryDirectory
            .resolvingSymlinksInPath()
            .appendingPathComponent("kairumo-sync-\(UUID().uuidString)", isDirectory: true)
        cloud = workDir.appendingPathComponent("Cloud", isDirectory: true)
        try FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)
        alice = FakeStore(root: workDir.appendingPathComponent("Alice", isDirectory: true))
        bob = FakeStore(root: workDir.appendingPathComponent("Bob", isDirectory: true))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workDir)
    }

    private func stroke(at x: CGFloat) -> PKStroke {
        let points = (0..<6).map { i in
            PKStrokePoint(
                location: CGPoint(x: x + CGFloat(i) * 3, y: 120),
                timeOffset: Double(i) * 0.01, size: CGSize(width: 4, height: 4),
                opacity: 1, force: 1, azimuth: 1, altitude: 1
            )
        }
        return PKStroke(
            ink: PKInk(.pen, color: .black),
            path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0))
        )
    }

    @discardableResult
    private func sync(_ store: FakeStore, _ deviceId: UInt32) async -> NotebookSyncCoordinator.Report {
        await NotebookSyncCoordinator.run(store: store, folder: cloud, deviceId: deviceId)
    }

    // MARK: - 使用者要的那件事

    func testANotebookWrittenOnOneDeviceAppearsOnTheOther() async throws {
        // 這條測試就是需求本身。
        var note = NotebookDocument(title: "會議記錄", pageCount: 1)
        note.textAttachments = [NoteTextAttachment(pageIndex: 0, text: "下週交報告")]
        alice.documents = [note]
        alice.syncSaveDrawing(notebookId: note.id, pageIndex: 0,
                              drawing: PKDrawing(strokes: [stroke(at: 20)]))

        await sync(alice, aliceId)
        await sync(bob, bobId)

        XCTAssertEqual(bob.documents.count, 1, "另一台裝置上什麼也沒出現")
        XCTAssertEqual(bob.documents.first?.title, "會議記錄")
        XCTAssertEqual(
            bob.documents.first?.textAttachments?.first?.text, "下週交報告")
        XCTAssertEqual(bob.syncLoadDrawing(notebookId: note.id, pageIndex: 0).strokes.count, 1)
    }

    func testEditsFromBothDevicesSurvive() async throws {
        // 雙方各寫一筆，同步之後兩筆都要在 —— 而且在同一頁上。
        let note = NotebookDocument(title: "共筆", pageCount: 1)
        alice.documents = [note]
        alice.syncSaveDrawing(notebookId: note.id, pageIndex: 0,
                              drawing: PKDrawing(strokes: [stroke(at: 10)]))
        await sync(alice, aliceId)
        await sync(bob, bobId)

        // Bob 在自己這邊加一筆。
        let bobDrawing = PKDrawing(strokes: [
            stroke(at: 10), stroke(at: 200)
        ])
        bob.syncSaveDrawing(notebookId: note.id, pageIndex: 0, drawing: bobDrawing)
        await sync(bob, bobId)
        await sync(alice, aliceId)

        let merged = alice.syncLoadDrawing(notebookId: note.id, pageIndex: 0)
        XCTAssertEqual(merged.strokes.count, 2, "有一邊的筆畫被洗掉了")
        XCTAssertEqual(alice.documents.first?.pageCount, 1, "頁數變多了")
    }

    func testRepeatedSyncsDoNotGrowTheNotebook() async throws {
        // 同步會來回很多次。每一趟讓內容長一點的話，幾趟之後筆記就走樣了。
        let note = NotebookDocument(title: "來回很多次", pageCount: 1)
        alice.documents = [note]
        alice.syncSaveDrawing(notebookId: note.id, pageIndex: 0,
                              drawing: PKDrawing(strokes: [stroke(at: 10)]))

        for _ in 0..<4 {
            await sync(alice, aliceId)
            await sync(bob, bobId)
        }

        XCTAssertEqual(alice.documents.count, 1)
        XCTAssertEqual(bob.documents.count, 1)
        XCTAssertEqual(bob.documents.first?.pageCount, 1)
        XCTAssertEqual(
            bob.syncLoadDrawing(notebookId: note.id, pageIndex: 0).strokes.count, 1,
            "筆畫被複製了"
        )
    }

    // MARK: - 內容的完整性

    func testImagesArriveAsRealFiles() async throws {
        // 筆記本指到一個不存在的檔名時，畫面上會是一格空白 —— 而且不會報錯。
        let png = try XCTUnwrap(
            UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
                .image { _ in UIColor.systemTeal.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 8, height: 8)) }
                .pngData()
        )
        var note = NotebookDocument(title: "有圖", pageCount: 1)
        note.attachments = [NoteImageAttachment(fileName: "pic.png", pageIndex: 0)]
        try png.write(to: alice.syncAttachmentsDirectory.appendingPathComponent("pic.png"))
        alice.documents = [note]

        await sync(alice, aliceId)
        await sync(bob, bobId)

        let arrived = bob.syncAttachmentsDirectory.appendingPathComponent("pic.png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: arrived.path), "圖檔沒有落地")
        XCTAssertNotNil(UIImage(contentsOfFile: arrived.path), "落地的不是一張讀得開的圖")
        XCTAssertEqual(bob.documents.first?.attachments?.first?.fileName, "pic.png")
    }

    func testTheTemplateAndFolderSurviveTheTrip() async throws {
        var note = NotebookDocument(title: "有樣板", pageCount: 1, template: .cornell)
        note.folderId = "study"
        alice.documents = [note]

        await sync(alice, aliceId)
        await sync(bob, bobId)

        XCTAssertEqual(bob.documents.first?.template, .cornell)
        XCTAssertEqual(bob.documents.first?.folderId, "study")
    }

    func testAChartArrivesStillEditable() async throws {
        var spec = ChartSpec()
        spec.title = "營收"
        spec.categories = ["Q1", "Q2"]
        spec.series = [ChartSeries(name: "北區", values: [12, 34])]
        let image = try XCTUnwrap(
            ChartRenderer.image(spec: spec, size: CGSize(width: 200, height: 150)))
        try XCTUnwrap(image.pngData())
            .write(to: alice.syncAttachmentsDirectory.appendingPathComponent("chart.png"))

        var note = NotebookDocument(title: "有圖表", pageCount: 1)
        note.attachments = [
            NoteImageAttachment(fileName: "chart.png", pageIndex: 0,
                                chartSpecJSON: spec.encodedJSON())
        ]
        alice.documents = [note]

        await sync(alice, aliceId)
        await sync(bob, bobId)

        let arrived = try XCTUnwrap(bob.documents.first?.attachments?.first?.chartSpec)
        XCTAssertEqual(arrived.title, "營收")
        XCTAssertEqual(arrived.series[0].values, [12, 34])
    }

    // MARK: - 多本與邊界

    func testEveryNotebookMakesTheTrip() async throws {
        alice.documents = (1...3).map { NotebookDocument(title: "第 \($0) 本", pageCount: 1) }
        await sync(alice, aliceId)
        await sync(bob, bobId)

        XCTAssertEqual(Set(bob.documents.map(\.title)), ["第 1 本", "第 2 本", "第 3 本"])
    }

    func testSyncingWithNothingToDoReportsItAsSuch() async throws {
        // 「已是最新」與「同步失敗」對使用者是完全不同的訊息。
        await sync(alice, aliceId)
        let second = await sync(alice, aliceId)
        XCTAssertTrue(second.isNoOp)
        XCTAssertTrue(second.failures.isEmpty)
    }

    func testAnEmptyCloudFolderIsNotAnError() async throws {
        let report = await sync(bob, bobId)
        XCTAssertTrue(report.failures.isEmpty)
        XCTAssertTrue(bob.documents.isEmpty)
    }

    func testABrokenPackageDoesNotStopTheOthers() async throws {
        // 一本壞掉，跟整輪同步失敗，對使用者是完全不同等級的損失。
        alice.documents = [NotebookDocument(title: "好的", pageCount: 1)]
        await sync(alice, aliceId)
        try Data("壞掉".utf8).write(to: cloud.appendingPathComponent("broken.padnote"))

        let report = await sync(bob, bobId)
        XCTAssertEqual(bob.documents.count, 1, "好的那一本要照樣進來")
        XCTAssertFalse(report.failures.isEmpty, "壞掉的那一本要被回報，不是靜靜跳過")
    }
}
