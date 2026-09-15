package com.kairumo.padnote.library

import android.content.Context
import android.graphics.BitmapFactory
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import uniffi.padnote_core.PadnoteSession
import java.io.File

/**
 * 筆記本第一頁的縮圖（Android）。
 *
 * # 為什麼算繪交給核心
 *
 * 用的是核心既有的 `export_page_png` —— 匯出走的是同一條路。自己在
 * Compose 上再畫一次的話，縮圖與匯出的結果會慢慢分岔，而使用者看到的是
 * 「預覽跟印出來的不一樣」。
 *
 * # 為什麼要有快取
 *
 * 產一張縮圖要開一個 session、重播 oplog、再光柵化一整頁。清單上有二十本
 * 就是二十次 —— 每次捲動都重做的話，首頁會卡到不能用。
 *
 * 快取的鍵帶上**修改時間**：內容變了就是一個新檔名，不必另外做失效判斷。
 * 舊的那些在同一次產生時順手刪掉。
 *
 * # 縮圖裡沒有的東西
 *
 * `export_page_png` 畫的是**底紋與筆畫**，不含文字方塊、表格、圖表與圖片
 * 那些畫布物件。所以一本只打字沒手寫的筆記，縮圖會是一張空白頁 ——
 * 那不是壞掉。要補的話得等核心的物件算繪也走同一條路。
 */
object NotebookThumbnails {

    /** 縮圖的長邊像素。清單上的縮圖很小，算太大只是白花時間與記憶體。 */
    private const val SCALE = 0.18f

    /**
     * 取一本筆記本第一頁的縮圖。**會開 session 並光柵化，要在背景執行緒呼叫。**
     *
     * 任何一步失敗都回 null —— 縮圖是裝飾，不該讓整份清單失敗。
     */
    fun load(context: Context, entry: NotebookLibrary.Entry): ImageBitmap? {
        val cached = cacheFile(context, entry)
        if (!cached.exists()) {
            val bytes = render(entry) ?: return null
            runCatching {
                cached.parentFile?.mkdirs()
                // 先寫暫存檔再改名：中途被砍掉的話，留下的是一個半截的
                // PNG，而它會被當成有效快取，那一本的縮圖就永遠是壞的。
                val tmp = File(cached.parentFile, "${cached.name}.tmp")
                tmp.writeBytes(bytes)
                tmp.renameTo(cached)
            }.getOrElse { return null }
            pruneOlder(context, entry, keep = cached.name)
        }
        return runCatching {
            BitmapFactory.decodeFile(cached.absolutePath)?.asImageBitmap()
        }.getOrNull()
    }

    private fun render(entry: NotebookLibrary.Entry): ByteArray? = runCatching {
        val session = PadnoteSession.openExisting(entry.path.absolutePath, 0u)
        val pageId = session.pageIdAt(0u) ?: session.firstPageId() ?: return null
        session.exportPagePng(pageId, SCALE)
    }.getOrNull()

    private fun dir(context: Context) = File(context.cacheDir, "thumbnails")

    private fun cacheFile(context: Context, entry: NotebookLibrary.Entry) =
        File(dir(context), "${entry.id}-${entry.modifiedAt}.png")

    /** 同一本筆記的舊縮圖。不刪的話，每改一次就多留一張，永遠不會少。 */
    private fun pruneOlder(context: Context, entry: NotebookLibrary.Entry, keep: String) {
        dir(context).listFiles()
            ?.filter { it.name.startsWith("${entry.id}-") && it.name != keep }
            ?.forEach { runCatching { it.delete() } }
    }
}
