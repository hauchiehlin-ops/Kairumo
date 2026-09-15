package com.kairumo.padnote.image

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import uniffi.padnote_core.FfiLinkMetadata

/**
 * 插入連結卡片。
 *
 * # 為什麼要先抓再插入
 *
 * 直接插入一張只有網址的卡片也行，但那和寫一行文字沒有差別。卡片的價值
 * 在標題與描述 —— 所以按下去先抓，抓完才插入。
 *
 * **抓失敗不擋人**：核心的 `link_parse_metadata` 在 HTML 是空字串時會退回
 * 主機名，所以連不上網仍然插得進去，只是資訊少一點。連不上網就不能插入
 * 連結，對使用者沒有道理。
 */
@Composable
fun LinkInsertDialog(
    l: (String) -> String,
    onDismiss: () -> Unit,
    onInsert: (FfiLinkMetadata) -> Unit
) {
    var url by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    AlertDialog(
        onDismissRequest = { if (!busy) onDismiss() },
        title = { Text(l("insert_link")) },
        text = {
            Column(Modifier.fillMaxWidth()) {
                OutlinedTextField(
                    value = url,
                    onValueChange = { url = it },
                    label = { Text(l("link_url_hint")) },
                    singleLine = true,
                    enabled = !busy,
                    modifier = Modifier.fillMaxWidth()
                )
                if (busy) {
                    CircularProgressIndicator(Modifier.padding(top = 12.dp))
                    Text(
                        l("link_fetching"),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        },
        confirmButton = {
            TextButton(
                enabled = url.isNotBlank() && !busy,
                onClick = {
                    busy = true
                    scope.launch {
                        // **一定要在背景執行緒**：抓網頁是網路 I/O，
                        // 在主執行緒做會讓畫面整個停住，而且 Android 會直接
                        // 丟 NetworkOnMainThreadException。
                        val meta = withContext(Dispatchers.IO) { LinkCard.fetch(url) }
                        busy = false
                        onInsert(meta)
                    }
                }
            ) { Text(l("confirm")) }
        },
        dismissButton = {
            TextButton(enabled = !busy, onClick = onDismiss) { Text(l("cancel")) }
        }
    )
}
