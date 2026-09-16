package com.kairumo.padnote.platform

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.print.PageRange
import android.print.PrintAttributes
import android.print.PrintDocumentAdapter
import android.print.PrintDocumentInfo
import android.print.PrintManager
import androidx.core.content.FileProvider
import uniffi.padnote_core.PadnoteSession
import java.io.File
import java.io.FileOutputStream

/**
 * 匯出、分享與列印（工作包 WP6）。
 *
 * 內容全部由核心產生 —— PDF、PNG、Markdown 都是 `padnote-export` 那一份。
 * 平台層只負責把位元組落到檔案、交給系統的分享或列印面板。
 *
 * 這樣分工的理由是 Apple 端剛踩過的坑：匯出若在平台層另外畫一次，
 * 畫出來的東西遲早會跟畫布上的不一樣（那次是整頁空白）。
 */
object Exporter {

    enum class Format(val extension: String, val mime: String) {
        PDF("pdf", "application/pdf"),
        PNG("png", "image/png"),
        MARKDOWN("md", "text/markdown")
    }

    /** 匯出檔只放在 App 私有 cache：不落到外部儲存，任何 App 都讀得到那裡。 */
    private fun exportsDir(context: Context): File =
        File(context.cacheDir, "exports").apply { mkdirs() }

    /**
     * 產生檔案並回傳它。
     *
     * @param pageId 只匯出某一頁；`null` 代表整本。
     */
    fun export(
        context: Context,
        session: PadnoteSession,
        format: Format,
        pageId: String? = null,
        baseName: String = "kairumo"
    ): Result<File> = runCatching {
        val bytes: ByteArray = when (format) {
            Format.PDF -> if (pageId == null) session.exportPdf() else session.exportPagePdf(pageId)
            Format.PNG -> {
                val page = pageId ?: session.firstPageId()
                    ?: error("這本筆記沒有任何頁面")
                // @2x：螢幕截圖級的解析度，列印或再編輯都還堪用。
                // 走 PageImageRenderer 而不是核心的 export_page_png：
                // 後者把文字畫成灰條，匯出的圖上會看不到字（工作項 S-60）。
                PageImageRenderer.renderPng(session, page, 2f, context.cacheDir)
            }
            Format.MARKDOWN -> session.exportMarkdown().toByteArray()
        }
        // 檔名帶時間戳：連續匯出兩次不該把前一次蓋掉，使用者常常兩份都要。
        val stamp = System.currentTimeMillis()
        val file = File(exportsDir(context), "$baseName-$stamp.${format.extension}")
        FileOutputStream(file).use { it.write(bytes) }
        file
    }

    /** 交給系統分享面板。 */
    fun shareIntent(context: Context, file: File, format: Format): Intent {
        val uri = FileProvider.getUriForFile(
            context, "${context.packageName}.fileprovider", file
        )
        return Intent(Intent.ACTION_SEND).apply {
            type = format.mime
            putExtra(Intent.EXTRA_STREAM, uri)
            // 沒有這個旗標，接收方會拿到一個開不起來的 URI。
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
    }

    /**
     * 交給系統列印面板。
     *
     * 列印資料走核心的 `print_data`，與匯出 PDF 同源 —— 印出來跟匯出的
     * 是同一份東西。
     */
    fun print(context: Context, session: PadnoteSession, jobName: String = "Kairumo") {
        val manager = context.getSystemService(Context.PRINT_SERVICE) as PrintManager
        val bytes = session.printData(pageId = null)
        manager.print(jobName, BytesPrintAdapter(bytes, jobName), PrintAttributes.Builder().build())
    }

    /** 把一段既有的 PDF 位元組交給列印框架。 */
    private class BytesPrintAdapter(
        private val bytes: ByteArray,
        private val jobName: String
    ) : PrintDocumentAdapter() {

        override fun onLayout(
            oldAttributes: PrintAttributes?,
            newAttributes: PrintAttributes?,
            cancellationSignal: CancellationSignal?,
            callback: LayoutResultCallback,
            extras: Bundle?
        ) {
            if (cancellationSignal?.isCanceled == true) {
                callback.onLayoutCancelled()
                return
            }
            val info = PrintDocumentInfo.Builder("$jobName.pdf")
                .setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT)
                .build()
            // changed = true：版面設定變更後要重新取資料，否則會印到舊的那份。
            callback.onLayoutFinished(info, true)
        }

        override fun onWrite(
            pages: Array<out PageRange>?,
            destination: ParcelFileDescriptor,
            cancellationSignal: CancellationSignal?,
            callback: WriteResultCallback
        ) {
            try {
                FileOutputStream(destination.fileDescriptor).use { it.write(bytes) }
                callback.onWriteFinished(arrayOf(PageRange.ALL_PAGES))
            } catch (t: Throwable) {
                callback.onWriteFailed(t.message)
            }
        }
    }
}
