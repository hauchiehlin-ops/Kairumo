package com.kairumo.padnote.ink

import android.view.MotionEvent
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import com.kairumo.padnote.canvas.drawPageBackground
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.PointerType
import androidx.compose.ui.input.pointer.pointerInput
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
    /**
     * 紙張底紋。畫在白底之上、筆跡之下。
     *
     * 疊一層 Composable 在 `InkCanvas` **外面**是行不通的 —— 這裡用
     * `.background(Color.White)` 把整塊塗掉，外層畫的底紋會整個不見。
     */
    pageStyle: uniffi.padnote_core.PageStyle = uniffi.padnote_core.PageStyle.BLANK,
    /**
     * 這張紙的識別字。版面（康乃爾的三區、四象限的十字）跟著它走 ——
     * `pageStyle` 只有六種底紋，分不出三十幾種紙。
     */
    paperId: String = "",
    /** 版面上的欄位標題要翻譯；沒有它的話畫出來的是一串語系鍵。 */
    localizeGuide: (String) -> String = { it },
    guideMeasurer: androidx.compose.ui.text.TextMeasurer? = null,
    /** 版面配色。整本一個。 */
    guidePaletteId: String = "",
    inkColor: Color = Color.Black,
    /// 筆畫有變動時通知外層（例如更新「N 筆」的顯示）。
    onInkChanged: () -> Unit = {},
    /** 當處於「僅限觸控筆」等模式下手指被手勢或掌拒攔截時的回呼。 */
    onFingerIgnored: () -> Unit = {},
    /**
     * 外部改動了 engine 裡的筆畫（讀檔、草圖美化、清除）時 +1。
     *
     * 畫布平常只在收到觸控事件時重畫 —— 沒有這個參數的話，
     * 「從檔案讀回來的筆畫」要等使用者下一次碰畫布才會出現。
     */
    contentVersion: Int = 0,
    /**
     * 這個模式下畫布接不接受筆畫。
     *
     * 打字模式要的是「**誰都不能畫**」—— 掌拒的 pen-only 擋得掉手指，
     * 擋不掉觸控筆。少了這道開關，使用者切到打字模式後拿筆一碰畫布
     * 還是在畫線，而畫面上沒有任何東西告訴他模式換了。
     * 與 Apple 端關掉 `drawingGestureRecognizer` 是同一件事。
     */
    acceptsInk: Boolean = true
) {
    val density = LocalDensity.current.density
    // 筆畫存在 engine 裡（它才是真相來源）。這個計數器只是用來觸發重繪 ——
    // 把整份筆畫複製進 Compose state，一筆一次複製整個清單會很慢。
    var revision by remember { mutableIntStateOf(0) }
    var liveVersion by remember { mutableStateOf(0L) }

    // 懸停預覽（工作項 S-69）：筆尖靠近但還沒碰到時，先畫出會落在哪裡。
    //
    // 核心的仲裁器早就有 `Verdict.HOVER`，說明寫著「顯示落筆預覽」——
    // 在這之前沒有任何地方真的畫過那個預覽，硬體回報了、判定分類了，
    // 然後結果被丟掉。
    //
    // 不知道筆尖會落在哪，使用者只能先點一下看看 —— 而一筆下去才發現位置
    // 不對，那一筆已經在紙上了。
    var hoverPoint by remember { mutableStateOf<Offset?>(null) }

    Canvas(
        modifier = modifier
            .background(backgroundColor)
            .pointerInput(acceptsInk) {
                awaitPointerEventScope {
                    while (true) {
                        val event = awaitPointerEvent(PointerEventPass.Initial)
                        val change = event.changes.firstOrNull()
                        hoverPoint = when {
                            !acceptsInk -> null
                            // 只有筆才預覽。手指懸停在 Android 上是存在的事件
                            // （某些裝置支援），但手指沒有「還沒碰到」的概念
                            // —— 畫一個筆頭只會讓人以為畫布壞了。
                            change?.type != PointerType.Stylus -> null
                            event.type == PointerEventType.Exit -> null
                            // 已經碰到螢幕了就不是懸停。此時預覽會疊在真正的
                            // 筆跡上，變成一個跟著筆尖跑的灰圈。
                            change.pressed -> null
                            event.type == PointerEventType.Enter ||
                                event.type == PointerEventType.Move -> change.position
                            else -> hoverPoint
                        }
                    }
                }
            }
            .pointerInteropFilter { event ->
                // 不收筆畫時把事件原樣讓出去，外層照常捲動與選取。
                if (!acceptsInk) return@pointerInteropFilter false
                val outcome = engine.onMotionEvent(event, density)
                revision++
                liveVersion = System.nanoTime()
                // 每個事件都通知：被「拒絕」的那些才是需要診斷的，
                // 只在畫得出東西時回報，等於看不到問題發生的那一刻。
                onInkChanged()
                if (outcome.gestureSamples > 0 && event.getToolType(0) == MotionEvent.TOOL_TYPE_FINGER) {
                    onFingerIgnored()
                }
                // 手勢判定的事件要讓給外層（捲動、縮放）；其餘由畫布消化。
                outcome.gestureSamples == 0
            }
    ) {
        @Suppress("UNUSED_EXPRESSION") revision
        @Suppress("UNUSED_EXPRESSION") contentVersion
        @Suppress("UNUSED_EXPRESSION") liveVersion

        // 底紋先畫 —— 先畫的先被蓋住，筆跡要在它上面。
        drawPageBackground(
            pageStyle, density,
            paperId = paperId,
            localize = localizeGuide,
            textMeasurer = guideMeasurer,
            paletteId = guidePaletteId
        )

        drawPageBoundary(density)

        for (stroke in engine.strokes) {
            val strokeColor = if (stroke.colorRgba.size >= 4) {
                Color(
                    (stroke.colorRgba[0].toInt() and 0xFF) / 255f,
                    (stroke.colorRgba[1].toInt() and 0xFF) / 255f,
                    (stroke.colorRgba[2].toInt() and 0xFF) / 255f,
                    (stroke.colorRgba[3].toInt() and 0xFF) / 255f
                )
            } else inkColor
            drawInkStroke(stroke.points, stroke.tool, stroke.baseWidth, strokeColor, density)
        }
        // 尚未抬筆的那一段也要即時畫出來，否則寫字時要等抬筆才看得到。
        for (live in engine.liveSamples()) {
            drawInkStroke(
                InkInput.strokePoints(live), engine.tool, engine.baseWidth, inkColor, density)
        }

        // 懸停預覽畫在最上層：被墨跡蓋住就失去意義了。
        hoverPoint?.let { point ->
            drawHoverPreview(point, engine.baseWidth, engine.isErasing, inkColor, density)
        }
    }
}

/**
 * 懸停時的筆頭預覽。
 *
 * **只描邊、不填滿**：填滿的預覽會把它自己要對齊的那個字蓋住，而對齊正是
 * 使用者需要它的唯一原因。
 *
 * 橡皮擦畫得比筆粗：擦除半徑本來就比畫出來的粗細大（`baseWidth * 1.5`，
 * 見 `InkEngine.eraseAt`），預覽照筆的粗細畫的話，使用者會擦掉比他預期
 * 更多的東西。
 *
 * **沒有畫傾角。** Apple 那一側會照筆桿角度把筆頭壓扁，這裡沒有 ——
 * Compose 的懸停事件拿不到 tilt，要拿得繞進內部 API。差別只在扁頭筆的
 * 預覽是圓的而不是橢圓的，落點本身是一樣的。
 */
private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawHoverPreview(
    point: Offset,
    baseWidth: Float,
    erasing: Boolean,
    inkColor: Color,
    density: Float
) {
    // 太小的筆頭在螢幕上看不見，太大的會擋住正要對齊的地方。
    val radius = (if (erasing) baseWidth * 1.5f else baseWidth)
        .coerceIn(4f, 40f) * density / 2f
    drawCircle(
        color = if (erasing) Color(0x88000000) else inkColor.copy(alpha = 0.55f),
        radius = radius,
        center = point,
        style = androidx.compose.ui.graphics.drawscope.Stroke(width = 1.5f * density)
    )
}

/**
 * 畫出頁面與可列印區的界線。
 *
 * 與 Apple 端畫的是同一組矩形（尺寸來自核心）。使用者要看得到「這一頁到哪裡
 * 為止」，而且那條線必須**就是**匯出與列印的邊界 —— 畫一條僅供參考的框線，
 * 比不畫還糟：他會相信它。
 */
private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawPageBoundary(density: Float) {
    val w = PageGeometry.width * density
    val h = PageGeometry.height * density
    val inset = PageGeometry.PRINTABLE_INSET * density

    drawRect(
        color = Color(0x33000000),
        topLeft = Offset(0f, 0f),
        size = androidx.compose.ui.geometry.Size(w, h),
        style = androidx.compose.ui.graphics.drawscope.Stroke(width = 1f * density)
    )
    drawRect(
        color = Color(0x22000000),
        topLeft = Offset(inset, inset),
        size = androidx.compose.ui.geometry.Size(w - inset * 2, h - inset * 2),
        style = androidx.compose.ui.graphics.drawscope.Stroke(
            width = 1f * density,
            pathEffect = androidx.compose.ui.graphics.PathEffect.dashPathEffect(
                floatArrayOf(6f * density, 5f * density), 0f
            )
        )
    )
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
    val pressureSensitive = when (tool) {
        ToolKind.FOUNTAIN_PEN, ToolKind.PENCIL, ToolKind.BRUSH, ToolKind.WATERCOLOR -> true
        ToolKind.BALL_POINT, ToolKind.HIGHLIGHTER, ToolKind.MARKER -> false
    }
    val toolColor = when (tool) {
        ToolKind.HIGHLIGHTER -> color.copy(alpha = 0.35f)
        ToolKind.WATERCOLOR -> color.copy(alpha = 0.55f)
        ToolKind.MARKER -> color.copy(alpha = 0.85f)
        ToolKind.PENCIL -> color.copy(alpha = 0.85f)
        else -> color
    }
    val toolWidthMultiplier = when (tool) {
        ToolKind.BRUSH -> 2.2f
        ToolKind.MARKER -> 2.8f
        ToolKind.HIGHLIGHTER -> 3.8f
        ToolKind.PENCIL -> 1.3f
        ToolKind.WATERCOLOR -> 2.4f
        ToolKind.BALL_POINT -> 0.65f
        ToolKind.FOUNTAIN_PEN -> 1.1f
    }
    val effectiveBaseWidth = baseWidth * toolWidthMultiplier

    // 逐段畫而不是一條 Path：寬度沿著筆畫變化，單一 Path 只能有一個寬度。
    for (i in 1 until points.size) {
        val a = points[i - 1]
        val b = points[i]
        val pressure = if (pressureSensitive) b.pressure.coerceIn(0f, 1f) else 1f
        val width = effectiveBaseWidth * (if (pressureSensitive) 0.35f + 0.65f * pressure else 1f)
        drawLine(
            color = toolColor,
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
    clearToken: Int = 0,
    /// 見 [InkCanvas] 的同名參數。
    acceptsInk: Boolean = true
) {
    val density = LocalDensity.current.density
    androidx.compose.ui.viewinterop.AndroidView(
        modifier = modifier,
        factory = { context ->
            InkSurfaceView(context, engine, latency, pxPerDp = density, onInkChanged = onInkChanged).also { view ->
                view.acceptsInk = acceptsInk
                if (!view.start()) onUnavailable()
            }
        },
        update = { view ->
            // 模式切換時要跟著改 —— 只在 factory 設的話，切過去之後
            // 那個 view 會被重用，筆照樣畫得出來。
            view.acceptsInk = acceptsInk
            if (clearToken > 0 && engine.strokes.isEmpty()) view.clearAll()
        },
        onRelease = { it.stop() }
    )
}
