package com.kairumo.padnote.text

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 逐字格式（`runs`）。與 Apple 端 `RichTextTests` 逐項對應 —— 兩邊算出的區段不同的話，
 * 同一份筆記在 iPad 上粗體的字，到 Android 上會套在別的字上。
 */
class RichTextTest {

    private fun box(text: String) = TextBox(id = "t", text = text)

    @Test fun boldOnASelectionOnlyTouchesThoseCharacters() {
        val b = box("Hello world")
        RichText.apply(b, TextCharStyle(bold = true), 6, 11)
        assertEquals(listOf(TextStyleRun(6, 5, TextCharStyle(bold = true))), b.runs)
        assertFalse(b.bold)
        assertFalse(RichText.resolvedStyleAt(b, 0, 1).bold)
        assertTrue(RichText.resolvedStyleAt(b, 6, 8).bold)
    }

    @Test fun overridesEqualToTheBoxDefaultAreNotStored() {
        val b = box("abc").apply { fontSize = 20f }
        RichText.apply(b, TextCharStyle(fontSize = 20f), 0, 3)
        assertNull(b.runs)
    }

    @Test fun wholeBoxChangeRemovesTheSameOverride() {
        val b = box("abcdef")
        RichText.apply(b, TextCharStyle(fontSize = 30f, textColorHex = "#FF0000"), 0, 3)
        RichText.applyToWholeBox(b, TextCharStyle(fontSize = 12f))
        assertEquals(12f, b.fontSize, 0.001f)
        assertEquals(listOf(TextStyleRun(0, 3, TextCharStyle(textColorHex = "#FF0000"))), b.runs)
    }

    @Test fun highlightClearRemovesIt() {
        val b = box("重點在這裡")
        RichText.apply(b, TextCharStyle(highlightHex = "#FFFF00"), 0, 2)
        assertEquals("#FFFF00", RichText.resolvedStyleAt(b, 0, 1).highlightHex)
        RichText.apply(b, TextCharStyle(highlightHex = "clear"), 0, 5)
        assertNull(b.runs)
    }

    @Test fun typingInsideABoldRunExtendsIt() {
        val b = box("abcdef")
        RichText.apply(b, TextCharStyle(bold = true), 2, 4)
        RichText.replace(b, 3, 3, "XY")
        assertEquals("abcXYdef", b.text)
        assertEquals(listOf(TextStyleRun(2, 4, TextCharStyle(bold = true))), b.runs)
    }

    @Test fun deletingTextBeforeARunShiftsIt() {
        val b = box("abcdef")
        RichText.apply(b, TextCharStyle(bold = true), 4, 6)
        val old = b.text
        b.text = "cdef"
        RichText.adjustRuns(b, old)
        assertEquals(listOf(TextStyleRun(2, 2, TextCharStyle(bold = true))), b.runs)
    }

    @Test fun listToggleKeepsEachLinesFormatting() {
        val b = box("甲乙\n丙丁")
        RichText.apply(b, TextCharStyle(bold = true), 3, 5)
        applyWordFormat(b, WordFormatAction.ToggleList(WordListKind.BULLET), TextFormatScope.WholeBox)
        assertEquals("• 甲乙\n• 丙丁", b.text)
        assertTrue(RichText.resolvedStyleAt(b, 8, 10).bold)
        assertFalse(RichText.resolvedStyleAt(b, 2, 4).bold)
    }

    @Test fun yearIsNotANumberedListMarker() {
        assertEquals("1. 2024. 年度", WordListKind.NUMBERED.toggle("2024. 年度"))
    }

    @Test fun positionsAreUtf16() {
        // 👍 是兩個 UTF-16 碼元 —— 與 Apple 的 NSRange 同一個單位。
        val b = box("👍好")
        RichText.apply(b, TextCharStyle(bold = true), 2, 3)
        assertEquals(listOf(TextStyleRun(2, 1, TextCharStyle(bold = true))), b.runs)
    }

    @Test fun runsBeyondTheTextAreClamped() {
        val b = box("abc").apply { runs = listOf(TextStyleRun(1, 50, TextCharStyle(bold = true))) }
        assertEquals(listOf(TextStyleRun(1, 2, TextCharStyle(bold = true))), RichText.normalized(b))
    }

    @Test fun wordUnderTheCaret() {
        assertEquals(0 until 5, RichText.wordRange("hello world", 2))
        assertNull(RichText.wordRange("hello world", 5))
        assertNull(RichText.wordRange("hello world", 11))
    }

    @Test fun fontSizeStepsFollowWord() {
        assertEquals(12f, wordGrowFontSize(11f), 0.001f)
        assertEquals(10.5f, wordGrowFontSize(10f), 0.001f)
        assertEquals(80f, wordGrowFontSize(72f), 0.001f)
        assertEquals(10f, wordShrinkFontSize(10.5f), 0.001f)
        assertEquals(72f, wordShrinkFontSize(80f), 0.001f)
    }

    // format-spec §6.2：兩個平台同一組扁平鍵名。

    @Test fun runsSurviveTheAppearanceRoundTrip() {
        val b = box("Hello world").apply { fontFamily = "Georgia" }
        RichText.apply(b, TextCharStyle(bold = true, fontSize = 24f, highlightHex = "#FFFF00"), 6, 11)
        val other = box("Hello world")
        TextBoxAppearance.apply(TextBoxAppearance.encode(b), other)
        assertEquals(b.runs, other.runs)
        assertEquals("Georgia", other.fontFamily)
    }

    @Test fun readsTheJsonApplesEncoderWrites() {
        // Apple 端 `TextBoxAppearance.encode` 寫出的形狀（鍵排序、扁平）。
        val json = """{"bold":false,"fontSize":16,"runs":[{"length":5,"start":6,"underline":true,"textColorHex":"#C00000"}]}"""
        val b = box("Hello world")
        TextBoxAppearance.apply(json, b)
        assertEquals(listOf(TextStyleRun(6, 5, TextCharStyle(underline = true, textColorHex = "#C00000"))), b.runs)
        val run = JSONObject(TextBoxAppearance.encode(b)).getJSONArray("runs").getJSONObject(0)
        assertFalse(run.has("style"))
        assertEquals(6, run.getInt("start"))
    }

    @Test fun missingRunsKeyMeansUniformFormatting() {
        val b = box("abc").apply { runs = listOf(TextStyleRun(0, 1, TextCharStyle(bold = true))) }
        TextBoxAppearance.apply("""{"fontSize":16}""", b)
        assertNull(b.runs)
    }
}
