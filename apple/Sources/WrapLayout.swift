//
//  WrapLayout.swift
//  Kairumo
//
//  工具列在窄寬度時的自動換行版面。
//
//  為什麼需要它：工具列原本用 `ViewThatFits` 在「有文字標籤」與「只有圖示」
//  兩種單行版本之間挑。但 `ViewThatFits` 在兩種都塞不下時會**無條件採用最後一個**，
//  結果就是整條工具列比視窗還寬、左右兩端被裁掉（iPad 直向與窄視窗都會發生）——
//  按鈕不是變小，是直接看不到也點不到。
//
//  把換行版當成 `ViewThatFits` 的最後一個候選，就永遠有一個一定塞得下的版本。
//

import SwiftUI

/// 由左至右排列、放不下就換行的版面。
///
/// 關鍵在於**每個按鈕都必須是這個 Layout 的直接子視圖**。
/// 舊版曾把筆刷群組包在 `HStack` 裡，整個群組變成單一子視圖，
/// 於是那一段永遠不換行、照樣溢出 —— 需要整組一起移動的（例如色盤）
/// 才刻意包成一個 `HStack`，其餘一律攤平。
struct WrapLayout: Layout {
    /// 同一列中相鄰元件的水平間距
    var spacing: CGFloat = 10
    /// 列與列之間的垂直間距
    var lineSpacing: CGFloat = 8

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func computeRows(maxWidth: CGFloat, sizes: [CGSize]) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for (index, size) in sizes.enumerated() {
            let additional = current.indices.isEmpty ? size.width : size.width + spacing
            if !current.indices.isEmpty, current.width + additional > maxWidth {
                rows.append(current)
                current = Row()
                current.indices = [index]
                current.width = size.width
                current.height = size.height
            } else {
                current.indices.append(index)
                current.width += additional
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(maxWidth: maxWidth, sizes: sizes)

        let contentWidth = rows.map(\.width).max() ?? 0
        let contentHeight = rows.reduce(0) { $0 + $1.height }
            + lineSpacing * CGFloat(max(0, rows.count - 1))

        return CGSize(width: contentWidth, height: contentHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let rows = computeRows(maxWidth: bounds.width, sizes: sizes)

        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = sizes[index]
                // 同一列的元件高度不一（有文字標籤的比較高），垂直置中才不會參差不齊
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }
}
