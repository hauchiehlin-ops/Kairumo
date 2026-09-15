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
        var selectedId: String? = null
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
    var queuedOplogCount by mutableIntStateOf(0)
        private set

    val peers = mutableStateListOf<Peer>()

    /** 這台裝置的身分。每次啟動換一個 —— 它只用來在房間裡區分人。 */
    val currentUserId: String = UUID.randomUUID().toString()

    /** 收到遠端操作時呼叫。由畫面設定。 */
    var onOplog: ((RemoteOplog) -> Unit)? = null

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
        val invite = collabParseInvite(text)
        if (invite.roomId.isEmpty()) {
            lastError = "invalid_room"
            return
        }
        if (invite.keyBase64.isNotEmpty() && collabIsValidRoomKey(invite.keyBase64)) {
            roomKeyBase64 = invite.keyBase64
        }
        connect(invite.roomId, asHost = false)
    }

    val inviteLink: String
        get() = collabInviteLink(roomId, roomKeyBase64 ?: "")

    private fun connect(room: String, asHost: Boolean, isReconnecting: Boolean = false) {
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
        val host = runCatching { java.net.URI(url).host ?: "" }.getOrDefault("")
        if (collabIsLoopbackHost(host)) {
            startLocalRelay(runCatching { java.net.URI(url).port }.getOrDefault(-1))
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

    private fun startLocalRelay(port: Int) {
        val p = if (port in 1..65535) port.toUShort() else 9002u
        val server = relay ?: RelayServer().also { relay = it }
        // 埠被佔用通常代表已經有一個中繼在聽，照常連過去就好，不是致命錯誤。
        isHostingLocalRelay = runCatching { server.start(p); server.isRunning() }.getOrDefault(false)
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
    fun broadcastOplog(kind: String, payload: JSONObject, lamport: ULong = 1uL) {
        val key = roomKeyBase64
        val msg = JSONObject()
            .put("type", "oplog")
            .put("room_id", roomId)
            .put("user_id", currentUserId)
            .put("lamport", lamport.toLong())
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
            val join = JSONObject()
                .put("type", "join")
                .put("room_id", roomId)
                .put("user_id", currentUserId)
                .put("user_name", profile.displayName)
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
            }
            "peer_joined" -> json.optJSONObject("peer")?.let { addPeer(it) }
            "peer_presence" -> {
                val uid = json.optString("user_id")
                val cursor = json.optJSONObject("cursor") ?: return
                peers.indexOfFirst { it.userId == uid }.takeIf { it >= 0 }?.let { idx ->
                    val p = peers[idx]
                    peers[idx] = p.copy(
                        cursorX = cursor.optDouble("x", 0.0).toFloat(),
                        cursorY = cursor.optDouble("y", 0.0).toFloat(),
                        isDrawing = cursor.optBoolean("is_drawing", false),
                        selectedId = json.optString("selected_id").takeIf { it.isNotEmpty() }
                    )
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
        val uid = item.optString("user_id").ifEmpty { return }
        val kind = item.optString("kind").ifEmpty { return }
        val raw = item.optJSONObject("payload") ?: return
        val lamport = item.optLong("lamport", 0L).toULong()

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
        onOplog?.invoke(RemoteOplog(uid, kind, payload, lamport))
    }

    // ── 設定 ────────────────────────────────────────────────────

    private fun loadServer(): String =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_SERVER, null) ?: tuning.defaultServer

    fun saveServer(address: String) {
        serverAddress = address
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY_SERVER, address).apply()
    }

    private companion object {
        const val PREFS = "kairumo_collab"
        const val KEY_SERVER = "relay_server_url"
    }
}
