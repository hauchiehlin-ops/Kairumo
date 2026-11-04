package com.kairumo.padnote.perf

/**
 * 即時響應的量測基礎（對應 Apple 的 `PerfProbe`）。
 *
 * 每個「使用者會感覺到的動作」各有一個量測點與延遲預算：
 * 1. 在 Systrace／Perfetto 看得到區間（`android.os.Trace`）；
 * 2. 在記憶體留下最近的耗時，算 p50／p95／最大值並與預算比對；
 * 3. 超標次數累計，診斷與測試可以直接讀。
 *
 * 量測本身必須比被量測的東西便宜得多：兩個時間戳、一把短鎖、一個環形緩衝。任何執行緒都可以呼叫。
 */
enum class PerfPoint(val budgetMs: Double) {
    /** 收筆：`InkEngine.commit` 從進入到交還。 */
    StrokeEnd(8.0),
    /** 換工具：`applyInkTool` 整段。 */
    ToolSwitch(16.0),
    /** 切頁：`switchToPage` 整段。 */
    PageSwitch(50.0),
    /** 切頁中「把上一頁的筆跡交出去」那一段。 */
    PageSave(16.0),
    /** 載入新頁的筆跡（含套用）。 */
    PageLoad(33.0),
    /** 縮圖離屏算繪（在主執行緒上的那段）。 */
    ThumbnailRender(16.0),
}

/** 與裝置速度無關的「次數型」成本計數。測試用它斷言某件事沒有發生、且不隨筆記大小成長。 */
/** [MainThreadAttachmentLoad]：主執行緒上同步讀圖片 blob＋解碼（與 Apple `mainThreadAttachmentLoad` 同義）。 */
enum class CostCounter { PrefetchScheduled, ThumbnailComposeOnMain, BackingFullRebuild, BackingPatch, MainThreadAttachmentLoad }

class PerfProbe(private val tracer: Tracer = Tracer.Android) {

    /** 追蹤介面（JVM 單元測試用空實作，避免依賴 Android 框架）。 */
    interface Tracer {
        fun begin(name: String)
        fun end()

        object Android : Tracer {
            override fun begin(name: String) { runCatching { android.os.Trace.beginSection(name) } }
            override fun end() { runCatching { android.os.Trace.endSection() } }
        }

        object None : Tracer {
            override fun begin(name: String) {}
            override fun end() {}
        }
    }

    data class Stats(
        val count: Int = 0,
        val p50Ms: Double = 0.0,
        val p95Ms: Double = 0.0,
        val maxMs: Double = 0.0,
        val overBudget: Int = 0
    )

    private val lock = Any()
    private val samples = HashMap<PerfPoint, ArrayDeque<Double>>()
    private val over = HashMap<PerfPoint, Int>()
    private val counters = HashMap<CostCounter, Int>()

    /** 量一段同步工作。 */
    inline fun <T> measure(point: PerfPoint, body: () -> T): T {
        val start = System.nanoTime()
        traceBegin(point)
        try {
            return body()
        } finally {
            traceEnd()
            record(point, (System.nanoTime() - start) / 1_000_000.0)
        }
    }

    @PublishedApi internal fun traceBegin(point: PerfPoint) = tracer.begin(point.name)
    @PublishedApi internal fun traceEnd() = tracer.end()

    fun record(point: PerfPoint, ms: Double) {
        synchronized(lock) {
            val list = samples.getOrPut(point) { ArrayDeque() }
            if (list.size >= CAPACITY) list.removeFirst()
            list.addLast(ms)
            if (ms > point.budgetMs) over[point] = (over[point] ?: 0) + 1
        }
    }

    fun count(counter: CostCounter, by: Int = 1) {
        synchronized(lock) { counters[counter] = (counters[counter] ?: 0) + by }
    }

    fun counter(counter: CostCounter): Int = synchronized(lock) { counters[counter] ?: 0 }

    fun stats(point: PerfPoint): Stats {
        val list: List<Double>
        val overCount: Int
        synchronized(lock) {
            list = samples[point]?.toList() ?: emptyList()
            overCount = over[point] ?: 0
        }
        if (list.isEmpty()) return Stats()
        val sorted = list.sorted()
        fun pct(p: Int) = sorted[((sorted.size - 1) * p) / 100]
        return Stats(sorted.size, pct(50), pct(95), sorted.last(), overCount)
    }

    /** 診斷用的多行摘要。 */
    fun report(): String = PerfPoint.entries.joinToString("\n") { point ->
        val s = stats(point)
        if (s.count == 0) "${point.name}: —"
        else "%s: p50 %.1f / p95 %.1f / max %.1f ms（預算 %.0f，超標 %d/%d）".format(
            point.name, s.p50Ms, s.p95Ms, s.maxMs, point.budgetMs, s.overBudget, s.count)
    }

    fun reset() {
        synchronized(lock) { samples.clear(); over.clear(); counters.clear() }
    }

    companion object {
        private const val CAPACITY = 256

        // profile-scope: device 效能診斷，整台裝置共用
        val shared = PerfProbe()
    }
}
