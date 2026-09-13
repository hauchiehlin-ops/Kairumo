package com.kairumo.padnote.ink

import android.view.InputDevice
import android.view.MotionEvent
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class InkLatencyMeterTest {

    private fun event(eventTimeMs: Long): MotionEvent {
        val props = MotionEvent.PointerProperties().apply {
            id = 0; toolType = MotionEvent.TOOL_TYPE_STYLUS
        }
        val coords = MotionEvent.PointerCoords().apply { x = 1f; y = 1f; pressure = 0.5f }
        return MotionEvent.obtain(
            0L, eventTimeMs, MotionEvent.ACTION_MOVE, 1,
            arrayOf(props), arrayOf(coords),
            0, 0, 1f, 1f, 0, 0, InputDevice.SOURCE_STYLUS, 0
        )
    }

    @Test
    fun percentileHandlesTheHundredthWithoutGoingOutOfBounds() {
        // size*p/100 這種寫法在 p=100 時會越界 —— 而那正是「最差情況」，
        // 是量延遲時最該看的那個數字。
        val meter = InkLatencyMeter()
        val e = event(10)
        repeat(5) { meter.record(e, nowNanos = e.eventTimeNanos + 1_000_000L) }
        e.recycle()
        assertEquals(1_000L, meter.percentileUs(100))
        assertEquals(1_000L, meter.percentileUs(0))
    }

    @Test
    fun negativeDeltasAreDiscardedInsteadOfPollutingTheStats() {
        // 少數裝置的事件時鐘與 System.nanoTime() 不同源，會算出負延遲。
        val meter = InkLatencyMeter()
        val e = event(10)
        meter.record(e, nowNanos = e.eventTimeNanos - 5_000_000L)
        e.recycle()
        assertEquals(0, meter.count)
    }

    @Test
    fun theBufferDoesNotGrowWithoutBound() {
        // 連續書寫十分鐘不該讓這個量測器自己變成記憶體問題。
        val meter = InkLatencyMeter(capacity = 8)
        val e = event(10)
        repeat(100) { meter.record(e, nowNanos = e.eventTimeNanos + 1_000_000L) }
        e.recycle()
        assertEquals(8, meter.count)
    }

    @Test
    fun summaryIsReadableWithNoSamples() {
        assertTrue(InkLatencyMeter().summaryMs().isNotBlank())
    }
}
