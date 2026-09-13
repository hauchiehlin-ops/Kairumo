//
//  PackageRoundTripTests.swift
//  KairumoTests
//
//  一本筆記寫成 `.padnote`，再讀回來變成一本可以繼續編輯的筆記。
//
//  # 這組測試在守什麼
//
//  「A 裝置寫、B 裝置打開就有」—— 使用者要的就是這件事。之前這條路只有一半：
//  匯得出去，讀不回來。現在兩半都在了，而**掉東西是這裡唯一要防的事**：
//  掉一張圖、掉一個圖釘、掉樣板，使用者在另一台裝置上看到的就是一本殘缺的筆記，
//  而且他不會知道少了什麼。
//
//  所以每一條測試都盯著一類內容，而不是只驗「開得起來」。
//

import XCTest
import PencilKit
@testable import Kairumo

final class PackageRoundTripTests: XCTestCase {

    private var workDir: URL!

    override func setUpWithError() throws {
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-rt-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workDir)
    }

    // MARK: - 素材

    private func stroke(at x: CGFloat, color: UIColor) -> PKStroke {
        var points: [PKStrokePoint] = []
        for i in 0..<10 {
            let step = CGFloat(i)
            points.append(
                PKStrokePoint(
                    location: CGPoint(x: x + step * 4, y: 180 + step * 2),
                    timeOffset: Double(i) * 0.01,
                    size: CGSize(width: 5, height: 5),
                    opacity: 1, force: 1, azimuth: 1.1, altitude: 1.0
                )
            )
        }
        return PKStroke(
            ink: PKInk(.pen, color: color),
            path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0))
        )
    }

    private func png(_ color: UIColor) throws -> Data {
        try XCTUnwrap(
            UIGraphicsImageRenderer(size: CGSize(width: 6, height: 6))
                .image { _ in color.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 6, height: 6)) }
                .pngData()
        )
    }

    /// 一本什麼都有的筆記：兩頁、筆畫、文字方塊、圖片、圖表、連結、3D、圖釘、資料夾。
    private func richNotebook() throws -> (NotebookDocument, [PKDrawing], [String: Data]) {
        var chartSpec = ChartSpec()
        chartSpec.title = "營收"
        chartSpec.categories = ["Q1", "Q2"]
        chartSpec.series = [ChartSeries(name: "北區", values: [10, 20])]

        var text = NoteTextAttachment(pageIndex: 0, text: "第一頁的重點", x: 120, y: 480)
        text.backgroundColorHex = "clear"
        text.lineSpacing = 8
        text.isBold = true

        var photo = NoteImageAttachment(fileName: "photo.png", pageIndex: 0, x: 40, y: 100)
        photo.cornerRadius = 18
        photo.hasBorder = true
        photo.borderColorHex = "#FF0000"
        photo.borderWidth = 3
        photo.rotationDegrees = 12
        photo.filterStyle = .vintage

        let chart = NoteImageAttachment(
            fileName: "chart.png", pageIndex: 1, x: 60, y: 200,
            width: 420, height: 300, chartSpecJSON: chartSpec.encodedJSON()
        )

        var doc = NotebookDocument(
            title: "什麼都有的筆記",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            pageCount: 2,
            template: .cornell,
            folderId: "work",
            attachments: [photo, chart],
            textAttachments: [text],
            linkAttachments: [
                NoteLinkAttachment(
                    pageIndex: 1, urlString: "https://example.com",
                    title: "範例", descriptionText: "說明", siteName: "example.com"
                )
            ],
            commentPins: [
                NoteCommentPin(
                    pageIndex: 0, x: 200, y: 300,
                    authorId: "u1", authorName: "阿林", authorColor: "#00FF00",
                    createdAt: Date(timeIntervalSince1970: 1_700_000_100),
                    isResolved: false, messages: []
                )
            ]
        )
        doc.previewSnippet = "摘要"

        let drawings = [
            PKDrawing(strokes: [stroke(at: 10, color: .red), stroke(at: 90, color: .blue)]),
            PKDrawing(strokes: [stroke(at: 40, color: .green)])
        ]
        let images = ["photo.png": try png(.orange), "chart.png": try png(.purple)]
        return (doc, drawings, images)
    }

    private func roundTrip(
        _ file: String = #function
    ) throws -> (original: NotebookDocument, imported: NotebookPackageBridge.ImportedNotebook) {
        let (doc, drawings, images) = try richNotebook()
        let path = workDir.appendingPathComponent("\(abs(file.hashValue)).padnote")
        try NotebookPackageBridge.export(
            document: doc, drawings: drawings, imageData: images, to: path, deviceId: 0xE1)
        let imported = try NotebookPackageBridge.importDocument(
            fromPackageAt: path, deviceId: 0xE2, documentId: doc.id)
        return (doc, imported)
    }

    // MARK: - 基本

    func testTitleAndPageCountComeBack() throws {
        let (original, imported) = try roundTrip()
        XCTAssertEqual(imported.document.title, original.title)
        XCTAssertEqual(imported.document.pageCount, 2)
        XCTAssertEqual(imported.drawings.count, 2)
    }

    func testStrokesComeBackOnTheRightPages() throws {
        let (_, imported) = try roundTrip()
        XCTAssertEqual(imported.drawings[0].strokes.count, 2)
        XCTAssertEqual(imported.drawings[1].strokes.count, 1)
    }

    func testStrokeGeometryIsPreserved() throws {
        let (_, imported) = try roundTrip()
        let restored = imported.drawings[0].strokes[0].path
        XCTAssertEqual(restored.count, 10)
        XCTAssertEqual(restored[0].location.x, 10, accuracy: 1e-3)
        XCTAssertEqual(restored[9].location.y, 180 + 9 * 2, accuracy: 1e-3)
    }

    // MARK: - 核心沒有對應概念的東西（就是以前會整批消失的那些）

    func testTheTemplateComesBack() throws {
        // 核心的 PageStyle 種類比 NoteTemplate 少，只靠它回推會把樣板換掉。
        let (_, imported) = try roundTrip()
        XCTAssertEqual(imported.document.template, .cornell)
    }

    func testTheFolderComesBack() throws {
        // 掉了的話，這本筆記會從資料夾裡掉出來，使用者以為它不見了。
        let (_, imported) = try roundTrip()
        XCTAssertEqual(imported.document.folderId, "work")
    }

    func testCreationDateComesBack() throws {
        let (original, imported) = try roundTrip()
        XCTAssertEqual(
            imported.document.createdAt.timeIntervalSince1970,
            original.createdAt.timeIntervalSince1970, accuracy: 1
        )
    }

    func testCommentPinsComeBack() throws {
        let (_, imported) = try roundTrip()
        let pins = try XCTUnwrap(imported.document.commentPins)
        XCTAssertEqual(pins.count, 1)
        XCTAssertEqual(pins[0].authorName, "阿林")
        XCTAssertEqual(pins[0].x, 200)
    }

    func testLinkCardsComeBack() throws {
        // 連結卡片在套件裡是一張圖（核心沒有這個區塊型別），但原始資料
        // 必須跟著中繼資料回來，否則它就永遠只是一張圖了。
        let (_, imported) = try roundTrip()
        let links = try XCTUnwrap(imported.document.linkAttachments)
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links[0].urlString, "https://example.com")
    }

    // MARK: - 文字方塊

    func testTextBoxContentAndPositionComeBack() throws {
        let (_, imported) = try roundTrip()
        let texts = try XCTUnwrap(imported.document.textAttachments)
        XCTAssertEqual(texts.count, 1)
        XCTAssertEqual(texts[0].text, "第一頁的重點")
        XCTAssertEqual(texts[0].x, 120, accuracy: 0.5)
        XCTAssertEqual(texts[0].y, 480, accuracy: 0.5)
        XCTAssertEqual(texts[0].pageIndex, 0)
    }

    func testTransparentCardColourSurvives() throws {
        // "clear" 是哨符不是顏色。走過任何顏色轉換就會變成黑色。
        let (_, imported) = try roundTrip()
        XCTAssertEqual(imported.document.textAttachments?[0].backgroundColorHex, "clear")
    }

    func testParagraphSettingsSurvive() throws {
        let (_, imported) = try roundTrip()
        XCTAssertEqual(imported.document.textAttachments?[0].lineSpacing, 8)
        XCTAssertEqual(imported.document.textAttachments?[0].isBold, true)
    }

    // MARK: - 圖片

    func testImageBytesComeBack() throws {
        // 位元組沒回來的話，另一台裝置打得開筆記，畫面上卻是一格空白。
        let (_, imported) = try roundTrip()
        XCTAssertEqual(imported.imageData.count, 2)
        for (_, bytes) in imported.imageData {
            XCTAssertGreaterThan(bytes.count, 0)
            XCTAssertNotNil(UIImage(data: bytes), "回來的不是一張讀得開的圖")
        }
    }

    func testImageFileNamesAreStable() throws {
        // 每次同步都換一組新檔名的話，比對與去重就失效了。
        let (_, imported) = try roundTrip()
        XCTAssertEqual(Set(imported.imageData.keys), ["photo.png", "chart.png"])
    }

    func testImageStyleSurvives() throws {
        // 掉了的話，每張圖都會變回一張沒有樣式的方形照片。
        let (_, imported) = try roundTrip()
        let photo = try XCTUnwrap(
            imported.document.attachments?.first { $0.fileName == "photo.png" })
        XCTAssertEqual(photo.cornerRadius, 18)
        XCTAssertEqual(photo.hasBorder, true)
        XCTAssertEqual(photo.borderColorHex, "#FF0000")
        XCTAssertEqual(photo.borderWidth, 3)
        XCTAssertEqual(photo.rotationDegrees, 12, accuracy: 0.01)
        XCTAssertEqual(photo.filterStyle, .vintage)
    }

    func testImagePositionAndSizeSurvive() throws {
        let (_, imported) = try roundTrip()
        let chart = try XCTUnwrap(
            imported.document.attachments?.first { $0.fileName == "chart.png" })
        XCTAssertEqual(chart.x, 60, accuracy: 0.5)
        XCTAssertEqual(chart.y, 200, accuracy: 0.5)
        XCTAssertEqual(chart.width, 420, accuracy: 0.5)
        XCTAssertEqual(chart.height, 300, accuracy: 0.5)
        XCTAssertEqual(chart.pageIndex, 1)
    }

    func testAChartStaysEditableAfterTheRoundTrip() throws {
        // 這是數字製圖那一輪的承諾：跨過套件之後還改得動。
        let (_, imported) = try roundTrip()
        let chart = try XCTUnwrap(
            imported.document.attachments?.first { $0.fileName == "chart.png" })
        let spec = try XCTUnwrap(chart.chartSpec)
        XCTAssertEqual(spec.title, "營收")
        XCTAssertEqual(spec.series[0].values, [10, 20])
    }

    func testAPlainPhotoIsNotTurnedIntoAChart() throws {
        let (_, imported) = try roundTrip()
        let photo = try XCTUnwrap(
            imported.document.attachments?.first { $0.fileName == "photo.png" })
        XCTAssertNil(photo.chartSpec)
    }

    // MARK: - 穩定性

    func testASecondRoundTripChangesNothing() throws {
        // 同步會來回很多次。每一趟都讓內容漂一點的話，幾趟之後就走樣了。
        let (doc, drawings, images) = try richNotebook()
        let first = workDir.appendingPathComponent("a.padnote")
        try NotebookPackageBridge.export(
            document: doc, drawings: drawings, imageData: images, to: first, deviceId: 0xE3)
        let once = try NotebookPackageBridge.importDocument(
            fromPackageAt: first, deviceId: 0xE4, documentId: doc.id)

        let second = workDir.appendingPathComponent("b.padnote")
        try NotebookPackageBridge.export(
            document: once.document, drawings: once.drawings,
            imageData: once.imageData, to: second, deviceId: 0xE5)
        let twice = try NotebookPackageBridge.importDocument(
            fromPackageAt: second, deviceId: 0xE6, documentId: doc.id)

        XCTAssertEqual(twice.document.title, once.document.title)
        XCTAssertEqual(twice.document.pageCount, once.document.pageCount)
        XCTAssertEqual(twice.document.template, once.document.template)
        XCTAssertEqual(twice.document.folderId, once.document.folderId)
        XCTAssertEqual(twice.document.attachments?.count, once.document.attachments?.count)
        XCTAssertEqual(twice.document.textAttachments?.count, once.document.textAttachments?.count)
        XCTAssertEqual(twice.document.commentPins?.count, once.document.commentPins?.count)
        XCTAssertEqual(twice.drawings[0].strokes.count, once.drawings[0].strokes.count)
        XCTAssertEqual(Set(twice.imageData.keys), Set(once.imageData.keys))
    }

    func testTheMetaJSONIsStable() throws {
        // 內容沒變卻產生不同的位元組，同步時每次都看起來像使用者改了東西。
        let (doc, _, _) = try richNotebook()
        XCTAssertEqual(
            NotebookMeta(from: doc).encodedJSON(), NotebookMeta(from: doc).encodedJSON())
    }

    // MARK: - 壞掉的輸入

    func testImportingANonPackageFailsCleanly() throws {
        let bogus = workDir.appendingPathComponent("bogus.padnote")
        try Data("不是套件".utf8).write(to: bogus)
        XCTAssertThrowsError(
            try NotebookPackageBridge.importDocument(fromPackageAt: bogus, deviceId: 0xE7))
    }

    func testCorruptMetaStillYieldsAUsableNotebook() throws {
        // 中繼資料壞掉最多是「回到預設樣板」，不該讓整本筆記開不起來 ——
        // 筆畫與文字都還在。
        var document = NotebookDocument(title: "壞中繼資料", pageCount: 1)
        document.textAttachments = [NoteTextAttachment(pageIndex: 0, text: "還在")]
        let path = workDir.appendingPathComponent("corrupt-meta.padnote")
        try NotebookPackageBridge.export(
            document: document, drawings: [PKDrawing(strokes: [stroke(at: 5, color: .black)])],
            to: path, deviceId: 0xE8)

        let session = try PadnoteSession.openExisting(path: path.path, deviceId: 0xE8)
        try session.setNotebookMeta(json: "壞掉的內容")

        let imported = try NotebookPackageBridge.importDocument(
            fromPackageAt: path, deviceId: 0xE9)
        XCTAssertEqual(imported.drawings[0].strokes.count, 1)
        XCTAssertEqual(imported.document.textAttachments?.first?.text, "還在")
    }
}

extension PackageRoundTripTests {

    func testALinkCardDoesNotAlsoComeBackAsAStrayImage() throws {
        // 連結卡片在套件裡是一張算繪出來的圖（PDF 裡才看得到），真身則跟著
        // 中繼資料走。兩邊都收的話，同一張卡片會變成兩份，而且每同步一趟
        // 就再多一份 —— 使用者會看到畫面上慢慢長出重複的東西。
        let (_, imported) = try roundTrip()
        let fileNames = Set(imported.document.attachments?.map(\.fileName) ?? [])
        XCTAssertEqual(fileNames, ["photo.png", "chart.png"],
                       "多出來的是連結卡片或 3D 模型的衍生圖片")
        XCTAssertEqual(imported.document.linkAttachments?.count, 1, "真身只能有一份")
    }
}

/// 兩台裝置寫同一個套件。
///
/// # 這組測試在守什麼
///
/// 架構上有一條保證：**每台裝置只寫自己 device_id 的檔案**。同步之後，套件裡
/// 已經有另一台裝置下載下來的 oplog 與筆畫檔 —— 這台裝置再匯出一次時，
/// 那些檔案不能被動到。動到的後果是對方的編輯悄悄消失，而且雙方都不會收到
/// 任何錯誤訊息。
final class PackageMultiDeviceTests: XCTestCase {

    private var workDir: URL!
    private let deviceA: UInt32 = 0x0A0A0A0A
    private let deviceB: UInt32 = 0x0B0B0B0B

    override func setUpWithError() throws {
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-md-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workDir)
    }

    private func stroke(at x: CGFloat) -> PKStroke {
        let points = (0..<6).map { i in
            PKStrokePoint(
                location: CGPoint(x: x + CGFloat(i) * 3, y: 100),
                timeOffset: Double(i) * 0.01,
                size: CGSize(width: 4, height: 4),
                opacity: 1, force: 1, azimuth: 1, altitude: 1
            )
        }
        return PKStroke(
            ink: PKInk(.pen, color: .black),
            path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0))
        )
    }

    private func document(_ title: String) -> NotebookDocument {
        NotebookDocument(title: title, pageCount: 1)
    }

    /// 檔名裡帶著某台裝置 id 的檔案。
    private func files(of deviceId: UInt32, in package: URL) -> [String] {
        let suffix = NotebookPackageBridge.deviceSuffix(deviceId)
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: package, includingPropertiesForKeys: nil) else { return [] }
        var out: [String] = []
        for case let url as URL in walker where url.lastPathComponent.contains(suffix) {
            out.append(url.lastPathComponent)
        }
        return out
    }

    func testAnotherDevicesFilesSurviveAReExport() throws {
        // 這是同步會不會吃掉對方編輯的關鍵。
        let package = workDir.appendingPathComponent("shared.padnote")

        // B 先寫，檔案留在套件裡（模擬同步下載下來的那些）。
        try NotebookPackageBridge.export(
            document: document("B 寫的"), drawings: [PKDrawing(strokes: [stroke(at: 50)])],
            to: package, deviceId: deviceB)
        let bFilesBefore = Set(files(of: deviceB, in: package))
        XCTAssertFalse(bFilesBefore.isEmpty, "測試前提不成立：B 應該要有檔案")

        // A 接著匯出自己的版本。
        try NotebookPackageBridge.exportPreservingOtherDevices(
            document: document("A 寫的"), drawings: [PKDrawing(strokes: [stroke(at: 10)])],
            to: package, deviceId: deviceA)

        XCTAssertEqual(Set(files(of: deviceB, in: package)), bFilesBefore,
                       "A 匯出時把 B 的檔案動掉了 —— B 的編輯會悄悄消失")
        XCTAssertFalse(files(of: deviceA, in: package).isEmpty, "A 自己的檔案要寫進去")
    }

    func testBothDevicesStrokesLandOnTheSamePage() throws {
        // 檔案還在還不夠 —— 兩邊的筆畫要落在**同一頁**上。
        // 頁面 id 沒有沿用的話，合併之後不是一頁有兩邊的內容，而是變成兩頁。
        let package = workDir.appendingPathComponent("both.padnote")
        try NotebookPackageBridge.export(
            document: document("B"), drawings: [PKDrawing(strokes: [stroke(at: 50)])],
            to: package, deviceId: deviceB)
        try NotebookPackageBridge.exportPreservingOtherDevices(
            document: document("A"), drawings: [PKDrawing(strokes: [stroke(at: 10)])],
            to: package, deviceId: deviceA)

        let drawings = try NotebookPackageBridge.drawings(fromPackageAt: package, deviceId: deviceA)
        XCTAssertEqual(drawings.count, 1, "頁數變多了 —— 頁面 id 沒有沿用")
        XCTAssertEqual(drawings[0].strokes.count, 2, "兩台裝置的筆畫都要在同一頁")
    }

    func testPageCountDoesNotGrowAcrossRepeatedSyncs() throws {
        // 同步會來回很多次。每一趟多一批頁的話，幾趟之後筆記就爆掉了。
        let package = workDir.appendingPathComponent("repeat.padnote")
        try NotebookPackageBridge.export(
            document: document("起點"), drawings: [PKDrawing(strokes: [stroke(at: 50)])],
            to: package, deviceId: deviceB)

        for round in 0..<4 {
            let deviceId = round.isMultiple(of: 2) ? deviceA : deviceB
            let imported = try NotebookPackageBridge.importDocument(
                fromPackageAt: package, deviceId: deviceId)
            try NotebookPackageBridge.exportPreservingOtherDevices(
                document: imported.document, drawings: imported.drawings,
                imageData: imported.imageData, to: package, deviceId: deviceId,
                pageIds: imported.pageIds)
        }

        let drawings = try NotebookPackageBridge.drawings(fromPackageAt: package, deviceId: deviceA)
        XCTAssertEqual(drawings.count, 1, "來回四趟之後頁數應該還是 1")
    }

    func testReExportingTwiceDoesNotDuplicateOwnContent() throws {
        // 這台裝置自己的舊檔要先清掉，否則同一筆畫會疊加上去。
        let package = workDir.appendingPathComponent("twice.padnote")
        let doc = document("A")
        let drawing = [PKDrawing(strokes: [stroke(at: 10)])]

        try NotebookPackageBridge.exportPreservingOtherDevices(
            document: doc, drawings: drawing, to: package, deviceId: deviceA)
        try NotebookPackageBridge.exportPreservingOtherDevices(
            document: doc, drawings: drawing, to: package, deviceId: deviceA)

        let drawings = try NotebookPackageBridge.drawings(fromPackageAt: package, deviceId: deviceA)
        XCTAssertEqual(drawings[0].strokes.count, 1, "重複匯出讓內容疊起來了")
    }

    func testExportingIntoAnEmptyLocationBehavesLikeANormalExport() throws {
        let package = workDir.appendingPathComponent("fresh.padnote")
        let summary = try NotebookPackageBridge.exportPreservingOtherDevices(
            document: document("新的"), drawings: [PKDrawing(strokes: [stroke(at: 10)])],
            to: package, deviceId: deviceA)
        XCTAssertEqual(summary.strokeCount, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: package.path))
    }

    func testTheOtherDevicesTextBlocksSurvive() throws {
        // 筆畫以外的內容也走 oplog，同樣不能被洗掉。
        let package = workDir.appendingPathComponent("text.padnote")
        var bDoc = document("B")
        bDoc.textAttachments = [NoteTextAttachment(pageIndex: 0, text: "B 寫的字")]
        try NotebookPackageBridge.export(
            document: bDoc, drawings: [PKDrawing()], to: package, deviceId: deviceB)

        try NotebookPackageBridge.exportPreservingOtherDevices(
            document: document("A"), drawings: [PKDrawing(strokes: [stroke(at: 10)])],
            to: package, deviceId: deviceA)

        let imported = try NotebookPackageBridge.importDocument(
            fromPackageAt: package, deviceId: deviceA)
        XCTAssertTrue(
            imported.document.textAttachments?.contains { $0.text == "B 寫的字" } ?? false,
            "B 的文字方塊被 A 的匯出洗掉了"
        )
    }
}
