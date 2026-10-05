import Combine
import PencilKit
import Foundation
import SwiftUI

extension Notification.Name {
    /// 圖層顯示／鎖定或製圖設定改了。圖層視圖收到後重畫。
    static let kairumoDraftingChanged = Notification.Name("kairumo.drafting.changed")
}

/// 圖學的編輯狀態：目前的製圖筆、要畫在哪一層、各圖層的顯示與鎖定、吸附與角度鎖定。
///
/// 圖層**定義**（有幾層、顏色、筆組）在核心 `ffi_draft.rs`，這裡只存使用者的選擇。
/// 顯示／鎖定是**這台裝置、這本筆記**的檢視狀態（跟捲動位置一樣），不同步 ——
/// 在 iPad 上隱藏了輔助線，不該讓手機上的同一本筆記也跟著少了線。
@MainActor
final class DraftingState: ObservableObject {
    static let shared = DraftingState()

    // MARK: 核心的定義
    let layers: [FfiDraftLayer] = draftLayers()
    let pens: [FfiDraftPen] = draftPens()

    // MARK: 使用者的選擇
    @Published var activePenId: String {
        didSet { UserDefaults.standard.set(activePenId, forKey: Keys.pen); changed() }
    }
    /// 畫在哪一層。`nil` = 跟著筆走（每支製圖筆有自己的預設圖層）。
    @Published var layerOverride: UInt8? {
        didSet {
            UserDefaults.standard.set(Int(layerOverride ?? 0), forKey: Keys.layerOverride)
            changed()
        }
    }
    @Published var snapEnabled: Bool {
        didSet { UserDefaults.standard.set(snapEnabled, forKey: Keys.snap); changed() }
    }
    /// 角度鎖定（度）。0 = 自由。
    @Published var angleStep: Int {
        didSet { UserDefaults.standard.set(angleStep, forKey: Keys.angle); changed() }
    }
    /// 點筆畫就把它改到目前圖層。
    @Published var reassignMode = false {
        didSet {
            if reassignMode { markerMode = false }
            changed()
        }
    }
    /// 點一下就放一個步驟編號（①②③…，畫在中層）。
    @Published var markerMode = false {
        didSet {
            if markerMode { reassignMode = false }
            changed()
        }
    }
    /// 下一個要放的編號。
    @Published var stepNumber = 1

    static let angleChoices = [0, 15, 30, 45, 90]

    /// 目前是哪一本筆記（顯示／鎖定逐本記）。編輯器開筆記時設。
    /// 不是 `@Published`：它在畫布更新的途中被設，發布會變成「更新途中改狀態」。
    private(set) var notebookId = ""

    private var hidden: [String: Set<UInt8>] = [:]
    private var locked: [String: Set<UInt8>] = [:]

    private enum Keys {
        static let pen = "kairumo.draft.pen"
        static let layerOverride = "kairumo.draft.layer"
        static let snap = "kairumo.draft.snap"
        static let angle = "kairumo.draft.angle"
        static func hidden(_ nb: String) -> String { "kairumo.draft.hidden.\(nb.lowercased())" }
        static func locked(_ nb: String) -> String { "kairumo.draft.locked.\(nb.lowercased())" }
    }

    private init() {
        let d = UserDefaults.standard
        activePenId = d.string(forKey: Keys.pen) ?? "thick"
        let o = d.integer(forKey: Keys.layerOverride)
        layerOverride = o == 0 ? nil : UInt8(clamping: o)
        snapEnabled = d.object(forKey: Keys.snap) as? Bool ?? true
        angleStep = d.object(forKey: Keys.angle) as? Int ?? 15
    }

    // MARK: 目前的筆

    var activePen: FfiDraftPen { pens.first { $0.id == activePenId } ?? pens[0] }
    /// 這一筆寫進的圖層。
    var activeLayerId: UInt8 { layerOverride ?? activePen.layer }
    var activeLineType: UInt8 { activePen.lineType }

    /// 目前的筆色。製圖筆的色是核心定義的；畫在別的圖層時用那一層的代表色，
    /// 這樣「輔助線＝淺藍」不會因為拿粗實線去畫輔助層而變成黑色。
    var activeColorRGBA: [UInt8] {
        let hex = layerOverride.flatMap { id in layers.first { $0.id == id }?.colorHex } ?? activePen.colorHex
        return Self.rgba(fromHex: hex)
    }

    func layerColor(_ id: UInt8) -> Color {
        guard let l = layers.first(where: { $0.id == id }) else { return .gray }
        let c = Self.rgba(fromHex: l.colorHex)
        return Color(red: Double(c[0]) / 255, green: Double(c[1]) / 255, blue: Double(c[2]) / 255)
    }

    // MARK: 顯示與鎖定

    /// 圖層面板現在在管哪一本。
    func use(notebook id: String) {
        notebookId = id
        load(id)
    }

    /// 第一次碰到某一本時，從偏好設定讀它的顯示／鎖定。
    private func load(_ id: String) {
        let key = id.lowercased()
        guard hidden[key] == nil else { return }
        let d = UserDefaults.standard
        hidden[key] = Set((d.array(forKey: Keys.hidden(id)) as? [Int] ?? []).map { UInt8(clamping: $0) })
        locked[key] = Set((d.array(forKey: Keys.locked(id)) as? [Int] ?? []).map { UInt8(clamping: $0) })
    }

    func isHidden(layer: UInt8, notebookId nb: String) -> Bool {
        load(nb)
        return layer != 0 && (hidden[nb.lowercased()]?.contains(layer) ?? false)
    }

    func isLocked(layer: UInt8, notebookId nb: String) -> Bool {
        load(nb)
        return layer != 0 && (locked[nb.lowercased()]?.contains(layer) ?? false)
    }

    /// 擦除／改圖層動得了這一層嗎：隱藏或鎖定的都不行。
    func canEdit(layer: UInt8, notebookId nb: String) -> Bool {
        !isHidden(layer: layer, notebookId: nb) && !isLocked(layer: layer, notebookId: nb)
    }

    func setHidden(_ on: Bool, layer: UInt8) {
        let key = notebookId.lowercased()
        var set = hidden[key] ?? []
        if on { set.insert(layer) } else { set.remove(layer) }
        hidden[key] = set
        UserDefaults.standard.set(set.map(Int.init), forKey: Keys.hidden(notebookId))
        changed()
    }

    func setLocked(_ on: Bool, layer: UInt8) {
        let key = notebookId.lowercased()
        var set = locked[key] ?? []
        if on { set.insert(layer) } else { set.remove(layer) }
        locked[key] = set
        UserDefaults.standard.set(set.map(Int.init), forKey: Keys.locked(notebookId))
        changed()
    }

    func ensureVisible(layer: UInt8, notebookId nb: String) {
        guard isHidden(layer: layer, notebookId: nb) else { return }
        setHidden(false, layer: layer)
    }

    /// 繪製順序：未分層 → 底 → 中 → 頂，隱藏的圖層略過。同層維持原本的先後。
    func drawOrder(_ strokes: [ProStroke], notebookId nb: String) -> [ProStroke] {
        load(nb)
        let hiddenSet = hidden[nb.lowercased()] ?? []
        if strokes.allSatisfy({ $0.layerId == 0 }) { return strokes }
        let visible = strokes.filter { $0.layerId == 0 || !hiddenSet.contains($0.layerId) }
        return visible.enumerated()
            .sorted { ($0.element.layerId, $0.offset) < ($1.element.layerId, $1.offset) }
            .map(\.element)
    }

    /// 顯示狀態的指紋（縮圖快取用：隱藏／顯示圖層之後縮圖要跟著變）。
    func hiddenStamp(notebookId nb: String) -> String {
        load(nb)
        return (hidden[nb.lowercased()] ?? []).sorted().map(String.init).joined(separator: ",")
    }

    /// 這本筆記目前隱藏的圖層（匯出時略過）。
    func hiddenLayers(notebookId nb: String) -> [UInt8] {
        load(nb)
        return (hidden[nb.lowercased()] ?? []).sorted()
    }

    private func changed() {
        objectWillChange.send()
        NotificationCenter.default.post(name: .kairumoDraftingChanged, object: nil)
    }

    nonisolated static func rgba(fromHex hex: String) -> [UInt8] {
        var h = hex
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let v = UInt32(h, radix: 16) else { return [0, 0, 0, 255] }
        return [UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF), 255]
    }
}

// MARK: - 圖學套件

extension NotebookStore {
    /// 一次建出套件裡的所有筆記本（課堂筆記、作圖練習、錯誤陷阱本）。
    ///
    /// 紙張、頁面規格與頁數都由核心的 `notebookKits()` 決定 —— 兩個平台建出來的一模一樣。
    @discardableResult
    func createKit(_ kit: FfiNotebookKit, paletteId: String?) -> [NotebookDocument] {
        var made: [NotebookDocument] = []
        for nb in kit.notebooks {
            let title = LocalizationManager.shared.localized(nb.titleKey)
            var doc = createNotebook(title: title, template: NoteTemplate(paperId: nb.paperId) ?? .blank)
            let pages = max(1, Int(nb.pageCount))
            doc.pageFormatId = nb.pageFormatId == defaultPageFormatId() ? nil : nb.pageFormatId
            doc.pageCount = pages
            doc.pagePaperIds = Array(repeating: nb.paperId, count: pages)
            doc.guidePaletteId = paletteId
            updateNotebook(doc)
            made.append(doc)
        }
        return made
    }
}

/// 自訂頁面尺寸的輸入畫面（大尺寸頁取代無限畫布）。
struct CustomPageSizeSheet: View {
    let initial: CGSize
    let onApply: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var width: String
    @State private var height: String

    init(initial: CGSize, onApply: @escaping (String) -> Void) {
        self.initial = initial
        self.onApply = onApply
        _width = State(initialValue: String(Int(initial.width)))
        _height = State(initialValue: String(Int(initial.height)))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text(localizationManager.localized("page_format_custom_hint"))) {
                    TextField(localizationManager.localized("page_format_custom_width"), text: $width)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("page_format.custom.width")
                    TextField(localizationManager.localized("page_format_custom_height"), text: $height)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("page_format.custom.height")
                }
            }
            .navigationTitle(localizationManager.localized("page_format_custom_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized("page_format_custom_apply")) {
                        let w = UInt32(width) ?? UInt32(initial.width)
                        let h = UInt32(height) ?? UInt32(initial.height)
                        onApply(customPageFormatId(width: w, height: h))
                        dismiss()
                    }
                    .accessibilityIdentifier("page_format.custom.apply")
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 範例筆記《圖學範例》

extension NotebookStore {
    static let draftingExampleId = "seed-drafting-example-v1"
    static let draftingExampleSeededKey = "seed.draftingExample.added"

    /// 《圖學範例》：三視圖輔助線求交點。內容（每頁的線與字）由核心的 `draftingExample()` 算好，
    /// Android 讀同一份，所以兩邊是同一本。製圖線一筆一筆落在**真正的圖層**上
    /// （底層原題、中層輔助線與步驟編號、頂層答案），最後一頁教人把中層隱藏。
    func makeDraftingExample() -> NotebookDocument {
        let ex = draftingExample()
        let l = LocalizationManager.shared
        let pages = ex.pages.count
        var doc = NotebookDocument(
            id: Self.draftingExampleId,
            title: l.localized(ex.titleKey),
            createdAt: Date().addingTimeInterval(-300),
            lastModifiedDate: Date().addingTimeInterval(-300),
            pageCount: pages,
            hasRecording: false,
            previewSnippet: l.localized("drafting_example_p1_sub"),
            template: NoteTemplate(paperId: ex.paperId) ?? .blank)
        doc.titleKey = ex.titleKey
        doc.snippetKey = "drafting_example_p1_sub"
        doc.pageFormatId = ex.pageFormatId
        doc.pagePaperIds = Array(repeating: ex.paperId, count: pages)
        let empty = PKDrawing().dataRepresentation()
        doc.pagesData = Array(repeating: empty, count: pages)

        var texts: [NoteTextAttachment] = []
        for (index, page) in ex.pages.enumerated() {
            ProInkStore.save(page.strokes.compactMap { ProStroke(drafted: $0) },
                             in: drawingsDirectory, notebookId: doc.id, page: index)
            for t in page.texts {
                let body = l.localized(t.key)
                let perLine = max(8, Int(CGFloat(t.width) / (CGFloat(t.fontSize) * 0.95)))
                let lines = body.split(separator: "\n", omittingEmptySubsequences: false)
                    .reduce(0) { $0 + max(1, Int((Double($1.count) / Double(perLine)).rounded(.up))) }
                texts.append(NoteTextAttachment(
                    pageIndex: index, text: body, fontSize: CGFloat(t.fontSize), isBold: t.bold,
                    alignmentRaw: "left", textColorHex: t.colorHex, backgroundColorHex: "clear",
                    hasBorder: false, x: CGFloat(t.x), y: CGFloat(t.y), width: CGFloat(t.width),
                    height: CGFloat(lines) * CGFloat(t.fontSize) * 1.6 + 12))
            }
        }
        doc.textAttachments = texts
        return doc
    }
}
