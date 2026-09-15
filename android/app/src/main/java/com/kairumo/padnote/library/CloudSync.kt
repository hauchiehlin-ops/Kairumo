package com.kairumo.padnote.library

import android.content.Context
import com.kairumo.padnote.oauth.DriveHttpClient
import com.kairumo.padnote.oauth.GoogleAuth
import uniffi.padnote_core.FfiCloudSyncResult
import uniffi.padnote_core.gdriveSyncMetadata

/**
 * 跑一輪雲端同步（Android）。
 *
 * 把三塊接起來：`GoogleAuth` 的權杖、`DriveHttpClient` 的 HTTP、
 * 以及核心的合併規則。合併之後的結果寫回 [AccountSyncStore] ——
 * **雲端那邊可能有別台裝置的改動**，不寫回去的話這次同步等於白做。
 *
 * 目前同步的只有**中繼資料**（設定、筆記本清單、刪除墓碑），
 * 筆記內容本身還沒有 —— 那要走 chunk 與 SyncEngine。
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
}
