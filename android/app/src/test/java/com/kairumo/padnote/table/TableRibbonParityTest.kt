package com.kairumo.padnote.table

import com.kairumo.padnote.canvas.CanvasRotation
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Android 表格功能區／「表格內容」與 Apple 對齊（I6）：每一顆按鈕背後的模型動作。
 * 需要核心算版面的（distributeRows 預設值、alignedX 預設寬度）改傳明確的值測。
 */
class TableRibbonParityTest {

    @Test
    fun updateStyleCoversTheRangeAndCollapsesBackToNull() {
        val t = NoteTable(rows = 2, cols = 2)
        t.updateStyle(0..0, 0..1) { it.copy(fillHex = "#FF0000") }
        assertEquals("#FF0000", t.style(0, 1).fillHex)
        assertNull(t.style(1, 0).fillHex)
        t.updateStyle(0..1, 0..1) { NoteTableCellStyle.DEFAULT }
        assertNull("全部回到預設就不留陣列", t.cellStyles)
    }

    @Test
    fun cellRangeIsTheWholeMergedSpan() {
        val t = NoteTable(rows = 3, cols = 3).apply { merge(0, 0, 2, 2) }
        assertEquals((0..1) to (0..1), t.cellRange(1, 1))
        assertEquals((2..2) to (2..2), t.cellRange(2, 2))
    }

    @Test
    fun columnAndRowOverridesFollowAppleSemantics() {
        val t = NoteTable(rows = 2, cols = 3)
        t.setColumnWidth(80.0, 1)
        assertEquals(listOf(0.0, 80.0, 0.0), t.columnWidthOverrides)
        t.setColumnWidth(null, 1)
        assertNull("全自動就收回 null", t.columnWidthOverrides)
        t.setRowHeight(40.0, 0)
        assertEquals(listOf(40.0, 0.0), t.rowHeightOverrides)
        t.autoFitSizes()
        assertNull(t.rowHeightOverrides)
    }

    @Test
    fun distributeFillsTheWidthAndUsesTheTallestRow() {
        val t = NoteTable(rows = 3, cols = 4, width = 400f)
        t.distributeColumns()
        assertEquals(List(4) { 100.0 }, t.columnWidthOverrides)
        t.distributeRows(listOf(30.0, 52.0, 30.0))
        assertEquals(List(3) { 52.0 }, t.rowHeightOverrides)
    }

    @Test
    fun preferredWidthScalesManualColumns() {
        val plain = NoteTable(rows = 1, cols = 2, width = 300f)
        plain.setPreferredWidth(500f) { error("沒有手動欄寬時不必算版面") }
        assertEquals(500f, plain.width, 0.001f)

        val manual = NoteTable(rows = 1, cols = 2, width = 300f).apply { columnWidthOverrides = mutableListOf(100.0, 200.0) }
        manual.setPreferredWidth(600f) { listOf(100.0, 200.0) }
        assertEquals(listOf(200.0, 400.0), manual.columnWidthOverrides)
        assertEquals(600f, manual.width, 0.001f)
    }

    @Test
    fun alignedXMatchesApple() {
        val t = NoteTable(rows = 1, cols = 1)
        assertNull("沒設定對齊就不動", t.alignedX(600f, 24f, 200f))
        t.alignment = "center"
        assertEquals(200f, t.alignedX(600f, 24f, 200f)!!, 0.001f)
        t.alignment = "right"
        assertEquals(376f, t.alignedX(600f, 24f, 200f)!!, 0.001f)
        t.alignment = "left"; t.indentLeft = 10f
        assertEquals(34f, t.alignedX(600f, 24f, 200f)!!, 0.001f)
    }

    @Test
    fun newAppearanceKeysRoundTripAsTypedFieldsNotExtras() {
        val t = NoteTable(rows = 1, cols = 1).apply {
            alignment = "center"; indentLeft = 12f; altTitle = "成績"; altDescription = "期中考"
        }
        val back = NoteTable.decode(t.encodedJson())!!
        assertEquals("center", back.alignment)
        assertEquals(12f, back.indentLeft!!, 0.001f)
        assertEquals("成績", back.altTitle)
        assertEquals("期中考", back.altDescription)
        assertNull("認得的鍵不再落進 extras", back.appearanceExtras)
        // Apple 寫的同名鍵讀得到。
        val apple = NoteTable.decode("""{"rows":1,"cols":1,"alignment":"right","altTitle":"A"}""")!!
        assertEquals("right", apple.alignment)
        assertEquals("A", JSONObject(apple.encodedJson()).getString("altTitle"))
    }

    @Test
    fun insertAboveAndLeftPushTheFocusWithTheOriginalCell() {
        val t = NoteTable(rows = 2, cols = 2)
        t.setCell("x", 1, 1)
        val f = TableRibbonActions.insertRowAbove(t, 1 to 1)
        assertEquals(3, t.rows)
        assertEquals(2 to 1, f)
        assertEquals("x", t.cell(2, 1))
        val g = TableRibbonActions.insertColumnLeft(t, f)
        assertEquals(2 to 2, g)
        assertEquals("x", t.cell(2, 2))
        assertNull("沒有焦點時不回報焦點", TableRibbonActions.insertRowAbove(t, null))
    }

    @Test
    fun insertAndDeleteWithoutFocusUseTheEdges() {
        val t = NoteTable(rows = 2, cols = 2)
        t.setCell("last", 1, 1)
        TableRibbonActions.insertRowBelow(t, null)
        assertEquals("last", t.cell(1, 1))
        TableRibbonActions.deleteRow(t, null)
        assertEquals(2, t.rows)
        TableRibbonActions.deleteColumn(t, 0 to 0)
        assertEquals("last", t.cell(1, 0))
    }

    @Test
    fun nineGridAlignsTheFocusedRangeOrTheWholeTable() {
        val t = NoteTable(rows = 2, cols = 2)
        TableRibbonActions.align(t, 0 to 1, "center", "middle")
        assertEquals("center", t.style(0, 1).hAlign)
        assertEquals("middle", t.style(0, 1).vAlign)
        assertNull(t.style(1, 1).hAlign)
        TableRibbonActions.align(t, null, "left", "top")
        assertNull("靠左寫 null", t.style(0, 1).hAlign)
        assertEquals("top", t.style(1, 1).vAlign)
    }

    @Test
    fun shadingTargetsTheFocusedCellOrTheHeader() {
        val t = NoteTable(rows = 2, cols = 2)
        TableRibbonActions.shade(t, null, "#FFF2CC")
        assertEquals("#FFF2CC", t.headerBackgroundHex)
        assertNull(t.cellStyles)
        TableRibbonActions.shade(t, 1 to 0, "#E2EFDA")
        assertEquals("#E2EFDA", t.style(1, 0).fillHex)
    }

    @Test
    fun galleryAppliesHeaderTextAndAlternateFill() {
        val t = NoteTable(rows = 4, cols = 2, headerRow = false)
        TableRibbonActions.applyGallery(t, TABLE_GALLERY[1])
        assertTrue(t.headerRow)
        assertEquals(true, t.bandedRows)
        assertEquals("#2B579A", t.headerBackgroundHex)
        assertEquals("#FFFFFF", t.style(0, 0).textColorHex)
        assertEquals("#F2F7FF", t.style(1, 1).fillHex)
        assertNull(t.style(2, 0).fillHex)
        assertEquals("#F2F7FF", t.style(3, 0).fillHex)
    }

    @Test
    fun borderWidthStepsAndResetsToNullAtOne() {
        assertEquals(1.5f, stepBorderWidth(1f, 0.5f))
        assertNull(stepBorderWidth(1.5f, -0.5f))
        assertEquals(0.5f, stepBorderWidth(0.5f, -0.5f))
        assertEquals(6f, stepBorderWidth(6f, 0.5f))
    }

    @Test
    fun tableTabLabelSubstitutesRowsAndColumns() {
        assertEquals("表格 (3 × 4)", tableTabLabel("表格 (%1@ × %2@)", 3, 4))
        assertFalse(tableTabLabel("Table (%1@ × %2@)", 1, 2).contains("%"))
    }

    @Test
    fun rotationAngleIsMeasuredFromStraightUp() {
        // 把手在正上方 = 0°，正右方 = 90°，正下方 = 180°，正左方 = 270°。
        assertEquals(0f, CanvasRotation.angleOf(0f, -50f, 0f, 0f), 0.01f)
        assertEquals(90f, CanvasRotation.angleOf(50f, 0f, 0f, 0f), 0.01f)
        assertEquals(180f, CanvasRotation.angleOf(0f, 50f, 0f, 0f), 0.01f)
        assertEquals(270f, CanvasRotation.angleOf(-50f, 0f, 0f, 0f), 0.01f)
    }

    @Test
    fun selectedObjectHandlesAreNotStolenByCanvasPan() {
        // 100×40 的物件在 (100,100)：中心 (150,120)，旋轉把手在中心上方 max(40,40)/2+52 = 72 點。
        val frame = com.kairumo.padnote.canvas.MarqueeHit("t", 100f, 100f, 100f, 40f)
        val within = com.kairumo.padnote.canvas.ObjectMarquee::withinSelectionChrome
        assertTrue("旋轉把手", within(androidx.compose.ui.geometry.Offset(150f, 48f), frame))
        assertTrue("右下縮放把手", within(androidx.compose.ui.geometry.Offset(205f, 145f), frame))
        assertFalse("遠處空白仍可平移畫布", within(androidx.compose.ui.geometry.Offset(400f, 400f), frame))
    }
}
