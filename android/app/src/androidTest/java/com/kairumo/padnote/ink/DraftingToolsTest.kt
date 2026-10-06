package com.kairumo.padnote.ink

import android.view.InputDevice
import android.view.MotionEvent
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.kairumo.padnote.L10n
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
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

    // ── 第三階段：對齊、尺規、圓規、轉折點 ──

    /** 在 (x0,y0) 落筆、拖到 (x1,y1) 的一筆製圖線（頂層）。回傳畫完之後的最後一筆。 */
    private fun drawLine(engine: InkEngine, x0: Float, y0: Float, x1: Float, y1: Float) {
        engine.layer = 3
        drag(engine, x0 to y0, x1 to y1)
    }

    @Test
    fun theEndOfALineAlignsWithAnExistingPointAndShowsAGuide() {
        DraftingState.changeAlign(true)
        val engine = InkEngine()
        drawLine(engine, 200f, 100f, 200f, 150f)       // 既有的線：端點 (200,100)
        val before = engine.strokes.size
        // 新的一筆終點 x 偏了 3，應該被吸到 x = 200，且放手之前有虛線導引。
        engine.layer = 3
        engine.onMotionEvent(touch(MotionEvent.ACTION_DOWN, 100f, 400f, clock), 1f)
        clock += 15
        engine.onMotionEvent(touch(MotionEvent.ACTION_MOVE, 150f, 400f, clock), 1f)
        clock += 15
        engine.onMotionEvent(touch(MotionEvent.ACTION_MOVE, 203f, 400f, clock), 1f)
        assertTrue("對齊時要有導引線", engine.alignGuides.isNotEmpty())
        clock += 15
        engine.onMotionEvent(touch(MotionEvent.ACTION_UP, 203f, 400f, clock), 1f)
        assertEquals(before + 1, engine.strokes.size)
        assertEquals(200f, engine.strokes.last().points.last().x, 0.01f)
        assertTrue("放手後導引線清掉", engine.alignGuides.isEmpty())
    }

    @Test
    fun alignmentCanBeTurnedOff() {
        DraftingState.changeAlign(false)
        try {
            val engine = InkEngine()
            drawLine(engine, 200f, 100f, 200f, 150f)
            drawLine(engine, 100f, 400f, 203f, 400f)
            assertEquals(203f, engine.strokes.last().points.last().x, 0.01f)
        } finally {
            DraftingState.changeAlign(true)
        }
    }

    @Test
    fun aLineStartedAgainstTheRulerFollowsItsEdge() {
        DraftingState.changeAlign(false)
        try {
            DraftingState.placeInstrument("ruler", 300f, 300f, 800f)
            val inst = DraftingState.instrument!!
            val (a, b) = inst.pageEdges.first()
            val engine = InkEngine()
            // 沿著邊起筆、終點偏離邊 20：整筆被拉回邊上。
            val sx = (a.x + b.x) / 2
            val sy = (a.y + b.y) / 2
            val nx = -(b.y - a.y)
            val ny = b.x - a.x
            val nl = kotlin.math.hypot(nx, ny)
            drawLine(engine, sx, sy + 2f, sx + 60f, sy + 20f)
            val pts = engine.strokes.last().points
            // 所有點都在邊所在的直線上（距離 < 0.5）。
            for (p in pts) {
                val d = kotlin.math.abs((p.x - a.x) * nx / nl + (p.y - a.y) * ny / nl)
                assertTrue("點離尺邊 $d", d < 0.5f)
            }
        } finally {
            DraftingState.removeInstrument()
            DraftingState.changeAlign(true)
        }
    }

    @Test
    fun draggingTheRulerBodyMovesItInsteadOfDrawing() {
        DraftingState.placeInstrument("ruler", 300f, 300f, 800f)
        try {
            val inst = DraftingState.instrument!!
            val engine = InkEngine()
            engine.layer = 3
            val startX = inst.originX
            val startY = inst.originY
            // 尺身正中央（離每條邊都遠）。
            val cx = inst.originX + inst.geometry.width / 2
            val cy = inst.originY + inst.geometry.height / 2
            drag(engine, cx to cy, (cx + 40f) to (cy + 25f))
            assertEquals("搬尺不留筆畫", 0, engine.strokes.size)
            assertEquals(startX + 40f, DraftingState.instrument!!.originX, 1f)
            assertEquals(startY + 25f, DraftingState.instrument!!.originY, 1f)
        } finally {
            DraftingState.removeInstrument()
        }
    }

    @Test
    fun theTSquareOnlySlidesVerticallyAndCannotRotate() {
        DraftingState.placeInstrument("t_square", 400f, 300f, 800f)
        try {
            val inst = DraftingState.instrument!!
            assertTrue(inst.verticalOnly)
            val x0 = inst.originX
            DraftingState.moveInstrument(50f, 30f)
            DraftingState.rotateInstrument(15.0)
            assertEquals("丁字尺不能橫向移動", x0, DraftingState.instrument!!.originX, 0.001f)
            assertEquals("丁字尺不能轉", 0.0, DraftingState.instrument!!.angleDegrees, 0.001)
        } finally {
            DraftingState.removeInstrument()
        }
    }

    @Test
    fun rotatingTheRulerTurnsItsEdges() {
        DraftingState.placeInstrument("ruler", 300f, 300f, 800f)
        try {
            val before = DraftingState.instrument!!.pageEdges.first()
            DraftingState.rotateInstrument(90.0)
            val after = DraftingState.instrument!!.pageEdges.first()
            val len0 = kotlin.math.hypot(before.second.x - before.first.x, before.second.y - before.first.y)
            val len1 = kotlin.math.hypot(after.second.x - after.first.x, after.second.y - after.first.y)
            assertEquals("轉動不改變長度", len0, len1, 0.01f)
            // 水平邊轉 90° 變垂直邊。
            assertEquals(0f, after.second.x - after.first.x, 0.05f)
        } finally {
            DraftingState.removeInstrument()
        }
    }

    @Test
    fun theCompassDrawsAnArcOfTheDraggedRadiusAndUndoes() {
        val engine = toolEngine(DraftTool.COMPASS)
        assertNotNull(DraftingState.toolHint)
        tap(engine, 300f, 300f)                              // 圓心
        drag(engine, 400f to 300f, 300f to 400f)             // 半徑 100，掃四分之一圈
        assertEquals("一條圓弧", 1, engine.strokes.size)
        val pts = engine.strokes.first().points
        for (p in pts) {
            val r = kotlin.math.hypot(p.x - 300f, p.y - 300f)
            assertEquals("弧上的點離圓心 $r", 100f, r, 1.5f)
        }
        assertTrue(engine.overlayStrokes.isEmpty())
        assertTrue(engine.undo())
        assertEquals(0, engine.strokes.size)
    }

    @Test
    fun theCompassCanGoPastAHalfTurn() {
        val engine = toolEngine(DraftTool.COMPASS)
        tap(engine, 300f, 300f)
        engine.onMotionEvent(touch(MotionEvent.ACTION_DOWN, 400f, 300f, clock), 1f)
        // 繞一整圈再多一點：逐步累計角度，不是只看起訖。
        for (i in 1..36) {
            clock += 10
            val a = i * Math.toRadians(10.0)
            engine.onMotionEvent(
                touch(MotionEvent.ACTION_MOVE, (300 + 100 * Math.cos(a)).toFloat(), (300 + 100 * Math.sin(a)).toFloat(), clock), 1f)
        }
        clock += 10
        engine.onMotionEvent(touch(MotionEvent.ACTION_UP, 400f, 300f, clock), 1f)
        assertEquals(1, engine.strokes.size)
        val pts = engine.strokes.first().points
        val first = pts.first()
        val last = pts.last()
        assertTrue("轉滿一圈首尾相接", kotlin.math.hypot(first.x - last.x, first.y - last.y) < 4f)
        assertTrue("圓周上的點很多：${pts.size}", pts.size > 60)
    }

    @Test
    fun thePivotToolStoresAPointPerPageAndReturnsToDrawing() {
        val engine = toolEngine(DraftTool.SET_PIVOT)
        tap(engine, 410f, 520f)
        val p = DraftingState.pivot(engine.pageKey)
        assertNotNull(p)
        assertEquals(410f, p!!.first, 0.01f)
        assertEquals(520f, p.second, 0.01f)
        assertEquals("設完就回到畫線", DraftTool.NONE, DraftingState.tool)
        DraftingState.setPivot(engine.pageKey, null)
        assertNull(DraftingState.pivot(engine.pageKey))
    }

    @Test
    fun theThirdAngleTransferAlignsWidthThroughThe45DegreePivot() {
        // 轉折點 (400,500)；右側視圖要對齊上方視圖的 (300,380)：x = 400 + (500 - 380) = 520。
        val engine = InkEngine()
        DraftingState.changeAlign(true)
        DraftingState.changeThirdAngle(true)
        DraftingState.setPivot(engine.pageKey, 400f to 500f)
        try {
            drawLine(engine, 300f, 380f, 340f, 380f)
            engine.layer = 3
            engine.onMotionEvent(touch(MotionEvent.ACTION_DOWN, 480f, 700f, clock), 1f)
            clock += 15
            engine.onMotionEvent(touch(MotionEvent.ACTION_MOVE, 500f, 700f, clock), 1f)
            clock += 15
            engine.onMotionEvent(touch(MotionEvent.ACTION_MOVE, 518f, 700f, clock), 1f)
            clock += 15
            engine.onMotionEvent(touch(MotionEvent.ACTION_UP, 518f, 700f, clock), 1f)
            assertEquals("寬度經 45° 傳遞到 x=520", 520f, engine.strokes.last().points.last().x, 0.01f)
        } finally {
            DraftingState.setPivot(engine.pageKey, null)
        }
    }

    // ── 量角器：讀角度、畫讀數線、半圓身體 ──

    /** 量角器圓心與半徑（頁面座標）。 */
    private fun protractorCenter(inst: InstrumentModel): Triple<Float, Float, Float> {
        val c = inst.toPage(inst.geometry.readingCenter!!)
        return Triple(c.x, c.y, inst.geometry.width / 2f)
    }

    @Test
    fun theProtractorBodyIsASemicircleAboveItsBaseline() {
        DraftingState.placeInstrument("protractor", 300f, 300f, 800f)
        try {
            val inst = DraftingState.instrument!!
            val (cx, cy, r) = protractorCenter(inst)
            assertTrue("圓心上方是身體", inst.containsBody(cx, cy - r * 0.5f))
            assertFalse("底邊以下不是身體", inst.containsBody(cx, cy + 10f))
            assertFalse("半徑之外不是身體", inst.containsBody(cx + r * 1.1f, cy - 1f))
            // 外框的包圍盒左上角就是原點（與其他尺一致）。
            assertEquals(inst.originX, cx - r, 0.5f)
            assertEquals(inst.originY, cy - r, 0.5f)
        } finally {
            DraftingState.removeInstrument()
        }
    }

    @Test
    fun pressingTheScaleRingReadsTheAngleAndDoesNotMoveTheProtractor() {
        DraftingState.placeInstrument("protractor", 300f, 300f, 800f)
        try {
            val inst = DraftingState.instrument!!
            val (cx, cy, r) = protractorCenter(inst)
            val engine = InkEngine()
            engine.layer = 3
            val ox = inst.originX
            val a = Math.toRadians(60.0)
            val px = cx + (r * 0.85f * Math.cos(a)).toFloat()
            val py = cy - (r * 0.85f * Math.sin(a)).toFloat()
            engine.onMotionEvent(touch(MotionEvent.ACTION_DOWN, px, py, clock), 1f)
            clock += 20
            engine.onMotionEvent(touch(MotionEvent.ACTION_UP, px, py, clock), 1f)
            clock += 30
            assertEquals(60f, inst.readingDegrees!!, 0.5f)
            assertEquals("兩邊刻度加起來是 180", 120f, 180f - inst.readingDegrees!!, 0.5f)
            assertEquals("按刻度帶不是搬尺", ox, inst.originX, 0.001f)
            assertEquals("讀數不留筆畫", 0, engine.strokes.size)
            assertNotNull(inst.readingText)
            // 拖著手指，讀數跟著連續變。
            drag(engine, px to py, (cx - (r * 0.85f * Math.cos(a)).toFloat()) to py)
            assertEquals(120f, inst.readingDegrees!!, 0.5f)
        } finally {
            DraftingState.removeInstrument()
        }
    }

    @Test
    fun theReadingFollowsTheProtractorWhenItIsMovedOrRotated() {
        DraftingState.placeInstrument("protractor", 300f, 300f, 800f)
        try {
            val inst = DraftingState.instrument!!
            val (cx, cy, r) = protractorCenter(inst)
            DraftingState.readInstrument(cx + r * 0.8f, cy - 1f)     // 約 0°
            assertEquals(0f, inst.readingDegrees!!, 1f)
            // 搬動：讀數不變。
            DraftingState.moveInstrument(40f, 25f)
            assertEquals(0f, inst.readingDegrees!!, 1f)
            // 內圈拖曳是搬尺，不改讀數。
            val engine = InkEngine()
            engine.layer = 3
            val (cx2, cy2, r2) = protractorCenter(inst)
            val before = inst.originX
            drag(engine, cx2 to (cy2 - r2 * 0.25f), (cx2 + 30f) to (cy2 - r2 * 0.25f + 10f))
            assertEquals(before + 30f, inst.originX, 1f)
            assertEquals(0f, inst.readingDegrees!!, 1f)
            // 轉 90°：讀數隨尺轉，相對尺的角度不變。
            DraftingState.rotateInstrument(90.0)
            assertEquals(0f, inst.readingDegrees!!, 1f)
        } finally {
            DraftingState.removeInstrument()
        }
    }

    @Test
    fun theReadingRayRunsFromTheCenterToTheRimAlongTheReadAngle() {
        DraftingState.placeInstrument("protractor", 300f, 300f, 800f)
        try {
            val inst = DraftingState.instrument!!
            assertNull("沒讀過就沒有讀數線", inst.readingRay)
            val (cx, cy, r) = protractorCenter(inst)
            val a = Math.toRadians(45.0)
            DraftingState.readInstrument(cx + (r * 0.7f * Math.cos(a)).toFloat(), cy - (r * 0.7f * Math.sin(a)).toFloat())
            val (p0, p1) = inst.readingRay!!
            assertEquals(cx, p0.x, 0.01f)
            assertEquals(cy, p0.y, 0.01f)
            assertEquals("到外緣：長度 = 半徑", r, kotlin.math.hypot(p1.x - p0.x, p1.y - p0.y), 0.01f)
            val deg = Math.toDegrees(Math.atan2((p0.y - p1.y).toDouble(), (p1.x - p0.x).toDouble()))
            assertEquals(45.0, deg, 0.1)
            // 底邊以下讀不到：沒有讀數線。
            DraftingState.readInstrument(cx, cy + 20f)
            assertNull(inst.readingDegrees)
            assertNull(inst.readingRay)
        } finally {
            DraftingState.removeInstrument()
        }
    }
}
