package com.kairumo.padnote.ink

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.input.pointer.pointerInteropFilter
import androidx.compose.ui.platform.LocalDensity
import uniffi.padnote_core.StrokePoint
import uniffi.padnote_core.ToolKind

/**
 * 手寫畫布（工作包 WP5）。
 *
 * 用 `pointerInteropFilter` 拿到原始的 `MotionEvent` 而不是 Compose 的
 * 指標事件：Compose 的手勢層已經把歷史取樣點合併掉了，拿到的是「這一幀的
 * 位置」，快速書寫會變成折線。手寫必須走原始事件。
 */
@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun InkCanvas(
    engine: InkEngine,
    modifier: Modifier = Modifier,
    backgroundColor: Color = Color.White,
    inkColor: Color = Color.Black,
    /// 筆畫有變動時通知外層（例如更新「N 筆」的顯示）。
    onInkChanged: () -> Unit = {}
) {
    val density = LocalDensity.current.density
    // 筆畫存在 engine 裡（它才是真相來源）。這個計數器只是用來觸發重繪 ——
    // 把整份筆畫複製進 Compose state，一筆一次複製整個清單會很慢。
    var revision by remember { mutableIntStateOf(0) }
    var liveVersion by remember { mutableStateOf(0L) }

    Canvas(
        modifier = modifier
            .background(backgroundColor)
            .pointerInteropFilter { event ->
                val outcome = engine.onMotionEvent(event, density)
                if (outcome.drawnSamples > 0 || outcome.retracted.isNotEmpty() ||
                    outcome.completed.isNotEmpty()
                ) {
                    revision++
                    liveVersion = System.nanoTime()
                    onInkChanged()
                }
                // 手勢判定的事件要讓給外層（捲動、縮放）；其餘由畫布消化。
                outcome.gestureSamples == 0
            }
    ) {
        @Suppress("UNUSED_EXPRESSION") revision
        @Suppress("UNUSED_EXPRESSION") liveVersion

        for (stroke in engine.strokes) {
            drawInkStroke(stroke.points, stroke.tool, engine.baseWidth, inkColor, density)
        }
        // 尚未抬筆的那一段也要即時畫出來，否則寫字時要等抬筆才看得到。
        for (live in engine.liveSamples()) {
            drawInkStroke(
                InkInput.strokePoints(live), engine.tool, engine.baseWidth, inkColor, density)
        }
    }
}

/**
 * 畫一筆。
 *
 * 寬度用核心 `half_width()` 的同一條公式算：`base × (0.35 + 0.65 × pressure)`，
 * 且只有壓感筆種才隨壓力變化。兩個平台用同一條公式，同一筆畫看起來才一樣。
 */
private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawInkStroke(
    points: List<StrokePoint>,
    tool: ToolKind,
    baseWidth: Float,
    color: Color,
    density: Float
) {
    if (points.size < 2) return
    val pressureSensitive = tool == ToolKind.FOUNTAIN_PEN || tool == ToolKind.PENCIL

    // 逐段畫而不是一條 Path：寬度沿著筆畫變化，單一 Path 只能有一個寬度。
    for (i in 1 until points.size) {
        val a = points[i - 1]
        val b = points[i]
        val pressure = if (pressureSensitive) b.pressure.coerceIn(0f, 1f) else 1f
        val width = baseWidth * (if (pressureSensitive) 0.35f + 0.65f * pressure else 1f)
        drawLine(
            color = color,
            start = Offset(a.x * density, a.y * density),
            end = Offset(b.x * density, b.y * density),
            strokeWidth = width * density,
            cap = StrokeCap.Round
        )
    }
    // StrokeJoin 只在 Path 上有意義；逐段畫時用 Round cap 讓轉折不出現缺口。
    @Suppress("UNUSED_EXPRESSION") StrokeJoin.Round
}

/**
 * 低延遲畫布：把 [InkSurfaceView] 包成 Compose 元件。
 *
 * 建不起來（OEM 不支援前緩衝）時呼叫 [onUnavailable]，由上層退回一般畫布。
 * 手寫可以比較鈍，但不能不能用。
 */
@Composable
fun LowLatencyInkCanvas(
    engine: InkEngine,
    latency: InkLatencyMeter,
    modifier: Modifier = Modifier,
    onInkChanged: () -> Unit = {},
    onUnavailable: () -> Unit = {},
    /// 外層改變這個值就會清空畫面（按下「清除」時遞增）。
    clearToken: Int = 0
) {
    val density = LocalDensity.current.density
    androidx.compose.ui.viewinterop.AndroidView(
        modifier = modifier,
        factory = { context ->
            InkSurfaceView(context, engine, latency, density, onInkChanged).also { view ->
                if (!view.start()) onUnavailable()
            }
        },
        update = { view -> if (clearToken > 0 && engine.strokes.isEmpty()) view.clearAll() },
        onRelease = { it.stop() }
    )
}
