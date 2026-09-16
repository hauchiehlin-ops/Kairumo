package com.kairumo.padnote.canvas

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * 可拖曳的畫布捲軸（工作項 S-63）。
 *
 * # 為什麼要自己做
 *
 * 與 Apple 端 `CanvasScrollbar.swift` 同一個理由：系統的捲動指示器是
 * **純顯示**的，不接受互動。在純觸控的手機上沒差（直接甩就好），但
 * Kairumo 會跑在平板加鍵鼠、Chromebook、DeX 這些有游標的環境 ——
 * 使用者很自然地想用游標去拖那條捲軸，結果拖不動。
 *
 * 第二個理由對觸控也成立：**長筆記需要知道自己在哪裡。** 一本 20 頁的
 * 筆記在連續模式下捲起來沒有任何位置感，捲軸至少給一個「還有多長」。
 *
 * # 行為
 *
 * - 拖曳滑塊：直接跳到對應位置。
 * - 點軌道：跳到該處（與桌面捲軸一致）。
 * - 滑塊有最小高度：內容很長時不會細到抓不到。
 */
@Composable
fun CanvasScrollbar(
    /** 可見區域佔內容的比例（0…1）。 */
    visibleFraction: Float,
    /** 目前捲動位置比例（0…1）。 */
    scrollFraction: Float,
    modifier: Modifier = Modifier,
    /** 使用者拖曳或點擊時回報新的比例。 */
    onScrub: (Float) -> Unit
) {
    // 內容比視窗短就不顯示 —— 一條永遠滿格的捲軸只是噪音。
    if (visibleFraction >= 0.999f) return

    var dragging by remember { mutableStateOf(false) }
    val barWidth: Dp = 12.dp
    val minThumb: Dp = 44.dp

    BoxWithConstraints(modifier = modifier.width(barWidth).fillMaxHeight()) {
        val track = maxHeight
        val thumb = maxOf(minThumb, track * visibleFraction.coerceIn(0.02f, 1f))
        val travel = (track - thumb).coerceAtLeast(0.dp)
        val y = travel * scrollFraction.coerceIn(0f, 1f)

        val density = androidx.compose.ui.platform.LocalDensity.current
        val trackPx = with(density) { track.toPx() }
        val thumbPx = with(density) { thumb.toPx() }
        val travelPx = (trackPx - thumbPx).coerceAtLeast(1f)
        var dragPx by remember { mutableFloatStateOf(0f) }

        // 軌道
        Box(
            modifier = Modifier
                .fillMaxHeight()
                .width(barWidth)
                .clip(RoundedCornerShape(barWidth / 2))
                .background(
                    MaterialTheme.colorScheme.onSurfaceVariant.copy(
                        alpha = if (dragging) 0.14f else 0.07f
                    )
                )
                .pointerInput(travelPx) {
                    detectTapGestures { offset ->
                        // 點軌道：讓滑塊中心對到點擊處，與桌面捲軸一致。
                        val target = ((offset.y - thumbPx / 2f) / travelPx).coerceIn(0f, 1f)
                        onScrub(target)
                    }
                }
        )

        // 滑塊
        Box(
            modifier = Modifier
                .offset(y = y)
                .size(width = barWidth, height = thumb)
                .clip(RoundedCornerShape(barWidth / 2))
                .background(
                    MaterialTheme.colorScheme.onSurfaceVariant.copy(
                        alpha = if (dragging) 0.70f else 0.40f
                    )
                )
                .pointerInput(travelPx) {
                    detectDragGestures(
                        onDragStart = {
                            dragging = true
                            dragPx = scrollFraction.coerceIn(0f, 1f) * travelPx
                        },
                        onDragEnd = { dragging = false },
                        onDragCancel = { dragging = false }
                    ) { change, delta ->
                        change.consume()
                        dragPx = (dragPx + delta.y).coerceIn(0f, travelPx)
                        onScrub(dragPx / travelPx)
                    }
                }
        )
    }
}
