package com.kairumo.padnote.library

import android.content.Context

/**
 * 回收桶的保留期限設定。設計見 `docs/plans/expiry-purge.md`。
 *
 * # 這裡只存「使用者選了什麼」，不算任何東西
 *
 * 「還剩幾天」「是否期滿」「哪些可以清」**全部由核心算**（`padnote-sync` 的
 * `retention`）。平台只負責把「現在幾點」與這個天數傳進去 —— 兩個平台各算一份的話，
 * 同一本筆記本在 iPad 上顯示還剩 3 天、在 Android 上卻已經被清掉。
 *
 * 與 `TrashRetention.swift` 是同一套：預設值、選項、壞值處理都一樣。
 */
object TrashRetention {

    private const val PREFS = "kairumo_trash"
    private const val KEY_DAYS = "trash_retention_days"

    /** 預設 30 天。與核心的 `DEFAULT_RETENTION_DAYS` 一致。 */
    const val DEFAULT_DAYS: UInt = 30u

    /** 設定頁給使用者選的值。`0` = 永不自動清除。 */
    val CHOICES: List<UInt> = listOf(7u, 30u, 90u, 0u)

    /**
     * 目前的保留天數。`0` = 永不自動清除（回收桶仍可手動清空）。
     *
     * 沒設過、或存了不在選項裡的怪值，一律回預設 —— 不要因為壞掉的偏好
     * 變成「永不」（不清）或「1 天」（一下就清）。
     */
    fun days(context: Context): UInt {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.contains(KEY_DAYS)) return DEFAULT_DAYS
        val stored = prefs.getInt(KEY_DAYS, -1)
        return if (stored >= 0 && CHOICES.contains(stored.toUInt())) stored.toUInt() else DEFAULT_DAYS
    }

    fun setDays(context: Context, days: UInt) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putInt(KEY_DAYS, days.toInt()).apply()
    }

    /** 現在的 Unix 秒。所有傳進核心的「現在」都從這裡來。 */
    fun nowUnixSeconds(): ULong = (System.currentTimeMillis() / 1000L).coerceAtLeast(0L).toULong()
}
