package com.kairumo.padnote.library

import android.content.Context
import java.util.UUID
import uniffi.padnote_core.FfiLibraryItem
import uniffi.padnote_core.FfiSyncedField
import uniffi.padnote_core.syncChildrenOf
import uniffi.padnote_core.syncDeleteItem
import uniffi.padnote_core.syncGetSetting
import uniffi.padnote_core.syncIsDeleted
import uniffi.padnote_core.syncMergeIndex
import uniffi.padnote_core.syncMergeSettings
import uniffi.padnote_core.syncNextLamport
import uniffi.padnote_core.syncSetSetting
import uniffi.padnote_core.syncUpsertItem
import uniffi.padnote_core.syncWouldCreateCycle

/**
 * 帳號式同步的本機那一半（G-04 / G-05，ADR-0011）。
 *
 * # 這個物件不做同步
 *
 * 它只做兩件事：把「使用者做了什麼」記成同步得動的事件，以及把合併結果讀出來。
 * 真正的上傳下載是 provider 的事（`padnote-sync`），還要等 G-01 的 OAuth。
 * 先把記錄做對是有意義的 —— **記錄漏掉的東西，之後接上雲端也補不回來**。
 * 最典型的是刪除：沒有留下墓碑的話，等雲端接上，另一台裝置會把已經刪掉的
 * 筆記本原封不動傳回來。
 *
 * # 與 Apple 端是同一套
 *
 * 合併規則、時戳來源、雲端路徑全部來自核心，兩邊只是各自的儲存殼。
 * 這裡的每一個方法在 `AccountSyncStore.swift` 都有同名的對應品。
 */
object AccountSyncStore {

    private const val PREFS = "kairumo_account_sync"
    private const val KEY_INDEX = "index.v1"
    private const val KEY_SETTINGS = "settings.v1"
    private const val KEY_DEVICE = "deviceId.v1"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /**
     * 這台裝置的 id。**每次安裝一個，重裝就是新裝置**（ADR-0011）。
     *
     * 用它在時戳平手時決勝，所以必須穩定。
     */
    fun deviceId(context: Context): String {
        val p = prefs(context)
        p.getString(KEY_DEVICE, null)?.let { return it }
        val fresh = UUID.randomUUID().toString()
        p.edit().putString(KEY_DEVICE, fresh).apply()
        return fresh
    }

    fun indexJson(context: Context): String = prefs(context).getString(KEY_INDEX, "") ?: ""

    fun settingsJson(context: Context): String = prefs(context).getString(KEY_SETTINGS, "") ?: ""

    // ── 筆記本與資料夾（G-05）──────────────────────────────────

    /**
     * 記下一個筆記本或資料夾的目前狀態（新增、改名、搬移都走這裡）。
     *
     * 改名與搬移**不能**靠「刪掉舊的再加一個」表示 —— 那在合併時與真正的
     * 刪除完全一樣，另一台裝置會把它當成已刪除。
     */
    fun record(
        context: Context,
        id: String,
        title: String,
        parentId: String? = null,
        isFolder: Boolean = false
    ) {
        val item = FfiLibraryItem(
            id = id,
            isFolder = isFolder,
            title = title,
            parentId = parentId ?: "",
            lamport = nextLamport(context),
            device = deviceId(context),
            deleted = false
        )
        setIndex(context, syncUpsertItem(indexJson(context), item))
    }

    /** 記下刪除。留**墓碑**，不是把它從索引裡拿掉。 */
    fun recordDeletion(context: Context, id: String) {
        setIndex(
            context,
            syncDeleteItem(indexJson(context), id, nextLamport(context), deviceId(context))
        )
    }

    /**
     * 這個 id 是不是已經被（可能是另一台裝置）刪除了。
     *
     * 索引裡沒看過的一律回 false —— 「沒看過」不是「被刪了」，混在一起的話，
     * 剛同步過來的新筆記本會被當成已刪除而收掉。
     */
    fun isDeleted(context: Context, id: String): Boolean =
        syncIsDeleted(indexJson(context), id)

    /**
     * 這一筆該不該因為刪除而**從清單上消失**。
     *
     * 清單要用這個而不是 [isDeleted]：後者只看自己那一筆，刪掉一個資料夾
     * 之後，裡面的筆記本仍然會被列出來 —— 那就是「存在但打不開、也刪不掉」
     * 的幽靈。核心會走完整條祖先鏈。
     */
    fun isHidden(context: Context, id: String): Boolean =
        uniffi.padnote_core.syncIsHidden(indexJson(context), id)

    /** 索引裡的一筆。沒有就回 null —— 那是「還沒記錄過」，不是「被刪了」。 */
    fun item(context: Context, id: String): FfiLibraryItem? =
        uniffi.padnote_core.syncItem(indexJson(context), id)

    /** 某個資料夾底下還活著的項目。`parentId` 傳 null 表示根目錄。 */
    fun children(context: Context, parentId: String? = null): List<FfiLibraryItem> =
        syncChildrenOf(indexJson(context), parentId ?: "")

    /**
     * 把一個資料夾搬進去會不會形成環。**動手之前**問 ——
     * 搬進自己的子孫裡，那棵子樹會從樹上斷開，救不回來。
     */
    fun wouldCreateCycle(context: Context, itemId: String, newParentId: String?): Boolean =
        syncWouldCreateCycle(indexJson(context), itemId, newParentId ?: "")

    /** 合併另一台裝置（或雲端）的索引。 */
    fun mergeIndex(context: Context, remoteJson: String) {
        setIndex(context, syncMergeIndex(indexJson(context), remoteJson))
    }

    // ── 跨裝置設定（G-04）──────────────────────────────────────

    /** 目前的介面語言。沒設過時回 null，由平台自己決定預設。 */
    fun syncedLanguage(context: Context): String? =
        syncGetSetting(settingsJson(context), FfiSyncedField.LOCALE).takeIf { it.isNotEmpty() }

    fun setSyncedLanguage(context: Context, tag: String) {
        setSettings(
            context,
            syncSetSetting(
                settingsJson(context),
                FfiSyncedField.LOCALE,
                tag,
                nextLamport(context),
                deviceId(context)
            )
        )
    }

    fun syncedToolbarJson(context: Context): String? =
        syncGetSetting(settingsJson(context), FfiSyncedField.TOOLBAR_JSON).takeIf { it.isNotEmpty() }

    fun setSyncedToolbarJson(context: Context, json: String) {
        setSettings(
            context,
            syncSetSetting(
                settingsJson(context),
                FfiSyncedField.TOOLBAR_JSON,
                json,
                nextLamport(context),
                deviceId(context)
            )
        )
    }

    /** 合併另一台裝置（或雲端）的設定。 */
    fun mergeSettings(context: Context, remoteJson: String) {
        setSettings(context, syncMergeSettings(settingsJson(context), remoteJson))
    }

    // ── 內部 ──────────────────────────────────────────────────

    /**
     * 下一個時戳。**由核心從文件本身推導**，不是自己維護一個計數器 ——
     * 計數器遲早會有一次忘了在合併之後往前跳，於是這台裝置寫出去的每一筆
     * 都比對方舊，永遠推不上去。
     *
     * 索引與設定共用同一條時間線：取兩邊的較大值，才不會出現
     * 「改完設定再改名，名字的時戳反而比較小」。
     */
    private fun nextLamport(context: Context): ULong =
        maxOf(syncNextLamport(indexJson(context)), syncNextLamport(settingsJson(context)))

    private fun setIndex(context: Context, json: String) {
        prefs(context).edit().putString(KEY_INDEX, json).apply()
    }

    private fun setSettings(context: Context, json: String) {
        prefs(context).edit().putString(KEY_SETTINGS, json).apply()
    }
}
