package com.kairumo.padnote.chart

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
import com.kairumo.padnote.canvas.MIN_OBJECT_HEIGHT_DP
import com.kairumo.padnote.canvas.MIN_OBJECT_WIDTH_DP
import com.kairumo.padnote.canvas.ResizeHandle
import com.kairumo.padnote.canvas.StyleHandle
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex

/**
 * 畫布上的圖表圖層（Android）。
 *
 * 圖表是**從設定即時畫出來的**，不是貼一張存好的點陣圖：縮放時不會糊，
 * 改了數字立刻反映，而且點兩下就能回到編輯器 —— 點陣圖做不到最後這件事。
 *
 * 與 Apple 端一致：位置以頁面座標（點）表示，乘上 [density] 才是螢幕像素。
 */
@Composable
fun ChartLayer(
    /**
     * 這一層要不要吃觸控。
     *
     * 手寫模式下一律 false：使用者拿筆想在物件上圈重點，筆畫要到得了
     * 底下的畫布。與 Apple 端 `allowsHitTesting(editorMode != .draw)`
     * 是同一條規則 —— 兩邊不一致的話，同一個人換裝置就會發現
     * 「在 iPad 上圈得到重點，在 Android 上圈不到」。
     */
    interactive: Boolean,
    charts: List<ChartObject>,
    density: Float,
    selectedId: String?,
    onSelect: (String?) -> Unit,
    onEdit: (ChartObject) -> Unit,
    onChanged: (ChartObject) -> Unit,
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
        for (chart in charts) {
            ChartObjectView(
                chart, density, chart.id == selectedId, onSelect, onEdit, onChanged,
                interactive = interactive, zIndex = zIndexOf(chart.id))
        }
}

@Composable
private fun ChartObjectView(
    chart: ChartObject,
    density: Float,
    isSelected: Boolean,
    onSelect: (String?) -> Unit,
    onEdit: (ChartObject) -> Unit,
    onChanged: (ChartObject) -> Unit,
    /** 見同檔案公開版本的說明。 */
    interactive: Boolean = true,
    /** 堆疊 z 值，見 ObjectStacking。 */
    zIndex: Float = 0f
) {
    val foreground = MaterialTheme.colorScheme.onSurface
    val grid = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.14f)

    // **把手必須在這個定位過的外層 Box 裡面。**
    //
    // 原本把手與圖表是兄弟：圖表自己 `offset(chart.x, chart.y)`，而把手沒有 ——
    // 於是樣式（編輯）鈕永遠畫在畫布左上角附近，離圖表很遠，
    // 使用者按右下／左下的編輯鈕「沒有作用」，其實是根本沒按到那顆鈕。
    // 圖片、表格、文字方塊都是「外層定位、內層畫內容、把手在外層裡」，圖表跟上同一個結構。
    Box(Modifier.offset(chart.x.dp, chart.y.dp).zIndex(zIndex)) {
        Box(
            Modifier
                .size(chart.width.dp, chart.height.dp)
                .border(
                    if (isSelected) 1.5.dp else 0.dp,
                    MaterialTheme.colorScheme.primary,
                    RoundedCornerShape(6.dp)
                )
                .gesturesIf(interactive) { pointerInput(chart.id) {
                    detectTapGestures(
                        onTap = { onSelect(chart.id) },
                        // 點兩下進編輯器 —— 這就是「可重新編修」在畫布上的入口。
                        onDoubleTap = { onEdit(chart) }
                    )
                } }
                .gesturesIf(interactive) { pointerInput(chart.id) {
                    detectDragGestures { change, drag ->
                        change.consume()
                        onChanged(
                            chart.copy(
                                x = chart.x + drag.x / density,
                                y = chart.y + drag.y / density
                            )
                        )
                    }
                } }
        ) {
            Canvas(Modifier.size(chart.width.dp, chart.height.dp)) {
                val layout = ChartRenderer.layout(chart.spec, size.width, size.height) ?: return@Canvas
                drawIntoCanvas { canvas ->
                    ChartRenderer.draw(
                        layout, canvas.nativeCanvas,
                        foreground = foreground.toArgb(),
                        gridColor = grid.toArgb()
                    )
                }
            }
        }

        if (isSelected && interactive) {
            StyleHandle(
                widthDp = chart.width,
                heightDp = chart.height,
                onTap = { onEdit(chart) },
                objectId = chart.id
            )
            // 縮放把手。圖表原本只能搬、不能縮放（Apple 端的圖表是圖片物件，有四角把手）。
            ResizeHandle(
                widthDp = chart.width,
                heightDp = chart.height,
                density = density,
                onResize = { dw, dh ->
                    onChanged(
                        chart.copy(
                            width = maxOf(MIN_OBJECT_WIDTH_DP, chart.width + dw),
                            height = maxOf(MIN_OBJECT_HEIGHT_DP, chart.height + dh)
                        )
                    )
                },
                onCommit = {}
            )
        }
    }
}
