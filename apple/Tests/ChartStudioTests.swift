//
//  ChartStudioTests.swift
//  KairumoTests
//
//  數字製圖的 Swift 側測試。
//
//  核心已經釘住了版面計算（`crates/padnote-chart`），這裡驗的是**平台這一邊**：
//  規格能不能無損地存進筆記檔再讀回來（那是「可重新編修」的全部依據）、
//  表格編輯會不會把資料弄壞、以及算繪出來的圖是不是真的有內容。
//

import XCTest
import PencilKit
@testable import Kairumo

final class ChartStudioTests: XCTestCase {

    private func sample() -> ChartSpec {
        var spec = ChartSpec()
        spec.kind = .stackedBar
        spec.title = "季度營收"
        spec.categories = ["Q1", "Q2", "Q3"]
        spec.series = [
            ChartSeries(name: "北區", values: [10, 20, 30]),
            ChartSeries(name: "南區", values: [5, 15, 25], colorHex: "#FF8800")
        ]
        spec.dataLabels = .outside
        spec.labelDecimals = 1
        spec.yAxis.title = "千元"
        spec.yAxis.min = -5
        spec.barWidthRatio = 0.55
        return spec
    }

    // MARK: - 可重新編修

    func testSpecSurvivesAJSONRoundTrip() throws {
        // 這條測試掉了，使用者再打開圖表時就只剩一張改不動的圖片。
        let original = sample()
        let restored = try XCTUnwrap(ChartSpec.decode(from: original.encodedJSON()))

        XCTAssertEqual(restored.kind, .stackedBar)
        XCTAssertEqual(restored.title, "季度營收")
        XCTAssertEqual(restored.categories, ["Q1", "Q2", "Q3"])
        XCTAssertEqual(restored.series.map(\.name), ["北區", "南區"])
        XCTAssertEqual(restored.series[1].values, [5, 15, 25])
        XCTAssertEqual(restored.series[1].colorHex, "#FF8800")
        XCTAssertEqual(restored.dataLabels, .outside)
        XCTAssertEqual(restored.labelDecimals, 1)
        XCTAssertEqual(restored.yAxis.title, "千元")
        XCTAssertEqual(restored.yAxis.min, -5)
        XCTAssertEqual(restored.barWidthRatio, 0.55, accuracy: 1e-9)
    }

    func testEncodingIsStable() {
        // 同一份規格要得到同一份位元組，否則每次存檔都會產生一筆「內容有變」
        // 的操作，同步時看起來像使用者改了東西。
        let spec = sample()
        XCTAssertEqual(spec.encodedJSON(), spec.encodedJSON())
        XCTAssertEqual(ChartSpec.decode(from: spec.encodedJSON())?.encodedJSON(), spec.encodedJSON())
    }

    func testAnUnknownFieldDoesNotBreakDecoding() throws {
        // 新版多寫了欄位，舊版仍要打得開 —— 讀不回來等於使用者的資料消失。
        let json = #"{"kind":"line","series":[{"name":"a","values":[1,2]}],"futureField":7}"#
        let spec = try XCTUnwrap(ChartSpec.decode(from: json))
        XCTAssertEqual(spec.kind, .line)
        XCTAssertEqual(spec.series[0].values, [1, 2])
    }

    func testAMissingFieldFallsBackToTheSameDefaultAsTheCore() throws {
        let spec = try XCTUnwrap(ChartSpec.decode(from: #"{"series":[{"values":[1]}]}"#))
        XCTAssertEqual(spec.kind, .bar)
        XCTAssertEqual(spec.legend, .bottom)
        XCTAssertTrue(spec.yAxis.showGrid, "Y 軸格線預設要開，跟核心一致")
        XCTAssertEqual(spec.barWidthRatio, 0.7, accuracy: 1e-9)
    }

    func testGarbageDecodesToNilRatherThanCrashing() {
        XCTAssertNil(ChartSpec.decode(from: "{ not json"))
        XCTAssertNil(ChartSpec.decode(from: ""))
    }

    func testTheDefaultSpecComesFromTheCoreAndIsDrawable() {
        // 新插入的圖表必須馬上看得到東西，空白的圖表看起來像壞掉了。
        let spec = ChartSpec.makeDefault()
        XCTAssertFalse(spec.series.isEmpty)
        XCTAssertTrue(spec.isDrawable)
    }

    // MARK: - 附件上的規格

    func testAnImageAttachmentCarriesItsChartSpec() throws {
        let spec = sample()
        let attachment = NoteImageAttachment(fileName: "chart.png", chartSpecJSON: spec.encodedJSON())
        XCTAssertEqual(try XCTUnwrap(attachment.chartSpec).title, "季度營收")
    }

    func testAPlainImageHasNoChartSpec() {
        XCTAssertNil(NoteImageAttachment(fileName: "photo.png").chartSpec)
    }

    func testACorruptSpecDoesNotBreakTheAttachment() {
        // 規格壞掉最多是「這張圖改不動了」，不該讓整本筆記開不起來。
        let attachment = NoteImageAttachment(fileName: "chart.png", chartSpecJSON: "壞掉的內容")
        XCTAssertNil(attachment.chartSpec)
    }

    func testAttachmentEncodingKeepsTheSpec() throws {
        // 附件本身也要能存進 JSON 再讀回來，否則關掉 App 就沒了。
        let original = NoteImageAttachment(fileName: "chart.png", chartSpecJSON: sample().encodedJSON())
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(NoteImageAttachment.self, from: data)
        XCTAssertEqual(restored.chartSpecJSON, original.chartSpecJSON)
    }

    func testAnOlderNotebookWithoutTheFieldStillDecodes() throws {
        // 這個欄位是後來加的。舊筆記裡沒有它，解碼一定要照樣成功。
        let json = #"{"id":"1","fileName":"a.png","pageIndex":0,"x":0,"y":0,"width":10,"height":10,"rotationDegrees":0,"cornerRadius":0,"hasShadow":false,"hasBorder":false,"filterStyle":"原圖"}"#
        let restored = try JSONDecoder().decode(NoteImageAttachment.self, from: XCTUnwrap(json.data(using: .utf8)))
        XCTAssertNil(restored.chartSpecJSON)
    }

    // MARK: - 區塊外觀（跨平台的那一段）

    func testTheBlockAppearanceRoundTripsThroughTheWrapper() throws {
        let spec = sample()
        let restored = try XCTUnwrap(ChartAppearance.decode(ChartAppearance.encode(spec)))
        XCTAssertEqual(restored.encodedJSON(), spec.encodedJSON(), "包一層之後規格變了")
    }

    func testANonChartAppearanceIsNotMistakenForAChart() {
        // 文字方塊的外觀走的是同一個欄位。認錯了會把文字方塊當成圖表開。
        XCTAssertNil(ChartAppearance.decode(#"{"backgroundColorHex":"clear"}"#))
        XCTAssertNil(ChartAppearance.decode("{}"))
        XCTAssertNil(ChartAppearance.decode("not json"))
    }

    // MARK: - 表格編輯

    func testAddingARowExtendsEverySeries() {
        // 只加一欄的話，欄與欄會對不齊，圖就畫歪了。
        var spec = sample()
        spec.addRow()
        XCTAssertEqual(spec.rowCount, 4)
        XCTAssertTrue(spec.series.allSatisfy { $0.values.count == 4 })
    }

    func testRemovingARowRemovesItFromEverySeries() {
        var spec = sample()
        spec.removeRow(0)
        XCTAssertEqual(spec.categories, ["Q2", "Q3"])
        XCTAssertEqual(spec.series[0].values, [20, 30])
        XCTAssertEqual(spec.series[1].values, [15, 25])
    }

    func testTheLastRowCannotBeRemoved() {
        // 沒有資料的圖表畫不出來，畫布會忽然變空白。
        var spec = ChartSpec()
        spec.series = [ChartSeries(values: [1])]
        spec.categories = ["只有一列"]
        spec.removeRow(0)
        XCTAssertEqual(spec.rowCount, 1)
    }

    func testTheLastSeriesCannotBeRemoved() {
        var spec = ChartSpec()
        spec.series = [ChartSeries(values: [1])]
        spec.removeSeries(0)
        XCTAssertEqual(spec.series.count, 1)
    }

    func testANewSeriesIsAlignedAndColoured() {
        var spec = sample()
        spec.addSeries()
        XCTAssertEqual(spec.series.count, 3)
        XCTAssertEqual(spec.series[2].values.count, spec.rowCount, "新數列沒有跟上列數")
        XCTAssertFalse(spec.series[2].colorHex.isEmpty, "新數列要拿到色盤的顏色")
    }

    func testWritingBeyondTheEndPadsInsteadOfCrashing() {
        var spec = sample()
        spec.setValue(99, series: 0, row: 6)
        XCTAssertEqual(spec.value(series: 0, row: 6), 99)
        XCTAssertEqual(spec.value(series: 0, row: 5), 0, "中間的空格要補 0")
    }

    func testReadingOutOfRangeReturnsZero() {
        let spec = sample()
        XCTAssertEqual(spec.value(series: 9, row: 0), 0)
        XCTAssertEqual(spec.value(series: 0, row: 99), 0)
    }

    func testRowCountTakesTheLongerOfCategoriesAndValues() {
        // 使用者多打了一列數字卻沒補類別名稱時，那列不該消失。
        var spec = ChartSpec()
        spec.categories = ["a"]
        spec.series = [ChartSeries(values: [1, 2, 3])]
        XCTAssertEqual(spec.rowCount, 3)
    }

    func testTheColourShownInThePickerIsTheColourDrawn() {
        // 取色器顯示的顏色跟畫出來的不一樣，使用者會以為自己改錯了。
        var spec = sample()
        spec.series[0].colorHex = ""
        XCTAssertEqual(spec.effectiveColorHex(0), chartPaletteColor(index: 0))
        XCTAssertEqual(spec.effectiveColorHex(1), "#FF8800")
    }

    // MARK: - 算繪

    func testEveryChartKindRendersSomething() throws {
        // 新增類型時最容易發生的事，是忘了接上繪製 —— 圖表會靜靜地空白。
        for kind in ChartKind.allCases {
            var spec = sample()
            spec.kind = kind
            let image = try XCTUnwrap(
                ChartRenderer.image(spec: spec, size: CGSize(width: 420, height: 300)),
                "\(kind) 算繪不出點陣圖"
            )
            XCTAssertGreaterThan(image.size.width, 0)
            XCTAssertFalse(isBlank(image), "\(kind) 算繪出來是一片空白")
        }
    }

    func testATinyCanvasReportsAReasonInsteadOfDrawingNothing() {
        let spec = sample()
        let tiny = CGSize(width: 10, height: 10)
        XCTAssertNil(ChartRenderer.layout(spec: spec, size: tiny))
        XCTAssertFalse(
            (ChartRenderer.failureReason(spec: spec, size: tiny) ?? "").isEmpty,
            "算不出來就要講出原因，空白畫布看起來像壞掉了"
        )
    }

    func testAnEmptySpecIsNotDrawable() {
        XCTAssertFalse(ChartSpec().isDrawable)
    }

    func testTheLayoutComesFromTheCore() throws {
        // 幾何若哪天被搬回 Swift 算，兩個平台就會畫出不一樣的圖。
        let spec = sample()
        let layout = try XCTUnwrap(ChartRenderer.layout(spec: spec, size: CGSize(width: 420, height: 300)))
        XCTAssertEqual(layout.bars.count, 6, "兩個數列三列資料應該是六根長條")
        XCTAssertEqual(layout.legend.count, 2)
        XCTAssertTrue(layout.labels.contains { $0.text == "季度營收" })
    }

    /// 這張圖是不是完全透明 —— 「有畫出東西」最低限度的檢查。
    private func isBlank(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return true }
        let width = 24, height = 24
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return true }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return !pixels.enumerated().contains { $0.offset % 4 == 3 && $0.element > 0 }
    }
}

/// 圖表跨過 `.padnote` 套件的那一段。
///
/// 這是使用者真正在乎的那條路：在 iPad 上插一張圖表，同步到 Android（或反過來），
/// 打開之後**還改得動**。中間任何一段掉東西都會在這裡現形，而不是等到他在另一台
/// 裝置上打開才發現。
final class ChartPackageRoundTripTests: XCTestCase {

    private var workDir: URL!

    override func setUpWithError() throws {
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-chart-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workDir)
    }

    private func spec() -> ChartSpec {
        var spec = ChartSpec()
        spec.kind = .doughnut
        spec.title = "市佔"
        spec.categories = ["甲", "乙", "丙"]
        spec.series = [ChartSeries(name: "份額", values: [30, 45, 25])]
        spec.doughnutHoleRatio = 0.4
        spec.dataLabels = .outside
        return spec
    }

    private func notebookWithChart() throws -> (NotebookDocument, [String: Data]) {
        let chartSpec = spec()
        let image = try XCTUnwrap(ChartRenderer.image(spec: chartSpec, size: CGSize(width: 420, height: 300)))
        let png = try XCTUnwrap(image.pngData())

        var doc = NotebookDocument(title: "帶圖表的筆記", pageCount: 1)
        doc.attachments = [
            NoteImageAttachment(
                fileName: "chart.png", pageIndex: 0, x: 120, y: 260,
                width: 420, height: 300, chartSpecJSON: chartSpec.encodedJSON()
            )
        ]
        return (doc, ["chart.png": png])
    }

    func testAChartSpecSurvivesThePackage() throws {
        let (doc, images) = try notebookWithChart()
        let path = workDir.appendingPathComponent("chart.padnote")
        try NotebookPackageBridge.export(
            document: doc, drawings: [PKDrawing()], imageData: images, to: path, deviceId: 0xC1)

        let charts = try NotebookPackageBridge.charts(fromPackageAt: path, deviceId: 0xD1)
        XCTAssertEqual(charts.count, 1, "圖表沒有跨過套件 —— 在另一台裝置上就改不動了")
        let restored = try XCTUnwrap(charts.first)
        XCTAssertEqual(restored.spec.kind, .doughnut)
        XCTAssertEqual(restored.spec.title, "市佔")
        XCTAssertEqual(restored.spec.categories, ["甲", "乙", "丙"])
        XCTAssertEqual(restored.spec.series[0].values, [30, 45, 25])
        XCTAssertEqual(restored.spec.doughnutHoleRatio, 0.4, accuracy: 1e-6)
        XCTAssertEqual(restored.spec.dataLabels, .outside)
    }

    func testAChartKeepsItsPlaceAndSizeThroughThePackage() throws {
        // 位置與尺寸沒跟過去的話，圖會跑到左上角、變回預設大小。
        let (doc, images) = try notebookWithChart()
        let path = workDir.appendingPathComponent("place.padnote")
        try NotebookPackageBridge.export(
            document: doc, drawings: [PKDrawing()], imageData: images, to: path, deviceId: 0xC2)

        let chart = try XCTUnwrap(
            NotebookPackageBridge.charts(fromPackageAt: path, deviceId: 0xD2).first)
        XCTAssertEqual(chart.x, 120, accuracy: 0.5)
        XCTAssertEqual(chart.y, 260, accuracy: 0.5)
        XCTAssertEqual(chart.width, 420, accuracy: 0.5)
        XCTAssertEqual(chart.height, 300, accuracy: 0.5)
        XCTAssertEqual(chart.pageIndex, 0)
    }

    func testAPlainImageIsNotReadBackAsAChart() throws {
        // 一般的圖片照樣是圖片，不該被誤認成圖表而開進編輯器。
        var doc = NotebookDocument(title: "只有照片", pageCount: 1)
        doc.attachments = [NoteImageAttachment(fileName: "photo.png", pageIndex: 0)]
        let png = try XCTUnwrap(
            UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
                .image { _ in UIColor.orange.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 4, height: 4)) }
                .pngData()
        )
        let path = workDir.appendingPathComponent("photo.padnote")
        try NotebookPackageBridge.export(
            document: doc, drawings: [PKDrawing()], imageData: ["photo.png": png],
            to: path, deviceId: 0xC3)

        XCTAssertTrue(
            try NotebookPackageBridge.charts(fromPackageAt: path, deviceId: 0xD3).isEmpty)
    }

    func testTheRestoredSpecRendersTheSameGeometry() throws {
        // 「讀得回來」還不夠 —— 讀回來的設定必須畫出同一張圖。
        let (doc, images) = try notebookWithChart()
        let path = workDir.appendingPathComponent("geometry.padnote")
        try NotebookPackageBridge.export(
            document: doc, drawings: [PKDrawing()], imageData: images, to: path, deviceId: 0xC4)

        let restored = try XCTUnwrap(
            NotebookPackageBridge.charts(fromPackageAt: path, deviceId: 0xD4).first).spec
        let size = CGSize(width: 420, height: 300)
        let before = try XCTUnwrap(ChartRenderer.layout(spec: spec(), size: size))
        let after = try XCTUnwrap(ChartRenderer.layout(spec: restored, size: size))

        XCTAssertEqual(after.slices.count, before.slices.count)
        for index in before.slices.indices {
            XCTAssertEqual(after.slices[index].startAngle, before.slices[index].startAngle, accuracy: 1e-9)
            XCTAssertEqual(after.slices[index].innerRadius, before.slices[index].innerRadius, accuracy: 1e-6)
        }
    }
}
