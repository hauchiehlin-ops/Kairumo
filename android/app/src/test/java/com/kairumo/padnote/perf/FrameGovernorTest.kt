package com.kairumo.padnote.perf

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FrameGovernorTest {
    private val target = 1000.0 / 120

    private fun feed(g: FrameGovernor, over: Int, ok: Int) {
        repeat(over) { g.ingest(target * 3, target) }
        repeat(ok) { g.ingest(target, target) }
    }

    @Test fun smoothFramesStayNormal() {
        val g = FrameGovernor()
        feed(g, 0, 200)
        assertEquals(FrameGovernor.Level.Normal, g.level)
        assertEquals(0L, g.thumbnailGapMs)
    }

    @Test fun sustainedHitchesConstrainThenRecoverWithHysteresis() {
        val g = FrameGovernor()
        feed(g, 30, 30)
        assertEquals(FrameGovernor.Level.Constrained, g.level)
        assertTrue(g.thumbnailGapMs > 0)
        // 持續約 16% 超時（低於進入門檻、高於離開門檻）：維持原狀，不來回跳。
        repeat(20) { feed(g, 1, 5) }
        assertEquals(FrameGovernor.Level.Constrained, g.level)
        feed(g, 0, 60)
        assertEquals(FrameGovernor.Level.Normal, g.level)
    }

    @Test fun aSingleHitchDoesNotConstrain() {
        val g = FrameGovernor()
        feed(g, 1, 100)
        assertEquals(FrameGovernor.Level.Normal, g.level)
    }
}
