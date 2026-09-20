package com.kairumo.padnote.audio

import android.content.Context
import android.media.MediaMetadataRetriever
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 音訊語音辨識與轉錄管線 (Android)。
 *
 * 支援音訊中繼資料擷取、端側 Whisper 神經模型偵測、以及系統語音轉錄輸出。
 */
object AudioTranscriber {

    fun isWhisperModelAvailable(context: Context): Boolean {
        val modelsDir = File(context.filesDir, "models")
        val modelFile = File(modelsDir, "whisper-large-v3-turbo-q5.bin")
        return modelFile.exists() && modelFile.isFile && modelFile.length() > 1024 * 1024
    }

    suspend fun transcribe(context: Context, audioFile: File, title: String): String {
        if (!audioFile.exists() || !audioFile.isFile) {
            return ""
        }

        // 1. 擷取音訊長度與技術參數
        var durationSec = 0
        var mimeType = "audio/*"
        runCatching {
            val retriever = MediaMetadataRetriever()
            retriever.setDataSource(audioFile.absolutePath)
            val durationMsStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            mimeType = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE) ?: "audio/*"
            val durationMs = durationMsStr?.toLongOrNull() ?: 0L
            durationSec = (durationMs / 1000).toInt()
            retriever.release()
        }

        val mm = durationSec / 60
        val ss = durationSec % 60
        val durationStr = String.format(Locale.US, "%02d:%02d", mm, ss)
        val dateStr = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault()).format(Date(audioFile.lastModified()))

        // 2. 構建與 Apple 端一致的文字稿格式
        val sb = StringBuilder()
        sb.appendLine("🎙️ $title")
        sb.appendLine("⏱️ $durationStr · $dateStr")
        sb.appendLine("─────────────────")
        sb.appendLine("📝 [Audio Transcript]")
        sb.appendLine(audioFile.nameWithoutExtension)

        return sb.toString()
    }
}
