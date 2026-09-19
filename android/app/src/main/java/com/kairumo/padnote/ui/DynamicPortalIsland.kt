package com.kairumo.padnote.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.LocalizationStrings
import com.kairumo.padnote.canvas.EditorMode

/**
 * 流體動態傳送島 (Android 端 Dynamic Portal Island)。
 *
 * 位於工具列/畫布核心，提供「手繪工作室 (Studio Drawing)」與「文字智庫 (Pro Docs)」的即時無縫切換。
 * 支援情境提示（如：手繪模式中編輯文字方塊時，浮島展開文字模式情境橫幅）。
 * 保持 `Modifier.testTag("editor.mode")`，以確保通過跨平台自動對照閘門。
 */
@Composable
fun DynamicPortalIsland(
    currentMode: EditorMode,
    contextualState: ContextualPortalState? = null,
    languageTag: String,
    onModeChange: (EditorMode) -> Unit,
    modifier: Modifier = Modifier
) {
    val haptic = LocalHapticFeedback.current
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp),
        modifier = modifier
    ) {
        Surface(
            shape = CircleShape,
            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.92f),
            shadowElevation = 2.dp,
            modifier = Modifier
                .testTag("editor.mode")
                .clip(CircleShape)
        ) {
            Row(
                modifier = Modifier.padding(3.dp),
                horizontalArrangement = Arrangement.spacedBy(2.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // 手繪工作室按鈕
                ModePillButton(
                    title = l("mode_draw"),
                    icon = "✏️",
                    isSelected = currentMode == EditorMode.DRAW,
                    activeColor = MaterialTheme.colorScheme.primary,
                    testTag = "portal.draw",
                    onClick = {
                        if (currentMode != EditorMode.DRAW) {
                            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                            onModeChange(EditorMode.DRAW)
                        }
                    }
                )

                // 文字智庫按鈕
                ModePillButton(
                    title = l("mode_type"),
                    icon = "📑",
                    isSelected = currentMode == EditorMode.TYPE,
                    activeColor = Color(0xFF6366F1), // 智庫經典靛藍
                    testTag = "portal.type",
                    onClick = {
                        if (currentMode != EditorMode.TYPE) {
                            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                            onModeChange(EditorMode.TYPE)
                        }
                    }
                )
            }
        }

        // 情境提示橫幅（例如在手繪模式編輯文字方塊時展開）
        AnimatedVisibility(
            visible = contextualState != null,
            enter = fadeIn(),
            exit = fadeOut()
        ) {
            contextualState?.let { state ->
                val (bgColor, textColor, text) = when (state) {
                    is ContextualPortalState.EditingTextInDrawMode -> Triple(
                        Color(0xFF6366F1).copy(alpha = 0.15f),
                        Color(0xFF4F46E5),
                        state.title
                    )
                    is ContextualPortalState.DrawingInTextMode -> Triple(
                        Color(0xFF059669).copy(alpha = 0.15f),
                        Color(0xFF047857),
                        state.title
                    )
                }

                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(6.dp))
                        .background(bgColor)
                        .padding(horizontal = 8.dp, vertical = 2.dp)
                ) {
                    Text(
                        text = text,
                        style = MaterialTheme.typography.labelSmall.copy(
                            fontSize = 10.sp,
                            fontWeight = FontWeight.SemiBold
                        ),
                        color = textColor
                    )
                }
            }
        }
    }
}

@Composable
private fun ModePillButton(
    title: String,
    icon: String,
    isSelected: Boolean,
    activeColor: Color,
    onClick: () -> Unit,
    testTag: String = ""
) {
    val backgroundColor by animateColorAsState(
        targetValue = if (isSelected) activeColor else Color.Transparent,
        label = "pill_bg"
    )
    val contentColor by animateColorAsState(
        targetValue = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurfaceVariant,
        label = "pill_text"
    )

    Box(
        modifier = Modifier
            .then(if (testTag.isNotEmpty()) Modifier.testTag(testTag) else Modifier)
            .clip(CircleShape)
            .background(backgroundColor)
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 5.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(
                text = icon,
                fontSize = 12.sp
            )
            Text(
                text = title,
                style = MaterialTheme.typography.labelMedium.copy(
                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                    fontSize = 12.sp
                ),
                color = contentColor
            )
        }
    }
}

/**
 * 傳送島情境狀態
 */
sealed class ContextualPortalState {
    data class EditingTextInDrawMode(val title: String) : ContextualPortalState()
    data class DrawingInTextMode(val title: String) : ContextualPortalState()
}
