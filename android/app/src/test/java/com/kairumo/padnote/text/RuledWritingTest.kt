package com.kairumo.padnote.text

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uniffi.padnote_core.FfiGuide
import uniffi.padnote_core.FfiGuideKind
import uniffi.padnote_core.FfiGuideTone
import uniffi.padnote_core.FfiTextureBand
import uniffi.padnote_core.FfiTextureKind

/**
 * 橫線紙上的「即點即書」幾何測試。與 Apple 端 `RuledWritingTests.swift` 保持完全同構。
 */
class RuledWritingTest {

    private fun band(y: Float, step: Float, count: UInt, vertical: Boolean = false) = FfiTextureBand(
        kind = FfiTextureKind.LINE,
        x = 40f,
        y = y,
        w = if (vertical) 0f else 700f,
        h = if (vertical) 700f else 0f,
        stepX = 0f,
        stepY = step,
        count = count,
        step2X = 0f,
        step2Y = 0f,
        count2 = 1u,
        weight = 0.5f,
        tone = FfiGuideTone.LIGHT
    )

    private fun guide(y: Float) = FfiGuide(
        kind = FfiGuideKind.LINE,
        x = 40f,
        y = y,
        w = 700f,
        h = 0f,
        tone = FfiGuideTone.MUTED,
        weight = 1.0f,
        textKey = "",
        size = 0.0f,
        align = 0u
    )

    private val lined: List<Float>
        get() = RuledWriting.horizontalRules(emptyList(), listOf(band(y = 100f, step = 28f, count = 30u)))

    @Test
    fun stepIsTheMedianGap() {
        assertEquals(28f, RuledWriting.step(lined))
        assertEquals(28f, RuledWriting.step(listOf(20f) + lined))
        assertNull("只有兩條線不是橫線紙", RuledWriting.step(listOf(100f, 400f)))
        assertNull("間距 200 是版面分隔", RuledWriting.step(listOf(100f, 300f, 500f, 700f)))
        // 黃金比例與情緒板等導引線絕不能被誤判為橫線紙
        assertNull("黃金比例與三分構圖僅4條導引線，非橫線紙", RuledWriting.step(listOf(377.3f, 432.4f, 699.5f, 754.7f)))
        assertNull("情緒板間距極度不均勻，非橫線紙", RuledWriting.step(listOf(56.6f, 124.5f, 158.5f, 973.5f, 996.2f, 1076.0f)))
    }

    @Test
    fun baselineSitsOnTheRule() {
        val p = RuledWriting.placement(tapY = 140f, rules = lined, fontSize = 16f, minTop = 40f)
        assertNotNull(p)
        val bottom = p!!.top + RuledWriting.textBottomOffset(p.fontSize)
        assertEquals(p.rule, bottom, 0.01f)
    }

    @Test
    fun everySecondLineLandsOnTheNextRule() {
        val p = RuledWriting.placement(tapY = 140f, rules = lined, fontSize = 16f, minTop = 40f)
        assertNotNull(p)
        assertEquals(p!!.step, RuledWriting.lineHeight(p.fontSize) + p.lineSpacing, 0.01f)
        assertEquals(28f, p.step, 0.001f)
    }
}
