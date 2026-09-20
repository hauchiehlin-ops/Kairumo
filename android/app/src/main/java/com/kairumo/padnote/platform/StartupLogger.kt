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
    val message: String
)

object StartupLogger {
    val entries = mutableStateListOf<StartupLogEntry>()
    private val startTime = System.currentTimeMillis()
    private val fullDateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US)

    fun log(message: String) {
        val now = System.currentTimeMillis()
        val elapsedSec = (now - startTime) / 1000.0
        val elapsedStr = String.format(Locale.US, "+%.3fs", elapsedSec)
        val isMain = Looper.myLooper() == Looper.getMainLooper()
        val threadName = if (isMain) "Main" else "Bg"
        val entry = StartupLogEntry(
            thread = threadName,
            message = "[$elapsedStr] $message"
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
