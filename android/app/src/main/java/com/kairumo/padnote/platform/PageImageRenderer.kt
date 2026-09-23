package com.kairumo.padnote.platform

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import uniffi.padnote_core.PadnoteSession
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * 把一頁算繪成 PNG（工作項 S-60）。
 *
 * # 為什麼不直接用核心的 `export_page_png`
 *
 * 核心那一條路把文字畫成**灰色的行條**（greeking）而不是真的字。原因寫在
 * `padnote-export::image` 的檔頭：純 Rust 的光柵化器手上沒有字型，而要畫
 * 中文得內嵌一份好幾 MB 的字型，那還是一個授權決策。
 *
 * 結果就是「打字的筆記，縮圖與匯出的 PNG 都是一排灰條」。Apple 端的縮圖
 * 走的是 UIKit（`PageThumbnailRenderer`），畫得出真的字 —— 兩邊因此長得
 * 不一樣，而那正是**同一份筆記在 iPad 上看得到字、在 Android 上看不到**。
 *
 * # 這條路：PDF 交給系統畫
 *
 * 核心的 PDF 匯出器（`export_page_pdf`）本來就會輸出真正的文字物件，中文走
 * Type 0 複合字型。Android 內建的 [PdfRenderer] 會替非內嵌字型代換系統字型，
 * 所以**一個位元組都不用內嵌**就有真字形。
 *
 * 實測（api-35 模擬器）：同樣八個字，「一」是 696 個暗像素、「鬱」是 4744 個
 * —— 差 6.8 倍。豆腐框（▯）畫出來兩者會一模一樣，所以這確定是真的字形，
 * 不是缺字的替代框。
 *
 * 這與 HTTP、LLM、PDF 讀取採同一個分工：**平台做得比我們好的事就交給平台**，
 * 不要為了它把二進位撐大。
 *
 * # 失敗就退回核心
 *
 * [PdfRenderer] 是系統元件，不是每一種內容都保證畫得出來。任何一步失敗就退回
 * `export_page_png` —— 灰條的版面仍然是對的（位置、行寬、行數、行高都照實算），
 * 比一張空白或一次例外好。
 */
object PageImageRenderer {

    /**
     * 算繪 `pageId` 這一頁並回傳 PNG 位元組。
     *
     * @param scale 相對於頁面點數的倍率（2.0 約等於 Retina 級）。
     */
    fun renderPng(session: PadnoteSession, pageId: String, scale: Float, cacheDir: File): ByteArray =
        runCatching { viaSystemRenderer(session, pageId, scale, cacheDir) }
            .getOrNull()
            ?: session.exportPagePng(pageId, scale)

    private fun viaSystemRenderer(
        session: PadnoteSession,
        pageId: String,
        scale: Float,
        cacheDir: File
    ): ByteArray? {
        // PdfRenderer 只吃檔案描述子，不吃位元組陣列，所以一定要先落地。
        val file = File(cacheDir, "render-${System.nanoTime()}.pdf")
        try {
            file.writeBytes(session.exportPagePdf(pageId))
            ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
                PdfRenderer(fd).use { renderer ->
                    if (renderer.pageCount < 1) return null
                    renderer.openPage(0).use { page ->
                        val w = (page.width * scale).toInt().coerceAtLeast(1)
                        val h = (page.height * scale).toInt().coerceAtLeast(1)
                        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                        // **底色一定要填白。** PdfRenderer 不會畫頁面背景，
                        // 留透明的話，存成 PNG 之後在淺色介面上看起來像空白頁。
                        bmp.eraseColor(Color.WHITE)
                        page.render(bmp, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        return ByteArrayOutputStream().use { out ->
                            bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
                            bmp.recycle()
                            out.toByteArray()
                        }
                    }
                }
            }
        } finally {
            file.delete()
        }
    }

    /** 一份外來 PDF 的頁數。讀不出來（壞檔、加密）回 0。 */
    fun pdfPageCount(file: File): Int = runCatching {
        ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
            PdfRenderer(fd).use { it.pageCount }
        }
    }.getOrDefault(0)

    /**
     * 把**外來** PDF 的某一頁算繪成 PNG，給「插入 PDF 頁面」用。
     *
     * 與上面那條路的差別只有來源：那邊畫的是我們自己匯出的一頁，這邊畫的
     * 是使用者挑進來的檔案。所以這裡**沒有退回核心那條路** —— 核心畫不出
     * 別人的 PDF，失敗就是失敗，要讓使用者看到「這一頁畫不出來」，
     * 而不是一張空白。
     *
     * @param pageIndex 從 0 起算。
     * @param scale 相對於頁面點數的倍率（2.0 約等於 Retina 級）。原尺寸插
     *   進來的話，在畫布上放大一點就糊掉了。
     */
    fun renderPdfPage(file: File, pageIndex: Int, scale: Float = 2.0f): ByteArray? = runCatching {
        ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
            PdfRenderer(fd).use { renderer ->
                if (pageIndex !in 0 until renderer.pageCount) return@runCatching null
                renderer.openPage(pageIndex).use { page ->
                    val w = (page.width * scale).toInt().coerceAtLeast(1)
                    val h = (page.height * scale).toInt().coerceAtLeast(1)
                    val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                    // **底色一定要填白。** PdfRenderer 不會畫頁面背景，留透明
                    // 的話插進畫布看起來像一張空白頁（同上面那條路的理由）。
                    bmp.eraseColor(Color.WHITE)
                    page.render(bmp, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                    ByteArrayOutputStream().use { out ->
                        bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
                        bmp.recycle()
                        out.toByteArray()
                    }
                }
            }
        }
    }.getOrNull()
}
