package com.kairumo.padnote.collab

import android.app.Activity
import android.content.Context
import com.kairumo.padnote.L10n
import com.kairumo.padnote.library.NotebookLibrary
import com.kairumo.padnote.sync.FocusSync
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import uniffi.padnote_core.FfiCloudPresence
import uniffi.padnote_core.FfiCollabInviteV2
import uniffi.padnote_core.FfiDriveAccess
import uniffi.padnote_core.FfiDriveMember
import uniffi.padnote_core.FfiP2pFrame
import uniffi.padnote_core.FfiPeerLink
import uniffi.padnote_core.FfiPeerListener
import uniffi.padnote_core.FfiPeerState
import uniffi.padnote_core.FfiSharedNotebook
import uniffi.padnote_core.FfiSyncSession
import java.io.File

/**
 * 雲端協作（Android）。與 Apple `CloudCollabManager` 同一套規則：
 *
 * 1. **共享雲端資料夾**：共同的底稿與跨網路通道（每人寫自己的事件檔，不會互蓋）。
 * 2. **點對點直連**（WebRTC）：信令走共享資料夾，連上後把剛寫出的事件檔直接推給對方。
 * 3. **區網中繼**：同一個網路時即時筆跡與游標（由編輯器的 `CollaborationManager` 連線，見 [relayInvite]）。
 *
 * Android 的套件就是工作資料：收到事件檔寫進套件之後，只要通知編輯器重開（`FocusSync.publishRemote`）。
 */
// profile-scope: device 共享清單與權杖都存在依設定檔命名的偏好檔；切換設定檔會重啟行程，記憶體狀態不跨設定檔
object CloudCollab {
    private const val PREFS = "kairumo_cloud_collab"
    private const val KEY_REGISTRY = "registry"
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val _registry = MutableStateFlow<List<FfiSharedNotebook>>(emptyList())
    val registry: StateFlow<List<FfiSharedNotebook>> = _registry
    private val _presences = MutableStateFlow<List<FfiCloudPresence>>(emptyList())
    val presences: StateFlow<List<FfiCloudPresence>> = _presences
    private val _directPeers = MutableStateFlow(0)
    val directPeers: StateFlow<Int> = _directPeers
    private val _busy = MutableStateFlow<String?>(null)
    val busy: StateFlow<String?> = _busy
    val lastError = MutableStateFlow<String?>(null)
    /** 外面送進來、等使用者確認的邀請。 */
    val pendingInvite = MutableStateFlow<FfiCollabInviteV2?>(null)
    /** 加入完成、要打開的筆記本（首頁接手）。 */
    val openRequest = MutableStateFlow<String?>(null)
    /** 剛加入的共享筆記要自動接上的即時中繼（編輯器接手）。 */
    val relayInvite = MutableStateFlow<FfiCollabInviteV2?>(null)

    private var appContext: Context? = null
    private val sessions = HashMap<String, FfiSyncSession>()
    var focusedId: String? = null
        private set
    private var loop: Job? = null
    private var lastRemoteChange = 0L
    private var lastLocalEdit = 0L
    private var lastPresenceAt = 0L
    private var myPage = 0u
    private var mySelection = ""
    private val links = HashMap<UInt, FfiPeerLink>()
    private val linkOpenedAt = HashMap<UInt, Long>()
    private val connected = HashSet<UInt>()
    private val failedAt = HashMap<UInt, Long>()
    private var sentSizes = HashMap<String, ULong>()
    private var refreshPending = false

    private fun deviceId(): UInt = com.kairumo.padnote.sync.AutoSync.currentDeviceId()

    fun init(context: Context) {
        appContext = context.applicationContext
        _registry.value = uniffi.padnote_core.sharedRegistryList(registryJson(context))
    }

    private fun prefs(context: Context) =
        com.kairumo.padnote.profile.ProfileContext.prefs(context, PREFS)

    private fun registryJson(context: Context): String = prefs(context).getString(KEY_REGISTRY, "") ?: ""

    private fun saveRegistry(context: Context, json: String) {
        prefs(context).edit().putString(KEY_REGISTRY, json).apply()
        _registry.value = uniffi.padnote_core.sharedRegistryList(json)
    }

    fun shared(context: Context, notebookId: String): FfiSharedNotebook? =
        uniffi.padnote_core.sharedRegistryFind(registryJson(context), notebookId)

    private fun packageDir(context: Context, notebookId: String): File =
        com.kairumo.padnote.sync.LanLink.findPackage(context, notebookId)
            ?: File(NotebookLibrary.directory(context), "$notebookId.padnote")

    private fun session(context: Context, entry: FfiSharedNotebook): FfiSyncSession? {
        sessions[entry.folderId]?.let { return it }
        val http = CollabDriveAuth.makeHttp(context) ?: return null
        return FfiSyncSession.createShared(http, entry.folderId, "").also { sessions[entry.folderId] = it }
    }

    // ── 房主：分享 ─────────────────────────────────────────

    /** 分享一本筆記。`email` 為空＝「知道連結的人都能編輯」。回傳邀請連結。 */
    suspend fun share(
        activity: Activity, collab: CollaborationManager, notebookId: String, title: String, email: String
    ): String? {
        lastError.value = null
        _busy.value = L10n.t("cloud_collab_sharing")
        try {
            // 憑證沒有、或有但已失效，都在這一次點擊裡開授權畫面（舊版要按兩次，與 Apple 相同）。
            var maybeHttp = if (CollabDriveAuth.isAuthorized(activity)) {
                withContext(Dispatchers.IO) { CollabDriveAuth.makeHttp(activity) }
            } else null
            if (maybeHttp == null) {
                val auth = CollabDriveAuth.authorize(activity)
                if (!auth.ok) {
                    if (auth.error != "cancelled") lastError.value = L10n.t("cloud_collab_err_reauth")
                    return null
                }
                maybeHttp = withContext(Dispatchers.IO) { CollabDriveAuth.makeHttp(activity) }
            }
            val http = maybeHttp ?: run { lastError.value = L10n.t("cloud_collab_err_reauth"); return null }
            var entry = shared(activity, notebookId)
            if (entry == null) {
                val created = withContext(Dispatchers.IO) { uniffi.padnote_core.collabDriveCreateFolder(http, title) }
                if (!created.ok) {
                    lastError.value = if (created.needsReauth) L10n.t("cloud_collab_err_reauth") else created.error
                    return null
                }
                entry = FfiSharedNotebook(notebookId, created.id, "", "", "owner", title)
            }
            val mail = email.trim()
            val granted = withContext(Dispatchers.IO) {
                if (mail.isEmpty()) uniffi.padnote_core.collabDriveGrantLink(http, entry.folderId)
                else uniffi.padnote_core.collabDriveGrant(http, entry.folderId, mail)
            }
            if (!granted.ok) {
                lastError.value = if (granted.error == "invalid_email") L10n.t("cloud_collab_err_email") else granted.error
                return null
            }
            // 即時房間：有公開中繼就開在公開中繼上（跨網路也即時）；沒有的話照舊開在本機（同一個網路才連得到）。
            if (CollaborationManager.PUBLIC_RELAY_URL.isNotEmpty()) {
                ensurePublicRoom(entry, collab)
            } else if (collab.status is CollaborationManager.Status.Disconnected) {
                collab.createRoom()
            }
            repeat(30) { if (collab.roomKeyBase64 == null || collab.roomId.isEmpty()) delay(100) }
            entry = entry.copy(roomId = collab.roomId, keyBase64 = collab.roomKeyBase64 ?: "")
            // 登記要在整本推上去之後才算數：推失敗就還原，面板不會誤切到「已分享」（與 Apple 相同）。
            val registryBefore = registryJson(activity)
            saveRegistry(activity, uniffi.padnote_core.sharedRegistryUpsert(registryBefore, entry))
            val s = withContext(Dispatchers.IO) { session(activity, entry) } ?: run {
                saveRegistry(activity, registryBefore)
                lastError.value = L10n.t("cloud_collab_err_reauth")
                return null
            }
            val pkg = packageDir(activity, notebookId)
            val result = withContext(Dispatchers.IO) {
                com.kairumo.padnote.ink.InkPackageWriter.withSyncLock {
                    s.syncNotebook(pkg.absolutePath, notebookId.lowercase(), deviceId())
                }
            }
            if (!result.ok) {
                saveRegistry(activity, registryBefore)
                lastError.value = result.error.ifEmpty { L10n.t("cloud_collab_err_retry") }
                return null
            }
            val files = uniffi.padnote_core.packageOpFileSizes(pkg.absolutePath).size.toUInt()
            return inviteLink(entry, collab, files)
        } finally {
            _busy.value = null
        }
    }

    /**
     * 房主：這本雲端共享筆記的即時房間開在公開中繼上。已經在那裡就不動；記過房號與金鑰就沿用
     * （重開之後，之前發出去的邀請照樣有效）。與 Apple `ensurePublicRoom` 相同。
     */
    fun ensurePublicRoom(entry: FfiSharedNotebook, collab: CollaborationManager) {
        val relay = CollaborationManager.PUBLIC_RELAY_URL
        if (relay.isEmpty() || entry.role != "owner") return
        if (collab.serverAddress == relay && collab.status !is CollaborationManager.Status.Disconnected) return
        if (entry.roomId.isNotEmpty() && entry.keyBase64.isNotEmpty()) {
            collab.hostRoom(entry.roomId, entry.keyBase64, relay)
        } else {
            collab.createRoom(server = relay)
        }
    }

    fun inviteLink(entry: FfiSharedNotebook, collab: CollaborationManager?, minFiles: UInt = 0u): String =
        uniffi.padnote_core.collabInviteLinkV2(
            FfiCollabInviteV2(
                roomId = entry.roomId.ifEmpty { collab?.roomId.orEmpty() },
                keyBase64 = entry.keyBase64.ifEmpty { collab?.roomKeyBase64.orEmpty() },
                // 有公開中繼：邀請只帶它（大家連同一台）。沒有：照舊帶區網／Tailscale 位址。
                servers = if (CollaborationManager.PUBLIC_RELAY_URL.isNotEmpty()) listOf(CollaborationManager.PUBLIC_RELAY_URL)
                    else listOfNotNull(collab?.lanRelayAddress, collab?.tailscaleRelayAddress),
                notebookId = entry.notebookId, driveFolderId = entry.folderId,
                title = entry.title, minFiles = minFiles
            )
        )

    suspend fun members(context: Context, entry: FfiSharedNotebook): List<FfiDriveMember> =
        withContext(Dispatchers.IO) {
            val http = CollabDriveAuth.makeHttp(context) ?: return@withContext emptyList()
            uniffi.padnote_core.collabDriveMembers(http, entry.folderId).members
        }

    suspend fun revoke(context: Context, entry: FfiSharedNotebook, member: FfiDriveMember): Boolean =
        withContext(Dispatchers.IO) {
            val http = CollabDriveAuth.makeHttp(context) ?: return@withContext false
            uniffi.padnote_core.collabDriveRevoke(http, entry.folderId, member.permissionId).ok
        }

    fun stopSharing(context: Context, notebookId: String) {
        if (focusedId.equals(notebookId, ignoreCase = true)) setFocus(null)
        saveRegistry(context, uniffi.padnote_core.sharedRegistryRemove(registryJson(context), notebookId))
    }

    /**
     * 結束線上協同作業：
     * 1. 若為原發起者（房主），自動在背景刪除雲端硬碟中該次作業的子資料夾（保留「Kairumo Co.」主資料夾）
     * 2. 結束即時中繼連線
     * 3. 本機解除雲端同步登記（stopSharing），筆記本檔案與所有內容各自立即留存於參與者本機。
     */
    suspend fun endCollaboration(context: Context, notebookId: String, collab: CollaborationManager? = null) {
        val entry = shared(context, notebookId)
        val isOwner = entry?.role == "owner"
        val folderId = entry?.folderId.orEmpty()

        if (isOwner && folderId.isNotEmpty()) {
            val http = withContext(Dispatchers.IO) { CollabDriveAuth.makeHttp(context) }
            if (http != null) {
                withContext(Dispatchers.IO) {
                    uniffi.padnote_core.collabDriveDeleteFolder(http, folderId)
                }
            }
        }

        collab?.disconnect()
        stopSharing(context, notebookId)
    }

    // ── 協作者：加入 ───────────────────────────────────────

    /** 收到邀請。有雲端資料夾的才由這裡處理。 */
    fun offer(link: String?): Boolean {
        val invite = uniffi.padnote_core.collabParseInviteV2(link ?: return false)
        if (invite.driveFolderId.isEmpty() || invite.notebookId.isEmpty()) return false
        // 邀請帶著公開中繼（`wss://`）：直接走即時房間加入（與掃同一 Wi-Fi 的 QR Code 同一條路），
        // 不必授權 Google、也不必從雲端硬碟下載 —— 加入後由房主的整份狀態補齊內容（與 Apple 相同）。
        if (invite.servers.any { it.lowercase().startsWith("wss://") }) return false
        pendingInvite.value = invite
        return true
    }

    /** 一鍵加入：優先使用現有 Google 憑證 probe（免重複選帳號）→ 若無或未授權才開啟挑選器 → 整本下載 → 打開 → 自動接上即時中繼。 */
    suspend fun join(activity: Activity, invite: FfiCollabInviteV2): Boolean {
        lastError.value = null
        _busy.value = L10n.t("cloud_collab_joining")
        try {
            // 1. 若本機已有有效之 Google 憑證，先直接測試讀取（免彈出視窗重複選帳號）
            val existingHttp = withContext(Dispatchers.IO) { CollabDriveAuth.makeHttp(activity) }
            if (existingHttp != null) {
                val probe = withContext(Dispatchers.IO) {
                    uniffi.padnote_core.collabDriveProbe(existingHttp, invite.driveFolderId, invite.minFiles)
                }
                if (probe.access == FfiDriveAccess.READY) {
                    return finishJoin(activity, invite, probe.folderName)
                }
            }

            val auth = CollabDriveAuth.authorize(activity, pickFolderId = invite.driveFolderId)
            if (!auth.ok) {
                // 關掉挑選器多半是「點進資料夾後找不到選取鈕」：告訴使用者下一次該怎麼點（與 Apple 相同）。
                lastError.value = L10n.t(if (auth.error == "cancelled") "cloud_collab_err_not_picked" else "cloud_collab_err_reauth")
                return false
            }
            val http = withContext(Dispatchers.IO) { CollabDriveAuth.makeHttp(activity) }
                ?: run { lastError.value = L10n.t("cloud_collab_err_reauth"); return false }
            val probe = withContext(Dispatchers.IO) {
                uniffi.padnote_core.collabDriveProbe(http, invite.driveFolderId, invite.minFiles)
            }
            if (probe.access != FfiDriveAccess.READY) {
                val pickedFolder = auth.picked.any { it == invite.driveFolderId }
                lastError.value = L10n.t(if (pickedFolder) probe.messageKey else "cloud_collab_err_not_picked")
                return false
            }
            return finishJoin(activity, invite, probe.folderName)
        } finally {
            _busy.value = null
        }
    }

    private suspend fun finishJoin(activity: Activity, invite: FfiCollabInviteV2, folderName: String): Boolean {
        val entry = FfiSharedNotebook(
            invite.notebookId, invite.driveFolderId, invite.roomId, invite.keyBase64, "editor",
            invite.title.ifEmpty { folderName }
        )
        saveRegistry(activity, uniffi.padnote_core.sharedRegistryUpsert(registryJson(activity), entry))
        val s = withContext(Dispatchers.IO) { session(activity, entry) } ?: return false
        val id = invite.notebookId
        val existing = com.kairumo.padnote.sync.LanLink.findPackage(activity, id)
        if (existing == null) {
            val path = File(NotebookLibrary.directory(activity), "$id.padnote")
            val cloned = withContext(Dispatchers.IO) {
                s.cloneNotebook(path.absolutePath, id.lowercase(), entry.title, System.currentTimeMillis().toULong())
            }
            if (!cloned.ok) {
                path.deleteRecursively()
                lastError.value = cloned.error
                return false
            }
            NotebookLibrary.invalidateCache(id)
        }
        relayInvite.value = invite
        openRequest.value = id
        return true
    }

    /** 編輯器：依自己的網路排序中繼位址，逐一試，連上就停。 */
    suspend fun connectRelay(collab: CollaborationManager, invite: FfiCollabInviteV2) {
        if (invite.roomId.isEmpty() || invite.servers.isEmpty()) return
        val (lan, ts) = collab.getLocalIpAddresses()
        val ordered = uniffi.padnote_core.collabOrderServers(invite.servers, listOfNotNull(lan, ts))
        val timeout = uniffi.padnote_core.collabConnectTimeoutMs().toLong()
        for (server in ordered) {
            val link = uniffi.padnote_core.collabInviteLinkV2(
                FfiCollabInviteV2(invite.roomId, invite.keyBase64, listOf(server), "", "", "", 0u)
            )
            collab.joinRoom(link)
            var waited = 0L
            while (waited < timeout) {
                if (collab.status is CollaborationManager.Status.Connected) return
                delay(100)
                waited += 100
            }
            if (collab.status is CollaborationManager.Status.Connected) return
            collab.disconnect()
        }
    }

    // ── 焦點與輪詢 ─────────────────────────────────────────

    fun setFocus(notebookId: String?) {
        val context = appContext ?: return
        val next = notebookId?.takeIf { shared(context, it) != null }
        if (next.equals(focusedId, ignoreCase = true)) return
        loop?.cancel()
        loop = null
        closeLinks()
        _presences.value = emptyList()
        focusedId = next
        sentSizes = HashMap()
        val entry = next?.let { shared(context, it) } ?: return
        lastRemoteChange = System.currentTimeMillis()
        loop = scope.launch { run(context, entry) }
    }

    /** 有本機修改要送：輪詢迴圈提早結束這一次等待。 */
    @Volatile private var wakeLoop = false

    fun noteLocalEdit() {
        if (focusedId == null) return
        lastLocalEdit = System.currentTimeMillis()
        val delayMs = uniffi.padnote_core.collabCloudFlushDelayMs().toLong()
        scope.launch {
            delay(delayMs)
            pushP2P()
            // 叫醒輪詢迴圈馬上上傳：不叫的話要等到下一輪（最久一整個輪詢間隔）對方才拿得到。
            wakeLoop = true
        }
    }

    fun notePresence(page: Int, selectedId: String?) {
        myPage = page.coerceAtLeast(0).toUInt()
        mySelection = selectedId.orEmpty()
    }

    /** 編輯器告訴這裡即時中繼連上了沒（連上時雲端只負責持久化，放慢輪詢）。 */
    var relayConnected: () -> Boolean = { false }

    /** App 在前景（`FocusSync.onForeground／onBackground` 更新）。背景時暫停輪詢。 */
    @Volatile var foreground = true

    private suspend fun run(context: Context, entry: FfiSharedNotebook) {
        while (scope.isActive && loop?.isActive != false) {
            val s = withContext(Dispatchers.IO) { session(context, entry) }
            if (s == null) {
                lastError.value = L10n.t("cloud_collab_err_reauth")
                return
            }
            val now = System.currentTimeMillis()
            val relayUp = relayConnected()
            val interval = uniffi.padnote_core.collabCloudPollMs(
                foreground = foreground,
                relayConnected = relayUp || connected.isNotEmpty(),
                secsSinceRemoteChange = ((now - lastRemoteChange) / 1000).coerceIn(0, 1_000_000).toUInt(),
                secsSinceLocalEdit = ((now - lastLocalEdit) / 1000).coerceIn(0, 1_000_000).toUInt()
            )
            if (interval > 0u) {
                val downloaded = withContext(Dispatchers.IO) { syncRound(context, entry, s) }
                if (downloaded > 0u) {
                    lastRemoteChange = System.currentTimeMillis()
                    FocusSync.publishRemote(entry.notebookId)
                }
                presenceTick(context, s)
                if (!relayUp) p2pTick(s)
            }
            // 分段睡：本機一有修改（`noteLocalEdit`）就提早醒來上傳。
            val wait = if (interval > 0u) interval.toLong() else 5_000L
            var slept = 0L
            while (slept < wait && !wakeLoop) {
                delay(100L)
                slept += 100L
            }
            wakeLoop = false
        }
    }

    private fun syncRound(context: Context, entry: FfiSharedNotebook, s: FfiSyncSession): UInt {
        val id = entry.notebookId
        val lock = uniffi.padnote_core.notebookLockTryEnter(id, "cloud-collab", android.os.SystemClock.elapsedRealtime().toULong())
        if (!lock.granted) return 0u
        try {
            val pkg = com.kairumo.padnote.sync.LanLink.findPackage(context, id) ?: return 0u
            if (!com.kairumo.padnote.ink.InkPackageWriter.awaitIdleBlocking()) return 0u
            val refreshed = s.refresh()
            if (!refreshed.ok) {
                if (refreshed.needsReauth) lastError.value = L10n.t("cloud_collab_err_reauth")
                return 0u
            }
            if (!com.kairumo.padnote.ink.InkPackageWriter.awaitIdleBlocking()) return 0u
            return com.kairumo.padnote.ink.InkPackageWriter.withSyncLock {
                if (!s.notebookNeedsSync(pkg.absolutePath, id.lowercase())) 0u
                else s.syncNotebook(pkg.absolutePath, id.lowercase(), deviceId()).downloaded
            }
        } finally {
            uniffi.padnote_core.notebookLockLeave(id, lock.ticket)
        }
    }

    // ── 在場 ───────────────────────────────────────────────

    private suspend fun presenceTick(context: Context, s: FfiSyncSession) {
        val now = System.currentTimeMillis()
        if (now - lastPresenceAt >= uniffi.padnote_core.collabPresenceIntervalMs().toLong()) {
            lastPresenceAt = now
            val profile = com.kairumo.padnote.account.AccountManager.load(context, fallbackName = "Kairumo")
            val json = uniffi.padnote_core.collabPresenceEncode(
                FfiCloudPresence(deviceId(), profile.displayName, profile.colorHex, myPage, mySelection, now.toULong())
            )
            withContext(Dispatchers.IO) {
                s.putAux(uniffi.padnote_core.collabPresencePath(deviceId()), json.toByteArray())
            }
            sendToPeers(uniffi.padnote_core.p2pEncodePresence(json))
        }
        val files = withContext(Dispatchers.IO) { s.readAux("presence/") }
        val seen = _presences.value.associateBy { it.deviceId }.toMutableMap()
        for (f in files) {
            val p = uniffi.padnote_core.collabPresenceDecode(String(f.data), now.toULong()) ?: continue
            if (p.deviceId == deviceId()) continue
            if ((seen[p.deviceId]?.updatedMs ?: 0u) <= p.updatedMs) seen[p.deviceId] = p
        }
        _presences.value = seen.values
            .filter { uniffi.padnote_core.collabPresenceDecode(uniffi.padnote_core.collabPresenceEncode(it), now.toULong()) != null }
            .sortedBy { it.userName }
    }

    // ── 點對點 ─────────────────────────────────────────────

    private class Listener(val peer: UInt) : FfiPeerListener {
        override fun onFrame(frame: ByteArray) {
            scope.launch { received(frame) }
        }
        override fun onState(state: FfiPeerState) {
            scope.launch { stateChanged(peer, state) }
        }
    }

    private fun signal(files: List<uniffi.padnote_core.FfiAuxFile>, path: String): String? {
        val f = files.firstOrNull { it.path == path } ?: return null
        val json = runCatching { JSONObject(String(f.data)) }.getOrNull() ?: return null
        if (System.currentTimeMillis() / 1000.0 - json.optDouble("t", 0.0) > 90) return null
        return json.optString("sdp").ifEmpty { null }
    }

    private fun signalBytes(sdp: String): ByteArray =
        JSONObject().put("t", System.currentTimeMillis() / 1000.0).put("sdp", sdp).toString().toByteArray()

    private suspend fun p2pTick(s: FfiSyncSession) {
        val me = deviceId()
        val files = withContext(Dispatchers.IO) { s.readAux("signal/") }
        for (peer in _presences.value.map { it.deviceId }) {
            if (peer in connected) continue
            if ((failedAt[peer] ?: 0L) > System.currentTimeMillis() - 60_000L) continue
            if (uniffi.padnote_core.p2pShouldOffer(me, peer)) {
                val link = links[peer]
                if (link != null) {
                    val answer = signal(files, uniffi.padnote_core.p2pSignalPath(peer, me, true))
                    if (answer != null) withContext(Dispatchers.IO) { link.applyAnswer(answer) }
                    else if (System.currentTimeMillis() - (linkOpenedAt[peer] ?: 0L) > 60_000L) dropLink(peer, true)
                    continue
                }
                val created = uniffi.padnote_core.p2pNewLink(emptyList(), Listener(peer)) ?: continue
                links[peer] = created
                linkOpenedAt[peer] = System.currentTimeMillis()
                val offer = withContext(Dispatchers.IO) { created.createOffer(4_000u) }
                if (offer.isEmpty()) continue
                withContext(Dispatchers.IO) { s.putAux(uniffi.padnote_core.p2pSignalPath(me, peer, false), signalBytes(offer)) }
            } else if (links[peer] == null) {
                val offer = signal(files, uniffi.padnote_core.p2pSignalPath(peer, me, false)) ?: continue
                val created = uniffi.padnote_core.p2pNewLink(emptyList(), Listener(peer)) ?: continue
                links[peer] = created
                linkOpenedAt[peer] = System.currentTimeMillis()
                val answer = withContext(Dispatchers.IO) { created.acceptOffer(offer, 4_000u) }
                if (answer.isEmpty()) continue
                withContext(Dispatchers.IO) { s.putAux(uniffi.padnote_core.p2pSignalPath(me, peer, true), signalBytes(answer)) }
            }
        }
    }

    private fun stateChanged(peer: UInt, state: FfiPeerState) {
        when (state) {
            FfiPeerState.CONNECTED -> {
                connected += peer
                sentSizes = HashMap() // 新連上：把目前所有事件檔推一次（對方已有的會被忽略）
                pushP2P()
            }
            FfiPeerState.FAILED -> dropLink(peer, true)
            FfiPeerState.CLOSED -> dropLink(peer, false)
            FfiPeerState.CONNECTING -> {}
        }
        _directPeers.value = connected.size
    }

    private fun received(frame: ByteArray) {
        val context = appContext ?: return
        val id = focusedId ?: return
        when (val f = uniffi.padnote_core.p2pDecodeFrame(frame)) {
            is FfiP2pFrame.OpFile -> {
                if (!f.notebookId.equals(id, ignoreCase = true)) return
                val pkg = packageDir(context, id).absolutePath
                if (uniffi.padnote_core.packageIngestOpFile(pkg, f.name, f.data)) {
                    lastRemoteChange = System.currentTimeMillis()
                    scheduleRefresh(id)
                }
            }
            is FfiP2pFrame.Presence -> {
                // 即時協同訊息（外包在在場訊框裡，見 `sendRealtime`）。
                if (f.json.startsWith(RT_PREFIX) && f.json.endsWith("}")) {
                    realtimeSink?.invoke(f.json.substring(RT_PREFIX.length, f.json.length - 1))
                    return
                }
                val p = uniffi.padnote_core.collabPresenceDecode(f.json, System.currentTimeMillis().toULong()) ?: return
                if (p.deviceId == deviceId()) return
                _presences.value = (_presences.value.filter { it.deviceId != p.deviceId } + p).sortedBy { it.userName }
            }
            FfiP2pFrame.Unknown -> {}
        }
    }

    /** 連續收到好幾個檔時合併成一次重開。 */
    private fun scheduleRefresh(id: String) {
        if (refreshPending) return
        refreshPending = true
        scope.launch {
            delay(250)
            refreshPending = false
            FocusSync.publishRemote(id)
        }
    }

    /** 把新的或變長的事件檔推給所有直連的對端。 */
    fun pushP2P() {
        val context = appContext ?: return
        val id = focusedId ?: return
        if (connected.isEmpty()) return
        val peers = connected.mapNotNull { links[it] }
        val previous = HashMap(sentSizes)
        val pkg = packageDir(context, id).absolutePath
        scope.launch(Dispatchers.IO) {
            val sent = HashMap(previous)
            for (f in uniffi.padnote_core.packageOpFileSizes(pkg)) {
                if (f.size <= (previous[f.name] ?: 0u)) continue
                val data = uniffi.padnote_core.packageReadOpFile(pkg, f.name)
                val frame = uniffi.padnote_core.p2pEncodeOpFile(id.lowercase(), f.name, data)
                if (frame.isEmpty()) continue // 太大：交給雲端
                peers.forEach { it.send(frame) }
                sent[f.name] = f.size
            }
            withContext(Dispatchers.Main) { sentSizes = sent }
        }
    }

    // ── 即時協同走直連（跨網路、連不到房主的中繼時）──
    //
    // 直連原本只搬事件檔：對方要等事件檔寫好、推過去、匯入、重開，一筆要將近一秒。
    // 這裡讓即時協同的訊息（`ink_add`、`obj_patch`、書寫中預覽 `live_ink`……，與中繼上的同一份 JSON）
    // 也走同一條資料通道，對方收到後與從中繼收到的走同一段處理 —— 跨網路也是即時的。
    // 同一則可能從中繼與直連各來一次：操作有 op id 去重、預覽有序號，重複無害。
    //
    // 訊框沿用「在場」格式外包一層 `{"rt":…}`：不必改核心的訊框種類（不用重建原生函式庫），
    // 舊版收到時在場解析失敗、直接忽略。

    /** 編輯器的即時協同管理器收這裡轉來的訊息（`CollaborationManager.receiveRealtime`）。 */
    @Volatile var realtimeSink: ((String) -> Unit)? = null

    /** 有直連中的對端就送出並回 `true`；沒有（或太大，交給中繼與雲端）回 `false`。主執行緒呼叫。 */
    fun sendRealtime(json: String): Boolean {
        if (connected.isEmpty()) return false
        val frame = uniffi.padnote_core.p2pEncodePresence("$RT_PREFIX$json}")
        if (frame.size > P2P_REALTIME_MAX) return false
        sendToPeers(frame)
        return true
    }

    private const val RT_PREFIX = "{\"rt\":"
    /** 資料通道單一訊息的安全上限（與核心的 `P2P_MAX_FRAME` 相同）。 */
    private const val P2P_REALTIME_MAX = 60 * 1024

    private fun sendToPeers(frame: ByteArray) {
        val peers = connected.mapNotNull { links[it] }
        if (peers.isEmpty()) return
        scope.launch(Dispatchers.IO) { peers.forEach { it.send(frame) } }
    }

    private fun dropLink(peer: UInt, failed: Boolean) {
        links.remove(peer)?.let { link -> scope.launch(Dispatchers.IO) { link.disconnect() } }
        connected.remove(peer)
        if (failed) failedAt[peer] = System.currentTimeMillis()
        _directPeers.value = connected.size
    }

    private fun closeLinks() {
        links.keys.toList().forEach { dropLink(it, false) }
        failedAt.clear()
    }
}
