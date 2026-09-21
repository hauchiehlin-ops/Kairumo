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
import com.kairumo.padnote.library.AccountSyncStore
import com.kairumo.padnote.library.NotebookLibrary
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
    val context = LocalContext.current
    val isSyncing by AutoSync.isSyncing.collectAsState()
    val needsSignIn by AutoSync.needsSignIn.collectAsState()

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
            Text("同步狀態", style = MaterialTheme.typography.labelMedium)
            val d = diagnostics
            if (d == null) {
                Row(Modifier.padding(top = 6.dp)) { Text("讀取中…", style = MaterialTheme.typography.bodySmall) }
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
            }
        }
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
