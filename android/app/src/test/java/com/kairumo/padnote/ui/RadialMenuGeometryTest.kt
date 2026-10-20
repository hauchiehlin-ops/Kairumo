package com.kairumo.padnote.ui

import androidx.compose.ui.geometry.Offset
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 飛梭工具盤的中心：在落點彈出，太靠邊就往內收，整圈都要在畫布區裡。
 *
 * 模擬器上實測過的情形：選單整圈超出畫布區時，壓到底部工具列的那幾格按不到
 * （點下去選到的是工具列上的筆）。
 */
class RadialMenuGeometryTest {
    private val density = 2f
    private val margin = 120f * density

    @Test fun pointWellInsideStaysAtTheTouch() {
        assertEquals(Offset(1000f, 700f), clampRadialCenter(Offset(1000f, 700f), 1960f, 1100f, density))
    }

    @Test fun pointNearAnEdgeIsPulledInSoTheWholeRingFits() {
        val c = clampRadialCenter(Offset(20f, 1090f), 1960f, 1100f, density)
        assertEquals(Offset(margin, 1100f - margin), c)
    }

    @Test fun areaSmallerThanTheRingKeepsTheMarginInsteadOfCrashing() {
        // coerceIn 的上下限顛倒會丟例外；畫布區比整圈還小（分割畫面）時不能閃退。
        val c = clampRadialCenter(Offset(50f, 50f), 100f, 100f, density)
        assertEquals(Offset(margin, margin), c)
    }
}
