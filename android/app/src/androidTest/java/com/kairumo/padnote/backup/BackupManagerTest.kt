package com.kairumo.padnote.backup

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.Date

/**
 * 個人資料備份與一鍵復原（Android）。
 *
 * 容器格式在核心有自己的測試；這裡測的是 Android 端的決定：
 * 哪些東西進備份、設定怎麼帶、復原前有沒有安全網。
 * 每一條都對應 Apple 端同名的那一條 —— 兩個平台必須做同一件事。
 */
@RunWith(AndroidJUnit4::class)
class BackupManagerTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val files: File get() = context.filesDir

    @Before
    fun setUp() {
        files.listFiles()?.forEach { it.deleteRecursively() }
        File(context.cacheDir, "backups").deleteRecursively()
        context.getSharedPreferences("kairumo", android.content.Context.MODE_PRIVATE)
            .edit().clear().apply()
    }

    @After
    fun tearDown() {
        files.listFiles()?.forEach { it.deleteRecursively() }
        File(context.cacheDir, "backups").deleteRecursively()
    }

    private fun write(relative: String, contents: String) {
        val f = File(files, relative)
        f.parentFile?.mkdirs()
        f.writeText(contents)
    }

    private fun read(relative: String): String? =
        File(files, relative).takeIf { it.isFile }?.readText()

    private fun seedEverything() {
        write("notebook.padnote/manifest.json", "{}")
        write("notebook.padnote/doc/ops/0001-aaaa.oplog", "op")
        write("notebook.padnote/ink/page-aaaa.strokes", "筆畫位元組")
        write("recordings/r1.opus", "錄音位元組")
    }

    // MARK: - 備份內容

    @Test
    fun everyKindOfUserDataIsIncluded() {
        seedEverything()
        val (file, info) = BackupManager.create(context, "2.3.4")
        assertTrue(file.exists())
        assertEquals(4u, info.fileCount)
        assertTrue(info.totalBytes > 0uL)
    }

    @Test
    fun theBackupFileIsSelfDescribing() {
        seedEverything()
        val date = Date(1_757_635_200_000)
        val (file, _) = BackupManager.create(context, "9.9.9", date)
        val info = BackupManager.inspect(file)
        assertEquals("9.9.9", info.appVersion)
        assertEquals(1_757_635_200_000uL, info.createdUnixMs)
        assertTrue(info.digestOk)
    }

    @Test
    fun twoBackupsInTheSameSecondDoNotOverwriteEachOther() {
        // 只帶到秒的話兩份會同名而互相覆蓋 —— 而「復原前先備份現況」正好就
        // 發生在同一秒，結果是安全備份把要復原的那份蓋掉。
        seedEverything()
        val date = Date(1_757_635_200_000)
        val (a, _) = BackupManager.create(context, "2.3.4", date)
        val (b, _) = BackupManager.create(context, "2.3.4", date)
        assertNotEquals(a.name, b.name)
        assertTrue(a.exists() && b.exists())
    }

    // MARK: - 設定

    @Test
    fun ourSettingsAreCarriedButTheSyncPermissionIsNot() {
        // 同步資料夾的 URI 授權換一台裝置就失效了，帶過去只會讓使用者
        // 以為資料夾還在。
        val prefs = context.getSharedPreferences("kairumo", android.content.Context.MODE_PRIVATE)
        prefs.edit().putString("deviceLabel", "我的平板")
            .putString("sync.treeUri", "content://com.android.externalstorage/tree/xyz").apply()

        val json = BackupManager.currentSettings(context)
        assertTrue(json.contains("deviceLabel"))
        assertTrue("同步授權不該進備份", !json.contains("sync.treeUri"))
    }

    @Test
    fun settingsComeBackAfterRestore() {
        seedEverything()
        val prefs = context.getSharedPreferences("kairumo", android.content.Context.MODE_PRIVATE)
        prefs.edit().putString("deviceLabel", "復原前").apply()
        val (file, _) = BackupManager.create(context, "2.3.4")

        prefs.edit().putString("deviceLabel", "被改掉了").apply()
        BackupManager.restore(context, file, "2.3.4")

        assertEquals("復原前", prefs.getString("deviceLabel", null))
    }

    // MARK: - 復原

    @Test
    fun restoreBringsBackDeletedFiles() {
        seedEverything()
        val (file, _) = BackupManager.create(context, "2.3.4")

        File(files, "notebook.padnote").deleteRecursively()
        File(files, "recordings").deleteRecursively()
        assertNull(read("notebook.padnote/ink/page-aaaa.strokes"))

        val outcome = BackupManager.restore(context, file, "2.3.4")
        assertEquals(4, outcome.restored)
        assertTrue(outcome.corrupted.isEmpty())
        assertEquals("筆畫位元組", read("notebook.padnote/ink/page-aaaa.strokes"))
        assertEquals("錄音位元組", read("recordings/r1.opus"))
    }

    @Test
    fun restoreMakesASafetyBackupFirst() {
        // 使用者按下復原的那一刻，手上的資料就要被覆蓋了。
        seedEverything()
        val (file, _) = BackupManager.create(context, "2.3.4")
        val outcome = BackupManager.restore(context, file, "2.3.4")
        val safety = assertNotNull(outcome.safetyBackup).let { outcome.safetyBackup!! }
        assertTrue(safety.exists())
        assertTrue(safety.name.contains("safety"))
        assertTrue(BackupManager.inspect(safety).digestOk)
    }

    @Test
    fun restoringAJunkFileFailsClearly() {
        // 使用者選錯檔案是常態。要明確拒絕，而不是把半份垃圾寫進去。
        val junk = File(context.cacheDir, "photo.jpg").apply { writeText("這不是備份") }
        var threw = false
        try {
            BackupManager.inspect(junk)
        } catch (t: Throwable) {
            threw = true
        }
        assertTrue("不是備份檔就該明確失敗", threw)
    }

    @Test
    fun anEmptyFilesDirectoryStillBacksUp() {
        // 新使用者第一次按備份就是這個情況，不該當掉。
        val (file, info) = BackupManager.create(context, "2.3.4")
        assertEquals(0u, info.fileCount)
        assertTrue(BackupManager.inspect(file).digestOk)
    }

    @Test
    fun backupsAreNotStoredWhereTheyWouldBackUpThemselves() {
        // 備份檔放在 cache 而不是 filesDir，否則每備份一次檔案就翻倍。
        seedEverything()
        BackupManager.create(context, "2.3.4")
        val (_, info) = BackupManager.create(context, "2.3.4")
        assertEquals("第二份備份不該把第一份包進去", 4u, info.fileCount)
    }
}
