package com.kairumo.padnote.ink

import android.view.InputDevice
import android.view.MotionEvent
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.FfiPoint
import uniffi.padnote_core.FfiSheetStroke

/**
 * 圖學：圖層、線型、吸附、改圖層、整組插入的復原。
 *
 * 全部走真正的 `InkEngine.onMotionEvent`（合成的 MotionEvent）—— 跟使用者落筆走同一條路。
 */
@RunWith(AndroidJUnit4::class)
class DraftingEngineTest {

    @Before
    fun setUp() {
        val ctx = InstrumentationRegistry.getInstrumentation().targetContext
        DraftingState.attach(ctx)
        // 每個測試各用一本「筆記」，顯示／鎖定的狀態才不會互相污染。
        DraftingState.use("draft-test-${System.nanoTime()}")
    }

    private fun touch(action: Int, x: Float, y: Float, timeMs: Long): MotionEvent {
        val props = MotionEvent.PointerProperties().apply { id = 0; toolType = MotionEvent.TOOL_TYPE_STYLUS }
        val coords = MotionEvent.PointerCoords().apply { this.x = x; this.y = y; pressure = 0.6f; touchMajor = 4f }
        return MotionEvent.obtain(
            0L, timeMs, action, 1, arrayOf(props), arrayOf(coords), 0, 0, 1f, 1f, 0, 0,
            InputDevice.SOURCE_STYLUS, 0
        )
    }

    private fun stroke(engine: InkEngine, from: Pair<Float, Float>, to: Pair<Float, Float>, holdMs: Long = 0, t0: Long = 1_000) {
        val steps = 8
        var t = t0
        engine.onMotionEvent(touch(MotionEvent.ACTION_DOWN, from.first, from.second, t), 1f)
        for (i in 1..steps) {
            t += 10
            val x = from.first + (to.first - from.first) * i / steps
            val y = from.second + (to.second - from.second) * i / steps
            engine.onMotionEvent(touch(MotionEvent.ACTION_MOVE, x, y, t), 1f)
        }
        if (holdMs > 0) {
            t += holdMs
            engine.onMotionEvent(touch(MotionEvent.ACTION_MOVE, to.first, to.second, t), 1f)
        }
        engine.onMotionEvent(touch(MotionEvent.ACTION_UP, to.first, to.second, t + 10), 1f)
    }

    @Test
    fun aStrokeCarriesTheLayerAndLineTypeItWasDrawnWith() {
        val engine = InkEngine().apply { layer = 3; lineType = 1 }
        stroke(engine, 20f to 100f, 200f to 100f)
        assertEquals(1, engine.strokes.size)
        assertEquals(3, engine.strokes[0].layer)
        assertEquals(1, engine.strokes[0].lineType)
    }

    @Test
    fun drawingOnALockedLayerIsRefused() {
        DraftingState.setLocked(3, true)
        val engine = InkEngine().apply { layer = 3 }
        stroke(engine, 20f to 100f, 200f to 100f)
        assertEquals("鎖住的圖層不收筆畫", 0, engine.strokes.size)
    }

    @Test
    fun drawingOnAHiddenLayerShowsItAgain() {
        DraftingState.setHidden(2, true)
        val engine = InkEngine().apply { layer = 2 }
        stroke(engine, 20f to 100f, 200f to 100f)
        assertEquals(1, engine.strokes.size)
        assertFalse("畫在隱藏的圖層上就把它顯示出來，不然畫了卻什麼都沒有", DraftingState.isHidden(2))
    }

    @Test
    fun holdingAtTheEndSnapsACrookedLineStraight() {
        val engine = InkEngine().apply { snapStepDeg = 90f; layer = 3 }
        stroke(engine, 20f to 100f, 220f to 112f, holdMs = 700)
        val ys = engine.strokes.single().points.map { it.y }.toSet()
        assertEquals("鎖 90° 之後是水平線", 1, ys.map { (it * 10).toInt() }.toSet().size)
        // 沒停留就不吸附。
        val free = InkEngine().apply { snapStepDeg = 90f; layer = 3 }
        stroke(free, 20f to 100f, 220f to 112f, holdMs = 0)
        assertTrue(free.strokes.single().points.map { it.y }.toSet().size > 1)
    }

    @Test
    fun snappingReportsWhichShapeItBecame() {
        val engine = InkEngine().apply { snapStepDeg = 15f }
        var kind: uniffi.padnote_core.FfiDraftSnapKind? = null
        engine.onSnapped = { kind = it }
        stroke(engine, 20f to 100f, 220f to 104f, holdMs = 700)
        assertEquals(uniffi.padnote_core.FfiDraftSnapKind.LINE, kind)
    }

    @Test
    fun reassignModeMovesTheStrokeUnderTheFingerToTheTargetLayer() {
        val engine = InkEngine().apply { layer = 3 }
        stroke(engine, 20f to 100f, 220f to 100f)
        engine.layer = 0
        engine.reassignTarget = 2
        // 點在線上（取樣點之間的位置，驗證用的是點到線段的距離）。
        engine.onMotionEvent(touch(MotionEvent.ACTION_DOWN, 123f, 102f, 5_000), 1f)
        engine.onMotionEvent(touch(MotionEvent.ACTION_UP, 123f, 102f, 5_010), 1f)
        assertEquals(1, engine.strokes.size)
        assertEquals(2, engine.strokes[0].layer)
        assertEquals("顏色與線型不動", 0, engine.strokes[0].lineType)
    }

    @Test
    fun hiddenLayersAreLeftOutOfThePdfExportAndLayersSurviveReopen() {
        val dir = java.io.File(
            InstrumentationRegistry.getInstrumentation().targetContext.cacheDir, "draft-export-${System.nanoTime()}"
        ).apply { mkdirs() }
        val path = java.io.File(dir, "d.padnote").absolutePath
        val session = uniffi.padnote_core.PadnoteSession.create(path, "圖學", 1_757_635_200_000uL, 0xA7u)
        val page = session.firstPageId()!!
        val engine = InkEngine(session, page)
        for ((i, layer) in listOf(2, 3).withIndex()) {
            engine.layer = layer
            engine.lineType = if (layer == 3) 1 else 0
            stroke(engine, 20f to 100f + i * 60, 220f to 100f + i * 60, t0 = 1_000L + i * 5_000)
        }
        assertEquals(2, engine.strokes.size)
        val both = session.exportPagePdf(page).size
        session.setExportHiddenLayers(byteArrayOf(2))
        val topOnly = session.exportPagePdf(page).size
        assertTrue("隱藏中層之後 PDF 少一筆（$both → $topOnly）", topOnly < both)
        session.setExportHiddenLayers(byteArrayOf())
        // 圖層與線型寫進檔案，重開還在。
        val reopened = uniffi.padnote_core.PadnoteSession.openExisting(path, 0xB7u)
        val details = reopened.visibleStrokeDetails(page)
        assertEquals(setOf(2 to 0, 3 to 1), details.map { it.layer.toInt() to it.lineType.toInt() }.toSet())
    }

    @Test
    fun reassigningALayerUndoesAndRedoesInOrder() {
        val engine = InkEngine().apply { layer = 3 }
        stroke(engine, 20f to 100f, 220f to 100f)
        engine.layer = 0
        engine.reassignTarget = 2
        engine.onMotionEvent(touch(MotionEvent.ACTION_DOWN, 100f, 100f, 5_000), 1f)
        engine.onMotionEvent(touch(MotionEvent.ACTION_UP, 100f, 100f, 5_010), 1f)
        assertEquals(2, engine.strokes[0].layer)
        assertTrue(engine.undo())
        assertEquals("先復原改圖層，不是整筆", 1, engine.strokes.size)
        assertEquals(3, engine.strokes[0].layer)
        assertTrue(engine.redo())
        assertEquals(2, engine.strokes[0].layer)
        assertTrue(engine.undo())
        assertTrue("再復原才是那一筆", engine.undo())
        assertEquals(0, engine.strokes.size)
        assertTrue(engine.redo())
        assertEquals(1, engine.strokes.size)
        assertEquals(3, engine.strokes[0].layer)
    }

    @Test
    fun erasingLeavesLockedLayersAloneButReassigningCanMoveTheirLines() {
        val engine = InkEngine().apply { layer = 3 }
        stroke(engine, 20f to 100f, 220f to 100f)
        DraftingState.setLocked(3, true)
        engine.layer = 0
        // 鎖定只擋「擦」與「畫」。
        engine.isErasing = true
        engine.baseWidth = 20f
        engine.onMotionEvent(touch(MotionEvent.ACTION_DOWN, 100f, 100f, 6_000), 1f)
        engine.onMotionEvent(touch(MotionEvent.ACTION_MOVE, 110f, 100f, 6_010), 1f)
        assertEquals("鎖定的圖層擦不到", 1, engine.strokes.size)
        // 改圖層本身就是搬動：使用者要把線搬出鎖定的圖層，所以不受鎖定限制。
        engine.isErasing = false
        engine.reassignTarget = 1
        engine.onMotionEvent(touch(MotionEvent.ACTION_DOWN, 100f, 100f, 5_000), 1f)
        assertEquals("鎖定圖層裡的線也要能搬到別的圖層", 1, engine.strokes[0].layer)
    }

    @Test
    fun anInsertedGroupUndoesAndRedoesAsOneAction() {
        val engine = InkEngine()
        val items = listOf(
            FfiSheetStroke(listOf(FfiPoint(0f, 0f), FfiPoint(100f, 0f)), 3u, 0u, 2.6f, "#111827"),
            FfiSheetStroke(listOf(FfiPoint(0f, 0f), FfiPoint(0f, 50f)), 3u, 1u, 1.4f, "#111827"),
            FfiSheetStroke(listOf(FfiPoint(10f, 10f), FfiPoint(60f, 10f)), 2u, 0u, 1.0f, "#3B82F6")
        )
        stroke(engine, 20f to 300f, 220f to 300f) // 一筆別的東西
        assertEquals(3, engine.insertDrafted(items, 40f, 60f))
        assertEquals(4, engine.strokes.size)
        // 補點到每 4 個單位：100 長的線 ≥ 25 點。
        assertTrue(engine.strokes[1].points.size >= 25)
        assertEquals(40f, engine.strokes[1].points.first().x, 0.01f)
        assertEquals(60f, engine.strokes[1].points.first().y, 0.01f)

        assertTrue(engine.undo())
        assertEquals("一次復原整組", 1, engine.strokes.size)
        assertTrue(engine.redo())
        assertEquals("一次重做整組", 4, engine.strokes.size)
        assertEquals(setOf(0, 3, 2), engine.strokes.map { it.layer }.toSet())
        assertEquals(setOf(0, 1), engine.strokes.map { it.lineType }.toSet())
        // 再復原一次還是整組。
        assertTrue(engine.undo())
        assertEquals(1, engine.strokes.size)
    }

    @Test
    fun stepNumbersAreOneUndoableGroupOnTheAuxLayer() {
        val engine = InkEngine()
        engine.insertDrafted(uniffi.padnote_core.draftStepMarker(3u, 100f, 100f, 15f), 0f, 0f)
        assertTrue(engine.strokes.size >= 2)
        assertTrue(engine.strokes.all { it.layer == 2 })
        assertEquals(1, engine.strokes.map { it.group }.toSet().size)
        engine.undo()
        assertEquals(0, engine.strokes.size)
    }

    @Test
    fun sketchPolylinesSkipTheConstructionLayer() {
        val engine = InkEngine()
        engine.insertDrafted(uniffi.padnote_core.draftStepMarker(1u, 50f, 50f, 15f), 0f, 0f)
        assertTrue("步驟編號的小圓圈不該被當成輪廓", engine.sketchPolylines().isEmpty())
        engine.layer = 1
        stroke(engine, 20f to 100f, 220f to 100f)
        assertEquals(1, engine.sketchPolylines().size)
    }

    @Test
    fun hiddenLayersAreDroppedAndTheRestDrawBottomUp() {
        val order = DraftingState.drawOrder(listOf(3, 0, 1, 2)) { it }
        assertEquals(listOf(0, 1, 2, 3), order)
        DraftingState.setHidden(2, true)
        assertEquals(listOf(0, 1, 3), DraftingState.drawOrder(listOf(3, 0, 1, 2)) { it })
        DraftingState.setHidden(2, false)
    }

    @Test
    fun draftingPensAndLayersComeFromTheCore() {
        assertEquals(setOf("thick", "thin", "hidden", "center", "phantom", "aux", "given"), DraftingState.pens.map { it.id }.toSet())
        assertEquals(listOf(1, 2, 3), DraftingState.layers.map { it.id.toInt() })
        DraftingState.selectPen("hidden")
        assertEquals(1, DraftingState.activeLineType)
        assertEquals(3, DraftingState.activeLayerId)
        DraftingState.toggleTarget(2)
        assertEquals(2, DraftingState.activeLayerId)
        assertNotEquals("#111827", DraftingState.activeColorHex)
        DraftingState.selectPen("thick")
        assertEquals("換筆回到跟著筆走的圖層", 0, DraftingState.layerOverride)
    }
}
