package com.kairumo.padnote.library

import android.content.Context
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
        val bytes: Long
    )

    /**
     * 全部錄音，新的在前。**會掃整個筆記本目錄，要在背景執行緒呼叫。**
     *
     * `limit` 是上限；首頁只放得下幾筆，全部撈出來只是白掃。
     */
    fun recent(context: Context, deviceId: UInt, limit: Int = 20): List<Recording> =
        NotebookLibrary.all(context, deviceId, folderId = NotebookLibrary.ANY_FOLDER)
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
}
