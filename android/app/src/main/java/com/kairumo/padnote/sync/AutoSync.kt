package com.kairumo.padnote.sync

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.SystemClock
import com.kairumo.padnote.library.CloudSync
import com.kairumo.padnote.library.SyncHistory
import com.kairumo.padnote.oauth.GoogleAuth
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import uniffi.padnote_core.FfiSyncOutcome
import uniffi.padnote_core.FfiSyncScheduler
import uniffi.padnote_core.FfiSyncTrigger
import uniffi.padnote_core.syncHeartbeatIntervalMs

/**
 * 自動同步的觸發器（P2，Android）。
 *
 * # 之前缺的是什麼
 *
 * 同步流程本身早就寫好了，但觸發點只有「回到首頁」與選單裡那顆按鈕。
 * 使用者在編輯器裡寫完一段、切到 iPad 打開，看到的是舊內容 ——
 * 不是同步壞了，是根本沒有跑。
 *
 * 「即時」不是把間隔調短，是**事件驅動**：
 *
 * - 進前景、登入完成、網路恢復 → 立刻跑
 * - 本機存檔 → 去抖動 1.5 秒（使用者還在寫字時每一筆都推只是浪費電，
 *   而且會拖慢正在編輯的那一本）
 * - 前景時每 60 秒整庫同步一次；**一輪週期同步發現與上一輪相比沒有變動，
 *   就停止週期同步**，直到下一個事件（進前景、存檔、登入、網路恢復、
 *   別的通道收到對方的東西）。開著的那一本走焦點通道，不靠這一檔
 *
 * # 策略不在這裡
 *
 * 去抖動多久、退避多久、同時能跑幾個、暫時性錯誤與要重新登入怎麼分 ——
 * 全部在核心的 [FfiSyncScheduler]，Apple 端用的是同一個物件。
 * 兩邊各寫一份的話，使用者看到的不是「排程策略不同」，是「Android 比較慢」。
 *
 * # 時間用單調時鐘
 *
 * 餵給排程器的是 [SystemClock.elapsedRealtime]，不是 `System.currentTimeMillis`。
 * 使用者改時區或系統校時會讓牆上時間往前或往後跳，排程會因此卡住或暴衝。
 */
object AutoSync {

    private val scheduler = FfiSyncScheduler.create()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val runLock = Mutex()

    private val _isSyncing = MutableStateFlow(false)
    val isSyncing: StateFlow<Boolean> = _isSyncing

    private val _needsSignIn = MutableStateFlow(false)
    val needsSignIn: StateFlow<Boolean> = _needsSignIn

    /** 這一輪有變動的筆記本 id。首頁據此重讀清單。 */
    private val _changedNotebooks = MutableStateFlow<List<String>>(emptyList())
    val changedNotebooks: StateFlow<List<String>> = _changedNotebooks

    private var started = false

    private var appContext: Context? = null
    private var heartbeatJob: Job? = null

    /**
     * 最近一輪有沒有上傳、下載或新增東西。排程器據此決定要不要「安靜下來」
     * （週期觸發的一輪沒有變動 → 不再排下一個週期）。不知道時當作有變動。
     */
    @Volatile
    private var roundChanged = true

    /**
     * 使用者現在打開的那一本。**自動同步靠它決定先做哪一本。**
     *
     * 在這之前只有編輯器裡的「立即同步」會傳作用中的 id，自動同步那條
     * 完全沒傳 —— 於是最該即時的那條路徑（背景自動 + 正在編輯）反而排在
     * 隨意的順序裡。使用者在另一台寫的那一行，可能要等前面十九本都傳完。
     *
     * `@Volatile`：寫的是主執行緒（畫面），讀的是同步的背景執行緒。
     */
    @Volatile
    var activeNotebookId: String? = null
    private var deviceId: UInt = 0u
    private var wasOnline = true

    private fun nowMs(): ULong = SystemClock.elapsedRealtime().toULong()

    /** 背景 worker 拿不到 Activity，只好跟這裡要 device id。 */
    fun currentDeviceId(): UInt = deviceId

    /** App 啟動時呼叫一次。 */
    @Synchronized
    fun start(context: Context, deviceId: UInt) {
        this.deviceId = deviceId
        // 焦點通道與區網直連（秒同步）。整庫這條通道照舊，兩者互不依賴。
        FocusSync.start(context, deviceId)
        if (started) return
        started = true
        val app = context.applicationContext

        // 登入完成 → 立刻同步。原本沒有這個觸發：Android 登入之後要等下一次心跳，
        // 而心跳只在有變動時才快。
        scope.launch {
            GoogleAuth.authState.collect { signedIn ->
                if (signedIn) {
                    request(app, FfiSyncTrigger.SIGNED_IN)
                    FocusSync.noteSignedIn()
                }
            }
        }

        // 前景心跳。間隔由核心給 —— 兩個平台照同一個數字。
        //
        // 心跳只是「問一下」，不是輪詢頻率：真正的節奏是核心的 60 秒週期，
        // 而且週期同步沒有變動就會安靜下來（見 `finishRound`）。
        // 心跳夠密，60 秒才不會實際變成 60～120 秒。
        appContext = app
        startHeartbeat(app)

        watchNetwork(app)
        // 背景保底：App 被收掉之後，前景的心跳也跟著停。
        SyncWorker.schedule(app)
        request(app, FfiSyncTrigger.FOREGROUND)
    }

    /** 啟動前景心跳（已經在跑就什麼也不做）。 */
    @Synchronized
    private fun startHeartbeat(app: Context) {
        if (heartbeatJob?.isActive == true) return
        heartbeatJob = scope.launch {
            val interval = syncHeartbeatIntervalMs().toLong()
            while (true) {
                delay(interval)
                scheduler.tick(nowMs())
                pump(app)
            }
        }
    }

    /**
     * 排程器休眠了（安靜之後連續兩次 8 分鐘守望掃描都沒有變化）：停掉心跳與背景 worker。
     * **不結束 App** —— 「同步沒有變化」不代表使用者沒在用。下一個事件會叫醒（見 [wake]）。
     */
    @Synchronized
    private fun sleepSyncServices(app: Context) {
        heartbeatJob?.cancel()
        heartbeatJob = null
        SyncWorker.cancel(app)
    }

    /** 事件把休眠的同步服務叫醒：心跳與背景 worker 都重新開始。 */
    @Synchronized
    private fun wake(app: Context) {
        if (!started || heartbeatJob?.isActive == true) return
        startHeartbeat(app)
        SyncWorker.schedule(app)
    }

    /** 送一個觸發事件進排程器。 */
    fun request(context: Context, trigger: FfiSyncTrigger) {
        val app = context.applicationContext
        scheduler.request(trigger, nowMs())
        wake(app)
        _needsSignIn.value = scheduler.isBlockedOnAuth()
        scope.launch {
            // 去抖動的觸發不會立刻起跑，所以要排一次「到點再問」。
            val due = scheduler.nextDueInMs(nowMs())
            if (due != ULong.MAX_VALUE && due > 0u) delay(due.toLong())
            pump(app)
        }
    }

    /** 本機存檔之後呼叫。**會去抖動**，連續存檔只會推一次。 */
    fun noteLocalEdit(context: Context) {
        request(context, FfiSyncTrigger.LOCAL_EDIT)
        // 開著的那一本走焦點通道，不必等整庫這一輪。
        FocusSync.noteLocalEdit()
    }

    /**
     * 焦點通道或區網直連**真的收到了對方的東西**。對方在動 ——
     * 整庫通道若已安靜下來，要重新開始，其他筆記本的變動才不會等不到。
     */
    fun noteRemoteActivity() {
        scheduler.noteRemoteChange(nowMs())
        appContext?.let { wake(it) }
    }

    /** 別的通道改了這些筆記本：首頁據此重讀清單。 */
    fun publishChanged(ids: List<String>) {
        _changedNotebooks.value = ids
    }

    /** 首頁讀完變動清單之後清掉，避免重複觸發重讀。 */
    fun consumeChanged() {
        _changedNotebooks.value = emptyList()
    }

    private fun pump(context: Context) {
        scope.launch {
            // 同一時間只跑一輪。排程器本身也擋，這道鎖是為了擋住
            // 「兩個協程同時通過 shouldStart」那個窗口。
            runLock.withLock {
                if (!scheduler.shouldStart(nowMs())) return@withLock
                _isSyncing.value = true
                roundChanged = true
                val outcome = try {
                    runOneRound(context)
                } finally {
                    _isSyncing.value = false
                }
                scheduler.finishRound(outcome, roundChanged, nowMs())
                _needsSignIn.value = scheduler.isBlockedOnAuth()
                if (scheduler.isDormant()) sleepSyncServices(context.applicationContext)
            }
            // 這一輪跑完之後還有待辦（例如跑到一半又存了檔）就接著跑。
            val due = scheduler.nextDueInMs(nowMs())
            if (due != ULong.MAX_VALUE) {
                if (due > 0u) delay(due.toLong())
                pump(context)
            }
        }
    }

    private suspend fun runOneRound(context: Context): FfiSyncOutcome {
        if (!GoogleAuth.isSignedIn(context)) {
            // 沒登入不是錯誤，也不該一直重試。
            roundChanged = false
            return FfiSyncOutcome.SUCCESS
        }
        return kotlinx.coroutines.withContext(Dispatchers.IO) {
            val result = runCatching {
                CloudSync.runFull(context, deviceId, activeNotebookId)
            }.getOrNull()
            val meta = result?.meta
            when {
                result == null -> FfiSyncOutcome.TRANSIENT
                // **跳過不是「要重新登入」。** 被擋下來時 meta 是 null，
                // 照 null 那一條走會回 NEEDS_REAUTH —— 一次跳過就把自動
                // 同步停掉、叫使用者去重新登入，而他根本沒有登出。
                result.skipped -> FfiSyncOutcome.TRANSIENT
                meta == null -> FfiSyncOutcome.NEEDS_REAUTH
                meta.needsReauth -> FfiSyncOutcome.NEEDS_REAUTH
                !meta.ok -> FfiSyncOutcome.TRANSIENT
                else -> {
                    SyncHistory.markGoogleSynced(context)
                    roundChanged = result.uploaded > 0 || result.downloaded > 0 ||
                        result.changed.isNotEmpty()
                    if (result.changed.isNotEmpty()) {
                        _changedNotebooks.value = result.changed
                        // 真的拉到了對方的東西 = 對方在動：排程器重新開始週期同步。
                        scheduler.noteRemoteChange(nowMs())
                    }
                    FfiSyncOutcome.SUCCESS
                }
            }
        }
    }

    private fun watchNetwork(context: Context) {
        val manager = context.getSystemService(ConnectivityManager::class.java) ?: return
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                // 只在**由斷轉通**時觸發。每次網路事件都觸發的話，
                // 在 Wi-Fi 與行動網路之間切換會連放好幾槍。
                if (!wasOnline) {
                    wasOnline = true
                    request(context, FfiSyncTrigger.NETWORK_REGAINED)
                }
            }

            override fun onLost(network: Network) {
                wasOnline = false
            }
        }
        runCatching { manager.registerNetworkCallback(request, callback) }
    }
}
