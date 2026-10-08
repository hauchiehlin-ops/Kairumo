package com.kairumo.padnote.platform

import com.kairumo.padnote.LocalizationStrings
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
    /// 這一頁是第幾頁。版面是逐頁的，所以匯出單頁時要知道它的索引。
    private fun pageIndexOf(session: PadnoteSession, pageId: String): Int {
        val count = runCatching { session.pageCount().toInt() }.getOrDefault(1)
        for (i in 0 until count) {
            if (runCatching { session.pageIdAt(i.toUInt()) }.getOrNull() == pageId) return i
        }
        return 0
    }

    fun export(
        context: Context,
        session: PadnoteSession,
        format: Format,
        pageId: String? = null,
        baseName: String = "kairumo",
        /** 版面標籤要照使用者的語系翻譯（S-90）。 */
        languageTag: String = "zh-Hant"
    ): Result<File> = runCatching {
        val bytes: ByteArray = when (format) {
            Format.PDF -> {
                // **把版面一起畫進去**（S-90）。
                //
                // 底紋只有六種，而使用者看到的版面有三十幾種 —— 康乃爾的三區、
                // 四象限的十字、週計畫的七欄都來自核心的 `pageGuides`。
                // 在此之前匯出的 PDF 完全沒有它們：畫布上是一張康乃爾，
                // 匯出來是一張空白紙。
                //
                // 顏色與文字核心拿不到（配色是使用者選的、語系鍵住在兩端共用
                // 的字串表裡），所以這裡一起交過去。
                val meta = com.kairumo.padnote.library.NotebookMeta.load(session)
                val pageCount = runCatching { session.pageCount().toInt() }.getOrDefault(1)
                val paperIds = (0 until maxOf(1, pageCount)).map { meta.paperId(it) }
                val labels = LocalizationStrings.table
                    .filterKeys { it.startsWith("guide_") }
                    .mapValues { (key, _) -> LocalizationStrings.localized(key, languageTag) }
                // 轉錄區塊的標記要跟著介面語言（S-54c）。核心原本完全不知道
                // 語言，於是寫死 `[Audio]`；再之前寫死的是 `[語音]`，而那更糟
                // —— 匯出的 PDF 是要給別人看的文件。
                if (pageId == null) {
                    session.exportPdfWithLayout(paperIds, meta.paletteId(), labels, languageTag)
                } else {
                    session.exportPagePdfWithLayout(
                        pageId,
                        meta.paperId(pageIndexOf(session, pageId)),
                        meta.paletteId(),
                        labels,
                        languageTag
                    )
                }
            }
            Format.PNG -> {
                val page = pageId ?: session.firstPageId()
                    ?: error(com.kairumo.padnote.L10n.t("export_err_no_pages"))
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
     * **所見即所得**的匯出（PDF／PNG）：每一頁都用編輯器畫布自己的元件算繪（見 [PageSnapshot]），
     * 不走核心的匯出器 —— 後者的筆畫是等寬折線、也沒有形狀／圖表／連結卡片／圖片濾鏡，
     * 匯出來的東西與畫布上看到的不一樣。
     *
     * - PDF：整本，每頁一張點陣圖，頁面尺寸 = 頁面點數。文字不能選取（要向量請用 `.padnote`）。
     * - PNG：[pageIndex] 這一頁（編輯器目前停的那一頁；原本不論在哪一頁都匯出第一頁）。
     *
     * 算繪失敗（逾時、系統不支援）才退回核心的匯出器 —— 拿得到一份缺東西的檔案，
     * 好過一個錯誤訊息。
     */
    suspend fun exportWysiwyg(
        activity: androidx.activity.ComponentActivity,
        session: PadnoteSession,
        format: Format,
        pageIndex: Int,
        audioDirectory: File?,
        baseName: String = "kairumo",
        languageTag: String = "zh-Hant"
    ): Result<File> = runCatching {
        require(format == Format.PDF || format == Format.PNG) { "only PDF and PNG are rendered page-by-page" }
        val stamp = System.currentTimeMillis()
        val file = File(exportsDir(activity), "$baseName-$stamp.${format.extension}")
        if (format == Format.PNG) {
            val bitmap = PageSnapshot.render(activity, session, pageIndex, 2f, languageTag, audioDirectory)
                ?: return@runCatching export(activity, session, format, languageTag = languageTag).getOrThrow()
            FileOutputStream(file).use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
            bitmap.recycle()
            return@runCatching file
        }
        val ok = renderPdf(activity, session, file, audioDirectory, languageTag)
        if (!ok) {
            file.delete()
            return@runCatching export(activity, session, format, languageTag = languageTag).getOrThrow()
        }
        file
    }

    /** 逐頁算繪、逐頁寫進 PDF（不把所有頁面的點陣圖一次留在記憶體）。任何一頁畫不出來回 `false`。 */
    private suspend fun renderPdf(
        activity: androidx.activity.ComponentActivity,
        session: PadnoteSession,
        out: File,
        audioDirectory: File?,
        languageTag: String
    ): Boolean {
        val pageCount = maxOf(1, runCatching { session.pageCount().toInt() }.getOrDefault(1))
        val document = android.graphics.pdf.PdfDocument()
        try {
            for (index in 0 until pageCount) {
                val bitmap = PageSnapshot.render(activity, session, index, 2f, languageTag, audioDirectory)
                    ?: return false
                // 頁面尺寸用點數（頁面座標 1 點 = PDF 1 點），圖是 2 倍：列印與放大都不糊。
                val widthPt = (bitmap.width / 2f).toInt().coerceAtLeast(1)
                val heightPt = (bitmap.height / 2f).toInt().coerceAtLeast(1)
                val page = document.startPage(
                    android.graphics.pdf.PdfDocument.PageInfo.Builder(widthPt, heightPt, index + 1).create())
                try {
                    page.canvas.drawBitmap(bitmap, null, android.graphics.Rect(0, 0, widthPt, heightPt), null)
                } finally {
                    // 畫失敗也要收頁，不然 `close()` 會再丟一個「Current page not finished」蓋掉真正的錯誤。
                    document.finishPage(page)
                    bitmap.recycle()
                }
            }
            FileOutputStream(out).use { document.writeTo(it) }
            return true
        } finally {
            document.close()
        }
    }

    /** 列印：與匯出 PDF 同一份算繪結果（印出來就是畫布上的樣子）。 */
    suspend fun printWysiwyg(
        activity: androidx.activity.ComponentActivity,
        session: PadnoteSession,
        audioDirectory: File?,
        languageTag: String,
        jobName: String = "Kairumo"
    ) {
        val temp = File(exportsDir(activity), "print-${System.currentTimeMillis()}.pdf")
        val bytes = if (renderPdf(activity, session, temp, audioDirectory, languageTag)) {
            temp.readBytes()
        } else {
            session.printData(pageId = null)
        }
        temp.delete()
        val manager = activity.getSystemService(Context.PRINT_SERVICE) as PrintManager
        manager.print(jobName, BytesPrintAdapter(bytes, jobName), PrintAttributes.Builder().build())
    }

    /** 封裝整個 .padnote 套件目錄為單一壓縮檔並回傳。 */
    fun sharePackage(context: Context, notebookDir: File, title: String): Result<File> = runCatching {
        val safeTitle = title.replace(Regex("[/\\\\:*?\"<>|]"), "_").ifBlank { "kairumo" }
        val stamp = System.currentTimeMillis()
        val file = File(exportsDir(context), "$safeTitle-$stamp.padnote")
        uniffi.padnote_core.archiveNotebook(notebookDir.absolutePath, file.absolutePath)
        file
    }

    fun sharePackageIntent(context: Context, file: File): Intent {
        val uri = FileProvider.getUriForFile(
            context, "${context.packageName}.fileprovider", file
        )
        return Intent(Intent.ACTION_SEND).apply {
            type = "application/octet-stream"
            putExtra(Intent.EXTRA_STREAM, uri)
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
