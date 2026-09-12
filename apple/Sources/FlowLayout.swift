//
//  FlowLayout.swift
//  Kairumo
//
//  自動換行的水平排列容器
//

import SwiftUI

/// 水平排列、放不下就換行的版面。
///
/// 取代工具列原本的「橫向捲動」：捲動雖然不會裁掉按鈕，但使用者看不到的東西
/// 就等於不存在 —— 得先知道有東西才會想去撥它。換行之後所有按鈕在任何視窗
/// 寬度下都同時可見，代價是工具列會變高、吃掉一點畫布高度。
///
/// 需要 iOS 16 的 `Layout` protocol（專案部署目標即為 16.0）。
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8
    /// 每一行內子視圖的垂直對齊方式。
    var alignment: VerticalAlignment = .center

    struct Line {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    /// 依可用寬度把子視圖切成數行。
    private func lines(for proposal: ProposedViewSize, subviews: Subviews) -> ([Line], CGSize) {
        // 沒有給寬度時（例如被放進 ScrollView）退化成單行，
        // 否則會以 0 寬計算而每個元素各佔一行。
        let maxWidth = proposal.width ?? .infinity

        var result: [Line] = []
        var current = Line()

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width

            if needed > maxWidth && !current.indices.isEmpty {
                result.append(current)
                current = Line()
                current.indices = [index]
                current.width = size.width
                current.height = size.height
            } else {
                current.width = needed
                current.height = max(current.height, size.height)
                current.indices.append(index)
            }
        }
        if !current.indices.isEmpty { result.append(current) }

        let totalHeight = result.reduce(0) { $0 + $1.height }
            + lineSpacing * CGFloat(max(0, result.count - 1))
        let totalWidth = result.map(\.width).max() ?? 0
        return (result, CGSize(width: totalWidth, height: totalHeight))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        lines(for: proposal, subviews: subviews).1
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let (rows, _) = lines(for: proposal, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                let dy: CGFloat
                switch alignment {
                case .top: dy = 0
                case .bottom: dy = row.height - size.height
                default: dy = (row.height - size.height) / 2
                }
                subviews[index].place(
                    at: CGPoint(x: x, y: y + dy),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }
}


/// 工具列群組之間的垂直分隔線。
///
/// 不用 `Divider()`：它在沒有 `HStack` 容器時預設是**水平**線，
/// 放進 `FlowLayout` 只會變成一小段橫槓。這裡直接畫一條有確定尺寸的直線。
struct ToolbarSeparator: View {
    var height: CGFloat = 26

    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.25))
            .frame(width: 1, height: height)
    }
}
