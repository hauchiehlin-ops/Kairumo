package com.kairumo.padnote.collab

import android.content.Context
import com.kairumo.padnote.L10n
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import uniffi.padnote_core.FfiCollabInviteV2
import uniffi.padnote_core.FfiSharedNotebook

/**
 * 雲端共享（跨網路，Android）：把一本筆記的協同房間開在 Cloudflare 的加密中繼上。與 Apple `CloudCollabManager` 相同。
 *
 * 以前另外用 Google 雲端硬碟的共享資料夾當底稿、走資料夾信令做點對點直連；`drive.file` 權限下協作者
 * 其實讀不到房主的檔案，掃碼加入早就改走中繼，所以整段拿掉。現在：
 * - 即時同步：中繼（編輯器的 [CollaborationManager]）。
 * - 房主不在線也能加入：參與者定期把整份狀態（端對端加密）寄存在房間裡（`state_store`）。
 * - 保存期限：房間沒人之後（含結束協同）中繼保留一段時間再整個刪除（見 `deploy/relay-cloudflare`）。
 *
 * 同一 Wi‑Fi／Tailscale（本機中繼）照舊，與這裡無關。
 */
// profile-scope: device 共享清單存在依設定檔命名的偏好檔；切換設定檔會重啟行程，記憶體狀態不跨設定檔
object CloudCollab {
    private const val PREFS = "kairumo_cloud_collab"
    private const val KEY_REGISTRY = "registry"

    private val _registry = MutableStateFlow<List<FfiSharedNotebook>>(emptyList())
    val registry: StateFlow<List<FfiSharedNotebook>> = _registry
    private val _busy = MutableStateFlow<String?>(null)
    val busy: StateFlow<String?> = _busy
    val lastError = MutableStateFlow<String?>(null)

    fun init(context: Context) {
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

    /** 把這本的房間開在雲端中繼上並回傳邀請連結。已經開過就沿用同一間房（同一把金鑰）。 */
    suspend fun share(context: Context, collab: CollaborationManager, notebookId: String, title: String): String? {
        lastError.value = null
        if (collab.cloudRelayUrl.isEmpty()) {
            lastError.value = L10n.t("cloud_collab_err_retry")
            return null
        }
        _busy.value = L10n.t("cloud_collab_sharing")
        try {
            var entry = shared(context, notebookId) ?: FfiSharedNotebook(notebookId, "", "", "", "owner", title)
            ensurePublicRoom(entry, collab, force = true)
            repeat(50) { if (collab.roomKeyBase64 == null || collab.roomId.isEmpty()) delay(100) }
            val key = collab.roomKeyBase64
            if (collab.roomId.isEmpty() || key == null) {
                lastError.value = L10n.t("cloud_collab_err_retry")
                return null
            }
            entry = entry.copy(roomId = collab.roomId, keyBase64 = key, folderId = "", title = title)
            saveRegistry(context, uniffi.padnote_core.sharedRegistryUpsert(registryJson(context), entry))
            return inviteLink(entry, collab)
        } finally {
            _busy.value = null
        }
    }

    /** 房主：這本的房間開在雲端中繼上。已經在那裡就不動；記過房號與金鑰就沿用。與 Apple `ensurePublicRoom` 相同。 */
    fun ensurePublicRoom(entry: FfiSharedNotebook, collab: CollaborationManager, force: Boolean = false) {
        val relay = collab.cloudRelayUrl
        if (relay.isEmpty() || entry.role != "owner") return
        if (collab.status !is CollaborationManager.Status.Disconnected) {
            if (collab.serverAddress == relay) return
            if (!force && collab.isHostingLocalRelay) return
        }
        if (entry.roomId.isNotEmpty() && entry.keyBase64.isNotEmpty()) {
            collab.hostRoom(entry.roomId, entry.keyBase64, relay)
        } else {
            collab.createRoom(server = relay)
        }
    }

    /** 邀請連結：房號、金鑰、中繼位址、哪一本。 */
    fun inviteLink(entry: FfiSharedNotebook, collab: CollaborationManager): String =
        uniffi.padnote_core.collabInviteLinkV2(
            FfiCollabInviteV2(
                roomId = entry.roomId.ifEmpty { collab.roomId },
                keyBase64 = entry.keyBase64.ifEmpty { collab.roomKeyBase64.orEmpty() },
                servers = listOf(collab.cloudRelayUrl),
                notebookId = entry.notebookId, driveFolderId = "",
                title = entry.title, minFiles = 0u
            )
        )

    /** 不再共享（這台不再記這間房；中繼上的資料到保存期限自動刪除）。 */
    fun stopSharing(context: Context, notebookId: String) {
        saveRegistry(context, uniffi.padnote_core.sharedRegistryRemove(registryJson(context), notebookId))
    }

    /**
     * 結束線上協同：房主先把最終版本寄存到中繼（不在線的協作者之後還拿得到），再關房；協作者只是離開。
     * 解除這台的登記；各參與者本機的筆記照舊留著。與 Apple `endCollaboration` 相同。
     */
    suspend fun endCollaboration(context: Context, notebookId: String, collab: CollaborationManager) {
        if (collab.isHost) {
            collab.depositState()
            collab.closeRoom()
        } else {
            collab.disconnect()
        }
        stopSharing(context, notebookId)
    }
}
