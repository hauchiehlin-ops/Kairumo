package com.kairumo.padnote.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.kairumo.padnote.LocalizationStrings
import com.kairumo.padnote.library.AccountSyncStore
import com.kairumo.padnote.library.CloudSync
import com.kairumo.padnote.library.NotebookTrash
import com.kairumo.padnote.library.TrashRetention
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import uniffi.padnote_core.FfiTrashEntry

/**
 * 回收桶畫面：還原、永久刪除、清空，以及保留期限設定。
 * 設計見 `docs/plans/expiry-purge.md`；Apple 端對應 `TrashView.swift`。
 *
 * # 這個畫面只「顯示」，不「決定」
 *
 * 「還剩幾天」「是否期滿」全部來自核心（[AccountSyncStore.trashEntries]）。
 * 這裡不自己算日期 —— 兩個平台各算一份的話，同一本筆記本在 iPad 上顯示還剩
 * 3 天、在 Android 上卻已經被清掉。
 *
 * # 清單以「本機真的還有的」為準
 *
 * 墓碑會永遠留在索引裡（不然別台會把刪掉的東西傳回來），所以不能拿「索引裡所有
 * 墓碑」當清單 —— 永久刪除之後它還會一直出現。這裡列的是 `trash/` 底下實際存在的
 * 套件，再去核心的清單裡找它的時間資訊。
 */
@Composable
fun TrashDialog(onDismiss: () -> Unit) {
    val languageTag = LocalAppLanguage.current
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    // 任何一個動作之後都要重讀 —— 清單來自磁碟與索引，不是這個畫面自己的狀態。
    var version by remember { mutableIntStateOf(0) }
    var retentionDays by remember { mutableStateOf(TrashRetention.days(context)) }
    var pendingDelete by remember { mutableStateOf<Pair<String, String>?>(null) }
    var confirmEmpty by remember { mutableStateOf(false) }
    var waitingDevices by remember { mutableStateOf<List<String>>(emptyList()) }

    val rows: List<Pair<String, FfiTrashEntry?>> = remember(version) {
        val entries = AccountSyncStore.trashEntries(context).associateBy { it.id.lowercase() }
        NotebookTrash.trashedIds(context)
            .map { it to entries[it.lowercase()] }
            .sortedByDescending { it.second?.deletedAt ?: 0uL }
    }

    fun titleOf(entry: FfiTrashEntry?): String =
        entry?.title?.takeIf { it.isNotBlank() } ?: l("untitled_note")

    fun countdownText(entry: FfiTrashEntry?): String = when {
        entry == null -> l("trash_clock_pending")
        // 沒倒數有兩個原因：保留期是「永不」，或這個墓碑還沒被補蓋章。
        !entry.hasCountdown ->
            if (retentionDays == 0u) l("trash_keep_forever_row") else l("trash_clock_pending")
        entry.daysLeft == 0u -> l("trash_expired")
        else -> l("trash_days_left").replaceFirst("%@", "${entry.daysLeft}")
    }

    fun retentionLabel(days: UInt) =
        if (days == 0u) l("trash_retention_forever")
        else l("trash_retention_days").replaceFirst("%@", "$days")

    AlertDialog(
        onDismissRequest = onDismiss,
        modifier = Modifier.testTag("trash.sheet"),
        title = { Text(l("trash_title")) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(l("trash_retention_title"), style = MaterialTheme.typography.labelLarge)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    TrashRetention.CHOICES.forEach { days ->
                        FilterChip(
                            selected = retentionDays == days,
                            onClick = {
                                retentionDays = days
                                TrashRetention.setDays(context, days)
                                version++
                            },
                            label = { Text(retentionLabel(days)) },
                            modifier = Modifier.testTag("trash.retention.$days")
                        )
                    }
                }
                Text(
                    l("trash_retention_footer"),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                if (rows.isEmpty()) {
                    Text(l("trash_empty"), modifier = Modifier.testTag("trash.empty"))
                } else {
                    LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        items(rows, key = { it.first }) { (id, entry) ->
                            Card(modifier = Modifier.fillMaxWidth().testTag("trash.row")) {
                                Column(Modifier.padding(12.dp)) {
                                    Text(titleOf(entry), style = MaterialTheme.typography.titleSmall)
                                    Text(
                                        countdownText(entry),
                                        style = MaterialTheme.typography.bodySmall,
                                        color = if (entry?.hasCountdown == true && entry.daysLeft == 0u)
                                            MaterialTheme.colorScheme.error
                                        else MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                    Row {
                                        TextButton(
                                            onClick = {
                                                // 本機回收桶裡有就從本機還原；沒有（只在雲端）就只記還原，
                                                // 下一輪同步會把它拉回來。
                                                if (!NotebookTrash.restore(context, id)) {
                                                    AccountSyncStore.recordRestore(context, id)
                                                }
                                                version++
                                            },
                                            modifier = Modifier.testTag("trash.restore")
                                        ) { Text(l("trash_restore")) }
                                        TextButton(
                                            onClick = { pendingDelete = id to titleOf(entry) },
                                            modifier = Modifier.testTag("trash.deleteForever")
                                        ) {
                                            Text(
                                                l("trash_delete_forever"),
                                                color = MaterialTheme.colorScheme.error
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                if (waitingDevices.isNotEmpty()) {
                    Text(
                        l("trash_waiting_devices")
                            .replaceFirst("%@", waitingDevices.joinToString(", ")),
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss, modifier = Modifier.testTag("trash.done")) {
                Text(l("done"))
            }
        },
        dismissButton = {
            TextButton(
                onClick = { confirmEmpty = true },
                enabled = rows.isNotEmpty(),
                modifier = Modifier.testTag("trash.emptyAction")
            ) {
                Text(l("trash_empty_action"), color = MaterialTheme.colorScheme.error)
            }
        }
    )

    pendingDelete?.let { (id, title) ->
        AlertDialog(
            onDismissRequest = { pendingDelete = null },
            title = { Text(l("trash_delete_forever_confirm_title")) },
            text = { Text(l("trash_delete_forever_confirm_message").replaceFirst("%@", title)) },
            confirmButton = {
                TextButton(onClick = {
                    NotebookTrash.purgeLocally(context, id)
                    pendingDelete = null
                    version++
                }) {
                    Text(l("trash_delete_forever"), color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = { TextButton(onClick = { pendingDelete = null }) { Text(l("cancel")) } }
        )
    }

    if (confirmEmpty) {
        AlertDialog(
            onDismissRequest = { confirmEmpty = false },
            title = { Text(l("trash_empty_confirm_title")) },
            text = { Text(l("trash_empty_confirm_message")) },
            confirmButton = {
                TextButton(onClick = {
                    confirmEmpty = false
                    NotebookTrash.empty(context)
                    version++
                    // 雲端那一半：忽略保留天數，但仍然要等所有必要裝置確認。
                    scope.launch {
                        val result = withContext(Dispatchers.IO) {
                            runCatching { CloudSync.reclaimDeleted(context, emptyTrash = true) }.getOrNull()
                        }
                        if (result != null) waitingDevices = result.waitingDevices
                    }
                }) {
                    Text(l("trash_empty_action"), color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = { TextButton(onClick = { confirmEmpty = false }) { Text(l("cancel")) } }
        )
    }
}
