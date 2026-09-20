package com.kairumo.padnote.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.platform.StartupLogger
import kotlinx.coroutines.delay

@Composable
fun AppDiagnosticsDialog(
    versionString: String,
    coreStatusRows: List<Pair<String, String>>,
    latencySummary: String? = null,
    l: (String) -> String,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    var selectedTab by remember { mutableIntStateOf(0) }
    var copiedStartupLogs by remember { mutableStateOf(false) }

    LaunchedEffect(copiedStartupLogs) {
        if (copiedStartupLogs) {
            delay(1500)
            copiedStartupLogs = false
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = onDismiss) { Text(l("close")) }
        },
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("🔧", fontSize = 20.sp, modifier = Modifier.padding(end = 8.dp))
                Text(l("system_diagnostics"), fontWeight = FontWeight.Bold)
            }
        },
        text = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 520.dp)
            ) {
                TabRow(selectedTabIndex = selectedTab) {
                    Tab(
                        selected = selectedTab == 0,
                        onClick = { selectedTab = 0 },
                        text = { Text(l("app_version_info"), maxLines = 1, fontSize = 12.sp) }
                    )
                    Tab(
                        selected = selectedTab == 1,
                        onClick = { selectedTab = 1 },
                        text = { Text(l("startup_logs_title"), maxLines = 1, fontSize = 12.sp) }
                    )
                }

                Spacer(modifier = Modifier.height(12.dp))

                if (selectedTab == 0) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .verticalScroll(rememberScrollState()),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(10.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                        ) {
                            Column(
                                modifier = Modifier.padding(12.dp),
                                verticalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                Row(modifier = Modifier.fillMaxWidth()) {
                                    Text(l("version_number"), style = MaterialTheme.typography.bodySmall, modifier = Modifier.weight(1f))
                                    Text(versionString, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Medium)
                                }
                                HorizontalDivider()
                                Row(modifier = Modifier.fillMaxWidth()) {
                                    Text(l("core_engine"), style = MaterialTheme.typography.bodySmall, modifier = Modifier.weight(1f))
                                    Text(versionString, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                                HorizontalDivider()
                                Row(modifier = Modifier.fillMaxWidth()) {
                                    Text(l("platform_desc"), style = MaterialTheme.typography.bodySmall, modifier = Modifier.weight(1f))
                                    Text("Android ${android.os.Build.VERSION.RELEASE} (API ${android.os.Build.VERSION.SDK_INT})", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                                HorizontalDivider()
                                Row(modifier = Modifier.fillMaxWidth()) {
                                    Text(l("arch_mode"), style = MaterialTheme.typography.bodySmall, modifier = Modifier.weight(1f))
                                    Text(android.os.Build.SUPPORTED_ABIS.firstOrNull() ?: "Unknown", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }
                        }

                        if (!latencySummary.isNullOrBlank()) {
                            Card(
                                modifier = Modifier.fillMaxWidth(),
                                shape = RoundedCornerShape(10.dp),
                                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                            ) {
                                Column(modifier = Modifier.padding(12.dp)) {
                                    Text(
                                        "${l("ink_latency_label")}：$latencySummary",
                                        style = MaterialTheme.typography.bodySmall,
                                        fontFamily = FontFamily.Monospace
                                    )
                                }
                            }
                        }

                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(10.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                        ) {
                            Column(
                                modifier = Modifier.padding(12.dp),
                                verticalArrangement = Arrangement.spacedBy(4.dp)
                            ) {
                                coreStatusRows.forEach { (label, value) ->
                                    Row(modifier = Modifier.fillMaxWidth()) {
                                        Text("$label: ", style = MaterialTheme.typography.bodySmall, fontFamily = FontFamily.Monospace, fontWeight = FontWeight.SemiBold)
                                        Text(value, style = MaterialTheme.typography.bodySmall, fontFamily = FontFamily.Monospace)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // 分頁 2：啟動與效能診斷日誌
                    Column(modifier = Modifier.fillMaxWidth()) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.End,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            val hasEntries = StartupLogger.entries.isNotEmpty()

                            TextButton(
                                onClick = {
                                    LogExportUtility.copy(context, StartupLogger.exportText(includeTimestamp = false))
                                    copiedStartupLogs = true
                                },
                                enabled = hasEntries
                            ) {
                                Text(
                                    if (copiedStartupLogs) "✓ ${l("log_copied")}" else l("log_copy"),
                                    color = if (copiedStartupLogs) Color(0xFF2E7D32) else MaterialTheme.colorScheme.primary,
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.SemiBold
                                )
                            }

                            Spacer(modifier = Modifier.width(4.dp))

                            TextButton(
                                onClick = {
                                    LogExportUtility.shareTextFile(
                                        context,
                                        StartupLogger.exportText(includeTimestamp = true),
                                        "kairumo-startup-logs.txt"
                                    )
                                },
                                enabled = hasEntries
                            ) {
                                Text(l("log_export"), fontSize = 12.sp)
                            }

                            Spacer(modifier = Modifier.width(4.dp))

                            TextButton(
                                onClick = { StartupLogger.clear() },
                                enabled = hasEntries
                            ) {
                                Text(l("log_clear"), fontSize = 12.sp)
                            }
                        }

                        if (StartupLogger.entries.isEmpty()) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(180.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    l("log_empty"),
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        } else {
                            LazyColumn(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(320.dp)
                                    .background(
                                        MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                                        RoundedCornerShape(8.dp)
                                    )
                                    .padding(8.dp),
                                verticalArrangement = Arrangement.spacedBy(4.dp)
                            ) {
                                items(StartupLogger.entries, key = { it.id }) { entry ->
                                    Row(
                                        verticalAlignment = Alignment.Top,
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        val isMain = entry.thread == "Main"
                                        Text(
                                            text = entry.thread,
                                            fontSize = 9.sp,
                                            fontFamily = FontFamily.Monospace,
                                            fontWeight = FontWeight.Bold,
                                            color = if (isMain) Color(0xFFE65100) else Color(0xFF1565C0),
                                            modifier = Modifier
                                                .clip(RoundedCornerShape(3.dp))
                                                .background(
                                                    if (isMain) Color(0xFFFFE0B2) else Color(0xFFBBDEFB)
                                                )
                                                .padding(horizontal = 4.dp, vertical = 1.dp)
                                        )

                                        Spacer(modifier = Modifier.width(6.dp))

                                        Text(
                                            text = entry.message,
                                            fontSize = 11.sp,
                                            fontFamily = FontFamily.Monospace,
                                            color = MaterialTheme.colorScheme.onSurface,
                                            modifier = Modifier.weight(1f)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    )
}
