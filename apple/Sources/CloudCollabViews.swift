//
//  CloudCollabViews.swift
//  Kairumo
//
//  協同面板裡的「雲端共享（跨網路）」。邏輯在 `CloudCollabManager`。
//

import SwiftUI

// MARK: - 協同面板：雲端共享（跨網路）

/// 房主：把這本的房間開在雲端中繼上（產生「知道連結的人可編輯」的邀請）。
/// 已開啟：顯示邀請的 QR Code、複製與傳送連結，以及保存期限的說明。
struct CloudShareSection: View {
    let notebookId: String
    let title: String

    @ObservedObject private var manager = CloudCollabManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var link = ""
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
            }
            Text(localizationManager.localized("cloud_collab_desc"))
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let entry {
                sharedBody(entry)
            } else {
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
    }

    private var shareForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task {
                    if let result = await manager.share(notebookId: notebookId, title: title) { link = result }
                }
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
            // 房主打開面板時確定房間開在雲端中繼上（QR Code 指向的就是那一間）。
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
        Text(localizationManager.localized("cloud_collab_retention_hint"))
            .font(.caption2)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
