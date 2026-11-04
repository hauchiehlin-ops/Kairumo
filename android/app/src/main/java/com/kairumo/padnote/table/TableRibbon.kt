package com.kairumo.padnote.table

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Checkbox
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.VerticalDivider
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.LocalizationStrings
import com.kairumo.padnote.ui.InstantTooltip

/**
 * 畫布上最後點進的儲存格（功能區、表格內容都以它為準）。與 Apple `TableCellFocus` 同一個角色。
 *
 * 只是畫面焦點，不寫進檔案、不跨設定檔沿用。
 */
// profile-scope: device 只是目前畫面上的儲存格焦點，切換設定檔時行程重啟即清空
object TableCellFocus {
    var tableId by mutableStateOf<String?>(null)
        private set
    var cell by mutableStateOf<Pair<Int, Int>?>(null)
        private set

    fun focus(tableId: String, row: Int, col: Int) {
        this.tableId = tableId
        cell = row to col
    }

    fun clear() {
        tableId = null
        cell = null
    }

    /** 這張表上的焦點格（夾在目前的列欄範圍內）；焦點不在這張表上回 null。 */
    fun cell(table: NoteTable): Pair<Int, Int>? {
        if (tableId != table.id) return null
        val (r, c) = cell ?: return null
        return r.coerceIn(0, table.rows - 1) to c.coerceIn(0, table.cols - 1)
    }
}

/** 表格樣式庫：表頭底色、表頭文字色、內容列隔列網底（與 Apple `styleGalleryBtn` 同一組值）。 */
internal data class TableGalleryStyle(val nameKey: String, val headerHex: String, val textHex: String?, val fillHex: String?)

internal val TABLE_GALLERY = listOf(
    TableGalleryStyle("table_style_simple", "#E9EEFC", null, null),
    TableGalleryStyle("table_style_business_blue", "#2B579A", "#FFFFFF", "#F2F7FF"),
    TableGalleryStyle("table_style_slate_gray", "#4A5568", "#FFFFFF", "#F7FAFC"),
    TableGalleryStyle("table_style_fresh_green", "#2E7D32", "#FFFFFF", "#F1F8E9"),
    TableGalleryStyle("table_style_warm_orange", "#E65100", "#FFFFFF", "#FFF8E1")
)

/** 網底／顏色色盤（與文字工具列相近的一組常用色）。 */
internal val TABLE_SWATCHES = listOf(
    "#FFFFFF", "#F2F2F2", "#D9D9D9", "#E9EEFC", "#DDEBF7", "#E2EFDA",
    "#FFF2CC", "#FCE4D6", "#F8CBAD", "#2B579A", "#2E7D32", "#C00000"
)

// MARK: - 功能區的動作（純模型，與 Apple `TableRibbonToolbar` 逐項對應；抽出來才測得到）

internal object TableRibbonActions {
    /** 上方插入列：沒有焦點時插在最上面；有焦點時插在它所在範圍的上方，焦點跟著原格往下移。 */
    fun insertRowAbove(t: NoteTable, cell: Pair<Int, Int>?): Pair<Int, Int>? {
        val range = cell?.let { t.cellRange(it.first, it.second) }
        t.insertRow(range?.first?.first ?: 0)
        return cell?.let { it.first + 1 to it.second }
    }

    fun insertRowBelow(t: NoteTable, cell: Pair<Int, Int>?) {
        val range = cell?.let { t.cellRange(it.first, it.second) }
        t.insertRow(range?.let { it.first.last + 1 } ?: t.rows)
    }

    fun insertColumnLeft(t: NoteTable, cell: Pair<Int, Int>?): Pair<Int, Int>? {
        val range = cell?.let { t.cellRange(it.first, it.second) }
        t.insertColumn(range?.second?.first ?: 0)
        return cell?.let { it.first to it.second + 1 }
    }

    fun insertColumnRight(t: NoteTable, cell: Pair<Int, Int>?) {
        val range = cell?.let { t.cellRange(it.first, it.second) }
        t.insertColumn(range?.let { it.second.last + 1 } ?: t.cols)
    }

    /** 刪焦點列（沒有焦點刪最後一列）。 */
    fun deleteRow(t: NoteTable, cell: Pair<Int, Int>?) = t.deleteRow(cell?.first ?: (t.rows - 1))

    fun deleteColumn(t: NoteTable, cell: Pair<Int, Int>?) = t.deleteColumn(cell?.second ?: (t.cols - 1))

    /** 焦點所在範圍（合併區為整片）；沒有焦點時整張表。 */
    fun focusedRange(t: NoteTable, cell: Pair<Int, Int>?): Pair<IntRange, IntRange> =
        cell?.let { t.cellRange(it.first, it.second) } ?: ((0 until t.rows) to (0 until t.cols))

    /** 九宮格對齊（與 Apple 相同：靠左寫 null，垂直一律寫明）。 */
    fun align(t: NoteTable, cell: Pair<Int, Int>?, h: String, v: String) {
        val (rows, cols) = focusedRange(t, cell)
        t.updateStyle(rows, cols) { it.copy(hAlign = if (h == "left") null else h, vAlign = v) }
    }

    /** 網底：有焦點改那一格（合併區整片），沒有焦點改表頭底色。 */
    fun shade(t: NoteTable, cell: Pair<Int, Int>?, hex: String) {
        if (cell != null) {
            val (rows, cols) = focusedRange(t, cell)
            t.updateStyle(rows, cols) { it.copy(fillHex = hex) }
        } else {
            t.headerBackgroundHex = hex
        }
    }

    /** 樣式庫：表頭色＋表頭文字色＋內容列隔列網底，開表頭與帶狀列。 */
    fun applyGallery(t: NoteTable, style: TableGalleryStyle) {
        t.headerBackgroundHex = style.headerHex
        t.headerRow = true
        t.bandedRows = true
        t.updateStyle(0..0, 0 until t.cols) { it.copy(textColorHex = style.textHex) }
        for (r in 1 until t.rows) {
            t.updateStyle(r..r, 0 until t.cols) {
                it.copy(fillHex = if (style.fillHex != null && r % 2 == 1) style.fillHex else null)
            }
        }
    }
}

/**
 * 表格功能區（Android）：選取表格時出現，「表格版面配置／表格設計」兩個分頁。
 *
 * 控制項、在地化鍵與行為與 Apple `TableRibbonToolbar` 一一對應（I6）：
 * 增刪列欄、合併／分割以**目前儲存格**為準；九宮格與網底改目前儲存格（沒有焦點時整表／表頭）。
 * 每次動作產生一份新表格交給 [onChange]（存檔、縮圖、協作由呼叫端一次處理）。
 */
@Composable
fun TableRibbon(
    table: NoteTable,
    languageTag: String,
    onChange: (NoteTable) -> Unit,
    onDelete: () -> Unit,
    onProperties: () -> Unit,
    modifier: Modifier = Modifier
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)
    var designTab by remember { mutableStateOf(false) }
    val cell = TableCellFocus.cell(table)

    // **一定要讀「最新」的表格。** 子元件拿到的是 `::edit` 這個區域函式參照，它在每次重組之間
    // 比較起來是相等的，Compose 會沿用舊的群組內容 —— 舊閉包裡的 `table` 是好幾步之前的那一份，
    // 例如先設九宮格對齊、再按「向下合併」，合併就以沒有對齊的舊表為底，把剛設的對齊洗掉（模擬器實測）。
    val latestTable by rememberUpdatedState(table)
    val latestOnChange by rememberUpdatedState(onChange)
    fun edit(block: (NoteTable) -> Unit) {
        val base = latestTable
        val next = base.copyTable()
        block(next)
        if (next.encodedJson() != base.encodedJson()) latestOnChange(next)
    }

    Surface(
        modifier = modifier.testTag("table.ribbon"),
        shape = RoundedCornerShape(8.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.97f),
        shadowElevation = 3.dp
    ) {
        Column(Modifier.padding(vertical = 4.dp)) {
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                RibbonTab(l("table_layout"), !designTab, "table.ribbon.tab.layout") { designTab = false }
                RibbonTab(l("table_design"), designTab, "table.ribbon.tab.design") { designTab = true }
                if (cell != null) {
                    Text(
                        l("table_cell_position")
                            .replaceFirst("%1@", "${cell.first + 1}")
                            .replaceFirst("%2@", "${cell.second + 1}"),
                        fontSize = 10.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.testTag("table.ribbon.focus")
                    )
                }
                Spacer(Modifier.weight(1f))
                TextButton(onClick = onProperties, modifier = Modifier.testTag("table.ribbon.properties")) {
                    Text(l("table_properties"), fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                }
            }
            Row(
                Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                if (!designTab) LayoutControls(table, cell, ::l, ::edit, onDelete)
                else DesignControls(table, cell, ::l, ::edit)
            }
        }
    }
}

@Composable
private fun LayoutControls(
    table: NoteTable,
    cell: Pair<Int, Int>?,
    l: (String) -> String,
    edit: ((NoteTable) -> Unit) -> Unit,
    onDelete: () -> Unit
) {
    val range = cell?.let { table.cellRange(it.first, it.second) }
    val span = cell?.let { table.spanContaining(it.first, it.second) }
    val canMergeRight = range != null && range.second.last + 1 < table.cols
    val canMergeDown = range != null && range.first.last + 1 < table.rows

    RibbonGroup(l("table_tab_row") + " & " + l("table_tab_column")) {
        GlyphButton("⤒", l("table_insert_row_above"), "table.ribbon.insert_row_above") {
            edit { t -> TableRibbonActions.insertRowAbove(t, cell)?.let { TableCellFocus.focus(t.id, it.first, it.second) } }
        }
        GlyphButton("⤓", l("table_insert_row_below"), "table.ribbon.insert_row_below") {
            edit { t -> TableRibbonActions.insertRowBelow(t, cell) }
        }
        GlyphButton("⇤", l("table_insert_col_left"), "table.ribbon.insert_col_left") {
            edit { t -> TableRibbonActions.insertColumnLeft(t, cell)?.let { TableCellFocus.focus(t.id, it.first, it.second) } }
        }
        GlyphButton("⇥", l("table_insert_col_right"), "table.ribbon.insert_col_right") {
            edit { t -> TableRibbonActions.insertColumnRight(t, cell) }
        }
        GlyphButton("⊟", l("table_delete_row"), "table.ribbon.delete_row", enabled = table.rows > 1, destructive = true) {
            edit { t -> TableRibbonActions.deleteRow(t, cell) }
        }
        GlyphButton("◫", l("table_delete_column"), "table.ribbon.delete_column", enabled = table.cols > 1, destructive = true) {
            edit { t -> TableRibbonActions.deleteColumn(t, cell) }
        }
        GlyphButton("🗑", l("delete"), "table.ribbon.delete_table", destructive = true) { onDelete() }
    }
    RibbonDivider()
    RibbonGroup(l("table_merge_selection")) {
        GlyphButton("⇉", l("table_merge_right"), "table.ribbon.merge_right", enabled = canMergeRight) {
            edit { t -> cell?.let { t.mergeRight(it.first, it.second) } }
        }
        GlyphButton("⇊", l("table_merge_down"), "table.ribbon.merge_down", enabled = canMergeDown) {
            edit { t -> cell?.let { t.mergeDown(it.first, it.second) } }
        }
        GlyphButton("⊞", l("table_split_cell"), "table.ribbon.split", enabled = span != null) {
            edit { t -> cell?.let { t.splitCell(it.first, it.second) } }
        }
    }
    RibbonDivider()
    RibbonGroup(l("table_section_size")) {
        GlyphButton("☰", l("table_distribute_rows"), "table.ribbon.distribute_rows") { edit { it.distributeRows() } }
        GlyphButton("⫴", l("table_distribute_cols"), "table.ribbon.distribute_cols") { edit { it.distributeColumns() } }
        GlyphButton("⤢", l("table_autofit"), "table.ribbon.autofit") { edit { it.autoFitSizes() } }
    }
    RibbonDivider()
    RibbonGroup(l("table_section_align")) {
        val probe = cell?.let { table.style(it.first, it.second) }
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            for ((v, vKey) in listOf("top" to "top", "middle" to "middle", "bottom" to "bottom")) {
                Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                    for ((h, glyph) in nineGlyphs(v)) {
                        val key = "table_align_9_${vKey}_" + (if (h == "left") "left" else if (h == "center") "center" else "right")
                        val current = probe != null && (probe.hAlign ?: "left") == h && (probe.vAlign ?: "top") == v
                        Box(
                            Modifier
                                .size(width = 20.dp, height = 15.dp)
                                .background(
                                    if (current) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surface,
                                    RoundedCornerShape(2.dp)
                                )
                                .clickable { edit { t -> TableRibbonActions.align(t, cell, h, v) } }
                                .semantics { contentDescription = l(key) }
                                .testTag("table.ribbon.$key"),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(glyph, fontSize = 9.sp,
                                color = if (current) Color.White else MaterialTheme.colorScheme.onSurface)
                        }
                    }
                }
            }
        }
    }
}

private fun nineGlyphs(v: String): List<Pair<String, String>> = when (v) {
    "top" -> listOf("left" to "↖", "center" to "↑", "right" to "↗")
    "middle" -> listOf("left" to "←", "center" to "•", "right" to "→")
    else -> listOf("left" to "↙", "center" to "↓", "right" to "↘")
}

@Composable
private fun DesignControls(
    table: NoteTable,
    cell: Pair<Int, Int>?,
    l: (String) -> String,
    edit: ((NoteTable) -> Unit) -> Unit
) {
    RibbonGroup(l("table_design")) {
        ToggleTag(l("table_header_row"), table.headerRow, "table.ribbon.header_row") { on -> edit { it.headerRow = on } }
        ToggleTag(l("table_banded_rows"), table.bandedRows == true, "table.ribbon.banded_rows") { on ->
            edit { it.bandedRows = if (on) true else null }
        }
        ToggleTag(l("table_banded_cols"), table.bandedCols == true, "table.ribbon.banded_cols") { on ->
            edit { it.bandedCols = if (on) true else null }
        }
    }
    RibbonDivider()
    RibbonGroup(l("table_styles_gallery")) {
        for (style in TABLE_GALLERY) {
            val name = l(style.nameKey)
            InstantTooltip(text = name) {
                Column(
                    Modifier
                        .border(0.5.dp, Color.Gray.copy(alpha = 0.5f), RoundedCornerShape(4.dp))
                        .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(4.dp))
                        .clickable { edit { TableRibbonActions.applyGallery(it, style) } }
                        .padding(2.dp)
                        .semantics { contentDescription = name }
                        .testTag("table.ribbon.style.${style.nameKey}"),
                    verticalArrangement = Arrangement.spacedBy(1.dp)
                ) {
                    Box(Modifier.size(32.dp, 10.dp).background(hexColor(style.headerHex) ?: Color.Blue, RoundedCornerShape(2.dp)))
                    Box(Modifier.size(32.dp, 12.dp).background(
                        style.fillHex?.let(::hexColor) ?: Color.Gray.copy(alpha = 0.1f), RoundedCornerShape(2.dp)))
                }
            }
        }
    }
    RibbonDivider()
    RibbonGroup(l("table_shading") + " & " + l("table_borders")) {
        var shadingOpen by remember { mutableStateOf(false) }
        var bordersOpen by remember { mutableStateOf(false) }
        val currentShade = if (cell != null) table.style(cell.first, cell.second).fillHex
            else table.headerBackgroundHex ?: "#E9EEFC"
        Box {
            InstantTooltip(text = l("table_shading")) {
                Box(
                    Modifier
                        .size(26.dp)
                        .background(currentShade?.takeIf { it != "clear" }?.let(::hexColor) ?: Color.Transparent, RoundedCornerShape(4.dp))
                        .border(1.dp, Color.Gray.copy(alpha = 0.6f), RoundedCornerShape(4.dp))
                        .clickable { shadingOpen = true }
                        .semantics { contentDescription = l("table_shading") }
                        .testTag("table.ribbon.shading")
                )
            }
            DropdownMenu(expanded = shadingOpen, onDismissRequest = { shadingOpen = false }) {
                SwatchGrid(currentShade) { hex ->
                    shadingOpen = false
                    edit { TableRibbonActions.shade(it, cell, hex) }
                }
            }
        }
        Box {
            InstantTooltip(text = l("table_borders")) {
                TextButton(
                    onClick = { bordersOpen = true },
                    modifier = Modifier.testTag("table.ribbon.borders").semantics { contentDescription = l("table_borders") }
                ) { Text("▦ ▾", fontSize = 13.sp) }
            }
            DropdownMenu(expanded = bordersOpen, onDismissRequest = { bordersOpen = false }) {
                for ((mode, key) in listOf(null to "table_border_all", "outer" to "table_border_outer",
                    "inner" to "table_border_inner", "horizontal" to "table_border_horizontal", "none" to "table_border_none")) {
                    DropdownMenuItem(
                        text = { Text(l(key)) },
                        onClick = { bordersOpen = false; edit { it.borderMode = mode } },
                        modifier = Modifier.testTag("table.ribbon.$key")
                    )
                }
            }
        }
    }
}

// MARK: - 小元件

@Composable
private fun RibbonTab(title: String, selected: Boolean, tag: String, onClick: () -> Unit) {
    Text(
        title,
        fontSize = 12.sp,
        fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
        color = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier
            .background(if (selected) MaterialTheme.colorScheme.surface else Color.Transparent, RoundedCornerShape(6.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 5.dp)
            .testTag(tag)
    )
}

@Composable
private fun RibbonGroup(label: String, content: @Composable () -> Unit) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) { content() }
        Text(label, fontSize = 9.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
    }
}

@Composable
private fun RibbonDivider() {
    VerticalDivider(Modifier.height(32.dp))
}

@Composable
private fun GlyphButton(
    glyph: String,
    label: String,
    tag: String,
    enabled: Boolean = true,
    destructive: Boolean = false,
    onClick: () -> Unit
) {
    val tint = when {
        !enabled -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f)
        destructive -> MaterialTheme.colorScheme.error
        else -> MaterialTheme.colorScheme.onSurface
    }
    InstantTooltip(text = label) {
        Box(
            Modifier
                .size(30.dp)
                .background(MaterialTheme.colorScheme.surface.copy(alpha = if (enabled) 1f else 0.5f), RoundedCornerShape(5.dp))
                .clickable(enabled = enabled, onClick = onClick)
                .semantics { contentDescription = label }
                .testTag(tag),
            contentAlignment = Alignment.Center
        ) { Text(glyph, fontSize = 15.sp, color = tint) }
    }
}

@Composable
private fun ToggleTag(label: String, on: Boolean, tag: String, onToggle: (Boolean) -> Unit) {
    Row(
        Modifier.clickable { onToggle(!on) }.testTag(tag),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Checkbox(checked = on, onCheckedChange = onToggle, modifier = Modifier.size(28.dp))
        Text(label, fontSize = 11.sp)
    }
}

/** 色盤（網底、框線色、表頭底色共用）。 */
@Composable
internal fun SwatchGrid(currentHex: String?, onPick: (String) -> Unit) {
    Column(Modifier.padding(8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        for (rowColors in TABLE_SWATCHES.chunked(6)) {
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                for (hex in rowColors) {
                    val selected = hex.equals(currentHex, ignoreCase = true)
                    Box(
                        Modifier
                            .size(24.dp)
                            .background(hexColor(hex) ?: Color.Transparent, RoundedCornerShape(3.dp))
                            .border(if (selected) 2.dp else 0.5.dp,
                                if (selected) MaterialTheme.colorScheme.primary else Color.Gray.copy(alpha = 0.5f),
                                RoundedCornerShape(3.dp))
                            .clickable { onPick(hex) }
                            .semantics { contentDescription = hex }
                            .testTag("table.swatch.$hex")
                    )
                }
            }
        }
    }
    Spacer(Modifier.width(0.dp))
}

internal fun hexColor(hex: String): Color? = runCatching {
    Color(android.graphics.Color.parseColor(hex))
}.getOrNull()
