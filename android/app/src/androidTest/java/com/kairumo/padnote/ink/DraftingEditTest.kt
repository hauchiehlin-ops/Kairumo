package com.kairumo.padnote.ink

import android.view.InputDevice
import android.view.MotionEvent
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.PadnoteSession
import java.io.File
import kotlin.math.hypot

/**
 * 編輯工具（修剪、延伸、圓角、偏移、鏡射、陣列）。走真正的 `InkEngine.onMotionEvent` 與核心工作階段，
 * 驗證結果寫進了檔案、復原與重做把檔案也還原。對應 Apple 的 `DraftingEditUITests`。
 */
@RunWith(AndroidJUnit4::class)
class DraftingEditTest {
    private lateinit var dir: File
    private lateinit var session: PadnoteSession
    private lateinit var pageId: String
    private lateinit var path: String
    private lateinit var engine: InkEngine
    private var clock = 1_000L

    @Before
    fun setUp() {
        val ctx = InstrumentationRegistry.getInstrumentation().targetContext
        DraftingState.attach(ctx)
        DraftingState.use("edit-test-${System.nanoTime()}")
        DraftingState.changeAlign(false)
        DraftingState.selectTool(DraftTool.NONE)
        DraftToolController.reset(null)
        dir = File(ctx.cacheDir, "edit-${System.nanoTime()}").also { it.mkdirs() }
        path = File(dir, "edit.padnote").absolutePath
        session = PadnoteSession.create(path, "編輯", 1_757_635_200_000uL, 0xC0u)
        pageId = session.firstPageId()!!
        engine = InkEngine(session, pageId)
        engine.layer = 3
    }

    @After
    fun tearDown() {
        DraftingState.changeAlign(true)
        DraftingState.selectTool(DraftTool.NONE)
        dir.deleteRecursively()
    }

    private fun touch(action: Int, x: Float, y: Float): MotionEvent {
        val props = MotionEvent.PointerProperties().apply { id = 0; toolType = MotionEvent.TOOL_TYPE_STYLUS }
        val coords = MotionEvent.PointerCoords().apply { this.x = x; this.y = y; pressure = 0.6f; touchMajor = 4f }
        return MotionEvent.obtain(0L, clock, action, 1, arrayOf(props), arrayOf(coords), 0, 0, 1f, 1f, 0, 0,
            InputDevice.SOURCE_STYLUS, 0)
    }

    private fun tap(x: Float, y: Float) {
        engine.onMotionEvent(touch(MotionEvent.ACTION_DOWN, x, y), 1f)
        clock += 30
        engine.onMotionEvent(touch(MotionEvent.ACTION_UP, x, y), 1f)
        clock += 30
    }

    /** 畫一條直線（頂層、製圖筆）。 */
    private fun line(x0: Float, y0: Float, x1: Float, y1: Float) {
        engine.layer = 3
        engine.onMotionEvent(touch(MotionEvent.ACTION_DOWN, x0, y0), 1f)
        for (i in 1..10) {
            clock += 12
            engine.onMotionEvent(touch(MotionEvent.ACTION_MOVE, x0 + (x1 - x0) * i / 10, y0 + (y1 - y0) * i / 10), 1f)
        }
        clock += 12
        engine.onMotionEvent(touch(MotionEvent.ACTION_UP, x1, y1), 1f)
        clock += 40
    }

    private fun use(tool: DraftTool) {
        DraftingState.selectTool(tool)
        DraftToolController.reset(engine)
        engine.onToolTouch = { phase, x, y -> DraftToolController.handle(phase, x, y, engine) }
    }

    private fun persisted() = PadnoteSession.openExisting(path, 0xC1u).visibleStrokeDetails(pageId)

    private fun xs(s: InkEngine.CompletedStroke) = s.points.map { it.x }

    @Test
    fun trimCutsAwayThePartBetweenCrossingsAndUndoesAndRedoes() {
        line(100f, 200f, 500f, 200f)      // 水平線
        line(300f, 100f, 300f, 300f)      // 垂直切割線
        use(DraftTool.TRIM)
        assertNotNull("選了修剪就該有提示", DraftingState.toolHint)
        tap(420f, 200f)                   // 點在垂直線右邊的那一段
        assertEquals(2, engine.strokes.size)
        val horizontal = engine.strokes.first { it.points.all { p -> kotlin.math.abs(p.y - 200f) < 0.5f } }
        assertEquals("水平線在交點 x=300 收掉", 300f, xs(horizontal).max(), 0.6f)
        assertEquals("左邊那一段還在", 100f, xs(horizontal).min(), 0.6f)
        assertEquals("核心也只剩兩筆", 2, persisted().size)

        assertTrue(engine.undo())
        assertEquals(2, engine.strokes.size)
        assertEquals("復原之後水平線又長到 500", 500f,
            engine.strokes.flatMap { s -> xs(s) }.max(), 0.6f)
        assertEquals(2, persisted().size)

        assertTrue(engine.redo())
        assertEquals("重做又剪掉", 300f,
            engine.strokes.filter { s -> s.points.all { kotlin.math.abs(it.y - 200f) < 0.5f } }.flatMap { xs(it) }.max(), 0.6f)
        assertEquals(2, persisted().size)
    }

    @Test
    fun trimTheMiddleLeavesTwoPieces() {
        line(100f, 200f, 500f, 200f)
        line(200f, 100f, 200f, 300f)
        line(400f, 100f, 400f, 300f)
        use(DraftTool.TRIM)
        tap(300f, 200f)
        // 水平線被剪成左右兩段 + 兩條垂直線 = 4 筆。
        assertEquals(4, engine.strokes.size)
        assertTrue(engine.undo())
        assertEquals(3, engine.strokes.size)
    }

    @Test
    fun trimExplainsWhenThereIsNothingToCutAgainst() {
        line(100f, 200f, 500f, 200f)
        use(DraftTool.TRIM)
        tap(300f, 200f)
        assertEquals("沒有交點，什麼都不動", 1, engine.strokes.size)
        assertEquals(com.kairumo.padnote.L10n.t("draft_edit_no_crossing"), DraftingState.toolHint)
        tap(300f, 600f)
        assertEquals(com.kairumo.padnote.L10n.t("draft_edit_nothing"), DraftingState.toolHint)
    }

    @Test
    fun extendRunsTheNearEndToTheNearestLine() {
        line(100f, 200f, 250f, 200f)
        line(400f, 100f, 400f, 300f)
        line(600f, 100f, 600f, 300f)
        use(DraftTool.EXTEND)
        tap(248f, 202f)
        val extended = engine.strokes.first { s -> s.points.all { kotlin.math.abs(it.y - 200f) < 0.5f } }
        assertEquals("延伸到最近的線 x=400", 400f, xs(extended).max(), 0.6f)
        assertEquals(100f, xs(extended).min(), 0.6f)
        assertEquals(3, engine.strokes.size)
        assertTrue(engine.undo())
        assertEquals(250f, engine.strokes.flatMap { xs(it) }.filter { it < 300f }.max(), 0.6f)
        assertEquals(3, persisted().size)
    }

    @Test
    fun filletJoinsTwoLinesWithAnArcAndUndoesAsOne() {
        DraftingState.changeFilletRadius(5.0)
        line(100f, 400f, 300f, 400f)
        line(300f, 400f, 300f, 200f)
        use(DraftTool.FILLET)
        tap(200f, 400f)
        tap(300f, 300f)
        assertEquals("兩條線加一段圓弧", 3, engine.strokes.size)
        val r = 5f * uniffi.padnote_core.draftUnitsPerMm()
        // 圓弧：x 與 y 都有變化（兩條直線一個方向不變）。
        val arc = engine.strokes.single { s ->
            (s.points.maxOf { it.x } - s.points.minOf { it.x }) > 1f && (s.points.maxOf { it.y } - s.points.minOf { it.y }) > 1f
        }
        // 弧上的點離圓心 (300-r, 400-r) 都是 r。
        for (p in arc.points) assertEquals(r, hypot(p.x - (300f - r), p.y - (400f - r)), 0.6f)
        assertEquals(3, persisted().size)
        assertTrue(engine.undo())
        assertEquals("一次復原收回圓弧並還原兩條線", 2, engine.strokes.size)
        assertEquals(300f, engine.strokes.flatMap { xs(it) }.max(), 0.6f)
    }

    @Test
    fun filletRefusesParallelLinesWithAnExplanation() {
        line(100f, 400f, 300f, 400f)
        line(100f, 300f, 300f, 300f)
        use(DraftTool.FILLET)
        tap(200f, 400f)
        tap(200f, 300f)
        assertEquals(2, engine.strokes.size)
        assertEquals(com.kairumo.padnote.L10n.t("draft_edit_fillet_fail"), DraftingState.toolHint)
    }

    @Test
    fun offsetAddsAParallelLineOnTheTappedSide() {
        DraftingState.changeOffsetDistance(5.0)
        line(100f, 300f, 400f, 300f)
        use(DraftTool.OFFSET)
        tap(250f, 300f)          // 選線
        tap(250f, 380f)          // 偏向下側
        assertEquals("原來那條留著、多一條", 2, engine.strokes.size)
        val d = 5f * uniffi.padnote_core.draftUnitsPerMm()
        val copy = engine.strokes.last()
        for (p in copy.points) assertEquals(300f + d, p.y, 0.6f)
        assertEquals(100f, xs(copy).min(), 0.6f)
        assertEquals(2, persisted().size)
        assertTrue(engine.undo())
        assertEquals(1, engine.strokes.size)
    }

    @Test
    fun mirrorCopiesTheSelectedLinesAcrossTheDraggedAxisWithALivePreview() {
        line(100f, 100f, 200f, 100f)
        // 選取：用核心 id（與套索同一條路）。
        DraftingState.editSelection = engine.strokes.mapNotNull { it.coreStrokeId }
        assertEquals(1, DraftingState.editSelection.size)
        use(DraftTool.MIRROR)
        tap(400f, 50f)           // 軸的第一點
        engine.onMotionEvent(touch(MotionEvent.ACTION_DOWN, 400f, 250f), 1f)
        clock += 20
        engine.onMotionEvent(touch(MotionEvent.ACTION_MOVE, 400f, 260f), 1f)
        assertTrue("拖曳中要有預覽", engine.overlayStrokes.isNotEmpty())
        assertEquals("預覽不算內容", 1, engine.strokes.size)
        clock += 20
        engine.onMotionEvent(touch(MotionEvent.ACTION_UP, 400f, 260f), 1f)
        assertEquals("原件留著、多一份鏡射", 2, engine.strokes.size)
        val m = engine.strokes.last()
        assertEquals("鏡射過 x=400：100→700、200→600", 600f, xs(m).min(), 0.8f)
        assertEquals(700f, xs(m).max(), 0.8f)
        assertTrue(engine.overlayStrokes.isEmpty())
        assertEquals(2, persisted().size)
        assertTrue(engine.undo())
        assertEquals(1, engine.strokes.size)
    }

    @Test
    fun mirrorAsksForASelectionFirst() {
        line(100f, 100f, 200f, 100f)
        DraftingState.editSelection = emptyList()
        use(DraftTool.MIRROR)
        tap(400f, 50f)
        assertEquals(1, engine.strokes.size)
        assertEquals(com.kairumo.padnote.L10n.t("draft_edit_need_selection"), DraftingState.toolHint)
    }

    @Test
    fun aRectangularArrayMakesRowsTimesColumnsMinusTheOriginal() {
        line(100f, 100f, 160f, 100f)
        DraftingState.editSelection = engine.strokes.mapNotNull { it.coreStrokeId }
        val n = DraftEditController.applyRectArray(2, 3, 30.0, 20.0, engine)
        assertEquals(5, n)
        assertEquals(6, engine.strokes.size)
        val unit = uniffi.padnote_core.draftUnitsPerMm()
        assertTrue("第三欄第二列", engine.strokes.any { s ->
            kotlin.math.abs(s.points.first().x - (100f + 2 * 30f * unit)) < 0.8f &&
                kotlin.math.abs(s.points.first().y - (100f + 20f * unit)) < 0.8f
        })
        assertEquals(6, persisted().size)
        assertTrue("整個陣列一次復原", engine.undo())
        assertEquals(1, engine.strokes.size)
    }

    @Test
    fun aPolarArraySpreadsCopiesAroundTheTappedCenter() {
        line(400f, 300f, 460f, 300f)
        DraftingState.editSelection = engine.strokes.mapNotNull { it.coreStrokeId }
        DraftingState.polarCount = 4
        DraftingState.polarTotalDeg = 360.0
        use(DraftTool.ARRAY_POLAR)
        tap(300f, 300f)          // 圓心
        assertEquals(4, engine.strokes.size)
        // 轉 180° 的那份：起點 (400,300) → (200,300)。
        assertTrue(engine.strokes.any { s ->
            kotlin.math.abs(s.points.first().x - 200f) < 0.8f && kotlin.math.abs(s.points.first().y - 300f) < 0.8f
        })
        assertEquals(4, persisted().size)
        assertTrue(engine.undo())
        assertEquals(1, engine.strokes.size)
    }

    @Test
    fun editedStrokesKeepThePenLayerAndLineTypeOfTheOriginal() {
        DraftingState.selectTool(DraftTool.NONE)
        engine.layer = 2
        engine.lineType = 1
        engine.onMotionEvent(touch(MotionEvent.ACTION_DOWN, 100f, 200f), 1f)
        for (i in 1..10) {
            clock += 12
            engine.onMotionEvent(touch(MotionEvent.ACTION_MOVE, 100f + 40f * i, 200f), 1f)
        }
        clock += 12
        engine.onMotionEvent(touch(MotionEvent.ACTION_UP, 500f, 200f), 1f)
        clock += 40
        line(300f, 100f, 300f, 300f)
        use(DraftTool.TRIM)
        tap(420f, 200f)
        val cut = engine.strokes.first { s -> s.layer == 2 }
        assertEquals("修剪之後仍是隱藏線", 1, cut.lineType)
        assertEquals(2, cut.layer)
    }
}
