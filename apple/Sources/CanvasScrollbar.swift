//
//  CanvasScrollbar.swift
//  Kairumo
//
//  可用滑鼠拖曳的畫布捲軸。
//
//  為什麼要自己做：iOS 的捲動指示器（scroll indicator）是**純顯示**的，不接受
//  互動 —— 在 iPad 上沒差，但在 Mac 上跑（Catalyst 或 Designed for iPad）時，
//  使用者會很自然地想用游標去拖那條捲軸，結果拖不動。
//  這裡畫一條自己的捲軸，接受拖曳並直接設定畫布的 contentOffset。
//

import SwiftUI

struct CanvasScrollbar: View {
    /// 可見區域佔內容的比例（0~1）
    let visibleFraction: CGFloat
    /// 目前捲動位置比例（0~1）
    let scrollFraction: CGFloat
    /// 使用者拖曳時回報新的比例
    let onScrub: (CGFloat) -> Void

    @State private var isDragging = false
    @GestureState private var dragStart: CGFloat? = nil

    private let barWidth: CGFloat = 12
    private let minThumb: CGFloat = 44

    var body: some View {
        GeometryReader { geo in
            let track = geo.size.height
            let thumbH = max(minThumb, track * min(1, max(0.02, visibleFraction)))
            let travel = max(track - thumbH, 0)
            let y = travel * min(1, max(0, scrollFraction))

            ZStack(alignment: .top) {
                Capsule()
                    .fill(Color.secondary.opacity(isDragging ? 0.14 : 0.07))
                    .frame(width: barWidth)

                Capsule()
                    .fill(Color.secondary.opacity(isDragging ? 0.75 : 0.45))
                    .frame(width: barWidth - 3, height: thumbH)
                    .offset(y: y)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                            .updating($dragStart) { value, state, _ in
                                if state == nil { state = value.startLocation.y - y }
                            }
                            .onChanged { value in
                                isDragging = true
                                let grab = dragStart ?? thumbH / 2
                                let newY = value.location.y - grab
                                guard travel > 0 else { return }
                                onScrub(min(1, max(0, newY / travel)))
                            }
                            .onEnded { _ in isDragging = false }
                    )
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .coordinateSpace(name: Self.space)
            // 點軌道任一處直接跳過去
            .contentShape(Rectangle())
            .onTapGesture { location in
                guard travel > 0 else { return }
                let target = (location.y - thumbH / 2) / travel
                onScrub(min(1, max(0, target)))
            }
        }
        .frame(width: barWidth + 6)
        .opacity(visibleFraction >= 1 ? 0 : 1)
        .animation(.easeInOut(duration: 0.15), value: isDragging)
    }

    private static let space = "kairumo.canvas.scrollbar"
}
