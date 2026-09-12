//
//  NotebookEditorView.swift
//  Kairumo
//
//  全功能專業手寫筆記編輯器與畫布視圖
//  內建實體手繪工具列（鋼筆、原子筆、螢光筆、鉛筆、橡皮擦、套索、色彩盤與粗細切換）
//  支援即時自動儲存、尺規量測導引、多頁切換、實體錄音與高解析度 PDF 導出
//

import SwiftUI
import PencilKit
import AVFoundation
import PhotosUI

#if canImport(PadnoteCore)
import PadnoteCore
#endif

/// 繪圖工具模式
public enum EditorToolType: String, CaseIterable, Identifiable {
    case pen = "鋼筆"
    case ballpoint = "原子筆"
    case brush = "毛筆"
    case marker = "麥克筆"
    case highlighter = "螢光筆"
    case pencil = "鉛筆"
    case watercolor = "水彩筆"
    case eraser = "橡皮擦"
    case lasso = "套索選取"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .pen: return "pencil.tip"
        case .ballpoint: return "pencil.line"
        case .brush: return "paintbrush.pointed.fill"
        case .marker: return "pencil.and.outline"
        case .highlighter: return "highlighter"
        case .pencil: return "pencil"
        case .watercolor: return "paintbrush.fill"
        case .eraser: return "eraser"
        case .lasso: return "lasso"
        }
    }

    public var localizationKey: String {
        switch self {
        case .pen: return "tool_pen"
        case .ballpoint: return "tool_ballpoint"
        case .brush: return "tool_brush"
        case .marker: return "tool_marker"
        case .highlighter: return "tool_highlighter"
        case .pencil: return "tool_pencil"
        case .watercolor: return "tool_watercolor"
        case .eraser: return "tool_eraser"
        case .lasso: return "tool_lasso"
        }
    }
}

/// 筆記編輯主模式（手繪手寫 vs 鍵盤打字排版）
public enum EditorMode: String, CaseIterable, Identifiable {
    case draw = "draw"
    case type = "type"

    public var id: String { rawValue }
}

/// 向量樣板背景繪製視圖（內嵌於 PKCanvasView 最底層，隨畫布長度無限延伸與同步滾動）
final class TemplateCanvasBackgroundView: UIView {
    var template: NoteTemplate = .blank {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        isUserInteractionEnabled = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let w = bounds.width
        let h = bounds.height

        switch template {
        case .blank:
            break

        case .grid:
            ctx.setStrokeColor(UIColor.secondaryLabel.withAlphaComponent(0.12).cgColor)
            ctx.setLineWidth(1.0)
            let step: CGFloat = 28
            var x: CGFloat = step
            while x < w {
                ctx.move(to: CGPoint(x: x, y: 0))
                ctx.addLine(to: CGPoint(x: x, y: h))
                x += step
            }
            var y: CGFloat = step
            while y < h {
                ctx.move(to: CGPoint(x: 0, y: y))
                ctx.addLine(to: CGPoint(x: w, y: y))
                y += step
            }
            ctx.strokePath()

        case .lined:
            ctx.setStrokeColor(UIColor.systemBlue.withAlphaComponent(0.15).cgColor)
            ctx.setLineWidth(1.0)
            let step: CGFloat = 32
            var y: CGFloat = 60
            while y < h {
                ctx.move(to: CGPoint(x: 30, y: y))
                ctx.addLine(to: CGPoint(x: w - 30, y: y))
                y += step
            }
            ctx.strokePath()

        case .cornell:
            ctx.setStrokeColor(UIColor.systemIndigo.withAlphaComponent(0.25).cgColor)
            ctx.setLineWidth(1.5)
            let cueX: CGFloat = min(220, w * 0.28)
            ctx.move(to: CGPoint(x: cueX, y: 60))
            ctx.addLine(to: CGPoint(x: cueX, y: h - 120))

            ctx.move(to: CGPoint(x: 20, y: 60))
            ctx.addLine(to: CGPoint(x: w - 20, y: 60))

            let summaryY: CGFloat = h - 120
            ctx.move(to: CGPoint(x: 20, y: summaryY))
            ctx.addLine(to: CGPoint(x: w - 20, y: summaryY))
            ctx.strokePath()

        // 美學視覺 (Aesthetic & Visual)
        case .dotGridFine:
            // 暖灰 5mm 極細點陣
            ctx.setFillColor(UIColor(red: 0.65, green: 0.63, blue: 0.60, alpha: 0.45).cgColor)
            let step: CGFloat = 20
            var x: CGFloat = step
            while x < w {
                var y: CGFloat = step
                while y < h {
                    ctx.fill(CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
                    y += step
                }
                x += step
            }

        case .goldenRatio:
            // 黃金比例 (0.382 / 0.618) 與三分線
            ctx.setStrokeColor(UIColor(red: 0.85, green: 0.65, blue: 0.20, alpha: 0.35).cgColor)
            ctx.setLineWidth(1.2)
            let gx1 = w * 0.382
            let gx2 = w * 0.618
            let gy1 = min(h, 1800) * 0.382
            let gy2 = min(h, 1800) * 0.618
            ctx.move(to: CGPoint(x: gx1, y: 0))
            ctx.addLine(to: CGPoint(x: gx1, y: h))
            ctx.move(to: CGPoint(x: gx2, y: 0))
            ctx.addLine(to: CGPoint(x: gx2, y: h))
            ctx.move(to: CGPoint(x: 0, y: gy1))
            ctx.addLine(to: CGPoint(x: w, y: gy1))
            ctx.move(to: CGPoint(x: 0, y: gy2))
            ctx.addLine(to: CGPoint(x: w, y: gy2))
            ctx.strokePath()

            // 九宮三分線 (細線)
            ctx.setStrokeColor(UIColor.systemBlue.withAlphaComponent(0.15).cgColor)
            ctx.setLineWidth(0.8)
            let tx1 = w / 3
            let tx2 = 2 * w / 3
            let ty1 = min(h, 1800) / 3
            let ty2 = 2 * min(h, 1800) / 3
            ctx.move(to: CGPoint(x: tx1, y: 0))
            ctx.addLine(to: CGPoint(x: tx1, y: h))
            ctx.move(to: CGPoint(x: tx2, y: 0))
            ctx.addLine(to: CGPoint(x: tx2, y: h))
            ctx.move(to: CGPoint(x: 0, y: ty1))
            ctx.addLine(to: CGPoint(x: w, y: ty1))
            ctx.move(to: CGPoint(x: 0, y: ty2))
            ctx.addLine(to: CGPoint(x: w, y: ty2))
            ctx.strokePath()

        case .moodboardMatrix:
            // 頂部 5 格色票定位卡位
            let swatchW: CGFloat = 56
            let swatchH: CGFloat = 48
            let startX: CGFloat = max(20, (w - (swatchW * 5 + 16 * 4)) / 2)
            ctx.setStrokeColor(UIColor.secondaryLabel.withAlphaComponent(0.3).cgColor)
            ctx.setLineWidth(1.0)
            for i in 0..<5 {
                let sx = startX + CGFloat(i) * (swatchW + 16)
                let r = CGRect(x: sx, y: 24, width: swatchW, height: swatchH)
                let p = UIBezierPath(roundedRect: r, cornerRadius: 6)
                ctx.addPath(p.cgPath)
            }
            ctx.strokePath()

            ctx.setStrokeColor(UIColor.separator.cgColor)
            ctx.move(to: CGPoint(x: 20, y: 90))
            ctx.addLine(to: CGPoint(x: w - 20, y: 90))
            ctx.strokePath()

        // 工程製程 (Engineering & Process)
        case .blueprintMetric:
            // 經典工程青藍底色
            ctx.setFillColor(UIColor(red: 0.08, green: 0.22, blue: 0.38, alpha: 1.0).cgColor)
            ctx.fill(bounds)

            // 毫米細網格 (10pt)
            ctx.setStrokeColor(UIColor(red: 0.30, green: 0.60, blue: 0.90, alpha: 0.25).cgColor)
            ctx.setLineWidth(0.6)
            var x: CGFloat = 10
            while x < w {
                ctx.move(to: CGPoint(x: x, y: 0))
                ctx.addLine(to: CGPoint(x: x, y: h))
                x += 10
            }
            var y: CGFloat = 10
            while y < h {
                ctx.move(to: CGPoint(x: 0, y: y))
                ctx.addLine(to: CGPoint(x: w, y: y))
                y += 10
            }
            ctx.strokePath()

            // 公分粗網格 (50pt)
            ctx.setStrokeColor(UIColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 0.55).cgColor)
            ctx.setLineWidth(1.2)
            x = 50
            while x < w {
                ctx.move(to: CGPoint(x: x, y: 0))
                ctx.addLine(to: CGPoint(x: x, y: h))
                x += 50
            }
            y = 50
            while y < h {
                ctx.move(to: CGPoint(x: 0, y: y))
                ctx.addLine(to: CGPoint(x: w, y: y))
                y += 50
            }
            ctx.strokePath()

            // 右下角工程規格標題欄 (Title Block)
            let tbRect = CGRect(x: w - 260, y: min(h, 1800) - 100, width: 240, height: 80)
            ctx.setStrokeColor(UIColor(red: 0.7, green: 0.85, blue: 1.0, alpha: 0.8).cgColor)
            ctx.setLineWidth(1.5)
            ctx.stroke(tbRect)
            ctx.move(to: CGPoint(x: tbRect.minX, y: tbRect.minY + 28))
            ctx.addLine(to: CGPoint(x: tbRect.maxX, y: tbRect.minY + 28))
            ctx.move(to: CGPoint(x: tbRect.minX, y: tbRect.minY + 54))
            ctx.addLine(to: CGPoint(x: tbRect.maxX, y: tbRect.minY + 54))
            ctx.strokePath()

        case .isometricGrid:
            // 30° 等角軸測立體網格
            ctx.setStrokeColor(UIColor.systemTeal.withAlphaComponent(0.22).cgColor)
            ctx.setLineWidth(0.8)
            let step: CGFloat = 36
            let slope: CGFloat = 0.57735 // tan(30°)

            // 垂直線
            var vx: CGFloat = 0
            while vx < w {
                ctx.move(to: CGPoint(x: vx, y: 0))
                ctx.addLine(to: CGPoint(x: vx, y: h))
                vx += step
            }

            // 30° 正斜線
            var sy: CGFloat = -w * slope
            while sy < h {
                ctx.move(to: CGPoint(x: 0, y: sy))
                ctx.addLine(to: CGPoint(x: w, y: sy + w * slope))
                sy += step * slope * 2
            }

            // 150° 反斜線
            var ry: CGFloat = 0
            while ry < h + w * slope {
                ctx.move(to: CGPoint(x: 0, y: ry))
                ctx.addLine(to: CGPoint(x: w, y: ry - w * slope))
                ry += step * slope * 2
            }
            ctx.strokePath()

        case .orthographic3View:
            // 四象限三視圖 (正視、俯視、側視、軸測)
            let midX = w / 2
            let midY = min(h, 1800) / 2
            ctx.setStrokeColor(UIColor.systemIndigo.withAlphaComponent(0.4).cgColor)
            ctx.setLineWidth(2.0)
            ctx.move(to: CGPoint(x: midX, y: 20))
            ctx.addLine(to: CGPoint(x: midX, y: h - 20))
            ctx.move(to: CGPoint(x: 20, y: midY))
            ctx.addLine(to: CGPoint(x: w - 20, y: midY))
            ctx.strokePath()

            // 基準 45° 投影導引線 (俯視對側視)
            ctx.setStrokeColor(UIColor.systemOrange.withAlphaComponent(0.25).cgColor)
            ctx.setLineWidth(1.0)
            ctx.move(to: CGPoint(x: midX, y: midY))
            ctx.addLine(to: CGPoint(x: w - 40, y: midY + (w - 40 - midX)))
            ctx.strokePath()

        // 數位體驗 (Digital Experience / UI/UX)
        case .mobileWireframe:
            // 8pt 網格背景
            ctx.setFillColor(UIColor.systemGray.withAlphaComponent(0.12).cgColor)
            let dotStep: CGFloat = 16
            var x: CGFloat = dotStep
            while x < w {
                var y: CGFloat = dotStep
                while y < h {
                    ctx.fill(CGRect(x: x - 0.75, y: y - 0.75, width: 1.5, height: 1.5))
                    y += dotStep
                }
                x += dotStep
            }

            // 雙手機線框輪廓
            ctx.setStrokeColor(UIColor.label.withAlphaComponent(0.35).cgColor)
            ctx.setLineWidth(2.5)
            let phoneW: CGFloat = 280
            let phoneH: CGFloat = 580
            let gap: CGFloat = 40
            let totalW = phoneW * 2 + gap
            let px1 = max(30, (w - totalW) / 2)
            let px2 = px1 + phoneW + gap
            let py: CGFloat = 70

            for px in [px1, px2] {
                let r = CGRect(x: px, y: py, width: phoneW, height: phoneH)
                let p = UIBezierPath(roundedRect: r, cornerRadius: 36)
                ctx.addPath(p.cgPath)

                // 動態島/瀏海
                let notch = CGRect(x: px + phoneW/2 - 40, y: py + 14, width: 80, height: 22)
                let np = UIBezierPath(roundedRect: notch, cornerRadius: 11)
                ctx.addPath(np.cgPath)

                // 底部 Home Indicator
                let bar = CGRect(x: px + phoneW/2 - 50, y: py + phoneH - 18, width: 100, height: 4)
                let bp = UIBezierPath(roundedRect: bar, cornerRadius: 2)
                ctx.addPath(bp.cgPath)
            }
            ctx.strokePath()

        case .webResponsiveGrid:
            // 響應式 12 欄網格 (Column Guides)
            let margin: CGFloat = max(30, w * 0.06)
            let contentW = w - 2 * margin
            let columns = 12
            let gutter: CGFloat = 16
            let colW = (contentW - CGFloat(columns - 1) * gutter) / CGFloat(columns)

            ctx.setFillColor(UIColor.systemPurple.withAlphaComponent(0.06).cgColor)
            for i in 0..<columns {
                let cx = margin + CGFloat(i) * (colW + gutter)
                ctx.fill(CGRect(x: cx, y: 0, width: colW, height: h))
            }

            // 邊界參考線
            ctx.setStrokeColor(UIColor.systemPurple.withAlphaComponent(0.25).cgColor)
            ctx.setLineWidth(1.0)
            ctx.move(to: CGPoint(x: margin, y: 0))
            ctx.addLine(to: CGPoint(x: margin, y: h))
            ctx.move(to: CGPoint(x: w - margin, y: 0))
            ctx.addLine(to: CGPoint(x: w - margin, y: h))
            ctx.strokePath()

        case .userJourneyFlow:
            // 泳道與步驟流程矩陣
            ctx.setStrokeColor(UIColor.systemTeal.withAlphaComponent(0.3).cgColor)
            ctx.setLineWidth(1.5)
            let laneH: CGFloat = 220
            var ly: CGFloat = 60
            while ly < h {
                ctx.move(to: CGPoint(x: 20, y: ly))
                ctx.addLine(to: CGPoint(x: w - 20, y: ly))
                ly += laneH
            }

            // 垂直階段分隔線 (4 階段)
            let stepW = (w - 60) / 4
            for i in 1...3 {
                let sx = 30 + CGFloat(i) * stepW
                ctx.move(to: CGPoint(x: sx, y: 40))
                ctx.addLine(to: CGPoint(x: sx, y: h - 40))
            }
            ctx.strokePath()
        }
    }
}

/// PencilKit 畫布之 SwiftUI 封裝（跨 iOS / iPadOS / Mac Catalyst，支援無限高度延長、背景同步滾動與套索選取監聽）
struct CanvasRepresentable: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var selectedTool: EditorToolType
    var selectedColor: Color
    var strokeWidth: CGFloat
    var isRulerActive: Bool
    var template: NoteTemplate
    var pageHeight: CGFloat
    var onDrawingChanged: ((PKDrawing) -> Void)?
    var onAutoExtendHeight: ((CGFloat) -> Void)?
    var onSelectionChanged: ((Bool) -> Void)?
    var canvasRef: ((PKCanvasView) -> Void)?

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.delegate = context.coordinator
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = true
        canvas.alwaysBounceVertical = true
        canvas.showsVerticalScrollIndicator = true
        canvas.showsHorizontalScrollIndicator = false
        canvas.drawing = drawing

        let initialWidth = max(canvas.bounds.width, 800)
        let initialHeight = max(pageHeight, 1800)
        canvas.contentSize = CGSize(width: initialWidth, height: initialHeight)

        // 嵌入底層背景樣板視圖（隨畫布滾動）
        let bgView = TemplateCanvasBackgroundView(frame: CGRect(origin: .zero, size: canvas.contentSize))
        bgView.template = template
        canvas.insertSubview(bgView, at: 0)
        context.coordinator.backgroundView = bgView

        context.coordinator.parent = self
        context.coordinator.applyTool(to: canvas)
        canvasRef?(canvas)

        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
        uiView.isRulerActive = isRulerActive

        // 更新高度與滾動範圍
        let targetWidth = max(uiView.bounds.width, 800)
        let targetHeight = max(pageHeight, 1800)
        let currentSize = uiView.contentSize
        if currentSize.height != targetHeight || currentSize.width != targetWidth {
            uiView.contentSize = CGSize(width: targetWidth, height: targetHeight)
            context.coordinator.backgroundView?.frame = CGRect(origin: .zero, size: uiView.contentSize)
            context.coordinator.backgroundView?.setNeedsDisplay()
        }
        if context.coordinator.backgroundView?.template != template {
            context.coordinator.backgroundView?.template = template
        }

        context.coordinator.applyTool(to: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: CanvasRepresentable
        weak var backgroundView: TemplateCanvasBackgroundView?

        init(_ parent: CanvasRepresentable) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
            parent.onDrawingChanged?(canvasView.drawing)

            // 智慧邊界感應：若筆劃接近當前畫布底部（距離小於 250pt），自動向上擴展長度
            let maxY = canvasView.drawing.bounds.maxY
            if maxY > 0 && maxY + 250 > parent.pageHeight {
                let newHeight = max(parent.pageHeight + 600, maxY + 450)
                parent.onAutoExtendHeight?(newHeight)
            }
        }

        func canvasViewSelectionDidChange(_ canvasView: PKCanvasView) {
            let hasSel = parent.checkHasSelection(in: canvasView)
            parent.onSelectionChanged?(hasSel)
        }

        func applyTool(to canvas: PKCanvasView) {
            let uiColor = UIColor(parent.selectedColor)
            switch parent.selectedTool {
            case .pen:
                // 鋼筆：墨水充沛飽滿、帶有自然流暢的下筆壓力與速度過渡
                canvas.tool = PKInkingTool(.pen, color: uiColor, width: max(2.5, parent.strokeWidth * 1.1))

            case .ballpoint:
                // 原子筆：恆定寬度、均勻工整、俐落乾脆之機械單線
                if #available(iOS 17.0, *) {
                    canvas.tool = PKInkingTool(.monoline, color: uiColor, width: max(1.2, parent.strokeWidth * 0.65))
                } else {
                    canvas.tool = PKInkingTool(.pen, color: uiColor, width: max(1.2, parent.strokeWidth * 0.65))
                }

            case .brush:
                // 毛筆：45° 書法扁鋒、提按起伏頓挫有致、筆鋒鮮明、粗細對比強烈
                if #available(iOS 17.0, *) {
                    canvas.tool = PKInkingTool(.fountainPen, color: uiColor, width: max(5.0, parent.strokeWidth * 2.2))
                } else {
                    canvas.tool = PKInkingTool(.pen, color: uiColor, width: max(5.0, parent.strokeWidth * 2.0))
                }

            case .marker:
                // 麥克筆：厚實方形斜切筆觸、高飽和厚重墨水（Alpha 0.85）、設計草圖與手繪上色
                canvas.tool = PKInkingTool(.marker, color: uiColor.withAlphaComponent(0.85), width: max(8.0, parent.strokeWidth * 2.8))

            case .highlighter:
                // 螢光筆：半透明寬扁筆刷（Alpha 0.35），重點標記不遮蔽底層筆跡
                canvas.tool = PKInkingTool(.marker, color: uiColor.withAlphaComponent(0.35), width: max(18.0, parent.strokeWidth * 3.8))

            case .pencil:
                // 鉛筆：石墨微顆粒磨砂質感、側鋒陰影素描
                canvas.tool = PKInkingTool(.pencil, color: uiColor.withAlphaComponent(0.85), width: max(2.0, parent.strokeWidth * 1.3))

            case .watercolor:
                // 水彩筆：濕潤水墨層疊擴散與暈染效果
                if #available(iOS 17.0, *) {
                    canvas.tool = PKInkingTool(.watercolor, color: uiColor.withAlphaComponent(0.55), width: max(8.0, parent.strokeWidth * 2.4))
                } else {
                    canvas.tool = PKInkingTool(.marker, color: uiColor.withAlphaComponent(0.5), width: max(8.0, parent.strokeWidth * 2.0))
                }

            case .eraser:
                canvas.tool = PKEraserTool(.vector)

            case .lasso:
                canvas.tool = PKLassoTool()
            }
        }
    }

    func checkHasSelection(in canvas: PKCanvasView) -> Bool {
        for sv in canvas.subviews where String(describing: type(of: sv)).contains("PKTiledView") {
            let hasSel = NSSelectorFromString("_hasSelection")
            if sv.responds(to: hasSel) {
                let hasSelectionFunc = unsafeBitCast(
                    sv.method(for: hasSel),
                    to: (@convention(c) (AnyObject, Selector) -> Bool).self
                )
                if hasSelectionFunc(sv, hasSel) {
                    return true
                }
            }
        }
        return false
    }
}

/// 黃金螺旋構圖 HUD 疊層視圖 (Φ 1.618)
struct GoldenSpiralOverlayView: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let minDim = min(w, h * 0.8)
            let phi: CGFloat = 1.6180339887

            ZStack(alignment: .topLeading) {
                Path { path in
                    var curW = minDim
                    var curH = minDim / phi
                    var origin = CGPoint(x: max(20, (w - curW) / 2), y: 60)

                    path.addRect(CGRect(origin: origin, size: CGSize(width: curW, height: curH)))

                    for _ in 0..<7 {
                        let squareSize = curH
                        let squareRect = CGRect(origin: origin, size: CGSize(width: squareSize, height: squareSize))
                        path.addRect(squareRect)
                        path.addArc(
                            center: CGPoint(x: squareRect.maxX, y: squareRect.maxY),
                            radius: squareSize,
                            startAngle: .degrees(180),
                            endAngle: .degrees(270),
                            clockwise: false
                        )
                        origin = CGPoint(x: origin.x + squareSize, y: origin.y)
                        let newW = curW - squareSize
                        curH = newW
                        curW = squareSize
                    }
                }
                .stroke(Color.orange.opacity(0.65), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

                HStack(spacing: 6) {
                    Image(systemName: "camera.metering.center.weighted")
                    Text("GOLDEN SPIRAL (Φ 1.618)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding(16)
            }
        }
    }
}

/// 九宮格三分構圖法 HUD 疊層視圖
struct RuleOfThirdsOverlayView: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let activeHeight = min(h, 1200)

            ZStack(alignment: .topLeading) {
                Path { path in
                    path.move(to: CGPoint(x: w / 3, y: 0))
                    path.addLine(to: CGPoint(x: w / 3, y: activeHeight))

                    path.move(to: CGPoint(x: w * 2 / 3, y: 0))
                    path.addLine(to: CGPoint(x: w * 2 / 3, y: activeHeight))

                    path.move(to: CGPoint(x: 0, y: activeHeight / 3))
                    path.addLine(to: CGPoint(x: w, y: activeHeight / 3))

                    path.move(to: CGPoint(x: 0, y: activeHeight * 2 / 3))
                    path.addLine(to: CGPoint(x: w, y: activeHeight * 2 / 3))
                }
                .stroke(Color.cyan.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))

                let points = [
                    CGPoint(x: w / 3, y: activeHeight / 3),
                    CGPoint(x: w * 2 / 3, y: activeHeight / 3),
                    CGPoint(x: w / 3, y: activeHeight * 2 / 3),
                    CGPoint(x: w * 2 / 3, y: activeHeight * 2 / 3)
                ]

                ForEach(0..<points.count, id: \.self) { idx in
                    let pt = points[idx]
                    Circle()
                        .stroke(Color.cyan, lineWidth: 2)
                        .background(Circle().fill(Color.cyan.opacity(0.2)))
                        .frame(width: 14, height: 14)
                        .position(pt)
                }

                HStack(spacing: 6) {
                    Image(systemName: "grid")
                    Text("RULE OF THIRDS (3×3)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.cyan)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding(16)
            }
        }
    }
}

/// 筆記樣板背景繪製器
struct TemplateBackgroundView: View {
    let template: NoteTemplate

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                switch template {
                case .blank:
                    Color(uiColor: .systemBackground)

                case .grid:
                    Color(uiColor: .systemBackground)
                    Path { path in
                        let step: CGFloat = 28
                        var x: CGFloat = step
                        while x < w {
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: h))
                            x += step
                        }
                        var y: CGFloat = step
                        while y < h {
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: w, y: y))
                            y += step
                        }
                    }
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)

                case .lined:
                    Color(uiColor: .systemBackground)
                    Path { path in
                        let step: CGFloat = 32
                        var y: CGFloat = 60
                        while y < h {
                            path.move(to: CGPoint(x: 30, y: y))
                            path.addLine(to: CGPoint(x: w - 30, y: y))
                            y += step
                        }
                    }
                    .stroke(Color.blue.opacity(0.15), lineWidth: 1)

                case .cornell:
                    Color(uiColor: .systemBackground)
                    Path { path in
                        let cueX: CGFloat = min(220, w * 0.28)
                        path.move(to: CGPoint(x: cueX, y: 60))
                        path.addLine(to: CGPoint(x: cueX, y: h - 120))

                        path.move(to: CGPoint(x: 20, y: 60))
                        path.addLine(to: CGPoint(x: w - 20, y: 60))

                        let summaryY: CGFloat = h - 120
                        path.move(to: CGPoint(x: 20, y: summaryY))
                        path.addLine(to: CGPoint(x: w - 20, y: summaryY))
                    }
                    .stroke(Color.indigo.opacity(0.25), lineWidth: 1.5)

                case .dotGridFine:
                    Color(uiColor: .systemBackground)
                    Canvas { ctx, size in
                        let step: CGFloat = 16
                        var y: CGFloat = 16
                        while y < size.height {
                            var x: CGFloat = 16
                            while x < size.width {
                                ctx.fill(
                                    Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                                    with: .color(Color.primary.opacity(0.18))
                                )
                                x += step
                            }
                            y += step
                        }
                    }

                case .goldenRatio:
                    Color(uiColor: .systemBackground)
                    GoldenSpiralOverlayView()

                case .moodboardMatrix:
                    Color(uiColor: .systemBackground)
                    Path { path in
                        let swatchW: CGFloat = min(70, (w - 100) / 5)
                        for i in 0..<5 {
                            let sx = 24 + CGFloat(i) * (swatchW + 12)
                            path.addRoundedRect(in: CGRect(x: sx, y: 16, width: swatchW, height: 48), cornerSize: CGSize(width: 6, height: 6))
                        }
                        path.move(to: CGPoint(x: 20, y: 76))
                        path.addLine(to: CGPoint(x: w - 20, y: 76))
                    }
                    .stroke(Color.pink.opacity(0.35), lineWidth: 1)

                case .blueprintMetric:
                    Color(red: 0.08, green: 0.22, blue: 0.38)
                    Path { path in
                        var x: CGFloat = 20
                        while x < w {
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: h))
                            x += 20
                        }
                        var y: CGFloat = 20
                        while y < h {
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: w, y: y))
                            y += 20
                        }
                    }
                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1)

                case .isometricGrid:
                    Color(uiColor: .systemBackground)
                    Path { path in
                        let step: CGFloat = 40
                        var x: CGFloat = -h
                        while x < w + h {
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x + h * 1.732, y: h))
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x - h * 1.732, y: h))
                            x += step
                        }
                    }
                    .stroke(Color.teal.opacity(0.25), lineWidth: 0.8)

                case .orthographic3View:
                    Color(uiColor: .systemBackground)
                    Path { path in
                        let midX = w / 2
                        let midY = h / 2
                        path.move(to: CGPoint(x: midX, y: 20))
                        path.addLine(to: CGPoint(x: midX, y: h - 20))
                        path.move(to: CGPoint(x: 20, y: midY))
                        path.addLine(to: CGPoint(x: w - 20, y: midY))
                    }
                    .stroke(Color.orange.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))

                case .mobileWireframe:
                    Color(uiColor: .systemBackground)
                    Path { path in
                        let phoneW: CGFloat = 220
                        let phoneH: CGFloat = 450
                        let r1 = CGRect(x: max(20, (w / 2 - phoneW - 20)), y: 40, width: phoneW, height: phoneH)
                        let r2 = CGRect(x: min(w - phoneW - 20, (w / 2 + 20)), y: 40, width: phoneW, height: phoneH)
                        path.addRoundedRect(in: r1, cornerSize: CGSize(width: 24, height: 24))
                        path.addRoundedRect(in: r2, cornerSize: CGSize(width: 24, height: 24))
                    }
                    .stroke(Color.purple.opacity(0.35), lineWidth: 1.5)

                case .webResponsiveGrid:
                    Color(uiColor: .systemBackground)
                    Path { path in
                        let colW = (w - 140) / 12
                        for i in 0..<12 {
                            let x = 60 + CGFloat(i) * (colW + 6)
                            path.addRect(CGRect(x: x, y: 20, width: colW, height: h - 40))
                        }
                    }
                    .stroke(Color.indigo.opacity(0.2), lineWidth: 1)

                case .userJourneyFlow:
                    Color(uiColor: .systemBackground)
                    Path { path in
                        let rowH: CGFloat = 100
                        for i in 1...4 {
                            let y = CGFloat(i) * rowH
                            path.move(to: CGPoint(x: 20, y: y))
                            path.addLine(to: CGPoint(x: w - 20, y: y))
                        }
                    }
                    .stroke(Color.green.opacity(0.25), lineWidth: 1)
                }
            }
        }
    }
}

/// 筆記編輯器全螢幕視圖
public struct NotebookEditorView: View {
    @Binding var notebook: NotebookDocument
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var store = NotebookStore.shared
    @ObservedObject var audioManager = AudioRecorderManager.shared
    @ObservedObject var localizationManager = LocalizationManager.shared

    // 頁面狀態
    @State private var currentPageIndex: Int = 0
    @State private var currentDrawing: PKDrawing = PKDrawing()
    @State private var canvasView: PKCanvasView? = nil
    @State private var currentPageHeight: CGFloat = 1800.0
    @State private var hasLassoSelection: Bool = false
    @State private var showExtendedBanner: Bool = false

    // 實體工具列狀態
    @State private var selectedTool: EditorToolType = .pen
    @State private var selectedColor: Color = .primary
    @State private var strokeWidth: CGFloat = 3.5
    @State private var isRulerActive: Bool = false
    @State private var rulerAngleGuide: Double = 0.0

    // 彈窗與輔助狀態
    @State private var showRenameAlert: Bool = false
    @State private var renameText: String = ""
    @State private var showShareSheet: Bool = false
    @State private var showClearConfirmAlert: Bool = false
    @State private var exportPdfData: Data? = nil

    // 圖片、算式、圖表、文字與連結狀態
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showPhotoPicker: Bool = false
    @State private var showMathCalculator: Bool = false
    @State private var showChartStudio: Bool = false
    @State private var editingAttachmentId: String? = nil

    // Word 文字排版、網址預覽與專業調色狀態
    @State private var showWordStudio: Bool = false
    @State private var editingTextId: String? = nil
    @State private var newTextDraft: NoteTextAttachment = NoteTextAttachment()
    @State private var showLinkPreviewSheet: Bool = false
    @State private var showProColorPicker: Bool = false

    // 草圖智慧修飾狀態 (幾何識別、平滑化、一鍵修飾/重做/恢復)
    @State private var showSketchRefineBar: Bool = false
    @State private var refineIntensity: CGFloat = 0.85
    @State private var originalSketchBackup: PKDrawing? = nil
    @State private var refinedSketchCache: PKDrawing? = nil

    // 3D 模型狀態
    @State private var show3DStudio: Bool = false

    // 三大主題專屬加速輔助工具與素材圖庫狀態
    @State private var showThemeToolsSheet: Bool = false
    @State private var showAssetLibrarySheet: Bool = false
    @State private var isGoldenSpiralOverlay: Bool = false
    @State private var isRuleOfThirdsOverlay: Bool = false

    // 筆記主模式：手繪 (Draw) vs 鍵盤打字 (Type)
    @State private var editorMode: EditorMode = .draw

    // 筆記結構欄（側邊頁面縮圖大綱目錄欄）
    @State private var showStructureSidebar: Bool = false

    // 頁面刪除警告
    @State private var pageToDeleteIndex: Int? = nil
    @State private var showDeletePageAlert: Bool = false

    // 常用色彩盤
    private let colorPalette: [Color] = [
        .black,
        .blue,
        .red,
        Color(red: 0.1, green: 0.6, blue: 0.2), // 綠色
        .orange,
        .purple,
        Color(red: 0.9, green: 0.8, blue: 0.1), // 螢光黃
        .gray
    ]

    public init(notebook: Binding<NotebookDocument>) {
        self._notebook = notebook
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. 頂部自訂主工作列（返回首頁、筆記結構、打字/手繪切換、標題、頁面切換、匯出與列印）
            editorTopBar

            // 2. 🌟 實體模式專屬工具列（手繪模式 vs 打字排版模式）
            if editorMode == .draw {
                drawingToolbar
            } else {
                typingToolbar
            }

            // 3. 尺規旋轉與量測輔助列（若尺規開啟時顯示）
            if isRulerActive {
                rulerControlBar
            }

            // 4. 若目前筆記有已錄音音檔，顯示音訊播放控制條
            if notebook.hasRecording, let audioPath = notebook.recordingAudioPath {
                audioPlaybackBar(fileName: audioPath)
            }

            // 5. 若目前正在進行錄音，顯示即時錄音波形橫條
            if audioManager.status == .recording {
                liveRecordingBar
            }

            // 6. 核心編輯工作區（包含左側筆記結構欄與右側畫布區）
            HStack(spacing: 0) {
                if showStructureSidebar {
                    notebookStructureSidebar
                        .frame(width: 250)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    Divider()
                }

                // 核心手寫/打字畫布區
                ZStack(alignment: .topTrailing) {
                    CanvasRepresentable(
                        drawing: $currentDrawing,
                        selectedTool: selectedTool,
                        selectedColor: selectedColor,
                        strokeWidth: strokeWidth,
                        isRulerActive: isRulerActive,
                        template: notebook.template,
                        pageHeight: currentPageHeight,
                        onDrawingChanged: { newDrawing in
                            // 即時自動儲存至專屬二進位檔案
                            store.saveDrawing(notebookId: notebook.id, pageIndex: currentPageIndex, drawing: newDrawing)
                            notebook.lastModifiedDate = Date()
                        },
                        onAutoExtendHeight: { newHeight in
                            currentPageHeight = newHeight
                            notebook.setHeight(newHeight, forPage: currentPageIndex)
                            store.updateNotebook(notebook)
                        },
                        onSelectionChanged: { hasSel in
                            self.hasLassoSelection = hasSel
                        },
                        canvasRef: { ref in
                            self.canvasView = ref
                        }
                    )

                    // 🌟 筆記內嵌圖片與圖表展示層（支援等比縮放、拖曳平移與濾鏡美化）
                    ForEach(notebook.attachments ?? []) { item in
                        if item.pageIndex == currentPageIndex {
                            AttachmentItemView(
                                attachment: binding(for: item.id),
                                onEdit: {
                                    self.editingAttachmentId = item.id
                                },
                                onDelete: {
                                    notebook.attachments?.removeAll { $0.id == item.id }
                                    store.updateNotebook(notebook)
                                }
                            )
                        }
                    }

                    // 🌟 筆記內嵌 Word 級文字方塊（支援段落對齊、特殊符號與便利貼卡片底色）
                    ForEach(notebook.textAttachments ?? []) { item in
                        if item.pageIndex == currentPageIndex {
                            TextAttachmentItemView(
                                textItem: binding(forTextId: item.id),
                                onEdit: {
                                    self.editingTextId = item.id
                                },
                                onDelete: {
                                    notebook.textAttachments?.removeAll { $0.id == item.id }
                                    store.updateNotebook(notebook)
                                }
                            )
                        }
                    }

                    // 🌟 筆記內嵌網址 Rich Link 預覽卡片（支援點擊跳轉瀏覽器與自由平移）
                    ForEach(notebook.linkAttachments ?? []) { item in
                        if item.pageIndex == currentPageIndex {
                            LinkAttachmentItemView(
                                linkItem: binding(forLinkId: item.id),
                                onDelete: {
                                    notebook.linkAttachments?.removeAll { $0.id == item.id }
                                    store.updateNotebook(notebook)
                                }
                            )
                        }
                    }

                    // 🌟 筆記內嵌 3D 幾何模型展示層（支援 360° 空間旋轉、9大材質 PBR 物理反射、縮放與文字標題）
                    ForEach(notebook.model3DAttachments ?? []) { item in
                        if item.pageIndex == currentPageIndex {
                            Model3DCanvasItemView(
                                item: binding(forModel3DId: item.id),
                                onDelete: {
                                    notebook.model3DAttachments?.removeAll { $0.id == item.id }
                                    store.updateNotebook(notebook)
                                }
                            )
                        }
                    }

                    // 🌟 美學構圖輔助 HUD 疊層（黃金螺旋與三分構圖）
                    if isGoldenSpiralOverlay {
                        GoldenSpiralOverlayView()
                            .allowsHitTesting(false)
                            .frame(height: currentPageHeight)
                    }
                    if isRuleOfThirdsOverlay {
                        RuleOfThirdsOverlayView()
                            .allowsHitTesting(false)
                            .frame(height: currentPageHeight)
                    }

                    // 🌟 草圖智慧修飾浮動控制面板（支援一鍵修飾、恢復原草圖、重做與強度調整）
                    if showSketchRefineBar {
                        VStack {
                            sketchRefineFloatingBar
                                .padding(.top, 12)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // 🌟 套索選取浮動控制面板（當套索工具啟動時浮現：支援剪下、複製、刪除選取筆劃）
                    if selectedTool == .lasso {
                        VStack {
                            lassoFloatingActionBar
                                .padding(.top, 12)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // 🌟 即時浮動錄音圖示徽章（筆記錄音完成後立即在已開啟筆記中呈現！）
                    if notebook.hasRecording, let audioPath = notebook.recordingAudioPath {
                        floatingAudioBadge(fileName: audioPath)
                            .padding(16)
                            .transition(.scale.combined(with: .opacity))
                    }

                    // 🌟 畫布底部浮動延伸膠囊按鈕（保留彈性：讓使用者隨時可向下延伸本頁）
                    VStack {
                        Spacer()
                        HStack {
                            if showExtendedBanner {
                                Text(localizationManager.localized("page_extended_hint"))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }

                            Spacer()

                            Button {
                                extendCurrentPage(by: 800)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.to.line.compact")
                                        .font(.subheadline)
                                    Text(localizationManager.localized("extend_page_amount"))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(.ultraThinMaterial)
                                .cornerRadius(18)
                                .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)
                            }
                            .buttonStyle(.plain)
                            .help(localizationManager.localized("extend_page_amount"))
                        }
                        .padding(14)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.black.opacity(0.06), radius: 8, y: 4)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .background {
                Group {
                    Button("") {
                        deleteSelectedStrokes()
                    }
                    .keyboardShortcut(.delete, modifiers: [])

                    Button("") {
                        deleteSelectedStrokes()
                    }
                    .keyboardShortcut(.deleteForward, modifiers: [])
                }
                .opacity(0)
                .allowsHitTesting(false)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarBackButtonHidden(true)
        .onAppear {
            loadCurrentPage()
        }
        .sheet(isPresented: $showShareSheet) {
            if let data = exportPdfData {
                ShareActivityView(data: data, filename: "\(notebook.title).pdf")
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let item = newItem,
                   let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    await MainActor.run {
                        insertImageAttachment(img)
                        selectedPhotoItem = nil
                    }
                }
            }
        }
        .sheet(isPresented: $showMathCalculator) {
            MathCalculatorSheet { exprText, cardImage in
                insertImageAttachment(cardImage)
            }
        }
        .sheet(isPresented: $showChartStudio) {
            ChartStudioView { chartImage in
                insertImageAttachment(chartImage)
            }
        }
        .sheet(isPresented: Binding(
            get: { editingAttachmentId != nil },
            set: { if !$0 { editingAttachmentId = nil } }
        )) {
            if let id = editingAttachmentId {
                ImageEditSheet(attachment: binding(for: id)) {
                    notebook.attachments?.removeAll { $0.id == id }
                    store.updateNotebook(notebook)
                }
            }
        }
        .sheet(isPresented: $showWordStudio) {
            WordTextStudioView(attachment: $newTextDraft) { created in
                if notebook.textAttachments == nil {
                    notebook.textAttachments = []
                }
                notebook.textAttachments?.append(created)
                store.updateNotebook(notebook)
            }
        }
        .sheet(isPresented: Binding(
            get: { editingTextId != nil },
            set: { if !$0 { editingTextId = nil } }
        )) {
            if let id = editingTextId {
                WordTextStudioView(attachment: binding(forTextId: id)) { updated in
                    if let idx = notebook.textAttachments?.firstIndex(where: { $0.id == id }) {
                        notebook.textAttachments?[idx] = updated
                        store.updateNotebook(notebook)
                    }
                }
            }
        }
        .sheet(isPresented: $showLinkPreviewSheet) {
            LinkPreviewSheet { linkItem in
                if notebook.linkAttachments == nil {
                    notebook.linkAttachments = []
                }
                notebook.linkAttachments?.append(linkItem)
                store.updateNotebook(notebook)
            }
        }
        .sheet(isPresented: $showProColorPicker) {
            ProColorPickerSheet(selectedColor: $selectedColor)
        }
        .sheet(isPresented: $show3DStudio) {
            Model3DStudioView { new3DAttachment in
                if notebook.model3DAttachments == nil {
                    notebook.model3DAttachments = []
                }
                var att = new3DAttachment
                att.pageIndex = currentPageIndex
                notebook.model3DAttachments?.append(att)
                store.updateNotebook(notebook)
            }
        }
        .sheet(isPresented: $showAssetLibrarySheet) {
            AssetLibraryView { image, _ in
                insertImageAttachment(image)
            }
        }
        .sheet(isPresented: $showThemeToolsSheet) {
            ThemeSpecificToolsView(
                currentBrushColor: $selectedColor,
                isGoldenSpiralActive: $isGoldenSpiralOverlay,
                isRuleOfThirdsActive: $isRuleOfThirdsOverlay,
                onInsertCardImage: { image in
                    insertImageAttachment(image)
                },
                onInsertTextCard: { text in
                    insertQuickTextSnippet(text)
                }
            )
        }
        .alert(localizationManager.localized("rename_note"), isPresented: $showRenameAlert) {
            TextField(localizationManager.localized("note_title"), text: $renameText)
            Button(localizationManager.localized("cancel"), role: .cancel) {}
            Button(localizationManager.localized("confirm")) {
                if !renameText.isEmpty {
                    notebook.title = renameText
                    store.updateNotebook(notebook)
                }
            }
        }
        .alert(localizationManager.localized("clear_page"), isPresented: $showClearConfirmAlert) {
            Button(localizationManager.localized("cancel"), role: .cancel) {}
            Button(localizationManager.localized("clear_confirm"), role: .destructive) {
                currentDrawing = PKDrawing()
                store.saveDrawing(notebookId: notebook.id, pageIndex: currentPageIndex, drawing: currentDrawing)
            }
        } message: {
            Text(localizationManager.localized("clear_page_confirm"))
        }
        .alert(localizationManager.localized("mic_permission_title"), isPresented: $audioManager.showPermissionAlert) {
            Button(localizationManager.localized("cancel"), role: .cancel) {
                audioManager.showPermissionAlert = false
            }
            Button(localizationManager.localized("open_settings")) {
                audioManager.openSystemSettings()
            }
        } message: {
            Text(localizationManager.localized("mic_permission_msg"))
        }
        .alert(localizationManager.localized("delete_page"), isPresented: $showDeletePageAlert) {
            Button(localizationManager.localized("cancel"), role: .cancel) {}
            Button(localizationManager.localized("delete_page"), role: .destructive) {
                if let idx = pageToDeleteIndex {
                    deletePage(at: idx)
                }
            }
        } message: {
            Text("確定要刪除第 \((pageToDeleteIndex ?? 0) + 1) 頁嗎？此動作無法復原。")
        }
    }

    // MARK: - 1. 頂部自訂主工作列
    private var editorTopBar: some View {
        HStack(spacing: 10) {
            // 回到首頁按鈕（明顯、易見、帶底色）
            Button {
                saveCurrentPageDrawing()
                dismiss()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                    Image(systemName: "house.fill")
                        .font(.system(size: 13))
                    Text(localizationManager.localized("home"))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor)
                .cornerRadius(8)
                .shadow(color: Color.accentColor.opacity(0.3), radius: 3, y: 1)
            }
            .buttonStyle(.plain)
            .help(localizationManager.localized("home"))

            // 筆記結構側邊欄切換鈕
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showStructureSidebar.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: showStructureSidebar ? "sidebar.left" : "sidebar.leading")
                        .font(.system(size: 13, weight: .semibold))
                    Text(localizationManager.localized("structure_sidebar"))
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(showStructureSidebar ? .accentColor : .primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(showStructureSidebar ? Color.accentColor.opacity(0.15) : Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .help(localizationManager.localized("structure_sidebar"))

            Spacer()

            // 手繪與打字模式切換器 (Picker)
            Picker("", selection: $editorMode) {
                HStack(spacing: 4) {
                    Image(systemName: "pencil.tip")
                    Text(localizationManager.localized("handwriting_mode"))
                }
                .tag(EditorMode.draw)

                HStack(spacing: 4) {
                    Image(systemName: "keyboard")
                    Text(localizationManager.localized("typing_mode"))
                }
                .tag(EditorMode.type)
            }
            .pickerStyle(.segmented)
            .frame(width: 190)

            // 筆記標題（點擊可修改）
            Button {
                renameText = notebook.title
                showRenameAlert = true
            } label: {
                HStack(spacing: 6) {
                    Text(notebook.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Image(systemName: "pencil.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // 頁碼切換器
            HStack(spacing: 6) {
                Button {
                    if currentPageIndex > 0 {
                        saveCurrentPageDrawing()
                        currentPageIndex -= 1
                        loadCurrentPage()
                    }
                } label: {
                    Image(systemName: "chevron.left.circle")
                }
                .disabled(currentPageIndex <= 0)

                Text("P.\(currentPageIndex + 1)/\(max(1, notebook.pageCount))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Button {
                    if currentPageIndex < notebook.pageCount - 1 {
                        saveCurrentPageDrawing()
                        currentPageIndex += 1
                        loadCurrentPage()
                    }
                } label: {
                    Image(systemName: "chevron.right.circle")
                }
                .disabled(currentPageIndex >= notebook.pageCount - 1)

                // 新增頁面
                Button {
                    saveCurrentPageDrawing()
                    let empty = PKDrawing()
                    notebook.pageCount += 1
                    currentPageIndex = notebook.pageCount - 1
                    store.saveDrawing(notebookId: notebook.id, pageIndex: currentPageIndex, drawing: empty)
                    loadCurrentPage()
                    store.updateNotebook(notebook)
                } label: {
                    Image(systemName: "plus.square.dashed")
                        .foregroundColor(.accentColor)
                }
                .help(localizationManager.localized("add_page"))
            }

            Divider()
                .frame(height: 18)

            // 尺規切換開關
            Button {
                isRulerActive.toggle()
            } label: {
                Image(systemName: "ruler")
                    .foregroundColor(isRulerActive ? .accentColor : .secondary)
                    .padding(5)
                    .background(isRulerActive ? Color.accentColor.opacity(0.15) : Color.clear)
                    .cornerRadius(6)
            }
            .help(localizationManager.localized("ruler"))

            // 錄音按鈕
            if audioManager.status == .recording {
                Button {
                    stopAndSaveRecording()
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 7, height: 7)
                        Text(localizationManager.localized("stop_recording"))
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.12))
                    .cornerRadius(6)
                }
            } else {
                Button {
                    Task {
                        _ = await audioManager.startRecording(title: "\(notebook.title) 錄音")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "mic.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text(localizationManager.localized("record"))
                            .font(.caption2)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(6)
                }
            }

            // 匯出與列印選單（解決「看不到匯出相關工具列」問題）
            Menu {
                Button {
                    exportAsPdf()
                } label: {
                    Label(localizationManager.localized("export_pdf"), systemImage: "doc.text.fill")
                }

                Button {
                    exportAsPngImage()
                } label: {
                    Label(localizationManager.localized("export_image"), systemImage: "photo")
                }

                Button {
                    printCurrentNotebook()
                } label: {
                    Label(localizationManager.localized("print_note"), systemImage: "printer.fill")
                }

                Divider()

                Button {
                    shareNotebookFile()
                } label: {
                    Label(localizationManager.localized("share_note"), systemImage: "square.and.arrow.up")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                    Text(localizationManager.localized("export_print"))
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.accentColor)
                .cornerRadius(7)
                .shadow(color: Color.accentColor.opacity(0.3), radius: 2, y: 1)
            }
            .buttonStyle(.plain)
            .help(localizationManager.localized("export_print"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    // MARK: - 筆記結構目錄側邊欄（頁面縮圖大綱）
    private var notebookStructureSidebar: some View {
        VStack(spacing: 0) {
            // 側邊欄頂部操作
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sidebar.left")
                        .foregroundColor(.accentColor)
                    Text(localizationManager.localized("structure_sidebar"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                Spacer()

                Button {
                    saveCurrentPageDrawing()
                    let empty = PKDrawing()
                    notebook.pageCount += 1
                    currentPageIndex = notebook.pageCount - 1
                    store.saveDrawing(notebookId: notebook.id, pageIndex: currentPageIndex, drawing: empty)
                    loadCurrentPage()
                    store.updateNotebook(notebook)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized("add_page"))

                Button {
                    withAnimation {
                        showStructureSidebar = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(uiColor: .secondarySystemGroupedBackground))

            Divider()

            // 頁面縮圖卡片清單
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(0..<max(1, notebook.pageCount), id: \.self) { idx in
                        let isSelected = (idx == currentPageIndex)
                        VStack(spacing: 4) {
                            HStack {
                                Text("P.\(idx + 1)")
                                    .font(.caption)
                                    .fontWeight(isSelected ? .bold : .medium)
                                    .foregroundColor(isSelected ? .accentColor : .primary)

                                Spacer()

                                Menu {
                                    Button {
                                        duplicatePage(at: idx)
                                    } label: {
                                        Label(localizationManager.localized("duplicate_page"), systemImage: "plus.square.on.square")
                                    }

                                    Button {
                                        extendCurrentPage(by: 800)
                                    } label: {
                                        Label(localizationManager.localized("extend_page_amount"), systemImage: "arrow.down.to.line.compact")
                                    }

                                    if notebook.pageCount > 1 {
                                        Divider()
                                        Button(role: .destructive) {
                                            pageToDeleteIndex = idx
                                            showDeletePageAlert = true
                                        } label: {
                                            Label(localizationManager.localized("delete_page"), systemImage: "trash")
                                        }
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.caption)
                                        .padding(4)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 6)

                            // 縮圖預覽卡片
                            Button {
                                if currentPageIndex != idx {
                                    saveCurrentPageDrawing()
                                    currentPageIndex = idx
                                    loadCurrentPage()
                                }
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(uiColor: .systemBackground))
                                        .frame(height: 130)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2.5 : 1)
                                        )
                                        .shadow(color: Color.black.opacity(isSelected ? 0.15 : 0.04), radius: isSelected ? 4 : 2, y: 1)

                                    let pageDrawing = (idx == currentPageIndex) ? currentDrawing : store.loadDrawing(notebookId: notebook.id, pageIndex: idx)
                                    let img = pageDrawing.image(from: CGRect(x: 0, y: 0, width: 612, height: 792), scale: 0.5)
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxHeight: 120)
                                        .padding(4)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
                        .cornerRadius(8)
                    }
                }
                .padding(.vertical, 8)
            }

            Divider()

            // 結構摘要統計
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("\(localizationManager.localized("all_pages")): \(notebook.pageCount)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    let txtCount = (notebook.textAttachments ?? []).count
                    let imgCount = (notebook.attachments ?? []).count
                    let modelCount = (notebook.model3DAttachments ?? []).count
                    Text("文字:\(txtCount) 圖片:\(imgCount) 3D:\(modelCount)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    // MARK: - 2. 🌟 實體手繪工具列（水平滑動包裹、免擠壓、隨點隨用）
    private var drawingToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                // 工具選擇群組（鋼筆、原子筆、毛筆、麥克筆、螢光筆、鉛筆、水彩筆、橡皮擦、套索）
                HStack(spacing: 4) {
                    ForEach(EditorToolType.allCases) { tool in
                        Button {
                            selectedTool = tool
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: tool.iconName)
                                    .font(.system(size: 16, weight: selectedTool == tool ? .bold : .regular))
                                Text(localizationManager.localized(tool.localizationKey))
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(selectedTool == tool ? .accentColor : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(selectedTool == tool ? Color.accentColor.opacity(0.15) : Color.clear)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()
                    .frame(height: 24)

                // 筆刷粗細切換
                HStack(spacing: 6) {
                    ForEach([2.0, 4.0, 8.0, 14.0], id: \.self) { w in
                        Button {
                            strokeWidth = CGFloat(w)
                        } label: {
                            Circle()
                                .fill(strokeWidth == CGFloat(w) ? Color.accentColor : Color.secondary.opacity(0.5))
                                .frame(width: max(6, CGFloat(w)), height: max(6, CGFloat(w)))
                                .padding(4)
                                .background(strokeWidth == CGFloat(w) ? Color.accentColor.opacity(0.15) : Color.clear)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("\(localizationManager.localized("stroke_width")) \(Int(w))pt")
                    }
                }

                Divider()
                    .frame(height: 24)

                // 色彩選擇盤
                HStack(spacing: 6) {
                    ForEach(colorPalette, id: \.self) { color in
                        Button {
                            selectedColor = color
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(color)
                                    .frame(width: 18, height: 18)
                                if selectedColor == color {
                                    Circle()
                                        .stroke(Color.primary, lineWidth: 2)
                                        .frame(width: 22, height: 22)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    ColorPicker("", selection: $selectedColor)
                        .labelsHidden()
                        .frame(width: 24)

                    // 專業調色盤按鈕
                    Button {
                        showProColorPicker = true
                    } label: {
                        Image(systemName: "slider.horizontal.2.square")
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                            .padding(5)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help(localizationManager.localized("pro_color"))
                }

                // 若為套索選取工具，即時展開剪下、複製與刪除選取筆劃按鈕
                if selectedTool == .lasso {
                    Divider()
                        .frame(height: 24)

                    HStack(spacing: 6) {
                        Button {
                            cutSelectedStrokes()
                        } label: {
                            Image(systemName: "scissors")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .padding(6)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .help(localizationManager.localized("cut_selected"))

                        Button {
                            copySelectedStrokes()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .padding(6)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .help(localizationManager.localized("copy_selected"))

                        Button {
                            deleteSelectedStrokes()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "trash.fill")
                                    .font(.caption)
                                Text(localizationManager.localized("delete_selected"))
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.red)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .help(localizationManager.localized("delete_selected"))
                    }
                }

                // 延長本頁按鈕
                Button {
                    extendCurrentPage(by: 800)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.to.line.compact")
                            .font(.system(size: 13, weight: .semibold))
                        Text(localizationManager.localized("extend_page"))
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized("extend_page_amount"))

                Divider()
                    .frame(height: 24)

                // 插入圖片按鈕
                Button {
                    showPhotoPicker = true
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 15))
                        Text(localizationManager.localized("insert_image"))
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized("insert_image"))

                // 算式計算按鈕
                Button {
                    showMathCalculator = true
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "plus.forwardslash.minus")
                            .font(.system(size: 15))
                        Text(localizationManager.localized("math_calc"))
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized("math_calc"))

                // 數字製圖按鈕
                Button {
                    showChartStudio = true
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 15))
                        Text(localizationManager.localized("chart_studio"))
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized("chart_studio"))

                // 🪄 草圖智慧修飾按鈕
                Button {
                    withAnimation {
                        showSketchRefineBar.toggle()
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 15))
                        Text(localizationManager.localized("refine_sketch"))
                            .font(.system(size: 10))
                    }
                    .foregroundColor(showSketchRefineBar ? .purple : .primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(showSketchRefineBar ? Color.purple.opacity(0.15) : Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized("refine_sketch"))

                // 🧊 3D 模型插入按鈕
                Button {
                    show3DStudio = true
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 15))
                        Text(localizationManager.localized("insert_3d"))
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized("insert_3d"))

                // 📦 素材圖庫按鈕
                Button {
                    showAssetLibrarySheet = true
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 15))
                        Text(localizationManager.localized("asset_library"))
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized("asset_library"))

                // 🎨 三大主題專屬加速工具按鈕
                Button {
                    showThemeToolsSheet = true
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 15))
                        Text(localizationManager.localized("theme_tools"))
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.purple)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.15))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized("theme_tools"))

                Divider()
                    .frame(height: 24)

                // 復原與重做
                HStack(spacing: 8) {
                    Button {
                        canvasView?.undoManager?.undo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .help("復原 (Undo)")

                    Button {
                        canvasView?.undoManager?.redo()
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .help(localizationManager.localized("redo"))

                    Button {
                        showClearConfirmAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .foregroundColor(.red.opacity(0.8))
                    }
                    .help(localizationManager.localized("clear_page"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
    }

    // MARK: - 🌟 實體鍵盤打字與排版工具列
    private var typingToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // 插入文字方塊
                Button {
                    newTextDraft = NoteTextAttachment(pageIndex: currentPageIndex)
                    showWordStudio = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "character.textbox")
                            .font(.system(size: 14, weight: .semibold))
                        Text(localizationManager.localized("tool_text"))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized("word_studio"))

                Divider().frame(height: 22)

                // 快速插入常用符號群組
                Menu {
                    Menu(localizationManager.localized("math_symbols")) {
                        ForEach(["π", "∑", "√", "±", "≠", "≤", "≥", "∞", "∫", "∂", "≈", "÷", "×", "∆", "θ"], id: \.self) { sym in
                            Button(sym) {
                                insertQuickTextSnippet(sym)
                            }
                        }
                    }

                    Menu(localizationManager.localized("punctuation_symbols")) {
                        ForEach(["「", "」", "『", "』", "【", "】", "—", "…", "《", "》", "•", "※", "§"], id: \.self) { sym in
                            Button(sym) {
                                insertQuickTextSnippet(sym)
                            }
                        }
                    }

                    Menu(localizationManager.localized("roman_symbols")) {
                        ForEach(["Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ", "Ⅴ", "Ⅵ", "Ⅶ", "Ⅷ", "Ⅸ", "Ⅹ", "Ⅺ", "Ⅻ"], id: \.self) { sym in
                            Button(sym) {
                                insertQuickTextSnippet(sym)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "star.bubble")
                            .font(.system(size: 14))
                        Text(localizationManager.localized("special_symbols"))
                            .font(.system(size: 11))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // 插入連結
                Button {
                    showLinkPreviewSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 14))
                        Text(localizationManager.localized("insert_link"))
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized("insert_link"))

                // 插入圖片
                Button {
                    showPhotoPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 14))
                        Text(localizationManager.localized("insert_image"))
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // 算式計算
                Button {
                    showMathCalculator = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.forwardslash.minus")
                            .font(.system(size: 14))
                        Text(localizationManager.localized("math_calc"))
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // 數字製圖
                Button {
                    showChartStudio = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 14))
                        Text(localizationManager.localized("chart_studio"))
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // 插入 3D 模型
                Button {
                    show3DStudio = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 14))
                        Text(localizationManager.localized("insert_3d"))
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // 📦 素材圖庫按鈕
                Button {
                    showAssetLibrarySheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 14))
                        Text(localizationManager.localized("asset_library"))
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // 🎨 三大主題加速工具按鈕
                Button {
                    showThemeToolsSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 14))
                        Text(localizationManager.localized("theme_tools"))
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.purple.opacity(0.15))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // 延長本頁
                Button {
                    extendCurrentPage(by: 800)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.to.line.compact")
                            .font(.system(size: 13, weight: .semibold))
                        Text(localizationManager.localized("extend_page"))
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Spacer()

                // 復原與重做
                HStack(spacing: 8) {
                    Button {
                        canvasView?.undoManager?.undo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .help("復原 (Undo)")

                    Button {
                        canvasView?.undoManager?.redo()
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .help(localizationManager.localized("redo"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
    }

    // MARK: - 3. 尺規旋轉與量測輔助列
    private var rulerControlBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "ruler")
                .foregroundColor(.accentColor)

            Text(localizationManager.localized("ruler_mode"))
                .font(.caption)
                .fontWeight(.bold)

            Text(localizationManager.localized("ruler_hint"))
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer()

            Button(localizationManager.localized("close_ruler")) {
                isRulerActive = false
            }
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.15))
            .cornerRadius(6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.1))
    }

    // MARK: - 4. 錄音播放器橫條
    private func audioPlaybackBar(fileName: String) -> some View {
        let fileUrl = audioManager.recordingsDirectory.appendingPathComponent(fileName)
        let isCurrentPlaying = audioManager.isPlaying && audioManager.playingRecordingId == fileName

        return HStack(spacing: 12) {
            Button {
                audioManager.playAudio(url: fileUrl, recordingId: fileName)
            } label: {
                Image(systemName: isCurrentPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title3)
                    .foregroundColor(.accentColor)
            }

            Text(localizationManager.localized("attached_audio"))
                .font(.caption)
                .fontWeight(.medium)

            ProgressView(value: isCurrentPlaying ? audioManager.playbackProgress : 0.0)
                .progressViewStyle(.linear)

            Button {
                notebook.hasRecording = false
                notebook.recordingAudioPath = nil
                store.updateNotebook(notebook)
                audioManager.stopPlayback()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.08))
    }

    // MARK: - 5. 即時錄音狀態列
    private var liveRecordingBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                Text("同步錄音中: \(formatTime(seconds: audioManager.elapsedSeconds))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
            }

            HStack(spacing: 2) {
                ForEach(0..<audioManager.audioLevels.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.red)
                        .frame(width: 3, height: max(4, audioManager.audioLevels[i] * 24))
                }
            }
            .frame(height: 24)

            Spacer()

            Button(localizationManager.localized("finish_recording")) {
                stopAndSaveRecording()
            }
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.red)
            .cornerRadius(6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.08))
    }

    // MARK: - 6. 畫布上之即時浮動錄音圖示徽章
    private func floatingAudioBadge(fileName: String) -> some View {
        let fileUrl = audioManager.recordingsDirectory.appendingPathComponent(fileName)
        let isCurrentPlaying = audioManager.isPlaying && audioManager.playingRecordingId == fileName

        return HStack(spacing: 8) {
            Button {
                audioManager.playAudio(url: fileUrl, recordingId: fileName)
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 28, height: 28)
                    Image(systemName: isCurrentPlaying ? "pause.fill" : "play.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.caption2)
                        .foregroundColor(.red)
                    Text(isCurrentPlaying ? localizationManager.localized("audio_playing") : localizationManager.localized("attached_audio"))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                Text(localizationManager.localized("audio_hint"))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Divider()
                .frame(height: 18)

            Button {
                audioManager.openRecordingsFolderInFinder()
            } label: {
                Image(systemName: "folder")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .help(localizationManager.localized("open_folder"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)
    }

    // MARK: - 7. 🌟 套索選取浮動工具列（圈選筆跡後隨選隨刪、隨選隨複製）
    private var lassoFloatingActionBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "lasso")
                .foregroundColor(.accentColor)
                .font(.subheadline)

            Text(localizationManager.localized("lasso_active_hint"))
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Divider()
                .frame(height: 16)

            Button {
                cutSelectedStrokes()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "scissors")
                    Text(localizationManager.localized("cut_selected"))
                }
                .font(.caption2)
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            Button {
                copySelectedStrokes()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                    Text(localizationManager.localized("copy_selected"))
                }
                .font(.caption2)
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            Button {
                deleteSelectedStrokes()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                    Text(localizationManager.localized("delete_selected"))
                }
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.red)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)
    }

    // MARK: - 🌟 草圖智慧修飾浮動控制面板
    private var sketchRefineFloatingBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(.purple)
                    .font(.system(size: 15, weight: .bold))
                Text(localizationManager.localized("refine_sketch"))
                    .font(.subheadline.bold())
            }

            Divider()
                .frame(height: 20)

            // 修飾強度調節
            HStack(spacing: 6) {
                Text("\(localizationManager.localized("refine_strength")): \(Int(refineIntensity * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $refineIntensity, in: 0.2...1.0, step: 0.05)
                    .frame(width: 90)
            }

            Divider()
                .frame(height: 20)

            // 一鍵修飾
            Button {
                applySketchRefine()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                    Text(localizationManager.localized("apply_refine"))
                        .font(.caption.bold())
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.purple)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            // 恢復原草圖
            Button {
                restoreOriginalSketch()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                    Text(localizationManager.localized("restore_original"))
                        .font(.caption)
                }
                .foregroundColor(originalSketchBackup != nil ? .primary : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(originalSketchBackup != nil ? 0.15 : 0.06))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(originalSketchBackup == nil)

            // 重做修飾
            Button {
                redoSketchRefine()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.forward")
                    Text(localizationManager.localized("redo_refine"))
                        .font(.caption)
                }
                .foregroundColor(refinedSketchCache != nil ? .primary : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(refinedSketchCache != nil ? 0.15 : 0.06))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(refinedSketchCache == nil)

            Spacer()

            // 關閉控制列
            Button {
                withAnimation {
                    showSketchRefineBar = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.12), radius: 8, y: 3)
        .padding(.horizontal, 16)
    }

    private func applySketchRefine() {
        guard !currentDrawing.strokes.isEmpty else { return }
        if originalSketchBackup == nil {
            originalSketchBackup = currentDrawing
        }
        let refined = SketchRefineEngine.refine(drawing: currentDrawing, intensity: refineIntensity)
        refinedSketchCache = refined
        currentDrawing = refined
        canvasView?.drawing = refined
        store.saveDrawing(notebookId: notebook.id, pageIndex: currentPageIndex, drawing: refined)
    }

    private func restoreOriginalSketch() {
        guard let original = originalSketchBackup else { return }
        currentDrawing = original
        canvasView?.drawing = original
        store.saveDrawing(notebookId: notebook.id, pageIndex: currentPageIndex, drawing: original)
    }

    private func redoSketchRefine() {
        guard let refined = refinedSketchCache else { return }
        currentDrawing = refined
        canvasView?.drawing = refined
        store.saveDrawing(notebookId: notebook.id, pageIndex: currentPageIndex, drawing: refined)
    }

    // MARK: - 儲存、延伸與套索編輯核心
    private func loadCurrentPage() {
        let loaded = store.loadDrawing(notebookId: notebook.id, pageIndex: currentPageIndex)
        self.currentDrawing = loaded
        self.currentPageHeight = notebook.height(forPage: currentPageIndex, defaultHeight: 1800)
        self.hasLassoSelection = false
        self.originalSketchBackup = nil
        self.refinedSketchCache = nil
    }

    private func saveCurrentPageDrawing() {
        store.saveDrawing(notebookId: notebook.id, pageIndex: currentPageIndex, drawing: currentDrawing)
        notebook.setHeight(currentPageHeight, forPage: currentPageIndex)
        notebook.lastModifiedDate = Date()
        store.updateNotebook(notebook)
    }

    private func extendCurrentPage(by amount: CGFloat = 800) {
        currentPageHeight += amount
        notebook.setHeight(currentPageHeight, forPage: currentPageIndex)
        store.updateNotebook(notebook)

        withAnimation {
            showExtendedBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showExtendedBanner = false
            }
        }

        if let canvas = canvasView {
            let targetY = max(0, canvas.contentSize.height - canvas.bounds.height)
            canvas.setContentOffset(CGPoint(x: 0, y: targetY), animated: true)
        }
    }

    private func deleteSelectedStrokes() {
        guard let canvas = canvasView else { return }
        for sv in canvas.subviews where String(describing: type(of: sv)).contains("PKTiledView") {
            if sv.responds(to: #selector(UIResponderStandardEditActions.delete(_:))) {
                sv.perform(#selector(UIResponderStandardEditActions.delete(_:)), with: nil)
            }
        }
        UIApplication.shared.sendAction(#selector(UIResponderStandardEditActions.delete(_:)), to: nil, from: nil, for: nil)
        self.currentDrawing = canvas.drawing
        self.saveCurrentPageDrawing()
        hasLassoSelection = false
    }

    private func cutSelectedStrokes() {
        guard let canvas = canvasView else { return }
        for sv in canvas.subviews where String(describing: type(of: sv)).contains("PKTiledView") {
            if sv.responds(to: #selector(UIResponderStandardEditActions.cut(_:))) {
                sv.perform(#selector(UIResponderStandardEditActions.cut(_:)), with: nil)
            }
        }
        UIApplication.shared.sendAction(#selector(UIResponderStandardEditActions.cut(_:)), to: nil, from: nil, for: nil)
        self.currentDrawing = canvas.drawing
        self.saveCurrentPageDrawing()
        hasLassoSelection = false
    }

    private func copySelectedStrokes() {
        guard let canvas = canvasView else { return }
        for sv in canvas.subviews where String(describing: type(of: sv)).contains("PKTiledView") {
            if sv.responds(to: #selector(UIResponderStandardEditActions.copy(_:))) {
                sv.perform(#selector(UIResponderStandardEditActions.copy(_:)), with: nil)
            }
        }
        UIApplication.shared.sendAction(#selector(UIResponderStandardEditActions.copy(_:)), to: nil, from: nil, for: nil)
    }

    private func stopAndSaveRecording() {
        if let result = audioManager.stopRecording() {
            let fileName = result.url.lastPathComponent
            notebook.hasRecording = true
            notebook.recordingAudioPath = fileName
            store.updateNotebook(notebook)
            store.addRecording(
                title: "\(notebook.title) 課程錄音",
                durationSeconds: Int(result.duration),
                fileName: fileName,
                linkedNotebookId: notebook.id
            )
        }
    }

    private func exportAsPdf() {
        saveCurrentPageDrawing()
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let pdf = renderer.pdfData { context in
            for i in 0..<max(1, notebook.pageCount) {
                context.beginPage()
                let drawing = (i == currentPageIndex) ? currentDrawing : store.loadDrawing(notebookId: notebook.id, pageIndex: i)
                let image = drawing.image(from: bounds, scale: 2.0)
                image.draw(in: bounds)
            }
        }
        self.exportPdfData = pdf
        self.showShareSheet = true
    }

    private func printCurrentNotebook() {
        saveCurrentPageDrawing()
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let pdfData = renderer.pdfData { context in
            for i in 0..<max(1, notebook.pageCount) {
                context.beginPage()
                let drawing = (i == currentPageIndex) ? currentDrawing : store.loadDrawing(notebookId: notebook.id, pageIndex: i)
                let img = drawing.image(from: bounds, scale: 2.0)
                img.draw(in: bounds)
            }
        }

        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = notebook.title
        printController.printInfo = printInfo
        printController.printingItem = pdfData
        printController.present(animated: true, completionHandler: nil)
    }

    private func exportAsPngImage() {
        saveCurrentPageDrawing()
        let bounds = CGRect(x: 0, y: 0, width: 612, height: max(792, currentPageHeight))
        let img = currentDrawing.image(from: bounds, scale: 2.0)
        if let pngData = img.pngData() {
            self.exportPdfData = pngData
            self.showShareSheet = true
        }
    }

    private func shareNotebookFile() {
        exportAsPdf()
    }

    private func duplicatePage(at index: Int) {
        saveCurrentPageDrawing()
        let drawingToCopy = store.loadDrawing(notebookId: notebook.id, pageIndex: index)

        // Shift drawings after index
        let total = notebook.pageCount
        var p = total
        while p > index + 1 {
            let prev = store.loadDrawing(notebookId: notebook.id, pageIndex: p - 1)
            store.saveDrawing(notebookId: notebook.id, pageIndex: p, drawing: prev)
            p -= 1
        }
        store.saveDrawing(notebookId: notebook.id, pageIndex: index + 1, drawing: drawingToCopy)

        notebook.pageCount += 1
        currentPageIndex = index + 1
        loadCurrentPage()
        store.updateNotebook(notebook)
    }

    private func deletePage(at index: Int) {
        guard notebook.pageCount > 1 else { return }
        let total = notebook.pageCount
        var p = index
        while p < total - 1 {
            let next = store.loadDrawing(notebookId: notebook.id, pageIndex: p + 1)
            store.saveDrawing(notebookId: notebook.id, pageIndex: p, drawing: next)
            p += 1
        }

        notebook.pageCount -= 1
        if currentPageIndex >= notebook.pageCount {
            currentPageIndex = max(0, notebook.pageCount - 1)
        }
        loadCurrentPage()
        store.updateNotebook(notebook)
    }

    private func insertQuickTextSnippet(_ text: String) {
        let newBox = NoteTextAttachment(
            pageIndex: currentPageIndex,
            text: text,
            fontSize: 24,
            isBold: true,
            x: 100,
            y: 120,
            width: 160,
            height: 60
        )
        if notebook.textAttachments == nil {
            notebook.textAttachments = []
        }
        notebook.textAttachments?.append(newBox)
        store.updateNotebook(notebook)
    }

    private func formatTime(seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - 附件管理核心
    private func insertImageAttachment(_ image: UIImage) {
        guard let fileName = store.saveAttachmentImage(image) else { return }
        let aspect = image.size.width / max(1, image.size.height)
        let w: CGFloat = 280
        let h: CGFloat = max(80, w / aspect)
        let newAttachment = NoteImageAttachment(
            fileName: fileName,
            pageIndex: currentPageIndex,
            x: 80,
            y: 120,
            width: w,
            height: h,
            rotationDegrees: 0,
            cornerRadius: 8,
            hasShadow: true,
            hasBorder: false,
            filterStyle: .original
        )
        if notebook.attachments == nil {
            notebook.attachments = []
        }
        notebook.attachments?.append(newAttachment)
        store.updateNotebook(notebook)
    }

    private func binding(for id: String) -> Binding<NoteImageAttachment> {
        Binding(
            get: {
                notebook.attachments?.first(where: { $0.id == id }) ?? NoteImageAttachment(fileName: "")
            },
            set: { updated in
                if let idx = notebook.attachments?.firstIndex(where: { $0.id == id }) {
                    notebook.attachments?[idx] = updated
                    store.updateNotebook(notebook)
                }
            }
        )
    }

    private func binding(forTextId id: String) -> Binding<NoteTextAttachment> {
        Binding(
            get: {
                notebook.textAttachments?.first(where: { $0.id == id }) ?? NoteTextAttachment()
            },
            set: { updated in
                if let idx = notebook.textAttachments?.firstIndex(where: { $0.id == id }) {
                    notebook.textAttachments?[idx] = updated
                    store.updateNotebook(notebook)
                }
            }
        )
    }

    private func binding(forLinkId id: String) -> Binding<NoteLinkAttachment> {
        Binding(
            get: {
                notebook.linkAttachments?.first(where: { $0.id == id }) ?? NoteLinkAttachment(urlString: "")
            },
            set: { updated in
                if let idx = notebook.linkAttachments?.firstIndex(where: { $0.id == id }) {
                    notebook.linkAttachments?[idx] = updated
                    store.updateNotebook(notebook)
                }
            }
        )
    }

    private func binding(forModel3DId id: String) -> Binding<Note3DAttachment> {
        Binding(
            get: {
                notebook.model3DAttachments?.first(where: { $0.id == id }) ?? Note3DAttachment()
            },
            set: { updated in
                if let idx = notebook.model3DAttachments?.firstIndex(where: { $0.id == id }) {
                    notebook.model3DAttachments?[idx] = updated
                    store.updateNotebook(notebook)
                }
            }
        )
    }
}

/// 系統分享面板封裝
struct ShareActivityView: UIViewControllerRepresentable {
    let data: Data
    let filename: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: tempUrl)
        return UIActivityViewController(activityItems: [tempUrl], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// 畫布內嵌附件視圖（支援圖片、算式卡片、數據圖表）
/// 支援手勢拖曳平移、角落手柄縮放、即時濾鏡美化、邊框、立體陰影與旋轉
struct AttachmentItemView: View {
    @Binding var attachment: NoteImageAttachment
    let onEdit: () -> Void
    let onDelete: () -> Void

    @ObservedObject var store = NotebookStore.shared
    @State private var dragOffset: CGSize = .zero
    @State private var isSelected: Bool = false

    var body: some View {
        let currentX = attachment.x + dragOffset.width
        let currentY = attachment.y + dragOffset.height

        ZStack(alignment: .topTrailing) {
            Group {
                if let uiImage = store.loadAttachmentImage(fileName: attachment.fileName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: attachment.width, height: attachment.height)
                        .modifier(ImageFilterModifier(filter: attachment.filterStyle))
                        .objectMaterial(attachment.materialType)
                        .clipShape(RoundedRectangle(cornerRadius: attachment.cornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: attachment.cornerRadius)
                                .stroke(attachment.hasBorder ? Color.white : (isSelected ? Color.accentColor : Color.clear), lineWidth: attachment.hasBorder ? 3 : 1.5)
                        )
                        .shadow(color: attachment.hasShadow ? Color.black.opacity(0.2) : Color.clear, radius: 8, x: 2, y: 4)
                        .rotationEffect(.degrees(attachment.rotationDegrees))
                } else {
                    RoundedRectangle(cornerRadius: attachment.cornerRadius)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: attachment.width, height: attachment.height)
                        .overlay(
                            ProgressView()
                        )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isSelected.toggle()
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        attachment.x += value.translation.width
                        attachment.y += value.translation.height
                        dragOffset = .zero
                    }
            )

            // 選取時顯示浮動小操作把手：編輯（美化）、刪除、右下角縮放把手
            if isSelected {
                HStack(spacing: 6) {
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .offset(x: 10, y: -10)

                // 右下角縮放把手
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newW = max(80, attachment.width + value.translation.width)
                                        let ratio = attachment.height / max(1, attachment.width)
                                        let newH = max(60, newW * ratio)
                                        attachment.width = newW
                                        attachment.height = newH
                                    }
                            )
                            .offset(x: 6, y: 6)
                    }
                }
                .frame(width: attachment.width, height: attachment.height)
            }
        }
        .position(x: currentX + attachment.width / 2, y: currentY + attachment.height / 2)
    }
}

/// 圖片濾鏡 ViewModifier
struct ImageFilterModifier: ViewModifier {
    let filter: ImageFilterStyle

    func body(content: Content) -> some View {
        switch filter {
        case .original:
            content
        case .vintage:
            content
                .colorMultiply(Color(red: 0.95, green: 0.88, blue: 0.75))
                .contrast(1.1)
                .saturation(0.8)
        case .mono:
            content
                .grayscale(1.0)
                .contrast(1.2)
        case .contrast:
            content
                .contrast(1.3)
                .saturation(1.2)
        case .warm:
            content
                .colorMultiply(Color(red: 1.0, green: 0.93, blue: 0.85))
                .brightness(0.04)
        }
    }
}

/// 畫布內嵌 Word 文字卡片視圖
struct TextAttachmentItemView: View {
    @Binding var textItem: NoteTextAttachment
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isSelected: Bool = false

    var body: some View {
        let currentX = textItem.x + dragOffset.width
        let currentY = textItem.y + dragOffset.height

        ZStack(alignment: .topTrailing) {
            VStack(alignment: resolveAlignment(textItem.alignmentRaw), spacing: 4) {
                Text(textItem.text)
                    .font(.system(size: textItem.fontSize, weight: textItem.isBold ? .bold : .regular))
                    .italic(textItem.isItalic)
                    .underline(textItem.isUnderline)
                    .strikethrough(textItem.isStrikethrough)
                    .foregroundColor(Color(hex: textItem.textColorHex) ?? .primary)
                    .multilineTextAlignment(resolveMultilineAlignment(textItem.alignmentRaw))
                    .frame(maxWidth: .infinity, alignment: resolveFrameAlignment(textItem.alignmentRaw))
            }
            .padding(14)
            .frame(width: textItem.width)
            .background(resolveBackground(textItem.backgroundColorHex))
            .clipShape(RoundedRectangle(cornerRadius: textItem.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: textItem.cornerRadius)
                    .stroke(textItem.hasBorder ? Color.secondary.opacity(0.35) : (isSelected ? Color.accentColor : Color.clear), lineWidth: textItem.hasBorder ? 1.5 : 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
            .contentShape(Rectangle())
            .onTapGesture {
                isSelected.toggle()
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        textItem.x += value.translation.width
                        textItem.y += value.translation.height
                        dragOffset = .zero
                    }
            )

            // 選取時浮動把手
            if isSelected {
                HStack(spacing: 6) {
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .offset(x: 10, y: -10)

                // 右下角縮放把手
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.left.and.right")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        textItem.width = max(140, textItem.width + value.translation.width)
                                    }
                            )
                            .offset(x: 6, y: 6)
                    }
                }
                .frame(width: textItem.width)
            }
        }
        .position(x: currentX + textItem.width / 2, y: currentY + 60)
    }

    private func resolveBackground(_ hex: String) -> Color {
        if hex == "clear" { return .clear }
        return Color(hex: hex) ?? .white
    }

    private func resolveAlignment(_ raw: String) -> HorizontalAlignment {
        switch raw {
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }

    private func resolveMultilineAlignment(_ raw: String) -> TextAlignment {
        switch raw {
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }

    private func resolveFrameAlignment(_ raw: String) -> Alignment {
        switch raw {
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }
}

/// 畫布內嵌 Rich Link 預覽卡片視圖
struct LinkAttachmentItemView: View {
    @Binding var linkItem: NoteLinkAttachment
    let onDelete: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isSelected: Bool = false

    var body: some View {
        let currentX = linkItem.x + dragOffset.width
        let currentY = linkItem.y + dragOffset.height

        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    Text(linkItem.siteName.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()

                    // 開啟連結外鏈圖示
                    Button {
                        if let url = URL(string: linkItem.urlString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text("開啟")
                                .font(.system(size: 10, weight: .medium))
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }

                Text(linkItem.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                    .foregroundColor(.primary)

                if !linkItem.descriptionText.isEmpty {
                    Text(linkItem.descriptionText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .frame(width: linkItem.width)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
            .contentShape(Rectangle())
            .onTapGesture {
                isSelected.toggle()
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        linkItem.x += value.translation.width
                        linkItem.y += value.translation.height
                        dragOffset = .zero
                    }
            )

            // 選取時刪除按鈕
            if isSelected {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(5)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .offset(x: 8, y: -8)
            }
        }
        .position(x: currentX + linkItem.width / 2, y: currentY + 50)
    }
}

/// 畫布內嵌 3D 幾何模型互動項目視圖
struct Model3DCanvasItemView: View {
    @Binding var item: Note3DAttachment
    let onDelete: () -> Void

    @State private var dragOffset: CGSize = .zero

    var body: some View {
        let currentX = item.x + dragOffset.width
        let currentY = item.y + dragOffset.height

        VStack(spacing: 0) {
            // 移動拖曳手把條（與 3D 旋轉手勢分離，方便自由平移卡片）
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text("拖曳移動卡片")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(8)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        item.x += value.translation.width
                        item.y += value.translation.height
                        dragOffset = .zero
                    }
            )

            Model3DInteractiveCardView(
                attachment: $item,
                onDelete: onDelete
            )
        }
        .frame(width: max(200, item.width))
        .position(x: currentX + item.width / 2, y: currentY + item.height / 2)
    }
}
