package com.kairumo.padnote.hwr

import com.google.mlkit.vision.digitalink.DigitalInkRecognition
import com.google.mlkit.vision.digitalink.DigitalInkRecognitionModel
import com.google.mlkit.vision.digitalink.DigitalInkRecognitionModelIdentifier
import com.google.mlkit.vision.digitalink.DigitalInkRecognizer
import com.google.mlkit.vision.digitalink.DigitalInkRecognizerOptions
import com.google.mlkit.vision.digitalink.Ink
import com.google.mlkit.vision.digitalink.Stroke

class MlKitHwrEngine {
    private var recognizer: DigitalInkRecognizer? = null

    init {
        // 設定辨識模型為繁體中文 (zho-TW)
        val modelIdentifier = DigitalInkRecognitionModelIdentifier.fromLanguageTag("zh-TW")
        if (modelIdentifier != null) {
            val model = DigitalInkRecognitionModel.builder(modelIdentifier).build()
            
            // TODO: Ensure model is downloaded before initializing the recognizer
            
            recognizer = DigitalInkRecognition.getClient(
                DigitalInkRecognizerOptions.builder(model).build()
            )
        }
    }

    /**
     * 接收從 Rust (padnote-ink) 傳來的筆畫，轉換為 ML Kit 的格式並辨識
     */
    fun recognizeStrokes(rustStrokes: List<List<Pair<Float, Float>>>, onSuccess: (String) -> Unit, onError: (Exception) -> Unit) {
        val inkBuilder = Ink.builder()
        
        for (rustStroke in rustStrokes) {
            val strokeBuilder = Stroke.builder()
            for (point in rustStroke) {
                strokeBuilder.addPoint(com.google.mlkit.vision.digitalink.Ink.Point.create(point.first, point.second))
            }
            inkBuilder.addStroke(strokeBuilder.build())
        }

        val ink = inkBuilder.build()
        recognizer?.recognize(ink)
            ?.addOnSuccessListener { result ->
                // result.candidates contains the recognition hypotheses
                val bestMatch = result.candidates.firstOrNull()?.text ?: ""
                onSuccess(bestMatch)
            }
            ?.addOnFailureListener { e ->
                onError(e)
            }
    }
    
    fun close() {
        recognizer?.close()
    }
}
