package com.kairumo.padnote.canvas

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import com.kairumo.padnote.ink.InkEngine
import com.kairumo.padnote.ink.PageGeometry
import uniffi.padnote_core.FullStroke

/**
 * 套索選取（Android）。
 *
 * # 判定規則在核心，與 Apple 同一份
 *
 * 「圈到算不算選到」走核心的 `lassoSelect`，Apple 走 `lassoEncloses`——
 * 同一段幾何程式碼。各寫一份的話，同一個圈選會在 iPad 上選得到、在
 * Android 上選不到，而使用者會描述成「Android 的套索很難用」。
 *
 * # 為什麼 Android 這邊直接吃核心的筆畫
 *
 * Android 的墨跡本來就寫在核心裡（`InkEngine` 每一筆都 `add_stroke`），
 * 所以選取、刪除、複製、貼上全部可以在核心完成。Apple 不行——它編輯中
 * 的真相來源是 PencilKit 的 `PKDrawing`，核心只有在匯出／匯入時才被寫到，
 * 所以那邊是拿點去問核心的規則，自己改 `PKDrawing`。
 *
 * **後端不同，規則同一條。** 核心的那幾個呼叫包在 [LassoBackend] 後面，
 * 選取的狀態機（拖曳、再製後選著新的一份、剪下原位貼回）才能在 JVM 上測。
 *
 * # 座標
 *
 * 這裡的點一律是**頁面點**（與核心筆畫同一套），與 Apple 的 `LassoSelection` 一致。
 * 手勢收到的是 Compose 的像素，要先除以 density（縮放與捲動由畫布的
 * `graphicsLayer` 反變換掉）；畫選取框與工具列時再換回畫面座標。
 * 不換算的話，在 3x 的手機上圈選會差三倍，症狀是「圈很大一圈卻什麼都沒選到」。
 */
class LassoSelection {

    /** 正在畫的那一圈（頁面點）。空的表示沒有在圈。 */
    var path by mutableStateOf<List<Offset>>(emptyList())
        private set

    /** 圈完之後那一圈仍然留著，讓使用者看得到選取範圍（頁面點）。 */
    var committed by mutableStateOf<List<Offset>>(emptyList())
        private set

    /** 選到的核心筆畫 id。 */
    var selected by mutableStateOf<List<String>>(emptyList())
        private set

    /** 選到的畫布物件 id（貼紙／圖片、形狀、文字方塊、表格、圖表）。 */
    var selectedObjectIds by mutableStateOf<Set<String>>(emptySet())
        private set

    /**
     * 選到的筆畫實際佔的範圍。套索圈到大半就算選中，筆畫會露出圈外；
     * 拖曳命中與工具列位置要用「圈 ∪ 筆畫」才不會抓不到露出去的那段。
     */
    var strokeBounds by mutableStateOf<Rect?>(null)
        private set

    /** 選到的畫布物件實際佔的範圍。 */
    var objectBounds by mutableStateOf<Rect?>(null)
        private set

    var objectCandidates: () -> List<MarqueeHit> = { emptyList() }
    var onMoveObjects: (Set<String>, Offset) -> Unit = { _, _ -> }
    var onDeleteObjects: (Set<String>) -> Boolean = { false }
    var onCopyObjects: (Set<String>) -> Unit = {}
    var onCutObjects: (Set<String>) -> Boolean = { false }
    var onDuplicateObjects: (Set<String>) -> List<MarqueeHit> = { emptyList() }

    /** 正在拖曳選取範圍。 */
    var isDragging by mutableStateOf(false)
        private set

    /**
     * 拖曳中累積的位移（頁面點）。**放開才真的搬**：核心的平移是「刪掉再加回去」，
     * 每一幀都搬的話 oplog 會多出幾百筆墓碑，同步與復原都被灌爆。
     */
    var dragOffset by mutableStateOf(Offset.Zero)
        private set
    private var dragStart: Offset? = null

    /**
     * 剪貼簿。**不用系統剪貼簿**：筆畫沒有標準的貼上格式，
     * 貼到別的 App 對方也讀不懂。要是 state：剪下之後選取清空，畫面要靠它決定還要不要顯示「貼上」。
     */
    private var clipboard by mutableStateOf<List<Any>>(emptyList())
    /** 剪貼簿是剪下來的（原位貼回）還是複製的（錯開一點貼，看得出是新的一份）。 */
    private var clipboardFromCut = false

    val hasSelection: Boolean get() = selected.isNotEmpty() || selectedObjectIds.isNotEmpty()

    /**
     * 拖曳中要畫在新位置的筆畫與位移（頁面點）；沒在拖曳回 null。
     *
     * 畫布在繪製階段讀它，讓**筆跡本身**跟著選取框走（與 iPad 一致）。核心要等放開才搬
     * （見 [dragOffset]），所以拖曳中畫面靠這個；放開之後核心已經搬好，這裡回 null，
     * 不會畫兩次位移。
     */
    fun dragPreview(): LassoDragPreview? {
        if (!isDragging) return null
        val offset = dragOffset
        if (offset == Offset.Zero || selected.isEmpty()) return null
        return LassoDragPreview(selected.toSet(), offset)
    }
    val canPaste: Boolean get() = clipboard.isNotEmpty()

    /** 選取框（頁面點）＝ 圈 ∪ 選中筆畫的外框 ∪ 選中物件的外框。 */
    val boundingRect: Rect?
        get() {
            var acc = committedRect()
            strokeBounds?.let { b ->
                acc = acc?.let {
                    Rect(minOf(it.left, b.left), minOf(it.top, b.top),
                        maxOf(it.right, b.right), maxOf(it.bottom, b.bottom))
                } ?: b
            }
            objectBounds?.let { b ->
                acc = acc?.let {
                    Rect(minOf(it.left, b.left), minOf(it.top, b.top),
                        maxOf(it.right, b.right), maxOf(it.bottom, b.bottom))
                } ?: b
            }
            return acc
        }

    private fun committedRect(): Rect? {
        if (committed.isEmpty()) return null
        return Rect(
            committed.minOf { it.x }, committed.minOf { it.y },
            committed.maxOf { it.x }, committed.maxOf { it.y }
        )
    }

    // ── 圈選 ──────────────────────────────────────────────────

    /** 落下：在選取框裡就是拖曳，否則開始新的一圈。 */
    fun begin(at: Offset) {
        val box = boundingRect
        if (hasSelection && (isInsideCommitted(at) ||
                (box != null && box.inflate(HIT_SLOP).contains(at)))
        ) {
            isDragging = true
            dragStart = at
            dragOffset = Offset.Zero
            return
        }
        isDragging = false
        dragStart = null
        dragOffset = Offset.Zero
        path = listOf(at)
        selected = emptyList()
        selectedObjectIds = emptySet()
        committed = emptyList()
        strokeBounds = null
        objectBounds = null
    }

    fun extend(to: Offset) {
        if (isDragging) {
            dragStart?.let { dragOffset = to - it }
            return
        }
        val last = path.lastOrNull()
        // 太近的點不收：手指抖動會塞進上千個幾乎重合的點，而點在不在
        // 多邊形裡是 O(頂點數)，那會讓每次判定都變慢。
        if (last != null && kotlin.math.abs(last.x - to.x) < 1.5f &&
            kotlin.math.abs(last.y - to.y) < 1.5f
        ) {
            return
        }
        path = path + to
    }

    /** 放開手指：拖曳中就把選取搬過去，否則算出選到哪幾筆。回傳筆畫或物件是否改了。 */
    fun finish(backend: LassoBackend): Boolean {
        if (isDragging) {
            val delta = dragOffset
            isDragging = false
            dragStart = null
            dragOffset = Offset.Zero
            if (delta.getDistance() < 0.5f) return false
            var changed = false
            if (selected.isNotEmpty()) {
                val moved = runCatching { backend.translate(selected, delta.x, delta.y) }.getOrNull()
                if (moved != null) {
                    backend.reload()
                    selected = moved
                    strokeBounds = backend.bounds(moved) ?: strokeBounds?.translate(delta)
                    changed = true
                }
            }
            if (selectedObjectIds.isNotEmpty()) {
                onMoveObjects(selectedObjectIds, delta)
                objectBounds = objectBounds?.translate(delta)
                changed = true
            }
            if (changed) {
                committed = committed.map { it + delta }
            }
            return changed
        }
        val drawn = path
        path = emptyList()
        if (drawn.size < 3) {
            // 點一下就放開，不是圈選。清掉，不要留一個看不見的選取狀態。
            clear()
            return false
        }
        val polygon = drawn.flatMap { listOf(it.x, it.y) }
        val picked = runCatching { backend.select(polygon) }.getOrDefault(emptyList())
        val candidates = objectCandidates()
        val pickedObjects = candidates.filter { enclosesObject(drawn, it) }
        selected = picked
        selectedObjectIds = pickedObjects.map { it.id }.toSet()
        objectBounds = unionRect(pickedObjects)
        val anySelected = picked.isNotEmpty() || selectedObjectIds.isNotEmpty()
        // 沒選到東西就不要留著那一圈 —— 畫面上掛著一個空的虛線框，
        // 使用者會以為選取還在。
        committed = if (!anySelected) emptyList() else drawn
        strokeBounds = if (picked.isEmpty()) null else backend.bounds(picked)
        return false
    }

    /** 中止進行中的圈選或拖曳（長按叫出飛梭工具盤、手勢被取消）。不動已有的選取。 */
    fun cancelGesture() {
        path = emptyList()
        isDragging = false
        dragStart = null
        dragOffset = Offset.Zero
    }

    /** 程式直接選定一批核心筆畫（例如剛插入的立體圖紙），框為頁面點。 */
    fun select(ids: List<String>, box: List<Offset>) {
        if (ids.isEmpty()) return
        cancelGesture()
        selected = ids
        selectedObjectIds = emptySet()
        committed = box
        strokeBounds = committedRect()
        objectBounds = null
    }

    fun clear() {
        cancelGesture()
        selected = emptyList()
        selectedObjectIds = emptySet()
        committed = emptyList()
        strokeBounds = null
        objectBounds = null
    }

    // ── 動作 ──────────────────────────────────────────────────
    //
    // 每一個改了筆畫的動作做完都要 `reload()`：核心已經改了，但 `InkEngine`
    // 記憶體裡那份還是動作前的 —— 不重讀的話畫面毫無變化，使用者會
    // 以為按鈕沒有作用。

    /** 回傳是否真的改了東西（呼叫端據此決定要不要重繪）。 */
    fun delete(backend: LassoBackend): Boolean {
        val strokeChanged = if (selected.isNotEmpty()) {
            runCatching { backend.delete(selected) }.getOrDefault(false).also {
                if (it) backend.reload()
            }
        } else false
        val objChanged = if (selectedObjectIds.isNotEmpty()) {
            onDeleteObjects(selectedObjectIds)
        } else false
        if (strokeChanged || objChanged) {
            clear()
        }
        return strokeChanged || objChanged
    }

    fun copy(backend: LassoBackend): Boolean {
        clipboard = if (selected.isNotEmpty()) {
            runCatching { backend.copy(selected) }.getOrDefault(emptyList())
        } else emptyList()
        if (selectedObjectIds.isNotEmpty()) {
            onCopyObjects(selectedObjectIds)
        }
        clipboardFromCut = false
        // 複製不改內容，所以不必重讀，也不清掉選取 ——
        // 使用者常常是「複製完再貼一次」。
        return false
    }

    fun cut(backend: LassoBackend): Boolean {
        clipboard = if (selected.isNotEmpty()) {
            runCatching { backend.copy(selected) }.getOrDefault(emptyList())
        } else emptyList()
        clipboardFromCut = true
        val strokeChanged = if (selected.isNotEmpty()) {
            runCatching { backend.delete(selected) }.getOrDefault(false).also {
                if (it) backend.reload()
            }
        } else false
        val objChanged = if (selectedObjectIds.isNotEmpty()) {
            onCutObjects(selectedObjectIds)
        } else false
        if (strokeChanged || objChanged) {
            clear()
        }
        return strokeChanged || objChanged
    }

    /** 再製：偏移一點放一份新的，並**選著新的那一份**，馬上能拖走。 */
    fun duplicate(backend: LassoBackend): Boolean {
        val created = if (selected.isNotEmpty()) {
            runCatching {
                backend.paste(backend.copy(selected), OFFSET, OFFSET)
            }.getOrDefault(emptyList()).also {
                if (it.isNotEmpty()) backend.reload()
            }
        } else emptyList()
        val duplicatedObjs = if (selectedObjectIds.isNotEmpty()) {
            onDuplicateObjects(selectedObjectIds)
        } else emptyList()
        if (created.isEmpty() && duplicatedObjs.isEmpty()) return false
        selectNew(created, duplicatedObjs, backend)
        return true
    }

    /** 貼上：剪下的原位貼回；複製的錯開一點。貼完選著貼上的那一份。 */
    fun paste(backend: LassoBackend): Boolean {
        if (clipboard.isEmpty()) return false
        val offset = if (clipboardFromCut) 0f else OFFSET
        val created = runCatching { backend.paste(clipboard, offset, offset) }
            .getOrDefault(emptyList())
        if (created.isEmpty()) return false
        backend.reload()
        selectNew(created, emptyList(), backend)
        // 同一份再貼一次就不要再疊在同一個位置。
        clipboardFromCut = false
        return true
    }

    /**
     * 把剛產生的筆畫設成目前選取，用它們的外框當選取框。
     * 不然新的一份疊在原物件上，再圈一次會連原物件一起圈到。
     */
    private fun selectNew(ids: List<String>, objects: List<MarqueeHit>, backend: LassoBackend) {
        cancelGesture()
        selected = ids
        selectedObjectIds = objects.map { it.id }.toSet()
        strokeBounds = if (ids.isEmpty()) null else backend.bounds(ids)
        objectBounds = unionRect(objects)
        committed = boundingRect?.inflate(8f)?.let {
            listOf(it.topLeft, it.topRight, it.bottomRight, it.bottomLeft)
        } ?: emptyList()
    }

    private fun unionRect(hits: List<MarqueeHit>): Rect? {
        var acc: Rect? = null
        for (h in hits) {
            val r = Rect(h.x, h.y, h.x + h.width, h.y + h.height)
            acc = acc?.let {
                Rect(minOf(it.left, r.left), minOf(it.top, r.top),
                    maxOf(it.right, r.right), maxOf(it.bottom, r.bottom))
            } ?: r
        }
        return acc
    }

    private fun enclosesObject(poly: List<Offset>, hit: MarqueeHit): Boolean {
        if (poly.size < 3 || hit.width <= 0f || hit.height <= 0f) return false
        val center = Offset(hit.x + hit.width / 2f, hit.y + hit.height / 2f)
        if (isPointInPolygon(center, poly)) return true
        val corners = listOf(
            Offset(hit.x, hit.y),
            Offset(hit.x + hit.width, hit.y),
            Offset(hit.x + hit.width, hit.y + hit.height),
            Offset(hit.x, hit.y + hit.height)
        )
        if (corners.count { isPointInPolygon(it, poly) } >= 2) return true
        val polyRect = Rect(
            poly.minOf { it.x }, poly.minOf { it.y },
            poly.maxOf { it.x }, poly.maxOf { it.y }
        )
        val objRect = Rect(hit.x, hit.y, hit.x + hit.width, hit.y + hit.height)
        if (polyRect.overlaps(objRect)) {
            val inter = polyRect.intersect(objRect)
            val area = maxOf(1f, hit.width * hit.height)
            if (inter.width * inter.height / area >= 0.55f) return true
        }
        return false
    }

    private fun isPointInPolygon(p: Offset, poly: List<Offset>): Boolean {
        if (poly.size < 3) return false
        var inside = false
        var j = poly.size - 1
        for (i in poly.indices) {
            val a = poly[i]
            val b = poly[j]
            if ((a.y > p.y) != (b.y > p.y) &&
                p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x
            ) {
                inside = !inside
            }
            j = i
        }
        return inside
    }

    // ── 引擎介面（呼叫端不必自己包 backend） ───────────────────────

    fun finish(engine: InkEngine): Boolean = finish(EngineLassoBackend(engine))
    fun delete(engine: InkEngine): Boolean = delete(EngineLassoBackend(engine))
    fun copy(engine: InkEngine): Boolean = copy(EngineLassoBackend(engine))
    fun cut(engine: InkEngine): Boolean = cut(EngineLassoBackend(engine))
    fun duplicate(engine: InkEngine): Boolean = duplicate(EngineLassoBackend(engine))
    fun paste(engine: InkEngine): Boolean = paste(EngineLassoBackend(engine))

    /** 綁定單頁模式的畫布物件，讓套索圈選與拖曳能同時作用於未鎖定的頁面物件。 */
    fun bindPageObjects(
        candidates: List<MarqueeHit>,
        lockedIds: Set<String>,
        imageStore: com.kairumo.padnote.image.ImageStore,
        textStore: com.kairumo.padnote.text.TextBoxStore,
        tableStore: com.kairumo.padnote.table.TableStore,
        chartStore: com.kairumo.padnote.chart.ChartStore,
        shapeStore: com.kairumo.padnote.shape.ShapeStore,
        onMutated: () -> Unit
    ) {
        objectCandidates = { candidates.filter { it.id !in lockedIds } }
        onMoveObjects = { ids, delta ->
            val dx = delta.x
            val dy = delta.y
            if (ids.isNotEmpty() && (kotlin.math.abs(dx) >= 0.5f || kotlin.math.abs(dy) >= 0.5f)) {
                imageStore.all.filter { it.id in ids }.forEach { img ->
                    val (nx, ny) = PageGeometry.clampOrigin(img.x + dx, img.y + dy, img.width, img.height)
                    img.x = nx; img.y = ny
                    imageStore.persist(img)
                }
                textStore.all.filter { it.id in ids }.forEach { box ->
                    val (nx, ny) = PageGeometry.clampOrigin(box.x + dx, box.y + dy, box.width, box.height)
                    box.x = nx; box.y = ny
                    textStore.persist(box)
                }
                tableStore.all.filter { it.id in ids }.forEach { tbl ->
                    val (nx, ny) = PageGeometry.clampOrigin(tbl.x + dx, tbl.y + dy, tbl.width, tbl.layout().height.toFloat())
                    tbl.x = nx; tbl.y = ny
                    tableStore.persist(tbl)
                }
                chartStore.all.filter { it.id in ids }.forEach { ch ->
                    val (nx, ny) = PageGeometry.clampOrigin(ch.x + dx, ch.y + dy, ch.width, ch.height)
                    chartStore.persist(ch.copy(x = nx, y = ny))
                }
                shapeStore.all.filter { it.id in ids }.forEach { sh ->
                    val (nx, ny) = PageGeometry.clampOrigin(sh.x + dx, sh.y + dy, sh.width, sh.height)
                    shapeStore.persist(sh.copyShape().apply { x = nx; y = ny })
                }
                onMutated()
            }
        }
        onDeleteObjects = { ids ->
            var changed = false
            imageStore.all.filter { it.id in ids }.forEach { imageStore.remove(it); changed = true }
            textStore.all.filter { it.id in ids }.forEach { textStore.remove(it); changed = true }
            tableStore.all.filter { it.id in ids }.forEach { tableStore.remove(it); changed = true }
            chartStore.all.filter { it.id in ids }.forEach { chartStore.remove(it); changed = true }
            shapeStore.all.filter { it.id in ids }.forEach { shapeStore.remove(it); changed = true }
            if (changed) onMutated()
            changed
        }
    }

    private fun isInsideCommitted(p: Offset): Boolean {
        val poly = committed
        if (poly.size < 3) return false
        var inside = false
        var j = poly.size - 1
        for (i in poly.indices) {
            val a = poly[i]
            val b = poly[j]
            if ((a.y > p.y) != (b.y > p.y) &&
                p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x
            ) {
                inside = !inside
            }
            j = i
        }
        return inside
    }

    companion object {
        /** 再製與貼上的偏移量（頁面點）。與 Apple 的 `duplicateOffset` 一致。 */
        const val OFFSET = 24f
        /** 選取框外再放寬多少仍算拖曳（頁面點）。與 Apple 一致。 */
        const val HIT_SLOP = 16f
    }
}

/** 拖曳中的筆畫（核心 id）與位移（頁面點）。 */
data class LassoDragPreview(val ids: Set<String>, val offset: Offset)

/** 套索動作實際改的是誰。正式環境是核心（[EngineLassoBackend]），測試用記憶體裡的假筆畫。 */
interface LassoBackend {
    /** 圈中的筆畫 id。`polygon` 是頁面點，`[x0, y0, x1, y1, …]`。 */
    fun select(polygon: List<Float>): List<String>
    /** 這批筆畫的聯集外框（頁面點），含筆寬。 */
    fun bounds(ids: List<String>): Rect?
    fun delete(ids: List<String>): Boolean
    /** 取出筆畫內容當剪貼簿（內容不透明，原樣交回 [paste]）。 */
    fun copy(ids: List<String>): List<Any>
    /** 貼上並平移，回傳新筆畫 id。 */
    fun paste(clip: List<Any>, dx: Float, dy: Float): List<String>
    /** 原地平移，回傳新的 id（核心是刪掉再加回去，id 會變）；失敗回 null。 */
    fun translate(ids: List<String>, dx: Float, dy: Float): List<String>?
    /** 核心改完之後讓畫面那一份跟上。 */
    fun reload()
}

/** 走核心的套索 API，改完 `engine.load()`。 */
class EngineLassoBackend(private val engine: InkEngine) : LassoBackend {
    override fun select(polygon: List<Float>): List<String> {
        val (session, pageId) = engine.coreHandles() ?: return emptyList()
        return session.lassoSelect(pageId, polygon)
    }

    override fun bounds(ids: List<String>): Rect? {
        val wanted = ids.toSet()
        var rect: Rect? = null
        for (stroke in engine.strokes) {
            if (stroke.coreStrokeId !in wanted || stroke.points.isEmpty()) continue
            val pad = stroke.baseWidth / 2f
            val b = Rect(
                stroke.points.minOf { it.x } - pad, stroke.points.minOf { it.y } - pad,
                stroke.points.maxOf { it.x } + pad, stroke.points.maxOf { it.y } + pad
            )
            rect = rect?.let {
                Rect(minOf(it.left, b.left), minOf(it.top, b.top),
                    maxOf(it.right, b.right), maxOf(it.bottom, b.bottom))
            } ?: b
        }
        return rect
    }

    override fun delete(ids: List<String>): Boolean {
        val (session, pageId) = engine.coreHandles() ?: return false
        return session.lassoDelete(pageId, ids) > 0u
    }

    override fun copy(ids: List<String>): List<Any> {
        val (session, pageId) = engine.coreHandles() ?: return emptyList()
        return session.lassoCopy(pageId, ids)
    }

    override fun paste(clip: List<Any>, dx: Float, dy: Float): List<String> {
        val (session, pageId) = engine.coreHandles() ?: return emptyList()
        return session.lassoPaste(pageId, clip.filterIsInstance<FullStroke>(), dx, dy)
    }

    override fun translate(ids: List<String>, dx: Float, dy: Float): List<String>? {
        val (session, pageId) = engine.coreHandles() ?: return null
        return session.lassoTranslate(pageId, ids, dx, dy)
    }

    override fun reload() = engine.load()
}
