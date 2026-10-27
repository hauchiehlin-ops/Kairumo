import XCTest
import PDFKit
import UIKit

@testable import Kairumo

/// 整份匯入 PDF、以及「筆跡畫在 PDF 上面」。
///
/// # 守的是哪三件事
///
/// 1. **算繪大小有上限。** 掃描版 PDF 的 mediaBox 常是像素（2480×3508），原本「點數 × 2」
///    一頁就是 4960×7016，主執行緒上編碼兩次 —— 那就是「匯入之後 App 停住」。
/// 2. **每一頁 PDF 填滿一頁內頁**，而且一次插入多頁時其他附件、逐頁設定一起讓位。
/// 3. **圖片（含 PDF 頁面）預設在筆跡下方，文字在上方**（核心 `ffi_layering`）。
///    原本所有物件預設都在筆跡上方，在 PDF 上寫的字全被蓋住。
@MainActor
final class PdfImportAndLayeringTests: XCTestCase {

    private func makePdf(pages: Int, size: CGSize) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "import-\(UUID().uuidString).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: size))
        try renderer.writePDF(to: url) { ctx in
            for _ in 0..<pages {
                ctx.beginPage()
                UIColor.black.setFill()
                ctx.cgContext.fill(CGRect(x: 10, y: 10, width: size.width / 4, height: size.height / 4))
            }
        }
        return url
    }

    private func tempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: "pdf-import-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - 算繪

    func testAScannerSizedPageIsRenderedAtAPageSizedResolutionNotThirtyFiveMegapixels() throws {
        let url = try makePdf(pages: 1, size: CGSize(width: 2480, height: 3508))
        let dir = try tempDirectory()
        let doc = try XCTUnwrap(PDFDocument(url: url))

        let page = try XCTUnwrap(PdfPageRenderer.importPage(
            document: doc, index: 0, pageSize: CGSize(width: 800, height: 1131), into: dir))

        let image = try XCTUnwrap(UIImage(contentsOfFile: dir.appending(path: page.fileName).path))
        let cg = try XCTUnwrap(image.cgImage)
        XCTAssertLessThanOrEqual(max(cg.width, cg.height), 3072)
        XCTAssertLessThanOrEqual(cg.width * cg.height, 6_000_000 + 4096)
        XCTAssertLessThan(cg.width, 4960, "不能再照 mediaBox × 2 算繪")
        // 填滿內頁：高度貼齊、水平置中、貼齊上緣。
        XCTAssertEqual(page.frame.height, 1131, accuracy: 0.5)
        XCTAssertEqual(page.frame.minY, 0)
        XCTAssertEqual(page.frame.midX, 400, accuracy: 0.5)
    }

    func testThePreviewIsAlsoCapped() throws {
        let url = try makePdf(pages: 1, size: CGSize(width: 2480, height: 3508))
        let image = try XCTUnwrap(PdfPageRenderer.render(url: url, pageIndex: 0))
        let cg = try XCTUnwrap(image.cgImage)
        XCTAssertLessThanOrEqual(max(cg.width, cg.height), 3072)
    }

    func testRenderingRunsOffTheMainThread() async throws {
        let url = try makePdf(pages: 3, size: CGSize(width: 595, height: 842))
        let dir = try tempDirectory()
        let pages = await Task.detached { () -> [PdfImportedPage] in
            XCTAssertFalse(Thread.isMainThread)
            guard let doc = PDFDocument(url: url) else { return [] }
            return (0..<doc.pageCount).compactMap {
                PdfPageRenderer.importPage(document: doc, index: $0, pageSize: CGSize(width: 595, height: 842), into: dir)
            }
        }.value
        XCTAssertEqual(pages.count, 3)
        XCTAssertEqual(Set(pages.map(\.fileName)).count, 3, "每一頁各自一個檔")
    }

    // MARK: - 插頁

    func testImportingFillsOneNotebookPagePerPdfPageAndShiftsTheRest() throws {
        let store = PageOrderTests.isolatedStore()
        var doc = NotebookDocument(
            title: "PDF", createdAt: Date(), lastModifiedDate: Date(), pageCount: 2,
            hasRecording: false, previewSnippet: nil, template: .blank)
        doc.pagesData = Array(repeating: Data(), count: 2)
        doc.textAttachments = [NoteTextAttachment(pageIndex: 1, text: "after")]
        doc.setObjectOrder(["x"], forPage: 1)
        store.notebooks.insert(doc, at: 0)

        let frame = CGRect(x: 0, y: 0, width: 800, height: 1131)
        let pages = (0..<3).map { PdfImportedPage(fileName: "att_\($0).png", frame: frame) }
        let first = store.insertPages(notebookId: doc.id, afterIndex: 0, count: 3)
        store.placePdfPages(notebookId: doc.id, pages: pages, firstPage: first)

        let updated = try XCTUnwrap(store.notebooks.first { $0.id == doc.id })
        XCTAssertEqual(first, 1)
        XCTAssertEqual(updated.pageCount, 5)
        XCTAssertEqual(updated.pagesData.count, 5)
        XCTAssertEqual(updated.pageHeights?.count, 5)
        XCTAssertEqual(updated.textAttachments?.first?.pageIndex, 4, "原本第 1 頁的東西讓出三頁")
        XCTAssertEqual(updated.objectOrder(forPage: 4), ["x"], "逐頁設定跟著讓位")
        let images = try XCTUnwrap(updated.attachments)
        XCTAssertEqual(images.map(\.pageIndex), [1, 2, 3])
        for image in images {
            XCTAssertEqual(CGRect(x: image.x, y: image.y, width: image.width, height: image.height), frame)
            XCTAssertTrue(updated.lockedObjectIds(forPage: image.pageIndex).contains(image.id), "PDF 底稿鎖定在畫布上")
            XCTAssertEqual(updated.objectOrder(forPage: image.pageIndex)?.first, image.id, "底稿在最底下")
            XCTAssertTrue(updated.underInkObjectIds(forPage: image.pageIndex).contains(image.id), "筆跡畫在 PDF 上面")
        }
    }

    // MARK: - 圖層

    func testInsertedMaterialDefaultsBelowInkAndTextAbove() {
        var doc = NotebookDocument(
            title: "L", createdAt: Date(), lastModifiedDate: Date(), pageCount: 1,
            hasRecording: false, previewSnippet: nil, template: .blank)
        let image = NoteImageAttachment(fileName: "a.png", pageIndex: 0)
        let text = NoteTextAttachment(pageIndex: 0, text: "note")
        let table = NoteTableAttachment(pageIndex: 0, x: 0, y: 0, width: 100, rows: 1, cols: 1, cells: ["c"])
        let shape = NoteShapeAttachment(pageIndex: 0, x: 0, y: 0, width: 10, height: 10)
        doc.attachments = [image]
        doc.textAttachments = [text]
        doc.tableAttachments = [table]
        doc.shapeAttachments = [shape]

        let below = doc.underInkObjectIds(forPage: 0)
        XCTAssertTrue(below.contains(image.id))
        XCTAssertTrue(below.contains(table.id))
        XCTAssertTrue(below.contains(shape.id))
        XCTAssertFalse(below.contains(text.id), "打字的文字是標註，預設在最上層")

        // 使用者把圖片搬到筆跡上方、文字搬到下方 —— 兩份明確清單各記一筆。
        doc.moveObjects([image.id], to: .aboveInk, forPage: 0)
        doc.moveObjects([text.id], to: .belowInk, forPage: 0)
        let moved = doc.underInkObjectIds(forPage: 0)
        XCTAssertFalse(moved.contains(image.id))
        XCTAssertTrue(moved.contains(text.id))
        XCTAssertEqual(doc.explicitOverInkObjectIds(forPage: 0), [image.id])

        // 搬回去：清單回到只記舊版也認得的那一份。
        doc.moveObjects([image.id], to: .belowInk, forPage: 0)
        XCTAssertTrue(doc.underInkObjectIds(forPage: 0).contains(image.id))
        XCTAssertNil(doc.overInkObjectIdsByPage)
    }

    func testOldNotebooksWithAnExplicitUnderListStillWork() {
        var doc = NotebookDocument(
            title: "Old", createdAt: Date(), lastModifiedDate: Date(), pageCount: 1,
            hasRecording: false, previewSnippet: nil, template: .blank)
        let text = NoteTextAttachment(pageIndex: 0, text: "bg")
        doc.textAttachments = [text]
        doc.setUnderInkObjectIds([text.id], forPage: 0)
        XCTAssertTrue(doc.underInkObjectIds(forPage: 0).contains(text.id))
    }

    func testDefaultStackOrderPutsAnnotationsOnTop() {
        XCTAssertLessThan(StackableObject.Kind.image.defaultLayer, StackableObject.Kind.text.defaultLayer)
        XCTAssertLessThan(StackableObject.Kind.audio.defaultLayer, StackableObject.Kind.text.defaultLayer)
        XCTAssertLessThan(StackableObject.Kind.text.defaultLayer, StackableObject.Kind.pin.defaultLayer)
    }
}
