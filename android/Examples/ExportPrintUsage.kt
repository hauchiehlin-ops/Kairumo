package com.padnote.examples

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
import java.io.FileInputStream

/**
 * Android 平台匯出與列印整合範例（工作項 S-18, S-43, S-55）。
 *
 * 示範：
 * 1. 匯出 PDF 並透過系統 Intent (ACTION_SEND) 分享或存檔
 * 2. 匯出單頁 PNG 圖片並分享
 * 3. 透過 Android PrintManager 與自訂 PrintDocumentAdapter 進行系統列印
 */
object ExportPrintUsage {

    /**
     * 匯出筆記本為 PDF 並呼叫系統分享面板。
     */
    fun shareNotebookPdf(context: Context, session: PadnoteSession) {
        val pdfBytes = session.exportPdf()
        val cacheFile = File(context.cacheDir, "${session.title()}.pdf")
        cacheFile.writeBytes(pdfBytes)

        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            cacheFile
        )

        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "application/pdf"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, session.title())
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        context.startActivity(Intent.createChooser(intent, "匯出 PDF"))
    }

    /**
     * 匯出單頁為 PNG 圖片並分享。
     */
    fun sharePagePng(context: Context, session: PadnoteSession, pageId: String, scale: Float = 2.0f) {
        val pngBytes = session.exportPagePng(pageId, scale)
        val cacheFile = File(context.cacheDir, "${session.title()}-page.png")
        cacheFile.writeBytes(pngBytes)

        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            cacheFile
        )

        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        context.startActivity(Intent.createChooser(intent, "匯出圖片 (PNG)"))
    }

    /**
     * 接軌 Android 系統列印（工作項 S-55）。
     *
     * @param pageId 若為 null 則列印整份筆記本；指定 ID 則列印該單頁。
     */
    fun printNotebook(context: Context, session: PadnoteSession, pageId: String? = null) {
        val printManager = context.getSystemService(Context.PRINT_SERVICE) as? PrintManager ?: return
        val jobName = "${session.title()}_print"

        // 從 Rust core 取得列印專用 PDF 位元組資料
        val pdfData = session.printData(pageId)

        printManager.print(
            jobName,
            ByteArrayPrintDocumentAdapter(pdfData, jobName),
            PrintAttributes.Builder()
                .setContentType(PrintAttributes.CONTENT_TYPE_DOCUMENT)
                .build()
        )
    }

    /**
     * 將 PDF 位元組直接寫入 Android PrintManager 管道的 Adapter。
     */
    private class ByteArrayPrintDocumentAdapter(
        private val pdfBytes: ByteArray,
        private val docName: String
    ) : PrintDocumentAdapter() {

        override fun onLayout(
            oldAttributes: PrintAttributes?,
            newAttributes: PrintAttributes?,
            cancellationSignal: CancellationSignal?,
            callback: LayoutResultCallback?,
            extras: Bundle?
        ) {
            if (cancellationSignal?.isCanceled == true) {
                callback?.onLayoutCancelled()
                return
            }

            val info = PrintDocumentInfo.Builder(docName)
                .setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT)
                .build()

            callback?.onLayoutFinished(info, true)
        }

        override fun onWrite(
            pages: Array<out PageRange>?,
            destination: ParcelFileDescriptor?,
            cancellationSignal: CancellationSignal?,
            callback: WriteResultCallback?
        ) {
            if (destination == null) {
                callback?.onWriteFailed("無效的檔案描述符")
                return
            }

            try {
                FileOutputStream(destination.fileDescriptor).use { out ->
                    out.write(pdfBytes)
                    out.flush()
                }

                if (cancellationSignal?.isCanceled == true) {
                    callback?.onWriteCancelled()
                } else {
                    callback?.onWriteFinished(arrayOf(PageRange.ALL_PAGES))
                }
            } catch (e: Exception) {
                callback?.onWriteFailed(e.localizedMessage)
            }
        }
    }
}
