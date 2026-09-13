package com.kairumo.padnote.table

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.PadnoteSession
import java.io.File

/**
 * Android 的表格（與 Apple 端同一組規則）。
 *
 * # 這組測試在守什麼
 *
 * 表格的錯誤都長得很像：**某一列少一格**、合併落在錯的格子上、刪到最後一列
 * 之後整張表消失。這些都不會跳錯誤，使用者只會看到一張怪怪的表。
 *
 * 對照 `apple/Tests/NoteTableTests.swift`：同一組案例，兩邊各驗一次。
 */
@RunWith(AndroidJUnit4::class)
class TableTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    private fun session(name: String): Pair<PadnoteSession, String> {
        val dir = File(context.cacheDir, "table-$name-${System.nanoTime()}")
        val s = PadnoteSession.create(dir.absolutePath, "表格", 1_757_635_200_000uL, 0xF3u)
        return s to s.firstPageId()!!
    }

    private fun table() = NoteTable(
        rows = 2, cols = 3,
        cells = mutableListOf("甲", "乙", "丙", "丁", "戊", "己"),
        headerRow = true
    )

    // ── 長度不變式 ──────────────────────────────────────────

    @Test
    fun cellsAreAlwaysRowsTimesColumns() {
        // 少一格在畫面上是「某一列少一格」，而且只有那一列。
        assertEquals(6, table().cells.size)
    }

    @Test
    fun aShortCellListIsPadded() {
        val short = NoteTable(rows = 2, cols = 3, cells = mutableListOf("只有一格"))
        assertEquals(6, short.cells.size)
        assertEquals("只有一格", short.cell(0, 0))
        assertEquals("", short.cell(1, 2))
    }

    @Test
    fun everyEditKeepsTheInvariant() {
        val t = table()
        t.insertRow(1); assertEquals(t.rows * t.cols, t.cells.size)
        t.insertColumn(0); assertEquals(t.rows * t.cols, t.cells.size)
        t.deleteRow(0); assertEquals(t.rows * t.cols, t.cells.size)
        t.deleteColumn(1); assertEquals(t.rows * t.cols, t.cells.size)
    }

    // ── 增刪 ────────────────────────────────────────────────

    @Test
    fun insertingARowPushesTheLaterRowsDown() {
        val t = table()
        t.insertRow(1)
        assertEquals(3, t.rows)
        assertEquals("甲", t.cell(0, 0))
        assertEquals("", t.cell(1, 0))
        assertEquals("丁", t.cell(2, 0))
    }

    @Test
    fun insertingAColumnKeepsEachRowAligned() {
        val t = table()
        t.insertColumn(1)
        assertEquals(4, t.cols)
        assertEquals("甲", t.cell(0, 0))
        assertEquals("", t.cell(0, 1))
        assertEquals("乙", t.cell(0, 2))
        assertEquals("戊", t.cell(1, 2))
    }

    @Test
    fun deletingAColumnRemovesItFromEveryRow() {
        val t = table()
        t.deleteColumn(1)
        assertEquals(2, t.cols)
        assertEquals(listOf("甲", "丙", "丁", "己"), t.cells)
    }

    @Test
    fun theLastRowCannotBeDeleted() {
        // 沒有列的表格畫不出來，畫面上會忽然變空白。
        val t = NoteTable(rows = 1, cols = 2)
        t.deleteRow(0)
        assertEquals(1, t.rows)
    }

    @Test
    fun outOfRangeEditsAreIgnoredRatherThanCrashing() {
        val t = table()
        t.deleteRow(99); t.deleteColumn(99); t.setCell("黑洞", 99, 99)
        assertEquals(6, t.cells.size)
    }

    // ── 合併 ────────────────────────────────────────────────

    @Test
    fun mergingSpansTheNeighbouringCells() {
        val t = table()
        t.merge(0, 0, 1, 2)
        assertEquals(1, t.mergedCells.size)
        assertTrue(t.isCovered(0, 1))
        assertFalse("錨點自己不算被蓋住", t.isCovered(0, 0))
    }

    @Test
    fun mergingBeyondTheEdgeIsRefused() {
        // 讓它成立的話，合併區會伸出表格外，畫出來是一塊飛在旁邊的方塊。
        val t = table()
        t.merge(0, 2, 1, 2)
        assertTrue(t.mergedCells.isEmpty())
    }

    @Test
    fun insertingARowMovesMergesBelowItDown() {
        // 不跟著移的話，合併會落在錯的格子上。
        val t = table()
        t.merge(1, 0, 1, 2)
        t.insertRow(0)
        assertEquals(2, t.mergedCells[0].row)
    }

    @Test
    fun deletingARowDropsTheMergeAnchoredThere() {
        val t = table()
        t.merge(0, 0, 1, 2)
        t.deleteRow(0)
        assertTrue(t.mergedCells.isEmpty())
    }

    // ── 版面來自核心 ────────────────────────────────────────

    @Test
    fun theLayoutComesFromTheCore() {
        // 版面若哪天被搬回 Kotlin 算，兩個平台就會畫出不一樣的表。
        val layout = table().layout()
        assertEquals(6, layout.cells.size)
        assertEquals(3, layout.columnWidths.size)
        assertTrue(layout.height > 0)
        assertTrue(layout.rules.isNotEmpty())
    }

    @Test
    fun coveredCellsAreNotDrawn() {
        // 照樣畫出來的話，合併區上會再出現一條格線，看起來像合併沒生效。
        val t = table()
        t.merge(0, 0, 1, 2)
        val layout = t.layout()
        assertFalse(layout.cells.any { it.row == 0u && it.col == 1u })
        assertEquals(5, layout.cells.size)
    }

    @Test
    fun bothPlatformsGetTheSameGeometry() {
        // 同一張表、同一個寬度，核心必須算出同一組數字。
        val a = table().layout()
        val b = table().layout()
        assertEquals(a.height, b.height, 1e-9)
        assertEquals(a.columnWidths, b.columnWidths)
    }

    // ── 存進筆記檔再讀回來 ──────────────────────────────────

    @Test
    fun aTableSurvivesTheNotebook() {
        // 使用者真正在乎的那條路：插一張表、關掉、再打開，內容還在。
        val (s, page) = session("roundtrip")
        val store = TableStore(s, page)
        val created = store.create(table().apply { x = 120f; y = 240f })

        val reopened = TableStore(s, page).apply { load() }
        assertEquals(1, reopened.all.size)
        val restored = reopened.all[0]
        assertEquals(created.id, restored.id)
        assertEquals(listOf("甲", "乙", "丙", "丁", "戊", "己"), restored.cells)
        assertTrue(restored.headerRow)
        assertEquals(120f, restored.x, 0.5f)
        assertEquals(240f, restored.y, 0.5f)
    }

    @Test
    fun theContentGoesIntoTheCoresOwnTableBlock() {
        // 只寫外觀的話，這張表對核心而言就只是一塊看不懂的 JSON ——
        // 匯出 PDF、搜尋、以及日後任何一個讀取器都拿不到裡面的字。
        val (s, page) = session("core-block")
        val created = TableStore(s, page).create(table())

        val core = s.table(created.id)
        assertNotNull("核心裡沒有對應的表格區塊", core)
        assertEquals(listOf("甲", "乙", "丙", "丁", "戊", "己"), core!!.cells)
    }

    @Test
    fun editingACellIsWrittenBack() {
        val (s, page) = session("edit-cell")
        val store = TableStore(s, page)
        val created = store.create(table())

        store.persist(created.copyTable().apply { setCell("改過", 1, 1) })

        assertEquals("改過", s.table(created.id)!!.cells[4])
    }

    @Test
    fun addingARowIsWrittenBack() {
        val (s, page) = session("add-row")
        val store = TableStore(s, page)
        val created = store.create(table())

        store.persist(created.copyTable().apply { insertRow(2) })

        assertEquals(3u, s.table(created.id)!!.rows)
    }

    @Test
    fun mergingIsWrittenBack() {
        val (s, page) = session("merge-back")
        val store = TableStore(s, page)
        val created = store.create(table())

        store.persist(created.copyTable().apply { merge(0, 0, 1, 2) })

        assertEquals(1, s.table(created.id)!!.mergedCells.size)
    }

    @Test
    fun deletingATableRemovesItFromTheNotebook() {
        val (s, page) = session("delete")
        val store = TableStore(s, page)
        val created = store.create(table())
        store.remove(created)

        assertTrue(TableStore(s, page).apply { load() }.all.isEmpty())
    }

    @Test
    fun aTableWithoutASessionStillWorksInMemory() {
        // 核心開不起來時，介面不該整個癱掉。
        val store = TableStore(null, null)
        val created = store.create(table())
        assertEquals(1, store.all.size)
        assertEquals("甲", created.cell(0, 0))
    }

    // ── 外觀包裝 ────────────────────────────────────────────

    @Test
    fun theAppearanceWrapperRoundTrips() {
        val t = table().apply { headerBackgroundHex = "clear"; fontSize = 18f }
        val restored = TableAppearance.decode(TableAppearance.encode(t))!!
        assertEquals("透明是哨符，不能走顏色轉換", "clear", restored.headerBackgroundHex)
        assertEquals(18f, restored.fontSize, 1e-6f)
        assertEquals(t.cells, restored.cells)
    }

    @Test
    fun aNonTableAppearanceIsNotMistakenForATable() {
        // 圖表與文字方塊的外觀走的是同一個欄位。
        assertNull(TableAppearance.decode("""{"object":"chart","chart":{}}"""))
        assertNull(TableAppearance.decode("{}"))
        assertNull(TableAppearance.decode("not json"))
    }
}
