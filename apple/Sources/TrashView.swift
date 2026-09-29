//
//  TrashView.swift
//  Kairumo
//
//  回收桶畫面：還原、永久刪除、清空，以及保留期限設定。
//  設計見 docs/plans/expiry-purge.md；Android 端對應 `TrashScreen.kt`。
//
//  # 這個畫面只「顯示」，不「決定」
//
//  「還剩幾天」「是否期滿」全部來自核心（`AccountSyncStore.trashEntries()`）。
//  這裡不自己算日期 —— 兩個平台各算一份的話，同一本筆記本在 iPad 上顯示還剩
//  3 天、在 Android 上卻已經被清掉。
//
//  # 清單以「本機真的還有的」為準
//
//  墓碑會永遠留在索引裡（不然別台會把刪掉的東西傳回來），所以不能拿「索引裡所有
//  墓碑」當清單 —— 永久刪除之後它還會一直出現。這裡列的是 `trashedNotebooks`，
//  再去核心的清單裡找它的時間資訊。
//

import SwiftUI

public struct TrashView: View {
    @ObservedObject private var store = NotebookStore.shared
    @ObservedObject private var sync = AccountSyncStore.shared
    @ObservedObject private var localization = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var retentionDays: UInt32 = TrashRetention.days
    @State private var pendingDelete: NotebookDocument?
    @State private var confirmEmpty = false
    @State private var waitingDevices: [String] = []

    public init() {}

    private func L(_ key: String) -> String { localization.localized(key) }

    /// 本機回收桶裡的每一本，配上核心算出的時間資訊。最近刪的在前。
    private var rows: [(document: NotebookDocument, entry: FfiTrashEntry?)] {
        let entries = Dictionary(
            sync.trashEntries().map { ($0.id.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first })
        return store.trashedNotebooks
            .map { ($0, entries[$0.id.lowercased()]) }
            .sorted { ($0.1?.deletedAt ?? 0) > ($1.1?.deletedAt ?? 0) }
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker(L("trash_retention_title"), selection: $retentionDays) {
                        ForEach(TrashRetention.choices, id: \.self) { days in
                            Text(retentionLabel(days)).tag(days)
                        }
                    }
                    .accessibilityIdentifier("trash.retention")
                } footer: {
                    Text(L("trash_retention_footer"))
                }

                Section {
                    if rows.isEmpty {
                        Text(L("trash_empty"))
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("trash.empty")
                    } else {
                        ForEach(rows, id: \.document.id) { row in
                            trashRow(row.document, entry: row.entry)
                        }
                    }
                } footer: {
                    if !waitingDevices.isEmpty {
                        Text(
                            L("trash_waiting_devices")
                                .replacingFirst("%@", with: waitingDevices.joined(separator: ", ")))
                    }
                }
            }
            .navigationTitle(L("trash_title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("trash_empty_action"), role: .destructive) {
                        confirmEmpty = true
                    }
                    .disabled(rows.isEmpty)
                    .accessibilityIdentifier("trash.emptyAction")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("done")) { dismiss() }
                        .accessibilityIdentifier("trash.done")
                }
            }
            .onChange(of: retentionDays) { newValue in
                TrashRetention.days = newValue
            }
            .alert(
                L("trash_delete_forever_confirm_title"),
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }),
                presenting: pendingDelete
            ) { document in
                Button(L("trash_delete_forever"), role: .destructive) {
                    store.purgeNotebookPermanently(id: document.id)
                }
                Button(L("cancel"), role: .cancel) {}
            } message: { document in
                Text(
                    L("trash_delete_forever_confirm_message")
                        .replacingFirst("%@", with: displayTitle(document)))
            }
            .alert(L("trash_empty_confirm_title"), isPresented: $confirmEmpty) {
                Button(L("trash_empty_action"), role: .destructive) { emptyTrash() }
                Button(L("cancel"), role: .cancel) {}
            } message: {
                Text(L("trash_empty_confirm_message"))
            }
        }
        .accessibilityIdentifier("trash.sheet")
    }

    private func trashRow(_ document: NotebookDocument, entry: FfiTrashEntry?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(displayTitle(document))
                .font(.headline)
            Text(countdownText(entry))
                .font(.footnote)
                .foregroundColor(entry.map { $0.hasCountdown && $0.daysLeft == 0 } == true ? .red : .secondary)
            HStack(spacing: 12) {
                Button(L("trash_restore")) { restore(document) }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("trash.restore")
                Button(L("trash_delete_forever"), role: .destructive) {
                    pendingDelete = document
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("trash.deleteForever")
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("trash.row")
    }

    private func displayTitle(_ document: NotebookDocument) -> String {
        let title = document.displayTitle()
        return title.isEmpty ? L("untitled_note") : title
    }

    /// 剩餘時間的說明。三種「沒有數字」的情況要分開講，不能都顯示成空白：
    /// 期限是「永不」、舊墓碑還沒有起算點、已期滿等待清除。
    private func countdownText(_ entry: FfiTrashEntry?) -> String {
        guard let entry else { return L("trash_clock_pending") }
        if !entry.hasCountdown {
            // 沒倒數有兩個原因：保留期是「永不」，或這個墓碑還沒被補蓋章。
            return TrashRetention.days == 0 ? L("trash_keep_forever_row") : L("trash_clock_pending")
        }
        if entry.daysLeft == 0 { return L("trash_expired") }
        return L("trash_days_left").replacingFirst("%@", with: "\(entry.daysLeft)")
    }

    private func retentionLabel(_ days: UInt32) -> String {
        days == 0
            ? L("trash_retention_forever")
            : L("trash_retention_days").replacingFirst("%@", with: "\(days)")
    }

    private func restore(_ document: NotebookDocument) {
        // 本機回收桶裡有就從本機還原；沒有（只在雲端）就只記還原，下一輪同步會把它拉回來。
        if !store.restoreNotebook(id: document.id) {
            AccountSyncStore.shared.recordRestore(id: document.id)
        }
    }

    private func emptyTrash() {
        store.emptyTrash()
        // 雲端那一半：忽略保留天數，但仍然要等所有必要裝置確認。
        Task {
            if let result = await CloudSync.reclaimDeleted(emptyTrash: true) {
                waitingDevices = result.waitingDevices
            }
        }
    }
}
