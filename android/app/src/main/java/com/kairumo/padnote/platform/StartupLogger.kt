package com.kairumo.padnote.platform

import android.os.Looper
import androidx.compose.runtime.mutableStateListOf
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

data class StartupLogEntry(
    val id: String = java.util.UUID.randomUUID().toString(),
    val timestamp: Long = System.currentTimeMillis(),
    val thread: String,
    val elapsed: String,
    val rawMessage: String,
    val key: String? = null,
    val args: List<String> = emptyList()
) {
    /** 有 [key] 時顯示才查字串表：存的是鍵與參數，切換語言後舊紀錄也會跟著換。 */
    val message: String
        get() = "[$elapsed] " + (key?.let { com.kairumo.padnote.L10n.f(it, *args.toTypedArray()) } ?: rawMessage)
}

object StartupLogger {
    val entries = mutableStateListOf<StartupLogEntry>()
    private val startTime = System.currentTimeMillis()
    private val fullDateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US)

    fun log(message: String) = record(message, null, emptyList())

    /** 以字串表的鍵記一筆日誌。使用者看得到診斷頁，所以訊息要跟著介面語言走。 */
    fun logKey(key: String, vararg args: Any?) = record(key, key, args.map { "$it" })

    private fun record(message: String, key: String?, args: List<String>) {
        val now = System.currentTimeMillis()
        val elapsedSec = (now - startTime) / 1000.0
        val elapsedStr = String.format(Locale.US, "+%.3fs", elapsedSec)
        val isMain = Looper.myLooper() == Looper.getMainLooper()
        val threadName = if (isMain) "Main" else "Bg"
        val entry = StartupLogEntry(
            thread = threadName,
            elapsed = elapsedStr,
            rawMessage = message,
            key = key,
            args = args
        )
        if (isMain) {
            addEntry(entry)
        } else {
            android.os.Handler(Looper.getMainLooper()).post {
                addEntry(entry)
            }
        }
    }

    private fun addEntry(entry: StartupLogEntry) {
        entries.add(entry)
        if (entries.size > 200) {
            entries.removeRange(0, entries.size - 200)
        }
    }

    fun clear() {
        entries.clear()
    }

    fun exportText(includeTimestamp: Boolean = true): String {
        return entries.joinToString("\n") { entry ->
            if (includeTimestamp) {
                "[${fullDateFormat.format(Date(entry.timestamp))}] [${entry.thread}] ${entry.message}"
            } else {
                entry.message
            }
        }
    }
}
