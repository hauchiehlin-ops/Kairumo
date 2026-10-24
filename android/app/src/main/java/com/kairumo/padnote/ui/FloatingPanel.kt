package com.kairumo.padnote.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Divider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import kotlin.math.roundToInt

/**
 * 浮在畫布上的浮動工作面板（Android）。
 *
 * 與 Apple 端 `FloatingPanel.swift` 對齊：
 * - 取代 blocking modal sheet / AlertDialog：物件與控制項同時在畫面上，
 *   調整即時反映在畫布上，擋到了就把面板拖開。
 * - 標題列可拖曳移動、可收合、有關閉鈕。
 * - 非模態：畫布不會被遮蔽變暗，改動即時生效。
 */
@Composable
fun FloatingPanel(
    title: String,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
    initialOffsetX: Float = 0f,
    initialOffsetY: Float = 24f,
    content: @Composable () -> Unit
) {
    var offsetX by remember { mutableFloatStateOf(initialOffsetX) }
    var offsetY by remember { mutableFloatStateOf(initialOffsetY) }
    var isCollapsed by remember { mutableStateOf(false) }

    BoxWithConstraints(
        modifier = modifier
            .fillMaxSize()
            .zIndex(900f)
    ) {
        val density = androidx.compose.ui.platform.LocalDensity.current.density
        val availableWidthDp = maxWidth.value
        val panelWidth = minOf(340f, maxOf(260f, availableWidthDp - 24f))
        val maxAvailableHeight = maxHeight.value - 60f
        val maxPanelHeight = minOf(640f, maxOf(240f, maxAvailableHeight))

        // 預設靠右上角（留 24dp 邊距）
        val baseRightX = (availableWidthDp - panelWidth - 24f).coerceAtLeast(0f)
        val currentX = (baseRightX + offsetX).coerceIn(0f, (availableWidthDp - panelWidth).coerceAtLeast(0f))
        val currentY = (offsetY).coerceIn(0f, (maxHeight.value - 100f).coerceAtLeast(0f))

        Surface(
            modifier = Modifier
                .offset { IntOffset((currentX * density).roundToInt(), (currentY * density).roundToInt()) }
                .width(panelWidth.dp)
                .shadow(8.dp, RoundedCornerShape(14.dp))
                .clip(RoundedCornerShape(14.dp))
                .border(0.5.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f), RoundedCornerShape(14.dp)),
            color = MaterialTheme.colorScheme.surface,
            shape = RoundedCornerShape(14.dp)
        ) {
            Column(modifier = Modifier.width(panelWidth.dp)) {
                // Header (可拖曳標題列)
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f))
                        .pointerInput(Unit) {
                            detectDragGestures { change, dragAmount ->
                                change.consume()
                                offsetX += dragAmount.x / density
                                offsetY += dragAmount.y / density
                            }
                        }
                        .padding(horizontal = 12.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "≡",
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
                        modifier = Modifier.padding(end = 8.dp)
                    )
                    Text(
                        text = title,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Spacer(modifier = Modifier.weight(1f))
                    // 收合按鈕
                    IconButton(
                        onClick = { isCollapsed = !isCollapsed },
                        modifier = Modifier.size(28.dp)
                    ) {
                        Text(
                            text = if (isCollapsed) "▾" else "▴",
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    // 關閉按鈕
                    IconButton(
                        onClick = { onClose() },
                        modifier = Modifier.size(28.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(20.dp)
                                .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f), CircleShape),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = "✕",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                        }
                    }
                }

                if (!isCollapsed) {
                    Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f), thickness = 0.5.dp)
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(max = maxPanelHeight.dp)
                            .verticalScroll(rememberScrollState())
                            .padding(12.dp)
                    ) {
                        content()
                    }
                }
            }
        }
    }
}

