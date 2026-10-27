package com.kairumo.padnote.screens

import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import android.os.Looper
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.kairumo.padnote.canvas.ObjectStacking
import com.kairumo.padnote.platform.PageImageRenderer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/**
 * 整份匯入 PDF 與「筆跡畫在 PDF 上面」（Android）。Apple 端是 `PdfImportAndLayeringTests`。
 *
 * 1. 掃描版 PDF（頁面寫成 2480×3508）不能再照「點數 × 2」算繪成 4960×7016。
 * 2. 每一頁 PDF 依內頁大小放置（核心 `pdfPagePlacement`）。
 * 3. 圖片預設在筆跡下方、文字在上方（核心 `ffi_layering`）。
 */
@RunWith(AndroidJUnit4::class)
class PdfImportAndLayeringTest {

    private val cacheDir: File
        get() = InstrumentationRegistry.getInstrumentation().targetContext.cacheDir

    private fun makePdf(pages: Int, width: Int, height: Int): File {
        val doc = PdfDocument()
        val paint = Paint().apply { color = Color.BLACK }
        for (i in 0 until pages) {
            val page = doc.startPage(PdfDocument.PageInfo.Builder(width, height, i + 1).create())
            page.canvas.drawRect(10f, 10f, width / 4f, height / 4f, paint)
            doc.finishPage(page)
        }
        val file = File(cacheDir, "import-${System.nanoTime()}.pdf")
        file.outputStream().use { doc.writeTo(it) }
        doc.close()
        return file
    }

    @Test
    fun aScannerSizedPageIsCappedAndFillsTheNotebookPage() {
        val file = makePdf(2, 2480, 3508)
        try {
            ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
                PdfRenderer(fd).use { renderer ->
                    for (i in 0 until renderer.pageCount) {
                        val page = PageImageRenderer.renderPdfPageForImport(renderer, i, 800f, 1131f)
                        assertNotNull("第 ${i + 1} 頁算不出來", page)
                        val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                        BitmapFactory.decodeByteArray(page!!.png, 0, page.png.size, opts)
                        assertTrue("像素沒有夾住：${opts.outWidth}×${opts.outHeight}",
                            maxOf(opts.outWidth, opts.outHeight) <= 3072)
                        assertTrue(opts.outWidth < 4960)
                        assertEquals(1131f, page.height, 0.5f)
                        assertEquals(0f, page.y, 0f)
                        assertEquals(400f, page.x + page.width / 2f, 0.5f)
                    }
                }
            }
        } finally {
            file.delete()
        }
    }

    @Test
    fun thePreviewIsCappedToo() {
        val file = makePdf(1, 2480, 3508)
        try {
            val png = PageImageRenderer.renderPdfPage(file, 0)
            assertNotNull(png)
            val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(png!!, 0, png.size, opts)
            assertTrue(maxOf(opts.outWidth, opts.outHeight) <= 3072)
        } finally {
            file.delete()
        }
    }

    @Test
    fun renderingWorksOffTheMainThread() {
        val file = makePdf(3, 595, 842)
        try {
            var rendered = 0
            val worker = Thread {
                assertFalse(Looper.myLooper() == Looper.getMainLooper())
                ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
                    PdfRenderer(fd).use { r ->
                        rendered = (0 until r.pageCount).count {
                            PageImageRenderer.renderPdfPageForImport(r, it, 595f, 842f) != null
                        }
                    }
                }
            }
            worker.start(); worker.join()
            assertEquals(3, rendered)
        } finally {
            file.delete()
        }
    }

    @Test
    fun insertedMaterialIsBelowInkAndTextAbove() {
        val kinds = mapOf(
            "pdf" to ObjectStacking.Kind.IMAGE,
            "chart" to ObjectStacking.Kind.CHART,
            "table" to ObjectStacking.Kind.TABLE,
            "audio" to ObjectStacking.Kind.AUDIO,
            "note" to ObjectStacking.Kind.TEXT,
            "pin" to ObjectStacking.Kind.PIN,
        )
        val below = ObjectStacking.belowInk(kinds, emptySet(), emptySet())
        assertEquals(setOf("pdf", "chart", "table", "audio"), below)
        // 使用者的明確設定蓋過預設。
        val moved = ObjectStacking.belowInk(kinds, setOf("note"), setOf("pdf"))
        assertTrue("note" in moved)
        assertFalse("pdf" in moved)
        // z 值：下方的在筆跡畫布（100）之下，上方的在它之上。
        assertTrue(ObjectStacking.inkAwareZ(5f, true) < 100f)
        assertTrue(ObjectStacking.inkAwareZ(0f, false) > 100f)
    }

    @Test
    fun theKindOrderMatchesTheCoreRanks() {
        // 主機上的單元測試載不到核心時退回宣告順序；這裡在裝置上確認兩者一致。
        for (kind in ObjectStacking.Kind.entries) {
            assertEquals(kind.name, kind.ordinal,
                uniffi.padnote_core.objectDefaultStackRank(kind.layerKind).toInt().let { rank ->
                    ObjectStacking.Kind.entries.sortedBy {
                        uniffi.padnote_core.objectDefaultStackRank(it.layerKind)
                    }.indexOf(kind)
                })
        }
    }
}
