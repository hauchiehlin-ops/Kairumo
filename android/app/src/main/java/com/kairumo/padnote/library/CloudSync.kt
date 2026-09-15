package com.kairumo.padnote.library

import android.content.Context
import com.kairumo.padnote.oauth.DriveHttpClient
import com.kairumo.padnote.oauth.GoogleAuth
import java.io.File
import uniffi.padnote_core.FfiCloudSyncResult
import uniffi.padnote_core.gdriveSyncMetadata
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
        return gdriveSyncNotebook(
            com.kairumo.padnote.oauth.DriveHttpClient(token),
            path.absolutePath,
            notebookId
        )
    }

    /**
     * 同步中繼資料，再同步每一本還活著的筆記本。
     *
     * 順序不能反：先收斂索引，才知道哪些筆記本還活著 ——
     * 先同步內容的話，會把另一台已經刪掉的筆記本內容又推上去。
     */
    fun runFull(context: Context, deviceId: UInt): Pair<FfiCloudSyncResult?, Int> {
        val meta = runOnce(context)
        if (meta == null || !meta.ok) return meta to 0
        var changed = 0
        for (entry in NotebookLibrary.all(context, deviceId)) {
            val result = syncNotebook(context, entry.id) ?: continue
            if (result.ok && result.downloaded > 0u) changed++
        }
        return meta to changed
    }
}
