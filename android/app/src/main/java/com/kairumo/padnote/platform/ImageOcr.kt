package com.kairumo.padnote.platform

import android.graphics.Bitmap
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.tasks.await

/**
 * 裝置端文字辨識 (OCR)。
 *
 * 供掃描翻譯筆等工具辨識圖片、匯入之 PDF 頁面或筆跡區域中的文字，
 * 對齊 Apple Vision Framework (`HandwritingRecognizer.recognizeForScanPen`)。
 */
object ImageOcr {

    suspend fun recognizeText(
        bitmap: Bitmap,
        languageTag: String = "en"
    ): Result<String> {
        val client = when {
            languageTag.startsWith("zh") ->
                TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
            languageTag.startsWith("ja") ->
                TextRecognition.getClient(JapaneseTextRecognizerOptions.Builder().build())
            languageTag.startsWith("ko") ->
                TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build())
            else ->
                TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        }
        return try {
            val image = InputImage.fromBitmap(bitmap, 0)
            val visionText = client.process(image).await()
            val text = visionText.text.trim()
            Result.success(text)
        } catch (t: Throwable) {
            Result.failure(t)
        } finally {
            runCatching { client.close() }
        }
    }
}
