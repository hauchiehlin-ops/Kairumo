package com.kairumo.padnote.ai

import android.content.Context
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import java.io.File
import uniffi.padnote_core.FfiLlm
import uniffi.padnote_core.FfiLlmException
import uniffi.padnote_core.FfiSummaryResult
import uniffi.padnote_core.FfiTodoResult
import uniffi.padnote_core.llmExtractTodos
import uniffi.padnote_core.llmSummarize

/**
 * 摘要與待辦抽取（工作項 S-20 收尾）。
 *
 * # 在這之前的狀態
 *
 * 核心的 `llm_summarize` / `llm_extract_todos` 早就在 FFI 上，切塊、提示詞、
 * **解析**都做完了（`padnote-llm`，18 項測試）。缺的只有一件事：
 * **沒有任何畫面呼叫它們**。功能做完了，使用者按不到。
 *
 * # 這一側目前沒有裝置端後端 —— 為什麼，以及為什麼不硬塞一個
 *
 * 核心只定義介面（[FfiLlm]），產生文字的後端由平台提供。Apple 那一側用
 * 系統內建的語言模型：不必下載、不會讓 App 變大、文字不離開裝置。
 *
 * Android 沒有對等的東西。三條路的代價不一樣：
 *
 * | 選項 | 代價 |
 * |---|---|
 * | `com.google.ai.edge.aicore`（Gemini Nano）| 實驗版（0.0.1-exp01），而且會帶進 Guava 與 play-services-basement。為一個只在少數機型上跑得動的功能，讓**每個**使用者多背好幾 MB |
 * | 把 llama.cpp 連進來 + 下載 2.4 GB 模型 | APK 變大，而且要使用者下載一個比整個 App 大幾十倍的檔案 |
 * | **MediaPipe `tasks-genai`**（採用） | 原生庫約 12 MB／ABI，但**模型完全不隨 App 出貨** |
 *
 * 選了第三條。關鍵差別在「誰下載什麼」：前兩條是**每個**使用者都要背，
 * 不管他用不用得到摘要；MediaPipe 只有那 12 MB 是全體共擔，而真正大的
 * 東西（模型）只有想用的人才放。這與專案前兩次的判斷（reqwest 不進核心、
 * llama.cpp 不進核心）是同一條線 —— **平台裝得下不代表使用者該下載它**，
 * 而這次要全體下載的只有函式庫本身。
 *
 * 同時把 `abiFilters` 收成 arm64-v8a 與 x86_64：第三方 AAR 會帶進
 * armeabi-v7a 與 x86 的原生庫，而那兩個 ABI 上根本沒有 `libpadnote_core.so`，
 * App 一啟動就會死在 `UnsatisfiedLinkError`。收掉之後，APK 反而比加
 * MediaPipe 之前更小。
 *
 * # 模型不在的時候
 *
 * 回 [FfiLlmException.ModelNotLoaded]，不是後端錯誤。核心用它區分
 * 「要引導使用者去處理」與「只能請他重試」—— 誠實地說沒有，比丟一個
 * 「摘要失敗，請重試」讓使用者按一百次好。
 */
object NoteIntelligence {

    /** 這台裝置能不能做摘要。 */
    enum class Availability {
        AVAILABLE,

        /** 這台裝置或這個系統版本沒有可用的模型。 */
        UNSUPPORTED,

        /** 有模型但現在不能用（還在下載、或被關掉了）。 */
        NOT_READY,
    }

    /** App 私有目錄裡的模型路徑。 */
    private const val MODEL_RELATIVE_PATH = "llm/model.task"

    /**
     * 模型檔，不存在時回 null。
     *
     * **每次都重看一次檔案，不要快取**：使用者可能在 App 開著的時候才把
     * 模型放進去。快取的話，他照做之後回到 App 仍然看到「沒有可用的模型」。
     */
    private fun modelFile(context: Context): File? =
        File(context.filesDir, MODEL_RELATIVE_PATH).takeIf { it.isFile && it.length() > 0 }

    /**
     * 目前的可用狀態。
     *
     * 問的是檔案系統，不是猜的 —— 無條件回 [Availability.AVAILABLE] 會讓
     * 使用者按下去才看到失敗。模型放進去之後**不必重開 App**就會變成可用。
     */
    fun availability(context: Context): Availability =
        if (modelFile(context) != null) Availability.AVAILABLE else Availability.UNSUPPORTED

    /**
     * 產生文字的後端。
     *
     * 模型檔不在時丟 [FfiLlmException.ModelNotLoaded]（見類別說明）。
     */
    fun backend(context: Context): FfiLlm = object : FfiLlm {
        override fun generate(prompt: String, maxTokens: UInt): String {
            val model = modelFile(context) ?: throw FfiLlmException.ModelNotLoaded()

            // 每次生成開一個新的 engine 再關掉。
            //
            // 留著重用會省下載入時間，但 `LlmInference` 抓著好幾百 MB 的原生
            // 記憶體不放，而使用者按一次摘要之後通常就回去寫字了 ——
            // 手寫才是這個 App 的主線，不能為了偶爾一次的摘要一直壓著記憶體。
            return try {
                LlmInference.createFromOptions(
                    context,
                    LlmInference.LlmInferenceOptions.builder()
                        .setModelPath(model.absolutePath)
                        .setMaxTokens(maxTokens.toInt())
                        .build()
                ).use { engine -> engine.generateResponse(prompt) ?: "" }
            } catch (t: Throwable) {
                // 載入或推論失敗是「後端壞了」，不是「沒有模型」——
                // 混成一種的話，一個壞掉的模型檔會讓畫面說「這台裝置不支援」，
                // 而使用者永遠不會想到去換那個檔案。
                throw FfiLlmException.Backend(t.message ?: "llm_backend_error")
            }
        }
    }

    /**
     * 跑一次摘要。
     *
     * **這個呼叫會同步等模型跑完，不要在主執行緒上叫。**
     * 核心那邊刻意設計成同步（解析那一段要逐次跑），呼叫端負責丟去背景。
     *
     * @param locale BCP-47。**一定要給** —— 不指定輸出語言的話，模型會跟著
     *   輸入走，而一份中英夾雜的會議記錄會拿到一半中文、一半英文的摘要。
     */
    fun summarize(context: Context, text: String, locale: String): FfiSummaryResult =
        llmSummarize(backend(context), text, locale, 400u)

    /**
     * 跑一次待辦抽取。
     *
     * **沒有待辦是正常的答案**，`ok` 仍然是 true、清單是空的。當成錯誤的話，
     * 使用者每次對一段沒有待辦的筆記按下去都會看到紅字。
     */
    fun extractTodos(context: Context, text: String, locale: String): FfiTodoResult =
        llmExtractTodos(backend(context), text, locale, 400u)
}

/**
 * 把一則筆記攤成純文字（工作項 S-20）。
 *
 * # 為什麼來源要與搜尋一致
 *
 * 這裡取的內容與首頁搜尋比對的**完全一樣**。不一致的話會出現一個很難解釋
 * 的狀況：使用者搜得到某句話，但摘要說筆記裡沒有提到它。
 *
 * # 為什麼不是直接餵 markdown 匯出
 *
 * 匯出的 markdown 帶著版面：頁碼、圖片佔位、表格的管線符號。那些對模型是
 * 雜訊 —— 一份滿是 `| --- | --- |` 的輸入，摘要會開始講表格的欄位。
 *
 * Apple 端是同一份規則（見 `NotebookPlainText.swift`）。同一則筆記在兩台
 * 裝置上要餵進一樣的文字，否則摘要會不一樣，而使用者會以為其中一台壞了。
 *
 * 空白與只有空格的段落會被丟掉 —— 模型會把一整排空行當成章節分隔，
 * 然後為每一段「章節」各寫一句摘要。
 */
fun notePlainText(
    title: String,
    /** 手寫辨識的結果。**排過再傳** —— 順序不穩的話，同一則筆記每次跑出來的摘要都不一樣。 */
    recognized: List<String> = emptyList(),
    textBoxes: List<String> = emptyList(),
    /** 表格逐格。一張表接成一段，格與格之間換行 —— 接成一長串的話，
     *  「姓名 王小明 電話」會被讀成一句話。 */
    tableCells: List<String> = emptyList(),
    shapeLabels: List<String> = emptyList()
): String {
    val parts = mutableListOf<String>()
    parts += title
    // 手寫辨識放在打字內容前面：手寫多半是主體，而文字方塊常常只是標註。
    parts += recognized
    parts += textBoxes
    if (tableCells.isNotEmpty()) parts += tableCells.joinToString("\n")
    parts += shapeLabels

    return parts
        .map { it.trim() }
        .filter { it.isNotEmpty() }
        .joinToString("\n\n")
}
