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
                    // 一般形狀、立體圖、流程圖四組（ISO 5807 的分類）：分組與順序都來自核心，
                    // 與 Android 同一份。
                    ForEach(shapeCategories(), id: \.self) { category in
                        section(
                            title: localizationManager.localized(Self.sectionKey(category)),
                            kinds: shapeKindsIn(category: category)
                        )
                    }
                    templates
                }
                .padding(16)
            }
            .navigationTitle(localizationManager.localized("shape_studio"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // 與其他五張插入面板一致的識別碼 —— 稽核要靠它確認
                    // 這張表真的打開了（S-261d 那一批的同一個理由）。
                    Button(localizationManager.localized("cancel")) { dismiss() }
                        .accessibilityIdentifier("shape.cancel")
                }
            }
        }
    }

    private static func sectionKey(_ category: FfiShapeCategory) -> String {
        switch category {
        case .basic: return "shape_section_basic"
        case .solid: return "shape_section_solid"
        case .flowProcess: return "shape_section_flow_process"
        case .flowData: return "shape_section_flow_data"
        case .flowControl: return "shape_section_flow_control"
        case .flowSpecial: return "shape_section_flow_special"
        }
    }

    /// 範本的顯示名稱。語系表沒有的退回識別碼，不顯示空白。
    private func templateName(_ id: String) -> String {
        let key = "shape_template_" + id.replacingOccurrences(of: ".", with: "_")
        let text = localizationManager.localized(key)
        return text == key ? id : text
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
        ShapeKindLabel.text(for: kind)
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
                            Text(templateName(template.id)).font(.callout)
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
        onCommit([NoteShapeAttachment.inserting(kind)], [])
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
                    cornerRadius: shapeDefaultCornerRadius(
                        kind: kind, width: Float(size.width), height: Float(size.height)),
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
            if shapeDrawsOutline(kind: kind) {
                context.stroke(path, with: .color(.primary), lineWidth: 1.5)
            }
            // 立體圖的面與稜線、流程圖符號裡的線。
            let thumbShape = FfiShape(
                kind: kind,
                bounds: FfiRect(minX: 2, minY: 2,
                                maxX: Float(size.width) - 2, maxY: Float(size.height) - 2),
                cornerRadius: shapeDefaultCornerRadius(
                    kind: kind, width: Float(size.width), height: Float(size.height)),
                rotationDegrees: 0
            )
            for detail in shapeDetails(shape: thumbShape, segments: 40) where detail.points.count >= 2 {
                var d = Path()
                d.move(to: CGPoint(x: CGFloat(detail.points[0].x), y: CGFloat(detail.points[0].y)))
                for p in detail.points.dropFirst() {
                    d.addLine(to: CGPoint(x: CGFloat(p.x), y: CGFloat(p.y)))
                }
                if detail.closed {
                    d.closeSubpath()
                    if detail.tone < 0 { context.fill(d, with: .color(.primary.opacity(0.18))) }
                }
                context.stroke(
                    d, with: .color(.primary),
                    style: StrokeStyle(lineWidth: 1, dash: detail.dashed ? [3, 2] : []))
            }

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
