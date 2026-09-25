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
    case maskingTape = "masking_tape"

    public var id: String { rawValue }

    /// 這個工具是不是「筆」。
    ///
    /// 橡皮擦與套索不是筆：一個是擦掉、一個是選取，兩者都不沾墨，也不吃
    /// 顏色與粗細。工具列把九個圖示排成沒有斷點的一長列時，使用者得靠
    /// 記圖案來分辨 —— 分組之後，形狀就說明了用途（工作項 S-62）。
    public var isBrush: Bool {
        switch self {
        case .eraser, .lasso, .maskingTape: return false
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
        case .maskingTape: return "bandage.fill"
        }
    }

    /// 跨平台對照閘門用的識別字（核心 `ffi_screens` 的 `editor.inktools`）。
    ///
    /// 寫成 switch 而不是 `"editor.ink.\(rawValue)"`：閘門掃的是原始碼裡的
    /// 字串字面值，插值組出來的識別字它看不見 —— 那樣工具少一個也不會紅。
    public var parityIdentifier: String {
        switch self {
        case .pen: return "editor.ink.pen"
        case .ballpoint: return "editor.ink.ballpoint"
        case .brush: return "editor.ink.brush"
        case .marker: return "editor.ink.marker"
        case .highlighter: return "editor.ink.highlighter"
        case .pencil: return "editor.ink.pencil"
        case .watercolor: return "editor.ink.watercolor"
        case .eraser: return "editor.ink.eraser"
        case .lasso: return "editor.ink.lasso"
        case .maskingTape: return "editor.ink.maskingTape"
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
        case .maskingTape: return "tool_masking_tape"
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
    /// 這一頁用的紙張。**逐頁**，不是整本 —— 同一本筆記可以一頁四象限、
    /// 一頁橫線（見 `NotebookDocument.pagePaperIds`）。
    var paperId: String = "blank" {
        didSet { if oldValue != paperId { setNeedsDisplay() } }
    }
    /// 版面的配色。整本一個。
    var paletteId: String? {
        didSet { if oldValue != paletteId { setNeedsDisplay() } }
    }

    private var template: NoteTemplate { NoteTemplate(paperId: paperId) ?? .blank }

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
        drawBaseTexture(ctx)
        drawGuides(ctx)
    }

    // MARK: - 底紋

    /// 重複的材質：方格、點陣、橫線、五線譜、等角軸測。
    ///
    /// # 為什麼這裡只剩四行
    ///
    /// 原本是一段 `switch` 加上一段等角軸測的手寫 CoreGraphics，而 Android
    /// 那邊有另一段 —— 兩段的數字不一樣（方格 28／24、點陣 20／16、五線譜
    /// 行距 9／10），於是同一本方格筆記在兩台裝置上「寫在第幾格」對不起來。
    /// 底紋現在也是核心送來的資料（`page_texture`），畫法在 `PageGuideRenderer`。
    ///
    /// **用頁面高度，不是畫布高度**：畫布比頁面高（它要捲動），拿
    /// `bounds.height` 鋪的話格線會一路畫到紙的下面 —— 看得到、印不出來。
    private func drawBaseTexture(_ ctx: CGContext) {
        PageGuideRenderer.drawTexture(
            paperId: paperId,
            style: template.pageStyle,
            paletteId: paletteId,
            in: ctx,
            size: PageGeometry.size
        )
    }

    // MARK: - 版面引導線

    /// 這張紙的**結構**：康乃爾的三個區塊、四象限的十字、時程表的欄列。
    ///
    /// # 為什麼不是繼續寫 switch
    ///
    /// 原本這裡是十三段手寫的 CoreGraphics，每一種紙一段；而 Android 端
    /// 只畫得出底紋，藍圖標題欄、手機線框那一層完全沒有 —— 同一本筆記在
    /// 兩台裝置上長得不一樣。紙張要長到三十幾種，沿著原路走就是這裡多二十段、
    /// Android 繼續落後二十段。
    ///
    /// 現在版面是核心送來的資料（`page_guides`），畫法在
    /// `PageGuideRenderer` —— 縮圖用的是同一份。
    private func drawGuides(_ ctx: CGContext) {
        PageGuideRenderer.draw(
            paperId: paperId,
            paletteId: paletteId,
            in: ctx,
            // **頁面高度，不是畫布高度。** 畫布比頁面高（它要捲動），
            // 用 `bounds.height` 算的話四象限的十字會落在頁面下緣之外 ——
            // 畫面上看得到，列印出來卻不在紙上。
            size: PageGeometry.size
        )
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

//
/// 橡皮擦雙模式：筆劃橡皮擦（一碰擦整條線）vs 像素橡皮擦（局部擦除）
enum EraserMode: String { case stroke, pixel }

/// PencilKit 畫布之 SwiftUI 封裝（跨 iOS / iPadOS / Mac Catalyst，支援無限高度延長、背景同步滾動與套索選取監聽）
struct CanvasRepresentable: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var selectedTool: EditorToolType
    var selectedColor: Color
    var strokeWidth: CGFloat
    var eraserMode: EraserMode = .stroke
    var pixelEraserWidth: CGFloat = 20.0
    var isRulerActive: Bool
    /// 這一頁的紙張 id（逐頁）與整本的配色。
    var paperId: String
    var paletteId: String?
    var pageHeight: CGFloat
    var editorMode: EditorMode = .draw
    /// 這個畫布要不要自己捲動。
    ///
    /// 連續頁面模式下每一頁都是一個 PKCanvasView，外面還有一個 ScrollView。
    /// 兩層都能捲的話，手指放在畫布上時捲到的是裡層那一頁 —— 捲不出去，
    /// 看起來像卡住。連續模式把裡層關掉，捲動交給外面那一層。
    var isScrollEnabled: Bool = true
    /// 筆跡有變動。
    ///
    /// **回傳值是「修正過的筆跡」**：需要收回某幾筆時回傳收回後的版本，
    /// 不需要修正就回 nil。畫布會把修正寫回去 —— 只改存檔不改畫布的話，
    /// 使用者看得到那一筆、檔案裡卻沒有，而且它會在**每一次落筆**時再被
    /// 檢查一次，提示就一直跳（實際回報過）。
    var onDrawingChanged: ((PKDrawing) -> PKDrawing?)?
    /// 筆跡寫到接近頁尾時通知編輯器。
    ///
    /// 舊版是「把這一頁拉長」，於是同一本筆記裡每頁高度都不同，匯出與列印
    /// 無從對齊紙張。現在頁面高度固定，到底了就準備下一頁。
    var onReachedPageBottom: (() -> Void)?
    var onSelectionChanged: ((Bool) -> Void)?
    var canvasRef: ((PKCanvasView) -> Void)?
    /// 回報捲動狀態（可見比例、捲動比例），給自訂捲軸用
    var onScrollMetrics: ((_ visibleFraction: CGFloat, _ scrollFraction: CGFloat) -> Void)?
    var onTransformChanged: ((_ scale: CGFloat, _ offset: CGPoint) -> Void)? = nil
    /// 掌拒（工作項 S-45）。判定規則走核心，與 Android 同一份。
    var palmRejection: PalmRejectionCoordinator?
    /// 仲裁器要求收回筆畫時通知編輯器。
    var onRetractStrokes: ((Date) -> Void)?
    /// 筆身上的動作（工作項 S-40 / S-67）。`pressed` 只對側鍵這類
    /// 「按著」的控制項有意義。
    var onPenControl: ((FfiPenControl, Bool) -> Void)?

    var onPrevPage: (() -> Void)?
    var onNextPage: (() -> Void)?
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    var onMagneticSnap: ((CGPoint, CGPoint) -> Void)?

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
        canvas.isUserInteractionEnabled = acceptsInk
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

        // **這一行一定要包在 `isProgrammaticUpdate` 裡。**
        //
        // 上面第一件事就是 `canvas.delegate = context.coordinator`，所以這裡
        // 一設 `drawing`，`canvasViewDrawingDidChange` 就會被叫到 —— 而它會
        // 走到 `recordDrawingEdit`，把當下這份 drawing **寫進磁碟**。
        //
        // 而 `makeUIView` 跑在 `body` 求值的時候，**比 `.onAppear` 早**，
        // 那時 `loadCurrentPage()` 還沒跑，`currentDrawing` 還是 `@State`
        // 的初始空值。結果就是：**每一次重新打開筆記本，都會先把已經存好的
        // 筆跡蓋成一張空白。**
        //
        // 這就是「筆跡沒有自動儲存」的真正原因 —— 存是存進去了（量過：
        // 畫完不離開，檔案是 638 bytes），是重新開啟的那一瞬間被清掉的
        // （同一個檔案變成 42 bytes，空的 PKDrawing）。
        //
        // `updateUIView` 裡設 `drawing` 的那一處一直都有這個保護，只有
        // 建立時這一處漏了。
        context.coordinator.isProgrammaticUpdate = true
        canvas.drawing = drawing
        context.coordinator.isProgrammaticUpdate = false

        // 給自動化測試一個穩定的抓取點（畫面上有多個 scroll view）
        canvas.accessibilityIdentifier = "editor.canvas"
        // 初始讀數。沒有這一行的話，測試在捏合之前讀到的是 nil，
        // 而 nil 與 "zoom:1.000" 的差別會被誤讀成「縮放有作用」。
        if ProcessInfo.processInfo.environment["KAIRUMO_UITEST"] == "1" {
            canvas.accessibilityValue = CanvasRepresentable.testReadout(canvas)
        }
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
        
        // 🌟 新增手勢：雙指點擊復原、三指點擊重做、三指上下滑動換頁
        let twoFingerTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTwoFingerTap(_:)))
        twoFingerTap.numberOfTouchesRequired = 2
        canvas.addGestureRecognizer(twoFingerTap)
        
        let threeFingerTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleThreeFingerTap(_:)))
        threeFingerTap.numberOfTouchesRequired = 3
        canvas.addGestureRecognizer(threeFingerTap)
        
        let swipeUp = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleThreeFingerSwipeUp(_:)))
        swipeUp.numberOfTouchesRequired = 3
        swipeUp.direction = .up
        canvas.addGestureRecognizer(swipeUp)
        
        let swipeDown = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleThreeFingerSwipeDown(_:)))
        swipeDown.numberOfTouchesRequired = 3
        swipeDown.direction = .down
        canvas.addGestureRecognizer(swipeDown)


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
            // 讀數要跟著更新。
            //
            // `isProgrammaticUpdate` 會讓 delegate 直接 return（那是對的 ——
            // 程式設進去的內容不該再存一次），但**讀數也跟著沒更新**。
            // 於是重新打開筆記本之後，畫面上明明有筆跡，測試讀到的卻還是
            // 建立當下那個 `strokes:0`：一個**看起來像資料掉了、其實是
            // 儀器沒動**的假象。實際被這個騙過一次。
            if ProcessInfo.processInfo.environment["KAIRUMO_UITEST"] == "1" {
                uiView.accessibilityValue = CanvasRepresentable.testReadout(uiView)
            }
        }
        uiView.isRulerActive = isRulerActive

        // 更新高度與滾動範圍。寬度交給 AdaptiveCanvasView 在 layoutSubviews 處理 ——
        // 這裡拿到的 bounds 可能還是版面變動前的舊值。
        if let adaptive = uiView as? AdaptiveCanvasView {
            adaptive.pageContentHeight = PageGeometry.height
            adaptive.syncContentSize()
        }

        context.coordinator.applyTool(to: uiView)
    }

    /// 測試用讀數：縮放倍率**與筆畫數**。
    ///
    /// # 為什麼筆畫數也要暴露
    ///
    /// 「筆跡有沒有存下來」看程式碼是看不出來的 —— `saveDrawing` 有呼叫、
    /// `onDisappear` 有存、`scenePhase` 也有存，每一項都對，而使用者一再
    /// 回報「筆跡沒有自動儲存」。
    ///
    /// 在此之前**沒有任何一條測試畫一筆、離開、再回來看它還在不在**：
    /// `testDrawingToolsAndTypeModeGridTap` 只點了工具再點一下畫布，
    /// 不檢查任何東西留下來。所以每一次「修好了」都沒有東西守著 ——
    /// 而這正是它被修了很多次卻還在的原因。
    ///
    /// 生產環境不掛：`accessibilityValue` 是給 VoiceOver 念的，
    /// 念一串「zoom:1.000 strokes:3」沒有任何意義。
    static func testReadout(_ canvas: PKCanvasView) -> String {
        String(format: "zoom:%.3f strokes:%d", canvas.zoomScale, canvas.drawing.strokes.count)
    }
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate, UIPointerInteractionDelegate {
        /// 把捲動狀態回報給 SwiftUI（自訂捲軸需要）
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            reportScrollMetrics(scrollView)
            parent.onTransformChanged?(scrollView.zoomScale, scrollView.contentOffset)
        }

        /// 縮放倍率的讀數，**只在 UI 測試下掛上去**。
        ///
        /// 「兩指捏合到底有沒有作用」這件事，看程式碼是看不出來的 ——
        /// min/max 設了、delegate 接了、`viewForZooming` 也回了，每一項都
        /// 對，而使用者回報它沒反應。中間任何一層（手勢辨識器互相擋、
        /// scroll view 被停用、回傳了錯的子視圖）都會讓它靜靜地失效。
        ///
        /// 所以把倍率暴露出來讓測試讀。生產環境不掛 —— `accessibilityValue`
        /// 是給 VoiceOver 念的，念一串「zoom:1.000」沒有任何意義。
        private func publishZoomForTests(_ scrollView: UIScrollView) {
            guard ProcessInfo.processInfo.environment["KAIRUMO_UITEST"] == "1" else { return }
            if let canvas = scrollView as? PKCanvasView {
                scrollView.accessibilityValue = CanvasRepresentable.testReadout(canvas)
            } else {
                scrollView.accessibilityValue = String(format: "zoom:%.3f", scrollView.zoomScale)
            }
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            publishZoomForTests(scrollView)
            parent.onTransformChanged?(scrollView.zoomScale, scrollView.contentOffset)
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            // PKCanvasView 的縮放必須透過 delegate 指定目標視圖。
            // 因為我們接管了 delegate，內建的處理被覆蓋了，縮放手勢會完全失效。
            // 官方文件規定：接管 delegate 時必須回傳它的第一個子視圖。
            scrollView.subviews.first
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
        var shapeRefineTimer: DispatchWorkItem? = nil
        var lastStrokeCountBeforeRefine: Int = 0

        /// Apple Pencil 雙擊的接收端。**這個屬性要持有它** ——
        /// `UIPencilInteraction.delegate` 是 weak 的，不留一份強參考的話
        /// 它會在 `makeUIView` 回傳之後就被釋放，雙擊從此沒有反應。
        let pencilTaps = PencilInteractionForwarder()

        /// 懸停預覽（工作項 S-69）。與 `pencilTaps` 一樣要由這裡持有 ——
        /// 手勢辨識器只對 target 保持 weak 參考。
        let penHover = PenHoverCoordinator()

        /// 多指手勢的動作**由核心決定**（`finger_tap_action` /
        /// `finger_swipe_action`）。
        ///
        /// 原本這四個方法各自寫死一個動作，而 Android 一個都沒有 ——
        /// 使用者回報「手指操作畫布的設計無法落地」，在 Android 上那是
        /// 字面意義的真。規則搬進核心之後兩端才可能對齊，而這四個動作
        /// 與「一指是畫還是平移」一樣是肌肉記憶：兩台裝置不一樣，
        /// 比兩台都沒有更糟。
        private func perform(_ action: FfiMultiFingerAction) {
            switch action {
            case .none: break
            case .undo: parent.onUndo?()
            case .redo: parent.onRedo?()
            case .prevPage: parent.onPrevPage?()
            case .nextPage: parent.onNextPage?()
            }
        }

        @objc func handleTwoFingerTap(_ sender: UITapGestureRecognizer) {
            guard sender.state == .ended else { return }
            perform(fingerTapAction(fingers: 2))
        }

        @objc func handleThreeFingerTap(_ sender: UITapGestureRecognizer) {
            guard sender.state == .ended else { return }
            perform(fingerTapAction(fingers: 3))
        }

        @objc func handleThreeFingerSwipeUp(_ sender: UISwipeGestureRecognizer) {
            guard sender.state == .ended else { return }
            perform(fingerSwipeAction(fingers: 3, upwards: true))
        }

        @objc func handleThreeFingerSwipeDown(_ sender: UISwipeGestureRecognizer) {
            guard sender.state == .ended else { return }
            perform(fingerSwipeAction(fingers: 3, upwards: false))
        }

        init(_ parent: CanvasRepresentable) {
            self.parent = parent
            super.init()
            pencilTaps.onControl = { [weak self] control, pressed in
                self?.parent.onPenControl?(control, pressed)
            }
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isProgrammaticUpdate else { return }
            var effective = canvasView.drawing
            if let corrected = parent.onDrawingChanged?(effective),
               corrected.strokes.count != effective.strokes.count {
                // 收回的筆畫要真的從畫布上消失。
                //
                // 原本只有存檔那一份被拿掉：畫面上那一筆還在，使用者以為
                // 寫成功了，而匯出的檔案裡沒有它；更糟的是它留在畫布上，
                // 於是**下一筆、再下一筆**都會連它一起重新檢查，
                // 「這一筆畫在可列印範圍之外」的提示就一直跳。
                isProgrammaticUpdate = true
                canvasView.drawing = corrected
                isProgrammaticUpdate = false
                effective = corrected
            }
            parent.drawing = effective

            // 筆畫數也要跟著更新 —— 只在建立時寫一次的話，測試讀到的
            // 永遠是 0，而「畫了沒存」與「根本沒畫進去」看起來一模一樣。
            if ProcessInfo.processInfo.environment["KAIRUMO_UITEST"] == "1" {
                canvasView.accessibilityValue = CanvasRepresentable.testReadout(canvasView)
            }

            // ── 長按圖形辨識 ────────────────────────────────────
            // 新增筆劃時啟動 0.5 秒計時器；期間若再下筆就取消。
            // 計時器到了表示使用者停住了，嘗試美化最後一筆。
            self.shapeRefineTimer?.cancel()
            let count = effective.strokes.count
            if count > self.lastStrokeCountBeforeRefine, parent.selectedTool.isBrush {
                let work = DispatchWorkItem { [weak canvasView, weak self] in
                    guard let canvas = canvasView else { return }
                    let drawing = canvas.drawing
                    guard let lastStroke = drawing.strokes.last else { return }
                    guard let (refined, kind) = SketchRefineEngine.refineSingleStroke(lastStroke) else { return }
                    // 只有辨識出幾何圖形才替換
                    guard kind != .freehand else { return }
                    
                    var strokes = drawing.strokes
                    strokes[strokes.count - 1] = refined
                    
                    DispatchQueue.main.async {
                        self?.isProgrammaticUpdate = true
                        canvas.drawing = PKDrawing(strokes: strokes)
                        self?.isProgrammaticUpdate = false
                        self?.parent.drawing = canvas.drawing
                        // Haptic 回饋
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
                self.shapeRefineTimer = work
            }

            // ── 智慧磁吸對齊與幾何角度引導 (Smart Magnetic Snap) ─────────────────
            if parent.onMagneticSnap != nil, parent.selectedTool.isBrush, count > self.lastStrokeCountBeforeRefine, let lastStroke = effective.strokes.last {
                let strokeCount = lastStroke.path.count
                if strokeCount >= 2 {
                    let startPoint = lastStroke.path[0].location
                    let endPoint = lastStroke.path[strokeCount - 1].location
                    let snapResult = SmartMagneticSnap.snap(start: startPoint, current: endPoint, enableGrid: true)
                    if snapResult.didSnap {
                        parent.onMagneticSnap?(startPoint, snapResult.snappedPoint)
                    }
                }
            }
            self.lastStrokeCountBeforeRefine = count

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
                switch parent.eraserMode {
                case .stroke:
                    canvas.tool = PKEraserTool(.vector)
                case .pixel:
                    if #available(iOS 16.4, *) {
                        canvas.tool = PKEraserTool(.bitmap, width: parent.pixelEraserWidth)
                    } else {
                        canvas.tool = PKEraserTool(.bitmap)
                    }
                }

            case .lasso, .maskingTape:
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

/// 筆記編輯器全螢幕視圖
public struct NotebookEditorView: View {
    @Binding var notebook: NotebookDocument
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @ObservedObject var store = NotebookStore.shared
    @ObservedObject var audioManager = AudioRecorderManager.shared
    @ObservedObject var localizationManager = LocalizationManager.shared
    /// 使用者自訂的工具列（S-261）。關掉的工具不畫出來。
    @ObservedObject var toolbarSettings = ToolbarSettings.shared
    private func L(_ key: String) -> String { localizationManager.localized(key) }

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
    /// 筆跡改動後「把這本筆記標記為剛改過」的去抖動計時器。
    ///
    /// 筆畫本身是**每次變動就落盤**的（見 `onDrawingChanged` 裡的
    /// `store.saveDrawing`），但那只寫 `.drawing` 檔，不會動到筆記本身。
    /// 少了這一步的後果有兩個，而且都看起來像「筆跡沒有被儲存」：
    ///
    /// 1. 首頁卡片上的修改時間停在上一次插入物件的時刻 —— 使用者寫了
    ///    一整頁字，清單上那本筆記卻沒有往上移，時間也沒變。
    /// 2. **雲端同步不會被觸發**。自動同步掛在 `persistData()` 上，
    ///    而只寫 `.drawing` 檔不會經過它 —— 於是手寫內容要等到使用者
    ///    換頁或離開編輯器才會上雲。
    ///
    /// 為什麼要去抖動：`onDrawingChanged` 在**一筆畫的途中**就會被叫很多次，
    /// 每次都寫 `notebooks.json` 並觸發整棵畫面重算的話，寫字會頓。
    @State private var inkTouchWork: DispatchWorkItem? = nil
    /// 已經寫進核心 `.padnote` 的筆跡基準線，依頁次保存。
    ///
    /// `PKCanvasView` 在一筆畫尚未離筆時就會連續回報 drawing 變更。核心的 ink log
    /// 是 append-only；若每次回報都 append，會把同一筆的半成品寫成好幾筆。
    /// 因此畫布仍即時寫 `.drawing`，核心套件則停筆後用這個基準線只補新增筆畫。
    @State private var coreInkBaselines: [Int: PKDrawing] = [:]
    @State private var pendingCoreInk: [Int: PKDrawing] = [:]
    @State private var coreInkWork: DispatchWorkItem? = nil
    @State private var canvasView: PKCanvasView? = nil
    @State private var currentPageHeight: CGFloat = PageGeometry.height
    /// 掌拒（工作項 S-45）。判定規則走核心，與 Android 同一份。
    @State private var palmRejection = PalmRejectionCoordinator()
    @State private var showToolbarCustomization = false
    @State private var showPalmThresholdSheet = false
    @State private var showAdvancedPenSettingsSheet = false
    @State private var showExportPreview = false
    @State private var wantsShareAfterPreview = false
    @State private var hasLassoSelection: Bool = false
    @State private var showExtendedBanner: Bool = false

    @State private var canvasZoomScale: CGFloat = 1.0
    @State private var canvasContentOffset: CGPoint = .zero

    // 實體工具列狀態
    @State private var selectedTool: EditorToolType = .pen
    @State private var previousTool: EditorToolType?
    @State private var lastObservedTool: EditorToolType = .pen

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
    
    @State private var eraserMode: EraserMode = .stroke
    @State private var pixelEraserWidth: CGFloat = 20.0
    
    @State private var showLassoColorPicker: Bool = false

    // 彈窗與輔助狀態
    @State private var showRenameAlert: Bool = false
    @State private var renameText: String = ""
    @State private var showShareSheet: Bool = false
    /// 匯出之後要開的是**儲存對話框**（而不是分享面板）。
    @State private var showSaveDialog: Bool = false
    @State private var showClearConfirmAlert: Bool = false
    @State private var exportPdfData: Data? = nil
    /// 這一次匯出的副檔名。
    ///
    /// 原本分享表一律叫 `<標題>.pdf` —— 選「匯出圖片」拿到的是一個
    /// **副檔名寫著 pdf、內容卻是 PNG** 的檔案，收到的人打不開，
    /// 使用者看到的是「我選了圖片，它給我 PDF」（實機回報過）。
    @State private var exportFileExtension: String = "pdf"

    // 圖片、算式、圖表、文字與連結狀態
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showPhotoPicker: Bool = false
    /// 從「檔案」挑圖，而不是從相簿。
    ///
    /// 相簿挑得到的只有相簿裡的東西 —— 使用者掃描的 PDF 轉出的 PNG、
    /// 從 Mac 拖進 iCloud 雲碟的那張圖，`PhotosPicker` 一張都看不到。
    @State private var showImageFileImporter: Bool = false
    /// 從「檔案」挑音訊。App 自己錄的那些走 `showAudioPicker`。
    @State private var showAudioFileImporter: Bool = false
    /// 挑一份 PDF 插進來。PDF 只有這一個入口 —— 它從來不會在相簿裡。
    @State private var showPdfFileImporter: Bool = false
    @State private var showDocumentFileImporter: Bool = false
    /// 已經收進來、正在讓使用者挑頁的那份 PDF。
    @State private var pdfToInsert: URL? = nil
    /// 匯入失敗的語系鍵。非空就跳提示。
    @State private var importErrorKey: String = ""
    @State private var showStickerLibrary: Bool = false
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
    /// 隨點隨打就地輸入狀態（連動 TextAttachmentItemView 的焦點與鍵盤）
    @State private var inlineEditingTextId: String? = nil
    @State private var snapToGrid: Bool = true
    @State private var newTextDraft: NoteTextAttachment = NoteTextAttachment()
    @State private var showLinkPreviewSheet: Bool = false
    @State private var showProColorPicker: Bool = false
    @State private var showProColorWheel: Bool = false

    // 🌟 次世代雙模核心狀態（動態傳送門、防抖修正、對稱尺規、極簡收折、局部畫布、徑向飛輪）
    @State private var activeInlineInkBlockId: String? = nil
    @State private var strokeStabilizer: Double = 0.0
    @State private var isSymmetryActive: Bool = false
    @State private var isMinimalistCanvasActive: Bool = false
    @State private var isFloatingPillExpanded: Bool = false
    @State private var showRadialMenu: Bool = false
    @State private var radialMenuCenter: CGPoint = CGPoint(x: 200, y: 200)
    @State private var magneticGuideActive: Bool = false
    @State private var magneticGuideStart: CGPoint = .zero
    @State private var magneticGuideEnd: CGPoint = .zero

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
    /// 辨識手寫剛被按下 —— 只給提示用。
    ///
    /// 其他三個功能本身就是布林模式，辨識手寫不是（它跑完就結束），
    /// 所以要一個獨立的旗標才跳得出提示。
    @State private var isRecognisingHandwriting = false
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

    /// 畫布上的提示（例如「超出可列印範圍」）。nil 代表沒有要說的話。
    @State private var canvasNotice: String?
    @State private var canvasNoticeToken: Int = 0

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
    /// `dropTargetFolderId` 用 nil 代表「沒有任何東西懸停」，所以「懸停在
    /// 未分類區」需要另一個值，不能也用 nil。
    private let unfiledDropKey = "__kairumo_unfiled__" 
    /// 拖曳中的筆記本落在「根目錄」上。根目錄那一列一直都在，
    /// 而「未分類檔案」那一段在沒有未分類筆記時整段不存在 ——
    /// 於是把最後一本筆記歸檔之後，就再也沒有地方可以把它拖回來。
    @State private var isRootDropTargeted: Bool = false

    // MARK: - 頁面結構欄的拖曳與縮放
    /// 拖曳懸停中的頁碼（畫插入指示線用）。
    @State private var dropTargetPageIndex: Int? = nil
    /// 多選模式下已選取的頁碼。
    ///
    /// 空集合**不等於**沒有進入多選模式 —— 進了模式還沒選是正常狀態，
    /// 用集合是否為空判斷的話，取消勾選最後一頁時整排操作會突然消失。
    @State private var pageSelection: Set<Int> = []
    @State private var isSelectingPages: Bool = false
    /// 目的筆記本選擇器：nil 代表沒開；true 是複製、false 是搬移。
    @State private var transferIsCopy: Bool? = nil
    /// 使用者要的縮圖寬度（pt）。落盤。
    ///
    /// 存絕對寬度而不是倍率：倍率的基準是側欄寬度，而側欄寬度也是使用者
    /// 在調的 —— 兩個都在動的話，拉寬側欄會讓縮圖跟著跳一次，
    /// 而使用者只是想把欄位拉寬一點看資料夾名稱。
    @AppStorage("kairumo_editor_page_thumb_width") private var pageThumbnailWidth: Double = 240
    /// 編輯工作區目前可用的總寬度。夾側欄寬度要用到它。
    ///
    /// # 為什麼是 @State 而不是 Environment
    ///
    /// 側欄的內容（縮圖卡片、底部的大小控制）與套用 `.environment` 的那一層
    /// 是**同一個 View 結構**的兩個 computed property —— 而 `@Environment`
    /// 讀的是這個結構自己收到的環境，不是它加到子樹上的那一份。
    /// 第一次寫成 Environment 的版本編得過、跑起來縮圖永遠停在 248pt，
    /// 因為它讀到的一直是預設值 280。
    @State private var editorAvailableWidth: CGFloat = 1024
    /// 使用者拖動界線之後的側欄寬度。落盤 —— 每次開筆記都要重調一次的設定
    /// 不算設定，只是每次都要做一遍的事。
    @AppStorage("kairumo_editor_sidebar_width") private var storedSidebarWidth: Double = 280
    /// 拖曳界線期間的暫時寬度。放開才落盤，拖曳中每一格都寫 UserDefaults
    /// 會在拖動時卡頓。
    @State private var draggingSidebarWidth: CGFloat? = nil

    // 次世代 UI/UX Phase 5: 折疊立起雙屏模式 (Tabletop Mode / Stage Manager Posture)
    @State private var isTabletopMode: Bool = false
    // 次世代 UI/UX Phase 4: 筆跡磁吸對齊與幾何角度引導 (Smart Magnetic Snap)
    @State private var isMagneticSnapActive: Bool = false

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

            // 2. 🌟 實體模式專屬工具列（手繪模式 vs 打字文書處理模式）
            //
            // **只有「上」這個位置畫在這裡**（S-261b）。左／右／下由
            // `canvasWithToolbar` 貼在畫布旁邊，收合則完全不畫 ——
            // 那時只剩浮動的工具丸。
            //
            // 可移動是刻意的：工具列頂部固定時，**左撇子與橫向書寫會擋手**。
            if effectiveToolbarMode == .draw {
                if !isMinimalistCanvasActive && toolbarSettings.placement == .top {
                    drawingToolbar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            } else {
                wordModeToolbar
            }

            // 3. 尺規旋轉與量測輔助列（若尺規開啟時顯示）
            if isRulerActive {
                rulerControlBar
            }

            // 4. 若目前筆記有已錄音音檔，顯示音訊播放控制條
            if notebook.hasRecording, let audioPath = notebook.recordingAudioPath {
                audioPlaybackBar(fileName: audioPath)
            }

            // 5. 若目前正在進行或暫停錄音，顯示即時錄音波形橫條
            if audioManager.status == .recording || audioManager.status == .paused {
                liveRecordingBar
            }

            // 6. 核心編輯工作區（包含左側筆記結構欄與右側畫布區）
            GeometryReader { geo in
                let metrics = layoutMetrics(width: Float(geo.size.width))
                if isTabletopMode {
                    // 立起雙屏模式：上方顯示主要畫布／預覽區，下方為沉浸式觸控工具盤
                    VStack(spacing: 0) {
                        ZStack(alignment: .topLeading) {
                            canvasWorkArea

                            HStack(spacing: 6) {
                                Image(systemName: "laptopcomputer.and.ipad")
                                    .font(.system(size: 11, weight: .bold))
                                Text(L("posture_tabletop_mode"))
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(uiColor: .systemBackground).opacity(0.85))
                            .cornerRadius(12)
                            .padding(8)
                        }
                        .frame(height: max(geo.size.height * 0.55, 180))

                        Divider()

                        tabletopControlDeck
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(uiColor: .secondarySystemBackground))
                    }
                } else {
                    HStack(spacing: 0) {
                        if showStructureSidebar && metrics.sidebarIsInline {
                            let width = resolvedSidebarWidth(total: geo.size.width)
                            notebookStructureSidebar
                                .frame(width: width)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                            sidebarResizeHandle(total: geo.size.width, current: width)
                        }

                        // 核心手寫（支援全品牌手寫筆） vs 打字排版模式（共用畫布，維持樣板與置中）
                        canvasWorkArea
                    }
                    .onAppear { editorAvailableWidth = geo.size.width }
                    .onChange(of: geo.size.width) { newValue in
                        editorAvailableWidth = newValue
                    }
                    .sheet(isPresented: Binding(
                        get: { showStructureSidebar && !metrics.sidebarIsInline },
                        set: { if !$0 { showStructureSidebar = false } }
                    )) {
                        resizableSheet { notebookStructureSidebar }
                    }
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
                selectEditorTool(EditorToolType.allCases[index])
            }
        }
        .overlay(alignment: .bottomLeading) {
            // 🌟 響應式極簡畫布模式：單一懸浮點 / 快捷氣泡（掛在最外層視窗，不受畫布縮放與單頁/連續模式影響）
            if effectiveToolbarMode == .draw && isMinimalistCanvasActive {
                FloatingToolPill(
                    isExpanded: $isFloatingPillExpanded,
                    currentToolIcon: selectedTool.iconName,
                    currentColorHex: selectedColor.toHex() ?? "#000000",
                    currentStrokeWidth: strokeWidth,
                    toolboxTitle: localizationManager.localized("minimal_toolbox"),
                    expandLabel: localizationManager.localized("expand_minimal_toolbox"),
                    collapseLabel: localizationManager.localized("collapse_minimal_toolbox"),
                    exitMinimalLabel: localizationManager.localized("exit_canvas_minimal_mode"),
                    onRestore: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                            isMinimalistCanvasActive = false
                            isFloatingPillExpanded = true
                        }
                    }
                ) {
                    drawingToolbarContent
                }
                .padding(20)
                .shadow(color: Color.black.opacity(0.2), radius: 10, y: 4)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .background {
            // 實體鍵盤 Esc 鍵支援一鍵退出畫布極簡模式
            if isMinimalistCanvasActive {
                Button("") {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                        isMinimalistCanvasActive = false
                    }
                }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
                .allowsHitTesting(false)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarBackButtonHidden(true)
        // Apple Pencil 雙擊要切回「最後用過的筆刷」（工作項 S-67），
        // 所以每次換工具都要把筆刷記下來。橡皮擦與套索不算筆刷。
        .onChange(of: selectedTool) { tool in
            if tool == .lasso, lastObservedTool != .lasso {
                previousTool = lastObservedTool
            }
            if tool.isBrush { lastBrushTool = tool }
            lastObservedTool = tool
        }
        .onChange(of: notebook.id) { _ in
            // 外層換綁之後才會走到這裡，這時 notebook 已經是新的那一則。
            currentPageIndex = 0
            coreInkBaselines.removeAll()
            pendingCoreInk.removeAll()
            coreInkWork?.cancel()
            coreInkWork = nil
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
            store.activeNotebookId = notebook.id
            sanitizeTextAttachments()
            loadCurrentPage()
            MacWindowTitle.apply()
            // 進到編輯器時也亮一次：第一次開的人要知道自己在哪個模式。
            flashModeBadge()
        }
        .onDisappear {
            if store.activeNotebookId == notebook.id {
                store.activeNotebookId = nil
            }
            saveCurrentPageDrawing()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background || phase == .inactive {
                saveCurrentPageDrawing()
            }
        }
        .sheet(isPresented: $showShareSheet) { erasedView {
            if let data = exportPdfData {
                ShareActivityView(
                    data: data,
                    filename: "\(notebook.displayTitle()).\(exportFileExtension)")
            }
        } }
        .sheet(isPresented: $showSaveDialog) { erasedView {
            if let data = exportPdfData {
                SaveToFilesView(
                    data: data,
                    filename: "\(notebook.displayTitle()).\(exportFileExtension)")
            }
        } }
        .sheet(isPresented: $showStickerLibrary) { resizableSheet {
            StickerLibraryView { drawing in
                // **拿不到畫布就要說一聲。**
                //
                // 原本這裡是 `guard let canvas = canvasView else { return }`
                // —— 靜靜地什麼都不做。使用者挑了一張貼紙、面板關上、
                // 畫布上什麼也沒有，而且沒有任何線索。回報就是
                // 「無法插入 Sticker」。
                //
                // 貼紙是貼成**筆跡**的（所以可以擦、可以套索搬走），
                // 那需要畫布在場。打字模式下畫布不吃筆跡，所以先講清楚
                // 要切回手寫模式。
                // 同上：要驗「拿不到畫布時會不會出聲」，就要能把畫布拿走。
                let noCanvas = ProcessInfo.processInfo
                    .environment["KAIRUMO_UITEST_NO_CANVAS"] == "1"
                guard let canvas = canvasView, !noCanvas else {
                    showCanvasNotice(localizationManager.localized("insert_needs_canvas"))
                    return
                }
                let visibleRect = canvas.bounds
                let drawingCenter = CGPoint(x: drawing.bounds.midX, y: drawing.bounds.midY)
                let targetCenter = CGPoint(x: visibleRect.midX, y: visibleRect.midY)
                let transform = CGAffineTransform(translationX: targetCenter.x - drawingCenter.x, y: targetCenter.y - drawingCenter.y)
                let translatedStrokes = drawing.strokes.map {
                    PKStroke(ink: $0.ink, path: $0.path, transform: $0.transform.concatenating(transform), mask: $0.mask)
                }
                var newDrawing = canvas.drawing
                newDrawing.strokes.append(contentsOf: translatedStrokes)
                canvas.drawing = newDrawing
                self.currentDrawing = newDrawing
                self.saveCurrentPageDrawing()
            }
        } }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        // 三個修飾詞收在一個 `ViewModifier` 裡。
        //
        // **不是為了好看**：這條鏈已經長到編譯器會放棄的程度 ——
        // 直接把三個攤在這裡，`body` 就會撞上
        // 「unable to type-check this expression in reasonable time」，
        // 而錯誤指的是整條鏈的開頭，看不出是哪一個加上去的。
        .modifier(ImportPickersModifier(
            showImageFileImporter: $showImageFileImporter,
            showAudioFileImporter: $showAudioFileImporter,
            importErrorKey: $importErrorKey,
            onImage: { outcome in
                // 存進附件目錄之後再讀回來解碼。先解碼再存的話，一個看起來
                // 像圖但其實壞掉的檔會在畫布上變成一個永遠空白的方塊。
                let url = store.importedFileURL(fileName: outcome.storedName)
                guard let data = try? Data(contentsOf: url),
                      let image = UIImage(data: data) else {
                    importErrorKey = "import_failed_read"
                    return
                }
                insertImageAttachment(image)
            },
            onAudio: { outcome in insertImportedAudio(outcome) },
            showPdfFileImporter: $showPdfFileImporter,
            onPdf: { outcome in
                pdfToInsert = store.importedFileURL(fileName: outcome.storedName)
            },
            showDocumentFileImporter: $showDocumentFileImporter,
            onDocument: { outcome in store.importDocument(notebookId: notebook.id, pageIndex: currentPageIndex, outcome: outcome) }
        ))
        .sheet(item: Binding(
            get: { pdfToInsert.map(IdentifiedURL.init) },
            set: { if $0 == nil { pdfToInsert = nil } })
        ) { wrapped in
            resizableSheet {
                PdfPageInsertSheet(fileURL: wrapped.url) { image in
                    insertImageAttachment(image)
                }
            }
        }
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
                if let idx = notebook.textAttachments?.firstIndex(where: { $0.id == created.id }) {
                    notebook.textAttachments?[idx] = created
                } else {
                    notebook.textAttachments?.append(created)
                }
                store.updateNotebook(notebook)
                PageThumbnailRenderer.invalidateAll()
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
        // 分享面板要等預覽**收乾淨之後**再開。
        //
        // 在預覽還在收起的時候直接 `showShareSheet = true`，SwiftUI 會把
        // 第二個 sheet 吞掉 —— 使用者按了「匯出」，畫面關掉，然後什麼都沒發生。
        // 所以預覽只留下一個意願旗標，真正的呈現放在 `onDismiss`。
        .sheet(
            isPresented: $showExportPreview,
            onDismiss: {
                if wantsShareAfterPreview {
                    wantsShareAfterPreview = false
                    showShareSheet = true
                }
            }
        ) {
            ExportPreviewSheet(
                data: exportPdfData ?? Data(),
                fileExtension: exportFileExtension,
                onExport: { wantsShareAfterPreview = true })
        }
        // 四個「按下去之後還要再做一個動作」的功能，第一次用時給一則提示
        // （使用者回報：不知道該怎麼操作）。內容與 id 都來自核心，
        // 兩端同一份 —— 鍵不一樣的話，在一台裝置上關掉的提示會在另一台冒出來。
        .featureHint("hint.comment_pin", trigger: isPlacingCommentPin)
        .featureHint("hint.refine_sketch", trigger: showSketchRefineBar)
        .featureHint("hint.tabletop", trigger: isTabletopMode)
        .featureHint("hint.recognize", trigger: isRecognisingHandwriting)
        .sheet(isPresented: $showToolbarCustomization) {
            NavigationStack { ToolbarCustomizationView() }
        }
        // UI 測試直接把這張表叫出來。
        //
        // 不是為了偷懶 —— 這個入口在「更多」選單裡，而 SwiftUI 的 `Menu`
        // 內容**根本不會出現在 XCUITest 的無障礙樹裡**（點開之後掃到的只有
        // 工具列那些控制項）。編輯器稽核那 40 項菜單內控制項全部進棘輪
        // 也是同一個原因。走不到選單就驗不了這張表，而這張表值得驗 ——
        // 十三個開關少一個，使用者就有一支筆關不掉。
        .onAppear {
            if ProcessInfo.processInfo.environment["KAIRUMO_UITEST_TOOLBAR"] == "1" {
                showToolbarCustomization = true
            }
        }
        .sheet(isPresented: $showPalmThresholdSheet) {
            // 改完立刻套進仲裁器。存了卻要重開筆記本才生效的話，
            // 使用者會以為設定沒有存到，然後再調一次。
            PalmThresholdSheet { palmRejection.applyStoredThresholds() }
        }
        .sheet(isPresented: $showAdvancedPenSettingsSheet) {
            AdvancedPenSettingsSheet()
        }
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
        .background(Color.clear.alert(localizationManager.localized("clear_page"), isPresented: $showClearConfirmAlert) {
            Button(localizationManager.localized("cancel"), role: .cancel) {}
            Button(localizationManager.localized("clear_confirm"), role: .destructive) {
                currentDrawing = PKDrawing()
                store.saveDrawing(notebookId: notebook.id, pageIndex: currentPageIndex, drawing: currentDrawing)
            }
        } message: {
            Text(localizationManager.localized("clear_page_confirm"))
        })
        .background(Color.clear.alert(localizationManager.localized("mic_permission_title"), isPresented: $audioManager.showPermissionAlert) {
            Button(localizationManager.localized("cancel"), role: .cancel) {
                audioManager.showPermissionAlert = false
            }
            Button(localizationManager.localized("open_settings")) {
                audioManager.openSystemSettings()
            }
        } message: {
            Text(localizationManager.localized("mic_permission_msg"))
        })
        .background(Color.clear.alert(localizationManager.localized("delete_page"), isPresented: $showDeletePageAlert) {
            Button(localizationManager.localized("cancel"), role: .cancel) {}
            Button(localizationManager.localized("delete_page"), role: .destructive) {
                if let idx = pageToDeleteIndex {
                    deletePage(at: idx)
                }
            }
        } message: {
            Text(String(format: localizationManager.localized("delete_page_confirm_msg"), (pageToDeleteIndex ?? 0) + 1))
        })
        .background(Color.clear.alert(localizationManager.localized("edit_root_folder"), isPresented: $showRenameRootFolderAlert) {
            TextField(localizationManager.localized("root_folder"), text: $rootFolderRenameText)
            Button(localizationManager.localized("cancel"), role: .cancel) {}
            Button(localizationManager.localized("confirm")) {
                store.renameRootFolder(newName: rootFolderRenameText)
            }
        })
        .background(Color.clear.alert(localizationManager.localized("new_subfolder"), isPresented: $showNewFolderAlert) {
            TextField(localizationManager.localized("folder_name"), text: $newFolderNameText)
            Button(localizationManager.localized("cancel"), role: .cancel) {}
            Button(localizationManager.localized("confirm")) {
                _ = store.createFolder(name: newFolderNameText, parentId: newFolderParentId)
                newFolderNameText = ""
            }
        })
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
            editorModeSwitcher()

            // 🌟 畫布極簡模式恢復按鈕（讓使用者一秒找到退出鍵）
            if isMinimalistCanvasActive {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                        isMinimalistCanvasActive = false
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12, weight: .bold))
                        Text(localizationManager.localized("exit_canvas_minimal_mode"))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor, in: Capsule())
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 4, y: 1)
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized("exit_canvas_minimal_mode"))
                .accessibilityLabel(localizationManager.localized("exit_canvas_minimal_mode"))
            }

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

            // 次世代 UI/UX Phase 5: 立起雙屏模式 (Tabletop Mode)
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isTabletopMode.toggle()
                }
            } label: {
                Image(systemName: isTabletopMode ? "laptopcomputer.and.ipad" : "ipad.landscape")
                    .foregroundColor(isTabletopMode ? .accentColor : .secondary)
                    .padding(5)
                    .background(isTabletopMode ? Color.accentColor.opacity(0.15) : Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(6)
            }
            .accessibilityLabel(L("posture_tabletop_mode"))
            .help(L("posture_tabletop_mode"))

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
            if audioManager.status == .recording || audioManager.status == .paused {
                Button {
                    stopAndSaveRecording()
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(audioManager.status == .recording ? Color.red : Color.orange)
                            .frame(width: 7, height: 7)
                        Text(localizationManager.localized("stop_recording"))
                            .font(.caption2)
                            .foregroundColor(audioManager.status == .recording ? .red : .orange)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background((audioManager.status == .recording ? Color.red : Color.orange).opacity(0.12))
                    .cornerRadius(6)
                }
            } else {
                Button {
                    Task {
                        _ = await audioManager.startRecording(
                            notebookId: notebook.id,
                            notebookTitle: notebook.displayTitle(),
                            title: "\(notebook.displayTitle()) \(localizationManager.localized("recording_suffix"))",
                            pageIndex: currentPageIndex,
                            languageTag: LocalizationManager.shared.currentLanguage.rawValue)
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
        .accessibilityIdentifier("editor.home")

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
        .accessibilityIdentifier("editor.sidebar_toggle")

        // 模式切換（緊湊圖標）
        editorModeSwitcher()
            .accessibilityIdentifier("editor.mode")

        if isMinimalistCanvasActive {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                    isMinimalistCanvasActive = false
                }
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Color.accentColor, in: Circle())
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 3, y: 1)
            }
            .buttonStyle(.plain)
            .help(localizationManager.localized("exit_canvas_minimal_mode"))
            .accessibilityLabel(localizationManager.localized("exit_canvas_minimal_mode"))
        }

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
        .accessibilityIdentifier("editor.title")

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
            .accessibilityIdentifier("editor.page.prev")

            Text("\(currentPageIndex + 1)/\(max(1, notebook.pageCount))")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .accessibilityIdentifier("editor.page.indicator")

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
            .accessibilityIdentifier("editor.page.next")

            Button {
                addNewPage()
            } label: {
                Image(systemName: "plus.square.dashed")
                    .foregroundColor(.accentColor)
            }
            .accessibilityIdentifier("editor.page.add")

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
            .accessibilityIdentifier("editor.page.display_mode")
        }

        // ⋯ 更多（次要功能收在這裡）
        //
        // 緊湊模式下不再把每個功能都攤在工具列上 —— 視窗一窄就會互相擠掉。
        // 主要動作（首頁、模式、頁碼、錄音、匯出）留在列上，其餘收進選單，
        // 位置固定、不會因為視窗寬度而消失。
        pageFormatMenu
            .accessibilityIdentifier("editor.page_format")

        guidePaletteMenu
            .accessibilityIdentifier("editor.guide_palette")

        Menu {
            Section {
                Button { showAssetLibrarySheet = true } label: { Label(localizationManager.localized("asset_library"), systemImage: "shippingbox.fill") }
                    .accessibilityIdentifier("editor.insert.assets")
                Button { showStickerLibrary = true } label: { Label(localizationManager.localized("sticker_library"), systemImage: "photo.on.rectangle") }
                    .accessibilityIdentifier("editor.insert.stickers")
                    Button { showAudioPicker = true } label: { Label(localizationManager.localized("insert_audio"), systemImage: "waveform.badge.plus") }
                        .accessibilityIdentifier("editor.insert.audio")
                    Button { showAudioFileImporter = true } label: { Label(localizationManager.localized("import_audio_from_files"), systemImage: "square.and.arrow.down.on.square") }
                        .accessibilityIdentifier("editor.insert.audio_file")
                Button { showPhotoPicker = true } label: { Label(localizationManager.localized("insert_image"), systemImage: "photo.badge.plus") }
                    .accessibilityIdentifier("editor.insert.image")
                Button { showImageFileImporter = true } label: { Label(localizationManager.localized("import_from_files"), systemImage: "folder.badge.plus") }
                    .accessibilityIdentifier("editor.insert.image_file")
                Button { showPdfFileImporter = true } label: { Label(localizationManager.localized("insert_pdf"), systemImage: "doc.richtext") }
                    .accessibilityIdentifier("editor.insert.pdf")
                Button { showDocumentFileImporter = true } label: { Label(localizationManager.localized("import_document"), systemImage: "doc.text") }
                    .accessibilityIdentifier("editor.insert.document")
                Button { showMathCalculator = true } label: { Label(localizationManager.localized("math_calc"), systemImage: "plus.forwardslash.minus") }
                    .accessibilityIdentifier("editor.insert.math")
                Button { showChartStudio = true } label: { Label(localizationManager.localized("chart_studio"), systemImage: "chart.bar.xaxis") }
                    .accessibilityIdentifier("editor.insert.chart")
                Button { insertDefaultTable() } label: { Label(localizationManager.localized("table_studio"), systemImage: "tablecells") }
                    .accessibilityIdentifier("editor.insert.table")
                // **開工作室，不要默默丟一個矩形。**
                //
                // 這一項原本呼叫 `insertDefaultShape()`：在 (200, 200) 塞一個
                // 預設矩形就結束。標籤寫著「形狀工作室」，使用者點下去卻
                // 沒有任何面板 —— 而那個矩形可能落在畫面外或被當成雜訊，
                // 所以回報是「點了沒反應」。
                //
                // 工作室（`ShapeStudioView`）一直都在，而且另一個插入選單
                // 早就接著它了；只有這個主選單接錯了。
                Button { showShapeStudio = true } label: { Label(localizationManager.localized("shape_studio"), systemImage: "square.on.circle") }
                    .accessibilityIdentifier("editor.insert.shape")
                Button { show3DStudio = true } label: { Label(localizationManager.localized("insert_3d"), systemImage: "cube.transparent") }
                    .accessibilityIdentifier("editor.insert.model3d")
                Button { showThemeToolsSheet = true } label: { Label(localizationManager.localized("theme_tools"), systemImage: "paintpalette.fill") }
                    .accessibilityIdentifier("editor.insert.theme_tools")
            } header: {
                Text(localizationManager.localized("insert_object"))
            }

            Section {
                Button { withAnimation { showSketchRefineBar.toggle() } } label: { Label(localizationManager.localized("refine_sketch"), systemImage: "wand.and.stars") }
                    .accessibilityIdentifier("editor.insert.refine_sketch")
                // 掌拒門檻（S-101）。判定一直都在核心，缺的只是「讓使用者調」——
                // 握筆姿勢比較特別的人，手掌一放上去就是一道線，
                // 而在此之前他完全沒有辦法處理。
                Button { showPalmThresholdSheet = true } label: {
                    Label(localizationManager.localized("palm_rejection_settings"), systemImage: "hand.raised.slash")
                }
                .accessibilityIdentifier("editor.insert.palm_thresholds")
                Button { showAdvancedPenSettingsSheet = true } label: {
                    Label(localizationManager.localized("pen_settings_title"), systemImage: "applepencil.and.scribble")
                }
                .accessibilityIdentifier("editor.insert.advanced_pen_settings")
                // 放在編輯器而不是設定頁：使用者想關掉某支筆的那一刻，
                // 是他正看著那支筆的時候。
                Button { showToolbarCustomization = true } label: {
                    Label(localizationManager.localized("customize_toolbar"), systemImage: "slider.horizontal.3")
                }
                .accessibilityIdentifier("editor.customize_toolbar")
                Button { withAnimation { isPlacingCommentPin.toggle() } } label: { Label(localizationManager.localized("add_comment_pin"), systemImage: "text.bubble.fill") }
                    .accessibilityIdentifier("editor.insert.comment_pin")
                Button { showCollaborationSheet = true } label: { Label(localizationManager.localized("collaborate"), systemImage: "person.2.fill") }
                    .accessibilityIdentifier("editor.insert.collaborate")
                Button { recognizeHandwritingOnCurrentPage() } label: {
                    Label(localizationManager.localized("recognize_handwriting"), systemImage: "text.viewfinder")
                }
                .accessibilityIdentifier("editor.insert.recognize")
                Button { showNoteIntelligence = true } label: {
                    Label(localizationManager.localized("ai_summary"), systemImage: "sparkles")
                }
                .accessibilityIdentifier("editor.insert.ai_summary")

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isTabletopMode.toggle()
                    }
                } label: {
                    Label(L("posture_tabletop_mode"), systemImage: "laptopcomputer.and.ipad")
                }
                .accessibilityIdentifier("editor.tabletop_mode")
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
        .accessibilityIdentifier("editor.more")

        // 錄音
        if audioManager.status == .recording || audioManager.status == .paused {
            Button {
                stopAndSaveRecording()
            } label: {
                Circle()
                    .fill(audioManager.status == .recording ? Color.red : Color.orange)
                    .frame(width: 12, height: 12)
                    .padding(5)
                    .background((audioManager.status == .recording ? Color.red : Color.orange).opacity(0.15))
                    .cornerRadius(6)
            }
            .accessibilityIdentifier("editor.record")
        } else {
            Button {
                Task {
                    // **失敗要讓使用者看見。**
                    //
                    // 原本是 `_ = await ...` —— 回傳值直接丟掉。而
                    // `startRecording` 有三處會靜靜地回 false（權限被拒、
                    // 開不了套件、擷取啟動失敗），於是按下去之後畫面上
                    // 什麼都不會發生，使用者回報的就是「錄音鈕沒反應」。
                    //
                    // 權限被拒那一條由 `AudioRecorderManager` 自己跳系統
                    // 提示（`showPermissionAlert`），其餘的在這裡說一聲。
                    // **可以從外面把它弄壞。**
                    //
                    // 「失敗時會不會出聲」這件事，不製造一次失敗是驗不到的
                    // —— 而沒有測試守著的修正，等於一個還沒發生的回歸
                    // （筆跡那一條就是這樣活了很久）。
                    let forcedFailure = ProcessInfo.processInfo
                        .environment["KAIRUMO_UITEST_FAIL_RECORDING"] == "1"
                    let started = forcedFailure
                        ? false
                        : await audioManager.startRecording(
                            notebookId: notebook.id,
                            notebookTitle: notebook.displayTitle(),
                            title: "\(notebook.displayTitle()) \(localizationManager.localized("recording_suffix"))",
                            pageIndex: currentPageIndex,
                            languageTag: LocalizationManager.shared.currentLanguage.rawValue)
                    if !started && !audioManager.showPermissionAlert {
                        showCanvasNotice(localizationManager.localized("recording_failed"))
                    }
                }
            } label: {
                Image(systemName: "mic.fill")
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(5)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(6)
            }
            .accessibilityIdentifier("editor.record")
        }

        // 匯出功能選單
        Menu {
            Button { exportAsPdf() } label: { Label(localizationManager.localized("export_pdf"), systemImage: "doc.text.fill") }
                .accessibilityIdentifier("editor.export.pdf")
            Button { exportAsPngImage() } label: { Label(localizationManager.localized("export_image"), systemImage: "photo") }
                .accessibilityIdentifier("editor.export.image")
            Button { printCurrentNotebook() } label: { Label(localizationManager.localized("print_note"), systemImage: "printer.fill") }
                .accessibilityIdentifier("editor.export.print")
            Divider()
            // **把檔案存到使用者自己選的位置。**
            //
            // 分享面板可以把檔案送去別的 App，但它不是儲存對話框 ——
            // 使用者沒辦法說「存到我的文件資料夾」。而這個 App 的資料全部
            // 在沙盒容器裡，容器是隱藏的、使用者碰不到。Mac App Store 審查
            // 指南 2.4.5(i) 因此把這個版本退了回來。
            Button { saveNotebookFile() } label: { Label(localizationManager.localized("export_save_as"), systemImage: "folder.badge.plus") }
                .accessibilityIdentifier("editor.export.save_as")
            Button { shareNotebookFile() } label: { Label(localizationManager.localized("share_note"), systemImage: "square.and.arrow.up") }
                .accessibilityIdentifier("editor.export.share")
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(5)
                .background(Color.accentColor)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("editor.share")
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

    // MARK: - 3-1. 🌟 Office Word / Google Docs 居中標準文件紙張編輯區
    private var wordDocumentArea: AnyView {
        AnyView(wordDocumentAreaContent)
    }

    private var wordDocumentAreaContent: some View {
        WordDocumentEditorView(
            notebook: $notebook,
            pageIndex: currentPageIndex,
            activeTextDraft: Binding(
                get: { activeTextAttachment ?? NoteTextAttachment(pageIndex: currentPageIndex) },
                set: { updated in
                    if notebook.textAttachments == nil { notebook.textAttachments = [] }
                    if let idx = notebook.textAttachments?.firstIndex(where: { $0.id == updated.id }) {
                        notebook.textAttachments?[idx] = updated
                    } else {
                        notebook.textAttachments?.append(updated)
                    }
                    store.updateNotebook(notebook)
                    PageThumbnailRenderer.invalidateAll()
                }
            ),
            activeInlineInkBlockId: $activeInlineInkBlockId,
            onCommit: {
                store.updateNotebook(notebook)
                PageThumbnailRenderer.invalidateAll()
            },
            onInsertTable: {
                let table = NoteTableAttachment(pageIndex: currentPageIndex, x: 40, y: 120, rows: 3, cols: 3)
                if notebook.tableAttachments == nil { notebook.tableAttachments = [] }
                notebook.tableAttachments?.append(table)
                store.updateNotebook(notebook)
                PageThumbnailRenderer.invalidateAll()
            },
            onInsertImage: { showPhotoPicker = true }
        )
    }

    /// 畫布工作區。抽出來並加上 AnyView 邊界 —— 這一塊（畫布 + 附件圖層 +
    /// 圖釘 + 浮動列）原本整棵樹的型別都被編進 body 的 mangled 名稱裡。
    private var canvasWorkArea: AnyView {
        // 兩條完全獨立的路。連續模式不碰整頁模式的任何一行 ——
        // 那一段綁著存檔、協同、掌拒與套索，是最沒本錢壞掉的地方。
        let canvas: AnyView = switch pageDisplayMode {
        case .single:     AnyView(singlePageWorkArea)
        case .continuous: AnyView(continuousPagesContent)
        }
        // **提示條掛在兩種模式共用的這一層。**
        //
        // 它原本只長在 `singlePageWorkArea` 裡，於是連續模式下
        // `showCanvasNotice(...)` 等於什麼都沒做 —— 而那正是它要補的那個洞
        // （失敗時沒有任何回饋）。「有時候會提示、有時候不會」比一直沒提示
        // 更難查。
        return AnyView(
            ZStack(alignment: .bottom) {
                placed(canvas)
                if let notice = canvasNotice {
                    canvasNoticeBanner(notice)
                }
            }
        )
    }

    /// 把工具列貼到畫布的哪一邊（S-261b）。
    ///
    /// 「上」由 `body` 的 VStack 畫（它要排在頂部工作列底下），
    /// 這裡只處理左／右／下與收合。分兩處看起來不漂亮，但合併的代價是
    /// 把整個頂部區塊搬進畫布層 —— 那會動到尺規列、播放列與錄音列的順序。
    ///
    /// 收合（`.collapsed`）時完全不畫：那時使用者要的就是只剩浮動工具丸。
    @ViewBuilder
    private func placed(_ canvas: AnyView) -> some View {
        if effectiveToolbarMode != .draw || isMinimalistCanvasActive {
            canvas
        } else {
            switch toolbarSettings.placement {
            case .top, .collapsed:
                canvas
            case .bottom:
                VStack(spacing: 0) {
                    canvas
                    drawingToolbar
                }
            case .left:
                HStack(spacing: 0) {
                    // 直向工具列要能捲 —— 十三顆按鈕在 iPhone 橫放時
                    // 高度不夠，不給捲的話下面幾顆永遠點不到。
                    ScrollView(.vertical) { drawingToolbar }
                        .frame(maxWidth: 96)
                    canvas
                }
            case .right:
                HStack(spacing: 0) {
                    canvas
                    ScrollView(.vertical) { drawingToolbar }
                        .frame(maxWidth: 96)
                }
            }
        }
    }

    /// 整頁模式：**一頁完整顯示，而且置中。**
    ///
    /// # 原本是什麼樣子
    ///
    /// 畫布直接把可用寬度吃滿（`AdaptiveCanvasView.syncContentSize` 用的是
    /// `bounds.width`），而頁面本身只有 800pt。於是右邊多出一塊空白 ——
    /// 那塊空白**在頁面框線之外**，寫上去的東西不會出現在列印結果裡。
    /// 把左側資料夾欄收起來之後那塊空白更大，看起來像畫布破了一個洞。
    ///
    /// 連續模式一直是「縮到剛好放得下」，整頁模式沒跟上。現在兩邊同一套：
    /// 放不下就等比縮小，放得下就維持原尺寸並置中。
    ///
    /// 只縮不放：放大到超過原尺寸會讓筆跡變糊（圖層是先算繪再變換的）。
    private var singlePageWorkArea: some View {
        GeometryReader { outer in
            // **寬與高都要算。**
            //
            // 原本只算寬度：`canvasWorkAreaContent` 沒有明確高度，於是它拿到
            // 的是「剩下多少就多少」—— 在 iPhone 上工具列吃掉大半螢幕之後
            // 只剩六百點，整張 A4 的版面（1132 點）就被壓進那六百點裡。
            // 使用者看到的是一張被壓扁的紙，底下一大塊空白，而且畫布上那圈
            // 虛線框與真正的可列印範圍對不起來 —— 寫在框裡的字有可能被判定
            // 在範圍外（實機回報過）。
            //
            // 現在把頁面的真實高度給它，再用寬高兩個比例的**較小者**縮放：
            // 整頁一定看得完，而且在可用空間裡盡可能大。
            let availableWidth = max(outer.size.width - 32, 1)
            let availableHeight = max(outer.size.height - 16, 1)
            let scale = min(
                1,
                min(availableWidth / PageGeometry.width, availableHeight / PageGeometry.height)
            )
            ZStack(alignment: .bottom) {
                canvasWorkAreaContent
                    // 頁面用**它自己的尺寸**佈局，再整個縮到放得下 ——
                    // 不給高度的話它會被壓成剩餘空間那麼扁（iPhone 上整張
                    // A4 被壓進六百點，見上面的說明）。
                    .frame(width: PageGeometry.width, height: PageGeometry.height)
                    .scaleEffect(scale, anchor: .center)
                    // 工作區**就是可用空間**，不會因為頁面而長高 ——
                    // 長高的話外層 VStack 會把工具列擠出畫面（踩過）。
                    .frame(width: outer.size.width, height: outer.size.height)
                    // 識別字也掛在 SwiftUI 這一層。
                    //
                    // `PKCanvasView` 自己設了 `accessibilityIdentifier`，但整頁
                    // 模式把它套上 `scaleEffect` 之後，它就不再出現在 XCUITest
                    // 的樹裡 —— 測試說「找不到畫布」而畫面上明明有，VoiceOver
                    // 也就同樣找不到。掛在外層這一個，縮放不會把它吃掉。
                    //
                    // **名字用規格那一個（`editor.canvas`）。** 在此之前畫布有
                    // 兩個名字：真正畫出來的這一層叫 `kairumo.canvas`，而規格
                    // 要求的 `editor.canvas` 掛在另一個**不會被算繪**的分支上。
                    // 於是畫面稽核一直報「少了 editor.canvas」，而那一項被放進
                    // 棘輪、附上一段解釋 —— 解釋是對的，但沒有人回頭把它修好。
                    //
                    // **`children: .contain` 不能拿掉。** 識別字掛在一個
                    // **容器**上，而 SwiftUI 預設會把容器底下的東西合併成
                    // 一個元素 —— 畫布上所有的物件（3D 卡片、圖片、表格…）
                    // 就此從無障礙樹裡消失。症狀認不出來：稽核說「模型上
                    // 沒有縮放把手」，而把手畫得好好的，截圖裡看得見。
                    // 受害的不只是測試 —— VoiceOver 的使用者同樣碰不到
                    // 畫布上的任何物件。
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("editor.canvas")

            }
            .frame(width: outer.size.width, height: outer.size.height)
        }
    }

    // 次世代 UI/UX Phase 5: 立起模式觸控工作盤 (Tabletop Studio Control Deck)
    private var tabletopControlDeck: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                // 1. 頂部狀態標題與收折按鈕
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "laptopcomputer.and.ipad")
                            .foregroundColor(.accentColor)
                        Text(L("posture_tabletop_mode"))
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isTabletopMode = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // 2. 常用工具快速點選盤 (Pen / Highlighter / Eraser / Lasso / Radial / Magnetic / Sticky)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: 10) {
                    // 鋼筆
                    Button {
                        selectEditorTool(.pen)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "pencil.tip")
                                .font(.system(size: 20))
                            Text(L("tool_pen"))
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(selectedTool == .pen ? Color.accentColor.opacity(0.18) : Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedTool == .pen ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)

                    // 螢光筆
                    Button {
                        selectEditorTool(.highlighter)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "highlighter")
                                .font(.system(size: 20))
                            Text(L("tool_highlighter"))
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(selectedTool == .highlighter ? Color.accentColor.opacity(0.18) : Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedTool == .highlighter ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)

                    // 橡皮擦
                    Button {
                        selectEditorTool(.eraser)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "eraser")
                                .font(.system(size: 20))
                            Text(L("tool_eraser"))
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(selectedTool == .eraser ? Color.accentColor.opacity(0.18) : Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedTool == .eraser ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)

                    // 套索工具
                    Button {
                        selectEditorTool(.lasso)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: selectedTool == .lasso ? "xmark.circle.fill" : "lasso")
                                .font(.system(size: 20))
                            Text(L("tool_lasso"))
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(selectedTool == .lasso ? Color.accentColor.opacity(0.18) : Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedTool == .lasso ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)

                    // 徑向飛輪工具盤喚醒 (Radial Menu)
                    Button {
                        radialMenuCenter = CGPoint(x: 200, y: 300)
                        showRadialMenu = true
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "circle.grid.cross")
                                .font(.system(size: 20))
                                .foregroundColor(.purple)
                            Text("Radial")
                                .font(.caption2)
                                .foregroundColor(.purple)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.purple.opacity(0.12))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    // 幾何角度磁吸開關 (Magnetic Snap)
                    Button {
                        isMagneticSnapActive.toggle()
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: isMagneticSnapActive ? "magnet.fill" : "magnet")
                                .font(.system(size: 20))
                                .foregroundColor(isMagneticSnapActive ? .blue : .secondary)
                            Text(L("magnetic_snap_ruler"))
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(isMagneticSnapActive ? Color.blue.opacity(0.18) : Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    // 筆跡文字流式錨定 (Sticky Anchor)
                    Button {
                        anchorSelectedStrokesToNearestText()
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "link.badge.plus")
                                .font(.system(size: 20))
                                .foregroundColor(.orange)
                            Text(L("sticky_anchor_ink"))
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                // 3. 常用顏色調色板與復原/重做/翻頁
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        ForEach([Color.black, Color.blue, Color.red, Color.green, Color.orange, Color.purple], id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Button { performUndo() } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Button { canvasView?.undoManager?.redo() } label: {
                            Image(systemName: "arrow.uturn.forward")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Button { addNewPage() } label: {
                            Image(systemName: "plus.square.dashed")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.accentColor)
                                .frame(width: 36, height: 36)
                                .background(Color.accentColor.opacity(0.15))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 20)
        }
    }

    /// 畫布底部的提示條。
    ///
    /// 用浮動提示而不是 alert：使用者正在寫字，跳一個要按確定的對話框
    /// 會把筆打斷，而這件事沒有嚴重到值得打斷。
    private func canvasNoticeBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(text)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .allowsHitTesting(false)
        // 測試要認得這條提示 —— 「失敗時有沒有出聲」本身就是要守的行為。
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("editor.notice")
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
                            paperId: notebook.paperId(forPage: index),
                            paletteId: notebook.guidePaletteId,
                            store: store,
                            selectedTool: selectedTool,
                            selectedColor: selectedColor,
                            strokeWidth: strokeWidth,
                            isRulerActive: isRulerActive,
                            editorMode: editorMode,
                            eraserMode: eraserMode,
                            pixelEraserWidth: pixelEraserWidth,
                            palmRejection: palmRejection,
                            isFocused: index == currentPageIndex,
                            objectLayer: { objectLayer(forPage: index) },
                            onDrawingChanged: { page, updated in
                                recordDrawingEdit(page: page, drawing: updated)
                                broadcastDrawingChange(page: page, drawing: updated)
                            },
                            onSelectionChanged: { hasLassoSelection = $0 },
                            onReachedPageBottom: { ensureNextPageExists() },
                            canvasRef: { canvasView = $0 },
                            onCanvasTap: { location in
                                currentPageIndex = index
                                handleCanvasTapInTypeMode(at: location)
                            },
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
                            height: PageGeometry.height * scale,
                            alignment: .top
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
                            isEditingInline: Binding(
                                get: { inlineEditingTextId == item.id },
                                set: { editing in
                                    if editing {
                                        inlineEditingTextId = item.id
                                    } else if inlineEditingTextId == item.id {
                                        inlineEditingTextId = nil
                                    }
                                }
                            ),
                            isTypeMode: editorMode == .type,
                            onEdit: {
                                self.editingTextId = item.id
                            },
                            onDelete: {
                                if inlineEditingTextId == item.id { inlineEditingTextId = nil }
                                deletedAttachmentBackup = (type: "text", data: item)
                                collaborationManager.broadcastAttachmentDelete(id: item.id, type: "text")
                                notebook.textAttachments?.removeAll { $0.id == item.id }
                                store.updateNotebook(notebook)
                                collaborationManager.broadcastSelection(selectedId: nil)
                                PageThumbnailRenderer.invalidateAll()
                            },
                            onMoved: { delta in
                                moveAnchoredStrokes(forTextId: item.id, delta: delta)
                            },
                            onAnchorInk: {
                                anchorOverlappingInkToText(textItem: item)
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

                // 🌟 頁面上的錄音卡片（可播放、可搬移、可縮放、可旋轉、可改名、音訊轉文字）
                ForEach(notebook.audioAttachments ?? []) { item in
                    if item.pageIndex == page {
                        AudioAttachmentItemView(
                            item: binding(forAudioId: item.id),
                            notebookId: notebook.id,
                            onDelete: {
                                notebook.audioAttachments?.removeAll { $0.id == item.id }
                                store.updateNotebook(notebook)
                            },
                            onTranscribe: { transcribedText in
                                insertTranscriptText(transcribedText, for: item)
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
    }

    private var canvasWorkAreaContent: some View {
        ZStack(alignment: .topTrailing) {
            PageBackgroundRepresentable(paperId: notebook.paperId(forPage: currentPageIndex), paletteId: notebook.guidePaletteId)
                .allowsHitTesting(false)
                .zIndex(0)

            if editorMode == .type {
                Color.black.opacity(0.0001)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        handleCanvasTapInTypeMode(at: location)
                    }
                    .zIndex(0.5)
            }

            CanvasRepresentable(
                drawing: $currentDrawing,
                selectedTool: selectedTool,
                selectedColor: selectedColor,
                strokeWidth: strokeWidth,
                eraserMode: eraserMode,
                pixelEraserWidth: pixelEraserWidth,
                isRulerActive: isRulerActive,
                paperId: notebook.paperId(forPage: currentPageIndex),
                paletteId: notebook.guidePaletteId,
                pageHeight: currentPageHeight,
                editorMode: editorMode,
                onDrawingChanged: { rawDrawing -> PKDrawing? in
                    // **頁面框線就是編輯區域。**
                    var processedDrawing = enforcePrintableArea(rawDrawing)
                    if strokeStabilizer > 0.05 {
                        processedDrawing = applyStabilizer(to: processedDrawing)
                    }
                    if isSymmetryActive {
                        processedDrawing = applySymmetry(to: processedDrawing)
                    }
                    let newDrawing = processedDrawing
                    recordDrawingEdit(page: currentPageIndex, drawing: newDrawing)

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
                    return newDrawing.strokes.count == rawDrawing.strokes.count
                        ? nil
                        : newDrawing
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
                onTransformChanged: { scale, offset in
                    canvasZoomScale = scale
                    canvasContentOffset = offset
                },
                palmRejection: palmRejection,
                onRetractStrokes: { landedAt in
                    let cleaned = PalmRejectionCoordinator.retracting(
                        currentDrawing, landedAt: landedAt)
                    guard cleaned.strokes.count != currentDrawing.strokes.count else { return }
                    currentDrawing = cleaned
                    canvasView?.drawing = cleaned
                    saveCurrentPageDrawing()
                },
                onPenControl: applyPenControl,
                onPrevPage: {
                    if currentPageIndex > 0 {
                        saveCurrentPageDrawing()
                        currentPageIndex -= 1
                        loadCurrentPage()
                    }
                },
                onNextPage: {
                    if currentPageIndex < notebook.pageCount - 1 {
                        saveCurrentPageDrawing()
                        currentPageIndex += 1
                        loadCurrentPage()
                    }
                },
                onUndo: { performUndo() },
                onRedo: { canvasView?.undoManager?.redo() },
                onMagneticSnap: { start, end in
                    magneticGuideStart = start
                    magneticGuideEnd = end
                    magneticGuideActive = true
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        magneticGuideActive = false
                    }
                }
            )
            .accessibilityIdentifier("editor.canvas")
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
            .allowsHitTesting(editorMode == .draw)
            .zIndex(1)

            objectLayer(forPage: currentPageIndex)
                .scaleEffect(canvasZoomScale, anchor: .topLeading)
                .offset(x: -canvasContentOffset.x, y: -canvasContentOffset.y)
                .allowsHitTesting(true)
                .zIndex(2)

            modeBadge
                .padding(.top, DS.Space.s)
                .padding(.trailing, DS.Space.m)
                .opacity(modeBadgeVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.22), value: modeBadgeVisible)
            MaskingTapeOverlayView(
                notebook: $notebook,
                pageIndex: currentPageIndex,
                isActive: selectedTool == .maskingTape,
                selectedColor: selectedColor,
                onTapesChanged: { store.updateNotebook(notebook) }
            )

            // 🌟 專業鏡像對稱尺規視覺參考線
            if isSymmetryActive && editorMode == .draw {
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                    .foregroundColor(Color.accentColor.opacity(0.6))
                    .frame(width: 1)
                    .overlay(alignment: .top) {
                        Text(localizationManager.localized("ed_symmetry_axis"))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(uiColor: .systemBackground).opacity(0.85))
                            .cornerRadius(4)
                            .offset(y: 8)
                    }
                    .position(x: 400, y: currentPageHeight / 2)
                    .allowsHitTesting(false)
            }


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
                // **與圖釘的點擊層同一個問題**：沒有 zIndex 就預設為 0，
                // 整個討論串面板都被壓在畫布（1）與物件層（2）底下。
                // 面板畫得出來，但只要它的按鈕和頁面上的物件重疊，
                // 點下去就會打到物件 —— 症狀是「收合」與「關閉」按了沒反應，
                // 而使用者只會覺得這個對話框關不掉。
                //
                // 4 在圖釘放置層（3）之上：它是面板，本來就該蓋住一切。
                .zIndex(4)
            }

            // 放置討論圖釘模式互動層。
            //
            // **`zIndex` 不能省。** 這一層原本沒有設，於是預設為 0 ——
            // 而畫布是 `.zIndex(1)`、物件層是 `.zIndex(2)`，它就被壓在最底下，
            // 點擊永遠到不了它。症狀是「加入討論圖釘」按下去之後，橫幅叫你
            // 點畫布，點下去卻是在畫線（手繪模式）或插入文字游標（打字模式），
            // 圖釘**一個都放不上去**。這個功能等於完全不能用。
            //
            // 2026-09-22 拍操作手冊截圖時發現：橫幅出現了，圖釘卻怎麼點都不出現。
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
                .zIndex(3)

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

            // 🌟 套索選取浮動控制面板（僅在手繪模式且套索工具啟動時浮現：支援剪下、複製、刪除選取筆劃）
            if editorMode == .draw && selectedTool == .lasso {
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
            }

            // 🌟 聲筆動態同步與波形卡拉 OK 高亮 (Audio-Ink Karaoke Sync)
            if audioManager.isPlaying && !currentDrawing.strokes.isEmpty {
                Canvas { context, size in
                    let total = currentDrawing.strokes.count
                    if total > 0 {
                        let activeIdx = min(total - 1, max(0, Int(Double(total) * audioManager.playbackProgress)))
                        let start = max(0, activeIdx - 1)
                        let end = min(total - 1, activeIdx + 1)
                        for i in start...end {
                            let rect = currentDrawing.strokes[i].renderBounds
                            context.fill(
                                Path(roundedRect: rect.insetBy(dx: -6, dy: -6), cornerRadius: 8),
                                with: .color(Color.yellow.opacity(0.35))
                            )
                            context.stroke(
                                Path(roundedRect: rect.insetBy(dx: -4, dy: -4), cornerRadius: 6),
                                with: .color(Color.orange.opacity(0.8)),
                                lineWidth: 2.5
                            )
                        }
                    }
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            // 🌟 筆跡磁吸對齊與幾何角度引導 (Smart Magnetic Snap Laser Guide)
            if snapToGrid && editorMode == .draw && magneticGuideActive {
                Canvas { context, size in
                    var path = Path()
                    path.move(to: magneticGuideStart)
                    path.addLine(to: magneticGuideEnd)
                    context.stroke(
                        path,
                        with: .color(Color.cyan.opacity(0.85)),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            // 🌟 徑向飛輪快捷工具盤 (Radial Pie Menu)
            if showRadialMenu {
                RadialMarkMenuView(
                    isPresented: $showRadialMenu,
                    centerPoint: radialMenuCenter,
                    items: [
                        RadialMenuItem(id: "pen", icon: "pencil.tip", labelKey: "tool_pen", color: .accentColor) {
                            selectedTool = .pen
                        },
                        RadialMenuItem(id: "highlighter", icon: "highlighter", labelKey: "tool_highlighter", color: .orange) {
                            selectedTool = .highlighter
                        },
                        RadialMenuItem(id: "eraser", icon: "eraser", labelKey: "tool_eraser", color: .red) {
                            selectedTool = .eraser
                        },
                        RadialMenuItem(id: "lasso", icon: "lasso", labelKey: "tool_lasso", color: .purple) {
                            selectedTool = .lasso
                        },
                        RadialMenuItem(id: "undo", icon: "arrow.uturn.backward", labelKey: "undo", color: .blue) {
                            canvasView?.undoManager?.undo()
                        },
                        RadialMenuItem(id: "redo", icon: "arrow.uturn.forward", labelKey: "redo", color: .blue) {
                            canvasView?.undoManager?.redo()
                        },
                        RadialMenuItem(id: "color", icon: "paintpalette.fill", labelKey: "pro_color", color: .pink) {
                            showProColorWheel = true
                        },
                        RadialMenuItem(id: "stabilizer", icon: "waveform.path.ecg", labelKey: "refine_sketch", color: .green) {
                            strokeStabilizer = (strokeStabilizer > 0) ? 0.0 : 0.5
                        }
                    ]
                )
            }
        }
        .frame(width: PageGeometry.width, height: currentPageHeight)
        .contentShape(Rectangle())
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
        // 打字模式下點擊空白處＝在該處新增文字方塊隨點隨打。
        //
        // 用 simultaneousGesture 讓手勢與底下的物件各自獨立辨識。
        .simultaneousGesture(
            editorMode == .type
                ? SpatialTapGesture(count: 1, coordinateSpace: .named(CanvasCoordinateSpace.name))
                    .onEnded { value in
                        handleCanvasTapInTypeMode(at: value.location)
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

    // MARK: - 次世代動態模式傳送門 (The Dynamic Mode Portal)
    /// 原本收一個 `compact` 旗標，而 `DynamicPortalIsland` **根本沒有緊湊
    /// 變體**，所以呼叫端傳 true 或 false 畫出來完全一樣。拿掉假旗標讓
    /// 「沒有緊湊版面」這件事看得見 —— 真要做的時候會是一次刻意的改動。
    private func editorModeSwitcher() -> some View {
        DynamicPortalIsland(
            editorMode: $editorMode,
            contextualState: contextualPortalState,
            onModeChange: { mode in
                saveCurrentPageDrawing()
                withAnimation(.easeInOut(duration: 0.18)) {
                    editorMode = mode
                    inlineEditingTextId = nil
                    activeInlineInkBlockId = nil
                }
                flashModeBadge()
            },
            onExitContextual: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    inlineEditingTextId = nil
                    activeInlineInkBlockId = nil
                }
            }
        )
        // **`children: .contain` 不是裝飾。**
        //
        // 只掛識別字的話，這座島會變成一個「單一無障礙元素」，裡面那兩顆
        // 藥丸（`portal.draw` / `portal.type`）就**整個從無障礙樹上消失**
        // —— 實測：編輯器上掃得到 `editor.mode`（而且有兩個），一個
        // `portal.*` 都沒有。
        //
        // 那不只是測試找不到按鈕：VoiceOver 的使用者也點不到「手寫／打字」
        // 這兩顆，他只會聽到一個沒有作用的容器。
        //
        // `.contain` 讓這一層仍然是可定位的群組（規格要 `editor.mode`），
        // 同時保留子元素。首頁那四個容器踩過同一件事（S-263）。
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("editor.mode")
    }

    private var effectiveToolbarMode: EditorMode {
        if editorMode == .draw {
            if inlineEditingTextId != nil {
                return .type
            }
            return .draw
        } else {
            if activeInlineInkBlockId != nil {
                return .draw
            }
            return .type
        }
    }

    private var contextualPortalState: DynamicPortalIsland.ContextualPortalState? {
        if editorMode == .draw && inlineEditingTextId != nil {
            return .editingTextInDrawMode(title: "\(localizationManager.localized("tool_text")) • \(localizationManager.localized("edit"))")
        } else if editorMode == .type && activeInlineInkBlockId != nil {
            return .drawingInTextMode(title: "\(localizationManager.localized("handwriting_mode")) • \(localizationManager.localized("edit"))")
        }
        return nil
    }

    // MARK: - 側欄與畫布之間的界線
    //
    // 原本這裡是一條 1pt 的分隔線，側欄固定 280pt。280 對「翻頁找內容」
    // 剛好夠，對「看清楚這一頁畫了什麼」不夠 —— 而使用者沒有任何辦法
    // 調整它：畫面上唯一的操作是把整條側欄關掉。
    //
    // 界線改成可以拖。夾住兩端的規則在核心（`sidebarClampWidth`），
    // 因為「畫布至少要留 480」這條線兩個平台是同一條。

    /// 目前該用的側欄寬度：拖曳中用暫時值，否則用落盤值，兩者都要夾過。
    private func resolvedSidebarWidth(total: CGFloat) -> CGFloat {
        let desired = draggingSidebarWidth ?? CGFloat(storedSidebarWidth)
        return CGFloat(sidebarClampWidth(desired: Float(desired), total: Float(total)))
    }

    /// 界線本身。視覺上是一條線，可以抓的範圍比線寬得多 ——
    /// 1pt 的命中區域在觸控上等於抓不到，在游標上等於要瞄準。
    private func sidebarResizeHandle(total: CGFloat, current: CGFloat) -> some View {
        let isDragging = (draggingSidebarWidth != nil)
        return ZStack {
            Color(uiColor: .separator)
                .frame(width: 1)
            // 抓得到的提示：三顆點。沒有它，這條線看起來就只是一條線。
            Capsule()
                .fill(isDragging ? Color.accentColor : Color.secondary.opacity(0.35))
                .frame(width: 4, height: 34)
        }
        .frame(width: 10)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .background(isDragging ? Color.accentColor.opacity(0.12) : Color.clear)
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    draggingSidebarWidth = CGFloat(
                        sidebarClampWidth(desired: Float(current + value.translation.width),
                                          total: Float(total)))
                }
                .onEnded { value in
                    let final = CGFloat(
                        sidebarClampWidth(desired: Float(current + value.translation.width),
                                          total: Float(total)))
                    storedSidebarWidth = Double(final)
                    draggingSidebarWidth = nil
                }
        )
        // 連點兩下回到預設寬度。拖過頭之後要靠手拖回「原本那樣」很難，
        // 而「回到原本那樣」是使用者第二常想做的事。
        .onTapGesture(count: 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                storedSidebarWidth = 280
            }
        }
        .accessibilityLabel(localizationManager.localized("resize_sidebar"))
        .help(localizationManager.localized("resize_sidebar"))
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
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isSelectingPages.toggle()
                                if !isSelectingPages { pageSelection.removeAll() }
                            }
                        } label: {
                            Image(systemName: isSelectingPages
                                ? "checkmark.circle.fill" : "checkmark.circle")
                                .font(.system(size: 17))
                                .foregroundColor(.accentColor)
                                .frame(width: 30, height: 30)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(localizationManager.localized("select_pages"))
                        .help(localizationManager.localized("select_pages"))

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
                    Text(localizationManager.localized("structure_pages"))
                        .tag(SidebarTabMode.pages)
                        .accessibilityIdentifier("editor.sidebar.tab.pages")
                    Text(localizationManager.localized("structure_folders"))
                        .tag(SidebarTabMode.folders)
                        .accessibilityIdentifier("editor.sidebar.tab.folders")
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(uiColor: .secondarySystemGroupedBackground))

            Divider()

            if sidebarTab == .pages {
                pagesStructureView
                    .accessibilityIdentifier("editor.sidebar.list")
            } else {
                foldersStructureView
                    .accessibilityIdentifier("editor.sidebar.list")
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
                        pageStructureCard(idx: idx)
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

            if isSelectingPages {
                pageSelectionBar
                Divider()
            }

            // 結構摘要統計與縮圖大小
            pagesStructureFooter
        }
        .sheet(isPresented: Binding(
            get: { transferIsCopy != nil },
            set: { if !$0 { transferIsCopy = nil } }
        )) {
            transferDestinationSheet
        }
    }

    /// 多選模式下的那一排操作。
    ///
    /// 放在清單底下而不是最上面：勾選是從上往下做的，手指停在下半部，
    /// 而「做完了要按的那顆」不該在滑到看不見的地方。
    private var pageSelectionBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text(
                    String(
                        format: localizationManager.localized("pages_selected"),
                        String(pageSelection.count))
                )
                .font(.system(size: 12 * sidebarScale))
                .foregroundColor(.secondary)

                Spacer()

                Button {
                    if pageSelection.count == notebook.pageCount {
                        pageSelection.removeAll()
                    } else {
                        pageSelection = Set(0..<max(1, notebook.pageCount))
                    }
                } label: {
                    Text(localizationManager.localized(
                        pageSelection.count == notebook.pageCount
                            ? "deselect_all" : "select_all"))
                        .font(.system(size: 12))
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }

            HStack(spacing: 8) {
                Button {
                    transferIsCopy = true
                } label: {
                    Label(
                        localizationManager.localized("copy_to"),
                        systemImage: "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.accentColor.opacity(0.12))
                        .cornerRadius(8)
                        // **`.buttonStyle(.plain)` 的命中範圍是標籤自己的形狀。**
                        // 沒有這一行的話，可以按的只有「文字與圖示的筆畫」，
                        // 那一圈底色是純裝飾 —— 實機上按下去完全沒有反應，
                        // 而畫面上它看起來就是一顆按鈕。
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(pageSelection.isEmpty)

                Button {
                    transferIsCopy = false
                } label: {
                    Label(
                        localizationManager.localized("move_to"),
                        systemImage: "arrow.right.doc.on.clipboard")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.accentColor.opacity(0.12))
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // 整本搬空是不允許的（核心的 `pageTransferPlan` 會擋），
                // 但按鈕直接停用比按下去才被拒絕清楚。
                .disabled(pageSelection.isEmpty || pageSelection.count >= notebook.pageCount)
            }
            .foregroundColor(.accentColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    /// 目的筆記本選擇器。
    ///
    /// 列出全部筆記本（含目前這一本）—— 複製到同一本是合理的動作
    /// （把某一頁再來一份接在最後）。搬移到同一本沒有意義，那一項會被擋下。
    private var transferDestinationSheet: some View {
        let isCopy = (transferIsCopy ?? true)
        return NavigationView {
            List {
                Section {
                    ForEach(store.visibleNotebooks) { target in
                        let isSelf = (target.id == notebook.id)
                        Button {
                            performTransfer(to: target, copy: isCopy)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: isSelf ? "doc.fill" : "doc.plaintext")
                                    .foregroundColor(isSelf ? .accentColor : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(target.displayTitle())
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Text("\(target.pageCount) \(localizationManager.localized("pages_count_suffix"))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if isSelf {
                                    Text(localizationManager.localized("current_notebook"))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        // 搬到自己身上要的是換順序，不是轉移 —— 那件事在
                        // 同一份選單裡有「上移／下移／移到最前」。
                        .disabled(!isCopy && isSelf)
                        .opacity(!isCopy && isSelf ? 0.4 : 1)
                    }
                } header: {
                    Text(localizationManager.localized(
                        isCopy ? "copy_pages_to_title" : "move_pages_to_title"))
                } footer: {
                    Text(
                        String(
                            format: localizationManager.localized("pages_selected"),
                            String(pageSelection.count))
                    )
                }
            }
            .navigationTitle(localizationManager.localized("choose_destination_notebook"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) { transferIsCopy = nil }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    /// 執行轉移，然後把畫面收拾乾淨。
    private func performTransfer(to target: NotebookDocument, copy: Bool) {
        // 目前這一頁的筆跡還在記憶體裡，先落盤 —— 不落盤的話複製過去的是
        // 磁碟上的舊版本，剛剛寫的那幾筆不會跟著走。
        saveCurrentPageDrawing()

        let pages = pageSelection.sorted()
        let moved = store.transferPages(
            from: notebook.id, pageIndexes: pages, to: target.id, move: !copy)

        transferIsCopy = nil
        isSelectingPages = false
        pageSelection.removeAll()

        guard moved > 0 else {
            showCanvasNotice(localizationManager.localized("transfer_failed"))
            return
        }

        if let updated = store.notebooks.first(where: { $0.id == notebook.id }) {
            notebook = updated
        }
        // 搬走之後目前的頁碼可能已經不存在。
        currentPageIndex = min(currentPageIndex, max(0, notebook.pageCount - 1))
        loadCurrentPage()

        showCanvasNotice(
            String(
                format: localizationManager.localized(copy ? "pages_copied" : "pages_moved"),
                String(moved), target.displayTitle())
        )
    }

    /// 單一頁面卡片。
    ///
    /// # 為什麼拆成一個函式
    ///
    /// 這張卡片上現在有四種操作：點選、拖曳換位、右上角選單、右鍵（或長按）
    /// 快顯。全部塞在 `LazyVStack` 的閉包裡的話，那個閉包的型別會長到
    /// 裝置端解析時爆堆疊 —— 這個檔案裡其他幾處 AnyView 邊界都是同一個理由。
    private func pageStructureCard(idx: Int) -> some View {
        let isSelected = (idx == currentPageIndex)
        let isDropTarget = (dropTargetPageIndex == idx)
        return VStack(spacing: 4) {
            HStack {
                if isSelectingPages {
                    Image(systemName: pageSelection.contains(idx)
                        ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundColor(pageSelection.contains(idx) ? .accentColor : .secondary)
                }

                Text("P.\(idx + 1)")
                    .font(.system(size: 12 * sidebarScale))
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundColor(isSelected ? .accentColor : .primary)

                Spacer()

                Menu {
                    pageActionMenuItems(idx: idx)
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
                // 多選模式下，點縮圖是「勾選／取消」而不是跳頁 ——
                // 要勾選卻跳走一頁，等於每勾一次就換一次畫面。
                if isSelectingPages {
                    if pageSelection.contains(idx) {
                        pageSelection.remove(idx)
                    } else {
                        pageSelection.insert(idx)
                    }
                    return
                }
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
            .frame(width: effectiveThumbnailWidth)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        .cornerRadius(8)
        // 拖曳中的落點指示。沒有它，拖到一半完全看不出會插在哪裡。
        .overlay(alignment: .top) {
            if isDropTarget {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(height: 3)
                    .padding(.horizontal, 8)
            }
        }
        // 右鍵（Mac 與觸控板）、長按（手指與觸控筆）都會叫出同一份選單。
        //
        // 原本這些操作只藏在卡片右上角那顆 `...` 裡 —— 那顆按鈕在縮圖縮小時
        // 只有十幾點寬，而且它看起來像裝飾。真正會被嘗試的手勢是長按與右鍵。
        .contextMenu {
            pageActionMenuItems(idx: idx)
        }
        .draggable(PageDragPayload(index: idx)) {
            // 拖曳時跟著手指走的東西。
            Label("P.\(idx + 1)", systemImage: "doc.on.doc")
                .font(.caption)
                .padding(8)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(8)
        }
        .dropDestination(for: PageDragPayload.self) { items, _ in
            dropTargetPageIndex = nil
            guard let from = items.first?.index else { return false }
            return reorderPage(from: from, to: idx)
        } isTargeted: { hovering in
            dropTargetPageIndex = hovering ? idx : (dropTargetPageIndex == idx ? nil : dropTargetPageIndex)
        }
    }

    /// 一頁能做的事。右上角的選單與右鍵快顯共用同一份 ——
    /// 各寫一份的結果是其中一邊少了一項，而使用者會以為那一項不存在。
    @ViewBuilder
    private func pageActionMenuItems(idx: Int) -> some View {
        Button {
            insertPageAfter(idx)
        } label: {
            Label(localizationManager.localized("insert_page_after"), systemImage: "plus.square")
        }

        // 插入**別種格式**的一頁。
        //
        // # 為什麼需要這個
        //
        // 樣板原本是「開筆記本時選一次，整本就定了」。而一本會議紀錄的
        // 第一頁想用四象限、後面幾頁想用橫線 —— 那件事以前做不到，
        // 使用者只能為了一頁不同的格式另外開一本筆記。
        Menu {
            ForEach(Array(paperThemes().enumerated()), id: \.offset) { _, theme in
                Menu {
                    ForEach(paperTemplatesForTheme(theme: theme), id: \.id) { paper in
                        Button {
                            insertPageAfter(idx, paperId: paper.id)
                        } label: {
                            Label(
                                localizationManager.localized(paper.titleKey),
                                systemImage: paper.iconApple)
                        }
                    }
                } label: {
                    Label(
                        localizationManager.localized(paperThemeKey(theme: theme)),
                        systemImage: paperThemeIcons(theme: theme).first ?? "doc.text")
                }
            }
        } label: {
            Label(
                localizationManager.localized("insert_page_with_template"),
                systemImage: "rectangle.stack.badge.plus")
        }

        Button {
            duplicatePage(at: idx)
        } label: {
            Label(localizationManager.localized("duplicate_page"), systemImage: "plus.square.on.square")
        }

        ToolbarSeparator()

        // 單頁的快路徑。多選那一排在下面的工具列裡，但「就這一頁」是最常見的
        // 情況，不該為了它先進多選模式再勾一格。
        Button {
            pageSelection = [idx]
            isSelectingPages = true
            transferIsCopy = true
        } label: {
            Label(localizationManager.localized("copy_to_notebook"), systemImage: "doc.on.doc")
        }

        if notebook.pageCount > 1 {
            Button {
                pageSelection = [idx]
                isSelectingPages = true
                transferIsCopy = false
            } label: {
                Label(
                    localizationManager.localized("move_to_notebook"),
                    systemImage: "arrow.right.doc.on.clipboard")
            }
        }

        if notebook.pageCount > 1 {
            ToolbarSeparator()

            Button {
                _ = reorderPage(from: idx, to: idx - 1)
            } label: {
                Label(localizationManager.localized("move_page_up"), systemImage: "arrow.up")
            }
            .disabled(idx == 0)

            Button {
                _ = reorderPage(from: idx, to: idx + 1)
            } label: {
                Label(localizationManager.localized("move_page_down"), systemImage: "arrow.down")
            }
            .disabled(idx >= notebook.pageCount - 1)

            Button {
                _ = reorderPage(from: idx, to: 0)
            } label: {
                Label(localizationManager.localized("move_page_to_top"), systemImage: "arrow.up.to.line")
            }
            .disabled(idx == 0)

            Button {
                _ = reorderPage(from: idx, to: notebook.pageCount - 1)
            } label: {
                Label(localizationManager.localized("move_page_to_bottom"), systemImage: "arrow.down.to.line")
            }
            .disabled(idx >= notebook.pageCount - 1)

            ToolbarSeparator()
            Button(role: .destructive) {
                pageToDeleteIndex = idx
                showDeletePageAlert = true
            } label: {
                Label(localizationManager.localized("delete_page"), systemImage: "trash")
            }
        }
    }

    /// 側欄底部：統計與縮圖大小。
    ///
    /// 縮圖大小放在這裡而不是標題列：標題列已經有三顆按鈕，再擠一顆會讓
    /// 每一顆都變小。而調整大小是「看一眼、調一次」的操作，不需要在最上面。
    private var pagesStructureFooter: some View {
        HStack(spacing: 8) {
            Text("\(localizationManager.localized("all_pages")): \(notebook.pageCount)")
                .font(.system(size: 11 * sidebarScale))
                .foregroundColor(.secondary)

            Spacer(minLength: 4)

            Button {
                pageThumbnailWidth = max(120, pageThumbnailWidth - 40)
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 13))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(pageThumbnailWidth <= 120)
            .accessibilityLabel(localizationManager.localized("thumbnail_smaller"))
            .help(localizationManager.localized("thumbnail_smaller"))
            .accessibilityIdentifier("editor.sidebar.thumb_smaller")

            Text("\(Int(effectiveThumbnailWidth))")
                .font(.system(size: 10))
                .monospacedDigit()
                .foregroundColor(.secondary)

            Button {
                pageThumbnailWidth = min(480, pageThumbnailWidth + 40)
                // 放大到比側欄還寬時，把側欄一起拉開。
                //
                // 不這樣做的話「＋」在到達側欄寬度之後就沒有反應了 ——
                // 而使用者按它的理由正是「我要看得更清楚」。真正的上限由
                // 核心夾（畫布至少要留 480），這裡只是提出要求。
                if pageThumbnailWidth + 32 > storedSidebarWidth {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        storedSidebarWidth = pageThumbnailWidth + 32
                    }
                }
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 13))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(pageThumbnailWidth >= 480)
            .accessibilityLabel(localizationManager.localized("thumbnail_larger"))
            .help(localizationManager.localized("thumbnail_larger"))
            .accessibilityIdentifier("editor.sidebar.thumb_larger")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    /// 把一頁搬到另一個位置。
    ///
    /// 回傳值是「有沒有真的搬」—— 拖到自己身上、拖到範圍外都回 false，
    /// 呼叫端不必各自再判斷一次。
    @discardableResult
    private func reorderPage(from: Int, to: Int) -> Bool {
        let total = notebook.pageCount
        guard pageMoveIsValid(count: UInt32(max(0, total)),
                              from: UInt32(max(0, from)),
                              to: UInt32(max(0, min(to, max(0, total - 1)))))
        else { return false }
        let target = min(max(0, to), total - 1)

        // 目前這一頁的筆跡還在記憶體裡，先落盤 —— 不落盤的話搬動會去讀
        // 磁碟上的舊版本，剛剛寫的那幾筆就沒了。
        saveCurrentPageDrawing()

        let landed = store.movePage(notebookId: notebook.id, from: from, to: target)

        // 游標跟著走：搬的如果是目前這一頁，人應該還停在同一頁的內容上；
        // 搬的是別頁時，目前這一頁的頁碼可能被推移了。
        if currentPageIndex == from {
            currentPageIndex = landed
        } else {
            currentPageIndex = Int(pageIndexAfterMove(index: UInt32(max(0, currentPageIndex)),
                                                      from: UInt32(from),
                                                      to: UInt32(target)))
        }
        if let updated = store.notebooks.first(where: { $0.id == notebook.id }) {
            notebook = updated
        }
        loadCurrentPage()
        return true
    }

    /// 側欄目前的實際寬度。與版面那一層畫出來的是同一個算式。
    private var currentSidebarWidth: CGFloat {
        resolvedSidebarWidth(total: editorAvailableWidth)
    }

    /// 側欄內字級的倍率。規則在核心（`sidebarContentScale`），
    /// 因為「側欄變寬字要不要跟著大、大到哪裡停」兩個平台是同一個答案。
    private var sidebarScale: CGFloat {
        CGFloat(sidebarContentScale(width: Float(currentSidebarWidth)))
    }

    /// 縮圖實際會畫多寬：使用者要的寬度，被側欄目前的內寬夾住。
    ///
    /// 夾住而不是溢出：溢出的縮圖會被裁掉右半邊，而使用者是為了「看清楚
    /// 這一頁」才把它放大的，看到一半的頁面比小張還糟。
    private var effectiveThumbnailWidth: CGFloat {
        min(CGFloat(pageThumbnailWidth), max(80, currentSidebarWidth - 32))
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
            .background(
                isRootDropTargeted
                    ? Color.accentColor.opacity(0.22)
                    : Color(uiColor: .tertiarySystemGroupedBackground)
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: isRootDropTargeted ? 2 : 0)
            )
            .padding(.horizontal, 10)
            .padding(.top, 8)
            // 把筆記拖到這裡就是「移出資料夾」。
            //
            // # 為什麼要多這個落點
            //
            // 原本唯一能移出去的地方是下面「未分類檔案」那一段的**標題列**，
            // 而那一段在沒有未分類筆記時整段不存在 —— 也就是說，把最後一本
            // 筆記歸檔之後，就再也沒有任何地方可以把它拖回來了。
            // 使用者看到的是「拖得進去，拖不出來」。
            //
            // 根目錄這一列一直都在，而且它在最上面：往上拖是「拿出來」的
            // 直覺方向。
            .dropDestination(for: String.self) { items, _ in
                guard let noteId = items.first else { return false }
                store.moveNotebook(id: noteId, toFolderId: nil)
                return true
            } isTargeted: { isRootDropTargeted = $0 }

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

                    // 最上層未分類筆記。
                    //
                    // **這一段就算是空的也要畫出來。** 它是拖曳「移出資料夾」的
                    // 落點，而原本的寫法是 `if !rootNotes.isEmpty` —— 於是
                    // 把所有筆記都歸檔之後，落點跟著消失，使用者再也拖不出來。
                    // 空的時候顯示一句提示，順便告訴他這裡可以放東西。
                    let rootNotes = store.notebooks(in: nil)
                    Group {
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

                            if rootNotes.isEmpty {
                                Text(localizationManager.localized("drop_here_to_unfile"))
                                    .font(.system(size: 10 * sidebarScale))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.3),
                                                    style: StrokeStyle(lineWidth: 1, dash: [4]))
                                    )
                                    .padding(.horizontal, 10)
                            } else {
                                ForEach(rootNotes) { note in
                                    notebookItemRow(note: note, indent: 8)
                                }
                            }
                        }
                        // 落點是**整段**，不是那一條標題列。
                        //
                        // 原本掛在標題列上，那是一條約 26pt 高的細長條 ——
                        // 用手指拖著一本筆記去瞄準它，瞄不中的次數比瞄中的多，
                        // 而瞄不中的表現就是「放開之後什麼也沒發生」。
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .background(isUnfiledDropTargeted ? Color.accentColor.opacity(0.18) : Color.clear)
                        .cornerRadius(6)
                        .dropDestination(for: String.self) { items, _ in
                            guard let noteId = items.first else { return false }
                            store.moveNotebook(id: noteId, toFolderId: nil)
                            return true
                        } isTargeted: { isUnfiledDropTargeted = $0 }
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
                    String(store.folders.count), String(store.visibleNotebooks.count))
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
                if note.folderId != nil {
                    Button {
                        store.moveNotebook(id: note.id, toFolderId: nil)
                    } label: {
                        Label(localizationManager.localized("move_out_of_folder"), systemImage: "arrow.up.left.square")
                    }
                }

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
        // 落到另一本筆記上 = 落到那本筆記所在的資料夾。
        //
        // 使用者要把 A 搬到「範例」裡時，最自然的動作是把它拖到「範例」
        // 底下那幾本筆記中間 —— 而那一片區域原本完全不接受落下，
        // 只有資料夾那一列（一條細長條）才算數。
        .dropDestination(for: String.self) { items, _ in
            guard let draggedId = items.first, draggedId != note.id else { return false }
            store.moveNotebook(id: draggedId, toFolderId: note.folderId)
            return true
        } isTargeted: { hovering in
            let key = note.folderId ?? unfiledDropKey
            if hovering {
                dropTargetFolderId = key
            } else if dropTargetFolderId == key {
                dropTargetFolderId = nil
            }
        }
        // 右鍵或長按。拖曳失敗時要有一條不靠瞄準的路 ——
        // 而「移出資料夾」原本連選單裡都沒有：`移至資料夾` 那張表只列得出
        // 資料夾，列不出「不在任何資料夾裡」。
        .contextMenu {
            if note.folderId != nil {
                Button {
                    store.moveNotebook(id: note.id, toFolderId: nil)
                } label: {
                    Label(localizationManager.localized("move_out_of_folder"), systemImage: "arrow.up.left.square")
                }
            }
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
        }
        // 拖到資料夾列上即可分類；拖到根目錄或「未分類檔案」可移出資料夾
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

    // MARK: - 2-1. 🌟 Office Word / Google Docs 專屬打字排版工具列
    private var wordModeToolbar: AnyView {
        AnyView(wordModeToolbarContent)
    }

    private var wordModeToolbarContent: some View {
        VStack(spacing: 0) {
            if editorMode == .draw && inlineEditingTextId != nil {
                HStack(spacing: 8) {
                    Image(systemName: "character.textbox")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)
                    Text(localizationManager.localized("ed_text_toolbar_hint"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            inlineEditingTextId = nil
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text(localizationManager.localized("ed_done_back_to_ink"))
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.12))
                Divider()
            }

            // **文字方塊物件的工具列。**
            //
            // 這一整份（新增方塊、粗體斜體底線、對齊、貼齊格線、疊層、
            // 特殊符號、框選）原本是**死的** —— 全專案沒有任何地方引用
            // `typingToolbar`，而規格要求的十六個 `editor.text.*` 識別碼
            // 全掛在它身上。結果是：靜態的跨平台對照閘門一直綠的（它掃的是
            // 原始碼裡有沒有那個字串），而使用者在 iPad 上**根本點不到**
            // 這些功能，Android 卻有。
            //
            // 它與底下的 `WordToolbarView` 不是重複：這一份操作的是畫布上
            // 的**文字方塊物件**（位置、疊層、對齊到格線），`WordToolbarView`
            // 操作的是**文件內文**（標題階層、字體、清單、表格）。
            // 兩者是不同層次，所以兩份都留。
            typingToolbar

            WordToolbarView(
                activeText: Binding(
                    get: { activeTextAttachment ?? NoteTextAttachment(pageIndex: currentPageIndex) },
                    set: { updated in
                        if notebook.textAttachments == nil { notebook.textAttachments = [] }
                        if let idx = notebook.textAttachments?.firstIndex(where: { $0.id == updated.id }) {
                            notebook.textAttachments?[idx] = updated
                        } else {
                            notebook.textAttachments?.append(updated)
                        }
                        store.updateNotebook(notebook)
                        PageThumbnailRenderer.invalidateAll()
                    }
                ),
                canUndo: canvasView?.undoManager?.canUndo ?? true,
                canRedo: canvasView?.undoManager?.canRedo ?? false,
                onUndo: { performUndo() },
                onRedo: { canvasView?.undoManager?.redo() },
                onInsertTable: { rows, cols in
                    let table = NoteTableAttachment(pageIndex: currentPageIndex, x: 40, y: 120, rows: rows, cols: cols)
                    if notebook.tableAttachments == nil { notebook.tableAttachments = [] }
                    notebook.tableAttachments?.append(table)
                    store.updateNotebook(notebook)
                    PageThumbnailRenderer.invalidateAll()
                },
                onInsertImage: { showPhotoPicker = true },
                onInsertDrawingBlock: {
                    withAnimation {
                        activeInlineInkBlockId = "page-\(currentPageIndex)-ink"
                    }
                },
                onInsertLink: { showLinkPreviewSheet = true },
                onInsertDivider: { insertQuickTextSnippet("────────────────────────────────────────") },
                onInsertTodo: { insertQuickTextSnippet("☐ ") },
                onInsertBullet: { insertQuickTextSnippet("• ") },
                onInsertNumbered: { insertQuickTextSnippet("1. ") },
                onClearFormat: {
                    if let id = activeTextAttachment?.id,
                       let idx = notebook.textAttachments?.firstIndex(where: { $0.id == id }) {
                        notebook.textAttachments?[idx].fontSize = 15
                        notebook.textAttachments?[idx].isBold = false
                        notebook.textAttachments?[idx].isItalic = false
                        notebook.textAttachments?[idx].isUnderline = false
                        notebook.textAttachments?[idx].isStrikethrough = false
                        notebook.textAttachments?[idx].textColorHex = "#000000"
                        notebook.textAttachments?[idx].backgroundColorHex = "clear"
                        notebook.textAttachments?[idx].alignmentRaw = "left"
                        store.updateNotebook(notebook)
                        PageThumbnailRenderer.invalidateAll()
                    }
                },
                onCommitChange: {
                    store.updateNotebook(notebook)
                    PageThumbnailRenderer.invalidateAll()
                }
            )
        }
    }

    // MARK: - 2. 🌟 實體手繪工具列（水平滑動包裹、免擠壓、隨點隨用）
    /// 型別邊界：SwiftUI 會把整棵子樹的型別編進 body 的 mangled 名稱，
    /// 名稱一長，裝置端（主執行緒只有 1MB 堆疊）解析時就會遞迴爆堆疊。
    private var drawingToolbar: AnyView { AnyView(drawingToolbarContent) }

    private func selectEditorTool(_ tool: EditorToolType) {
        if tool == .lasso, selectedTool == .lasso {
            exitLassoMode()
        } else {
            selectedTool = tool
        }
    }

    private func exitLassoMode() {
        selectedTool = previousTool ?? lastBrushTool
        previousTool = nil
    }

    @ViewBuilder
    private var eraserModeControls: some View {
        if selectedTool == .eraser {
            ToolbarSeparator().frame(height: 24)
            HStack(spacing: 4) {
                Button {
                    eraserMode = .stroke
                    canvasView?.tool = PKEraserTool(.vector)
                } label: {
                    Image(systemName: "eraser.line.dashed")
                        .font(.system(size: 16, weight: eraserMode == .stroke ? .bold : .regular))
                        .foregroundColor(eraserMode == .stroke ? .accentColor : .secondary)
                        .padding(.horizontal, DS.Space.xs)
                        .padding(.vertical, 5)
                        .background(Color.secondary.opacity(eraserMode == .stroke ? 0.25 : 0.08))
                        .cornerRadius(DS.Radius.s)
                }
                .buttonStyle(.plain)

                Button {
                    eraserMode = .pixel
                    if #available(iOS 16.4, *) {
                        canvasView?.tool = PKEraserTool(.bitmap, width: pixelEraserWidth)
                    } else {
                        canvasView?.tool = PKEraserTool(.bitmap)
                    }
                } label: {
                    Image(systemName: "eraser.fill")
                        .font(.system(size: 16, weight: eraserMode == .pixel ? .bold : .regular))
                        .foregroundColor(eraserMode == .pixel ? .accentColor : .secondary)
                        .padding(.horizontal, DS.Space.xs)
                        .padding(.vertical, 5)
                        .background(Color.secondary.opacity(eraserMode == .pixel ? 0.25 : 0.08))
                        .cornerRadius(DS.Radius.s)
                }
                .buttonStyle(.plain)
                
                if eraserMode == .pixel {
                    Slider(value: $pixelEraserWidth, in: 10...60, step: 1) { _ in
                        if #available(iOS 16.4, *) {
                            canvasView?.tool = PKEraserTool(.bitmap, width: pixelEraserWidth)
                        }
                    }
                    .frame(width: 80)
                    .tint(.accentColor)
                }
            }
        }
    }

    @ViewBuilder
    private var lassoRecolorButton: some View {
        Button {
            showLassoColorPicker.toggle()
        } label: {
            Image(systemName: "paintbrush.fill")
                .font(.system(size: 14))
                .frame(width: 28, height: 28)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(localizationManager.localized("ink_change_colour"))
        .accessibilityLabel(localizationManager.localized("ink_change_colour"))
        .popover(isPresented: $showLassoColorPicker) {
            HStack(spacing: 12) {
                ForEach(colorPalette, id: \.self) { color in
                    Button {
                        recolorSelectedStrokes(to: color)
                        showLassoColorPicker = false
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 28, height: 28)
                            .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .modifier(PopoverCompactAdaptation())
        }
    }

    /// iOS 16.4+ 限定修飾器，低版本直接略過。
    private struct PopoverCompactAdaptation: ViewModifier {
        func body(content: Content) -> some View {
            if #available(iOS 16.4, *) {
                content.presentationCompactAdaptation(.popover)
            } else {
                content
            }
        }
    }

    /// 將 PKLassoTool 圈選的筆劃換色。
    ///
    /// PencilKit 不開放「哪些筆劃被選取」的 API，但選取狀態下刪除
    /// 只會移除被選的筆劃。利用「刪除前後的差集」辨識被選取的筆劃索引，
    /// 再將它們換色並復原。
    private func recolorSelectedStrokes(to newColor: Color) {
        guard let canvas = canvasView else { return }
        let before = canvas.drawing.strokes
        // 1. 記錄原始筆劃 ID 集
        let beforeIds = Set(before.map { $0.path.creationDate })

        // 2. 送出 cut（剪下選取的筆劃）
        for sv in canvas.subviews where String(describing: type(of: sv)).contains("PKTiledView") {
            if sv.responds(to: #selector(UIResponderStandardEditActions.cut(_:))) {
                sv.perform(#selector(UIResponderStandardEditActions.cut(_:)), with: nil)
            }
        }
        UIApplication.shared.sendAction(#selector(UIResponderStandardEditActions.cut(_:)), to: nil, from: nil, for: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak canvas] in
            guard let canvas = canvas else { return }
            let after = canvas.drawing.strokes
            let afterIds = Set(after.map { $0.path.creationDate })
            // 3. 差集 = 被 cut 掉的（即被選取的）
            let removedIds = beforeIds.subtracting(afterIds)
            guard !removedIds.isEmpty else { return }

            // 4. 以新顏色重建被剪的筆劃並加回
            let uiColor = UIColor(newColor)
            var restored = after
            for original in before where removedIds.contains(original.path.creationDate) {
                let newInk = PKInk(original.ink.inkType, color: uiColor)
                let recolored = PKStroke(ink: newInk, path: original.path, transform: original.transform, mask: original.mask)
                restored.append(recolored)
            }
            canvas.drawing = PKDrawing(strokes: restored)
            self.currentDrawing = canvas.drawing
            self.saveCurrentPageDrawing()
            self.hasLassoSelection = false
        }
    }

    private var drawingToolbarContent: some View {
        VStack(spacing: 0) {
            if editorMode == .type && activeInlineInkBlockId != nil {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.tip")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)
                    Text(localizationManager.localized("ed_ink_toolbar_hint"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            activeInlineInkBlockId = nil
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text(localizationManager.localized("ed_done_back_to_doc"))
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.12))
                Divider()
            }

            // 文字標籤（S-261b）。
            //
            // 使用者關掉的話就**不提供**帶標籤的那個變體 —— 原本這裡完全
            // 由 `ViewThatFits` 依寬度決定，塞得下就一定有字。
            // 泰文與日文的字串比英文長 30–50%，那些語言核心預設只給圖示，
            // 而使用者也該有權在任何語言下關掉它。
            ViewThatFits(in: .horizontal) {
                if toolbarSettings.showLabels {
                    drawingToolbarRow(showToolLabels: true)
                }
                drawingToolbarRow(showToolLabels: false)
                WrapLayout(spacing: 12, lineSpacing: 8) {
                    drawingToolbarItems(showToolLabels: false)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        // 使用者把正在用的那一支關掉時要換一支，否則畫面上沒有任何按鈕
        // 是亮的，而畫布還在用那支筆 —— 他看到的是「我的筆不見了，
        // 但寫出來還是原本那支」。換成哪一支由核心決定（S-261），
        // Android 走同一條規則。
        .onChange(of: toolbarSettings.hiddenIdentifiers) { _ in
            let next = toolbarSettings.identifierAfterHiding(selectedTool.parityIdentifier)
            guard next != selectedTool.parityIdentifier,
                  let tool = EditorToolType.allCases.first(where: { $0.parityIdentifier == next })
            else { return }
            selectEditorTool(tool)
        }
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
                ForEach(EditorToolType.allCases.filter { $0.isBrush && toolbarSettings.isVisible($0.parityIdentifier) }) { tool in
                    Button {
                        selectEditorTool(tool)
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
                    .accessibilityIdentifier(tool.parityIdentifier)
                    .help(localizationManager.localized(tool.localizationKey))
                }

                ToolbarSeparator()
                    .frame(height: 24)

                // 擦除與選取。與筆刷分開，因為它們不沾墨，也不吃顏色與粗細。
                ForEach(EditorToolType.allCases.filter { !$0.isBrush && toolbarSettings.isVisible($0.parityIdentifier) }) { tool in
                    Button {
                        selectEditorTool(tool)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: selectedTool == .lasso && tool == .lasso ? "xmark.circle.fill" : tool.iconName)
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
                    .accessibilityIdentifier(tool.parityIdentifier)
                    .help(tool == .lasso ? "套索框選 (Lasso) - 再按一次可取消框選模式" : localizationManager.localized(tool.localizationKey))
                }

                Button {
                    let draft = insertTextBox(at: CGPoint(x: 200, y: 200))
                    withAnimation(.easeInOut(duration: 0.18)) {
                        editorMode = .type
                        inlineEditingTextId = draft.id
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "plus.bubble")
                            .font(.system(size: 16, weight: .regular))
                        if showToolLabels {
                            Text(localizationManager.localized("add_text_box"))
                                .font(.system(size: 10))
                        }
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, DS.Space.xs)
                    .padding(.vertical, 5)
                    .background(Color.clear)
                    .cornerRadius(DS.Radius.s)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizationManager.localized("add_text_box"))
                .help(localizationManager.localized("add_text_box"))

                ToolbarSeparator()
                    .frame(height: 24)

                // 筆刷粗細：四個預設點 + 可拖曳的滑桿
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
                    .accessibilityIdentifier("editor.ink.width")
                }

                ToolbarSeparator()
                    .frame(height: 24)

                // 色彩選擇盤
                HStack(spacing: DS.Space.xs) {
                    ForEach(colorPalette, id: \.self) { color in
                        Button {
                            selectedColor = color
                        } label: {
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
                        .accessibilityLabel(inkColorName(for: color))
                        .accessibilityAddTraits(selectedColor == color ? [.isSelected] : [])
                    }

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

                    // 🌟 專業 HSV 色相環與和諧色彈窗
                    Button {
                        showProColorWheel = true
                    } label: {
                        Image(systemName: "circle.hexagongrid.fill")
                            .font(.system(size: DS.Icon.small, weight: .medium))
                            .foregroundStyle(DS.Color.secondaryText)
                            .frame(width: DS.Icon.medium, height: DS.Icon.medium)
                    }
                    .buttonStyle(.plain)
                    .help(localizationManager.localized("ink_pro_wheel"))
                    .accessibilityLabel(localizationManager.localized("ink_pro_wheel"))
                    .popover(isPresented: $showProColorWheel) {
                        ProColorWheelView(
                            selectedColorHex: Binding(
                                get: { selectedColor.toHex() ?? "#000000" },
                                set: { hex in selectedColor = Color(hex: hex) ?? selectedColor }
                            ),
                            onColorSelected: { hex in
                                selectedColor = Color(hex: hex) ?? selectedColor
                            }
                        )
                    }
                }
                .accessibilityIdentifier("editor.ink.palette")

                ToolbarSeparator().frame(height: 24)

                // 🌟 專業筆刷平滑防抖 (Stroke Stabilizer)
                Menu {
                    Button(localizationManager.localized("stab_off")) { strokeStabilizer = 0.0 }
                    Button(localizationManager.localized("stab_light")) { strokeStabilizer = 0.25 }
                    Button(localizationManager.localized("stab_medium")) { strokeStabilizer = 0.50 }
                    Button(localizationManager.localized("stab_strong")) { strokeStabilizer = 0.85 }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "waveform.path")
                            .font(.system(size: 13, weight: strokeStabilizer > 0 ? .bold : .regular))
                        if strokeStabilizer > 0 {
                            Text("\(Int(strokeStabilizer * 100))%")
                                .font(.system(size: 9, weight: .bold))
                        }
                    }
                    .foregroundColor(strokeStabilizer > 0 ? .accentColor : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(strokeStabilizer > 0 ? Color.accentColor.opacity(0.15) : Color.clear)
                    .cornerRadius(6)
                }
                .help(localizationManager.localized("stab_title"))
                .accessibilityLabel(localizationManager.localized("stab_title"))

                // 🌟 鏡像對稱尺規 (Symmetry Guide)
                Button {
                    isSymmetryActive.toggle()
                } label: {
                    Image(systemName: isSymmetryActive ? "arrow.left.and.right.square.fill" : "arrow.left.and.right.square")
                        .font(.system(size: 14, weight: isSymmetryActive ? .bold : .regular))
                        .foregroundColor(isSymmetryActive ? .accentColor : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(isSymmetryActive ? Color.accentColor.opacity(0.15) : Color.clear)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized("symmetry_guide"))
                .accessibilityLabel(localizationManager.localized("symmetry_guide"))

                // 🌟 響應式極簡畫布收折按鈕
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                        isMinimalistCanvasActive.toggle()
                    }
                } label: {
                    Image(systemName: isMinimalistCanvasActive ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(4)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized(
                    isMinimalistCanvasActive ? "exit_canvas_minimal_mode" : "enter_canvas_minimal_mode"
                ))
                .accessibilityLabel(localizationManager.localized(
                    isMinimalistCanvasActive ? "exit_canvas_minimal_mode" : "enter_canvas_minimal_mode"
                ))

                // 🌟 徑向飛輪快捷工具盤 (Radial Pie Menu) 手動喚醒按鈕
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
                        radialMenuCenter = CGPoint(x: 200, y: 180)
                        showRadialMenu.toggle()
                    }
                } label: {
                    Image(systemName: showRadialMenu ? "circle.circle.fill" : "circle.circle")
                        .font(.system(size: 14, weight: showRadialMenu ? .bold : .regular))
                        .foregroundColor(showRadialMenu ? .accentColor : .secondary)
                        .padding(4)
                        .background(showRadialMenu ? Color.accentColor.opacity(0.15) : Color.clear)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized("radial_menu"))
                .accessibilityLabel(localizationManager.localized("radial_menu"))

                eraserModeControls

                // 若為套索選取工具，即時展開剪下、複製、轉文字與刪除選取筆劃按鈕
                if selectedTool == .lasso {
                    ToolbarSeparator()
                        .frame(height: 24)

                    HStack(spacing: 6) {
                        lassoActionButton("scissors", "cut_selected", "cut_selected_hint") { cutSelectedStrokes() }
                        lassoActionButton("doc.on.doc", "copy_selected", "copy_selected_hint") { copySelectedStrokes() }
                        lassoActionButton("plus.square.on.square", "duplicate_selected", "duplicate_selected_hint") { duplicateSelectedStrokes() }
                        lassoActionButton("doc.on.clipboard", "paste_strokes", "paste_strokes_hint") { pasteStrokes() }
                        lassoActionButton("photo.on.rectangle", "save_as_sticker", "save_as_sticker_hint") { saveSelectedAsSticker() }

                        // 🌟 套索轉化傳送門：手寫直接轉為文字方塊
                        lassoActionButton("text.viewfinder", "recognize_handwriting", "recognize_handwriting") {
                            recognizeHandwritingToTextBox()
                        }

                        // 🌟 動態流式錨定：手寫筆劃錨定至文字方塊
                        lassoActionButton("link.badge.plus", "sticky_anchor_text", "sticky_anchored_hint") {
                            anchorSelectedStrokesToNearestText()
                        }
                        
                        lassoRecolorButton

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

                // 復原與重做
                HStack(spacing: 8) {
                    if toolbarSettings.isVisible("editor.ink.undo") {
                    Button {
                        performUndo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel(localizationManager.localized("undo"))
                    .help(localizationManager.localized("undo"))
                    .accessibilityIdentifier("editor.ink.undo")
                    }

                    if toolbarSettings.isVisible("editor.ink.redo") {
                    Button {
                        canvasView?.undoManager?.redo()
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel(localizationManager.localized("redo"))
                    .help(localizationManager.localized("redo"))
                    .accessibilityIdentifier("editor.ink.redo")
                    }

                    if toolbarSettings.isVisible("editor.ink.clear") {
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
                    .accessibilityIdentifier("editor.ink.clear")
                    }
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
        // 1. 新增文字方塊按鈕
        Button {
            _ = insertTextBox(at: CGPoint(x: 200, y: 200))
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus.bubble")
                    .font(.system(size: 13, weight: .semibold))
                Text(localizationManager.localized("add_text_box"))
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.accentColor)
            .cornerRadius(7)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized("add_text_box"))
        .help(localizationManager.localized("add_text_box"))
        .accessibilityIdentifier("editor.text.add_box")

        // 2. 文字排版 / 樣式面板
        Button {
            newTextDraft = activeTextAttachment ?? NoteTextAttachment(pageIndex: currentPageIndex)
            showWordStudio = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "character.textbox")
                    .font(.system(size: 13))
                Text(localizationManager.localized("tool_text"))
                    .font(.system(size: 11))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(7)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized("word_studio"))
        .help(localizationManager.localized("word_studio"))
        .accessibilityIdentifier("editor.text.studio")

        Divider().frame(height: 20)

        // 🌟 字級調節 (A- / 字號 / A+)
        HStack(spacing: 2) {
            Button {
                changeActiveTextFontSize(delta: -2)
            } label: {
                Text("A-")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)

            Text("\(Int(activeTextAttachment?.fontSize ?? 16))")
                .font(.system(size: 11, weight: .bold))
                .frame(width: 22)

            Button {
                changeActiveTextFontSize(delta: 2)
            } label: {
                Text("A+")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
        }
        .padding(2)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)

        // 🌟 常用字色快捷色盤 (黑、深灰、藍、紅、綠、橙)
        HStack(spacing: 4) {
            ForEach(["#000000", "#555555", "#007AFF", "#FF3B30", "#34C759", "#FF9500"], id: \.self) { colorHex in
                Circle()
                    .fill(Color(hex: colorHex) ?? .black)
                    .frame(width: 15, height: 15)
                    .overlay(
                        Circle()
                            .stroke(
                                (activeTextAttachment?.textColorHex ?? "#000000").caseInsensitiveCompare(colorHex) == .orderedSame ? Color.accentColor : Color.secondary.opacity(0.25),
                                lineWidth: (activeTextAttachment?.textColorHex ?? "#000000").caseInsensitiveCompare(colorHex) == .orderedSame ? 2.5 : 1
                            )
                    )
                    .onTapGesture {
                        setActiveTextColor(colorHex)
                    }
            }
        }
        .padding(.horizontal, 5)
        .frame(height: 30)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)

        // 3. 粗體、斜體、底線快捷按鈕
        HStack(spacing: 2) {
            Button {
                toggleActiveTextBold()
            } label: {
                Image(systemName: "bold")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 26, height: 26)
                    .background(isCurrentTextBold ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("text_bold"))
            .accessibilityIdentifier("editor.text.bold")

            Button {
                toggleActiveTextItalic()
            } label: {
                Image(systemName: "italic")
                    .font(.system(size: 12))
                    .frame(width: 26, height: 26)
                    .background(isCurrentTextItalic ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("text_italic"))
            .accessibilityIdentifier("editor.text.italic")

            Button {
                toggleActiveTextUnderline()
            } label: {
                Image(systemName: "underline")
                    .font(.system(size: 12))
                    .frame(width: 26, height: 26)
                    .background(isCurrentTextUnderline ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("text_underline"))
            .accessibilityIdentifier("editor.text.underline")
        }
        .padding(2)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)

        // 4. 段落對齊
        HStack(spacing: 2) {
            Button {
                setActiveTextAlignment("left")
            } label: {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 12))
                    .frame(width: 26, height: 26)
                    .background(currentTextAlignment == "left" ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("align_left"))
            .accessibilityIdentifier("editor.text.align_left")

            Button {
                setActiveTextAlignment("center")
            } label: {
                Image(systemName: "text.aligncenter")
                    .font(.system(size: 12))
                    .frame(width: 26, height: 26)
                    .background(currentTextAlignment == "center" ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("align_center_h"))
            .accessibilityIdentifier("editor.text.align_center")

            Button {
                setActiveTextAlignment("right")
            } label: {
                Image(systemName: "text.alignright")
                    .font(.system(size: 12))
                    .frame(width: 26, height: 26)
                    .background(currentTextAlignment == "right" ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("align_right"))
            .accessibilityIdentifier("editor.text.align_right")
        }
        .padding(2)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)

        Divider().frame(height: 20)

        // 5. 格線/方格吸附開關
        Button {
            snapToGrid.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: snapToGrid ? "squareshape.split.3x3" : "squareshape.dashed.squareshape")
                    .font(.system(size: 13))
                Text(localizationManager.localized("snap_to_grid"))
                    .font(.system(size: 11))
            }
            .foregroundColor(snapToGrid ? .white : .primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(snapToGrid ? Color.accentColor : Color.secondary.opacity(0.12))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized("snap_to_grid"))
        .help(localizationManager.localized("snap_to_grid_desc"))
        .accessibilityIdentifier("editor.text.snap_grid")

        // 6. 圖層層級調整（物件與文字相對順序）
        HStack(spacing: 2) {
            Button {
                bringActiveObjectForward()
            } label: {
                Image(systemName: "square.2.layers.3d.top.filled")
                    .font(.system(size: 12))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("layer_bring_forward"))
            .help(localizationManager.localized("layer_bring_forward"))
            .accessibilityIdentifier("editor.text.layer_forward")

            Button {
                sendActiveObjectBackward()
            } label: {
                Image(systemName: "square.2.layers.3d.bottom.filled")
                    .font(.system(size: 12))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizationManager.localized("layer_send_backward"))
            .help(localizationManager.localized("layer_send_backward"))
            .accessibilityIdentifier("editor.text.layer_backward")
        }
        .padding(2)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)

        Divider().frame(height: 20)

        // 7. 特殊符號選單
        Menu {
            ForEach(symbolCategories(), id: \.self) { category in
                Menu(localizationManager.localized(symbolCategoryKey(category))) {
                    ForEach(symbolPalette(category: category), id: \.self) { sym in
                        Button(sym) {
                            insertQuickTextSnippet(sym)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "star.bubble")
                    .font(.system(size: 14))
                Text(localizationManager.localized("special_symbols"))
                    .accessibilityIdentifier("editor.text.symbols")
                    .font(.system(size: 11))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)

        // 8. 框選模式
        Button {
            isMarqueeActive.toggle()
            if !isMarqueeActive { selectedObjectIds = [] }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "square.dashed")
                    .font(.system(size: 14))
                Text(localizationManager.localized("marquee_select"))
                    .accessibilityIdentifier("editor.text.select")
                    .font(.system(size: 11))
            }
            .foregroundColor(isMarqueeActive ? .white : .primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(isMarqueeActive ? Color.accentColor : Color.secondary.opacity(0.12))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized("marquee_hint"))
        .help(localizationManager.localized("marquee_hint"))

        // 9. 插入連結
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
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized("insert_link"))
        .help(localizationManager.localized("insert_link"))
        .accessibilityIdentifier("editor.text.link")

        Spacer()

        // 10. 復原與重做
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
            .accessibilityIdentifier("editor.text.undo")

            Button {
                canvasView?.undoManager?.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel(localizationManager.localized("redo"))
            .help(localizationManager.localized("redo"))
            .accessibilityIdentifier("editor.text.redo")
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
        // 錄音現在住在套件裡（會被同步）；舊的還在 Kairumo Record，
        // 由 store 決定該指向哪一個。
        let fileUrl = store.recordingFileURL(fileName: fileName, notebookId: notebook.id)
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
        let isPaused = audioManager.status == .paused
        return HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isPaused ? Color.orange : Color.red)
                    .frame(width: 10, height: 10)
                Text(isPaused
                     ? "\(localizationManager.localized("recording_paused")): \(formatTime(seconds: audioManager.elapsedSeconds))"
                     : "\(localizationManager.localized("sync_recording_in_progress")): \(formatTime(seconds: audioManager.elapsedSeconds))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isPaused ? .orange : .red)
            }

            HStack(spacing: 2) {
                ForEach(0..<audioManager.audioLevels.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(isPaused ? Color.orange.opacity(0.6) : Color.red)
                        .frame(width: 3, height: max(4, audioManager.audioLevels[i] * 24))
                }
            }
            .frame(height: 24)

            Spacer()

            // 暫停 / 繼續按鈕
            Button {
                if isPaused {
                    audioManager.resumeRecording()
                } else {
                    audioManager.pauseRecording()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    Text(isPaused
                         ? localizationManager.localized("resume_recording")
                         : localizationManager.localized("pause_recording"))
                }
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(isPaused ? .white : .orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isPaused ? Color.orange : Color.orange.opacity(0.15))
                .cornerRadius(6)
            }

            // 完成錄音按鈕
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
        .background((isPaused ? Color.orange : Color.red).opacity(0.08))
    }

    // MARK: - 6. 畫布上之即時浮動錄音圖示徽章
    private func floatingAudioBadge(fileName: String) -> AnyView { AnyView(floatingAudioBadgeContent(fileName: fileName)) }

    private func floatingAudioBadgeContent(fileName: String) -> some View {
        // 錄音現在住在套件裡（會被同步）；舊的還在 Kairumo Record，
        // 由 store 決定該指向哪一個。
        let fileUrl = store.recordingFileURL(fileName: fileName, notebookId: notebook.id)
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

            Button {
                saveSelectedAsSticker()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle")
                    Text(localizationManager.localized("save_as_sticker"))
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

            Divider()
                .frame(height: 16)

            Button {
                exitLassoMode()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityLabel(localizationManager.localized("ed_cancel_selection"))
            .help(localizationManager.localized("cancel_selection_hint"))
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
        isRecognisingHandwriting = true
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
        // 這一本用的是哪一種紙。畫布、分頁、縮圖與匯出都讀這個值 ——
        // 忘了設的話，換到另一本不同規格的筆記時會沿用上一本的尺寸。
        PageGeometry.use(format: notebook.pageFormatId)
        let loaded = store.loadDrawing(notebookId: notebook.id, pageIndex: currentPageIndex)
        self.currentDrawing = loaded
        self.lastStrokeCount = loaded.strokes.count
        self.currentPageHeight = notebook.height(forPage: currentPageIndex)
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
                if let idx = notebook.textAttachments?.firstIndex(where: { $0.id == item.id }) {
                    notebook.textAttachments?[idx] = item
                } else {
                    notebook.textAttachments?.append(item)
                }
                store.updateNotebook(notebook)
                PageThumbnailRenderer.invalidateAll()
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
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                    .background(Color.accentColor.opacity(0.08))

                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text(L("multi_window_drop_hint"))
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.accentColor)
                .cornerRadius(20)
                .shadow(radius: 6)
            }
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

    /// 筆跡動過了。去抖動之後把筆記標記成剛改過並落盤。
    ///
    /// 1.2 秒與同步排程器的去抖動（1.5 秒）刻意錯開：先把本機狀態定下來，
    /// 再讓同步那一輪去看已經穩定的內容。反過來的話，同步會拿到寫到一半的
    /// 那個瞬間，然後下一輪再傳一次。
    private func noteInkEdited() {
        inkTouchWork?.cancel()
        let work = DispatchWorkItem {
            // `updateNotebook` 自己會蓋上現在的時間，並在 `persistData()`
            // 裡通知自動同步。這裡不碰 `AccountSyncStore` —— 內容改動不是
            // 中繼資料改動，把時戳往前推會讓這台裝置永遠贏過另一台對同一本
            // 筆記的改名，而那次改名其實比較晚。
            store.updateNotebook(notebook)
        }
        inkTouchWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    private func corePackageURL() -> URL {
        store.corePackagesDirectory.appending(path: "\(notebook.id.lowercased()).padnote")
    }

    private func coreInkBaseline(for page: Int) -> PKDrawing {
        if let cached = coreInkBaselines[page] { return cached }
        let packageDrawings = try? NotebookPackageBridge.drawings(
            fromPackageAt: corePackageURL(),
            deviceId: NotebookMigration.deviceId)
        let baseline: PKDrawing
        if let packageDrawings, packageDrawings.indices.contains(page) {
            baseline = packageDrawings[page]
        } else {
            baseline = PKDrawing()
        }
        coreInkBaselines[page] = baseline
        return baseline
    }

    private func recordDrawingEdit(page: Int, drawing: PKDrawing) {
        if page == currentPageIndex {
            currentDrawing = drawing
        }
        pendingCoreInk[page] = drawing
        scheduleCoreInkFlush()
        noteInkEdited()
    }

    private func scheduleCoreInkFlush() {
        coreInkWork?.cancel()
        let work = DispatchWorkItem {
            flushPendingCoreInk()
        }
        coreInkWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    private func flushPendingCoreInk() {
        coreInkWork?.cancel()
        coreInkWork = nil
        let pending = pendingCoreInk
        pendingCoreInk.removeAll()

        for (page, drawing) in pending {
            store.saveDrawing(notebookId: notebook.id, pageIndex: page, drawing: drawing)
            let baseline = coreInkBaseline(for: page)
            let added = StrokeDelta.added(in: drawing, since: baseline)
            guard !added.isEmpty else {
                coreInkBaselines[page] = drawing
                continue
            }
            do {
                try NotebookPackageBridge.appendInkDelta(
                    document: notebook,
                    pageIndex: page,
                    strokes: added,
                    to: corePackageURL(),
                    deviceId: NotebookMigration.deviceId)
                coreInkBaselines[page] = drawing
            } catch {
                // 保留下一輪再試；不要因為核心套件暫時寫不進去而丟掉 Apple 端的
                // 即時 `.drawing` 自動存檔。
                pendingCoreInk[page] = drawing
                print("[InkAutosave] Failed to append ink to package: \(error)")
            }
        }
    }

    private func saveCurrentPageDrawing() {
        // 明確存檔就把待辦的去抖動取消掉 —— 留著的話 1.2 秒後會再寫一次
        // 一模一樣的內容。
        inkTouchWork?.cancel()
        inkTouchWork = nil
        if pageDisplayMode == .continuous {
            flushPendingCoreInk()
            notebook.lastModifiedDate = Date()
            store.updateNotebook(notebook)
            return
        }
        store.saveDrawing(notebookId: notebook.id, pageIndex: currentPageIndex, drawing: currentDrawing)
        pendingCoreInk[currentPageIndex] = currentDrawing
        flushPendingCoreInk()
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
        guard !canvas.drawing.strokes.isEmpty else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
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
        guard !canvas.drawing.strokes.isEmpty else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
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

    // MARK: - 🌟 次世代專業筆刷與手寫轉換 (CSP 防抖、對稱尺規、套索 OCR 轉文字)
    private func recognizeHandwritingToTextBox() {
        let drawing = currentDrawing
        guard !drawing.strokes.isEmpty else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
        let language = localizationManager.currentLanguage.rawValue
        Task { @MainActor in
            switch await HandwritingRecognizer.recognize(drawing: drawing, languageTag: language) {
            case .success(let groups):
                let recognizedText = groups.map(\.text).joined(separator: "\n")
                guard !recognizedText.isEmpty else { return }
                let draft = NoteTextAttachment(
                    id: UUID().uuidString,
                    pageIndex: currentPageIndex,
                    text: recognizedText,
                    fontSize: 18,
                    textColorHex: "#000000",
                    backgroundColorHex: "#FFFFFF",
                    hasBorder: true,
                    x: 160,
                    y: 200,
                    width: 340,
                    height: 140
                )
                if notebook.textAttachments == nil { notebook.textAttachments = [] }
                notebook.textAttachments?.append(draft)
                inlineEditingTextId = draft.id
                store.updateNotebook(notebook)
                PageThumbnailRenderer.invalidateAll()
            case .failure:
                break
            }
        }
    }

    // MARK: - 🌟 文字與手寫動態流式錨定系統 (Fluid Sticky Annotations)
    private func moveAnchoredStrokes(forTextId textId: String, delta: CGSize) {
        guard let anchors = notebook.stickyAnchors, !anchors.isEmpty else { return }
        let matched = anchors.filter { $0.targetId == textId && $0.pageIndex == currentPageIndex }
        guard !matched.isEmpty else { return }

        let drawing = currentDrawing
        var strokes = drawing.strokes
        var modified = false

        for anchor in matched {
            if let indices = anchor.strokeIndices {
                for idx in indices where strokes.indices.contains(idx) {
                    var copy = strokes[idx]
                    copy.transform = copy.transform.translatedBy(x: delta.width, y: delta.height)
                    strokes[idx] = copy
                    modified = true
                }
            }
        }

        if modified {
            let newDrawing = PKDrawing(strokes: strokes)
            self.currentDrawing = newDrawing
            self.canvasView?.drawing = newDrawing
            self.saveCurrentPageDrawing()
            for i in 0..<(notebook.stickyAnchors?.count ?? 0) {
                if notebook.stickyAnchors?[i].targetId == textId {
                    notebook.stickyAnchors?[i].anchorOriginX += Float(delta.width)
                    notebook.stickyAnchors?[i].anchorOriginY += Float(delta.height)
                }
            }
            store.updateNotebook(notebook)
        }
    }

    private func anchorSelectedStrokesToNearestText() {
        let drawing = currentDrawing
        guard !drawing.strokes.isEmpty else { return }

        let pageTexts = (notebook.textAttachments ?? []).filter { $0.pageIndex == currentPageIndex }
        guard !pageTexts.isEmpty else { return }

        for target in pageTexts {
            let textRect = CGRect(x: target.x, y: target.y, width: target.width, height: target.height)
            var matchedIndices: [Int] = []
            for (idx, stroke) in drawing.strokes.enumerated() {
                if textRect.intersects(stroke.renderBounds) {
                    matchedIndices.append(idx)
                }
            }
            if !matchedIndices.isEmpty {
                let anchor = StickyAnnotationAnchor(
                    pageIndex: currentPageIndex,
                    targetId: target.id,
                    strokeIndices: matchedIndices,
                    anchorOriginX: Float(target.x),
                    anchorOriginY: Float(target.y)
                )
                if notebook.stickyAnchors == nil { notebook.stickyAnchors = [] }
                notebook.stickyAnchors?.removeAll { $0.targetId == target.id }
                notebook.stickyAnchors?.append(anchor)
                store.updateNotebook(notebook)
                hasLassoSelection = false
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                return
            }
        }
        if let firstText = pageTexts.first {
            anchorOverlappingInkToText(textItem: firstText)
        }
    }

    private func anchorOverlappingInkToText(textItem: NoteTextAttachment) {
        let drawing = currentDrawing
        guard !drawing.strokes.isEmpty else { return }
        let textRect = CGRect(x: textItem.x, y: textItem.y, width: textItem.width, height: textItem.height)

        var matchedIndices: [Int] = []
        for (idx, stroke) in drawing.strokes.enumerated() {
            if textRect.intersects(stroke.renderBounds) {
                matchedIndices.append(idx)
            }
        }

        guard !matchedIndices.isEmpty else { return }
        let anchor = StickyAnnotationAnchor(
            pageIndex: currentPageIndex,
            targetId: textItem.id,
            strokeIndices: matchedIndices,
            anchorOriginX: Float(textItem.x),
            anchorOriginY: Float(textItem.y)
        )
        if notebook.stickyAnchors == nil { notebook.stickyAnchors = [] }
        notebook.stickyAnchors?.removeAll { $0.targetId == textItem.id }
        notebook.stickyAnchors?.append(anchor)
        store.updateNotebook(notebook)
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    private func applyStabilizer(to drawing: PKDrawing) -> PKDrawing {
        guard strokeStabilizer > 0.05, let lastStroke = drawing.strokes.last else {
            return drawing
        }
        var ffiPoints: [FfiPoint] = []
        for i in 0..<lastStroke.path.count {
            let p = lastStroke.path[i]
            ffiPoints.append(FfiPoint(x: Float(p.location.x), y: Float(p.location.y)))
        }
        let refined = sketchRefineStroke(points: ffiPoints, intensity: Float(strokeStabilizer))
        guard refined.points.count == lastStroke.path.count else {
            return drawing
        }
        var newStrokePoints: [PKStrokePoint] = []
        for i in 0..<lastStroke.path.count {
            let orig = lastStroke.path[i]
            let newLoc = CGPoint(x: CGFloat(refined.points[i].x), y: CGFloat(refined.points[i].y))
            let pt = PKStrokePoint(
                location: newLoc,
                timeOffset: orig.timeOffset,
                size: orig.size,
                opacity: orig.opacity,
                force: orig.force,
                azimuth: orig.azimuth,
                altitude: orig.altitude
            )
            newStrokePoints.append(pt)
        }
        let newPath = PKStrokePath(controlPoints: newStrokePoints, creationDate: lastStroke.path.creationDate)
        let newStroke = PKStroke(ink: lastStroke.ink, path: newPath, transform: lastStroke.transform, mask: lastStroke.mask)
        var allStrokes = Array(drawing.strokes.dropLast())
        allStrokes.append(newStroke)
        return PKDrawing(strokes: allStrokes)
    }

    private func applySymmetry(to drawing: PKDrawing, axisX: CGFloat = 400) -> PKDrawing {
        guard isSymmetryActive, let lastStroke = drawing.strokes.last else {
            return drawing
        }
        var mirroredPoints: [PKStrokePoint] = []
        for i in 0..<lastStroke.path.count {
            let orig = lastStroke.path[i]
            let mirroredX = 2 * axisX - orig.location.x
            let pt = PKStrokePoint(
                location: CGPoint(x: mirroredX, y: orig.location.y),
                timeOffset: orig.timeOffset,
                size: orig.size,
                opacity: orig.opacity,
                force: orig.force,
                azimuth: -orig.azimuth,
                altitude: orig.altitude
            )
            mirroredPoints.append(pt)
        }
        let mirroredPath = PKStrokePath(controlPoints: mirroredPoints, creationDate: Date())
        let mirroredStroke = PKStroke(ink: lastStroke.ink, path: mirroredPath, transform: lastStroke.transform, mask: lastStroke.mask)
        var allStrokes = drawing.strokes
        allStrokes.append(mirroredStroke)
        return PKDrawing(strokes: allStrokes)
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
        guard !canvas.drawing.strokes.isEmpty else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
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


    private func saveSelectedAsSticker() {
        guard let canvas = canvasView, hasLassoSelection else { return }
        let originalStrokes = canvas.drawing.strokes
        for sv in canvas.subviews where String(describing: type(of: sv)).contains("PKTiledView") {
            if sv.responds(to: #selector(UIResponderStandardEditActions.cut(_:))) {
                sv.perform(#selector(UIResponderStandardEditActions.cut(_:)), with: nil)
            }
        }
        UIApplication.shared.sendAction(#selector(UIResponderStandardEditActions.cut(_:)), to: nil, from: nil, for: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let cutDrawing = canvas.drawing
            let originalDict = Dictionary(uniqueKeysWithValues: originalStrokes.map { ($0.path.creationDate, $0) })
            let cutDict = Dictionary(uniqueKeysWithValues: cutDrawing.strokes.map { ($0.path.creationDate, $0) })
            
            var extractedStrokes: [PKStroke] = []
            for (date, stroke) in originalDict {
                if cutDict[date] == nil {
                    extractedStrokes.append(stroke)
                }
            }
            guard !extractedStrokes.isEmpty else {
                canvas.drawing = PKDrawing(strokes: originalStrokes)
                return
            }
            let tempDrawing = PKDrawing(strokes: extractedStrokes)
            let bounds = tempDrawing.bounds
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let transform = CGAffineTransform(translationX: -center.x, y: -center.y)
            let centeredStrokes = extractedStrokes.map {
                PKStroke(ink: $0.ink, path: $0.path, transform: $0.transform.concatenating(transform), mask: $0.mask)
            }
            let stickerDrawing = PKDrawing(strokes: centeredStrokes)
            StickerManager.shared.saveSticker(stickerDrawing)
            
            canvas.drawing = PKDrawing(strokes: originalStrokes)
            self.hasLassoSelection = false
            self.selectedTool = .pen
        }
    }

    private func copySelectedStrokes() {
        guard let canvas = canvasView else { return }
        guard !canvas.drawing.strokes.isEmpty else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
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
            let rec = store.addRecording(
                title: "\(notebook.title) \(localizationManager.localized("recording_suffix"))",
                durationSeconds: Int(result.duration),
                fileName: fileName,
                linkedNotebookId: notebook.id
            )
            insertAudioAttachment(rec)
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
        self.exportFileExtension = "pdf"
        // 先給預覽（S-100）。分享面板由預覽上的「匯出」再叫出來 ——
        // 使用者要確認的是「版面對不對」，而那件事只有看到結果才答得出來。
        self.showExportPreview = true
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
            self.exportFileExtension = "png"
            self.showExportPreview = true
        }
    }

    /// 把整本筆記打包成 `.padnote`，然後開**儲存對話框**。
    ///
    /// 與 `shareNotebookFile()` 只差在最後開哪一個面板 —— 打包那一段一模
    /// 一樣，所以共用，不要再抄一份（抄漏的那一次會是「存出來的檔案少了
    /// 圖片」，而那要等使用者在另一台裝置打開才發現）。
    private func saveNotebookFile() {
        shareNotebookFile(asSaveDialog: true)
    }

    private func shareNotebookFile(asSaveDialog: Bool = false) {
        saveCurrentPageDrawing()
        let tempDir = FileManager.default.temporaryDirectory.appending(path: "share_\(UUID().uuidString)")
        let pkgDir = tempDir.appending(path: "\(notebook.id).padnote")
        let zipUrl = tempDir.appending(path: "\(notebook.displayTitle()).padnote")

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            var drawings: [PKDrawing] = []
            for p in 0..<notebook.pageCount {
                drawings.append(store.loadDrawing(notebookId: notebook.id, pageIndex: p))
            }
            var imageMap: [String: Data] = [:]
            for att in notebook.attachments ?? [] {
                let fileUrl = store.attachmentsDirectory.appending(path: att.fileName)
                if let data = try? Data(contentsOf: fileUrl) {
                    imageMap[att.fileName] = data
                }
            }
            try NotebookPackageBridge.export(
                document: notebook,
                drawings: drawings,
                imageData: imageMap,
                to: pkgDir,
                deviceId: 0x4150
            )
            try archiveNotebook(packageDir: pkgDir.path, outFile: zipUrl.path)
            let zipData = try Data(contentsOf: zipUrl)
            self.exportPdfData = zipData
            self.exportFileExtension = "padnote"
            if asSaveDialog {
                self.showSaveDialog = true
            } else {
                self.showShareSheet = true
            }
            try? FileManager.default.removeItem(at: tempDir)
        } catch {
            print("[ShareNotebook] Failed to package notebook: \(error)")
            exportAsPdf()
        }
    }

    private func addNewPage() {
        saveCurrentPageDrawing()
        let newIndex = store.addPage(notebookId: notebook.id, paperId: notebook.paperId(forPage: currentPageIndex))
        if let updated = store.notebooks.first(where: { $0.id == notebook.id }) {
            self.notebook = updated
        }
        self.currentPageIndex = newIndex
        self.loadCurrentPage()
    }

    /// 在某一頁後面插入新的一頁。
    ///
    /// `paperId` 為 nil 時沿用整本的樣板；指定時這一頁自己用那一種
    /// （見 `NotebookDocument.pagePaperIds`）。
    private func insertPageAfter(_ index: Int, paperId: String? = nil) {
        saveCurrentPageDrawing()
        let newIndex = store.insertPage(
            notebookId: notebook.id, afterIndex: index, paperId: paperId)
        if let updated = store.notebooks.first(where: { $0.id == notebook.id }) {
            self.notebook = updated
        }
        self.currentPageIndex = newIndex
        self.loadCurrentPage()
        if let paperId, let paper = NoteTemplate(paperId: paperId) {
            showCanvasNotice(localizationManager.localized(paper.localizationKey))
        }
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

    /// 頁面規格選單。
    ///
    /// # 為什麼它在工具列上，而不是收進設定
    ///
    /// 規格同時決定三件事：畫布多大、分頁在哪裡斷、匯出的 PDF 多大。
    /// 它是**編輯當下**會想改的東西（「這份要印成 A5」），不是設定一次
    /// 就不動的偏好。收進設定的話，使用者要先離開筆記才改得到。
    private var pageFormatMenu: some View {
        Menu {
            ForEach(pageFormats(), id: \.id) { format in
                Button {
                    applyPageFormat(format.id)
                } label: {
                    HStack {
                        Text(localizationManager.localized(format.titleKey))
                        if (notebook.pageFormatId ?? defaultPageFormatId()) == format.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                Text(localizationManager.localized(
                    pageFormat(id: notebook.pageFormatId ?? defaultPageFormatId()).titleKey))
                    .font(.system(size: 11))
            }
            .foregroundColor(.accentColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized("page_format"))
        .help(localizationManager.localized("page_format"))
    }

    /// 版面配色。
    ///
    /// # 為什麼是整本一個
    ///
    /// 每一頁各挑一個顏色不是「豐富」，是雜亂 —— 翻頁時整份筆記在閃。
    /// 一本筆記一個調子，而那個調子是使用者選的。
    private var guidePaletteMenu: some View {
        let current = notebook.guidePaletteId ?? guidePalettes().first?.id ?? "graphite"
        return Menu {
            ForEach(guidePalettes(), id: \.id) { palette in
                Button {
                    applyGuidePalette(palette.id)
                } label: {
                    HStack {
                        Text(localizationManager.localized(palette.nameKey))
                        if current == palette.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                // 直接畫出那個顏色。名字旁邊放一個色點，比只寫「靛藍」清楚 ——
                // 使用者要挑的是顏色，不是詞。
                Circle()
                    .fill(Color(uiColor: UIColor(hexString: guidePalette(id: current).accentHex) ?? .systemIndigo))
                    .frame(width: 11, height: 11)
                Text(localizationManager.localized(guidePalette(id: current).nameKey))
                    .font(.system(size: 11))
            }
            .foregroundColor(.accentColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized("guide_palette"))
        .help(localizationManager.localized("guide_palette"))
    }

    private func applyGuidePalette(_ id: String) {
        guard notebook.guidePaletteId != id else { return }
        notebook.guidePaletteId = id
        store.updateNotebook(notebook)
        // 縮圖的快取鍵含配色，所以側欄會跟著換 —— 但畫布要自己重畫一次。
        PageThumbnailRenderer.invalidateAll()
        showCanvasNotice(localizationManager.localized(guidePalette(id: id).nameKey))
    }

    /// 換一種紙。
    ///
    /// 換完之後**既有的內容要跟著進來**：A4 直式換成 A5 之後，原本靠右
    /// 那一欄的東西會落在新頁面外面 —— 畫布上看得到、匯出時整欄不見。
    /// 所以一併把每個物件夾回新的可列印範圍，並講清楚發生了什麼事。
    private func applyPageFormat(_ id: String) {
        guard notebook.pageFormatId != id else { return }
        notebook.pageFormatId = id
        PageGeometry.use(format: id)
        clampAttachmentsIntoPage()
        store.updateNotebook(notebook)
        showCanvasNotice(localizationManager.localized("page_format_change_warning"))
    }

    /// 把所有附件夾回目前頁面的可列印範圍。
    private func clampAttachmentsIntoPage() {
        let page = PageGeometry.size
        let inset = Float(PageGeometry.printableInset)

        func fit(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            let clamped = clampToPrintable(
                rect: FfiRect(
                    minX: Float(x), minY: Float(y),
                    maxX: Float(x + w), maxY: Float(y + h)),
                pageWidth: Float(page.width), pageHeight: Float(page.height), inset: inset)
            return CGRect(
                x: CGFloat(clamped.minX), y: CGFloat(clamped.minY),
                width: CGFloat(clamped.maxX - clamped.minX),
                height: CGFloat(clamped.maxY - clamped.minY))
        }

        notebook.attachments = notebook.attachments?.map { item in
            var moved = item
            let r = fit(item.x, item.y, item.width, item.height)
            moved.x = r.minX; moved.y = r.minY
            moved.width = r.width; moved.height = r.height
            return moved
        }
        notebook.textAttachments = notebook.textAttachments?.map { item in
            var moved = item
            let r = fit(item.x, item.y, item.width, item.height)
            moved.x = r.minX; moved.y = r.minY
            moved.width = r.width; moved.height = r.height
            return moved
        }
        notebook.tableAttachments = notebook.tableAttachments?.map { item in
            var moved = item
            let r = fit(item.x, item.y, item.width, 0)
            moved.x = r.minX; moved.y = r.minY
            return moved
        }
        notebook.shapeAttachments = notebook.shapeAttachments?.map { item in
            var moved = item
            let r = fit(item.x, item.y, item.width, item.height)
            moved.x = r.minX; moved.y = r.minY
            return moved
        }
    }

    /// 把落在可列印範圍**之外**的筆畫收回。
    ///
    /// # 為什麼是「完全在外面才收回」
    ///
    /// 界線判斷分三種答案（見核心 `is_within_printable` / `is_outside_printable`）：
    /// 整個在裡面、整個在外面、跨在界線上。三種要分開處理：
    ///
    /// - **整個在外面** → 收回。那一筆印不出來也匯不出去，留著只會讓使用者
    ///   以為它存在，等到列印那天才發現不見了。
    /// - **跨在界線上** → 留著，但提醒一次。寫到一半被整筆吃掉比溢出更難用，
    ///   而且那一筆大半還看得見。
    ///
    /// 要改成「碰到界線就擋」的話，把下面的 `isOutside` 換成 `!isWithin` 即可。
    private func enforcePrintableArea(_ drawing: PKDrawing) -> PKDrawing {
        guard drawing.strokes.count > lastStrokeCount else { return drawing }

        let page = PageGeometry.size
        let inset = Float(PageGeometry.printableInset)
        var kept: [PKStroke] = []
        var rejected = false
        var straddled = false

        for (index, stroke) in drawing.strokes.enumerated() {
            // 只檢查這一次新加的那幾筆 —— 既有的筆畫可能是別的裝置或別的
            // 頁面尺寸下寫的，回頭去刪它們等於幫使用者做了他沒要求的決定。
            guard index >= lastStrokeCount else {
                kept.append(stroke)
                continue
            }
            let bounds = stroke.renderBounds
            let rect = FfiRect(
                minX: Float(bounds.minX), minY: Float(bounds.minY),
                maxX: Float(bounds.maxX), maxY: Float(bounds.maxY))
            if isOutsidePrintable(
                rect: rect, pageWidth: Float(page.width),
                pageHeight: Float(page.height), inset: inset) {
                rejected = true
                continue
            }
            if !isWithinPrintable(
                rect: rect, pageWidth: Float(page.width),
                pageHeight: Float(page.height), inset: inset) {
                straddled = true
            }
            kept.append(stroke)
        }

        if rejected {
            showCanvasNotice(localizationManager.localized("outside_printable_rejected"))
            return PKDrawing(strokes: kept)
        }
        if straddled {
            showCanvasNotice(localizationManager.localized("outside_printable_clamped"))
        }
        return drawing
    }

    /// 在畫布上顯示一則提示，幾秒後自己淡掉。
    private func showCanvasNotice(_ text: String) {
        canvasNoticeToken += 1
        let token = canvasNoticeToken
        withAnimation(.easeInOut(duration: 0.2)) { canvasNotice = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            guard canvasNoticeToken == token else { return }
            withAnimation(.easeInOut(duration: 0.3)) { canvasNotice = nil }
        }
    }

    /// 自動清理重複 ID 與未完成的幽靈空白文字方塊
    private func sanitizeTextAttachments() {
        guard let attachments = notebook.textAttachments, !attachments.isEmpty else { return }
        var seenIds = Set<String>()
        var cleaned: [NoteTextAttachment] = []
        for item in attachments {
            if seenIds.contains(item.id) {
                // 重複 ID：若已存入的是空的但目前這筆有內容，以有內容的替換
                if !item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if let existingIdx = cleaned.firstIndex(where: { $0.id == item.id }),
                       cleaned[existingIdx].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        cleaned[existingIdx] = item
                    }
                }
                continue
            }
            // 清理幽靈空方塊（若文字為空且非當前正在輸入的項目，自動清除）
            if item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && item.id != inlineEditingTextId {
                continue
            }
            seenIds.insert(item.id)
            cleaned.append(item)
        }
        if cleaned.count != attachments.count {
            notebook.textAttachments = cleaned
            store.updateNotebook(notebook)
            PageThumbnailRenderer.invalidateAll()
        }
    }

    private var activeTextAttachment: NoteTextAttachment? {
        if let id = inlineEditingTextId {
            return notebook.textAttachments?.first(where: { $0.id == id })
        }
        if let id = editingTextId {
            return notebook.textAttachments?.first(where: { $0.id == id })
        }
        return notebook.textAttachments?.first(where: { $0.pageIndex == currentPageIndex })
    }

    private var isCurrentTextBold: Bool {
        activeTextAttachment?.isBold ?? false
    }

    private var isCurrentTextItalic: Bool {
        activeTextAttachment?.isItalic ?? false
    }

    private var isCurrentTextUnderline: Bool {
        activeTextAttachment?.isUnderline ?? false
    }

    private var currentTextAlignment: String {
        activeTextAttachment?.alignmentRaw ?? "left"
    }

    private func toggleActiveTextBold() {
        guard let id = activeTextAttachment?.id,
              let index = notebook.textAttachments?.firstIndex(where: { $0.id == id }) else { return }
        notebook.textAttachments?[index].isBold.toggle()
        store.updateNotebook(notebook)
        PageThumbnailRenderer.invalidateAll()
    }

    private func toggleActiveTextItalic() {
        guard let id = activeTextAttachment?.id,
              let index = notebook.textAttachments?.firstIndex(where: { $0.id == id }) else { return }
        notebook.textAttachments?[index].isItalic.toggle()
        store.updateNotebook(notebook)
        PageThumbnailRenderer.invalidateAll()
    }

    private func toggleActiveTextUnderline() {
        guard let id = activeTextAttachment?.id,
              let index = notebook.textAttachments?.firstIndex(where: { $0.id == id }) else { return }
        notebook.textAttachments?[index].isUnderline.toggle()
        store.updateNotebook(notebook)
        PageThumbnailRenderer.invalidateAll()
    }

    private func setActiveTextAlignment(_ align: String) {
        guard let id = activeTextAttachment?.id,
              let index = notebook.textAttachments?.firstIndex(where: { $0.id == id }) else { return }
        notebook.textAttachments?[index].alignmentRaw = align
        store.updateNotebook(notebook)
        PageThumbnailRenderer.invalidateAll()
    }

    private func changeActiveTextFontSize(delta: CGFloat) {
        guard let id = activeTextAttachment?.id,
              let index = notebook.textAttachments?.firstIndex(where: { $0.id == id }) else { return }
        let current = notebook.textAttachments?[index].fontSize ?? 16
        notebook.textAttachments?[index].fontSize = max(10, min(72, current + delta))
        store.updateNotebook(notebook)
        PageThumbnailRenderer.invalidateAll()
    }

    private func setActiveTextColor(_ hex: String) {
        guard let id = activeTextAttachment?.id,
              let index = notebook.textAttachments?.firstIndex(where: { $0.id == id }) else { return }
        notebook.textAttachments?[index].textColorHex = hex
        store.updateNotebook(notebook)
        PageThumbnailRenderer.invalidateAll()
    }

    private func bringActiveObjectForward() {
        let order = ObjectStacking.normalized(objects: pageStackableObjects, order: notebook.objectOrder(forPage: currentPageIndex))
        let targetId = inlineEditingTextId ?? editingTextId ?? selectedShapeIds.first ?? selectedObjectIds.first ?? (notebook.textAttachments?.last(where: { $0.pageIndex == currentPageIndex })?.id)
        guard let id = targetId else { return }
        let newOrder = ObjectStacking.bringForward([id], in: order)
        notebook.setObjectOrder(newOrder, forPage: currentPageIndex)
        store.updateNotebook(notebook)
    }

    private func sendActiveObjectBackward() {
        let order = ObjectStacking.normalized(objects: pageStackableObjects, order: notebook.objectOrder(forPage: currentPageIndex))
        let targetId = inlineEditingTextId ?? editingTextId ?? selectedShapeIds.first ?? selectedObjectIds.first ?? (notebook.textAttachments?.last(where: { $0.pageIndex == currentPageIndex })?.id)
        guard let id = targetId else { return }
        let newOrder = ObjectStacking.sendBackward([id], in: order)
        notebook.setObjectOrder(newOrder, forPage: currentPageIndex)
        store.updateNotebook(notebook)
    }

    private func isLocationInsideAnyObject(at location: CGPoint, page: Int) -> Bool {
        if let items = notebook.attachments {
            for item in items where item.pageIndex == page {
                if CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -4, dy: -4).contains(location) {
                    return true
                }
            }
        }
        if let items = notebook.shapeAttachments {
            for item in items where item.pageIndex == page {
                if CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -4, dy: -4).contains(location) {
                    return true
                }
            }
        }
        if let items = notebook.tableAttachments {
            for item in items where item.pageIndex == page {
                let layout = item.layout()
                if CGRect(x: item.x, y: item.y, width: CGFloat(layout.width), height: CGFloat(layout.height)).insetBy(dx: -4, dy: -4).contains(location) {
                    return true
                }
            }
        }
        if let items = notebook.audioAttachments {
            for item in items where item.pageIndex == page {
                if CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -4, dy: -4).contains(location) {
                    return true
                }
            }
        }
        if let items = notebook.linkAttachments {
            for item in items where item.pageIndex == page {
                if CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -4, dy: -4).contains(location) {
                    return true
                }
            }
        }
        if let items = notebook.model3DAttachments {
            for item in items where item.pageIndex == page {
                if CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -4, dy: -4).contains(location) {
                    return true
                }
            }
        }
        return false
    }

    private func handleCanvasTapInTypeMode(at location: CGPoint) {
        // 1. 若先前有就地編輯但未打任何字的空方塊，先自動清理
        if let activeId = inlineEditingTextId,
           let activeItem = notebook.textAttachments?.first(where: { $0.id == activeId }),
           activeItem.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notebook.textAttachments?.removeAll { $0.id == activeId }
            store.updateNotebook(notebook)
            inlineEditingTextId = nil
            PageThumbnailRenderer.invalidateAll()
        }

        // 2. 檢查是否點擊在既有文字範圍內
        if let existing = notebook.textAttachments?.first(where: { item in
            item.pageIndex == currentPageIndex &&
            CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -12, dy: -12).contains(location)
        }) {
            // 直接就地聚焦編輯既有文字，絕不彈出浮動面板
            inlineEditingTextId = existing.id
            editingTextId = nil
            return
        }

        // 3. 若點擊在其他畫布物件（圖片、表格、形狀、錄音卡片、3D等）上，不新增文字，讓該物件處理選取
        if isLocationInsideAnyObject(at: location, page: currentPageIndex) {
            inlineEditingTextId = nil
            return
        }

        // 4. 點擊空白處：隨點隨打，像 Word 即點即書，建立自然排版文字
        let draft = insertTextBox(at: location)
        inlineEditingTextId = draft.id
        editingTextId = nil
    }

    /// 在畫布的指定位置新增一個空文字方塊並直接進入隨點隨打。
    @discardableResult
    private func insertDefaultTable() {
        if notebook.tableAttachments == nil { notebook.tableAttachments = [] }
        notebook.tableAttachments?.append(NoteTableAttachment(pageIndex: currentPageIndex, x: 200, y: 200, rows: 3, cols: 3))
        store.updateNotebook(notebook)
    }

    private func insertDefaultShape() {
        if notebook.shapeAttachments == nil { notebook.shapeAttachments = [] }
        notebook.shapeAttachments?.append(NoteShapeAttachment(pageIndex: currentPageIndex, kindName: "rectangle", x: 200, y: 200, width: 120, height: 80, cornerRadius: 8, strokeColorHex: "#000000", fillColorHex: "#FFFFFF", lineWidth: 2))
        store.updateNotebook(notebook)
    }

    private func insertTextBox(at location: CGPoint) -> NoteTextAttachment {
        var targetX = location.x
        var targetY = location.y
        if snapToGrid {
            let step: CGFloat = 20.0
            targetX = round(targetX / step) * step
            targetY = round(targetY / step) * step
        }
        let printable = PageGeometry.printableRect
        let startX = max(printable.minX, targetX)
        let midX = PageGeometry.width / 2
        // 若在左右分欄或四象限結構的左半部，文字寬度以中線為界；否則延伸至右側可列印邊界
        let availWidth: CGFloat
        if startX < midX - 30 && printable.maxX > midX {
            availWidth = max(180, midX - startX - 12)
        } else {
            availWidth = max(180, printable.maxX - startX)
        }
        let draft = NoteTextAttachment(
            id: UUID().uuidString,
            pageIndex: currentPageIndex,
            text: "",
            fontSize: activeTextAttachment?.fontSize ?? 16,
            textColorHex: activeTextAttachment?.textColorHex ?? "#000000",
            backgroundColorHex: "clear",
            hasBorder: false,
            x: startX,
            y: max(printable.minY, min(targetY, printable.maxY - 40)),
            width: availWidth,
            height: 40
        )
        if notebook.textAttachments == nil {
            notebook.textAttachments = []
        }
        notebook.textAttachments?.append(draft)
        var order = ObjectStacking.normalized(objects: pageStackableObjects, order: notebook.objectOrder(forPage: currentPageIndex))
        order = ObjectStacking.bringToFront([draft.id], in: order)
        notebook.setObjectOrder(order, forPage: currentPageIndex)

        store.updateNotebook(notebook)
        return draft
    }

    /// 符號分類的語系鍵。與 Android 的 `categoryKey` 同一組。
    private func symbolCategoryKey(_ category: FfiSymbolCategory) -> String {
        switch category {
        case .special: return "special_symbols"
        case .punctuation: return "punctuation_symbols"
        case .math: return "math_symbols"
        case .roman: return "roman_symbols"
        }
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
        if let idx = notebook.textAttachments?.firstIndex(where: { $0.id == newBox.id }) {
            notebook.textAttachments?[idx] = newBox
        } else {
            notebook.textAttachments?.append(newBox)
        }
        store.updateNotebook(notebook)
        PageThumbnailRenderer.invalidateAll()
    }

    /// 將語音辨識/轉錄出的文字稿作為文字方塊插入在該錄音卡片下方
    private func insertTranscriptText(_ text: String, for audio: NoteAudioAttachment) {
        let boxWidth: CGFloat = max(240, audio.width)
        let boxHeight: CGFloat = max(80, CGFloat(min(240, 40 + (text.count / 20) * 24)))
        let targetX = audio.x
        let targetY = audio.y + audio.height + 16

        let transcriptBox = NoteTextAttachment(
            id: UUID().uuidString,
            pageIndex: audio.pageIndex,
            text: text,
            fontSize: 16,
            isBold: false,
            backgroundColorHex: "#F2F4F7",
            hasBorder: true,
            cornerRadius: 10,
            borderColorHex: "#D0D5DD",
            borderWidth: 1.0,
            x: targetX,
            y: targetY,
            width: boxWidth,
            height: boxHeight
        )

        if notebook.textAttachments == nil {
            notebook.textAttachments = []
        }
        if let idx = notebook.textAttachments?.firstIndex(where: { $0.id == transcriptBox.id }) {
            notebook.textAttachments?[idx] = transcriptBox
        } else {
            notebook.textAttachments?.append(transcriptBox)
        }

        var order = ObjectStacking.normalized(objects: pageStackableObjects, order: notebook.objectOrder(forPage: audio.pageIndex))
        order = ObjectStacking.bringToFront([transcriptBox.id], in: order)
        notebook.setObjectOrder(order, forPage: audio.pageIndex)

        store.updateNotebook(notebook)
        PageThumbnailRenderer.invalidateAll()
        withAnimation(.easeInOut(duration: 0.18)) {
            editorMode = .type
            inlineEditingTextId = transcriptBox.id
        }
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
    /// 匯入的音訊檔變成一張跟自己錄的完全一樣的卡片。
    ///
    /// **它會被登記成一段真正的錄音**（`addRecording`），而不是另一種
    /// 只在這一頁存在的附件。理由是使用者接下來會做的每一件事 ——
    /// 播放、在「最近錄音」找它、讓它跟著筆記本同步到另一台裝置 ——
    /// 走的都是錄音那條路；自成一格的話，那些全部要再實作一次，
    /// 而漏掉的那一項會變成「這張卡片按了沒反應」。
    private func insertImportedAudio(_ outcome: FileImport.Outcome) {
        // 長度走核心算（S-42）。各平台問各自的系統 API 的話，
        // 同一個檔案在兩台裝置上會顯示不同的秒數。
        let url = store.recordingFileURL(fileName: outcome.storedName, notebookId: nil)
        let seconds = (try? Data(contentsOf: url)).map {
            Int(audioDurationSeconds(bytes: $0))
        } ?? 0
        let rec = store.addRecording(
            title: outcome.displayName,
            durationSeconds: seconds,
            fileName: outcome.storedName,
            linkedNotebookId: notebook.id
        )
        insertAudioAttachment(rec)
    }

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

    /// 把某個物件的左上角搬到指定座標（並夾回可列印區域，S-85）。
    private func moveObject(id: String, to rawOrigin: CGPoint) {
        let size = frameOfObject(id: id)?.size ?? .zero
        let page = PageGeometry.size
        let inset = Float(PageGeometry.printableInset)
        let clamped = clampToPrintable(
            rect: FfiRect(
                minX: Float(rawOrigin.x), minY: Float(rawOrigin.y),
                maxX: Float(rawOrigin.x + size.width), maxY: Float(rawOrigin.y + size.height)),
            pageWidth: Float(page.width), pageHeight: Float(page.height), inset: inset)
        let origin = CGPoint(x: CGFloat(clamped.minX), y: CGFloat(clamped.minY))

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
/// 系統的儲存對話框。
///
/// Catalyst 上這就是 macOS 的儲存面板（拿不到 `NSSavePanel` —— 這是一個
/// UIKit 程式），iOS 上是「檔案」的儲存介面。
///
/// `asCopy: true`：交出去的是副本。少了它，使用者存完之後我們那份暫存檔
/// 會被系統搬走，而暫存目錄隨時會被清掉。
struct SaveToFilesView: UIViewControllerRepresentable {
    let data: Data
    let filename: String

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let tempUrl = FileManager.default.temporaryDirectory.appending(path: filename)
        try? data.write(to: tempUrl, options: .atomic)
        return UIDocumentPickerViewController(forExporting: [tempUrl], asCopy: true)
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}

struct ShareActivityView: UIViewControllerRepresentable {
    let data: Data
    let filename: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let tempUrl = FileManager.default.temporaryDirectory.appending(path: filename)
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
                DragGesture(minimumDistance: 5, coordinateSpace: .named(CanvasCoordinateSpace.name))
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
                        if hypot(value.translation.width, value.translation.height) < 4 {
                            isSelected.toggle()
                            collaborationManager.broadcastSelection(selectedId: isSelected ? attachment.id : nil)
                        } else {
                            var transaction = Transaction()
                            transaction.animation = nil
                            withTransaction(transaction) {
                                // 拖出可列印範圍的物件推回邊界（S-85）。
                                let landed = PrintableArea.clampOrigin(
                                    x: attachment.x + value.translation.width,
                                    y: attachment.y + value.translation.height,
                                    width: attachment.width, height: attachment.height)
                                attachment.x = landed.x
                                attachment.y = landed.y
                                dragOffset = .zero
                                isDragging = false
                            }
                            if let data = try? JSONEncoder().encode(attachment),
                               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                collaborationManager.broadcastAttachmentUpsert(type: "image", itemDict: dict)
                            }
                        }
                        dragOffset = .zero
                        isDragging = false
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
        .padding(20)
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
    @Binding var isEditingInline: Bool
    var isTypeMode: Bool = false
    let onEdit: () -> Void
    let onDelete: () -> Void
    var onMoved: ((CGSize) -> Void)? = nil
    var onAnchorInk: (() -> Void)? = nil

    @ObservedObject var localizationManager = LocalizationManager.shared
    @ObservedObject var collaborationManager = CollaborationManager.shared
    @State private var dragOffset: CGSize = .zero
    /// 縮放期間的本地預覽寬度（理由同 `AttachmentItemView.liveSize`）。
    @State private var liveWidth: CGFloat? = nil
    @State private var resizeBaseWidth: CGFloat? = nil
    @State private var isSelected: Bool = false
    @State private var isDragging: Bool = false
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
                    // 就地編輯：隨點隨打，鍵盤自動升起，不必開面板
                    ZStack(alignment: .topLeading) {
                        if textItem.text.isEmpty && !isTypeMode {
                            Text(localizationManager.localized("text_placeholder"))
                                .font(.system(size: textItem.fontSize, weight: textItem.isBold ? .bold : .regular))
                                .italic(textItem.isItalic)
                                .foregroundColor(Color.secondary.opacity(0.45))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                                .frame(maxWidth: .infinity, alignment: resolveFrameAlignment(textItem.alignmentRaw))
                        }

                        TextEditor(text: $textItem.text)
                            .font(.system(size: textItem.fontSize, weight: textItem.isBold ? .bold : .regular))
                            .foregroundColor(Color(hex: textItem.textColorHex) ?? .primary)
                            .multilineTextAlignment(resolveMultilineAlignment(textItem.alignmentRaw))
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .frame(minWidth: displayWidth, minHeight: max(36, displayHeight))
                            .focused($inlineFocused)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if !isTypeMode {
                            Button {
                                isEditingInline = false
                                inlineFocused = false
                                finishEditing()
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
            // 內距隨方塊大小縮（見 TextBoxMetrics）。小到一格週計畫的格子時，
            // 固定 14 的內距會把可寫的空間吃光。
            .padding(TextBoxMetrics.padding(width: displayWidth, height: displayHeight))
            .frame(width: displayWidth, height: displayHeight, alignment: .top)
            .background(resolveBackground(textItem.backgroundColorHex))
            .clipShape(RoundedRectangle(cornerRadius: textItem.cornerRadius))
            .overlay(
                Group {
                    if let peer = lockedByPeer {
                        RoundedRectangle(cornerRadius: textItem.cornerRadius)
                            .stroke(Color(hex: peer.userColor) ?? .blue, lineWidth: 3)
                    } else if isEditingInline {
                        if isTypeMode && !textItem.hasBorder {
                            Color.clear
                        } else {
                            RoundedRectangle(cornerRadius: textItem.cornerRadius)
                                .stroke(Color.accentColor.opacity(0.85), lineWidth: 1.5)
                        }
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
            .shadow(color: (isTypeMode || isDragging || !textItem.hasBorder) ? Color.clear : Color.black.opacity(0.08), radius: 6, y: 3)
            .contentShape(Rectangle())
            .rotationEffect(.degrees(textItem.canvasRotation))
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
                                    liveWidth = max(TextBoxMetrics.minWidth,
                                                    base.width + value.translation.width)
                                    liveHeight = max(TextBoxMetrics.minHeight,
                                                     base.height + value.translation.height)
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
                // 點兩下＝就地編輯
                guard lockedByPeer == nil else { return }
                isSelected = true
                isEditingInline = true
                inlineFocused = true
            }
            .onTapGesture {
                guard lockedByPeer == nil else { return }
                if isTypeMode {
                    // 打字模式下，單擊文字方塊直接就地編輯
                    isSelected = true
                    isEditingInline = true
                    inlineFocused = true
                } else {
                    if isEditingInline { return }
                    isSelected.toggle()
                    collaborationManager.broadcastSelection(selectedId: isSelected ? textItem.id : nil)
                }
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

                if let onAnchorInk {
                    Button {
                        onAnchorInk()
                    } label: { Label(localizationManager.localized("sticky_anchor_ink"), systemImage: "link.badge.plus") }
                }

                ObjectFrameStyleMenu(style: $textItem, onChange: broadcastTextChange)

                Divider()

                Button(role: .destructive) {
                    onDelete()
                } label: { Label(localizationManager.localized("delete"), systemImage: "trash") }
            }
            .gesture(
                DragGesture(minimumDistance: 5, coordinateSpace: .named(CanvasCoordinateSpace.name))
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
                        if hypot(value.translation.width, value.translation.height) < 4 {
                            if isTypeMode {
                                isSelected = true
                                isEditingInline = true
                                inlineFocused = true
                            } else {
                                isSelected.toggle()
                                collaborationManager.broadcastSelection(selectedId: isSelected ? textItem.id : nil)
                            }
                        } else {
                            let oldX = textItem.x
                            let oldY = textItem.y
                            var transaction = Transaction()
                            transaction.animation = nil
                            withTransaction(transaction) {
                                // 拖出可列印範圍的物件推回邊界（S-85）。
                                let landed = PrintableArea.clampOrigin(
                                    x: textItem.x + value.translation.width,
                                    y: textItem.y + value.translation.height,
                                    width: textItem.width, height: textItem.height)
                                textItem.x = landed.x
                                textItem.y = landed.y
                                dragOffset = .zero
                                isDragging = false
                            }
                            let deltaX = textItem.x - oldX
                            let deltaY = textItem.y - oldY
                            if deltaX != 0 || deltaY != 0 {
                                onMoved?(CGSize(width: deltaX, height: deltaY))
                            }
                            if let data = try? JSONEncoder().encode(textItem),
                               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                collaborationManager.broadcastAttachmentUpsert(type: "text", itemDict: dict)
                            }
                        }
                        dragOffset = .zero
                        isDragging = false
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
        .padding(20)
        .position(x: currentX + displayWidth / 2, y: currentY + displayHeight / 2)
        .onChange(of: isEditingInline) { editing in
            if editing {
                inlineFocused = true
            } else {
                inlineFocused = false
                finishEditing()
            }
        }
        .onChange(of: inlineFocused) { focused in
            if !focused && isEditingInline {
                isEditingInline = false
                finishEditing()
            }
        }
        .onAppear {
            if isEditingInline {
                DispatchQueue.main.async {
                    inlineFocused = true
                }
            }
        }
    }

    private func finishEditing() {
        if textItem.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            onDelete()
        } else {
            broadcastTextChange()
        }
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
                DragGesture(minimumDistance: 5, coordinateSpace: .named(CanvasCoordinateSpace.name))
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        if hypot(value.translation.width, value.translation.height) < 4 {
                            isSelected.toggle()
                        } else {
                            // 拖出可列印範圍的物件推回邊界（S-85）。
                            let landed = PrintableArea.clampOrigin(
                                x: linkItem.x + value.translation.width,
                                y: linkItem.y + value.translation.height,
                                width: linkItem.width, height: linkItem.height)
                            linkItem.x = landed.x
                            linkItem.y = landed.y
                        }
                        dragOffset = .zero
                    }
            )
            .onTapGesture { isSelected.toggle() }
            .padding(20)
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
                DragGesture(minimumDistance: 5, coordinateSpace: .named(CanvasCoordinateSpace.name))
                    .onChanged { value in
                        guard lockedByPeer == nil else { return }
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        guard lockedByPeer == nil else { return }
                        // 拖出可列印範圍的物件推回邊界（S-85）。
                        let landed = PrintableArea.clampOrigin(
                            x: item.x + value.translation.width,
                            y: item.y + value.translation.height,
                            width: item.width, height: item.height)
                        item.x = landed.x
                        item.y = landed.y
                        dragOffset = .zero
                        if let data = try? JSONEncoder().encode(item),
                           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            collaborationManager.broadcastAttachmentUpsert(type: "3d", itemDict: dict)
                        }
                    }
            )

            Model3DInteractiveCardView(
                attachment: $item,
                onDelete: onDelete,
                // 拖卡片本體 = 移動，與畫布上其他每一種物件一致。
                // （旋轉改成卡片右上角那顆鈕先開啟。）
                onMove: { translation in
                    dragOffset = translation
                },
                onMoveEnded: {
                    // 與頂部手把那條路同一個夾擠（S-85：拖出可列印範圍要推回）。
                    let landed = PrintableArea.clampOrigin(
                        x: item.x + dragOffset.width,
                        y: item.y + dragOffset.height,
                        width: item.width, height: item.height)
                    item.x = landed.x
                    item.y = landed.y
                    dragOffset = .zero
                    if let data = try? JSONEncoder().encode(item),
                       let dict = try? JSONSerialization.jsonObject(with: data)
                        as? [String: Any] {
                        collaborationManager.broadcastAttachmentUpsert(type: "3d", itemDict: dict)
                    }
                }
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
            // **右下角的縮放把手。**
            //
            // 在此之前 3D 卡片**完全沒有縮放**：圖片、表格、圖表都有四角
            // 把手，只有它沒有，而卡片寬度寫死在 `.frame(width:)` 裡。
            // 使用者回報的「插入 3D 模型後無法改變大小」就是這一項 ——
            // 那不是他沒找到，是真的沒有。
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Circle().fill(Color.accentColor))
                    .offset(x: 6, y: 6)
                    // **要先變成一個無障礙元素，識別字才有東西可以掛。**
                    //
                    // 這是一張沒有標籤的 `Image`，SwiftUI 不會把它當成元素，
                    // 於是 `.accessibilityIdentifier` 掛了等於沒掛 —— 稽核
                    // 在樹裡一個 `model3d.*` 都找不到，訊息說「模型上沒有
                    // 縮放把手」，而把手其實畫得好好的（截圖裡看得見）。
                    //
                    // 這不只是測試看不到：**VoiceOver 的使用者也碰不到它**，
                    // 所以那是真的缺陷，不是測試的毛病。
                    .accessibilityElement()
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(localizationManager.localized("resize"))
                    .accessibilityIdentifier("model3d.resize")
                    .gesture(
                        DragGesture(minimumDistance: 2)
                            .onChanged { value in
                                // 下限與卡片本身的 `max(200, ...)` 對齊 ——
                                // 不對齊的話縮到最小時把手會跑到卡片外面。
                                item.width = max(200, item.width + value.translation.width)
                                item.height = max(160, item.height + value.translation.height)
                            }
                            .onEnded { _ in
                                if let data = try? JSONEncoder().encode(item),
                                   let dict = try? JSONSerialization.jsonObject(with: data)
                                    as? [String: Any] {
                                    collaborationManager.broadcastAttachmentUpsert(
                                        type: "3d", itemDict: dict)
                                }
                            }
                    )
            }
        }
        .frame(width: max(200, item.width))
        .padding(20)
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




public struct Sticker: Identifiable, Codable {
    public let id: UUID
    public let drawingData: Data
    
    public init(id: UUID = UUID(), drawingData: Data) {
        self.id = id
        self.drawingData = drawingData
    }
}

public class StickerManager: ObservableObject {
    public static let shared = StickerManager()
    private let storageKey = "user_saved_stickers"
    
    @Published public var stickers: [Sticker] = []
    
    private init() {
        loadStickers()
    }
    
    public func saveSticker(_ drawing: PKDrawing) {
        let sticker = Sticker(drawingData: drawing.dataRepresentation())
        stickers.append(sticker)
        persist()
    }
    
    public func removeSticker(withId id: UUID) {
        stickers.removeAll { $0.id == id }
        persist()
    }
    
    private func persist() {
        if let data = try? JSONEncoder().encode(stickers) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func loadStickers() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let loaded = try? JSONDecoder().decode([Sticker].self, from: data) else {
            return
        }
        self.stickers = loaded
    }
}

public struct StickerLibraryView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var manager = StickerManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    public var onSelect: ((PKDrawing) -> Void)?

    /// 內建還是自己存的。
    ///
    /// 原本只有「自己存的」那一半，而它一開始一定是空的 —— 第一次打開
    /// 貼紙庫的人看到一片空白，卻不知道要怎麼生出第一張。
    private enum Tab: Hashable { case builtin, mine }
    @State private var tab: Tab = .builtin

    /// 貼進畫布的尺寸（點）。
    ///
    /// 120 是實測的折衷：小於 90 的話笑臉的眼睛會糊成一點，
    /// 大於 160 的話貼一個勾就佔掉半行字。使用者貼上去之後還能縮放 ——
    /// 它就是一般的筆跡。
    private static let insertSize: CGFloat = 120

    public init(onSelect: ((PKDrawing) -> Void)? = nil) {
        self.onSelect = onSelect
    }

    private func L(_ key: String) -> String { localizationManager.localized(key) }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    Text(L("sticker_builtin")).tag(Tab.builtin)
                    Text(L("sticker_mine")).tag(Tab.mine)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .accessibilityIdentifier("stickers.tab")

                switch tab {
                case .builtin: builtinGrid
                case .mine: mineGrid
                }
            }
            .navigationTitle(L("sticker_library"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("cancel")) { dismiss() }
                        .accessibilityIdentifier("stickers.cancel")
                }
            }
        }
    }

    /// 內建貼紙，依用途分類。
    ///
    /// 分類依「使用者想做什麼」分，不是依圖形長相分 —— 那是核心的決定，
    /// 這裡照著顯示。
    private var builtinGrid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(stickerCategories(), id: \.id) { category in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L(category.titleKey))
                            .font(.headline)
                            .padding(.horizontal)
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 74, maximum: 96), spacing: 12)],
                            spacing: 12
                        ) {
                            ForEach(category.codes, id: \.self) { code in
                                builtinCell(code)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .accessibilityIdentifier("stickers.builtin")
    }

    private func builtinCell(_ code: String) -> some View {
        Button {
            onSelect?(StickerCatalogue.drawing(
                code: code,
                size: Self.insertSize,
                origin: CGPoint(x: 160, y: 200),
                color: UIColor.label))
            dismiss()
        } label: {
            VStack(spacing: 4) {
                StickerGlyph(code: code)
                    .frame(width: 52, height: 52)
                Text(L(stickerLabelKey(code: code)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        // 名稱在底下，但識別碼掛在整顆 Button 上 ——
        // 掛在內層 Text 的話，VoiceOver 與 UI 測試按到的是那行字（S-263）。
        .accessibilityLabel(L(stickerLabelKey(code: code)))
        .accessibilityIdentifier("stickers.item")
    }

    /// 使用者自己存下來的。
    private var mineGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)],
                spacing: 16
            ) {
                ForEach(manager.stickers) { sticker in
                    if let drawing = try? PKDrawing(data: sticker.drawingData) {
                        StickerCell(drawing: drawing) {
                            onSelect?(drawing)
                            dismiss()
                        } onRemove: {
                            manager.removeSticker(withId: sticker.id)
                        }
                    }
                }
            }
            .padding()
        }
        .accessibilityIdentifier("stickers.mine")
        .overlay {
            if manager.stickers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(L("no_stickers")).font(.headline)
                    Text(L("no_stickers_hint"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
    }
}

private struct StickerCell: View {
    let drawing: PKDrawing
    let onSelect: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onSelect) {
                Image(uiImage: drawing.image(from: drawing.bounds, scale: 2.0))
                    .resizable()
                    .scaledToFit()
                    .padding()
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
                    .background(Circle().fill(.white))
            }
            .padding(8)
        }
    }
}

public struct MaskingTapeOverlayView: View {
    @Binding var notebook: NotebookDocument
    let pageIndex: Int
    let isActive: Bool
    let selectedColor: Color
    let onTapesChanged: () -> Void
    
    @State private var currentDragTape: NoteTapeAttachment? = nil
    @State private var dragStartPoint: CGPoint = .zero
    
    public var body: some View {
        ZStack {
            let tapes = notebook.tapeAttachments?.filter { $0.pageIndex == pageIndex } ?? []
            ForEach(tapes) { tape in
                TapeView(
                    tape: tape,
                    isActive: isActive,
                    onToggleReveal: {
                        if let idx = notebook.tapeAttachments?.firstIndex(where: { $0.id == tape.id }) {
                            notebook.tapeAttachments?[idx].isRevealed.toggle()
                            onTapesChanged()
                        }
                    },
                    onRemove: {
                        notebook.tapeAttachments?.removeAll { $0.id == tape.id }
                        onTapesChanged()
                    }
                )
            }
            
            if let dragTape = currentDragTape {
                Rectangle()
                    .fill(selectedColor)
                    .frame(width: dragTape.rect.width, height: dragTape.rect.height)
                    .position(x: dragTape.rect.midX, y: dragTape.rect.midY)
                    .opacity(0.8)
            }
        }
        .background(
            Color.white.opacity(0.001)
                .allowsHitTesting(isActive)
                .gesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            guard isActive else { return }
                            if currentDragTape == nil {
                                dragStartPoint = value.startLocation
                            }
                            let x = min(dragStartPoint.x, value.location.x)
                            let width = abs(value.location.x - dragStartPoint.x)
                            let height: CGFloat = 24.0
                            let rect = CGRect(x: x, y: dragStartPoint.y - height / 2, width: max(width, 10), height: height)
                            
                            currentDragTape = NoteTapeAttachment(pageIndex: pageIndex, rect: rect)
                        }
                        .onEnded { value in
                            guard isActive, let dragTape = currentDragTape else { return }
                            if notebook.tapeAttachments == nil {
                                notebook.tapeAttachments = []
                            }
                            notebook.tapeAttachments?.append(dragTape)
                            currentDragTape = nil
                            onTapesChanged()
                        }
                )
        )
    }
}

private struct TapeView: View {
    let tape: NoteTapeAttachment
    let isActive: Bool
    let onToggleReveal: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        Rectangle()
            .fill(tape.isRevealed ? Color.gray.opacity(0.3) : Color.gray)
            .frame(width: tape.rect.width, height: tape.rect.height)
            .position(x: tape.rect.midX, y: tape.rect.midY)
            .onTapGesture {
                if isActive {
                    onRemove()
                } else {
                    onToggleReveal()
                }
            }
    }
}

/// 「從檔案匯入」那三個修飾詞（挑圖、挑音訊、失敗提示）。
///
/// 收成一個 `ViewModifier` 是因為編輯器的 `body` 修飾詞鏈已經長到
/// 編譯器會放棄型別推導 —— 攤開來寫會讓整支檔案編不過，而錯誤訊息
/// 指的是鏈的開頭，完全看不出是哪一個加上去的。
private struct ImportPickersModifier: ViewModifier {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Binding var showImageFileImporter: Bool
    @Binding var showAudioFileImporter: Bool
    @Binding var importErrorKey: String
    let onImage: (FileImport.Outcome) -> Void
    let onAudio: (FileImport.Outcome) -> Void
    @Binding var showPdfFileImporter: Bool
    let onPdf: (FileImport.Outcome) -> Void
    @Binding var showDocumentFileImporter: Bool
    let onDocument: (FileImport.Outcome) -> Void

    func body(content: Content) -> some View {
        content
            // 挑選器的過濾條件與「收不收」的判斷都來自核心 —— 同一個檔案
            // 在 iPad 上挑得到、在 Android 手機上挑不到，是使用者完全
            // 無法理解的行為。
            .fileImporter(
                isPresented: $showImageFileImporter,
                allowedContentTypes: FileImport.allowedTypes(for: .image),
                allowsMultipleSelection: false
            ) { result in
                guard let outcome = FileImport.take(result: result, slot: .image) else { return }
                if outcome.succeeded { onImage(outcome) } else { importErrorKey = outcome.errorKey }
            }
            .fileImporter(
                isPresented: $showAudioFileImporter,
                allowedContentTypes: FileImport.allowedTypes(for: .audio),
                allowsMultipleSelection: false
            ) { result in
                guard let outcome = FileImport.take(
                    result: result, slot: .audio, into: .recordings) else { return }
                if outcome.succeeded { onAudio(outcome) } else { importErrorKey = outcome.errorKey }
            }
            .fileImporter(
                isPresented: $showPdfFileImporter,
                allowedContentTypes: FileImport.allowedTypes(for: .pdf),
                allowsMultipleSelection: false
            ) { result in
                guard let outcome = FileImport.take(result: result, slot: .pdf) else { return }
                if outcome.succeeded { onPdf(outcome) } else { importErrorKey = outcome.errorKey }
            }

            .fileImporter(
                isPresented: $showDocumentFileImporter,
                allowedContentTypes: FileImport.allowedTypes(for: .document),
                allowsMultipleSelection: false
            ) { result in
                guard let outcome = FileImport.take(result: result, slot: .document) else { return }
                if outcome.succeeded { onDocument(outcome) } else { importErrorKey = outcome.errorKey }
            }
            .alert(
                localizationManager.localized("import_failed_read"),
                isPresented: Binding(
                    get: { !importErrorKey.isEmpty },
                    set: { if !$0 { importErrorKey = "" } })
            ) {
                Button(localizationManager.localized("confirm"), role: .cancel) { importErrorKey = "" }
            } message: {
                // 理由來自核心的 `reason_key` —— 「為什麼不收」兩端講同一句話。
                Text(localizationManager.localized(importErrorKey))
            }
    }
}

/// `.sheet(item:)` 需要 `Identifiable`，而 `URL` 不是。
///
/// 用 `isPresented` + 另一個狀態也做得到，但那有一個很難查的坑：表打開的
/// 那一幀如果 URL 還沒設好，裡面的畫面會拿到 `nil` 然後畫一片空白，而重畫
/// 之後也不會自己補回來。`item:` 把「有東西」與「打開」綁成同一件事。
private struct IdentifiedURL: Identifiable {
    let url: URL
    var id: String { url.path }
}
import SwiftUI

/// 即時游標的資料結構 (對應 Rust PresenceEvent)
public struct PeerCursor: Identifiable {
    public let id: UInt32 // device_id
    public var x: CGFloat
    public var y: CGFloat
    public var color: Color
    public var lastUpdated: Date
    
    public init(id: UInt32, x: CGFloat, y: CGFloat, color: Color) {
        self.id = id
        self.x = x
        self.y = y
        self.color = color
        self.lastUpdated = Date()
    }
}

/// 疊加於 Notebook 畫布上方的多人游標 UI
public struct LiveCursorOverlay: View {
    public var cursors: [PeerCursor]
    
    public init(cursors: [PeerCursor]) {
        self.cursors = cursors
    }
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
            // 背景透明，讓事件可以穿透到下方的畫布
            Color.clear.allowsHitTesting(false)
            
            ForEach(cursors) { cursor in
                VStack(alignment: .leading, spacing: 2) {
                    // 游標本體 (自訂形狀或 SF Symbol)
                    Image(systemName: "cursorarrow")
                        .font(.system(size: 16))
                        .foregroundColor(cursor.color)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1)
                    
                    // 裝置或使用者 ID 標籤
                    Text("Peer \(cursor.id)")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(cursor.color)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                // 使用 animation 讓網路傳來的離散座標平滑移動
                .position(x: cursor.x, y: cursor.y)
                .animation(.linear(duration: 0.15), value: cursor.x)
                .animation(.linear(duration: 0.15), value: cursor.y)
            }
        }
        .allowsHitTesting(false) // 絕對不阻擋使用者的任何觸控與手寫
    }
}
import SwiftUI

/// (Advanced Feature 3) 供時光機與貢獻者高亮使用的資料結構
public struct TextContributor {
    public let range: NSRange
    public let deviceId: UInt32
    public let color: Color
    
    public init(range: NSRange, deviceId: UInt32, color: Color) {
        self.range = range
        self.deviceId = deviceId
        self.color = color
    }
}

/// 時間軸回溯拉桿 UI
public struct TimeMachineSlider: View {
    @Binding public var currentLamport: Double
    public let maxLamport: Double
    
    public init(currentLamport: Binding<Double>, maxLamport: Double) {
        self._currentLamport = currentLamport
        self.maxLamport = maxLamport
    }
    
    public var body: some View {
        VStack {
            Text("歷史回溯 (Lamport: \\(Int(currentLamport)))")
                .font(.headline)
            Slider(value: $currentLamport, in: 0...maxLamport)
                .padding()
            // 當 Slider 拖動時，可呼叫 Rust FFI: `replay_to_lamport`
        }
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(12)
        .shadow(radius: 5)
        .padding()
    }
}
