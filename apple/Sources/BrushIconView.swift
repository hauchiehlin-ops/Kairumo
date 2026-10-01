//
//  BrushIconView.swift
//  Kairumo
//
//  工具列上每支筆的向量圖示與筆跡預覽。
//
//  兩樣東西都由核心提供（`brushIcon`、`brushPreviewDabs`），這裡只負責照畫：
//  圖示是 `assets/brushes/*.svg` 解析出來的路徑指令，筆跡預覽是同一份筆點陣
//  （自繪引擎的筆刷是真正的筆跡，原生筆刷是模擬）。Android 畫的是同一組資料。

import SwiftUI

extension EditorToolType {
    /// 對應核心的工具列項目。
    var ffiTool: FfiTool {
        switch self {
        case .pen: return .pen
        case .ballpoint: return .ballPoint
        case .fineliner: return .fineliner
        case .brush: return .brush
        case .calligraphy: return .calligraphy
        case .pencil: return .pencil
        case .charcoal: return .charcoal
        case .crayon: return .crayon
        case .airbrush: return .airbrush
        case .oilpaint: return .oilPaint
        case .watercolor: return .watercolor
        case .marker: return .marker
        case .highlighter: return .highlighter
        case .eraser: return .eraser
        case .lasso: return .lasso
        case .maskingTape: return .maskingTape
        }
    }
}

/// 一支筆的向量圖示。`ink` 是使用者目前的筆色：圖示裡標成 `currentColor` 的部分會跟著換色。
struct BrushVectorIcon: View {
    let tool: EditorToolType
    let ink: Color

    var body: some View {
        // 解析一次就好：核心每次呼叫都會重新讀 SVG。
        let shapes = Self.shapes(for: tool)
        Canvas { context, size in
            let scale = min(size.width, size.height) / 48
            let origin = CGPoint(x: (size.width - 48 * scale) / 2, y: (size.height - 48 * scale) / 2)
            for shape in shapes {
                var path = Path()
                for command in shape.commands {
                    let a = command.args.map { CGFloat($0) }
                    func p(_ i: Int) -> CGPoint {
                        CGPoint(x: origin.x + a[i] * scale, y: origin.y + a[i + 1] * scale)
                    }
                    switch command.op {
                    case "M": path.move(to: p(0))
                    case "L": path.addLine(to: p(0))
                    case "C": path.addCurve(to: p(4), control1: p(0), control2: p(2))
                    case "Z": path.closeSubpath()
                    default: break
                    }
                }
                var layer = context
                layer.opacity = Double(shape.opacity)
                if let fill = Self.color(shape.fill, ink: ink) {
                    layer.fill(path, with: .color(fill))
                }
                if let stroke = Self.color(shape.stroke, ink: ink) {
                    layer.stroke(
                        path, with: .color(stroke),
                        style: StrokeStyle(
                            lineWidth: CGFloat(shape.strokeWidth) * scale,
                            lineCap: shape.roundCap ? .round : .butt, lineJoin: .round))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private static var cache: [EditorToolType: [FfiIconShape]] = [:]

    private static func shapes(for tool: EditorToolType) -> [FfiIconShape] {
        if let hit = cache[tool] { return hit }
        let parsed = brushIcon(tool: tool.ffiTool)
        cache[tool] = parsed
        return parsed
    }

    private static func color(_ paint: FfiPaint, ink: Color) -> Color? {
        switch paint {
        case .none: return nil
        case .ink: return ink
        case let .color(r, g, b): return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
        }
    }
}

/// 一小段示範筆跡，畫在圖示旁邊 —— 一眼看出這支筆畫出來是什麼樣子。
struct BrushStrokePreview: View {
    let tool: EditorToolType
    let ink: Color

    var body: some View {
        Canvas { context, size in
            let dabs = brushPreviewDabs(tool: tool.ffiTool, width: Float(size.width), height: Float(size.height))
            guard !dabs.isEmpty else { return }
            let resolved = UIColor(ink).resolvedColor(with: .current)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
            for dab in dabs {
                let s = CGFloat(dab.shade)
                let target: CGFloat = s >= 0 ? 1 : 0
                let k = abs(s) * 0.35
                let color = Color(
                    red: r + (target - r) * k, green: g + (target - g) * k, blue: b + (target - b) * k)
                var layer = context
                layer.translateBy(x: CGFloat(dab.x), y: CGFloat(dab.y))
                layer.rotate(by: .radians(Double(dab.angle)))
                let rx = CGFloat(dab.rx), ry = CGFloat(dab.ry)
                let alpha = Double(dab.alpha)
                if dab.softness > 0.5 {
                    for step in 0 ..< 4 {
                        let f = 1.0 - CGFloat(step) * 0.22
                        layer.fill(
                            Path(ellipseIn: CGRect(x: -rx * f, y: -ry * f, width: rx * f * 2, height: ry * f * 2)),
                            with: .color(color.opacity(alpha * 0.34)))
                    }
                } else {
                    layer.fill(
                        Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2)),
                        with: .color(color.opacity(alpha)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// 工具列上一顆筆刷按鈕的內容：圖示、示範筆跡、（選取時）凸起。
struct BrushToolContent: View {
    let tool: EditorToolType
    let isSelected: Bool
    let ink: Color

    var body: some View {
        VStack(spacing: 2) {
            BrushVectorIcon(tool: tool, ink: ink)
                .frame(width: 40, height: 40)
                .offset(y: isSelected ? -6 : 0)
                .shadow(color: .black.opacity(isSelected ? 0.25 : 0), radius: 4, x: 0, y: 4)
            if tool.isBrush {
                BrushStrokePreview(tool: tool, ink: ink)
                    .frame(width: 44, height: 14)
            }
        }
        .frame(width: 48, height: tool.isBrush ? 60 : 46)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(isSelected ? 0.14 : 0))
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        .contentShape(Rectangle())
    }
}
