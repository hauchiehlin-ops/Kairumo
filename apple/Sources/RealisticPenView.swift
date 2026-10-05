//
//  RealisticPenView.swift
//  Kairumo
//
//  仿 Apple 原生 Markup / Tool Picker 模式之實體擬真筆刷視圖與物理浮起動畫。
//  （次世代 UI/UX 第五階段：實體筆刷擬真渲染與動態手勢回饋）
//

import SwiftUI

/// 實體擬真筆身幾何與渲染元件
public struct RealisticPenView: View {
    public let tool: EditorToolType
    public let isSelected: Bool
    public let inkColor: Color
    public let strokeWidth: CGFloat
    public let isVertical: Bool

    public init(
        tool: EditorToolType,
        isSelected: Bool,
        inkColor: Color,
        strokeWidth: CGFloat = 2.5,
        isVertical: Bool = true
    ) {
        self.tool = tool
        self.isSelected = isSelected
        self.inkColor = inkColor
        self.strokeWidth = strokeWidth
        self.isVertical = isVertical
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 筆身結構本體
            penBodyStructure
                .frame(width: 24, height: 58)
                // 物理浮起動畫：被選取時向上突起 12pt 並投射環境陰影，未選取時靜止於筆槽基座
                .offset(y: isSelected ? -12 : 0)
                .shadow(
                    color: isSelected ? Color.black.opacity(0.28) : Color.black.opacity(0.04),
                    radius: isSelected ? 5 : 1,
                    x: 0,
                    y: isSelected ? 6 : 1
                )
                .animation(.spring(response: 0.32, dampingFraction: 0.72), value: isSelected)
        }
        .frame(width: 28, height: 68)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var penBodyStructure: some View {
        switch tool {
        case .pen, .brush, .watercolor:
            FountainPenBody(color: inkColor, isSelected: isSelected, strokeWidth: strokeWidth)
        case .ballpoint:
            BallpointPenBody(color: inkColor, isSelected: isSelected)
        case .highlighter, .marker:
            HighlighterPenBody(color: inkColor, isSelected: isSelected)
        case .pencil:
            PencilBody(color: inkColor, isSelected: isSelected)
        case .eraser:
            EraserBody(isSelected: isSelected)
        case .lasso:
            LassoStylusBody(isSelected: isSelected)
        case .maskingTape:
            MaskingTapeBody(isSelected: isSelected)
        case .drafting:
            LassoStylusBody(isSelected: isSelected)
        }
    }
}

// MARK: - 鋼筆／書法筆／水彩（錐形金屬雙色筆尖、黑色亮面握位、筆幅標籤）

private struct FountainPenBody: View {
    let color: Color
    let isSelected: Bool
    let strokeWidth: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            // 1. 筆尖（金屬倒角與墨水沾染）
            Canvas { context, size in
                let w = size.width
                let h = size.height
                var nibPath = Path()
                nibPath.move(to: CGPoint(x: w * 0.5, y: 0))
                nibPath.addLine(to: CGPoint(x: w, y: h))
                nibPath.addLine(to: CGPoint(x: 0, y: h))
                nibPath.closeSubpath()

                // 金屬底質
                context.fill(nibPath, with: .linearGradient(
                    Gradient(colors: [Color(white: 0.92), Color(white: 0.65), Color(white: 0.85)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: w, y: h)
                ))

                // 筆尖墨水色染
                var tipInk = Path()
                tipInk.move(to: CGPoint(x: w * 0.5, y: 0))
                tipInk.addLine(to: CGPoint(x: w * 0.75, y: h * 0.45))
                tipInk.addLine(to: CGPoint(x: w * 0.25, y: h * 0.45))
                tipInk.closeSubpath()
                context.fill(tipInk, with: .color(color))

                // 筆尖中縫呼吸孔
                var slit = Path()
                slit.move(to: CGPoint(x: w * 0.5, y: 0))
                slit.addLine(to: CGPoint(x: w * 0.5, y: h * 0.7))
                context.stroke(slit, with: .color(Color(white: 0.25)), lineWidth: 0.8)
            }
            .frame(height: 14)

            // 2. 金屬領圈箍
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color(white: 0.85), Color(white: 0.5), Color(white: 0.9)],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(height: 3)

            // 3. 握位（染有墨水之色環）
            Rectangle()
                .fill(color)
                .frame(height: 5)

            // 4. 筆身（曜石黑啞光，印有筆幅讀數）
            ZStack {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color(white: 0.28), Color(white: 0.12), Color(white: 0.22)],
                        startPoint: .leading, endPoint: .trailing
                    ))

                if isSelected {
                    Text(String(format: "%.1f", strokeWidth))
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.85))
                        .rotationEffect(.degrees(90))
                }
            }
            .clipShape(RoundedCornerShape(radius: 3, corners: [.bottomLeft, .bottomRight]))
        }
    }
}

// MARK: - 原子筆（針管筆頭、微型滾珠、鍍鉻光澤金屬夾）

private struct BallpointPenBody: View {
    let color: Color
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 針管筆頭
            ZStack(alignment: .top) {
                // 滾珠
                Circle()
                    .fill(color)
                    .frame(width: 3.5, height: 3.5)

                // 針管金屬套柱
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color(white: 0.85), Color(white: 0.6)],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: 4, height: 8)
                    .padding(.top, 2)
            }
            .frame(height: 10)

            // 階梯金屬承座
            Canvas { context, size in
                let w = size.width
                let h = size.height
                var p = Path()
                p.move(to: CGPoint(x: w * 0.35, y: 0))
                p.addLine(to: CGPoint(x: w * 0.65, y: 0))
                p.addLine(to: CGPoint(x: w, y: h))
                p.addLine(to: CGPoint(x: 0, y: h))
                p.closeSubpath()
                context.fill(p, with: .linearGradient(
                    Gradient(colors: [Color(white: 0.75), Color(white: 0.45), Color(white: 0.75)]),
                    startPoint: .zero, endPoint: CGPoint(x: w, y: 0)
                ))
            }
            .frame(height: 6)

            // 色環
            Rectangle()
                .fill(color)
                .frame(height: 4)

            // 筆桿
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color(white: 0.88), Color(white: 0.72), Color(white: 0.84)],
                    startPoint: .leading, endPoint: .trailing
                ))
                .clipShape(RoundedCornerShape(radius: 2, corners: [.bottomLeft, .bottomRight]))
        }
    }
}

// MARK: - 螢光筆（斜切厚實鑿形筆尖、半透明螢光墨水層）

private struct HighlighterPenBody: View {
    let color: Color
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 斜切鑿形筆頭
            Canvas { context, size in
                let w = size.width
                let h = size.height
                var chisel = Path()
                chisel.move(to: CGPoint(x: w * 0.2, y: 0))
                chisel.addLine(to: CGPoint(x: w * 0.9, y: h * 0.35))
                chisel.addLine(to: CGPoint(x: w * 0.85, y: h))
                chisel.addLine(to: CGPoint(x: w * 0.15, y: h))
                chisel.closeSubpath()

                // 螢光鮮豔半透明色
                context.fill(chisel, with: .color(color.opacity(0.92)))
            }
            .frame(height: 12)

            // 黑色粗頸部
            Rectangle()
                .fill(Color(white: 0.18))
                .frame(width: 18, height: 5)

            // 粗厚方圓筆身
            ZStack {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color(white: 0.32), Color(white: 0.18), Color(white: 0.28)],
                        startPoint: .leading, endPoint: .trailing
                    ))

                // 筆腹螢光大色條
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.85))
                    .frame(width: 14, height: 18)
            }
            .clipShape(RoundedCornerShape(radius: 4, corners: [.bottomLeft, .bottomRight]))
        }
    }
}

// MARK: - 鉛筆（天然切削六角原木錐、深黑石墨筆芯）

private struct PencilBody: View {
    let color: Color
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 削尖錐形（木質部＋石墨芯）
            Canvas { context, size in
                let w = size.width
                let h = size.height

                // 木質部錐形
                var wood = Path()
                wood.move(to: CGPoint(x: w * 0.5, y: 0))
                wood.addLine(to: CGPoint(x: w, y: h))
                wood.addLine(to: CGPoint(x: 0, y: h))
                wood.closeSubpath()
                context.fill(wood, with: .color(Color(red: 0.88, green: 0.72, blue: 0.52)))

                // 石墨核心
                var lead = Path()
                lead.move(to: CGPoint(x: w * 0.5, y: 0))
                lead.addLine(to: CGPoint(x: w * 0.65, y: h * 0.38))
                lead.addLine(to: CGPoint(x: w * 0.35, y: h * 0.38))
                lead.closeSubpath()
                context.fill(lead, with: .color(Color(white: 0.18)))
            }
            .frame(height: 14)

            // 六棱鉛筆身（經典金黃/亮橘木身）
            HStack(spacing: 0) {
                Rectangle().fill(Color(red: 0.95, green: 0.68, blue: 0.18))
                Rectangle().fill(Color(red: 0.82, green: 0.55, blue: 0.10))
                Rectangle().fill(Color(red: 0.98, green: 0.75, blue: 0.24))
            }
            .clipShape(RoundedCornerShape(radius: 2, corners: [.bottomLeft, .bottomRight]))
        }
    }
}

// MARK: - 橡皮擦（粉紅/亮白斜切橡皮塊、深灰鋼印底座）

private struct EraserBody: View {
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 橡皮擦圓角頭（經典櫻花粉紅橡皮）
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(
                    colors: [Color(red: 0.98, green: 0.65, blue: 0.72), Color(red: 0.92, green: 0.52, blue: 0.62)],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(height: 18)

            // 包覆金屬箍
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color(white: 0.8), Color(white: 0.45), Color(white: 0.75)],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(height: 4)

            // 黑色握把筆桿
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color(white: 0.25), Color(white: 0.12)],
                    startPoint: .leading, endPoint: .trailing
                ))
                .clipShape(RoundedCornerShape(radius: 3, corners: [.bottomLeft, .bottomRight]))
        }
    }
}

// MARK: - 套索選取工具（高科技流線手寫筆、虛線選取環徽記）

private struct LassoStylusBody: View {
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 觸控細圓球尖
            Circle()
                .fill(Color(white: 0.35))
                .frame(width: 5, height: 5)

            // 導向圓錐
            Canvas { context, size in
                let w = size.width
                let h = size.height
                var p = Path()
                p.move(to: CGPoint(x: w * 0.4, y: 0))
                p.addLine(to: CGPoint(x: w * 0.6, y: 0))
                p.addLine(to: CGPoint(x: w, y: h))
                p.addLine(to: CGPoint(x: 0, y: h))
                p.closeSubpath()
                context.fill(p, with: .color(Color(white: 0.88)))
            }
            .frame(height: 7)

            // 筆身（銀白霧面鋁合金＋套索標誌）
            ZStack {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color(white: 0.96), Color(white: 0.82), Color(white: 0.92)],
                        startPoint: .leading, endPoint: .trailing
                    ))

                Image(systemName: "lasso")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.accentColor)
            }
            .clipShape(RoundedCornerShape(radius: 3, corners: [.bottomLeft, .bottomRight]))
        }
    }
}

// MARK: - 遮蔽膠帶（和紙膠帶花紋）

private struct MaskingTapeBody: View {
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 鋸齒膠帶頭
            Canvas { context, size in
                let w = size.width
                let h = size.height
                var p = Path()
                p.move(to: CGPoint(x: 0, y: h))
                p.addLine(to: CGPoint(x: w * 0.25, y: 0))
                p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.5))
                p.addLine(to: CGPoint(x: w * 0.75, y: 0))
                p.addLine(to: CGPoint(x: w, y: h))
                p.closeSubpath()
                context.fill(p, with: .color(Color(red: 0.95, green: 0.88, blue: 0.68)))
            }
            .frame(height: 7)

            // 和紙膠帶本體
            ZStack {
                Rectangle()
                    .fill(Color(red: 0.92, green: 0.85, blue: 0.62))

                Image(systemName: "bandage.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 0.72, green: 0.65, blue: 0.42))
            }
            .clipShape(RoundedCornerShape(radius: 2, corners: [.bottomLeft, .bottomRight]))
        }
    }
}

// MARK: - 幾何輔助形狀（部分圓角形）

private struct RoundedCornerShape: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
