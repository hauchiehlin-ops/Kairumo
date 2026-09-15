package com.kairumo.padnote.table

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.kairumo.padnote.canvas.gesturesIf
import androidx.compose.ui.graphics.graphicsLayer
import com.kairumo.padnote.canvas.CanvasRotation
import com.kairumo.padnote.canvas.RotationHandle
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp

/**
 * 畫布上的表格圖層（Android）。
 *
 * 格線與文字都照**核心算好的位置**畫 —— 這一層不做任何排版。自己再斷一次行
 * 的話，同一張表在 iPad 與 Android 上的高度會不一樣，而表格的高度會影響它
 * 底下的東西，整頁版面就分家了。
 *
 * 對照 `apple/Sources/TableStudioView.swift` 的 `NoteTableView`。
 */
@Composable
fun TableLayer(
    /**
     * 這一層要不要吃觸控。
     *
     * 手寫模式下一律 false：使用者拿筆想在物件上圈重點，筆畫要到得了
     * 底下的畫布。與 Apple 端 `allowsHitTesting(editorMode != .draw)`
     * 是同一條規則 —— 兩邊不一致的話，同一個人換裝置就會發現
     * 「在 iPad 上圈得到重點，在 Android 上圈不到」。
     */
    interactive: Boolean,
    tables: List<NoteTable>,
    density: Float,
    selectedId: String?,
    onSelect: (String?) -> Unit,
    onEdit: (NoteTable) -> Unit,
    onChanged: (NoteTable) -> Unit,
    modifier: Modifier = Modifier
) {
    Box(modifier = modifier) {
        for (table in tables) {
            TableObjectView(
                table, density, table.id == selectedId, onSelect, onEdit, onChanged,
                interactive = interactive)
        }
    }
}

@Composable
private fun TableObjectView(
    table: NoteTable,
    density: Float,
    isSelected: Boolean,
    onSelect: (String?) -> Unit,
    onEdit: (NoteTable) -> Unit,
    onChanged: (NoteTable) -> Unit,
    /** 見同檔案公開版本的說明。 */
    interactive: Boolean = true
) {
    val layout = table.layout()
    val foreground = MaterialTheme.colorScheme.onSurface
    val ruleColor = table.ruleColorHex
        ?.let { hex -> ChartColorOrNull(hex) }
        ?: foreground.copy(alpha = 0.35f)
    val headerFill = when (val hex = table.headerBackgroundHex) {
        // "clear" 是哨符不是顏色 —— 走顏色轉換會變成黑色。
        "clear" -> Color.Transparent
        null -> foreground.copy(alpha = 0.06f)
        else -> ChartColorOrNull(hex) ?: foreground.copy(alpha = 0.06f)
    }

    val rotation = CanvasRotation.normalized(table.rotationDegrees ?: 0f)

    // 外層只定位、不旋轉 —— 旋轉把手掛在這一層。
        // 座標的單位是**頁面點**（＝dp），與 Apple 端和 format-spec 一致。
    // 原本當成像素在用，在 density = 1.0 的模擬器上看不出來，真實手機
    // （2～3.5 倍）上會縮到三分之一並擠向左上角。詳見 ShapeLayer 的說明。
    Box(Modifier.offset(table.x.dp, table.y.dp)) {

    Box(
        Modifier
            .size(layout.width.toFloat().dp, layout.height.toFloat().dp)
            // 整個表格一起轉（格線 + 文字）。
            .graphicsLayer { rotationZ = rotation }
            .border(
                if (isSelected) 1.5.dp else 0.dp,
                MaterialTheme.colorScheme.primary,
                RoundedCornerShape(4.dp)
            )
            .gesturesIf(interactive) { pointerInput(table.id) {
                detectTapGestures(
                    onTap = { onSelect(table.id) },
                    // 點兩下進編輯面板 —— 與 Apple 端一致。
                    onDoubleTap = { onEdit(table) }
                )
            } }
            .gesturesIf(interactive) { pointerInput(table.id) {
                detectDragGestures { change, drag ->
                    change.consume()
                    onChanged(
                        table.copyTable().apply {
                            x = table.x + drag.x / density
                            y = table.y + drag.y / density
                        }
                    )
                }
            } }
    ) {
        Canvas(Modifier.size(layout.width.toFloat().dp, layout.height.toFloat().dp)) {
            // Canvas 內部是像素，版面是頁面點 —— 乘上 density。
            val scale = density
            // 表頭底色先畫，才會在格線與文字下面。
            for (cell in layout.cells) {
                if (!cell.isHeader) continue
                drawRect(
                    color = headerFill,
                    topLeft = Offset((cell.x * scale).toFloat(), (cell.y * scale).toFloat()),
                    size = Size((cell.width * scale).toFloat(), (cell.height * scale).toFloat())
                )
            }

            drawIntoCanvas { canvas ->
                val native = canvas.nativeCanvas
                val stroke = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
                    style = android.graphics.Paint.Style.STROKE
                    strokeWidth = 1f
                    color = ruleColor.toArgb()
                }
                for (rule in layout.rules) {
                    native.drawLine(
                        (rule.x1 * scale).toFloat(), (rule.y1 * scale).toFloat(),
                        (rule.x2 * scale).toFloat(), (rule.y2 * scale).toFloat(), stroke
                    )
                }

                val text = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
                    color = foreground.toArgb()
                    textSize = table.fontSize * scale
                }
                val lineHeight = table.fontSize * 1.35f * scale
                for (cell in layout.cells) {
                    text.isFakeBoldText = cell.isHeader
                    var baseline = (cell.y * scale).toFloat() + lineHeight
                    for (line in cell.lines) {
                        native.drawText(
                            line,
                            (cell.x * scale).toFloat() + 6f * scale,
                            baseline,
                            text
                        )
                        baseline += lineHeight
                    }
                }
            }
        }
    }

        if (isSelected) {
            RotationHandle(
                degrees = rotation,
                widthDp = layout.width.toFloat(),
                heightDp = layout.height.toFloat(),
                density = density,
                onRotate = { deg ->
                    onChanged(table.copyTable().apply { rotationDegrees = deg })
                },
                onCommit = { onChanged(table) }
            )
        }
    }
}

/** 解析 `#RRGGBB`，失敗時回 `null`（讓呼叫端自己挑 fallback）。 */
private fun ChartColorOrNull(hex: String): Color? =
    com.kairumo.padnote.chart.ChartRenderer.parseColor(hex)?.let { Color(it) }
