package com.kairumo.padnote.account

import android.content.Context

/**
 * 協作身分（Android）。
 *
 * 與 Apple 端的 `AccountManager` / `UserProfile` 是同一組概念與同一組顏色 ——
 * 兩邊各挑一套調色盤的話，同一個人在兩台裝置上的游標顏色不一樣，
 * 協作時看起來像兩個人。
 *
 * 沒有帳號系統、沒有伺服器：這只是存在本機的一個名字與一個顏色。
 */
object AccountManager {

    private const val PREFS = "kairumo.account"
    private const val KEY_NAME = "displayName"
    private const val KEY_COLOR = "colorHex"

    /**
     * 可選的身分顏色。**必須與 Apple 端的 `IdentityPalette.hexes` 逐字相同。**
     *
     * 固定一組而非任意調色盤：協作時顏色要能互相區辨，
     * 讓人自由選會出現兩個人都挑到相近的灰。
     */
    val PALETTE = listOf(
        "#007AFF", "#34C759", "#AF52DE", "#FF9500",
        "#FF2D55", "#5856D6", "#00C7BE", "#A2845E"
    )
    const val DEFAULT_COLOR = "#007AFF"

    data class Profile(val displayName: String, val colorHex: String)

    fun load(context: Context, fallbackName: String): Profile {
        val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return Profile(
            displayName = p.getString(KEY_NAME, null)?.takeIf { it.isNotBlank() } ?: fallbackName,
            colorHex = p.getString(KEY_COLOR, null) ?: DEFAULT_COLOR
        )
    }

    fun saveName(context: Context, name: String, fallbackName: String) {
        // 空白名字不存。存了的話協作清單上會出現一個沒有名字的人，
        // 而那個人是誰只有他自己知道。
        val clean = name.trim().ifEmpty { fallbackName }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY_NAME, clean).apply()
    }

    fun saveColor(context: Context, hex: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY_COLOR, hex).apply()
    }
}
