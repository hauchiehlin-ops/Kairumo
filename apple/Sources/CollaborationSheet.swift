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
    /// 還原之後給使用者的一句話（成功時說退路，失敗時說沒動到內容）。
    @State private var restoreMessage: String? = nil
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
                    case .reconnecting(let attempt, let maxAttempts):
                        reconnectingSection(attempt: attempt, maxAttempts: maxAttempts)
                    case .disconnected:
                        disconnectedActionSection
                    }

                    // 中繼起不來時**要講出來**，而且要在「還沒連上」的時候
                    // 也看得到 —— 舊版只 print 一行就繼續，使用者看到的是
                    // 「連線中斷，正在自動重新連線」無限轉圈，而真正的原因是
                    // 這台裝置根本沒有開成房間。連上之後這個訊息會自己清掉
                    // （埠被別的中繼佔著也照樣連得上，那不算問題）。
                    if let failure = collaborationManager.localRelayFailure {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(failure)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                        .accessibilityIdentifier("collaboration.relay_failed")
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
                // 講清楚「不會消失」—— 舊版這裡只說「確定要還原？」，
                // 而使用者真正在猶豫的是「我這半小時的東西會不會沒了」。
                Text(
                    String(
                        format: localizationManager.localized("milestone_restore_confirm"),
                        targetRestoreSnapshot?.title ?? ""))
            }
            .alert(
                localizationManager.localized("milestone_snapshots"),
                isPresented: Binding(
                    get: { restoreMessage != nil },
                    set: { if !$0 { restoreMessage = nil } })
            ) {
                Button(localizationManager.localized("done"), role: .cancel) {}
            } message: {
                Text(restoreMessage ?? "")
            }
        }
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
        case .connecting:
            return localizationManager.localized("status_connecting")
        case .reconnecting(let attempt, let maxAttempts):
            return String(format: localizationManager.localized("reconnecting_status"), attempt, maxAttempts)
        case .disconnected:
            return localizationManager.localized("status_disconnected")
        }
    }

    private var statusSubtitle: String {
        switch collaborationManager.status {
        case .connected(let rid):
            return "\(localizationManager.localized("room_id")): \(rid)"
        case .connecting:
            return collaborationManager.serverAddress
        case .reconnecting:
            if collaborationManager.queuedOplogCount > 0 {
                return String(format: localizationManager.localized("offline_queue_hint"), collaborationManager.queuedOplogCount)
            } else {
                return collaborationManager.serverAddress
            }
        case .disconnected:
            return localizationManager.localized("start_collaboration")
        }
    }

    // MARK: - 已連線房間詳情與成員清單
    private func connectedRoomSection(roomId: String) -> some View {
        VStack(spacing: 16) {
            // 🔒 端對端加密保護提示條
            HStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text(localizationManager.localized("e2ee_protected"))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text(localizationManager.localized("e2ee_protected_desc"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(Color.green.opacity(0.1))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.green.opacity(0.25), lineWidth: 1)
            )

            // 這台裝置正在擔任中繼點（見 `LocalRelayServer`）。
            //
            // # 為什麼一定要顯示出來
            //
            // 在此之前這個狀態只存在 `CollaborationManager` 的屬性裡，
            // 畫面上完全看不到 —— Android 早就在協同面板上顯示了，Apple 沒有。
            //
            // 兩個後果：使用者不知道邀請要用哪個位址（區網上的另一台裝置
            // 連 `127.0.0.1` 是連不到的）；而在 macOS 上，**審查員也看不到
            // 這個 App 真的在監聽連入連線** —— App Store 的自動分析因此
            // 判定 `com.apple.security.network.server` 沒有對應功能。
            if collaborationManager.isHostingLocalRelay {
                HStack(spacing: 10) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(localizationManager.localized("hosting_local_relay"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        // 區網位址是**別台裝置要連的那一個**。
                        Text(
                            collaborationManager.lanRelayAddress
                                ?? localizationManager.localized("local_relay_hint")
                        )
                        .font(.caption2)
                        .monospaced()
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                    }

                    Spacer()
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
                .accessibilityIdentifier("collaboration.hosting_relay")
            }

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
                        UIPasteboard.general.string = collaborationManager.encryptedInviteLink
                        #endif
                        showCopiedAlert = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showCopiedAlert ? "checkmark" : "link.badge.plus")
                            Text(showCopiedAlert ? localizationManager.localized("room_id_copied") : localizationManager.localized("copy_encrypted_link"))
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

                // 只貼房號、沒帶金鑰就加入的話，連得上、也看得到成員，
                // **但對方寫的每一個字都解不開** —— 畫面上什麼都不會發生，
                // 而使用者會以為是同步壞了。這是這個功能最容易踩的一個坑，
                // 所以連上之後就把它講明白。
                if !collaborationManager.isHost && collaborationManager.roomKeyBase64 == nil {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(localizationManager.localized("collab_key_missing"))
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(10)
                }

                // 本機正在當中繼點時，把隊友要輸入的區域網路位址直接顯示出來，
                // 否則對方只拿到房號，還是不知道要連到哪一台。
                if collaborationManager.isHostingLocalRelay {
                    HStack(spacing: 6) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text(collaborationManager.lanRelayAddress.map {
                            "\(localizationManager.localized("hosting_local_relay"))  \($0)"
                        } ?? localizationManager.localized("hosting_local_relay"))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.horizontal, 4)
                }
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

    // MARK: - 斷線自動重連中過渡狀態
    private func reconnectingSection(attempt: Int, maxAttempts: Int) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .padding(.top, 10)

            VStack(spacing: 6) {
                Text(String(format: localizationManager.localized("reconnecting_status"), attempt, maxAttempts))
                    .font(.headline)
                    .foregroundColor(.primary)

                if collaborationManager.queuedOplogCount > 0 {
                    Text(String(format: localizationManager.localized("offline_queue_hint"), collaborationManager.queuedOplogCount))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let err = collaborationManager.lastErrorMessage {
                    Text(err)
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                }
            }

            Button {
                collaborationManager.forceReconnect()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text(localizationManager.localized("reconnect_now"))
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)

            Button(localizationManager.localized("cancel")) {
                collaborationManager.disconnect()
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
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

                Text(localizationManager.localized("local_relay_hint"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                // **協同不限於同一個網路。**
                //
                // 核心的位址檢查一直是允許 `wss://` 連到任何主機的
                // （見 `collab_check_server`），但介面上從頭到尾只講區網位址，
                // 於是使用者合理地以為「這功能只能在同一個 Wi-Fi 用」。
                // 能力一直在，只是沒有人講。
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "globe")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    Text(localizationManager.localized("relay_remote_hint"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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

            CollabAdvancedFeaturesPanel()
                .padding(.horizontal)

            if snapshots.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text(localizationManager.localized("milestone_empty"))
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 24)
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
                                HStack(spacing: 5) {
                                    Text(snap.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    // 自動快照與舊版檔要標出來 —— 按了幾次還原之後，
                                    // 清單裡系統產生的項目會比使用者自己命名的還多。
                                    if snap.automatic {
                                        badge(localizationManager.localized("milestone_automatic"), .secondary)
                                    }
                                    if snap.isLegacy {
                                        badge(localizationManager.localized("milestone_legacy"), .orange)
                                    }
                                }

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
        guard store.restoreMilestoneSnapshot(notebookId: nId, snapshot: snap) else {
            restoreMessage = localizationManager.localized("milestone_restore_failed")
            return
        }
        loadSnapshots()
        // 還原前那一刻被自動存成一個里程碑。**一定要講出來** ——
        // 不然使用者不知道剛剛那半小時的工作還回得來，會以為按錯了就沒了。
        if let safety = snapshots.first(where: { $0.automatic }) {
            restoreMessage = String(
                format: localizationManager.localized("milestone_restored"), safety.title)
        }
        dismiss()
    }

    /// 清單上的小標記。
    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
    }

    private func formatSnapshotDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}
