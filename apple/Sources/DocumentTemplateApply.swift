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

        var texts = doc.textAttachments ?? []
        var tables = doc.tableAttachments ?? []

        for block in variant.blocks {
            if block.kind == "table" {
                tables.append(
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
                texts.append(textBox(block))
            }
        }

        doc.textAttachments = texts
        doc.tableAttachments = tables
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
