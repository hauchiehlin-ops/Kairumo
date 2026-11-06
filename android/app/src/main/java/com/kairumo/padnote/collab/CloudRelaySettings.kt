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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp

/**
 * 協同面板裡的「雲端共享中繼」設定：可改用自己部署的中繼，旁邊附零基礎的取得步驟
 * （Cloudflare 一鍵部署，全程在瀏覽器裡）。與 Apple `CloudRelaySettings.swift` 相同。
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
        CollaborationManager.setCustomCloudRelay(context, normalized)
        message = l("cloud_relay_saved"); isError = false
    }

    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
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
        TextButton(onClick = { showGuide = true }, modifier = Modifier.testTag("collab.cloud_relay.guide")) {
            Text(l("cloud_relay_guide"))
        }
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
