package com.kairumo.padnote

import android.Manifest
import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.view.HapticFeedbackConstants
import android.view.KeyEvent
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.*
import androidx.compose.foundation.*
import androidx.compose.foundation.draganddrop.dragAndDropTarget
import androidx.compose.foundation.gestures.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.*
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.snapshots.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draganddrop.DragAndDropEvent
import androidx.compose.ui.draganddrop.DragAndDropTarget
import androidx.compose.ui.draganddrop.mimeTypes
import androidx.compose.ui.draganddrop.toAndroidDragEvent
import androidx.compose.ui.draw.*
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.*
import androidx.compose.ui.layout.*
import androidx.compose.ui.platform.*
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.*
import androidx.compose.ui.text.style.*
import androidx.compose.ui.unit.*
import androidx.compose.ui.window.*
import androidx.compose.ui.zIndex
import androidx.documentfile.provider.DocumentFile
import com.kairumo.padnote.account.*
import com.kairumo.padnote.ai.*
import com.kairumo.padnote.asset.*
import com.kairumo.padnote.audio.*
import com.kairumo.padnote.backup.*
import com.kairumo.padnote.canvas.*
import com.kairumo.padnote.canvas.fingerTapOnLockedObject
import com.kairumo.padnote.chart.*
import com.kairumo.padnote.collab.*
import com.kairumo.padnote.comment.*
import com.kairumo.padnote.image.*
import com.kairumo.padnote.ink.*
import com.kairumo.padnote.library.*
import com.kairumo.padnote.math.*
import com.kairumo.padnote.model3d.*
import com.kairumo.padnote.platform.*
import com.kairumo.padnote.profile.*
import com.kairumo.padnote.shape.*
import com.kairumo.padnote.sync.*
import com.kairumo.padnote.table.*
import com.kairumo.padnote.text.*
import com.kairumo.padnote.text.doubleTapToWrite
import com.kairumo.padnote.theme.*
import com.kairumo.padnote.ui.*
import kotlinx.coroutines.*
import uniffi.padnote_core.*
import java.io.File


@OptIn(ExperimentalLayoutApi::class, ExperimentalFoundationApi::class)
@Composable
internal fun EditorFloatingPanels(ctx: EditorCanvasContext) = with(ctx) {
    if (showPageSidebar && !layout.sidebarIsInline) {
        androidx.compose.ui.window.Dialog(
            onDismissRequest = { showPageSidebar = false },
            properties = androidx.compose.ui.window.DialogProperties(
                usePlatformDefaultWidth = false
            )
        ) {
            Surface(modifier = Modifier.fillMaxHeight()) {
                PageSidebar(
                    session = notebook?.first,
                    pageCount = pageCount,
                    pageIndex = pageIndex,
                    revision = revision + textRevision + shapeRevision + tableRevision +
                        chartRevision + imageRevision + model3DRevision + continuousContentRevision,
                    l = { key -> l10n(key) },
                    onSelectPage = { pageIndex = it; showPageSidebar = false },
                    onAddPage = {
                        val s = notebook?.first
                        if (s != null) {
                            runCatching { s.addPage(uniffi.padnote_core.PageStyle.BLANK) }
                            pageCount = runCatching { s.pageCount().toInt() }
                                .getOrDefault(pageCount + 1)
                            pageIndex = pageCount - 1
                            revision++
                            continuousContentRevision++
                            continuousScrollRequest++
                        }
                        showPageSidebar = false
                    },
                    onMovePage = { from, to -> movePage(from, to) },
                    onInsertPageAfter = { idx, pid -> insertPageAfter(idx, pid) },
                        onDuplicatePage = { idx -> duplicatePage(idx) },
                    onDeletePage = { idx -> deletePageAt(idx) },
                    onTransferPage = { index, moveOut -> transferringPage = index to moveOut },
                    onOpenNotebook = { id -> showPageSidebar = false; onOpenNotebook?.invoke(id) },
                    deviceId = deviceId(activity),
                    onClose = { showPageSidebar = false }
                )
            }
        }
    }

    if (deletingPage) {
        AlertDialog(
            onDismissRequest = { deletingPage = false },
            title = { Text(l10n("delete_page")) },
            text = { Text(l10n("delete_page_confirm").replace("%@", "${pageIndex + 1}")) },
            confirmButton = {
                TextButton(onClick = {
                    deletingPage = false
                    // 與側欄的刪除同一支：原本這裡只刪核心的頁，紙張與以頁碼記位置的物件
                    // （卡片、膠帶、錨定…）留在原頁碼，落到下一頁上。
                    if (pageId != null) deletePageAt(pageIndex)
                }) { Text(l10n("delete")) }
            },
            dismissButton = {
                TextButton(onClick = { deletingPage = false }) { Text(l10n("cancel")) }
            }
        )
    }

    /**
     * 對齊選取中的物件。
     *
     * 幾何交給核心的 `alignRects`；這裡只負責「哪個 id 是哪個物件」與把新座標
     * 寫回去。**矩形的順序必須與回傳座標的順序一致**，錯位的話每個物件會搬到
     * 別人的位置。
     *
     * id 由圖層面板給 —— 畫布上的選取是「每種型別各一個」，兩個文字方塊
     * 根本選不起來，而對齊最常用的就是那種情況。
     */
    fun alignObjects(mode: uniffi.padnote_core.FfiAlignMode, ids: List<String>) {
        if (ids.size < 2) return

        val rects = ids.map { id ->
            // 有任何一個找不到就整批不動 —— 只搬一半比不搬更難收拾。
            ObjectGeometry.rectOf(id, textStore, imageStore, tableStore, chartStore, shapeStore)
                ?: return
        }
        val origins = uniffi.padnote_core.alignRects(rects, mode)
        if (origins.size != ids.size) return
        ids.forEachIndexed { i, id ->
            ObjectGeometry.move(id, origins[i].x, origins[i].y,
                textStore, imageStore, tableStore, chartStore, shapeStore)
        }
        textRevision++; imageRevision++; tableRevision++; chartRevision++; shapeRevision++
    }

    openPin?.let { pin ->
        val profile = AccountManager.load(activity, l10n("default_user_name"))
        CommentThreadDialog(
            pin = pin,
            languageTag = deviceLanguageTag(),
            currentUserId = deviceId(activity).toString(),
            currentUserName = profile.displayName,
            currentUserColor = profile.colorHex,
            onChanged = { meta.setCommentPins(notebook?.first, pins); pinRevision++ },
            onDelete = {
                pins = pins.filterNot { it.id == pin.id }.toMutableList()
                meta.setCommentPins(notebook?.first, pins)
                pinRevision++
            },
            onDismiss = { openPin = null }
        )
    }

    if (showProColors) {
        ProColorPicker(
            languageTag = deviceLanguageTag(),
            currentHex = inkColorHex,
            // 挑完直接套到目前的筆 —— 專業色盤最常見的用途就是換筆色。
            onPick = { inkColorHex = it },
            onDismiss = { showProColors = false }
        )
    }

    // 專業 HSV 色相環（Studio Drawing 進階色輪）
    if (showProColorWheel) {
        ProColorWheelDialog(
            languageTag = deviceLanguageTag(),
            initialHex = inkColorHex,
            onPick = { hex ->
                inkColorHex = hex
                engine.colorRgba = hexToRgba(hex)
                showProColorWheel = false
            },
            onDismiss = { showProColorWheel = false }
        )
    }

    if (insertingLink) {
        LinkInsertDialog(
            l = { key -> l10n(key) },
            onDismiss = { insertingLink = false },
            // 參數叫 `fetched` 不叫 `meta` —— 外層的 `meta` 是這本筆記的
            // NotebookMeta，同名會把它整個遮掉，而且編譯器只會說
            // 「找不到 setLinks」，不會說是被遮蔽。
            onInsert = { fetched ->
                val (w, h) = LinkCard.cardSize()
                val link = LinkObject(
                    id = java.util.UUID.randomUUID().toString(),
                    pageIndex = pageIndex,
                    urlString = fetched.url,
                    title = fetched.title,
                    descriptionText = fetched.description,
                    siteName = fetched.siteName,
                    x = 60f, y = 120f, width = w, height = h
                )
                links = (links + link).toMutableList()
                // 真身寫進中繼資料（會跟著同步走），另外存一張算繪好的 PNG
                // 當後備 —— 還不認得這個型別的版本至少看得到內容。
                meta.setLinks(notebook?.first, links)
                LinkCard.render(
                    uniffi.padnote_core.FfiLinkMetadata(
                        url = link.urlString,
                        title = link.title,
                        description = link.descriptionText,
                        siteName = link.siteName
                    )
                )?.let { png ->
                    runCatching {
                        val s2 = notebook?.first ?: return@runCatching
                        val page = pageId ?: return@runCatching
                        val blob = s2.putBlob(png)
                        val blockId = s2.addImage(page, blob, link.width, link.height)
                        s2.setBlockPosition(blockId, link.x, link.y)
                        // 標成衍生圖片，`ImageStore` 才會跳過它 ——
                        // 不標的話同一張卡片會出現兩份，各自能拖到不同地方。
                        s2.setBlockAppearance(
                            blockId,
                            org.json.JSONObject().put("object", "link").toString()
                        )
                    }
                }
                insertingLink = false
                linkRevision++
            }
        )
    }

    editingLink?.let { target ->
        // 網址、標題與說明一直都在模型裡、也一直跟著同步走，但在這一版
        // 之前沒有任何介面改得到 —— 解析錯一次就只能刪掉重插。
        var draftTitle by remember(target.id) { mutableStateOf(target.title) }
        var draftDesc by remember(target.id) { mutableStateOf(target.descriptionText) }
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { editingLink = null },
            title = { Text(l10n("link_edit")) },
            text = {
                androidx.compose.foundation.layout.Column {
                    androidx.compose.material3.OutlinedTextField(
                        value = draftTitle,
                        onValueChange = { draftTitle = it },
                        label = { Text(l10n("link_title")) },
                        singleLine = true
                    )
                    androidx.compose.material3.OutlinedTextField(
                        value = draftDesc,
                        onValueChange = { draftDesc = it },
                        label = { Text(l10n("link_description")) },
                        modifier = Modifier.padding(top = 8.dp)
                    )
                }
            },
            confirmButton = {
                androidx.compose.material3.TextButton(onClick = {
                    val updated = target.copy(
                        title = draftTitle, descriptionText = draftDesc
                    )
                    links = links.map { if (it.id == target.id) updated else it }.toMutableList()
                    meta.setLinks(notebook?.first, links)
                    linkRevision++
                    editingLink = null
                }) { Text(l10n("done")) }
            },
            dismissButton = {
                androidx.compose.material3.TextButton(onClick = { editingLink = null }) {
                    Text(l10n("cancel"))
                }
            }
        )
    }

    pdfToInsert?.let { pdfFile ->
        PdfPageInsertDialog(
            l = { key -> l10n(key) },
            file = pdfFile,
            onDismiss = { pdfToInsert = null },
            onPick = { png ->
                val inserted = imageStore.insert(png, pdfFile.nameWithoutExtension)
                imageRevision++
                selectedImageId = inserted?.id
                if (inserted != null) {
                    // 插入後切到打字模式 —— 手寫模式下物件不吃觸控，
                    // 剛插進來的那一頁會拖不動，看起來像插壞了。
                    editorMode = EditorMode.TYPE
                } else {
                    message = l10n("pdf_render_failed")
                }
                pdfToInsert = null
            },
            onImportAll = { onProgress ->
                val (done, skipped) = importPdfAsPages(pdfFile, onProgress)
                message = when {
                    done == 0 -> l10n("pdf_render_failed")
                    skipped > 0 -> l10n("pdf_import_partial").replace("%1@", done.toString()).replace("%2@", skipped.toString())
                    else -> l10n("pdf_import_done").replace("%@", done.toString())
                }
                pdfToInsert = null
            }
        )
    }

    if (insertingAudio) {
        AudioInsertDialog(
            l = { key -> l10n(key) },
            audioDirectory = audioDirectory,
            onDismiss = { insertingAudio = false },
            onPick = { file -> insertAudioCard(file) },
            onImportFile = {
                insertingAudio = false
                audioImportPicker.launch(audioMimeTypes)
            }
        )
    }

    renamingAudio?.let { target ->
        var draft by remember(target.id) { mutableStateOf(target.title) }
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { renamingAudio = null },
            title = { Text(l10n("rename_audio_card")) },
            text = {
                androidx.compose.material3.OutlinedTextField(
                    value = draft,
                    onValueChange = { draft = it },
                    label = { Text(l10n("recording_title")) },
                    singleLine = true
                )
            },
            confirmButton = {
                androidx.compose.material3.TextButton(onClick = {
                    val trimmed = draft.trim()
                    if (trimmed.isNotEmpty()) {
                        target.title = trimmed
                        audioCards = audioCards.map { if (it.id == target.id) target else it }
                            .toMutableList()
                        meta.setAudioCards(notebook?.first, audioCards)
                        notebook?.first?.let { RecordingTitles.write(it, target.fileName, trimmed) }
                        audioRevision++
                    }
                    renamingAudio = null
                }) { Text(l10n("done")) }
            },
            dismissButton = {
                androidx.compose.material3.TextButton(onClick = { renamingAudio = null }) {
                    Text(l10n("cancel"))
                }
            }
        )
    }

    if (showCalculator) {
        MathCalculatorDialog(
            languageTag = deviceLanguageTag(),
            onInsert = { text ->
                // 插成文字方塊而不是圖片 —— 算式之後還改得動。
                val box = textStore.create(x = 60f, y = 80f)
                box.text = text
                textStore.persist(box)
                textRevision++
                selectedTextId = box.id
                editorMode = EditorMode.TYPE
            },
            onDismiss = { showCalculator = false }
        )
    }

    if (insertingModel3D || editingModel3D != null) {
        val editing = editingModel3D
        Model3DStudio(
            languageTag = deviceLanguageTag(),
            existing = editing,
            onCommit = { model ->
                models3D = if (editing == null) {
                    (models3D + model.copy(pageIndex = pageIndex)).toMutableList()
                } else {
                    models3D.map { if (it.id == model.id) model else it }.toMutableList()
                }
                meta.setModels3D(notebook?.first, models3D)
                model3DRevision++
                selectedModel3DId = model.id
                // 插完切到打字模式，不然物件層不吃觸控、剛插的東西選不到。
                editorMode = EditorMode.TYPE
            },
            onDismiss = { insertingModel3D = false; editingModel3D = null }
        )
    }

    if (showNoteIntelligence) {
        NoteIntelligenceSheet(
            // 取的五種內容與首頁搜尋比對的**完全一樣**。不一致的話會出現
            // 一個很難解釋的狀況：使用者搜得到某句話，但摘要說筆記裡沒有
            // 提到它。
            text = notePlainText(
                // 標題從筆記庫查 —— 編輯器畫面上沒有顯示它，所以手上沒有。
                title = noteTitle,
                textBoxes = textStore.all.map { it.text },
                tableCells = tableStore.all.flatMap { it.cells },
                shapeLabels = shapeStore.all.map { it.label }
            ),
            locale = deviceLanguageTag(),
            l = { key -> l10n(key) },
            onInsert = { inserted ->
                // 插成一個文字方塊，位置固定在左上角一帶 —— 摘要是整則筆記
                // 的東西，不屬於任何一個特定位置。
                val box = textStore.create(60f, 80f)
                textStore.persist(box.copy(text = inserted))
                textRevision++
            },
            onDismiss = { showNoteIntelligence = false }
        )
    }

    if (showLanguagePicker) {
        LanguagePickerDialog(
            current = deviceLanguageTag(),
            onPick = { tag ->
                setAppLanguage(activity, tag)
                showLanguagePicker = false
                // 換語言要整個畫面重畫。重建 Activity 是最省事也最可靠的做法 ——
                // 逐個字串狀態去追，一定會漏掉幾個沒有重組的地方。
                activity.recreate()
            },
            onDismiss = { showLanguagePicker = false }
        )
    }

    pendingExport?.let { (file, format) ->
        ExportPreviewDialog(
            file = file,
            format = format,
            languageTag = deviceLanguageTag(),
            onExport = {
                message = shareExported(activity, file, format)
                pendingExport = null
            },
            onDismiss = {
                // 取消就把檔案刪掉 —— 它在預覽之前就已經落在 cache/exports，
                // 留著的話下次分享清單裡會冒出使用者以為沒匯出過的東西。
                runCatching { file.delete() }
                pendingExport = null
            }
        )
    }

    if (showPalmThresholds) {
        PalmThresholdDialog(
            languageTag = deviceLanguageTag(),
            onApply = { radius, retractMs ->
                engine.setPalmThresholds(radius, retractMs)
                palmTuned = radius != null
            },
            onDismiss = { showPalmThresholds = false }
        )
    }

    if (showPenSettings) {
        AdvancedPenSettingsDialog(
            languageTag = deviceLanguageTag(),
            onApply = { floor, gamma ->
                engine.setPressureCurve(floor ?: 0.1f, gamma ?: 1.0f)
                penTuned = floor != null
            },
            onDismiss = { showPenSettings = false }
        )
    }

    if (showRevertConfirm) {
        AlertDialog(
            onDismissRequest = { showRevertConfirm = false },
            title = { Text(l10n("revert_to_initial_state")) },
            text = { Text(l10n("revert_to_initial_state_confirm") + "\n\n" + l10n("revert_safety_note")) },
            confirmButton = {
                TextButton(
                    modifier = Modifier.testTag("editor.revert_confirm"),
                    onClick = {
                        showRevertConfirm = false
                        // `restoreMilestone` 要的是筆記本 id（拿來找套件），不是第一頁的 id。
                        val id = notebookId
                        val mark = openMarkId
                        if (id != null && mark != null) {
                            val safety = NotebookLibrary.restoreMilestone(
                                activity, id, deviceId(activity), mark,
                                l10n("milestone_before_restore").replace("%@", l10n("revert_to_initial_state"))
                            )
                            if (safety != null) {
                                sessionRevision++
                                android.widget.Toast.makeText(
                                    activity, l10n("revert_done"), android.widget.Toast.LENGTH_SHORT
                                ).show()
                            } else {
                                android.widget.Toast.makeText(
                                    activity, l10n("milestone_restore_failed"), android.widget.Toast.LENGTH_LONG
                                ).show()
                            }
                        }
                    }
                ) { Text(l10n("revert_confirm_action")) }
            },
            dismissButton = { TextButton(onClick = { showRevertConfirm = false }) { Text(l10n("cancel")) } }
        )
    }

    if (showCollaboration) {
        CollaborationSheet(
            manager = collaboration,
            languageTag = deviceLanguageTag(),
            notebookId = notebookId,
            deviceId = deviceId(activity),
            creatorName = AccountManager.load(activity, l10n("default_user_name")).displayName,
            // 還原改的是磁碟上的套件，記憶體裡那份還是還原前的 ——
            // 跟同步下載完之後一樣，重開這一本的 session 就好，
            // 不要 recreate 整個 Activity（那會把捲動位置與開著的面板全打掉）。
            onRestored = { sessionRevision++ },
            onDismiss = { showCollaboration = false }
        )
    }

    if (showAssetLibrary) {
        AssetLibrarySheet(
            languageTag = deviceLanguageTag(),
            onInsert = { item, style ->
                // 素材是**線圖**，沒有可編輯的文字內容，所以插成圖片區塊
                // ——與 Apple 端一致。向量在這裡算繪成 PNG 落盤，讓匯出 PDF
                // 與尚未支援素材的讀取器也看得到東西。
                val png = renderAssetPng(item.drawingCode, style, item.source)
                if (png != null) {
                    imageStore.insert(png, "${item.id}.png")
                    imageRevision++
                    editorMode = EditorMode.TYPE
                } else {
                    message = l10n("no_assets_found")
                }
            },
            onDismiss = { showAssetLibrary = false }
        )
    }

    if (showStickerLibrary) {
        // 貼紙貼進來是**圖片物件**，不是筆跡：點一下就有把手，可以搬、縮放、旋轉、
        // 刪除。貼成筆跡的話它跟手寫的字混在一起，確認後就沒有任何辦法再動它。
        // 與 Apple 同一個做法；跟素材庫一樣落成 PNG 插進圖片區塊。
        fun placeSticker(code: String, size: Float) {
            val png = com.kairumo.padnote.ui.renderStickerPng(code, engine.colorRgba)
            val inserted = png?.let { imageStore.insert(it, "$code.png", maxWidth = size) }
            if (inserted == null) {
                message = l10n("err_image_read_failed")
                return
            }
            inserted.x = 160f
            inserted.y = 200f
            // 貼紙是透明底的線稿：不要圓角、不要陰影，否則會多出一塊方形的影子。
            inserted.cornerRadius = 0f
            inserted.hasShadow = false
            imageStore.persist(inserted)
            imageRevision++
            selectedImageId = inserted.id
            // 手寫模式下物件不吃觸控，貼完卻點不動等於原本的問題。
            editorMode = EditorMode.TYPE
            message = l10n("sticker_placed_hint")
            showStickerLibrary = false
        }
        com.kairumo.padnote.ui.StickerLibrarySheet(
            languageTag = deviceLanguageTag(),
            onPick = { code -> placeSticker(code, 120f) },
            onPickWithSize = { code, size -> placeSticker(code, size) },
            onDismiss = { showStickerLibrary = false }
        )
    }

    if (showToolbarCustomization) {
        com.kairumo.padnote.ui.ToolbarCustomizationSheet(
            context = activity,
            languageTag = deviceLanguageTag(),
            onDismiss = { showToolbarCustomization = false }
        )
    }

    if (showThemeTools) {
        ThemeToolsSheet(
            languageTag = deviceLanguageTag(),
            goldenSpiral = goldenSpiral,
            ruleOfThirds = ruleOfThirds,
            onGoldenSpiralChange = { goldenSpiral = it },
            onRuleOfThirdsChange = { ruleOfThirds = it },
            onPickColor = { inkColorHex = it },
            onInsertText = { text ->
                // 插成文字方塊而不是圖片 —— 標註插完還要改數字。
                val box = textStore.create(x = 60f, y = 80f)
                box.text = text
                textStore.persist(box)
                textRevision++
                selectedTextId = box.id
                editorMode = EditorMode.TYPE
            },
            onDismiss = { showThemeTools = false }
        )
    }

    if (showStackPanel) {
        CanvasStackPanel(
            items = stackItems,
            order = stackOrder,
            underInkIds = underInkIds,
            lockedIds = lockedIds,
            onLockChange = { id, locked -> objectLock.setLocked(id, locked) },
            languageTag = deviceLanguageTag(),
            onOrderChange = { updated ->
                // 只寫這一頁，其餘頁面與其餘中繼資料欄位原封不動。
                meta.setObjectOrder(notebook?.first, pageIndex, updated)
                stackRevision++
            },
            onUnderInkChange = { updatedUnder ->
                // 面板給的是「搬完之後實際在下方的整組」；兩份明確清單怎麼改交給核心。
                val sunk = kindOf.filterKeys { it in updatedUnder && it !in underInkIds }
                val lifted = kindOf.filterKeys { it in underInkIds && it !in updatedUnder }
                meta.moveObjectsToInkPlane(notebook?.first, pageIndex, sunk, uniffi.padnote_core.FfiInkPlane.BELOW_INK)
                meta.moveObjectsToInkPlane(notebook?.first, pageIndex, lifted, uniffi.padnote_core.FfiInkPlane.ABOVE_INK)
                stackRevision++
            },
            onAlign = { mode, ids -> alignObjects(mode, ids) },
            onDismiss = { showStackPanel = false }
        )
    }

    editingImage?.let { image ->
        ImageEditor(
            image = image,
            languageTag = deviceLanguageTag(),
            onReorder = { op -> objectReorder(image.id, op) },
            onChanged = { imageStore.persist(it); imageRevision++ },
            onDelete = {
                imageStore.remove(image)
                selectedImageId = null
                imageRevision++
            },
            onDismiss = { editingImage = null }
        )
    }

    editingShape?.let { shape ->
        ShapeEditDialog(
            shape = shape,
            languageTag = deviceLanguageTag(),
            onApply = { updated ->
                shapeStore.persist(updated)
                shapeRevision++
            },
            onDuplicate = { source ->
                val copy = shapeStore.create(
                    source.copyShape().apply { x += 24f; y += 24f; groupId = null })
                selectedShapeIds = setOf(copy.id)
                editingShape = copy
                shapeRevision++
            },
            onDelete = { target ->
                shapeStore.remove(target)
                selectedShapeIds = selectedShapeIds - target.id
                shapeRevision++
            },
            onReorder = { op -> objectReorder(shape.id, op) },
            onDismiss = { editingShape = null }
        )
    }

    editingConnection?.let { link ->
        ConnectionEditDialog(
            link = link,
            languageTag = deviceLanguageTag(),
            onApply = { updated ->
                shapeStore.persist(updated)
                shapeRevision++
            },
            onDelete = { target ->
                shapeStore.remove(target)
                selectedConnectionId = null
                shapeRevision++
            },
            onDismiss = { editingConnection = null }
        )
    }

    editingText?.let { box ->
        TextBoxEditor(
            box = box,
            languageTag = deviceLanguageTag(),
            onReorder = { op -> objectReorder(box.id, op) },
            remoteRevision = collabTextRevision,
            typingPeerName = if (collabActive) collaboration.typingPeers(box.id).firstOrNull()?.userName else null,
            onChanged = { updated ->
                textStore.persist(updated)
                editingText = updated
                textRevision++
            },
            onDelete = {
                textStore.remove(box)
                editingText = null
                selectedTextId = null
                textRevision++
            },
            onDismiss = { editingText = null }
        )
    }

    if (insertingShape) {
        ShapePicker(
            languageTag = deviceLanguageTag(),
            onCommit = { newShapes, newConnections ->
                // 範本的連線指向的是**核心給的 id**，不是範本裡的暫時 id ——
                // 用暫時 id 的話，線會指向不存在的物件，畫面上是一條從空氣
                // 連出來的線。
                val created = mutableMapOf<String, NoteShape>()
                for (shape in newShapes) {
                    created[shape.id] = shapeStore.create(shape)
                }
                for (link in newConnections) {
                    val from = created[link.fromShapeId] ?: continue
                    val to = created[link.toShapeId] ?: continue
                    shapeStore.connect(from, to, link.label)
                }
                shapeRevision++
                insertingShape = false
                // 插入後切到打字模式 —— 手寫模式下物件不吃觸控，剛插進來的形狀
                // 會拖不動、選不起來，看起來像插壞了（與圖片、PDF 頁面同一條規則）。
                editorMode = EditorMode.TYPE
            },
            onDismiss = { insertingShape = false }
        )
    }

    if (showLayerPanel) {
        LayerPanel(
            shapes = shapeStore.all,
            selection = selectedShapeIds,
            languageTag = deviceLanguageTag(),
            onSelectionChange = { selectedShapeIds = it },
            onShapesChange = { updated ->
                shapeStore.replaceAll(updated)
                shapeRevision++
            },
            onDismiss = { showLayerPanel = false }
        )
    }

    // 插入一張新表格。
    if (insertingTable) {
        TableEditor(
            table = NoteTable(),
            languageTag = deviceLanguageTag(),
            isNew = true,
            onCommit = { table ->
                tableStore.create(table)
                tableRevision++
                insertingTable = false
            },
            onDelete = { insertingTable = false },
            onDismiss = { insertingTable = false }
        )
    }

    // 重新編修既有的表格。
    editingTable?.let { table ->
        TableEditor(
            table = table,
            languageTag = deviceLanguageTag(),
            isNew = false,
            onCommit = { updated ->
                // 位置原地保留：使用者只是改了裡面的內容。
                tableStore.persist(
                    updated.copyTable().apply { x = table.x; y = table.y }
                )
                tableRevision++
                editingTable = null
            },
            onDelete = {
                tableStore.remove(table)
                tableRevision++
                editingTable = null
                selectedTableId = null
            },
            onDismiss = { editingTable = null }
        )
    }

    // 插入一張新圖表。
    if (insertingChart) {
        Dialog(onDismissRequest = { insertingChart = false }) {
            Surface(shape = RoundedCornerShape(12.dp)) {
                ChartStudio(
                    languageTag = deviceLanguageTag(),
                    onCommit = { spec ->
                        chartStore.create(spec)
                        chartRevision++
                        insertingChart = false
                    },
                    onDismiss = { insertingChart = false }
                )
            }
        }
    }

    // 重新編修既有的圖表。帶著原本的設定進去，使用者看到的是自己當初輸入的
    // 數字 —— 而不是一張只能刪掉重做的圖。
    editingChart?.let { chart ->
        Dialog(onDismissRequest = { editingChart = null }) {
            Surface(shape = RoundedCornerShape(12.dp)) {
                ChartStudio(
                    languageTag = deviceLanguageTag(),
                    initial = chart.spec,
                    onCommit = { spec ->
                        // 位置與尺寸原地保留：使用者只是改了裡面的數字。
                        chartStore.persist(chart.copy(spec = spec))
                        chartRevision++
                        editingChart = null
                    },
                    onDismiss = { editingChart = null }
                )
            }
        }
    }

    docsAsset?.let { asset ->
        // 全螢幕對話框而不是 AlertDialog：說明文件是要「讀」的，
        // 塞進一個固定高度的小框裡，使用者看到的是一小條白色。
        Dialog(
            onDismissRequest = { docsAsset = null },
            properties = DialogProperties(usePlatformDefaultWidth = false)
        ) {
            Surface(modifier = Modifier.fillMaxSize()) {
                com.kairumo.padnote.platform.DocsScreen(asset, deviceLanguageTag()) { docsAsset = null }
            }
        }
    }

    if (showSymbolPicker) {
        com.kairumo.padnote.text.SymbolPickerDialog(
            l = { key -> l10n(key) },
            onDismiss = { showSymbolPicker = false },
            onPick = { symbol ->
                showSymbolPicker = false
                // 與 Apple 的 `insertQuickTextSnippet` 一樣：插進一個**新的**
                // 文字方塊，而不是塞進目前選取的那一個 —— 使用者按符號時
                // 通常正在標註，不是在編輯某一段文字。
                val box = textStore.create(x = 100f, y = 120f)
                box.text = symbol
                box.fontSize = 20f
                box.bold = true
                box.width = 260f
                box.height = 64f
                textStore.persist(box)
                textRevision++
                selectedTextId = box.id
                editorMode = EditorMode.TYPE
            }
        )
    }

    transferringPage?.let { (pageIdx, moveOut) ->
        val others = remember(revision, notebookId) {
            NotebookLibrary.all(activity, deviceId(activity), folderId = NotebookLibrary.ANY_FOLDER)
                .filter { it.id != notebookId }
        }
        com.kairumo.padnote.library.TransferPagesDialog(
            title = l10n(if (moveOut) "move_pages_to_title" else "copy_pages_to_title"),
            notebooks = others,
            l = { key -> l10n(key) },
            onDismiss = { transferringPage = null },
            onPick = { target ->
                val session = notebook?.first
                val countBefore = pageCount
                val moved = if (session == null) {
                    0u
                } else {
                    val pages = runCatching {
                        session.transferPagesMapped(
                            listOf(pageIdx.toUInt()),
                            target.path.absolutePath,
                            moveOut
                        )
                    }.getOrDefault(emptyList())
                    // 核心只帶得動區塊、筆畫、形狀與連接線；紙張、卡片、膠帶、錨定、樣式這些
                    // 住在中繼資料裡，照核心回傳的頁碼與物件 id 對照表帶進目標那一本。
                    if (pages.isNotEmpty()) {
                        runCatching {
                            PadnoteSession.openExisting(target.path.absolutePath, deviceId(activity))
                                .use { targetSession ->
                                    val targetMeta = NotebookMeta.load(targetSession)
                                    for (page in pages) {
                                        targetMeta.receivePage(
                                            targetSession, source = meta,
                                            sourcePage = page.sourceIndex.toInt(),
                                            targetPage = page.targetIndex.toInt(),
                                            idMap = page.idMap
                                        )
                                    }
                                }
                        }
                    }
                    pages.size.toUInt()
                }
                transferringPage = null
                message = if (moved > 0u) {
                    l10n(if (moveOut) "pages_moved" else "pages_copied")
                        .replaceFirst("%@", moved.toString())
                        .replaceFirst("%@", target.title)
                } else {
                    l10n("transfer_failed")
                }
                // 搬移會少一頁：這本以頁碼記位置的東西（紙張、卡片、膠帶…）跟刪頁一樣往前補位，
                // 不然後面那幾頁的東西錯位一頁。
                if (moveOut && moved > 0u) meta.removePageTemplate(session, pageIdx, countBefore)
                pageCount = runCatching { session?.pageCount()?.toInt() }.getOrNull() ?: pageCount
                pageIndex = pageIndex.coerceIn(0, maxOf(0, pageCount - 1))
                revision++
            }
        )
    }

    val curNbId = notebookId
    if (renamingCurrent && curNbId != null) {
        // 用 FolderNameDialog 這個通用的「一個標題欄位」對話框 ——
        // RenameNotebookDialog 要一個 NotebookLibrary.Entry，而編輯器手上
        // 只有 id，為了它去掃整個筆記庫只是白做工。
        FolderNameDialog(
            title = l10n("rename_note"),
            initial = FolderTree.titleOf(activity, curNbId) ?: "",
            l = { key -> l10n(key) },
            onDismiss = { renamingCurrent = false },
            onConfirm = { newTitle ->
                if (newTitle.isNotBlank()) {
                    NotebookLibrary.rename(activity, curNbId, newTitle, deviceId(activity))
                    revision++
                }
                renamingCurrent = false
            }
        )
    }

    if (showStatus) {
        val rows = remember { readCoreStatus(activity) }
        val ver = remember { appVersionName(activity) }
        AppDiagnosticsDialog(
            versionString = ver,
            coreStatusRows = rows,
            latencySummary = latency.summaryMs(),
            l = { k -> l10n(k) },
            onDismiss = { showStatus = false }
        )
    }
}

// ────────────────────────────── 系統狀態與協同中繼診斷 ──────────────────────────────

internal fun readCoreStatus(activity: ComponentActivity): List<Pair<String, String>> = try {
    val info = appInfo()
    listOf(
        L10n.t("diag_core_version") to coreVersion(),
        L10n.t("diag_target_platform") to "${info.targetOs}/${info.targetArch}",
        L10n.t("diag_ui_version") to "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})",
        L10n.t("diag_collab_crypto") to checkSessionCrypto(),
        L10n.t("diag_collab_relay") to checkRelay(),
        L10n.t("diag_ui_language") to deviceLanguageTag(),
        L10n.t("diag_string_table") to L10n.f("diag_string_table_value", LocalizationStrings.table.size),
        L10n.t("diag_sample_string") to uiString("about_app")
    ) + activity.readHandoffPackage()
} catch (t: Throwable) {
    // 綁定或 .so 載入失敗時要講清楚，不要給一個空白畫面
    listOf(L10n.t("diag_core_load_failed") to (t.message ?: t.toString()))
}

/**
 * 走核心的協同加密做一次 round-trip。
 *
 * 格式與 Apple 版的 CryptoKit AES-256-GCM 逐位元組相同（核心那邊有跨語言測試），
 * 所以 Android 與 iOS 能在同一個協同房間裡互相解得開。
 */
/**
 * 啟動核心的協同中繼（padnote-relay），確認在 Android 上真的綁得到埠。
 *
 * 與 Apple 版共用同一份 JSON 協定 —— Apple 端維持它自己的 Swift 實作，
 * 兩邊仍然可以加入同一個房間。
 */
internal fun checkRelay(): String = try {
    val relay = RelayServer()
    val port = relay.start(0u)
    val running = relay.isRunning()
    relay.stop()
    if (running && port > 0u) L10n.f("diag_relay_started", port) else L10n.t("diag_relay_start_failed")
} catch (t: Throwable) {
    L10n.f("diag_failed", t.message)
}

/**
 * 打開 iOS 端匯出的 `.padnote` 套件並回報內容（工作包 WP4 的驗收）。
 *
 * 驗收條件是「iOS 建立的多頁筆記在 Android 開啟後，筆畫數、座標、顏色與
 * 頁面高度與原稿一致」。所以這裡不只顯示「開得起來」—— 要把可以逐項比對的
 * 數字攤出來：每頁筆畫數、第一筆的顏色與起點座標、每頁高度。
 *
 * 檔案放在 App 內部 filesDir。不用外部目錄：Android 10 之後 adb push 進去的
 * 檔案屬於 shell、App 反而讀不到，會得到一個看起來像「檔案壞掉」的錯誤訊息。
 * 放內部目錄則用 `adb shell run-as` 解壓進去即可（debug 版）。
 * 沒有檔案時整段略過。
 */
internal fun ComponentActivity.readHandoffPackage(): List<Pair<String, String>> {
    // profile-scope: device 除錯用的交接檔
    val pkg = java.io.File(filesDir, "handoff.padnote")
    if (!pkg.exists()) return emptyList()

    return try {
        val session = PadnoteSession.openExisting(pkg.absolutePath, 0xB0u)
        val rows = mutableListOf<Pair<String, String>>()
        rows += L10n.t("diag_handoff_note") to session.title()
        val pageCount = session.pageCount().toInt()
        rows += L10n.t("diag_pages") to pageCount.toString()

        for (i in 0 until pageCount) {
            val pageId = session.pageIdAt(i.toUInt()) ?: continue
            val strokes = session.visibleStrokeDetails(pageId)
            val height = session.pageSize(pageId)?.getOrNull(1) ?: 0f
            rows += L10n.f("diag_page_n", i + 1) to L10n.f("diag_page_value", strokes.size, height.toInt())
            strokes.firstOrNull()?.let { s ->
                val rgba = s.colorRgba.joinToString(",") { (it.toInt() and 0xFF).toString() }
                val p0 = s.points.first()
                rows += L10n.t("diag_first_stroke") to L10n.f("diag_first_stroke_value", rgba, p0.x, p0.y, s.points.size)
            }
        }
        rows
    } catch (t: Throwable) {
        listOf(L10n.t("diag_handoff_note") to L10n.f("diag_open_failed", t.message))
    }
}

/**
 * 協同加密的自我測試。
 *
 * **戳的必須是真的在用的那條路。** 舊版呼叫 `sessionSeal`/`sessionOpen`，
 * 而協同實際上走的是 `collabEncrypt`/`collabDecrypt` —— 於是這個診斷
 * 永遠是綠的，就算真正在用的那份壞了也一樣。
 * （兩份實作現在已經合成一份，但測試仍然該戳呼叫端走的那個入口。）
 */
internal fun checkSessionCrypto(): String = try {
    val key = collabGenerateRoomKey()
    val message = LocalizationStrings.localized("collab_notification_title", deviceLanguageTag())
    val sealed = collabEncrypt(key, message)
    val opened = collabDecrypt(key, sealed)
    when {
        sealed.isEmpty() -> L10n.t("diag_crypto_empty")
        opened == message -> L10n.t("diag_crypto_ok")
        else -> L10n.t("diag_crypto_mismatch")
    }
} catch (t: Throwable) {
    L10n.f("diag_failed", t.message)
}
