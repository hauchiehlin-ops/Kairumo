package com.kairumo.padnote.platform

import android.content.Context
import android.os.Build
import android.util.Log
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Android 崩潰捕捉器 (Crash Logger)。
 *
 * 捕捉全域 Uncaught Exception 並寫入本機 filesDir/kairumo_last_crash.log，
 * 提供給使用者在 App 內「系統診斷 (System Diagnostics)」頁面直接檢視、複製或分享給開發者。
 */
object CrashLogger {
    private const val TAG = "CrashLogger"
    private const val CRASH_FILE_NAME = "kairumo_last_crash.log"
    private var defaultHandler: Thread.UncaughtExceptionHandler? = null
    private var installed = false

    fun install(context: Context) {
        if (installed) return
        installed = true
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
    }

    private fun recordCrash(context: Context, thread: Thread, throwable: Throwable) {
        val sw = StringWriter()
        val pw = PrintWriter(sw)
        throwable.printStackTrace(pw)
        val stackTrace = sw.toString()

        val sdf = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US)
        val now = sdf.format(Date())

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
            val file = File(context.filesDir, CRASH_FILE_NAME)
            file.writeText(report)
            Log.e(TAG, "Crash logged to ${file.absolutePath}")
        } catch (e: Exception) {
            Log.e(TAG, "Cannot write crash log to disk", e)
        }
    }

    fun lastCrashLog(context: Context): String? {
        val file = File(context.filesDir, CRASH_FILE_NAME)
        return if (file.exists() && file.length() > 0) {
            runCatching { file.readText() }.getOrNull()
        } else {
            null
        }
    }

    fun clearCrashLog(context: Context) {
        val file = File(context.filesDir, CRASH_FILE_NAME)
        if (file.exists()) {
            file.delete()
        }
    }
}
