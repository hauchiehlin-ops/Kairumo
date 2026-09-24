package com.kairumo.padnote.library

import android.content.Context
import com.kairumo.padnote.oauth.DriveHttpClient
import com.kairumo.padnote.oauth.GoogleAuth
import com.kairumo.padnote.sync.SyncLogger
import com.kairumo.padnote.sync.SyncSource
import java.io.File
import uniffi.padnote_core.FfiCloudSyncResult

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
            ?.also { AccountSyncStore.setLastAccount(context, it) }
    }.getOrNull()

    // ── P1：帶著雲端快照的工作階段 ────────────────────────────────

    /**
     * 開一輪同步。回傳 null 表示沒登入。
     *
     * 工作階段握著一份 `RemoteIndex`：一次 `changes.list` 更新它，
     * 之後「這本要不要碰」完全在本機算，一個位元組都不傳。
     *
     * **會阻塞網路 I/O（取權杖），要在背景執行緒呼叫。**
     */
    fun makeSession(context: Context): uniffi.padnote_core.FfiSyncSession? {
        val token = GoogleAuth.validAccessToken(context) ?: return null
        val account = AccountSyncStore.lastAccount(context)
        val saved = AccountSyncStore.remoteIndexJson(context, account)
        return uniffi.padnote_core.FfiSyncSession.create(DriveHttpClient(token), saved)
    }

    /**
     * **把這個帳號在雲端的同步資料整個刪掉。**
     *
     * 不可逆：只存在雲端的內容會一起消失。呼叫端必須先讓使用者確認。
     *
     * 為什麼要做在 App 裡：資料存在 Drive 的 `appDataFolder`，那是隱藏區
     * —— 使用者在 drive.google.com 的檔案列表裡看不到也刪不掉。唯一的手動
     * 路徑是 Drive 設定 →「管理應用程式」→「刪除隱藏的應用程式資料」，
     * 而那條路徑**只清雲端**：本機還留著一份「雲端有這些檔案」的快照，
     * 下一輪同步會拿著幻覺去比對。
     *
     * 走互斥閘 —— 清到一半被另一輪同步插進來重新上傳的話，留下的是一個
     * 半清空的雲端，比原本的狀態更難解釋。
     *
     * **會阻塞網路 I/O，要在背景執行緒呼叫。**
     *
     * @return 結果；`null` 表示沒登入或有一輪同步正在跑。
     */
    fun wipeCloud(context: Context): uniffi.padnote_core.FfiWipeResult? {
        val nowMs = android.os.SystemClock.elapsedRealtime().toULong()
        val grant = uniffi.padnote_core.syncGateTryEnter("android:wipe-cloud", nowMs)
        if (!grant.granted) {
            SyncLogger.log(
                "【重置雲端】有一輪同步正在跑（${grant.holder}）—— 等它結束再試",
                SyncSource.GOOGLE_DRIVE
            )
            return null
        }
        return try {
            val session = makeSession(context) ?: return null
            SyncLogger.log("【重置雲端】開始刪除雲端資料…", SyncSource.GOOGLE_DRIVE)
            val result = session.wipeCloud()
            // 快照已經在核心裡歸零，這裡把歸零後的它存回磁碟 —— 不存的話
            // 下次開 App 會從磁碟讀回舊快照，等於沒清。
            persist(context, session)
            SyncLogger.log(
                if (result.ok) "【重置雲端】完成，刪除 ${result.deleted} 個檔案"
                else "【重置雲端】刪除 ${result.deleted} 個，失敗 ${result.failed} 個：${result.error}",
                SyncSource.GOOGLE_DRIVE
            )
            result
        } finally {
            uniffi.padnote_core.syncGateLeave(grant.ticket)
        }
    }

    /** 把工作階段的快照存回磁碟。**每輪同步結束都要做。** */
    fun persist(context: Context, session: uniffi.padnote_core.FfiSyncSession) {
        AccountSyncStore.saveRemoteIndexJson(
            context, session.indexJson(), AccountSyncStore.lastAccount(context)
        )
    }

    /**
     * 中繼資料（設定、筆記本清單、刪除墓碑）。
     *
     * **會阻塞網路 I/O，要在背景執行緒呼叫。**
     */
    fun syncMetadata(
        context: Context,
        session: uniffi.padnote_core.FfiSyncSession
    ): FfiCloudSyncResult? {
        val result = session.syncMetadata(
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
     * 只同步中繼資料的一輪（給不需要碰內容的呼叫端）。
     *
     * **會阻塞網路 I/O，要在背景執行緒呼叫。** 回傳 null 表示沒登入。
     */

    /**
     * 同步一本筆記本的內容與媒體。**會阻塞網路 I/O，要在背景執行緒呼叫。**
     *
     * 回傳 `downloaded > 0` 時，**呼叫端必須重開這本筆記的 session** ——
     * oplog 檔已經寫進套件，但記憶體裡那份還是同步前的狀態，
     * 畫面上看不到任何變化，使用者會以為同步沒作用。
     */
    fun syncNotebook(
        context: Context,
        notebookId: String,
        deviceId: UInt = 0u
    ): uniffi.padnote_core.FfiNotebookSyncResult? {
        val path = File(NotebookLibrary.directory(context), "$notebookId.padnote")
        if (!path.exists()) return null
        val session = makeSession(context) ?: return null
        val result = session.syncNotebook(path.absolutePath, notebookId, deviceId)
        persist(context, session)
        return result
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
        val changed: List<String>,
        /**
         * 這一輪**根本沒跑** —— 已經有另一輪在進行中。
         *
         * 跟「跑了但沒事做」要分得開：都說「同步完成」的話，使用者按下
         * 「立即同步」看到完成，會以為雲端真的比對過了。
         */
        val skipped: Boolean = false
    )

    /**
     * 跑一輪完整同步。**整個行程同一時間只准一輪。**
     *
     * 入口有四個（自動同步、`SyncWorker`、兩顆手動），原本彼此不認識，
     * 於是自動同步在跑的時候按下「立即同步」，兩輪就並行了。併發的症狀
     * 完全不像併發：
     *
     * * 「找不到：/upload/drive/v3/files/…」—— 兩輪各自為同一本筆記開了
     *   可續傳上傳工作階段，先完成的那一輪把檔案換掉，另一輪手上的網址
     *   就失效了。看起來像 Drive 弄丟檔案。
     * * 「blob … 下載後雜湊不符」—— 一輪在下載，另一輪同時把同名的 blob
     *   換掉。看起來像傳輸損毀。
     *
     * 鎖在核心（`syncGateTryEnter`／`syncGateLeave`），與 Apple 共用同一把。
     */
    fun runFull(context: Context, deviceId: UInt, activeNotebookId: String? = null): FullResult {
        // 單調時鐘：牆上時鐘跳一下會讓「拿著多久」算錯，於是不是永遠不
        // 接手，就是立刻把正在跑的那輪踢掉。
        val nowMs = android.os.SystemClock.elapsedRealtime().toULong()
        val grant = uniffi.padnote_core.syncGateTryEnter("android:google-drive", nowMs)
        if (!grant.granted) {
            SyncLogger.log(
                "【Google Drive 同步】已有一輪在跑（${grant.holder}，${grant.heldMs / 1000u} 秒）—— 這次跳過",
                SyncSource.GOOGLE_DRIVE
            )
            return FullResult(null, 0, 0, emptyList(), skipped = true)
        }
        if (grant.tookOver) {
            SyncLogger.log(
                "【Google Drive 同步】上一輪（${grant.holder}）卡了 ${grant.heldMs / 1000u} 秒沒收尾，接手",
                SyncSource.GOOGLE_DRIVE
            )
        }
        return try {
            runFullBody(context, deviceId, activeNotebookId)
        } finally {
            uniffi.padnote_core.syncGateLeave(grant.ticket)
        }
    }

    private fun runFullBody(context: Context, deviceId: UInt, activeNotebookId: String? = null): FullResult {
        SyncLogger.log("【Google Drive 同步】開始執行", SyncSource.GOOGLE_DRIVE)
        SyncLogger.log("步驟 1：同步中繼資料與索引 (連線中)...", SyncSource.GOOGLE_DRIVE)

        // 【RC-5 根治版】復活迴圈：掃「所有本機條目 + 磁碟套件目錄」，
        // 而非僅掃 activeLocalIds（它可能因 tombstone 而不含被誤刪的筆記本）。
        val allLocalEntries = NotebookLibrary.all(context, deviceId)
        val activeLocalIds = allLocalEntries.map { it.id }.toSet()
        val localLiveIds = uniffi.padnote_core.syncLiveNotebooks(AccountSyncStore.indexJson(context)).map { it.id }.toSet()
        // (A) 從本機條目全集復活
        for (entry in allLocalEntries) {
            if (AccountSyncStore.isDeleted(context, entry.id) || !localLiveIds.contains(entry.id)) {
                AccountSyncStore.record(context, entry.id, entry.title, null, false)
            }
        }
        // (B) 從磁碟套件目錄再掃一遍：有套件但被 tombstone 的也要復活
        val packagesDir = NotebookLibrary.directory(context)
        val diskPackageIds = packagesDir.listFiles { f -> f.name.endsWith(".padnote") }
            ?.map { it.name.removeSuffix(".padnote") }?.toSet() ?: emptySet()
        for (diskId in diskPackageIds) {
            if (AccountSyncStore.isDeleted(context, diskId) || !localLiveIds.contains(diskId)) {
                val title = allLocalEntries.firstOrNull { it.id == diskId }?.title ?: diskId
                AccountSyncStore.record(context, diskId, title, null, false)
            }
        }

        // ── 一次 changes.list，然後只碰真的有差異的筆記本 ──────────
        //
        // 舊流程是「每一本筆記都打一次 files.list」——20 本筆記 20 次往返，
        // 而其中 19 次的答案是「沒事」。使用者要的「沒變動的就不要花時間
        // 去動它」在那個結構下做不到：要知道有沒有變動就得先問，
        // 而問本身就是主要成本。
        val session = makeSession(context)
        if (session == null) {
            SyncLogger.log("無法取得有效權杖，Google Drive 同步中止", SyncSource.GOOGLE_DRIVE)
            return FullResult(null, 0, 0, emptyList())
        }
        val refreshed = session.refresh()
        if (!refreshed.ok) {
            SyncLogger.log("雲端快照更新失敗：${refreshed.error}", SyncSource.GOOGLE_DRIVE)
            if (refreshed.needsReauth) GoogleAuth.signOutLocally(context)
            return FullResult(null, 0, 0, emptyList())
        }
        SyncLogger.log(
            if (refreshed.fullRebuild) {
                "雲端快照重建完成（${refreshed.trackedFiles} 個檔案）"
            } else {
                "雲端變動 ${refreshed.changed} 筆，快照共 ${refreshed.trackedFiles} 個檔案"
            },
            SyncSource.GOOGLE_DRIVE
        )

        val meta = syncMetadata(context, session)
        if (meta == null) {
            SyncLogger.log("無法取得有效權杖，Google Drive 同步中止", SyncSource.GOOGLE_DRIVE)
            persist(context, session)
            return FullResult(null, 0, 0, emptyList())
        }
        if (!meta.ok) {
            SyncLogger.log("中繼資料同步失敗：${meta.error}", SyncSource.GOOGLE_DRIVE)
            persist(context, session)
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
            // 判定 1：本機現存活躍的筆記本擁有最高本機權威（絕不刪除）
            if (activeLocalIds.contains(id)) {
                deletedNotebookIds.remove(id)
                validPackages.add(pkg)
                continue
            }
            // 判定 2：明確已刪除（本機墓碑中）⇒ 清理磁碟殘留
            // 判定 3：本機沒有、雲端也不再活躍 ⇒ 孤立過期套件
            // 注意：絕不在此呼叫 recordDeletion 產生虛假雲端墓碑！
            if (deletedNotebookIds.contains(id) || !cloudLiveIds.contains(id)) {
                pkg.deleteRecursively()
                cleanedCount++
            }
        }

        // 只碰真的有差異的那幾本。**這一行是整個改善的重點。**
        val pending = validPackages.filter {
            session.notebookNeedsSync(it.absolutePath, it.name.removeSuffix(".padnote"))
        }
        SyncLogger.log(
            "📊【同步前核實】本機 ${activeLocalIds.size} 本，清理 $cleanedCount 本，" +
                "有差異待同步 ${pending.size} 本（跳過 ${validPackages.size - pending.size} 本）",
            SyncSource.GOOGLE_DRIVE
        )

        var uploaded = 0
        var downloaded = 0
        val changed = mutableListOf<String>()

        // 前台作用中的那一本排最前面：使用者正在看的內容要先到。
        val ordered = pending.sortedBy { it.name.removeSuffix(".padnote") != activeNotebookId }

        for (pkg in ordered) {
            val id = pkg.name.removeSuffix(".padnote")
            val result = runCatching {
                session.syncNotebook(pkg.absolutePath, id, deviceId)
            }.getOrNull()
            if (result == null) {
                SyncLogger.log("筆記本 $id 同步中斷", SyncSource.GOOGLE_DRIVE)
                continue
            }
            if (result.ok) {
                uploaded += result.uploaded.toInt()
                downloaded += result.downloaded.toInt()
                if (result.downloaded > 0u) changed += id
                // 不致命但要看得見：例如雲端上一個壞掉的 blob。悄悄吞掉的話，
                // 使用者會發現某張圖永遠出不來而查不出原因。
                for (warning in result.warnings) {
                    SyncLogger.log("筆記本 $id $warning", SyncSource.GOOGLE_DRIVE)
                }
            } else {
                SyncLogger.log("筆記本 $id 同步失敗：${result.error}", SyncSource.GOOGLE_DRIVE)
                if (result.needsReauth) {
                    GoogleAuth.signOutLocally(context)
                    break
                }
            }
        }

        // 別台裝置新建的筆記本整本抓下來（排除已被刪除的筆記本）
        val pulled = pullNewNotebooks(context, session, meta.indexJson, activeLocalIds, deletedNotebookIds)
        changed += pulled
        downloaded += pulled.size

        // 快照要落地。不存的話，下次開 App 又要全量重建一次 ——
        // 那是唯一的慢路徑，不該每次啟動都走。
        persist(context, session)
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
        session: uniffi.padnote_core.FfiSyncSession,
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
            SyncLogger.log("發現新筆記「${item.title}」(${item.id})，開始自雲端下載...", SyncSource.GOOGLE_DRIVE)
            val result = session.cloneNotebook(
                path.absolutePath,
                item.id,
                item.title,
                System.currentTimeMillis().toULong()
            )
            if (result.ok) {
                pulled += item.id
                SyncLogger.log("筆記本「${item.title}」成功自雲端下載完成", SyncSource.GOOGLE_DRIVE)
            } else {
                SyncLogger.log("筆記本「${item.title}」自雲端下載失敗：${result.error}", SyncSource.GOOGLE_DRIVE)
                // 抓失敗時把空殼刪掉。留著的話，下一輪 `path.exists()` 為真，
                // 這本就再也不會被重抓 —— 使用者會看到一本永遠打不開的空筆記。
                path.deleteRecursively()
                if (result.needsReauth) break
            }
        }
        return pulled
    }
}
