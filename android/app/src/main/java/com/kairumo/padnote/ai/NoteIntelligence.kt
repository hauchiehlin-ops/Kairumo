package com.kairumo.padnote.ai

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
 * Android 沒有對等的東西。能走的兩條路都有明確的代價：
 *
 * | 選項 | 代價 |
 * |---|---|
 * | `com.google.ai.edge.aicore`（Gemini Nano）| 實驗版（0.0.1-exp01），而且會帶進 Guava 與 play-services-basement。為一個只在少數機型上跑得動的功能，讓**每個**使用者多背好幾 MB |
 * | 把 llama.cpp 連進來 + 下載 2.4 GB 模型 | APK 變大，而且要使用者下載一個比整個 App 大幾十倍的檔案 |
 *
 * 兩條都違反這個專案已經做過兩次的同一個判斷（reqwest 不進核心、
 * llama.cpp 不進核心）：**平台裝得下不代表使用者該下載它。**
 *
 * 所以這一側現在回報「這台裝置上沒有可用的模型」，而那正是
 * `FfiLlmError.ModelNotLoaded` 存在的理由 —— 核心用它區分「要引導使用者
 * 去處理」與「只能請他重試」。誠實地說沒有，比丟一個「摘要失敗，請重試」
 * 讓使用者按一百次好。
 *
 * 要補上後端時，改的只有 [backend] 這一個函式；畫面與流程都不用動。
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

    /**
     * 目前的可用狀態。
     *
     * 接上裝置端後端時，這裡要改成真的去問它 —— 而不是無條件回
     * [Availability.AVAILABLE]，那會讓使用者按下去才看到失敗。
     */
    fun availability(): Availability = Availability.UNSUPPORTED

    /**
     * 產生文字的後端。
     *
     * 目前一律丟 [FfiLlmException.ModelNotLoaded] —— 見類別說明。
     * **這不是 TODO 樁**：它回報的是這台裝置真實的狀態，核心與畫面都會
     * 照著它做出正確的行為。
     */
    fun backend(): FfiLlm = object : FfiLlm {
        override fun generate(prompt: String, maxTokens: UInt): String {
            throw FfiLlmException.ModelNotLoaded()
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
    fun summarize(text: String, locale: String): FfiSummaryResult =
        llmSummarize(backend(), text, locale, 400u)

    /**
     * 跑一次待辦抽取。
     *
     * **沒有待辦是正常的答案**，`ok` 仍然是 true、清單是空的。當成錯誤的話，
     * 使用者每次對一段沒有待辦的筆記按下去都會看到紅字。
     */
    fun extractTodos(text: String, locale: String): FfiTodoResult =
        llmExtractTodos(backend(), text, locale, 400u)
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
