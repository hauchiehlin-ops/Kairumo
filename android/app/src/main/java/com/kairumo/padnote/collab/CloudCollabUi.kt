package com.kairumo.padnote.collab

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
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
    val scope = rememberCoroutineScope()
    val registry by CloudCollab.registry.collectAsState()
    val busy by CloudCollab.busy.collectAsState()
    val error by CloudCollab.lastError.collectAsState()
    val entry = registry.firstOrNull { it.notebookId.equals(notebookId, ignoreCase = true) }
    var link by remember { mutableStateOf("") }

    HorizontalDivider()
    Text(l("cloud_collab_title"), style = MaterialTheme.typography.labelMedium)
    Text(l("cloud_collab_desc"), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)

    if (entry == null) {
        val shareLabel = l("cloud_collab_share_link")
        Button(
            onClick = {
                com.kairumo.padnote.entitlement.EntitlementManager.requirePro(
                    com.kairumo.padnote.entitlement.ProFeatureGate.COLLAB_HOST,
                    shareLabel
                ) {
                    scope.launch { CloudCollab.share(context, collab, notebookId, title)?.let { link = it } }
                }
            },
            enabled = busy == null
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(shareLabel)
                if (!com.kairumo.padnote.entitlement.EntitlementManager.isProUnlocked) {
                    com.kairumo.padnote.entitlement.ProMicroBadge(
                        compact = false,
                        languageTag = languageTag
                    )
                }
            }
        }
        Text(l("cloud_collab_share_link_hint"), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    } else {
        // 房主打開面板時確定房間開在雲端中繼上（QR Code 指向的就是那一間）。
        LaunchedEffect(entry.notebookId) { CloudCollab.ensurePublicRoom(context, entry, collab) }
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
        Text(l("cloud_collab_retention_hint"), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
    busy?.let {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
            Text(it, style = MaterialTheme.typography.labelSmall)
        }
    }
    error?.let { Text(it, style = MaterialTheme.typography.labelSmall, color = Color(0xFFFF9500)) }

    // 使用自己的中繼：放在這張卡片上（以前藏在「協同伺服器位址」的編輯區裡，使用者找不到）。
    HorizontalDivider()
    CloudRelaySetting(::l)
}
