package com.kairumo.padnote.canvas

import com.kairumo.padnote.audio.AudioObject
import com.kairumo.padnote.chart.ChartObject
import com.kairumo.padnote.image.LinkObject
import com.kairumo.padnote.image.NoteImage
import com.kairumo.padnote.model3d.Model3DObject
import com.kairumo.padnote.shape.NoteConnection
import com.kairumo.padnote.shape.NoteShape
import com.kairumo.padnote.table.NoteTable
import com.kairumo.padnote.text.TextBox

/**
 * 一頁畫布上的所有物件（不含筆跡 —— 筆跡由 `InkEngine` 自己復原）。
 *
 * 每一份都是**深複本**：物件在拖曳時是就地改的（`box.x += …`），
 * 共用同一個實例的話，「改之前」那份會跟著一起變，復原就退不回去。
 */
data class CanvasSnapshot(
    val texts: List<TextBox> = emptyList(),
    val images: List<NoteImage> = emptyList(),
    val shapes: List<NoteShape> = emptyList(),
    val connections: List<NoteConnection> = emptyList(),
    val tables: List<NoteTable> = emptyList(),
    val charts: List<ChartObject> = emptyList(),
    val links: List<LinkObject> = emptyList(),
    val models3D: List<Model3DObject> = emptyList(),
    val audio: List<AudioObject> = emptyList(),
    val order: List<String> = emptyList()
) {
    /** 這一次動到了哪些物件。用來判斷「同一個東西的連續小變動」要不要合併成一步。 */
    fun changedKeys(other: CanvasSnapshot): Set<String> {
        val keys = mutableSetOf<String>()
        fun <T> diff(a: List<T>, b: List<T>, id: (T) -> String) {
            val left = a.associateBy(id)
            val right = b.associateBy(id)
            for ((k, v) in left) if (right[k] != v) keys += k
            for (k in right.keys) if (k !in left) keys += k
        }
        diff(texts, other.texts) { it.id }
        diff(images, other.images) { it.id }
        diff(shapes, other.shapes) { it.id }
        diff(connections, other.connections) { it.id }
        diff(tables, other.tables) { it.id }
        diff(charts, other.charts) { it.id }
        diff(links, other.links) { it.id }
        diff(models3D, other.models3D) { it.id }
        diff(audio, other.audio) { it.id }
        if (order != other.order) keys += "#order"
        return keys
    }
}

/**
 * 畫布的全域復原／重做：筆跡與物件在**同一條時間軸**上，照發生順序退回。
 *
 * 原本 Android 的復原只認筆跡（`InkEngine`）：搬圖、刪表格、改形狀顏色、調圖層 ——
 * 按復原都沒有反應。與 Apple 端（`CanvasHistory.swift`）同一套規則：
 * - 筆跡的每一步記一個「筆跡」標記，復原時交給 `InkEngine.undo()`。
 * - 物件的每一步記「改之前／改之後」兩份快照。
 * - 同一個物件在短時間內的連續變動（打字、拖滑桿）合併成一步。
 * - 套用復原期間的變動不記（否則復原本身又變成一步）。
 */
class CanvasHistory(
    private val clock: () -> Long = System::currentTimeMillis
) {
    /**
     * 一步。[page] 是頁面 id：連續頁面模式下時間軸跨頁（在第 3 頁畫一筆、到第 5 頁搬一張圖，
     * 復原要先回第 5 頁、再回第 3 頁）。單頁模式一律是空字串。
     */
    sealed interface Step {
        val page: String
        data class Ink(override val page: String) : Step
        class Objects(override val page: String, val before: CanvasSnapshot, var after: CanvasSnapshot) : Step
    }

    private val undoSteps = ArrayDeque<Step>()
    private val redoSteps = ArrayDeque<Step>()
    /** 每一頁各自的基準（連續模式下每一頁的物件各自比對）。 */
    private val baselines = HashMap<String, CanvasSnapshot>()
    private var lastKeys: Set<String> = emptySet()
    private var lastPage: String? = null
    private var lastTime = 0L
    private var coalescingBroken = true

    val canUndo: Boolean get() = undoSteps.isNotEmpty()
    val canRedo: Boolean get() = redoSteps.isNotEmpty()

    /** 以目前的內容為基準重新開始（開頁、或內容被整份換掉）。 */
    fun reset(snapshot: CanvasSnapshot, page: String = "") {
        baselines[page] = snapshot
        coalescingBroken = true
    }

    /** 這一頁有沒有基準（連續模式第一次讀進來時用來分辨「讀進來」與「改了」）。 */
    fun hasBaseline(page: String = ""): Boolean = baselines.containsKey(page)

    /** 下一次變更另起一步，不併進前一步。 */
    fun breakCoalescing() {
        coalescingBroken = true
    }

    /** 筆跡多了一個可復原的動作（畫了一筆、擦除、搬移筆畫…）。 */
    fun inkCommitted(page: String = "") {
        undoSteps.addLast(Step.Ink(page))
        redoSteps.clear()
        coalescingBroken = true
    }

    /** 物件可能變了：跟上一次比，不同就記一步（或併進上一步）。 */
    fun observe(snapshot: CanvasSnapshot, page: String = "", coalescingWindowMs: Long = 1500) {
        val before = baselines[page] ?: run { reset(snapshot, page); return }
        if (snapshot == before) return
        baselines[page] = snapshot
        val keys = snapshot.changedKeys(before)
        val now = clock()
        val last = undoSteps.lastOrNull()
        // 只改了圖層順序、緊接在上一步之後：那是插入物件後「新物件放到最上層」的後續，
        // 不是使用者另一個動作 —— 併進去，否則插入一個物件要按兩次復原。
        val orderFollowUp = keys == setOf("#order")
        if (!coalescingBroken && last is Step.Objects && last.page == page && lastPage == page &&
            (keys == lastKeys || orderFollowUp) && now - lastTime < coalescingWindowMs
        ) {
            last.after = snapshot
        } else {
            undoSteps.addLast(Step.Objects(page, before, snapshot))
        }
        redoSteps.clear()
        if (!orderFollowUp) lastKeys = keys
        lastPage = page
        lastTime = now
        coalescingBroken = false
    }

    /**
     * 退一步（單頁模式）。回傳有沒有退。
     * @param applyObjects 把畫布物件換成這一份。
     * @param undoInk 交給筆跡引擎退一筆，回傳它有沒有真的退。
     */
    fun undo(applyObjects: (CanvasSnapshot) -> Unit, undoInk: () -> Boolean): Boolean =
        undoAcrossPages({ _, snapshot -> applyObjects(snapshot) }, { undoInk() })

    fun redo(applyObjects: (CanvasSnapshot) -> Unit, redoInk: () -> Boolean): Boolean =
        redoAcrossPages({ _, snapshot -> applyObjects(snapshot) }, { redoInk() })

    /** 退一步（連續頁面模式）：交給那一步所屬的頁面處理。 */
    fun undoAcrossPages(
        applyObjects: (page: String, snapshot: CanvasSnapshot) -> Unit,
        undoInk: (page: String) -> Boolean
    ): Boolean {
        val step = undoSteps.removeLastOrNull() ?: return false
        when (step) {
            is Step.Ink -> if (!undoInk(step.page)) return undoAcrossPages(applyObjects, undoInk)
            is Step.Objects -> {
                applyObjects(step.page, step.before)
                baselines[step.page] = step.before
            }
        }
        redoSteps.addLast(step)
        coalescingBroken = true
        return true
    }

    fun redoAcrossPages(
        applyObjects: (page: String, snapshot: CanvasSnapshot) -> Unit,
        redoInk: (page: String) -> Boolean
    ): Boolean {
        val step = redoSteps.removeLastOrNull() ?: return false
        when (step) {
            is Step.Ink -> if (!redoInk(step.page)) return redoAcrossPages(applyObjects, redoInk)
            is Step.Objects -> {
                applyObjects(step.page, step.after)
                baselines[step.page] = step.after
            }
        }
        undoSteps.addLast(step)
        coalescingBroken = true
        return true
    }
}

/**
 * 外層工具列的復原／重做按鈕要驅動連續頁面模式時用的接頭。
 *
 * 連續模式的頁面引擎與物件都在 `ContinuousPagesView` 裡面，外層拿不到；
 * 由它把自己的復原／重做掛上來，外層照樣只按一顆鈕。
 */
class ContinuousUndoController {
    internal var undoHandler: (() -> Boolean)? = null
    internal var redoHandler: (() -> Boolean)? = null

    fun undo(): Boolean = undoHandler?.invoke() ?: false
    fun redo(): Boolean = redoHandler?.invoke() ?: false
}
