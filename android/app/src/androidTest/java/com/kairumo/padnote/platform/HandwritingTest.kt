package com.kairumo.padnote.platform

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.StrokePoint

/**
 * 手寫辨識的可測部分（工作包 WP7）。
 *
 * 辨識本身要下載模型、要網路，測起來會變成在測 Google 的服務。這裡測的是
 * **我們自己寫的那些決定**：筆畫怎麼分組、怎麼轉成 ML Kit 的資料結構、
 * 失敗時說了什麼。那些才是會出錯又不會有人發現的地方。
 */
@RunWith(AndroidJUnit4::class)
class HandwritingTest {

    private fun stroke(vararg dtUs: Int): List<StrokePoint> =
        dtUs.mapIndexed { i, dt -> StrokePoint(i * 5f, 100f, 0.5f, 0.3f, 1f, dt.toUInt()) }

    private fun longStroke(points: Int, dtUs: Int): List<StrokePoint> =
        (0 until points).map { StrokePoint(it * 2f, 100f, 0.5f, 0.3f, 1f, dtUs.toUInt()) }

    // MARK: - 分組

    @Test
    fun strokesWrittenBackToBackStayInOneGroup() {
        // 一個中文字往往是好幾筆。逐筆送去辨識的話中文會整個垮掉。
        val ids = listOf("a", "b", "c")
        val strokes = listOf(stroke(0, 8_000), stroke(0, 8_000), stroke(0, 8_000))
        val times = listOf(1_000L, 1_020L, 1_040L)   // 每筆之間只停 12ms
        val groups = Handwriting.group(ids, strokes, times)
        assertEquals(1, groups.size)
        assertEquals(listOf("a", "b", "c"), groups.first().strokeIds)
    }

    @Test
    fun aPauseStartsANewGroup() {
        val ids = listOf("a", "b")
        val strokes = listOf(stroke(0, 8_000), stroke(0, 8_000))
        val times = listOf(1_000L, 3_000L)   // 停了兩秒
        assertEquals(2, Handwriting.group(ids, strokes, times).size)
    }

    @Test
    fun theGapIsMeasuredFromTheEndOfThePreviousStrokeNotItsStart() {
        // 一筆長長的橫畫寫了 600ms，下一筆在 100ms 後落下 —— 那是連著寫的。
        // 若從**開始**時刻量，會算成停了 700ms 而錯誤切開。
        val ids = listOf("a", "b")
        val held = longStroke(points = 60, dtUs = 10_000)   // 60 點 × 10ms = 600ms
        val strokes = listOf(held, stroke(0, 8_000))
        val times = listOf(1_000L, 1_700L)
        assertEquals(1, Handwriting.group(ids, strokes, times).size)
    }

    @Test
    fun emptyInputProducesNoGroups() {
        assertTrue(Handwriting.group(emptyList(), emptyList(), emptyList()).isEmpty())
    }

    // MARK: - 轉成 ML Kit 的資料

    @Test
    fun inkKeepsEveryStrokeAndEveryPoint() {
        // 少一點在畫面上看不出來，但辨識率會莫名其妙地差。
        val ink = Handwriting.buildInk(listOf(stroke(0, 8_000, 8_000), stroke(0, 8_000)))
        assertEquals(2, ink.strokes.size)
        assertEquals(3, ink.strokes[0].points.size)
        assertEquals(2, ink.strokes[1].points.size)
    }

    @Test
    fun inkTimestampsAreCumulativeNotTheRawIntervals() {
        // 核心存的是「距前一點的間隔」，ML Kit 要的是時間戳。
        // 直接把間隔填進去，每一點看起來都發生在同一瞬間。
        val ink = Handwriting.buildInk(listOf(stroke(0, 8_000, 8_000)))
        val ts = ink.strokes[0].points.map { p -> p.timestamp }
        assertEquals(listOf(0L, 8L, 16L), ts)
    }

    // MARK: - 語言與模型

    @Test
    fun theLanguagesWeShipHaveModels() {
        for (tag in listOf("zh-Hant", "zh-Hans", "en", "ja", "ko", "th")) {
            assertNotNull("「$tag」沒有對應的手寫模型", Handwriting.modelIdentifier(tag))
        }
    }

    @Test
    fun anUnknownLanguageReturnsNullInsteadOfThrowing() {
        assertNull(Handwriting.modelIdentifier("xx-YY-not-a-language"))
    }

    // MARK: - 失敗訊息

    @Test
    fun everyFailureSaysSomethingActionable() {
        // 「辨識失敗」四個字幫不了使用者 —— 尤其是「這台裝置沒有 Play 服務」
        // 這種他自己永遠猜不到的原因。
        val messages = listOf(
            Handwriting.describe(Handwriting.Failure.Unsupported("no gms")),
            Handwriting.describe(Handwriting.Failure.NoModel("zz")),
            Handwriting.describe(Handwriting.Failure.DownloadFailed("timeout")),
            Handwriting.describe(Handwriting.Failure.RecognitionFailed("boom"))
        )
        assertTrue(messages.all { it.length > 8 })
        assertTrue(messages[0].contains("Google Play"))
        assertTrue(messages[2].contains("Wi-Fi"))
    }
}
