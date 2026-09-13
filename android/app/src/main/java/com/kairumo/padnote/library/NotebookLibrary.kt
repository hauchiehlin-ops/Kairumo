package com.kairumo.padnote.library

import android.content.Context
import androidx.documentfile.provider.DocumentFile
import com.kairumo.padnote.sync.FolderSync
import java.io.File
import uniffi.padnote_core.PadnoteSession

/**
 * 這台裝置上的所有筆記本（Android）。
 *
 * # 為什麼需要它
 *
 * Android 原本只認一本固定檔名的 `notebook.padnote`。後果是跨平台同步**做不完**：
 * iPad 那邊每一本筆記是一個以 id 命名的套件，同步下來之後 Android 根本不會去開
 * 它們 —— 檔案就躺在資料夾裡，畫面上什麼也沒有。使用者看到的是「同步成功，
 * 但筆記沒出現」。
 *
 * 所以這裡把筆記本當成**一個目錄下的多個套件**，跟 Apple 端同一個模型。
 */
object NotebookLibrary {

    private const val DIRECTORY = "Notebooks"
    private const val LEGACY_NAME = "notebook.padnote"
    const val EXTENSION = "padnote"

    /** 一本筆記本。 */
    data class Entry(
        val id: String,
        val title: String,
        val pageCount: Int,
        val path: File
    )

    /** 套件目錄。第一次呼叫時會把舊版那本單一筆記搬進來。 */
    fun directory(context: Context): File {
        val dir = File(context.filesDir, DIRECTORY)
        if (!dir.exists()) dir.mkdirs()
        migrateLegacyNotebook(context, dir)
        return dir
    }

    /**
     * 把舊版的 `filesDir/notebook.padnote` 搬進套件目錄。
     *
     * 搬而不是複製一份：留兩份的話，使用者在新位置寫的東西同步得出去，
     * 而他以為自己在看的那本（舊位置）永遠不會更新。
     *
     * 搬不動時保持原狀而不是刪掉 —— 那是使用者唯一的一份資料。
     */
    private fun migrateLegacyNotebook(context: Context, dir: File) {
        val legacy = File(context.filesDir, LEGACY_NAME)
        if (!legacy.exists()) return
        val target = File(dir, LEGACY_NAME)
        if (target.exists()) return
        runCatching { legacy.renameTo(target) }
    }

    /** 所有筆記本，依標題排序。開不起來的套件會被跳過，不會讓整份清單失敗。 */
    fun all(context: Context, deviceId: UInt): List<Entry> =
        directory(context).listFiles()
            ?.filter { it.isDirectory && it.name.endsWith(".$EXTENSION") }
            ?.mapNotNull { describe(it, deviceId) }
            ?.sortedBy { it.title }
            ?: emptyList()

    private fun describe(path: File, deviceId: UInt): Entry? {
        val session = runCatching { PadnoteSession.openExisting(path.absolutePath, deviceId) }
            .getOrNull() ?: return null
        return Entry(
            id = path.nameWithoutExtension,
            title = runCatching { session.title() }.getOrDefault(path.nameWithoutExtension),
            pageCount = runCatching { session.pageCount().toInt() }.getOrDefault(0),
            path = path
        )
    }

    /** 開啟（或建立）一本筆記本，回傳 session 與第一頁。 */
    fun open(context: Context, id: String, deviceId: UInt, title: String = "Kairumo"):
        Pair<PadnoteSession, String>? = runCatching {
        val path = File(directory(context), "$id.$EXTENSION")
        val session = if (path.exists()) {
            PadnoteSession.openExisting(path.absolutePath, deviceId)
        } else {
            PadnoteSession.create(
                path.absolutePath, title, System.currentTimeMillis().toULong(), deviceId
            )
        }
        val page = session.firstPageId()
            ?: session.addPage(uniffi.padnote_core.PageStyle.BLANK)
        session to page
    }.getOrNull()

    /** 建立一本新筆記本，回傳它的 id。 */
    fun create(context: Context, title: String, deviceId: UInt): String? {
        val id = java.util.UUID.randomUUID().toString()
        return if (open(context, id, deviceId, title) != null) id else null
    }

    /**
     * 這台裝置要開的那一本。
     *
     * 沒有任何筆記本時建一本 —— 打開 App 看到空畫面，使用者不會知道下一步該做什麼。
     */
    fun currentOrCreate(context: Context, deviceId: UInt): String? =
        all(context, deviceId).firstOrNull()?.id
            ?: create(context, "Kairumo", deviceId)

    /**
     * 把同步資料夾裡本機還沒有的筆記本整包抓下來。
     *
     * 少了這一步，另一台裝置**新建**的筆記本永遠不會出現：`FolderSync.sync` 只
     * 對齊「本機已經有的那些套件」，沒見過的它不會主動去拿。
     *
     * @return 新抓下來的筆記本數。
     */
    fun pullNewNotebooks(context: Context, remoteRoot: DocumentFile, languageTag: String): Int {
        val dir = directory(context)
        var pulled = 0
        for (remote in remoteRoot.listFiles()) {
            val name = remote.name ?: continue
            if (!remote.isDirectory || !name.endsWith(".$EXTENSION")) continue
            val local = File(dir, name)
            if (local.exists()) continue
            val result = FolderSync.sync(context, local, remoteRoot, languageTag)
            if (result.downloaded.isNotEmpty()) pulled++
        }
        return pulled
    }

    /** 把每一本都與同步資料夾對齊。 */
    fun syncAll(context: Context, remoteRoot: DocumentFile, languageTag: String): FolderSync.Result {
        var merged = FolderSync.Result()
        for (path in directory(context).listFiles().orEmpty()) {
            if (!path.isDirectory || !path.name.endsWith(".$EXTENSION")) continue
            val result = FolderSync.sync(context, path, remoteRoot, languageTag)
            merged = FolderSync.Result(
                uploaded = merged.uploaded + result.uploaded,
                downloaded = merged.downloaded + result.downloaded,
                needsAttention = merged.needsAttention + result.needsAttention,
                failures = merged.failures + result.failures
            )
        }
        return merged
    }
}
