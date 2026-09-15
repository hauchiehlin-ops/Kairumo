package com.kairumo.padnote.collab

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.kairumo.padnote.LocalizationStrings

/**
 * 協同編輯面板（Android）。
 *
 * 與 Apple 的 `CollaborationSheet` 對應：狀態、建立／加入房間、成員清單、
 * 邀請連結（含端對端金鑰）、中繼位址設定、離線佇列筆數。
 *
 * 金鑰跟著邀請連結走（放在 `#` 之後的 fragment）。**不要把連結貼到網路上
 * 的公開位置** —— 拿到連結的人就拿得到金鑰，這在 UI 上有一行提示。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun CollaborationSheet(
    manager: CollaborationManager,
    languageTag: String,
    onDismiss: () -> Unit
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)
    val context = LocalContext.current

    var joinInput by remember { mutableStateOf("") }
    var serverInput by remember { mutableStateOf(manager.serverAddress) }
    var editingServer by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("collaborate")) },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("done")) } },
        text = {
            Column(
                Modifier.heightIn(max = 520.dp).verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                StatusLine(manager, ::l)

                when (val status = manager.status) {
                    is CollaborationManager.Status.Connected -> {
                        HorizontalDivider()
                        Text(
                            "${l("room_id")}：${status.roomId}",
                            style = MaterialTheme.typography.bodyMedium,
                            fontFamily = FontFamily.Monospace
                        )

                        if (manager.isHostingLocalRelay) {
                            // 這台裝置正在當中繼。關掉 App 房間就沒了 ——
                            // 使用者需要知道，不然只會覺得「別人突然都斷線」。
                            Text(
                                l("hosting_local_relay"),
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }

                        Text(l("copy_encrypted_link"), style = MaterialTheme.typography.labelMedium)
                        Text(
                            manager.inviteLink,
                            style = MaterialTheme.typography.labelSmall,
                            fontFamily = FontFamily.Monospace
                        )
                        if (manager.roomKeyBase64 != null) {
                            Text(
                                l("e2ee_protected_desc"),
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.error
                            )
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedButton(onClick = { copy(context, manager.inviteLink) }) {
                                Text(l("copy_encrypted_link"))
                            }
                            OutlinedButton(onClick = { manager.disconnect() }) {
                                Text(l("end_collaboration"))
                            }
                        }

                        if (manager.queuedOplogCount > 0) {
                            Text(
                                "${l("offline_queue_hint")}：${manager.queuedOplogCount}",
                                style = MaterialTheme.typography.labelSmall
                            )
                        }

                        HorizontalDivider()
                        Text(l("online_participants"), style = MaterialTheme.typography.labelMedium)
                        if (manager.peers.isEmpty()) {
                            Text(
                                l("local_relay_hint"),
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        } else {
                            for (peer in manager.peers) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    Box(
                                        Modifier
                                            .size(14.dp)
                                            .background(parseColor(peer.userColor), CircleShape)
                                    )
                                    Text(peer.userName, style = MaterialTheme.typography.bodyMedium)
                                    Text(
                                        peer.role,
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        }
                    }

                    else -> {
                        HorizontalDivider()
                        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Button(onClick = { manager.createRoom() }) { Text(l("start_collaboration")) }
                        }
                        OutlinedTextField(
                            value = joinInput,
                            onValueChange = { joinInput = it },
                            label = { Text(l("enter_room_id")) },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth()
                        )
                        Button(
                            onClick = { manager.joinRoom(joinInput) },
                            enabled = joinInput.isNotBlank()
                        ) { Text(l("join_room")) }
                    }
                }

                HorizontalDivider()
                if (editingServer) {
                    OutlinedTextField(
                        value = serverInput,
                        onValueChange = { serverInput = it },
                        label = { Text(l("relay_server_address")) },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        TextButton(onClick = {
                            manager.saveServer(serverInput.trim())
                            editingServer = false
                        }) { Text(l("confirm")) }
                        TextButton(onClick = {
                            serverInput = manager.serverAddress
                            editingServer = false
                        }) { Text(l("cancel")) }
                    }
                } else {
                    Row(
                        Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            "${l("relay_server_address")}：${manager.serverAddress}",
                            style = MaterialTheme.typography.labelSmall
                        )
                        TextButton(onClick = { editingServer = true }) { Text(l("reset")) }
                    }
                }
            }
        }
    )
}

@Composable
private fun StatusLine(manager: CollaborationManager, l: (String) -> String) {
    val text = when (val s = manager.status) {
        is CollaborationManager.Status.Connected -> l("status_connected")
        is CollaborationManager.Status.Connecting -> l("status_connecting")
        is CollaborationManager.Status.Reconnecting ->
            "${l("reconnecting_status")} ${s.attempt}/${s.max}"
        else -> l("status_disconnected")
    }
    Text(text, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
    manager.lastError?.let {
        // 只顯示「重連中」而不說原因，使用者無從判斷是位址打錯還是對方離線。
        //
        // `lastError` 放的是**語系鍵**，查表不到時 `localized` 會原樣回傳 ——
        // 所以連線層丟回來的原始訊息（例如 OkHttp 的例外字串）仍然看得到。
        Text(l(it), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.error)
    }
}

private fun copy(context: Context, text: String) {
    val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager ?: return
    cm.setPrimaryClip(ClipData.newPlainText("Kairumo", text))
}

private fun parseColor(hex: String): Color =
    runCatching { Color(android.graphics.Color.parseColor(hex)) }.getOrDefault(Color.Gray)
