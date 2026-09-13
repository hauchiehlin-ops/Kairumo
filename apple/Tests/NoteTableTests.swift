//
//  NoteTableTests.swift
//  KairumoTests
//
//  畫布表格的資料模型。
//
//  # 這組測試在守什麼
//
//  表格的錯誤都長得很像：**某一列少一格**、合併落在錯的格子上、刪到最後一列
//  之後整張表消失。這些都不會跳錯誤，使用者只會看到一張怪怪的表。
//
//  版面本身由核心負責（`padnote-table` 有 17 條測試），這裡驗的是平台這一邊
//  的編輯操作，以及「版面真的來自核心」。
//

import XCTest
@testable import Kairumo

final class NoteTableTests: XCTestCase {

    private func table() -> NoteTableAttachment {
        NoteTableAttachment(
            rows: 2, cols: 3,
            cells: ["甲", "乙", "丙", "丁", "戊", "己"],
            headerRow: true
        )
    }

    // MARK: - 長度不變式

    func testCellsAreAlwaysRowsTimesColumns() {
        // 少一格在畫面上是「某一列少一格」，而且只有那一列。
        XCTAssertEqual(table().cells.count, 6)
    }

    func testAShortCellListIsPadded() {
        let short = NoteTableAttachment(rows: 2, cols: 3, cells: ["只有一格"])
        XCTAssertEqual(short.cells.count, 6)
        XCTAssertEqual(short.cell(row: 0, col: 0), "只有一格")
        XCTAssertEqual(short.cell(row: 1, col: 2), "")
    }

    func testALongCellListIsTruncated() {
        let long = NoteTableAttachment(
            rows: 1, cols: 2, cells: ["a", "b", "多出來的", "更多"])
        XCTAssertEqual(long.cells, ["a", "b"])
    }

    func testEveryEditKeepsTheInvariant() {
        // 每一種增刪之後長度都要對得上 —— 對不上就會有一列畫不出來。
        var item = table()
        item.insertRow(at: 1)
        XCTAssertEqual(item.cells.count, item.rows * item.cols)
        item.insertColumn(at: 0)
        XCTAssertEqual(item.cells.count, item.rows * item.cols)
        item.deleteRow(at: 0)
        XCTAssertEqual(item.cells.count, item.rows * item.cols)
        item.deleteColumn(at: 1)
        XCTAssertEqual(item.cells.count, item.rows * item.cols)
    }

    // MARK: - 增刪

    func testInsertingARowPushesTheLaterRowsDown() {
        var item = table()
        item.insertRow(at: 1)
        XCTAssertEqual(item.rows, 3)
        XCTAssertEqual(item.cell(row: 0, col: 0), "甲")
        XCTAssertEqual(item.cell(row: 1, col: 0), "", "插入的那一列要是空的")
        XCTAssertEqual(item.cell(row: 2, col: 0), "丁", "原本的第二列要往下移")
    }

    func testInsertingAColumnKeepsEachRowAligned() {
        var item = table()
        item.insertColumn(at: 1)
        XCTAssertEqual(item.cols, 4)
        XCTAssertEqual(item.cell(row: 0, col: 0), "甲")
        XCTAssertEqual(item.cell(row: 0, col: 1), "")
        XCTAssertEqual(item.cell(row: 0, col: 2), "乙")
        XCTAssertEqual(item.cell(row: 1, col: 2), "戊", "第二列也要跟著插一格")
    }

    func testDeletingARowRemovesExactlyThatRow() {
        var item = table()
        item.deleteRow(at: 0)
        XCTAssertEqual(item.rows, 1)
        XCTAssertEqual(item.cells, ["丁", "戊", "己"])
    }

    func testDeletingAColumnRemovesItFromEveryRow() {
        var item = table()
        item.deleteColumn(at: 1)
        XCTAssertEqual(item.cols, 2)
        XCTAssertEqual(item.cells, ["甲", "丙", "丁", "己"])
    }

    func testTheLastRowCannotBeDeleted() {
        // 沒有列的表格畫不出來，畫面上會忽然變空白。
        var item = NoteTableAttachment(rows: 1, cols: 2)
        item.deleteRow(at: 0)
        XCTAssertEqual(item.rows, 1)
    }

    func testTheLastColumnCannotBeDeleted() {
        var item = NoteTableAttachment(rows: 2, cols: 1)
        item.deleteColumn(at: 0)
        XCTAssertEqual(item.cols, 1)
    }

    func testOutOfRangeEditsAreIgnoredRatherThanCrashing() {
        var item = table()
        item.deleteRow(at: 99)
        item.deleteColumn(at: 99)
        item.setCell("黑洞", row: 99, col: 99)
        XCTAssertEqual(item.cells.count, 6)
    }

    // MARK: - 合併

    func testMergingSpansTheNeighbouringCells() {
        var item = table()
        item.merge(row: 0, col: 0, rowSpan: 1, colSpan: 2)
        XCTAssertEqual(item.mergedCells.count, 1)
        XCTAssertTrue(item.isCovered(row: 0, col: 1), "被蓋住的格子要認得出來")
        XCTAssertFalse(item.isCovered(row: 0, col: 0), "錨點自己不算被蓋住")
    }

    func testMergingBeyondTheEdgeIsRefused() {
        // 讓它成立的話，合併區會伸出表格外，畫出來就是一塊飛在旁邊的方塊。
        var item = table()
        item.merge(row: 0, col: 2, rowSpan: 1, colSpan: 2)
        XCTAssertTrue(item.mergedCells.isEmpty)
    }

    func testAOneByOneMergeIsRefused() {
        var item = table()
        item.merge(row: 0, col: 0, rowSpan: 1, colSpan: 1)
        XCTAssertTrue(item.mergedCells.isEmpty)
    }

    func testUnmergingReleasesTheCoveredCells() {
        var item = table()
        item.merge(row: 0, col: 0, rowSpan: 1, colSpan: 2)
        item.unmerge(row: 0, col: 0)
        XCTAssertFalse(item.isCovered(row: 0, col: 1))
    }

    func testMergingTheSameAnchorTwiceReplacesRatherThanStacks() {
        var item = table()
        item.merge(row: 0, col: 0, rowSpan: 1, colSpan: 2)
        item.merge(row: 0, col: 0, rowSpan: 1, colSpan: 3)
        XCTAssertEqual(item.mergedCells.count, 1)
        XCTAssertEqual(item.mergedCells[0].colSpan, 3)
    }

    func testInsertingARowMovesMergesBelowItDown() {
        // 不跟著移的話，合併會落在錯的格子上 ——
        // 而且使用者不會知道是插入那一步造成的。
        var item = table()
        item.merge(row: 1, col: 0, rowSpan: 1, colSpan: 2)
        item.insertRow(at: 0)
        XCTAssertEqual(item.mergedCells[0].row, 2)
    }

    func testInsertingAColumnMovesMergesToItsRight() {
        var item = table()
        item.merge(row: 0, col: 1, rowSpan: 1, colSpan: 2)
        item.insertColumn(at: 0)
        XCTAssertEqual(item.mergedCells[0].col, 2)
    }

    func testDeletingARowDropsTheMergeAnchoredThere() {
        var item = table()
        item.merge(row: 0, col: 0, rowSpan: 1, colSpan: 2)
        item.deleteRow(at: 0)
        XCTAssertTrue(item.mergedCells.isEmpty, "錨點被刪掉了，合併不該留著")
    }

    // MARK: - 版面來自核心

    func testTheLayoutComesFromTheCore() {
        // 版面若哪天被搬回 Swift 算，兩個平台就會畫出不一樣的表。
        let layout = table().layout()
        XCTAssertEqual(layout.cells.count, 6)
        XCTAssertEqual(layout.columnWidths.count, 3)
        XCTAssertGreaterThan(layout.height, 0)
        XCTAssertFalse(layout.rules.isEmpty)
    }

    func testTheHeaderRowIsMarkedInTheLayout() {
        let layout = table().layout()
        XCTAssertTrue(layout.cells.filter { $0.row == 0 }.allSatisfy(\.isHeader))
        XCTAssertTrue(layout.cells.filter { $0.row == 1 }.allSatisfy { !$0.isHeader })
    }

    func testCoveredCellsAreNotDrawn() {
        // 照樣畫出來的話，合併區上會再出現一條格線，看起來像合併沒生效。
        var item = table()
        item.merge(row: 0, col: 0, rowSpan: 1, colSpan: 2)
        let layout = item.layout()
        XCTAssertFalse(layout.cells.contains { $0.row == 0 && $0.col == 1 })
        XCTAssertEqual(layout.cells.count, 5)
    }

    func testLongTextMakesTheTableTaller() {
        var short = table()
        short.width = 200
        var long = short
        long.setCell("這是一段很長很長很長的說明文字用來把這一格撐高", row: 1, col: 0)
        XCTAssertGreaterThan(long.height, short.height)
    }

    // MARK: - 持久化

    func testATableSurvivesEncodingAndDecoding() throws {
        var original = table()
        original.merge(row: 0, col: 0, rowSpan: 1, colSpan: 2)
        original.headerBackgroundHex = "clear"
        original.fontSize = 18

        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(NoteTableAttachment.self, from: data)

        XCTAssertEqual(restored.cells, original.cells)
        XCTAssertEqual(restored.mergedCells, original.mergedCells)
        XCTAssertEqual(restored.headerBackgroundHex, "clear", "透明是哨符，不能走顏色轉換")
        XCTAssertEqual(restored.fontSize, 18)
    }

    func testANotebookWithoutTablesStillDecodes() throws {
        // 這個欄位是後來加的。舊筆記裡沒有它，解碼一定要照樣成功。
        let json = #"{"id":"1","title":"舊筆記","createdAt":0,"lastModifiedDate":0,"pageCount":1,"hasRecording":false,"template":"空白紙張","pagesData":[]}"#
        let document = try JSONDecoder().decode(
            NotebookDocument.self, from: XCTUnwrap(json.data(using: .utf8)))
        XCTAssertNil(document.tableAttachments)
    }
}
