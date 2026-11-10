package com.kairumo.padnote.collab

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
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
import androidx.compose.ui.Modifier
import androidx.compose.foundation.layout.padding
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp

/**
 * 協同面板「雲端共享（跨網路）」卡片底部的「使用自己的中繼」：使用說明、一鍵申請按鈕（Cloudflare 一鍵部署，
 * 全程在瀏覽器裡）、網址欄位與零基礎的詳細步驟。與 Apple `CloudRelaySettings.swift` 相同。
 */
object CloudRelayLinks {
    /** Cloudflare「一鍵部署」：把專案裡的 `deploy/relay-cloudflare` 複製到使用者自己的帳號並部署。 */
    const val DEPLOY = "https://deploy.workers.cloudflare.com/?url=https://github.com/hauchiehlin-ops/Kairumo/tree/main/deploy/relay-cloudflare"
    const val SIGNUP_CLOUDFLARE = "https://dash.cloudflare.com/sign-up"
    const val SIGNUP_GITHUB = "https://github.com/signup"
}

@Composable
fun CloudRelaySetting(l: (String) -> String) {
    val context = LocalContext.current
    var draft by remember { mutableStateOf(CollaborationManager.customCloudRelay(context)) }
    // 目前生效的（已儲存的）位址：決定上方顯示「試用中繼」還是「自己的中繼」。
    var saved by remember { mutableStateOf(CollaborationManager.customCloudRelay(context)) }
    var message by remember { mutableStateOf<String?>(null) }
    var isError by remember { mutableStateOf(false) }
    var showGuide by remember { mutableStateOf(false) }

    fun save(value: String) {
        val text = value.trim()
        // 貼成 https:// 的也收：換成 wss://（教學裡就是叫使用者這樣改，順手代勞）。
        val normalized = if (text.lowercase().startsWith("https://")) "wss://" + text.substring("https://".length) else text
        if (normalized.isNotEmpty() && !CollaborationManager.isValidCloudRelay(normalized)) {
            message = l("cloud_relay_invalid"); isError = true
            return
        }
        draft = normalized
        saved = normalized
        CollaborationManager.setCustomCloudRelay(context, normalized)
        message = l("cloud_relay_saved"); isError = false
    }

    fun open(url: String) {
        runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
    }

    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        // 目前用哪個中繼。內建的是**試用**：所有使用者共用免費額度、保留 1 天、寄存較小 ——
        // 把限制講清楚，常用的人才知道該架自己的。與 Apple `relayStatus` 相同。
        if (CollaborationManager.isValidCloudRelay(saved)) {
            Text(l("cloud_relay_status_own"), style = MaterialTheme.typography.labelSmall,
                color = Color(0xFF34C759), modifier = Modifier.testTag("collab.cloud_relay.status_own"))
        } else {
            androidx.compose.material3.Surface(
                color = Color(0xFFFF9500).copy(alpha = 0.10f),
                shape = MaterialTheme.shapes.small,
                modifier = Modifier.fillMaxWidth().testTag("collab.cloud_relay.status_trial")
            ) {
                Column(Modifier.padding(8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(l("cloud_relay_status_trial"), style = MaterialTheme.typography.labelMedium, color = Color(0xFFFF9500))
                    Text(l("cloud_relay_trial_limits"), style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        Text(l("cloud_relay_own_title"), style = MaterialTheme.typography.labelMedium)
        // 使用說明：為什麼要、怎麼做（三步），看不懂再開詳細步驟。
        Text(l("cloud_relay_own_usage"), style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = { open(CloudRelayLinks.DEPLOY) }, modifier = Modifier.testTag("collab.cloud_relay.one_click")) {
                Text(l("cloud_relay_one_click"))
            }
            OutlinedButton(onClick = { showGuide = true }, modifier = Modifier.testTag("collab.cloud_relay.guide")) {
                Text(l("cloud_relay_guide"))
            }
        }
        OutlinedTextField(
            value = draft,
            onValueChange = { draft = it },
            label = { Text(l("cloud_relay_title")) },
            placeholder = { Text(CollaborationManager.PUBLIC_RELAY_URL) },
            singleLine = true,
            modifier = Modifier.fillMaxWidth().testTag("collab.cloud_relay.field")
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = { save(draft) }) { Text(l("cloud_relay_save")) }
            OutlinedButton(onClick = { save("") }) { Text(l("reset")) }
        }
        message?.let {
            Text(it, style = MaterialTheme.typography.labelSmall, color = if (isError) Color(0xFFFF9500) else Color(0xFF34C759))
        }
        Text(l("cloud_relay_hint"), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }

    if (showGuide) CloudRelayGuideDialog(l) { showGuide = false }
}

/** 零基礎的取得步驟。 */
@Composable
private fun CloudRelayGuideDialog(l: (String) -> String, onDismiss: () -> Unit) {
    val context = LocalContext.current
    fun open(url: String) {
        runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
    }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("cloud_relay_guide_title")) },
        text = {
            Column(
                Modifier.heightIn(max = 520.dp).verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Text(l("cloud_relay_guide_intro"), style = MaterialTheme.typography.bodyMedium)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick = { open(CloudRelayLinks.SIGNUP_CLOUDFLARE) }) { Text(l("cloud_relay_signup_cloudflare")) }
                    OutlinedButton(onClick = { open(CloudRelayLinks.SIGNUP_GITHUB) }) { Text(l("cloud_relay_signup_github")) }
                }
                for (key in listOf("cloud_relay_step1", "cloud_relay_step2", "cloud_relay_step3",
                    "cloud_relay_step4", "cloud_relay_step5", "cloud_relay_step6")) {
                    Text(l(key), style = MaterialTheme.typography.bodyMedium)
                }
                Button(
                    onClick = { open(CloudRelayLinks.DEPLOY) },
                    modifier = Modifier.fillMaxWidth().testTag("collab.cloud_relay.deploy")
                ) { Text(l("cloud_relay_open_deploy")) }
                Text(l("cloud_relay_guide_note"), style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text(l("done")) } }
    )
}
