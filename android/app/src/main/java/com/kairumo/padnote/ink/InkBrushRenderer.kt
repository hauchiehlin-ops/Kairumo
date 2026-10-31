package com.kairumo.padnote.ink

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.geometry.Size
import uniffi.padnote_core.FfiDab
import uniffi.padnote_core.StrokePoint
import uniffi.padnote_core.ToolKind
import uniffi.padnote_core.brushDabs
import uniffi.padnote_core.brushIsCustom
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.sin

/**
 * 跨 Compose DrawScope 與 Android Canvas 的專屬筆刷特性渲染器。
 *
 * 針對 7 種繪圖工具實作專屬物理手感與視覺特徵：
 * 1. 鋼筆 (FOUNTAIN_PEN)：運筆速度彈性、出墨隨速度與提按變化、首尾收鋒。
 * 2. 原子筆 (BALL_POINT)：等寬單線 (Monoline)、均勻穩定。
 * 3. 毛筆 (BRUSH)：書法提按、起筆與收筆鋒芒、快速飛白 (0.35x) 與慢速蓄墨 (2.2x)。
 * 4. 麥克筆 (MARKER)：斜切扁筆寬窄動態 (Chisel angle)、半透明飽和墨水。
 * 5. 螢光筆 (HIGHLIGHTER)：平切平頭 (Square Cap)、色彩正片疊底 (Multiply)。
 * 6. 鉛筆 (PENCIL)：石墨摩擦紙張纖維微噪感 (Graphite Grain)、半透炭筆質地。
 * 7. 水彩筆 (WATERCOLOR)：雙層水痕暈染 (Wet Bleed & Core Wash)。
 */
// profile-scope: device 純筆點與線段幾何快取（以筆畫點列物件識別與幾何參數為鍵），不含跨設定檔持久狀態
object InkBrushRenderer {

    data class SegmentSpec(
        val x1: Float,
        val y1: Float,
        val x2: Float,
        val y2: Float,
        val width: Float,
        val alpha: Float,
        val isSquareCap: Boolean = false,
        val secondaryWidth: Float = 0f,
        val secondaryAlpha: Float = 0f,
        val jitterX: Float = 0f,
        val jitterY: Float = 0f
    )

    /**
     * 計算單一筆劃中每一段的物理渲染規格。
     */
    fun computeSegments(
        points: List<StrokePoint>,
        tool: ToolKind,
        baseWidth: Float,
        density: Float
    ): List<SegmentSpec> {
        if (points.size < 2) return emptyList()

        val specs = ArrayList<SegmentSpec>(points.size - 1)
        val count = points.size

        for (i in 1 until count) {
            val a = points[i - 1]
            val b = points[i]

            val dx = b.x - a.x
            val dy = b.y - a.y
            val dist = hypot(dx, dy)
            val dtMs = if (b.dtUs > 0u) (b.dtUs.toFloat() / 1000f).coerceIn(1f, 100f) else 16.6f
            val speed = dist / dtMs // dp / ms

            // 筆尖頭尾收鋒比例 (0.0 ~ 1.0)
            val taperPoints = minOf(6, count / 2).coerceAtLeast(1)
            val startTaper = (i.toFloat() / taperPoints).coerceIn(0.2f, 1f)
            val endTaper = ((count - 1 - i).toFloat() / taperPoints).coerceIn(0.2f, 1f)
            val tipTaper = minOf(startTaper, endTaper)

            val x1 = a.x * density
            val y1 = a.y * density
            val x2 = b.x * density
            val y2 = b.y * density

            when (tool) {
                ToolKind.FOUNTAIN_PEN -> {
                    // 鋼筆：彈性金屬筆尖（下壓劈開加粗 0.42x~1.35x）+ 速度反比（快細慢粗）+ 筆尖收鋒
                    val speedFactor = (1.32f - 0.52f * (speed / 2.2f).coerceIn(0f, 1f))
                    val pressFactor = if (b.pressure in 0.01f..0.99f) 0.42f + 0.88f * b.pressure else 1.0f
                    val w = baseWidth * 1.15f * speedFactor * pressFactor * tipTaper * density
                    val inkAlpha = (0.88f + 0.12f * b.pressure.coerceIn(0f, 1f)).coerceIn(0.82f, 1.0f)
                    specs.add(SegmentSpec(x1, y1, x2, y2, width = w.coerceAtLeast(0.75f * density), alpha = inkAlpha))
                }

                ToolKind.BALL_POINT -> {
                    // 原子筆：均勻等寬 (Monoline)，僅極輕觸微淡、重壓微實，乾淨俐落
                    val p = b.pressure.coerceIn(0.2f, 1.0f)
                    val w = baseWidth * (0.62f + 0.10f * p) * density
                    specs.add(SegmentSpec(x1, y1, x2, y2, width = w.coerceAtLeast(0.6f * density), alpha = 0.92f + 0.08f * p))
                }

                ToolKind.BRUSH -> {
                    // 毛筆線段備援：書法提按、起筆與收筆出鋒、快速飛白收尖与慢速頓筆蓄墨
                    // （實際繪製時若啟用自繪引擎則優先走核心 `chinese_brush` 永字八法筆點陣）
                    val speedMod = (2.25f - 1.60f * (speed / 2.5f).coerceIn(0f, 1f))
                    val pressMod = if (b.pressure in 0.01f..0.99f) 0.18f + 1.55f * b.pressure else 1.0f
                    val tiltMod = 1.0f + 0.65f * sin(b.tilt.coerceIn(0f, 1.57f))
                    val brushTaper = minOf(startTaper * startTaper, endTaper * endTaper).coerceAtLeast(0.14f)
                    val w = baseWidth * 2.1f * speedMod * pressMod * tiltMod * brushTaper * density
                    specs.add(SegmentSpec(x1, y1, x2, y2, width = w.coerceAtLeast(0.7f * density), alpha = 0.96f))
                }

                ToolKind.MARKER -> {
                    // 麥克筆：斜角扁頭 (Chisel)，切角角度與施壓決定線寬
                    val angle = atan2(dy, dx)
                    val chisel = 0.62f + 0.68f * abs(sin(angle - 0.7853982f)) // 45 度角切面
                    val pressSpread = 0.85f + 0.28f * b.pressure.coerceIn(0f, 1f)
                    val w = baseWidth * 2.6f * chisel * pressSpread * density
                    specs.add(SegmentSpec(x1, y1, x2, y2, width = w.coerceAtLeast(1.5f * density), alpha = 0.86f))
                }

                ToolKind.HIGHLIGHTER -> {
                    // 螢光筆：寬平頭 (Square Cap)
                    val w = baseWidth * 3.8f * density
                    specs.add(SegmentSpec(x1, y1, x2, y2, width = w.coerceAtLeast(3f * density), alpha = 0.38f, isSquareCap = true))
                }

                ToolKind.PENCIL -> {
                    // 鉛筆：立鋒精細素描排線 vs 側鋒（tilt > 0.40 rad）大面積柔化鋪調子
                    val press = if (b.pressure in 0.01f..0.99f) 0.38f + 0.68f * b.pressure else 0.85f
                    val tiltSin = sin(b.tilt.coerceIn(0f, 1.57f))
                    val isSideShading = b.tilt > 0.40f
                    val tiltWidthBoost = if (isSideShading) 1.0f + 1.85f * tiltSin else 1.0f + 0.25f * tiltSin
                    val tiltAlphaMod = if (isSideShading) (0.68f - 0.22f * tiltSin).coerceAtLeast(0.38f) else 0.82f
                    val w = baseWidth * 1.25f * press * tiltWidthBoost * density
                    val hash = (i * 7919 + (dx * 100).toInt()) % 11 - 5
                    val jx = hash * 0.12f * density
                    val jy = ((i * 4909) % 11 - 5) * 0.12f * density
                    specs.add(
                        SegmentSpec(
                            x1 = x1, y1 = y1, x2 = x2, y2 = y2,
                            width = w.coerceAtLeast(0.65f * density),
                            alpha = (tiltAlphaMod * press).coerceIn(0.18f, 0.95f),
                            jitterX = jx, jitterY = jy
                        )
                    )
                }

                ToolKind.WATERCOLOR -> {
                    // 水彩筆：雙層水痕渲染（重壓與慢速駐留時外層水暈擴張，模擬宣紙／水彩紙溼畫法暈染）
                    val p = b.pressure.coerceIn(0.15f, 1.0f)
                    val dwellWetness = (1.28f - 0.35f * (speed / 2.0f).coerceIn(0f, 1f)).coerceIn(0.85f, 1.30f)
                    val outerW = baseWidth * (2.2f + 1.1f * p) * dwellWetness * density
                    val innerW = baseWidth * (1.15f + 0.65f * p) * density
                    specs.add(
                        SegmentSpec(
                            x1 = x1, y1 = y1, x2 = x2, y2 = y2,
                            width = outerW,
                            alpha = (0.18f + 0.12f * p).coerceIn(0.15f, 0.36f),
                            secondaryWidth = innerW,
                            secondaryAlpha = (0.34f + 0.22f * p).coerceIn(0.28f, 0.62f)
                        )
                    )
                }

                // 自繪引擎的筆刷由 `drawStroke…` 開頭的分支用核心的筆點陣畫，不會走到這裡。
                ToolKind.FINELINER, ToolKind.CHARCOAL, ToolKind.CRAYON,
                ToolKind.AIRBRUSH, ToolKind.OIL_PAINT, ToolKind.CALLIGRAPHY -> Unit
            }
        }
        if (tool == ToolKind.BRUSH || tool == ToolKind.FOUNTAIN_PEN) smoothWidths(specs)
        return specs
    }

    /** 粗細做前後平均，毛筆與鋼筆不會因取樣間隔不均而忽粗忽細。 */
    private fun smoothWidths(specs: ArrayList<SegmentSpec>) {
        if (specs.size < 3) return
        val raw = FloatArray(specs.size) { specs[it].width }
        var prev = raw[0]
        for (i in specs.indices) {
            val next = if (i + 1 < raw.size) raw[i + 1] else raw[i]
            val w = 0.25f * prev + 0.5f * raw[i] + 0.25f * next
            prev = raw[i]
            specs[i] = specs[i].copy(width = w)
        }
    }

    /** 半透明的筆（鉛筆、螢光筆）整條畫成一條路徑，段與段不會疊出接縫或虛線。 */
    private fun isSinglePass(tool: ToolKind) = tool == ToolKind.HIGHLIGHTER || tool == ToolKind.PENCIL

    private fun avgWidth(segments: List<SegmentSpec>) = segments.sumOf { it.width.toDouble() }.toFloat() / segments.size
    private fun avgAlpha(segments: List<SegmentSpec>) = segments.sumOf { it.alpha.toDouble() }.toFloat() / segments.size

    private data class DabCacheKey(
        val pointsIdentity: Int,
        val size: Int,
        val firstX: Float,
        val lastX: Float,
        val lastY: Float,
        val tool: ToolKind,
        val baseWidth: Float,
        val lineType: Int
    )

    private data class SegmentCacheKey(
        val pointsIdentity: Int,
        val size: Int,
        val firstX: Float,
        val lastX: Float,
        val lastY: Float,
        val tool: ToolKind,
        val baseWidth: Float,
        val density: Float
    )

    private val dabsCache = android.util.LruCache<DabCacheKey, List<FfiDab>>(512)
    private val segmentsCache = android.util.LruCache<SegmentCacheKey, List<SegmentSpec>>(512)

    private fun cachedDabs(
        points: List<StrokePoint>,
        tool: ToolKind,
        baseWidth: Float,
        lineType: Int,
        useCache: Boolean = true
    ): List<FfiDab> {
        if (points.isEmpty()) return emptyList()
        if (!useCache) {
            return if (lineType != 0) {
                uniffi.padnote_core.brushDabsStyled(tool, baseWidth, points, lineType.toUByte())
            } else {
                brushDabs(tool, baseWidth, points)
            }
        }
        val key = DabCacheKey(
            pointsIdentity = System.identityHashCode(points),
            size = points.size,
            firstX = points.first().x,
            lastX = points.last().x,
            lastY = points.last().y,
            tool = tool,
            baseWidth = baseWidth,
            lineType = lineType
        )
        synchronized(dabsCache) {
            dabsCache.get(key)?.let { return it }
        }
        val computed = if (lineType != 0) {
            uniffi.padnote_core.brushDabsStyled(tool, baseWidth, points, lineType.toUByte())
        } else {
            brushDabs(tool, baseWidth, points)
        }
        synchronized(dabsCache) {
            dabsCache.put(key, computed)
        }
        return computed
    }

    private fun cachedSegments(
        points: List<StrokePoint>,
        tool: ToolKind,
        baseWidth: Float,
        density: Float,
        useCache: Boolean = true
    ): List<SegmentSpec> {
        if (points.size < 2) return emptyList()
        if (!useCache) return computeSegments(points, tool, baseWidth, density)
        val key = SegmentCacheKey(
            pointsIdentity = System.identityHashCode(points),
            size = points.size,
            firstX = points.first().x,
            lastX = points.last().x,
            lastY = points.last().y,
            tool = tool,
            baseWidth = baseWidth,
            density = density
        )
        synchronized(segmentsCache) {
            segmentsCache.get(key)?.let { return it }
        }
        val computed = computeSegments(points, tool, baseWidth, density)
        synchronized(segmentsCache) {
            segmentsCache.put(key, computed)
        }
        return computed
    }

    /**
     * 在 Compose DrawScope 上繪製筆畫
     */
    fun drawStrokeOnDrawScope(
        drawScope: DrawScope,
        points: List<StrokePoint>,
        tool: ToolKind,
        baseWidth: Float,
        baseColor: Color,
        density: Float,
        lineType: Int = 0,
        /**
         * 正在畫的那一筆傳 `false`：它每一幀都是一份新的點列，放進快取只會把已完成筆畫的
         * 快取擠掉、堆出一大串用不到的筆點陣（記憶體與 GC 跟著寫得越久越重）。
         */
        useCache: Boolean = true
    ) {
        if (brushIsCustom(tool)) {
            // 虛線／點線：核心依線型把間隔挖掉，兩個平台畫出同樣的線。
            val dabs = cachedDabs(points, tool, baseWidth, lineType, useCache)
            drawDabsOnDrawScope(drawScope, dabs, baseColor, density)
            return
        }
        val segments = cachedSegments(points, tool, baseWidth, density, useCache)
        if (segments.isEmpty()) return

        val isHighlighter = tool == ToolKind.HIGHLIGHTER
        val blend = if (isHighlighter) BlendMode.Multiply else BlendMode.SrcOver

        if (isSinglePass(tool)) {
            val path = androidx.compose.ui.graphics.Path().apply {
                moveTo(segments[0].x1, segments[0].y1)
                for (seg in segments) lineTo(seg.x2, seg.y2)
            }
            drawScope.drawPath(
                path = path,
                color = baseColor.copy(alpha = baseColor.alpha * avgAlpha(segments)),
                style = androidx.compose.ui.graphics.drawscope.Stroke(
                    width = avgWidth(segments),
                    cap = if (isHighlighter) StrokeCap.Square else StrokeCap.Round,
                    join = androidx.compose.ui.graphics.StrokeJoin.Round
                ),
                blendMode = blend
            )
            return
        }

        for (seg in segments) {
            val cap = if (seg.isSquareCap) StrokeCap.Square else StrokeCap.Round

            if (seg.secondaryWidth > 0f) {
                // 水彩雙層暈染：先畫外圈淺水暈
                drawScope.drawLine(
                    color = baseColor.copy(alpha = baseColor.alpha * seg.alpha),
                    start = Offset(seg.x1, seg.y1),
                    end = Offset(seg.x2, seg.y2),
                    strokeWidth = seg.width,
                    cap = cap,
                    blendMode = blend
                )
                // 再疊加內圈蓄色
                drawScope.drawLine(
                    color = baseColor.copy(alpha = baseColor.alpha * seg.secondaryAlpha),
                    start = Offset(seg.x1, seg.y1),
                    end = Offset(seg.x2, seg.y2),
                    strokeWidth = seg.secondaryWidth,
                    cap = cap,
                    blendMode = blend
                )
            } else if (tool == ToolKind.PENCIL) {
                // 鉛筆微噪質地：主體微透線 + 輕度顆粒位移
                drawScope.drawLine(
                    color = baseColor.copy(alpha = baseColor.alpha * seg.alpha),
                    start = Offset(seg.x1 + seg.jitterX, seg.y1 + seg.jitterY),
                    end = Offset(seg.x2 + seg.jitterX, seg.y2 + seg.jitterY),
                    strokeWidth = seg.width,
                    cap = cap,
                    blendMode = blend
                )
            } else {
                drawScope.drawLine(
                    color = baseColor.copy(alpha = baseColor.alpha * seg.alpha),
                    start = Offset(seg.x1, seg.y1),
                    end = Offset(seg.x2, seg.y2),
                    strokeWidth = seg.width,
                    cap = cap,
                    blendMode = blend
                )
            }
        }
    }

    /**
     * 在原生 Android Canvas (例如 InkSurfaceView 低延遲繪製) 上繪製筆畫
     */
    fun drawStrokeOnCanvas(
        canvas: Canvas,
        paint: Paint,
        points: List<StrokePoint>,
        tool: ToolKind,
        baseWidth: Float,
        pxPerDp: Float
    ) {
        if (brushIsCustom(tool)) {
            drawDabsOnCanvas(canvas, paint, cachedDabs(points, tool, baseWidth, 0), pxPerDp)
            return
        }
        val segments = cachedSegments(points, tool, baseWidth, pxPerDp)
        if (segments.isEmpty()) return

        val origAlpha = paint.alpha
        val origCap = paint.strokeCap
        val origXfer = paint.xfermode

        if (tool == ToolKind.HIGHLIGHTER) {
            paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.MULTIPLY)
        }

        if (isSinglePass(tool)) {
            val path = android.graphics.Path().apply {
                moveTo(segments[0].x1, segments[0].y1)
                for (seg in segments) lineTo(seg.x2, seg.y2)
            }
            val origStyle = paint.style
            val origJoin = paint.strokeJoin
            paint.style = Paint.Style.STROKE
            paint.strokeJoin = Paint.Join.ROUND
            paint.strokeCap = if (tool == ToolKind.HIGHLIGHTER) Paint.Cap.SQUARE else Paint.Cap.ROUND
            paint.alpha = (origAlpha * avgAlpha(segments)).toInt().coerceIn(0, 255)
            paint.strokeWidth = avgWidth(segments)
            canvas.drawPath(path, paint)
            paint.style = origStyle
            paint.strokeJoin = origJoin
            paint.alpha = origAlpha
            paint.strokeCap = origCap
            paint.xfermode = origXfer
            return
        }

        for (seg in segments) {
            paint.strokeCap = if (seg.isSquareCap) Paint.Cap.SQUARE else Paint.Cap.ROUND

            if (seg.secondaryWidth > 0f) {
                // 水彩雙層暈染
                paint.alpha = (origAlpha * seg.alpha).toInt().coerceIn(0, 255)
                paint.strokeWidth = seg.width
                canvas.drawLine(seg.x1, seg.y1, seg.x2, seg.y2, paint)

                paint.alpha = (origAlpha * seg.secondaryAlpha).toInt().coerceIn(0, 255)
                paint.strokeWidth = seg.secondaryWidth
                canvas.drawLine(seg.x1, seg.y1, seg.x2, seg.y2, paint)
            } else if (tool == ToolKind.PENCIL) {
                paint.alpha = (origAlpha * seg.alpha).toInt().coerceIn(0, 255)
                paint.strokeWidth = seg.width
                canvas.drawLine(seg.x1 + seg.jitterX, seg.y1 + seg.jitterY, seg.x2 + seg.jitterX, seg.y2 + seg.jitterY, paint)
            } else {
                paint.alpha = (origAlpha * seg.alpha).toInt().coerceIn(0, 255)
                paint.strokeWidth = seg.width
                canvas.drawLine(seg.x1, seg.y1, seg.x2, seg.y2, paint)
            }
        }

        paint.alpha = origAlpha
        paint.strokeCap = origCap
        paint.xfermode = origXfer
    }

    // ── 自繪引擎筆刷（針筆、炭筆、蠟筆、噴槍、油畫筆、書法扁頭筆）──────────────
    //
    // 筆點陣由核心算（`padnote-ink/src/brush.rs`），Apple 畫的是同一份，
    // 所以同一筆在兩台裝置上長得一樣。這裡只負責把橢圓畫出來。

    /** 明暗：向白或向黑偏最多 35%，與 Apple 端同一條式子。 */
    private fun shade(channel: Float, shade: Float): Float {
        val target = if (shade >= 0f) 1f else 0f
        return channel + (target - channel) * (kotlin.math.abs(shade) * 0.35f)
    }

    /** 柔邊筆點由外向內疊四層漸縮的橢圓，每層只補一點不透明度。 */
    private const val SOFT_LAYERS = 4

    /** 把核心算好的筆點畫出來（即時筆畫一段一段畫，見 `LiveBrushLayers`）。 */
    fun drawDabs(drawScope: DrawScope, dabs: List<FfiDab>, baseColor: Color, density: Float) =
        drawDabsOnDrawScope(drawScope, dabs, baseColor, density)

    private fun drawDabsOnDrawScope(
        drawScope: DrawScope,
        dabs: List<FfiDab>,
        baseColor: Color,
        density: Float
    ) {
        for (dab in dabs) {
            val color = Color(
                red = shade(baseColor.red, dab.shade),
                green = shade(baseColor.green, dab.shade),
                blue = shade(baseColor.blue, dab.shade)
            )
            val cx = dab.x * density
            val cy = dab.y * density
            val rx = dab.rx * density
            val ry = dab.ry * density
            val alpha = dab.alpha * baseColor.alpha
            drawScope.rotate(Math.toDegrees(dab.angle.toDouble()).toFloat(), Offset(cx, cy)) {
                if (dab.softness > 0.5f) {
                    for (step in 0 until SOFT_LAYERS) {
                        val f = 1f - step * 0.22f
                        drawOval(
                            color = color.copy(alpha = alpha * 0.34f),
                            topLeft = Offset(cx - rx * f, cy - ry * f),
                            size = Size(rx * f * 2f, ry * f * 2f)
                        )
                    }
                } else {
                    drawOval(
                        color = color.copy(alpha = alpha),
                        topLeft = Offset(cx - rx, cy - ry),
                        size = Size(rx * 2f, ry * 2f)
                    )
                }
            }
        }
    }

    private fun drawDabsOnCanvas(canvas: Canvas, paint: Paint, dabs: List<FfiDab>, pxPerDp: Float) {
        val origColor = paint.color
        val origAlpha = paint.alpha
        val origStyle = paint.style
        paint.style = Paint.Style.FILL
        val baseR = android.graphics.Color.red(origColor) / 255f
        val baseG = android.graphics.Color.green(origColor) / 255f
        val baseB = android.graphics.Color.blue(origColor) / 255f
        val oval = android.graphics.RectF()
        for (dab in dabs) {
            paint.color = android.graphics.Color.rgb(
                (shade(baseR, dab.shade) * 255f + 0.5f).toInt().coerceIn(0, 255),
                (shade(baseG, dab.shade) * 255f + 0.5f).toInt().coerceIn(0, 255),
                (shade(baseB, dab.shade) * 255f + 0.5f).toInt().coerceIn(0, 255)
            )
            val cx = dab.x * pxPerDp
            val cy = dab.y * pxPerDp
            val rx = dab.rx * pxPerDp
            val ry = dab.ry * pxPerDp
            canvas.save()
            canvas.rotate(Math.toDegrees(dab.angle.toDouble()).toFloat(), cx, cy)
            if (dab.softness > 0.5f) {
                for (step in 0 until SOFT_LAYERS) {
                    val f = 1f - step * 0.22f
                    paint.alpha = (origAlpha * dab.alpha * 0.34f).toInt().coerceIn(0, 255)
                    oval.set(cx - rx * f, cy - ry * f, cx + rx * f, cy + ry * f)
                    canvas.drawOval(oval, paint)
                }
            } else {
                paint.alpha = (origAlpha * dab.alpha).toInt().coerceIn(0, 255)
                oval.set(cx - rx, cy - ry, cx + rx, cy + ry)
                canvas.drawOval(oval, paint)
            }
            canvas.restore()
        }
        paint.color = origColor
        paint.alpha = origAlpha
        paint.style = origStyle
    }
}
