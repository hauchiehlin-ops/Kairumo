package com.kairumo.padnote.library

import android.content.Context
import com.kairumo.padnote.oauth.DriveHttpClient
import com.kairumo.padnote.oauth.GoogleAuth
import com.kairumo.padnote.sync.SyncLogger
import com.kairumo.padnote.sync.SyncSource
import java.io.File
import uniffi.padnote_core.FfiCloudSyncResult
import uniffi.padnote_core.notebookLockLeave
import uniffi.padnote_core.notebookLockTryEnter
import uniffi.padnote_core.syncGateLeave
import uniffi.padnote_core.syncGateTryEnter
import uniffi.padnote_core.syncLiveNotebooks
import uniffi.padnote_core.syncOrderActiveFirst

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
     * 同一行程內的同步入口佇列。核心閘負責互斥，這裡把「忙碌就丟掉」
     * 改成「等前一輪收尾」，讓自動、手動、Worker 與重置依序執行。
     * 呼叫端依契約都在 Dispatchers.IO／Worker，這裡不會阻塞 UI thread。
     */
    private fun acquireGate(label: String): uniffi.padnote_core.FfiSyncGrant? {
        val started = android.os.SystemClock.elapsedRealtime()
        while (!Thread.currentThread().isInterrupted) {
            val now = android.os.SystemClock.elapsedRealtime()
            val grant = syncGateTryEnter(label, now.toULong())
            if (grant.granted) return grant
            if (now - started >= 120_000L) return null
            Thread.sleep(150L)
        }
        return null
    }

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
     * 整個行程**共用一個**工作階段。
     *
     * 焦點通道（使用者開著的那一本，每秒輪詢）與整庫通道各自拿一個的話，就有兩份
     * 雲端快照、兩個變更游標，彼此不知道對方上傳過什麼：一邊剛建立的檔案，另一邊的
     * 快照裡沒有，於是又建立一次 —— Drive 允許同名檔案，結果是雲端多一份重複。
     * 共用一個，快照與游標就只有一份，核心裡的索引鎖同時把兩條通道對同一份快照的
     * 存取串起來。
     */
    private class Shared(
        val session: uniffi.padnote_core.FfiSyncSession,
        val http: DriveHttpClient,
        val account: String
    )

    private var shared: Shared? = null

    /**
     * 取得共用的工作階段。回傳 null 表示沒登入。
     *
     * 工作階段握著一份 `RemoteIndex`：一次 `changes.list` 更新它，
     * 之後「這本要不要碰」完全在本機算，一個位元組都不傳。
     *
     * 快照綁帳號：帳號不同就重建。
     *
     * **會阻塞網路 I/O（取權杖），要在背景執行緒呼叫。**
     */
    @Synchronized
    fun makeSession(context: Context): uniffi.padnote_core.FfiSyncSession? {
        val token = GoogleAuth.validAccessToken(context) ?: return null
        val account = AccountSyncStore.lastAccount(context)
        shared?.let {
            if (it.account == account) {
                it.http.updateAccessToken(token)
                return it.session
            }
        }
        val saved = AccountSyncStore.remoteIndexJson(context, account)
        val http = DriveHttpClient(token)
        val session = uniffi.padnote_core.FfiSyncSession.create(http, saved)
        shared = Shared(session, http, account)
        return session
    }

    /** 登出或換帳號之後丟掉共用的工作階段。 */
    @Synchronized
    fun invalidateSession() {
        shared = null
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
        val grant = acquireGate("android:wipe-cloud")
        if (grant == null) {
            SyncLogger.log(
                "【重置雲端】等待上一輪結束逾時，請稍後重試",
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
            syncGateLeave(grant.ticket)
        }
    }

    /**
     * **回收已刪除筆記本留在雲端的檔案。**
     *
     * 只刪「索引裡有墓碑」的那些。這台裝置還沒辨識的檔案絕不碰 —— 那多半
     * 是另一台剛建立、索引還沒拉到，刪掉等於吃掉別台剛寫的東西。
     *
     * 走互斥閘：回收到一半被另一輪同步插進來的話，兩邊會對同一批檔案一個
     * 刪一個傳。
     *
     * **會阻塞網路 I/O，要在背景執行緒呼叫。**
     */
    fun reclaimDeleted(context: Context): uniffi.padnote_core.FfiGcResult? {
        val grant = acquireGate("android:reclaim")
        if (grant == null) {
            SyncLogger.log(
                "【回收】等待上一輪結束逾時，請稍後重試",
                SyncSource.GOOGLE_DRIVE
            )
            return null
        }
        return try {
            val session = makeSession(context) ?: return null
            // 先把雲端的現況拉一次。拿舊快照去回收，等於照著一份可能過期的
            // 清單刪檔案。
            session.refresh()
            val result = session.collectGarbage(AccountSyncStore.indexJson(context))
            persist(context, session)
            SyncLogger.log(
                if (result.ok) "【回收】完成，刪除 ${result.deleted} 個檔案"
                else "【回收】刪除 ${result.deleted} 個，失敗 ${result.failed} 個：${result.error}",
                SyncSource.GOOGLE_DRIVE
            )
            result
        } finally {
            syncGateLeave(grant.ticket)
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
        val grant = acquireGate("android:google-drive")
        if (grant == null) {
            SyncLogger.log(
                "【Google Drive 同步】等待上一輪結束逾時，已保留待同步狀態",
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
            syncGateLeave(grant.ticket)
        }
    }

    private fun runFullBody(context: Context, deviceId: UInt, activeNotebookId: String? = null): FullResult {
        SyncLogger.log("【Google Drive 同步】開始執行", SyncSource.GOOGLE_DRIVE)
        SyncLogger.log("步驟 1：同步中繼資料與索引 (連線中)...", SyncSource.GOOGLE_DRIVE)

        // 舊版本機資料遷移：只補「索引從未見過」的套件。
        //
        // 這裡以前會把墓碑也重新 record 成存活，而且每次同步都用本機套件
        // 的舊標題產生一個更大的 Lamport 時戳。結果是：A 已刪除／改名，
        // B 晚一點開 App，就會憑空偽造一次較新的編輯，把 A 的結果覆蓋。
        // 真正的新增、改名與搬移入口本來就會 record；同步只能合併事件，
        // 不能把「本機還有舊檔」解讀成使用者剛做了一次編輯。
        val allLocalEntries = NotebookLibrary.all(context, deviceId)
        val activeLocalIds = allLocalEntries.map { it.id }.toSet()
        // (A) 從舊版本機條目補索引；明確墓碑絕不復活。
        for (entry in allLocalEntries) {
            if (AccountSyncStore.item(context, entry.id) == null) {
                AccountSyncStore.record(context, entry.id, entry.title, null, false)
            }
        }
        // (B) 磁碟上能開不起來的舊套件也只在索引未知時補；已刪除仍不碰。
        val packagesDir = NotebookLibrary.directory(context)
        val diskPackageIds = packagesDir.listFiles { f -> f.name.endsWith(".padnote") }
            ?.map { it.name.removeSuffix(".padnote") }?.toSet() ?: emptySet()
        for (diskId in diskPackageIds) {
            if (AccountSyncStore.item(context, diskId) == null) {
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
        val cloudLiveIds = syncLiveNotebooks(meta.indexJson).map { it.id }.toSet()

        // 🌟 先把別台裝置新建、本機還沒有的筆記本整本抓下來
        val pulled = pullNewNotebooks(context, session, meta.indexJson, activeLocalIds, deletedNotebookIds)
        val changed = mutableListOf<String>()
        changed += pulled
        var downloaded = pulled.size

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

        // 前台作用中的那一本排最前面：使用者正在看的內容要先到。
        // 規則用核心那一份，與 Apple 同一套（各寫一份的話，使用者感覺到的
        // 不是「策略不同」，是「Android 比較慢」）。
        val orderedIds = syncOrderActiveFirst(
            pending.map { it.name.removeSuffix(".padnote") },
            activeNotebookId
        )
        val byId = pending.associateBy { it.name.removeSuffix(".padnote") }
        val ordered = orderedIds.mapNotNull { byId[it] }

        for (pkg in ordered) {
            val id = pkg.name.removeSuffix(".padnote")
            // 焦點通道正在處理這一本（它自己會推、拉）：略過，不要兩條通道同時
            // 動同一個套件目錄。同步是冪等的，這一本下一輪再看沒有任何代價。
            val lock = notebookLockTryEnter(id, "full-sync", android.os.SystemClock.elapsedRealtime().toULong())
            if (!lock.granted) continue
            val result = try {
                runCatching { session.syncNotebook(pkg.absolutePath, id, deviceId) }.getOrNull()
            } finally {
                notebookLockLeave(id, lock.ticket)
            }
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
        for (item in syncLiveNotebooks(mergedIndexJson)) {
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
