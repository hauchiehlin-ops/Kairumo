package com.kairumo.padnote.sync

import android.os.Looper
import androidx.compose.runtime.mutableStateListOf
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

enum class SyncSource(val rawValue: String) {
    GOOGLE_DRIVE("Google Drive"),
    FOLDER("Folder"),
    GENERAL("General")
}

data class SyncLogEntry(
    val id: String = java.util.UUID.randomUUID().toString(),
    val timestamp: Long = System.currentTimeMillis(),
    val source: SyncSource,
    val message: String
)

object SyncLogger {
    val entries = mutableStateListOf<SyncLogEntry>()

    private val fullDateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US)

    fun log(message: String, source: SyncSource = SyncSource.GENERAL) {
        val entry = SyncLogEntry(source = source, message = message)
        if (Looper.myLooper() == Looper.getMainLooper()) {
            addEntry(entry)
        } else {
            android.os.Handler(Looper.getMainLooper()).post {
                addEntry(entry)
            }
        }
    }

    private fun addEntry(entry: SyncLogEntry) {
        entries.add(entry)
        if (entries.size > 300) {
            entries.removeRange(0, entries.size - 300)
        }
    }

    fun clear(forSource: SyncSource? = null) {
        if (forSource != null) {
            entries.removeAll { it.source == forSource }
        } else {
            entries.clear()
        }
    }

    fun exportText(filter: SyncSource? = null, includeTimestamp: Boolean = true): String {
        val list = if (filter != null) entries.filter { it.source == filter } else entries
        return list.joinToString("\n") { entry ->
            if (includeTimestamp) {
                "[${fullDateFormat.format(Date(entry.timestamp))}] [${entry.source.rawValue}] ${entry.message}"
            } else {
                entry.message
            }
        }
    }
}
