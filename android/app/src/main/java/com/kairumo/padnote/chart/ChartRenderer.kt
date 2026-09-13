package com.kairumo.padnote.chart

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import uniffi.padnote_core.FfiChartLayout
import uniffi.padnote_core.FfiChartLine
import uniffi.padnote_core.FfiChartPoint
import uniffi.padnote_core.FfiChartPolyline
import uniffi.padnote_core.FfiTextAlign
import uniffi.padnote_core.chartLayout
import uniffi.padnote_core.chartPaletteColor

/**
 * 把核心算好的圖表幾何畫出來。
 *
 * # 這裡不做任何計算
 *
 * 每一個座標都來自核心的 `chartLayout(...)`，跟 Apple 端用的是同一支。
 * 一旦在這裡多算一步（哪怕只是把長條往上挪兩點），iPad 就不會跟著挪，
 * 同一份筆記在兩個平台上就長得不一樣了 —— 而那種不一致只有使用者會發現。
 *
 * 對照 `apple/Sources/ChartRenderer.swift`：兩邊畫的是同一組形狀，差別只在
 * 用的是各自的原生繪圖 API。
 */
object ChartRenderer {

    /** 算出一張圖的版面。規格有問題時回 `null` —— 呼叫端要顯示原因，不是畫一張空圖。 */
    fun layout(spec: ChartSpec, width: Float, height: Float): FfiChartLayout? =
        runCatching { chartLayout(spec.encodedJson(), width.toDouble(), height.toDouble()) }.getOrNull()

    /** 算不出來的原因，可以直接顯示給使用者。 */
    fun failureReason(spec: ChartSpec, width: Float, height: Float): String? =
        runCatching {
            chartLayout(spec.encodedJson(), width.toDouble(), height.toDouble())
            null
        }.getOrElse { it.message ?: it.toString() }

    /**
     * 把版面畫進一個畫布。
     *
     * @param foreground 文字與軸線的顏色。傳進來而不是寫死，圖表才會跟著深淺色
     *   模式走 —— 插入畫布的點陣圖則固定用深色，因為紙張永遠是淺的。
     */
    fun draw(layout: FfiChartLayout, canvas: Canvas, foreground: Int, gridColor: Int) {
        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
        val text = Paint(Paint.ANTI_ALIAS_FLAG)

        // 格線先畫，才會被資料蓋住而不是浮在上面。
        stroke.color = gridColor
        stroke.strokeWidth = 1f
        layout.gridLines.forEach { canvas.drawLineSegment(it, stroke) }

        stroke.color = foreground.withAlpha(0.55f)
        stroke.strokeWidth = 1.5f
        layout.axisLines.forEach { canvas.drawLineSegment(it, stroke) }
        layout.radarSpokes.forEach { canvas.drawLineSegment(it, stroke) }

        // 雷達的同心圈是封閉多邊形，不是圓。
        stroke.color = gridColor
        stroke.strokeWidth = 1f
        layout.radarRings.filter { it.size > 2 }.forEach { ring ->
            val path = Path()
            path.moveTo(ring[0].x.toFloat(), ring[0].y.toFloat())
            ring.drop(1).forEach { path.lineTo(it.x.toFloat(), it.y.toFloat()) }
            path.close()
            canvas.drawPath(path, stroke)
        }

        // 刻度
        stroke.color = foreground.withAlpha(0.45f)
        stroke.strokeWidth = 1.5f
        (layout.xTicks + layout.yTicks).forEach { tick ->
            canvas.drawLine(tick.x.toFloat(), tick.y.toFloat(), tick.x2.toFloat(), tick.y2.toFloat(), stroke)
            canvas.drawChartText(
                tick.label, tick.labelX, tick.labelY, 11.0,
                tick.align, foreground.withAlpha(0.75f), 0.0, text
            )
        }

        // 長條
        layout.bars.filter { it.width > 0 && it.height > 0 }.forEach { bar ->
            fill.color = parseColor(bar.colorHex) ?: Color.BLUE
            // 高度不到圓角兩倍時不要圓角，否則細長條會縮成一顆藥丸。
            val radius = minOf(3.0, minOf(bar.width, bar.height) / 2).toFloat()
            val rect = RectF(
                bar.x.toFloat(), bar.y.toFloat(),
                (bar.x + bar.width).toFloat(), (bar.y + bar.height).toFloat()
            )
            canvas.drawRoundRect(rect, radius, radius, fill)
        }

        // 圓餅與環圈
        layout.slices.forEach { slice ->
            // 核心的角度以正上方為 0、順時針為正；Android 從 +x 軸起算、用「度」。
            val start = Math.toDegrees(slice.startAngle) - 90.0
            val sweep = Math.toDegrees(slice.endAngle - slice.startAngle)
            val outer = RectF(
                (slice.centerX - slice.radius).toFloat(), (slice.centerY - slice.radius).toFloat(),
                (slice.centerX + slice.radius).toFloat(), (slice.centerY + slice.radius).toFloat()
            )
            val path = Path()
            if (slice.innerRadius > 0) {
                val inner = RectF(
                    (slice.centerX - slice.innerRadius).toFloat(),
                    (slice.centerY - slice.innerRadius).toFloat(),
                    (slice.centerX + slice.innerRadius).toFloat(),
                    (slice.centerY + slice.innerRadius).toFloat()
                )
                path.arcTo(outer, start.toFloat(), sweep.toFloat(), true)
                path.arcTo(inner, (start + sweep).toFloat(), (-sweep).toFloat(), false)
            } else {
                path.moveTo(slice.centerX.toFloat(), slice.centerY.toFloat())
                path.arcTo(outer, start.toFloat(), sweep.toFloat(), false)
            }
            path.close()

            fill.color = parseColor(slice.colorHex) ?: Color.BLUE
            canvas.drawPath(path, fill)
            // 白色分隔線：相鄰的扇形顏色再不同，沒有縫隙時還是會黏成一塊。
            stroke.color = Color.argb(230, 255, 255, 255)
            stroke.strokeWidth = 1.5f
            canvas.drawPath(path, stroke)
        }

        // 折線與區域
        layout.polylines.filter { it.points.size > 1 }.forEach { line ->
            val color = parseColor(line.colorHex) ?: Color.BLUE
            val path = if (line.smooth) smoothPath(line.points) else straightPath(line.points)

            line.fillToY?.let { baseline ->
                val area = Path(path)
                area.lineTo(line.points.last().x.toFloat(), baseline.toFloat())
                area.lineTo(line.points.first().x.toFloat(), baseline.toFloat())
                area.close()
                fill.color = color.withAlpha(0.25f)
                canvas.drawPath(area, fill)
            }

            stroke.color = color
            stroke.strokeWidth = 3f
            canvas.drawPath(path, stroke)

            if (line.showMarkers) {
                fill.color = color
                line.points.forEach { canvas.drawCircle(it.x.toFloat(), it.y.toFloat(), 3.5f, fill) }
            }
        }

        // 散佈
        layout.scatterPoints.forEach { point ->
            fill.color = parseColor(chartPaletteColor(point.seriesIndex)) ?: Color.BLUE
            canvas.drawCircle(point.x.toFloat(), point.y.toFloat(), 5f, fill)
        }

        // 圖例
        layout.legend.forEach { entry ->
            fill.color = parseColor(entry.colorHex) ?: Color.BLUE
            val rect = RectF(
                entry.swatchX.toFloat(), entry.swatchY.toFloat(),
                (entry.swatchX + entry.swatchSize).toFloat(),
                (entry.swatchY + entry.swatchSize).toFloat()
            )
            canvas.drawRoundRect(rect, 2f, 2f, fill)
            canvas.drawChartText(
                entry.text, entry.textX, entry.textY, 11.0,
                FfiTextAlign.LEADING, foreground, 0.0, text
            )
        }

        // 標題、軸標題、資料標籤
        layout.labels.forEach { label ->
            canvas.drawChartText(
                label.text, label.x, label.y, label.fontSize, label.align,
                parseColor(label.colorHex) ?: foreground, label.rotation, text
            )
        }
    }

    /**
     * 通過每一點的平滑曲線（Catmull-Rom 轉三次貝茲）。
     *
     * 用 Catmull-Rom 而不是隨手取中點：曲線必須**通過**每一個資料點。
     * 不通過資料點的「平滑曲線」畫的是一組不存在的數字。
     * Apple 端用同一條公式。
     */
    private fun smoothPath(points: List<FfiChartPoint>): Path {
        val path = Path()
        path.moveTo(points[0].x.toFloat(), points[0].y.toFloat())
        for (i in 0 until points.size - 1) {
            val p0 = points[maxOf(0, i - 1)]
            val p1 = points[i]
            val p2 = points[i + 1]
            val p3 = points[minOf(points.size - 1, i + 2)]
            path.cubicTo(
                (p1.x + (p2.x - p0.x) / 6).toFloat(), (p1.y + (p2.y - p0.y) / 6).toFloat(),
                (p2.x - (p3.x - p1.x) / 6).toFloat(), (p2.y - (p3.y - p1.y) / 6).toFloat(),
                p2.x.toFloat(), p2.y.toFloat()
            )
        }
        return path
    }

    private fun straightPath(points: List<FfiChartPoint>): Path {
        val path = Path()
        path.moveTo(points[0].x.toFloat(), points[0].y.toFloat())
        points.drop(1).forEach { path.lineTo(it.x.toFloat(), it.y.toFloat()) }
        return path
    }

    private fun Canvas.drawLineSegment(line: FfiChartLine, paint: Paint) {
        drawLine(line.x1.toFloat(), line.y1.toFloat(), line.x2.toFloat(), line.y2.toFloat(), paint)
    }

    private fun Canvas.drawChartText(
        content: String, x: Double, y: Double, size: Double,
        align: FfiTextAlign, color: Int, rotation: Double, paint: Paint
    ) {
        if (content.isEmpty()) return
        paint.color = color
        paint.textSize = size.toFloat()
        paint.textAlign = when (align) {
            FfiTextAlign.LEADING -> Paint.Align.LEFT
            FfiTextAlign.CENTER -> Paint.Align.CENTER
            FfiTextAlign.TRAILING -> Paint.Align.RIGHT
        }
        if (rotation == 0.0) {
            drawText(content, x.toFloat(), y.toFloat(), paint)
        } else {
            save()
            translate(x.toFloat(), y.toFloat())
            rotate(Math.toDegrees(rotation).toFloat())
            drawText(content, 0f, 0f, paint)
            restore()
        }
    }

    /**
     * 解析 `#RRGGBB`。
     *
     * 解析不出來時回 `null` 讓呼叫端自己挑 fallback，而不是悄悄畫成黑色 ——
     * 悄悄畫成黑色的話，色盤壞掉時整張圖會是一片黑而沒有人知道為什麼。
     */
    fun parseColor(hex: String): Int? {
        if (hex.isEmpty()) return null
        return runCatching { Color.parseColor(if (hex.startsWith("#")) hex else "#$hex") }.getOrNull()
    }

    private fun Int.withAlpha(fraction: Float): Int =
        Color.argb(
            (255 * fraction).toInt().coerceIn(0, 255),
            Color.red(this), Color.green(this), Color.blue(this)
        )

    /**
     * 算繪成點陣圖，給插入畫布與匯出用。
     *
     * 文字固定用深色：這張圖會落在紙張上，而紙張永遠是淺的 —— 跟著系統深色
     * 模式走的話，在深色模式下插入的圖表印出來會是一片看不見的深灰。
     */
    fun bitmap(spec: ChartSpec, width: Int, height: Int, scale: Float = 3f): Bitmap? {
        val layout = layout(spec, width.toFloat(), height.toFloat()) ?: return null
        val bitmap = Bitmap.createBitmap(
            (width * scale).toInt(), (height * scale).toInt(), Bitmap.Config.ARGB_8888
        )
        val canvas = Canvas(bitmap)
        canvas.scale(scale, scale)
        draw(
            layout, canvas,
            foreground = Color.rgb(28, 28, 28),
            gridColor = Color.argb(36, 28, 28, 28)
        )
        return bitmap
    }
}
