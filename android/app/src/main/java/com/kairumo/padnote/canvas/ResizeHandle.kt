package com.kairumo.padnote.canvas

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.foundation.clickable
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp

/**
 * 畫布物件右下角的縮放把手。
 *
 * **下限必須與 Apple 端的 `TextItemView` 一致**（寬 120、高 60）。
 * 兩邊不同的話，同一個方塊在一台裝置上縮得比另一台小，而尺寸是會同步的
 * —— 使用者看到的是「換台裝置就變形」。
 *
 * 和旋轉把手一樣，元件自己撐出空間而不用負的 offset：負偏移只要遇到任何
 * 一層祖先裁切就整個消失，而且只在特定位置消失，非常難查。
 */
@Composable
fun ResizeHandle(
    widthDp: Float,
    heightDp: Float,
    density: Float,
    onResize: (width: Float, height: Float) -> Unit,
    onCommit: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier.size((widthDp + HANDLE_DP).dp, (heightDp + HANDLE_DP).dp)
    ) {
        Box(
            modifier = Modifier
                .offset(x = (widthDp - HANDLE_DP / 2f).dp, y = (heightDp - HANDLE_DP / 2f).dp)
                .size(HANDLE_DP.dp)
                .background(MaterialTheme.colorScheme.primary, CircleShape)
                .pointerInput(Unit) {
                    detectDragGestures(
                        onDrag = { change, drag ->
                            change.consume()
                            // 位移要換回 dp：尺寸存的是與螢幕密度無關的頁面座標。
                            onResize(drag.x / density, drag.y / density)
                        },
                        onDragEnd = { onCommit() }
                    )
                }
        ) {
            Icon(
                imageVector = Icons.Filled.Add,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(16.dp).offset(5.dp, 5.dp)
            )
        }
    }
}

/** 縮放下限。比一行字還窄的方框，每個字都會自己換一行，看起來像壞掉。 */
const val MIN_OBJECT_WIDTH_DP = 120f
const val MIN_OBJECT_HEIGHT_DP = 60f

private const val HANDLE_DP = 26f

/**
 * 畫布物件左下角的樣式鈕。
 *
 * 與縮放把手同一套定位方式：元件自己撐出空間，不用負的 offset。
 */
@Composable
fun StyleHandle(
    widthDp: Float,
    heightDp: Float,
    onTap: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier.size((widthDp + HANDLE_DP).dp, (heightDp + HANDLE_DP).dp)
    ) {
        Box(
            modifier = Modifier
                .offset(x = (-HANDLE_DP / 2f).dp, y = (heightDp - HANDLE_DP / 2f).dp)
                .size(HANDLE_DP.dp)
                .background(MaterialTheme.colorScheme.primary, CircleShape)
                .clickable { onTap() }
        ) {
            Icon(
                imageVector = Icons.Filled.Edit,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(16.dp).offset(5.dp, 5.dp)
            )
        }
    }
}
