package com.kairumo.padnote.library

import android.content.Context
import com.kairumo.padnote.oauth.DriveHttpClient
import com.kairumo.padnote.oauth.GoogleAuth
import com.kairumo.padnote.sync.SyncLogger
import com.kairumo.padnote.sync.SyncSource
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.runBlocking
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
    /**
     * 這些筆記正在同步到**誰的** Drive。
     *
     * 走 Drive 的 `about.get` —— 它在 `drive.appdata` 這個範圍底下就讀得到
     * `user.emailAddress`，**不需要 `openid email`**，也就不必讓使用者
     * 重新同意一次。多要一個範圍只為了顯示一行字，與這個 App 的定位相反。
     *
     * 拿不到就回 null：這是一行顯示用的字，不該讓同步失敗。
     * **不要在主執行緒呼叫** —— 它打網路。
     */
    fun accountEmail(context: Context): String? = runCatching {
        val token = com.kairumo.padnote.oauth.GoogleAuth.validAccessToken(context)
            ?.takeIf { it.isNotEmpty() } ?: return null
        val url = java.net.URL("https://www.googleapis.com/drive/v3/about?fields=user")
        val conn = (url.openConnection() as java.net.HttpURLConnection).apply {
            setRequestProperty("Authorization", "Bearer $token")
            connectTimeout = 10_000
            readTimeout = 10_000
        }
        val body = conn.inputStream.bufferedReader().use { it.readText() }
        org.json.JSONObject(body)
            .optJSONObject("user")
            ?.optString("emailAddress")
            ?.takeIf { it.isNotEmpty() }
    }.getOrNull()

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
    /**
     * 一輪完整同步的結果。
     *
     * **有上傳與下載的數量**，不是只有「成功了沒」。與 Apple 的
     * `NotebookSyncCoordinator.Report` 對應 —— 只說「同步完成」的話，
     * 使用者分不出「真的傳了東西」與「其實什麼也沒做」，而那兩件事在
     * 「為什麼另一台還是舊的」這個問題上差很多。
     */
    data class FullResult(
        val meta: FfiCloudSyncResult?,
        val uploaded: Int,
        val downloaded: Int,
        /** 被別台改過、需要重開 session 的筆記本 id。 */
        val changed: List<String>
    )

    fun runFull(context: Context, deviceId: UInt, activeNotebookId: String? = null): FullResult {
        SyncLogger.log("【Google Drive 同步】開始執行", SyncSource.GOOGLE_DRIVE)
        SyncLogger.log("步驟 1：同步中繼資料與索引 (連線中)...", SyncSource.GOOGLE_DRIVE)

        // 確保本機目前所有活躍呈現的筆記本，都登記於同步索引中且無誤植墓碑
        val allLocalEntries = NotebookLibrary.all(context, deviceId)
        val activeLocalIds = allLocalEntries.map { it.id }.toSet()
        val localLiveIds = uniffi.padnote_core.syncLiveNotebooks(AccountSyncStore.indexJson(context)).map { it.id }.toSet()
        for (entry in allLocalEntries) {
            if (AccountSyncStore.isDeleted(context, entry.id) || !localLiveIds.contains(entry.id)) {
                AccountSyncStore.record(context, entry.id, entry.title, null, false)
            }
        }

        val meta = runOnce(context)
        if (meta == null) {
            SyncLogger.log("無法取得有效權杖，Google Drive 同步中止", SyncSource.GOOGLE_DRIVE)
            return FullResult(null, 0, 0, emptyList())
        }
        if (!meta.ok) {
            SyncLogger.log("中繼資料同步失敗：${meta.error}", SyncSource.GOOGLE_DRIVE)
            return FullResult(meta, 0, 0, emptyList())
        }

        // ── 同步前即時核實：本機現存 vs. 雲端索引差異樣態 ──────────────
        val dir = NotebookLibrary.directory(context)
        val deletedNotebookIds = AccountSyncStore.deletedNotebookIds(context).toMutableSet()
        val cloudLiveIds = uniffi.padnote_core.syncLiveNotebooks(meta.indexJson).map { it.id }.toSet()

        val allDiskPackages = dir.listFiles { file -> file.name.endsWith(".padnote") } ?: emptyArray()

        val validPackages = mutableListOf<File>()
        var cleanedCount = 0

        for (pkg in allDiskPackages) {
            val id = pkg.name.removeSuffix(".padnote")
            // 判定 1：本機現存活躍的筆記本擁有最高本機權威，納入雙軌同步排程（絕不刪除）
            if (activeLocalIds.contains(id)) {
                deletedNotebookIds.remove(id)
                validPackages.add(pkg)
                continue
            }
            // 判定 2：若為明確已刪除的筆記本（本機墓碑中），立即清理實體磁碟殘留套件
            if (deletedNotebookIds.contains(id)) {
                pkg.deleteRecursively()
                cleanedCount++
                continue
            }
            // 判定 3：若不在本機現存筆記中，且雲端也不再活躍，屬於孤立過期套件，清理實體檔案
            // 注意：絕不在此呼叫 recordDeletion 產生虛假雲端墓碑！磁碟清理僅為本地快取回收。
            if (!cloudLiveIds.contains(id)) {
                pkg.deleteRecursively()
                cleanedCount++
                continue
            }
        }

        SyncLogger.log("📊【同步前核實】本機現存: ${activeLocalIds.size} 本，清理/排除無效套件: $cleanedCount 本，待同步活躍筆記: ${validPackages.size} 本", SyncSource.GOOGLE_DRIVE)
        SyncLogger.log("雲端元資料同步完成，開始逐本比對套件檔案...", SyncSource.GOOGLE_DRIVE)

        var uploaded = 0
        var downloaded = 0
        val changed = mutableListOf<String>()

        // ── 雙軌排程：前台極速軌 + 背景並行佇列 ──────────────
        val foreground = validPackages.filter { it.name.removeSuffix(".padnote") == activeNotebookId }
        val background = validPackages.filter { it.name.removeSuffix(".padnote") != activeNotebookId }

        // 前台極速軌：優先、立即執行
        for (pkg in foreground) {
            val id = pkg.name.removeSuffix(".padnote")
            SyncLogger.log("⚡ 前台極速同步：$id", SyncSource.GOOGLE_DRIVE)
            val result = syncNotebook(context, id)
            if (result != null && result.ok) {
                uploaded += result.uploaded.toInt()
                downloaded += result.downloaded.toInt()
                if (result.downloaded > 0u) changed += id
            } else if (result != null) {
                SyncLogger.log("筆記本 $id 同步失敗：${result.error}", SyncSource.GOOGLE_DRIVE)
                if (result.needsReauth) {
                    GoogleAuth.signOutLocally(context)
                    break
                }
            }
        }

        // 背景並行佇列：分批（最多 4 路並發）執行
        val concurrencyLimit = 4
        var backgroundQueue = background
        while (backgroundQueue.isNotEmpty()) {
            val batch = backgroundQueue.take(concurrencyLimit)
            backgroundQueue = backgroundQueue.drop(batch.size)

            val batchResults = runBlocking(Dispatchers.IO) {
                batch.map { pkg ->
                    async {
                        val id = pkg.name.removeSuffix(".padnote")
                        val res = syncNotebook(context, id)
                        Triple(id, res, res?.error)
                    }
                }.awaitAll()
            }

            var shouldBreak = false
            for ((id, res, err) in batchResults) {
                if (res != null && res.ok) {
                    uploaded += res.uploaded.toInt()
                    downloaded += res.downloaded.toInt()
                    if (res.downloaded > 0u) changed += id
                } else if (err != null) {
                    SyncLogger.log("筆記本 $id 背景同步失敗：$err", SyncSource.GOOGLE_DRIVE)
                    if (res?.needsReauth == true) {
                        GoogleAuth.signOutLocally(context)
                        shouldBreak = true
                    }
                }
            }
            if (shouldBreak) break
        }

        // 別台裝置新建的筆記本整本抓下來（排除已被刪除的筆記本）
        val pulled = pullNewNotebooks(context, meta.indexJson, activeLocalIds, deletedNotebookIds)
        changed += pulled
        downloaded += pulled.size

        SyncLogger.log("步驟 2 完成。上傳: $uploaded, 下載: $downloaded, 新增: ${pulled.size}", SyncSource.GOOGLE_DRIVE)
        SyncLogger.log("【Google Drive 同步】全部完成。", SyncSource.GOOGLE_DRIVE)

        return FullResult(meta, uploaded, downloaded, changed)
    }

    /**
     * 把雲端有、本機還沒有的筆記本整本抓下來。回傳抓下來的那幾本的 id。
     *
     * 清單來自**合併後的索引**，不是本機那一份 —— 用本機的話，剛從雲端
     * 收斂進來的那幾本還不在裡面，永遠差一輪。
     */
    private fun pullNewNotebooks(
        context: Context,
        mergedIndexJson: String,
        activeLocalIds: Set<String> = emptySet(),
        deletedNotebookIds: Set<String> = emptySet()
    ): List<String> {
        val dir = NotebookLibrary.directory(context)
        val pulled = mutableListOf<String>()
        for (item in uniffi.padnote_core.syncLiveNotebooks(mergedIndexJson)) {
            if (deletedNotebookIds.contains(item.id)) continue
            val path = File(dir, "${item.id}.padnote")
            // 防禦性檢查：若本地存在該目錄，但本機尚未載入該筆記本，檢查是否為無 ops 的空殼目錄
            if (path.exists() && !activeLocalIds.contains(item.id)) {
                val opsDir = File(path, "doc/ops")
                val opFiles = opsDir.listFiles { f -> f.name.endsWith(".oplog") }
                if (opFiles == null || opFiles.isEmpty()) {
                    path.deleteRecursively()
                }
            }
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
