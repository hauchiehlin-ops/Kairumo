//
//  ObjectLayerPanel.swift
//  Kairumo
//
//  形狀的圖層面板：堆疊順序與群組。
//
//  # 為什麼需要一個面板
//
//  核心的物件樹從一開始就有完整的堆疊與群組操作，也有列舉出口，但兩個平台的
//  介面只做到「選取」與「搬動」—— 使用者碰得到物件，卻**碰不到它們的順序**。
//  兩個方塊疊在一起時沒有任何辦法把下面那個拉上來。
//
//  # 順序的定義
//
//  陣列的順序就是堆疊順序：索引 0 在最底層，最後一個在最上面。畫布上的
//  `ForEach` 依同一個順序畫，所以清單與畫面永遠一致。
//
//  面板由上到下顯示的是**由前到後**（最上層在最前面），那是圖層面板的慣例 ——
//  反過來的話使用者每按一次「上移」都要在腦中翻譯一次。
//

import SwiftUI

/// 形狀的堆疊與群組操作。
///
/// 抽成獨立型別而不是寫在視圖裡：這些操作要被測試，而視圖測不了。
/// 每一個都直接改 `shapes` 陣列 —— 陣列的順序就是堆疊順序。
public enum ObjectLayerOps {

    /// 把 `id` 移到最上層。
    public static func bringToFront(_ id: String, in shapes: inout [NoteShapeAttachment]) {
        move(id, in: &shapes) { _, count in count - 1 }
    }

    public static func sendToBack(_ id: String, in shapes: inout [NoteShapeAttachment]) {
        move(id, in: &shapes) { _, _ in 0 }
    }

    public static func bringForward(_ id: String, in shapes: inout [NoteShapeAttachment]) {
        move(id, in: &shapes) { index, count in min(index + 1, count - 1) }
    }

    public static func sendBackward(_ id: String, in shapes: inout [NoteShapeAttachment]) {
        move(id, in: &shapes) { index, _ in max(index - 1, 0) }
    }

    private static func move(
        _ id: String,
        in shapes: inout [NoteShapeAttachment],
        to destination: (_ index: Int, _ count: Int) -> Int
    ) {
        guard let index = shapes.firstIndex(where: { $0.id == id }) else { return }
        let target = destination(index, shapes.count)
        guard target != index, shapes.indices.contains(target) else { return }
        let item = shapes.remove(at: index)
        shapes.insert(item, at: target)
    }

    /// 把選取的形狀收成一組。
    ///
    /// 少於兩個不成組 —— 一個物件的「群組」沒有意義，而且解散之後使用者會
    /// 發現什麼也沒變，只會覺得按鈕壞了。
    @discardableResult
    public static func group(
        _ ids: Set<String>, in shapes: inout [NoteShapeAttachment]
    ) -> String? {
        let members = shapes.filter { ids.contains($0.id) }
        guard members.count > 1 else { return nil }
        let groupId = UUID().uuidString
        for index in shapes.indices where ids.contains(shapes[index].id) {
            shapes[index].groupId = groupId
        }
        return groupId
    }

    /// 解散一個群組。成員留在原地，只是不再是一組。
    public static func ungroup(_ groupId: String, in shapes: inout [NoteShapeAttachment]) {
        for index in shapes.indices where shapes[index].groupId == groupId {
            shapes[index].groupId = nil
        }
    }

    /// 同一組的其他成員。
    ///
    /// 選到群組裡的一個，整組都要一起動 —— 那正是群組的意義。
    public static func groupMates(
        of id: String, in shapes: [NoteShapeAttachment]
    ) -> Set<String> {
        guard let groupId = shapes.first(where: { $0.id == id })?.groupId else { return [id] }
        return Set(shapes.filter { $0.groupId == groupId }.map(\.id))
    }

    /// 面板要顯示的項目：群組收成一列，未分組的形狀各自一列。
    public struct Row: Identifiable, Equatable {
        public let id: String
        public let isGroup: Bool
        public let memberCount: Int
        public let label: String
        public let kindName: String
    }

    /// 由**前到後**列出（最上層在最前面）—— 那是圖層面板的慣例。
    public static func rows(
        for shapes: [NoteShapeAttachment], unnamed: String, groupLabel: (Int) -> String
    ) -> [Row] {
        var rows: [Row] = []
        var seenGroups: Set<String> = []
        for shape in shapes.reversed() {
            if let groupId = shape.groupId {
                guard !seenGroups.contains(groupId) else { continue }
                seenGroups.insert(groupId)
                let count = shapes.filter { $0.groupId == groupId }.count
                rows.append(
                    Row(id: groupId, isGroup: true, memberCount: count,
                        label: groupLabel(count), kindName: "group"))
            } else {
                rows.append(
                    Row(id: shape.id, isGroup: false, memberCount: 1,
                        label: shape.label.isEmpty ? unnamed : shape.label,
                        kindName: shape.kindName))
            }
        }
        return rows
    }
}

/// 圖層面板。
public struct ObjectLayerPanel: View {
    @Binding var shapes: [NoteShapeAttachment]
    @Binding var selection: Set<String>

    @ObservedObject private var localizationManager = LocalizationManager.shared

    public init(shapes: Binding<[NoteShapeAttachment]>, selection: Binding<Set<String>>) {
        _shapes = shapes
        _selection = selection
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if shapes.isEmpty {
                Text(localizationManager.localized("layers_empty"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                Text(localizationManager.localized("layers_hint"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(rows) { row in
                            rowView(row)
                        }
                    }
                }
                .frame(maxHeight: 220)

                Divider()
                orderButtons
                groupButtons
            }
        }
        .padding(12)
        .frame(width: 260)
    }

    private var rows: [ObjectLayerOps.Row] {
        ObjectLayerOps.rows(
            for: shapes,
            unnamed: localizationManager.localized("layer_unnamed"),
            groupLabel: { count in
                localizationManager.localized("layer_group_name")
                    .replacingOccurrences(of: "%@", with: "\(count)")
            }
        )
    }

    private func rowView(_ row: ObjectLayerOps.Row) -> some View {
        let ids = memberIds(of: row)
        let isSelected = !ids.isEmpty && ids.isSubset(of: selection)
        return Button {
            // 選群組＝選它的全部成員。只選群組本身的話，接下來的每一個
            // 操作都得再判斷一次「這是群組還是形狀」。
            if isSelected {
                selection.subtract(ids)
            } else {
                selection.formUnion(ids)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: row.isGroup ? "square.on.square" : "square")
                    .foregroundStyle(row.isGroup ? Color.accentColor : .secondary)
                Text(row.label)
                    .font(.footnote)
                    .lineLimit(1)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func memberIds(of row: ObjectLayerOps.Row) -> Set<String> {
        row.isGroup
            ? Set(shapes.filter { $0.groupId == row.id }.map(\.id))
            : [row.id]
    }

    private var orderButtons: some View {
        HStack(spacing: 6) {
            orderButton("layer_send_back", "arrow.down.to.line") { id in
                ObjectLayerOps.sendToBack(id, in: &shapes)
            }
            orderButton("layer_send_backward", "arrow.down") { id in
                ObjectLayerOps.sendBackward(id, in: &shapes)
            }
            orderButton("layer_bring_forward", "arrow.up") { id in
                ObjectLayerOps.bringForward(id, in: &shapes)
            }
            orderButton("layer_bring_front", "arrow.up.to.line") { id in
                ObjectLayerOps.bringToFront(id, in: &shapes)
            }
        }
    }

    private func orderButton(
        _ key: String, _ systemImage: String, _ action: @escaping (String) -> Void
    ) -> some View {
        Button {
            // 整組一起動：群組裡的成員不能被拆散在不同的層裡，
            // 否則別的東西會夾在它們中間。
            for id in orderedSelection { action(id) }
        } label: {
            Image(systemName: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(selection.isEmpty)
        .help(localizationManager.localized(key))
        .accessibilityLabel(localizationManager.localized(key))
    }

    /// 依目前的堆疊順序排好的選取項。
    ///
    /// 不排的話，多選時的搬移結果會取決於 `Set` 的迭代順序 ——
    /// 同樣的操作每次得到的順序都不一樣。
    private var orderedSelection: [String] {
        shapes.map(\.id).filter { selection.contains($0) }
    }

    private var groupButtons: some View {
        HStack(spacing: 6) {
            Button {
                ObjectLayerOps.group(selection, in: &shapes)
            } label: {
                Label(localizationManager.localized("layer_group"), systemImage: "square.on.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(selection.count < 2)

            Button {
                for groupId in selectedGroupIds {
                    ObjectLayerOps.ungroup(groupId, in: &shapes)
                }
            } label: {
                Label(localizationManager.localized("layer_ungroup"),
                      systemImage: "square.on.square.dashed")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(selectedGroupIds.isEmpty)
        }
        .font(.caption)
    }

    private var selectedGroupIds: Set<String> {
        Set(shapes.filter { selection.contains($0.id) }.compactMap(\.groupId))
    }
}
