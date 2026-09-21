package com.kairumo.padnote.library

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.border
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.material3.FilterChip
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
import androidx.compose.ui.platform.testTag
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
// FlowRow 在這個 Compose 版本仍標著實驗性（主題膠囊用它換行，見下面的說明）。
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun NewNotebookDialog(
    themes: List<DocumentTemplateCatalog.Theme>,
    lang: String,
    l: (String) -> String,
    /**
     * 最近套用過的樣板（最多三個，最近的在前）。
     *
     * 傳解析好的樣板而不是 id：常用清單裡可能是**紙張樣板**，而
     * `themes` 這一份已經把紙張主題濾掉了（它掛在上面的紙張清單底下）——
     * 只傳 id 的話，紙張樣板會在常用清單裡查不到而靜靜地消失。
     */
    recentTemplates: List<DocumentTemplateCatalog.Template> = emptyList(),
    onDismiss: () -> Unit,
    /**
     * 改走「建立加密筆記本」那條路。
     *
     * 加密不是這張表單裡的一個開關：它有三步而且不能跳
     * （設密碼 → 抄復原碼 → 把復原碼輸回來），塞成開關會讓人以為
     * 那是可以之後再說的選項，而復原碼沒有「之後再說」。
     */
    onCreateEncrypted: () -> Unit = {},
    onConfirm: (
        title: String,
        templateId: String?,
        kind: DocumentTemplateCatalog.VariantKind,
        paperId: String,
        paperVariant: DocumentTemplateCatalog.VariantKind?,
        /** 版面配色的 id（核心 `guidePalettes()`）。 */
        paletteId: String
    ) -> Unit
) {
    var title by remember { mutableStateOf("") }
    // 版面配色。預設是核心清單的第一組（石墨），與 Apple 的預設一致。
    var paletteId by remember { mutableStateOf(uniffi.padnote_core.guidePalettes().first().id) }
    var selectedId by remember { mutableStateOf<String?>(null) }
    var kind by remember {
        mutableStateOf(DocumentTemplateCatalog.VariantKind.EXAMPLE)
    }
    var expanded by remember { mutableStateOf<String?>(null) }

    // 紙張。清單來自核心 `paperTemplates()` —— Apple 端讀的是同一份，
    // 各寫一份的話兩邊的紙張種類與順序遲早會不一樣。
    val paperThemes = remember { uniffi.padnote_core.paperThemes() }
    var paperTheme by remember { mutableStateOf(paperThemes.first()) }
    var paperId by remember { mutableStateOf("blank") }
    // 紙張要不要順便鋪一份示範內容。預設不套用 —— 最常用的動作仍然是
    // 「給我一張空白紙」，那件事不該因此多按一下。
    var paperVariant by remember {
        mutableStateOf<DocumentTemplateCatalog.VariantKind?>(null)
    }
    // 選了文件範本，紙張就跟著它走：公文「簽」不該鋪在行動端線框紙上。
    val paperLocked = selectedId != null

    // 高度由使用者拉。固定 460dp 的話，範本樹一展開就得在一個小窗裡捲很久。
    val height = rememberDialogHeight("newNotebook")

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("new_notebook")) },
        confirmButton = {
            TextButton(
                onClick = { onConfirm(title, selectedId, kind, paperId, paperVariant, paletteId) },
                modifier = Modifier.testTag("new_notebook.confirm")
            ) { Text(l("confirm")) }
        },
        dismissButton = {
            androidx.compose.foundation.layout.Row {
                // 加密走另一條路 —— 見 `onCreateEncrypted` 的說明。
                TextButton(
                    onClick = onCreateEncrypted,
                    modifier = Modifier.testTag("new_notebook.encrypted")
                ) { Text("🔒 " + l("encrypt_notebook")) }
                TextButton(
                    onClick = onDismiss,
                    modifier = Modifier.testTag("new_notebook.cancel")
                ) { Text(l("cancel")) }
            }
        },
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
                        modifier = Modifier.fillMaxWidth().testTag("new_notebook.title.field")
                    )
                }

                // ── 常用樣板 ──────────────────────────────────────
                //
                // 39 種文件範本收在一棵三層的樹裡，而使用者絕大多數時候要的
                // 是「再來一份跟上次一樣的」—— 那件事原本要展開主題、展開
                // 分類、再認出那一個。最常用的路徑不該是最長的。
                //
                // 沒用過任何樣板時整個區塊不出現：一張寫著「還沒有」的卡片
                // 只是佔位置。
                val recents = recentTemplates
                if (recents.isNotEmpty()) {
                    item {
                        Text(
                            l("recent_templates"),
                            style = MaterialTheme.typography.labelLarge,
                            modifier = Modifier.padding(top = 8.dp)
                        )
                    }
                    items(recents, key = { "recent-" + it.id }) { tmpl ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { selectedId = tmpl.id }
                                .padding(vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            RadioButton(
                                selected = selectedId == tmpl.id,
                                onClick = { selectedId = tmpl.id }
                            )
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    DocumentTemplateCatalog.localized(tmpl.name, lang),
                                    style = MaterialTheme.typography.bodyMedium
                                )
                                Text(
                                    DocumentTemplateCatalog.localized(tmpl.description, lang),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                            }
                        }
                    }
                }

                // ── 紙張（主題分類 + 清單 + 內容）───────────────────
                //
                // 在此之前 Android 的「新增筆記」**連紙張都不能選** ——
                // 同一個 App，一邊能挑康乃爾格式，一邊只拿得到空白紙。
                item {
                    Text(
                        l("select_template"),
                        style = MaterialTheme.typography.labelLarge,
                        modifier = Modifier.padding(top = 8.dp)
                    )
                }
                // 主題切換器。**不是分段控制項**：主題從四個長到七個，
                // 七個中文標籤擠在同一列就是先前回報過的「文字被擠壓」。
                //
                // 也**不是橫向捲動的單列**（原本是）。對話框寬度只放得下三個半，
                // 第四個被切在邊緣、後面三組完全不在畫面上 —— 使用者回報的
                // 「看不到全部」就是這個：捲動條不明顯，一列膠囊看起來就像
                // 「總共只有這幾組」。換行排版讓七組一次全部看得到。
                item {
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                        modifier = Modifier.fillMaxWidth().testTag("new_notebook.paper.themes")
                    ) {
                        paperThemes.forEach { theme ->
                            val active = paperTheme == theme
                            FilterChip(
                                selected = active,
                                enabled = !paperLocked,
                                onClick = {
                                    paperTheme = theme
                                    // 切主題就選那一組的第一張，否則清單換了、
                                    // 勾選卻還留在上一組看不見的那一張。
                                    paperId = uniffi.padnote_core
                                        .paperTemplatesForTheme(theme).first().id
                                },
                                label = {
                                    Text(
                                        l(uniffi.padnote_core.paperThemeKey(theme)),
                                        style = MaterialTheme.typography.labelMedium,
                                        maxLines = 1
                                    )
                                }
                            )
                        }
                    }
                }
                items(
                    uniffi.padnote_core.paperTemplatesForTheme(paperTheme),
                    key = { it.id }
                ) { paper ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("new_notebook.paper.list")
                            .clickable(enabled = !paperLocked) { paperId = paper.id }
                            .padding(vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        RadioButton(
                            selected = paperId == paper.id,
                            enabled = !paperLocked,
                            onClick = { paperId = paper.id }
                        )
                        Column(modifier = Modifier.weight(1f)) {
                            Text(l(paper.titleKey), style = MaterialTheme.typography.bodyMedium)
                            Text(
                                l(paper.descKey),
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 2,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }
                }
                item {
                    if (paperLocked) {
                        Text(
                            l("paper_locked_by_doc"),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    } else {
                        // 這張紙要不要帶一份示範內容。
                        SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                            val options: List<DocumentTemplateCatalog.VariantKind?> =
                                listOf(null) + DocumentTemplateCatalog.VariantKind.entries
                            options.forEachIndexed { i, option ->
                                SegmentedButton(
                                    selected = paperVariant == option,
                                    onClick = { paperVariant = option },
                                    shape = SegmentedButtonDefaults.itemShape(i, options.size)
                                ) {
                                    Text(
                                        l(option?.labelKey ?: "paper_content_none"),
                                        style = MaterialTheme.typography.labelSmall,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                }
                            }
                        }
                    }
                }

                // ── 版面配色（S-93）──────────────────────────────
                //
                // Android 的畫布早就讀得到也畫得出 `guidePalette`，缺的一直是
                // 這一排色點 —— 於是 Apple 挑好的顏色同步過來看得到，
                // 在 Android 上卻改不了。
                //
                // 畫顏色本身、名字寫在下面：使用者要挑的是顏色，不是「靛藍」
                // 這兩個字。與 Apple 的 `paletteRow` 同一個版型。
                item {
                    Text(
                        l("guide_palette"),
                        style = MaterialTheme.typography.labelLarge,
                        modifier = Modifier.padding(top = 8.dp).testTag("new_notebook.palette")
                    )
                }
                item {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        uniffi.padnote_core.guidePalettes().forEach { palette ->
                            val active = paletteId == palette.id
                            Column(
                                modifier = Modifier
                                    .weight(1f)
                                    .clickable { paletteId = palette.id },
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(22.dp)
                                        .background(
                                            com.kairumo.padnote.chart.ChartRenderer.parseColor(palette.accentHex)?.let { androidx.compose.ui.graphics.Color(it) }
                                                ?: MaterialTheme.colorScheme.primary,
                                            CircleShape
                                        )
                                        .then(
                                            if (active) {
                                                Modifier.border(
                                                    2.dp,
                                                    MaterialTheme.colorScheme.primary,
                                                    CircleShape
                                                )
                                            } else {
                                                Modifier
                                            }
                                        )
                                )
                                Text(
                                    l(palette.nameKey),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = if (active) {
                                        MaterialTheme.colorScheme.primary
                                    } else {
                                        MaterialTheme.colorScheme.onSurfaceVariant
                                    },
                                    maxLines = 1
                                )
                            }
                        }
                    }
                }

                item {
                    Text(
                        l("doc_template_section"),
                        style = MaterialTheme.typography.labelLarge,
                        modifier = Modifier.padding(top = 8.dp).testTag("new_notebook.document.current")
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
                    // parity: new_notebook.document.tree
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
