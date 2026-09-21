package com.kairumo.padnote.ink

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import uniffi.padnote_core.StrokePoint
import uniffi.padnote_core.ToolKind

class InkBrushRendererTest {

    private fun dummyPoints(count: Int = 10): List<StrokePoint> {
        return (0 until count).map { i ->
            StrokePoint(
                x = i * 10f,
                y = i * 5f,
                pressure = 1.0f,
                tilt = 0f,
                azimuth = 0f,
                dtUs = 16_000u
            )
        }
    }

    @Test
    fun testAllToolsProduceSegments() {
        val points = dummyPoints(8)
        val tools = listOf(
            ToolKind.FOUNTAIN_PEN,
            ToolKind.BALL_POINT,
            ToolKind.BRUSH,
            ToolKind.MARKER,
            ToolKind.HIGHLIGHTER,
            ToolKind.PENCIL,
            ToolKind.WATERCOLOR
        )

        for (tool in tools) {
            val segments = InkBrushRenderer.computeSegments(points, tool, baseWidth = 3f, density = 2f)
            assertEquals("Tool $tool should produce N-1 segments", points.size - 1, segments.size)
        }
    }

    @Test
    fun testHighlighterHasSquareCapAndWideStroke() {
        val points = dummyPoints(6)
        val segments = InkBrushRenderer.computeSegments(points, ToolKind.HIGHLIGHTER, baseWidth = 3f, density = 1f)
        assertTrue(segments.isNotEmpty())
        assertTrue("Highlighter must use square cap", segments.all { it.isSquareCap })
        assertTrue("Highlighter should have wide width (> 10dp)", segments.all { it.width >= 10f })
        assertTrue("Highlighter alpha should be translucent (around 0.38)", segments.all { it.alpha < 0.5f })
    }

    @Test
    fun testWatercolorHasDualLayerWash() {
        val points = dummyPoints(6)
        val segments = InkBrushRenderer.computeSegments(points, ToolKind.WATERCOLOR, baseWidth = 3f, density = 1f)
        assertTrue(segments.isNotEmpty())
        assertTrue("Watercolor must have secondary inner width", segments.all { it.secondaryWidth > 0f })
        assertTrue("Watercolor secondary alpha must be set", segments.all { it.secondaryAlpha > 0f })
    }

    @Test
    fun testPencilHasGrainJitter() {
        val points = dummyPoints(12)
        val segments = InkBrushRenderer.computeSegments(points, ToolKind.PENCIL, baseWidth = 3f, density = 1f)
        assertTrue(segments.isNotEmpty())
        val hasNonZeroJitter = segments.any { it.jitterX != 0f || it.jitterY != 0f }
        assertTrue("Pencil must have texture jitter to simulate graphite grain", hasNonZeroJitter)
    }

    @Test
    fun testCalligraphyBrushHasTaperDynamics() {
        val points = dummyPoints(12)
        val segments = InkBrushRenderer.computeSegments(points, ToolKind.BRUSH, baseWidth = 3f, density = 1f)
        assertTrue(segments.isNotEmpty())
        val startSegmentWidth = segments.first().width
        val midSegmentWidth = segments[segments.size / 2].width
        assertNotEquals("Brush tip should taper relative to middle stroke body", startSegmentWidth, midSegmentWidth, 0.01f)
        assertFalse("Brush should not have square cap", segments.any { it.isSquareCap })
    }

    @Test
    fun testBallPointIsMonoline() {
        val points = dummyPoints(8)
        val segments = InkBrushRenderer.computeSegments(points, ToolKind.BALL_POINT, baseWidth = 4f, density = 1f)
        val widths = segments.map { it.width }
        val firstWidth = widths.first()
        assertTrue("Ballpoint pen must have uniform monoline width", widths.all { it == firstWidth })
    }
}
