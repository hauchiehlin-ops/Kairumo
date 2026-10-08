//
//  ExportParityTests.swift
//  KairumoTests
//
//  「所見即所得」：匯出、縮圖、列印走的繪圖程式碼要與畫布的疊放、濾鏡、陰影一致。
//  這批測試取**像素**，因為這類差異（誰在誰上面、有沒有套濾鏡）看程式碼看不出來。
//

import PencilKit
import XCTest
@testable import Kairumo

@MainActor
final class ExportParityTests: XCTestCase {

    private var created: [URL] = []

    override func tearDown() {
        for url in created { try? FileManager.default.removeItem(at: url) }
        created = []
        super.tearDown()
    }

    /// 在附件目錄放一張純色圖，回傳檔名。
    private func solidImage(_ color: UIColor, size: CGFloat = 100) -> String {
        let image = UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        }
        let name = "parity-\(UUID().uuidString).png"
        let url = NotebookStore.shared.attachmentsDirectory.appending(path: name)
        try? FileManager.default.createDirectory(
            at: NotebookStore.shared.attachmentsDirectory, withIntermediateDirectories: true)
        try? image.pngData()?.write(to: url)
        created.append(url)
        return name
    }

    private func image(
        _ file: String, x: CGFloat = 100, y: CGFloat = 100, size: CGFloat = 200,
        shadow: Bool = false, filter: ImageFilterStyle = .original, material: MaterialType? = nil
    ) -> NoteImageAttachment {
        NoteImageAttachment(
            fileName: file, pageIndex: 0, x: x, y: y, width: size, height: size, cornerRadius: 0,
            hasShadow: shadow, hasBorder: false, filterStyle: filter, materialType: material)
    }

    private func render(
        _ notebook: NotebookDocument, drawing: PKDrawing = PKDrawing(), inkOnTop: Bool = true
    ) -> UIImage {
        PageThumbnailRenderer.renderFullPage(
            notebook: notebook, pageIndex: 0, drawing: drawing, store: NotebookStore.shared,
            canvasWidth: PageGeometry.width, scale: 1.0, inkOnTop: inkOnTop)
    }

    private func pixel(_ image: UIImage, _ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int) {
        guard let cg = image.cgImage else { return (0, 0, 0) }
        var data = [UInt8](repeating: 0, count: 4)
        let space = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: &data, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cg, in: CGRect(x: -x, y: -(cg.height - 1 - y), width: cg.width, height: cg.height))
        return (Int(data[0]), Int(data[1]), Int(data[2]))
    }

    private func notebook(with images: [NoteImageAttachment]) -> NotebookDocument {
        var book = NotebookDocument(title: "P", pageCount: 1)
        book.attachments = images
        return book
    }

    private func thickStroke() -> PKStroke {
        let points = (0 ..< 20).map { i in
            PKStrokePoint(
                location: CGPoint(x: 60 + CGFloat(i) * 12, y: 200), timeOffset: Double(i) * 0.01,
                size: CGSize(width: 24, height: 24), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(
            ink: PKInk(.pen, color: .black),
            path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0)))
    }

    // MARK: 墨跡與物件誰在上面

    func testInkIsAboveTheImageInDrawModeAndBelowItInTypeMode() {
        let book = notebook(with: [image(solidImage(.red))])
        let drawing = PKDrawing(strokes: [thickStroke()])
        // (200, 200) 同時在圖片裡、也在墨跡的線上。
        let drawMode = pixel(render(book, drawing: drawing, inkOnTop: true), 200, 200)
        XCTAssertLessThan(drawMode.r, 80, "手寫模式：墨跡在圖片之上（在圖上圈重點），匯出要看得到黑線")
        let typeMode = pixel(render(book, drawing: drawing, inkOnTop: false), 200, 200)
        XCTAssertGreaterThan(typeMode.r, 200, "打字模式：物件在墨跡之上，圖片蓋住線")
        XCTAssertLessThan(typeMode.g, 60)
    }

    func testObjectOrderDecidesWhichOverlappingObjectIsOnTop() {
        let red = image(solidImage(.red), x: 100, y: 100)
        let blue = image(solidImage(.blue), x: 150, y: 150)
        var book = notebook(with: [red, blue])
        // 沒排過：後加的在上面（照型別預設層級，同層照加入順序）。
        XCTAssertGreaterThan(pixel(render(book), 200, 200).b, 200)
        // 使用者把紅色拉到最上面。
        book.setObjectOrder([blue.id, red.id], forPage: 0)
        let reordered = pixel(render(book), 200, 200)
        XCTAssertGreaterThan(reordered.r, 200, "圖層面板排的順序，匯出要照做")
        XCTAssertLessThan(reordered.b, 60)
    }

    // MARK: 濾鏡、材質、陰影

    func testImageFiltersAreAppliedLikeOnTheCanvas() {
        let file = solidImage(.red)
        let plain = pixel(render(notebook(with: [image(file)])), 200, 200)
        XCTAssertGreaterThan(plain.r, 240)
        XCTAssertLessThan(plain.g, 30)
        let mono = pixel(render(notebook(with: [image(file, filter: .mono)])), 200, 200)
        XCTAssertLessThan(abs(mono.r - mono.g), 12, "黑白濾鏡：匯出不能還是紅色")
        XCTAssertLessThan(abs(mono.g - mono.b), 12)
    }

    func testMaterialsChangeTheImageLikeOnTheCanvas() {
        let file = solidImage(UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        let plain = pixel(render(notebook(with: [image(file)])), 200, 200)
        let gold = pixel(render(notebook(with: [image(file, material: .gold)])), 200, 200)
        XCTAssertGreaterThan(gold.r - gold.b, plain.r - plain.b + 20, "黃金材質要偏黃")
    }

    func testTheShadowIsDrawnOutsideTheImage() {
        let file = solidImage(.red)
        // 圖片下緣之外 3 點：有陰影時比純白暗。
        let withShadow = pixel(render(notebook(with: [image(file, shadow: true)])), 200, 303)
        let without = pixel(render(notebook(with: [image(file, shadow: false)])), 200, 303)
        XCTAssertGreaterThan(without.r, 250)
        XCTAssertLessThan(withShadow.r, without.r - 3, "畫布上有陰影，匯出也要有")
    }

    // MARK: 外觀

    func testExportIsAlwaysOnWhitePaperEvenInDarkMode() {
        var dark: UIImage!
        UITraitCollection(userInterfaceStyle: .dark).performAsCurrent {
            dark = render(notebook(with: []))
        }
        let p = pixel(dark, 10, 10)
        XCTAssertGreaterThan(p.r, 240, "匯出的紙是白的，不能因為 App 在深色模式就變成黑底")
        XCTAssertGreaterThan(p.g, 240)
    }
}
