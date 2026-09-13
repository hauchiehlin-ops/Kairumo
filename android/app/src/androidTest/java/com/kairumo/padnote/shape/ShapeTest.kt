package com.kairumo.padnote.shape

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.FfiShapeKind
import uniffi.padnote_core.PadnoteSession
import uniffi.padnote_core.allShapeKinds
import uniffi.padnote_core.flowchartShapeKinds
import uniffi.padnote_core.flowchartTemplates
import java.io.File

/**
 * Android 的形狀與流程圖（與 Apple 端同一組規則）。
 *
 * 幾何來自核心，所以這裡不重驗菱形長什麼樣。驗的是平台這一邊會不會接錯：
 * 種類用名稱存（不是列舉序號）、連線端點落在邊界上、形狀關掉 App 之後還在。
 *
 * 對照 `apple/Tests/NoteShapeTests.swift`。
 */
@RunWith(AndroidJUnit4::class)
class ShapeTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    private fun session(name: String): Pair<PadnoteSession, String> {
        val dir = File(context.cacheDir, "shape-$name-${System.nanoTime()}")
        val s = PadnoteSession.create(dir.absolutePath, "形狀", 1_757_635_200_000uL, 0xF4u)
        return s to s.firstPageId()!!
    }

    private fun shape(kind: String = "process") =
        NoteShape(kindName = kind, x = 100f, y = 200f, width = 160f, height = 80f)

    // ── 種類的身分 ──────────────────────────────────────────

    @Test
    fun kindIsStoredByNameNotByOrdinal() {
        // 序號會隨核心新增種類而位移 —— 存序號的話，舊筆記裡的「判斷」
        // 有一天會變成「資料」，而且不會有任何錯誤訊息。
        assertEquals(FfiShapeKind.DECISION, shape("decision").kind)
        assertEquals("decision", NoteShape.nameOf(FfiShapeKind.DECISION))
    }

    @Test
    fun everyCoreKindRoundTripsThroughItsName() {
        for (kind in allShapeKinds()) {
            assertEquals("$kind 的名稱對不回去", kind, NoteShape.kindOf(NoteShape.nameOf(kind)))
        }
    }

    @Test
    fun anUnknownNameFallsBackToAPlainBox() {
        // 退回方框是最無害的選擇：使用者至少看得到一個形狀，而不是一片空白。
        assertEquals(FfiShapeKind.PROCESS, shape("未來才有的形狀").kind)
    }

    // ── 幾何來自核心 ────────────────────────────────────────

    @Test
    fun theOutlineComesFromTheCore() {
        assertTrue(shape().outline().size > 2)
    }

    @Test
    fun theOutlineStaysInsideTheBounds() {
        val item = shape("decision")
        for (point in item.outline()) {
            assertTrue(point.x >= item.x - 0.01f)
            assertTrue(point.x <= item.x + item.width + 0.01f)
            assertTrue(point.y >= item.y - 0.01f)
            assertTrue(point.y <= item.y + item.height + 0.01f)
        }
    }

    @Test
    fun everyKindDrawsSomething() {
        // 新增種類時最容易發生的事，是忘了接上 —— 形狀會靜靜地空白。
        for (kind in allShapeKinds()) {
            val item = NoteShape(kindName = NoteShape.nameOf(kind), width = 120f, height = 60f)
            assertTrue("$kind 畫不出東西", item.outline().size > 1)
        }
    }

    @Test
    fun flowchartSymbolsCarryTheirMeaning() {
        // 語意直接顯示給使用者 —— 沒有人記得哪個符號代表什麼。
        assertNotNull(shape("decision").semantic)
    }

    @Test
    fun shapesThatCannotHoldTextAreMarked() {
        // 讓使用者把字打進一條線裡，那些字永遠不會出現。
        assertTrue(shape("process").acceptsText)
        assertFalse(shape("line").acceptsText)
    }

    // ── 連接線 ──────────────────────────────────────────────

    @Test
    fun aConnectionEndsOnTheShapeBoundaries() {
        // 端點落在「大概的邊」的話，線會穿進形狀裡或浮在外面。
        val from = NoteShape(x = 0f, y = 0f, width = 100f, height = 60f)
        val to = NoteShape(x = 300f, y = 0f, width = 100f, height = 60f)
        val geometry = ShapeGeometry.connection(from, to)!!

        assertTrue(geometry.path.size >= 2)
        assertTrue("起點跑到來源形狀外面了", geometry.path.first().x <= 100.01f)
        assertTrue("終點沒有接到目標形狀", geometry.path.last().x >= 299.99f)
    }

    @Test
    fun aConnectionHasAnArrowHead() {
        // 沒有箭頭的流程圖看不出方向。
        val from = NoteShape(x = 0f, y = 0f, width = 100f, height = 60f)
        val to = NoteShape(x = 300f, y = 0f, width = 100f, height = 60f)
        assertTrue(ShapeGeometry.connection(from, to)!!.arrowHead.size >= 3)
    }

    @Test
    fun connectionsBetweenDifferentKindsStillWork() {
        for (kind in flowchartShapeKinds()) {
            val from = NoteShape(
                kindName = NoteShape.nameOf(kind), x = 0f, y = 0f, width = 100f, height = 60f)
            val to = NoteShape(x = 300f, y = 0f, width = 100f, height = 60f)
            assertNotNull("$kind 連不起來", ShapeGeometry.connection(from, to))
        }
    }

    // ── 範本 ────────────────────────────────────────────────

    @Test
    fun everyTemplateHasNodesAndEdges() {
        // 只有節點的話，使用者得自己一條一條連 —— 那範本就沒有意義了。
        assertTrue(flowchartTemplates().isNotEmpty())
        for (template in flowchartTemplates()) {
            assertTrue("${template.id} 沒有節點", template.nodes.isNotEmpty())
            assertTrue("${template.id} 沒有連線", template.edges.isNotEmpty())
        }
    }

    // ── 持久化 ──────────────────────────────────────────────

    @Test
    fun aShapeSurvivesTheNotebook() {
        // 只活在記憶體裡的話，關掉 App 形狀就沒了 ——
        // 那是使用者第一天就會遇到的事。
        val (s, page) = session("roundtrip")
        val created = ShapeStore(s, page).create(
            shape("decision").apply { label = "要不要繼續？" })

        val reopened = ShapeStore(s, page).apply { load() }
        assertEquals(1, reopened.all.size)
        val restored = reopened.all[0]
        assertEquals(created.id, restored.id)
        assertEquals(FfiShapeKind.DECISION, restored.kind)
        assertEquals("要不要繼續？", restored.label)
        assertEquals(100f, restored.x, 0.5f)
        assertEquals(160f, restored.width, 0.5f)
    }

    @Test
    fun movingAShapeKeepsItsIdentity() {
        // 搬動時重新插入的話會換一個 id，連著它的連接線就會指向不存在的物件。
        val (s, page) = session("move")
        val store = ShapeStore(s, page)
        val created = store.create(shape())

        store.persist(created.copyShape().apply { x = 300f; y = 400f })

        val reopened = ShapeStore(s, page).apply { load() }
        assertEquals(created.id, reopened.all[0].id)
        assertEquals(300f, reopened.all[0].x, 0.5f)
    }

    @Test
    fun aShapeCanBeRemoved() {
        // 插得進去卻刪不掉的話，使用者插錯一個就永遠留在那裡。
        val (s, page) = session("remove")
        val store = ShapeStore(s, page)
        val created = store.create(shape())
        store.remove(created)

        assertTrue(ShapeStore(s, page).apply { load() }.all.isEmpty())
    }

    @Test
    fun aShapeWithoutASessionStillWorksInMemory() {
        val store = ShapeStore(null, null)
        assertEquals("process", store.create(shape()).kindName)
        assertEquals(1, store.all.size)
    }

    @Test
    fun aStrokeObjectIsNotLoadedAsAShape() {
        // 認錯的話，一組筆畫會被當成形狀畫出來。
        val (s, page) = session("not-a-shape")
        s.createStrokeObject(page, emptyList())

        assertTrue(ShapeStore(s, page).apply { load() }.all.isEmpty())
    }
}
