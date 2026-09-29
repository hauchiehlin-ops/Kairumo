package com.kairumo.padnote.sync

import android.content.Context
import android.os.SystemClock
import com.kairumo.padnote.library.AccountSyncStore
import com.kairumo.padnote.library.CloudSync
import com.kairumo.padnote.oauth.GoogleAuth
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import uniffi.padnote_core.FfiFocusLane
import uniffi.padnote_core.FfiFocusOutcome
import uniffi.padnote_core.FfiFocusRun
import uniffi.padnote_core.FfiSyncTrigger
import uniffi.padnote_core.notebookLockLeave
import uniffi.padnote_core.notebookLockTryEnter
import uniffi.padnote_core.syncGateHolder

/**
 * 秒同步：**焦點通道**與**區網直連**（Android）。
 *
 * # 為什麼有第二條通道
 *
 * [AutoSync] 排的是整庫一輪：中繼資料、changes.list、逐本同步、垃圾回收。
 * 成本跟筆記本數量成正比，而且一輪跑完才跑下一輪，所以「改一個字要多久才到
 * 另一台」取決於整個資料庫有多大 —— 把輪詢週期調短只會讓整輪更常空跑。
 *
 * 使用者感覺到慢的場景，幾乎都是**兩台裝置同時開著同一本筆記**。所以這裡另開
 * 一條窄通道，只服務「現在開著的那一本」：
 *
 * - 一筆畫完（`onContentCommitted`，oplog 已經寫進套件）→ 0.25 秒去抖動 → 推
 * - 每秒問一次雲端（一個 changes.list），有變才拉這一本
 * - 區網上有另一台同帳號的裝置時，套件一寫好就**直接**傳給它，不等 Drive
 *
 * 節奏在核心的 [FfiFocusLane]，Apple 端用同一個 —— 兩邊各寫一份的話，
 * 使用者看到的不是「策略不同」，是「Android 比較慢」。
 *
 * # 與整庫通道的關係
 *
 * 共用同一份雲端快照（[CloudSync.makeSession] 整個行程只有一個）與同一份資料格式，
 * **不共用任何排程狀態**。兩條通道只在「同一本筆記本的套件目錄」上會撞在一起，
 * 所以核心有一把每本一把的鎖（`notebookLockTryEnter`）：整庫通道遇到焦點通道拿著
 * 的那一本就略過（同步是冪等的，下一輪再看）。
 *
 * # 時間用單調時鐘
 *
 * 與 [AutoSync] 相同：[SystemClock.elapsedRealtime]。
 */
object FocusSync {

    private val lane = FfiFocusLane.create()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var wake: Job? = null
    private var appContext: Context? = null
    private var deviceId: UInt = 0u
    private var link: LanLink? = null
    @Volatile private var lanStarting = false
    private var lastPersistMs = 0L

    /** 目前有幾台區網對端直連中。 */
    private val _lanPeers = MutableStateFlow(0)
    val lanPeers: StateFlow<Int> = _lanPeers

    /** 最近一次**有工作**的一輪的總耗時（毫秒）。給同步醫生看。 */
    private val _lastWorkRoundMs = MutableStateFlow(0L)
    val lastWorkRoundMs: StateFlow<Long> = _lastWorkRoundMs

    /**
     * 某一本筆記本的內容被別台裝置（Drive 或區網）改了。
     *
     * 編輯器據此重開 session：oplog 檔已經寫進套件，但記憶體裡那份還是同步前的
     * 狀態，畫面上看不到任何變化，使用者會以為同步沒作用。
     * [serial] 遞增，同一本連續變動也會各觸發一次。
     */
    data class RemoteChange(val notebookId: String, val serial: Long)

    private val _remoteChange = MutableStateFlow(RemoteChange("", 0L))
    val remoteChange: StateFlow<RemoteChange> = _remoteChange

    private fun nowMs(): ULong = SystemClock.elapsedRealtime().toULong()

    /** App 啟動時呼叫一次（[AutoSync.start] 之後）。 */
    @Synchronized
    fun start(context: Context, deviceId: UInt) {
        this.deviceId = deviceId
        appContext = context.applicationContext
    }

    /** 打開／離開一本筆記時呼叫。`null` = 回到首頁。 */
    fun setFocus(notebookId: String?) {
        lane.setFocus(notebookId, nowMs())
        link?.setFocused(notebookId)
        reschedule()
        if (notebookId != null) ensureLan()
    }

    /** 焦點筆記本存檔完成。Android 每一筆都直接寫 oplog，所以這時候套件已經是最新的。 */
    fun noteLocalEdit() {
        lane.noteLocalEdit(nowMs())
        reschedule()
    }

    fun noteSignedIn() {
        lane.noteSignedIn(nowMs())
        reschedule()
        ensureLan()
    }

    /** 回到前景：立刻問一次，並確保區網節點在。 */
    fun onForeground() {
        lane.noteRemoteHint(nowMs())
        reschedule()
        ensureLan()
    }

    /** 進背景：收掉區網節點（系統會限制背景的 socket 與 mDNS，留著只是耗電）。 */
    fun onBackground() {
        stopLan()
    }

    // ── 排程 ─────────────────────────────────────────────────

    /**
     * 排一次「到點再問」。每次事件之後、每輪結束之後都重排，舊的那個作廢。
     *
     * 不用固定週期的計時器：沒有焦點筆記本時完全不醒來，有的時候則精確地睡到
     * 下一個該動的時間點。
     */
    @Synchronized
    private fun reschedule() {
        wake?.cancel()
        val due = lane.nextDueInMs(nowMs())
        if (due == ULong.MAX_VALUE) return
        wake = scope.launch {
            delay(due.toLong())
            pump()
        }
    }

    private fun pump() {
        val context = appContext ?: return
        val run = lane.poll(nowMs())
        if (run == null) {
            reschedule()
            return
        }
        scope.launch {
            val outcome = withContext(Dispatchers.IO) {
                runCatching { runRound(context, run) }.getOrDefault(FfiFocusOutcome.TRANSIENT)
            }
            lane.finish(run.notebookId, outcome, nowMs())
            reschedule()
        }
    }

    private fun runRound(context: Context, run: FfiFocusRun): FfiFocusOutcome {
        if (!GoogleAuth.isSignedIn(context)) return FfiFocusOutcome.NEEDS_REAUTH
        // 重置雲端／回收正在動整個雲端：這時候推東西上去只會被它們半途蓋掉。
        val holder = syncGateHolder()
        if (holder.contains("wipe-cloud") || holder.contains("reclaim")) return FfiFocusOutcome.BUSY
        val session = CloudSync.makeSession(context) ?: return FfiFocusOutcome.NEEDS_REAUTH
        val id = run.notebookId
        val lock = notebookLockTryEnter(id, "focus", nowMs())
        if (!lock.granted) return FfiFocusOutcome.BUSY
        try {
            val pkg = LanLink.findPackage(context, id) ?: return FfiFocusOutcome.SUCCESS
            // 有寫入就先通知區網對端 —— 不必等 Drive 那一趟。
            if (run.push) link?.announce(id)

            val started = SystemClock.elapsedRealtime()
            val round = session.focusRound(pkg.absolutePath, id, deviceId)
            val elapsed = SystemClock.elapsedRealtime() - started

            if (!round.ok) {
                SyncLogger.log(
                    "【焦點同步】${id.take(8)}… 失敗：${round.error}",
                    SyncSource.GOOGLE_DRIVE
                )
                if (round.needsReauth) {
                    GoogleAuth.signOutLocally(context)
                    return FfiFocusOutcome.NEEDS_REAUTH
                }
                return FfiFocusOutcome.TRANSIENT
            }

            if (round.hadWork || round.downloaded > 0u || round.uploaded > 0u) {
                // 量出來才知道慢在哪：只有真的做了事的那幾輪才寫，
                // 閒置輪詢每秒一次不能洗版。
                _lastWorkRoundMs.value = elapsed
                SyncLogger.log(
                    "【焦點同步】${id.take(8)}… 上傳 ${round.uploaded}、下載 ${round.downloaded}（雲端 ${elapsed}ms）",
                    SyncSource.GOOGLE_DRIVE
                )
                for (warning in round.warnings) {
                    SyncLogger.log("【焦點同步】${id.take(8)}… $warning", SyncSource.GOOGLE_DRIVE)
                }
                // 快照落地，但不要每輪都存 —— 它可能有幾千筆，序列化不便宜。
                val now = SystemClock.elapsedRealtime()
                if (now - lastPersistMs > 15_000L) {
                    lastPersistMs = now
                    CloudSync.persist(context, session)
                }
            }

            if (round.downloaded > 0u) {
                publishRemote(id)
                AutoSync.noteRemoteActivity()
                return FfiFocusOutcome.PULLED
            }
            // 雲端有**別的**東西動了（別本筆記、索引）而這一本沒事：叫整庫通道去看。
            // 用 `remoteChanges`（快照真的改變的）而不是原始變更數 —— 自己剛上傳的
            // 檔案也會出現在 changes.list，不能因為它就叫醒整庫。
            if (round.remoteChanges > 0u && !round.hadWork) {
                AutoSync.request(context, FfiSyncTrigger.PERIODIC)
            }
            return FfiFocusOutcome.SUCCESS
        } finally {
            notebookLockLeave(id, lock.ticket)
        }
    }

    /** 通知編輯器與首頁：這一本的內容變了。 */
    internal fun publishRemote(notebookId: String) {
        _remoteChange.value = RemoteChange(notebookId, _remoteChange.value.serial + 1)
        AutoSync.publishChanged(listOf(notebookId))
    }

    // ── 區網直連 ─────────────────────────────────────────────

    /**
     * 已登入、App 在前景時建立區網節點。**失敗一律安靜略過** ——
     * 區網是加法，沒有它 Drive 那條路照常運作。
     */
    private fun ensureLan() {
        val context = appContext ?: return
        if (link != null || lanStarting) return
        lanStarting = true
        scope.launch(Dispatchers.IO) {
            try {
                if (!GoogleAuth.isSignedIn(context)) return@launch
                val account = AccountSyncStore.lastAccount(context).ifEmpty { "default" }

                // 金鑰以雲端為準：兩台裝置同時第一次建立時可能各握著不同的一把，
                // 而握手失敗是靜默的。每次啟動讀一次（一個 GET）就會收斂。
                var key: ByteArray? = null
                CloudSync.makeSession(context)?.let { session ->
                    val result = session.lanKey()
                    if (result.ok) key = result.key
                }
                val fresh = key
                if (fresh != null) {
                    GoogleAuth.saveLanKey(context, account, fresh)
                } else {
                    key = GoogleAuth.loadLanKey(context, account)
                }
                val finalKey = key ?: return@launch
                val created = LanLink(context, finalKey, deviceId)
                created.setFocused(lane.focused())
                synchronized(this@FocusSync) {
                    if (link == null) link = created else { created.stop(); return@launch }
                }
                created.start()
            } catch (t: Throwable) {
                SyncLogger.log("【區網直連】啟動失敗：${t.message}", SyncSource.GOOGLE_DRIVE)
            } finally {
                lanStarting = false
            }
        }
    }

    private fun stopLan() {
        val current = synchronized(this) { link.also { link = null } }
        current?.stop()
        _lanPeers.value = 0
    }

    internal fun lanPeersChanged(count: Int) {
        _lanPeers.value = count
        if (count > 0) {
            SyncLogger.log("【區網直連】已連上 $count 台裝置", SyncSource.GOOGLE_DRIVE)
        }
    }

    /**
     * 區網對端把新檔案寫進了套件。Android 的套件就是工作資料，沒有匯入這一步 ——
     * 只要通知編輯器重開 session。
     */
    internal fun lanReceived(notebookId: String) {
        SyncLogger.log("【區網直連】${notebookId.take(8)}… 收到對端的更新", SyncSource.GOOGLE_DRIVE)
        publishRemote(notebookId)
        AutoSync.noteRemoteActivity()
    }
}
