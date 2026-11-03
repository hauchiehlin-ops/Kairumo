package com.kairumo.padnote.perf

import android.app.Activity
import android.os.Build
import android.view.FrameMetrics
import android.view.Window
import com.kairumo.padnote.platform.CrashLogger

/**
 * 真實使用者的裝置表現（對應 Apple 的 `FieldTelemetry`）。
 *
 * 開發者手上的裝置只是一個樣本。這裡用系統的 `FrameMetrics` 在**這台裝置上**累計卡頓幀
 * （總耗時超過目標幀時間 1.5 倍）與嚴重卡頓幀（超過 700ms，凍結幀），並餵給 [FrameGovernor]
 * 當目標幀時間。摘要只留在本機（執行時期日誌，診斷匯出時帶走），**不上傳任何東西**，也不含筆記內容。
 */
// profile-scope: device 系統彙總的幀表現，不含使用者資料
object FieldTelemetry {
    private const val SUMMARY_EVERY_FRAMES = 1800
    @Volatile private var started = false
    private var total = 0L
    private var janky = 0L
    private var frozen = 0L

    /** 最近的摘要（最新在後）。 */
    private val summaries = ArrayDeque<String>()

    fun recentSummaries(): List<String> = synchronized(summaries) { summaries.toList() }

    fun start(activity: Activity) {
        if (started || Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        started = true
        val window: Window = activity.window
        val refresh = runCatching {
            @Suppress("DEPRECATION")
            activity.windowManager.defaultDisplay.refreshRate
        }.getOrDefault(60f).coerceIn(30f, 240f)
        val targetMs = 1000.0 / refresh
        FrameGovernor.shared.targetFrameMs = targetMs
        window.addOnFrameMetricsAvailableListener({ _, metrics, _ ->
            val totalMs = metrics.getMetric(FrameMetrics.TOTAL_DURATION) / 1_000_000.0
            record(totalMs, targetMs)
        }, android.os.Handler(android.os.Looper.getMainLooper()))
    }

    internal fun record(totalMs: Double, targetMs: Double) {
        var line: String? = null
        synchronized(this) {
            total++
            if (totalMs > targetMs * 1.5) janky++
            if (totalMs > 700.0) frozen++
            if (total % SUMMARY_EVERY_FRAMES == 0L) {
                line = "frames=%d janky=%d (%.1f%%) frozen=%d".format(total, janky, janky * 100.0 / total, frozen)
            }
        }
        line?.let {
            synchronized(summaries) {
                summaries.addLast(it)
                if (summaries.size > 20) summaries.removeFirst()
            }
            runCatching { CrashLogger.logRuntime("field: $it") }
        }
    }
}
