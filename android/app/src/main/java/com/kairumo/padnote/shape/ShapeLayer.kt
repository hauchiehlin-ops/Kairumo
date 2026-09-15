package com.kairumo.padnote.shape

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import com.kairumo.padnote.canvas.CanvasRotation
import com.kairumo.padnote.canvas.RotationHandle
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * 畫布上的形狀與連接線（Android）。
 *
 * 外框、連線路徑、箭頭全部照**核心算好的頂點**畫 —— 這一層不做任何幾何。
 * 自己畫一個「差不多的菱形」的話，同一張流程圖在 iPad 上的頂點位置會不一樣，
 * 連接線的落點也就跟著錯。
 */
@Composable
fun ShapeLayer(
    shapes: List<NoteShape>,
    connections: List<NoteConnection>,
    density: Float,
    selectedIds: Set<String>,
    onSelect: (String?) -> Unit,
    onEdit: (NoteShape) -> Unit,
    onChanged: (NoteShape) -> Unit,
    modifier: Modifier = Modifier
) {
    val foreground = MaterialTheme.colorScheme.onSurface

    Box(modifier = modifier) {
        // 連接線先畫 —— 畫在形狀之上的話，線會壓過方塊的邊，看起來像穿幫。
        Canvas(Modifier.fillMaxSize()) {
            val scale = 1f / density
            for (link in connections) {
                val from = shapes.firstOrNull { it.id == link.fromShapeId } ?: continue
                val to = shapes.firstOrNull { it.id == link.toShapeId } ?: continue
                val geometry = ShapeGeometry.connection(from, to) ?: continue
                val color = link.colorHex?.let { parseColor(it) } ?: foreground

                val path = Path().apply {
                    moveTo(geometry.path[0].x * scale, geometry.path[0].y * scale)
                    geometry.path.drop(1).forEach { lineTo(it.x * scale, it.y * scale) }
                }
                drawPath(path, color, style = Stroke(width = link.lineWidth * scale))

                if (geometry.arrowHead.size >= 3) {
                    val head = Path().apply {
                        moveTo(geometry.arrowHead[0].x * scale, geometry.arrowHead[0].y * scale)
                        geometry.arrowHead.drop(1).forEach { lineTo(it.x * scale, it.y * scale) }
                        close()
                    }
                    drawPath(head, color)
                }
            }
        }

        for (shape in shapes) {
            ShapeObjectView(
                shape, density, selectedIds.contains(shape.id), onSelect, onEdit, onChanged)
        }
    }
}

@Composable
private fun ShapeObjectView(
    shape: NoteShape,
    density: Float,
    isSelected: Boolean,
    onSelect: (String?) -> Unit,
    onEdit: (NoteShape) -> Unit,
    onChanged: (NoteShape) -> Unit
) {
    val foreground = MaterialTheme.colorScheme.onSurface
    val stroke = shape.strokeColorHex?.let { parseColor(it) } ?: foreground
    val fill = when (val hex = shape.fillColorHex) {
        // "clear" 是哨符不是顏色 —— 走顏色轉換會變成黑色。
        "clear", null -> null
        else -> parseColor(hex)
    }

    val rotation = CanvasRotation.normalized(shape.rotationDegrees ?: 0f)

    // 外層只定位、不旋轉 —— 旋轉把手掛在這一層。
    Box(Modifier.offset((shape.x / density).dp, (shape.y / density).dp)) {

    Box(
        Modifier
            .size((shape.width / density).dp, (shape.height / density).dp)
            // 整個視圖一起轉（輪廓 + 標籤）。核心的 outline 刻意不轉：
            // 只轉輪廓的話標籤會留在正的，而且轉過的輪廓會超出畫布被裁掉。
            .graphicsLayer { rotationZ = rotation }
            .border(
                if (isSelected) 1.dp else 0.dp,
                MaterialTheme.colorScheme.primary,
                RoundedCornerShape(2.dp)
            )
            .pointerInput(shape.id) {
                detectTapGestures(
                    onTap = { onSelect(shape.id) },
                    onDoubleTap = { onEdit(shape) }
                )
            }
            .pointerInput(shape.id) {
                detectDragGestures { change, drag ->
                    change.consume()
                    onChanged(
                        shape.copyShape().apply {
                            x = shape.x + drag.x * density
                            y = shape.y + drag.y * density
                        }
                    )
                }
            },
        contentAlignment = Alignment.Center
    ) {
        Canvas(Modifier.fillMaxSize()) {
            val points = shape.outline()
            if (points.size < 2) return@Canvas
            val scale = 1f / density
            val linear = shape.isLinear
            val path = Path().apply {
                // 頂點是畫布座標，這個 Canvas 的原點在物件左上角 —— 要減掉偏移。
                moveTo((points[0].x - shape.x) * scale, (points[0].y - shape.y) * scale)
                points.drop(1).forEach {
                    lineTo((it.x - shape.x) * scale, (it.y - shape.y) * scale)
                }
                // 線狀形狀（線／箭頭／雙箭頭）只有兩個點，不能收尾也不能填色。
                if (!linear) close()
            }
            if (!linear) fill?.let { drawPath(path, it) }
            drawPath(path, stroke, style = Stroke(width = shape.lineWidth * scale))

            for (head in shape.arrowHeads()) {
                val tri = Path().apply {
                    moveTo((head[0].x - shape.x) * scale, (head[0].y - shape.y) * scale)
                    head.drop(1).forEach {
                        lineTo((it.x - shape.x) * scale, (it.y - shape.y) * scale)
                    }
                    close()
                }
                drawPath(tri, stroke)
            }
        }

        if (shape.acceptsText && shape.label.isNotEmpty()) {
            Text(
                shape.label,
                color = foreground,
                fontSize = 14.sp,
                textAlign = TextAlign.Center
            )
        }
    }

        if (isSelected) {
            RotationHandle(
                degrees = rotation,
                widthDp = shape.width / density,
                heightDp = shape.height / density,
                density = density,
                onRotate = { deg ->
                    onChanged(shape.copyShape().apply { rotationDegrees = deg })
                },
                onCommit = { onChanged(shape) }
            )
        }
    }
}

private fun parseColor(hex: String): Color? =
    com.kairumo.padnote.chart.ChartRenderer.parseColor(hex)?.let { Color(it) }
