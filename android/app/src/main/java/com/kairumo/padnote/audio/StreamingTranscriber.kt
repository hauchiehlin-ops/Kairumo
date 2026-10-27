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
import uniffi.padnote_core.transcriptOutputLanguage
import uniffi.padnote_core.whisperIsModelAvailable
import uniffi.padnote_core.whisperTranscribePcmWith

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
        // 錄音開始時決定一次，錄到一半改設定不影響這一段。
        val options = AudioTranscriber.liveOptions(context)
        val source = languageTag ?: AudioTranscriber.sourceLanguageTag(context)
        val output = transcriptOutputLanguage(source, AudioTranscriber.outputLanguagePreference(context))

        job = scope.launch {
            while (isActive) {
                delay(1000)
                val segments = runCatching { session.takePendingSegments() }.getOrNull() ?: continue
                if (segments.isEmpty()) continue

                for (seg in segments) {
                    try {
                        val result = whisperTranscribePcmWith(modelPath, seg.samples, source, options)
                        if (result.segments.isNotEmpty()) {
                            // 同語言：只轉字體；不同語言：逐句翻譯（失敗時保留原文，轉錄不中斷）。
                            val texts = TranscriptTranslator.finalize(
                                result.segments.map { it.text }, source, output
                            ).texts
                            val inputs = result.segments.zip(texts).map { (w, text) ->
                                TranscriptWordInput(
                                    text = text,
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
