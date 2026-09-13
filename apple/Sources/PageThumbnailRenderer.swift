//
//  PageThumbnailRenderer.swift
//  Kairumo
//
//  頁面結構側邊欄的縮圖合成器
//

import UIKit
import PencilKit

/// 把一頁的**所有圖層**合成為單張縮圖。
///
/// 側邊欄原本只畫 `PKDrawing`，所以手繪線條看得到、但插入的文字方塊、圖片、
/// 3D 模型與討論圖釘全都不見 —— 那些是畫布上的獨立疊層，不在 `PKDrawing` 裡。
/// 這裡按照畫布上的實際疊放順序重新畫一次。
///
/// 座標系與 `CanvasRepresentable` 一致：寬 `pageWidth`、高為該頁的實際高度。
public enum PageThumbnailRenderer {

    /// 畫布寬度的下限，與 `CanvasRepresentable.contentSize` 的 `max(bounds.width, 800)` 一致。
    public static let minPageWidth: CGFloat = 800

    /// 縮圖最多畫到「寬度的幾倍高」。頁面預設 1800pt 高，若整頁塞進側邊欄，
    /// 卡片不是變成細長一條、就是要縮到物件看不清 —— 超過的部分裁掉，
    /// 底部畫漸層提示還有內容。
    public static let maxHeightRatio: CGFloat = 1.25

    /// 縮圖快取。側邊欄每次重繪都重新合成整頁會很慢，而內容沒變時結果是一樣的。
    private static let cache = NSCache<NSString, UIImage>()

    /// 快取鍵必須涵蓋所有會改變畫面的東西：
    /// `lastModifiedDate` 反映附件變動，`strokes.count` 反映手繪變動
    /// （手繪是存到獨立的 .drawing 檔，不會更新 lastModifiedDate）。
    private static func cacheKey(
        notebook: NotebookDocument,
        pageIndex: Int,
        drawing: PKDrawing,
        canvasWidth: CGFloat
    ) -> NSString {
        "\(notebook.id)|\(pageIndex)|\(notebook.lastModifiedDate.timeIntervalSince1970)|\(drawing.strokes.count)|\(Int(canvasWidth))" as NSString
    }

    /// 清空快取（例如切換筆記本時）。
    public static func invalidateAll() {
        cache.removeAllObjects()
    }

    /// 合成單頁縮圖。`scale` 越小越省記憶體，縮圖只需要看得出輪廓。
    /// - Parameter canvasWidth: 畫布目前的實際內容寬度。
    ///   物件的 x/y 存的是畫布座標，而畫布寬度是 `max(視圖寬度, 800)` ——
    ///   縮圖若一律當成 800 寬，在 Mac 這種寬視窗上物件位置會整個偏掉。
    @MainActor
    public static func render(
        notebook: NotebookDocument,
        pageIndex: Int,
        drawing: PKDrawing,
        store: NotebookStore,
        canvasWidth: CGFloat,
        scale: CGFloat = 0.4
    ) -> UIImage {
        compose(notebook: notebook, pageIndex: pageIndex, drawing: drawing, store: store,
                canvasWidth: canvasWidth, scale: scale, cropToPreviewRatio: true, useCache: true)
    }

    /// 整頁算繪（不裁切、不取快取），給匯出 PDF / 圖片與列印用。
    ///
    /// 匯出原本只畫 `PKDrawing`，而且寫死成 612×792 的信紙尺寸 —— 但畫布的座標
    /// 是「視圖寬度 × 頁面高度」（常常是 1500×1800 以上）。結果是只截到左上角
    /// 那一小塊，使用者寫在中間的內容完全不在裡面，匯出檔看起來就是一片空白，
    /// 而且文字方塊、圖片、3D 與圖釘也全都沒畫進去。
    @MainActor
    public static func renderFullPage(
        notebook: NotebookDocument,
        pageIndex: Int,
        drawing: PKDrawing,
        store: NotebookStore,
        canvasWidth: CGFloat,
        scale: CGFloat = 2.0
    ) -> UIImage {
        compose(notebook: notebook, pageIndex: pageIndex, drawing: drawing, store: store,
                canvasWidth: canvasWidth, scale: scale, cropToPreviewRatio: false, useCache: false)
    }

    @MainActor
    private static func compose(
        notebook: NotebookDocument,
        pageIndex: Int,
        drawing: PKDrawing,
        store: NotebookStore,
        canvasWidth: CGFloat,
        scale: CGFloat,
        cropToPreviewRatio: Bool,
        useCache: Bool
    ) -> UIImage {
        let width = max(canvasWidth, minPageWidth)
        let key = cacheKey(notebook: notebook, pageIndex: pageIndex, drawing: drawing, canvasWidth: width)
        if useCache, let cached = cache.object(forKey: key) { return cached }

        let pageHeight = notebook.height(forPage: pageIndex)
        let visibleHeight = cropToPreviewRatio ? min(pageHeight, width * maxHeightRatio) : pageHeight
        let pageRect = CGRect(x: 0, y: 0, width: width, height: visibleHeight)
        // 手繪要用整頁的座標系取圖，否則落在裁切線以下的筆畫會被擠上來。
        let fullPageRect = CGRect(x: 0, y: 0, width: width, height: pageHeight)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = true

        let image = UIGraphicsImageRenderer(size: pageRect.size, format: format).image { ctx in
            UIColor.systemBackground.setFill()
            ctx.fill(pageRect)

            // 疊放順序刻意對齊畫布：手繪在最底，圖釘在最上。
            drawing.image(from: fullPageRect, scale: scale)
                .draw(in: fullPageRect)

            for item in notebook.attachments ?? [] where item.pageIndex == pageIndex {
                drawImage(item, store: store, ctx: ctx)
            }
            for item in notebook.textAttachments ?? [] where item.pageIndex == pageIndex {
                drawText(item)
            }
            for item in notebook.linkAttachments ?? [] where item.pageIndex == pageIndex {
                drawLink(item)
            }
            for item in notebook.model3DAttachments ?? [] where item.pageIndex == pageIndex {
                drawModel3D(item)
            }
            for pin in notebook.commentPins ?? [] where pin.pageIndex == pageIndex {
                drawPin(pin)
            }

            // 有被裁掉的內容時，底部畫一道漸層，讓使用者知道這不是整頁。
            if cropToPreviewRatio, pageHeight > visibleHeight {
                let fadeHeight: CGFloat = min(60, visibleHeight * 0.12)
                let fadeRect = CGRect(
                    x: 0,
                    y: visibleHeight - fadeHeight,
                    width: width,
                    height: fadeHeight
                )
                let bg = UIColor.systemBackground
                if let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [bg.withAlphaComponent(0).cgColor, bg.cgColor] as CFArray,
                    locations: [0, 1]
                ) {
                    ctx.cgContext.saveGState()
                    ctx.cgContext.clip(to: fadeRect)
                    ctx.cgContext.drawLinearGradient(
                        gradient,
                        start: CGPoint(x: 0, y: fadeRect.minY),
                        end: CGPoint(x: 0, y: fadeRect.maxY),
                        options: []
                    )
                    ctx.cgContext.restoreGState()
                }
            }
        }

        if useCache { cache.setObject(image, forKey: key) }
        return image
    }

    // MARK: - 各圖層

    @MainActor
    private static func drawImage(
        _ item: NoteImageAttachment,
        store: NotebookStore,
        ctx: UIGraphicsImageRendererContext
    ) {
        let rect = CGRect(x: item.x, y: item.y, width: item.width, height: item.height)
        guard let image = store.loadAttachmentImage(fileName: item.fileName) else {
            // 圖檔還沒載入完也要佔位，否則縮圖會與畫布對不起來。
            UIColor.secondarySystemFill.setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: item.cornerRadius).fill()
            return
        }

        let cg = ctx.cgContext
        cg.saveGState()
        if item.rotationDegrees != 0 {
            // 旋轉必須繞著物件中心，繞原點會讓圖飛出畫面。
            let center = CGPoint(x: rect.midX, y: rect.midY)
            cg.translateBy(x: center.x, y: center.y)
            cg.rotate(by: CGFloat(item.rotationDegrees) * .pi / 180)
            cg.translateBy(x: -center.x, y: -center.y)
        }
        UIBezierPath(roundedRect: rect, cornerRadius: item.cornerRadius).addClip()
        image.draw(in: rect)
        cg.restoreGState()

        if item.hasBorder {
            UIColor.tintColor.withAlphaComponent(0.8).setStroke()
            let border = UIBezierPath(roundedRect: rect, cornerRadius: item.cornerRadius)
            border.lineWidth = 2.5
            border.stroke()
        }
    }

    private static func drawText(_ item: NoteTextAttachment) {
        let rect = CGRect(x: item.x, y: item.y, width: item.width, height: item.height)

        if item.backgroundColorHex != "clear", let bg = UIColor(hexString: item.backgroundColorHex) {
            bg.setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: item.cornerRadius).fill()
        }
        if item.hasBorder {
            // 邊框顏色與粗細要跟畫布上看到的一致（使用者可自訂）
            let borderColor = UIColor(hexString: item.borderColorHex ?? "") ?? UIColor.tintColor.withAlphaComponent(0.5)
            borderColor.setStroke()
            let border = UIBezierPath(roundedRect: rect, cornerRadius: item.cornerRadius)
            border.lineWidth = item.borderWidth ?? 1.5
            border.stroke()
        }

        guard !item.text.isEmpty else { return }

        var traits: UIFontDescriptor.SymbolicTraits = []
        if item.isBold { traits.insert(.traitBold) }
        if item.isItalic { traits.insert(.traitItalic) }
        let base = UIFont.systemFont(ofSize: item.fontSize)
        let font = base.fontDescriptor.withSymbolicTraits(traits).map { UIFont(descriptor: $0, size: item.fontSize) } ?? base

        let paragraph = NSMutableParagraphStyle()
        switch item.alignmentRaw {
        case "center": paragraph.alignment = .center
        case "right": paragraph.alignment = .right
        case "justified": paragraph.alignment = .justified
        default: paragraph.alignment = .left
        }
        paragraph.lineBreakMode = .byTruncatingTail

        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(hexString: item.textColorHex) ?? .label,
            .paragraphStyle: paragraph
        ]
        if item.isUnderline { attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if item.isStrikethrough { attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }

        NSAttributedString(string: item.text, attributes: attrs)
            .draw(in: rect.insetBy(dx: 8, dy: 6))
    }

    private static func drawLink(_ item: NoteLinkAttachment) {
        let rect = CGRect(x: item.x, y: item.y, width: item.width, height: max(60, item.height))
        UIColor.tertiarySystemBackground.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()
        UIColor.separator.setStroke()
        let border = UIBezierPath(roundedRect: rect, cornerRadius: 10)
        border.lineWidth = 1
        border.stroke()

        let title = item.title.isEmpty ? item.urlString : item.title
        NSAttributedString(
            string: title,
            attributes: [
                .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
        ).draw(in: rect.insetBy(dx: 10, dy: 8))

        NSAttributedString(
            string: item.siteName,
            attributes: [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.secondaryLabel
            ]
        ).draw(at: CGPoint(x: rect.minX + 10, y: rect.minY + 32))
    }

    private static func drawModel3D(_ item: Note3DAttachment) {
        let rect = CGRect(x: item.x, y: item.y, width: item.width, height: item.height)
        // SceneKit 離屏算繪對縮圖來說太昂貴，畫一個帶標題的佔位卡片即可 ——
        // 目的是讓使用者知道「這一頁這個位置有個 3D 模型」。
        UIColor.secondarySystemBackground.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 12).fill()
        UIColor.tintColor.withAlphaComponent(0.45).setStroke()
        let border = UIBezierPath(roundedRect: rect, cornerRadius: 12)
        border.lineWidth = 1.5
        border.stroke()

        if let cube = UIImage(systemName: "cube.transparent") {
            let side = min(rect.width, rect.height) * 0.4
            let box = CGRect(
                x: rect.midX - side / 2,
                y: rect.midY - side / 2 - 8,
                width: side,
                height: side
            )
            cube.withTintColor(.tintColor, renderingMode: .alwaysOriginal).draw(in: box)
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        NSAttributedString(
            string: item.title,
            attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: UIColor.secondaryLabel,
                .paragraphStyle: paragraph
            ]
        ).draw(in: CGRect(x: rect.minX + 6, y: rect.maxY - 26, width: rect.width - 12, height: 20))
    }

    private static func drawPin(_ pin: NoteCommentPin) {
        let radius: CGFloat = 14
        let rect = CGRect(x: pin.x - radius, y: pin.y - radius, width: radius * 2, height: radius * 2)
        let color = UIColor(hexString: pin.authorColor) ?? .systemOrange
        (pin.isResolved ? color.withAlphaComponent(0.35) : color).setFill()
        UIBezierPath(ovalIn: rect).fill()
        UIColor.white.setStroke()
        let ring = UIBezierPath(ovalIn: rect)
        ring.lineWidth = 2
        ring.stroke()
    }
}

extension UIColor {
    /// 解析 `#RRGGBB` / `RRGGBB` / `#RRGGBBAA`。無法解析時回傳 nil，
    /// 讓呼叫端自己決定 fallback，而不是悄悄畫成黑色。
    convenience init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6 || hex.count == 8,
              let value = UInt64(hex, radix: 16) else { return nil }

        let r, g, b, a: CGFloat
        if hex.count == 6 {
            r = CGFloat((value & 0xFF0000) >> 16) / 255
            g = CGFloat((value & 0x00FF00) >> 8) / 255
            b = CGFloat(value & 0x0000FF) / 255
            a = 1
        } else {
            r = CGFloat((value & 0xFF00_0000) >> 24) / 255
            g = CGFloat((value & 0x00FF_0000) >> 16) / 255
            b = CGFloat((value & 0x0000_FF00) >> 8) / 255
            a = CGFloat(value & 0x0000_00FF) / 255
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
