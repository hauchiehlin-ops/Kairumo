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
import UniformTypeIdentifiers

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

    /// 這個工具是不是「筆」。
    ///
    /// 橡皮擦與套索不是筆：一個是擦掉、一個是選取，兩者都不沾墨，也不吃
    /// 顏色與粗細。工具列把九個圖示排成沒有斷點的一長列時，使用者得靠
    /// 記圖案來分辨 —— 分組之後，形狀就說明了用途（工作項 S-62）。
    public var isBrush: Bool {
        switch self {
        case .eraser, .lasso: return false
        default: return true
        }
    }

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
    /// 觸控觀察。
    ///
    /// 觀察而**不攔截**：一律呼叫 `super`，PencilKit 的繪製路徑完全不受影響。
    /// 我們只是在旁邊看，決定要不要切換輸入政策、以及有沒有東西要收回。
    ///
    /// 寫在類別本體而不是 extension：在 extension 裡 override UIKit 方法雖然
    /// 編得過，但那是靠 @objc 動態派發矇混，不是 Swift 保證的行為。
    var onTouchObserved: ((UITouch) -> Void)?

    /// 輸入診斷。掛在同一個觀察點上 —— 出問題時要看得到輸入本身長什麼樣。
    ///
    /// `touchesMoved` 也要記：`coalescedTouches` 的數量只有在移動時才有意義，
    /// 只在 began／ended 取樣的話永遠是 1，而那正是「快速書寫變折線」的徵兆
    /// 被漏掉的原因。
    var onTouchDiagnostics: ((UITouch, UIEvent?) -> Void)?

    /// 目前的筆頭形狀。由 `CanvasRepresentable` 更新。
    ///
    /// 用 `UIPointerInteraction` 而不是 `NSCursor`：這個 App 在 iPadOS 與
    /// Mac Catalyst 上跑同一份程式碼，而 Catalyst 沒有直接可用的 `NSCursor`。
    var brushPointerPath: UIBezierPath?

    func refreshPointer(_ path: UIBezierPath?) {
        brushPointerPath = path
        // 讓系統重新問一次要顯示什麼游標。不呼叫的話，換了筆刷游標仍是舊的，
        // 要把滑鼠移出去再移回來才會更新。
        pointerInteractions.forEach { $0.invalidate() }
    }

    private var pointerInteractions: [UIPointerInteraction] {
        interactions.compactMap { $0 as? UIPointerInteraction }
    }

    func installPointerInteractionIfNeeded(delegate: UIPointerInteractionDelegate) {
        guard pointerInteractions.isEmpty else { return }
        addInteraction(UIPointerInteraction(delegate: delegate))
    }

    /// 懸停預覽（工作項 S-69）。筆尖靠近但還沒碰到時，先畫出會落在哪裡。
    private var hoverPreview: PenHoverPreviewView?

    func installHoverPreviewIfNeeded(coordinator: PenHoverCoordinator) {
        guard hoverPreview == nil else { return }
        let preview = PenHoverPreviewView(frame: bounds)
        preview.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // 加在畫布的**最上層**：筆頭預覽被墨跡蓋住就失去意義了。
        // 它 `isUserInteractionEnabled = false`，不會擋到書寫。
        addSubview(preview)
        hoverPreview = preview
        coordinator.attach(to: self, preview: preview)
    }

    /// 掛上 Apple Pencil 的筆身互動（工作項 S-40 / S-67）。
    ///
    /// 雙擊與擠壓都由它來。對應規則在核心（`padnote-input::pen`），
    /// 這裡只負責把事件送過去 —— 見 `PenHardware.swift`。
    ///
    /// 掛在畫布上而不是根視圖：雙擊只有在「正在寫字」的情境下才有意義，
    /// 掛在根視圖的話，在設定頁或檔案清單裡雙擊也會默默換掉工具。
    func installPencilInteractionIfNeeded(delegate: UIPencilInteractionDelegate) {
        guard interactions.compactMap({ $0 as? UIPencilInteraction }).isEmpty else { return }
        // 不用 `init(delegate:)` —— 那個建構式是 iOS 17.5 才有的，
        // 而部署目標比它低。分兩步寫，舊系統上一樣掛得上去。
        let interaction = UIPencilInteraction()
        interaction.delegate = delegate
        addInteraction(interaction)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach {
            onTouchObserved?($0)
            onTouchDiagnostics?($0, event)
        }
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach { onTouchDiagnostics?($0, event) }
        super.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach {
            onTouchObserved?($0)
            onTouchDiagnostics?($0, event)
        }
        super.touchesEnded(touches, with: event)
    }

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
    /// 這個畫布要不要自己捲動。
    ///
    /// 連續頁面模式下每一頁都是一個 PKCanvasView，外面還有一個 ScrollView。
    /// 兩層都能捲的話，手指放在畫布上時捲到的是裡層那一頁 —— 捲不出去，
    /// 看起來像卡住。連續模式把裡層關掉，捲動交給外面那一層。
    var isScrollEnabled: Bool = true
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
    /// 掌拒（工作項 S-45）。判定規則走核心，與 Android 同一份。
    var palmRejection: PalmRejectionCoordinator?
    /// 仲裁器要求收回筆畫時通知編輯器。
    var onRetractStrokes: ((Date) -> Void)?
    /// 筆身上的動作（工作項 S-40 / S-67）。`pressed` 只對側鍵這類
    /// 「按著」的控制項有意義。
    var onPenControl: ((FfiPenControl, Bool) -> Void)?

    /// 目前該用哪個輸入政策。
    ///
    /// 打字模式一律只有筆能寫（手指要用來捲動與選取）。手寫模式交給掌拒
    /// 協調器決定 —— 沒有它時退回原本的 `.anyInput`，行為與以前相同。
    ///
    /// **`drawingPolicy` 只能表達「誰可以畫」，表達不了「誰都不能畫」。**
    /// 打字模式下真正要的是後者，所以另外關掉 `drawingGestureRecognizer`
    /// —— 只設 `.pencilOnly` 的話，拿 Apple Pencil 的人在「打字模式」裡
    /// 照樣在畫畫，而畫面上沒有任何東西告訴他模式換了。
    private func resolvedPolicy(now: Date = Date()) -> PKCanvasViewDrawingPolicy {
        guard editorMode == .draw else { return .pencilOnly }
        return palmRejection?.drawingPolicy(now: now) ?? .anyInput
    }

    /// 這個模式下畫布接不接受筆畫。
    private var acceptsInk: Bool { editorMode == .draw }

    /// 給核心看的模式。
    private var ffiEditorMode: FfiEditorMode { editorMode == .draw ? .draw : .type }

    /// 給核心看的輸入政策。`.anyInput` 才算「手指可以畫」。
    private var ffiInkPolicy: FfiInkPolicy {
        resolvedPolicy() == .anyInput ? .anyInput : .stylusOnly
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = AdaptiveCanvasView()
        canvas.drawingPolicy = resolvedPolicy()
        canvas.onTouchObserved = { [weak canvas] touch in
            guard let palm = palmRejection else { return }
            let landed = Date()
            if palm.observe(touch: touch, now: landed) {
                onRetractStrokes?(landed)
            }
            let policy = palm.drawingPolicy(now: landed)
            if canvas?.drawingPolicy != policy { canvas?.drawingPolicy = policy }
        }
        canvas.onTouchDiagnostics = { [weak canvas] touch, event in
            guard let canvas else { return }
            InkInputDiagnostics.shared.record(touch: touch, event: event, in: canvas)
        }
        canvas.delegate = context.coordinator
        canvas.drawingGestureRecognizer.isEnabled = acceptsInk
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = isScrollEnabled
        canvas.alwaysBounceVertical = isScrollEnabled
        canvas.showsVerticalScrollIndicator = isScrollEnabled
        canvas.showsHorizontalScrollIndicator = false

        // **捏合縮放。**
        //
        // `PKCanvasView` 是一個 `UIScrollView`，而 scroll view 的預設
        // `minimumZoomScale` 與 `maximumZoomScale` **都是 1.0** —— 也就是
        // 「不准縮放」。這兩行從來沒有被設定過，所以捏合手勢在任何裝置上
        // 都不會有反應。使用者的回報是「手機上沒辦法變更畫面大小」，
        // 而那不是設定錯了，是根本沒做。
        //
        // 範圍由核心給，兩端同一組數字。
        let gesture = canvasGesture(mode: ffiEditorMode, ink: ffiInkPolicy)
        canvas.minimumZoomScale = CGFloat(gesture.minZoom)
        canvas.maximumZoomScale = CGFloat(gesture.maxZoom)
        canvas.bouncesZoom = true

        canvas.drawing = drawing

        // 給自動化測試一個穩定的抓取點（畫面上有多個 scroll view）
        canvas.accessibilityIdentifier = "kairumo.canvas"
        canvas.installPointerInteractionIfNeeded(delegate: context.coordinator)
        canvas.installPencilInteractionIfNeeded(delegate: context.coordinator.pencilTaps)
        context.coordinator.penHover.currentPath = { [weak coordinator = context.coordinator] in
            guard let coordinator else { return nil }
            return BrushCursor.path(
                for: coordinator.parent.selectedTool,
                strokeWidth: coordinator.parent.strokeWidth)
        }
        context.coordinator.penHover.currentColor = { [weak coordinator = context.coordinator] in
            UIColor(coordinator?.parent.selectedColor ?? .primary)
        }
        context.coordinator.penHover.isPreviewEnabled = { [weak coordinator = context.coordinator] in
            coordinator?.parent.editorMode == .draw
        }
        canvas.installHoverPreviewIfNeeded(coordinator: context.coordinator.penHover)
        canvas.refreshPointer(BrushCursor.path(for: selectedTool, strokeWidth: strokeWidth))
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
        // 模式切換時要跟著改 —— 只在 makeUIView 設的話，從連續切回整頁
        // 會得到一個捲不動的畫布（SwiftUI 會重用同一個 UIView）。
        if uiView.isScrollEnabled != isScrollEnabled {
            uiView.isScrollEnabled = isScrollEnabled
            uiView.alwaysBounceVertical = isScrollEnabled
            uiView.showsVerticalScrollIndicator = isScrollEnabled
        }
        let targetPolicy = resolvedPolicy()
        if uiView.drawingPolicy != targetPolicy {
            uiView.drawingPolicy = targetPolicy
        }
        // 模式切換時縮放範圍也要重設 —— 只在 makeUIView 設的話，
        // SwiftUI 重用同一個 UIView 時會沿用舊值。
        let gesture = canvasGesture(mode: ffiEditorMode, ink: ffiInkPolicy)
        if uiView.minimumZoomScale != CGFloat(gesture.minZoom) {
            uiView.minimumZoomScale = CGFloat(gesture.minZoom)
        }
        if uiView.maximumZoomScale != CGFloat(gesture.maxZoom) {
            uiView.maximumZoomScale = CGFloat(gesture.maxZoom)
        }
        // 見 `acceptsInk`：政策擋不掉 Pencil，手勢本身要關。
        if uiView.drawingGestureRecognizer.isEnabled != acceptsInk {
            uiView.drawingGestureRecognizer.isEnabled = acceptsInk
        }
        // 換筆刷或拉筆寬時，游標要跟著變 —— 不更新的話使用者得把滑鼠移出去
        // 再移回來才看得到新的筆頭。
        if let adaptive = uiView as? AdaptiveCanvasView {
            adaptive.installPointerInteractionIfNeeded(delegate: context.coordinator)
            adaptive.refreshPointer(BrushCursor.path(for: selectedTool, strokeWidth: strokeWidth))
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

    class Coordinator: NSObject, PKCanvasViewDelegate, UIPointerInteractionDelegate {
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

        /// Apple Pencil 雙擊的接收端。**這個屬性要持有它** ——
        /// `UIPencilInteraction.delegate` 是 weak 的，不留一份強參考的話
        /// 它會在 `makeUIView` 回傳之後就被釋放，雙擊從此沒有反應。
        let pencilTaps = PencilInteractionForwarder()

        /// 懸停預覽（工作項 S-69）。與 `pencilTaps` 一樣要由這裡持有 ——
        /// 手勢辨識器只對 target 保持 weak 參考。
        let penHover = PenHoverCoordinator()

        init(_ parent: CanvasRepresentable) {
            self.parent = parent
            super.init()
            pencilTaps.onControl = { [weak self] control, pressed in
                self?.parent.onPenControl?(control, pressed)
            }
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

        /// 自訂筆頭游標。
        ///
        /// 選了螢光筆卻看到一個箭頭 —— 使用者得先畫一筆才知道自己選到什麼、
        /// 那一筆會有多粗。把游標換成對應的筆頭，落筆之前就看得見。
        func pointerInteraction(
            _ interaction: UIPointerInteraction,
            styleFor region: UIPointerRegion
        ) -> UIPointerStyle? {
            guard let canvas = interaction.view as? AdaptiveCanvasView,
                  let path = canvas.brushPointerPath else { return nil }
            // 不加 `constrainedAxes`：筆頭要能自由移動，限制軸是給滑桿用的。
            return UIPointerStyle(shape: .path(path), constrainedAxes: [])
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

    /// 頁面顯示模式。**預設整頁**；使用者切過之後記住他的選擇。
    ///
    /// 存在 AppStorage 而不是筆記裡：它是「怎麼看」而不是「內容是什麼」，
    /// 跟著人走比跟著筆記走合理 —— 跟著筆記的話，同一個人在不同本筆記裡
    /// 會拿到不同的捲動方式。
    @AppStorage("kairumo.editor.pageDisplayMode")
    private var pageDisplayModeRaw: String = PageDisplayMode.single.rawValue
    private var pageDisplayMode: PageDisplayMode {
        PageDisplayMode(rawValue: pageDisplayModeRaw) ?? .single
    }
    @State private var currentDrawing: PKDrawing = PKDrawing()
    @State private var canvasView: PKCanvasView? = nil
    @State private var currentPageHeight: CGFloat = PageGeometry.height
    /// 掌拒（工作項 S-45）。判定規則走核心，與 Android 同一份。
    @State private var palmRejection = PalmRejectionCoordinator()
    @State private var hasLassoSelection: Bool = false
    @State private var showExtendedBanner: Bool = false

    // 實體工具列狀態
    @State private var selectedTool: EditorToolType = .pen

    /// 有東西正懸在畫布上等著放下（工作項 S-68）。
    ///
    /// 一定要有這個回饋：拖放看不見目標的話，使用者不知道放開會發生什麼事，
    /// 也分不出「這裡不能放」與「放了但沒反應」。
    @State private var isCanvasDropTargeted: Bool = false

    /// 按著側鍵之前選的是哪一支。放開時回到它。
    ///
    /// `nil` 表示「這一次的橡皮擦不是側鍵切出來的」—— 使用者自己在工具列
    /// 選的橡皮擦，不能因為他碰了一下側鍵就被換掉。
    @State private var penHeldTool: EditorToolType? = nil

    /// 最後用過的**筆刷**。筆身動作要切回來的就是它（工作項 S-67）。
    ///
    /// 由 `.onChange(of: selectedTool)` 維護，不是 `didSet` ——
    /// `@State` 的 `didSet` 在透過 binding（`$selectedTool`）改值時不會觸發，
    /// 那會變成「用某些 UI 換筆會記到、用另一些不會」。
    ///
    /// 記「最後用過的筆刷」而不是「上一個工具」：後者在連按兩次之後會在
    /// 橡皮擦與套索之間跳，而使用者按第二次想回到的是他原本那支筆。
    @State private var lastBrushTool: EditorToolType = .pen
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
    @State private var showTableStudio: Bool = false
    @State private var showShapeStudio: Bool = false
    @State private var showLayerPanel: Bool = false
    /// 圖層面板裡選取的形狀。多選才群組得起來。
    @State private var selectedShapeIds: Set<String> = []
    /// 正在重新編修的表格。
    @State private var editingTable: NoteTableAttachment? = nil
    @State private var editingAttachmentId: String? = nil
    /// 正在重新編修的圖表。帶著規格一起，`sheet(item:)` 才有東西可以開。
    @State private var editingChartAttachmentId: ChartEditTarget? = nil

    // Word 文字排版、網址預覽與專業調色狀態
    @State private var showWordStudio: Bool = false
    /// 摘要與待辦（工作項 S-20）。
    @State private var showNoteIntelligence: Bool = false
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
    /// 「插入錄音」的挑選面板。
    @State private var showAudioPicker: Bool = false

    // MARK: - 框選
    //
    // 見 ObjectMarquee 開頭的說明：框選是一個**明確的模式**，不是
    // 「在空白處拖曳」—— 那會跟搬物件與捲畫布互相搶。
    @State private var isMarqueeActive: Bool = false
    @State private var marqueeStart: CGPoint? = nil
    @State private var marqueeCurrent: CGPoint? = nil
    @State private var selectedObjectIds: Set<String> = []
    /// 整組拖曳時的即時位移。每一幀都寫回筆記的話，拖一次會存幾十次檔。
    @State private var groupDragOffset: CGSize = .zero
    @State private var objectClipboard: [ClipboardObject] = []
    /// 手寫辨識的結果或錯誤，顯示在浮動提示上。
    @State private var recognitionMessage: String?
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
    /// 模式徽章是不是正顯示著。切換模式時亮起，過幾秒自己淡掉。
    ///
    /// **不常駐**（工作項 S-62）：它原本一直蓋在畫布右上角，330pt 寬，
    /// 等於永遠有一塊紙面被說明文字佔著。模式本身在工具列的切換器上看得到，
    /// 徽章要說的是「這個模式下手勢會怎樣」—— 那是切換當下才需要的提示。
    @State private var modeBadgeVisible: Bool = false
    /// 用來取消上一次的淡出排程：連續切換兩次時，第一次的排程不該把
    /// 第二次剛亮起的徽章關掉。
    @State private var modeBadgeToken: Int = 0

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
    /// 常用墨色。**來源是核心的 `inkPalette()`**（工作項 S-63）。
    ///
    /// 這一組原本寫死在這個檔案裡，Android 端也寫死在 `InkToolbar`。
    /// S-62 把 Apple 這邊從八個純飽和原色換成六個「照真筆調」的墨色之後，
    /// Android 仍然是它自己那套 —— 同一支「藍筆」在兩台裝置上是兩個顏色。
    ///
    /// 筆畫顏色是**落盤的資料**：每一筆手寫都帶著 hex 存進筆記。所以它和
    /// 卡片底色一樣下沉到核心，兩邊不可能再分岔。
    // compactMap：`Color(hex:)` 是可失敗的初始化。core 給的 hex 一定合法
    // （核心有測試釘住格式），但用 `map` 會得到 `[Color?]` 而編不過。
    private let colorPalette: [Color] = inkPalette().compactMap { Color(hex: $0.hex) }

    /// 某個墨色的語系名稱，給無障礙標籤用。
    ///
    /// 用 hex 反查而不是靠索引：色票的順序將來可能會變，靠索引對的話
    /// 名字會悄悄錯位 —— 而那種錯誤只有開著 VoiceOver 才聽得出來。
    private func inkColorName(for color: Color) -> String {
        let target = inkPalette().first { Color(hex: $0.hex) == color }
        guard let key = target?.key else {
            return localizationManager.localized("custom_color")
        }
        return localizationManager.localized(key)
    }

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
            //
            // **並排與否由核心的 `layoutMetrics` 決定，不是一律並排。**
            //
            // 原本只要 `showStructureSidebar` 就並排，於是在 iPhone 上
            // 一條 280pt 的側欄配上 393pt 的螢幕 —— 畫布只剩 113pt，
            // 比工具列還窄。使用者打開結構欄是為了「翻到第 9 頁」，
            // 不是為了把畫布壓掉。塞不下就改用覆蓋（sheet）。
            GeometryReader { geo in
                let metrics = layoutMetrics(width: Float(geo.size.width))
                HStack(spacing: 0) {
                    if showStructureSidebar && metrics.sidebarIsInline {
                        notebookStructureSidebar
                            .frame(width: CGFloat(metrics.sidebarWidth))
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        ToolbarSeparator()
                    }

                    // 核心手寫/打字畫布區
                    canvasWorkArea
                }
                .sheet(isPresented: Binding(
                    get: { showStructureSidebar && !metrics.sidebarIsInline },
                    set: { if !$0 { showStructureSidebar = false } }
                )) {
                    resizableSheet { notebookStructureSidebar }
                }
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
            // 實體鍵盤快捷鍵（見 AppCommands.swift）。
            .onReceive(NotificationCenter.default.publisher(for: AppCommand.toggleEditorMode)) { _ in
                let next: EditorMode = (editorMode == .draw) ? .type : .draw
                saveCurrentPageDrawing()
                withAnimation(.easeInOut(duration: 0.18)) { editorMode = next }
                flashModeBadge()
            }
            .onReceive(NotificationCenter.default.publisher(for: AppCommand.selectTool)) { note in
                guard let index = note.object as? Int,
                      EditorToolType.allCases.indices.contains(index) else { return }
                selectedTool = EditorToolType.allCases[index]
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarBackButtonHidden(true)
        // Apple Pencil 雙擊要切回「最後用過的筆刷」（工作項 S-67），
        // 所以每次換工具都要把筆刷記下來。橡皮擦與套索不算筆刷。
        .onChange(of: selectedTool) { tool in
            if tool.isBrush { lastBrushTool = tool }
        }
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
            // 進到編輯器時也亮一次：第一次開的人要知道自己在哪個模式。
            flashModeBadge()
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
        .sheet(isPresented: $showMathCalculator) { resizableSheet {
            MathCalculatorSheet { exprText, cardImage in
                insertImageAttachment(cardImage)
            }
        } }
        .sheet(isPresented: $showShapeStudio) { resizableSheet {
            ShapeStudioView { shapes, connections in
                if notebook.shapeAttachments == nil { notebook.shapeAttachments = [] }
                if notebook.connectionAttachments == nil { notebook.connectionAttachments = [] }
                for shape in shapes {
                    var placed = shape
                    placed.pageIndex = currentPageIndex
                    notebook.shapeAttachments?.append(placed)
                }
                for connection in connections {
                    var placed = connection
                    placed.pageIndex = currentPageIndex
                    notebook.connectionAttachments?.append(placed)
                }
                store.updateNotebook(notebook)
            }
        } }
        .sheet(isPresented: $showTableStudio) { resizableSheet {
            TableStudioView { created in
                var table = created
                table.pageIndex = currentPageIndex
                if notebook.tableAttachments == nil { notebook.tableAttachments = [] }
                notebook.tableAttachments?.append(table)
                store.updateNotebook(notebook)
            }
        } }
        .sheet(item: $editingTable) { target in resizableSheet {
            TableStudioView(editing: target) { updated in
                guard let index = notebook.tableAttachments?
                    .firstIndex(where: { $0.id == updated.id }) else { return }
                // 位置原地保留：使用者只是改了裡面的內容。
                var table = updated
                table.x = notebook.tableAttachments?[index].x ?? table.x
                table.y = notebook.tableAttachments?[index].y ?? table.y
                notebook.tableAttachments?[index] = table
                store.updateNotebook(notebook)
            }
        } }
        .sheet(isPresented: $showChartStudio) { resizableSheet {
            ChartStudioView { chartSpec, chartImage in
                insertImageAttachment(chartImage, chartSpecJSON: chartSpec.encodedJSON())
            }
        } }
        // 重新編修既有的圖表。帶著原本的規格進去，使用者看到的是自己當初
        // 輸入的數字 —— 而不是一張只能刪掉重做的圖。
        .sheet(item: $editingChartAttachmentId) { identifier in resizableSheet {
            ChartStudioView(editing: identifier.spec) { updatedSpec, updatedImage in
                replaceChartAttachment(id: identifier.id, spec: updatedSpec, image: updatedImage)
            }
        } }
        .sheet(isPresented: $showNoteIntelligence) { resizableSheet {
            NoteIntelligenceSheet(
                // 走核心的 markdown 匯出：打字內容、表格、轉錄文字都在裡面，
                // 而且與匯出看到的是同一份文字 —— 另外湊一份「給模型看的」
                // 文字的話，摘要會講到使用者匯出時看不到的東西。
                text: notebook.plainText(),
                onInsert: { text in insertQuickTextSnippet(text) }
            )
        } }
        .sheet(isPresented: $showWordStudio) { resizableSheet {
            WordTextStudioView(attachment: $newTextDraft) { created in
                if notebook.textAttachments == nil {
                    notebook.textAttachments = []
                }
                notebook.textAttachments?.append(created)
                store.updateNotebook(notebook)
            }
        } }
        .sheet(isPresented: $showLinkPreviewSheet) { resizableSheet {
            LinkPreviewSheet { linkItem in
                if notebook.linkAttachments == nil {
                    notebook.linkAttachments = []
                }
                // 頁次要在這裡補。少了它，連結卡片一律落在第 1 頁 ——
                // 在第 5 頁按「插入連結」，畫面上什麼也不會出現。
                // 其他插入路徑（圖片、表格、形狀、3D）都有這一行，只有連結漏了。
                var placed = linkItem
                placed.pageIndex = currentPageIndex
                notebook.linkAttachments?.append(placed)
                store.updateNotebook(notebook)
            }
        } }
        .sheet(isPresented: $showProColorPicker) { resizableSheet {
            ProColorPickerSheet(selectedColor: $selectedColor)
        } }
        .sheet(isPresented: $show3DStudio) { resizableSheet {
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
        .sheet(isPresented: $showAssetLibrarySheet) { resizableSheet {
            AssetLibraryView { image, _ in
                insertImageAttachment(image)
            }
        } }
        .sheet(isPresented: $showAudioPicker) { resizableSheet {
            AudioInsertPickerSheet { recording in
                insertAudioAttachment(recording)
            }
        } }
        .sheet(isPresented: $showCollaborationSheet) { resizableSheet {
            CollaborationSheet(notebookId: notebook.id)
        } }
        .onReceive(collaborationManager.oplogReceived) { event in
            handleRemoteOplog(event)
        }
        .sheet(isPresented: $showThemeToolsSheet) { resizableSheet {
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
        .sheet(isPresented: $showMoveNotebookSheet) { resizableSheet {
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
            .accessibilityLabel(localizationManager.localized("home"))
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
            .accessibilityLabel(localizationManager.localized("structure_sidebar"))
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
                .accessibilityLabel(localizationManager.localized("add_page"))
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
            .accessibilityLabel(localizationManager.localized("ruler"))
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
                .accessibilityLabel(localizationManager.localized("undo"))
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
                .accessibilityLabel(localizationManager.localized("redo"))
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
            .accessibilityLabel(localizationManager.localized("asset_library"))
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

                // 表格、形狀、連結與錄音原本只在「更多」裡有。
                // 這個選單叫「插入物件」，卻插不了其中四種 ——
                // 使用者找不到就會以為功能不存在。
                Button {
                    showTableStudio = true
                } label: {
                    Label(localizationManager.localized("table_studio"), systemImage: "tablecells")
                }

                Button {
                    showShapeStudio = true
                } label: {
                    Label(localizationManager.localized("shape_studio"), systemImage: "square.on.circle")
                }

                Button {
                    showLinkPreviewSheet = true
                } label: {
                    Label(localizationManager.localized("insert_link"), systemImage: "link")
                }

                Button {
                    showAudioPicker = true
                } label: {
                    Label(localizationManager.localized("insert_audio"), systemImage: "waveform.badge.plus")
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

                // 摘要與待辦（工作項 S-20）。核心的 `llm_summarize` 早就在
                // FFI 上，缺的一直是這一顆按鈕。
                Button {
                    showNoteIntelligence = true
                } label: {
                    Label(
                        localizationManager.localized("ai_summary"),
                        systemImage: "sparkles")
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
            .accessibilityLabel(localizationManager.localized("insert_object"))
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
            .accessibilityLabel(localizationManager.localized("comment_pin"))
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
            .accessibilityLabel(localizationManager.localized("collaborate"))
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
            .accessibilityLabel(localizationManager.localized("export_print"))
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
        .accessibilityLabel(localizationManager.localized("home"))
        .help(localizationManager.localized("home"))

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

            // 整頁／連續切換。放在頁碼旁邊 —— 它改的就是這一組按鈕的意義：
            // 連續模式下上一頁／下一頁變成捲到那一頁，而不是換掉整個畫布。
            Button {
                pageDisplayModeRaw = (pageDisplayMode == .single
                    ? PageDisplayMode.continuous
                    : PageDisplayMode.single).rawValue
                // 切換前把當頁存好。整頁模式的筆跡在記憶體裡，不存就丟了。
                if pageDisplayMode == .continuous {
                    saveCurrentPageDrawing()
                } else {
                    loadCurrentPage()
                }
            } label: {
                Image(systemName: pageDisplayMode == .continuous
                    ? "rectangle.split.1x2"
                    : "doc.plaintext")
                    .foregroundColor(pageDisplayMode == .continuous ? .accentColor : .secondary)
            }
            .help(localizationManager.localized(
                pageDisplayMode == .continuous ? "page_mode_continuous" : "page_mode_single"))
            .accessibilityLabel(localizationManager.localized("page_mode"))
        }

        // ⋯ 更多（次要功能收在這裡）
        //
        // 緊湊模式下不再把每個功能都攤在工具列上 —— 視窗一窄就會互相擠掉。
        // 主要動作（首頁、模式、頁碼、錄音、匯出）留在列上，其餘收進選單，
        // 位置固定、不會因為視窗寬度而消失。
        Menu {
            Section {
                Button { showAssetLibrarySheet = true } label: { Label(localizationManager.localized("asset_library"), systemImage: "shippingbox.fill") }
                    Button { showAudioPicker = true } label: { Label(localizationManager.localized("insert_audio"), systemImage: "waveform.badge.plus") }
                Button { showPhotoPicker = true } label: { Label(localizationManager.localized("insert_image"), systemImage: "photo.badge.plus") }
                Button { showMathCalculator = true } label: { Label(localizationManager.localized("math_calc"), systemImage: "plus.forwardslash.minus") }
                Button { showChartStudio = true } label: { Label(localizationManager.localized("chart_studio"), systemImage: "chart.bar.xaxis") }
                Button { showTableStudio = true } label: { Label(localizationManager.localized("table_studio"), systemImage: "tablecells") }
                Button { showShapeStudio = true } label: { Label(localizationManager.localized("shape_studio"), systemImage: "square.on.circle") }
                Button { showLayerPanel.toggle() } label: { Label(localizationManager.localized("layers_panel"), systemImage: "square.3.layers.3d") }
                Button { show3DStudio = true } label: { Label(localizationManager.localized("insert_3d"), systemImage: "cube.transparent") }
                Button { showThemeToolsSheet = true } label: { Label(localizationManager.localized("theme_tools"), systemImage: "paintpalette.fill") }
            } header: {
                Text(localizationManager.localized("insert_object"))
            }

            Section {
                Button { withAnimation { showSketchRefineBar.toggle() } } label: { Label(localizationManager.localized("refine_sketch"), systemImage: "wand.and.stars") }
                Button { withAnimation { isPlacingCommentPin.toggle() } } label: { Label(localizationManager.localized("add_comment_pin"), systemImage: "text.bubble.fill") }
                Button { showCollaborationSheet = true } label: { Label(localizationManager.localized("collaborate"), systemImage: "person.2.fill") }
                Button { recognizeHandwritingOnCurrentPage() } label: {
                    Label(localizationManager.localized("recognize_handwriting"), systemImage: "text.viewfinder")
                }
                Button { showNoteIntelligence = true } label: {
                    Label(localizationManager.localized("ai_summary"), systemImage: "sparkles")
                }
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
        .accessibilityLabel(localizationManager.localized("more_tools"))
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
    private var canvasWorkArea: AnyView {
        // 兩條完全獨立的路。連續模式不碰整頁模式的任何一行 ——
        // 那一段綁著存檔、協同、掌拒與套索，是最沒本錢壞掉的地方。
        switch pageDisplayMode {
        case .single:     return AnyView(canvasWorkAreaContent)
        case .continuous: return AnyView(continuousPagesContent)
        }
    }

    /// 連續頁面模式的工作區。
    private var continuousPagesContent: some View {
        GeometryReader { outer in
            // 頁面是固定的 800 × 1132（P-01），視窗不是。縮到剛好放得下，
            // 不縮的話側欄一開，頁面右半邊就被切掉 —— 而使用者看不出那是
            // 「超出去」還是「畫布壞了」。
            //
            // 只縮不放：放大到超過原尺寸會讓筆跡變糊（圖層是先算繪再變換的）。
            let available = max(outer.size.width - 32, 1)
            let scale = min(1, available / PageGeometry.width)
            continuousPages(scale: scale)
        }
    }

    @ViewBuilder
    private func continuousPages(scale: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 20) {
                    ForEach(0..<max(1, notebook.pageCount), id: \.self) { index in
                        ContinuousPageView(
                            pageIndex: index,
                            notebookId: notebook.id,
                            template: notebook.template,
                            store: store,
                            selectedTool: selectedTool,
                            selectedColor: selectedColor,
                            strokeWidth: strokeWidth,
                            isRulerActive: isRulerActive,
                            editorMode: editorMode,
                            palmRejection: palmRejection,
                            isFocused: index == currentPageIndex,
                            objectLayer: { objectLayer(forPage: index) },
                            onDrawingChanged: { page, updated in
                                broadcastDrawingChange(page: page, drawing: updated)
                            },
                            onSelectionChanged: { hasLassoSelection = $0 },
                            onReachedPageBottom: { ensureNextPageExists() },
                            canvasRef: { canvasView = $0 },
                            onPenControl: applyPenControl,
                            onImageDropped: { page, providers, location in
                                acceptImageDrop(providers, at: location, page: page)
                            }
                        )
                        .scaleEffect(scale, anchor: .top)
                        // 縮放後的實際高度要讓出來，否則每一頁之間會留下
                        // (1 - scale) × 1132 的空白，看起來像頁與頁之間破了一個洞。
                        .frame(
                            width: PageGeometry.width * scale,
                            height: PageGeometry.height * scale
                        )
                        .id(index)
                        .background(
                            // 哪一頁在畫面中央，哪一頁就是焦點頁。
                            // 插入物件要落在使用者正在看的那一頁，不是他上次
                            // 按過上一頁／下一頁的那一頁。
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: PageFocusPreferenceKey.self,
                                    value: [index: geo.frame(in: .named(ContinuousPagesSpace.name)).midY]
                                )
                            }
                        )
                    }
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
            }
            .coordinateSpace(name: ContinuousPagesSpace.name)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { continuousViewportHeight = geo.size.height }
                        .onChange(of: geo.size.height) { h in continuousViewportHeight = h }
                }
            )
            .onPreferenceChange(PageFocusPreferenceKey.self) { mids in
                updateFocusedPage(from: mids)
            }
            .onAppear {
                // 從整頁模式切過來時，停在原本那一頁而不是回到第 1 頁。
                proxy.scrollTo(currentPageIndex, anchor: .top)
            }
        }
    }

    /// 連續模式下捲動容器的高度。焦點判定要拿它算中線。
    @State private var continuousViewportHeight: CGFloat = 800

    /// 把某一頁的筆跡變動廣播出去（協同）。
    ///
    /// 與整頁模式走同一組 oplog 事件與同一個 `page_index` —— 兩邊各發一種
    /// 事件的話，對方會在不同的模式下收到不同的東西。
    private func broadcastDrawingChange(page: Int, drawing: PKDrawing) {
        guard !isApplyingRemoteUpdate, isCollaborating else { return }
        let b64 = drawing.dataRepresentation().base64EncodedString()
        collaborationManager.broadcastOplog(
            kind: "drawing_replace",
            payload: ["page_index": page, "drawing_base64": b64]
        )
    }

    /// 取畫面中央最近的那一頁當焦點頁。
    private func updateFocusedPage(from mids: [Int: CGFloat]) {
        guard !mids.isEmpty else { return }
        // 視窗中央的 y。用固定的頁高估一個中線就夠 —— 這裡只要挑出
        // 「最接近中央的那一頁」，不需要精準的可見面積。
        let viewportCenter = continuousViewportHeight / 2
        let nearest = mids.min {
            abs($0.value - viewportCenter) < abs($1.value - viewportCenter)
        }
        guard let page = nearest?.key, page != currentPageIndex else { return }
        currentPageIndex = page
    }


    /// 某一頁的插入物件層（圖片、形狀、表格、文字、連結、3D、討論圖釘）。
    ///
    /// 抽成帶頁碼的方法，是為了讓連續頁面模式能對每一頁各叫一次 ——
    /// 原本這一整段寫死在畫布工作區裡、只認 `currentPageIndex`，
    /// 連續模式下就只有一頁有物件，其餘頁面是空的。
    ///
    /// **手寫模式下這一整層不攔截觸控。** 這些物件是疊在 PKCanvasView 之上的
    /// SwiftUI 視圖，預設會吃掉觸控 —— 於是使用者拿筆想在一張圖上圈重點，
    /// 筆畫根本到不了畫布，看起來就是「筆刷在物件上沒作用」。
    @ViewBuilder
    private func objectLayer(forPage page: Int) -> some View {
        ZStack {
                ForEach(notebook.attachments ?? []) { item in
                    if item.pageIndex == page {
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
                        .zIndex(ObjectStacking.zIndex(for: item.id, kind: .image, order: notebook.objectOrder(forPage: page)))
                    }
                }

                // 連接線先畫 —— 畫在形狀之上的話，線會壓過方塊的邊，看起來像穿幫。
                ForEach(notebook.connectionAttachments ?? []) { item in
                    if item.pageIndex == page,
                       let from = notebook.shapeAttachments?.first(where: { $0.id == item.fromShapeId }),
                       let to = notebook.shapeAttachments?.first(where: { $0.id == item.toShapeId }),
                       let geometry = ShapeGeometry.connection(item, from: from, to: to) {
                        ConnectionLineView(connection: item, geometry: geometry)
                    }
                }

                // 形狀。
                ForEach(notebook.shapeAttachments ?? []) { item in
                    if item.pageIndex == page {
                        ShapeAttachmentItemView(
                            shape: shapeBinding(for: item.id),
                            isSelected: selectedShapeIds.contains(item.id),
                            onSelect: { toggleShapeSelection(item.id) },
                            onMove: { delta in moveShapeGroup(item.id, by: delta) },
                            onDelete: {
                                notebook.shapeAttachments?.removeAll { $0.id == item.id }
                                // 連著的線也要跟著走 —— 留著的話會指向一個不存在的
                                // 形狀，畫面上是一條從空氣連出來的線。
                                notebook.connectionAttachments?.removeAll {
                                    $0.fromShapeId == item.id || $0.toShapeId == item.id
                                }
                                store.updateNotebook(notebook)
                            }
                        )
                        .zIndex(ObjectStacking.zIndex(for: item.id, kind: .shape, order: notebook.objectOrder(forPage: page)))
                    }
                }

                if showLayerPanel {
                    FloatingPanel(
                        title: localizationManager.localized("layers_panel"),
                        onClose: { showLayerPanel = false }
                    ) {
                        VStack(spacing: 10) {
                            // 跨型別的堆疊：圖片、文字、表格、圖表、3D、連結、
                            // 形狀全部在同一份順序裡。使用者要的「圖層上下排序」
                            // 指的是這個 —— 底下那個只認形狀。
                            CanvasStackPanel(
                                objects: pageStackableObjects,
                                order: Binding(
                                    get: {
                                        ObjectStacking.normalized(
                                            objects: pageStackableObjects,
                                            order: notebook.objectOrder(forPage: currentPageIndex)
                                        )
                                    },
                                    set: { updated in
                                        // **只寫這一頁。** 整個欄位覆蓋掉的話，在第 2 頁
                                        // 調一次順序，第 1 頁的順序就被清光了 ——
                                        // 那是 v3.8.0 (32) 已經出貨的 bug。
                                        notebook.setObjectOrder(updated, forPage: currentPageIndex)
                                        store.updateNotebook(notebook)
                                    }
                                ),
                                selection: $selectedShapeIds,
                                onAlign: { mode, ids in alignSelectedObjects(mode, ids: ids) }
                            )

                            // 形狀的群組操作留在原本的面板 —— 群組是形狀專屬的
                            // 概念（連接線要接得住），其餘型別沒有這回事。
                            if !pageShapes.isEmpty {
                                Divider()
                                ObjectLayerPanel(
                                    shapes: Binding(
                                        get: { pageShapes },
                                        set: { updated in replacePageShapes(with: updated) }
                                    ),
                                    selection: $selectedShapeIds,
                                    groupingOnly: true
                                )
                            }
                        }
                    }
                    .padding(.top, 24)
                    .padding(.trailing, 24)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                }

                // 表格。與文字方塊一樣疊在墨跡之上，手寫模式下不攔截觸控。
                ForEach(notebook.tableAttachments ?? []) { item in
                    if item.pageIndex == page {
                        TableAttachmentItemView(
                            table: tableBinding(for: item.id),
                            onEdit: { editingTable = item },
                            onDelete: {
                                notebook.tableAttachments?.removeAll { $0.id == item.id }
                                store.updateNotebook(notebook)
                            }
                        )
                        .zIndex(ObjectStacking.zIndex(for: item.id, kind: .table, order: notebook.objectOrder(forPage: page)))
                    }
                }

                // 🌟 筆記內嵌 Word 級文字方塊（支援段落對齊、特殊符號與便利貼卡片底色）
                ForEach(notebook.textAttachments ?? []) { item in
                    if item.pageIndex == page {
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
                        .zIndex(ObjectStacking.zIndex(for: item.id, kind: .text, order: notebook.objectOrder(forPage: page)))
                    }
                }

                // 🌟 筆記內嵌網址 Rich Link 預覽卡片（支援點擊跳轉瀏覽器與自由平移）
                ForEach(notebook.linkAttachments ?? []) { item in
                    if item.pageIndex == page {
                        LinkAttachmentItemView(
                            linkItem: binding(forLinkId: item.id),
                            onDelete: {
                                notebook.linkAttachments?.removeAll { $0.id == item.id }
                                store.updateNotebook(notebook)
                            }
                        )
                        .zIndex(ObjectStacking.zIndex(for: item.id, kind: .link, order: notebook.objectOrder(forPage: page)))
                    }
                }

                // 🌟 頁面上的錄音卡片（可播放、可搬移、可縮放、可旋轉、可改名）
                ForEach(notebook.audioAttachments ?? []) { item in
                    if item.pageIndex == page {
                        AudioAttachmentItemView(
                            item: binding(forAudioId: item.id),
                            onDelete: {
                                notebook.audioAttachments?.removeAll { $0.id == item.id }
                                store.updateNotebook(notebook)
                            }
                        )
                        .zIndex(ObjectStacking.zIndex(for: item.id, kind: .audio, order: notebook.objectOrder(forPage: page)))
                    }
                }

                // 🌟 筆記內嵌 3D 幾何模型展示層（支援 360° 空間旋轉、9大材質 PBR 物理反射、縮放與文字標題）
                ForEach(notebook.model3DAttachments ?? []) { item in
                    if item.pageIndex == page {
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
                        .zIndex(ObjectStacking.zIndex(for: item.id, kind: .model3D, order: notebook.objectOrder(forPage: page)))
                    }
                }

                // 🌟 筆記內嵌討論圖釘展示層（支援多方訊息留言串、已解決標記與即時推播）
                ForEach(notebook.commentPins ?? []) { pin in
                    if pin.pageIndex == page {
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
                        .zIndex(ObjectStacking.zIndex(for: pin.id, kind: .pin, order: notebook.objectOrder(forPage: page)))
                    }
                }

        }
        .allowsHitTesting(editorMode != .draw)
    }

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
                },
                palmRejection: palmRejection,
                onRetractStrokes: { landedAt in
                    // 手掌先碰、筆才落下 —— 把手掌剛畫出來的那一段收回。
                    let cleaned = PalmRejectionCoordinator.retracting(
                        currentDrawing, landedAt: landedAt)
                    guard cleaned.strokes.count != currentDrawing.strokes.count else { return }
                    currentDrawing = cleaned
                    canvasView?.drawing = cleaned
                    saveCurrentPageDrawing()
                },
                onPenControl: applyPenControl
            )
            // 從別的 App 把圖拖進來（工作項 S-68）。
            //
            // 掛在畫布上而不是整個編輯器：落點要能換算成頁面座標，
            // 掛在外層的話拖到工具列上也會插進去，而且位置會偏掉。
            .onDrop(of: [.image], isTargeted: $isCanvasDropTargeted) { providers, location in
                acceptImageDrop(providers, at: location, page: currentPageIndex)
            }
            .overlay { canvasDropHighlight(isCanvasDropTargeted) }
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { updateCanvasContentWidth(geo.size.width) }
                        .onChange(of: geo.size.width) { newWidth in
                            updateCanvasContentWidth(newWidth)
                        }
                }
            )

            // 🌟 打字模式畫布互動層：**點兩下**空白處才新增文字方塊。
            //
            // 原本是單擊就新增，而且這一層鋪滿整個畫布、吃掉所有觸控 ——
            // 於是打字模式下想捲動畫布、想點選既有的方塊或圖片，得到的
            // 都是一個新的空方塊。使用者最常做的兩件事各生一個垃圾物件。
            //
            // 單擊留給底下的畫布與物件（捲動、選取），新增改用點兩下：
            // 仍然能指定位置，而且不會跟任何既有手勢搶。
            if editorMode == .type {
                // 這一層**不攔截任何觸控**。
                //
                // 舊寫法是鋪一層 Color.black.opacity(0.001) 加 onTapGesture 接手勢。
                // 那層只要可命中，單擊就到不了底下 —— 改成點兩下也一樣，單擊
                // 依然被它吃掉，結果是「點了完全沒反應」，比原本更糟。
                // 所以必須 allowsHitTesting(false)，新增的手勢掛在下面那個
                // simultaneousGesture 上，與畫布的捲動、物件的選取並存。
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)

            }

            // 模式徽章。
            //
            // **兩個模式都要顯示。** 只在打字模式掛一條提示的話，使用者切回
            // 手寫時畫面上沒有任何差別 —— 而兩個模式下「同一個手勢會發生
            // 什麼事」完全不同（筆會不會畫線、物件拖不拖得動）。看不出自己
            // 在哪個模式，就只能一直試。
            modeBadge
                .padding(.top, DS.Space.s)
                .padding(.trailing, DS.Space.m)
                .opacity(modeBadgeVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.22), value: modeBadgeVisible)

            // 🌟 插入物件層（圖片、文字方塊、3D 模型、連結卡片、討論圖釘）
            //
            // **手寫模式下這一整層不攔截觸控。**
            //
            // 這些物件是疊在 PKCanvasView 之上的 SwiftUI 視圖，預設會吃掉觸控 ——
            // 於是使用者拿筆想在一張圖上圈重點，筆畫根本到不了畫布，看起來就是
            // 「筆刷在物件上沒作用」。在一個手寫筆記 App 裡，那是最該能做的事之一。
            //
            // 代價是手寫模式下不能直接拖動物件 —— 要搬動或編輯就切到打字模式。
            // 這個取捨是刻意的：手寫模式的主角是筆，物件操作有它自己的模式。
            objectLayer(forPage: currentPageIndex)

            // 框選層。只有在框選模式下才存在 —— 平常掛一層可命中的
            // 透明視圖，底下的物件就全部點不到了。
            if isMarqueeActive && editorMode == .type {
                marqueeLayer
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
                    .accessibilityLabel(localizationManager.localized("add_next_page"))
                    .help(localizationManager.localized("add_next_page"))

                    // 「延長本頁」已移除：頁面高度固定（PageGeometry），
                    // 寫到頁尾會自動準備下一頁。
                }
                .padding(14)
            }

            // 🌟 線上多人即時彩色游標與筆尖浮層
            RemoteCursorsOverlay()

            // 🌟 文字編修浮動面板
            //
            // 以前是 modal sheet，蓋住整個畫布 —— 要調一個文字方塊的排版，
            // 卻看不到那個文字方塊。與圖片美化面板同樣的問題、同樣的解法：
            // 浮在畫布上、標題列可以拖到一旁，改動直接反映在物件上。
            if let id = editingTextId {
                FloatingPanel(
                    title: localizationManager.localized("text_studio"),
                    onClose: { editingTextId = nil }
                ) {
                    WordTextStudioView(
                        attachment: binding(forTextId: id),
                        presentation: .inlinePanel
                    ) { updated in
                        if let idx = notebook.textAttachments?.firstIndex(where: { $0.id == id }) {
                            notebook.textAttachments?[idx] = updated
                            store.updateNotebook(notebook)
                        }
                    }
                }
                .padding(.top, 24)
                .padding(.trailing, 24)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }

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
                    VStack(spacing: 10) {
                        // 這張圖如果是數字製圖，先給重新編修的入口 ——
                        // 濾鏡與邊框改不了圖表裡的數字。
                        if let spec = notebook.attachments?
                            .first(where: { $0.id == id })?.chartSpec {
                            Button {
                                editingChartAttachmentId = ChartEditTarget(id: id, spec: spec)
                            } label: {
                                Label(localizationManager.localized("chart_edit"),
                                      systemImage: "chart.bar.xaxis")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }

                        ImageEditControls(attachment: binding(for: id)) {
                            notebook.attachments?.removeAll { $0.id == id }
                            store.updateNotebook(notebook)
                            editingAttachmentId = nil
                        }
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
        // 打字模式下點兩下空白處＝在該處新增文字方塊。
        //
        // 用 simultaneousGesture 而不是 onTapGesture：後者會把單擊也一起
        // 接管，於是捲動與選取又回到原本壞掉的狀態。simultaneous 讓這個
        // 手勢與底下的畫布、物件各自獨立辨識 —— 單擊照常穿透。
        .simultaneousGesture(
            editorMode == .type
                ? SpatialTapGesture(count: 2, coordinateSpace: .named(CanvasCoordinateSpace.name))
                    .onEnded { value in
                        insertTextBox(at: value.location)
                    }
                : nil
        )
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
        // help 是補充說明（hint），標籤要用按鈕本身的名字。
        .accessibilityLabel(localizationManager.localized(titleKey))
        .help(localizationManager.localized(hintKey))
    }

    /// 版本標示（v2.2.0 這種）。點一下可複製，回報問題時直接貼上。
    // 版本號**不放在編輯器工具列**（工作項 S-62）。
    //
    // 原本這裡有一個等寬字體的 `v3.9.0` 標籤，理由是「Mac 上跑的 iOS 版由
    // 系統決定視窗標題，畫在自己的工具列裡最可靠」。那個理由本身沒錯，
    // 但結論放錯地方了：使用者每天盯著的編輯畫面不該常駐一個版本號 ——
    // 那是開發用的東西出現在出貨的介面上。
    //
    // 版本號在兩個地方仍然看得到：首頁頁尾，以及快捷選單裡的系統診斷。

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
            // 切換當下把提示亮出來，幾秒後自己淡掉。
            flashModeBadge()
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
        // compact 時這顆只有圖示，沒有文字可念。
        .accessibilityLabel(localizationManager.localized(titleKey))
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
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
                        .accessibilityLabel(localizationManager.localized("add_page"))
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
                        .accessibilityLabel(localizationManager.localized("new_subfolder"))
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
                .accessibilityLabel(localizationManager.localized("edit_root_folder"))
                .help(localizationManager.localized("edit_root_folder"))
            }
            .padding(8)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(8)
            .padding(.horizontal, 10)
            .padding(.top, 8)

            // 「新增子資料夾」已移除：側欄標題列右上角那顆 folder.badge.plus
            // 做的是同一件事。同一個動作給兩個入口，只是讓側欄變窄、讓使用者
            // 多想一秒「這兩個一樣嗎」。

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

            // 目錄統計（工作項 S-62）。
            //
            // 原本是「Folders: 0」與「All Files: 2」分列左右兩端 ——
            // `標籤: 數字` 是程式在印偵錯訊息的格式，不是給人看的句子。
            // 改成一句自然語言，並靠左排（貼在兩端會讓人以為是兩個欄位）。
            Text(
                String(
                    format: localizationManager.localized("structure_summary"),
                    String(store.folders.count), String(store.notebooks.count))
            )
            .font(DS.Font.caption)
            .foregroundStyle(DS.Color.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Space.s)
            .padding(.vertical, DS.Space.xs)
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
                // 筆刷群組。橡皮擦與套索另成一組（見 EditorToolType.isBrush）。
                ForEach(EditorToolType.allCases.filter(\.isBrush)) { tool in
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
                    // 工具列在窄螢幕上不顯示文字標籤（showToolLabels = false），
                    // 那時整排都是純圖示。
                    .accessibilityLabel(localizationManager.localized(tool.localizationKey))
                    .accessibilityAddTraits(selectedTool == tool ? [.isSelected] : [])
                }

                ToolbarSeparator()
                    .frame(height: 24)

                // 擦除與選取。與筆刷分開，因為它們不沾墨，也不吃顏色與粗細。
                ForEach(EditorToolType.allCases.filter { !$0.isBrush }) { tool in
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
                        .padding(.horizontal, DS.Space.xs)
                        .padding(.vertical, 5)
                        .background(selectedTool == tool ? DS.Color.accentSoft : Color.clear)
                        .cornerRadius(DS.Radius.s)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localizationManager.localized(tool.localizationKey))
                    .accessibilityAddTraits(selectedTool == tool ? [.isSelected] : [])
                }

                ToolbarSeparator()
                    .frame(height: 24)

                // 筆刷粗細：四個預設點 + 可拖曳的滑桿
                //
                // 點點給的是「常用的四種」，一下就選到；滑桿給的是「就是要
                // 這個粗細」。只有點點的話，想要 5pt 的人永遠只能在 4 與 8
                // 之間挑一個。游標的筆頭大小跟著這個值走。
                HStack(spacing: 6) {
                    ForEach([2.0, 4.0, 8.0, 14.0], id: \.self) { w in
                        Button {
                            strokeWidth = CGFloat(w)
                        } label: {
                            Circle()
                                .fill(abs(strokeWidth - CGFloat(w)) < 0.01 ? Color.accentColor : Color.secondary.opacity(0.5))
                                .frame(width: max(6, CGFloat(w)), height: max(6, CGFloat(w)))
                                .padding(4)
                                .background(abs(strokeWidth - CGFloat(w)) < 0.01 ? Color.accentColor.opacity(0.15) : Color.clear)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("\(localizationManager.localized("stroke_width")) \(Int(w))pt")
                    }

                    StrokeWidthSlider(
                        width: $strokeWidth,
                        tool: selectedTool,
                        color: selectedColor
                    )
                }

                ToolbarSeparator()
                    .frame(height: 24)

                // 色彩選擇盤
                HStack(spacing: DS.Space.xs) {
                    ForEach(colorPalette, id: \.self) { color in
                        Button {
                            selectedColor = color
                        } label: {
                            // 色票畫在「紙」上（工作項 S-64）。
                            //
                            // 墨黑是 #1C1F24，深色模式的卡片底是 #1C1C1E ——
                            // 兩者差不到一個色階，那顆色票在深色模式下
                            // **整個看不見**。
                            //
                            // 襯一張紙不只是為了看得見：墨色本來就是「畫在
                            // 紙上的顏色」，襯在深色介面上看到的根本不是它
                            // 在頁面上的樣子。
                            Circle()
                                .fill(color)
                                .frame(width: DS.Icon.small, height: DS.Icon.small)
                                .padding(3)
                                .background(Circle().fill(Color.white))
                                .overlay(
                                    Circle().stroke(DS.Color.hairline, lineWidth: 0.5)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(
                                            selectedColor == color ? DS.Color.accent : .clear,
                                            lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                        // 純色圓點沒有任何文字 —— VoiceOver 念出來只會是
                        // 「按鈕」，使用者無從知道自己選的是哪一支筆。
                        .accessibilityLabel(inkColorName(for: color))
                        .accessibilityAddTraits(selectedColor == color ? [.isSelected] : [])
                    }

                    // 任意色只留一個入口（工作項 S-62）。
                    //
                    // 這裡原本同時有系統的 `ColorPicker`（那顆彩虹圈）**與**
                    // 專業調色盤按鈕。專業調色盤支援 RGB／HSB／HEX 與設計師
                    // 色盤，是彩虹圈的超集 —— 兩個並排只是讓人不知道該按哪一個。
                    Button {
                        showProColorPicker = true
                    } label: {
                        Image(systemName: "paintpalette")
                            .font(.system(size: DS.Icon.small, weight: .medium))
                            .foregroundStyle(DS.Color.secondaryText)
                            .frame(width: DS.Icon.medium, height: DS.Icon.medium)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localizationManager.localized("pro_color"))
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
                        .accessibilityLabel(localizationManager.localized("delete_selected"))
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
                Button { showTableStudio = true } label: { Label(localizationManager.localized("table_studio"), systemImage: "tablecells") }
                Button { showShapeStudio = true } label: { Label(localizationManager.localized("shape_studio"), systemImage: "square.on.circle") }
                Button { showLayerPanel.toggle() } label: { Label(localizationManager.localized("layers_panel"), systemImage: "square.3.layers.3d") }
                    Button { show3DStudio = true } label: { Label(localizationManager.localized("insert_3d"), systemImage: "cube.transparent") }
                    Button { showAssetLibrarySheet = true } label: { Label(localizationManager.localized("asset_library"), systemImage: "shippingbox.fill") }
                    Button { showAudioPicker = true } label: { Label(localizationManager.localized("insert_audio"), systemImage: "waveform.badge.plus") }
                    Divider()
                    Button { withAnimation { showSketchRefineBar.toggle() } } label: { Label(localizationManager.localized("refine_sketch"), systemImage: "wand.and.stars") }
                    Button { showThemeToolsSheet = true } label: { Label(localizationManager.localized("theme_tools"), systemImage: "paintpalette.fill") }
                    Button { showNoteIntelligence = true } label: { Label(localizationManager.localized("ai_summary"), systemImage: "sparkles") }
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
                .accessibilityLabel(localizationManager.localized("more_tools"))
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
                    .accessibilityLabel(localizationManager.localized("undo"))
                    .help(localizationManager.localized("undo"))

                    Button {
                        canvasView?.undoManager?.redo()
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel(localizationManager.localized("redo"))
                    .help(localizationManager.localized("redo"))

                    // 「清空整頁」與復原／重做之間要有分隔（工作項 S-62）。
                    //
                    // 三顆按鈕原本等距排在一起，而其中一顆會**清掉整頁**。
                    // 手指在 iPad 上點復原點偏一格，清掉的東西雖然還原得回來，
                    // 但那一瞬間的驚嚇是真的。分隔線把「可逆」與「破壞性」
                    // 分成兩組，這是工具列最基本的一件事。
                    ToolbarSeparator()
                        .frame(height: 20)
                        .padding(.horizontal, DS.Space.xxs)

                    Button {
                        showClearConfirmAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .foregroundStyle(DS.Color.destructive)
                    }
                    .accessibilityLabel(localizationManager.localized("clear_page"))
                    .help(localizationManager.localized("clear_page"))
                }
    }

    // MARK: - 🌟 實體鍵盤打字與排版工具列
    /// 型別邊界：SwiftUI 會把整棵子樹的型別編進 body 的 mangled 名稱，
    /// 名稱一長，裝置端（主執行緒只有 1MB 堆疊）解析時就會遞迴爆堆疊。
    private var typingToolbar: AnyView { AnyView(typingToolbarContent) }

    private var typingToolbarContent: some View {
        VStack(spacing: 0) {
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

            // 框選的動作列。掛在工具列這一層而不是畫布上 ——
            // 跟著畫布捲的話，選了下半頁的東西就得捲回去才按得到刪除。
            if isMarqueeActive {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    marqueeToolbar
                }
            }
        }
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
                .accessibilityLabel(localizationManager.localized("word_studio"))
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

                // 框選。與「插入」並列而不是收進「更多」——
                // 它是一個**模式**，使用者要看得到自己現在在不在裡面。
                Button {
                    isMarqueeActive.toggle()
                    if !isMarqueeActive { selectedObjectIds = [] }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.dashed")
                            .font(.system(size: 14))
                        Text(localizationManager.localized("marquee_select"))
                            .font(.system(size: 11))
                    }
                    .foregroundColor(isMarqueeActive ? .white : .primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(isMarqueeActive ? Color.accentColor : Color.secondary.opacity(0.12))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizationManager.localized("marquee_hint"))
                .help(localizationManager.localized("marquee_hint"))

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
                .accessibilityLabel(localizationManager.localized("insert_link"))
                .help(localizationManager.localized("insert_link"))

                // ⋯ 更多：次要插入工具
                Menu {
                    Button { showPhotoPicker = true } label: { Label(localizationManager.localized("insert_image"), systemImage: "photo.badge.plus") }
                    Button { showMathCalculator = true } label: { Label(localizationManager.localized("math_calc"), systemImage: "plus.forwardslash.minus") }
                    Button { showChartStudio = true } label: { Label(localizationManager.localized("chart_studio"), systemImage: "chart.bar.xaxis") }
                Button { showTableStudio = true } label: { Label(localizationManager.localized("table_studio"), systemImage: "tablecells") }
                Button { showShapeStudio = true } label: { Label(localizationManager.localized("shape_studio"), systemImage: "square.on.circle") }
                Button { showLayerPanel.toggle() } label: { Label(localizationManager.localized("layers_panel"), systemImage: "square.3.layers.3d") }
                    Button { show3DStudio = true } label: { Label(localizationManager.localized("insert_3d"), systemImage: "cube.transparent") }
                    Button { showAssetLibrarySheet = true } label: { Label(localizationManager.localized("asset_library"), systemImage: "shippingbox.fill") }
                    Button { showAudioPicker = true } label: { Label(localizationManager.localized("insert_audio"), systemImage: "waveform.badge.plus") }
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
                .accessibilityLabel(localizationManager.localized("more_tools"))
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
                    .accessibilityLabel(localizationManager.localized("undo"))
                    .help(localizationManager.localized("undo"))

                    Button {
                        canvasView?.undoManager?.redo()
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel(localizationManager.localized("redo"))
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
            .accessibilityLabel(localizationManager.localized("open_folder"))
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
            .accessibilityLabel(localizationManager.localized("copy_selected_hint"))
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
            .accessibilityLabel(localizationManager.localized("duplicate_selected_hint"))
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
            .accessibilityLabel(localizationManager.localized("paste_strokes_hint"))
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

    /// 辨識目前這一頁的手寫，結果存進筆記本供搜尋。
    ///
    /// **不會改動任何一筆畫。** 辨識只是讓手寫找得到 —— 手寫筆記的價值
    /// 就在那個手寫。分組規則走核心（與 Android 同一份），辨識引擎是 Vision。
    private func recognizeHandwritingOnCurrentPage() {
        let drawing = currentDrawing
        guard !drawing.strokes.isEmpty else {
            recognitionMessage = localizationManager.localized("no_strokes")
            return
        }
        recognitionMessage = localizationManager.localized("recognizing")
        // Vision 吃 BCP-47；AppLanguage 的 rawValue 正好就是（zh-Hant / ja / …）。
        let language = localizationManager.currentLanguage.rawValue
        let page = currentPageIndex

        Task { @MainActor in
            switch await HandwritingRecognizer.recognize(drawing: drawing, languageTag: language) {
            case .success(let groups):
                let text = groups.map(\.text).joined(separator: " ")
                guard !text.isEmpty else {
                    recognitionMessage = localizationManager.localized("no_recognition_result")
                    return
                }
                var map = notebook.recognizedText ?? [:]
                map[String(page)] = text
                notebook.recognizedText = map
                store.updateNotebook(notebook)
                recognitionMessage = text
            case .failure(let error):
                // 逐項分開 —— 「辨識失敗」四個字幫不了使用者。
                recognitionMessage = switch error {
                case .unsupported(let detail): detail
                case .noModel(let tag): String(
                    format: localizationManager.localized("hwr_no_model"), tag)
                case .recognitionFailed(let detail): detail
                }
            }
        }
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

    /// 把對方傳來的筆跡落到本機。
    ///
    /// # 為什麼不是「有畫布才做」
    ///
    /// 這裡原本整段包在 `if let canvas = canvasView` 裡：畫布還沒建立的那
    /// 一瞬間（剛進編輯器、剛換頁、連續模式下那一頁還沒捲到），對方的筆畫
    /// **連存都不會存** —— 訊息收到了、解密成功了、然後靜靜地被丟掉。
    /// 實機上看到的就是「兩台都顯示已連線，畫下去對面什麼都沒有」，
    /// 而且完全沒有任何錯誤可查。
    ///
    /// 落盤與畫面是兩件事：先無條件落盤，畫布有沒有在都不影響資料。
    private func applyRemoteDrawing(page: Int, remote: PKDrawing, replace: Bool) {
        let isCurrent = (page == currentPageIndex)
        let base: PKDrawing = isCurrent
            ? (canvasView?.drawing ?? currentDrawing)
            : store.loadDrawing(notebookId: notebook.id, pageIndex: page)
        let merged = replace ? remote : base.appending(remote)

        store.saveDrawing(notebookId: notebook.id, pageIndex: page, drawing: merged)
        guard isCurrent else { return }

        isApplyingRemoteUpdate = true
        currentDrawing = merged
        canvasView?.drawing = merged
        lastStrokeCount = merged.strokes.count
        DispatchQueue.main.async {
            isApplyingRemoteUpdate = false
        }
    }

    /// 處理協同遠端廣播操作（CRDT Oplog 合併）
    private func handleRemoteOplog(_ event: RemoteOplogEvent) {
        switch event.kind {
        case "stroke_delta":
            guard let pageIdx = event.payload["page_index"] as? Int,
                  let b64 = event.payload["drawing_base64"] as? String,
                  let data = Data(base64Encoded: b64),
                  let remoteDrawing = try? PKDrawing(data: data) else { return }
            applyRemoteDrawing(page: pageIdx, remote: remoteDrawing, replace: false)

        case "drawing_replace":
            guard let pageIdx = event.payload["page_index"] as? Int,
                  let b64 = event.payload["drawing_base64"] as? String,
                  let data = Data(base64Encoded: b64),
                  let remoteDrawing = try? PKDrawing(data: data) else { return }
            applyRemoteDrawing(page: pageIdx, remote: remoteDrawing, replace: true)

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

    /// 接住拖進畫布的圖片（工作項 S-68）。
    ///
    /// 回傳值是**同步**的「我要不要接這一批」—— 圖片是非同步載進來的，
    /// 等載完再回答的話系統早就把拖放取消掉了。所以這裡看的是「有沒有
    /// 任何一個來源給得出圖」，真正的插入在回呼裡做。
    private func acceptImageDrop(
        _ providers: [NSItemProvider], at location: CGPoint, page: Int
    ) -> Bool {
        guard providers.contains(where: { $0.canLoadObject(ofClass: UIImage.self) }) else {
            return false
        }
        ImageDropLoader.firstImage(from: providers) { image in
            guard let image else { return }
            insertImageAttachment(image, at: location, page: page)
            // 插進來之後切到打字模式：手寫模式下物件不吃觸控，使用者剛拖
            // 進來的圖會拖不動，看起來像插壞了。Android 端也是這樣做。
            editorMode = .type
        }
        return true
    }

    /// 拖放時的落點提示。
    @ViewBuilder
    private func canvasDropHighlight(_ targeted: Bool) -> some View {
        if targeted {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                .background(Color.accentColor.opacity(0.08))
                .allowsHitTesting(false)
        }
    }

    /// 筆身上的動作（雙擊、擠壓、側鍵、反向筆頭）發生了。
    ///
    /// **規則不在這裡。** 「這個動作要做什麼」整張表在核心
    /// （`padnote-input::pen`），與 Android 共用同一份 —— 各寫一套的話，
    /// 同一支筆在兩台裝置上行為會不同。這裡只負責把核心回的結果換成
    /// 這個 App 的工具。
    ///
    /// 打字模式下不理會：那時候畫布根本不收筆畫，換工具只會讓使用者切回
    /// 手寫時發現筆莫名其妙變了。
    private func applyPenControl(_ control: FfiPenControl, pressed: Bool) {
        guard editorMode == .draw else { return }

        let settings = PenHardwareSettings.shared
        // 按著的控制項（側鍵、反向筆頭）放開時，只還原**我們自己切過去的
        // 那一次**。使用者自己在工具列上選了橡皮擦、然後碰了一下側鍵，
        // 放開時把他的橡皮擦換掉是錯的。
        if settings.isMomentary(control) {
            if pressed {
                penHeldTool = selectedTool
            } else if penHeldTool == nil {
                return
            }
        }

        let outcome = settings.controls.outcome(
            control: control,
            pressed: pressed,
            erasing: selectedTool == .eraser,
            lassoing: selectedTool == .lasso)

        switch outcome {
        case .nothing:
            return
        case .useEraser:
            selectedTool = .eraser
        case .useLastBrush:
            // 放開時回到按下去之前那支，而不是「最後用過的筆刷」——
            // 兩者通常一樣，但使用者若在按著側鍵的期間又換過筆，
            // 他要的是回到他剛剛選的那一支。
            selectedTool = penHeldTool ?? lastBrushTool
        case .useLasso:
            selectedTool = .lasso
        case .showInkAttributes:
            showProColorPicker = true
        case .undo:
            canvasView?.undoManager?.undo()
        case .redo:
            canvasView?.undoManager?.redo()
        case .toggleRuler:
            isRulerActive.toggle()
        }

        if settings.isMomentary(control) && !pressed {
            penHeldTool = nil
        }
        // 筆身的動作是看不見的 —— 使用者當下正看著筆尖，一下短回饋讓他
        // 知道剛剛那下有收到，不必抬頭確認工具列。
        PenHaptics.penControlFired(in: canvasView)
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

    /// 匯出 PDF。
    ///
    /// 走核心的匯出器，因為它同時輸出**向量筆畫與標準 `/Ink` 標註** ——
    /// 在 Goodnotes / Notability / PDF Expert 打開後可以繼續編輯那些筆畫。
    /// App 原本的做法是把整頁算繪成點陣圖，那樣只能「在上面加註」，
    /// 我們的筆畫本身不是物件。
    ///
    /// 核心拒絕這份資料時退回原本的點陣匯出 —— 拿得到一份看得見內容的 PDF，
    /// 比拿到一個錯誤訊息好。
    private func buildNotebookPdf(scale: CGFloat = 2.0) -> Data {
        saveCurrentPageDrawing()

        let drawings = (0..<max(notebook.pageCount, 1)).map {
            store.loadDrawing(notebookId: notebook.id, pageIndex: $0)
        }
        var images: [String: Data] = [:]
        for attachment in notebook.attachments ?? [] {
            if let image = store.loadAttachmentImage(fileName: attachment.fileName),
               let png = image.pngData() {
                images[attachment.fileName] = png
            }
        }

        if let data = try? NotebookPackageBridge.exportPdf(
            document: notebook, drawings: drawings, imageData: images,
            deviceId: NotebookMigration.deviceId
        ), !data.isEmpty {
            return data
        }

        return buildRasterPdf(scale: scale)
    }

    /// 點陣匯出（備援）。與畫布逐像素一致，但筆畫不是可編輯的標註。
    private func buildRasterPdf(scale: CGFloat = 2.0) -> Data {
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

    /// 在畫布的指定位置新增一個空文字方塊並直接進入編輯。
    ///
    /// 位置往左上各退一點，讓方塊的**中心**落在手指點的地方 ——
    /// 以點擊處當左上角的話，方塊會整個長在手指的右下方。
    private func insertTextBox(at location: CGPoint) {
        let draft = NoteTextAttachment(
            id: UUID().uuidString,
            pageIndex: currentPageIndex,
            text: "",
            x: max(20, location.x - 130),
            y: max(20, location.y - 40)
        )
        if notebook.textAttachments == nil {
            notebook.textAttachments = []
        }
        notebook.textAttachments?.append(draft)
        store.updateNotebook(notebook)
        editingTextId = draft.id
    }

    private func insertQuickTextSnippet(_ text: String) {
        // 尺寸配合內容。高度現在是權威值（見 format-spec §6.2），
        // 160 × 60 配 24pt 粗體裝不下「↔ 120.0 ±0.05 mm」這種標註，
        // 會被裁掉 —— 而使用者看不出那是尺寸問題還是字沒插進去。
        let newBox = NoteTextAttachment(
            pageIndex: currentPageIndex,
            text: text,
            fontSize: 20,
            isBold: true,
            x: 100,
            y: 120,
            width: 260,
            height: 64
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
    /// 把一張圖插到頁面上。
    ///
    /// - Parameters:
    ///   - at: 拖放的落點（頁面座標）。`nil` 表示從選單插入 —— 沿用固定位置。
    ///   - page: 落在哪一頁。連續模式下拖到哪一頁就是哪一頁，`nil` 用焦點頁。
    private func insertImageAttachment(
        _ image: UIImage,
        chartSpecJSON: String? = nil,
        at dropPoint: CGPoint? = nil,
        page: Int? = nil
    ) {
        guard let fileName = store.saveAttachmentImage(image) else { return }
        let aspect = image.size.width / max(1, image.size.height)
        let placed = dropPoint.map {
            ImageDropPlacement.frame(
                dropPoint: $0,
                imageSize: image.size,
                pageSize: CGSize(width: PageGeometry.width, height: PageGeometry.height))
        }
        let w: CGFloat = placed?.width ?? 280
        let h: CGFloat = placed?.height ?? max(80, 280 / aspect)
        let newAttachment = NoteImageAttachment(
            fileName: fileName,
            pageIndex: page ?? currentPageIndex,
            x: placed?.minX ?? 80,
            y: placed?.minY ?? 120,
            width: w,
            height: h,
            rotationDegrees: 0,
            cornerRadius: 8,
            hasShadow: true,
            hasBorder: false,
            filterStyle: .original,
            chartSpecJSON: chartSpecJSON
        )
        if notebook.attachments == nil {
            notebook.attachments = []
        }
        notebook.attachments?.append(newAttachment)
        store.updateNotebook(notebook)
    }

    /// 把一段既有的錄音插到目前這一頁。
    ///
    /// 位置逐張往右下錯開。全部疊在同一點的話，插第二張時使用者會以為沒插進去。
    private func insertAudioAttachment(_ recording: AudioRecordingRecord) {
        let existing = (notebook.audioAttachments ?? []).filter { $0.pageIndex == currentPageIndex }.count
        let offset = CGFloat(existing % 6) * 18
        let attachment = NoteAudioAttachment(
            pageIndex: currentPageIndex,
            recordingId: recording.id,
            fileName: recording.fileName,
            title: recording.title,
            durationSeconds: recording.durationSeconds,
            x: 80 + offset,
            y: 120 + offset
        )
        if notebook.audioAttachments == nil {
            notebook.audioAttachments = []
        }
        notebook.audioAttachments?.append(attachment)
        // 這本筆記從此「有錄音」—— 首頁的錄音篩選要看得到它。
        notebook.hasRecording = true
        store.updateNotebook(notebook)
    }

    /// 用新算出來的圖表取代原本那一張。
    ///
    /// 位置、尺寸、邊框、濾鏡全部原地保留 —— 使用者只是改了裡面的數字，
    /// 圖不該跳回預設大小、跑回左上角。
    private func replaceChartAttachment(id: String, spec: ChartSpec, image: UIImage) {
        guard let index = notebook.attachments?.firstIndex(where: { $0.id == id }),
              let fileName = store.saveAttachmentImage(image) else { return }
        notebook.attachments?[index].fileName = fileName
        notebook.attachments?[index].chartSpecJSON = spec.encodedJSON()
        store.updateNotebook(notebook)
        editingChartAttachmentId = nil
    }

    /// 目前這一頁的形狀，依堆疊順序。
    private var pageShapes: [NoteShapeAttachment] {
        (notebook.shapeAttachments ?? []).filter { $0.pageIndex == currentPageIndex }
    }

    /// 對齊目前選取的物件。
    ///
    /// 幾何交給核心；這裡只負責「哪個 id 是哪個附件」與把新座標寫回去。
    /// id 由圖層面板給 —— 它才是多選發生的地方。
    /// 七種型別各有自己的陣列，所以搬移得逐型別處理 —— 但**順序必須與
    /// 傳給核心的矩形順序一致**，錯位的話每個物件會搬到別人的位置。
    private func alignSelectedObjects(_ mode: FfiAlignMode, ids: [String]) {
        guard ids.count >= 2 else { return }

        // 收集矩形，順序即 ids 的順序。
        var rects: [CGRect] = []
        for id in ids {
            guard let rect = frameOfObject(id: id) else { return }
            rects.append(rect)
        }

        let origins = ObjectAlignment.aligned(rects: rects, mode: mode)
        guard origins.count == ids.count else { return }
        for (id, origin) in zip(ids, origins) {
            moveObject(id: id, to: origin)
        }
        store.updateNotebook(notebook)
    }

    /// 某個物件目前的版面框（頁面座標）。
    private func frameOfObject(id: String) -> CGRect? {
        if let i = notebook.attachments?.first(where: { $0.id == id }) {
            return CGRect(x: i.x, y: i.y, width: i.width, height: i.height)
        }
        if let i = notebook.shapeAttachments?.first(where: { $0.id == id }) {
            return CGRect(x: i.x, y: i.y, width: i.width, height: i.height)
        }
        if let i = notebook.tableAttachments?.first(where: { $0.id == id }) {
            return CGRect(x: i.x, y: i.y, width: i.width, height: i.height)
        }
        if let i = notebook.textAttachments?.first(where: { $0.id == id }) {
            return CGRect(x: i.x, y: i.y, width: i.width, height: i.height)
        }
        if let i = notebook.linkAttachments?.first(where: { $0.id == id }) {
            return CGRect(x: i.x, y: i.y, width: i.width, height: i.height)
        }
        if let i = notebook.model3DAttachments?.first(where: { $0.id == id }) {
            return CGRect(x: i.x, y: i.y, width: i.width, height: i.height)
        }
        if let i = notebook.audioAttachments?.first(where: { $0.id == id }) {
            return CGRect(x: i.x, y: i.y, width: i.width, height: i.height)
        }
        return nil
    }

    /// 把某個物件的左上角搬到指定座標。
    private func moveObject(id: String, to origin: CGPoint) {
        if let index = notebook.attachments?.firstIndex(where: { $0.id == id }) {
            notebook.attachments?[index].x = origin.x
            notebook.attachments?[index].y = origin.y
            return
        }
        if let index = notebook.shapeAttachments?.firstIndex(where: { $0.id == id }) {
            notebook.shapeAttachments?[index].x = origin.x
            notebook.shapeAttachments?[index].y = origin.y
            return
        }
        if let index = notebook.tableAttachments?.firstIndex(where: { $0.id == id }) {
            notebook.tableAttachments?[index].x = origin.x
            notebook.tableAttachments?[index].y = origin.y
            return
        }
        if let index = notebook.textAttachments?.firstIndex(where: { $0.id == id }) {
            notebook.textAttachments?[index].x = origin.x
            notebook.textAttachments?[index].y = origin.y
            return
        }
        if let index = notebook.linkAttachments?.firstIndex(where: { $0.id == id }) {
            notebook.linkAttachments?[index].x = origin.x
            notebook.linkAttachments?[index].y = origin.y
            return
        }
        if let index = notebook.model3DAttachments?.firstIndex(where: { $0.id == id }) {
            notebook.model3DAttachments?[index].x = origin.x
            notebook.model3DAttachments?[index].y = origin.y
            return
        }
        if let index = notebook.audioAttachments?.firstIndex(where: { $0.id == id }) {
            notebook.audioAttachments?[index].x = origin.x
            notebook.audioAttachments?[index].y = origin.y
        }
    }

    // MARK: - 框選

    /// 這一頁上每一個物件的位置與大小，給框選判定用。
    private var marqueeCandidates: [MarqueeHit] {
        pageStackableObjects.compactMap { object in
            guard let frame = frameOfObject(id: object.id) else { return nil }
            return MarqueeHit(id: object.id, kind: object.kind, frame: frame)
        }
    }

    /// 框選層：拉框、顯示選取外框、整組拖曳。
    private var marqueeLayer: some View {
        let candidates = marqueeCandidates
        let selectionBounds = ObjectMarquee.bounds(of: selectedObjectIds, among: candidates)
        return ZStack(alignment: .topLeading) {
            // 這一層要吃掉觸控 —— 框選模式下畫布不捲、物件不動，
            // 只剩框選這一件事（見 ObjectMarquee 開頭的說明）。
            Color.black.opacity(0.001)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 2,
                                coordinateSpace: .named(CanvasCoordinateSpace.name))
                        .onChanged { value in
                            if let bounds = selectionBounds,
                               bounds.contains(value.startLocation) {
                                // 從選取範圍裡面開始拖＝搬整組。
                                groupDragOffset = value.translation
                            } else {
                                if marqueeStart == nil { marqueeStart = value.startLocation }
                                marqueeCurrent = value.location
                            }
                        }
                        .onEnded { value in
                            if groupDragOffset != .zero {
                                moveSelection(by: groupDragOffset)
                                groupDragOffset = .zero
                            } else if let start = marqueeStart {
                                let rect = ObjectMarquee.rect(from: start, to: value.location)
                                selectedObjectIds = ObjectMarquee.hits(in: rect, among: candidates)
                            }
                            marqueeStart = nil
                            marqueeCurrent = nil
                        }
                )
                // 點空白處＝取消選取。與所有繪圖工具的慣例一致。
                .onTapGesture { selectedObjectIds = [] }

            // 每個被選中的物件畫一個外框。只畫一個大框的話，
            // 使用者看不出「到底選到了哪幾個」。
            ForEach(candidates.filter { selectedObjectIds.contains($0.id) }, id: \.id) { hit in
                Rectangle()
                    .stroke(Color.accentColor, lineWidth: 1.5)
                    .frame(width: hit.frame.width, height: hit.frame.height)
                    .offset(x: hit.frame.minX + groupDragOffset.width,
                            y: hit.frame.minY + groupDragOffset.height)
                    .allowsHitTesting(false)
            }

            // 拉框中的橡皮筋
            if let start = marqueeStart, let current = marqueeCurrent {
                let rect = ObjectMarquee.rect(from: start, to: current)
                Rectangle()
                    .fill(Color.accentColor.opacity(0.10))
                    .overlay(Rectangle().stroke(Color.accentColor, style: StrokeStyle(
                        lineWidth: 1, dash: [4, 3])))
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
                    .allowsHitTesting(false)
            }
        }
    }

    /// 框選模式的工具列。掛在畫布外面（工具列那一層），不隨畫布捲動 ——
    /// 跟著捲的話，選了下半頁的東西就得捲回去才按得到刪除。
    private var marqueeToolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.dashed.inset.filled")
                .foregroundColor(.accentColor)
            Text(localizationManager.localized("marquee_selected")
                .replacingOccurrences(of: "%@", with: "\(selectedObjectIds.count)"))
                .font(.caption)
                .monospacedDigit()

            Divider().frame(height: 18)

            Button {
                copySelection()
            } label: {
                Label(localizationManager.localized("action_copy"), systemImage: "doc.on.doc")
            }
            .disabled(selectedObjectIds.isEmpty)

            Button {
                pasteClipboard()
            } label: {
                Label(localizationManager.localized("action_paste"), systemImage: "doc.on.clipboard")
            }
            .disabled(objectClipboard.isEmpty)

            Button {
                duplicateSelection()
            } label: {
                Label(localizationManager.localized("action_duplicate"), systemImage: "plus.square.on.square")
            }
            .disabled(selectedObjectIds.isEmpty)

            Button(role: .destructive) {
                deleteSelection()
            } label: {
                Label(localizationManager.localized("action_delete"), systemImage: "trash")
            }
            .disabled(selectedObjectIds.isEmpty)

            Divider().frame(height: 18)

            Button {
                isMarqueeActive = false
                selectedObjectIds = []
            } label: {
                Label(localizationManager.localized("done"), systemImage: "checkmark")
            }
        }
        .font(.caption)
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
    }

    // MARK: - 框選的批次操作

    private func moveSelection(by delta: CGSize) {
        guard !selectedObjectIds.isEmpty, delta != .zero else { return }
        for id in selectedObjectIds {
            guard let frame = frameOfObject(id: id) else { continue }
            moveObject(id: id, to: CGPoint(x: frame.minX + delta.width,
                                           y: frame.minY + delta.height))
        }
        store.updateNotebook(notebook)
    }

    private func copySelection() {
        objectClipboard = selectedObjectIds.compactMap(clipboardObject(forId:))
    }

    private func duplicateSelection() {
        let copies = selectedObjectIds.compactMap(clipboardObject(forId:))
        paste(copies)
    }

    private func pasteClipboard() {
        paste(objectClipboard)
    }

    /// 貼上一組物件。**每一個都給新的 id** —— 沿用原 id 的話，兩份物件
    /// 會共用同一筆資料，拖其中一個另一個也會跟著動。
    private func paste(_ objects: [ClipboardObject]) {
        guard !objects.isEmpty else { return }
        let offset = ObjectMarquee.pasteOffset
        var pastedIds: Set<String> = []

        for object in objects {
            switch object {
            case .image(let item):
                var copy = NoteImageAttachment(
                    fileName: item.fileName, pageIndex: currentPageIndex,
                    x: item.x + offset.width, y: item.y + offset.height,
                    width: item.width, height: item.height,
                    rotationDegrees: item.rotationDegrees, cornerRadius: item.cornerRadius,
                    hasShadow: item.hasShadow, hasBorder: item.hasBorder,
                    filterStyle: item.filterStyle, materialType: item.materialType,
                    borderColorHex: item.borderColorHex, borderWidth: item.borderWidth,
                    backgroundColorHex: item.backgroundColorHex,
                    chartSpecJSON: item.chartSpecJSON)
                copy.pageIndex = currentPageIndex
                notebook.attachments = (notebook.attachments ?? []) + [copy]
                pastedIds.insert(copy.id)
            case .text(let item):
                var copy = item
                copy = NoteTextAttachment(
                    pageIndex: currentPageIndex, text: item.text, fontSize: item.fontSize,
                    isBold: item.isBold, isItalic: item.isItalic, isUnderline: item.isUnderline,
                    isStrikethrough: item.isStrikethrough, alignmentRaw: item.alignmentRaw,
                    textColorHex: item.textColorHex,
                    backgroundColorHex: item.backgroundColorHex ?? "#FFFFFF",
                    hasBorder: item.hasBorder, cornerRadius: item.cornerRadius,
                    borderColorHex: item.borderColorHex, borderWidth: item.borderWidth,
                    x: item.x + offset.width, y: item.y + offset.height,
                    width: item.width, height: item.height,
                    lineSpacing: item.lineSpacing, paragraphSpacing: item.paragraphSpacing,
                    firstLineIndent: item.firstLineIndent, paragraphIndent: item.paragraphIndent)
                copy.rotationDegrees = item.rotationDegrees
                notebook.textAttachments = (notebook.textAttachments ?? []) + [copy]
                pastedIds.insert(copy.id)
            case .table(let item):
                var copy = NoteTableAttachment(
                    pageIndex: currentPageIndex,
                    x: item.x + offset.width, y: item.y + offset.height,
                    width: item.width, rows: item.rows, cols: item.cols,
                    cells: item.cells, headerRow: item.headerRow,
                    mergedCells: item.mergedCells, fontSize: item.fontSize,
                    ruleColorHex: item.ruleColorHex,
                    headerBackgroundHex: item.headerBackgroundHex)
                copy.rotationDegrees = item.rotationDegrees
                notebook.tableAttachments = (notebook.tableAttachments ?? []) + [copy]
                pastedIds.insert(copy.id)
            case .shape(let item):
                var copy = NoteShapeAttachment(
                    pageIndex: currentPageIndex, kindName: item.kindName,
                    x: item.x + offset.width, y: item.y + offset.height,
                    width: item.width, height: item.height,
                    cornerRadius: item.cornerRadius, label: item.label,
                    strokeColorHex: item.strokeColorHex, fillColorHex: item.fillColorHex,
                    lineWidth: item.lineWidth)
                copy.rotationDegrees = item.rotationDegrees
                notebook.shapeAttachments = (notebook.shapeAttachments ?? []) + [copy]
                pastedIds.insert(copy.id)
            case .link(let item):
                var copy = NoteLinkAttachment(
                    pageIndex: currentPageIndex, urlString: item.urlString,
                    title: item.title, descriptionText: item.descriptionText,
                    siteName: item.siteName,
                    x: item.x + offset.width, y: item.y + offset.height,
                    width: item.width, height: item.height)
                copy.rotationDegrees = item.rotationDegrees
                copy.hasBorder = item.hasBorder
                copy.cornerRadius = item.cornerRadius
                notebook.linkAttachments = (notebook.linkAttachments ?? []) + [copy]
                pastedIds.insert(copy.id)
            case .model3D(let item):
                var copy = item
                copy = Note3DAttachment()
                copy.pageIndex = currentPageIndex
                copy.x = item.x + offset.width
                copy.y = item.y + offset.height
                copy.width = item.width
                copy.height = item.height
                notebook.model3DAttachments = (notebook.model3DAttachments ?? []) + [copy]
                pastedIds.insert(copy.id)
            case .audio(let item):
                let copy = NoteAudioAttachment(
                    pageIndex: currentPageIndex, recordingId: item.recordingId,
                    fileName: item.fileName, title: item.title,
                    durationSeconds: item.durationSeconds,
                    x: item.x + offset.width, y: item.y + offset.height,
                    width: item.width, height: item.height,
                    rotationDegrees: item.rotationDegrees,
                    hasBorder: item.hasBorder, cornerRadius: item.cornerRadius,
                    borderColorHex: item.borderColorHex, borderWidth: item.borderWidth,
                    backgroundColorHex: item.backgroundColorHex)
                notebook.audioAttachments = (notebook.audioAttachments ?? []) + [copy]
                pastedIds.insert(copy.id)
            }
        }

        store.updateNotebook(notebook)
        // 貼上之後選取新的那一份，接著就能直接再拖一次。
        selectedObjectIds = pastedIds
    }

    private func deleteSelection() {
        guard !selectedObjectIds.isEmpty else { return }
        let ids = selectedObjectIds
        notebook.attachments?.removeAll { ids.contains($0.id) }
        notebook.textAttachments?.removeAll { ids.contains($0.id) }
        notebook.tableAttachments?.removeAll { ids.contains($0.id) }
        notebook.linkAttachments?.removeAll { ids.contains($0.id) }
        notebook.model3DAttachments?.removeAll { ids.contains($0.id) }
        notebook.audioAttachments?.removeAll { ids.contains($0.id) }
        notebook.commentPins?.removeAll { ids.contains($0.id) }
        // 形狀連同它的連接線一起刪 —— 只刪形狀的話，線會留在畫布上，
        // 兩端各指著一個不存在的東西。
        notebook.shapeAttachments?.removeAll { ids.contains($0.id) }
        notebook.connectionAttachments?.removeAll {
            ids.contains($0.fromShapeId) || ids.contains($0.toShapeId)
        }
        selectedObjectIds = []
        store.updateNotebook(notebook)
    }

    private func clipboardObject(forId id: String) -> ClipboardObject? {
        if let item = notebook.attachments?.first(where: { $0.id == id }) { return .image(item) }
        if let item = notebook.textAttachments?.first(where: { $0.id == id }) { return .text(item) }
        if let item = notebook.tableAttachments?.first(where: { $0.id == id }) { return .table(item) }
        if let item = notebook.shapeAttachments?.first(where: { $0.id == id }) { return .shape(item) }
        if let item = notebook.linkAttachments?.first(where: { $0.id == id }) { return .link(item) }
        if let item = notebook.model3DAttachments?.first(where: { $0.id == id }) { return .model3D(item) }
        if let item = notebook.audioAttachments?.first(where: { $0.id == id }) { return .audio(item) }
        return nil
    }

    /// 目前模式的徽章：這個模式下筆會不會畫線、物件拖不拖得動。
    /// 讓模式徽章亮起，並排程淡出。
    private func flashModeBadge() {
        modeBadgeToken += 1
        let token = modeBadgeToken
        modeBadgeVisible = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            // 這段期間又切過模式的話，token 對不上，就讓後來那一次決定。
            if token == modeBadgeToken { modeBadgeVisible = false }
        }
    }

    private var modeBadge: some View {
        let isDraw = editorMode == .draw
        return HStack(spacing: 7) {
            Image(systemName: isDraw ? "pencil.tip" : "keyboard.fill")
                .font(.caption)
                .foregroundColor(isDraw ? .orange : .accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(localizationManager.localized(isDraw ? "mode_draw_badge" : "mode_type_badge"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(localizationManager.localized(isDraw ? "mode_draw_hint" : "mode_type_hint"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: 330, alignment: .leading)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke((isDraw ? Color.orange : Color.accentColor).opacity(0.35), lineWidth: 1)
        )
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.12), radius: 5, y: 2)
        // 徽章是狀態顯示，不是按鈕 —— 吃掉觸控的話，它蓋住的那塊畫布
        // 就寫不了字，而使用者看不出是被什麼擋住的。
        .allowsHitTesting(false)
    }

    /// 這一頁上所有可堆疊的物件，跨七種型別收成同一份清單。
    ///
    /// 名字取得出來就用內容（文字方塊取內文、形狀取標籤），取不出來就用型別名
    /// —— 面板上一整排「未命名」的話，使用者分不出哪一列是哪一個。
    private var pageStackableObjects: [StackableObject] {
        let page = currentPageIndex
        let unnamed = localizationManager.localized("layer_unnamed")
        func title(_ raw: String, _ fallbackKey: String) -> String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return localizationManager.localized(fallbackKey) }
            return String(trimmed.prefix(24))
        }

        var result: [StackableObject] = []
        for item in (notebook.attachments ?? []) where item.pageIndex == page {
            result.append(.init(id: item.id, kind: .image,
                                title: localizationManager.localized("layer_kind_image")))
        }
        for item in (notebook.shapeAttachments ?? []) where item.pageIndex == page {
            result.append(.init(id: item.id, kind: .shape,
                                title: title(item.label, "layer_kind_shape")))
        }
        for item in (notebook.tableAttachments ?? []) where item.pageIndex == page {
            result.append(.init(id: item.id, kind: .table,
                                title: localizationManager.localized("layer_kind_table")))
        }
        for item in (notebook.textAttachments ?? []) where item.pageIndex == page {
            result.append(.init(id: item.id, kind: .text,
                                title: title(item.text, "layer_kind_text")))
        }
        for item in (notebook.linkAttachments ?? []) where item.pageIndex == page {
            result.append(.init(id: item.id, kind: .link,
                                title: title(item.title.isEmpty ? item.urlString : item.title, "layer_kind_link")))
        }
        for item in (notebook.model3DAttachments ?? []) where item.pageIndex == page {
            result.append(.init(id: item.id, kind: .model3D,
                                title: localizationManager.localized("layer_kind_model3d")))
        }
        for item in (notebook.audioAttachments ?? []) where item.pageIndex == page {
            result.append(.init(id: item.id, kind: .audio,
                                title: title(item.title, "layer_kind_audio")))
        }
        for pin in (notebook.commentPins ?? []) where pin.pageIndex == page {
            result.append(.init(id: pin.id, kind: .pin,
                                title: localizationManager.localized("layer_kind_pin")))
        }
        _ = unnamed
        return result
    }

    /// 換掉這一頁的形狀，其餘頁面原封不動。
    ///
    /// 陣列順序就是堆疊順序，所以整段換掉是必要的 —— 只改個別元素的話，
    /// 圖層面板調的順序不會反映到畫布上。
    private func replacePageShapes(with updated: [NoteShapeAttachment]) {
        var others = (notebook.shapeAttachments ?? []).filter { $0.pageIndex != currentPageIndex }
        others.append(contentsOf: updated)
        notebook.shapeAttachments = others
        store.updateNotebook(notebook)
    }

    private func toggleShapeSelection(_ id: String) {
        // 選到群組裡的一個就整組選起來 —— 那正是群組的意義。
        let mates = ObjectLayerOps.groupMates(of: id, in: pageShapes)
        if mates.isSubset(of: selectedShapeIds) {
            selectedShapeIds.subtract(mates)
        } else {
            selectedShapeIds.formUnion(mates)
        }
    }

    /// 拖曳一個形狀時，同一組的其他成員要跟著走。
    ///
    /// 不跟的話，群組起來的流程圖一拖就散開了。
    private func moveShapeGroup(_ id: String, by delta: CGSize) {
        let mates = ObjectLayerOps.groupMates(of: id, in: pageShapes)
        guard var all = notebook.shapeAttachments else { return }
        for index in all.indices where mates.contains(all[index].id) {
            all[index].x += delta.width
            all[index].y += delta.height
        }
        notebook.shapeAttachments = all
        store.updateNotebook(notebook)
    }

    private func shapeBinding(for id: String) -> Binding<NoteShapeAttachment> {
        Binding(
            get: {
                notebook.shapeAttachments?.first(where: { $0.id == id })
                    ?? NoteShapeAttachment(id: id)
            },
            set: { updated in
                guard let index = notebook.shapeAttachments?
                    .firstIndex(where: { $0.id == id }) else { return }
                notebook.shapeAttachments?[index] = updated
                store.updateNotebook(notebook)
            }
        )
    }

    private func tableBinding(for id: String) -> Binding<NoteTableAttachment> {
        Binding(
            get: {
                notebook.tableAttachments?.first(where: { $0.id == id })
                    ?? NoteTableAttachment(id: id)
            },
            set: { updated in
                guard let index = notebook.tableAttachments?
                    .firstIndex(where: { $0.id == id }) else { return }
                notebook.tableAttachments?[index] = updated
                store.updateNotebook(notebook)
            }
        )
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

    private func binding(forAudioId id: String) -> Binding<NoteAudioAttachment> {
        Binding(
            get: {
                notebook.audioAttachments?.first(where: { $0.id == id })
                    ?? NoteAudioAttachment(fileName: "")
            },
            set: { updated in
                if let idx = notebook.audioAttachments?.firstIndex(where: { $0.id == id }) {
                    notebook.audioAttachments?[idx] = updated
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
                        .rotationEffect(.degrees(attachment.canvasRotation))
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

                    // 邊框開關已移進「美化圖片」面板（`ImageEditControls` 的
                    // 「保留邊框」）。原本兩個地方都能改同一個值，畫布上那顆
                    // 又只有顏色會變、沒有標示，使用者不知道自己按了什麼。

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

                // 旋轉把手。與內容同層但**不參與** `.rotationEffect` ——
                // 包進旋轉裡的話，拖曳算出的角度會疊加自身旋轉，物件會失控加速。
                ObjectRotationHandle(
                    degrees: $attachment.canvasRotation,
                    size: CGSize(width: displayWidth, height: displayHeight)
                ) {
                    if let data = try? JSONEncoder().encode(attachment),
                       let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        collaborationManager.broadcastAttachmentUpsert(type: "image", itemDict: dict)
                    }
                }
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
        .accessibilityLabel(localizationManager.localized(titleKey))
        .help(localizationManager.localized(titleKey))
    }

    private var displayWidth: CGFloat { liveWidth ?? textItem.width }
    private var displayHeight: CGFloat { liveHeight ?? textItem.height }
    /// 拖曳縮放中的即時高度。
    @State private var liveHeight: CGFloat? = nil
    @State private var resizeBaseSize: CGSize? = nil

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
                        // 段落設定要跟匯出端套同一組值，否則行數不同、版面又分家。
                        .lineSpacing(textItem.lineSpacing ?? 0)
                        .padding(.leading, textItem.paragraphIndent ?? 0)
                        .frame(maxWidth: .infinity, alignment: resolveFrameAlignment(textItem.alignmentRaw))
                }
            }
            .padding(14)
            // 高度也要套。原本只套寬度，於是方塊的高度由內容決定：
            //   1. 右下角的縮放把手往下拉完全沒有反應 —— 使用者說「只能調寬度」。
            //   2. 同一個方塊在 Android 上是 `size(width, height)`，兩邊高度不一樣。
            // `height` 這個欄位一直都在，也一直跟著同步走，只有 Apple 沒有用它。
            .frame(width: displayWidth, height: displayHeight, alignment: .top)
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
            .rotationEffect(.degrees(textItem.canvasRotation))
            // 右下角的縮放把手。
            //
            // 原本只能進到「Word 文字編修」面板拉「方塊寬度」滑桿 ——
            // 要改一個方框的大小卻得先開一個蓋住它的面板，而且只能改寬度。
            // 圖片早就有這個把手了，文字方塊沒有。
            //
            // **必須掛在 .contentShape(Rectangle()) 之後。** 掛在前面的話，
            // 那個 contentShape 會把整個組合視圖的命中形狀壓成方塊本身的矩形，
            // 而把手是 offset 到矩形外面的 —— 於是它看得到、點得到一半、
            // 拖曳完全沒有反應（實機上就是這樣，看起來像「只能調寬度」）。
            // 用 highPriorityGesture 是同一個道理：外層有兩個 onTapGesture，
            // 普通 gesture 會被它們先吃掉。
            .overlay(alignment: .bottomTrailing) {
                if isSelected && lockedByPeer == nil && !isEditingInline {
                    Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                        .contentShape(Circle())
                        .offset(x: 10, y: 10)
                        .accessibilityLabel(localizationManager.localized("resize_text_box"))
                        .help(localizationManager.localized("resize_text_box"))
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 1,
                                        coordinateSpace: .named(CanvasCoordinateSpace.name))
                                .onChanged { value in
                                    let base = resizeBaseSize
                                        ?? CGSize(width: textItem.width, height: textItem.height)
                                    if resizeBaseSize == nil { resizeBaseSize = base }
                                    // 下限不是隨手取的：比一行字還窄的方框，
                                    // 每個字都會自己換一行，看起來像壞掉。
                                    liveWidth = max(120, base.width + value.translation.width)
                                    liveHeight = max(60, base.height + value.translation.height)
                                }
                                .onEnded { _ in
                                    if let w = liveWidth { textItem.width = w }
                                    if let h = liveHeight { textItem.height = h }
                                    resizeBaseSize = nil
                                    liveWidth = nil
                                    liveHeight = nil
                                    broadcastTextChange()
                                }
                        )
                }
            }
            .overlay {
                if isSelected && !isEditingInline && lockedByPeer == nil {
                    // 尺寸取實際版面框。現在版面框就是 displayWidth × displayHeight，
                    // 兩者一致 —— 但仍然用量到的值，把手的位置沒有猜測的餘地。
                    GeometryReader { geo in
                        ObjectRotationHandle(
                            degrees: $textItem.canvasRotation,
                            size: geo.size,
                            onCommit: broadcastTextChange
                        )
                    }
                }
            }
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
                    // 邊框開關已移進「文字排版」面板的「樣式」分頁。
                    // 保留在畫布上的只有真正需要立即觸及的動作：編輯與刪除。
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
        // y 是方塊的**上緣**，與 x 的語意一致，也與 Android 的
        // `offset(x, y)` 一致。原本這裡寫死 60（等於假設方塊高 120），
        // 高度一改就錯位，而且同一份筆記在兩個平台的落點本來就不同。
        .position(x: currentX + displayWidth / 2, y: currentY + displayHeight / 2)
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
    /// 縮放拖曳中的即時尺寸。直接改 linkItem.width 會每一幀都寫回筆記。
    @State private var liveSize: CGSize? = nil
    @State private var resizeBase: CGSize? = nil
    @State private var isEditing: Bool = false

    private var displayWidth: CGFloat { liveSize?.width ?? linkItem.width }
    private var displayHeight: CGFloat { liveSize?.height ?? linkItem.height }

    var body: some View {
        let currentX = linkItem.x + dragOffset.width
        let currentY = linkItem.y + dragOffset.height

        card
            // 卡片本體跟著轉；把手掛在旋轉**外面**的 overlay ——
            // 包進去的話拖曳算出的角度會疊加自身旋轉，卡片會失控加速。
            .rotationEffect(.degrees(linkItem.canvasRotation))
            .overlay {
                if isSelected {
                    GeometryReader { geo in
                        ObjectRotationHandle(degrees: $linkItem.canvasRotation, size: geo.size)
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.red)
                    }
                    .buttonStyle(.plain)
                    .offset(x: 10, y: -10)
                    .accessibilityLabel(localizationManager.localized("action_delete"))
                }
            }
            // 右下角縮放把手。卡片原本只能用插入時的寬度，標題長一點就被截掉。
            .overlay(alignment: .bottomTrailing) {
                if isSelected { resizeHandle }
            }
            // 左下角編修鈕：網址、標題與說明都存在模型裡，但在這一版之前
            // 沒有任何介面改得到 —— 打錯一個字只能刪掉重插。
            .overlay(alignment: .bottomLeading) {
                if isSelected {
                    Button { isEditing = true } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                    .offset(x: -10, y: 10)
                    .accessibilityLabel(localizationManager.localized("link_edit"))
                    .help(localizationManager.localized("link_edit"))
                }
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
            .onTapGesture { isSelected.toggle() }
            .position(x: currentX + displayWidth / 2, y: currentY + displayHeight / 2)
            .sheet(isPresented: $isEditing) { resizableSheet {
                LinkAttachmentEditSheet(linkItem: $linkItem)
            } }
    }

    private var card: some View {
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
                    .lineLimit(3)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        // 高度也照模型走。原本只綁寬度、位置用寫死的 +50 推算中心 ——
        // 卡片一變高，選取框、把手與實際內容就對不上。
        .frame(width: displayWidth, height: displayHeight, alignment: .topLeading)
        .background(ObjectFrameStyleResolver.background(linkItem, .link))
        .cornerRadius(linkItem.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: linkItem.cornerRadius)
                .stroke(
                    isSelected ? Color.accentColor
                               : ObjectFrameStyleResolver.borderColor(linkItem, .link),
                    lineWidth: isSelected ? 1.5
                                          : ObjectFrameStyleResolver.borderWidth(linkItem, .link)
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
        .contentShape(Rectangle())
    }

    private var resizeHandle: some View {
        Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 30, height: 30)
            .background(Color.accentColor)
            .clipShape(Circle())
            .contentShape(Circle())
            .offset(x: 10, y: 10)
            .accessibilityLabel(localizationManager.localized("resize_link"))
            .help(localizationManager.localized("resize_link"))
            .highPriorityGesture(
                DragGesture(minimumDistance: 1,
                            coordinateSpace: .named(CanvasCoordinateSpace.name))
                    .onChanged { value in
                        let base = resizeBase ?? CGSize(width: linkItem.width, height: linkItem.height)
                        if resizeBase == nil { resizeBase = base }
                        // 下限取卡片還讀得出東西的尺寸：再小就只剩邊框。
                        liveSize = CGSize(
                            width: max(140, base.width + value.translation.width),
                            height: max(64, base.height + value.translation.height)
                        )
                    }
                    .onEnded { _ in
                        if let size = liveSize {
                            linkItem.width = size.width
                            linkItem.height = size.height
                        }
                        resizeBase = nil
                        liveSize = nil
                    }
            )
    }
}

/// 連結卡片的編修表單。
///
/// 網址、標題、說明與站名四個欄位一直都在模型裡、也一直跟著同步走，
/// 但在這一版之前沒有任何介面改得到它們 —— 解析錯一次就只能刪掉重插。
struct LinkAttachmentEditSheet: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @Binding var linkItem: NoteLinkAttachment

    var body: some View {
        NavigationStack {
            Form {
                Section(localizationManager.localized("insert_link")) {
                    TextField(localizationManager.localized("link_url_hint"), text: $linkItem.urlString)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
                Section(localizationManager.localized("link_title")) {
                    TextField(localizationManager.localized("link_title"), text: $linkItem.title)
                }
                Section(localizationManager.localized("link_description")) {
                    TextField(localizationManager.localized("link_description"),
                              text: $linkItem.descriptionText, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section(localizationManager.localized("link_site_name")) {
                    TextField(localizationManager.localized("link_site_name"), text: $linkItem.siteName)
                }
            }
            .navigationTitle(localizationManager.localized("link_edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized("done")) { dismiss() }
                }
            }
        }
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
        static let audio = Defaults(
            borderColor: .red.opacity(0.35), borderWidth: 1.5,
            background: Color(UIColor.secondarySystemGroupedBackground))
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


