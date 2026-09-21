package com.kairumo.padnote.sync

import androidx.documentfile.provider.DocumentFile
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/**
 * 用使用者自己的雲端硬碟同步（決策 D3 選項 A）。
 *
 * 這裡不需要真的 Google Drive：`DocumentFile.fromFile` 讓一個本機目錄
 * 走完全相同的 SAF 介面，所以策略與 I/O 都測得到。真正只有實機能驗的是
 * 「Drive 有沒有把檔案傳上去」—— 那是別人的服務，不是我們的程式碼。
 *
 * 每一條測試都對應 Apple 端同名的那一條，因為兩個平台必須做同一件事。
 */
@RunWith(AndroidJUnit4::class)
class FolderSyncTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private lateinit var root: File
    private lateinit var localPackage: File
    private lateinit var cloud: File

    @Before
    fun setUp() {
        root = File(context.cacheDir, "sync-${System.nanoTime()}")
        localPackage = File(root, "note.padnote").apply { mkdirs() }
        cloud = File(root, "Cloud").apply { mkdirs() }
    }

    @After
    fun tearDown() {
        root.deleteRecursively()
    }

    private fun write(relative: String, contents: String, base: File) {
        val f = File(base, relative)
        f.parentFile?.mkdirs()
        f.writeText(contents)
    }

    private fun read(relative: String, base: File): String? =
        File(base, relative).takeIf { it.isFile }?.readText()

    private val remotePackage: File get() = File(cloud, "note.padnote")

    private fun sync(): FolderSync.Result =
        FolderSync.sync(context, localPackage, DocumentFile.fromFile(cloud))

    // MARK: - 列檔

    @Test
    fun listingIsRecursive() {
        // 只列單層的話，doc/ops 與 ink 底下的東西 —— 也就是真正的內容 ——
        // 一個都不會被同步，而計畫看起來會是「成功，沒事要做」。
        write("manifest.json", "{}", localPackage)
        write("doc/ops/0001-aaaa.oplog", "op", localPackage)
        write("ink/page-aaaa.strokes", "ink", localPackage)

        val paths = FolderSync.localEntries(localPackage).map { it.path }.sorted()
        assertEquals(
            listOf("doc/ops/0001-aaaa.oplog", "ink/page-aaaa.strokes", "manifest.json"),
            paths
        )
    }

    @Test
    fun remoteListingIsAlsoRecursive() {
        write("doc/ops/0001-bbbb.oplog", "op", remotePackage)
        val paths = FolderSync.remoteEntries(DocumentFile.fromFile(remotePackage)).map { it.path }
        assertEquals(listOf("doc/ops/0001-bbbb.oplog"), paths)
    }

    // MARK: - 第一次同步

    @Test
    fun firstSyncUploadsEverything() {
        write("manifest.json", "{}", localPackage)
        write("doc/ops/0001-aaaa.oplog", "op", localPackage)

        val result = sync()
        assertEquals(listOf("doc/ops/0001-aaaa.oplog", "manifest.json"), result.uploaded.sorted())
        assertTrue(result.failures.isEmpty())
        assertEquals("op", read("doc/ops/0001-aaaa.oplog", remotePackage))
    }

    @Test
    fun newDevicePullsEverything() {
        write("manifest.json", "{}", remotePackage)
        write("ink/page-bbbb.strokes", "ink", remotePackage)

        val result = sync()
        assertEquals(listOf("ink/page-bbbb.strokes", "manifest.json"), result.downloaded.sorted())
        assertEquals("ink", read("ink/page-bbbb.strokes", localPackage))
    }

    // MARK: - 兩台裝置

    @Test
    fun bothDevicesInkFilesSurvive() {
        // 整個方案要保護的東西：兩台裝置在同一頁上寫字，兩份都要在。
        write("ink/page-11111111.strokes", "A 的筆跡", localPackage)
        write("ink/page-22222222.strokes", "B 的筆跡", remotePackage)

        sync()

        assertEquals("A 的筆跡", read("ink/page-11111111.strokes", localPackage))
        assertEquals("B 的筆跡", read("ink/page-22222222.strokes", localPackage))
        assertEquals("A 的筆跡", read("ink/page-11111111.strokes", remotePackage))
        assertEquals("B 的筆跡", read("ink/page-22222222.strokes", remotePackage))
    }

    @Test
    fun theLongerAppendOnlyFileWins() {
        write("doc/ops/0001-aaaa.oplog", "op1op2op3", localPackage)
        write("doc/ops/0001-aaaa.oplog", "op1", remotePackage)

        sync()
        assertEquals("op1op2op3", read("doc/ops/0001-aaaa.oplog", remotePackage))
    }

    @Test
    fun overwritingAShorterRemoteFileDoesNotLeaveTrailingBytes() {
        // SAF 的 "w" 不保證截斷。沒有用 "wt" 的話，較短的舊版尾端會殘留，
        // 檔案就壞了 —— 而且壞在雲端那一份。
        write("doc/ops/0001-aaaa.oplog", "SHORT", remotePackage)
        write("doc/ops/0001-aaaa.oplog", "LONGER-CONTENT", localPackage)
        sync()
        assertEquals("LONGER-CONTENT", read("doc/ops/0001-aaaa.oplog", remotePackage))

        // 反過來：本機比較長時被換成較短的雲端版本，也不能有殘留
        write("x.oplog", "AAAAAAAAAAAA", localPackage)
        write("x.oplog", "BBB", remotePackage)
        // 雲端較短 ⇒ 依策略本機才是超集，應該上傳而不是下載
        sync()
        assertEquals("AAAAAAAAAAAA", read("x.oplog", remotePackage))
    }

    // MARK: - 不該默默做的事

    @Test
    fun divergingManifestIsLeftAloneOnBothSides() {
        // manifest 的欄位不是不可變（notebook_id、created_at）、就是權威在別處
        // （標題由 notebooks/index.json 與 oplog 的 SetTitle 決定）、就是**本機專屬**
        // （encryption 的金鑰包裝參數 —— 被對面蓋掉就等於把這台裝置的解密資訊
        // 換成另一台的）。所以兩邊都有時各留各的。
        //
        // 舊版把它列進 needsAttention，症狀是每次同步都跳一句「需要注意」，
        // 而使用者無論做什麼都不會消失 —— 因為那本來就不是他能回答的問題。
        write("manifest.json", "{\"title\":\"我改的\"}", localPackage)
        write("manifest.json", "{\"title\":\"另一台改的\"}", remotePackage)

        val result = sync()
        assertEquals(emptyList<String>(), result.needsAttention)
        assertEquals("{\"title\":\"我改的\"}", read("manifest.json", localPackage))
        assertEquals("{\"title\":\"另一台改的\"}", read("manifest.json", remotePackage))
    }

    @Test
    fun syncingTwiceChangesNothingTheSecondTime() {
        write("manifest.json", "{}", localPackage)
        write("doc/ops/0001-aaaa.oplog", "op", localPackage)

        sync()
        val second = sync()
        assertTrue("第二次應該什麼都不用做，實得 $second", second.isNoOp)
    }

    @Test
    fun nothingIsDeletedOnEitherSide() {
        // 同步只做聯集。同步程式自作主張刪檔是最不可挽回的一種 bug。
        write("only-local.oplog", "x", localPackage)
        write("only-remote.oplog", "y", remotePackage)

        sync()

        assertNotNull(read("only-local.oplog", localPackage))
        assertNotNil(read("only-remote.oplog", localPackage))
        assertNotNull(read("only-local.oplog", remotePackage))
        assertNotNull(read("only-remote.oplog", remotePackage))
    }

    private fun assertNotNil(value: String?) = assertNotNull(value)
}
