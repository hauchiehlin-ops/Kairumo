package com.kairumo.padnote.library

import android.content.Context

/**
 * 最近套用過的樣板 id。
 *
 * # 為什麼需要它
 *
 * 39 種文件範本收在一棵三層的樹裡。實際上使用者絕大多數時候要的是
 * 「再來一份跟上次一樣的」—— 而那件事現在要展開主題、展開分類、再從
 * 清單裡認出那一個。清單本身沒有問題，問題是**最常用的路徑最長**。
 *
 * # 順序規則在核心
 *
 * 「去重、最近的在前、只留三個」看起來不值得共用，但它是會落盤的順序：
 * 兩端各寫一份的話，同一個人換平台打開時常用樣板的排法不一樣。
 * 見核心 `recent_templates_push`。與 Apple 的 `RecentTemplates.swift` 對應。
 */
object RecentTemplates {
    private const val PREFS = "kairumo.templates"
    private const val KEY = "recentIds"

    fun load(context: Context): List<String> =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, null)
            ?.split("\n")
            ?.filter { it.isNotEmpty() }
            ?: emptyList()

    /** 記下剛套用的樣板，回傳新的清單。 */
    fun record(context: Context, id: String): List<String> {
        val updated = uniffi.padnote_core.recentTemplatesPush(
            load(context), id, uniffi.padnote_core.recentTemplateLimit()
        )
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY, updated.joinToString("\n"))
            .apply()
        return updated
    }
}
