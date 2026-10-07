package com.kairumo.padnote.ink

import android.view.MotionEvent
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import uniffi.padnote_core.FfiPhase
import uniffi.padnote_core.FfiPoint
import uniffi.padnote_core.FfiVerdict
import uniffi.padnote_core.InkArbiter
import uniffi.padnote_core.PadnoteSession
import uniffi.padnote_core.StrokePoint
import uniffi.padnote_core.ToolKind

/**
 * Android 的筆跡引擎（工作包 WP5）。
 *
 * 把 `MotionEvent` 餵進核心的仲裁器，依判定累積或丟棄筆畫，落筆結束時寫進
 * `.padnote`。掌拒、壓感曲線、輸入模式全都是核心那一份 —— Apple 版與
 * Android 版用同一組規則，不會出現「同一支筆在兩個平台行為不一樣」。
 *
 * # `retract` 一定要處理
 *
 * 使用者的自然動作是手掌先碰螢幕、筆才落下。手掌那一筆此時**已經在畫了**，
 * 所以筆落下時仲裁器會回傳要收回的指標 id。忽略它的話，掌拒只擋得住
 * 「筆之後」的誤觸 —— 擋不住最常見的那一種。
 */
class InkEngine(
    private val session: PadnoteSession? = null,
    private val pageId: String? = null,
    private val arbiter: InkArbiter = InkArbiter()
) {

    /** 正在畫、尚未結束的一筆。 */
    private val inFlight = LinkedHashMap<ULong, MutableList<InkInput.Sample>>()

    /**
     * 有沒有一筆正在畫（指標已經落下、還沒抬起）。
     *
     * 別台裝置的更新要重開 session 時據此等一下：換掉引擎的話，落筆到一半的
     * 那一筆會消失。
     */
    val isDrawing: Boolean get() = inFlight.isNotEmpty()

    /** 已經寫進核心、但仍在可收回時間窗內的筆畫：指標 id → 核心筆畫 id。 */
    private val committed = LinkedHashMap<ULong, String>()

    /** 已完成的筆畫（沒有 session 時留在記憶體，供測試與預覽用）。 */
    private val _strokes = mutableListOf<CompletedStroke>()
    val strokes: List<CompletedStroke> get() = _strokes

    /**
     * 使用者自訂的掌拒門檻。`null` 表示沒有自訂，跟著模式走預設值。
     *
     * 自訂之後**兩種模式都用同一個數字** —— 「我設了門檻，那就是門檻」
     * 比「你設的值在某些模式下會被換掉」好解釋得多。
     */
    private var overrideRadiusDp: Float? = null
    private var overrideRetractMs: UInt? = null

    private var lastPenOnly = false

    init {
        // 預設筆與手指皆可書寫，用比較鬆的門檻 ——
        // 手指的接觸半徑本來就比筆尖大，用僅限筆的門檻會把正常手寫當成手掌。
        applyPalmThresholds(penOnly = false)
    }

    data class CompletedStroke(
        val pointerId: ULong,
        val coreStrokeId: String?,
        val points: List<StrokePoint>,
        val tool: ToolKind,
        /** 落筆時刻（毫秒）。手寫辨識靠它把筆畫依書寫停頓分組。 */
        val startedAtMs: Long,
        val colorRgba: ByteArray = byteArrayOf(0, 0, 0, -1),
        val baseWidth: Float = 3f,
        /** 製圖圖層（1 底／2 中／3 頂）。0 = 一般筆跡。 */
        val layer: Int = 0,
        /** 工程線型（0 實線、1 隱藏線、2 中心線、3 假想線）。 */
        val lineType: Int = 0,
        /**
         * 一次插入的一組筆畫（三視圖、步驟編號）共用的編號；0 = 單獨一筆。
         * 復原／重做把同一組當成**一個動作**。
         */
        val group: Int = 0
    )

    /** 一次事件處理的結果，供 UI 決定要不要重繪。 */
    data class Outcome(
        val drawnSamples: Int,
        val rejectedSamples: Int,
        val gestureSamples: Int,
        val retracted: List<ULong>,
        val completed: List<CompletedStroke>
    )

    var tool: ToolKind = ToolKind.FOUNTAIN_PEN
    var colorRgba: ByteArray = byteArrayOf(0, 0, 0, -1) // 不透明黑
    var baseWidth: Float = 3f

    /** 製圖：之後落下的筆畫寫進哪一層、用什麼線型。一般筆刷維持 0。 */
    var layer: Int = 0
    var lineType: Int = 0

    /**
     * 長按吸附的角度鎖定（度）。`null` = 沒開吸附。
     * 筆畫抬起前在終點停留超過 [SNAP_DWELL_MS]，就把這一筆釘成直線／圓／矩形／鎖角度的折線。
     */
    var snapStepDeg: Float? = null
    /** 非 null = 改圖層模式：點筆畫把它改到這一層。 */
    var reassignTarget: Int? = null

    /** 非 null = 步驟編號模式：點哪裡就通知哪裡（頁面座標），不落筆。 */
    var onMarkerTap: ((Float, Float) -> Unit)? = null

    /**
     * 非 null = 圖學工具模式（標註…）：觸控的每個階段與位置（頁面座標），不落筆。
     * 對應 Apple 的 `ProStrokeGestureRecognizer.onToolTouch`。
     */
    var onToolTouch: ((FfiPhase, Float, Float) -> Unit)? = null

    /** 目前的畫布縮放：工具要把「手指大小」的吸附半徑換成頁面單位。 */
    var toolZoom: Float = 1f
        private set

    /** 工具的預覽（標註畫到一半的樣子）與已選的點。不存檔、不進復原；每次更新整組換掉。 */
    var overlayStrokes by androidx.compose.runtime.mutableStateOf<List<uniffi.padnote_core.FfiSheetStroke>>(emptyList())
        private set
    var overlayMarks by androidx.compose.runtime.mutableStateOf<List<Offset2>>(emptyList())
        private set

    /** 這一頁的識別字（逐頁設定，例如 45° 轉折點，用它當鍵）。 */
    val pageKey: String get() = pageId ?: ""

    /** 製圖：正在畫的線對齊了哪些既有點（虛線導引），與調整後的即時預覽（靠著尺的邊、對齊吸附）。 */
    var alignGuides by androidx.compose.runtime.mutableStateOf<List<List<Offset2>>>(emptyList())
        private set
    var draftPreview by androidx.compose.runtime.mutableStateOf<List<StrokePoint>?>(null)
        private set

    /** 一個頁面座標的點（避免引擎依賴 Compose 的 `Offset`）。 */
    data class Offset2(val x: Float, val y: Float)

    fun setOverlay(strokes: List<uniffi.padnote_core.FfiSheetStroke>, marks: List<Offset2>) {
        overlayStrokes = strokes
        overlayMarks = marks
    }

    fun clearOverlay() = setOverlay(emptyList(), emptyList())

    /**
     * 離 (x, y) 最近的吸附點（半徑 [radius] 之內）：筆畫的端點、轉折點，以及圓形筆畫的圓心。
     * 標註要量準，就得釘在線的端點與圓心上，而不是手指落下的那個點。
     */
    fun snapAnchor(x: Float, y: Float, radius: Float): Offset2? {
        var best: Offset2? = null
        var bestDist = Float.MAX_VALUE
        fun consider(px: Float, py: Float) {
            val d = kotlin.math.hypot(px - x, py - y)
            if (d <= radius && d < bestDist) { best = Offset2(px, py); bestDist = d }
        }
        for (stroke in _strokes) {
            if (stroke.layer != 0 && DraftingState.isHidden(stroke.layer)) continue
            val pts = stroke.points
            if (pts.isEmpty()) continue
            consider(pts.first().x, pts.first().y)
            consider(pts.last().x, pts.last().y)
            // 吸附出來的線／多邊形只有幾個點，每個點都是轉折；手繪的長線不是。
            if (pts.size <= 12) for (p in pts) consider(p.x, p.y)
            fitCircle(pts.map { Offset2(it.x, it.y) })?.let { consider(it.first.x, it.first.y) }
        }
        return best
    }

    // ── 投影對齊與尺規靠邊 ──

    /** 對齊用的點：看得見的筆畫的端點與短折線的轉折點（上限 600 個，免得大頁面拖慢）。 */
    private fun alignAnchors(): List<uniffi.padnote_core.FfiPoint> {
        val out = ArrayList<uniffi.padnote_core.FfiPoint>()
        for (stroke in _strokes) {
            if (stroke.layer != 0 && DraftingState.isHidden(stroke.layer)) continue
            val pts = stroke.points
            if (pts.isEmpty()) continue
            out += uniffi.padnote_core.FfiPoint(pts.first().x, pts.first().y)
            out += uniffi.padnote_core.FfiPoint(pts.last().x, pts.last().y)
            if (pts.size <= 12) for (q in pts.drop(1).dropLast(1)) out += uniffi.padnote_core.FfiPoint(q.x, q.y)
            if (out.size > 600) break
        }
        return out
    }

    private fun alignedPoint(x: Float, y: Float, anchors: List<uniffi.padnote_core.FfiPoint>, guides: MutableList<List<Offset2>>): Offset2 {
        if (!DraftingState.alignEnabled) return Offset2(x, y)
        val pivot = DraftingState.pivot(pageKey)?.let { uniffi.padnote_core.FfiPoint(it.first, it.second) }
        val r = uniffi.padnote_core.draftAlign(
            uniffi.padnote_core.FfiPoint(x, y), anchors, pivot, DraftingState.thirdAngle,
            8f / toolZoom.coerceAtLeast(0.25f))
        for (g in r.guides) guides += g.points.map { Offset2(it.x, it.y) }
        return Offset2(r.point.x, r.point.y)
    }

    /**
     * 製圖線的調整：起點靠著尺的邊就整筆沿著邊走（直線）；否則起點與終點對齊既有點。
     * 與 Apple 的 `ProInkLayerView` 同一套規則。回傳調整後的筆點與要畫的導引線。
     */
    private fun draftAdjust(pts: List<StrokePoint>): Pair<List<StrokePoint>, List<List<Offset2>>> {
        if (layer == 0 || pts.isEmpty()) return pts to emptyList()
        val guides = mutableListOf<List<Offset2>>()
        val first = pts.first()
        val last = pts.last()
        val band = 14f / toolZoom.coerceAtLeast(0.25f)
        val inst = DraftingState.instrument
        val edge = inst?.nearestEdge(first.x, first.y, band)
        if (edge != null) {
            val foot = InstrumentModel.footOnLine(last.x, last.y, edge.a, edge.b)
            val n = 24
            val out = (0 until n).map { i ->
                val t = i.toFloat() / (n - 1)
                first.copy(x = edge.foot.x + (foot.x - edge.foot.x) * t, y = edge.foot.y + (foot.y - edge.foot.y) * t)
            }
            return out to emptyList()
        }
        if (!DraftingState.alignEnabled) return pts to emptyList()
        val anchors = alignAnchors()
        val a = alignedPoint(first.x, first.y, anchors, guides)
        val b = if (pts.size > 1) alignedPoint(last.x, last.y, anchors, guides) else a
        val out = pts.toMutableList()
        out[0] = first.copy(x = a.x, y = a.y)
        if (pts.size > 1) out[out.lastIndex] = last.copy(x = b.x, y = b.y)
        return out to guides
    }

    private fun updateDraftPreview() {
        if (layer == 0 || (DraftingState.instrument == null && !DraftingState.alignEnabled)) return
        val live = inFlight.values.firstOrNull() ?: return
        val raw = InkInput.strokePoints(live.toList())
        if (raw.size < 2) return
        val (adjusted, guides) = draftAdjust(raw)
        draftPreview = adjusted
        alignGuides = guides
    }

    private fun clearDraftPreview() {
        if (draftPreview != null) draftPreview = null
        if (alignGuides.isNotEmpty()) alignGuides = emptyList()
    }

    /** 手指落在尺的身體上（不是靠邊的地方）：這個指標是在搬尺，不是在畫。 */
    private var instrumentPointer: ULong? = null
    /** 這個指標是在量角器刻度帶上讀角度（不是搬尺）。 */
    private var instrumentReads = false
    private var instrumentLastX = 0f
    private var instrumentLastY = 0f

    /** 拖尺：回傳這個取樣是不是被拿來搬尺了。 */
    private fun handleInstrumentDrag(sample: InkInput.Sample): Boolean {
        val inst = DraftingState.instrument ?: return false
        if (layer == 0 || isErasing) return false
        val e = sample.event
        val band = 14f / zoom.coerceAtLeast(0.25f)
        when (e.phase) {
            FfiPhase.BEGAN -> {
                if (inst.isReadingZone(e.x, e.y) && inst.nearestEdge(e.x, e.y, band) == null) {
                    instrumentPointer = e.id
                    instrumentReads = true
                    DraftingState.readInstrument(e.x, e.y)
                    return true
                }
                if (inst.containsBody(e.x, e.y) && inst.nearestEdge(e.x, e.y, band) == null) {
                    instrumentPointer = e.id
                    instrumentReads = false
                    instrumentLastX = e.x
                    instrumentLastY = e.y
                    return true
                }
            }
            FfiPhase.MOVED -> if (instrumentPointer == e.id) {
                if (instrumentReads) {
                    DraftingState.readInstrument(e.x, e.y)
                    return true
                }
                DraftingState.moveInstrument(e.x - instrumentLastX, e.y - instrumentLastY)
                instrumentLastX = e.x
                instrumentLastY = e.y
                return true
            }
            FfiPhase.ENDED, FfiPhase.CANCELLED -> if (instrumentPointer == e.id) {
                instrumentPointer = null
                return true
            }
            else -> Unit
        }
        return false
    }

    /** (x, y) 附近的圓形筆畫（首尾相接、擬合殘差小）：回傳圓心與半徑。 */
    fun circleNear(x: Float, y: Float, radius: Float): Pair<Offset2, Float>? {
        var best: Pair<Offset2, Float>? = null
        var bestDist = Float.MAX_VALUE
        for (stroke in _strokes) {
            val fit = fitCircle(stroke.points.map { Offset2(it.x, it.y) }) ?: continue
            val d = kotlin.math.abs(kotlin.math.hypot(x - fit.first.x, y - fit.first.y) - fit.second)
            if (d <= radius + stroke.baseWidth && d < bestDist) { best = fit; bestDist = d }
        }
        return best
    }

    /** 吸附成功時通知 UI（觸覺回饋）。 */
    var onSnapped: ((uniffi.padnote_core.FfiDraftSnapKind) -> Unit)? = null

    /**
     * 擦除模式。
     *
     * 擦除不是一種筆刷 —— 核心的 `ToolKind` 只有筆刷種類，擦除走
     * `erase_stroke`。所以它是引擎的一個狀態，不是 `tool` 的一個值。
     */
    var isErasing: Boolean = false

    /**
     * 觸控筆的側鍵（或反向筆頭）狀態變了（工作項 S-67）。
     *
     * 只在**狀態真的翻面**時呼叫一次，不是每個事件都叫 —— 一次書寫會產生
     * 上百個 `ACTION_MOVE`，每個都回報的話，上層的工具列狀態每秒被寫幾十次。
     *
     * 掛在引擎上而不是各個 View：低延遲畫布（`InkSurfaceView`）與一般畫布
     * 是兩條繪製路徑，但都經過這裡。掛在 View 上會變成「只有其中一條路
     * 支援側鍵」，而使用者切不切得到低延遲取決於他的裝置。
     */
    var onPenControlChanged: ((uniffi.padnote_core.FfiPenControl?, Boolean) -> Unit)? = null

    /**
     * 有內容寫進核心了（一筆畫完、或擦掉一筆）。
     *
     * 給自動同步用：使用者停手之後推一次。**掛在引擎上而不是各個 View**，
     * 理由與 `onPenControlChanged` 相同 —— 低延遲畫布與一般畫布是兩條
     * 繪製路徑，掛在 View 上會變成「只有其中一條路會觸發同步」，
     * 而使用者切不切得到低延遲取決於他的裝置。
     */
    var onContentCommitted: (() -> Unit)? = null

    /** 筆跡磁吸對齊開關 (Smart Magnetic Snap) */
    var isMagneticSnapActive: Boolean = false
    /** 磁吸吸附觸發回呼 (起點, 吸附終點) */
    var onMagneticSnap: ((androidx.compose.ui.geometry.Offset, androidx.compose.ui.geometry.Offset) -> Unit)? = null

    /** 上一次看到的側鍵狀態。用來只在翻面時通知。 */
    private var heldControl: uniffi.padnote_core.FfiPenControl? = null

    // ── 復原／重做（S-64 的缺口：Android 完全沒有這一層）────────────
    //
    // Apple 端的畫布交給 PencilKit 的 `undoManager`，Android 自己畫，
    // 所以要自己記。記的是**被拿掉的筆畫本身**，不是「一個動作」——
    // 重做時把同一筆原樣加回核心（新的 id），畫面與落盤一起回來。
    //
    // 只管筆畫。文字、圖片與表格是另一層物件，它們的復原走各自的資料流，
    // 混在同一個堆疊裡的話，「復原」會變成使用者猜不到的東西。
    private val undoStack = mutableListOf<CompletedStroke>()
    private val redoStack = mutableListOf<CompletedStroke>()

    val canUndo: Boolean get() = _strokes.isNotEmpty()
    val canRedo: Boolean get() = redoStack.isNotEmpty()

    /** 收回最後一筆（或最後一次插入的一整組）。回傳是否真的收回了東西。 */
    fun undo(): Boolean {
        val act = acts.lastOrNull()
        if (act is ReplaceAct) {
            acts.removeLast()
            act.removed = swapStrokes(remove = act.added, add = act.removed)
            redoActs += act
            return true
        }
        if (act is ReassignAct) {
            acts.removeLast()
            if (setLayerOf(act.key, act.from)) {
                redoActs += act
                return true
            }
        } else if (act != null) {
            acts.removeLast()
        }
        val last = _strokes.lastOrNull() ?: return false
        redoActs += AddAct
        val removed = if (last.group != 0) _strokes.filter { it.group == last.group } else listOf(last)
        val target = session
        val page = pageId
        for (stroke in removed) {
            _strokes.remove(stroke)
            stroke.coreStrokeId?.let { id ->
                if (target != null && page != null) runCatching { target.eraseStroke(page, id) }
            }
        }
        redoStack += removed.asReversed()
        return true
    }

    /** 把最後一次收回的筆畫（或整組）放回去。 */
    fun redo(): Boolean {
        val next = redoActs.lastOrNull()
        if (next is ReplaceAct) {
            redoActs.removeLast()
            next.added = swapStrokes(remove = next.removed, add = next.added)
            acts += next
            return true
        }
        if (next is ReassignAct) {
            redoActs.removeLast()
            if (setLayerOf(next.key, next.to)) {
                acts += next
                return true
            }
        } else if (next != null) {
            redoActs.removeLast()
        }
        val first = redoStack.removeLastOrNull() ?: return false
        acts += AddAct
        val batch = mutableListOf(first)
        if (first.group != 0) {
            while (redoStack.lastOrNull()?.group == first.group) batch += redoStack.removeLast()
        }
        val target = session
        val page = pageId
        for (stroke in batch) {
            val newId = if (target != null && page != null) {
                runCatching {
                    target.addStrokeDrafted(
                        page, stroke.tool, stroke.colorRgba, stroke.baseWidth, stroke.points,
                        stroke.layer.toUByte(), stroke.lineType.toUByte()
                    )
                }.getOrNull()
            } else {
                null
            }
            _strokes += stroke.copy(coreStrokeId = newId)
        }
        return true
    }

    private var nextGroup = 1

    /**
     * 把核心排好的製圖線整組插進這一頁（三視圖、步驟編號），原點偏移 `(ox, oy)`。
     * 整組是**一次復原**。回傳插入的筆畫數。
     *
     * 兩點的直線補點到每 4 個頁面單位一點：虛線與點畫線的間隔由筆點陣挖出來，點太稀會失準。
     */
    /** 最近一次 [insertDrafted] 寫進核心的筆畫 id（插入後用套索選住它）。 */
    var lastInsertedCoreIds: List<String> = emptyList()
        private set

    fun insertDrafted(items: List<uniffi.padnote_core.FfiSheetStroke>, ox: Float, oy: Float): Int {
        val inserted = mutableListOf<String>()
        val target = session
        val page = pageId
        val group = nextGroup++
        var count = 0
        for (item in items) {
            if (item.points.size < 2) continue
            val pts = DraftingState.points(item, ox, oy)
            val rgba = DraftingState.rgba(item.colorHex)
            val coreId = if (target != null && page != null) {
                runCatching {
                    target.addStrokeDrafted(
                        page, ToolKind.FINELINER, rgba, item.width, pts,
                        item.layer, item.lineType
                    )
                }.getOrNull()
            } else null
            coreId?.let { inserted += it }
            _strokes += CompletedStroke(
                pointerId = ULong.MAX_VALUE - 1_000_000uL - _strokes.size.toULong(),
                coreStrokeId = coreId,
                points = pts,
                tool = ToolKind.FINELINER,
                startedAtMs = System.currentTimeMillis(),
                colorRgba = rgba,
                baseWidth = item.width,
                layer = item.layer.toInt(),
                lineType = item.lineType.toInt(),
                group = group
            )
            count++
        }
        lastInsertedCoreIds = inserted
        if (count > 0) {
            redoStack.clear()
            redoActs.clear()
            acts += AddAct
            onContentCommitted?.invoke()
        }
        return count
    }

    // ── 編輯工具（修剪、延伸、圓角、偏移、鏡射、陣列）──

    private var syntheticId = 0uL

    /** 編輯工具做出來的筆畫沒有硬體指標：用一段不會與真指標撞號的編號（改圖層靠 pointerId 認筆畫）。 */
    private fun nextSyntheticId(): ULong = ULong.MAX_VALUE - 2_000_000uL - syntheticId++

    private fun coreAdd(s: CompletedStroke): CompletedStroke {
        val target = session
        val page = pageId
        val id = if (target != null && page != null) {
            runCatching {
                target.addStrokeDrafted(
                    page, s.tool, s.colorRgba, s.baseWidth, s.points, s.layer.toUByte(), s.lineType.toUByte())
            }.getOrNull()
        } else null
        return s.copy(coreStrokeId = id)
    }

    private fun coreErase(s: CompletedStroke) {
        val target = session
        val page = pageId
        val id = s.coreStrokeId
        if (target != null && page != null && id != null) runCatching { target.eraseStroke(page, id) }
    }

    /** 把 [remove]（以實例認）換成 [add]。回傳真正放進去的實例（核心重新發了 id）。 */
    private fun swapStrokes(remove: List<CompletedStroke>, add: List<CompletedStroke>): List<CompletedStroke> {
        for (s in remove) {
            _strokes.removeAll { it === s }
            coreErase(s)
        }
        val added = add.map { coreAdd(it) }
        _strokes += added
        onContentCommitted?.invoke()
        return added
    }

    /** 離 (x, y) 最近的一筆（[radius] 之內）；隱藏的圖層不算，[editable] 時鎖住的也不算。疊在一起取最晚畫的。 */
    fun strokeNear(x: Float, y: Float, radius: Float, editable: Boolean = true): CompletedStroke? {
        var best: CompletedStroke? = null
        var bestD = Float.MAX_VALUE
        for (stroke in _strokes) {
            if (stroke.layer != 0) {
                if (DraftingState.isHidden(stroke.layer)) continue
                if (editable && DraftingState.isLocked(stroke.layer)) continue
            }
            var d = Float.MAX_VALUE
            val pts = stroke.points
            if (pts.size == 1) d = kotlin.math.hypot(pts[0].x - x, pts[0].y - y)
            for (k in 1 until pts.size) d = minOf(d, distToSegment(x, y, pts[k - 1], pts[k]))
            if (d <= radius + stroke.baseWidth * 0.5f && d <= bestD) { best = stroke; bestD = d }
        }
        return best
    }

    /** 其他看得見的筆畫（修剪、延伸要對著它們找交點）。 */
    fun polylinesExcluding(exclude: Collection<CompletedStroke>): List<uniffi.padnote_core.FfiPolyline> =
        _strokes.filter { s -> exclude.none { it === s } && (s.layer == 0 || !DraftingState.isHidden(s.layer)) }
            .map { s -> uniffi.padnote_core.FfiPolyline(s.points.map { uniffi.padnote_core.FfiPoint(it.x, it.y) }) }

    /** 套索選到的那批筆畫（以核心 id 認）。 */
    fun strokesByCoreIds(ids: Collection<String>): List<CompletedStroke> =
        _strokes.filter { it.coreStrokeId != null && it.coreStrokeId in ids }

    /** 核心給的折線 → 筆點；直線段補點到每 4 個頁面單位一點（虛線與點畫線靠它）。 */
    private fun densify(items: List<uniffi.padnote_core.FfiPoint>, pressure: Float): List<StrokePoint> {
        val out = ArrayList<StrokePoint>()
        fun add(x: Float, y: Float) {
            out += StrokePoint(x = x, y = y, pressure = pressure, tilt = 0f, azimuth = 0f, dtUs = 2000u, roll = 0f)
        }
        if (items.isEmpty()) return out
        add(items[0].x, items[0].y)
        for (k in 1 until items.size) {
            val a = items[k - 1]
            val b = items[k]
            val n = maxOf(1, kotlin.math.ceil(kotlin.math.hypot(b.x - a.x, b.y - a.y) / 4f).toInt())
            for (i in 1..n) {
                val t = i.toFloat() / n
                add(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
            }
        }
        return out
    }

    /** 以 [base] 的筆、顏色、圖層、線型做一筆新的，點換成 [points]。 */
    fun derive(base: CompletedStroke, points: List<uniffi.padnote_core.FfiPoint>): CompletedStroke =
        base.copy(
            pointerId = nextSyntheticId(), coreStrokeId = null, group = 0,
            points = densify(points, base.points.firstOrNull()?.pressure ?: 0.6f))

    /** 同一筆、點數不變、位置換掉（鏡射、陣列的複本）。 */
    fun moved(base: CompletedStroke, points: List<uniffi.padnote_core.FfiPoint>): CompletedStroke =
        base.copy(
            pointerId = nextSyntheticId(), coreStrokeId = null, group = 0,
            points = base.points.mapIndexed { i, p ->
                val q = points.getOrNull(i) ?: return@mapIndexed p
                p.copy(x = q.x, y = q.y)
            })

    /** 原來的筆畫換成新的一組，**一次復原**。 */
    fun replaceStrokes(old: List<CompletedStroke>, new: List<CompletedStroke>): Boolean {
        if (old.isEmpty() && new.isEmpty()) return false
        val added = swapStrokes(remove = old, add = new)
        redoStack.clear()
        redoActs.clear()
        acts += ReplaceAct(old, added)
        return true
    }

    /** 加一組做好的複本（偏移、鏡射、陣列），一次復原。回傳數量。 */
    fun insertCopies(copies: List<CompletedStroke>): Int {
        if (copies.isEmpty()) return 0
        val group = nextGroup++
        for (c in copies) _strokes += coreAdd(c.copy(group = group))
        redoStack.clear()
        redoActs.clear()
        acts += AddAct
        onContentCommitted?.invoke()
        return copies.size
    }

    /** 頁面上所有筆畫的點（立體輔助從裡面找封閉輪廓）。 */
    fun sketchPolylines(): List<List<uniffi.padnote_core.FfiPoint>> =
        // 中層（輔助線與步驟編號）不算：步驟編號是一個個小圓圈，會被當成最小的封閉圖形。
        _strokes.filter { it.layer != 2 }.map { s -> s.points.map { uniffi.padnote_core.FfiPoint(it.x, it.y) } }

    /**
     * 擦掉碰到的筆畫。
     *
     * 用「碰到就整筆擦掉」而不是切斷筆畫：切斷需要把一筆拆成兩筆並改寫取樣點，
     * 那會破壞「存原始取樣點」的不變式（ADR-0002）。整筆擦除是 append-only
     * 的墓碑，與同步、回溯都相容。
     */
    private fun eraseAt(x: Float, y: Float, radius: Float): List<CompletedStroke> {
        val hit = _strokes.filter { stroke ->
            // 隱藏或鎖定的圖層擦不到：看不見的線被擦掉會讓人找不到它去了哪。
            DraftingState.canEdit(stroke.layer) && stroke.points.any { p ->
                val dx = p.x - x
                val dy = p.y - y
                dx * dx + dy * dy <= radius * radius
            }
        }
        val target = session
        val page = pageId
        for (stroke in hit) {
            _strokes.remove(stroke)
            stroke.coreStrokeId?.let { id ->
                if (target != null && page != null) runCatching { target.eraseStroke(page, id) }
            }
        }
        return hit
    }

    /**
     * 把離 (x, y) 最近的一筆（鎖定／隱藏的圖層除外）改到 [target] 圖層。
     *
     * 核心是 append-only，所以「改一筆」是擦掉舊的、用新圖層寫一筆新的（顏色、線型、點都不變）。
     * 回傳有沒有改到。
     */
    fun reassignLayerAt(x: Float, y: Float, targetLayer: Int, radius: Float = 14f): Boolean {
        var best: CompletedStroke? = null
        var bestDist = Float.MAX_VALUE
        for (stroke in _strokes) {
            if (!DraftingState.canEdit(stroke.layer)) continue
            val reach = radius + stroke.baseWidth * 0.5f
            // 點到**線段**的距離，不是點到取樣點：直線只有兩三個取樣點，
            // 點在兩點中間會離任何一個取樣點都很遠。
            var d = Float.MAX_VALUE
            val pts = stroke.points
            for (i in 0 until pts.size - 1) d = minOf(d, distToSegment(x, y, pts[i], pts[i + 1]))
            if (pts.size == 1) d = kotlin.math.hypot(pts[0].x - x, pts[0].y - y)
            if (d <= reach && d < bestDist) { best = stroke; bestDist = d }
        }
        val old = best ?: return false
        if (old.layer == targetLayer) return true
        setLayerOf(old.pointerId, targetLayer)
        // 可復原：改圖層也進動作紀錄，與落筆、整組插入照時間順序一起復原／重做。
        acts += ReassignAct(old.pointerId, old.layer, targetLayer)
        redoActs.clear()
        return true
    }

    /** 把筆畫（以 pointerId 認）改到某一層。核心是 append-only：擦掉舊的、用新圖層寫一筆新的。 */
    private fun setLayerOf(key: ULong, layer: Int): Boolean {
        val index = _strokes.indexOfFirst { it.pointerId == key }
        if (index < 0) return false
        val old = _strokes[index]
        val target = session
        val page = pageId
        var newId: String? = null
        if (target != null && page != null) {
            old.coreStrokeId?.let { runCatching { target.eraseStroke(page, it) } }
            newId = runCatching {
                target.addStrokeDrafted(
                    page, old.tool, old.colorRgba, old.baseWidth, old.points,
                    layer.toUByte(), old.lineType.toUByte()
                )
            }.getOrNull()
        }
        _strokes[index] = old.copy(coreStrokeId = newId, layer = layer)
        if (newId != null) onContentCommitted?.invoke()
        return true
    }

    // ── 動作紀錄：筆畫的落筆／插入，與「改圖層」要照時間順序復原 ──
    private sealed interface Act
    private data object AddAct : Act
    private data class ReassignAct(val key: ULong, val from: Int, val to: Int) : Act
    /** 編輯工具：一批筆畫換成另一批（修剪、延伸、圓角）。復原與重做互換兩邊。 */
    private class ReplaceAct(var removed: List<CompletedStroke>, var added: List<CompletedStroke>) : Act
    private val acts = mutableListOf<Act>()
    private val redoActs = mutableListOf<Act>()

    /**
     * 最後一個事件的原始資訊，給畫面上的診斷列用。
     *
     * 為什麼要顯示在畫面上而不是寫 log：使用者手上的裝置我碰不到，
     * 一張截圖要能告訴我「平台回報的是什麼」—— 工具類型、接觸半徑、仲裁結果。
     * 沒有這條線，遠端除錯只能用猜的。
     */
    var lastEventDebug: String = "—"
        private set

    /** 畫布縮放比例（S-80）。預設 1.0。 */
    var zoom: Float = 1f
    /** 畫布水平位移（dp，S-80）。 */
    var offsetX: Float = 0f
    /** 畫布垂直位移（dp，S-80）。 */
    var offsetY: Float = 0f

    fun onMotionEvent(event: MotionEvent, density: Float): Outcome {
        // 側鍵先看：它決定的是**這一段**要畫還是要擦，慢一個事件的話，
        // 按下去的第一個點會先畫出一小段墨再開始擦。
        val control = PenHardware.control(event)
        if (control != heldControl) {
            // 先報放開、再報按下。反過來的話，從主鍵直接換到次鍵時，
            // 上層會先切到新工具、再被「放開」還原回去 —— 看起來像次鍵沒作用。
            heldControl?.let { onPenControlChanged?.invoke(it, false) }
            heldControl = control
            control?.let { onPenControlChanged?.invoke(it, true) }
        }

        var drawn = 0
        var rejected = 0
        var gesture = 0
        val retractedAll = mutableListOf<ULong>()
        val completedNow = mutableListOf<CompletedStroke>()

        for (sample in InkInput.samples(event, density, zoom, offsetX, offsetY)) {
            // 改圖層模式：點一下就把最近的一筆改到目標圖層，不落筆。
            // 繞過仲裁器 —— 它要看到移動才肯判定，一個點擊永遠等不到判定。
            val toolTouch = onToolTouch
            if (toolTouch != null) {
                toolZoom = zoom
                val phase = sample.event.phase
                if (phase != FfiPhase.HOVER && phase != FfiPhase.HOVER_ENDED) {
                    toolTouch(phase, sample.event.x, sample.event.y)
                    drawn++
                }
                continue
            }
            val marker = onMarkerTap
            if (marker != null) {
                if (sample.event.phase == FfiPhase.BEGAN) {
                    marker(sample.event.x, sample.event.y)
                    drawn++
                }
                continue
            }
            val reassign = reassignTarget
            if (reassign != null) {
                if (sample.event.phase == FfiPhase.BEGAN) {
                    val done = reassignLayerAt(sample.event.x, sample.event.y, reassign)
                    DraftingState.reassignResult = if (done) {
                        val name = DraftingState.layers.firstOrNull { it.id.toInt() == reassign }
                            ?.let { com.kairumo.padnote.L10n.t(it.nameKey) } ?: ""
                        com.kairumo.padnote.L10n.f("draft_reassigned", name)
                    } else {
                        com.kairumo.padnote.L10n.t("draft_reassign_miss")
                    }
                    drawn++
                }
                continue
            }
            if (handleInstrumentDrag(sample)) {
                drawn++
                continue
            }
            val decision = arbiter.handle(sample.event)

            // 先處理收回：被收回的筆畫不該再因為後續事件而復活。
            for (id in decision.retract) {
                if (retract(id)) retractedAll += id
            }

            when (decision.verdict) {
                FfiVerdict.DRAW -> {
                    drawn++
                    if (isErasing) {
                        // 擦除半徑與畫出來的粗細用同一組推算，
                        // 否則使用者會覺得「橡皮擦比看起來的小」。
                        eraseAt(sample.event.x, sample.event.y, baseWidth * 1.5f)
                    } else {
                        accumulate(sample)?.let { completedNow += it }
                    }
                }
                FfiVerdict.REJECT -> {
                    rejected++
                    // 這一根指標的既有筆跡要一併丟掉，不是只忽略這一個點。
                    inFlight.remove(sample.event.id)
                }
                FfiVerdict.GESTURE -> {
                    gesture++
                    inFlight.remove(sample.event.id)
                }
                FfiVerdict.HOVER -> Unit
            }
        }

        val first = InkInput.samples(event, density, zoom, offsetX, offsetY).firstOrNull()
        lastEventDebug = if (first == null) {
            "action=${event.actionMasked} 無取樣點"
        } else {
            "tool=${event.getToolType(0)} r=${"%.1f".format(first.event.contactRadius)}dp " +
                "p=${"%.2f".format(first.event.pressure)} d=$density " +
                "draw=$drawn rej=$rejected ges=$gesture"
        }

        return Outcome(drawn, rejected, gesture, retractedAll, completedNow)
    }

    /**
     * 內容寫到頁尾時通知外層準備下一頁。
     *
     * 與 Apple 端一致：**不自動翻頁** —— 使用者可能只是把最後一行寫到很下面，
     * 畫面自己跳走比繼續留在原地更糟。
     */
    var onReachedPageBottom: (() -> Unit)? = null

    private fun accumulate(sample: InkInput.Sample): CompletedStroke? {
        val id = sample.event.id
        when (sample.event.phase) {
            FfiPhase.BEGAN -> {
                inFlight[id] = mutableListOf(sample)
                resetHold(sample.event.x, sample.event.y)
                updateDraftPreview()
            }
            FfiPhase.MOVED -> {
                // 沒有 BEGAN 就收到 MOVED（例如前一筆被收回後又有事件進來）
                // 不該無中生有一筆畫。
                inFlight[id]?.add(sample)
                if (kotlin.math.hypot(sample.event.x - holdAnchorX, sample.event.y - holdAnchorY) > SNAP_SLOP) {
                    resetHold(sample.event.x, sample.event.y)
                }
                if (sample.event.y + 200f > PageGeometry.height) onReachedPageBottom?.invoke()
                updateDraftPreview()
            }
            FfiPhase.ENDED -> {
                val collected = inFlight.remove(id) ?: return null
                collected.add(sample)
                clearDraftPreview()
                // 預覽已經亮著就一定要吸附（所見即所得），不再另外用時間戳判斷。
                val previewed = snapPreview != null
                endHold()
                forceSnap = previewed
                try {
                    return commit(id, collected)
                } finally {
                    forceSnap = false
                }
            }
            FfiPhase.CANCELLED -> {
                endHold()
                inFlight.remove(id)
                clearDraftPreview()
            }
            FfiPhase.HOVER, FfiPhase.HOVER_ENDED -> Unit
        }
        return null
    }

    /** 抬筆前，筆有沒有在終點停了至少 [SNAP_DWELL_MS]（位移不超過 [SNAP_SLOP]）。 */
    private fun dwelledAtEnd(samples: List<InkInput.Sample>): Boolean {
        if (samples.size < 3) return false
        val last = samples.last().event
        var i = samples.size - 2
        while (i >= 0) {
            val e = samples[i].event
            if (kotlin.math.hypot(e.x - last.x, e.y - last.y) > SNAP_SLOP) {
                val dwellMs = (last.timestampUs - samples[i + 1].event.timestampUs).toLong() / 1000
                return dwellMs >= SNAP_DWELL_MS
            }
            i--
        }
        // 整筆都沒離開起點：是點，不是筆畫。
        return false
    }

    private var forceSnap = false

    private fun commit(id: ULong, samples: List<InkInput.Sample>): CompletedStroke? {
        if (layer != 0) {
            // 鎖住的圖層不收筆畫；畫在隱藏的圖層上就把它顯示出來，不然畫了卻什麼都沒有。
            if (DraftingState.isLocked(layer)) return null
            DraftingState.ensureVisible(layer)
        }
        val points = InkInput.strokePoints(samples)
        // 單點「筆畫」是點一下，不是書寫。留著只會在畫面上產生看不見的雜點。
        if (points.size < 2) return null

        // 完全落在可列印範圍外的筆畫**不收**（S-85，與 Apple 同一條規則）。
        //
        // 那一筆印不出來也匯不出去，留著只會讓使用者以為它存在，
        // 等到列印那天才發現不見了。跨在界線上的留著 —— 寫到一半被整筆
        // 吃掉比溢出更難用，而且那一筆大半還看得見。
        if (isEntirelyOutsidePrintableArea(points)) {
            outsidePrintableArea = true
            return null
        }

        var finalPoints = points
        if (isMagneticSnapActive && points.size >= 2 &&
            com.kairumo.padnote.canvas.SmartMagneticSnap.isNearlyStraight(
                points.map { androidx.compose.ui.geometry.Offset(it.x, it.y) })
        ) {
            val start = androidx.compose.ui.geometry.Offset(points.first().x, points.first().y)
            val end = androidx.compose.ui.geometry.Offset(points.last().x, points.last().y)
            val snapRes = com.kairumo.padnote.canvas.SmartMagneticSnap.snap(start, end, enableGrid = true)
            if (snapRes.didSnap) {
                val lastPt = points.last()
                finalPoints = points.dropLast(1) + StrokePoint(
                    x = snapRes.snappedPoint.x,
                    y = snapRes.snappedPoint.y,
                    pressure = lastPt.pressure,
                    tilt = lastPt.tilt,
                    azimuth = lastPt.azimuth,
                    dtUs = lastPt.dtUs
                )
                onMagneticSnap?.invoke(start, snapRes.snappedPoint)
            }
        }

        val drafting = layer != 0 || lineType != 0
        if (layer != 0 && !forceSnap) finalPoints = draftAdjust(finalPoints).first
        // 長按吸附：筆畫抬起前在終點停住一下，就釘成幾何圖形（見 `draftSnapStroke`）。
        var snappedKind: uniffi.padnote_core.FfiDraftSnapKind? = null
        val step = snapStepDeg
        if (step != null && (forceSnap || dwelledAtEnd(samples))) {
            val snap = uniffi.padnote_core.draftSnapStroke(
                finalPoints.map { uniffi.padnote_core.FfiPoint(it.x, it.y) }, step
            )
            if (snap.kind != uniffi.padnote_core.FfiDraftSnapKind.NONE && snap.points.size == finalPoints.size) {
                finalPoints = finalPoints.mapIndexed { i, p ->
                    p.copy(x = snap.points[i].x, y = snap.points[i].y)
                }
                snappedKind = snap.kind
            }
        }
        // 製圖線要的是等寬、不收尖、不圓角：不做平滑。
        if (finalPoints.size >= 3 && !drafting) {
            finalPoints = uniffi.padnote_core.streamlineSmoothPoints(finalPoints, 0.35f, 1.0f, 0.20f, 0.30f)
        }
        snappedKind?.let { onSnapped?.invoke(it) }

        val target = session
        val page = pageId
        val coreId = if (target != null && page != null) {
            runCatching {
                target.addStrokeDrafted(
                    page, tool, colorRgba, baseWidth, finalPoints, layer.toUByte(), lineType.toUByte()
                )
            }.getOrNull()
        } else {
            null
        }
        if (coreId != null) onContentCommitted?.invoke()

        val stroke = CompletedStroke(
            pointerId = id,
            coreStrokeId = coreId,
            points = finalPoints,
            tool = tool,
            startedAtMs = (samples.first().event.timestampUs / 1_000uL).toLong(),
            colorRgba = colorRgba.copyOf(),
            baseWidth = baseWidth,
            layer = layer,
            lineType = lineType
        )
        _strokes += stroke
        // 畫了新的東西就沒有「重做」可言了 —— 留著的話，按下重做會把
        // 一筆與現在的畫面毫無關係的筆畫放回來。
        redoStack.clear()
        redoActs.clear()
        acts += AddAct
        if (coreId != null) committed[id] = coreId
        return stroke
    }

    /**
     * 使用者剛剛寫了一筆完全在可列印範圍外的東西。
     *
     * 畫面層讀完要自己清掉（`consumeOutsidePrintableArea`）—— 提醒只出現一次，
     * 每一筆都跳一次的話，在框外連寫十筆會跳十次。
     */
    private var outsidePrintableArea = false

    fun consumeOutsidePrintableArea(): Boolean {
        val flagged = outsidePrintableArea
        outsidePrintableArea = false
        return flagged
    }

    /** 整筆都在可列印範圍外嗎。判斷用筆畫的外接矩形，與 Apple 同一種做法。 */
    private fun isEntirelyOutsidePrintableArea(points: List<uniffi.padnote_core.StrokePoint>): Boolean {
        if (points.isEmpty()) return false
        var minX = Float.MAX_VALUE
        var minY = Float.MAX_VALUE
        var maxX = -Float.MAX_VALUE
        var maxY = -Float.MAX_VALUE
        for (p in points) {
            // 座標是跨頁的，要先換算成這一頁裡的 y。
            val y = PageGeometry.yWithinPage(p.y)
            minX = minOf(minX, p.x); maxX = maxOf(maxX, p.x)
            minY = minOf(minY, y); maxY = maxOf(maxY, y)
        }
        val within = runCatching {
            uniffi.padnote_core.isWithinPrintable(
                uniffi.padnote_core.FfiRect(minX, minY, maxX, maxY),
                PageGeometry.width,
                PageGeometry.height,
                PageGeometry.PRINTABLE_INSET
            )
        }.getOrNull()
        if (within == true) return false
        val rect = runCatching {
            uniffi.padnote_core.printableRect(
                PageGeometry.width, PageGeometry.height, PageGeometry.PRINTABLE_INSET
            )
        }.getOrNull() ?: return false
        // 完全在外面 = 外接矩形與可列印矩形沒有交集。
        return maxX < rect.minX || minX > rect.maxX || maxY < rect.minY || minY > rect.maxY
    }

    /** 收回某根指標畫出來的東西。回傳是否真的收回了什麼。 */
    private fun retract(id: ULong): Boolean {
        var removed = inFlight.remove(id) != null

        val coreId = committed.remove(id)
        val index = _strokes.indexOfLast { it.pointerId == id }
        if (index >= 0) {
            _strokes.removeAt(index)
            removed = true
        }
        val target = session
        val page = pageId
        if (coreId != null && target != null && page != null) {
            // 核心是 append-only：收回是追加墓碑，不是刪位元組。
            runCatching { target.eraseStroke(page, coreId) }
        }
        return removed
    }

    /**
     * 把這一頁**已經存在檔案裡**的筆畫讀回來。
     *
     * # 為什麼這個方法原本不存在，而那是一個嚴重的錯誤
     *
     * `_strokes` 原本只裝「這一次開啟期間畫的」筆畫。寫進核心是有的、
     * `.padnote` 裡也真的有資料 —— 但**重開筆記本之後畫面是空的**，
     * 使用者寫的字看起來憑空消失了。物件（文字方塊、表格、形狀）都有各自的
     * `load()`，只有墨跡沒有，所以症狀是「圖還在、字不見了」，
     * 看起來像渲染壞掉而不是少讀一份資料。
     *
     * 讀回來的筆畫沒有對應的指標 id（它們不是這次畫的），所以用遞減的合成 id。
     * 那些 id 只用在收回（retract）與擦除的對應上，不會與真實指標撞號。
     */
    fun load() {
        val target = session ?: return
        val page = pageId ?: return
        val loaded = runCatching { target.visibleStrokeDetails(page) }.getOrNull() ?: return

        _strokes.clear()
        acts.clear()
        redoActs.clear()
        committed.clear()
        var syntheticId = ULong.MAX_VALUE
        for (stroke in loaded) {
            _strokes += CompletedStroke(
                pointerId = syntheticId,
                coreStrokeId = stroke.id,
                points = stroke.points,
                tool = stroke.tool,
                startedAtMs = (stroke.startedAtUs / 1_000uL).toLong(),
                colorRgba = stroke.colorRgba.copyOf(),
                baseWidth = stroke.baseWidth,
                layer = stroke.layer.toInt(),
                lineType = stroke.lineType.toInt()
            )
            syntheticId -= 1uL
        }
        // 讀回來的筆畫不在「可收回時間窗」內 —— 它們是上次寫的，
        // 掌拒不該把它們收回去。所以刻意不填 committed。
    }

    // ── 草圖美化 ──────────────────────────────────────────────
    //
    // 幾何辨識與平滑在核心（`sketchRefineStroke`），與 Apple 端同一份實作。
    // 這裡負責「換掉畫布上的筆畫」：核心是 append-only，所以「改一筆」實際上
    // 是**擦掉舊的、加一筆新的**，不是就地改座標。

    /** 美化之前的樣子。按「還原」用得到。 */
    private var sketchBackup: List<CompletedStroke>? = null

    /** 上一次美化的結果。還原之後按「重做」用得到。 */
    private var refinedCache: List<CompletedStroke>? = null

    /** 有沒有可以還原的原始草圖。 */
    /**
     * 這一頁的核心 session 與 page id，套索要用。
     *
     * 開出來而不是讓套索自己再開一份：`InkEngine` 已經是這一頁筆畫的
     * 真相來源，兩份 session 指著同一個套件會在寫入時互相看不到對方。
     */
    fun coreHandles(): Pair<PadnoteSession, String>? {
        val s = session ?: return null
        val p = pageId ?: return null
        return s to p
    }

    fun canRestoreSketch(): Boolean = sketchBackup != null

    /** 有沒有可以重做的美化結果。 */
    fun canRedoRefine(): Boolean = refinedCache != null

    /**
     * 美化目前這一頁的所有筆畫。回傳實際換掉的筆數。
     *
     * 第一次呼叫會記下原始草圖；之後連按也不會覆蓋那份備份 ——
     * 否則「還原」只能退回上一次美化的結果，退不回手寫的原樣。
     */
    fun refineSketch(intensity: Float): Int {
        if (_strokes.isEmpty()) return 0
        if (sketchBackup == null) sketchBackup = _strokes.toList()

        val refined = _strokes.map { stroke ->
            val input = stroke.points.map { FfiPoint(it.x, it.y) }
            val result = uniffi.padnote_core.sketchRefineStroke(input, intensity)
            // 核心保證輸出點數與輸入相同，所以壓感、傾角、時間差可以逐點沿用
            // —— 只換位置，筆觸的粗細變化不變。
            val points = stroke.points.mapIndexed { i, p ->
                StrokePoint(
                    x = result.points[i].x,
                    y = result.points[i].y,
                    pressure = p.pressure,
                    tilt = p.tilt,
                    azimuth = p.azimuth,
                    dtUs = p.dtUs
                )
            }
            stroke.copy(points = points)
        }
        refinedCache = replaceStrokes(refined)
        return refinedCache?.size ?: 0
    }

    /** 回到美化之前的手寫原樣。 */
    fun restoreSketch(): Boolean {
        val original = sketchBackup ?: return false
        replaceStrokes(original)
        return true
    }

    /** 還原之後再套回美化結果。 */
    fun redoRefine(): Boolean {
        val refined = refinedCache ?: return false
        replaceStrokes(refined)
        return true
    }

    /**
     * 用一組新筆畫取代畫布上現有的筆畫。
     *
     * 回傳的是**寫回核心之後**的筆畫（`coreStrokeId` 已更新）。沿用舊的 id
     * 會讓下一次擦除打在已經是墓碑的筆畫上，那一筆就再也擦不掉了。
     */
    private fun replaceStrokes(next: List<CompletedStroke>): List<CompletedStroke> {
        val target = session
        val page = pageId
        if (target != null && page != null) {
            for (old in _strokes) {
                old.coreStrokeId?.let { runCatching { target.eraseStroke(page, it) } }
            }
        }
        val written = next.map { stroke ->
            val coreId = if (target != null && page != null) {
                runCatching {
                    target.addStrokeDrafted(
                        page, stroke.tool, stroke.colorRgba, stroke.baseWidth, stroke.points,
                        stroke.layer.toUByte(), stroke.lineType.toUByte()
                    )
                }.getOrNull()
            } else {
                null
            }
            stroke.copy(coreStrokeId = coreId)
        }
        _strokes.clear()
        _strokes += written
        // 換過筆畫之後，舊的 pointerId → coreStrokeId 對應已經沒有意義。
        committed.clear()
        return written
    }

    /** 切換頁面或視圖時呼叫。 */
    fun reset() {
        acts.clear()
        redoActs.clear()
        inFlight.clear()
        committed.clear()
        _strokes.clear()
        sketchBackup = null
        refinedCache = null
        arbiter.reset()
    }

    /**
     * 這根指標目前是否被採納為墨跡。
     *
     * 低延遲渲染要用：前緩衝是**先畫了才知道對不對**的路徑，所以下筆之前
     * 必須先問過仲裁結果，否則手掌的軌跡會先閃一下才被擦掉。
     */
    fun isDrawing(pointerId: ULong): Boolean = inFlight.containsKey(pointerId)

    // ── 長按吸附的即時預覽（對齊 Apple：按住時就看到會變成什麼，不是抬筆才變）──
    //
    // 筆停著不動時 Android 不會再送事件，所以不能靠事件的時間戳判斷「停了多久」，
    // 要靠牆上時鐘的計時器：每次移動超過 [SNAP_SLOP] 就重設錨點與計時，計時到了還在原地就算一次吸附結果。
    private val snapHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private var holdAnchorX = 0f
    private var holdAnchorY = 0f
    private var holdToken = 0

    /** 吸附預覽的點（頁面座標）。非空時畫這個，不畫原本的即時筆畫。 */
    var snapPreview: List<StrokePoint>? = null
        private set

    /** 預覽有變動時通知畫布重繪。 */
    var onSnapPreviewChanged: (() -> Unit)? = null

    private fun resetHold(x: Float, y: Float) {
        holdAnchorX = x
        holdAnchorY = y
        val token = ++holdToken
        if (snapPreview != null) {
            snapPreview = null
            onSnapPreviewChanged?.invoke()
        }
        snapHandler.removeCallbacksAndMessages(null)
        if (snapStepDeg == null) return
        snapHandler.postDelayed({ if (token == holdToken) showSnapPreview(token) }, SNAP_DWELL_MS)
    }

    private fun showSnapPreview(token: Int) {
        val step = snapStepDeg ?: return
        val live = inFlight.values.firstOrNull() ?: return
        val pts = InkInput.strokePoints(live.toList())
        if (pts.size < 3 || token != holdToken) return
        val snap = uniffi.padnote_core.draftSnapStroke(
            pts.map { uniffi.padnote_core.FfiPoint(it.x, it.y) }, step
        )
        if (snap.kind == uniffi.padnote_core.FfiDraftSnapKind.NONE || snap.points.size != pts.size) return
        snapPreview = pts.mapIndexed { i, p -> p.copy(x = snap.points[i].x, y = snap.points[i].y) }
        onSnapPreviewChanged?.invoke()
    }

    private fun endHold() {
        holdToken++
        snapHandler.removeCallbacksAndMessages(null)
        if (snapPreview != null) {
            snapPreview = null
            onSnapPreviewChanged?.invoke()
        }
    }

    /** 目前正在畫、尚未結束的取樣點（供即時預覽）。 */
    fun liveSamples(): List<List<InkInput.Sample>> = inFlight.values.map { it.toList() }

    fun setPenOnly(penOnly: Boolean) {
        arbiter.setMode(
            if (penOnly) uniffi.padnote_core.FfiInputMode.PEN_ONLY
            else uniffi.padnote_core.FfiInputMode.PEN_AND_FINGER
        )
        applyPalmThresholds(penOnly)
    }

    private fun applyPalmThresholds(penOnly: Boolean) {
        lastPenOnly = penOnly
        val limits = uniffi.padnote_core.palmThresholdLimits()
        val radius = overrideRadiusDp
            ?: if (penOnly) limits.defaultRadiusDp else limits.fingerModeRadiusDp
        // **單位是毫秒。** 這裡曾經傳 500_000 —— 那是核心內部 `_us` 欄位的
        // 預設值，當成毫秒就是 500 秒：手指寫了幾分鐘、筆一落下，
        // 過去八分鐘的筆畫會被當成手掌整批收回。核心現在會夾制，
        // 但正確的值還是要從這裡傳出去。
        val retractMs = overrideRetractMs ?: limits.defaultRetractMs
        arbiter.setPalmThresholds(radius, retractMs)
    }

    /** 套用使用者在設定裡調的門檻。傳 `null` 表示恢復預設。 */
    fun setPalmThresholds(palmRadiusDp: Float?, retractWindowMs: UInt?) {
        overrideRadiusDp = palmRadiusDp
        overrideRetractMs = retractWindowMs
        applyPalmThresholds(lastPenOnly)
    }
    
    fun setPressureCurve(floor: Float, gamma: Float) {
        arbiter.setPressureCurve(floor, gamma)
    }

    private fun distToSegment(px: Float, py: Float, a: StrokePoint, b: StrokePoint): Float {
        val dx = b.x - a.x
        val dy = b.y - a.y
        val len2 = dx * dx + dy * dy
        val t = if (len2 < 1e-6f) 0f else (((px - a.x) * dx + (py - a.y) * dy) / len2).coerceIn(0f, 1f)
        return kotlin.math.hypot(px - (a.x + dx * t), py - (a.y + dy * t))
    }

    private companion object {
        /** 抬筆前在終點停多久才算「長按吸附」。與 Apple 的 0.55 秒一致。 */
        const val SNAP_DWELL_MS = 550L
        /** 停留期間允許的抖動（頁面單位）。 */
        const val SNAP_SLOP = 4f
    }
}


/**
 * 閉合的點列擬合成圓（Kåsa 代數法，與 Apple 的 `ProInkLayerView.fitCircle` 同一個算法）。
 * 不閉合、太小、殘差超過半徑 6% 都回 `null`。
 */
internal fun fitCircle(pts: List<InkEngine.Offset2>): Pair<InkEngine.Offset2, Float>? {
    if (pts.size < 8) return null
    var perimeter = 0.0
    for (i in 1 until pts.size) perimeter += kotlin.math.hypot((pts[i].x - pts[i - 1].x).toDouble(), (pts[i].y - pts[i - 1].y).toDouble())
    val first = pts.first()
    val last = pts.last()
    if (perimeter <= 30 || kotlin.math.hypot((first.x - last.x).toDouble(), (first.y - last.y).toDouble()) >= perimeter * 0.08) return null
    var sx = 0.0; var sy = 0.0; var sxx = 0.0; var syy = 0.0; var sxy = 0.0; var sz = 0.0; var szx = 0.0; var szy = 0.0
    val n = pts.size.toDouble()
    for (p in pts) {
        val x = p.x.toDouble(); val y = p.y.toDouble(); val z = x * x + y * y
        sx += x; sy += y; sxx += x * x; syy += y * y; sxy += x * y; sz += z; szx += z * x; szy += z * y
    }
    val m = arrayOf(doubleArrayOf(sxx, sxy, sx), doubleArrayOf(sxy, syy, sy), doubleArrayOf(sx, sy, n))
    val b = doubleArrayOf(szx, szy, sz)
    fun det(a: Array<DoubleArray>) =
        a[0][0] * (a[1][1] * a[2][2] - a[1][2] * a[2][1]) -
            a[0][1] * (a[1][0] * a[2][2] - a[1][2] * a[2][0]) +
            a[0][2] * (a[1][0] * a[2][1] - a[1][1] * a[2][0])
    val d = det(m)
    if (kotlin.math.abs(d) <= 1e-9) return null
    val sol = DoubleArray(3)
    for (k in 0 until 3) {
        val mk = Array(3) { r -> m[r].copyOf() }
        for (r in 0 until 3) mk[r][k] = b[r]
        sol[k] = det(mk) / d
    }
    val cx = sol[0] / 2
    val cy = sol[1] / 2
    val r2 = sol[2] + cx * cx + cy * cy
    if (r2 <= 0) return null
    val r = kotlin.math.sqrt(r2)
    var err = 0.0
    for (p in pts) err += kotlin.math.abs(kotlin.math.hypot(p.x - cx, p.y - cy) - r)
    if (err / n >= r * 0.06 || r <= 4) return null
    return InkEngine.Offset2(cx.toFloat(), cy.toFloat()) to r.toFloat()
}
