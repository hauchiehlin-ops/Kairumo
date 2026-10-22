package com.kairumo.padnote.canvas

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.zIndex
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import com.kairumo.padnote.chart.ChartLayer
import com.kairumo.padnote.chart.ChartStore
import com.kairumo.padnote.image.ImageLayer
import com.kairumo.padnote.image.ImageStore
import com.kairumo.padnote.ink.InkCanvas
import com.kairumo.padnote.ink.InkEngine
import com.kairumo.padnote.ink.PageGeometry
import com.kairumo.padnote.library.NotebookMeta
import com.kairumo.padnote.shape.ConnectionDraft
import com.kairumo.padnote.shape.ConnectionEditDialog
import com.kairumo.padnote.shape.NoteConnection
import com.kairumo.padnote.shape.NoteShape
import com.kairumo.padnote.shape.ShapeEditDialog
import com.kairumo.padnote.shape.ShapeLayer
import com.kairumo.padnote.shape.ShapeStore
import com.kairumo.padnote.table.TableLayer
import com.kairumo.padnote.table.TableStore
import com.kairumo.padnote.chart.ChartObject
import com.kairumo.padnote.chart.ChartStudio
import com.kairumo.padnote.image.ImageEditor
import com.kairumo.padnote.image.NoteImage
import com.kairumo.padnote.table.NoteTable
import com.kairumo.padnote.table.TableEditor
import com.kairumo.padnote.text.TextBox
import com.kairumo.padnote.text.TextBoxEditor
import com.kairumo.padnote.text.TextBoxLayer
import com.kairumo.padnote.ui.LocalAppLanguage
import com.kairumo.padnote.text.TextBoxStore
import uniffi.padnote_core.PadnoteSession
import uniffi.padnote_core.ToolKind
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.withFrameNanos
import androidx.compose.foundation.gestures.calculatePan
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.PointerType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.util.VelocityTracker
import com.kairumo.padnote.ink.PalmThresholdStore
import com.kairumo.padnote.ink.PenSettingsStore
import kotlin.math.pow
import kotlinx.coroutines.launch

/**
 * 頁面顯示模式。與 Apple 的 `PageDisplayMode` 是同一組值 ——
 * 這個選擇會被記住，兩邊的字串一樣才不會互相看不懂。
 */
enum class PageDisplayMode(val wire: String) {
    /** 一次一頁，用上一頁／下一頁切換（預設）。 */
    SINGLE("single"),

    /** 所有頁面接續排列，一路往下捲。 */
    CONTINUOUS("continuous");

    companion object {
        fun fromWire(value: String?, isTablet: Boolean = false): PageDisplayMode =
            entries.firstOrNull { it.wire == value } ?: if (isTablet) CONTINUOUS else SINGLE
    }
}

/** 這一次手寫用的筆設定。一起傳比逐項傳清楚，而且不會漏掉其中一項。 */
data class InkSettings(
    val tool: ToolKind,
    val colorRgba: ByteArray,
    val baseWidth: Float,
    val isErasing: Boolean,
    val penOnly: Boolean
) {
    // data class 帶陣列欄位時自動產生的 equals 比的是參照，
    // 會讓 remember(settings) 每次重組都認為「變了」。手動比內容。
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is InkSettings) return false
        return tool == other.tool &&
            colorRgba.contentEquals(other.colorRgba) &&
            baseWidth == other.baseWidth &&
            isErasing == other.isErasing &&
            penOnly == other.penOnly
    }

    override fun hashCode(): Int =
        listOf(tool, colorRgba.contentHashCode(), baseWidth, isErasing, penOnly).hashCode()
}

/**
 * 連續頁面模式（Android）。
 *
 * # 為什麼是「加一棵視圖樹」而不是改造原本的畫布
 *
 * 整頁模式那條路（單一 `InkEngine` ＋ `pageIndex`）綁著存檔、物件層、
 * 掌拒與模式切換，是這個編輯器最沒有本錢壞掉的一段。所以這裡**完全不動它** ——
 * 連續模式是另一棵樹，共用同一組元件（`InkCanvas`、各個 Layer）。
 * 與 Apple 端 `ContinuousPagesView` 的取捨相同。
 *
 * # 每一頁自己一個引擎與一組 store
 *
 * 共用一個 `InkEngine` 的話，在第 7 頁寫的筆畫會被寫進第 1 頁的檔案裡 ——
 * 那是資料損毀，不是顯示問題。
 *
 * # 焦點頁
 *
 * 畫面中央的那一頁就是焦點頁。插入物件要落在使用者**正在看**的那一頁，
 * 不是他上次按過上一頁／下一頁的那一頁。焦點變動會回報給外層，
 * 外層的 `pageIndex` 跟著走，所以選單裡的插入動作自然落在對的頁。
 *
 * # 捲動與手寫的分工：**這一點與 Apple 端不同**
 *
 * Apple 的連續模式是「手指畫畫、兩指捲動」。Android 做不到同一套：
 * `LazyColumn` 的捲動手勢在觸控滑動超過 touch slop 時就把事件攔走，
 * 底下的畫布只收得到前幾個點 —— 結果是手指既畫不出東西、又只能捲動。
 *
 * 試過「偵測到筆就關掉 userScrollEnabled」：**沒有用**。重組要等到下一幀，
 * 而捲動手勢在那之前就已經接手了；筆畫完全畫不出來。
 *
 * 現在的做法是把判定交回核心的輸入仲裁器：連續模式下每一頁的引擎一律
 * **pen-only**。筆 → 仲裁器判為墨跡，畫布吃掉事件；手指 → 判為手勢，
 * 畫布回傳 false，`LazyColumn` 照常捲動。不需要跟捲動容器搶事件。
 *
 * 代價寫清楚：**連續模式下手指畫不出東西**，沒有觸控筆的裝置要畫就切回
 * 整頁模式（整頁模式的手指仍然可以畫，那條路一行都沒有改）。
 *
 * # 其他已知限制（與 Apple 端一致）
 *
 * - 頁面只縮不放：放大到超過原尺寸會讓筆跡變糊。
 */
@Composable
fun ContinuousPagesView(
    session: PadnoteSession?,
    meta: NotebookMeta,
    pageCount: Int,
    focusIndex: Int,
    onFocusChange: (Int) -> Unit,
    ink: InkSettings,
    editorMode: EditorMode,
    onModeChange: (EditorMode) -> Unit = {},
    /** 外層插入物件之後 bump，讓對應的頁重新讀 store。 */
    reloadToken: Int,
    /** 遞增就代表「再捲到目前頁一次」（點了目前這一頁的縮圖：頁碼沒變，但要回到頁頂）。 */
    scrollRequest: Int = 0,
    /** 套索模式時的選取（null = 不是套索模式）。所有頁面共用一份，選取屬於哪一頁見 `lassoPageId`。 */
    lasso: LassoSelection? = null,
    /** 外層工具列的復原／重做按鈕接到這裡（見 `ContinuousUndoController`）。 */
    undoController: ContinuousUndoController? = null,
    /** 即時協同讀寫每一頁的引擎與物件（見 `ContinuousCollabBridge`）。 */
    collabBridge: com.kairumo.padnote.collab.ContinuousCollabBridge? = null,
    modifier: Modifier = Modifier,
    /**
     * 飛梭工具盤的中心（null = 沒開）。疊在整個清單上面，與 `modifier` 收到的長按同一套座標
     * （長按掛在 `modifier` 上，見 `radialHoldArea`）。
     */
    radialMenuCenter: Offset? = null,
    /** 飛梭工具盤的動作（項目 id，或 `RADIAL_DISMISS`）。 */
    onRadialAction: (String) -> Unit = {}
) {
    val listState = rememberLazyListState()
    /** 套索選取屬於哪一頁。只有那一頁畫圈、選取框與工具列，動作也只作用在那一頁的引擎。 */
    var lassoPageId by remember(session) { mutableStateOf<String?>(null) }

    LaunchedEffect(meta) {
        com.kairumo.padnote.ink.PageGeometry.use(meta.pageFormatId())
    }

    // ── 復原／重做 ─────────────────────────────────────────────
    //
    // 原本連續模式**完全沒有復原**：外層的鈕只認單頁模式的那一個引擎。
    // 這裡比照單頁模式：筆跡與物件同一條時間軸，而且**跨頁** ——
    // 在第 3 頁畫一筆、到第 5 頁搬一張圖，復原先回第 5 頁、再回第 3 頁。
    //
    // 每一頁的引擎與物件放在這裡的快取，不放在清單項目裡：捲出畫面的頁面會被
    // `LazyColumn` 拆掉，引擎裡的復原紀錄跟著消失，回頭復原那一頁的筆畫就退錯東西。
    // 重開 session（別台同步進來）會換一份新的快取。舊的那份留一個參照：新頁面的引擎先借舊引擎的筆畫
    // 當畫面，背景讀完再換成套件的內容 —— 不然每一頁都會白一下（見 InkEngine.seedDisplayFrom）。
    val runtimeContext = androidx.compose.ui.platform.LocalContext.current
    val previousRuntimes = remember { arrayOfNulls<HashMap<String, PageRuntime>>(1) }
    val runtimes = remember(session) {
        HashMap<String, PageRuntime>().also { fresh ->
            val old = previousRuntimes[0]
            previousRuntimes[0] = fresh
            if (old != null) {
                for ((id, runtime) in old) {
                    if (id.isEmpty()) continue
                    fresh[id] = PageRuntime(session, id, runtimeContext).also { it.engine.seedDisplayFrom(runtime.engine) }
                }
            }
        }
    }
    val history = remember(session, pageCount) { CanvasHistory() }
    val currentFocus by androidx.compose.runtime.rememberUpdatedState(focusIndex)
    val currentOnFocusChange by androidx.compose.runtime.rememberUpdatedState(onFocusChange)
    fun pageIdAt(index: Int): String =
        runCatching { session?.pageIdAt(index.toUInt()) }.getOrNull() ?: ""
    fun indexOfPage(id: String): Int? = (0 until maxOf(1, pageCount)).firstOrNull { pageIdAt(it) == id }
    /** 復原到別頁的步驟時把那一頁捲到眼前 —— 不然使用者按了復原卻看不到哪裡變了。 */
    fun reveal(page: String) {
        val index = indexOfPage(page) ?: return
        if (index != currentFocus) currentOnFocusChange(index)
    }

    // Ctrl+X／C／V（對齊 Apple 的 ⌘V）：作用在選取所屬的頁，沒有就是焦點頁。
    LaunchedEffect(lasso, runtimes) {
        val selection = lasso ?: return@LaunchedEffect
        com.kairumo.padnote.ui.AppCommands.events.collect { command ->
            val target = lassoPageId ?: pageIdAt(currentFocus)
            val rt = runtimes[target] ?: return@collect
            val changed = when (command) {
                com.kairumo.padnote.ui.AppCommand.Cut -> selection.cut(rt.engine)
                com.kairumo.padnote.ui.AppCommand.Copy -> selection.copy(rt.engine)
                com.kairumo.padnote.ui.AppCommand.Paste -> selection.paste(rt.engine)
                else -> return@collect
            }
            if (changed) {
                lassoPageId = target
                rt.bump()
                collabBridge?.onLocalChange?.invoke()
            }
        }
    }
    DisposableEffect(collabBridge, runtimes, history) {
        val bridge = collabBridge
        if (bridge != null) {
            bridge.engineFor = { id -> runtimes[id]?.takeIf { it.inkLoaded }?.engine }
            bridge.storesFor = { id ->
                runtimes[id]?.let {
                    com.kairumo.padnote.collab.CollabPageStores(
                        it.textStore, it.imageStore, it.tableStore, it.chartStore, it.shapeStore)
                }
            }
            bridge.loadedPages = { runtimes.keys.filter { it.isNotEmpty() } }
            bridge.remoteApplied = {
                for ((id, runtime) in runtimes) {
                    val index = indexOfPage(id) ?: continue
                    // 別人的修改不是這台的復原步驟：以寫回後的內容為新基準，再重畫。
                    history.reset(runtime.snapshot(meta, index), id)
                    runtime.bump()
                }
            }
        }
        onDispose {
            bridge?.engineFor = { null }
            bridge?.storesFor = { null }
            bridge?.loadedPages = { emptyList() }
            bridge?.remoteApplied = {}
        }
    }
    DisposableEffect(undoController, history) {
        undoController?.undoHandler = {
            val did = history.undoAcrossPages(
                applyObjects = { page, snapshot ->
                    runtimes[page]?.restore(snapshot, meta, session, indexOfPage(page))
                    reveal(page)
                },
                undoInk = { page ->
                    val rt = runtimes[page]
                    val undone = rt?.engine?.undo() == true
                    if (undone) { rt?.bump(); reveal(page) }
                    undone
                }
            )
            // 這次開啟之後還沒做過任何事：與單頁模式相同，收回焦點頁檔案裡的最後一筆。
            did || runtimes[pageIdAt(currentFocus)]?.let { rt -> rt.engine.undo().also { if (it) rt.bump() } } == true
        }
        undoController?.redoHandler = {
            val did = history.redoAcrossPages(
                applyObjects = { page, snapshot ->
                    runtimes[page]?.restore(snapshot, meta, session, indexOfPage(page))
                    reveal(page)
                },
                redoInk = { page ->
                    val rt = runtimes[page]
                    val redone = rt?.engine?.redo() == true
                    if (redone) { rt?.bump(); reveal(page) }
                    redone
                }
            )
            did || runtimes[pageIdAt(currentFocus)]?.let { rt -> rt.engine.redo().also { if (it) rt.bump() } } == true
        }
        onDispose {
            undoController?.undoHandler = null
            undoController?.redoHandler = null
        }
    }
    val density = LocalDensity.current.density
    val scope = rememberCoroutineScope()
    val context = androidx.compose.ui.platform.LocalContext.current


    // 畫面中央最近的那一頁 = 焦點頁。用 layoutInfo 而不是
    // firstVisibleItemIndex：後者在頁面比視窗高時永遠是同一個值，
    // 捲過半頁焦點也不會變。
    // 外層改了頁碼（按了上一頁／下一頁、新增頁面）就捲過去。
    //
    // 記住「最後一次由捲動回報出去的頁碼」，只有在外層的值與它不同時才捲 ——
    // 不這樣分的話，捲動→回報→外層更新→再捲回去，會自己跟自己打架。
    var lastReported by remember { mutableIntStateOf(-1) }
    // 程式捲動進行中。這段時間內捲動「途中」經過的頁面不算焦點。
    //
    // 原本沒有這個旗標：點縮圖從第 12 頁跳到第 9 頁，動畫才開始，途中第 11 頁
    // 經過視窗中央 → 回報焦點 → 外層 `focusIndex` 變成 11 → 這個 LaunchedEffect
    // 因為 key 變了被取消，**動畫在半路被砍掉**，使用者看到畫面停在第 11 頁附近。
    // 點縮圖「時而跳得到、時而停在半路」就是這個。
    var programmaticScroll by remember { mutableStateOf(false) }
    var lastRequest by remember { mutableIntStateOf(scrollRequest) }
    LaunchedEffect(focusIndex, scrollRequest) {
        val requested = scrollRequest != lastRequest
        lastRequest = scrollRequest
        if (focusIndex != lastReported || requested) {
            val target = focusIndex.coerceAtLeast(0)
            programmaticScroll = true
            try {
                listState.animateScrollToItem(target)
            } finally {
                programmaticScroll = false
            }
            lastReported = target
        }
    }

    LaunchedEffect(listState) {
        snapshotFlow {
            val info = listState.layoutInfo
            val center = (info.viewportStartOffset + info.viewportEndOffset) / 2
            info.visibleItemsInfo.minByOrNull { item ->
                kotlin.math.abs(item.offset + item.size / 2 - center)
            }?.index
        }.collect { index ->
            if (index != null && index != lastReported && !programmaticScroll) {
                lastReported = index
                onFocusChange(index)
            }
        }
    }

    BoxWithConstraints(modifier) {
        // 頁面是固定的 800 × 1132（P-01），視窗不是。縮到剛好放得下 ——
        // 不縮的話頁面右半邊會被切掉，而使用者看不出那是「超出去」
        // 還是「畫布壞了」。視窗比紙張寬時反過來放大填滿（上限 2 倍，
        // 與 Apple 的 `PageViewportLayout.maxFitScale` 同一個數字），
        // 否則兩側留下的灰邊看起來像畫布被框住。
        val available = (maxWidth.value - 32f).coerceAtLeast(1f)
        val scale = minOf(MAX_FIT_SCALE, available / PageGeometry.width)
        var momentumJob by remember { mutableStateOf<kotlinx.coroutines.Job?>(null) }

        LazyColumn(
            state = listState,
            userScrollEnabled = editorMode != EditorMode.DRAW,
            modifier = Modifier
                .fillMaxSize()
                .pointerInput(editorMode, ink.penOnly) {
                    if (editorMode != EditorMode.DRAW) return@pointerInput
                    val canFingerDraw = !ink.penOnly
                    awaitPointerEventScope {
                        while (true) {
                            val first = awaitPointerEvent(PointerEventPass.Initial)
                            val pressedChanges = first.changes.filter { it.pressed }
                            val hasStylus = pressedChanges.any { it.type == PointerType.Stylus }
                            val fingerChanges = pressedChanges.filter { it.type != PointerType.Stylus }
                            val fingerCount = fingerChanges.size

                            // 繪圖模式下：觸控筆始終直接繪圖；手指可繪圖時僅在 2 指以上攔截捲動；僅限觸控筆時手指 1 指即可捲動
                            val shouldIntercept = !hasStylus && (
                                (canFingerDraw && fingerCount >= 2) ||
                                (!canFingerDraw && fingerCount >= 1)
                            )

                            if (!shouldIntercept) continue

                            momentumJob?.cancel()

                            // 手勢接管前取消所有頁面進行中的未完成筆畫，避免雙指觸控時在畫布留下誤觸墨點
                            runtimes.values.forEach { rt ->
                                if (rt.engine.isDrawing) {
                                    rt.engine.cancelInFlight()
                                    rt.bump()
                                }
                            }

                            val startPointers = fingerCount
                            var maxPointers = fingerCount
                            var totalPanY = 0f
                            val velocityTracker = VelocityTracker()

                            first.changes.forEach { change ->
                                if (change.pressed) {
                                    change.consume()
                                    velocityTracker.addPosition(change.uptimeMillis, change.position)
                                }
                            }

                            var event = first
                            while (event.changes.any { it.pressed }) {
                                val currentFingers = event.changes.count { it.pressed && it.type != PointerType.Stylus }
                                maxPointers = maxOf(maxPointers, currentFingers)

                                val panChange = event.calculatePan()
                                totalPanY += panChange.y
                                if (panChange.y != 0f) {
                                    listState.dispatchRawDelta(-panChange.y)
                                }

                                event.changes.forEach { change ->
                                    if (change.pressed) {
                                        change.consume()
                                        velocityTracker.addPosition(change.uptimeMillis, change.position)
                                    }
                                }
                                event = awaitPointerEvent(PointerEventPass.Initial)
                            }

                            val isTap = kotlin.math.abs(totalPanY) < 24.dp.toPx()
                            if (isTap && startPointers >= 2) {
                                // 對齊 Apple：雙指點擊＝復原，三指點擊＝重做
                                when (maxPointers) {
                                    2 -> undoController?.undoHandler?.invoke()
                                    3 -> undoController?.redoHandler?.invoke()
                                }
                            } else {
                                // 慣性減速：採用與 Apple TwoFingerScrollForwarder 一致的 pow(0.998, dt * 1000) 衰減曲線
                                val velocity = velocityTracker.calculateVelocity().y
                                if (kotlin.math.abs(velocity) > 80f) {
                                    momentumJob = scope.launch {
                                        var vel = velocity
                                        var lastTime = System.nanoTime()
                                        while (kotlin.math.abs(vel) > 20f) {
                                            withFrameNanos { now ->
                                                val dt = minOf((now - lastTime) / 1_000_000_000f, 0.05f)
                                                lastTime = now
                                                vel *= 0.998.pow((dt * 1000f).toDouble()).toFloat()
                                                listState.dispatchRawDelta(-vel * dt)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                },
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = 20.dp)
        ) {
            items(maxOf(1, pageCount)) { index ->
                Box(Modifier.scaledPage(scale)) {
                    key(index) {
                        val pageId = remember(session, index, pageCount) { pageIdAt(index) }
                        ContinuousPage(
                            session = session,
                            meta = meta,
                            runtime = runtimes.getOrPut(pageId) { PageRuntime(session, pageId.ifEmpty { null }, context) },
                            history = history,
                            pageIndex = index,
                            isFocused = index == focusIndex,
                            lasso = lasso,
                            ownsLasso = lasso != null && lassoPageId == pageId,
                            onLassoClaim = {
                                // 在別頁圈下去：先把選取清掉（索引對的是那一頁的筆畫），焦點跟過來。
                                if (lassoPageId != pageId) {
                                    lasso?.clear()
                                    lassoPageId = pageId
                                }
                                if (index != currentFocus) currentOnFocusChange(index)
                            },
                            pageScale = scale,
                            ink = ink,
                            editorMode = editorMode,
                            onModeChange = onModeChange,
                            density = density,
                            reloadToken = reloadToken,
                            collabBridge = collabBridge
                        )
                    }
                }
            }
        }

        // 套索模式、沒有選取、剪貼簿有筆跡時的「貼上」入口：貼到選取所屬的頁，沒有就貼到焦點頁。
        if (lasso != null && editorMode == EditorMode.DRAW) {
            val target = lassoPageId ?: pageIdAt(focusIndex)
            runtimes[target]?.let { rt ->
                LassoPastePill(
                    lasso = lasso,
                    engine = rt.engine,
                    l = { key -> com.kairumo.padnote.LocalizationStrings.localized(key, com.kairumo.padnote.currentLanguageTag()) },
                    onChanged = {
                        lassoPageId = target
                        rt.bump()
                        collabBridge?.onLocalChange?.invoke()
                    },
                    modifier = Modifier.align(Alignment.TopCenter).padding(top = 12.dp).zIndex(10f)
                )
            }
        }

        // 可拖曳的捲軸（工作項 S-63）。與 Apple 端同一個理由：系統的捲動
        // 指示器是純顯示的，接鍵鼠的平板／Chromebook／DeX 上拖不動；
        // 而且長筆記需要一個「還有多長」的位置感。
        val info = listState.layoutInfo
        val viewport = (info.viewportEndOffset - info.viewportStartOffset).toFloat()
        val itemSpan = info.visibleItemsInfo.firstOrNull()?.size?.toFloat() ?: 0f
        val total = itemSpan * maxOf(1, pageCount)
        if (total > 0f && viewport > 0f) {
            val scrolled = listState.firstVisibleItemIndex * itemSpan +
                listState.firstVisibleItemScrollOffset
            val scrollable = (total - viewport).coerceAtLeast(1f)
            CanvasScrollbar(
                visibleFraction = (viewport / total).coerceIn(0f, 1f),
                scrollFraction = (scrolled / scrollable).coerceIn(0f, 1f),
                modifier = Modifier
                    .align(Alignment.CenterEnd)
                    .padding(end = 4.dp, top = 10.dp, bottom = 10.dp)
            ) { fraction ->
                val targetPx = fraction * scrollable
                val index = (targetPx / itemSpan).toInt().coerceIn(0, maxOf(0, pageCount - 1))
                val offset = (targetPx - index * itemSpan).toInt().coerceAtLeast(0)
                scope.launch { listState.scrollToItem(index, offset) }
            }
        }

        radialMenuCenter?.let { center ->
            com.kairumo.padnote.ui.EditorRadialMenu(
                center,
                { key -> com.kairumo.padnote.LocalizationStrings.localized(key, com.kairumo.padnote.currentLanguageTag()) },
                onRadialAction
            )
        }
    }
}


/** 自動貼合寬度時的放大上限；與 Apple `PageViewportLayout.maxFitScale` 一致。 */
private const val MAX_FIT_SCALE = 2f

/**
 * 把固定 800 × 1132 的頁面縮進捲動列表的一格。
 *
 * # 為什麼要自訂 layout 而不是「外層小 Box + 內層 requiredSize + graphicsLayer」
 *
 * 那個寫法踩過雷：內層用 `requiredSize` 撐到 800 之後，它**比外層大**，
 * 於是被 Box 依對齊方式擺放 —— 在置中的清單裡就被推到 x = (視窗 − 800) / 2，
 * 也就是螢幕左邊外面；再以自己的左上角為原點縮小，結果整頁只剩右下一小塊
 * 露在畫面上。量出來的尺寸還是對的（288×408），所以看數字完全看不出問題。
 *
 * 這裡把兩件事合成一個節點：**量的時候給整頁大小，回報的時候回報縮小後的
 * 大小**。父層看到的就是 288×408，沒有任何溢出，也就沒有對齊的問題。
 */
private fun Modifier.scaledPage(scale: Float): Modifier = this
    .layout { measurable, _ ->
        val w = (PageGeometry.width * density).toInt()
        val h = (PageGeometry.height * density).toInt()
        val placeable = measurable.measure(Constraints.fixed(w, h))
        // 縮放後的實際大小要讓出來，否則每一頁之間會留下
        // (1 - scale) × 1132 的空白，看起來像頁與頁之間破了一個洞。
        layout((w * scale).toInt(), (h * scale).toInt()) { placeable.place(0, 0) }
    }
    .graphicsLayer(
        scaleX = scale,
        scaleY = scale,
        transformOrigin = TransformOrigin(0f, 0f)
    )

@Composable
private fun ContinuousPage(
    session: PadnoteSession?,
    meta: NotebookMeta,
    runtime: PageRuntime,
    history: CanvasHistory,
    pageIndex: Int,
    isFocused: Boolean,
    lasso: LassoSelection?,
    ownsLasso: Boolean,
    onLassoClaim: () -> Unit,
    pageScale: Float,
    ink: InkSettings,
    editorMode: EditorMode,
    onModeChange: (EditorMode) -> Unit,
    density: Float,
    reloadToken: Int,
    collabBridge: com.kairumo.padnote.collab.ContinuousCollabBridge?
) {
    val pageId = runtime.pageId
    val historyKey = pageId ?: ""

    // 每一頁自己一個引擎。共用的話會把筆畫寫進別頁的檔案裡。
    // 引擎與物件都在 `runtime`（ContinuousPagesView 的快取）：捲出畫面再捲回來，復原紀錄還在。
    val engine = runtime.engine
    engine.tool = ink.tool
    engine.colorRgba = ink.colorRgba
    engine.baseWidth = ink.baseWidth
    engine.isErasing = ink.isErasing
    // 遵循使用者的 pen-only 設定（預設為 false，支援手指與筆；若使用者開啟僅限觸控筆則為 true）。
    LaunchedEffect(engine, ink.penOnly) {
        engine.setPenOnly(ink.penOnly)
        // 讀回這一頁已經存在的筆畫。見 InkEngine.load() 的說明。
        // **只讀一次**：引擎留在快取裡，再讀一次會把它的復原紀錄清掉。
        if (!runtime.inkLoaded) {
            engine.loadAsync()
            runtime.inkLoaded = true
            runtime.bump()
        }
    }
    DisposableEffect(engine, collabBridge) {
        val previous = engine.onContentCommitted
        engine.onContentCommitted = { previous?.invoke(); collabBridge?.onLocalChange?.invoke() }
        onDispose { engine.onContentCommitted = previous }
    }
    DisposableEffect(engine, history) {
        engine.onUndoableAction = { history.inkCommitted(historyKey) }
        onDispose { engine.onUndoableAction = null }
    }

    val textStore = runtime.textStore
    val shapeStore = runtime.shapeStore
    val tableStore = runtime.tableStore
    val chartStore = runtime.chartStore
    val imageStore = runtime.imageStore
    var revision by runtime.revision

    // reloadToken 讓外層插入物件之後這一頁看得到新東西 ——
    // 不重讀的話，從選單插進去的文字方塊要等切換頁面才會出現。
    LaunchedEffect(session, pageId, reloadToken) {
        textStore.load()
        shapeStore.load()
        tableStore.load()
        chartStore.load()
        imageStore.load()
        // 第一次讀進來是基準，不是「新增了所有物件」；之後外層插入的物件才算一步。
        val loaded = runtime.snapshot(meta, pageIndex)
        if (history.hasBaseline(historyKey)) history.observe(loaded, historyKey) else history.reset(loaded, historyKey)
        revision++
    }
    // 物件有動（各個 onChanged 都會遞增 revision）就比對一次；筆跡的變動比對不出差異，不會多記一步。
    LaunchedEffect(revision) {
        if (runtime.isRestoring) {
            runtime.isRestoring = false
            history.reset(runtime.snapshot(meta, pageIndex), historyKey)
            return@LaunchedEffect
        }
        if (history.hasBaseline(historyKey)) history.observe(runtime.snapshot(meta, pageIndex), historyKey)
        collabBridge?.onLocalChange?.invoke()
    }

    val order = remember(revision, pageIndex) { meta.objectOrder(pageIndex) }
    val kindOf = remember(revision, pageIndex) {
        buildMap {
            imageStore.all.forEach { put(it.id, ObjectStacking.Kind.IMAGE) }
            shapeStore.all.forEach { put(it.id, ObjectStacking.Kind.SHAPE) }
            tableStore.all.forEach { put(it.id, ObjectStacking.Kind.TABLE) }
            chartStore.all.forEach { put(it.id, ObjectStacking.Kind.CHART) }
            textStore.all.forEach { put(it.id, ObjectStacking.Kind.TEXT) }
        }
    }
    val underInkIds = remember(meta, pageIndex, revision) {
        meta.underInkObjectIds(pageIndex)
    }
    val zIndexOf: (String) -> Float = { id ->
        val baseZ = ObjectStacking.zIndex(id, kindOf[id] ?: ObjectStacking.Kind.TEXT, order)
        if (underInkIds.contains(id)) 10f + baseZ else 200f + baseZ
    }

    val interactive = editorMode == EditorMode.TYPE
    val lockedIds = remember(meta, revision) { meta.lockedObjectIds() }

    // 這一頁的選取（單選，圖片／表格／圖表／文字／形狀共用一個 id —— id 在整頁內唯一）。
    var selectedId by remember(pageId) { mutableStateOf<String?>(null) }
    var selectedConnectionId by remember(pageId) { mutableStateOf<String?>(null) }
    var connectionDraft by remember(pageId) { mutableStateOf<ConnectionDraft?>(null) }
    var editingImage by remember(pageId) { mutableStateOf<NoteImage?>(null) }
    var editingShape by remember(pageId) { mutableStateOf<NoteShape?>(null) }
    var editingConnection by remember(pageId) { mutableStateOf<NoteConnection?>(null) }
    var editingTable by remember(pageId) { mutableStateOf<NoteTable?>(null) }
    var editingChart by remember(pageId) { mutableStateOf<ChartObject?>(null) }
    var editingText by remember(pageId) { mutableStateOf<TextBox?>(null) }
    /** 正在顯示「解除鎖定」鈕的鎖定物件。 */
    var lockPromptId by remember(pageId) { mutableStateOf<String?>(null) }
    /** 這一頁物件的位置與大小（鎖頭、解除鎖定鈕、點擊判定用），由下到上排。 */
    val lockFrames = remember(revision, order) {
        buildList {
            imageStore.all.forEach { add(MarqueeHit(it.id, it.x, it.y, it.width, it.height)) }
            shapeStore.all.forEach { add(MarqueeHit(it.id, it.x, it.y, it.width, it.height)) }
            tableStore.all.forEach { add(MarqueeHit(it.id, it.x, it.y, it.width, it.layout().height.toFloat())) }
            chartStore.all.forEach { add(MarqueeHit(it.id, it.x, it.y, it.width, it.height)) }
            textStore.all.forEach { add(MarqueeHit(it.id, it.x, it.y, it.width, it.height)) }
        }.sortedBy { order.indexOf(it.id) }
    }
    val lockFramesLatest by androidx.compose.runtime.rememberUpdatedState(lockFrames)
    val lockedIdsLatest by androidx.compose.runtime.rememberUpdatedState(lockedIds)
    val objectLock = remember(meta, pageIndex) {
        com.kairumo.padnote.canvas.ObjectLockActions(
            isLocked = { id -> id in meta.lockedObjectIds() },
            setLocked = { id, locked ->
                meta.setObjectLocked(session, pageIndex, id, locked)
                if (locked && selectedId == id) selectedId = null
                if (lockPromptId == id) lockPromptId = null
                revision++
            }
        )
    }
    // 切到手寫模式時清掉選取 —— 手寫模式下物件不吃觸控，留著把手只會擋住筆。
    LaunchedEffect(editorMode) {
        if (editorMode != EditorMode.TYPE) { selectedId = null; selectedConnectionId = null }
    }

    // **新插入的物件一律放在最上層**（理由與基準的算法見 MainActivity 裡同一段）。
    var knownObjectIds by remember(pageId) { mutableStateOf<Set<String>?>(null) }
    val currentItems = buildList {
        imageStore.all.forEach { add(ObjectStacking.Item(it.id, ObjectStacking.Kind.IMAGE, "")) }
        shapeStore.all.forEach { add(ObjectStacking.Item(it.id, ObjectStacking.Kind.SHAPE, "")) }
        tableStore.all.forEach { add(ObjectStacking.Item(it.id, ObjectStacking.Kind.TABLE, "")) }
        chartStore.all.forEach { add(ObjectStacking.Item(it.id, ObjectStacking.Kind.CHART, "")) }
        textStore.all.forEach { add(ObjectStacking.Item(it.id, ObjectStacking.Kind.TEXT, "")) }
    }
    val latestItems by androidx.compose.runtime.rememberUpdatedState(currentItems)
    LaunchedEffect(pageId) {
        kotlinx.coroutines.delay(1000)
        knownObjectIds = latestItems.map { it.id }.toSet()
    }
    LaunchedEffect(revision, knownObjectIds) {
        val known = knownObjectIds ?: return@LaunchedEffect
        val fresh = latestItems.map { it.id }.filter { it !in known }
        if (fresh.isEmpty()) return@LaunchedEffect
        knownObjectIds = known + fresh
        val freshSet = fresh.toSet()
        meta.setObjectOrder(
            session, pageIndex,
            ObjectStacking.withNewOnTop(
                latestItems.filter { it.id !in freshSet }, meta.objectOrder(pageIndex), fresh)
        )
        revision++
    }

    val currentInkColor = remember(ink) {
        if (ink.colorRgba.size >= 4) {
            Color(
                (ink.colorRgba[0].toInt() and 0xFF) / 255f,
                (ink.colorRgba[1].toInt() and 0xFF) / 255f,
                (ink.colorRgba[2].toInt() and 0xFF) / 255f,
                (ink.colorRgba[3].toInt() and 0xFF) / 255f
            )
        } else Color.Black
    }

    val pageStyle = remember(pageId, revision) {
        runCatching {
            session?.pageStyle(pageId ?: return@runCatching null)
        }.getOrNull() ?: uniffi.padnote_core.PageStyle.BLANK
    }
    val paperId = remember(meta, pageIndex, revision) { meta.paperId(pageIndex) }
    val guidePaletteId = remember(meta) { meta.paletteId() }
    val guideMeasurer = androidx.compose.ui.text.rememberTextMeasurer()

    Box(
        Modifier
            .fillMaxSize()
            .background(Color.White)
            .border(
                if (isFocused) 1.5.dp else 1.dp,
                // 焦點頁描一圈，使用者才知道現在插入的東西會落在哪一頁。
                if (isFocused) MaterialTheme.colorScheme.primary.copy(alpha = 0.45f)
                else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.18f)
            )
            // 手寫模式下手指點鎖定的物件：切到打字模式並給「解除鎖定」鈕（見 ObjectLock.kt）。
            .fingerTapOnLockedObject(
                listOf(editorMode, lasso != null),
                hitAt = { p ->
                    if (editorMode != EditorMode.DRAW || lasso != null) null
                    else lockedObjectHit(p.x / density, p.y / density, lockFramesLatest, lockedIdsLatest)
                },
                onCancelInk = { engine.cancelInFlight(); revision++ },
                onTap = { id ->
                    onModeChange(EditorMode.TYPE)
                    lockPromptId = id
                }
            )
            .then(
                if (editorMode == EditorMode.TYPE) {
                    Modifier.pointerInput(pageIndex) {
                        detectTapGestures { offset: Offset ->
                            val tapX = offset.x / density
                            val tapY = offset.y / density
                            // 點到鎖定的物件：給「解除鎖定」鈕，不開新文字方塊（見 ObjectLock.kt）。
                            val lockedHit = lockedObjectHit(tapX, tapY, lockFramesLatest, lockedIdsLatest)
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
                                selectedId = hitExisting.id
                                editingText = hitExisting
                            } else {
                                val newBox = textStore.create(
                                    x = maxOf(20f, minOf(tapX, 700f)),
                                    y = maxOf(20f, minOf(tapY, 1000f))
                                )
                                val currentOrder = meta.objectOrder(pageIndex)
                                val updatedOrder = com.kairumo.padnote.canvas.ObjectStacking.bringToFront(setOf(newBox.id), currentOrder)
                                meta.setObjectOrder(session, pageIndex, updatedOrder)
                                revision++
                                selectedId = newBox.id
                                editingText = newBox
                            }
                        }
                    }
                } else {
                    Modifier
                }
            )
    ) {
        InkCanvas(
            engine = engine,
            modifier = Modifier.fillMaxSize().zIndex(100f),
            backgroundColor = Color.Transparent,
            pageStyle = pageStyle,
            paperId = paperId,
            guidePaletteId = guidePaletteId,
            localizeGuide = { key -> com.kairumo.padnote.LocalizationStrings.localized(key, com.kairumo.padnote.currentLanguageTag()) },
            guideMeasurer = guideMeasurer,
            inkColor = currentInkColor,
            onInkChanged = { revision++ },
            onStylusDetected = {
                // 全自動意圖感知：偵測到 Stylus 觸控筆下筆時，自動平滑切換回 DRAW 手繪模式
                if (editorMode != EditorMode.DRAW) {
                    onModeChange(EditorMode.DRAW)
                }
            },
            contentVersion = revision,
            acceptsInk = editorMode == EditorMode.DRAW,
            // 選取只屬於一頁：只有那一頁把選中的筆畫畫在拖曳後的位置。
            lassoDrag = { if (ownsLasso) lasso?.dragPreview() else null }
        )

        // 選取與編輯。
        //
        // **連續模式原本完全沒有選取** —— 每一層都收到 `selectedId = null`、`onSelect = {}`，
        // 物件選不起來，把手與編輯鈕就永遠不會出現（使用者看到的是「編輯鈕沒有作用」，
        // 其實是根本沒有那顆鈕）。單頁模式有的選取、編輯面板、層級調整，這裡一樣要有。
        CompositionLocalProvider(
            com.kairumo.padnote.canvas.LocalObjectReorder provides { id, op ->
                when (op) {
                    com.kairumo.padnote.canvas.ObjectStacking.Reorder.SEND_BELOW_INK -> {
                        val current = meta.underInkObjectIds(pageIndex).toMutableSet()
                        if (current.add(id)) {
                            meta.setUnderInkObjectIds(session, pageIndex, current)
                            revision++
                        }
                    }
                    com.kairumo.padnote.canvas.ObjectStacking.Reorder.BRING_ABOVE_INK -> {
                        val current = meta.underInkObjectIds(pageIndex).toMutableSet()
                        if (current.remove(id)) {
                            meta.setUnderInkObjectIds(session, pageIndex, current)
                            revision++
                        }
                    }
                    com.kairumo.padnote.canvas.ObjectStacking.Reorder.TO_FRONT -> {
                        val current = meta.underInkObjectIds(pageIndex).toMutableSet()
                        if (current.remove(id)) {
                            meta.setUnderInkObjectIds(session, pageIndex, current)
                        }
                        val items = buildList {
                            imageStore.all.forEach { add(ObjectStacking.Item(it.id, ObjectStacking.Kind.IMAGE, "")) }
                            shapeStore.all.forEach { add(ObjectStacking.Item(it.id, ObjectStacking.Kind.SHAPE, "")) }
                            tableStore.all.forEach { add(ObjectStacking.Item(it.id, ObjectStacking.Kind.TABLE, "")) }
                            chartStore.all.forEach { add(ObjectStacking.Item(it.id, ObjectStacking.Kind.CHART, "")) }
                            textStore.all.forEach { add(ObjectStacking.Item(it.id, ObjectStacking.Kind.TEXT, "")) }
                        }
                        val currentOrder = ObjectStacking.normalized(items, meta.objectOrder(pageIndex))
                        meta.setObjectOrder(session, pageIndex, op.apply(id, currentOrder))
                        revision++
                    }
                    else -> {
                        val items = buildList {
                            imageStore.all.forEach { add(ObjectStacking.Item(it.id, ObjectStacking.Kind.IMAGE, "")) }
                            shapeStore.all.forEach { add(ObjectStacking.Item(it.id, ObjectStacking.Kind.SHAPE, "")) }
                            tableStore.all.forEach { add(ObjectStacking.Item(it.id, ObjectStacking.Kind.TABLE, "")) }
                            chartStore.all.forEach { add(ObjectStacking.Item(it.id, ObjectStacking.Kind.CHART, "")) }
                            textStore.all.forEach { add(ObjectStacking.Item(it.id, ObjectStacking.Kind.TEXT, "")) }
                        }
                        val currentOrder = ObjectStacking.normalized(items, meta.objectOrder(pageIndex))
                        meta.setObjectOrder(session, pageIndex, op.apply(id, currentOrder))
                        revision++
                    }
                }
            },
            // 鎖定在畫布上（見 ObjectLock.kt）：與單頁模式同一份中繼資料。
            com.kairumo.padnote.canvas.LocalObjectLock provides objectLock,
            com.kairumo.padnote.canvas.LocalLockedObjectIds provides lockedIds
        ) {
            key(revision) {
                ImageLayer(
                    images = imageStore.all,
                    store = imageStore,
                    density = density,
                    selectedId = selectedId,
                    interactive = interactive,
                    onSelect = { selectedId = it; selectedConnectionId = null },
                    onEditStyle = { editingImage = it },
                    onChanged = { imageStore.persist(it); revision++ },
                    zIndexOf = zIndexOf,
                    modifier = Modifier.fillMaxSize()
                )
                TableLayer(
                    interactive = interactive,
                    tables = tableStore.all,
                    density = density,
                    selectedId = selectedId,
                    onSelect = { selectedId = it; selectedConnectionId = null },
                    onEdit = { editingTable = it },
                    onChanged = { tableStore.persist(it); revision++ },
                    zIndexOf = zIndexOf,
                    modifier = Modifier.fillMaxSize()
                )
                ChartLayer(
                    interactive = interactive,
                    charts = chartStore.all,
                    density = density,
                    selectedId = selectedId,
                    onSelect = { selectedId = it; selectedConnectionId = null },
                    onEdit = { editingChart = it },
                    onChanged = { chartStore.persist(it); revision++ },
                    zIndexOf = zIndexOf,
                    modifier = Modifier.fillMaxSize()
                )
                TextBoxLayer(
                    interactive = interactive,
                    boxes = textStore.all,
                    density = density,
                    selectedId = selectedId,
                    onSelect = { selectedId = it; selectedConnectionId = null },
                    onEditStyle = { editingText = it },
                    onChanged = { textStore.persist(it); revision++ },
                    zIndexOf = zIndexOf,
                    modifier = Modifier.fillMaxSize()
                )
            }

            // 形狀不放進 `key(revision)`：整層重建會把進行中的拖曳、縮放、拉線拆掉
            // （理由見 MainActivity 裡同一段）。只讀版本號訂閱重組。
            @Suppress("UNUSED_VARIABLE") val revisionRead = revision
            ShapeLayer(
                interactive = interactive,
                shapes = shapeStore.all,
                connections = shapeStore.allConnections,
                density = density,
                selectedIds = setOfNotNull(selectedId),
                selectedConnectionId = selectedConnectionId,
                connectionDraft = connectionDraft,
                onSelect = { id ->
                    selectedConnectionId = null
                    selectedId = if (selectedId == id) null else id
                },
                onEdit = { shape -> selectedId = shape.id; editingShape = shape },
                onDelete = { shape ->
                    shapeStore.remove(shape)
                    if (selectedId == shape.id) selectedId = null
                    revision++
                },
                onChanged = { shapeStore.persist(it); revision++ },
                zIndexOf = zIndexOf,
                modifier = Modifier.fillMaxSize(),
                onSelectConnection = { id ->
                    selectedConnectionId = id
                    if (id != null) selectedId = null
                },
                onEditConnection = { link -> selectedConnectionId = link.id; editingConnection = link },
                onDeleteConnection = { link ->
                    shapeStore.remove(link)
                    selectedConnectionId = null
                    revision++
                },
                onConnectDrag = { from, anchor, start, current, finished ->
                    if (!finished) {
                        connectionDraft = ConnectionDraft(start.x, start.y, current.x, current.y)
                    } else {
                        connectionDraft = null
                        shapeStore.connectByDrag(from, anchor, current.x, current.y)?.let {
                            selectedId = null
                            selectedConnectionId = it.id
                            revision++
                        }
                    }
                }
            )
        }

        // 套索層：疊在這一頁上面。每一頁各一層、共用一份選取 —— 圈、選取框與快顯工具列
        // 只畫在選取所屬的那一頁（ownsLasso）。頁面被 `scaledPage` 縮過，工具列反向放大回
        // 螢幕上的原尺寸，不然縮小時按鈕小到按不到（與 Apple 的 barScale 同一個道理）。
        if (lasso != null && editorMode == EditorMode.DRAW) {
            val lassoChanged = {
                revision++
                runtime.bump()
                collabBridge?.onLocalChange?.invoke()
                Unit
            }
            LassoOverlay(
                lasso = lasso,
                engine = engine,
                onGestureStart = onLassoClaim,
                showDecoration = ownsLasso,
                onChanged = lassoChanged,
                modifier = Modifier.fillMaxSize().zIndex(200f)
            )
            val box = lasso.boundingRect
            if (ownsLasso && box != null) {
                LassoActionBar(
                    lasso = lasso,
                    engine = engine,
                    l = { key -> com.kairumo.padnote.LocalizationStrings.localized(key, com.kairumo.padnote.currentLanguageTag()) },
                    onChanged = lassoChanged,
                    modifier = Modifier
                        .zIndex(300f)
                        .lassoBarPlacement(box, density, 1f, Offset.Zero, 12f * density / pageScale)
                        .graphicsLayer(scaleX = 1f / pageScale, scaleY = 1f / pageScale)
                )
            }
        }

        if (lockedIds.isNotEmpty()) {
            val localize = { key: String -> com.kairumo.padnote.LocalizationStrings.localized(key, com.kairumo.padnote.currentLanguageTag()) }
            // 兩種模式都畫；手寫模式下只顯示，入口是手指點物件（上面的 fingerTapOnLockedObject）。
            LockBadges(
                lockFrames, lockedIds, localize("object_locked"),
                if (interactive) { id -> lockPromptId = if (lockPromptId == id) null else id } else null
            )
            if (interactive) lockFrames.firstOrNull { it.id == lockPromptId && it.id in lockedIds }?.let { frame ->
                UnlockPrompt(frame, localize("object_unlock")) { objectLock.setLocked(frame.id, false) }
            }
        }

        Text(
            "${pageIndex + 1}",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(6.dp)
        )
    }

    // ---- 編輯面板（與單頁模式同一批）----
    val languageTag = LocalAppLanguage.current

    editingImage?.let { image ->
        ImageEditor(
            image = image,
            languageTag = languageTag,
            onChanged = { imageStore.persist(it); revision++ },
            onDelete = { imageStore.remove(image); selectedId = null; revision++ },
            onDismiss = { editingImage = null }
        )
    }
    editingShape?.let { shape ->
        ShapeEditDialog(
            shape = shape,
            languageTag = languageTag,
            onApply = { shapeStore.persist(it); revision++ },
            onDuplicate = { source ->
                val copy = shapeStore.create(source.copyShape().apply { x += 24f; y += 24f; groupId = null })
                selectedId = copy.id
                editingShape = copy
                revision++
            },
            onDelete = { target -> shapeStore.remove(target); selectedId = null; revision++ },
            onReorder = { op ->
                val current = ObjectStacking.normalized(currentItems, meta.objectOrder(pageIndex))
                meta.setObjectOrder(session, pageIndex, op.apply(shape.id, current))
                revision++
            },
            onDismiss = { editingShape = null }
        )
    }
    editingConnection?.let { link ->
        ConnectionEditDialog(
            link = link,
            languageTag = languageTag,
            onApply = { shapeStore.persist(it); revision++ },
            onDelete = { target -> shapeStore.remove(target); selectedConnectionId = null; revision++ },
            onDismiss = { editingConnection = null }
        )
    }
    editingTable?.let { table ->
        TableEditor(
            table = table,
            languageTag = languageTag,
            isNew = false,
            onCommit = { updated ->
                // 位置原地保留：使用者只是改了裡面的內容。
                tableStore.persist(updated.copyTable().apply { x = table.x; y = table.y })
                revision++
                editingTable = null
            },
            onDelete = { tableStore.remove(table); selectedId = null; revision++; editingTable = null },
            onDismiss = { editingTable = null }
        )
    }
    editingChart?.let { chart ->
        androidx.compose.ui.window.Dialog(onDismissRequest = { editingChart = null }) {
            androidx.compose.material3.Surface(shape = androidx.compose.foundation.shape.RoundedCornerShape(12.dp)) {
                ChartStudio(
                    languageTag = languageTag,
                    initial = chart.spec,
                    onCommit = { spec ->
                        // 位置與尺寸原地保留：使用者只是改了裡面的數字。
                        chartStore.persist(chart.copy(spec = spec))
                        revision++
                        editingChart = null
                    },
                    onDismiss = { editingChart = null }
                )
            }
        }
    }
    editingText?.let { box ->
        TextBoxEditor(
            box = box,
            languageTag = languageTag,
            onChanged = { textStore.persist(it); revision++ },
            onDelete = { textStore.remove(box); selectedId = null; revision++; editingText = null },
            onDismiss = { editingText = null }
        )
    }
}

/**
 * 連續模式裡一頁的引擎與物件。放在 `ContinuousPagesView` 的快取裡，不隨清單項目拆掉 ——
 * 捲出畫面再捲回來，筆跡的復原紀錄與物件都還在（見 ContinuousPagesView 的復原說明）。
 */
internal class PageRuntime(session: PadnoteSession?, val pageId: String?, context: android.content.Context? = null) {
    val engine = InkEngine(session = session, pageId = pageId).apply {
        if (context != null) {
            setPalmThresholds(
                PalmThresholdStore.radius(context),
                PalmThresholdStore.retractMs(context)
            )
            setPressureCurve(
                PenSettingsStore.floor(context) ?: 0.1f,
                PenSettingsStore.gamma(context) ?: 1.0f
            )
        }
    }
    val textStore = TextBoxStore(session, pageId)
    val shapeStore = ShapeStore(session, pageId)
    val tableStore = TableStore(session, pageId)
    val chartStore = ChartStore(session, pageId)
    val imageStore = ImageStore(session, pageId)
    /** 這一頁的版本號。頁面在畫面上時由它重組；復原改到不在畫面上的頁時也遞增它。 */
    val revision = mutableIntStateOf(0)
    var inkLoaded = false

    fun bump() { revision.intValue++ }

    /** 這一頁物件的快照（連續模式沒有連結卡、3D、錄音卡，那些只在單頁模式出現）。 */
    fun snapshot(meta: NotebookMeta, pageIndex: Int) = CanvasSnapshot(
        texts = textStore.all.map { it.copy() },
        images = imageStore.all.map { it.copy() },
        shapes = shapeStore.all.map { it.copy() },
        connections = shapeStore.allConnections.map { it.copy() },
        tables = tableStore.all.map { it.copyTable() },
        charts = chartStore.all.map { it.copy() },
        order = meta.objectOrder(pageIndex)
    )

    fun restore(snapshot: CanvasSnapshot, meta: NotebookMeta, session: PadnoteSession?, pageIndex: Int?) {
        isRestoring = true
        textStore.restoreTo(snapshot.texts)
        imageStore.restoreTo(snapshot.images)
        shapeStore.restoreTo(snapshot.shapes, snapshot.connections)
        tableStore.restoreTo(snapshot.tables)
        chartStore.restoreTo(snapshot.charts)
        if (pageIndex != null && meta.objectOrder(pageIndex) != snapshot.order) {
            meta.setObjectOrder(session, pageIndex, snapshot.order)
        }
        bump()
    }
    var isRestoring = false
}
