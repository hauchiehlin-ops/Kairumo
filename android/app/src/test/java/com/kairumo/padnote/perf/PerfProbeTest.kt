package com.kairumo.padnote.perf

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PerfProbeTest {
    private fun probe() = PerfProbe(PerfProbe.Tracer.None)

    @Test fun statsReportPercentilesAndOverBudgetCount() {
        val p = probe()
        for (ms in listOf(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 100.0)) p.record(PerfPoint.StrokeEnd, ms)
        val s = p.stats(PerfPoint.StrokeEnd)
        assertEquals(10, s.count)
        assertEquals(100.0, s.maxMs, 0.0)
        assertEquals(5.0, s.p50Ms, 0.0)
        assertEquals("預算 8 ms：9 與 100 超標", 2, s.overBudget)
    }

    @Test fun emptyPointReportsNothing() {
        assertEquals(PerfProbe.Stats(), probe().stats(PerfPoint.PageSwitch))
    }

    @Test fun ringBufferIsBounded() {
        val p = probe()
        repeat(1000) { p.record(PerfPoint.ToolSwitch, 1.0) }
        assertEquals(256, p.stats(PerfPoint.ToolSwitch).count)
    }

    @Test fun measureRecordsAndReturnsValue() {
        val p = probe()
        assertEquals(42, p.measure(PerfPoint.PageLoad) { 42 })
        assertEquals(1, p.stats(PerfPoint.PageLoad).count)
    }

    @Test fun measureRecordsEvenWhenTheBodyThrows() {
        val p = probe()
        runCatching { p.measure(PerfPoint.PageSave) { error("boom") } }
        assertEquals(1, p.stats(PerfPoint.PageSave).count)
    }

    @Test fun countersAreIndependentAndResettable() {
        val p = probe()
        p.count(CostCounter.BackingPatch); p.count(CostCounter.BackingPatch, 2)
        assertEquals(3, p.counter(CostCounter.BackingPatch))
        assertEquals(0, p.counter(CostCounter.BackingFullRebuild))
        p.reset()
        assertEquals(0, p.counter(CostCounter.BackingPatch))
    }

    @Test fun budgetsMatchTheAppleSide() {
        // 兩個平台用同一組預算 —— 同一個動作的標準不該因平台而異。
        val expected = mapOf(
            PerfPoint.StrokeEnd to 8.0, PerfPoint.ToolSwitch to 16.0, PerfPoint.PageSwitch to 50.0,
            PerfPoint.PageSave to 16.0, PerfPoint.PageLoad to 33.0, PerfPoint.ThumbnailRender to 16.0)
        for ((point, budget) in expected) assertEquals(point.name, budget, point.budgetMs, 0.0)
        assertTrue(PerfPoint.entries.size == expected.size)
    }
}
