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
import uniffi.padnote_core.StrokePoint
import uniffi.padnote_core.ToolKind
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
                    // 鋼筆：速度反比 (快細慢粗) + 筆尖微收鋒
                    val speedFactor = (1.3f - 0.5f * (speed / 2.2f).coerceIn(0f, 1f))
                    val pressFactor = if (b.pressure in 0.01f..0.99f) 0.5f + 0.6f * b.pressure else 1.0f
                    val w = baseWidth * 1.15f * speedFactor * pressFactor * tipTaper * density
                    specs.add(SegmentSpec(x1, y1, x2, y2, width = w.coerceAtLeast(0.8f * density), alpha = 1.0f))
                }

                ToolKind.BALL_POINT -> {
                    // 原子筆：均勻等寬 (Monoline)，乾淨俐落
                    val w = baseWidth * 0.68f * density
                    specs.add(SegmentSpec(x1, y1, x2, y2, width = w.coerceAtLeast(0.6f * density), alpha = 0.98f))
                }

                ToolKind.BRUSH -> {
                    // 毛筆：極致書法提按，行筆飛白收尖 (0.35x)，轉折頓筆蓄墨 (2.2x)
                    val speedMod = (2.2f - 1.55f * (speed / 2.5f).coerceIn(0f, 1f))
                    val pressMod = if (b.pressure in 0.01f..0.99f) 0.35f + 1.1f * b.pressure else 1.0f
                    val brushTaper = minOf(startTaper * startTaper, endTaper * endTaper).coerceAtLeast(0.18f)
                    val w = baseWidth * 2.1f * speedMod * pressMod * brushTaper * density
                    specs.add(SegmentSpec(x1, y1, x2, y2, width = w.coerceAtLeast(1.0f * density), alpha = 0.96f))
                }

                ToolKind.MARKER -> {
                    // 麥克筆：斜角扁頭 (Chisel)，切角角度決定線寬
                    val angle = atan2(dy, dx)
                    val chisel = 0.65f + 0.65f * abs(sin(angle - 0.7853982f)) // 45 度角切面
                    val w = baseWidth * 2.6f * chisel * density
                    specs.add(SegmentSpec(x1, y1, x2, y2, width = w.coerceAtLeast(1.5f * density), alpha = 0.86f))
                }

                ToolKind.HIGHLIGHTER -> {
                    // 螢光筆：寬平頭 (Square Cap)
                    val w = baseWidth * 3.8f * density
                    specs.add(SegmentSpec(x1, y1, x2, y2, width = w.coerceAtLeast(3f * density), alpha = 0.38f, isSquareCap = true))
                }

                ToolKind.PENCIL -> {
                    // 鉛筆：石墨微噪顆粒與紙面纖維
                    val press = if (b.pressure in 0.01f..0.99f) 0.5f + 0.5f * b.pressure else 0.85f
                    val w = baseWidth * 1.25f * press * density
                    val hash = (i * 7919 + (dx * 100).toInt()) % 11 - 5
                    val jx = hash * 0.12f * density
                    val jy = ((i * 4909) % 11 - 5) * 0.12f * density
                    specs.add(
                        SegmentSpec(
                            x1 = x1, y1 = y1, x2 = x2, y2 = y2,
                            width = w.coerceAtLeast(0.7f * density),
                            alpha = 0.75f * press,
                            jitterX = jx, jitterY = jy
                        )
                    )
                }

                ToolKind.WATERCOLOR -> {
                    // 水彩筆：雙層水痕渲染 (外層擴散水暈 + 內層主體水色)
                    val outerW = baseWidth * 2.8f * density
                    val innerW = baseWidth * 1.5f * density
                    specs.add(
                        SegmentSpec(
                            x1 = x1, y1 = y1, x2 = x2, y2 = y2,
                            width = outerW,
                            alpha = 0.24f,
                            secondaryWidth = innerW,
                            secondaryAlpha = 0.46f
                        )
                    )
                }
            }
        }
        return specs
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
        density: Float
    ) {
        val segments = computeSegments(points, tool, baseWidth, density)
        if (segments.isEmpty()) return

        val isHighlighter = tool == ToolKind.HIGHLIGHTER
        val blend = if (isHighlighter) BlendMode.Multiply else BlendMode.SrcOver

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
        val segments = computeSegments(points, tool, baseWidth, pxPerDp)
        if (segments.isEmpty()) return

        val origAlpha = paint.alpha
        val origCap = paint.strokeCap
        val origXfer = paint.xfermode

        if (tool == ToolKind.HIGHLIGHTER) {
            paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.MULTIPLY)
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
}
