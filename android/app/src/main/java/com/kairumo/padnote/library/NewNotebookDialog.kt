package com.kairumo.padnote.library

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.kairumo.padnote.ui.DialogResizeHandle
import com.kairumo.padnote.ui.rememberDialogHeight

/**
 * 「新增筆記」對話框（工作項 S-61）。
 *
 * # 為什麼 Android 原本沒有這個
 *
 * 之前按「新增筆記」直接就建一本空白的 —— 連命名都不能。Apple 端一直有
 * 範本挑選視窗，兩邊差了一整個步驟。這一版補上，版面比照 Apple：
 * 標題 → 文件範本（主題收合）→ 版本切換。
 *
 * # 為什麼預設整個收起來
 *
 * 39 種範本全部攤開的話，原本兩下就完成的「新增一張空白紙」會被埋在幾十列
 * 底下。最常用的動作不該變成最難的那一個，所以主題預設收合，
 * 不選範本直接按確定就是一張空白頁。
 */
@Composable
fun NewNotebookDialog(
    themes: List<DocumentTemplateCatalog.Theme>,
    lang: String,
    l: (String) -> String,
    onDismiss: () -> Unit,
    onConfirm: (title: String, templateId: String?, kind: DocumentTemplateCatalog.VariantKind) -> Unit
) {
    var title by remember { mutableStateOf("") }
    var selectedId by remember { mutableStateOf<String?>(null) }
    var kind by remember {
        mutableStateOf(DocumentTemplateCatalog.VariantKind.EXAMPLE)
    }
    var expanded by remember { mutableStateOf<String?>(null) }
    // 高度由使用者拉。固定 460dp 的話，範本樹一展開就得在一個小窗裡捲很久。
    val height = rememberDialogHeight("newNotebook")

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("new_notebook")) },
        confirmButton = {
            TextButton(onClick = { onConfirm(title, selectedId, kind) }) { Text(l("confirm")) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("cancel")) } },
        text = {
            Column {
            LazyColumn(
                modifier = Modifier.height(height.value),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                item {
                    OutlinedTextField(
                        value = title,
                        onValueChange = { title = it },
                        label = { Text(l("note_title")) },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                item {
                    Text(
                        l("doc_template_section"),
                        style = MaterialTheme.typography.labelLarge,
                        modifier = Modifier.padding(top = 8.dp)
                    )
                }

                if (selectedId != null) {
                    item {
                        SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                            DocumentTemplateCatalog.VariantKind.entries.forEachIndexed { i, k ->
                                SegmentedButton(
                                    selected = kind == k,
                                    onClick = { kind = k },
                                    shape = SegmentedButtonDefaults.itemShape(
                                        i, DocumentTemplateCatalog.VariantKind.entries.size
                                    )
                                ) { Text(l(k.labelKey)) }
                            }
                        }
                    }
                }

                items(themes, key = { it.id }) { theme ->
                    ThemeRow(
                        theme = theme,
                        lang = lang,
                        isExpanded = expanded == theme.id,
                        selectedId = selectedId,
                        onToggle = { expanded = if (expanded == theme.id) null else theme.id },
                        onSelect = { selectedId = if (selectedId == it) null else it }
                    )
                }

                item {
                    Text(
                        l("doc_template_hint"),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 8.dp)
                    )
                }
            }
            // 把手在捲動區外面：放進 LazyColumn 會跟著內容捲走。
            DialogResizeHandle(state = height, key = "newNotebook")
            }
        }
    )
}

@Composable
private fun ThemeRow(
    theme: DocumentTemplateCatalog.Theme,
    lang: String,
    isExpanded: Boolean,
    selectedId: String?,
    onToggle: () -> Unit,
    onSelect: (String) -> Unit
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onToggle)
                .padding(vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                DocumentTemplateCatalog.localized(theme.name, lang),
                style = MaterialTheme.typography.titleSmall,
                modifier = Modifier.weight(1f)
            )
            Icon(chevron(isExpanded), contentDescription = null)
        }

        if (isExpanded) {
            for (category in theme.categories) {
                Text(
                    DocumentTemplateCatalog.localized(category.name, lang),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(start = 8.dp, top = 6.dp, bottom = 2.dp)
                )
                for (tmpl in category.templates) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onSelect(tmpl.id) }
                            .padding(start = 8.dp, top = 2.dp, bottom = 2.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        RadioButton(
                            selected = selectedId == tmpl.id,
                            onClick = { onSelect(tmpl.id) }
                        )
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                DocumentTemplateCatalog.localized(tmpl.name, lang),
                                style = MaterialTheme.typography.bodyMedium
                            )
                            Text(
                                DocumentTemplateCatalog.localized(tmpl.description, lang),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 2,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }
                }
            }
        }
    }
}

private fun chevron(expanded: Boolean): ImageVector =
    if (expanded) Icons.Filled.KeyboardArrowUp else Icons.Filled.KeyboardArrowDown
