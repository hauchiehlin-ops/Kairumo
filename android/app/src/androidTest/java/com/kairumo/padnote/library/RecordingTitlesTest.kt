package com.kairumo.padnote.library

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.PadnoteSession
import java.io.File

/**
 * 錄音名稱的寫入端：寫進套件的 `rectitle` 區塊，要讀得回來（也就是 Apple 讀得到的同一個格式）。
 * 改名是同一個區塊的第二次寫入，不能長出第二份。
 */
@RunWith(AndroidJUnit4::class)
class RecordingTitlesTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val deviceId = 0xB1u
    private val pkg get() = File(context.filesDir, "rectitle-test.padnote")

    @Before
    @After
    fun clean() {
        pkg.deleteRecursively()
    }

    private fun session(): PadnoteSession {
        if (!pkg.exists()) {
            PadnoteSession.create(pkg.absolutePath, "T", System.currentTimeMillis().toULong(), deviceId)
        }
        return PadnoteSession.openExisting(pkg.absolutePath, deviceId)
    }

    @Test
    fun aWrittenTitleReadsBack() {
        val s = session()
        assertTrue(RecordingTitles.write(s, "Abc.OPUS", "週會紀錄"))
        s.close()
        assertEquals("週會紀錄", RecordingIndex.titlesIn(pkg, deviceId)["abc.opus"])
    }

    @Test
    fun aRenameReplacesTheTitleWithoutAddingABlock() {
        val s = session()
        RecordingTitles.write(s, "a.opus", "舊")
        val page = s.pageIdAt(0u)!!
        val before = s.imageBlockIds(page).size
        assertTrue(RecordingTitles.write(s, "a.opus", "新"))
        assertEquals(before, s.imageBlockIds(page).size)
        s.close()
        assertEquals("新", RecordingIndex.titlesIn(pkg, deviceId)["a.opus"])
    }

    @Test
    fun aBlankTitleIsRefused() {
        val s = session()
        assertFalse(RecordingTitles.write(s, "a.opus", "   "))
        s.close()
    }
}
