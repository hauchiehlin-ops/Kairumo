package com.kairumo.padnote.ink

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class BackingDiffTest {
    private fun diff(baked: List<String>, current: List<String>, max: Int = 8) =
        BackingDiff.diff(baked, current, max) { a, b -> a == b }

    @Test fun removingStrokesFromTheMiddleIsAPatch() {
        val d = diff(listOf("a", "b", "c", "d"), listOf("a", "c", "d"))
        assertNotNull(d)
        assertEquals(listOf("b"), d!!.removed)
        assertEquals(emptyList<String>(), d.inserted)
    }

    @Test fun restoringAStrokeInTheMiddleIsAPatch() {
        val d = diff(listOf("a", "c"), listOf("a", "b", "c"))
        assertEquals(listOf("b"), d!!.inserted)
        assertEquals(emptyList<String>(), d.removed)
    }

    @Test fun removingFromTheEndAndFrontAreBothPatches() {
        assertEquals(listOf("d"), diff(listOf("a", "b", "c", "d"), listOf("a", "b", "c"))!!.removed)
        assertEquals(listOf("a"), diff(listOf("a", "b", "c"), listOf("b", "c"))!!.removed)
    }

    @Test fun reorderingOrReplacingIsNotAPatch() {
        assertNull(diff(listOf("a", "b", "c"), listOf("a", "c", "b", "x")))
        assertNull("同樣數量＝替換或換序", diff(listOf("a", "b"), listOf("a", "x")))
    }

    @Test fun tooManyChangesFallBackToAFullRebuild() {
        val baked = (1..20).map { "s$it" }
        assertNull(diff(baked, baked.take(5)))
        assertNotNull(diff(baked, baked.take(15)))
    }

    @Test fun emptyToEmptyAndUnchangedAreNotPatches() {
        assertNull(diff(emptyList(), emptyList()))
        assertNull(diff(listOf("a"), listOf("a")))
    }

    @Test fun clearingEverythingWithinTheLimitIsAPatchOfAllStrokes() {
        val d = diff(listOf("a", "b"), emptyList())
        assertEquals(listOf("a", "b"), d!!.removed)
    }
}
