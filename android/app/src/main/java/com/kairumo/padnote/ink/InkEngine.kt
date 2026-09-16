package com.kairumo.padnote.ink

import android.view.MotionEvent
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
     * 觸控筆的側鍵（或反向筆頭）狀態變了（工作項 S-67）。
     *
     * 只在**狀態真的翻面**時呼叫一次，不是每個事件都叫 —— 一次書寫會產生
     * 上百個 `ACTION_MOVE`，每個都回報的話，上層的工具列狀態每秒被寫幾十次。
     *
     * 掛在引擎上而不是各個 View：低延遲畫布（`InkSurfaceView`）與一般畫布
     * 是兩條繪製路徑，但都經過這裡。掛在 View 上會變成「只有其中一條路
     * 支援側鍵」，而使用者切不切得到低延遲取決於他的裝置。
     */
    var onStylusEraserChanged: ((Boolean) -> Unit)? = null

    /** 上一次看到的側鍵狀態。用來只在翻面時通知。 */
    private var stylusErasing: Boolean = false

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
        // 側鍵先看：它決定的是**這一段**要畫還是要擦，慢一個事件的話，
        // 按下去的第一個點會先畫出一小段墨再開始擦。
        val erasing = StylusButton.isErasing(event)
        if (erasing != stylusErasing) {
            stylusErasing = erasing
            onStylusEraserChanged?.invoke(erasing)
        }

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
        committed.clear()
        var syntheticId = ULong.MAX_VALUE
        for (stroke in loaded) {
            _strokes += CompletedStroke(
                pointerId = syntheticId,
                coreStrokeId = stroke.id,
                points = stroke.points,
                tool = stroke.tool,
                startedAtMs = (stroke.startedAtUs / 1_000uL).toLong()
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
                    target.addStroke(page, stroke.tool, colorRgba, baseWidth, stroke.points)
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
