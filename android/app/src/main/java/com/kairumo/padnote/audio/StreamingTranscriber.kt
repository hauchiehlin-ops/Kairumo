package com.kairumo.padnote.audio

import android.content.Context
import com.kairumo.padnote.models.ModelDownloadManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import uniffi.padnote_core.PadnoteSession
import uniffi.padnote_core.TranscriptWordInput
import uniffi.padnote_core.whisperIsModelAvailable
import uniffi.padnote_core.whisperTranscribePcm

/**
 * 串流轉錄 Worker。
 * 定期從核心抓取 `takePendingSegments` 並送進 Whisper 進行語音辨識，
 * 最後呼叫 `addTranscript` 寫回筆記本。
 */
class StreamingTranscriber(private val context: Context, private val session: PadnoteSession) {
    private var job: Job? = null
    private val scope = CoroutineScope(Dispatchers.IO)
    
    fun start(pageId: String, languageTag: String?) {
        if (job?.isActive == true) return
        val modelPath = ModelDownloadManager.modelPath(context, AudioTranscriber.WHISPER_MODEL_ID)
        if (!whisperIsModelAvailable(modelPath)) return

        job = scope.launch {
            while (isActive) {
                delay(1000)
                val segments = runCatching { session.takePendingSegments() }.getOrNull() ?: continue
                if (segments.isEmpty()) continue

                for (seg in segments) {
                    try {
                        val result = whisperTranscribePcm(modelPath, seg.samples, languageTag)
                        if (result.segments.isNotEmpty()) {
                            val inputs = result.segments.map { w ->
                                TranscriptWordInput(
                                    text = w.text,
                                    // 偏移量：從這段音訊在筆記本的時間點開始加
                                    startUs = seg.sessionStartUs + seg.startUs + w.startMs * 1000u,
                                    endUs = seg.sessionStartUs + seg.startUs + w.endMs * 1000u,
                                    confidence = w.confidence
                                )
                            }
                            session.addTranscript(pageId, seg.sessionId, inputs)
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
            }
        }
    }

    fun stop() {
        job?.cancel()
        job = null
    }
}
