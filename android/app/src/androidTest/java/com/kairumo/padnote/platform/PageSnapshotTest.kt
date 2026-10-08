package com.kairumo.padnote.platform

import android.graphics.Bitmap
import androidx.activity.ComponentActivity
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.kairumo.padnote.ink.PageGeometry
import com.kairumo.padnote.text.TextBoxStore
import kotlinx.coroutines.runBlocking
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
 * 「所見即所得」的匯出（見 [PageSnapshot]）：用畫布自己的元件把一頁算成點陣圖。
 * 這些測試取**像素** —— 筆畫有沒有畫上去、文字方塊的底色在不在，看程式碼看不出來。
 */
@RunWith(AndroidJUnit4::class)
class PageSnapshotTest {

    // 不用 Compose 測試規則：它把畫面的時脈換成測試時脈，我們自己掛的 ComposeView 收不到幀。
    // 真正的 App 走的是真實的 Choreographer，這裡也要走真的。
    private lateinit var scenario: androidx.test.core.app.ActivityScenario<ComponentActivity>
    private lateinit var activity: ComponentActivity

    @org.junit.Before
    fun launch() {
        scenario = androidx.test.core.app.ActivityScenario.launch(ComponentActivity::class.java)
        scenario.onActivity { activity = it }
    }

    @org.junit.After
    fun close() {
        scenario.close()
    }

    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    private fun session(name: String): PadnoteSession {
        val dir = File(context.cacheDir, "snap-$name-${System.nanoTime()}")
        return PadnoteSession.create(dir.absolutePath, "快照測試", 1_757_635_200_000uL, 0xE1u)
    }

    private fun Bitmap.rgb(x: Int, y: Int): Triple<Int, Int, Int> {
        val p = getPixel(x, y)
        return Triple((p shr 16) and 0xFF, (p shr 8) and 0xFF, p and 0xFF)
    }

    @Test
    fun theSnapshotHasThePageSizeAndShowsInkAndATextBox() = runBlocking {
        val s = session("basic")
        val page = s.firstPageId()!!
        val points = (0 until 16).map { i ->
            StrokePoint(60f + i * 10f, 300f + i * 4f, 0.9f, 0.3f, 1f, if (i == 0) 0u else 8_333u)
        }
        s.addStroke(page, ToolKind.BALL_POINT, byteArrayOf(0, 0, 0, -1), 6f, points)
        val store = TextBoxStore(s, page)
        val box = store.create(100f, 600f)
        box.width = 300f
        box.height = 120f
        box.text = "Hello"
        box.backgroundColorHex = "#FF0000"
        store.persist(box)

        val bitmap = PageSnapshot.render(activity, s, 0, 1f, "en", null)
        assertNotNull("算繪逾時或失敗", bitmap)
        bitmap!!
        assertEquals(PageGeometry.width.toInt(), bitmap.width)
        assertEquals(PageGeometry.height.toInt(), bitmap.height)
        // 白紙。
        val paper = bitmap.rgb(5, 5)
        assertTrue("紙張應該是白的：$paper", paper.first > 235 && paper.second > 235 && paper.third > 235)
        // 筆畫上的點（第 8 個取樣點附近）要是黑的。
        val ink = bitmap.rgb(60 + 80, 300 + 32)
        assertTrue("筆畫沒有畫上去：$ink", ink.first < 90)
        // 文字方塊的紅色底（避開文字與邊框）。
        val fill = bitmap.rgb(100 + 250, 600 + 100)
        assertTrue("文字方塊的底色沒有畫上去：$fill", fill.first > 200 && fill.second < 80 && fill.third < 80)
    }

    @Test
    fun exportWysiwygWritesAPdfWithOnePagePerNotebookPage() = runBlocking {
        val s = session("pdf")
        s.addPage(uniffi.padnote_core.PageStyle.BLANK)
        val file = Exporter.exportWysiwyg(activity, s, Exporter.Format.PDF, 0, null).getOrThrow()
        assertEquals("%PDF", file.readBytes().copyOfRange(0, 4).toString(Charsets.US_ASCII))
        val renderer = android.graphics.pdf.PdfRenderer(
            android.os.ParcelFileDescriptor.open(file, android.os.ParcelFileDescriptor.MODE_READ_ONLY))
        try {
            assertEquals(2, renderer.pageCount)
        } finally {
            renderer.close()
        }
    }

    @Test
    fun pngExportIsTheCurrentPageNotAlwaysTheFirst() = runBlocking {
        val s = session("png")
        val second = s.addPage(uniffi.padnote_core.PageStyle.BLANK)
        val points = (0 until 16).map { i ->
            StrokePoint(60f + i * 10f, 300f + i * 4f, 0.9f, 0.3f, 1f, if (i == 0) 0u else 8_333u)
        }
        s.addStroke(second, ToolKind.BALL_POINT, byteArrayOf(0, 0, 0, -1), 6f, points)
        val file = Exporter.exportWysiwyg(activity, s, Exporter.Format.PNG, 1, null).getOrThrow()
        val bitmap = android.graphics.BitmapFactory.decodeFile(file.absolutePath)
        assertNotNull(bitmap)
        // 匯出是 2 倍，座標也乘 2。
        val ink = bitmap.rgb((60 + 80) * 2, (300 + 32) * 2)
        assertTrue("匯出的是第二頁，要看得到第二頁的筆畫：$ink", ink.first < 90)
        // 第一頁是空的：同一個位置是白的。
        val first = Exporter.exportWysiwyg(activity, s, Exporter.Format.PNG, 0, null).getOrThrow()
        val firstBitmap = android.graphics.BitmapFactory.decodeFile(first.absolutePath)
        assertTrue(firstBitmap.rgb((60 + 80) * 2, (300 + 32) * 2).first > 235)
    }
}
