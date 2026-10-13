package com.kairumo.padnote.profile

import android.content.Context
import com.kairumo.padnote.account.AccountManager

/**
 * 設定檔名單的載入與存檔（Android）。與 Apple 端 `ProfileManager` 的名單部分對應。
 *
 * 名單存在**裝置共用**的偏好（`kairumo.profiles`，不屬於任何設定檔），整份 JSON 一個鍵、`commit()` 同步寫 ——
 * 切換之後行程馬上要結束，非同步的 `apply()` 可能還沒落盤，下次啟動就回到舊的設定檔。
 */
// profile-scope: device 設定檔名單本身是整台裝置共用的
object ProfileManager {
    private const val KEY_REGISTRY = "registry"

    @Volatile
    private var cached: ProfileRegistry? = null

    /** 目前的名單。第一次呼叫時讀檔（沒有就建立只有預設設定檔的初始名單 —— 它對應既有資料，什麼都不搬）。 */
    fun registry(context: Context): ProfileRegistry {
        cached?.let { return it }
        synchronized(this) {
            cached?.let { return it }
            val prefs = ProfileContext.devicePrefs(context, ProfileContext.DEVICE_PREFS)
            val fallbackName = AccountManager.customName(context, "Kairumo")
            val loaded = prefs.getString(KEY_REGISTRY, null)?.let { ProfileRegistry.fromJson(it) }
            val registry = loaded?.repaired(fallbackName, AccountManager.DEFAULT_COLOR)
                ?: ProfileRegistry.initial(fallbackName, AccountManager.DEFAULT_COLOR)
            if (loaded == null || registry != loaded) save(context, registry)
            // `ProfileContext` 與名單必須一致。切換時「先名單、後 context」，兩步之間被中斷就以名單為準。
            if (ProfileContext.activeId(context) != registry.activeId) {
                ProfileContext.setActive(context, registry.activeId)
            }
            cached = registry
            return registry
        }
    }

    /** 存名單。回傳有沒有真的寫進磁碟。 */
    fun save(context: Context, registry: ProfileRegistry): Boolean {
        val ok = ProfileContext.devicePrefs(context, ProfileContext.DEVICE_PREFS)
            .edit().putString(KEY_REGISTRY, registry.toJson()).commit()
        if (ok) cached = registry
        return ok
    }

    /** 只給測試：丟掉快取。 */
    internal fun resetCacheForTesting() {
        cached = null
    }
}
