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
     * 核心（Rust）的錯誤訊息是**中文**（開發語言）。其他語言的使用者看到一串看不懂的中文沒有任何幫助，
     * 所以非中文介面改顯示通用訊息。只用在「確定是核心產生的字串」上 ——
     * Kotlin 這邊組的訊息本來就已在地化，不要經過這裡（日文也有漢字）。對應 Apple 的 `L10n.coreText`。
     */
    fun coreText(message: String): String {
        if (currentLanguageTag().startsWith("zh")) return message
        val hasCjk = message.any { it.code in 0x3400..0x9FFF }
        return if (hasCjk) t("error_generic") else message
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
