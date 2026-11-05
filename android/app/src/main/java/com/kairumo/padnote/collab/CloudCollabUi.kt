package com.kairumo.padnote.collab

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.kairumo.padnote.LocalizationStrings
import kotlinx.coroutines.launch
import uniffi.padnote_core.FfiCollabInviteV2
import uniffi.padnote_core.FfiDriveMember

/** 核心產生的 QR 矩陣（與 Apple 同一份）。四周留 4 格靜區。 */
@Composable
fun CloudQrCode(text: String, modifier: Modifier = Modifier) {
    val qr = remember(text) { runCatching { uniffi.padnote_core.collabQrCode(text) }.getOrNull() }
    if (qr == null || qr.size == 0u) return
    val n = qr.size.toInt()
    Canvas(modifier.background(Color.White)) {
        val quiet = 4
        val cell = size.minDimension / (n + quiet * 2)
        for (y in 0 until n) for (x in 0 until n) {
            if (qr.modules[y * n + x]) {
                drawRect(Color.Black, Offset((x + quiet) * cell, (y + quiet) * cell), Size(cell + 0.5f, cell + 0.5f))
            }
        }
    }
}

/** 協同面板：雲端共享（跨網路）。與 Apple `CloudShareSection` 相同。 */
@Composable
fun CloudShareSection(
    collab: CollaborationManager, notebookId: String, title: String, languageTag: String
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)
    val context = LocalContext.current
    val activity = context as? Activity
    val scope = rememberCoroutineScope()
    val registry by CloudCollab.registry.collectAsState()
    val busy by CloudCollab.busy.collectAsState()
    val error by CloudCollab.lastError.collectAsState()
    val direct by CloudCollab.directPeers.collectAsState()
    val entry = registry.firstOrNull { it.notebookId.equals(notebookId, ignoreCase = true) }
    var email by remember { mutableStateOf("") }
    var link by remember { mutableStateOf("") }
    var members by remember { mutableStateOf<List<FfiDriveMember>>(emptyList()) }

    LaunchedEffect(entry?.folderId) {
        members = if (entry != null && entry.role == "owner") CloudCollab.members(context, entry) else emptyList()
    }

    fun share(mail: String) {
        val act = activity ?: return
        scope.launch {
            CloudCollab.share(act, collab, notebookId, title, mail)?.let {
                link = it
                email = ""
                CloudCollab.shared(context, notebookId)?.let { e -> members = CloudCollab.members(context, e) }
            }
        }
    }

    HorizontalDivider()
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(l("cloud_collab_title"), style = MaterialTheme.typography.labelMedium, modifier = Modifier.weight(1f))
        if (direct > 0) Text(l("cloud_collab_direct"), style = MaterialTheme.typography.labelSmall, color = Color(0xFF34C759))
    }
    Text(l("cloud_collab_desc"), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)

    if (entry == null) {
        Button(onClick = { share("") }, enabled = busy == null) { Text(l("cloud_collab_share_link")) }
        Text(l("cloud_collab_share_link_hint"), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    } else {
        val invite = link.ifEmpty { CloudCollab.inviteLink(entry, collab) }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            CloudQrCode(invite, Modifier.size(140.dp).testTag("cloudcollab.qr"))
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(l("cloud_collab_invite_hint"), style = MaterialTheme.typography.labelSmall)
                OutlinedButton(onClick = {
                    val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    cm.setPrimaryClip(ClipData.newPlainText("kairumo", invite))
                }) { Text(l("cloud_collab_copy_invite")) }
                OutlinedButton(onClick = {
                    val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, invite)
                    context.startActivity(Intent.createChooser(send, l("cloud_collab_send_invite")))
                }) { Text(l("cloud_collab_send_invite")) }
            }
        }
        if (entry.role == "owner") {
            for (m in members) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(m.name.ifEmpty { m.email.ifEmpty { l("cloud_collab_anyone") } }, style = MaterialTheme.typography.bodySmall)
                        Text(l("cloud_collab_role_${m.role}"), style = MaterialTheme.typography.labelSmall)
                    }
                    if (m.role != "owner") {
                        TextButton(onClick = {
                            scope.launch { if (CloudCollab.revoke(context, entry, m)) members = CloudCollab.members(context, entry) }
                        }) { Text(l("cloud_collab_revoke"), color = MaterialTheme.colorScheme.error) }
                    }
                }
            }
        }
    }
    busy?.let {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
            Text(it, style = MaterialTheme.typography.labelSmall)
        }
    }
    error?.let { Text(it, style = MaterialTheme.typography.labelSmall, color = Color(0xFFFF9500)) }
}

/** App 最外層：收到雲端共享筆記的邀請就跳出「加入」確認。加入完成後由 [onOpen] 打開那本筆記。 */
@Composable
fun CloudJoinHost(languageTag: String, onOpen: (String) -> Unit) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)
    val activity = LocalContext.current as? Activity
    val scope = rememberCoroutineScope()
    val invite by CloudCollab.pendingInvite.collectAsState()
    val open by CloudCollab.openRequest.collectAsState()
    val busy by CloudCollab.busy.collectAsState()
    val error by CloudCollab.lastError.collectAsState()

    LaunchedEffect(open) {
        open?.let {
            CloudCollab.openRequest.value = null
            onOpen(it)
        }
    }
    val current: FfiCollabInviteV2 = invite ?: return
    AlertDialog(
        onDismissRequest = { if (busy == null) CloudCollab.pendingInvite.value = null },
        title = { Text(l("cloud_collab_join_title")) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                if (current.title.isNotEmpty()) Text(current.title, style = MaterialTheme.typography.titleSmall)
                Text(l("cloud_collab_join_desc"), style = MaterialTheme.typography.bodySmall)
                busy?.let {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
                        Text(it, style = MaterialTheme.typography.labelSmall)
                    }
                }
                error?.let { Text(it, style = MaterialTheme.typography.labelSmall, color = Color(0xFFFF9500)) }
            }
        },
        confirmButton = {
            Button(
                enabled = busy == null,
                modifier = Modifier.testTag("cloudcollab.join"),
                onClick = {
                    val act = activity ?: return@Button
                    scope.launch { if (CloudCollab.join(act, current)) CloudCollab.pendingInvite.value = null }
                }
            ) { Text(l("cloud_collab_join")) }
        },
        dismissButton = {
            TextButton(onClick = { CloudCollab.pendingInvite.value = null }, enabled = busy == null) { Text(l("cancel")) }
        }
    )
}

/** 編輯器：其他參與者在哪一頁。點一下跳過去。 */
@Composable
fun CloudPresenceBar(currentPage: Int, languageTag: String, modifier: Modifier = Modifier, onJump: (Int) -> Unit) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)
    val presences by CloudCollab.presences.collectAsState()
    val direct by CloudCollab.directPeers.collectAsState()
    if (presences.isEmpty()) return
    Row(
        modifier
            .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.92f), RoundedCornerShape(16.dp))
            .padding(6.dp)
            .testTag("cloudcollab.presence"),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(if (direct > 0) "⚡" else "☁", style = MaterialTheme.typography.labelSmall)
        for (p in presences) {
            val color = runCatching { Color(android.graphics.Color.parseColor(p.colorHex)) }.getOrDefault(MaterialTheme.colorScheme.primary)
            Row(
                Modifier
                    .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(12.dp))
                    .clickable { onJump(p.pageIndex.toInt()) }
                    .padding(horizontal = 8.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Box(Modifier.size(8.dp).background(color, CircleShape))
                Text(
                    l("cloud_collab_on_page").replace("%@", p.userName).replace("%d", (p.pageIndex.toInt() + 1).toString()),
                    style = MaterialTheme.typography.labelSmall,
                    color = if (p.pageIndex.toInt() == currentPage) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
                )
            }
        }
    }
}
