package com.kairumo.padnote.audio

import android.content.Context
import com.kairumo.padnote.models.ModelDownloadManager
import com.kairumo.padnote.profile.ProfileContext
import com.kairumo.padnote.deviceLanguageTag
import java.io.File
import kotlinx.coroutines.runBlocking
import uniffi.padnote_core.FfiTranscribeOptions
import uniffi.padnote_core.defaultTranscribeOptions
import uniffi.padnote_core.liveTranscribeOptions
import uniffi.padnote_core.transcriptOutputLanguage
import uniffi.padnote_core.whisperIsModelAvailable
import uniffi.padnote_core.whisperTranscribePcmWith

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
        /** [translationError] 有值時翻譯沒成功，[value] 是原文（見 [TranscriptTranslator]）。 */
        data class Text(val value: String, val translationError: String? = null) : Outcome

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

    /** 核心清單裡的 id。與 `models/manifest.json` 一致。 */
    const val WHISPER_MODEL_ID = "whisper-large-v3-turbo-q5"

    /** 與 Apple 的 `kairumo_asr_denoise` 同名。 */
    private const val DENOISE_PREF_KEY = "kairumo_asr_denoise"

    /**
     * 辨識前先用 RNNoise 降噪（只影響 Whisper；錄音檔永遠是原音）。
     * 預設關：降噪常讓 Whisper 錯字變多（見 `padnote-denoise`），只適合真的很吵的場合。
     */
    fun isDenoiseEnabled(context: Context): Boolean =
        ProfileContext.prefs(context, "kairumo").getBoolean(DENOISE_PREF_KEY, false)

    fun setDenoiseEnabled(context: Context, enabled: Boolean) {
        ProfileContext.prefs(context, "kairumo").edit().putBoolean(DENOISE_PREF_KEY, enabled).apply()
    }

    private const val SOURCE_LANGUAGE_KEY = "kairumo_asr_source_language"
    private const val OUTPUT_LANGUAGE_KEY = "kairumo_asr_output_language"

    /** 與 Apple 的語言清單一致（介面支援的六種）。 */
    val transcriptLanguages = listOf("zh-Hant", "zh-Hans", "en", "ja", "ko", "th")

    /** 音訊語言設定。空字串＝跟隨介面語言。鍵名與 Apple 相同。 */
    fun sourceLanguagePreference(context: Context): String =
        ProfileContext.prefs(context, "kairumo").getString(SOURCE_LANGUAGE_KEY, "") ?: ""

    fun setSourceLanguagePreference(context: Context, tag: String) {
        ProfileContext.prefs(context, "kairumo").edit().putString(SOURCE_LANGUAGE_KEY, tag).apply()
    }

    /** 轉出文字語言設定。空字串＝與音訊相同（不翻譯，沿用原本的轉錄）。 */
    fun outputLanguagePreference(context: Context): String =
        ProfileContext.prefs(context, "kairumo").getString(OUTPUT_LANGUAGE_KEY, "") ?: ""

    fun setOutputLanguagePreference(context: Context, tag: String) {
        ProfileContext.prefs(context, "kairumo").edit().putString(OUTPUT_LANGUAGE_KEY, tag).apply()
    }

    /** 實際的音訊語言標籤。 */
    fun sourceLanguageTag(context: Context): String =
        sourceLanguagePreference(context).ifEmpty { deviceLanguageTag() }

    /** 錄完之後整段轉錄：核心的預設（高通 + VAD 切段 + AGC）加上降噪設定。 */
    fun fileOptions(context: Context): FfiTranscribeOptions =
        defaultTranscribeOptions().copy(denoise = isDenoiseEnabled(context))

    /** 錄音中一段段轉錄：錄音管線已做過高通與 AGC（見核心 `live_transcribe_options`）。 */
    fun liveOptions(context: Context): FfiTranscribeOptions =
        liveTranscribeOptions().copy(denoise = isDenoiseEnabled(context))

    /**
     * 轉錄一段錄音。**會阻塞（解碼 + 推論），要在背景執行緒呼叫。**
     *
     * @param languageTag BCP-47；null 表示讓模型自己偵測。
     */
    /**
     * @param languageTag 要辨識的語言；null = 用設定裡的音訊語言，設定是「跟隨介面語言」時
     *   由 Whisper 自動偵測（Apple「自動偵測」同義）。
     *
     * 轉出的文字是「轉出文字語言」：與音訊相同時只轉繁／簡字體，不同時再翻譯。
     */
    fun transcribe(context: Context, audioFile: File, languageTag: String? = null): Outcome {
        val recognitionTag = languageTag ?: sourceLanguagePreference(context).ifEmpty { null }
        val source = recognitionTag ?: sourceLanguageTag(context)
        val output = transcriptOutputLanguage(source, outputLanguagePreference(context))
        val modelPath = ModelDownloadManager.modelPath(context, WHISPER_MODEL_ID)
        if (!whisperIsModelAvailable(modelPath)) {
            return Outcome.ModelMissing
        }
        val pcm = AudioPcmDecoder.decodeTo16kMono(audioFile) ?: return Outcome.AudioUnreadable
        if (pcm.isEmpty()) return Outcome.AudioUnreadable

        return try {
            val result = whisperTranscribePcmWith(modelPath, pcm.toList(), recognitionTag, fileOptions(context))
            val raw = result.text.trim()
            if (raw.isEmpty()) return Outcome.NoSpeech
            // 字體／翻譯規則在核心與 TranscriptTranslator，與 Apple 同一份。已在背景執行緒，可以等。
            val final = runBlocking { TranscriptTranslator.finalize(listOf(raw), source, output) }
            Outcome.Text(final.texts.first(), final.error)
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
