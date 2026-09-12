//
//  HomeWorkbenchView.swift
//  Kairumo
//
//  首頁工作台：真實持久化、可操作介面
//  支援動態顯示登入帳號名稱、真實筆記畫布編輯、實體錄音與音訊播放
//  跨平台架構：iOS / iPadOS / macOS (Mac Catalyst)
//

import SwiftUI

#if canImport(PadnoteCore)
import PadnoteCore
#endif

/// Kairumo 首頁工作台（真實可操作介面）
public struct HomeWorkbenchView: View {
    @StateObject private var accountManager = AccountManager.shared
    @StateObject private var notebookStore = NotebookStore.shared
    @StateObject private var audioManager = AudioRecorderManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared

    @State private var searchText: String = ""
    @State private var showInfoSheet: Bool = false
    @State private var showAccountSheet: Bool = false
    @State private var showNewNotebookSheet: Bool = false
    @State private var showQuickRecordSheet: Bool = false
    @State private var selectedSortOption: SortOption = .byDate
    @State private var selectedNotebookForEditing: NotebookDocument? = nil

    // 新增筆記暫存狀態
    @State private var newNoteTitle: String = ""
    @State private var selectedTemplate: NoteTemplate = .blank
    @State private var selectedNewNoteCategory: NoteThemeCategory = .general
    @State private var showAssetLibrarySheet: Bool = false

    // 重新命名彈窗
    @State private var renamingNotebookId: String? = nil
    @State private var renameText: String = ""

    // 各區塊展開 (All) 與個別檔案隱藏/刪除狀態
    @State private var showAllContinue: Bool = false
    @State private var showAllRecordings: Bool = false
    @State private var hiddenNoteIds: Set<String> = []
    @State private var hiddenRecordingIds: Set<String> = []

    public enum SortOption: String, CaseIterable, Identifiable {
        case byDate = "依修改時間排序"
        case byTitle = "依名稱排序"
        case onlyRecordings = "僅顯示含錄音筆記"

        public var id: String { rawValue }
    }

    public init() {}

    /// 取得核心版本資訊
    public var appVersionString: String {
        #if canImport(PadnoteCore)
        let v = coreVersion()
        if !v.isEmpty { return "v\(v)" }
        #endif
        let bundleVer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return "v\(bundleVer)"
    }

    /// 核心平台環境描述
    public var platformArchitectureDescription: String {
        #if targetEnvironment(macCatalyst)
        return "Mac Catalyst (Apple Silicon / Intel)"
        #elseif os(macOS)
        return "macOS 原生"
        #elseif os(iOS)
        #if targetEnvironment(simulator)
        return "iOS 模擬器"
        #else
        return "iOS / iPadOS 實機"
        #endif
        #else
        return "Apple 通用架構"
        #endif
    }

    /// 依搜尋關鍵字與排序選項過濾真實筆記清單
    private var filteredNotebooks: [NotebookDocument] {
        var list = notebookStore.notebooks

        if !searchText.isEmpty {
            list = list.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                ($0.previewSnippet?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        switch selectedSortOption {
        case .byDate:
            return list.sorted { $0.lastModifiedDate > $1.lastModifiedDate }
        case .byTitle:
            return list.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .onlyRecordings:
            return list.filter { $0.hasRecording }
        }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 1. 頂部使用者帳號資訊條
                    userAccountBanner

                    // 2. 頂部搜尋列
                    searchBarSection

                    // 3. 主要動作：新增筆記、開始錄音（皆為真實可操作按鈕）
                    primaryActionsSection

                    // 4. 繼續：最近開啟之真實筆記
                    continueWorkingSection

                    // 5. 最近錄音：真實音訊播放與轉錄清單
                    recentRecordingsSection

                    // 6. 全部筆記（真實多頁手繪文件）
                    allNotebooksSection

                    // 7. 底部工作台品牌與版本號
                    footerVersionSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            // 將「今日工作台」標題改為「使用者登入帳號名稱」
            .navigationTitle(accountManager.profile.displayName)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 8) {
                        // 介面語系選單
                        Menu {
                            ForEach(AppLanguage.allCases) { lang in
                                Button {
                                    localizationManager.setLanguage(lang)
                                } label: {
                                    HStack {
                                        Text(lang.endonym)
                                        if localizationManager.currentLanguage == lang {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "globe")
                                Text(localizationManager.currentLanguage.endonym)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.primary.opacity(0.08))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .help("選擇介面語言 (Language)")

                        // 開啟 Kairumo Record 資料夾按鈕
                        Button {
                            audioManager.openRecordingsFolderInFinder()
                        } label: {
                            Image(systemName: "folder")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .help("在 Finder 開啟 Kairumo Record 錄音資料夾")

                        // 📦 素材圖庫按鈕
                        Button {
                            showAssetLibrarySheet = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "shippingbox.fill")
                                    .foregroundColor(.accentColor)
                                Text(localizationManager.localized("asset_library"))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                        .help(localizationManager.localized("asset_library"))

                        // 使用者頭像按鈕（點擊進入個人資料管理）
                        Button {
                            showAccountSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 26, height: 26)
                                    Text(String(accountManager.profile.displayName.prefix(1)).uppercased())
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                Text(accountManager.profile.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                        .help("點擊管理帳號資料")

                        // 版本資訊膠囊按鈕
                        Button {
                            showInfoSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                Text(appVersionString)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.12))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("關於 Kairumo 與版本號")
                    }
                }
            }
            .sheet(isPresented: $showAssetLibrarySheet) {
                AssetLibraryView()
            }
            .sheet(isPresented: $showAccountSheet) {
                AccountProfileSheet()
            }
            .sheet(isPresented: $showInfoSheet) {
                AppDiagnosticsSheet(versionString: appVersionString, platformDesc: platformArchitectureDescription)
            }
            .sheet(isPresented: $showNewNotebookSheet) {
                newNotebookModal
            }
            .sheet(isPresented: $showQuickRecordSheet) {
                QuickAudioRecorderModal()
            }
            .fullScreenCover(item: $selectedNotebookForEditing) { doc in
                if let index = notebookStore.notebooks.firstIndex(where: { $0.id == doc.id }) {
                    NotebookEditorView(notebook: $notebookStore.notebooks[index])
                }
            }
            .alert("重新命名筆記", isPresented: Binding(
                get: { renamingNotebookId != nil },
                set: { if !$0 { renamingNotebookId = nil } }
            )) {
                TextField("輸入新標題", text: $renameText)
                Button("取消", role: .cancel) { renamingNotebookId = nil }
                Button("儲存") {
                    if let id = renamingNotebookId {
                        notebookStore.renameNotebook(id: id, newTitle: renameText)
                    }
                    renamingNotebookId = nil
                }
            }
            .alert(localizationManager.localized("mic_permission_title"), isPresented: $audioManager.showPermissionAlert) {
                Button(localizationManager.localized("cancel"), role: .cancel) {
                    audioManager.showPermissionAlert = false
                }
                Button(localizationManager.localized("open_settings")) {
                    audioManager.openSystemSettings()
                }
            } message: {
                Text(localizationManager.localized("mic_permission_msg"))
            }
        }
    }

    // MARK: - 1. 頂部使用者帳號橫幅
    private var userAccountBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                Text(String(accountManager.profile.displayName.prefix(1)).uppercased())
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(accountManager.profile.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("線上")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(6)
                }

                Text("\(accountManager.profile.email.isEmpty ? "@" + accountManager.profile.username : accountManager.profile.email) • \(accountManager.profile.syncStatusText)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                showAccountSheet = true
            } label: {
                Text(localizationManager.localized("switch_account"))
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - 2. 頂部搜尋列
    private var searchBarSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(localizationManager.localized("search_placeholder"), text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
    }

    // MARK: - 3. 主要動作按鈕（真實可操作）
    private var primaryActionsSection: some View {
        HStack(spacing: 14) {
            // 真實動作：新增筆記（彈出範本選擇器）
            Button {
                newNoteTitle = "未命名筆記 \(notebookStore.notebooks.count + 1)"
                selectedTemplate = .blank
                showNewNotebookSheet = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localizationManager.localized("new_note"))
                            .font(.headline)
                        Text(localizationManager.localized("new_note_desc"))
                            .font(.caption2)
                            .opacity(0.85)
                    }
                    Spacer()
                }
                .padding()
                .foregroundColor(.white)
                .background(LinearGradient(colors: [.accentColor, .accentColor.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .cornerRadius(14)
            }
            .buttonStyle(.plain)

            // 真實動作：開始麥克風錄音（彈出即時錄音器）
            Button {
                showQuickRecordSheet = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "waveform.badge.mic")
                        .font(.title3)
                        .foregroundColor(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localizationManager.localized("start_recording"))
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(localizationManager.localized("start_recording_desc"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.red.opacity(0.25), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 4. 繼續 Working Section（真實筆記）
    private var continueWorkingSection: some View {
        let visibleList = filteredNotebooks.filter { !hiddenNoteIds.contains($0.id) }
        let displayedList = showAllContinue ? visibleList : Array(visibleList.prefix(5))

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(localizationManager.localized("continue"))
                    .font(.title3)
                    .fontWeight(.bold)

                if !hiddenNoteIds.isEmpty {
                    Button {
                        withAnimation {
                            hiddenNoteIds.removeAll()
                        }
                    } label: {
                        Text(localizationManager.localized("unhide_items"))
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // 各區塊「All / 全部」展開切換功能
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAllContinue.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(showAllContinue ? "收合" : "\(localizationManager.localized("show_all")) (\(visibleList.count))")
                        Image(systemName: showAllContinue ? "chevron.up" : "chevron.down")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            if visibleList.isEmpty {
                HStack {
                    Spacer()
                    Text(searchText.isEmpty ? "尚無筆記或皆已隱藏，點選「新增筆記」開始繪製" : "找不到符合「\(searchText)」的筆記")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 24)
                    Spacer()
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(14)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(displayedList) { note in
                            Button {
                                selectedNotebookForEditing = note
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Image(systemName: note.template.iconName)
                                            .foregroundColor(.accentColor)

                                        if note.hasRecording {
                                            HStack(spacing: 3) {
                                                Circle()
                                                    .fill(Color.red)
                                                    .frame(width: 6, height: 6)
                                                Image(systemName: "waveform")
                                                    .font(.caption2)
                                                    .foregroundColor(.red)
                                            }
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.red.opacity(0.1))
                                            .cornerRadius(8)
                                        }

                                        Spacer()

                                        // 個別檔案功能選項（隱藏、重新命名、副本、刪除）
                                        Menu {
                                            Button {
                                                selectedNotebookForEditing = note
                                            } label: {
                                                Label("開啟編輯", systemImage: "pencil.and.scribble")
                                            }
                                            Button {
                                                withAnimation {
                                                    hiddenNoteIds.insert(note.id)
                                                }
                                            } label: {
                                                Label(localizationManager.localized("hide_item"), systemImage: "eye.slash")
                                            }
                                            Button {
                                                renameText = note.title
                                                renamingNotebookId = note.id
                                            } label: {
                                                Label("重新命名", systemImage: "pencil")
                                            }
                                            Button {
                                                notebookStore.duplicateNotebook(id: note.id)
                                            } label: {
                                                Label("建立副本", systemImage: "doc.on.doc")
                                            }
                                            Divider()
                                            Button(role: .destructive) {
                                                notebookStore.deleteNotebook(id: note.id)
                                            } label: {
                                                Label(localizationManager.localized("delete_item"), systemImage: "trash")
                                            }
                                        } label: {
                                            Image(systemName: "ellipsis.circle")
                                                .font(.system(size: 15))
                                                .foregroundColor(.secondary)
                                                .padding(2)
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    Text(note.title)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)

                                    if let snippet = note.previewSnippet {
                                        Text(snippet)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }

                                    Spacer(minLength: 0)

                                    HStack {
                                        Text("\(note.pageCount) 頁 · \(note.template.rawValue)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(note.lastModifiedDate, style: .time)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(14)
                                .frame(width: 220, height: 140)
                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                                .cornerRadius(14)
                                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - 5. 最近錄音（真實實體播放）
    private var recentRecordingsSection: some View {
        let visibleRecordings = notebookStore.recordings.filter { !hiddenRecordingIds.contains($0.id) }
        let displayedRecordings = showAllRecordings ? visibleRecordings : Array(visibleRecordings.prefix(4))

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(localizationManager.localized("recent_recordings"))
                    .font(.title3)
                    .fontWeight(.bold)

                if !hiddenRecordingIds.isEmpty {
                    Button {
                        withAnimation {
                            hiddenRecordingIds.removeAll()
                        }
                    } label: {
                        Text(localizationManager.localized("unhide_items"))
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // 各區塊「All / 全部」展開切換功能
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAllRecordings.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(showAllRecordings ? "收合" : "\(localizationManager.localized("show_all")) (\(visibleRecordings.count))")
                        Image(systemName: showAllRecordings ? "chevron.up" : "chevron.down")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button {
                    audioManager.openRecordingsFolderInFinder()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                        Text("開啟 Kairumo Record")
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help("在 Finder 開啟本機文件夾中的 Kairumo Record 錄音目錄")
            }

            if visibleRecordings.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "mic.slash")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("目前尚無錄音檔或皆已隱藏，點擊「開始錄音」即可即時收音")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
            } else {
                VStack(spacing: 10) {
                    ForEach(displayedRecordings) { rec in
                        let fileUrl = audioManager.recordingsDirectory.appendingPathComponent(rec.fileName)
                        let isPlayingThis = audioManager.isPlaying && audioManager.playingRecordingId == rec.id

                        HStack(spacing: 14) {
                            Button {
                                audioManager.playAudio(url: fileUrl, recordingId: rec.id)
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.red.opacity(0.12))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                                        .foregroundColor(.red)
                                        .font(.subheadline)
                                }
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(rec.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                HStack(spacing: 8) {
                                    Text(formatDuration(seconds: rec.durationSeconds))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("•")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(rec.transcriptionStatus)
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                    Text("•")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(rec.recordedDate, style: .date)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            if isPlayingThis {
                                ProgressView(value: audioManager.playbackProgress)
                                    .frame(width: 60)
                            } else {
                                Image(systemName: "waveform")
                                    .foregroundColor(.secondary.opacity(0.7))
                                    .font(.title3)
                            }

                            // 個別檔案功能選項（隱藏、開啟資料夾、刪除）
                            Menu {
                                Button {
                                    withAnimation {
                                        hiddenRecordingIds.insert(rec.id)
                                    }
                                } label: {
                                    Label(localizationManager.localized("hide_item"), systemImage: "eye.slash")
                                }
                                Button {
                                    audioManager.openRecordingsFolderInFinder()
                                } label: {
                                    Label("在資料夾中顯示", systemImage: "folder")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    notebookStore.deleteRecording(id: rec.id)
                                } label: {
                                    Label("刪除錄音檔", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                    .padding(4)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }

    // MARK: - 6. 全部筆記（真實多頁手繪文件）
    private var allNotebooksSection: some View {
        let visibleList = filteredNotebooks.filter { !hiddenNoteIds.contains($0.id) }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(localizationManager.localized("all_notebooks")) (\(visibleList.count))")
                    .font(.title3)
                    .fontWeight(.bold)

                if !hiddenNoteIds.isEmpty {
                    Button {
                        withAnimation {
                            hiddenNoteIds.removeAll()
                        }
                    } label: {
                        Text(localizationManager.localized("unhide_items"))
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
                Menu {
                    ForEach(SortOption.allCases) { opt in
                        Button {
                            selectedSortOption = opt
                        } label: {
                            HStack {
                                Text(opt.rawValue)
                                if selectedSortOption == opt {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedSortOption.rawValue)
                            .font(.caption)
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 14)], spacing: 14) {
                ForEach(visibleList) { note in
                    Button {
                        selectedNotebookForEditing = note
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack(alignment: .topTrailing) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                                    .frame(height: 110)

                                VStack(spacing: 6) {
                                    Image(systemName: note.template.iconName)
                                        .font(.largeTitle)
                                        .foregroundColor(.accentColor.opacity(0.7))
                                    Text(note.title)
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .foregroundColor(.secondary)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)

                                // 個別功能選項
                                Menu {
                                    Button {
                                        selectedNotebookForEditing = note
                                    } label: {
                                        Label("開啟編輯", systemImage: "pencil.and.scribble")
                                    }
                                    Button {
                                        withAnimation {
                                            hiddenNoteIds.insert(note.id)
                                        }
                                    } label: {
                                        Label(localizationManager.localized("hide_item"), systemImage: "eye.slash")
                                    }
                                    Button {
                                        renameText = note.title
                                        renamingNotebookId = note.id
                                    } label: {
                                        Label("重新命名", systemImage: "pencil")
                                    }
                                    Button {
                                        notebookStore.duplicateNotebook(id: note.id)
                                    } label: {
                                        Label("建立副本", systemImage: "doc.on.doc")
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        notebookStore.deleteNotebook(id: note.id)
                                    } label: {
                                        Label(localizationManager.localized("delete_item"), systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary.opacity(0.8))
                                        .padding(8)
                                }
                                .buttonStyle(.plain)
                            }

                            Text(note.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            HStack {
                                Text("\(note.pageCount) 頁")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(note.lastModifiedDate, style: .date)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(10)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 7. 底部工作台品牌與版本號
    private var footerVersionSection: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.vertical, 8)

            HStack(spacing: 8) {
                Text("Kairumo")
                    .font(.footnote)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)

                Text("•")
                    .font(.footnote)
                    .foregroundColor(.secondary.opacity(0.6))

                Button {
                    showInfoSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Text("版本 \(appVersionString)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)

                Text("•")
                    .font(.footnote)
                    .foregroundColor(.secondary.opacity(0.6))

                Text(platformArchitectureDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Text("手寫與錄音雙向對齊 · 離線優先 · 開源透明")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(.top, 16)
        .padding(.bottom, 24)
    }

    // MARK: - 新增筆記彈窗
    private var newNotebookModal: some View {
        NavigationStack {
            Form {
                Section(localizationManager.localized("note_title")) {
                    TextField(localizationManager.localized("note_title"), text: $newNoteTitle)
                }

                Section(localizationManager.localized("theme_category")) {
                    Picker("", selection: $selectedNewNoteCategory) {
                        ForEach(NoteThemeCategory.allCases) { cat in
                            HStack(spacing: 4) {
                                Image(systemName: cat.iconName)
                                Text(localizationManager.localized(cat.localizationKey))
                            }
                            .tag(cat)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                }

                Section(localizationManager.localized("select_template")) {
                    ForEach(NoteTemplate.allCases.filter { $0.category == selectedNewNoteCategory }) { tmpl in
                        HStack(spacing: 12) {
                            Image(systemName: tmpl.iconName)
                                .font(.title3)
                                .foregroundColor(selectedTemplate == tmpl ? .accentColor : .secondary)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(localizationManager.localized(tmpl.localizationKey))
                                    .font(.headline)
                                Text(localizationManager.localized(tmpl.descriptionLocalizationKey))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if selectedTemplate == tmpl {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTemplate = tmpl
                        }
                    }
                }
            }
            .navigationTitle(localizationManager.localized("new_notebook"))
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedNewNoteCategory) { newCat in
                if let first = NoteTemplate.allCases.first(where: { $0.category == newCat }) {
                    selectedTemplate = first
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) {
                        showNewNotebookSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized("confirm")) {
                        let defaultTitle = newNoteTitle.isEmpty ? localizationManager.localized("new_notebook") : newNoteTitle
                        let created = notebookStore.createNotebook(title: defaultTitle, template: selectedTemplate)
                        showNewNotebookSheet = false
                        // 立即開啟該筆記畫布進行編輯
                        selectedNotebookForEditing = created
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private func formatDuration(seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

/// 快速即時錄音彈窗視圖
struct QuickAudioRecorderModal: View {
    @ObservedObject var audioManager = AudioRecorderManager.shared
    @ObservedObject var notebookStore = NotebookStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var recordingTitle: String = "課堂/會議錄音 \(Date().formatted(date: .numeric, time: .shortened))"
    @State private var targetNotebookId: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                // 動態波形與錄音時間
                VStack(spacing: 12) {
                    Text(formatTime(seconds: audioManager.elapsedSeconds))
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(audioManager.status == .recording ? .red : .primary)

                    HStack(spacing: 3) {
                        ForEach(0..<audioManager.audioLevels.count, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(audioManager.status == .recording ? Color.red : Color.secondary.opacity(0.3))
                                .frame(width: 4, height: max(6, audioManager.audioLevels[i] * 50))
                        }
                    }
                    .frame(height: 50)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("錄音標題")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("輸入錄音標題", text: $recordingTitle)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal, 32)

                // 🌟 筆記附加對齊選項（解決使用者疑問：錄音如何被利用、是否即時出現在筆記中）
                VStack(alignment: .leading, spacing: 6) {
                    Text("附加至指定筆記（錄音完成後將即時出現在該筆記中）")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("附加至筆記", selection: $targetNotebookId) {
                        Text("不附加（僅儲存為獨立錄音）").tag(nil as String?)
                        ForEach(notebookStore.notebooks) { nb in
                            Text(nb.title).tag(nb.id as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 32)

                // 錄音控制大按鈕
                if audioManager.status == .recording {
                    Button {
                        if let res = audioManager.stopRecording() {
                            let fileName = res.url.lastPathComponent
                            notebookStore.addRecording(
                                title: recordingTitle,
                                durationSeconds: Int(res.duration),
                                fileName: fileName,
                                linkedNotebookId: targetNotebookId
                            )
                        }
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "stop.fill")
                            Text("停止並儲存至 Kairumo Record")
                                .fontWeight(.bold)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                } else {
                    Button {
                        Task {
                            _ = await audioManager.startRecording(title: recordingTitle)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "record.circle")
                            Text("開始錄音")
                                .fontWeight(.bold)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                }

                Spacer()
            }
            .navigationTitle("語音錄音與對齊")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") {
                        if audioManager.status == .recording {
                            _ = audioManager.stopRecording()
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        audioManager.openRecordingsFolderInFinder()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                            Text("Kairumo Record")
                                .font(.caption)
                        }
                    }
                    .help("在 Finder 開啟 Kairumo Record 資料夾")
                }
            }
            .onAppear {
                Task {
                    _ = await audioManager.startRecording(title: recordingTitle)
                }
            }
        }
    }

    private func formatTime(seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - 應用程式與核心診斷面板（點擊版本號展開）
public struct AppDiagnosticsSheet: View {
    let versionString: String
    let platformDesc: String
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            List {
                Section("應用程式版本資訊") {
                    HStack {
                        Text("版本號")
                        Spacer()
                        Text(versionString)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text("Rust Core 引擎")
                        Spacer()
                        Text(versionString)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("執行平台")
                        Spacer()
                        Text(platformDesc)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("架構模式")
                        Spacer()
                        Text("Mac Catalyst / iOS 通用 (方案一)")
                            .foregroundColor(.secondary)
                    }
                }

                Section("核心技術與授權") {
                    HStack {
                        Text("開源授權")
                        Spacer()
                        Text("Apache-2.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("跨平台架構")
                        Spacer()
                        Text("Rust Core + UniFFI + PencilKit/Metal/SwiftUI")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("關於 Kairumo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    HomeWorkbenchView()
}
