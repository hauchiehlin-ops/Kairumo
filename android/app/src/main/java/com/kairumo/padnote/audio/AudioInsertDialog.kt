package com.kairumo.padnote.audio

import androidx.compose.foundation.layout.height
import com.kairumo.padnote.ui.DialogResizeHandle
import com.kairumo.padnote.ui.rememberDialogHeight
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.io.File

/**
 * 挑一段這本筆記裡既有的錄音，插到目前這一頁。
 *
 * # 為什麼清單來源是檔案系統
 *
 * 錄音檔就住在筆記本套件的 `media/audio` 底下，而套件是同步的單位。
 * 另外維護一份清單的話，從另一台裝置同步過來的錄音不會出現在上面 ——
 * 與 [com.kairumo.padnote.library.RecordingIndex] 同一個理由。
 */
@Composable
fun AudioInsertDialog(
    l: (String) -> String,
    audioDirectory: File?,
    onDismiss: () -> Unit,
    onPick: (File) -> Unit
) {
    val height = rememberDialogHeight("audioInsert", 320.dp)

    val files = (audioDirectory?.listFiles()
        ?.filter { it.isFile && it.length() > 0 }
        ?.sortedByDescending { it.lastModified() }
        ?: emptyList())

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("insert_audio")) },
        text = {
            if (files.isEmpty()) {
                Text(
                    l("no_recordings_hint"),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            } else {
                Column(
                    Modifier.fillMaxWidth().height(height.value)
                        .verticalScroll(rememberScrollState())
                ) {
                    for (file in files) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.fillMaxWidth()
                                .clickable { onPick(file) }
                                .padding(vertical = 10.dp)
                        ) {
                            Text("🎙", fontSize = 16.sp, modifier = Modifier.padding(end = 10.dp))
                            Column(Modifier.weight(1f)) {
                                Text(file.name, fontWeight = FontWeight.Medium, fontSize = 14.sp)
                                Text(
                                    "${file.length() / 1024} KB",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
                // 底部的拖曳把手：往下拖變高（S-72）。
                DialogResizeHandle(height, "audioInsert")
            }
        },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("cancel")) } }
    )
}
