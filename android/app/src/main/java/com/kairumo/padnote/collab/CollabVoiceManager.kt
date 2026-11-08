package com.kairumo.padnote.collab

import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.NoiseSuppressor
import android.util.Base64
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * 線上協同即時語音管理器（Android）。
 *
 * 與 Apple 端的 `CollabVoiceManager` 講**同一套 `live_voice` 協定**：
 * - 取樣率統一為 16kHz Mono 16-bit PCM。
 * - 100ms 一個微音框（1600 samples = 3200 bytes）。
 * - 採用系統硬體級 AEC (AcousticEchoCanceler) 與降噪。
 * - 透過現有協同通道端對端加密（AES-256-GCM）傳輸。
 */
class CollabVoiceManager(
    private val context: Context,
    private val collaboration: CollaborationManager
) {
    companion object {
        const val SAMPLE_RATE = 16_000
        const val FRAME_DURATION_MS = 100
        const val FRAME_SAMPLES = SAMPLE_RATE * FRAME_DURATION_MS / 1000 // 1600 samples
        const val FRAME_BYTES = FRAME_SAMPLES * 2 // 3200 bytes
    }

    var isTalking by mutableStateOf(false)
        private set

    var activeSpeakerName by mutableStateOf<String?>(null)
        private set

    var isMuted by mutableStateOf(false)
        private set

    fun setMutedState(muted: Boolean) {
        isMuted = muted
        audioTrack?.setVolume(if (muted) 0f else 1f)
    }

    private val scope = CoroutineScope(Dispatchers.IO)
    private var recordJob: Job? = null
    private var audioRecord: AudioRecord? = null
    private var echoCanceler: AcousticEchoCanceler? = null
    private var noiseSuppressor: NoiseSuppressor? = null

    private var audioTrack: AudioTrack? = null
    private var currentSpeakerUserId: String? = null
    private var speakerTimeoutJob: Job? = null
    private var outgoingSeq: Long = 0

    // ── PTT 按住發話控制 ──────────────────────────────────────────

    @SuppressLint("MissingPermission")
    fun startTalking() {
        if (isTalking) return
        if (collaboration.status !is CollaborationManager.Status.Connected) {
            android.util.Log.w("CollabVoice", "startTalking: 協同尚未連線")
            return
        }
        if (context.checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            android.util.Log.w("CollabVoice", "startTalking: 缺少 RECORD_AUDIO 權限")
            return
        }

        isTalking = true
        outgoingSeq = 0

        // 廣播開始發話事件
        collaboration.sendLiveVoice("begin", outgoingSeq, "")

        val minBuf = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        val bufSize = maxOf(minBuf * 2, FRAME_BYTES * 4)

        val record = try {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufSize
            )
        } catch (t: Throwable) {
            android.util.Log.e("CollabVoice", "startTalking: AudioRecord 建立失敗", t)
            isTalking = false
            return
        }

        if (record.state != AudioRecord.STATE_INITIALIZED) {
            android.util.Log.e("CollabVoice", "startTalking: AudioRecord 初始化失敗 (state != INITIALIZED)")
            record.release()
            isTalking = false
            return
        }

        // 啟用硬體回音消除與降噪
        if (AcousticEchoCanceler.isAvailable()) {
            runCatching {
                echoCanceler = AcousticEchoCanceler.create(record.audioSessionId)?.apply { enabled = true }
            }
        }
        if (NoiseSuppressor.isAvailable()) {
            runCatching {
                noiseSuppressor = NoiseSuppressor.create(record.audioSessionId)?.apply { enabled = true }
            }
        }

        audioRecord = record
        try {
            record.startRecording()
        } catch (t: Throwable) {
            stopTalking()
            return
        }

        recordJob = scope.launch {
            val buffer = ByteArray(FRAME_BYTES)
            while (isTalking && record.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                var readTotal = 0
                while (readTotal < FRAME_BYTES && isTalking) {
                    val read = record.read(buffer, readTotal, FRAME_BYTES - readTotal)
                    if (read <= 0) break
                    readTotal += read
                }
                if (readTotal == FRAME_BYTES && isTalking) {
                    outgoingSeq++
                    val b64 = Base64.encodeToString(buffer, Base64.NO_WRAP)
                    collaboration.sendLiveVoice("chunk", outgoingSeq, b64)
                }
            }
        }
    }

    fun stopTalking() {
        if (!isTalking) return
        isTalking = false

        recordJob?.cancel()
        recordJob = null

        runCatching {
            audioRecord?.stop()
            audioRecord?.release()
        }
        audioRecord = null

        runCatching {
            echoCanceler?.release()
            noiseSuppressor?.release()
        }
        echoCanceler = null
        noiseSuppressor = null

        // 廣播結束發話事件
        collaboration.sendLiveVoice("end", outgoingSeq + 1, "")
    }

    // ── 接收遠端語音（`live_voice`）──────────────────────────────

    fun receiveRemoteVoice(userId: String, payload: JSONObject) {
        if (userId == collaboration.currentUserId) return

        val phase = payload.optString("phase", "chunk")
        val userName = payload.optString("user_name").ifEmpty { userId.take(6) }
        val audioBase64 = payload.optString("audio", "")

        when (phase) {
            "begin" -> {
                currentSpeakerUserId = userId
                activeSpeakerName = userName
                resetSpeakerTimeout()
                ensurePlaybackReady()
            }
            "end" -> {
                if (currentSpeakerUserId == userId) {
                    currentSpeakerUserId = null
                    activeSpeakerName = null
                    speakerTimeoutJob?.cancel()
                    speakerTimeoutJob = null
                }
            }
            else -> { // "chunk"
                if (currentSpeakerUserId == null || currentSpeakerUserId == userId) {
                    currentSpeakerUserId = userId
                    activeSpeakerName = userName
                    resetSpeakerTimeout()
                }
                if (!isMuted && audioBase64.isNotEmpty()) {
                    val bytes = runCatching { Base64.decode(audioBase64, Base64.DEFAULT) }.getOrNull()
                    if (bytes != null && bytes.isNotEmpty()) {
                        playPcmChunk(bytes)
                    }
                }
            }
        }
    }

    private fun resetSpeakerTimeout() {
        speakerTimeoutJob?.cancel()
        speakerTimeoutJob = scope.launch {
            kotlinx.coroutines.delay(1500)
            currentSpeakerUserId = null
            activeSpeakerName = null
        }
    }

    private fun ensurePlaybackReady() {
        if (audioTrack != null && audioTrack?.state == AudioTrack.STATE_INITIALIZED) return

        val minBuf = AudioTrack.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        val bufSize = maxOf(minBuf * 2, FRAME_BYTES * 4)

        val track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(SAMPLE_RATE)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(bufSize)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
            .build()

        if (track.state == AudioTrack.STATE_INITIALIZED) {
            track.play()
            track.setVolume(if (isMuted) 0f else 1f)
            audioTrack = track
        }
    }

    private fun playPcmChunk(bytes: ByteArray) {
        ensurePlaybackReady()
        val track = audioTrack ?: return
        if (track.playState != AudioTrack.PLAYSTATE_PLAYING) {
            track.play()
        }
        track.write(bytes, 0, bytes.size, AudioTrack.WRITE_NON_BLOCKING)
    }

    fun reset() {
        stopTalking()
        speakerTimeoutJob?.cancel()
        speakerTimeoutJob = null
        currentSpeakerUserId = null
        activeSpeakerName = null

        runCatching {
            audioTrack?.stop()
            audioTrack?.release()
        }
        audioTrack = null
    }
}
