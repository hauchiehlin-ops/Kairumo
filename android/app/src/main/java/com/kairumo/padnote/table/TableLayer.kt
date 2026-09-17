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
import androidx.compose.ui.zIndex

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
    /**
     * 這個物件的堆疊 z 值。跨型別共用同一份順序（見 ObjectStacking）。
     */
    zIndexOf: (String) -> Float,
    modifier: Modifier = Modifier
) {
    // **不包一層自己的 Box。**
    //
    // Compose 的 zIndex 只在**同一個父容器的兄弟之間**生效。每一層各包一個 Box
    // 的話，圖片的 zIndex 只跟圖片比、文字的只跟文字比 —— 跨型別永遠是
    // 「圖片一定在文字下面」，圖層面板就排不動。
    // 直接把物件發到呼叫端的 Box 裡，它們才是彼此的兄弟。
        for (table in tables) {
            TableObjectView(
                zIndex = zIndexOf(table.id),
                table, density, table.id == selectedId, onSelect, onEdit, onChanged,
                interactive = interactive)
        }
}

@Composable
private fun TableObjectView(
    /** 堆疊 z 值，見 ObjectStacking。 */
    zIndex: Float,
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
    Box(Modifier.offset(table.x.dp, table.y.dp).zIndex(zIndex)) {

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
                detectDragGestures(
                    onDrag = { change, drag ->
                        change.consume()
                        onChanged(
                            table.copyTable().apply {
                                x = table.x + drag.x / density
                                y = table.y + drag.y / density
                            }
                        )
                    },
                    onDragEnd = {
                        val landed = com.kairumo.padnote.ink.PageGeometry
                            .clampOrigin(table.x, table.y, layout.width.toFloat(), layout.height.toFloat())
                        table.x = landed.first
                        table.y = landed.second
                        onChanged(table)
                    }
                )
            } }
    ) {
        TablePreview(table = table, density = density)
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

/**
 * 把一張表畫出來（不含選取、拖曳與旋轉）。
 *
 * 畫布上的表格物件與**編修面板的預覽**走同一份算繪 —— 各畫一份的話，
 * 面板上看到的與插進去得到的會慢慢分岔，而那正是預覽最不該出現的事。
 */
@Composable
fun TablePreview(
    table: NoteTable,
    density: Float,
    modifier: Modifier = Modifier
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

    Canvas(
        modifier.size(layout.width.toFloat().dp, layout.height.toFloat().dp)
    ) {
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

/** 解析 `#RRGGBB`，失敗時回 `null`（讓呼叫端自己挑 fallback）。 */
private fun ChartColorOrNull(hex: String): Color? =
    com.kairumo.padnote.chart.ChartRenderer.parseColor(hex)?.let { Color(it) }
