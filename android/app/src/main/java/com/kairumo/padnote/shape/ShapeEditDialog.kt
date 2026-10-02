package com.kairumo.padnote.shape

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.kairumo.padnote.LocalizationStrings
import com.kairumo.padnote.canvas.ObjectStacking
import com.kairumo.padnote.ui.DialogResizeHandle
import com.kairumo.padnote.ui.rememberDialogHeight
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import uniffi.padnote_core.FfiShapeKind
import uniffi.padnote_core.allShapeKinds
import uniffi.padnote_core.shapeIsLinear

/**
 * 形狀編修面板（對應 Apple 的 `ShapeEditPanel`）。
 *
 * **每個動作立刻套用**：對話框後面的畫布看得到改動，不必按「完成」才知道改出來長怎樣。
 * 滑桿只在放開時才寫回 —— 拖曳每一幀都存檔的話，整份形狀的變換操作會一路疊上去。
 *
 * 選項與 Apple 端一致（種類、文字、字級、粗斜體、文字色、填色、線色、粗細、虛實、
 * 圓角、不透明度、旋轉、大小、複製、層級、刪除）—— 兩邊能調的東西不一樣的話，
 * 在 iPad 上調好的流程圖到 Android 上改不回來，而這些設定是會同步的。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ShapeEditDialog(
    shape: NoteShape,
    languageTag: String,
    onApply: (NoteShape) -> Unit,
    onDuplicate: (NoteShape) -> Unit,
    onDelete: (NoteShape) -> Unit,
    onReorder: (ObjectStacking.Reorder) -> Unit,
    onDismiss: () -> Unit
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    var draft by remember(shape.id) { mutableStateOf(shape.copyShape()) }
    val dialogHeight = rememberDialogHeight("shapeEditor", 460.dp)

    /** 離散的改動：立刻套用。 */
    fun commit(change: NoteShape.() -> Unit) {
        draft = draft.copyShape().apply(change)
        onApply(draft)
    }

    /** 滑桿的過程：只改草稿，放開才套用。 */
    fun preview(change: NoteShape.() -> Unit) {
        draft = draft.copyShape().apply(change)
    }

    val swappable = remember(draft.isLinear) {
        allShapeKinds().filter { shapeIsLinear(it) == draft.isLinear }
    }
    val hasCorner = draft.kindName.lowercase() in setOf("roundedrectangle", "terminator")

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("shape_edit")) },
        text = {
            // 內容與把手包進同一個 Column：AlertDialog 的 text 槽是 Box，
            // 兩個兄弟會疊在一起，把手蓋住內容最上面 24dp（那一排點不到）。
            Column {
                Column(
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                    modifier = Modifier.height(dialogHeight.value).verticalScroll(rememberScrollState())
                ) {
                    // 層級：移到最上層／上移／下移／移到最下層。
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        for (op in ObjectStacking.Reorder.entries) {
                            AssistChip(onClick = { onReorder(op) }, label = { Text(l(op.labelKey)) })
                        }
                    }

                    SectionLabel(l("shape_change_kind"))
                    KindMenu(draft.kind, swappable, languageTag) { kind ->
                        commit { kindName = NoteShape.nameOf(kind) }
                    }

                    if (draft.acceptsText) {
                        SectionLabel(l("shape_text_section"))
                        OutlinedTextField(
                            value = draft.label,
                            onValueChange = { v -> commit { label = v } },
                            label = { Text(l("shape_label")) },
                            modifier = Modifier.fillMaxWidth()
                        )
                        LabeledSlider(
                            "${l("font_size")}: ${(draft.fontSize ?: 14f).roundToInt()}",
                            value = draft.fontSize ?: 14f, range = 8f..64f,
                            onChange = { v -> preview { fontSize = v.roundToInt().toFloat() } },
                            onFinished = { onApply(draft) }
                        )
                        FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            FilterChip(
                                selected = draft.isBold == true,
                                onClick = { commit { isBold = if (isBold == true) null else true } },
                                label = { Text(l("font_bold")) }
                            )
                            FilterChip(
                                selected = draft.isItalic == true,
                                onClick = { commit { isItalic = if (isItalic == true) null else true } },
                                label = { Text(l("font_italic")) }
                            )
                        }
                        Swatches(draft.textColorHex, includeClear = false) { hex -> commit { textColorHex = hex } }
                    }

                    if (!draft.isLinear) {
                        SectionLabel(l("fill_color"))
                        Swatches(draft.fillColorHex, includeClear = true) { hex -> commit { fillColorHex = hex } }
                    }

                    SectionLabel(l("stroke_color"))
                    Swatches(draft.strokeColorHex, includeClear = false) { hex -> commit { strokeColorHex = hex } }

                    LabeledSlider(
                        "${l("line_width")}: ${"%.1f".format(draft.lineWidth)}",
                        value = draft.lineWidth, range = 0.5f..12f,
                        onChange = { v -> preview { lineWidth = (v * 2f).roundToInt() / 2f } },
                        onFinished = { onApply(draft) }
                    )

                    SectionLabel(l("shape_line_style"))
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        for (d in ShapeDash.entries) {
                            FilterChip(
                                selected = draft.dash == d,
                                onClick = { commit { dashStyle = if (d == ShapeDash.SOLID) null else d.raw } },
                                label = { Text(l(d.labelKey)) }
                            )
                        }
                    }

                    if (hasCorner) {
                        LabeledSlider(
                            l("shape_corner"),
                            value = draft.cornerRadius,
                            range = 0f..max(1f, min(draft.width, draft.height) / 2f),
                            onChange = { v -> preview { cornerRadius = v } },
                            onFinished = { onApply(draft) }
                        )
                    }

                    LabeledSlider(
                        "${l("opacity")}: ${((draft.opacity ?: 1f) * 100).roundToInt()}%",
                        value = draft.opacity ?: 1f, range = 0.1f..1f,
                        onChange = { v -> preview { opacity = if (v >= 0.999f) null else v } },
                        onFinished = { onApply(draft) }
                    )

                    LabeledSlider(
                        "${l("shape_rotation")}: ${(draft.rotationDegrees ?: 0f).roundToInt()}°",
                        value = draft.rotationDegrees ?: 0f, range = 0f..359f,
                        onChange = { v ->
                            preview { rotationDegrees = ShapeFrameMath.snapped(v).let { if (it < 0.01f) null else it } }
                        },
                        onFinished = { onApply(draft) }
                    )
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        for (angle in listOf(0f, 90f, 180f, 270f)) {
                            AssistChip(
                                onClick = { commit { rotationDegrees = if (angle == 0f) null else angle } },
                                label = { Text("${angle.roundToInt()}°") }
                            )
                        }
                    }

                    if (!draft.isLinear) {
                        SectionLabel(l("shape_geometry_section"))
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            SizeField(l("shape_width"), draft.width, Modifier.weight(1f)) { v ->
                                commit { width = max(ShapeFrameMath.MIN_SIDE, v) }
                            }
                            SizeField(l("shape_height"), draft.height, Modifier.weight(1f)) { v ->
                                commit { height = max(ShapeFrameMath.MIN_SIDE, v) }
                            }
                        }
                        Text(
                            l("shape_flowchart_hint"),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }

                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        OutlinedButton(onClick = { onDuplicate(draft) }) { Text(l("shape_duplicate")) }
                        OutlinedButton(onClick = { onDelete(draft); onDismiss() }) {
                            Text(l("delete"), color = MaterialTheme.colorScheme.error)
                        }
                    }
                }
                // 底部的拖曳把手：往下拖變高（S-72）。
                DialogResizeHandle(dialogHeight, "shapeEditor")
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text(l("done")) } }
    )
}

/** 連接線編修面板（對應 Apple 的 `ConnectionEditPanel`）。 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ConnectionEditDialog(
    link: NoteConnection,
    languageTag: String,
    onApply: (NoteConnection) -> Unit,
    onDelete: (NoteConnection) -> Unit,
    onDismiss: () -> Unit
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    var draft by remember(link.id) { mutableStateOf(link.copy()) }
    val dialogHeight = rememberDialogHeight("connectionEditor", 420.dp)

    fun commit(change: NoteConnection.() -> NoteConnection) {
        draft = draft.change()
        onApply(draft)
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("connection_edit")) },
        text = {
            // 內容與把手包進同一個 Column：AlertDialog 的 text 槽是 Box，
            // 兩個兄弟會疊在一起，把手蓋住內容最上面 24dp（那一排點不到）。
            Column {
                Column(
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                    modifier = Modifier.height(dialogHeight.value).verticalScroll(rememberScrollState())
                ) {
                    SectionLabel(l("connection_route"))
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        for (r in ConnectionRoute.entries) {
                            FilterChip(
                                selected = (ConnectionRoute.named(draft.route) ?: ConnectionRoute.ORTHOGONAL) == r,
                                onClick = { commit { copy(route = r.raw) } },
                                label = { Text(l(r.labelKey)) }
                            )
                        }
                    }

                    SectionLabel(l("connection_start_cap"))
                    CapMenu(draft.startCapName, languageTag) { cap ->
                        // 預設值（起點無、終點箭頭）存成 null，保持檔案乾淨。
                        commit { copy(startCap = if (cap == ConnectionCap.NONE) null else cap.raw) }
                    }
                    SectionLabel(l("connection_end_cap"))
                    CapMenu(draft.endCapName, languageTag) { cap ->
                        commit { copy(endCap = if (cap == ConnectionCap.ARROW) null else cap.raw) }
                    }

                    SectionLabel(l("connection_from_anchor"))
                    AnchorChips(draft.fromAnchor, languageTag) { raw -> commit { copy(fromAnchor = raw) } }
                    SectionLabel(l("connection_to_anchor"))
                    AnchorChips(draft.toAnchor, languageTag) { raw -> commit { copy(toAnchor = raw) } }

                    OutlinedTextField(
                        value = draft.label,
                        onValueChange = { v -> commit { copy(label = v) } },
                        label = { Text(l("shape_label")) },
                        modifier = Modifier.fillMaxWidth()
                    )

                    SectionLabel(l("stroke_color"))
                    Swatches(draft.colorHex, includeClear = false) { hex -> commit { copy(colorHex = hex) } }

                    LabeledSlider(
                        "${l("line_width")}: ${"%.1f".format(draft.lineWidth)}",
                        value = draft.lineWidth, range = 0.5f..10f,
                        onChange = { v -> draft = draft.copy(lineWidth = (v * 2f).roundToInt() / 2f) },
                        onFinished = { onApply(draft) }
                    )

                    SectionLabel(l("shape_line_style"))
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        for (d in ShapeDash.entries) {
                            FilterChip(
                                selected = draft.dash == d,
                                onClick = { commit { copy(dashStyle = if (d == ShapeDash.SOLID) null else d.raw) } },
                                label = { Text(l(d.labelKey)) }
                            )
                        }
                    }

                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        OutlinedButton(onClick = { commit { reversed() } }) { Text(l("connection_reverse")) }
                        OutlinedButton(onClick = { onDelete(draft); onDismiss() }) {
                            Text(l("delete"), color = MaterialTheme.colorScheme.error)
                        }
                    }
                }
                DialogResizeHandle(dialogHeight, "connectionEditor")
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text(l("done")) } }
    )
}

// ---- 小零件 ------------------------------------------------------------------

@Composable
private fun SectionLabel(text: String) {
    Text(text, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

@Composable
private fun LabeledSlider(
    label: String,
    value: Float,
    range: ClosedFloatingPointRange<Float>,
    onChange: (Float) -> Unit,
    onFinished: () -> Unit
) {
    Column {
        SectionLabel(label)
        Slider(
            value = value.coerceIn(range.start, range.endInclusive),
            onValueChange = onChange,
            onValueChangeFinished = onFinished,
            valueRange = range
        )
    }
}

@Composable
private fun SizeField(label: String, value: Float, modifier: Modifier, onValue: (Float) -> Unit) {
    var text by remember(value.roundToInt()) { mutableStateOf(value.roundToInt().toString()) }
    OutlinedTextField(
        value = text,
        onValueChange = { raw ->
            text = raw.filter { it.isDigit() }.take(4)
            text.toFloatOrNull()?.let(onValue)
        },
        label = { Text(label) },
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        modifier = modifier
    )
}

@Composable
private fun KindMenu(
    current: FfiShapeKind,
    kinds: List<FfiShapeKind>,
    languageTag: String,
    onPick: (FfiShapeKind) -> Unit
) {
    var open by remember { mutableStateOf(false) }
    fun name(kind: FfiShapeKind): String {
        val key = "shape_kind_${NoteShape.nameOf(kind)}"
        val localized = LocalizationStrings.localized(key, languageTag)
        // 語系表裡沒有的退回識別字，而不是顯示一個空白的項目。
        return if (localized == key) NoteShape.nameOf(kind) else localized
    }
    Box {
        OutlinedButton(onClick = { open = true }, modifier = Modifier.fillMaxWidth()) {
            Text(name(current))
        }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            for (kind in kinds) {
                DropdownMenuItem(text = { Text(name(kind)) }, onClick = { open = false; onPick(kind) })
            }
        }
    }
}

@Composable
private fun CapMenu(current: ConnectionCap, languageTag: String, onPick: (ConnectionCap) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        OutlinedButton(onClick = { open = true }, modifier = Modifier.fillMaxWidth()) {
            Text(LocalizationStrings.localized(current.labelKey, languageTag))
        }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            for (cap in ConnectionCap.entries) {
                DropdownMenuItem(
                    text = { Text(LocalizationStrings.localized(cap.labelKey, languageTag)) },
                    onClick = { open = false; onPick(cap) }
                )
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun AnchorChips(selected: String?, languageTag: String, onPick: (String?) -> Unit) {
    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        FilterChip(
            selected = selected == null,
            onClick = { onPick(null) },
            label = { Text(LocalizationStrings.localized("anchor_auto", languageTag)) }
        )
        for (a in ShapeAnchor.entries) {
            FilterChip(
                selected = selected == a.raw,
                onClick = { onPick(a.raw) },
                label = { Text(LocalizationStrings.localized(a.labelKey, languageTag)) }
            )
        }
    }
}

/**
 * 與 Apple 端 `ColorSwatchRow` 同一組色。**來源是核心的 `borderPalette()`** ——
 * 同一份筆記在兩個平台可選的顏色不同的話，一邊設好的顏色到另一邊就改不回來了。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun Swatches(selected: String?, includeClear: Boolean, onPick: (String?) -> Unit) {
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        if (includeClear) {
            // 命中區 38dp、色點 26dp —— 純色點當命中區在手指下太小。
            Box(Modifier.size(38.dp).clickable { onPick("clear") }, contentAlignment = Alignment.Center) {
                Box(
                    Modifier.size(26.dp)
                        .background(Color.Transparent, CircleShape)
                        .border(
                            if (selected == "clear") 2.5.dp else 1.dp,
                            if (selected == "clear") MaterialTheme.colorScheme.primary
                            else MaterialTheme.colorScheme.outline,
                            CircleShape
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    // 透明畫一條斜線 —— 不畫的話它跟白色長得一樣。
                    Box(Modifier.width(22.dp).height(1.5.dp).background(Color.Red.copy(alpha = 0.7f)))
                }
            }
        }
        for (hex in uniffi.padnote_core.borderPalette().map { it.hex }) {
            val color = com.kairumo.padnote.chart.ChartRenderer.parseColor(hex)?.let { Color(it) } ?: Color.Gray
            Box(Modifier.size(38.dp).clickable { onPick(hex) }, contentAlignment = Alignment.Center) {
                Box(
                    Modifier.size(26.dp)
                        .background(color, CircleShape)
                        .border(
                            if (selected == hex) 2.5.dp else 1.dp,
                            if (selected == hex) MaterialTheme.colorScheme.primary
                            else MaterialTheme.colorScheme.outline,
                            CircleShape
                        )
                )
            }
        }
    }
}
