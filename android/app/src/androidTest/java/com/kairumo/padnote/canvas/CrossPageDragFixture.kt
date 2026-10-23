package com.kairumo.padnote.canvas

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.kairumo.padnote.chart.ChartSeries
import com.kairumo.padnote.chart.ChartSpec
import com.kairumo.padnote.chart.ChartStore
import com.kairumo.padnote.image.ImageStore
import com.kairumo.padnote.library.NotebookLibrary
import com.kairumo.padnote.profile.ProfileContext
import com.kairumo.padnote.shape.NoteShape
import com.kairumo.padnote.shape.ShapeStore
import com.kairumo.padnote.table.NoteTable
import com.kairumo.padnote.table.TableStore
import com.kairumo.padnote.text.TextBoxStore
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * 手動驗證「連續模式把物件拖到下一頁」用的測試筆記：兩頁，第 1 頁上圖片、圖表、文字框、表格、形狀各一個。
 *
 * **不是一般測試**：只在帶了 `-e seedCrossPage true` 時才建，平常跑整組測試會略過 ——
 * 它寫進的是 App 真正的筆記庫，不能每跑一次測試就多一本。固定 id，重跑會先刪掉舊的。
 *
 * ```
 * adb shell am instrument -w -e seedCrossPage true \
 *   -e class com.kairumo.padnote.canvas.CrossPageDragFixture \
 *   com.kairumo.padnote.test/androidx.test.runner.AndroidJUnitRunner
 * adb shell am start -n com.kairumo.padnote/.MainActivity --es open_notebook_id uitest-crosspage
 * ```
 */
@RunWith(AndroidJUnit4::class)
class CrossPageDragFixture {

    @Test
    fun seedTwoPagesWithEveryDraggableObject() {
        assumeTrue(InstrumentationRegistry.getArguments().getString("seedCrossPage") == "true")
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val saved = ProfileContext.prefs(context, "kairumo").getInt("deviceId", 0)
        val device = if (saved != 0) saved.toUInt() else 0xE7u
        val id = "uitest-crosspage"

        File(NotebookLibrary.directory(context), "$id.${NotebookLibrary.EXTENSION}").deleteRecursively()
        NotebookLibrary.invalidateCache()
        NotebookLibrary.create(context, "Cross-page drag", device, id = id)!!
        val (session, firstPage) = NotebookLibrary.open(context, id, device)!!
        if (session.pageCount().toInt() < 2) session.addPage(uniffi.padnote_core.PageStyle.BLANK)

        val png = ByteArrayOutputStream().also { out ->
            Bitmap.createBitmap(120, 120, Bitmap.Config.ARGB_8888).also { Canvas(it).drawColor(Color.rgb(255, 149, 0)) }
                .compress(Bitmap.CompressFormat.PNG, 100, out)
        }.toByteArray()
        // 全部放在第 1 頁底部、尺寸縮小：捲到頁界時，物件與第 2 頁的開頭要同時在畫面上，
        // 一次拖曳才拖得過去（測試用的 adb 沒有雙指縮放）。
        ImageStore(session, firstPage).let { store ->
            store.insert(png, "fixture.png")!!.also { it.x = 40f; it.y = 1000f; it.width = 90f; it.height = 90f; store.persist(it) }
        }
        ChartStore(session, firstPage).let { store ->
            val chart = store.create(
                ChartSpec(
                    title = "Chart",
                    categories = mutableListOf("A", "B"),
                    series = mutableListOf(ChartSeries("S", mutableListOf(3.0, 5.0)))
                ),
                x = 150f, y = 1000f
            )
            store.persist(chart.copy(width = 140f, height = 90f))
        }
        TextBoxStore(session, firstPage).let { store ->
            store.create(x = 310f, y = 1000f).also {
                it.text = "Fixture text"; it.width = 150f; it.height = 60f; store.persist(it)
            }
        }
        TableStore(session, firstPage).create(
            NoteTable(rows = 2, cols = 2, cells = mutableListOf("A", "B", "C", "D"), headerRow = true)
                .apply { x = 480f; y = 1000f; width = 130f }
        )
        ShapeStore(session, firstPage).create(
            NoteShape(
                kindName = "process",
                x = 630f, y = 1000f, width = 120f, height = 60f,
                label = "Fixture shape",
                strokeColorHex = "#FF3B30",
                lineWidth = 4f
            )
        )
        NotebookLibrary.invalidateCache()
    }

    @Test
    fun verifyAllObjectsOnSecondPage() {
        assumeTrue(InstrumentationRegistry.getArguments().getString("verifyCrossPage") == "true")
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val saved = ProfileContext.prefs(context, "kairumo").getInt("deviceId", 0)
        val device = if (saved != 0) saved.toUInt() else 0xE7u
        val id = "uitest-crosspage"

        NotebookLibrary.invalidateCache()
        val (session, firstPage) = NotebookLibrary.open(context, id, device)!!
        val secondPage = session.pageIdAt(1u)

        val p1Images = ImageStore(session, firstPage).also { it.load() }.all
        val p1Charts = ChartStore(session, firstPage).also { it.load() }.all
        val p1Texts = TextBoxStore(session, firstPage).also { it.load() }.all
        val p1Tables = TableStore(session, firstPage).also { it.load() }.all
        val p1Shapes = ShapeStore(session, firstPage).also { it.load() }.all

        val p2Images = ImageStore(session, secondPage).also { it.load() }.all
        val p2Charts = ChartStore(session, secondPage).also { it.load() }.all
        val p2Texts = TextBoxStore(session, secondPage).also { it.load() }.all
        val p2Tables = TableStore(session, secondPage).also { it.load() }.all
        val p2Shapes = ShapeStore(session, secondPage).also { it.load() }.all

        org.junit.Assert.assertEquals("Page 1 images: $p1Images, Page 2 images: $p2Images", 0, p1Images.size)
        org.junit.Assert.assertEquals("Page 1 charts: $p1Charts, Page 2 charts: $p2Charts", 0, p1Charts.size)
        org.junit.Assert.assertEquals("Page 1 texts: $p1Texts, Page 2 texts: $p2Texts", 0, p1Texts.size)
        org.junit.Assert.assertEquals("Page 1 tables: $p1Tables, Page 2 tables: $p2Tables", 0, p1Tables.size)
        org.junit.Assert.assertEquals("Page 1 shapes: $p1Shapes, Page 2 shapes: $p2Shapes", 0, p1Shapes.size)

        org.junit.Assert.assertEquals(1, p2Images.size)
        org.junit.Assert.assertEquals(1, p2Charts.size)
        org.junit.Assert.assertEquals(1, p2Texts.size)
        org.junit.Assert.assertEquals(1, p2Tables.size)
        org.junit.Assert.assertEquals(1, p2Shapes.size)
        org.junit.Assert.assertEquals("#FF3B30", p2Shapes.single().strokeColorHex)
        org.junit.Assert.assertEquals(4f, p2Shapes.single().lineWidth, 0.01f)
    }

    @Test
    fun cleanupCrossPageFixture() {
        assumeTrue(InstrumentationRegistry.getArguments().getString("cleanupCrossPage") == "true")
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val id = "uitest-crosspage"
        File(NotebookLibrary.directory(context), "$id.${NotebookLibrary.EXTENSION}").deleteRecursively()
        NotebookLibrary.invalidateCache()
    }
}
