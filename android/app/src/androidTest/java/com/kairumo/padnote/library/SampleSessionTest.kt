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
import uniffi.padnote_core.StrokePoint
import uniffi.padnote_core.ToolKind
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
        id = NotebookLibrary.create(context, "My Sample", device)!!
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

    private fun strokeCount(notebook: String): Int =
        PadnoteSession.openExisting(File(NotebookLibrary.directory(context), "$notebook.padnote").absolutePath, device).use { s ->
            val page = s.pageIdAt(0u)!!
            s.visibleStrokes(page).size
        }

    private fun addSampleStroke(): String =
        PadnoteSession.openExisting(File(NotebookLibrary.directory(context), "$id.padnote").absolutePath, device).use { s ->
            val page = s.pageIdAt(0u)!!
            val points = listOf(
                StrokePoint(10f, 10f, 0.5f, 0f, 0f, 0u, 0f),
                StrokePoint(20f, 20f, 0.5f, 0f, 0f, 1000u, 0f)
            )
            s.addStroke(page, ToolKind.BALL_POINT, byteArrayOf(0, 0, 0, -1), 2f, points)
        }

    private fun eraseSampleStroke(strokeId: String) {
        PadnoteSession.openExisting(File(NotebookLibrary.directory(context), "$id.padnote").absolutePath, device).use { s ->
            val page = s.pageIdAt(0u)!!
            s.eraseStroke(page, strokeId)
        }
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
        addText("added_text") // i18n-ok: test fixture
        assertTrue(SampleFork.hasChanges(context, id, device))
        val copy = SampleFork.finish(context, id, device, "zh-Hant", SampleFork.Choice.SAVE_COPY)
        assertNotNull(copy)
        assertEquals("修改在副本裡", listOf("added_text"), texts(copy!!.first))
        assertTrue("範例回到打開前的樣子", texts(id).isEmpty())
        assertFalse("副本是一般筆記本", SampleFork.isSample(context, copy.first, device))
        assertTrue(copy.second.startsWith("My Sample ") || copy.second.startsWith("我的範例 "))
    }

    @Test
    fun discardingPutsTheSampleBack() {
        SampleFork.begin(context, id, device)
        addText("discarded_text") // i18n-ok: test fixture
        SampleFork.finish(context, id, device, "zh-Hant", SampleFork.Choice.DISCARD)
        assertTrue(texts(id).isEmpty())
        assertEquals(1, NotebookLibrary.all(context, device).size)
    }

    @Test
    fun keepingSavesIntoTheSample() {
        SampleFork.begin(context, id, device)
        addText("kept_text") // i18n-ok: test fixture
        SampleFork.finish(context, id, device, "zh-Hant", SampleFork.Choice.KEEP)
        assertEquals(listOf("kept_text"), texts(id))
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
        addText("app_killed") // i18n-ok: test fixture
        assertEquals(listOf(id), SampleFork.pendingIds(context))
        assertTrue(SampleFork.hasChanges(context, id, device))
    }

    @Test
    fun addingAndErasingStrokeInSampleIsTracked() {
        SampleFork.begin(context, id, device)
        val strokeId = addSampleStroke()
        assertTrue("畫了筆畫算改動", SampleFork.hasChanges(context, id, device))
        // 存檔保留在範例
        SampleFork.finish(context, id, device, "zh-Hant", SampleFork.Choice.KEEP)
        assertEquals("筆畫已保留在範例內", 1, strokeCount(id))

        // 重開範例並擦掉筆畫
        SampleFork.begin(context, id, device)
        assertFalse("剛重開還沒改", SampleFork.hasChanges(context, id, device))
        eraseSampleStroke(strokeId)
        assertTrue("擦掉筆畫算改動", SampleFork.hasChanges(context, id, device))
        SampleFork.finish(context, id, device, "zh-Hant", SampleFork.Choice.KEEP)
        assertEquals("擦掉筆畫後再存檔，筆畫確實被清空", 0, strokeCount(id))
    }
}
