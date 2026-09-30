package com.kairumo.padnote.library

import android.content.Context
import java.io.File

/**
 * 筆記本的回收桶。設計見 `docs/plans/expiry-purge.md`。
 *
 * # 套件搬到 `trash/`，不是留在原地打記號
 *
 * 一本筆記本就是 `notebooks/<id>.padnote` 這個目錄，清單與同步都靠列舉那個目錄。
 * 搬到旁邊的 `trash/` 之後，列舉的程式碼根本看不到它 —— 不可能有哪一處漏判
 * 「已在回收桶」而把它當成新筆記匯回來（刪掉的東西自己復活）。
 * 同一個檔案系統內的 rename 是原子的：中途斷電不會留下半個目錄。
 *
 * 搬檔案與「記墓碑」分開：搬檔案在這裡，記墓碑在 [AccountSyncStore]。
 * 兩者由 [NotebookLibrary.delete] 等呼叫端串起來，這樣檔案搬移可以單獨測。
 *
 * 與 Apple 端（`NotebookStore` 的 `trashLocally` / `restoreLocally` / `purgeLocally`）
 * 是同一套語意。
 */
object NotebookTrash {

    private const val DIRECTORY = "trash"

    /** 回收桶的套件目錄。與 `notebooks/` 同層。 */
    fun directory(context: Context): File {
        val dir = File(context.filesDir, DIRECTORY)
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    private fun live(context: Context, id: String) =
        File(NotebookLibrary.directory(context), "$id.${NotebookLibrary.EXTENSION}")

    private fun trashed(context: Context, id: String) =
        File(directory(context), "$id.${NotebookLibrary.EXTENSION}")

    /** 移進回收桶（**只動本機**，不記墓碑）。回傳有沒有真的移。 */
    fun moveToTrash(context: Context, id: String): Boolean {
        val source = live(context, id)
        if (!source.exists()) return false
        val target = trashed(context, id)
        if (target.exists()) target.deleteRecursively()
        return source.renameTo(target)
    }

    /** 從回收桶搬回來（**只動本機**，不記還原）。 */
    fun restoreLocally(context: Context, id: String): Boolean {
        val source = trashed(context, id)
        if (!source.exists()) return false
        val target = live(context, id)
        // 已經有同 id 的（不該發生）就不要蓋掉 —— 那是使用者正在用的那一本。
        if (target.exists()) return false
        return source.renameTo(target)
    }

    /** 永久刪除本機的一本（**只動本機**）。原本的位置也一併清。 */
    fun purgeLocally(context: Context, id: String) {
        runCatching { trashed(context, id).deleteRecursively() }
        runCatching { live(context, id).deleteRecursively() }
    }

    /** 回收桶裡有哪些筆記本 id。 */
    fun trashedIds(context: Context): List<String> =
        directory(context).listFiles()
            ?.filter { it.isDirectory && it.name.endsWith(".${NotebookLibrary.EXTENSION}") }
            ?.map { it.name.removeSuffix(".${NotebookLibrary.EXTENSION}") }
            ?: emptyList()

    /**
     * 讓本機與索引一致（同步之後呼叫）。
     *
     * - **別台刪掉的**（索引有墓碑、套件還在 `notebooks/`）→ 移進回收桶，不是永久刪除。
     * - **別台還原的**（在回收桶、索引已不是墓碑）→ 搬回 `notebooks/`。
     *
     * 兩個方向都**看現在的索引**，不用同步開頭算好的名單：同步進行到一半時
     * 使用者可能剛好刪了或還原了一本，用舊名單會把它倒回去。
     */
    fun reconcile(context: Context): Boolean {
        var changed = false
        val liveDir = NotebookLibrary.directory(context)
        liveDir.listFiles()
            ?.filter { it.isDirectory && it.name.endsWith(".${NotebookLibrary.EXTENSION}") }
            ?.map { it.name.removeSuffix(".${NotebookLibrary.EXTENSION}") }
            ?.filter { AccountSyncStore.isDeleted(context, it) }
            ?.forEach { if (moveToTrash(context, it)) changed = true }
        for (id in trashedIds(context)) {
            if (AccountSyncStore.isDeleted(context, id)) continue
            if (restoreLocally(context, id)) {
                changed = true
            } else if (live(context, id).exists()) {
                // 索引說它活著、`notebooks/` 裡也已經有一份（例如重新抓下來的）：
                // 回收桶裡這份是過期的殘骸，留著就永遠清不掉。
                runCatching { trashed(context, id).deleteRecursively() }
                changed = true
            }
        }
        return changed
    }

    /** 從回收桶還原並記下還原（別的裝置也會看到它回來）。 */
    fun restore(context: Context, id: String): Boolean {
        if (!restoreLocally(context, id)) return false
        AccountSyncStore.recordRestore(context, id)
        return true
    }

    /**
     * 永久清掉**已期滿**的本機筆記本。啟動時與每輪同步之後呼叫。
     * 期限由核心算（[AccountSyncStore.expiredNotebookIdsForLocalPurge]）。
     */
    fun purgeExpired(context: Context): Int {
        AccountSyncStore.stampLegacyTombstonesIfNeeded(context)
        val expired = AccountSyncStore.expiredNotebookIdsForLocalPurge(context)
        expired.forEach { purgeLocally(context, it) }
        return expired.size
    }

    /**
     * 永久刪除回收桶裡的一本（使用者按了「永久刪除」）。
     *
     * 先把「立即永久刪除」寫進墓碑，再清本機 —— 雲端那一半與別台的副本靠它自然完成
     * （見 [AccountSyncStore.recordPurgeRequest]）。與 [purgeLocally] 的差別：後者只動本機、
     * 不記任何東西，給期滿清除與測試用。
     */
    fun purgePermanently(context: Context, id: String) {
        AccountSyncStore.recordPurgeRequest(context, id)
        purgeLocally(context, id)
    }

    /** 清空回收桶（使用者按了「清空」）。雲端那一半由呼叫端接著觸發回收。 */
    fun empty(context: Context): Int {
        val ids = trashedIds(context)
        ids.forEach { purgePermanently(context, it) }
        return ids.size
    }
}
