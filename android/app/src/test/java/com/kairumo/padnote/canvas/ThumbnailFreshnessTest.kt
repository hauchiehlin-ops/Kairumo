package com.kairumo.padnote.canvas

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * 側欄縮圖與畫布同源（AGENTS.md I4）。
 *
 * 實機回報：畫布上新貼的貼紙、圖表，左側「頁面結構」預覽沒有出現。
 * 情境重現：在目前頁貼完（revision 前進、縮圖還在去抖動）就切到別頁，
 * 那一頁成了「非目前頁」，舊的基底縮圖被當成最新沿用下去。
 */
class ThumbnailFreshnessTest {

    @Before fun setUp() = ThumbnailFreshness.reset()
    @After fun tearDown() = ThumbnailFreshness.reset()

    private val page = "page-A"

    @Test
    fun `目前頁內容變了之後切走，舊基底縮圖不能沿用`() {
        // 第 10 版算過縮圖；貼紙讓 revision 到 11。
        assertTrue(ThumbnailFreshness.currentPageChanged(isCurrent = true, lastRenderedRevision = 10, revision = 11))
        ThumbnailFreshness.markDirty(page)

        // 還沒算完就切到別頁：這張卡片變成非目前頁。
        val reuse = ThumbnailFreshness.canReuseBase(
            hasBase = true, isCurrent = false, lastRenderedRevision = 10, revision = 12,
            isDirty = ThumbnailFreshness.isDirty(page)
        )
        assertFalse("髒頁面不得拿舊縮圖頂替（I4）", reuse)
    }

    @Test
    fun `重算完成後非目前頁可以沿用基底縮圖`() {
        val gen = ThumbnailFreshness.markDirty(page)
        ThumbnailFreshness.markRendered(page, gen)
        assertFalse(ThumbnailFreshness.isDirty(page))
        assertTrue(
            ThumbnailFreshness.canReuseBase(
                hasBase = true, isCurrent = false, lastRenderedRevision = 3, revision = 9, isDirty = false
            )
        )
    }

    @Test
    fun `重算期間又有新變動，舊那輪算完不能洗掉髒標記`() {
        val first = ThumbnailFreshness.markDirty(page)
        val second = ThumbnailFreshness.markDirty(page) // 又縮放了一次貼紙
        ThumbnailFreshness.markRendered(page, first)
        assertTrue("較新的變動還沒畫進縮圖", ThumbnailFreshness.isDirty(page))
        ThumbnailFreshness.markRendered(page, second)
        assertFalse(ThumbnailFreshness.isDirty(page))
    }

    @Test
    fun `目前頁只有依同一版算過才沿用`() {
        assertTrue(
            ThumbnailFreshness.canReuseBase(
                hasBase = true, isCurrent = true, lastRenderedRevision = 5, revision = 5, isDirty = false
            )
        )
        assertFalse(
            ThumbnailFreshness.canReuseBase(
                hasBase = true, isCurrent = true, lastRenderedRevision = 5, revision = 6, isDirty = false
            )
        )
    }

    @Test
    fun `沒有基底縮圖一定重算`() {
        assertFalse(
            ThumbnailFreshness.canReuseBase(
                hasBase = false, isCurrent = false, lastRenderedRevision = 1, revision = 1, isDirty = false
            )
        )
    }

    @Test
    fun `第一次組合不算內容變動`() {
        // -1 是剛建立的卡片，還沒算過縮圖 —— 不是「內容變了」，不應把整排頁面標髒。
        assertFalse(ThumbnailFreshness.currentPageChanged(isCurrent = true, lastRenderedRevision = -1, revision = 7))
        assertFalse(ThumbnailFreshness.currentPageChanged(isCurrent = false, lastRenderedRevision = 3, revision = 7))
    }

    @Test
    fun `換設定檔清空後不殘留髒標記`() {
        ThumbnailFreshness.markDirty(page)
        ThumbnailFreshness.reset()
        assertEquals(0, ThumbnailFreshness.generation(page))
    }
}
