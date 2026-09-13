package com.kairumo.padnote.ui

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/**
 * 引擎與權限中心 (WP13 & I1/I2)
 * 全平台統一介面，用於管理模型下載與系統權限狀態。
 */
@Composable
fun EngineCenterScreen(
    hasMicPermission: Boolean,
    onRequestMicPermission: () -> Unit,
    asrModelStatus: ModelStatus,
    onDownloadAsrModel: () -> Unit,
    syncProviderStatus: SyncStatus,
    onConfigureSync: () -> Unit
) {
    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Text("引擎與權限中心", style = MaterialTheme.typography.headlineMedium)
        Spacer(modifier = Modifier.height(24.dp))

        // 1. 麥克風權限
        PermissionItem(
            title = "麥克風權限 (語音轉錄必須)",
            isGranted = hasMicPermission,
            action = onRequestMicPermission
        )

        Spacer(modifier = Modifier.height(16.dp))

        // 2. ASR 離線模型管理
        ModelItem(
            title = "Paraformer 離線中文轉錄模型",
            status = asrModelStatus,
            action = onDownloadAsrModel
        )

        Spacer(modifier = Modifier.height(16.dp))

        // 3. 雲端同步狀態
        SyncItem(
            title = "跨裝置同步",
            status = syncProviderStatus,
            action = onConfigureSync
        )
    }
}

@Composable
fun PermissionItem(title: String, isGranted: Boolean, action: () -> Unit) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(title)
        if (isGranted) {
            Text("已授權", color = MaterialTheme.colorScheme.primary)
        } else {
            Button(onClick = action) { Text("授予權限") }
        }
    }
}

@Composable
fun ModelItem(title: String, status: ModelStatus, action: () -> Unit) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(title)
        when (status) {
            ModelStatus.READY -> Text("就緒", color = MaterialTheme.colorScheme.primary)
            ModelStatus.DOWNLOADING -> Text("下載中...")
            ModelStatus.NOT_DOWNLOADED -> Button(onClick = action) { Text("下載 (150MB)") }
        }
    }
}

@Composable
fun SyncItem(title: String, status: SyncStatus, action: () -> Unit) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(title)
        when (status) {
            SyncStatus.CONNECTED -> Text("Google Drive 已連線", color = MaterialTheme.colorScheme.primary)
            SyncStatus.DISCONNECTED -> Button(onClick = action) { Text("設定同步") }
        }
    }
}

enum class ModelStatus { READY, DOWNLOADING, NOT_DOWNLOADED }
enum class SyncStatus { CONNECTED, DISCONNECTED }
