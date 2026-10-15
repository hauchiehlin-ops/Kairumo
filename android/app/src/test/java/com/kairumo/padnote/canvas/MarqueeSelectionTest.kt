package com.kairumo.padnote.canvas

import androidx.compose.ui.geometry.Offset
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
}
