package com.kairumo.padnote.chart

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 圖表版面一律在頁面點裡算、畫的時候整張乘上密度（I4 畫面同源）。
 *
 * 原本拿像素直接算版面：側欄縮圖（0.22 倍）裡一張 400 點寬的圖只剩 88 像素，
 * 固定像素的軸標與邊距吃光繪圖區，預覽只看得到一個空框。
 */
class ChartPointScaleTest {

    @Test
    fun `縮圖與畫布換算回同一個頁面點尺寸`() {
        val chartWidthPt = 400f
        for (density in listOf(0.22f, 1f, 2.625f, 3.5f)) {
            val px = chartWidthPt * density
            assertEquals(chartWidthPt, px / ChartRenderer.pointScale(density), 0.01f)
        }
    }

    @Test
    fun `異常密度退回 1`() {
        assertEquals(1f, ChartRenderer.pointScale(0f), 0f)
        assertEquals(1f, ChartRenderer.pointScale(-2f), 0f)
        assertEquals(1f, ChartRenderer.pointScale(Float.NaN), 0f)
        assertEquals(1f, ChartRenderer.pointScale(Float.POSITIVE_INFINITY), 0f)
    }
}
