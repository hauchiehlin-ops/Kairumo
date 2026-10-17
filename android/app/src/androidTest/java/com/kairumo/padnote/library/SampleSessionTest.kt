package com.kairumo.padnote.library

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.BlockStyle
import uniffi.padnote_core.PadnoteSession
import java.io.File

/**
 * 範例筆記本：打開時備份到暫存區，離開時內容真的有改才問存檔／另存／放棄（[SampleFork]）。
 * 與 Apple `SyncFixesTests` 的範例測試同一組情境。
 */
@RunWith(AndroidJUnit4::class)
class SampleSessionTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val device = 0xE8u
    private lateinit var id: String

    @Before
    fun setUp() {
        clean()
        id = NotebookLibrary.create(context, "我的範例", device)!!
        SampleFork.setSample(context, id, device, true)
    }

    @After
    fun clean() {
        File(context.filesDir, "Notebooks").deleteRecursively()
        File(context.filesDir, "SampleSessions").deleteRecursively()
        NotebookLibrary.invalidateCache()
    }

    private fun texts(notebook: String): List<String> =
        PadnoteSession.openExisting(File(NotebookLibrary.directory(context), "$notebook.padnote").absolutePath, device).use { s ->
            val page = s.pageIdAt(0u)!!
            s.textBlockIds(page).map { s.blockText(it).orEmpty() }
        }

    private fun addText(text: String) {
        PadnoteSession.openExisting(File(NotebookLibrary.directory(context), "$id.padnote").absolutePath, device).use { s ->
            s.addText(s.pageIdAt(0u)!!, text, BlockStyle.BODY)
        }
    }

    @Test
    fun openingWithoutChangesIsNotAnEdit() {
        assertTrue(SampleFork.isSample(context, id, device))
        SampleFork.begin(context, id, device)
        assertTrue(SampleFork.hasSession(context, id))
        assertFalse("只是打開不算修改", SampleFork.hasChanges(context, id, device))
        SampleFork.finish(context, id, device, "zh-Hant", SampleFork.Choice.KEEP)
        assertFalse(SampleFork.hasSession(context, id))
        assertEquals("沒有多出副本", 1, NotebookLibrary.all(context, device).size)
    }

    @Test
    fun savingAsACopyLeavesTheSampleAsItWas() {
        SampleFork.begin(context, id, device)
        addText("我加的字")
        assertTrue(SampleFork.hasChanges(context, id, device))
        val copy = SampleFork.finish(context, id, device, "zh-Hant", SampleFork.Choice.SAVE_COPY)
        assertNotNull(copy)
        assertEquals("修改在副本裡", listOf("我加的字"), texts(copy!!.first))
        assertTrue("範例回到打開前的樣子", texts(id).isEmpty())
        assertFalse("副本是一般筆記本", SampleFork.isSample(context, copy.first, device))
        assertTrue(copy.second.startsWith("我的範例 "))
    }

    @Test
    fun discardingPutsTheSampleBack() {
        SampleFork.begin(context, id, device)
        addText("不要了")
        SampleFork.finish(context, id, device, "zh-Hant", SampleFork.Choice.DISCARD)
        assertTrue(texts(id).isEmpty())
        assertEquals(1, NotebookLibrary.all(context, device).size)
    }

    @Test
    fun keepingSavesIntoTheSample() {
        SampleFork.begin(context, id, device)
        addText("留在範例")
        SampleFork.finish(context, id, device, "zh-Hant", SampleFork.Choice.KEEP)
        assertEquals(listOf("留在範例"), texts(id))
        assertFalse(SampleFork.hasSession(context, id))
    }

    @Test
    fun unmarkingMakesItANormalNotebook() {
        SampleFork.setSample(context, id, device, false)
        assertFalse(SampleFork.isSample(context, id, device))
        SampleFork.begin(context, id, device)
        assertFalse("解除範例之後不再暫存", SampleFork.hasSession(context, id))
    }

    @Test
    fun anUndecidedSessionSurvivesForTheNextLaunch() {
        SampleFork.begin(context, id, device)
        addText("App 被關掉")
        assertEquals(listOf(id), SampleFork.pendingIds(context))
        assertTrue(SampleFork.hasChanges(context, id, device))
    }
}
