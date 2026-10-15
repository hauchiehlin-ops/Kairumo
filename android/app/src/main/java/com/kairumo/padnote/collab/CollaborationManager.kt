package com.kairumo.padnote.collab

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
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

    private val tuning = collabTuning()

    var status by mutableStateOf<Status>(Status.Disconnected)
        private set
    var serverAddress by mutableStateOf(loadServer())
    var roomId by mutableStateOf("")
        private set
    var isHost by mutableStateOf(false)
        private set
    var roomKeyBase64 by mutableStateOf<String?>(null)
        private set
    var lastError by mutableStateOf<String?>(null)
        private set
    var isHostingLocalRelay by mutableStateOf(false)
        private set
    var lanRelayAddress by mutableStateOf<String?>(null)
        private set
    var tailscaleRelayAddress by mutableStateOf<String?>(null)
        private set
    var queuedOplogCount by mutableIntStateOf(0)
        private set

    val peers = mutableStateListOf<Peer>()

    /** 這台裝置的身分。每次啟動換一個 —— 它只用來在房間裡區分人。 */
    val currentUserId: String = UUID.randomUUID().toString()

    /** 收到遠端操作時呼叫。由畫面設定。**在背景執行緒上呼叫**，畫面要自己切回主執行緒。 */
    var onOplog: ((RemoteOplog) -> Unit)? = null
    /** 兩人同時選了同一個物件、對方勝出：本機要放手（設計 §5.3）。參數是物件 id 與對方名字。 */
    var onLeaseLost: ((String, String) -> Unit)? = null
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
        .build()
    private var socket: WebSocket? = null
    private var relay: RelayServer? = null
    private var reconnectAttempt = 0
    private var userInitiatedDisconnect = false
    private val offlineQueue = mutableListOf<JSONObject>()
    private var lastPresenceSentAtMs = 0L
    private var lastCursor = 0f to 0f

    // ── 房間 ────────────────────────────────────────────────────

    fun createRoom() {
        roomKeyBase64 = collabGenerateRoomKey().takeIf { it.isNotEmpty() }
        connect(collabNewRoomId(), asHost = true)
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

        val invite = collabParseInvite(trimmed)
        if (invite.roomId.isEmpty()) {
            lastError = "invalid_room"
            return
        }
        if (invite.keyBase64.isNotEmpty() && collabIsValidRoomKey(invite.keyBase64)) {
            roomKeyBase64 = invite.keyBase64
        }
        connect(invite.roomId, asHost = false)
    }

    fun getInviteLink(useTailscale: Boolean = false): String {
        val base = collabInviteLink(roomId, roomKeyBase64 ?: "")
        val target = if (isHostingLocalRelay) {
            if (useTailscale && tailscaleRelayAddress != null) {
                tailscaleRelayAddress
            } else {
                lanRelayAddress ?: tailscaleRelayAddress
            }
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
        get() = getInviteLink(useTailscale = false)

    val tailscaleInviteLink: String?
        get() = if (tailscaleRelayAddress != null) getInviteLink(useTailscale = true) else null

    private fun connect(room: String, asHost: Boolean, isReconnecting: Boolean = false) {
        // 新的房間從頭來；斷線重連回同一個房間則從看過的序號接著補。
        if (!isReconnecting) lastSeq = 0L
        userInitiatedDisconnect = false
        if (!isReconnecting) {
            disconnect(userInitiated = false)
            reconnectAttempt = 0
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
            isHostingLocalRelay = false
        }
        lastError = null

        val request = runCatching { Request.Builder().url(url.toHttpish()).build() }.getOrNull()
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

    fun getLocalIpAddresses(): Pair<String?, String?> {
        var lanIp: String? = null
        var tailscaleIp: String? = null
        try {
            val interfaces = java.net.NetworkInterface.getNetworkInterfaces() ?: return Pair(null, null)
            for (intf in interfaces.asSequence()) {
                if (!intf.isUp || intf.isLoopback) continue
                for (addr in intf.inetAddresses.asSequence()) {
                    if (addr is java.net.Inet4Address && !addr.isLoopbackAddress) {
                        val hostAddress = addr.hostAddress ?: continue
                        if (hostAddress.startsWith("100.")) {
                            val parts = hostAddress.split(".")
                            if (parts.size == 4) {
                                val second = parts[1].toIntOrNull() ?: 0
                                if (second in 64..127) {
                                    tailscaleIp = hostAddress
                                }
                            }
                        } else if (!hostAddress.startsWith("127.") && !hostAddress.startsWith("169.254.")) {
                            if (lanIp == null || intf.name.startsWith("wlan") || intf.name.startsWith("eth")) {
                                lanIp = hostAddress
                            }
                        }
                    }
                }
            }
        } catch (_: Exception) {}
        return Pair(lanIp, tailscaleIp)
    }

    private fun startLocalRelay(port: Int) {
        val p = if (port in 1..65535) port.toUShort() else 9002u
        val server = relay ?: RelayServer().also { relay = it }
        // 埠被佔用通常代表已經有一個中繼在聽，照常連過去就好，不是致命錯誤。
        val ok = runCatching { server.start(p); server.isRunning() }.getOrDefault(false)
        isHostingLocalRelay = ok
        if (ok) {
            val (lan, ts) = getLocalIpAddresses()
            lanRelayAddress = lan?.let { "ws://$it:$p" }
            tailscaleRelayAddress = ts?.let { "ws://$it:$p" }
        } else {
            lanRelayAddress = null
            tailscaleRelayAddress = null
        }
    }

    fun disconnect(userInitiated: Boolean = true) {
        if (userInitiated) {
            userInitiatedDisconnect = true
            reconnectAttempt = 0
            offlineQueue.clear()
            queuedOplogCount = 0
            roomKeyBase64 = null
        }
        socket?.close(1000, null)
        socket = null
        peers.clear()
        if (userInitiated) {
            runCatching { relay?.stop() }
            isHostingLocalRelay = false
            lanRelayAddress = null
            tailscaleRelayAddress = null
            status = Status.Disconnected
        }
    }

    // ── 廣播 ────────────────────────────────────────────────────

    /** 游標。30Hz 節流 —— 不節流的話一次手寫會送出上千則訊息把中繼灌爆。 */
    fun broadcastCursor(x: Float, y: Float, isDrawing: Boolean, tool: String, selectedId: String? = null) {
        val connected = status as? Status.Connected ?: return
        lastCursor = x to y
        val now = System.currentTimeMillis()
        if (now - lastPresenceSentAtMs < tuning.presenceThrottleMs.toLong()) return
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

    /**
     * 持久化操作。連線中斷時進離線佇列，重連後補送 ——
     * 丟掉的話使用者畫的東西不會出現在對方畫面上，而且沒有人會發現。
     */
    fun broadcastOplog(kind: String, payload: JSONObject, lamport: Long? = null): Long {
        val key = roomKeyBase64
        // 時鐘由這裡配發（或由呼叫端事先以 nextLamport() 取得）；操作 id 放在 payload 裡 ——
        // 三份中繼都原樣轉送 payload，但不見得保留外層的其他欄位。
        val stamp = lamport ?: nextLamport()
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

        if (status is Status.Connected) {
            send(msg)
        } else {
            offlineQueue += msg
            queuedOplogCount = offlineQueue.size
        }
        return stamp
    }

    private fun send(msg: JSONObject) {
        socket?.send(msg.toString())
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
            lastError = t.message
            if (!userInitiatedDisconnect) scheduleReconnect() else status = Status.Disconnected
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            if (!userInitiatedDisconnect) scheduleReconnect() else status = Status.Disconnected
        }
    }

    private fun scheduleReconnect() {
        if (reconnectAttempt >= tuning.maxReconnectAttempts.toInt()) {
            status = Status.Disconnected
            return
        }
        reconnectAttempt++
        status = Status.Reconnecting(reconnectAttempt, tuning.maxReconnectAttempts.toInt())
        // 指數退避：連不上時每 0.5 秒重試一次只會讓事情更糟。
        val delayMs = (1L shl (reconnectAttempt - 1)) * 1000L
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            if (!userInitiatedDisconnect) connect(roomId, isHost, isReconnecting = true)
        }, delayMs)
    }

    private fun handle(text: String) {
        val json = runCatching { JSONObject(text) }.getOrNull() ?: return
        when (json.optString("type")) {
            "joined" -> {
                status = Status.Connected(json.optString("room_id", roomId))
                lastError = null
                reconnectAttempt = 0
                drainOfflineQueue()
                json.optJSONArray("peers")?.let { addPeers(it) }
                // 第一次進這個房間、而且裡面有人：向他們要整份狀態（這台的檔案可能比較舊，設計 §7）。
                if (lastSeq == 0L && peers.isNotEmpty()) onStateSyncNeeded?.invoke()
                // 新版中繼以序號補發（不會漏掉時鐘較小但較晚到的操作）；舊版中繼忽略 last_seq，
                // 照 last_lamport = 0 從頭補 —— 合併規則冪等，重複收到沒有副作用（設計 §7）。
                send(JSONObject().put("type", "catchup").put("room_id", roomId)
                    .put("last_lamport", 0).put("last_seq", lastSeq))
            }
            "peer_joined" -> json.optJSONObject("peer")?.let { addPeer(it) }
            "peer_presence" -> {
                val uid = json.optString("user_id")
                val cursor = json.optJSONObject("cursor") ?: return
                peers.indexOfFirst { it.userId == uid }.takeIf { it >= 0 }?.let { idx ->
                    val p = peers[idx]
                    val selected = json.optString("selected_id").takeIf { it.isNotEmpty() }?.let(::canonicalSelection)
                    peers[idx] = p.copy(
                        cursorX = cursor.optDouble("x", 0.0).toFloat(),
                        cursorY = cursor.optDouble("y", 0.0).toFloat(),
                        isDrawing = cursor.optBoolean("is_drawing", false),
                        selectedId = selected,
                        lastActiveMs = System.currentTimeMillis()
                    )
                    // 兩人同時選了同一個物件：使用者 id 較小者勝（每一台算出同一個答案）。打字不搶。
                    val mine = mySelectedId
                    if (selected != null && mine != null && selected == canonicalSelection(mine) &&
                        !selected.startsWith(TYPING_PREFIX) && uid < currentUserId) {
                        onLeaseLost?.invoke(mine, p.userName)
                    }
                }
            }
            "peer_left" -> {
                val uid = json.optString("user_id")
                peers.removeAll { it.userId == uid }
            }
            "peer_oplog" -> deliverOplog(json)
            "oplog_batch" -> {
                val batch = json.optJSONArray("oplogs") ?: return
                for (i in 0 until batch.length()) {
                    batch.optJSONObject(i)?.let { deliverOplog(it) }
                }
                if (json.optBoolean("truncated", false)) onStateSyncNeeded?.invoke()
            }
            "room_closed" -> disconnect()
            "pong" -> Unit
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

    private fun deliverOplog(item: JSONObject) {
        if (item.has("seq")) lastSeq = maxOf(lastSeq, item.optLong("seq"))
        val uid = item.optString("user_id").ifEmpty { return }
        // 補發會包含自己送過的：自己的修改本機早就套用了。
        if (uid == currentUserId) return
        val kind = item.optString("kind").ifEmpty { return }
        val raw = item.optJSONObject("payload") ?: return
        val lamport = item.optLong("lamport", 0L).toULong()
        synchronized(this) { lamportClock = maxOf(lamportClock, lamport.toLong()) }

        val payload = if (item.optBoolean("encrypted", false)) {
            val key = roomKeyBase64 ?: return
            val plain = collabDecrypt(key, raw.optString("ciphertext"))
            // 解不開代表對方用的是另一把金鑰。丟掉，不要把密文當內容
            // 寫進筆記 —— 那只會在畫布上留下一串亂碼。
            if (plain.isEmpty()) return
            runCatching { JSONObject(plain) }.getOrNull() ?: return
        } else {
            raw
        }
        payload.optString("op_id").takeIf { it.isNotEmpty() }?.let { opId ->
            synchronized(seenOpIds) {
                if (!seenOpIds.add(opId)) return
                if (seenOpIds.size > 4000) seenOpIds.remove(seenOpIds.first())
            }
        }
        onOplog?.invoke(RemoteOplog(uid, kind, payload, lamport))
    }

    // ── 設定 ────────────────────────────────────────────────────

    private fun loadServer(): String =
        ProfileContext.prefs(context, PREFS)
            .getString(KEY_SERVER, null) ?: tuning.defaultServer

    fun saveServer(address: String) {
        serverAddress = address
        ProfileContext.prefs(context, PREFS)
            .edit().putString(KEY_SERVER, address).apply()
    }

    companion object {
        private const val PREFS = "kairumo_collab"
        private const val KEY_SERVER = "relay_server_url"
        /** 編輯租約多久沒續約就失效（與 Apple 端相同）。 */
        const val LEASE_TIMEOUT_MS = 5_000L
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
