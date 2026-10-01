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

/// 一支筆的向量圖示。`ink` 是使用者目前的筆色：圖示裡標成 `currentColor` 的部分（含漸層色標）會跟著換色。
struct BrushVectorIcon: View {
    let tool: EditorToolType
    let ink: Color

    var body: some View {
        // 解析一次就好：核心每次呼叫都會重新讀 SVG。
        let shapes = Self.shapes(for: tool)
        let inkRGB = Self.rgb(of: ink)
        Canvas { context, size in
            let scale = min(size.width, size.height) / 48
            let origin = CGPoint(x: (size.width - 48 * scale) / 2, y: (size.height - 48 * scale) / 2)
            func point(_ x: Float, _ y: Float) -> CGPoint {
                CGPoint(x: origin.x + CGFloat(x) * scale, y: origin.y + CGFloat(y) * scale)
            }
            for shape in shapes {
                var path = Path()
                for command in shape.commands {
                    let a = command.args
                    switch command.op {
                    case "M": path.move(to: point(a[0], a[1]))
                    case "L": path.addLine(to: point(a[0], a[1]))
                    case "C": path.addCurve(to: point(a[4], a[5]), control1: point(a[0], a[1]), control2: point(a[2], a[3]))
                    case "Z": path.closeSubpath()
                    default: break
                    }
                }
                var layer = context
                layer.opacity = Double(shape.opacity)
                if let fill = Self.shading(shape.fill, ink: ink, inkRGB: inkRGB, scale: scale, point: point) {
                    layer.fill(path, with: fill)
                }
                if let stroke = Self.shading(shape.stroke, ink: ink, inkRGB: inkRGB, scale: scale, point: point) {
                    layer.stroke(
                        path, with: stroke,
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

    private static func rgb(of color: Color) -> (r: Double, g: Double, b: Double) {
        let resolved = UIColor(color).resolvedColor(with: .current)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    /// 色標的顏色：固定 RGB，或筆色再向黑／白偏 `shade`（-1…1，最多偏 100%）。
    private static func stopColor(_ stop: FfiGradientStop, inkRGB: (r: Double, g: Double, b: Double)) -> Color {
        var r = stop.ink ? inkRGB.r : Double(stop.r) / 255
        var g = stop.ink ? inkRGB.g : Double(stop.g) / 255
        var b = stop.ink ? inkRGB.b : Double(stop.b) / 255
        let target: Double = stop.shade >= 0 ? 1 : 0
        let k = Double(abs(stop.shade))
        r += (target - r) * k
        g += (target - g) * k
        b += (target - b) * k
        return Color(red: r, green: g, blue: b).opacity(Double(stop.alpha))
    }

    private static func shading(
        _ paint: FfiPaint, ink: Color, inkRGB: (r: Double, g: Double, b: Double), scale: CGFloat,
        point: (Float, Float) -> CGPoint
    ) -> GraphicsContext.Shading? {
        switch paint {
        case .none:
            return nil
        case .ink:
            return .color(ink)
        case let .color(r, g, b):
            return .color(Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255))
        case let .linear(x1, y1, x2, y2, stops):
            let gradient = Gradient(stops: stops.map {
                Gradient.Stop(color: stopColor($0, inkRGB: inkRGB), location: CGFloat($0.offset))
            })
            return .linearGradient(gradient, startPoint: point(x1, y1), endPoint: point(x2, y2))
        case let .radial(cx, cy, r, stops):
            let gradient = Gradient(stops: stops.map {
                Gradient.Stop(color: stopColor($0, inkRGB: inkRGB), location: CGFloat($0.offset))
            })
            return .radialGradient(gradient, center: point(cx, cy), startRadius: 0, endRadius: CGFloat(r) * scale)
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
                .frame(width: 44, height: 44)
                .offset(y: isSelected ? -6 : 0)
                .shadow(color: .black.opacity(isSelected ? 0.25 : 0), radius: 4, x: 0, y: 4)
            if tool.isBrush {
                BrushStrokePreview(tool: tool, ink: ink)
                    .frame(width: 44, height: 14)
            }
        }
        .frame(width: 52, height: tool.isBrush ? 64 : 50)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(isSelected ? 0.14 : 0))
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        .contentShape(Rectangle())
    }
}
