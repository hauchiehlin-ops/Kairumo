package com.kairumo.padnote.platform

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import androidx.core.content.ContextCompat
import com.kairumo.padnote.LocalizationStrings
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import com.kairumo.padnote.audio.StreamingTranscriber
import uniffi.padnote_core.PadnoteSession

/**
 * 麥克風擷取（工作包 WP6）。
 *
 * # 為什麼是 16kHz 單聲道 float
 *
 * 核心的 `feed_audio` 收的就是這個格式 —— 與 Apple 端同一條路徑、同一個
 * Opus 編碼器、同一份時間軸。取樣率換算若放在平台層各寫一次，兩邊錄出來的
 * 檔案就會不一樣，而「同一份筆記在兩個平台聽起來不一樣」是沒辦法解釋的。
 *
 * # 第一版沒有語音轉錄，但**錄音是可用的**
 *
 * `asr` feature 關掉的是轉錄（ONNX Runtime），不是錄音。libopus 有交叉編譯
 * 進來，實測 `feed_audio` 確實會寫出音框（見 `CoreCapabilityTest`）。
 */
class AudioCapture(private val context: Context) {

    companion object {
        const val SAMPLE_RATE = 16_000

        /** 有沒有麥克風權限。沒有就不要假裝在錄 —— 使用者會以為錄到了。 */
        fun hasPermission(context: Context): Boolean =
            ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED
    }

    private var record: AudioRecord? = null
    private var job: Job? = null
    private var transcriber: StreamingTranscriber? = null
    private val scope = CoroutineScope(Dispatchers.IO)
    @Volatile private var paused: Boolean = false

    val isRecording: Boolean get() = job?.isActive == true
    val isPaused: Boolean get() = paused

    /**
     * 開始錄音並持續餵給核心。
     *
     * @return 失敗的原因；成功時為 `null`。回傳字串而不是 boolean，是因為
     *         「錄不起來」有好幾種原因，使用者需要知道是哪一種。
     */
    @SuppressLint("MissingPermission")
    fun start(pageId: String?, 
        session: PadnoteSession,
        languageTag: String = "zh-Hant",
        onError: (String) -> Unit = {}
    ): String? {
        fun l(key: String, arg: String = "") =
            LocalizationStrings.localized(key, languageTag).replace("%@", arg)

        if (isRecording) return null
        if (!hasPermission(context)) return l("err_no_mic_permission")

        val minBuffer = AudioRecord.getMinBufferSize(
            SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_FLOAT
        )
        if (minBuffer <= 0) return l("err_mic_unsupported")

        // 緩衝取最小值的四倍：剛好最小值的話，背景執行緒稍微被排程延遲就掉資料。
        val bufferBytes = minBuffer * 4
        val recorder = try {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_FLOAT,
                bufferBytes
            )
        } catch (t: Throwable) {
            return l("err_mic_open_failed", t.message ?: "")
        }

        if (recorder.state != AudioRecord.STATE_INITIALIZED) {
            recorder.release()
            return l("err_mic_open_failed", "init")
        }

        record = recorder
        recorder.startRecording()
        
        transcriber = StreamingTranscriber(context, session)
        if (pageId != null) transcriber?.start(pageId, languageTag)
        runCatching { session.startRecording() }.onFailure {
            stop(session)
            return l("err_core_not_ready") + "：${it.message}"
        }

        val chunk = FloatArray(bufferBytes / 4 / 2)
        paused = false
        job = scope.launch {
            while (isActiveRecording()) {
                val read = recorder.read(chunk, 0, chunk.size, AudioRecord.READ_BLOCKING)
                if (read <= 0 || paused) continue
                val slice = if (read == chunk.size) chunk else chunk.copyOf(read)
                runCatching { session.feedAudio(slice.toList()) }
                    .onFailure { onError("餵音訊失敗：${it.message}"); return@launch }
            }
        }
        return null
    }

    /** 暫停錄音：保留錄音硬體但暫停餵送音訊 */
    fun pause() {
        if (isRecording) {
            paused = true
        }
    }

    /** 恢復錄音：繼續餵送音訊 */
    fun resume() {
        if (isRecording) {
            paused = false
        }
    }

    private fun isActiveRecording(): Boolean =
        record?.recordingState == AudioRecord.RECORDSTATE_RECORDING

    /** 停止錄音。回傳核心記錄到的時長（微秒）。 */
    fun stop(session: PadnoteSession): ULong {
        paused = false
        transcriber?.stop()
        job?.cancel()
        job = null
        record?.let { r ->
            runCatching { if (r.state == AudioRecord.STATE_INITIALIZED) r.stop() }
            r.release()
        }
        record = null
        runCatching { session.stopRecording() }
        return runCatching { session.recordedAudioUs() }.getOrDefault(0uL)
    }
}
