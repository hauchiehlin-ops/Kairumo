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
                    .disabled(isMoving)
                    .accessibilityIdentifier("storage.location.choose")
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
                isMoving = true
                statusMessage = nil
                Task { @MainActor in
                    defer { isMoving = false }
                    do {
                        try await store.moveStorage(toParentFolder: folder)
                        statusMessage = "✓ " + localization.localized("storage_move_complete")
                        if isRequired { dismiss() }
                    } catch {
                        statusMessage = error.localizedDescription
                    }
                }
            }
        }
        .interactiveDismissDisabled(isRequired)
    }
}
