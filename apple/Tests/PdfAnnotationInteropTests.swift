//
//  PdfAnnotationInteropTests.swift
//  KairumoTests
//
//  匯出的 PDF 要能在別的 App 裡**繼續編輯我們的筆畫**（工作項 S-44）。
//
//  「開得起來」與「可以繼續編輯」是兩件事。任何 PDF 都能在 Goodnotes 裡
//  被加註；但要讓我們寫的那些筆畫成為**它認得的物件**，PDF 裡必須有標準的
//  `/Subtype /Ink` 標註。原本的匯出是把整頁算繪成點陣圖 —— 看得到，改不了。
//

import XCTest
import PencilKit
@testable import Kairumo

final class PdfAnnotationInteropTests: XCTestCase {

    private func stroke(at y: CGFloat) -> PKStroke {
        let points = (0..<10).map { i in
            PKStrokePoint(
                location: CGPoint(x: 100 + CGFloat(i) * 12, y: y + CGFloat(i) * 3),
                timeOffset: Double(i) * 0.008,
                size: CGSize(width: 4, height: 4),
                opacity: 1, force: 1, azimuth: 1, altitude: 1.2)
        }
        return PKStroke(
            ink: PKInk(.pen, color: .black),
            path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0)))
    }

    private func sampleNotebook() -> (NotebookDocument, [PKDrawing]) {
        let doc = NotebookDocument(
            id: "ink-pdf", title: "標註互通", pageCount: 2,
            textAttachments: [NoteTextAttachment(pageIndex: 0, text: "會議重點", x: 60, y: 400)]
        )
        return (doc, [
            PKDrawing(strokes: [stroke(at: 200), stroke(at: 300)]),
            PKDrawing(strokes: [stroke(at: 250)])
        ])
    }

    private func exportedPdf() throws -> Data {
        let (doc, drawings) = sampleNotebook()
        return try NotebookPackageBridge.exportPdf(
            document: doc, drawings: drawings, deviceId: 0xA44)
    }

    /// PDF 內部是二進位混文字；標註字典是未壓縮的純文字，直接掃位元組就找得到。
    private func contains(_ data: Data, _ marker: String) -> Bool {
        data.range(of: Data(marker.utf8)) != nil
    }

    // MARK: - 標註本身

    func testTheExportedPdfIsARealPdf() throws {
        let data = try exportedPdf()
        XCTAssertGreaterThan(data.count, 1_000)
        XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "%PDF")
    }

    func testStrokesBecomeEditableInkAnnotations() throws {
        // 這一條就是「能繼續編輯我的筆畫」的實際判準。
        let data = try exportedPdf()
        XCTAssertTrue(contains(data, "/Subtype /Ink"), "PDF 裡必須有標準的 Ink 標註")
        XCTAssertTrue(contains(data, "/InkList"), "Ink 標註必須帶著實際的筆跡座標")
    }

    func testEveryStrokeGetsItsOwnAnnotation() throws {
        // 三筆畫合併成一個標註的話，在別的 App 裡就只能整組刪除，
        // 不能單獨改其中一筆。
        let data = try exportedPdf()
        let count = String(decoding: data, as: UTF8.self)
            .components(separatedBy: "/Subtype /Ink").count - 1
        XCTAssertEqual(count, 3, "三筆畫要有三個標註，實得 \(count)")
    }

    func testAnnotationsAreAttachedToPages() throws {
        // 標註物件存在但沒有掛到頁面上的話，檢視器根本不會顯示它。
        let data = try exportedPdf()
        XCTAssertTrue(contains(data, "/Annots"))
    }

    func testAnnotationsCarryStrokeWidth() throws {
        // 沒有 /BS 的話，別的 App 會用它自己的預設粗細重畫，
        // 使用者看到的是「我的字變粗了」。
        XCTAssertTrue(contains(try exportedPdf(), "/BS"))
    }

    // MARK: - 內容沒有掉

    func testTextBoxesSurviveTheExport() throws {
        // 走核心匯出器換來可編輯的筆畫，但不能因此掉了其他內容。
        let data = try exportedPdf()
        XCTAssertGreaterThan(data.count, 2_000, "只有筆畫沒有文字的 PDF 會明顯偏小")
    }

    func testBothPagesAreExported() throws {
        let data = try exportedPdf()
        let pages = String(decoding: data, as: UTF8.self)
            .components(separatedBy: "/Type /Page\n").count
            + String(decoding: data, as: UTF8.self)
                .components(separatedBy: "/Type /Page ").count - 2
        XCTAssertGreaterThanOrEqual(pages, 2, "兩頁都要在")
    }

    /// 產一份真的 PDF 給人在 Goodnotes / Notability / PDF Expert 裡實測。
    ///
    /// 自動化測試證明得了「PDF 裡有 Ink 標註」，證明不了「Goodnotes 認得它」——
    /// 那要真的把檔案丟進去。檔案刻意留下不刪，並印出路徑。
    func testProduceSamplePdfForThirdPartyApps() throws {
        let data = try exportedPdf()
        let path = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kairumo-ink-annotations.pdf")
        try data.write(to: path)
        print("KAIRUMO_INK_PDF=\(path.path)")
        XCTAssertGreaterThan(data.count, 1_000)
    }

    // MARK: - 備援

    @MainActor
    func testTheRasterPathStillWorksAsAFallback() throws {
        // 核心拒絕資料時要退回點陣匯出 —— 拿得到一份看得見內容的 PDF，
        // 比拿到一個錯誤訊息好。這裡確認備援路徑本身沒有壞掉。
        let (doc, drawings) = sampleNotebook()
        let image = PageThumbnailRenderer.renderFullPage(
            notebook: doc, pageIndex: 0, drawing: drawings[0],
            store: NotebookStore.shared, canvasWidth: PageGeometry.width, scale: 1)
        XCTAssertGreaterThan(image.size.width, 0)
    }
}
