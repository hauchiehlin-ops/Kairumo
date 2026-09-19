package com.kairumo.padnote.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import kotlin.math.cos
import kotlin.math.sin

/**
 * 徑向飛輪快捷工具項目定義
 */
data class RadialMenuItem(
    val id: String,
    val icon: String,
    val label: String,
    val color: Color = Color.Unspecified,
    val action: () -> Unit
)

/**
 * 專業級徑向飛輪快捷工具盤 (Radial Pie / Mark Menu - Android 版)。
 *
 * 在手指長按或觸控筆側鍵觸發時，於落筆位置以 360° 環形彈出高頻功能。
 * 使用者只需輕輕向任一扇區滑動或點擊即可切換工具，完全不中斷創作心流。
 */
@Composable
fun RadialMarkMenu(
    visible: Boolean,
    centerOffset: Offset,
    items: List<RadialMenuItem>,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    if (!visible) return

    val haptic = LocalHapticFeedback.current
    val density = LocalDensity.current

    // 飛輪幾何參數 (dp)
    val radiusDp = 88.dp
    val itemSizeDp = 46.dp
    val radiusPx = with(density) { radiusDp.toPx() }

    Box(
        modifier = modifier
            .fillMaxSize()
            .zIndex(10_000f)
            .background(Color.Black.copy(alpha = 0.15f))
            .pointerInput(Unit) {
                detectTapGestures(onTap = { onDismiss() })
            }
    ) {
        AnimatedVisibility(
            visible = visible,
            enter = fadeIn(spring()) + scaleIn(spring(dampingRatio = 0.76f, stiffness = 400f)),
            exit = fadeOut() + scaleOut()
        ) {
            Box(modifier = Modifier.fillMaxSize()) {
                // 中央指示錨點 (32dp)
                Box(
                    modifier = Modifier
                        .offset {
                            IntOffset(
                                (centerOffset.x - with(density) { 16.dp.toPx() }).toInt(),
                                (centerOffset.y - with(density) { 16.dp.toPx() }).toInt()
                            )
                        }
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.9f))
                        .border(2.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.5f), CircleShape)
                        .shadow(6.dp, CircleShape)
                )

                // 環形分佈之快捷按鈕
                items.forEachIndexed { index, item ->
                    val angle = angleForIndex(index, items.size)
                    val offsetX = cos(angle) * radiusPx
                    val offsetY = sin(angle) * radiusPx

                    var isPressed by remember { mutableStateOf(false) }
                    val scale by animateFloatAsState(
                        targetValue = if (isPressed) 1.15f else 1.0f,
                        label = "radial_scale"
                    )

                    Box(
                        modifier = Modifier
                            .offset {
                                IntOffset(
                                    (centerOffset.x + offsetX - with(density) { (itemSizeDp / 2).toPx() }).toInt(),
                                    (centerOffset.y + offsetY - with(density) { (itemSizeDp / 2).toPx() }).toInt()
                                )
                            }
                            .size(itemSizeDp)
                            .scale(scale)
                            .shadow(6.dp, CircleShape)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.95f))
                            .border(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f), CircleShape)
                            .clickable {
                                haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                                item.action()
                                onDismiss()
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = item.icon,
                                fontSize = 15.sp
                            )
                            Text(
                                text = item.label,
                                style = MaterialTheme.typography.labelSmall.copy(
                                    fontSize = 8.sp,
                                    fontWeight = FontWeight.Bold
                                ),
                                color = if (item.color != Color.Unspecified) item.color else MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 1
                            )
                        }
                    }
                }
            }
        }
    }
}

private fun angleForIndex(index: Int, total: Int): Double {
    val step = (2.0 * Math.PI) / total.toDouble()
    // 從正上方 (-90度) 起始
    return - (Math.PI / 2.0) + (index.toDouble() * step)
}
