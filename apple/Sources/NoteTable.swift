//
//  NoteTable.swift
//  Kairumo
//
//  畫布上的表格。
//
//  # 為什麼資料長這樣
//
//  儲存格用**扁平陣列**逐列展開，與核心的 `BlockKind::Table` 一致。
//  巢狀 `[[String]]` 在增刪欄時要逐列處理，而且容易出現長度不一致的列 ——
//  那種錯誤在畫面上是「某一列少一格」，而且只有那一列。
//
//  版面（欄寬、列高、斷行）**不在這裡算**，走核心的 `tableLayout` ——
//  兩個平台各算一份的話，同一張表會斷行位置不同、總高度不同。
//

import Foundation

/// 合併儲存格的錨點與跨度。
public struct NoteTableSpan: Codable, Hashable {
    public var row: Int
    public var col: Int
    public var rowSpan: Int
    public var colSpan: Int

    public init(row: Int, col: Int, rowSpan: Int, colSpan: Int) {
        self.row = row
        self.col = col
        self.rowSpan = rowSpan
        self.colSpan = colSpan
    }
}

/// 儲存格水平對齊。
public enum TableHAlign: String, Codable, CaseIterable, Hashable {
    case left, center, right
}

/// 儲存格垂直對齊（內文在格子裡的位置）。
public enum TableVAlign: String, Codable, CaseIterable, Hashable {
    case top, middle, bottom
}

/// 框線樣式。`all` 為預設（與舊檔一致）。
public enum TableBorderMode: String, Codable, CaseIterable, Hashable {
    case all, outer, inner, horizontal, none
}

/// 單一儲存格的格式（仿 Office 的儲存格格式）。
///
/// **每一個欄位都是 Optional，`nil` 代表「沿用表格預設」。** 舊檔沒有這些鍵，
/// 非 Optional 會讓整份筆記解碼失敗（載入走 `try?`，筆記會整批靜默消失）。
public struct NoteTableCellStyle: Codable, Hashable {
    public var bold: Bool?
    public var italic: Bool?
    public var underline: Bool?
    public var strikethrough: Bool?
    public var fontSize: CGFloat?
    public var textColorHex: String?
    /// 儲存格底色。`"clear"` 為透明（蓋掉表頭底色）。
    public var fillHex: String?
    public var hAlign: TableHAlign?
    public var vAlign: TableVAlign?
    /// 文字方向：0 橫向、90 順時針轉 90°、270 逆時針轉 90°。
    public var textRotation: Int?
    /// 自動換行。`nil` 與 `true` 相同。
    public var wrap: Bool?

    public init() {}

    public var isDefault: Bool { self == NoteTableCellStyle() }

    /// 會改變格子所需高度的設定。沒有這些設定的格子沿用核心算好的列高。
    var affectsMeasure: Bool {
        bold != nil || italic != nil || fontSize != nil || textRotation.map { $0 != 0 } == true
            || wrap == false
    }
}

public struct NoteTableAttachment: Identifiable, Codable, Hashable {
    public let id: String
    /// 繞自身中心的旋轉角度（度，順時針）。
    ///
    /// **必須是 Optional** —— 舊檔沒有這個鍵，非 Optional 會讓整份筆記解碼
    /// 失敗，而載入走的是 `try?`：使用者的筆記會整批靜默消失。
    /// 見 `ObjectFrameStyled.canvasRotation` 的說明。
    public var rotationDegrees: Double?
    public var canvasRotation: Double {
        get { rotationDegrees ?? 0 }
        set { rotationDegrees = newValue }
    }
    public var pageIndex: Int
    public var x: CGFloat
    public var y: CGFloat
    public var width: CGFloat
    public var rows: Int
    public var cols: Int
    /// 逐列展開，長度為 `rows * cols`。
    public var cells: [String]
    public var headerRow: Bool
    public var mergedCells: [NoteTableSpan]
    public var fontSize: CGFloat
    /// 格線顏色。`nil` 時用平台預設。
    public var ruleColorHex: String?
    /// 表頭底色。`"clear"` 為透明。
    public var headerBackgroundHex: String?
    /// 逐格格式，長度為 `rows * cols`（與 `cells` 同序）。`nil` 為全部沿用預設。
    public var cellStyles: [NoteTableCellStyle]?
    /// 手動欄寬（點）。`0` 或超出範圍的項目為自動。`nil` 為全部自動。
    public var columnWidthOverrides: [Double]?
    /// 手動列高（點）。語意同上。
    public var rowHeightOverrides: [Double]?
    public var borderMode: TableBorderMode?
    /// 表格整體對齊 ("left", "center", "right")
    public var alignmentRaw: String?
    /// 從左邊縮排 (點)
    public var indentLeft: CGFloat?
    /// 文繞圖 ("none", "around")
    public var textWrappingRaw: String?
    /// 帶狀列（斑馬紋）
    public var bandedRows: Bool?
    /// 帶狀欄
    public var bandedCols: Bool?
    /// 首欄強調
    public var firstCol: Bool?
    /// 末欄強調
    public var lastCol: Bool?
    /// 合計列強調
    public var totalRow: Bool?
    /// 替代文字標題
    public var altTitle: String?
    /// 替代文字描述
    public var altDescription: String?
    /// 框線粗細 (pt)
    public var borderWidth: CGFloat?
    /// 框線樣式 ("solid", "dashed", "double")
    public var borderStyleRaw: String?

    public init(
        id: String = UUID().uuidString.lowercased(),
        pageIndex: Int = 0,
        x: CGFloat = 60,
        y: CGFloat = 120,
        width: CGFloat = 440,
        rows: Int = 3,
        cols: Int = 3,
        cells: [String]? = nil,
        headerRow: Bool = true,
        mergedCells: [NoteTableSpan] = [],
        fontSize: CGFloat = 14,
        ruleColorHex: String? = nil,
        headerBackgroundHex: String? = nil
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.x = x
        self.y = y
        self.width = width
        self.rows = max(1, rows)
        self.cols = max(1, cols)
        // 長度一律補齊：少一格在畫面上是「某一列少一格」，而且只有那一列。
        var content = cells ?? []
        content.append(
            contentsOf: Array(repeating: "", count: max(0, self.rows * self.cols - content.count)))
        self.cells = Array(content.prefix(self.rows * self.cols))
        self.headerRow = headerRow
        self.mergedCells = mergedCells
        self.fontSize = fontSize
        self.ruleColorHex = ruleColorHex
        self.headerBackgroundHex = headerBackgroundHex
    }

    // MARK: - 讀寫

    public func cell(row: Int, col: Int) -> String {
        let index = row * cols + col
        return cells.indices.contains(index) ? cells[index] : ""
    }

    public mutating func setCell(_ text: String, row: Int, col: Int) {
        let index = row * cols + col
        guard cells.indices.contains(index) else { return }
        cells[index] = text
    }

    // MARK: - 儲存格格式

    public func style(row: Int, col: Int) -> NoteTableCellStyle {
        guard let styles = cellStyles else { return NoteTableCellStyle() }
        let index = row * cols + col
        return styles.indices.contains(index) ? styles[index] : NoteTableCellStyle()
    }

    /// 對一個矩形範圍內的每一格套用同一個修改。被合併蓋住的格子也一併改，
    /// 這樣之後取消合併時整片格式是一致的。
    public mutating func updateStyle(
        rows rowRange: ClosedRange<Int>, cols colRange: ClosedRange<Int>,
        _ change: (inout NoteTableCellStyle) -> Void
    ) {
        var styles = cellStyles ?? []
        if styles.count != rows * cols {
            styles = Array(repeating: NoteTableCellStyle(), count: rows * cols)
        }
        for r in rowRange where (0..<rows).contains(r) {
            for c in colRange where (0..<cols).contains(c) {
                change(&styles[r * cols + c])
            }
        }
        // 全部回到預設就收回去，檔案裡不留空陣列。
        cellStyles = styles.allSatisfy(\.isDefault) ? nil : styles
    }

    public mutating func clearStyles(rows rowRange: ClosedRange<Int>, cols colRange: ClosedRange<Int>) {
        updateStyle(rows: rowRange, cols: colRange) { $0 = NoteTableCellStyle() }
    }

    /// 設定第 `index` 欄的欄寬。`nil` 或 `<= 0` 為自動。
    public mutating func setColumnWidth(_ value: Double?, at index: Int) {
        guard (0..<cols).contains(index) else { return }
        var widths = columnWidthOverrides ?? []
        if widths.count != cols { widths = Array(repeating: 0, count: cols) }
        widths[index] = max(0, value ?? 0)
        columnWidthOverrides = widths.allSatisfy { $0 <= 0 } ? nil : widths
    }

    public mutating func setRowHeight(_ value: Double?, at index: Int) {
        guard (0..<rows).contains(index) else { return }
        var heights = rowHeightOverrides ?? []
        if heights.count != rows { heights = Array(repeating: 0, count: rows) }
        heights[index] = max(0, value ?? 0)
        rowHeightOverrides = heights.allSatisfy { $0 <= 0 } ? nil : heights
    }

    /// 所有欄平均分配（填滿 `width`）。
    public mutating func distributeColumns() {
        columnWidthOverrides = Array(repeating: Double(width) / Double(cols), count: cols)
    }

    /// 所有列取同一個高度（以目前最高的那一列為準）。
    public mutating func distributeRows() {
        let heights = resolvedLayout().rowHeights
        let tallest = Double(heights.max() ?? 30)
        rowHeightOverrides = Array(repeating: tallest, count: rows)
    }

    /// 還原成自動欄寬與列高。
    public mutating func autoFitSizes() {
        columnWidthOverrides = nil
        rowHeightOverrides = nil
    }

    /// 合併一個矩形範圍。範圍內原有的合併區先拆掉，否則兩個合併區會互相重疊。
    public mutating func mergeRange(rows rowRange: ClosedRange<Int>, cols colRange: ClosedRange<Int>) {
        let rowSpan = rowRange.count
        let colSpan = colRange.count
        guard rowSpan > 1 || colSpan > 1,
              rowRange.upperBound < rows, colRange.upperBound < cols, rowRange.lowerBound >= 0,
              colRange.lowerBound >= 0 else { return }
        mergedCells.removeAll { span in
            span.row <= rowRange.upperBound && span.row + max(1, span.rowSpan) - 1 >= rowRange.lowerBound
                && span.col <= colRange.upperBound && span.col + max(1, span.colSpan) - 1 >= colRange.lowerBound
        }
        mergedCells.append(
            NoteTableSpan(
                row: rowRange.lowerBound, col: colRange.lowerBound, rowSpan: rowSpan, colSpan: colSpan))
    }

    // MARK: - 增刪
    /// 批次調整表格維度並保留相容格子內容
    public mutating func resizeGrid(newRows: Int, newCols: Int) {
        let targetRows = max(1, newRows)
        let targetCols = max(1, newCols)
        guard targetRows != rows || targetCols != cols else { return }
        var newCells: [String] = []
        for r in 0..<targetRows {
            for c in 0..<targetCols {
                if r < rows && c < cols {
                    newCells.append(cell(row: r, col: c))
                } else {
                    newCells.append("")
                }
            }
        }
        if cellStyles != nil {
            var newStyles: [NoteTableCellStyle] = []
            for r in 0..<targetRows {
                for c in 0..<targetCols {
                    newStyles.append(r < rows && c < cols ? style(row: r, col: c) : NoteTableCellStyle())
                }
            }
            cellStyles = newStyles
        }
        if var widths = columnWidthOverrides {
            widths = Array(widths.prefix(targetCols))
            widths += Array(repeating: 0, count: max(0, targetCols - widths.count))
            columnWidthOverrides = widths
        }
        if var heights = rowHeightOverrides {
            heights = Array(heights.prefix(targetRows))
            heights += Array(repeating: 0, count: max(0, targetRows - heights.count))
            rowHeightOverrides = heights
        }
        self.rows = targetRows
        self.cols = targetCols
        self.cells = newCells
        self.mergedCells.removeAll {
            $0.row + $0.rowSpan > targetRows || $0.col + $0.colSpan > targetCols
        }
    }

    public mutating func insertRow(at index: Int) {
        let position = min(max(0, index), rows)
        cells.insert(contentsOf: Array(repeating: "", count: cols), at: position * cols)
        if cellStyles != nil {
            cellStyles?.insert(
                contentsOf: Array(repeating: NoteTableCellStyle(), count: cols), at: position * cols)
        }
        if let heights = rowHeightOverrides {
            // 新列沿用相鄰列的手動列高（Office 也是這樣）。插入 0（自動）會讓貼齊格線的表格
            // 從新列開始與紙上的線錯開。
            let at = min(position, heights.count)
            let neighbour = heights.indices.contains(at) ? heights[at] : (heights.last ?? 0)
            rowHeightOverrides?.insert(neighbour, at: at)
        }
        rows += 1
        shiftSpans(afterRow: position, by: 1)
    }

    public mutating func deleteRow(at index: Int) {
        // 最後一列不能刪：沒有列的表格畫不出來，畫面上會忽然變空白。
        guard rows > 1, (0..<rows).contains(index) else { return }
        cells.removeSubrange((index * cols)..<((index + 1) * cols))
        if cellStyles != nil { cellStyles?.removeSubrange((index * cols)..<((index + 1) * cols)) }
        if let heights = rowHeightOverrides, heights.indices.contains(index) {
            rowHeightOverrides?.remove(at: index)
        }
        rows -= 1
        mergedCells.removeAll { $0.row == index }
        shiftSpans(afterRow: index, by: -1)
    }

    public mutating func insertColumn(at index: Int) {
        let position = min(max(0, index), cols)
        for row in (0..<rows).reversed() {
            cells.insert("", at: row * cols + position)
            if cellStyles != nil { cellStyles?.insert(NoteTableCellStyle(), at: row * cols + position) }
        }
        if columnWidthOverrides != nil {
            let count = columnWidthOverrides?.count ?? 0
            columnWidthOverrides?.insert(0, at: min(position, count))
        }
        cols += 1
        shiftSpans(afterColumn: position, by: 1)
    }

    public mutating func deleteColumn(at index: Int) {
        guard cols > 1, (0..<cols).contains(index) else { return }
        for row in (0..<rows).reversed() {
            cells.remove(at: row * cols + index)
            if cellStyles != nil { cellStyles?.remove(at: row * cols + index) }
        }
        if let widths = columnWidthOverrides, widths.indices.contains(index) {
            columnWidthOverrides?.remove(at: index)
        }
        cols -= 1
        mergedCells.removeAll { $0.col == index }
        shiftSpans(afterColumn: index, by: -1)
    }

    /// 增刪列欄之後，合併區的錨點要跟著移。
    ///
    /// 不移的話，合併會落在錯的格子上 —— 而且使用者不會知道是插入那一步造成的。
    private mutating func shiftSpans(afterRow index: Int, by delta: Int) {
        mergedCells = mergedCells.map { span in
            var span = span
            if span.row >= index { span.row += delta }
            return span
        }
    }

    private mutating func shiftSpans(afterColumn index: Int, by delta: Int) {
        mergedCells = mergedCells.map { span in
            var span = span
            if span.col >= index { span.col += delta }
            return span
        }
    }

    // MARK: - 合併

    public mutating func merge(row: Int, col: Int, rowSpan: Int, colSpan: Int) {
        guard rowSpan >= 1, colSpan >= 1, rowSpan > 1 || colSpan > 1,
              row + rowSpan <= rows, col + colSpan <= cols else { return }
        unmerge(row: row, col: col)
        mergedCells.append(
            NoteTableSpan(row: row, col: col, rowSpan: rowSpan, colSpan: colSpan))
    }

    public mutating func unmerge(row: Int, col: Int) {
        mergedCells.removeAll { $0.row == row && $0.col == col }
    }

    /// 這一格是不是被別的合併區蓋住了（蓋住的格子不顯示、也不能編輯）。
    public func isCovered(row: Int, col: Int) -> Bool {
        mergedCells.contains { span in
            !(span.row == row && span.col == col)
                && row >= span.row && row < span.row + max(1, span.rowSpan)
                && col >= span.col && col < span.col + max(1, span.colSpan)
        }
    }

    // MARK: - 版面

    /// 核心算出來的版面。欄寬、列高、斷行都在那裡決定。
    public func layout() -> FfiTableLayout {
        tableLayout(
            table: FfiTable(
                blockId: id,
                rows: UInt32(rows),
                cols: UInt32(cols),
                cells: cells,
                headerRow: headerRow,
                mergedCells: mergedCells.map {
                    [UInt32($0.row), UInt32($0.col), UInt32($0.rowSpan), UInt32($0.colSpan)]
                }
            ),
            width: Double(width),
            fontSize: Double(fontSize)
        )
    }

    /// 這張表在畫布上的高度。位置排版要用它。
    public var height: CGFloat { resolvedLayout().height }
}

#if canImport(PencilKit)
import PencilKit

extension NoteTableAttachment {
    /// 檢查筆劃是否位於表格範圍內（支援包含、中心點、面積交集與旋轉）
    public func containsStroke(_ stroke: PKStroke) -> Bool {
        let layout = self.resolvedLayout()
        let tableWidth = max(self.width, layout.width)
        let tableHeight = max(self.height, layout.height)
        let tableRect = CGRect(x: self.x, y: self.y, width: tableWidth, height: tableHeight)
        let hitRect = tableRect.insetBy(dx: -4, dy: -4)

        let center = CGPoint(x: self.x + tableWidth / 2, y: self.y + tableHeight / 2)
        let rad = -self.canvasRotation * .pi / 180.0
        let cosA = cos(rad)
        let sinA = sin(rad)
        func unrotatedPoint(_ p: CGPoint) -> CGPoint {
            guard abs(self.canvasRotation) > 0.01 else { return p }
            let dx = p.x - center.x
            let dy = p.y - center.y
            return CGPoint(
                x: center.x + CGFloat(Double(dx) * cosA - Double(dy) * sinA),
                y: center.y + CGFloat(Double(dx) * sinA + Double(dy) * cosA)
            )
        }

        let bounds = stroke.renderBounds
        let mid = CGPoint(x: bounds.midX, y: bounds.midY)
        let unrotatedMid = unrotatedPoint(mid)
        let unrotatedOrigin = unrotatedPoint(bounds.origin)
        let intersection = tableRect.intersection(bounds)

        if abs(self.canvasRotation) > 0.01 {
            return hitRect.contains(unrotatedMid) || hitRect.contains(unrotatedOrigin)
        }

        return tableRect.contains(bounds)
            || hitRect.contains(mid)
            || (!intersection.isNull && (intersection.width * intersection.height) >= (bounds.width * bounds.height * 0.4))
            || (hitRect.contains(bounds.origin) && !intersection.isNull && intersection.width > 2 && intersection.height > 2)
    }

    /// 將畫布筆跡中位於表格內的所有筆劃平移 delta
    public func offsetContainedStrokes(in drawing: PKDrawing, by delta: CGSize) -> (drawing: PKDrawing, movedCount: Int) {
        guard hypot(delta.width, delta.height) >= 0.5 else { return (drawing, 0) }
        var newStrokes = drawing.strokes
        var movedCount = 0
        for i in 0..<newStrokes.count {
            if containsStroke(newStrokes[i]) {
                var moved = newStrokes[i]
                moved.transform = moved.transform.concatenating(CGAffineTransform(translationX: delta.width, y: delta.height))
                newStrokes[i] = moved
                movedCount += 1
            }
        }
        return (PKDrawing(strokes: newStrokes), movedCount)
    }
}
#endif

// MARK: - 畫布縮放、對齊、以儲存格為準的合併（表格編修工具列與「表格內容」面板共用）

/// 框線樣式。`NoteTableAttachment.borderStyleRaw` 的值；`nil` 為實線。
public enum TableBorderStyle: String, CaseIterable, Hashable {
    case solid, dashed, dotted

    /// 給 `StrokeStyle` / `UIBezierPath.setLineDash` 用的虛線樣式（與線寬成比例）。
    public func dashPattern(lineWidth: CGFloat) -> [CGFloat] {
        let w = max(0.5, lineWidth)
        switch self {
        case .solid: return []
        case .dashed: return [w * 4, w * 2]
        case .dotted: return [w, w * 1.5]
        }
    }
}

/// 一格的底色來源。畫布（`NoteTableView`）與縮圖（`PageThumbnailRenderer`）走同一個判斷，
/// 兩邊才不會一邊有斑馬紋、一邊沒有（I4）。
public enum TableCellFillRole: Equatable {
    case own(String)
    case header
    case bandedRow
    case bandedColumn
}

extension NoteTableAttachment {

    /// 畫格線用的線寬（點）。
    public var resolvedBorderWidth: CGFloat { max(0.5, borderWidth ?? 1) }

    public var resolvedBorderStyle: TableBorderStyle {
        borderStyleRaw.flatMap(TableBorderStyle.init(rawValue:)) ?? .solid
    }

    public func fillRole(row: Int, col: Int, isHeader: Bool) -> TableCellFillRole? {
        if let own = style(row: row, col: col).fillHex { return .own(own) }
        if isHeader { return .header }
        if bandedRows == true && row % 2 == 1 { return .bandedRow }
        if bandedCols == true && col % 2 == 1 { return .bandedColumn }
        return nil
    }

    /// 在畫布上拖曳縮放把手：表格外框變成 `newSize`，**每一欄、每一列等比例**跟著縮放。
    ///
    /// 只改 `width` 的話，有手動欄寬的表格寬度根本不會變（版面以覆寫為準），
    /// 列高也不會動 —— 那就是「拉了把手但儲存格沒跟著縮」。
    public mutating func scale(to newSize: CGSize) {
        let layout = resolvedLayout()
        guard layout.width > 0, layout.height > 0, newSize.width > 0, newSize.height > 0 else { return }
        let minWidth = CGFloat(cols) * Self.minimumColumnWidth
        let minHeight = CGFloat(rows) * Self.minimumRowHeight
        let targetW = max(minWidth, newSize.width)
        let targetH = max(minHeight, newSize.height)
        let sx = targetW / layout.width
        let sy = targetH / layout.height
        columnWidthOverrides = layout.columnWidths.map { max(Double(Self.minimumColumnWidth), Double($0 * sx)) }
        rowHeightOverrides = layout.rowHeights.map { max(Double(Self.minimumRowHeight), Double($0 * sy)) }
        width = CGFloat(columnWidthOverrides?.reduce(0, +) ?? Double(targetW))
    }

    /// 版面解析器認得的最小欄寬／列高（低於它會被當成「自動」）。
    public static let minimumColumnWidth: CGFloat = 24
    public static let minimumRowHeight: CGFloat = 16

    /// 「表格內容 › 對齊」落地：依頁寬算出表格左緣該在哪裡。`alignmentRaw == nil` 回 `nil`（不動）。
    public func alignedX(pageWidth: CGFloat, inset: CGFloat) -> CGFloat? {
        guard let raw = alignmentRaw else { return nil }
        let w = resolvedLayout().width
        switch raw {
        case "center": return max(inset, (pageWidth - w) / 2)
        case "right": return max(inset, pageWidth - inset - w)
        default: return inset + max(0, indentLeft ?? 0)
        }
    }

    /// 含有 (row, col) 的合併區（沒有就是 `nil`）。
    public func span(containing row: Int, col: Int) -> NoteTableSpan? {
        mergedCells.first { span in
            row >= span.row && row < span.row + max(1, span.rowSpan)
                && col >= span.col && col < span.col + max(1, span.colSpan)
        }
    }

    /// 把 (row, col) 所在的格子（或合併區）與右邊一欄合併。
    public mutating func mergeRight(row: Int, col: Int) {
        let s = span(containing: row, col: col) ?? NoteTableSpan(row: row, col: col, rowSpan: 1, colSpan: 1)
        let lastCol = s.col + max(1, s.colSpan)
        guard lastCol < cols else { return }
        mergeRange(rows: s.row...(s.row + max(1, s.rowSpan) - 1), cols: s.col...lastCol)
    }

    /// 把 (row, col) 所在的格子（或合併區）與下面一列合併。
    public mutating func mergeDown(row: Int, col: Int) {
        let s = span(containing: row, col: col) ?? NoteTableSpan(row: row, col: col, rowSpan: 1, colSpan: 1)
        let lastRow = s.row + max(1, s.rowSpan)
        guard lastRow < rows else { return }
        mergeRange(rows: s.row...lastRow, cols: s.col...(s.col + max(1, s.colSpan) - 1))
    }

    /// 分割 (row, col) 所在的合併區。
    public mutating func splitCell(row: Int, col: Int) {
        guard let s = span(containing: row, col: col) else { return }
        unmerge(row: s.row, col: s.col)
    }

    /// (row, col) 所在的矩形範圍（合併區則為整片）。
    public func cellRange(row: Int, col: Int) -> (rows: ClosedRange<Int>, cols: ClosedRange<Int>) {
        let r = min(max(0, row), rows - 1)
        let c = min(max(0, col), cols - 1)
        guard let s = span(containing: r, col: c) else { return (r...r, c...c) }
        return (s.row...(s.row + max(1, s.rowSpan) - 1), s.col...(s.col + max(1, s.colSpan) - 1))
    }
}

extension NoteTableAttachment {
    /// 「表格內容 › 慣用寬度」：有手動欄寬時各欄等比例縮放，否則直接改寬度。
    ///
    /// 只改 `width` 的話，有手動欄寬的表格完全不會變（版面以覆寫為準）——輸入框改了沒反應。
    public mutating func setPreferredWidth(_ newWidth: CGFloat) {
        let target = max(CGFloat(cols) * Self.minimumColumnWidth, newWidth)
        guard let overrides = columnWidthOverrides, overrides.contains(where: { $0 > 0 }) else {
            width = target
            return
        }
        let layout = resolvedLayout()
        let s = target / max(1, layout.width)
        let scaled = layout.columnWidths.map { max(Double(Self.minimumColumnWidth), Double($0 * s)) }
        columnWidthOverrides = scaled
        width = CGFloat(scaled.reduce(0, +))
    }
}
