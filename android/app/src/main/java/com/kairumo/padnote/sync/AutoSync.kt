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
 * - 前景時每 12 秒拉一次 —— P1 之後那是**一個** HTTP 請求，
 *   沒有變動就是空回應
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
    private var deviceId: UInt = 0u
    private var wasOnline = true

    private fun nowMs(): ULong = SystemClock.elapsedRealtime().toULong()

    /** 背景 worker 拿不到 Activity，只好跟這裡要 device id。 */
    fun currentDeviceId(): UInt = deviceId

    /** App 啟動時呼叫一次。 */
    @Synchronized
    fun start(context: Context, deviceId: UInt) {
        this.deviceId = deviceId
        if (started) return
        started = true
        val app = context.applicationContext

        // 前景心跳。間隔由核心給 —— 兩個平台照同一個數字。
        //
        // 心跳只是「問一下」，不是輪詢頻率：真正的節奏由排程器依
        // 當下狀態決定（對方正在寫→三秒、有人在動→十二秒、
        // 兩邊都閒→一分鐘）。心跳要跟最快的那一檔一樣快，否則
        // 快檔會被慢計時器吃掉。
        scope.launch {
            val interval = syncHeartbeatIntervalMs().toLong()
            while (true) {
                delay(interval)
                scheduler.tick(nowMs())
                pump(app)
            }
        }

        watchNetwork(app)
        // 背景保底：App 被收掉之後，前景的心跳也跟著停。
        SyncWorker.schedule(app)
        request(app, FfiSyncTrigger.FOREGROUND)
    }

    /** 送一個觸發事件進排程器。 */
    fun request(context: Context, trigger: FfiSyncTrigger) {
        val app = context.applicationContext
        scheduler.request(trigger, nowMs())
        _needsSignIn.value = scheduler.isBlockedOnAuth()
        scope.launch {
            // 去抖動的觸發不會立刻起跑，所以要排一次「到點再問」。
            val due = scheduler.nextDueInMs(nowMs())
            if (due != ULong.MAX_VALUE && due > 0u) delay(due.toLong())
            pump(app)
        }
    }

    /** 本機存檔之後呼叫。**會去抖動**，連續存檔只會推一次。 */
    fun noteLocalEdit(context: Context) = request(context, FfiSyncTrigger.LOCAL_EDIT)

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
                val outcome = try {
                    runOneRound(context)
                } finally {
                    _isSyncing.value = false
                }
                scheduler.finish(outcome, nowMs())
                _needsSignIn.value = scheduler.isBlockedOnAuth()
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
            return FfiSyncOutcome.SUCCESS
        }
        return kotlinx.coroutines.withContext(Dispatchers.IO) {
            val result = runCatching { CloudSync.runFull(context, deviceId) }.getOrNull()
            val meta = result?.meta
            when {
                result == null -> FfiSyncOutcome.TRANSIENT
                meta == null -> FfiSyncOutcome.NEEDS_REAUTH
                meta.needsReauth -> FfiSyncOutcome.NEEDS_REAUTH
                !meta.ok -> FfiSyncOutcome.TRANSIENT
                else -> {
                    SyncHistory.markGoogleSynced(context)
                    if (result.changed.isNotEmpty()) {
                        _changedNotebooks.value = result.changed
                        // 真的拉到了對方的東西 = 對方正在寫。接下來
                        // 九十秒改用快檔，讓來回編輯像在同一台裝置上。
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
