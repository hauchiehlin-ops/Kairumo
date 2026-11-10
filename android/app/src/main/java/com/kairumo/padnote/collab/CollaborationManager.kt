package com.kairumo.padnote.collab

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.kairumo.padnote.L10n
import com.kairumo.padnote.account.AccountManager
import java.util.UUID
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONArray
import org.json.JSONObject
import uniffi.padnote_core.RelayServer
import uniffi.padnote_core.collabDecrypt
import uniffi.padnote_core.collabEncrypt
import uniffi.padnote_core.collabGenerateRoomKey
import uniffi.padnote_core.collabInviteLink
import uniffi.padnote_core.collabIsLoopbackHost
import uniffi.padnote_core.collabIsValidRoomKey
import uniffi.padnote_core.collabNewRoomId
import uniffi.padnote_core.collabParseInvite
import uniffi.padnote_core.collabTuning
import com.kairumo.padnote.profile.ProfileContext

/**
 * 協同編輯（Android）。
 *
 * 與 Apple 的 `CollaborationManager` 講**同一套 JSON 協定**，而且房號規則、
 * 邀請連結格式、端對端加密與節流參數全部取自核心
 * （`collab*` 那一組），所以 iPad 開的房間手機進得去、訊息解得開。
 *
 * # 為什麼 socket 留在這裡
 *
 * 協定與密碼學在核心，連線本身不在：把 WebSocket 搬進核心要帶進一整個
 * async runtime 與跨語言 callback，換來的只是少寫幾十行樣板。
 *
 * # 本機中繼
 *
 * 位址指向本機時要**自己把中繼開起來**（核心的 [RelayServer]）。少了這一步，
 * 預設的 ws://127.0.0.1:9002 後面根本沒有人在聽，畫面會永遠卡在
 * 「正在自動重新連線」—— Apple 端踩過這個坑。
 */
class CollaborationManager(private val context: Context) {

    sealed interface Status {
        data object Disconnected : Status
        data object Connecting : Status
        data class Connected(val roomId: String) : Status
        data class Reconnecting(val attempt: Int, val max: Int) : Status
    }

    data class Peer(
        val userId: String,
        val userName: String,
        val userColor: String,
        val role: String,
        var cursorX: Float = 0f,
        var cursorY: Float = 0f,
        var isDrawing: Boolean = false,
        var selectedId: String? = null,
        /** 最後一次收到在場資訊的時間。租約 5 秒沒續約就失效（設計 §5.1）。 */
        var lastActiveMs: Long = System.currentTimeMillis()
    )

    /** 收到的遠端操作。呼叫端決定怎麼套進筆記。 */
    data class RemoteOplog(
        val userId: String,
        val kind: String,
        val payload: JSONObject,
        val lamport: ULong
    )

    /** 跨頁即時協同編輯租約（「以第一個下筆為主」仲裁與全員自動跟隨跳頁，與 Apple `PageEditLease` 對齊）。 */
    data class PageEditLease(
        val userId: String,
        val userName: String,
        val isHost: Boolean,
        val pageId: String,
        /** 該輪編輯開始時的 Lamport 時鐘（越小代表越早下筆；平手時以 userId 字典序較小者優先）。 */
        val startedLamport: Long,
        val updatedAtMs: Long = System.currentTimeMillis(),
    ) {
        fun hasPriority(over: PageEditLease): Boolean =
            if (startedLamport != over.startedLamport) startedLamport < over.startedLamport
            else userId < over.userId
    }

    private val tuning = collabTuning()
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

    private var statusState by mutableStateOf<Status>(Status.Disconnected)
    var status: Status
        get() = statusState
        private set(value) {
            val changed = value != statusState
            statusState = value
            if (changed) mainHandler.post { updateRelayBridge() }
        }
    var serverAddress by mutableStateOf(loadServer())
    var roomId by mutableStateOf("")
        private set
    var isHost by mutableStateOf(false)
        private set

    /**
     * 「重新載入會議室內容」的請求次數（協作者在協作中按「一鍵恢復初始狀態」時改走這裡）。
     * 編輯器看到它變了，就以目前內容為基準重新向房間要整份狀態 —— 房主回覆的內容補回缺的筆畫與物件，
     * 房間裡已擦掉的筆畫（回覆附的墓碑）也從這台拿掉。與 Apple `reloadCollabRoomContent` 相同。只在主執行緒動。
     */
    /** 中繼的提醒（`relay_notice`，已在地化）。任何執行緒都可送出；編輯器收集後以 Toast 顯示。 */
    val relayNotices = kotlinx.coroutines.flow.MutableSharedFlow<String>(extraBufferCapacity = 4)

    var roomReloadRequests by mutableIntStateOf(0)
        private set

    fun requestRoomReload() {
        roomReloadRequests++
    }
    var roomKeyBase64 by mutableStateOf<String?>(null)
        private set

    /** 收到但解不開（沒有金鑰或金鑰不符）而被丟棄的加密操作數。 */
    @Volatile var undecryptableCount = 0
        private set
    var lastError by mutableStateOf<String?>(null)
        private set
    private var hostingLocalRelayState by mutableStateOf(false)
    var isHostingLocalRelay: Boolean
        get() = hostingLocalRelayState
        private set(value) {
            val changed = value != hostingLocalRelayState
            hostingLocalRelayState = value
            if (changed) mainHandler.post { updateRelayBridge() }
        }
    var lanRelayAddress by mutableStateOf<String?>(null)
        private set
    var queuedOplogCount by mutableIntStateOf(0)
        private set

    val peers = mutableStateListOf<Peer>()

    /** 即時語音管理器（掛在協同連線上） */
    var voice: CollabVoiceManager? = null

    /** 這台裝置的身分。每次啟動換一個 —— 它只用來在房間裡區分人。 */
    val currentUserId: String = UUID.randomUUID().toString()

    /** 收到遠端操作時呼叫。由畫面設定。**在背景執行緒上呼叫**，畫面要自己切回主執行緒。 */
    var onOplog: ((RemoteOplog) -> Unit)? = null
    /** 兩人同時選了同一個物件、對方勝出：本機要放手（設計 §5.3）。參數是物件 id 與對方名字。 */
    var onLeaseLost: ((String, String) -> Unit)? = null
    /** 遠端協作者或房主在某頁開始／進行編輯時，通知全員畫布同步跳轉至該頁面。 */
    var onPageJumpRequested: ((String, Boolean) -> Unit)? = null
    /** 本機嘗試在不同頁進行編輯，但已有另一位協作者／房主先下筆持有編輯權：通知畫布顯示等待提示。 */
    var onPageEditBlocked: ((PageEditLease) -> Unit)? = null
    /** 兩人幾乎同時在不同頁下筆、對方時鐘較早而勝出：通知本機取消進行中的筆畫／打字並顯示等待提示。 */
    var onPageEditPreempted: ((PageEditLease) -> Unit)? = null
    /** 目前有效的頁面編輯租約（可能為本機或遠端持有）。 */
    @Volatile var activePageEditLease: PageEditLease? = null
        private set
    private var lastPageEditBroadcastAtMs = 0L
    private var pageEditReleaseTask: java.util.TimerTask? = null
    private var pageEditTimer: java.util.Timer? = null
    /**
     * 中繼的暫存已經補不回漏掉的那一段（設計 §7）：要向其他成員要整份狀態。
     * 在連線的執行緒上呼叫，接手的人自己轉到主執行緒。
     */
    var onStateSyncNeeded: (() -> Unit)? = null
    /** 看過的最大中繼序號（同一個房間裡重連時從這裡補發）。 */
    @Volatile private var lastSeq = 0L

    // ── 時鐘與去重（設計 §3、§7；與 Apple 端相同）────────────────
    /** Lamport 時鐘：送出時 +1，收到時取最大值。以前每一筆都是 1，沒有任何先後依據。 */
    var lamportClock = 0L
        private set
    private val seenOpIds = LinkedHashSet<String>()
    /** 自己目前的選取（編輯租約）。持有期間每秒續約一次。 */
    var mySelectedId: String? = null
        private set
    private var leaseRenewer: java.util.Timer? = null

    @Synchronized
    fun nextLamport(): Long {
        lamportClock += 1
        return lamportClock
    }

    /** 誰正在獨佔編輯這個物件（租約有效、而且對方勝出）。打字（`text:`）不是獨佔的。 */
    fun leaseHolder(id: String): Peer? {
        val now = System.currentTimeMillis()
        val wanted = canonicalSelection(id)
        return peers.firstOrNull { p ->
            p.selectedId == wanted && now - p.lastActiveMs < LEASE_TIMEOUT_MS &&
                (mySelectedId?.let(::canonicalSelection) != wanted || p.userId < currentUserId)
        }
    }

    /** 正在這個文字方塊打字的人（不鎖：字元 CRDT 會合併）。 */
    fun typingPeers(id: String): List<Peer> {
        val now = System.currentTimeMillis()
        val wanted = canonicalSelection(TYPING_PREFIX + id)
        return peers.filter { it.selectedId == wanted && now - it.lastActiveMs < LEASE_TIMEOUT_MS }
    }

    /** 選取（或取消選取）物件：立刻告訴大家，並在持有期間每秒續約。 */
    fun broadcastSelection(selectedId: String?) {
        mySelectedId = selectedId
        leaseRenewer?.cancel()
        leaseRenewer = null
        if (selectedId != null) {
            leaseRenewer = java.util.Timer(true).apply {
                scheduleAtFixedRate(object : java.util.TimerTask() {
                    override fun run() { mySelectedId?.let { sendSelection(it) } }
                }, 1000L, 1000L)
            }
        }
        sendSelection(selectedId)
    }

    private fun sendSelection(selectedId: String?) {
        val connected = status as? Status.Connected ?: return
        val msg = JSONObject()
            .put("type", "presence")
            .put("room_id", connected.roomId)
            .put("user_id", currentUserId)
            .put("cursor", JSONObject().put("x", lastCursor.first).put("y", lastCursor.second)
                .put("is_drawing", false).put("tool", "select"))
        selectedId?.let { msg.put("selected_id", it) }
        send(msg)
    }

    private val client = OkHttpClient.Builder()
        // OkHttp 預設會在閒置時關掉連線；協同是長連線，交給自己的心跳管。
        .pingInterval(java.time.Duration.ofSeconds(tuning.pingIntervalS.toLong()))
        // 關掉 Nagle：協同送的是一則則很小的訊息，開著的話下一則要等上一則的 ACK（延遲 ACK 可達 200 ms）。
        .socketFactory(NoDelaySocketFactory)
        .build()
    private var socket: WebSocket? = null

    /** 送出佇列裡還沒送出的位元組數（分塊送大圖時用來節流）。任何執行緒都可讀。 */
    fun outgoingQueueBytes(): Long = socket?.queueSize() ?: 0L
    private var relay: RelayServer? = null
    private var reconnectAttempt = 0
    private var userInitiatedDisconnect = false
    /**
     * 這間房至少成功加入過一次。加入過之後的斷線（App 進背景、螢幕關閉、網路切換）**不會放棄重連** ——
     * 只有使用者自己按「離開／結束協同」才真的離開會議室。與 Apple `joinedThisRoom` 相同。
     */
    private var joinedThisRoom = false
    /** 進背景的時間：回前景時據此判斷連線是不是已經被系統掐掉。 */
    private var backgroundedAtMs = 0L

    /** 在會議室裡（加入或開了房間、而且不是使用者自己離開的）。 */
    val isInRoom: Boolean
        get() = roomId.isNotEmpty() && !userInitiatedDisconnect

    /** App 進背景（編輯器所在的 Activity onStop）。 */
    fun onAppBackground() {
        if (isInRoom) backgroundedAtMs = System.currentTimeMillis()
    }

    /**
     * App 回前景（onStart）：連線沒在、或在背景待過一陣子（底層連線多半已被系統關掉、卻還沒回報），
     * 立刻以同一間房重連、從看過的序號接著補。與 Apple `handleBecomeActive` 相同。
     */
    fun onAppForeground() {
        val away = if (backgroundedAtMs == 0L) 0L else System.currentTimeMillis() - backgroundedAtMs
        backgroundedAtMs = 0L
        if (!isInRoom) return
        if (status !is Status.Connected || away > BACKGROUND_RECONNECT_AFTER_MS) reconnectNow()
    }

    /** 丟掉目前的連線，立刻以同一間房重連。 */
    private fun reconnectNow() {
        if (!isInRoom) return
        reconnectAttempt = 0
        val old = socket
        socket = null
        runCatching { old?.cancel() }
        connect(roomId, isHost, isReconnecting = true)
    }
    private val candidateServers = mutableListOf<String>()
    private val offlineQueue = mutableListOf<JSONObject>()
    private var lastPresenceSentAtMs = 0L
    private var lastCursor = 0f to 0f

    // ── 房間 ────────────────────────────────────────────────────

    /**
     * @param server 指定這一場用的伺服器（雲端共享的房間開在公開中繼上）。這個管理器屬於一個編輯器，
     *   位址只活在這一場，不寫回設定（`saveServer` 才會）。
     */
    fun createRoom(server: String? = null) {
        roomKeyBase64 = collabGenerateRoomKey().takeIf { it.isNotEmpty() }
        server?.let { serverAddress = it }
        connect(collabNewRoomId(), asHost = true)
    }

    /**
     * 「同一 Wi‑Fi」開房用的中繼：這台裝置內建的本機中繼。與 Apple `localRoomServer` 相同。
     *
     * 使用者**存的**位址是 `wss://`（刻意設定的自架遠端中繼）才沿用它；其餘一律用本機中繼。
     * 以前用的是記憶體裡的 [serverAddress] —— 加入別人的房間、開過雲端共享之後它會變成對方的區網位址
     * 或雲端中繼，再按「開始多人協同」就連到別處（對方沒開房時：Connection refused，一直重連）。
     */
    val localRoomServer: String get() {
        val saved = loadServer()
        return if (usesCustomRemoteRelay(saved)) saved else tuning.defaultServer
    }

    /** 存的位址是不是自架的遠端中繼（`wss://`）。是的話開房按鈕照舊叫「開始多人協同」。 */
    val savedCustomRemoteRelay: Boolean get() = usesCustomRemoteRelay(loadServer())

    private fun usesCustomRemoteRelay(address: String) = address.trim().lowercase().startsWith("wss://")

    /** 以既有的房號與金鑰當房主開房（雲端共享：重開之後沿用同一間，發出去的邀請照樣有效）。與 Apple `hostRoom` 相同。 */
    fun hostRoom(room: String, keyBase64: String, server: String) {
        if (collabIsValidRoomKey(keyBase64)) roomKeyBase64 = keyBase64
        serverAddress = server
        connect(room, asHost = true)
    }

    // ── 同時開放雲端（見 CollabRelayBridge.kt）──

    /** 會議室開在本機中繼（同一 Wi‑Fi）時，也以同一間房開放到這個雲端中繼。`null`＝只開在一個中繼上。 */
    var cloudBridgeUrl by mutableStateOf<String?>(null)
        private set
    private var relayBridge: CollabRelayBridge? = null
    /** 上一座橋帶進來的雲端成員（重建橋時不把他們誤當成 Wi‑Fi 這邊的人）。 */
    private var bridgedCloudUserIds: Set<String> = emptySet()

    /** 這間會議室是不是同時開在雲端（房主正在橋接）。 */
    val isBridgingCloud: Boolean get() = relayBridge != null

    /** 房主：同一 Wi‑Fi 的會議室也開放雲端共享（傳 `null` 關掉）。與 Apple `enableCloudBridge` 相同。 */
    fun enableCloudBridge(url: String?) {
        cloudBridgeUrl = url
        mainHandler.post { updateRelayBridge() }
    }

    /**
     * 房主按「同一 Wi‑Fi」：會議室已開在雲端時不另開一間 —— 同一間房改開在本機中繼，雲端那邊用橋接續上，
     * 兩種方式加入的人都在同一間會議室。其餘照舊開新房。與 Apple `startLocalRoom` 相同。
     */
    fun startLocalRoom() {
        val key = roomKeyBase64
        val cloud = serverAddress
        if (isHost && status is Status.Connected && roomId.isNotEmpty() && key != null &&
            cloud == cloudRelayUrl && !savedCustomRemoteRelay
        ) {
            hostRoom(roomId, key, localRoomServer)
            enableCloudBridge(cloud)
            return
        }
        createRoom(localRoomServer)
    }

    /** 依目前狀態開或關橋：房主、連在自己的本機中繼上、已連線、而且開放了雲端。只在主執行緒呼叫。 */
    private fun updateRelayBridge() {
        val cloud = cloudBridgeUrl
        val host = runCatching { java.net.URI(serverAddress.trim()).host ?: "" }.getOrDefault("")
        val wanted = !cloud.isNullOrEmpty() && isHost && isHostingLocalRelay && status is Status.Connected &&
            collabIsLoopbackHost(host) && cloud != serverAddress
        val existing = relayBridge
        if (wanted && existing == null && cloud != null) {
            val profile = AccountManager.load(context, fallbackName = "Kairumo")
            val me = CollabRelayBridge.Member(
                currentUserId, "${profile.displayName.ifEmpty { "Kairumo" }} (Android)", profile.colorHex
            )
            val bridge = CollabRelayBridge(cloud, serverAddress.trim(), roomId, me)
            bridge.start(peers.map { CollabRelayBridge.Member(it.userId, it.userName, it.userColor) }, bridgedCloudUserIds)
            relayBridge = bridge
        } else if (!wanted && existing != null) {
            bridgedCloudUserIds = existing.cloudUserIds
            existing.stop()
            relayBridge = null
        }
    }

    /** 房號、邀請連結、連結帶金鑰三種都吃得下（解析在核心）。 */
    fun joinRoom(text: String) {
        val trimmed = text.trim()
        // 若包含 server 參數，立即套用該伺服器位址
        val serverParam = runCatching {
            android.net.Uri.parse(trimmed).getQueryParameter("server")
        }.getOrNull() ?: if (trimmed.contains("server=")) {
            trimmed.substringAfter("server=").substringBefore("&").substringBefore("#").trim()
        } else null

        if (!serverParam.isNullOrEmpty()) {
            val decoded = runCatching { java.net.URLDecoder.decode(serverParam, "UTF-8") }.getOrDefault(serverParam)
            serverAddress = decoded
        }

        val inviteV2 = runCatching { uniffi.padnote_core.collabParseInviteV2(trimmed) }.getOrNull()
        val roomId = inviteV2?.roomId?.takeIf { it.isNotEmpty() } ?: collabParseInvite(trimmed).roomId
        if (roomId.isEmpty()) {
            lastError = "invalid_room"
            return
        }
        // 金鑰在 `#key=` 之後，是標準 base64（含 `+`、`/`、`=`）。連結被轉貼、經過聊天軟體或系統的網址
        // 處理後這幾個字元常被百分號編碼，核心的解析不解碼 → 判成「沒有金鑰」→ 以明文加入，
        // 之後房主送來的每一則加密訊息都解不開、被靜靜丟掉：連得上、成員也對，內容卻永遠不來。
        // 所以這裡自己再解一次，三種寫法（原樣、百分號編碼、`+` 被當空白）都認。
        val key = listOf(
            inviteV2?.keyBase64.orEmpty(),
            collabParseInvite(trimmed).keyBase64,
            extractInviteKey(trimmed),
        ).firstOrNull { it.isNotEmpty() && collabIsValidRoomKey(it) }
        roomKeyBase64 = key
        if (key == null && trimmed.contains("#")) {
            android.util.Log.w("Collab", "邀請連結帶了 # 片段但解不出合法金鑰：會以未加密身分加入，無法讀取加密房間")
        }
        if (inviteV2 != null && inviteV2.servers.isNotEmpty()) {
            val myIps = listOfNotNull(getLanIpAddress())
            val ordered = runCatching { uniffi.padnote_core.collabOrderServers(inviteV2.servers, myIps) }.getOrNull()
            if (!ordered.isNullOrEmpty()) {
                candidateServers.clear()
                candidateServers.addAll(ordered)
                serverAddress = candidateServers.removeAt(0)
            }
        }
        connect(roomId, asHost = false)
    }

    /** 從邀請文字的 `#` 片段取出金鑰：容忍百分號編碼與被轉成空白的 `+`。 */
    private fun extractInviteKey(text: String): String {
        val fragment = text.substringAfter('#', "").trim()
        if (fragment.isEmpty()) return ""
        val raw = fragment.removePrefix("key=").trim().replace("+", "%2B").replace(" ", "%2B")
        return runCatching { java.net.URLDecoder.decode(raw, "UTF-8") }.getOrDefault(raw).trim()
    }

    fun buildInviteLink(): String {
        val base = collabInviteLink(roomId, roomKeyBase64 ?: "")
        val target = if (isHostingLocalRelay) {
            lanRelayAddress
        } else if (!collabIsLoopbackHost(runCatching { java.net.URI(serverAddress).host ?: "" }.getOrDefault(""))) {
            serverAddress
        } else null

        return if (target != null) {
            val encodedTarget = runCatching { java.net.URLEncoder.encode(target, "UTF-8") }.getOrDefault(target)
            if (base.contains("#")) {
                val parts = base.split("#", limit = 2)
                val delim = if (parts[0].contains("?")) "&" else "?"
                "${parts[0]}${delim}server=${encodedTarget}#${parts[1]}"
            } else {
                val delim = if (base.contains("?")) "&" else "?"
                "$base${delim}server=${encodedTarget}"
            }
        } else base
    }

    val inviteLink: String
        get() = buildInviteLink()

    /**
     * 帶上「是哪一本筆記」的邀請連結（QR Code 用）。舊版只有房號、金鑰、位址：對方一掃，
     * App 起來之後不知道要打開哪一本，只好停在首頁。補上 `nb`／`title`（與雲端共享同一個
     * v2 格式，由核心組字串，與 Apple 相同，I6）。
     */
    fun notebookInviteLink(link: String, notebookId: String?, title: String): String {
        if (notebookId.isNullOrEmpty() || link.isEmpty()) return link
        val invite = uniffi.padnote_core.collabParseInviteV2(link)
        if (invite.roomId.isEmpty()) return link
        return uniffi.padnote_core.collabInviteLinkV2(invite.copy(notebookId = notebookId, title = title))
    }

    private fun connect(room: String, asHost: Boolean, isReconnecting: Boolean = false) {
        // 新的房間從頭來；斷線重連回同一個房間則從看過的序號接著補。
        if (!isReconnecting) {
            lastSeq = 0L
            stateDirty = true
            lastDepositAtMs = 0L
        }
        userInitiatedDisconnect = false
        if (!isReconnecting) {
            disconnect(userInitiated = false)
            reconnectAttempt = 0
            joinedThisRoom = false
            roomId = room
            isHost = asHost
            peers.clear()
            status = Status.Connecting
        }

        val url = serverAddress.trim()

        // 明文的中繼只允許在自己的區網或本機。oplog 本身是端對端加密的，
        // 但房號、成員與流量樣態全是明文，而且明文 WebSocket 可以被中間人
        // 直接改寫或重導。判斷在核心，兩邊同一份 —— 各寫一次的話，同一個
        // 位址會在 iPad 上連得上、在 Android 上連不上。
        val check = uniffi.padnote_core.collabCheckServer(url)
        if (!check.ok) {
            lastError = check.reasonKey
            status = Status.Disconnected
            return
        }

        val host = runCatching { java.net.URI(url).host ?: "" }.getOrDefault("")
        if (collabIsLoopbackHost(host)) {
            if (asHost) {
                startLocalRelay(runCatching { java.net.URI(url).port }.getOrDefault(-1))
            } else {
                lastError = "relay_guest_cannot_loopback"
                status = Status.Disconnected
                return
            }
        } else {
            runCatching { relay?.stop() }
            isHostingLocalRelay = false
            lanRelayAddress = null
        }
        lastError = null

        // 網址加上 `room=<房號>`：公開中繼（Cloudflare）以它決定房間；Rust 中繼不看網址，加了也無妨（與 Apple 相同）。
        val socketUrl = runCatching {
            val uri = android.net.Uri.parse(url)
            val builder = uri.buildUpon().clearQuery()
            for (name in uri.queryParameterNames) {
                if (name == "room") continue
                for (value in uri.getQueryParameters(name)) builder.appendQueryParameter(name, value)
            }
            builder.appendQueryParameter("room", room).build().toString()
        }.getOrDefault(url)
        val request = runCatching { Request.Builder().url(socketUrl.toHttpish()).build() }.getOrNull()
        if (request == null) {
            lastError = "invalid_server"
            status = Status.Disconnected
            return
        }
        socket = client.newWebSocket(request, Listener())
    }

    /**
     * OkHttp 吃 http/https，不吃 ws/wss —— 換掉 scheme 即可，協定升級由它處理。
     * 不換的話會丟 IllegalArgumentException，而且訊息只說「Expected URL scheme」，
     * 看起來像位址打錯。
     */
    private fun String.toHttpish(): String = when {
        startsWith("ws://") -> "http://" + removePrefix("ws://")
        startsWith("wss://") -> "https://" + removePrefix("wss://")
        else -> this
    }

    /**
     * 本機在區域網路上的 IPv4 位址（給隊友連線）。不收 100.64.0.0/10（電信級 NAT、VPN 覆蓋網路）：
     * 那種位址對方通常連不到，放進邀請連結只會讓加入者卡在「連線中」。與 Apple `lanIPv4Address` 相同。
     */
    fun getLanIpAddress(): String? {
        var lanIp: String? = null
        try {
            val interfaces = java.net.NetworkInterface.getNetworkInterfaces() ?: return null
            for (intf in interfaces.asSequence()) {
                if (!intf.isUp || intf.isLoopback) continue
                for (addr in intf.inetAddresses.asSequence()) {
                    if (addr is java.net.Inet4Address && !addr.isLoopbackAddress) {
                        val hostAddress = addr.hostAddress ?: continue
                        if (isCarrierGradeNat(hostAddress)) continue
                        if (!hostAddress.startsWith("127.") && !hostAddress.startsWith("169.254.")) {
                            if (lanIp == null || intf.name.startsWith("wlan") || intf.name.startsWith("eth")) {
                                lanIp = hostAddress
                            }
                        }
                    }
                }
            }
        } catch (_: Exception) {}
        return lanIp
    }

    private fun isCarrierGradeNat(ip: String): Boolean {
        val parts = ip.split(".")
        if (parts.size != 4 || parts[0] != "100") return false
        val second = parts[1].toIntOrNull() ?: return false
        return second in 64..127
    }

    private fun startLocalRelay(port: Int) {
        val p = if (port in 1..65535) port.toUShort() else 9002u
        val server = relay ?: RelayServer().also { relay = it }
        // 埠被佔用通常代表已經有一個中繼在聽，照常連過去就好，不是致命錯誤。
        val ok = runCatching { server.start(p); server.isRunning() }.getOrDefault(false)
        isHostingLocalRelay = ok
        if (ok) {
            lanRelayAddress = getLanIpAddress()?.let { "ws://$it:$p" }
        } else {
            lanRelayAddress = null
        }
    }

    fun disconnect(userInitiated: Boolean = true) {
        if (userInitiated) {
            userInitiatedDisconnect = true
            reconnectAttempt = 0
            offlineQueue.clear()
            queuedOplogCount = 0
            roomKeyBase64 = null
            cloudBridgeUrl = null
            bridgedCloudUserIds = emptySet()
        }
        val s = socket
        if (s != null && status is Status.Connected) {
            runCatching {
                val leavePayload = JSONObject()
                    .put("type", "leave")
                    .put("room_id", (status as Status.Connected).roomId)
                    .put("user_id", currentUserId)
                s.send(leavePayload.toString())
            }
        }
        socket?.close(1000, null)
        socket = null
        stopHeartbeatTimer()
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            peers.clear()
        }
        liveInk.clear()
        resetPageEditLeaseState()
        voice?.reset()
        if (userInitiated) {
            joinedThisRoom = false
            runCatching { relay?.stop() }
            isHostingLocalRelay = false
            lanRelayAddress = null
            status = Status.Disconnected
        }
    }

    // ── 廣播 ────────────────────────────────────────────────────

    /** 游標。30Hz 節流 —— 不節流的話一次手寫會送出上千則訊息把中繼灌爆。 */
    fun broadcastCursor(x: Float, y: Float, isDrawing: Boolean, tool: String, selectedId: String? = null) {
        val connected = status as? Status.Connected ?: return
        lastCursor = x to y
        val now = System.currentTimeMillis()
        if (now - lastPresenceSentAtMs < tuning.presenceThrottleMs.toLong() * crowdFactor(peers.size)) return
        lastPresenceSentAtMs = now

        val msg = JSONObject()
            .put("type", "presence")
            .put("room_id", connected.roomId)
            .put("user_id", currentUserId)
            .put(
                "cursor",
                JSONObject()
                    .put("x", x).put("y", y)
                    .put("is_drawing", isDrawing).put("tool", tool)
            )
        selectedId?.let { msg.put("selected_id", it) }
        send(msg)
    }

    private var heartbeatTimer: java.util.Timer? = null

    private fun startHeartbeatTimer() {
        heartbeatTimer?.cancel()
        heartbeatTimer = java.util.Timer(true).apply {
            scheduleAtFixedRate(object : java.util.TimerTask() {
                override fun run() {
                    val connected = status as? Status.Connected ?: return
                    val msg = JSONObject()
                        .put("type", "presence")
                        .put("room_id", connected.roomId)
                        .put("user_id", currentUserId)
                        .put(
                            "cursor",
                            JSONObject()
                                .put("x", lastCursor.first).put("y", lastCursor.second)
                                .put("is_drawing", false).put("tool", "heartbeat")
                        )
                    mySelectedId?.let { msg.put("selected_id", it) }
                    send(msg)
                    val now = System.currentTimeMillis()
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        peers.removeAll { now - it.lastActiveMs > 35_000L }
                    }
                }
            }, 5000L, 5000L)
        }
    }

    private fun stopHeartbeatTimer() {
        heartbeatTimer?.cancel()
        heartbeatTimer = null
    }

    /**
     * 持久化操作。連線中斷時進離線佇列，重連後補送 ——
     * 丟掉的話使用者畫的東西不會出現在對方畫面上，而且沒有人會發現。
     */
    fun broadcastOplog(kind: String, payload: JSONObject, lamport: Long? = null, envelope: Map<String, Any> = emptyMap()): Long {
        val key = roomKeyBase64
        // 時鐘由這裡配發（或由呼叫端事先以 nextLamport() 取得）；操作 id 放在 payload 裡 ——
        // 三份中繼都原樣轉送 payload，但不見得保留外層的其他欄位。
        val stamp = lamport ?: nextLamport()
        noteStateChanged(kind)
        payload.put("op_id", UUID.randomUUID().toString())
        val msg = JSONObject()
            .put("type", "oplog")
            .put("room_id", roomId)
            .put("user_id", currentUserId)
            .put("lamport", stamp)
            .put("kind", kind)

        val cipher = if (key != null) collabEncrypt(key, payload.toString()) else ""
        if (cipher.isNotEmpty()) {
            msg.put("payload", JSONObject().put("ciphertext", cipher))
            msg.put("encrypted", true)
        } else {
            // 加密失敗就送明文，不是不送：少一則 oplog 是資料遺失，
            // 而使用者不會知道。與 Apple 端同一個取捨。
            msg.put("payload", payload)
        }

        // 信封上的明文欄位（寄存整份狀態的 `snap`／`part`／`parts`／`seq`，中繼要看）。內容仍在加密的 payload 裡。
        for ((k, v) in envelope) if (!msg.has(k)) msg.put(k, v)
        if (status is Status.Connected) {
            send(msg)
        } else {
            offlineQueue += msg
            queuedOplogCount = offlineQueue.size
        }
        return stamp
    }

    // ── 寄存整份狀態（雲端中繼，見 `deploy/relay-cloudflare`）──與 Apple 同一套 ──

    /** 已收到的最大中繼序號（寄存時寫在信封上，中繼以它判斷新舊）。 */
    val relaySeq: Long get() = lastSeq

    /** 這場協同開在雲端中繼上（`wss://`）。區網的本機中繼不收寄存（它會照常轉送給每個人）。 */
    // 同時開放雲端（橋接）時也寄存：橋會把寄存送進雲端，房主不在線時新加入的人才拿得到最新版。
    val isOnCloudRelay: Boolean get() = serverAddress.lowercase().startsWith("wss://") || relayBridge != null

    /** 編輯器在協同中掛上：把這本目前的整份狀態寄存到中繼。 */
    var stateDepositor: (suspend () -> Unit)? = null

    /** 上次寄存之後房間內容有沒有變（送出或收到正式操作）。進新房間時算「有變」：先寄存一份底稿。 */
    @Volatile private var stateDirty = true
    @Volatile private var lastDepositAtMs = 0L

    /**
     * 現在該由這台寄存：在雲端中繼上、有變動、離上次夠久，而且房間裡（含自己）使用者 id 最小的是我 ——
     * 每個人都寄存只是把同一份內容多寫幾遍。
     */
    val shouldDepositState: Boolean
        get() {
            if (!isOnCloudRelay || status !is Status.Connected || !stateDirty) return false
            if (lastDepositAtMs != 0L && System.currentTimeMillis() - lastDepositAtMs < DEPOSIT_MIN_INTERVAL_MS) return false
            // 房主在線就只由房主寄存：剛加入、只同步到一半的協作者寄存的半份狀態會蓋掉房主的完整版本，
            // 之後每個雲端加入者都只拿到半份（只剩第一頁）。與 Apple 相同。
            if (isHost) return true
            if (peers.any { it.role == "owner" }) return false
            return peers.none { it.userId < currentUserId }
        }

    fun noteStateDeposited() {
        stateDirty = false
        lastDepositAtMs = System.currentTimeMillis()
    }

    private fun noteStateChanged(kind: String) {
        if (!kind.startsWith("state_") && !kind.startsWith("live_")) stateDirty = true
    }

    /** 寄存一次（例如結束協同之前，讓不在線的協作者之後還拿得到最終版本）。 */
    suspend fun depositState() {
        if (!isOnCloudRelay || status !is Status.Connected) return
        val depositor = stateDepositor ?: return
        kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Main) { depositor() }
        // 送出排在連線的送出佇列裡；關房前給它一點時間送完。
        kotlinx.coroutines.delay(500)
    }

    /** 房主結束這場協同：通知房裡每個人，然後離開。中繼保留房間資料到保存期限（見 `deploy/relay-cloudflare`）。與 Apple `closeRoom` 相同。 */
    fun closeRoom() {
        if (status is Status.Connected && isHost) {
            send(JSONObject().put("type", "close_room").put("room_id", roomId).put("user_id", currentUserId))
        }
        disconnect()
    }

    /** 房主結束了協同（`room_closed`）：編輯器據此解除這本的雲端共享登記。 */
    var onRoomClosed: (() -> Unit)? = null

    // ── 書寫中即時串流（`live_ink`，見 LiveInk.kt）──

    /** 別人書寫中的預覽線。 */
    val liveInk = LiveInkStore()

    /** 連上房間、而且房間裡有別人：才值得記點送出。 */
    val isLiveInkReady: Boolean
        get() = status is Status.Connected && peers.isNotEmpty()

    /**
     * 送一段書寫中的點。**不配發時鐘、不排離線佇列**：它是暫態的，漏了就漏了，
     * 正式筆畫（`ink_add`）提筆後照常送。種類以 `live_` 開頭，中繼不放進補發暫存。
     */
    fun sendLiveInk(payload: JSONObject) {
        val key = roomKeyBase64
        val msg = JSONObject()
            .put("type", "oplog").put("room_id", roomId).put("user_id", currentUserId)
            .put("lamport", 0).put("kind", "live_ink")
        val cipher = if (key != null) collabEncrypt(key, payload.toString()) else ""
        if (cipher.isNotEmpty()) {
            msg.put("payload", JSONObject().put("ciphertext", cipher)).put("encrypted", true)
        } else {
            msg.put("payload", payload)
        }
        if (status is Status.Connected) send(msg)
    }

    // ── 即時語音通話（`live_voice`，見 CollabVoiceManager.kt）──

    /** 廣播按住說話（PTT）微音框或狀態事件。種類以 `live_` 開頭，中繼不放進補發暫存。 */
    fun sendLiveVoice(phase: String, seq: Long, audioBase64: String) {
        val key = roomKeyBase64
        val raw = JSONObject()
            .put("phase", phase)
            .put("seq", seq)
            .put("audio", audioBase64)
            .put("user_name", myDisplayName)

        val msg = JSONObject()
            .put("type", "oplog").put("room_id", roomId).put("user_id", currentUserId)
            .put("lamport", 0).put("kind", "live_voice")

        val cipher = if (key != null) collabEncrypt(key, raw.toString()) else ""
        if (cipher.isNotEmpty()) {
            msg.put("payload", JSONObject().put("ciphertext", cipher)).put("encrypted", true)
        } else {
            msg.put("payload", raw)
        }
        if (status is Status.Connected) send(msg)
    }

    // ── 跨頁即時協同編輯仲裁與自動跳頁（`live_page_edit`，與 Apple 對齊）──

    val myDisplayName: String
        get() {
            val raw = runCatching { AccountManager.load(context, fallbackName = "Kairumo").displayName }
                .getOrDefault("Kairumo")
                .ifEmpty { "Kairumo" }
            return "$raw (Android)"
        }

    /** 格式化「目前由（房主／協作者）XXX 正在進行編輯中，請稍後再進行編輯」提示文字。 */
    fun formatPageEditWaitNotice(lease: PageEditLease, language: String): String {
        val roleLabel = com.kairumo.padnote.LocalizationStrings.localized(
            if (lease.isHost) "collab_role_host" else "collab_role_peer",
            language,
        )
        val trimmedName = lease.userName.trim()
        val actor = if (trimmedName.isEmpty()) roleLabel else "$roleLabel $trimmedName"
        return com.kairumo.padnote.LocalizationStrings.localized("collab_page_editing_wait_notice", language)
            .replace("%@", actor)
    }

    /** 檢查目前是否有其他人在「不同頁」持有有效編輯租約。 */
    @Synchronized
    fun currentBlockingPageEditLease(pageId: String, nowMs: Long = System.currentTimeMillis()): PageEditLease? {
        pruneExpiredPageEditLease(nowMs)
        val lease = activePageEditLease ?: return null
        val canonical = AndroidCollabCanvas.canonicalId(pageId)
        return if (lease.userId != currentUserId && lease.pageId != canonical) lease else null
    }

    /**
     * 本機嘗試在 [pageId] 開始編輯（手繪落筆或文字輸入）。
     * 若被其他協作者／房主在不同頁的既有編輯擋下，回傳對方的 [PageEditLease]（並觸發提示與跳頁回呼）；
     * 若獲准編輯，回傳 `null` 並取得／續約本機租約與廣播 `live_page_edit`。
     */
    @Synchronized
    fun tryBeginLocalPageEdit(pageId: String, nowMs: Long = System.currentTimeMillis()): PageEditLease? {
        if (status !is Status.Connected) return null
        val canonical = AndroidCollabCanvas.canonicalId(pageId)
        if (canonical.isEmpty()) return null

        val blocker = currentBlockingPageEditLease(canonical, nowMs)
        if (blocker != null) {
            onPageEditBlocked?.invoke(blocker)
            onPageJumpRequested?.invoke(blocker.pageId, true)
            return blocker
        }

        pageEditReleaseTask?.cancel()
        pageEditReleaseTask = null

        val existing = activePageEditLease
        if (existing != null && existing.userId == currentUserId && existing.pageId == canonical) {
            val updated = existing.copy(updatedAtMs = nowMs)
            activePageEditLease = updated
            if (nowMs - lastPageEditBroadcastAtMs >= PAGE_EDIT_RENEW_INTERVAL_MS) {
                sendLivePageEdit("renew", updated, nowMs)
            }
            return null
        }

        val stamp = nextLamport()
        val lease = PageEditLease(
            userId = currentUserId,
            userName = myDisplayName,
            isHost = isHost,
            pageId = canonical,
            startedLamport = stamp,
            updatedAtMs = nowMs,
        )
        activePageEditLease = if (existing != null && existing.pageId == canonical && existing.hasPriority(over = lease)) {
            existing.copy(updatedAtMs = nowMs)
        } else {
            lease
        }
        sendLivePageEdit("begin", lease, nowMs)
        return null
    }

    /** 持續書寫或打字期間續約本機的頁面編輯租約。 */
    @Synchronized
    fun renewLocalPageEdit(pageId: String, nowMs: Long = System.currentTimeMillis()) {
        if (status !is Status.Connected) return
        val canonical = AndroidCollabCanvas.canonicalId(pageId)
        if (canonical.isEmpty()) return
        if (currentBlockingPageEditLease(canonical, nowMs) != null) return

        pageEditReleaseTask?.cancel()
        pageEditReleaseTask = null

        val existing = activePageEditLease
        if (existing != null && existing.userId == currentUserId && existing.pageId == canonical) {
            val updated = existing.copy(updatedAtMs = nowMs)
            activePageEditLease = updated
            if (nowMs - lastPageEditBroadcastAtMs >= PAGE_EDIT_RENEW_INTERVAL_MS) {
                sendLivePageEdit("renew", updated, nowMs)
            }
        } else {
            tryBeginLocalPageEdit(canonical, nowMs)
        }
    }

    /** 結束本機的頁面編輯租約（`immediate = false` 用於提筆後保留短暫緩衝；`true` 用於結束打字或立即釋放）。 */
    @Synchronized
    fun endLocalPageEdit(pageId: String? = null, immediate: Boolean = false) {
        pageEditReleaseTask?.cancel()
        pageEditReleaseTask = null
        val existing = activePageEditLease ?: return
        if (existing.userId != currentUserId) return
        if (!pageId.isNullOrEmpty() && existing.pageId != AndroidCollabCanvas.canonicalId(pageId)) return

        if (immediate) {
            activePageEditLease = null
            sendLivePageEdit("end", existing, System.currentTimeMillis())
        } else {
            val targetPage = existing.pageId
            val timer = pageEditTimer ?: java.util.Timer(true).also { pageEditTimer = it }
            val task = object : java.util.TimerTask() {
                override fun run() {
                    endLocalPageEdit(targetPage, immediate = true)
                }
            }
            pageEditReleaseTask = task
            timer.schedule(task, PAGE_EDIT_POST_STROKE_HOLD_MS)
        }
    }

    /** 接收並仲裁遠端成員的頁面編輯狀態（`live_page_edit`）。 */
    @Synchronized
    fun receiveRemotePageEdit(
        userId: String,
        payload: JSONObject,
        lamport: Long = 0L,
        nowMs: Long = System.currentTimeMillis(),
    ) {
        if (userId == currentUserId) return
        val rawPage = payload.optString("page")
        if (rawPage.isEmpty()) return
        val pageId = AndroidCollabCanvas.canonicalId(rawPage)
        val phase = payload.optString("phase", "begin").ifEmpty { "begin" }
        val started = payload.optLong("started_lamport", if (lamport > 0L) lamport else 1L).coerceAtLeast(1L)
        lamportClock = maxOf(lamportClock, maxOf(lamport, started))

        if (phase == "end") {
            val existing = activePageEditLease
            if (existing != null && existing.userId == userId && existing.pageId == pageId) {
                activePageEditLease = null
            }
            return
        }

        pruneExpiredPageEditLease(nowMs)
        val rawName = payload.optString("user_name").trim()
        val resolvedName = rawName.ifEmpty {
            peers.firstOrNull { it.userId == userId }?.userName ?: userId.take(6)
        }
        val resolvedIsHost = if (payload.has("is_host")) {
            payload.optBoolean("is_host", false)
        } else {
            peers.firstOrNull { it.userId == userId }?.role == "owner"
        }

        val incoming = PageEditLease(
            userId = userId,
            userName = resolvedName,
            isHost = resolvedIsHost,
            pageId = pageId,
            startedLamport = started,
            updatedAtMs = nowMs,
        )

        val existing = activePageEditLease
        if (existing != null) {
            if (existing.userId == userId) {
                val pageChanged = existing.pageId != pageId
                activePageEditLease = incoming
                onPageJumpRequested?.invoke(pageId, phase == "begin" || pageChanged)
                return
            }
            if (existing.pageId != incoming.pageId) {
                // 跨頁同時編輯衝突：以第一個下筆（startedLamport 較小，平手比 userId）為優先。
                if (incoming.hasPriority(over = existing)) {
                    pageEditReleaseTask?.cancel()
                    pageEditReleaseTask = null
                    val wasLocal = (existing.userId == currentUserId)
                    activePageEditLease = incoming
                    if (wasLocal) {
                        onPageEditPreempted?.invoke(incoming)
                    }
                    onPageJumpRequested?.invoke(pageId, true)
                } else if (existing.userId == currentUserId) {
                    sendLivePageEdit("renew", existing, nowMs)
                }
                return
            }
            // 同一頁協同：保留優先權較高者的租約並更新時戳。
            activePageEditLease = if (incoming.hasPriority(over = existing)) {
                incoming
            } else {
                existing.copy(updatedAtMs = nowMs)
            }
            if (phase == "begin") {
                onPageJumpRequested?.invoke(pageId, false)
            }
        } else {
            activePageEditLease = incoming
            onPageJumpRequested?.invoke(pageId, phase == "begin")
        }
    }

    private fun sendLivePageEdit(phase: String, lease: PageEditLease, nowMs: Long) {
        lastPageEditBroadcastAtMs = nowMs
        val raw = JSONObject()
            .put("page", lease.pageId)
            .put("phase", phase)
            .put("started_lamport", lease.startedLamport)
            .put("user_name", lease.userName)
            .put("is_host", lease.isHost)
        val key = roomKeyBase64
        val msg = JSONObject()
            .put("type", "oplog")
            .put("room_id", roomId)
            .put("user_id", currentUserId)
            .put("lamport", lease.startedLamport)
            .put("kind", "live_page_edit")
        val cipher = if (key != null) collabEncrypt(key, raw.toString()) else ""
        if (cipher.isNotEmpty()) {
            msg.put("payload", JSONObject().put("ciphertext", cipher)).put("encrypted", true)
        } else {
            msg.put("payload", raw)
        }
        if (status is Status.Connected) send(msg)
    }

    @Synchronized
    private fun pruneExpiredPageEditLease(nowMs: Long = System.currentTimeMillis()) {
        val existing = activePageEditLease ?: return
        if (nowMs - existing.updatedAtMs >= PAGE_EDIT_LEASE_TIMEOUT_MS) {
            activePageEditLease = null
        }
    }

    @Synchronized
    private fun clearPageEditLeaseIfHeldBy(userId: String) {
        if (activePageEditLease?.userId == userId) {
            activePageEditLease = null
        }
    }

    @Synchronized
    fun resetPageEditLeaseState() {
        pageEditReleaseTask?.cancel()
        pageEditReleaseTask = null
        pageEditTimer?.cancel()
        pageEditTimer = null
        lastPageEditBroadcastAtMs = 0L
        activePageEditLease = null
    }

    private fun send(msg: JSONObject) {
        val text = msg.toString()
        socket?.send(text)
        // 同時開放雲端時，房主自己的操作也送進雲端（見 CollabRelayBridge）。
        if (relayBridge != null) mainHandler.post { relayBridge?.hostSent(JSONObject(text)) }
    }

    private fun drainOfflineQueue() {
        if (offlineQueue.isEmpty()) return
        offlineQueue.forEach { send(it) }
        offlineQueue.clear()
        queuedOplogCount = 0
    }

    // ── 接收 ────────────────────────────────────────────────────

    private inner class Listener : WebSocketListener() {
        override fun onOpen(webSocket: WebSocket, response: Response) {
            val profile = AccountManager.load(context, fallbackName = "Kairumo")
            val rawName = profile.displayName.ifEmpty { "Kairumo" }
            val join = JSONObject()
                .put("type", "join")
                .put("room_id", roomId)
                .put("user_id", currentUserId)
                .put("user_name", "$rawName (Android)")
                .put("user_color", profile.colorHex)
                .put("role", if (isHost) "owner" else "editor")
            webSocket.send(join.toString())
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            handle(text)
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            // 舊連線（已經換成新的一條）的回報不要再處理：會多排一次重連。與 Apple 相同。
            if (socket != null && webSocket !== socket) return
            android.util.Log.w("Collab", "WebSocket failure on $serverAddress: ${t.message}")
            if (candidateServers.isNotEmpty()) {
                val nextServer = candidateServers.removeAt(0)
                android.util.Log.i("Collab", "Fallback to candidate server: $nextServer")
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    serverAddress = nextServer
                    connect(roomId, isHost, isReconnecting = false)
                }
                return
            }
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                lastError = t.message
                if (!userInitiatedDisconnect) scheduleReconnect() else status = Status.Disconnected
            }
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            if (socket != null && webSocket !== socket) return
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                if (!userInitiatedDisconnect) scheduleReconnect() else status = Status.Disconnected
            }
        }
    }

    private fun scheduleReconnect() {
        val max = tuning.maxReconnectAttempts.toInt()
        // 加入過的房間不放棄（只有使用者自己離開才離開）；從沒連上過的照次數上限報錯。
        if (reconnectAttempt >= max && !joinedThisRoom) {
            status = Status.Disconnected
            return
        }
        reconnectAttempt++
        status = Status.Reconnecting(minOf(reconnectAttempt, max), max)
        // 指數退避（最長 16 秒）：連不上時每 0.5 秒重試一次只會讓事情更糟。
        val delayMs = (1L shl (minOf(reconnectAttempt, 5) - 1)) * 1000L
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            if (!userInitiatedDisconnect) connect(roomId, isHost, isReconnecting = true)
        }, delayMs)
    }

    private fun handle(text: String) {
        val json = runCatching { JSONObject(text) }.getOrNull() ?: return
        // 同時開放雲端時，本機中繼這邊的成員與操作也轉進雲端（見 CollabRelayBridge）。
        mainHandler.post { relayBridge?.lanReceived(json) }
        when (json.optString("type")) {
            "joined" -> {
                candidateServers.clear()
                val rId = json.optString("room_id", roomId)
                val peersArray = json.optJSONArray("peers")
                startHeartbeatTimer()
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    val rejoined = joinedThisRoom
                    joinedThisRoom = true
                    status = Status.Connected(rId)
                    lastError = null
                    reconnectAttempt = 0
                    drainOfflineQueue()
                    peersArray?.let { addPeers(it) }
                    if (lastSeq == 0L && peers.isNotEmpty()) onStateSyncNeeded?.invoke()
                    // 斷線重連回來：中繼可能重開過，補發不一定補得齊。加入者向房間要一次整份狀態。與 Apple 相同。
                    else if (rejoined && !isHost && peers.isNotEmpty()) onStateSyncNeeded?.invoke()
                }
                // 新版中繼以序號補發（不會漏掉時鐘較小但較晚到的操作）；舊版中繼忽略 last_seq，
                // 照 last_lamport = 0 從頭補 —— 合併規則冪等，重複收到沒有副作用（設計 §7）。
                send(JSONObject().put("type", "catchup").put("room_id", roomId)
                    .put("last_lamport", 0).put("last_seq", lastSeq))
            }
            "error" -> {
                if (json.optString("code") == "ROOM_FULL") {
                    // 會議室人數已滿：明確告訴使用者，不換中繼、不重連（與 Apple 相同）。
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        disconnect()
                        lastError = L10n.t("collab_err_room_full").replace("%@", MAX_PEERS_PER_ROOM.toString())
                    }
                    return
                }
                val msg = json.optString("message", json.optString("code", "collab_err_connect"))
                android.util.Log.e("Collab", "Relay returned error: $msg")
                if (candidateServers.isNotEmpty()) {
                    val nextServer = candidateServers.removeAt(0)
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        serverAddress = nextServer
                        connect(roomId, isHost, isReconnecting = false)
                    }
                    return
                }
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    lastError = msg
                    status = Status.Disconnected
                }
            }
            "peer_joined" -> {
                val peerObj = json.optJSONObject("peer")
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    peerObj?.let { addPeer(it) }
                    if (lastSeq == 0L) onStateSyncNeeded?.invoke()
                }
            }
            "peer_presence" -> {
                val uid = json.optString("user_id")
                val cursor = json.optJSONObject("cursor") ?: return
                val selected = json.optString("selected_id").takeIf { it.isNotEmpty() }?.let(::canonicalSelection)
                val curX = cursor.optDouble("x", 0.0).toFloat()
                val curY = cursor.optDouble("y", 0.0).toFloat()
                val drawing = cursor.optBoolean("is_drawing", false)
                val now = System.currentTimeMillis()
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    if (uid.isNotEmpty() && uid != currentUserId) {
                        val idx = peers.indexOfFirst { it.userId == uid }
                        if (idx >= 0) {
                            val p = peers[idx]
                            peers[idx] = p.copy(
                                cursorX = curX,
                                cursorY = curY,
                                isDrawing = drawing,
                                selectedId = selected,
                                lastActiveMs = now
                            )
                            // 兩人同時選了同一個物件：使用者 id 較小者勝（每一台算出同一個答案）。打字不搶。
                            val mine = mySelectedId
                            if (selected != null && mine != null && selected == canonicalSelection(mine) &&
                                !selected.startsWith(TYPING_PREFIX) && uid < currentUserId) {
                                onLeaseLost?.invoke(mine, p.userName)
                            }
                        } else {
                            // 自癒：若清單缺失立即加回在線成員
                            peers.add(
                                Peer(
                                    userId = uid,
                                    userName = uid.take(6),
                                    userColor = "#4A90E2",
                                    role = "editor",
                                    cursorX = curX,
                                    cursorY = curY,
                                    isDrawing = drawing,
                                    selectedId = selected,
                                    lastActiveMs = now
                                )
                            )
                        }
                    }
                }
            }
            "peer_left" -> {
                val uid = json.optString("user_id")
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    peers.removeAll { it.userId == uid }
                    liveInk.settle(uid)
                    clearPageEditLeaseIfHeldBy(uid)
                }
            }
            "peer_oplog" -> deliverOplog(json, live = true)
            "oplog_batch" -> {
                val batch = json.optJSONArray("oplogs") ?: return
                for (i in 0 until batch.length()) {
                    batch.optJSONObject(i)?.let { deliverOplog(it, live = false) }
                }
                if (json.optBoolean("truncated", false)) onStateSyncNeeded?.invoke()
            }
            "room_closed" -> {
                disconnect()
                onRoomClosed?.invoke()
            }
            "pong" -> Unit
            "relay_notice" -> {
                // 中繼的提醒（連線照常，不是錯誤）：已在地化的訊息交給編輯器顯示。與 Apple 相同。
                val key = when (json.optString("code")) {
                    "recent_near_limit" -> "relay_notice_recent_near_limit"
                    "store_near_limit" -> "relay_notice_store_near_limit"
                    "store_too_large" -> "relay_notice_store_too_large"
                    else -> return
                }
                relayNotices.tryEmit(L10n.t(key))
            }
        }
    }

    private fun addPeers(array: JSONArray) {
        for (i in 0 until array.length()) {
            array.optJSONObject(i)?.let { addPeer(it) }
        }
    }

    /** 加入成員清單。自己與重複的 id 都跳過 —— 不然清單上會出現兩個自己。 */
    private fun addPeer(dict: JSONObject) {
        val uid = dict.optString("user_id").ifEmpty { return }
        if (uid == currentUserId || peers.any { it.userId == uid }) return
        peers += Peer(
            userId = uid,
            userName = dict.optString("user_name").ifEmpty { uid.take(6) },
            userColor = dict.optString("user_color").ifEmpty { AccountManager.DEFAULT_COLOR },
            role = dict.optString("role").ifEmpty { "editor" }
        )
    }

    /** @param live 即時送達（不是補發）。補發裡的書寫中預覽早就過時了，不畫。 */
    private fun deliverOplog(item: JSONObject, live: Boolean) {
        val uid = item.optString("user_id").ifEmpty { return }
        // 補發會包含自己送過的：自己的修改本機早就套用了。
        if (uid == currentUserId) return
        val oplogNow = System.currentTimeMillis()
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            val idx = peers.indexOfFirst { it.userId == uid }
            if (idx >= 0) {
                peers[idx] = peers[idx].copy(lastActiveMs = oplogNow)
            } else {
                peers.add(
                    Peer(
                        userId = uid,
                        userName = uid.take(6),
                        userColor = "#4A90E2",
                        role = "editor",
                        lastActiveMs = oplogNow
                    )
                )
            }
        }
        val kind = item.optString("kind").ifEmpty { return }
        val raw = item.optJSONObject("payload") ?: return
        if (kind.startsWith("live_")) {
            // 暫態：直接交給預覽層與跨頁編輯仲裁器，不記 op id、不進編輯器的合併流程。
            if (!live) return
            if (kind == "live_page_edit") {
                val lamport = item.optLong("lamport", 0L)
                decryptPayload(item, raw)?.let { receiveRemotePageEdit(uid, it, lamport) }
            } else if (kind == "live_voice") {
                decryptPayload(item, raw)?.let { voice?.receiveRemoteVoice(uid, it) }
            } else if (kind == "live_ink") {
                decryptPayload(item, raw)?.let { payload ->
                    liveInk.receive(uid, payload)
                    val page = payload.optString("page")
                    val ended = payload.optBoolean("end", false)
                    val seq = payload.optInt("seq", 0)
                    if (page.isNotEmpty() && !ended &&
                        (activePageEditLease == null || activePageEditLease?.userId == uid)
                    ) {
                        receiveRemotePageEdit(
                            uid,
                            JSONObject().put("page", page).put("phase", if (seq == 0) "begin" else "renew"),
                            maxOf(1L, lamportClock),
                        )
                    }
                }
            }
            return
        }
        // 寄存的整份狀態只該在補發裡出現：Cloudflare 中繼不轉送它，但自架的 Rust 中繼會把 `state_` 當暫態照轉
        // —— 即時收到就忽略，免得每兩分鐘套一次整份狀態（打字中會被重建基準）。與 Apple 相同。
        if (live && kind == "state_store") return
        if (item.has("seq")) lastSeq = maxOf(lastSeq, item.optLong("seq"))
        if (kind == "ink_add") liveInk.settle(uid)
        val lamport = item.optLong("lamport", 0L).toULong()
        synchronized(this) { lamportClock = maxOf(lamportClock, lamport.toLong()) }

        val payload = if (item.optBoolean("encrypted", false)) {
            val key = roomKeyBase64
            if (key == null) {
                undecryptableCount++
                android.util.Log.w("Collab", "收到加密的 $kind 但這台沒有房間金鑰：丟棄（共 $undecryptableCount 則）")
                return
            }
            val plain = collabDecrypt(key, raw.optString("ciphertext"))
            // 解不開代表對方用的是另一把金鑰。丟掉，不要把密文當內容
            // 寫進筆記 —— 那只會在畫布上留下一串亂碼。
            if (plain.isEmpty()) {
                undecryptableCount++
                android.util.Log.w("Collab", "收到的 $kind 解不開（金鑰不符）：丟棄（共 $undecryptableCount 則）")
                return
            }
            runCatching { JSONObject(plain) }.getOrNull() ?: return
        } else {
            raw
        }
        noteStateChanged(kind)
        payload.optString("op_id").takeIf { it.isNotEmpty() }?.let { opId ->
            synchronized(seenOpIds) {
                if (!seenOpIds.add(opId)) return
                if (seenOpIds.size > 4000) seenOpIds.remove(seenOpIds.first())
            }
        }
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            peers.indexOfFirst { it.userId == uid }.takeIf { it >= 0 }?.let { idx ->
                peers[idx] = peers[idx].copy(lastActiveMs = System.currentTimeMillis())
            }
            pruneStalePeers()
        }
        onOplog?.invoke(RemoteOplog(uid, kind, payload, lamport))
    }

    private fun pruneStalePeers() {
        val now = System.currentTimeMillis()
        val timeoutMs = 18_000L
        val stale = peers.filter { now - it.lastActiveMs > timeoutMs }
        if (stale.isNotEmpty()) {
            for (s in stale) {
                liveInk.settle(s.userId)
                clearPageEditLeaseIfHeldBy(s.userId)
            }
            peers.removeAll { now - it.lastActiveMs > timeoutMs }
        }
    }

    private fun decryptPayload(item: JSONObject, raw: JSONObject): JSONObject? {
        if (!item.optBoolean("encrypted", false)) return raw
        val key = roomKeyBase64 ?: return null
        val plain = collabDecrypt(key, raw.optString("ciphertext"))
        if (plain.isEmpty()) return null
        return runCatching { JSONObject(plain) }.getOrNull()
    }

    // ── 設定 ────────────────────────────────────────────────────

    /** 雲端共享實際用的中繼（見 [cloudRelayUrl]）。 */
    val cloudRelayUrl: String get() = cloudRelayUrl(context)

    private fun loadServer(): String =
        ProfileContext.prefs(context, PREFS)
            .getString(KEY_SERVER, null) ?: tuning.defaultServer

    fun saveServer(address: String) {
        serverAddress = address
        ProfileContext.prefs(context, PREFS)
            .edit().putString(KEY_SERVER, address).apply()
    }

    companion object {
        /** 每間房的人數上限（與 Rust `IN_APP_MAX_PEERS`、Apple `LocalRelayServer.maxPeersPerRoom`、雲端預設 `MAX_PEERS` 相同）。 */
        const val MAX_PEERS_PER_ROOM = 50

        /**
         * 人多時把游標與書寫中預覽放慢的倍數（與 Apple `crowdFactor` 相同）：這兩種訊息每個人都轉給
         * 其他所有人，總量隨人數平方成長。8 人以內照舊；9–20 人放慢一倍；再多放慢三倍。正式筆畫不受影響。
         */
        fun crowdFactor(peerCount: Int): Long = if (peerCount <= 8) 1L else if (peerCount <= 20) 2L else 4L
        /** 多久檢查一次要不要寄存。與 Apple `depositCheckInterval` 相同。 */
        const val DEPOSIT_CHECK_INTERVAL_MS = 30_000L
        /** 兩次寄存的最短間隔。與 Apple `depositMinInterval` 相同。 */
        const val DEPOSIT_MIN_INTERVAL_MS = 120_000L
        /** 在背景超過這個毫秒數，回前景時一律重建連線（與 Apple `backgroundReconnectAfter` 相同）。 */
        const val BACKGROUND_RECONNECT_AFTER_MS = 5_000L

        /**
         * Kairumo 的公開中繼（Cloudflare Workers，見 `deploy/relay-cloudflare`）。與 Apple
         * `CollaborationManager.publicRelayURL` 相同。空字串＝還沒部署：雲端共享照舊只用區網。
         */
        const val PUBLIC_RELAY_URL = "wss://kairumo-relay.kairumo-relay.workers.dev"
        private const val KEY_CLOUD_RELAY = "cloud_relay_url"

        /** 使用者自訂的雲端共享中繼（空字串＝用內建的）。與 Apple `customCloudRelay` 相同。 */
        fun customCloudRelay(context: Context): String =
            ProfileContext.prefs(context, PREFS).getString(KEY_CLOUD_RELAY, "") ?: ""

        fun setCustomCloudRelay(context: Context, address: String) {
            ProfileContext.prefs(context, PREFS).edit().putString(KEY_CLOUD_RELAY, address).apply()
        }

        /** 雲端共享實際用的中繼：自訂的（有效的話）優先，否則內建的。只有房主的設定有作用，邀請會帶上它。 */
        fun cloudRelayUrl(context: Context): String =
            customCloudRelay(context).trim().takeIf { isValidCloudRelay(it) } ?: PUBLIC_RELAY_URL

        /** 雲端共享中繼必須是加密的 `wss://`（跨網路的流量不能走明文）。與 Apple 相同。 */
        fun isValidCloudRelay(address: String): Boolean {
            val text = address.trim()
            if (!text.lowercase().startsWith("wss://")) return false
            val host = runCatching { java.net.URI(text).host }.getOrNull()
            if (host.isNullOrEmpty()) return false
            return uniffi.padnote_core.collabCheckServer(text).ok
        }
        private const val PREFS = "kairumo_collab"
        private const val KEY_SERVER = "relay_server_url"
        /** 編輯租約多久沒續約就失效（與 Apple 端相同）。 */
        const val LEASE_TIMEOUT_MS = 5_000L
        /** 頁面編輯租約逾時毫秒數（與 Apple `pageEditLeaseTimeout` 相同）。 */
        const val PAGE_EDIT_LEASE_TIMEOUT_MS = 4_000L
        /** 手繪提筆後的短暫保留毫秒數（與 Apple `pageEditPostStrokeHold` 相同）。 */
        const val PAGE_EDIT_POST_STROKE_HOLD_MS = 1_200L
        /** 持續書寫／打字期間的租約續約廣播最小間隔毫秒數（與 Apple `pageEditRenewInterval` 相同）。 */
        const val PAGE_EDIT_RENEW_INTERVAL_MS = 800L
        /** 在場資訊裡「正在這個方塊打字」的選取 id 前綴（與 Apple 端相同）。 */
        /**
         * 選取 id 的正規形式（設計 §8.1）：Apple 的附件 id 是大寫 UUID、這裡是核心的小寫 id，
         * 不正規化的話兩個平台的編輯鎖互相看不見。收到時與比對時都過這一關。
         */
        fun canonicalSelection(id: String): String =
            if (id.startsWith(TYPING_PREFIX)) TYPING_PREFIX + AndroidCollabCanvas.canonicalId(id.removePrefix(TYPING_PREFIX))
            else AndroidCollabCanvas.canonicalId(id)

        const val TYPING_PREFIX = "text:"
    }
}

/** 每條連線都設 `TCP_NODELAY` 的 socket 工廠（給協同的 WebSocket 用）。 */
private object NoDelaySocketFactory : javax.net.SocketFactory() {
    private val base = javax.net.SocketFactory.getDefault()
    private fun tuned(s: java.net.Socket) = s.apply { tcpNoDelay = true }
    override fun createSocket(): java.net.Socket = tuned(base.createSocket())
    override fun createSocket(host: String?, port: Int): java.net.Socket = tuned(base.createSocket(host, port))
    override fun createSocket(host: String?, port: Int, localHost: java.net.InetAddress?, localPort: Int): java.net.Socket =
        tuned(base.createSocket(host, port, localHost, localPort))
    override fun createSocket(host: java.net.InetAddress?, port: Int): java.net.Socket = tuned(base.createSocket(host, port))
    override fun createSocket(address: java.net.InetAddress?, port: Int, localAddress: java.net.InetAddress?, localPort: Int): java.net.Socket =
        tuned(base.createSocket(address, port, localAddress, localPort))
}
