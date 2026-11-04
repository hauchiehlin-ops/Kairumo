package com.kairumo.padnote.table

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 表格編修面板的合併／分割以「目前儲存格」為準，以及 Apple 寫的外觀鍵經過 Android 編輯不會掉。
 * （等比縮放 `scaleTo` 要核心算版面，在 instrumented 測試裡驗。）
 */
class NoteTableEditingWiringTest {

    @Test
    fun mergeRightThenDownGrowsTheSpanFromTheFocusedCell() {
        val t = NoteTable(rows = 3, cols = 3)
        t.mergeRight(1, 1)
        assertEquals(NoteTableSpan(1, 1, 1, 2), t.spanContaining(1, 2))
        t.mergeDown(1, 2)
        assertEquals(NoteTableSpan(1, 1, 2, 2), t.spanContaining(2, 2))
        assertEquals(1, t.mergedCells.size)
    }

    @Test
    fun mergeAtTheEdgeIsRefused() {
        val t = NoteTable(rows = 3, cols = 3)
        t.mergeRight(0, 2)
        t.mergeDown(2, 0)
        assertTrue(t.mergedCells.isEmpty())
    }

    @Test
    fun mergingOverAnotherSpanReplacesItInsteadOfOverlapping() {
        val t = NoteTable(rows = 3, cols = 3)
        t.merge(0, 1, 2, 1)
        t.mergeRight(0, 0)
        assertEquals(listOf(NoteTableSpan(0, 0, 1, 2)), t.mergedCells)
    }

    @Test
    fun splitFromACoveredCellRemovesTheWholeSpan() {
        val t = NoteTable(rows = 3, cols = 3)
        t.merge(0, 0, 2, 2)
        t.splitCell(1, 1)
        assertTrue(t.mergedCells.isEmpty())
    }

    @Test
    fun appleOnlyAppearanceKeysSurviveAnAndroidEdit() {
        val apple = """{"rows":2,"cols":2,"cells":["a","b","c","d"],"borderMode":"outer",
            "borderWidth":2.5,"borderStyle":"dashed","bandedRows":true,"altTitle":"成績表",
            "columnWidths":[100,200]}"""
        val t = NoteTable.decode(apple)!!
        t.setCell("z", 0, 0)
        val out = JSONObject(t.encodedJson())
        assertEquals("outer", out.getString("borderMode"))
        assertEquals(2.5, out.getDouble("borderWidth"), 0.0001)
        assertEquals("dashed", out.getString("borderStyle"))
        assertTrue(out.getBoolean("bandedRows"))
        assertEquals("成績表", out.getString("altTitle"))
        assertEquals("z", out.getJSONArray("cells").getString(0))
        assertEquals(2, out.getJSONArray("columnWidths").length())
    }

    @Test
    fun androidOwnFieldsWinOverStaleExtras() {
        val t = NoteTable.decode("""{"rows":1,"cols":1,"fontSize":14,"borderMode":"none"}""")!!
        t.fontSize = 20f
        val out = JSONObject(t.encodedJson())
        assertEquals(20.0, out.getDouble("fontSize"), 0.0001)
        assertEquals("none", out.getString("borderMode"))
    }

    @Test
    fun gridIndexedExtrasAreDroppedWhenTheGridChanges() {
        val apple = """{"rows":1,"cols":2,"cellStyles":[{},{}],"columnWidths":[50,60],"borderMode":"inner"}"""
        val rowEdit = NoteTable.decode(apple)!!.apply { insertRow(1) }
        val afterRow = JSONObject(rowEdit.encodedJson())
        assertFalse("逐格格式對不上新格子，要丟掉", afterRow.has("cellStyles"))
        assertTrue("欄沒變，欄寬保留", afterRow.has("columnWidths"))
        assertEquals("inner", afterRow.getString("borderMode"))

        val colEdit = NoteTable.decode(apple)!!.apply { insertColumn(1) }
        val afterCol = JSONObject(colEdit.encodedJson())
        assertFalse(afterCol.has("columnWidths"))
        assertFalse(afterCol.has("cellStyles"))
    }

    @Test
    fun aTableWithoutExtrasWritesNoExtras() {
        assertNull(NoteTable(rows = 1, cols = 1).appearanceExtras)
        assertNull(NoteTable.decode(NoteTable(rows = 1, cols = 1).encodedJson())!!.appearanceExtras)
    }
}
