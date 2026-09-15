//
//  PdfKitDocumentTests.swift
//  KairumoTests
//
//  Apple 的 PDF 讀取改走 PDFKit（決策 D-11b）之後，這一批釘的是
//  **與核心 `padnote_pdf` 一致的那幾個約定**。
//
//  兩個平台的後端不同（Apple 用 PDFKit、Android 用 libpdfium），
//  介面與座標約定卻必須完全一樣 —— 不一樣的話，同一份標註會在兩個平台上
//  落在不同的位置，而那種 bug 只有把兩台裝置擺在一起才看得出來。
//

import XCTest
import PDFKit
@testable import Kairumo

final class PdfKitDocumentTests: XCTestCase {

    /// 產一份真的 PDF 來測，不要用假資料。
    ///
    /// 用 `UIGraphicsPDFRenderer`（系統的）而不是自己拼位元組：這一批要驗的是
    /// 「讀得對不對」，餵一份自己拼的檔案只會測到自己的拼法。
    private func samplePDF(pages: Int = 2, size: CGSize = CGSize(width: 595, height: 842)) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: size))
        return renderer.pdfData { context in
            for index in 0..<pages {
                context.beginPage()
                let text = "Kairumo page \(index + 1)"
                (text as NSString).draw(
                    at: CGPoint(x: 72, y: 72),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 24)]
                )
            }
        }
    }

    func testReadsPageCountAndSize() throws {
        let doc = try PdfKitDocument(data: samplePDF(pages: 3))
        XCTAssertEqual(doc.pageCount, 3)

        let page = try doc.page(at: 0)
        XCTAssertEqual(page.size.width, 595, accuracy: 1)
        XCTAssertEqual(page.size.height, 842, accuracy: 1)
        XCTAssertEqual(page.rotation, 0)
    }

    func testRejectsSomethingThatIsNotAPdf() throws {
        // 「這不是 PDF」要**當場**講清楚。含混過去的話，後面每一步都會用一份
        // 空文件繼續跑，而使用者看到的是「開起來是空白的」。
        XCTAssertThrowsError(try PdfKitDocument(data: Data("這不是 PDF".utf8))) { error in
            XCTAssertEqual(error as? PdfKitError, .notAPdf)
        }
    }

    func testPageIndexIsBoundsChecked() throws {
        let doc = try PdfKitDocument(data: samplePDF(pages: 2))
        // 越界不能靜靜回 nil —— nil 在上層看起來像「這一頁是空的」。
        XCTAssertThrowsError(try doc.page(at: 5)) { error in
            XCTAssertEqual(error as? PdfKitError, .pageOutOfRange(requested: 5, total: 2))
        }
        XCTAssertThrowsError(try doc.page(at: -1))
    }

    func testCoordinateConversionFlipsYAndRoundTrips() throws {
        // **標註位置偏移的 bug 幾乎都出在這裡。**
        // 這幾條與核心 `padnote_pdf::PdfPage` 的同名測試一一對應。
        let doc = try PdfKitDocument(data: samplePDF(pages: 1))
        let page = try doc.page(at: 0)

        // PDF 的底部（y = 0）就是頁面的頂部的對面。
        XCTAssertEqual(page.pdfToPage(CGPoint(x: 100, y: 0)).y, page.size.height, accuracy: 0.01)
        XCTAssertEqual(page.pdfToPage(CGPoint(x: 100, y: page.size.height)).y, 0, accuracy: 0.01)

        let there = page.pdfToPage(CGPoint(x: 123, y: 456))
        let back = page.pageToPdf(there)
        XCTAssertEqual(back.x, 123, accuracy: 0.01)
        XCTAssertEqual(back.y, 456, accuracy: 0.01)
    }

    func testRotationSwapsDisplayDimensions() {
        // 忘記這件事會讓橫向掃描件顯示成被壓扁的直式。
        let portrait = PdfPageInfo(index: 0, size: CGSize(width: 595, height: 842), rotation: 0)
        XCTAssertEqual(portrait.displaySize, CGSize(width: 595, height: 842))

        let rotated = PdfPageInfo(index: 0, size: CGSize(width: 595, height: 842), rotation: 90)
        XCTAssertEqual(rotated.displaySize, CGSize(width: 842, height: 595))

        let upsideDown = PdfPageInfo(index: 0, size: CGSize(width: 595, height: 842), rotation: 180)
        XCTAssertEqual(upsideDown.displaySize, CGSize(width: 595, height: 842))
    }

    func testRendersAPagePng() throws {
        let doc = try PdfKitDocument(data: samplePDF(pages: 1))
        let png = try doc.renderPNG(at: 0, scale: 0.5)

        // 真的是 PNG（前八個位元組是 PNG 的簽章），而且尺寸跟著 scale 走。
        XCTAssertEqual(Array(png.prefix(4)), [0x89, 0x50, 0x4E, 0x47])
        let image = UIImage(data: png)
        XCTAssertNotNil(image)
        XCTAssertEqual(image?.size.width ?? 0, 595 * 0.5, accuracy: 2)
    }

    func testReadsTheTextLayer() throws {
        // 有文字層才做得到選取與 highlight。用畫線模擬螢光筆的話，
        // 選不到字也搜不到 —— 那不算 PDF 標註。
        let doc = try PdfKitDocument(data: samplePDF(pages: 1))
        let spans = try doc.textSpans(at: 0)
        XCTAssertFalse(spans.isEmpty, "這份 PDF 有文字層，不該讀成空的")
        XCTAssertTrue(
            spans.contains { $0.text.contains("Kairumo") },
            "讀到的內容對不上：\(spans.map(\.text))"
        )
    }
}
