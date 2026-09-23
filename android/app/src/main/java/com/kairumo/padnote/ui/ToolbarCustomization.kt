package com.kairumo.padnote.ui

import android.content.Context
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.kairumo.padnote.LocalizationStrings
import com.kairumo.padnote.library.AccountSyncStore
import uniffi.padnote_core.FfiTool
import uniffi.padnote_core.FfiToolGroupInfo
import uniffi.padnote_core.FfiToolbar
import uniffi.padnote_core.localeForTag

/**
 * 自訂工具列（工作項 S-261）。
 *
 * # 為什麼不是各平台各寫一份
 *
 * 哪些工具存在、分幾組、關掉正在用的那一支之後該換成哪一支 —— 全部在核心
 * （`padnote-toolbar`）。這裡只做三件事：畫開關、存下來、把結果餵回工具列。
 *
 * 設定走 `AccountSyncStore` 的 `toolbarJson` 欄位，所以**會跟著帳號跑**。
 * 在 Android 上關掉的水彩筆，iPad 打開就已經是關的。那條管線其實早就鋪好了，
 * 只是一直沒有人讀寫它。
 */
object ToolbarSettings {

    private var core: FfiToolbar? = null
    private var loadedTag: String? = null

    /**
     * 目前隱藏的工具，以**跨平台識別字**表示（`editor.ink.pen`…）。
     *
     * 存識別字而不是 `FfiTool`：`InkTool` 早就掛著同一個字串當測試標籤
     * （`parityIdentifier`），用它對照就不必再維護一張「哪個 enum 對哪個
     * enum」的表。那種表漏一格不會有人發現 —— 症狀只是某支筆關不掉。
     *
     * 用 `mutableStateOf` 而不是普通欄位：工具列是 Composable，
     * 改完設定要能立刻重組，否則使用者得退出筆記本再進來才看得到結果。
     */
    var hiddenIdentifiers by mutableStateOf<Set<String>>(emptySet())
        private set

    private fun core(context: Context, languageTag: String): FfiToolbar {
        val existing = core
        if (existing != null && loadedTag == languageTag) return existing
        existing?.close()
        val locale = localeForTag(languageTag)
        val saved = AccountSyncStore.syncedToolbarJson(context)
        val fresh = if (saved != null) FfiToolbar.fromJson(locale, saved) else FfiToolbar(locale)
        core = fresh
        loadedTag = languageTag
        refresh(fresh)
        return fresh
    }

    /** 全部工具，依分組排列 —— 設定畫面要的就是這份。 */
    fun groups(context: Context, languageTag: String): List<FfiToolGroupInfo> =
        core(context, languageTag).allGroups()

    fun isVisible(context: Context, languageTag: String, identifier: String): Boolean {
        core(context, languageTag)
        return !hiddenIdentifiers.contains(identifier)
    }

    fun setVisible(context: Context, languageTag: String, tool: FfiTool, visible: Boolean) {
        val c = core(context, languageTag)
        c.setVisible(tool, visible)
        persist(context, c)
    }

    /**
     * 工具列擺哪裡（S-261b）。
     *
     * 可移動是刻意的：工具列頂部固定時，**左撇子與橫向書寫會擋手**。
     */
    var placement by mutableStateOf(uniffi.padnote_core.FfiPlacement.BOTTOM)
        private set

    /**
     * 顯示文字標籤還是只有圖示。
     *
     * 泰文與日文的字串常比英文長 30–50%，那些語言核心預設只給圖示。
     */
    var showLabels by mutableStateOf(false)
        private set

    fun setPlacement(
        context: Context,
        languageTag: String,
        next: uniffi.padnote_core.FfiPlacement
    ) {
        val c = core(context, languageTag)
        c.setPlacement(next)
        persist(context, c)
    }

    fun setShowLabels(context: Context, languageTag: String, next: Boolean) {
        val c = core(context, languageTag)
        c.setShowLabels(next)
        persist(context, c)
    }

    /** 回到出廠設定。**使用者改壞了要回得去。** */
    fun reset(context: Context, languageTag: String) {
        val c = core(context, languageTag)
        c.reset()
        persist(context, c)
    }

    /**
     * 藏起某支工具之後，目前選中的該換成哪一支（兩者都用識別字表示）。
     *
     * 規則在核心，Apple 走同一條 —— 兩端對這件事給出不同答案的話，
     * 同一個帳號在兩台裝置上會停在不同的筆上。
     *
     * 認不得的識別字原樣回傳：編輯器有一天多一支核心還不知道的筆時，
     * 該讓它繼續用，而不是把使用者踢回鋼筆。
     */
    fun identifierAfterHiding(context: Context, languageTag: String, identifier: String): String {
        val c = core(context, languageTag)
        val all = c.allGroups().flatMap { it.tools }
        val current = all.firstOrNull { it.identifier == identifier } ?: return identifier
        val next = c.toolAfterHiding(current.tool)
        return all.firstOrNull { it.tool == next }?.identifier ?: identifier
    }

    private fun persist(context: Context, c: FfiToolbar) {
        refresh(c)
        AccountSyncStore.setSyncedToolbarJson(context, c.toJson())
    }

    private fun refresh(c: FfiToolbar) {
        placement = c.placement()
        showLabels = c.showLabels()
        hiddenIdentifiers = c.allGroups()
            .flatMap { it.tools }
            .filter { !it.visible }
            .map { it.identifier }
            .toSet()
    }

    /**
     * 設定畫面上的字必須與編輯器工具列上的字**逐字相同** ——
     * 使用者要靠那行字認出自己在關哪一顆按鈕。所以這裡用的是介面字串表的鍵，
     * 不是核心自己那張表（`FfiToolInfo.label`）。
     */
    fun uiLabelKey(identifier: String): String = when (identifier) {
        "editor.ink.pen" -> "tool_pen"
        "editor.ink.ballpoint" -> "tool_ballpoint"
        "editor.ink.brush" -> "tool_brush"
        "editor.ink.marker" -> "tool_marker"
        "editor.ink.highlighter" -> "tool_highlighter"
        "editor.ink.pencil" -> "tool_pencil"
        "editor.ink.watercolor" -> "tool_watercolor"
        "editor.ink.eraser" -> "tool_eraser"
        "editor.ink.lasso" -> "tool_lasso"
        "editor.ink.maskingTape" -> "tool_masking_tape"
        "editor.ink.undo" -> "undo"
        "editor.ink.redo" -> "redo"
        "editor.ink.clear" -> "clear_page"
        else -> identifier
    }

    /**
     * 編輯器的 `editor.ink.pen` → 設定畫面的 `toolbar.tool.pen`。
     *
     * 寫成 `when` 而不是字串拼接：跨平台對照閘門掃的是原始碼裡的**字串
     * 字面值**，拼出來的識別字它看不見 —— 那樣某支工具在設定畫面上漏掉一個
     * 開關，閘門也不會紅。這件事在 `InkTool.parityIdentifier` 已經踩過一次。
     */
    /** 位置選項與它們的語系鍵。順序與 Apple 端的 Picker 相同。 */
    val PLACEMENTS: List<Pair<uniffi.padnote_core.FfiPlacement, String>> = listOf(
        uniffi.padnote_core.FfiPlacement.TOP to "toolbar_place_top",
        uniffi.padnote_core.FfiPlacement.BOTTOM to "toolbar_place_bottom",
        uniffi.padnote_core.FfiPlacement.LEFT to "toolbar_place_left",
        uniffi.padnote_core.FfiPlacement.RIGHT to "toolbar_place_right",
        uniffi.padnote_core.FfiPlacement.COLLAPSED to "toolbar_place_collapsed",
    )

    fun settingsTag(editorIdentifier: String): String = when (editorIdentifier) {
        "editor.ink.pen" -> "toolbar.tool.pen"
        "editor.ink.ballpoint" -> "toolbar.tool.ballpoint"
        "editor.ink.brush" -> "toolbar.tool.brush"
        "editor.ink.marker" -> "toolbar.tool.marker"
        "editor.ink.highlighter" -> "toolbar.tool.highlighter"
        "editor.ink.pencil" -> "toolbar.tool.pencil"
        "editor.ink.watercolor" -> "toolbar.tool.watercolor"
        "editor.ink.eraser" -> "toolbar.tool.eraser"
        "editor.ink.lasso" -> "toolbar.tool.lasso"
        "editor.ink.maskingTape" -> "toolbar.tool.maskingTape"
        "editor.ink.undo" -> "toolbar.tool.undo"
        "editor.ink.redo" -> "toolbar.tool.redo"
        "editor.ink.clear" -> "toolbar.tool.clear"
        else -> editorIdentifier
    }
}

/** 「自訂工具列」設定畫面。 */
@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
fun ToolbarCustomizationSheet(
    context: Context,
    languageTag: String,
    onDismiss: () -> Unit
) {
    fun l10n(key: String) = LocalizationStrings.localized(key, languageTag)

    val groups = ToolbarSettings.groups(context, languageTag)
    val hidden = ToolbarSettings.hiddenIdentifiers
    val total = groups.sumOf { it.tools.size }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l10n("customize_toolbar")) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = if (hidden.size == total) l10n("toolbar_all_hidden")
                    else l10n("toolbar_customize_hint"),
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.testTag("toolbar.hint")
                )
                // 捲動容器要有 tag：畫面稽核得靠它 `performScrollToNode`。
                // 沒有的話後面五支筆（套索、紙膠帶、復原、重做、清除）
                // 永遠在摺線下面，稽核會判成「不見了」—— 實際發生過。
                LazyColumn(
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                    modifier = Modifier.testTag("toolbar.scroll")
                ) {
                    // 位置與文字標籤（S-261b）。
                    //
                    // 這兩個設定原本只存在核心裡、也同步得動，但**兩端都
                    // 沒有 UI** —— 理由是「只做得動一邊的設定比沒有更糟」。
                    // 現在兩端都能真的移動工具列，開關才有意義。
                    item(key = "placement") {
                        HorizontalDivider()
                        Text(
                            l10n("toolbar_placement"),
                            style = MaterialTheme.typography.labelMedium,
                            modifier = Modifier.padding(top = 6.dp)
                        )
                        androidx.compose.foundation.layout.FlowRow(
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                            modifier = Modifier.testTag("toolbar.placement")
                        ) {
                            ToolbarSettings.PLACEMENTS.forEach { (value, key) ->
                                androidx.compose.material3.FilterChip(
                                    selected = ToolbarSettings.placement == value,
                                    onClick = {
                                        ToolbarSettings.setPlacement(context, languageTag, value)
                                    },
                                    label = { Text(l10n(key)) }
                                )
                            }
                        }
                        Text(
                            if (ToolbarSettings.placement ==
                                uniffi.padnote_core.FfiPlacement.COLLAPSED) {
                                l10n("toolbar_collapsed_hint")
                            } else {
                                l10n("toolbar_placement_hint")
                            },
                            style = MaterialTheme.typography.bodySmall
                        )
                        androidx.compose.foundation.layout.Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("toolbar.show_labels"),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(l10n("toolbar_show_labels"))
                            Switch(
                                checked = ToolbarSettings.showLabels,
                                onCheckedChange = {
                                    ToolbarSettings.setShowLabels(context, languageTag, it)
                                }
                            )
                        }
                        Text(
                            l10n("toolbar_labels_hint"),
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                    groups.forEach { group ->
                        item(key = group.label) {
                            HorizontalDivider()
                            Text(
                                text = group.label,
                                style = MaterialTheme.typography.labelMedium,
                                modifier = Modifier.padding(top = 6.dp)
                            )
                        }
                        items(group.tools, key = { it.identifier }) { info ->
                            androidx.compose.foundation.layout.Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    // 標籤掛在整列上而不是裡面的 Switch ——
                                    // 掛在子元素上時，TalkBack 與 UI 測試按到的
                                    // 是那行字，而開關在別的地方（S-263 踩過這個坑）。
                                    .testTag(ToolbarSettings.settingsTag(info.identifier)),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text(l10n(ToolbarSettings.uiLabelKey(info.identifier)))
                                Switch(
                                    checked = !hidden.contains(info.identifier),
                                    onCheckedChange = {
                                        ToolbarSettings.setVisible(
                                            context, languageTag, info.tool, it
                                        )
                                    }
                                )
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text(l10n("done")) }
        },
        dismissButton = {
            TextButton(
                onClick = { ToolbarSettings.reset(context, languageTag) },
                modifier = Modifier.testTag("toolbar.reset")
            ) { Text(l10n("toolbar_reset")) }
        }
    )
}
