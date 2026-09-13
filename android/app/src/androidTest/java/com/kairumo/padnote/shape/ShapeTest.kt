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

    // ── 連接線（流程圖跨得過平台的關鍵）────────────────────

    @Test
    fun aConnectionSurvivesTheNotebook() {
        // 連接線沒存進核心的話，另一台裝置看到的是一堆沒有線連起來的方塊。
        val (s, page) = session("connection-roundtrip")
        val store = ShapeStore(s, page)
        val from = store.create(shape("terminator").apply { label = "開始" })
        val to = store.create(shape("process").apply { x = 300f; label = "處理" })
        store.connect(from, to, "是")

        val reopened = ShapeStore(s, page).apply { load() }
        assertEquals(2, reopened.all.size)
        assertEquals(1, reopened.allConnections.size)
        val link = reopened.allConnections[0]
        assertEquals("是", link.label)
        assertEquals(from.id, link.fromShapeId)
        assertEquals(to.id, link.toShapeId)
    }

    @Test
    fun connectionEndpointsPointAtShapesThatExist() {
        // 端點用平台自己生的 id 的話，線會連到不存在的物件上 ——
        // 畫面上是一條從空氣連出來的線。
        val (s, page) = session("connection-endpoints")
        val store = ShapeStore(s, page)
        val from = store.create(shape())
        val to = store.create(shape().apply { x = 300f })
        store.connect(from, to)

        val reopened = ShapeStore(s, page).apply { load() }
        val ids = reopened.all.map { it.id }.toSet()
        for (link in reopened.allConnections) {
            assertTrue("起點指向不存在的形狀", ids.contains(link.fromShapeId))
            assertTrue("終點指向不存在的形狀", ids.contains(link.toShapeId))
        }
    }

    @Test
    fun deletingAShapeAlsoRemovesItsConnections() {
        // 留著的話會指向一個不存在的形狀，畫面上是一條從空氣連出來的線。
        val (s, page) = session("connection-cascade")
        val store = ShapeStore(s, page)
        val from = store.create(shape())
        val to = store.create(shape().apply { x = 300f })
        store.connect(from, to)

        store.remove(from)

        val reopened = ShapeStore(s, page).apply { load() }
        assertTrue("形狀刪掉了，連著它的線還在", reopened.allConnections.isEmpty())
        assertEquals(1, reopened.all.size)
    }

    @Test
    fun aRestoredConnectionStillDrawsItsPath() {
        // 「讀得回來」還不夠 —— 讀回來的東西要真的畫得出線。
        val (s, page) = session("connection-draws")
        val store = ShapeStore(s, page)
        val from = store.create(shape())
        val to = store.create(shape().apply { x = 300f })
        store.connect(from, to)

        val reopened = ShapeStore(s, page).apply { load() }
        val link = reopened.allConnections[0]
        val a = reopened.all.first { it.id == link.fromShapeId }
        val b = reopened.all.first { it.id == link.toShapeId }

        val geometry = ShapeGeometry.connection(a, b)
        assertNotNull("讀回來的形狀畫不出連接線", geometry)
        assertTrue(geometry!!.arrowHead.size >= 3)
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

/**
 * 形狀的堆疊順序與群組（Android）。
 *
 * # 這組測試在守什麼
 *
 * 順序的錯誤不會跳例外，只會讓畫面上的東西**疊錯**：該在上面的跑到下面、
 * 群組裡的成員被別的東西夾在中間。那種錯只有測試抓得到。
 *
 * 規則與 Apple 的 `ObjectLayerOps` 一字不差 —— 同一組案例兩邊各驗一次，
 * 不然「同一個操作在兩個平台結果不同」只有使用者會發現。
 */
@RunWith(AndroidJUnit4::class)
class ObjectLayerTest {

    private fun shapes(vararg ids: String): List<NoteShape> =
        ids.map { NoteShape(id = it, label = it) }

    private fun order(shapes: List<NoteShape>) = shapes.map { it.id }

    // ── 堆疊順序 ────────────────────────────────────────────

    @Test
    fun bringToFrontPutsItOnTop() {
        assertEquals(
            listOf("b", "c", "a"),
            order(ObjectLayer.bringToFront("a", shapes("a", "b", "c")))
        )
    }

    @Test
    fun sendToBackPutsItAtTheBottom() {
        assertEquals(
            listOf("c", "a", "b"),
            order(ObjectLayer.sendToBack("c", shapes("a", "b", "c")))
        )
    }

    @Test
    fun bringForwardMovesOneStepOnly() {
        // 一次跳兩層的話，使用者要按幾次才對得準就沒人知道了。
        assertEquals(
            listOf("b", "a", "c"),
            order(ObjectLayer.bringForward("a", shapes("a", "b", "c")))
        )
    }

    @Test
    fun sendBackwardMovesOneStepOnly() {
        assertEquals(
            listOf("a", "c", "b"),
            order(ObjectLayer.sendBackward("c", shapes("a", "b", "c")))
        )
    }

    @Test
    fun movingBeyondTheEdgeDoesNothing() {
        // 夾住而不是繞回去：已經在最上層還按「上移」，東西不該跑到最底下。
        val items = shapes("a", "b")
        assertEquals(listOf("a", "b"), order(ObjectLayer.bringForward("b", items)))
        assertEquals(listOf("a", "b"), order(ObjectLayer.sendBackward("a", items)))
    }

    @Test
    fun movingAnUnknownIdChangesNothing() {
        assertEquals(listOf("a", "b"), order(ObjectLayer.bringToFront("不存在", shapes("a", "b"))))
    }

    @Test
    fun reorderingKeepsEveryShape() {
        // 少一個就是畫面上有東西不見了。
        var items = shapes("a", "b", "c", "d")
        items = ObjectLayer.bringToFront("b", items)
        items = ObjectLayer.sendToBack("d", items)
        items = ObjectLayer.bringForward("a", items)
        assertEquals(setOf("a", "b", "c", "d"), order(items).toSet())
        assertEquals(4, items.size)
    }

    // ── 群組 ────────────────────────────────────────────────

    @Test
    fun groupingMarksEveryMember() {
        val (items, groupId) = ObjectLayer.group(setOf("a", "c"), shapes("a", "b", "c"))
        assertNotNull(groupId)
        assertEquals(groupId, items.first { it.id == "a" }.groupId)
        assertEquals(groupId, items.first { it.id == "c" }.groupId)
        assertNull("沒選到的不該被拉進群組", items.first { it.id == "b" }.groupId)
    }

    @Test
    fun groupingASingleShapeIsRefused() {
        // 一個物件的「群組」沒有意義，解散之後使用者會發現什麼也沒變，
        // 只會覺得按鈕壞了。
        val (items, groupId) = ObjectLayer.group(setOf("a"), shapes("a", "b"))
        assertNull(groupId)
        assertNull(items[0].groupId)
    }

    @Test
    fun ungroupingReleasesEveryMemberButKeepsThem() {
        // 解散群組不是刪除 —— 成員要留在原地。
        val (grouped, groupId) = ObjectLayer.group(setOf("a", "b"), shapes("a", "b"))
        val released = ObjectLayer.ungroup(groupId!!, grouped)
        assertTrue(released.all { it.groupId == null })
        assertEquals(listOf("a", "b"), order(released))
    }

    @Test
    fun groupMatesIncludeEveryMember() {
        // 選到群組裡的一個，整組都要一起動 —— 那正是群組的意義。
        val (items, _) = ObjectLayer.group(setOf("a", "b"), shapes("a", "b", "c"))
        assertEquals(setOf("a", "b"), ObjectLayer.groupMates("a", items))
    }

    @Test
    fun anUngroupedShapeIsItsOwnMate() {
        assertEquals(setOf("a"), ObjectLayer.groupMates("a", shapes("a", "b")))
    }

    // ── 面板的列 ────────────────────────────────────────────

    @Test
    fun rowsAreListedFrontToBack() {
        // 面板由上到下＝由前到後，那是圖層面板的慣例。反過來的話，
        // 使用者每按一次「上移」都要在腦中翻譯一次。
        val rows = ObjectLayer.rows(shapes("底", "中", "頂"), "未命名") { "群組 $it" }
        assertEquals(listOf("頂", "中", "底"), rows.map { it.label })
    }

    @Test
    fun aGroupCollapsesIntoOneRow() {
        // 一個群組在面板上是一列，不是散開的成員。
        val (items, _) = ObjectLayer.group(setOf("a", "b"), shapes("a", "b", "c"))
        val rows = ObjectLayer.rows(items, "未命名") { "群組 $it" }
        assertEquals(2, rows.size)
        assertEquals(1, rows.count { it.isGroup })
        assertEquals(2, rows.first { it.isGroup }.memberCount)
    }

    @Test
    fun anUnnamedShapeGetsAPlaceholderLabel() {
        // 空字串在清單裡是一列看不出是什麼的空白。
        val rows = ObjectLayer.rows(listOf(NoteShape(id = "a", label = "")), "未命名") { "群組 $it" }
        assertEquals("未命名", rows[0].label)
    }

    // ── 存回核心 ────────────────────────────────────────────

    @Test
    fun reorderingIsWrittenBackToTheCore() {
        // 只改記憶體的話，關掉 App 順序就跑回去了。
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val dir = File(context.cacheDir, "layer-order-${System.nanoTime()}")
        val s = PadnoteSession.create(dir.absolutePath, "圖層", 1_757_635_200_000uL, 0xF5u)
        val page = s.firstPageId()!!
        val store = ShapeStore(s, page)

        val bottom = store.create(NoteShape(kindName = "process", label = "底"))
        val top = store.create(NoteShape(kindName = "process", label = "頂", x = 300f))
        store.replaceAll(ObjectLayer.bringToFront(bottom.id, store.all))

        val reopened = ShapeStore(s, page).apply { load() }
        assertEquals(listOf(top.id, bottom.id), reopened.all.map { it.id })
    }

    @Test
    fun groupingIsWrittenBackToTheCore() {
        // 群組是核心物件樹裡真正的節點 —— 沒寫回去的話，
        // 換一台裝置打開群組就散了。
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val dir = File(context.cacheDir, "layer-group-${System.nanoTime()}")
        val s = PadnoteSession.create(dir.absolutePath, "圖層", 1_757_635_200_000uL, 0xF6u)
        val page = s.firstPageId()!!
        val store = ShapeStore(s, page)

        val a = store.create(NoteShape(kindName = "process", label = "甲"))
        val b = store.create(NoteShape(kindName = "process", label = "乙", x = 300f))
        val (grouped, _) = ObjectLayer.group(setOf(a.id, b.id), store.all)
        store.replaceAll(grouped)

        // 群組之後，根層只剩那個 Group 節點。
        val roots = s.rootObjects(page)
        assertEquals(1, roots.size)
        assertEquals(uniffi.padnote_core.FfiObjectKind.GROUP, roots[0].kind)
        assertEquals(setOf(a.id, b.id), roots[0].members.toSet())
    }
}
