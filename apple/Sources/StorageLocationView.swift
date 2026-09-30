//
//  StorageLocationView.swift
//  Kairumo
//
//  主要文件庫的位置設定。所有 Apple 平台共用同一張畫面；Mac 第一次啟動
//  會以不可略過的方式顯示，以符合 Mac App Store 的使用者文件要求。
//

import SwiftUI
import UniformTypeIdentifiers

struct StorageLocationView: View {
    @ObservedObject private var location = DocumentStorageLocation.shared
    @ObservedObject private var store = NotebookStore.shared
    @ObservedObject private var localization = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    let isRequired: Bool

    @State private var showFolderPicker = false
    @State private var isMoving = false
    @State private var statusMessage: String?
    @State private var progress: DocumentStorageLocation.MoveProgress?
    @State private var moveTask: Task<Void, Never>?
    /// 使用者挑了、但在 iCloud 同步範圍內，等他確認。
    @State private var pendingFolder: URL?
    @State private var showICloudWarning = false
    @State private var currentIsICloud = false
    // 重設本機資料
    @State private var showResetConfirm = false
    @State private var alsoWipeCloud = true
    @State private var isResetting = false
    @State private var resetPhase: NotebookStore.ResetPhase?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    HStack(spacing: DS.Space.m) {
                        Image(systemName: "folder.badge.gearshape")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(localization.localized("storage_library_title"))
                                .font(DS.Font.screenTitle)
                            Text(localization.localized("storage_library_subtitle"))
                                .font(DS.Font.body)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: DS.Space.s) {
                        Text(localization.localized("storage_current_location"))
                            .font(DS.Font.caption)
                            .foregroundStyle(.secondary)
                        Text(location.displayPath)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                            .accessibilityIdentifier("storage.location.path")
                    }
                    .padding(DS.Space.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m))

                    if currentIsICloud {
                        Label(localization.localized("storage_icloud_current"),
                              systemImage: "exclamationmark.icloud")
                            .font(DS.Font.caption)
                            .foregroundStyle(Color.orange)
                            .accessibilityIdentifier("storage.location.icloud_warning")
                    }

                    Text(localization.localized("storage_library_explainer"))
                        .font(DS.Font.body)
                        .foregroundStyle(.secondary)

                    Text(localization.localized("storage_sync_explainer"))
                        .font(DS.Font.caption)
                        .foregroundStyle(.secondary)

                    if let statusMessage {
                        Text(statusMessage)
                            .font(DS.Font.caption)
                            .foregroundStyle(statusMessage.hasPrefix("✓") ? Color.green : Color.red)
                            .accessibilityIdentifier("storage.location.status")
                    }

                    if let progress {
                        VStack(alignment: .leading, spacing: DS.Space.s) {
                            if progress.phase == .copying, progress.totalFiles > 0 {
                                ProgressView(
                                    value: Double(progress.copiedFiles),
                                    total: Double(progress.totalFiles))
                            } else {
                                ProgressView()
                            }
                            Text(progressText(progress))
                                .font(DS.Font.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("storage.location.progress")
                            Button(localization.localized("cancel"), role: .cancel) {
                                moveTask?.cancel()
                            }
                            .accessibilityIdentifier("storage.location.cancel")
                        }
                    }

                    Button {
                        showFolderPicker = true
                    } label: {
                        HStack {
                            if isMoving {
                                ProgressView().padding(.trailing, 6)
                            } else {
                                Image(systemName: "folder.badge.plus")
                            }
                            Text(localization.localized("storage_choose_parent"))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isMoving || isResetting)
                    .accessibilityIdentifier("storage.location.choose")

                    Divider().padding(.vertical, DS.Space.s)

                    resetSection
                }
                .padding(DS.Space.l)
                .dsContentWidth()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(localization.localized("storage_library_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isRequired {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(localization.localized("close")) { dismiss() }
                    }
                }
            }
            .task { refreshICloudState() }
            .fileImporter(
                isPresented: $showFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                guard case let .success(urls) = result, let folder = urls.first else {
                    if case let .failure(error) = result {
                        statusMessage = error.localizedDescription
                    }
                    return
                }
                // 在 iCloud 同步範圍內先問一聲：資料庫是幾千個小檔，又已經有自己的同步，
                // 兩邊同步同一批檔案會讓已刪除的檔案被還原、互相衝突。
                if DocumentStorageLocation.isICloudSynced(folder) {
                    pendingFolder = folder
                    showICloudWarning = true
                } else {
                    startMove(folder)
                }
            }
            .alert(localization.localized("storage_icloud_title"), isPresented: $showICloudWarning) {
                Button(localization.localized("storage_icloud_continue")) {
                    if let folder = pendingFolder { startMove(folder) }
                    pendingFolder = nil
                }
                Button(localization.localized("cancel"), role: .cancel) { pendingFolder = nil }
            } message: {
                Text(localization.localized("storage_icloud_message"))
            }
            .alert(localization.localized("storage_reset_confirm_title"), isPresented: $showResetConfirm) {
                Button(localization.localized("storage_reset_confirm_action"), role: .destructive) {
                    startReset()
                }
                Button(localization.localized("cancel"), role: .cancel) {}
            } message: {
                Text(localization.localized("storage_reset_confirm_message"))
            }
        }
        .interactiveDismissDisabled(isRequired)
    }

    private func progressText(_ progress: DocumentStorageLocation.MoveProgress) -> String {
        switch progress.phase {
        case .waitingForSync:
            return localization.localized("storage_progress_waiting")
        case .copying:
            return String(
                format: localization.localized("storage_progress_copying"),
                progress.copiedFiles, progress.totalFiles)
        case .verifying:
            return localization.localized("storage_progress_verifying")
        case .removingOld:
            return localization.localized("storage_progress_cleaning")
        }
    }

    private func refreshICloudState() {
        let root = location.rootURL
        Task { @MainActor in
            currentIsICloud = await Task.detached(priority: .utility) {
                DocumentStorageLocation.isICloudSynced(root)
            }.value
        }
    }

    /// 搬移：背景做、回報進度、可取消。取消或失敗時舊資料庫原封不動。
    private func startMove(_ folder: URL) {
        isMoving = true
        statusMessage = nil
        progress = DocumentStorageLocation.MoveProgress(phase: .waitingForSync)
        moveTask = Task { @MainActor in
            defer {
                isMoving = false
                progress = nil
                moveTask = nil
                refreshICloudState()
            }
            do {
                try await store.moveStorage(toParentFolder: folder) { update in
                    Task { @MainActor in progress = update }
                }
                statusMessage = "✓ " + localization.localized("storage_move_complete")
                if isRequired { dismiss() }
            } catch is CancellationError {
                statusMessage = localization.localized("storage_move_cancelled")
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    private var resetSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text(localization.localized("storage_reset_title"))
                .font(DS.Font.cardTitle)
            Text(localization.localized("storage_reset_explainer"))
                .font(DS.Font.caption)
                .foregroundStyle(.secondary)
            Toggle(localization.localized("storage_reset_cloud_toggle"), isOn: $alsoWipeCloud)
                .disabled(isResetting)
                .accessibilityIdentifier("storage.reset.cloud_toggle")
            if alsoWipeCloud {
                Text(localization.localized("storage_reset_cloud_note"))
                    .font(DS.Font.caption)
                    .foregroundStyle(.secondary)
            }
            if isResetting {
                HStack(spacing: DS.Space.s) {
                    ProgressView()
                    Text(localization.localized(
                        resetPhase == .cloud ? "storage_reset_progress_cloud" : "storage_reset_progress_local"))
                        .font(DS.Font.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Text(localization.localized("storage_reset_button"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .disabled(isMoving || isResetting)
            .accessibilityIdentifier("storage.reset.button")
        }
    }

    private func startReset() {
        isResetting = true
        statusMessage = nil
        resetPhase = alsoWipeCloud ? .cloud : .local
        Task { @MainActor in
            defer {
                isResetting = false
                resetPhase = nil
                refreshICloudState()
            }
            do {
                try await store.resetLocalData(alsoWipeCloud: alsoWipeCloud) { phase in
                    Task { @MainActor in resetPhase = phase }
                }
                statusMessage = "✓ " + localization.localized("storage_reset_done")
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }
}
