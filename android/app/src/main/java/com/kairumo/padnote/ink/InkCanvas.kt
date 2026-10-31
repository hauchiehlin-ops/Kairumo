package com.kairumo.padnote.ink

import android.view.MotionEvent
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import com.kairumo.padnote.canvas.drawPageBackground
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
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
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.layer.GraphicsLayer
import androidx.compose.ui.platform.LocalGraphicsContext
import androidx.compose.ui.input.pointer.pointerInteropFilter
import androidx.compose.ui.platform.LocalDensity
import uniffi.padnote_core.FfiDab
import uniffi.padnote_core.LiveBrushStroke
import uniffi.padnote_core.StrokePoint
import uniffi.padnote_core.brushIsCustom
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
    /** 硬體觸控筆感知：偵測到實體筆時自動通知外層切換為繪圖模式（方案 A）。 */
    onStylusDetected: () -> Unit = {},
    /**
     * 這個模式下畫布接不接受筆畫。
     *
     * 打字模式下如果偵測到硬體觸控筆，會自動切換為手繪模式並接收筆劃。
     */
    acceptsInk: Boolean = true,
    /**
     * 套索拖曳中：選中的筆畫畫在手指帶過去的位置（見 `LassoSelection.dragPreview`）。
     *
     * **在繪製階段讀**，拖曳時只重畫這張畫布、不重組外層。只畫預覽、原筆畫留在原位的話，
     * 畫面上同時有兩份，使用者看起來是「拖不動、放開又跳過去」。
     */
    lassoDrag: () -> com.kairumo.padnote.canvas.LassoDragPreview? = { null }
) {
    val density = LocalDensity.current.density
    val view = androidx.compose.ui.platform.LocalView.current
    val predictor = remember(view) {
        runCatching { androidx.input.motionprediction.MotionEventPredictor.newInstance(view) }.getOrNull()
    }
    var predictedPoints by remember { mutableStateOf<List<StrokePoint>>(emptyList()) }
    // 筆畫存在 engine 裡（它才是真相來源）。這個計數器只是用來觸發重繪 ——
    // 把整份筆畫複製進 Compose state，一筆一次複製整個清單會很慢。
    var revision by remember { mutableIntStateOf(0) }
    var liveVersion by remember { mutableStateOf(0L) }
    DisposableEffect(engine) {
        engine.onSnapPreviewChanged = { liveVersion = System.nanoTime() }
        onDispose { engine.onSnapPreviewChanged = null }
    }

    // 懸停預覽（工作項 S-69）：筆尖靠近但還沒碰到時，先畫出會落在哪裡。
    //
    // 核心的仲裁器早就有 `Verdict.HOVER`，說明寫著「顯示落筆預覽」——
    // 在這之前沒有任何地方真的畫過那個預覽，硬體回報了、判定分類了，
    // 然後結果被丟掉。
    //
    // 不知道筆尖會落在哪，使用者只能先點一下看看 —— 而一筆下去才發現位置
    // 不對，那一筆已經在紙上了。
    var hoverPoint by remember { mutableStateOf<Offset?>(null) }
    var activeEraserPoint by remember { mutableStateOf<Offset?>(null) }

    // 已完成的筆畫一筆一個圖層，錄一次之後只重播（見 `StrokeLayerCache`）。
    val graphicsContext = LocalGraphicsContext.current
    val strokeLayers = remember(graphicsContext) { StrokeLayerCache(graphicsContext) }
    DisposableEffect(strokeLayers) { onDispose { strokeLayers.releaseAll() } }
    // 正在畫的那一筆（自繪引擎筆刷）邊畫邊算，見 `LiveBrushLayers`。
    val liveLayers = remember(graphicsContext) { LiveBrushLayers(graphicsContext) }
    DisposableEffect(liveLayers) { onDispose { liveLayers.releaseAll() } }

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
                            // 支援觸控筆與滑鼠游標懸停預覽
                            change?.type != PointerType.Stylus && change?.type != PointerType.Mouse -> null
                            event.type == PointerEventType.Exit -> null
                            // 已經碰到螢幕了就不是懸停。此時預覽會疊在真正的
                            // 筆跡上，若是橡皮擦則由下方 pointerInteropFilter 處理 activeEraserPoint
                            change.pressed -> null
                            event.type == PointerEventType.Enter ||
                                event.type == PointerEventType.Move -> change.position
                            else -> hoverPoint
                        }
                    }
                }
            }
            .pointerInteropFilter { event ->
                // 打字模式等不收筆畫的狀態下，完全不攔截、不繪墨，將觸控原樣放行給文字、物件與即點即書手勢
                if (!acceptsInk) return@pointerInteropFilter false
                // pointerInteropFilter 傳入之 MotionEvent 座標未經外部 graphicsLayer 縮放除倍率；
                // 畫布內部繪製（DrawScope）隨後會再受 graphicsLayer 縮放，故指示圓圈中心座標需嚴格轉換至
                // 畫布內部本地座標（/ engine.zoom），確保指示圓圈與螢幕真實下筆/擦除軌跡 1:1 精確咬合。
                val z = if (engine.zoom > 0.01f) engine.zoom else 1f
                val localCanvasPoint = Offset(event.x / z, event.y / z)

                // 懸停事件（筆尖靠近、滑鼠移動）也會進到這裡。原本一律清掉 hoverPoint，
                // 上面 pointerInput 剛設好的懸停位置馬上被抹掉 —— 懸停圓圈閃一下就不見。
                when (event.actionMasked) {
                    MotionEvent.ACTION_HOVER_ENTER, MotionEvent.ACTION_HOVER_MOVE -> {
                        val toolType = event.getToolType(0)
                        hoverPoint = if (toolType == MotionEvent.TOOL_TYPE_STYLUS ||
                            toolType == MotionEvent.TOOL_TYPE_ERASER ||
                            toolType == MotionEvent.TOOL_TYPE_MOUSE
                        ) localCanvasPoint else null
                    }
                    MotionEvent.ACTION_HOVER_EXIT -> hoverPoint = null
                    else -> hoverPoint = null
                }
                if (engine.isErasing) {
                    when (event.actionMasked) {
                        MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE -> {
                            activeEraserPoint = localCanvasPoint
                        }
                        MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                            activeEraserPoint = null
                        }
                    }
                } else {
                    activeEraserPoint = null
                }
                predictor?.record(event)
                val outcome = engine.onMotionEvent(event, density)
                predictedPoints = if (event.actionMasked == MotionEvent.ACTION_MOVE && !engine.isErasing) {
                    val predEvent = predictor?.predict()
                    if (predEvent != null) {
                        // 預測點要換算到**與真實取樣點相同**的頁面座標（倍率與位移）。原本少了這一步：
                        // 預測點落在另一個座標系，即時筆畫的尾端每一幀都多出一條從筆尖拉出去的直線，
                        // 抬筆才消失（預測點不進資料，所以留不下來）。也只取正在畫的那根指標。
                        val samples = InkInput.samples(predEvent, density, engine.zoom, engine.offsetX, engine.offsetY)
                            .filter { engine.isDrawing(it.event.id) }
                        val pts = InkInput.strokePoints(samples).take(3)
                        predEvent.recycle()
                        pts
                    } else {
                        emptyList()
                    }
                } else {
                    emptyList()
                }
                revision++
                liveVersion = System.nanoTime()
                // 避免在 ACTION_MOVE 120Hz/240Hz 取樣過程中無條件觸發父層 Compose 狀態更新與儲存排程；
                // 僅於落筆／抬筆、筆畫完成或撤回、拒絕／手勢攔截或橡皮擦擦除時通知外層。
                if (event.actionMasked != MotionEvent.ACTION_MOVE ||
                    engine.isErasing ||
                    outcome.completed.isNotEmpty() ||
                    outcome.retracted.isNotEmpty() ||
                    outcome.rejectedSamples > 0 ||
                    outcome.gestureSamples > 0
                ) {
                    onInkChanged()
                }
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

        @Suppress("UNUSED_EXPRESSION") DraftingState.version
        // 未分層 → 底 → 中 → 頂；隱藏的圖層不畫。
        val drag = lassoDrag()
        val committed = engine.strokes
        for (stroke in DraftingState.drawOrder(committed) { it.layer }) {
            val strokeColor = if (stroke.colorRgba.size >= 4) {
                Color(
                    (stroke.colorRgba[0].toInt() and 0xFF) / 255f,
                    (stroke.colorRgba[1].toInt() and 0xFF) / 255f,
                    (stroke.colorRgba[2].toInt() and 0xFF) / 255f,
                    (stroke.colorRgba[3].toInt() and 0xFF) / 255f
                )
            } else inkColor
            if (drag != null && stroke.coreStrokeId in drag.ids) {
                // 拖曳中的筆畫每一幀位置都不同，直接畫。
                translate(drag.offset.x * density, drag.offset.y * density) {
                    drawInkStroke(stroke.points, stroke.tool, stroke.baseWidth, strokeColor, density, stroke.lineType)
                }
                continue
            }
            val cached = strokeLayers.get(stroke, strokeColor, density, size)
            val layer = cached ?: strokeLayers.create(stroke, strokeColor, density, size).also {
                it.record {
                    drawInkStroke(stroke.points, stroke.tool, stroke.baseWidth, strokeColor, density, stroke.lineType)
                }
            }
            drawLayer(layer)
        }
        strokeLayers.retainOnly(committed)
        // 尚未抬筆的那一段也要即時畫出來，否則寫字時要等抬筆才看得到。
        val snapped = engine.snapPreview ?: engine.draftPreview
        val liveById = engine.liveSamplesById()
        liveLayers.retainOnly(if (snapped == null) liveById.keys else emptySet())
        for ((pointerId, live) in liveById) {
            if (snapped == null && brushIsCustom(engine.tool)) {
                // 自繪引擎的筆刷：只算新來的取樣點，已定案的筆點錄進圖層只重播。
                // 原本每一幀把整筆重算、重畫一次 —— 筆畫越長越慢，寫得快時筆跡越追越遠。
                liveLayers.draw(
                    this, pointerId, InkInput.strokePoints(live), predictedPoints,
                    engine.tool, engine.baseWidth, engine.lineType, inkColor, density)
                continue
            }
            // 長按吸附的預覽：按住不動時直接畫出吸附後的圖形；製圖線則畫出靠邊／對齊之後的樣子。
            val livePts = snapped ?: (InkInput.strokePoints(live) + predictedPoints)
            InkBrushRenderer.drawStrokeOnDrawScope(
                this, livePts, engine.tool, engine.baseWidth, inkColor, density,
                engine.lineType, useCache = false)
        }
        drawDraftingAids(engine, density, false)

        // 工具覆蓋層（標註預覽與已選的點）。
        @Suppress("UNUSED_EXPRESSION") engine.overlayStrokes
        for (item in engine.overlayStrokes) {
            val color = DraftingState.parseHex(item.colorHex)
            drawInkStroke(
                DraftingState.points(item, 0f, 0f), uniffi.padnote_core.ToolKind.FINELINER,
                item.width, color, density, item.lineType.toInt())
        }
        for (mark in engine.overlayMarks) {
            drawCircle(
                Color(0x59FF9500), radius = 5f * density, center = androidx.compose.ui.geometry.Offset(mark.x * density, mark.y * density))
            drawCircle(
                Color(0xFFFF9500), radius = 5f * density, center = androidx.compose.ui.geometry.Offset(mark.x * density, mark.y * density),
                style = androidx.compose.ui.graphics.drawscope.Stroke(width = 1.6f * density))
        }

        // 懸停預覽或橡皮擦擦除時的指示圓圈畫在最上層：被墨跡蓋住就失去意義了。
        val indicatorPoint = if (engine.isErasing) (activeEraserPoint ?: hoverPoint) else hoverPoint
        indicatorPoint?.let { point ->
            drawIndicatorPreview(point, engine.baseWidth, engine.isErasing, inkColor, density)
        }
    }
}

/**
 * 已完成的筆畫一筆一個圖層。
 *
 * 畫布每收到一個觸控點就重畫一次（`revision`／`liveVersion`），原本每一次都把**整頁所有筆畫**
 * 從頭畫過。炭筆、蠟筆這類筆刷一筆是成千上萬個筆點，頁面上塗多了，一次重畫就超過 5 秒 ——
 * 實機上是「Kairumo 沒有回應」（ANR，主執行緒卡在 `InkBrushRenderer.drawDabsOnDrawScope`）。
 * 整頁錄成一個圖層也不夠：每多一筆就得整頁重錄，成本一樣。所以每一筆錄進自己的圖層，
 * 畫完那一刻只錄這一筆，其餘只是重播錄好的內容。
 *
 * 筆畫是不可變的資料（改動一律 `copy()` 換新物件），以**物件本身**為鍵就知道是不是同一筆；
 * 不在引擎清單裡的筆畫（擦掉、復原、重讀）它的圖層會被釋放。
 */
private class StrokeLayerCache(private val graphicsContext: androidx.compose.ui.graphics.GraphicsContext) {
    private class Entry(
        val layer: GraphicsLayer,
        val color: Color,
        val density: Float,
        val size: androidx.compose.ui.geometry.Size
    )

    private val entries = java.util.IdentityHashMap<InkEngine.CompletedStroke, Entry>()

    fun get(
        stroke: InkEngine.CompletedStroke, color: Color, density: Float,
        size: androidx.compose.ui.geometry.Size
    ): GraphicsLayer? {
        val entry = entries[stroke] ?: return null
        if (entry.color == color && entry.density == density && entry.size == size) return entry.layer
        graphicsContext.releaseGraphicsLayer(entry.layer)
        entries.remove(stroke)
        return null
    }

    fun create(
        stroke: InkEngine.CompletedStroke, color: Color, density: Float,
        size: androidx.compose.ui.geometry.Size
    ): GraphicsLayer {
        val layer = graphicsContext.createGraphicsLayer()
        entries[stroke] = Entry(layer, color, density, size)
        return layer
    }

    /** 引擎清單裡已經沒有的筆畫，釋放它的圖層。 */
    fun retainOnly(current: List<InkEngine.CompletedStroke>) {
        if (entries.isEmpty()) return
        val alive = java.util.Collections.newSetFromMap(java.util.IdentityHashMap<InkEngine.CompletedStroke, Boolean>())
        alive.addAll(current)
        val iterator = entries.entries.iterator()
        while (iterator.hasNext()) {
            val (stroke, entry) = iterator.next()
            if (stroke !in alive) {
                graphicsContext.releaseGraphicsLayer(entry.layer)
                iterator.remove()
            }
        }
    }

    fun releaseAll() {
        for (entry in entries.values) graphicsContext.releaseGraphicsLayer(entry.layer)
        entries.clear()
    }
}

/**
 * 正在畫的筆畫（自繪引擎筆刷），一根指標一份，**邊畫邊算**。
 *
 * 核心的 [LiveBrushStroke] 每次只算新來的取樣點，回傳的筆點定案後不再變動；
 * 這裡把它們每滿 [CHUNK] 個錄成一個圖層，之後每一幀只重播圖層、再補上未滿的那一段與
 * 筆尖附近的預覽。每一幀的成本因此跟著「新寫的那一小段」走，不隨筆畫長度增加。
 */
private class LiveBrushLayers(private val graphicsContext: androidx.compose.ui.graphics.GraphicsContext) {
    private class Entry(
        val first: StrokePoint,
        val tool: ToolKind,
        val baseWidth: Float,
        val lineType: Int,
        val color: Color,
        val density: Float,
        val brush: LiveBrushStroke
    ) {
        /** 已經餵給核心的取樣點數。 */
        var fed = 0
        val chunks = ArrayList<GraphicsLayer>()
        val pending = ArrayList<FfiDab>()

        fun matches(points: List<StrokePoint>, tool: ToolKind, baseWidth: Float, lineType: Int, color: Color, density: Float) =
            points.size >= fed && points[0].x == first.x && points[0].y == first.y &&
                tool == this.tool && baseWidth == this.baseWidth && lineType == this.lineType &&
                color == this.color && density == this.density
    }

    private val entries = HashMap<ULong, Entry>()

    fun draw(
        scope: androidx.compose.ui.graphics.drawscope.DrawScope,
        pointerId: ULong,
        points: List<StrokePoint>,
        predicted: List<StrokePoint>,
        tool: ToolKind,
        baseWidth: Float,
        lineType: Int,
        color: Color,
        density: Float
    ) {
        if (points.isEmpty()) return
        var entry = entries[pointerId]
        if (entry == null || !entry.matches(points, tool, baseWidth, lineType, color, density)) {
            entry?.let { release(it) }
            entry = Entry(points[0], tool, baseWidth, lineType, color, density,
                LiveBrushStroke(tool, baseWidth, lineType.toUByte()))
            entries[pointerId] = entry
        }
        if (points.size > entry.fed) {
            entry.pending += entry.brush.append(points.subList(entry.fed, points.size))
            entry.fed = points.size
        }
        if (entry.pending.size >= CHUNK) {
            val dabs = ArrayList(entry.pending)
            val layer = graphicsContext.createGraphicsLayer()
            with(scope) { layer.record { InkBrushRenderer.drawDabs(this, dabs, color, density) } }
            entry.chunks += layer
            entry.pending.clear()
        }
        for (layer in entry.chunks) scope.drawLayer(layer)
        InkBrushRenderer.drawDabs(scope, entry.pending, color, density)
        InkBrushRenderer.drawDabs(scope, entry.brush.preview(predicted), color, density)
    }

    /** 已經不在畫的指標（抬筆、取消）放掉它的圖層與核心狀態。 */
    fun retainOnly(alive: Set<ULong>) {
        val iterator = entries.entries.iterator()
        while (iterator.hasNext()) {
            val (id, entry) = iterator.next()
            if (id !in alive) {
                release(entry)
                iterator.remove()
            }
        }
    }

    fun releaseAll() {
        for (entry in entries.values) release(entry)
        entries.clear()
    }

    private fun release(entry: Entry) {
        for (layer in entry.chunks) graphicsContext.releaseGraphicsLayer(layer)
        entry.chunks.clear()
        entry.brush.close()
    }

    private companion object {
        /** 一個圖層錄多少個筆點：太小圖層太多，太大則未錄進圖層、每幀重畫的那一段太長。 */
        const val CHUNK = 256
    }
}

/**
 * 懸停時的筆頭預覽或橡皮擦擦除時的指示圓圈。
 *
 * 橡皮擦圓圈半徑嚴格對齊核心擦除半徑（`baseWidth * 1.5f * density`），
 * 並以高對比同心雙環圈及半透明底色呈現，讓使用者能清楚判讀橡皮擦實際涵蓋範圍。
 */
private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawIndicatorPreview(
    point: Offset,
    baseWidth: Float,
    erasing: Boolean,
    inkColor: Color,
    density: Float
) {
    if (erasing) {
        // 橡皮擦半徑依選定比例計算（與 InkEngine.eraseAt 一致）
        val radius = (baseWidth * 1.5f).coerceAtLeast(6f) * density
        // 輕微半透明淺藍色底，清楚標示擦除覆蓋區域
        drawCircle(
            color = Color(0x18007AFF),
            radius = radius,
            center = point
        )
        // 外層高對比亮白圈（在深色背景或黑筆跡上清晰分明）
        drawCircle(
            color = Color(0xEEFFFFFF),
            radius = radius,
            center = point,
            style = androidx.compose.ui.graphics.drawscope.Stroke(width = 2.4f * density)
        )
        // 內層深色圈（在淺色或白底紙張上清晰分明）
        drawCircle(
            color = Color(0xD01E293B),
            radius = radius,
            center = point,
            style = androidx.compose.ui.graphics.drawscope.Stroke(width = 1.2f * density)
        )
        // 中心微小十字準心（3.5dp），輔助精確擦除細小筆跡
        val tick = 3.5f * density
        drawLine(
            color = Color(0xD01E293B),
            start = Offset(point.x - tick, point.y),
            end = Offset(point.x + tick, point.y),
            strokeWidth = 1.2f * density
        )
        drawLine(
            color = Color(0xD01E293B),
            start = Offset(point.x, point.y - tick),
            end = Offset(point.x, point.y + tick),
            strokeWidth = 1.2f * density
        )
    } else {
        // 一般筆刷懸停預覽：只描邊、不填滿
        val radius = baseWidth.coerceIn(2f, 32f) * density / 2f
        drawCircle(
            color = inkColor.copy(alpha = 0.55f),
            radius = radius,
            center = point,
            style = androidx.compose.ui.graphics.drawscope.Stroke(width = 1.5f * density)
        )
    }
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
    density: Float,
    lineType: Int = 0
) {
    InkBrushRenderer.drawStrokeOnDrawScope(this, points, tool, baseWidth, color, density, lineType)
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
    /** 硬體觸控筆感知：偵測到實體筆時自動通知外層切換為繪圖模式（方案 A）。 */
    onStylusDetected: () -> Unit = {},
    /// 見 [InkCanvas] 的同名參數。
    acceptsInk: Boolean = true
) {
    val density = LocalDensity.current.density
    var lastClearToken by remember { mutableIntStateOf(clearToken) }
    androidx.compose.ui.viewinterop.AndroidView(
        modifier = modifier,
        factory = { context ->
            InkSurfaceView(context, engine, latency, pxPerDp = density, onInkChanged = onInkChanged).also { view ->
                view.acceptsInk = acceptsInk
                view.onStylusDetected = onStylusDetected
                if (!view.start()) onUnavailable()
            }
        },
        update = { view ->
            // 模式切換時要跟著改 —— 只在 factory 設的話，切過去之後
            // 那個 view 會被重用，筆照樣畫得出來。
            view.acceptsInk = acceptsInk
            view.onStylusDetected = onStylusDetected
            if (clearToken != lastClearToken) {
                lastClearToken = clearToken
                view.clearAll()
            }
        },
        onRelease = { it.stop() }
    )
}


/** 45° 轉折點、尺規與對齊導引（與 Apple `ProInkLayerView.draw` 同一組圖）。 */
private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawDraftingAids(
    engine: InkEngine, density: Float, dark: Boolean
) {
    DraftingState.pivot(engine.pageKey)?.let { (px, py) ->
        val c = Offset(px * density, py * density)
        val blue = Color(0xFF007AFF)
        drawLine(blue, Offset(c.x - 9f * density, c.y), Offset(c.x + 9f * density, c.y), strokeWidth = 1.2f * density)
        drawLine(blue, Offset(c.x, c.y - 9f * density), Offset(c.x, c.y + 9f * density), strokeWidth = 1.2f * density)
        drawCircle(blue, radius = 5f * density, center = c, style = androidx.compose.ui.graphics.drawscope.Stroke(1.2f * density))
    }
    DraftingState.instrument?.let { inst ->
        val teal = Color(0xFF30B0C7)
        val ink = if (dark) Color(0xEBFFFFFF) else Color(0xFF1F1F1F)
        fun o(p: InkEngine.Offset2) = Offset(p.x * density, p.y * density)
        for (ring in inst.pageOutline) {
            if (ring.size < 3) continue
            val path = androidx.compose.ui.graphics.Path().apply {
                moveTo(o(ring[0]).x, o(ring[0]).y)
                for (q in ring.drop(1)) lineTo(o(q).x, o(q).y)
                close()
            }
            drawPath(path, teal.copy(alpha = 0.16f))
            drawPath(path, teal.copy(alpha = 0.85f), style = androidx.compose.ui.graphics.drawscope.Stroke(1.4f * density))
        }
        for (tick in inst.geometry.ticks) {
            drawLine(
                ink.copy(alpha = 0.8f), o(inst.toPage(tick.a)), o(inst.toPage(tick.b)),
                strokeWidth = (if (tick.weight.toInt() == 2) 1.1f else 0.7f) * density)
            tick.label?.let { label ->
                val at = o(inst.toPage(tick.labelAt))
                drawContext.canvas.nativeCanvas.drawText(
                    label, at.x, at.y + 3f * density,
                    android.graphics.Paint().apply {
                        color = ink.toArgb(); textSize = 9f * density; textAlign = android.graphics.Paint.Align.CENTER
                        isAntiAlias = true
                    })
            }
        }
        val ray = inst.readingRay
        val text = inst.readingText
        if (ray != null && text != null) {
            val orange = Color(0xFFFF9500)
            drawLine(orange, o(ray.first), o(ray.second), strokeWidth = 1.6f * density)
            val at = o(ray.second)
            drawContext.canvas.nativeCanvas.drawText(
                text, at.x + 4f * density, at.y - 4f * density,
                android.graphics.Paint().apply {
                    color = orange.toArgb(); textSize = 11f * density; isAntiAlias = true
                    typeface = android.graphics.Typeface.create(android.graphics.Typeface.MONOSPACE, android.graphics.Typeface.BOLD)
                })
        }
        for ((a, b) in inst.pageEdges) drawLine(teal, o(a), o(b), strokeWidth = 2f * density)
    }
    for (line in engine.alignGuides) {
        if (line.size < 2) continue
        val path = androidx.compose.ui.graphics.Path().apply {
            moveTo(line[0].x * density, line[0].y * density)
            for (q in line.drop(1)) lineTo(q.x * density, q.y * density)
        }
        drawPath(
            path, Color(0xD9007AFF),
            style = androidx.compose.ui.graphics.drawscope.Stroke(
                1f * density, pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f * density, 4f * density), 0f)))
    }
}
