package com.kairumo.padnote.library

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.text.DateFormat
import java.util.Date

/**
 * 首頁（Android）。
 *
 * # 為什麼要有這個畫面
 *
 * 在此之前 Android **沒有首頁** —— App 一開就直接進一本筆記的一頁，沒有清單、
 * 沒有搜尋、沒有「新增一本」。使用者看到的是一個畫圖玩具，不是筆記本。
 *
 * # 區塊順序與 Apple 端一致
 *
 * 身分 → 搜尋 → 主要動作 → 繼續 → 全部筆記 → 資料與同步 → 版本號。
 * 順序自己排一套的話，同一個人換裝置就要重新找每一樣東西在哪裡。
 * （Apple 端還有「最近錄音」與「素材圖庫」，Android 的底層還沒有，
 *   補上之後會插回原本的位置。）
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun HomeScreen(
    entries: List<NotebookLibrary.Entry>,
    profileName: String,
    profileColorHex: String,
    appVersion: String,
    sort: NotebookLibrary.Sort,
    recording: Boolean,
    l: (String) -> String,
    onOpen: (String) -> Unit,
    onCreate: () -> Unit,
    onRename: (NotebookLibrary.Entry) -> Unit,
    onDelete: (NotebookLibrary.Entry) -> Unit,
    onSortChange: (NotebookLibrary.Sort) -> Unit,
    onEditIdentity: () -> Unit,
    onToggleRecording: () -> Unit,
    onBackup: () -> Unit,
    onRestore: () -> Unit
) {
    var query by remember { mutableStateOf("") }

    val filtered = remember(entries, query) {
        if (query.isBlank()) entries
        else entries.filter { it.title.contains(query.trim(), ignoreCase = true) }
    }

    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = 16.dp)
    ) {
        // ── 1. 身分 ──────────────────────────────────────────────
        item {
            Card(
                modifier = Modifier.fillMaxWidth().clickable { onEditIdentity() },
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant
                )
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(40.dp)
                            .background(parseHex(profileColorHex) ?: Color(0xFF007AFF), CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            profileName.take(1).uppercase(),
                            color = Color.White,
                            fontWeight = FontWeight.Bold
                        )
                    }
                    Column(Modifier.weight(1f)) {
                        Text(profileName, fontWeight = FontWeight.SemiBold)
                        Text(
                            l("identity_desc_short"),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    TextButton(onClick = onEditIdentity) { Text(l("edit_identity")) }
                }
            }
        }

        // ── 2. 搜尋 ──────────────────────────────────────────────
        item {
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                placeholder = { Text(l("search_placeholder"), maxLines = 1) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
        }

        // ── 3. 主要動作 ──────────────────────────────────────────
        item {
            FlowRow(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                ActionCard(l("new_note"), primary = true, onClick = onCreate)
                ActionCard(
                    l(if (recording) "stop_recording" else "start_recording"),
                    primary = false,
                    onClick = onToggleRecording
                )
            }
        }

        // ── 4. 繼續（最近三本）────────────────────────────────────
        if (filtered.isNotEmpty() && query.isBlank()) {
            item { SectionTitle(l("continue_working")) }
            items(filtered.take(3), key = { "recent-${it.id}" }) { entry ->
                NotebookRow(entry, l, onOpen, onRename, onDelete)
            }
        }

        // ── 5. 全部筆記 ──────────────────────────────────────────
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                SectionTitle("${l("all_notebooks")} (${entries.size})", Modifier.weight(1f))
                SortMenu(sort, l, onSortChange)
            }
        }

        if (filtered.isEmpty()) {
            item {
                Text(
                    if (query.isBlank()) l("notebook_empty") else l("search_no_result"),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.fillMaxWidth().padding(vertical = 24.dp)
                )
            }
        } else {
            items(filtered, key = { it.id }) { entry ->
                NotebookRow(entry, l, onOpen, onRename, onDelete)
            }
        }

        // ── 6. 資料與同步 ────────────────────────────────────────
        item {
            HorizontalDivider()
            SectionTitle(l("data_and_sync"))
        }
        item {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                ActionCard(l("backup_create"), primary = false, onClick = onBackup)
                ActionCard(l("backup_restore"), primary = false, onClick = onRestore)
                Text(
                    l("backup_explainer"),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        // ── 7. 版本號 ────────────────────────────────────────────
        item {
            Text(
                appVersion,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp)
            )
        }
    }
}

@Composable
private fun SectionTitle(text: String, modifier: Modifier = Modifier) {
    Text(
        text,
        style = MaterialTheme.typography.titleMedium,
        fontWeight = FontWeight.Bold,
        modifier = modifier.padding(top = 6.dp)
    )
}

@Composable
private fun ActionCard(label: String, primary: Boolean, onClick: () -> Unit) {
    Card(
        modifier = Modifier.width(180.dp).clickable { onClick() },
        colors = CardDefaults.cardColors(
            containerColor = if (primary) MaterialTheme.colorScheme.primary
            else MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Text(
            label,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 16.dp),
            color = if (primary) MaterialTheme.colorScheme.onPrimary
            else MaterialTheme.colorScheme.onSurfaceVariant,
            fontWeight = FontWeight.SemiBold
        )
    }
}

@Composable
private fun NotebookRow(
    entry: NotebookLibrary.Entry,
    l: (String) -> String,
    onOpen: (String) -> Unit,
    onRename: (NotebookLibrary.Entry) -> Unit,
    onDelete: (NotebookLibrary.Entry) -> Unit
) {
    var menu by remember(entry.id) { mutableStateOf(false) }
    Card(
        modifier = Modifier.fillMaxWidth().clickable { onOpen(entry.id) },
        shape = RoundedCornerShape(12.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(Modifier.weight(1f)) {
                Text(entry.title, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                Text(
                    "${entry.pageCount} ${l("pages")} · ${formatDate(entry.modifiedAt)}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Box {
                TextButton(onClick = { menu = true }) { Text("⋯") }
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                    DropdownMenuItem(
                        text = { Text(l("open_note")) },
                        onClick = { menu = false; onOpen(entry.id) }
                    )
                    DropdownMenuItem(
                        text = { Text(l("rename_note")) },
                        onClick = { menu = false; onRename(entry) }
                    )
                    DropdownMenuItem(
                        text = { Text(l("delete")) },
                        onClick = { menu = false; onDelete(entry) }
                    )
                }
            }
        }
    }
}

@Composable
private fun SortMenu(
    sort: NotebookLibrary.Sort,
    l: (String) -> String,
    onSortChange: (NotebookLibrary.Sort) -> Unit
) {
    var open by remember { mutableStateOf(false) }
    val label = when (sort) {
        NotebookLibrary.Sort.MODIFIED -> l("sort_by_date")
        NotebookLibrary.Sort.TITLE -> l("sort_by_title")
        NotebookLibrary.Sort.PAGES -> l("sort_by_pages")
    }
    Box {
        TextButton(onClick = { open = true }) {
            Text(label, style = MaterialTheme.typography.labelMedium)
        }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            for (option in NotebookLibrary.Sort.entries) {
                val text = when (option) {
                    NotebookLibrary.Sort.MODIFIED -> l("sort_by_date")
                    NotebookLibrary.Sort.TITLE -> l("sort_by_title")
                    NotebookLibrary.Sort.PAGES -> l("sort_by_pages")
                }
                DropdownMenuItem(
                    text = { Text(text) },
                    trailingIcon = { if (option == sort) Text("✓") },
                    onClick = { open = false; onSortChange(option) }
                )
            }
        }
    }
}

/** 重新命名對話框。與 Apple 端同一組字串鍵。 */
@Composable
fun RenameNotebookDialog(
    entry: NotebookLibrary.Entry,
    l: (String) -> String,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit
) {
    var title by remember(entry.id) { mutableStateOf(entry.title) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("rename_note")) },
        text = {
            OutlinedTextField(
                value = title,
                onValueChange = { title = it },
                label = { Text(l("note_title")) },
                singleLine = true
            )
        },
        confirmButton = {
            TextButton(onClick = { onConfirm(title.trim()); onDismiss() }) { Text(l("confirm")) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("cancel")) } }
    )
}

/**
 * 刪除確認。
 *
 * 一定要問。刪掉的是整個套件目錄，沒有回收桶，那是使用者唯一的一份資料。
 */
@Composable
fun DeleteNotebookDialog(
    entry: NotebookLibrary.Entry,
    l: (String) -> String,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("delete")) },
        text = { Text(l("delete_notebook_confirm").replace("%@", entry.title)) },
        confirmButton = {
            TextButton(onClick = { onConfirm(); onDismiss() }) { Text(l("delete")) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("cancel")) } }
    )
}

private fun formatDate(millis: Long): String =
    if (millis <= 0) "—"
    else DateFormat.getDateInstance(DateFormat.MEDIUM).format(Date(millis))

private fun parseHex(hex: String): Color? =
    com.kairumo.padnote.chart.ChartRenderer.parseColor(hex)?.let { Color(it) }
