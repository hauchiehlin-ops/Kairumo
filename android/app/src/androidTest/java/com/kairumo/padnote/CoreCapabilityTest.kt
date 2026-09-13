package com.kairumo.padnote

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.PadnoteSession
import uniffi.padnote_core.StrokePoint
import uniffi.padnote_core.ToolKind
import java.io.File
import kotlin.math.sin

/**
 * Android 這組 feature（`--no-default-features --features relay`）下，核心到底
 * 給不給得出東西（工作包 WP6 的前提）。
 *
 * 「綁定裡有這個函式」不等於「它在這台裝置上會動」—— `asr` 與 `pdf` 兩個
 * feature 在 Android 版是關著的，所以哪些能力還在、哪些已經沒了，必須實測，
 * 不能從函式名單推論。
 */
@RunWith(AndroidJUnit4::class)
class CoreCapabilityTest {

    private fun session(name: String): Pair<PadnoteSession, String> {
        val dir = File(
            InstrumentationRegistry.getInstrumentation().targetContext.cacheDir,
            "cap-$name-${System.nanoTime()}"
        )
        val s = PadnoteSession.create(dir.absolutePath, "能力測試", 1_757_635_200_000uL, 0xC0u)
        val page = s.firstPageId()!!
        // 放一筆畫，免得匯出的是一張真的空白頁 —— 那樣測不出「內容有沒有進去」。
        val points = (0 until 24).map { i ->
            StrokePoint(
                x = 60f + i * 8f,
                y = 300f + sin(i * 0.4).toFloat() * 40f,
                pressure = 0.6f, tilt = 0.3f, azimuth = 1.0f,
                dtUs = if (i == 0) 0u else 8_333u
            )
        }
        s.addStroke(page, ToolKind.FOUNTAIN_PEN, byteArrayOf(0, 0, 0, -1), 3f, points)
        return s to page
    }

    @Test
    fun pdfExportWorksWithoutThePdfFeature() {
        // pdf feature 關的是 PDFium（讀 PDF）。匯出是 padnote-export 自己產的，
        // 兩者不是同一件事 —— 這條測試就是要確認我沒把它們搞混。
        val (s, _) = session("pdf")
        val bytes = s.exportPdf()
        assertTrue("PDF 應該有內容，實得 ${bytes.size} 位元組", bytes.size > 500)
        assertEquals("%PDF", String(bytes.copyOfRange(0, 4)))
    }

    @Test
    fun singlePagePdfExportWorks() {
        val (s, page) = session("page-pdf")
        val bytes = s.exportPagePdf(page)
        assertEquals("%PDF", String(bytes.copyOfRange(0, 4)))
    }

    @Test
    fun pngExportProducesARealPngHeader() {
        val (s, page) = session("png")
        val bytes = s.exportPagePng(page, 2f)
        val signature = byteArrayOf(-119, 80, 78, 71, 13, 10, 26, 10) // \x89PNG\r\n\x1a\n
        assertTrue("PNG 應該有內容，實得 ${bytes.size} 位元組", bytes.size > 100)
        assertTrue("不是合法的 PNG 檔頭", bytes.copyOfRange(0, 8).contentEquals(signature))
    }

    @Test
    fun markdownExportContainsTheTitle() {
        val (s, _) = session("md")
        val md = s.exportMarkdown()
        assertTrue("Markdown 應該帶標題，實得：${md.take(80)}", md.contains("能力測試"))
    }

    @Test
    fun printDataIsAPdf() {
        // 系統列印面板吃的就是這份位元組。
        val (s, _) = session("print")
        val bytes = s.printData(pageId = null)
        assertEquals("%PDF", String(bytes.copyOfRange(0, 4)))
    }

    @Test
    fun recordingAcceptsAudioWithoutTheAsrFeature() {
        // asr 關掉的是轉錄（ONNX）。錄音本身是 Opus，libopus 有交叉編譯進來 ——
        // 所以「第一版不含語音轉錄」不該連錄音都做不了。
        val (s, _) = session("rec")
        s.startRecording()
        assertTrue(s.isRecording())

        // 0.5 秒的 16kHz 單聲道正弦波
        val pcm = FloatArray(8_000) { sin(it * 0.05).toFloat() * 0.3f }
        val stats = s.feedAudio(pcm.toList())
        s.stopRecording()

        assertTrue("應該有音框寫進檔案，實得 ${stats.framesWritten}", stats.framesWritten > 0uL)
        assertTrue("錄到的時長應該大於 0", s.recordedAudioUs() > 0uL)
        assertTrue(!s.isRecording())
    }

    @Test
    fun recognizedHandwritingBecomesSearchable() {
        // WP7 的驗收條件是「辨識結果進入全文搜尋索引且搜得到」。
        //
        // 辨識本身要模型、要網路，放進自動化測試會變成在測 Google 的服務。
        // 這裡用固定文字走同一條回填路徑，把「索引 → 搜尋」這一段釘死；
        // 辨識那一段由實機操作驗證（見 DEVLOG）。
        val (s, page) = session("hwr")
        val strokeId = s.visibleStrokeDetails(page).first().id

        s.indexHandwriting(page, strokeId, "會議紀錄")

        val hits = s.search("會議", 10u)
        assertTrue("辨識出來的字應該搜得到", hits.isNotEmpty())
        assertTrue(
            "命中來源應該標成手寫，實得 ${hits.map { it.source }}",
            hits.any { it.source.contains("hand", ignoreCase = true) }
        )
    }

    @Test
    fun searchFindsTextWrittenOnThisDevice() {
        val (s, page) = session("search")
        s.addText(page, "會議重點：下週交付", uniffi.padnote_core.BlockStyle.BODY)
        val hits = s.search("交付", 10u)
        assertTrue("全文搜尋應該找得到剛寫的字", hits.isNotEmpty())
    }
}
