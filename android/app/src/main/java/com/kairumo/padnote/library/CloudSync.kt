package com.kairumo.padnote.library

import android.content.Context
import com.kairumo.padnote.oauth.DriveHttpClient
import com.kairumo.padnote.oauth.GoogleAuth
import java.io.File
import uniffi.padnote_core.FfiCloudSyncResult
import uniffi.padnote_core.gdriveSyncMetadata
import uniffi.padnote_core.gdriveSyncMedia
import uniffi.padnote_core.gdriveSyncNotebook

/**
 * 跑一輪雲端同步（Android）。
 *
 * 把三塊接起來：`GoogleAuth` 的權杖、`DriveHttpClient` 的 HTTP、
 * 以及核心的合併規則。合併之後的結果寫回 [AccountSyncStore] ——
 * **雲端那邊可能有別台裝置的改動**，不寫回去的話這次同步等於白做。
 *
 * 兩層都同步：中繼資料（設定、筆記本清單、刪除墓碑）與**內容**
 * （每一本筆記的 oplog 檔）。
 */
object CloudSync {

    /**
     * 同步一輪。**會阻塞網路 I/O，要在背景執行緒呼叫。**
     *
     * 回傳 null 表示沒登入。
     */
    fun runOnce(context: Context): FfiCloudSyncResult? {
        // 這裡面可能會先去更新權杖，所以也是網路 I/O。
        val token = GoogleAuth.validAccessToken(context) ?: return null

        val result = gdriveSyncMetadata(
            DriveHttpClient(token),
            AccountSyncStore.settingsJson(context),
            AccountSyncStore.indexJson(context)
        )

        if (result.ok) {
            // 合併結果要落地。只更新畫面不寫檔的話，重開 App 就回到同步前。
            AccountSyncStore.mergeSettings(context, result.settingsJson)
            AccountSyncStore.mergeIndex(context, result.indexJson)
        } else if (result.needsReauth) {
            // 權杖救不回來了。清掉本機那份，讓 UI 顯示「未登入」——
            // 留著一個永遠失敗的權杖，背景會一直重試而使用者不知道要去登入。
            GoogleAuth.signOutLocally(context)
        }
        return result
    }

    /**
     * 同步一本筆記本的內容。**會阻塞網路 I/O，要在背景執行緒呼叫。**
     *
     * 回傳 `downloaded > 0` 時，**呼叫端必須重開這本筆記的 session** ——
     * oplog 檔已經寫進套件，但記憶體裡那份還是同步前的狀態，
     * 畫面上看不到任何變化，使用者會以為同步沒作用。
     */
    fun syncNotebook(context: Context, notebookId: String): uniffi.padnote_core.FfiNotebookSyncResult? {
        val token = GoogleAuth.validAccessToken(context) ?: return null
        val path = File(NotebookLibrary.directory(context), "$notebookId.padnote")
        if (!path.exists()) return null
        val http = com.kairumo.padnote.oauth.DriveHttpClient(token)
        val ops = gdriveSyncNotebook(http, path.absolutePath, notebookId)
        if (!ops.ok) return ops

        // 媒體接在 oplog 之後。順序很重要：oplog 裡的 AddImage 會指向一個
        // blob id，媒體還沒到的話，那一頁會有一個指向不存在檔案的圖片區塊。
        // 反過來先傳媒體只是多佔一點空間，不會讓畫面壞掉。
        val media = gdriveSyncMedia(http, path.absolutePath, notebookId)
        return uniffi.padnote_core.FfiNotebookSyncResult(
            ok = media.ok,
            uploaded = ops.uploaded + media.uploaded,
            downloaded = ops.downloaded + media.downloaded,
            error = media.error,
            needsReauth = media.needsReauth
        )
    }

    /**
     * 同步中繼資料，再同步每一本還活著的筆記本。
     *
     * 順序不能反：先收斂索引，才知道哪些筆記本還活著 ——
     * 先同步內容的話，會把另一台已經刪掉的筆記本內容又推上去。
     */
    fun runFull(context: Context, deviceId: UInt): Pair<FfiCloudSyncResult?, List<String>> {
        val meta = runOnce(context)
        if (meta == null || !meta.ok) return meta to emptyList()
        val changed = mutableListOf<String>()
        for (entry in NotebookLibrary.all(context, deviceId)) {
            val result = syncNotebook(context, entry.id) ?: continue
            if (result.ok && result.downloaded > 0u) changed += entry.id
        }
        // 別台裝置**新建**的筆記本在本機連套件目錄都沒有，上面那一圈看不到它們。
        // 少了這一步，症狀是：索引同步成功、清單上出現了標題，點進去卻是空的。
        changed += pullNewNotebooks(context, meta.indexJson)
        return meta to changed
    }

    /**
     * 把雲端有、本機還沒有的筆記本整本抓下來。回傳抓下來的那幾本的 id。
     *
     * 清單來自**合併後的索引**，不是本機那一份 —— 用本機的話，剛從雲端
     * 收斂進來的那幾本還不在裡面，永遠差一輪。
     */
    private fun pullNewNotebooks(context: Context, mergedIndexJson: String): List<String> {
        val dir = NotebookLibrary.directory(context)
        val pulled = mutableListOf<String>()
        for (item in uniffi.padnote_core.syncLiveNotebooks(mergedIndexJson)) {
            val path = File(dir, "${item.id}.padnote")
            if (path.exists()) continue
            // 權杖每一本都重新取一次：整批抓下來可能跨過存取權杖的有效期，
            // 用同一個舊的會在中途開始 401。
            val token = GoogleAuth.validAccessToken(context) ?: break
            val result = uniffi.padnote_core.gdriveCloneNotebook(
                DriveHttpClient(token),
                path.absolutePath,
                item.id,
                item.title,
                System.currentTimeMillis().toULong()
            )
            if (result.ok) {
                pulled += item.id
            } else {
                // 抓失敗時把空殼刪掉。留著的話，下一輪 `path.exists()` 為真，
                // 這本就再也不會被重抓 —— 使用者會看到一本永遠打不開的空筆記。
                path.deleteRecursively()
                if (result.needsReauth) break
            }
        }
        return pulled
    }
}
