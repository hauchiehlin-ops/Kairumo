package com.kairumo.padnote.image

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 圖片／貼紙縮放（實機回報：貼紙只能放大、不能縮小）。
 *
 * 規則對照 Apple `EditorAttachments` 的圖片縮放把手：等比、寬下限 80、高下限 60。
 */
class ImageResizeTest {

    private val eps = 0.001f

    @Test
    fun `預設 120 的貼紙可以往左上縮小`() {
        // 原本共用文字方塊的下限 120×60：貼紙一插進來就卡在下限，往內拖完全不動。
        val (w, h) = ImageResize.resized(120f, 120f, dx = -30f, dy = -30f)
        assertTrue("寬應變小，實際 $w", w < 120f)
        assertTrue("高應變小，實際 $h", h < 120f)
    }

    @Test
    fun `縮小保持原比例`() {
        val (w, h) = ImageResize.resized(200f, 100f, dx = -40f, dy = -20f)
        assertEquals(0.5f, h / w, eps)
    }

    @Test
    fun `縮小停在與 Apple 相同的下限`() {
        val (w, h) = ImageResize.resized(120f, 120f, dx = -500f, dy = -500f)
        assertEquals(ImageResize.MIN_WIDTH_DP, w, eps)
        assertEquals(80f, h, eps) // 正方形：高跟著寬等比，仍高於高下限 60
    }

    @Test
    fun `比下限還小的貼紙往內拖不會反而跳大`() {
        // 滑桿可以放 60 dp 的貼紙；套用 80 的下限的話，一碰把手就變成 80。
        val (w, h) = ImageResize.resized(60f, 60f, dx = -10f, dy = -10f)
        assertEquals(60f, w, eps)
        assertEquals(60f, h, eps)
    }

    @Test
    fun `往右下拉放大`() {
        val (w, h) = ImageResize.resized(120f, 120f, dx = 40f, dy = 40f)
        assertEquals(160f, w, eps)
        assertEquals(160f, h, eps)
    }

    @Test
    fun `只往上推也能縮小`() {
        // 只看水平位移的話，往上推毫無反應 —— 使用者會以為又是「縮不了」。
        val (w, _) = ImageResize.resized(150f, 150f, dx = 0f, dy = -40f)
        assertTrue("只往上推應縮小，實際 $w", w < 150f)
    }

    @Test
    fun `來回拖曳以起點為準不累積誤差`() {
        val (w1, h1) = ImageResize.resized(120f, 90f, dx = -20f, dy = -15f)
        val (w2, h2) = ImageResize.resized(120f, 90f, dx = 0f, dy = 0f)
        assertTrue(w1 < 120f && h1 < 90f)
        assertEquals(120f, w2, eps)
        assertEquals(90f, h2, eps)
    }

    @Test
    fun `退化尺寸不會除以零`() {
        val (w, h) = ImageResize.resized(0f, 0f, dx = 10f, dy = 10f)
        assertTrue(w.isFinite() && h.isFinite())
    }
}
