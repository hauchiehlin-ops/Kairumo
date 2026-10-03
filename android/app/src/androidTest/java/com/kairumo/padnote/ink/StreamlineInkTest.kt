package com.kairumo.padnote.ink

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import uniffi.padnote_core.StrokePoint
import uniffi.padnote_core.streamlineSmoothPoints

class StreamlineInkTest {

    @Test
    fun testStreamlineSmoothPointsPreservesCountAndTapersTail() {
        val input = listOf(
            StrokePoint(x = 0f, y = 0f, pressure = 0.8f, tilt = 0f, azimuth = 0f, dtUs = 0u),
            StrokePoint(x = 10f, y = 3f, pressure = 0.8f, tilt = 0f, azimuth = 0f, dtUs = 10u),
            StrokePoint(x = 20f, y = -3f, pressure = 0.8f, tilt = 0f, azimuth = 0f, dtUs = 20u),
            StrokePoint(x = 30f, y = 2f, pressure = 0.8f, tilt = 0f, azimuth = 0f, dtUs = 30u),
            StrokePoint(x = 40f, y = 0f, pressure = 0.8f, tilt = 0f, azimuth = 0f, dtUs = 40u)
        )

        val smoothed = streamlineSmoothPoints(input, amount = 0.4f, gamma = 1.0f, taper = 0.25f, tension = 0.35f)
        assertEquals(input.size, smoothed.size)
        assertEquals(0f, smoothed.first().x, 0.001f)
        assertEquals(40f, smoothed.last().x, 0.001f)

        // 揮筆收尾出鋒驗證
        assertTrue("尾部壓感必須因出鋒大幅衰減", smoothed.last().pressure < 0.3f)
    }

    @Test
    fun testStreamlineEmptyInputIsSafe() {
        val empty = streamlineSmoothPoints(emptyList(), amount = 0.5f, gamma = 1.0f, taper = 0.2f, tension = 0.3f)
        assertTrue(empty.isEmpty())
    }
}
