package com.kairumo.padnote.canvas

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import com.kairumo.padnote.ink.InkEngine
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

    /**
     * 選到的筆畫實際佔的範圍。套索圈到大半就算選中，筆畫會露出圈外；
     * 拖曳命中與工具列位置要用「圈 ∪ 筆畫」才不會抓不到露出去的那段。
     */
    var strokeBounds by mutableStateOf<Rect?>(null)
        private set

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

    val hasSelection: Boolean get() = selected.isNotEmpty()
    val canPaste: Boolean get() = clipboard.isNotEmpty()

    /** 選取框（頁面點）＝ 圈 ∪ 選中筆畫的外框。 */
    val boundingRect: Rect?
        get() {
            val loop = committedRect() ?: return strokeBounds
            val strokes = strokeBounds ?: return loop
            return Rect(
                minOf(loop.left, strokes.left), minOf(loop.top, strokes.top),
                maxOf(loop.right, strokes.right), maxOf(loop.bottom, strokes.bottom)
            )
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
        committed = emptyList()
        strokeBounds = null
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

    /** 放開手指：拖曳中就把選取搬過去，否則算出選到哪幾筆。回傳筆畫是否改了。 */
    fun finish(backend: LassoBackend): Boolean {
        if (isDragging) {
            val delta = dragOffset
            isDragging = false
            dragStart = null
            dragOffset = Offset.Zero
            if (delta.getDistance() < 0.5f) return false
            val moved = runCatching { backend.translate(selected, delta.x, delta.y) }.getOrNull()
                ?: return false
            backend.reload()
            selected = moved
            committed = committed.map { it + delta }
            strokeBounds = backend.bounds(moved) ?: strokeBounds?.translate(delta)
            return true
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
        selected = picked
        // 沒選到東西就不要留著那一圈 —— 畫面上掛著一個空的虛線框，
        // 使用者會以為選取還在。
        committed = if (picked.isEmpty()) emptyList() else drawn
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
        committed = box
        strokeBounds = committedRect()
    }

    fun clear() {
        cancelGesture()
        selected = emptyList()
        committed = emptyList()
        strokeBounds = null
    }

    // ── 動作 ──────────────────────────────────────────────────
    //
    // 每一個改了筆畫的動作做完都要 `reload()`：核心已經改了，但 `InkEngine`
    // 記憶體裡那份還是動作前的 —— 不重讀的話畫面毫無變化，使用者會
    // 以為按鈕沒有作用。

    /** 回傳是否真的改了東西（呼叫端據此決定要不要重繪）。 */
    fun delete(backend: LassoBackend): Boolean {
        val changed = runCatching { backend.delete(selected) }.getOrDefault(false)
        if (changed) {
            backend.reload()
            clear()
        }
        return changed
    }

    fun copy(backend: LassoBackend): Boolean {
        clipboard = runCatching { backend.copy(selected) }.getOrDefault(emptyList())
        clipboardFromCut = false
        // 複製不改內容，所以不必重讀，也不清掉選取 ——
        // 使用者常常是「複製完再貼一次」。
        return false
    }

    fun cut(backend: LassoBackend): Boolean {
        copy(backend)
        clipboardFromCut = true
        return delete(backend)
    }

    /** 再製：偏移一點放一份新的，並**選著新的那一份**，馬上能拖走。 */
    fun duplicate(backend: LassoBackend): Boolean {
        val created = runCatching {
            backend.paste(backend.copy(selected), OFFSET, OFFSET)
        }.getOrDefault(emptyList())
        if (created.isEmpty()) return false
        backend.reload()
        selectNew(created, backend)
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
        selectNew(created, backend)
        // 同一份再貼一次就不要再疊在同一個位置。
        clipboardFromCut = false
        return true
    }

    /**
     * 把剛產生的筆畫設成目前選取，用它們的外框當選取框。
     * 不然新的一份疊在原物件上，再圈一次會連原物件一起圈到。
     */
    private fun selectNew(ids: List<String>, backend: LassoBackend) {
        cancelGesture()
        selected = ids
        strokeBounds = backend.bounds(ids)
        committed = strokeBounds?.inflate(8f)?.let {
            listOf(it.topLeft, it.topRight, it.bottomRight, it.bottomLeft)
        } ?: emptyList()
    }

    // ── 引擎介面（呼叫端不必自己包 backend） ───────────────────────

    fun finish(engine: InkEngine): Boolean = finish(EngineLassoBackend(engine))
    fun delete(engine: InkEngine): Boolean = delete(EngineLassoBackend(engine))
    fun copy(engine: InkEngine): Boolean = copy(EngineLassoBackend(engine))
    fun cut(engine: InkEngine): Boolean = cut(EngineLassoBackend(engine))
    fun duplicate(engine: InkEngine): Boolean = duplicate(EngineLassoBackend(engine))
    fun paste(engine: InkEngine): Boolean = paste(EngineLassoBackend(engine))

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
