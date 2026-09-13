package com.kairumo.padnote.chart

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.PadnoteSession
import java.io.File

/**
 * Android 的數字製圖（與 Apple 端同一組規則）。
 *
 * 重點不是「畫得好不好看」，而是三件事：
 * 1. 設定能無損地存進筆記檔再讀回來 —— 那是「可重新編修」的全部依據
 * 2. 版面來自核心，所以 Android 與 iPad 畫出來的是同一張圖
 * 3. 表格編輯不會把資料弄壞
 *
 * 對照 `apple/Tests/ChartStudioTests.swift`：同一組案例，兩邊各驗一次。
 */
@RunWith(AndroidJUnit4::class)
class ChartTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    private fun session(name: String): Pair<PadnoteSession, String> {
        val dir = File(context.cacheDir, "chart-$name-${System.nanoTime()}")
        val s = PadnoteSession.create(dir.absolutePath, "數字製圖", 1_757_635_200_000uL, 0xF2u)
        return s to s.firstPageId()!!
    }

    private fun sample(): ChartSpec = ChartSpec(
        kind = ChartKind.STACKED_BAR,
        title = "季度營收",
        categories = mutableListOf("Q1", "Q2", "Q3"),
        series = mutableListOf(
            ChartSeries("北區", mutableListOf(10.0, 20.0, 30.0)),
            ChartSeries("南區", mutableListOf(5.0, 15.0, 25.0), "#FF8800")
        ),
        dataLabels = ChartLabelPosition.OUTSIDE,
        labelDecimals = 1,
        barWidthRatio = 0.55
    ).apply { yAxis.title = "千元"; yAxis.min = -5.0 }

    // ── 可重新編修 ──────────────────────────────────────────

    @Test
    fun specSurvivesAJsonRoundTrip() {
        // 這條測試掉了，使用者再打開圖表時就只剩一張改不動的圖片。
        val restored = ChartSpec.decode(sample().encodedJson())!!
        assertEquals(ChartKind.STACKED_BAR, restored.kind)
        assertEquals("季度營收", restored.title)
        assertEquals(listOf("Q1", "Q2", "Q3"), restored.categories)
        assertEquals(listOf("北區", "南區"), restored.series.map { it.name })
        assertEquals(listOf(5.0, 15.0, 25.0), restored.series[1].values)
        assertEquals("#FF8800", restored.series[1].colorHex)
        assertEquals(ChartLabelPosition.OUTSIDE, restored.dataLabels)
        assertEquals(1, restored.labelDecimals)
        assertEquals("千元", restored.yAxis.title)
        assertEquals(-5.0, restored.yAxis.min!!, 1e-9)
        assertEquals(0.55, restored.barWidthRatio, 1e-9)
    }

    @Test
    fun theSameSpecEncodesToTheSameBytes() {
        // 不穩定的話，每次存檔都會產生一筆「內容有變」的操作，
        // 同步時看起來像使用者改了東西。
        val spec = sample()
        assertEquals(spec.encodedJson(), spec.encodedJson())
        assertEquals(spec.encodedJson(), ChartSpec.decode(spec.encodedJson())!!.encodedJson())
    }

    @Test
    fun anUnknownFieldDoesNotBreakDecoding() {
        // 新版多寫了欄位，舊版仍要打得開 —— 讀不回來等於使用者的資料消失。
        val spec = ChartSpec.decode("""{"kind":"line","series":[{"values":[1,2]}],"futureField":7}""")!!
        assertEquals(ChartKind.LINE, spec.kind)
        assertEquals(listOf(1.0, 2.0), spec.series[0].values)
    }

    @Test
    fun missingFieldsFallBackToTheSameDefaultsAsTheCore() {
        val spec = ChartSpec.decode("""{"series":[{"values":[1]}]}""")!!
        assertEquals(ChartKind.BAR, spec.kind)
        assertEquals(ChartLegendPosition.BOTTOM, spec.legend)
        assertTrue("Y 軸格線預設要開，跟核心與 Apple 一致", spec.yAxis.showGrid)
        assertEquals(0.7, spec.barWidthRatio, 1e-9)
    }

    @Test
    fun garbageDecodesToNullRatherThanCrashing() {
        assertNull(ChartSpec.decode("{ not json"))
        assertNull(ChartSpec.decode(""))
    }

    @Test
    fun theDefaultSpecComesFromTheCoreAndIsDrawable() {
        // 新插入的圖表必須馬上看得到東西，空白的圖表看起來像壞掉了。
        val spec = ChartSpec.makeDefault()
        assertTrue(spec.series.isNotEmpty())
        assertTrue(spec.isDrawable)
    }

    @Test
    fun anEmptySpecIsNotDrawable() {
        assertFalse(ChartSpec().isDrawable)
    }

    // ── 區塊外觀（跨平台的那一段）────────────────────────────

    @Test
    fun theBlockAppearanceRoundTripsThroughTheWrapper() {
        val spec = sample()
        val restored = ChartAppearance.decode(ChartAppearance.encode(spec))!!
        assertEquals("包一層之後設定變了", spec.encodedJson(), restored.encodedJson())
    }

    @Test
    fun aNonChartAppearanceIsNotMistakenForAChart() {
        // 文字方塊的外觀走的是同一個欄位。認錯了會把文字方塊當成圖表開。
        assertNull(ChartAppearance.decode("""{"backgroundColorHex":"clear"}"""))
        assertNull(ChartAppearance.decode("{}"))
        assertNull(ChartAppearance.decode("not json"))
    }

    // ── 存進筆記檔再讀回來 ───────────────────────────────────

    @Test
    fun aChartSurvivesTheNotebook() {
        // 這是使用者真正在乎的那條路：插一張圖、關掉、再打開，還改得動。
        val (s, page) = session("roundtrip")
        val store = ChartStore(s, page)
        val created = store.create(sample(), x = 120f, y = 240f)

        val reopened = ChartStore(s, page).apply { load() }
        assertEquals(1, reopened.all.size)
        val chart = reopened.all[0]
        assertEquals(created.id, chart.id)
        assertEquals("季度營收", chart.spec.title)
        assertEquals(listOf(10.0, 20.0, 30.0), chart.spec.series[0].values)
        assertEquals(120f, chart.x, 0.5f)
        assertEquals(240f, chart.y, 0.5f)
    }

    @Test
    fun editingAChartKeepsItsPlaceOnThePage() {
        // 使用者只是改了裡面的數字，圖不該跳回預設大小、跑回左上角。
        val (s, page) = session("edit-in-place")
        val store = ChartStore(s, page)
        val chart = store.create(sample(), x = 200f, y = 300f)

        val edited = chart.copy(spec = chart.spec.copySpec().apply { title = "改過的標題" })
        store.persist(edited)

        val reopened = ChartStore(s, page).apply { load() }.all[0]
        assertEquals("改過的標題", reopened.spec.title)
        assertEquals(200f, reopened.x, 0.5f)
        assertEquals(300f, reopened.y, 0.5f)
        assertEquals(chart.width, reopened.width, 0.5f)
    }

    @Test
    fun aPlainImageIsNotLoadedAsAChart() {
        // 一般的圖片照樣是圖片，不該被誤認成圖表而開進編輯器。
        val (s, page) = session("plain-image")
        val blob = s.putBlob(byteArrayOf(1, 2, 3))
        s.addImage(page, blob, 100f, 80f)

        val store = ChartStore(s, page).apply { load() }
        assertTrue(store.all.isEmpty())
    }

    @Test
    fun deletingAChartRemovesItFromTheNotebook() {
        val (s, page) = session("delete")
        val store = ChartStore(s, page)
        val chart = store.create(sample())
        store.remove(chart)

        assertTrue(ChartStore(s, page).apply { load() }.all.isEmpty())
    }

    @Test
    fun aChartWithoutASessionStillWorksInMemory() {
        // 核心開不起來時，介面不該整個癱掉 —— 至少讓使用者畫得出來。
        val store = ChartStore(null, null)
        val chart = store.create(sample())
        assertEquals(1, store.all.size)
        assertEquals("季度營收", chart.spec.title)
    }

    // ── 表格編輯 ────────────────────────────────────────────

    @Test
    fun addingARowExtendsEverySeries() {
        // 只加一欄的話，欄與欄會對不齊，圖就畫歪了。
        val spec = sample()
        spec.addRow()
        assertEquals(4, spec.rowCount)
        assertTrue(spec.series.all { it.values.size == 4 })
    }

    @Test
    fun removingARowRemovesItFromEverySeries() {
        val spec = sample()
        spec.removeRow(0)
        assertEquals(listOf("Q2", "Q3"), spec.categories)
        assertEquals(listOf(20.0, 30.0), spec.series[0].values)
        assertEquals(listOf(15.0, 25.0), spec.series[1].values)
    }

    @Test
    fun theLastRowCannotBeRemoved() {
        // 沒有資料的圖表畫不出來，畫布會忽然變空白。
        val spec = ChartSpec(
            categories = mutableListOf("唯一一列"),
            series = mutableListOf(ChartSeries(values = mutableListOf(1.0)))
        )
        spec.removeRow(0)
        assertEquals(1, spec.rowCount)
    }

    @Test
    fun theLastSeriesCannotBeRemoved() {
        val spec = ChartSpec(series = mutableListOf(ChartSeries(values = mutableListOf(1.0))))
        spec.removeSeries(0)
        assertEquals(1, spec.series.size)
    }

    @Test
    fun aNewSeriesIsAlignedAndColoured() {
        val spec = sample()
        spec.addSeries()
        assertEquals(3, spec.series.size)
        assertEquals("新數列沒有跟上列數", spec.rowCount, spec.series[2].values.size)
        assertTrue("新數列要拿到色盤的顏色", spec.series[2].colorHex.isNotEmpty())
    }

    @Test
    fun writingBeyondTheEndPadsInsteadOfCrashing() {
        val spec = sample()
        spec.setValue(99.0, 0, 6)
        assertEquals(99.0, spec.value(0, 6), 1e-9)
        assertEquals("中間的空格要補 0", 0.0, spec.value(0, 5), 1e-9)
    }

    @Test
    fun readingOutOfRangeReturnsZero() {
        val spec = sample()
        assertEquals(0.0, spec.value(9, 0), 1e-9)
        assertEquals(0.0, spec.value(0, 99), 1e-9)
    }

    @Test
    fun rowCountTakesTheLongerOfCategoriesAndValues() {
        // 使用者多打了一列數字卻沒補類別名稱時，那列不該消失。
        val spec = ChartSpec(
            categories = mutableListOf("a"),
            series = mutableListOf(ChartSeries(values = mutableListOf(1.0, 2.0, 3.0)))
        )
        assertEquals(3, spec.rowCount)
    }

    @Test
    fun theColourShownInThePickerIsTheColourDrawn() {
        // 取色器顯示的顏色跟畫出來的不一樣，使用者會以為自己改錯了。
        val spec = sample()
        spec.series[0].colorHex = ""
        assertEquals(uniffi.padnote_core.chartPaletteColor(0u), spec.effectiveColorHex(0))
        assertEquals("#FF8800", spec.effectiveColorHex(1))
    }

    // ── 算繪 ────────────────────────────────────────────────

    @Test
    fun everyChartKindRendersSomething() {
        // 新增類型時最容易發生的事，是忘了接上繪製 —— 圖表會靜靜地空白。
        for (kind in ChartKind.entries) {
            val spec = sample().apply { this.kind = kind }
            val bitmap = ChartRenderer.bitmap(spec, 420, 300)
            assertNotNull("$kind 算繪不出點陣圖", bitmap)
            assertFalse("$kind 算繪出來是一片空白", isBlank(bitmap!!))
        }
    }

    @Test
    fun aTinyCanvasReportsAReasonInsteadOfDrawingNothing() {
        val spec = sample()
        assertNull(ChartRenderer.layout(spec, 10f, 10f))
        assertTrue(
            "算不出來就要講出原因，空白畫布看起來像壞掉了",
            !ChartRenderer.failureReason(spec, 10f, 10f).isNullOrEmpty()
        )
    }

    @Test
    fun theLayoutComesFromTheCore() {
        // 幾何若哪天被搬回 Kotlin 算，兩個平台就會畫出不一樣的圖。
        val layout = ChartRenderer.layout(sample(), 420f, 300f)!!
        assertEquals("兩個數列三列資料應該是六根長條", 6, layout.bars.size)
        assertEquals(2, layout.legend.size)
        assertTrue(layout.labels.any { it.text == "季度營收" })
    }

    @Test
    fun bothPlatformsGetTheSameGeometry() {
        // 同一份設定、同一個尺寸，核心必須算出同一組數字 ——
        // 這是把版面放進核心的全部理由。Apple 端有對應的一條。
        val a = ChartRenderer.layout(sample(), 512f, 384f)!!
        val b = ChartRenderer.layout(sample(), 512f, 384f)!!
        assertEquals(a.bars.map { it.x to it.y }, b.bars.map { it.x to it.y })
        assertEquals(a.yTicks.map { it.label }, b.yTicks.map { it.label })
    }

    /** 這張圖是不是完全透明 —— 「有畫出東西」最低限度的檢查。 */
    private fun isBlank(bitmap: android.graphics.Bitmap): Boolean {
        val step = maxOf(1, bitmap.width / 24)
        for (x in 0 until bitmap.width step step) {
            for (y in 0 until bitmap.height step step) {
                if (android.graphics.Color.alpha(bitmap.getPixel(x, y)) > 0) return false
            }
        }
        return true
    }
}
