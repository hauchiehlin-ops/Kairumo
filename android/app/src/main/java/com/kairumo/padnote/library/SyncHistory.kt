package com.kairumo.padnote.library

import android.content.Context
import android.text.format.DateUtils

/**
 * 上次同步的時間，以及正在同步到哪一個帳號。
 *
 * # 為什麼需要它
 *
 * 同步頁原本只有「已登入 / 尚未登入」。按下「立即同步」之後畫面上沒有
 * 任何東西改變 —— 使用者無法分辨「同步成功了」與「按鈕沒反應」，而這
 * 兩者需要的下一步完全不同。
 *
 * 與 Apple 端的 `SyncHistory.swift` 對應：同一組鍵、同一個相對時間寫法。
 * 存 SharedPreferences —— 這是顯示用的字串，不是資料，掉了最壞的情況
 * 是顯示「尚未同步過」。
 */
object SyncHistory {
    private const val PREFS = "kairumo.sync"
    private const val KEY_GOOGLE_AT = "lastGoogleAt"
    private const val KEY_FOLDER_AT = "lastFolderAt"
    private const val KEY_ACCOUNT = "accountEmail"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun markGoogleSynced(context: Context, at: Long = System.currentTimeMillis()) {
        prefs(context).edit().putLong(KEY_GOOGLE_AT, at).apply()
    }

    fun markFolderSynced(context: Context, at: Long = System.currentTimeMillis()) {
        prefs(context).edit().putLong(KEY_FOLDER_AT, at).apply()
    }

    /**
     * 記下這些筆記正在同步到**誰的** Drive。
     *
     * 不需要新增授權範圍：Drive 的 `about.get` 在 `drive.appdata` 底下
     * 就讀得到 `user.emailAddress`。多要一個 `openid email` 只為了顯示
     * 一行字，與這個 App 的定位相反。
     */
    fun setAccount(context: Context, email: String?) {
        val editor = prefs(context).edit()
        if (email.isNullOrEmpty()) editor.remove(KEY_ACCOUNT) else editor.putString(KEY_ACCOUNT, email)
        editor.apply()
    }

    fun account(context: Context): String? = prefs(context).getString(KEY_ACCOUNT, null)

    fun lastGoogleSync(context: Context, none: String): String =
        describe(prefs(context).getLong(KEY_GOOGLE_AT, 0L), none)

    fun lastFolderSync(context: Context, none: String): String =
        describe(prefs(context).getLong(KEY_FOLDER_AT, 0L), none)

    /**
     * 相對時間（「3 分鐘前」）而不是絕對時間。
     *
     * 使用者在這一頁要回答的問題是「剛才那次到底有沒有成功」，
     * 不是「那是幾點幾分」。
     */
    private fun describe(at: Long, none: String): String {
        if (at <= 0L) return none
        return DateUtils.getRelativeTimeSpanString(
            at, System.currentTimeMillis(), DateUtils.MINUTE_IN_MILLIS
        ).toString()
    }
}
