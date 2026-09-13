//
//  StrokeWidthSlider.swift
//  Kairumo
//
//  可拖曳的筆寬控制，附即時筆頭預覽。
//
//  # 為什麼在四個點點之外還要這個
//
//  點點給的是「常用的四種」，一下就選到；滑桿給的是「就是要這個粗細」。
//  只有點點的話，想要 5pt 的人永遠只能在 4 與 8 之間挑一個。
//
//  # 預覽為什麼重要
//
//  數字不會告訴使用者「8pt 有多粗」。旁邊那個圓點就是**畫出來會是多粗**，
//  而且與游標的筆頭用同一組尺寸推算（`BrushCursor.tipDiameter`）——
//  拖到一半就看得出夠不夠粗，不必先畫一筆再擦掉。
//

import SwiftUI

struct StrokeWidthSlider: View {
    @Binding var width: CGFloat
    let tool: EditorToolType
    let color: Color

    @ObservedObject private var localizationManager = LocalizationManager.shared

    /// 可選範圍。上限 30pt：再粗就不是在寫字了，而滑桿的精度會整個被吃掉。
    static let range: ClosedRange<CGFloat> = 1...30

    /// 預覽圓點的顯示上限。
    ///
    /// 與工具列的高度有關 —— 真的按 30pt 畫出來的話會把整條工具列撐高。
    static let previewCap: CGFloat = 22

    /// 預覽圓點的直徑。與游標筆頭同一組推算，只是夾在工具列放得下的範圍內。
    var previewDiameter: CGFloat {
        min(BrushCursor.tipDiameter(for: tool, strokeWidth: width), Self.previewCap)
    }

    var body: some View {
        HStack(spacing: 8) {
            Slider(value: $width, in: Self.range)
                .frame(width: 110)
                .help("\(localizationManager.localized("stroke_width")) \(Int(width))pt")

            // 目前粗細：數字 + 實際筆頭
            HStack(spacing: 5) {
                Text("\(Int(width))")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                    .frame(width: 18, alignment: .trailing)

                Circle()
                    .fill(tool == .eraser ? Color.clear : color)
                    .overlay(
                        Circle().stroke(
                            tool == .eraser ? Color.secondary : Color.clear,
                            lineWidth: 1.5)
                    )
                    .frame(width: previewDiameter, height: previewDiameter)
                    .frame(width: Self.previewCap, height: Self.previewCap)
            }
        }
    }
}
