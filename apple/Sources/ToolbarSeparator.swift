//
//  ToolbarSeparator.swift
//  Kairumo
//
//  工具列群組之間的垂直分隔線
//

import SwiftUI

/// 工具列群組之間的垂直分隔線。
///
/// 不用 `Divider()`：它會依容器決定方向，在某些排版下會變成一條橫線。
/// 這裡直接畫一條有確定尺寸的直線，行為可預期。
struct ToolbarSeparator: View {
    var height: CGFloat = 26

    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.25))
            .frame(width: 1, height: height)
    }
}
