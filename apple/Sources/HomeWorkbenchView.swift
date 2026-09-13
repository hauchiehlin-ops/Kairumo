//
//  HomeWorkbenchView.swift
//  Kairumo
//
//  首頁工作台：真實持久化、可操作介面
//  支援動態顯示登入帳號名稱、真實筆記畫布編輯、實體錄音與音訊播放
//  跨平台架構：iOS / iPadOS / macOS (Mac Catalyst)
//

import SwiftUI
import PencilKit

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
    @State private var viewingDocument: BundledDocument? = nil
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

    // 資料夾管理與過濾狀態
    @State private var selectedFolderId: String? = nil
    @State private var showRenameRootFolderAlert: Bool = false
    @State private var rootFolderRenameText: String = ""
    @State private var showNewFolderAlert: Bool = false
    @State private var newFolderNameText: String = ""
    @State private var newFolderParentId: String? = nil
    @State private var folderToRename: FolderItem? = nil
    @State private var folderRenameText: String = ""
    @State private var showMoveNotebookSheet: Bool = false
    @State private var notebookToMoveId: String? = nil

    public enum SortOption: String, CaseIterable, Identifiable {
        case byDate = "date"
        case byTitle = "title"
        case onlyRecordings = "recordings"

        public var id: String { rawValue }

        @MainActor
        public func localizedTitle(using localizationManager: LocalizationManager) -> String {
            switch self {
            case .byDate: return localizationManager.localized("sort_by_date")
            case .byTitle: return localizationManager.localized("sort_by_title")
            case .onlyRecordings: return localizationManager.localized("sort_only_recordings")
            }
        }
    }

    public init() {}

    /// 取得核心版本資訊
    public var appVersionString: String {
        #if canImport(PadnoteCore)
        let v = coreVersion()
        if !v.isEmpty { return "v\(v)" }
        #endif
        return "v\(AppVersion.marketing)"
    }

    /// 核心平台環境描述
    public var platformArchitectureDescription: String {
        #if targetEnvironment(macCatalyst)
        return "Mac Catalyst (Apple Silicon / Intel)"
        #elseif os(macOS)
        return "macOS Native"
        #elseif os(iOS)
        #if targetEnvironment(simulator)
        return "iOS Simulator"
        #else
        return "iOS / iPadOS Device"
        #endif
        #else
        return "Apple Universal"
        #endif
    }

    /// 依搜尋關鍵字與排序選項過濾真實筆記清單
    private var filteredNotebooks: [NotebookDocument] {
        var list = notebookStore.notebooks

        if !searchText.isEmpty {
            list = list.filter {
                $0.displayTitle().localizedCaseInsensitiveContains(searchText) ||
                ($0.previewSnippet?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        switch selectedSortOption {
        case .byDate:
            return list.sorted { $0.lastModifiedDate > $1.lastModifiedDate }
        case .byTitle:
            return list.sorted { $0.displayTitle().localizedCompare($1.displayTitle()) == .orderedAscending }
        case .onlyRecordings:
            return list.filter { $0.hasRecording }
        }
    }

    public var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 24) {
                        // 1. 頂部使用者帳號資訊條（自適應寬窄螢幕）
                        userAccountBanner

                        // 2. 頂部搜尋列
                        searchBarSection

                        // 3. 主要動作：新增筆記、開始錄音、📦素材圖庫（自適應網格）
                        primaryActionsSection

                        // 4. 繼續：最近開啟之真實筆記
                        continueWorkingSection

                        // 5. 最近錄音：真實音訊播放與轉錄清單
                        recentRecordingsSection

                        // 6. 全部筆記（真實多頁手繪文件）
                        allNotebooksSection

                        // 7. 底部工作台品牌與版本號
                        documentsSection

                    footerVersionSection
                    }
                    .padding(.horizontal, max(12, min(22, proxy.size.width * 0.035)))
                    .padding(.vertical, 16)
                    .frame(width: proxy.size.width, alignment: .topLeading)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            // 將「今日工作台」標題改為「使用者登入帳號名稱」
            .navigationTitle(accountManager.profile.displayName)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 8) {
                        // 介面語系下拉式選單 (Prominent Language Dropdown)
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
                            HStack(spacing: 5) {
                                Image(systemName: "globe")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.accentColor)
                                Text(localizationManager.currentLanguage.endonym)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.accentColor.opacity(0.35), lineWidth: 1.2)
                            )
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
                        }
                        .buttonStyle(.plain)
                        .help(localizationManager.localized("select_language"))

                        // 📦 素材圖庫快捷鍵
                        Button {
                            showAssetLibrarySheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "shippingbox.fill")
                                    .foregroundColor(.purple)
                                Text(localizationManager.localized("asset_library"))
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.purple.opacity(0.12))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .help(localizationManager.localized("asset_library"))

                        // 快捷工作台選單（開啟資料夾、帳號設定、診斷）
                        Menu {
                            Button {
                                showAccountSheet = true
                            } label: {
                                Label(accountManager.profile.displayName, systemImage: "person.crop.circle")
                            }

                            Button {
                                audioManager.openRecordingsFolderInFinder()
                            } label: {
                                Label(localizationManager.localized("open_record_folder"), systemImage: "folder")
                            }

                            Divider()

                            Button {
                                showInfoSheet = true
                            } label: {
                                Label("\(localizationManager.localized("system_diagnostics")) (\(appVersionString))", systemImage: "info.circle")
                            }
                            .accessibilityIdentifier("home.diagnostics")
                        } label: {
                            HStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 22, height: 22)
                                    Text(String(accountManager.profile.displayName.prefix(1)).uppercased())
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                Image(systemName: "ellipsis.circle")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        }
                        // UI 測試要能穩定點到這個選單。靠 "ellipsis" 這種系統圖示名稱
                        // 去猜，會先命中筆記卡片上的那個「⋯」。
                        .accessibilityIdentifier("home.workbenchMenu")
                    }
                }
            }
            .sheet(isPresented: $showAssetLibrarySheet) { erasedView {
                AssetLibraryView()
            } }
            .sheet(isPresented: $showAccountSheet) { erasedView {
                AccountProfileSheet()
            } }
            .sheet(item: $viewingDocument) { doc in erasedView {
                DocumentViewerSheet(document: doc)
            } }
            .sheet(isPresented: $showInfoSheet) { erasedView {
                AppDiagnosticsSheet(versionString: appVersionString, platformDesc: platformArchitectureDescription)
            } }
            .sheet(isPresented: $showNewNotebookSheet) { erasedView {
                newNotebookModal
            } }
            .sheet(isPresented: $showQuickRecordSheet) { erasedView {
                QuickAudioRecorderModal()
            } }
            .fullScreenCover(item: $selectedNotebookForEditing) { doc in erasedView {
                NotebookEditorHost(store: notebookStore, initialNotebookId: doc.id)
            } }
            .alert(localizationManager.localized("rename_note"), isPresented: Binding(
                get: { renamingNotebookId != nil },
                set: { if !$0 { renamingNotebookId = nil } }
            )) {
                TextField(localizationManager.localized("enter_title"), text: $renameText)
                Button(localizationManager.localized("cancel"), role: .cancel) { renamingNotebookId = nil }
                Button(localizationManager.localized("save")) {
                    if let id = renamingNotebookId {
                        notebookStore.renameNotebook(id: id, newTitle: renameText)
                    }
                    renamingNotebookId = nil
                }
            }
            .alert(localizationManager.localized("edit_root_folder"), isPresented: $showRenameRootFolderAlert) {
                TextField(localizationManager.localized("root_folder"), text: $rootFolderRenameText)
                Button(localizationManager.localized("cancel"), role: .cancel) {}
                Button(localizationManager.localized("confirm")) {
                    notebookStore.renameRootFolder(newName: rootFolderRenameText)
                }
            }
            .alert(localizationManager.localized("new_subfolder"), isPresented: $showNewFolderAlert) {
                TextField(localizationManager.localized("folder_name"), text: $newFolderNameText)
                Button(localizationManager.localized("cancel"), role: .cancel) {}
                Button(localizationManager.localized("confirm")) {
                    _ = notebookStore.createFolder(name: newFolderNameText, parentId: newFolderParentId)
                    newFolderNameText = ""
                }
            }
            .alert(localizationManager.localized("rename_folder"), isPresented: Binding(
                get: { folderToRename != nil },
                set: { if !$0 { folderToRename = nil } }
            )) {
                TextField(localizationManager.localized("folder_name"), text: $folderRenameText)
                Button(localizationManager.localized("cancel"), role: .cancel) { folderToRename = nil }
                Button(localizationManager.localized("confirm")) {
                    if let f = folderToRename {
                        notebookStore.renameFolder(id: f.id, newName: folderRenameText)
                    }
                    folderToRename = nil
                }
            }
            .sheet(isPresented: $showMoveNotebookSheet) { erasedView {
                if let id = notebookToMoveId {
                    MoveNotebookSheet(notebookId: id)
                }
            } }
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
            .onAppear {
                // 不限定 macCatalyst：使用者在 Mac 上跑的是 iOS 版（Designed for iPad）
                MacWindowTitle.apply()
                if ProcessInfo.processInfo.environment["KAIRUMO_EXPORT_AUDIT"] != nil {
                    runExportAudit()
                }
                if ProcessInfo.processInfo.environment["KAIRUMO_TYPE_AUDIT"] != nil {
                    let n = _typeName(NotebookEditorView.Body.self, qualified: true).count
                    let h = _typeName(HomeWorkbenchView.Body.self, qualified: true).count
                    let d = _typeName(AppDiagnosticsSheet.Body.self, qualified: true).count
                    print("🔎TYPE editor.body name length = \(n)")
                    print("🔎TYPE home.body   name length = \(h)")
                    print("🔎TYPE diag.body   name length = \(d)")
                }
            }
        }
    }

    // MARK: - 1. 頂部使用者帳號橫幅（響應式自適應寬度）
    /// 型別邊界（見 erasedView 的說明）：避免整棵子樹的型別被編進 body 的名稱。
    private var userAccountBanner: AnyView { AnyView(userAccountBannerContent) }

    private var userAccountBannerContent: some View {
        ViewThatFits(in: .horizontal) {
            // 寬螢幕排版（橫向並排）
            HStack(spacing: 12) {
                userAvatarCircle
                userProfileTexts
                Spacer(minLength: 8)
                switchAccountButton
            }

            // 窄螢幕排版（頭像資訊在上、切換按鈕在下）
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    userAvatarCircle
                    userProfileTexts
                    Spacer(minLength: 4)
                }
                HStack {
                    Spacer()
                    switchAccountButton
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var userAvatarCircle: some View {
        ZStack {
            Circle()
                .fill(Color(hex: accountManager.profile.colorHex) ?? .blue)
                .frame(width: 42, height: 42)
            Text(String(accountManager.profile.displayName.prefix(1)).uppercased())
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }

    private var userProfileTexts: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(accountManager.profile.displayName)
                .font(.headline)
                .foregroundColor(.primary)

            // 這裡以前掛著「線上」徽章與同步狀態，但沒有伺服器也沒有帳號，
            // 那是不成立的狀態。改成說明這個身分的實際用途。
            Text(localizationManager.localized("identity_desc_short"))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    private var switchAccountButton: some View {
        Button {
            showAccountSheet = true
        } label: {
            Text(localizationManager.localized("edit_identity"))
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 2. 頂部搜尋列
    /// 型別邊界（見 erasedView 的說明）：避免整棵子樹的型別被編進 body 的名稱。
    private var searchBarSection: AnyView { AnyView(searchBarSectionContent) }

    private var searchBarSectionContent: some View {
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

    // MARK: - 3. 主要動作按鈕（響應式自適應網格：新增筆記、開始錄音、📦素材圖庫）
    /// 型別邊界（見 erasedView 的說明）：避免整棵子樹的型別被編進 body 的名稱。
    private var primaryActionsSection: AnyView { AnyView(primaryActionsSectionContent) }

    private var primaryActionsSectionContent: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190, maximum: 380), spacing: 12)], spacing: 12) {
            // 真實動作 1：新增筆記（彈出範本選擇器）
            Button {
                newNoteTitle = "\(localizationManager.localized("untitled_note")) \(notebookStore.notebooks.count + 1)"
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
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                }
                .padding(14)
                .foregroundColor(.white)
                .background(LinearGradient(colors: [.accentColor, .accentColor.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .cornerRadius(14)
            }
            .buttonStyle(.plain)

            // 真實動作 2：開始麥克風錄音（彈出即時錄音器）
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
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                }
                .padding(14)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.red.opacity(0.25), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // 真實動作 3：📦 素材圖庫（涵蓋三大主題、機構、3C、零件）
            Button {
                showAssetLibrarySheet = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "shippingbox.fill")
                        .font(.title3)
                        .foregroundColor(.purple)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localizationManager.localized("asset_library"))
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(localizationManager.localized("responsive_asset_desc"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                }
                .padding(14)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.purple.opacity(0.25), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 4. 繼續 Working Section（真實筆記）
    /// 型別邊界（見 erasedView 的說明）：避免整棵子樹的型別被編進 body 的名稱。
    private var continueWorkingSection: AnyView { AnyView(continueWorkingSectionContent) }

    private var continueWorkingSectionContent: some View {
        let visibleList = filteredNotebooks.filter { !hiddenNoteIds.contains($0.id) }
        let displayedList = showAllContinue ? visibleList : Array(visibleList.prefix(5))

        return VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                // 寬螢幕水平並排
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
                            Text(showAllContinue ? localizationManager.localized("collapse") : "\(localizationManager.localized("show_all")) (\(visibleList.count))")
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

                // 窄螢幕垂直分行
                VStack(alignment: .leading, spacing: 6) {
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
                    }

                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showAllContinue.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(showAllContinue ? localizationManager.localized("collapse") : "\(localizationManager.localized("show_all")) (\(visibleList.count))")
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
                }
            }

            if visibleList.isEmpty {
                HStack {
                    Spacer()
                    Text(searchText.isEmpty ? localizationManager.localized("no_notes_hint") : String(format: localizationManager.localized("no_search_results"), searchText))
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
                                                Label(localizationManager.localized("open_editor"), systemImage: "pencil.and.scribble")
                                            }
                                            Button {
                                                withAnimation {
                                                    hiddenNoteIds.insert(note.id)
                                                }
                                            } label: {
                                                Label(localizationManager.localized("hide_item"), systemImage: "eye.slash")
                                            }
                                            Button {
                                                renameText = note.displayTitle()
                                                renamingNotebookId = note.id
                                            } label: {
                                                Label(localizationManager.localized("rename_note"), systemImage: "pencil")
                                            }
                                            Button {
                                                notebookToMoveId = note.id
                                                showMoveNotebookSheet = true
                                            } label: {
                                                Label(localizationManager.localized("move_to_folder"), systemImage: "folder")
                                            }
                                            Button {
                                                notebookStore.duplicateNotebook(id: note.id)
                                            } label: {
                                                Label(localizationManager.localized("duplicate_note"), systemImage: "doc.on.doc")
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

                                    Text(note.displayTitle())
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)

                                    if let snippet = note.displaySnippet() {
                                        Text(snippet)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }

                                    Spacer(minLength: 0)

                                    HStack {
                                        Text("\(note.pageCount) \(localizationManager.localized("pages_count_suffix")) · \(localizationManager.localized(note.template.localizationKey))")
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
    /// 型別邊界（見 erasedView 的說明）：避免整棵子樹的型別被編進 body 的名稱。
    private var recentRecordingsSection: AnyView { AnyView(recentRecordingsSectionContent) }

    private var recentRecordingsSectionContent: some View {
        let visibleRecordings = notebookStore.recordings.filter { !hiddenRecordingIds.contains($0.id) }
        let displayedRecordings = showAllRecordings ? visibleRecordings : Array(visibleRecordings.prefix(4))

        return VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                // 寬螢幕水平並排
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
                            Text(showAllRecordings ? localizationManager.localized("collapse") : "\(localizationManager.localized("show_all")) (\(visibleRecordings.count))")
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
                            Text(localizationManager.localized("open_record_folder"))
                        }
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .help(localizationManager.localized("open_record_folder"))
                }

                // 窄螢幕分行並排
                VStack(alignment: .leading, spacing: 6) {
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
                    }

                    HStack(spacing: 8) {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showAllRecordings.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(showAllRecordings ? localizationManager.localized("collapse") : "\(localizationManager.localized("show_all")) (\(visibleRecordings.count))")
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
                                Text(localizationManager.localized("folders"))
                            }
                            .font(.caption)
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if visibleRecordings.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "mic.slash")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text(localizationManager.localized("no_recordings_hint"))
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
                                    Label(localizationManager.localized("show_in_folder"), systemImage: "folder")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    notebookStore.deleteRecording(id: rec.id)
                                } label: {
                                    Label(localizationManager.localized("delete_recording"), systemImage: "trash")
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
    /// 型別邊界（見 erasedView 的說明）：避免整棵子樹的型別被編進 body 的名稱。
    private var allNotebooksSection: AnyView { AnyView(allNotebooksSectionContent) }

    private var allNotebooksSectionContent: some View {
        let baseList = filteredNotebooks.filter { !hiddenNoteIds.contains($0.id) }
        let visibleList: [NotebookDocument] = {
            if let fId = selectedFolderId {
                return baseList.filter { $0.folderId == fId }
            } else {
                return baseList
            }
        }()

        return VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                // 寬螢幕排版
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
                    allNotebooksSortMenu
                }

                // 窄螢幕排版
                VStack(alignment: .leading, spacing: 6) {
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
                    }

                    HStack {
                        Spacer()
                        allNotebooksSortMenu
                    }
                }
            }

            // 📁 資料夾分類導覽列（顯示最上層資料夾名稱與子資料夾）
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "tray.2.fill")
                        .foregroundColor(.accentColor)
                        .font(.subheadline)
                    Text(notebookStore.displayRootFolderName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Button {
                        rootFolderRenameText = notebookStore.displayRootFolderName
                        showRenameRootFolderAlert = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(localizationManager.localized("edit_root_folder"))

                    Spacer()

                    Button {
                        newFolderParentId = nil
                        newFolderNameText = ""
                        showNewFolderAlert = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.plus")
                            Text(localizationManager.localized("new_subfolder"))
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

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // 全部檔案
                        Button {
                            selectedFolderId = nil
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.grid.2x2")
                                Text(localizationManager.localized("all_folders"))
                            }
                            .font(.caption)
                            .fontWeight(selectedFolderId == nil ? .bold : .regular)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(selectedFolderId == nil ? Color.accentColor : Color(uiColor: .tertiarySystemGroupedBackground))
                            .foregroundColor(selectedFolderId == nil ? .white : .primary)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        // 各資料夾
                        ForEach(notebookStore.folders) { folder in
                            let isSel = (selectedFolderId == folder.id)
                            let count = notebookStore.notebooks(in: folder.id).count
                            Menu {
                                Button {
                                    newFolderParentId = folder.id
                                    newFolderNameText = ""
                                    showNewFolderAlert = true
                                } label: {
                                    Label(localizationManager.localized("new_subfolder"), systemImage: "folder.badge.plus")
                                }
                                Button {
                                    folderToRename = folder
                                    folderRenameText = folder.name
                                } label: {
                                    Label(localizationManager.localized("rename_folder"), systemImage: "pencil")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    notebookStore.deleteFolder(id: folder.id)
                                    if selectedFolderId == folder.id {
                                        selectedFolderId = nil
                                    }
                                } label: {
                                    Label(localizationManager.localized("delete_folder"), systemImage: "trash")
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: folder.parentId == nil ? "folder.fill" : "folder.badge.gearshape")
                                    Text("\(folder.name) (\(count))")
                                }
                                .font(.caption)
                                .fontWeight(isSel ? .bold : .regular)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(isSel ? Color.accentColor : Color(uiColor: .tertiarySystemGroupedBackground))
                                .foregroundColor(isSel ? .white : .primary)
                                .cornerRadius(8)
                            } primaryAction: {
                                selectedFolderId = folder.id
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(10)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)

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
                                    Text(note.displayTitle())
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
                                        Label(localizationManager.localized("open_editor"), systemImage: "pencil.and.scribble")
                                    }
                                    Button {
                                        withAnimation {
                                            hiddenNoteIds.insert(note.id)
                                        }
                                    } label: {
                                        Label(localizationManager.localized("hide_item"), systemImage: "eye.slash")
                                    }
                                    Button {
                                        renameText = note.displayTitle()
                                        renamingNotebookId = note.id
                                    } label: {
                                        Label(localizationManager.localized("rename_note"), systemImage: "pencil")
                                    }
                                    Button {
                                        notebookToMoveId = note.id
                                        showMoveNotebookSheet = true
                                    } label: {
                                        Label(localizationManager.localized("move_to_folder"), systemImage: "folder")
                                    }
                                    Button {
                                        notebookStore.duplicateNotebook(id: note.id)
                                    } label: {
                                        Label(localizationManager.localized("duplicate_note"), systemImage: "doc.on.doc")
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

                            Text(note.displayTitle())
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            HStack {
                                Text("\(note.pageCount) \(localizationManager.localized("pages_count_suffix"))")
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

    /// 型別邊界（見 erasedView 的說明）：避免整棵子樹的型別被編進 body 的名稱。
    private var allNotebooksSortMenu: AnyView { AnyView(allNotebooksSortMenuContent) }

    private var allNotebooksSortMenuContent: some View {
        Menu {
            ForEach(SortOption.allCases) { opt in
                Button {
                    selectedSortOption = opt
                } label: {
                    HStack {
                        Text(opt.localizedTitle(using: localizationManager))
                        if selectedSortOption == opt {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedSortOption.localizedTitle(using: localizationManager))
                    .font(.caption)
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(8)
        }
    }

    // MARK: - 7. 底部工作台品牌與版本號
    /// 型別邊界（見 erasedView 的說明）：避免整棵子樹的型別被編進 body 的名稱。
    /// 匯出內容稽核（只在 KAIRUMO_EXPORT_AUDIT=1 時執行）。
    ///
    /// 造一份帶手繪筆劃、文字方塊與討論圖釘的頁面，走**匯出用的整頁算繪路徑**
    /// 輸出 PNG 到 Documents，用來確認匯出不是空白 —— 這是唯一能在模擬器上
    /// 客觀檢查匯出內容的方法。
    private func runExportAudit() {
        let width: CGFloat = 1200
        var doc = notebookStore.createNotebook(title: "Export Audit", template: .blank)
        doc.textAttachments = [
            NoteTextAttachment(
                pageIndex: 0,
                text: "匯出稽核用文字方塊 / Export audit text box",
                fontSize: 28,
                backgroundColorHex: "#FFF9C4",
                hasBorder: true,
                borderColorHex: "#FF3B30",
                borderWidth: 3,
                x: 120, y: 700, width: 620, height: 160
            )
        ]
        doc.commentPins = [
            NoteCommentPin(pageIndex: 0, x: 900, y: 500, authorId: "audit", authorName: "Audit", authorColor: "#34C759", messages: [])
        ]
        notebookStore.updateNotebook(doc)

        // 一條橫跨頁面的筆劃：位置刻意放在舊版 612x792 取圖框「之外」
        var points: [PKStrokePoint] = []
        for i in 0...60 {
            let t = CGFloat(i) / 60
            let p = CGPoint(x: 100 + t * (width - 200), y: 1000 + sin(t * 6) * 180)
            points.append(PKStrokePoint(location: p, timeOffset: TimeInterval(i) * 0.01,
                                        size: CGSize(width: 8, height: 8), opacity: 1, force: 1, azimuth: 0, altitude: 0))
        }
        let stroke = PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()))
        let drawing = PKDrawing(strokes: [stroke])
        notebookStore.saveDrawing(notebookId: doc.id, pageIndex: 0, drawing: drawing)

        let image = PageThumbnailRenderer.renderFullPage(
            notebook: doc, pageIndex: 0, drawing: drawing, store: notebookStore,
            canvasWidth: width, scale: 1.0
        )
        if let data = image.pngData() {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("export_audit.png")
            try? data.write(to: url)
            print("🔎EXPORT audit written: \(url.path) size=\(image.size)")
        }
        notebookStore.deleteNotebook(id: doc.id)
    }

    /// 說明文件入口：操作手冊與隱私權政策（離線可讀，隨 App 打包）
    private var documentsSection: AnyView { AnyView(documentsSectionContent) }

    private var documentsSectionContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizationManager.localized("help_and_legal"))
                .font(.headline)
                .fontWeight(.bold)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    documentCard(.manual)
                    documentCard(.privacy)
                }
                VStack(spacing: 12) {
                    documentCard(.manual)
                    documentCard(.privacy)
                }
            }
        }
        .padding(.top, 6)
    }

    private func documentCard(_ doc: BundledDocument) -> some View {
        Button {
            viewingDocument = doc
        } label: {
            HStack(spacing: 12) {
                Image(systemName: doc == .manual ? "book.pages.fill" : "lock.shield.fill")
                    .font(.title3)
                    .foregroundColor(doc == .manual ? .accentColor : .green)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(localizationManager.localized(doc.titleKey))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(localizationManager.localized(doc == .manual ? "user_manual_desc" : "privacy_policy_desc"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var footerVersionSection: AnyView { AnyView(footerVersionSectionContent) }

    private var footerVersionSectionContent: some View {
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
                        Text("\(localizationManager.localized("version_number")): \(appVersionString)")
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

            Text(localizationManager.localized("app_slogan"))
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(.top, 16)
        .padding(.bottom, 24)
    }

    // MARK: - 新增筆記彈窗
    /// 型別邊界（見 erasedView 的說明）：避免整棵子樹的型別被編進 body 的名稱。
    private var newNotebookModal: AnyView { AnyView(newNotebookModalContent) }

    private var newNotebookModalContent: some View {
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
    @ObservedObject var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var recordingTitle: String = ""
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
                    Text(localizationManager.localized("recording_title"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField(localizationManager.localized("enter_recording_title"), text: $recordingTitle)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal, 32)

                // 🌟 筆記附加對齊選項（解決使用者疑問：錄音如何被利用、是否即時出現在筆記中）
                VStack(alignment: .leading, spacing: 6) {
                    Text(localizationManager.localized("attach_to_note"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker(localizationManager.localized("attach_picker_label"), selection: $targetNotebookId) {
                        Text(localizationManager.localized("standalone_recording")).tag(nil as String?)
                        ForEach(notebookStore.notebooks) { nb in
                            Text(nb.displayTitle()).tag(nb.id as String?)
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
                            Text(localizationManager.localized("stop_and_save_record"))
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
                            Text(localizationManager.localized("quick_record_title"))
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
            .navigationTitle(localizationManager.localized("quick_record"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("close")) {
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
                    .help(localizationManager.localized("open_record_folder"))
                }
            }
            .onAppear {
                if recordingTitle.isEmpty {
                    recordingTitle = "\(localizationManager.localized("quick_record_title")) \(Date().formatted(date: .numeric, time: .shortened))"
                }
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
    @ObservedObject var localizationManager = LocalizationManager.shared
    @ObservedObject private var store = NotebookStore.shared
    @Environment(\.dismiss) private var dismiss

    /// 遷移是明確的動作，不在啟動時自動跑 —— 所以要有一個按鈕，
    /// 而且結果要看得到，包含失敗的那幾本是為什麼失敗。
    @State private var isMigrating = false
    @State private var migrationReport: NotebookMigration.Report?
    @State private var rollbackMessage: String?

    /// 雲端同步（決策 D3 選項 A）。
    @State private var showFolderPicker = false
    @State private var syncMessage: String?

    public var body: some View {
        NavigationStack {
            List {
                Section(localizationManager.localized("app_version_info")) {
                    HStack {
                        Text(localizationManager.localized("version_number"))
                        Spacer()
                        Text(versionString)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text(localizationManager.localized("core_engine"))
                        Spacer()
                        Text(versionString)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text(localizationManager.localized("platform_desc"))
                        Spacer()
                        Text(platformDesc)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text(localizationManager.localized("arch_mode"))
                        Spacer()
                        Text("Mac Catalyst / iOS Universal")
                            .foregroundColor(.secondary)
                    }
                }

                migrationSection
                cloudSyncSection

                Section(localizationManager.localized("about_app")) {
                    HStack {
                        Text("License")
                        Spacer()
                        Text("Apache-2.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Stack")
                        Spacer()
                        Text("Rust Core + UniFFI + PencilKit/Metal/SwiftUI")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(localizationManager.localized("about_app"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized("close")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

extension AppDiagnosticsSheet {

    /// 雲端同步 —— 使用者自己的雲端硬碟（決策 D3 選項 A）。
    ///
    /// 沒有帳號、沒有我們的伺服器。同步由 iCloud Drive / Google Drive / Dropbox
    /// 負責，我們只是把 `.padnote` 套件放進使用者挑的資料夾。
    @ViewBuilder
    var cloudSyncSection: some View {
        Section(localizationManager.localized("sync_section")) {
            HStack {
                Text(localizationManager.localized("migration_status"))
                Spacer()
                Text(CloudSyncFolder.resolveFolder()?.lastPathComponent
                     ?? localizationManager.localized("sync_not_configured"))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            if let syncMessage {
                Text(syncMessage)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Button(localizationManager.localized("sync_choose_folder")) {
                showFolderPicker = true
            }

            if CloudSyncFolder.resolveFolder() != nil {
                Button(localizationManager.localized("sync_now")) { runSync() }
            }

            Text(localizationManager.localized("sync_explainer"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                // 使用者選的資料夾在 App 沙箱之外，必須先取得存取權才能存書籤。
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                do {
                    try CloudSyncFolder.setFolder(url)
                    runSync()
                } catch {
                    syncMessage = error.localizedDescription
                }
            case .failure(let error):
                syncMessage = error.localizedDescription
            }
        }
    }

    private func runSync() {
        guard let folder = CloudSyncFolder.resolveFolder() else { return }
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }

        let packages = (try? FileManager.default.contentsOfDirectory(
            at: store.corePackagesDirectory,
            includingPropertiesForKeys: nil
        ))?.filter { $0.pathExtension == "padnote" } ?? []

        var uploaded = 0, downloaded = 0
        var attention: [String] = []
        for package in packages {
            let result = CloudSyncFolder.sync(localPackage: package, into: folder)
            uploaded += result.uploaded.count
            downloaded += result.downloaded.count
            attention.append(contentsOf: result.needsAttention)
        }

        if let first = attention.first {
            syncMessage = localizationManager.localized("sync_needs_attention")
                .replacingFirst("%@", with: first)
        } else if uploaded == 0 && downloaded == 0 {
            syncMessage = localizationManager.localized("sync_up_to_date")
        } else {
            syncMessage = localizationManager.localized("sync_result")
                .replacingFirst("%1@", with: "\(uploaded)")
                .replacingFirst("%2@", with: "\(downloaded)")
        }
    }

    /// 跨平台格式轉換。
    ///
    /// 放在診斷頁而不是主畫面：這是進階動作，不該是使用者第一天就會按到的東西。
    @ViewBuilder
    var migrationSection: some View {
        Section(localizationManager.localized("migration_section")) {
            HStack {
                Text(localizationManager.localized("migration_status"))
                Spacer()
                Text(migrationStatusText)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("migration.status")
            }

            if let report = migrationReport {
                HStack {
                    Text(localizationManager.localized("migration_result_summary")
                        .replacingFirst("%@", with: "\(report.migratedCount)")
                        .replacingFirst("%@", with: "\(report.skippedCount)")
                        .replacingFirst("%@", with: "\(report.failedCount)"))
                        .font(.footnote)
                        .foregroundColor(report.allSucceeded ? .secondary : .red)
                    Spacer()
                }

                // 失敗的那幾本要講清楚是為什麼，不能只給一個數字。
                ForEach(failedEntries(in: report), id: \.0) { entry in
                    Text("\(notebookTitle(for: entry.0))：\(entry.1)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            if let message = rollbackMessage {
                Text(message).font(.footnote).foregroundColor(.secondary)
            }

            Button {
                runMigration()
            } label: {
                HStack {
                    if isMigrating { ProgressView().padding(.trailing, 6) }
                    Text(localizationManager.localized(
                        isMigrating ? "migration_running" : "migration_run"))
                }
            }
            .disabled(isMigrating)
            .accessibilityIdentifier("migration.run")

            if let backup = migrationReport?.backupPath {
                Button(role: .destructive) {
                    rollback(to: backup)
                } label: {
                    Text(localizationManager.localized("migration_rollback"))
                }
                .disabled(isMigrating)
            }

            Text(localizationManager.localized("migration_explainer"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var migrationStatusText: String {
        let count = store.coreMigrationState.entries.count
        guard count > 0 else { return localizationManager.localized("migration_never_run") }
        return localizationManager.localized("migration_converted_count")
            .replacingFirst("%@", with: "\(count)")
    }

    private func failedEntries(in report: NotebookMigration.Report) -> [(String, String)] {
        report.outcomes.compactMap { id, outcome in
            if case .failed(let reason) = outcome { return (id, reason) }
            return nil
        }
        .sorted { $0.0 < $1.0 }
    }

    private func notebookTitle(for id: String) -> String {
        store.notebooks.first(where: { $0.id == id })?.displayTitle(localizationManager) ?? id
    }

    private func runMigration() {
        isMigrating = true
        rollbackMessage = nil
        // 先讓「轉換中…」畫出來再開始做事，否則使用者按下去只會看到畫面卡住。
        Task { @MainActor in
            await Task.yield()
            migrationReport = store.migrateToCoreFormat()
            isMigrating = false
        }
    }

    private func rollback(to backup: URL) {
        do {
            try store.rollbackCoreMigration(from: backup)
            migrationReport = nil
            rollbackMessage = localizationManager.localized("migration_rollback_done")
        } catch {
            rollbackMessage = error.localizedDescription
        }
    }
}

private extension String {
    /// 只換掉第一個佔位符。
    ///
    /// 這些訊息有多個 `%@`，要逐一填不同的值；`replacingOccurrences` 會一次
    /// 全換成同一個數字，看起來像「成功 3、略過 3、失敗 3」。
    func replacingFirst(_ target: String, with replacement: String) -> String {
        guard let range = self.range(of: target) else { return self }
        return self.replacingCharacters(in: range, with: replacement)
    }
}

#Preview {
    HomeWorkbenchView()
}


/// 編輯器的宿主視圖。
///
/// 為什麼需要它：`fullScreenCover` 原本直接把 `$store.notebooks[index]` 傳進
/// 編輯器，而 index 是呈現當下算好的。編輯器裡的「切換到另一則筆記」
/// 只能靠寫入那個 Binding —— 那等於覆蓋掉目前這一格。
/// 由宿主持有「現在是哪一則」的 id，每次重算索引，切換就只是換 id，
/// 不會動到任何一則筆記的內容，也不必關掉再重開浮層。
struct NotebookEditorHost: View {
    @ObservedObject var store: NotebookStore
    @State private var currentNotebookId: String

    init(store: NotebookStore, initialNotebookId: String) {
        self.store = store
        self._currentNotebookId = State(initialValue: initialNotebookId)
    }

    var body: some View {
        if let current = store.notebooks.first(where: { $0.id == currentNotebookId }) {
            NotebookEditorView(
                notebook: binding(fallback: current),
                onRequestSwitch: { target in
                    currentNotebookId = target.id
                }
            )
        }
    }

    /// 以 id 在**存取當下**查索引的綁定。
    ///
    /// 先前是 `$store.notebooks[index]`，index 在 body 求值時就算好。
    /// 只要陣列在那之後縮短（刪除筆記、載入時去重、任何重排），
    /// 之後每一次寫入都是越界存取 —— 而編輯器裡幾乎所有操作都會寫入它，
    /// 症狀就是「一碰筆記就閃退」。改成寫入時才查 id，索引不可能過期；
    /// 找不到就安靜略過，而不是讓 App 當掉。
    private func binding(fallback: NotebookDocument) -> Binding<NotebookDocument> {
        Binding(
            get: { store.notebooks.first(where: { $0.id == currentNotebookId }) ?? fallback },
            set: { updated in
                guard let idx = store.notebooks.firstIndex(where: { $0.id == currentNotebookId }) else { return }
                store.notebooks[idx] = updated
            }
        )
    }
}
