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
    /// 有鎖是因為匯出真的會在背景執行緒上讀它（見 `syncDrawingLoader`）。
    /// 正式版的筆跡在磁碟上，沒有這個問題；測試替身放在記憶體裡，就得自己
    /// 保證安全 —— 不然這裡會是一個只有在測試裡才存在的資料競爭。
    private nonisolated let drawingsLock = NSLock()
    /// `nonisolated(unsafe)` 的「unsafe」由上面那把鎖負責 —— 每一處存取都
    /// 走 `drawingsLock`，沒有例外。
    private nonisolated(unsafe) var _drawings: [String: PKDrawing] = [:]
    private var drawings: [String: PKDrawing] {
        get { drawingsLock.withLock { _drawings } }
        set { drawingsLock.withLock { _drawings = newValue } }
    }

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
    var syncDrawingsDirectory: URL { root.appendingPathComponent("Drawings") }
    var syncBaselineDirectory: URL { root.appendingPathComponent("SyncBaseline") }

    func syncLoadDrawing(notebookId: String, pageIndex: Int) -> PKDrawing {
        drawings["\(notebookId)_\(pageIndex)"] ?? PKDrawing()
    }

    /// 只捕捉 `self`（有鎖）—— 匯出會在背景執行緒上呼叫它。
    var syncDrawingLoader: @Sendable (String, Int) -> PKDrawing {
        { [self] notebookId, pageIndex in
            drawingsLock.withLock { _drawings["\(notebookId)_\(pageIndex)"] } ?? PKDrawing()
        }
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

    /// 在 B 把 A 畫的製圖線改到別的圖層：兩台最後要看到同樣的畫面（一條、新圖層），
    /// 而且 A 那台的原線要真的消失。這條走真實的 `NotebookSyncCoordinator.run`（匯出、資料夾同步、匯入），
    /// 不是直接呼叫橋接層 —— 墓碑能不能傳回原作者，取決於整條路徑上「檔案只有變大才會傳」這條規則。
    func testReassigningAnotherDevicesLineReachesBothDevices() async throws {
        let note = NotebookDocument(title: "圖學", pageCount: 1)
        alice.documents = [note]
        for store in [alice!, bob!] {
            try FileManager.default.createDirectory(
                at: store.syncDrawingsDirectory, withIntermediateDirectories: true)
        }
        let line = ProStroke(
            tool: "fineliner", colorRGBA: [0, 0, 0, 255], baseWidth: 2,
            points: (0 ..< 12).map {
                ProPoint(x: 20 + Float($0) * 9, y: 80, pressure: 0.5, tilt: 0, azimuth: 0, dtUs: 8_000)
            })
        ProInkStore.save([line], in: alice.syncDrawingsDirectory, notebookId: note.id, page: 0)

        await sync(alice, aliceId)
        await sync(bob, bobId)
        XCTAssertEqual(
            ProInkStore.load(in: bob.syncDrawingsDirectory, notebookId: note.id, page: 0, foreign: true).count, 1,
            "B 要先收到 A 的那條線")

        // B 把它改到頂層。
        let layer = ProInkLayerView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        layer.load(directory: bob.syncDrawingsDirectory, notebookId: note.id, pageIndex: 0)
        XCTAssertTrue(layer.reassignLayer(near: CGPoint(x: 20, y: 80), to: 3))

        await sync(bob, bobId)
        await sync(alice, aliceId)

        func state(_ store: FakeStore) -> (own: [ProStroke], foreign: [ProStroke]) {
            (ProInkStore.load(in: store.syncDrawingsDirectory, notebookId: note.id, page: 0),
             ProInkStore.load(in: store.syncDrawingsDirectory, notebookId: note.id, page: 0, foreign: true))
        }
        // 再來回幾輪：不能復活、不能增生。
        for _ in 0 ..< 3 {
            await sync(alice, aliceId)
            await sync(bob, bobId)
        }
        let a = state(alice), b = state(bob)
        XCTAssertTrue(a.own.isEmpty, "A 那台的原線要被拿掉（別台把它改到別的圖層了）")
        XCTAssertEqual(a.foreign.count, 1, "A 要看到 B 改過圖層的那一條")
        XCTAssertEqual(a.foreign.first?.layerId, 3)
        XCTAssertEqual(b.own.count, 1)
        XCTAssertEqual(b.own.first?.layerId, 3)
        XCTAssertTrue(b.foreign.isEmpty, "B 不該又收到 A 的原線")
    }

    // MARK: - PencilKit 筆畫的擦除要傳到每一台

    private func pencilKitNote() -> (note: NotebookDocument, a: PKStroke, b: PKStroke) {
        let note = NotebookDocument(title: "手寫", pageCount: 1)
        return (note, stroke(at: 20), stroke(at: 220))
    }

    private func strokeCount(_ store: FakeStore, _ note: NotebookDocument) -> Int {
        store.syncLoadDrawing(notebookId: note.id, pageIndex: 0).strokes.count
    }

    func testErasingYourOwnPencilKitStrokeReachesTheOtherDevice() async throws {
        let (note, a, b) = pencilKitNote()
        alice.documents = [note]
        alice.syncSaveDrawing(notebookId: note.id, pageIndex: 0, drawing: PKDrawing(strokes: [a, b]))
        await sync(alice, aliceId)
        await sync(bob, bobId)
        XCTAssertEqual(strokeCount(bob, note), 2)

        alice.syncSaveDrawing(notebookId: note.id, pageIndex: 0, drawing: PKDrawing(strokes: [a]))
        await sync(alice, aliceId)
        await sync(bob, bobId)
        for _ in 0 ..< 2 {
            await sync(alice, aliceId)
            await sync(bob, bobId)
        }
        XCTAssertEqual(strokeCount(alice, note), 1)
        XCTAssertEqual(strokeCount(bob, note), 1, "擦掉的那一筆在另一台還在 —— 擦除沒有傳出去")
    }

    func testErasingTheOtherDevicesPencilKitStrokeReachesTheOwnerToo() async throws {
        let (note, a, b) = pencilKitNote()
        alice.documents = [note]
        alice.syncSaveDrawing(notebookId: note.id, pageIndex: 0, drawing: PKDrawing(strokes: [a, b]))
        await sync(alice, aliceId)
        await sync(bob, bobId)
        XCTAssertEqual(strokeCount(bob, note), 2)

        // Bob 擦掉 Alice 畫的第二筆。
        bob.syncSaveDrawing(notebookId: note.id, pageIndex: 0, drawing: PKDrawing(strokes: [a]))
        await sync(bob, bobId)
        await sync(alice, aliceId)
        for _ in 0 ..< 2 {
            await sync(bob, bobId)
            await sync(alice, aliceId)
        }
        XCTAssertEqual(strokeCount(bob, note), 1, "Bob 自己擦掉的不能又回來")
        XCTAssertEqual(strokeCount(alice, note), 1, "原作者那台還看得到被別台擦掉的筆畫")
    }

    func testRedrawingAnErasedPencilKitStrokeComesBackOnBothDevices() async throws {
        // 擦掉 → 同步 → 復原（把同一條線畫回來）：墓碑已經傳出去、撤不掉，所以那一筆要拿新的身分。
        let (note, a, b) = pencilKitNote()
        alice.documents = [note]
        alice.syncSaveDrawing(notebookId: note.id, pageIndex: 0, drawing: PKDrawing(strokes: [a, b]))
        await sync(alice, aliceId)
        await sync(bob, bobId)
        alice.syncSaveDrawing(notebookId: note.id, pageIndex: 0, drawing: PKDrawing(strokes: [a]))
        await sync(alice, aliceId)
        await sync(bob, bobId)
        XCTAssertEqual(strokeCount(bob, note), 1)

        alice.syncSaveDrawing(notebookId: note.id, pageIndex: 0, drawing: PKDrawing(strokes: [a, b]))
        await sync(alice, aliceId)
        await sync(bob, bobId)
        await sync(alice, aliceId)
        XCTAssertEqual(strokeCount(alice, note), 2, "畫回來的那一筆在自己這台不見了")
        XCTAssertEqual(strokeCount(bob, note), 2, "畫回來的那一筆沒傳到另一台")
    }

    func testBothDevicesKeepDrawingAfterAnEraseWithoutLosingAnything() async throws {
        let (note, a, b) = pencilKitNote()
        alice.documents = [note]
        alice.syncSaveDrawing(notebookId: note.id, pageIndex: 0, drawing: PKDrawing(strokes: [a, b]))
        await sync(alice, aliceId)
        await sync(bob, bobId)
        bob.syncSaveDrawing(notebookId: note.id, pageIndex: 0, drawing: PKDrawing(strokes: [a, stroke(at: 420)]))
        await sync(bob, bobId)       // Bob 擦掉 b、又畫了一筆
        alice.syncSaveDrawing(
            notebookId: note.id, pageIndex: 0, drawing: PKDrawing(strokes: [a, b, stroke(at: 620)]))
        await sync(alice, aliceId)   // Alice 同時又畫了一筆
        for _ in 0 ..< 3 {
            await sync(bob, bobId)
            await sync(alice, aliceId)
        }
        // a、Bob 新畫的、Alice 新畫的；b 被擦掉。
        XCTAssertEqual(strokeCount(alice, note), 3)
        XCTAssertEqual(strokeCount(bob, note), 3)
    }

    func testUpgradingAnExistingNotebookRewritesItOnceEvenWithoutEdits() async throws {
        // 升級前的筆記：帳本版本是 0。第一次同步就要用穩定身分重寫一次 —— 即使沒有任何編輯。
        let (note, a, b) = pencilKitNote()
        alice.documents = [note]
        try FileManager.default.createDirectory(
            at: alice.syncDrawingsDirectory, withIntermediateDirectories: true)
        alice.syncSaveDrawing(notebookId: note.id, pageIndex: 0, drawing: PKDrawing(strokes: [a, b]))
        await sync(alice, aliceId)
        XCTAssertEqual(
            ProInkStore.loadLedger(in: alice.syncDrawingsDirectory, notebookId: note.id, page: 0).schema, 2)
        // 模擬升級前：帳本被清掉（等同從未用新方式匯出過）。
        let ledgerFile = alice.syncDrawingsDirectory.appending(path: "\(note.id)_p0.proink-ledger.json")
        try? FileManager.default.removeItem(at: ledgerFile)
        await sync(alice, aliceId)
        XCTAssertEqual(
            ProInkStore.loadLedger(in: alice.syncDrawingsDirectory, notebookId: note.id, page: 0).schema, 2,
            "沒有編輯也要把升級前的筆記重寫一次")
        await sync(bob, bobId)
        XCTAssertEqual(strokeCount(bob, note), 2, "重寫不能讓別台多出或少掉筆畫")
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

// MARK: - 主執行緒預算（提案 ⑤）

extension NotebookSyncCoordinatorTests {

    /// 同步不准把主執行緒佔住。
    ///
    /// # 為什麼需要在桌機上量這件事
    ///
    /// v4.8.2 build 60 在 iPhone 上按下雲端同步就被 SIGKILL：scene-update
    /// 看門狗 10 秒到期（0x8BADF00D）。成因是匯出整段跟著
    /// `NotebookSyncCoordinator` 的 `@MainActor` 標記留在主執行緒上。
    ///
    /// 那個 bug **在桌機上完全測不出來** —— 單元測試不看主執行緒有沒有被佔住，
    /// 而模擬器沒有看門狗。只有實機、而且筆記本要夠多，才會炸。
    /// 使用者的時間不該花在幫我們找這種東西。
    ///
    /// # 量法
    ///
    /// 在主執行緒的 run loop 上掛一個心跳，量**兩次心跳之間最長的間隔**。
    /// 主執行緒被佔住的時候心跳就不會跳，間隔等於被佔住的時間 —— 這正是
    /// 看門狗在量的東西。
    ///
    /// # 門檻是量出來的，不是猜的
    ///
    /// 這台機器上，200 本筆記：
    ///
    /// | 狀態 | 主執行緒最長被佔住 |
    /// |---|---|
    /// | 正確（匯出在背景執行緒） | **24 ms** |
    /// | 退步（把 `Task.detached` 拿掉） | **293 ms** |
    ///
    /// 差 12 倍。門檻取 150 ms：離正常值有 6 倍餘裕（CI 的機器比較慢也
    /// 撐得住），離退步值有 2 倍偵測空間。
    ///
    /// 第一版訂在 1 秒、用 40 本筆記 —— **抓不到退步**（量到 81 ms，
    /// 遠低於門檻）。訂門檻前先量兩種狀態，不然只是寫了一條永遠會綠的測試。
    ///
    /// 那 24 ms 不是雜訊，是 MainActor 上真的在做的事：200 次
    /// `exportInputs` 快照。它會隨筆記本數量線性成長，所以筆記本再多十倍
    /// 時這個數字要重新量。
    @MainActor
    func testSyncDoesNotBlockTheMainThread() async throws {
        // 量得出差距需要足夠的量。40 本 × 每本一頁一筆。
        for index in 0..<200 {
            var note = NotebookDocument(title: "壓測 \(index)", pageCount: 1)
            note.textAttachments = [NoteTextAttachment(pageIndex: 0, text: "內容 \(index)")]
            alice.documents.append(note)
            alice.syncSaveDrawing(
                notebookId: note.id, pageIndex: 0,
                drawing: PKDrawing(strokes: [stroke(at: CGFloat(index))]))
        }

        var longestBlock: TimeInterval = 0
        var lastBeat = CFAbsoluteTimeGetCurrent()
        let heartbeat = Timer(timeInterval: 0.01, repeats: true) { _ in
            let now = CFAbsoluteTimeGetCurrent()
            longestBlock = max(longestBlock, now - lastBeat)
            lastBeat = now
        }
        // `.common` 才會在捲動之類的模式下照跳；預設模式在某些情況會停。
        RunLoop.main.add(heartbeat, forMode: .common)
        defer { heartbeat.invalidate() }

        // 先讓心跳跑起來，不然第一次間隔會把「還沒開始跳」也算進去。
        try await Task.sleep(nanoseconds: 100_000_000)
        longestBlock = 0
        lastBeat = CFAbsoluteTimeGetCurrent()

        let started = CFAbsoluteTimeGetCurrent()
        let report = await sync(alice, aliceId)
        let elapsed = CFAbsoluteTimeGetCurrent() - started
        print(String(
            format: "【主執行緒預算】同步耗時 %.3fs，主執行緒最長被佔住 %.3fs",
            elapsed, longestBlock))
        XCTAssertEqual(report.exported, 200, "200 本沒有全部匯出，這一輪的量測不算數")

        XCTAssertLessThan(
            longestBlock, 0.150,
            "同步把主執行緒連續佔住了 \(String(format: "%.2f", longestBlock)) 秒。"
                + "實機上這會撞到 scene-update 看門狗（10 秒）——"
                + "匯出那一段是不是又回到 MainActor 上了？")
    }
}
