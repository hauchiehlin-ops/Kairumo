//
//  EditorSidebars.swift
//  Kairumo
//
//  編輯器側邊欄：頁面縮圖結構清單與資料夾階層目錄
//

import SwiftUI
import PencilKit
import UniformTypeIdentifiers

// MARK: - 側邊欄縮圖獨立 View 結構（提供 SwiftUI Diff 邊界與算繪效能快取）

struct PageThumbnailCardView: View {
    let pageIndex: Int
    let isSelected: Bool
    let isSelectingPages: Bool
    let isPageSelected: Bool
    let isDropTarget: Bool
    let effectiveWidth: CGFloat
    let sidebarScale: CGFloat
    let pageDrawing: PKDrawing
    /// 這一頁手繪的版本號（`PageInkStore.revision`）。內容換了它就變，縮圖才會重畫。
    let inkRevision: Int
    let notebook: NotebookDocument
    let store: NotebookStore
    let canvasWidth: CGFloat
    let onTap: () -> Void
    let menuItems: AnyView
    let onDropReorder: (Int) -> Bool
    let onDropTargetChange: (Bool) -> Void

    var body: some View {
        Button(action: onTap) {
            let pageRatio = PageGeometry.width / max(1, PageGeometry.height)
            let img = PageThumbnailRenderer.render(
                notebook: notebook,
                pageIndex: pageIndex,
                drawing: pageDrawing,
                store: store,
                canvasWidth: canvasWidth,
                inkRevision: inkRevision,
                deferRecomputation: CanvasTouchState.isCanvasNavigating
            )
            Image(uiImage: img)
                .resizable()
                .aspectRatio(pageRatio, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2.5 : 1)
                )
                .shadow(color: Color.black.opacity(isSelected ? 0.15 : 0.04), radius: isSelected ? 4 : 2, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sidebar.page.\(pageIndex)")
        .frame(width: effectiveWidth)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        .cornerRadius(8)
        .overlay(alignment: .top) {
            if isDropTarget {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(height: 3)
                    .padding(.horizontal, 8)
            }
        }
        .contextMenu {
            menuItems
        }
        .draggable(PageDragPayload(index: pageIndex)) {
            Label("P.\(pageIndex + 1)", systemImage: "doc.on.doc")
                .font(.caption)
                .padding(8)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(8)
        }
        .dropDestination(for: PageDragPayload.self) { items, _ in
            guard let from = items.first?.index else { return false }
            return onDropReorder(from)
        } isTargeted: { hovering in
            onDropTargetChange(hovering)
        }
    }
}

// MARK: - 側欄與畫布之間的界線及目錄結構

extension NotebookEditorView {

    // MARK: - 側欄與畫布之間的界線
    //
    // 原本這裡是一條 1pt 的分隔線，側欄固定 280pt。280 對「翻頁找內容」
    // 剛好夠，對「看清楚這一頁畫了什麼」不夠 —— 而使用者沒有任何辦法
    // 調整它：畫面上唯一的操作是把整條側欄關掉。
    //
    // 界線改成可以拖。夾住兩端的規則在核心（`sidebarClampWidth`），
    // 因為「畫布至少要留 480」這條線兩個平台是同一條。

    /// 目前該用的側欄寬度：拖曳中用暫時值，否則用落盤值，兩者都要夾過。
    func resolvedSidebarWidth(total: CGFloat) -> CGFloat {
        let desired = draggingSidebarWidth ?? CGFloat(storedSidebarWidth)
        return CGFloat(sidebarClampWidth(desired: Float(desired), total: Float(total)))
    }

    /// 界線本身。視覺上是一條線，可以抓的範圍比線寬得多 ——
    /// 1pt 的命中區域在觸控上等於抓不到，在游標上等於要瞄準。
    func sidebarResizeHandle(total: CGFloat, current: CGFloat) -> some View {
        let isDragging = (draggingSidebarWidth != nil)
        return ZStack {
            Color(uiColor: .separator)
                .frame(width: 1)
            // 抓得到的提示：三顆點。沒有它，這條線看起來就只是一條線。
            Capsule()
                .fill(isDragging ? Color.accentColor : Color.secondary.opacity(0.35))
                .frame(width: 4, height: 34)
        }
        .frame(width: 10)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .background(isDragging ? Color.accentColor.opacity(0.12) : Color.clear)
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    draggingSidebarWidth = CGFloat(
                        sidebarClampWidth(desired: Float(current + value.translation.width),
                                          total: Float(total)))
                }
                .onEnded { value in
                    let final = CGFloat(
                        sidebarClampWidth(desired: Float(current + value.translation.width),
                                          total: Float(total)))
                    storedSidebarWidth = Double(final)
                    draggingSidebarWidth = nil
                }
        )
        // 連點兩下回到預設寬度。拖過頭之後要靠手拖回「原本那樣」很難，
        // 而「回到原本那樣」是使用者第二常想做的事。
        .onTapGesture(count: 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                storedSidebarWidth = 280
            }
        }
        .accessibilityLabel(localizationManager.localized("resize_sidebar"))
        .help(localizationManager.localized("resize_sidebar"))
    }

    /// 型別邊界：SwiftUI 會把整棵子樹的型別編進 body 的 mangled 名稱，
    /// 名稱一長，裝置端（主執行緒只有 1MB 堆疊）解析時就會遞迴爆堆疊。
    var notebookStructureSidebar: AnyView { AnyView(notebookStructureSidebarContent) }

    var notebookStructureSidebarContent: some View {
        VStack(spacing: 0) {
            // 頂部導覽列與分頁模式切換
            VStack(spacing: 8) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: sidebarTab == .pages ? "sidebar.left" : "folder.fill")
                            .foregroundColor(.accentColor)
                        Text(sidebarTab == .pages ? localizationManager.localized("structure_pages") : localizationManager.localized("structure_folders"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    Spacer()

                    if sidebarTab == .pages {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isSelectingPages.toggle()
                                if !isSelectingPages { pageSelection.removeAll() }
                            }
                        } label: {
                            Image(systemName: isSelectingPages
                                ? "checkmark.circle.fill" : "checkmark.circle")
                                .font(.system(size: 17))
                                .foregroundColor(.accentColor)
                                .frame(width: 30, height: 30)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(localizationManager.localized("select_pages"))
                        .help(localizationManager.localized("select_pages"))

                        Button {
                            addNewPage()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.accentColor)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(localizationManager.localized("add_page"))
                        .help(localizationManager.localized("add_page"))
                    } else {
                        Button {
                            newFolderParentId = nil
                            newFolderNameText = ""
                            showNewFolderAlert = true
                        } label: {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 16))
                                .foregroundColor(.accentColor)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(localizationManager.localized("new_subfolder"))
                        .help(localizationManager.localized("new_subfolder"))
                    }

                    Button {
                        withAnimation {
                            showStructureSidebar = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Picker("", selection: sidebarTabBinding) {
                    Text(localizationManager.localized("structure_pages"))
                        .tag(SidebarTabMode.pages)
                        .accessibilityIdentifier("editor.sidebar.tab.pages")
                    Text(localizationManager.localized("structure_folders"))
                        .tag(SidebarTabMode.folders)
                        .accessibilityIdentifier("editor.sidebar.tab.folders")
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(uiColor: .secondarySystemGroupedBackground))

            Divider()

            if sidebarTab == .pages {
                pagesStructureView
                    .accessibilityIdentifier("editor.sidebar.list")
            } else {
                foldersStructureView
                    .accessibilityIdentifier("editor.sidebar.list")
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    // MARK: - 頁面結構縮圖清單
    /// 型別邊界：SwiftUI 會把整棵子樹的型別編進 body 的 mangled 名稱，
    /// 名稱一長，裝置端（主執行緒只有 1MB 堆疊）解析時就會遞迴爆堆疊。
    var pagesStructureView: AnyView { AnyView(pagesStructureViewContent) }

    var pagesStructureViewContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(Array(0..<max(1, notebook.pageCount)), id: \.self) { idx in
                        pageStructureCard(idx: idx)
                    }

                    // 🌟 顯著的新增頁面大按鈕卡片
                    Button {
                        addNewPage()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                            Text(localizationManager.localized("add_page_large"))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor.opacity(0.08))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.accentColor.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                }
                .id(notebook.pageCount)
                .padding(.vertical, 8)
            }

            Divider()

            if isSelectingPages {
                pageSelectionBar
                Divider()
            }

            // 結構摘要統計與縮圖大小
            pagesStructureFooter
        }
        .sheet(isPresented: Binding(
            get: { transferIsCopy != nil },
            set: { if !$0 { transferIsCopy = nil } }
        )) {
            transferDestinationSheet
        }
    }

    /// 多選模式下的那一排操作。
    var pageSelectionBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text(
                    String(
                        format: localizationManager.localized("pages_selected"),
                        String(pageSelection.count))
                )
                .font(.system(size: 12 * sidebarScale))
                .foregroundColor(.secondary)

                Spacer()

                Button {
                    if pageSelection.count == notebook.pageCount {
                        pageSelection.removeAll()
                    } else {
                        pageSelection = Set(0..<max(1, notebook.pageCount))
                    }
                } label: {
                    Text(localizationManager.localized(
                        pageSelection.count == notebook.pageCount
                            ? "deselect_all" : "select_all"))
                        .font(.system(size: 12))
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }

            HStack(spacing: 8) {
                Button {
                    transferIsCopy = true
                } label: {
                    Label(
                        localizationManager.localized("copy_to"),
                        systemImage: "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.accentColor.opacity(0.12))
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(pageSelection.isEmpty)

                Button {
                    transferIsCopy = false
                } label: {
                    Label(
                        localizationManager.localized("move_to"),
                        systemImage: "arrow.right.doc.on.clipboard")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.accentColor.opacity(0.12))
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(pageSelection.isEmpty || pageSelection.count >= notebook.pageCount)
            }
            .foregroundColor(.accentColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    /// 目的筆記本選擇器。
    var transferDestinationSheet: some View {
        let isCopy = (transferIsCopy ?? true)
        return NavigationView {
            List {
                Section {
                    ForEach(store.visibleNotebooks) { target in
                        let isSelf = (target.id == notebook.id)
                        Button {
                            performTransfer(to: target, copy: isCopy)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: isSelf ? "doc.fill" : "doc.plaintext")
                                    .foregroundColor(isSelf ? .accentColor : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(target.displayTitle())
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Text("\(target.pageCount) \(localizationManager.localized("pages_count_suffix"))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if isSelf {
                                    Text(localizationManager.localized("current_notebook"))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!isCopy && isSelf)
                        .opacity(!isCopy && isSelf ? 0.4 : 1)
                    }
                } header: {
                    Text(localizationManager.localized(
                        isCopy ? "copy_pages_to_title" : "move_pages_to_title"))
                } footer: {
                    Text(
                        String(
                            format: localizationManager.localized("pages_selected"),
                            String(pageSelection.count))
                    )
                }
            }
            .navigationTitle(localizationManager.localized("choose_destination_notebook"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) { transferIsCopy = nil }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    /// 執行轉移，然後把畫面收拾乾淨。
    func performTransfer(to target: NotebookDocument, copy: Bool) {
        let pages = pageSelection.sorted()
        let selected = Set(pages)
        transferIsCopy = nil
        isSelectingPages = false
        pageSelection.removeAll()

        let sameNotebook = target.id == notebook.id
        let pageMap = { (page: Int) -> Int? in
            guard !copy, !sameNotebook else { return page }
            if selected.contains(page) { return nil }
            return page - pages.filter { $0 < page }.count
        }
        var moved = 0
        changePageStructure(pageMap: pageMap) {
            moved = store.transferPages(
                from: notebook.id, pageIndexes: pages, to: target.id, move: !copy)
            guard moved > 0 else {
                showCanvasNotice(localizationManager.localized("transfer_failed"))
                return nil
            }
            showCanvasNotice(
                String(
                    format: localizationManager.localized(copy ? "pages_copied" : "pages_moved"),
                    String(moved), target.displayTitle())
            )
            return pageMap(currentPageIndex)
                ?? (currentPageIndex - pages.filter { $0 < currentPageIndex }.count)
        }
    }

    /// 單一頁面卡片。
    func pageStructureCard(idx: Int) -> some View {
        let isSelected = (idx == currentPageIndex)
        return VStack(spacing: 4) {
            HStack {
                if isSelectingPages {
                    Image(systemName: pageSelection.contains(idx)
                        ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundColor(pageSelection.contains(idx) ? .accentColor : .secondary)
                }

                Text("P.\(idx + 1)")
                    .font(.system(size: 12 * sidebarScale))
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundColor(isSelected ? .accentColor : .primary)

                Spacer()

                Menu {
                    pageActionMenuItems(idx: idx)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)

            thumbnailCard(for: idx)
        }
        .padding(.vertical, 4)
    }

    /// 縮圖卡片：使用獨立的 PageThumbnailCardView，隔離渲染區域並避免主執行緒阻塞
    func thumbnailCard(for idx: Int) -> some View {
        let isSelected = (idx == currentPageIndex)
        let isDropTarget = (dropTargetPageIndex == idx)
        return PageThumbnailCardView(
            pageIndex: idx,
            isSelected: isSelected,
            isSelectingPages: isSelectingPages,
            isPageSelected: pageSelection.contains(idx),
            isDropTarget: isDropTarget,
            effectiveWidth: effectiveThumbnailWidth,
            sidebarScale: sidebarScale,
            pageDrawing: drawingForPage(idx),
            inkRevision: inkRevisionForPage(idx),
            notebook: notebook,
            store: store,
            canvasWidth: canvasContentWidth,
            onTap: {
                if isSelectingPages {
                    if pageSelection.contains(idx) {
                        pageSelection.remove(idx)
                    } else {
                        pageSelection.insert(idx)
                    }
                    return
                }
                if currentPageIndex != idx {
                    switchToPage(idx)
                } else if pageDisplayMode == .continuous {
                    continuousScrollRequest += 1
                }
            },
            menuItems: AnyView(pageActionMenuItems(idx: idx)),
            onDropReorder: { from in
                dropTargetPageIndex = nil
                return reorderPage(from: from, to: idx)
            },
            onDropTargetChange: { hovering in
                dropTargetPageIndex = hovering ? idx : (dropTargetPageIndex == idx ? nil : dropTargetPageIndex)
            }
        )
    }

    /// 一頁能做的事。右上角的選單與右鍵快顯共用同一份
    @ViewBuilder
    func pageActionMenuItems(idx: Int) -> some View {
        Button {
            insertPageAfter(idx)
        } label: {
            Label(localizationManager.localized("insert_page_after"), systemImage: "plus.square")
        }

        Menu {
            ForEach(Array(paperThemes().enumerated()), id: \.offset) { _, theme in
                Menu {
                    ForEach(paperTemplatesForTheme(theme: theme), id: \.id) { paper in
                        Button {
                            insertPageAfter(idx, paperId: paper.id)
                        } label: {
                            Label(
                                localizationManager.localized(paper.titleKey),
                                systemImage: paper.iconApple)
                        }
                    }
                } label: {
                    Label(
                        localizationManager.localized(paperThemeKey(theme: theme)),
                        systemImage: paperThemeIcons(theme: theme).first ?? "doc.text")
                }
            }
        } label: {
            Label(
                localizationManager.localized("insert_page_with_template"),
                systemImage: "rectangle.stack.badge.plus")
        }

        Button {
            duplicatePage(at: idx)
        } label: {
            Label(localizationManager.localized("duplicate_page"), systemImage: "plus.square.on.square")
        }

        ToolbarSeparator()

        Button {
            pageSelection = [idx]
            isSelectingPages = true
            transferIsCopy = true
        } label: {
            Label(localizationManager.localized("copy_to_notebook"), systemImage: "doc.on.doc")
        }

        if notebook.pageCount > 1 {
            Button {
                pageSelection = [idx]
                isSelectingPages = true
                transferIsCopy = false
            } label: {
                Label(
                    localizationManager.localized("move_to_notebook"),
                    systemImage: "arrow.right.doc.on.clipboard")
            }
        }

        if notebook.pageCount > 1 {
            ToolbarSeparator()

            Button {
                _ = reorderPage(from: idx, to: idx - 1)
            } label: {
                Label(localizationManager.localized("move_page_up"), systemImage: "arrow.up")
            }
            .disabled(idx == 0)

            Button {
                _ = reorderPage(from: idx, to: idx + 1)
            } label: {
                Label(localizationManager.localized("move_page_down"), systemImage: "arrow.down")
            }
            .disabled(idx >= notebook.pageCount - 1)

            Button {
                _ = reorderPage(from: idx, to: 0)
            } label: {
                Label(localizationManager.localized("move_page_to_top"), systemImage: "arrow.up.to.line")
            }
            .disabled(idx == 0)

            Button {
                _ = reorderPage(from: idx, to: notebook.pageCount - 1)
            } label: {
                Label(localizationManager.localized("move_page_to_bottom"), systemImage: "arrow.down.to.line")
            }
            .disabled(idx >= notebook.pageCount - 1)

            ToolbarSeparator()
            Button(role: .destructive) {
                presentFromMenu {
                    pageToDeleteIndex = idx
                    showDeletePageAlert = true
                }
            } label: {
                Label(localizationManager.localized("delete_page"), systemImage: "trash")
            }
        }
    }

    /// 側欄底部：統計與縮圖大小。
    var pagesStructureFooter: some View {
        HStack(spacing: 8) {
            Text("\(localizationManager.localized("all_pages")): \(notebook.pageCount)")
                .font(.system(size: 11 * sidebarScale))
                .foregroundColor(.secondary)

            Spacer(minLength: 4)

            Button {
                pageThumbnailWidth = max(120, pageThumbnailWidth - 40)
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 13))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(pageThumbnailWidth <= 120)
            .accessibilityLabel(localizationManager.localized("thumbnail_smaller"))
            .help(localizationManager.localized("thumbnail_smaller"))
            .accessibilityIdentifier("editor.sidebar.thumb_smaller")

            Text("\(Int(effectiveThumbnailWidth))")
                .font(.system(size: 10))
                .monospacedDigit()
                .foregroundColor(.secondary)

            Button {
                pageThumbnailWidth = min(480, pageThumbnailWidth + 40)
                if pageThumbnailWidth + 32 > storedSidebarWidth {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        storedSidebarWidth = pageThumbnailWidth + 32
                    }
                }
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 13))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(pageThumbnailWidth >= 480)
            .accessibilityLabel(localizationManager.localized("thumbnail_larger"))
            .help(localizationManager.localized("thumbnail_larger"))
            .accessibilityIdentifier("editor.sidebar.thumb_larger")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    /// 把一頁搬到另一個位置。
    @discardableResult
    func reorderPage(from: Int, to: Int) -> Bool {
        let total = notebook.pageCount
        guard pageMoveIsValid(count: UInt32(max(0, total)),
                              from: UInt32(max(0, from)),
                              to: UInt32(max(0, min(to, max(0, total - 1)))))
        else { return false }
        let target = min(max(0, to), total - 1)

        changePageStructure(pageMap: { page in
            Int(pageIndexAfterMove(index: UInt32(max(0, page)), from: UInt32(from), to: UInt32(target)))
        }) {
            guard pageMoveIsValid(count: UInt32(max(0, notebook.pageCount)),
                                  from: UInt32(max(0, from)),
                                  to: UInt32(max(0, target)))
            else { return nil }
            let landed = store.movePage(notebookId: notebook.id, from: from, to: target)
            if currentPageIndex == from { return landed }
            return Int(pageIndexAfterMove(index: UInt32(max(0, currentPageIndex)),
                                          from: UInt32(from), to: UInt32(target)))
        }
        return true
    }

    /// 頁面結構變動（新增、插入、複製、刪除、搬動）的共用流程。
    func changePageStructure(pageMap explicitMap: ((Int) -> Int?)? = nil, _ change: @escaping () -> Int?) {
        saveCurrentPageDrawing()
        afterCoreInkWrites {
            activeInkStore.flushDirtyPages(notebook: notebook)
            if pageOrigins == nil, let snapshot = initialNotebookSnapshot {
                for page in 0..<min(notebook.pageCount, snapshot.pageCount) {
                    captureInitialPageState(
                        page: page, drawing: store.loadDrawing(notebookId: notebook.id, pageIndex: page))
                }
                pageOrigins = (0..<notebook.pageCount).map { $0 < snapshot.pageCount ? $0 : nil }
            }
            let idsBefore = notebook.pageIds
            let countBefore = notebook.pageCount
            guard let landing = change() else { return }
            let idsAfter = store.notebooks.first(where: { $0.id == notebook.id })?.pageIds
            let pageMap: (Int) -> Int? = explicitMap ?? { page in
                guard let before = idsBefore, page < before.count, let after = idsAfter else { return nil }
                return after.firstIndex(of: before[page])
            }

            continuousCanvases.invalidateCachedDrawings()
            if let origins = pageOrigins {
                let countAfter = store.notebooks.first(where: { $0.id == notebook.id })?.pageCount ?? countBefore
                var next = [Int?](repeating: nil, count: countAfter)
                for page in 0..<countBefore {
                    guard let moved = pageMap(page), moved < countAfter else { continue }
                    next[moved] = page < origins.count ? origins[page] : nil
                }
                pageOrigins = next
            }

            if let updated = store.notebooks.first(where: { $0.id == notebook.id }) {
                notebook = updated
            }
            currentPageIndex = min(max(0, landing), max(0, notebook.pageCount - 1)) // state-entry: 頁面結構變更 landing 頁碼
            objectHistory.pageStructureChanged(notebook, manager: historyUndoManager)
            loadCurrentPage()
            (canvasView as? AdaptiveCanvasView)?.proLayer?.reload()
            continuousReloadGeneration += 1
            thumbnailRevision += 1
            if pageDisplayMode == .continuous {
                continuousProgrammaticScrollUntil = Date().addingTimeInterval(1.0)
                continuousScrollRequest += 1
            }
        }
    }

    /// 側欄目前的實際寬度。與版面那一層畫出來的是同一個算式。
    var currentSidebarWidth: CGFloat {
        resolvedSidebarWidth(total: editorAvailableWidth)
    }

    /// 側欄內字級的倍率。規則在核心（`sidebarContentScale`），
    var sidebarScale: CGFloat {
        CGFloat(sidebarContentScale(width: Float(currentSidebarWidth)))
    }

    /// 縮圖實際會畫多寬：使用者要的寬度，被側欄目前的內寬夾住。
    var effectiveThumbnailWidth: CGFloat {
        min(CGFloat(pageThumbnailWidth), max(80, currentSidebarWidth - 32))
    }

    // MARK: - 資料夾階層結構目錄
    var foldersStructureView: AnyView { AnyView(foldersStructureViewContent) }

    var foldersStructureViewContent: some View {
        VStack(spacing: 0) {
            // 最上層根資料夾標題（可自訂與重命名）
            HStack(spacing: 8) {
                Image(systemName: "tray.2.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.displayRootFolderName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(localizationManager.localized("root_folder"))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    rootFolderRenameText = store.displayRootFolderName
                    showRenameRootFolderAlert = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 17))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizationManager.localized("edit_root_folder"))
                .help(localizationManager.localized("edit_root_folder"))
            }
            .padding(8)
            .background(
                isRootDropTargeted
                    ? Color.accentColor.opacity(0.22)
                    : Color(uiColor: .tertiarySystemGroupedBackground)
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: isRootDropTargeted ? 2 : 0)
            )
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .dropDestination(for: String.self) { items, _ in
                guard let noteId = items.first else { return false }
                store.moveNotebook(id: noteId, toFolderId: nil)
                return true
            } isTargeted: { isRootDropTargeted = $0 }

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    // 最上層子資料夾
                    ForEach(store.folders.filter { $0.parentId == nil }) { folder in
                        folderRowView(folder: folder, level: 0)
                    }

                    let rootNotes = store.notebooks(in: nil)
                    Group {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Image(systemName: "tray.fill")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(localizationManager.localized("unfiled_notes"))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(rootNotes.count)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, 10)
                            .padding(.top, 8)
                            .padding(.vertical, 4)

                            if rootNotes.isEmpty {
                                Text(localizationManager.localized("drop_here_to_unfile"))
                                    .font(.system(size: 10 * sidebarScale))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.3),
                                                    style: StrokeStyle(lineWidth: 1, dash: [4]))
                                    )
                                    .padding(.horizontal, 10)
                            } else {
                                ForEach(rootNotes) { note in
                                    notebookItemRow(note: note, indent: 8)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .background(isUnfiledDropTargeted ? Color.accentColor.opacity(0.18) : Color.clear)
                        .cornerRadius(6)
                        .dropDestination(for: String.self) { items, _ in
                            guard let noteId = items.first else { return false }
                            store.moveNotebook(id: noteId, toFolderId: nil)
                            return true
                        } isTargeted: { isUnfiledDropTargeted = $0 }
                    }
                }
                .padding(.vertical, 6)
            }

            Divider()

            Text(
                String(
                    format: localizationManager.localized("structure_summary"),
                    String(store.folders.count), String(store.visibleNotebooks.count))
            )
            .font(DS.Font.caption)
            .foregroundStyle(DS.Color.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Space.s)
            .padding(.vertical, DS.Space.xs)
        }
    }

    // 單一資料夾列視圖（支援遞迴子資料夾與展開）
    func folderRowView(folder: FolderItem, level: Int) -> AnyView {
        let isExpanded = expandedFolderIds.contains(folder.id)
        let subfolders = store.subfolders(of: folder.id)
        let folderNotes = store.notebooks(in: folder.id)

        return AnyView(
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isExpanded {
                                expandedFolderIds.remove(folder.id)
                            } else {
                                expandedFolderIds.insert(folder.id)
                            }
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)

                    Image(systemName: isExpanded ? "folder.fill" : "folder")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 13))

                    Text(folder.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Spacer()

                    Text("\(folderNotes.count)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .clipShape(Capsule())

                    Menu {
                        Button {
                            presentFromMenu {
                                newFolderParentId = folder.id
                                newFolderNameText = ""
                                showNewFolderAlert = true
                            }
                        } label: {
                            Label(localizationManager.localized("new_subfolder"), systemImage: "folder.badge.plus")
                        }

                        Button {
                            let created = store.createNotebook(
                                title: localizationManager.localized("new_notebook"),
                                template: notebook.template,
                                folderId: folder.id
                            )
                            switchToNotebook(created)
                        } label: {
                            Label(localizationManager.localized("add_note_to_folder"), systemImage: "plus.square")
                        }

                        Button {
                            presentFromMenu {
                                folderRenameText = folder.displayName
                                folderToRename = folder
                            }
                        } label: {
                            Label(localizationManager.localized("rename_folder"), systemImage: "pencil")
                        }

                        ToolbarSeparator()

                        Button(role: .destructive) {
                            store.deleteFolder(id: folder.id)
                        } label: {
                            Label(localizationManager.localized("delete_folder"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, CGFloat(level * 14 + 6))
                .padding(.trailing, 8)
                .padding(.vertical, 4)
                .background(
                    (dropTargetFolderId == folder.id ? Color.accentColor.opacity(0.22)
                                                     : Color(uiColor: .tertiarySystemGroupedBackground).opacity(0.5))
                )
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor, lineWidth: dropTargetFolderId == folder.id ? 2 : 0)
                )
                .dropDestination(for: String.self) { items, _ in
                    guard let noteId = items.first else { return false }
                    store.moveNotebook(id: noteId, toFolderId: folder.id)
                    expandedFolderIds.insert(folder.id)
                    return true
                } isTargeted: { hovering in
                    dropTargetFolderId = hovering ? folder.id : (dropTargetFolderId == folder.id ? nil : dropTargetFolderId)
                }

                if isExpanded {
                    ForEach(subfolders) { sub in
                        folderRowView(folder: sub, level: level + 1)
                    }

                    ForEach(folderNotes) { note in
                        notebookItemRow(note: note, indent: CGFloat((level + 1) * 14 + 6))
                    }
                }
            }
            .padding(.horizontal, 6)
        )
    }

    // 單一筆記檔案列視圖（支援快速點選切換編輯）
    @ViewBuilder
    func notebookItemRow(note: NotebookDocument, indent: CGFloat) -> some View {
        let isCurrent = (note.id == notebook.id)
        HStack(spacing: 6) {
            Image(systemName: isCurrent ? "doc.fill" : "doc.plaintext")
                .foregroundColor(isCurrent ? .accentColor : .secondary)
                .font(.system(size: 12))

            VStack(alignment: .leading, spacing: 1) {
                Text(note.displayTitle())
                    .font(.caption)
                    .fontWeight(isCurrent ? .bold : .regular)
                    .foregroundColor(isCurrent ? .accentColor : .primary)
                    .lineLimit(1)
                Text("\(note.pageCount) \(localizationManager.localized("pages_count_suffix"))")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isCurrent {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
            }

            Menu {
                if note.folderId != nil {
                    Button {
                        store.moveNotebook(id: note.id, toFolderId: nil)
                    } label: {
                        Label(localizationManager.localized("move_out_of_folder"), systemImage: "arrow.up.left.square")
                    }
                }

                Button {
                    notebookToMoveId = note.id
                    showMoveNotebookSheet = true
                } label: {
                    Label(localizationManager.localized("move_to_folder"), systemImage: "folder")
                }

                Button {
                    renameText = note.title
                    showRenameAlert = true
                } label: {
                    Label(localizationManager.localized("rename_note"), systemImage: "pencil")
                }

                ToolbarSeparator()

                Button(role: .destructive) {
                    store.deleteNotebook(id: note.id)
                    if note.id == notebook.id {
                        if let first = store.notebooks.first {
                            switchToNotebook(first)
                        } else {
                            let created = store.createNotebook(title: localizationManager.localized("untitled_note"), template: .blank)
                            switchToNotebook(created)
                        }
                    }
                } label: {
                    Label(localizationManager.localized("delete"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(3)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, indent)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .background(isCurrent ? Color.accentColor.opacity(0.12) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture {
            switchToNotebook(note)
        }
        .dropDestination(for: String.self) { items, _ in
            guard let draggedId = items.first, draggedId != note.id else { return false }
            store.moveNotebook(id: draggedId, toFolderId: note.folderId)
            return true
        } isTargeted: { hovering in
            let key = note.folderId ?? unfiledDropKey
            if hovering {
                dropTargetFolderId = key
            } else if dropTargetFolderId == key {
                dropTargetFolderId = nil
            }
        }
        .contextMenu {
            if note.folderId != nil {
                Button {
                    store.moveNotebook(id: note.id, toFolderId: nil)
                } label: {
                    Label(localizationManager.localized("move_out_of_folder"), systemImage: "arrow.up.left.square")
                }
            }
            Button {
                notebookToMoveId = note.id
                showMoveNotebookSheet = true
            } label: {
                Label(localizationManager.localized("move_to_folder"), systemImage: "folder")
            }
            Button {
                renameText = note.title
                showRenameAlert = true
            } label: {
                Label(localizationManager.localized("rename_note"), systemImage: "pencil")
            }
        }
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
