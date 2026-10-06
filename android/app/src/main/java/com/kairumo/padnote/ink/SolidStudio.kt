package com.kairumo.padnote.ink

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.LocalizationStrings
import uniffi.padnote_core.FfiPoint
import uniffi.padnote_core.FfiSectionKind
import uniffi.padnote_core.FfiSheetStroke
import uniffi.padnote_core.FfiSolidProfile
import uniffi.padnote_core.FfiSolidSection
import uniffi.padnote_core.FfiSolidSheet
import uniffi.padnote_core.FfiSolidSheetOptions
import uniffi.padnote_core.draftLinePattern
import uniffi.padnote_core.solidComposeSheet
import uniffi.padnote_core.solidPresetProfile
import uniffi.padnote_core.solidPresets
import uniffi.padnote_core.solidProfileFromStrokes
import uniffi.padnote_core.solidView

/**
 * 立體輔助（對應 Apple 的 `SolidStudioSheet`）：草圖拉伸 → 三視圖／等角圖／剖面，插進頁面；
 * 或旋轉立體對照。幾何全在核心，預覽畫的就是插入時寫進頁面的那組線。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun SolidStudioDialog(
    languageTag: String,
    pageWidth: Float,
    pageHeight: Float,
    sketchPolylines: () -> List<List<FfiPoint>>,
    onInsert: (FfiSolidSheet) -> Unit,
    onDismiss: () -> Unit
) {
    fun t(key: String) = LocalizationStrings.localized(key, languageTag)

    // 0 = 圖紙、1 = 旋轉對照、2 = 玻璃盒展開。
    var tab by remember { mutableStateOf(0) }
    val rotate = tab == 1
    val glass = remember { GlassState() }
    val context = androidx.compose.ui.platform.LocalContext.current
    var exportNotice by remember { mutableStateOf<String?>(null) }
    var presetId by remember { mutableStateOf("u_shape") }
    var width by remember { mutableFloatStateOf(240f) }
    var height by remember { mutableFloatStateOf(180f) }
    var depth by remember { mutableFloatStateOf(140f) }
    var sketchProfile by remember { mutableStateOf<FfiSolidProfile?>(null) }
    var notice by remember { mutableStateOf<String?>(null) }

    var kind by remember { mutableStateOf(FfiSectionKind.NONE) }
    var angle by remember { mutableFloatStateOf(90f) }
    var offset by remember { mutableFloatStateOf(0.5f) }
    var offset2 by remember { mutableFloatStateOf(0.7f) }
    var step by remember { mutableFloatStateOf(0.5f) }
    var delta by remember { mutableFloatStateOf(30f) }
    var flip by remember { mutableStateOf(true) }
    var depthFrac by remember { mutableFloatStateOf(0.5f) }
    var tilt by remember { mutableFloatStateOf(40f) }

    var firstAngle by remember { mutableStateOf(false) }
    var includeIso by remember { mutableStateOf(true) }
    var projection by remember { mutableStateOf(true) }
    var centerLines by remember { mutableStateOf(true) }
    var dimensions by remember { mutableStateOf(false) }
    var sectionLabel by remember { mutableStateOf(false) }

    var yaw by remember { mutableFloatStateOf(35f) }
    var pitch by remember { mutableFloatStateOf(25f) }

    val profile: FfiSolidProfile? =
        sketchProfile ?: solidPresetProfile(presetId, width, height)
    val pageFitW = (pageWidth * 0.8f).coerceAtLeast(200f)
    val pageFitH = (pageHeight * 0.5f).coerceAtLeast(200f)

    fun options(fitW: Float, fitH: Float, ratio: Float) = FfiSolidSheetOptions(
        firstAngle = firstAngle,
        includeIso = includeIso,
        projectionLines = projection,
        centerLines = centerLines,
        section = FfiSolidSection(
            kind = kind, angleDeg = angle, offset = offset, offset2 = offset2, step = step,
            pivotX = 0.5f, pivotY = 0.5f, deltaDeg = delta, flip = flip, depthFrac = depthFrac,
            tiltDeg = tilt
        ),
        fitWidth = fitW,
        fitHeight = fitH,
        hatchSpacing = 6f * ratio,
        dimensions = dimensions,
        sectionLabel = sectionLabel
    )

    @Composable
    fun LabeledSlider(
        title: String, value: Float, range: ClosedFloatingPointRange<Float>, tag: String,
        fmt: (Float) -> String = { "%.0f".format(it) }, onChange: (Float) -> Unit
    ) {
        Column(Modifier.fillMaxWidth()) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(title, fontSize = 13.sp)
                Text(fmt(value), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Slider(value = value, onValueChange = onChange, valueRange = range, modifier = Modifier.testTag(tag))
        }
    }

    @Composable
    fun Toggle(title: String, value: Boolean, tag: String, onChange: (Boolean) -> Unit) {
        Row(
            Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(title, fontSize = 13.sp)
            Switch(checked = value, onCheckedChange = onChange, modifier = Modifier.testTag(tag))
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(t("solid_studio")) },
        confirmButton = {
            TextButton(
                enabled = profile != null,
                onClick = {
                    val p = profile ?: return@TextButton
                    solidComposeSheet(p, depth, options(pageFitW, pageFitH, 1f))?.let(onInsert)
                },
                modifier = Modifier.testTag("solid.insert")
            ) { Text(t("solid_insert")) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(t("cancel")) } },
        text = {
            // 標籤與預覽固定在上面，設定在下面捲 —— 拉滑桿時要看得到圖怎麼變。
            Column(Modifier.testTag("solid.dialog"), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(
                        selected = tab == 0, onClick = { tab = 0 },
                        label = { Text(t("solid_tab_sheet")) }, modifier = Modifier.testTag("solid.tab.sheet")
                    )
                    FilterChip(
                        selected = tab == 1, onClick = { tab = 1 },
                        label = { Text(t("solid_tab_rotate")) }, modifier = Modifier.testTag("solid.tab.rotate")
                    )
                    FilterChip(
                        selected = tab == 2, onClick = { tab = 2 },
                        label = { Text(t("solid_tab_glass")) }, modifier = Modifier.testTag("solid.tab.glass")
                    )
                }

                // ── 預覽 ──
                if (tab == 2) GlassBoxPreview(glass, profile, depth)
                if (tab != 2) Canvas(
                    Modifier.fillMaxWidth().height(220.dp).background(Color.White)
                        .border(1.dp, Color(0x33000000)).testTag("solid.preview")
                ) {
                    val pad = 12.dp.toPx()
                    val fitW = size.width - pad * 2
                    val fitH = size.height - pad * 2
                    val p = profile ?: return@Canvas
                    if (fitW < 40f || fitH < 40f) return@Canvas
                    if (!rotate) {
                        val ratio = fitW / pageFitW / density
                        val sheet = solidComposeSheet(p, depth, options(fitW / density, fitH / density, ratio))
                            ?: return@Canvas
                        val ox = pad + (fitW - sheet.width * density) / 2
                        val oy = pad + (fitH - sheet.height * density) / 2
                        for (s in sheet.strokes.sortedBy { it.layer }) {
                            drawSheetStroke(s, ox, oy, density, ratio)
                        }
                    } else {
                        val view = solidView(p, depth, yaw, pitch, fitW, fitH) ?: return@Canvas
                        val ox = pad + (fitW - view.width) / 2
                        val oy = pad + (fitH - view.height) / 2
                        for (l in view.lines) {
                            drawLine(
                                Color.Black, Offset(ox + l.ax, oy + l.ay), Offset(ox + l.bx, oy + l.by),
                                strokeWidth = if (l.hidden) 1.dp.toPx() else 2.dp.toPx(),
                                pathEffect = if (l.hidden) PathEffect.dashPathEffect(floatArrayOf(10f, 8f)) else null
                            )
                        }
                    }
                }

                Column(
                    Modifier.heightIn(max = 360.dp).verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                // 玻璃盒的播放與進度放在最上面：拉滑桿、看動畫要同時看得到預覽與控制。
                if (tab == 2) GlassBoxControls(glass, ::t)
                // ── 輪廓 ──
                Text(t("solid_profile"), style = MaterialTheme.typography.labelLarge)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    for (id in solidPresets()) {
                        FilterChip(
                            selected = sketchProfile == null && presetId == id,
                            onClick = { presetId = id; sketchProfile = null; notice = null },
                            label = { Text(t("solid_preset_$id"), fontSize = 12.sp) },
                            modifier = Modifier.testTag("solid.preset.$id")
                        )
                    }
                }
                FilterChip(
                    selected = sketchProfile != null,
                    onClick = {
                        val found = solidProfileFromStrokes(sketchPolylines())
                        if (found != null) {
                            sketchProfile = found
                            notice = t("solid_sketch_used")
                        } else {
                            notice = t("solid_sketch_none")
                        }
                    },
                    label = { Text("✏️ " + t("solid_from_sketch"), fontSize = 12.sp) },
                    modifier = Modifier.testTag("solid.fromSketch")
                )
                notice?.let {
                    Text(it, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                if (sketchProfile == null) {
                    LabeledSlider(t("solid_width"), width, 60f..600f, "solid.width") { width = it }
                    LabeledSlider(t("solid_height"), height, 60f..600f, "solid.height") { height = it }
                }
                LabeledSlider(t("solid_depth"), depth, 20f..600f, "solid.depth") { depth = it }

                if (tab == 2) {
                    // 控制已經放在最上面。
                } else if (!rotate) {
                    // ── 剖面 ──
                    Text(t("solid_section"), style = MaterialTheme.typography.labelLarge)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        for ((k, key) in listOf(
                            FfiSectionKind.NONE to "solid_section_none",
                            FfiSectionKind.FULL to "solid_section_full",
                            FfiSectionKind.STEPPED to "solid_section_stepped",
                            FfiSectionKind.ROTATED to "solid_section_rotated",
                            FfiSectionKind.PARALLEL to "solid_section_parallel",
                            FfiSectionKind.OBLIQUE to "solid_section_oblique"
                        )) {
                            FilterChip(
                                selected = kind == k, onClick = { kind = k },
                                label = { Text(t(key), fontSize = 12.sp) },
                                modifier = Modifier.testTag("solid.section.$k")
                            )
                        }
                    }
                    val deg = { v: Float -> "%.0f°".format(v) }
                    val two = { v: Float -> "%.2f".format(v) }
                    when (kind) {
                        FfiSectionKind.NONE -> Unit
                        FfiSectionKind.FULL -> {
                            LabeledSlider(t("solid_angle"), angle, 0f..180f, "solid.angle", deg) { angle = it }
                            LabeledSlider(t("solid_offset"), offset, 0f..1f, "solid.offset", two) { offset = it }
                            Toggle(t("solid_flip"), flip, "solid.flip") { flip = it }
                        }
                        FfiSectionKind.STEPPED -> {
                            LabeledSlider(t("solid_angle"), angle, 0f..180f, "solid.angle", deg) { angle = it }
                            LabeledSlider(t("solid_offset"), offset, 0f..1f, "solid.offset", two) { offset = it }
                            LabeledSlider(t("solid_offset2"), offset2, 0f..1f, "solid.offset2", two) { offset2 = it }
                            LabeledSlider(t("solid_step"), step, 0f..1f, "solid.step", two) { step = it }
                            Toggle(t("solid_flip"), flip, "solid.flip") { flip = it }
                        }
                        FfiSectionKind.ROTATED -> {
                            LabeledSlider(t("solid_angle"), angle, 0f..180f, "solid.angle", deg) { angle = it }
                            LabeledSlider(t("solid_delta"), delta, -80f..80f, "solid.delta", deg) { delta = it }
                            Toggle(t("solid_flip"), flip, "solid.flip") { flip = it }
                        }
                        FfiSectionKind.PARALLEL ->
                            LabeledSlider(t("solid_depth_pos"), depthFrac, 0f..1f, "solid.depthFrac", two) { depthFrac = it }
                        FfiSectionKind.OBLIQUE -> {
                            LabeledSlider(t("solid_angle"), angle, 0f..180f, "solid.angle", deg) { angle = it }
                            LabeledSlider(t("solid_offset"), offset, 0f..1f, "solid.offset", two) { offset = it }
                            LabeledSlider(t("solid_tilt"), tilt, 5f..85f, "solid.tilt", deg) { tilt = it }
                            Toggle(t("solid_flip"), flip, "solid.flip") { flip = it }
                        }
                    }
                    Toggle(t("solid_first_angle"), firstAngle, "solid.firstAngle") { firstAngle = it }
                    Toggle(t("solid_iso"), includeIso, "solid.iso") { includeIso = it }
                    Toggle(t("solid_projection"), projection, "solid.projection") { projection = it }
                    Toggle(t("solid_centerlines"), centerLines, "solid.centerlines") { centerLines = it }
                    Toggle(t("solid_dimensions"), dimensions, "solid.dimensions") { dimensions = it }
                    if (kind != FfiSectionKind.NONE) {
                        Toggle(t("solid_section_label"), sectionLabel, "solid.sectionLabel") { sectionLabel = it }
                    }
                } else {
                    val deg = { v: Float -> "%.0f°".format(v) }
                    LabeledSlider(t("solid_yaw"), yaw, -180f..180f, "solid.yaw", deg) { yaw = it }
                    LabeledSlider(t("solid_pitch"), pitch, -90f..90f, "solid.pitch", deg) { pitch = it }
                }
                SolidExportSection(
                    t = ::t, enabled = profile != null, notice = exportNotice,
                    onExport = { format ->
                        val p = profile
                        exportNotice = if (p != null && DraftingExport.shareSolid(context, p, depth, format)) null else t("solid_export_failed")
                    }
                )
                }
            }
        }
    )
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawSheetStroke(
    s: FfiSheetStroke, ox: Float, oy: Float, dens: Float, widthScale: Float
) {
    if (s.points.size < 2) return
    val color = DraftingState.parseHex(s.colorHex)
    val pattern = draftLinePattern(s.lineType).map { it * widthScale * dens }.toFloatArray()
    val effect = if (pattern.size >= 2) PathEffect.dashPathEffect(pattern, 0f) else null
    for (i in 1 until s.points.size) {
        val a = s.points[i - 1]
        val b = s.points[i]
        drawLine(
            color,
            Offset(ox + a.x * dens, oy + a.y * dens),
            Offset(ox + b.x * dens, oy + b.y * dens),
            strokeWidth = kotlin.math.max(0.8f, s.width * widthScale * dens * 1.1f),
            pathEffect = effect
        )
    }
}


/** 3D 匯出：STL、OBJ、GLB、USDZ（頂層函式：避免把對話框的 lambda 撐得更大）。 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun SolidExportSection(t: (String) -> String, enabled: Boolean, notice: String?, onExport: (String) -> Unit) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(t("solid_export_title"), style = MaterialTheme.typography.labelLarge)
        FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            for (format in uniffi.padnote_core.solidExportFormats()) {
                FilterChip(
                    selected = false, enabled = enabled, onClick = { onExport(format) },
                    label = { Text(t("solid_export_$format"), fontSize = 12.sp) },
                    modifier = Modifier.testTag("solid.export.$format")
                )
            }
        }
        notice?.let { Text(it, fontSize = 12.sp, color = MaterialTheme.colorScheme.error) }
        Text(t("solid_export_footer"), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
