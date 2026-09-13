package com.kairumo.padnote.ink

import android.view.MotionEvent
import uniffi.padnote_core.FfiPhase
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

    /** 已經寫進核心、但仍在可收回時間窗內的筆畫：指標 id → 核心筆畫 id。 */
    private val committed = LinkedHashMap<ULong, String>()

    /** 已完成的筆畫（沒有 session 時留在記憶體，供測試與預覽用）。 */
    private val _strokes = mutableListOf<CompletedStroke>()
    val strokes: List<CompletedStroke> get() = _strokes

    data class CompletedStroke(
        val pointerId: ULong,
        val coreStrokeId: String?,
        val points: List<StrokePoint>,
        val tool: ToolKind,
        /** 落筆時刻（毫秒）。手寫辨識靠它把筆畫依書寫停頓分組。 */
        val startedAtMs: Long
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

    /**
     * 擦除模式。
     *
     * 擦除不是一種筆刷 —— 核心的 `ToolKind` 只有筆刷種類，擦除走
     * `erase_stroke`。所以它是引擎的一個狀態，不是 `tool` 的一個值。
     */
    var isErasing: Boolean = false

    /**
     * 擦掉碰到的筆畫。
     *
     * 用「碰到就整筆擦掉」而不是切斷筆畫：切斷需要把一筆拆成兩筆並改寫取樣點，
     * 那會破壞「存原始取樣點」的不變式（ADR-0002）。整筆擦除是 append-only
     * 的墓碑，與同步、回溯都相容。
     */
    private fun eraseAt(x: Float, y: Float, radius: Float): List<CompletedStroke> {
        val hit = _strokes.filter { stroke ->
            stroke.points.any { p ->
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
     * 最後一個事件的原始資訊，給畫面上的診斷列用。
     *
     * 為什麼要顯示在畫面上而不是寫 log：使用者手上的裝置我碰不到，
     * 一張截圖要能告訴我「平台回報的是什麼」—— 工具類型、接觸半徑、仲裁結果。
     * 沒有這條線，遠端除錯只能用猜的。
     */
    var lastEventDebug: String = "—"
        private set

    fun onMotionEvent(event: MotionEvent, density: Float): Outcome {
        var drawn = 0
        var rejected = 0
        var gesture = 0
        val retractedAll = mutableListOf<ULong>()
        val completedNow = mutableListOf<CompletedStroke>()

        for (sample in InkInput.samples(event, density)) {
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

        val first = InkInput.samples(event, density).firstOrNull()
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
            }
            FfiPhase.MOVED -> {
                // 沒有 BEGAN 就收到 MOVED（例如前一筆被收回後又有事件進來）
                // 不該無中生有一筆畫。
                inFlight[id]?.add(sample)
                if (sample.event.y + 200f > PageGeometry.height) onReachedPageBottom?.invoke()
            }
            FfiPhase.ENDED -> {
                val collected = inFlight.remove(id) ?: return null
                collected.add(sample)
                return commit(id, collected)
            }
            FfiPhase.CANCELLED -> {
                inFlight.remove(id)
            }
            FfiPhase.HOVER, FfiPhase.HOVER_ENDED -> Unit
        }
        return null
    }

    private fun commit(id: ULong, samples: List<InkInput.Sample>): CompletedStroke? {
        val points = InkInput.strokePoints(samples)
        // 單點「筆畫」是點一下，不是書寫。留著只會在畫面上產生看不見的雜點。
        if (points.size < 2) return null

        val target = session
        val page = pageId
        val coreId = if (target != null && page != null) {
            runCatching {
                target.addStroke(page, tool, colorRgba, baseWidth, points)
            }.getOrNull()
        } else {
            null
        }

        val stroke = CompletedStroke(
            pointerId = id,
            coreStrokeId = coreId,
            points = points,
            tool = tool,
            startedAtMs = (samples.first().event.timestampUs / 1_000uL).toLong()
        )
        _strokes += stroke
        if (coreId != null) committed[id] = coreId
        return stroke
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

    /** 切換頁面或視圖時呼叫。 */
    fun reset() {
        inFlight.clear()
        committed.clear()
        _strokes.clear()
        arbiter.reset()
    }

    /**
     * 這根指標目前是否被採納為墨跡。
     *
     * 低延遲渲染要用：前緩衝是**先畫了才知道對不對**的路徑，所以下筆之前
     * 必須先問過仲裁結果，否則手掌的軌跡會先閃一下才被擦掉。
     */
    fun isDrawing(pointerId: ULong): Boolean = inFlight.containsKey(pointerId)

    /** 目前正在畫、尚未結束的取樣點（供即時預覽）。 */
    fun liveSamples(): List<List<InkInput.Sample>> = inFlight.values.map { it.toList() }

    fun setPenOnly(penOnly: Boolean) {
        arbiter.setMode(
            if (penOnly) uniffi.padnote_core.FfiInputMode.PEN_ONLY
            else uniffi.padnote_core.FfiInputMode.PEN_AND_FINGER
        )
    }

    fun setPalmThresholds(palmRadiusDp: Float, retractWindowMs: UInt) {
        arbiter.setPalmThresholds(palmRadiusDp, retractWindowMs)
    }
}
