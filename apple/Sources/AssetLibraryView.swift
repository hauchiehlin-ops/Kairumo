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

    @State private var selectedCategory: AssetCategory = .all
    @State private var selectedSourceFilter: AssetSourceType? = nil
    @State private var searchText: String = ""
    @State private var viewingDetailItem: AssetItem? = nil
    @State private var showClearCacheAlert: Bool = false

    public init(onInsertToCanvas: ((UIImage, AssetItem) -> Void)? = nil) {
        self.onInsertToCanvas = onInsertToCanvas
    }

    private var filteredItems: [AssetItem] {
        libraryManager.items.filter { item in
            let matchesCategory = (selectedCategory == .all || item.category == selectedCategory)
            let matchesSource = (selectedSourceFilter == nil || item.sourceType == selectedSourceFilter)
            let matchesSearch = searchText.isEmpty ||
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.specsSummary.localizedCaseInsensitiveContains(searchText) ||
                item.materialSuggestion.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSource && matchesSearch
        }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. 頂部搜尋列
                searchAndFilterBar

                // 2. 主題類別橫向滑動標籤
                categoryFilterScrollView

                // 3. 快取容量與隨需下載管理列
                storageManagementBanner

                // 4. 素材卡片瀑布流網格
                ScrollView {
                    if filteredItems.isEmpty {
                        emptyStateView
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 14)], spacing: 14) {
                            ForEach(filteredItems) { item in
                                assetCardView(item: item)
                            }
                        }
                        .padding(16)
                    }
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
                Text("確定要清除所有本機素材快取以釋放硬碟空間嗎？已插入筆記中的內容不受影響。")
            }
            .sheet(item: $viewingDetailItem) { item in
                assetDetailSheet(item: item)
            }
        }
    }

    // MARK: - 1. 搜尋與型態過濾
    private var searchAndFilterBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜尋機構、3C、零件、規格...", text: $searchText)
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
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(10)

            // 實體規格 vs AI 概念切換
            Picker("", selection: $selectedSourceFilter) {
                Text("全部型態").tag(AssetSourceType?.none)
                Text(localizationManager.localized("filter_physical")).tag(AssetSourceType?.some(.physicalSpec))
                Text(localizationManager.localized("filter_ai")).tag(AssetSourceType?.some(.aiConcept))
            }
            .pickerStyle(.segmented)
            .frame(width: 250)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    // MARK: - 2. 主題類別橫向滑動列
    private var categoryFilterScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AssetCategory.allCases) { cat in
                    let isSelected = (selectedCategory == cat)
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = cat
                        }
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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.8))
    }

    // MARK: - 3. 快取容量與隨需下載管理列
    private var storageManagementBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "internaldrive")
                .foregroundColor(.accentColor)
                .font(.subheadline)

            let downloadedCount = libraryManager.items.filter { libraryManager.isDownloaded($0.id) }.count
            Text("已下載 \(downloadedCount) 項 (\(String(format: "%.1f", libraryManager.totalDownloadedSizeMB)) MB) / 雲端隨需 \(libraryManager.items.count - downloadedCount) 項")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button {
                libraryManager.downloadCategory(selectedCategory)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                    Text("下載本類全部")
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
    private func assetCardView(item: AssetItem) -> some View {
        let isDownloaded = libraryManager.isDownloaded(item.id)
        let isDownloading = libraryManager.downloadingItemIds.contains(item.id)

        return VStack(alignment: .leading, spacing: 8) {
            // 縮圖與預覽點擊區
            Button {
                viewingDetailItem = item
            } label: {
                ZStack(alignment: .topTrailing) {
                    let img = libraryManager.renderItemImage(for: item)
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
                Text(item.title)
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
                    Text("\(String(format: "%.1f", item.fileSizeMB)) MB")
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
                    Text("下載中...")
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
                            let img = libraryManager.renderItemImage(for: item)
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
                    let img = libraryManager.renderItemImage(for: item)
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(item.title)
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
                                Text("主要規格：")
                                    .fontWeight(.medium)
                                    .frame(width: 80, alignment: .leading)
                                Text(item.specsSummary)
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)

                            HStack(alignment: .top) {
                                Text("材質工藝：")
                                    .fontWeight(.medium)
                                    .frame(width: 80, alignment: .leading)
                                Text(item.materialSuggestion)
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)

                            HStack(alignment: .top) {
                                Text("參考尺寸：")
                                    .fontWeight(.medium)
                                    .frame(width: 80, alignment: .leading)
                                Text(item.dimensionsMm)
                                    .foregroundColor(.accentColor)
                            }
                            .font(.subheadline)

                            HStack(alignment: .top) {
                                Text("檔案大小：")
                                    .fontWeight(.medium)
                                    .frame(width: 80, alignment: .leading)
                                Text("\(String(format: "%.1f", item.fileSizeMB)) MB (向量高解析)")
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
                                    Text("移除本機快取")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(8)
                            }

                            if let onInsert = onInsertToCanvas {
                                Button {
                                    let img = libraryManager.renderItemImage(for: item)
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
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") {
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
            Text("未找到符合條件的素材")
                .font(.headline)
            Text("嘗試更換搜尋關鍵字或切換主題分類標籤")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
}
