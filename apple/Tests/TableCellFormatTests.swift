//
//  TableCellFormatTests.swift
//  KairumoTests
//
//  Office 式表格編修：儲存格格式、手動欄寬列高、框線、範圍合併。
//
//  守的是兩件事：
//  1. **舊檔不變** —— 沒有任何覆寫時，解析後的版面要與核心逐點相同。
//  2. **增刪列欄時，格式與欄寬列高跟著走** —— 不跟著走的話，粗體會跳到隔壁那一格。
//

import XCTest
@testable import Kairumo

final class TableCellFormatTests: XCTestCase {

    private func table() -> NoteTableAttachment {
        NoteTableAttachment(
            rows: 3, cols: 3,
            cells: ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬"],
            headerRow: true)
    }

    func testWithoutOverridesTheResolvedLayoutEqualsTheCore() {
        let item = table()
        let core = item.layout()
        let resolved = item.resolvedLayout()
        XCTAssertEqual(Double(resolved.width), core.width, accuracy: 0.01)
        XCTAssertEqual(Double(resolved.height), core.height, accuracy: 0.01)
        XCTAssertEqual(resolved.cells.count, core.cells.count)
        XCTAssertEqual(resolved.rules.count, core.rules.count)
    }

    func testStyleStaysOnItsCellWhenARowIsInsertedAbove() {
        var item = table()
        item.updateStyle(rows: 1...1, cols: 1...1) { $0.bold = true }
        item.insertRow(at: 0)
        XCTAssertEqual(item.cellStyles?.count, item.rows * item.cols)
        XCTAssertEqual(item.style(row: 2, col: 1).bold, true)
        XCTAssertNil(item.style(row: 1, col: 1).bold)
    }

    /// 貼齊格線的表格（每列都是格線間距的整數倍）插入新列後，新列必須沿用相鄰列高，
    /// 否則新列回到自動高度，之後的每一條橫線都與紙上的線錯開。
    func testInsertedRowInheritsNeighbourHeightOverride() {
        var item = table()
        item.rowHeightOverrides = Array(repeating: 25.5, count: item.rows)
        item.insertRow(at: 1)
        XCTAssertEqual(item.rowHeightOverrides, Array(repeating: 25.5, count: item.rows))
        item.insertRow(at: item.rows)
        XCTAssertEqual(item.rowHeightOverrides?.last, 25.5)
    }

    func testStyleStaysOnItsCellWhenAColumnIsDeletedBefore() {
        var item = table()
        item.updateStyle(rows: 0...0, cols: 2...2) { $0.italic = true }
        item.deleteColumn(at: 0)
        XCTAssertEqual(item.cellStyles?.count, item.rows * item.cols)
        XCTAssertEqual(item.style(row: 0, col: 1).italic, true)
    }

    func testResizingKeepsStylesAndOverridesAligned() {
        var item = table()
        item.updateStyle(rows: 0...0, cols: 0...0) { $0.hAlign = .center }
        item.setColumnWidth(120, at: 2)
        item.resizeGrid(newRows: 4, newCols: 2)
        XCTAssertEqual(item.cellStyles?.count, 8)
        XCTAssertEqual(item.style(row: 0, col: 0).hAlign, .center)
        XCTAssertEqual(item.columnWidthOverrides?.count, 2)
    }

    func testClearingEveryStyleDropsTheArray() {
        var item = table()
        item.updateStyle(rows: 0...0, cols: 0...0) { $0.bold = true }
        XCTAssertNotNil(item.cellStyles)
        item.clearStyles(rows: 0...2, cols: 0...2)
        XCTAssertNil(item.cellStyles)
    }

    func testAColumnOverrideChangesTheResolvedWidth() {
        var item = table()
        let before = item.resolvedLayout().columnWidths[1]
        item.setColumnWidth(Double(before) + 60, at: 1)
        let after = item.resolvedLayout()
        XCTAssertEqual(after.columnWidths[1], before + 60, accuracy: 0.01)
        XCTAssertEqual(after.cells.first { $0.col == 2 }?.x ?? 0,
                       item.resolvedLayout().columnWidths[0] + after.columnWidths[1], accuracy: 0.01)
    }

    func testARowHeightOverrideWins() {
        var item = table()
        item.setRowHeight(90, at: 1)
        XCTAssertEqual(item.resolvedLayout().rowHeights[1], 90, accuracy: 0.01)
    }

    func testDistributeColumnsFillsTheTableWidth() {
        var item = table()
        item.distributeColumns()
        XCTAssertEqual(item.resolvedLayout().width, item.width, accuracy: 0.5)
    }

    func testNoBordersMeansNoRules() {
        var item = table()
        item.borderMode = TableBorderMode.none
        XCTAssertTrue(item.resolvedLayout().rules.isEmpty)
    }

    func testOuterBordersAreFewerThanAll() {
        var item = table()
        let all = item.resolvedLayout().rules.count
        item.borderMode = .outer
        let outer = item.resolvedLayout().rules.count
        XCTAssertGreaterThan(outer, 0)
        XCTAssertLessThan(outer, all)
    }

    func testMergeRangeReplacesOverlappingSpans() {
        var item = table()
        item.merge(row: 0, col: 0, rowSpan: 1, colSpan: 2)
        item.mergeRange(rows: 0...1, cols: 1...2)
        XCTAssertEqual(item.mergedCells.count, 1)
        XCTAssertEqual(item.mergedCells[0].rowSpan, 2)
        XCTAssertEqual(item.mergedCells[0].colSpan, 2)
    }

    func testFormatSurvivesThePackageEncoding() {
        var item = table()
        item.updateStyle(rows: 1...1, cols: 1...1) { $0.textRotation = 90; $0.vAlign = .middle }
        item.borderMode = .horizontal
        item.setRowHeight(60, at: 0)

        let json = TableAppearance.encode(item)
        var restored = table()
        TableAppearance.apply(json, to: &restored)
        XCTAssertEqual(restored.borderMode, .horizontal)
        XCTAssertEqual(restored.style(row: 1, col: 1).textRotation, 90)
        XCTAssertEqual(restored.style(row: 1, col: 1).vAlign, .middle)
        XCTAssertEqual(restored.rowHeightOverrides?.first, 60)
    }

    func testAnOldFileWithoutTheNewKeysStillDecodes() throws {
        let data = try JSONEncoder().encode(table())
        var dict = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["cellStyles", "columnWidthOverrides", "rowHeightOverrides", "borderMode"] {
            dict.removeValue(forKey: key)
        }
        let old = try JSONSerialization.data(withJSONObject: dict)
        let decoded = try JSONDecoder().decode(NoteTableAttachment.self, from: old)
        XCTAssertNil(decoded.cellStyles)
        XCTAssertEqual(decoded.rows, 3)
    }
}
