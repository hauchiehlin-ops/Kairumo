package com.kairumo.padnote.library

import android.content.Context
import java.util.UUID
import uniffi.padnote_core.syncChildrenOf
import uniffi.padnote_core.syncWouldCreateCycle

/**
 * 資料夾階層（Android）。
 *
 * # 為什麼沒有第二份資料
 *
 * 資料夾**完全住在同步索引裡**（[AccountSyncStore]），不另外存一份本機清單。
 * 索引本來就有資料夾型別、父子關係、標題與墓碑，而且合併規則在核心。
 * 再存一份的話就有兩個真相來源，而它們一定會在某次同步之後對不起來 ——
 * 症狀是「資料夾在，裡面的筆記本不見了」或反過來。
 *
 * （Apple 端目前是兩份：`NotebookStore.folders` 加上索引。那是既有設計，
 *   這裡沒有跟著抄 —— 抄過來只是把同一個問題複製兩遍。）
 *
 * # 筆記本屬於哪個資料夾
 *
 * 就是它在索引裡那一筆的 `parentId`。索引裡**沒有**的筆記本算在最上層：
 * 那是「還沒被記錄過」，不是「被丟出資料夾」。
 */
object FolderTree {

    data class Folder(val id: String, val title: String, val parentId: String?)

    /**
     * 最上層那一層的顯示名稱。
     *
     * **只存在這台裝置上**，與 Apple 的 `NotebookStore.rootFolderName` 同語意：
     * 它不是一個真的資料夾（最上層沒有對應的索引項目），所以也沒有東西可以同步。
     * 空的就用語系表裡的「最上層」。
     */
    private const val ROOT_NAME_PREF = "kairumo.root_folder_name"

    fun rootName(context: Context, fallback: String): String =
        context.getSharedPreferences("kairumo", Context.MODE_PRIVATE)
            .getString(ROOT_NAME_PREF, null)
            ?.takeIf { it.isNotBlank() }
            ?: fallback

    fun renameRoot(context: Context, name: String) {
        val clean = name.trim()
        if (clean.isEmpty()) return
        context.getSharedPreferences("kairumo", Context.MODE_PRIVATE)
            .edit()
            .putString(ROOT_NAME_PREF, clean)
            .apply()
    }

    /** 某個資料夾底下的子資料夾。`parentId` 傳 null 表示最上層。 */
    fun subfolders(context: Context, parentId: String?): List<Folder> =
        syncChildrenOf(AccountSyncStore.indexJson(context), parentId ?: "")
            .filter { it.isFolder }
            .map { Folder(it.id, it.title, it.parentId.takeIf { p -> p.isNotEmpty() }) }

    /** 這個筆記本或資料夾在哪個資料夾底下。null 表示最上層。 */
    fun parentOf(context: Context, id: String): String? =
        AccountSyncStore.item(context, id)?.parentId?.takeIf { it.isNotEmpty() }

    fun titleOf(context: Context, id: String): String? =
        AccountSyncStore.item(context, id)?.title

    /** 從某個資料夾往上到最上層的路徑，最上層在前。麵包屑用。 */
    fun pathTo(context: Context, folderId: String?): List<Folder> {
        var cursor = folderId
        val seen = mutableSetOf<String>()
        val reversed = mutableListOf<Folder>()
        while (cursor != null) {
            // 迴圈保護：兩台裝置各自把 A 搬進 B、把 B 搬進 A 就會接成環，
            // 沒有這道保護的話麵包屑會無限長 —— App 直接凍住。
            if (!seen.add(cursor)) break
            val item = AccountSyncStore.item(context, cursor) ?: break
            reversed += Folder(item.id, item.title, item.parentId.takeIf { it.isNotEmpty() })
            cursor = item.parentId.takeIf { it.isNotEmpty() }
        }
        return reversed.reversed()
    }

    /**
     * 全部資料夾，攤平成一份清單（不分層級）。搬移對話框要用。
     *
     * 已刪除的、以及祖先被刪掉的都不列 —— 讓使用者把東西搬進一個
     * 已經不存在的資料夾，等於當場把它藏起來。
     */
    fun all(context: Context): List<Folder> {
        val json = AccountSyncStore.indexJson(context)
        val out = mutableListOf<Folder>()
        fun walk(parent: String?, depth: Int) {
            // 深度上限：索引可能因為兩台裝置各自搬移而接成環。核心的
            // `children_of` 會擋掉環上的項目，這裡再加一道保險。
            if (depth > 32) return
            for (item in syncChildrenOf(json, parent ?: "")) {
                if (!item.isFolder) continue
                out += Folder(item.id, item.title, parent)
                walk(item.id, depth + 1)
            }
        }
        walk(null, 0)
        return out
    }

    /** 建一個資料夾，回傳它的 id。 */
    fun create(context: Context, title: String, parentId: String?): String {
        val id = UUID.randomUUID().toString()
        AccountSyncStore.record(
            context, id = id, title = title, parentId = parentId, isFolder = true
        )
        return id
    }

    fun rename(context: Context, id: String, title: String) {
        val parent = parentOf(context, id)
        AccountSyncStore.record(
            context, id = id, title = title, parentId = parent, isFolder = true
        )
    }

    /**
     * 刪除資料夾。**只留一個墓碑，裡面的東西不動。**
     *
     * 裡面的筆記本會因為祖先被刪而一起從清單上消失（核心的
     * `sync_is_hidden` 會走祖先鏈），但檔案還在。逐一刪掉裡面每一本的話，
     * 使用者在另一台裝置上把資料夾救回來時，內容已經沒了。
     */
    fun delete(context: Context, id: String) {
        AccountSyncStore.recordDeletion(context, id)
    }

    /**
     * 把一個項目搬進某個資料夾。回傳 false 表示**會形成環**，沒有動。
     *
     * 一定要在動手**之前**問：把資料夾搬進自己的子孫裡，那棵子樹會從樹上
     * 整個斷開，而且刪不掉也救不回來。
     */
    fun move(context: Context, id: String, title: String, isFolder: Boolean, toParent: String?): Boolean {
        if (isFolder && syncWouldCreateCycle(AccountSyncStore.indexJson(context), id, toParent ?: "")) {
            return false
        }
        AccountSyncStore.record(
            context, id = id, title = title, parentId = toParent, isFolder = isFolder
        )
        return true
    }
}
