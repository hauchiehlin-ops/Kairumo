//
//  EditorStickersAndTapes.swift
//  Kairumo
//
//  互動式貼圖、遮蔽膠帶、特殊樣板導引與附加操作面板（架構模組化 P2）。
//

import SwiftUI
import PencilKit

#if canImport(PadnoteCore)
import PadnoteCore
#endif

// MARK: - 互動式貼圖定位與放置元件

public struct PendingStickerPlacement: Identifiable, Equatable {
    public let id: UUID = UUID()
    public var drawing: PKDrawing
    public var center: CGPoint
    public var size: CGSize
    public var scale: CGFloat = 1.0
    public var rotationDegrees: Double = 0.0

    public static func == (lhs: PendingStickerPlacement, rhs: PendingStickerPlacement) -> Bool {
        lhs.id == rhs.id &&
        lhs.center == rhs.center &&
        lhs.size == rhs.size &&
        lhs.scale == rhs.scale &&
        lhs.rotationDegrees == rhs.rotationDegrees
    }
}

public struct StickerRenderView: View {
    public let drawing: PKDrawing

    public var body: some View {
        let b = drawing.bounds
        let safeBounds = (b.width > 0 && b.height > 0) ? b : CGRect(x: 0, y: 0, width: 100, height: 100)
        let img = drawing.image(from: safeBounds, scale: 2.0)
        Image(uiImage: img)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

public struct StickerPlacementOverlayView: View {
    @Binding var placement: PendingStickerPlacement
    let onCommit: () -> Void
    let onCancel: () -> Void
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Environment(\.pageCrossing) private var pageCrossing

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var resizeBaseScale: CGFloat? = nil
    @State private var pinchBaseScale: CGFloat? = nil

    private var currentCenter: CGPoint {
        CGPoint(
            x: placement.center.x + dragOffset.width,
            y: placement.center.y + dragOffset.height
        )
    }

    private var displayScale: CGFloat {
        max(0.2, min(5.0, placement.scale))
    }

    public var body: some View {
        let baseW = max(50, placement.size.width)
        let baseH = max(50, placement.size.height)
        let displayW = baseW * displayScale
        let displayH = baseH * displayScale

        VStack(spacing: 10) {
            // 頂部控制把手列：取消、重設、完成放置
            HStack(spacing: 10) {
                Button {
                    if isDragging { pageCrossing?.ended(nil, nil) }
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(7)
                        .background(Color.red)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sticker.place.cancel")
                .accessibilityLabel(localizationManager.localized("cancel"))

                Button {
                    placement.scale = 1.0
                    placement.rotationDegrees = 0
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(7)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizationManager.localized("reset"))

                Button {
                    onCommit()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                        Text(localizationManager.localized("place_sticker"))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sticker.place.confirm")
            }

            // 貼圖互動預覽本體（可自由拖曳定位、旋轉、右下角縮放與雙指捏合縮放）
            ZStack(alignment: .bottomTrailing) {
                StickerRenderView(drawing: placement.drawing)
                    .frame(width: displayW, height: displayH)
                    .rotationEffect(.degrees(placement.rotationDegrees))
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 3, coordinateSpace: .named(CanvasCoordinateSpace.name))
                            .onChanged { val in
                                if !isDragging {
                                    pageCrossing?.began()
                                    isDragging = true
                                }
                                dragOffset = val.translation
                            }
                            .onEnded { val in
                                placement.center.x += val.translation.width
                                placement.center.y += val.translation.height
                                dragOffset = .zero
                                isDragging = false
                                pageCrossing?.ended(nil, nil)
                            }
                    )
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { mag in
                                let base = pinchBaseScale ?? placement.scale
                                if pinchBaseScale == nil { pinchBaseScale = base }
                                placement.scale = max(0.2, min(5.0, base * mag))
                            }
                            .onEnded { _ in
                                pinchBaseScale = nil
                            }
                    )

                // 外圍邊框
                RoundedRectangle(cornerRadius: 10)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundColor(Color.accentColor)
                    .frame(width: displayW + 16, height: displayH + 16)
                    .rotationEffect(.degrees(placement.rotationDegrees))
                    .allowsHitTesting(false)

                // 右下角縮放把手
                Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .contentShape(Circle())
                    .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 1)
                    .offset(x: 10, y: 10)
                    .accessibilityLabel(localizationManager.localized("resize"))
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .named(CanvasCoordinateSpace.name))
                            .onChanged { val in
                                let base = resizeBaseScale ?? placement.scale
                                if resizeBaseScale == nil { resizeBaseScale = base }
                                let delta = (val.translation.width + val.translation.height) / 2.0
                                placement.scale = max(0.2, min(5.0, base + (delta / 120.0)))
                            }
                            .onEnded { _ in
                                resizeBaseScale = nil
                            }
                    )

                // 頂部旋轉把手
                ObjectRotationHandle(
                    degrees: $placement.rotationDegrees,
                    size: CGSize(width: displayW + 16, height: displayH + 16)
                )
            }
        }
        .padding(20)
        .position(x: currentCenter.x, y: currentCenter.y)
    }
}

public struct Sticker: Identifiable, Codable {
    public let id: UUID
    public let drawingData: Data
    
    public init(id: UUID = UUID(), drawingData: Data) {
        self.id = id
        self.drawingData = drawingData
    }
}

public class StickerManager: ObservableObject {
    // profile-scope: profile 每個設定檔各有一份狀態，切換時必須重設
    public static let shared = StickerManager()
    private let storageKey = "user_saved_stickers"
    
    @Published public var stickers: [Sticker] = []
    
    private init() {
        loadStickers()
    }
    
    public func saveSticker(_ drawing: PKDrawing) {
        let sticker = Sticker(drawingData: drawing.dataRepresentation())
        stickers.append(sticker)
        persist()
    }
    
    public func removeSticker(withId id: UUID) {
        stickers.removeAll { $0.id == id }
        persist()
    }
    
    public func persist() {
        if let data = try? JSONEncoder().encode(stickers) {
            ProfileDefaults.current.set(data, forKey: storageKey)
            ProfileDefaults.current.synchronize()
        }
    }
    
    public func loadStickers() {
        guard let data = ProfileDefaults.current.data(forKey: storageKey),
              let loaded = try? JSONDecoder().decode([Sticker].self, from: data) else {
            return
        }
        self.stickers = loaded
    }
}

public struct StickerLibraryView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var manager = StickerManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    public var onSelect: ((PKDrawing) -> Void)?

    /// 內建還是自己存的。
    ///
    /// 原本只有「自己存的」那一半，而它一開始一定是空的 —— 第一次打開
    /// 貼紙庫的人看到一片空白，卻不知道要怎麼生出第一張。
    private enum Tab: Hashable { case builtin, mine }
    @State private var tab: Tab = .builtin

    /// 貼進畫布的尺寸（點）。
    ///
    /// 120 是實測的折衷：小於 90 的話笑臉的眼睛會糊成一點，
    /// 大於 160 的話貼一個勾就佔掉半行字。使用者貼上去之後還能縮放 ——
    /// 它就是一般的筆跡。
    private static let insertSize: CGFloat = 120

    public init(onSelect: ((PKDrawing) -> Void)? = nil) {
        self.onSelect = onSelect
        if !StickerManager.shared.stickers.isEmpty {
            self._tab = State(initialValue: .mine)
        }
    }

    private func L(_ key: String) -> String { localizationManager.localized(key) }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    Text(L("sticker_builtin")).tag(Tab.builtin)
                    Text(L("sticker_mine")).tag(Tab.mine)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .accessibilityIdentifier("stickers.tab")

                switch tab {
                case .builtin: builtinGrid
                case .mine: mineGrid
                }
            }
            .navigationTitle(L("sticker_library"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("cancel")) { dismiss() }
                        .accessibilityIdentifier("stickers.cancel")
                }
            }
            .onAppear {
                manager.loadStickers()
            }
        }
    }

    /// 內建貼紙，依用途分類。
    ///
    /// 分類依「使用者想做什麼」分，不是依圖形長相分 —— 那是核心的決定，
    /// 這裡照著顯示。
    private var builtinGrid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(stickerCategories(), id: \.id) { category in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L(category.titleKey))
                            .font(.headline)
                            .padding(.horizontal)
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 74, maximum: 96), spacing: 12)],
                            spacing: 12
                        ) {
                            ForEach(category.codes, id: \.self) { code in
                                builtinCell(code)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .accessibilityIdentifier("stickers.builtin")
    }

    private func builtinCell(_ code: String) -> some View {
        Button {
            onSelect?(StickerCatalogue.drawing(
                code: code,
                size: Self.insertSize,
                origin: CGPoint(x: 160, y: 200),
                color: UIColor.label))
            dismiss()
        } label: {
            VStack(spacing: 4) {
                StickerGlyph(code: code)
                    .frame(width: 52, height: 52)
                Text(L(stickerLabelKey(code: code)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        // 名稱在底下，但識別碼掛在整顆 Button 上 ——
        // 掛在內層 Text 的話，VoiceOver 與 UI 測試按到的是那行字（S-263）。
        .accessibilityLabel(L(stickerLabelKey(code: code)))
        .accessibilityIdentifier("stickers.item")
    }

    /// 使用者自己存下來的。
    private var mineGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)],
                spacing: 16
            ) {
                ForEach(manager.stickers) { sticker in
                    if let drawing = try? PKDrawing(data: sticker.drawingData) {
                        StickerCell(drawing: drawing) {
                            onSelect?(drawing)
                            dismiss()
                        } onRemove: {
                            manager.removeSticker(withId: sticker.id)
                        }
                    }
                }
            }
            .padding()
        }
        .accessibilityIdentifier("stickers.mine")
        .overlay {
            if manager.stickers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(L("no_stickers")).font(.headline)
                    Text(L("no_stickers_hint"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
    }
}

private struct StickerCell: View {
    let drawing: PKDrawing
    let onSelect: () -> Void
    let onRemove: () -> Void
    
    private var renderedImage: UIImage? {
        let b = drawing.bounds
        guard b.width > 0, b.height > 0 else { return nil }
        return drawing.image(from: b, scale: 2.0)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onSelect) {
                if let image = renderedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding()
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(12)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .frame(height: 120)
                        .overlay(Image(systemName: "pencil.tip").foregroundColor(.secondary))
                }
            }
            .buttonStyle(.plain)
            
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
                    .background(Circle().fill(.white))
            }
            .padding(8)
        }
    }
}

public struct MaskingTapeOverlayView: View {
    @Binding var notebook: NotebookDocument
    let pageIndex: Int
    let isActive: Bool
    let selectedColor: Color
    let onTapesChanged: () -> Void
    
    @State private var selectedTapeId: String? = nil
    @State private var currentDragTape: NoteTapeAttachment? = nil
    @State private var dragStartPoint: CGPoint = .zero
    
    // 預設遮蔽膠帶色票（莫蘭迪粉彩質感），支援快速換色
    private let tapePresetHexes = [
        "#FCEEAC", // 暖黃
        "#FFD1DC", // 柔粉
        "#C8E6C9", // 薄荷綠
        "#BBDEFB", // 晴空藍
        "#FFE0B2", // 淺杏橙
        "#E1BEE7", // 薰衣草紫
        "#CFD8DC"  // 莫蘭迪灰
    ]

    public init(notebook: Binding<NotebookDocument>, pageIndex: Int, isActive: Bool, selectedColor: Color, onTapesChanged: @escaping () -> Void) {
        self._notebook = notebook
        self.pageIndex = pageIndex
        self.isActive = isActive
        self.selectedColor = selectedColor
        self.onTapesChanged = onTapesChanged
    }
    
    public var body: some View {
        ZStack {
            // 背景點擊與繪製層：未點中既有膠帶時，點擊空白處可取消選取；拖曳可立即繪製新的一筆膠帶（支援連續多筆繪製）
            if isActive {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTapeId = nil
                    }
                    .gesture(
                        DragGesture(minimumDistance: 10, coordinateSpace: .named(CanvasCoordinateSpace.name))
                            .onChanged { value in
                                if selectedTapeId != nil {
                                    selectedTapeId = nil
                                }
                                if currentDragTape == nil {
                                    dragStartPoint = value.startLocation
                                }
                                let x = min(dragStartPoint.x, value.location.x)
                                let width = max(abs(value.location.x - dragStartPoint.x), 20)
                                let height: CGFloat = 32.0
                                let rect = CGRect(x: x, y: dragStartPoint.y - height / 2, width: width, height: height)
                                
                                let hex = selectedColor.toHex() ?? "#FCEEAC"
                                currentDragTape = NoteTapeAttachment(pageIndex: pageIndex, rect: rect, colorHex: hex)
                            }
                            .onEnded { value in
                                guard let dragTape = currentDragTape else { return }
                                if notebook.tapeAttachments == nil {
                                    notebook.tapeAttachments = []
                                }
                                notebook.tapeAttachments?.append(dragTape)
                                selectedTapeId = nil
                                currentDragTape = nil
                                onTapesChanged()
                            }
                    )
            }

            let tapes = notebook.tapeAttachments?.filter { $0.pageIndex == pageIndex } ?? []
            ForEach(tapes) { tape in
                TapeView(
                    tape: tape,
                    isActive: isActive,
                    isSelected: selectedTapeId == tape.id,
                    fallbackColor: selectedColor,
                    onSelect: {
                        selectedTapeId = tape.id
                    },
                    onToggleReveal: {
                        if let idx = notebook.tapeAttachments?.firstIndex(where: { $0.id == tape.id }) {
                            notebook.tapeAttachments?[idx].isRevealed.toggle()
                            onTapesChanged()
                        }
                    },
                    onRectChanged: { newRect in
                        if let idx = notebook.tapeAttachments?.firstIndex(where: { $0.id == tape.id }) {
                            notebook.tapeAttachments?[idx].rect = newRect
                            onTapesChanged()
                        }
                    },
                    onRotationChanged: { newRot in
                        if let idx = notebook.tapeAttachments?.firstIndex(where: { $0.id == tape.id }) {
                            notebook.tapeAttachments?[idx].rotation = newRot
                            onTapesChanged()
                        }
                    },
                    onRemove: {
                        if selectedTapeId == tape.id {
                            selectedTapeId = nil
                        }
                        notebook.tapeAttachments?.removeAll { $0.id == tape.id }
                        onTapesChanged()
                    }
                )
            }

            // 繪製中的預覽
            if let dragTape = currentDragTape {
                RoundedRectangle(cornerRadius: 4)
                    .fill(selectedColor.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.accentColor, lineWidth: 1.5)
                    )
                    .frame(width: dragTape.rect.width, height: dragTape.rect.height)
                    .position(x: dragTape.rect.midX, y: dragTape.rect.midY)
                    .shadow(color: Color.black.opacity(0.12), radius: 3, y: 1)
            }

            // 選中膠帶時，在頂層獨立浮動顯示快捷工具條（保證按鈕點擊 100% 作用且不被邊界裁切）
            if isActive, let selId = selectedTapeId, let selectedTape = tapes.first(where: { $0.id == selId }) {
                let toolbarY: CGFloat = selectedTape.rect.minY < 75
                    ? selectedTape.rect.maxY + 48
                    : selectedTape.rect.minY - 50
                TapeFloatingToolbar(
                    tape: selectedTape,
                    presetColors: tapePresetHexes,
                    onColorChanged: { hex in
                        if let idx = notebook.tapeAttachments?.firstIndex(where: { $0.id == selId }) {
                            notebook.tapeAttachments?[idx].colorHex = hex
                            onTapesChanged()
                        }
                    },
                    onToggleReveal: {
                        if let idx = notebook.tapeAttachments?.firstIndex(where: { $0.id == selId }) {
                            notebook.tapeAttachments?[idx].isRevealed.toggle()
                            onTapesChanged()
                        }
                    },
                    onRotate: {
                        if let idx = notebook.tapeAttachments?.firstIndex(where: { $0.id == selId }) {
                            let cur = notebook.tapeAttachments?[idx].rotation ?? 0.0
                            notebook.tapeAttachments?[idx].rotation = (cur + 45.0).truncatingRemainder(dividingBy: 360.0)
                            onTapesChanged()
                        }
                    },
                    onRemove: {
                        selectedTapeId = nil
                        notebook.tapeAttachments?.removeAll { $0.id == selId }
                        onTapesChanged()
                    }
                )
                .position(x: min(max(selectedTape.rect.midX, 180), PageGeometry.width - 180), y: toolbarY)
                .zIndex(20)
            }
        }
        .coordinateSpace(name: CanvasCoordinateSpace.name)
    }
}

private struct TapeFloatingToolbar: View {
    let tape: NoteTapeAttachment
    let presetColors: [String]
    let onColorChanged: (String) -> Void
    let onToggleReveal: () -> Void
    let onRotate: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // 色票選擇
            ForEach(presetColors, id: \.self) { hex in
                Button {
                    onColorChanged(hex)
                } label: {
                    Circle()
                        .fill(Color(hex: hex) ?? .yellow)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(tape.colorHex?.uppercased() == hex.uppercased() ? 0.9 : 0.2), lineWidth: tape.colorHex?.uppercased() == hex.uppercased() ? 2.5 : 1)
                        )
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Divider().frame(height: 18)

            // 旋轉
            Button(action: onRotate) {
                Image(systemName: "rotate.right.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider().frame(height: 18)

            // 翻開 / 遮回切換
            Button(action: onToggleReveal) {
                Image(systemName: tape.isRevealed ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider().frame(height: 18)

            // 刪除
            Button(action: onRemove) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.red)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color.black.opacity(0.22), radius: 8, y: 3)
        )
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .onTapGesture {}
    }
}

private struct TapeView: View {
    let tape: NoteTapeAttachment
    let isActive: Bool
    let isSelected: Bool
    let fallbackColor: Color
    let onSelect: () -> Void
    let onToggleReveal: () -> Void
    let onRectChanged: (CGRect) -> Void
    let onRotationChanged: (Double) -> Void
    let onRemove: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var resizeBaseRect: CGRect? = nil
    @State private var liveRect: CGRect? = nil

    private var currentRect: CGRect {
        if let live = liveRect { return live }
        return CGRect(
            x: tape.rect.minX + dragOffset.width,
            y: tape.rect.minY + dragOffset.height,
            width: tape.rect.width,
            height: tape.rect.height
        )
    }

    private var baseColor: Color {
        if let hex = tape.colorHex, let c = Color(hex: hex) {
            return c
        }
        return fallbackColor
    }

    var body: some View {
        let rect = currentRect

        ZStack {
            // 膠帶本體
            RoundedRectangle(cornerRadius: 4)
                .fill(tape.isRevealed ? baseColor.opacity(0.20) : baseColor.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(baseColor.opacity(tape.isRevealed ? 0.4 : 0.8), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(tape.isRevealed ? 0.02 : 0.08), radius: 2, y: 1)

            // 選取外框與編輯把手（當工具啟動且該膠帶被選中時）
            if isActive && isSelected {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

                // 左縮放把手（水平拉伸）
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                    .frame(width: 14, height: 14)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .position(x: 0, y: rect.height / 2)
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .named(CanvasCoordinateSpace.name))
                            .onChanged { value in
                                if resizeBaseRect == nil {
                                    resizeBaseRect = tape.rect
                                }
                                guard let base = resizeBaseRect else { return }
                                let newMinX = min(base.minX + value.translation.width, base.maxX - 20)
                                let newW = base.maxX - newMinX
                                var transaction = Transaction()
                                transaction.animation = nil
                                withTransaction(transaction) {
                                    liveRect = CGRect(x: newMinX, y: base.minY, width: newW, height: base.height)
                                }
                            }
                            .onEnded { _ in
                                var transaction = Transaction()
                                transaction.animation = nil
                                withTransaction(transaction) {
                                    if let finalRect = liveRect {
                                        onRectChanged(finalRect)
                                    }
                                    resizeBaseRect = nil
                                    liveRect = nil
                                }
                            }
                    )

                // 右縮放把手（水平拉伸）
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                    .frame(width: 14, height: 14)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .position(x: rect.width, y: rect.height / 2)
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .named(CanvasCoordinateSpace.name))
                            .onChanged { value in
                                if resizeBaseRect == nil {
                                    resizeBaseRect = tape.rect
                                }
                                guard let base = resizeBaseRect else { return }
                                let newW = max(20, base.width + value.translation.width)
                                var transaction = Transaction()
                                transaction.animation = nil
                                withTransaction(transaction) {
                                    liveRect = CGRect(x: base.minX, y: base.minY, width: newW, height: base.height)
                                }
                            }
                            .onEnded { _ in
                                var transaction = Transaction()
                                transaction.animation = nil
                                withTransaction(transaction) {
                                    if let finalRect = liveRect {
                                        onRectChanged(finalRect)
                                    }
                                    resizeBaseRect = nil
                                    liveRect = nil
                                }
                            }
                    )

                // 上縮放把手（垂直拉伸）
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                    .frame(width: 14, height: 14)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .position(x: rect.width / 2, y: 0)
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .named(CanvasCoordinateSpace.name))
                            .onChanged { value in
                                if resizeBaseRect == nil {
                                    resizeBaseRect = tape.rect
                                }
                                guard let base = resizeBaseRect else { return }
                                let newMinY = min(base.minY + value.translation.height, base.maxY - 16)
                                let newH = base.maxY - newMinY
                                var transaction = Transaction()
                                transaction.animation = nil
                                withTransaction(transaction) {
                                    liveRect = CGRect(x: base.minX, y: newMinY, width: base.width, height: newH)
                                }
                            }
                            .onEnded { _ in
                                var transaction = Transaction()
                                transaction.animation = nil
                                withTransaction(transaction) {
                                    if let finalRect = liveRect {
                                        onRectChanged(finalRect)
                                    }
                                    resizeBaseRect = nil
                                    liveRect = nil
                                }
                            }
                    )

                // 下縮放把手（垂直拉伸）
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                    .frame(width: 14, height: 14)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .position(x: rect.width / 2, y: rect.height)
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .named(CanvasCoordinateSpace.name))
                            .onChanged { value in
                                if resizeBaseRect == nil {
                                    resizeBaseRect = tape.rect
                                }
                                guard let base = resizeBaseRect else { return }
                                let newH = max(16, base.height + value.translation.height)
                                var transaction = Transaction()
                                transaction.animation = nil
                                withTransaction(transaction) {
                                    liveRect = CGRect(x: base.minX, y: base.minY, width: base.width, height: newH)
                                }
                            }
                            .onEnded { _ in
                                var transaction = Transaction()
                                transaction.animation = nil
                                withTransaction(transaction) {
                                    if let finalRect = liveRect {
                                        onRectChanged(finalRect)
                                    }
                                    resizeBaseRect = nil
                                    liveRect = nil
                                }
                            }
                    )

                // 旋轉把手（頂部拉桿）
                VStack(spacing: 0) {
                    Circle()
                        .fill(Color.accentColor)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .frame(width: 14, height: 14)
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 1.5, height: 14)
                }
                .frame(width: 36, height: 40)
                .contentShape(Rectangle())
                .position(x: rect.width / 2, y: -22)
                .gesture(
                    DragGesture(minimumDistance: 1, coordinateSpace: .named(CanvasCoordinateSpace.name))
                        .onChanged { value in
                            let center = CGPoint(x: rect.midX, y: rect.midY)
                            let vx = value.location.x - center.x
                            let vy = value.location.y - center.y
                            let raw = atan2(vy, vx) * 180 / .pi + 90
                            let angle = CanvasRotation.snapped(Double(raw))
                            onRotationChanged(angle)
                        }
                )
            }

            // 翻開與刪除按鈕（未選中時只在右側顯示輕便移除鈕）
            if isActive && !isSelected {
                HStack {
                    Spacer()
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: rect.width, height: rect.height)
        .contentShape(Rectangle())
        .rotationEffect(.degrees(tape.rotation))
        .onTapGesture {
            if isActive {
                if !isSelected {
                    onSelect()
                }
            } else {
                onToggleReveal()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .named(CanvasCoordinateSpace.name))
                .onChanged { value in
                    guard isActive else { return }
                    if !isSelected {
                        onSelect()
                    }
                    var transaction = Transaction()
                    transaction.animation = nil
                    withTransaction(transaction) {
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    guard isActive else { return }
                    let movedRect = CGRect(
                        x: tape.rect.minX + value.translation.width,
                        y: tape.rect.minY + value.translation.height,
                        width: tape.rect.width,
                        height: tape.rect.height
                    )
                    var transaction = Transaction()
                    transaction.animation = nil
                    withTransaction(transaction) {
                        dragOffset = .zero
                    }
                    onRectChanged(movedRect)
                }
        )
        .position(x: rect.midX, y: rect.midY)
        .animation(nil, value: dragOffset)
        .animation(nil, value: liveRect)
    }
}

/// 「從檔案匯入」那三個修飾詞（挑圖、挑音訊、失敗提示）。
struct ImportPickersModifier: ViewModifier {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Binding var activeImportSlot: FfiImportSlot?
    @Binding var importErrorKey: String
    let onImage: (FileImport.Outcome) -> Void
    let onAudio: (FileImport.Outcome) -> Void
    let onPdf: (FileImport.Outcome) -> Void
    let onDocument: (FileImport.Outcome) -> Void

    func body(content: Content) -> some View {
        content
            // 命令式呈現，見 `DocumentPickerPresenter` 的說明（`.fileImporter` 第二次起會被吞掉）。
            .onChange(of: activeImportSlot) { slot in
                guard let slot else { return }
                DispatchQueue.main.async {
                    let presented = DocumentPickerPresenter.present(
                        types: FileImport.allowedTypes(for: slot)
                    ) { result in
                        activeImportSlot = nil
                        guard let result else { return }
                        let destination: FileImport.Destination = (slot == .audio) ? .recordings : .attachments
                        guard let outcome = FileImport.take(result: result, slot: slot, into: destination)
                        else { return }
                        if outcome.succeeded {
                            switch slot {
                            case .image: onImage(outcome)
                            case .audio: onAudio(outcome)
                            case .pdf: onPdf(outcome)
                            case .document: onDocument(outcome)
                            default: break
                            }
                        } else {
                            importErrorKey = outcome.errorKey
                        }
                    }
                    // 呈現不出去也要把槽位放掉，不然下一次要求是「nil → 同一個值」之外的卡死狀態。
                    if !presented { activeImportSlot = nil }
                }
            }
            .alert(
                localizationManager.localized("import_failed_read"),
                isPresented: Binding(
                    get: { !importErrorKey.isEmpty },
                    set: { if !$0 { importErrorKey = "" } })
            ) {
                Button(localizationManager.localized("confirm"), role: .cancel) { importErrorKey = "" }
            } message: {
                // 理由來自核心的 `reason_key` —— 「為什麼不收」兩端講同一句話。
                Text(localizationManager.localized(importErrorKey))
            }
    }
}

/// `.sheet(item:)` 需要 `Identifiable`，而 `URL` 不是。
struct IdentifiedURL: Identifiable {
    let url: URL
    var id: String { url.path }
}

/// 進階協作四部曲：功能測試與操作面板
/// 專門設計給終端使用者與 QA 測試進階連線功能，完全解耦自 NotebookEditorView 避免破壞核心。
public struct CollabAdvancedFeaturesPanel: View {
    @State private var timeMachineLamport: Double = 0.0
    @State private var isVoiceRoomActive: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            Text(LocalizationManager.shared.localized("collab_advanced_panel"))
                .font(.headline)
            
            // 2. 區網直連 (P2P Local Relay) 掃描與連線
            HStack {
                Button(LocalizationManager.shared.localized("collab_p2p_scan")) {
                    LocalSyncDiscovery.shared.startBrowsing()
                }
                .buttonStyle(.bordered)
                
                Button(LocalizationManager.shared.localized("collab_p2p_stop")) {
                    LocalSyncDiscovery.shared.stopBrowsing()
                }
                .buttonStyle(.bordered)
                
                Button(LocalizationManager.shared.localized("collab_p2p_test")) {
                    if let endpoint = LocalSyncDiscovery.shared.discoveredEndpoints.first {
                        LocalSyncDiscovery.shared.connectToP2P(endpoint: endpoint)
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            // 1. 語音通話 (Voice Room) 操作區
            HStack {
                Text(LocalizationManager.shared.localized("collab_voice_room"))
                Spacer()
                Button(action: {
                    isVoiceRoomActive.toggle()
                    if isVoiceRoomActive {
                        // 觸發 FFI 或 WebSocket 狀態改變
                        print("User joined Voice Room.")
                    } else {
                        print("User left Voice Room.")
                    }
                }) {
                    HStack {
                        Image(systemName: isVoiceRoomActive ? "mic.fill" : "mic.slash")
                        Text(isVoiceRoomActive ? L10n.t("voice_connected") : L10n.t("voice_disconnected"))
                    }
                    .padding(8)
                    .background(isVoiceRoomActive ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            
            Divider()
            
            // 2. 時光機 (Time Machine) 操作區
            VStack(alignment: .leading) {
                Text("\(LocalizationManager.shared.localized("collab_time_machine")) (Lamport: \(Int(timeMachineLamport)))")
                Slider(value: $timeMachineLamport, in: 0...1000) { editing in
                    if !editing {
                        // 呼叫 Rust FFI: collab_time_machine_contributors
                        print("Replaying history to lamport \(timeMachineLamport)...")
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
    }
}

/// 特殊樣板核取清單 Checkbox 互動視圖（支援點選勾選、觸覺回饋、右鍵／長按進度管控選單）
struct InteractiveGuideCheckboxView: View {
    let isChecked: Bool
    let size: CGSize
    let onToggle: () -> Void
    let onStrikethroughRow: () -> Void
    let onClearRowText: () -> Void
    let onResetPage: () -> Void

    @ObservedObject var localizationManager = LocalizationManager.shared

    private var toggleTitle: String {
        isChecked
            ? (localizationManager.currentLanguage == .en ? "Mark Incomplete" : "取消勾選")
            : (localizationManager.currentLanguage == .en ? "Mark Completed" : "✓ 標記完成")
    }
    private var strikethroughTitle: String {
        localizationManager.currentLanguage == .en ? "Strikethrough Row" : "劃除本行文字"
    }
    private var clearRowTitle: String {
        localizationManager.currentLanguage == .en ? "Clear Row Text" : "清空本行文字"
    }
    private var resetPageTitle: String {
        localizationManager.currentLanguage == .en ? "Reset Page Checkboxes" : "重設此頁核取清單"
    }

    var body: some View {
        Button(action: onToggle) {
            ZStack {
                // 隱形延伸觸控區（32x32pt），手指與觸控筆皆極易點擊
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: max(32, size.width + 16), height: max(32, size.height + 16))

                // 方塊外框（依樣板大小適配）
                RoundedRectangle(cornerRadius: min(3, size.width * 0.25))
                    .stroke(isChecked ? Color.green : Color.secondary.opacity(0.4), lineWidth: isChecked ? 1.5 : 1)
                    .background(
                        RoundedRectangle(cornerRadius: min(3, size.width * 0.25))
                            .fill(isChecked ? Color.green.opacity(0.12) : Color.clear)
                    )
                    .frame(width: max(14, size.width), height: max(14, size.height))

                // 勾選符號
                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: max(9, size.width * 0.75), weight: .bold))
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onToggle) {
                Label(toggleTitle, systemImage: isChecked ? "circle" : "checkmark.circle.fill")
            }
            Button(action: onStrikethroughRow) {
                Label(strikethroughTitle, systemImage: "strikethrough")
            }
            Button(role: .destructive, action: onClearRowText) {
                Label(clearRowTitle, systemImage: "delete.left")
            }
            Divider()
            Button(action: onResetPage) {
                Label(resetPageTitle, systemImage: "arrow.counterclockwise")
            }
        }
        .accessibilityLabel(isChecked ? (localizationManager.currentLanguage == .en ? "Completed" : "已完成") : (localizationManager.currentLanguage == .en ? "Incomplete" : "未完成"))
        .accessibilityIdentifier("editor.guide.checkbox")
    }
}

// MARK: - 設定檔切換

extension StickerManager: ProfileScoped {
    func resetForProfileSwitch() {
        stickers = []
        loadStickers()
    }
}
