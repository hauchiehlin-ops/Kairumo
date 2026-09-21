package com.kairumo.padnote.audio

import android.content.Context
import com.kairumo.padnote.models.ModelDownloadManager
import java.io.File
import uniffi.padnote_core.whisperIsModelAvailable
import uniffi.padnote_core.whisperTranscribePcm

/**
 * 語音轉錄（Android）。
 *
 * # 這個檔案之前是假的
 *
 * 舊版的 `transcribe()` **沒有做任何語音辨識**：它組一段標頭（標題、長度、
 * 日期）再把**檔名**當成內容回傳，而呼叫端顯示「轉錄成功」。
 *
 * 那比缺功能更傷：使用者會以為轉錄壞了（結果莫名其妙是檔名），
 * 而不是以為這個功能還沒有 —— 前者會讓他不信任整個 App。
 *
 * # 現在走的路
 *
 * 與 Apple 同一條：解碼成 16 kHz 單聲道 PCM → 核心的 `whisperTranscribePcm`。
 * 拿不到結果時**明確回報為什麼**，由呼叫端顯示，不再產生任何假文字。
 *
 * 三種拿不到的原因，而且要分得開：
 *
 * | 狀況 | 使用者該做什麼 |
 * |---|---|
 * | 這個版本沒有編進 Whisper 引擎 | 什麼也做不了（見 [Outcome.EngineUnavailable]） |
 * | 引擎有、但模型還沒下載 | 去設定裡下載 |
 * | 音檔解不開 | 換一個檔案 |
 *
 * 混成一種「轉錄失敗」的話，使用者會一直按重試，而其中兩種重試一百次也一樣。
 */
object AudioTranscriber {

    /** 轉錄的結果。**沒有「假成功」這個選項。** */
    sealed interface Outcome {
        data class Text(val value: String) : Outcome

        /** 這個版本沒有把 Whisper 編進來（見 `padnote-core` 的 `asr-whisper` feature）。 */
        data object EngineUnavailable : Outcome

        /** 引擎有，但模型還沒下載。 */
        data object ModelMissing : Outcome

        /** 音檔解不開或太長。 */
        data object AudioUnreadable : Outcome

        /** 模型與音檔都沒問題，但這段錄音裡沒有偵測到語音。 */
        data object NoSpeech : Outcome

        data class Failed(val detail: String) : Outcome
    }

    fun isModelAvailable(context: Context): Boolean =
        whisperIsModelAvailable(ModelDownloadManager.modelPath(context, WHISPER_MODEL_ID))

    /** 核心清單裡的 id。與 `models/manifest.json` 一致。 */
    const val WHISPER_MODEL_ID = "whisper-large-v3-turbo-q5"

    /**
     * 轉錄一段錄音。**會阻塞（解碼 + 推論），要在背景執行緒呼叫。**
     *
     * @param languageTag BCP-47；null 表示讓模型自己偵測。
     */
    fun transcribe(context: Context, audioFile: File, languageTag: String? = null): Outcome {
        val modelPath = ModelDownloadManager.modelPath(context, WHISPER_MODEL_ID)
        if (!whisperIsModelAvailable(modelPath)) {
            return Outcome.ModelMissing
        }
        val pcm = AudioPcmDecoder.decodeTo16kMono(audioFile) ?: return Outcome.AudioUnreadable
        if (pcm.isEmpty()) return Outcome.AudioUnreadable

        return try {
            val result = whisperTranscribePcm(modelPath, pcm.toList(), languageTag)
            val text = result.text.trim()
            if (text.isEmpty()) Outcome.NoSpeech else Outcome.Text(text)
        } catch (t: Throwable) {
            val message = t.message ?: ""
            // 核心在沒有編進引擎時回的就是這句 —— 分出來才能給對的提示。
            if (message.contains("未啟用")) {
                Outcome.EngineUnavailable
            } else {
                Outcome.Failed(message)
            }
        }
    }
}
