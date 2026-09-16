package com.kairumo.padnote.platform

import android.graphics.BitmapFactory
import android.graphics.Color
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.BlockStyle
import uniffi.padnote_core.PadnoteSession
import java.io.File

/**
 * 縮圖與 PNG 匯出上的文字必須是**真的字**（工作項 S-60）。
 *
 * 核心的純 Rust 光柵化器把文字畫成灰色行條，一本只打字的筆記因此在
 * Android 的縮圖上看不到半個字，而同一本在 iPad 上看得到 —— 這條測試守的
 * 就是那個差異不要回來。
 */
@RunWith(AndroidJUnit4::class)
class PageImageRendererTest {

    private fun inkPixels(text: String?): Int {
        val ctx = InstrumentationRegistry.getInstrumentation().targetContext
        val dir = File(ctx.cacheDir, "pir-${System.nanoTime()}")
        val s = PadnoteSession.create(dir.absolutePath, "字型", 1_757_635_200_000uL, 0xC0u)
        val page = s.firstPageId()!!
        if (text != null) s.addText(page, text, BlockStyle.HEADING1)
        val png = PageImageRenderer.renderPng(s, page, 2f, ctx.cacheDir)
        val bmp = BitmapFactory.decodeByteArray(png, 0, png.size)
        var dark = 0
        for (y in 0 until bmp.height) for (x in 0 until bmp.width) {
            val c = bmp.getPixel(x, y)
            if (Color.red(c) < 120 && Color.green(c) < 120 && Color.blue(c) < 120) dark++
        }
        return dark
    }

    @Test
    fun chineseTextIsDrawnAsRealGlyphsNotTofuOrGreyBars() {
        // **筆畫密度是唯一問得出真假的問題。** 灰條、豆腐框（▯）、真字形
        // 三者都會有暗像素，光看「有沒有墨」分不出來。但筆畫少的字與筆畫多的
        // 字，只有真字形才會差很多 —— 灰條與豆腐框畫出來兩者一模一樣。
        val light = inkPixels("一一一一一一一一")
        val heavy = inkPixels("鬱鬱鬱鬱鬱鬱鬱鬱")
        assertTrue("「一」該有墨，實得 $light", light > 0)
        assertTrue(
            "「鬱」的墨量該遠多於「一」，實得 heavy=$heavy light=$light —— " +
                "兩者接近代表畫出來的是灰條或豆腐框，不是字",
            heavy > light * 3
        )
    }

    @Test
    fun aPageWithOnlyTypedTextIsNotBlank() {
        // 只打字沒手寫的筆記，縮圖不可以是一張空白頁。
        val blank = inkPixels(null)
        val typed = inkPixels("特徵值與特徵向量")
        assertTrue("只打字的頁面縮圖不該與空白頁一樣（$typed vs $blank）", typed > blank + 200)
    }
}
