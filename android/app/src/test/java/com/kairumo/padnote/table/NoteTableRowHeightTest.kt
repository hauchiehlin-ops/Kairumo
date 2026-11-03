package com.kairumo.padnote.table

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * 手動列高的資料面（不需要核心）：存檔鍵與增刪列時陣列對齊。
 * 版面套用的部分在 instrumented `TableTest`（要載入核心）。
 */
class NoteTableRowHeightTest {
    private fun table() = NoteTable(rows = 3, cols = 2).apply {
        rowHeightOverrides = mutableListOf(25.5, 25.5, 51.0)
    }

    @Test
    fun rowHeightsSurviveTheJsonRoundTrip() {
        val restored = NoteTable.decode(table().encodedJson())!!
        assertEquals(listOf(25.5, 25.5, 51.0), restored.rowHeightOverrides)
    }

    /** Apple `TableAppearance` 寫的是 `rowHeights`；Apple 套件檔欄位名是 `rowHeightOverrides`。兩個都要認得。 */
    @Test
    fun readsBothAppleKeys() {
        val a = NoteTable.decode("""{"rows":2,"cols":1,"rowHeights":[30,40]}""")!!
        val b = NoteTable.decode("""{"rows":2,"cols":1,"rowHeightOverrides":[30,40]}""")!!
        assertEquals(listOf(30.0, 40.0), a.rowHeightOverrides)
        assertEquals(listOf(30.0, 40.0), b.rowHeightOverrides)
    }

    @Test
    fun anOldFileWithoutTheKeyStaysAuto() {
        assertNull(NoteTable.decode("""{"rows":2,"cols":1}""")!!.rowHeightOverrides)
        assertNull(NoteTable.decode(NoteTable(rows = 2, cols = 1).encodedJson())!!.rowHeightOverrides)
    }

    @Test
    fun insertedRowInheritsTheNeighbourHeight() {
        val t = table()
        t.insertRow(1)
        assertEquals(listOf(25.5, 25.5, 25.5, 51.0), t.rowHeightOverrides)
        t.insertRow(t.rows)
        assertEquals(51.0, t.rowHeightOverrides!!.last(), 0.0)
    }

    @Test
    fun deletingAndResizingKeepOneHeightPerRow() {
        val t = table()
        t.deleteRow(0)
        assertEquals(listOf(25.5, 51.0), t.rowHeightOverrides)
        t.resizeGrid(4, 2)
        assertEquals(listOf(25.5, 51.0, 0.0, 0.0), t.rowHeightOverrides)
        assertEquals(t.rows, t.rowHeightOverrides!!.size)
    }
}
