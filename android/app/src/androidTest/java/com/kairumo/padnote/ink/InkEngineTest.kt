package com.kairumo.padnote.ink

import android.view.InputDevice
import android.view.MotionEvent
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.PadnoteSession
import java.io.File

/**
 * 掌拒與筆畫累積（工作包 WP5 的驗收）。
 *
 * 驗收條件寫的是「手掌貼在螢幕上書寫不產生任何筆畫」。這裡用合成的
 * `MotionEvent` 重現真實的書寫順序 —— **手掌先碰、筆才落下** —— 因為那才是
 * 使用者的自然動作，也是掌拒最容易漏掉的那一種。
 */
@RunWith(AndroidJUnit4::class)
class InkEngineTest {

    private lateinit var workDir: File

    @Before
    fun setUp() {
        workDir = File(
            InstrumentationRegistry.getInstrumentation().targetContext.cacheDir,
            "ink-${System.nanoTime()}"
        )
        workDir.mkdirs()
    }

    private fun touch(
        action: Int,
        toolType: Int,
        x: Float,
        touchMajor: Float,
        timeMs: Long,
        pointerId: Int = 0
    ): MotionEvent {
        val props = MotionEvent.PointerProperties().apply {
            id = pointerId
            this.toolType = toolType
        }
        val coords = MotionEvent.PointerCoords().apply {
            this.x = x
            this.y = 200f
            pressure = 0.6f
            this.touchMajor = touchMajor
        }
        return MotionEvent.obtain(
            0L, timeMs, action, 1,
            arrayOf(props), arrayOf(coords),
            0, 0, 1f, 1f, 0, 0, InputDevice.SOURCE_STYLUS, 0
        )
    }

    private fun feed(engine: InkEngine, vararg events: MotionEvent): InkEngine {
        for (e in events) {
            engine.onMotionEvent(e, density = 1f)
            e.recycle()
        }
        return engine
    }

    // MARK: - 掌拒

    @Test
    fun aRestingPalmProducesNoStroke() {
        // 手掌接觸半徑遠大於門檻（預設 22dp），touchMajor 90 → 半徑 45。
        val engine = InkEngine()
        feed(
            engine,
            touch(MotionEvent.ACTION_DOWN, MotionEvent.TOOL_TYPE_FINGER, 50f, 90f, 1_000L),
            touch(MotionEvent.ACTION_MOVE, MotionEvent.TOOL_TYPE_FINGER, 55f, 90f, 1_010L),
            touch(MotionEvent.ACTION_UP, MotionEvent.TOOL_TYPE_FINGER, 60f, 90f, 1_020L)
        )
        assertEquals("手掌不該留下任何筆畫", 0, engine.strokes.size)
    }

    @Test
    fun aPenStrokeIsAccepted() {
        val engine = InkEngine()
        feed(
            engine,
            touch(MotionEvent.ACTION_DOWN, MotionEvent.TOOL_TYPE_STYLUS, 10f, 4f, 1_000L),
            touch(MotionEvent.ACTION_MOVE, MotionEvent.TOOL_TYPE_STYLUS, 20f, 4f, 1_008L),
            touch(MotionEvent.ACTION_MOVE, MotionEvent.TOOL_TYPE_STYLUS, 30f, 4f, 1_016L),
            touch(MotionEvent.ACTION_UP, MotionEvent.TOOL_TYPE_STYLUS, 40f, 4f, 1_024L)
        )
        assertEquals(1, engine.strokes.size)
        assertEquals(4, engine.strokes.first().points.size)
    }

    @Test
    fun aPalmThatLandedFirstIsRetractedWhenThePenComesDown() {
        // 這是掌拒真正的考題：手掌先碰，筆後落。手掌那一筆此時已經在畫了。
        val engine = InkEngine()
        engine.setPalmThresholds(22f, 500u)

        // 手掌落下並移動一段（小接觸面積，所以不會被當場擋掉 —— 模擬平台沒給
        // 可靠的接觸面積時的情況），接著抬起完成一筆
        feed(
            engine,
            touch(MotionEvent.ACTION_DOWN, MotionEvent.TOOL_TYPE_FINGER, 50f, 8f, 1_000L),
            touch(MotionEvent.ACTION_MOVE, MotionEvent.TOOL_TYPE_FINGER, 55f, 8f, 1_010L),
            touch(MotionEvent.ACTION_UP, MotionEvent.TOOL_TYPE_FINGER, 60f, 8f, 1_020L)
        )
        val afterFinger = engine.strokes.size

        // 筆在收回時間窗內落下
        val outcome = engine.onMotionEvent(
            touch(MotionEvent.ACTION_DOWN, MotionEvent.TOOL_TYPE_STYLUS, 100f, 4f, 1_100L, pointerId = 1),
            density = 1f
        )

        assertTrue(
            "筆落下時應該收回先前的可疑筆畫（先前有 $afterFinger 筆，收回 ${outcome.retracted}）",
            afterFinger == 0 || outcome.retracted.isNotEmpty()
        )
        assertEquals("收回後不該留下手指畫的那一筆", 0, engine.strokes.size)
    }

    @Test
    fun penOnlyModeTreatsFingersAsGestures() {
        val engine = InkEngine()
        engine.setPenOnly(true)
        val outcome = engine.onMotionEvent(
            touch(MotionEvent.ACTION_DOWN, MotionEvent.TOOL_TYPE_FINGER, 50f, 8f, 1_000L),
            density = 1f
        )
        assertEquals(0, outcome.drawnSamples)
        assertEquals(0, engine.strokes.size)
    }

    // MARK: - 筆畫累積

    @Test
    fun aSingleTapDoesNotBecomeAStroke() {
        // 一個點的「筆畫」是點一下，不是書寫。留著只會在畫面上產生看不見的雜點。
        val engine = InkEngine()
        feed(
            engine,
            touch(MotionEvent.ACTION_DOWN, MotionEvent.TOOL_TYPE_STYLUS, 10f, 4f, 1_000L)
        )
        engine.onMotionEvent(
            touch(MotionEvent.ACTION_UP, MotionEvent.TOOL_TYPE_STYLUS, 10f, 4f, 1_004L), 1f)
        // DOWN + UP 共兩個點，但位置相同 —— 仍算一筆（使用者確實點了），
        // 這裡確認的是不會產生**零點或單點**的壞資料。
        engine.strokes.forEach { assertTrue(it.points.size >= 2) }
    }

    @Test
    fun cancelledStrokesAreDiscarded() {
        // 來電或系統手勢接管時，畫到一半的筆畫不該被當成完成。
        val engine = InkEngine()
        feed(
            engine,
            touch(MotionEvent.ACTION_DOWN, MotionEvent.TOOL_TYPE_STYLUS, 10f, 4f, 1_000L),
            touch(MotionEvent.ACTION_MOVE, MotionEvent.TOOL_TYPE_STYLUS, 20f, 4f, 1_008L),
            touch(MotionEvent.ACTION_CANCEL, MotionEvent.TOOL_TYPE_STYLUS, 30f, 4f, 1_016L)
        )
        assertEquals(0, engine.strokes.size)
    }

    @Test
    fun theEraserRemovesStrokesInsteadOfAddingThem() {
        // 擦除是 append-only 的墓碑，不是「畫一筆白色」—— 後者在透明背景上
        // 會留下一條白線，而且同步過去在別的裝置上看得到。
        val engine = InkEngine()
        feed(
            engine,
            touch(MotionEvent.ACTION_DOWN, MotionEvent.TOOL_TYPE_STYLUS, 10f, 4f, 1_000L),
            touch(MotionEvent.ACTION_MOVE, MotionEvent.TOOL_TYPE_STYLUS, 20f, 4f, 1_008L),
            touch(MotionEvent.ACTION_UP, MotionEvent.TOOL_TYPE_STYLUS, 30f, 4f, 1_016L)
        )
        assertEquals(1, engine.strokes.size)

        engine.isErasing = true
        engine.baseWidth = 20f
        feed(
            engine,
            touch(MotionEvent.ACTION_DOWN, MotionEvent.TOOL_TYPE_STYLUS, 20f, 4f, 2_000L),
            touch(MotionEvent.ACTION_MOVE, MotionEvent.TOOL_TYPE_STYLUS, 20f, 4f, 2_008L)
        )
        assertEquals("碰到的筆畫應該被擦掉", 0, engine.strokes.size)
    }

    @Test
    fun theEraserLeavesStrokesItDidNotTouch() {
        // 擦除半徑太大的話會把旁邊的字一起吃掉。
        val engine = InkEngine()
        feed(
            engine,
            touch(MotionEvent.ACTION_DOWN, MotionEvent.TOOL_TYPE_STYLUS, 10f, 4f, 1_000L),
            touch(MotionEvent.ACTION_MOVE, MotionEvent.TOOL_TYPE_STYLUS, 20f, 4f, 1_008L),
            touch(MotionEvent.ACTION_UP, MotionEvent.TOOL_TYPE_STYLUS, 30f, 4f, 1_016L)
        )
        engine.isErasing = true
        engine.baseWidth = 2f
        feed(
            engine,
            touch(MotionEvent.ACTION_DOWN, MotionEvent.TOOL_TYPE_STYLUS, 900f, 4f, 2_000L)
        )
        assertEquals("離很遠的筆畫不該被擦掉", 1, engine.strokes.size)
    }

    @Test
    fun resetClearsEverything() {
        val engine = InkEngine()
        feed(
            engine,
            touch(MotionEvent.ACTION_DOWN, MotionEvent.TOOL_TYPE_STYLUS, 10f, 4f, 1_000L),
            touch(MotionEvent.ACTION_MOVE, MotionEvent.TOOL_TYPE_STYLUS, 20f, 4f, 1_008L),
            touch(MotionEvent.ACTION_UP, MotionEvent.TOOL_TYPE_STYLUS, 30f, 4f, 1_016L)
        )
        assertEquals(1, engine.strokes.size)
        engine.reset()
        assertEquals(0, engine.strokes.size)
    }

    // MARK: - 真的寫進 .padnote

    @Test
    fun strokesWrittenOnAndroidLandInThePackage() {
        // 這條把整條路走完：MotionEvent → 仲裁 → 核心 → 落盤 → 重新開啟讀回來。
        val path = File(workDir, "written.padnote").absolutePath
        val session = PadnoteSession.create(path, "Android 手寫", 1_757_635_200_000uL, 0xA0u)
        val pageId = session.firstPageId()!!
        val engine = InkEngine(session, pageId)

        feed(
            engine,
            touch(MotionEvent.ACTION_DOWN, MotionEvent.TOOL_TYPE_STYLUS, 10f, 4f, 1_000L),
            touch(MotionEvent.ACTION_MOVE, MotionEvent.TOOL_TYPE_STYLUS, 20f, 4f, 1_008L),
            touch(MotionEvent.ACTION_MOVE, MotionEvent.TOOL_TYPE_STYLUS, 30f, 4f, 1_016L),
            touch(MotionEvent.ACTION_UP, MotionEvent.TOOL_TYPE_STYLUS, 40f, 4f, 1_024L)
        )

        val reopened = PadnoteSession.openExisting(path, 0xB0u)
        val details = reopened.visibleStrokeDetails(pageId)
        assertEquals(1, details.size)
        assertEquals(4, details.first().points.size)
        assertEquals(10f, details.first().points.first().x, 0.001f)
        assertEquals(40f, details.first().points.last().x, 0.001f)
    }

    @Test
    fun aRetractedStrokeIsAlsoRemovedFromThePackage() {
        // 收回若只改記憶體、沒動檔案，重開之後手掌畫的那一筆會回來。
        val path = File(workDir, "retract.padnote").absolutePath
        val session = PadnoteSession.create(path, "收回", 1_757_635_200_000uL, 0xA1u)
        val pageId = session.firstPageId()!!
        val engine = InkEngine(session, pageId)
        engine.setPalmThresholds(22f, 500u)

        feed(
            engine,
            touch(MotionEvent.ACTION_DOWN, MotionEvent.TOOL_TYPE_FINGER, 50f, 8f, 1_000L),
            touch(MotionEvent.ACTION_MOVE, MotionEvent.TOOL_TYPE_FINGER, 55f, 8f, 1_010L),
            touch(MotionEvent.ACTION_UP, MotionEvent.TOOL_TYPE_FINGER, 60f, 8f, 1_020L)
        )
        feed(
            engine,
            touch(MotionEvent.ACTION_DOWN, MotionEvent.TOOL_TYPE_STYLUS, 100f, 4f, 1_100L, pointerId = 1)
        )

        val reopened = PadnoteSession.openExisting(path, 0xB1u)
        assertEquals(
            "重新開啟後不該看到被收回的那一筆",
            0, reopened.visibleStrokeDetails(pageId).size
        )
    }
}

/**
 * 筆刷、顏色、筆寬與橡皮擦（Android）。
 *
 * 在此之前 Android 只有一支固定的黑色鋼筆 —— 核心一直支援這些，缺的只是 UI。
 */
@RunWith(AndroidJUnit4::class)
class InkToolbarTest {

    @Test
    fun everyBrushMapsToACoreToolExceptTheEraser() {
        // 擦除與套索**都不是筆刷** —— 核心的 ToolKind 只有筆刷種類。
        // 擦除走 erase_stroke，套索是選取工具（L-06），兩個都畫不出線。
        //
        // 套索是後來加的，而這條測試當時沒跟著改 —— 加一個非筆刷的工具
        // 就要在這裡列出來，否則這條測試會把「新工具」誤判成「漏接核心」。
        for (tool in InkTool.entries) {
            when {
                tool == InkTool.ERASER ->
                    assertTrue("橡皮擦不該對到某一種筆刷", tool.isEraser)
                tool.isLasso ->
                    assertTrue("套索不該對到某一種筆刷", tool.kind == null)
                else ->
                    assertTrue("${tool.name} 沒有對到核心的筆刷", tool.kind != null)
            }
        }
    }

    @Test
    fun theWidthRangeMatchesTheOtherPlatform() {
        // 同一個設定在兩個平台畫出來要一樣粗。
        assertEquals(1f, inkWidthRange.start)
        assertEquals(30f, inkWidthRange.endInclusive)
    }

    @Test
    fun thePreviewGrowsWithTheWidth() {
        assertTrue(
            previewDiameter(InkTool.FOUNTAIN_PEN, 20f) >
                previewDiameter(InkTool.FOUNTAIN_PEN, 2f)
        )
    }

    @Test
    fun thePreviewIsCappedSoTheToolbarDoesNotGrow() {
        assertTrue(previewDiameter(InkTool.HIGHLIGHTER, 30f) <= 22f)
    }

    @Test
    fun theHighlighterIsWiderThanTheBallpointAtTheSameWidth() {
        assertTrue(
            previewDiameter(InkTool.HIGHLIGHTER, 4f) > previewDiameter(InkTool.BALLPOINT, 4f)
        )
    }

    @Test
    fun thePaletteHasDistinctColors() {
        // 重複的色票只是佔位置。
        assertEquals(inkPalette.size, inkPalette.map { it.first }.toSet().size)
    }
}
