package com.kairumo.padnote.milestone

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.kairumo.padnote.LocalizationStrings
import com.kairumo.padnote.library.NotebookLibrary
import uniffi.padnote_core.FfiMilestone
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 里程碑快照（時光機）—— 工作項 S-99，與 Apple 的 `CollaborationSheet`
 * 裡那一段對應。
 *
 * # 為什麼放在協同面板裡
 *
 * 跟 Apple 放同一個地方。里程碑最常見的用法是「交稿前」「對方改動之前」，
 * 那正好是打開協同面板的時機；另開一個入口只會讓兩個平台的位置分家。
 *
 * # 這裡沒有「刪除快照」
 *
 * 快照住在 append-only 的 oplog 裡（見 `padnote_doc::milestone`），
 * 刪不掉也不該刪 —— 一個常數大小的名字換來的是「還原永遠可以反悔」。
 * 假裝有刪除鈕、按下去卻只是從畫面上藏起來，比沒有更糟。
 */
@Composable
fun MilestoneSection(
    notebookId: String,
    deviceId: UInt,
    creatorName: String,
    languageTag: String,
    /** 還原完成後呼叫 —— 呼叫端必須重新開啟筆記本。見下方說明。 */
    onRestored: () -> Unit
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)
    val context = LocalContext.current

    var revision by remember { mutableStateOf(0) }
    val milestones = remember(revision, notebookId) {
        NotebookLibrary.milestones(context, notebookId, deviceId)
    }
    var creating by remember { mutableStateOf(false) }
    var newTitle by remember { mutableStateOf("") }
    var pendingRestore by remember { mutableStateOf<FfiMilestone?>(null) }
    var message by remember { mutableStateOf<String?>(null) }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        HorizontalDivider()
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                l("milestone_snapshots"),
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold
            )
            TextButton(onClick = { newTitle = ""; creating = true }) {
                Text(l("create_snapshot"))
            }
        }

        if (milestones.isEmpty()) {
            Text(
                l("milestone_empty"),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        } else {
            milestones.forEach { m ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(8.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant)
                        .padding(horizontal = 10.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(Modifier.weight(1f)) {
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(m.title, style = MaterialTheme.typography.bodyMedium)
                            // 自動快照要標出來 —— 按了幾次還原之後，
                            // 系統產生的項目會比使用者自己命名的還多。
                            if (m.automatic) {
                                Text(
                                    l("milestone_automatic"),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                        Text(
                            "${m.creator} · ${formatMoment(m.createdUnixMs.toLong(), languageTag)}",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    TextButton(onClick = { pendingRestore = m }) {
                        Text(l("restore_snapshot"))
                    }
                }
            }
        }
    }

    if (creating) {
        AlertDialog(
            onDismissRequest = { creating = false },
            title = { Text(l("create_snapshot")) },
            text = {
                OutlinedTextField(
                    value = newTitle,
                    onValueChange = { newTitle = it },
                    singleLine = true,
                    label = { Text(l("milestone_snapshots")) }
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    val title = newTitle.ifBlank { l("collab_snapshot") }
                    NotebookLibrary.createMilestone(
                        context, notebookId, deviceId, title, creatorName
                    )
                    creating = false
                    revision++
                }) { Text(l("confirm")) }
            },
            dismissButton = {
                TextButton(onClick = { creating = false }) { Text(l("cancel")) }
            }
        )
    }

    pendingRestore?.let { target ->
        AlertDialog(
            onDismissRequest = { pendingRestore = null },
            title = { Text(l("restore_snapshot")) },
            // 講清楚「不會消失」—— 使用者真正在猶豫的是
            // 「我這半小時的東西會不會沒了」。
            text = { Text(l("milestone_restore_confirm").replace("%@", target.title)) },
            confirmButton = {
                TextButton(onClick = {
                    val safety = NotebookLibrary.restoreMilestone(
                        context, notebookId, deviceId, target.id,
                        l("milestone_before_restore").replace("%@", target.title)
                    )
                    pendingRestore = null
                    revision++
                    message = if (safety == null) {
                        l("milestone_restore_failed")
                    } else {
                        l("milestone_restored").replace("%@", safety.title)
                    }
                    if (safety != null) onRestored()
                }) { Text(l("confirm")) }
            },
            dismissButton = {
                TextButton(onClick = { pendingRestore = null }) { Text(l("cancel")) }
            }
        )
    }

    message?.let { text ->
        AlertDialog(
            onDismissRequest = { message = null },
            title = { Text(l("milestone_snapshots")) },
            text = { Text(text) },
            confirmButton = { TextButton(onClick = { message = null }) { Text(l("done")) } }
        )
    }
}

/** 掛鐘時間，跟著介面語言走。 */
private fun formatMoment(unixMs: Long, languageTag: String): String =
    SimpleDateFormat("yyyy/MM/dd HH:mm", Locale.forLanguageTag(languageTag))
        .format(Date(unixMs))
