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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.ScrollableTabRow
import androidx.compose.material3.Switch
import androidx.compose.material3.Tab
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.LocalizationStrings
import kotlin.math.roundToInt

/** 1 公分 ≈ 28.3465 點（與 Apple `TablePropertiesSheet.ptPerCm` 相同）。 */
private const val PT_PER_CM = 28.3465f

/**
 * 「表格內容」（Android），對照 Apple `TablePropertiesSheet`：
 * 表格、列、欄、儲存格、替代文字五個分頁，加上「框線及網底…」「選項…」兩個子面板。
 *
 * 所有修改先改 [working]，按「確認」才交給 [onCommit]；「取消」整批放棄（含子面板）。
 * 表格標籤「表格 (%1@ × %2@)」一定要代入列數與欄數（見 [tableTabLabel]）。
 */
@Composable
fun TablePropertiesDialog(
    table: NoteTable,
    languageTag: String,
    onCommit: (NoteTable) -> Unit,
    onDismiss: () -> Unit
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)
    var working by remember(table.id) { mutableStateOf(table.copyTable()) }
    var tab by remember { mutableIntStateOf(0) }
    // 從畫布上最後點進去的那一格開始（列、欄、儲存格分頁、框線及網底都以它為準）。
    val seed = TableCellFocus.cell(table)
    var activeRow by remember(table.id) { mutableIntStateOf(seed?.first ?: 0) }
    var activeCol by remember(table.id) { mutableIntStateOf(seed?.second ?: 0) }
    var useCm by remember { mutableStateOf(true) }
    var showBorders by remember { mutableStateOf(false) }
    var showOptions by remember { mutableStateOf(false) }

    fun mutate(block: (NoteTable) -> Unit) {
        working = working.copyTable().also(block)
        activeRow = activeRow.coerceIn(0, working.rows - 1)
        activeCol = activeCol.coerceIn(0, working.cols - 1)
    }
    fun toDisplay(pt: Float) = if (useCm) pt / PT_PER_CM else pt
    fun fromDisplay(v: Float) = if (useCm) v * PT_PER_CM else v
    val unitLabel = l(if (useCm) "table_unit_cm" else "table_unit_pt")

    AlertDialog(
        onDismissRequest = onDismiss,
        modifier = Modifier.testTag("table.props"),
        title = { Text(l("table_properties")) },
        confirmButton = {
            TextButton(onClick = { onCommit(working) }, modifier = Modifier.testTag("table.props.confirm")) {
                Text(l("confirm"))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss, modifier = Modifier.testTag("table.props.cancel")) { Text(l("cancel")) }
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                ScrollableTabRow(selectedTabIndex = tab, edgePadding = 0.dp, modifier = Modifier.testTag("table.props.tabs")) {
                    listOf(
                        tableTabLabel(l("word_table_label"), working.rows, working.cols),
                        l("table_tab_row"), l("table_tab_column"), l("table_tab_cell"), l("table_tab_alt_text")
                    ).forEachIndexed { i, title ->
                        Tab(selected = tab == i, onClick = { tab = i }, text = { Text(title, fontSize = 12.sp) })
                    }
                }
                Column(
                    Modifier.heightIn(max = 420.dp).verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    when (tab) {
                        0 -> {
                            SectionTitle(l("table_section_size"))
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text(l("table_preferred_width"), Modifier.weight(1f))
                                NumberField(toDisplay(working.layout().width.toFloat()), "table.props.width") { v ->
                                    mutate { it.setPreferredWidth(fromDisplay(v)) }
                                }
                                UnitToggle(useCm, l("table_unit_cm"), l("table_unit_pt")) { useCm = it }
                            }
                            SectionTitle(l("table_section_align"))
                            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                for ((value, key) in listOf("left" to "table_align_left", "center" to "table_align_center", "right" to "table_align_right")) {
                                    val selected = (working.alignment ?: "left") == value
                                    FilterChip(
                                        selected = selected,
                                        onClick = { mutate { it.alignment = value } },
                                        label = { Text(l(key)) },
                                        modifier = Modifier.testTag("table.props.align.$value")
                                    )
                                }
                            }
                            // 「從左邊縮排」只對靠左有意義（Word 也是）。
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text(l("table_indent_left"), Modifier.weight(1f))
                                NumberField(
                                    toDisplay(working.indentLeft ?: 0f), "table.props.indent",
                                    enabled = (working.alignment ?: "left") == "left"
                                ) { v -> mutate { it.indentLeft = maxOf(0f, fromDisplay(v)); it.alignment = "left" } }
                                Text(unitLabel, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                OutlinedButton(onClick = { showBorders = true }, modifier = Modifier.testTag("table.props.borders")) {
                                    Text(l("table_borders_and_shading"))
                                }
                                OutlinedButton(onClick = { showOptions = true }, modifier = Modifier.testTag("table.props.options")) {
                                    Text(l("table_options"))
                                }
                            }
                        }
                        1 -> {
                            val r = activeRow.coerceIn(0, working.rows - 1)
                            Navigator(l("table_tab_row"), r, working.rows, "▲", "▼") { activeRow = it }
                            val h = working.layout().rowHeights.getOrElse(r) { 30.0 }.toFloat()
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text(l("table_row_height"), Modifier.weight(1f))
                                NumberField(toDisplay(h), "table.props.row_height") { v ->
                                    mutate { it.setRowHeight(fromDisplay(v).toDouble(), r) }
                                }
                                Text(unitLabel, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                OutlinedButton(onClick = { mutate { it.distributeRows() } }) { Text(l("table_distribute_rows")) }
                                OutlinedButton(onClick = { mutate { it.setRowHeight(null, r) } }) { Text(l("table_size_auto")) }
                            }
                            SwitchRow(l("table_header_row"), working.headerRow) { on -> mutate { it.headerRow = on } }
                        }
                        2 -> {
                            val c = activeCol.coerceIn(0, working.cols - 1)
                            Navigator(l("table_tab_column"), c, working.cols, "◀", "▶") { activeCol = it }
                            val w = working.layout().columnWidths.getOrElse(c) { 60.0 }.toFloat()
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text(l("table_col_width"), Modifier.weight(1f))
                                NumberField(toDisplay(w), "table.props.col_width") { v ->
                                    mutate { it.setColumnWidth(fromDisplay(v).toDouble(), c) }
                                }
                                Text(unitLabel, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                OutlinedButton(onClick = { mutate { it.distributeColumns() } }) { Text(l("table_distribute_cols")) }
                                OutlinedButton(onClick = { mutate { it.setColumnWidth(null, c) } }) { Text(l("table_size_auto")) }
                            }
                        }
                        3 -> {
                            // 改的是**這一格**（合併區則整片），不是整張表。
                            val (rows, cols) = working.cellRange(activeRow, activeCol)
                            val style = working.style(rows.first, cols.first)
                            Text(
                                l("table_cell_position").replaceFirst("%1@", "${rows.first + 1}")
                                    .replaceFirst("%2@", "${cols.first + 1}"),
                                fontWeight = FontWeight.SemiBold
                            )
                            Navigator(l("table_tab_row"), activeRow.coerceIn(0, working.rows - 1), working.rows, "▲", "▼") { activeRow = it }
                            Navigator(l("table_tab_column"), activeCol.coerceIn(0, working.cols - 1), working.cols, "◀", "▶") { activeCol = it }
                            Text(l("table_align_v"), color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                for ((v, key) in listOf("top" to "table_align_top", "middle" to "table_align_middle", "bottom" to "table_align_bottom")) {
                                    FilterChip(
                                        selected = (style.vAlign ?: "top") == v,
                                        onClick = { mutate { t -> t.updateStyle(rows, cols) { it.copy(vAlign = if (v == "top") null else v) } } },
                                        label = { Text(l(key)) },
                                        modifier = Modifier.testTag("table.props.valign.$v")
                                    )
                                }
                            }
                            Text(l("table_align_h"), color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                for ((h, key) in listOf("left" to "table_align_left", "center" to "table_align_center", "right" to "table_align_right")) {
                                    FilterChip(
                                        selected = (style.hAlign ?: "left") == h,
                                        onClick = { mutate { t -> t.updateStyle(rows, cols) { it.copy(hAlign = if (h == "left") null else h) } } },
                                        label = { Text(l(key)) },
                                        modifier = Modifier.testTag("table.props.halign.$h")
                                    )
                                }
                            }
                        }
                        else -> {
                            Text(l("table_title_text"), fontWeight = FontWeight.SemiBold)
                            OutlinedTextField(
                                value = working.altTitle ?: "",
                                onValueChange = { text -> mutate { it.altTitle = text.ifEmpty { null } } },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth().testTag("table.props.alt_title")
                            )
                            Text(l("table_description_text"), fontWeight = FontWeight.SemiBold)
                            OutlinedTextField(
                                value = working.altDescription ?: "",
                                onValueChange = { text -> mutate { it.altDescription = text.ifEmpty { null } } },
                                minLines = 4,
                                modifier = Modifier.fillMaxWidth().testTag("table.props.alt_description")
                            )
                        }
                    }
                }
            }
        }
    )

    if (showBorders) {
        TableBordersShadingDialog(working, activeRow, activeCol, languageTag,
            onChange = { working = it }, onDismiss = { showBorders = false })
    }
    if (showOptions) {
        TableOptionsDialog(working, languageTag, onChange = { working = it }, onDismiss = { showOptions = false })
    }
}

/** 「表格 (3 × 4)」—— 列數與欄數要代進去，否則畫面上直接印出 `%1@`（與 Apple `tableTabLabel` 相同）。 */
fun tableTabLabel(template: String, rows: Int, cols: Int): String =
    template.replaceFirst("%1@", "$rows").replaceFirst("%2@", "$cols")

/** 「框線及網底…」：框線範圍、線型、粗細、顏色；網底（目前儲存格或整張表）與表頭底色。 */
@Composable
internal fun TableBordersShadingDialog(
    table: NoteTable,
    row: Int,
    col: Int,
    languageTag: String,
    onChange: (NoteTable) -> Unit,
    onDismiss: () -> Unit
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)
    var shadeWholeTable by remember { mutableStateOf(false) }
    fun mutate(block: (NoteTable) -> Unit) = onChange(table.copyTable().also(block))
    val cellRange = table.cellRange(row, col)
    val shadingRange = if (shadeWholeTable) (0 until table.rows) to (0 until table.cols) else cellRange
    val currentShade = table.style(shadingRange.first.first, shadingRange.second.first).fillHex
    fun setShading(hex: String?) = mutate { t -> t.updateStyle(shadingRange.first, shadingRange.second) { it.copy(fillHex = hex) } }

    AlertDialog(
        onDismissRequest = onDismiss,
        modifier = Modifier.testTag("table.borders"),
        // 按鈕字樣帶「…」（表示會開新視窗），視窗本身的標題不帶。
        title = { Text(l("table_borders_and_shading").trimEnd('.', '…')) },
        confirmButton = {
            TextButton(onClick = onDismiss, modifier = Modifier.testTag("table.borders.done")) { Text(l("done")) }
        },
        text = {
            Column(
                Modifier.heightIn(max = 460.dp).verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                SectionTitle(l("table_preview"))
                MiniPreview(table)
                HorizontalDivider()
                SectionTitle(l("table_borders"))
                ChipRow {
                    for ((mode, key) in listOf(null to "table_border_all", "outer" to "table_border_outer",
                        "inner" to "table_border_inner", "horizontal" to "table_border_horizontal", "none" to "table_border_none")) {
                        FilterChip(
                            selected = table.resolvedBorderMode.raw == (mode ?: "all"),
                            onClick = { mutate { it.borderMode = mode } },
                            label = { Text(l(key)) },
                            modifier = Modifier.testTag("table.borders.mode.${mode ?: "all"}")
                        )
                    }
                }
                Text(l("table_border_style"), color = MaterialTheme.colorScheme.onSurfaceVariant)
                ChipRow {
                    for ((style, key) in listOf(TableBorderStyle.SOLID to "table_border_solid",
                        TableBorderStyle.DASHED to "table_border_dashed", TableBorderStyle.DOTTED to "table_border_dotted")) {
                        FilterChip(
                            selected = table.resolvedBorderStyle == style,
                            onClick = { mutate { it.borderStyle = if (style == TableBorderStyle.SOLID) null else style.raw } },
                            label = { Text(l(key)) },
                            modifier = Modifier.testTag("table.borders.style.${style.raw}")
                        )
                    }
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(l("table_border_width"), Modifier.weight(1f))
                    TextButton(
                        onClick = { mutate { it.borderWidth = stepBorderWidth(it.resolvedBorderWidth, -0.5f) } },
                        enabled = table.resolvedBorderWidth > 0.5f,
                        modifier = Modifier.testTag("table.borders.width.minus")
                    ) { Text("−") }
                    Text("${"%.1f".format(table.resolvedBorderWidth)} ${l("table_unit_pt")}", modifier = Modifier.testTag("table.borders.width"))
                    TextButton(
                        onClick = { mutate { it.borderWidth = stepBorderWidth(it.resolvedBorderWidth, 0.5f) } },
                        enabled = table.resolvedBorderWidth < 6f,
                        modifier = Modifier.testTag("table.borders.width.plus")
                    ) { Text("+") }
                }
                ColorRow(l("table_rule_color"), table.ruleColorHex, l("table_reset_color"), "table.borders.color",
                    resetEnabled = table.ruleColorHex != null,
                    onPick = { hex -> mutate { it.ruleColorHex = hex } },
                    onReset = { mutate { it.ruleColorHex = null } })
                HorizontalDivider()
                SectionTitle(l("table_shading"))
                Text(l("table_apply_to"), color = MaterialTheme.colorScheme.onSurfaceVariant)
                ChipRow {
                    FilterChip(selected = !shadeWholeTable, onClick = { shadeWholeTable = false },
                        label = { Text(l("table_apply_cell")) }, modifier = Modifier.testTag("table.shading.target.cell"))
                    FilterChip(selected = shadeWholeTable, onClick = { shadeWholeTable = true },
                        label = { Text(l("table_apply_table")) }, modifier = Modifier.testTag("table.shading.target.table"))
                }
                ColorRow(l("table_fill_color"), currentShade, l("table_no_color"), "table.shading.color",
                    resetEnabled = currentShade != null,
                    onPick = { setShading(it) }, onReset = { setShading(null) })
                if (table.headerRow) {
                    ColorRow(l("table_header_fill"), table.headerBackgroundHex, l("table_no_color"), "table.shading.header",
                        resetEnabled = table.headerBackgroundHex != "clear",
                        onPick = { hex -> mutate { it.headerBackgroundHex = hex } },
                        onReset = { mutate { it.headerBackgroundHex = "clear" } })
                }
            }
        }
    )
}

/** 框線粗細一次 ±0.5 點，夾在 0.5～6；回到 1 寫 null（與 Apple Stepper 相同）。 */
internal fun stepBorderWidth(current: Float, delta: Float): Float? {
    val next = (current + delta).coerceIn(0.5f, 6f)
    return if (next == 1f) null else next
}

/** 「選項…」：表頭、帶狀列／欄、字級。 */
@Composable
internal fun TableOptionsDialog(
    table: NoteTable,
    languageTag: String,
    onChange: (NoteTable) -> Unit,
    onDismiss: () -> Unit
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)
    fun mutate(block: (NoteTable) -> Unit) = onChange(table.copyTable().also(block))
    AlertDialog(
        onDismissRequest = onDismiss,
        modifier = Modifier.testTag("table.options"),
        title = { Text(l("table_options_title")) },
        confirmButton = {
            TextButton(onClick = onDismiss, modifier = Modifier.testTag("table.options.done")) { Text(l("done")) }
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                SectionTitle(l("table_preview"))
                MiniPreview(table)
                SwitchRow(l("table_header_row"), table.headerRow) { on -> mutate { it.headerRow = on } }
                SwitchRow(l("table_banded_rows"), table.bandedRows == true, "table.options.banded_rows") { on ->
                    mutate { it.bandedRows = if (on) true else null }
                }
                SwitchRow(l("table_banded_cols"), table.bandedCols == true, "table.options.banded_cols") { on ->
                    mutate { it.bandedCols = if (on) true else null }
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(l("table_font_size"), Modifier.weight(1f))
                    TextButton(onClick = { mutate { it.fontSize = (it.fontSize - 1f).coerceIn(8f, 36f) } },
                        enabled = table.fontSize > 8f) { Text("−") }
                    Text("${table.fontSize.roundToInt()} ${l("table_unit_pt")}", modifier = Modifier.testTag("table.options.font_size"))
                    TextButton(onClick = { mutate { it.fontSize = (it.fontSize + 1f).coerceIn(8f, 36f) } },
                        enabled = table.fontSize < 36f) { Text("+") }
                }
            }
        }
    )
}

// MARK: - 小元件

@Composable
private fun SectionTitle(text: String) {
    Text(text, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
}

@Composable
private fun ChipRow(content: @Composable () -> Unit) {
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) { content() }
}

@Composable
private fun SwitchRow(label: String, on: Boolean, tag: String? = null, onToggle: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(label, Modifier.weight(1f))
        Switch(on, onCheckedChange = onToggle, modifier = if (tag != null) Modifier.testTag(tag) else Modifier)
    }
}

@Composable
private fun Navigator(label: String, index: Int, count: Int, prev: String, next: String, onMove: (Int) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text("$label ${index + 1} / $count", fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
        TextButton(onClick = { onMove(maxOf(0, index - 1)) }, enabled = index > 0) { Text(prev) }
        TextButton(onClick = { onMove(minOf(count - 1, index + 1)) }, enabled = index < count - 1) { Text(next) }
    }
}

@Composable
private fun UnitToggle(useCm: Boolean, cm: String, pt: String, onChange: (Boolean) -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        FilterChip(selected = useCm, onClick = { onChange(true) }, label = { Text(cm) })
        FilterChip(selected = !useCm, onClick = { onChange(false) }, label = { Text(pt) })
    }
}

/** 數字輸入框：打字中保留使用者的字，解析成功才回報（不會邊打邊被改寫）。 */
@Composable
private fun NumberField(value: Float, tag: String, enabled: Boolean = true, onValue: (Float) -> Unit) {
    val shown = "%.2f".format(value)
    var text by remember(tag) { mutableStateOf(shown) }
    var editing by remember(tag) { mutableStateOf(false) }
    LaunchedEffect(shown) { if (!editing) text = shown }
    OutlinedTextField(
        value = text,
        onValueChange = { t ->
            editing = true
            text = t
            t.replace(',', '.').toFloatOrNull()?.let { if (it >= 0f) onValue(it) }
        },
        enabled = enabled,
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
        modifier = Modifier.width(96.dp).testTag(tag)
    )
}

@Composable
private fun ColorRow(
    label: String,
    currentHex: String?,
    resetLabel: String,
    tag: String,
    resetEnabled: Boolean,
    onPick: (String) -> Unit,
    onReset: () -> Unit
) {
    var open by remember { mutableStateOf(false) }
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(label, Modifier.weight(1f))
        Box {
            Box(
                Modifier
                    .size(28.dp)
                    .background(currentHex?.takeIf { it != "clear" }?.let(::hexColor) ?: Color.Transparent, RoundedCornerShape(4.dp))
                    .border(1.dp, Color.Gray.copy(alpha = 0.6f), RoundedCornerShape(4.dp))
                    .clickable { open = true }
                    .semantics { contentDescription = label }
                    .testTag(tag)
            )
            androidx.compose.material3.DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
                SwatchGrid(currentHex) { hex -> open = false; onPick(hex) }
            }
        }
        TextButton(onClick = onReset, enabled = resetEnabled, modifier = Modifier.testTag("$tag.reset")) { Text(resetLabel) }
    }
}

/** 子面板裡的即時預覽：與畫布同一份算繪（[TablePreview]），等比例縮到可用寬度。 */
@Composable
private fun MiniPreview(table: NoteTable) {
    val layout = table.layout()
    val w = maxOf(1f, layout.width.toFloat())
    val h = maxOf(1f, layout.height.toFloat())
    val scale = minOf(1f, 260f / w, 140f / h)
    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.TopCenter) {
        Box(Modifier.size((w * scale).dp, (h * scale).dp)) {
            TablePreview(
                table = table,
                density = androidx.compose.ui.platform.LocalDensity.current.density,
                modifier = Modifier
                    .wrapContentSize(align = Alignment.TopStart, unbounded = true)
                    .graphicsLayer(
                        scaleX = scale, scaleY = scale,
                        transformOrigin = androidx.compose.ui.graphics.TransformOrigin(0f, 0f)
                    )
            )
        }
    }
}
