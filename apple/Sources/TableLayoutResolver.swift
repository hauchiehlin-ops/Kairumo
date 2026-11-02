//
//  TableLayoutResolver.swift
//  Kairumo
//
//  核心版面 + 使用者手動欄寬／列高／儲存格格式 = 畫面上實際的表格。
//
//  # 為什麼在核心版面「之上」做，而不是改核心
//
//  核心的 `tableLayout` 不認得逐格字級、手動欄寬與列高。這一層把核心算好的
//  欄邊界與列邊界當作「自動值」，再套上使用者的覆寫：
//
//  - 沒有任何覆寫、沒有任何儲存格格式時，結果與核心**逐點相同**（舊檔不變）。
//  - 欄寬／列高覆寫只改邊界位置；合併儲存格與格線沿用核心的結果，座標跟著邊界重映射，
//    所以合併區上不會多出格線。
//  - 儲存格格式只會讓列「長高」不會縮（除非使用者指定了列高），文字不會被切掉。
//

import CoreGraphics
import SwiftUI
import UIKit

/// 畫面上一格的幾何與內容。
public struct ResolvedTableCell {
    public let row: Int
    public let col: Int
    public let rowSpan: Int
    public let colSpan: Int
    public let rect: CGRect
    /// 公式已計算過的顯示文字。
    public let text: String
    public let isHeader: Bool
    public let style: NoteTableCellStyle
    public let fontSize: CGFloat
    public let isBold: Bool
    public var x: CGFloat { rect.minX }
    public var y: CGFloat { rect.minY }
    public var width: CGFloat { rect.width }
    public var height: CGFloat { rect.height }
}

public struct ResolvedTableLayout {
    public var width: CGFloat
    public var height: CGFloat
    public var columnWidths: [CGFloat]
    public var rowHeights: [CGFloat]
    public var cells: [ResolvedTableCell]
    /// 格線（起點、終點）。已套用框線樣式。
    public var rules: [(CGPoint, CGPoint)]

    /// 表格座標落在哪一格（合併區回傳其錨點）。
    public func cellCoordinate(at point: CGPoint) -> TableCellCoordinate? {
        let hit = cells.first { $0.rect.insetBy(dx: -0.01, dy: -0.01).contains(point) }
        return hit.map { TableCellCoordinate(row: $0.row, col: $0.col) }
    }

    /// 一個矩形範圍佔的畫面區域。
    public func rect(rows: ClosedRange<Int>, cols: ClosedRange<Int>) -> CGRect {
        let xs = cumulative(columnWidths)
        let ys = cumulative(rowHeights)
        guard cols.lowerBound >= 0, cols.upperBound < columnWidths.count,
              rows.lowerBound >= 0, rows.upperBound < rowHeights.count else { return .zero }
        return CGRect(
            x: xs[cols.lowerBound], y: ys[rows.lowerBound],
            width: xs[cols.upperBound + 1] - xs[cols.lowerBound],
            height: ys[rows.upperBound + 1] - ys[rows.lowerBound])
    }
}

private func cumulative(_ values: [CGFloat]) -> [CGFloat] {
    var out: [CGFloat] = [0]
    for v in values { out.append(out[out.count - 1] + v) }
    return out
}

extension NoteTableCellStyle {
    /// 這一格實際用的字體。表頭預設半粗，使用者明確設定粗體（或取消）時以設定為準。
    func resolvedFont(baseSize: CGFloat, isHeader: Bool) -> UIFont {
        let size = fontSize ?? baseSize
        let weight: UIFont.Weight
        switch bold {
        case .some(true): weight = .bold
        case .some(false): weight = .regular
        case .none: weight = isHeader ? .semibold : .regular
        }
        var font = UIFont.systemFont(ofSize: size, weight: weight)
        if italic == true,
           let descriptor = font.fontDescriptor.withSymbolicTraits(
               font.fontDescriptor.symbolicTraits.union(.traitItalic)) {
            font = UIFont(descriptor: descriptor, size: size)
        }
        return font
    }
}

extension NoteTableAttachment {

    /// 格子內距（左右、上下各一邊）。與畫布上的 `NoteTableView` 一致。
    static let cellInset: CGFloat = 6

    public func resolvedLayout() -> ResolvedTableLayout {
        let core = layout()

        var colW = core.columnWidths.map { CGFloat($0) }
        if colW.count != cols { colW = Array(repeating: width / CGFloat(cols), count: cols) }
        var rowH = core.rowHeights.map { CGFloat($0) }
        if rowH.count != rows { rowH = Array(repeating: CGFloat(core.height) / CGFloat(rows), count: rows) }
        let oldColEdges = cumulative(colW)
        let oldRowEdges = cumulative(rowH)

        let colOverrides = columnWidthOverrides ?? []
        let rowOverrides = rowHeightOverrides ?? []
        let hasColOverride = colOverrides.contains { $0 > 0 }

        // 每一個錨點格的顯示文字。
        struct Entry {
            let core: FfiTableCell
            let text: String
            let style: NoteTableCellStyle
        }
        let entries: [Entry] = core.cells.map { cell in
            let r = Int(cell.row)
            let c = Int(cell.col)
            let raw = self.cell(row: r, col: c)
            let shown = TableFormulaEvaluator.evaluateCell(
                content: raw, allCells: cells, rows: rows, cols: cols)
            return Entry(
                core: cell,
                text: shown.isEmpty ? cell.lines.joined(separator: "\n") : shown,
                style: style(row: r, col: c))
        }

        // 欄寬：覆寫優先。
        for c in 0..<cols where c < colOverrides.count && colOverrides[c] >= 24 {
            colW[c] = CGFloat(colOverrides[c])
        }
        func spanWidth(_ cell: FfiTableCell) -> CGFloat {
            let start = Int(cell.col)
            let end = min(cols, start + max(1, Int(cell.colSpan)))
            return colW[start..<end].reduce(0, +)
        }

        // 列高：自動值要先看格式與欄寬的影響，再套手動列高。
        let floorHeight = rowH.min() ?? 30
        var measured = Array(repeating: CGFloat(0), count: rows)
        for entry in entries where Int(entry.core.rowSpan) == 1 {
            let r = Int(entry.core.row)
            let isHeader = entry.core.isHeader
            guard entry.style.affectsMeasure || hasColOverride else { continue }
            let font = entry.style.resolvedFont(baseSize: fontSize, isHeader: isHeader)
            let need = Self.neededHeight(
                text: entry.text, font: font, width: spanWidth(entry.core),
                wrap: entry.style.wrap ?? true, rotation: entry.style.textRotation ?? 0)
            measured[r] = max(measured[r], need)
        }
        for r in 0..<rows {
            if hasColOverride {
                // 欄寬變了，核心當初算的斷行就不準：自動列高全部改用實測值（不低於單行高度）。
                rowH[r] = max(floorHeight, measured[r])
            } else if measured[r] > 0 {
                rowH[r] = max(rowH[r], measured[r])
            }
            if r < rowOverrides.count, rowOverrides[r] >= 16 { rowH[r] = CGFloat(rowOverrides[r]) }
        }

        let newColEdges = cumulative(colW)
        let newRowEdges = cumulative(rowH)
        let totalWidth = newColEdges.last ?? 0
        let totalHeight = newRowEdges.last ?? 0

        // 舊邊界 → 新邊界的對照（格線座標用）。
        func remap(_ value: CGFloat, old: [CGFloat], new: [CGFloat]) -> CGFloat {
            for i in old.indices where abs(old[i] - value) < 0.5 { return new[i] }
            guard let upper = old.firstIndex(where: { $0 > value }), upper > 0 else {
                return value >= (old.last ?? 0) ? (new.last ?? value) : value
            }
            let span = old[upper] - old[upper - 1]
            let t = span > 0 ? (value - old[upper - 1]) / span : 0
            return new[upper - 1] + t * (new[upper] - new[upper - 1])
        }
        func edgeIndex(_ value: CGFloat, in edges: [CGFloat]) -> Int? {
            edges.firstIndex { abs($0 - value) < 0.5 }
        }

        let mode = borderMode ?? .all
        var rules: [(CGPoint, CGPoint)] = []
        if mode != .none {
            for rule in core.rules {
                let x1 = CGFloat(rule.x1), y1 = CGFloat(rule.y1)
                let x2 = CGFloat(rule.x2), y2 = CGFloat(rule.y2)
                let horizontal = abs(y1 - y2) < 0.5
                switch mode {
                case .horizontal where !horizontal:
                    continue
                case .outer, .inner:
                    let outer: Bool
                    if horizontal {
                        let i = edgeIndex(y1, in: oldRowEdges)
                        outer = i == 0 || i == oldRowEdges.count - 1
                    } else {
                        let i = edgeIndex(x1, in: oldColEdges)
                        outer = i == 0 || i == oldColEdges.count - 1
                    }
                    if (mode == .outer) != outer { continue }
                default:
                    break
                }
                rules.append((
                    CGPoint(x: remap(x1, old: oldColEdges, new: newColEdges),
                            y: remap(y1, old: oldRowEdges, new: newRowEdges)),
                    CGPoint(x: remap(x2, old: oldColEdges, new: newColEdges),
                            y: remap(y2, old: oldRowEdges, new: newRowEdges))))
            }
        }

        let resolvedCells: [ResolvedTableCell] = entries.map { entry in
            let cell = entry.core
            let r = Int(cell.row), c = Int(cell.col)
            let r2 = min(rows, r + max(1, Int(cell.rowSpan)))
            let c2 = min(cols, c + max(1, Int(cell.colSpan)))
            let font = entry.style.resolvedFont(baseSize: fontSize, isHeader: cell.isHeader)
            return ResolvedTableCell(
                row: r, col: c,
                rowSpan: max(1, Int(cell.rowSpan)), colSpan: max(1, Int(cell.colSpan)),
                rect: CGRect(
                    x: newColEdges[c], y: newRowEdges[r],
                    width: newColEdges[c2] - newColEdges[c],
                    height: newRowEdges[r2] - newRowEdges[r]),
                text: entry.text, isHeader: cell.isHeader, style: entry.style,
                fontSize: font.pointSize,
                isBold: (entry.style.bold ?? cell.isHeader))
        }

        return ResolvedTableLayout(
            width: totalWidth, height: totalHeight,
            columnWidths: colW, rowHeights: rowH, cells: resolvedCells, rules: rules)
    }

    /// 一格內容需要的高度（含上下內距）。
    static func neededHeight(
        text: String, font: UIFont, width: CGFloat, wrap: Bool, rotation: Int
    ) -> CGFloat {
        let pad = cellInset * 2
        let sample = text.isEmpty ? " " : text
        if rotation != 0 {
            // 旋轉後文字沿著列高排：需要的高度就是文字的長度（上限避免一格把整張表撐爆）。
            let longest = sample.components(separatedBy: "\n")
                .map { ($0 as NSString).size(withAttributes: [.font: font]).width }
                .max() ?? 0
            return min(360, ceil(longest) + pad + 4)
        }
        if !wrap {
            let lines = max(1, sample.components(separatedBy: "\n").count)
            return ceil(font.lineHeight) * CGFloat(lines) + pad
        }
        let rect = (sample as NSString).boundingRect(
            with: CGSize(width: max(10, width - pad), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font], context: nil)
        return ceil(rect.height) + pad
    }
}

// MARK: - 顏色

extension NoteTableCellStyle {
    var resolvedTextColor: Color? { textColorHex.flatMap(Color.init(hex:)) }
    /// `nil`：沿用（表頭底色或透明）。`.clear`：明確透明。
    var resolvedFill: Color? {
        guard let hex = fillHex else { return nil }
        return hex == "clear" ? .clear : Color(hex: hex)
    }
}

// MARK: - 縮圖／匯出用的繪製

extension NoteTableAttachment {
    /// 在 `CGContext` 裡畫出一格的文字（縮圖、列印共用）。
    static func drawCellText(_ cell: ResolvedTableCell, origin: CGPoint, in cg: CGContext) {
        guard !cell.text.isEmpty else { return }
        let style = cell.style
        let font = style.resolvedFont(baseSize: cell.fontSize, isHeader: cell.isHeader)
        let paragraph = NSMutableParagraphStyle()
        switch style.hAlign ?? .left {
        case .left: paragraph.alignment = .left
        case .center: paragraph.alignment = .center
        case .right: paragraph.alignment = .right
        }
        paragraph.lineBreakMode = (style.wrap ?? true) ? .byWordWrapping : .byClipping
        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: style.textColorHex.flatMap { UIColor(hexString: $0) } ?? UIColor.label,
            .paragraphStyle: paragraph,
        ]
        if style.underline == true { attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if style.strikethrough == true { attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }

        let rotation = style.textRotation ?? 0
        let pad = cellInset
        let rotated = rotation != 0
        let boxW = max(1, (rotated ? cell.height : cell.width) - pad * 2)
        let boxH = max(1, (rotated ? cell.width : cell.height) - pad * 2)

        let attributed = NSAttributedString(string: cell.text, attributes: attrs)
        let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let bounds = attributed.boundingRect(
            with: CGSize(width: (style.wrap ?? true) ? boxW : .greatestFiniteMagnitude, height: .greatestFiniteMagnitude),
            options: options, context: nil)
        let textH = min(boxH, ceil(bounds.height))
        let yOffset: CGFloat
        switch style.vAlign ?? .top {
        case .top: yOffset = 0
        case .middle: yOffset = (boxH - textH) / 2
        case .bottom: yOffset = boxH - textH
        }

        cg.saveGState()
        let center = CGPoint(x: origin.x + cell.x + cell.width / 2, y: origin.y + cell.y + cell.height / 2)
        cg.translateBy(x: center.x, y: center.y)
        if rotated { cg.rotate(by: CGFloat(rotation) * .pi / 180) }
        cg.clip(to: CGRect(x: -boxW / 2, y: -boxH / 2, width: boxW, height: boxH))
        attributed.draw(
            with: CGRect(x: -boxW / 2, y: -boxH / 2 + yOffset, width: boxW, height: max(textH, 1)),
            options: options, context: nil)
        cg.restoreGState()
    }
}
