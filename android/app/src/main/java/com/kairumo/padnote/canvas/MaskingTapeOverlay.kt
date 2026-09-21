package com.kairumo.padnote.canvas

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import java.util.UUID
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * 遮蔽膠帶（Masking Tape）資料模型。
 * 對齊 Apple 端 NoteTapeAttachment。
 */
data class NoteTape(
    val id: String = UUID.randomUUID().toString(),
    val pageIndex: Int,
    val x: Float,
    val y: Float,
    val width: Float,
    val height: Float,
    val isRevealed: Boolean = false,
    val colorHex: String = "#FCEEAC"
)

/**
 * 遮蔽膠帶覆蓋層（Masking Tape Overlay）。
 *
 * 在筆記上貼附膠帶以覆蓋文字或考題答案，點一下即可翻開（Reveal）或遮回，
 * 方便背誦或自我測驗。與 Apple 端 MaskingTapeOverlayView 完全對齊。
 */
@Composable
fun MaskingTapeOverlay(
    pageIndex: Int,
    isActive: Boolean,
    tapeColor: Color = Color(0xFFFCEEAC),
    tapes: MutableList<NoteTape>,
    onTapesChanged: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    val density = LocalDensity.current.density
    var dragStart by remember { mutableStateOf<Offset?>(null) }
    var currentDragRect by remember { mutableStateOf<Rect?>(null) }

    Box(
        modifier = modifier
            .fillMaxSize()
            .then(
                if (isActive) {
                    Modifier.pointerInput(Unit) {
                        detectDragGestures(
                            onDragStart = { start ->
                                dragStart = start
                            },
                            onDrag = { change, _ ->
                                val start = dragStart ?: return@detectDragGestures
                                val pos = change.position
                                val x = min(start.x, pos.x) / density
                                val y = (start.y - 20f) / density
                                val width = max(abs(pos.x - start.x) / density, 20f)
                                val height = 36f
                                currentDragRect = Rect(x, y, x + width, y + height)
                            },
                            onDragEnd = {
                                currentDragRect?.let { r ->
                                    tapes.add(
                                        NoteTape(
                                            pageIndex = pageIndex,
                                            x = r.left,
                                            y = r.top,
                                            width = r.width,
                                            height = r.height
                                        )
                                    )
                                    onTapesChanged()
                                }
                                dragStart = null
                                currentDragRect = null
                            },
                            onDragCancel = {
                                dragStart = null
                                currentDragRect = null
                            }
                        )
                    }
                } else {
                    Modifier
                }
            )
    ) {
        val pageTapes = tapes.filter { it.pageIndex == pageIndex }
        for (tape in pageTapes) {
            val tapeAlpha = if (tape.isRevealed) 0.18f else 0.92f
            Box(
                modifier = Modifier
                    .offset {
                        IntOffset(
                            (tape.x * density).toInt(),
                            (tape.y * density).toInt()
                        )
                    }
                    .size((tape.width).dp, (tape.height).dp)
                    .background(
                        tapeColor.copy(alpha = tapeAlpha),
                        shape = RoundedCornerShape(4.dp)
                    )
                    .border(
                        1.dp,
                        tapeColor.copy(alpha = 0.6f),
                        shape = RoundedCornerShape(4.dp)
                    )
                    .clickable {
                        val idx = tapes.indexOfFirst { it.id == tape.id }
                        if (idx >= 0) {
                            tapes[idx] = tape.copy(isRevealed = !tape.isRevealed)
                            onTapesChanged()
                        }
                    }
            ) {
                if (isActive) {
                    IconButton(
                        onClick = {
                            tapes.removeAll { it.id == tape.id }
                            onTapesChanged()
                        },
                        modifier = Modifier
                            .align(Alignment.CenterEnd)
                            .size(24.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "刪除膠帶",
                            tint = Color.DarkGray,
                            modifier = Modifier.size(14.dp)
                        )
                    }
                }
            }
        }

        // 正在拖曳產生的預覽膠帶
        currentDragRect?.let { r ->
            Box(
                modifier = Modifier
                    .offset {
                        IntOffset(
                            (r.left * density).toInt(),
                            (r.top * density).toInt()
                        )
                    }
                    .size((r.width).dp, (r.height).dp)
                    .background(
                        tapeColor.copy(alpha = 0.75f),
                        shape = RoundedCornerShape(4.dp)
                    )
                    .border(
                        1.5.dp,
                        MaterialTheme.colorScheme.primary,
                        shape = RoundedCornerShape(4.dp)
                    )
            )
        }
    }
}
