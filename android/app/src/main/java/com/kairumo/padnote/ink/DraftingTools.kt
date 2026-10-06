package com.kairumo.padnote.ink

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.L10n
import com.kairumo.padnote.LocalizationStrings
import uniffi.padnote_core.FfiDimAxis
import uniffi.padnote_core.FfiDimension
import uniffi.padnote_core.FfiDraftKit
import uniffi.padnote_core.FfiDraftSymbolInfo
import uniffi.padnote_core.FfiPhase
import uniffi.padnote_core.FfiPoint
import uniffi.padnote_core.FfiSymbolParams
import uniffi.padnote_core.draftDimAngle
import uniffi.padnote_core.draftDimDiameter
import uniffi.padnote_core.draftDimLinear
import uniffi.padnote_core.draftDimRadius
import uniffi.padnote_core.draftLinePattern
import uniffi.padnote_core.draftScales
import uniffi.padnote_core.draftSymbol
import uniffi.padnote_core.draftSymbolCatalog

/**
 * 圖學工具的觸控流程（對應 Apple 的 `DraftToolController`）：點兩個點再拖出尺寸線、點圓再拖出引線…
 *
 * 幾何（尺寸線、箭頭、數字）全在核心（`draft_dim_*`），這裡只管「點了哪裡、現在在第幾步、預覽什麼」。
 * 預覽畫在引擎的覆蓋層（不存檔、不進復原）；完成時整組標註一次插入、一次復原。
 */
object DraftToolController {
    private val picks = mutableListOf<InkEngine.Offset2>()
    /** 圓形標註：從已經畫好的圓（擬合出來的）取得圓心與半徑；手動點圓心的話是 null。 */
    private var fitted: Pair<InkEngine.Offset2, Float>? = null
    private var lastTool = DraftTool.NONE

    /** 內容改了，要重畫。 */
    var onChanged: () -> Unit = {}

    private fun pt(p: InkEngine.Offset2) = FfiPoint(p.x, p.y)
    private fun pt(x: Float, y: Float) = FfiPoint(x, y)

    /** 目前這一步在等什麼。 */
    fun refreshHint() {
        val n = picks.size
        val key: String? = when (DraftingState.tool) {
            DraftTool.NONE -> null
            DraftTool.DIM_LINEAR -> listOf("draft_hint_dim_first", "draft_hint_dim_second", "draft_hint_dim_place")[minOf(n, 2)]
            DraftTool.DIM_DIAMETER, DraftTool.DIM_RADIUS ->
                if (fitted != null || n >= 1) "draft_hint_dim_edge" else "draft_hint_dim_center"
            DraftTool.DIM_ANGLE ->
                listOf("draft_hint_angle_vertex", "draft_hint_angle_ray1", "draft_hint_angle_ray2", "draft_hint_angle_arc")[minOf(n, 3)]
        }
        DraftingState.toolHint = key?.let { L10n.t(it) }
    }

    fun reset(engine: InkEngine?) {
        picks.clear()
        fitted = null
        engine?.clearOverlay()
        refreshHint()
    }

    fun handle(phase: FfiPhase, x: Float, y: Float, engine: InkEngine) {
        val tool = DraftingState.tool
        if (!tool.isDimension) return
        if (lastTool != tool) {
            lastTool = tool
            reset(engine)
        }
        if (phase == FfiPhase.CANCELLED) {
            engine.setOverlay(emptyList(), picks.toList())
            return
        }
        val radius = 14f / engine.toolZoom.coerceAtLeast(0.25f)
        val raw = InkEngine.Offset2(x, y)
        val snapped = engine.snapAnchor(x, y, radius) ?: raw
        when (tool) {
            DraftTool.DIM_LINEAR -> linear(phase, raw, snapped, engine)
            DraftTool.DIM_DIAMETER, DraftTool.DIM_RADIUS -> circular(tool, phase, raw, radius, engine)
            DraftTool.DIM_ANGLE -> angular(phase, raw, snapped, engine)
            DraftTool.NONE -> Unit
        }
    }

    private fun linear(phase: FfiPhase, raw: InkEngine.Offset2, snapped: InkEngine.Offset2, engine: InkEngine) {
        if (picks.size < 2) {
            if (phase != FfiPhase.ENDED) return
            picks.firstOrNull()?.let { if (kotlin.math.hypot(it.x - snapped.x, it.y - snapped.y) < 1f) return }
            picks += snapped
            engine.setOverlay(emptyList(), picks.toList())
            refreshHint()
            return
        }
        val dim = draftDimLinear(pt(picks[0]), pt(picks[1]), pt(raw), FfiDimAxis.AUTO, DraftingState.scaleRatio.toFloat())
        finishOrPreview(phase, dim, engine)
    }

    private fun circular(tool: DraftTool, phase: FfiPhase, raw: InkEngine.Offset2, radius: Float, engine: InkEngine) {
        if (picks.isEmpty()) {
            if (phase != FfiPhase.ENDED) return
            // 點在已經畫好的圓上：圓心與半徑直接取用，接下來只要拖出引線的方向。
            val c = engine.circleNear(raw.x, raw.y, radius * 1.5f)
            if (c != null) {
                fitted = c
                picks += c.first
            } else {
                fitted = null
                picks += raw
            }
            engine.setOverlay(emptyList(), picks.toList())
            refreshHint()
            return
        }
        val center = picks[0]
        val dx = raw.x - center.x
        val dy = raw.y - center.y
        val dist = kotlin.math.hypot(dx, dy)
        val r = fitted?.second ?: dist
        if (r <= 2f || dist <= 0.5f) {
            if (phase == FfiPhase.ENDED) reset(engine)
            return
        }
        val dir = FfiPoint(dx / dist, dy / dist)
        val ratio = DraftingState.scaleRatio.toFloat()
        val dim = if (tool == DraftTool.DIM_DIAMETER) draftDimDiameter(pt(center), r, dir, ratio)
        else draftDimRadius(pt(center), r, dir, ratio)
        finishOrPreview(phase, dim, engine)
    }

    private fun angular(phase: FfiPhase, raw: InkEngine.Offset2, snapped: InkEngine.Offset2, engine: InkEngine) {
        if (picks.size < 3) {
            if (phase != FfiPhase.ENDED) return
            picks.lastOrNull()?.let { if (kotlin.math.hypot(it.x - snapped.x, it.y - snapped.y) < 1f) return }
            picks += snapped
            engine.setOverlay(emptyList(), picks.toList())
            refreshHint()
            return
        }
        val arc = maxOf(20f, kotlin.math.hypot(raw.x - picks[0].x, raw.y - picks[0].y))
        finishOrPreview(phase, draftDimAngle(pt(picks[0]), pt(picks[1]), pt(picks[2]), arc), engine)
    }

    private fun finishOrPreview(phase: FfiPhase, dim: FfiDimension?, engine: InkEngine) {
        when (phase) {
            FfiPhase.BEGAN, FfiPhase.MOVED -> engine.setOverlay(dim?.strokes ?: emptyList(), picks.toList())
            FfiPhase.ENDED -> commit(dim, engine)
            else -> Unit
        }
    }

    private fun commit(dim: FfiDimension?, engine: InkEngine) {
        try {
            if (dim == null || dim.strokes.isEmpty()) return
            // 畫在頂層（細線筆）：標註是「答案」的一部分；圖層被鎖住就不畫。
            val top = dim.strokes.first().layer.toInt()
            if (DraftingState.isLocked(top)) return
            for (s in dim.strokes) DraftingState.ensureVisible(s.layer.toInt())
            engine.insertDrafted(dim.strokes, 0f, 0f)
            onChanged()
        } finally {
            reset(engine)
        }
    }
}

/**
 * 把一組製圖符號放在目前看得到的範圍正中央需要的偏移：包圍盒中心落在 (cx, cy)，再夾回頁面裡。
 * 回傳 (ox, oy, 寬, 高)；沒有任何點回 null。
 */
internal fun draftKitPlacement(kit: FfiDraftKit, cx: Float, cy: Float, pageW: Float, pageH: Float): FloatArray? {
    val pts = kit.strokes.flatMap { it.points }
    if (pts.isEmpty()) return null
    val minX = pts.minOf { it.x }
    val maxX = pts.maxOf { it.x }
    val minY = pts.minOf { it.y }
    val maxY = pts.maxOf { it.y }
    val w = maxX - minX
    val h = maxY - minY
    val left = (cx - w / 2f).coerceIn(0f, maxOf(0f, pageW - w))
    val top = (cy - h / 2f).coerceIn(0f, maxOf(0f, pageH - h))
    return floatArrayOf(left - minX, top - minY, w, h)
}

// ── 工具箱 ─────────────────────────────────────────────────────────────

/**
 * 「圖學工具」（對應 Apple 的 `DraftingToolbox`）：選尺寸標註的種類、設比例尺、進符號面板、插入圖框與標題欄。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun DraftingToolboxDialog(
    languageTag: String,
    frameSupported: Boolean,
    onPickTool: (DraftTool) -> Unit,
    onInsertSymbol: (FfiDraftKit) -> Unit,
    onInsertFrame: (thirdAngle: Boolean) -> Unit,
    onDismiss: () -> Unit
) {
    fun t(key: String) = LocalizationStrings.localized(key, languageTag)
    var symbols by remember { mutableStateOf(false) }
    var thirdAngle by remember { mutableStateOf(true) }
    @Suppress("UNUSED_EXPRESSION") DraftingState.version

    if (symbols) {
        DraftSymbolPickerDialog(
            languageTag = languageTag,
            onInsert = { onInsertSymbol(it) },
            onBack = { symbols = false }
        )
        return
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(t("draft_tools")) },
        confirmButton = {
            TextButton(onClick = onDismiss, modifier = Modifier.testTag("draft.toolbox.close")) { Text(t("cancel")) }
        },
        text = {
            Column(
                Modifier.heightIn(max = 460.dp).verticalScroll(rememberScrollState()).testTag("draft.toolbox"),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Text(t("draft_toolbox_dimension"), style = MaterialTheme.typography.labelLarge)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    for (tool in listOf(DraftTool.DIM_LINEAR, DraftTool.DIM_DIAMETER, DraftTool.DIM_RADIUS, DraftTool.DIM_ANGLE)) {
                        FilterChip(
                            selected = DraftingState.tool == tool,
                            onClick = { onPickTool(tool) },
                            label = { Text(t(tool.nameKey), fontSize = 12.sp) },
                            modifier = Modifier.testTag("draft.tool.${tool.name}")
                        )
                    }
                }
                Text(t("draft_scale"), style = MaterialTheme.typography.labelLarge)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    for (scale in draftScales()) {
                        FilterChip(
                            selected = kotlin.math.abs(DraftingState.scaleRatio - scale.ratio) < 1e-4,
                            onClick = { DraftingState.changeScaleRatio(scale.ratio.toDouble()) },
                            label = { Text(scale.label, fontSize = 12.sp) },
                            modifier = Modifier.testTag("draft.scale.${scale.label}")
                        )
                    }
                }
                Text(t("draft_scale_footer"), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                HorizontalDivider()
                FilterChip(
                    selected = false,
                    onClick = { symbols = true },
                    label = { Text("📐 " + t("draft_symbols"), fontSize = 13.sp) },
                    modifier = Modifier.testTag("draft.symbols")
                )
                HorizontalDivider()
                Text(t("draft_toolbox_frame"), style = MaterialTheme.typography.labelLarge)
                Row(
                    Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(t("draft_frame_third_angle"), fontSize = 13.sp, modifier = Modifier.weight(1f))
                    Switch(checked = thirdAngle, onCheckedChange = { thirdAngle = it }, modifier = Modifier.testTag("draft.frame.third"))
                }
                FilterChip(
                    selected = false,
                    enabled = frameSupported,
                    onClick = { onInsertFrame(thirdAngle) },
                    label = { Text(t("draft_frame_insert"), fontSize = 13.sp) },
                    modifier = Modifier.testTag("draft.frame.insert")
                )
                Text(
                    t(if (frameSupported) "draft_frame_footer" else "draft_frame_unsupported"),
                    fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    )
}

// ── 符號面板 ─────────────────────────────────────────────────────────────

private val SYMBOL_GROUPS = listOf("surface", "weld", "thread", "gdt", "mark", "fastener")

/**
 * 製圖符號（對應 Apple 的 `DraftSymbolPicker`）：每個符號的圖形由核心算，這裡只放參數的控制項與預覽；
 * 「放進頁面」把整組筆畫放到目前看得見的範圍正中央、套索選住。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun DraftSymbolPickerDialog(
    languageTag: String,
    onInsert: (FfiDraftKit) -> Unit,
    onBack: () -> Unit
) {
    fun t(key: String) = LocalizationStrings.localized(key, languageTag)
    val catalog = remember { draftSymbolCatalog() }
    var group by remember { mutableStateOf("surface") }
    var selectedId by remember { mutableStateOf("surface_basic") }
    var sizeMm by remember { mutableFloatStateOf(3.5f) }
    var text by remember { mutableStateOf("") }
    var rotation by remember { mutableFloatStateOf(0f) }
    var otherSide by remember { mutableStateOf(false) }
    var allAround by remember { mutableStateOf(false) }
    var field by remember { mutableStateOf(false) }
    var diameterZone by remember { mutableStateOf(false) }
    var datums by remember { mutableStateOf("") }
    var length by remember { mutableFloatStateOf(25f) }
    var mSize by remember { mutableFloatStateOf(6f) }
    val isFastener = group == "fastener"

    fun params() = FfiSymbolParams(
        sizeMm = if (isFastener) mSize else sizeMm, text = text, rotationDeg = rotation,
        otherSide = otherSide, allAround = allAround, field = field, diameter = diameterZone,
        datums = datums, lengthMm = length
    )

    fun kit(id: String): FfiDraftKit? = draftSymbol(id, FfiPoint(0f, 0f), params())

    @Composable
    fun LabeledSlider(title: String, value: Float, range: ClosedFloatingPointRange<Float>, tag: String,
                      fmt: String = "%.0f", onChange: (Float) -> Unit) {
        Column(Modifier.fillMaxWidth()) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(title, fontSize = 13.sp)
                Text(fmt.format(value), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Slider(value = value, onValueChange = onChange, valueRange = range, modifier = Modifier.testTag(tag))
        }
    }

    @Composable
    fun Toggle(title: String, value: Boolean, tag: String, onChange: (Boolean) -> Unit) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
            Text(title, fontSize = 13.sp)
            Switch(checked = value, onCheckedChange = onChange, modifier = Modifier.testTag(tag))
        }
    }

    AlertDialog(
        onDismissRequest = onBack,
        title = { Text(t("draft_symbols")) },
        dismissButton = { TextButton(onClick = onBack) { Text(t("cancel")) } },
        confirmButton = {
            TextButton(
                onClick = { kit(selectedId)?.let(onInsert) },
                modifier = Modifier.testTag("draft.symbol.place")
            ) { Text(t("draft_sym_place")) }
        },
        text = {
            Column(
                Modifier.heightIn(max = 460.dp).verticalScroll(rememberScrollState()).testTag("draft.symbols.dialog"),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    for (g in SYMBOL_GROUPS) {
                        FilterChip(
                            selected = group == g,
                            onClick = {
                                group = g
                                selectedId = catalog.first { it.group == g }.id
                            },
                            label = { Text(t("draft_sym_group_$g"), fontSize = 12.sp) },
                            modifier = Modifier.testTag("draft.symbols.group.$g")
                        )
                    }
                }
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    for (info in catalog.filter { it.group == group }) {
                        val selected = info.id == selectedId
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier
                                .size(width = 96.dp, height = 96.dp)
                                .clip(RoundedCornerShape(10.dp))
                                .background(
                                    if (selected) MaterialTheme.colorScheme.primary.copy(alpha = 0.16f)
                                    else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f)
                                )
                                .clickable { selectedId = info.id }
                                .padding(4.dp)
                                .testTag("draft.symbol.${info.id}")
                                .semantics {
                                    contentDescription = t(info.nameKey)
                                    if (selected) stateDescription = t("selected")
                                }
                        ) {
                            SymbolPreview(kit(info.id), Modifier.fillMaxWidth().height(60.dp))
                            Text(t(info.nameKey), fontSize = 10.sp, maxLines = 2)
                        }
                    }
                }
                HorizontalDivider()
                if (isFastener) {
                    Text(t("draft_sym_m_size"), style = MaterialTheme.typography.labelLarge)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        for (m in listOf(3, 4, 5, 6, 8, 10, 12, 16, 20, 24)) {
                            FilterChip(
                                selected = mSize == m.toFloat(), onClick = { mSize = m.toFloat() },
                                label = { Text("M$m", fontSize = 12.sp) },
                                modifier = Modifier.testTag("draft.symbol.m$m")
                            )
                        }
                    }
                    if (selectedId == "bolt_hex") {
                        LabeledSlider(t("draft_sym_length"), length, 6f..100f, "draft.symbol.length") { length = it }
                    }
                } else {
                    LabeledSlider(t("draft_sym_size"), sizeMm, 2.5f..8f, "draft.symbol.size", "%.1f") { sizeMm = it }
                    if (selectedId.startsWith("thread_") && selectedId.endsWith("_side")) {
                        LabeledSlider(t("draft_sym_length"), length, 6f..100f, "draft.symbol.length") { length = it }
                    }
                    if (selectedId != "center_mark") {
                        OutlinedTextField(
                            value = text, onValueChange = { text = it }, singleLine = true,
                            label = { Text(t("draft_sym_text")) }, placeholder = { Text(t("draft_sym_text_hint")) },
                            modifier = Modifier.fillMaxWidth().testTag("draft.symbol.text")
                        )
                    }
                    if (group == "weld") {
                        Toggle(t("draft_sym_other_side"), otherSide, "draft.symbol.otherSide") { otherSide = it }
                        Toggle(t("draft_sym_all_around"), allAround, "draft.symbol.allAround") { allAround = it }
                        Toggle(t("draft_sym_field"), field, "draft.symbol.field") { field = it }
                    }
                    if (group == "gdt" && selectedId != "datum_feature") {
                        Toggle(t("draft_sym_diameter_zone"), diameterZone, "draft.symbol.diameter") { diameterZone = it }
                        OutlinedTextField(
                            value = datums, onValueChange = { datums = it.uppercase().take(3) }, singleLine = true,
                            label = { Text(t("draft_sym_datums")) },
                            modifier = Modifier.fillMaxWidth().testTag("draft.symbol.datums")
                        )
                    }
                    LabeledSlider(t("draft_sym_rotation"), rotation, 0f..345f, "draft.symbol.rotation") {
                        rotation = (it / 15f).toInt() * 15f
                    }
                }
            }
        }
    )
}

/** 符號的預覽：把核心給的折線縮進格子裡畫出來（用文字色，深色模式也看得見）。 */
@Composable
fun SymbolPreview(kit: FfiDraftKit?, modifier: Modifier = Modifier) {
    val color = MaterialTheme.colorScheme.onSurface
    Canvas(modifier) {
        val k0 = kit ?: return@Canvas
        val pts = k0.strokes.flatMap { it.points }
        if (pts.isEmpty()) return@Canvas
        val minX = pts.minOf { it.x }
        val maxX = pts.maxOf { it.x }
        val minY = pts.minOf { it.y }
        val maxY = pts.maxOf { it.y }
        val w = maxOf(maxX - minX, 1f)
        val h = maxOf(maxY - minY, 1f)
        val k = minOf((size.width - 8f) / w, (size.height - 8f) / h)
        val ox = (size.width - w * k) / 2f - minX * k
        val oy = (size.height - h * k) / 2f - minY * k
        for (s in k0.strokes) {
            if (s.points.size < 2) continue
            val pattern = draftLinePattern(s.lineType).map { it * k }.toFloatArray()
            val effect = if (pattern.size >= 2) PathEffect.dashPathEffect(pattern, 0f) else null
            for (i in 1 until s.points.size) {
                val a = s.points[i - 1]
                val b = s.points[i]
                drawLine(
                    color, Offset(a.x * k + ox, a.y * k + oy), Offset(b.x * k + ox, b.y * k + oy),
                    strokeWidth = maxOf(0.8f, s.width * k * 0.9f), cap = StrokeCap.Round, pathEffect = effect
                )
            }
        }
    }
}
