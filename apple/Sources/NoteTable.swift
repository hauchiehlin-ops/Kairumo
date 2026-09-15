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

    public init(
        id: String = UUID().uuidString,
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

    // MARK: - 增刪

    public mutating func insertRow(at index: Int) {
        let position = min(max(0, index), rows)
        cells.insert(contentsOf: Array(repeating: "", count: cols), at: position * cols)
        rows += 1
        shiftSpans(afterRow: position, by: 1)
    }

    public mutating func deleteRow(at index: Int) {
        // 最後一列不能刪：沒有列的表格畫不出來，畫面上會忽然變空白。
        guard rows > 1, (0..<rows).contains(index) else { return }
        cells.removeSubrange((index * cols)..<((index + 1) * cols))
        rows -= 1
        mergedCells.removeAll { $0.row == index }
        shiftSpans(afterRow: index, by: -1)
    }

    public mutating func insertColumn(at index: Int) {
        let position = min(max(0, index), cols)
        for row in (0..<rows).reversed() {
            cells.insert("", at: row * cols + position)
        }
        cols += 1
        shiftSpans(afterColumn: position, by: 1)
    }

    public mutating func deleteColumn(at index: Int) {
        guard cols > 1, (0..<cols).contains(index) else { return }
        for row in (0..<rows).reversed() {
            cells.remove(at: row * cols + index)
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
    public var height: CGFloat { CGFloat(layout().height) }
}
