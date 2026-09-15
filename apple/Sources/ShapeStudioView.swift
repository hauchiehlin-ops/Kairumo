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
    var onEdit: () -> Void

    public var body: some View {
        let points = shape.outline()
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

                for head in shape.arrowHeads() where head.count >= 3 {
                    var tri = Path()
                    tri.move(to: CGPoint(x: head[0].x - shape.x, y: head[0].y - shape.y))
                    for point in head.dropFirst() {
                        tri.addLine(to: CGPoint(x: point.x - shape.x, y: point.y - shape.y))
                    }
                    tri.closeSubpath()
                    context.fill(tri, with: .color(strokeColor))
                }
            }
            .frame(width: shape.width, height: shape.height)

            if shape.acceptsText && !shape.label.isEmpty {
                Text(shape.label)
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .padding(6)
                    .frame(width: shape.width, height: shape.height)
            }
        }
        .frame(width: shape.width, height: shape.height)
        .overlay(
            Rectangle()
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onEdit)
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

    private func section(title: String, kinds: [FfiShapeKind]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 10)], spacing: 10) {
                ForEach(kinds, id: \.self) { kind in
                    Button {
                        insert(kind)
                    } label: {
                        VStack(spacing: 6) {
                            ShapeThumbnail(kind: kind)
                                .frame(height: 40)
                            Text(NoteShapeAttachment.name(of: kind))
                                .font(.caption2)
                                .lineLimit(1)
                            // ISO 5807 的語意直接寫出來 —— 使用者不必記得
                            // 哪個符號代表什麼。
                            if let semantic = shapeSemantic(kind: kind) {
                                Text(semantic)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(uiColor: .secondarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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

    var body: some View {
        let currentX = shape.x + dragOffset.width
        let currentY = shape.y + dragOffset.height

        NoteShapeView(shape: $shape, isSelected: isSelected, onEdit: { isEditingLabel = true })
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
            .position(x: currentX + shape.width / 2, y: currentY + shape.height / 2)
            .alert(
                localizationManager.localized("shape_label"),
                isPresented: $isEditingLabel
            ) {
                TextField(localizationManager.localized("shape_label"), text: $shape.label)
                Button(localizationManager.localized("action_done")) { isEditingLabel = false }
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
