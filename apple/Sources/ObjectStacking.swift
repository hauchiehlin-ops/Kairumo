//
//  ObjectStacking.swift
//  Kairumo
//
//  畫布物件的堆疊順序（誰疊在誰上面）。
//
//  在此之前，順序是**寫死在視圖樹裡**的：圖片永遠在文字下面、文字永遠在表格
//  下面，因為那幾個 ForEach 就是照那個次序排的。兩個物件疊在一起時，使用者
//  沒有任何辦法把下面那個拉上來 —— 只能刪掉重做。
//
//  圖層面板原本只認形狀（`ObjectLayerPanel` 綁的是 `[NoteShapeAttachment]`），
//  其餘六種型別碰不到。這一層把七種型別收斂成同一份順序。
//

import Foundation
import SwiftUI

/// 畫布上的一個可堆疊物件（跨型別的共同視角）。
public struct StackableObject: Identifiable, Hashable {
    public enum Kind: String, CaseIterable {
        case image, text, table, chart, model3D, link, shape, pin

        /// 沒有明確順序時的預設層級。
        ///
        /// 數值就是原本視圖樹裡的排列次序 —— 舊筆記沒有 `objectOrder`，
        /// 走這條路得到的疊放結果與過去完全相同。
        var defaultLayer: Int {
            switch self {
            case .image: return 0
            case .shape: return 1
            case .table: return 2
            case .chart: return 3
            case .model3D: return 4
            case .link: return 5
            case .text: return 6
            case .pin: return 7
            }
        }
    }

    public let id: String
    public let kind: Kind
    /// 面板上顯示的名字（文字方塊取內文、形狀取標籤…）。
    public let title: String
}

public enum ObjectStacking {

    /// 一個物件的 z 值。
    ///
    /// 在 `order` 裡的照它的位置；不在的排到後面，同型別之間保持原本的相對次序。
    /// 回傳 Double 是因為 SwiftUI 的 `.zIndex` 吃 Double。
    public static func zIndex(
        for id: String,
        kind: StackableObject.Kind,
        order: [String]?
    ) -> Double {
        if let index = order?.firstIndex(of: id) {
            return Double(index)
        }
        // 沒被排過的物件放在所有排過的之上，並照型別的預設層級分層。
        let base = Double((order?.count ?? 0) + 1)
        return base + Double(kind.defaultLayer)
    }

    /// 把目前畫布上的物件整理成一份由後到前的清單。
    ///
    /// 已經在 `order` 裡的照舊；新加進來的（還沒排過的）接在後面。
    /// 這樣使用者插入的新物件預設在最上層 —— 那是所有繪圖工具的共同慣例。
    public static func normalized(
        objects: [StackableObject],
        order: [String]?
    ) -> [String] {
        let present = Set(objects.map(\.id))
        // 已經刪掉的物件要從順序裡剔除，否則清單會無限長大。
        var result = (order ?? []).filter { present.contains($0) }
        let placed = Set(result)
        let newcomers = objects
            .filter { !placed.contains($0.id) }
            .sorted { $0.kind.defaultLayer < $1.kind.defaultLayer }
        result.append(contentsOf: newcomers.map(\.id))
        return result
    }

    // MARK: - 重新排序
    //
    // 四個動作與形狀圖層面板原本的一致（`ObjectLayer`），只是作用在跨型別的
    // 清單上。多選時整批一起動，而且**照它們目前的相對順序**動 ——
    // 不然多選搬移的結果會取決於 Set 的迭代順序，同樣的操作每次都不一樣。

    public static func bringToFront(_ ids: [String], in order: [String]) -> [String] {
        let moving = order.filter { ids.contains($0) }
        return order.filter { !ids.contains($0) } + moving
    }

    public static func sendToBack(_ ids: [String], in order: [String]) -> [String] {
        let moving = order.filter { ids.contains($0) }
        return moving + order.filter { !ids.contains($0) }
    }

    public static func bringForward(_ ids: [String], in order: [String]) -> [String] {
        var result = order
        // 由後往前處理：由前往後的話，先搬的會擋住後搬的。
        for id in order.filter({ ids.contains($0) }).reversed() {
            guard let index = result.firstIndex(of: id), index < result.count - 1 else { continue }
            // 已經在最上面的那個不動，但它上面若也是被選中的，整批就卡住不動 ——
            // 那是對的：一整組一起往上，遇到頂就停。
            if ids.contains(result[index + 1]) { continue }
            result.swapAt(index, index + 1)
        }
        return result
    }

    public static func sendBackward(_ ids: [String], in order: [String]) -> [String] {
        var result = order
        for id in order.filter({ ids.contains($0) }) {
            guard let index = result.firstIndex(of: id), index > 0 else { continue }
            if ids.contains(result[index - 1]) { continue }
            result.swapAt(index, index - 1)
        }
        return result
    }
}

// MARK: - 對齊

/// 對齊一組物件。
///
/// 幾何走核心的 `alignRects` —— 「靠左」的細節有好幾種合理答案（對齊到最左的
/// 物件還是選取範圍？置中用選取範圍還是頁面中線？），兩邊各寫一份就會各挑
/// 一種，而使用者在 iPad 上排好的版面到 Android 會跑掉。
public enum ObjectAlignment {

    /// 選單上的順序。分佈放最後，它與前六個不是同一類操作。
    public static let modes: [(mode: FfiAlignMode, key: String, symbol: String)] = [
        (.left, "align_left", "align.horizontal.left"),
        (.horizontalCenter, "align_center_h", "align.horizontal.center"),
        (.right, "align_right", "align.horizontal.right"),
        (.top, "align_top", "align.vertical.top"),
        (.verticalMiddle, "align_middle_v", "align.vertical.center"),
        (.bottom, "align_bottom", "align.vertical.bottom"),
        (.distributeHorizontally, "align_distribute_h", "distribute.horizontal"),
        (.distributeVertically, "align_distribute_v", "distribute.vertical")
    ]

    /// 算出每個矩形對齊後的新左上角。順序與輸入相同。
    public static func aligned(
        rects: [CGRect],
        mode: FfiAlignMode
    ) -> [CGPoint] {
        let input = rects.map {
            FfiRect(minX: Float($0.minX), minY: Float($0.minY),
                    maxX: Float($0.maxX), maxY: Float($0.maxY))
        }
        return alignRects(rects: input, mode: mode).map {
            CGPoint(x: CGFloat($0.x), y: CGFloat($0.y))
        }
    }
}

// MARK: - 跨型別的堆疊面板

/// 畫布上**所有**物件的堆疊面板。
///
/// 與 `ObjectLayerPanel` 的差別：那一個只認形狀，也只處理形狀陣列的順序
/// （形狀的群組操作留在那裡）。這一個認七種型別，改的是筆記上的
/// `objectOrder` —— 那才是使用者說的「圖層要能上下重新排序」。
public struct CanvasStackPanel: View {
    let objects: [StackableObject]
    @Binding var order: [String]
    @Binding var selection: Set<String>
    /// 對齊指定的那些物件。
    ///
    /// 選取清單由這個面板持有，並且**照目前的堆疊順序**傳出去 ——
    /// 用 `Set` 的迭代順序的話，同樣的操作每次得到的結果會不一樣。
    let onAlign: (FfiAlignMode, [String]) -> Void

    @ObservedObject private var localizationManager = LocalizationManager.shared

    public init(
        objects: [StackableObject],
        order: Binding<[String]>,
        selection: Binding<Set<String>>,
        onAlign: @escaping (FfiAlignMode, [String]) -> Void = { _, _ in }
    ) {
        self.objects = objects
        _order = order
        _selection = selection
        self.onAlign = onAlign
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if objects.isEmpty {
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
                        // 由上到下＝由前到後。那是圖層面板的慣例 ——
                        // 反過來的話使用者每按一次「上移」都要在腦中翻譯一次。
                        ForEach(rowsFrontToBack) { object in
                            rowView(object)
                        }
                    }
                }
                .frame(maxHeight: 220)

                Divider()
                orderButtons

                Divider()
                Text(localizationManager.localized("align_objects"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                alignButtons
                if selection.count < 2 {
                    // 只選一個時按鈕是停用的 —— 不說原因的話，使用者會以為壞了。
                    Text(localizationManager.localized("align_needs_two"))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .frame(width: 260)
    }

    /// 兩列四個。八個排成一列的話，在 260pt 寬的面板裡每個只剩 30pt。
    private var alignButtons: some View {
        VStack(spacing: 6) {
            ForEach([0, 1], id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(Array(ObjectAlignment.modes[(row * 4)..<(row * 4 + 4)]), id: \.key) { item in
                        Button {
                            onAlign(item.mode, orderedSelection)
                        } label: {
                            Image(systemName: item.symbol).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(selection.count < 2)
                        .help(localizationManager.localized(item.key))
                        .accessibilityLabel(localizationManager.localized(item.key))
                    }
                }
            }
        }
    }

    private var rowsFrontToBack: [StackableObject] {
        let byId = Dictionary(uniqueKeysWithValues: objects.map { ($0.id, $0) })
        return order.compactMap { byId[$0] }.reversed()
    }

    private func rowView(_ object: StackableObject) -> some View {
        let isSelected = selection.contains(object.id)
        return Button {
            if isSelected { selection.remove(object.id) } else { selection.insert(object.id) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon(for: object.kind))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(object.title)
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

    private func icon(for kind: StackableObject.Kind) -> String {
        switch kind {
        case .image: return "photo"
        case .text: return "textformat"
        case .table: return "tablecells"
        case .chart: return "chart.bar"
        case .model3D: return "cube"
        case .link: return "link"
        case .shape: return "square.on.circle"
        case .pin: return "bubble.left"
        }
    }

    private var orderButtons: some View {
        HStack(spacing: 6) {
            orderButton("layer_send_back", "arrow.down.to.line", ObjectStacking.sendToBack)
            orderButton("layer_send_backward", "arrow.down", ObjectStacking.sendBackward)
            orderButton("layer_bring_forward", "arrow.up", ObjectStacking.bringForward)
            orderButton("layer_bring_front", "arrow.up.to.line", ObjectStacking.bringToFront)
        }
    }

    private func orderButton(
        _ key: String,
        _ systemImage: String,
        _ op: @escaping ([String], [String]) -> [String]
    ) -> some View {
        Button {
            order = op(orderedSelection, order)
        } label: {
            Image(systemName: systemImage).frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(selection.isEmpty)
        .help(localizationManager.localized(key))
        .accessibilityLabel(localizationManager.localized(key))
    }

    /// 依目前堆疊順序排好的選取項 —— 見 `ObjectStacking` 裡的說明。
    private var orderedSelection: [String] {
        order.filter { selection.contains($0) }
    }
}
