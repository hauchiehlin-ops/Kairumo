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
import uniffi.padnote_core.PadnoteSession
import java.io.File

/**
 * Android 的筆記本清單。
 *
 * # 這組測試在守什麼
 *
 * Android 原本只認一本固定檔名的 `notebook.padnote`。跨平台同步因此**做不完**：
 * iPad 那邊每一本筆記是一個以 id 命名的套件，同步下來之後根本不會被開啟 ——
 * 使用者看到的是「同步成功，但筆記沒出現」。
 *
 * 而換掉儲存位置這件事本身有風險：舊版那本筆記是使用者唯一的一份資料，
 * 搬家搬丟了就沒了。所以遷移的部分測得比功能還細。
 */
@RunWith(AndroidJUnit4::class)
class NotebookLibraryTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val deviceId = 0xA7u

    @Before
    @After
    fun clean() {
        File(context.filesDir, "Notebooks").deleteRecursively()
        File(context.filesDir, "notebook.padnote").deleteRecursively()
    }

    private fun makeNotebook(path: File, title: String) {
        PadnoteSession.create(
            path.absolutePath, title, System.currentTimeMillis().toULong(), deviceId
        )
    }

    // ── 舊版資料的搬家（最不能出錯的部分）───────────────────

    @Test
    fun theLegacyNotebookIsMovedIntoTheLibrary() {
        // 舊版那本是使用者唯一的一份資料。搬丟了就沒了。
        makeNotebook(File(context.filesDir, "notebook.padnote"), "舊版的筆記")

        val all = NotebookLibrary.all(context, deviceId)

        assertEquals(1, all.size)
        assertEquals("舊版的筆記", all[0].title)
        assertTrue(all[0].path.absolutePath.contains("Notebooks"))
    }

    @Test
    fun theLegacyNotebookIsMovedNotCopied() {
        // 留兩份的話，使用者在新位置寫的東西同步得出去，
        // 而他以為自己在看的那本（舊位置）永遠不會更新。
        makeNotebook(File(context.filesDir, "notebook.padnote"), "舊版的筆記")
        NotebookLibrary.all(context, deviceId)

        assertFalse(File(context.filesDir, "notebook.padnote").exists())
    }

    @Test
    fun migrationRunsOnlyOnce() {
        makeNotebook(File(context.filesDir, "notebook.padnote"), "舊版的筆記")
        NotebookLibrary.all(context, deviceId)
        // 再跑一次不該多出東西，也不該把已經搬好的那本弄壞。
        val all = NotebookLibrary.all(context, deviceId)
        assertEquals(1, all.size)
        assertEquals("舊版的筆記", all[0].title)
    }

    @Test
    fun theLegacyNotebookStillOpensAfterMoving() {
        // 搬完之後打不開，跟搬丟了沒有兩樣。
        makeNotebook(File(context.filesDir, "notebook.padnote"), "舊版的筆記")
        val entry = NotebookLibrary.all(context, deviceId).first()

        val opened = NotebookLibrary.open(context, entry.id, deviceId)
        assertNotNull("搬完之後打不開", opened)
        assertEquals("舊版的筆記", opened!!.first.title())
    }

    // ── 多本 ────────────────────────────────────────────────

    @Test
    fun severalNotebooksAreAllListed() {
        NotebookLibrary.create(context, "甲", deviceId)
        NotebookLibrary.create(context, "乙", deviceId)
        NotebookLibrary.create(context, "丙", deviceId)

        assertEquals(
            listOf("丙", "乙", "甲").sorted(),
            NotebookLibrary.all(context, deviceId).map { it.title }.sorted()
        )
    }

    @Test
    fun eachNotebookGetsItsOwnPackage() {
        val first = NotebookLibrary.create(context, "甲", deviceId)!!
        val second = NotebookLibrary.create(context, "乙", deviceId)!!
        assertTrue(first != second)
        assertEquals(2, NotebookLibrary.directory(context).listFiles()!!.size)
    }

    @Test
    fun openingTheSameNotebookTwiceDoesNotCreateASecond() {
        val id = NotebookLibrary.create(context, "甲", deviceId)!!
        NotebookLibrary.open(context, id, deviceId)
        assertEquals(1, NotebookLibrary.all(context, deviceId).size)
    }

    @Test
    fun contentWrittenToOneNotebookStaysThere() {
        // 兩本共用同一個套件的話，寫在 A 的字會出現在 B ——
        // 那種錯誤使用者第一天就會遇到。
        val first = NotebookLibrary.create(context, "甲", deviceId)!!
        val second = NotebookLibrary.create(context, "乙", deviceId)!!

        val (sessionA, pageA) = NotebookLibrary.open(context, first, deviceId)!!
        sessionA.addText(pageA, "只在甲裡面", uniffi.padnote_core.BlockStyle.BODY)

        val (sessionB, pageB) = NotebookLibrary.open(context, second, deviceId)!!
        assertTrue("內容跑到別本去了", sessionB.textBlockIds(pageB).isEmpty())
    }

    // ── 空狀態 ──────────────────────────────────────────────

    @Test
    fun anEmptyLibraryCreatesOneSoTheAppIsNotBlank() {
        // 打開 App 看到空畫面，使用者不會知道下一步該做什麼。
        val id = NotebookLibrary.currentOrCreate(context, deviceId)
        assertNotNull(id)
        assertEquals(1, NotebookLibrary.all(context, deviceId).size)
    }

    @Test
    fun anExistingNotebookIsReusedInsteadOfCreatingAnother() {
        val id = NotebookLibrary.create(context, "已經有的", deviceId)
        assertEquals(id, NotebookLibrary.currentOrCreate(context, deviceId))
        assertEquals(1, NotebookLibrary.all(context, deviceId).size)
    }

    @Test
    fun aBrokenPackageDoesNotBreakTheWholeList() {
        // 一本壞掉，跟整份清單開不出來，對使用者是完全不同等級的損失。
        NotebookLibrary.create(context, "好的", deviceId)
        File(NotebookLibrary.directory(context), "broken.padnote").mkdirs()

        val all = NotebookLibrary.all(context, deviceId)
        assertEquals(1, all.size)
        assertEquals("好的", all[0].title)
    }

    @Test
    fun strayFilesAreIgnored() {
        NotebookLibrary.create(context, "好的", deviceId)
        File(NotebookLibrary.directory(context), "note.txt").writeText("不是套件")

        assertEquals(1, NotebookLibrary.all(context, deviceId).size)
    }
}
