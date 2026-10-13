package com.kairumo.padnote.library

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.UUID

class RecordingIndexNameTest {
    /** 組一個 v7 UUID：前 48 位元是毫秒時間戳。 */
    private fun v7(ms: Long): UUID {
        val msb = (ms shl 16) or 0x7000L or 0x0abcL
        val lsb = (2L shl 62) or 0x0123456789abL
        return UUID(msb, lsb)
    }

    @Test
    fun theTimestampInAV7NameIsTheRecordingTime() {
        val ms = 1_791_895_800_000L
        assertEquals(ms, RecordingIndex.recordedAtFromName("${v7(ms)}.opus", fallback = 5L))
    }

    @Test
    fun nonV7OrAbsurdTimesFallBack() {
        assertEquals(5L, RecordingIndex.recordedAtFromName("${UUID.randomUUID()}.opus", 5L)) // v4
        assertEquals(5L, RecordingIndex.recordedAtFromName("take-3.m4a", 5L))
        assertEquals(5L, RecordingIndex.recordedAtFromName("${v7(1000L)}.opus", 5L))
    }
}
