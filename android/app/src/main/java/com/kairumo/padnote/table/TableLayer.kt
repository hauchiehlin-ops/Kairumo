package com.kairumo.padnote.table

import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.mutableFloatStateOf
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
import com.kairumo.padnote.canvas.StyleHandle
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
            androidx.compose.runtime.key(table.id) {
                TableObjectView(
                    zIndex = zIndexOf(table.id),
                    table, density, table.id == selectedId, onSelect, onEdit, onChanged,
                    interactive = interactive)
            }
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
    // 連續模式：拖到哪一頁就歸哪一頁（單頁模式為 null，照舊夾在本頁）。
    val crossing by androidx.compose.runtime.rememberUpdatedState(com.kairumo.padnote.canvas.LocalPageCrossing.current)
    val editorMode = com.kairumo.padnote.canvas.LocalEditorMode.current
    val isCanvasNavigating = com.kairumo.padnote.canvas.LocalCanvasNavigating.current
    val isTypeMode = editorMode == com.kairumo.padnote.canvas.EditorMode.TYPE
    // 鎖定在畫布上：不能拖曳、旋轉；點選、點兩下編修照常（見 canvas/ObjectLock.kt）。
    val moveLocked = com.kairumo.padnote.canvas.isMoveLocked(table.id)
    val currentTable by androidx.compose.runtime.rememberUpdatedState(table)
    val layout = table.layout()
    // 壓到下方選取物件（表格等）的工具列時讓出觸控，鎖定鈕才點得到（見 canvas/ObjectLock.kt）。
    @Suppress("NAME_SHADOWING") val interactive = interactive &&
        !com.kairumo.padnote.canvas.yieldsToSelectedChrome(table.id, table.x, table.y, table.width, layout.height.toFloat())
    var liveX by remember(table.id, table.x) { mutableFloatStateOf(table.x) }
    var liveY by remember(table.id, table.y) { mutableFloatStateOf(table.y) }
    var liveRotation by remember(table.id, table.rotationDegrees) { mutableFloatStateOf(table.rotationDegrees ?: 0f) }
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

    val rotation = CanvasRotation.normalized(liveRotation)

    // 外層只定位、不旋轉 —— 旋轉把手掛在這一層。
        // 座標的單位是**頁面點**（＝dp），與 Apple 端和 format-spec 一致。
    // 原本當成像素在用，在 density = 1.0 的模擬器上看不出來，真實手機
    // （2～3.5 倍）上會縮到三分之一並擠向左上角。詳見 ShapeLayer 的說明。
    Box(Modifier.offset(liveX.dp, liveY.dp).zIndex(zIndex)) {

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
                    onTap = { onSelect(currentTable.id) },
                    // 點兩下進編輯面板 —— 與 Apple 端一致。
                    onDoubleTap = { onEdit(currentTable) }
                )
            } }
            .gesturesIf(interactive && !moveLocked && (isSelected || isTypeMode) && !isCanvasNavigating) {
                // 不以 isSelected 當鍵：拖曳一開始就 onSelect()，選取狀態一變這段手勢就被重啟、拖到一半被取消（實機回報：方塊拖不動）。
                pointerInput(table.id, isTypeMode, isCanvasNavigating) {
                var base: NoteTable? = null
                var accX = 0f
                var accY = 0f
                val finishDrag: () -> Unit = {
                    val t = currentTable
                    val l = t.layout()
                    val landed = com.kairumo.padnote.canvas.landObject(
                        t.id, liveX, liveY, l.width.toFloat(), l.height.toFloat(), crossing)
                    liveX = landed.x
                    liveY = landed.y
                    t.x = landed.x
                    t.y = landed.y
                    onChanged(t)
                    landed.page?.let { crossing?.moved?.invoke(t.id, it) }
                    crossing?.ended?.invoke()
                }
                detectDragGestures(
                    onDragStart = {
                        if (isCanvasNavigating) return@detectDragGestures
                        val t = currentTable
                        base = t
                        accX = 0f
                        accY = 0f
                        liveX = t.x
                        liveY = t.y
                        onSelect(t.id)
                        crossing?.began?.invoke()
                    },
                    onDragCancel = finishDrag,
                    onDrag = { change, drag ->
                        if (isCanvasNavigating) {
                            base?.let { liveX = it.x; liveY = it.y }
                            crossing?.ended?.invoke()
                            return@detectDragGestures
                        }
                        change.consume()
                        val t0 = base ?: return@detectDragGestures
                        accX += drag.x
                        accY += drag.y
                        val rad = (t0.rotationDegrees ?: 0f) * kotlin.math.PI / 180.0
                        val c = kotlin.math.cos(rad).toFloat()
                        val sn = kotlin.math.sin(rad).toFloat()
                        liveX = t0.x + (accX * c - accY * sn) / density
                        liveY = t0.y + (accX * sn + accY * c) / density
                    },
                    onDragEnd = finishDrag
                )
            } }
    ) {
        TablePreview(table = table, density = density)
    }

        if (isSelected) {
            StyleHandle(
                widthDp = layout.width.toFloat(),
                heightDp = layout.height.toFloat(),
                onTap = { onEdit(currentTable) },
                objectId = table.id
            )

            if (!moveLocked) RotationHandle(
                degrees = rotation,
                widthDp = layout.width.toFloat(),
                heightDp = layout.height.toFloat(),
                density = density,
                onRotate = { deg ->
                    liveRotation = deg
                    currentTable.rotationDegrees = deg
                },
                onCommit = {
                    currentTable.rotationDegrees = liveRotation
                    onChanged(currentTable)
                }
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
                    val displayText = if (line.trim().startsWith("=")) {
                        TableFormulaEvaluator.evaluateCell(line, table.cells, table.rows, table.cols)
                    } else {
                        line
                    }
                    native.drawText(
                        displayText,
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
