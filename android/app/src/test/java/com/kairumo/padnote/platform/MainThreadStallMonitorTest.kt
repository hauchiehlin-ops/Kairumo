package com.kairumo.padnote.platform

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MainThreadStallMonitorTest {
    @Test
    fun theStackIsFormattedOneFramePerLineAndCapped() {
        val frames = Array(50) { StackTraceElement("com.kairumo.Foo", "bar$it", "Foo.kt", it + 1) }
        val text = MainThreadStallMonitor.formatStack(frames)
        val lines = text.lines()
        assertEquals(30, lines.size)
        assertTrue(lines.first().contains("com.kairumo.Foo.bar0(Foo.kt:1)"))
    }
}
