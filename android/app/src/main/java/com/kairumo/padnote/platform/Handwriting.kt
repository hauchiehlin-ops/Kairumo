package com.kairumo.padnote.platform

import com.google.mlkit.common.MlKitException
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.common.model.RemoteModelManager
import com.google.mlkit.vision.digitalink.DigitalInkRecognition
import com.google.mlkit.vision.digitalink.DigitalInkRecognitionModel
import com.google.mlkit.vision.digitalink.DigitalInkRecognitionModelIdentifier
import com.google.mlkit.vision.digitalink.Ink
import kotlinx.coroutines.tasks.await
import uniffi.padnote_core.StrokePoint

/**
 * 手寫辨識（工作包 WP7）。
 *
 * # 為什麼可以用 ML Kit
 *
 * 架構決策 D2 原則上不引入需要 Google 服務的相依，但手寫辨識是已接受的例外
 * —— 裝置端沒有同等品質的替代方案。代價是**沒有 Google Play 服務的裝置
 * 用不了**，那種情況要明確講出來，不能靜默失敗：使用者會以為是自己的字太醜。
 *
 * # 辨識結果只進索引，不改筆跡
 *
 * 辨識出來的文字寫進核心的搜尋索引（`index_handwriting`），**不會**取代或
 * 修改任何一筆畫。手寫筆記的價值就在那個手寫，辨識只是讓它搜得到。
 */
object Handwriting {

    /** 一組要一起送去辨識的筆畫（大致對應一個詞或一行）。 */
    data class Group(val strokeIds: List<String>, val strokes: List<List<StrokePoint>>)

    /**
     * 書寫停頓多久算換一個詞。
     *
     * 逐筆辨識的話中文會整個垮掉（一個字往往是好幾筆）；整頁一次送則會把
     * 相隔很遠的內容硬湊成一句。用停頓切是最接近人怎麼寫字的切法。
     * 700ms 是起點值，需要實機以真實書寫節奏調整。
     */
    const val GROUP_GAP_MS: Long = 700

    /**
     * 依書寫停頓把筆畫分組。
     *
     * `strokeTimesMs` 是每一筆的落筆時刻（毫秒），與 `strokeIds`／`strokes`
     * 一一對應。
     */
    fun group(
        strokeIds: List<String>,
        strokes: List<List<StrokePoint>>,
        strokeTimesMs: List<Long>
    ): List<Group> {
        require(strokeIds.size == strokes.size && strokes.size == strokeTimesMs.size) {
            "三個清單的長度必須一致"
        }
        if (strokeIds.isEmpty()) return emptyList()

        val out = mutableListOf<Group>()
        var ids = mutableListOf(strokeIds[0])
        var pts = mutableListOf(strokes[0])

        for (i in 1 until strokeIds.size) {
            // 上一筆**結束**到這一筆開始之間的停頓，才是使用者感受到的那個停頓。
            val previousEnd = strokeTimesMs[i - 1] + durationMs(strokes[i - 1])
            if (strokeTimesMs[i] - previousEnd > GROUP_GAP_MS) {
                out += Group(ids, pts)
                ids = mutableListOf()
                pts = mutableListOf()
            }
            ids.add(strokeIds[i])
            pts.add(strokes[i])
        }
        if (ids.isNotEmpty()) out += Group(ids, pts)
        return out
    }

    private fun durationMs(points: List<StrokePoint>): Long =
        points.sumOf { it.dtUs.toLong() } / 1_000

    /** 把核心的取樣點轉成 ML Kit 的 `Ink`。 */
    fun buildInk(strokes: List<List<StrokePoint>>): Ink {
        val builder = Ink.builder()
        for (points in strokes) {
            val stroke = Ink.Stroke.builder()
            var tMs = 0L
            for (p in points) {
                tMs += p.dtUs.toLong() / 1_000
                // ML Kit 要的是時間戳而不是間隔；用累加值即可，
                // 它只看相對關係。
                stroke.addPoint(Ink.Point.create(p.x, p.y, tMs))
            }
            builder.addStroke(stroke.build())
        }
        return builder.build()
    }

    /** 辨識失敗的原因。逐項分開 —— 「辨識失敗」四個字幫不了使用者。 */
    sealed class Failure {
        /** 裝置沒有 Google Play 服務，或版本太舊。 */
        data class Unsupported(val detail: String) : Failure()
        /** 這個語言沒有對應的模型。 */
        data class NoModel(val languageTag: String) : Failure()
        /** 模型下載失敗（多半是沒有網路）。 */
        data class DownloadFailed(val detail: String) : Failure()
        data class RecognitionFailed(val detail: String) : Failure()
    }

    /** 語言標籤 → ML Kit 的模型識別碼。查無對應時回傳 `null`。 */
    fun modelIdentifier(languageTag: String): DigitalInkRecognitionModelIdentifier? = try {
        DigitalInkRecognitionModelIdentifier.fromLanguageTag(languageTag)
    } catch (t: Throwable) {
        null
    }

    /**
     * 確保模型已下載。
     *
     * 只在有 Wi-Fi 時下載：手寫模型有數 MB，用行動網路默默下載不是我們該替
     * 使用者做的決定。
     */
    suspend fun ensureModel(languageTag: String): Failure? {
        val identifier = modelIdentifier(languageTag) ?: return Failure.NoModel(languageTag)
        val model = DigitalInkRecognitionModel.builder(identifier).build()
        val manager = RemoteModelManager.getInstance()
        return try {
            if (manager.isModelDownloaded(model).await()) return null
            manager.download(model, DownloadConditions.Builder().requireWifi().build()).await()
            null
        } catch (e: MlKitException) {
            Failure.Unsupported(e.message ?: e.toString())
        } catch (t: Throwable) {
            Failure.DownloadFailed(t.message ?: t.toString())
        }
    }

    /** 辨識一組筆畫，回傳最佳候選字串。 */
    suspend fun recognize(
        strokes: List<List<StrokePoint>>,
        languageTag: String
    ): Result<String> {
        if (strokes.isEmpty()) return Result.success("")
        ensureModel(languageTag)?.let { return Result.failure(HandwritingError(it)) }

        val identifier = modelIdentifier(languageTag)
            ?: return Result.failure(HandwritingError(Failure.NoModel(languageTag)))
        val model = DigitalInkRecognitionModel.builder(identifier).build()
        val recognizer = DigitalInkRecognition.getClient(
            com.google.mlkit.vision.digitalink.DigitalInkRecognizerOptions.builder(model).build()
        )
        return try {
            // 不帶 RecognitionContext：它的 builder 需要 preContext 與書寫區域，
            // 空的建出來會在辨識時丟「Missing required properties: preContext」。
            // 我們也沒有前文可給 —— 這是一整頁手寫，不是輸入法的接續輸入。
            val result = recognizer.recognize(buildInk(strokes)).await()
            Result.success(result.candidates.firstOrNull()?.text.orEmpty())
        } catch (t: Throwable) {
            Result.failure(HandwritingError(Failure.RecognitionFailed(t.message ?: t.toString())))
        } finally {
            recognizer.close()
        }
    }

    class HandwritingError(val failure: Failure) : Exception(describe(failure))

    /** 給使用者看的一句話。 */
    fun describe(failure: Failure): String = when (failure) {
        is Failure.Unsupported ->
            "這台裝置無法使用手寫辨識（需要 Google Play 服務）：${failure.detail}"
        is Failure.NoModel -> "沒有「${failure.languageTag}」的手寫模型"
        is Failure.DownloadFailed -> "手寫模型下載失敗（請連上 Wi-Fi）：${failure.detail}"
        is Failure.RecognitionFailed -> "辨識失敗：${failure.detail}"
    }
}
