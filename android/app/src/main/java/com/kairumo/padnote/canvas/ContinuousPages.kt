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
import androidx.compose.foundation.lazy.rememberLazyListState
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
import androidx.compose.runtime.rememberCoroutineScope
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
    modifier: Modifier = Modifier
) {
    val listState = rememberLazyListState()
    val density = LocalDensity.current.density
    val scope = rememberCoroutineScope()


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
            modifier = Modifier.fillMaxSize(),
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
                            onModeChange = onModeChange,
                            density = density,
                            reloadToken = reloadToken
                        )
                    }
                }
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
    onModeChange: (EditorMode) -> Unit,
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
    // **一律 pen-only**，不理會外層的設定。理由見 ContinuousPagesView 的說明：
    // 手指要留給捲動，否則畫布會跟 LazyColumn 搶事件，兩邊都做不成。
    LaunchedEffect(engine) {
        engine.setPenOnly(true)
        // 讀回這一頁已經存在的筆畫。見 InkEngine.load() 的說明。
        engine.load()
    }

    val textStore = remember(session, pageId) { TextBoxStore(session, pageId) }
    val shapeStore = remember(session, pageId) { ShapeStore(session, pageId) }
    val tableStore = remember(session, pageId) { TableStore(session, pageId) }
    val chartStore = remember(session, pageId) { ChartStore(session, pageId) }
    val imageStore = remember(session, pageId) { ImageStore(session, pageId) }
    var revision by remember(pageId) { mutableIntStateOf(0) }

    // reloadToken 讓外層插入物件之後這一頁看得到新東西 ——
    // 不重讀的話，從選單插進去的文字方塊要等切換頁面才會出現。
    LaunchedEffect(session, pageId, reloadToken) {
        textStore.load()
        shapeStore.load()
        tableStore.load()
        chartStore.load()
        imageStore.load()
        revision++
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
    val zIndexOf: (String) -> Float = { id ->
        ObjectStacking.zIndex(id, kindOf[id] ?: ObjectStacking.Kind.TEXT, order)
    }

    val interactive = editorMode == EditorMode.TYPE
    val currentInkColor = remember(ink.colorRgba) {
        if (ink.colorRgba.size >= 4) {
            Color(
                (ink.colorRgba[0].toInt() and 0xFF) / 255f,
                (ink.colorRgba[1].toInt() and 0xFF) / 255f,
                (ink.colorRgba[2].toInt() and 0xFF) / 255f,
                (ink.colorRgba[3].toInt() and 0xFF) / 255f
            )
        } else Color.Black
    }

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
            inkColor = currentInkColor,
            onInkChanged = { revision++ },
            onStylusDetected = { onModeChange(EditorMode.DRAW) },
            contentVersion = revision,
            acceptsInk = editorMode == EditorMode.DRAW
        )

        key(revision) {
            ImageLayer(
                images = imageStore.all,
                store = imageStore,
                density = density,
                selectedId = null,
                interactive = interactive,
                onSelect = {},
                onEditStyle = {},
                onChanged = { imageStore.persist(it); revision++ },
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
                onChanged = { shapeStore.persist(it); revision++ },
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
                onChanged = { tableStore.persist(it); revision++ },
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
                onChanged = { chartStore.persist(it); revision++ },
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
                onChanged = { textStore.persist(it); revision++ },
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
