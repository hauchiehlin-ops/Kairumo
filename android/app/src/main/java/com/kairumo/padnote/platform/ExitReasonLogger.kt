package com.kairumo.padnote.platform

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.os.Build
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 上一次（以及更早幾次）行程**為什麼結束**，寫進執行時期日誌。
 *
 * 為什麼需要：原生層（Rust）崩潰、被系統因記憶體殺掉、ANR 之後被關掉 —— 這幾種都不會經過
 * Kotlin 的未捕捉例外處理常式，[CrashLogger] 什麼都看不到。使用者回報的樣子只有「App 自己重開了」，
 * 日誌裡是一行啟動訊息接在一段同步的中間。Android 11（API 30）起系統自己記得每次行程結束的原因，
 * 這裡把它讀出來：是原生崩潰、ANR、低記憶體、被使用者滑掉，還是正常結束。
 *
 * 每一筆只記一次（記下已處理到的時間戳）。
 */
// profile-scope: device 診斷用，整台裝置共用
object ExitReasonLogger {
    private const val PREFS = "kairumo.diagnostics"
    private const val KEY_LAST = "last_exit_info_ms"
    private const val MAX_ENTRIES = 5

    fun logRecent(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        runCatching {
            val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val prefs = com.kairumo.padnote.profile.ProfileContext.devicePrefs(context, PREFS)
            val seen = prefs.getLong(KEY_LAST, 0L)
            val infos = am.getHistoricalProcessExitReasons(context.packageName, 0, MAX_ENTRIES)
                .filter { it.timestamp > seen }
                .sortedBy { it.timestamp }
            for (info in infos) {
                CrashLogger.logRuntime(describe(info))
                // ANR 的追蹤是文字，留一段；原生崩潰的是二進位 tombstone，這裡不展開。
                if (info.reason == ApplicationExitInfo.REASON_ANR) {
                    runCatching {
                        info.traceInputStream?.bufferedReader()?.useLines { lines ->
                            CrashLogger.logRuntime("ANR 追蹤（前 60 行）：\n" + lines.take(60).joinToString("\n"))
                        }
                    }
                }
            }
            infos.lastOrNull()?.let { prefs.edit().putLong(KEY_LAST, it.timestamp).apply() }
        }
    }

    internal fun describe(info: ApplicationExitInfo): String = format(
        reason = info.reason, status = info.status, timestamp = info.timestamp,
        description = info.description, importance = info.importance, pssKb = info.pss
    )

    /** 純函式，給測試用。 */
    internal fun format(
        reason: Int, status: Int, timestamp: Long, description: String?, importance: Int, pssKb: Long
    ): String {
        val time = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date(timestamp))
        val foreground = if (importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND) "前景" else "背景"
        return "上次行程結束：$time · ${reasonName(reason)} · 狀態 $status · $foreground · " +
            "PSS ${pssKb / 1024} MB" + (description?.takeIf { it.isNotBlank() }?.let { " · $it" } ?: "")
    }

    internal fun reasonName(reason: Int): String = when (reason) {
        ApplicationExitInfo.REASON_EXIT_SELF -> "自行結束（exit）"
        ApplicationExitInfo.REASON_SIGNALED -> "被訊號終止（signaled）"
        ApplicationExitInfo.REASON_LOW_MEMORY -> "低記憶體被系統殺掉"
        ApplicationExitInfo.REASON_CRASH -> "Java/Kotlin 例外崩潰"
        ApplicationExitInfo.REASON_CRASH_NATIVE -> "原生層崩潰（Rust / C++）"
        ApplicationExitInfo.REASON_ANR -> "ANR（無回應）"
        ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "初始化失敗"
        ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "權限變更"
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "資源使用過量"
        ApplicationExitInfo.REASON_USER_REQUESTED -> "使用者要求結束（例如強制停止）"
        ApplicationExitInfo.REASON_USER_STOPPED -> "使用者停止"
        ApplicationExitInfo.REASON_DEPENDENCY_DIED -> "依賴的行程結束"
        ApplicationExitInfo.REASON_OTHER -> "其他原因"
        else -> "未知（$reason）"
    }
}
