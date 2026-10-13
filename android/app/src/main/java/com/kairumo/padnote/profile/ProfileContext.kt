package com.kairumo.padnote.profile

import android.content.Context
import android.content.SharedPreferences
import java.io.File

/**
 * 「現在是哪個設定檔」，以及它的資料該放在哪裡（Android）。
 *
 * # 為什麼是全域、而且取用一律帶 [Context]
 *
 * 偏好設定、檔案位置、加密偏好的檔名全部要依「現在的設定檔」決定，而它們被背景執行緒、
 * 同步、WorkManager 的 worker 到處呼叫 —— 這些地方都拿得到 Context，卻不一定在主執行緒。
 * 所以這裡只存一個 `@Volatile` 的 id，其餘全部由它算出來。
 *
 * # 預設設定檔 = 升級前的那一份，完全不變
 *
 * - 偏好設定：檔名**原樣**（沒有任何後綴）
 * - 檔案：照舊放在 `filesDir`
 *
 * 只有其他設定檔才會加後綴／放到 `filesDir/profiles/<id>/`。既有使用者升級後沒有任何資料被搬動或改名。
 * 與 Apple 端的 `ProfileContext.swift` 對應。
 */
object ProfileContext {
    /** 裝置共用的偏好（不屬於任何設定檔）：記著「現在是哪一個」與設定檔名單。 */
    internal const val DEVICE_PREFS = "kairumo.profiles"
    private const val KEY_ACTIVE = "activeId"

    @Volatile
    private var cachedActiveId: String? = null

    /** 目前使用中的設定檔 id。 */
    fun activeId(context: Context): String {
        cachedActiveId?.let { return it }
        val saved = context.applicationContext
            .getSharedPreferences(DEVICE_PREFS, Context.MODE_PRIVATE)
            .getString(KEY_ACTIVE, null) ?: ProfileRecord.DEFAULT_ID
        cachedActiveId = saved
        return saved
    }

    fun isDefault(context: Context): Boolean = activeId(context) == ProfileRecord.DEFAULT_ID

    /**
     * 切換使用中的設定檔。**只有 `ProfileSwitcher` 該呼叫它** —— 它負責先收尾、再切、再重新載入。
     * 用 `commit()` 同步寫：切換之後行程若馬上被收掉，下次啟動不能回到舊的設定檔。
     */
    internal fun setActive(context: Context, id: String) {
        cachedActiveId = id
        context.applicationContext
            .getSharedPreferences(DEVICE_PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY_ACTIVE, id).commit()
    }

    /** 只給測試：清掉快取，下次重新讀。 */
    internal fun resetCacheForTesting() {
        cachedActiveId = null
    }

    // ── 偏好設定 ─────────────────────────────────────────────

    /**
     * 偏好設定的檔名。預設設定檔**原樣**，其他加上 `.pf.<id>`。
     * 純函式：不碰 Context，所以單元測試直接驗。
     */
    fun prefsName(base: String, profileId: String): String =
        if (profileId == ProfileRecord.DEFAULT_ID) base else "$base.pf.$profileId"

    /**
     * 這個設定檔的偏好。**取代程式裡原本直接用的 `context.getSharedPreferences(name, ...)`。**
     * 每次呼叫都重新解析設定檔 —— 不要把回傳值存起來跨越切換。
     */
    fun prefs(context: Context, base: String): SharedPreferences =
        context.applicationContext.getSharedPreferences(
            prefsName(base, activeId(context)), Context.MODE_PRIVATE
        )

    /** 整台裝置共用的偏好。用這個要有理由 —— 預設是 [prefs]。 */
    fun devicePrefs(context: Context, name: String): SharedPreferences =
        context.applicationContext.getSharedPreferences(name, Context.MODE_PRIVATE)

    // ── 檔案 ─────────────────────────────────────────────────

    /** 純函式：預設設定檔的根目錄就是 [base] 本身，其他是 `<base>/profiles/<id>`。 */
    fun dataRoot(base: File, profileId: String): File =
        if (profileId == ProfileRecord.DEFAULT_ID) base else File(File(base, "profiles"), profileId)

    /** 這個設定檔的資料根目錄（筆記、垃圾桶、同步快照都在底下）。取代 `context.filesDir`。 */
    fun dataDir(context: Context): File =
        dataRoot(context.filesDir, activeId(context)).also { it.mkdirs() }

    /** 快取（縮圖、預覽、匯出暫存）。**一定要分開**：範例筆記的 id 在每個設定檔都一樣。 */
    fun cacheDir(context: Context): File =
        dataRoot(context.cacheDir, activeId(context)).also { it.mkdirs() }

    // ── 刪除 ─────────────────────────────────────────────────

    /**
     * 這個設定檔留在磁碟上的所有東西（刪除設定檔時用）。
     * 預設設定檔回空 —— 它的根目錄就是整個 `filesDir`，裡面還有別人的設定檔與裝置共用的東西，
     * 刪除時要逐項處理，不能整個砍。
     */
    fun ownedDirectories(context: Context, profileId: String): List<File> {
        if (profileId == ProfileRecord.DEFAULT_ID) return emptyList()
        return listOf(
            dataRoot(context.filesDir, profileId),
            dataRoot(context.cacheDir, profileId)
        )
    }

    /** 這個設定檔的所有偏好檔名（掃 `shared_prefs/` 找後綴）。預設設定檔回空，理由同上。 */
    fun ownedPrefsNames(context: Context, profileId: String): List<String> {
        if (profileId == ProfileRecord.DEFAULT_ID) return emptyList()
        val dir = File(context.applicationInfo.dataDir, "shared_prefs")
        val suffix = ".pf.$profileId.xml"
        return dir.listFiles { f -> f.name.endsWith(suffix) }
            ?.map { it.name.removeSuffix(".xml") }
            ?: emptyList()
    }
}
