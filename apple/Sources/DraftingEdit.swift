import SwiftUI
import UIKit

/// 編輯工具的觸控流程：修剪、延伸、圓角、偏移、鏡射、環形陣列（對應 Android 的 `DraftEditController`）。
///
/// 幾何全在核心（`draft_trim`…），這裡只管「點了哪一筆、現在第幾步」，並把結果換成筆畫
/// （沿用原筆畫的筆、顏色、圖層與線型）。每個動作都是**一次復原**。
@MainActor
final class DraftEditController {
    static let shared = DraftEditController()

    private var first: ProStroke?
    private var firstClick: CGPoint = .zero
    private var axisStart: CGPoint?
    private var drafting: DraftingState { DraftingState.shared }

    /// 鏡射、陣列的對象是選的那批筆畫，不是最近點到的。
    private func selectedStrokes(_ layer: ProInkLayerView) -> [ProStroke] {
        layer.strokes(ids: drafting.editSelection)
    }

    func reset(layer: ProInkLayerView?) {
        first = nil
        axisStart = nil
        layer?.clearOverlay()
    }

    /// 這一步在等什麼（語系鍵）。
    func hintKey(for tool: DraftTool) -> String? {
        switch tool {
        case .trim: return "draft_hint_trim"
        case .extend: return "draft_hint_extend"
        case .fillet: return first == nil ? "draft_hint_fillet_first" : "draft_hint_fillet_second"
        case .offset: return first == nil ? "draft_hint_offset_first" : "draft_hint_offset_side"
        case .mirror: return axisStart == nil ? "draft_hint_mirror_first" : "draft_hint_mirror_second"
        case .arrayPolar: return "draft_hint_polar_center"
        default: return nil
        }
    }

    func handle(_ phase: ProStrokeGestureRecognizer.ToolPhase, _ raw: CGPoint, tool: DraftTool, layer: ProInkLayerView) {
        if phase == .cancelled {
            layer.clearOverlay()
            return
        }
        let scale = max(layer.transform.a, 0.25)
        let radius = 14 / scale
        switch tool {
        case .trim: if phase == .ended { trim(raw, radius, layer) }
        case .extend: if phase == .ended { extend(raw, radius, layer) }
        case .fillet: if phase == .ended { fillet(raw, radius, layer) }
        case .offset: if phase == .ended { offset(raw, radius, layer) }
        case .mirror: mirror(phase, raw, radius, layer)
        case .arrayPolar: if phase == .ended { polar(raw, radius, layer) }
        default: break
        }
    }

    private func l(_ key: String) -> String { LocalizationManager.shared.localized(key) }

    /// 這一次觸控有沒有出提示（出了就不要被「下一步在等什麼」蓋掉）。
    private var noticed = false

    func consumeNotice() -> Bool {
        defer { noticed = false }
        return noticed
    }

    private func notice(_ key: String) {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        drafting.toolHint = l(key)
        noticed = true
    }

    private func done(_ layer: ProInkLayerView) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        reset(layer: layer)
    }

    private func ffi(_ p: CGPoint) -> FfiPoint { FfiPoint(x: Float(p.x), y: Float(p.y)) }
    private func ffi(_ s: ProStroke) -> [FfiPoint] { s.points.map { FfiPoint(x: $0.x, y: $0.y) } }
    private func polyline(_ pts: [CGPoint]) -> FfiPolyline { FfiPolyline(points: pts.map(ffi)) }

    // MARK: 修剪

    private func trim(_ click: CGPoint, _ radius: CGFloat, _ layer: ProInkLayerView) {
        guard let hit = layer.strokeNear(click, radius: radius) else { return notice("draft_edit_nothing") }
        let cutters = layer.polylines(excluding: [hit.id]).map(polyline)
        guard let pieces = draftTrim(target: ffi(hit), cutters: cutters, click: ffi(click)) else {
            return notice("draft_edit_no_crossing")
        }
        layer.replace(ids: [hit.id], with: pieces.map { layer.derive(from: hit, points: $0.points) })
        done(layer)
    }

    // MARK: 延伸

    private func extend(_ click: CGPoint, _ radius: CGFloat, _ layer: ProInkLayerView) {
        // 點的是「端點附近」：找端點離點擊最近的筆畫（比一般命中半徑大一點，端點好點）。
        guard let hit = layer.strokeNear(click, radius: radius * 2.2) else { return notice("draft_edit_nothing") }
        let boundaries = layer.polylines(excluding: [hit.id]).map(polyline)
        guard let longer = draftExtend(target: ffi(hit), near: ffi(click), boundaries: boundaries) else {
            return notice("draft_edit_no_boundary")
        }
        layer.replace(ids: [hit.id], with: [layer.derive(from: hit, points: longer)])
        done(layer)
    }

    // MARK: 圓角

    private func fillet(_ click: CGPoint, _ radius: CGFloat, _ layer: ProInkLayerView) {
        guard let hit = layer.strokeNear(click, radius: radius) else { return notice("draft_edit_nothing") }
        guard let one = first else {
            first = hit
            firstClick = click
            layer.setOverlay(strokes: [], marks: [click])
            drafting.toolHint = l("draft_hint_fillet_second")
            return
        }
        guard hit.id != one.id else { return }
        let r = Float(drafting.filletRadiusMm) * draftUnitsPerMm()
        guard let f = draftFillet(first: ffi(one), second: ffi(hit), radius: r, clickFirst: ffi(firstClick), clickSecond: ffi(click)) else {
            reset(layer: layer)
            drafting.toolHint = l("draft_hint_fillet_first")
            return notice("draft_edit_fillet_fail")
        }
        layer.replace(ids: [one.id, hit.id], with: [
            layer.derive(from: one, points: f.a),
            layer.derive(from: hit, points: f.b),
            layer.derive(from: one, points: f.arc),
        ])
        done(layer)
        drafting.toolHint = l("draft_hint_fillet_first")
    }

    // MARK: 偏移

    private func offset(_ click: CGPoint, _ radius: CGFloat, _ layer: ProInkLayerView) {
        guard let one = first else {
            guard let hit = layer.strokeNear(click, radius: radius) else { return notice("draft_edit_nothing") }
            first = hit
            firstClick = click
            layer.setOverlay(strokes: [], marks: [click])
            drafting.toolHint = l("draft_hint_offset_side")
            return
        }
        let distance = Float(drafting.offsetDistanceMm) * draftUnitsPerMm()
        guard let moved = draftOffset(points: ffi(one), distance: distance, side: ffi(click)) else {
            reset(layer: layer)
            drafting.toolHint = l("draft_hint_offset_first")
            return notice("draft_edit_offset_fail")
        }
        // 偏移是**多一條**平行線，原來那條留著。
        layer.insert(copies: [layer.derive(from: one, points: moved)])
        done(layer)
        drafting.toolHint = l("draft_hint_offset_first")
    }

    // MARK: 鏡射

    private func mirrored(_ strokes: [ProStroke], _ a: CGPoint, _ b: CGPoint) -> [ProStroke] {
        strokes.map { s in
            var copy = s
            copy.id = UUID().uuidString
            let m = draftMirror(points: ffi(s), a: ffi(a), b: ffi(b))
            for (k, q) in m.enumerated() where k < copy.points.count {
                copy.points[k].x = q.x
                copy.points[k].y = q.y
            }
            return copy
        }
    }

    private func preview(_ strokes: [ProStroke], marks: [CGPoint], layer: ProInkLayerView) {
        let items = strokes.map { s in
            FfiSheetStroke(
                points: s.points.map { FfiPoint(x: $0.x, y: $0.y) }, layer: s.layerId, lineType: s.lineTypeId,
                width: s.baseWidth, colorHex: Self.hex(s.colorRGBA))
        }
        layer.setOverlay(strokes: items, marks: marks)
    }

    private static func hex(_ rgba: [UInt8]) -> String {
        guard rgba.count >= 3 else { return "#000000" }
        return String(format: "#%02X%02X%02X", rgba[0], rgba[1], rgba[2])
    }

    private func mirror(_ phase: ProStrokeGestureRecognizer.ToolPhase, _ raw: CGPoint, _ radius: CGFloat, _ layer: ProInkLayerView) {
        let chosen = selectedStrokes(layer)
        guard !chosen.isEmpty else {
            if phase == .ended { notice("draft_edit_need_selection") }
            return
        }
        guard let a = axisStart else {
            guard phase == .ended else { return }
            axisStart = layer.snapAnchor(near: raw, radius: radius) ?? raw
            layer.setOverlay(strokes: [], marks: [axisStart!])
            drafting.toolHint = l("draft_hint_mirror_second")
            return
        }
        let b = layer.snapAnchor(near: raw, radius: radius) ?? raw
        guard hypot(b.x - a.x, b.y - a.y) > 2 else {
            if phase == .ended { reset(layer: layer) }
            return
        }
        switch phase {
        case .began, .moved:
            preview(mirrored(chosen, a, b), marks: [a, b], layer: layer)
        case .ended:
            layer.insert(copies: mirrored(chosen, a, b))
            done(layer)
            drafting.toolHint = l("draft_hint_mirror_first")
        case .cancelled:
            break
        }
    }

    // MARK: 陣列

    /// 矩形陣列：直接套用在選取的筆畫上。回傳做出幾份複本（0 = 沒東西可做）。
    @discardableResult
    func applyRectArray(rows: Int, cols: Int, dxMm: Double, dyMm: Double, layer: ProInkLayerView) -> Int {
        let chosen = selectedStrokes(layer)
        guard !chosen.isEmpty else { return 0 }
        var made: [ProStroke] = []
        for s in chosen {
            let copies = draftArrayRect(
                points: ffi(s), rows: UInt32(max(1, rows)), cols: UInt32(max(1, cols)),
                dx: Float(dxMm * Double(draftUnitsPerMm())), dy: Float(dyMm * Double(draftUnitsPerMm())))
            for c in copies { made.append(withPoints(s, c.points)) }
        }
        layer.insert(copies: made)
        return made.count
    }

    private func polar(_ click: CGPoint, _ radius: CGFloat, _ layer: ProInkLayerView) {
        let chosen = selectedStrokes(layer)
        guard !chosen.isEmpty else { return notice("draft_edit_need_selection") }
        let center = layer.snapAnchor(near: click, radius: radius) ?? click
        var made: [ProStroke] = []
        for s in chosen {
            let copies = draftArrayPolar(
                points: ffi(s), center: ffi(center), count: UInt32(max(1, drafting.polarCount)),
                totalDeg: Float(drafting.polarTotalDeg))
            for c in copies { made.append(withPoints(s, c.points)) }
        }
        layer.insert(copies: made)
        done(layer)
    }

    /// 複本：原筆畫的屬性與點數，位置換成 `points`（陣列的運算保持點數不變）。
    private func withPoints(_ s: ProStroke, _ points: [FfiPoint]) -> ProStroke {
        var copy = s
        copy.id = UUID().uuidString
        for (k, q) in points.enumerated() where k < copy.points.count {
            copy.points[k].x = q.x
            copy.points[k].y = q.y
        }
        return copy
    }
}

// MARK: - 矩形陣列的參數面板

/// 矩形陣列：列數、欄數、列距、欄距（紙上毫米）。做出來的複本不含原件。
struct DraftArraySheet: View {
    var onApply: (_ rows: Int, _ cols: Int, _ dxMm: Double, _ dyMm: Double) -> Void
    var onPolar: (_ count: Int, _ totalDeg: Double) -> Void

    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var polar = false
    @State private var rows = 2
    @State private var cols = 3
    @State private var dx: Double = 20
    @State private var dy: Double = 20
    @State private var count = 6
    @State private var total: Double = 360

    private func t(_ key: String) -> String { localizationManager.localized(key) }

    var body: some View {
        NavigationStack {
            Form {
                Picker(t("draft_array_title"), selection: $polar) {
                    Text(t("draft_array_mode_rect")).tag(false)
                    Text(t("draft_array_mode_polar")).tag(true)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("draft.array.mode")
                if polar {
                    Stepper("\(t("draft_array_count")): \(count)", value: $count, in: 2...72)
                        .accessibilityIdentifier("draft.array.count")
                    Stepper("\(t("draft_array_angle")): \(Int(total))", value: $total, in: 15...360, step: 15)
                        .accessibilityIdentifier("draft.array.angle")
                } else {
                    Stepper("\(t("draft_array_rows")): \(rows)", value: $rows, in: 1...20)
                        .accessibilityIdentifier("draft.array.rows")
                    Stepper("\(t("draft_array_cols")): \(cols)", value: $cols, in: 1...20)
                        .accessibilityIdentifier("draft.array.cols")
                    Stepper("\(t("draft_array_dx")): \(Int(dx))", value: $dx, in: -300...300, step: 5)
                        .accessibilityIdentifier("draft.array.dx")
                    Stepper("\(t("draft_array_dy")): \(Int(dy))", value: $dy, in: -300...300, step: 5)
                        .accessibilityIdentifier("draft.array.dy")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    if polar { onPolar(count, total) } else { onApply(rows, cols, dx, dy) }
                    dismiss()
                } label: {
                    Text(t(polar ? "draft_array_polar_go" : "draft_array_apply")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal).padding(.vertical, 8)
                .background(.bar)
                .accessibilityIdentifier("draft.array.apply")
            }
            .navigationTitle(t("draft_array_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("cancel")) { dismiss() }.accessibilityIdentifier("draft.array.close")
                }
            }
        }
        .presentationDetents([.medium])
    }
}
