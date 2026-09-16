package com.kairumo.padnote.ink

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.view.MotionEvent
import android.view.SurfaceView
import androidx.graphics.lowlatency.CanvasFrontBufferedRenderer
import androidx.input.motionprediction.MotionEventPredictor
import uniffi.padnote_core.StrokePoint
import uniffi.padnote_core.ToolKind

/**
 * 低延遲手寫表面（工作包 WP5c / WP5d）。
 *
 * # 為什麼需要前緩衝
 *
 * 一般的渲染路徑要經過「App 畫 → 合成器合成 → 面板更新」至少兩三幀。手寫時
 * 那段距離看得見：筆尖走了、墨跡還在後面追。前緩衝渲染讓 App 直接畫進正在
 * 掃描的那塊緩衝區，省掉合成的來回。API 29 起才有 —— minSdk 29 就是為它訂的。
 *
 * # 預測筆跡：只進畫面，永不進資料
 *
 * `MotionEventPredictor` 猜的是「筆接下來大概會到哪」，用來補視覺落差。
 * 它是**猜測**，不是使用者真的寫下的東西。所以預測點只畫到前緩衝，
 * 絕不餵給 `InkEngine`、絕不進 `.padnote`。這是既有的架構不變式，
 * 不是這裡的臨時決定 —— 寫進去的話，使用者的筆記裡會混進他沒寫過的線條。
 *
 * # 失敗時要退回去，不是黑畫面
 *
 * 各家 OEM 對前緩衝的支援不一致。建不起來就回報 `false`，由上層改用一般的
 * Compose 畫布 —— 手寫可以比較鈍，但不能不能用。
 */
class InkSurfaceView(
    context: Context,
    private val engine: InkEngine,
    private val latency: InkLatencyMeter,
    /**
     * 每 dp 幾個像素。
     *
     * **不要叫它 `density`。** 這個檔案裡有寫在 `Canvas` 上的擴充函式，
     * 而 `Canvas` 本身有一個 `density` 成員 —— 接收者的成員會蓋過外層類別的
     * 屬性，於是座標與線寬全被乘上 `Canvas.density`（未設定時是 0），
     * 筆畫整條塌到原點、線寬變 0。編譯器不會警告，畫面上就是一片空白。
     */
    private val pxPerDp: Float,
    private val onInkChanged: () -> Unit = {}
) : SurfaceView(context) {

    /** 要畫的一小段。前緩衝一次只畫增量，不是整張重畫。 */
    data class Segment(
        val x1: Float, val y1: Float,
        val x2: Float, val y2: Float,
        val width: Float,
        val predicted: Boolean
    )

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        color = Color.BLACK
    }

    /** 預測線淡一點：它隨時可能被真實軌跡改寫，畫得跟真跡一樣濃會看到殘影。 */
    private val predictedPaint = Paint(paint).apply { alpha = 140 }

    private var renderer: CanvasFrontBufferedRenderer<Segment>? = null
    private var predictor: MotionEventPredictor? = null

    /** 每根指標最後一個畫過的點，用來接出下一段。 */
    private val lastPoint = HashMap<ULong, Pair<Float, Float>>()

    private val callback = object : CanvasFrontBufferedRenderer.Callback<Segment> {
        override fun onDrawFrontBufferedLayer(
            canvas: Canvas, bufferWidth: Int, bufferHeight: Int, param: Segment
        ) {
            canvas.drawSegment(param)
        }

        override fun onDrawMultiBufferedLayer(
            canvas: Canvas, bufferWidth: Int, bufferHeight: Int, params: Collection<Segment>
        ) {
            canvas.drawColor(Color.WHITE)
            // 這一層每次 commit 都是全新的緩衝，所以要重畫全部內容 ——
            // 只畫增量的話，抬筆瞬間先前的筆畫會整片消失。
            for (stroke in engine.strokes) {
                canvas.drawStroke(stroke.points, stroke.tool)
            }
            // 預測線不進這一層 —— 它不是使用者寫的東西，抬筆後就該消失。
        }
    }

    /** 建立前緩衝渲染器。裝置不支援時回傳 `false`，由上層退回一般畫布。 */
    fun start(): Boolean = runCatching {
        // SurfaceView 預設在**視窗底下**，靠在視窗上打洞才看得見。Compose 的
        // Surface 會畫一層不透明底色，那個洞就被蓋住了 —— 畫面上看到的是
        // 一片底色，不是我們畫的東西。實機回報「畫布全白」就是這個。
        setZOrderOnTop(true)
        holder.setFormat(android.graphics.PixelFormat.TRANSLUCENT)
        renderer = CanvasFrontBufferedRenderer(this, callback)
        predictor = MotionEventPredictor.newInstance(this)
        true
    }.getOrElse { false }

    /**
     * 清掉畫面上的一切。
     *
     * 只清 `InkEngine` 不夠：前緩衝與多重緩衝各自持有已經畫上去的像素，
     * 不主動清的話，按了「清除」畫面還是舊的墨跡，直到下一次抬筆才更新。
     */
    fun clearAll() {
        val active = renderer ?: return
        lastPoint.clear()
        runCatching { active.clear() }
        active.commit()
    }

    fun stop() {
        runCatching { renderer?.release(cancelPending = true) }
        renderer = null
        predictor = null
        lastPoint.clear()
    }

    /**
     * 這個模式下畫布接不接受筆畫。見 [InkCanvas] 的同名參數。
     *
     * 打字模式要的是「誰都不能畫」—— 掌拒的 pen-only 擋得掉手指，
     * 擋不掉觸控筆。
     */
    var acceptsInk: Boolean = true

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        // 不收筆畫時把事件讓出去，外層照常捲動與選取。
        if (!acceptsInk) return false
        val active = renderer ?: return false
        predictor?.record(event)

        val outcome = engine.onMotionEvent(event, pxPerDp)
        latency.record(event)

        if (outcome.retracted.isNotEmpty()) {
            // 收回的內容還畫在前緩衝上，只能整片重來。
            runCatching { active.clear() }
            lastPoint.clear()
            active.commit()
        }

        // 真實軌跡：把這次收到的每個取樣點接成線段送進前緩衝。
        drawIncoming(event, active)

        if (event.actionMasked == MotionEvent.ACTION_UP ||
            event.actionMasked == MotionEvent.ACTION_CANCEL
        ) {
            lastPoint.clear()
            active.commit()
        }
        onInkChanged()
        return true
    }

    /** 把這個事件帶來的取樣點（含歷史點）接成線段畫出去，最後補上預測。 */
    private fun drawIncoming(event: MotionEvent, active: CanvasFrontBufferedRenderer<Segment>) {
        for (sample in InkInput.samples(event, pxPerDp)) {
            if (!engine.isDrawing(sample.event.id)) continue
            val id = sample.event.id
            val x = sample.event.x * pxPerDp
            val y = sample.event.y * pxPerDp
            val previous = lastPoint[id]
            if (previous != null) {
                active.renderFrontBufferedLayer(
                    Segment(previous.first, previous.second, x, y,
                        widthFor(sample.event.pressure), predicted = false)
                )
            }
            lastPoint[id] = x to y
        }

        // 預測只在筆還按著時有意義。
        if (event.actionMasked != MotionEvent.ACTION_MOVE) return
        val predicted = predictor?.predict() ?: return
        for (sample in InkInput.samples(predicted, pxPerDp)) {
            if (!engine.isDrawing(sample.event.id)) continue
            val previous = lastPoint[sample.event.id] ?: continue
            active.renderFrontBufferedLayer(
                Segment(previous.first, previous.second,
                    sample.event.x * pxPerDp, sample.event.y * pxPerDp,
                    widthFor(sample.event.pressure), predicted = true)
            )
            // 刻意不更新 lastPoint：下一個真實點要從**真實**的位置接續，
            // 否則預測誤差會一路累積下去。
        }
        predicted.recycle()
    }

    private fun widthFor(pressure: Float): Float {
        val sensitive = engine.tool == ToolKind.FOUNTAIN_PEN || engine.tool == ToolKind.PENCIL
        val scale = if (sensitive) 0.35f + 0.65f * pressure.coerceIn(0f, 1f) else 1f
        return engine.baseWidth * scale * pxPerDp
    }

    private fun Canvas.drawSegment(s: Segment) {
        val p = if (s.predicted) predictedPaint else paint
        p.strokeWidth = s.width
        drawLine(s.x1, s.y1, s.x2, s.y2, p)
    }

    private fun Canvas.drawStroke(points: List<StrokePoint>, tool: ToolKind) {
        if (points.size < 2) return
        val sensitive = tool == ToolKind.FOUNTAIN_PEN || tool == ToolKind.PENCIL
        for (i in 1 until points.size) {
            val a = points[i - 1]
            val b = points[i]
            val scale = if (sensitive) 0.35f + 0.65f * b.pressure.coerceIn(0f, 1f) else 1f
            paint.strokeWidth = engine.baseWidth * scale * pxPerDp
            drawLine(a.x * pxPerDp, a.y * pxPerDp, b.x * pxPerDp, b.y * pxPerDp, paint)
        }
    }
}
