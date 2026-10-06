import QuickLook
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

    private enum Tab: Hashable { case sheet, rotate, glass }
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
    @State private var tilt: Double = 40

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

    // 玻璃盒展開
    @State private var glassT: Double = 0
    @State private var glassPlaying = false
    @State private var glassThird = true
    @State private var glassYaw: Double = 30
    @State private var glassPitch: Double = 25
    @State private var glassCache = GlassBoundsCache()
    private static let glassTick = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    // 3D 匯出
    @State private var shareURL: SharedFile?
    @State private var arURL: SharedFile?
    @State private var exportNotice: String?

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
                depthFrac: Float(depthFrac), tiltDeg: Float(tilt)),
            fitWidth: Float(fit.width), fitHeight: Float(fit.height),
            hatchSpacing: Float(6 * ratio), dimensions: dimensions, sectionLabel: sectionLabel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    Text(t("solid_tab_sheet")).tag(Tab.sheet)
                    Text(t("solid_tab_rotate")).tag(Tab.rotate)
                    Text(t("solid_tab_glass")).tag(Tab.glass)
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
                    // 玻璃盒的播放與進度放在最上面：拉滑桿、看動畫要同時看得到預覽與控制。
                    if tab == .glass { glassSection }
                    profileSection
                    switch tab {
                    case .sheet:
                        sectionSection
                        layoutSection
                    case .rotate:
                        rotateSection
                    case .glass:
                        EmptyView()
                    }
                    exportSection
                }
            }
            .onReceive(Self.glassTick) { _ in advanceGlass() }
            .sheet(item: $shareURL) { item in ShareItemsSheet(items: [item.url]) }
            .fullScreenCover(item: $arURL) { item in QuickLookPreview(url: item.url) }
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
                case .glass:
                    drawGlass(&ctx, size: size, pad: pad, profile: profile)
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
            // 拖曳轉動觀看的角度（旋轉對照與玻璃盒共用）。
            .gesture(DragGesture(minimumDistance: 2).onChanged { value in
                guard tab != .sheet else { return }
                orbit(by: value.translation)
            }.onEnded { _ in lastDrag = .zero })
        }
    }

    @State private var lastDrag: CGSize = .zero

    private func orbit(by translation: CGSize) {
        let dx = translation.width - lastDrag.width, dy = translation.height - lastDrag.height
        lastDrag = translation
        if tab == .glass {
            glassYaw = max(-180, min(180, glassYaw + Double(dx) * 0.5))
            glassPitch = max(-90, min(90, glassPitch - Double(dy) * 0.5))
        } else {
            yaw = max(-180, min(180, yaw + Double(dx) * 0.5))
            pitch = max(-90, min(90, pitch - Double(dy) * 0.5))
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
                Text(t("solid_section_oblique")).tag(FfiSectionKind.oblique)
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
            case .oblique:
                slider(t("solid_angle"), $angle, 0...180, id: "solid.angle", format: "%.0f°")
                slider(t("solid_offset"), $offset, 0...1, id: "solid.offset", format: "%.2f")
                slider(t("solid_tilt"), $tilt, 5...85, id: "solid.tilt", format: "%.0f°")
                Toggle(t("solid_flip"), isOn: $flip)
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

    // MARK: 玻璃盒

    /// 整段動畫的畫面範圍只算一次（每換一個輪廓、深度或視角才重算）；每一格都重算會拖慢動畫。
    final class GlassBoundsCache {
        var key = ""
        var rect: [Float] = []
    }

    private func drawGlass(_ ctx: inout GraphicsContext, size: CGSize, pad: CGFloat, profile: FfiSolidProfile) {
        let key = "\(profile.outer.count)-\(profile.width)-\(profile.height)-\(depth)-\(glassThird)-\(Int(glassYaw))-\(Int(glassPitch))"
        if glassCache.key != key {
            glassCache.rect = solidGlassBounds(
                profile: profile, depth: Float(depth), thirdAngle: glassThird,
                yawDeg: Float(glassYaw), pitchDeg: Float(glassPitch)) ?? []
            glassCache.key = key
        }
        guard glassCache.rect.count == 4,
              let frame = solidGlassFrame(
                profile: profile, depth: Float(depth), thirdAngle: glassThird, t: Float(glassT),
                yawDeg: Float(glassYaw), pitchDeg: Float(glassPitch))
        else { return }
        let r = glassCache.rect
        let bw = CGFloat(max(r[2] - r[0], 1)), bh = CGFloat(max(r[3] - r[1], 1))
        // 範圍再留 6% 的邊：中間幾格可能比取樣的邊界稍微超出一點。
        let k = min((size.width - pad * 2) / bw, (size.height - pad * 2) / bh) * 0.94
        let ox = size.width / 2 - (CGFloat(r[0]) + bw / 2) * k
        let oy = size.height / 2 + (CGFloat(r[1]) + bh / 2) * k
        func map(_ x: Float, _ y: Float) -> CGPoint { CGPoint(x: ox + CGFloat(x) * k, y: oy - CGFloat(y) * k) }
        let fade = max(0, 1 - glassT * 3)
        // 由底到頂：投射線、面框、立體、隱藏線、實線。
        let order: [FfiGlassKind] = [.projection, .frame, .object, .hidden, .visible]
        for kind in order {
            for l in frame.lines where l.kind == kind {
                if kind == .projection && fade <= 0.01 { continue }
                var path = Path()
                path.move(to: map(l.ax, l.ay))
                path.addLine(to: map(l.bx, l.by))
                switch kind {
                case .projection:
                    ctx.stroke(path, with: .color(.blue.opacity(0.35 * fade)), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
                case .frame:
                    ctx.stroke(path, with: .color(.teal.opacity(0.8)), style: StrokeStyle(lineWidth: 1.2))
                case .object:
                    ctx.stroke(path, with: .color(.gray.opacity(0.55)), style: StrokeStyle(lineWidth: 1))
                case .hidden:
                    ctx.stroke(path, with: .color(.black.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                case .visible:
                    ctx.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
            }
        }
    }

    /// 播放中：每 1/30 秒往前走一格（約 4 秒展開完）；走到 1 就停。
    private func advanceGlass() {
        guard glassPlaying, tab == .glass else { return }
        glassT = min(1, glassT + (1.0 / 30.0) / 4.0)
        if glassT >= 1 { glassPlaying = false }
    }

    private var glassSection: some View {
        Section {
            Text(t("solid_glass_hint")).font(.footnote).foregroundColor(.secondary)
            HStack {
                Button {
                    if glassT >= 1 { glassT = 0 }
                    glassPlaying.toggle()
                } label: {
                    Label(
                        glassPlaying ? t("solid_glass_pause") : (glassT >= 1 ? t("solid_glass_replay") : t("solid_glass_play")),
                        systemImage: glassPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("solid.glass.play")
                Spacer()
                Toggle(t("solid_first_angle"), isOn: Binding(get: { !glassThird }, set: { glassThird = !$0 }))
                    .fixedSize()
                    .accessibilityIdentifier("solid.glass.first")
            }
            slider(t("solid_glass_progress"), Binding(get: { glassT }, set: { glassT = $0; glassPlaying = false }),
                   0...1, id: "solid.glass.t", format: "%.2f")
            slider(t("solid_yaw"), $glassYaw, -180...180, id: "solid.glass.yaw", format: "%.0f°")
            slider(t("solid_pitch"), $glassPitch, -90...90, id: "solid.glass.pitch", format: "%.0f°")
        }
    }

    // MARK: 3D 匯出

    private var exportSection: some View {
        Section(t("solid_export_title")) {
            ForEach(solidExportFormats(), id: \.self) { format in
                Button {
                    export(format: format, ar: false)
                } label: {
                    Label(t("solid_export_\(format)"), systemImage: "square.and.arrow.up")
                }
                .disabled(profile == nil)
                .accessibilityIdentifier("solid.export.\(format)")
            }
            Button {
                export(format: "usdz", ar: true)
            } label: {
                Label(t("solid_export_ar"), systemImage: "arkit")
            }
            .disabled(profile == nil)
            .accessibilityIdentifier("solid.export.ar")
            if let exportNotice { Text(exportNotice).font(.caption).foregroundColor(.red) }
            Text(t("solid_export_footer")).font(.footnote).foregroundColor(.secondary)
        }
    }

    /// 立體 → 檔案（一個頁面單位 = 1/每毫米單位數 毫米），寫進暫存資料夾，再交給分享表或 AR 預覽。
    private func export(format: String, ar: Bool) {
        exportNotice = nil
        guard let profile,
              let data = solidExport3d(profile: profile, depth: Float(depth), format: format, mmPerUnit: 1 / draftUnitsPerMm())
        else {
            exportNotice = t("solid_export_failed")
            return
        }
        let url = FileManager.default.temporaryDirectory.appending(path: "solid-\(UUID().uuidString.prefix(6)).\(format)")
        do {
            try Data(data).write(to: url, options: .atomic)
        } catch {
            exportNotice = t("solid_export_failed")
            return
        }
        if ar { arURL = SharedFile(url: url) } else { shareURL = SharedFile(url: url) }
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
