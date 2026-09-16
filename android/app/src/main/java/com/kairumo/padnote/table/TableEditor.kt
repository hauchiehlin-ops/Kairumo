package com.kairumo.padnote.table

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.LocalizationStrings

/**
 * 表格編修面板（Android）。
 *
 * 控制項與 Apple 的 `TableStudioView` 對齊：增刪列欄、合併／取消合併、表頭、
 * 寬度與字級。同一組在地化鍵。
 */
@Composable
fun TableEditor(
    table: NoteTable,
    languageTag: String,
    isNew: Boolean,
    onCommit: (NoteTable) -> Unit,
    onDelete: () -> Unit,
    onDismiss: () -> Unit
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    var draft by remember(table.id) { mutableStateOf(table.copyTable()) }
    var row by remember { mutableIntStateOf(0) }
    var col by remember { mutableIntStateOf(0) }
    fun mutate(block: NoteTable.() -> Unit) {
        draft = draft.copyTable().apply(block)
        row = row.coerceIn(0, draft.rows - 1)
        col = col.coerceIn(0, draft.cols - 1)
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("table_studio")) },
        confirmButton = {
            TextButton(onClick = { onCommit(draft) }) {
                Text(l(if (isNew) "table_insert" else "table_update"))
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("cancel")) } },
        text = {
            Column(
                Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                // 即時預覽。沒有它的話，欄寬、字級、合併與表頭底色都要
                // 「插進去才知道」—— 而那時候面板已經關了。與畫布走同一份算繪。
                Text(l("table_preview"), style = MaterialTheme.typography.labelSmall)
                Box(
                    Modifier
                        .heightIn(max = 160.dp)
                        .horizontalScroll(rememberScrollState())
                        .verticalScroll(rememberScrollState())
                ) {
                    TablePreview(table = draft, density = 1f)
                }

                HorizontalDivider()

                // 格子
                Column(
                    Modifier
                        .heightIn(max = 200.dp)
                        .verticalScroll(rememberScrollState())
                        .horizontalScroll(rememberScrollState())
                ) {
                    for (r in 0 until draft.rows) {
                        Row {
                            for (c in 0 until draft.cols) {
                                if (draft.isCovered(r, c)) {
                                    // 被合併蓋住的格子不給編輯 —— 它的內容不會被顯示，
                                    // 讓人輸入等於讓人把字打進看不見的地方。
                                    Box(Modifier.width(110.dp).padding(2.dp))
                                } else {
                                    OutlinedTextField(
                                        value = draft.cell(r, c),
                                        onValueChange = { text -> mutate { setCell(text, r, c) } },
                                        modifier = Modifier
                                            .width(110.dp)
                                            .padding(2.dp),
                                        singleLine = true,
                                        textStyle = MaterialTheme.typography.bodySmall,
                                        label = if (r == row && c == col) {
                                            { Text("●", fontSize = 9.sp) }
                                        } else null
                                    )
                                }
                            }
                        }
                    }
                }

                HorizontalDivider()

                Row(Modifier.fillMaxWidth(), Arrangement.SpaceBetween, Alignment.CenterVertically) {
                    Text(l("table_header_row"))
                    Switch(draft.headerRow, onCheckedChange = { on -> mutate { headerRow = on } })
                }

                Row(Modifier.horizontalScroll(rememberScrollState())) {
                    TextButton(onClick = { mutate { insertRow(row + 1) } }) { Text(l("table_add_row")) }
                    TextButton(
                        onClick = { mutate { deleteRow(row) } },
                        enabled = draft.rows > 1
                    ) { Text(l("table_delete_row")) }
                }
                Row(Modifier.horizontalScroll(rememberScrollState())) {
                    TextButton(onClick = { mutate { insertColumn(col + 1) } }) { Text(l("table_add_column")) }
                    TextButton(
                        onClick = { mutate { deleteColumn(col) } },
                        enabled = draft.cols > 1
                    ) { Text(l("table_delete_column")) }
                }
                Row(Modifier.horizontalScroll(rememberScrollState())) {
                    TextButton(
                        onClick = { mutate { merge(row, col, 1, 2) } },
                        enabled = col + 1 < draft.cols
                    ) { Text(l("table_merge_right")) }
                    TextButton(
                        onClick = { mutate { merge(row, col, 2, 1) } },
                        enabled = row + 1 < draft.rows
                    ) { Text(l("table_merge_down")) }
                    TextButton(onClick = { mutate { unmerge(row, col) } }) { Text(l("table_unmerge")) }
                }

                HorizontalDivider()

                Text(l("table_width"))
                Slider(
                    value = draft.width,
                    onValueChange = { value -> mutate { width = value } },
                    valueRange = 200f..760f
                )
                Text(l("table_font_size"))
                Slider(
                    value = draft.fontSize,
                    onValueChange = { value -> mutate { fontSize = value } },
                    valueRange = 10f..24f,
                    steps = 13
                )

                HorizontalDivider()
                TextButton(onClick = onDelete) { Text(l("action_delete")) }
            }
        }
    )
}
