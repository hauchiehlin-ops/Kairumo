package com.kairumo.padnote.platform

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import com.kairumo.padnote.audio.AudioPlayback
import java.io.File
import kotlinx.coroutines.delay
import uniffi.padnote_core.audioEncodePcmToOpus
import uniffi.padnote_core.localizeTranscriptScript
import kotlin.math.PI
import kotlin.math.sin

/**
 * 裝置上的一鍵自檢（驗證層 L4，見 docs/plans/ipad-first-verification.md）。
 *
 * 與 Apple 的 `PlatformSelfCheck` 同一組問題、同一個報告格式：使用者回報「這台不行」時，
 * 我們拿到的是通過／失敗與原因，而不是一句症狀。每一項都獨立、可重複、不動使用者資料
 * （暫存檔用完即刪）。
 */
data class SelfCheckResult(val id: String, val title: String, val status: Status, val detail: String) {
    enum class Status { PASS, WARN, FAIL }
}

object PlatformSelfCheck {

    suspend fun run(context: Context, languageTag: String): List<SelfCheckResult> = listOf(
        checkPlaybackPipeline(context),
        checkMicrophonePermission(context),
        checkLibraryFolder(context),
        checkFilePicker(context),
        checkTranscriptScript(),
        checkFreeSpace(context),
    )

    fun report(results: List<SelfCheckResult>, languageTag: String): String = buildString {
        appendLine("Kairumo self-check")
        appendLine("device: ${Build.MANUFACTURER} ${Build.MODEL} / Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})")
        appendLine("language: $languageTag")
        appendLine()
        results.forEach { appendLine("[${it.status.name}] ${it.title} — ${it.detail}") }
    }

    /** 合成一小段 Opus → 用真正的播放器播 → 位置要前進。 */
    private suspend fun checkPlaybackPipeline(context: Context): SelfCheckResult {
        val title = "Playback pipeline"
        val file = File(context.cacheDir, "selfcheck-${System.nanoTime()}.opus")
        return try {
            val pcm = List(16_000) { (sin(it * 2.0 * PI * 440.0 / 16_000.0) * 0.05).toFloat() }
            if (audioEncodePcmToOpus(pcm, file.absolutePath) == null) {
                return SelfCheckResult("audio.playback", title, SelfCheckResult.Status.FAIL, "core encoder failed")
            }
            val started = AudioPlayback.toggle("selfcheck", file) {}
            if (started == null) {
                return SelfCheckResult("audio.playback", title, SelfCheckResult.Status.FAIL, "MediaPlayer did not start")
            }
            delay(700)
            val position = AudioPlayback.currentPositionMs
            val ok = position > 50
            SelfCheckResult(
                "audio.playback", title,
                if (ok) SelfCheckResult.Status.PASS else SelfCheckResult.Status.FAIL,
                if (ok) "position advanced to ${position}ms" else "started but position did not advance (${position}ms)"
            )
        } catch (t: Throwable) {
            SelfCheckResult("audio.playback", title, SelfCheckResult.Status.FAIL, t.message ?: t.javaClass.simpleName)
        } finally {
            AudioPlayback.stop()
            file.delete()
        }
    }

    private fun checkMicrophonePermission(context: Context): SelfCheckResult {
        val granted = context.checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        return SelfCheckResult(
            "mic.permission", "Microphone permission",
            if (granted) SelfCheckResult.Status.PASS else SelfCheckResult.Status.WARN,
            if (granted) "granted" else "not granted yet (asked on first recording)"
        )
    }

    /** 筆記庫所在目錄存在而且寫得進去。 */
    private fun checkLibraryFolder(context: Context): SelfCheckResult {
        val dir = context.filesDir
        val probe = File(dir, ".selfcheck-${System.nanoTime()}")
        val writable = runCatching { probe.writeText("x"); true }.getOrDefault(false)
        probe.delete()
        return SelfCheckResult(
            "folder.library", "Library folder",
            if (writable) SelfCheckResult.Status.PASS else SelfCheckResult.Status.FAIL,
            "${dir.absolutePath} writable=$writable"
        )
    }

    /** 系統有沒有能處理「選檔案」的 Activity（沒有的話匯入入口全部無效）。 */
    private fun checkFilePicker(context: Context): SelfCheckResult {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("*/*")
        val handlers = context.packageManager.queryIntentActivities(intent, 0).size
        return SelfCheckResult(
            "picker.presenter", "File picker",
            if (handlers > 0) SelfCheckResult.Status.PASS else SelfCheckResult.Status.FAIL,
            "$handlers handler(s) for ACTION_OPEN_DOCUMENT"
        )
    }

    private fun checkTranscriptScript(): SelfCheckResult {
        val converted = runCatching { localizeTranscriptScript("语音识别", "zh-Hant") }.getOrDefault("?")
        return SelfCheckResult(
            "transcript.script", "Transcript script (zh-Hant)",
            if (converted == "語音識別") SelfCheckResult.Status.PASS else SelfCheckResult.Status.FAIL,
            "语音识别 → $converted"
        )
    }

    private fun checkFreeSpace(context: Context): SelfCheckResult {
        val mb = Environment.getDataDirectory().usableSpace / 1_048_576
        return SelfCheckResult(
            "storage.free", "Free storage",
            when {
                mb >= 200 -> SelfCheckResult.Status.PASS
                mb >= 50 -> SelfCheckResult.Status.WARN
                else -> SelfCheckResult.Status.FAIL
            },
            "$mb MB"
        )
    }
}
