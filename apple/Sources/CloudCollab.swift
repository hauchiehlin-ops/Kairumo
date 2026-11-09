//
//  CloudCollab.swift
//  Kairumo
//
//  雲端共享（跨網路）：把一本筆記的協同房間開在 Cloudflare 的加密中繼上，任何網路都連得到。
//
//  # 只有一條跨網路通道
//
//  以前這裡另外用 Google 雲端硬碟的共享資料夾當「共同底稿」，再加上走雲端資料夾信令的點對點直連。
//  實際上 `drive.file` 權限下協作者讀不到房主建立的檔案（Google 的逐檔授權），掃碼加入早就改走
//  中繼；Drive 只剩下讓房主多登入一次 Google、多一種讓人搞混的模式。現在整段拿掉：
//
//  - 即時同步：中繼（`CollaborationManager`）。
//  - 房主不在線也能加入：參與者定期把整份狀態（端對端加密）寄存在房間裡（`state_store`，
//    見 `deploy/relay-cloudflare`），新加入的人先拿到它、再補之後的操作。
//  - 保存期限：房間沒人之後（含房主按「結束協同」）中繼保留一段時間再整個刪除，讓不在線的協作者
//    回來時還拿得到最終版本。
//
//  同一 Wi‑Fi（本機中繼）照舊，與這裡無關。
//

import Combine
import Foundation

@MainActor
final class CloudCollabManager: ObservableObject {
    // profile-scope: profile 共享筆記清單依設定檔存在偏好設定；切換時重讀
    static let shared = CloudCollabManager()

    /// 這台裝置上開了雲端共享的筆記（房號與金鑰記著：重開 App 之後之前發出去的邀請照樣有效）。
    /// 格式沿用核心的共享清單（`folder` 欄位不再使用）。
    @Published private(set) var registry: [FfiSharedNotebook] = []
    /// 最近一次的錯誤（已翻譯的文字）。
    @Published var lastError: String?
    /// 進行中的長工作的說明。
    @Published private(set) var busyMessage: String?

    private let registryKey = "kairumo.cloudCollab.registry"

    private init() {
        reloadRegistry()
    }

    // MARK: 清單

    private var registryJson: String {
        get { ProfileDefaults.current.string(forKey: registryKey) ?? "" }
        set {
            ProfileDefaults.current.set(newValue, forKey: registryKey)
            registry = sharedRegistryList(json: newValue)
        }
    }

    func reloadRegistry() {
        registry = sharedRegistryList(json: registryJson)
    }

    func shared(_ notebookId: String) -> FfiSharedNotebook? {
        sharedRegistryFind(json: registryJson, notebookId: notebookId)
    }

    /// 這本的協同房間現在開在哪一本（給 `room_closed` 用）。
    var focusedId: String? { CollaborationManager.shared.roomNotebookId }

    // MARK: 房主：開啟

    /// 把這本的房間開在雲端中繼上並回傳邀請連結。已經開過就沿用同一間房（同一把金鑰）。
    func share(notebookId: String, title: String) async -> String? {
        lastError = nil
        let collab = CollaborationManager.shared
        let relay = collab.cloudRelayURL
        guard !relay.isEmpty else {
            lastError = L10n.t("cloud_collab_err_retry")
            return nil
        }
        busyMessage = L10n.t("cloud_collab_sharing")
        defer { busyMessage = nil }
        var entry = shared(notebookId) ?? FfiSharedNotebook(
            notebookId: notebookId, folderId: "", roomId: "", keyBase64: "", role: "owner", title: title)
        ensurePublicRoom(for: entry, force: true)
        for _ in 0..<50 where collab.roomKeyBase64 == nil || collab.currentRoomId.isEmpty {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        guard !collab.currentRoomId.isEmpty, let key = collab.roomKeyBase64 else {
            lastError = L10n.t("cloud_collab_err_retry")
            return nil
        }
        entry.roomId = collab.currentRoomId
        entry.keyBase64 = key
        entry.folderId = ""
        entry.title = title
        registryJson = sharedRegistryUpsert(json: registryJson, entry: entry)
        return inviteLink(for: entry)
    }

    /// 房主：這本的房間開在雲端中繼上。已經在那裡就不動；記過房號與金鑰就沿用。
    /// 若目前這本筆記已經開在本機中繼（同一 Wi‑Fi）上，尊重使用者當下的選擇，不強行搬回雲端。
    func ensurePublicRoom(for entry: FfiSharedNotebook, force: Bool = false) {
        let collab = CollaborationManager.shared
        let relay = collab.cloudRelayURL
        guard !relay.isEmpty, entry.role == "owner" else { return }
        let bound = collab.roomNotebookId == entry.notebookId.lowercased()
        if bound, collab.status != .disconnected {
            if collab.activeServerAddress == relay { return }
            if !force && collab.isHostingLocalRelay { return }
        }
        if !entry.roomId.isEmpty, !entry.keyBase64.isEmpty {
            collab.hostRoom(roomId: entry.roomId, keyBase64: entry.keyBase64,
                            notebookId: entry.notebookId, server: relay)
        } else {
            collab.createRoom(notebookId: entry.notebookId, server: relay)
        }
    }

    /// 邀請連結：房號、金鑰、中繼位址、哪一本。
    func inviteLink(for entry: FfiSharedNotebook) -> String {
        let collab = CollaborationManager.shared
        return collabInviteLinkV2(invite: FfiCollabInviteV2(
            roomId: entry.roomId.isEmpty ? collab.currentRoomId : entry.roomId,
            keyBase64: entry.keyBase64.isEmpty ? (collab.roomKeyBase64 ?? "") : entry.keyBase64,
            servers: [collab.cloudRelayURL], notebookId: entry.notebookId, driveFolderId: "",
            title: entry.title, minFiles: 0))
    }

    /// 不再共享（這台不再記這間房；中繼上的資料到保存期限自動刪除）。
    func stopSharing(_ notebookId: String) {
        registryJson = sharedRegistryRemove(json: registryJson, notebookId: notebookId)
    }

    /// 結束線上協同：先把最終版本寄存到中繼（讓不在線的協作者之後還拿得到），再關房、解除登記。
    /// 各參與者本機的筆記照舊留著。
    func endCollaboration(notebookId: String) async {
        let collab = CollaborationManager.shared
        if collab.isHost {
            await collab.depositState()
            collab.closeRoom()
        } else {
            collab.disconnect()
        }
        stopSharing(notebookId)
    }
}

// MARK: - 設定檔切換

extension CloudCollabManager: ProfileScoped {
    func resetForProfileSwitch() {
        lastError = nil
        reloadRegistry()
    }
}
