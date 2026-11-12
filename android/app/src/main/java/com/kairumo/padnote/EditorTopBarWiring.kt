package com.kairumo.padnote

import com.kairumo.padnote.canvas.EditorMode
import com.kairumo.padnote.canvas.ObjectStacking
import com.kairumo.padnote.entitlement.EntitlementManager
import com.kairumo.padnote.entitlement.ProFeatureGate
import com.kairumo.padnote.platform.AudioCapture
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * 編輯器工具列上「拆檔時掉了接線」的那些動作。
 *
 * `EditorTopBarActions` 每個欄位都有空的預設值 `{}`，而 MainActivity 拆檔（1189891e）時
 * 有三十幾個沒有傳進去：錄音、紙張規格、版面色彩、框選、縮放比例、刪除頁面、備份、
 * 使用手冊……全部點了沒反應（實機回報：「部分工具點擊後沒有反應」）。
 * 這裡逐一接回拆檔前的實作（行為與 Apple 對齊）。
 *
 * 獨立成**非 Composable** 的頂層函式，不寫進 `InkScreen`：那個 Composable 曾經大到
 * ART 驗證器的上限，多幾個 lambda 就 `VerifyError` 閃退（見 MainActivity 的註解）。
 *
 * 狀態變更一律走正門：選取用 `selectText`／`clearSelection`，換工具用 `applyInkTool`。
 */
internal fun EditorCanvasContext.withRestoredTopBarWiring(base: EditorTopBarActions): EditorTopBarActions = base.copy(
    // 立起工作盤：`isTabletopActive` 是每次重組依姿態算出來的唯讀結果，改它不會留下任何東西；
    // 手動開關存在 `isTabletopManual`（與拆檔前一致）。
    onToggleTabletop = { isTabletopManual = !isTabletopManual },

    // ── 紙張規格與版面色彩 ─────────────────────────────────
    onSelectPageFormat = { id -> applyPageFormat(id) },
    onApplyCustomFormat = { w, h ->
        applyPageFormat(uniffi.padnote_core.customPageFormatId(w.toUInt(), h.toUInt()))
    },
    onSelectPalette = { id ->
        meta.setPaletteId(notebook?.first, id)
        revision++
        // 色彩調性只染底紋。整本都是空白紙時畫面上沒有東西會變色，要講出來（與 Apple 相同）。
        val name = l10n(uniffi.padnote_core.guidePalette(id).nameKey)
        val hasTexture = (0 until maxOf(1, pageCount)).any { meta.paperId(it) != "blank" }
        message = if (hasTexture) name else l10n("guide_palette_blank_hint").replace("%@", name)
    },

    // ── 錄音 ─────────────────────────────────────────────
    onToggleRecord = { toggleRecording() },
    onTogglePauseRecord = {
        if (recordingPaused) {
            audio.resume()
            recordingPaused = false
        } else {
            audio.pause()
            recordingPaused = true
        }
    },
    onFinishRecord = { finishRecording() },

    // ── 同步、備份、文件 ─────────────────────────────────
    onCloudSync = { runEditorCloudSync() },
    onFolderSync = { folderPicker.launch(null) },
    onOpenDoc = { asset -> docsAsset = asset },
    onBackupCreate = {
        val stamp = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH-mm-ss", java.util.Locale.US)
            .format(java.util.Date())
        val unique = java.util.UUID.randomUUID().toString().take(6)
        editorBackupCreatePicker.launch("Kairumo-$stamp-$unique.kairumobackup")
    },
    onBackupRestore = { backupPicker.launch(arrayOf("*/*")) },

    // ── 筆跡與頁面 ───────────────────────────────────────
    onClearInk = { clearPageInk() },
    onDeletePage = { deletingPage = true },
    onRefineSketch = {
        EntitlementManager.requirePro(ProFeatureGate.STUDIOS, l10n("refine_sketch")) {
            showRefineBar = true
        }
    },
    onRecognizeHandwriting = { startHandwritingRecognition() },
    onZoomFit = { mode -> fitCanvas(mode) },

    // ── 圖層 ─────────────────────────────────────────────
    onOpenLayers = { showStackPanel = true },
    onManageGroups = { showLayerPanel = true },
    onBringForward = { reorderSelected(forward = true) },
    onSendBackward = { reorderSelected(forward = false) },

    // ── 插入與 Pro 工作室 ────────────────────────────────
    onInsertAudioFile = { audioImportPicker.launch(audioMimeTypes) },
    onPasteScreenshot = { pasteClipboardImageOrScreenshot() },
    onOpenTextStudio = {
        EntitlementManager.requirePro(ProFeatureGate.STUDIOS, l10n("text_studio")) {
            val box = selectedTextId?.let { textStore.find(it) } ?: textStore.create(x = 60f, y = 80f)
            textRevision++
            selectText(box.id)
            editingText = box
        }
    },
    onInsertMath = {
        EntitlementManager.requirePro(ProFeatureGate.STUDIOS, l10n("math_calc")) {
            showCalculator = true
        }
    },
    onInsertChart = {
        EntitlementManager.requirePro(ProFeatureGate.STUDIOS, l10n("chart_studio")) {
            insertingChart = true
        }
    },
    onInsertTable = {
        EntitlementManager.requirePro(ProFeatureGate.STUDIOS, l10n("table_studio")) {
            insertingTable = true
        }
    },
    onInsertModel3D = {
        EntitlementManager.requirePro(ProFeatureGate.STUDIOS, l10n("insert_3d")) {
            insertingModel3D = true
        }
    },
    onInsertLegend = {
        EntitlementManager.requirePro(ProFeatureGate.STUDIOS, l10n("insert_legend")) {
            val box = insertLegend()
            editingText = box
            selectText(box.id)
            editorMode = EditorMode.TYPE
            textRevision++
            stackRevision++
        }
    },
    onThemeTools = {
        EntitlementManager.requirePro(ProFeatureGate.PRO_INK_AND_THEMES, l10n("theme_tools")) {
            showThemeTools = true
        }
    },
    onAiSummary = {
        EntitlementManager.requirePro(ProFeatureGate.STUDIOS, l10n("ai_summary")) {
            showNoteIntelligence = true
        }
    },
    onPenSettings = {
        EntitlementManager.requirePro(ProFeatureGate.PRO_INK_AND_THEMES, l10n("advanced_pen_settings")) {
            showPenSettings = true
        }
    },
    onToggleSnapToGrid = {
        snapToGrid = !snapToGrid
        message = l10n(if (snapToGrid) "snap_to_grid_on_notice" else "snap_to_grid_off_notice")
    },

    // ── 偵錯 ─────────────────────────────────────────────
    onToggleInkDebug = { showInkDebug = !showInkDebug },
    onToggleLowLatency = { lowLatency = !lowLatency; latency.clear() },
    onTogglePenOnly = {
        penOnly = !penOnly
        engine.setPenOnly(penOnly)
    },

    // ── 框選 ─────────────────────────────────────────────
    onToggleMarquee = {
        marqueeActive = !marqueeActive
        if (!marqueeActive) {
            marqueeSelection = emptySet()
            lasso.clear()
            marqueeAdditive = false
        } else {
            // 框選只在打字模式有作用（手繪模式下物件不吃觸控）。
            editorMode = EditorMode.TYPE
            // Android 的連續頁面還沒有框選層（只有單頁畫布有）：原本在連續模式按「框選」什麼都不會發生。
            // 先切到單頁（只限這一次，不改使用者的偏好設定），框選才真的能用。
            if (pageDisplayMode == com.kairumo.padnote.canvas.PageDisplayMode.CONTINUOUS) {
                pageDisplayMode = com.kairumo.padnote.canvas.PageDisplayMode.SINGLE
            }
            lasso.clear()   // 套索留下的物件選取不能混進框選，否則同一個物件會被搬兩次
            message = l10n("marquee_hint")
        }
    },
    onToggleMarqueeAdditive = {
        marqueeAdditive = !marqueeAdditive
        if (marqueeAdditive) message = l10n("marquee_continuous_hint")
    },
    // 框選的每一個動作都同時作用在物件與筆跡上（筆跡走 `lasso`：核心當下寫事件、刪除留墓碑）。
    onSelectAllMarquee = {
        val locked = lockedIdsLatest
        marqueeSelection = marqueeCandidatesLatest.filter { it.id !in locked }.map { it.id }.toSet()
        lasso.selectAllStrokes(engine)
    },
    onDeselectAllMarquee = { marqueeSelection = emptySet(); lasso.clear() },
    onCutMarquee = {
        val firstObject = marqueeSelection.firstOrNull()
        if (firstObject != null) objectClipboardActions.cut(firstObject) else objectClipboard = emptyList()
        // 沒選筆跡時 cut 會把筆跡剪貼簿清空 —— 只剪物件就不要貼出上一次的筆跡。
        if (lasso.cut(engine)) revision++
    },
    onCopyMarquee = {
        val firstObject = marqueeSelection.firstOrNull()
        if (firstObject != null) objectClipboardActions.copy(firstObject) else objectClipboard = emptyList()
        lasso.copy(engine)
        if (firstObject == null && lasso.strokeSelectionCount > 0) message = l10n("copy_selected_hint")
    },
    onPasteMarquee = {
        // 只有筆跡時不走物件貼上（它在物件剪貼簿為空時另有退路）。
        if (objectClipboard.isNotEmpty() || !lasso.canPaste) pasteSinglePageClipboard(null)
        if (lasso.paste(engine)) revision++
    },
    onPasteAtLocation = {
        // 框選開始的放置：剪貼簿有筆跡就一起放（見 placeClipboardAt）。
        lasso.inkPlacementArmed = lasso.canPaste
        isPlacingPasteObject = objectClipboard.isNotEmpty() || lasso.inkPlacementArmed
    },
    onDuplicateMarquee = {
        if (marqueeSelection.isNotEmpty()) duplicateMarqueeSelection()
        if (lasso.duplicate(engine)) revision++
    },
    onDeleteMarquee = {
        if (marqueeSelection.isNotEmpty()) deleteMarqueeSelection()
        if (lasso.delete(engine)) revision++
    }
)

private fun EditorCanvasContext.applyPageFormat(id: String) {
    meta.setPageFormatId(notebook?.first, id)
    com.kairumo.padnote.ink.PageGeometry.use(id)
    revision++
    continuousContentRevision++
}

private fun EditorCanvasContext.toggleRecording() {
    val session = notebook?.first ?: run {
        message = l10n("err_core_not_ready")
        return
    }
    if (recording) {
        finishRecording()
    } else if (AudioCapture.hasPermission(activity)) {
        recordSeconds = 0
        recordingPaused = false
        message = audio.start(pageId ?: "", session, deviceLanguageTag()) { message = it }
        recording = audio.isRecording
    } else {
        micPermission.launch(android.Manifest.permission.RECORD_AUDIO)
    }
}

private fun EditorCanvasContext.finishRecording() {
    val session = notebook?.first ?: return
    val us = audio.stop(session)
    recording = false
    recordingPaused = false
    message = l10n("recorded_duration").replace("%@", "${us / 1_000_000uL}")
    audio.showAdviceOnce(deviceLanguageTag())
}

private fun EditorCanvasContext.runEditorCloudSync() {
    val act = activity
    if (!com.kairumo.padnote.oauth.GoogleAuth.isSignedIn(act)) {
        com.kairumo.padnote.oauth.GoogleAuth.startSignIn(act)
        return
    }
    message = l10n("syncing")
    val openId = notebookId
    scope.launch {
        // 同步會讀寫磁碟與網路：一律在 IO 執行緒；回主執行緒才推進 UI 狀態（Layer 3）。
        val result = withContext(Dispatchers.IO) {
            com.kairumo.padnote.library.CloudSync.runFull(act, deviceId(act), openId)
        }
        withContext(Dispatchers.Main.immediate) {
            val meta = result.meta
            message = when {
                result.skipped -> l10n("sync_already_running")
                meta == null -> l10n("not_signed_in")
                meta.needsReauth -> l10n("sync_needs_reauth")
                !meta.ok -> l10n("sync_failed").replace("%@", meta.error)
                else -> l10n("sync_result")
                    .replace("%1@", "${result.uploaded}")
                    .replace("%2@", "${result.downloaded}")
            }
            if (openId != null && result.changed.contains(openId)) {
                sessionRevision++
            }
        }
    }
}

private fun EditorCanvasContext.startHandwritingRecognition() {
    val session = notebook?.first
    val page = pageId
    if (session == null || page == null) {
        message = l10n("err_core_not_ready")
        return
    }
    isRecognisingHandwriting = true
    message = l10n("recognizing")
    scope.launch {
        val result = recognizeHandwriting(session, page, engine)
        withContext(Dispatchers.Main.immediate) {
            message = result
            isRecognisingHandwriting = false
        }
    }
}

/**
 * 清空本頁筆跡。**走核心的擦除（`lassoDelete` → `erase_stroke`）**，每一筆都留下 `Remove`
 * 墓碑（ADR-0015 I2／I3），同步與重開都不會復活。只清記憶體的 `engine.reset()` 不能用：
 * 下次 `load()` 筆跡就全部回來了。
 *
 * 呼叫端（工具列）已經先跳過確認對話框，與 Apple 的 `showClearConfirmAlert` 一致。
 */
private fun EditorCanvasContext.clearPageInk() {
    val handles = engine.coreHandles() ?: return
    val (session, page) = handles
    val known = engine.strokes.mapNotNull { it.coreStrokeId }
    // 再用一個蓋住整頁的套索把核心裡所有看得見的筆畫撈出來（含別台同步來、還沒進記憶體的）。
    val big = 1_000_000f
    val everything = runCatching {
        session.lassoSelect(page, listOf(-big, -big, big, -big, big, big, -big, big))
    }.getOrDefault(emptyList())
    val ids = (known + everything).distinct()
    if (ids.isEmpty()) return
    runCatching { session.lassoDelete(page, ids) }
    engine.load()
    latency.clear()
    revision++
    clearToken++ // 低延遲路徑的前緩衝也要清，否則舊筆畫還留在畫面上
}

/** 目前有沒有可調層級的選取物件（工具列「上移／下移一層」據此啟用）。 */
internal fun EditorCanvasContext.hasReorderableSelection(): Boolean =
    selectedTextId != null || selectedShapeIds.isNotEmpty() || selectedImageId != null ||
        selectedTableId != null || selectedChartId != null

/** 選取中的物件（文字 → 形狀 → 圖片 → 表格 → 圖表）上移／下移一層。 */
private fun EditorCanvasContext.reorderSelected(forward: Boolean) {
    val targetId = selectedTextId ?: selectedShapeIds.firstOrNull() ?: selectedImageId
        ?: selectedTableId ?: selectedChartId
    // 沒有選取時工具列上的按鈕是停用的（`hasSelectedObject`），這裡只是保險。
    if (targetId == null) return
    val order = stackOrderLatest
    val updated = if (forward) ObjectStacking.bringForward(setOf(targetId), order)
    else ObjectStacking.sendBackward(setOf(targetId), order)
    meta.setObjectOrder(notebook?.first, pageIndex, updated)
    stackRevision++
}

/** 放置模式下有東西可放：物件，或框選開始的放置帶著的筆跡。 */
internal val EditorCanvasContext.hasPlaceableClipboard: Boolean
    get() = objectClipboard.isNotEmpty() || (lasso.inkPlacementArmed && lasso.canPaste)

/**
 * 放置模式下點了頁面某處：物件與（框選帶來的）筆跡以**整組**聯集外框的中心對齊點下去的位置，
 * 彼此相對位置不變。筆跡走核心的套索貼上（當下寫事件，I2）。與 Apple `placeClipboard(at:onPage:)` 一致。
 */
internal fun EditorCanvasContext.placeClipboardAt(target: androidx.compose.ui.geometry.Offset) {
    val frames = objectClipboard.map { it.frame }
    val objectUnion = frames.reduceOrNull { a, b ->
        androidx.compose.ui.geometry.Rect(minOf(a.left, b.left), minOf(a.top, b.top), maxOf(a.right, b.right), maxOf(a.bottom, b.bottom))
    }
    val ink = if (lasso.inkPlacementArmed && lasso.canPaste) lasso.clipboardBounds else null
    val union = listOfNotNull(objectUnion, ink).reduceOrNull { a, b ->
        androidx.compose.ui.geometry.Rect(minOf(a.left, b.left), minOf(a.top, b.top), maxOf(a.right, b.right), maxOf(a.bottom, b.bottom))
    }
    if (union != null) {
        val delta = target - union.center
        if (objectUnion != null) pasteSinglePageClipboard(objectUnion.center + delta)
        if (ink != null && lasso.paste(engine, delta)) revision++
    }
    isPlacingPasteObject = false
    lasso.inkPlacementArmed = false
}

/** 開啟 Pro 專業色輪（受 Pro 門禁與二段式輕提示保護）。 */
internal fun EditorCanvasContext.openProColorWheel() {
    EntitlementManager.requirePro(ProFeatureGate.PRO_INK_AND_THEMES, l10n("ink_pro_wheel")) {
        showProColorWheel = true
    }
}


