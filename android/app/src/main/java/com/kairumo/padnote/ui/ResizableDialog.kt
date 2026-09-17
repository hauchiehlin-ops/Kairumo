package com.kairumo.padnote.ui

import android.content.Context
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.background
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * 可由使用者調整高度的對話框內容。
 *
 * # 為什麼只有高度
 *
 * 對話框的寬度由 Material 的規格決定（手機上就是螢幕寬減去邊距），
 * 拉寬它只會讓小螢幕上的內容貼到邊。Apple 端同樣只調高度 —— 那邊是
 * `presentationDetents`，這邊是底部的拖曳把手，兩邊能做的事一樣。
 *
 * # 高度為什麼要記住
 *
 * 使用者把某個面板拉高一次，下次打開就該是那個高度。`key` 一個面板一個，
 * 共用的話兩個不相干的面板會互相改對方的大小。
 */
object DialogSize {
    val minimum: Dp = 200.dp
    val maximum: Dp = 760.dp
    val default: Dp = 460.dp

    private const val PREFS = "kairumo.dialogSize"

    fun load(context: Context, key: String, fallback: Dp): Dp {
        val stored = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getFloat(key, -1f)
        return if (stored > 0f) stored.dp else fallback
    }

    fun save(context: Context, key: String, height: Dp) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putFloat(key, height.value)
            .apply()
    }
}

/** 這個面板目前的高度。記在 SharedPreferences，關掉再開還在。 */
@Composable
fun rememberDialogHeight(key: String, default: Dp = DialogSize.default): MutableState<Dp> {
    val context = LocalContext.current
    return remember(key) { mutableStateOf(DialogSize.load(context, key, default)) }
}

/**
 * 對話框底部的拖曳把手。往下拖變高，往上拖變矮。
 *
 * 放在可捲動內容的**外面** —— 放進 `LazyColumn` 裡的話，把手會跟著內容
 * 一起捲走，使用者捲到一半就再也找不到它。
 */
@Composable
fun DialogResizeHandle(
    state: MutableState<Dp>,
    key: String,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val density = LocalDensity.current
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(24.dp)
            .pointerInput(key) {
                detectVerticalDragGestures(
                    onDragEnd = { DialogSize.save(context, key, state.value) }
                ) { _, dragAmount ->
                    val delta = with(density) { dragAmount.toDp() }
                    state.value = (state.value + delta)
                        .coerceIn(DialogSize.minimum, DialogSize.maximum)
                }
            },
        contentAlignment = Alignment.Center
    ) {
        Box(
            Modifier
                .size(width = 36.dp, height = 4.dp)
                .background(
                    MaterialTheme.colorScheme.onSurfaceVariant,
                    RoundedCornerShape(2.dp)
                )
                .padding(0.dp)
        )
    }
}
