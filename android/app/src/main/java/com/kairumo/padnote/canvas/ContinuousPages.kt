package com.kairumo.padnote.canvas

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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
import com.kairumo.padnote.shape.ShapeLayer
import com.kairumo.padnote.shape.ShapeStore
import com.kairumo.padnote.table.TableLayer
import com.kairumo.padnote.table.TableStore
import com.kairumo.padnote.text.TextBoxLayer
import com.kairumo.padnote.text.TextBoxStore
import uniffi.padnote_core.PadnoteSession
import uniffi.padnote_core.ToolKind

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
        fun fromWire(value: String?): PageDisplayMode =
            entries.firstOrNull { it.wire == value } ?: SINGLE
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
 * # 捲動與手寫的分工：一指畫、兩指捲，與 Apple 端一致
 *
 * `LazyColumn` 自己的捲動手勢在滑動超過 touch slop 時就把事件攔走，
 * 底下的畫布只收得到前幾個點 —— 手指既畫不出東西、又只能捲動。
 *
 * 試過「偵測到筆就**動態**關掉 `userScrollEnabled`」：沒有用。重組要等到
 * 下一幀，而捲動手勢在那之前就已經接手了。
 *
 * 現在是把 `userScrollEnabled` **靜態關掉**（不是動態切換，所以沒有差一幀
 * 的問題），捲動改由這裡自己驅動：
 *
 * - 一根手指或筆 → 事件先到畫布。畫布要就吃掉，這裡看不到。
 * - 兩根以上 → 畫布的仲裁器判為手勢而不消費，這裡接到之後
 *   `dispatchRawDelta` 推動清單。
 *
 * 之所以是「兩根以上」而不是「不是筆就捲動」：手指畫畫是整頁模式本來就
 * 支援的事，連續模式沒有理由不支援。
 *
 * **已知不足**：放開手指之後沒有慣性滑行（fling）。要補的話得接上
 * `VelocityTracker` 與 `listState.animateScrollBy`，那是另一件事。
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
    /** 外層插入物件之後 bump，讓對應的頁重新讀 store。 */
    reloadToken: Int,
    modifier: Modifier = Modifier
) {
    val listState = rememberLazyListState()
    val density = LocalDensity.current.density


    // 畫面中央最近的那一頁 = 焦點頁。用 layoutInfo 而不是
    // firstVisibleItemIndex：後者在頁面比視窗高時永遠是同一個值，
    // 捲過半頁焦點也不會變。
    // 外層改了頁碼（按了上一頁／下一頁、新增頁面）就捲過去。
    //
    // 記住「最後一次由捲動回報出去的頁碼」，只有在外層的值與它不同時才捲 ——
    // 不這樣分的話，捲動→回報→外層更新→再捲回去，會自己跟自己打架。
    var lastReported by remember { mutableIntStateOf(-1) }
    LaunchedEffect(focusIndex) {
        if (focusIndex != lastReported) {
            listState.animateScrollToItem(focusIndex.coerceAtLeast(0))
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
            if (index != null && index != lastReported) {
                lastReported = index
                onFocusChange(index)
            }
        }
    }

    BoxWithConstraints(modifier) {
        // 頁面是固定的 800 × 1132（P-01），視窗不是。縮到剛好放得下 ——
        // 不縮的話頁面右半邊會被切掉，而使用者看不出那是「超出去」
        // 還是「畫布壞了」。
        val available = (maxWidth.value - 32f).coerceAtLeast(1f)
        val scale = minOf(1f, available / PageGeometry.width)
        LazyColumn(
            state = listState,
            // **靜態**關掉內建捲動（不是動態切換，所以沒有差一幀的問題）。
            // 開著的話它會在滑動超過 touch slop 時把事件整個攔走，
            // 手指就永遠畫不出東西。
            userScrollEnabled = false,
            modifier = Modifier.fillMaxSize().twoFingerScroll(listState),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = 20.dp)
        ) {
            items(maxOf(1, pageCount)) { index ->
                Box(Modifier.scaledPage(scale)) {
                    key(index) {
                        ContinuousPage(
                            session = session,
                            meta = meta,
                            pageIndex = index,
                            isFocused = index == focusIndex,
                            ink = ink,
                            editorMode = editorMode,
                            density = density,
                            reloadToken = reloadToken
                        )
                    }
                }
            }
        }
    }
}


/**
 * 兩指（以上）拖曳就捲動清單。
 *
 * 跑在 **Main pass**，所以子節點先看事件：一根手指或筆落在畫布上時，
 * 畫布會自己消費掉，這裡收到的 change 已經是 consumed，不會誤捲。
 * 兩根手指時畫布的仲裁器判為手勢而不消費，這裡才動。
 *
 * 用 `dispatchRawDelta` 而不是 `scrollBy`：後者是 suspend 的，
 * 每個事件開一個協程會落後好幾幀，捲動看起來像在拖泥。
 */
private fun Modifier.twoFingerScroll(listState: LazyListState): Modifier =
    pointerInput(listState) {
        awaitPointerEventScope {
            var lastY: Float? = null
            while (true) {
                val event = awaitPointerEvent()
                val down = event.changes.filter { it.pressed && !it.isConsumed }
                if (down.size < 2) {
                    // 手指放開或只剩一根：下一次要重新取基準點，
                    // 不然會把「兩指之間的位置跳動」當成一次大幅捲動。
                    lastY = null
                    continue
                }
                val y = down.map { it.position.y }.average().toFloat()
                lastY?.let { previous ->
                    val dy = y - previous
                    // 手指往下 = 內容往上，所以要反號。
                    if (dy != 0f) listState.dispatchRawDelta(-dy)
                }
                lastY = y
                down.forEach { it.consume() }
            }
        }
    }

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
    pageIndex: Int,
    isFocused: Boolean,
    ink: InkSettings,
    editorMode: EditorMode,
    density: Float,
    reloadToken: Int
) {
    val pageId = remember(session, pageIndex) {
        runCatching { session?.pageIdAt(pageIndex.toUInt()) }.getOrNull()
    }

    // 每一頁自己一個引擎。共用的話會把筆畫寫進別頁的檔案裡。
    val engine = remember(session, pageId) { InkEngine(session = session, pageId = pageId) }
    engine.tool = ink.tool
    engine.colorRgba = ink.colorRgba
    engine.baseWidth = ink.baseWidth
    engine.isErasing = ink.isErasing
    // 跟著外層的設定走。**不再強制 pen-only** —— 捲動改由
    // ContinuousPagesView 自己用兩指手勢驅動，手指不必再讓給 LazyColumn。
    engine.setPenOnly(ink.penOnly)
    LaunchedEffect(engine) {
        // 讀回這一頁已經存在的筆畫。見 InkEngine.load() 的說明。
        engine.load()
    }

    val textStore = remember(session, pageId) { TextBoxStore(session, pageId) }
    val shapeStore = remember(session, pageId) { ShapeStore(session, pageId) }
    val tableStore = remember(session, pageId) { TableStore(session, pageId) }
    val chartStore = remember(session, pageId) { ChartStore(session, pageId) }
    val imageStore = remember(session, pageId) { ImageStore(session, pageId) }
    // **墨跡與物件要分開兩個計數器。**
    //
    // 原本共用一個：`InkCanvas` 的 `onInkChanged` 每收到一個觸控取樣就 +1，
    // 而底下所有物件圖層都 `key(revision)` —— 於是寫一筆字（120Hz 下
    // 每秒上百個取樣）就把圖片、形狀、表格、圖表、文字五個圖層整個丟掉
    // 重建，一秒好幾百次。
    //
    // 在整頁模式看不出來：那邊本來就是分開的計數器（imageRevision、
    // textRevision…）。連續模式抄過來時合成了一個，而且頁數越多越糟。
    // 實測過一次輸入派送逾時的 ANR，很可能就是這個。
    var objectRevision by remember(pageId) { mutableIntStateOf(0) }
    var inkRevision by remember(pageId) { mutableIntStateOf(0) }

    // reloadToken 讓外層插入物件之後這一頁看得到新東西 ——
    // 不重讀的話，從選單插進去的文字方塊要等切換頁面才會出現。
    LaunchedEffect(session, pageId, reloadToken) {
        textStore.load()
        shapeStore.load()
        tableStore.load()
        chartStore.load()
        imageStore.load()
        objectRevision++
    }

    val order = remember(objectRevision, pageIndex) { meta.objectOrder(pageIndex) }
    val kindOf = remember(objectRevision, pageIndex) {
        buildMap {
            imageStore.all.forEach { put(it.id, ObjectStacking.Kind.IMAGE) }
            shapeStore.all.forEach { put(it.id, ObjectStacking.Kind.SHAPE) }
            tableStore.all.forEach { put(it.id, ObjectStacking.Kind.TABLE) }
            chartStore.all.forEach { put(it.id, ObjectStacking.Kind.CHART) }
            textStore.all.forEach { put(it.id, ObjectStacking.Kind.TEXT) }
        }
    }
    val zIndexOf: (String) -> Float = { id ->
        ObjectStacking.zIndex(id, kindOf[id] ?: ObjectStacking.Kind.TEXT, order)
    }

    val interactive = editorMode == EditorMode.TYPE

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
    ) {
        InkCanvas(
            engine = engine,
            modifier = Modifier.fillMaxSize(),
            // 只動墨跡那個計數器。物件圖層不重建 —— 見上面的說明。
            onInkChanged = { inkRevision++ },
            contentVersion = inkRevision
        )

        key(objectRevision) {
            ImageLayer(
                images = imageStore.all,
                store = imageStore,
                density = density,
                selectedId = null,
                interactive = interactive,
                onSelect = {},
                onEditStyle = {},
                onChanged = { imageStore.persist(it); objectRevision++ },
                zIndexOf = zIndexOf,
                modifier = Modifier.fillMaxSize()
            )
            ShapeLayer(
                interactive = interactive,
                shapes = shapeStore.all,
                connections = shapeStore.allConnections,
                density = density,
                selectedIds = emptySet(),
                onSelect = {},
                onEdit = {},
                onEditStyle = {},
                onChanged = { shapeStore.persist(it); objectRevision++ },
                zIndexOf = zIndexOf,
                modifier = Modifier.fillMaxSize()
            )
            TableLayer(
                interactive = interactive,
                tables = tableStore.all,
                density = density,
                selectedId = null,
                onSelect = {},
                onEdit = {},
                onChanged = { tableStore.persist(it); objectRevision++ },
                zIndexOf = zIndexOf,
                modifier = Modifier.fillMaxSize()
            )
            ChartLayer(
                interactive = interactive,
                charts = chartStore.all,
                density = density,
                selectedId = null,
                onSelect = {},
                onEdit = {},
                onChanged = { chartStore.persist(it); objectRevision++ },
                zIndexOf = zIndexOf,
                modifier = Modifier.fillMaxSize()
            )
            TextBoxLayer(
                interactive = interactive,
                boxes = textStore.all,
                density = density,
                selectedId = null,
                onSelect = {},
                onEditStyle = {},
                onChanged = { textStore.persist(it); objectRevision++ },
                zIndexOf = zIndexOf,
                modifier = Modifier.fillMaxSize()
            )
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
}
