package com.kairumo.padnote.chart

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.FilterChip
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.TabRow
import androidx.compose.material3.Tab
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.LocalizationStrings

/**
 * 數字製圖（Android）—— 表格編輯、圖表類型、格式設定，以及即時預覽。
 *
 * 與 Apple 的 `ChartStudioView` 對齊：同一份 [ChartSpec]、同一個核心版面引擎、
 * 同一組在地化鍵。編輯的是**設定**而不是圖片，所以插進筆記之後還改得動。
 *
 * @param initial 要編修的既有圖表；`null` 代表新插入一張。
 * @param onCommit 交出去的是設定與尺寸，呼叫端再決定要不要點陣化 ——
 *   設定必須存起來，否則這張圖下次就改不動了。
 */
@Composable
fun ChartStudio(
    languageTag: String,
    initial: ChartSpec? = null,
    onCommit: (ChartSpec) -> Unit,
    onDismiss: () -> Unit
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    // 規格是可變物件，改完要換成新實例 Compose 才會重組。
    var spec by remember { mutableStateOf(initial?.copySpec() ?: ChartSpec.makeDefault()) }
    var tab by remember { mutableIntStateOf(0) }
    fun mutate(block: ChartSpec.() -> Unit) {
        spec = spec.copySpec().apply(block)
    }

    Column(Modifier.fillMaxSize()) {
        ChartPreview(spec, Modifier.fillMaxWidth().height(240.dp))
        HorizontalDivider()

        val tabs = listOf("chart_tab_data", "chart_tab_type", "chart_tab_format")
        TabRow(selectedTabIndex = tab) {
            tabs.forEachIndexed { index, key ->
                Tab(selected = tab == index, onClick = { tab = index }, text = { Text(l(key)) })
            }
        }

        Box(Modifier.weight(1f)) {
            when (tab) {
                0 -> DataSheet(spec, ::l, ::mutate)
                1 -> TypeGallery(spec, ::l) { kind -> mutate { this.kind = kind } }
                else -> FormatPanel(spec, ::l, ::mutate)
            }
        }

        HorizontalDivider()
        Row(
            Modifier.fillMaxWidth().padding(12.dp),
            horizontalArrangement = Arrangement.End
        ) {
            TextButton(onClick = onDismiss) { Text(l("cancel")) }
            Button(
                onClick = { onCommit(spec) },
                // 畫不出來的規格插進去只會得到一塊空白。
                enabled = spec.isDrawable
            ) {
                Text(l(if (initial != null) "chart_update" else "chart_insert"))
            }
        }
    }
}

/**
 * 圖表的即時預覽。
 *
 * 走 `nativeCanvas` 交給 [ChartRenderer.draw] —— 跟點陣化用的是**同一支**繪製
 * 函式，否則預覽好看、插進去卻不一樣，而使用者要到插入後才會發現。
 */
@Composable
// 原本收一個 `languageTag`，主體從沒讀過它 —— ChartRenderer.draw 不收語系，
// failureReason 回的是原始例外訊息（沒有翻譯）。Apple 的 ChartPreview(spec:)
// 也沒有這個參數，拿掉之後兩端一致。
fun ChartPreview(spec: ChartSpec, modifier: Modifier = Modifier) {
    val foreground = MaterialTheme.colorScheme.onSurface
    val grid = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.14f)
    var reason by remember(spec) { mutableStateOf<String?>(null) }

    Box(modifier.background(MaterialTheme.colorScheme.surfaceVariant), Alignment.Center) {
        Canvas(Modifier.fillMaxSize().padding(12.dp)) {
            val layout = ChartRenderer.layout(spec, size.width, size.height)
            if (layout == null) {
                reason = ChartRenderer.failureReason(spec, size.width, size.height)
                return@Canvas
            }
            reason = null
            drawIntoCanvas { canvas ->
                ChartRenderer.draw(
                    layout, canvas.nativeCanvas,
                    foreground = foreground.toArgb(),
                    gridColor = grid.toArgb()
                )
            }
        }
        // 空白畫布看起來像壞掉了 —— 要講出是哪裡不對。
        reason?.let {
            Text(
                it,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

// MARK: - 資料（試算表）

@Composable
private fun DataSheet(
    spec: ChartSpec,
    l: (String) -> String,
    mutate: (ChartSpec.() -> Unit) -> Unit
) {
    Column(Modifier.fillMaxSize()) {
        if (spec.kind.usesSingleSeries && spec.series.size > 1) {
            // 說出來，使用者才不會納悶第二欄的數字為什麼沒有出現。
            Text(
                l("chart_single_series_hint"),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
            )
        }

        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState())
                .horizontalScroll(rememberScrollState()).padding(12.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    l("chart_category_column"),
                    Modifier.width(110.dp),
                    style = MaterialTheme.typography.labelMedium
                )
                spec.series.forEachIndexed { index, series ->
                    Column(Modifier.width(130.dp).padding(horizontal = 3.dp)) {
                        OutlinedTextField(
                            value = series.name,
                            onValueChange = { name -> mutate { this.series[index].name = name } },
                            label = { Text(l("chart_series_name"), fontSize = 10.sp) },
                            singleLine = true,
                            textStyle = MaterialTheme.typography.bodySmall
                        )
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            // 色盤走核心，取色器顯示的就是畫出來的顏色。
                            ColorSwatchRow(spec.effectiveColorHex(index)) { hex ->
                                mutate { this.series[index].colorHex = hex }
                            }
                            if (spec.series.size > 1) {
                                TextButton(onClick = { mutate { removeSeries(index) } }) {
                                    Text("−", fontSize = 16.sp)
                                }
                            }
                        }
                    }
                }
            }

            for (row in 0 until spec.rowCount) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    OutlinedTextField(
                        value = spec.category(row),
                        onValueChange = { name -> mutate { setCategory(name, row) } },
                        modifier = Modifier.width(110.dp),
                        placeholder = { Text("${row + 1}") },
                        singleLine = true,
                        textStyle = MaterialTheme.typography.bodySmall
                    )
                    spec.series.indices.forEach { index ->
                        NumberCell(
                            value = spec.value(index, row),
                            modifier = Modifier.width(130.dp).padding(horizontal = 3.dp)
                        ) { value -> mutate { setValue(value, index, row) } }
                    }
                    if (spec.rowCount > 1) {
                        TextButton(onClick = { mutate { removeRow(row) } }) {
                            Text("−", fontSize = 16.sp)
                        }
                    }
                }
            }
        }

        HorizontalDivider()
        Row(Modifier.fillMaxWidth().padding(12.dp), Arrangement.SpaceBetween) {
            TextButton(onClick = { mutate { addRow() } }) { Text(l("chart_add_row")) }
            TextButton(onClick = { mutate { addSeries() } }) { Text(l("chart_add_series")) }
        }
    }
}

/**
 * 一格數字。
 *
 * 文字狀態留在這一格裡：每打一個字就 parse 回 Double 的話，使用者打到
 * 「-」或「1.」這種還不是合法數字的中途狀態，游標就會被彈掉。
 */
@Composable
private fun NumberCell(value: Double, modifier: Modifier, onValue: (Double) -> Unit) {
    var text by remember(value) { mutableStateOf(formatNumber(value)) }
    OutlinedTextField(
        value = text,
        onValueChange = { input ->
            text = input
            input.trim().toDoubleOrNull()?.let(onValue)
        },
        modifier = modifier,
        singleLine = true,
        textStyle = MaterialTheme.typography.bodySmall
    )
}

/** 整數不要拖著 `.0` —— 表格裡滿滿的 `10.0` 只是雜訊。 */
private fun formatNumber(value: Double): String =
    if (value == value.toLong().toDouble()) value.toLong().toString() else value.toString()

/** 色盤取色。顏色來自核心，與畫出來的完全一致。 */
@Composable
private fun ColorSwatchRow(current: String, onPick: (String) -> Unit) {
    val palette = (0 until uniffi.padnote_core.chartPaletteCount().toInt()).map {
        uniffi.padnote_core.chartPaletteColor(it.toUInt())
    }
    Row(Modifier.horizontalScroll(rememberScrollState())) {
        palette.forEach { hex ->
            val color = Color(ChartRenderer.parseColor(hex) ?: Color.Blue.toArgb())
            Box(
                Modifier
                    .padding(2.dp)
                    .width(18.dp).height(18.dp)
                    .background(color, RoundedCornerShape(4.dp))
                    .border(
                        if (hex.equals(current, ignoreCase = true)) 2.dp else 0.dp,
                        MaterialTheme.colorScheme.onSurface,
                        RoundedCornerShape(4.dp)
                    )
            ) {
                IconButton(onClick = { onPick(hex) }, modifier = Modifier.fillMaxSize()) {}
            }
        }
    }
}

// MARK: - 類型

@Composable
private fun TypeGallery(spec: ChartSpec, l: (String) -> String, onPick: (ChartKind) -> Unit) {
    LazyVerticalGrid(
        columns = GridCells.Adaptive(110.dp),
        modifier = Modifier.fillMaxSize().padding(12.dp)
    ) {
        items(ChartKind.entries.toList()) { kind ->
            FilterChip(
                selected = spec.kind == kind,
                onClick = { onPick(kind) },
                label = { Text(l(kind.localizationKey), fontSize = 12.sp) },
                modifier = Modifier.padding(4.dp)
            )
        }
    }
}

// MARK: - 格式

@Composable
private fun FormatPanel(
    spec: ChartSpec,
    l: (String) -> String,
    mutate: (ChartSpec.() -> Unit) -> Unit
) {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        OutlinedTextField(
            value = spec.title,
            onValueChange = { value -> mutate { title = value } },
            label = { Text(l("chart_title")) },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )

        if (spec.kind.hasAxes) {
            Text(l("chart_section_axes"), style = MaterialTheme.typography.titleSmall)
            OutlinedTextField(
                value = spec.xAxis.title,
                onValueChange = { value -> mutate { xAxis.title = value } },
                label = { Text(l("chart_x_axis_title")) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
            OutlinedTextField(
                value = spec.yAxis.title,
                onValueChange = { value -> mutate { yAxis.title = value } },
                label = { Text(l("chart_y_axis_title")) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
            SwitchRow(l("chart_show_grid"), spec.yAxis.showGrid) { on ->
                mutate { yAxis.showGrid = on }
            }
            SwitchRow(l("chart_show_axis_labels"), spec.yAxis.showLabels) { on ->
                mutate { yAxis.showLabels = on }
            }
            OptionalNumberField(l("chart_axis_min"), spec.yAxis.min) { v -> mutate { yAxis.min = v } }
            OptionalNumberField(l("chart_axis_max"), spec.yAxis.max) { v -> mutate { yAxis.max = v } }
            OptionalNumberField(l("chart_axis_step"), spec.yAxis.step) { v -> mutate { yAxis.step = v } }
        }

        Text(l("chart_section_legend"), style = MaterialTheme.typography.titleSmall)
        Row(Modifier.horizontalScroll(rememberScrollState())) {
            ChartLegendPosition.entries.forEach { position ->
                FilterChip(
                    selected = spec.legend == position,
                    onClick = { mutate { legend = position } },
                    label = { Text(l(position.localizationKey), fontSize = 12.sp) },
                    modifier = Modifier.padding(end = 6.dp)
                )
            }
        }
        Row(Modifier.horizontalScroll(rememberScrollState())) {
            ChartLabelPosition.entries.forEach { position ->
                FilterChip(
                    selected = spec.dataLabels == position,
                    onClick = { mutate { dataLabels = position } },
                    label = { Text(l(position.localizationKey), fontSize = 12.sp) },
                    modifier = Modifier.padding(end = 6.dp)
                )
            }
        }
        if (spec.dataLabels != ChartLabelPosition.NONE) {
            Text("${l("chart_label_decimals")}　${spec.labelDecimals}")
            Slider(
                value = spec.labelDecimals.toFloat(),
                onValueChange = { value -> mutate { labelDecimals = value.toInt() } },
                valueRange = 0f..4f,
                steps = 3
            )
        }

        Text(l("chart_section_style"), style = MaterialTheme.typography.titleSmall)
        if (spec.kind == ChartKind.BAR || spec.kind == ChartKind.STACKED_BAR ||
            spec.kind == ChartKind.HORIZONTAL_BAR
        ) {
            Text(l("chart_bar_width"))
            Slider(
                value = spec.barWidthRatio.toFloat(),
                onValueChange = { value -> mutate { barWidthRatio = value.toDouble() } },
                valueRange = 0.2f..1f
            )
        }
        if (spec.kind == ChartKind.DOUGHNUT) {
            Text(l("chart_doughnut_hole"))
            Slider(
                value = spec.doughnutHoleRatio.toFloat(),
                onValueChange = { value -> mutate { doughnutHoleRatio = value.toDouble() } },
                valueRange = 0f..0.85f
            )
        }
    }
}

@Composable
private fun SwitchRow(label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth(), Arrangement.SpaceBetween, Alignment.CenterVertically) {
        Text(label)
        Switch(checked = checked, onCheckedChange = onChange)
    }
}

/**
 * 「自動 / 指定」的數值欄位。
 *
 * 空字串代表交給核心決定，不是 0 —— 把留空當成 0 的話，使用者清掉欄位就會
 * 意外把軸釘死在零。
 */
@Composable
private fun OptionalNumberField(label: String, value: Double?, onChange: (Double?) -> Unit) {
    var text by remember(value) { mutableStateOf(value?.let { formatNumber(it) } ?: "") }
    OutlinedTextField(
        value = text,
        onValueChange = { input ->
            text = input
            onChange(if (input.isBlank()) null else input.trim().toDoubleOrNull())
        },
        label = { Text(label) },
        singleLine = true,
        modifier = Modifier.fillMaxWidth()
    )
}
