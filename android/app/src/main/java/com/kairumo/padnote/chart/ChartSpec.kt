package com.kairumo.padnote.chart

import org.json.JSONArray
import org.json.JSONObject
import uniffi.padnote_core.chartDefaultSpecJson
import uniffi.padnote_core.chartPaletteColor
import uniffi.padnote_core.chartPaletteCount
import uniffi.padnote_core.chartSpecIsDrawable

/**
 * 圖表的資料模型 —— 與核心 `padnote-chart` 的 `ChartSpec` 一對一對應。
 *
 * # 為什麼要有這份 Kotlin 鏡射
 *
 * 版面計算在核心（兩個平台才會算出同一張圖），但**編輯**發生在這裡：
 * 使用者改一個欄位，介面要立刻重畫。把規格留在 Kotlin，Compose 的狀態就能
 * 直接綁到每一個欄位；要重畫時再序列化成 JSON 交給核心。
 *
 * 這份 JSON 也是**存進筆記檔**的東西（走 `setBlockAppearance`）。存規格不是
 * 存圖片，所以圖表隨時都能重新編修 —— 存成圖片的話，那張圖就是最終產物，
 * 資料再也回不來。
 *
 * ⚠️ 鍵名必須與 Apple 的 `ChartSpec.swift` 和 Rust 的
 * `#[serde(rename_all = "camelCase")]` 完全一致。改這裡就要三邊一起改。
 */

/** 圖表類型。`wire` 即 JSON 值，必須與 Rust 的 `ChartKind` 一致。 */
enum class ChartKind(val wire: String) {
    BAR("bar"),
    STACKED_BAR("stackedBar"),
    HORIZONTAL_BAR("horizontalBar"),
    LINE("line"),
    SMOOTH_LINE("smoothLine"),
    AREA("area"),
    STACKED_AREA("stackedArea"),
    PIE("pie"),
    DOUGHNUT("doughnut"),
    SCATTER("scatter"),
    RADAR("radar");

    /** 有沒有直角座標軸 —— 沒有的話，軸的設定欄位就不該出現在介面上。 */
    val hasAxes: Boolean get() = this != PIE && this != DOUGHNUT && this != RADAR

    /**
     * 只畫第一個資料數列。
     *
     * 介面要據此提示使用者，而不是讓他納悶為什麼第二欄的數字沒有出現。
     */
    val usesSingleSeries: Boolean get() = this == PIE || this == DOUGHNUT

    /** 在地化鍵。字串表在六個語系裡都有，與 Apple 同一組鍵。 */
    val localizationKey: String get() = "chart_kind_$wire"

    companion object {
        fun from(wire: String?): ChartKind = entries.firstOrNull { it.wire == wire } ?: BAR
    }
}

enum class ChartLegendPosition(val wire: String) {
    NONE("none"), TOP("top"), BOTTOM("bottom"), RIGHT("right");

    val localizationKey: String get() = "chart_legend_$wire"

    companion object {
        fun from(wire: String?): ChartLegendPosition = entries.firstOrNull { it.wire == wire } ?: BOTTOM
    }
}

enum class ChartLabelPosition(val wire: String) {
    NONE("none"), OUTSIDE("outside"), INSIDE("inside"), CENTER("center");

    val localizationKey: String get() = "chart_labels_$wire"

    companion object {
        fun from(wire: String?): ChartLabelPosition = entries.firstOrNull { it.wire == wire } ?: NONE
    }
}

/** 一個座標軸的設定。 */
data class ChartAxisSpec(
    var title: String = "",
    var showLine: Boolean = true,
    var showTicks: Boolean = true,
    var showLabels: Boolean = true,
    var showGrid: Boolean = false,
    /** 固定最小值。`null` 代表由資料決定。 */
    var min: Double? = null,
    var max: Double? = null,
    /** 固定刻度間距。`null` 代表由核心挑一個「好看的數字」。 */
    var step: Double? = null
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("title", title)
        put("showLine", showLine)
        put("showTicks", showTicks)
        put("showLabels", showLabels)
        put("showGrid", showGrid)
        // null 的欄位不寫進去 —— 接收端才分得出「自動」與「設成 0」。
        min?.let { put("min", it) }
        max?.let { put("max", it) }
        step?.let { put("step", it) }
    }

    companion object {
        /** 缺欄位時回到預設值，不是解碼失敗 —— 別的平台可能還沒寫這個欄位。 */
        fun from(obj: JSONObject?, gridByDefault: Boolean = false): ChartAxisSpec {
            if (obj == null) return ChartAxisSpec(showGrid = gridByDefault)
            return ChartAxisSpec(
                title = obj.optString("title", ""),
                showLine = obj.optBoolean("showLine", true),
                showTicks = obj.optBoolean("showTicks", true),
                showLabels = obj.optBoolean("showLabels", true),
                showGrid = obj.optBoolean("showGrid", gridByDefault),
                min = if (obj.has("min") && !obj.isNull("min")) obj.getDouble("min") else null,
                max = if (obj.has("max") && !obj.isNull("max")) obj.getDouble("max") else null,
                step = if (obj.has("step") && !obj.isNull("step")) obj.getDouble("step") else null
            )
        }
    }
}

/** 一個資料數列 —— 試算表裡的一欄。 */
data class ChartSeries(
    var name: String = "",
    var values: MutableList<Double> = mutableListOf(),
    /** `#RRGGBB`。空字串代表用核心的預設色盤依序取色。 */
    var colorHex: String = ""
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("name", name)
        put("values", JSONArray().also { array -> values.forEach { array.put(it) } })
        put("colorHex", colorHex)
    }

    companion object {
        fun from(obj: JSONObject): ChartSeries {
            val array = obj.optJSONArray("values")
            val values = MutableList(array?.length() ?: 0) { array!!.optDouble(it, 0.0) }
            return ChartSeries(
                name = obj.optString("name", ""),
                values = values,
                colorHex = obj.optString("colorHex", "")
            )
        }
    }
}

/** 一張圖表的完整設定。 */
data class ChartSpec(
    var kind: ChartKind = ChartKind.BAR,
    var title: String = "",
    /** 類別名稱 —— 試算表裡的第一欄。 */
    var categories: MutableList<String> = mutableListOf(),
    var series: MutableList<ChartSeries> = mutableListOf(),

    var legend: ChartLegendPosition = ChartLegendPosition.BOTTOM,
    var dataLabels: ChartLabelPosition = ChartLabelPosition.NONE,
    var labelDecimals: Int = 0,

    var xAxis: ChartAxisSpec = ChartAxisSpec(),
    var yAxis: ChartAxisSpec = ChartAxisSpec(showGrid = true),

    /** 長條佔類別寬度的比例。Excel 的「類別間距」反過來講同一件事。 */
    var barWidthRatio: Double = 0.7,
    /** 環圈的內徑比例。 */
    var doughnutHoleRatio: Double = 0.55
) {

    // MARK: - JSON

    fun encodedJson(): String = JSONObject().apply {
        put("kind", kind.wire)
        put("title", title)
        put("categories", JSONArray().also { array -> categories.forEach { array.put(it) } })
        put("series", JSONArray().also { array -> series.forEach { array.put(it.toJson()) } })
        put("legend", legend.wire)
        put("dataLabels", dataLabels.wire)
        put("labelDecimals", labelDecimals)
        put("xAxis", xAxis.toJson())
        put("yAxis", yAxis.toJson())
        put("barWidthRatio", barWidthRatio)
        put("doughnutHoleRatio", doughnutHoleRatio)
    }.toString()

    // MARK: - 編輯

    /**
     * 表格的列數：類別數與最長數列取大的那個。
     *
     * 取大而不是取小：使用者多打了一列數字卻沒補類別名稱時，那列不該消失
     * （核心會用序號補上類別名）。
     */
    val rowCount: Int get() = maxOf(categories.size, series.maxOfOrNull { it.values.size } ?: 0)

    /** 讀第 [seriesIndex] 欄、第 [row] 列的數字。超出範圍回 0 而不是崩潰。 */
    fun value(seriesIndex: Int, row: Int): Double =
        series.getOrNull(seriesIndex)?.values?.getOrNull(row) ?: 0.0

    fun setValue(value: Double, seriesIndex: Int, row: Int) {
        val target = series.getOrNull(seriesIndex) ?: return
        while (target.values.size <= row) target.values.add(0.0)
        target.values[row] = value
    }

    fun category(index: Int): String = categories.getOrNull(index) ?: ""

    fun setCategory(name: String, index: Int) {
        while (categories.size <= index) categories.add("")
        categories[index] = name
    }

    /** 在表格末尾加一列。每一欄都要補一格，否則欄與欄會對不齊。 */
    fun addRow() {
        val row = rowCount
        categories.add("")
        series.forEach { s ->
            while (s.values.size < row) s.values.add(0.0)
            s.values.add(0.0)
        }
    }

    fun removeRow(row: Int) {
        // 最後一列不能刪：沒有資料的圖表畫不出來，畫布會忽然變空白。
        if (rowCount <= 1) return
        if (row in categories.indices) categories.removeAt(row)
        series.forEach { if (row in it.values.indices) it.values.removeAt(row) }
    }

    fun addSeries() {
        series.add(
            ChartSeries(
                values = MutableList(maxOf(1, rowCount)) { 0.0 },
                colorHex = chartPaletteColor((series.size % chartPaletteCount().toInt()).toUInt())
            )
        )
    }

    fun removeSeries(index: Int) {
        if (series.size <= 1 || index !in series.indices) return
        series.removeAt(index)
    }

    /** 第 [index] 欄實際會被畫成什麼顏色 —— 取色器要顯示的就是這個。 */
    fun effectiveColorHex(index: Int): String {
        val explicit = series.getOrNull(index)?.colorHex ?: ""
        return explicit.ifEmpty { chartPaletteColor(index.toUInt()) }
    }

    /** 能不能畫。核心說了算 —— 判斷條件抄第二份就會跟核心不一致。 */
    val isDrawable: Boolean get() = chartSpecIsDrawable(encodedJson())

    /** 深拷貝。Compose 的狀態要換成新物件才會觸發重組。 */
    fun copySpec(): ChartSpec = decode(encodedJson()) ?: ChartSpec()

    companion object {
        /** 從 JSON 讀回一份設定。讀不懂時回 `null`，呼叫端決定要不要退回成圖片。 */
        fun decode(json: String): ChartSpec? {
            val obj = runCatching { JSONObject(json) }.getOrNull() ?: return null
            val categoriesArray = obj.optJSONArray("categories")
            val seriesArray = obj.optJSONArray("series")
            return ChartSpec(
                kind = ChartKind.from(if (obj.has("kind")) obj.optString("kind") else null),
                title = obj.optString("title", ""),
                categories = MutableList(categoriesArray?.length() ?: 0) {
                    categoriesArray!!.optString(it, "")
                },
                series = MutableList(seriesArray?.length() ?: 0) {
                    ChartSeries.from(seriesArray!!.getJSONObject(it))
                },
                legend = ChartLegendPosition.from(if (obj.has("legend")) obj.optString("legend") else null),
                dataLabels = ChartLabelPosition.from(
                    if (obj.has("dataLabels")) obj.optString("dataLabels") else null
                ),
                labelDecimals = obj.optInt("labelDecimals", 0),
                xAxis = ChartAxisSpec.from(obj.optJSONObject("xAxis")),
                yAxis = ChartAxisSpec.from(obj.optJSONObject("yAxis"), gridByDefault = true),
                barWidthRatio = obj.optDouble("barWidthRatio", 0.7),
                doughnutHoleRatio = obj.optDouble("doughnutHoleRatio", 0.55)
            )
        }

        /** 核心給的預設設定 —— 新插入的圖表要馬上看得到東西。 */
        fun makeDefault(): ChartSpec = decode(chartDefaultSpecJson()) ?: ChartSpec()
    }
}

/**
 * 圖片區塊的外觀 JSON（`.padnote` 套件裡的 `SetBlockAppearance`）。
 *
 * 刻意包一層 `{"object":"chart","chart":{…}}` 而不是把規格直接寫進去：
 * 圖片區塊日後還會有別的外觀資訊，沒有這個標記的話，讀的人只能靠猜 JSON
 * 的形狀來判斷這是不是一張圖表。
 *
 * Apple 的 `ChartAppearance`（ChartSpec.swift）用同一組鍵。
 */
object ChartAppearance {
    private const val OBJECT_KEY = "object"
    private const val OBJECT_VALUE = "chart"
    private const val CHART_KEY = "chart"

    fun encode(spec: ChartSpec): String = JSONObject().apply {
        put(OBJECT_KEY, OBJECT_VALUE)
        put(CHART_KEY, JSONObject(spec.encodedJson()))
    }.toString()

    /** 從區塊外觀讀回規格。不是圖表時回 `null`。 */
    fun decode(json: String): ChartSpec? {
        val obj = runCatching { JSONObject(json) }.getOrNull() ?: return null
        if (obj.optString(OBJECT_KEY) != OBJECT_VALUE) return null
        val chart = obj.optJSONObject(CHART_KEY) ?: return null
        return ChartSpec.decode(chart.toString())
    }
}
