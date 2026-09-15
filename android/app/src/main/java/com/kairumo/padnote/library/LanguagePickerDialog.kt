package com.kairumo.padnote.library

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.selection.selectable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.kairumo.padnote.LocalizationStrings

/**
 * 語言選擇（Android）。
 *
 * Apple 端一直有這個畫面，Android 原本只能跟著系統語系走 —— 那是一個
 * 使用者感受得到的差異：同一個帳號在 iPad 上選了日文，手機上還是中文。
 *
 * 語言是**跨裝置設定**（G-04 / ADR-0011），選完會寫進同步設定。
 *
 * # 語言名稱用該語言自己的寫法
 *
 * 清單上寫「日本語」而不是「日文」。看不懂目前介面語言的人，
 * 正是最需要這個畫面的人 —— 用他看不懂的語言標示選項毫無幫助。
 * 與 Apple 端 `AppLanguage.endonym` 是同一份寫法。
 */
@Composable
fun LanguagePickerDialog(
    current: String,
    onPick: (String) -> Unit,
    onDismiss: () -> Unit
) {
    val languages = listOf(
        "zh-Hant" to "繁體中文",
        "en" to "English",
        "zh-Hans" to "简体中文",
        "ja" to "日本語",
        "ko" to "한국어",
        "th" to "ไทย"
    )

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(LocalizationStrings.localized("language", current)) },
        confirmButton = {},
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(LocalizationStrings.localized("cancel", current))
            }
        },
        text = {
            Column(
                Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                for ((tag, endonym) in languages) {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .selectable(selected = tag == current, onClick = { onPick(tag) }),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        RadioButton(selected = tag == current, onClick = { onPick(tag) })
                        Text(endonym, style = MaterialTheme.typography.bodyLarge)
                    }
                }
            }
        }
    )
}
