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
    var headerBackgroundHex: String? = null
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

    fun insertRow(at: Int) {
        val position = at.coerceIn(0, rows)
        cells.addAll(position * cols, List(cols) { "" })
        rows += 1
        mergedCells.forEach { if (it.row >= position) it.row += 1 }
    }

    fun deleteRow(at: Int) {
        // 最後一列不能刪：沒有列的表格畫不出來，畫面上會忽然變空白。
        if (rows <= 1 || at !in 0 until rows) return
        repeat(cols) { cells.removeAt(at * cols) }
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
    fun layout(): FfiTableLayout = tableLayout(
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
    }.toString()

    companion object {
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
                    if (obj.has("headerBackgroundHex")) obj.optString("headerBackgroundHex") else null
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
