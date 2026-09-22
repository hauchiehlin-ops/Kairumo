package com.kairumo.padnote.ui

import android.content.Context
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Checkbox
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.kairumo.padnote.LocalizationStrings
import uniffi.padnote_core.FfiFeatureHint
import uniffi.padnote_core.featureHint

/**
 * 功能的操作提示（首次使用時出現一次）。
 *
 * # 為什麼需要
 *
 * 使用者的回報是「這幾個功能無法實際操作，或者說不知道該怎麼操作」。
 * 查下去，**四個都有實作，而且都能用** —— 它們共同的問題是按下去之後進入
 * 某種「模式」，而真正要做的事是**下一個動作**（圖釘要再點畫面、草圖修飾
 * 要先有筆跡…）。畫面上沒有任何地方講，所以看起來就是「按了沒反應」。
 *
 * 內容與 id 都來自核心，與 Apple 端同一份 —— 鍵不一樣的話，使用者在一台
 * 裝置上關掉的提示會在另一台冒出來。
 *
 * # 「不再顯示」存在本機
 *
 * 這是介面偏好，不是內容 —— 存進同步的設定就要動格式，而那件事有相容性
 * 代價（見 H-OPLOG-COMPAT）。代價與收益不成比例。
 */
object FeatureHintStore {

    private const val PREFS = "kairumo_hints"
    private const val KEY = "dismissed_v1"

    fun isDismissed(context: Context, id: String): Boolean =
        dismissed(context).contains(id)

    fun dismiss(context: Context, id: String) {
        val all = dismissed(context).toMutableSet()
        all.add(id)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putStringSet(KEY, all).apply()
    }

    /**
     * 全部重新顯示。設定頁要有這個 —— 關掉之後就再也找不回來的說明，
     * 對後來才需要它的人等於不存在。
     */
    fun resetAll(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().remove(KEY).apply()
    }

    private fun dismissed(context: Context): Set<String> =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getStringSet(KEY, emptySet()) ?: emptySet()
}

/**
 * 第一次用到某個功能時，跳一則講「接下來要做什麼」的提示。
 *
 * @param trigger 這個功能剛被啟動了嗎。由 false 變 true 時才跳 ——
 *   每次重組都跳的話，使用者會在放圖釘的途中被彈窗打斷。
 */
@Composable
fun FeatureHintHost(
    context: Context,
    id: String,
    trigger: Boolean,
    languageTag: String
) {
    var hint by remember { mutableStateOf<FfiFeatureHint?>(null) }
    var dontShowAgain by remember { mutableStateOf(false) }

    LaunchedEffect(trigger) {
        if (trigger && !FeatureHintStore.isDismissed(context, id)) {
            hint = featureHint(id)
            dontShowAgain = false
        }
    }

    val shown = hint ?: return
    fun l10n(key: String) = LocalizationStrings.localized(key, languageTag)

    AlertDialog(
        onDismissRequest = { hint = null },
        title = {
            Text(l10n(shown.titleKey), modifier = Modifier.testTag("hint.title"))
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    l10n(shown.bodyKey),
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.testTag("hint.body")
                )
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("hint.dont_show_again"),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Checkbox(
                        checked = dontShowAgain,
                        onCheckedChange = { dontShowAgain = it }
                    )
                    Text(l10n("hint_dont_show_again"), style = MaterialTheme.typography.bodySmall)
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    if (dontShowAgain) FeatureHintStore.dismiss(context, id)
                    hint = null
                },
                modifier = Modifier.testTag("hint.got_it")
            ) { Text(l10n("hint_got_it")) }
        }
    )
}
