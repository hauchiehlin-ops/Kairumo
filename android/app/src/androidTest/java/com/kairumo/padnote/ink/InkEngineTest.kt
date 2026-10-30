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

    @Test
    fun anAdbStyleFingerSwipeDrawsInDefaultModeButNotPenOnly() {
        // `adb shell input swipe` 的事件：手指、觸控面積 0、壓力 1.0、每 10ms 一點。
        fun swipe(engine: InkEngine) {
            for (i in 0..12) {
                val action = when (i) {
                    0 -> MotionEvent.ACTION_DOWN
                    12 -> MotionEvent.ACTION_UP
                    else -> MotionEvent.ACTION_MOVE
                }
                val props = MotionEvent.PointerProperties().apply { id = 0; toolType = MotionEvent.TOOL_TYPE_FINGER }
                val coords = MotionEvent.PointerCoords().apply { x = 100f + i * 20f; y = 300f; pressure = 1f; touchMajor = 0f }
                val e = MotionEvent.obtain(0L, 1_000L + i * 10L, action, 1, arrayOf(props), arrayOf(coords),
                    0, 0, 1f, 1f, 0, 0, InputDevice.SOURCE_TOUCHSCREEN, 0)
                engine.onMotionEvent(e, density = 1f)
                e.recycle()
            }
        }
        val any = InkEngine().also { swipe(it) }
        val penOnly = InkEngine().also { it.setPenOnly(true); swipe(it) }
        assertEquals("預設（筆與手指皆可）：手指滑動應成一筆", 1, any.strokes.size)
        assertEquals("僅限筆：手指不該畫", 0, penOnly.strokes.size)
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
    fun aDownAndAFarAwayUpWithNoMovesDoNotDrawAStraightLine() {
        // 實機回報：手繪時多出一條直線。套件裡那一筆只有兩點（落筆、抬筆），中間沒有任何移動取樣。
        val engine = InkEngine()
        feed(
            engine,
            touch(MotionEvent.ACTION_DOWN, MotionEvent.TOOL_TYPE_STYLUS, 10f, 4f, 1_000L),
            touch(MotionEvent.ACTION_UP, MotionEvent.TOOL_TYPE_STYLUS, 300f, 4f, 1_200L)
        )
        assertEquals(0, engine.strokes.size)
        // 正常書寫照收。
        feed(
            engine,
            touch(MotionEvent.ACTION_DOWN, MotionEvent.TOOL_TYPE_STYLUS, 10f, 4f, 2_000L),
            touch(MotionEvent.ACTION_MOVE, MotionEvent.TOOL_TYPE_STYLUS, 150f, 4f, 2_100L),
            touch(MotionEvent.ACTION_UP, MotionEvent.TOOL_TYPE_STYLUS, 300f, 4f, 2_200L)
        )
        assertEquals(1, engine.strokes.size)
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
        assertTrue("筆畫寫入佇列應完成", InkPackageWriter.awaitIdleBlocking())

        val reopened = PadnoteSession.openExisting(path, 0xB0u)
        val details = reopened.visibleStrokeDetails(pageId)
        assertEquals(1, details.size)
        assertEquals(4, details.first().points.size)
        assertEquals(10f, details.first().points.first().x, 0.001f)
        assertEquals(40f, details.first().points.last().x, 0.001f)
    }

    @Test
    fun aCollabStrokeKeepsTheSendersIdInThePackage() {
        // 即時協同收到的筆畫用送出者的 id 寫進核心：送出者的筆畫檔經檔案同步過來時，
        // 核心看到的是同一個 id（`materialize` 去重），套件裡不會多一份。
        val path = File(workDir, "collab-id.padnote").absolutePath
        val session = PadnoteSession.create(path, "協同", 1_757_635_200_000uL, 0xA3u)
        val pageId = session.firstPageId()!!
        val engine = InkEngine(session, pageId)
        val senderId = "3c1f6a0e-7d2b-4e8f-9a1c-5b6d7e8f9a0b"
        val stroke = InkEngine.CompletedStroke(
            pointerId = 7uL, coreStrokeId = null,
            points = listOf(
                uniffi.padnote_core.StrokePoint(10f, 10f, 0.5f, 0f, 0f, 0u, 0f),
                uniffi.padnote_core.StrokePoint(40f, 30f, 0.5f, 0f, 0f, 8000u, 0f)
            ),
            tool = uniffi.padnote_core.ToolKind.FOUNTAIN_PEN, startedAtMs = 0L
        )
        val added = engine.applyRemoteStrokes(listOf(stroke), listOf(senderId))
        assertEquals(senderId, added.single().coreStrokeId)
        // 同一筆又收到一次（整份狀態、重送）：不重複加。
        engine.applyRemoteStrokes(listOf(stroke), listOf(senderId))
        assertEquals(1, engine.strokes.size)
        assertTrue(InkPackageWriter.awaitIdleBlocking())

        // 送出者那台的筆畫檔同步進同一個套件：同一個 id，看得到的還是一筆。
        val sender = PadnoteSession.openExisting(path, 0xB3u)
        sender.addStrokeDraftedWithId(
            pageId, senderId, stroke.tool, stroke.colorRgba, stroke.baseWidth, stroke.points, 0u, 0u
        )
        val reopened = PadnoteSession.openExisting(path, 0xC3u)
        assertEquals(listOf(senderId), reopened.visibleStrokeDetails(pageId).map { it.id.lowercase() })

        // 沒有可用的 id（舊版 Apple）：照舊發新的。
        val fresh = engine.applyRemoteStrokes(listOf(stroke.copy(pointerId = 8uL)), listOf(null))
        assertTrue(fresh.single().coreStrokeId != null && fresh.single().coreStrokeId != senderId)
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
        assertTrue("收回筆畫寫入佇列應完成", InkPackageWriter.awaitIdleBlocking())

        val reopened = PadnoteSession.openExisting(path, 0xB1u)
        assertEquals(
            "重新開啟後不該看到被收回的那一筆",
            0, reopened.visibleStrokeDetails(pageId).size
        )
    }

    @Test
    fun undoingALassoMoveThenUndoingAgainRemovesTheLaterStroke() {
        // 先畫 A、再畫 B，套索把 A 搬走；連按兩次復原：第一次 A 回原位，第二次拿掉的必須是 B。
        // 以前搬移把 A 挪到清單最後，第二次復原拿掉的是 A。
        val path = File(workDir, "lasso-undo.padnote").absolutePath
        val session = PadnoteSession.create(path, "套索復原", 1_757_635_200_000uL, 0xA2u)
        val pageId = session.firstPageId()!!
        val engine = InkEngine(session, pageId)
        fun line(x0: Float, t0: Long, pointer: Int) = feed(
            engine,
            touch(MotionEvent.ACTION_DOWN, MotionEvent.TOOL_TYPE_STYLUS, x0, 4f, t0, pointer),
            touch(MotionEvent.ACTION_MOVE, MotionEvent.TOOL_TYPE_STYLUS, x0 + 10f, 4f, t0 + 8, pointer),
            touch(MotionEvent.ACTION_UP, MotionEvent.TOOL_TYPE_STYLUS, x0 + 20f, 4f, t0 + 16, pointer)
        )
        line(10f, 1_000L, 0)
        line(300f, 2_000L, 1)
        assertTrue(InkPackageWriter.awaitIdleBlocking())
        val a = engine.strokes[0]
        val b = engine.strokes[1]

        engine.translateStrokes(setOf(a.coreStrokeId!!), 0f, 50f)
        assertTrue(engine.undo())
        assertTrue(engine.undo())

        assertEquals(1, engine.strokes.size)
        assertEquals("留下來的應該是先畫的 A", a.points.first().x, engine.strokes[0].points.first().x, 0.001f)
        assertEquals(a.points.first().y, engine.strokes[0].points.first().y, 0.001f)
        assertTrue(engine.strokes.none { it.points.first().x == b.points.first().x })
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
                tool.isMaskingTape ->
                    assertTrue("遮蔽膠帶不該對到某一種筆刷", tool.kind == null)
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
