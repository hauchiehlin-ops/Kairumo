package com.kairumo.padnote.ink

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
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
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import uniffi.padnote_core.FfiGlassKind
import uniffi.padnote_core.FfiSolidProfile
import uniffi.padnote_core.solidGlassBounds
import uniffi.padnote_core.solidGlassFrame

/** 玻璃盒展開的狀態：進度、播放、投影法、觀看角度（對應 Apple 的 `SolidStudioSheet` 的 glass 狀態）。 */
class GlassState {
    var t by mutableFloatStateOf(0f)
    var playing by mutableStateOf(false)
    var third by mutableStateOf(true)
    var yaw by mutableFloatStateOf(30f)
    var pitch by mutableFloatStateOf(25f)

    /** 整段動畫的畫面範圍只算一次（輪廓、深度、視角、投影法變了才重算）。 */
    private var boundsKey = ""
    private var bounds: List<Float> = emptyList()

    fun boundsFor(profile: FfiSolidProfile, depth: Float): List<Float> {
        val key = "${profile.outer.size}-${profile.width}-${profile.height}-$depth-$third-${yaw.toInt()}-${pitch.toInt()}"
        if (key != boundsKey) {
            bounds = solidGlassBounds(profile, depth, third, yaw, pitch) ?: emptyList()
            boundsKey = key
        }
        return bounds
    }
}

/** 玻璃盒預覽：把立體放在玻璃盒裡，三個視圖掀開攤平。拖曳轉動觀看的角度。 */
@Composable
fun GlassBoxPreview(state: GlassState, profile: FfiSolidProfile?, depth: Float, modifier: Modifier = Modifier) {
    // 播放：每 1/30 秒往前走一格（約 4 秒展開完）；走到 1 就停。
    LaunchedEffect(state.playing) {
        while (state.playing) {
            delay(33)
            state.t = (state.t + 1f / 30f / 4f).coerceAtMost(1f)
            if (state.t >= 1f) state.playing = false
        }
    }
    Canvas(
        modifier.fillMaxWidth().height(220.dp).background(Color.White).border(1.dp, Color(0x33000000))
            .pointerInput(Unit) {
                detectDragGestures { _, drag ->
                    state.yaw = (state.yaw + drag.x * 0.5f).coerceIn(-180f, 180f)
                    state.pitch = (state.pitch - drag.y * 0.5f).coerceIn(-90f, 90f)
                }
            }
            .testTag("solid.preview")
    ) {
        val p = profile ?: return@Canvas
        val r = state.boundsFor(p, depth)
        val frame = solidGlassFrame(p, depth, state.third, state.t, state.yaw, state.pitch) ?: return@Canvas
        if (r.size != 4) return@Canvas
        val pad = 12.dp.toPx()
        val bw = (r[2] - r[0]).coerceAtLeast(1f)
        val bh = (r[3] - r[1]).coerceAtLeast(1f)
        // 範圍再留 6% 的邊：中間幾格可能比取樣的邊界稍微超出一點。
        val k = minOf((size.width - pad * 2) / bw, (size.height - pad * 2) / bh) * 0.94f
        val ox = size.width / 2 - (r[0] + bw / 2) * k
        val oy = size.height / 2 + (r[1] + bh / 2) * k
        fun map(x: Float, y: Float) = Offset(ox + x * k, oy - y * k)
        val fade = (1f - state.t * 3f).coerceAtLeast(0f)
        // 由底到頂：投射線、面框、立體、隱藏線、實線。
        for (kind in listOf(FfiGlassKind.PROJECTION, FfiGlassKind.FRAME, FfiGlassKind.OBJECT, FfiGlassKind.HIDDEN, FfiGlassKind.VISIBLE)) {
            if (kind == FfiGlassKind.PROJECTION && fade <= 0.01f) continue
            for (l in frame.lines) {
                if (l.kind != kind) continue
                val a = map(l.ax, l.ay)
                val b = map(l.bx, l.by)
                when (kind) {
                    FfiGlassKind.PROJECTION -> drawLine(
                        Color(0xFF2563EB).copy(alpha = 0.35f * fade), a, b, strokeWidth = 0.8.dp.toPx(),
                        pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 6f)))
                    FfiGlassKind.FRAME -> drawLine(Color(0xCC14B8A6), a, b, strokeWidth = 1.2.dp.toPx())
                    FfiGlassKind.OBJECT -> drawLine(Color(0x8C808080), a, b, strokeWidth = 1.dp.toPx())
                    FfiGlassKind.HIDDEN -> drawLine(
                        Color(0xB3000000), a, b, strokeWidth = 1.dp.toPx(),
                        pathEffect = PathEffect.dashPathEffect(floatArrayOf(8f, 6f)))
                    FfiGlassKind.VISIBLE -> drawLine(
                        Color.Black, a, b, strokeWidth = 2.dp.toPx(), cap = androidx.compose.ui.graphics.StrokeCap.Round)
                }
            }
        }
    }
}

/** 玻璃盒的控制：播放／暫停／重播、投影法、進度、觀看角度。 */
@Composable
fun GlassBoxControls(state: GlassState, t: (String) -> String) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(t("solid_glass_hint"), fontSize = 12.sp)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
            FilterChip(
                selected = state.playing,
                onClick = {
                    if (state.t >= 1f) state.t = 0f
                    state.playing = !state.playing
                },
                label = {
                    Text(
                        if (state.playing) "⏸ " + t("solid_glass_pause")
                        else if (state.t >= 1f) "↻ " + t("solid_glass_replay") else "▶ " + t("solid_glass_play"),
                        fontSize = 12.sp)
                },
                modifier = Modifier.testTag("solid.glass.play")
            )
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(t("solid_first_angle"), fontSize = 12.sp)
                Switch(checked = !state.third, onCheckedChange = { state.third = !it }, modifier = Modifier.testTag("solid.glass.first"))
            }
        }
        GlassSlider(t("solid_glass_progress"), state.t, 0f..1f, "solid.glass.t", { "%.2f".format(it) }) {
            state.t = it
            state.playing = false
        }
        GlassSlider(t("solid_yaw"), state.yaw, -180f..180f, "solid.glass.yaw", { "%.0f°".format(it) }) { state.yaw = it }
        GlassSlider(t("solid_pitch"), state.pitch, -90f..90f, "solid.glass.pitch", { "%.0f°".format(it) }) { state.pitch = it }
    }
}

@Composable
private fun GlassSlider(
    title: String, value: Float, range: ClosedFloatingPointRange<Float>, tag: String, fmt: (Float) -> String,
    onChange: (Float) -> Unit
) {
    Column(Modifier.fillMaxWidth()) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(title, fontSize = 13.sp)
            Text(fmt(value), fontSize = 12.sp)
        }
        Slider(value = value, onValueChange = onChange, valueRange = range, modifier = Modifier.testTag(tag))
    }
}
