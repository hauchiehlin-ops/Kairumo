package com.kairumo.padnote.ink

import android.view.MotionEvent

/**
 * 筆尖延遲的量測（工作包 WP5c）。
 *
 * # 它量的到底是什麼
 *
 * 從「這個取樣點在硬體上發生的時刻」（`MotionEvent.getEventTimeNanos()`）到
 * 「App 把它交給合成器的時刻」。**這不是筆尖到光子的完整延遲** ——
 * 面板本身的掃描與亮起時間量不到，那要靠高速攝影機。
 *
 * 說清楚這件事比給一個好看的數字重要：拿這個值去跟別家 App 的「延遲」比較，
 * 只有在對方也用同一個定義時才有意義。它真正有用的地方是**同一台裝置上
 * 開關前緩衝渲染的前後對比** —— 那個差值是真的。
 */
class InkLatencyMeter(private val capacity: Int = 512) {

    private val samplesUs = ArrayDeque<Long>()

    /** 記一次「這個事件的取樣時刻 → 現在」。 */
    fun record(event: MotionEvent, nowNanos: Long = System.nanoTime()) {
        val deltaNs = nowNanos - event.eventTimeNanos
        // 負值代表時鐘來源不同步（少數裝置會這樣），記錄它只會汙染統計。
        if (deltaNs < 0) return
        if (samplesUs.size >= capacity) samplesUs.removeFirst()
        samplesUs.addLast(deltaNs / 1_000)
    }

    fun clear() = samplesUs.clear()

    val count: Int get() = samplesUs.size

    /** 第 `p` 百分位的延遲（微秒）。沒有樣本時回傳 0。 */
    fun percentileUs(p: Int): Long {
        if (samplesUs.isEmpty()) return 0
        val sorted = samplesUs.sorted()
        // 取「不小於 p% 的第一個樣本」。用 size*p/100 會在 p=100 時越界。
        val index = ((sorted.size - 1) * p.coerceIn(0, 100)) / 100
        return sorted[index]
    }

    /** 給使用者看的一行摘要。 */
    fun summaryMs(): String {
        if (samplesUs.isEmpty()) return "—"
        fun ms(us: Long) = String.format("%.1f", us / 1000.0)
        return "p50 ${ms(percentileUs(50))}ms · p95 ${ms(percentileUs(95))}ms · ${samplesUs.size} 樣本"
    }
}
