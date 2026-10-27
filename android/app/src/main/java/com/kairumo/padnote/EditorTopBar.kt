package com.kairumo.padnote

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.canvas.EditorMode
import com.kairumo.padnote.canvas.PageDisplayMode
import com.kairumo.padnote.ink.InkTool
import com.kairumo.padnote.ink.InkToolbar
import com.kairumo.padnote.platform.Exporter
import com.kairumo.padnote.text.*
import com.kairumo.padnote.ui.ContextualPortalState
import com.kairumo.padnote.ui.DynamicPortalIsland
import com.kairumo.padnote.ui.InstantTooltip
import uniffi.padnote_core.FfiPlacement

internal class InkBarState(
    val tool: InkTool,
    val colorHex: String,
    val width: Float,
    val languageTag: String,
    val onToolChange: (InkTool) -> Unit,
    val onColorChange: (String) -> Unit,
    val onWidthChange: (Float) -> Unit,
    val onOpenColorWheel: () -> Unit,
    val onAddTextBox: () -> Unit
)

@Composable
internal fun RenderInkBar(state: InkBarState, modifier: Modifier = Modifier) {
    InkToolbar(
        tool = state.tool,
        colorHex = state.colorHex,
        width = state.width,
        languageTag = state.languageTag,
        onToolChange = state.onToolChange,
        onColorChange = state.onColorChange,
        onWidthChange = state.onWidthChange,
        onOpenColorWheel = state.onOpenColorWheel,
        onAddTextBox = state.onAddTextBox,
        modifier = modifier
    )
}

@Composable
internal fun FormatControlsBar(
    isCompact: Boolean,
    formatTarget: TextBox?,
    languageTag: String,
    l10n: (String) -> String,
    onFormatAction: (WordFormatAction) -> Unit
) {
    if (isCompact) {
        Row(
            modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
            verticalAlignment = Alignment.CenterVertically
        ) {
            WordFormatControls(
                state = (formatTarget ?: TextBox(id = "")).let { WordFormatState.of(it, RichText.base(it)) },
                l = { key -> l10n(key) },
                languageTag = languageTag,
                onAction = onFormatAction
            )
        }
    } else {
        WordFormatControls(
            state = (formatTarget ?: TextBox(id = "")).let { WordFormatState.of(it, RichText.base(it)) },
            l = { key -> l10n(key) },
            languageTag = languageTag,
            onAction = onFormatAction
        )
    }
}

/**
 * 編輯器頂部工具列狀態
 */
data class EditorTopBarState(
    val title: String,
    val showPageSidebar: Boolean,
    val minimalistCanvasMode: Boolean,
    val editorMode: EditorMode,
    val effectiveToolbarMode: EditorMode,
    val showRadialMenu: Boolean,
    val isTabletopActive: Boolean,
    val hiddenTools: Set<String> = emptySet(),
    val canUndo: Boolean = false,
    val canRedo: Boolean = false,
    val hasOpenMark: Boolean = false,
    val isPlacingCommentPin: Boolean = false,
    val pageIndex: Int = 0,
    val pageCount: Int = 1,
    val pageDisplayMode: PageDisplayMode = PageDisplayMode.SINGLE,
    val currentFormat: String = "A4",
    val currentPalette: String = "classic",
    val isCollabConnected: Boolean = false,
    val recording: Boolean = false,
    val recordingPaused: Boolean = false,
    val recordSeconds: Int = 0,
    val backlogUs: Long = 0L,
    val lowLatency: Boolean = false,
    val lowLatencyUnavailable: Boolean = false,
    val penOnly: Boolean = false,
    val toolbarPlacement: FfiPlacement = FfiPlacement.TOP,
    val marqueeActive: Boolean = false,
    val marqueeAdditive: Boolean = false,
    val canSelectAll: Boolean = false,
    val canDeselectAll: Boolean = false,
    val hasMarqueeSelection: Boolean = false,
    val marqueeSelectionCount: Int = 0,
    val hasClipboardContent: Boolean = false,
    val snapToGrid: Boolean = false,
    val strokeCount: Int = 0,
    val eventDebug: String = "",
    val showInkDebug: Boolean = false,
    val micBlocked: Boolean = false,
    val statusMessage: String? = null,
    val languageTag: String = "zh-TW",
    val isGoogleSignedIn: Boolean = false,
    val hasFolderSyncUri: Boolean = false
)

/**
 * 編輯器頂部工具列動作回呼集合
 */
data class EditorTopBarActions(
    val onBack: (() -> Unit)? = null,
    val onToggleSidebar: () -> Unit = {},
    val onEnterMinimalist: () -> Unit = {},
    val onExitMinimalist: () -> Unit = {},
    val onRenameTitle: () -> Unit = {},
    val onModeChange: (EditorMode) -> Unit = {},
    val onToggleRadialMenu: () -> Unit = {},
    val onToggleTabletop: () -> Unit = {},
    val onUndo: () -> Unit = {},
    val onRedo: () -> Unit = {},
    val onRevertInitial: () -> Unit = {},
    val onOpenAssetLibrary: () -> Unit = {},
    val onToggleCommentPin: () -> Unit = {},
    val onPrevPage: () -> Unit = {},
    val onNextPage: () -> Unit = {},
    val onAddPage: () -> Unit = {},
    val onTogglePageDisplayMode: () -> Unit = {},
    val onSelectPageFormat: (String) -> Unit = {},
    val onApplyCustomFormat: (Float, Float) -> Unit = { _, _ -> },
    val onSelectPalette: (String) -> Unit = {},
    val onOpenCollaboration: () -> Unit = {},
    val onToggleRecord: () -> Unit = {},
    val onTogglePauseRecord: () -> Unit = {},
    val onFinishRecord: () -> Unit = {},
    val onExport: (Exporter.Format) -> Unit = {},
    val onPrint: () -> Unit = {},
    val onSaveAs: () -> Unit = {},
    val onSharePackage: () -> Unit = {},
    val onCloudSync: () -> Unit = {},
    val onFolderSync: () -> Unit = {},
    val onFolderSyncNow: () -> Unit = {},
    val onOpenProColors: () -> Unit = {},
    val onOpenLanguagePicker: () -> Unit = {},
    val onOpenDoc: (String) -> Unit = {},
    val onBackupCreate: () -> Unit = {},
    val onBackupRestore: () -> Unit = {},
    val onClearInk: () -> Unit = {},
    val onInsertMath: () -> Unit = {},
    val onOpenLayers: () -> Unit = {},
    val onRefineSketch: () -> Unit = {},
    val onAiSummary: () -> Unit = {},
    val onThemeTools: () -> Unit = {},
    val onCustomizeToolbar: () -> Unit = {},
    val onInsertModel3D: () -> Unit = {},
    val onInsertStickers: () -> Unit = {},
    val onInsertImage: () -> Unit = {},
    val onInsertDocument: () -> Unit = {},
    val onInsertPdf: () -> Unit = {},
    val onImportImageFile: () -> Unit = {},
    val onPasteScreenshot: () -> Unit = {},
    val onInsertAudio: () -> Unit = {},
    val onInsertAudioFile: () -> Unit = {},
    val onInsertChart: () -> Unit = {},
    val onInsertTable: () -> Unit = {},
    val onInsertShape: () -> Unit = {},
    val onManageGroups: () -> Unit = {},
    val onRecognizeHandwriting: () -> Unit = {},
    val onZoomFit: (String) -> Unit = {},
    val onDeletePage: () -> Unit = {},
    val onShowDiagnostics: () -> Unit = {},
    val onToggleInkDebug: () -> Unit = {},
    val onOpenAppSettings: () -> Unit = {},
    val onToggleLowLatency: () -> Unit = {},
    val onTogglePenOnly: () -> Unit = {},
    val onToggleMarquee: () -> Unit = {},
    val onToggleMarqueeAdditive: () -> Unit = {},
    val onSelectAllMarquee: () -> Unit = {},
    val onDeselectAllMarquee: () -> Unit = {},
    val onCutMarquee: () -> Unit = {},
    val onCopyMarquee: () -> Unit = {},
    val onPasteMarquee: () -> Unit = {},
    val onPasteAtLocation: () -> Unit = {},
    val onDuplicateMarquee: () -> Unit = {},
    val onDeleteMarquee: () -> Unit = {},
    val onAddTextBox: () -> Unit = {},
    val onOpenTextStudio: () -> Unit = {},
    val onFormatAction: (WordFormatAction) -> Unit = {},
    val onToggleSnapToGrid: () -> Unit = {},
    val onBringForward: () -> Unit = {},
    val onSendBackward: () -> Unit = {},
    val onInsertSymbol: () -> Unit = {},
    val onInsertLink: () -> Unit = {}
)

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun EditorTopBar(
    state: EditorTopBarState,
    actions: EditorTopBarActions,
    inkBarState: InkBarState,
    formatTarget: TextBox?,
    contextualState: ContextualPortalState?,
    l10n: (String) -> String
) {
    var formatMenu by remember { mutableStateOf(false) }
    var customFormatDialog by remember { mutableStateOf(false) }
    var wText by remember { mutableStateOf("") }
    var hText by remember { mutableStateOf("") }
    var paletteMenu by remember { mutableStateOf(false) }
    var showShareMenu by remember { mutableStateOf(false) }
    var showMenu by remember { mutableStateOf(false) }

    fun toolShown(id: String) =
        state.editorMode != EditorMode.DRAW || id !in state.hiddenTools

    FlowRow(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        // 回首頁。對齊 iPad：帶藍色底色、首頁小圖示與文字
        if (actions.onBack != null) {
            Surface(
                shape = RoundedCornerShape(8.dp),
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(vertical = 2.dp)
            ) {
                TextButton(
                    onClick = { actions.onBack.invoke() },
                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp),
                    modifier = Modifier.testTag("editor.home")
                ) {
                    Text(
                        "‹  🏠 " + l10n("home"),
                        color = MaterialTheme.colorScheme.onPrimary,
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }

        // 側欄展開／收合開關
        Surface(
            shape = RoundedCornerShape(8.dp),
            color = if (state.showPageSidebar) MaterialTheme.colorScheme.primary.copy(alpha = 0.15f)
            else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
            modifier = Modifier.padding(vertical = 2.dp)
        ) {
            TextButton(
                onClick = actions.onToggleSidebar,
                modifier = Modifier.testTag("editor.sidebar_toggle"),
                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
            ) {
                Text(
                    "📖 " + l10n("pages"),
                    fontWeight = if (state.showPageSidebar) FontWeight.SemiBold else FontWeight.Normal,
                    color = if (state.showPageSidebar) MaterialTheme.colorScheme.primary
                    else MaterialTheme.colorScheme.onSurface
                )
            }
        }

        // 極簡全螢幕畫布開關
        Surface(
            shape = RoundedCornerShape(8.dp),
            color = if (state.minimalistCanvasMode) MaterialTheme.colorScheme.primary.copy(alpha = 0.15f)
            else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
            modifier = Modifier.padding(vertical = 2.dp)
        ) {
            TextButton(
                onClick = {
                    if (state.minimalistCanvasMode) actions.onExitMinimalist()
                    else actions.onEnterMinimalist()
                },
                modifier = Modifier.testTag("editor.minimalist_toggle"),
                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
            ) {
                Text(
                    if (state.minimalistCanvasMode) "⤢ " + l10n("exit_canvas_minimal_mode")
                    else "⤡ " + l10n("enter_canvas_minimal_mode"),
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = if (state.minimalistCanvasMode) FontWeight.SemiBold else FontWeight.Normal,
                    color = if (state.minimalistCanvasMode) MaterialTheme.colorScheme.primary
                    else MaterialTheme.colorScheme.onSurface
                )
            }
        }

        // 標題顯示與重新命名入口
        Surface(
            shape = RoundedCornerShape(8.dp),
            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f),
            modifier = Modifier.padding(vertical = 2.dp)
        ) {
            TextButton(
                onClick = actions.onRenameTitle,
                modifier = Modifier.testTag("editor.title"),
                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp)
            ) {
                Text(
                    state.title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface
                )
            }
        }

        // 流體動態傳送門 (Dynamic Portal Island)。
        // 決定畫布模式並支援即時情境展開（如手繪模式中編輯文字方塊）。
        DynamicPortalIsland(
            currentMode = state.editorMode,
            contextualState = contextualState,
            languageTag = state.languageTag,
            onModeChange = actions.onModeChange
        )

        // 快速輪盤開關
        Surface(
            shape = RoundedCornerShape(8.dp),
            color = if (state.showRadialMenu) MaterialTheme.colorScheme.primary.copy(alpha = 0.15f)
            else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
            modifier = Modifier.padding(vertical = 2.dp)
        ) {
            IconButton(
                onClick = actions.onToggleRadialMenu,
                modifier = Modifier.size(36.dp).testTag("editor.radial_toggle")
            ) {
                Text(
                    "◎",
                    style = MaterialTheme.typography.titleMedium,
                    color = if (state.showRadialMenu) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
                )
            }
        }

        // 摺疊立起創作工作盤 (Tabletop Studio Deck) 手動切換鈕
        Surface(
            shape = RoundedCornerShape(8.dp),
            color = if (state.isTabletopActive) MaterialTheme.colorScheme.primary.copy(alpha = 0.15f)
            else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
            modifier = Modifier.padding(vertical = 2.dp)
        ) {
            InstantTooltip(
                text = l10n("posture_tabletop_mode"),
                modifier = Modifier.testTag("editor.tabletop_mode_btn")
            ) {
                IconButton(
                    onClick = actions.onToggleTabletop,
                    modifier = Modifier.size(36.dp)
                ) {
                    Text(
                        if (state.isTabletopActive) "💻" else "📱",
                        style = MaterialTheme.typography.titleMedium,
                        color = if (state.isTabletopActive) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
                    )
                }
            }
        }

        // 復原／重做／重設群組膠囊
        if (toolShown("editor.ink.undo") || toolShown("editor.ink.redo")) {
            Surface(
                shape = RoundedCornerShape(8.dp),
                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                modifier = Modifier.padding(vertical = 2.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (toolShown("editor.ink.undo")) {
                        InstantTooltip(
                            text = l10n("undo"),
                            modifier = Modifier.testTag(if (state.editorMode == EditorMode.DRAW) "editor.ink.undo" else "editor.text.undo")
                        ) {
                            IconButton(
                                onClick = actions.onUndo,
                                enabled = state.canUndo,
                                modifier = Modifier.size(36.dp)
                            ) {
                                Text(
                                    "↶",
                                    style = MaterialTheme.typography.titleMedium,
                                    color = if (state.canUndo) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f)
                                )
                            }
                        }
                    }
                    if (toolShown("editor.ink.redo")) {
                        InstantTooltip(
                            text = l10n("redo"),
                            modifier = Modifier.testTag(if (state.editorMode == EditorMode.DRAW) "editor.ink.redo" else "editor.text.redo")
                        ) {
                            IconButton(
                                onClick = actions.onRedo,
                                enabled = state.canRedo,
                                modifier = Modifier.size(36.dp)
                            ) {
                                Text(
                                    "↷",
                                    style = MaterialTheme.typography.titleMedium,
                                    color = if (state.canRedo) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f)
                                )
                            }
                        }
                    }
                    if (state.hasOpenMark) {
                        InstantTooltip(
                            text = l10n("revert_to_initial_state"),
                            modifier = Modifier.testTag("editor.revert_initial_state")
                        ) {
                            IconButton(
                                onClick = actions.onRevertInitial,
                                modifier = Modifier.size(36.dp)
                            ) {
                                Text(
                                    "⏮",
                                    style = MaterialTheme.typography.titleSmall,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                            }
                        }
                    }
                }
            }
        }

        // 素材庫膠囊
        Surface(
            shape = RoundedCornerShape(8.dp),
            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
            modifier = Modifier.padding(vertical = 2.dp)
        ) {
            IconButton(
                onClick = actions.onOpenAssetLibrary,
                modifier = Modifier.size(36.dp).testTag("editor.insert.assets")
            ) {
                Text("🎬", style = MaterialTheme.typography.titleMedium)
            }
        }

        // 留言圖釘工具膠囊
        Surface(
            shape = RoundedCornerShape(8.dp),
            color = if (state.isPlacingCommentPin) MaterialTheme.colorScheme.primary.copy(alpha = 0.15f)
            else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
            modifier = Modifier.padding(vertical = 2.dp)
        ) {
            InstantTooltip(
                text = l10n("add_comment_pin"),
                modifier = Modifier.testTag("editor.comment_pin_toggle")
            ) {
                IconButton(
                    onClick = actions.onToggleCommentPin,
                    modifier = Modifier.size(36.dp)
                ) {
                    Text(
                        "📌",
                        style = MaterialTheme.typography.titleMedium,
                        color = if (state.isPlacingCommentPin) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
                    )
                }
            }
        }

        // 翻頁／加頁／檢視模式膠囊
        Surface(
            shape = RoundedCornerShape(8.dp),
            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
            modifier = Modifier.padding(vertical = 2.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                InstantTooltip(
                    text = l10n("previous_page"),
                    modifier = Modifier.testTag("editor.page.prev")
                ) {
                    IconButton(
                        onClick = actions.onPrevPage,
                        enabled = state.pageIndex > 0,
                        modifier = Modifier.size(36.dp)
                    ) {
                        Text("‹", style = MaterialTheme.typography.titleMedium)
                    }
                }
                Text(
                    "${state.pageIndex + 1} / ${state.pageCount}",
                    style = MaterialTheme.typography.labelMedium,
                    modifier = Modifier.testTag("editor.page.indicator")
                )
                InstantTooltip(
                    text = l10n("next_page"),
                    modifier = Modifier.testTag("editor.page.next")
                ) {
                    IconButton(
                        onClick = actions.onNextPage,
                        enabled = state.pageIndex < state.pageCount - 1,
                        modifier = Modifier.size(36.dp)
                    ) {
                        Text("›", style = MaterialTheme.typography.titleMedium)
                    }
                }
                InstantTooltip(
                    text = l10n("add_page"),
                    modifier = Modifier.testTag("editor.page.add")
                ) {
                    IconButton(
                        onClick = actions.onAddPage,
                        modifier = Modifier.size(36.dp)
                    ) {
                        Text("+", style = MaterialTheme.typography.titleMedium)
                    }
                }
                InstantTooltip(
                    text = l10n(if (state.pageDisplayMode == PageDisplayMode.SINGLE) "page_mode_single" else "page_mode_continuous"),
                    modifier = Modifier.testTag("editor.page.display_mode")
                ) {
                    IconButton(
                        onClick = actions.onTogglePageDisplayMode,
                        modifier = Modifier.size(36.dp)
                    ) {
                        Text(
                            if (state.pageDisplayMode == PageDisplayMode.SINGLE) "📄" else "📜",
                            style = MaterialTheme.typography.titleMedium
                        )
                    }
                }
            }
        }

        // 紙張規格與版面調色群組膠囊
        Surface(
            shape = RoundedCornerShape(8.dp),
            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
            modifier = Modifier.padding(vertical = 2.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box {
                    TextButton(
                        onClick = { formatMenu = true },
                        modifier = Modifier.testTag("editor.page_format"),
                        contentPadding = PaddingValues(horizontal = 6.dp, vertical = 4.dp)
                    ) {
                        val fmt = uniffi.padnote_core.pageFormat(state.currentFormat)
                        Text(
                            if (uniffi.padnote_core.isCustomPageFormat(state.currentFormat)) {
                                "${fmt.width.toInt()}×${fmt.height.toInt()}"
                            } else l10n(fmt.titleKey),
                            style = MaterialTheme.typography.labelMedium
                        )
                    }
                    DropdownMenu(expanded = formatMenu, onDismissRequest = { formatMenu = false }) {
                        uniffi.padnote_core.pageFormats().forEach { format ->
                            DropdownMenuItem(
                                text = { Text(l10n(format.titleKey)) },
                                trailingIcon = { if (format.id == state.currentFormat) Text("✓") },
                                onClick = {
                                    formatMenu = false
                                    actions.onSelectPageFormat(format.id)
                                }
                            )
                        }
                        HorizontalDivider()
                        DropdownMenuItem(
                            text = { Text(l10n("page_format_custom")) },
                            trailingIcon = {
                                if (uniffi.padnote_core.isCustomPageFormat(state.currentFormat)) Text("✓")
                            },
                            onClick = {
                                formatMenu = false
                                val current = uniffi.padnote_core.pageFormat(state.currentFormat)
                                wText = current.width.toInt().toString()
                                hText = current.height.toInt().toString()
                                customFormatDialog = true
                            },
                            modifier = Modifier.testTag("page_format.custom")
                        )
                    }
                    if (customFormatDialog) {
                        AlertDialog(
                            onDismissRequest = { customFormatDialog = false },
                            title = { Text(l10n("page_format_custom_title")) },
                            text = {
                                Column {
                                    Text(l10n("page_format_custom_hint"), style = MaterialTheme.typography.labelSmall)
                                    OutlinedTextField(
                                        value = wText, onValueChange = { wText = it.filter(Char::isDigit) },
                                        label = { Text(l10n("page_format_custom_width")) }, singleLine = true,
                                        keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(
                                            keyboardType = androidx.compose.ui.text.input.KeyboardType.Number),
                                        modifier = Modifier.testTag("page_format.custom.width")
                                    )
                                    OutlinedTextField(
                                        value = hText, onValueChange = { hText = it.filter(Char::isDigit) },
                                        label = { Text(l10n("page_format_custom_height")) }, singleLine = true,
                                        keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(
                                            keyboardType = androidx.compose.ui.text.input.KeyboardType.Number),
                                        modifier = Modifier.testTag("page_format.custom.height")
                                    )
                                }
                            },
                            confirmButton = {
                                TextButton(
                                    onClick = {
                                        customFormatDialog = false
                                        val w = wText.toFloatOrNull() ?: 0f
                                        val h = hText.toFloatOrNull() ?: 0f
                                        if (w >= 100f && h >= 100f) {
                                            actions.onApplyCustomFormat(w, h)
                                        }
                                    },
                                    modifier = Modifier.testTag("page_format.custom.apply")
                                ) { Text(l10n("page_format_custom_apply")) }
                            },
                            dismissButton = {
                                TextButton(onClick = { customFormatDialog = false }) { Text(l10n("cancel")) }
                            }
                        )
                    }
                }
                VerticalDivider(modifier = Modifier.height(16.dp))

                Box {
                    TextButton(
                        onClick = { paletteMenu = true },
                        modifier = Modifier.testTag("editor.guide_palette"),
                        contentPadding = PaddingValues(horizontal = 6.dp, vertical = 4.dp)
                    ) {
                        Text(
                            l10n(
                                uniffi.padnote_core.guidePalettes()
                                    .firstOrNull { it.id == state.currentPalette }?.nameKey
                                    ?: "guide_palette"
                            ),
                            style = MaterialTheme.typography.labelSmall
                        )
                    }
                    DropdownMenu(expanded = paletteMenu, onDismissRequest = { paletteMenu = false }) {
                        uniffi.padnote_core.guidePalettes().forEach { palette ->
                            DropdownMenuItem(
                                text = { Text(l10n(palette.nameKey)) },
                                trailingIcon = { if (palette.id == state.currentPalette) Text("✓") },
                                onClick = {
                                    paletteMenu = false
                                    actions.onSelectPalette(palette.id)
                                }
                            )
                        }
                    }
                }
            }
        }

        // 線上多人即時協同按鈕
        Surface(
            shape = RoundedCornerShape(8.dp),
            color = if (state.isCollabConnected) Color(0xFFE8F5E9) else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
            modifier = Modifier.padding(vertical = 2.dp)
        ) {
            IconButton(
                onClick = actions.onOpenCollaboration,
                modifier = Modifier.size(36.dp).testTag("editor.collaborate")
            ) {
                Text(
                    "👥",
                    style = MaterialTheme.typography.titleMedium,
                    color = if (state.isCollabConnected) Color(0xFF2E7D32) else MaterialTheme.colorScheme.onSurface
                )
            }
        }

        // 錄音
        Surface(
            shape = RoundedCornerShape(8.dp),
            color = if (state.recording) Color(0xFFFFEBEE) else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
            modifier = Modifier.padding(vertical = 2.dp)
        ) {
            IconButton(
                onClick = actions.onToggleRecord,
                modifier = Modifier.size(36.dp).testTag("editor.record")
            ) {
                Text(
                    if (state.recording) "⏹" else "🎙️",
                    color = if (state.recording) Color.Red else MaterialTheme.colorScheme.onSurface,
                    style = MaterialTheme.typography.titleMedium
                )
            }
        }

        // 匯出／分享選單
        Surface(
            shape = RoundedCornerShape(8.dp),
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.padding(vertical = 2.dp)
        ) {
            Button(
                onClick = { showShareMenu = true },
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    contentColor = MaterialTheme.colorScheme.onPrimary
                ),
                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp),
                shape = RoundedCornerShape(8.dp),
                modifier = Modifier.testTag("editor.share")
            ) {
                Text(
                    "⇪  " + l10n("export_print"),
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Bold
                )
            }
        }

        // 更多選項選單
        Box {
            IconButton(
                onClick = { showMenu = true },
                modifier = Modifier.testTag("editor.more")
            ) {
                Text("⋮", style = MaterialTheme.typography.titleLarge)
            }

            DropdownMenu(expanded = showShareMenu, onDismissRequest = { showShareMenu = false }) {
                DropdownMenuItem(
                    text = { Text(l10n("export_pdf")) },
                    modifier = Modifier.testTag("editor.export.pdf"),
                    onClick = {
                        showShareMenu = false
                        actions.onExport(Exporter.Format.PDF)
                    }
                )
                DropdownMenuItem(
                    text = { Text(l10n("export_image")) },
                    modifier = Modifier.testTag("editor.export.image"),
                    onClick = {
                        showShareMenu = false
                        actions.onExport(Exporter.Format.PNG)
                    }
                )
                DropdownMenuItem(
                    text = { Text(l10n("print_note")) },
                    modifier = Modifier.testTag("editor.export.print"),
                    onClick = {
                        showShareMenu = false
                        actions.onPrint()
                    }
                )
                DropdownMenuItem(
                    text = { Text(l10n("export_save_as")) },
                    modifier = Modifier.testTag("editor.export.save_as"),
                    onClick = {
                        showShareMenu = false
                        actions.onSaveAs()
                    }
                )
                HorizontalDivider()
                DropdownMenuItem(
                    text = { Text(l10n("share_note")) },
                    modifier = Modifier.testTag("editor.export.share"),
                    onClick = {
                        showShareMenu = false
                        actions.onSharePackage()
                    }
                )
                HorizontalDivider()
                DropdownMenuItem(
                    text = { Text(l10n("cloud_sync")) },
                    onClick = {
                        showShareMenu = false
                        actions.onCloudSync()
                    }
                )
                DropdownMenuItem(
                    text = { Text(l10n("sync_choose_folder")) },
                    onClick = {
                        showShareMenu = false
                        actions.onFolderSync()
                    }
                )
                if (state.hasFolderSyncUri) {
                    DropdownMenuItem(
                        text = { Text(l10n("sync_now")) },
                        onClick = {
                            showShareMenu = false
                            actions.onFolderSyncNow()
                        }
                    )
                }
            }

            DropdownMenu(expanded = showMenu, onDismissRequest = { showMenu = false }) {
                // ── 1. 插入物件 ─────────────────────────────────────
                DropdownMenuItem(
                    text = { Text(l10n("asset_library")) },
                    modifier = Modifier.testTag("editor.insert.assets"),
                    onClick = { showMenu = false; actions.onOpenAssetLibrary() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("sticker_library")) },
                    modifier = Modifier.testTag("editor.insert.stickers"),
                    onClick = { showMenu = false; actions.onInsertStickers() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("marquee_select")) },
                    modifier = Modifier.testTag("editor.insert.marquee"),
                    onClick = { showMenu = false; actions.onToggleMarquee() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("insert_audio")) },
                    modifier = Modifier.testTag("editor.insert.audio"),
                    onClick = { showMenu = false; actions.onInsertAudio() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("import_audio_from_files")) },
                    modifier = Modifier.testTag("editor.insert.audio_file"),
                    onClick = { showMenu = false; actions.onInsertAudioFile() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("insert_image")) },
                    modifier = Modifier.testTag("editor.insert.image"),
                    onClick = { showMenu = false; actions.onInsertImage() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("import_from_files")) },
                    modifier = Modifier.testTag("editor.insert.image_file"),
                    onClick = { showMenu = false; actions.onImportImageFile() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("paste_screenshot")) },
                    modifier = Modifier.testTag("editor.insert.paste_screenshot"),
                    onClick = { showMenu = false; actions.onPasteScreenshot() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("insert_pdf")) },
                    modifier = Modifier.testTag("editor.insert.pdf"),
                    onClick = { showMenu = false; actions.onInsertPdf() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("import_document")) },
                    modifier = Modifier.testTag("editor.insert.document"),
                    onClick = { showMenu = false; actions.onInsertDocument() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("math_calc")) },
                    modifier = Modifier.testTag("editor.insert.math"),
                    onClick = { showMenu = false; actions.onInsertMath() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("chart_studio")) },
                    modifier = Modifier.testTag("editor.insert.chart"),
                    onClick = { showMenu = false; actions.onInsertChart() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("table_studio")) },
                    modifier = Modifier.testTag("editor.insert.table"),
                    onClick = { showMenu = false; actions.onInsertTable() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("shape_studio")) },
                    modifier = Modifier.testTag("editor.insert.shape"),
                    onClick = { showMenu = false; actions.onInsertShape() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("insert_3d")) },
                    modifier = Modifier.testTag("editor.insert.model3d"),
                    onClick = { showMenu = false; actions.onInsertModel3D() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("theme_tools")) },
                    modifier = Modifier.testTag("editor.insert.theme_tools"),
                    onClick = { showMenu = false; actions.onThemeTools() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("add_text_box")) },
                    onClick = { showMenu = false; actions.onAddTextBox() }
                )

                HorizontalDivider()

                // ── 2. 工具操作 ─────────────────────────────────────
                DropdownMenuItem(
                    text = { Text(l10n("refine_sketch")) },
                    modifier = Modifier.testTag("editor.insert.refine_sketch"),
                    onClick = { showMenu = false; actions.onRefineSketch() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("ai_summary")) },
                    modifier = Modifier.testTag("editor.insert.ai_summary"),
                    onClick = { showMenu = false; actions.onAiSummary() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("recognize_handwriting")) },
                    modifier = Modifier.testTag("editor.insert.recognize"),
                    onClick = { showMenu = false; actions.onRecognizeHandwriting() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("collaborate")) },
                    modifier = Modifier.testTag("editor.insert.collaborate"),
                    onClick = { showMenu = false; actions.onOpenCollaboration() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("add_comment_pin")) },
                    modifier = Modifier.testTag("editor.insert.comment_pin"),
                    onClick = { showMenu = false; actions.onToggleCommentPin() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("layers_panel")) },
                    modifier = Modifier.testTag("editor.insert.layers"),
                    onClick = { showMenu = false; actions.onManageGroups() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("pro_color")) },
                    onClick = { showMenu = false; actions.onOpenProColors() }
                )

                HorizontalDivider()

                // ── 3. 設定與檢視 ───────────────────────────────────
                DropdownMenuItem(
                    text = { Text(l10n("customize_toolbar")) },
                    modifier = Modifier.testTag("editor.customize_toolbar"),
                    onClick = { showMenu = false; actions.onCustomizeToolbar() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("posture_tabletop_mode")) },
                    modifier = Modifier.testTag("editor.tabletop_mode_menu"),
                    onClick = { showMenu = false; actions.onToggleTabletop() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("zoom_fit_page")) },
                    modifier = Modifier.testTag("editor.zoom.fit_page"),
                    onClick = { showMenu = false; actions.onZoomFit("page") }
                )
                DropdownMenuItem(
                    text = { Text(l10n("zoom_fit_width")) },
                    modifier = Modifier.testTag("editor.zoom.fit_width"),
                    onClick = { showMenu = false; actions.onZoomFit("width") }
                )
                DropdownMenuItem(
                    text = { Text(l10n("zoom_actual_size")) },
                    modifier = Modifier.testTag("editor.zoom.actual"),
                    onClick = { showMenu = false; actions.onZoomFit("actual") }
                )
                DropdownMenuItem(
                    text = { Text(l10n("backup_create")) },
                    onClick = { showMenu = false; actions.onBackupCreate() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("backup_restore")) },
                    onClick = { showMenu = false; actions.onBackupRestore() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("sync_choose_folder")) },
                    onClick = { showMenu = false; actions.onFolderSync() }
                )
                if (state.hasFolderSyncUri) {
                    DropdownMenuItem(
                        text = { Text(l10n("sync_now")) },
                        onClick = { showMenu = false; actions.onFolderSyncNow() }
                    )
                }
                DropdownMenuItem(
                    text = { Text(l10n("user_manual")) },
                    onClick = { showMenu = false; actions.onOpenDoc("manual/index.html") }
                )
                DropdownMenuItem(
                    text = { Text(l10n("privacy_policy")) },
                    onClick = { showMenu = false; actions.onOpenDoc("legal/privacy.html") }
                )
                DropdownMenuItem(
                    text = { Text(l10n("system_diagnostics")) },
                    onClick = { showMenu = false; actions.onShowDiagnostics() }
                )
                DropdownMenuItem(
                    text = { Text(l10n("ink_input_debug")) },
                    trailingIcon = { if (state.showInkDebug) Text("✓") },
                    onClick = { showMenu = false; actions.onToggleInkDebug() }
                )

                HorizontalDivider()

                // ── 4. 危險動作 ─────────────────────────────────────
                DropdownMenuItem(
                    text = {
                        Text(
                            l10n("revert_to_initial_state"),
                            color = MaterialTheme.colorScheme.error
                        )
                    },
                    enabled = state.hasOpenMark,
                    modifier = Modifier.testTag("editor.revert_initial_state"),
                    onClick = { showMenu = false; actions.onRevertInitial() }
                )
                if (toolShown("editor.ink.clear")) {
                    DropdownMenuItem(
                        text = { Text(l10n("ink_clear"), color = MaterialTheme.colorScheme.error) },
                        modifier = Modifier.testTag("editor.ink.clear"),
                        onClick = { showMenu = false; actions.onClearInk() }
                    )
                }
                DropdownMenuItem(
                    text = {
                        Text(
                            l10n("delete_page"),
                            color = if (state.pageCount > 1) MaterialTheme.colorScheme.error else Color.Unspecified
                        )
                    },
                    enabled = state.pageCount > 1,
                    onClick = { showMenu = false; actions.onDeletePage() }
                )
            }
        }
    }


    if (!state.minimalistCanvasMode) {
        // ── 第二排：目前模式的工具 ────────────────────────────────
        FlowRow(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            if (state.effectiveToolbarMode == EditorMode.DRAW) {
                if (state.showInkDebug) {
                    FilterChip(
                        selected = state.lowLatency && !state.lowLatencyUnavailable,
                        enabled = !state.lowLatencyUnavailable,
                        onClick = actions.onToggleLowLatency,
                        label = { Text(l10n("ink_low_latency")) }
                    )
                    FilterChip(
                        selected = state.penOnly,
                        onClick = actions.onTogglePenOnly,
                        label = { Text(l10n("ink_pen_only")) }
                    )
                }
            } else {
                FilterChip(
                    selected = state.marqueeActive,
                    onClick = actions.onToggleMarquee,
                    label = { Text(l10n("marquee_select")) },
                    modifier = Modifier.testTag("editor.text.select")
                )
                if (state.marqueeActive) {
                    Text(
                        if (state.marqueeSelectionCount == 0) l10n("marquee_hint")
                        else l10n("marquee_selected").replace("%@", state.marqueeSelectionCount.toString()),
                        style = MaterialTheme.typography.labelSmall
                    )
                    FilterChip(
                        selected = state.marqueeAdditive,
                        onClick = actions.onToggleMarqueeAdditive,
                        label = { Text(l10n("marquee_continuous")) },
                        modifier = Modifier.testTag("editor.marquee.continuous")
                    )
                    TextButton(
                        onClick = actions.onSelectAllMarquee,
                        enabled = state.canSelectAll,
                        modifier = Modifier.testTag("editor.marquee.select_all")
                    ) { Text(l10n("select_all")) }
                    TextButton(
                        onClick = actions.onDeselectAllMarquee,
                        enabled = state.hasMarqueeSelection,
                        modifier = Modifier.testTag("editor.marquee.deselect_all")
                    ) { Text(l10n("deselect_all")) }
                    TextButton(
                        onClick = actions.onCutMarquee,
                        enabled = state.hasMarqueeSelection
                    ) { Text(l10n("action_cut")) }
                    TextButton(
                        onClick = actions.onCopyMarquee,
                        enabled = state.hasMarqueeSelection
                    ) { Text(l10n("action_copy")) }
                    if (state.hasClipboardContent) {
                        TextButton(
                            onClick = actions.onPasteMarquee
                        ) { Text(l10n("action_paste")) }
                        TextButton(
                            onClick = actions.onPasteAtLocation
                        ) { Text(l10n("paste_at_location")) }
                    }
                    TextButton(
                        onClick = actions.onDuplicateMarquee,
                        enabled = state.hasMarqueeSelection
                    ) { Text(l10n("action_duplicate")) }
                    TextButton(
                        onClick = actions.onDeleteMarquee,
                        enabled = state.hasMarqueeSelection
                    ) { Text(l10n("action_delete"), color = MaterialTheme.colorScheme.error) }
                }
                // 1. 新增文字方塊
                TextButton(
                    onClick = actions.onAddTextBox,
                    modifier = Modifier.testTag("editor.text.add_box")
                ) { Text("+ " + l10n("add_text_box")) }

                // 2. 豐富文字格式工具列
                FormatControlsBar(
                    isCompact = true,
                    formatTarget = formatTarget,
                    languageTag = state.languageTag,
                    l10n = l10n,
                    onFormatAction = actions.onFormatAction
                )

                // 3. 打開排版設計專用全功能工作台
                InstantTooltip(
                    text = l10n("text_studio"),
                    modifier = Modifier.testTag("editor.text.studio")
                ) {
                    TextButton(
                        onClick = actions.onOpenTextStudio
                    ) {
                        Text(
                            "🎨 " + l10n("text_studio"),
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                }

                // 5. 格線/方格吸附開關
                TextButton(
                    onClick = actions.onToggleSnapToGrid,
                    modifier = Modifier.testTag("editor.text.snap_grid")
                ) { Text(if (state.snapToGrid) "✓ " + l10n("snap_to_grid") else l10n("snap_to_grid")) }

                // 6. 圖層層級調整
                TextButton(
                    onClick = actions.onBringForward,
                    modifier = Modifier.testTag("editor.text.layer_forward")
                ) { Text(l10n("layer_bring_forward")) }

                TextButton(
                    onClick = actions.onSendBackward,
                    modifier = Modifier.testTag("editor.text.layer_backward")
                ) { Text(l10n("layer_send_backward")) }

                // 7. 特殊符號
                TextButton(
                    onClick = actions.onInsertSymbol,
                    modifier = Modifier.testTag("editor.text.symbols")
                ) { Text(l10n("special_symbols")) }

                // 8. 插入連結
                TextButton(
                    onClick = actions.onInsertLink,
                    modifier = Modifier.testTag("editor.text.link")
                ) { Text(l10n("insert_link")) }
            }
        }

        if (state.showInkDebug) {
            Text(
                l10n(if (state.editorMode == EditorMode.DRAW) "mode_draw_hint" else "mode_type_hint"),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 2.dp)
            )
        }

        if (state.effectiveToolbarMode == EditorMode.DRAW &&
            state.toolbarPlacement == FfiPlacement.TOP
        ) {
            RenderInkBar(inkBarState)
        }
    }

    if (state.showInkDebug) {
        Text(
            l10n("ink_stroke_count").replace("%@", "${state.strokeCount}"),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 12.dp)
        )
    }

    if (state.micBlocked) {
        TextButton(onClick = actions.onOpenAppSettings) {
            Text(l10n("permission_open_settings"))
        }
    }

    state.statusMessage?.let {
        Text(
            it,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.padding(horizontal = 12.dp)
        )
    }

    if (state.showInkDebug) {
        Text(
            state.eventDebug,
            style = MaterialTheme.typography.labelSmall,
            fontFamily = FontFamily.Monospace,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 12.dp)
        )
    }

    if (state.lowLatencyUnavailable) {
        Text(
            l10n("ink_low_latency_unavailable"),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.error,
            modifier = Modifier.padding(horizontal = 12.dp)
        )
    }

    // 即時錄音控制條
    if (state.recording) {
        val min = state.recordSeconds / 60
        val sec = state.recordSeconds % 60
        val timeStr = String.format(java.util.Locale.US, "%02d:%02d", min, sec)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(if (state.recordingPaused) Color(0xFFFFF7ED) else Color(0xFFFEF2F2))
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(10.dp)
                        .clip(CircleShape)
                        .background(if (state.recordingPaused) Color(0xFFF97316) else Color(0xFFDC2626))
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    if (state.recordingPaused) "${l10n("recording_paused")}: $timeStr"
                    else if (state.backlogUs > 5_000_000L) "${l10n("sync_recording_in_progress")}: $timeStr (${l10n("sync_transcript_lag").replace("%@", "${state.backlogUs / 1_000_000L}")})"
                    else "${l10n("sync_recording_in_progress")}: $timeStr",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = if (state.recordingPaused) Color(0xFFC2410C) else Color(0xFFDC2626)
                )
            }

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                TextButton(
                    onClick = actions.onTogglePauseRecord
                ) {
                    Text(
                        if (state.recordingPaused) l10n("resume_recording") else l10n("pause_recording"),
                        color = Color(0xFFEA580C),
                        fontWeight = FontWeight.Bold
                    )
                }

                Button(
                    onClick = actions.onFinishRecord,
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFDC2626))
                ) {
                    Text(l10n("finish_recording"), color = Color.White)
                }
            }
        }
    }
}
