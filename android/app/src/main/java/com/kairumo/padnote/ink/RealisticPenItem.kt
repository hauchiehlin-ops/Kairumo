package com.kairumo.padnote.ink

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.LocalizationStrings
import uniffi.padnote_core.FfiGradientStop
import uniffi.padnote_core.FfiIconShape
import uniffi.padnote_core.FfiPaint
import uniffi.padnote_core.FfiTool
import uniffi.padnote_core.brushIcon
import uniffi.padnote_core.brushPreviewDabs

/**
 * 工具列上的一顆筆：向量圖示、示範筆跡、選取時凸起。
 *
 * 圖示與示範筆跡都由核心提供（`brushIcon`、`brushPreviewDabs`）—— 圖示是
 * `assets/brushes` 資料夾裡的 SVG 解析出來的路徑指令，筆跡預覽是同一份筆點陣。
 * Apple 畫的是同一組資料，所以兩台裝置上每支筆長得一樣。
 */
@Composable
fun RealisticPenItem(
    tool: InkTool,
    isSelected: Boolean,
    inkColor: Color,
    languageTag: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    // 選取時向上抬升，彈簧曲線。
    val offsetY by animateDpAsState(
        targetValue = if (isSelected) (-6).dp else 0.dp,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessLow),
        label = "penElevation"
    )
    val toolLabel = LocalizationStrings.localized(tool.labelKey, languageTag)
    val ffiTool = remember(tool) { tool.ffiTool }
    val shapes = remember(tool) { brushIcon(ffiTool) }

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = modifier
            .testTag(tool.parityIdentifier)
            .clickable(onClick = onClick)
            .padding(horizontal = 3.dp, vertical = 2.dp)
            .semantics {
                contentDescription = toolLabel
                stateDescription = if (isSelected) "selected" else "unselected"
            }
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .offset(y = offsetY)
                .then(
                    if (isSelected) Modifier.shadow(4.dp, shape = MaterialTheme.shapes.extraSmall) else Modifier
                )
                .size(44.dp)
        ) {
            Canvas(modifier = Modifier.size(44.dp)) { drawIcon(shapes, inkColor) }
        }
        if (tool.family != null) {
            Canvas(modifier = Modifier.width(44.dp).height(14.dp)) {
                drawPreview(ffiTool, inkColor, size)
            }
        }
        Text(
            text = toolLabel,
            fontSize = 9.sp,
            color = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 2.dp)
        )
    }
}

/** 族與族之間的分隔線。 */
@Composable
fun BrushFamilyDivider() {
    Box(
        modifier = Modifier
            .width(1.dp)
            .height(54.dp)
            .background(MaterialTheme.colorScheme.outlineVariant)
    )
}

/** 對應核心的工具列項目。 */
val InkTool.ffiTool: FfiTool
    get() = when (this) {
        InkTool.FOUNTAIN_PEN -> FfiTool.PEN
        InkTool.BALLPOINT -> FfiTool.BALL_POINT
        InkTool.FINELINER -> FfiTool.FINELINER
        InkTool.BRUSH -> FfiTool.BRUSH
        InkTool.CALLIGRAPHY -> FfiTool.CALLIGRAPHY
        InkTool.PENCIL -> FfiTool.PENCIL
        InkTool.CHARCOAL -> FfiTool.CHARCOAL
        InkTool.CRAYON -> FfiTool.CRAYON
        InkTool.AIRBRUSH -> FfiTool.AIRBRUSH
        InkTool.OIL_PAINT -> FfiTool.OIL_PAINT
        InkTool.WATERCOLOR -> FfiTool.WATERCOLOR
        InkTool.MARKER -> FfiTool.MARKER
        InkTool.HIGHLIGHTER -> FfiTool.HIGHLIGHTER
        InkTool.ERASER -> FfiTool.ERASER
        InkTool.LASSO -> FfiTool.LASSO
        InkTool.MASKING_TAPE -> FfiTool.MASKING_TAPE
    }

private const val ICON_VIEWBOX = 48f

/** 色標的顏色：固定 RGB，或筆色再向黑／白偏 `shade`（-1…1）。 */
private fun stopColor(stop: FfiGradientStop, ink: Color): Color {
    val base = if (stop.ink) ink else Color(stop.r.toInt(), stop.g.toInt(), stop.b.toInt())
    val target = if (stop.shade >= 0f) 1f else 0f
    val k = kotlin.math.abs(stop.shade)
    return Color(
        red = base.red + (target - base.red) * k,
        green = base.green + (target - base.green) * k,
        blue = base.blue + (target - base.blue) * k,
        alpha = stop.alpha
    )
}

/** 填色或描邊用的 Brush。`None` 回 null。 */
private fun paintBrush(paint: FfiPaint, ink: Color, point: (Float, Float) -> Offset, scale: Float): Brush? = when (paint) {
    is FfiPaint.None -> null
    is FfiPaint.Ink -> SolidColor(ink)
    is FfiPaint.Color -> SolidColor(Color(paint.r.toInt(), paint.g.toInt(), paint.b.toInt()))
    is FfiPaint.Linear -> Brush.linearGradient(
        colorStops = paint.stops.map { it.offset to stopColor(it, ink) }.toTypedArray(),
        start = point(paint.x1, paint.y1),
        end = point(paint.x2, paint.y2)
    )
    is FfiPaint.Radial -> Brush.radialGradient(
        colorStops = paint.stops.map { it.offset to stopColor(it, ink) }.toTypedArray(),
        center = point(paint.cx, paint.cy),
        radius = paint.r * scale
    )
}

private fun DrawScope.drawIcon(shapes: List<FfiIconShape>, ink: Color) {
    val scale = minOf(size.width, size.height) / ICON_VIEWBOX
    val ox = (size.width - ICON_VIEWBOX * scale) / 2f
    val oy = (size.height - ICON_VIEWBOX * scale) / 2f
    val point = { x: Float, y: Float -> Offset(ox + x * scale, oy + y * scale) }
    for (shape in shapes) {
        val path = Path()
        for (cmd in shape.commands) {
            val a = cmd.args
            when (cmd.op) {
                "M" -> path.moveTo(ox + a[0] * scale, oy + a[1] * scale)
                "L" -> path.lineTo(ox + a[0] * scale, oy + a[1] * scale)
                "C" -> path.cubicTo(
                    ox + a[0] * scale, oy + a[1] * scale, ox + a[2] * scale, oy + a[3] * scale,
                    ox + a[4] * scale, oy + a[5] * scale
                )
                "Z" -> path.close()
            }
        }
        paintBrush(shape.fill, ink, point, scale)?.let { drawPath(path, it, alpha = shape.opacity) }
        paintBrush(shape.stroke, ink, point, scale)?.let {
            drawPath(
                path, it, alpha = shape.opacity,
                style = Stroke(
                    width = shape.strokeWidth * scale,
                    cap = if (shape.roundCap) StrokeCap.Round else StrokeCap.Butt,
                    join = StrokeJoin.Round
                )
            )
        }
    }
}

/** 一小段示範筆跡。 */
private fun DrawScope.drawPreview(tool: FfiTool, ink: Color, size: Size) {
    val dabs = brushPreviewDabs(tool, size.width, size.height)
    for (dab in dabs) {
        val s = dab.shade
        val target = if (s >= 0f) 1f else 0f
        val k = kotlin.math.abs(s) * 0.35f
        val color = Color(
            red = ink.red + (target - ink.red) * k,
            green = ink.green + (target - ink.green) * k,
            blue = ink.blue + (target - ink.blue) * k
        )
        rotate(Math.toDegrees(dab.angle.toDouble()).toFloat(), Offset(dab.x, dab.y)) {
            if (dab.softness > 0.5f) {
                for (step in 0 until 4) {
                    val f = 1f - step * 0.22f
                    drawOval(
                        color.copy(alpha = dab.alpha * 0.34f),
                        topLeft = Offset(dab.x - dab.rx * f, dab.y - dab.ry * f),
                        size = Size(dab.rx * f * 2f, dab.ry * f * 2f)
                    )
                }
            } else {
                drawOval(
                    color.copy(alpha = dab.alpha),
                    topLeft = Offset(dab.x - dab.rx, dab.y - dab.ry),
                    size = Size(dab.rx * 2f, dab.ry * 2f)
                )
            }
        }
    }
}
