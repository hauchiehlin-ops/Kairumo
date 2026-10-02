package com.kairumo.padnote.platform

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.kairumo.padnote.ink.PageGeometry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/**
 * 「匯入文件」。對照 `apple/Tests/ShapeEditingTests.swift` 裡的匯入那幾條。
 *
 * 守的是「使用者按下去之後**看得到東西**」：解析得出原生物件、依順序由上往下排、
 * 放不下的接到下一頁、空文件明確回報而不是什麼都不做。
 */
@RunWith(AndroidJUnit4::class)
class DocumentImportTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    private fun file(name: String, text: String): File =
        File(context.cacheDir, "doc-$name-${System.nanoTime()}").apply { writeText(text) }

    @Test
    fun markdownBecomesNativeTextBlocksInDocumentOrder() {
        val md = file("a.md", "# 標題\n\n第一段文字\n\n第二段文字\n")
        // 副檔名要在存下來的檔名上 —— 核心靠它認格式。
        val named = File(md.parentFile, md.name + ".md").also { md.renameTo(it) }

        val parsed = DocumentImport.parse(context.cacheDir, named, "a")
        val texts = parsed.pieces.filterIsInstance<DocumentImport.TextPiece>()
        assertTrue("Markdown 要展開成文字方塊", texts.isNotEmpty())
        assertTrue(texts.any { it.text.contains("第一段文字") })
        val first = texts.indexOfFirst { it.text.contains("第一段文字") }
        val second = texts.indexOfFirst { it.text.contains("第二段文字") }
        assertTrue("依文件順序", first < second)
    }

    @Test
    fun anEmptyDocumentIsReportedNotSwallowed() {
        val md = file("empty", " \n")
        val named = File(md.parentFile, md.name + ".md").also { md.renameTo(it) }
        try {
            DocumentImport.parse(context.cacheDir, named, "empty")
            fail("空文件應該丟例外")
        } catch (_: DocumentImport.EmptyDocumentException) {
        }
    }

    @Test
    fun flowStacksBlocksAndSpillsOntoTheNextPage() {
        val usable = PageGeometry.height - PageGeometry.PRINTABLE_INSET * 2
        val placed = DocumentImport.flow(listOf(100f, 100f, usable - 400f, 200f))
        assertEquals(PageGeometry.PRINTABLE_INSET, placed[0].y, 0f)
        assertTrue("第二塊要排在第一塊下面，不是疊在上面", placed[1].y > placed[0].y + 100f)
        assertEquals(0, placed[2].pageOffset)
        assertEquals("放不下的接到下一頁", 1, placed[3].pageOffset)
        assertEquals(PageGeometry.PRINTABLE_INSET, placed[3].y, 0f)
    }

    @Test
    fun anOversizedBlockGetsItsOwnPageInsteadOfLoopingForever() {
        val placed = DocumentImport.flow(listOf(50f, 99999f, 50f))
        assertEquals(1, placed[1].pageOffset)
        assertEquals(2, placed[2].pageOffset)
    }

    @Test
    fun estimatedHeightGrowsWithTextAndTreatsCjkAsWider() {
        val short = DocumentImport.estimatedHeight("hi", 16f, 400f)
        val long = DocumentImport.estimatedHeight("word ".repeat(200), 16f, 400f)
        assertTrue(long > short)
        assertTrue(
            DocumentImport.estimatedHeight("字".repeat(60), 16f, 200f) >
                DocumentImport.estimatedHeight("a".repeat(60), 16f, 200f)
        )
    }
}
