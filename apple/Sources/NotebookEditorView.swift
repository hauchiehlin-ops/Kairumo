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
    case pen = "pen"
    case ballpoint = "ballpoint"
    case brush = "brush"
    case marker = "marker"
    case highlighter = "highlighter"
    case pencil = "pencil"
    case watercolor = "watercolor"
    case eraser = "eraser"
    case lasso = "lasso"

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

    /// 畫出頁面與可列印區的界線。
    ///
    /// 使用者要看得到「這一頁到哪裡為止」，而且那條線必須**就是**匯出與列印
    /// 的邊界 —— 畫一條僅供參考的框線，比不畫還糟：他會相信它。
    ///
    /// 頁面之外的區域畫成灰底，因為在寬螢幕上畫布比頁面寬，不畫的話使用者
    /// 會以為整片都能寫。
    private func drawPageBoundary(_ ctx: CGContext) {
        let page = PageGeometry.rect

        // 頁面以外（寬螢幕上右側多出來的部分）
        if bounds.width > page.width {
            UIColor.secondarySystemBackground.setFill()
            ctx.fill(CGRect(x: page.maxX, y: 0, width: bounds.width - page.width, height: bounds.height))
        }

        // 頁面邊緣
        UIColor.separator.setStroke()
        let edge = UIBezierPath(rect: page)
        edge.lineWidth = 1
        edge.stroke()

        // 可列印區：虛線，明顯是輔助線而不是內容
        UIColor.tertiaryLabel.setStroke()
        let printable = UIBezierPath(rect: PageGeometry.printableRect)
        printable.lineWidth = 1
        printable.setLineDash([6, 5], count: 2, phase: 0)
        printable.stroke()
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        drawPageBoundary(ctx)

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

/// 會在版面變動時自行重算內容寬度的畫布。
///
/// 為什麼需要子類：`updateUIView` 是在 SwiftUI 狀態改變時呼叫，那個時間點
/// `bounds.width` 還是**舊的**（版面尚未跑完）。所以收合左側結構欄之後，
/// contentSize 仍停在「扣掉側欄」的寬度，畫布右側就空出一塊灰色。
/// 真正知道新寬度的時機是 `layoutSubviews`。
final class AdaptiveCanvasView: PKCanvasView {
    /// 這一頁的高度（由 SwiftUI 端更新）
    var pageContentHeight: CGFloat = PageGeometry.height {
        didSet { if pageContentHeight != oldValue { syncContentSize() } }
    }
    /// 底層樣板背景，要跟著 contentSize 一起變
    weak var templateBackgroundView: UIView?

    override func layoutSubviews() {
        super.layoutSubviews()
        syncContentSize()
    }

    func syncContentSize() {
        let targetWidth = max(bounds.width, 1)
        let targetHeight = max(pageContentHeight, bounds.height)
        let target = CGSize(width: targetWidth, height: targetHeight)
        guard contentSize != target else { return }
        contentSize = target
        templateBackgroundView?.frame = CGRect(origin: .zero, size: target)
        templateBackgroundView?.setNeedsDisplay()
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
    var editorMode: EditorMode = .draw
    var onDrawingChanged: ((PKDrawing) -> Void)?
    /// 筆跡寫到接近頁尾時通知編輯器。
    ///
    /// 舊版是「把這一頁拉長」，於是同一本筆記裡每頁高度都不同，匯出與列印
    /// 無從對齊紙張。現在頁面高度固定，到底了就準備下一頁。
    var onReachedPageBottom: (() -> Void)?
    var onSelectionChanged: ((Bool) -> Void)?
    var canvasRef: ((PKCanvasView) -> Void)?
    /// 回報捲動狀態（可見比例、捲動比例），給自訂捲軸用
    var onScrollMetrics: ((_ visibleFraction: CGFloat, _ scrollFraction: CGFloat) -> Void)?

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = AdaptiveCanvasView()
        canvas.drawingPolicy = (editorMode == .draw) ? .anyInput : .pencilOnly
        canvas.delegate = context.coordinator
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = true
        canvas.alwaysBounceVertical = true
        canvas.showsVerticalScrollIndicator = true
        canvas.showsHorizontalScrollIndicator = false
        canvas.drawing = drawing

        // 給自動化測試一個穩定的抓取點（畫面上有多個 scroll view）
        canvas.accessibilityIdentifier = "kairumo.canvas"
        canvas.pageContentHeight = PageGeometry.height
        canvas.contentSize = CGSize(width: max(canvas.bounds.width, 1), height: canvas.pageContentHeight)

        // 嵌入底層背景樣板視圖（隨畫布滾動）
        let bgView = TemplateCanvasBackgroundView(frame: CGRect(origin: .zero, size: canvas.contentSize))
        bgView.template = template
        canvas.insertSubview(bgView, at: 0)
        canvas.templateBackgroundView = bgView
        context.coordinator.backgroundView = bgView

        context.coordinator.parent = self
        context.coordinator.applyTool(to: canvas)
        canvasRef?(canvas)

        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        let targetPolicy: PKCanvasViewDrawingPolicy = (editorMode == .draw) ? .anyInput : .pencilOnly
        if uiView.drawingPolicy != targetPolicy {
            uiView.drawingPolicy = targetPolicy
        }
        if uiView.drawing != drawing {
            context.coordinator.isProgrammaticUpdate = true
            uiView.drawing = drawing
            context.coordinator.isProgrammaticUpdate = false
        }
        uiView.isRulerActive = isRulerActive

        // 更新高度與滾動範圍。寬度交給 AdaptiveCanvasView 在 layoutSubviews 處理 ——
        // 這裡拿到的 bounds 可能還是版面變動前的舊值。
        if let adaptive = uiView as? AdaptiveCanvasView {
            adaptive.pageContentHeight = PageGeometry.height
            adaptive.syncContentSize()
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
        /// 把捲動狀態回報給 SwiftUI（自訂捲軸需要）
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            reportScrollMetrics(scrollView)
        }

        func reportScrollMetrics(_ scrollView: UIScrollView) {
            let contentH = max(scrollView.contentSize.height, 1)
            let viewportH = scrollView.bounds.height
            let visible = min(1, viewportH / contentH)
            let scrollable = max(contentH - viewportH, 1)
            let fraction = min(1, max(0, scrollView.contentOffset.y / scrollable))
            parent.onScrollMetrics?(visible, fraction)
        }

        var parent: CanvasRepresentable
        weak var backgroundView: TemplateCanvasBackgroundView?
        var isProgrammaticUpdate: Bool = false

        init(_ parent: CanvasRepresentable) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isProgrammaticUpdate else { return }
            parent.drawing = canvasView.drawing
            parent.onDrawingChanged?(canvasView.drawing)

            // 寫到接近頁尾就先把下一頁準備好。
            //
            // 刻意**不自動翻頁**：使用者可能只是把最後一行寫到很下面，
            // 畫面自己跳走比繼續留在原地更糟。準備好下一頁、讓他自己翻。
            let maxY = canvasView.drawing.bounds.maxY
            if maxY > 0 && maxY + 200 > PageGeometry.height {
                parent.onReachedPageBottom?()
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

    // 線上多人即時協同狀態
    @ObservedObject var collaborationManager = CollaborationManager.shared
    @State private var showCollaborationSheet: Bool = false
    @State private var isApplyingRemoteUpdate: Bool = false
    @State private var lastStrokeCount: Int = 0
    // 第二階段協同防護與討論狀態
    @State private var isPlacingCommentPin: Bool = false
    @State private var selectedCommentPinId: String? = nil
    @State private var deletedAttachmentBackup: (type: String, data: Any)? = nil

    private var isCollaborating: Bool {
        if case .connected = collaborationManager.status {
            return true
        }
        return false
    }

    // 筆記主模式：手繪 (Draw) vs 鍵盤打字 (Type)
    @State private var editorMode: EditorMode = .draw

    public enum SidebarTabMode: String, CaseIterable, Identifiable {
        case pages = "pages"
        case folders = "folders"
        public var id: String { rawValue }
    }

    // 筆記結構欄（側邊頁面縮圖大綱目錄欄）
    // 開啟筆記時預設展開，否則使用者每次進入新筆記都要先自己按一次才看得到
    // 資料夾目錄，等於把「這則筆記放在哪裡」藏起來。
    @State private var showStructureSidebar: Bool = false
    /// 畫布目前的實際內容寬度。縮圖要用同一個寬度算，物件位置與比例才會對得上。
    @State private var canvasContentWidth: CGFloat = PageThumbnailRenderer.minPageWidth
    // 自訂捲軸狀態：iOS 原生捲動指示器不接受互動，Mac 上使用者會想用游標拖它
    @State private var canvasVisibleFraction: CGFloat = 1
    @State private var canvasScrollFraction: CGFloat = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var didAutoOpenSidebar: Bool = false
    @AppStorage("kairumo_editor_sidebar_tab") private var sidebarTabRaw: String = SidebarTabMode.folders.rawValue

    private var sidebarTab: SidebarTabMode {
        get { SidebarTabMode(rawValue: sidebarTabRaw) ?? .folders }
        nonmutating set { sidebarTabRaw = newValue.rawValue }
    }

    private var sidebarTabBinding: Binding<SidebarTabMode> {
        Binding(
            get: { SidebarTabMode(rawValue: sidebarTabRaw) ?? .folders },
            set: { sidebarTabRaw = $0.rawValue }
        )
    }

    // 資料夾管理狀態
    @State private var showRenameRootFolderAlert: Bool = false
    @State private var rootFolderRenameText: String = ""
    @State private var showNewFolderAlert: Bool = false
    @State private var newFolderNameText: String = ""
    @State private var newFolderParentId: String? = nil
    @State private var folderToRename: FolderItem? = nil
    @State private var folderRenameText: String = ""
    @State private var showMoveNotebookSheet: Bool = false
    @State private var notebookToMoveId: String? = nil
    @State private var expandedFolderIds: Set<String> = []
    /// 目前被拖曳懸停的資料夾（nil 代表「未分類」區）
    @State private var dropTargetFolderId: String? = nil
    @State private var isUnfiledDropTargeted: Bool = false

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

    /// 要求外層改綁到另一則筆記。
    ///
    /// 不能自己 `self.notebook = target` —— `notebook` 是
    /// `$store.notebooks[index]` 的 Binding，寫進去等於把「目前這則筆記」
    /// 在陣列裡的那一格覆蓋成目標筆記：原本那則的紀錄直接消失，
    /// 陣列還會出現兩筆相同 id，畫面隨即整片空白。
    public var onRequestSwitch: ((NotebookDocument) -> Void)?

    public init(
        notebook: Binding<NotebookDocument>,
        onRequestSwitch: ((NotebookDocument) -> Void)? = nil
    ) {
        self._notebook = notebook
        self.onRequestSwitch = onRequestSwitch
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
                        .frame(width: 280)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    ToolbarSeparator()
                }

                // 核心手寫/打字畫布區
                canvasWorkArea
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
        .onChange(of: notebook.id) { _ in
            // 外層換綁之後才會走到這裡，這時 notebook 已經是新的那一則。
            currentPageIndex = 0
            loadCurrentPage()
            PageThumbnailRenderer.invalidateAll()
        }
        .background(
            // 用實際量到的寬度決定要不要展開結構欄。
            // 原本看 horizontalSizeClass，但在 fullScreenCover 剛推上來的那一瞬間
            // 它可能還回報 compact，於是 iPad 上時開時不開。
            GeometryReader { geo in
                Color.clear.onAppear { autoOpenSidebarIfWideEnough(width: geo.size.width) }
            }
        )
        .onAppear {
            loadCurrentPage()
            MacWindowTitle.apply()
        }
        .sheet(isPresented: $showShareSheet) { erasedView {
            if let data = exportPdfData {
                ShareActivityView(data: data, filename: "\(notebook.displayTitle()).pdf")
            }
        } }
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
        .sheet(isPresented: $showMathCalculator) { erasedView {
            MathCalculatorSheet { exprText, cardImage in
                insertImageAttachment(cardImage)
            }
        } }
        .sheet(isPresented: $showChartStudio) { erasedView {
            ChartStudioView { chartImage in
                insertImageAttachment(chartImage)
            }
        } }
        .sheet(isPresented: $showWordStudio) { erasedView {
            WordTextStudioView(attachment: $newTextDraft) { created in
                if notebook.textAttachments == nil {
                    notebook.textAttachments = []
                }
                notebook.textAttachments?.append(created)
                store.updateNotebook(notebook)
            }
        } }
        .sheet(isPresented: Binding(
            get: { editingTextId != nil },
            set: { if !$0 { editingTextId = nil } }
        )) { erasedView {
            if let id = editingTextId {
                WordTextStudioView(attachment: binding(forTextId: id)) { updated in
                    if let idx = notebook.textAttachments?.firstIndex(where: { $0.id == id }) {
                        notebook.textAttachments?[idx] = updated
                        store.updateNotebook(notebook)
                    }
                }
            }
        } }
        .sheet(isPresented: $showLinkPreviewSheet) { erasedView {
            LinkPreviewSheet { linkItem in
                if notebook.linkAttachments == nil {
                    notebook.linkAttachments = []
                }
                notebook.linkAttachments?.append(linkItem)
                store.updateNotebook(notebook)
            }
        } }
        .sheet(isPresented: $showProColorPicker) { erasedView {
            ProColorPickerSheet(selectedColor: $selectedColor)
        } }
        .sheet(isPresented: $show3DStudio) { erasedView {
            Model3DStudioView { new3DAttachment in
                if notebook.model3DAttachments == nil {
                    notebook.model3DAttachments = []
                }
                var att = new3DAttachment
                att.pageIndex = currentPageIndex
                notebook.model3DAttachments?.append(att)
                store.updateNotebook(notebook)
            }
        } }
        .sheet(isPresented: $showAssetLibrarySheet) { erasedView {
            AssetLibraryView { image, _ in
                insertImageAttachment(image)
            }
        } }
        .sheet(isPresented: $showCollaborationSheet) { erasedView {
            CollaborationSheet(notebookId: notebook.id)
        } }
        .onReceive(collaborationManager.oplogReceived) { event in
            handleRemoteOplog(event)
        }
        .sheet(isPresented: $showThemeToolsSheet) { erasedView {
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
        } }
        .alert(localizationManager.localized("rename_note"), isPresented: $showRenameAlert) {
            TextField(localizationManager.localized("note_title"), text: $renameText)
            Button(localizationManager.localized("cancel"), role: .cancel) {}
            Button(localizationManager.localized("confirm")) {
                if !renameText.isEmpty {
                    notebook.title = renameText
                    // 使用者命名後不再跟著語系翻譯（見 NotebookDocument.titleKey）。
                    notebook.titleKey = nil
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
            Text(String(format: localizationManager.localized("delete_page_confirm_msg"), (pageToDeleteIndex ?? 0) + 1))
        }
        .alert(localizationManager.localized("edit_root_folder"), isPresented: $showRenameRootFolderAlert) {
            TextField(localizationManager.localized("root_folder"), text: $rootFolderRenameText)
            Button(localizationManager.localized("cancel"), role: .cancel) {}
            Button(localizationManager.localized("confirm")) {
                store.renameRootFolder(newName: rootFolderRenameText)
            }
        }
        .alert(localizationManager.localized("new_subfolder"), isPresented: $showNewFolderAlert) {
            TextField(localizationManager.localized("folder_name"), text: $newFolderNameText)
            Button(localizationManager.localized("cancel"), role: .cancel) {}
            Button(localizationManager.localized("confirm")) {
                _ = store.createFolder(name: newFolderNameText, parentId: newFolderParentId)
                newFolderNameText = ""
            }
        }
        .alert(localizationManager.localized("rename_folder"), isPresented: Binding(
            get: { folderToRename != nil },
            set: { if !$0 { folderToRename = nil } }
        )) {
            TextField(localizationManager.localized("folder_name"), text: $folderRenameText)
            Button(localizationManager.localized("cancel"), role: .cancel) {
                folderToRename = nil
            }
            Button(localizationManager.localized("confirm")) {
                if let f = folderToRename {
                    store.renameFolder(id: f.id, newName: folderRenameText)
                }
                folderToRename = nil
            }
        }
        .sheet(isPresented: $showMoveNotebookSheet) { erasedView {
            MoveNotebookSheet(notebookId: notebookToMoveId ?? notebook.id)
        } }
    }

    // MARK: - 1. 頂部自訂主工作列（自適應寬窄螢幕模式）
    /// 型別邊界：SwiftUI 會把整棵子樹的型別編進 body 的 mangled 名稱，
    /// 名稱一長，裝置端（主執行緒只有 1MB 堆疊）解析時就會遞迴爆堆疊。
    private var editorTopBar: AnyView { AnyView(editorTopBarContent) }

    private var editorTopBarContent: some View {
        // 寬度夠就用單行完整版；放不下則切到緊湊版，把次要功能收進「更多」選單；
        // 都還塞不下才換行。優先維持單行，主要動作才會固定在同一個位置。
        ViewThatFits(in: .horizontal) {
            expandedEditorTopBar
            HStack(spacing: 6) {
                compactEditorTopBarItems
            }
            // 連緊湊版都放不下時換行。否則「首頁」與「匯出與列印」
            // 會被擠到視窗外，使用者連退出筆記都做不到。
            WrapLayout(spacing: 6, lineSpacing: 6) {
                compactEditorTopBarItems
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    // 寬螢幕完整主工具列
    private var expandedEditorTopBar: some View {
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

            // 版本標示。不要只靠視窗標題列 —— 在 Mac 上跑的 iOS 版（Designed for iPad）
            // 由系統決定標題，App 設什麼都不一定反映得出來。畫在自己的工具列裡最可靠。
            versionBadge

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

            // 手繪與打字模式切換器
            editorModeSwitcher(compact: false)

            // 筆記標題（點擊可修改）
            Button {
                renameText = notebook.displayTitle()
                showRenameAlert = true
            } label: {
                HStack(spacing: 6) {
                    Text(notebook.displayTitle())
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
                    addNewPage()
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
                    .background(isRulerActive ? Color.accentColor.opacity(0.15) : Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(6)
            }
            .help(localizationManager.localized("ruler"))

            // 復原與重做 (Undo / Redo)
            HStack(spacing: 3) {
                Button {
                    performUndo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(5)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(6)
                }
                .help(localizationManager.localized("undo"))

                Button {
                    canvasView?.undoManager?.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(5)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(6)
                }
                .help(localizationManager.localized("redo"))
            }

            // 📦 素材圖庫快捷按鈕（與 iOS 首頁一致）
            Button {
                showAssetLibrarySheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "shippingbox.fill")
                        .foregroundColor(.purple)
                    Text(localizationManager.localized("asset_library"))
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.purple.opacity(0.12))
                .cornerRadius(7)
            }
            .buttonStyle(.plain)
            .help(localizationManager.localized("asset_library"))

            // ➕ 插入物件下拉選單（整合圖片、算式、圖表、3D、主題工具）
            Menu {
                Button {
                    showAssetLibrarySheet = true
                } label: {
                    Label(localizationManager.localized("asset_library"), systemImage: "shippingbox.fill")
                }

                Button {
                    showPhotoPicker = true
                } label: {
                    Label(localizationManager.localized("insert_image"), systemImage: "photo.badge.plus")
                }

                Button {
                    showMathCalculator = true
                } label: {
                    Label(localizationManager.localized("math_calc"), systemImage: "plus.forwardslash.minus")
                }

                Button {
                    showChartStudio = true
                } label: {
                    Label(localizationManager.localized("chart_studio"), systemImage: "chart.bar.xaxis")
                }

                Button {
                    show3DStudio = true
                } label: {
                    Label(localizationManager.localized("insert_3d"), systemImage: "cube.transparent")
                }

                Button {
                    showThemeToolsSheet = true
                } label: {
                    Label(localizationManager.localized("theme_tools"), systemImage: "paintpalette.fill")
                }

                Button {
                    withAnimation {
                        isPlacingCommentPin = true
                    }
                } label: {
                    Label(localizationManager.localized("add_comment_pin"), systemImage: "text.bubble.fill")
                }

                ToolbarSeparator()

                Button {
                    withAnimation {
                        showSketchRefineBar.toggle()
                    }
                } label: {
                    Label(localizationManager.localized("refine_sketch"), systemImage: "wand.and.stars")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.accentColor)
                    Text(localizationManager.localized("insert_object"))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(7)
            }
            .buttonStyle(.plain)
            .help(localizationManager.localized("insert_object"))

            // 💬 畫布討論圖釘快捷按鈕
            Button {
                withAnimation {
                    isPlacingCommentPin.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isPlacingCommentPin ? "pin.circle.fill" : "text.bubble.fill")
                        .foregroundColor(isPlacingCommentPin ? .orange : .accentColor)
                    Text(localizationManager.localized("comment_pin"))
                        .font(.caption2)
                        .fontWeight(.semibold)
                    if let count = notebook.commentPins?.filter({ !$0.isResolved }).count, count > 0 {
                        Text("\(count)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(isPlacingCommentPin ? Color.orange.opacity(0.15) : Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isPlacingCommentPin ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help(localizationManager.localized("comment_pin"))

            // 👥 線上多人即時協同按鈕
            Button {
                showCollaborationSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isCollaborating ? "person.2.wave.2.fill" : "person.2.fill")
                        .foregroundColor(isCollaborating ? .green : .accentColor)
                    Text(localizationManager.localized("collaborate"))
                        .font(.caption2)
                        .fontWeight(.semibold)
                    if isCollaborating {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("\(collaborationManager.peers.count + 1)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(isCollaborating ? Color.green.opacity(0.15) : Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isCollaborating ? Color.green.opacity(0.4) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help(localizationManager.localized("collaborate"))

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
                        _ = await audioManager.startRecording(title: "\(notebook.displayTitle()) \(localizationManager.localized("recording_suffix"))")
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

                ToolbarSeparator()

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
    }

    // 窄螢幕自適應緊湊工具列
    /// 緊湊模式的按鈕們（容器由呼叫端提供）。
    @ViewBuilder
    private var compactEditorTopBarItems: some View {
        // 回到首頁按鈕（緊湊模式）
        Button {
            saveCurrentPageDrawing()
            dismiss()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                Image(systemName: "house.fill")
                    .font(.system(size: 12))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(Color.accentColor)
            .cornerRadius(7)
        }
        .buttonStyle(.plain)
        .help(localizationManager.localized("home"))

        versionBadge

        // 筆記結構側邊欄切換
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                showStructureSidebar.toggle()
            }
        } label: {
            Image(systemName: showStructureSidebar ? "sidebar.left" : "sidebar.leading")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(showStructureSidebar ? .accentColor : .primary)
                .padding(5)
                .background(showStructureSidebar ? Color.accentColor.opacity(0.15) : Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(7)
        }
        .buttonStyle(.plain)

        // 模式切換（緊湊圖標）
        editorModeSwitcher(compact: true)

        // 筆記標題（彈性縮寫）
        Button {
            renameText = notebook.displayTitle()
            showRenameAlert = true
        } label: {
            Text(notebook.displayTitle())
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .buttonStyle(.plain)

        Spacer(minLength: 2)

        // 頁碼切換
        HStack(spacing: 3) {
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

            Text("\(currentPageIndex + 1)/\(max(1, notebook.pageCount))")
                .font(.system(size: 11, weight: .medium))
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

            Button {
                addNewPage()
            } label: {
                Image(systemName: "plus.square.dashed")
                    .foregroundColor(.accentColor)
            }
        }

        // ⋯ 更多（次要功能收在這裡）
        //
        // 緊湊模式下不再把每個功能都攤在工具列上 —— 視窗一窄就會互相擠掉。
        // 主要動作（首頁、模式、頁碼、錄音、匯出）留在列上，其餘收進選單，
        // 位置固定、不會因為視窗寬度而消失。
        Menu {
            Section {
                Button { showAssetLibrarySheet = true } label: { Label(localizationManager.localized("asset_library"), systemImage: "shippingbox.fill") }
                Button { showPhotoPicker = true } label: { Label(localizationManager.localized("insert_image"), systemImage: "photo.badge.plus") }
                Button { showMathCalculator = true } label: { Label(localizationManager.localized("math_calc"), systemImage: "plus.forwardslash.minus") }
                Button { showChartStudio = true } label: { Label(localizationManager.localized("chart_studio"), systemImage: "chart.bar.xaxis") }
                Button { show3DStudio = true } label: { Label(localizationManager.localized("insert_3d"), systemImage: "cube.transparent") }
                Button { showThemeToolsSheet = true } label: { Label(localizationManager.localized("theme_tools"), systemImage: "paintpalette.fill") }
            } header: {
                Text(localizationManager.localized("insert_object"))
            }

            Section {
                Button { withAnimation { showSketchRefineBar.toggle() } } label: { Label(localizationManager.localized("refine_sketch"), systemImage: "wand.and.stars") }
                Button { withAnimation { isPlacingCommentPin.toggle() } } label: { Label(localizationManager.localized("add_comment_pin"), systemImage: "text.bubble.fill") }
                Button { showCollaborationSheet = true } label: { Label(localizationManager.localized("collaborate"), systemImage: "person.2.fill") }
            }
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.caption)
                .foregroundColor(.accentColor)
                .padding(5)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(localizationManager.localized("more_tools"))

        // 錄音
        if audioManager.status == .recording {
            Button {
                stopAndSaveRecording()
            } label: {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .padding(5)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(6)
            }
        } else {
            Button {
                Task {
                    _ = await audioManager.startRecording(title: "\(notebook.displayTitle()) \(localizationManager.localized("recording_suffix"))")
                }
            } label: {
                Image(systemName: "mic.fill")
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(5)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(6)
            }
        }

        // 匯出功能選單
        Menu {
            Button { exportAsPdf() } label: { Label(localizationManager.localized("export_pdf"), systemImage: "doc.text.fill") }
            Button { exportAsPngImage() } label: { Label(localizationManager.localized("export_image"), systemImage: "photo") }
            Button { printCurrentNotebook() } label: { Label(localizationManager.localized("print_note"), systemImage: "printer.fill") }
            Divider()
            Button { shareNotebookFile() } label: { Label(localizationManager.localized("share_note"), systemImage: "square.and.arrow.up") }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(5)
                .background(Color.accentColor)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    /// 寬度足夠時自動展開結構欄（只做一次，之後尊重使用者自己的開關）。
    /// iPhone 這種窄寬度維持收合 —— 280pt 的側欄會把畫布擠到不能用。
    private func autoOpenSidebarIfWideEnough(width: CGFloat) {
        guard !didAutoOpenSidebar else { return }
        didAutoOpenSidebar = true
        if width >= 700 {
            showStructureSidebar = true
        }
    }

    /// 畫布內容寬度與 `CanvasRepresentable` 的 `max(bounds.width, 800)` 保持一致。
    private func updateCanvasContentWidth(_ viewWidth: CGFloat) {
        // 與 AdaptiveCanvasView 一致：畫布內容寬度就是視圖寬度
        let width = max(viewWidth, 320)
        guard abs(width - canvasContentWidth) > 0.5 else { return }
        canvasContentWidth = width
    }

    /// 畫布工作區。抽出來並加上 AnyView 邊界 —— 這一塊（畫布 + 附件圖層 +
    /// 圖釘 + 浮動列）原本整棵樹的型別都被編進 body 的 mangled 名稱裡。
    private var canvasWorkArea: AnyView { AnyView(canvasWorkAreaContent) }

    private var canvasWorkAreaContent: some View {
ZStack(alignment: .topTrailing) {
            CanvasRepresentable(
                drawing: $currentDrawing,
                selectedTool: selectedTool,
                selectedColor: selectedColor,
                strokeWidth: strokeWidth,
                isRulerActive: isRulerActive,
                template: notebook.template,
                pageHeight: currentPageHeight,
                editorMode: editorMode,
                onDrawingChanged: { newDrawing in
                    // 即時自動儲存至專屬二進位檔案（不觸發 Struct 重新賦值以防競態覆蓋）
                    store.saveDrawing(notebookId: notebook.id, pageIndex: currentPageIndex, drawing: newDrawing)

                    if !isApplyingRemoteUpdate && isCollaborating {
                        let count = newDrawing.strokes.count
                        if count > lastStrokeCount {
                            let deltaStrokes = Array(newDrawing.strokes.suffix(count - lastStrokeCount))
                            let deltaDrawing = PKDrawing(strokes: deltaStrokes)
                            let b64 = deltaDrawing.dataRepresentation().base64EncodedString()
                            collaborationManager.broadcastOplog(
                                kind: "stroke_delta",
                                payload: [
                                    "page_index": currentPageIndex,
                                    "drawing_base64": b64
                                ]
                            )
                        } else if count < lastStrokeCount {
                            let b64 = newDrawing.dataRepresentation().base64EncodedString()
                            collaborationManager.broadcastOplog(
                                kind: "drawing_replace",
                                payload: [
                                    "page_index": currentPageIndex,
                                    "drawing_base64": b64
                                ]
                            )
                        }
                        lastStrokeCount = count
                    } else if !isApplyingRemoteUpdate {
                        lastStrokeCount = newDrawing.strokes.count
                    }
                },
                onReachedPageBottom: {
                    ensureNextPageExists()
                },
                onSelectionChanged: { hasSel in
                    self.hasLassoSelection = hasSel
                },
                canvasRef: { ref in
                    self.canvasView = ref
                },
                onScrollMetrics: { visible, fraction in
                    canvasVisibleFraction = visible
                    canvasScrollFraction = fraction
                }
            )
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { updateCanvasContentWidth(geo.size.width) }
                        .onChange(of: geo.size.width) { newWidth in
                            updateCanvasContentWidth(newWidth)
                        }
                }
            )

            // 🌟 打字模式畫布互動層：點選空白處新增文字方塊並直接彈出鍵盤
            if editorMode == .type {
                GeometryReader { geo in
                    Color.black.opacity(0.001)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            let newDraft = NoteTextAttachment(
                                id: UUID().uuidString,
                                pageIndex: currentPageIndex,
                                text: "",
                                x: max(20, location.x - 130),
                                y: max(20, location.y - 40)
                            )
                            if notebook.textAttachments == nil {
                                notebook.textAttachments = []
                            }
                            notebook.textAttachments?.append(newDraft)
                            store.updateNotebook(notebook)
                            self.editingTextId = newDraft.id
                        }
                }

                // 打字模式頂部提示條
                HStack(spacing: 6) {
                    Image(systemName: "keyboard.fill")
                        .foregroundColor(.accentColor)
                    Text(localizationManager.localized("tap_to_type_hint"))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.12), radius: 5, y: 2)
                .padding(.top, 14)
                .padding(.trailing, 20)
            }

            // 🌟 筆記內嵌圖片與圖表展示層（支援等比縮放、拖曳平移與濾鏡美化）
            ForEach(notebook.attachments ?? []) { item in
                if item.pageIndex == currentPageIndex {
                    AttachmentItemView(
                        attachment: binding(for: item.id),
                        onEdit: {
                            self.editingAttachmentId = item.id
                        },
                        onDelete: {
                            deletedAttachmentBackup = (type: "image", data: item)
                            collaborationManager.broadcastAttachmentDelete(id: item.id, type: "image")
                            notebook.attachments?.removeAll { $0.id == item.id }
                            store.updateNotebook(notebook)
                            collaborationManager.broadcastSelection(selectedId: nil)
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
                            deletedAttachmentBackup = (type: "text", data: item)
                            collaborationManager.broadcastAttachmentDelete(id: item.id, type: "text")
                            notebook.textAttachments?.removeAll { $0.id == item.id }
                            store.updateNotebook(notebook)
                            collaborationManager.broadcastSelection(selectedId: nil)
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
                            deletedAttachmentBackup = (type: "3d", data: item)
                            collaborationManager.broadcastAttachmentDelete(id: item.id, type: "3d")
                            notebook.model3DAttachments?.removeAll { $0.id == item.id }
                            store.updateNotebook(notebook)
                            collaborationManager.broadcastSelection(selectedId: nil)
                        }
                    )
                }
            }

            // 🌟 筆記內嵌討論圖釘展示層（支援多方訊息留言串、已解決標記與即時推播）
            ForEach(notebook.commentPins ?? []) { pin in
                if pin.pageIndex == currentPageIndex {
                    CommentPinMarkerView(
                        pin: pin,
                        isSelected: selectedCommentPinId == pin.id,
                        onTap: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                if selectedCommentPinId == pin.id {
                                    selectedCommentPinId = nil
                                    collaborationManager.broadcastSelection(selectedId: nil)
                                } else {
                                    selectedCommentPinId = pin.id
                                    collaborationManager.broadcastSelection(selectedId: pin.id)
                                }
                            }
                        }
                    )
                    .position(x: pin.x, y: pin.y)
                }
            }

            // 展開的討論圖釘詳細對話框
            if let pinId = selectedCommentPinId,
               let pin = (notebook.commentPins ?? []).first(where: { $0.id == pinId }),
               pin.pageIndex == currentPageIndex {
                CommentThreadDialog(
                    pin: pin,
                    currentUserId: collaborationManager.currentUserId,
                    currentUserName: AccountManager.shared.profile.displayName,
                    currentUserColor: collaborationManager.myColorHex,
                    onReply: { pId, text in
                        addCommentReply(pinId: pId, text: text)
                    },
                    onToggleResolve: { pId in
                        toggleCommentResolve(pinId: pId)
                    },
                    onDelete: { pId in
                        deleteCommentPin(pinId: pId)
                    },
                    onDeleteMessage: { pId, mId in
                        deleteCommentMessage(pinId: pId, messageId: mId)
                    },
                    onClose: {
                        withAnimation {
                            selectedCommentPinId = nil
                            collaborationManager.broadcastSelection(selectedId: nil)
                        }
                    }
                )
                .position(
                    x: min(max(170, pin.x), 650),
                    y: min(max(150, pin.y - 120), currentPageHeight - 120)
                )
            }

            // 放置討論圖釘模式互動層
            if isPlacingCommentPin {
                GeometryReader { geo in
                    Color.blue.opacity(0.001)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            let newPin = NoteCommentPin(
                                pageIndex: currentPageIndex,
                                x: location.x,
                                y: location.y,
                                authorId: collaborationManager.currentUserId,
                                authorName: AccountManager.shared.profile.displayName,
                                authorColor: collaborationManager.myColorHex,
                                messages: [
                                    NoteCommentMessage(
                                        authorId: collaborationManager.currentUserId,
                                        authorName: AccountManager.shared.profile.displayName,
                                        authorColor: collaborationManager.myColorHex,
                                        text: localizationManager.localized("add_comment_pin")
                                    )
                                ]
                            )
                            if notebook.commentPins == nil {
                                notebook.commentPins = []
                            }
                            notebook.commentPins?.append(newPin)
                            store.updateNotebook(notebook)
                            selectedCommentPinId = newPin.id
                            isPlacingCommentPin = false
                            broadcastCommentPinUpsert(newPin)
                            collaborationManager.broadcastSelection(selectedId: newPin.id)
                        }
                }

                // 放置圖釘模式頂部提示條
                HStack(spacing: 8) {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.orange)
                    Text(localizationManager.localized("tap_to_place_pin"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Button(action: { isPlacingCommentPin = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.12), radius: 5, y: 2)
                .padding(.top, 14)
                .padding(.leading, 20)
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

                    // ＋ 新增下一頁
                    Button {
                        addNewPage()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.square.dashed")
                                .font(.subheadline)
                            Text(localizationManager.localized("add_next_page"))
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial)
                        .cornerRadius(18)
                        .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                    .help(localizationManager.localized("add_next_page"))

                    // 「延長本頁」已移除：頁面高度固定（PageGeometry），
                    // 寫到頁尾會自動準備下一頁。
                }
                .padding(14)
            }

            // 🌟 線上多人即時彩色游標與筆尖浮層
            RemoteCursorsOverlay()

            // 🌟 圖片美化浮動面板
            //
            // 以前是 modal sheet，蓋住整個畫布 —— 調濾鏡時看不到自己在調
            // 什麼。改成浮在畫布上、標題列可拖到一旁的面板：控制項與圖片
            // 同時在畫面上，改動直接反映在物件上。
            if let id = editingAttachmentId {
                FloatingPanel(
                    title: localizationManager.localized("image_beautify"),
                    onClose: { editingAttachmentId = nil }
                ) {
                    ImageEditControls(attachment: binding(for: id)) {
                        notebook.attachments?.removeAll { $0.id == id }
                        store.updateNotebook(notebook)
                        editingAttachmentId = nil
                    }
                }
                .padding(.top, 24)
                .padding(.trailing, 24)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .overlay(alignment: .trailing) {
            // 可用游標拖曳的捲軸（iOS 原生指示器不接受互動）
            CanvasScrollbar(
                visibleFraction: canvasVisibleFraction,
                scrollFraction: canvasScrollFraction
            ) { fraction in
                guard let canvas = canvasView else { return }
                let scrollable = max(canvas.contentSize.height - canvas.bounds.height, 0)
                canvas.setContentOffset(CGPoint(x: canvas.contentOffset.x, y: scrollable * fraction), animated: false)
                canvasScrollFraction = fraction
            }
            .padding(.trailing, 4)
            .padding(.vertical, 10)
        }
        .coordinateSpace(name: CanvasCoordinateSpace.name)
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                collaborationManager.broadcastCursor(
                    x: location.x,
                    y: location.y,
                    isDrawing: false,
                    tool: selectedTool.rawValue
                )
            case .ended:
                break
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    /// 套索操作按鈕：圖示 + 文字 + 說明提示
    private func lassoActionButton(_ icon: String, _ titleKey: String, _ hintKey: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(localizationManager.localized(titleKey))
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(localizationManager.localized(hintKey))
    }

    /// 版本標示（v2.2.0 這種）。點一下可複製，回報問題時直接貼上。
    private var versionBadge: some View {
        Text("v\(AppVersion.marketing)")
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(5)
            .help("Kairumo v\(AppVersion.marketing) (build \(AppVersion.build))")
            .onTapGesture {
                #if canImport(UIKit)
                UIPasteboard.general.string = "Kairumo v\(AppVersion.marketing) (build \(AppVersion.build))"
                #endif
            }
    }

    // MARK: - 手繪／打字模式切換器
    //
    // 原本用 `.pickerStyle(.segmented)`，但每個選項裡放的是 `HStack { Image; Text }`：
    // UIKit 的分段控制項只吃單一 Text 或單一 Image，HStack 會被拆平成好幾段，
    // `.tag()` 跟著失效 —— 畫面上看得到「打字」，點下去卻永遠切不過去。
    // 改成兩顆自己畫的按鈕，狀態由 editorMode 直接驅動，行為確定。
    private func editorModeSwitcher(compact: Bool) -> some View {
        HStack(spacing: 2) {
            editorModeButton(mode: .draw, icon: "pencil.tip", titleKey: "handwriting_mode", compact: compact)
            editorModeButton(mode: .type, icon: "keyboard", titleKey: "typing_mode", compact: compact)
        }
        .padding(2)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .cornerRadius(compact ? 7 : 9)
    }

    private func editorModeButton(mode: EditorMode, icon: String, titleKey: String, compact: Bool) -> some View {
        let isActive = (editorMode == mode)
        return Button {
            guard editorMode != mode else { return }
            // 切到打字模式前先把目前筆劃落盤，否則切換時的畫布重建會吃掉未存的筆跡
            saveCurrentPageDrawing()
            withAnimation(.easeInOut(duration: 0.18)) {
                editorMode = mode
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: compact ? 12 : 13, weight: .semibold))
                if !compact {
                    Text(localizationManager.localized(titleKey))
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .foregroundColor(isActive ? .accentColor : .secondary)
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.vertical, compact ? 4 : 6)
            .background(
                RoundedRectangle(cornerRadius: compact ? 5 : 7)
                    .fill(isActive ? Color(uiColor: .systemBackground) : Color.clear)
                    .shadow(color: Color.black.opacity(isActive ? 0.12 : 0), radius: 2, y: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(localizationManager.localized(titleKey))
    }

    /// 型別邊界：SwiftUI 會把整棵子樹的型別編進 body 的 mangled 名稱，
    /// 名稱一長，裝置端（主執行緒只有 1MB 堆疊）解析時就會遞迴爆堆疊。
    private var notebookStructureSidebar: AnyView { AnyView(notebookStructureSidebarContent) }

    private var notebookStructureSidebarContent: some View {
        VStack(spacing: 0) {
            // 頂部導覽列與分頁模式切換
            VStack(spacing: 8) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: sidebarTab == .pages ? "sidebar.left" : "folder.fill")
                            .foregroundColor(.accentColor)
                        Text(sidebarTab == .pages ? localizationManager.localized("structure_pages") : localizationManager.localized("structure_folders"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    Spacer()

                    if sidebarTab == .pages {
                        Button {
                            addNewPage()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.accentColor)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(localizationManager.localized("add_page"))
                    } else {
                        Button {
                            newFolderParentId = nil
                            newFolderNameText = ""
                            showNewFolderAlert = true
                        } label: {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 16))
                                .foregroundColor(.accentColor)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(localizationManager.localized("new_subfolder"))
                    }

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

                Picker("", selection: sidebarTabBinding) {
                    Text(localizationManager.localized("structure_pages")).tag(SidebarTabMode.pages)
                    Text(localizationManager.localized("structure_folders")).tag(SidebarTabMode.folders)
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(uiColor: .secondarySystemGroupedBackground))

            Divider()

            if sidebarTab == .pages {
                pagesStructureView
            } else {
                foldersStructureView
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    // MARK: - 頁面結構縮圖清單
    /// 型別邊界：SwiftUI 會把整棵子樹的型別編進 body 的 mangled 名稱，
    /// 名稱一長，裝置端（主執行緒只有 1MB 堆疊）解析時就會遞迴爆堆疊。
    private var pagesStructureView: AnyView { AnyView(pagesStructureViewContent) }

    private var pagesStructureViewContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(Array(0..<max(1, notebook.pageCount)), id: \.self) { idx in
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
                                        insertPageAfter(idx)
                                    } label: {
                                        Label(localizationManager.localized("insert_page_after"), systemImage: "plus.square")
                                    }

                                    Button {
                                        duplicatePage(at: idx)
                                    } label: {
                                        Label(localizationManager.localized("duplicate_page"), systemImage: "plus.square.on.square")
                                    }

                                    if notebook.pageCount > 1 {
                                        ToolbarSeparator()
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
                                // 縮圖用畫布的實際寬度算繪，並讓卡片維持同樣的長寬比 ——
                                // 舊版固定 800 寬、卡片固定 130 高，一張 800x1800 的頁面
                                // scaledToFit 之後只剩 50pt 寬，物件小到看不出是什麼。
                                let pageDrawing = (idx == currentPageIndex) ? currentDrawing : store.loadDrawing(notebookId: notebook.id, pageIndex: idx)
                                let img = PageThumbnailRenderer.render(
                                    notebook: notebook,
                                    pageIndex: idx,
                                    drawing: pageDrawing,
                                    store: store,
                                    canvasWidth: canvasContentWidth
                                )
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(img.size.width / max(img.size.height, 1), contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2.5 : 1)
                                    )
                                    .shadow(color: Color.black.opacity(isSelected ? 0.15 : 0.04), radius: isSelected ? 4 : 2, y: 1)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
                        .cornerRadius(8)
                    }

                    // 🌟 顯著的新增頁面大按鈕卡片
                    Button {
                        addNewPage()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                            Text(localizationManager.localized("add_page_large"))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor.opacity(0.08))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.accentColor.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                }
                .id(notebook.pageCount)
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
                    Text("\(localizationManager.localized("txt_count")): \(txtCount)  \(localizationManager.localized("img_count")): \(imgCount)  \(localizationManager.localized("model3d_count")): \(modelCount)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
        }
    }

    // MARK: - 資料夾階層結構目錄
    /// 型別邊界：SwiftUI 會把整棵子樹的型別編進 body 的 mangled 名稱，
    /// 名稱一長，裝置端（主執行緒只有 1MB 堆疊）解析時就會遞迴爆堆疊。
    private var foldersStructureView: AnyView { AnyView(foldersStructureViewContent) }

    private var foldersStructureViewContent: some View {
        VStack(spacing: 0) {
            // 最上層根資料夾標題（可自訂與重命名）
            HStack(spacing: 8) {
                Image(systemName: "tray.2.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.displayRootFolderName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(localizationManager.localized("root_folder"))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    rootFolderRenameText = store.displayRootFolderName
                    showRenameRootFolderAlert = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 17))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized("edit_root_folder"))
            }
            .padding(8)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(8)
            .padding(.horizontal, 10)
            .padding(.top, 8)

            // 新增子資料夾按鈕
            Button {
                newFolderParentId = nil
                newFolderNameText = ""
                showNewFolderAlert = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder.badge.plus")
                        .font(.caption)
                    Text(localizationManager.localized("new_subfolder"))
                        .font(.caption)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.accentColor.opacity(0.1))
                .foregroundColor(.accentColor)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    // 最上層子資料夾
                    ForEach(store.folders.filter { $0.parentId == nil }) { folder in
                        folderRowView(folder: folder, level: 0)
                    }

                    // 最上層未分類筆記
                    let rootNotes = store.notebooks.filter { $0.folderId == nil }
                    if !rootNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Image(systemName: "tray.fill")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(localizationManager.localized("unfiled_notes"))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(rootNotes.count)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, 10)
                            .padding(.top, 8)
                            .padding(.vertical, 4)
                            .background(isUnfiledDropTargeted ? Color.accentColor.opacity(0.18) : Color.clear)
                            .cornerRadius(6)
                            // 把筆記拖回這裡，就會移出資料夾
                            .dropDestination(for: String.self) { items, _ in
                                guard let noteId = items.first else { return false }
                                store.moveNotebook(id: noteId, toFolderId: nil)
                                return true
                            } isTargeted: { isUnfiledDropTargeted = $0 }

                            ForEach(rootNotes) { note in
                                notebookItemRow(note: note, indent: 8)
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }

            Divider()

            // 目錄統計
            HStack {
                Text("\(localizationManager.localized("structure_folders")): \(store.folders.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(localizationManager.localized("all_folders")): \(store.notebooks.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
        }
    }

    // 單一資料夾列視圖（支援遞迴子資料夾與展開）
    private func folderRowView(folder: FolderItem, level: Int) -> AnyView {
        let isExpanded = expandedFolderIds.contains(folder.id)
        let subfolders = store.subfolders(of: folder.id)
        let folderNotes = store.notebooks(in: folder.id)

        return AnyView(
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    // 展開箭頭
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isExpanded {
                                expandedFolderIds.remove(folder.id)
                            } else {
                                expandedFolderIds.insert(folder.id)
                            }
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)

                    // 資料夾圖示與名稱
                    Image(systemName: isExpanded ? "folder.fill" : "folder")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 13))

                    Text(folder.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Spacer()

                    // 筆記件數徽章
                    Text("\(folderNotes.count)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .clipShape(Capsule())

                    // 功能選單
                    Menu {
                        Button {
                            newFolderParentId = folder.id
                            newFolderNameText = ""
                            showNewFolderAlert = true
                        } label: {
                            Label(localizationManager.localized("new_subfolder"), systemImage: "folder.badge.plus")
                        }

                        Button {
                            let created = store.createNotebook(
                                title: localizationManager.localized("new_notebook"),
                                template: notebook.template,
                                folderId: folder.id
                            )
                            switchToNotebook(created)
                        } label: {
                            Label(localizationManager.localized("add_note_to_folder"), systemImage: "plus.square")
                        }

                        Button {
                            folderToRename = folder
                            folderRenameText = folder.name
                        } label: {
                            Label(localizationManager.localized("rename_folder"), systemImage: "pencil")
                        }

                        ToolbarSeparator()

                        Button(role: .destructive) {
                            store.deleteFolder(id: folder.id)
                        } label: {
                            Label(localizationManager.localized("delete_folder"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, CGFloat(level * 14 + 6))
                .padding(.trailing, 8)
                .padding(.vertical, 4)
                .background(
                    (dropTargetFolderId == folder.id ? Color.accentColor.opacity(0.22)
                                                     : Color(uiColor: .tertiarySystemGroupedBackground).opacity(0.5))
                )
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor, lineWidth: dropTargetFolderId == folder.id ? 2 : 0)
                )
                // 把筆記拖到資料夾上即完成分類
                .dropDestination(for: String.self) { items, _ in
                    guard let noteId = items.first else { return false }
                    store.moveNotebook(id: noteId, toFolderId: folder.id)
                    expandedFolderIds.insert(folder.id)
                    return true
                } isTargeted: { hovering in
                    dropTargetFolderId = hovering ? folder.id : (dropTargetFolderId == folder.id ? nil : dropTargetFolderId)
                }

                // 若展開，渲染子資料夾與內部筆記檔案
                if isExpanded {
                    // 子資料夾
                    ForEach(subfolders) { sub in
                        folderRowView(folder: sub, level: level + 1)
                    }

                    // 該資料夾所屬筆記檔案
                    ForEach(folderNotes) { note in
                        notebookItemRow(note: note, indent: CGFloat((level + 1) * 14 + 6))
                    }
                }
            }
            .padding(.horizontal, 6)
        )
    }

    // 單一筆記檔案列視圖（支援快速點選切換編輯）
    @ViewBuilder
    private func notebookItemRow(note: NotebookDocument, indent: CGFloat) -> some View {
        let isCurrent = (note.id == notebook.id)
        HStack(spacing: 6) {
            Image(systemName: isCurrent ? "doc.fill" : "doc.plaintext")
                .foregroundColor(isCurrent ? .accentColor : .secondary)
                .font(.system(size: 12))

            VStack(alignment: .leading, spacing: 1) {
                Text(note.displayTitle())
                    .font(.caption)
                    .fontWeight(isCurrent ? .bold : .regular)
                    .foregroundColor(isCurrent ? .accentColor : .primary)
                    .lineLimit(1)
                Text("\(note.pageCount) \(localizationManager.localized("pages_count_suffix"))")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isCurrent {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
            }

            Menu {
                Button {
                    notebookToMoveId = note.id
                    showMoveNotebookSheet = true
                } label: {
                    Label(localizationManager.localized("move_to_folder"), systemImage: "folder")
                }

                Button {
                    renameText = note.title
                    showRenameAlert = true
                } label: {
                    Label(localizationManager.localized("rename_note"), systemImage: "pencil")
                }

                ToolbarSeparator()

                Button(role: .destructive) {
                    store.deleteNotebook(id: note.id)
                    if note.id == notebook.id {
                        if let first = store.notebooks.first {
                            switchToNotebook(first)
                        } else {
                            let created = store.createNotebook(title: localizationManager.localized("untitled_note"), template: .blank)
                            switchToNotebook(created)
                        }
                    }
                } label: {
                    Label(localizationManager.localized("delete"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(3)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, indent)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .background(isCurrent ? Color.accentColor.opacity(0.12) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture {
            switchToNotebook(note)
        }
        // 拖到資料夾列上即可分類；拖到「未分類檔案」標題可移出資料夾
        .draggable(note.id) {
            HStack(spacing: 6) {
                Image(systemName: "doc.fill")
                Text(note.displayTitle()).lineLimit(1)
            }
            .font(.caption)
            .padding(8)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(8)
        }
    }

    // MARK: - 2. 🌟 實體手繪工具列（水平滑動包裹、免擠壓、隨點隨用）
    /// 型別邊界：SwiftUI 會把整棵子樹的型別編進 body 的 mangled 名稱，
    /// 名稱一長，裝置端（主執行緒只有 1MB 堆疊）解析時就會遞迴爆堆疊。
    private var drawingToolbar: AnyView { AnyView(drawingToolbarContent) }

    private var drawingToolbarContent: some View {
        // 放不下時分三步退讓：先收掉筆刷底下的文字標籤，
        // 再不夠就由「更多」選單承接次要工具，最後才換行 ——
        // 換行會改變按鈕位置，所以放在最後，不是第一選擇。
        ViewThatFits(in: .horizontal) {
            drawingToolbarRow(showToolLabels: true)
            drawingToolbarRow(showToolLabels: false)
            // 兩種單行版本都塞不下時的保底：自動換行。
            // 沒有這一層，ViewThatFits 會直接採用最後一個候選，
            // 工具列就會比視窗寬、左右兩端被裁掉。
            WrapLayout(spacing: 12, lineSpacing: 8) {
                drawingToolbarItems(showToolLabels: false)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
    }

    private func drawingToolbarRow(showToolLabels: Bool) -> some View {
        HStack(spacing: 14) {
            drawingToolbarItems(showToolLabels: showToolLabels)
        }
    }

    /// 工具列的內容。攤平成一連串子視圖，`HStack` 與 `WrapLayout` 共用同一份 ——
    /// 換行版才不會因為內容被包在容器裡而永遠不換行。
    @ViewBuilder
    private func drawingToolbarItems(showToolLabels: Bool) -> some View {
                // 工具選擇群組（鋼筆、原子筆、毛筆、麥克筆、螢光筆、鉛筆、水彩筆、橡皮擦、套索）
                ForEach(EditorToolType.allCases) { tool in
                    Button {
                        selectedTool = tool
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tool.iconName)
                                .font(.system(size: 16, weight: selectedTool == tool ? .bold : .regular))
                            if showToolLabels {
                                Text(localizationManager.localized(tool.localizationKey))
                                    .font(.system(size: 10))
                            }
                        }
                        .foregroundColor(selectedTool == tool ? .accentColor : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(selectedTool == tool ? Color.accentColor.opacity(0.15) : Color.clear)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                ToolbarSeparator()
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

                ToolbarSeparator()
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
                    ToolbarSeparator()
                        .frame(height: 24)

                    HStack(spacing: 6) {
                        // 圖示配文字：純圖示看不出是「對選取的筆劃」做事
                        lassoActionButton("scissors", "cut_selected", "cut_selected_hint") { cutSelectedStrokes() }
                        lassoActionButton("doc.on.doc", "copy_selected", "copy_selected_hint") { copySelectedStrokes() }
                        lassoActionButton("plus.square.on.square", "duplicate_selected", "duplicate_selected_hint") { duplicateSelectedStrokes() }
                        lassoActionButton("doc.on.clipboard", "paste_strokes", "paste_strokes_hint") { pasteStrokes() }

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

                ToolbarSeparator()
                    .frame(height: 24)

                // ⋯ 更多：次要工具收在這裡
                //
                // 這些插入類工具原本全部攤在列上，視窗一窄就被擠出畫面外。
                // 收進選單後位置固定，不會因為視窗寬度而消失。
                Menu {
                    Button { showPhotoPicker = true } label: { Label(localizationManager.localized("insert_image"), systemImage: "photo.badge.plus") }
                    Button { showMathCalculator = true } label: { Label(localizationManager.localized("math_calc"), systemImage: "plus.forwardslash.minus") }
                    Button { showChartStudio = true } label: { Label(localizationManager.localized("chart_studio"), systemImage: "chart.bar.xaxis") }
                    Button { show3DStudio = true } label: { Label(localizationManager.localized("insert_3d"), systemImage: "cube.transparent") }
                    Button { showAssetLibrarySheet = true } label: { Label(localizationManager.localized("asset_library"), systemImage: "shippingbox.fill") }
                    Divider()
                    Button { withAnimation { showSketchRefineBar.toggle() } } label: { Label(localizationManager.localized("refine_sketch"), systemImage: "wand.and.stars") }
                    Button { showThemeToolsSheet = true } label: { Label(localizationManager.localized("theme_tools"), systemImage: "paintpalette.fill") }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 15, weight: .semibold))
                        Text(localizationManager.localized("more_tools"))
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.10))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized("more_tools"))

                ToolbarSeparator()
                    .frame(height: 24)

                // 復原與重做
                HStack(spacing: 8) {
                    Button {
                        performUndo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .help(localizationManager.localized("undo"))

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

    // MARK: - 🌟 實體鍵盤打字與排版工具列
    /// 型別邊界：SwiftUI 會把整棵子樹的型別編進 body 的 mangled 名稱，
    /// 名稱一長，裝置端（主執行緒只有 1MB 堆疊）解析時就會遞迴爆堆疊。
    private var typingToolbar: AnyView { AnyView(typingToolbarContent) }

    private var typingToolbarContent: some View {
        // 次要的插入工具收進「更多」選單；真的還是塞不下時才換行。
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                typingToolbarItems
            }
            WrapLayout(spacing: 12, lineSpacing: 8) {
                typingToolbarItems
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
    }

    @ViewBuilder
    private var typingToolbarItems: some View {
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

                // ⋯ 更多：次要插入工具
                Menu {
                    Button { showPhotoPicker = true } label: { Label(localizationManager.localized("insert_image"), systemImage: "photo.badge.plus") }
                    Button { showMathCalculator = true } label: { Label(localizationManager.localized("math_calc"), systemImage: "plus.forwardslash.minus") }
                    Button { showChartStudio = true } label: { Label(localizationManager.localized("chart_studio"), systemImage: "chart.bar.xaxis") }
                    Button { show3DStudio = true } label: { Label(localizationManager.localized("insert_3d"), systemImage: "cube.transparent") }
                    Button { showAssetLibrarySheet = true } label: { Label(localizationManager.localized("asset_library"), systemImage: "shippingbox.fill") }
                    Divider()
                    Button { showThemeToolsSheet = true } label: { Label(localizationManager.localized("theme_tools"), systemImage: "paintpalette.fill") }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 15, weight: .semibold))
                        Text(localizationManager.localized("more_tools"))
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.10))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized("more_tools"))

                // 「延長本頁」已移除：頁面高度固定（PageGeometry），
                // 寫到頁尾會自動準備下一頁。

                Spacer()

                // 復原與重做
                HStack(spacing: 8) {
                    Button {
                        performUndo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .help(localizationManager.localized("undo"))

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

    // MARK: - 3. 尺規旋轉與量測輔助列
    /// 型別邊界：SwiftUI 會把整棵子樹的型別編進 body 的 mangled 名稱，
    /// 名稱一長，裝置端（主執行緒只有 1MB 堆疊）解析時就會遞迴爆堆疊。
    private var rulerControlBar: AnyView { AnyView(rulerControlBarContent) }

    private var rulerControlBarContent: some View {
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
    private func audioPlaybackBar(fileName: String) -> AnyView { AnyView(audioPlaybackBarContent(fileName: fileName)) }

    private func audioPlaybackBarContent(fileName: String) -> some View {
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
    /// 型別邊界：SwiftUI 會把整棵子樹的型別編進 body 的 mangled 名稱，
    /// 名稱一長，裝置端（主執行緒只有 1MB 堆疊）解析時就會遞迴爆堆疊。
    private var liveRecordingBar: AnyView { AnyView(liveRecordingBarContent) }

    private var liveRecordingBarContent: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                Text("\(localizationManager.localized("sync_recording_in_progress")): \(formatTime(seconds: audioManager.elapsedSeconds))")
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
    private func floatingAudioBadge(fileName: String) -> AnyView { AnyView(floatingAudioBadgeContent(fileName: fileName)) }

    private func floatingAudioBadgeContent(fileName: String) -> some View {
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
    /// 型別邊界：SwiftUI 會把整棵子樹的型別編進 body 的 mangled 名稱，
    /// 名稱一長，裝置端（主執行緒只有 1MB 堆疊）解析時就會遞迴爆堆疊。
    private var lassoFloatingActionBar: AnyView { AnyView(lassoFloatingActionBarContent) }

    private var lassoFloatingActionBarContent: some View {
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
            .help(localizationManager.localized("copy_selected_hint"))

            Button {
                duplicateSelectedStrokes()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.square.on.square")
                    Text(localizationManager.localized("duplicate_selected"))
                }
                .font(.caption2)
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help(localizationManager.localized("duplicate_selected_hint"))

            Button {
                pasteStrokes()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.clipboard")
                    Text(localizationManager.localized("paste_strokes"))
                }
                .font(.caption2)
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help(localizationManager.localized("paste_strokes_hint"))

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
    /// 型別邊界：SwiftUI 會把整棵子樹的型別編進 body 的 mangled 名稱，
    /// 名稱一長，裝置端（主執行緒只有 1MB 堆疊）解析時就會遞迴爆堆疊。
    private var sketchRefineFloatingBar: AnyView { AnyView(sketchRefineFloatingBarContent) }

    private var sketchRefineFloatingBarContent: some View {
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
        if let updated = store.notebooks.first(where: { $0.id == notebook.id }) {
            self.notebook = updated
        }
        let loaded = store.loadDrawing(notebookId: notebook.id, pageIndex: currentPageIndex)
        self.currentDrawing = loaded
        self.lastStrokeCount = loaded.strokes.count
        self.currentPageHeight = notebook.height(forPage: currentPageIndex, defaultHeight: 1800)
        self.hasLassoSelection = false
        self.originalSketchBackup = nil
        self.refinedSketchCache = nil
    }

    /// 處理協同遠端廣播操作（CRDT Oplog 合併）
    private func handleRemoteOplog(_ event: RemoteOplogEvent) {
        switch event.kind {
        case "stroke_delta":
            guard let pageIdx = event.payload["page_index"] as? Int,
                  let b64 = event.payload["drawing_base64"] as? String,
                  let data = Data(base64Encoded: b64),
                  let remoteDrawing = try? PKDrawing(data: data) else { return }

            if pageIdx == currentPageIndex {
                if let canvas = canvasView {
                    isApplyingRemoteUpdate = true
                    let merged = canvas.drawing.appending(remoteDrawing)
                    canvas.drawing = merged
                    currentDrawing = merged
                    lastStrokeCount = merged.strokes.count
                    store.saveDrawing(notebookId: notebook.id, pageIndex: currentPageIndex, drawing: merged)
                    DispatchQueue.main.async {
                        isApplyingRemoteUpdate = false
                    }
                }
            } else {
                let existing = store.loadDrawing(notebookId: notebook.id, pageIndex: pageIdx)
                let merged = existing.appending(remoteDrawing)
                store.saveDrawing(notebookId: notebook.id, pageIndex: pageIdx, drawing: merged)
            }

        case "drawing_replace":
            guard let pageIdx = event.payload["page_index"] as? Int,
                  let b64 = event.payload["drawing_base64"] as? String,
                  let data = Data(base64Encoded: b64),
                  let remoteDrawing = try? PKDrawing(data: data) else { return }

            if pageIdx == currentPageIndex {
                if let canvas = canvasView {
                    isApplyingRemoteUpdate = true
                    canvas.drawing = remoteDrawing
                    currentDrawing = remoteDrawing
                    lastStrokeCount = remoteDrawing.strokes.count
                    store.saveDrawing(notebookId: notebook.id, pageIndex: currentPageIndex, drawing: remoteDrawing)
                    DispatchQueue.main.async {
                        isApplyingRemoteUpdate = false
                    }
                }
            } else {
                store.saveDrawing(notebookId: notebook.id, pageIndex: pageIdx, drawing: remoteDrawing)
            }

        case "attachment_upsert":
            guard let attType = event.payload["attachment_type"] as? String,
                  let itemDict = event.payload["item"] as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: itemDict) else { return }

            if attType == "text", let textItem = try? JSONDecoder().decode(NoteTextAttachment.self, from: jsonData) {
                if let idx = notebook.textAttachments?.firstIndex(where: { $0.id == textItem.id }) {
                    notebook.textAttachments?[idx] = textItem
                } else {
                    if notebook.textAttachments == nil { notebook.textAttachments = [] }
                    notebook.textAttachments?.append(textItem)
                }
                store.updateNotebook(notebook)
            } else if attType == "image", let imgItem = try? JSONDecoder().decode(NoteImageAttachment.self, from: jsonData) {
                if let idx = notebook.attachments?.firstIndex(where: { $0.id == imgItem.id }) {
                    notebook.attachments?[idx] = imgItem
                } else {
                    if notebook.attachments == nil { notebook.attachments = [] }
                    notebook.attachments?.append(imgItem)
                }
                store.updateNotebook(notebook)
            } else if attType == "3d", let modelItem = try? JSONDecoder().decode(Note3DAttachment.self, from: jsonData) {
                if let idx = notebook.model3DAttachments?.firstIndex(where: { $0.id == modelItem.id }) {
                    notebook.model3DAttachments?[idx] = modelItem
                } else {
                    if notebook.model3DAttachments == nil { notebook.model3DAttachments = [] }
                    notebook.model3DAttachments?.append(modelItem)
                }
                store.updateNotebook(notebook)
            }

        case "attachment_delete":
            guard let attId = event.payload["id"] as? String,
                  let attType = event.payload["attachment_type"] as? String else { return }

            if attType == "text" {
                notebook.textAttachments?.removeAll { $0.id == attId }
            } else if attType == "image" {
                notebook.attachments?.removeAll { $0.id == attId }
            } else if attType == "3d" {
                notebook.model3DAttachments?.removeAll { $0.id == attId }
            }
            store.updateNotebook(notebook)

        case "comment_upsert":
            guard let pinDict = event.payload["pin"] as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: pinDict),
                  let pin = try? JSONDecoder().decode(NoteCommentPin.self, from: jsonData) else { return }

            if let idx = notebook.commentPins?.firstIndex(where: { $0.id == pin.id }) {
                notebook.commentPins?[idx] = pin
            } else {
                if notebook.commentPins == nil { notebook.commentPins = [] }
                notebook.commentPins?.append(pin)
            }
            store.updateNotebook(notebook)

        case "comment_resolve":
            guard let pinId = event.payload["pin_id"] as? String,
                  let isResolved = event.payload["is_resolved"] as? Bool else { return }

            if let idx = notebook.commentPins?.firstIndex(where: { $0.id == pinId }) {
                notebook.commentPins?[idx].isResolved = isResolved
                store.updateNotebook(notebook)
            }

        case "comment_delete":
            guard let pinId = event.payload["pin_id"] as? String else { return }
            notebook.commentPins?.removeAll { $0.id == pinId }
            if selectedCommentPinId == pinId {
                selectedCommentPinId = nil
            }
            store.updateNotebook(notebook)

        default:
            break
        }
    }

    private func broadcastCommentPinUpsert(_ pin: NoteCommentPin) {
        guard let data = try? JSONEncoder().encode(pin),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        collaborationManager.broadcastCommentUpsert(pinDict: dict)
    }

    private func addCommentReply(pinId: String, text: String) {
        let msg = NoteCommentMessage(
            authorId: collaborationManager.currentUserId,
            authorName: AccountManager.shared.profile.displayName,
            authorColor: collaborationManager.myColorHex,
            text: text
        )
        if let idx = notebook.commentPins?.firstIndex(where: { $0.id == pinId }) {
            notebook.commentPins?[idx].messages.append(msg)
            store.updateNotebook(notebook)
            if let pin = notebook.commentPins?[idx] {
                broadcastCommentPinUpsert(pin)
            }
        }
    }

    private func toggleCommentResolve(pinId: String) {
        if let idx = notebook.commentPins?.firstIndex(where: { $0.id == pinId }) {
            notebook.commentPins?[idx].isResolved.toggle()
            let state = notebook.commentPins?[idx].isResolved ?? false
            store.updateNotebook(notebook)
            collaborationManager.broadcastCommentResolve(pinId: pinId, isResolved: state)
        }
    }

    /// 刪除討論串中的單一則留言。
    /// 只剩最後一則時不刪 —— 沒有任何訊息的圖釘在畫布上等於一個看不出用途的點，
    /// 要整個移除請用圖釘上的垃圾桶。
    private func deleteCommentMessage(pinId: String, messageId: String) {
        guard let idx = notebook.commentPins?.firstIndex(where: { $0.id == pinId }),
              let count = notebook.commentPins?[idx].messages.count,
              count > 1 else { return }
        notebook.commentPins?[idx].messages.removeAll { $0.id == messageId }
        store.updateNotebook(notebook)
        if let pin = notebook.commentPins?[idx] {
            broadcastCommentPinUpsert(pin)
        }
    }

    private func deleteCommentPin(pinId: String) {
        notebook.commentPins?.removeAll { $0.id == pinId }
        store.updateNotebook(notebook)
        selectedCommentPinId = nil
        collaborationManager.broadcastCommentDelete(pinId: pinId)
        collaborationManager.broadcastSelection(selectedId: nil)
    }

    /// 協同個人專屬復原與防誤刪墓碑還原
    private func performUndo() {
        if let backup = deletedAttachmentBackup {
            // 優先復原防誤刪墓碑中的物件
            if backup.type == "image", let item = backup.data as? NoteImageAttachment {
                if notebook.attachments == nil { notebook.attachments = [] }
                notebook.attachments?.append(item)
                store.updateNotebook(notebook)
                if let data = try? JSONEncoder().encode(item),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    collaborationManager.broadcastAttachmentUpsert(type: "image", itemDict: dict)
                }
            } else if backup.type == "text", let item = backup.data as? NoteTextAttachment {
                if notebook.textAttachments == nil { notebook.textAttachments = [] }
                notebook.textAttachments?.append(item)
                store.updateNotebook(notebook)
                if let data = try? JSONEncoder().encode(item),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    collaborationManager.broadcastAttachmentUpsert(type: "text", itemDict: dict)
                }
            } else if backup.type == "3d", let item = backup.data as? Note3DAttachment {
                if notebook.model3DAttachments == nil { notebook.model3DAttachments = [] }
                notebook.model3DAttachments?.append(item)
                store.updateNotebook(notebook)
                if let data = try? JSONEncoder().encode(item),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    collaborationManager.broadcastAttachmentUpsert(type: "3d", itemDict: dict)
                }
            }
            deletedAttachmentBackup = nil
        } else {
            canvasView?.undoManager?.undo()
        }
    }

    private func saveCurrentPageDrawing() {
        store.saveDrawing(notebookId: notebook.id, pageIndex: currentPageIndex, drawing: currentDrawing)
        notebook.lastModifiedDate = Date()
        store.updateNotebook(notebook)
    }

    /// 內容寫到頁尾時，確保後面有一頁可以接下去。
    ///
    /// 只在目前是最後一頁時才新增 —— 否則在中間的頁面寫到底，會憑空多出
    /// 一堆空白頁。
    private func ensureNextPageExists() {
        guard currentPageIndex == notebook.pageCount - 1 else { return }
        notebook.pageCount += 1
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

    /// 貼上剪貼簿中的筆劃。
    ///
    /// 為什麼需要自己做一顆：PencilKit 的內建選單（Cut / Copy / Duplicate…）只在
    /// **有選取時**才出現，複製完取消選取後就沒有入口可以貼上了。
    private func pasteStrokes() {
        guard let canvas = canvasView else { return }
        for sv in canvas.subviews where String(describing: type(of: sv)).contains("PKTiledView") {
            if sv.responds(to: #selector(UIResponderStandardEditActions.paste(_:))) {
                sv.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
            }
        }
        UIApplication.shared.sendAction(#selector(UIResponderStandardEditActions.paste(_:)), to: nil, from: nil, for: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.currentDrawing = canvas.drawing
            self.saveCurrentPageDrawing()
        }
    }

    /// 就地複製選取的筆劃並稍微偏移（不經過剪貼簿）—— 這就是「再製」與「複製」的差別：
    /// 「複製」把東西放進剪貼簿等你貼上，「再製」直接在旁邊多一份。
    private func duplicateSelectedStrokes() {
        guard let canvas = canvasView else { return }
        for sv in canvas.subviews where String(describing: type(of: sv)).contains("PKTiledView") {
            if sv.responds(to: #selector(UIResponderStandardEditActions.duplicate(_:))) {
                sv.perform(#selector(UIResponderStandardEditActions.duplicate(_:)), with: nil)
            }
        }
        UIApplication.shared.sendAction(#selector(UIResponderStandardEditActions.duplicate(_:)), to: nil, from: nil, for: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.currentDrawing = canvas.drawing
            self.saveCurrentPageDrawing()
        }
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
                title: "\(notebook.title) \(localizationManager.localized("recording_suffix"))",
                durationSeconds: Int(result.duration),
                fileName: fileName,
                linkedNotebookId: notebook.id
            )
        }
    }

    /// 每一頁完整算繪成一張圖，再組成 PDF。
    ///
    /// 舊版寫死 612×792（信紙尺寸）並且只畫 `PKDrawing` —— 但畫布座標是
    /// 「視圖寬度 × 頁面高度」，通常遠大於這個框，所以只截到左上角一小塊，
    /// 匯出檔看起來就是空白；文字方塊、圖片、3D、圖釘也全都沒畫進去。
    private func composedPageImages(scale: CGFloat) -> [(image: UIImage, size: CGSize)] {
        let width = max(canvasContentWidth, PageThumbnailRenderer.minPageWidth)
        return (0..<max(1, notebook.pageCount)).map { i in
            let drawing = (i == currentPageIndex) ? currentDrawing : store.loadDrawing(notebookId: notebook.id, pageIndex: i)
            let image = PageThumbnailRenderer.renderFullPage(
                notebook: notebook,
                pageIndex: i,
                drawing: drawing,
                store: store,
                canvasWidth: width,
                scale: scale
            )
            return (image, CGSize(width: width, height: notebook.height(forPage: i)))
        }
    }

    private func buildNotebookPdf(scale: CGFloat = 2.0) -> Data {
        saveCurrentPageDrawing()
        let pages = composedPageImages(scale: scale)
        let firstSize = pages.first?.size ?? CGSize(width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: firstSize))
        return renderer.pdfData { context in
            for page in pages {
                // 每一頁用自己的尺寸開頁：頁面可以被「向下延長」，高度不一定相同
                context.beginPage(withBounds: CGRect(origin: .zero, size: page.size), pageInfo: [:])
                page.image.draw(in: CGRect(origin: .zero, size: page.size))
            }
        }
    }

    private func exportAsPdf() {
        self.exportPdfData = buildNotebookPdf()
        self.showShareSheet = true
    }

    private func printCurrentNotebook() {
        let pdfData = buildNotebookPdf()

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
        let width = max(canvasContentWidth, PageThumbnailRenderer.minPageWidth)
        let img = PageThumbnailRenderer.renderFullPage(
            notebook: notebook,
            pageIndex: currentPageIndex,
            drawing: currentDrawing,
            store: store,
            canvasWidth: width,
            scale: 2.0
        )
        if let pngData = img.pngData() {
            self.exportPdfData = pngData
            self.showShareSheet = true
        }
    }

    private func shareNotebookFile() {
        exportAsPdf()
    }

    private func addNewPage() {
        saveCurrentPageDrawing()
        let newIndex = store.addPage(notebookId: notebook.id)
        if let updated = store.notebooks.first(where: { $0.id == notebook.id }) {
            self.notebook = updated
        }
        self.currentPageIndex = newIndex
        self.loadCurrentPage()
    }

    private func insertPageAfter(_ index: Int) {
        saveCurrentPageDrawing()
        let newIndex = store.insertPage(notebookId: notebook.id, afterIndex: index)
        if let updated = store.notebooks.first(where: { $0.id == notebook.id }) {
            self.notebook = updated
        }
        self.currentPageIndex = newIndex
        self.loadCurrentPage()
    }

    private func duplicatePage(at index: Int) {
        saveCurrentPageDrawing()
        let newIndex = store.duplicatePage(notebookId: notebook.id, pageIndex: index)
        if let updated = store.notebooks.first(where: { $0.id == notebook.id }) {
            self.notebook = updated
        }
        self.currentPageIndex = newIndex
        self.loadCurrentPage()
    }

    private func deletePage(at index: Int) {
        guard notebook.pageCount > 1 else { return }
        let safeIndex = store.deletePage(notebookId: notebook.id, pageIndex: index, currentIndex: currentPageIndex)
        if let updated = store.notebooks.first(where: { $0.id == notebook.id }) {
            self.notebook = updated
        }
        self.currentPageIndex = safeIndex
        self.loadCurrentPage()
    }

    private func switchToNotebook(_ target: NotebookDocument) {
        guard target.id != notebook.id else { return }
        saveCurrentPageDrawing()
        // 由外層換掉 Binding 指向的索引；這裡自己寫會覆蓋掉目前這則筆記。
        onRequestSwitch?(target)
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

/// 畫布共用座標系名稱。
///
/// 拖曳手勢**必須**綁在這個具名座標系上，不能用預設的 `.local`：
/// `.position()` 由手勢自己的 translation 驅動，而 `.local` 是「手勢所在那個
/// 視圖」的座標系 —— 視圖一被移動，座標原點跟著移動，translation 就會被重新
/// 換算回較小的值，形成「移動 → 原點位移 → translation 縮回」的回授迴圈，
/// 表現出來就是物件在手指底下抖動、跟不上。
enum CanvasCoordinateSpace {
    static let name = "kairumoCanvas"
}

/// 畫布內嵌附件視圖（支援圖片、算式卡片、數據圖表）
/// 支援手勢拖曳平移、角落手柄縮放、即時濾鏡美化、邊框、立體陰影與旋轉
struct AttachmentItemView: View {
    @Binding var attachment: NoteImageAttachment
    let onEdit: () -> Void
    let onDelete: () -> Void

    @ObservedObject var store = NotebookStore.shared
    @ObservedObject var localizationManager = LocalizationManager.shared
    @ObservedObject var collaborationManager = CollaborationManager.shared
    @State private var dragOffset: CGSize = .zero
    @State private var isSelected: Bool = false
    @State private var isDragging: Bool = false
    /// 縮放期間的本地預覽尺寸。
    ///
    /// 縮放中**不寫入 store**：每寫一次就會整份 notebooks 重新 JSON 編碼並原子
    /// 寫檔三次（見 `NotebookStore.persistData`），一秒鐘做六十次會直接卡住主執
    /// 行緒。只在手勢結束時提交一次。
    @State private var liveSize: CGSize? = nil
    /// 手勢開始時的原始尺寸。translation 是「從起點累計」的量，
    /// 若每幀都加到已更新的寬度上，尺寸會以平方成長。
    @State private var resizeBaseSize: CGSize? = nil

    private var lockedByPeer: CollaboratorPeer? {
        collaborationManager.peers.first(where: { $0.selectedId == attachment.id })
    }

    private var displayWidth: CGFloat { liveSize?.width ?? attachment.width }
    private var displayHeight: CGFloat { liveSize?.height ?? attachment.height }

    var body: some View {
        let currentX = attachment.x + dragOffset.width
        let currentY = attachment.y + dragOffset.height

        ZStack(alignment: .topTrailing) {
            Group {
                if let uiImage = store.loadAttachmentImage(fileName: attachment.fileName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: displayWidth, height: displayHeight)
                        .modifier(ImageFilterModifier(filter: attachment.filterStyle))
                        .objectMaterial(attachment.materialType)
                        .background(
                            RoundedRectangle(cornerRadius: attachment.cornerRadius)
                                .fill(ObjectFrameStyleResolver.background(attachment, .image))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: attachment.cornerRadius))
                        .overlay(
                            Group {
                                if let peer = lockedByPeer {
                                    RoundedRectangle(cornerRadius: attachment.cornerRadius)
                                        .stroke(Color(hex: peer.userColor) ?? .blue, lineWidth: 3)
                                } else {
                                    RoundedRectangle(cornerRadius: attachment.cornerRadius)
                                        .stroke(
                                            attachment.hasBorder
                                                ? ObjectFrameStyleResolver.borderColor(attachment, .image)
                                                : (isSelected ? Color.accentColor : Color.clear),
                                            lineWidth: attachment.hasBorder
                                                ? ObjectFrameStyleResolver.borderWidth(attachment, .image)
                                                : 1.5
                                        )
                                }
                            }
                        )
                        .shadow(color: (attachment.hasShadow && !isDragging) ? Color.black.opacity(0.18) : Color.clear, radius: 8, x: 2, y: 4)
                        .rotationEffect(.degrees(attachment.rotationDegrees))
                        .contextMenu {
                            ObjectFrameStyleMenu(style: $attachment)
                            Divider()
                            Button(role: .destructive, action: onDelete) {
                                Label(localizationManager.localized("delete"), systemImage: "trash")
                            }
                        }
                } else {
                    RoundedRectangle(cornerRadius: attachment.cornerRadius)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: displayWidth, height: displayHeight)
                        .overlay(
                            ProgressView()
                        )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard lockedByPeer == nil else { return }
                isSelected.toggle()
                collaborationManager.broadcastSelection(selectedId: isSelected ? attachment.id : nil)
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(CanvasCoordinateSpace.name))
                    .onChanged { value in
                        guard lockedByPeer == nil else { return }
                        isDragging = true
                        var transaction = Transaction()
                        transaction.animation = nil
                        withTransaction(transaction) {
                            dragOffset = value.translation
                        }
                    }
                    .onEnded { value in
                        guard lockedByPeer == nil else { return }
                        var transaction = Transaction()
                        transaction.animation = nil
                        withTransaction(transaction) {
                            attachment.x += value.translation.width
                            attachment.y += value.translation.height
                            dragOffset = .zero
                            isDragging = false
                        }
                        if let data = try? JSONEncoder().encode(attachment),
                           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            collaborationManager.broadcastAttachmentUpsert(type: "image", itemDict: dict)
                        }
                    }
            )

            // 遠端成員軟鎖定中指示徽章
            if let peer = lockedByPeer {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: peer.userColor) ?? .blue)
                        .frame(width: 8, height: 8)
                    Text("\(peer.userName) \(localizationManager.localized("object_locked_by"))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: peer.userColor)?.opacity(0.95) ?? Color.blue)
                .cornerRadius(10)
                .offset(x: -8, y: -24)
            }

            // 選取時顯示浮動小操作把手：編輯（美化）、邊框保留/刪除、刪除、右下角縮放把手
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

                    // 邊框保留或刪除快速開關
                    Button {
                        attachment.hasBorder.toggle()
                    } label: {
                        Image(systemName: attachment.hasBorder ? "rectangle.inset.filled" : "rectangle")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(attachment.hasBorder ? Color.purple : Color.secondary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(localizationManager.localized("toggle_border"))

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
                                DragGesture(minimumDistance: 1, coordinateSpace: .named(CanvasCoordinateSpace.name))
                                    .onChanged { value in
                                        let base = resizeBaseSize ?? CGSize(width: attachment.width, height: attachment.height)
                                        if resizeBaseSize == nil { resizeBaseSize = base }
                                        let ratio = base.height / max(1, base.width)
                                        let newW = max(80, base.width + value.translation.width)
                                        liveSize = CGSize(width: newW, height: max(60, newW * ratio))
                                    }
                                    .onEnded { _ in
                                        if let size = liveSize {
                                            attachment.width = size.width
                                            attachment.height = size.height
                                            if let data = try? JSONEncoder().encode(attachment),
                                               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                                collaborationManager.broadcastAttachmentUpsert(type: "image", itemDict: dict)
                                            }
                                        }
                                        resizeBaseSize = nil
                                        liveSize = nil
                                    }
                            )
                            .offset(x: 6, y: 6)
                    }
                }
                .frame(width: displayWidth, height: displayHeight)
            }
        }
        .position(x: currentX + displayWidth / 2, y: currentY + displayHeight / 2)
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

    @ObservedObject var localizationManager = LocalizationManager.shared
    @ObservedObject var collaborationManager = CollaborationManager.shared
    @State private var dragOffset: CGSize = .zero
    /// 縮放期間的本地預覽寬度（理由同 `AttachmentItemView.liveSize`）。
    @State private var liveWidth: CGFloat? = nil
    @State private var resizeBaseWidth: CGFloat? = nil
    @State private var isSelected: Bool = false
    @State private var isDragging: Bool = false
    /// 就地編輯：直接在畫布上改字，不必先開面板
    @State private var isEditingInline: Bool = false
    @FocusState private var inlineFocused: Bool

    private var lockedByPeer: CollaboratorPeer? {
        collaborationManager.peers.first(where: { $0.selectedId == textItem.id })
    }

    /// 選取時的動作按鈕（圖示 + 文字，看得懂也點得到）
    private func textActionButton(_ icon: String, _ titleKey: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(localizationManager.localized(titleKey))
                    .font(.system(size: 11, weight: .semibold))
                    .fixedSize()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(tint)
            .cornerRadius(7)
        }
        .buttonStyle(.plain)
        .help(localizationManager.localized(titleKey))
    }

    private var displayWidth: CGFloat { liveWidth ?? textItem.width }

    var body: some View {
        let currentX = textItem.x + dragOffset.width
        let currentY = textItem.y + dragOffset.height

        ZStack(alignment: .topTrailing) {
            VStack(alignment: resolveAlignment(textItem.alignmentRaw), spacing: 4) {
                if isEditingInline {
                    // 就地編輯：點兩下就能直接改字，不必先開面板
                    TextEditor(text: $textItem.text)
                        .font(.system(size: textItem.fontSize, weight: textItem.isBold ? .bold : .regular))
                        .foregroundColor(Color(hex: textItem.textColorHex) ?? .primary)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(minHeight: 60)
                        .focused($inlineFocused)
                        .overlay(alignment: .bottomTrailing) {
                            Button {
                                isEditingInline = false
                                inlineFocused = false
                                broadcastTextChange()
                            } label: {
                                Text(localizationManager.localized("done"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.accentColor)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .offset(x: 4, y: 22)
                        }
                } else {
                    Text(textItem.text)
                        .font(.system(size: textItem.fontSize, weight: textItem.isBold ? .bold : .regular))
                        .italic(textItem.isItalic)
                        .underline(textItem.isUnderline)
                        .strikethrough(textItem.isStrikethrough)
                        .foregroundColor(Color(hex: textItem.textColorHex) ?? .primary)
                        .multilineTextAlignment(resolveMultilineAlignment(textItem.alignmentRaw))
                        .frame(maxWidth: .infinity, alignment: resolveFrameAlignment(textItem.alignmentRaw))
                }
            }
            .padding(14)
            .frame(width: displayWidth)
            .background(resolveBackground(textItem.backgroundColorHex))
            .clipShape(RoundedRectangle(cornerRadius: textItem.cornerRadius))
            .overlay(
                Group {
                    if let peer = lockedByPeer {
                        RoundedRectangle(cornerRadius: textItem.cornerRadius)
                            .stroke(Color(hex: peer.userColor) ?? .blue, lineWidth: 3)
                    } else {
                        RoundedRectangle(cornerRadius: textItem.cornerRadius)
                            .stroke(
                                textItem.hasBorder
                                    ? (Color(hex: textItem.borderColorHex ?? "") ?? Color.secondary.opacity(0.4))
                                    : (isSelected ? Color.accentColor : Color.clear),
                                lineWidth: textItem.hasBorder ? (textItem.borderWidth ?? 1.5) : 1
                            )
                    }
                }
            )
            .shadow(color: isDragging ? Color.clear : Color.black.opacity(0.08), radius: 6, y: 3)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                // 點兩下＝就地編輯（最直覺的路徑）
                guard lockedByPeer == nil else { return }
                isSelected = true
                isEditingInline = true
                inlineFocused = true
            }
            .onTapGesture {
                guard lockedByPeer == nil else { return }
                if isEditingInline { return }
                isSelected.toggle()
                collaborationManager.broadcastSelection(selectedId: isSelected ? textItem.id : nil)
            }
            // 右鍵／長按也要能刪除 —— 這是大家最先嘗試的操作
            .contextMenu {
                Button {
                    isSelected = true
                    isEditingInline = true
                    inlineFocused = true
                } label: { Label(localizationManager.localized("edit_in_place"), systemImage: "character.cursor.ibeam") }

                Button {
                    onEdit()
                } label: { Label(localizationManager.localized("text_studio"), systemImage: "textformat") }

                ObjectFrameStyleMenu(style: $textItem, onChange: broadcastTextChange)

                Divider()

                Button(role: .destructive) {
                    onDelete()
                } label: { Label(localizationManager.localized("delete"), systemImage: "trash") }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(CanvasCoordinateSpace.name))
                    .onChanged { value in
                        guard lockedByPeer == nil else { return }
                        isDragging = true
                        var transaction = Transaction()
                        transaction.animation = nil
                        withTransaction(transaction) {
                            dragOffset = value.translation
                        }
                    }
                    .onEnded { value in
                        guard lockedByPeer == nil else { return }
                        var transaction = Transaction()
                        transaction.animation = nil
                        withTransaction(transaction) {
                            textItem.x += value.translation.width
                            textItem.y += value.translation.height
                            dragOffset = .zero
                            isDragging = false
                        }
                        if let data = try? JSONEncoder().encode(textItem),
                           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            collaborationManager.broadcastAttachmentUpsert(type: "text", itemDict: dict)
                        }
                    }
            )

            // 遠端成員軟鎖定中指示徽章
            if let peer = lockedByPeer {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: peer.userColor) ?? .blue)
                        .frame(width: 8, height: 8)
                    Text("\(peer.userName) \(localizationManager.localized("object_locked_by"))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: peer.userColor)?.opacity(0.95) ?? Color.blue)
                .cornerRadius(10)
                .offset(x: -8, y: -24)
            }

            // 選取時的動作列。按鈕帶文字，且整條移到方塊上方 ——
            // 原本是三顆無標示的小圓點又壓在方塊角上，很難點也看不懂。
            if isSelected && !isEditingInline {
                HStack(spacing: 6) {
                    textActionButton("pencil", "edit", .blue) { onEdit() }
                    textActionButton(
                        textItem.hasBorder ? "rectangle.inset.filled" : "rectangle",
                        "toggle_border",
                        textItem.hasBorder ? .purple : .gray
                    ) { textItem.hasBorder.toggle() }
                    textActionButton("trash.fill", "delete", .red) { onDelete() }
                }
                .padding(4)
                .background(Color(uiColor: .systemBackground).opacity(0.95))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.15), radius: 5, y: 2)
                .offset(x: 6, y: -42)

                // 原本這裡有一顆「雙向箭頭」縮放把手：它很小、會擋住文字、
                // 又只能改寬度，使用者反映沒必要。寬度改到「文字排版」裡調整，
                // 畫布上只保留編輯／邊框／刪除三個明確的動作。
            }
        }
        .position(x: currentX + displayWidth / 2, y: currentY + 60)
    }

    private func broadcastTextChange() {
        if let data = try? JSONEncoder().encode(textItem),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            collaborationManager.broadcastAttachmentUpsert(type: "text", itemDict: dict)
        }
    }

    /// 解析方框底色。`nil` 是舊檔沒有這個欄位（回落成白色），
    /// `"clear"` 是使用者主動選了透明 —— 兩者不一樣，不能混為一談。
    private func resolveBackground(_ hex: String?) -> Color {
        guard let hex else { return .white }
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
    @ObservedObject var localizationManager = LocalizationManager.shared
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
                            Text(localizationManager.localized("open"))
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
                DragGesture(minimumDistance: 1, coordinateSpace: .named(CanvasCoordinateSpace.name))
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

/// 插入物件共用的外框樣式解析（SwiftUI 端）。
///
/// 匯出端有一份等價的實作（`PageThumbnailRenderer.FrameDefaults`）。兩邊必須
/// 給出同樣的結果 —— 否則「畫布所見」與「匯出所得」又會分家。差異用
/// `ObjectFrameStyleTests` 釘住。
enum ObjectFrameStyleResolver {
    struct Defaults {
        var borderColor: Color
        var borderWidth: CGFloat
        /// `nil` 代表這個型別原本就沒有底色。
        var background: Color?

        static let image = Defaults(
            borderColor: .accentColor.opacity(0.8), borderWidth: 2.5, background: nil)
        static let text = Defaults(
            borderColor: .accentColor.opacity(0.5), borderWidth: 1.5, background: .white)
        static let link = Defaults(
            borderColor: Color(UIColor.separator), borderWidth: 1,
            background: Color(UIColor.tertiarySystemBackground))
        static let model3D = Defaults(
            borderColor: .accentColor.opacity(0.45), borderWidth: 1.5,
            background: Color(UIColor.secondarySystemBackground))
    }

    /// 底色。`nil`（舊檔沒這欄位）回落預設；`"clear"` 是使用者選的透明。
    static func background(_ style: some ObjectFrameStyled, _ defaults: Defaults) -> Color {
        guard let hex = style.backgroundColorHex else { return defaults.background ?? .clear }
        if hex == "clear" { return .clear }
        return Color(hex: hex) ?? defaults.background ?? .clear
    }

    static func borderColor(_ style: some ObjectFrameStyled, _ defaults: Defaults) -> Color {
        guard style.hasBorder else { return .clear }
        return style.borderColorHex.flatMap { Color(hex: $0) } ?? defaults.borderColor
    }

    static func borderWidth(_ style: some ObjectFrameStyled, _ defaults: Defaults) -> CGFloat {
        style.hasBorder ? (style.borderWidth ?? defaults.borderWidth) : 0
    }
}

struct Model3DCanvasItemView: View {
    @ObservedObject var localizationManager = LocalizationManager.shared
    @ObservedObject var collaborationManager = CollaborationManager.shared
    @Binding var item: Note3DAttachment
    let onDelete: () -> Void

    @State private var dragOffset: CGSize = .zero

    private var lockedByPeer: CollaboratorPeer? {
        collaborationManager.peers.first(where: { $0.selectedId == item.id })
    }

    var body: some View {
        let currentX = item.x + dragOffset.width
        let currentY = item.y + dragOffset.height

        VStack(spacing: 0) {
            // 移動拖曳手把條（與 3D 旋轉手勢分離，方便自由平移卡片）
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(localizationManager.localized("drag_card_hint"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()

                // 遠端成員軟鎖定中提示
                if let peer = lockedByPeer {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: peer.userColor) ?? .blue)
                            .frame(width: 7, height: 7)
                        Text("\(peer.userName) \(localizationManager.localized("object_locked_by"))")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: peer.userColor)?.opacity(0.95) ?? Color.blue)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(8)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(CanvasCoordinateSpace.name))
                    .onChanged { value in
                        guard lockedByPeer == nil else { return }
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        guard lockedByPeer == nil else { return }
                        item.x += value.translation.width
                        item.y += value.translation.height
                        dragOffset = .zero
                        if let data = try? JSONEncoder().encode(item),
                           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            collaborationManager.broadcastAttachmentUpsert(type: "3d", itemDict: dict)
                        }
                    }
            )

            Model3DInteractiveCardView(
                attachment: $item,
                onDelete: onDelete
            )
            // 底色與邊框吃使用者的設定。原本是寫死的 —— 那表示「所有插入的
            // 東西都能調外框」這件事在 3D 模型上是假的。
            .background(
                RoundedRectangle(cornerRadius: item.cornerRadius)
                    .fill(ObjectFrameStyleResolver.background(item, .model3D))
            )
            .overlay(
                RoundedRectangle(cornerRadius: item.cornerRadius)
                    .stroke(
                        ObjectFrameStyleResolver.borderColor(item, .model3D),
                        lineWidth: ObjectFrameStyleResolver.borderWidth(item, .model3D)
                    )
            )
            .overlay(
                Group {
                    if let peer = lockedByPeer {
                        RoundedRectangle(cornerRadius: item.cornerRadius)
                            .stroke(Color(hex: peer.userColor) ?? .blue, lineWidth: 3)
                    }
                }
            )
            .contextMenu {
                ObjectFrameStyleMenu(style: $item)
                Divider()
                Button(role: .destructive, action: onDelete) {
                    Label(localizationManager.localized("delete"), systemImage: "trash")
                }
            }
        }
        .frame(width: max(200, item.width))
        .position(x: currentX + item.width / 2, y: currentY + item.height / 2)
    }
}

/// 移動筆記至指定資料夾彈窗
public struct MoveNotebookSheet: View {
    public let notebookId: String
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store = NotebookStore.shared
    @ObservedObject var localizationManager = LocalizationManager.shared

    public init(notebookId: String) {
        self.notebookId = notebookId
    }

    public var body: some View {
        NavigationStack {
            List {
                Section(header: Text(localizationManager.localized("select_destination_folder"))) {
                    // 最上層根資料夾
                    Button {
                        store.moveNotebook(id: notebookId, toFolderId: nil)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "tray.2.fill")
                                .foregroundColor(.accentColor)
                            Text("\(store.displayRootFolderName) (\(localizationManager.localized("root_folder")))")
                                .foregroundColor(.primary)
                            Spacer()
                            if let note = store.notebooks.first(where: { $0.id == notebookId }), note.folderId == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }

                    // 自訂資料夾清單
                    ForEach(store.folders) { folder in
                        Button {
                            store.moveNotebook(id: notebookId, toFolderId: folder.id)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: folder.parentId == nil ? "folder.fill" : "folder.badge.gearshape")
                                    .foregroundColor(folder.parentId == nil ? .accentColor : .secondary)
                                Text(folder.name)
                                    .foregroundColor(.primary)
                                    .padding(.leading, folder.parentId == nil ? 0 : 16)
                                Spacer()
                                if let note = store.notebooks.first(where: { $0.id == notebookId }), note.folderId == folder.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(localizationManager.localized("move_to_folder"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// 遠端協同成員即時游標浮動圖層（平滑動畫、具名標籤與筆尖狀態指示）
struct RemoteCursorsOverlay: View {
    @ObservedObject var collaborationManager = CollaborationManager.shared

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(collaborationManager.peers) { peer in
                if let cursor = peer.cursor {
                    HStack(alignment: .top, spacing: 3) {
                        // 游標 / 筆尖指示圖示
                        Image(systemName: cursor.isDrawing ? "pencil.tip" : "cursorarrow.rays")
                            .font(.system(size: cursor.isDrawing ? 14 : 12, weight: .bold))
                            .foregroundColor(Color(hex: peer.userColor) ?? .accentColor)
                            .shadow(color: Color.black.opacity(0.2), radius: 2, y: 1)

                        // 成員姓名徽章
                        HStack(spacing: 3) {
                            Text(peer.userName)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            if cursor.isDrawing {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 4, height: 4)
                            }
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(hex: peer.userColor) ?? .accentColor)
                        .cornerRadius(4)
                        .shadow(color: Color.black.opacity(0.15), radius: 3, y: 1)
                    }
                    .position(x: cursor.x, y: cursor.y)
                    .animation(.spring(response: 0.15, dampingFraction: 0.8), value: cursor.x)
                    .animation(.spring(response: 0.15, dampingFraction: 0.8), value: cursor.y)
                }
            }
        }
        .allowsHitTesting(false)
    }
}


