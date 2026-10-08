//
//  StorageUsageSection.swift
//  Kairumo
//
//  診斷面板的「儲存空間」：看得到 App 佔多少、各自是什麼，並可以立刻清理。
//

import SwiftUI

struct StorageUsageSection: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var usage: StorageSweeper.Usage?
    @State private var busy = false
    @State private var message: String?
    @State private var inkLedgerBytes: Int64 = 0
    @State private var confirmClearEraseHistory = false

    var body: some View {
        Section(loc.localized("storage_title")) {
            if let usage {
                row("storage_library", usage.library)
                row("storage_temp", usage.temp)
                row("storage_caches", usage.caches)
                row("storage_models", usage.models)
            } else {
                ProgressView()
            }
            Button {
                Task { await cleanNow() }
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text(loc.localized("storage_clean_now"))
                    Spacer()
                    if busy { ProgressView() }
                }
            }
            .disabled(busy)
            .accessibilityIdentifier("diagnostics.storage.clean")
            // 同步記錄（擦除墓碑、被擦掉的別台筆畫指紋）。平常會自動清理；這裡讓使用者看得到、也能自己動手。
            row("storage_ink_ledger", inkLedgerBytes)
            Button {
                Task { await compactInkLedger() }
            } label: {
                HStack {
                    Image(systemName: "archivebox")
                    Text(loc.localized("storage_ink_compact"))
                    Spacer()
                }
            }
            .disabled(busy)
            .accessibilityIdentifier("diagnostics.storage.ink_compact")
            Button(role: .destructive) {
                confirmClearEraseHistory = true
            } label: {
                HStack {
                    Image(systemName: "eraser.line.dashed")
                    Text(loc.localized("storage_ink_clear"))
                    Spacer()
                }
            }
            .disabled(busy)
            .accessibilityIdentifier("diagnostics.storage.ink_clear")
            .confirmationDialog(
                loc.localized("storage_ink_clear"), isPresented: $confirmClearEraseHistory, titleVisibility: .visible
            ) {
                Button(loc.localized("storage_ink_clear_action"), role: .destructive) {
                    Task { await clearEraseHistory() }
                }
                Button(loc.localized("cancel"), role: .cancel) {}
            } message: {
                Text(loc.localized("storage_ink_clear_confirm"))
            }
            if let message {
                Text(message).font(.caption).foregroundColor(.secondary)
                    .accessibilityIdentifier("diagnostics.storage.result")
            }
        }
        .task { await refresh() }
    }

    private func row(_ key: String, _ bytes: Int64) -> some View {
        HStack {
            Text(loc.localized(key))
            Spacer()
            Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                .foregroundColor(.secondary).monospacedDigit()
        }
    }

    @MainActor
    private func refresh() async {
        let library = DocumentStorageLocation.shared.rootURL
        let models = ModelDownloadManager.shared.modelsRoot
        let drawings = NotebookStore.shared.syncDrawingsDirectory
        let baseline = NotebookStore.shared.syncBaselineDirectory
        usage = await Task.detached(priority: .utility) {
            StorageSweeper.usage(library: library, modelsRoot: models)
        }.value
        inkLedgerBytes = await Task.detached(priority: .utility) {
            InkLedgerJanitor.usage(drawingsDirectory: drawings, baselineDirectory: baseline)
        }.value
    }

    @MainActor
    private func compactInkLedger() async {
        busy = true
        defer { busy = false }
        let drawings = NotebookStore.shared.syncDrawingsDirectory
        let report = await Task.detached(priority: .utility) {
            InkLedgerJanitor.compact(drawingsDirectory: drawings)
        }.value
        await refresh()
        message = String(
            format: loc.localized("storage_ink_compacted"),
            ByteCountFormatter.string(fromByteCount: report.bytesFreed, countStyle: .file))
    }

    @MainActor
    private func clearEraseHistory() async {
        busy = true
        defer { busy = false }
        let drawings = NotebookStore.shared.syncDrawingsDirectory
        let baseline = NotebookStore.shared.syncBaselineDirectory
        let report = await Task.detached(priority: .utility) {
            InkLedgerJanitor.clearEraseHistory(drawingsDirectory: drawings, baselineDirectory: baseline)
        }.value
        await refresh()
        message = String(
            format: loc.localized("storage_ink_cleared"),
            ByteCountFormatter.string(fromByteCount: report.bytesFreed, countStyle: .file))
    }

    @MainActor
    private func cleanNow() async {
        busy = true
        defer { busy = false }
        let before = usage?.total ?? 0
        var report = await StorageSweeper.sweepAtLaunch(store: NotebookStore.shared)
        // 文件庫裡沒人引用的附件與筆跡（保守規則見 StorageJanitor）。
        NotebookStore.shared.cleanUnusedFiles()
        try? await Task.sleep(nanoseconds: 800_000_000)
        await refresh()
        let freed = max(0, before - (usage?.total ?? before))
        report.tempBytes = max(report.tempBytes, 0)
        message = String(
            format: loc.localized("storage_cleaned"),
            ByteCountFormatter.string(fromByteCount: freed, countStyle: .file))
    }
}
