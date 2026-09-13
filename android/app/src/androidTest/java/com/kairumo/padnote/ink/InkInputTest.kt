package com.kairumo.padnote.ink

import android.view.InputDevice
import android.view.MotionEvent
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.FfiPhase
import uniffi.padnote_core.FfiPointerKind
import kotlin.math.PI

/**
 * `MotionEvent` → 核心事件的轉換（工作包 WP5）。
 *
 * 這些是 instrumented 測試而非純 JVM 測試，因為 `MotionEvent` 的建構與
 * 歷史點機制只有真的 Android runtime 才有 —— 用 mock 測這一層，等於在測
 * 自己寫的假物件。
 */
@RunWith(AndroidJUnit4::class)
class InkInputTest {

    /** 造一個帶壓感、傾斜、方位的觸控事件。 */
    private fun event(
        action: Int,
        toolType: Int,
        x: Float = 100f,
        y: Float = 200f,
        pressure: Float = 0.5f,
        touchMajor: Float = 6f,
        orientation: Float = 0f,
        eventTimeMs: Long = 1_000L
    ): MotionEvent {
        val props = MotionEvent.PointerProperties().apply {
            id = 0
            this.toolType = toolType
        }
        val coords = MotionEvent.PointerCoords().apply {
            this.x = x
            this.y = y
            this.pressure = pressure
            this.touchMajor = touchMajor
            this.orientation = orientation
            setAxisValue(MotionEvent.AXIS_TILT, 0.4f)
        }
        return MotionEvent.obtain(
            0L, eventTimeMs, action, 1,
            arrayOf(props), arrayOf(coords),
            0, 0, 1f, 1f, 0, 0,
            InputDevice.SOURCE_STYLUS, 0
        )
    }

    @Test
    fun toolTypeMapsToThePointerKindTheArbiterExpects() {
        // 對應寫反不會當掉 —— 只會讓掌拒完全失效，而且只在真的用筆時才看得出來。
        assertEquals(FfiPointerKind.PEN, InkInput.kindOf(MotionEvent.TOOL_TYPE_STYLUS))
        assertEquals(FfiPointerKind.ERASER, InkInput.kindOf(MotionEvent.TOOL_TYPE_ERASER))
        assertEquals(FfiPointerKind.FINGER, InkInput.kindOf(MotionEvent.TOOL_TYPE_FINGER))
        assertEquals(FfiPointerKind.MOUSE, InkInput.kindOf(MotionEvent.TOOL_TYPE_MOUSE))
        assertEquals(FfiPointerKind.UNKNOWN, InkInput.kindOf(MotionEvent.TOOL_TYPE_UNKNOWN))
    }

    @Test
    fun hoverBecomesHoverNotADrawnPoint() {
        // 懸停若被當成落筆，筆還沒碰到螢幕就會留下墨跡。
        val e = event(MotionEvent.ACTION_HOVER_MOVE, MotionEvent.TOOL_TYPE_STYLUS)
        assertEquals(FfiPhase.HOVER, InkInput.phaseOf(e))
        e.recycle()
    }

    @Test
    fun unhandledActionsAreIgnoredInsteadOfGuessed() {
        val e = event(MotionEvent.ACTION_SCROLL, MotionEvent.TOOL_TYPE_MOUSE)
        assertNull(InkInput.phaseOf(e))
        e.recycle()
    }

    @Test
    fun contactRadiusIsConvertedToDensityIndependentUnits() {
        // 核心的手掌門檻是 22「點」。餵 px 的話，3x 螢幕上連筆尖都會被當成手掌，
        // 而在 1x 的模擬器上一切正常 —— 這種錯最難在開發機上發現。
        val e = event(MotionEvent.ACTION_DOWN, MotionEvent.TOOL_TYPE_STYLUS, touchMajor = 60f)
        val atOneX = InkInput.samples(e, density = 1f).first().event.contactRadius
        val atThreeX = InkInput.samples(e, density = 3f).first().event.contactRadius
        e.recycle()

        assertEquals(30f, atOneX, 0.001f)       // touchMajor 是直徑，半徑取一半
        assertEquals(10f, atThreeX, 0.001f)     // 再除以密度
    }

    @Test
    fun coordinatesAreAlsoConvertedToDensityIndependentUnits() {
        val e = event(MotionEvent.ACTION_DOWN, MotionEvent.TOOL_TYPE_STYLUS, x = 300f, y = 600f)
        val s = InkInput.samples(e, density = 3f).first()
        e.recycle()
        assertEquals(100f, s.event.x, 0.001f)
        assertEquals(200f, s.event.y, 0.001f)
    }

    @Test
    fun negativeOrientationIsNormalizedIntoTheCoreRange() {
        // AXIS_ORIENTATION 是 -π..π，核心要 0..2π。負值會被核心夾成 0，
        // 於是扁筆頭的方向在螢幕左半邊全部錯，而且不會有任何錯誤訊息。
        val tau = (PI * 2).toFloat()
        assertEquals(tau - 1f, InkInput.normalizeAzimuth(-1f), 0.001f)
        assertEquals(1f, InkInput.normalizeAzimuth(1f), 0.001f)
        assertTrue(InkInput.normalizeAzimuth(-3.1f) in 0f..tau)
    }

    @Test
    fun historicalSamplesAreNotDropped() {
        // S Pen 的取樣率遠高於畫面更新率，一個 ACTION_MOVE 裡通常塞著好幾個
        // 歷史取樣點。只讀 getX() 的話，快速書寫會變成折線。
        val props = MotionEvent.PointerProperties().apply {
            id = 0; toolType = MotionEvent.TOOL_TYPE_STYLUS
        }
        fun coords(x: Float) = MotionEvent.PointerCoords().apply {
            this.x = x; this.y = 100f; pressure = 0.5f; touchMajor = 6f
        }

        val e = MotionEvent.obtain(
            0L, 1_000L, MotionEvent.ACTION_MOVE, 1,
            arrayOf(props), arrayOf(coords(10f)),
            0, 0, 1f, 1f, 0, 0, InputDevice.SOURCE_STYLUS, 0
        )
        // 追加三個歷史樣本，模擬 240Hz 取樣塞進 60Hz 的事件
        e.addBatch(1_004L, arrayOf(coords(20f)), 0)
        e.addBatch(1_008L, arrayOf(coords(30f)), 0)
        e.addBatch(1_012L, arrayOf(coords(40f)), 0)

        val samples = InkInput.samples(e, density = 1f)
        e.recycle()

        assertEquals("四個取樣點一個都不能少", 4, samples.size)
        assertEquals(listOf(10f, 20f, 30f, 40f), samples.map { it.event.x })
    }

    @Test
    fun timeDeltasAreClampedToTheFormatLimit() {
        // 格式規格 §5.4 的 dt 是 u16 微秒。停筆三秒不該讓數值繞回去變成很小的值。
        val a = event(MotionEvent.ACTION_DOWN, MotionEvent.TOOL_TYPE_STYLUS, eventTimeMs = 1_000L)
        val b = event(MotionEvent.ACTION_MOVE, MotionEvent.TOOL_TYPE_STYLUS, eventTimeMs = 4_000L)
        val samples = InkInput.samples(a, 1f) + InkInput.samples(b, 1f)
        a.recycle(); b.recycle()

        val points = InkInput.strokePoints(samples)
        assertEquals(0u, points[0].dtUs)
        assertEquals(InkInput.MAX_DT_US, points[1].dtUs)
    }

    @Test
    fun firstPointHasNoTimeDelta() {
        val e = event(MotionEvent.ACTION_DOWN, MotionEvent.TOOL_TYPE_STYLUS)
        val points = InkInput.strokePoints(InkInput.samples(e, 1f))
        e.recycle()
        assertNotNull(points.firstOrNull())
        assertEquals(0u, points.first().dtUs)
    }
}
