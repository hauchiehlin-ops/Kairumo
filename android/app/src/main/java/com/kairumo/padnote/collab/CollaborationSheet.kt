package com.kairumo.padnote.collab

import androidx.compose.foundation.layout.height
import com.kairumo.padnote.ui.DialogResizeHandle
import com.kairumo.padnote.ui.rememberDialogHeight
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
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import kotlinx.coroutines.launch
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.platform.testTag
import com.kairumo.padnote.LocalizationStrings
import com.kairumo.padnote.milestone.MilestoneSection

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
    /** 目前開著的筆記本。null 時不顯示里程碑那一段 —— 它是逐本的。 */
    notebookId: String? = null,
    deviceId: UInt = 0u,
    creatorName: String = "",
    /** 還原完成後呼叫，呼叫端要重新開啟筆記本。 */
    onRestored: () -> Unit = {},
    /** 筆記本名稱（雲端共享資料夾的名字用）。 */
    notebookTitle: String = "",
    onDismiss: () -> Unit
) {
    val height = rememberDialogHeight("collaboration", 520.dp)

    fun l(key: String) = LocalizationStrings.localized(key, languageTag)
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    // 從 QR Code／邀請連結進來的話，直接帶入（見 CollabInvites）。
    val invited = remember { CollabInvites.pending.also { CollabInvites.pending = null } }
    var joinInput by remember { mutableStateOf(invited ?: "") }
    var serverInput by remember { mutableStateOf(manager.serverAddress) }
    var editingServer by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("collaborate")) },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("done")) } },
        text = {
            // 內容與把手包進同一個 Column：AlertDialog 的 text 槽是 Box，
            // 兩個兄弟會疊在一起，把手蓋住內容最上面 24dp（那一排點不到）。
            Column {
                Column(
                    Modifier.height(height.value).verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    StatusLine(manager, ::l)

                    // ☁️ 雲端共享（跨網路）：最高優先跨網協同入口（無論連線狀態，一律置頂展示）
                    if (notebookId != null) {
                        CloudShareSection(manager, notebookId, notebookTitle, languageTag)
                    }

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
                                manager.lanRelayAddress?.let {
                                    Text(
                                        "${l("relay_lan_address")}：$it",
                                        style = MaterialTheme.typography.labelSmall,
                                        fontFamily = FontFamily.Monospace,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                                manager.tailscaleRelayAddress?.let {
                                    Text(
                                        "${l("relay_tailscale_address")}：$it",
                                        style = MaterialTheme.typography.labelSmall,
                                        fontFamily = FontFamily.Monospace,
                                        color = MaterialTheme.colorScheme.primary
                                    )
                                }
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
                                if (manager.tailscaleRelayAddress != null) {
                                    OutlinedButton(onClick = { copy(context, manager.tailscaleInviteLink ?: manager.inviteLink) }) {
                                        Text(l("copy_tailscale_link"))
                                    }
                                }
                                OutlinedButton(onClick = { copy(context, manager.inviteLink) }) {
                                    Text(if (manager.tailscaleRelayAddress != null) l("copy_lan_link") else l("copy_encrypted_link"))
                                }
                                OutlinedButton(onClick = {
                                    scope.launch {
                                        if (!notebookId.isNullOrEmpty()) {
                                            CloudCollab.endCollaboration(context, notebookId, manager)
                                        } else {
                                            manager.disconnect()
                                        }
                                    }
                                }) {
                                    Text(l("end_collaboration"))
                                }
                            }

                            // 掃描加入：每種連線方式一張 QR Code（同一 Wi‑Fi／Tailscale／遠端中繼）。
                            CollabInviteQr(manager, ::l)

                            // 只貼房號、沒帶金鑰就加入的話，連得上、也看得到成員，
                            // **但對方寫的每一個字都解不開** —— 畫面上什麼都不會
                            // 發生，而使用者會以為是同步壞了。連上之後就講明白。
                            if (!manager.isHost && manager.roomKeyBase64 == null) {
                                Text(
                                    l("collab_key_missing"),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.error
                                )
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
                            if (invited != null) {
                                Text(
                                    l("collab_invite_received"),
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.primary
                                )
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
                        Text(
                            l("local_relay_hint"),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        // **協同不限於同一個網路。** 核心的位址檢查一直允許
                        // `wss://` 連到任何主機，但介面上從頭到尾只講區網位址，
                        // 於是使用者合理地以為只能在同一個 Wi-Fi 用。
                        Text(
                            l("relay_remote_hint"),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
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

                    // ☁️ 雲端共享（跨網路）：未連線狀態下也提供一鍵開啟雲端共享。
                    if (notebookId != null && manager.status is CollaborationManager.Status.Disconnected) {
                        CloudShareSection(manager, notebookId, notebookTitle, languageTag)
                    }

                    // 里程碑快照（S-99）。位置與 Apple 的協同面板一致 ——
                    // 另開一個入口只會讓兩個平台的操作路徑分家。
                    if (notebookId != null) {
                        MilestoneSection(
                            notebookId = notebookId,
                            deviceId = deviceId,
                            creatorName = creatorName,
                            languageTag = languageTag,
                            onRestored = {
                                onRestored()
                                onDismiss()
                            }
                        )
                    }
                }
                // 底部的拖曳把手：往下拖變高。放在捲動容器**外面** ——
                // 放進去的話把手會跟著內容捲走，捲到一半就再也找不到它。
                DialogResizeHandle(height, "collaboration")
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

/**
 * 邀請連結的 QR Code。依可用的連線方式各一張：同一 Wi‑Fi、Tailscale、遠端中繼。
 * 對方用相機掃描就開啟 `kairumo://collab?...`，房號、金鑰、位址自動帶入。
 * 矩陣由核心產生（`collabQrCode`），Apple 畫的是同一份（I6）。
 */
@Composable
private fun CollabInviteQr(manager: CollaborationManager, l: (String) -> String) {
    data class Mode(val id: String, val titleKey: String, val link: String, val hintKey: String)
    val modes = buildList {
        if (manager.isHostingLocalRelay) {
            if (manager.lanRelayAddress != null) add(Mode("lan", "collab_qr_mode_lan", manager.inviteLink, "collab_qr_hint"))
            manager.tailscaleInviteLink?.let { add(Mode("tailscale", "collab_qr_mode_tailscale", it, "collab_qr_hint")) }
        } else {
            add(Mode("remote", "collab_qr_mode_remote", manager.inviteLink, "collab_qr_hint"))
        }
    }.filter { it.link.isNotEmpty() }.distinctBy { it.link }
    if (modes.isEmpty()) return
    var selected by remember { mutableStateOf<String?>(null) }
    val current = modes.firstOrNull { it.id == selected } ?: modes.first()

    HorizontalDivider()
    Text(l("collab_qr_title"), style = MaterialTheme.typography.labelMedium)
    if (modes.size > 1) {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            for (mode in modes) {
                androidx.compose.material3.FilterChip(
                    selected = mode.id == current.id,
                    onClick = { selected = mode.id },
                    label = { Text(l(mode.titleKey)) }
                )
            }
        }
    }
    // 矩陣依連結快取：捲動重組時不重算。
    val qr = remember(current.link) { runCatching { uniffi.padnote_core.collabQrCode(current.link) }.getOrNull() }
    if (qr != null && qr.size > 0u) {
        val n = qr.size.toInt()
        androidx.compose.foundation.Canvas(
            Modifier
                .size(176.dp)
                .background(Color.White)
                .semantics { contentDescription = l("collab_qr_title") }
                .testTag("collaboration.qr")
        ) {
            val quiet = 4
            val cell = size.minDimension / (n + quiet * 2)
            for (y in 0 until n) {
                for (x in 0 until n) {
                    if (qr.modules[y * n + x]) {
                        drawRect(
                            Color.Black,
                            topLeft = androidx.compose.ui.geometry.Offset((x + quiet) * cell, (y + quiet) * cell),
                            size = androidx.compose.ui.geometry.Size(cell + 0.5f, cell + 0.5f)
                        )
                    }
                }
            }
        }
    }
    Text(
        l(current.hintKey),
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant
    )
}
