package com.kairumo.padnote.collab

import android.os.Handler
import android.os.Looper
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONArray
import org.json.JSONObject

/**
 * 同一間會議室同時開放「同一 Wi‑Fi」與「雲端共享（跨網路）」。與 Apple `CollabRelayBridge` 同一套。
 *
 * 房主同一時間只連得上一個中繼。以前會議室開在本機中繼時，掃雲端 QR Code 的人進到房主不在的雲端房間：
 * 拿得到寄存的整本內容，房主的在線成員卻看不到他、也無法一起編輯。實際使用時協作者不一定在同一個 Wi‑Fi。
 *
 * 雲端中繼把每條連線綁定到加入時的 user_id，不能用一條連線代轉別人的訊息，所以房主當橋：
 * - 會議室開在房主的本機中繼上（房主自己的連線照舊）。
 * - Wi‑Fi 這邊的每個人（含房主）在雲端中繼各有一條代理連線；他的操作由房主轉進雲端。
 * - 雲端那邊的每個人在本機中繼各有一條代理連線；他的操作由房主轉進本機中繼。
 * - 雲端的訊息從「房主在雲端的代理連線」收；其他代理連線只送不收。
 *
 * 內容原樣轉送（同房號、同一把金鑰，中繼本來就看不到內容）。所有狀態只在主執行緒上動。
 */
class CollabRelayBridge(
    val cloudUrl: String,
    private val lanUrl: String,
    private val roomId: String,
    private val host: Member,
) {
    data class Member(val userId: String, val name: String, val color: String)

    private class Link(val userId: String) {
        var socket: WebSocket? = null
        var alive = true
    }

    private val main = Handler(Looper.getMainLooper())
    private val client = OkHttpClient.Builder().build()

    /** Wi‑Fi 這邊的人（含房主）→ 他在雲端的代理連線。 */
    private val lanMembers = mutableMapOf<String, Member>()
    private val cloudLinks = mutableMapOf<String, Link>()
    /** 雲端那邊的人 → 他在本機中繼的代理連線。 */
    private val cloudMembers = mutableMapOf<String, Member>()
    private val lanLinks = mutableMapOf<String, Link>()
    private var stopped = false
    private val pinger = object : Runnable {
        override fun run() {
            if (stopped) return
            (cloudLinks.values + lanLinks.values).forEach { send(JSONObject().put("type", "ping"), it) }
            main.postDelayed(this, 20_000L)
        }
    }

    /** 目前經由橋接進來的雲端成員（停止後交給下一座橋，免得被誤當成 Wi‑Fi 這邊的人）。 */
    val cloudUserIds: Set<String> get() = cloudMembers.keys.toSet()

    fun start(lanPeers: List<Member>, excluding: Set<String>) {
        lanMembers[host.userId] = host
        openCloudLink(host, "owner")
        lanPeers.filter { it.userId !in excluding }.forEach { addLanMember(it) }
        main.postDelayed(pinger, 20_000L)
    }

    fun stop() {
        if (stopped) return
        stopped = true
        main.removeCallbacks(pinger)
        (cloudLinks.values + lanLinks.values).forEach { close(it) }
        cloudLinks.clear()
        lanLinks.clear()
    }

    // ── 房主在本機中繼的連線（Wi‑Fi 這邊）──

    fun lanReceived(json: JSONObject) {
        if (stopped) return
        when (val type = json.optString("type")) {
            "joined" -> json.optJSONArray("peers")?.let { members(it).forEach(::addLanMember) }
            "peer_joined" -> json.optJSONObject("peer")?.let(::member)?.let(::addLanMember)
            "peer_left" -> removeLanMember(json.optString("user_id"))
            "peer_oplog", "peer_presence" -> {
                val uid = json.optString("user_id")
                if (uid.isEmpty() || uid == host.userId || uid !in lanMembers) return
                if (json.optString("kind") == "state_store") return
                cloudLinks[uid]?.let { send(rewrap(json, if (type == "peer_oplog") "oplog" else "presence"), it) }
            }
        }
    }

    /** 房主自己送出的訊息：操作、游標、寄存與結束會議也送進雲端。 */
    fun hostSent(msg: JSONObject) {
        if (stopped) return
        val type = msg.optString("type")
        if (type != "oplog" && type != "presence" && type != "close_room") return
        val link = cloudLinks[host.userId] ?: return
        send(JSONObject(msg.toString()).put("room_id", roomId), link)
    }

    // ── 房主在雲端的代理連線（雲端那邊）──

    private fun cloudReceived(text: String) {
        if (stopped) return
        val json = runCatching { JSONObject(text) }.getOrNull() ?: return
        when (val type = json.optString("type")) {
            "joined" -> json.optJSONArray("peers")?.let { members(it).forEach(::addCloudMember) }
            "peer_joined" -> json.optJSONObject("peer")?.let(::member)?.let(::addCloudMember)
            "peer_left" -> removeCloudMember(json.optString("user_id"))
            "peer_oplog", "peer_presence" -> {
                val uid = json.optString("user_id")
                if (uid.isEmpty() || uid == host.userId || uid in lanMembers) return
                if (json.optString("kind") == "state_store") return
                if (uid !in cloudMembers) addCloudMember(Member(uid, uid.take(6), "#4A90E2"))
                lanLinks[uid]?.let { send(rewrap(json, if (type == "peer_oplog") "oplog" else "presence"), it) }
            }
        }
    }

    // ── 成員 ──

    private fun addLanMember(m: Member) {
        if (m.userId == host.userId || m.userId in cloudMembers || m.userId in lanMembers) return
        lanMembers[m.userId] = m
        openCloudLink(m, "editor")
    }

    private fun removeLanMember(uid: String) {
        if (uid.isEmpty() || uid == host.userId || lanMembers.remove(uid) == null) return
        cloudLinks.remove(uid)?.let { close(it) }
    }

    private fun addCloudMember(m: Member) {
        if (m.userId == host.userId || m.userId in lanMembers || m.userId in cloudMembers) return
        // 先記下再開代理連線：房主自己的連線收到他的 `peer_joined` 時才認得出是雲端那邊的人。
        cloudMembers[m.userId] = m
        openLanLink(m)
    }

    private fun removeCloudMember(uid: String) {
        if (cloudMembers.remove(uid) == null) return
        lanLinks.remove(uid)?.let { close(it) }
    }

    // ── 連線 ──

    private fun openCloudLink(m: Member, role: String) {
        val isHostLink = m.userId == host.userId
        cloudLinks[m.userId] = open(cloudUrl, m, role, if (isHostLink) ::cloudReceived else null) {
            if (isHostLink || m.userId in lanMembers) openCloudLink(lanMembers[m.userId] ?: m, role)
        }
    }

    private fun openLanLink(m: Member) {
        lanLinks[m.userId] = open(lanUrl, m, "editor", null) {
            cloudMembers[m.userId]?.let { openLanLink(it) }
        }
    }

    /** 開一條代理連線並以 [m] 的身分加入；斷了 3 秒後以同一個身分重開（人還在的話）。 */
    private fun open(address: String, m: Member, role: String, onText: ((String) -> Unit)?, reopen: () -> Unit): Link {
        val link = Link(m.userId)
        val url = roomUrl(address).replaceFirst("wss://", "https://").replaceFirst("ws://", "http://")
        val request = runCatching { Request.Builder().url(url).build() }.getOrNull() ?: return link.also { it.alive = false }
        link.socket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                webSocket.send(
                    JSONObject().put("type", "join").put("room_id", roomId).put("user_id", m.userId)
                        .put("user_name", m.name).put("user_color", m.color).put("role", role).toString()
                )
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                if (onText != null) main.post { if (link.alive) onText(text) }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) = dropped()
            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) = dropped()

            private fun dropped() {
                main.post {
                    if (!link.alive) return@post
                    link.alive = false
                    if (!stopped) main.postDelayed({ if (!stopped) reopen() }, 3_000L)
                }
            }
        })
        return link
    }

    private fun close(link: Link) {
        if (!link.alive) return
        link.alive = false
        val s = link.socket ?: return
        runCatching { s.send(JSONObject().put("type", "leave").put("room_id", roomId).put("user_id", link.userId).toString()) }
        main.postDelayed({ runCatching { s.close(1000, null) } }, 150L)
    }

    private fun send(msg: JSONObject, link: Link) {
        if (!link.alive) return
        runCatching { link.socket?.send(msg.toString()) }
    }

    /** 網址加上 `room=<房號>`（Cloudflare 以它決定房間；本機中繼不看）。與 [CollaborationManager] 相同。 */
    private fun roomUrl(address: String): String = runCatching {
        val uri = android.net.Uri.parse(address)
        val builder = uri.buildUpon().clearQuery()
        for (name in uri.queryParameterNames) {
            if (name == "room") continue
            for (value in uri.getQueryParameters(name)) builder.appendQueryParameter(name, value)
        }
        builder.appendQueryParameter("room", roomId).build().toString()
    }.getOrDefault(address)

    private fun member(o: JSONObject): Member? {
        val uid = o.optString("user_id").ifEmpty { return null }
        return Member(uid, o.optString("user_name").ifEmpty { uid.take(6) }, o.optString("user_color").ifEmpty { "#4A90E2" })
    }

    private fun members(arr: JSONArray): List<Member> =
        (0 until arr.length()).mapNotNull { arr.optJSONObject(it)?.let(::member) }

    /** 中繼轉來的 `peer_oplog`／`peer_presence` 改回送出時的 `oplog`／`presence`（拿掉中繼加的序號）。 */
    private fun rewrap(json: JSONObject, type: String): JSONObject {
        val out = JSONObject(json.toString())
        out.put("type", type)
        out.put("room_id", roomId)
        out.remove("seq")
        return out
    }
}
