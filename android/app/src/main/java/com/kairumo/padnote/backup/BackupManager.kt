package com.kairumo.padnote.backup

import android.content.Context
import android.net.Uri
import org.json.JSONObject
import uniffi.padnote_core.BackupInfo
import uniffi.padnote_core.createBackup
import uniffi.padnote_core.inspectBackup
import uniffi.padnote_core.restoreBackup
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

/**
 * 個人資料備份與一鍵復原（Android）。
 *
 * 容器格式在核心，與 Apple 端**同一份** —— iPad 上做的備份換到 Android 也
 * 開得起來。這裡只負責「哪些東西要進去」與「使用者按了什麼」。
 */
object BackupManager {

    const val FILE_EXTENSION = "kairumobackup"
    private const val PREFS = "kairumo"

    /** 備份檔暫存區。使用者要自己把它帶到雲端或電腦上才算數。 */
    private fun backupsDir(context: Context): File =
        File(context.cacheDir, "backups").apply { mkdirs() }

    // MARK: - 設定

    /**
     * 要一起備份的 App 設定。
     *
     * 只帶我們自己的 SharedPreferences。跨裝置失效的東西（同步資料夾的
     * URI 權限）帶過去只會讓使用者以為資料夾還在。
     */
    fun currentSettings(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val json = JSONObject()
        for ((key, value) in prefs.all) {
            if (key == "sync.treeUri") continue   // 換一台裝置就沒有那個授權了
            when (value) {
                is String, is Int, is Long, is Float, is Boolean -> json.put(key, value)
                else -> Unit
            }
        }
        return json.toString()
    }

    fun applySettings(context: Context, json: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        runCatching {
            val obj = JSONObject(json)
            for (key in obj.keys()) {
                if (key == "sync.treeUri") continue
                when (val value = obj.get(key)) {
                    is String -> prefs.putString(key, value)
                    is Int -> prefs.putInt(key, value)
                    is Long -> prefs.putLong(key, value)
                    is Boolean -> prefs.putBoolean(key, value)
                    is Double -> prefs.putFloat(key, value.toFloat())
                    else -> Unit
                }
            }
        }
        prefs.apply()
    }

    // MARK: - 建立

    /**
     * 建立備份檔。
     *
     * 檔名帶日期時間**與一段亂碼**：只帶到秒的話，同一秒建立的兩份會同名而
     * 互相覆蓋 —— 而「復原前先備份現況」正好就發生在同一秒，
     * 結果是安全備份把要復原的那份蓋掉。
     */
    fun create(
        context: Context,
        appVersion: String,
        date: Date = Date(),
        label: String = ""
    ): Pair<File, BackupInfo> {
        val stamp = SimpleDateFormat("yyyy-MM-dd'T'HH-mm-ss", Locale.US).format(date)
        val unique = UUID.randomUUID().toString().take(6)
        val suffix = if (label.isEmpty()) "" else "-$label"
        val out = File(backupsDir(context), "Kairumo-$stamp$suffix-$unique.$FILE_EXTENSION")

        val info = createBackup(
            sourceDir = context.filesDir.absolutePath,
            outPath = out.absolutePath,
            appVersion = appVersion,
            settingsJson = currentSettings(context),
            nowUnixMs = date.time.toULong()
        )
        return out to info
    }

    // MARK: - 檢視

    fun inspect(file: File): BackupInfo = inspectBackup(file.absolutePath)

    /** 把使用者選的 SAF 檔案複製到暫存區 —— 核心要的是路徑，不是 URI。 */
    fun stage(context: Context, uri: Uri): File {
        val staged = File(backupsDir(context), "incoming-${System.nanoTime()}.$FILE_EXTENSION")
        context.contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "無法讀取選取的檔案" }
            staged.outputStream().use { input.copyTo(it) }
        }
        return staged
    }

    // MARK: - 復原

    data class RestoreOutcome(
        val restored: Int,
        val corrupted: List<String>,
        /** 復原前自動留的現況備份。出事時從這裡回得去。 */
        val safetyBackup: File?
    )

    /**
     * 一鍵復原。
     *
     * 復原**之前**先把現況備份起來 —— 使用者按下去的那一刻，手上的資料就要
     * 被覆蓋了；萬一備份檔本身有問題，沒有安全網他會同時失去兩份。
     */
    fun restore(context: Context, file: File, appVersion: String): RestoreOutcome {
        val safety = runCatching { create(context, appVersion, label = "safety").first }.getOrNull()
        val report = restoreBackup(file.absolutePath, context.filesDir.absolutePath)
        applySettings(context, report.settingsJson)
        return RestoreOutcome(report.restored.size, report.corrupted, safety)
    }
}
