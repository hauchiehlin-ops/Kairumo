package com.kairumo.padnote.screens

import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.kairumo.padnote.platform.PageImageRenderer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/**
 * 「插入 PDF 頁面」真的畫得出東西嗎？
 *
 * # 為什麼要有這條
 *
 * 這條路上每一步都是系統 API（`PdfRenderer`），編得過完全不代表跑得動 ——
 * 而它的失敗方式**不會丟例外**：畫出一張全白的圖。使用者看到的是「插進去
 * 了，可是是空白的」，沒有任何錯誤訊息可以查。
 *
 * 所以這裡不只看「有沒有回傳位元組」，還數了非白的像素。
 */
@RunWith(AndroidJUnit4::class)
class PdfPageRenderTest {

    private val cacheDir: File
        get() = InstrumentationRegistry.getInstrumentation().targetContext.cacheDir

    /** 造一份三頁的 PDF，每頁畫一個黑方塊（第幾頁就畫幾個）。 */
    private fun makePdf(pages: Int): File {
        val doc = PdfDocument()
        val paint = Paint().apply { color = Color.BLACK }
        for (i in 0 until pages) {
            val page = doc.startPage(PdfDocument.PageInfo.Builder(200, 300, i + 1).create())
            for (n in 0..i) {
                val left = 10f + n * 40f
                page.canvas.drawRect(left, 10f, left + 30f, 40f, paint)
            }
            doc.finishPage(page)
        }
        val file = File(cacheDir, "probe-${System.nanoTime()}.pdf")
        file.outputStream().use { doc.writeTo(it) }
        doc.close()
        return file
    }

    private fun darkPixels(png: ByteArray): Int {
        val bmp = BitmapFactory.decodeByteArray(png, 0, png.size)
        assertNotNull("算繪出來的位元組不是一張圖", bmp)
        var dark = 0
        for (y in 0 until bmp.height) {
            for (x in 0 until bmp.width) {
                if (Color.red(bmp.getPixel(x, y)) < 128) dark++
            }
        }
        return dark
    }

    @Test
    fun everyPageRendersItsOwnContent() {
        val file = makePdf(3)
        try {
            assertEquals(3, PageImageRenderer.pdfPageCount(file))

            // 每一頁畫的方塊數不同，所以暗像素也該不同 —— 只看「有沒有東西」
            // 的話，一支永遠回傳第一頁的實作也會過。
            val counts = (0 until 3).map { index ->
                val png = PageImageRenderer.renderPdfPage(file, index)
                assertNotNull("第 ${index + 1} 頁算不出來", png)
                darkPixels(png!!)
            }

            assertTrue("第一頁一個暗像素都沒有 —— 畫出來是全白的", counts[0] > 0)
            assertTrue(
                "三頁的內容量一樣（$counts）—— 多半每次都畫了同一頁",
                counts.distinct().size == 3)
            assertTrue("頁數愈後面方塊愈多，暗像素卻沒有遞增：$counts",
                counts[0] < counts[1] && counts[1] < counts[2])
        } finally {
            file.delete()
        }
    }

    @Test
    fun anOutOfRangePageIsRefusedNotGuessed() {
        // 回 null 才能讓介面顯示「這一頁畫不出來」。悄悄退回第一頁的話，
        // 使用者拿到的是一頁他沒有選的東西。
        val file = makePdf(1)
        try {
            assertNull(PageImageRenderer.renderPdfPage(file, 5))
            assertNull(PageImageRenderer.renderPdfPage(file, -1))
        } finally {
            file.delete()
        }
    }

    @Test
    fun abrokenFileFailsQuietlyInsteadOfCrashing() {
        // 副檔名是 .pdf 但內容不是 —— 核心的 `importCheck` 只看副檔名
        // （刻意的），所以這種檔案一定會走到這裡。
        val file = File(cacheDir, "broken-${System.nanoTime()}.pdf")
        file.writeBytes("this is not a pdf".toByteArray())
        try {
            assertEquals(0, PageImageRenderer.pdfPageCount(file))
            assertNull(PageImageRenderer.renderPdfPage(file, 0))
        } finally {
            file.delete()
        }
    }
}
