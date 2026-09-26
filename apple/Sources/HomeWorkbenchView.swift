//
//  HomeWorkbenchView.swift
//  Kairumo
//
//  首頁工作台：真實持久化、可操作介面
//  支援動態顯示登入帳號名稱、真實筆記畫布編輯、實體錄音與音訊播放
//  跨平台架構：iOS / iPadOS / macOS (Mac Catalyst)
//

import PencilKit
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
    @ObservedObject private var transcriber = AudioTranscriber.shared
    @ObservedObject private var tailscaleMonitor = TailscaleMonitor.shared

    @State private var searchText: String = ""
    /// 核心索引的搜尋結果（轉錄、PDF、OCR）。見 `NotebookSearchIndex`。
    @ObservedObject private var searchIndex = NotebookSearchIndex.shared
    /// ⌘F 用來把游標送進搜尋框。
    @FocusState private var searchFieldFocused: Bool
    @State private var viewingDocument: BundledDocument? = nil
    /// 正在挑「要插進哪一本筆記」的錄音。
    @State private var insertingRecording: AudioRecordingRecord? = nil
    @State private var shareRecordingURL: URL? = nil
    @Environment(\.openWindow) private var openWindow
    @State private var showInfoSheet: Bool = false
    @State private var showCloudSyncSheet: Bool = false
    @State private var showBackupCreateSheet: Bool = false
    @State private var showNotebookSnapshotSheet: Bool = false
    @State private var showBackupRestoreSheet: Bool = false
    @State private var showFolderSyncSheet: Bool = false
    @State private var showAccountSheet: Bool = false
    @State private var showNewNotebookSheet: Bool = false
    /// 建立**加密**筆記本的流程（H-CRYPTO）。與一般新增分開：
    /// 它有三步而且不能跳（設密碼 → 抄復原碼 → 把復原碼輸回來）。
    @State private var showEncryptedNotebookSheet: Bool = false
    @State private var showQuickRecordSheet: Bool = false
    @State private var showImportPicker: Bool = false
    @State private var selectedSortOption: SortOption = .byDate
    @State private var selectedNotebookForEditing: NotebookDocument? = nil

    // 新增筆記暫存狀態
    @State private var newNoteTitle: String = ""
    @State private var selectedTemplate: NoteTemplate = .blank
    /// 紙張要不要順便鋪一份示範內容。nil = 不套用（預設）。
    @State private var selectedPaperVariant: DocumentTemplateCatalog.Variantkind? = nil
    /// 最近套用過的文件範本 id（最多三個，最近的在前）。
    @State private var recentTemplateIds: [String] = RecentTemplates.load()
    /// 目前選中的紙張主題。
    ///
    /// 型別是**核心的** `FfiPaperTheme`，不是 Apple 自己的 `NoteThemeCategory`：
    /// 主題從四個長到七個，而 `NoteThemeCategory` 另外被素材庫用著（它的分類
    /// 只對得上其中三個）。兩邊共用一個列舉的話，素材庫會憑空多出三個
    /// 篩不到任何東西的分頁。
    /// 新筆記要用哪一組版面配色。**落盤** —— 使用者通常有固定的偏好，
    /// 每建一本都要重挑一次的設定不算設定。
    @AppStorage("kairumo_guide_palette") private var newNotePaletteId: String = "graphite"
    @State private var selectedNewNoteCategory: FfiPaperTheme = .general
    // 文件範本（工作項 S-61）。`nil` 代表只要一張空紙，不鋪任何內容。
    @State private var selectedDocTemplateId: String?
    @State private var selectedDocVariant: DocumentTemplateCatalog.Variantkind = .example
    @State private var expandedDocTheme: String?
    @State private var showAssetLibrarySheet: Bool = false

    // 重新命名彈窗
    @State private var renamingNotebookId: String? = nil
    @State private var renameText: String = ""

    // 各區塊展開 (All) 與個別檔案隱藏/刪除狀態
    @State private var showAllContinue: Bool = false
    @State private var showAllRecordings: Bool = false
    @State private var hiddenNoteIds: Set<String> = []
    @State private var hiddenRecordingIds: Set<String> = []

    /// 資料夾管理與過濾狀態
    /// Google 帳號同步的狀態。首頁要直接看得到「登入了沒」——
    /// 藏在設定頁裡的話，使用者不會知道有這個功能。
    @ObservedObject private var homeGoogleAuth = GoogleAuth.shared
    @ObservedObject private var autoSync = AutoSyncController.shared
    /// 首頁那張卡片自己的同步狀態。
    ///
    /// 原本首頁的卡片只是一個「開啟診斷頁」的入口，登入／同步／登出三顆按鈕
    /// 都在診斷頁裡 —— 而 Android 是**直接在首頁卡片上**。同一個動作，一邊
    /// 一下、一邊三下，這正是對齊計劃 L2 那一層要消掉的差異。
    @State private var homeGoogleMessage: String?
    @State private var homeGoogleSyncing = false
    @State private var homeFolderSyncing = false

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

        public var id: String {
            rawValue
        }

        @MainActor
        public func localizedTitle(using localizationManager: LocalizationManager) -> String {
            switch self {
            case .byDate: return localizationManager.localized("sort_by_date")
            case .byTitle: return localizationManager.localized("sort_by_title")
            case .onlyRecordings: return localizationManager.localized("sort_only_recordings")
            }
        }
    }

    public init() {
        StartupLogger.log("HomeWorkbenchView.init 實例化完成")
    }

    /// 取得核心版本資訊
    public var appVersionString: String {
        #if canImport(PadnoteCore)
            let v = coreVersion()
            if !v.isEmpty {
                return "v\(v)"
            }
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
    /// 這本筆記有沒有命中搜尋字（工作項 S-64）。
    ///
    /// # 原本只搜得到標題與摘要
    ///
    /// 使用者**打在筆記裡的字一個都搜不到**。S-61 加了 39 種文件範本之後
    /// 這件事變得很明顯：整份租賃契約的條文都在筆記裡，搜「押金」卻是零結果。
    ///
    /// 所以把畫布上真正有文字的東西都納進來：文字方塊、表格儲存格、
    /// 形狀標籤。Android 端走的是核心的 bigram 索引（它的筆記本來就是
    /// `.padnote` 套件），Apple 這邊的內容就在記憶體裡的附件上，
    /// 直接比對即可 —— 同樣的使用者可見行為，兩種合適的做法。
    private func matchesSearch(_ doc: NotebookDocument) -> Bool {
        func hit(_ text: String?) -> Bool {
            guard let text, !text.isEmpty else { return false }
            return text.localizedCaseInsensitiveContains(searchText)
        }

        if hit(doc.displayTitle()) || hit(doc.previewSnippet) {
            return true
        }

        // 手寫辨識的結果也要搜得到 —— 不然辨識完了卻找不到，
        // 使用者會以為辨識沒有作用。
        if doc.recognizedText?.values.contains(where: { hit($0) }) == true {
            return true
        }

        // 打字內容。
        if doc.textAttachments?.contains(where: { hit($0.text) }) == true {
            return true
        }

        // 表格。整張表逐格看 —— 使用者記得的往往是某一格裡的字，
        // 而不是標題。
        if doc.tableAttachments?.contains(where: { table in
            table.cells.contains { hit($0) }
        }) == true {
            return true
        }

        // 形狀上的標籤（流程圖的節點名稱）。
        if doc.shapeAttachments?.contains(where: { hit($0.label) }) == true {
            return true
        }

        // 記憶體裡的附件到此為止。**錄音轉錄、PDF 內容與 OCR 文字不在裡面**
        // —— 那三樣要問核心的索引（`NotebookSearchIndex`，與 Android 同一組
        // 規則）。少了這一段，使用者搜「押金」找不到自己掃進來的那份合約。
        return searchIndex.contains(doc.id)
    }

    private var filteredNotebooks: [NotebookDocument] {
        // `visibleNotebooks` 而不是 `notebooks`：另一台裝置刪掉的要跟著消失。
        var list = notebookStore.visibleNotebooks

        if !searchText.isEmpty {
            list = list.filter { matchesSearch($0) }
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
                    VStack(alignment: .leading, spacing: DS.Space.l) {
                        // 畫面標題。**放在內容欄裡，不用導覽列的大標題**
                        // （工作項 S-62）：導覽列的大標題貼著視窗最左邊，
                        // 內容欄卻是置中的，兩者在寬螢幕上會差到 300pt，
                        // 看起來像標題掉在外面。
                        Text(accountManager.profile.displayName)
                            .font(DS.Font.screenTitle)
                            .foregroundStyle(DS.Color.primaryText)
                            .padding(.top, DS.Space.xs)
                            .accessibilityIdentifier("home.title")

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
                        dataAndSyncSection
                        documentsSection

                        footerVersionSection
                    }
                    // 內容置中並限制最大寬度（工作項 S-62）。
                    //
                    // 在此之前這裡是 `.frame(width: proxy.size.width)` —— 內容
                    // 把整個視窗填滿。13 吋 iPad 橫向是 1376pt，一列設定的文字
                    // 因此橫跨 1300pt，眼睛要掃過整個螢幕才讀完一行，而右邊
                    // 大半是空的。那不是用到了空間，是沒有版面。
                    .padding(.horizontal, DS.Content.gutter(for: proxy.size.width))
                    .padding(.vertical, DS.Space.m)
                    .dsContentWidth()
                    .frame(width: proxy.size.width, alignment: .top)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            // 實體鍵盤快捷鍵（見 AppCommands.swift）。
            .onReceive(NotificationCenter.default.publisher(for: AppCommand.newNotebook)) { _ in
                newNoteTitle = "\(localizationManager.localized("untitled_note")) \(notebookStore.notebooks.count + 1)"
                selectedTemplate = .blank
                selectedDocTemplateId = nil
                expandedDocTheme = nil
                showNewNotebookSheet = true
            }
            .onReceive(NotificationCenter.default.publisher(for: AppCommand.focusSearch)) { _ in
                searchFieldFocused = true
            }
            // 標題改由內容欄自己畫（見上面）。導覽列只留一個 inline 標題，
            // 捲動時仍然看得到自己在哪一頁。
            // 標題由內容欄自己畫，導覽列就不要再寫一次 —— 兩個「You」
            // 上下相疊，看起來像畫面出錯。
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            // 導覽列只放**換介面語言**一件事（工作項 S-62、S-74）。
            //
            // 這裡曾經是三個各自為政的控制項（語言膠囊、素材圖庫按鈕、
            // 頭像選單），三種圓角、三種底色、三種字級擠在一起。後來拿掉
            // 素材圖庫，最後連頭像選單也拿掉 —— 它底下四個項目**全部**在
            // 首頁上已經有自己的入口：
            //
            //   身分   → 身分卡片上的「編輯身分」
            //   素材圖庫 → 主要動作卡片
            //   錄音資料夾 → 「最近錄音與轉錄」區塊的按鈕
            //   系統診斷 → 頁尾的版本號，以及「資料與同步」裡的卡片
            //
            // 同一個入口出現兩次不會增加能力，只會讓使用者多一個地方要找。
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showInfoSheet = true
                    } label: {
                        HStack(spacing: DS.Space.xxs) {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.system(size: DS.Icon.small, weight: .medium))
                            Text(localizationManager.localized("diagnostics"))
                                .font(.subheadline)
                        }
                    }
                    .accessibilityLabel(localizationManager.localized("hw_diag_a11y"))
                    .help(localizationManager.localized("hw_diag_a11y"))
                    .accessibilityIdentifier("home.diagnostics_button")
                }

                ToolbarItem(placement: .primaryAction) {
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
                        // 圖示旁一定要有字。地球圖示在這個 App 裡代表過三件事
                        // （語系、連結卡片、線上協同），光看圖示分不出按下去
                        // 會發生什麼 —— 而換介面語言是一個按錯了要摸索回來的動作。
                        // 用 HStack 而不是 `Label` + `.labelStyle(.titleAndIcon)`：
                        // 工具列會自己覆寫 Menu 標籤的 label style，那個修飾子
                        // **編得過但沒有作用** —— 畫出來還是只有圖示（實測過）。
                        HStack(spacing: DS.Space.xxs) {
                            Image(systemName: "globe")
                                .font(.system(size: DS.Icon.small, weight: .medium))
                            Text(localizationManager.localized("language"))
                                .font(.subheadline)
                        }
                    }
                    .accessibilityLabel(localizationManager.localized("select_language"))
                    .help(localizationManager.localized("select_language"))
                    .accessibilityIdentifier("home.language")
                }
            }
            .sheet(isPresented: $showAssetLibrarySheet) { resizableSheet {
                AssetLibraryView()
            } }
            .sheet(isPresented: $showAccountSheet) { resizableSheet {
                AccountProfileSheet()
            } }
            .sheet(item: $viewingDocument) { doc in resizableSheet {
                DocumentViewerSheet(document: doc)
            } }
            .sheet(isPresented: $showInfoSheet) { resizableSheet {
                AppDiagnosticsSheet(versionString: appVersionString, platformDesc: platformArchitectureDescription)
            } }
            .sheet(isPresented: $showCloudSyncSheet) { resizableSheet {
                CloudSyncDetailSheet()
            } }
            .sheet(isPresented: $showBackupCreateSheet) { resizableSheet {
                BackupCreateDetailSheet()
            } }
            .sheet(isPresented: $showNotebookSnapshotSheet) { resizableSheet {
                NotebookSnapshotDetailSheet()
            } }
            .sheet(isPresented: $showBackupRestoreSheet) { resizableSheet {
                BackupRestoreDetailSheet()
            } }
            .sheet(isPresented: $showFolderSyncSheet) { resizableSheet {
                FolderSyncDetailSheet()
            } }
            .sheet(isPresented: $showNewNotebookSheet) { resizableSheet {
                newNotebookModal
            } }
            .sheet(isPresented: $showQuickRecordSheet) { resizableSheet {
                QuickAudioRecorderModal()
            } }
            .sheet(isPresented: $showEncryptedNotebookSheet) { resizableSheet {
                NotebookEncryptionSheet { id, title in
                    // 套件已經由核心建好了（含加密），這裡只補上清單那一筆。
                    var doc = NotebookDocument(
                        id: id,
                        title: title.isEmpty
                            ? localizationManager.localized("new_note") : title,
                        pageCount: 1,
                        template: .blank
                    )
                    doc.isEncrypted = true
                    notebookStore.upsertNotebook(doc)
                    AccountSyncStore.shared.record(
                        id: id, title: doc.title, parentId: nil, isFolder: false
                    )
                }
            } }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.init(filenameExtension: "padnote") ?? .data, .data, .archive],
                allowsMultipleSelection: false
            ) { result in
                guard let urls = try? result.get(), let url = urls.first else { return }
                _ = try? notebookStore.importNotebookArchive(from: url)
            }
            .fullScreenCover(item: $selectedNotebookForEditing) { doc in erasedView {
                NotebookEditorHost(store: notebookStore, initialNotebookId: doc.id)
            } }
            .alert(localizationManager.localized("rename_note"), isPresented: Binding(
                get: { renamingNotebookId != nil },
                set: {
                    if !$0 {
                        renamingNotebookId = nil
                    }
                }
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
                set: {
                    if !$0 {
                        folderToRename = nil
                    }
                }
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
            .sheet(isPresented: $showMoveNotebookSheet) { resizableSheet {
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
                StartupLogger.log("HomeWorkbenchView.onAppear: 首頁畫面載入就緒")
                // 不限定 macCatalyst：使用者在 Mac 上跑的是 iOS 版（Designed for iPad）
                MacWindowTitle.apply()
                autoSync.start(store: notebookStore, deviceId: NotebookMigration.deviceId)
                autoSync.request(.foreground)
            }
        }
    }

    // MARK: - 1. 頂部使用者帳號橫幅（響應式自適應寬度）

    /// 型別邊界（見 erasedView 的說明）：避免整棵子樹的型別被編進 body 的名稱。
    private var userAccountBanner: AnyView {
        // `.accessibilityElement(children: .contain)` 不是可有可無的。
        //
        // `.accessibilityIdentifier` 套在**容器**上會讓那個容器變成單一無障礙
        // 元素，**把子元素整個吞掉** —— 於是 home.identity.edit、
        // home.notebooks.sort 這些子控制項在無障礙樹裡根本不存在。
        //
        // 那不只是測試找不到：**VoiceOver 使用者同樣按不到它們**。
        // `.contain` 讓容器保有自己的識別碼，同時把子元素留在樹上。
        AnyView(
            userAccountBannerContent
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.identity.card")
        )
    }

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
        // 識別碼要在 Button 上，不能在 label 裡的 Text 上 —— SwiftUI 會把
        // Button 的子樹合併成一個無障礙元素，內層的識別碼浮不上來，
        // 於是畫面稽核找不到它（而畫面對照閘門掃原始碼看得到，所以是綠的）。
        .accessibilityIdentifier("home.identity.edit")
    }

    // MARK: - 2. 頂部搜尋列

    /// 型別邊界（見 erasedView 的說明）：避免整棵子樹的型別被編進 body 的名稱。
    private var searchBarSection: AnyView {
        AnyView(searchBarSectionContent)
    }

    private var searchBarSectionContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(localizationManager.localized("search_placeholder"), text: $searchText)
                .textFieldStyle(.plain)
                .focused($searchFieldFocused)
                .accessibilityIdentifier("home.search.field")
                // 記憶體裡的附件是同步比對的；轉錄、PDF 與 OCR 要問核心的
                // 索引，而那要逐本開套件 —— 在計算屬性裡同步做的話，
                // 每打一個字就把整個筆記庫重開一遍。
                .onChange(of: searchText) { value in
                    searchIndex.update(
                        query: value,
                        notebooks: notebookStore.visibleNotebooks,
                        deviceId: NotebookMigration.deviceId
                    )
                }
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
    private var primaryActionsSection: AnyView {
        AnyView(primaryActionsSectionContent)
    }

    private var primaryActionsSectionContent: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 220, maximum: 360), spacing: DS.Space.s)],
            spacing: DS.Space.s
        ) {
            // 一個主要動作、兩個次要動作（工作項 S-62）。
            //
            // 在此之前三張卡片有三種邊框顏色（主色漸層、紅、紫），看起來像
            // 三個同等重要又互相搶眼的按鈕。實際上「新增筆記」才是這個畫面
            // 的主要動作，另外兩個是次要的 —— 版面應該說出這件事。
            //
            // 圖示保留各自的語意色（錄音是紅的），但**邊框一律中性**：
            // 彩色邊框會把整個畫面切成好幾塊互相競爭的色區。
            actionCard(
                icon: "plus.circle.fill",
                title: localizationManager.localized("new_note"),
                identifier: "home.action.new_note",
                subtitle: localizationManager.localized("new_note_desc"),
                tint: nil,
                prominent: true
            ) {
                newNoteTitle = "\(localizationManager.localized("untitled_note")) \(notebookStore.notebooks.count + 1)"
                selectedTemplate = .blank
                selectedDocTemplateId = nil
                expandedDocTheme = nil
                showNewNotebookSheet = true
            }

            actionCard(
                icon: "waveform.badge.mic",
                title: localizationManager.localized("start_recording"),
                identifier: "home.action.record",
                subtitle: localizationManager.localized("start_recording_desc"),
                tint: DS.Color.destructive,
                prominent: false
            ) {
                showQuickRecordSheet = true
            }

            actionCard(
                icon: "shippingbox.fill",
                title: localizationManager.localized("asset_library"),
                identifier: "home.action.assets",
                subtitle: localizationManager.localized("responsive_asset_desc"),
                tint: DS.Color.accent,
                prominent: false
            ) {
                showAssetLibrarySheet = true
            }

            actionCard(
                icon: "square.and.arrow.down.fill",
                title: localizationManager.localized("import_note"),
                identifier: "home.action.import",
                subtitle: localizationManager.localized("import_note_desc"),
                tint: DS.Color.accent,
                prominent: false
            ) {
                showImportPicker = true
            }
        }
    }

    /// 主要動作卡片。三張卡片共用同一個版型，差別只在主要／次要與圖示顏色。
    private func actionCard(
        icon: String,
        title: String,
        // 對照閘門用的識別字（見核心 `ffi_screens`）。有預設值是為了讓
        // 既有呼叫端不必全部改，但首頁這三張一定要給。
        identifier: String = "",
        subtitle: String,
        tint: Color?,
        prominent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Space.s) {
                Image(systemName: icon)
                    .font(.system(size: DS.Icon.large * 0.8, weight: .medium))
                    .foregroundStyle(prominent ? AnyShapeStyle(.white) : AnyShapeStyle(tint ?? DS.Color.accent))
                    .frame(width: DS.Icon.large)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DS.Font.cardTitle)
                        .foregroundStyle(prominent ? AnyShapeStyle(.white) : AnyShapeStyle(DS.Color.primaryText))
                    Text(subtitle)
                        .font(DS.Font.caption)
                        .foregroundStyle(prominent ? AnyShapeStyle(Color.white.opacity(0.85))
                            : AnyShapeStyle(DS.Color.secondaryText))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        // fixedSize 會觸發無上界 sizeThatFits，
                        // 導致 CoreText 在 main thread 載入斷字字典（0x8BADF00D）。
                        // 改用明確高度上限取代。
                        .frame(maxHeight: 32, alignment: .topLeading)
                }
                Spacer(minLength: DS.Space.xxs)
            }
            .padding(DS.Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(prominent ? AnyShapeStyle(DS.Color.accent) : AnyShapeStyle(DS.Color.surface))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .stroke(prominent ? Color.clear : DS.Color.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - 4. 繼續 Working Section（真實筆記）

    /// 型別邊界（見 erasedView 的說明）：避免整棵子樹的型別被編進 body 的名稱。
    private var continueWorkingSection: AnyView {
        AnyView(
            continueWorkingSectionContent
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.continue.list")
        )
    }

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
                                .accessibilityIdentifier("home.continue.show_all")
                            Image(systemName: showAllContinue ? "chevron.up" : "chevron.down")
                        }
                        .dsChip()
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
                                    .accessibilityIdentifier("home.continue.show_all")
                                Image(systemName: showAllContinue ? "chevron.up" : "chevron.down")
                            }
                            .dsChip()
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
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 14) {
                        ForEach(displayedList) { note in
                            ZStack(alignment: .topTrailing) {
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
                                                .truncationMode(.tail)
                                                .environment(\.layoutDirection, .leftToRight)
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
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                // 個別檔案功能選項（隱藏、重新命名、副本、刪除）
                                Menu {
                                    Button {
                                        selectedNotebookForEditing = note
                                    } label: {
                                        Label(localizationManager.localized("open_editor"), systemImage: "pencil.and.scribble")
                                    }
                                    Button {
                                        withAnimation {
                                            _ = hiddenNoteIds.insert(note.id)
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
                                        withAnimation {
                                            notebookStore.deleteNotebook(id: note.id)
                                        }
                                    } label: {
                                        Label(localizationManager.localized("delete_item"), systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.system(size: 15))
                                        .foregroundColor(.secondary)
                                        .padding(10)
                                        .contentShape(Rectangle())
                                }
                            }
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .cornerRadius(14)
                            .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
                            .contextMenu {
                                Button {
                                    selectedNotebookForEditing = note
                                } label: {
                                    Label(localizationManager.localized("open_editor"), systemImage: "pencil.and.scribble")
                                }
                                Button {
                                    withAnimation {
                                        _ = hiddenNoteIds.insert(note.id)
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
                                    withAnimation {
                                        notebookStore.deleteNotebook(id: note.id)
                                    }
                                } label: {
                                    Label(localizationManager.localized("delete_item"), systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - 5. 最近錄音（真實實體播放）

    /// 型別邊界（見 erasedView 的說明）：避免整棵子樹的型別被編進 body 的名稱。
    private var recentRecordingsSection: AnyView {
        AnyView(
            recentRecordingsSectionContent
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.recordings.list")
        )
    }

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
                        .dsChip()
                    }
                    .buttonStyle(.plain)
                    // 識別碼在 Button 上，不在裡面的 Text 上（S-263）。
                    .accessibilityIdentifier("home.recordings.show_all")

                    Button {
                        #if targetEnvironment(macCatalyst) || os(macOS)
                        audioManager.openRecordingsFolderInFinder()
                        #else
                        shareRecordingURL = audioManager.recordingsDirectory
                        #endif
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                            Text(localizationManager.localized("open_record_folder"))
                        }
                        .dsChip()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localizationManager.localized("open_record_folder"))
                    .help(localizationManager.localized("open_record_folder"))
                    // 識別碼在 Button 上，不在 label 裡的 Text 上（見
                    // switchAccountButton 的說明）。
                    .accessibilityIdentifier("home.recordings.open_folder")
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
                            .dsChip()
                        }
                        .buttonStyle(.plain)
                        // 識別碼在 Button 上，不在裡面的 Text 上（S-263）。
                        .accessibilityIdentifier("home.recordings.show_all")

                        // 與寬螢幕那一顆是**同一個動作**，所以掛同一個識別碼、
                        // 用同一個語系鍵。
                        //
                        // 原本這一顆兩樣都沒有：`ViewThatFits` 在 iPhone 上
                        // 選的是這個變體，於是識別碼在整個窄螢幕上等於不存在
                        // （畫面稽核找不到它，而 VoiceOver 念到的是「資料夾」，
                        // 不是「開啟錄音資料夾」）。兩個版面變體只接一邊的線，
                        // 是這個專案一再出現的一類 bug。
                        Button {
                            #if targetEnvironment(macCatalyst) || os(macOS)
                            audioManager.openRecordingsFolderInFinder()
                            #else
                            shareRecordingURL = audioManager.recordingsDirectory
                            #endif
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "folder")
                                Text(localizationManager.localized("open_record_folder"))
                            }
                            .dsChip()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(localizationManager.localized("open_record_folder"))
                        .help(localizationManager.localized("open_record_folder"))
                        .accessibilityIdentifier("home.recordings.open_folder")
                    }
                }
            }

            // 🌟 語音轉錄引擎狀態與 Whisper 模型下載橫幅
            whisperModelBanner

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
                        let fileUrl = notebookStore.recordingFileURL(for: rec)
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

                            // 個別檔案功能選項（插入筆記、隱藏、開啟資料夾、刪除）
                            Menu {
                                // 錄音原本只能在首頁播 —— 它進不了任何一頁，
                                // 也就沒辦法擺在它對應的那段筆記旁邊。
                                Button {
                                    insertingRecording = rec
                                } label: {
                                    Label(localizationManager.localized("insert_to_notebook"),
                                          systemImage: "text.badge.plus")
                                }
                                Divider()
                                Button {
                                    withAnimation {
                                        _ = hiddenRecordingIds.insert(rec.id)
                                    }
                                } label: {
                                    Label(localizationManager.localized("hide_item"), systemImage: "eye.slash")
                                }
                                Button {
                                    #if targetEnvironment(macCatalyst) || os(macOS)
                                    audioManager.openRecordingsFolderInFinder()
                                    #else
                                    shareRecordingURL = fileUrl
                                    #endif
                                } label: {
                                    Label(localizationManager.localized("show_in_folder"), systemImage: "folder")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    withAnimation {
                                        notebookStore.deleteRecording(id: rec.id)
                                    }
                                } label: {
                                    Label(localizationManager.localized("delete_recording"), systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                    .padding(8)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .contextMenu {
                            Button {
                                insertingRecording = rec
                            } label: {
                                Label(localizationManager.localized("insert_to_notebook"),
                                      systemImage: "text.badge.plus")
                            }
                            Divider()
                            Button {
                                withAnimation {
                                    _ = hiddenRecordingIds.insert(rec.id)
                                }
                            } label: {
                                Label(localizationManager.localized("hide_item"), systemImage: "eye.slash")
                            }
                            Button {
                                #if targetEnvironment(macCatalyst) || os(macOS)
                                audioManager.openRecordingsFolderInFinder()
                                #else
                                shareRecordingURL = fileUrl
                                #endif
                            } label: {
                                Label(localizationManager.localized("show_in_folder"), systemImage: "folder")
                            }
                            Divider()
                            Button(role: .destructive) {
                                withAnimation {
                                    notebookStore.deleteRecording(id: rec.id)
                                }
                            } label: {
                                Label(localizationManager.localized("delete_recording"), systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $insertingRecording) { rec in
            resizableSheet {
                RecordingToNotebookSheet(recording: rec)
            }
        }
        .sheet(item: Binding(
            get: { shareRecordingURL.map { IdentifiableURL(url: $0) } },
            set: { shareRecordingURL = $0?.url }
        )) { item in
            ShareSheet(items: [item.url])
        }
    }

    private var whisperModelBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: transcriber.isWhisperAvailable ? "waveform.badge.mic" : "arrow.down.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(transcriber.isWhisperAvailable ? .green : .blue)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(transcriber.isWhisperAvailable ? "Whisper 端側神經語音模型已就緒" : "未下載 Whisper 離線語音模型")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Circle()
                        .fill(transcriber.isWhisperAvailable ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                }

                if transcriber.isWhisperAvailable {
                    Text("100% 離線高精準辨識 (574 MB)，支援多國語自動偵測與智慧標點")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if transcriber.isDownloadingModel {
                    HStack(spacing: 8) {
                        ProgressView(value: transcriber.downloadProgress)
                            .progressViewStyle(.linear)
                            .frame(maxWidth: 160)
                        Text(transcriber.downloadStatusText.isEmpty ? "\(Int(transcriber.downloadProgress * 100))%" : transcriber.downloadStatusText)
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                        Button(localizationManager.localized("cancel")) {
                            transcriber.cancelModelDownload()
                        }
                        .font(.caption2)
                        .foregroundColor(.red)
                    }
                } else if let error = transcriber.downloadError {
                    Text("下載中斷：\(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Text("點擊下載離線模型 (574 MB)；未下載時自動降級以系統聽寫轉錄")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if !transcriber.isWhisperAvailable {
                if !transcriber.isDownloadingModel {
                    Button {
                        transcriber.downloadWhisperModel()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle")
                            Text("下載模型")
                        }
                        .font(.footnote)
                        .fontWeight(.medium)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Button {
                    showInfoSheet = true
                } label: {
                    Text("管理")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(transcriber.isWhisperAvailable ? Color.green.opacity(0.06) : Color.blue.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(transcriber.isWhisperAvailable ? Color.green.opacity(0.2) : Color.blue.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - 6. 全部筆記（真實多頁手繪文件）

    /// 型別邊界（見 erasedView 的說明）：避免整棵子樹的型別被編進 body 的名稱。
    private var allNotebooksSection: AnyView {
        AnyView(
            allNotebooksSectionContent
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.notebooks.list")
        )
    }

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
                    .accessibilityLabel(localizationManager.localized("edit_root_folder"))
                    .help(localizationManager.localized("edit_root_folder"))
                    .accessibilityIdentifier("home.notebooks.rename_root")

                    Spacer()

                    Button {
                        newFolderParentId = nil
                        newFolderNameText = ""
                        showNewFolderAlert = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.plus")
                            Text(localizationManager.localized("new_subfolder"))
                                .accessibilityIdentifier("home.notebooks.new_folder")
                        }
                        .dsChip()
                    }
                    .buttonStyle(.plain)
                }

                ScrollView(.horizontal, showsIndicators: true) {
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
                        // 「全部檔案」也是落點：拖到這裡＝移出資料夾（S-88）。
                        // 只有資料夾接受落下的話，拖得進去、拖不出來 ——
                        // 編輯器側欄踩過同一個坑。
                        .dropDestination(for: String.self) { items, _ in
                            guard let noteId = items.first else { return false }
                            notebookStore.moveNotebook(id: noteId, toFolderId: nil)
                            return true
                        }

                        // 各資料夾
                        // 過濾即可，**不要改成 `subfolders(of: nil)`** ——
                        // 這份側邊清單是攤平的，換成只列最上層會讓子資料夾消失。
                        ForEach(notebookStore.folders.filter { !notebookStore.isHiddenBySync($0.id) }) { folder in
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
                            // 筆記卡片拖到這裡就移進這個資料夾（S-88）。
                            .dropDestination(for: String.self) { items, _ in
                                guard let noteId = items.first else { return false }
                                notebookStore.moveNotebook(id: noteId, toFolderId: folder.id)
                                return true
                            }
                        }
                    }
                }
            }
            .padding(10)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 14)], spacing: 14) {
                ForEach(visibleList) { note in
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .topTrailing) {
                            Button {
                                selectedNotebookForEditing = note
                            } label: {
                                ZStack {
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
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            // 個別功能選項
                            Menu {
                                Button {
                                    selectedNotebookForEditing = note
                                } label: {
                                    Label(localizationManager.localized("open_editor"), systemImage: "pencil.and.scribble")
                                }
                                Button {
                                    withAnimation {
                                        _ = hiddenNoteIds.insert(note.id)
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
                                    withAnimation {
                                        notebookStore.deleteNotebook(id: note.id)
                                    }
                                } label: {
                                    Label(localizationManager.localized("delete_item"), systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary.opacity(0.8))
                                    .padding(8)
                                    .contentShape(Rectangle())
                            }
                        }

                        Button {
                            selectedNotebookForEditing = note
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
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
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
                    .contextMenu {
                        Button {
                            selectedNotebookForEditing = note
                        } label: {
                            Label(localizationManager.localized("open_editor"), systemImage: "pencil.and.scribble")
                        }
                        Button {
                            withAnimation {
                                _ = hiddenNoteIds.insert(note.id)
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
                            withAnimation {
                                notebookStore.deleteNotebook(id: note.id)
                            }
                        } label: {
                            Label(localizationManager.localized("delete_item"), systemImage: "trash")
                        }
                    }
                    // 每一張卡片一個識別碼（S-263）。
                    //
                    // 在此之前只有整份清單有 `home.notebooks.list`，於是測試
                    // 要開一本筆記只能**靠顯示文字**去找
                    // （`app.staticTexts["Welcome to Kairumo"]`），而那讓測試的
                    // 成敗取決於模擬器當下是什麼語言 —— 拍完中文截圖之後整套
                    // 就會全紅，而那跟程式對不對一點關係都沒有。
                    //
                    // 用 id 而不是序號：序號會隨排序與新增而變。
                    .accessibilityIdentifier("home.notebooks.card.\(note.id)")
                    // 拖到上面的資料夾膠囊上就分類完成（S-88）。
                    //
                    // 編輯器的側欄早就能這樣拖，首頁卻不行 —— 而首頁才是
                    // 使用者整理筆記的地方。要整理一本筆記得先打開它，
                    // 那個順序是反的。
                    .draggable(note.id) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.fill")
                            Text(note.displayTitle()).lineLimit(1)
                        }
                        .font(.caption)
                        .padding(8)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }

    /// 型別邊界（見 erasedView 的說明）：避免整棵子樹的型別被編進 body 的名稱。
    private var allNotebooksSortMenu: AnyView {
        AnyView(allNotebooksSortMenuContent)
    }

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
        // 識別碼在 Menu 上，不在包著它的 AnyView 上 —— 型別抹除那一層不是
        // 無障礙元素，識別碼掛在那裡查不到。
        .accessibilityIdentifier("home.notebooks.sort")
    }

    // MARK: - 7. 底部工作台品牌與版本號

    // 型別邊界（見 erasedView 的說明）：避免整棵子樹的型別被編進 body 的名稱。

    /// 資料與同步入口。
    ///
    /// 這三項原本只藏在「系統診斷」裡 —— 使用者回報「一鍵備份的功能在哪裡？」
    /// 「同步的功能在哪裡？」。備份與同步是會在**出事之後**才想起來的功能，
    /// 那時使用者不會去翻診斷頁。放在首頁。
    private var dataAndSyncSection: AnyView {
        AnyView(dataAndSyncSectionContent)
    }

    private var dataAndSyncSectionContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(localizationManager.localized("data_and_sync"))
                    .font(.headline)
                    .fontWeight(.bold)
                // 直接講「不需要帳號」：使用者會找「登入」，找不到會以為功能不存在。
                Text(localizationManager.localized("no_account_needed"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // 「選擇同步資料夾」那張卡（S-263）。
            //
            // 兩件事一起修：Android 首頁一直有這張卡而 Apple 沒有，
            // 而 `FolderSyncDetailSheet` 這整張畫面**早就做好也接在
            // `.sheet` 上了，只是沒有任何地方把 showFolderSyncSheet 設成
            // true** —— 做完卻進不去。
            //
            // 資料夾同步在 Apple 這邊原本只能從「雲端同步」那張卡進去再切
            // 分頁，使用者要先知道它藏在那裡。
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    unifiedSyncCard
                    p2pSyncCard
                    dataCard("icloud.and.arrow.up.fill", "sync_choose_folder",
                             "sync_folder_desc", .teal) { showFolderSyncSheet = true }
                    dataCard("doc.zipper", "backup_snapshot",
                             "backup_snapshot_desc", .purple) { showNotebookSnapshotSheet = true }
                    dataCard("externaldrive.badge.timemachine", "backup_create",
                             "backup_create_desc", .blue) { showBackupCreateSheet = true }
                    dataCard("arrow.counterclockwise.circle.fill", "backup_restore",
                             "backup_restore_desc", .orange) { showBackupRestoreSheet = true }
                }
                VStack(spacing: 12) {
                    unifiedSyncCard
                    p2pSyncCard
                    dataCard("icloud.and.arrow.up.fill", "sync_choose_folder",
                             "sync_folder_desc", .teal) { showFolderSyncSheet = true }
                    dataCard("doc.zipper", "backup_snapshot",
                             "backup_snapshot_desc", .purple) { showNotebookSnapshotSheet = true }
                    dataCard("externaldrive.badge.timemachine", "backup_create",
                             "backup_create_desc", .blue) { showBackupCreateSheet = true }
                    dataCard("arrow.counterclockwise.circle.fill", "backup_restore",
                             "backup_restore_desc", .orange) { showBackupRestoreSheet = true }
                }
            }
        }
        .padding(.top, 6)
    }

    private var p2pSyncCard: some View {
        let tailscale = tailscaleMonitor.status
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "point.3.filled.connected.trianglepath")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.indigo)
                    Text("Tailscale 點對點直連同步")
                        .font(DS.Font.cardTitle)
                        .fontWeight(.semibold)
                }

                Spacer()

                // 連線狀態指示燈
                HStack(spacing: 6) {
                    Circle()
                        .fill(tailscale.isConnected ? Color.green : Color.secondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                    Text(tailscale.isConnected ? (tailscale.ipAddress ?? "已連線") : "未連線")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(tailscale.isConnected ? .green : .secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(tailscale.isConnected ? Color.green.opacity(0.12) : Color.secondary.opacity(0.08))
                .clipShape(Capsule())
            }

            Text("跨裝置直連同步：Padnote 使用 WebRTC 進行跨網際網路的點對點極速同步。為達到最穩定的無伺服器穿透效果，強烈建議在您的裝置上安裝 Tailscale。")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            // 超連結
            Link(destination: URL(string: "https://tailscale.com/download")!) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right.square")
                    Text("前往下載 Tailscale (tailscale.com/download)")
                }
                .font(DS.Font.caption)
                .fontWeight(.medium)
                .foregroundColor(.accentColor)
            }
        }
        .padding(DS.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .stroke(DS.Color.hairline, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.p2p.card")
    }

    // 統一雲端同步卡片。結合 Google Drive 與 iCloud / 本機資料夾同步。

    private var homeGoogleStatusText: String {
        if !homeGoogleAuth.isSignedIn {
            return localizationManager.localized("not_signed_in")
        }
        if homeGoogleSyncing || autoSync.isSyncing {
            return localizationManager.localized("syncing")
        }
        if let msg = homeGoogleMessage ?? (autoSync.lastMessage.isEmpty ? nil : autoSync.lastMessage), msg.contains("失敗") || msg.contains("錯誤") || msg.contains("逾時") {
            return "同步發生錯誤"
        }
        return localizationManager.localized("sync_done")
    }

    private var homeGoogleStatusColor: Color {
        if !homeGoogleAuth.isSignedIn {
            return .secondary
        }
        if homeGoogleSyncing || autoSync.isSyncing {
            return .teal
        }
        if let msg = homeGoogleMessage ?? (autoSync.lastMessage.isEmpty ? nil : autoSync.lastMessage), msg.contains("失敗") || msg.contains("錯誤") || msg.contains("逾時") {
            return .red
        }
        return .green
    }

    private var homeFolderStatusText: String {
        if CloudSyncFolder.resolveFolder() == nil {
            return localizationManager.localized("sync_not_configured")
        }
        if homeFolderSyncing {
            return localizationManager.localized("syncing")
        }
        if let msg = homeGoogleMessage, msg.contains("失敗") || msg.contains("錯誤") {
            return "同步失敗"
        }
        return localizationManager.localized("sync_done")
    }

    private var homeFolderStatusColor: Color {
        if CloudSyncFolder.resolveFolder() == nil {
            return .secondary
        }
        if homeFolderSyncing {
            return .teal
        }
        if let msg = homeGoogleMessage, msg.contains("失敗") || msg.contains("錯誤") {
            return .red
        }
        return .green
    }

    private var unifiedSyncCard: some View {
        ZStack(alignment: .topLeading) {
            // 底層全卡片點擊按鈕：確保點擊卡片任何空白處皆可直接開啟設定 Sheet
            Button {
                showCloudSyncSheet = true
            } label: {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                // 標題行按鈕：整列包含圖示、文字、Spacer 與箭頭皆可點擊
                Button {
                    showCloudSyncSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath.icloud.fill")
                            .foregroundStyle(Color.indigo)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(localizationManager.localized("cloud_sync"))
                                .font(DS.Font.cardTitle)
                                .foregroundStyle(Color.primary)
                            Text(unifiedSyncSubtitle)
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Color.secondaryText)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if homeGoogleAuth.isSignedIn {
                    Text(homeGoogleStatusText)
                        .font(DS.Font.caption)
                        .foregroundStyle(homeGoogleStatusColor)
                } else if CloudSyncFolder.resolveFolder() != nil {
                    Text(homeFolderStatusText)
                        .font(DS.Font.caption)
                        .foregroundStyle(homeFolderStatusColor)
                }

                HStack(spacing: 6) {
                    if homeGoogleAuth.isSignedIn {
                        Button(localizationManager.localized("sync_now")) {
                            Task { await runHomeGoogleSync() }
                        }
                        .disabled(homeGoogleSyncing || autoSync.isSyncing)
                        .accessibilityIdentifier("home.cloud.sync_now")

                        Button(localizationManager.localized("settings")) {
                            showCloudSyncSheet = true
                        }
                        .accessibilityIdentifier("home.cloud.settings")

                        Button(localizationManager.localized("sign_out"), role: .destructive) {
                            Task {
                                await GoogleAuth.shared.signOut()
                                homeGoogleMessage = nil
                            }
                        }
                        .accessibilityIdentifier("home.cloud.signout")
                    } else if CloudSyncFolder.resolveFolder() != nil {
                        Button(localizationManager.localized("sync_now")) {
                            runHomeFolderSync()
                        }
                        .disabled(homeFolderSyncing)
                        .accessibilityIdentifier("home.folder.sync_now")

                        Button(localizationManager.localized("settings")) {
                            showCloudSyncSheet = true
                        }
                        .accessibilityIdentifier("home.cloud.settings")
                    } else {
                        Button(localizationManager.localized("settings")) {
                            showCloudSyncSheet = true
                        }
                        .accessibilityIdentifier("home.cloud.signin")
                    }
                }
                .buttonStyle(.bordered)
                .font(DS.Font.caption)

                // 說明文字亦支援點擊展開設定
                Button {
                    showCloudSyncSheet = true
                } label: {
                    Text(unifiedSyncExplainer)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.secondaryText)
                        .lineLimit(5) // 替換 fixedSize：避免 CoreText 斷字字典 I/O (0x8BADF00D)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DS.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Color.surface)
        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
        .onTapGesture {
            showCloudSyncSheet = true
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .stroke(DS.Color.hairline, lineWidth: 1)
        )
        // 見 userAccountBanner 的說明：識別碼套在容器上會把子元素吞掉，
        // 這張卡裡的 home.cloud.signin / sync_now / sign_out 都會不見。
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.cloud.card")
    }

    private var unifiedSyncSubtitle: String {
        if homeGoogleAuth.isSignedIn {
            return "Google Drive · " + (homeGoogleAuth.accountEmail ?? localizationManager.localized("signed_in"))
        } else if let folder = CloudSyncFolder.resolveFolder() {
            return localizationManager.localized("sync_folder_label") + " · " + folder.lastPathComponent
        } else {
            return localizationManager.localized("sync_not_set_up")
        }
    }

    private var unifiedSyncExplainer: String {
        if homeGoogleAuth.isSignedIn {
            return localizationManager.localized("cloud_sync_explainer")
        } else if CloudSyncFolder.resolveFolder() != nil {
            return localizationManager.localized("sync_explainer_folder")
        } else {
            return localizationManager.localized("sync_explainer_none")
        }
    }

    /// 首頁卡片上的 Google Drive「立即同步」。
    @MainActor
    private func runHomeGoogleSync() async {
        guard !homeGoogleSyncing, !autoSync.isSyncing else { return }
        homeGoogleSyncing = true
        autoSync.setSyncing(true, message: localizationManager.localized("syncing"))
        defer {
            homeGoogleSyncing = false
            autoSync.setSyncing(false)
        }

        homeGoogleMessage = localizationManager.localized("syncing")
        let report: NotebookSyncCoordinator.Report?
        do {
            report = try await withSyncTimeout(seconds: 180) {
                await NotebookSyncCoordinator.runDrive(
                    store: notebookStore, deviceId: NotebookMigration.deviceId
                )
            }
        } catch {
            homeGoogleMessage = "同步逾時，請確認網路連線後重試"
            return
        }
        guard let report else {
            homeGoogleMessage = localizationManager.localized("not_signed_in")
            return
        }
        // 被互斥閘擋下來：別說「已是最新」—— 這一輪根本沒比對過雲端。
        if report.wasSkipped {
            homeGoogleMessage = localizationManager.localized("sync_already_running")
            return
        }
        if report.failures.isEmpty {
            SyncHistory.markGoogleSynced()
        }
        if let failure = report.failures.first {
            homeGoogleMessage = "\(failure.key)：\(failure.value)"
        } else if report.isNoOp {
            homeGoogleMessage = localizationManager.localized("sync_up_to_date")
        } else {
            homeGoogleMessage = localizationManager.localized("sync_result")
                .replacingFirst("%1@", with: "\(report.uploaded)")
                .replacingFirst("%2@", with: "\(report.downloaded)")
        }
    }

    /// 首頁卡片上的資料夾「立即同步」。
    @MainActor
    private func runHomeFolderSync() {
        guard !homeFolderSyncing else { return }
        guard let folder = CloudSyncFolder.resolveFolder() else { return }
        homeFolderSyncing = true

        Task {
            defer { homeFolderSyncing = false }
            homeGoogleMessage = localizationManager.localized("syncing")
            let scoped = folder.startAccessingSecurityScopedResource()
            defer {
                if scoped {
                    folder.stopAccessingSecurityScopedResource()
                }
            }

            let report = await NotebookSyncCoordinator.run(
                store: notebookStore, folder: folder, deviceId: NotebookMigration.deviceId
            )

            if report.failures.isEmpty, report.needsAttention.isEmpty {
                SyncHistory.markFolderSynced()
            }
            if let first = report.needsAttention.first {
                homeGoogleMessage = localizationManager.localized("sync_needs_attention")
                    .replacingFirst("%@", with: first)
            } else if let failure = report.failures.first {
                homeGoogleMessage = "\(failure.key)：\(failure.value)"
            } else if report.isNoOp {
                homeGoogleMessage = localizationManager.localized("sync_up_to_date")
            } else {
                homeGoogleMessage = localizationManager.localized("sync_result")
                    .replacingFirst("%1@", with: "\(report.uploaded)")
                    .replacingFirst("%2@", with: "\(report.downloaded)")
            }
        }
    }

    /// 「資料與同步」那三張卡。識別字由 `titleKey` 推出來
    /// （`backup_create` → `home.data.backup`），對照閘門靠它認人 ——
    /// 手寫一份對照表的話，加第四張卡時一定會忘記加進去。
    private func dataCardIdentifier(_ titleKey: String) -> String {
        switch titleKey {
        case "backup_snapshot": return "home.data.snapshot"
        case "backup_create": return "home.data.backup"
        case "backup_restore": return "home.data.restore"
        case "sync_choose_folder": return "home.data.folder"
        default: return ""
        }
    }

    private func dataCard(
        _ icon: String, _ titleKey: String, _ descKey: String,
        _ tint: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(tint)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(localizationManager.localized(titleKey))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(localizationManager.localized(descKey))
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
        .accessibilityIdentifier(dataCardIdentifier(titleKey))
    }

    /// 說明文件入口：操作手冊與隱私權政策（離線可讀，隨 App 打包）
    private var documentsSection: AnyView {
        AnyView(documentsSectionContent)
    }

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

    /// 說明文件卡片。識別字由文件本身推出來，與 `dataCard` 同一個道理。
    private func documentCardIdentifier(_ doc: BundledDocument) -> String {
        doc == .manual ? "home.docs.manual" : "home.docs.privacy"
    }

    private func documentCard(_ doc: BundledDocument) -> some View {
        Button {
            // Mac 上開成獨立視窗：可以移動、可以調整大小、可以擺在旁邊
            // 一邊看一邊操作。工作表做不到這三件事。
            if DocumentWindow.supportsSeparateWindow {
                openWindow(id: DocumentWindow.id, value: doc.id)
            } else {
                viewingDocument = doc
            }
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
        .accessibilityIdentifier(documentCardIdentifier(doc))
    }

    private var footerVersionSection: AnyView {
        AnyView(footerVersionSectionContent)
    }

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
                            .accessibilityIdentifier("home.version")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
                // 診斷頁原本要先開頭像選單才點得到，選單拿掉之後這裡是
                // 首頁上最穩定的入口，UI 測試改指這一顆。
                .accessibilityIdentifier("home.diagnostics")

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
    private var newNotebookModal: AnyView {
        AnyView(newNotebookModalContent)
    }

    private var newNotebookModalContent: some View {
        NavigationStack {
            Form {
                Section(localizationManager.localized("note_title")) {
                    TextField(localizationManager.localized("note_title"), text: $newNoteTitle)
                        .accessibilityIdentifier("new_notebook.title.field")
                }

                paperSection

                recentTemplatesSection

                documentTemplateSection

                // 加密是**另一條路**，不是這裡的一個開關。
                //
                // 它有三步而且不能跳（設密碼 → 抄復原碼 → 把復原碼輸回來），
                // 塞進這張表單只會讓人以為那是一個可以之後再說的選項 ——
                // 而「之後再說」的使用者就是後來會失去全部筆記的那一個。
                Section {
                    Button {
                        showNewNotebookSheet = false
                        // 等這張 sheet 收完再開下一張，否則兩張會打架。
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showEncryptedNotebookSheet = true
                        }
                    } label: {
                        Label(localizationManager.localized("encrypt_notebook"),
                              systemImage: "lock.fill")
                    }
                    .accessibilityIdentifier("new_notebook.encrypted")
                }
            }
            .navigationTitle(localizationManager.localized("new_notebook"))
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedNewNoteCategory) { newCat in
                if let first = NoteTemplate.allCases.first(where: { $0.ffiTheme == newCat }) {
                    selectedTemplate = first
                }
            }
            .onChange(of: selectedDocTemplateId) { _ in
                applyDocumentTemplatePaper()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) {
                        showNewNotebookSheet = false
                    }
                    .accessibilityIdentifier("new_notebook.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized("confirm")) {
                        let defaultTitle = newNoteTitle.isEmpty ? localizationManager.localized("new_notebook") : newNoteTitle
                        var created = notebookStore.createNotebook(
                            title: defaultTitle, template: selectedTemplate
                        )
                        created.guidePaletteId = newNotePaletteId
                        notebookStore.updateNotebook(created)
                        // 選了文件範本就把內容鋪進去，再存一次。
                        if let id = selectedDocTemplateId,
                           let tmpl = DocumentTemplateCatalog.template(id: id)
                        {
                            DocumentTemplateCatalog.apply(
                                tmpl, kind: selectedDocVariant,
                                language: localizationManager.currentLanguage.catalogKey, to: &created
                            )
                            notebookStore.updateNotebook(created)
                        } else if let variant = selectedPaperVariant,
                                  let paper = DocumentTemplateCatalog.paperTemplate(
                                      paperId: selectedTemplate.paperId
                                  )
                        {
                            // 沒選文件範本，但紙張自己帶了示範內容。
                            DocumentTemplateCatalog.apply(
                                paper, kind: variant,
                                language: localizationManager.currentLanguage.catalogKey, to: &created
                            )
                            notebookStore.updateNotebook(created)
                        }
                        // 記下這一次用了哪個樣板，下次直接從「常用樣板」點。
                        let usedId = selectedDocTemplateId
                            ?? (selectedPaperVariant != nil ? selectedTemplate.paperId : nil)
                        if let usedId {
                            recentTemplateIds = RecentTemplates.record(usedId)
                        }

                        showNewNotebookSheet = false
                        // 立即開啟該筆記畫布進行編輯
                        selectedNotebookForEditing = created
                    }
                    .fontWeight(.bold)
                    .accessibilityIdentifier("new_notebook.confirm")
                }
            }
        }
    }

    // MARK: - 紙張挑選

    /// 選了文件範本，紙張就跟著它走。
    ///
    /// 這兩件事原本各選各的，於是實機上出現過一份公文「簽」鋪在
    /// **行動端線框**紙上 —— 本文底下壓著兩個手機外框。文件範本的 JSON
    /// 本來就帶著它要的 `pageStyle`，兩端卻都只解析、不使用。
    private func applyDocumentTemplatePaper() {
        guard let id = selectedDocTemplateId,
              let tmpl = DocumentTemplateCatalog.template(id: id),
              let paper = NoteTemplate(paperId: docTemplatePaperId(pageStyle: tmpl.pageStyle))
        else { return }
        selectedTemplate = paper
        selectedNewNoteCategory = paper.ffiTheme
    }

    /// 紙張是由文件範本決定的嗎？是的話清單只能看，不能改。
    private var paperIsLockedByDocument: Bool {
        selectedDocTemplateId != nil
    }

    /// 主題分類 + 該主題底下的紙張，**同一個區塊**。
    ///
    /// 這兩件事原本分成兩個 Section，中間還隔著一整棵可展開的文件範本樹。
    /// 於是切換主題時，會變的那份清單在螢幕外 —— 使用者按下去看不到任何
    /// 反應，合理的結論就是「這個東西壞了」。清單就放在切換器正下方。
    ///
    /// 清單本身來自核心 `paperTemplatesForTheme`：Android 端原本連紙張都
    /// 不能選，各寫一份只會讓兩邊繼續分岔。
    /// 主題切換器。
    ///
    /// # 為什麼不是分段控制項
    ///
    /// 主題從四個長到七個。`.segmented` 會把七個中文標籤擠進同一列 ——
    /// 那正是先前回報過的「文字被擠壓、功能鈕被遮掩」。橫向捲動的膠囊列
    /// 放得下任意數量，而且每一個都看得清楚。
    /// 七組主題的膠囊列。
    ///
    /// 原本是橫向捲動的單列。主題有七組，表單寬度只放得下三個半 ——
    /// 第四個被切在邊緣，後面三組完全不在畫面上。使用者回報的是
    /// 「看不到全部」：捲動條在 sheet 邊緣不明顯，一列膠囊看起來就像
    /// 「總共只有這幾組」，而右邊那半個被切掉的膠囊更像是版面壞了。
    ///
    /// 改用換行版面（工具列已經在用的那個 `WrapLayout`）：七組一次全部
    /// 看得到，也不必猜還有沒有別的。膠囊本身高度固定，換成兩三列
    /// 只多幾十點，換不到需要捲動的程度。
    private var themeChips: some View {
        WrapLayout(spacing: 8, lineSpacing: 8) {
            ForEach(Array(paperThemes().enumerated()), id: \.offset) { _, theme in
                themeChip(theme)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .disabled(paperIsLockedByDocument)
        .accessibilityIdentifier("new_notebook.paper.themes")
    }

    private func themeChip(_ theme: FfiPaperTheme) -> some View {
        let isActive = (selectedNewNoteCategory == theme)
        let icons = paperThemeIcons(theme: theme)
        return Button {
            selectedNewNoteCategory = theme
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icons.first ?? "doc.text")
                    .font(.system(size: 12, weight: .semibold))
                Text(localizationManager.localized(paperThemeKey(theme: theme)))
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundColor(isActive ? .white : .accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(isActive ? Color.accentColor : Color.accentColor.opacity(0.12))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var paperSection: some View {
        Section {
            themeChips

            ForEach(paperTemplatesForTheme(theme: selectedNewNoteCategory), id: \.id) { paper in
                paperRow(paper)
                    .accessibilityIdentifier("new_notebook.paper.list")
            }

            paperContentPicker

            paletteRow
        } header: {
            Text(localizationManager.localized("select_template"))
        } footer: {
            if paperIsLockedByDocument {
                Text(localizationManager.localized("paper_locked_by_doc"))
            }
        }
    }

    /// 這張紙要不要帶一份示範內容。
    ///
    /// # 為什麼紙張也需要內容
    ///
    /// 紙張本來只有底紋 —— 選了「行動端線框」拿到的是兩個空的手機外框，
    /// 使用者要自己想那兩個框該放什麼。十三種紙裡有一半都有這個問題
    /// （黃金比例、情緒板、工程藍圖、三視圖、使用者旅程…）：
    /// **會用的人不需要它，不會用的人看不懂它。**
    ///
    /// 所以每一種紙各配一份「實務範例」（照著改就能用的真實內容）與一份
    /// 「空白大綱」（只留標題與欄位）。預設**不套用** —— 最常用的動作
    /// 仍然是「給我一張空白紙」，那件事不該因此多按一下。
    @ViewBuilder
    private var paperContentPicker: some View {
        if !paperIsLockedByDocument,
           DocumentTemplateCatalog.paperTemplate(paperId: selectedTemplate.paperId) != nil
        {
            Picker(
                localizationManager.localized("paper_content"),
                selection: $selectedPaperVariant
            ) {
                Text(localizationManager.localized("paper_content_none"))
                    .tag(nil as DocumentTemplateCatalog.Variantkind?)
                ForEach(DocumentTemplateCatalog.Variantkind.allCases) { kind in
                    Text(localizationManager.localized(kind.localizationKey))
                        .tag(kind as DocumentTemplateCatalog.Variantkind?)
                }
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 2)
        }
    }

    /// 版面配色。
    ///
    /// 直接畫出顏色本身，名字寫在下面 —— 使用者要挑的是顏色，不是「靛藍」
    /// 這兩個字。整本一個調子，不是逐頁。
    private var paletteRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localizationManager.localized("guide_palette"))
                .font(.caption)
                .foregroundColor(.secondary)
                .accessibilityIdentifier("new_notebook.palette")
            HStack(spacing: 10) {
                ForEach(guidePalettes(), id: \.id) { palette in
                    let isActive = (newNotePaletteId == palette.id)
                    Button {
                        newNotePaletteId = palette.id
                    } label: {
                        VStack(spacing: 3) {
                            Circle()
                                .fill(Color(uiColor: UIColor(hexString: palette.accentHex) ?? .systemIndigo))
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle().stroke(Color.accentColor, lineWidth: isActive ? 2.5 : 0)
                                        .padding(-3)
                                )
                            Text(localizationManager.localized(palette.nameKey))
                                .font(.system(size: 9))
                                .foregroundColor(isActive ? .accentColor : .secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func paperRow(_ paper: FfiPaperTemplate) -> some View {
        let isSelected = selectedTemplate.paperId == paper.id
        return HStack(spacing: 12) {
            Image(systemName: paper.iconApple)
                .font(.title3)
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(localizationManager.localized(paper.titleKey))
                    .font(.headline)
                Text(localizationManager.localized(paper.descKey))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .opacity(paperIsLockedByDocument && !isSelected ? 0.4 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !paperIsLockedByDocument, let match = NoteTemplate(paperId: paper.id) else { return }
            selectedTemplate = match
        }
    }

    // MARK: - 常用樣板

    /// 最近套用過的三個樣板，一按就套用。
    ///
    /// # 為什麼需要它
    ///
    /// 39 種文件範本收在一棵三層的樹裡。實際上使用者絕大多數時候要的是
    /// 「再來一份跟上次一樣的」—— 而那件事現在要展開主題、展開分類、
    /// 再從清單裡認出那一個。清單本身沒有問題，問題是最常用的路徑最長。
    ///
    /// 沒用過任何樣板時整個區塊不出現：一張寫著「還沒有」的卡片只是佔位置。
    @ViewBuilder
    private var recentTemplatesSection: some View {
        let recents = recentTemplateIds.compactMap { id -> DocumentTemplateCatalog.Template? in
            DocumentTemplateCatalog.template(id: id)
                ?? DocumentTemplateCatalog.paperTemplate(paperId: id)
        }
        if !recents.isEmpty {
            Section(localizationManager.localized("recent_templates")) {
                ForEach(recents) { tmpl in
                    Button {
                        applyRecentTemplate(tmpl)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.accentColor)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(catalogText(tmpl.name))
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text(catalogText(tmpl.description))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if selectedDocTemplateId == tmpl.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// 點了常用樣板。
    ///
    /// 紙張樣板與文件範本走的是兩條不同的套用路徑，所以要分辨它是哪一種 ——
    /// 用文件範本的路徑去套紙張樣板的話，紙張那一欄會被鎖住而使用者改不動。
    private func applyRecentTemplate(_ tmpl: DocumentTemplateCatalog.Template) {
        if DocumentTemplateCatalog.paperTemplate(paperId: tmpl.id) != nil,
           let paper = NoteTemplate(paperId: tmpl.id)
        {
            selectedDocTemplateId = nil
            selectedTemplate = paper
            selectedNewNoteCategory = paper.ffiTheme
            selectedPaperVariant = .example
        } else {
            selectedDocTemplateId = tmpl.id
            applyDocumentTemplatePaper()
        }
    }

    // MARK: - 文件範本挑選（工作項 S-61）

    /// 主題 → 分類 → 範本，三層收合。
    ///
    /// **預設整個收起來。** 39 種範本全部攤開的話，原本兩行就選得完的
    /// 「新增一張空白紙」會被埋在幾十列底下 —— 最常用的動作不該變最難的。
    private var documentTemplateSection: some View {
        Section {
            HStack {
                Image(systemName: "doc.badge.plus")
                    .foregroundColor(selectedDocTemplateId == nil ? .secondary : .accentColor)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(localizationManager.localized("doc_template"))
                        .font(.headline)
                        .accessibilityIdentifier("new_notebook.document.current")
                    Text(selectedDocTemplateName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if selectedDocTemplateId != nil {
                    Button(localizationManager.localized("doc_template_clear")) {
                        selectedDocTemplateId = nil
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
            }

            if selectedDocTemplateId != nil {
                Picker("", selection: $selectedDocVariant) {
                    ForEach(DocumentTemplateCatalog.Variantkind.allCases) { kind in
                        Text(localizationManager.localized(kind.localizationKey)).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
            }

            ForEach(DocumentTemplateCatalog.documentThemes) { theme in
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedDocTheme == theme.id },
                        set: { expandedDocTheme = $0 ? theme.id : nil }
                    )
                ) {
                    ForEach(theme.categories) { category in
                        Text(catalogText(category.name))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        ForEach(category.templates) { tmpl in
                            documentTemplateRow(tmpl)
                                .accessibilityIdentifier("new_notebook.document.tree")
                        }
                    }
                } label: {
                    Label(catalogText(theme.name), systemImage: theme.iconName)
                        .font(.subheadline)
                }
            }
        } header: {
            Text(localizationManager.localized("doc_template_section"))
        } footer: {
            Text(localizationManager.localized("doc_template_hint"))
        }
    }

    private func documentTemplateRow(_ tmpl: DocumentTemplateCatalog.Template) -> some View {
        HStack(spacing: 10) {
            Image(systemName: selectedDocTemplateId == tmpl.id
                ? "checkmark.circle.fill" : "circle")
                .foregroundColor(selectedDocTemplateId == tmpl.id ? .accentColor : .secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(catalogText(tmpl.name)).font(.subheadline)
                Text(catalogText(tmpl.description))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDocTemplateId = selectedDocTemplateId == tmpl.id ? nil : tmpl.id
        }
    }

    private var selectedDocTemplateName: String {
        guard let id = selectedDocTemplateId,
              let tmpl = DocumentTemplateCatalog.template(id: id)
        else { return localizationManager.localized("doc_template_none") }
        return catalogText(tmpl.name)
    }

    private func catalogText(_ table: [String: String]) -> String {
        DocumentTemplateCatalog.localized(
            table, language: localizationManager.currentLanguage.catalogKey
        )
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
                        .foregroundColor(audioManager.status == .recording ? .red : (audioManager.status == .paused ? .orange : .primary))

                    if audioManager.status == .paused {
                        Text(localizationManager.localized("recording_paused"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }

                    HStack(spacing: 3) {
                        ForEach(0 ..< audioManager.audioLevels.count, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(audioManager.status == .recording ? Color.red : (audioManager.status == .paused ? Color.orange.opacity(0.6) : Color.secondary.opacity(0.3)))
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
                        ForEach(notebookStore.visibleNotebooks) { nb in
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

                // 錄音控制大按鈕（支援暫停、繼續、停止並儲存）
                if audioManager.status == .recording || audioManager.status == .paused {
                    HStack(spacing: 16) {
                        // 暫停 / 繼續按鈕
                        Button {
                            if audioManager.status == .recording {
                                audioManager.pauseRecording()
                            } else {
                                audioManager.resumeRecording()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: audioManager.status == .recording ? "pause.fill" : "play.fill")
                                Text(audioManager.status == .recording
                                    ? localizationManager.localized("pause_recording")
                                    : localizationManager.localized("resume_recording"))
                                    .fontWeight(.semibold)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(12)
                        }

                        // 停止並儲存按鈕
                        Button {
                            if let res = audioManager.stopRecording() {
                                let fileName = res.url.lastPathComponent
                                let linkedId = targetNotebookId ?? notebookStore.recordingInbox().id
                                notebookStore.addRecording(
                                    title: recordingTitle,
                                    durationSeconds: Int(res.duration),
                                    fileName: fileName,
                                    linkedNotebookId: linkedId
                                )
                            }
                            dismiss()
                        } label: {
                            HStack(spacing: 6) {
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
                    }
                    .padding(.horizontal, 32)
                } else {
                    Button {
                        Task { await startQuickRecording() }
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
                        if audioManager.status == .recording || audioManager.status == .paused {
                            if let res = audioManager.stopRecording() {
                                let fileName = res.url.lastPathComponent
                                let linkedId = targetNotebookId ?? notebookStore.recordingInbox().id
                                notebookStore.addRecording(
                                    title: recordingTitle,
                                    durationSeconds: Int(res.duration),
                                    fileName: fileName,
                                    linkedNotebookId: linkedId
                                )
                            }
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
                    .accessibilityLabel(localizationManager.localized("open_record_folder"))
                    .help(localizationManager.localized("open_record_folder"))
                }
            }
            .onAppear {
                if recordingTitle.isEmpty {
                    recordingTitle = "\(localizationManager.localized("quick_record_title")) \(Date().formatted(date: .numeric, time: .shortened))"
                }
                Task { await startQuickRecording() }
            }
        }
    }

    /// 首頁的快速錄音。
    ///
    /// 錄音**一定要落在某個套件裡** —— 套件才是同步的單位。使用者沒有指定
    /// 筆記本時就落在「錄音收件匣」，那是一本 id 寫死的筆記本，
    /// 兩台裝置會收斂成同一本（見核心的 `recordingInboxNotebookId()`）。
    ///
    /// 舊版寫到 `Documents/Kairumo Record` 的 m4a —— 那在套件外面，
    /// 所以從來沒有被同步過。
    @MainActor
    private func startQuickRecording() async {
        let target: NotebookDocument
        if let id = targetNotebookId,
           let picked = notebookStore.notebooks.first(where: { $0.id == id })
        {
            target = picked
        } else {
            target = notebookStore.recordingInbox()
        }
        _ = await audioManager.startRecording(
            notebookId: target.id,
            notebookTitle: target.displayTitle(),
            title: recordingTitle,
            pageIndex: 0,
            languageTag: LocalizationManager.shared.currentLanguage.rawValue
        )
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
    @ObservedObject private var startupLogger = StartupLogger.shared
    @Environment(\.dismiss) private var dismiss

    /// 遷移是明確的動作，不在啟動時自動跑 —— 所以要有一個按鈕，
    /// 而且結果要看得到，包含失敗的那幾本是為什麼失敗。
    @State private var isMigrating = false
    @State private var migrationReport: NotebookMigration.Report?
    @State private var rollbackMessage: String?

    /// 雲端同步（決策 D3 選項 A）。
    @State private var showCloudSyncHub = false
    @State private var showFolderPicker = false
    @State private var syncMessage: String?

    /// Google 帳號同步（G-01 ～ G-05）。
    @ObservedObject private var googleAuth = GoogleAuth.shared
    @State private var googleMessage: String?
    @State private var isGoogleSyncing = false

    /// 固定頁面模型的重新分頁（問題 3＋5）。
    @State private var repaginationMessage: String?

    /// 輸入診斷。與 Android 端同一組定義，兩邊的數字才比得起來。
    ///
    /// 用共用的那一份：使用者在編輯器裡寫字，接著到這裡來看數字。
    private var inputDiagnostics: InkInputDiagnostics {
        .shared
    }

    /// 備份與復原。
    @State private var backupMessage: String?
    @State private var showRestorePicker = false
    @State private var shareBackupURL: URL?
    @State private var shareStartupLogsURL: URL?
    @State private var copiedStartupLogs = false

    /// 語音與 Whisper 模型管理
    @ObservedObject private var transcriber = AudioTranscriber.shared
    @State private var showModelFileImporter = false
    @State private var modelImportMessage: String?

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

                startupDiagnosticsSection
                speechTranscriptionSection
                migrationSection
                unifiedSyncSection
                pageModelSection
                backupSection
                inputDiagnosticsSection

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
        .sheet(item: Binding(
            get: { shareStartupLogsURL.map { IdentifiableURL(url: $0) } },
            set: { shareStartupLogsURL = $0?.url }
        )) { item in
            ShareSheet(items: [item.url])
        }
        .fileImporter(
            isPresented: $showModelFileImporter,
            allowedContentTypes: [.data, .item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                do {
                    try transcriber.importWhisperModel(from: url)
                    modelImportMessage = "✅ 成功匯入 Whisper 離線模型！"
                } catch {
                    modelImportMessage = "❌ 匯入失敗: \(error.localizedDescription)"
                }
            case let .failure(error):
                modelImportMessage = "❌ 選取檔案失敗: \(error.localizedDescription)"
            }
        }
    }
}

extension AppDiagnosticsSheet {
    /// 備份與復原。
    ///
    /// 備份檔包含整個 Documents 目錄與 App 自己的設定 —— 目標是「換一台裝置
    /// 或重裝之後，一鍵回到原樣」。容器格式在核心，所以 iPad 上做的備份
    /// 在 Android 也開得起來。
    var backupSection: some View {
        Section(localizationManager.localized("backup_section")) {
            if let backupMessage {
                Text(backupMessage)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Button(localizationManager.localized("backup_create")) { createBackup() }

            Button(localizationManager.localized("backup_restore")) {
                showRestorePicker = true
            }

            Text(localizationManager.localized("backup_safety_note"))
                .font(.caption)
                .foregroundColor(.secondary)
            Text(localizationManager.localized("backup_explainer"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .fileImporter(
            isPresented: $showRestorePicker,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            restoreBackup(from: url)
        }
        .sheet(item: Binding(
            get: { shareBackupURL.map { IdentifiableURL(url: $0) } },
            set: { shareBackupURL = $0?.url }
        )) { item in
            // 系統分享表是 UIActivityViewController，大小由系統決定 ——
            // 硬塞 preferredContentSize 只會讓它的版面錯位。
            ShareSheet(items: [item.url])
        }
    }

    private func createBackup() {
        do {
            let (url, info) = try BackupManager.createBackup(
                documentsDirectory: store.documentsDirectory
            )
            backupMessage = localizationManager.localized("backup_created")
                .replacingFirst("%1@", with: "\(info.fileCount)")
                .replacingFirst("%2@", with: ByteCountFormatter.string(
                    fromByteCount: Int64(info.totalBytes), countStyle: .file
                ))
            // 直接叫出分享面板：備份檔留在 tmp 裡等於沒有備份，
            // 使用者要把它放到雲端或電腦上才算數。
            shareBackupURL = url
        } catch {
            backupMessage = error.localizedDescription
        }
    }

    private func restoreBackup(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            // 先看一眼再動手：使用者要知道自己選到的是什麼。
            _ = try BackupManager.inspect(url)
            let outcome = try BackupManager.restore(
                from: url, into: store.documentsDirectory
            )
            store.loadData()

            var message = localizationManager.localized("backup_restored")
                .replacingFirst("%@", with: "\(outcome.restored)")
            if !outcome.corrupted.isEmpty {
                message += "　" + localizationManager.localized("backup_corrupted")
                    .replacingFirst("%@", with: "\(outcome.corrupted.count)")
            }
            backupMessage = message
        } catch {
            backupMessage = error.localizedDescription
        }
    }

    /// 固定頁面模型。
    ///
    /// 舊版可以任意延長頁面，於是同一本筆記裡每頁高度都不同，匯出與列印無從
    /// 對齊紙張。這個動作把過長的頁面切成固定高度的頁。會動到頁面配置，
    /// 所以是明確的按鈕，不在啟動時自動跑。
    @ViewBuilder
    var pageModelSection: some View {
        if store.needsRepagination || repaginationMessage != nil {
            Section(localizationManager.localized("page_model_section")) {
                if let repaginationMessage {
                    Text(repaginationMessage)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    Text(localizationManager.localized("page_model_needs_repagination"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Button(localizationManager.localized("page_model_repaginate")) {
                    let report = store.repaginateToFixedPages()
                    repaginationMessage = report.allSucceeded
                        ? localizationManager.localized("page_model_done")
                        .replacingFirst("%@", with: "\(report.changedCount)")
                        : localizationManager.localized("page_model_failed")
                        .replacingFirst("%@", with: "\(report.failedCount)")
                }

                Text(localizationManager.localized("page_model_explainer"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    /// Google 帳號同步（G-01 ～ G-05，ADR-0011）。
    ///
    /// 統一雲端同步中心（整合 Google Drive 與 iCloud / 自選資料夾）
    var unifiedSyncSection: some View {
        Section(localizationManager.localized("cloud_sync")) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizationManager.localized("cloud_sync"))
                        .font(.body)
                        .fontWeight(.medium)
                    if googleAuth.isSignedIn {
                        Text("Google Drive: \(googleAuth.accountEmail ?? "")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let folder = CloudSyncFolder.resolveFolder() {
                        Text(localizationManager.localized("sync_folder_label") + ": \(folder.lastPathComponent)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text(localizationManager.localized("sync_not_configured"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button(localizationManager.localized("settings")) {
                    showCloudSyncHub = true
                }
                .font(.footnote)
            }

            if googleAuth.isSignedIn {
                HStack {
                    Text(localizationManager.localized("sync_last_at"))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(SyncHistory.lastGoogleSyncDescription(
                        none: localizationManager.localized("sync_never")
                    ))
                }
                .font(.footnote)

                Button(localizationManager.localized("sync_now")) {
                    Task { await runGoogleSync() }
                }
                .disabled(isGoogleSyncing)

                Button(localizationManager.localized("sign_out"), role: .destructive) {
                    Task {
                        await GoogleAuth.shared.signOut()
                        googleMessage = nil
                    }
                }
            } else if CloudSyncFolder.resolveFolder() != nil {
                HStack {
                    Text(localizationManager.localized("sync_last_at"))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(SyncHistory.lastFolderSyncDescription(
                        none: localizationManager.localized("sync_never")
                    ))
                }
                .font(.footnote)

                Button(localizationManager.localized("sync_now")) {
                    runSync()
                }
            }

            if let googleMessage {
                Text(googleMessage)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            if let syncMessage {
                Text(syncMessage)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Text(localizationManager.localized("cloud_sync_explainer"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .sheet(isPresented: $showCloudSyncHub) {
            CloudSyncDetailSheet()
        }
    }

    /// 語音轉錄與離線模型狀態（提供離線模型檢測、進度顯示、鏡像分流與手動匯入）
    var speechTranscriptionSection: some View {
        Section(localizationManager.localized("asr_section_title2")) {
            let status = transcriber.checkOfflineStatus()
            HStack {
                Text(localizationManager.localized("hw_asr_onboard"))
                Spacer()
                switch status {
                case .whisperReady:
                    Label(localizationManager.localized("hw_asr_whisper_ready"), systemImage: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.footnote)
                case .ready, .appleSpeechReady:
                    Label(localizationManager.localized("hw_asr_system_ready"), systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.footnote)
                case .needsDownload:
                    Label(localizationManager.localized("hw_asr_no_model"), systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.footnote)
                case .unsupported:
                    Label(localizationManager.localized("hw_asr_unsupported"), systemImage: "info.circle")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                }
            }

            if transcriber.isWhisperAvailable {
                HStack {
                    Label(localizationManager.localized("hw_asr_model_ready_size"), systemImage: "internaldrive.fill")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(localizationManager.localized("asr_remove_model"), role: .destructive) {
                        try? transcriber.deleteWhisperModel()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            } else if transcriber.isDownloadingModel {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        ProgressView(value: transcriber.downloadProgress)
                            .progressViewStyle(.linear)
                        Button(localizationManager.localized("cancel")) {
                            transcriber.cancelModelDownload()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                    HStack {
                        Text(transcriber.downloadStatusText.isEmpty ? "下載中..." : "Whisper 模型下載中：\(transcriber.downloadStatusText)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            } else {
                if let error = transcriber.downloadError {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(String(format: localizationManager.localized("hw_asr_download_failed"), error))
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        // 原本這裡有「官方／鏡像」兩顆重試。鏡像那顆拿掉了——
                        // 鏡像的概念在下載管理員、核心與 models/manifest.json
                        // 裡都不存在，兩顆做的事一模一樣。
                        Button {
                            transcriber.downloadWhisperModel()
                        } label: {
                            Text(localizationManager.localized("hw_asr_retry_official"))
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 2)
                } else {
                    Button {
                        transcriber.downloadWhisperModel()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text(localizationManager.localized("hw_asr_download_official"))
                        }
                    }
                    .font(.footnote)
                }

                Button {
                    showModelFileImporter = true
                } label: {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                        Text(localizationManager.localized("hw_asr_import_file"))
                    }
                }
                .font(.footnote)
                .foregroundColor(.accentColor)

                if let modelImportMessage {
                    Text(modelImportMessage)
                        .font(.caption)
                        .foregroundColor(modelImportMessage.starts(with: "✅") ? .green : .red)
                }
            }

            Button {
                transcriber.openSystemDictationSettings()
            } label: {
                HStack {
                    Image(systemName: "gearshape")
                    Text(localizationManager.localized("hw_asr_system_settings"))
                }
            }
            .font(.footnote)

            Text(localizationManager.localized("hw_asr_explainer"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @MainActor
    private func runGoogleSync() async {
        guard !isGoogleSyncing else { return }
        isGoogleSyncing = true
        defer { isGoogleSyncing = false }

        googleMessage = localizationManager.localized("syncing")
        let report: NotebookSyncCoordinator.Report?
        do {
            report = try await withSyncTimeout(seconds: 180) {
                await NotebookSyncCoordinator.runDrive(
                    store: store, deviceId: NotebookMigration.deviceId
                )
            }
        } catch {
            googleMessage = "同步逾時，請確認網路連線後重試"
            return
        }
        guard let report else {
            googleMessage = localizationManager.localized("not_signed_in")
            return
        }
        // 被互斥閘擋下來：別說「已是最新」—— 這一輪根本沒比對過雲端。
        if report.wasSkipped {
            googleMessage = localizationManager.localized("sync_already_running")
            return
        }
        if report.failures.isEmpty {
            SyncHistory.markGoogleSynced()
        }
        if let failure = report.failures.first {
            googleMessage = "\(failure.key)：\(failure.value)"
        } else if report.isNoOp {
            googleMessage = localizationManager.localized("sync_up_to_date")
        } else {
            googleMessage = localizationManager.localized("sync_result")
                .replacingFirst("%1@", with: "\(report.uploaded)")
                .replacingFirst("%2@", with: "\(report.downloaded)")
        }
    }

    private func runSync() {
        guard let folder = CloudSyncFolder.resolveFolder() else { return }

        Task {
            let scoped = folder.startAccessingSecurityScopedResource()
            defer {
                if scoped {
                    folder.stopAccessingSecurityScopedResource()
                }
            }

            // 匯出 → 搬檔 → 匯入。順序不能顛倒：先搬檔的話上傳的是舊內容，
            // 不匯入的話另一台裝置寫的東西永遠不會變成筆記。
            let report = await NotebookSyncCoordinator.run(
                store: store, folder: folder, deviceId: NotebookMigration.deviceId
            )

            if report.failures.isEmpty && report.needsAttention.isEmpty {
                SyncHistory.markFolderSynced()
            }
            if let first = report.needsAttention.first {
                syncMessage = localizationManager.localized("sync_needs_attention")
                    .replacingFirst("%@", with: first)
            } else if let failure = report.failures.first {
                syncMessage = "\(failure.key)：\(failure.value)"
            } else if report.isNoOp {
                syncMessage = localizationManager.localized("sync_up_to_date")
            } else {
                syncMessage = localizationManager.localized("sync_result")
                    .replacingFirst("%1@", with: "\(report.uploaded)")
                    .replacingFirst("%2@", with: "\(report.downloaded)")
            }
        }
    }

    /// 輸入診斷與筆尖延遲。
    ///
    /// Android 早就有這一欄，Apple 一直沒有 —— 於是 iPad 出問題時只能猜。
    /// 上一輪 Android 畫布全白那次，就是靠這條線找到原因的。
    ///
    /// 量到的是「事件在硬體上發生 → 交給畫面」，**不是筆尖到光子**：
    /// 面板的掃描與亮起時間量不到。它真正有用的地方是同一台裝置上開關某個
    /// 選項的前後對比。
    var inputDiagnosticsSection: some View {
        Section(localizationManager.localized("input_diagnostics")) {
            ForEach(inputDiagnostics.lines(), id: \.0) { label, value in
                HStack {
                    Text(label)
                    Spacer()
                    Text(value)
                        .foregroundColor(.secondary)
                        .font(.system(.body, design: .monospaced))
                }
            }
            Text(localizationManager.localized("input_diagnostics_explainer"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    /// 啟動與效能診斷日誌（毫秒時間戳與執行緒標記）。
    var startupDiagnosticsSection: some View {
        Section {
            HStack {
                Text(localizationManager.localized("startup_logs_title"))
                    .font(.headline)
                Spacer()
                if !startupLogger.entries.isEmpty {
                    Button {
                        copyStartupLogs()
                        copiedStartupLogs = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            copiedStartupLogs = false
                        }
                    } label: {
                        Label(
                            copiedStartupLogs ? localizationManager.localized("log_copied") : localizationManager.localized("log_copy"),
                            systemImage: copiedStartupLogs ? "checkmark" : "doc.on.doc"
                        )
                    }
                    .font(.caption)
                    .foregroundColor(copiedStartupLogs ? .green : .indigo)
                    .animation(.easeInOut(duration: 0.2), value: copiedStartupLogs)

                    Button {
                        exportStartupLogs()
                    } label: {
                        Label(localizationManager.localized("log_export"), systemImage: "square.and.arrow.up")
                    }
                    .font(.caption)
                    .foregroundColor(.indigo)

                    Button(localizationManager.localized("log_clear")) {
                        startupLogger.clear()
                    }
                    .font(.caption)
                    .foregroundColor(.indigo)
                }
            }
            if startupLogger.entries.isEmpty {
                Text(localizationManager.localized("log_empty"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(startupLogger.entries) { entry in
                            HStack(alignment: .top, spacing: 6) {
                                Text(entry.thread)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(entry.thread == "Main" ? Color.orange.opacity(0.18) : Color.blue.opacity(0.18))
                                    .foregroundColor(entry.thread == "Main" ? .orange : .blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))

                                Text(entry.message)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 1)
                        }
                    }
                    .padding(4)
                }
                .frame(maxHeight: 220)
            }
        }
    }

    private func copyStartupLogs() {
        LogExportUtility.copy(startupLogText(includeTimestamp: false))
    }

    private func exportStartupLogs() {
        do {
            shareStartupLogsURL = try LogExportUtility.writeTextFile(
                startupLogText(includeTimestamp: true),
                filename: "kairumo-startup-logs.txt"
            )
        } catch {
            StartupLogger.log("啟動日誌匯出失敗：\(error.localizedDescription)")
        }
    }

    private func startupLogText(includeTimestamp: Bool) -> String {
        startupLogger.entries.map { entry in
            if includeTimestamp {
                return "[\(LogExportUtility.timestamp(entry.timestamp))] [\(entry.thread)] \(entry.message)"
            } else {
                return entry.message
            }
        }
        .joined(separator: "\n")
    }

    /// 跨平台格式轉換。
    ///
    /// 放在診斷頁而不是主畫面：這是進階動作，不該是使用者第一天就會按到的東西。
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
                    if isMigrating {
                        ProgressView().padding(.trailing, 6)
                    }
                    Text(localizationManager.localized(
                        isMigrating ? "migration_running" : "migration_run"
                    ))
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
            if case let .failed(reason) = outcome {
                return (id, reason)
            }
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
        guard let range = range(of: target) else { return self }
        return replacingCharacters(in: range, with: replacement)
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
        _currentNotebookId = State(initialValue: initialNotebookId)
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

/// `sheet(item:)` 需要 Identifiable，而 URL 不是。
private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String {
        url.path
    }
}

/// 系統分享面板。備份檔留在 tmp 裡等於沒有備份 —— 一定要讓使用者把它帶走。
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}

/// 系統檔案儲存面板（取代 ShareSheet，直接開啟 Files 選擇儲存位置）。
private struct DocumentExporter: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context _: Context) -> UIDocumentPickerViewController {
        UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}
}

private enum LogExportUtility {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    static func timestamp(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func copy(_ text: String) {
        UIPasteboard.general.string = text
    }

    static func writeTextFile(_ text: String, filename: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: filename)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

// MARK: - 1. 雲端同步中心專屬獨立視窗 (整合 Google Drive 與 iCloud / 資料夾同步)

public enum CloudSyncProvider: String, CaseIterable, Identifiable {
    case googleDrive = "google"
    case folderOrICloud = "folder"
    case disabled

    public var id: String {
        rawValue
    }
}

public struct CloudSyncDetailSheet: View {
    @ObservedObject var localizationManager = LocalizationManager.shared
    @ObservedObject private var googleAuth = GoogleAuth.shared
    @ObservedObject private var autoSync = AutoSyncController.shared
    @ObservedObject private var notebookStore = NotebookStore.shared
    @ObservedObject private var syncLogger = SyncLogger.shared
    @ObservedObject private var tailscaleMonitor = TailscaleMonitor.shared
    @Environment(\.dismiss) private var dismiss

    public enum LogFilter: String, CaseIterable, Identifiable {
        case currentTab = "當前分頁"
        case all = "全部"
        case googleDrive = "Google Drive"
        case folder = "iCloud / 資料夾"

        public var id: String {
            rawValue
        }
    }

    @State private var logFilter: LogFilter = .currentTab
    @State private var selectedProvider: CloudSyncProvider = .googleDrive
    @State private var googleStatusMessage: String?
    /// 「重置雲端同步」的確認與進行狀態。
    @State private var showWipeConfirm = false
    @State private var showReclaimConfirm = false
    @State private var isReclaiming = false
    @State private var isWiping = false
    @State private var wipeMessage: String?
    @State private var isGoogleSyncing = false
    @State private var googleSyncTask: Task<Void, Never>?
    @State private var folderStatusMessage: String?
    @State private var isFolderSyncing = false
    @State private var folderSyncTask: Task<Void, Never>?
    @State private var showFolderPicker = false
    @State private var shareSyncLogsURL: URL?
    @State private var copiedSyncLogs = false

    // Asynchronous diagnostic state to prevent main thread blocking (watchdog crash)
    @State private var currentDiagnostics: FfiSyncDiagnostics?
    @State private var currentAudit: FfiCloudAudit?

    private func refreshDiagnostics() async {
        let store = notebookStore
        let packagesDir = store.syncPackagesDirectory
        let books = store.syncNotebooks
        let account = googleAuth.accountEmail ?? ""
        let remoteIndexJson = AccountSyncStore.shared.remoteIndexJSON(account: account)
        let libraryIndexJson = AccountSyncStore.shared.indexJSON

        let (d, a) = await Task.detached {
            let packagePaths = books.map { packagesDir.appending(path: "\($0.id).padnote").path }
            let notebookIds = books.map { $0.id }
            let d = syncDiagnose(
                remoteIndexJson: remoteIndexJson,
                packagePaths: packagePaths,
                notebookIds: notebookIds
            )
            let a = cloudAudit(
                remoteIndexJson: remoteIndexJson,
                libraryIndexJson: libraryIndexJson
            )
            return (d, a)
        }.value

        await MainActor.run {
            self.currentDiagnostics = d
            self.currentAudit = a
        }
    }

    private static let logDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private let initialProvider: CloudSyncProvider?

    public init(initialProvider: CloudSyncProvider? = nil) {
        self.initialProvider = initialProvider
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    // 同步服務切換分頁
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localizationManager.localized("hw_sync_choose_service"))
                            .font(DS.Font.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $selectedProvider) {
                            Text(localizationManager.localized("hw_sync_gdrive_option")).tag(CloudSyncProvider.googleDrive)
                            Text(localizationManager.localized("sync_folder_label")).tag(CloudSyncProvider.folderOrICloud)
                            Text(localizationManager.localized("hw_sync_off_option")).tag(CloudSyncProvider.disabled)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.top, DS.Space.xs)

                    // Tailscale 點對點連線狀態指示
                    HStack(spacing: 8) {
                        Circle()
                            .fill(tailscaleMonitor.status.isConnected ? Color.green : Color.secondary.opacity(0.4))
                            .frame(width: 8, height: 8)
                        Text(tailscaleMonitor.status.isConnected ? "Tailscale 直連就緒 (\(tailscaleMonitor.status.ipAddress ?? ""))" : "Tailscale 未連線")
                            .font(DS.Font.caption)
                            .foregroundColor(tailscaleMonitor.status.isConnected ? .green : .secondary)

                        Spacer()

                        Link(destination: URL(string: "https://tailscale.com/download")!) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.up.right.square")
                                Text("下載 Tailscale")
                            }
                            .font(DS.Font.caption)
                            .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.horizontal, DS.Space.s)
                    .padding(.vertical, DS.Space.xs)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    if selectedProvider == .googleDrive {
                        googleDriveSection
                    } else if selectedProvider == .folderOrICloud {
                        folderSyncSection
                    } else {
                        disabledSyncSection
                    }
                }
                .padding(DS.Space.m)

                if selectedProvider == .googleDrive {
                    syncDoctorSection
                        .padding(.horizontal, DS.Space.m)
                        .padding(.bottom, DS.Space.s)
                }

                if selectedProvider != .disabled {
                    logSection
                        .padding(.horizontal, DS.Space.m)
                        .padding(.bottom, DS.Space.m)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(localizationManager.localized("cloud_sync"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized("close")) { dismiss() }
                }
            }
            .task {
                await refreshDiagnostics()
            }
            .onChange(of: isGoogleSyncing) { _ in
                Task { await refreshDiagnostics() }
            }
            .onChange(of: autoSync.isSyncing) { _ in
                Task { await refreshDiagnostics() }
            }
            .onAppear {
                if let initial = initialProvider {
                    selectedProvider = initial
                } else if googleAuth.isSignedIn {
                    selectedProvider = .googleDrive
                } else if CloudSyncFolder.resolveFolder() != nil {
                    selectedProvider = .folderOrICloud
                } else {
                    selectedProvider = .googleDrive
                }
            }
            .fileImporter(
                isPresented: $showFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case let .success(urls):
                    guard let url = urls.first else { return }
                    if url.pathExtension == "padnote" || url.lastPathComponent.hasSuffix(".padnote") {
                        folderStatusMessage = localizationManager.localized("invalid_folder_padnote")
                        return
                    }
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer {
                        if scoped {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    do {
                        try CloudSyncFolder.setFolder(url)
                        folderSyncTask = Task { await runFolderSync() }
                    } catch {
                        folderStatusMessage = error.localizedDescription
                    }
                case let .failure(error):
                    folderStatusMessage = error.localizedDescription
                }
            }
            .sheet(item: Binding(
                get: { shareSyncLogsURL.map { IdentifiableURL(url: $0) } },
                set: { shareSyncLogsURL = $0?.url }
            )) { item in
                ShareSheet(items: [item.url])
            }
        }
    }

    // MARK: - Google Drive 視圖

    private var googleDriveSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.l) {
            HStack(spacing: DS.Space.m) {
                Image(systemName: "arrow.triangle.2.circlepath.icloud.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.indigo)

                VStack(alignment: .leading, spacing: 4) {
                    Text(localizationManager.localized("sync_section"))
                        .font(DS.Font.screenTitle)
                        .foregroundColor(.primary)

                    Text(googleStatusText)
                        .font(DS.Font.cardTitle)
                        .foregroundColor(googleStatusColor)
                }
            }

            VStack(spacing: 0) {
                if googleAuth.isSignedIn {
                    if let email = googleAuth.accountEmail {
                        detailRow(title: localizationManager.localized("sync_account"), value: email)
                        Divider()
                    }
                    detailRow(
                        title: localizationManager.localized("sync_destination"),
                        value: localizationManager.localized("sync_destination_appdata")
                    )
                    Divider()
                    detailRow(
                        title: localizationManager.localized("sync_last_at"),
                        value: SyncHistory.lastGoogleSyncDescription(date: autoSync.lastGoogleSyncDate, none: localizationManager.localized("sync_never"))
                    )
                    // **同一件事不可以兩個地方說不同的話。**
                    //
                    // 這張面板原本只顯示「上次成功是什麼時候」，而它背後的
                    // 卡片顯示的是「現在正在跑」—— 兩邊各自帶 @State，互不
                    // 知情。使用者看到的是卡片寫「同步中…」、面板寫「3 天前」
                    // 而且「立即同步」還按得下去（按了只會被互斥閘擋掉）。
                    //
                    // 狀態改成讀同一個來源：`AutoSyncController`。
                    if isGoogleSyncing || autoSync.isSyncing {
                        Divider()
                        detailRow(
                            title: localizationManager.localized("sync_status"),
                            value: localizationManager.localized("syncing")
                        )
                    } else if let msg = googleStatusMessage ?? (autoSync.lastMessage.isEmpty ? nil : autoSync.lastMessage), !msg.isEmpty {
                        Divider()
                        detailRow(
                            title: localizationManager.localized("sync_status"),
                            value: msg
                        )
                    }
                } else {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .foregroundColor(.orange)
                        Text(localizationManager.localized("not_signed_in"))
                            .font(DS.Font.body)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(DS.Space.m)
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(DS.Radius.m)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.m)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )

            if isFolderSyncing {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.teal)
                    Text(localizationManager.localized("hw_sync_running_folder"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, DS.Space.xs)
            }

            if let googleStatusMessage {
                Text(googleStatusMessage)
                    .font(DS.Font.caption)
                    .foregroundColor(googleStatusMessage.contains("失敗") || googleStatusMessage.contains("過期") ? .red : .secondary)
                    .padding(.horizontal, DS.Space.xs)
            }

            VStack(spacing: DS.Space.s) {
                if googleAuth.isSignedIn {
                    // **「正在跑」要包含自動同步那一輪。**
                    //
                    // 原本只看這張面板自己的 `isGoogleSyncing`，所以背景自動
                    // 同步進行中時，這裡照樣顯示「立即同步」按得下去 ——
                    // 按了只會被互斥閘擋掉，而使用者只看到一顆沒反應的按鈕。
                    if isGoogleSyncing || autoSync.isSyncing {
                        Button(role: .destructive) {
                            googleSyncTask?.cancel()
                            NotebookSyncCoordinator.cancelSync()
                            isGoogleSyncing = false
                            autoSync.setSyncing(false, message: localizationManager.localized("sync_interrupted"))
                            googleStatusMessage = localizationManager.localized("sync_interrupted")
                        } label: {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 6)
                                Text(localizationManager.localized("hw_sync_disconnect"))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    } else {
                        Button {
                            googleSyncTask = Task { await runGoogleSync() }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text(localizationManager.localized("sync_now"))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                    }

                    Button(role: .destructive) {
                        Task {
                            await GoogleAuth.shared.signOut()
                            googleStatusMessage = nil
                        }
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text(localizationManager.localized("sign_out"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        Task {
                            googleStatusMessage = nil
                            switch await GoogleAuth.shared.signIn() {
                            case .success:
                                if !isGoogleSyncing {
                                    await runGoogleSync()
                                } else {
                                    googleStatusMessage = "已登入成功（目前正有其他同步執行中）"
                                }
                            case .failure(.cancelled):
                                break
                            case let .failure(error):
                                googleStatusMessage = error.errorDescription ?? error.localizedDescription
                            }
                        }
                    } label: {
                        HStack {
                            if googleAuth.isSigningIn {
                                ProgressView()
                                    .padding(.trailing, 6)
                                Text(localizationManager.localized("hw_signing_in"))
                                    .fontWeight(.semibold)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                Text(localizationManager.localized("sign_in_google"))
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .disabled(googleAuth.isSigningIn)
                }
            }

            VStack(alignment: .leading, spacing: DS.Space.m) {
                Text(localizationManager.localized("help_and_legal"))
                    .font(DS.Font.cardTitle)
                    .foregroundColor(.primary)

                guideStep(
                    number: "1",
                    title: localizationManager.localized("sign_in_google"),
                    desc: localizationManager.localized("cloud_sync_explainer")
                )
                guideStep(
                    number: "2",
                    title: localizationManager.localized("sync_destination"),
                    desc: localizationManager.localized("sync_destination_appdata")
                )
                guideStep(
                    number: "3",
                    title: localizationManager.localized("sync_x_platform_title"),
                    desc: "支援 Android、iPadOS 與 macOS 雙向增量筆跡與圖表合併，各平台均可無縫協同編輯。"
                )
            }
            .padding(DS.Space.m)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(DS.Radius.m)
        }
    }

    // MARK: - iCloud / 資料夾同步視圖

    private var folderSyncSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.l) {
            HStack(spacing: DS.Space.m) {
                Image(systemName: "icloud.and.arrow.up.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.teal)

                VStack(alignment: .leading, spacing: 4) {
                    Text(localizationManager.localized("sync_choose_folder"))
                        .font(DS.Font.screenTitle)
                        .foregroundColor(.primary)

                    Text(folderStatusTitle)
                        .font(DS.Font.cardTitle)
                        .foregroundColor(folderStatusColor)
                }
            }

            VStack(spacing: 0) {
                HStack {
                    Text(localizationManager.localized("migration_status"))
                        .font(DS.Font.body)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(folderStatusText)
                        .font(DS.Font.body)
                        .foregroundColor(folderStatusColor)
                }
                .padding(DS.Space.m)

                if let folder = CloudSyncFolder.resolveFolder() {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizationManager.localized("sync_folder_path"))
                            .font(DS.Font.caption)
                            .foregroundColor(.secondary)
                        Text(folder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                            .font(.system(.footnote, design: .monospaced))
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DS.Space.m)

                    Divider()
                    HStack {
                        Text(localizationManager.localized("sync_last_at"))
                            .font(DS.Font.body)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(SyncHistory.lastFolderSyncDescription(none: localizationManager.localized("sync_never")))
                            .font(DS.Font.body)
                            .foregroundColor(.primary)
                    }
                    .padding(DS.Space.m)
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(DS.Radius.m)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.m)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )

            if isGoogleSyncing {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.indigo)
                    Text(localizationManager.localized("hw_sync_running_gdrive"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, DS.Space.xs)
            }

            if let folderStatusMessage {
                Text(folderStatusMessage)
                    .font(DS.Font.caption)
                    .foregroundColor(folderStatusMessage.contains("失敗") || folderStatusMessage.contains("錯誤") ? .red : .secondary)
                    .padding(.horizontal, DS.Space.xs)
            }

            // **兩種同步都設定時，只有 Drive 會自動跑。**
            //
            // `AutoSyncController.runOneRound` 是「登入 Drive 就只跑 Drive」，
            // 資料夾那條在自動路徑上碰不到。在這之前這件事完全不會說 ——
            // 使用者設好 iCloud 資料夾，看起來已設定，實際上永遠不會自動
            // 更新，變成一份會過期的備份。那比沒設定更危險。
            //
            // 不強迫擇一（雙備份是合理需求），但要講清楚哪一個是自動的。
            if googleAuth.isSignedIn {
                Text(localizationManager.localized("sync_folder_manual_while_drive"))
                    .font(DS.Font.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, DS.Space.xs)
            }

            VStack(spacing: DS.Space.s) {
                Button {
                    showFolderPicker = true
                } label: {
                    HStack {
                        Image(systemName: "folder.badge.gearshape")
                        Text(localizationManager.localized("sync_choose_folder"))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)

                if CloudSyncFolder.resolveFolder() != nil {
                    if isFolderSyncing {
                        Button(role: .destructive) {
                            folderSyncTask?.cancel()
                            NotebookSyncCoordinator.cancelSync()
                            isFolderSyncing = false
                            folderStatusMessage = "已中斷同步"
                        } label: {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 6)
                                Text(localizationManager.localized("hw_sync_disconnect"))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    } else {
                        Button {
                            folderSyncTask = Task { await runFolderSync() }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text(localizationManager.localized("sync_now"))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                        .tint(.teal)
                    }

                    Button(role: .destructive) {
                        CloudSyncFolder.clearFolder()
                        folderStatusMessage = nil
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text(localizationManager.localized("delete_item"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                    // 重置雲端資料夾
                    Button(role: .destructive) {
                        showWipeConfirm = true
                    } label: {
                        if isWiping {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text(localizationManager.localized("sync_reset_cloud_running"))
                            }
                        } else {
                            HStack {
                                Image(systemName: "trash")
                                Text(localizationManager.localized("sync_reset_cloud"))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                    .padding(.top, DS.Space.m)
                    .disabled(isWiping || isFolderSyncing)
                    .confirmationDialog(
                        localizationManager.localized("sync_reset_cloud_confirm_title"),
                        isPresented: $showWipeConfirm,
                        titleVisibility: .visible
                    ) {
                        Button(localizationManager.localized("sync_reset_cloud"), role: .destructive) {
                            Task { await runWipeCloud() }
                        }
                        Button(localizationManager.localized("cancel"), role: .cancel) {}
                    } message: {
                        Text(localizationManager.localized("sync_reset_cloud_confirm_body"))
                    }

                    if let wipeMessage {
                        Text(wipeMessage)
                            .font(DS.Font.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }
            }

            VStack(alignment: .leading, spacing: DS.Space.m) {
                Text(localizationManager.localized("hw_sync_how_it_works"))
                    .font(DS.Font.cardTitle)
                    .foregroundColor(.primary)

                guideStep(
                    number: "1",
                    title: localizationManager.localized("sync_q_what"),
                    desc: "本功能採用去中心化的架構。設定 iCloud Drive 或自選資料夾後，每一本筆記都會自動產生對應的 `.padnote` 專屬資料夾（內含手寫向量筆畫與錄音檔等）。這些多出來的 `.padnote` 是維持同步的正常結構，請勿隨意刪除。"
                )
                guideStep(
                    number: "2",
                    title: localizationManager.localized("sync_q_how"),
                    desc: "在您的其他 iPad 或 Mac 上，只要在「雲端同步」指定「同一個上層根目錄」（不要點進個別的 .padnote），App 即會自動掃描所有筆記並進行雙向合併更新。"
                )
                guideStep(
                    number: "3",
                    title: localizationManager.localized("sync_q_privacy"),
                    desc: "沒有第三方伺服器儲存您的手繪或筆記，同步直接由 Apple 系統的 iCloud 傳輸，確保 100% 隱私與資料主權。"
                )
            }
            .padding(DS.Space.m)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(DS.Radius.m)
        }
    }

    private var folderStatusTitle: String {
        if CloudSyncFolder.resolveFolder() == nil {
            return localizationManager.localized("sync_not_configured")
        }
        if isFolderSyncing {
            return localizationManager.localized("syncing")
        }
        if let msg = folderStatusMessage, msg.contains("失敗") || msg.contains("錯誤") {
            return "同步發生錯誤"
        }
        let history = SyncHistory.lastFolderSyncDescription(none: "never")
        if history != "never" {
            return localizationManager.localized("sync_done")
        }
        return "已設定資料夾 (待同步)"
    }

    private var folderStatusText: String {
        if CloudSyncFolder.resolveFolder() == nil {
            return localizationManager.localized("sync_not_configured")
        }
        if isFolderSyncing {
            return folderStatusMessage ?? localizationManager.localized("syncing")
        }
        if let msg = folderStatusMessage, msg.contains("失敗") || msg.contains("錯誤") {
            return "同步失敗"
        }
        let history = SyncHistory.lastFolderSyncDescription(none: "never")
        if history != "never" {
            return localizationManager.localized("sync_done")
        }
        return "已設定 (待同步)"
    }

    private var googleStatusText: String {
        if !googleAuth.isSignedIn {
            return localizationManager.localized("not_signed_in")
        }
        if isGoogleSyncing || autoSync.isSyncing {
            return localizationManager.localized("syncing")
        }
        if let msg = googleStatusMessage ?? (autoSync.lastMessage.isEmpty ? nil : autoSync.lastMessage), msg.contains("失敗") || msg.contains("錯誤") || msg.contains("過期") || msg.contains("逾時") {
            return "同步發生錯誤"
        }
        return localizationManager.localized("sync_done")
    }

    private var googleStatusColor: Color {
        if !googleAuth.isSignedIn {
            return .secondary
        }
        if isGoogleSyncing || autoSync.isSyncing {
            return .teal
        }
        if let msg = googleStatusMessage ?? (autoSync.lastMessage.isEmpty ? nil : autoSync.lastMessage), msg.contains("失敗") || msg.contains("錯誤") || msg.contains("過期") || msg.contains("逾時") {
            return .red
        }
        return .green
    }

    private var folderStatusColor: Color {
        if CloudSyncFolder.resolveFolder() == nil {
            return .secondary
        }
        if isFolderSyncing {
            return .teal
        }
        if let msg = folderStatusMessage, msg.contains("失敗") || msg.contains("錯誤") {
            return .red
        }
        let history = SyncHistory.lastFolderSyncDescription(none: "never")
        if history != "never" {
            return .green
        }
        return .blue
    }

    // MARK: - 關閉同步視圖

    private var disabledSyncSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.l) {
            HStack(spacing: DS.Space.m) {
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.gray)

                VStack(alignment: .leading, spacing: 4) {
                    Text(localizationManager.localized("hw_local_only_mode"))
                        .font(DS.Font.screenTitle)
                        .foregroundColor(.primary)

                    Text(localizationManager.localized("hw_local_only_sub"))
                        .font(DS.Font.cardTitle)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(localizationManager.localized("hw_local_only_explainer"))
                    .font(DS.Font.body)
                    .foregroundColor(.secondary)

                if googleAuth.isSignedIn {
                    HStack {
                        Text(localizationManager.localized("hw_google_still_signed_in"))
                            .font(.footnote)
                        Spacer()
                        Button(localizationManager.localized("google_sign_out")) {
                            Task { await googleAuth.signOut() }
                        }
                        .font(.footnote)
                    }
                    .padding(.top, 4)
                }

                if CloudSyncFolder.resolveFolder() != nil {
                    HStack {
                        Text(localizationManager.localized("hw_folder_still_linked"))
                            .font(.footnote)
                        Spacer()
                        Button(localizationManager.localized("folder_unlink")) {
                            CloudSyncFolder.clearFolder()
                        }
                        .font(.footnote)
                        .foregroundColor(.red)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(DS.Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(DS.Radius.m)
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(DS.Font.body)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(DS.Font.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(DS.Space.m)
    }

    private func guideStep(number: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.15))
                    .frame(width: 26, height: 26)
                Text(number)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.indigo)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Font.body)
                    .fontWeight(.semibold)
                Text(desc)
                    .font(DS.Font.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(5) // 替換 fixedSize：避免 CoreText 斷字字典 I/O (0x8BADF00D)
            }
        }
    }

    @MainActor
    private func runGoogleSync() async {
        guard !isGoogleSyncing, !autoSync.isSyncing else { return }
        isGoogleSyncing = true
        autoSync.setSyncing(true, message: localizationManager.localized("sync_gdrive_syncing"))
        defer {
            isGoogleSyncing = false
            autoSync.setSyncing(false)
        }

        googleStatusMessage = localizationManager.localized("sync_gdrive_syncing")
        let report: NotebookSyncCoordinator.Report?
        do {
            report = try await withSyncTimeout(seconds: 180) {
                await NotebookSyncCoordinator.runDrive(
                    store: notebookStore, deviceId: NotebookMigration.deviceId
                )
            }
        } catch is CancellationError {
            googleStatusMessage = "已中斷同步"
            return
        } catch {
            if Task.isCancelled || NotebookSyncCoordinator.isCancelled {
                googleStatusMessage = "已中斷同步"
            } else {
                googleStatusMessage = "同步逾時，請確認網路連線後重試"
            }
            return
        }
        if Task.isCancelled || NotebookSyncCoordinator.isCancelled {
            googleStatusMessage = "已中斷同步"
            return
        }
        guard let report else {
            googleStatusMessage = localizationManager.localized("not_signed_in")
            return
        }
        // 被互斥閘擋下來：別說「已是最新」—— 這一輪根本沒比對過雲端。
        if report.wasSkipped {
            googleStatusMessage = localizationManager.localized("sync_already_running")
            return
        }
        if report.failures.isEmpty {
            SyncHistory.markGoogleSynced()
        }
        if let failure = report.failures.first {
            googleStatusMessage = "\(failure.key)：\(failure.value)"
        } else if report.isNoOp {
            googleStatusMessage = localizationManager.localized("sync_up_to_date")
        } else {
            googleStatusMessage = localizationManager.localized("sync_result")
                .replacingFirst("%1@", with: "\(report.uploaded)")
                .replacingFirst("%2@", with: "\(report.downloaded)")
        }
    }

    @MainActor
    private func runFolderSync() async {
        guard !isFolderSyncing else { return }
        guard let folder = CloudSyncFolder.resolveFolder() else { return }
        isFolderSyncing = true
        defer { isFolderSyncing = false }

        let scoped = folder.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                folder.stopAccessingSecurityScopedResource()
            }
        }

        folderStatusMessage = "iCloud / 資料夾同步中..."
        let report: NotebookSyncCoordinator.Report
        do {
            report = try await withSyncTimeout(seconds: 180) {
                await NotebookSyncCoordinator.run(
                    store: notebookStore, folder: folder, deviceId: NotebookMigration.deviceId
                )
            }
        } catch is CancellationError {
            folderStatusMessage = "已中斷同步"
            return
        } catch {
            if Task.isCancelled || NotebookSyncCoordinator.isCancelled {
                folderStatusMessage = "已中斷同步"
            } else {
                folderStatusMessage = "同步逾時，請確認網路連線或 iCloud 狀態後重試"
            }
            return
        }
        if Task.isCancelled || NotebookSyncCoordinator.isCancelled {
            folderStatusMessage = "已中斷同步"
            return
        }
        if report.failures.isEmpty, report.needsAttention.isEmpty {
            SyncHistory.markFolderSynced()
        }
        if let first = report.needsAttention.first {
            folderStatusMessage = localizationManager.localized("sync_needs_attention")
                .replacingFirst("%@", with: first)
        } else if let failure = report.failures.first {
            folderStatusMessage = "\(failure.key)：\(failure.value)"
        } else if report.isNoOp {
            folderStatusMessage = localizationManager.localized("sync_up_to_date")
        } else {
            folderStatusMessage = localizationManager.localized("sync_result")
                .replacingFirst("%1@", with: "\(report.uploaded)")
                .replacingFirst("%2@", with: "\(report.downloaded)")
        }
    }

    private var filteredLogEntries: [SyncLogger.LogEntry] {
        syncLogger.entries.filter { entry in
            switch logFilter {
            case .currentTab:
                if selectedProvider == .googleDrive {
                    return entry.source == .googleDrive || entry.source == .general
                } else if selectedProvider == .folderOrICloud {
                    return entry.source == .folder || entry.source == .general
                } else {
                    return true
                }
            case .all:
                return true
            case .googleDrive:
                return entry.source == .googleDrive
            case .folder:
                return entry.source == .folder
            }
        }
    }

    private func copySyncLogs() {
        LogExportUtility.copy(syncLogText(includeTimestamp: false))
    }

    private func exportSyncLogs() {
        do {
            shareSyncLogsURL = try LogExportUtility.writeTextFile(
                syncLogText(includeTimestamp: true),
                filename: "kairumo-sync-logs.txt"
            )
        } catch {
            if selectedProvider == .googleDrive {
                googleStatusMessage = error.localizedDescription
            } else {
                folderStatusMessage = error.localizedDescription
            }
        }
    }

    private func syncLogText(includeTimestamp: Bool) -> String {
        filteredLogEntries.map { entry in
            if includeTimestamp {
                return "[\(LogExportUtility.timestamp(entry.timestamp))] [\(entry.source.rawValue)] \(entry.message)"
            } else {
                return entry.message
            }
        }
        .joined(separator: "\n")
    }

    /// 同步醫生（P4）。
    ///
    /// # 為什麼日誌不夠
    ///
    /// 出問題時畫面上只有一串日誌。日誌答得出「發生過什麼」，答不出
    /// **「現在是什麼狀態」**：游標建立了沒？快照裡有幾個檔案？
    /// 哪幾本還沒推上去？而那才是下一步要根據的東西。
    ///
    /// 這一段**不打網路、也不需要權杖** —— 診斷畫面在網路不通的時候
    /// 最需要，依賴一個要先去換權杖的工作階段就等於在最需要時失效。
    @ViewBuilder
    private var syncDoctorSection: some View {
        if let diagnostics = currentDiagnostics, let cloudFiles = currentAudit {
            VStack(alignment: .leading, spacing: 8) {
                Text(localizationManager.localized("hw_sync_status"))
                    .font(DS.Font.caption)
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 6) {
                    doctorRow(
                        "雲端快照",
                        diagnostics.hasCursor
                            ? "已建立（追蹤 \(diagnostics.trackedFiles) 個檔案）"
                            : "尚未建立，下次同步會重新盤點一次"
                    )
                    doctorRow(
                        "待同步筆記",
                        diagnostics.pendingNotebooks.isEmpty
                            ? "無（已檢查 \(diagnostics.checkedNotebooks) 本）"
                            : "\(diagnostics.pendingNotebooks.count) / \(diagnostics.checkedNotebooks) 本"
                    )
                    doctorRow(
                        "自動同步",
                        AutoSyncController.shared.needsSignIn
                            ? "已暫停，請重新登入"
                            : (AutoSyncController.shared.isSyncing ? "進行中" : "待命")
                    )
                    doctorRow(
                        localizationManager.localized("sync_audit_files"),
                        localizationManager.localized("sync_audit_breakdown")
                            .replacingFirst("%1@", with: "\(cloudFiles.live)")
                            .replacingFirst("%2@", with: "\(cloudFiles.deleted)")
                            .replacingFirst("%3@", with: "\(cloudFiles.unknown)")
                    )
                    if cloudFiles.unknown > 0 {
                        Text(localizationManager.localized("sync_audit_unknown_hint"))
                            .font(DS.Font.caption)
                            .foregroundColor(.secondary)
                    }
                    if !AutoSyncController.shared.lastMessage.isEmpty {
                        doctorRow("最後結果", AutoSyncController.shared.lastMessage)
                    }
                    if let wipeMessage {
                        doctorRow("重置", wipeMessage)
                    }
                }
                .font(DS.Font.caption)
                .padding(DS.Space.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )

                if cloudFiles.deleted > 0 {
                    Button {
                        showReclaimConfirm = true
                    } label: {
                        if isReclaiming {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text(localizationManager.localized("sync_reclaim_running"))
                            }
                        } else {
                            Text(localizationManager.localized("sync_reclaim"))
                        }
                    }
                    .font(DS.Font.caption)
                    .disabled(isReclaiming)
                    .accessibilityIdentifier("sync.reclaim")
                    .confirmationDialog(
                        localizationManager.localized("sync_reclaim"),
                        isPresented: $showReclaimConfirm,
                        titleVisibility: .visible
                    ) {
                        Button(localizationManager.localized("sync_reclaim")) {
                            Task { await runReclaim() }
                        }
                        Button(localizationManager.localized("cancel"), role: .cancel) {}
                    } message: {
                        Text(localizationManager.localized("sync_reclaim_confirm_body"))
                    }
                }

                Button(role: .destructive) {
                    showWipeConfirm = true
                } label: {
                    if isWiping {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text(localizationManager.localized("sync_reset_cloud_running"))
                        }
                    } else {
                        Text(localizationManager.localized("sync_reset_cloud"))
                    }
                }
                .font(DS.Font.caption)
                .disabled(isWiping)
                .accessibilityIdentifier("sync.reset_cloud")
                .confirmationDialog(
                    localizationManager.localized("sync_reset_cloud_confirm_title"),
                    isPresented: $showWipeConfirm,
                    titleVisibility: .visible
                ) {
                    Button(localizationManager.localized("sync_reset_cloud"), role: .destructive) {
                        Task { await runWipeCloud() }
                    }
                    Button(localizationManager.localized("cancel"), role: .cancel) {}
                } message: {
                    Text(localizationManager.localized("sync_reset_cloud_confirm_body"))
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(localizationManager.localized("hw_sync_status"))
                    .font(DS.Font.caption)
                    .foregroundColor(.secondary)
                ProgressView().controlSize(.small).padding(.vertical, DS.Space.s)
            }
        }
    }

    /// 回收已刪除筆記本留在雲端的檔案。  @MainActor
    private func runReclaim() async {
        isReclaiming = true
        defer { isReclaiming = false }
        wipeMessage = localizationManager.localized("sync_reclaim_running")
        guard let result = await CloudSync.reclaimDeleted() else {
            wipeMessage = localizationManager.localized("sync_reset_cloud_busy")
            return
        }
        if result.deleted == 0, result.failed == 0 {
            wipeMessage = localizationManager.localized("sync_reclaim_nothing")
        } else if result.ok {
            wipeMessage = localizationManager.localized("sync_reclaim_done")
                .replacingFirst("%1@", with: "\(result.deleted)")
        } else {
            wipeMessage = localizationManager.localized("sync_reclaim_partial")
                .replacingFirst("%1@", with: "\(result.deleted)")
                .replacingFirst("%2@", with: "\(result.failed)")
        }
    }

    /// 清空雲端，然後讓這台裝置把本機的內容整個重新上傳。
    ///
    /// **本機的筆記一個都不會動。** 清的只有雲端那一份與本機的遠端快照；
    /// 接下來那一輪同步會把這台裝置上的東西當成新的基準傳上去。
    @MainActor
    private func runWipeCloud() async {
        isWiping = true
        defer { isWiping = false }
        wipeMessage = localizationManager.localized("sync_reset_cloud_running")

        let result: FfiWipeResult?
        if selectedProvider == .folderOrICloud {
            result = CloudSyncFolder.wipeCloud()
        } else {
            result = await CloudSync.wipeCloud()
        }

        guard let res = result else {
            wipeMessage = localizationManager.localized("sync_reset_cloud_busy")
            return
        }
        if res.ok {
            wipeMessage = localizationManager.localized("sync_reset_cloud_done")
                .replacingFirst("%1@", with: "\(res.deleted)")
        } else {
            wipeMessage = localizationManager.localized("sync_reset_cloud_partial")
                .replacingFirst("%1@", with: "\(res.deleted)")
                .replacingFirst("%2@", with: "\(res.failed)")
        }
    }

    private func doctorRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label).foregroundColor(.secondary).frame(width: 84, alignment: .leading)
            Text(value).foregroundColor(.primary)
            Spacer(minLength: 0)
        }
    }

    /// 雲端每一個檔案的歸屬。純計算，零 HTTP。
    private var logSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack(spacing: 8) {
                Text(localizationManager.localized("sync_logs_title"))
                    .font(DS.Font.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Picker(localizationManager.localized("log_filter"), selection: $logFilter) {
                    Text(localizationManager.localized("log_filter_current")).tag(LogFilter.currentTab)
                    Text(localizationManager.localized("log_filter_all")).tag(LogFilter.all)
                    Text("Google Drive").tag(LogFilter.googleDrive)
                    Text("iCloud / " + localizationManager.localized("folder_name")).tag(LogFilter.folder)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 290)

                if !filteredLogEntries.isEmpty {
                    Button {
                        copySyncLogs()
                        copiedSyncLogs = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            copiedSyncLogs = false
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: copiedSyncLogs ? "checkmark" : "doc.on.doc")
                            Text(copiedSyncLogs ? localizationManager.localized("log_copied") : localizationManager.localized("log_copy"))
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(copiedSyncLogs ? .green : .indigo)
                    .animation(.easeInOut(duration: 0.2), value: copiedSyncLogs)
                    .help(localizationManager.localized("log_copy"))
                    .accessibilityLabel(localizationManager.localized("log_copy"))

                    Button {
                        exportSyncLogs()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "square.and.arrow.up")
                            Text(localizationManager.localized("log_export"))
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.indigo)
                    .help(localizationManager.localized("log_export"))
                    .accessibilityLabel(localizationManager.localized("log_export"))

                    Button(localizationManager.localized("log_clear")) {
                        switch logFilter {
                        case .currentTab:
                            if selectedProvider == .googleDrive {
                                syncLogger.clear(for: .googleDrive)
                            } else {
                                syncLogger.clear(for: .folder)
                            }
                        case .all:
                            syncLogger.clear()
                        case .googleDrive:
                            syncLogger.clear(for: .googleDrive)
                        case .folder:
                            syncLogger.clear(for: .folder)
                        }
                    }
                    .font(DS.Font.caption)
                    .foregroundColor(.indigo)
                }
            }

            if filteredLogEntries.isEmpty {
                Text(localizationManager.localized("log_empty"))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(DS.Radius.s)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(filteredLogEntries) { entry in
                                HStack(alignment: .top, spacing: 6) {
                                    Text(entry.timestamp, formatter: Self.logDateFormatter)
                                        .foregroundColor(.secondary)

                                    sourceBadge(entry.source)

                                    Text(entry.message)
                                        .foregroundColor(.primary)
                                }
                                .font(.system(size: 11, design: .monospaced))
                                .id(entry.id)
                            }
                        }
                        .padding(DS.Space.s)
                    }
                    .frame(height: 150)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(DS.Radius.s)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.s)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
                    .onChange(of: filteredLogEntries.count) { _ in
                        if let last = filteredLogEntries.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sourceBadge(_ source: SyncSource) -> some View {
        switch source {
        case .googleDrive:
            Text("Drive")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.indigo.opacity(0.15))
                .foregroundColor(.indigo)
                .cornerRadius(3)
        case .folder:
            Text("iCloud")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.teal.opacity(0.15))
                .foregroundColor(.teal)
                .cornerRadius(3)
        case .general:
            Text(localizationManager.localized("hw_system"))
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.secondary.opacity(0.15))
                .foregroundColor(.secondary)
                .cornerRadius(3)
        }
    }
}

// MARK: - 2. 單本筆記快照專屬獨立視窗

public struct NotebookSnapshotDetailSheet: View {
    @ObservedObject var localizationManager = LocalizationManager.shared
    @ObservedObject private var store = NotebookStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var snapshotMessage: String?
    @State private var exportURL: URL?
    @State private var creatingNotebookId: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    HStack(spacing: DS.Space.m) {
                        Image(systemName: "doc.zipper")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.purple)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(localizationManager.localized("backup_snapshot"))
                                .font(DS.Font.screenTitle)
                            Text(localizationManager.localized("backup_snapshot_desc"))
                                .font(DS.Font.cardTitle)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, DS.Space.s)

                    if let snapshotMessage {
                        Text(snapshotMessage)
                            .font(DS.Font.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: DS.Space.s) {
                        Text(localizationManager.localized("backup_snapshot_picker_title"))
                            .font(DS.Font.cardTitle)

                        ForEach(store.visibleNotebooks) { notebook in
                            Button {
                                createSnapshot(for: notebook)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "book.closed")
                                        .foregroundColor(.purple)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(notebook.displayTitle(localizationManager))
                                            .font(DS.Font.body)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Text("\(notebook.pageCount) \(localizationManager.localized("pages"))")
                                            .font(DS.Font.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if creatingNotebookId == notebook.id {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "square.and.arrow.up")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(DS.Space.m)
                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                                .cornerRadius(DS.Radius.m)
                            }
                            .buttonStyle(.plain)
                            .disabled(creatingNotebookId != nil)
                        }
                    }
                }
                .padding(DS.Space.m)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(localizationManager.localized("backup_snapshot"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized("close")) { dismiss() }
                }
            }
            .sheet(item: Binding(
                get: { exportURL.map { IdentifiableURL(url: $0) } },
                set: { exportURL = $0?.url }
            )) { item in
                DocumentExporter(url: item.url)
            }
        }
    }

    private func createSnapshot(for notebook: NotebookDocument) {
        guard creatingNotebookId == nil else { return }
        creatingNotebookId = notebook.id
        defer { creatingNotebookId = nil }

        do {
            let package = try NotebookSyncCoordinator.mirrorWorkingCopyIntoPackage(
                notebook, store: store, deviceId: NotebookMigration.deviceId
            )
            let filename = Self.safeFilename(notebook.displayTitle(localizationManager))
            let out = FileManager.default.temporaryDirectory
                .appending(path: "\(filename).padnote")
            try? FileManager.default.removeItem(at: out)
            try archiveNotebook(packageDir: package.path, outFile: out.path)
            exportURL = out
            snapshotMessage = localizationManager.localized("export_done")
                .replacingFirst("%@", with: out.lastPathComponent)
        } catch {
            snapshotMessage = localizationManager.localized("export_failed")
                .replacingFirst("%@", with: error.localizedDescription)
        }
    }

    private static func safeFilename(_ title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let cleaned = title.components(separatedBy: invalid).joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Kairumo" : cleaned
    }
}

// MARK: - 3. 建立備份檔專屬獨立視窗

public struct BackupCreateDetailSheet: View {
    @ObservedObject var localizationManager = LocalizationManager.shared
    @ObservedObject private var store = NotebookStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var backupMessage: String?
    @State private var shareBackupURL: URL?
    @State private var isCreating = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    // 頂部圖示與標題
                    HStack(spacing: DS.Space.m) {
                        Image(systemName: "externaldrive.badge.timemachine")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(localizationManager.localized("backup_create"))
                                .font(DS.Font.screenTitle)
                                .foregroundColor(.primary)

                            Text(localizationManager.localized("backup_create_desc"))
                                .font(DS.Font.cardTitle)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, DS.Space.s)

                    // 統計資訊卡
                    VStack(spacing: 0) {
                        detailRow(
                            title: localizationManager.localized("all_notebooks"),
                            value: "\(store.notebooks.count)"
                        )
                        Divider()
                        detailRow(
                            title: localizationManager.localized("recent_recordings"),
                            value: "\(store.recordings.count)"
                        )
                        Divider()
                        detailRow(
                            title: localizationManager.localized("storage_location"),
                            value: "Documents & App Settings"
                        )
                    }
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(DS.Radius.m)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.m)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )

                    if let backupMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(backupMessage)
                                .font(DS.Font.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, DS.Space.xs)
                    }

                    // 執行建立備份按鈕
                    Button {
                        createBackup()
                    } label: {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .padding(.trailing, 6)
                            } else {
                                Image(systemName: "arrow.down.doc.fill")
                            }
                            Text(localizationManager.localized("backup_create"))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(isCreating)

                    // 詳細操作指引與備份內容說明
                    VStack(alignment: .leading, spacing: DS.Space.m) {
                        Text(localizationManager.localized("backup_section"))
                            .font(DS.Font.cardTitle)
                            .foregroundColor(.primary)

                        guideBullet(
                            icon: "doc.zipper",
                            title: localizationManager.localized("backup_create"),
                            desc: localizationManager.localized("backup_explainer")
                        )

                        guideBullet(
                            icon: "shield.lefthalf.filled",
                            title: localizationManager.localized("backup_restore"),
                            desc: localizationManager.localized("backup_safety_note")
                        )

                        guideBullet(
                            icon: "square.and.arrow.up",
                            title: localizationManager.localized("storage_location"),
                            desc: localizationManager.localized("backup_created")
                                .replacingFirst("%1@", with: "...")
                                .replacingFirst("%2@", with: "...")
                        )
                    }
                    .padding(DS.Space.m)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(DS.Radius.m)
                }
                .padding(DS.Space.m)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(localizationManager.localized("backup_create"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized("close")) { dismiss() }
                }
            }
            .sheet(item: Binding(
                get: { shareBackupURL.map { IdentifiableURL(url: $0) } },
                set: { shareBackupURL = $0?.url }
            )) { item in
                DocumentExporter(url: item.url)
            }
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(DS.Font.body)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(DS.Font.body)
                .foregroundColor(.primary)
                .fontWeight(.medium)
        }
        .padding(DS.Space.m)
    }

    private func guideBullet(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Font.body)
                    .fontWeight(.semibold)
                Text(desc)
                    .font(DS.Font.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(5) // 替換 fixedSize：避免 CoreText 斷字字典 I/O (0x8BADF00D)
            }
        }
    }

    private func createBackup() {
        guard !isCreating else { return }
        isCreating = true
        defer { isCreating = false }

        do {
            let (url, info) = try BackupManager.createBackup(
                documentsDirectory: store.documentsDirectory
            )
            backupMessage = localizationManager.localized("backup_created")
                .replacingFirst("%1@", with: "\(info.fileCount)")
                .replacingFirst("%2@", with: ByteCountFormatter.string(
                    fromByteCount: Int64(info.totalBytes), countStyle: .file
                ))
            shareBackupURL = url
        } catch {
            backupMessage = error.localizedDescription
        }
    }
}

// MARK: - 3. 從備份復原專屬獨立視窗

public struct BackupRestoreDetailSheet: View {
    @ObservedObject var localizationManager = LocalizationManager.shared
    @ObservedObject private var store = NotebookStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var restoreMessage: String?
    @State private var showRestorePicker = false
    @State private var isRestoring = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    // 頂部圖示與標題
                    HStack(spacing: DS.Space.m) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.orange)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(localizationManager.localized("backup_restore"))
                                .font(DS.Font.screenTitle)
                                .foregroundColor(.primary)

                            Text(localizationManager.localized("backup_restore_desc"))
                                .font(DS.Font.cardTitle)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, DS.Space.s)

                    // 安全性保障提示
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.title2)
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(localizationManager.localized("backup_safety_note"))
                                .font(DS.Font.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Text(localizationManager.localized("backup_explainer"))
                                .font(DS.Font.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(DS.Space.m)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(DS.Radius.m)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.m)
                            .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                    )

                    if let restoreMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.orange)
                            Text(restoreMessage)
                                .font(DS.Font.caption)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, DS.Space.xs)
                    }

                    // 選擇備份檔復原按鈕
                    Button {
                        showRestorePicker = true
                    } label: {
                        HStack {
                            if isRestoring {
                                ProgressView()
                                    .padding(.trailing, 6)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text(localizationManager.localized("backup_restore"))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(isRestoring)

                    // 詳細步驟說明
                    VStack(alignment: .leading, spacing: DS.Space.m) {
                        Text(localizationManager.localized("backup_section"))
                            .font(DS.Font.cardTitle)
                            .foregroundColor(.primary)

                        stepRow(
                            step: "1",
                            title: localizationManager.localized("backup_restore"),
                            desc: localizationManager.localized("backup_restore_desc")
                        )

                        stepRow(
                            step: "2",
                            title: localizationManager.localized("backup_safety_note"),
                            desc: localizationManager.localized("backup_safety_note")
                        )

                        stepRow(
                            step: "3",
                            title: localizationManager.localized("app_version_info"),
                            desc: localizationManager.localized("backup_restored")
                                .replacingFirst("%@", with: "...")
                        )
                    }
                    .padding(DS.Space.m)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(DS.Radius.m)
                }
                .padding(DS.Space.m)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(localizationManager.localized("backup_restore"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized("close")) { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showRestorePicker,
                allowedContentTypes: [.data, .archive],
                allowsMultipleSelection: false
            ) { result in
                guard case let .success(urls) = result, let url = urls.first else { return }
                restore(from: url)
            }
        }
    }

    private func stepRow(step: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 26, height: 26)
                Text(step)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Font.body)
                    .fontWeight(.semibold)
                Text(desc)
                    .font(DS.Font.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(5) // 替換 fixedSize：避免 CoreText 斷字字典 I/O (0x8BADF00D)
            }
        }
    }

    private func restore(from url: URL) {
        guard !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }

        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            _ = try BackupManager.inspect(url)
            let outcome = try BackupManager.restore(
                from: url, into: store.documentsDirectory
            )
            store.loadData()

            var message = localizationManager.localized("backup_restored")
                .replacingFirst("%@", with: "\(outcome.restored)")
            if !outcome.corrupted.isEmpty {
                message += "　" + localizationManager.localized("backup_corrupted")
                    .replacingFirst("%@", with: "\(outcome.corrupted.count)")
            }
            restoreMessage = message
        } catch {
            restoreMessage = error.localizedDescription
        }
    }
}

/// 同步逾時保護。指定秒數內未完成就拋出 `CancellationError`。
/// 用於保護所有 Google Drive 同步的入口，確保 isSyncing 一定能回到 false。
private func withSyncTimeout<T: Sendable>(
    seconds: Double,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw CancellationError()
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

// MARK: - 4. 選擇同步資料夾專屬獨立視窗

public struct FolderSyncDetailSheet: View {
    public init() {}

    public var body: some View {
        CloudSyncDetailSheet(initialProvider: .folderOrICloud)
    }
}
