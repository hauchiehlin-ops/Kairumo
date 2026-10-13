package com.kairumo.padnote.platform

import android.os.Handler
import android.os.Looper
import android.os.SystemClock

/**
 * 主執行緒卡頓記錄（對應 Apple 的 `MainThreadStallMonitor`）。
 *
 * 畫面卡住但沒有當機、也沒有達到 ANR 門檻（5 秒）的時候，系統不會留下任何東西，使用者只能說「卡住了」。
 * 這個監看器在背景每 0.25 秒問主執行緒一聲；超過 1.5 秒沒回應，就在卡住期間取主執行緒的**堆疊**
 * （Android 可以直接讀另一條執行緒的堆疊，不必像 iOS 那樣送訊號），恢復之後再記一筆「卡了幾秒」。
 * 日誌寫進 [CrashLogger] 的執行時期日誌，可用診斷頁的匯出帶走。只記錄，不改變任何行為。
 */
// profile-scope: device 診斷用，整台裝置共用
object MainThreadStallMonitor {
    private const val THRESHOLD_MS = 1_500L
    private const val POLL_MS = 250L
    private const val SAMPLE_INTERVAL_MS = 4_000L
    private const val MAX_SAMPLES = 3
    private const val MAX_FRAMES = 30

    @Volatile private var lastPong = SystemClock.elapsedRealtime()
    @Volatile private var started = false
    @Volatile private var lastCrumb = "—"

    /** 記下最近一件事（任何執行緒都可以呼叫）。 */
    fun breadcrumb(text: String) {
        lastCrumb = text
    }

    fun start() {
        if (started) return
        started = true
        val main = Handler(Looper.getMainLooper())
        val mainThread = Looper.getMainLooper().thread
        lastPong = SystemClock.elapsedRealtime()
        Thread({
            var stallStart = 0L
            var samples = 0
            var lastSampleAt = 0L
            while (true) {
                runCatching { Thread.sleep(POLL_MS) }
                val now = SystemClock.elapsedRealtime()
                val silent = now - lastPong
                if (silent > THRESHOLD_MS) {
                    if (stallStart == 0L) stallStart = lastPong
                    if (samples < MAX_SAMPLES && now - lastSampleAt >= SAMPLE_INTERVAL_MS) {
                        lastSampleAt = now
                        samples++
                        CrashLogger.logRuntime(
                            "主執行緒卡住中（已 ${silent / 1000.0} 秒），堆疊樣本 $samples：\n" +
                                formatStack(mainThread.stackTrace)
                        )
                    }
                } else if (stallStart != 0L) {
                    CrashLogger.logRuntime(
                        "主執行緒卡住 ${(now - stallStart) / 1000.0} 秒（畫面無回應）。卡住前最後一件事：$lastCrumb"
                    )
                    stallStart = 0L
                    samples = 0
                    lastSampleAt = 0L
                }
                main.post { lastPong = SystemClock.elapsedRealtime() }
            }
        }, "kairumo-stall-monitor").apply { isDaemon = true }.start()
    }

    /** 堆疊轉成日誌文字（最多 [MAX_FRAMES] 層）。 */
    internal fun formatStack(frames: Array<StackTraceElement>): String =
        frames.take(MAX_FRAMES).joinToString("\n") { "    at $it" }
}
