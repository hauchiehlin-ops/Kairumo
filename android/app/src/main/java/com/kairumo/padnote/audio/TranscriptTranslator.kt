package com.kairumo.padnote.audio

import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.common.model.RemoteModelManager
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.TranslateRemoteModel
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.Translator
import com.google.mlkit.nl.translate.TranslatorOptions
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.tasks.await
import uniffi.padnote_core.localizeTranscriptScript
import uniffi.padnote_core.transcriptNeedsTranslation
import uniffi.padnote_core.transcriptOutputLanguage

/**
 * 逐字稿的「轉出文字語言」處理（Android）。
 *
 * # 規則（核心決定，與 Apple 一樣）
 *
 * - 音訊語言與轉出語言的主語言相同（含 `zh-Hant` ↔ `zh-Hans`）：**不翻譯**，
 *   沿用原本的轉錄結果，只做簡繁字體轉換；
 * - 主語言不同：辨識完的每一句交給 ML Kit Translation。
 *
 * # 為什麼是 ML Kit
 *
 * 在裝置上執行、免費、不需要後台；與手寫辨識的 ML Kit Digital Ink 同屬決策 D2 已接受的例外。
 * 每個語言的模型約 30 MB，**只在使用者於設定裡按下載時才下載**（只用 Wi-Fi）——
 * 錄音中途才發現要下載的話，前幾分鐘的逐字稿會全部卡住。
 *
 * ML Kit 的中文只有一種（簡體）；譯成中文後再交給核心轉成使用者要的字體。
 */
// profile-scope: device 只快取 ML Kit 翻譯器（語言模型），不含任何使用者資料
object TranscriptTranslator {

    /** 翻譯結果。[error] 有值時 [texts] 是原文。 */
    data class Result(val texts: List<String>, val error: String?)

    private val mutex = Mutex()
    private var cachedPair: String = ""
    private var cached: Translator? = null

    /** App 的語言標籤（`zh-Hant`、`en`…）→ ML Kit 的語言；不支援時回 null。 */
    fun mlkitLanguage(tag: String): String? =
        TranslateLanguage.fromLanguageTag(tag.substringBefore('-').substringBefore('_').lowercase())

    /** 兩邊的語言模型是否都已下載。 */
    suspend fun isReady(source: String, target: String): Boolean {
        val models = listOf(mlkitLanguage(source), mlkitLanguage(target))
        if (models.any { it == null }) return false
        val manager = RemoteModelManager.getInstance()
        return models.all { lang ->
            runCatching {
                manager.isModelDownloaded(TranslateRemoteModel.Builder(lang!!).build()).await()
            }.getOrDefault(false)
        }
    }

    /** 下載這組語言的模型（只用 Wi-Fi）。失敗時丟例外。 */
    suspend fun download(source: String, target: String) {
        val translator = translator(source, target) ?: error("unsupported")
        translator.downloadModelIfNeeded(DownloadConditions.Builder().requireWifi().build()).await()
    }

    /**
     * 把辨識結果轉成轉出文字語言。
     *
     * **翻譯失敗時回傳原文**（再做字體轉換）與原因 —— 文字不能因為模型沒下載就整段消失，
     * 錄音中的即時轉錄也不能因此中斷。
     */
    suspend fun finalize(texts: List<String>, source: String, output: String): Result {
        val target = transcriptOutputLanguage(source, output)
        if (!transcriptNeedsTranslation(source, output)) {
            return Result(texts.map { localizeTranscriptScript(it, target) }, null)
        }
        val original = texts.map { localizeTranscriptScript(it, source) }
        if (!isReady(source, target)) {
            return Result(original, "model_missing")
        }
        return try {
            val translator = translator(source, target) ?: return Result(original, "unsupported")
            val out = texts.map { text ->
                if (text.isBlank()) text else translator.translate(text).await()
            }
            Result(out.map { localizeTranscriptScript(it, target) }, null)
        } catch (t: Throwable) {
            Result(original, t.message ?: t.javaClass.simpleName)
        }
    }

    /** 同一組語言重用同一個 Translator（建立時要載入模型）。換組時關掉舊的。 */
    private suspend fun translator(source: String, target: String): Translator? {
        val from = mlkitLanguage(source) ?: return null
        val to = mlkitLanguage(target) ?: return null
        val key = "$from→$to"
        return mutex.withLock {
            cached?.takeIf { cachedPair == key } ?: run {
                cached?.close()
                Translation.getClient(
                    TranslatorOptions.Builder().setSourceLanguage(from).setTargetLanguage(to).build()
                ).also {
                    cached = it
                    cachedPair = key
                }
            }
        }
    }
}
