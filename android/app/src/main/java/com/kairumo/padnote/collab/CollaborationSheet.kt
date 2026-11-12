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
import androidx.compose.foundation.layout.padding
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
import androidx.compose.runtime.LaunchedEffect
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
    // 開著的就是邀請指定的那本（首頁剛為這張 QR Code 打開／建立的）：直接加入、連上就收起面板。
    // 掃碼就是要加入，再要使用者按一次「加入」，看起來像編輯器一閃又跳回面板、
    // 關掉面板只剩空白畫布。開著的是別本筆記時照舊只帶入、等使用者自己按。與 Apple 同一套。
    var autoJoined by remember { mutableStateOf(false) }
    LaunchedEffect(invited) {
        if (invited != null && inviteTargets(invited, notebookId) && manager.status !is CollaborationManager.Status.Connected) {
            autoJoined = true
            manager.joinRoom(invited)
        }
    }
    LaunchedEffect(manager.status) {
        if (autoJoined && manager.status is CollaborationManager.Status.Connected) {
            autoJoined = false
            onDismiss()
        }
    }
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

                    // 三種連線方式的使用時機與限制（與 Apple `CollabModesGuide` 相同）。
                    CollabModesGuide(::l)

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

                            if (!manager.isHostingLocalRelay) {
                                // 會議室已開在雲端共享時按這裡：同一間房也開放同一 Wi‑Fi（不另開一間，見 `startLocalRoom`）。
                                val startLabel = l(if (manager.savedCustomRemoteRelay) "start_collaboration" else "collab_start_local")
                                Button(onClick = {
                                    com.kairumo.padnote.entitlement.EntitlementManager.requirePro(
                                        com.kairumo.padnote.entitlement.ProFeatureGate.COLLAB_HOST,
                                        startLabel
                                    ) {
                                        manager.startLocalRoom()
                                    }
                                }) {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                                    ) {
                                        Text(startLabel)
                                        if (!com.kairumo.padnote.entitlement.EntitlementManager.isProUnlocked) {
                                            com.kairumo.padnote.entitlement.ProMicroBadge(
                                                compact = false,
                                                languageTag = languageTag
                                            )
                                        }
                                    }
                                }
                            }

                            // 掃描加入：每種連線方式一張 QR Code（同一 Wi‑Fi／遠端中繼）。
                            CollabInviteQr(manager, notebookId, notebookTitle, ::l)

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
                                // 「同一 Wi‑Fi」：房間開在這台內建的本機中繼上。只有存了自架的 wss:// 中繼時
                                // 才連到那台，按鈕也照舊叫「開始多人協同」。與 Apple 相同。
                                val hostLabel = l(if (manager.savedCustomRemoteRelay) "start_collaboration" else "collab_start_local")
                                Button(onClick = {
                                    com.kairumo.padnote.entitlement.EntitlementManager.requirePro(
                                        com.kairumo.padnote.entitlement.ProFeatureGate.COLLAB_HOST,
                                        hostLabel
                                    ) {
                                        manager.createRoom(manager.localRoomServer)
                                    }
                                }) {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                                    ) {
                                        Text(hostLabel)
                                        if (!com.kairumo.padnote.entitlement.EntitlementManager.isProUnlocked) {
                                            com.kairumo.padnote.entitlement.ProMicroBadge(
                                                compact = false,
                                                languageTag = languageTag
                                            )
                                        }
                                    }
                                }
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
    // 狀態燈：連線完成＝實心綠燈＋綠字，連線中／重連＝琥珀，未連線＝灰。
    // 舊版只有一行黑字，連上與沒連上一眼分不出來（實機回報「綠燈不夠明顯」）。
    val lamp = when (manager.status) {
        is CollaborationManager.Status.Connected -> androidx.compose.ui.graphics.Color(0xFF22A447)
        is CollaborationManager.Status.Connecting,
        is CollaborationManager.Status.Reconnecting -> androidx.compose.ui.graphics.Color(0xFFF5A623)
        else -> androidx.compose.ui.graphics.Color(0xFF9E9E9E)
    }
    val connected = manager.status is CollaborationManager.Status.Connected
    androidx.compose.foundation.layout.Row(
        verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier
            .background(lamp.copy(alpha = 0.14f), androidx.compose.foundation.shape.RoundedCornerShape(12.dp))
            .padding(horizontal = 10.dp, vertical = 6.dp)
    ) {
        androidx.compose.foundation.layout.Box(
            Modifier
                .size(14.dp)
                .background(androidx.compose.ui.graphics.Color.White, androidx.compose.foundation.shape.CircleShape)
                .padding(2.dp)
                .background(lamp, androidx.compose.foundation.shape.CircleShape)
        )
        Text(
            text,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.Bold,
            color = if (connected) androidx.compose.ui.graphics.Color(0xFF13702E) else MaterialTheme.colorScheme.onSurface
        )
    }
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
 * 邀請連結的 QR Code。依可用的連線方式各一張：同一 Wi‑Fi、遠端中繼（跨網路一律走雲端共享）。
 * 對方用相機掃描就開啟 `kairumo://collab?...`，房號、金鑰、位址自動帶入。
 * 矩陣由核心產生（`collabQrCode`），Apple 畫的是同一份（I6）。
 */
@Composable
private fun CollabInviteQr(manager: CollaborationManager, notebookId: String?, notebookTitle: String, l: (String) -> String) {
    data class Mode(val id: String, val titleKey: String, val link: String, val hintKey: String)
    val context = LocalContext.current
    // 這本已經雲端共享、房間開在雲端共享的中繼上：上方「雲端共享」那張 QR Code 就是這間房
    // （同一個中繼、同一把金鑰），再給一張「遠端中繼」只會讓人以為是另一種連法（與 Apple 相同）。
    val cloudShared = notebookId != null && CloudCollab.shared(context, notebookId) != null &&
        uniffi.padnote_core.collabParseInviteV2(manager.inviteLink).servers.contains(manager.cloudRelayUrl)
    val modes = buildList {
        if (manager.isHostingLocalRelay) {
            if (manager.lanRelayAddress != null) add(Mode("lan", "collab_qr_mode_lan", manager.inviteLink, "collab_qr_hint_lan"))
        } else if (!cloudShared) {
            add(Mode("remote", "collab_qr_mode_remote", manager.inviteLink, "collab_qr_hint_remote"))
        }
    }.filter { it.link.isNotEmpty() }.distinctBy { it.link }
        // 連結帶上筆記本 id：對方掃了才知道要打開哪一本（與 Apple 相同）。
        .map { it.copy(link = manager.notebookInviteLink(it.link, notebookId, notebookTitle)) }
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

/**
 * 協同面板頂端的說明：三種連線方式各在什麼時候用、有什麼限制；「改用連結分享」會讓 QR Code 換掉的原因；
 * 端對端加密不是一種連線方式。預設收合。與 Apple `CollabModesGuide` 相同。
 */
@Composable
private fun CollabModesGuide(l: (String) -> String) {
    var expanded by remember { mutableStateOf(false) }
    Column(
        Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surfaceVariant, androidx.compose.foundation.shape.RoundedCornerShape(12.dp))
            .testTag("collaboration.modes_guide")
    ) {
        TextButton(onClick = { expanded = !expanded }) {
            Text((if (expanded) "▾ " else "▸ ") + l("collab_modes_title"), style = MaterialTheme.typography.labelLarge)
        }
        if (expanded) {
            Text(
                l("collab_modes_body"),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(start = 12.dp, end = 12.dp, bottom = 12.dp)
            )
        }
    }
}

/** 邀請連結指定的筆記本（`nb`，沒有就是房間 id）是不是 [notebookId] 這本。 */
internal fun inviteTargets(link: String, notebookId: String?): Boolean {
    if (notebookId.isNullOrBlank()) return false
    val invite = uniffi.padnote_core.collabParseInviteV2(link)
    val target = invite.notebookId.trim().ifEmpty { invite.roomId.trim() }
    return target.isNotEmpty() && target.equals(notebookId, ignoreCase = true)
}
