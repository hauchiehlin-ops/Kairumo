package com.kairumo.padnote.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.PlainTooltip
import androidx.compose.material3.Text
import androidx.compose.material3.TooltipBox
import androidx.compose.material3.TooltipDefaults
import androidx.compose.material3.rememberTooltipState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/**
 * 即時響應之按鈕提示工具 (Android 端 Instant Tooltip)。
 *
 * 支援手寫筆懸停 (Stylus Hover) 或外接滑鼠游標時即刻顯示功能說明。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InstantTooltip(
    text: String?,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit
) {
    if (text.isNullOrBlank()) {
        Box(modifier = modifier) { content() }
        return
    }

    val state = rememberTooltipState(isPersistent = false)
    TooltipBox(
        positionProvider = TooltipDefaults.rememberPlainTooltipPositionProvider(),
        tooltip = {
            PlainTooltip {
                Text(text)
            }
        },
        state = state,
        modifier = modifier
    ) {
        content()
    }
}
