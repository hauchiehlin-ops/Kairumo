import XCTest
import PDFKit
import UIKit

@testable import Kairumo

/// 「插入 PDF 頁面」真的畫得出東西嗎？
///
/// # 為什麼要有這條
///
/// 這條路上每一步都是系統 API（PDFKit），編得過完全不代表跑得動 ——
/// 而它的失敗方式**不會丟例外**：畫出一張全白的圖。使用者看到的是
/// 「插進去了，可是是空白的」，沒有任何錯誤訊息可以查。
///
/// 所以這裡不只看「有沒有回傳一張圖」，還數了非白的像素。
/// Android 端的對應物是 `PdfPageRenderTest`。
@MainActor
final class PdfPageRendererTests: XCTestCase {

    /// 造一份 `pages` 頁的 PDF，第 n 頁畫 n 個黑方塊。
    ///
    /// 每頁內容量不同是刻意的：只看「有沒有東西」的話，一支永遠回傳
    /// 第一頁的實作也會過。
    private func makePdf(pages: Int) throws -> URL {
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 300)
        let url = FileManager.default.temporaryDirectory
            .appending(path: "probe-\(UUID().uuidString).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        try renderer.writePDF(to: url) { ctx in
            for i in 0..<pages {
                ctx.beginPage()
                UIColor.black.setFill()
                for n in 0...i {
                    let left = 10.0 + Double(n) * 40.0
                    ctx.cgContext.fill(CGRect(x: left, y: 10, width: 30, height: 30))
                }
            }
        }
        return url
    }

    private func darkPixels(_ image: UIImage) throws -> Int {
        let cg = try XCTUnwrap(image.cgImage, "算繪出來的不是一張點陣圖")
        let width = cg.width
        let height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let ctx = try XCTUnwrap(CGContext(
            data: &pixels, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        var dark = 0
        for i in stride(from: 0, to: pixels.count, by: 4) where pixels[i] < 128 {
            dark += 1
        }
        return dark
    }

    func testEveryPageRendersItsOwnContent() throws {
        let url = try makePdf(pages: 3)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(PdfPageRenderer.pageCount(url: url), 3)

        var counts: [Int] = []
        for index in 0..<3 {
            let image = try XCTUnwrap(
                PdfPageRenderer.render(url: url, pageIndex: index),
                "第 \(index + 1) 頁算不出來")
            counts.append(try darkPixels(image))
        }

        XCTAssertGreaterThan(counts[0], 0, "第一頁一個暗像素都沒有 —— 畫出來是全白的")
        XCTAssertEqual(
            Set(counts).count, 3,
            "三頁的內容量一樣（\(counts)）—— 多半每次都畫了同一頁")
        XCTAssertTrue(
            counts[0] < counts[1] && counts[1] < counts[2],
            "頁數愈後面方塊愈多，暗像素卻沒有遞增：\(counts)")
    }

    func testAnOutOfRangePageIsRefusedNotGuessed() throws {
        // 回 nil 才能讓介面顯示「這一頁畫不出來」。悄悄退回第一頁的話，
        // 使用者拿到的是一頁他沒有選的東西。
        let url = try makePdf(pages: 1)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertNil(PdfPageRenderer.render(url: url, pageIndex: 5))
        XCTAssertNil(PdfPageRenderer.render(url: url, pageIndex: -1))
    }

    func testABrokenFileFailsQuietlyInsteadOfCrashing() throws {
        // 副檔名是 .pdf 但內容不是 —— 核心的 `importCheck` 只看副檔名
        // （刻意的），所以這種檔案一定會走到這裡。
        let url = FileManager.default.temporaryDirectory
            .appending(path: "broken-\(UUID().uuidString).pdf")
        try Data("this is not a pdf".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(PdfPageRenderer.pageCount(url: url), 0)
        XCTAssertNil(PdfPageRenderer.render(url: url, pageIndex: 0))
    }

    /// 底色是白的，不是透明的。
    ///
    /// 透明的話存進畫布後在淺色介面上看起來像插了一張空白頁 ——
    /// 兩端都踩過同一個坑，所以兩端都有這條。
    func testThePageBackgroundIsWhiteNotTransparent() throws {
        let url = try makePdf(pages: 1)
        defer { try? FileManager.default.removeItem(at: url) }

        let image = try XCTUnwrap(PdfPageRenderer.render(url: url, pageIndex: 0))
        let cg = try XCTUnwrap(image.cgImage)
        var pixel = [UInt8](repeating: 0, count: 4)
        let ctx = try XCTUnwrap(CGContext(
            data: &pixel, width: 1, height: 1,
            bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        // 右下角：那裡一定沒有方塊。
        ctx.draw(cg, in: CGRect(
            x: -(CGFloat(cg.width) - 1), y: 0,
            width: CGFloat(cg.width), height: CGFloat(cg.height)))

        XCTAssertEqual(pixel[3], 255, "右下角是透明的 —— 底色沒填白")
        XCTAssertGreaterThan(pixel[0], 200, "右下角不是白的")
    }
}
