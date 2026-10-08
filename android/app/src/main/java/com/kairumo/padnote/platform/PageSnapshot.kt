package com.kairumo.padnote.platform

import android.graphics.Bitmap
import androidx.activity.ComponentActivity
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.drawscope.draw
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import android.view.ViewGroup
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import android.widget.FrameLayout
import com.kairumo.padnote.LocalizationStrings
import com.kairumo.padnote.audio.AudioLayer
import com.kairumo.padnote.canvas.MaskingTapeOverlay
import com.kairumo.padnote.canvas.NoteTape
import com.kairumo.padnote.canvas.NoteTapeCodec
import com.kairumo.padnote.canvas.ObjectStacking
import com.kairumo.padnote.chart.ChartLayer
import com.kairumo.padnote.chart.ChartStore
import com.kairumo.padnote.comment.CommentLayer
import com.kairumo.padnote.image.ImageLayer
import com.kairumo.padnote.image.ImageStore
import com.kairumo.padnote.image.LinkLayer
import com.kairumo.padnote.ink.InkCanvas
import com.kairumo.padnote.ink.InkEngine
import com.kairumo.padnote.ink.PageGeometry
import com.kairumo.padnote.library.NotebookMeta
import com.kairumo.padnote.model3d.Model3DLayer
import com.kairumo.padnote.shape.ShapeLayer
import com.kairumo.padnote.shape.ShapeStore
import com.kairumo.padnote.table.TableLayer
import com.kairumo.padnote.table.TableStore
import com.kairumo.padnote.text.TextBoxLayer
import com.kairumo.padnote.text.TextBoxStore
import com.kairumo.padnote.ui.KairumoTheme
import com.kairumo.padnote.ui.LocalAppLanguage
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import uniffi.padnote_core.PadnoteSession
import java.io.File
import kotlin.math.ceil

/**
 * 把一頁**照畫布上看到的樣子**算成點陣圖（所見即所得）。
 *
 * # 為什麼不是核心的匯出器
 *
 * 核心的 PDF／PNG 匯出器有自己的繪圖程式碼：筆畫是等寬折線（沒有壓感粗細、鉛筆與麥克筆的質地、
 * 螢光筆的疊色、專業筆刷的筆點），形狀、圖表、連結卡片、3D、錄音卡片、圖片的濾鏡不在它的文件模型裡，
 * 堆疊順序也不是畫布上的順序。**畫布一個樣子、匯出另一個樣子**，使用者只會覺得內容缺了。
 *
 * # 做法：用畫布自己的元件
 *
 * 這裡組一棵與編輯器單頁模式**同一組元件、同一個堆疊**的畫面（`InkCanvas` + 各個 `*Layer`，
 * 全部 `interactive = false`），放進一個離螢幕的 `ComposeView`，再用 `GraphicsLayer` 錄下來。
 * 沒有第二份繪圖程式碼可以漂移：畫布改了，匯出自然跟著改。
 *
 * 密度設成 [scale]：頁面座標 1 點 = [scale] 個像素，2.0 約等於 Retina。
 */
object PageSnapshot {

    /** 等待畫面穩定與錄製完成的上限。逾時回 `null`，呼叫端退回核心的匯出器。 */
    private const val TIMEOUT_MS = 20_000L

    suspend fun render(
        activity: ComponentActivity,
        session: PadnoteSession,
        pageIndex: Int,
        scale: Float,
        languageTag: String,
        audioDirectory: File? = null
    ): Bitmap? = withContext(Dispatchers.Main) {
        val meta = NotebookMeta.load(session)
        PageGeometry.use(meta.pageFormatId())
        val widthDp = PageGeometry.width
        val heightDp = PageGeometry.height
        val widthPx = ceil(widthDp * scale).toInt()
        val heightPx = ceil(heightDp * scale).toInt()

        val result = CompletableDeferred<Bitmap?>()
        val host = FrameLayout(activity)
        // 視窗的根視圖通常已經有生命週期與狀態擁有者（`setContent` 設的）；沒有時（例如測試用的空白
        // Activity）ComposeView 會拋「No lifecycle owner exists」，所以掛在這個宿主上補齊。
        host.setViewTreeLifecycleOwner(activity)
        host.setViewTreeSavedStateRegistryOwner(activity)
        host.setViewTreeViewModelStoreOwner(activity)
        val view = ComposeView(activity).apply {
            setContent {
                val layer = rememberGraphicsLayer()
                val scope = rememberCoroutineScope()
                CompositionLocalProvider(
                    LocalDensity provides Density(scale, 1f),
                    LocalAppLanguage provides languageTag
                ) {
                    KairumoTheme {
                        Box(
                            Modifier
                                .size(widthDp.dp, heightDp.dp)
                                .drawWithContent {
                                    layer.record { this@drawWithContent.drawContent() }
                                    drawLayer(layer)
                                }
                        ) {
                            ExportPageContent(session, meta, pageIndex, scale, languageTag, audioDirectory)
                        }
                    }
                }
                LaunchedEffect(Unit) {
                    // 等第一輪組合、版面、繪製都走完，再多給兩幀：圖層裡有幾處（圖表、文字量測）
                    // 要等版面量完才畫得出來。
                    repeat(3) { androidx.compose.runtime.withFrameNanos { } }
                    result.complete(
                        runCatching {
                            // `GraphicsLayer` 給的是 HARDWARE 點陣圖：讀不了像素、也畫不進 PDF 的軟體畫布。
                            // 複製成一般的 ARGB_8888 再交出去。
                            val hardware = layer.toImageBitmap().asAndroidBitmap()
                            hardware.copy(Bitmap.Config.ARGB_8888, false).also { hardware.recycle() }
                        }
                            .onFailure { android.util.Log.e("PageSnapshot", "toImageBitmap failed", it) }
                            .getOrNull()
                    )
                }
            }
        }
        host.addView(view, FrameLayout.LayoutParams(widthPx, heightPx))
        val root = activity.findViewById<ViewGroup>(android.R.id.content)
        // 放在視窗外面：使用者看不到，但仍然會被量測、排版、繪製。
        host.translationX = -(widthPx + 64).toFloat()
        root.addView(host, FrameLayout.LayoutParams(widthPx, heightPx))
        try {
            withTimeoutOrNull(TIMEOUT_MS) { result.await() }
        } finally {
            root.removeView(host)
        }
    }

    /**
     * 與 `MainActivity` 單頁模式同一個堆疊：紙張底紋與墨跡（`InkCanvas`）→ 遮蔽膠帶 → 圖片 → 文字 → 形狀 →
     * 表格 → 圖表 → 連結 → 錄音卡片 → 3D → 討論圖釘。順序與各層的 `zIndexOf` 都照那邊。
     */
    @Composable
    private fun ExportPageContent(
        session: PadnoteSession,
        meta: NotebookMeta,
        pageIndex: Int,
        density: Float,
        languageTag: String,
        audioDirectory: File?
    ) {
        val pageId = remember(session, pageIndex) {
            runCatching { session.pageIdAt(pageIndex.toUInt()) }.getOrNull()
        }
        val engine = remember(session, pageId) { InkEngine(session = session, pageId = pageId).also { it.load() } }
        val textStore = remember(session, pageId) { TextBoxStore(session, pageId).also { it.load() } }
        val shapeStore = remember(session, pageId) { ShapeStore(session, pageId).also { it.load() } }
        val tableStore = remember(session, pageId) { TableStore(session, pageId).also { it.load() } }
        val chartStore = remember(session, pageId) { ChartStore(session, pageId).also { it.load() } }
        val imageStore = remember(session, pageId) { ImageStore(session, pageId).also { it.load() } }
        val links = remember(meta, pageIndex) { meta.links().filter { it.pageIndex == pageIndex } }
        val audioCards = remember(meta, pageIndex) { meta.audioCards().filter { it.pageIndex == pageIndex } }
        val models = remember(meta, pageIndex) { meta.models3D().filter { it.pageIndex == pageIndex } }
        val pins = remember(meta) { meta.commentPins() }
        val tapes = remember(session, pageId, meta, pageIndex) {
            val envelopes = mutableListOf<NoteTape>()
            if (pageId != null) {
                for (blockId in runCatching { session.imageBlockIds(pageId) }.getOrDefault(emptyList())) {
                    val json = runCatching { session.blockAppearance(blockId) }.getOrNull() ?: continue
                    NoteTapeCodec.parseEnvelope(json, pageIndex)?.let { envelopes.add(it) }
                }
            }
            val known = envelopes.map { it.id.lowercase() }.toSet()
            (envelopes + meta.tapes().filter { it.pageIndex == pageIndex && it.id.lowercase() !in known })
                .toMutableList()
        }

        // 堆疊順序：與編輯器同一組純函式。
        val stack = remember(meta, pageIndex, imageStore, shapeStore, tableStore, chartStore, textStore) {
            val items = buildList {
                imageStore.all.forEach { add(ObjectStacking.Item(it.id, ObjectStacking.Kind.IMAGE, "")) }
                shapeStore.all.forEach { add(ObjectStacking.Item(it.id, ObjectStacking.Kind.SHAPE, "")) }
                tableStore.all.forEach { add(ObjectStacking.Item(it.id, ObjectStacking.Kind.TABLE, "")) }
                chartStore.all.forEach { add(ObjectStacking.Item(it.id, ObjectStacking.Kind.CHART, "")) }
                textStore.all.forEach { add(ObjectStacking.Item(it.id, ObjectStacking.Kind.TEXT, "")) }
            }
            val order = ObjectStacking.normalized(items, meta.objectOrder(pageIndex))
            order to items.associate { it.id to it.kind }
        }
        val zIndexOf: (String) -> Float = { id ->
            ObjectStacking.zIndex(id, stack.second[id] ?: ObjectStacking.Kind.TEXT, stack.first)
        }
        val l10n: (String) -> String = { key -> LocalizationStrings.localized(key, languageTag) }
        val guideMeasurer = rememberTextMeasurer()

        Box(Modifier.fillMaxSize().background(Color.White)) {
            InkCanvas(
                engine = engine,
                modifier = Modifier.fillMaxSize(),
                pageStyle = uniffi.padnote_core.PageStyle.BLANK,
                paperId = meta.paperId(pageIndex),
                localizeGuide = l10n,
                guideMeasurer = guideMeasurer,
                guidePaletteId = meta.paletteId(),
                acceptsInk = false
            )
            MaskingTapeOverlay(
                pageIndex = pageIndex, isActive = false, tapes = tapes, modifier = Modifier.fillMaxSize()
            )
            ImageLayer(
                zIndexOf = zIndexOf, images = imageStore.all, store = imageStore, density = density,
                selectedId = null, interactive = false, onSelect = {}, onEditStyle = {}, onChanged = {},
                modifier = Modifier.fillMaxSize()
            )
            TextBoxLayer(
                zIndexOf = zIndexOf, interactive = false, boxes = textStore.all, density = density,
                selectedId = null, onSelect = {}, onEditStyle = {}, onChanged = {},
                modifier = Modifier.fillMaxSize()
            )
            ShapeLayer(
                interactive = false, shapes = shapeStore.all, connections = shapeStore.allConnections,
                density = density, selectedIds = emptySet(), selectedConnectionId = null,
                connectionDraft = null, onSelect = {}, onEdit = {}, onDelete = {}, onChanged = {},
                zIndexOf = zIndexOf, modifier = Modifier.fillMaxSize(),
                onSelectConnection = {}, onEditConnection = {}, onDeleteConnection = {},
                onConnectDrag = { _, _, _, _, _ -> }
            )
            TableLayer(
                zIndexOf = zIndexOf, interactive = false, tables = tableStore.all, density = density,
                selectedId = null, onSelect = {}, onEdit = {}, onChanged = {}, modifier = Modifier.fillMaxSize()
            )
            ChartLayer(
                zIndexOf = zIndexOf, interactive = false, charts = chartStore.all, density = density,
                selectedId = null, onSelect = {}, onEdit = {}, onChanged = {}, modifier = Modifier.fillMaxSize()
            )
            LinkLayer(
                interactive = false, links = links, density = density, selectedId = null, onSelect = {},
                onOpen = {}, onEdit = {}, onDelete = {}, onChanged = {}, zIndexOf = zIndexOf
            )
            AudioLayer(
                interactive = false, items = audioCards, density = density, audioDirectory = audioDirectory,
                selectedId = null, playingId = null, l = l10n, onSelect = {}, onTogglePlay = {},
                onRename = {}, onDelete = {}, onChanged = {}, zIndexOf = zIndexOf
            )
            Model3DLayer(
                interactive = false, models = models, density = density, selectedId = null, onSelect = {},
                onEdit = {}, onChanged = {}, zIndexOf = zIndexOf
            )
            CommentLayer(
                pins = pins, pageIndex = pageIndex, interactive = false, onOpen = {}, onMoved = {},
                density = density
            )
        }
    }
}
