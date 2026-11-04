package com.kairumo.padnote.table

import org.json.JSONArray
import org.json.JSONObject
import uniffi.padnote_core.FfiTable
import uniffi.padnote_core.FfiTableCell
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
    var rowHeightOverrides: MutableList<Double>? = null,
    /**
     * 手動欄寬（點），逐欄一個。`0` 或小於 [MIN_COLUMN_WIDTH] 的項目為自動，`null` 為全部自動。
     * 外觀鍵 `columnWidths`（與 Apple `columnWidthOverrides` 同一個語意）。
     */
    var columnWidthOverrides: MutableList<Double>? = null,
    /**
     * 逐格格式，長度 = rows×cols（與 [cells] 同序）。`null` 為全部沿用預設。外觀鍵 `cellStyles`。
     */
    var cellStyles: MutableList<NoteTableCellStyle>? = null,
    /** 框線樣式原值（`all`/`outer`/`inner`/`horizontal`/`none`）。`null` 為 all。保留原值，未來新值不會被洗掉。 */
    var borderMode: String? = null,
    /** 框線粗細（點）。`null` 為 1。 */
    var borderWidth: Float? = null,
    /** 框線線型原值（`solid`/`dashed`/`dotted`）。`null` 為實線。 */
    var borderStyle: String? = null,
    /** 帶狀列（斑馬紋）。 */
    var bandedRows: Boolean? = null,
    /** 帶狀欄。 */
    var bandedCols: Boolean? = null,
    /**
     * Android 不認得、但 Apple 會寫的其他外觀鍵（`altTitle`、`alignment`、`indentLeft`…），
     * 原樣保留的 JSON 物件文字。
     *
     * 沒有它的話，Android 一改這張表（打一個字、拖一下），寫回去的外觀就只剩自己認得的鍵 ——
     * 使用者在 iPad 上設的替代文字等整批消失（I6）。
     */
    var appearanceExtras: String? = null
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

    // MARK: - 外觀（與 Apple `NoteTableAttachment` 同一組判斷）

    fun style(row: Int, col: Int): NoteTableCellStyle =
        cellStyles?.getOrNull(row * cols + col) ?: NoteTableCellStyle.DEFAULT

    val resolvedBorderMode: TableBorderMode get() = TableBorderMode.from(borderMode)

    val resolvedBorderStyle: TableBorderStyle get() = TableBorderStyle.from(borderStyle)

    /** 畫格線用的線寬（點）。與 Apple `resolvedBorderWidth` 相同。 */
    val resolvedBorderWidth: Float get() = maxOf(0.5f, borderWidth ?: 1f)

    /** 一格的底色來源：自己的底色 → 表頭 → 帶狀列 → 帶狀欄（與 Apple `fillRole` 相同）。 */
    fun fillRole(row: Int, col: Int, isHeader: Boolean): TableCellFillRole? {
        style(row, col).fillHex?.let { return TableCellFillRole.Own(it) }
        if (isHeader) return TableCellFillRole.Header
        if (bandedRows == true && row % 2 == 1) return TableCellFillRole.BandedRow
        if (bandedCols == true && col % 2 == 1) return TableCellFillRole.BandedColumn
        return null
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
        if (cellStyles != null) {
            cellStyles = MutableList(targetRows * targetCols) { i ->
                val r = i / targetCols
                val c = i % targetCols
                if (r < rows && c < cols) style(r, c) else NoteTableCellStyle.DEFAULT
            }
        }
        columnWidthOverrides?.let { widths ->
            columnWidthOverrides = MutableList(targetCols) { widths.getOrElse(it) { 0.0 } }
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
        cellStyles?.let { styles ->
            styles.addAll(minOf(position * cols, styles.size), List(cols) { NoteTableCellStyle.DEFAULT })
        }
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
        cellStyles?.let { styles -> repeat(cols) { if (at * cols < styles.size) styles.removeAt(at * cols) } }
        rowHeightOverrides?.let { if (at in it.indices) it.removeAt(at) }
        rows -= 1
        mergedCells.removeAll { it.row == at }
        mergedCells.forEach { if (it.row > at) it.row -= 1 }
    }

    fun insertColumn(at: Int) {
        val position = at.coerceIn(0, cols)
        for (row in rows - 1 downTo 0) {
            cells.add(row * cols + position, "")
            cellStyles?.let { styles ->
                val i = row * cols + position
                if (i <= styles.size) styles.add(i, NoteTableCellStyle.DEFAULT)
            }
        }
        columnWidthOverrides?.let { widths -> widths.add(minOf(position, widths.size), 0.0) }
        cols += 1
        mergedCells.forEach { if (it.col >= position) it.col += 1 }
    }

    fun deleteColumn(at: Int) {
        if (cols <= 1 || at !in 0 until cols) return
        for (row in rows - 1 downTo 0) {
            cells.removeAt(row * cols + at)
            cellStyles?.let { styles ->
                val i = row * cols + at
                if (i < styles.size) styles.removeAt(i)
            }
        }
        columnWidthOverrides?.let { widths -> if (at in widths.indices) widths.removeAt(at) }
        cols -= 1
        mergedCells.removeAll { it.col == at }
        mergedCells.forEach { if (it.col > at) it.col -= 1 }
    }

    /**
     * 畫布上拖右下角把手縮放：外框變成 `newWidth × newHeight`，**每一列、每一欄等比例**跟著縮放。
     * 與 Apple `NoteTableAttachment.scale(to:)` 同一條規則（含最小欄寬 24、最小列高 16）。
     */
    fun scaleTo(newWidth: Float, newHeight: Float) {
        val current = layout()
        if (current.width <= 0.0 || current.height <= 0.0 || newWidth <= 0f || newHeight <= 0f) return
        val targetW = maxOf(cols * MIN_COLUMN_WIDTH, newWidth.toDouble())
        val targetH = maxOf(rows * MIN_ROW_OVERRIDE, newHeight.toDouble())
        val sx = targetW / current.width
        val sy = targetH / current.height
        width = (width * sx).toFloat()
        rowHeightOverrides = current.rowHeights.map { maxOf(MIN_ROW_OVERRIDE, it * sy) }.toMutableList()
        // 手動欄寬也一起等比例縮放：不縮的話欄寬以覆寫為準，表格又變回原寬。
        columnWidthOverrides = columnWidthOverrides?.map { w ->
            if (w > 0) maxOf(MIN_COLUMN_WIDTH, w * sx) else 0.0
        }?.toMutableList()
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

    /** 含有 (row, col) 的合併區（沒有就是 null）。與 Apple `span(containing:col:)` 相同。 */
    fun spanContaining(row: Int, col: Int): NoteTableSpan? = mergedCells.firstOrNull { span ->
        row >= span.row && row < span.row + maxOf(1, span.rowSpan) &&
            col >= span.col && col < span.col + maxOf(1, span.colSpan)
    }

    /** (row, col) 所在的格子（或合併區）向右多併一欄。與 Apple `mergeRight` 相同。 */
    fun mergeRight(row: Int, col: Int) {
        val s = spanContaining(row, col) ?: NoteTableSpan(row, col, 1, 1)
        if (s.col + s.colSpan >= cols) return
        mergeRect(s.row, s.col, s.rowSpan, s.colSpan + 1)
    }

    /** (row, col) 所在的格子（或合併區）向下多併一列。與 Apple `mergeDown` 相同。 */
    fun mergeDown(row: Int, col: Int) {
        val s = spanContaining(row, col) ?: NoteTableSpan(row, col, 1, 1)
        if (s.row + s.rowSpan >= rows) return
        mergeRect(s.row, s.col, s.rowSpan + 1, s.colSpan)
    }

    /** 合併一個矩形：範圍內原有的合併區先拆掉，兩個合併區才不會互相重疊（與 Apple `mergeRange` 相同）。 */
    private fun mergeRect(row: Int, col: Int, rowSpan: Int, colSpan: Int) {
        if (row + rowSpan > rows || col + colSpan > cols) return
        mergedCells.removeAll { span ->
            span.row < row + rowSpan && span.row + maxOf(1, span.rowSpan) > row &&
                span.col < col + colSpan && span.col + maxOf(1, span.colSpan) > col
        }
        merge(row, col, rowSpan, colSpan)
    }

    /** 分割 (row, col) 所在的合併區（從被蓋住的格子也拆得掉）。 */
    fun splitCell(row: Int, col: Int) {
        spanContaining(row, col)?.let { unmerge(it.row, it.col) }
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
     * 畫面上的版面：核心的結果再套上手動欄寬、手動列高、逐格格式與框線樣式。
     * 演算法與 Apple `TableLayoutResolver.resolvedLayout()` 逐步對應，見 [resolveLayout]。
     *
     * 沒有任何覆寫、格式與框線設定時與核心**逐點相同**（舊檔不變）。
     * 畫布、側欄縮圖與匯出都從這裡取版面（I4）。
     */
    fun layout(): FfiTableLayout {
        val key = layoutKey()
        cachedLayout?.let { (k, v) -> if (k == key) return v }
        val resolved = resolveLayout(coreLayout(), ::coreMeasure)
        cachedLayout = key to resolved
        return resolved
    }

    /** 版面只取決於這些欄位；一樣的話重用上一次的結果（版面在每次重組、每次拖曳都會被讀）。 */
    private fun layoutKey(): List<Any?> = listOf(
        rows, cols, cells.toList(), headerRow, mergedCells.map { it.copy() }, fontSize, width,
        rowHeightOverrides?.toList(), columnWidthOverrides?.toList(), cellStyles?.toList(), borderMode
    )

    @Transient private var cachedLayout: Pair<List<Any?>, FfiTableLayout>? = null

    /** 一段文字在指定寬度與字級下的斷行與所需高度（含內距）。 */
    fun interface CellMeasurer {
        fun measure(text: String, width: Double, fontSize: Double): Pair<List<String>, Double>
    }

    /** 用核心同一套斷行估算量一格：與核心算整張表時的規則相同，兩端一致。 */
    private fun coreMeasure(text: String, width: Double, fontSize: Double): Pair<List<String>, Double> {
        val l = tableLayout(
            FfiTable(blockId = "$id-measure", rows = 1u, cols = 1u, cells = listOf(text),
                headerRow = false, mergedCells = emptyList()),
            width, fontSize
        )
        return (l.cells.firstOrNull()?.lines ?: emptyList()) to l.height
    }

    /**
     * 核心版面 + 使用者覆寫 = 畫面版面（與 Apple `resolvedLayout()` 同一套步驟）：
     *
     * 1. 欄寬：`columnWidths` 中 ≥ [MIN_COLUMN_WIDTH] 的項目覆寫核心欄寬。
     * 2. 列高：有欄寬覆寫時自動列高全部改用實測（不低於核心最矮列）；否則有影響量測的格式才讓列長高。
     *    最後再套手動列高（≥ [MIN_ROW_OVERRIDE]）。
     * 3. 格線：依 `borderMode` 在核心座標上過濾（外框／內線／只留橫線／全無），再重映射到新邊界 ——
     *    合併區上不會多出格線。
     * 4. 格子：位置照新邊界；重新量過的格子換上新的斷行。
     *
     * 純函式（量測可注入），JVM 單元測試不必載入核心。
     */
    internal fun resolveLayout(core: FfiTableLayout, measure: CellMeasurer): FfiTableLayout {
        val colW = (if (core.columnWidths.size == cols) core.columnWidths
            else List(cols) { width.toDouble() / cols }).toMutableList()
        val rowH = (if (core.rowHeights.size == rows) core.rowHeights
            else List(rows) { core.height / rows }).toMutableList()
        val oldColEdges = cumulative(colW)
        val oldRowEdges = cumulative(rowH)

        val colOverrides = columnWidthOverrides ?: emptyList<Double>()
        val rowOverrides = rowHeightOverrides ?: emptyList<Double>()
        val hasColOverride = colOverrides.any { it > 0 }

        for (c in 0 until cols) {
            colOverrides.getOrNull(c)?.takeIf { it >= MIN_COLUMN_WIDTH }?.let { colW[c] = it }
        }
        fun spanWidth(cell: FfiTableCell): Double {
            val start = cell.col.toInt().coerceIn(0, cols - 1)
            val end = minOf(cols, start + maxOf(1, cell.colSpan.toInt()))
            return (start until end).sumOf { colW[it] }
        }

        // 要重新量的格子：欄寬變了（核心的斷行不準了）或格式會影響大小。
        val remeasured = HashMap<FfiTableCell, List<String>>()
        val floorHeight = rowH.minOrNull() ?: 30.0
        val measured = DoubleArray(rows)
        for (cell in core.cells) {
            val r = cell.row.toInt()
            val c = cell.col.toInt()
            if (r !in 0 until rows || c !in 0 until cols) continue
            val style = style(r, c)
            if (!style.affectsMeasure && !hasColOverride) continue
            val w = if (style.wrap == false) UNWRAPPED_WIDTH else spanWidth(cell)
            val (lines, need) = measure.measure(cell(r, c), w, style.fontSize ?: fontSize.toDouble())
            remeasured[cell] = lines
            if (maxOf(1, cell.rowSpan.toInt()) == 1) measured[r] = maxOf(measured[r], need)
        }
        for (r in 0 until rows) {
            if (hasColOverride) {
                rowH[r] = maxOf(floorHeight, measured[r])
            } else if (measured[r] > 0) {
                rowH[r] = maxOf(rowH[r], measured[r])
            }
            rowOverrides.getOrNull(r)?.takeIf { it >= MIN_ROW_OVERRIDE }?.let { rowH[r] = it }
        }

        val newColEdges = cumulative(colW)
        val newRowEdges = cumulative(rowH)

        fun remap(value: Double, old: List<Double>, new: List<Double>): Double {
            old.indexOfFirst { kotlin.math.abs(it - value) < 0.5 }.takeIf { it >= 0 }?.let { return new[it] }
            val upper = old.indexOfFirst { it > value }
            if (upper <= 0) return if (value >= old.last()) new.last() else value
            val span = old[upper] - old[upper - 1]
            val t = if (span > 0) (value - old[upper - 1]) / span else 0.0
            return new[upper - 1] + t * (new[upper] - new[upper - 1])
        }
        fun isOuterEdge(value: Double, edges: List<Double>): Boolean {
            val i = edges.indexOfFirst { kotlin.math.abs(it - value) < 0.5 }
            return i == 0 || i == edges.size - 1
        }

        val mode = resolvedBorderMode
        val rules = if (mode == TableBorderMode.NONE) emptyList() else core.rules.filter { rule ->
            val horizontal = kotlin.math.abs(rule.y1 - rule.y2) < 0.5
            when (mode) {
                TableBorderMode.HORIZONTAL -> horizontal
                TableBorderMode.OUTER, TableBorderMode.INNER -> {
                    val outer = if (horizontal) isOuterEdge(rule.y1, oldRowEdges) else isOuterEdge(rule.x1, oldColEdges)
                    (mode == TableBorderMode.OUTER) == outer
                }
                else -> true
            }
        }.map {
            it.copy(
                x1 = remap(it.x1, oldColEdges, newColEdges), y1 = remap(it.y1, oldRowEdges, newRowEdges),
                x2 = remap(it.x2, oldColEdges, newColEdges), y2 = remap(it.y2, oldRowEdges, newRowEdges)
            )
        }

        val cellsOut = core.cells.map { cell ->
            val r = cell.row.toInt().coerceIn(0, rows - 1)
            val c = cell.col.toInt().coerceIn(0, cols - 1)
            val r2 = minOf(rows, r + maxOf(1, cell.rowSpan.toInt()))
            val c2 = minOf(cols, c + maxOf(1, cell.colSpan.toInt()))
            cell.copy(
                x = newColEdges[c], y = newRowEdges[r],
                width = newColEdges[c2] - newColEdges[c],
                height = newRowEdges[r2] - newRowEdges[r],
                lines = remeasured[cell] ?: cell.lines
            )
        }

        return core.copy(
            width = newColEdges.last(),
            height = newRowEdges.last(),
            columnWidths = colW,
            rowHeights = rowH,
            cells = cellsOut,
            rules = rules
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
        // 先放 Apple 寫的、Android 不認得的鍵，再用自己的欄位覆蓋（見 appearanceExtras）。
        appearanceExtras?.let { runCatching { JSONObject(it) }.getOrNull() }?.let { extras ->
            extras.keys().forEach { key -> put(key, extras.get(key)) }
        }
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
        columnWidthOverrides?.let { widths ->
            put("columnWidths", JSONArray().also { array -> widths.forEach { array.put(it) } })
        }
        cellStyles?.let { put("cellStyles", NoteTableCellStyle.listToJson(it)) }
        borderMode?.let { put("borderMode", it) }
        borderWidth?.let { put("borderWidth", it.toDouble()) }
        borderStyle?.let { put("borderStyle", it) }
        bandedRows?.let { put("bandedRows", it) }
        bandedCols?.let { put("bandedCols", it) }
    }.toString()

    companion object {
        /** 小於這個值的手動列高視為自動（與 Apple `TableLayoutResolver` 相同）。 */
        const val MIN_ROW_OVERRIDE = 16.0

        /** 縮放時的最小欄寬（與 Apple `NoteTableAttachment.minimumColumnWidth` 相同）。 */
        const val MIN_COLUMN_WIDTH = 24.0

        /** 這一端自己讀寫的鍵；其餘鍵原樣保留在 [appearanceExtras]。 */
        private val KNOWN_KEYS = setOf(
            "id", "x", "y", "width", "rows", "cols", "cells", "headerRow", "mergedCells",
            "fontSize", "rotationDegrees", "ruleColorHex", "headerBackgroundHex",
            "rowHeights", "rowHeightOverrides",
            "columnWidths", "cellStyles", "borderMode", "borderWidth", "borderStyle",
            "bandedRows", "bandedCols"
        )

        /** `wrap == false` 的格子量測時用的寬度：夠寬，核心就不會斷行。 */
        private const val UNWRAPPED_WIDTH = 1_000_000.0

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
                    ?.let { array -> MutableList(array.length()) { array.optDouble(it, 0.0) } },
                columnWidthOverrides = obj.optJSONArray("columnWidths")
                    ?.let { array -> MutableList(array.length()) { array.optDouble(it, 0.0) } },
                cellStyles = NoteTableCellStyle.listFromJson(
                    obj.optJSONArray("cellStyles"),
                    maxOf(1, obj.optInt("rows", 1)) * maxOf(1, obj.optInt("cols", 1))
                ),
                borderMode = if (obj.has("borderMode")) obj.optString("borderMode") else null,
                borderWidth = if (obj.has("borderWidth")) obj.optDouble("borderWidth").toFloat() else null,
                borderStyle = if (obj.has("borderStyle")) obj.optString("borderStyle") else null,
                bandedRows = if (obj.has("bandedRows")) obj.optBoolean("bandedRows") else null,
                bandedCols = if (obj.has("bandedCols")) obj.optBoolean("bandedCols") else null,
                appearanceExtras = JSONObject().also { extras ->
                    obj.keys().forEach { key -> if (key !in KNOWN_KEYS) extras.put(key, obj.get(key)) }
                }.takeIf { it.length() > 0 }?.toString()
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
