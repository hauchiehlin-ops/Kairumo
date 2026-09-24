package com.kairumo.padnote.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.TextButton
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.testTag
import kotlinx.coroutines.launch
import com.kairumo.padnote.library.AccountSyncStore
import com.kairumo.padnote.library.CloudSync
import com.kairumo.padnote.library.NotebookLibrary
import com.kairumo.padnote.LocalizationStrings
import com.kairumo.padnote.sync.AutoSync
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import uniffi.padnote_core.FfiSyncDiagnostics
import uniffi.padnote_core.syncDiagnose

/**
 * 同步醫生（P4）。
 *
 * # 為什麼日誌不夠
 *
 * 出問題時畫面上只有一串日誌。日誌答得出「發生過什麼」，答不出
 * **「現在是什麼狀態」**：游標建立了沒？快照裡有幾個檔案？哪幾本還沒推上去？
 * 而那才是下一步要根據的東西。
 *
 * # 不打網路
 *
 * 診斷畫面在**網路不通的時候最需要**，所以它吃的是本機存下來的快照，
 * 不是一個要先去換權杖的工作階段。文字與 Apple 端逐項對應 ——
 * 兩台裝置的數字要能直接比對，各自湊一份的話會得到互相矛盾的結論。
 */
@Composable
fun SyncDoctorCard(deviceId: UInt, modifier: Modifier = Modifier) {
    // 介面語言由最外層的 CompositionLocal 提供（見 ui/LocalAppLanguage.kt）。
    val languageTag = LocalAppLanguage.current
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)
    val context = LocalContext.current
    val isSyncing by AutoSync.isSyncing.collectAsState()
    val needsSignIn by AutoSync.needsSignIn.collectAsState()
    val scope = rememberCoroutineScope()
    var showConfirm by remember { mutableStateOf(false) }
    var showReclaim by remember { mutableStateOf(false) }
    var reclaiming by remember { mutableStateOf(false) }
    var wiping by remember { mutableStateOf(false) }
    var wipeMessage by remember { mutableStateOf<String?>(null) }

    // 雲端檔案歸屬：純計算，但讀兩份快照要碰磁碟。
    val audit by produceState<uniffi.padnote_core.FfiCloudAudit?>(initialValue = null, isSyncing) {
        value = withContext(Dispatchers.IO) {
            runCatching {
                uniffi.padnote_core.cloudAudit(
                    AccountSyncStore.remoteIndexJson(
                        context, AccountSyncStore.lastAccount(context)
                    ),
                    AccountSyncStore.indexJson(context)
                )
            }.getOrNull()
        }
    }

    // 掃套件目錄要碰磁碟，不能在主執行緒做。
    val diagnostics by produceState<FfiSyncDiagnostics?>(initialValue = null, isSyncing) {
        value = withContext(Dispatchers.IO) {
            runCatching {
                val entries = NotebookLibrary.all(context, deviceId)
                syncDiagnose(
                    AccountSyncStore.remoteIndexJson(
                        context, AccountSyncStore.lastAccount(context)
                    ),
                    entries.map { it.path.absolutePath },
                    entries.map { it.id }
                )
            }.getOrNull()
        }
    }

    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Column(Modifier.padding(12.dp)) {
            Text(l("hw_sync_status"), style = MaterialTheme.typography.labelMedium)
            val d = diagnostics
            if (d == null) {
                Row(Modifier.padding(top = 6.dp)) { Text(l("sd_loading"), style = MaterialTheme.typography.bodySmall) }
            } else {
                DoctorRow(
                    "雲端快照",
                    if (d.hasCursor) {
                        "已建立（追蹤 ${d.trackedFiles} 個檔案）"
                    } else {
                        "尚未建立，下次同步會重新盤點一次"
                    }
                )
                DoctorRow(
                    "待同步筆記",
                    if (d.pendingNotebooks.isEmpty()) {
                        "無（已檢查 ${d.checkedNotebooks} 本）"
                    } else {
                        "${d.pendingNotebooks.size} / ${d.checkedNotebooks} 本"
                    }
                )
                DoctorRow(
                    "自動同步",
                    when {
                        needsSignIn -> "已暫停，請重新登入"
                        isSyncing -> "進行中"
                        else -> "待命"
                    }
                )
                // **這幾千個檔案裡有多少是活的。** 在這之前沒有人答得出來。
                audit?.let { a ->
                    DoctorRow(
                        l("sync_audit_files"),
                        l("sync_audit_breakdown")
                            .replace("%1@", "${a.live}")
                            .replace("%2@", "${a.deleted}")
                            .replace("%3@", "${a.unknown}")
                    )
                    if (a.unknown > 0u) {
                        Text(
                            l("sync_audit_unknown_hint"),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(top = 4.dp)
                        )
                    }
                }
                wipeMessage?.let { DoctorRow("重置", it) }
            }

            // **重置雲端同步。**
            //
            // 資料存在 Drive 的 appDataFolder（隱藏區），使用者在
            // drive.google.com 看不到也刪不掉。唯一的手動路徑只清雲端，
            // 本機還留著一份「雲端有這些檔案」的快照 —— 下一輪會拿著
            // 幻覺去比對。所以重置要由 App 來做，兩邊一起清。
            // **回收**：只刪已刪除筆記本的殘骸。比「重置」溫和得多，
            // 所以排在它前面 —— 多數人要的是這一個。
            if ((audit?.deleted ?: 0u) > 0u) {
                TextButton(
                    onClick = { showReclaim = true },
                    enabled = !reclaiming && !wiping,
                    modifier = Modifier.fillMaxWidth().testTag("sync.reclaim")
                ) {
                    Text(
                        if (reclaiming) l("sync_reclaim_running") else l("sync_reclaim"),
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }

            TextButton(
                onClick = { showConfirm = true },
                enabled = !wiping,
                modifier = Modifier.fillMaxWidth().testTag("sync.reset_cloud")
            ) {
                Text(
                    if (wiping) l("sync_reset_cloud_running") else l("sync_reset_cloud"),
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
    }

    if (showReclaim) {
        AlertDialog(
            onDismissRequest = { showReclaim = false },
            title = { Text(l("sync_reclaim")) },
            text = { Text(l("sync_reclaim_confirm_body")) },
            confirmButton = {
                TextButton(onClick = {
                    showReclaim = false
                    reclaiming = true
                    wipeMessage = l("sync_reclaim_running")
                    scope.launch {
                        val result = withContext(Dispatchers.IO) {
                            runCatching { CloudSync.reclaimDeleted(context) }.getOrNull()
                        }
                        wipeMessage = when {
                            result == null -> l("sync_reset_cloud_busy")
                            result.deleted == 0u && result.failed == 0u ->
                                l("sync_reclaim_nothing")
                            result.ok -> l("sync_reclaim_done")
                                .replace("%1@", "${result.deleted}")
                            else -> l("sync_reclaim_partial")
                                .replace("%1@", "${result.deleted}")
                                .replace("%2@", "${result.failed}")
                        }
                        reclaiming = false
                    }
                }) { Text(l("sync_reclaim")) }
            },
            dismissButton = {
                TextButton(onClick = { showReclaim = false }) { Text(l("cancel")) }
            }
        )
    }

    if (showConfirm) {
        AlertDialog(
            onDismissRequest = { showConfirm = false },
            title = { Text(l("sync_reset_cloud_confirm_title")) },
            text = { Text(l("sync_reset_cloud_confirm_body")) },
            confirmButton = {
                TextButton(onClick = {
                    showConfirm = false
                    wiping = true
                    wipeMessage = l("sync_reset_cloud_running")
                    scope.launch {
                        val result = withContext(Dispatchers.IO) {
                            runCatching { CloudSync.wipeCloud(context) }.getOrNull()
                        }
                        wipeMessage = when {
                            result == null -> l("sync_reset_cloud_busy")
                            result.ok -> l("sync_reset_cloud_done")
                                .replace("%1@", "${result.deleted}")
                            else -> l("sync_reset_cloud_partial")
                                .replace("%1@", "${result.deleted}")
                                .replace("%2@", "${result.failed}")
                        }
                        wiping = false
                    }
                }) {
                    Text(l("sync_reset_cloud"), color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showConfirm = false }) { Text(l("cancel")) }
            }
        )
    }
}

@Composable
private fun DoctorRow(label: String, value: String) {
    Row(Modifier.padding(top = 6.dp)) {
        Text(
            label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.width(88.dp)
        )
        Text(value, style = MaterialTheme.typography.bodySmall)
    }
}
