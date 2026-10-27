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
internal fun ColumnScope.EditorCanvasContainer(ctx: EditorCanvasContext) = with(ctx) {
        val radialAction: (String) -> Unit = { id ->
            // 槽位是使用者自訂的（見 ui/RadialMarkMenu.kt 的 RadialSlots），id 是 `radial.pen`…。
            val action = com.kairumo.padnote.ui.RadialSlots.actionFor(id)
            val tool = action?.let { com.kairumo.padnote.ui.RadialSlots.inkTool(it) }
            when {
                id == com.kairumo.padnote.ui.RADIAL_DISMISS -> showRadialMenu = false
                // 選工具與工具列走同一條路（applyInkTool）：離開套索清選取、橡皮擦旗標等不會漏。
                tool != null -> applyInkTool(tool)
                action == uniffi.padnote_core.FfiRadialAction.UNDO -> globalUndo()
                action == uniffi.padnote_core.FfiRadialAction.REDO -> globalRedo()
                action == uniffi.padnote_core.FfiRadialAction.COLOR -> showProColorWheel = true
                action == uniffi.padnote_core.FfiRadialAction.STABILIZER ->
                    strokeStabilizer = if (strokeStabilizer > 0f) 0f else 50f
                // 與 Ctrl+E 同一個做法：切回手寫時清掉文字選取。
                action == uniffi.padnote_core.FfiRadialAction.TOGGLE_MODE ->
                    if (editorMode == EditorMode.DRAW) {
                        editorMode = EditorMode.TYPE
                    } else {
                        editorMode = EditorMode.DRAW
                        selectedTextId = null
                    }
            }
        }

        // 兩條完全獨立的路。連續模式不碰整頁模式的任何一行 ——
        // 那一段綁著存檔、物件層、掌拒與模式切換，是最沒本錢壞掉的地方。
        if (pageDisplayMode == PageDisplayMode.CONTINUOUS) {
            val sideToolbar = effectiveToolbarMode == EditorMode.DRAW &&
                (toolbarPlacement == uniffi.padnote_core.FfiPlacement.LEFT ||
                    toolbarPlacement == uniffi.padnote_core.FfiPlacement.RIGHT)
            EditorWorkArea(
                sidebarInline = showPageSidebar && layout.sidebarIsInline,
                posture = posture,
                sidebar = {
                    PageSidebar(
                        session = notebook?.first,
                        pageCount = pageCount,
                        pageIndex = pageIndex,
                        revision = revision + textRevision + shapeRevision + tableRevision +
                            chartRevision + imageRevision + model3DRevision + continuousContentRevision,
                        l = { key -> l10n(key) },
                        onSelectPage = { pageIndex = it; continuousScrollRequest++ },
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
            ) {
                androidx.compose.foundation.layout.Row(
                    modifier = Modifier.weight(1f).fillMaxWidth()
                ) {
                    if (sideToolbar && toolbarPlacement == uniffi.padnote_core.FfiPlacement.LEFT) {
                        androidx.compose.foundation.layout.Column(
                            modifier = Modifier
                                .width(110.dp)
                                .fillMaxHeight()
                                .verticalScroll(rememberScrollState())
                        ) { RenderInkBar(inkBarState) }
                    }
                    ContinuousPagesView(
                        session = notebook?.first,
                        meta = meta,
                        pageCount = pageCount,
                        focusIndex = pageIndex,
                        // 焦點頁就是外層的 pageIndex，所以選單裡的插入動作
                        // 自然落在使用者正在看的那一頁。
                        onFocusChange = { pageIndex = it },
                        ink = InkSettings(
                            tool = inkTool.kind ?: uniffi.padnote_core.ToolKind.FOUNTAIN_PEN,
                            colorRgba = hexToRgba(inkColorHex),
                            baseWidth = inkWidth,
                            isErasing = inkTool.isEraser,
                            penOnly = penOnly
                        ),
                        editorMode = editorMode,
                        onModeChange = { editorMode = it },
                        // 任何一種物件有變動就讓連續模式重讀。逐項接 callback 的話，
                        // 之後新增一種物件很容易忘記接上，而症狀是「插進去看不到」。
                        reloadToken = textRevision + shapeRevision + tableRevision +
                            chartRevision + imageRevision + model3DRevision + linkRevision + audioRevision,
                        scrollRequest = continuousScrollRequest,
                        // 套索不限焦點頁：在哪一頁圈就圈哪一頁（與 Apple 連續模式一致）。
                        lasso = if (inkTool.isLasso) continuousLasso else null,
                        undoController = continuousUndo,
                        collabBridge = continuousCollab,
                        objectClipboard = objectClipboard,
                        onObjectClipboardChange = { objectClipboard = it },
                        isPlacingPasteObject = isPlacingPasteObject,
                        snapToGrid = snapToGrid,
                        onPlacingPasteObjectChange = { isPlacingPasteObject = it },
                        onMetaObjectsChanged = {
                            links = meta.links(); models3D = meta.models3D(); audioCards = meta.audioCards()
                            linkRevision++; model3DRevision++; audioRevision++
                        },
                        // 長按叫出飛梭工具盤：與整頁模式同一個手勢與條件（見整頁模式的畫布區）。
                        // 原本連續模式完全沒接 —— 長按只會在頁面上留下一個墨點。
                        // 這裡刻意少寫 lambda、不在外面包一層 Box：`InkScreen` 已經在 ART 驗證器的
                        // 上限邊緣，多兩三個 lambda 就啟動即 VerifyError（實測）。選單的動作走 `radialAction`。
                        modifier = Modifier.weight(1f).fillMaxHeight().radialHoldArea(
                            enabled = editorMode == EditorMode.DRAW && !showRadialMenu &&
                                !isPlacingCommentPin && !inkTool.isMaskingTape,
                            lasso = continuousLasso.takeIf { inkTool.isLasso },
                            onOpen = { center -> radialMenuCenter = center; showRadialMenu = true }
                        ),
                        radialMenuCenter = if (showRadialMenu) radialMenuCenter else null,
                        onRadialAction = radialAction
                    )
                    if (sideToolbar && toolbarPlacement == uniffi.padnote_core.FfiPlacement.RIGHT) {
                        androidx.compose.foundation.layout.Column(
                            modifier = Modifier
                                .width(110.dp)
                                .fillMaxHeight()
                                .verticalScroll(rememberScrollState())
                        ) { RenderInkBar(inkBarState) }
                    }
                }
            }
            if (effectiveToolbarMode == EditorMode.DRAW &&
                toolbarPlacement == uniffi.padnote_core.FfiPlacement.BOTTOM
            ) {
                RenderInkBar(inkBarState)
            }
            return@EditorCanvasContainer
        }

        // 從別的 App 把圖拖進來（工作項 S-68）。
        //
        // 掛在畫布這個 Box 上而不是整個畫面：落點要能換算成頁面座標，
        // 掛在外層的話拖到工具列上也會插進去，而且位置會偏掉。
        //
        // 落點與尺寸的計算走 `ImageDropPlacement`，與 Apple 端同一份規則 ——
        // 同一張圖拖到同一個位置，兩台裝置上要落在同一個地方。
        val canvasDensity = LocalDensity.current.density
        val haptic = androidx.compose.ui.platform.LocalHapticFeedback.current

        val imageDropTarget = remember(pageId, canvasDensity) {
            object : DragAndDropTarget {
                override fun onEntered(event: DragAndDropEvent) { isImageDropTargeted = true }
                override fun onExited(event: DragAndDropEvent) { isImageDropTargeted = false }
                override fun onEnded(event: DragAndDropEvent) { isImageDropTargeted = false }

                override fun onDrop(event: DragAndDropEvent): Boolean {
                    isImageDropTargeted = false
                    val drag = event.toAndroidDragEvent()
                    val uri = drag.clipData?.takeIf { it.itemCount > 0 }
                        ?.getItemAt(0)?.uri ?: return false

                    // **這一行不能少。** 跨 App 拖進來的 URI 預設讀不到 ——
                    // 少了它 `openInputStream` 會丟 SecurityException，症狀是
                    // 「從相簿拖過來什麼也沒發生」，而且沒有任何畫面提示。
                    val grant = runCatching {
                        activity.requestDragAndDropPermissions(drag)
                    }.getOrNull()
                    try {
                        val bytes = runCatching {
                            activity.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                        }.getOrNull()
                        if (bytes == null) {
                            message = l10n("err_image_read_failed")
                            return false
                        }
                        val name = uri.lastPathSegment?.substringAfterLast('/') ?: "image.png"
                        val inserted = imageStore.insert(bytes, name) ?: run {
                            message = l10n("err_image_read_failed")
                            return false
                        }
                        val bounds = android.graphics.BitmapFactory.Options().apply {
                            inJustDecodeBounds = true
                        }
                        android.graphics.BitmapFactory.decodeByteArray(
                            bytes, 0, bytes.size, bounds)
                        val placed = ImageDropPlacement.frame(
                            dropX = drag.x / canvasDensity,
                            dropY = drag.y / canvasDensity,
                            imageWidth = bounds.outWidth.toFloat(),
                            imageHeight = bounds.outHeight.toFloat(),
                            pageWidth = PageGeometry.width,
                            pageHeight = PageGeometry.height
                        )
                        inserted.x = placed.x
                        inserted.y = placed.y
                        inserted.width = placed.width
                        inserted.height = placed.height
                        imageStore.persist(inserted)
                        imageRevision++
                        selectedImageId = inserted.id
                        // 插進來之後切到打字模式：手寫模式下物件不吃觸控，
                        // 使用者剛拖進來的圖會拖不動，看起來像插壞了。
                        editorMode = EditorMode.TYPE
                        return true
                    } finally {
                        grant?.release()
                    }
                }
            }
        }

        EditorWorkArea(
            sidebarInline = showPageSidebar && layout.sidebarIsInline,
            posture = posture,
            modifier = Modifier.weight(if (isTabletopActive) 0.58f else 1f),
            sidebar = {
                PageSidebar(
                    session = notebook?.first,
                    pageCount = pageCount,
                    pageIndex = pageIndex,
                    revision = revision + textRevision + shapeRevision + tableRevision +
                        chartRevision + imageRevision + model3DRevision + continuousContentRevision,
                    l = { key -> l10n(key) },
                    onSelectPage = { pageIndex = it },
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
        ) {
        // **畫布的捲動與縮放。**
        //
        // 在此之前整頁模式的畫布是一個固定的 `Box` —— 既不捲動也不縮放。
        // 使用者的回報是「在手機上手指沒辦法捲動，也沒辦法變更畫面大小」，
        // 而那不是設定錯了，是根本沒做（連續模式只是剛好外面包了
        // `LazyColumn` 才捲得動）。
        //
        // 規則走核心的 `canvasGesture`，兩端同一套：
        //   手指能畫 → 一指畫線、兩指平移與縮放
        //   只有筆能畫 / 打字模式 → 一指就平移
        val gesture = remember(editorMode, penOnly) {
            uniffi.padnote_core.canvasGesture(
                if (editorMode == EditorMode.DRAW) {
                    uniffi.padnote_core.FfiEditorMode.DRAW
                } else {
                    uniffi.padnote_core.FfiEditorMode.TYPE
                },
                if (penOnly) {
                    uniffi.padnote_core.FfiInkPolicy.STYLUS_ONLY
                } else {
                    uniffi.padnote_core.FfiInkPolicy.ANY_INPUT
                }
            )
        }
        val onePanFinger = gesture.oneFinger == uniffi.padnote_core.FfiFingerAction.PAN

        // 多指手勢的動作端（S-GESTURE）。動作由核心的表決定，這裡只負責
        // 把它接到 Android 這一側的對應操作上。
        val onMultiFinger: (uniffi.padnote_core.FfiMultiFingerAction) -> Unit = { action ->
            when (action) {
                uniffi.padnote_core.FfiMultiFingerAction.NONE -> Unit
                uniffi.padnote_core.FfiMultiFingerAction.UNDO ->
                    globalUndo()
                uniffi.padnote_core.FfiMultiFingerAction.REDO ->
                    globalRedo()
                uniffi.padnote_core.FfiMultiFingerAction.PREV_PAGE ->
                    if (pageIndex > 0) pageIndex--
                uniffi.padnote_core.FfiMultiFingerAction.NEXT_PAGE ->
                    if (pageIndex < pageCount - 1) pageIndex++
            }
        }

        // 工具列在左／右時，畫布與它並排（S-261b）。
        //
        // 永遠包一層 Row：上／下／收合時它只裝畫布一個子項，與沒有包是
        // 等價的。用條件式決定要不要包的話，Compose 會在切換位置時把整棵
        // 畫布子樹丟掉重建 —— 那會清掉筆跡的暫存狀態。
        //
        // 直向工具列要能捲：十三顆按鈕在手機橫放時高度不夠，不給捲的話
        // 下面幾顆永遠點不到。
        val sideToolbar = effectiveToolbarMode == EditorMode.DRAW &&
            (toolbarPlacement == uniffi.padnote_core.FfiPlacement.LEFT ||
                toolbarPlacement == uniffi.padnote_core.FfiPlacement.RIGHT)
        androidx.compose.foundation.layout.Row(
            modifier = Modifier.weight(1f).fillMaxWidth()
        ) {
        if (sideToolbar && toolbarPlacement == uniffi.padnote_core.FfiPlacement.LEFT) {
            androidx.compose.foundation.layout.Column(
                modifier = Modifier
                    .width(110.dp)
                    .fillMaxHeight()
                    .verticalScroll(rememberScrollState())
            ) { RenderInkBar(inkBarState) }
        }
        // 圖學列佔用版面，不浮在畫布上：疊在頁面最上方會蓋住頁首標題與題目文字。
        // 與 Apple 的 `safeAreaInset(edge: .top)` 一致。
        Column(modifier = Modifier.weight(1f).fillMaxHeight()) {
        if (inkTool.isDrafting && editorMode == EditorMode.DRAW) {
            com.kairumo.padnote.ink.DraftingBar(
                languageTag = deviceLanguageTag(),
                onOpenSolidStudio = { showSolidStudio = true },
                onOpenToolbox = { showDraftingToolbox = true },
                onMarkAngle = { markProtractorReading(engine); revision++ },
                onCloseTool = {
                    DraftingState.selectTool(DraftTool.NONE)
                    DraftToolController.reset(engine)
                },
                modifier = Modifier.padding(top = 8.dp, bottom = 2.dp, start = 8.dp, end = 8.dp)
            )
        }
        var isCanvasNavigating by remember { mutableStateOf(false) }
        Box(
            modifier = Modifier.weight(1f).fillMaxWidth().padding(8.dp)
                .dragAndDropTarget(
                    shouldStartDragAndDrop = { start ->
                        start.mimeTypes().any { it.startsWith("image/") }
                    },
                    target = imageDropTarget
                )
                // 手勢攔在**外層**，而且只在該攔的時候攔。
                //
                // 全部攔下來的話筆就畫不了了；完全不攔的話，`InkCanvas` 的
                // `pointerInteropFilter` 會把每一個觸控都吃掉。所以逐點判斷：
                // 兩指以上一律是平移縮放，一指只有在「手指本來就不能畫」時才攔。
                // 筆尖或單指落下停住不動 ~0.55 秒：在落點彈出飛梭工具盤，並取消落下的那一點。
                // 正在拖曳套索選取、已有選取、打字、遮蔽膠帶、放圖釘時不攔（與 Apple 的
                // openRadialMenuFromPress 同一組條件）。
                .pressAndHoldForRadialMenu(lasso) { point ->
                    val blocked = editorMode != EditorMode.DRAW || showRadialMenu ||
                        isPlacingCommentPin || inkTool.isMaskingTape ||
                        (inkTool.isLasso && (lasso.isDragging || lasso.hasSelection))
                    if (blocked) return@pressAndHoldForRadialMenu false
                    engine.cancelInFlight()
                    lasso.cancelGesture()
                    radialMenuCenter = com.kairumo.padnote.ui.clampRadialCenter(
                        point, canvasViewport.width, canvasViewport.height, canvasDensity)
                    showRadialMenu = true
                    haptic.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.LongPress)
                    revision++
                    true
                }
                .pointerInput(onePanFinger, canvasViewport) {
                    awaitPointerEventScope {
                        while (true) {
                            val first = awaitPointerEvent(PointerEventPass.Initial)
                            val pointers = first.changes.count { it.pressed }
                            val stylus = first.changes.any {
                                it.type == PointerType.Stylus
                            }
                            val contentW = PageGeometry.width * canvasDensity
                            val contentH = PageGeometry.height * canvasDensity
                            val scaledW = contentW * canvasScale
                            val scaledH = contentH * canvasScale
                            val contentExceedsViewport = scaledW > canvasViewport.width || scaledH > canvasViewport.height || canvasScale > 1f
                            val takeIt = pointers >= 2 ||
                                (onePanFinger && !stylus && contentExceedsViewport)
                            if (!takeIt) continue
                            isCanvasNavigating = true

                            // **多指手勢（S-GESTURE）。**
                            //
                            // 雙指點擊＝復原、三指點擊＝重做、三指上下滑＝翻頁。
                            // 這四個動作 Apple 端一直都有（四個寫死的 @objc
                            // 方法），**Android 一個都沒有** —— 使用者回報
                            // 「手指操作畫布的設計無法落地」，在這一側那是字面
                            // 意義的真。規則現在在核心的 finger_tap_action /
                            // finger_swipe_action，兩端同一張表。
                            //
                            // 判定要在「手指全部離開」時才下：中途就判的話，
                            // 一個正在進行的縮放會在經過兩指的瞬間被當成點擊。
                            val startFingers = pointers
                            var maxFingers = pointers
                            var totalPan = Offset.Zero
                            var totalZoom = 1f

                            var event = first
                            while (event.changes.any { it.pressed }) {
                                maxFingers = maxOf(
                                    maxFingers, event.changes.count { it.pressed })
                                totalPan += event.calculatePan()
                                totalZoom *= event.calculateZoom()
                                val zoomChange = event.calculateZoom()
                                val panChange = event.calculatePan()
                                if (zoomChange != 1f || panChange != Offset.Zero) {
                                    canvasScale = uniffi.padnote_core.clampZoom(
                                        canvasScale * zoomChange
                                    )
                                    val contentW = PageGeometry.width * canvasDensity
                                    val contentH = PageGeometry.height * canvasDensity
                                    val scaledW = contentW * canvasScale
                                    val scaledH = contentH * canvasScale
                                    val margin = 80f * canvasDensity

                                    val minX = if (scaledW > canvasViewport.width) {
                                        canvasViewport.width - scaledW - margin
                                    } else {
                                        minOf(-margin, canvasViewport.width - scaledW - margin)
                                    }
                                    val maxX = if (scaledW > canvasViewport.width) {
                                        margin
                                    } else {
                                        maxOf(margin, canvasViewport.width - scaledW + margin)
                                    }

                                    val minY = if (scaledH > canvasViewport.height) {
                                        canvasViewport.height - scaledH - margin
                                    } else {
                                        minOf(-margin, canvasViewport.height - scaledH - margin)
                                    }
                                    val maxY = if (scaledH > canvasViewport.height) {
                                        margin
                                    } else {
                                        maxOf(margin, canvasViewport.height - scaledH + margin)
                                    }

                                    canvasOffset = Offset(
                                        (canvasOffset.x + panChange.x).coerceIn(minX, maxX),
                                        (canvasOffset.y + panChange.y).coerceIn(minY, maxY)
                                    )
                                }
                                event.changes.forEach { it.consume() }
                                event = awaitPointerEvent(PointerEventPass.Initial)
                            }
                            isCanvasNavigating = false

                            // 手指全部離開了 —— 現在才判這是點擊、滑動，
                            // 還是一次縮放／平移。
                            val zoomed = kotlin.math.abs(totalZoom - 1f) > 0.05f
                            val panDistance = totalPan.getDistance()
                            val action = when {
                                zoomed -> uniffi.padnote_core.FfiMultiFingerAction.NONE
                                // 幾乎沒動 = 點擊。48dp 是 Android 的最小
                                // 觸控目標，拿它當「有沒有移動」的門檻。
                                panDistance < 48.dp.toPx() ->
                                    uniffi.padnote_core.fingerTapAction(maxFingers.toUByte())
                                // 縱向為主才算滑動；橫向亂晃不該翻頁。
                                kotlin.math.abs(totalPan.y) > kotlin.math.abs(totalPan.x) * 2 ->
                                    uniffi.padnote_core.fingerSwipeAction(
                                        maxFingers.toUByte(), totalPan.y < 0)
                                else -> uniffi.padnote_core.FfiMultiFingerAction.NONE
                            }
                            // 起手就一指的不算多指手勢 —— 那是平移。
                            if (startFingers >= 2) onMultiFinger(action)
                        }
                    }
                }
                .onSizeChanged {
                    canvasViewport = Size(it.width.toFloat(), it.height.toFloat())
                    if (!didInitialFit && it.width > 0 && it.height > 0) {
                        didInitialFit = true
                        fitCanvas("width")
                    }
                }
        ) {
        CompositionLocalProvider(
            com.kairumo.padnote.canvas.LocalObjectReorder provides objectReorder,
            com.kairumo.padnote.canvas.LocalObjectLock provides objectLock,
            com.kairumo.padnote.canvas.LocalLockedObjectIds provides lockedIds,
            com.kairumo.padnote.canvas.LocalObjectClipboard provides objectClipboardActions,
            com.kairumo.padnote.canvas.LocalCanvasNavigating provides isCanvasNavigating,
            com.kairumo.padnote.canvas.LocalEditorMode provides editorMode
        ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer(
                    scaleX = canvasScale,
                    scaleY = canvasScale,
                    translationX = canvasOffset.x,
                    translationY = canvasOffset.y,
                    transformOrigin = androidx.compose.ui.graphics.TransformOrigin(0f, 0f),
                    // **一定要裁切。** 不裁的話平移之後頁面會畫到畫布範圍
                    // 外面，蓋在工具列上 —— 實機上看到的是「捲一下工具列
                    // 就不見了」。
                    clip = true
                )
                // 手寫模式下手指點物件：鎖定物件給「解除鎖定」鈕；未鎖定物件直接選取它以供剪下、複製、搬移。
                .fingerTapOnLockedObject(
                    listOf(editorMode, inkTool.isLasso, inkTool.isMaskingTape, isPlacingCommentPin, isPlacingPasteObject),
                    hitAt = { p ->
                        if (editorMode != EditorMode.DRAW || inkTool.isLasso || inkTool.isMaskingTape ||
                            isPlacingCommentPin || isPlacingPasteObject) null
                        else {
                            val sorted = marqueeCandidatesLatest.sortedBy { stackOrderLatest.indexOf(it.id) }
                            val pt = Offset(p.x / canvasDensity, p.y / canvasDensity)
                            com.kairumo.padnote.canvas.lockedObjectHit(
                                pt.x, pt.y, sorted, lockedIdsLatest
                            ) ?: com.kairumo.padnote.canvas.ObjectMarquee.topmostHit(pt, sorted)
                        }
                    },
                    onCancelInk = { engine.cancelInFlight(); revision++ },
                    onTap = { id ->
                        if (id in lockedIdsLatest) {
                            editorMode = EditorMode.TYPE
                            lockPromptId = id
                        } else {
                            applySinglePageClipboardSelection(setOf(id))
                        }
                    }
                )
                // 手繪模式下手指雙擊空白處：建立文字方塊並切到打字模式（對齊 Apple）。
                .doubleTapToWrite(
                    enabled = editorMode == EditorMode.DRAW && !inkTool.isLasso && !inkTool.isMaskingTape &&
                        !isPlacingCommentPin && !isPlacingPasteObject,
                    density = canvasDensity,
                    engine = engine,
                    textStore = textStore,
                    meta = meta,
                    session = notebook?.first,
                    pageIndex = pageIndex,
                    snapToGrid = snapToGrid,
                    frames = marqueeCandidatesLatest.sortedBy { stackOrderLatest.indexOf(it.id) },
                    stackOrder = stackOrderLatest,
                    onWritten = { box ->
                        selectedTextId = box.id
                        editorMode = EditorMode.TYPE
                        stackRevision++
                        textRevision++
                    }
                )
                .then(
                    if (editorMode == EditorMode.TYPE) {
                        Modifier.pointerInput(pageIndex, snapToGrid) {
                            detectTapGestures { offset: Offset ->
                                val tapX = offset.x / canvasDensity
                                val tapY = offset.y / canvasDensity
                                // 點到鎖定在畫布上的物件（它不接觸控，這一下穿透到頁面來了）：
                                // 不開新文字方塊、不就地編輯它，而是在它上方給「解除鎖定」鈕。
                                val lockedHit = com.kairumo.padnote.canvas.lockedObjectHit(
                                    tapX, tapY,
                                    marqueeCandidatesLatest.sortedBy { stackOrderLatest.indexOf(it.id) },
                                    lockedIdsLatest)
                                if (lockedHit != null) {
                                    lockPromptId = if (lockPromptId == lockedHit) null else lockedHit
                                    return@detectTapGestures
                                }
                                lockPromptId = null
                                val hitExisting = textStore.all.firstOrNull { box ->
                                    tapX >= (box.x - 10f) && tapX <= (box.x + box.width + 10f) &&
                                    tapY >= (box.y - 10f) && tapY <= (box.y + box.height + 10f)
                                }
                                if (hitExisting != null) {
                                    selectedTextId = hitExisting.id
                                    com.kairumo.padnote.text.InlineTextEditing.activeId = hitExisting.id
                                } else {
                                    val newBox = textStore.createTapToWrite(tapX, tapY, textStore.pageRules(meta.paperId(pageIndex)), snapToGrid)
                                    val updatedOrder = com.kairumo.padnote.canvas.ObjectStacking.bringToFront(
                                        setOf(newBox.id),
                                        stackOrder
                                    )
                                    meta.setObjectOrder(notebook?.first, pageIndex, updatedOrder)
                                    stackRevision++
                                    textRevision++
                                    selectedTextId = newBox.id
                                    com.kairumo.padnote.text.InlineTextEditing.activeId = newBox.id
                                }
                            }
                        }
                    } else {
                        Modifier
                    }
                )
        ) {
            // 紙張底紋。畫在墨跡**底下**：先畫的先被蓋住。
            //
            // 底紋來自那一頁自己存的 `PageStyle`（`add_page` 寫進去的），
            // 不是筆記層級的設定 —— 同一本筆記可以一頁方格、一頁康乃爾。
            val pageStyle = remember(pageId, revision) {
                runCatching {
                    notebook?.first?.pageStyle(pageId ?: return@runCatching null)
                }.getOrNull() ?: uniffi.padnote_core.PageStyle.BLANK
            }
            // 這張紙的**版面**。底紋只有六種，紙張有三十幾種 ——
            // 康乃爾與四象限的底紋都是 BLANK，差別全在版面上。
            val notebookMeta = remember(notebookId, revision) {
                com.kairumo.padnote.library.NotebookMeta.load(notebook?.first)
            }
            // 這本筆記的頁面規格（S-84）。畫布、底紋、分頁與匯出五條路都讀
            // `PageGeometry`，所以在這裡設一次就好 —— 與 Apple 的
            // `PageGeometry.use(format:)` 同一個做法。
            LaunchedEffect(notebookMeta) {
                com.kairumo.padnote.ink.PageGeometry.use(notebookMeta.pageFormatId())
            }
            // **逐頁**：同一本筆記可以一頁四象限、一頁日程表。
            val paperId = remember(notebookMeta, pageIndex) { notebookMeta.paperId(pageIndex) }
            val guidePaletteId = remember(notebookMeta) { notebookMeta.paletteId() }
            // 同步縮放與位移至筆跡引擎（S-80）。
            // 縮放時座標反變換，避免墨跡因手勢位移脫位。
            LaunchedEffect(canvasScale, canvasOffset, canvasDensity) {
                engine.zoom = canvasScale
                engine.offsetX = canvasOffset.x / canvasDensity
                engine.offsetY = canvasOffset.y / canvasDensity
            }
            val guideMeasurer = androidx.compose.ui.text.rememberTextMeasurer()
            // 縮放時不能走低延遲路徑。
            //
            // `LowLatencyInkCanvas` 畫在 `SurfaceView` 上，而 SurfaceView 是
            // 另一層合成的表面 —— `graphicsLayer` 的縮放**對它無效**，
            // 結果是底下的頁面縮小了、筆跡還是原本大小，兩層對不起來。
            //
            // 圖學筆畫也不能走低延遲路徑：它要依線型挖虛線、依圖層疊放與隱藏，
            // 前緩衝的簡化繪製做不到。
            val draftingInk = inkTool.isDrafting || inkTool.isLasso || engine.strokes.any { it.layer != 0 || it.lineType != 0 }
            if (lowLatency && !lowLatencyUnavailable && canvasScale == 1f && !draftingInk) {
                LowLatencyInkCanvas(
                    engine = engine,
                    latency = latency,
                    modifier = Modifier
                        .fillMaxSize()
                        .zIndex(100f)
                        .testTag("editor.canvas")
                        .semantics { contentDescription = "strokes:${engine.strokes.size}" },
                    onInkChanged = {
                        revision++
                        if (engine.consumeOutsidePrintableArea()) {
                            message = l10n("outside_printable_rejected")
                        }
                    },
                    onUnavailable = { lowLatencyUnavailable = true },
                    clearToken = clearToken,
                    onStylusDetected = {
                        // 全自動意圖感知：偵測到 Stylus 觸控筆下筆時，自動平滑切換回 DRAW 手繪模式
                        if (editorMode != EditorMode.DRAW) {
                            editorMode = EditorMode.DRAW
                            selectedTextId = null
                        }
                    },
                    acceptsInk = editorMode == EditorMode.DRAW
                )
            } else {
                InkCanvas(
                    engine = engine,
                    modifier = Modifier
                        .fillMaxSize()
                        .zIndex(100f)
                        .testTag("editor.canvas")
                        .semantics { contentDescription = "strokes:${engine.strokes.size}" },
                    backgroundColor = Color.Transparent,
                    inkColor = if (inkTool.isDrafting) {
                        DraftingState.parseHex(DraftingState.activeColorHex)
                    } else runCatching {
                        Color(android.graphics.Color.parseColor(inkColorHex))
                    }.getOrDefault(Color.Black),
                    onInkChanged = {
                        revision++
                        // 整筆畫在框線外會被引擎收回（S-85）。使用者要知道
                        // 那一筆去哪裡了 —— 沒有提示的話它就只是「消失了」。
                        if (engine.consumeOutsidePrintableArea()) {
                            message = l10n("outside_printable_rejected")
                        }
                    },
                    onFingerIgnored = {
                        if (penOnly) {
                            message = l10n("pen_only_toast")
                        }
                    },
                    onStylusDetected = {
                        // 全自動意圖感知：偵測到 Stylus 觸控筆下筆時，自動平滑切換回 DRAW 手繪模式
                        if (editorMode != EditorMode.DRAW) {
                            editorMode = EditorMode.DRAW
                            selectedTextId = null
                        }
                    },
                    contentVersion = revision,
                    lassoDrag = { if (inkTool.isLasso) lasso.dragPreview() else null },
                    // 底紋要畫在**畫布自己的白底之上、筆跡之下**。
                    // 疊一層 Composable 在外面是不行的：`InkCanvas` 會用
                    // `Color.White` 把整塊塗掉，底紋就消失了（實機看過）。
                    pageStyle = pageStyle,
                    paperId = paperId,
                    localizeGuide = l10n,
                    guideMeasurer = guideMeasurer,
                    guidePaletteId = guidePaletteId,
                    acceptsInk = editorMode == EditorMode.DRAW
                )
            }

            // 拖放的落點提示。與 Apple 端一樣是一圈虛線。
            if (isImageDropTargeted) {
                Box(
                    modifier = Modifier.fillMaxSize()
                        .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.08f))
                        .border(
                            3.dp,
                            MaterialTheme.colorScheme.primary,
                            RoundedCornerShape(8.dp)
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Surface(
                        shape = RoundedCornerShape(20.dp),
                        color = MaterialTheme.colorScheme.primary,
                        shadowElevation = 6.dp
                    ) {
                        Text(
                            text = l10n("multi_window_drop_hint"),
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.onPrimary,
                            modifier = Modifier.padding(horizontal = 20.dp, vertical = 10.dp)
                        )
                    }
                }
            }

            // 練習題進行中：題目、選項、批改結果（見 DraftingPractice.kt）。
            if (inkTool.isDrafting && editorMode == EditorMode.DRAW && com.kairumo.padnote.ink.PracticeSession.isActive) {
                @Suppress("UNUSED_EXPRESSION") revision
                com.kairumo.padnote.ink.PracticeCard(
                    engine = engine,
                    onNew = { PracticeSession_next(engine); revision++ },
                    modifier = Modifier.zIndex(10f).align(Alignment.BottomStart).padding(12.dp)
                )
            }
            // 套索層疊在畫布上面。套索模式下它吃掉所有觸控，畫布完全收不到 ——
            // 不必在 InkEngine 裡加「現在是不是套索模式」的分支，而那種分支
            // 正是墨跡路徑最不該有的東西。
            if (inkTool.isLasso) {
                LassoOverlay(
                    lasso = lasso,
                    engine = engine,
                    // 低延遲畫布（SurfaceView）畫不了拖曳中的位移。圖學筆畫與套索模式走的是一般畫布，
                    // 預覽會疊在已經位移的筆畫上 —— 同一個位置，看不出來，不值得在這裡多算一次。
                    drawDragPreview = false,
                    objectCandidates = marqueeCandidatesLatest,
                    lockedObjectIds = lockedIdsLatest,
                    imageStore = imageStore,
                    textStore = textStore,
                    tableStore = tableStore,
                    chartStore = chartStore,
                    shapeStore = shapeStore,
                    onChanged = {
                        imageRevision++; textRevision++; tableRevision++; chartRevision++; shapeRevision++; revision++
                    },
                    modifier = Modifier.fillMaxSize().zIndex(260f)
                )
            }

            // 遮蔽膠帶覆蓋層（對齊 Apple MaskingTapeOverlayView）。
            com.kairumo.padnote.canvas.MaskingTapeOverlay(
                pageIndex = pageIndex,
                isActive = inkTool.isMaskingTape,
                tapeColor = runCatching { Color(android.graphics.Color.parseColor(inkColorHex)) }.getOrDefault(Color(0xFFFCEEAC)),
                currentInkHex = inkColorHex,
                tapes = maskingTapes,
                onTapesChanged = {
                    val session = notebook?.first
                    if (session != null) {
                        val meta = com.kairumo.padnote.library.NotebookMeta.load(session)
                        val otherPages = meta.tapes().filter { it.pageIndex != pageIndex }
                        meta.setTapes(session, otherPages + maskingTapes)
                        pageId?.let {
                            com.kairumo.padnote.canvas.NoteTapeCodec.writeEnvelopes(
                                session, it, maskingTapes.filter { t -> t.pageIndex == pageIndex })
                        }
                        AutoSync.noteLocalEdit(activity)
                    }
                    revision++
                },
                modifier = Modifier.fillMaxSize().zIndex(150f)
            )

            // 圖片疊在墨跡之上、文字方塊之下 —— 與 Apple 端的預設層級一致
            // （ObjectStacking.Kind.defaultLayer：image=0、text=6）。
            @Suppress("UNUSED_VARIABLE") val imageRevisionRead = imageRevision
            ImageLayer(
                zIndexOf = zIndexOf,
                images = imageStore.all,
                store = imageStore,
                density = canvasDensity,
                selectedId = selectedImageId,
                interactive = editorMode == EditorMode.TYPE || selectedImageId != null,
                onSelect = { id ->
                    selectedImageId = id
                    if (id != null && editorMode != EditorMode.TYPE) {
                        editorMode = EditorMode.TYPE
                    }
                },
                onEditStyle = { editingImage = it },
                onChanged = { imageStore.persist(it); imageRevision++ },
                modifier = Modifier.fillMaxSize()
            )

            // 文字方塊疊在墨跡之上 —— 與 Apple 端的疊放順序一致。
            @Suppress("UNUSED_VARIABLE") val textRevisionRead = textRevision
            TextBoxLayer(
                zIndexOf = zIndexOf,
                interactive = editorMode == EditorMode.TYPE || selectedTextId != null,
                boxes = textStore.all,
                density = canvasDensity,
                selectedId = selectedTextId,
                revision = textRevision,
                onSelect = { id ->
                    selectedTextId = id
                    if (id != null && editorMode != EditorMode.TYPE) {
                        editorMode = EditorMode.TYPE
                    }
                },
                onEditStyle = { editingText = it },
                inlineEditingId = com.kairumo.padnote.text.InlineTextEditing.activeId,
                onInlineEditStart = { id -> com.kairumo.padnote.text.InlineTextEditing.activeId = id },
                onInlineEditEnd = { box ->
                    if (com.kairumo.padnote.text.InlineTextEditing.activeId == box.id) com.kairumo.padnote.text.InlineTextEditing.activeId = null
                    if (box.text.isBlank() && editingText?.id != box.id) {
                        textStore.remove(box)
                        if (selectedTextId == box.id) selectedTextId = null
                        textRevision++
                    }
                },
                onChanged = { box -> textStore.persist(box); textRevision++ },
                onDelete = { box ->
                    textStore.remove(box)
                    if (selectedTextId == box.id) selectedTextId = null
                    if (editingText?.id == box.id) editingText = null
                    textRevision++
                },
                onMoved = { box, dx, dy ->
                    val session = notebook?.first
                    val handles = engine.coreHandles()
                    if (session != null && handles != null) {
                        val (_, pageId) = handles
                        val meta = NotebookMeta.load(session)
                        val anchors = meta.stickyAnchors()
                        val matched = anchors.filter { it.targetId == box.id && it.pageIndex == pageIndex }
                        if (matched.isNotEmpty()) {
                            var changedAny = false
                            for (anchor in matched) {
                                if (anchor.strokeIds.isNotEmpty()) {
                                    val newIds = runCatching {
                                        session.lassoTranslate(pageId, anchor.strokeIds, dx, dy)
                                    }.getOrNull()
                                    if (newIds != null) {
                                        anchor.strokeIds = newIds
                                        anchor.anchorOriginX += dx
                                        anchor.anchorOriginY += dy
                                        changedAny = true
                                    }
                                }
                            }
                            if (changedAny) {
                                meta.setStickyAnchors(session, anchors)
                                engine.load()
                                revision++
                                clearToken++
                            }
                        }
                    }
                },
                modifier = Modifier.fillMaxSize()
            )

            // 鎖定物件右上角的小鎖頭。兩種模式都畫；手寫模式下只顯示，入口是手指點物件。
            if (lockedIds.isNotEmpty()) {
                com.kairumo.padnote.canvas.LockBadges(
                    marqueeCandidates, lockedIds, l10n("object_locked"),
                    if (editorMode == EditorMode.TYPE) { id -> lockPromptId = if (lockPromptId == id) null else id } else null
                )
            }
            if (editorMode == EditorMode.TYPE && lockedIds.isNotEmpty()) {
                val promptFrame = lockPromptId?.let { id -> marqueeCandidates.firstOrNull { it.id == id } }
                if (promptFrame != null && promptFrame.id in lockedIds) {
                    com.kairumo.padnote.canvas.UnlockPrompt(promptFrame, l10n("object_unlock")) {
                        objectLock.setLocked(promptFrame.id, false)
                    }
                }
            }

            // 形狀與連接線。
            //
            // **不再用 `key(shapeRevision)` 整層重建。** 重建會把進行中的手勢拆掉 ——
            // 拖曳、縮放、拉線都是「每一幀存檔、每一幀換新物件」，整層重建的話
            // 手指還按著，接收手勢的節點已經不是原來那一個了。改成只讀版本號訂閱重組，
            // 手勢節點在重組之間保持不變（手勢區塊讀的是最新的物件，見 ShapeLayer）。
            @Suppress("UNUSED_VARIABLE") val shapeRevisionRead = shapeRevision
            ShapeLayer(
                zIndexOf = zIndexOf,
                interactive = editorMode == EditorMode.TYPE || selectedShapeIds.isNotEmpty() || selectedConnectionId != null,
                shapes = shapeStore.all,
                connections = shapeStore.allConnections,
                density = canvasDensity,
                selectedIds = selectedShapeIds,
                selectedConnectionId = selectedConnectionId,
                connectionDraft = connectionDraft,
                onSelect = { id ->
                    selectedConnectionId = null
                    // 選到群組裡的一個就整組選起來 —— 那正是群組的意義。
                    val mates = if (id == null) emptySet()
                                else ObjectLayer.groupMates(id, shapeStore.all)
                    selectedShapeIds =
                        if (selectedShapeIds.containsAll(mates) && mates.isNotEmpty()) {
                            selectedShapeIds - mates
                        } else {
                            selectedShapeIds + mates
                        }
                    if (selectedShapeIds.isNotEmpty() && editorMode != EditorMode.TYPE) {
                        editorMode = EditorMode.TYPE
                    }
                },
                onEdit = { shape ->
                    selectedShapeIds = setOf(shape.id)
                    selectedConnectionId = null
                    editingShape = shape
                },
                onDelete = { shape ->
                    shapeStore.remove(shape)
                    selectedShapeIds = selectedShapeIds - shape.id
                    if (editingShape?.id == shape.id) editingShape = null
                    shapeRevision++
                },
                onChanged = { updated ->
                    // 拖曳一個形狀時，同一組的其他成員要跟著走 ——
                    // 不跟的話，群組起來的流程圖一拖就散開了。
                    val previous = shapeStore.all.firstOrNull { it.id == updated.id }
                    val dx = updated.x - (previous?.x ?: updated.x)
                    val dy = updated.y - (previous?.y ?: updated.y)
                    shapeStore.persist(updated)
                    for (mate in ObjectLayer.groupMates(updated.id, shapeStore.all)) {
                        if (mate == updated.id) continue
                        shapeStore.all.firstOrNull { it.id == mate }?.let { other ->
                            shapeStore.persist(
                                other.copyShape().apply { x += dx; y += dy }
                            )
                        }
                    }
                    shapeRevision++
                },
                onSelectConnection = { id ->
                    selectedConnectionId = id
                    if (id != null) {
                        selectedShapeIds = emptySet()
                        if (editorMode != EditorMode.TYPE) editorMode = EditorMode.TYPE
                    }
                },
                onEditConnection = { link ->
                    selectedConnectionId = link.id
                    editingConnection = link
                },
                onDeleteConnection = { link ->
                    shapeStore.remove(link)
                    selectedConnectionId = null
                    shapeRevision++
                },
                onConnectDrag = { from, anchor, start, current, finished ->
                    if (!finished) {
                        connectionDraft = ConnectionDraft(start.x, start.y, current.x, current.y)
                    } else {
                        connectionDraft = null
                        val created = shapeStore.connectByDrag(from, anchor, current.x, current.y)
                        if (created != null) {
                            selectedShapeIds = emptySet()
                            selectedConnectionId = created.id
                            shapeRevision++
                        }
                    }
                },
                modifier = Modifier.fillMaxSize()
            )

            // 表格疊在文字方塊之上。
            @Suppress("UNUSED_VARIABLE") val tableRevisionRead = tableRevision
            TableLayer(
                zIndexOf = zIndexOf,
                interactive = editorMode == EditorMode.TYPE || selectedTableId != null,
                tables = tableStore.all,
                density = canvasDensity,
                selectedId = selectedTableId,
                onSelect = { id ->
                    selectedTableId = id
                    if (id != null && editorMode != EditorMode.TYPE) editorMode = EditorMode.TYPE
                },
                onEdit = { editingTable = it },
                onChanged = { table -> tableStore.persist(table); tableRevision++ },
                modifier = Modifier.fillMaxSize()
            )

            // 圖表疊在文字方塊之上 —— 與 Apple 端的疊放順序一致。
            @Suppress("UNUSED_VARIABLE") val chartRevisionRead = chartRevision
            ChartLayer(
                zIndexOf = zIndexOf,
                interactive = editorMode == EditorMode.TYPE || selectedChartId != null,
                charts = chartStore.all,
                density = canvasDensity,
                selectedId = selectedChartId,
                onSelect = { id ->
                    selectedChartId = id
                    if (id != null && editorMode != EditorMode.TYPE) editorMode = EditorMode.TYPE
                },
                onEdit = { editingChart = it },
                onChanged = { chart -> chartStore.persist(chart); chartRevision++ },
                modifier = Modifier.fillMaxSize()
            )

            // 3D 模型。位置與大小是頁面座標，與其他圖層同一套規則。
            key(linkRevision) {
                LinkLayer(
                    interactive = editorMode == EditorMode.TYPE,
                    links = links.filter { it.pageIndex == pageIndex },
                    density = canvasDensity,
                    selectedId = selectedLinkId,
                    onSelect = { selectedLinkId = it },
                    onOpen = { url ->
                        // 交給系統瀏覽器。在 App 裡開 WebView 的話，使用者
                        // 已經登入的 cookie 都不在，而那正是他點連結的理由。
                        runCatching {
                            activity.startActivity(
                                android.content.Intent(
                                    android.content.Intent.ACTION_VIEW,
                                    android.net.Uri.parse(url)
                                )
                            )
                        }
                    },
                    onEdit = { editingLink = it },
                    onDelete = { target ->
                        links = links.filter { it.id != target.id }.toMutableList()
                        meta.setLinks(notebook?.first, links)
                        selectedLinkId = null
                        linkRevision++
                    },
                    onChanged = { updated ->
                        links = links.map { if (it.id == updated.id) updated else it }
                            .toMutableList()
                        meta.setLinks(notebook?.first, links)
                        linkRevision++
                    },
                    zIndexOf = zIndexOf
                )
            }

            // 錄音卡片。疊在連結卡片之上 —— 與 Apple 端的預設層級一致。
            key(audioRevision) {
                AudioLayer(
                    interactive = true,
                    items = audioCards.filter { it.pageIndex == pageIndex },
                    density = canvasDensity,
                    audioDirectory = audioDirectory,
                    selectedId = selectedAudioId,
                    playingId = playingAudioId,
                    l = { key -> l10n(key) },
                    onSelect = { selectedAudioId = it },
                    onTogglePlay = { card ->
                        val file = audioDirectory?.let { java.io.File(it, card.fileName) }
                        playingAudioId = if (file == null) null else {
                            AudioPlayback.toggle(card.id, file) { playingAudioId = null }
                        }
                    },
                    onRename = { renamingAudio = it },
                    onDelete = { card ->
                        if (playingAudioId == card.id) { AudioPlayback.stop(); playingAudioId = null }
                        audioCards = audioCards.filter { it.id != card.id }.toMutableList()
                        meta.setAudioCards(notebook?.first, audioCards)
                        selectedAudioId = null
                        audioRevision++
                    },
                    onChanged = { updated ->
                        audioCards = audioCards.map { if (it.id == updated.id) updated else it }
                            .toMutableList()
                        meta.setAudioCards(notebook?.first, audioCards)
                        audioRevision++
                    },
                    onTranscribe = { card, language ->
                        scope.launch {
                            val file = audioDirectory?.let { java.io.File(it, card.fileName) }
                            if (file == null || !file.isFile) {
                                message = l10n("audio_file_missing")
                                return@launch
                            }
                            message = l10n("recognizing")
                            val outcome = withContext(Dispatchers.IO) {
                                com.kairumo.padnote.audio.AudioTranscriber.transcribe(activity, file, language)
                            }
                            // **每一種拿不到都要講清楚原因。** 混成一句
                            // 「轉錄失敗」的話，使用者會一直按重試，
                            // 而其中兩種重試一百次也一樣。
                            val text = when (outcome) {
                                is com.kairumo.padnote.audio.AudioTranscriber.Outcome.Text -> {
                                    // 翻譯失敗時文字是原文 —— 要說，不然使用者會以為「轉出文字語言」沒作用。
                                    outcome.translationError?.let {
                                        message = l10n("hw_asr_translate_failed").replace("%@", it)
                                    }
                                    outcome.value
                                }
                                com.kairumo.padnote.audio.AudioTranscriber.Outcome.ModelMissing -> {
                                    message = l10n("transcribe_needs_model")
                                    return@launch
                                }
                                com.kairumo.padnote.audio.AudioTranscriber.Outcome.EngineUnavailable -> {
                                    message = l10n("transcribe_engine_unavailable")
                                    return@launch
                                }
                                com.kairumo.padnote.audio.AudioTranscriber.Outcome.AudioUnreadable -> {
                                    message = l10n("transcribe_audio_unreadable")
                                    return@launch
                                }
                                com.kairumo.padnote.audio.AudioTranscriber.Outcome.NoSpeech -> {
                                    message = l10n("transcribe_no_speech")
                                    return@launch
                                }
                                is com.kairumo.padnote.audio.AudioTranscriber.Outcome.Failed -> {
                                    message = l10n("transcribe_failed").replace("%@", outcome.detail)
                                    return@launch
                                }
                            }
                            // 將語音轉錄出的文字作為「隨點即書」自然排版文字插入在錄音卡片下方，
                            // 無框線、無預設灰底，依可用寬度動態排版，並切換至打字模式進入編輯以供後續編修（與 Apple 端一致）。
                            val inset = com.kairumo.padnote.ink.PageGeometry.PRINTABLE_INSET
                            val pageWidth = com.kairumo.padnote.ink.PageGeometry.width
                            val pageHeight = com.kairumo.padnote.ink.PageGeometry.height
                            val startX = maxOf(inset, card.x)
                            val midX = pageWidth / 2f
                            val availWidth = if (startX < midX - 30f && (pageWidth - inset) > midX) {
                                maxOf(180f, midX - startX - 12f)
                            } else {
                                maxOf(180f, pageWidth - inset - startX)
                            }
                            val baseFontSize = 16f
                            val charsPerLine = maxOf(10f, availWidth / (baseFontSize * 1.1f))
                            val approxLines = text.split("\n").fold(0) { acc, line ->
                                acc + maxOf(1, kotlin.math.ceil(maxOf(1, line.length) / charsPerLine).toInt())
                            }
                            val approxHeight = maxOf(48f, 28f + approxLines * (baseFontSize * 1.4f))
                            val targetY = maxOf(inset, minOf(card.y + card.height + 16f, pageHeight - inset - approxHeight))

                            val newBox = textStore.create(startX, targetY)
                            newBox.text = text
                            newBox.fontSize = baseFontSize
                            newBox.width = availWidth
                            newBox.height = approxHeight
                            newBox.backgroundColorHex = "clear"
                            newBox.hasBorder = false
                            textStore.persist(newBox)
                            // 轉錄文字是標註：一定在筆跡上方（文字預設就在上方，這裡只清掉殘留的明確設定）。
                            if (newBox.id in meta.explicitUnderInkObjectIds(pageIndex)) {
                                meta.moveObjectsToInkPlane(notebook?.first, pageIndex,
                                    mapOf(newBox.id to com.kairumo.padnote.canvas.ObjectStacking.Kind.TEXT),
                                    uniffi.padnote_core.FfiInkPlane.ABOVE_INK)
                            }
                            val updatedOrder = com.kairumo.padnote.canvas.ObjectStacking.bringToFront(
                                setOf(newBox.id),
                                meta.objectOrder(pageIndex)
                            )
                            meta.setObjectOrder(notebook?.first, pageIndex, updatedOrder)
                            selectedTextId = newBox.id
                            editingText = newBox
                            editorMode = EditorMode.TYPE
                            stackRevision++
                            textRevision++
                            message = l10n("transcribe_success")
                        }
                    },
                    zIndexOf = zIndexOf
                )
            }

            // 框選層。只有在框選模式下才存在 —— 平常掛一層可命中的
            // 透明視圖，底下的物件就全部點不到了。
            if (marqueeActive && editorMode == EditorMode.TYPE) {
                MarqueeLayer(
                    // 依堆疊順序由下到上，點選時才拿得到最上面那一個。
                    // 鎖定在畫布上的物件不框：框選帶著它一起搬，就不叫鎖定了。
                    candidates = marqueeCandidates.filter { it.id !in lockedIds }
                        .sortedBy { hit -> stackOrder.indexOf(hit.id) },
                    density = canvasDensity,
                    selectedIds = marqueeSelection,
                    additive = marqueeAdditive,
                    onSelectionChange = { marqueeSelection = it },
                    onCommitMove = { dx, dy -> moveMarqueeSelection(dx, dy) }
                )
            }

            // 協同：別人正在編輯、打字的物件標上對方的顏色與名字（設計 §5）。
            if (collabActive) PeerSelectionLayer(marqueeCandidates, collaboration, deviceLanguageTag())

            key(model3DRevision) {
                Model3DLayer(
                    interactive = editorMode == EditorMode.TYPE,
                    models = models3D.filter { it.pageIndex == pageIndex },
                    density = canvasDensity,
                    selectedId = selectedModel3DId,
                    onSelect = { selectedModel3DId = it },
                    onEdit = { editingModel3D = it },
                    onChanged = { updated ->
                        models3D = models3D.map { if (it.id == updated.id) updated else it }
                            .toMutableList()
                        meta.setModels3D(notebook?.first, models3D)
                        model3DRevision++
                    },
                    zIndexOf = zIndexOf
                )
            }

            // 討論圖釘畫在最上層 —— 它是標記，被內容蓋住就失去意義。
            key(pinRevision) {
                CommentLayer(
                    pins = pins,
                    pageIndex = pageIndex,
                    interactive = editorMode == EditorMode.TYPE,
                    onOpen = { openPin = it },
                    onMoved = { meta.setCommentPins(notebook?.first, pins); pinRevision++ },
                    density = canvasDensity
                )
            }

            // 🌟 聲筆動態同步與波形卡拉 OK 高亮 (Audio-Ink Karaoke Sync)
            val audioPlaying = remember(revision) { AudioPlayback.playingId != null }
            if (audioPlaying && engine.strokes.isNotEmpty()) {
                val karaokePath = remember { androidx.compose.ui.graphics.Path() }
                androidx.compose.foundation.Canvas(
                    modifier = Modifier.fillMaxSize().zIndex(8_999f)
                ) {
                    val currentPos = AudioPlayback.currentPositionMs
                    val duration = maxOf(1, AudioPlayback.durationMs)
                    val progressRatio = (currentPos.toFloat() / duration.toFloat()).coerceIn(0f, 1f)
                    val activeIdx = ((engine.strokes.size - 1) * progressRatio).toInt().coerceIn(0, engine.strokes.size - 1)
                    val startIdx = maxOf(0, activeIdx - 1)
                    val endIdx = minOf(engine.strokes.size - 1, activeIdx + 1)
                    for (i in startIdx..endIdx) {
                        val stroke = engine.strokes[i]
                        val pts = stroke.points
                        if (pts.size >= 2) {
                            karaokePath.reset()
                            karaokePath.moveTo(pts.first().x * canvasDensity, pts.first().y * canvasDensity)
                            for (p in pts.drop(1)) {
                                karaokePath.lineTo(p.x * canvasDensity, p.y * canvasDensity)
                            }
                            drawPath(
                                path = karaokePath,
                                color = Color(0xFFFBBF24).copy(alpha = 0.55f),
                                style = androidx.compose.ui.graphics.drawscope.Stroke(width = 6.dp.toPx())
                            )
                        }
                    }
                }
            }

            // 構圖輔助線。畫在所有內容之上但**不吃觸控** —— 它是參考線，
            // 擋住筆的話等於把畫布鎖住。
            CompositionOverlay(
                goldenSpiral = goldenSpiral,
                ruleOfThirds = ruleOfThirds,
                modifier = Modifier.fillMaxSize().zIndex(9_000f)
            )

            // 🌟 專業鏡像對稱尺規視覺參考線（與 Apple 端對稱軸對齊）
            if (showSymmetryGuide && editorMode == EditorMode.DRAW) {
                androidx.compose.foundation.Canvas(
                    modifier = Modifier.fillMaxSize().zIndex(9_001f)
                ) {
                    val axisX = (PageGeometry.width * canvasDensity) / 2f
                    val strokeDash = androidx.compose.ui.graphics.PathEffect.dashPathEffect(floatArrayOf(12f, 12f))
                    drawLine(
                        color = Color(0xFF6366F1).copy(alpha = 0.65f),
                        start = Offset(axisX, 0f),
                        end = Offset(axisX, size.height),
                        strokeWidth = 2.dp.toPx(),
                        pathEffect = strokeDash
                    )
                }
            }

            // 🌟 筆跡磁吸對齊與幾何角度引導 (Smart Magnetic Snap Laser Guide)
            if (isMagneticSnapActive && editorMode == EditorMode.DRAW && magneticGuideActive) {
                androidx.compose.foundation.Canvas(
                    modifier = Modifier.fillMaxSize().zIndex(9_002f)
                ) {
                    val strokeDash = androidx.compose.ui.graphics.PathEffect.dashPathEffect(floatArrayOf(8f, 6f))
                    drawLine(
                        color = Color(0xFF06B6D4).copy(alpha = 0.85f),
                        start = Offset(magneticGuideStart.x * canvasDensity, magneticGuideStart.y * canvasDensity),
                        end = Offset(magneticGuideEnd.x * canvasDensity, magneticGuideEnd.y * canvasDensity),
                        strokeWidth = 1.5.dp.toPx(),
                        pathEffect = strokeDash
                    )
                }
            }

            // 點選位置貼上物件：不論手繪或打字模式，點一下頁面任意座標就將剪貼簿物件中心對齊貼在該處。
            if (isPlacingPasteObject && objectClipboard.isNotEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .zIndex(9_500f)
                        .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.04f))
                        .testTag("editor.object.paste.target_layer")
                        .pointerInput(pageIndex, objectClipboard) {
                            detectTapGestures { offset ->
                                val target = Offset(offset.x / canvasDensity, offset.y / canvasDensity)
                                pasteSinglePageClipboard(target)
                            }
                        }
                )
            }

            if (showRefineBar) {
                // 讀一下 revision，按鈕的 enabled 才會跟著美化結果更新。
                @Suppress("UNUSED_EXPRESSION") refineRevision
                SketchRefineBar(
                    languageTag = deviceLanguageTag(),
                    canRestore = engine.canRestoreSketch(),
                    canRedo = engine.canRedoRefine(),
                    onApply = { intensity ->
                        val n = engine.refineSketch(intensity)
                        refineRevision++
                        revision++       // 畫布重繪
                        clearToken++     // 低延遲路徑的前緩衝也要清，否則舊筆畫還留在畫面上
                        message = if (n > 0) l10n("apply_refine") else l10n("nothing_to_refine")
                    },
                    onRestore = {
                        engine.restoreSketch(); refineRevision++; revision++; clearToken++
                    },
                    onRedo = {
                        engine.redoRefine(); refineRevision++; revision++; clearToken++
                    },
                    onDismiss = { showRefineBar = false },
                    modifier = Modifier.align(Alignment.BottomCenter)
                )
            }

            // 極簡懸浮點 (Floating Tool Pill) — 極簡畫布模式下顯示
            if (minimalistCanvasMode) {
                FloatingToolPill(
                    isExpanded = floatingPillExpanded,
                    currentToolName = l10n(inkTool.labelKey),
                    currentColorHex = inkColorHex,
                    languageTag = deviceLanguageTag(),
                    onToggleExpand = { floatingPillExpanded = !floatingPillExpanded },
                    onExitMinimalMode = {
                        minimalistCanvasMode = false
                        floatingPillExpanded = false
                    },
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(start = 8.dp, top = 8.dp)
                ) {
                    // 展開後的快速工具槽
                    androidx.compose.foundation.layout.Column(
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        InkToolbar(
                            tool = inkTool,
                            colorHex = inkColorHex,
                            width = inkWidth,
                            languageTag = deviceLanguageTag(),
                            onToolChange = { picked -> applyInkTool(picked) },
                            onColorChange = { hex ->
                                inkColorHex = hex
                                engine.colorRgba = hexToRgba(hex)
                            },
                            onWidthChange = { value ->
                                inkWidth = value
                                engine.baseWidth = value
                            },
                            onOpenColorWheel = { showProColorWheel = true }
                        )
                    }
                }
            }
        }
        }

            // 套索的快顯動作列：浮在選取框上方（放不下就放下方），畫面座標 ——
            // 選取框是頁面點，乘 density、縮放再加捲動。工具列不跟著頁面縮放，按鈕維持原尺寸。
            // 與 Apple 的 lassoSelectionDecoration 一致。
            //
            // 它、貼上鈕與飛梭工具盤都必須在縮放層（上面那個 graphicsLayer）**外面**。原本寫在裡面：
            // 位置被再縮放、平移一次而偏掉，飛梭盤被放大，還被 clip 裁掉、壓到底部工具列的
            // 那幾格按不到（模擬器上實測）。
            val lassoBox = lasso.boundingRect
            if (inkTool.isLasso && lassoBox != null) {
                LassoActionBar(
                    lasso = lasso,
                    engine = engine,
                    l = { key -> l10n(key) },
                    onChanged = { revision++ },
                    onRecognizeToText = {
                        val selIds = lasso.selected.toSet()
                        val strokes = engine.strokes.filter { it.coreStrokeId in selIds && it.points.isNotEmpty() }
                        if (strokes.isEmpty()) {
                            // 原本什麼都不做：按了沒反應，使用者不知道是沒圈到還是壞了。
                            message = l10n("lasso_recognize_select_first")
                        } else {
                            message = l10n("recognizing")
                            scope.launch {
                                val language = deviceLanguageTag()
                                // 先把整組圈選當成一份筆跡辨識（與 iPad 一致）：依書寫停頓分組會把
                                // 寫到一半停一下的同一個字（例如「林」的兩個木）拆成兩組，各自都認不出來。
                                var failure: Throwable? = null
                                val whole = Handwriting.recognize(strokes.map { it.points }, language)
                                var finalStr = whole.getOrNull().orEmpty().trim()
                                whole.exceptionOrNull()?.let { failure = it }
                                if (finalStr.isEmpty() && failure == null) {
                                    val recognized = StringBuilder()
                                    val groups = Handwriting.group(
                                        strokeIds = strokes.map { it.coreStrokeId ?: "" },
                                        strokes = strokes.map { it.points },
                                        strokeTimesMs = strokes.map { it.startedAtMs }
                                    )
                                    for (group in groups) {
                                        val res = Handwriting.recognize(group.strokes, language)
                                        res.exceptionOrNull()?.let { failure = it }
                                        val txt = res.getOrNull().orEmpty()
                                        if (txt.isNotBlank()) recognized.append(txt).append("\n")
                                    }
                                    finalStr = recognized.toString().trim()
                                }
                                if (finalStr.isNotEmpty()) {
                                    // 原地轉換（與 iPad 一致）：文字方塊放在原本筆跡的位置、沿用筆色，圈選的筆跡換成文字。
                                    val points = strokes.flatMap { it.points }
                                    val pad = 8f
                                    val minX = points.minOf { it.x }
                                    val minY = points.minOf { it.y }
                                    val maxX = points.maxOf { it.x }
                                    val maxY = points.maxOf { it.y }
                                    val box = textStore.create(maxOf(0f, minX - pad), maxOf(0f, minY - pad))
                                    box.text = finalStr
                                    box.width = maxOf(120f, maxX - minX + pad * 2)
                                    box.height = maxOf(44f, maxY - minY + pad * 2)
                                    box.fontSize = ((maxY - minY) * 0.7f).coerceIn(16f, 32f)
                                    val rgba = strokes.last().colorRgba
                                    box.textColorHex = String.format(
                                        "#%02X%02X%02X",
                                        rgba[0].toInt() and 0xFF, rgba[1].toInt() and 0xFF, rgba[2].toInt() and 0xFF
                                    )
                                    box.backgroundColorHex = "#FFFFFF"
                                    box.hasBorder = false
                                    textStore.persist(box)
                                    // 等待辨識期間選取可能已被清掉：那就保留原筆跡，只加文字。
                                    if (lasso.selected.toSet() == selIds && lasso.delete(engine)) revision++
                                    selectedTextId = box.id
                                    textRevision++
                                    message = l10n("lasso_recognize_done")
                                } else {
                                    message = failure?.let { err ->
                                        (err as? Handwriting.HandwritingError)?.let {
                                            Handwriting.describe(it.failure, language)
                                        } ?: err.message
                                    } ?: l10n("lasso_recognize_none")
                                }
                            }
                        }
                    },
                    onAnchorToText = {
                        val session = notebook?.first
                        val handles = engine.coreHandles()
                        val pageBoxes = textStore.all.filter { it.pageIndex == pageIndex }
                        val targetBox = pageBoxes.firstOrNull()
                        if (session != null && handles != null && targetBox != null) {
                            val (_, pageId) = handles
                            var selIds = lasso.selected
                            if (selIds.isEmpty()) {
                                val poly = listOf(
                                    targetBox.x - 10f, targetBox.y - 10f,
                                    targetBox.x + targetBox.width + 10f, targetBox.y - 10f,
                                    targetBox.x + targetBox.width + 10f, targetBox.y + targetBox.height + 10f,
                                    targetBox.x - 10f, targetBox.y + targetBox.height + 10f
                                )
                                selIds = runCatching { session.lassoSelect(pageId, poly) }.getOrDefault(emptyList())
                            }
                            if (selIds.isNotEmpty()) {
                                val meta = NotebookMeta.load(session)
                                val anchors = meta.stickyAnchors()
                                anchors.removeAll { it.targetId == targetBox.id }
                                anchors.add(
                                    com.kairumo.padnote.library.StickyAnnotationAnchor(
                                        pageIndex = pageIndex,
                                        targetId = targetBox.id,
                                        strokeIds = selIds,
                                        anchorOriginX = targetBox.x,
                                        anchorOriginY = targetBox.y
                                    )
                                )
                                meta.setStickyAnchors(session, anchors)
                                lasso.clear()
                                revision++
                                clearToken++
                                message = l10n("sticky_anchored_hint")
                            } else {
                                message = l10n("sticky_anchor_ink")
                            }
                        }
                    },
                    modifier = Modifier
                        .zIndex(9_000f)
                        .lassoBarPlacement(
                            box = lassoBox,
                            density = canvasDensity,
                            scale = canvasScale,
                            offset = canvasOffset,
                            gapPx = 12f * canvasDensity
                        )
                        .padding(horizontal = 8.dp)
                )
            }
            // 沒有選取、剪貼簿有筆跡時的「貼上」入口（剪下之後就靠它貼回去）。
            if (inkTool.isLasso) {
                LassoPastePill(
                    lasso = lasso,
                    engine = engine,
                    l = { key -> l10n(key) },
                    onChanged = { revision++ },
                    modifier = Modifier.zIndex(9_000f).align(Alignment.TopCenter).padding(top = 12.dp)
                )
            }
            // 物件剪貼簿與選取的浮動工具丸（支援手繪／打字兩種模式與跨頁貼上／點選位置貼上）。
            val activeSingleObjectIds = currentSelectedObjectIds()
            if (activeSingleObjectIds.isNotEmpty() || objectClipboard.isNotEmpty()) {
                com.kairumo.padnote.canvas.ObjectPastePill(
                    hasSelection = activeSingleObjectIds.isNotEmpty(),
                    hasClipboard = objectClipboard.isNotEmpty(),
                    isPlacingPaste = isPlacingPasteObject,
                    l = { key -> l10n(key) },
                    onCut = { activeSingleObjectIds.firstOrNull()?.let { objectClipboardActions.cut(it) } },
                    onCopy = { activeSingleObjectIds.firstOrNull()?.let { objectClipboardActions.copy(it) } },
                    onPasteDefault = { pasteSinglePageClipboard(null) },
                    onStartPlacePaste = { isPlacingPasteObject = true },
                    onCancelPlacePaste = { isPlacingPasteObject = false },
                    onClearClipboard = { objectClipboard = emptyList(); isPlacingPasteObject = false },
                    modifier = Modifier
                        .zIndex(9_100f)
                        .align(Alignment.TopCenter)
                        .padding(top = if (inkTool.isLasso && lasso.canPaste) 56.dp else 12.dp)
                )
            }

            if (showRadialMenu) {
                com.kairumo.padnote.ui.EditorRadialMenu(radialMenuCenter, l10n, radialAction)
            }

            // 放置討論圖釘：點哪裡就放哪裡（與 Apple 端同一個模式）。
            //
            // 疊在最上面，只在放置模式時存在 —— 常駐的話它會把畫布的
            // 觸控全部吃掉，筆就畫不了了。
            if (isPlacingCommentPin) {
                Box(
                    modifier = Modifier
                        .matchParentSize()
                        .testTag("editor.comment_pin.placing")
                        .pointerInput(pageIndex) {
                            detectTapGestures { offset ->
                                val profile = AccountManager.load(
                                    activity, l10n("default_user_name"))
                                val pin = CommentPin(
                                    id = java.util.UUID.randomUUID().toString(),
                                    pageIndex = pageIndex,
                                    x = offset.x / canvasDensity,
                                    y = offset.y / canvasDensity,
                                    authorId = deviceId(activity).toString(),
                                    authorName = profile.displayName,
                                    authorColor = profile.colorHex,
                                    createdAt = java.util.Date(),
                                    isResolved = false,
                                    messages = mutableListOf()
                                )
                                pins = (pins + pin).toMutableList()
                                meta.setCommentPins(notebook?.first, pins)
                                pinRevision++
                                openPin = pin
                                isPlacingCommentPin = false
                                editorMode = EditorMode.TYPE
                            }
                        }
                )
            }

        }
        }
        if (sideToolbar && toolbarPlacement == uniffi.padnote_core.FfiPlacement.RIGHT) {
            androidx.compose.foundation.layout.Column(
                modifier = Modifier
                    .width(110.dp)
                    .fillMaxHeight()
                    .verticalScroll(rememberScrollState())
            ) { RenderInkBar(inkBarState) }
        }
        }

        // 四個「按下去之後還要再做一個動作」的功能，第一次用時給一則提示
        // （使用者回報：不知道該怎麼操作）。內容與 id 都來自核心，
        // 與 Apple 端同一份 —— 鍵不一樣的話，在一台裝置上關掉的提示會在
        // 另一台冒出來。
        com.kairumo.padnote.ui.FeatureHintHost(
            activity, "hint.comment_pin", isPlacingCommentPin, deviceLanguageTag())
        com.kairumo.padnote.ui.FeatureHintHost(
            activity, "hint.refine_sketch", showRefineBar, deviceLanguageTag())
        com.kairumo.padnote.ui.FeatureHintHost(
            activity, "hint.tabletop", isTabletopManual, deviceLanguageTag())
        com.kairumo.padnote.ui.FeatureHintHost(
            activity, "hint.recognize", isRecognisingHandwriting, deviceLanguageTag())
        }

        // 工具列在「下」：要放在 `EditorWorkArea` **外面**（Column 的下一個子項）。
        // 原本它在畫布的 RowScope 裡，成了畫布的**橫向**兄弟，`fillMaxWidth` 把畫布擠成
        // 寬度 0 —— 預設就是「下」，所以新安裝的 Android 一打開畫布整個不見。
        if (effectiveToolbarMode == EditorMode.DRAW &&
            toolbarPlacement == uniffi.padnote_core.FfiPlacement.BOTTOM
        ) {
            RenderInkBar(inkBarState)
        }

        // 次世代 UI/UX Phase 5: 折疊立起雙屏創作工作盤 (Tabletop Studio Control Deck)
        if (isTabletopActive) {
            HorizontalDivider()
            TabletopControlDeck(
                l10n = { key -> l10n(key) },
                currentTool = inkTool,
                onPickTool = { applyInkTool(it) },
                isMagneticSnapActive = isMagneticSnapActive,
                onToggleMagneticSnap = { isMagneticSnapActive = !isMagneticSnapActive },
                onOpenRadial = {
                    radialMenuCenter = Offset(
                        if (canvasViewport.width > 0) canvasViewport.width / 2f else 300f,
                        if (canvasViewport.height > 0) canvasViewport.height / 2f else 300f
                    )
                    showRadialMenu = true
                },
                onAnchorSticky = {
                    val session = notebook?.first
                    val handles = engine.coreHandles()
                    val pageBoxes = textStore.all.filter { it.pageIndex == pageIndex }
                    val target = pageBoxes.firstOrNull()
                    if (session != null && handles != null && target != null) {
                        val (_, pageId) = handles
                        var strokeIds: List<String> = lasso.selected
                        if (strokeIds.isEmpty()) {
                            val poly = listOf(
                                target.x - 10f, target.y - 10f,
                                target.x + target.width + 10f, target.y - 10f,
                                target.x + target.width + 10f, target.y + target.height + 10f,
                                target.x - 10f, target.y + target.height + 10f
                            )
                            strokeIds = runCatching { session.lassoSelect(pageId, poly) }.getOrDefault(emptyList())
                        }
                        if (strokeIds.isNotEmpty()) {
                            val meta = NotebookMeta.load(session)
                            val anchors = meta.stickyAnchors().toMutableList()
                            anchors.removeAll { it.targetId == target.id }
                            anchors.add(
                                StickyAnnotationAnchor(
                                    pageIndex = pageIndex,
                                    targetId = target.id,
                                    strokeIds = strokeIds,
                                    anchorOriginX = target.x,
                                    anchorOriginY = target.y
                                )
                            )
                            meta.setStickyAnchors(session, anchors)
                            lasso.clear()
                            revision++
                            clearToken++
                            message = l10n("sticky_anchored_hint")
                        } else {
                            message = l10n("sticky_anchor_ink")
                        }
                    }
                },
                onUndo = { globalUndo() },
                onRedo = { globalRedo() },
                onAddPage = {
                    val s = notebook?.first
                    if (s != null) {
                        runCatching { s.addPage(uniffi.padnote_core.PageStyle.BLANK) }
                        pageCount = runCatching { s.pageCount().toInt() }.getOrDefault(pageCount + 1)
                        pageIndex = pageCount - 1
                        revision++
                        continuousContentRevision++
                        continuousScrollRequest++
                    }
                },
                onColorPick = { hex -> engine.colorRgba = hexToRgba(hex) },
                onExitTabletop = { isTabletopManual = false },
                modifier = Modifier.fillMaxWidth().weight(0.42f)
            )
        }
}

// ────────────────────────────── 折疊創作工作盤 ──────────────────────────────

/**
 * 次世代 UI/UX Phase 5: 折疊立起雙屏創作工作盤 (Tabletop Studio Control Deck)。
 *
 * 當折疊機處於半折立起 (Tabletop / Flex Mode) 或使用者手動開啟雙視窗時，
 * 上半部為完整畫布與文件預覽區，下半部為高效率觸控創作工作盤。
 */
@Composable
internal fun TabletopControlDeck(
    l10n: (String) -> String,
    currentTool: InkTool,
    onPickTool: (InkTool) -> Unit,
    isMagneticSnapActive: Boolean,
    onToggleMagneticSnap: () -> Unit,
    onOpenRadial: () -> Unit,
    onAnchorSticky: () -> Unit,
    onUndo: () -> Unit,
    onRedo: () -> Unit,
    onAddPage: () -> Unit,
    onColorPick: (String) -> Unit,
    onExitTabletop: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier,
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        shape = RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp)
    ) {
        Column(
            modifier = Modifier.fillMaxSize().padding(horizontal = 14.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // 頂部狀態列與功能按鈕
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "⧉ ${l10n("posture_tabletop_mode")}",
                    style = MaterialTheme.typography.titleSmall,
                    color = MaterialTheme.colorScheme.primary
                )
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    IconButton(onClick = onUndo, modifier = Modifier.size(32.dp)) {
                        Text("↶", fontSize = 16.sp)
                    }
                    IconButton(onClick = onRedo, modifier = Modifier.size(32.dp)) {
                        Text("↷", fontSize = 16.sp)
                    }
                    IconButton(onClick = onAddPage, modifier = Modifier.size(32.dp)) {
                        Text("+", fontSize = 18.sp, color = MaterialTheme.colorScheme.primary)
                    }
                    IconButton(onClick = onExitTabletop, modifier = Modifier.size(32.dp)) {
                        Text("✕", fontSize = 13.sp)
                    }
                }
            }

            // 常用筆刷工具組
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                FilterChip(
                    selected = currentTool == InkTool.FOUNTAIN_PEN,
                    onClick = { onPickTool(InkTool.FOUNTAIN_PEN) },
                    label = { Text(l10n("tool_pen"), maxLines = 1) },
                    modifier = Modifier.weight(1f)
                )
                FilterChip(
                    selected = currentTool == InkTool.HIGHLIGHTER,
                    onClick = { onPickTool(InkTool.HIGHLIGHTER) },
                    label = { Text(l10n("tool_highlighter"), maxLines = 1) },
                    modifier = Modifier.weight(1f)
                )
                FilterChip(
                    selected = currentTool == InkTool.ERASER,
                    onClick = { onPickTool(InkTool.ERASER) },
                    label = { Text(l10n("tool_eraser"), maxLines = 1) },
                    modifier = Modifier.weight(1f)
                )
                FilterChip(
                    selected = currentTool == InkTool.LASSO,
                    onClick = { onPickTool(InkTool.LASSO) },
                    label = { Text(l10n("tool_lasso"), maxLines = 1) },
                    modifier = Modifier.weight(1f)
                )
            }

            // 次世代功能輔助鍵：Radial Menu / 磁吸 / 錨定
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                OutlinedButton(
                    onClick = onOpenRadial,
                    modifier = Modifier.weight(1f),
                    contentPadding = PaddingValues(horizontal = 4.dp, vertical = 2.dp)
                ) {
                    Text("◎ ${l10n("tool_radial_short")}", fontSize = 11.sp, maxLines = 1)
                }

                OutlinedButton(
                    onClick = onToggleMagneticSnap,
                    modifier = Modifier.weight(1.2f),
                    contentPadding = PaddingValues(horizontal = 4.dp, vertical = 2.dp)
                ) {
                    Text(
                        text = if (isMagneticSnapActive) "🧲 Snap ON" else "🧲 Snap",
                        fontSize = 11.sp,
                        color = if (isMagneticSnapActive) MaterialTheme.colorScheme.primary else Color.Unspecified,
                        maxLines = 1
                    )
                }

                OutlinedButton(
                    onClick = onAnchorSticky,
                    modifier = Modifier.weight(1f),
                    contentPadding = PaddingValues(horizontal = 4.dp, vertical = 2.dp)
                ) {
                    Text("🔗 ${l10n("tool_anchor_short")}", fontSize = 11.sp, maxLines = 1)
                }
            }

            // 常用色彩圓點
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically
            ) {
                val colorList = listOf(
                    "#000000" to Color.Black,
                    "#1E40AF" to Color(0xFF1E40AF),
                    "#DC2626" to Color(0xFFDC2626),
                    "#16A34A" to Color(0xFF16A34A),
                    "#D97706" to Color(0xFFD97706),
                    "#7C3AED" to Color(0xFF7C3AED)
                )
                colorList.forEach { (hex, color) ->
                    Box(
                        modifier = Modifier
                            .size(28.dp)
                            .clip(CircleShape)
                            .background(color)
                            .border(1.dp, Color.White.copy(alpha = 0.5f), CircleShape)
                            .clickable { onColorPick(hex) }
                    )
                }
            }
        }
    }
}

// ────────────────────────────── 空間繪圖與圖紙輔助 ──────────────────────────────

/**
 * 把立體輔助排好的圖紙放在「目前看得到的範圍正中央」（不是固定貼頂，那會壓在既有的圖上），
 * 回傳插入的核心筆畫 id 與選取框（像素）。
 *
 * 獨立成頂層函式：寫在 `InkScreen` 的 lambda 裡會讓 Compose 編譯器對這個巨大的函式
 * 產出驗證不過的位元碼（啟動即 `VerifyError`）。
 *
 * 畫布的 graphicsLayer 以中心為軸縮放，所以畫面中心對應的頁面點是
 * 中心 − 平移 / 縮放，再除以 density 換成頁面單位。
 */
internal fun placeSolidSheet(
    engine: com.kairumo.padnote.ink.InkEngine,
    sheet: uniffi.padnote_core.FfiSolidSheet,
    viewport: Size,
    scale: Float,
    offset: Offset,
    density: Float
): Pair<List<String>, List<Offset>> {
    val cx = (viewport.width / 2f - offset.x / scale) / density
    val cy = (viewport.height / 2f - offset.y / scale) / density
    val ox = (cx - sheet.width / 2f).coerceIn(0f, maxOf(0f, PageGeometry.width - sheet.width))
    val oy = (cy - sheet.height / 2f).coerceIn(0f, maxOf(0f, PageGeometry.height - sheet.height))
    engine.insertDrafted(sheet.strokes, ox, oy)
    val l = (ox - 8f) * density
    val t = (oy - 8f) * density
    val r = (ox + sheet.width + 8f) * density
    val b = (oy + sheet.height + 8f) * density
    return engine.lastInsertedCoreIds to listOf(Offset(l, t), Offset(r, t), Offset(r, b), Offset(l, b))
}

/**
 * 把一組製圖符號放在「目前看得到的範圍正中央」（同 [placeSolidSheet]：整組一次復原），
 * 回傳插入的核心筆畫 id 與選取框（像素）。沒有任何筆畫回 null。
 */
internal fun placeDraftKit(
    engine: com.kairumo.padnote.ink.InkEngine,
    kit: uniffi.padnote_core.FfiDraftKit,
    viewport: Size,
    scale: Float,
    offset: Offset,
    density: Float
): Pair<List<String>, List<Offset>>? {
    val cx = (viewport.width / 2f - offset.x / scale) / density
    val cy = (viewport.height / 2f - offset.y / scale) / density
    val box = com.kairumo.padnote.ink.draftKitPlacement(kit, cx, cy, PageGeometry.width, PageGeometry.height) ?: return null
    engine.insertDrafted(kit.strokes, box[0], box[1])
    // 選取框：符號的包圍盒（頁面單位）→ 像素。
    val pts = kit.strokes.flatMap { it.points }
    val l = (pts.minOf { it.x } + box[0] - 8f) * density
    val t = (pts.minOf { it.y } + box[1] - 8f) * density
    val r = (pts.maxOf { it.x } + box[0] + 8f) * density
    val b = (pts.maxOf { it.y } + box[1] + 8f) * density
    return engine.lastInsertedCoreIds to listOf(Offset(l, t), Offset(r, t), Offset(r, b), Offset(l, b))
}

/** 匯出本頁的製圖線（SVG／DXF）並開分享表；沒有任何線回 false（頂層函式：避免在巨大的 InkScreen 裡放大 lambda）。 */
internal fun exportDraftingPage(ctx: android.content.Context, engine: com.kairumo.padnote.ink.InkEngine, format: String): Boolean =
    com.kairumo.padnote.ink.DraftingExport.sharePage(ctx, engine, format, PageGeometry.width, PageGeometry.height)

/** 再出同一題型的一題。 */
internal fun PracticeSession_next(engine: com.kairumo.padnote.ink.InkEngine) {
    val kind = com.kairumo.padnote.ink.PracticeSession.problem?.kind ?: return
    startPractice(engine, kind)
}

/** 開始一題練習：把題目線放進目前這一頁（頂層函式：避免在巨大的 InkScreen 裡放大 lambda）。 */
internal fun startPractice(engine: com.kairumo.padnote.ink.InkEngine, kind: String) {
    com.kairumo.padnote.ink.PracticeSession.start(kind, null, engine, PageGeometry.width, PageGeometry.height)
}

/** 把套索選的那批線帶進編輯工具；沒選到回 false（頂層函式：避免在巨大的 InkScreen 裡放大 lambda）。 */
internal fun captureEditSelection(lasso: com.kairumo.padnote.canvas.LassoSelection): Boolean {
    DraftingState.editSelection = lasso.selected
    return lasso.selected.isNotEmpty()
}

internal fun applyRectArrayToSelection(
    engine: com.kairumo.padnote.ink.InkEngine, lasso: com.kairumo.padnote.canvas.LassoSelection,
    rows: Int, cols: Int, dxMm: Double, dyMm: Double
) {
    DraftingState.editSelection = lasso.selected
    com.kairumo.padnote.ink.DraftEditController.applyRectArray(rows, cols, dxMm, dyMm, engine)
}

/** 把量角器讀到的角度畫成一條線（從圓心到外緣），一次復原（頂層函式：避免在巨大的 InkScreen 裡放大 lambda）。 */
internal fun markProtractorReading(engine: com.kairumo.padnote.ink.InkEngine) {
    val (a, b) = DraftingState.instrument?.readingRay ?: return
    val pen = DraftingState.activePen
    val layer = DraftingState.activeLayerId
    if (DraftingState.isLocked(layer)) return
    DraftingState.ensureVisible(layer)
    engine.insertDrafted(
        listOf(uniffi.padnote_core.FfiSheetStroke(
            listOf(uniffi.padnote_core.FfiPoint(a.x, a.y), uniffi.padnote_core.FfiPoint(b.x, b.y)),
            layer.toUByte(), DraftingState.activeLineType.toUByte(), pen.width, pen.colorHex)),
        0f, 0f)
}

/** 把尺規放在目前看得到的範圍正中央（頂層函式：避免在巨大的 InkScreen 裡放大 lambda）。 */
internal fun placeDraftInstrument(kind: String, viewport: Size, scale: Float, offset: Offset, density: Float) {
    val cx = (viewport.width / 2f - offset.x / scale) / density
    val cy = (viewport.height / 2f - offset.y / scale) / density
    DraftingState.placeInstrument(kind, cx, cy, PageGeometry.width)
}

/** 目前頁面的紙張規格識別字（A4／A3…）；自訂尺寸或認不得的回 null。 */
internal fun currentPaperId(): String? =
    uniffi.padnote_core.pageFormats().firstOrNull {
        kotlin.math.abs(it.width - PageGeometry.width) < 0.5f && kotlin.math.abs(it.height - PageGeometry.height) < 0.5f
    }?.id

/** 畫布目前的視窗大小、縮放與平移（給「放在畫面正中央」用）。 */
internal class CanvasViewInfo {
    var viewport: Size = Size.Zero
    var scale: Float = 1f
    var offset: Offset = Offset.Zero
}
