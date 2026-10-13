package com.kairumo.padnote.platform

import android.content.Context
import android.os.Build
import android.util.Log
import com.kairumo.padnote.ui.LogExportUtility
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Android 崩潰與持續運作日誌記錄器 (Crash & Runtime Logger)。
 *
 * 1. 捕捉全域 Uncaught Exception 並寫入本機 filesDir/kairumo_last_crash.log。
 * 2. 同步及執行時期關鍵日誌自動滾動寫入 filesDir/kairumo_runtime.log。
 * 3. 提供一鍵匯出完整診斷日誌，讓使用者精確回報當機或 ANR 問題。
 */
// profile-scope: device 崩潰與診斷日誌是整台裝置的
object CrashLogger {
    private const val TAG = "CrashLogger"
    private const val CRASH_FILE_NAME = "kairumo_last_crash.log"
    private const val RUNTIME_LOG_NAME = "kairumo_runtime.log"
    private const val RUNTIME_LOG_OLD_NAME = "kairumo_runtime.log.1"
    private const val MAX_LOG_SIZE = 2 * 1024 * 1024L // 2MB

    private var defaultHandler: Thread.UncaughtExceptionHandler? = null
    private var installed = false
    private var appContext: Context? = null
    private val lock = Any()
    // 寫檔放背景單一執行緒：同步日誌可能從主執行緒呼叫，同步寫檔會重新造成 ANR。
    private val writer = java.util.concurrent.Executors.newSingleThreadExecutor { r ->
        Thread(r, "kairumo-runtime-log").apply { isDaemon = true }
    }

    // SimpleDateFormat 不是執行緒安全的，每次新建。
    private fun now(): String =
        SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US).format(Date())

    fun install(context: Context) {
        if (installed) return
        installed = true
        appContext = context.applicationContext
        defaultHandler = Thread.getDefaultUncaughtExceptionHandler()

        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                recordCrash(context.applicationContext, thread, throwable)
            } catch (t: Throwable) {
                Log.e(TAG, "Failed to record uncaught exception", t)
            } finally {
                defaultHandler?.uncaughtException(thread, throwable)
            }
        }

        logRuntime("=== Kairumo 啟動: ${Build.MANUFACTURER} ${Build.MODEL} (Android ${Build.VERSION.RELEASE}, API ${Build.VERSION.SDK_INT}) ===")
    }

    fun logRuntime(message: String) {
        val ctx = appContext ?: return
        val line = "[${now()}] $message\n"
        runCatching { writer.execute { appendLine(ctx, line) } }
    }

    private fun appendLine(ctx: Context, line: String) {
        synchronized(lock) {
            try {
                // profile-scope: device 崩潰與診斷日誌是整台裝置的
                val file = File(ctx.filesDir, RUNTIME_LOG_NAME)
                if (file.exists() && file.length() > MAX_LOG_SIZE) {
                    // profile-scope: device
                    val oldFile = File(ctx.filesDir, RUNTIME_LOG_OLD_NAME)
                    if (oldFile.exists()) oldFile.delete()
                    file.renameTo(oldFile)
                }
                file.appendText(line, Charsets.UTF_8)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write runtime log", e)
            }
        }
    }

    private fun recordCrash(context: Context, thread: Thread, throwable: Throwable) {
        val sw = StringWriter()
        val pw = PrintWriter(sw)
        throwable.printStackTrace(pw)
        val stackTrace = sw.toString()

        val now = now()

        val report = buildString {
            append("=== KAIRUMO CRASH REPORT ===\n")
            append("Timestamp: ").append(now).append("\n")
            append("Thread: ").append(thread.name).append(" (id=").append(thread.id).append(")\n")
            append("Device: ").append(Build.MANUFACTURER).append(" ").append(Build.MODEL).append("\n")
            append("Android OS: ").append(Build.VERSION.RELEASE).append(" (API ").append(Build.VERSION.SDK_INT).append(")\n")
            append("Exception: ").append(throwable.javaClass.name).append("\n")
            append("Message: ").append(throwable.message ?: "").append("\n\n")
            append("--- STACK TRACE ---\n")
            append(stackTrace)
            append("\n============================\n")
        }

        try {
            // profile-scope: device
            val file = File(context.filesDir, CRASH_FILE_NAME)
            file.writeText(report)
            Log.e(TAG, "Crash logged to ${file.absolutePath}")
            appendLine(context, "[${now()}] FATAL EXCEPTION:\n$report\n") // 行程將結束，同步寫
        } catch (e: Exception) {
            Log.e(TAG, "Cannot write crash log to disk", e)
        }
    }

    fun lastCrashLog(context: Context): String? {
        // profile-scope: device
        val file = File(context.filesDir, CRASH_FILE_NAME)
        return if (file.exists() && file.length() > 0) {
            runCatching { file.readText() }.getOrNull()
        } else {
            null
        }
    }

    fun runtimeLog(context: Context): String {
        return synchronized(lock) {
            // profile-scope: device
            val oldFile = File(context.filesDir, RUNTIME_LOG_OLD_NAME)
            // profile-scope: device
            val file = File(context.filesDir, RUNTIME_LOG_NAME)
            buildString {
                if (oldFile.exists()) {
                    append(runCatching { oldFile.readText() }.getOrDefault(""))
                }
                if (file.exists()) {
                    append(runCatching { file.readText() }.getOrDefault(""))
                }
            }
        }
    }

    fun allLogs(context: Context): String {
        val crash = lastCrashLog(context)
        val runtime = runtimeLog(context)
        return buildString {
            append("=== KAIRUMO 系統與診斷日誌匯出 ===\n")
            append("裝置: ").append(Build.MANUFACTURER).append(" ").append(Build.MODEL).append("\n")
            append("系統版本: Android ").append(Build.VERSION.RELEASE).append(" (API ").append(Build.VERSION.SDK_INT).append(")\n")
            append("時間: ").append(now()).append("\n\n")
            if (!crash.isNullOrBlank()) {
                append("--- 最新崩潰記錄 (LAST CRASH) ---\n")
                append(crash)
                append("\n\n")
            }
            append("--- 執行時期日誌 (RUNTIME & SYNC LOGS) ---\n")
            append(if (runtime.isNotBlank()) runtime else "（無執行時期日誌）")
            append("\n")
        }
    }

    fun exportLogs(context: Context) {
        val text = allLogs(context)
        val sdf = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US)
        val filename = "kairumo_log_${sdf.format(Date())}.txt"
        LogExportUtility.shareTextFile(context, text, filename)
    }

    fun clearCrashLog(context: Context) {
        // profile-scope: device
        val file = File(context.filesDir, CRASH_FILE_NAME)
        if (file.exists()) {
            file.delete()
        }
    }
}
