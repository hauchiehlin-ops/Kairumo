package com.kairumo.padnote

/**
 * 非畫面程式（同步、錄音）組使用者看得到的訊息時用的查表與格式化。
 *
 * 畫面程式用 `l10n(...)`；背景工作拿不到那個 Composable 的語言標籤，所以這裡直接讀目前語言。
 * **訊息一律走這裡，不要在程式裡寫死任何語言的字** —— 切換語言之後，其他語言的使用者看到的
 * 就是那一句寫死的話。對應 Apple 的 `L10n`。
 */
object L10n {
    fun t(key: String): String = LocalizationStrings.localized(key, currentLanguageTag())

    /** `%1@`、`%2@`… 依編號取代；沒有編號的 `%@` 依序取代。 */
    fun f(key: String, vararg args: Any?): String {
        var text = t(key)
        args.forEachIndexed { index, value ->
            val numbered = "%${index + 1}@"
            text = if (text.contains(numbered)) text.replace(numbered, "$value")
            else text.replaceFirst("%@", "$value")
        }
        return text
    }

    /**
     * 核心（Rust）的錯誤訊息是**中文**（開發語言）。使用者看到的語言由介面決定，所以在這個「介面邊界」依
     * [CoreMessagePatterns]（產生自 `i18n/core-patterns.json`）比對訊息、換成使用者語系的句子；
     * 動態的部分（檔名、數字、內層錯誤）原樣帶進去，內層若又是核心訊息就遞迴翻譯。
     * 繁體中文原樣；其他語言比得到就翻，整句比不到而且含漢字才退成通用訊息。
     * 只用在「確定是核心產生的字串」上 —— Kotlin 這邊組的訊息本來就已在地化，不要經過這裡（日文也有漢字）。
     * 對應 Apple 的 `L10n.coreText`。
     */
    fun coreText(message: String): String {
        val tag = currentLanguageTag()
        if (tag == "zh-Hant" || tag == "zh-TW" || tag == "zh-HK") return message
        translateCore(message, tag)?.let { return it }
        if (tag.startsWith("zh")) return message
        val hasCjk = message.any { it.code in 0x3400..0x9FFF }
        return if (hasCjk) t("error_generic") else message
    }

    /** 同步日誌的一行：依樣式翻成目前語言，比不到就原樣（日誌是給人看狀況的，不像錯誤訊息要退成通用句）。 */
    fun logText(message: String): String {
        val tag = currentLanguageTag()
        if (tag == "zh-Hant" || tag == "zh-TW" || tag == "zh-HK") return message
        return translateCore(message, tag) ?: message
    }

    private val corePatterns: List<Pair<String, Regex>> by lazy {
        CoreMessagePatterns.all.map { (key, parts) ->
            key to Regex("^" + parts.joinToString("(.*?)") { Regex.escape(it) } + "$", RegexOption.DOT_MATCHES_ALL)
        }
    }

    private fun translateCore(message: String, tag: String): String? {
        val text = message.replace(Regex("\\s+"), " ").trim()
        for ((key, regex) in corePatterns) {
            val match = regex.matchEntire(text) ?: continue
            var out = LocalizationStrings.localized(key, tag)
            match.groupValues.drop(1).forEachIndexed { i, value ->
                out = out.replace("%${i + 1}@", translateFragment(value, tag))
            }
            return out
        }
        return null
    }

    /** 動態片段：本身可能又是核心訊息，或是一串用「、」連起來的名稱（例如「需要：麥克風、手寫辨識」）。 */
    private fun translateFragment(fragment: String, tag: String): String {
        translateCore(fragment, tag)?.let { return it }
        if (fragment.contains("、")) {
            val separator = if (tag.startsWith("ja") || tag.startsWith("zh")) "、" else ", "
            return fragment.split("、").joinToString(separator) { translateCore(it, tag) ?: it }
        }
        return fragment
    }

    /** 使用者看得到的錯誤文字：核心的例外（UniFFI 產生的 `Ffi*Exception`）走 [coreText]，其餘原樣。 */
    fun errorText(error: Throwable): String {
        val raw = error.message ?: error.toString()
        return if (error.javaClass.simpleName.startsWith("Ffi")) coreText(raw) else raw
    }
}

/**
 * 同步訊息的「這是錯誤」標記（對應 Apple 的 `SyncText`）。
 * 畫面依訊息決定顯示紅色與否；原本是找「失敗」「錯誤」這些中文詞，翻成別的語言就不會變紅了。
 */
object SyncText {
    const val ERROR_MARK = "⚠️ "

    fun error(message: String): String = if (message.startsWith(ERROR_MARK)) message else ERROR_MARK + message

    fun isError(message: String?): Boolean = message?.startsWith(ERROR_MARK) == true
}
