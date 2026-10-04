package com.kairumo.padnote.canvas

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Divider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
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

private val tapePresetHexes = listOf(
    "#FCEEAC", // 暖黃
    "#FFD1DC", // 柔粉
    "#C8E6C9", // 薄荷綠
    "#BBDEFB", // 晴空藍
    "#FFE0B2", // 淺杏橙
    "#E1BEE7", // 薰衣草紫
    "#CFD8DC"  // 莫蘭迪灰
)

/**
 * 遮蔽膠帶覆蓋層（Masking Tape Overlay）。
 *
 * 在筆記上貼附膠帶以覆蓋文字或考題答案，點一下即可翻開（Reveal）或遮回，
 * 方便背誦或自我測驗。與 Apple 端 MaskingTapeOverlayView 完全對齊。
 *
 * 支援多筆繪製、選取、移動、拉伸縮放、切換顏色、翻開/遮蔽與刪除。
 */
@Composable
fun MaskingTapeOverlay(
    pageIndex: Int,
    isActive: Boolean,
    tapeColor: Color = Color(0xFFFCEEAC),
    currentInkHex: String = "#FCEEAC",
    tapes: MutableList<NoteTape>,
    onTapesChanged: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    val density = LocalDensity.current.density
    var selectedTapeId by remember { mutableStateOf<String?>(null) }
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
                                selectedTapeId = null
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
                                    val newTape = NoteTape(
                                        pageIndex = pageIndex,
                                        x = r.left,
                                        y = r.top,
                                        width = r.width,
                                        height = r.height,
                                        colorHex = currentInkHex
                                    )
                                    tapes.add(newTape)
                                    selectedTapeId = newTape.id
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
            val isSelected = isActive && selectedTapeId == tape.id
            val parsedColor = runCatching { Color(android.graphics.Color.parseColor(tape.colorHex)) }.getOrDefault(tapeColor)
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
                        parsedColor.copy(alpha = tapeAlpha),
                        shape = RoundedCornerShape(4.dp)
                    )
                    .border(
                        if (isSelected) 1.5.dp else 1.dp,
                        if (isSelected) MaterialTheme.colorScheme.primary else parsedColor.copy(alpha = 0.6f),
                        shape = RoundedCornerShape(4.dp)
                    )
                    .clickable {
                        if (isActive) {
                            if (isSelected) {
                                val idx = tapes.indexOfFirst { it.id == tape.id }
                                if (idx >= 0) {
                                    tapes[idx] = tape.copy(isRevealed = !tape.isRevealed)
                                    onTapesChanged()
                                }
                            } else {
                                selectedTapeId = tape.id
                            }
                        } else {
                            val idx = tapes.indexOfFirst { it.id == tape.id }
                            if (idx >= 0) {
                                tapes[idx] = tape.copy(isRevealed = !tape.isRevealed)
                                onTapesChanged()
                            }
                        }
                    }
                    .then(
                        if (isSelected) {
                            Modifier.pointerInput(tape.id) {
                                detectDragGestures { change, dragAmount ->
                                    change.consume()
                                    val idx = tapes.indexOfFirst { it.id == tape.id }
                                    if (idx >= 0) {
                                        val cur = tapes[idx]
                                        tapes[idx] = cur.copy(
                                            x = cur.x + dragAmount.x / density,
                                            y = cur.y + dragAmount.y / density
                                        )
                                        onTapesChanged()
                                    }
                                }
                            }
                        } else Modifier
                    )
            ) {
                // 左縮放把手
                if (isSelected) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.CenterStart)
                            .offset((-10).dp, 0.dp)
                            .size(24.dp)
                            .pointerInput(tape.id) {
                                detectDragGestures { change, dragAmount ->
                                    change.consume()
                                    val idx = tapes.indexOfFirst { it.id == tape.id }
                                    if (idx >= 0) {
                                        val cur = tapes[idx]
                                        val deltaX = dragAmount.x / density
                                        val newW = max(20f, cur.width - deltaX)
                                        val actualDelta = cur.width - newW
                                        tapes[idx] = cur.copy(
                                            x = cur.x + actualDelta,
                                            width = newW
                                        )
                                        onTapesChanged()
                                    }
                                }
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        Box(
                            modifier = Modifier
                                .size(12.dp)
                                .background(Color.White, CircleShape)
                                .border(2.dp, MaterialTheme.colorScheme.primary, CircleShape)
                        )
                    }

                    // 右縮放把手
                    Box(
                        modifier = Modifier
                            .align(Alignment.CenterEnd)
                            .offset(10.dp, 0.dp)
                            .size(24.dp)
                            .pointerInput(tape.id) {
                                detectDragGestures { change, dragAmount ->
                                    change.consume()
                                    val idx = tapes.indexOfFirst { it.id == tape.id }
                                    if (idx >= 0) {
                                        val cur = tapes[idx]
                                        val deltaX = dragAmount.x / density
                                        val newW = max(20f, cur.width + deltaX)
                                        tapes[idx] = cur.copy(width = newW)
                                        onTapesChanged()
                                    }
                                }
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        Box(
                            modifier = Modifier
                                .size(12.dp)
                                .background(Color.White, CircleShape)
                                .border(2.dp, MaterialTheme.colorScheme.primary, CircleShape)
                        )
                    }
                }

                // 未選中時右上角小刪除按鈕
                if (isActive && !isSelected) {
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

            // 選中時在上方浮現快捷色票與操作面板
            if (isSelected) {
                Box(
                    modifier = Modifier
                        .offset {
                            IntOffset(
                                (tape.x * density).toInt(),
                                ((tape.y - 48f) * density).toInt()
                            )
                        }
                        .shadow(4.dp, RoundedCornerShape(20.dp))
                        .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(20.dp))
                        .padding(horizontal = 8.dp, vertical = 4.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        for (hex in tapePresetHexes) {
                            val c = runCatching { Color(android.graphics.Color.parseColor(hex)) }.getOrDefault(Color.Yellow)
                            val isColorActive = tape.colorHex.equals(hex, ignoreCase = true)
                            Box(
                                modifier = Modifier
                                    .size(18.dp)
                                    .background(c, CircleShape)
                                    .border(
                                        if (isColorActive) 2.dp else 1.dp,
                                        if (isColorActive) MaterialTheme.colorScheme.primary else Color.Gray.copy(alpha = 0.4f),
                                        CircleShape
                                    )
                                    .clickable {
                                        val idx = tapes.indexOfFirst { it.id == tape.id }
                                        if (idx >= 0) {
                                            tapes[idx] = tape.copy(colorHex = hex)
                                            onTapesChanged()
                                        }
                                    }
                            )
                        }

                        Divider(
                            modifier = Modifier
                                .height(14.dp)
                                .width(1.dp)
                        )

                        // 翻開 / 遮回切換
                        IconButton(
                            onClick = {
                                val idx = tapes.indexOfFirst { it.id == tape.id }
                                if (idx >= 0) {
                                    tapes[idx] = tape.copy(isRevealed = !tape.isRevealed)
                                    onTapesChanged()
                                }
                            },
                            modifier = Modifier.size(24.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Refresh,
                                contentDescription = "翻開或遮回",
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(16.dp)
                            )
                        }

                        // 刪除按鈕
                        IconButton(
                            onClick = {
                                selectedTapeId = null
                                tapes.removeAll { it.id == tape.id }
                                onTapesChanged()
                            },
                            modifier = Modifier.size(24.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Delete,
                                contentDescription = "刪除膠帶",
                                tint = MaterialTheme.colorScheme.error,
                                modifier = Modifier.size(16.dp)
                            )
                        }
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

