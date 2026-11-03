package com.kairumo.padnote.perf

import android.view.Choreographer

/**
 * 執行期自我調節（對應 Apple 的 `FrameGovernor`）。
 *
 * 不同裝置、不同系統版本、不同負載下「做得起」的量不一樣，不可能事先為每一種寫死參數。
 * 所以讓每台裝置在**執行時**看自己的幀表現：滑動視窗內「超過目標幀時間 1.5 倍」的比例過高就進入
 * `Constrained`，低於較低門檻才離開（遲滯，避免來回跳）。筆跡本身永遠不降級。
 * 判斷邏輯是純函式（[ingest]），可單元測試；[start]/[stop] 才碰 Choreographer。
 */
class FrameGovernor(
    private val window: Int = 60,
    private val enterRatio: Double = 0.25,
    private val exitRatio: Double = 0.05
) {
    enum class Level { Normal, Constrained }

    @Volatile var level: Level = Level.Normal
        private set
    private val recent = ArrayDeque<Boolean>()
    private var overCount = 0

    /** 餵一幀的實際間隔與目標間隔（毫秒）。回傳目前等級。 */
    @Synchronized
    fun ingest(frameMs: Double, targetMs: Double): Level {
        val over = frameMs > targetMs * 1.5
        recent.addLast(over)
        if (over) overCount++
        if (recent.size > window && recent.removeFirst()) overCount--
        if (recent.size < window / 2) return level
        val ratio = overCount.toDouble() / recent.size
        level = when {
            level == Level.Normal && ratio >= enterRatio -> Level.Constrained
            level == Level.Constrained && ratio <= exitRatio -> Level.Normal
            else -> level
        }
        return level
    }

    /** 縮圖逐張之間多等多久（毫秒）。 */
    val thumbnailGapMs: Long get() = if (level == Level.Constrained) 60L else 0L

    // ── Choreographer（只在編輯器開著時跑）──

    private var callback: Choreographer.FrameCallback? = null
    private var lastNanos = 0L

    fun start() {
        if (callback != null) return
        lastNanos = 0L
        val cb = object : Choreographer.FrameCallback {
            override fun doFrame(frameTimeNanos: Long) {
                if (lastNanos > 0L) {
                    val dtMs = (frameTimeNanos - lastNanos) / 1_000_000.0
                    // 回到前景的第一幀間隔會很大，不是掉幀。
                    if (dtMs in 1.0..1000.0) ingest(dtMs, targetFrameMs)
                }
                lastNanos = frameTimeNanos
                if (callback === this) Choreographer.getInstance().postFrameCallback(this)
            }
        }
        callback = cb
        Choreographer.getInstance().postFrameCallback(cb)
    }

    fun stop() {
        callback?.let { Choreographer.getInstance().removeFrameCallback(it) }
        callback = null
        synchronized(this) { recent.clear(); overCount = 0; level = Level.Normal }
    }

    /** 目標幀時間（毫秒），由 [FieldTelemetry]／視窗的更新率設定；預設 60Hz。 */
    @Volatile var targetFrameMs: Double = 1000.0 / 60

    companion object {
        // profile-scope: device 幀表現調節，不含使用者資料
        val shared = FrameGovernor()
    }
}
