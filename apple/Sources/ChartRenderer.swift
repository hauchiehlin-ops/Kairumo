//
//  ChartRenderer.swift
//  Kairumo
//
//  把核心算好的圖表幾何畫出來。
//
//  # 這裡不做任何計算
//
//  每一個座標都來自核心的 `chartLayout(...)`。這層只負責「把這些形狀畫出來」
//  —— 一旦在這裡多算一步（哪怕只是把長條往上挪兩點），Android 就不會跟著挪，
//  同一張圖在兩個平台上就長得不一樣了。
//
//  繪製只寫一份（`draw(_:in:)`，走 Core Graphics），螢幕預覽與插入畫布用的
//  點陣圖都走它。寫兩份的話，預覽好看、插進去卻不一樣，而使用者要到插入後
//  才會發現。
//

import SwiftUI
import UIKit

public enum ChartRenderer {

    /// 算出一張圖的版面。規格有問題時回 `nil` —— 呼叫端要顯示原因，不是畫一張空圖。
    public static func layout(spec: ChartSpec, size: CGSize) -> FfiChartLayout? {
        try? chartLayout(specJson: spec.encodedJSON(), width: size.width, height: size.height)
    }

    /// 算不出來的原因，可以直接顯示給使用者。
    public static func failureReason(spec: ChartSpec, size: CGSize) -> String? {
        do {
            _ = try chartLayout(specJson: spec.encodedJSON(), width: size.width, height: size.height)
            return nil
        } catch {
            return (error as? FfiChartError).map(describe) ?? String(describing: error)
        }
    }

    private static func describe(_ error: FfiChartError) -> String {
        switch error {
        case .BadSpec(let reason), .TooSmall(let reason): return reason
        }
    }

    // MARK: - 繪製

    /// 把版面畫進一個 Core Graphics 內容。
    ///
    /// - Parameters:
    ///   - foreground: 文字與軸線的顏色。傳進來而不是寫死，圖表才會跟著
    ///     深淺色模式走 —— 插入畫布的點陣圖則固定用深色，因為紙張永遠是淺的。
    public static func draw(
        _ layout: FfiChartLayout,
        in context: CGContext,
        foreground: UIColor,
        gridColor: UIColor
    ) {
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // 格線先畫，才會被資料蓋住而不是浮在上面。
        context.setStrokeColor(gridColor.cgColor)
        context.setLineWidth(0.5)
        for line in layout.gridLines { strokeLine(line, in: context) }

        context.setStrokeColor(foreground.withAlphaComponent(0.55).cgColor)
        context.setLineWidth(1)
        for line in layout.axisLines { strokeLine(line, in: context) }
        for line in layout.radarSpokes { strokeLine(line, in: context) }

        // 雷達的同心圈是封閉多邊形，不是圓。
        context.setStrokeColor(gridColor.cgColor)
        context.setLineWidth(0.5)
        for ring in layout.radarRings where ring.count > 2 {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: ring[0].x, y: ring[0].y))
            for point in ring.dropFirst() { path.addLine(to: CGPoint(x: point.x, y: point.y)) }
            path.closeSubpath()
            context.addPath(path)
            context.strokePath()
        }

        drawTicks(layout, in: context, foreground: foreground)
        drawBars(layout, in: context)
        drawSlices(layout, in: context)
        drawPolylines(layout, in: context)
        drawScatter(layout, in: context)
        drawLegend(layout, in: context, foreground: foreground)

        for label in layout.labels {
            drawText(label.text, at: CGPoint(x: label.x, y: label.y),
                     size: label.fontSize, align: label.align,
                     color: color(label.colorHex) ?? foreground,
                     rotation: label.rotation, in: context)
        }
    }

    private static func strokeLine(_ line: FfiChartLine, in context: CGContext) {
        context.move(to: CGPoint(x: line.x1, y: line.y1))
        context.addLine(to: CGPoint(x: line.x2, y: line.y2))
        context.strokePath()
    }

    private static func drawTicks(_ layout: FfiChartLayout, in context: CGContext, foreground: UIColor) {
        context.setStrokeColor(foreground.withAlphaComponent(0.45).cgColor)
        context.setLineWidth(1)
        for tick in layout.xTicks + layout.yTicks {
            context.move(to: CGPoint(x: tick.x, y: tick.y))
            context.addLine(to: CGPoint(x: tick.x2, y: tick.y2))
            context.strokePath()
            drawText(tick.label, at: CGPoint(x: tick.labelX, y: tick.labelY),
                     size: 11, align: tick.align, color: foreground.withAlphaComponent(0.75),
                     rotation: 0, in: context)
        }
    }

    private static func drawBars(_ layout: FfiChartLayout, in context: CGContext) {
        for bar in layout.bars {
            guard bar.width > 0, bar.height > 0 else { continue }
            context.setFillColor((color(bar.colorHex) ?? .systemBlue).cgColor)
            // 高度不到圓角兩倍時不要圓角，否則細長條會縮成一顆藥丸。
            let radius = min(3, min(bar.width, bar.height) / 2)
            let rect = CGRect(x: bar.x, y: bar.y, width: bar.width, height: bar.height)
            context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
            context.fillPath()
        }
    }

    private static func drawSlices(_ layout: FfiChartLayout, in context: CGContext) {
        for slice in layout.slices {
            // 核心的角度以正上方為 0、順時針為正；Core Graphics 從 +x 軸起算。
            let start = slice.startAngle - .pi / 2
            let end = slice.endAngle - .pi / 2
            let center = CGPoint(x: slice.centerX, y: slice.centerY)
            let path = CGMutablePath()

            if slice.innerRadius > 0 {
                path.addArc(center: center, radius: slice.radius,
                            startAngle: start, endAngle: end, clockwise: false)
                path.addArc(center: center, radius: slice.innerRadius,
                            startAngle: end, endAngle: start, clockwise: true)
            } else {
                path.move(to: center)
                path.addArc(center: center, radius: slice.radius,
                            startAngle: start, endAngle: end, clockwise: false)
            }
            path.closeSubpath()

            context.setFillColor((color(slice.colorHex) ?? .systemBlue).cgColor)
            context.addPath(path)
            context.fillPath()

            // 白色分隔線：相鄰的扇形顏色再不同，沒有縫隙時還是會黏成一塊。
            context.setStrokeColor(UIColor.white.withAlphaComponent(0.9).cgColor)
            context.setLineWidth(1)
            context.addPath(path)
            context.strokePath()
        }
    }

    private static func drawPolylines(_ layout: FfiChartLayout, in context: CGContext) {
        for line in layout.polylines where line.points.count > 1 {
            let stroke = color(line.colorHex) ?? .systemBlue
            let points = line.points.map { CGPoint(x: $0.x, y: $0.y) }
            let path = line.smooth ? smoothPath(points) : straightPath(points)

            if let baseline = line.fillToY {
                let fill = CGMutablePath()
                fill.addPath(path)
                fill.addLine(to: CGPoint(x: points[points.count - 1].x, y: baseline))
                fill.addLine(to: CGPoint(x: points[0].x, y: baseline))
                fill.closeSubpath()
                context.setFillColor(stroke.withAlphaComponent(0.25).cgColor)
                context.addPath(fill)
                context.fillPath()
            }

            context.setStrokeColor(stroke.cgColor)
            context.setLineWidth(2)
            context.addPath(path)
            context.strokePath()

            if line.showMarkers {
                context.setFillColor(stroke.cgColor)
                for point in points {
                    context.fillEllipse(in: CGRect(x: point.x - 2.5, y: point.y - 2.5, width: 5, height: 5))
                }
            }
        }
    }

    private static func drawScatter(_ layout: FfiChartLayout, in context: CGContext) {
        for point in layout.scatterPoints {
            let fill = UIColor(hexString: chartPaletteColor(index: point.seriesIndex)) ?? .systemBlue
            context.setFillColor(fill.cgColor)
            context.fillEllipse(in: CGRect(x: point.x - 3.5, y: point.y - 3.5, width: 7, height: 7))
        }
    }

    private static func drawLegend(_ layout: FfiChartLayout, in context: CGContext, foreground: UIColor) {
        for entry in layout.legend {
            context.setFillColor((color(entry.colorHex) ?? .systemBlue).cgColor)
            let rect = CGRect(x: entry.swatchX, y: entry.swatchY,
                              width: entry.swatchSize, height: entry.swatchSize)
            context.addPath(CGPath(roundedRect: rect, cornerWidth: 2, cornerHeight: 2, transform: nil))
            context.fillPath()
            drawText(entry.text, at: CGPoint(x: entry.textX, y: entry.textY),
                     size: 11, align: .leading, color: foreground, rotation: 0, in: context)
        }
    }

    /// 通過每一點的平滑曲線（Catmull-Rom 轉三次貝茲）。
    ///
    /// 用 Catmull-Rom 而不是隨手取中點：曲線必須**通過**每一個資料點。
    /// 不通過資料點的「平滑曲線」畫的是一組不存在的數字。
    private static func smoothPath(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        path.move(to: points[0])
        for i in 0..<(points.count - 1) {
            let p0 = points[max(0, i - 1)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(points.count - 1, i + 2)]
            let control1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let control2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: control1, control2: control2)
        }
        return path
    }

    private static func straightPath(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        path.move(to: points[0])
        for point in points.dropFirst() { path.addLine(to: point) }
        return path
    }

    private static func drawText(
        _ text: String, at point: CGPoint, size: Double,
        align: FfiTextAlign, color: UIColor, rotation: Double, in context: CGContext
    ) {
        guard !text.isEmpty else { return }
        let font = UIFont.systemFont(ofSize: size)
        let string = NSAttributedString(
            string: text, attributes: [.font: font, .foregroundColor: color])
        let bounds = string.size()

        let dx: CGFloat = switch align {
        case .center: -bounds.width / 2
        case .trailing: -bounds.width
        case .leading: 0
        }

        context.saveGState()
        UIGraphicsPushContext(context)
        context.translateBy(x: point.x, y: point.y)
        if rotation != 0 { context.rotate(by: rotation) }
        // 核心給的 y 是**基線**（Android 的 drawText 直接吃基線），而
        // `draw(at:)` 要的是左上角 —— 差一個 ascender。用實際的字型度量而不是
        // 「高度乘 0.8」之類的估計，兩個平台的文字才會落在同一條線上。
        string.draw(at: CGPoint(x: dx, y: -font.ascender))
        UIGraphicsPopContext()
        context.restoreGState()
    }

    private static func color(_ hex: String) -> UIColor? {
        hex.isEmpty ? nil : UIColor(hexString: hex)
    }

    // MARK: - 點陣化

    /// 算繪成點陣圖，給插入畫布與匯出用。
    ///
    /// 文字固定用深色：這張圖會落在紙張上，而紙張永遠是淺的 —— 跟著系統深色
    /// 模式走的話，在深色模式下插入的圖表印出來會是一片看不見的深灰。
    public static func image(spec: ChartSpec, size: CGSize, scale: CGFloat = 3) -> UIImage? {
        guard let layout = layout(spec: spec, size: size) else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            draw(layout, in: ctx.cgContext,
                 foreground: UIColor(white: 0.11, alpha: 1),
                 gridColor: UIColor(white: 0.11, alpha: 0.14))
        }
    }
}

/// 圖表的即時預覽。
///
/// 走 `Canvas` 的 `withCGContext`，跟點陣化用的是**同一個**繪製函式 ——
/// 否則預覽好看、插進去卻不一樣，而使用者要到插入後才會發現。
public struct ChartPreview: View {
    public let spec: ChartSpec
    @Environment(\.colorScheme) private var colorScheme

    public init(spec: ChartSpec) { self.spec = spec }

    public var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            if let layout = ChartRenderer.layout(spec: spec, size: size) {
                Canvas { context, _ in
                    context.withCGContext { cg in
                        ChartRenderer.draw(
                            layout, in: cg,
                            foreground: UIColor.label,
                            gridColor: UIColor.label.withAlphaComponent(0.14)
                        )
                    }
                }
            } else {
                // 空白畫布看起來像壞掉了 —— 要講出是哪裡不對。
                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                    Text(ChartRenderer.failureReason(spec: spec, size: size) ?? "")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
