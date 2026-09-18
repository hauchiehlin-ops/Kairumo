import re

with open("apple/Sources/NotebookStore.swift", "r") as f:
    store_code = f.read()

# Add NoteTapeAttachment to NotebookDocument
store_code = store_code.replace(
    "public var audioAttachments: [NoteAudioAttachment]?",
    "public var audioAttachments: [NoteAudioAttachment]?\n    public var tapeAttachments: [NoteTapeAttachment]?"
)

# Append NoteTapeAttachment definition to the end
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


with open("apple/Sources/NotebookEditorView.swift", "r") as f:
    editor_code = f.read()

# EditorToolType
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

# applyTool
editor_code = editor_code.replace(
    "case .lasso:\n                canvas.tool = PKLassoTool()",
    "case .lasso, .maskingTape:\n                canvas.tool = PKLassoTool()"
)

# showStickerLibrary state
editor_code = editor_code.replace(
    "@State private var showPhotoPicker: Bool = false",
    "@State private var showPhotoPicker: Bool = false\n    @State private var showStickerLibrary: Bool = false"
)

# Insert menu
editor_code = editor_code.replace(
    "Button { showAssetLibrarySheet = true } label: { Label(localizationManager.localized(\"asset_library\"), systemImage: \"shippingbox.fill\") }\n                    .accessibilityIdentifier(\"editor.insert.assets\")",
    "Button { showAssetLibrarySheet = true } label: { Label(localizationManager.localized(\"asset_library\"), systemImage: \"shippingbox.fill\") }\n                    .accessibilityIdentifier(\"editor.insert.assets\")\n                Button { showStickerLibrary = true } label: { Label(localizationManager.localized(\"sticker_library\"), systemImage: \"photo.on.rectangle\") }\n                    .accessibilityIdentifier(\"editor.insert.stickers\")"
)

# Sheet
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

# Object Layer tape overlay
overlay_str = """            objectLayer(forPage: currentPageIndex)
            MaskingTapeOverlayView(
                notebook: $notebook,
                pageIndex: currentPageIndex,
                isActive: selectedTool == .maskingTape,
                selectedColor: selectedColor,
                onTapesChanged: { store.updateNotebook(notebook) }
            )"""
editor_code = editor_code.replace("            objectLayer(forPage: currentPageIndex)", overlay_str, 1)

# saveSelectedAsSticker function
func_str = """
    private func saveSelectedAsSticker() {
        guard let canvas = canvasView, hasLassoSelection else { return }
        let originalStrokes = canvas.drawing.strokes
        UIResponderStandardEditActions.cut?(canvas)
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

# Floating action bar button
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

with open("apple/Sources/NotebookEditorView.swift", "w") as f:
    f.write(editor_code)

with open("apple/Sources/NotebookEditorView.swift", "a") as f:
    f.write(open("add_sticker_func.swift").read()) # This actually contains MaskingTapeOverlayView etc from earlier. Wait! I shouldn't use it, I will write it explicitly.

