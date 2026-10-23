package com.kairumo.padnote.canvas

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import com.kairumo.padnote.audio.AudioObject
import com.kairumo.padnote.chart.ChartObject
import com.kairumo.padnote.image.LinkObject
import com.kairumo.padnote.image.NoteImage
import com.kairumo.padnote.ink.PageGeometry
import com.kairumo.padnote.model3d.Model3DObject
import com.kairumo.padnote.shape.NoteShape
import com.kairumo.padnote.table.NoteTable
import com.kairumo.padnote.text.TextBox

/**
 * 剪貼簿上的一個畫布物件（支援單頁與連續模式跨頁剪下、複製、貼上）。
 *
 * 存完整結構與圖片原始位元組，而非只存 ID：如此「剪下」把原件從頁面移除後，
 * 貼到本頁或其他頁任何位置時仍然能完整重建。
 */
sealed class ClipboardObject {
    abstract val frame: Rect

    data class Image(val item: NoteImage, val blobBytes: ByteArray?) : ClipboardObject() {
        override val frame: Rect
            get() = Rect(item.x, item.y, item.x + item.width, item.y + item.height)
    }

    data class Text(val item: TextBox) : ClipboardObject() {
        override val frame: Rect
            get() = Rect(item.x, item.y, item.x + item.width, item.y + item.height)
    }

    data class Table(val item: NoteTable) : ClipboardObject() {
        override val frame: Rect
            get() = Rect(item.x, item.y, item.x + item.width, item.y + item.height)
    }

    data class Chart(val item: ChartObject) : ClipboardObject() {
        override val frame: Rect
            get() = Rect(item.x, item.y, item.x + item.width, item.y + item.height)
    }

    data class Shape(val item: NoteShape) : ClipboardObject() {
        override val frame: Rect
            get() = Rect(item.x, item.y, item.x + item.width, item.y + item.height)
    }

    data class Link(val item: LinkObject) : ClipboardObject() {
        override val frame: Rect
            get() = Rect(item.x, item.y, item.x + item.width, item.y + item.height)
    }

    data class Model3D(val item: Model3DObject) : ClipboardObject() {
        override val frame: Rect
            get() = Rect(item.x, item.y, item.x + item.width, item.y + item.height)
    }

    data class Audio(val item: AudioObject) : ClipboardObject() {
        override val frame: Rect
            get() = Rect(item.x, item.y, item.x + item.width, item.y + item.height)
    }
}

/**
 * 畫布物件的框選（Android）。
 *
 * 與 Apple 的 `ObjectMarquee` 同一套規則：
 *
 * - 框選是一個**明確的模式**，不是「在空白處拖曳」。打字模式下拖曳已經有
 *   兩個意思（拖物件＝搬它、拖空白＝捲畫布），再疊一個上去三者會互相搶。
 * - 判定用**相交**不是「完全包住」：使用者掃過一排卡片時，很少會把框拉得
 *   比那一排還大，要求完全包住的話十次有九次什麼都沒選到。
 * - 在選取範圍**裡面**開始拖＝整組搬移。
 */
data class MarqueeHit(
    val id: String,
    /** 頁面座標（點）。 */
    val x: Float,
    val y: Float,
    val width: Float,
    val height: Float
) {
    val rect: Rect get() = Rect(x, y, x + width, y + height)
}

object ObjectMarquee {

    /** 兩個角落拉出來的矩形。往左上拉也要成立。 */
    fun rect(start: Offset, end: Offset): Rect = Rect(
        minOf(start.x, end.x),
        minOf(start.y, end.y),
        maxOf(start.x, end.x),
        maxOf(start.y, end.y)
    )

    fun hits(box: Rect, candidates: List<MarqueeHit>): Set<String> {
        if (box.width <= 2f || box.height <= 2f) return emptySet()
        return candidates.filter { it.rect.overlaps(box) }.map { it.id }.toSet()
    }

    fun bounds(ids: Set<String>, candidates: List<MarqueeHit>): Rect? {
        val rects = candidates.filter { it.id in ids }.map { it.rect }
        if (rects.isEmpty()) return null
        return rects.drop(1).fold(rects.first()) { acc, r -> acc.expandToInclude(r) }
    }

    /**
     * 這一次拉框之後的選取。**連續框選**（[additive]）時新框到的加進原本的選取，不取代 ——
     * 散在頁面各處的物件可以一框一框累積起來。與 Apple 端 `ObjectMarquee.combined` 相同。
     */
    fun combined(existing: Set<String>, hits: Set<String>, additive: Boolean): Set<String> =
        if (additive) existing + hits else hits

    /**
     * 點一下的結果。點到物件：連續框選時切換它在不在選取裡；一般模式只選它。
     * 點到空白：一般模式取消選取；連續框選時保留（累積的選取不能因為手滑就沒了）。
     */
    fun tapped(id: String?, existing: Set<String>, additive: Boolean): Set<String> = when {
        id == null -> if (additive) existing else emptySet()
        !additive -> setOf(id)
        id in existing -> existing - id
        else -> existing + id
    }

    /** 點的位置上最上層的物件。候選依堆疊順序（由下到上）排列，所以從後面找。 */
    fun topmostHit(point: Offset, candidates: List<MarqueeHit>): String? =
        candidates.lastOrNull { it.rect.contains(point) }?.id

    /** 貼上／建立副本的位移。貼在原位的話使用者會以為沒成功。 */
    const val PASTE_OFFSET = 24f

    /**
     * 計算貼上一組物件時，每個物件在目標頁面上的新左上角座標（已夾回可列印範圍）。
     *
     * - [targetPoint] == null：依原位置加上 [PASTE_OFFSET] (24, 24)。
     * - [targetPoint] != null：以整組物件的聯集外框中心對齊 [targetPoint]，保留多物件之間的相對位置，
     *   單一物件時即中心對齊使用者點選的座標。
     */
    fun pasteOrigins(frames: List<Rect>, targetPoint: Offset? = null): List<Offset> {
        if (frames.isEmpty()) return emptyList()
        val dx: Float
        val dy: Float
        if (targetPoint != null) {
            val unionBounds = frames.drop(1).fold(frames.first()) { acc, r -> acc.expandToInclude(r) }
            dx = targetPoint.x - unionBounds.center.x
            dy = targetPoint.y - unionBounds.center.y
        } else {
            dx = PASTE_OFFSET
            dy = PASTE_OFFSET
        }
        return frames.map { frame ->
            val clamped = PageGeometry.clampOrigin(
                frame.left + dx,
                frame.top + dy,
                frame.width,
                frame.height
            )
            Offset(clamped.first, clamped.second)
        }
    }

    /**
     * 從某一頁擷取指定 ID 清單的物件到剪貼簿，若 [removeSource] 為 true 則一併從原頁刪除（剪下）。
     */
    fun captureFromStores(
        ids: Set<String>,
        removeSource: Boolean,
        pageIndex: Int,
        session: uniffi.padnote_core.PadnoteSession?,
        meta: com.kairumo.padnote.library.NotebookMeta,
        imageStore: com.kairumo.padnote.image.ImageStore,
        textStore: com.kairumo.padnote.text.TextBoxStore,
        tableStore: com.kairumo.padnote.table.TableStore,
        chartStore: com.kairumo.padnote.chart.ChartStore,
        shapeStore: com.kairumo.padnote.shape.ShapeStore
    ): List<ClipboardObject> {
        if (ids.isEmpty()) return emptyList()
        val out = mutableListOf<ClipboardObject>()
        var links = meta.links()
        var models = meta.models3D()
        var audio = meta.audioCards()
        var linksChanged = false
        var modelsChanged = false
        var audioChanged = false

        for (id in ids) {
            imageStore.all.firstOrNull { it.id == id }?.let { img ->
                out += ClipboardObject.Image(img.copy(), imageStore.blobBytes(img))
                if (removeSource) imageStore.remove(img)
                return@let
            }
            textStore.all.firstOrNull { it.id == id }?.let { box ->
                val copy = TextBox(box.id, box.pageIndex).apply { copyFieldsFrom(box) }
                out += ClipboardObject.Text(copy)
                if (removeSource) textStore.remove(box)
                return@let
            }
            tableStore.all.firstOrNull { it.id == id }?.let { tbl ->
                out += ClipboardObject.Table(tbl.copyTable())
                if (removeSource) tableStore.remove(tbl)
                return@let
            }
            chartStore.all.firstOrNull { it.id == id }?.let { ch ->
                out += ClipboardObject.Chart(ch.copy())
                if (removeSource) chartStore.remove(ch)
                return@let
            }
            shapeStore.all.firstOrNull { it.id == id }?.let { sh ->
                out += ClipboardObject.Shape(sh.copyShape())
                if (removeSource) shapeStore.remove(sh)
                return@let
            }
            links.firstOrNull { it.id == id && it.pageIndex == pageIndex }?.let { lk ->
                out += ClipboardObject.Link(lk.copy())
                if (removeSource) {
                    links = links.filter { it.id != id }.toMutableList()
                    linksChanged = true
                }
                return@let
            }
            models.firstOrNull { it.id == id && it.pageIndex == pageIndex }?.let { m3 ->
                out += ClipboardObject.Model3D(m3.copy())
                if (removeSource) {
                    models = models.filter { it.id != id }.toMutableList()
                    modelsChanged = true
                }
                return@let
            }
            audio.firstOrNull { it.id == id && it.pageIndex == pageIndex }?.let { au ->
                out += ClipboardObject.Audio(au.copy())
                if (removeSource) {
                    audio = audio.filter { it.id != id }.toMutableList()
                    audioChanged = true
                }
                return@let
            }
        }
        if (linksChanged) meta.setLinks(session, links)
        if (modelsChanged) meta.setModels3D(session, models)
        if (audioChanged) meta.setAudioCards(session, audio)
        return out
    }

    /**
     * 將剪貼簿物件貼到指定頁面與目標位置（[targetPoint] == null 代表預設向右下偏移 24pt），
     * 回傳新建立的物件 ID 集合。
     */
    fun pasteToStores(
        items: List<ClipboardObject>,
        targetPoint: Offset?,
        pageIndex: Int,
        session: uniffi.padnote_core.PadnoteSession?,
        meta: com.kairumo.padnote.library.NotebookMeta,
        imageStore: com.kairumo.padnote.image.ImageStore,
        textStore: com.kairumo.padnote.text.TextBoxStore,
        tableStore: com.kairumo.padnote.table.TableStore,
        chartStore: com.kairumo.padnote.chart.ChartStore,
        shapeStore: com.kairumo.padnote.shape.ShapeStore
    ): Set<String> {
        if (items.isEmpty()) return emptySet()
        val origins = pasteOrigins(items.map { it.frame }, targetPoint)
        val createdIds = mutableListOf<String>()
        val links = meta.links().toMutableList()
        val models = meta.models3D().toMutableList()
        val audio = meta.audioCards().toMutableList()
        var linksChanged = false
        var modelsChanged = false
        var audioChanged = false

        for ((clip, origin) in items.zip(origins)) {
            when (clip) {
                is ClipboardObject.Image -> {
                    imageStore.createCopy(clip.item, clip.blobBytes, origin.x, origin.y)?.let {
                        createdIds += it.id
                    }
                }
                is ClipboardObject.Text -> {
                    val created = textStore.create(origin.x, origin.y)
                    created.copyFieldsFrom(clip.item)
                    created.x = origin.x
                    created.y = origin.y
                    textStore.persist(created)
                    createdIds += created.id
                }
                is ClipboardObject.Table -> {
                    val created = tableStore.create(clip.item.copyTable().apply { x = origin.x; y = origin.y })
                    createdIds += created.id
                }
                is ClipboardObject.Chart -> {
                    val created = chartStore.createCopy(clip.item, origin.x, origin.y)
                    createdIds += created.id
                }
                is ClipboardObject.Shape -> {
                    val created = shapeStore.create(
                        clip.item.copyShape().apply { x = origin.x; y = origin.y; groupId = null }
                    )
                    createdIds += created.id
                }
                is ClipboardObject.Link -> {
                    val newId = java.util.UUID.randomUUID().toString()
                    links += clip.item.copy(id = newId, pageIndex = pageIndex, x = origin.x, y = origin.y)
                    linksChanged = true
                    createdIds += newId
                }
                is ClipboardObject.Model3D -> {
                    val newId = java.util.UUID.randomUUID().toString()
                    models += clip.item.copy(id = newId, pageIndex = pageIndex, x = origin.x, y = origin.y)
                    modelsChanged = true
                    createdIds += newId
                }
                is ClipboardObject.Audio -> {
                    val newId = java.util.UUID.randomUUID().toString()
                    audio += clip.item.copy(id = newId, pageIndex = pageIndex, x = origin.x, y = origin.y)
                    audioChanged = true
                    createdIds += newId
                }
            }
        }
        if (linksChanged) meta.setLinks(session, links)
        if (modelsChanged) meta.setModels3D(session, models)
        if (audioChanged) meta.setAudioCards(session, audio)
        if (createdIds.isNotEmpty()) {
            val updatedOrder = ObjectStacking.bringToFront(createdIds.toSet(), meta.objectOrder(pageIndex))
            meta.setObjectOrder(session, pageIndex, updatedOrder)
        }
        return createdIds.toSet()
    }

    private fun Rect.expandToInclude(other: Rect) = Rect(
        minOf(left, other.left),
        minOf(top, other.top),
        maxOf(right, other.right),
        maxOf(bottom, other.bottom)
    )
}

/**
 * 框選圖層。
 *
 * @param candidates 這一頁上每個物件的位置與大小（頁面點）。
 * @param onCommitMove 整組搬移結束時回報位移（頁面點）。
 */
@Composable
fun MarqueeLayer(
    candidates: List<MarqueeHit>,
    density: Float,
    selectedIds: Set<String>,
    /** 連續框選：新框到、點到的物件加進選取，不取代。 */
    additive: Boolean = false,
    onSelectionChange: (Set<String>) -> Unit,
    onCommitMove: (Float, Float) -> Unit,
    modifier: Modifier = Modifier
) {
    var start by remember { mutableStateOf<Offset?>(null) }
    var current by remember { mutableStateOf<Offset?>(null) }
    var groupDrag by remember { mutableStateOf(Offset.Zero) }
    val selectionBounds = ObjectMarquee.bounds(selectedIds, candidates)

    Box(modifier.fillMaxSize().zIndex(9_000f)) {
        Box(
            Modifier
                .fillMaxSize()
                .pointerInput(candidates, selectedIds, additive) {
                    detectDragGestures(
                        onDragStart = { offset ->
                            // 座標進來是像素，物件是頁面點 —— 差一個 density。
                            val page = Offset(offset.x / density, offset.y / density)
                            if (selectionBounds != null && selectionBounds.contains(page)) {
                                groupDrag = Offset.Zero
                                start = null
                            } else {
                                start = page
                                current = page
                            }
                        },
                        onDrag = { change, drag ->
                            change.consume()
                            val d = Offset(drag.x / density, drag.y / density)
                            if (start == null) {
                                groupDrag += d
                            } else {
                                current = (current ?: start!!) + d
                            }
                        },
                        onDragEnd = {
                            val s = start
                            val c = current
                            if (s != null && c != null) {
                                onSelectionChange(
                                    ObjectMarquee.combined(
                                        selectedIds,
                                        ObjectMarquee.hits(ObjectMarquee.rect(s, c), candidates),
                                        additive
                                    )
                                )
                            } else if (groupDrag != Offset.Zero) {
                                onCommitMove(groupDrag.x, groupDrag.y)
                            }
                            start = null
                            current = null
                            groupDrag = Offset.Zero
                        },
                        onDragCancel = {
                            start = null; current = null; groupDrag = Offset.Zero
                        }
                    )
                }
                .pointerInput(candidates, selectedIds, additive) {
                    // 點物件＝選它（連續框選時切換加入／移除）；點空白＝取消選取（連續框選時保留）。
                    detectTapGestures { offset ->
                        val page = Offset(offset.x / density, offset.y / density)
                        onSelectionChange(
                            ObjectMarquee.tapped(ObjectMarquee.topmostHit(page, candidates), selectedIds, additive)
                        )
                    }
                }
        )

        // 每個被選中的物件各畫一個外框。只畫一個大框的話，
        // 使用者看不出「到底選到了哪幾個」。
        for (hit in candidates) {
            if (hit.id !in selectedIds) continue
            Box(
                Modifier
                    .offset {
                        IntOffset(
                            ((hit.x + groupDrag.x) * density).toInt(),
                            ((hit.y + groupDrag.y) * density).toInt()
                        )
                    }
                    .size(hit.width.dp, hit.height.dp)
                    .border(1.5.dp, MaterialTheme.colorScheme.primary)
            )
        }

        // 拉框中的橡皮筋
        val s = start
        val c = current
        if (s != null && c != null) {
            val box = ObjectMarquee.rect(s, c)
            Box(
                Modifier
                    .offset { IntOffset((box.left * density).toInt(), (box.top * density).toInt()) }
                    .size(box.width.dp, box.height.dp)
                    .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.10f))
                    .border(1.dp, MaterialTheme.colorScheme.primary)
            )
        }
    }
}

/**
 * 物件剪貼簿與選取的浮動工具丸（支援手繪／打字兩種模式與單頁／連續兩種頁面型態）。
 *
 * - 已選取物件時：顯示「✂ 剪下」與「📋 複製」。
 * - 剪貼簿有物件時：顯示「📋 貼上」、「👆 點選位置貼上」與清除鈕。
 * - 正在點選貼上位置時：顯示「🎯 請在要貼上的頁面位置點一下」與取消鈕。
 */
@Composable
fun ObjectPastePill(
    hasSelection: Boolean,
    hasClipboard: Boolean,
    isPlacingPaste: Boolean,
    l: (String) -> String,
    onCut: () -> Unit,
    onCopy: () -> Unit,
    onPasteDefault: () -> Unit,
    onStartPlacePaste: () -> Unit,
    onCancelPlacePaste: () -> Unit,
    onClearClipboard: () -> Unit,
    modifier: Modifier = Modifier
) {
    if (!hasSelection && !hasClipboard) return
    Card(
        modifier = modifier.testTag("editor.object.paste.pill"),
        shape = RoundedCornerShape(50),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.96f)
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            if (isPlacingPaste && hasClipboard) {
                Text(
                    "🎯 " + l("tap_to_paste_object"),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.padding(horizontal = 6.dp)
                )
                TextButton(
                    onClick = onCancelPlacePaste,
                    contentPadding = PaddingValues(horizontal = 6.dp, vertical = 2.dp),
                    modifier = Modifier.testTag("editor.object.paste.cancel_place")
                ) {
                    Text("✕", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            } else {
                if (hasSelection) {
                    TextButton(
                        onClick = onCut,
                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp),
                        modifier = Modifier.testTag("editor.object.cut")
                    ) {
                        Text(
                            "✂ " + l("action_cut"),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                    TextButton(
                        onClick = onCopy,
                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp),
                        modifier = Modifier.testTag("editor.object.copy")
                    ) {
                        Text(
                            "📋 " + l("action_copy"),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                }
                if (hasClipboard) {
                    TextButton(
                        onClick = onPasteDefault,
                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp),
                        modifier = Modifier.testTag("editor.object.paste")
                    ) {
                        Text(
                            "📋 " + l("action_paste"),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                    TextButton(
                        onClick = onStartPlacePaste,
                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp),
                        modifier = Modifier.testTag("editor.object.paste_at_location")
                    ) {
                        Text(
                            "👆 " + l("paste_at_location"),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                    TextButton(
                        onClick = onClearClipboard,
                        contentPadding = PaddingValues(horizontal = 6.dp, vertical = 2.dp),
                        modifier = Modifier.testTag("editor.object.paste.clear")
                    ) {
                        Text("✕", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }
}

