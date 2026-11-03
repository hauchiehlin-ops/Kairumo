package com.kairumo.padnote.library

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test
import java.util.Calendar

/** 新筆記本預設名稱「時-分-秒-New」（與 Apple `NotebookNamingTests` 同一組案例）。 */
class NotebookNamingTest {
    private fun at(h: Int, m: Int, s: Int) = Calendar.getInstance().apply {
        set(2026, Calendar.NOVEMBER, 3, h, m, s)
    }

    @Test
    fun usesTwentyFourHourClockWithHyphens() {
        assertEquals("23-30-15-New", NotebookNaming.newTitle(at(23, 30, 15)))
    }

    @Test
    fun padsSingleDigits() {
        assertEquals("09-05-07-New", NotebookNaming.newTitle(at(9, 5, 7)))
    }

    /** 冒號在 exFAT／Windows 不能當檔名。 */
    @Test
    fun containsNoColon() {
        assertFalse(NotebookNaming.newTitle().contains(":"))
    }
}
