package com.kairumo.padnote.canvas

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** 框選的選取規則：一般／連續框選、點選切換、最上層命中。與 Apple 端 `MarqueeSelectionTests` 對應。 */
class MarqueeSelectionTest {

    @Test fun aNewMarqueeReplacesTheSelectionByDefault() {
        assertEquals(setOf("b"), ObjectMarquee.combined(setOf("a"), setOf("b"), additive = false))
    }

    @Test fun continuousMarqueeAccumulates() {
        assertEquals(setOf("a", "b"), ObjectMarquee.combined(setOf("a"), setOf("b"), additive = true))
    }

    @Test fun tappingTogglesInContinuousMode() {
        assertEquals(setOf("a", "b"), ObjectMarquee.tapped("b", setOf("a"), additive = true))
        assertEquals(setOf("a"), ObjectMarquee.tapped("b", setOf("a", "b"), additive = true))
    }

    @Test fun tappingSelectsOnlyThatObjectNormally() {
        assertEquals(setOf("b"), ObjectMarquee.tapped("b", setOf("a"), additive = false))
    }

    @Test fun tappingBlankClearsNormallyButKeepsAccumulatedSelection() {
        assertEquals(emptySet<String>(), ObjectMarquee.tapped(null, setOf("a"), additive = false))
        assertEquals(setOf("a"), ObjectMarquee.tapped(null, setOf("a"), additive = true))
    }

    @Test fun topmostHitPrefersTheObjectOnTop() {
        val below = MarqueeHit("below", 0f, 0f, 100f, 100f)
        val above = MarqueeHit("above", 50f, 50f, 100f, 100f)
        assertEquals("above", ObjectMarquee.topmostHit(Offset(60f, 60f), listOf(below, above)))
        assertEquals("below", ObjectMarquee.topmostHit(Offset(10f, 10f), listOf(below, above)))
        assertNull(ObjectMarquee.topmostHit(Offset(500f, 500f), listOf(below, above)))
    }

    @Test fun pasteOriginsDefaultOffsetAndArbitraryTargetPoint() {
        val frames = listOf(
            Rect(100f, 100f, 200f, 160f),
            Rect(220f, 140f, 300f, 220f)
        )
        // 1. Default paste: offset by (24, 24)
        val defaultOrigins = ObjectMarquee.pasteOrigins(frames, targetPoint = null)
        assertEquals(2, defaultOrigins.size)
        assertEquals(124f, defaultOrigins[0].x, 0.01f)
        assertEquals(124f, defaultOrigins[0].y, 0.01f)
        assertEquals(244f, defaultOrigins[1].x, 0.01f)
        assertEquals(164f, defaultOrigins[1].y, 0.01f)

        // 2. Arbitrary target point: union bounds is [100..300, 100..220] -> center (200, 160)
        // Pasting at (400, 500) shifts both by (+200, +340) while preserving relative offset (120, 40)
        val targetedOrigins = ObjectMarquee.pasteOrigins(frames, targetPoint = Offset(400f, 500f))
        assertEquals(300f, targetedOrigins[0].x, 0.01f)
        assertEquals(440f, targetedOrigins[0].y, 0.01f)
        assertEquals(420f, targetedOrigins[1].x, 0.01f)
        assertEquals(480f, targetedOrigins[1].y, 0.01f)
        assertEquals(120f, targetedOrigins[1].x - targetedOrigins[0].x, 0.01f)
        assertEquals(40f, targetedOrigins[1].y - targetedOrigins[0].y, 0.01f)
    }
}
