import CoreGraphics
import PencilKit
import XCTest

@testable import Kairumo

/// 匯出的 PNG 上的文字必須是**真的字**（工作項 S-60）。
///
/// 核心的純 Rust 光柵化器把文字畫成灰色行條。Apple 的縮圖不走那裡
/// （`PageThumbnailRenderer` 用 UIKit 畫），但匯出 PNG 一直走 —— 所以畫面上
/// 看得到字、匯出的圖卻是一排灰條。這組測試守的就是那個落差不要回來。
final class PageImageRendererTests: XCTestCase {

    private var workDir: URL!

    override func setUpWithError() throws {
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("page-image-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workDir)
    }

    /// 開一本只有一段文字的筆記，回傳匯出 PNG 裡的暗像素數。
    private func inkPixels(of text: String?) throws -> Int {
        var document = NotebookDocument(title: "字型", pageCount: 1)
        if let text {
            document.textAttachments = [NoteTextAttachment(pageIndex: 0, text: text)]
        }
        let path = workDir.appendingPathComponent("\(UUID().uuidString).padnote")
        try NotebookPackageBridge.export(
            document: document, drawings: [PKDrawing()], to: path, deviceId: 0xE8)
        let session = try PadnoteSession.openExisting(path: path.path, deviceId: 0xE8)
        guard let page = try session.firstPageId() else {
            XCTFail("這本筆記沒有頁面")
            return 0
        }
        let png = try PageImageRenderer.renderPng(session: session, pageId: page, scale: 2.0)
        return try darkPixels(inPng: png)
    }

    private func darkPixels(inPng png: Data) throws -> Int {
        guard let provider = CGDataProvider(data: png as CFData),
              let image = CGImage(
                pngDataProviderSource: provider, decode: nil,
                shouldInterpolate: false, intent: .defaultIntent)
        else {
            XCTFail("匯出的不是一張讀得回來的 PNG")
            return 0
        }
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let ctx = CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            XCTFail("建不出點陣內容")
            return 0
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var dark = 0
        for i in stride(from: 0, to: pixels.count, by: 4)
        where pixels[i] < 120 && pixels[i + 1] < 120 && pixels[i + 2] < 120 {
            dark += 1
        }
        return dark
    }

    func testChineseTextIsDrawnAsRealGlyphsNotTofuOrGreyBars() throws {
        // **筆畫密度是唯一問得出真假的問題。** 灰條、豆腐框（▯）與真字形
        // 三者都有暗像素，光看「有沒有墨」分不出來。但筆畫少的字與筆畫多的
        // 字，只有真字形才會差很多。
        let light = try inkPixels(of: String(repeating: "一", count: 8))
        let heavy = try inkPixels(of: String(repeating: "鬱", count: 8))
        XCTAssertGreaterThan(light, 0, "「一」該有墨，實得 \(light)")
        XCTAssertGreaterThan(
            heavy, light * 3,
            "「鬱」的墨量該遠多於「一」（heavy=\(heavy) light=\(light)）—— "
                + "兩者接近代表畫出來的是灰條或豆腐框，不是字")
    }

    func testAPageWithOnlyTypedTextIsNotBlank() throws {
        let blank = try inkPixels(of: nil)
        let typed = try inkPixels(of: "特徵值與特徵向量")
        XCTAssertGreaterThan(
            typed, blank + 200, "只打字的頁面匯出不該與空白頁一樣（\(typed) vs \(blank)）")
    }
}
