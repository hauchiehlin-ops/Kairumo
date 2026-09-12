//
//  CollaborationSheet.swift
//  Kairumo
//
//  線上多人即時協同管理彈窗面板（Phase 1 MVP）
//

import SwiftUI

public struct CollaborationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var collaborationManager = CollaborationManager.shared
    @ObservedObject var localizationManager = LocalizationManager.shared
    @ObservedObject var store = NotebookStore.shared

    public let notebookId: String?

    @State private var inputRoomId: String = ""
    @State private var showCopiedAlert: Bool = false
    @State private var showEndSessionAlert: Bool = false
    @State private var isEditingServerUrl: Bool = false

    // 里程碑快照狀態
    @State private var snapshots: [NotebookMilestoneSnapshot] = []
    @State private var showCreateSnapshotAlert: Bool = false
    @State private var newSnapshotTitle: String = ""
    @State private var targetRestoreSnapshot: NotebookMilestoneSnapshot? = nil
    @State private var showRestoreConfirmAlert: Bool = false

    public init(notebookId: String? = nil) {
        self.notebookId = notebookId
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 頂部狀態橫幅卡片
                    statusHeaderCard

                    // 依據連線狀態呈現不同介面
                    switch collaborationManager.status {
                    case .connected(let roomId):
                        connectedRoomSection(roomId: roomId)
                    case .connecting:
                        connectingSection
                    case .disconnected, .reconnecting:
                        disconnectedActionSection
                    }

                    // 📸 里程碑快照時光機區塊
                    if notebookId != nil {
                        milestonesSection
                    }

                    // 進階伺服器位址設定
                    serverConfigSection
                }
                .padding(20)
            }
            .onAppear {
                loadSnapshots()
            }
            .navigationTitle(localizationManager.localized("collaborate"))
            #if os(iOS) || targetEnvironment(macCatalyst)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("done")) {
                        dismiss()
                    }
                }
            }
            .alert(localizationManager.localized("end_collaboration"), isPresented: $showEndSessionAlert) {
                Button(localizationManager.localized("cancel"), role: .cancel) {}
                Button(localizationManager.localized("confirm"), role: .destructive) {
                    if collaborationManager.isHost {
                        collaborationManager.closeRoom()
                    } else {
                        collaborationManager.disconnect()
                    }
                }
            } message: {
                Text(localizationManager.localized("end_session_confirm"))
            }
            .alert(localizationManager.localized("create_snapshot"), isPresented: $showCreateSnapshotAlert) {
                TextField(localizationManager.localized("snapshot_name"), text: $newSnapshotTitle)
                Button(localizationManager.localized("cancel"), role: .cancel) {}
                Button(localizationManager.localized("confirm")) {
                    createSnapshot()
                }
            }
            .alert(localizationManager.localized("restore_snapshot"), isPresented: $showRestoreConfirmAlert) {
                Button(localizationManager.localized("cancel"), role: .cancel) {}
                Button(localizationManager.localized("restore_snapshot"), role: .destructive) {
                    if let target = targetRestoreSnapshot {
                        restoreSnapshot(target)
                    }
                }
            } message: {
                Text(localizationManager.localized("restore_snapshot_confirm"))
            }
        }
        #if os(macOS) || targetEnvironment(macCatalyst)
        .frame(minWidth: 440, minHeight: 520)
        #endif
    }

    // MARK: - 狀態橫幅卡片
    private var statusHeaderCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 46, height: 46)

                Image(systemName: statusIcon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(statusTitle)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if case .connected = collaborationManager.status {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                }

                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(statusColor.opacity(0.25), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        switch collaborationManager.status {
        case .connected: return .green
        case .connecting, .reconnecting: return .orange
        case .disconnected: return .accentColor
        }
    }

    private var statusIcon: String {
        switch collaborationManager.status {
        case .connected: return "person.2.wave.2.fill"
        case .connecting, .reconnecting: return "arrow.triangle.2.circlepath"
        case .disconnected: return "person.2.fill"
        }
    }

    private var statusTitle: String {
        switch collaborationManager.status {
        case .connected:
            return localizationManager.localized("status_connected")
        case .connecting, .reconnecting:
            return localizationManager.localized("status_connecting")
        case .disconnected:
            return localizationManager.localized("status_disconnected")
        }
    }

    private var statusSubtitle: String {
        switch collaborationManager.status {
        case .connected(let rid):
            return "\(localizationManager.localized("room_id")): \(rid)"
        case .connecting, .reconnecting:
            return collaborationManager.serverAddress
        case .disconnected:
            return localizationManager.localized("start_collaboration")
        }
    }

    // MARK: - 已連線房間詳情與成員清單
    private func connectedRoomSection(roomId: String) -> some View {
        VStack(spacing: 16) {
            // 房間識別碼與快速複製
            VStack(alignment: .leading, spacing: 8) {
                Text(localizationManager.localized("room_id"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                HStack {
                    Text(roomId)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Spacer()

                    Button {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = roomId
                        #endif
                        showCopiedAlert = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showCopiedAlert ? "checkmark" : "doc.on.doc")
                            Text(showCopiedAlert ? localizationManager.localized("room_id_copied") : localizationManager.localized("copy_room_id"))
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundColor(.accentColor)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(10)
            }

            // 在線成員名單
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(localizationManager.localized("online_participants")) (\(collaborationManager.peers.count + 1))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                // 我自己
                peerRow(
                    name: "\(AccountManager.shared.profile.displayName) (\(localizationManager.localized("current_user")))",
                    colorHex: collaborationManager.myColorHex,
                    roleText: collaborationManager.isHost ? localizationManager.localized("role_owner") : localizationManager.localized("role_editor"),
                    isHost: collaborationManager.isHost,
                    isMe: true
                )

                // 遠端在線成員
                ForEach(collaborationManager.peers) { peer in
                    peerRow(
                        name: peer.userName,
                        colorHex: peer.userColor,
                        roleText: localizationManager.localized(peer.role.localizedKey),
                        isHost: peer.role == .owner,
                        isMe: false
                    )
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)

            // 結束協同會議按鈕
            Button(role: .destructive) {
                showEndSessionAlert = true
            } label: {
                HStack {
                    Image(systemName: collaborationManager.isHost ? "xmark.circle.fill" : "rectangle.portrait.and.arrow.right")
                    Text(collaborationManager.isHost ? localizationManager.localized("end_collaboration") : localizationManager.localized("disconnect"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.12))
                .foregroundColor(.red)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }

    private func peerRow(name: String, colorHex: String, roleText: String, isHost: Bool, isMe: Bool) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: colorHex) ?? .accentColor)
                .frame(width: 28, height: 28)
                .overlay(
                    Text(String(name.prefix(1)).uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(isMe ? .semibold : .regular)
                    .foregroundColor(.primary)

                Text(roleText)
                    .font(.caption2)
                    .foregroundColor(isHost ? .purple : .secondary)
            }

            Spacer()

            Circle()
                .fill(Color.green)
                .frame(width: 7, height: 7)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 連線中過渡狀態
    private var connectingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(localizationManager.localized("status_connecting"))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button(localizationManager.localized("cancel")) {
                collaborationManager.disconnect()
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 30)
    }

    // MARK: - 未連線時的操作選單
    private var disconnectedActionSection: some View {
        VStack(spacing: 16) {
            // 一鍵開啟多人協同
            Button {
                collaborationManager.createRoom()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                    Text(localizationManager.localized("start_collaboration"))
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: Color.accentColor.opacity(0.3), radius: 6, y: 3)
            }
            .buttonStyle(.plain)

            Divider()

            // 輸入房間代碼加入既有房間
            VStack(alignment: .leading, spacing: 8) {
                Text(localizationManager.localized("join_room"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    TextField(localizationManager.localized("enter_room_id"), text: $inputRoomId)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif

                    Button {
                        collaborationManager.joinRoom(roomId: inputRoomId)
                    } label: {
                        Text(localizationManager.localized("join_room"))
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(inputRoomId.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - 伺服器進階位址設定
    private var serverConfigSection: some View {
        DisclosureGroup(isExpanded: $isEditingServerUrl) {
            VStack(alignment: .leading, spacing: 8) {
                Text(localizationManager.localized("relay_server_address"))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                HStack {
                    TextField("ws://127.0.0.1:9002", text: $collaborationManager.serverAddress)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif

                    Button(localizationManager.localized("reset")) {
                        collaborationManager.serverAddress = "ws://127.0.0.1:9002"
                    }
                    .font(.caption)
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "gearshape")
                    .font(.caption)
                Text(localizationManager.localized("relay_server_address"))
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(10)
    }

    // MARK: - 📸 里程碑快照時光機
    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.blue)
                    Text(localizationManager.localized("milestone_snapshots"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    newSnapshotTitle = ""
                    showCreateSnapshotAlert = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text(localizationManager.localized("create_snapshot"))
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            if snapshots.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text(localizationManager.localized("milestone_snapshots"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(10)
            } else {
                VStack(spacing: 8) {
                    ForEach(snapshots) { snap in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.blue)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(snap.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)

                                HStack(spacing: 6) {
                                    Text(snap.creatorName)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("•")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(formatSnapshotDate(snap.createdAt))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Button {
                                targetRestoreSnapshot = snap
                                showRestoreConfirmAlert = true
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.uturn.backward.circle.fill")
                                    Text(localizationManager.localized("restore_snapshot"))
                                }
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func loadSnapshots() {
        guard let nId = notebookId else { return }
        snapshots = store.listMilestoneSnapshots(notebookId: nId)
    }

    private func createSnapshot() {
        guard let nId = notebookId else { return }
        let name = AccountManager.shared.profile.displayName
        if let created = store.createMilestoneSnapshot(notebookId: nId, title: newSnapshotTitle, creatorName: name) {
            snapshots.insert(created, at: 0)
        }
    }

    private func restoreSnapshot(_ snap: NotebookMilestoneSnapshot) {
        guard let nId = notebookId else { return }
        if store.restoreMilestoneSnapshot(notebookId: nId, snapshot: snap) {
            loadSnapshots()
            dismiss()
        }
    }

    private func formatSnapshotDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}
