package com.kairumo.padnote.ink

import android.view.InputDevice
import android.view.MotionEvent
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.kairumo.padnote.L10n
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.FfiPhase

/**
 * 圖學工具（標註、符號、圖框、比例尺）。走真正的 `InkEngine.onMotionEvent`，與使用者點下去走同一條路。
 * 對應 Apple 的 `DraftingToolsUITests`。
 */
@RunWith(AndroidJUnit4::class)
class DraftingToolsTest {

    @Before
    fun setUp() {
        val ctx = InstrumentationRegistry.getInstrumentation().targetContext
        DraftingState.attach(ctx)
        DraftingState.use("tools-test-${System.nanoTime()}")
        DraftingState.selectTool(DraftTool.NONE)
        DraftToolController.reset(null)
    }

    private fun touch(action: Int, x: Float, y: Float, timeMs: Long): MotionEvent {
        val props = MotionEvent.PointerProperties().apply { id = 0; toolType = MotionEvent.TOOL_TYPE_STYLUS }
        val coords = MotionEvent.PointerCoords().apply { this.x = x; this.y = y; pressure = 0.6f; touchMajor = 4f }
        return MotionEvent.obtain(
            0L, timeMs, action, 1, arrayOf(props), arrayOf(coords), 0, 0, 1f, 1f, 0, 0,
            InputDevice.SOURCE_STYLUS, 0
        )
    }

    private var clock = 1_000L

    private fun tap(engine: InkEngine, x: Float, y: Float) {
        engine.onMotionEvent(touch(MotionEvent.ACTION_DOWN, x, y, clock), 1f)
        clock += 30
        engine.onMotionEvent(touch(MotionEvent.ACTION_UP, x, y, clock), 1f)
        clock += 30
    }

    private fun drag(engine: InkEngine, from: Pair<Float, Float>, to: Pair<Float, Float>) {
        engine.onMotionEvent(touch(MotionEvent.ACTION_DOWN, from.first, from.second, clock), 1f)
        for (i in 1..6) {
            clock += 15
            engine.onMotionEvent(
                touch(MotionEvent.ACTION_MOVE, from.first + (to.first - from.first) * i / 6,
                    from.second + (to.second - from.second) * i / 6, clock), 1f)
        }
        clock += 15
        engine.onMotionEvent(touch(MotionEvent.ACTION_UP, to.first, to.second, clock), 1f)
        clock += 30
    }

    private fun toolEngine(tool: DraftTool): InkEngine {
        val engine = InkEngine()
        DraftingState.selectTool(tool)
        DraftToolController.reset(engine)
        engine.onToolTouch = { phase, x, y -> DraftToolController.handle(phase, x, y, engine) }
        return engine
    }

    @Test
    fun aLinearDimensionIsTwoTapsAndADragAndUndoesAsOne() {
        val engine = toolEngine(DraftTool.DIM_LINEAR)
        assertNotNull("選了工具就該有提示", DraftingState.toolHint)
        tap(engine, 100f, 200f)
        tap(engine, 300f, 200f)
        assertEquals("兩個點還沒有標註", 0, engine.strokes.size)
        drag(engine, 200f to 240f, 200f to 262f)
        assertTrue("標註的筆畫太少：${engine.strokes.size}", engine.strokes.size >= 8)
        // 都畫在頂層、細線，而且屬於同一組（一次復原）。
        assertEquals(1, engine.strokes.map { it.group }.toSet().size)
        assertTrue(engine.strokes.all { it.layer == 3 })
        // 預覽已經清掉。
        assertTrue(engine.overlayStrokes.isEmpty())
        assertTrue(engine.undo())
        assertEquals("復原一次收回整個標註", 0, engine.strokes.size)
    }

    @Test
    fun thePreviewShowsWhileDraggingAndIsGoneAfterwards() {
        val engine = toolEngine(DraftTool.DIM_LINEAR)
        tap(engine, 100f, 200f)
        tap(engine, 300f, 200f)
        engine.onMotionEvent(touch(MotionEvent.ACTION_DOWN, 200f, 240f, clock), 1f)
        clock += 20
        engine.onMotionEvent(touch(MotionEvent.ACTION_MOVE, 200f, 250f, clock), 1f)
        assertTrue("拖曳中要有預覽", engine.overlayStrokes.isNotEmpty())
        assertEquals("兩個已選的點", 2, engine.overlayMarks.size)
        assertEquals("預覽不算內容", 0, engine.strokes.size)
        clock += 20
        engine.onMotionEvent(touch(MotionEvent.ACTION_UP, 200f, 250f, clock), 1f)
        assertTrue(engine.overlayStrokes.isEmpty() && engine.overlayMarks.isEmpty())
    }

    @Test
    fun theDimensionNumberFollowsTheScale() {
        // 紙上量 50 mm（≈190.5 頁面單位）：1:1 標 50，1:2 標 100。
        val units = uniffi.padnote_core.draftUnitsPerMm()
        for ((ratio, expected) in listOf(1.0 to "50", 2.0 to "100", 0.5 to "25")) {
            DraftingState.changeScaleRatio(ratio)
            val dim = uniffi.padnote_core.draftDimLinear(
                uniffi.padnote_core.FfiPoint(0f, 0f), uniffi.padnote_core.FfiPoint(50f * units, 0f),
                uniffi.padnote_core.FfiPoint(10f, 30f), uniffi.padnote_core.FfiDimAxis.AUTO,
                DraftingState.scaleRatio.toFloat()
            )
            assertEquals(expected, dim!!.text)
        }
        assertEquals("1:1", run { DraftingState.changeScaleRatio(1.0); DraftingState.scaleLabel() })
        assertEquals("1:2", run { DraftingState.changeScaleRatio(2.0); DraftingState.scaleLabel() })
    }

    @Test
    fun tappingADrawnCircleThenDraggingMakesADiameterDimension() {
        val engine = InkEngine()
        // 先畫一個圓（用引擎自己的落筆路徑，一圈 40 點）。
        val cx = 300f
        val cy = 300f
        val r = 60f
        engine.layer = 3
        engine.onMotionEvent(touch(MotionEvent.ACTION_DOWN, cx + r, cy, clock), 1f)
        for (i in 1..40) {
            clock += 10
            val a = i * 2.0 * Math.PI / 40
            engine.onMotionEvent(
                touch(MotionEvent.ACTION_MOVE, (cx + r * Math.cos(a)).toFloat(), (cy + r * Math.sin(a)).toFloat(), clock), 1f)
        }
        clock += 10
        engine.onMotionEvent(touch(MotionEvent.ACTION_UP, cx + r, cy, clock), 1f)
        val circle = engine.circleNear(cx + r, cy, 20f)
        assertNotNull("畫好的圓要認得出來", circle)
        assertEquals(cx, circle!!.first.x, 3f)
        assertEquals(r, circle.second, 3f)
        // 圓心是吸附點。
        val anchor = engine.snapAnchor(cx + 5f, cy - 4f, 14f)
        assertNotNull(anchor)
        assertEquals(cx, anchor!!.x, 3f)

        val before = engine.strokes.size
        DraftingState.selectTool(DraftTool.DIM_DIAMETER)
        DraftToolController.reset(engine)
        engine.onToolTouch = { phase, x, y -> DraftToolController.handle(phase, x, y, engine) }
        tap(engine, cx + r, cy)               // 點在圓上：取得圓心與半徑
        drag(engine, cx + 10f to cy - 10f, cx + 120f to cy - 110f)   // 拖出引線的方向
        assertTrue("直徑標註的筆畫", engine.strokes.size > before + 3)
        // 數字是「⌀」開頭：筆畫裡有文字（細線）。
        val last = engine.strokes.last()
        assertEquals(3, last.layer)
        assertTrue(engine.undo())
        assertEquals("復原收回整個標註、圓還在", before, engine.strokes.size)
    }

    @Test
    fun aNonCircleIsNotMistakenForOne() {
        val engine = InkEngine()
        engine.layer = 3
        engine.onMotionEvent(touch(MotionEvent.ACTION_DOWN, 100f, 100f, clock), 1f)
        for (i in 1..20) {
            clock += 10
            engine.onMotionEvent(touch(MotionEvent.ACTION_MOVE, 100f + i * 10, 100f + (i % 3) * 2, clock), 1f)
        }
        clock += 10
        engine.onMotionEvent(touch(MotionEvent.ACTION_UP, 300f, 100f, clock), 1f)
        assertNull(engine.circleNear(200f, 100f, 30f))
    }

    @Test
    fun anAngleDimensionNeedsThreePicksAndAnArcDrag() {
        val engine = toolEngine(DraftTool.DIM_ANGLE)
        tap(engine, 200f, 300f)   // 頂點
        tap(engine, 400f, 300f)   // 第一邊
        tap(engine, 200f, 100f)   // 第二邊（垂直）
        assertEquals(0, engine.strokes.size)
        drag(engine, 260f to 240f, 270f to 230f)
        assertTrue(engine.strokes.size >= 5)
    }

    @Test
    fun dimensionsRefuseToDrawOnALockedLayerAndTheToolCanBeLeft() {
        DraftingState.setLocked(3, true)
        val engine = toolEngine(DraftTool.DIM_LINEAR)
        tap(engine, 100f, 200f)
        tap(engine, 300f, 200f)
        drag(engine, 200f to 240f, 200f to 262f)
        assertEquals("頂層鎖住就不畫標註", 0, engine.strokes.size)
        // 結束工具之後，單指又回到畫線。
        DraftingState.selectTool(DraftTool.NONE)
        engine.onToolTouch = null
        DraftToolController.reset(engine)
        assertNull(DraftingState.toolHint)
    }

    @Test
    fun everySymbolAndTheTitleBlockComeBackFromTheCore() {
        val catalog = uniffi.padnote_core.draftSymbolCatalog()
        assertTrue(catalog.size >= 30)
        val params = uniffi.padnote_core.FfiSymbolParams(
            sizeMm = 3.5f, text = "Ra 1.6", rotationDeg = 0f, otherSide = false, allAround = false,
            field = false, diameter = false, datums = "", lengthMm = 20f
        )
        for (info in catalog) {
            val kit = uniffi.padnote_core.draftSymbol(info.id, uniffi.padnote_core.FfiPoint(0f, 0f), params)
            assertNotNull(info.id, kit)
            assertTrue(info.id, kit!!.strokes.isNotEmpty())
        }
        val frame = uniffi.padnote_core.draftSheetFrame("a3_landscape", "1:2", true, true)
        assertNotNull(frame)
        assertTrue(frame!!.texts.any { it.key == "draft_tb_title" })
        // 標籤的語系鍵六個語言都翻得出來。
        for (label in frame.texts) {
            for (tag in listOf("zh-Hant", "en", "zh-Hans", "ja", "ko", "th")) {
                assertTrue(label.key, com.kairumo.padnote.LocalizationStrings.localized(label.key, tag) != label.key)
            }
        }
        assertNull(uniffi.padnote_core.draftSheetFrame("custom_900x700", "", true, true))
    }

    @Test
    fun placingAKitCentresItInTheViewAndKeepsItInsideThePage() {
        val params = uniffi.padnote_core.FfiSymbolParams(
            sizeMm = 3.5f, text = "", rotationDeg = 0f, otherSide = false, allAround = false,
            field = false, diameter = false, datums = "", lengthMm = 20f
        )
        val kit = uniffi.padnote_core.draftSymbol("surface_basic", uniffi.padnote_core.FfiPoint(0f, 0f), params)!!
        val box = draftKitPlacement(kit, 400f, 500f, 800f, 1132f)!!
        // 包圍盒中心落在視野中央。
        val pts = kit.strokes.flatMap { it.points }
        val cx = (pts.minOf { it.x } + pts.maxOf { it.x }) / 2f + box[0]
        val cy = (pts.minOf { it.y } + pts.maxOf { it.y }) / 2f + box[1]
        assertEquals(400f, cx, 0.5f)
        assertEquals(500f, cy, 0.5f)
        // 視野中央在頁面外的角落：夾回頁面裡。
        val corner = draftKitPlacement(kit, -50f, 2000f, 800f, 1132f)!!
        val left = pts.minOf { it.x } + corner[0]
        val bottom = pts.maxOf { it.y } + corner[1]
        assertTrue(left >= -0.01f && bottom <= 1132.01f)
    }
}
