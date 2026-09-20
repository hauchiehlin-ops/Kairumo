package com.kairumo.padnote.ui

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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
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
import com.kairumo.padnote.sync.SyncLogger
import com.kairumo.padnote.sync.SyncSource
import kotlinx.coroutines.delay

@Composable
fun SyncLogCard(
    filterSource: SyncSource? = null,
    l: (String) -> String,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    var copiedLogs by remember { mutableStateOf(false) }

    LaunchedEffect(copiedLogs) {
        if (copiedLogs) {
            delay(1500)
            copiedLogs = false
        }
    }

    val entries = remember(SyncLogger.entries.size, filterSource) {
        if (filterSource != null) {
            SyncLogger.entries.filter { it.source == filterSource || it.source == SyncSource.GENERAL }
        } else {
            SyncLogger.entries.toList()
        }
    }

    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(10.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
        )
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    l("sync_logs_title"),
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f)
                )

                val hasLogs = entries.isNotEmpty()

                TextButton(
                    onClick = {
                        LogExportUtility.copy(
                            context,
                            SyncLogger.exportText(filter = filterSource, includeTimestamp = false)
                        )
                        copiedLogs = true
                    },
                    enabled = hasLogs
                ) {
                    Text(
                        if (copiedLogs) "✓ ${l("log_copied")}" else l("log_copy"),
                        color = if (copiedLogs) Color(0xFF2E7D32) else MaterialTheme.colorScheme.primary,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                }

                TextButton(
                    onClick = {
                        LogExportUtility.shareTextFile(
                            context,
                            SyncLogger.exportText(filter = filterSource, includeTimestamp = true),
                            "kairumo-sync-logs.txt"
                        )
                    },
                    enabled = hasLogs
                ) {
                    Text(l("log_export"), fontSize = 11.sp)
                }

                TextButton(
                    onClick = { SyncLogger.clear(filterSource) },
                    enabled = hasLogs
                ) {
                    Text(l("log_clear"), fontSize = 11.sp)
                }
            }

            if (entries.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(80.dp),
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
                        .heightIn(max = 200.dp)
                        .background(
                            MaterialTheme.colorScheme.surfaceVariant,
                            RoundedCornerShape(6.dp)
                        )
                        .padding(6.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                    reverseLayout = true
                ) {
                    items(entries.reversed(), key = { it.id }) { entry ->
                        Row(
                            verticalAlignment = Alignment.Top,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(
                                text = entry.source.rawValue,
                                fontSize = 8.sp,
                                fontFamily = FontFamily.Monospace,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onPrimaryContainer,
                                modifier = Modifier
                                    .clip(RoundedCornerShape(3.dp))
                                    .background(MaterialTheme.colorScheme.primaryContainer)
                                    .padding(horizontal = 4.dp, vertical = 1.dp)
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                text = entry.message,
                                fontSize = 10.sp,
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
