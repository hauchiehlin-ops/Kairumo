//
//  PageThumbnailRenderer.swift
//  Kairumo
//
//  頁面結構側邊欄的縮圖合成器
//

import UIKit
import PencilKit
import SceneKit
import Metal

/// 把一頁的**所有圖層**合成為單張縮圖。
///
/// 側邊欄原本只畫 `PKDrawing`，所以手繪線條看得到、但插入的文字方塊、圖片、
/// 3D 模型與討論圖釘全都不見 —— 那些是畫布上的獨立疊層，不在 `PKDrawing` 裡。
/// 這裡按照畫布上的實際疊放順序重新畫一次。
///
/// 座標系與 `CanvasRepresentable` 一致：寬 `pageWidth`、高為該頁的實際高度。
public enum PageThumbnailRenderer {

    /// 畫布寬度。
    ///
    /// **跟著目前這一本筆記的頁面規格走**，不是寫死的 800。
    /// 寫死的話，A4 橫式或簡報 16:9 的筆記匯出與縮圖仍然按直式 A4 取樣 ——
    /// 畫布上看到的是橫的，匯出的 PDF 卻是直的，而且右半邊被裁掉。
    public static var minPageWidth: CGFloat { PageGeometry.width }

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
        // 紙張與配色也要進快取鍵：改的是「這一頁用哪張紙」時，筆跡沒動、
        // 物件沒動，只有版面變了 —— 沒有這兩個欄位的話側欄縮圖不會更新。
        "\(notebook.id)|\(pageIndex)|\(notebook.lastModifiedDate.timeIntervalSince1970)|\(drawing.strokes.count)|\(Int(canvasWidth))|\(notebook.paperId(forPage: pageIndex))|\(notebook.guidePaletteId ?? "-")" as NSString
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
                canvasWidth: canvasWidth, scale: scale, cropToPreviewRatio: false,
                useCache: false, quality: .export)
    }

    @MainActor
    /// 算繪品質。
    ///
    /// 側邊欄縮圖與匯出走的是同一份繪圖程式碼（不然兩邊遲早長得不一樣），
    /// 但有些東西在縮圖上不值得付代價、在匯出上又非做不可 ——
    /// 3D 模型就是這種：離屏算繪很貴，縮圖畫個佔位卡就夠了，
    /// 匯出畫佔位卡則是**把使用者的內容換成一個圖示**，那是錯的。
    enum Quality {
        case preview
        case export
    }

    private static func compose(
        notebook: NotebookDocument,
        pageIndex: Int,
        drawing: PKDrawing,
        store: NotebookStore,
        canvasWidth: CGFloat,
        scale: CGFloat,
        cropToPreviewRatio: Bool,
        useCache: Bool,
        quality: Quality = .preview
    ) -> UIImage {
        // 匯出與縮圖一律以**頁面**為準，不是以當下的畫布寬度為準。
        // 以畫布寬度取圖的話，同一則筆記在 Mac 與 iPhone 上匯出的結果不一樣 ——
        // 那正是「匯出與畫布對不起來」的根本原因。
        _ = canvasWidth
        let width = PageGeometry.width
        let key = cacheKey(notebook: notebook, pageIndex: pageIndex, drawing: drawing, canvasWidth: width)
        if useCache, let cached = cache.object(forKey: key) { return cached }

        let pageHeight = PageGeometry.height
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

            // 紙張的版面。縮圖上原本**完全沒有** —— 使用者在側欄裡分不出
            // 哪一頁是康乃爾、哪一頁是四象限，而畫布上是看得到的。
            // 匯出也走這裡：列印出來要跟畫布上看到的一樣。
            PageGuideRenderer.draw(
                paperId: notebook.paperId(forPage: pageIndex),
                paletteId: notebook.guidePaletteId,
                in: ctx.cgContext,
                size: fullPageRect.size
            )

            // 疊放順序刻意對齊畫布：手繪在最底，圖釘在最上。
            drawing.image(from: fullPageRect, scale: scale)
                .draw(in: fullPageRect)

            for item in notebook.attachments ?? [] where item.pageIndex == pageIndex {
                drawImage(item, store: store, ctx: ctx)
            }
            // 形狀與連接線在圖片之上、表格之下 —— 與畫布的疊放順序一致
            // （見 `StackableObject.Kind.defaultLayer`）。
            //
            // 這三種型別原本**完全沒有畫**：側邊欄的縮圖與匯出的圖片裡看不到
            // 表格與流程圖，而畫布上看得到。使用者看到的是「預覽跟畫布不一樣」，
            // 而且會以為自己的內容掉了。
            let pageShapes = (notebook.shapeAttachments ?? []).filter { $0.pageIndex == pageIndex }
            for item in pageShapes {
                drawShape(item, ctx: ctx)
            }
            for item in notebook.connectionAttachments ?? [] where item.pageIndex == pageIndex {
                drawConnection(item, shapes: pageShapes, ctx: ctx)
            }
            for item in notebook.tableAttachments ?? [] where item.pageIndex == pageIndex {
                drawTable(item, ctx: ctx)
            }
            for item in notebook.textAttachments ?? [] where item.pageIndex == pageIndex {
                drawText(item, ctx: ctx)
            }
            for item in notebook.linkAttachments ?? [] where item.pageIndex == pageIndex {
                drawLink(item)
            }
            for item in notebook.model3DAttachments ?? [] where item.pageIndex == pageIndex {
                drawModel3D(item, quality: quality, scale: scale)
            }
            for item in notebook.audioAttachments ?? [] where item.pageIndex == pageIndex {
                drawAudio(item)
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

    /// 把單一物件算繪成圖片。
    ///
    /// 匯出 PDF 時，核心的文件模型沒有 3D 模型與連結卡片這兩種型別。
    /// 直接跳過的話匯出就會少掉它們 —— 算繪成圖片帶進去，使用者看到的
    /// 是同一個東西。
    static func renderObjectImage(_ item: Note3DAttachment) -> UIImage? {
        let size = CGSize(width: max(item.width, 1), height: max(item.height, 1))
        return UIGraphicsImageRenderer(size: size).image { _ in
            var local = item
            local.x = 0
            local.y = 0
            drawModel3D(local, quality: .export, scale: 2)
        }
    }

    /// 錄音卡片的靜態外觀，給匯出用。
    ///
    /// 匯出的 PDF 播不出聲音，但卡片**必須在那裡** —— 少畫一張，
    /// 使用者看到的是自己的內容掉了。
    static func renderObjectImage(_ item: NoteAudioAttachment) -> UIImage? {
        let size = CGSize(width: max(item.width, 1), height: max(item.height, 1))
        return UIGraphicsImageRenderer(size: size).image { _ in
            var local = item
            local.x = 0
            local.y = 0
            drawAudio(local)
        }
    }

    static func renderObjectImage(_ item: NoteLinkAttachment) -> UIImage? {
        let size = CGSize(width: max(item.width, 1), height: max(60, item.height))
        return UIGraphicsImageRenderer(size: size).image { _ in
            var local = item
            local.x = 0
            local.y = 0
            drawLink(local)
        }
    }

    // MARK: - 共用外框

    /// 各型別原本的外觀。使用者沒有自訂時回落到這裡 ——
    /// 升級上來的舊筆記看起來必須跟以前一模一樣。
    struct FrameDefaults {
        var borderColor: UIColor
        var borderWidth: CGFloat
        /// `nil` 代表這個型別原本就沒有底色。
        var background: UIColor?

        static let image = FrameDefaults(
            borderColor: .tintColor.withAlphaComponent(0.8), borderWidth: 2.5, background: nil)
        static let text = FrameDefaults(
            borderColor: .tintColor.withAlphaComponent(0.5), borderWidth: 1.5, background: .white)
        static let link = FrameDefaults(
            borderColor: .separator, borderWidth: 1, background: .tertiarySystemBackground)
        static let model3D = FrameDefaults(
            borderColor: .tintColor.withAlphaComponent(0.45), borderWidth: 1.5,
            background: .secondarySystemBackground)
        static let audio = FrameDefaults(
            borderColor: UIColor.systemRed.withAlphaComponent(0.35), borderWidth: 1.5,
            background: .secondarySystemGroupedBackground)
    }

    /// 解析出實際要用的底色。`"clear"` 代表使用者選了透明。
    static func resolvedBackground(
        _ style: some ObjectFrameStyled, defaults: FrameDefaults
    ) -> UIColor? {
        guard let hex = style.backgroundColorHex else { return defaults.background }
        if hex == "clear" { return nil }
        return UIColor(hexString: hex) ?? defaults.background
    }

    static func resolvedBorderColor(
        _ style: some ObjectFrameStyled, defaults: FrameDefaults
    ) -> UIColor {
        style.borderColorHex.flatMap { UIColor(hexString: $0) } ?? defaults.borderColor
    }

    static func resolvedBorderWidth(
        _ style: some ObjectFrameStyled, defaults: FrameDefaults
    ) -> CGFloat {
        style.borderWidth ?? defaults.borderWidth
    }

    /// 畫底色。邊框另外畫 —— 有些型別要先畫內容再描邊。
    static func fillFrame(
        _ style: some ObjectFrameStyled, in rect: CGRect, defaults: FrameDefaults
    ) {
        guard let bg = resolvedBackground(style, defaults: defaults) else { return }
        bg.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: style.cornerRadius).fill()
    }

    static func strokeFrame(
        _ style: some ObjectFrameStyled, in rect: CGRect, defaults: FrameDefaults
    ) {
        guard style.hasBorder else { return }
        resolvedBorderColor(style, defaults: defaults).setStroke()
        let path = UIBezierPath(roundedRect: rect, cornerRadius: style.cornerRadius)
        path.lineWidth = resolvedBorderWidth(style, defaults: defaults)
        path.stroke()
    }

    // MARK: - 各圖層

    @MainActor
    private static func drawImage(
        _ item: NoteImageAttachment,
        store: NotebookStore,
        ctx: UIGraphicsImageRendererContext
    ) {
        let rect = CGRect(x: item.x, y: item.y, width: item.width, height: item.height)
        fillFrame(item, in: rect, defaults: .image)
        guard let image = store.loadAttachmentImage(fileName: item.fileName) else {
            // 圖檔還沒載入完也要佔位，否則縮圖會與畫布對不起來。
            UIColor.secondarySystemFill.setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: item.cornerRadius).fill()
            return
        }

        let cg = ctx.cgContext
        withRotation(item, in: rect) {
            cg.saveGState()
            UIBezierPath(roundedRect: rect, cornerRadius: item.cornerRadius).addClip()
            image.draw(in: rect)
            cg.restoreGState()
            strokeFrame(item, in: rect, defaults: .image)
        }
    }

    /// 畫布上的文字方塊內距。與 `TextBoxCanvasItemView` 共用 `TextBoxMetrics`。
    ///
    /// 這個數字必須跟畫布那邊同步。匯出原本用的是 8/6，於是同一段文字在兩邊
    /// 從不同的位置開始排，行數一不同，整塊版面就對不起來了。
    /// 小方塊的內距會縮，所以這裡也不能再用單一常數 —— 用同一個函式。
    static func textBoxPadding(for item: NoteTextAttachment) -> CGFloat {
        TextBoxMetrics.padding(width: item.width, height: item.height)
    }

    /// 依內容算出文字方塊實際需要的高度。
    ///
    /// 畫布上的高度是**內容撐出來的**（SwiftUI 的 intrinsic size），存下來的
    /// `item.height` 只是最後一次調整時的值。匯出時直接用存下來的高度，
    /// 文字一多就會被截掉或溢出框外壓到旁邊的東西 —— 那正是「方框重疊」的來源。
    static func measuredHeight(for item: NoteTextAttachment) -> CGFloat {
        let pad = textBoxPadding(for: item)
        let inner = max(item.width - pad * 2, 1)
        let bounds = attributedText(for: item).boundingRect(
            with: CGSize(width: inner, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return max(item.height, ceil(bounds.height) + pad * 2)
    }

    private static func attributedText(for item: NoteTextAttachment) -> NSAttributedString {
        var traits: UIFontDescriptor.SymbolicTraits = []
        if item.isBold { traits.insert(.traitBold) }
        if item.isItalic { traits.insert(.traitItalic) }
        let base = UIFont.systemFont(ofSize: item.fontSize)
        let font = base.fontDescriptor.withSymbolicTraits(traits)
            .map { UIFont(descriptor: $0, size: item.fontSize) } ?? base

        let paragraph = NSMutableParagraphStyle()
        switch item.alignmentRaw {
        case "center": paragraph.alignment = .center
        case "right": paragraph.alignment = .right
        case "justified": paragraph.alignment = .justified
        default: paragraph.alignment = .left
        }
        // 換行而不是截斷：畫布上的文字是會自動換行的，截斷等於匯出時
        // 把使用者寫的東西吃掉一部分。
        paragraph.lineBreakMode = .byWordWrapping

        // 段落設定。畫布上套了什麼，匯出就要套什麼 —— 行距差幾點，
        // 整塊文字的行數就不同，版面又會對不起來。
        if let value = item.lineSpacing { paragraph.lineSpacing = value }
        if let value = item.paragraphSpacing { paragraph.paragraphSpacing = value }
        if let value = item.firstLineIndent { paragraph.firstLineHeadIndent = value }
        if let value = item.paragraphIndent { paragraph.headIndent = value }

        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(hexString: item.textColorHex) ?? .label,
            .paragraphStyle: paragraph
        ]
        if item.isUnderline { attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if item.isStrikethrough { attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        return NSAttributedString(string: item.text, attributes: attrs)
    }

    /// 以物件中心為軸套用畫布旋轉，畫完還原。
    ///
    /// 縮圖與畫布**必須用同一個角度**。只在畫布上轉、縮圖不轉的話，
    /// 使用者會以為自己的排版沒有存進去 —— 那比完全不支援旋轉更糟。
    ///
    /// 繞中心而不是繞原點：繞原點的話物件會被甩到畫面外，而且離原點越遠飛得越誇張。
    private static func withRotation<T>(
        _ style: some ObjectFrameStyled,
        in rect: CGRect,
        _ body: () -> T
    ) -> T {
        guard style.isRotated, let cg = UIGraphicsGetCurrentContext() else { return body() }
        cg.saveGState()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        cg.translateBy(x: center.x, y: center.y)
        cg.rotate(by: CGFloat(style.canvasRotation) * .pi / 180)
        cg.translateBy(x: -center.x, y: -center.y)
        defer { cg.restoreGState() }
        return body()
    }

    private static func drawText(_ item: NoteTextAttachment, ctx: UIGraphicsImageRendererContext) {
        let rect = CGRect(
            x: item.x, y: item.y,
            width: item.width, height: measuredHeight(for: item)
        )

        withRotation(item, in: rect) {
            fillFrame(item, in: rect, defaults: .text)
            strokeFrame(item, in: rect, defaults: .text)

            guard !item.text.isEmpty else { return }

            // 裁切到方框內。沒有這一步，超出高度的文字會直接畫到框外、
            // 壓在旁邊的物件上 —— 畫布上不會這樣，因為那邊有 clipShape。
            ctx.cgContext.saveGState()
            UIBezierPath(roundedRect: rect, cornerRadius: item.cornerRadius).addClip()
            attributedText(for: item).draw(
                with: rect.insetBy(dx: textBoxPadding(for: item), dy: textBoxPadding(for: item)),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            ctx.cgContext.restoreGState()
        }
    }

    private static func drawLink(_ item: NoteLinkAttachment) {
        let rect = CGRect(x: item.x, y: item.y, width: item.width, height: max(60, item.height))
        fillFrame(item, in: rect, defaults: .link)
        strokeFrame(item, in: rect, defaults: .link)

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

    // MARK: - 表格、形狀、連接線、錄音
    //
    // 這四種型別的幾何**一律走核心**（`layout()` / `outline()` /
    // `ShapeGeometry.connection`），與畫布用的是同一份。自己再算一次的話，
    // 匯出的表格高度或連接線落點會和畫面上差一點點 —— 而「差一點點」正是
    // 使用者說不出哪裡怪、只覺得怪的那種 bug。

    private static func drawTable(_ item: NoteTableAttachment, ctx: UIGraphicsImageRendererContext) {
        let layout = item.layout()
        let rect = CGRect(
            x: item.x, y: item.y,
            width: CGFloat(layout.width), height: CGFloat(layout.height)
        )
        let cg = ctx.cgContext
        let rotated = abs(item.canvasRotation.truncatingRemainder(dividingBy: 360)) > 0.01
        if rotated {
            cg.saveGState()
            cg.translateBy(x: rect.midX, y: rect.midY)
            cg.rotate(by: CGFloat(item.canvasRotation) * .pi / 180)
            cg.translateBy(x: -rect.midX, y: -rect.midY)
        }
        defer { if rotated { cg.restoreGState() } }

        // 表頭底色先畫，才會在格線與文字下面。
        let headerFill: UIColor = {
            guard let hex = item.headerBackgroundHex else { return UIColor.label.withAlphaComponent(0.06) }
            if hex == "clear" { return .clear }
            return UIColor(hexString: hex) ?? UIColor.label.withAlphaComponent(0.06)
        }()
        headerFill.setFill()
        for cell in layout.cells where cell.isHeader {
            cg.fill(CGRect(x: rect.minX + CGFloat(cell.x), y: rect.minY + CGFloat(cell.y),
                           width: CGFloat(cell.width), height: CGFloat(cell.height)))
        }

        let ruleColor = item.ruleColorHex.flatMap { UIColor(hexString: $0) }
            ?? UIColor.label.withAlphaComponent(0.35)
        ruleColor.setStroke()
        let path = UIBezierPath()
        for rule in layout.rules {
            path.move(to: CGPoint(x: rect.minX + CGFloat(rule.x1), y: rect.minY + CGFloat(rule.y1)))
            path.addLine(to: CGPoint(x: rect.minX + CGFloat(rule.x2), y: rect.minY + CGFloat(rule.y2)))
        }
        path.lineWidth = 1
        path.stroke()

        for cell in layout.cells {
            let text = cell.lines.joined(separator: "\n")
            guard !text.isEmpty else { continue }
            NSAttributedString(
                string: text,
                attributes: [
                    .font: UIFont.systemFont(
                        ofSize: item.fontSize,
                        weight: cell.isHeader ? .semibold : .regular),
                    .foregroundColor: UIColor.label
                ]
            ).draw(
                with: CGRect(
                    x: rect.minX + CGFloat(cell.x) + 6, y: rect.minY + CGFloat(cell.y) + 4,
                    width: max(1, CGFloat(cell.width) - 12), height: max(1, CGFloat(cell.height) - 8)),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
        }
    }

    private static func drawShape(_ item: NoteShapeAttachment, ctx: UIGraphicsImageRendererContext) {
        let points = item.outline()
        guard points.count >= 2 else { return }
        let rect = CGRect(x: item.x, y: item.y, width: item.width, height: item.height)
        let cg = ctx.cgContext
        let rotated = abs(item.canvasRotation.truncatingRemainder(dividingBy: 360)) > 0.01
        if rotated {
            cg.saveGState()
            cg.translateBy(x: rect.midX, y: rect.midY)
            cg.rotate(by: CGFloat(item.canvasRotation) * .pi / 180)
            cg.translateBy(x: -rect.midX, y: -rect.midY)
        }
        defer { if rotated { cg.restoreGState() } }

        let path = UIBezierPath()
        path.move(to: points[0])
        for point in points.dropFirst() { path.addLine(to: point) }
        // 線狀形狀（線／箭頭）不能收尾 —— 收了會多出一條回到起點的邊。
        if !item.isLinear { path.close() }
        path.lineWidth = item.lineWidth

        if !item.isLinear {
            let fill: UIColor = {
                guard let hex = item.fillColorHex else { return .clear }
                return hex == "clear" ? .clear : (UIColor(hexString: hex) ?? .clear)
            }()
            if fill != .clear {
                fill.setFill()
                path.fill()
            }
        }
        (item.strokeColorHex.flatMap { UIColor(hexString: $0) } ?? UIColor.label).setStroke()
        path.stroke()

        // 箭頭頭部要填實，不然箭頭看起來只是一條線。
        for head in item.arrowHeads() where head.count >= 3 {
            let arrow = UIBezierPath()
            arrow.move(to: head[0])
            for point in head.dropFirst() { arrow.addLine(to: point) }
            arrow.close()
            (item.strokeColorHex.flatMap { UIColor(hexString: $0) } ?? UIColor.label).setFill()
            arrow.fill()
        }

        guard !item.label.isEmpty, item.acceptsText else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13),
            .foregroundColor: UIColor.label
        ]
        let size = (item.label as NSString).size(withAttributes: attributes)
        (item.label as NSString).draw(
            at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
            withAttributes: attributes
        )
    }

    private static func drawConnection(
        _ item: NoteConnectionAttachment,
        shapes: [NoteShapeAttachment],
        ctx: UIGraphicsImageRendererContext
    ) {
        guard let from = shapes.first(where: { $0.id == item.fromShapeId }),
              let to = shapes.first(where: { $0.id == item.toShapeId }),
              let geometry = ShapeGeometry.connection(item, from: from, to: to),
              geometry.path.count >= 2 else { return }

        let color = item.colorHex.flatMap { UIColor(hexString: $0) } ?? UIColor.label
        let path = UIBezierPath()
        path.move(to: geometry.path[0])
        for point in geometry.path.dropFirst() { path.addLine(to: point) }
        path.lineWidth = item.lineWidth
        color.setStroke()
        path.stroke()

        if geometry.arrowHead.count >= 3 {
            let head = UIBezierPath()
            head.move(to: geometry.arrowHead[0])
            for point in geometry.arrowHead.dropFirst() { head.addLine(to: point) }
            head.close()
            color.setFill()
            head.fill()
        }
    }

    /// 錄音卡片。匯出的檔案播不出聲音，但**它必須在那裡** ——
    /// 少畫一張卡片，使用者看到的是自己的內容掉了。
    private static func drawAudio(_ item: NoteAudioAttachment) {
        let rect = CGRect(x: item.x, y: item.y, width: item.width, height: item.height)
        fillFrame(item, in: rect, defaults: .audio)
        strokeFrame(item, in: rect, defaults: .audio)

        // 播放鈕的圓與三角。
        let circle = CGRect(x: rect.minX + 12, y: rect.midY - 17, width: 34, height: 34)
        UIColor.systemRed.withAlphaComponent(0.12).setFill()
        UIBezierPath(ovalIn: circle).fill()
        let triangle = UIBezierPath()
        triangle.move(to: CGPoint(x: circle.midX - 5, y: circle.midY - 7))
        triangle.addLine(to: CGPoint(x: circle.midX + 7, y: circle.midY))
        triangle.addLine(to: CGPoint(x: circle.midX - 5, y: circle.midY + 7))
        triangle.close()
        UIColor.systemRed.setFill()
        triangle.fill()

        let textX = circle.maxX + 10
        NSAttributedString(
            string: item.title,
            attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
        ).draw(in: CGRect(x: textX, y: rect.minY + 10,
                          width: max(1, rect.maxX - textX - 12), height: 18))

        NSAttributedString(
            string: AudioAttachmentFormat.duration(item.durationSeconds),
            attributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel
            ]
        ).draw(at: CGPoint(x: textX, y: rect.minY + 30))
    }

    private static func drawModel3D(
        _ item: Note3DAttachment,
        quality: Quality,
        scale: CGFloat
    ) {
        let rect = CGRect(x: item.x, y: item.y, width: item.width, height: item.height)

        // 匯出時真的把模型算繪出來。畫佔位圖示等於「把使用者放進去的東西
        // 換成一個 icon」—— 在側邊欄縮圖上那是合理的取捨，在匯出的檔案上不是。
        if quality == .export, let rendered = renderModel3D(item, scale: scale) {
            fillFrame(item, in: rect, defaults: .model3D)
            rendered.draw(in: rect)
            strokeFrame(item, in: rect, defaults: .model3D)
            return
        }

        drawModel3DPlaceholder(item, rect: rect)
    }

    /// SceneKit 離屏算繪。失敗時回傳 `nil`，由呼叫端退回佔位卡片。
    private static func renderModel3D(_ item: Note3DAttachment, scale: CGFloat) -> UIImage? {
        let size = CGSize(width: max(item.width, 1), height: max(item.height, 1))
        let scene = SceneKitHelper.makeScene(
            modelTypeRaw: item.modelTypeRaw,
            material: item.materialType,
            rotationX: item.rotationX,
            rotationY: item.rotationY,
            rotationZ: item.rotationZ,
            scale: item.scale
        )

        let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        renderer.scene = scene
        // 與畫布上的 SceneView 一樣開預設光源，否則匯出的模型會是一片黑。
        renderer.autoenablesDefaultLighting = true
        renderer.pointOfView = scene.rootNode.childNode(withName: "camera", recursively: true)
            ?? scene.rootNode.childNodes.first { $0.camera != nil }

        let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        return image.size.width > 0 ? image : nil
    }

    private static func drawModel3DPlaceholder(_ item: Note3DAttachment, rect: CGRect) {
        fillFrame(item, in: rect, defaults: .model3D)
        strokeFrame(item, in: rect, defaults: .model3D)

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

        guard !item.title.isEmpty else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        NSAttributedString(
            string: item.title,
            attributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor.secondaryLabel,
                .paragraphStyle: paragraph
            ]
        ).draw(in: CGRect(
            x: rect.minX + 8,
            y: rect.maxY - 26,
            width: rect.width - 16,
            height: 18
        ))
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
