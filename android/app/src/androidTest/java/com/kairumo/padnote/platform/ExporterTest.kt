package com.kairumo.padnote.platform

import android.content.Intent
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.PadnoteSession
import uniffi.padnote_core.StrokePoint
import uniffi.padnote_core.ToolKind
import java.io.File

/**
 * 匯出與分享（工作包 WP6）。
 *
 * 重點不在「有沒有產生檔案」，而在**產生的是不是真的那種檔案**，以及
 * 分享出去的 URI 對方打不打得開。授權旗標少一個，接收方拿到的就是一個
 * 開不起來的連結 —— 而在自己的裝置上測完全看不出來。
 */
@RunWith(AndroidJUnit4::class)
class ExporterTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    private fun session(name: String): PadnoteSession {
        val dir = File(context.cacheDir, "exp-$name-${System.nanoTime()}")
        val s = PadnoteSession.create(dir.absolutePath, "匯出測試", 1_757_635_200_000uL, 0xE0u)
        val page = s.firstPageId()!!
        val points = (0 until 16).map { i ->
            StrokePoint(60f + i * 10f, 300f + i * 4f, 0.6f, 0.3f, 1f, if (i == 0) 0u else 8_333u)
        }
        s.addStroke(page, ToolKind.FOUNTAIN_PEN, byteArrayOf(0, 0, 0, -1), 3f, points)
        return s
    }

    @Test
    fun pdfExportProducesARealPdfOnDisk() {
        val file = Exporter.export(context, session("pdf"), Exporter.Format.PDF).getOrThrow()
        assertTrue(file.exists())
        assertTrue("PDF 太小，可能是空的：${file.length()} 位元組", file.length() > 500)
        assertEquals("%PDF", file.readBytes().copyOfRange(0, 4).toString(Charsets.US_ASCII))
    }

    @Test
    fun pngExportProducesARealPngOnDisk() {
        val file = Exporter.export(context, session("png"), Exporter.Format.PNG).getOrThrow()
        val signature = byteArrayOf(-119, 80, 78, 71, 13, 10, 26, 10)
        assertTrue(file.readBytes().copyOfRange(0, 8).contentEquals(signature))
    }

    @Test
    fun markdownExportIsReadableText() {
        val file = Exporter.export(context, session("md"), Exporter.Format.MARKDOWN).getOrThrow()
        assertTrue(file.readText().contains("匯出測試"))
    }

    @Test
    fun exportsLandInPrivateCacheNotExternalStorage() {
        // 匯出的是使用者的筆記內容。放到外部儲存等於任何 App 都讀得到。
        val file = Exporter.export(context, session("loc"), Exporter.Format.PDF).getOrThrow()
        assertTrue(
            "匯出檔跑到 App 私有 cache 之外：${file.absolutePath}",
            file.absolutePath.startsWith(context.cacheDir.absolutePath)
        )
    }

    @Test
    fun consecutiveExportsDoNotOverwriteEachOther() {
        // 使用者常常兩份都要。第二次把第一次蓋掉是很難發現的資料遺失。
        val s = session("twice")
        val a = Exporter.export(context, s, Exporter.Format.PDF).getOrThrow()
        Thread.sleep(2)
        val b = Exporter.export(context, s, Exporter.Format.PDF).getOrThrow()
        assertTrue(a.name != b.name)
        assertTrue(a.exists() && b.exists())
    }

    @Test
    fun shareIntentGrantsReadPermissionToTheReceiver() {
        // 少了這個旗標，接收方拿到的是一個開不起來的 URI ——
        // 而寄件者這邊完全看不出有問題。
        val file = Exporter.export(context, session("share"), Exporter.Format.PDF).getOrThrow()
        val intent = Exporter.shareIntent(context, file, Exporter.Format.PDF)

        assertEquals(Intent.ACTION_SEND, intent.action)
        assertEquals("application/pdf", intent.type)
        assertNotNull(intent.getParcelableExtra<android.net.Uri>(Intent.EXTRA_STREAM))
        assertTrue(
            "缺少 FLAG_GRANT_READ_URI_PERMISSION",
            intent.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0
        )
    }

    @Test
    fun sharedUriGoesThroughFileProviderNotARawFilePath() {
        // file:// 的 URI 在 Android 7 之後丟給別的 App 會直接丟 FileUriExposedException。
        val file = Exporter.export(context, session("uri"), Exporter.Format.PDF).getOrThrow()
        val uri = Exporter.shareIntent(context, file, Exporter.Format.PDF)
            .getParcelableExtra<android.net.Uri>(Intent.EXTRA_STREAM)!!
        assertEquals("content", uri.scheme)
        assertTrue(uri.authority!!.endsWith(".fileprovider"))
    }
}
