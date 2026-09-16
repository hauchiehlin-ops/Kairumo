import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

/// 把一頁算繪成 PNG（工作項 S-60）。
///
/// # 為什麼不直接用核心的 `exportPagePng`
///
/// 核心那條路把文字畫成**灰色的行條**（greeking）而不是真的字。原因寫在
/// `padnote-export::image` 的檔頭：純 Rust 的光柵化器手上沒有字型，要畫中文
/// 得內嵌一份好幾 MB 的字型，而那是一個授權決策。
///
/// Apple 的**縮圖**本來就不走那裡（`PageThumbnailRenderer` 用 UIKit 畫，字是
/// 真的），但**匯出 PNG** 一直走核心 —— 所以一本打字的筆記，畫面上看得到字，
/// 匯出的圖卻是一排灰條。同一份內容在兩個出口長得不一樣，比兩邊都醜更糟。
///
/// # 這條路：PDF 交給系統畫
///
/// 核心的 `exportPagePdf` 本來就輸出真正的文字物件，中文走 Type 0 複合字型。
/// PDFKit 會替非內嵌字型代換系統字型，所以**一個位元組都不用內嵌**就有真字形。
/// 已在 macOS 上實測：核心產的 PDF 經 PDFKit 算繪，中文標題是完整的字。
///
/// Android 端用系統的 `PdfRenderer` 做同一件事（`PageImageRenderer.kt`），
/// 兩邊因此畫的是同一份 PDF。
///
/// # 失敗就退回核心
///
/// 任何一步失敗都退回 `exportPagePng` —— 灰條的版面仍然是對的（位置、行寬、
/// 行數、行高都照實算），比丟一個例外給使用者好。
public enum PageImageRenderer {

    /// 算繪 `pageId` 這一頁並回傳 PNG 位元組。
    /// - Parameter scale: 相對於頁面點數的倍率（2.0 約等於 Retina 級）。
    public static func renderPng(
        session: PadnoteSession,
        pageId: String,
        scale: Float = 2.0
    ) throws -> Data {
        if let data = try? session.exportPagePdf(pageId: pageId),
           let png = pngFromPdf(data, scale: CGFloat(scale)) {
            return png
        }
        return try session.exportPagePng(pageId: pageId, scale: scale)
    }

    static func pngFromPdf(_ pdf: Data, scale: CGFloat) -> Data? {
        guard let doc = PDFDocument(data: pdf), let page = doc.page(at: 0) else { return nil }
        let box = page.bounds(for: .mediaBox)
        let width = Int((box.width * scale).rounded())
        let height = Int((box.height * scale).rounded())
        guard width > 0, height > 0 else { return nil }

        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // **底色一定要填白。** PDF 的頁面背景不是繪製指令的一部分，
        // 不填的話存出來是透明的，在淺色介面上看起來像一張空白頁。
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.scaleBy(x: scale, y: scale)
        // mediaBox 的原點不保證在 (0, 0)。
        ctx.translateBy(x: -box.origin.x, y: -box.origin.y)
        page.draw(with: .mediaBox, to: ctx)

        guard let image = ctx.makeImage() else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            out, UTType.png.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
