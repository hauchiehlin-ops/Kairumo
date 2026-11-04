import CoreGraphics
import Foundation
import PencilKit

/// 把文件範本的內容鋪進一本新筆記（工作項 S-61）。
///
/// 座標已經由 `scripts/doc_templates_tool.py` 算好，這裡只負責把每一個區塊
/// 轉成對應的附件型別。**不要在這裡重算版面** —— 一重算，Apple 與 Android
/// 就各有一套版面邏輯，兩邊會慢慢分岔。
extension DocumentTemplateCatalog {

    /// 各種區塊的顏色與外觀。與 `SeedContent` 同一組配色。
    private enum Ink {
        static let title = "#141A22"
        static let heading = "#1F2937"
        static let body = "#26303C"
        static let noticeText = "#7A4A05"
        static let noticeFill = "#FDF4E3"
        static let noticeBorder = "#E0A94A"
        static let tableHeader = "#E9EEFC"
    }

    /// 把 `template` 的 `kind` 版本鋪進 `doc`。
    ///
    /// - Parameter language: 介面語言。內文只有繁中與英文，其餘退回繁中。
    public static func apply(
        _ template: Template,
        kind: Variantkind,
        language: String,
        to doc: inout NotebookDocument
    ) {
        guard let variant = variant(template, kind: kind, language: language) else { return }

        let blank = PKDrawing().dataRepresentation()
        while doc.pagesData.count < variant.pageCount {
            doc.pagesData.append(blank)
        }
        doc.pageCount = max(doc.pageCount, variant.pageCount)

        var newTexts: [NoteTextAttachment] = []
        var newTables: [NoteTableAttachment] = []

        for block in variant.blocks {
            if block.kind == "table" {
                newTables.append(
                    NoteTableAttachment(
                        pageIndex: block.page,
                        x: block.x,
                        y: block.y,
                        width: block.width,
                        rows: block.rows,
                        cols: block.cols,
                        cells: block.cells,
                        headerRow: block.headerRow,
                        fontSize: 13,
                        headerBackgroundHex: Ink.tableHeader
                    ))
            } else {
                newTexts.append(textBox(block))
            }
        }

        // 橫線紙／方格紙：文字與表格貼齊格線。座標是範本算好的「理想位置」，
        // 但範本不知道底下是哪一種紙 —— 不貼齊的話字會卡在兩條線中間、表格的列線與紙上的線錯開。
        // 注意：如果是「紙張樣板自己的示範內容」（paperTemplate != nil），版面是針對該紙張特定引導線
        // 與網格專門設計的，絕對不能再做 snapToRules，否則會破壞精心設計的專屬座標。
        if paperTemplate(paperId: template.id) == nil {
            snapToRules(texts: &newTexts, tables: &newTables, doc: doc)
        }

        doc.textAttachments = (doc.textAttachments ?? []) + newTexts
        doc.tableAttachments = (doc.tableAttachments ?? []) + newTables
    }

    // MARK: - 貼齊格線

    /// 一頁的水平格線與間距。不像橫線紙（沒有線、間距不規則）回 `nil` —— 呼叫端維持範本原座標。
    private static func ruleGrid(forPage page: Int, in doc: NotebookDocument) -> (rules: [CGFloat], step: CGFloat)? {
        let paperId = doc.paperId(forPage: page)
        let guides = pageGuides(
            paperId: paperId, width: Float(PageGeometry.width), height: Float(PageGeometry.height))
        let bands = pageTexture(
            paperId: paperId, style: NoteTemplate(paperId: paperId)?.pageStyle ?? .blank,
            width: Float(PageGeometry.width), height: Float(PageGeometry.height))
        let rules = RuledWriting.horizontalRules(guides: guides, bands: bands)
        guard let step = RuledWriting.step(of: rules) else { return nil }
        return (rules, step)
    }

    private enum Placed {
        case text(Int)
        case table(Int)
    }

    /// 把新鋪的文字方塊與表格貼到格線上：
    ///
    /// - 文字：第一行坐在格線上，行距取格線間距的整數倍，後面每一行也都在線上。
    /// - 表格：列高取格線間距的整數倍、頂邊落在格線上，每一條橫格線都與紙上的線重合。
    /// - 往下貼齊可能會撞到前一個區塊，所以依頁面由上到下排，撞到就順延到下一條線
    ///   （順延後會超出可列印範圍就不動，寧可貼近也不要被擠出頁面）。
    private static func snapToRules(
        texts: inout [NoteTextAttachment], tables: inout [NoteTableAttachment], doc: NotebookDocument
    ) {
        var gridCache: [Int: (rules: [CGFloat], step: CGFloat)?] = [:]
        func grid(_ page: Int) -> (rules: [CGFloat], step: CGFloat)? {
            if let cached = gridCache[page] { return cached }
            let value = ruleGrid(forPage: page, in: doc)
            gridCache[page] = .some(value)
            return value
        }

        var order: [(page: Int, y: CGFloat, item: Placed)] = []
        for (i, t) in texts.enumerated() { order.append((t.pageIndex, t.y, .text(i))) }
        for (i, t) in tables.enumerated() { order.append((t.pageIndex, t.y, .table(i))) }
        order.sort { ($0.page, $0.y) < ($1.page, $1.y) }

        var floors: [Int: CGFloat] = [:]
        let limit = PageGeometry.height - PageGeometry.printableInset

        for entry in order {
            guard let g = grid(entry.page) else { continue }
            let floor = floors[entry.page] ?? 0

            /// 最靠近 `y` 的那條線；撞到前一個區塊時改取不小於 `floor` 的下一條。
            func snapped(top y: CGFloat, offset: CGFloat, height: CGFloat) -> CGFloat {
                let target = y + offset
                var rule = g.rules.min { abs($0 - target) < abs($1 - target) } ?? target
                var top = rule - offset
                if top < floor - 0.5 {
                    if let next = g.rules.first(where: { $0 - offset >= floor - 0.5 }),
                       next - offset + height <= limit {
                        rule = next
                        top = rule - offset
                    } else {
                        // 往下已無合適格線，維持在上一區塊底部之下，嚴禁回傳小於 floor 的 top 導致重疊
                        top = max(y, floor)
                    }
                }
                return max(0, top)
            }

            switch entry.item {
            case .text(let i):
                var t = texts[i]
                let natural = RuledWriting.lineHeight(fontSize: t.fontSize, bold: t.isBold)
                let pitch = max(1, (natural / g.step).rounded(.up)) * g.step
                let offset = RuledWriting.textBottomOffset(fontSize: t.fontSize, bold: t.isBold)
                t.lineSpacing = max(0, pitch - natural)
                t.paragraphSpacing = 0
                let height = RuledWriting.boxHeight(
                    text: t.text, width: t.width, fontSize: t.fontSize, bold: t.isBold,
                    lineSpacing: t.lineSpacing ?? 0)
                t.height = max(t.height, height)
                t.y = snapped(top: t.y, offset: offset, height: t.height)
                floors[entry.page] = t.y + t.height
                texts[i] = t

            case .table(let i):
                var t = tables[i]
                // 先算出核心的自動列高，再取格線間距的整數倍。
                let heights = t.resolvedLayout().rowHeights
                t.rowHeightOverrides = heights.map {
                    max(1, (CGFloat($0) / g.step).rounded(.up)) * g.step
                }.map(Double.init)
                // 字坐在下面那條線上，與橫線紙上寫字的感覺一致。
                t.updateStyle(rows: 0...(t.rows - 1), cols: 0...(t.cols - 1)) { $0.vAlign = .bottom }
                let total = t.resolvedLayout().height
                t.y = snapped(top: t.y, offset: 0, height: total)
                floors[entry.page] = t.y + total
                tables[i] = t
            }
        }
    }

    private static func textBox(_ block: Block) -> NoteTextAttachment {
        // 免責提示是唯一有底框的區塊 —— 它要一眼看出來「這段不是文件本文」，
        // 否則使用者會把它當成契約條款的一部分印出去。
        let isNotice = block.kind == "notice"
        return NoteTextAttachment(
            pageIndex: block.page,
            text: block.text,
            fontSize: block.fontSize,
            isBold: block.bold,
            alignmentRaw: "left",
            textColorHex: color(for: block.kind),
            backgroundColorHex: isNotice ? Ink.noticeFill : "clear",
            hasBorder: isNotice,
            cornerRadius: isNotice ? 8 : 0,
            borderColorHex: isNotice ? Ink.noticeBorder : nil,
            x: block.x,
            y: block.y,
            width: block.width,
            height: block.height,
            lineSpacing: block.lineSpacing,
            paragraphSpacing: 6
        )
    }

    private static func color(for kind: String) -> String {
        switch kind {
        case "title": return Ink.title
        case "heading": return Ink.heading
        case "notice": return Ink.noticeText
        default: return Ink.body
        }
    }
}
