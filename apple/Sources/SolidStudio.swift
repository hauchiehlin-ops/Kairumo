import SwiftUI

/// 立體輔助：草圖拉伸 → 三視圖／等角圖／剖面，插進頁面；或旋轉立體對照。
///
/// 幾何全在核心（`padnote-solid`），這裡只有畫面：預覽畫的就是插入時寫進頁面的那組線，
/// 所以「預覽長這樣、插進去就長這樣」。
struct SolidStudioSheet: View {
    /// 目前頁面的大小（頁面單位）。決定插入時圖紙的範圍。
    let pageSize: CGSize
    /// 這一頁上所有手繪線的點，用來從草圖找輪廓。
    let sketchPolylines: () -> [[CGPoint]]
    let onInsert: (FfiSolidSheet) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared

    private enum Tab: Hashable { case sheet, rotate }
    @State private var tab: Tab = .sheet

    // 輪廓
    @State private var presetId = "u_shape"
    @State private var width: Double = 240
    @State private var height: Double = 180
    @State private var depth: Double = 140
    @State private var sketchProfile: FfiSolidProfile?
    @State private var sketchNotice: String?

    // 剖面
    @State private var kind: FfiSectionKind = .none
    @State private var angle: Double = 90
    @State private var offset: Double = 0.5
    @State private var offset2: Double = 0.7
    @State private var step: Double = 0.5
    @State private var delta: Double = 30
    @State private var flip = true
    @State private var depthFrac: Double = 0.5

    // 排版
    @State private var firstAngle = false
    @State private var includeIso = true
    @State private var projection = true
    @State private var centerLines = true
    @State private var dimensions = false
    @State private var sectionLabel = false

    // 旋轉對照
    @State private var yaw: Double = 35
    @State private var pitch: Double = 25

    private func t(_ key: String) -> String { localizationManager.localized(key) }

    private var profile: FfiSolidProfile? {
        sketchProfile ?? solidPresetProfile(name: presetId, w: Float(width), h: Float(height))
    }

    /// 插入頁面時圖紙的範圍。
    private var pageFit: CGSize {
        CGSize(width: max(200, pageSize.width * 0.8), height: max(200, pageSize.height * 0.5))
    }

    private func options(fit: CGSize, ratio: CGFloat) -> FfiSolidSheetOptions {
        FfiSolidSheetOptions(
            firstAngle: firstAngle, includeIso: includeIso, projectionLines: projection,
            centerLines: centerLines,
            section: FfiSolidSection(
                kind: kind, angleDeg: Float(angle), offset: Float(offset), offset2: Float(offset2),
                step: Float(step), pivotX: 0.5, pivotY: 0.5, deltaDeg: Float(delta), flip: flip,
                depthFrac: Float(depthFrac)),
            fitWidth: Float(fit.width), fitHeight: Float(fit.height),
            hatchSpacing: Float(6 * ratio), dimensions: dimensions, sectionLabel: sectionLabel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    Text(t("solid_tab_sheet")).tag(Tab.sheet)
                    Text(t("solid_tab_rotate")).tag(Tab.rotate)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .accessibilityIdentifier("solid.tab")

                preview
                    .frame(height: 300)
                    .background(Color.white)
                    .overlay(Rectangle().stroke(Color.secondary.opacity(0.3)))
                    .padding(.horizontal)
                    .accessibilityIdentifier("solid.preview")

                Form {
                    profileSection
                    if tab == .sheet {
                        sectionSection
                        layoutSection
                    } else {
                        rotateSection
                    }
                }
            }
            .navigationTitle(t("solid_studio"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(t("solid_insert")) { insert() }
                        .fontWeight(.bold)
                        .disabled(profile == nil)
                        .accessibilityIdentifier("solid.insert")
                }
            }
        }
    }

    // MARK: 預覽

    @ViewBuilder private var preview: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let pad: CGFloat = 16
                let fit = CGSize(width: size.width - pad * 2, height: size.height - pad * 2)
                guard fit.width > 40, fit.height > 40, let profile else { return }
                switch tab {
                case .sheet:
                    let ratio = fit.width / pageFit.width
                    guard let sheet = solidComposeSheet(
                        profile: profile, depth: Float(depth), options: options(fit: fit, ratio: ratio))
                    else { return }
                    let ox = pad + (fit.width - CGFloat(sheet.width)) / 2
                    let oy = pad + (fit.height - CGFloat(sheet.height)) / 2
                    for s in sheet.strokes.sorted(by: { $0.layer < $1.layer }) {
                        draw(s, in: &ctx, origin: CGPoint(x: ox, y: oy), widthScale: ratio)
                    }
                case .rotate:
                    guard let view = solidView(
                        profile: profile, depth: Float(depth), yawDeg: Float(yaw), pitchDeg: Float(pitch),
                        fitWidth: Float(fit.width), fitHeight: Float(fit.height))
                    else { return }
                    let ox = pad + (fit.width - CGFloat(view.width)) / 2
                    let oy = pad + (fit.height - CGFloat(view.height)) / 2
                    for l in view.lines {
                        var path = Path()
                        path.move(to: CGPoint(x: ox + CGFloat(l.ax), y: oy + CGFloat(l.ay)))
                        path.addLine(to: CGPoint(x: ox + CGFloat(l.bx), y: oy + CGFloat(l.by)))
                        ctx.stroke(path, with: .color(.black),
                                   style: StrokeStyle(lineWidth: l.hidden ? 1 : 2, lineCap: .round,
                                                      dash: l.hidden ? [5, 4] : []))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func draw(_ s: FfiSheetStroke, in ctx: inout GraphicsContext, origin: CGPoint, widthScale: CGFloat) {
        guard s.points.count >= 2 else { return }
        var path = Path()
        path.move(to: CGPoint(x: origin.x + CGFloat(s.points[0].x), y: origin.y + CGFloat(s.points[0].y)))
        for p in s.points.dropFirst() {
            path.addLine(to: CGPoint(x: origin.x + CGFloat(p.x), y: origin.y + CGFloat(p.y)))
        }
        let c = DraftingState.rgba(fromHex: s.colorHex)
        let color = Color(red: Double(c[0]) / 255, green: Double(c[1]) / 255, blue: Double(c[2]) / 255)
        let pattern = draftLinePattern(lineType: s.lineType).map { CGFloat($0) * widthScale }
        ctx.stroke(path, with: .color(color),
                   style: StrokeStyle(lineWidth: max(0.8, CGFloat(s.width) * widthScale * 1.1),
                                      lineCap: .butt, dash: pattern))
    }

    // MARK: 設定

    private var profileSection: some View {
        Section(t("solid_profile")) {
            Picker(t("solid_profile"), selection: Binding(
                get: { sketchProfile == nil ? presetId : "" },
                set: { id in
                    guard !id.isEmpty else { return }
                    presetId = id
                    sketchProfile = nil
                    sketchNotice = nil
                })
            ) {
                if sketchProfile != nil { Text(t("solid_sketch_used")).tag("") }
                ForEach(solidPresets(), id: \.self) { id in
                    Text(t("solid_preset_\(id)")).tag(id)
                }
            }
            .accessibilityIdentifier("solid.preset")

            Button {
                useSketch()
            } label: {
                Label(t("solid_from_sketch"), systemImage: "scribble.variable")
            }
            .accessibilityIdentifier("solid.fromSketch")

            if let sketchNotice {
                Text(sketchNotice).font(.caption).foregroundColor(.secondary)
            }
            if sketchProfile == nil {
                slider(t("solid_width"), $width, 60...600, id: "solid.width")
                slider(t("solid_height"), $height, 60...600, id: "solid.height")
            }
            slider(t("solid_depth"), $depth, 20...600, id: "solid.depth")
        }
    }

    private var sectionSection: some View {
        Section(t("solid_section")) {
            Picker(t("solid_section"), selection: $kind) {
                Text(t("solid_section_none")).tag(FfiSectionKind.none)
                Text(t("solid_section_full")).tag(FfiSectionKind.full)
                Text(t("solid_section_stepped")).tag(FfiSectionKind.stepped)
                Text(t("solid_section_rotated")).tag(FfiSectionKind.rotated)
                Text(t("solid_section_parallel")).tag(FfiSectionKind.parallel)
            }
            .accessibilityIdentifier("solid.sectionKind")

            switch kind {
            case .none:
                EmptyView()
            case .full:
                slider(t("solid_angle"), $angle, 0...180, id: "solid.angle", format: "%.0f°")
                slider(t("solid_offset"), $offset, 0...1, id: "solid.offset", format: "%.2f")
                Toggle(t("solid_flip"), isOn: $flip)
            case .stepped:
                slider(t("solid_angle"), $angle, 0...180, id: "solid.angle", format: "%.0f°")
                slider(t("solid_offset"), $offset, 0...1, id: "solid.offset", format: "%.2f")
                slider(t("solid_offset2"), $offset2, 0...1, id: "solid.offset2", format: "%.2f")
                slider(t("solid_step"), $step, 0...1, id: "solid.step", format: "%.2f")
                Toggle(t("solid_flip"), isOn: $flip)
            case .rotated:
                slider(t("solid_angle"), $angle, 0...180, id: "solid.angle", format: "%.0f°")
                slider(t("solid_delta"), $delta, -80...80, id: "solid.delta", format: "%.0f°")
                Toggle(t("solid_flip"), isOn: $flip)
            case .parallel:
                slider(t("solid_depth_pos"), $depthFrac, 0...1, id: "solid.depthFrac", format: "%.2f")
            }
        }
    }

    private var layoutSection: some View {
        Section {
            Toggle(t("solid_first_angle"), isOn: $firstAngle)
            Toggle(t("solid_iso"), isOn: $includeIso)
            Toggle(t("solid_projection"), isOn: $projection)
            Toggle(t("solid_centerlines"), isOn: $centerLines)
            Toggle(t("solid_dimensions"), isOn: $dimensions).accessibilityIdentifier("solid.dimensions")
            if kind != .none {
                Toggle(t("solid_section_label"), isOn: $sectionLabel).accessibilityIdentifier("solid.sectionLabel")
            }
        }
    }

    private var rotateSection: some View {
        Section {
            slider(t("solid_yaw"), $yaw, -180...180, id: "solid.yaw", format: "%.0f°")
            slider(t("solid_pitch"), $pitch, -90...90, id: "solid.pitch", format: "%.0f°")
        }
    }

    private func slider(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>,
                        id: String, format: String = "%.0f") -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text(String(format: format, value.wrappedValue)).font(.caption).foregroundColor(.secondary)
            }
            Slider(value: value, in: range).accessibilityIdentifier(id)
        }
    }

    // MARK: 動作

    private func useSketch() {
        let strokes = sketchPolylines().map { $0.map { FfiPoint(x: Float($0.x), y: Float($0.y)) } }
        if let found = solidProfileFromStrokes(strokes: strokes) {
            sketchProfile = found
            sketchNotice = t("solid_sketch_used")
        } else {
            sketchNotice = t("solid_sketch_none")
        }
    }

    private func insert() {
        guard let profile, let sheet = solidComposeSheet(
            profile: profile, depth: Float(depth), options: options(fit: pageFit, ratio: 1))
        else { return }
        onInsert(sheet)
        dismiss()
    }
}
