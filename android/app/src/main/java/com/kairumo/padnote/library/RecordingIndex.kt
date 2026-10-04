package com.kairumo.padnote.library

import android.content.Context
import org.json.JSONObject
import uniffi.padnote_core.PadnoteSession
import java.io.File

/**
 * 最近的錄音（Android）。
 *
 * # 為什麼用掃檔案而不是另外維護一份索引
 *
 * 錄音檔就住在筆記本套件裡（`media/audio` 底下的 `.opus`，format-spec §5），
 * —— 這裡不寫成萬用字元的樣子，Kotlin 的區塊註解**可以巢狀**，
 * 註解裡一個斜線加星號會開一層新的註解，而編譯器只會報「Unclosed comment」。
 * 而套件是同步的單位。另外維護一份清單的話，從另一台裝置同步過來的錄音
 * 不會出現在上面 —— 而那正是「最近錄音」最該顯示的東西。
 *
 * 檔案系統本身就是真相來源，掃它就不會有對不起來的問題。
 *
 * # 錄音的名字
 *
 * 名字也在套件裡：Apple 端把每段錄音的名字寫成第一頁上的 `rectitle` 信封區塊
 * （`{"object":"rectitle","payload":{"fileName":…,"title":…}}`，見 Apple 的
 * `RecordingTitle`）。原本這裡只顯示筆記本標題 —— 在 iPad／Mac 改了錄音名稱，
 * Android 永遠看不到，使用者以為「改名沒有同步」。
 *
 * # 為什麼沒有長度
 *
 * 要知道一段 Opus 有多長得把它的封包走過一遍。清單上二十筆就是二十次，
 * 而使用者要的只是「哪一天、在哪一本」。長度留給播放時再算。
 */
object RecordingIndex {

    data class Recording(
        val notebookId: String,
        val notebookTitle: String,
        val file: File,
        val recordedAt: Long,
        val bytes: Long,
        /** 別台（或這台）取的錄音名字；套件裡沒有就是 null。 */
        val title: String? = null
    ) {
        /** 清單上顯示的名字：有錄音名字用它，沒有退回筆記本標題。 */
        val displayTitle: String get() = title?.takeIf { it.isNotBlank() } ?: notebookTitle
    }

    private const val TITLE_KIND = "rectitle"

    /**
     * 全部錄音，新的在前。**會掃整個筆記本目錄，要在背景執行緒呼叫。**
     *
     * `limit` 是上限；首頁只放得下幾筆，全部撈出來只是白掃。
     */
    fun recent(context: Context, deviceId: UInt, limit: Int = 20): List<Recording> {
        val found = NotebookLibrary.all(context, deviceId, folderId = NotebookLibrary.ANY_FOLDER)
            .flatMap { entry ->
                File(entry.path, "media/audio").listFiles()
                    ?.filter { it.isFile && it.length() > 0 }
                    ?.map {
                        Recording(
                            notebookId = entry.id,
                            notebookTitle = entry.title,
                            file = it,
                            recordedAt = it.lastModified(),
                            bytes = it.length()
                        )
                    }
                    ?: emptyList()
            }
            .sortedByDescending { it.recordedAt }
            .take(limit)

        // 只打開清單上真的有錄音的那幾本，讀它們的名字。
        val titlesByPackage = found
            .map { it.file.parentFile?.parentFile?.parentFile }
            .filterNotNull()
            .distinct()
            .associateWith { titlesIn(it, deviceId) }
        return found.map { rec ->
            val pkg = rec.file.parentFile?.parentFile?.parentFile
            val title = pkg?.let { titlesByPackage[it] }?.get(rec.file.name.lowercase())
            if (title != null) rec.copy(title = title) else rec
        }
    }

    /** 一個套件裡的錄音名字：檔名（小寫）→ 名字。讀不到就是空的。 */
    internal fun titlesIn(packageDir: File, deviceId: UInt): Map<String, String> {
        val session = runCatching { PadnoteSession.openExisting(packageDir.absolutePath, deviceId) }
            .getOrNull() ?: return emptyMap()
        return try {
            val page = runCatching { session.pageIdAt(0u) }.getOrNull() ?: return emptyMap()
            val out = HashMap<String, String>()
            for (blockId in runCatching { session.imageBlockIds(page) }.getOrDefault(emptyList())) {
                val json = runCatching { session.blockAppearance(blockId) }.getOrNull() ?: continue
                parseTitle(json)?.let { (file, title) -> out[file] = title }
            }
            out
        } finally {
            runCatching { session.close() }
        }
    }

    /** 解一個 `rectitle` 信封。不是這種區塊、或內容不完整就回 null。 */
    internal fun parseTitle(json: String): Pair<String, String>? {
        val root = runCatching { JSONObject(json) }.getOrNull() ?: return null
        if (root.optString("object") != TITLE_KIND) return null
        val payload = root.optJSONObject("payload") ?: return null
        val file = payload.optString("fileName").trim().lowercase()
        val title = payload.optString("title").trim()
        if (file.isEmpty() || title.isEmpty()) return null
        return file to title
    }
}
