//
//  AssetLibraryView.swift
//  Kairumo
//
//  三大主題實體素材圖庫瀏覽器與隨需下載管理視圖
//  支援依機構/3C/汽車/家具/五金/數位分類篩選、實體規格圖/AI概念切換
//  支援單項隨需下載、整類下載、清除快取與一鍵插入至筆記畫布
//

import SwiftUI

public struct AssetLibraryView: View {
    @ObservedObject var libraryManager = AssetLibraryManager.shared
    @ObservedObject var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    var onInsertToCanvas: ((UIImage, AssetItem) -> Void)?

    /// 卡片預覽與插入畫布使用的算繪樣式。
    /// 預設實物 —— 貼進筆記本的多半希望是個物件，而不是一張工程圖紙。
    @AppStorage("kairumo.assetRenderStyle") private var renderStyleRaw: String =
        AssetLibraryManager.AssetRenderStyle.solid.rawValue

    private var renderStyle: AssetLibraryManager.AssetRenderStyle {
        AssetLibraryManager.AssetRenderStyle(rawValue: renderStyleRaw) ?? .solid
    }

    @State private var selectedTheme: NoteThemeCategory? = nil
    @State private var selectedCategory: AssetCategory = .all
    @State private var selectedSourceFilter: AssetSourceType? = nil
    @State private var searchText: String = ""
    @State private var viewingDetailItem: AssetItem? = nil
    @State private var showClearCacheAlert: Bool = false

    public init(onInsertToCanvas: ((UIImage, AssetItem) -> Void)? = nil) {
        self.onInsertToCanvas = onInsertToCanvas
    }

    /// 根據所選主題過濾次級分類標籤
    private var availableCategories: [AssetCategory] {
        if let theme = selectedTheme {
            return [.all] + AssetCategory.allCases.filter { $0 != .all && $0.themeCategory == theme }
        } else {
            return AssetCategory.allCases
        }
    }

    private var filteredItems: [AssetItem] {
        libraryManager.items.filter { item in
            let matchesTheme: Bool
            if let theme = selectedTheme {
                matchesTheme = (item.category.themeCategory == theme)
            } else {
                matchesTheme = true
            }

            let matchesCategory = (selectedCategory == .all || item.category == selectedCategory)
            let matchesSource = (selectedSourceFilter == nil || item.sourceType == selectedSourceFilter)
            let title = assetTitle(for: item)
            let matchesSearch = searchText.isEmpty ||
                title.localizedCaseInsensitiveContains(searchText) ||
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.specsSummary.localizedCaseInsensitiveContains(searchText) ||
                item.materialSuggestion.localizedCaseInsensitiveContains(searchText)
            return matchesTheme && matchesCategory && matchesSource && matchesSearch
        }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. 頂部搜尋列與來源型態過濾（自適應寬窄螢幕）
                searchAndFilterBar

                // 2. 三大主題主標籤篩選列（全部、美學視覺、工程製程、數位體驗）
                themeFilterBar

                // 3. 次級主題類別橫向滑動標籤
                categoryFilterScrollView

                // 4. 快取容量與隨需下載管理列
                storageManagementBanner

                // 5. 素材卡片瀑布流自適應網格
                GeometryReader { proxy in
                    ScrollView {
                        if filteredItems.isEmpty {
                            emptyStateView
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 280), spacing: 14)], spacing: 14) {
                                ForEach(filteredItems) { item in
                                    assetCardView(item: item)
                                }
                            }
                            .padding(14)
                        }
                    }
                    .frame(width: proxy.size.width, alignment: .topLeading)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(localizationManager.localized("asset_library"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            libraryManager.downloadCategory(selectedCategory)
                        } label: {
                            Label(localizationManager.localized("download_all"), systemImage: "arrow.down.circle")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showClearCacheAlert = true
                        } label: {
                            Label(localizationManager.localized("clear_cache"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert(localizationManager.localized("clear_cache"), isPresented: $showClearCacheAlert) {
                Button(localizationManager.localized("cancel"), role: .cancel) {}
                Button(localizationManager.localized("clear_cache"), role: .destructive) {
                    libraryManager.clearAllCache()
                }
            } message: {
                Text(localizationManager.localized("clear_cache_confirm"))
            }
            .sheet(item: $viewingDetailItem) { item in resizableSheet {
                assetDetailSheet(item: item)
            } }
        }
    }

    private func assetTitle(for item: AssetItem) -> String {
        let key = "asset_\(item.id)_title"
        let localized = localizationManager.localized(key)
        return localized == key ? item.title : localized
    }

    // MARK: - 1. 搜尋與型態過濾（響應式 ViewThatFits）
    private var searchAndFilterBar: some View {
        ViewThatFits(in: .horizontal) {
            // 寬螢幕水平排列
            HStack(spacing: 10) {
                searchFieldView
                sourceFilterPicker.frame(width: 240)
                renderStylePicker.frame(width: 150)
            }
            // 中等寬度：搜尋獨立一行
            VStack(spacing: 8) {
                searchFieldView
                HStack(spacing: 10) {
                    sourceFilterPicker
                    renderStylePicker.frame(width: 150)
                }
            }
            // 窄螢幕垂直分行
            VStack(spacing: 8) {
                searchFieldView
                sourceFilterPicker
                renderStylePicker
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private var searchFieldView: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(localizationManager.localized("search_assets_placeholder"), text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .cornerRadius(10)
    }

    /// 線框 / 實物 顯示樣式切換
    private var renderStylePicker: some View {
        Picker("", selection: $renderStyleRaw) {
            Text(localizationManager.localized("style_blueprint"))
                .tag(AssetLibraryManager.AssetRenderStyle.blueprint.rawValue)
            Text(localizationManager.localized("style_solid"))
                .tag(AssetLibraryManager.AssetRenderStyle.solid.rawValue)
        }
        .pickerStyle(.segmented)
    }

    private var sourceFilterPicker: some View {
        Picker("", selection: $selectedSourceFilter) {
            Text(localizationManager.localized("all_asset_types")).tag(AssetSourceType?.none)
            Text(localizationManager.localized("filter_physical")).tag(AssetSourceType?.some(.physicalSpec))
            Text(localizationManager.localized("filter_ai")).tag(AssetSourceType?.some(.aiConcept))
        }
        .pickerStyle(.segmented)
    }

    // MARK: - 2. 三大主題主標籤篩選列
    private var themeFilterBar: some View {
        // **不能維持單行。**
        //
        // 原本這裡寫著「只有四個主題，任何寬度都放得下」—— 在 iPad 上成立，
        // 在 iPhone 上不成立：四顆帶文字的膠囊擠不進 390 點，SwiftUI 會把
        // 每個 Text 壓到最小寬度，於是「All Themes」變成一欄一個字母的直排
        // （實機看過）。換行版面（工具列與新增筆記本用的同一個 `WrapLayout`）
        // 讓它在窄螢幕上折行，寬螢幕仍然是一行。
        WrapLayout(spacing: 8, lineSpacing: 6) {
                // 全部主題
                themeChip(theme: nil, title: localizationManager.localized("all_themes"), icon: "square.grid.2x2")

                // 美學視覺
                themeChip(theme: .aesthetic, title: localizationManager.localized("theme_aesthetic"), icon: "paintpalette.fill")

                // 工程製程
                themeChip(theme: .engineering, title: localizationManager.localized("theme_engineering"), icon: "wrench.and.screwdriver.fill")

                // 數位體驗
                themeChip(theme: .digital, title: localizationManager.localized("theme_digital"), icon: "iphone.gen3")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.95))
        .overlay(Divider(), alignment: .bottom)
    }

    private func themeChip(theme: NoteThemeCategory?, title: String, icon: String) -> some View {
        let isSelected = (selectedTheme == theme)
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTheme = theme
                // 若當前次分類不屬於新主題，重置為 .all
                if let theme = theme, selectedCategory != .all, selectedCategory.themeCategory != theme {
                    selectedCategory = .all
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .medium)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 2. 主題類別橫向滑動列
    /// 主分類列上直接顯示的數量。其餘收進「更多」選單。
    private let visibleCategoryCount = 5

    /// 列上顯示的分類。
    ///
    /// 目前選取的分類一定會出現在列上 —— 若它落在溢位區而被藏進選單，
    /// 使用者會看不出自己正在篩什麼。
    private var primaryCategories: [AssetCategory] {
        let all = availableCategories
        var shown = Array(all.prefix(visibleCategoryCount))
        if !shown.contains(selectedCategory), all.contains(selectedCategory) {
            shown[shown.count - 1] = selectedCategory
        }
        return shown
    }

    private var overflowCategories: [AssetCategory] {
        availableCategories.filter { !primaryCategories.contains($0) }
    }

    // MARK: - 2. 主題類別列（次要分類收進「更多」）
    private var categoryFilterScrollView: some View {
        // 同上：窄螢幕要折行，不然分類名稱會被壓成直排。
        WrapLayout(spacing: 8, lineSpacing: 6) {
            ForEach(primaryCategories) { cat in
                categoryChip(cat)
            }

            if !overflowCategories.isEmpty {
                Menu {
                    ForEach(overflowCategories) { cat in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = cat }
                        } label: {
                            Label(localizationManager.localized(cat.localizationKey), systemImage: cat.iconName)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .semibold))
                        Text(localizationManager.localized("more_tools"))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(20)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.8))
    }

    private func categoryChip(_ cat: AssetCategory) -> some View {
        let isSelected = (selectedCategory == cat)
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = cat }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: cat.iconName)
                    .font(.system(size: 13, weight: .semibold))
                Text(localizationManager.localized(cat.localizationKey))
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color.accentColor : Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 3. 快取容量與隨需下載管理列
    private var storageManagementBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "internaldrive")
                .foregroundColor(.accentColor)
                .font(.subheadline)

            let downloadedCount = libraryManager.items.filter { libraryManager.isDownloaded($0.id) }.count
            Text("\(localizationManager.localized("downloaded")) \(downloadedCount) (\(String(format: "%.1f", libraryManager.totalDownloadedSizeMB)) MB) / \(libraryManager.items.count - downloadedCount)")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button {
                libraryManager.downloadCategory(selectedCategory)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                    Text(localizationManager.localized("download_all_category"))
                }
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.12))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.06))
    }

    // MARK: - 4. 單一素材卡片
    /// 容量標示：已落盤回報真實檔案大小，未落盤的預估值加上 `~`。
    private func sizeLabel(for item: AssetItem) -> String {
        if let real = libraryManager.cachedSizeMB(for: item.id) {
            return String(format: "%.1f MB", real)
        }
        return String(format: "~%.1f MB", item.fileSizeMB)
    }

    private func assetCardView(item: AssetItem) -> some View {
        let isDownloaded = libraryManager.isDownloaded(item.id)
        let isDownloading = libraryManager.downloadingItemIds.contains(item.id)

        return VStack(alignment: .leading, spacing: 8) {
            // 縮圖與預覽點擊區
            Button {
                viewingDetailItem = item
            } label: {
                ZStack(alignment: .topTrailing) {
                    let img = libraryManager.renderItemImage(for: item, style: renderStyle)
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 160)
                        .clipped()
                        .cornerRadius(8)

                    // 標籤徽章 (實體 vs AI)
                    HStack(spacing: 4) {
                        Image(systemName: item.sourceType.iconName)
                            .font(.system(size: 9))
                        Text(localizationManager.localized(item.sourceType.localizationKey))
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(item.sourceType == .physicalSpec ? Color.blue.opacity(0.85) : Color.purple.opacity(0.85))
                    .cornerRadius(4)
                    .padding(8)
                }
            }
            .buttonStyle(.plain)

            // 標題與規格簡介
            VStack(alignment: .leading, spacing: 3) {
                Text(assetTitle(for: item))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(item.specsSummary)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .frame(height: 28, alignment: .topLeading)

                HStack {
                    Text(item.dimensionsMm)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.accentColor)
                    Spacer()
                    // 已落盤的顯示真實檔案大小；未落盤的是預估值，用 ~ 標示出來。
                    Text(sizeLabel(for: item))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // 動作按鈕列
            HStack(spacing: 6) {
                if isDownloading {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(localizationManager.localized("downloading"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                } else if isDownloaded {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption2)
                        Text(localizationManager.localized("downloaded"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // 若提供畫布回調，顯示「插入畫布」按鈕
                    if let onInsert = onInsertToCanvas {
                        Button {
                            // 插入畫布一律用透明底，才不會在筆記頁上壓出一塊白方框。
                            let img = libraryManager.renderItemImage(
                                for: item,
                                style: renderStyle,
                                transparent: true
                            )
                            onInsert(img, item)
                            dismiss()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "plus.square.fill")
                                Text(localizationManager.localized("insert_to_canvas"))
                            }
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    // 未下載：顯示「下載」按鈕
                    Button {
                        libraryManager.downloadItem(id: item.id)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.down.circle")
                            Text(localizationManager.localized("download_item"))
                        }
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - 5. 詳細規格彈窗 (Detail Sheet)
    private func assetDetailSheet(item: AssetItem) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    let img = libraryManager.renderItemImage(for: item, style: renderStyle)
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(assetTitle(for: item))
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: item.sourceType.iconName)
                                Text(localizationManager.localized(item.sourceType.localizationKey))
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(item.sourceType == .physicalSpec ? Color.blue : Color.purple)
                            .cornerRadius(6)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(localizationManager.localized("specs_info"))
                                .font(.headline)

                            HStack(alignment: .top) {
                                Text(localizationManager.localized("spec_specs"))
                                    .fontWeight(.medium)
                                    .frame(width: 80, alignment: .leading)
                                Text(item.specsSummary)
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)

                            HStack(alignment: .top) {
                                Text(localizationManager.localized("spec_materials"))
                                    .fontWeight(.medium)
                                    .frame(width: 80, alignment: .leading)
                                Text(item.materialSuggestion)
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)

                            HStack(alignment: .top) {
                                Text(localizationManager.localized("spec_dimensions"))
                                    .fontWeight(.medium)
                                    .frame(width: 80, alignment: .leading)
                                Text(item.dimensionsMm)
                                    .foregroundColor(.accentColor)
                            }
                            .font(.subheadline)

                            HStack(alignment: .top) {
                                Text(localizationManager.localized("spec_filesize"))
                                    .fontWeight(.medium)
                                    .frame(width: 80, alignment: .leading)
                                Text(sizeLabel(for: item))
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)
                        }
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(10)
                    }

                    Spacer(minLength: 20)

                    // 底部主要操作
                    HStack(spacing: 12) {
                        if libraryManager.isDownloaded(item.id) {
                            Button(role: .destructive) {
                                libraryManager.removeItem(id: item.id)
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text(localizationManager.localized("remove_cache"))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(8)
                            }

                            if let onInsert = onInsertToCanvas {
                                Button {
                                    let img = libraryManager.renderItemImage(
                                        for: item,
                                        style: renderStyle,
                                        transparent: true
                                    )
                                    onInsert(img, item)
                                    viewingDetailItem = nil
                                    dismiss()
                                } label: {
                                    HStack {
                                        Image(systemName: "plus.square.fill")
                                        Text(localizationManager.localized("insert_to_canvas"))
                                    }
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                            }
                        } else {
                            Button {
                                libraryManager.downloadItem(id: item.id)
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text(localizationManager.localized("download_item"))
                                }
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(assetTitle(for: item))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("close")) {
                        viewingDetailItem = nil
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 40)
            Image(systemName: "square.stack.3d.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(localizationManager.localized("no_assets_found"))
                .font(.headline)
            Text(localizationManager.localized("no_assets_hint"))
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
}
