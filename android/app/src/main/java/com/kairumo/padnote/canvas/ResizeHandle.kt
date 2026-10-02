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
import androidx.compose.material.icons.filled.List
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import com.kairumo.padnote.LocalizationStrings
import com.kairumo.padnote.ui.LocalAppLanguage
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
    val handleLabel = LocalizationStrings.localized("resize_handle", LocalAppLanguage.current)
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
                // 標籤放在**可拖曳的容器**上，不是裡面那顆圖示 —— 圖示是
                // 裝飾（所以維持 null），真正能操作的是這個 Box。
                // 沒有它的話，TalkBack 掃過畫布上的把手時什麼也不會念。
                .semantics { contentDescription = handleLabel }
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
    modifier: Modifier = Modifier,
    /** 給了就在右上角多一顆「調整層級」鈕（見 [OrderHandle]）。 */
    objectId: String? = null
) {
    if (objectId != null) {
        OrderHandle(objectId = objectId, widthDp = widthDp, heightDp = heightDp)
    }
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


/**
 * 由編輯器提供：調整某個物件的層級。沒有提供時（預覽、測試）按鈕不出現。
 *
 * 用 CompositionLocal 而不是一條條回呼往下傳 —— 每一種物件圖層都要它，
 * 七份各自的簽章只會讓第八種物件漏掉。
 */
val LocalObjectReorder =
    androidx.compose.runtime.compositionLocalOf<((String, ObjectStacking.Reorder) -> Unit)?> { null }

/**
 * 物件右上角的「層級」鈕：點開選單選「移到最上層／上移一層／下移一層／移到最下層」。
 *
 * 每個物件都要有 —— 圖層面板是整頁的總覽，而使用者想改的常常只是
 * 「這一張被蓋住了，拉到前面來」，不該要他先去開面板、再找到那一列。
 */
@Composable
fun OrderHandle(
    objectId: String,
    widthDp: Float,
    heightDp: Float,
    modifier: Modifier = Modifier
) {
    val reorder = LocalObjectReorder.current ?: return
    var open by androidx.compose.runtime.remember(objectId) {
        androidx.compose.runtime.mutableStateOf(false)
    }
    val language = LocalAppLanguage.current
    Box(
        modifier = modifier.size((widthDp + HANDLE_DP).dp, (heightDp + HANDLE_DP).dp)
    ) {
        Box(
            modifier = Modifier
                .offset(x = (widthDp - HANDLE_DP / 2f).dp, y = (-HANDLE_DP / 2f).dp)
                .size(HANDLE_DP.dp)
                .background(MaterialTheme.colorScheme.tertiary, CircleShape)
                .clickable { open = true }
                .semantics {
                    contentDescription = LocalizationStrings.localized("layers_panel", language)
                }
        ) {
            Icon(
                imageVector = Icons.Filled.List,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(16.dp).offset(5.dp, 5.dp)
            )
            androidx.compose.material3.DropdownMenu(
                expanded = open,
                onDismissRequest = { open = false }
            ) {
                for (op in ObjectStacking.Reorder.entries) {
                    androidx.compose.material3.DropdownMenuItem(
                        text = { androidx.compose.material3.Text(
                            LocalizationStrings.localized(op.labelKey, language)) },
                        onClick = { open = false; reorder(objectId, op) }
                    )
                }
            }
        }
    }
}
