import re
import os

# 1. NotebookStore.swift
with open("apple/Sources/NotebookStore.swift", "r") as f:
    store_code = f.read()

store_code = store_code.replace(
    "public var audioAttachments: [NoteAudioAttachment]?",
    "public var audioAttachments: [NoteAudioAttachment]?\n    public var tapeAttachments: [NoteTapeAttachment]?"
)

store_code += """
public struct NoteTapeAttachment: Identifiable, Codable, Hashable {
    public let id: String
    public var pageIndex: Int
    public var rect: CGRect
    public var isRevealed: Bool
    
    public init(id: String = UUID().uuidString, pageIndex: Int, rect: CGRect, isRevealed: Bool = false) {
        self.id = id
        self.pageIndex = pageIndex
        self.rect = rect
        self.isRevealed = isRevealed
    }
}
"""

with open("apple/Sources/NotebookStore.swift", "w") as f:
    f.write(store_code)

# 2. NotebookEditorView.swift
with open("apple/Sources/NotebookEditorView.swift", "r") as f:
    editor_code = f.read()

editor_code = editor_code.replace(
    "case lasso = \"lasso\"",
    "case lasso = \"lasso\"\n    case maskingTape = \"masking_tape\""
)
editor_code = editor_code.replace(
    "case .eraser, .lasso: return false",
    "case .eraser, .lasso, .maskingTape: return false"
)
editor_code = editor_code.replace(
    "case .lasso: return \"lasso\"",
    "case .lasso: return \"lasso\"\n        case .maskingTape: return \"bandage.fill\""
)
editor_code = editor_code.replace(
    "case .lasso: return \"editor.ink.lasso\"",
    "case .lasso: return \"editor.ink.lasso\"\n        case .maskingTape: return \"editor.ink.maskingTape\""
)
editor_code = editor_code.replace(
    "case .lasso: return \"tool_lasso\"",
    "case .lasso: return \"tool_lasso\"\n        case .maskingTape: return \"tool_masking_tape\""
)

editor_code = editor_code.replace(
    "case .lasso:\n                canvas.tool = PKLassoTool()",
    "case .lasso, .maskingTape:\n                canvas.tool = PKLassoTool()"
)

editor_code = editor_code.replace(
    "@State private var showPhotoPicker: Bool = false",
    "@State private var showPhotoPicker: Bool = false\n    @State private var showStickerLibrary: Bool = false"
)

editor_code = editor_code.replace(
    "Button { showAssetLibrarySheet = true } label: { Label(localizationManager.localized(\"asset_library\"), systemImage: \"shippingbox.fill\") }\n                    .accessibilityIdentifier(\"editor.insert.assets\")",
    "Button { showAssetLibrarySheet = true } label: { Label(localizationManager.localized(\"asset_library\"), systemImage: \"shippingbox.fill\") }\n                    .accessibilityIdentifier(\"editor.insert.assets\")\n                Button { showStickerLibrary = true } label: { Label(localizationManager.localized(\"sticker_library\"), systemImage: \"photo.on.rectangle\") }\n                    .accessibilityIdentifier(\"editor.insert.stickers\")"
)

sheet_str = """        .sheet(isPresented: $showStickerLibrary) { resizableSheet {
            StickerLibraryView { drawing in
                guard let canvas = canvasView else { return }
                let visibleRect = canvas.bounds
                let drawingCenter = CGPoint(x: drawing.bounds.midX, y: drawing.bounds.midY)
                let targetCenter = CGPoint(x: visibleRect.midX, y: visibleRect.midY)
                let transform = CGAffineTransform(translationX: targetCenter.x - drawingCenter.x, y: targetCenter.y - drawingCenter.y)
                let translatedStrokes = drawing.strokes.map {
                    PKStroke(ink: $0.ink, path: $0.path, transform: $0.transform.concatenating(transform), mask: $0.mask)
                }
                var newDrawing = canvas.drawing
                newDrawing.strokes.append(contentsOf: translatedStrokes)
                canvas.drawing = newDrawing
                self.currentDrawing = newDrawing
                self.saveCurrentPageDrawing()
            }
        } }"""
editor_code = editor_code.replace(
    "        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)",
    sheet_str + "\n        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)"
)

overlay_str = """            objectLayer(forPage: currentPageIndex)
            MaskingTapeOverlayView(
                notebook: $notebook,
                pageIndex: currentPageIndex,
                isActive: selectedTool == .maskingTape,
                selectedColor: selectedColor,
                onTapesChanged: { store.updateNotebook(notebook) }
            )"""
editor_code = editor_code.replace("            objectLayer(forPage: currentPageIndex)", overlay_str, 1)

func_str = """
    private func saveSelectedAsSticker() {
        guard let canvas = canvasView, hasLassoSelection else { return }
        let originalStrokes = canvas.drawing.strokes
        for sv in canvas.subviews where String(describing: type(of: sv)).contains("PKTiledView") {
            if sv.responds(to: #selector(UIResponderStandardEditActions.cut(_:))) {
                sv.perform(#selector(UIResponderStandardEditActions.cut(_:)), with: nil)
            }
        }
        UIApplication.shared.sendAction(#selector(UIResponderStandardEditActions.cut(_:)), to: nil, from: nil, for: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let cutDrawing = canvas.drawing
            let originalDict = Dictionary(uniqueKeysWithValues: originalStrokes.map { ($0.path.creationDate, $0) })
            let cutDict = Dictionary(uniqueKeysWithValues: cutDrawing.strokes.map { ($0.path.creationDate, $0) })
            
            var extractedStrokes: [PKStroke] = []
            for (date, stroke) in originalDict {
                if cutDict[date] == nil {
                    extractedStrokes.append(stroke)
                }
            }
            guard !extractedStrokes.isEmpty else {
                canvas.drawing = PKDrawing(strokes: originalStrokes)
                return
            }
            let tempDrawing = PKDrawing(strokes: extractedStrokes)
            let bounds = tempDrawing.bounds
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let transform = CGAffineTransform(translationX: -center.x, y: -center.y)
            let centeredStrokes = extractedStrokes.map {
                PKStroke(ink: $0.ink, path: $0.path, transform: $0.transform.concatenating(transform), mask: $0.mask)
            }
            let stickerDrawing = PKDrawing(strokes: centeredStrokes)
            StickerManager.shared.saveSticker(stickerDrawing)
            
            canvas.drawing = PKDrawing(strokes: originalStrokes)
            self.hasLassoSelection = false
            self.selectedTool = .pen
        }
    }
"""
editor_code = editor_code.replace("    private func copySelectedStrokes() {", func_str + "\n    private func copySelectedStrokes() {")

fab_btn_str = """                        lassoActionButton("doc.on.clipboard", "paste_strokes", "paste_strokes_hint") { pasteStrokes() }
                        lassoActionButton("photo.on.rectangle", "save_as_sticker", "save_as_sticker_hint") { saveSelectedAsSticker() }"""
editor_code = editor_code.replace("                        lassoActionButton(\"doc.on.clipboard\", \"paste_strokes\", \"paste_strokes_hint\") { pasteStrokes() }", fab_btn_str)

fab_btn_str2 = """            Button {
                copySelectedStrokes()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                    Text(localizationManager.localized("copy_selected"))
                }
                .font(.caption2)
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            Button {
                saveSelectedAsSticker()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle")
                    Text(localizationManager.localized("save_as_sticker"))
                }
                .font(.caption2)
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)"""
editor_code = re.sub(
    r'            Button \{\n                copySelectedStrokes\(\)\n            \} label: \{\n                HStack\(spacing: 4\) \{\n                    Image\(systemName: "doc\.on\.doc"\)\n                    Text\(localizationManager\.localized\("copy_selected"\)\)\n                \}\n                \.font\(\.caption2\)\n                \.foregroundColor\(\.primary\)\n                \.padding\(\.horizontal, 8\)\n                \.padding\(\.vertical, 4\)\n                \.background\(Color\.secondary\.opacity\(0\.15\)\)\n                \.cornerRadius\(6\)\n            \}\n            \.buttonStyle\(\.plain\)',
    fab_btn_str2,
    editor_code
)

extra_classes = """

public struct Sticker: Identifiable, Codable {
    public let id: UUID
    public let drawingData: Data
    
    public init(id: UUID = UUID(), drawingData: Data) {
        self.id = id
        self.drawingData = drawingData
    }
}

public class StickerManager: ObservableObject {
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
    
    private func persist() {
        if let data = try? JSONEncoder().encode(stickers) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func loadStickers() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let loaded = try? JSONDecoder().decode([Sticker].self, from: data) else {
            return
        }
        self.stickers = loaded
    }
}

public struct StickerLibraryView: View {
    @Environment(\\.dismiss) var dismiss
    @ObservedObject private var manager = StickerManager.shared
    public var onSelect: ((PKDrawing) -> Void)?
    
    public init(onSelect: ((PKDrawing) -> Void)? = nil) {
        self.onSelect = onSelect
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)], spacing: 16) {
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
            .navigationTitle(LocalizationManager.shared.localized("sticker_library"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizationManager.shared.localized("cancel")) {
                        dismiss()
                    }
                }
            }
            .overlay {
                if manager.stickers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(LocalizationManager.shared.localized("no_stickers"))
                            .font(.headline)
                        Text(LocalizationManager.shared.localized("no_stickers_hint"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
        }
    }
}

private struct StickerCell: View {
    let drawing: PKDrawing
    let onSelect: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onSelect) {
                Image(uiImage: drawing.image(from: drawing.bounds, scale: 2.0))
                    .resizable()
                    .scaledToFit()
                    .padding()
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
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
    
    @State private var currentDragTape: NoteTapeAttachment? = nil
    @State private var dragStartPoint: CGPoint = .zero
    
    public var body: some View {
        ZStack {
            let tapes = notebook.tapeAttachments?.filter { $0.pageIndex == pageIndex } ?? []
            ForEach(tapes) { tape in
                TapeView(
                    tape: tape,
                    isActive: isActive,
                    onToggleReveal: {
                        if let idx = notebook.tapeAttachments?.firstIndex(where: { $0.id == tape.id }) {
                            notebook.tapeAttachments?[idx].isRevealed.toggle()
                            onTapesChanged()
                        }
                    },
                    onRemove: {
                        notebook.tapeAttachments?.removeAll { $0.id == tape.id }
                        onTapesChanged()
                    }
                )
            }
            
            if let dragTape = currentDragTape {
                Rectangle()
                    .fill(selectedColor)
                    .frame(width: dragTape.rect.width, height: dragTape.rect.height)
                    .position(x: dragTape.rect.midX, y: dragTape.rect.midY)
                    .opacity(0.8)
            }
        }
        .background(
            Color.white.opacity(0.001)
                .allowsHitTesting(isActive)
                .gesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            guard isActive else { return }
                            if currentDragTape == nil {
                                dragStartPoint = value.startLocation
                            }
                            let x = min(dragStartPoint.x, value.location.x)
                            let y = min(dragStartPoint.y, value.location.y)
                            let width = abs(value.location.x - dragStartPoint.x)
                            let height: CGFloat = 24.0
                            let rect = CGRect(x: x, y: dragStartPoint.y - height / 2, width: max(width, 10), height: height)
                            
                            currentDragTape = NoteTapeAttachment(pageIndex: pageIndex, rect: rect)
                        }
                        .onEnded { value in
                            guard isActive, let dragTape = currentDragTape else { return }
                            if notebook.tapeAttachments == nil {
                                notebook.tapeAttachments = []
                            }
                            notebook.tapeAttachments?.append(dragTape)
                            currentDragTape = nil
                            onTapesChanged()
                        }
                )
        )
    }
}

private struct TapeView: View {
    let tape: NoteTapeAttachment
    let isActive: Bool
    let onToggleReveal: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        Rectangle()
            .fill(tape.isRevealed ? Color.gray.opacity(0.3) : Color.gray)
            .frame(width: tape.rect.width, height: tape.rect.height)
            .position(x: tape.rect.midX, y: tape.rect.midY)
            .onTapGesture {
                if isActive {
                    onRemove()
                } else {
                    onToggleReveal()
                }
            }
    }
}
"""

editor_code += extra_classes

with open("apple/Sources/NotebookEditorView.swift", "w") as f:
    f.write(editor_code)
