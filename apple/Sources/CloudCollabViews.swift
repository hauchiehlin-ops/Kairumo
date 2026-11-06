//
//  CloudCollabViews.swift
//  Kairumo
//
//  雲端協作的畫面：協同面板裡的「雲端共享（跨網路）」、一鍵加入的確認畫面、
//  編輯器裡的「誰在哪一頁」提示。邏輯在 `CloudCollabManager`。
//

import SwiftUI

// MARK: - 協同面板：雲端共享（跨網路）

/// 房主：把這本筆記分享到雲端資料夾（輸入 Email，或產生「知道連結的人可編輯」的連結）。
/// 已分享：顯示一鍵邀請連結與 QR Code、成員清單（可撤銷）。
struct CloudShareSection: View {
    let notebookId: String
    let title: String

    @ObservedObject private var manager = CloudCollabManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var link = ""
    @State private var members: [FfiDriveMember] = []
    @State private var copied = false

    private var entry: FfiSharedNotebook? { manager.registry.first { $0.notebookId.lowercased() == notebookId.lowercased() } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "icloud.and.arrow.up")
                    .foregroundColor(.accentColor)
                Text(localizationManager.localized("cloud_collab_title"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                if manager.directPeers > 0 {
                    Label(localizationManager.localized("cloud_collab_direct"), systemImage: "bolt.horizontal.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            Text(localizationManager.localized("cloud_collab_desc"))
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let entry {
                sharedBody(entry)
            } else if entry == nil {
                shareForm
            }

            if let busy = manager.busyMessage {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(busy).font(.caption)
                }
            }
            if let error = manager.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .task(id: entry?.folderId) { await refreshMembers() }
    }

    private var shareForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task { await share(email: "") }
            } label: {
                Label(localizationManager.localized("cloud_collab_share_link"), systemImage: "link")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .disabled(manager.busyMessage != nil)
            Text(localizationManager.localized("cloud_collab_share_link_hint"))
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func sharedBody(_ entry: FfiSharedNotebook) -> some View {
        let invite = link.isEmpty ? manager.inviteLink(for: entry) : link
        HStack(alignment: .top, spacing: 12) {
            // 房主打開面板時確定房間開在公開中繼上（QR Code 指向的就是那一間）。
            Color.clear.frame(width: 0, height: 0)
                .onAppear { manager.ensurePublicRoom(for: entry) }
            QRCodeImage(text: invite)
                .frame(width: 132, height: 132)
                .accessibilityIdentifier("cloudcollab.qr")
            VStack(alignment: .leading, spacing: 8) {
                Text(localizationManager.localized("cloud_collab_invite_hint"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    UIPasteboard.general.string = invite
                    copied = true
                } label: {
                    Label(localizationManager.localized(copied ? "room_id_copied" : "cloud_collab_copy_invite"),
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                ShareLink(item: invite) {
                    Label(localizationManager.localized("cloud_collab_send_invite"), systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
            }
        }
        if entry.role == "owner" {
            ForEach(members, id: \.permissionId) { member in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(member.name.isEmpty ? (member.email.isEmpty ? localizationManager.localized("cloud_collab_anyone") : member.email) : member.name)
                            .font(.subheadline)
                        Text(localizationManager.localized("cloud_collab_role_\(member.role)"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if member.role != "owner" {
                        Button(role: .destructive) {
                            Task {
                                if await manager.revoke(member, in: entry) { await refreshMembers() }
                            }
                        } label: {
                            Image(systemName: "person.crop.circle.badge.minus")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(localizationManager.localized("cloud_collab_revoke"))
                    }
                }
            }
        }
    }

    private func share(email: String) async {
        if let result = await manager.share(notebookId: notebookId, title: title, email: email) {
            link = result
            await refreshMembers()
        }
    }

    private func refreshMembers() async {
        guard let entry, entry.role == "owner" else { members = []; return }
        members = await manager.members(of: entry)
    }
}

// MARK: - 一鍵加入

/// 掃了 QR Code／點了邀請連結之後的確認畫面：一個「加入」鈕。
/// 之後只有 Google 自己的畫面（登入、同意、確認資料夾）—— 那一步省不掉，是 Google 的規定。
struct CloudCollabJoinSheet: View {
    let invite: FfiCollabInviteV2
    @ObservedObject private var manager = CloudCollabManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "person.2.wave.2.fill")
                .font(.system(size: 44))
                .foregroundColor(.accentColor)
            Text(localizationManager.localized("cloud_collab_join_title"))
                .font(.title3.weight(.semibold))
            if !invite.title.isEmpty {
                Text(invite.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            Text(localizationManager.localized("cloud_collab_join_desc"))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let busy = manager.busyMessage {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(busy).font(.caption)
                }
            }
            if let error = manager.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 12) {
                Button(localizationManager.localized("cancel")) {
                    manager.pendingInvite = nil
                    dismiss()
                }
                .buttonStyle(.bordered)
                Button {
                    Task {
                        if await manager.join(invite) {
                            manager.pendingInvite = nil
                            dismiss()
                        }
                    }
                } label: {
                    Text(localizationManager.localized("cloud_collab_join"))
                        .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .disabled(manager.busyMessage != nil)
                .accessibilityIdentifier("cloudcollab.join")
            }
        }
        .padding(28)
        .frame(maxWidth: 420)
    }
}

/// `.sheet(item:)` 要 `Identifiable`。
struct PendingCloudInvite: Identifiable {
    let invite: FfiCollabInviteV2
    var id: String { invite.driveFolderId + "|" + invite.notebookId }
}

/// 掛在 App 最外層：有邀請就跳出確認畫面（首頁、編輯器都一樣）。
struct CloudCollabInviteHost: ViewModifier {
    @ObservedObject private var manager = CloudCollabManager.shared

    func body(content: Content) -> some View {
        content.sheet(item: Binding(
            get: { manager.pendingInvite.map(PendingCloudInvite.init(invite:)) },
            set: { if $0 == nil { manager.pendingInvite = nil } }
        )) { pending in
            CloudCollabJoinSheet(invite: pending.invite)
        }
    }
}

// MARK: - 編輯器：誰在哪一頁

/// 共享筆記裡其他人的位置（第幾頁、正在改的物件）。點一下跳到那一頁。
/// 看得到彼此在哪裡，大家自然分頁分物件作業 —— 雲端有幾秒延遲時，這是避免互相覆蓋最有效的一招。
struct CloudPresenceBar: View {
    let currentPage: Int
    let onJump: (Int) -> Void
    @ObservedObject private var manager = CloudCollabManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared

    var body: some View {
        if !manager.presences.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: manager.directPeers > 0 ? "bolt.horizontal.fill" : "icloud")
                    .font(.caption2)
                    .foregroundColor(manager.directPeers > 0 ? .green : .secondary)
                ForEach(manager.presences, id: \.deviceId) { p in
                    Button {
                        onJump(Int(p.pageIndex))
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: p.colorHex) ?? .accentColor)
                                .frame(width: 8, height: 8)
                            Text(String(format: localizationManager.localized("cloud_collab_on_page"),
                                        p.userName, Int(p.pageIndex) + 1))
                                .font(.caption2)
                                .foregroundColor(Int(p.pageIndex) == currentPage ? .accentColor : .primary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(uiColor: .secondarySystemBackground)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(.ultraThinMaterial, in: Capsule())
            .accessibilityIdentifier("cloudcollab.presence")
        }
    }
}
