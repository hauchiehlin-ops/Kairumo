import SwiftUI
import UIKit

/// 圖學工具的觸控流程：點兩個點再拖出尺寸線、點圓再拖出引線…
///
/// 幾何（尺寸線、箭頭、數字）全在核心（`draft_dim_*`），這裡只管「點了哪裡、現在在第幾步、預覽什麼」。
/// 預覽畫在 `ProInkLayerView` 的覆蓋層（不存檔、不進復原）；完成時整組標註一次插入、一次復原。
@MainActor
final class DraftToolController {
    static let shared = DraftToolController()

    private var picks: [CGPoint] = []
    /// 圓形標註：從已經畫好的圓（擬合出來的）取得圓心與半徑；手動點圓心的話是 `nil`。
    private var fitted: (center: CGPoint, radius: CGFloat)?
    private var dragging = false
    private var lastTool: DraftTool = .none

    private var drafting: DraftingState { DraftingState.shared }
    private func l(_ key: String) -> String { LocalizationManager.shared.localized(key) }

    /// 目前這一步在等什麼。
    private func updateHint() {
        let tool = drafting.tool
        let n = picks.count
        let key: String?
        switch tool {
        case .none: key = nil
        case .dimLinear: key = ["draft_hint_dim_first", "draft_hint_dim_second", "draft_hint_dim_place"][min(n, 2)]
        case .dimDiameter, .dimRadius: key = fitted != nil || n >= 1 ? "draft_hint_dim_edge" : "draft_hint_dim_center"
        case .dimAngle: key = ["draft_hint_angle_vertex", "draft_hint_angle_ray1", "draft_hint_angle_ray2", "draft_hint_angle_arc"][min(n, 3)]
        case .compass: key = n == 0 ? "draft_hint_compass_center" : "draft_hint_compass_arc"
        case .setPivot: key = "draft_hint_pivot"
        }
        drafting.toolHint = key.map(l)
    }

    /// 從工具箱剛選了工具：換成第一步的提示。
    func refreshHint() { updateHint() }

    func reset(layer: ProInkLayerView?) {
        picks = []
        fitted = nil
        dragging = false
        layer?.clearOverlay()
        updateHint()
    }

    func handle(_ phase: ProStrokeGestureRecognizer.ToolPhase, _ raw: CGPoint, layer: ProInkLayerView) {
        let tool = drafting.tool
        guard tool != .none else { return }
        if lastTool != tool {
            lastTool = tool
            reset(layer: layer)
        }
        if phase == .cancelled {
            dragging = false
            preview(layer: layer, strokes: [])
            return
        }
        let scale = max(layer.transform.a, 0.25)
        let radius = 14 / scale
        let snapped = layer.snapAnchor(near: raw, radius: radius) ?? raw
        switch tool {
        case .dimLinear: linear(phase, raw, snapped, layer)
        case .dimDiameter, .dimRadius: circular(tool, phase, raw, radius, layer)
        case .dimAngle: angular(phase, raw, snapped, layer)
        case .compass: compass(phase, raw, snapped, layer)
        case .setPivot: pivot(phase, snapped, layer)
        case .none: break
        }
    }

    // MARK: 線性

    private func linear(_ phase: ProStrokeGestureRecognizer.ToolPhase, _ raw: CGPoint, _ snapped: CGPoint, _ layer: ProInkLayerView) {
        if picks.count < 2 {
            guard phase == .ended else { return }
            if let first = picks.first, hypot(first.x - snapped.x, first.y - snapped.y) < 1 { return }
            picks.append(snapped)
            layer.setOverlay(strokes: [], marks: picks)
            tick()
            updateHint()
            return
        }
        let dim = draftDimLinear(
            p1: ffi(picks[0]), p2: ffi(picks[1]), through: ffi(raw), axis: .auto,
            ratio: Float(ratio(layer)))
        switch phase {
        case .began, .moved:
            dragging = true
            preview(layer: layer, strokes: dim?.strokes ?? [], marks: picks)
        case .ended:
            commit(dim, layer)
        case .cancelled:
            break
        }
    }

    // MARK: 直徑／半徑

    private func circular(_ tool: DraftTool, _ phase: ProStrokeGestureRecognizer.ToolPhase, _ raw: CGPoint, _ radius: CGFloat, _ layer: ProInkLayerView) {
        if picks.isEmpty {
            guard phase == .ended else { return }
            // 點在已經畫好的圓上：圓心與半徑直接取用，接下來只要拖出引線的方向。
            if let c = layer.circle(near: raw, radius: radius * 1.5) {
                fitted = c
                picks = [c.center]
            } else {
                fitted = nil
                picks = [raw]
            }
            layer.setOverlay(strokes: [], marks: picks)
            tick()
            updateHint()
            return
        }
        let center = picks[0]
        let dx = raw.x - center.x, dy = raw.y - center.y
        let dist = hypot(dx, dy)
        let r = fitted?.radius ?? dist
        guard r > 2, dist > 0.5 else {
            if phase == .ended { reset(layer: layer) }
            return
        }
        let dir = FfiPoint(x: Float(dx / dist), y: Float(dy / dist))
        let dim = tool == .dimDiameter
            ? draftDimDiameter(center: ffi(center), radius: Float(r), dir: dir, ratio: Float(ratio(layer)))
            : draftDimRadius(center: ffi(center), radius: Float(r), dir: dir, ratio: Float(ratio(layer)))
        switch phase {
        case .began, .moved:
            dragging = true
            preview(layer: layer, strokes: dim?.strokes ?? [], marks: picks)
        case .ended:
            commit(dim, layer)
        case .cancelled:
            break
        }
    }

    // MARK: 角度

    private func angular(_ phase: ProStrokeGestureRecognizer.ToolPhase, _ raw: CGPoint, _ snapped: CGPoint, _ layer: ProInkLayerView) {
        if picks.count < 3 {
            guard phase == .ended else { return }
            if let last = picks.last, hypot(last.x - snapped.x, last.y - snapped.y) < 1 { return }
            picks.append(snapped)
            layer.setOverlay(strokes: [], marks: picks)
            tick()
            updateHint()
            return
        }
        let arc = max(20, Float(hypot(raw.x - picks[0].x, raw.y - picks[0].y)))
        let dim = draftDimAngle(vertex: ffi(picks[0]), a: ffi(picks[1]), b: ffi(picks[2]), arcRadius: arc)
        switch phase {
        case .began, .moved:
            dragging = true
            preview(layer: layer, strokes: dim?.strokes ?? [], marks: picks)
        case .ended:
            commit(dim, layer)
        case .cancelled:
            break
        }
    }

    // MARK: 45° 轉折點

    private func pivot(_ phase: ProStrokeGestureRecognizer.ToolPhase, _ snapped: CGPoint, _ layer: ProInkLayerView) {
        guard phase == .ended else { return }
        drafting.setPivot(snapped, notebookId: layer.notebookId, page: layer.pageIndex)
        drafting.tool = .none
        drafting.toolHint = nil
        tick()
    }

    // MARK: 圓規

    private var compassStart: CGFloat = 0
    private var compassSweep: CGFloat = 0
    private var compassLast: CGFloat = 0
    private var compassRadius: CGFloat = 0

    private func compass(_ phase: ProStrokeGestureRecognizer.ToolPhase, _ raw: CGPoint, _ snapped: CGPoint, _ layer: ProInkLayerView) {
        if picks.isEmpty {
            guard phase == .ended else { return }
            picks = [snapped]
            layer.setOverlay(strokes: [], marks: picks)
            tick()
            updateHint()
            return
        }
        let c = picks[0]
        let angle = atan2(raw.y - c.y, raw.x - c.x)
        switch phase {
        case .began:
            compassRadius = hypot(raw.x - c.x, raw.y - c.y)
            compassStart = angle
            compassLast = angle
            compassSweep = 0
            dragging = true
            previewArc(layer)
        case .moved:
            guard dragging else { return }
            // 逐步累計角度變化（跨過 ±π 要接回去），才能轉超過半圈、也能反方向。
            var d = angle - compassLast
            if d > .pi { d -= 2 * .pi } else if d < -.pi { d += 2 * .pi }
            compassSweep = max(-2 * .pi, min(2 * .pi, compassSweep + d))
            compassLast = angle
            previewArc(layer)
        case .ended:
            guard dragging, compassRadius > 2, abs(compassSweep) > 0.02 else { reset(layer: layer); return }
            commitArc(layer)
        case .cancelled:
            break
        }
    }

    private func arcStroke() -> FfiSheetStroke {
        let pts = draftArc(center: ffi(picks[0]), radius: Float(compassRadius), start: Float(compassStart), sweep: Float(compassSweep))
        return FfiSheetStroke(points: pts, layer: drafting.activeLayerId, lineType: drafting.activeLineType,
                              width: drafting.activePen.width, colorHex: drafting.activePen.colorHex)
    }

    private func previewArc(_ layer: ProInkLayerView) {
        let radial = FfiSheetStroke(
            points: [ffi(picks[0]), FfiPoint(x: Float(picks[0].x + cos(compassStart + compassSweep) * compassRadius),
                                             y: Float(picks[0].y + sin(compassStart + compassSweep) * compassRadius))],
            layer: 2, lineType: 4, width: 0.6, colorHex: "#1E78FF")
        layer.setOverlay(strokes: [arcStroke(), radial], marks: picks)
    }

    private func commitArc(_ layer: ProInkLayerView) {
        defer { reset(layer: layer) }
        let stroke = arcStroke()
        if drafting.isLocked(layer: stroke.layer, notebookId: layer.notebookId) {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        drafting.ensureVisible(layer: stroke.layer, notebookId: layer.notebookId)
        layer.insertDrafted([stroke], origin: .zero)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: 共用

    private func ratio(_ layer: ProInkLayerView) -> Double {
        drafting.scaleRatio(notebookId: layer.notebookId)
    }

    private func ffi(_ p: CGPoint) -> FfiPoint { FfiPoint(x: Float(p.x), y: Float(p.y)) }

    private func preview(layer: ProInkLayerView, strokes: [FfiSheetStroke], marks: [CGPoint]? = nil) {
        layer.setOverlay(strokes: strokes, marks: marks ?? picks)
    }

    private func commit(_ dim: FfiDimension?, _ layer: ProInkLayerView) {
        defer { reset(layer: layer) }
        guard let dim, !dim.strokes.isEmpty else { return }
        // 畫在頂層（細線筆）：標註是「答案」的一部分；圖層被鎖住就不畫並提醒。
        if let top = dim.strokes.first?.layer, drafting.isLocked(layer: top, notebookId: layer.notebookId) {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        for s in dim.strokes { drafting.ensureVisible(layer: s.layer, notebookId: layer.notebookId) }
        layer.insertDrafted(dim.strokes, origin: .zero)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func tick() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}

// MARK: - 圖學工具箱

/// 「圖學工具」：選尺寸標註的種類、設比例尺、進符號面板、插入圖框與標題欄。
///
/// 從製圖列的「圖學工具」按鈕打開；選了標註工具就關掉並進入該工具（單指改成點選與拖曳）。
struct DraftingToolbox: View {
    let notebookId: String
    /// 這一頁的紙張規格能不能畫標準圖框（A4／A3／A2）。
    let frameSupported: Bool
    var onPickTool: (DraftTool) -> Void
    var onInsertSymbol: (FfiDraftKit) -> Void
    var onInsertFrame: (_ thirdAngle: Bool) -> Void
    var onPlaceInstrument: (String) -> Void

    @ObservedObject private var state = DraftingState.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var thirdAngle = true

    private func t(_ key: String) -> String { localizationManager.localized(key) }

    private var ratioBinding: Binding<Double> {
        Binding(
            get: { state.scaleRatio(notebookId: notebookId) },
            set: { state.setScaleRatio($0, notebookId: notebookId) })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(t("draft_toolbox_dimension")) {
                    ForEach([DraftTool.dimLinear, .dimDiameter, .dimRadius, .dimAngle], id: \.self) { tool in
                        Button {
                            onPickTool(tool)
                            dismiss()
                        } label: {
                            Label(t(tool.nameKey), systemImage: tool.symbol)
                        }
                        .accessibilityIdentifier("draft.tool.\(tool.rawValue)")
                    }
                    Picker(t("draft_scale"), selection: ratioBinding) {
                        ForEach(draftScales(), id: \.label) { scale in
                            Text(scale.label).tag(Double(scale.ratio))
                        }
                    }
                    .accessibilityIdentifier("draft.scale")
                    Text(t("draft_scale_footer")).font(.footnote).foregroundColor(.secondary)
                }
                Section(t("draft_toolbox_symbols")) {
                    NavigationLink {
                        DraftSymbolPicker(onInsert: { kit in
                            onInsertSymbol(kit)
                            dismiss()
                        })
                    } label: {
                        Label(t("draft_symbols"), systemImage: "character.book.closed")
                    }
                    .accessibilityIdentifier("draft.symbols")
                }
                Section(t("draft_toolbox_frame")) {
                    Toggle(t("draft_frame_third_angle"), isOn: $thirdAngle)
                        .accessibilityIdentifier("draft.frame.third")
                    Button {
                        onInsertFrame(thirdAngle)
                        dismiss()
                    } label: {
                        Label(t("draft_frame_insert"), systemImage: "rectangle.split.3x1")
                    }
                    .disabled(!frameSupported)
                    .accessibilityIdentifier("draft.frame.insert")
                    Text(t(frameSupported ? "draft_frame_footer" : "draft_frame_unsupported"))
                        .font(.footnote).foregroundColor(.secondary)
                }
                Section(t("draft_toolbox_aids")) {
                    Toggle(t("draft_align"), isOn: $state.alignEnabled)
                        .accessibilityIdentifier("draft.align")
                    Toggle(t("draft_frame_third_angle"), isOn: $state.thirdAngle)
                        .accessibilityIdentifier("draft.projection")
                    ForEach([DraftTool.setPivot, .compass], id: \.self) { tool in
                        Button {
                            onPickTool(tool)
                            dismiss()
                        } label: {
                            Label(t(tool.nameKey), systemImage: tool.symbol)
                        }
                        .accessibilityIdentifier("draft.tool.\(tool.rawValue)")
                    }
                    ForEach(draftInstrumentKinds(), id: \.self) { kind in
                        Button {
                            onPlaceInstrument(kind)
                            dismiss()
                        } label: {
                            Label(t("draft_inst_\(kind)"), systemImage: "ruler")
                        }
                        .accessibilityIdentifier("draft.inst.\(kind)")
                    }
                    Text(t("draft_align_footer")).font(.footnote).foregroundColor(.secondary)
                    Text(t("draft_inst_footer")).font(.footnote).foregroundColor(.secondary)
                }
            }
            .navigationTitle(t("draft_tools"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("cancel")) { dismiss() }
                        .accessibilityIdentifier("draft.toolbox.close")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - 符號面板

/// 製圖符號：表面粗度、焊接、螺紋、幾何公差、標記、標準件。
///
/// 每個符號的圖形由核心算（`draft_symbol`），這裡只放參數的控制項與預覽；
/// 「放進頁面」把整組筆畫放到目前看得見的範圍正中央、套索選住，拖一下就能搬。
struct DraftSymbolPicker: View {
    var onInsert: (FfiDraftKit) -> Void

    @ObservedObject private var localizationManager = LocalizationManager.shared
    private let catalog = draftSymbolCatalog()
    private let groups = ["surface", "weld", "thread", "gdt", "mark", "fastener"]

    @State private var group = "surface"
    @State private var selectedId = "surface_basic"
    @State private var sizeMm: Double = 3.5
    @State private var text = ""
    @State private var rotation: Double = 0
    @State private var otherSide = false
    @State private var allAround = false
    @State private var field = false
    @State private var diameterZone = false
    @State private var datums = ""
    @State private var length: Double = 25
    @State private var mSize: Double = 6

    private func t(_ key: String) -> String { localizationManager.localized(key) }

    private var members: [FfiDraftSymbolInfo] { catalog.filter { $0.group == group } }

    private var isFastener: Bool { group == "fastener" }

    /// 目前的參數。緊固件用 `size_mm` 當 M 規格。
    private func params() -> FfiSymbolParams {
        FfiSymbolParams(
            sizeMm: Float(isFastener ? mSize : sizeMm), text: text, rotationDeg: Float(rotation),
            otherSide: otherSide, allAround: allAround, field: field, diameter: diameterZone,
            datums: datums, lengthMm: Float(length))
    }

    private func kit(for id: String) -> FfiDraftKit? {
        draftSymbol(id: id, anchor: FfiPoint(x: 0, y: 0), params: params())
    }

    var body: some View {
        Form {
            Picker(t("draft_symbols"), selection: $group) {
                ForEach(groups, id: \.self) { g in Text(t("draft_sym_group_\(g)")).tag(g) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("draft.symbols.group")
            .onChange(of: group) { _ in
                selectedId = members.first?.id ?? selectedId
                if group == "fastener" { text = "" }
            }

            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                    ForEach(members, id: \.id) { info in
                        let selected = info.id == selectedId
                        Button { selectedId = info.id } label: {
                            VStack(spacing: 4) {
                                SymbolPreview(kit: kit(for: info.id))
                                    .frame(height: 64)
                                Text(t(info.nameKey)).font(.caption2).lineLimit(2).multilineTextAlignment(.center)
                            }
                            .padding(6)
                            .frame(maxWidth: .infinity)
                            .background(selected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(t(info.nameKey))
                        .accessibilityIdentifier("draft.symbol.\(info.id)")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }

            Section {
                controls
            }

        }
        // 「放進頁面」釘在底部：表單是惰性的，捲出畫面的列根本不存在（測試與 VoiceOver 都找不到）。
        .safeAreaInset(edge: .bottom) {
            Button {
                if let k = kit(for: selectedId) { onInsert(k) }
            } label: {
                Label(t("draft_sym_place"), systemImage: "plus.square.on.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal).padding(.vertical, 8)
            .background(.bar)
            .accessibilityIdentifier("draft.symbol.place")
        }
        .navigationTitle(t("draft_symbols"))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var controls: some View {
        if isFastener {
            Picker(t("draft_sym_m_size"), selection: $mSize) {
                ForEach([3, 4, 5, 6, 8, 10, 12, 16, 20, 24], id: \.self) { m in Text("M\(m)").tag(Double(m)) }
            }
            .accessibilityIdentifier("draft.symbol.msize")
            if selectedId == "bolt_hex" {
                slider(t("draft_sym_length"), $length, 6...100, id: "draft.symbol.length")
            }
        } else {
            slider(t("draft_sym_size"), $sizeMm, 2.5...8, id: "draft.symbol.size", format: "%.1f")
            if selectedId.hasPrefix("thread_") && selectedId.hasSuffix("_side") {
                slider(t("draft_sym_length"), $length, 6...100, id: "draft.symbol.length")
            }
            if selectedId != "center_mark" {
                TextField(t("draft_sym_text"), text: $text, prompt: Text(t("draft_sym_text_hint")))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("draft.symbol.text")
            }
            if group == "weld" {
                Toggle(t("draft_sym_other_side"), isOn: $otherSide)
                Toggle(t("draft_sym_all_around"), isOn: $allAround)
                Toggle(t("draft_sym_field"), isOn: $field)
            }
            if group == "gdt" && selectedId != "datum_feature" {
                Toggle(t("draft_sym_diameter_zone"), isOn: $diameterZone)
                TextField(t("draft_sym_datums"), text: $datums)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("draft.symbol.datums")
            }
            slider(t("draft_sym_rotation"), $rotation, 0...345, id: "draft.symbol.rotation", step: 15)
        }
    }

    private func slider(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>,
                        id: String, format: String = "%.0f", step: Double? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text(String(format: format, value.wrappedValue)).font(.caption).foregroundColor(.secondary)
            }
            if let step {
                Slider(value: value, in: range, step: step).accessibilityIdentifier(id)
            } else {
                Slider(value: value, in: range).accessibilityIdentifier(id)
            }
        }
    }
}

/// 符號的預覽：把核心給的折線縮進格子裡畫出來（用文字色，深色模式也看得見）。
struct SymbolPreview: View {
    let kit: FfiDraftKit?

    var body: some View {
        Canvas { ctx, size in
            guard let kit, !kit.strokes.isEmpty else { return }
            let pts = kit.strokes.flatMap(\.points)
            guard let minX = pts.map(\.x).min(), let maxX = pts.map(\.x).max(),
                  let minY = pts.map(\.y).min(), let maxY = pts.map(\.y).max() else { return }
            let w = max(CGFloat(maxX - minX), 1), h = max(CGFloat(maxY - minY), 1)
            let k = min((size.width - 8) / w, (size.height - 8) / h)
            let ox = (size.width - w * k) / 2 - CGFloat(minX) * k
            let oy = (size.height - h * k) / 2 - CGFloat(minY) * k
            for s in kit.strokes where s.points.count >= 2 {
                var path = Path()
                path.move(to: CGPoint(x: CGFloat(s.points[0].x) * k + ox, y: CGFloat(s.points[0].y) * k + oy))
                for p in s.points.dropFirst() {
                    path.addLine(to: CGPoint(x: CGFloat(p.x) * k + ox, y: CGFloat(p.y) * k + oy))
                }
                let pattern = draftLinePattern(lineType: s.lineType).map { CGFloat($0) * k }
                ctx.stroke(path, with: .color(.primary),
                           style: StrokeStyle(lineWidth: max(0.8, CGFloat(s.width) * k * 0.9), lineCap: .round, lineJoin: .round, dash: pattern))
            }
        }
        .accessibilityHidden(true)
    }
}
