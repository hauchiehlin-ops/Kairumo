//
//  EditorCanvasContainer.swift
//  Kairumo
//
//  編輯器畫布容器、Word文件紙張視圖、連續模式與單頁縮放視圖
//

import SwiftUI
import PencilKit
import UniformTypeIdentifiers

// MARK: - 畫布容器與頁面渲染視圖擴充

extension NotebookEditorView {
    // MARK: - 3-1. 🌟 Office Word / Google Docs 居中標準文件紙張編輯區
    var wordDocumentArea: AnyView {
        AnyView(wordDocumentAreaContent)
    }

    var wordDocumentAreaContent: some View {
        WordDocumentEditorView(
            notebook: $notebook,
            pageIndex: currentPageIndex,
            activeTextDraft: Binding(
                get: { activeTextAttachment ?? NoteTextAttachment(pageIndex: currentPageIndex) },
                set: { updated in
                    if notebook.textAttachments == nil { notebook.textAttachments = [] }
                    if let idx = notebook.textAttachments?.firstIndex(where: { $0.id == updated.id }) {
                        notebook.textAttachments?[idx] = updated
                    } else {
                        notebook.textAttachments?.append(updated)
                    }
                    commitNotebook()
                    PageThumbnailRenderer.invalidateAll()
                }
            ),
            activeInlineInkBlockId: $activeInlineInkBlockId,
            onCommit: {
                commitNotebook()
                PageThumbnailRenderer.invalidateAll()
            },
            onInsertTable: {
                let table = NoteTableAttachment(pageIndex: currentPageIndex, x: 40, y: 120, rows: 3, cols: 3)
                if notebook.tableAttachments == nil { notebook.tableAttachments = [] }
                notebook.tableAttachments?.append(table)
                activeSelectedObjectId = table.id
                selectedObjectIds = [table.id]
                commitNotebook()
                PageThumbnailRenderer.invalidateAll()
                if let data = try? JSONEncoder().encode(table),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    collaborationManager.broadcastAttachmentUpsert(type: "table", itemDict: dict)
                }
            },
            onInsertImage: { showPhotoPicker = true },
            onInsertImageFile: { triggerFileImport(.image) },
            onPasteClipboardImage: { pasteScreenshotOrClipboardImage() }
        )
    }

    /// 飛梭工具盤的中心：長按叫出的放在落點（往內收，整圈都要在畫面裡），
    /// 工具列按鈕叫出的放在畫面中央。
    func radialMenuCenter(in geo: GeometryProxy) -> CGPoint {
        let size = geo.size
        guard let anchor = radialMenuAnchor else {
            return CGPoint(x: size.width / 2, y: min(size.height / 2, max(170, size.height * 0.42)))
        }
        let frame = geo.frame(in: .global)
        let margin: CGFloat = 160  // 半徑 118 + 按鈕半徑 36 + 一點邊
        let local = CGPoint(x: anchor.x - frame.minX, y: anchor.y - frame.minY)
        return CGPoint(
            x: min(max(local.x, margin), max(margin, size.width - margin)),
            y: min(max(local.y, margin), max(margin, size.height - margin)))
    }

    /// 畫布上長按（筆尖或單指落下停住不動）叫出飛梭工具盤。
    ///
    /// 飛梭的意義就在「不用把手移到工具列」：手在哪裡，工具盤就開在哪裡。
    /// 正在拖曳套索選取、打字或行內編輯時不攔，讓原本的操作繼續。
    func openRadialMenuFromPress(at windowPoint: CGPoint) -> Bool {
        guard isCanvasInkActive, editorMode == .draw, !showRadialMenu else { return false }
        if selectedTool == .lasso && (lasso.isDraggingSelection || lasso.hasSelection) { return false }
        if selectedTool == .maskingTape { return false }
        radialMenuAnchor = windowPoint
        withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
            showRadialMenu = true
        }
        return true
    }

    /// 飛梭工具盤的一格被選中。選工具走 `selectEditorTool` —— 與工具列、⌘1… 快捷鍵同一條路，
    /// 切到製圖筆時的提示、離開套索時清掉選取等副作用才不會在這裡漏掉。
    func performRadialAction(_ action: FfiRadialAction) {
        // 正在編修文字方塊時，螢光筆的意思是「標示這段字」：套文字醒目提示（與工具列同一條路、
        // 同一個上次用的顏色），不換成手繪螢光筆 —— 否則畫下去的是一道墨水，蓋在字上卻不屬於那個方塊。
        if action.editorTool == .highlighter, effectiveToolbarMode == .type, activeTextAttachment != nil {
            applyToolbarHighlight(ProfileDefaults.current.string(forKey: "kairumo.word.lastHighlight") ?? "#FFFF00")
            return
        }
        if let tool = action.editorTool {
            selectEditorTool(tool)
            return
        }
        switch action {
        case .undo: performUndo()
        case .redo: performRedo()
        case .color:
            // 色相環是掛在工具列按鈕上的 popover，從這裡開不一定有錨點；改開完整調色面板。
            showProColorPicker = true
        case .stabilizer: strokeStabilizer = (strokeStabilizer > 0) ? 0.0 : 0.5
        case .toggleMode: transitionToMode((editorMode == .draw) ? .type : .draw)
        default: break
        }
    }

    /// 徑向飛輪快捷工具盤（螢幕座標，不隨頁面縮放，蓋在畫布之上）。
    @ViewBuilder
    var radialMenuLayer: some View {
        if showRadialMenu {
            GeometryReader { geo in
                RadialMarkMenuView(
                    isPresented: $showRadialMenu,
                    centerPoint: radialMenuCenter(in: geo),
                    // 槽位是使用者自訂的（設定 → 自訂工具列 → 飛梭工具盤），規則與 Android 同一份在核心。
                    items: toolbarSettings.radialActions.map { action in
                        RadialMenuItem(
                            id: action.parityIdentifier,
                            icon: action.symbol, labelKey: action.labelKey, color: action.tint
                        ) { performRadialAction(action) }
                    }
                )
            }
            .transition(.opacity)
        }
    }

    /// 畫布工作區。抽出來並加上 AnyView 邊界 —— 這一塊（畫布 + 附件圖層 +
    /// 圖釘 + 浮動列）原本整棵樹的型別都被編進 body 的 mangled 名稱裡。
    var canvasWorkArea: AnyView {
        // 兩條完全獨立的路。連續模式不碰整頁模式的任何一行 ——
        // 那一段綁著存檔、協同、掌拒與套索，是最沒本錢壞掉的地方。
        let canvas: AnyView = switch pageDisplayMode {
        case .single:     AnyView(singlePageWorkArea)
        case .continuous: AnyView(continuousPagesContent)
        }
        // **提示條掛在兩種模式共用的這一層。**
        //
        // 它原本只長在 `singlePageWorkArea` 裡，於是連續模式下
        // `showCanvasNotice(...)` 等於什麼都沒做 —— 而那正是它要補的那個洞
        // （失敗時沒有任何回饋）。「有時候會提示、有時候不會」比一直沒提示
        // 更難查。
        return AnyView(
            ZStack(alignment: .bottom) {
                placed(canvas)
                if let notice = canvasNotice {
                    canvasNoticeBanner(notice)
                }
            }
            .overlay { objectEditPanels }
            .overlay(alignment: .top) {
                // 🌟 草圖智慧修飾浮動控制面板（兩種頁面模式共用）
                if showSketchRefineBar {
                    sketchRefineFloatingBar
                        .padding(.top, 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            .sheet(isPresented: $showDraftingToolbox) {
                DraftingToolbox(
                    notebookId: notebook.id,
                    frameSupported: frameSupportedForCurrentPage,
                    onPickTool: { tool in
                        // 鏡射、陣列要處理套索選的那批線：在離開套索之前把它帶過來。
                        if tool.needsSelection {
                            guard !lasso.proIds.isEmpty else {
                                showCanvasNotice(localizationManager.localized("draft_edit_need_selection"))
                                return
                            }
                            DraftingState.shared.editSelection = lasso.proIds
                        }
                        applyEditorTool(.drafting)
                        DraftingState.shared.tool = tool
                        DraftToolController.shared.reset(layer: (canvasView as? AdaptiveCanvasView)?.proLayer)
                        DraftToolController.shared.refreshHint()
                    },
                    onInsertSymbol: { insertDraftKit($0) },
                    onInsertFrame: { insertDraftFrame(thirdAngle: $0) },
                    onPlaceInstrument: { kind in
                        applyEditorTool(.drafting)
                        let center = draftViewportCenter()
                        DraftingState.shared.placeInstrument(kind: kind, center: center, pageWidth: PageGeometry.size.width)
                    },
                    onRectArray: { rows, cols, dx, dy in applyRectArray(rows: rows, cols: cols, dxMm: dx, dyMm: dy) },
                    onStartPractice: { startPractice(kind: $0) },
                    onExport: { exportDrafting(format: $0) })
            }
            .sheet(item: $draftExportShare) { item in
                ShareItemsSheet(items: [item.url])
            }
            .sheet(isPresented: $showSolidStudio) {
                SolidStudioSheet(
                    pageSize: PageGeometry.size,
                    sketchPolylines: { solidSketchPolylines() },
                    onInsert: { insertSolidSheet($0) })
            }
            .overlay(alignment: .bottomLeading) {
                // 練習題進行中：題目、選項、批改結果（見 DraftingPractice.swift）。
                let isDraftingPaper = paperUsesDrafting(paperId: notebook.paperId(forPage: currentPageIndex))
                if editorMode == .draw && (selectedTool == .drafting || isDraftingPaper) {
                    PracticeCard(
                        layer: { (canvasView as? AdaptiveCanvasView)?.proLayer },
                        onNew: {
                            if let kind = PracticeSession.shared.problem?.kind { startPractice(kind: kind) }
                        })
                        .padding(12)
                }
            }
            // 圖學：製圖筆組、圖層、吸附（見 DraftingBar.swift）。
            //
            // **佔用版面，不是浮在畫布上。** 原本是 `.overlay`，列疊在頁面最上方，
            // 蓋住頁首標題與題目文字（圖學頁一開頭就是標題）。改成 `safeAreaInset`：
            // 畫布整個往下讓出位置，收合或展開都不會壓到頁面內容。
            // 在圖學專用紙張中保持列位穩定，切換一般畫筆寫筆記時不會突然收合引發整個畫布抖動重繪與觸控延遲。
            .safeAreaInset(edge: .top, spacing: 0) {
                let isDraftingPaper = paperUsesDrafting(paperId: notebook.paperId(forPage: currentPageIndex))
                if editorMode == .draw && (selectedTool == .drafting || isDraftingPaper) {
                    DraftingBar(onOpenSolidStudio: { showSolidStudio = true },
                                onOpenToolbox: { showDraftingToolbox = true },
                                onMarkAngle: { markProtractorReading() })
                        .padding(.top, 8)
                        .padding(.bottom, 6)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .onAppear {
                DispatchQueue.main.async {
                    if knownObjectIds == nil { knownObjectIds = Set(allObjectIds) }
                }
            }
            .onChange(of: allObjectIds.count) { _ in
                DispatchQueue.main.async {
                    placeNewObjectsOnTop()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
                if let frame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
                    withAnimation(.easeOut(duration: 0.25)) {
                        keyboardHeight = frame.height
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = 0
                }
            }
        )
    }

    /// 把工具列貼到畫布的哪一邊（S-261b）。
    ///
    /// 「上」由 `body` 的 VStack 畫（它要排在頂部工作列底下），
    /// 這裡只處理左／右／下與收合。分兩處看起來不漂亮，但合併的代價是
    /// 把整個頂部區塊搬進畫布層 —— 那會動到尺規列、播放列與錄音列的順序。
    ///
    /// 收合（`.collapsed`）時完全不畫：那時使用者要的就是只剩浮動工具丸。
    @ViewBuilder
    func placed(_ canvas: AnyView) -> some View {
        if effectiveToolbarMode != .draw || isMinimalistCanvasActive {
            canvas
        } else {
            switch toolbarSettings.placement {
            case .top, .collapsed:
                canvas
            case .bottom:
                VStack(spacing: 0) {
                    canvas
                    drawingToolbar
                }
            case .left:
                HStack(spacing: 0) {
                    // 直向工具列要能捲 —— 十三顆按鈕在 iPhone 橫放時
                    // 高度不夠，不給捲的話下面幾顆永遠點不到。
                    ScrollView(.vertical) { drawingToolbar }
                        .frame(maxWidth: 96)
                    canvas
                }
            case .right:
                HStack(spacing: 0) {
                    canvas
                    ScrollView(.vertical) { drawingToolbar }
                        .frame(maxWidth: 96)
                }
            }
        }
    }

    /// 整頁模式：**一頁完整顯示，而且置中。**
    ///
    /// # 原本是什麼樣子
    ///
    /// 畫布直接把可用寬度吃滿（`AdaptiveCanvasView.syncContentSize` 用的是
    /// `bounds.width`），而頁面本身只有 800pt。於是右邊多出一塊空白 ——
    /// 那塊空白**在頁面框線之外**，寫上去的東西不會出現在列印結果裡。
    /// 把左側資料夾欄收起來之後那塊空白更大，看起來像畫布破了一個洞。
    ///
    /// 連續模式一直是「縮到剛好放得下」，整頁模式沒跟上。現在兩邊同一套：
    /// 放不下就等比縮小，放得下就放大填滿（有上限）並置中。
    ///
    /// 視窗寬就放大到填滿可用寬度（上限見 `PageViewportLayout.maxFitScale`）。
    var singlePageWorkArea: some View {
        GeometryReader { outer in
            let availableWidth = max(outer.size.width - 32, 1)
            let availableHeight = max(outer.size.height - 32, 1)
            let widthScale = PageViewportLayout.scale(
                availableWidth: availableWidth,
                pageWidth: PageGeometry.width
            )
            let fitPageScale = min(widthScale, availableHeight / PageGeometry.height)
            let baseScale = (singlePageFitMode == .fitPage) ? fitPageScale : widthScale
            let effectiveScale = max(0.3, min(4.0, baseScale * singlePageManualZoom))
            let scaledW = PageGeometry.width * effectiveScale
            let scaledH = PageGeometry.height * effectiveScale

            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                ScaledPageLayout(scale: effectiveScale, unscaledSize: CGSize(width: PageGeometry.width, height: PageGeometry.height)) {
                    canvasWorkAreaContent
                        .frame(width: PageGeometry.width, height: PageGeometry.height)
                        .clipped()
                        .scaleEffect(effectiveScale, anchor: .topLeading)
                }
                .padding(.bottom, inlineEditingTextId != nil ? keyboardHeight : 0)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("editor.canvas")
                .frame(
                    minWidth: outer.size.width,
                    minHeight: outer.size.height,
                    alignment: .top
                )
            }
            .frame(width: outer.size.width, height: outer.size.height)
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { mag in
                        let base = singlePagePinchBaseZoom ?? singlePageManualZoom
                        if singlePagePinchBaseZoom == nil { singlePagePinchBaseZoom = base }
                        singlePageManualZoom = max(0.3, min(4.0, base * mag))
                    }
                    .onEnded { _ in
                        singlePagePinchBaseZoom = nil
                    }
            )
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 6) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            singlePageManualZoom = max(0.4, singlePageManualZoom - 0.15)
                        }
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            singlePageManualZoom = 1.0
                            singlePageFitMode = (singlePageFitMode == .fitPage) ? .fitWidth : .fitPage
                        }
                    } label: {
                        Text(localizationManager.localized(
                            singlePageFitMode == .fitPage ? "zoom_fit_page" : "zoom_fit_width"))
                            .font(.system(size: 11, weight: .bold))
                            .frame(minWidth: 28)
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            singlePageManualZoom = min(3.0, singlePageManualZoom + 0.15)
                        }
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }
    }

    // 次世代 UI/UX Phase 5: 立起模式觸控工作盤 (Tabletop Studio Control Deck)
    var tabletopControlDeck: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                // 1. 頂部狀態標題與收折按鈕
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "laptopcomputer.and.ipad")
                            .foregroundColor(.accentColor)
                        Text(L("posture_tabletop_mode"))
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isTabletopMode = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // 2. 常用工具快速點選盤 (Pen / Highlighter / Eraser / Lasso / Radial / Magnetic / Sticky)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: 10) {
                    // 鋼筆
                    Button {
                        selectEditorTool(.pen)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "pencil.tip")
                                .font(.system(size: 20))
                            Text(L("tool_pen"))
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(selectedTool == .pen ? Color.accentColor.opacity(0.18) : Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedTool == .pen ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // 螢光筆
                    Button {
                        selectEditorTool(.highlighter)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "highlighter")
                                .font(.system(size: 20))
                            Text(L("tool_highlighter"))
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(selectedTool == .highlighter ? Color.accentColor.opacity(0.18) : Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedTool == .highlighter ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // 橡皮擦
                    Button {
                        selectEditorTool(.eraser)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "eraser")
                                .font(.system(size: 20))
                            Text(L("tool_eraser"))
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(selectedTool == .eraser ? Color.accentColor.opacity(0.18) : Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedTool == .eraser ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // 套索工具
                    Button {
                        selectEditorTool(.lasso)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: selectedTool == .lasso ? "xmark.circle.fill" : "lasso")
                                .font(.system(size: 20))
                            Text(L("tool_lasso"))
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(selectedTool == .lasso ? Color.accentColor.opacity(0.18) : Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedTool == .lasso ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // 徑向飛輪工具盤喚醒 (Radial Menu)
                    Button {
                        radialMenuAnchor = nil
                        showRadialMenu = true
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "circle.grid.cross")
                                .font(.system(size: 20))
                                .foregroundColor(.purple)
                            Text(L10n.t("tool_radial_short"))
                                .font(.caption2)
                                .foregroundColor(.purple)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.purple.opacity(0.12))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    // 幾何角度磁吸開關 (Magnetic Snap)
                    Button {
                        isMagneticSnapActive.toggle()
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: isMagneticSnapActive ? "magnet.fill" : "magnet")
                                .font(.system(size: 20))
                                .foregroundColor(isMagneticSnapActive ? .blue : .secondary)
                            Text(L("magnetic_snap_ruler"))
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(isMagneticSnapActive ? Color.blue.opacity(0.18) : Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    // 筆跡文字流式錨定 (Sticky Anchor)
                    Button {
                        anchorSelectedStrokesToNearestText()
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "link.badge.plus")
                                .font(.system(size: 20))
                                .foregroundColor(.orange)
                            Text(L("sticky_anchor_ink"))
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                // 3. 常用顏色調色板與復原/重做/翻頁
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        ForEach([Color.black, Color.blue, Color.red, Color.green, Color.orange, Color.purple], id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Button { performUndo() } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Button { performRedo() } label: {
                            Image(systemName: "arrow.uturn.forward")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Button { addNewPage() } label: {
                            Image(systemName: "plus.square.dashed")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.accentColor)
                                .frame(width: 36, height: 36)
                                .background(Color.accentColor.opacity(0.15))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 20)
        }
    }

    /// 畫布底部的提示條。
    ///
    /// 用浮動提示而不是 alert：使用者正在寫字，跳一個要按確定的對話框
    /// 會把筆打斷，而這件事沒有嚴重到值得打斷。
    func canvasNoticeBanner(_ text: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.accentColor)
            Text(text)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .allowsHitTesting(false)
        // 測試要認得這條提示 —— 「失敗時有沒有出聲」本身就是要守的行為。
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("editor.notice")
    }

    /// 連續頁面模式的工作區。
    var continuousPagesContent: some View {
        GeometryReader { outer in
            // 頁面是固定的 800 × 1132（P-01），視窗不是。縮到剛好放得下，
            // 不縮的話側欄一開，頁面右半邊就被切掉 —— 而使用者看不出那是
            // 「超出去」還是「畫布壞了」。
            //
            // 視窗比紙張寬就放大到填滿（上限見 `PageViewportLayout.maxFitScale`），
            // 不留兩片灰邊讓畫布看起來被框住。
            let available = max(outer.size.width - 32, 1)
            let fitWidth = PageViewportLayout.scale(
                availableWidth: available, pageWidth: PageGeometry.width)
            let viewport = CGSize(width: available, height: max(outer.size.height - 40, 1))
            let pageSize = CGSize(width: PageGeometry.width, height: currentPageHeight)
            let scale = continuousZoomTarget.map { target -> CGFloat in
                if case .ratio(let value) = target {
                    // 與單頁模式一致：倍率相對於「整頁剛好放進視窗」。
                    let whole = PageViewportLayout.zoomScale(for: .fitPage, viewport: viewport, page: pageSize)
                    return min(max(whole * value, 0.3), 4)
                }
                return PageViewportLayout.zoomScale(for: target, viewport: viewport, page: pageSize)
            } ?? fitWidth
            continuousPages(scale: scale)
                .onAppear {
                    DispatchQueue.main.async { continuousScale = scale }
                }
                .onChange(of: scale) { newScale in
                    DispatchQueue.main.async { continuousScale = newScale }
                }
        }
    }


    /// 整頁的顯示比例。單頁模式沿用既有的 `singlePageFitMode` / `singlePageManualZoom`（畫布右下角的 −／全頁／＋
    /// 也是它們），連續模式用 `continuousZoomTarget`。倍率一律**相對於「整頁剛好放進視窗」**：100% = 全頁。
    /// 捏合縮放（看某個區域）是另一件事，這裡一併歸位，才不會「選了全頁卻還停在放大的位置」。
    func applyEditorZoom(_ target: PageViewportLayout.ZoomTarget) {
        if pageDisplayMode == .continuous {
            continuousZoomTarget = target
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            switch target {
            case .fitPage:
                singlePageFitMode = .fitPage
                singlePageManualZoom = 1
            case .fitWidth:
                singlePageFitMode = .fitWidth
                singlePageManualZoom = 1
            case .ratio(let value):
                singlePageFitMode = .fitPage
                singlePageManualZoom = min(max(value, 0.4), 3)
            }
        }
        (canvasView as? AdaptiveCanvasView)?.applyPageZoom(.ratio(1))
    }

    /// 畫布區的「顯示比例」選單：顯示全頁、符合頁寬、實際大小與常用倍率。
    var zoomMenu: some View {
        Menu {
            Button {
                applyEditorZoom(.fitPage)
            } label: {
                Label(localizationManager.localized("zoom_fit_page"), systemImage: "arrow.up.left.and.down.right.magnifyingglass")
            }
            .accessibilityIdentifier("editor.zoom.fit_page")
            Button {
                applyEditorZoom(.fitWidth)
            } label: {
                Label(localizationManager.localized("zoom_fit_width"), systemImage: "arrow.left.and.right")
            }
            .accessibilityIdentifier("editor.zoom.fit_width")
            Divider()
            ForEach([50, 75, 125, 150, 200], id: \.self) { percent in
                Button("\(percent)%") { applyEditorZoom(.ratio(CGFloat(percent) / 100)) }
            }
        } label: {
            Image(systemName: "plus.magnifyingglass")
                .font(.system(size: EditorToolbarMetrics.icon - 3))
                .foregroundColor(.secondary)
                .frame(width: 24, height: 28)
        }
        .help(localizationManager.localized("zoom_menu"))
        .accessibilityLabel(localizationManager.localized("zoom_menu"))
        .accessibilityIdentifier("editor.zoom.menu")
    }

    static let continuousPageSpacing: CGFloat = 20

    @ViewBuilder
    func continuousPages(scale: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: Self.continuousPageSpacing) {
                    ForEach(0..<max(1, notebook.pageCount), id: \.self) { index in
                        ScaledPageLayout(scale: scale, unscaledSize: CGSize(width: PageGeometry.width, height: PageGeometry.height)) {
                            ContinuousPageView(
                                pageIndex: index,
                                notebookId: notebook.id,
                                paperId: notebook.paperId(forPage: index),
                                paletteId: notebook.guidePaletteId,
                                store: store,
                                selectedTool: selectedTool,
                                selectedColor: selectedColor,
                                strokeWidth: strokeWidth,
                                isRulerActive: isRulerActive,
                                editorMode: editorMode,
                                eraserMode: eraserMode,
                                pixelEraserWidth: pixelEraserWidth,
                                palmRejection: palmRejection,
                                isObjectActive: isObjectInteractionActive,
                                isFocused: index == currentPageIndex,
                                objectLayer: { objectLayer(forPage: index) },
                                underInkObjectLayer: { AnyView(objectLayer(forPage: index, filter: .underInkOnly)) },
                                overInkObjectLayer: { AnyView(objectLayer(forPage: index, filter: .overInkOnly)) },
                                isUnderInkPointPassThrough: { point, page, event in
                                    isUnderInkPointPassThrough(point: point, page: page, event: event)
                                },
                                onDrawingChanged: { page, updated in
                                    objectHistory.breakCoalescing()
                                    recordDrawingEdit(page: page, drawing: updated)
                                    broadcastDrawingChange(page: page, drawing: updated)
                                },
                                onSelectionChanged: { if !$0 { lasso.clear() } },
                                onReachedPageBottom: { ensureNextPageExists() },
                                // LazyVStack 會建立多頁畫布；不能讓最後建立的頁面覆蓋
                                // `canvasView`，否則貼紙可能蓋到別頁且存檔頁碼也錯。
                                canvasRef: { ref in
                                    continuousCanvases[index] = ref
                                    if index == currentPageIndex {
                                        continuousCanvases.activeCanvas = ref
                                    }
                                    // 同上：不在畫面更新途中改 @State，且只在真的換了才寫。
                                    guard index == currentPageIndex, canvasView !== ref else { return }
                                    DispatchQueue.main.async { canvasView = ref }
                                },
                                onCanvasTap: { location in
                                    focusContinuousPage(index)
                                    handleCanvasDirectTap(at: location, page: index)
                                },
                                onCanvasDoubleTap: { location in
                                    focusContinuousPage(index)
                                    handleCanvasDirectDoubleTap(at: location, page: index)
                                },
                                onPencilTouchBegan: {
                                    focusContinuousPage(index)
                                    handlePencilTouchBegan()
                                },
                                onPenControl: applyPenControl,
                                onImageDropped: { page, providers, location in
                                    acceptImageDrop(providers, at: location, page: page)
                                },
                                onInitialLoaded: { page, loaded in
                                    DispatchQueue.main.async {
                                        let pid = (notebook.pageIds != nil && page < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[page] : nil
                                        if !activeInkStore.isPendingCoreFlush(for: page, pageId: pid) { inkDiskBaselines[page] = loaded }
                                        captureInitialPageState(page: page, drawing: loaded)
                                    }
                                },
                                reloadGeneration: continuousReloadGeneration,
                                inkReloadGeneration: continuousInkReloadGeneration,
                                objectGeneration: continuousObjectGeneration,
                                mergeReloaded: { page, live in
                                    let merged = mergedWithDisk(page: page, local: live, updateBaseline: true)
                                    if activeInkStore.hasPendingCoreFlush { scheduleCoreInkFlush() }
                                    return merged
                                },
                                initialDrawing: { page in
                                    let pid = (notebook.pageIds != nil && page < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[page] : nil
                                    return activeInkStore.drawing(for: page, pageId: pid)
                                },
                                notebook: $notebook,
                                onNotebookChanged: {
                                    commitNotebook()
                                    PageThumbnailRenderer.invalidateAll()
                                },
                                onLassoBegan: { pt in
                                    // 在非焦點頁圈：先把焦點（與 currentDrawing）切到這一頁，
                                    // 選取的索引才會對到這一頁的筆畫。
                                    if currentPageIndex != index {
                                        lasso.clear()
                                        focusContinuousPage(index)
                                    } else {
                                        syncDrawingFromCanvas()
                                    }
                                    configureLassoCallbacks(forPage: index)
                                    lasso.begin(at: pt)
                                    if lasso.isDraggingSelection {
                                        lassoDragStartPage = index
                                        lassoDragInitialDrawing = currentDrawing
                                        continuousDragPage = index
                                    }
                                },
                                onLassoMoved: { pt in
                                    guard index == currentPageIndex else { return }
                                    if lasso.isDraggingSelection {
                                        if lassoDragStartPage == nil {
                                            lassoDragStartPage = index
                                            lassoDragInitialDrawing = currentDrawing
                                            continuousDragPage = index
                                        }
                                        let lastPt = lasso.dragPoint ?? pt
                                        let delta = CGSize(width: pt.x - lastPt.x, height: pt.y - lastPt.y)
                                        lasso.updateDragPoint(pt)
                                        if let updated = lasso.moveSelected(in: currentDrawing, by: delta) {
                                            currentDrawing = updated
                                            showLassoEdit(updated)
                                        }
                                    } else {
                                        lasso.extend(to: pt)
                                    }
                                },
                                onLassoEnded: {
                                    guard index == currentPageIndex else { return }
                                    let wasDragging = lasso.isDraggingSelection
                                    continuousDragPage = nil
                                    let fromPage = lassoDragStartPage ?? index
                                    let drawingBefore = lassoDragInitialDrawing ?? currentDrawing
                                    lassoDragStartPage = nil
                                    lassoDragInitialDrawing = nil

                                    if wasDragging {
                                        if let box = lasso.boundingRect,
                                           let landing = crossingLanding(for: box, page: index),
                                           landing.page != index {
                                            let targetPage = landing.page
                                            let targetOffset = landing.offset
                                            let selectedIndices = lasso.selected
                                            let movedStrokes = selectedIndices.compactMap { idx in
                                                currentDrawing.strokes.indices.contains(idx) ? currentDrawing.strokes[idx] : nil
                                            }

                                            var fromStrokes = currentDrawing.strokes
                                            for idx in selectedIndices.sorted(by: >) where fromStrokes.indices.contains(idx) {
                                                fromStrokes.remove(at: idx)
                                            }
                                            let finalFromDrawing = PKDrawing(strokes: fromStrokes)

                                            let pidTarget = (notebook.pageIds != nil && targetPage < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[targetPage] : nil
                                            let initialTargetDrawing = activeInkStore.drawing(for: targetPage, pageId: pidTarget)
                                            let targetStrokes = movedStrokes.map { LassoSelection.offset($0, by: targetOffset) }
                                            let finalTargetDrawing = PKDrawing(strokes: initialTargetDrawing.strokes + targetStrokes)

                                            recordDrawingEdit(page: fromPage, drawing: finalFromDrawing)
                                            updateCanvasDrawing(forPage: fromPage, drawing: finalFromDrawing)
                                            broadcastDrawingChange(page: fromPage, drawing: finalFromDrawing)

                                            recordDrawingEdit(page: targetPage, drawing: finalTargetDrawing)
                                            updateCanvasDrawing(forPage: targetPage, drawing: finalTargetDrawing)
                                            broadcastDrawingChange(page: targetPage, drawing: finalTargetDrawing)

                                            if !lasso.objectIds.isEmpty {
                                                for id in lasso.objectIds {
                                                    if let idx = notebook.textAttachments?.firstIndex(where: { $0.id == id }) {
                                                        notebook.textAttachments?[idx].pageIndex = targetPage
                                                        notebook.textAttachments?[idx].x += targetOffset.width
                                                        notebook.textAttachments?[idx].y += targetOffset.height
                                                    } else if let idx = notebook.shapeAttachments?.firstIndex(where: { $0.id == id }) {
                                                        notebook.shapeAttachments?[idx].pageIndex = targetPage
                                                        notebook.shapeAttachments?[idx].x += targetOffset.width
                                                        notebook.shapeAttachments?[idx].y += targetOffset.height
                                                    } else if let idx = notebook.attachments?.firstIndex(where: { $0.id == id }) {
                                                        notebook.attachments?[idx].pageIndex = targetPage
                                                        notebook.attachments?[idx].x += targetOffset.width
                                                        notebook.attachments?[idx].y += targetOffset.height
                                                    } else if let idx = notebook.tableAttachments?.firstIndex(where: { $0.id == id }) {
                                                        notebook.tableAttachments?[idx].pageIndex = targetPage
                                                        notebook.tableAttachments?[idx].x += targetOffset.width
                                                        notebook.tableAttachments?[idx].y += targetOffset.height
                                                    }
                                                }
                                                finishPageCrossing(ids: Array(lasso.objectIds), to: targetPage)
                                            }

                                            focusContinuousPage(targetPage)
                                            let newIndices = IndexSet(initialTargetDrawing.strokes.count..<finalTargetDrawing.strokes.count)
                                            lasso.finishCrossPageMove(newIndices: newIndices, in: finalTargetDrawing.strokes)
                                            lasso.finish(in: finalTargetDrawing)

                                            registerLassoCrossPageUndo(
                                                fromPage: fromPage, fromBefore: drawingBefore, fromAfter: finalFromDrawing,
                                                targetPage: targetPage, targetBefore: initialTargetDrawing, targetAfter: finalTargetDrawing
                                            )
                                            PageThumbnailRenderer.invalidateAll()
                                        } else {
                                            lasso.finish(in: currentDrawing)
                                            recordDrawingEdit(page: index, drawing: currentDrawing)
                                            broadcastDrawingChange(page: index, drawing: currentDrawing)
                                            PageThumbnailRenderer.invalidateAll()
                                            if currentDrawing != drawingBefore {
                                                registerLassoSamePageUndo(page: index, before: drawingBefore, after: currentDrawing)
                                            }
                                        }
                                    } else {
                                        lasso.finish(in: currentDrawing)
                                    }
                                },
                                onPressAndHold: { point in
                                    guard openRadialMenuFromPress(at: point) else { return false }
                                    focusContinuousPage(index)
                                    return true
                                },
                                lassoDecoration: {
                                    AnyView(lassoSelectionDecoration(
                                        zoom: 1, offset: .zero,
                                        viewSize: CGSize(width: PageGeometry.width, height: PageGeometry.height),
                                        barScale: 1 / max(scale, 0.01)))
                                }
                            )
                            .frame(width: PageGeometry.width, height: PageGeometry.height)
                            .clipped()
                            .scaleEffect(scale, anchor: .topLeading)
                            // 連續模式的物件可以拖到相鄰的頁（單頁模式照舊夾在本頁）。
                            .environment(\.pageCrossing, pageCrossing(for: index))
                        }
                        .id(index)
                        .zIndex(continuousDragPage == index ? 1 : 0)
                        .background(
                            // 哪一頁在畫面中央，哪一頁就是焦點頁。
                            // 插入物件要落在使用者正在看的那一頁，不是他上次
                            // 按過上一頁／下一頁的那一頁。
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: PageFocusPreferenceKey.self,
                                    value: [index: geo.frame(in: .named(ContinuousPagesSpace.name)).midY]
                                )
                            }
                        )
                    }
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
            }
            .coordinateSpace(name: ContinuousPagesSpace.name)
            .environment(\.objectReorder, { id, op in reorderObject(id, op) })
            .environment(\.objectLock, objectLockActions)
            .environment(\.objectClipboard, objectClipboardActions)
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { mag in
                        let currentRatio: CGFloat
                        if let target = continuousZoomTarget, case .ratio(let val) = target {
                            currentRatio = val
                        } else {
                            currentRatio = 1.0
                        }
                        let base = continuousPinchBaseZoom ?? currentRatio
                        if continuousPinchBaseZoom == nil { continuousPinchBaseZoom = base }
                        let newRatio = max(0.4, min(3.0, base * mag))
                        continuousZoomTarget = .ratio(newRatio)
                    }
                    .onEnded { _ in
                        continuousPinchBaseZoom = nil
                    }
            )
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            DispatchQueue.main.async { continuousViewportHeight = geo.size.height }
                        }
                        .onChange(of: geo.size.height) { h in
                            DispatchQueue.main.async { continuousViewportHeight = h }
                        }
                }
            )
            .onPreferenceChange(PageFocusPreferenceKey.self) { mids in
                DispatchQueue.main.async {
                    updateFocusedPage(from: mids)
                }
            }
            .onChange(of: currentPageIndex) { page in
                // 捲動自己帶來的變動不用再捲。
                guard page != continuousReportedPage else { return }
                DispatchQueue.main.async {
                    continuousReportedPage = page
                    scrollContinuous(to: page, proxy: proxy, animated: true)
                }
            }
            .onChange(of: continuousScrollRequest) { _ in
                DispatchQueue.main.async {
                    scrollContinuous(to: currentPageIndex, proxy: proxy, animated: true)
                }
            }
            .onChange(of: notebook.pageCount) { _ in
                // 新增／刪除頁面之後頁碼可能沒變但內容換了，確保焦點頁在畫面上。
                DispatchQueue.main.async {
                    scrollContinuous(to: currentPageIndex, proxy: proxy, animated: false)
                }
            }
            .onChange(of: editorMode) { _ in
                // 切換手繪/打字模式時維持使用者原本的捲動位置與閱讀視角，不強制捲動頁面。
            }
            .onAppear {
                // 從整頁模式切過來時，停在原本那一頁而不是回到第 1 頁。
                // LazyVStack 第一輪排版還沒完成時 scrollTo 會落空，下一輪 run loop 補一次。
                DispatchQueue.main.async {
                    continuousReportedPage = currentPageIndex
                    scrollContinuous(to: currentPageIndex, proxy: proxy, animated: false)
                }
            }
        }
    }

    /// 連續模式：使用者在某一頁上落筆／點擊，焦點換到那一頁。
    ///
    /// **不捲動。** 改 `currentPageIndex` 會觸發「捲到焦點頁頂端」（給翻頁鈕、縮圖用的）——
    /// 在半露出來的下一頁落筆，整個畫面就帶著動畫滑走，筆尖底下的紙換了位置，
    /// 使用者看到的是「一碰就跳、空白一下」。先把回報頁設成同一頁，捲動那邊就知道不必動。
    /// 也只在真的換頁時才讀那一頁的筆跡：每一次落筆都讀檔解碼，筆尖一碰就卡一下。
    /// 第 `page` 頁的物件層拿到的跨頁資訊。只有連續模式才有。
    func pageCrossing(for page: Int) -> PageCrossing? {
        guard pageDisplayMode == .continuous else { return nil }
        return PageCrossing(
            page: page,
            pageCount: max(1, notebook.pageCount),
            gap: Self.continuousPageSpacing / max(continuousScale, 0.01),
            began: {
                continuousDragPage = page
                focusContinuousPage(page)
            },
            ended: { id, to in finishPageCrossing(ids: id.map { [$0] } ?? [], to: to) })
    }

    /// 拖曳結束。物件換了頁（`pageIndex` 已經寫好）的話，以頁碼為鍵的名單跟著搬、焦點換到新頁。
    func finishPageCrossing(ids: [String], to page: Int?) {
        continuousDragPage = nil
        guard let page, !ids.isEmpty else { return }
        notebook.realignPageKeyedObjectLists()
        focusContinuousPage(page)
        commitNotebook()
        continuousObjectGeneration += 1
        thumbnailRevision += 1
    }

    /// 編輯器自己搬的物件（形狀、表格、多選）在連續模式下的落點：`frame` 整組的外框，
    /// 在第 `page` 頁的座標裡。回傳 `nil` 表示不換頁（單頁模式、或中心還在本頁）。
    func crossingLanding(for frame: CGRect, page: Int) -> (page: Int, offset: CGSize)? {
        guard let crossing = pageCrossing(for: page) else { return nil }
        let landed = PrintableArea.land(
            x: frame.minX, y: frame.minY, width: frame.width, height: frame.height, crossing: crossing)
        guard let target = landed.page else { return nil }
        return (target, CGSize(width: landed.origin.x - frame.minX, height: landed.origin.y - frame.minY))
    }

    func focusContinuousPage(_ index: Int) {
        guard index != currentPageIndex else { return }
        continuousReportedPage = index
        currentPageIndex = index // state-entry: 連續模式焦點頁切換正門
        if let canvas = continuousCanvases[index] {
            continuousCanvases.activeCanvas = canvas
            canvasView = canvas
        }
        currentDrawing = drawingForPage(index)
        configureLassoCallbacks(forPage: index)
    }

    func scrollContinuous(to page: Int, proxy: ScrollViewProxy, animated: Bool) {
        let target = min(max(0, page), max(0, notebook.pageCount - 1))
        continuousProgrammaticScrollUntil = Date().addingTimeInterval(animated ? 0.8 : 0.4)
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(target, anchor: .top) }
            } else {
                proxy.scrollTo(target, anchor: .top)
            }
        }
    }


    /// 把某一頁的筆跡變動廣播出去（協同）。
    ///
    /// 與整頁模式走同一組 oplog 事件與同一個 `page_index` —— 兩邊各發一種
    /// 事件的話，對方會在不同的模式下收到不同的東西。
    /// 筆跡的變動以「加入哪幾筆、移除哪幾筆」送出（設計 §4.3）。
    ///
    /// 不再送整頁：整頁取代會把對方同一瞬間畫的筆畫蓋掉。這一頁還沒同步過時，
    /// 第一次會把整頁的筆畫當成加入送出 —— 加入是冪等的，對方已有的不會重複。
    func broadcastDrawingChange(page: Int, drawing: PKDrawing) {
        guard !isApplyingRemoteUpdate, isCollaborating else { return }
        ensureCollabPageIds()
        guard let ids = notebook.pageIds, page >= 0, page < ids.count else { return }
        let pageId = ids[page]
        let current = drawing.strokes.enumerated().map { (collabInkLedger.wireId(for: $1), $1, $0) }
        let currentIds = Set(current.map(\.0))
        let known = collabInkLedger.known[pageId] ?? []
        let added = current.filter { !known.contains($0.0) }
        let removed = known.subtracting(currentIds)
        collabInkLedger.known[pageId] = currentIds
        if !added.isEmpty {
            collabInkLedger.added(page: pageId, wires: added.map(\.0))
            let cores = collabCoreIds(page: page, drawing: drawing)
            collaborationManager.broadcastOplog(kind: "ink_add", payload: [
                "proto": Self.collabProto, "page": pageId,
                "strokes": added.map { CollabStroke.encode($0.1, id: $0.0, coreId: cores[$0.2]) }
            ])
        }
        if !removed.isEmpty {
            collabInkLedger.removed(page: pageId, wires: removed)
            collaborationManager.broadcastOplog(kind: "ink_remove", payload: [
                "proto": Self.collabProto, "page": pageId, "ids": Array(removed)
            ])
        }
    }

    /// 一頁筆畫在這台套件裡的 id（與 `CoreInkFlush`、完整匯出同一套），隨筆畫送出，
    /// 收到的人照它寫進自己的套件。
    func collabCoreIds(page: Int, drawing: PKDrawing) -> [String] {
        CollabInkIds.coreIds(of: drawing.strokes, pinned: CollabInkIds.load(
            in: store.syncBaselineDirectory, notebookId: notebook.id, page: page))
    }

    /// 取畫面中央最近的那一頁當焦點頁。
    func updateFocusedPage(from mids: [Int: CGFloat]) {
        guard !mids.isEmpty else { return }
        // 程式捲動進行中不判焦點（理由見 `continuousProgrammaticScrollUntil`）。
        guard Date() >= continuousProgrammaticScrollUntil else { return }
        // 若當前頁碼大於 0，但 mids 尚未包含當前頁且數量不足，防止 LazyVStack 重排初始暫態奪走焦點覆蓋為第 0 頁
        if currentPageIndex > 0 && !mids.keys.contains(currentPageIndex) && mids.count < min(2, notebook.pageCount) {
            return
        }
        // 視窗中央的 y。用固定的頁高估一個中線就夠 —— 這裡只要挑出
        // 「最接近中央的那一頁」，不需要精準的可見面積。
        let viewportCenter = continuousViewportHeight / 2
        let nearest = mids.min {
            abs($0.value - viewportCenter) < abs($1.value - viewportCenter)
        }
        guard let page = nearest?.key, page != currentPageIndex else { return }
        continuousReportedPage = page
        currentPageIndex = page // state-entry: 連續模式視窗焦點頁切換正門
        if let canvas = continuousCanvases[page] {
            continuousCanvases.activeCanvas = canvas
            canvasView = canvas
        }
        currentDrawing = drawingForPage(page)
        configureLassoCallbacks(forPage: page)
    }


    /// 某一頁的插入物件層（圖片、形狀、表格、文字、連結、3D、討論圖釘）。
    ///
    /// 抽成帶頁碼的方法，是為了讓連續頁面模式能對每一頁各叫一次 ——
    /// 原本這一整段寫死在畫布工作區裡、只認 `currentPageIndex`，
    /// 連續模式下就只有一頁有物件，其餘頁面是空的。
    enum ObjectInkLayerFilter {
        case all
        case underInkOnly
        case overInkOnly
    }

    func shouldIncludeInInkLayer(id: String, filter: ObjectInkLayerFilter, underInkSet: Set<String>) -> Bool {
        switch filter {
        case .all: return true
        case .underInkOnly:
            return underInkSet.contains(id)
        case .overInkOnly:
            return !underInkSet.contains(id)
        }
    }

    /// 選取中的「筆跡下方」物件，它的工具列與把手佔的範圍（頁面座標）。
    ///
    /// 表格、圖片、形狀等預設在筆跡下方，文字方塊與圖釘在上方 —— 兩層是
    /// 不同的父容器，選取物件的 `zIndex(999)` 只在自己那一層有效。於是表格
    /// 上緣的「拖曳移動 / 鎖定 / 編修」列一旦跟上方的文字方塊重疊（透明底的
    /// 標題框最常見），點下去被文字方塊吃掉，鎖定鈕怎麼點都點不到。
    ///
    /// 不把選取物件搬到上方那一層：換父容器等於重建 View，表格正在編的
    /// 儲存格、文字游標這些狀態會在選取的瞬間被清掉。改成讓上方那一層裡
    /// 壓到這塊範圍的物件暫時不吃觸控（見 `yieldsToSelectedChrome`）。
    func selectedUnderInkChrome(underInkSet: Set<String>) -> CGRect? {
        let selected = activeSelectedObjectId ?? (selectedShapeIds.count == 1 ? selectedShapeIds.first : nil)
        guard let id = selected, underInkSet.contains(id), let frame = frameOfObject(id: id) else { return nil }
        // 上方留給工具列與旋轉鈕，其餘三邊留給角落的縮放／刪除把手。
        // 旋轉過的物件以外框估算：寧可多讓一點，也不要讓把手被蓋住。
        return CGRect(x: frame.minX - 40, y: frame.minY - 96,
                      width: frame.width + 80, height: frame.height + 136)
    }

    /// 上方圖層的物件是否該讓出觸控給下方選取物件的工具列（見 `selectedUnderInkChrome`）。
    /// 只在有選取時生效；點空白處取消選取後，這些物件又能點了。
    func yieldsToSelectedChrome(_ id: String, chrome: CGRect?) -> Bool {
        guard let chrome, id != activeSelectedObjectId, let frame = frameOfObject(id: id) else { return false }
        return frame.intersects(chrome)
    }

    /// 某一頁的插入物件層（圖片、形狀、表格、文字、連結、3D、討論圖釘）。
    ///
    /// 支援依筆跡上下圖層進行過濾：
    /// - `.underInkOnly`: 移至筆跡下方的物件（置於 PKCanvasView 底層）
    /// - `.overInkOnly`: 筆跡上方的物件（置於 PKCanvasView 頂層）
    /// - `.all`: 完整物件層（連續頁面等情境）
    @ViewBuilder
    func objectLayer(forPage page: Int, filter: ObjectInkLayerFilter = .all) -> some View {
        let underInkSet = notebook.underInkObjectIds(forPage: page)
        // 鎖定在畫布上的物件：不能搬移、縮放、旋轉（見 `canvasLocked`）。不分頁查：物件 id 全域唯一，
        // 頁面搬移、插頁之後頁次鍵對不上也不會鎖錯或漏鎖。
        let lockedSet = notebook.allLockedObjectIds
        // 堆疊順序的索引表：一次算繪只建一次，不要每個物件各掃一遍
        // （見 `ObjectStacking.Lookup`）。
        let stacking = ObjectStacking.Lookup(order: notebook.objectOrder(forPage: page))
        // 下方選取物件的工具列範圍：上方層壓到它的物件暫時讓出觸控（見 `selectedUnderInkChrome`）。
        let chrome = filter == .overInkOnly ? selectedUnderInkChrome(underInkSet: underInkSet) : nil
        ZStack(alignment: .topLeading) {
            ForEach(notebook.attachments ?? []) { item in
                    if item.pageIndex == page && shouldIncludeInInkLayer(id: item.id, filter: filter, underInkSet: underInkSet) {
                        AttachmentItemView(
                            attachment: binding(for: item.id),
                            isSelected: activeSelectedObjectId == item.id,
                            isTypeMode: editorMode == .type,
                            onSelect: { selectSingleObject(item.id) },
                            onEdit: {
                                if let formula = item.mathFormula {
                                    self.editingMathAttachmentId = MathEditTarget(id: item.id, formula: formula)
                                } else if let spec = item.chartSpec {
                                    self.editingChartAttachmentId = ChartEditTarget(id: item.id, spec: spec)
                                } else {
                                    self.editingAttachmentId = item.id
                                }
                            },
                            onDelete: {
                                deletedAttachmentBackup = (type: "image", data: item)
                                collaborationManager.broadcastAttachmentDelete(id: item.id, type: "image")
                                notebook.attachments?.removeAll { $0.id == item.id }
                                commitNotebook()
                                collaborationManager.broadcastSelection(selectedId: nil)
                            }
                        )
                        .canvasLocked(lockedSet.contains(item.id.lowercased()))
                        .allowsHitTesting(!yieldsToSelectedChrome(item.id, chrome: chrome))
                        .zIndex(activeSelectedObjectId == item.id ? 999 : stacking.zIndex(for: item.id, kind: .image))
                    }
                }

                // 連接線先畫 —— 畫在形狀之上的話，線會壓過方塊的邊，看起來像穿幫。
                ForEach(notebook.connectionAttachments ?? []) { item in
                    if item.pageIndex == page && shouldIncludeInInkLayer(id: item.id, filter: filter, underInkSet: underInkSet),
                       let from = notebook.shapeAttachments?.first(where: { $0.id == item.fromShapeId }),
                       let to = notebook.shapeAttachments?.first(where: { $0.id == item.toShapeId }),
                       let geometry = ShapeGeometry.connection(item, from: from, to: to) {
                        ConnectionLineView(
                            connection: item,
                            geometry: geometry,
                            isSelected: selectedConnectionId == item.id,
                            onSelect: {
                                selectedShapeIds = []
                                selectedConnectionId = (selectedConnectionId == item.id) ? nil : item.id
                            },
                            onEdit: {
                                selectedConnectionId = item.id
                                editingConnectionId = item.id
                                editingShapeId = nil
                            },
                            onDelete: { deleteConnection(item.id) }
                        )
                        // 線畫在它連著的兩個形狀的**下面**（見上面的說明），
                        // 但仍然在更低層的其他物件之上。
                        .zIndex(min(
                            stacking.zIndex(for: from.id, kind: .shape),
                            stacking.zIndex(for: to.id, kind: .shape)) - 0.1)
                    }
                }

                // 形狀。
                ForEach(notebook.shapeAttachments ?? []) { item in
                    if item.pageIndex == page && shouldIncludeInInkLayer(id: item.id, filter: filter, underInkSet: underInkSet) {
                        ShapeAttachmentItemView(
                            shape: shapeBinding(for: item.id),
                            isSelected: selectedShapeIds.contains(item.id),
                            isSoleSelection: selectedShapeIds.count <= 1,
                            onSelect: {
                                selectedConnectionId = nil
                                toggleShapeSelection(item.id)
                            },
                            onMove: { delta in moveShapeGroup(item.id, by: delta) },
                            onDelete: { deleteShape(item.id) },
                            onEdit: {
                                selectedShapeIds = [item.id]
                                selectedConnectionId = nil
                                editingShapeId = item.id
                                editingConnectionId = nil
                            },
                            onConnectDrag: { anchor, start, current, finished in
                                handleConnectDrag(
                                    from: item.id, anchor: anchor, start: start,
                                    current: current, finished: finished)
                            }
                        )
                        .canvasLocked(lockedSet.contains(item.id.lowercased()))
                        .allowsHitTesting(!yieldsToSelectedChrome(item.id, chrome: chrome))
                        .zIndex(activeSelectedObjectId == item.id ? 999 : stacking.zIndex(for: item.id, kind: .shape))
                    }
                }

                // 拉線預覽。
                if let draft = connectionDraft, draft.page == page {
                    ConnectionDraftView(from: draft.start, to: draft.current)
                        .zIndex(9000)
                }

                // 互動式貼圖定位與放置浮層（工作項：允許自由拖曳、縮放與旋轉貼圖位置）
                if page == currentPageIndex, let placement = pendingStickerPlacement {
                    StickerPlacementOverlayView(
                        placement: Binding(
                            get: { self.pendingStickerPlacement ?? placement },
                            set: { self.pendingStickerPlacement = $0 }
                        ),
                        onCommit: {
                            if let p = self.pendingStickerPlacement {
                                insertStickerObject(p)
                                self.pendingStickerPlacement = nil
                                // 手寫模式下物件不吃觸控，貼紙放完卻點不動等於又回到
                                // 原本的問題。圖片拖放後也是切到打字模式。
                                transitionToMode(.type)
                                showCanvasNotice(localizationManager.localized("sticker_placed_hint"))
                            }
                        },
                        onCancel: {
                            self.pendingStickerPlacement = nil
                        }
                    )
                    .zIndex(9999)
                }

                // 表格。
                ForEach(notebook.tableAttachments ?? []) { item in
                    if item.pageIndex == page && shouldIncludeInInkLayer(id: item.id, filter: filter, underInkSet: underInkSet) {
                        TableAttachmentItemView(
                            table: tableBinding(for: item.id),
                            isSelected: activeSelectedObjectId == item.id,
                            onSelect: {
                                let wasControlled = (activeSelectedObjectId == item.id)
                                selectSingleObject(item.id)
                                if selectedTool == .eraser {
                                    watchdog.notifyEraserUsedOnNonInk(targetType: .table) {
                                        let id = item.id
                                        notebook.tableAttachments?.removeAll { $0.id == id }
                                        commitNotebook()
                                        PageThumbnailRenderer.invalidateAll()
                                    }
                                } else {
                                    watchdog.notifyObjectTapped(
                                        targetId: item.id,
                                        targetType: .table,
                                        isControlled: wasControlled,
                                        onControlObject: {
                                            selectSingleObject(item.id)
                                        }
                                    )
                                }
                            },
                            onMove: { delta in moveTable(item.id, by: delta) },
                            onEdit: { editingTable = item },
                            onDelete: {
                                let id = item.id
                                notebook.tableAttachments?.removeAll { $0.id == id }
                                commitNotebook()
                                PageThumbnailRenderer.invalidateAll()
                                collaborationManager.broadcastAttachmentDelete(id: id, type: "table")
                            }
                        )
                        .canvasLocked(lockedSet.contains(item.id.lowercased()))
                        .allowsHitTesting(!yieldsToSelectedChrome(item.id, chrome: chrome))
                        .zIndex(activeSelectedObjectId == item.id ? 999 : stacking.zIndex(for: item.id, kind: .table))
                    }
                }

                // 🌟 筆記內嵌 Word 級文字方塊（支援段落對齊、特殊符號與便利貼卡片底色）
                ForEach(Array((notebook.textAttachments ?? []).enumerated()), id: \.element.id) { position, item in
                    if item.pageIndex == page && shouldIncludeInInkLayer(id: item.id, filter: filter, underInkSet: underInkSet) {
                        TextAttachmentItemView(
                            textItem: binding(forTextId: item.id, hint: position),
                            isEditingInline: Binding(
                                get: { inlineEditingTextId == item.id },
                                set: { editing in
                                    if editing {
                                        recordTextUndoState()
                                        textFormatTargetId = item.id
                                        suspendedInlineTextId = nil
                                        inlineEditingTextId = item.id
                                    } else if inlineEditingTextId == item.id {
                                        // 失焦（多半是按了工具列）：記住目標，格式套用後再把游標還回來。
                                        textFormatTargetId = item.id
                                        suspendedInlineTextId = item.id
                                        inlineEditingTextId = nil
                                    }
                                }
                            ),
                            isSelected: activeSelectedObjectId == item.id,
                            onSelect: { selectSingleObject(item.id) },
                            isTypeMode: editorMode == .type,
                            isUnderInk: underInkSet.contains(item.id),
                            snapToGrid: snapToGrid,
                            snapY: { y in snapYToGuideLine(at: y) },
                            onEdit: {
                                recordTextUndoState()
                                self.editingTextId = item.id
                            },
                            onDelete: {
                                if inlineEditingTextId == item.id { inlineEditingTextId = nil }
                                recordTextUndoState()
                                deletedAttachmentBackup = (type: "text", data: item)
                                collaborationManager.broadcastAttachmentDelete(id: item.id, type: "text")
                                notebook.textAttachments?.removeAll { $0.id == item.id }
                                commitNotebook()
                                collaborationManager.broadcastSelection(selectedId: nil)
                                PageThumbnailRenderer.invalidateAll()
                            },
                            onMoved: { delta in
                                moveAnchoredStrokes(forTextId: item.id, delta: delta)
                            },
                            onAnchorInk: {
                                anchorOverlappingInkToText(textItem: item)
                            },
                            selectionTracker: textSelectionTracker
                        )
                        .canvasLocked(lockedSet.contains(item.id.lowercased()))
                        .allowsHitTesting(!yieldsToSelectedChrome(item.id, chrome: chrome))
                        .zIndex(activeSelectedObjectId == item.id ? 999 : stacking.zIndex(for: item.id, kind: .text))
                    }
                }

                // 🌟 筆記內嵌網址 Rich Link 預覽卡片（支援點擊跳轉瀏覽器與自由平移）
                ForEach(notebook.linkAttachments ?? []) { item in
                    if item.pageIndex == page && shouldIncludeInInkLayer(id: item.id, filter: filter, underInkSet: underInkSet) {
                        LinkAttachmentItemView(
                            linkItem: binding(forLinkId: item.id),
                            isSelected: activeSelectedObjectId == item.id,
                            onSelect: { selectSingleObject(item.id) },
                            onDelete: {
                                notebook.linkAttachments?.removeAll { $0.id == item.id }
                                if activeSelectedObjectId == item.id { activeSelectedObjectId = nil }
                                commitNotebook()
                            }
                        )
                        .canvasLocked(lockedSet.contains(item.id.lowercased()))
                        .allowsHitTesting(!yieldsToSelectedChrome(item.id, chrome: chrome))
                        .zIndex(activeSelectedObjectId == item.id ? 999 : stacking.zIndex(for: item.id, kind: .link))
                    }
                }

                // 🌟 頁面上的錄音卡片（可播放、可搬移、可縮放、可旋轉、可改名、音訊轉文字）
                ForEach(notebook.audioAttachments ?? []) { item in
                    if item.pageIndex == page && shouldIncludeInInkLayer(id: item.id, filter: filter, underInkSet: underInkSet) {
                        AudioAttachmentItemView(
                            item: binding(forAudioId: item.id),
                            isSelected: activeSelectedObjectId == item.id,
                            onSelect: { selectSingleObject(item.id) },
                            notebookId: notebook.id,
                            onDelete: {
                                notebook.audioAttachments?.removeAll { $0.id == item.id }
                                commitNotebook()
                            },
                            onTranscribe: { transcribedText in
                                insertTranscriptText(transcribedText, for: item)
                            }
                        )
                        .canvasLocked(lockedSet.contains(item.id.lowercased()))
                        .allowsHitTesting(!yieldsToSelectedChrome(item.id, chrome: chrome))
                        .zIndex(activeSelectedObjectId == item.id ? 999 : stacking.zIndex(for: item.id, kind: .audio))
                    }
                }

                // 🌟 筆記內嵌 3D 幾何模型展示層（支援 360° 空間旋轉、9大材質 PBR 物理反射、縮放與文字標題）
                ForEach(notebook.model3DAttachments ?? []) { item in
                    if item.pageIndex == page && shouldIncludeInInkLayer(id: item.id, filter: filter, underInkSet: underInkSet) {
                        Model3DCanvasItemView(
                            item: binding(forModel3DId: item.id),
                            isSelected: activeSelectedObjectId == item.id,
                            onSelect: { selectSingleObject(item.id) },
                            onDelete: {
                                deletedAttachmentBackup = (type: "3d", data: item)
                                collaborationManager.broadcastAttachmentDelete(id: item.id, type: "3d")
                                notebook.model3DAttachments?.removeAll { $0.id == item.id }
                                commitNotebook()
                                collaborationManager.broadcastSelection(selectedId: nil)
                            }
                        )
                        .canvasLocked(lockedSet.contains(item.id.lowercased()))
                        .allowsHitTesting(!yieldsToSelectedChrome(item.id, chrome: chrome))
                        .zIndex(activeSelectedObjectId == item.id ? 999 : stacking.zIndex(for: item.id, kind: .model3D))
                    }
                }

                // 🌟 筆記內嵌討論圖釘展示層（支援多方訊息留言串、已解決標記與即時推播）
                ForEach(notebook.commentPins ?? []) { pin in
                    if pin.pageIndex == page && filter != .underInkOnly {
                        CommentPinMarkerView(
                            pin: pin,
                            isSelected: selectedCommentPinId == pin.id,
                            onTap: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    if selectedCommentPinId == pin.id {
                                        selectedCommentPinId = nil
                                        collaborationManager.broadcastSelection(selectedId: nil)
                                    } else {
                                        activeSelectedObjectId = nil
                                        selectedShapeIds = []
                                        selectedConnectionId = nil
                                        selectedObjectIds = []
                                        if inlineEditingTextId != nil { inlineEditingTextId = nil }
                                        selectedCommentPinId = pin.id
                                        collaborationManager.broadcastSelection(selectedId: pin.id)
                                    }
                                }
                            }
                        )
                        .position(x: pin.x, y: pin.y)
                        .canvasLocked(lockedSet.contains(pin.id.lowercased()))
                        .allowsHitTesting(!(chrome?.contains(CGPoint(x: pin.x, y: pin.y)) ?? false))

                        .zIndex(stacking.zIndex(for: pin.id, kind: .pin))
                    }
                }

                // 🌟 特殊樣板智慧互動元件層（核取清單 Checkbox、選項切換與進度管控）
                if filter != .underInkOnly {
                    lockedObjectBadges(forPage: page)
                    lockedObjectPrompt(forPage: page)

                    ForEach(interactiveGuideCheckboxes(forPage: page)) { item in
                        InteractiveGuideCheckboxView(
                            isChecked: notebook.checkedGuideItems?[item.key] ?? false,
                            size: CGSize(width: CGFloat(item.guide.w), height: CGFloat(item.guide.h)),
                            onToggle: {
                                toggleGuideCheckbox(key: item.key)
                            },
                            onStrikethroughRow: {
                                toggleRowStrikethrough(y: CGFloat(item.guide.y), page: page)
                            },
                            onClearRowText: {
                                clearRowText(y: CGFloat(item.guide.y), page: page)
                            },
                            onResetPage: {
                                resetPageCheckboxes(page: page)
                            }
                        )
                        .position(
                            x: CGFloat(item.guide.x) + CGFloat(item.guide.w) / 2,
                            y: CGFloat(item.guide.y) + CGFloat(item.guide.h) / 2
                        )
                        .zIndex(10)
                    }
                    if pageDisplayMode == .continuous {
                        if isMarqueeActive && editorMode == .type {
                            marqueeLayer(forPage: page)
                                .zIndex(1000)
                        }
                        if isPlacingPasteObject && !objectClipboard.isEmpty {
                            pasteTargetLayer(forPage: page)
                                .zIndex(1001)
                        }
                    }
                }

        }
        .environment(\.objectReorder, { id, op in reorderObject(id, op) })
        .environment(\.objectLock, objectLockActions)
        .environment(\.objectClipboard, objectClipboardActions)
        .coordinateSpace(name: CanvasCoordinateSpace.name)
    }

    var canvasWorkAreaContent: some View {
        ZStack(alignment: .topTrailing) {
            PageBackgroundRepresentable(
                paperId: notebook.paperId(forPage: currentPageIndex),
                paletteId: notebook.guidePaletteId,
                pageIndex: currentPageIndex,
                checkedGuideItems: notebook.checkedGuideItems
            )
                .frame(width: PageGeometry.width, height: currentPageHeight, alignment: .topLeading)
                .scaleEffect(canvasZoomScale, anchor: .topLeading)
                .offset(x: -canvasContentOffset.x, y: -canvasContentOffset.y)
                .allowsHitTesting(false)
                .zIndex(0)

            // 筆跡下方層（Background / Under-ink objects）：在 CanvasRepresentable 之下，zIndex 1
            objectLayer(forPage: currentPageIndex, filter: .underInkOnly)
                .frame(width: PageGeometry.width, height: currentPageHeight, alignment: .topLeading)
                .scaleEffect(canvasZoomScale, anchor: .topLeading)
                .offset(x: -canvasContentOffset.x, y: -canvasContentOffset.y)
                .allowsHitTesting(isObjectInteractionActive)
                .zIndex(1)

            CanvasRepresentable(
                drawing: $currentDrawing,
                proInk: ProInkBinding(
                    directory: store.drawingsDirectory, notebookId: notebook.id, pageIndex: currentPageIndex),
                selectedTool: selectedTool,
                selectedColor: selectedColor,
                strokeWidth: strokeWidth,
                eraserMode: eraserMode,
                pixelEraserWidth: pixelEraserWidth,
                isRulerActive: isRulerActive,
                paperId: notebook.paperId(forPage: currentPageIndex),
                paletteId: notebook.guidePaletteId,
                pageHeight: currentPageHeight,
                editorMode: effectiveCanvasMode,
                hitPassThroughCheck: { point, event in
                    isUnderInkPointPassThrough(point: point, page: currentPageIndex, event: event)
                },
                isScrollEnabled: false,
                onDrawingChanged: { rawDrawing -> PKDrawing? in
                    // 筆跡登記了自己的復原項：之後的物件變更不能併進前一個物件步驟。
                    objectHistory.breakCoalescing()
                    // **頁面框線就是編輯區域。**
                    var processedDrawing = enforcePrintableArea(rawDrawing)
                    if strokeStabilizer > 0.05 {
                        processedDrawing = applyStabilizer(to: processedDrawing)
                    }
                    if isSymmetryActive {
                        processedDrawing = applySymmetry(to: processedDrawing)
                    }
                    let newDrawing = processedDrawing
                    recordDrawingEdit(page: currentPageIndex, drawing: newDrawing)

                    // 🌟 智慧意圖感知：手繪筆劃覆蓋於文字方塊上方
                    if let latestStroke = newDrawing.strokes.last, newDrawing.strokes.count > lastStrokeCount {
                        let strokeRect = latestStroke.renderBounds
                        if let overlapped = (notebook.textAttachments ?? []).first(where: {
                            $0.pageIndex == currentPageIndex && strokeRect.intersects(CGRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height))
                        }) {
                            watchdog.notifyStrokeDrawnOverText(
                                strokeBounds: strokeRect,
                                textBoxId: overlapped.id,
                                textBoxBounds: CGRect(x: overlapped.x, y: overlapped.y, width: overlapped.width, height: overlapped.height),
                                onAnchor: {
                                    anchorSelectedStrokesToNearestText()
                                }
                            )
                        }
                    }

                    if !isApplyingRemoteUpdate && isCollaborating {
                        let count = newDrawing.strokes.count
                        // 逐筆增刪（設計 §4.3）。以前是「多了就送尾巴幾筆、少了就送整頁取代」：
                        // 套索搬動（筆數不變）不會送；擦掉一筆時送整頁，對方整頁被取代，
                        // 同一瞬間對方畫的那一筆就沒了。
                        broadcastDrawingChange(page: currentPageIndex, drawing: newDrawing)
                        lastStrokeCount = count
                    } else if !isApplyingRemoteUpdate {
                        lastStrokeCount = newDrawing.strokes.count
                    }
                    
                    // 🌟 自動流式錨定：若落筆於既有文字方塊上方（圈註、畫底線、旁註），自動建立關聯錨定
                    if !isApplyingRemoteUpdate && newDrawing.strokes.count > 0 {
                        autoAnchorNewStrokesToOverlappingText(drawing: newDrawing)
                    }
                    
                    return newDrawing.strokes.count == rawDrawing.strokes.count
                        ? nil
                        : newDrawing
                },
                onReachedPageBottom: {
                    ensureNextPageExists()
                },
                onSelectionChanged: { hasSel in
                    if !hasSel { lasso.clear() }
                },
                onLassoBegan: { pt in
                    syncDrawingFromCanvas()
                    configureLassoCallbacks(forPage: currentPageIndex)
                    lasso.begin(at: pt)
                    if lasso.isDraggingSelection {
                        lassoDragInitialDrawing = currentDrawing
                    }
                },
                onLassoMoved: { pt in
                    if lasso.isDraggingSelection {
                        if lassoDragInitialDrawing == nil {
                            lassoDragInitialDrawing = currentDrawing
                        }
                        let lastPt = lasso.dragPoint ?? pt
                        let delta = CGSize(width: pt.x - lastPt.x, height: pt.y - lastPt.y)
                        lasso.updateDragPoint(pt)
                        if let updated = lasso.moveSelected(in: currentDrawing, by: delta) {
                            currentDrawing = updated
                            showLassoEdit(updated)
                        }
                    } else {
                        lasso.extend(to: pt)
                    }
                },
                onLassoEnded: {
                    let wasDragging = lasso.isDraggingSelection
                    let drawingBefore = lassoDragInitialDrawing ?? currentDrawing
                    lassoDragInitialDrawing = nil
                    lasso.finish(in: currentDrawing)
                    if wasDragging {
                        recordDrawingEdit(page: currentPageIndex, drawing: currentDrawing)
                        broadcastDrawingChange(page: currentPageIndex, drawing: currentDrawing)
                        PageThumbnailRenderer.invalidateAll()
                        if currentDrawing != drawingBefore {
                            registerLassoSamePageUndo(page: currentPageIndex, before: drawingBefore, after: currentDrawing)
                        }
                    }
                },
                canvasRef: { ref in
                    continuousCanvases.activeCanvas = ref
                    // `updateUIView` 每次更新都會叫到這裡；直接寫 @State 就是在畫面更新途中改狀態
                    // （SwiftUI 的 runtime issue「Modifying state during view update」，每個工作階段
                    // 好幾十次），而且同一個物件重複指派也會再觸發一輪更新。
                    // 只在真的換了才寫，並且挪到這一輪更新之後。
                    guard self.canvasView !== ref else { return }
                    DispatchQueue.main.async { 
                        self.canvasView = ref 
                        if let adaptive = ref as? AdaptiveCanvasView, self.currentDrawing.strokes.count > 0 {
                            adaptive.forceDisplayRefresh(with: self.currentDrawing)
                        }
                    }
                },
                onScrollMetrics: { visible, fraction in
                    canvasVisibleFraction = visible
                    canvasScrollFraction = fraction
                },
                onTransformChanged: { scale, offset in
                    canvasZoomScale = scale
                    canvasContentOffset = offset
                },
                palmRejection: palmRejection,
                onRetractStrokes: { landedAt in
                    guard palmRejection.drawingPolicy(now: landedAt) != .pencilOnly else { return }
                    if let adaptive = canvasView as? AdaptiveCanvasView, adaptive.activeTouchesCount > 0 {
                        adaptive.pendingRetractDate = landedAt
                        return
                    }
                    let cleaned = PalmRejectionCoordinator.retracting(
                        currentDrawing, landedAt: landedAt)
                    guard cleaned.strokes.count != currentDrawing.strokes.count else { return }
                    let removed = currentDrawing.strokes.count - cleaned.strokes.count
                    currentDrawing = cleaned
                    canvasView?.drawing = cleaned
                    (canvasView as? AdaptiveCanvasView)?.dropDeadUndoEntries(max: removed)
                    saveCurrentPageDrawing()
                },
                onPenControl: applyPenControl,
                onPrevPage: {
                    if currentPageIndex > 0 {
                        saveCurrentPageDrawing()
                        currentPageIndex -= 1
                        loadCurrentPage()
                    }
                },
                onNextPage: {
                    if currentPageIndex < notebook.pageCount - 1 {
                        saveCurrentPageDrawing()
                        currentPageIndex += 1
                        loadCurrentPage()
                    }
                },
                onUndo: { performUndo() },
                onRedo: { performRedo() },
                magneticSnapEnabled: isMagneticSnapActive,
                onMagneticSnap: { start, end in
                    magneticGuideStart = start
                    magneticGuideEnd = end
                    magneticGuideActive = true
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        magneticGuideActive = false
                    }
                },
                onPencilTouchBegan: { handlePencilTouchBegan() },
                onCanvasDirectTap: { location in
                    guard !isInlineInkEditing else { return }
                    handleCanvasDirectTap(at: location)
                },
                onCanvasDirectDoubleTap: { location in
                    guard !isInlineInkEditing else { return }
                    handleCanvasDirectDoubleTap(at: location)
                },
                onPencilTapInTypeMode: { location in
                    guard !isInlineInkEditing else { return }
                    handlePencilTapInTypeMode(at: location)
                },
                onPressAndHold: { openRadialMenuFromPress(at: $0) }
            )
            .accessibilityIdentifier("editor.canvas")
            .overlay(alignment: .topLeading) {
                // 套索的圈、選取框與快顯工具列。套索點是頁面座標，畫在這一層要換回
                // 畫布可視範圍的座標（乘縮放、扣捲動）。
                GeometryReader { geo in
                    lassoSelectionDecoration(
                        zoom: canvasZoomScale, offset: canvasContentOffset, viewSize: geo.size)
                }
            }
            // 從別的 App 把圖拖進來（工作項 S-68）。
            //
            // 掛在畫布上而不是整個編輯器：落點要能換算成頁面座標，
            // 掛在外層的話拖到工具列上也會插進去，而且位置會偏掉。
            .onDrop(of: [.image], isTargeted: $isCanvasDropTargeted) { providers, location in
                acceptImageDrop(providers, at: location, page: currentPageIndex)
            }
            .overlay { canvasDropHighlight(isCanvasDropTargeted) }
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            DispatchQueue.main.async { updateCanvasContentWidth(geo.size.width) }
                        }
                        .onChange(of: geo.size.width) { newWidth in
                            DispatchQueue.main.async { updateCanvasContentWidth(newWidth) }
                        }
                }
            )
            .frame(width: PageGeometry.width, height: currentPageHeight, alignment: .topLeading)
            .zIndex(2)

            modeBadge
                .padding(.top, DS.Space.s)
                .padding(.trailing, DS.Space.m)
                .opacity(modeBadgeVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.22), value: modeBadgeVisible)
            MaskingTapeOverlayView(
                notebook: $notebook,
                pageIndex: currentPageIndex,
                // 膠帶只在手繪模式接管觸控；打字模式下工具還停在膠帶時，整頁覆蓋層會擋掉即點即書。
                isActive: selectedTool == .maskingTape && editorMode == .draw,
                selectedColor: selectedColor,
                onTapesChanged: {
                    commitNotebook()
                    PageThumbnailRenderer.invalidateAll()
                }
            )
            .frame(width: PageGeometry.width, height: currentPageHeight, alignment: .topLeading)
            .scaleEffect(canvasZoomScale, anchor: .topLeading)
            .offset(x: -canvasContentOffset.x, y: -canvasContentOffset.y)
            .allowsHitTesting((selectedTool == .maskingTape && editorMode == .draw) || (editorMode != .draw && !(notebook.tapeAttachments?.filter { $0.pageIndex == currentPageIndex }.isEmpty ?? true)))
            .zIndex(selectedTool == .maskingTape && editorMode == .draw ? 4 : 2.5)

            // 筆跡上方層（Foreground / Over-ink objects）：在 CanvasRepresentable 之上，zIndex 3
            objectLayer(forPage: currentPageIndex, filter: .overInkOnly)
                .frame(width: PageGeometry.width, height: currentPageHeight, alignment: .topLeading)
                .scaleEffect(canvasZoomScale, anchor: .topLeading)
                .offset(x: -canvasContentOffset.x, y: -canvasContentOffset.y)
                .allowsHitTesting(isObjectInteractionActive)
                .zIndex(3)

            // 🌟 專業鏡像對稱尺規視覺參考線
            if isSymmetryActive && editorMode == .draw {
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                    .foregroundColor(Color.accentColor.opacity(0.6))
                    .frame(width: 1)
                    .overlay(alignment: .top) {
                        Text(localizationManager.localized("ed_symmetry_axis"))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(uiColor: .systemBackground).opacity(0.85))
                            .cornerRadius(4)
                            .offset(y: 8)
                    }
                    .position(x: 400, y: currentPageHeight / 2)
                    .allowsHitTesting(false)
            }

            // 🌟 插入垂直空間分隔導引器（GoodNotes 風格空間插入條）
            if isInsertSpaceActive {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(height: 2)
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.and.down.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                        Text(localizationManager.localized("insert_vertical_space"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isInsertSpaceActive = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.accentColor.opacity(0.95)).shadow(color: .black.opacity(0.2), radius: 4, y: 2))
                    .offset(x: 20)
                }
                .frame(width: PageGeometry.width, height: 32)
                .position(x: PageGeometry.width / 2, y: insertSpaceDividerY)
                .scaleEffect(canvasZoomScale, anchor: .topLeading)
                .offset(x: -canvasContentOffset.x, y: -canvasContentOffset.y)
                .zIndex(5)
                .gesture(
                    DragGesture()
                        .onChanged { val in
                            let delta = val.translation.height - insertSpaceDragAccum
                            insertSpaceDragAccum = val.translation.height
                            let targetY = max(50, min(currentPageHeight + 200, insertSpaceDividerY + delta))
                            insertSpaceDividerY = targetY
                            if abs(delta) > 0.5 {
                                applyVerticalSpaceInsertion(splitY: insertSpaceDividerY, deltaY: delta)
                            }
                        }
                        .onEnded { _ in
                            insertSpaceDragAccum = 0.0
                        }
                )
            }


            // 框選層。只有在框選模式下才存在 —— 平常掛一層可命中的
            // 透明視圖，底下的物件就全部點不到了。
            if isMarqueeActive && editorMode == .type {
                marqueeLayer(forPage: currentPageIndex)
                    .frame(width: PageGeometry.width, height: currentPageHeight, alignment: .topLeading)
                    .scaleEffect(canvasZoomScale, anchor: .topLeading)
                    .offset(x: -canvasContentOffset.x, y: -canvasContentOffset.y)
                    .coordinateSpace(name: CanvasCoordinateSpace.name)
                    .zIndex(4)
            }

            if isPlacingPasteObject && !objectClipboard.isEmpty {
                pasteTargetLayer(forPage: currentPageIndex)
                    .frame(width: PageGeometry.width, height: currentPageHeight, alignment: .topLeading)
                    .scaleEffect(canvasZoomScale, anchor: .topLeading)
                    .offset(x: -canvasContentOffset.x, y: -canvasContentOffset.y)
                    .coordinateSpace(name: CanvasCoordinateSpace.name)
                    .zIndex(4)
            }

            // 展開的討論圖釘詳細對話框
            if let pinId = selectedCommentPinId,
               let pin = (notebook.commentPins ?? []).first(where: { $0.id == pinId }),
               pin.pageIndex == currentPageIndex {
                CommentThreadDialog(
                    pin: pin,
                    currentUserId: collaborationManager.currentUserId,
                    currentUserName: AccountManager.shared.profile.displayName,
                    currentUserColor: collaborationManager.myColorHex,
                    onReply: { pId, text in
                        addCommentReply(pinId: pId, text: text)
                    },
                    onToggleResolve: { pId in
                        toggleCommentResolve(pinId: pId)
                    },
                    onDelete: { pId in
                        deleteCommentPin(pinId: pId)
                    },
                    onDeleteMessage: { pId, mId in
                        deleteCommentMessage(pinId: pId, messageId: mId)
                    },
                    onClose: {
                        withAnimation {
                            selectedCommentPinId = nil
                            collaborationManager.broadcastSelection(selectedId: nil)
                        }
                    }
                )
                .position(
                    x: min(max(170, pin.x), 650),
                    y: min(max(150, pin.y - 120), currentPageHeight - 120)
                )
                // **與圖釘的點擊層同一個問題**：沒有 zIndex 就預設為 0，
                // 整個討論串面板都被壓在畫布（1）與物件層（2）底下。
                // 面板畫得出來，但只要它的按鈕和頁面上的物件重疊，
                // 點下去就會打到物件 —— 症狀是「收合」與「關閉」按了沒反應，
                // 而使用者只會覺得這個對話框關不掉。
                //
                // 4 在圖釘放置層（3）之上：它是面板，本來就該蓋住一切。
                .zIndex(4)
            }

            // 放置討論圖釘模式互動層。
            //
            // **`zIndex` 不能省。** 這一層原本沒有設，於是預設為 0 ——
            // 而畫布是 `.zIndex(1)`、物件層是 `.zIndex(2)`，它就被壓在最底下，
            // 點擊永遠到不了它。症狀是「加入討論圖釘」按下去之後，橫幅叫你
            // 點畫布，點下去卻是在畫線（手繪模式）或插入文字游標（打字模式），
            // 圖釘**一個都放不上去**。這個功能等於完全不能用。
            //
            // 2026-09-22 拍操作手冊截圖時發現：橫幅出現了，圖釘卻怎麼點都不出現。
            if isPlacingCommentPin {
                GeometryReader { geo in
                    Color.blue.opacity(0.001)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            let newPin = NoteCommentPin(
                                pageIndex: currentPageIndex,
                                x: location.x,
                                y: location.y,
                                authorId: collaborationManager.currentUserId,
                                authorName: AccountManager.shared.profile.displayName,
                                authorColor: collaborationManager.myColorHex,
                                messages: [
                                    NoteCommentMessage(
                                        authorId: collaborationManager.currentUserId,
                                        authorName: AccountManager.shared.profile.displayName,
                                        authorColor: collaborationManager.myColorHex,
                                        text: localizationManager.localized("add_comment_pin")
                                    )
                                ]
                            )
                            if notebook.commentPins == nil {
                                notebook.commentPins = []
                            }
                            notebook.commentPins?.append(newPin)
                            commitNotebook()
                            selectedCommentPinId = newPin.id
                            isPlacingCommentPin = false
                            broadcastCommentPinUpsert(newPin)
                            collaborationManager.broadcastSelection(selectedId: newPin.id)
                        }
                }
                .zIndex(3)

                // 放置圖釘模式頂部提示條
                HStack(spacing: 8) {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.orange)
                    Text(localizationManager.localized("tap_to_place_pin"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Button(action: { isPlacingCommentPin = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.12), radius: 5, y: 2)
                .padding(.top, 14)
                .padding(.leading, 20)
            }

            // 🌟 美學構圖輔助 HUD 疊層（黃金螺旋與三分構圖）
            if isGoldenSpiralOverlay {
                GoldenSpiralOverlayView()
                    .allowsHitTesting(false)
                    .frame(height: currentPageHeight)
            }
            if isRuleOfThirdsOverlay {
                RuleOfThirdsOverlayView()
                    .allowsHitTesting(false)
                    .frame(height: currentPageHeight)
            }

            // 🌟 即時浮動錄音圖示徽章（筆記錄音完成後立即在已開啟筆記中呈現！）
            if notebook.hasRecording, let audioPath = notebook.recordingAudioPath {
                floatingAudioBadge(fileName: audioPath)
                    .padding(16)
                    .transition(.scale.combined(with: .opacity))
            }

            // 🌟 畫布底部浮動延伸膠囊按鈕（保留彈性：讓使用者隨時可向下延伸本頁）
            VStack {
                Spacer()
                HStack {
                    if showExtendedBanner {
                        Text(localizationManager.localized("page_extended_hint"))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    Spacer()

                    // ＋ 新增下一頁
                    Button {
                        addNewPage()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.square.dashed")
                                .font(.subheadline)
                            Text(localizationManager.localized("add_next_page"))
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial)
                        .cornerRadius(18)
                        .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localizationManager.localized("add_next_page"))
                    .help(localizationManager.localized("add_next_page"))

                    // 「延長本頁」已移除：頁面高度固定（PageGeometry），
                    // 寫到頁尾會自動準備下一頁。
                }
                .padding(14)
            }

            // 🌟 線上多人即時彩色游標與筆尖浮層
            RemoteCursorsOverlay()

            // 文字／圖片編修面板與圖層面板已移到 `objectEditPanels`，掛在
            // 兩種頁面模式共用的 `canvasWorkArea` 上 —— 原本掛在這裡，
            // 層級低於畫布與文字輸入層（觸控被它們吃掉，面板關不掉），
            // 而且連續模式根本不會走到這一段。

            // 🌟 聲筆動態同步與波形卡拉 OK 高亮 (Audio-Ink Karaoke Sync)
            if audioManager.isPlaying && !currentDrawing.strokes.isEmpty {
                Canvas { context, size in
                    let total = currentDrawing.strokes.count
                    if total > 0 {
                        let activeIdx = min(total - 1, max(0, Int(Double(total) * audioManager.playbackProgress)))
                        let start = max(0, activeIdx - 1)
                        let end = min(total - 1, activeIdx + 1)
                        for i in start...end {
                            let rect = currentDrawing.strokes[i].renderBounds
                            context.fill(
                                Path(roundedRect: rect.insetBy(dx: -6, dy: -6), cornerRadius: 8),
                                with: .color(Color.yellow.opacity(0.35))
                            )
                            context.stroke(
                                Path(roundedRect: rect.insetBy(dx: -4, dy: -4), cornerRadius: 6),
                                with: .color(Color.orange.opacity(0.8)),
                                lineWidth: 2.5
                            )
                        }
                    }
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            // 🌟 筆跡磁吸對齊與幾何角度引導 (Smart Magnetic Snap Laser Guide)
            if isMagneticSnapActive && editorMode == .draw && magneticGuideActive {
                Canvas { context, size in
                    var path = Path()
                    path.move(to: magneticGuideStart)
                    path.addLine(to: magneticGuideEnd)
                    context.stroke(
                        path,
                        with: .color(Color.cyan.opacity(0.85)),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            // 徑向飛輪快捷工具盤不放在這裡：見 `canvasWorkArea` 的 `radialMenuLayer`。
            // 這一層會跟著頁面縮放，而且沒有 zIndex（預設 0）—— 被畫布（zIndex 2）壓住，
            // 點按鈕其實都點到畫布上變成筆跡，工具盤完全沒反應。
        }
        .frame(width: PageGeometry.width, height: currentPageHeight)
        .contentShape(Rectangle())
        .overlay(alignment: .trailing) {
            // 可用游標拖曳的捲軸（iOS 原生指示器不接受互動）
            CanvasScrollbar(
                visibleFraction: canvasVisibleFraction,
                scrollFraction: canvasScrollFraction
            ) { fraction in
                guard let canvas = canvasView else { return }
                let scrollable = max(canvas.contentSize.height - canvas.bounds.height, 0)
                canvas.setContentOffset(CGPoint(x: canvas.contentOffset.x, y: scrollable * fraction), animated: false)
                canvasScrollFraction = fraction
            }
            .padding(.trailing, 4)
            .padding(.vertical, 10)
        }
        .coordinateSpace(name: CanvasCoordinateSpace.name)
        .onContinuousHover { phase in
            guard isCollaborating else { return }
            switch phase {
            case .active(let location):
                collaborationManager.broadcastCursor(
                    x: location.x,
                    y: location.y,
                    isDrawing: false,
                    tool: selectedTool.rawValue
                )
            case .ended:
                break
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 8, y: 4)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    /// 套索操作按鈕：圖示 + 可選文字標籤 + 說明提示
    func lassoActionButton(
        _ icon: String,
        _ titleKey: String,
        _ hintKey: String,
        showLabel: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                if showLabel {
                    Text(localizationManager.localized(titleKey))
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .foregroundColor(.primary)
            .padding(.horizontal, showLabel ? 8 : 6)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        // help 是補充說明（hint），標籤要用按鈕本身的名字。
        .accessibilityLabel(localizationManager.localized(titleKey))
        .help(localizationManager.localized(hintKey))
    }


    /// 版本標示（v2.2.0 這種）。點一下可複製，回報問題時直接貼上。
    // 版本號**不放在編輯器工具列**（工作項 S-62）。
    //
    // 原本這裡有一個等寬字體的 `v3.9.0` 標籤，理由是「Mac 上跑的 iOS 版由
    // 系統決定視窗標題，畫在自己的工具列裡最可靠」。那個理由本身沒錯，
    // 但結論放錯地方了：使用者每天盯著的編輯畫面不該常駐一個版本號 ——
    // 那是開發用的東西出現在出貨的介面上。
    //
    // 版本號在兩個地方仍然看得到：首頁頁尾，以及快捷選單裡的系統診斷。


}
