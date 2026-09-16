//
//  ShapeStudioView.swift
//  Kairumo
//
//  形狀與流程圖的插入與編修。
//
//  核心的形狀幾何（S-52）從一開始就在，包含 ISO 5807 的九個流程圖符號與
//  四份內建範本 —— 但**沒有任何平台呼叫過它們**。這一層把它們接出來。
//

import SwiftUI

/// 畫布上的一個形狀。
///
/// 外框照核心算好的頂點畫 —— 這一層不做任何幾何。自己畫一個「差不多的菱形」
/// 的話，同一張流程圖在 Android 上的頂點位置會不一樣，連接線的落點也就跟著錯。
public struct NoteShapeView: View {
    @Binding var shape: NoteShapeAttachment
    var isSelected: Bool
    /// 縮放拖曳中的即時尺寸。`nil` 代表用模型上的尺寸。
    ///
    /// 拖曳每一幀都寫回 `shape` 的話，整份筆記會跟著每一幀存檔。
    var overrideSize: CGSize? = nil
    var onEdit: () -> Void

    private var drawWidth: CGFloat { overrideSize?.width ?? shape.width }
    private var drawHeight: CGFloat { overrideSize?.height ?? shape.height }

    public var body: some View {
        let points = outlinePoints
        ZStack {
            Canvas { context, _ in
                guard points.count >= 2 else { return }
                var path = Path()
                // 頂點是畫布座標，這裡的畫布原點在物件左上角 —— 要減掉偏移。
                path.move(to: CGPoint(x: points[0].x - shape.x, y: points[0].y - shape.y))
                for point in points.dropFirst() {
                    path.addLine(to: CGPoint(x: point.x - shape.x, y: point.y - shape.y))
                }
                // 線狀形狀（線／箭頭／雙箭頭）只有兩個點，不能收尾也不能填色。
                if !shape.isLinear {
                    path.closeSubpath()
                    if let fill = fillColor {
                        context.fill(path, with: .color(fill))
                    }
                }
                context.stroke(path, with: .color(strokeColor), lineWidth: shape.lineWidth)

                for head in arrowHeadPoints where head.count >= 3 {
                    var tri = Path()
                    tri.move(to: CGPoint(x: head[0].x - shape.x, y: head[0].y - shape.y))
                    for point in head.dropFirst() {
                        tri.addLine(to: CGPoint(x: point.x - shape.x, y: point.y - shape.y))
                    }
                    tri.closeSubpath()
                    context.fill(tri, with: .color(strokeColor))
                }
            }
            .frame(width: drawWidth, height: drawHeight)

            if shape.acceptsText && !shape.label.isEmpty {
                Text(shape.label)
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .padding(6)
                    .frame(width: drawWidth, height: drawHeight)
            }
        }
        .frame(width: drawWidth, height: drawHeight)
        .overlay(
            Rectangle()
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onEdit)
    }

    /// 輪廓要用**畫出來的**尺寸算，不是模型尺寸 —— 否則拖曳縮放時
    /// 外框維持原大小，只有外面的框在動，看起來像壞掉。
    private var outlinePoints: [CGPoint] {
        guard let size = overrideSize else { return shape.outline() }
        var probe = shape
        probe.width = size.width
        probe.height = size.height
        return probe.outline()
    }

    private var arrowHeadPoints: [[CGPoint]] {
        guard let size = overrideSize else { return shape.arrowHeads() }
        var probe = shape
        probe.width = size.width
        probe.height = size.height
        return probe.arrowHeads()
    }

    private var strokeColor: Color {
        shape.strokeColorHex.flatMap(Color.init(hex:)) ?? .primary
    }

    private var fillColor: Color? {
        guard let hex = shape.fillColorHex else { return nil }
        // "clear" 是哨符不是顏色 —— 走顏色轉換會變成黑色。
        return hex == "clear" ? nil : Color(hex: hex)
    }
}

/// 形狀挑選面板：一般形狀、ISO 5807 流程圖符號、內建範本。
public struct ShapeStudioView: View {

    /// 插入的結果。範本會一次給出多個形狀與它們之間的連接線。
    public typealias Commit = (_ shapes: [NoteShapeAttachment], _ connections: [NoteConnectionAttachment]) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared
    private let onCommit: Commit

    public init(onCommit: @escaping Commit) {
        self.onCommit = onCommit
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section(
                        title: localizationManager.localized("shape_section_basic"),
                        kinds: allShapeKinds().filter { !flowchartShapeKinds().contains($0) }
                    )
                    section(
                        title: localizationManager.localized("shape_section_flowchart"),
                        kinds: flowchartShapeKinds()
                    )
                    templates
                }
                .padding(16)
            }
            .navigationTitle(localizationManager.localized("shape_studio"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) { dismiss() }
                }
            }
        }
    }

    /// 一格的邊長。
    ///
    /// **刻意做小。** 這裡的圖只是「這是什麼形狀」的示意，不是預覽 ——
    /// 每格 88pt 的話，五十幾個形狀要捲四五個螢幕才看得完，而使用者在
    /// 找的那一個十之八九不在第一屏。插進畫布之後尺寸本來就要自己調。
    private static let cellSide: CGFloat = 56

    private func section(title: String, kinds: [FfiShapeKind]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: Self.cellSide), spacing: 8)],
                spacing: 8
            ) {
                ForEach(kinds, id: \.self) { kind in
                    Button {
                        insert(kind)
                    } label: {
                        ShapeThumbnail(kind: kind)
                            .frame(width: Self.cellSide - 18, height: Self.cellSide - 18)
                            .frame(width: Self.cellSide, height: Self.cellSide)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(uiColor: .secondarySystemBackground))
                            )
                    }
                    .buttonStyle(.plain)
                    // 名稱與 ISO 5807 的語意改走輔助說明與長按預覽 ——
                    // 每一格都掛兩行字的話，格子就小不下來。
                    .help(label(for: kind))
                    .accessibilityLabel(label(for: kind))
                    .contextMenu {
                        Text(label(for: kind))
                        if let semantic = shapeSemantic(kind: kind) {
                            Text(semantic)
                        }
                    }
                }
            }
        }
    }

    /// 形狀的顯示名稱。
    ///
    /// 走語系表而不是 `NoteShapeAttachment.name(of:)` —— 後者是**持久化用的
    /// 識別字**（小寫的列舉名），拿來顯示的話，中文介面裡會出現
    /// 「arrowblockright」。
    private func label(for kind: FfiShapeKind) -> String {
        let key = "shape_kind_\(NoteShapeAttachment.name(of: kind))"
        let localized = localizationManager.localized(key)
        // 語系表裡沒有的（核心新增了形狀但字串還沒補）退回識別字，
        // 而不是顯示一個空白的格子。
        return localized == key ? NoteShapeAttachment.name(of: kind) : localized
    }

    private var templates: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizationManager.localized("shape_section_templates")).font(.headline)
            ForEach(flowchartTemplates(), id: \.id) { template in
                Button {
                    insert(template)
                } label: {
                    HStack {
                        Image(systemName: "square.on.square.dashed")
                        VStack(alignment: .leading) {
                            Text(template.id).font(.callout)
                            Text(localizationManager.localized("shape_node_count")
                                .replacingOccurrences(
                                    of: "%@", with: "\(template.nodes.count)"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func insert(_ kind: FfiShapeKind) {
        onCommit(
            [NoteShapeAttachment(kindName: NoteShapeAttachment.name(of: kind))],
            []
        )
        dismiss()
    }

    /// 插入一整份範本。
    ///
    /// 節點與連接線一起給出去 —— 只給節點的話，使用者得自己一條一條連，
    /// 那範本就沒有意義了。
    private func insert(_ template: FfiTemplate) {
        let origin = CGPoint(x: 60, y: 140)
        var shapes: [NoteShapeAttachment] = []
        for node in template.nodes {
            shapes.append(
                NoteShapeAttachment(
                    kindName: NoteShapeAttachment.name(of: node.kind),
                    x: origin.x + CGFloat(node.bounds.minX),
                    y: origin.y + CGFloat(node.bounds.minY),
                    width: CGFloat(node.bounds.maxX - node.bounds.minX),
                    height: CGFloat(node.bounds.maxY - node.bounds.minY),
                    label: node.label
                )
            )
        }
        var connections: [NoteConnectionAttachment] = []
        for edge in template.edges {
            let from = Int(edge.from)
            let to = Int(edge.to)
            guard shapes.indices.contains(from), shapes.indices.contains(to) else { continue }
            connections.append(
                NoteConnectionAttachment(
                    fromShapeId: shapes[from].id,
                    toShapeId: shapes[to].id,
                    label: edge.label
                )
            )
        }
        onCommit(shapes, connections)
        dismiss()
    }
}

/// 形狀的縮圖。與畫布上畫的是同一組頂點。
struct ShapeThumbnail: View {
    let kind: FfiShapeKind

    var body: some View {
        Canvas { context, size in
            let points = shapeOutline(
                shape: FfiShape(
                    kind: kind,
                    bounds: FfiRect(
                        minX: 2, minY: 2,
                        maxX: Float(size.width) - 2, maxY: Float(size.height) - 2
                    ),
                    cornerRadius: 4,
                    // 選單裡的預覽一律正放，才比較得出形狀本身的差別。
                    rotationDegrees: 0
                ),
                segments: 40
            )
            // 線、箭頭、雙箭頭的輪廓只有兩個點。用 `> 2` 擋掉的話它們
            // 整格都是空白 —— 選單裡那三格看起來像壞掉（實際發生過）。
            guard points.count >= 2 else { return }
            let isLinear = shapeIsLinear(kind: kind)
            var path = Path()
            path.move(to: CGPoint(x: CGFloat(points[0].x), y: CGFloat(points[0].y)))
            for point in points.dropFirst() {
                path.addLine(to: CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
            }
            // 線狀形狀不能收尾：折回去就成了零面積的圖形。
            if !isLinear { path.closeSubpath() }
            context.stroke(path, with: .color(.primary), lineWidth: 1.5)

            if isLinear {
                let heads = shapeArrowHeads(
                    shape: FfiShape(
                        kind: kind,
                        bounds: FfiRect(minX: 2, minY: 2,
                                        maxX: Float(size.width) - 2,
                                        maxY: Float(size.height) - 2),
                        cornerRadius: 4,
                        rotationDegrees: 0
                    ),
                    size: 8
                )
                for head in [heads.start, heads.end] where head.count >= 3 {
                    var tri = Path()
                    tri.move(to: CGPoint(x: CGFloat(head[0].x), y: CGFloat(head[0].y)))
                    for point in head.dropFirst() {
                        tri.addLine(to: CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
                    }
                    tri.closeSubpath()
                    context.fill(tri, with: .color(.primary))
                }
            }
        }
    }
}

/// 畫布上的形狀物件：可拖曳、可縮放、可刪除。
struct ShapeAttachmentItemView: View {
    @Binding var shape: NoteShapeAttachment
    /// 選取狀態由外面管 —— 群組要整組一起亮起來，各自為政的話做不到。
    let isSelected: Bool
    let onSelect: () -> Void
    /// 拖曳的位移。同一組的其他成員要跟著走，那是呼叫端的事。
    let onMove: (CGSize) -> Void
    let onDelete: () -> Void

    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var dragOffset: CGSize = .zero
    @State private var isEditingLabel: Bool = false
    @State private var isEditingStyle: Bool = false
    /// 縮放拖曳中的即時尺寸。直接改 shape.width 會每一幀都寫回筆記。
    @State private var liveSize: CGSize? = nil
    @State private var resizeBase: CGSize? = nil

    private var displayWidth: CGFloat { liveSize?.width ?? shape.width }
    private var displayHeight: CGFloat { liveSize?.height ?? shape.height }

    var body: some View {
        let currentX = shape.x + dragOffset.width
        let currentY = shape.y + dragOffset.height

        NoteShapeView(
            shape: $shape,
            isSelected: isSelected,
            overrideSize: liveSize,
            onEdit: { isEditingLabel = true }
        )
            // 圖形本體跟著轉；把手與刪除鈕掛在旋轉**外面**的 overlay，
            // 包進去的話拖曳算出的角度會疊加自身旋轉，圖形會失控加速。
            .rotationEffect(.degrees(shape.canvasRotation))
            .overlay {
                if isSelected {
                    GeometryReader { geo in
                        ObjectRotationHandle(degrees: $shape.canvasRotation, size: geo.size)
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.red)
                    }
                    .buttonStyle(.plain)
                    .offset(x: 10, y: -10)
                    .accessibilityLabel(localizationManager.localized("action_delete"))
                }
            }
            // 右下角縮放把手。形狀原本只能用插入時的預設尺寸 ——
            // 一個流程圖節點要配合文字長短，不能調大小等於不能用。
            .overlay(alignment: .bottomTrailing) {
                if isSelected {
                    Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                        .contentShape(Circle())
                        .offset(x: 10, y: 10)
                        .accessibilityLabel(localizationManager.localized("resize_shape"))
                        .help(localizationManager.localized("resize_shape"))
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 1,
                                        coordinateSpace: .named(CanvasCoordinateSpace.name))
                                .onChanged { value in
                                    let base = resizeBase ?? CGSize(width: shape.width, height: shape.height)
                                    if resizeBase == nil { resizeBase = base }
                                    // 下限比文字方塊小：箭頭與連接點本來就可以很短。
                                    liveSize = CGSize(
                                        width: max(24, base.width + value.translation.width),
                                        height: max(24, base.height + value.translation.height)
                                    )
                                }
                                .onEnded { _ in
                                    if let size = liveSize {
                                        shape.width = size.width
                                        shape.height = size.height
                                    }
                                    resizeBase = nil
                                    liveSize = nil
                                }
                        )
                }
            }
            // 樣式鈕。線條顏色與填滿顏色的欄位一直都在、也一直跟著同步走，
            // 但沒有任何介面改得到它們 —— 等於存在卻用不到。
            .overlay(alignment: .bottomLeading) {
                if isSelected {
                    Button { isEditingStyle = true } label: {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                    .offset(x: -10, y: 10)
                    .accessibilityLabel(localizationManager.localized("shape_style"))
                    .help(localizationManager.localized("shape_style"))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(CanvasCoordinateSpace.name))
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { _ in
                        onMove(dragOffset)
                        dragOffset = .zero
                    }
            )
            .onTapGesture(perform: onSelect)
            .position(x: currentX + displayWidth / 2, y: currentY + displayHeight / 2)
            .sheet(isPresented: $isEditingStyle) {
                ShapeStyleSheet(shape: $shape)
            }
            .alert(
                localizationManager.localized("shape_label"),
                isPresented: $isEditingLabel
            ) {
                TextField(localizationManager.localized("shape_label"), text: $shape.label)
                Button(localizationManager.localized("done")) { isEditingLabel = false }
            }
    }
}

/// 兩個形狀之間的連接線。路徑與箭頭都來自核心。
struct ConnectionLineView: View {
    let connection: NoteConnectionAttachment
    let geometry: ShapeGeometry.Connection

    var body: some View {
        Canvas { context, _ in
            var path = Path()
            path.move(to: geometry.path[0])
            for point in geometry.path.dropFirst() { path.addLine(to: point) }
            context.stroke(path, with: .color(color), lineWidth: connection.lineWidth)

            if geometry.arrowHead.count >= 3 {
                var head = Path()
                head.move(to: geometry.arrowHead[0])
                for point in geometry.arrowHead.dropFirst() { head.addLine(to: point) }
                head.closeSubpath()
                context.fill(head, with: .color(color))
            }
        }
        .allowsHitTesting(false)
    }

    private var color: Color {
        connection.colorHex.flatMap(Color.init(hex:)) ?? .primary
    }
}

/// 形狀的樣式編修：線條顏色、填滿顏色、線條粗細、標籤。
///
/// 這些欄位（`strokeColorHex` / `fillColorHex` / `lineWidth`）從一開始就在模型裡，
/// 也一直跟著跨平台同步走 —— 但沒有任何介面碰得到它們。插進畫布的形狀
/// 永遠是黑框白底，等於那三個欄位形同不存在。
struct ShapeStyleSheet: View {
    @Binding var shape: NoteShapeAttachment
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared

    /// 與文字方塊邊框用同一組顏色 —— 同一份筆記裡兩種物件的可選色不同，
    /// 使用者會以為是兩套系統。來源是核心的 `borderPalette()`。
    ///
    /// （原本這裡寫死 `#007AFF`，而文字方塊那邊是 `#0A84FF` —— 兩個都叫藍色，
    ///   但存進筆記的是不同的值。）
    private var palette: [String] { borderPalette().map(\.hex) }

    var body: some View {
        NavigationView {
            Form {
                if shape.acceptsText {
                    Section(localizationManager.localized("shape_label")) {
                        TextField(localizationManager.localized("shape_label"), text: $shape.label)
                    }
                }

                Section(localizationManager.localized("stroke_color")) {
                    swatches(selected: shape.strokeColorHex) { shape.strokeColorHex = $0 }
                }

                // 線狀形狀沒有內部可以填。放著只會讓人以為壞了。
                if !shape.isLinear {
                    Section(localizationManager.localized("fill_color")) {
                        swatches(selected: shape.fillColorHex,
                                 includeClear: true) { shape.fillColorHex = $0 }
                    }
                }

                Section(localizationManager.localized("line_width")) {
                    Picker("", selection: $shape.lineWidth) {
                        ForEach([1.0, 2.0, 3.0, 5.0], id: \.self) { w in
                            Text(String(format: "%.0f", w)).tag(CGFloat(w))
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(localizationManager.localized("shape_style"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized("done")) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func swatches(
        selected: String?,
        includeClear: Bool = false,
        set: @escaping (String?) -> Void
    ) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 8)],
                  alignment: .leading, spacing: 8) {
            if includeClear {
                Button { set(nil) } label: {
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.001))
                            .frame(width: 26, height: 26)
                            .overlay(Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 1))
                        // 透明畫一條斜線 —— 不畫的話它跟白色長得一樣。
                        Path { p in
                            p.move(to: CGPoint(x: 5, y: 21))
                            p.addLine(to: CGPoint(x: 21, y: 5))
                        }
                        .stroke(Color.red.opacity(0.7), lineWidth: 1.5)
                        .frame(width: 26, height: 26)
                        if selected == nil {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                        }
                    }
                }
                .buttonStyle(.plain)
                // 命中區與文字排版面板同一套作法：26pt 的圓在手指下太小。
                .frame(width: 38, height: 38)
                .contentShape(Rectangle())
                .accessibilityLabel(localizationManager.localized("color_transparent"))
                .help(localizationManager.localized("color_transparent"))
            }

            ForEach(palette, id: \.self) { hex in
                Button { set(hex) } label: {
                    Circle()
                        .fill(Color(hex: hex) ?? .gray)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle().stroke(
                                selected == hex ? Color.accentColor : Color.secondary.opacity(0.3),
                                lineWidth: selected == hex ? 2.5 : 1)
                        )
                }
                .buttonStyle(.plain)
                .frame(width: 38, height: 38)
                .contentShape(Rectangle())
            }
        }
    }
}
