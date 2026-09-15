//
//  HoverHighlight.swift
//  Kairumo
//
//  自訂樣式按鈕在 Mac 上的滑鼠回饋。
//
//  # 為什麼需要
//
//  面板裡的按鈕用 `.buttonStyle(.plain)` 配自己畫的背景（要的是方形色塊，
//  不是系統膠囊）。代價是**在 Mac 上完全沒有 hover 回饋** —— 滑鼠移過去
//  什麼都不會變，使用者不知道那是不是可以按的。
//
//  iPad 上看不出來，因為沒有游標。實機比對過兩張截圖：滑鼠在按鈕上與不在，
//  像素完全一致。
//

import SwiftUI

/// 滑鼠移入時加一層淡色高亮。
private struct HoverHighlight: ViewModifier {
    @State private var isHovering = false
    /// 高亮的圓角要跟底下的背景一致，不然會露出一圈。
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.primary.opacity(isHovering ? 0.10 : 0))
                    // 高亮疊在按鈕自己的背景**上面**會蓋住選取態的強調色，
                    // 所以用 background 疊在下面，只在未選取時看得出來。
                    .allowsHitTesting(false)
            )
            .onHover { isHovering = $0 }
            // 觸控裝置也有指標（iPad 外接滑鼠／觸控板）—— 一併給。
            .hoverEffect(.lift)
    }
}

public extension View {
    /// 讓自訂樣式的按鈕在 Mac 上對滑鼠有反應。
    func hoverHighlight(cornerRadius: CGFloat = 6) -> some View {
        modifier(HoverHighlight(cornerRadius: cornerRadius))
    }
}
