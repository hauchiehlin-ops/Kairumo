package com.kairumo.padnote.perf

import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

/**
 * 背景工作的唯一排程器（對應 Apple 的 `BackgroundScheduler`）。
 *
 * 預取、解碼、縮圖、同步各自判斷「現在可不可以做」，哪一處忘了讓路，筆跡就卡一下。
 * 這裡把規則收成一份：工作分四級，**書寫中，預取與維護一律暫停**，停手後才繼續；
 * 互動級（使用者正在等的）永遠不被暫停。與裝置無關 —— 慢的裝置只是做得比較久，不會搶到筆。
 *
 * 工作在背景執行緒執行，**不得碰 UI**。
 */
enum class BackgroundPriority(val threadPriority: Int) {
    /** 使用者正在等結果（不受書寫暫停影響）。 */
    Interactive(Thread.NORM_PRIORITY),
    /** 目前畫面上看得到、等一下就要用的。書寫中暫停。 */
    Visible(Thread.NORM_PRIORITY - 1),
    /** 預測下一步會用的（相鄰頁的筆跡解碼）。書寫中暫停。 */
    Prefetch(Thread.MIN_PRIORITY + 1),
    /** 可以晚點做的。書寫中暫停。 */
    Maintenance(Thread.MIN_PRIORITY),
}

class BackgroundScheduler(
    /** 現在是不是「筆正在忙」。預設讀引擎的書寫活動；測試可以換掉。 */
    @Volatile var inkBusy: () -> Boolean = { com.kairumo.padnote.ink.InkEngine.isActivelyInking(500L) },
    /** 書寫中，被暫停的工作隔多久再看一次。 */
    @Volatile var retryIntervalMs: Long = 150L
) {
    private val pools = ConcurrentHashMap<BackgroundPriority, ScheduledExecutorService>()
    private val inFlight: MutableSet<String> = ConcurrentHashMap.newKeySet()

    private fun pool(p: BackgroundPriority): ScheduledExecutorService = pools.getOrPut(p) {
        Executors.newSingleThreadScheduledExecutor { task ->
            Thread(task, "kairumo-bg-${p.name}").apply { isDaemon = true; priority = p.threadPriority }
        }
    }

    /** 排一件工作。`key` 相同且前一件還沒做完時不重複排（預取常被連續觸發）。 */
    fun submit(priority: BackgroundPriority, key: String? = null, work: () -> Unit) {
        if (key != null && !inFlight.add(key)) return
        run(priority, key, work)
    }

    private fun run(priority: BackgroundPriority, key: String?, work: () -> Unit) {
        val executor = pool(priority)
        executor.execute {
            if (priority != BackgroundPriority.Interactive && runCatching(inkBusy).getOrDefault(false)) {
                executor.schedule({ run(priority, key, work) }, retryIntervalMs, TimeUnit.MILLISECONDS)
                return@execute
            }
            try {
                work()
            } finally {
                if (key != null) inFlight.remove(key)
            }
        }
    }

    companion object {
        // profile-scope: device 排程器本身不含使用者資料
        val shared = BackgroundScheduler()
    }
}
