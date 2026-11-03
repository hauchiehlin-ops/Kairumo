package com.kairumo.padnote.table

import org.json.JSONArray
import org.json.JSONObject
import uniffi.padnote_core.FfiTable
import uniffi.padnote_core.FfiTableLayout
import uniffi.padnote_core.tableLayout

/**
 * 畫布上的表格（Android）。
 *
 * 與 Apple 的 `NoteTableAttachment` 一對一對應：同一組欄位、同一組 JSON 鍵、
 * 同一個核心版面引擎。
 *
 * 儲存格用**扁平陣列**逐列展開，與核心的 `BlockKind::Table` 一致。
 * 巢狀陣列在增刪欄時要逐列處理，而且容易出現長度不一致的列 ——
 * 那種錯誤在畫面上是「某一列少一格」，而且只有那一列。
 */
data class NoteTableSpan(
    var row: Int,
    var col: Int,
    var rowSpan: Int,
    var colSpan: Int
)

data class NoteTable(
    val id: String = java.util.UUID.randomUUID().toString(),
    var x: Float = 60f,
    var y: Float = 120f,
    var width: Float = 440f,
    var rows: Int = 3,
    var cols: Int = 3,
    var cells: MutableList<String> = mutableListOf(),
    var headerRow: Boolean = true,
    var mergedCells: MutableList<NoteTableSpan> = mutableListOf(),
    var fontSize: Float = 14f,
    var ruleColorHex: String? = null,
    /**
     * 繞自身中心的旋轉角度（度，順時針）。`null` = 沒設定（等同 0）。
     *
     * 與 Apple 端 `NoteTableAttachment.rotationDegrees` 同一個鍵、同一個語意。
     */
    var rotationDegrees: Float? = null,
    /** `"clear"` 為透明。 */
    var headerBackgroundHex: String? = null,
    /**
     * 手動列高（點），逐列一個。`0` 或小於 [MIN_ROW_OVERRIDE] 的項目為自動，`null` 為全部自動。
     *
     * 與 Apple 端 `NoteTableAttachment.rowHeightOverrides` 同一個語意；存在外觀裡的鍵是
     * `rowHeights`（Apple `TableAppearance` 同一個鍵），兩端看到同一張表的列高一樣。
     */
    var rowHeightOverrides: MutableList<Double>? = null
) {
    init {
        rows = maxOf(1, rows)
        cols = maxOf(1, cols)
        // 長度一律補齊：少一格在畫面上是「某一列少一格」，而且只有那一列。
        while (cells.size < rows * cols) cells.add("")
        while (cells.size > rows * cols) cells.removeAt(cells.size - 1)
    }

    // MARK: - 讀寫

    fun cell(row: Int, col: Int): String = cells.getOrNull(row * cols + col) ?: ""

    fun setCell(text: String, row: Int, col: Int) {
        val index = row * cols + col
        if (index in cells.indices) cells[index] = text
    }

    // MARK: - 增刪

    /** 批次調整表格維度並保留相容格子內容 */
    fun resizeGrid(newRows: Int, newCols: Int) {
        val targetRows = maxOf(1, newRows)
        val targetCols = maxOf(1, newCols)
        if (targetRows == rows && targetCols == cols) return
        val newCells = ArrayList<String>(targetRows * targetCols)
        for (r in 0 until targetRows) {
            for (c in 0 until targetCols) {
                if (r < rows && c < cols) {
                    newCells.add(cell(r, c))
                } else {
                    newCells.add("")
                }
            }
        }
        rowHeightOverrides?.let { heights ->
            rowHeightOverrides = MutableList(targetRows) { heights.getOrElse(it) { 0.0 } }
        }
        rows = targetRows
        cols = targetCols
        cells = newCells
        mergedCells.removeAll {
            it.row + it.rowSpan > targetRows || it.col + it.colSpan > targetCols
        }
    }

    fun insertRow(at: Int) {
        val position = at.coerceIn(0, rows)
        cells.addAll(position * cols, List(cols) { "" })
        rowHeightOverrides?.let { heights ->
            // 新列沿用相鄰列的手動列高（與 Apple 相同）。插入 0（自動）會讓貼齊格線的表格
            // 從新列開始與紙上的線錯開。
            val at = minOf(position, heights.size)
            heights.add(at, heights.getOrElse(at) { heights.lastOrNull() ?: 0.0 })
        }
        rows += 1
        mergedCells.forEach { if (it.row >= position) it.row += 1 }
    }

    fun deleteRow(at: Int) {
        // 最後一列不能刪：沒有列的表格畫不出來，畫面上會忽然變空白。
        if (rows <= 1 || at !in 0 until rows) return
        repeat(cols) { cells.removeAt(at * cols) }
        rowHeightOverrides?.let { if (at in it.indices) it.removeAt(at) }
        rows -= 1
        mergedCells.removeAll { it.row == at }
        mergedCells.forEach { if (it.row > at) it.row -= 1 }
    }

    fun insertColumn(at: Int) {
        val position = at.coerceIn(0, cols)
        for (row in rows - 1 downTo 0) cells.add(row * cols + position, "")
        cols += 1
        mergedCells.forEach { if (it.col >= position) it.col += 1 }
    }

    fun deleteColumn(at: Int) {
        if (cols <= 1 || at !in 0 until cols) return
        for (row in rows - 1 downTo 0) cells.removeAt(row * cols + at)
        cols -= 1
        mergedCells.removeAll { it.col == at }
        mergedCells.forEach { if (it.col > at) it.col -= 1 }
    }

    // MARK: - 合併

    fun merge(row: Int, col: Int, rowSpan: Int, colSpan: Int) {
        if (rowSpan < 1 || colSpan < 1) return
        if (rowSpan == 1 && colSpan == 1) return
        // 伸出表格外的話，畫出來是一塊飛在旁邊的方塊。
        if (row + rowSpan > rows || col + colSpan > cols) return
        unmerge(row, col)
        mergedCells.add(NoteTableSpan(row, col, rowSpan, colSpan))
    }

    fun unmerge(row: Int, col: Int) {
        mergedCells.removeAll { it.row == row && it.col == col }
    }

    /** 這一格是不是被別的合併區蓋住了（蓋住的格子不顯示、也不能編輯）。 */
    fun isCovered(row: Int, col: Int): Boolean = mergedCells.any { span ->
        !(span.row == row && span.col == col) &&
            row >= span.row && row < span.row + maxOf(1, span.rowSpan) &&
            col >= span.col && col < span.col + maxOf(1, span.colSpan)
    }

    // MARK: - 版面

    /**
     * 核心算出來的版面。
     *
     * 欄寬、列高、斷行都在那裡決定 —— 這一層自己再算一次的話，同一張表在
     * iPad 與 Android 上的高度會不一樣，而表格的高度會影響它底下的東西。
     */
    /**
     * 畫面上的版面：核心的結果再套上手動列高。
     *
     * 沒有列高覆寫時與核心**逐點相同**。有的話只移動列的邊界 —— 格子、格線的 y 跟著
     * 邊界重映射（與 Apple `TableLayoutResolver` 同一套做法），合併區上不會多出格線。
     */
    fun layout(): FfiTableLayout {
        val core = coreLayout()
        val overrides = rowHeightOverrides ?: return core
        if (overrides.none { it >= MIN_ROW_OVERRIDE } || core.rowHeights.size != rows) return core
        val newHeights = core.rowHeights.mapIndexed { r, h ->
            overrides.getOrNull(r)?.takeIf { it >= MIN_ROW_OVERRIDE } ?: h
        }
        val oldEdges = cumulative(core.rowHeights)
        val newEdges = cumulative(newHeights)
        fun remap(y: Double): Double {
            oldEdges.indexOfFirst { kotlin.math.abs(it - y) < 0.5 }.takeIf { it >= 0 }?.let { return newEdges[it] }
            val upper = oldEdges.indexOfFirst { it > y }
            if (upper <= 0) return if (y >= oldEdges.last()) newEdges.last() else y
            val span = oldEdges[upper] - oldEdges[upper - 1]
            val t = if (span > 0) (y - oldEdges[upper - 1]) / span else 0.0
            return newEdges[upper - 1] + t * (newEdges[upper] - newEdges[upper - 1])
        }
        return core.copy(
            height = newEdges.last(),
            rowHeights = newHeights,
            cells = core.cells.map { cell ->
                val r = cell.row.toInt()
                val r2 = minOf(rows, r + maxOf(1, cell.rowSpan.toInt()))
                cell.copy(y = newEdges[r], height = newEdges[r2] - newEdges[r])
            },
            rules = core.rules.map { it.copy(y1 = remap(it.y1), y2 = remap(it.y2)) }
        )
    }

    /**
     * 新插入的表格貼齊這一頁的橫格線：頂邊落在最近的線上，每一列高度取格線間距的整數倍，
     * 表格的每一條橫線都與紙上的線重合。與 Apple `fitTableToPageRules` 同一條規則。
     * 沒有規則格線的紙張（空白、點陣）原樣不動。
     */
    fun fitToRules(rules: List<Float>) {
        val step = com.kairumo.padnote.text.RuledWriting.step(rules) ?: return
        rules.minByOrNull { kotlin.math.abs(it - y) }?.let { y = it }
        val s = step.toDouble()
        rowHeightOverrides = layout().rowHeights.map {
            maxOf(1.0, kotlin.math.ceil(it / s - 0.01)) * s
        }.toMutableList()
    }

    private fun coreLayout(): FfiTableLayout = tableLayout(
        FfiTable(
            blockId = id,
            rows = rows.toUInt(),
            cols = cols.toUInt(),
            cells = cells.toList(),
            headerRow = headerRow,
            mergedCells = mergedCells.map {
                listOf(it.row.toUInt(), it.col.toUInt(), it.rowSpan.toUInt(), it.colSpan.toUInt())
            }
        ),
        width.toDouble(),
        fontSize.toDouble()
    )

    val height: Float get() = layout().height.toFloat()

    fun copyTable(): NoteTable = decode(encodedJson()) ?: NoteTable()

    // MARK: - JSON（與 Apple 同一組鍵）

    fun encodedJson(): String = JSONObject().apply {
        put("id", id)
        put("x", x.toDouble())
        put("y", y.toDouble())
        put("width", width.toDouble())
        put("rows", rows)
        put("cols", cols)
        put("cells", JSONArray().also { array -> cells.forEach { array.put(it) } })
        put("headerRow", headerRow)
        put("fontSize", fontSize.toDouble())
        put("mergedCells", JSONArray().also { array ->
            mergedCells.forEach {
                array.put(JSONObject().apply {
                    put("row", it.row); put("col", it.col)
                    put("rowSpan", it.rowSpan); put("colSpan", it.colSpan)
                })
            }
        })
        // null 的欄位不寫進去 —— 接收端才分得出「沒設定」與「設成透明」。
        rotationDegrees?.let { put("rotationDegrees", it.toDouble()) }
        ruleColorHex?.let { put("ruleColorHex", it) }
        headerBackgroundHex?.let { put("headerBackgroundHex", it) }
        rowHeightOverrides?.let { heights ->
            put("rowHeights", JSONArray().also { array -> heights.forEach { array.put(it) } })
        }
    }.toString()

    companion object {
        /** 小於這個值的手動列高視為自動（與 Apple `TableLayoutResolver` 相同）。 */
        const val MIN_ROW_OVERRIDE = 16.0

        private fun cumulative(values: List<Double>): List<Double> {
            val out = ArrayList<Double>(values.size + 1)
            out.add(0.0)
            for (v in values) out.add(out.last() + v)
            return out
        }

        fun decode(json: String): NoteTable? {
            val obj = runCatching { JSONObject(json) }.getOrNull() ?: return null
            val cellArray = obj.optJSONArray("cells")
            val mergedArray = obj.optJSONArray("mergedCells")
            return NoteTable(
                id = obj.optString("id", java.util.UUID.randomUUID().toString()),
                x = obj.optDouble("x", 60.0).toFloat(),
                y = obj.optDouble("y", 120.0).toFloat(),
                width = obj.optDouble("width", 440.0).toFloat(),
                rows = obj.optInt("rows", 1),
                cols = obj.optInt("cols", 1),
                cells = MutableList(cellArray?.length() ?: 0) { cellArray!!.optString(it, "") },
                headerRow = obj.optBoolean("headerRow", true),
                mergedCells = MutableList(mergedArray?.length() ?: 0) {
                    val span = mergedArray!!.getJSONObject(it)
                    NoteTableSpan(
                        span.optInt("row"), span.optInt("col"),
                        span.optInt("rowSpan", 1), span.optInt("colSpan", 1)
                    )
                },
                fontSize = obj.optDouble("fontSize", 14.0).toFloat(),
                rotationDegrees = if (obj.has("rotationDegrees"))
                    obj.optDouble("rotationDegrees").toFloat() else null,
                ruleColorHex = if (obj.has("ruleColorHex")) obj.optString("ruleColorHex") else null,
                headerBackgroundHex =
                    if (obj.has("headerBackgroundHex")) obj.optString("headerBackgroundHex") else null,
                // `rowHeights` 是外觀裡的鍵（兩端共用）；`rowHeightOverrides` 是 Apple 套件檔的欄位名，一併認得。
                rowHeightOverrides = (obj.optJSONArray("rowHeights") ?: obj.optJSONArray("rowHeightOverrides"))
                    ?.let { array -> MutableList(array.length()) { array.optDouble(it, 0.0) } }
            )
        }
    }
}

/**
 * 表格在區塊外觀裡的包裝。
 *
 * 與圖表同一個約定：`object` 是判別欄位，沒有它讀的人只能靠猜 JSON 的形狀。
 */
object TableAppearance {
    private const val OBJECT_KEY = "object"
    private const val OBJECT_VALUE = "table"
    private const val TABLE_KEY = "table"

    fun encode(table: NoteTable): String = JSONObject().apply {
        put(OBJECT_KEY, OBJECT_VALUE)
        put(TABLE_KEY, JSONObject(table.encodedJson()))
    }.toString()

    fun decode(json: String): NoteTable? {
        val obj = runCatching { JSONObject(json) }.getOrNull() ?: return null
        if (obj.optString(OBJECT_KEY) != OBJECT_VALUE) return null
        val table = obj.optJSONObject(TABLE_KEY) ?: return null
        return NoteTable.decode(table.toString())
    }
}
