package com.kairumo.padnote.table

import org.json.JSONObject
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import uniffi.padnote_core.FfiTableCell
import uniffi.padnote_core.FfiTableLayout
import uniffi.padnote_core.FfiTableRule

/**
 * Apple 寫的表格外觀鍵在 Android 上解析、增刪列欄時對齊、以及版面解析（框線過濾、欄寬覆寫、
 * 底色來源）與 Apple `TableLayoutResolver` / `fillRole` 一致。
 *
 * 版面解析用手造的核心版面與假量測，不需要載入核心。
 */
class NoteTableAppearanceTest {

    private val appleJson = """{"id":"t1","rows":2,"cols":2,"cells":["a","b","c","d"],
        "borderMode":"outer","borderWidth":2.5,"borderStyle":"dashed",
        "bandedRows":true,"bandedCols":false,"columnWidths":[120,0],
        "cellStyles":[{"bold":true,"fillHex":"#FF0000"},{},{"hAlign":"center","vAlign":"middle"},{"italic":true,"textColorHex":"#00FF00"}],
        "altTitle":"成績表"}"""

    // MARK: - 解析與寫回

    @Test
    fun appleKeysBecomeTypedFields() {
        val t = NoteTable.decode(appleJson)!!
        assertEquals("outer", t.borderMode)
        assertEquals(TableBorderMode.OUTER, t.resolvedBorderMode)
        assertEquals(2.5f, t.borderWidth!!, 0.0001f)
        assertEquals(TableBorderStyle.DASHED, t.resolvedBorderStyle)
        assertEquals(true, t.bandedRows)
        assertEquals(false, t.bandedCols)
        assertEquals(listOf(120.0, 0.0), t.columnWidthOverrides)
        assertEquals(NoteTableCellStyle(bold = true, fillHex = "#FF0000"), t.style(0, 0))
        assertEquals("center", t.style(1, 0).hAlign)
        assertEquals("middle", t.style(1, 0).vAlign)
        assertEquals(true, t.style(1, 1).italic)
        // 替代文字現在也是具型別欄位（表格內容 › 替代文字可編）；已解析的鍵不再重複放在 extras。
        assertEquals("成績表", t.altTitle)
        val extras = t.appearanceExtras?.let { JSONObject(it) } ?: JSONObject()
        assertTrue(!extras.has("altTitle") && !extras.has("borderMode") && !extras.has("cellStyles") && !extras.has("columnWidths"))
    }

    @Test
    fun roundTripWritesTheSameKeysAppleWrites() {
        val out = JSONObject(NoteTable.decode(appleJson)!!.encodedJson())
        assertEquals("outer", out.getString("borderMode"))
        assertEquals(2.5, out.getDouble("borderWidth"), 0.0001)
        assertEquals("dashed", out.getString("borderStyle"))
        assertTrue(out.getBoolean("bandedRows"))
        assertEquals(2, out.getJSONArray("columnWidths").length())
        val styles = out.getJSONArray("cellStyles")
        assertEquals(4, styles.length())
        // 預設格式寫成空物件（與 Apple Codable 省略 nil 相同），不寫出 null 值。
        assertEquals(0, styles.getJSONObject(1).length())
        assertEquals("成績表", out.getString("altTitle"))
    }

    @Test
    fun anOldTableWritesNoNewKeys() {
        val out = JSONObject(NoteTable(rows = 2, cols = 2).encodedJson())
        for (key in listOf("borderMode", "borderWidth", "borderStyle", "bandedRows", "bandedCols", "columnWidths", "cellStyles")) {
            assertTrue("舊表格不應多出 $key", !out.has(key))
        }
    }

    @Test
    fun cellStylesOfTheWrongLengthAreIgnored() {
        val t = NoteTable.decode("""{"rows":2,"cols":2,"cellStyles":[{"bold":true}]}""")!!
        assertNull(t.cellStyles)
    }

    @Test
    fun unknownBorderValuesFallBackButSurvive() {
        val t = NoteTable.decode("""{"rows":1,"cols":1,"borderMode":"diagonal","borderStyle":"wavy"}""")!!
        assertEquals(TableBorderMode.ALL, t.resolvedBorderMode)
        assertEquals(TableBorderStyle.SOLID, t.resolvedBorderStyle)
        val out = JSONObject(t.encodedJson())
        assertEquals("diagonal", out.getString("borderMode"))
        assertEquals("wavy", out.getString("borderStyle"))
    }

    // MARK: - 增刪列欄

    private fun styled(rows: Int, cols: Int) = NoteTable(rows = rows, cols = cols).apply {
        cellStyles = MutableList(rows * cols) { NoteTableCellStyle(fontSize = it.toDouble() + 10) }
        columnWidthOverrides = MutableList(cols) { (it + 1) * 50.0 }
    }

    @Test
    fun insertRowKeepsStylesOnTheirCells() {
        val t = styled(2, 2)
        t.insertRow(1)
        assertEquals(6, t.cellStyles!!.size)
        assertEquals(10.0, t.style(0, 0).fontSize)
        assertTrue(t.style(1, 0).isDefault)
        assertTrue(t.style(1, 1).isDefault)
        assertEquals(12.0, t.style(2, 0).fontSize)
        assertEquals(13.0, t.style(2, 1).fontSize)
    }

    @Test
    fun deleteRowRemovesThatRowsStyles() {
        val t = styled(3, 2)
        t.deleteRow(1)
        assertEquals(4, t.cellStyles!!.size)
        assertEquals(10.0, t.style(0, 0).fontSize)
        assertEquals(14.0, t.style(1, 0).fontSize)
        assertEquals(15.0, t.style(1, 1).fontSize)
    }

    @Test
    fun insertColumnShiftsStylesAndWidths() {
        val t = styled(2, 2)
        t.insertColumn(1)
        assertEquals(6, t.cellStyles!!.size)
        assertEquals(10.0, t.style(0, 0).fontSize)
        assertTrue(t.style(0, 1).isDefault)
        assertEquals(11.0, t.style(0, 2).fontSize)
        assertEquals(12.0, t.style(1, 0).fontSize)
        assertTrue(t.style(1, 1).isDefault)
        assertEquals(13.0, t.style(1, 2).fontSize)
        assertEquals(listOf(50.0, 0.0, 100.0), t.columnWidthOverrides)
    }

    @Test
    fun deleteColumnRemovesStylesAndWidth() {
        val t = styled(2, 3)
        t.deleteColumn(1)
        assertEquals(4, t.cellStyles!!.size)
        assertEquals(10.0, t.style(0, 0).fontSize)
        assertEquals(12.0, t.style(0, 1).fontSize)
        assertEquals(13.0, t.style(1, 0).fontSize)
        assertEquals(15.0, t.style(1, 1).fontSize)
        assertEquals(listOf(50.0, 150.0), t.columnWidthOverrides)
    }

    @Test
    fun resizeGridKeepsTheOverlap() {
        val t = styled(2, 2)
        t.resizeGrid(3, 1)
        assertEquals(3, t.cellStyles!!.size)
        assertEquals(10.0, t.style(0, 0).fontSize)
        assertEquals(12.0, t.style(1, 0).fontSize)
        assertTrue(t.style(2, 0).isDefault)
        assertEquals(listOf(50.0), t.columnWidthOverrides)
    }

    // MARK: - 框線、底色

    @Test
    fun dashPatternMatchesAppleProportions() {
        assertArrayEquals(floatArrayOf(), TableBorderStyle.SOLID.dashPattern(2f), 0f)
        assertArrayEquals(floatArrayOf(8f, 4f), TableBorderStyle.DASHED.dashPattern(2f), 0f)
        assertArrayEquals(floatArrayOf(2f, 3f), TableBorderStyle.DOTTED.dashPattern(2f), 0f)
        // 線寬下限 0.5（與 Apple 相同）。
        assertArrayEquals(floatArrayOf(2f, 1f), TableBorderStyle.DASHED.dashPattern(0f), 0f)
    }

    @Test
    fun fillRolePriorityMatchesApple() {
        val t = NoteTable(rows = 3, cols = 3).apply {
            bandedRows = true
            bandedCols = true
            cellStyles = MutableList(9) { NoteTableCellStyle.DEFAULT }.also {
                it[4] = NoteTableCellStyle(fillHex = "clear")
            }
        }
        assertEquals(TableCellFillRole.Header, t.fillRole(0, 1, isHeader = true))
        assertEquals(TableCellFillRole.Own("clear"), t.fillRole(1, 1, isHeader = false))
        assertEquals(TableCellFillRole.BandedRow, t.fillRole(1, 0, isHeader = false))
        assertEquals(TableCellFillRole.BandedColumn, t.fillRole(2, 1, isHeader = false))
        assertNull(t.fillRole(2, 0, isHeader = false))
        assertEquals(1f, t.resolvedBorderWidth, 0f)
    }

    // MARK: - 版面解析

    /** 2×2、寬 200、列高 30 的核心版面：外框四條 + 中間一橫一直，每條橫跨整張表。 */
    private fun core(): FfiTableLayout {
        fun cell(r: Int, c: Int) = FfiTableCell(
            row = r.toUInt(), col = c.toUInt(), rowSpan = 1u, colSpan = 1u,
            x = c * 100.0, y = r * 30.0, width = 100.0, height = 30.0,
            lines = listOf("core"), isHeader = r == 0
        )
        val rules = listOf(0.0, 30.0, 60.0).map { FfiTableRule(0.0, it, 200.0, it) } +
            listOf(0.0, 100.0, 200.0).map { FfiTableRule(it, 0.0, it, 60.0) }
        return FfiTableLayout(
            width = 200.0, height = 60.0,
            cells = listOf(cell(0, 0), cell(0, 1), cell(1, 0), cell(1, 1)),
            rules = rules, columnWidths = listOf(100.0, 100.0), rowHeights = listOf(30.0, 30.0)
        )
    }

    private val noMeasure = NoteTable.CellMeasurer { _, _, _ -> error("不該量測") }

    private fun table(mode: String? = null) =
        NoteTable(rows = 2, cols = 2, width = 200f, cells = mutableListOf("a", "b", "c", "d")).apply { borderMode = mode }

    @Test
    fun withoutAppearanceTheLayoutIsTheCoreLayout() {
        val c = core()
        assertEquals(c, table().resolveLayout(c, noMeasure))
    }

    @Test
    fun borderModeFiltersRules() {
        fun count(mode: String?) = table(mode).resolveLayout(core(), noMeasure).rules.size
        assertEquals(6, count(null))
        assertEquals(6, count("all"))
        assertEquals(4, count("outer"))
        assertEquals(2, count("inner"))
        assertEquals(3, count("horizontal"))
        assertEquals(0, count("none"))
        val inner = table("inner").resolveLayout(core(), noMeasure).rules
        assertTrue(inner.contains(FfiTableRule(0.0, 30.0, 200.0, 30.0)))
        assertTrue(inner.contains(FfiTableRule(100.0, 0.0, 100.0, 60.0)))
    }

    @Test
    fun columnWidthOverrideMovesEdgesAndRemeasuresRows() {
        val t = table().apply { columnWidthOverrides = mutableListOf(150.0, 10.0) }
        val widths = mutableListOf<Double>()
        val l = t.resolveLayout(core(), NoteTable.CellMeasurer { text, w, _ ->
            widths.add(w)
            listOf(text, text) to if (text == "c") 50.0 else 20.0
        })
        // 10 < 24 視為自動（沿用核心的 100），但仍算「有欄寬覆寫」→ 列高全部重量。
        assertEquals(listOf(150.0, 100.0), l.columnWidths)
        assertEquals(250.0, l.width, 0.0)
        assertEquals(listOf(150.0, 100.0, 150.0, 100.0), widths)
        // 第 0 列實測 20 低於核心最矮列 30 → 30；第 1 列 50。
        assertEquals(listOf(30.0, 50.0), l.rowHeights)
        assertEquals(80.0, l.height, 0.0)
        val d = l.cells.first { it.row == 1u && it.col == 1u }
        assertEquals(150.0, d.x, 0.0)
        assertEquals(30.0, d.y, 0.0)
        assertEquals(50.0, d.height, 0.0)
        assertEquals(listOf("d", "d"), d.lines)
        // 中間的直線跟著欄邊界移到 150，並延伸到新的總高。
        assertTrue(l.rules.contains(FfiTableRule(150.0, 0.0, 150.0, 80.0)))
        assertTrue(l.rules.contains(FfiTableRule(0.0, 80.0, 250.0, 80.0)))
    }

    @Test
    fun manualRowHeightStillWinsOverMeasuredHeight() {
        val t = table().apply {
            cellStyles = MutableList(4) { NoteTableCellStyle.DEFAULT }.also { it[2] = NoteTableCellStyle(fontSize = 30.0) }
            rowHeightOverrides = mutableListOf(0.0, 40.0)
        }
        val l = t.resolveLayout(core(), NoteTable.CellMeasurer { text, _, size ->
            assertEquals(30.0, size, 0.0)
            listOf(text) to 90.0
        })
        assertEquals(listOf(30.0, 40.0), l.rowHeights)
    }

    @Test
    fun fontStyleOnlyGrowsItsRow() {
        val t = table().apply {
            cellStyles = MutableList(4) { NoteTableCellStyle.DEFAULT }.also { it[3] = NoteTableCellStyle(fontSize = 28.0) }
        }
        val l = t.resolveLayout(core(), NoteTable.CellMeasurer { text, w, _ ->
            assertEquals(100.0, w, 0.0)
            listOf(text) to 45.0
        })
        assertEquals(listOf(30.0, 45.0), l.rowHeights)
        assertEquals(listOf("core"), l.cells.first { it.row == 0u && it.col == 0u }.lines)
        assertEquals(listOf("d"), l.cells.first { it.row == 1u && it.col == 1u }.lines)
    }

    @Test
    fun noWrapMeasuresWithoutAWidthLimit() {
        val t = table().apply {
            cellStyles = MutableList(4) { NoteTableCellStyle.DEFAULT }.also { it[0] = NoteTableCellStyle(wrap = false) }
        }
        var measuredWidth = 0.0
        t.resolveLayout(core(), NoteTable.CellMeasurer { text, w, _ ->
            measuredWidth = w
            listOf(text) to 20.0
        })
        assertTrue(measuredWidth > 10_000)
    }

    @Test
    fun dataClassCopyKeepsAppearance() {
        val t = NoteTable.decode(appleJson)!!
        val c = t.copy(id = "other")
        assertSame(t.cellStyles, c.cellStyles)
        assertEquals(t.borderStyle, c.borderStyle)
    }
}
