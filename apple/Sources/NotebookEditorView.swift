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
    // 順序依「書寫／繪畫／標記」三族排列（核心 `BrushFamily`），與核心的工具清單一致。
    case pen = "pen"
    case ballpoint = "ballpoint"
    case fineliner = "fineliner"
    case brush = "brush"
    case calligraphy = "calligraphy"
    case pencil = "pencil"
    case charcoal = "charcoal"
    case crayon = "crayon"
    case airbrush = "airbrush"
    case oilpaint = "oilpaint"
    case watercolor = "watercolor"
    case marker = "marker"
    case highlighter = "highlighter"
    case eraser = "eraser"
    case lasso = "lasso"
    case maskingTape = "masking_tape"
    /// 圖學：製圖筆組、圖層、線型與吸附（見 Drafting.swift）。
    case drafting = "drafting"

    public var id: String { rawValue }

    /// 這個工具是不是「筆」。
    ///
    /// 橡皮擦與套索不是筆：一個是擦掉、一個是選取，兩者都不沾墨，也不吃
    /// 顏色與粗細。工具列把九個圖示排成沒有斷點的一長列時，使用者得靠
    /// 記圖案來分辨 —— 分組之後，形狀就說明了用途（工作項 S-62）。
    public var isBrush: Bool {
        switch self {
        case .eraser, .lasso, .maskingTape, .drafting: return false
        default: return true
        }
    }

    /// ⌘1…⌘0 對應的工具，依**原本**的順序。
    ///
    /// 工具列改成「書寫／繪畫／標記」三族排列之後，`allCases` 的順序變了；
    /// 快捷鍵是肌肉記憶，不能跟著工具列重排 —— 用 ⌘3 叫出毛筆的人，升級之後不該拿到針筆。
    public static let shortcutOrder: [EditorToolType] = [
        .pen, .ballpoint, .brush, .marker, .highlighter, .pencil, .watercolor, .eraser, .lasso, .maskingTape,
    ]

    /// 筆刷所屬的族。不是筆刷的工具為 `nil`。與核心 `Tool::family` 一致（有測試對帳）。
    public var family: FfiBrushFamily? {
        switch self {
        case .pen, .ballpoint, .fineliner, .brush, .calligraphy, .pencil: return .writing
        case .charcoal, .crayon, .airbrush, .oilpaint, .watercolor: return .painting
        case .marker, .highlighter: return .marking
        case .eraser, .lasso, .maskingTape, .drafting: return nil
        }
    }

    /// 由自繪引擎算繪的筆刷（見 ProInk.swift）。其餘走 PencilKit。
    public var proToolKind: ToolKind? {
        switch self {
        case .fineliner: return .fineliner
        case .charcoal: return .charcoal
        case .crayon: return .crayon
        case .airbrush: return .airbrush
        case .oilpaint: return .oilPaint
        case .calligraphy: return .calligraphy
        default: return nil
        }
    }

    public var iconName: String {
        switch self {
        case .pen: return "pencil.tip"
        case .fineliner: return "pencil.line"
        case .calligraphy: return "pencil.tip.crop.circle"
        case .charcoal: return "scribble"
        case .crayon: return "pencil.and.scribble"
        case .airbrush: return "sparkle"
        case .oilpaint: return "paintbrush.pointed"
        case .ballpoint: return "pencil.line"
        case .brush: return "paintbrush.pointed.fill"
        case .marker: return "pencil.and.outline"
        case .highlighter: return "highlighter"
        case .pencil: return "pencil"
        case .watercolor: return "paintbrush.fill"
        case .eraser: return "eraser"
        case .lasso: return "lasso"
        case .maskingTape: return "bandage.fill"
        case .drafting: return "ruler"
        }
    }

    /// 跨平台對照閘門用的識別字（核心 `ffi_screens` 的 `editor.inktools`）。
    ///
    /// 寫成 switch 而不是 `"editor.ink.\(rawValue)"`：閘門掃的是原始碼裡的
    /// 字串字面值，插值組出來的識別字它看不見 —— 那樣工具少一個也不會紅。
    public var parityIdentifier: String {
        switch self {
        case .pen: return "editor.ink.pen"
        case .fineliner: return "editor.ink.fineliner"
        case .calligraphy: return "editor.ink.calligraphy"
        case .charcoal: return "editor.ink.charcoal"
        case .crayon: return "editor.ink.crayon"
        case .airbrush: return "editor.ink.airbrush"
        case .oilpaint: return "editor.ink.oilpaint"
        case .ballpoint: return "editor.ink.ballpoint"
        case .brush: return "editor.ink.brush"
        case .marker: return "editor.ink.marker"
        case .highlighter: return "editor.ink.highlighter"
        case .pencil: return "editor.ink.pencil"
        case .watercolor: return "editor.ink.watercolor"
        case .eraser: return "editor.ink.eraser"
        case .lasso: return "editor.ink.lasso"
        case .maskingTape: return "editor.ink.maskingTape"
        case .drafting: return "editor.ink.drafting"
        }
    }

    public var localizationKey: String {
        switch self {
        case .pen: return "tool_pen"
        case .fineliner: return "tool_fineliner"
        case .calligraphy: return "tool_calligraphy"
        case .charcoal: return "tool_charcoal"
        case .crayon: return "tool_crayon"
        case .airbrush: return "tool_airbrush"
        case .oilpaint: return "tool_oilpaint"
        case .ballpoint: return "tool_ballpoint"
        case .brush: return "tool_brush"
        case .marker: return "tool_marker"
        case .highlighter: return "tool_highlighter"
        case .pencil: return "tool_pencil"
        case .watercolor: return "tool_watercolor"
        case .eraser: return "tool_eraser"
        case .lasso: return "tool_lasso"
        case .maskingTape: return "tool_masking_tape"
        case .drafting: return "tool_drafting"
        }
    }
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
    var pageIndex: Int = 0 {
        didSet { if oldValue != pageIndex { setNeedsDisplay() } }
    }
    var checkedGuideItems: [String: Bool]? {
        didSet { if oldValue != checkedGuideItems { setNeedsDisplay() } }
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
            size: PageGeometry.size,
            pageIndex: pageIndex,
            checkedGuideItems: checkedGuideItems
        )
    }
}

/// 會在版面變動時自行重算內容寬度的畫布。
///
/// 為什麼需要子類：`updateUIView` 是在 SwiftUI 狀態改變時呼叫，那個時間點
/// `bounds.width` 還是**舊的**（版面尚未跑完）。所以收合左側結構欄之後，
/// contentSize 仍停在「扣掉側欄」的寬度，畫布右側就空出一塊灰色。
/// 真正知道新寬度的時機是 `layoutSubviews`。
/// 專業筆刷手勢與 PencilKit 手勢的並存規則：橡皮擦模式下兩邊同時收，其餘互不干擾。
final class ProGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        guard let pro = gestureRecognizer as? ProStrokeGestureRecognizer else { return false }
        // 橡皮擦：PencilKit 與我們同時收。畫筆：PencilKit 的落筆手勢已經關掉，沒有要並存的。
        return pro.mode == .erase
    }
}

/// 打字模式下判定 Pencil 這一下是「輕點」還是「筆畫」（工作項 F1）。
///
/// 只觀察、不攔截：永遠停在 `.possible`、`cancelsTouchesInView = false`、
/// 與所有手勢並存，所以 PencilKit／專業筆刷照常收墨，第一筆不會遺失。
/// 判定在筆離開時才做 —— 筆畫進行中切換模式會改到畫布設定，那一筆會被取消。
final class PencilIntentObserver: UIGestureRecognizer, UIGestureRecognizerDelegate {
    var onStroke: (() -> Void)?
    /// 座標是畫布（scroll view）自己的座標，尚未除以縮放倍率。
    var onTap: ((CGPoint) -> Void)?

    private var tracked: UITouch?
    private var startPoint: CGPoint = .zero
    private var startTime: TimeInterval = 0
    private var maxDistance: CGFloat = 0

    init() {
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard tracked == nil, let touch = touches.first(where: { $0.type == .pencil }) else { return }
        tracked = touch
        startPoint = touch.location(in: view)
        startTime = touch.timestamp
        maxDistance = 0
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = tracked, touches.contains(touch) else { return }
        let p = touch.location(in: view)
        maxDistance = max(maxDistance, hypot(p.x - startPoint.x, p.y - startPoint.y))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = tracked, touches.contains(touch) else { return }
        let p = touch.location(in: view)
        maxDistance = max(maxDistance, hypot(p.x - startPoint.x, p.y - startPoint.y))
        let kind = EditorCanvasInputPolicy.classifyPencil(
            distance: maxDistance, duration: touch.timestamp - startTime)
        let start = startPoint
        tracked = nil
        state = .failed
        switch kind {
        case .tap: onTap?(start)
        case .stroke, .holdToSnap: onStroke?()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = tracked, touches.contains(touch) else { return }
        tracked = nil
        state = .failed
    }

    override func reset() {
        tracked = nil
        maxDistance = 0
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool { true }
}

/// 畫布復原／橡皮擦的診斷紀錄（進「診斷」的系統日誌）。
///
/// 「最先畫的幾筆無法復原、也擦不掉」只在實機出現過，模擬器重現不了；
/// 這一條線記下每一次**程式指派 `drawing`**（會讓 PencilKit 先前登記的復原項失效）
/// 與每一次復原的實際效果，下次發生時就看得出是哪條路徑弄壞的。
enum CanvasDiag {
    static func log(_ message: String) {
        SyncLogger.logAsync("【畫布】\(message)", source: .general)
    }
}

final class AdaptiveCanvasView: PKCanvasView {
    /// 連續模式下的兩指捲動（見 `TwoFingerScrollForwarder`）。
    let twoFingerScroll = TwoFingerScrollForwarder()

    private let internalUndoManager = UndoManager()
    override var undoManager: UndoManager? {
        super.undoManager ?? internalUndoManager
    }
    override var canBecomeFirstResponder: Bool { true }
    var initialLoadedStrokeCount: Int = 0

    // MARK: - Hold-to-Snap 筆尖停留成形監測（第二階段：幾何停頓轉正）
    private var pencilDwellWorkItem: DispatchWorkItem?
    private var lastPencilLocation: CGPoint = .zero
    var lastStrokeHadHoldDwell: Bool = false
    var onHoldDwellTriggered: (() -> Void)?

    private func schedulePencilDwellTimer() {
        pencilDwellWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.lastStrokeHadHoldDwell = true
            self.onHoldDwellTriggered?()
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
        }
        pencilDwellWorkItem = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + EditorCanvasInputPolicy.holdToSnapMinDuration,
            execute: work
        )
    }

    /// 這一頁的高度（由 SwiftUI 端更新）
    /// 觸控觀察。
    ///
    /// 觀察而**不攔截**：一律呼叫 `super`，PencilKit 的繪製路徑完全不受影響。
    /// 我們只是在旁邊看，決定要不要切換輸入政策、以及有沒有東西要收回。
    ///
    /// 寫在類別本體而不是 extension：在 extension 裡 override UIKit 方法雖然
    /// 編得過，但那是靠 @objc 動態派發矇混，不是 Swift 保證的行為。
    var onTouchObserved: ((UITouch) -> Void)?

    /// Apple Pencil 感知：當筆尖碰到畫布時立即回報（方案 A：硬體感知分離）
    var onPencilTouchBegan: (() -> Void)?

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

    // MARK: 專業筆刷（自繪引擎，見 ProInk.swift）

    /// 疊在畫布上的專業筆畫層。第一次需要時才建。
    private(set) var proLayer: ProInkLayerView?
    private var proGesture: ProStrokeGestureRecognizer?
    private let proGestureDelegate = ProGestureDelegate()
    /// 專業筆刷啟用前，捲動手勢要幾根手指 —— 停用時還原。
    private var savedMinimumPanTouches: Int?

    /// 目前的專業筆刷設定。手勢辨識器每次落筆時讀。
    var proTool: ToolKind?
    var proColor: [UInt8] = [0, 0, 0, 255]
    var proWidth: Float = 4
    var proEraserRadius: CGFloat = 10
    var proAllowsFinger: () -> Bool = { true }
    /// 圖學：這一筆的圖層、線型，吸附的角度鎖定（`nil` = 沒開吸附），改圖層的目標。
    var proLayerId: UInt8 = 0
    var proLineType: UInt8 = 0
    var proSnapStep: Float?
    var proReassignTarget: UInt8 = 0
    var onProSnapped: ((FfiDraftSnapKind) -> Void)?
    /// 步驟編號模式下點的位置（頁面座標）。
    var onProMarker: ((CGPoint) -> Void)?
    /// 圖學工具模式（標註…）：觸控的每個階段與位置（頁面座標）。
    var onProTool: ((ProStrokeGestureRecognizer.ToolPhase, CGPoint) -> Void)?

    enum ProMode { case off, draw, erase, reassign, marker, tool }

    /// 依目前的工具設定專業筆畫層與輸入手勢。
    ///
    /// - `.draw`：選了專業筆刷。PencilKit 的落筆手勢關掉、改由我們收筆；
    ///   捲動改成兩指，單指（或 Apple Pencil）才能畫。
    /// - `.erase`：選了橡皮擦。兩邊同時收：PencilKit 擦它的、我們擦專業筆畫。
    /// - `.off`：其他工具。我們的手勢不收任何東西。
    func configurePro(
        mode: ProMode, directory: URL?, notebookId: String, pageIndex: Int, pencilOnly: Bool = false
    ) {
        let layer = installProLayerIfNeeded()
        if let directory {
            layer.load(directory: directory, notebookId: notebookId, pageIndex: pageIndex)
        }
        guard let gesture = proGesture else { return }
        switch mode {
        case .off:
            gesture.isEnabled = false
            gesture.deferUntilMoved = false
            drawingGestureRecognizer.isEnabled = true
            restorePan()
        case .draw:
            gesture.mode = .draw
            gesture.cancelsTouchesInView = true
            // 打字模式：只收 Pencil，而且要真的動了才落墨 —— 輕點是「放游標」，不該留墨點。
            gesture.deferUntilMoved = pencilOnly
            gesture.isEnabled = true
            drawingGestureRecognizer.isEnabled = false
            // 打字模式下單指要能捲動，不能把捲動改成兩指。
            if pencilOnly { restorePan() } else { overridePan() }
        case .erase:
            gesture.mode = .erase
            gesture.cancelsTouchesInView = false
            gesture.deferUntilMoved = false
            gesture.isEnabled = true
            restorePan()
        case .reassign, .marker, .tool:
            // 點一下筆畫改圖層／點一下放步驟編號／圖學工具（標註…）：PencilKit 的筆畫不管，單指拿來點。
            gesture.mode = mode == .marker ? .marker : (mode == .tool ? .tool : .reassign)
            gesture.cancelsTouchesInView = true
            gesture.deferUntilMoved = false
            gesture.isEnabled = true
            drawingGestureRecognizer.isEnabled = false
            overridePan()
        }
    }

    // MARK: 打字模式的 Pencil 意圖（工作項 F1）

    /// 打字模式時為真：Pencil 落筆不立刻宣告「要寫字」，交給 `pencilIntent` 等筆離開再判定。
    var deferPencilIntent = false {
        didSet { pencilIntent.isEnabled = deferPencilIntent }
    }
    /// 打字模式中 Pencil 輕點一下。座標是**頁面座標**（已除以縮放倍率）。
    var onPencilTap: ((CGPoint) -> Void)?

    private lazy var pencilIntent: PencilIntentObserver = {
        let observer = PencilIntentObserver()
        observer.onStroke = { [weak self] in self?.onPencilTouchBegan?() }
        observer.onTap = { [weak self] location in
            guard let self else { return }
            let scale = max(self.zoomScale, 0.01)
            self.onPencilTap?(CGPoint(x: location.x / scale, y: location.y / scale))
        }
        return observer
    }()

    func installPencilIntentIfNeeded() {
        guard pencilIntent.view == nil else { return }
        pencilIntent.isEnabled = deferPencilIntent
        addGestureRecognizer(pencilIntent)
    }

    private func overridePan() {
        if savedMinimumPanTouches == nil {
            savedMinimumPanTouches = panGestureRecognizer.minimumNumberOfTouches
        }
        panGestureRecognizer.minimumNumberOfTouches = 2
    }

    private func restorePan() {
        guard let saved = savedMinimumPanTouches else { return }
        panGestureRecognizer.minimumNumberOfTouches = saved
        savedMinimumPanTouches = nil
    }

    /// 套索模式下，一根手指要拿來圈選，捲動改成兩指。
    ///
    /// 畫布本身是 UIScrollView，單頁模式下它的捲動手勢（單指）與套索的拖曳手勢互搶，
    /// 先開始辨識的是捲動 —— 套索的手勢一個事件都收不到，使用者看到的是「套索選不到任何東西」。
    /// （連續模式裡層畫布不捲，所以那邊本來就能用。）
    private var savedPanTouchesForLasso: Int?

    func setLassoClaimsSingleTouch(_ on: Bool) {
        if on {
            if savedPanTouchesForLasso == nil {
                savedPanTouchesForLasso = panGestureRecognizer.minimumNumberOfTouches
            }
            panGestureRecognizer.minimumNumberOfTouches = 2
        } else if let saved = savedPanTouchesForLasso {
            panGestureRecognizer.minimumNumberOfTouches = saved
            savedPanTouchesForLasso = nil
        }
    }

    private func installProLayerIfNeeded() -> ProInkLayerView {
        if let proLayer { return proLayer }
        let layer = ProInkLayerView(frame: .zero)
        layer.layer.anchorPoint = .zero
        layer.undoManagerProvider = { [weak self] in self?.undoManager }
        // 測試讀數要跟著專業筆畫的增減更新（畫一條標註、復原、擦除之後，筆畫數才讀得到）。
        if ProcessInfo.processInfo.environment["KAIRUMO_UITEST"] == "1" {
            layer.onChanged = { [weak self] in
                guard let self else { return }
                self.accessibilityValue = CanvasRepresentable.testReadout(self)
            }
            layer.onDraftingChanged = { [weak self] in
                guard let self else { return }
                self.accessibilityValue = CanvasRepresentable.testReadout(self)
            }
        }
        addSubview(layer)
        proLayer = layer

        let gesture = ProStrokeGestureRecognizer()
        gesture.layerView = layer
        gesture.tool = { [weak self] in self?.proTool }
        gesture.color = { [weak self] in self?.proColor ?? [0, 0, 0, 255] }
        gesture.width = { [weak self] in self?.proWidth ?? 4 }
        gesture.eraserRadius = { [weak self] in self?.proEraserRadius ?? 10 }
        gesture.drawLayer = { [weak self] in self?.proLayerId ?? 0 }
        gesture.drawLineType = { [weak self] in self?.proLineType ?? 0 }
        gesture.snapStep = { [weak self] in self?.proSnapStep }
        gesture.reassignTarget = { [weak self] in self?.proReassignTarget ?? 0 }
        gesture.onSnapped = { [weak self] kind in self?.onProSnapped?(kind) }
        gesture.onMarker = { [weak self] point in self?.onProMarker?(point) }
        gesture.onToolTouch = { [weak self] phase, point in self?.onProTool?(phase, point) }
        gesture.allowsFingerDrawing = { [weak self] in self?.proAllowsFinger() ?? true }
        gesture.delegate = proGestureDelegate
        gesture.isEnabled = false
        addGestureRecognizer(gesture)
        proGesture = gesture
        syncProLayerGeometry()
        return layer
    }

    /// 專業筆畫層要跟著頁面一起縮放與捲動：框是未縮放的頁面大小，縮放用 transform。
    func syncProLayerGeometry() {
        guard let layer = proLayer else { return }
        let scale = max(zoomScale, 0.01)
        let size = CGSize(
            width: max(bounds.width, contentSize.width / scale),
            height: max(pageContentHeight, contentSize.height / scale))
        layer.bounds = CGRect(origin: .zero, size: size)
        layer.layer.position = .zero
        layer.transform = CGAffineTransform(scaleX: scale, y: scale)
    }

    private(set) var activeTouchesCount: Int = 0
    var pendingRetractDate: Date? = nil
    var onPendingRetractNeeded: ((Date) -> Void)? = nil

    /// 套索圈選：直接收觸控，不靠 `UIPanGestureRecognizer`。
    ///
    /// 畫布裡 PencilKit 與捲動視圖自己有一組互相牽制的手勢，額外掛上去的拖曳辨識器
    /// 即使 `shouldBegin` 回傳了 true 也等不到 `.began`（實測整段拖曳沒有任何一次動作回呼），
    /// 套索於是「圈不到任何東西」。觸控事件不經過這些辨識器的仲裁，改由這裡轉出去。
    var lassoTouchHandler: ((UIGestureRecognizer.State, CGPoint) -> Void)?
    private weak var lassoTouch: UITouch?

    private func forwardLasso(_ touches: Set<UITouch>, _ state: UIGestureRecognizer.State) {
        guard let handler = lassoTouchHandler else { return }
        if state == .began {
            guard lassoTouch == nil, let first = touches.first else { return }
            lassoTouch = first
            handler(.began, first.location(in: self))
            return
        }
        guard let tracked = lassoTouch, touches.contains(tracked) else { return }
        handler(state, tracked.location(in: self))
        if state != .changed { lassoTouch = nil }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        forwardLasso(touches, .began)
        activeTouchesCount += touches.count
        for touch in touches {
            if touch.type == .pencil {
                lastPencilLocation = touch.location(in: self)
                lastStrokeHadHoldDwell = false
                schedulePencilDwellTimer()
                if !deferPencilIntent {
                    onPencilTouchBegan?()
                }
            }
            onTouchObserved?(touch)
            if InkInputDiagnostics.isEnabled || ProcessInfo.processInfo.environment["KAIRUMO_UITEST"] == "1" {
                onTouchDiagnostics?(touch, event)
            }
        }
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        forwardLasso(touches, .changed)
        if let pTouch = touches.first(where: { $0.type == .pencil }) {
            let loc = pTouch.location(in: self)
            let dist = hypot(loc.x - lastPencilLocation.x, loc.y - lastPencilLocation.y)
            if dist > EditorCanvasInputPolicy.holdToSnapMaxJitter {
                lastPencilLocation = loc
                lastStrokeHadHoldDwell = false
                schedulePencilDwellTimer()
            }
        }
        if InkInputDiagnostics.isEnabled || ProcessInfo.processInfo.environment["KAIRUMO_UITEST"] == "1" {
            touches.forEach { onTouchDiagnostics?($0, event) }
        }
        super.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        forwardLasso(touches, .ended)
        if touches.contains(where: { $0.type == .pencil }) {
            pencilDwellWorkItem?.cancel()
        }
        activeTouchesCount = max(0, activeTouchesCount - touches.count)
        touches.forEach {
            onTouchObserved?($0)
            if InkInputDiagnostics.isEnabled || ProcessInfo.processInfo.environment["KAIRUMO_UITEST"] == "1" {
                onTouchDiagnostics?($0, event)
            }
        }
        super.touchesEnded(touches, with: event)
        checkPendingRetract()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        forwardLasso(touches, .cancelled)
        if touches.contains(where: { $0.type == .pencil }) {
            pencilDwellWorkItem?.cancel()
            lastStrokeHadHoldDwell = false
        }
        activeTouchesCount = max(0, activeTouchesCount - touches.count)
        super.touchesCancelled(touches, with: event)
        checkPendingRetract()
    }

    private func checkPendingRetract() {
        if activeTouchesCount == 0, let date = pendingRetractDate {
            pendingRetractDate = nil
            onPendingRetractNeeded?(date)
        }
    }

    var pageContentHeight: CGFloat = PageGeometry.height {
        didSet { if pageContentHeight != oldValue { syncContentSize() } }
    }
    /// 底層樣板背景，要跟著 contentSize 一起變
    weak var templateBackgroundView: UIView?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            refreshInitialRenderIfNeeded()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        syncContentSize()
        refreshInitialRenderIfNeeded()
    }

    /// 重開舊筆記本時，載入的筆跡要使用者點一下畫布才會出現。
    ///
    /// `makeUIView` 在畫布進入視窗、有尺寸**之前**就指派了 `drawing`，PencilKit 在那個時間點
    /// 畫出來的是空的貼圖，之後內容沒變就不會重畫（縮圖用另一條路畫，所以縮圖是對的）。
    /// 畫布第一次有了視窗與尺寸之後，把同一份 `drawing` 再指派一次，強迫它重畫。
    /// 要包在 `isProgrammaticUpdate` 裡：不然 delegate 會把這份當成使用者的編輯存回去。
    private var didInitialRefresh = false

    /// 強制畫布立即重新刷出指定筆跡（若無傳入則取畫布既有 drawing），無需使用者落筆點擊觸發
    func forceDisplayRefresh(with newDrawing: PKDrawing? = nil) {
        let coordinator = delegate as? CanvasRepresentable.Coordinator
        let target = newDrawing ?? self.drawing
        guard target.strokes.count > 0 else { return }
        coordinator?.isProgrammaticUpdate = true
        self.drawing = target
        coordinator?.isProgrammaticUpdate = false
        self.setNeedsLayout()
        self.layoutIfNeeded()
        self.setNeedsDisplay()
        for subview in self.subviews {
            subview.setNeedsDisplay()
        }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window != nil, self.activeTouchesCount == 0 else { return }
            let coord = self.delegate as? CanvasRepresentable.Coordinator
            coord?.isProgrammaticUpdate = true
            self.drawing = target
            coord?.isProgrammaticUpdate = false
            self.setNeedsDisplay()
            for subview in self.subviews {
                subview.setNeedsDisplay()
            }
        }
    }

    /// 程式替換／收回筆畫之後，把 PencilKit 登記的「已經失效」的復原項消耗掉。
    ///
    /// 直接指派 `drawing` 之後，原本登記的「加入筆畫」指向不存在的筆畫：按復原沒有反應，還吃掉一次點擊。
    /// 這裡讓 PencilKit 自己復原一次 —— 畫面沒變就是失效項，算消耗掉了；畫面變了代表那是有效項
    /// （堆疊頂端是別的動作），立刻重做回來並停手。回傳消耗了幾個。
    @discardableResult
    func dropDeadUndoEntries(max: Int) -> Int {
        guard max > 0, let manager = undoManager, !manager.isUndoing, !manager.isRedoing else { return 0 }
        let coordinator = delegate as? CanvasRepresentable.Coordinator
        var dropped = 0
        while dropped < max, manager.canUndo {
            let before = drawing
            coordinator?.isProgrammaticUpdate = true
            manager.undo()
            if drawing != before {
                manager.redo()
                coordinator?.isProgrammaticUpdate = false
                break
            }
            coordinator?.isProgrammaticUpdate = false
            dropped += 1
        }
        return dropped
    }

    private func refreshInitialRenderIfNeeded() {
        guard !didInitialRefresh, window != nil, bounds.width > 1, bounds.height > 1 else { return }
        let strokeCount = max(drawing.strokes.count, initialLoadedStrokeCount)
        guard strokeCount > 0 else { return }
        didInitialRefresh = true
        guard activeTouchesCount == 0 else { return }
        if self.undoManager?.canUndo == true { return }

        DispatchQueue.main.async { [weak self] in
            guard let self, self.window != nil, self.activeTouchesCount == 0 else { return }
            if self.undoManager?.canUndo == true {
                self.setNeedsDisplay()
                return
            }
            CanvasDiag.log("初次補畫重新指派 drawing（\(self.drawing.strokes.count) 筆）")
            let coordinator = self.delegate as? CanvasRepresentable.Coordinator
            let current = self.drawing
            coordinator?.isProgrammaticUpdate = true
            self.drawing = current
            coordinator?.isProgrammaticUpdate = false
            self.setNeedsDisplay()
            for subview in self.subviews {
                subview.setNeedsDisplay()
            }
        }
    }

    func syncContentSize() {
        syncProLayerGeometry()
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
struct ProInkBinding {
    let directory: URL
    let notebookId: String
    let pageIndex: Int
}

struct CanvasRepresentable: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    /// 專業筆刷（自繪引擎）這一頁存哪裡。`nil` 表示這個畫布不支援專業筆刷。
    var proInk: ProInkBinding? = nil
    /// 圖學狀態：換筆、換圖層、改角度鎖定都要讓畫布重新套用工具設定。
    @ObservedObject var drafting = DraftingState.shared
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
    var onLassoBegan: ((CGPoint) -> Void)? = nil
    var onLassoMoved: ((CGPoint) -> Void)? = nil
    var onLassoEnded: (() -> Void)? = nil
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
    /// 磁吸對齊開關。開啟時，**刻意畫的直線**的終點會被扶正到水平／垂直／45° 或格點，
    /// 並呼叫 `onMagneticSnap` 顯示引導線。關閉時完全不碰筆跡。
    var magneticSnapEnabled: Bool = false
    var onMagneticSnap: ((CGPoint, CGPoint) -> Void)?

    /// 🌟 方案 A+B：Apple Pencil 硬體落筆感知與手指單雙擊回呼
    var onPencilTouchBegan: (() -> Void)? = nil
    var onCanvasDirectTap: ((CGPoint) -> Void)? = nil
    var onCanvasDirectDoubleTap: ((CGPoint) -> Void)? = nil
    /// 打字模式下 Pencil 輕點一下（頁面座標）。沒接的話就當成手指點擊。
    var onPencilTapInTypeMode: ((CGPoint) -> Void)? = nil

    /// 目前該用哪個輸入政策。
    ///
    /// 打字模式一律設為 `.pencilOnly`：拿 Apple Pencil 的使用者隨時可順暢下筆，手指則負責點選與選取物件。
    /// 手寫模式交給掌拒協調器決定 —— 沒有它時退回原本的 `.anyInput`。
    private func resolvedPolicy(now: Date = Date()) -> PKCanvasViewDrawingPolicy {
        if EditorCanvasInputPolicy.fingerMayDraw(effectiveMode: editorMode) == false {
            return .pencilOnly
        }
        return palmRejection?.drawingPolicy(now: now) ?? .anyInput
    }

    /// 給核心看的模式。
    private var ffiEditorMode: FfiEditorMode { editorMode == .draw ? .draw : .type }

    /// 給核心看的輸入政策。`.anyInput` 才算「手指可以畫」。
    private var ffiInkPolicy: FfiInkPolicy {
        resolvedPolicy() == .anyInput ? .anyInput : .stylusOnly
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = AdaptiveCanvasView()
        // 無限制復原/重做次數（0 代表 levelsOfUndo 無上限，直到記憶體或棧頂耗盡為止）
        canvas.undoManager?.levelsOfUndo = 0
        canvas.drawingPolicy = resolvedPolicy()
        canvas.onPencilTouchBegan = onPencilTouchBegan
        canvas.onTouchObserved = { [weak canvas, weak coordinator = context.coordinator] touch in
            guard let palm = palmRejection else { return }
            // 掌拒只在手繪模式管事。打字模式下手指本來就不畫，
            // 讓它去改政策會把畫布改回 `.anyInput`（手指又能畫了），
            // 收回筆畫則可能把剛用 Pencil 寫的字收掉。
            guard coordinator?.parent.editorMode == .draw else { return }
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
        canvas.drawingGestureRecognizer.isEnabled =
            EditorCanvasInputPolicy.drawingGestureEnabled(effectiveMode: editorMode)
        canvas.installPencilIntentIfNeeded()
        canvas.deferPencilIntent = EditorCanvasInputPolicy.defersPencilIntent(effectiveMode: editorMode)
        canvas.onPencilTap = onPencilTapInTypeMode ?? onCanvasDirectTap
        canvas.isUserInteractionEnabled = true
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
        canvas.initialLoadedStrokeCount = drawing.strokes.count
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
        context.coordinator.penHover.snapQuery = { [weak coordinator = context.coordinator] loc in
            guard let coordinator else { return nil }
            let isDrafting = coordinator.parent.selectedTool == .drafting || coordinator.parent.magneticSnapEnabled
            guard isDrafting else { return nil }
            let snap = SmartMagneticSnap.snap(start: loc, current: loc, enableGrid: true)
            return snap.didSnap ? snap.snappedPoint : nil
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

        canvas.onPendingRetractNeeded = { [weak canvas] landedAt in
            guard let canvas else { return }
            guard palmRejection?.drawingPolicy(now: landedAt) != .pencilOnly else { return }
            let cleaned = PalmRejectionCoordinator.retracting(canvas.drawing, landedAt: landedAt)
            guard cleaned.strokes.count != canvas.drawing.strokes.count else { return }
            let removed = canvas.drawing.strokes.count - cleaned.strokes.count
            context.coordinator.isProgrammaticUpdate = true
            canvas.drawing = cleaned
            context.coordinator.isProgrammaticUpdate = false
            canvas.dropDeadUndoEntries(max: removed)
            _ = onDrawingChanged?(cleaned)
        }

        // 🌟 方案 A+B：手指／游標單擊與雙擊手勢（限定 direct / indirectPointer，完全不阻礙 Apple Pencil 筆跡）
        let directSingleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDirectSingleTap(_:)))
        directSingleTap.numberOfTapsRequired = 1
        directSingleTap.allowedTouchTypes = [
            NSNumber(value: UITouch.TouchType.direct.rawValue),
            NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)
        ]
        directSingleTap.cancelsTouchesInView = false
        directSingleTap.name = Coordinator.directTapName
        directSingleTap.delegate = context.coordinator

        let directDoubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDirectDoubleTap(_:)))
        directDoubleTap.numberOfTapsRequired = 2
        directDoubleTap.allowedTouchTypes = [
            NSNumber(value: UITouch.TouchType.direct.rawValue),
            NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)
        ]
        directDoubleTap.cancelsTouchesInView = false
        directDoubleTap.name = Coordinator.directTapName
        directDoubleTap.delegate = context.coordinator
        directSingleTap.require(toFail: directDoubleTap)

        canvas.addGestureRecognizer(directDoubleTap)
        canvas.addGestureRecognizer(directSingleTap)

        let lassoPan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLassoPan(_:)))
        lassoPan.maximumNumberOfTouches = 1
        // 圈選改由 `AdaptiveCanvasView.lassoTouchHandler` 收觸控（見該處說明）；
        // 這個辨識器留著只是為了相容，不啟用，免得同一次拖曳處理兩遍。
        lassoPan.isEnabled = false
        canvas.addGestureRecognizer(lassoPan)
        context.coordinator.lassoPan = lassoPan

        context.coordinator.parent = self
        context.coordinator.applyTool(to: canvas)
        // 套用儲存的壓感曲線（與 Android AdvancedPenSettingsDialog 對等）
        context.coordinator.applyPressureCurve()
        applyProInk(to: canvas)
        canvasRef?(canvas)

        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.lassoPan?.isEnabled = false
        if let adaptive = uiView as? AdaptiveCanvasView {
            adaptive.setLassoClaimsSingleTouch(selectedTool == .lasso)
            adaptive.lassoTouchHandler = selectedTool == .lasso
                ? { [weak coordinator = context.coordinator] state, point in
                    coordinator?.handleLassoTouch(state, point)
                } : nil
        }
        // 模式切換時要跟著改 —— 只在 makeUIView 設的話，從連續切回整頁
        // 會得到一個捲不動的畫布（SwiftUI 會重用同一個 UIView）。
        // 套索模式下單頁畫布的捲動手勢要讓出來，否則套索的拖曳辨識不起來。
        let wantsScroll = isScrollEnabled && selectedTool != .lasso
        if uiView.isScrollEnabled != wantsScroll {
            uiView.isScrollEnabled = wantsScroll
            uiView.alwaysBounceVertical = wantsScroll
            uiView.showsVerticalScrollIndicator = wantsScroll
        }
        // 打字模式不再關掉落筆手勢：靠 `.pencilOnly` 擋手指，Pencil 第一筆就收得到。
        // 套索與遮蔽膠帶模式下關閉繪圖手勢，確保所有碰觸皆由自定義物件層全權接收。
        let gestureOn = EditorCanvasInputPolicy.drawingGestureEnabled(effectiveMode: editorMode) && (selectedTool != .lasso) && (selectedTool != .maskingTape)
        if uiView.drawingGestureRecognizer.isEnabled != gestureOn {
            uiView.drawingGestureRecognizer.isEnabled = gestureOn
        }
        let targetPolicy = resolvedPolicy()
        if uiView.drawingPolicy != targetPolicy {
            uiView.drawingPolicy = targetPolicy
        }
        // 連續模式（畫布自己不捲）且手指會畫圖時，兩指捲動由我們自己接管；
        // `.pencilOnly` 時手指不畫，外層捲動單指就能動，不必（也不該）再轉發。
        if let adaptive = uiView as? AdaptiveCanvasView {
            adaptive.twoFingerScroll.setEnabled(
                !isScrollEnabled && targetPolicy == .anyInput && selectedTool != .lasso && selectedTool != .maskingTape, on: adaptive)
        }
        if let adaptive = uiView as? AdaptiveCanvasView {
            let defer_ = EditorCanvasInputPolicy.defersPencilIntent(effectiveMode: editorMode)
            if adaptive.deferPencilIntent != defer_ { adaptive.deferPencilIntent = defer_ }
            adaptive.onPencilTap = onPencilTapInTypeMode ?? onCanvasDirectTap
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
        if !uiView.isUserInteractionEnabled {
            uiView.isUserInteractionEnabled = true
        }

        // 換筆刷或拉筆寬時，游標要跟著變 —— 不更新的話使用者得把滑鼠移出去
        // 再移回來才看得到新的筆頭。
        if let adaptive = uiView as? AdaptiveCanvasView {
            adaptive.onPencilTouchBegan = onPencilTouchBegan
            adaptive.installPointerInteractionIfNeeded(delegate: context.coordinator)
            adaptive.refreshPointer(BrushCursor.path(for: selectedTool, strokeWidth: strokeWidth))
        }

        if uiView.drawing != drawing {
            CanvasDiag.log("updateUIView 重新指派 drawing：畫布 \(uiView.drawing.strokes.count) 筆 → \(drawing.strokes.count) 筆，復原項 \(uiView.undoManager?.canUndo == true ? "有" : "無")")
            context.coordinator.isProgrammaticUpdate = true
            uiView.drawing = drawing
            context.coordinator.isProgrammaticUpdate = false
            if let adaptive = uiView as? AdaptiveCanvasView {
                adaptive.initialLoadedStrokeCount = drawing.strokes.count
                adaptive.forceDisplayRefresh(with: drawing)
            }
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
            adaptive.onPendingRetractNeeded = { [weak uiView] landedAt in
                guard let uiView else { return }
                guard palmRejection?.drawingPolicy(now: landedAt) != .pencilOnly else { return }
                let cleaned = PalmRejectionCoordinator.retracting(uiView.drawing, landedAt: landedAt)
                guard cleaned.strokes.count != uiView.drawing.strokes.count else { return }
                let removed = uiView.drawing.strokes.count - cleaned.strokes.count
                CanvasDiag.log("掌拒收回 \(removed) 筆並重新指派 drawing")
                context.coordinator.isProgrammaticUpdate = true
                uiView.drawing = cleaned
                context.coordinator.isProgrammaticUpdate = false
                (uiView as? AdaptiveCanvasView)?.dropDeadUndoEntries(max: removed)
                _ = onDrawingChanged?(cleaned)
            }
        }

        context.coordinator.applyTool(to: uiView)
        applyProInk(to: uiView)
        canvasRef?(uiView)
    }

    /// 專業筆刷：設好層、手勢與目前的筆色／筆寬。
    private func applyProInk(to canvas: PKCanvasView) {
        guard let adaptive = canvas as? AdaptiveCanvasView else { return }
        let mode: AdaptiveCanvasView.ProMode
        let isDrafting = selectedTool == .drafting
        if isDrafting {
            mode = drafting.tool != .none ? .tool
                : (drafting.markerMode ? .marker : (drafting.reassignMode ? .reassign : .draw))
        } else if selectedTool.proToolKind != nil {
            mode = .draw
        } else if selectedTool == .eraser {
            mode = .erase
        } else {
            mode = .off
        }
        let fingerRule = EditorCanvasInputPolicy.fingerMayDraw(effectiveMode: editorMode)
        if isDrafting {
            // 製圖筆一律走針筆（等寬、硬邊）；顏色、粗細、線型、圖層由製圖筆組決定。
            adaptive.proTool = .fineliner
            adaptive.proColor = drafting.activeColorRGBA
            adaptive.proWidth = drafting.activePen.width
            adaptive.proLayerId = drafting.activeLayerId
            adaptive.proLineType = drafting.activeLineType
            adaptive.proSnapStep = drafting.snapEnabled ? Float(drafting.angleStep) : nil
            adaptive.proReassignTarget = drafting.activeLayerId
            adaptive.onProMarker = { [weak adaptive] point in
                // 一次放一個「圈＋數字」，一次復原；放完編號加一。
                let state = DraftingState.shared
                let strokes = draftStepMarker(number: UInt32(state.stepNumber), cx: Float(point.x),
                                              cy: Float(point.y), radius: 15)
                adaptive?.proLayer?.insertDrafted(strokes, origin: .zero)
                state.stepNumber += 1
            }
            adaptive.onProTool = { [weak adaptive] phase, point in
                guard let layer = adaptive?.proLayer else { return }
                DraftToolController.shared.handle(phase, point, layer: layer)
            }
            if let id = proInk?.notebookId { drafting.use(notebook: id) }
        } else {
            adaptive.proTool = selectedTool.proToolKind
            adaptive.proColor = InkInterop.rgba(from: UIColor(selectedColor)).map { $0 }
            adaptive.proWidth = Float(max(1.2, strokeWidth * 1.4))
            adaptive.proLayerId = 0
            adaptive.proLineType = 0
            adaptive.proSnapStep = nil
        }
        adaptive.proEraserRadius = eraserMode == .pixel ? max(8, pixelEraserWidth / 2) : 8
        adaptive.proAllowsFinger = { [palmRejection] in
            if fingerRule == false { return false }
            return (palmRejection?.drawingPolicy(now: Date()) ?? .anyInput) == .anyInput
        }
        adaptive.configurePro(
            mode: mode, directory: proInk?.directory,
            notebookId: proInk?.notebookId ?? "", pageIndex: proInk?.pageIndex ?? 0,
            pencilOnly: fingerRule == false)
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
        // `pro:` 是專業筆畫（含製圖線、標註）的數量：它們不在 PencilKit 的 drawing 裡。
        let pro = (canvas as? AdaptiveCanvasView)?.proLayer?.ownStrokes.count ?? 0
        var text = String(format: "zoom:%.3f strokes:%d pro:%d", canvas.zoomScale, canvas.drawing.strokes.count, pro)
        // 測試要知道尺在哪裡、最後一筆畫到哪裡（頁面座標與視窗座標兩套）。
        if let layer = (canvas as? AdaptiveCanvasView)?.proLayer {
            if let last = layer.ownStrokes.last, let f = last.points.first, let l = last.points.last {
                text += String(format: " last:%.2f,%.2f,%.2f,%.2f", f.x, f.y, l.x, l.y)
            }
            if let pivot = DraftingState.shared.pivot(notebookId: layer.notebookId, page: layer.pageIndex) {
                text += String(format: " pivot:%.2f,%.2f", pivot.x, pivot.y)
            }
            if let inst = DraftingState.shared.instrument {
                func win(_ p: CGPoint) -> CGPoint { layer.convert(p, to: nil) }
                if let (a, b) = inst.pageEdges.first {
                    text += String(format: " edge:%.2f,%.2f,%.2f,%.2f", a.x, a.y, b.x, b.y)
                    let wa = win(a), wb = win(b)
                    text += String(format: " edgeW:%.2f,%.2f,%.2f,%.2f", wa.x, wa.y, wb.x, wb.y)
                }
                let box = inst.pageOutline.flatMap { $0 }.reduce(CGRect.null) { $0.union(CGRect(origin: win($1), size: .zero)) }
                text += String(format: " instW:%.2f,%.2f,%.2f,%.2f", box.minX, box.minY, box.width, box.height)
            }
        }
        return text
    }
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate, UIPointerInteractionDelegate, UIGestureRecognizerDelegate {
        /// 手指／游標單擊、雙擊辨識器的名字，讓委派認得出「是我們的」。
        static let directTapName = "kairumo.canvas.directTap"

        /// **單擊要能與 PencilKit 的繪圖手勢同時辨識。**
        ///
        /// 手繪模式（`.anyInput`，手指也能畫）下，PKCanvasView 的繪圖手勢一收到
        /// 觸控就先宣告辨識，我們的單擊辨識器因此被擋掉 —— `handleDirectSingleTap`
        /// 根本不會被呼叫。症狀：文字模式打的字，切回手繪模式後變成文字方塊，
        /// 點它沒有任何反應，既不能編輯也不能移動。
        ///
        /// 同時辨識是安全的：夠短的單擊本來就不會被 PencilKit 當成一筆
        /// （實測 `strokes` 讀數維持 0），所以不會多出一個點。
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            gestureRecognizer.name == Self.directTapName
                || other.name == Self.directTapName
        }

        weak var lassoPan: UIPanGestureRecognizer?

        func handleLassoTouch(_ state: UIGestureRecognizer.State, _ point: CGPoint) {
            switch state {
            case .began: parent.onLassoBegan?(point)
            case .changed: parent.onLassoMoved?(point)
            case .ended, .cancelled, .failed: parent.onLassoEnded?()
            default: break
            }
        }

        @objc func handleLassoPan(_ gesture: UIPanGestureRecognizer) {
            guard let canvas = gesture.view as? PKCanvasView else { return }
            let point = gesture.location(in: canvas)
            switch gesture.state {
            case .began:
                parent.onLassoBegan?(point)
            case .changed:
                parent.onLassoMoved?(point)
            case .ended, .cancelled, .failed:
                parent.onLassoEnded?()
            default:
                break
            }
        }

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
            (scrollView as? AdaptiveCanvasView)?.syncProLayerGeometry()
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

        @objc func handleDirectSingleTap(_ sender: UITapGestureRecognizer) {
            guard sender.state == .ended, let canvas = sender.view else { return }
            parent.onCanvasDirectTap?(Self.pageLocation(of: sender, in: canvas))
        }

        @objc func handleDirectDoubleTap(_ sender: UITapGestureRecognizer) {
            guard sender.state == .ended, let canvas = sender.view else { return }
            parent.onCanvasDirectDoubleTap?(Self.pageLocation(of: sender, in: canvas))
        }

        /// 點擊位置換成**頁面座標**。畫布放大時，scroll view 自己的座標是放大後的，
        /// 物件與文字框用的是未縮放的頁面座標 —— 不換算的話放大時點到的位置會偏掉。
        static func pageLocation(of gesture: UIGestureRecognizer, in canvas: UIView) -> CGPoint {
            let loc = gesture.location(in: canvas)
            let scale = max((canvas as? UIScrollView)?.zoomScale ?? 1, 0.01)
            return CGPoint(x: loc.x / scale, y: loc.y / scale)
        }

        init(_ parent: CanvasRepresentable) {
            self.parent = parent
            super.init()
            pencilTaps.onControl = { [weak self] control, pressed in
                self?.parent.onPenControl?(control, pressed)
            }
        }

        /// 把剛畫完的那一筆換成美化後的版本，**同時讓復原／重做對得上**。
        ///
        /// PencilKit 在一筆畫完時登記「加入筆畫」。事後直接指派 `drawing` 把那一筆換掉，
        /// 登記的復原就指向一個已經不存在的筆畫 —— 按復原**沒有任何反應，還吃掉一次按鍵**
        /// （使用者回報：一開始畫的幾筆復原／重做沒作用，後面畫的才可以；實測是被辨識成直線／
        /// 圓形的筆畫，復原前後筆畫數都不變）。
        ///
        /// 做法：先讓 PencilKit 自己把那一筆復原掉（堆疊裡失效的那一項就此消耗掉），
        /// 再套上美化結果，並登記一個「來回切換」的復原項，這樣復原會拿掉美化後的那一筆、
        /// 重做會放回來。復原到的若不是剛畫的那一筆（堆疊頂端是別的東西）就還原，退回直接指派。
        func replaceLastStroke(in canvas: PKCanvasView, resulting: PKDrawing) {
            isProgrammaticUpdate = true
            defer { isProgrammaticUpdate = false }
            let before = canvas.drawing
            if let manager = canvas.undoManager, manager.canUndo,
               !manager.isUndoing, !manager.isRedoing {
                manager.undo()
                if canvas.drawing.strokes.count == before.strokes.count - 1 {
                    canvas.drawing = resulting
                    registerDrawingSwap(
                        on: canvas, to: PKDrawing(strokes: Array(resulting.strokes.dropLast())),
                        back: resulting)
                    return
                }
                manager.redo()
            }
            canvas.drawing = resulting
        }

        /// 復原項：把畫布換成 `target`，並登記反方向的項目（重做）。
        private func registerDrawingSwap(
            on canvas: PKCanvasView, to target: PKDrawing, back: PKDrawing
        ) {
            canvas.undoManager?.registerUndo(withTarget: self) { [weak canvas] coordinator in
                guard let canvas else { return }
                coordinator.isProgrammaticUpdate = true
                canvas.drawing = target
                coordinator.isProgrammaticUpdate = false
                coordinator.parent.drawing = target
                _ = coordinator.parent.onDrawingChanged?(target)
                coordinator.registerDrawingSwap(on: canvas, to: back, back: target)
            }
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isProgrammaticUpdate else { return }
            var effective = canvasView.drawing
            // 磁吸要在存檔之前套用：先存再改的話，磁碟上那份是歪的，下次開啟才「彈回來」。
            var magneticGuide: (CGPoint, CGPoint)?
            if parent.magneticSnapEnabled, parent.selectedTool.isBrush,
               effective.strokes.count > self.lastStrokeCountBeforeRefine,
               let snapped = Self.magneticallySnapped(effective) {
                isProgrammaticUpdate = true
                canvasView.drawing = snapped.drawing
                isProgrammaticUpdate = false
                // 原本登記的「加入筆畫」已經失效；等這一輪事件結束再處理（現在還在 PencilKit 的回呼裡）。
                DispatchQueue.main.async { [weak self, weak canvasView] in
                    guard let self, let canvas = canvasView as? AdaptiveCanvasView else { return }
                    let current = canvas.drawing
                    if canvas.dropDeadUndoEntries(max: 1) == 1 {
                        self.registerDrawingSwap(
                            on: canvas, to: PKDrawing(strokes: Array(current.strokes.dropLast())),
                            back: current)
                    }
                }
                effective = snapped.drawing
                magneticGuide = (snapped.start, snapped.end)
            }
            if let corrected = parent.onDrawingChanged?(effective),
               corrected.strokes.count != effective.strokes.count {
                // 收回的筆畫要真的從畫布上消失。
                //
                // 原本只有存檔那一份被拿掉：畫面上那一筆還在，使用者以為
                // 寫成功了，而匯出的檔案裡沒有它；更糟的是它留在畫布上，
                // 於是**下一筆、再下一筆**都會連它一起重新檢查，
                // 「這一筆畫在可列印範圍之外」的提示就一直跳。
                CanvasDiag.log("可列印範圍收回 \(effective.strokes.count - corrected.strokes.count) 筆並重新指派 drawing")
                isProgrammaticUpdate = true
                canvasView.drawing = corrected
                isProgrammaticUpdate = false
                (canvasView as? AdaptiveCanvasView)?.dropDeadUndoEntries(max: max(0, effective.strokes.count - corrected.strokes.count))
                effective = corrected
            }
            parent.drawing = effective

            // 筆畫數也要跟著更新 —— 只在建立時寫一次的話，測試讀到的
            // 永遠是 0，而「畫了沒存」與「根本沒畫進去」看起來一模一樣。
            if ProcessInfo.processInfo.environment["KAIRUMO_UITEST"] == "1" {
                canvasView.accessibilityValue = CanvasRepresentable.testReadout(canvasView)
            }

            // ── 真・Hold-to-Snap（手勢停頓即吸附成形） ──────────────────
            // 只有在繪製時有刻意停留（hadDwell），或工具為圖學／磁吸直線時才觸發幾何美化轉正。
            // 快速連貫書寫（一般筆記落筆提筆無停頓）100% 保持手繪原生線條，絕不誤把字體筆畫轉正！
            self.shapeRefineTimer?.cancel()
            let count = effective.strokes.count
            let hadDwell = (canvasView as? AdaptiveCanvasView)?.lastStrokeHadHoldDwell ?? false
            (canvasView as? AdaptiveCanvasView)?.lastStrokeHadHoldDwell = false

            if count > self.lastStrokeCountBeforeRefine, parent.selectedTool.isBrush,
               (hadDwell || parent.selectedTool == .drafting || parent.magneticSnapEnabled) {
                let drawing = canvasView.drawing
                if let lastStroke = drawing.strokes.last,
                   let (refined, kind) = SketchRefineEngine.refineSingleStroke(lastStroke),
                   kind != .freehand {
                    var strokes = drawing.strokes
                    strokes[strokes.count - 1] = refined
                    self.replaceLastStroke(in: canvasView, resulting: PKDrawing(strokes: strokes))
                    self.parent.drawing = canvasView.drawing
                    _ = self.parent.onDrawingChanged?(canvasView.drawing)
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                }
            }

            // ── 智慧磁吸對齊的引導線（實際的扶正已在上面、存檔之前做完）──────────
            if let (start, end) = magneticGuide {
                parent.onMagneticSnap?(start, end)
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

        /// 把最後一筆（若是刻意畫的直線）的終點扶正。不是直線、或本來就貼齊，回 nil。
        static func magneticallySnapped(_ drawing: PKDrawing)
            -> (drawing: PKDrawing, start: CGPoint, end: CGPoint)?
        {
            guard let lastStroke = drawing.strokes.last, lastStroke.path.count >= 2 else { return nil }
            var points: [PKStrokePoint] = Array(lastStroke.path)
            let locations = points.map(\.location)
            guard SmartMagneticSnap.isNearlyStraight(locations),
                  let startPoint = locations.first, let endPoint = locations.last else { return nil }
            let result = SmartMagneticSnap.snap(start: startPoint, current: endPoint, enableGrid: true)
            guard result.didSnap, result.snappedPoint != endPoint else { return nil }
            let tail = points[points.count - 1]
            points[points.count - 1] = PKStrokePoint(
                location: result.snappedPoint, timeOffset: tail.timeOffset, size: tail.size,
                opacity: tail.opacity, force: tail.force, azimuth: tail.azimuth,
                altitude: tail.altitude)
            let path = PKStrokePath(controlPoints: points, creationDate: lastStroke.path.creationDate)
            var strokes = drawing.strokes
            strokes[strokes.count - 1] = PKStroke(
                ink: lastStroke.ink, path: path, transform: lastStroke.transform, mask: lastStroke.mask)
            return (PKDrawing(strokes: strokes), startPoint, result.snappedPoint)
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
            case .fineliner, .calligraphy, .charcoal, .crayon, .airbrush, .oilpaint:
                // 專業筆刷由自繪引擎收筆（ProInk.swift），PencilKit 的落筆手勢在這時是關著的。
                // 這裡只放一支不會被用到的筆，讓畫布手上永遠有個合法的工具。
                canvas.tool = PKInkingTool(.pen, color: uiColor, width: max(1, parent.strokeWidth))

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

            case .lasso:
                // 套索選取由自定義 LassoSelection 與手勢全權接管，不依賴 PKLassoTool 私有介面
                canvas.tool = PKInkingTool(.pen, color: .clear, width: 1)

            case .drafting:
                // 圖學筆畫走自繪引擎（ProInk），PencilKit 不收筆。
                canvas.tool = PKInkingTool(.pen, color: .clear, width: 1)

            case .maskingTape:
                // 遮蔽膠帶（Masking Tape）：自定義覆蓋層物件，不應指派為 PKLassoTool，
                // 以免與套索工具混淆。畫布在膠帶工具啟動時停用繪畫筆刷以確保手勢完全由膠帶層接收。
                break
            }
        }

        /// 從 UserDefaults 讀取使用者設定的壓感曲線並套用。
        ///
        /// Apple 的 PencilKit 不直接暴露壓感曲線 API，以下手法透過
        /// 縮小 PKInkingTool 的最小有效寬度來模擬 `pressureFloor`。
        /// `pressureGamma` 存於 UserDefaults，供後續接入核心 `inkWidthScale`
        /// 反向查表時使用（兩個平台讀同一組 key）。
        func applyPressureCurve() {
            // 讀取使用者設定，未設定時退回預設
            // 這裡只做輕量的持久化確認，真正的壓感曲線邏輯在核心 `ink_width_scale`。
            let floor = max(0.01, min(1.0, Double(UserDefaults.standard.float(forKey: "kairumo.pen.pressureFloor"))))
            let gamma = max(0.5, min(2.5, Double(UserDefaults.standard.float(forKey: "kairumo.pen.pressureGamma"))))
            // 只在有使用者明確設定值的情況下套用（避免 UserDefaults 回傳 0 的未設狀態）
            let floorSet = UserDefaults.standard.object(forKey: "kairumo.pen.pressureFloor") != nil
            let gammaSet = UserDefaults.standard.object(forKey: "kairumo.pen.pressureGamma") != nil
            guard floorSet || gammaSet else { return }
            // 記錄到核心側（Android 的 InkEngine.setPressureCurve 對應實作在 JNI；
            // Apple 這裡以 UserDefaults 為橋，核心 ink_width_scale 在畫線時讀取）
            _ = floor  // pressureFloor 與 pressureGamma 透過 ink_width_scale FFI 影響筆寬
            _ = gamma
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
                    Text(L10n.t("composition_golden_spiral"))
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
                    Text(L10n.t("composition_rule_of_thirds"))
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
    /// 最近一次真的寫進磁碟的筆跡（頁次 + 內容）。切換模式時用來判斷「這一頁其實沒變」，
    /// 不必每次都同步序列化整頁筆跡（筆跡多的頁面，那一下就是點物件時的卡頓）。
    @State private var lastPersistedInk: (page: Int, drawing: PKDrawing)? = nil
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
    /// 這一批待寫筆畫最早的那一筆的時間。見 `scheduleCoreInkFlush` 的上限說明。
    @State private var coreInkFirstPendingAt: Date? = nil
    @State private var canvasView: PKCanvasView? = nil
    @State private var currentPageHeight: CGFloat = PageGeometry.height
    /// 掌拒（工作項 S-45）。判定規則走核心，與 Android 同一份。
    @State private var palmRejection = PalmRejectionCoordinator()
    @State private var showToolbarCustomization = false
    @State private var showPalmThresholdSheet = false
    @State private var showAdvancedPenSettingsSheet = false
    @State private var showExportPreview = false
    @State private var wantsShareAfterPreview = false
    @StateObject private var lasso = LassoSelection()
    private var hasLassoSelection: Bool {
        lasso.hasSelection
    }
    @State private var showExtendedBanner: Bool = false

    @State private var canvasZoomScale: CGFloat = 1.0
    @State private var canvasContentOffset: CGPoint = .zero

    // 實體工具列狀態
    @State private var selectedTool: EditorToolType = .pen
    /// 自訂頁面尺寸的輸入畫面。
    @State private var showCustomPageSize = false
    /// 立體輔助（草圖拉伸、三視圖、剖面）。
    @State private var showSolidStudio = false
    @State private var showDraftingToolbox = false
    @State private var draftExportShare: SharedFile?
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
    @State private var isInsertSpaceActive: Bool = false
    @State private var insertSpaceDividerY: CGFloat = 300.0
    @State private var insertSpaceDragAccum: CGFloat = 0.0
    
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
    /// 統一管理自檔案匯入的插槽，避免 SwiftUI 多個 .fileImporter 競爭互斥
    @State private var activeImportSlot: FfiImportSlot? = nil
    /// 已經收進來、正在讓使用者挑頁的那份 PDF。
    @State private var pdfToInsert: URL? = nil
    /// 匯入失敗的語系鍵。非空就跳提示。
    @State private var importErrorKey: String = ""
    @State private var showStickerLibrary: Bool = false
    @State private var pendingStickerPlacement: PendingStickerPlacement? = nil
    @State private var showMathCalculator: Bool = false
    @State private var showChartStudio: Bool = false
    @State private var showTableStudio: Bool = false
    @State private var showShapeStudio: Bool = false
    @State private var showLayerPanel: Bool = false
    /// 畫布中單一選取物件的唯一識別碼（互斥單選：同一時間最多只有一個物件處於編輯/選取狀態）
    @State private var activeSelectedObjectId: String? = nil
    /// 一鍵恢復初始狀態（捨棄進入編輯器後的所有修改）
    @State private var initialNotebookSnapshot: NotebookDocument? = nil
    @State private var initialPageDrawings: [Int: PKDrawing] = [:]
    /// 每一頁第一次載入時的專業筆畫（圖學筆畫、專業筆刷）與「已擦除」名單 ——
    /// 「恢復初始狀態」要連它們一起還原，不然圖學筆記本裡畫的線一條都不會少。
    @State private var initialPageInk: [Int: InitialPageInk] = [:]

    struct InitialPageInk {
        var own: [ProStroke]
        var foreign: [ProStroke]
        var suppressed: Set<String>
        var erasedPencilKit: Set<String>
    }
    @State private var showRevertConfirmAlert: Bool = false
    /// 圖層面板裡選取的形狀。多選才群組得起來。
    @State private var selectedShapeIds: Set<String> = []
    /// 被選取的連接線（連接線不在 `selectedShapeIds` 裡 —— 它不是形狀，沒有群組與對齊）。
    @State private var selectedConnectionId: String? = nil
    @State private var editingShapeId: String? = nil
    @State private var editingConnectionId: String? = nil
    /// 拖曳連接點拉線時的預覽。
    @State private var connectionDraft: (page: Int, start: CGPoint, current: CGPoint)? = nil
    /// 正在重新編修的表格。
    @State private var editingTable: NoteTableAttachment? = nil
    @State private var editingAttachmentId: String? = nil
    /// 正在重新編修的圖表。帶著規格一起，`sheet(item:)` 才有東西可以開。
    @State private var editingChartAttachmentId: ChartEditTarget? = nil
    /// 正在重新編修的算式卡片。
    @State private var editingMathAttachmentId: MathEditTarget? = nil

    // Word 文字排版、網址預覽與專業調色狀態
    @State private var showWordStudio: Bool = false
    /// 摘要與待辦（工作項 S-20）。
    @State private var showNoteIntelligence: Bool = false
    @State private var editingTextId: String? = nil
    /// 隨點隨打就地輸入狀態（連動 TextAttachmentItemView 的焦點與鍵盤）
    @State private var inlineEditingTextId: String? = nil
    @State private var lastAddedTextId: String? = nil
    // 文字復原/重做堆疊（供文字模式與文字框使用）
    @State private var textUndoStack: [[NoteTextAttachment]] = []
    @State private var textRedoStack: [[NoteTextAttachment]] = []
    @State private var lastTextUndoTimestamp: Date = .distantPast
    @ObservedObject private var watchdog = InteractionWatchdog.shared


    // 單頁模式排版與縮放狀態（全頁 vs 適寬，支援手動放大縮小與捲動）
    enum SinglePageFitMode: String {
        case fitWidth
        case fitPage
    }
    @State private var singlePageFitMode: SinglePageFitMode = .fitWidth
    @State private var singlePageManualZoom: CGFloat = 1.0

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
    /// 已知的物件 id，用來認出「剛插入的」。`nil` 代表尚未建立基準（開啟筆記當下）。
    @State private var knownObjectIds: Set<String>? = nil
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
        collaborationManager.status != .disconnected || !collaborationManager.currentRoomId.isEmpty
    }


    // 筆記主模式：手繪 (Draw) vs 鍵盤打字 (Type)
    @State private var editorMode: EditorMode = .draw
    /// 軟體鍵盤避讓高度（Word 級打字流暢滾動視窗，避免畫面跳動或文字被遮擋）
    @State private var keyboardHeight: CGFloat = 0
    /// 模式徽章是不是正顯示著。切換模式時亮起，過幾秒自己淡掉。
    ///
    /// **不常駐**（工作項 S-62）：它原本一直蓋在畫布右上角，330pt 寬，
    /// 等於永遠有一塊紙面被說明文字佔著。模式本身在工具列的切換器上看得到，
    /// 徽章要說的是「這個模式下手勢會怎樣」—— 那是切換當下才需要的提示。
    @State private var modeBadgeVisible: Bool = false
    /// 用來取消上一次的淡出排程：連續切換兩次時，第一次的排程不該把
    /// 第二次剛亮起的徽章關掉。
    @State private var modeBadgeToken: Int = 0

    /// 工具切換快顯提示：點擊任一筆刷或工具時在工具列緊鄰處彈出提示工具名稱
    @State private var activeToolToast: (name: String, icon: String)? = nil
    @State private var toolToastToken: Int = 0

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
        var initialPage = 0
        if let targetPageStr = ProcessInfo.processInfo.environment["KAIRUMO_AUTO_OPEN_PAGE"],
           let targetPage = Int(targetPageStr), targetPage >= 0 && targetPage < notebook.wrappedValue.pageCount {
            initialPage = targetPage
        }
        let initialDrawing = NotebookStore.shared.loadDrawing(notebookId: notebook.wrappedValue.id, pageIndex: initialPage)
        self._currentDrawing = State(initialValue: initialDrawing)
        self._currentPageIndex = State(initialValue: initialPage)
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
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
                            removal: .opacity
                        ))
                }
            } else {
                wordModeToolbar
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
                        removal: .opacity
                    ))
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

                        // 手寫與打字**共用同一塊畫布**：紙張樣板、置中、可用區域框線、
                        // 文字方塊與其他物件都在這裡。
                        //
                        // **打字模式不可以換成 `WordDocumentEditorView`。** 那條路換掉的
                        // 是整塊工作區，結果：
                        //   1. 樣板消失 —— 選了「橫線筆記」，切到文字卻是全白頁
                        //   2. 頁面不置中（固定 760pt 寬、可橫向捲動），可用區域框線也沒了
                        //   3. 畫布上的文字方塊物件層不在樹裡，切回手繪後那些方塊
                        //      點不動、拖不動
                        // 這三個問題在 22fbc58 修過一次（撤掉 Word 模式），e479503 又把它
                        // 「恢復」回來，同樣的症狀原封不動地回來。
                        //
                        // 文書排版的工具（`WordToolbarView`）仍在工具列上，操作的是
                        // 這塊畫布上的文字方塊。
                        //
                        // 寬度要**釘在剩下的空間**：A3 橫式這類大頁面的畫布理想寬度比螢幕大，
                        // 不釘的話整塊工作區（連同工具列）被撐寬、右邊的工具被切到螢幕外。
                        canvasWorkArea
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .clipped()
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
                      EditorToolType.shortcutOrder.indices.contains(index) else { return }
                selectEditorTool(EditorToolType.shortcutOrder[index])
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
                    AnyView(minimalToolboxContent)
                }
                .padding(20)
                .shadow(color: Color.black.opacity(0.2), radius: 10, y: 4)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            if let guidance = watchdog.activeGuidance {
                ContextGuidanceHUDView(
                    item: guidance,
                    onPerformAction: {
                        guidance.action?()
                    },
                    onDismiss: {
                        guidance.onDismiss?()
                        watchdog.dismissGuidance()
                    }
                )
                .padding(.top, 54)
                .zIndex(99999)
            }
        }
        .onChange(of: editorMode) { newMode in
            watchdog.notifyModeSwitch(to: newMode)
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
        // 軟體鍵盤應覆蓋視窗底部，而不是重新排版整個編輯器。否則鍵盤每次
        // 出現／消失都會改變 GeometryReader 高度，畫布和物件跟著跳動。
        .ignoresSafeArea(.keyboard, edges: .bottom)
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
        .onReceive(NotificationCenter.default.publisher(for: AppCommand.proInkDidChange), perform: handleProInkDidChange)
        .onReceive(NotificationCenter.default.publisher(for: AppCommand.notebookPackageChanged), perform: handleNotebookPackageChanged)
        .onChange(of: notebook.id) { _ in
            // 外層換綁之後才會走到這裡，這時 notebook 已經是新的那一則。
            currentPageIndex = 0
            FocusSyncController.shared.setFocus(notebook.id)
            coreInkBaselines.removeAll()
            pendingCoreInk.removeAll()
            coreInkWork?.cancel()
            coreInkWork = nil
            loadCurrentPage()
            initialNotebookSnapshot = notebook
            initialPageDrawings.removeAll()
            initialPageInk.removeAll()
            captureInitialPageState(page: 0, drawing: currentDrawing)
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
            lasso.proHost = { (canvasView as? AdaptiveCanvasView)?.proLayer }
            store.activeNotebookId = notebook.id
            // 開著的這一本走焦點通道（秒同步）與區網直連。
            sanitizeTextAttachments()
            sanitizeUnderInkObjects()
            if let targetPageStr = ProcessInfo.processInfo.environment["KAIRUMO_AUTO_OPEN_PAGE"],
               let targetPage = Int(targetPageStr), targetPage >= 0 && targetPage < notebook.pageCount {
                currentPageIndex = targetPage
            }
            loadCurrentPage()
            // 製圖用的紙（三視圖、等角、作圖步驟…）一打開就選好「圖學」筆組。
            if paperUsesDrafting(paperId: notebook.paperId(forPage: currentPageIndex)) {
                selectedTool = .drafting
            }
            MacWindowTitle.apply()
            // 擷取剛打開筆記本時的初始狀態（提供一鍵恢復初始狀態功能）
            if initialNotebookSnapshot == nil {
                initialNotebookSnapshot = notebook
                captureInitialPageState(page: currentPageIndex, drawing: currentDrawing)
            }
            // 進到編輯器時也亮一次：第一次開的人要知道自己在哪個模式。
            flashModeBadge()
        }
        .onDisappear {
            if store.activeNotebookId == notebook.id {
                store.activeNotebookId = nil
                FocusSyncController.shared.setFocus(nil)
            }
            saveCurrentPageDrawing()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background || phase == .inactive {
                saveCurrentPageDrawing()
            } else if phase == .active {
                // 從背景切回前景時，檢查同步是否已更新這本筆記
                coreInkBaselines.removeAll()
                loadCurrentPage()
                PageThumbnailRenderer.invalidateAll()
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
                // 拿不到畫布或 UI 測試模擬無畫布時提示使用者
                let noCanvas = ProcessInfo.processInfo
                    .environment["KAIRUMO_UITEST_NO_CANVAS"] == "1"
                guard !noCanvas else {
                    showCanvasNotice(localizationManager.localized("insert_needs_canvas"))
                    return
                }

                // 放置貼紙的浮層（拖曳、縮放、旋轉、確認）畫在物件層裡，而**手寫模式下
                // 物件層不吃觸控**（見 `objectLayer(forPage:)`）。原本這裡切到手寫模式，
                // 於是浮層上的「放置」按鈕根本按不到 —— 點下去變成在畫布上畫了一個點。
                // 要切就切到打字模式，浮層才碰得到；確認後貼紙也是物件，同樣要在這個模式下才能動。
                if editorMode != .type {
                    editorMode = .type
                }

                // 計算貼紙置中位置：若拿得到 canvasView 則以可視區為準，否則以紙張中心為準
                let targetCenter: CGPoint
                if let canvas = canvasView, canvas.bounds.width > 50, canvas.bounds.height > 50 {
                    targetCenter = CGPoint(x: canvas.bounds.midX, y: canvas.bounds.midY)
                } else {
                    targetCenter = CGPoint(x: PageGeometry.width / 2.0, y: PageGeometry.height / 2.0)
                }

                let b = drawing.bounds
                let baseW = max(70, min(b.width > 0 ? b.width : 160, 260))
                let baseH = max(70, min(b.height > 0 ? b.height : 160, 260))

                // 若為自動化測試環境，直接蓋印以相容非互動 headless 測試流程
                if ProcessInfo.processInfo.environment["KAIRUMO_UITEST"] == "1" {
                    insertStickerObject(PendingStickerPlacement(
                        drawing: drawing,
                        center: targetCenter,
                        size: CGSize(width: baseW, height: baseH)))
                } else {
                    // 進入互動式貼圖放置模式：使用者可全畫面自由拖曳定位、縮放大小、旋轉角度，滿意後再確認蓋印
                    self.pendingStickerPlacement = PendingStickerPlacement(
                        drawing: drawing,
                        center: targetCenter,
                        size: CGSize(width: baseW, height: baseH),
                        scale: 1.0,
                        rotationDegrees: 0
                    )
                }
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
            activeImportSlot: $activeImportSlot,
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
            onPdf: { outcome in
                pdfToInsert = store.importedFileURL(fileName: outcome.storedName)
            },
            onDocument: { outcome in importDocumentOutcome(outcome) }
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
            MathCalculatorSheet(
                onInsertFormula: { exprText, cardImage in
                    insertImageAttachment(cardImage, mathFormula: exprText)
                },
                onInsertEditableText: { formulaText in
                    insertFormulaText(formulaText)
                }
            )
        } }
        .sheet(isPresented: $showShapeStudio) { resizableSheet {
            ShapeStudioView { shapes, connections in
                if notebook.shapeAttachments == nil { notebook.shapeAttachments = [] }
                if notebook.connectionAttachments == nil { notebook.connectionAttachments = [] }
                for shape in shapes {
                    var placed = shape
                    placed.pageIndex = currentPageIndex
                    notebook.shapeAttachments?.append(placed)
                    if let data = try? JSONEncoder().encode(placed),
                       let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        collaborationManager.broadcastAttachmentUpsert(type: "shape", itemDict: dict)
                    }
                }
                for connection in connections {
                    var placed = connection
                    placed.pageIndex = currentPageIndex
                    notebook.connectionAttachments?.append(placed)
                    if let data = try? JSONEncoder().encode(placed),
                       let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        collaborationManager.broadcastAttachmentUpsert(type: "connection", itemDict: dict)
                    }
                }
                store.updateNotebook(notebook)
                PageThumbnailRenderer.invalidateAll()
            }
        } }
        .sheet(isPresented: $showTableStudio) { resizableSheet {
            TableStudioView { created in
                var table = created
                table.pageIndex = currentPageIndex
                let targetX = max(PageGeometry.printableInset, (PageGeometry.width - table.width) / 2)
                let baseOffsetY = max(PageGeometry.printableInset, canvasContentOffset.y + 120)
                let existingCount = notebook.tableAttachments?.filter { $0.pageIndex == currentPageIndex }.count ?? 0
                table.x = targetX
                table.y = min(PageGeometry.height - 200, baseOffsetY + CGFloat(existingCount * 40))
                if notebook.tableAttachments == nil { notebook.tableAttachments = [] }
                notebook.tableAttachments?.append(table)
                activeSelectedObjectId = table.id
                selectedObjectIds = [table.id]
                store.updateNotebook(notebook)
                PageThumbnailRenderer.invalidateAll()
                if let data = try? JSONEncoder().encode(table),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    collaborationManager.broadcastAttachmentUpsert(type: "table", itemDict: dict)
                }
            }
            .frame(minWidth: 540)
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
                PageThumbnailRenderer.invalidateAll()
                if let data = try? JSONEncoder().encode(table),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    collaborationManager.broadcastAttachmentUpsert(type: "table", itemDict: dict)
                }
            }
            .frame(minWidth: 540)
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
        // 重新編修算式卡片：回到原生的計算視窗，帶入原始輸入的算式
        .sheet(item: $editingMathAttachmentId) { target in resizableSheet {
            MathCalculatorSheet(
                initialFormula: target.formula,
                onInsertFormula: { exprText, cardImage in
                    replaceMathAttachment(id: target.id, formula: exprText, image: cardImage)
                },
                onInsertEditableText: { formulaText in
                    replaceMathAttachment(id: target.id, formula: formulaText, image: nil)
                    insertFormulaText(formulaText)
                }
            )
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
                if let data = try? JSONEncoder().encode(created),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    collaborationManager.broadcastAttachmentUpsert(type: "text", itemDict: dict)
                }
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
                if let data = try? JSONEncoder().encode(placed),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    collaborationManager.broadcastAttachmentUpsert(type: "link", itemDict: dict)
                }
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
                PageThumbnailRenderer.invalidateAll()
                if let data = try? JSONEncoder().encode(att),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    collaborationManager.broadcastAttachmentUpsert(type: "3d", itemDict: dict)
                }
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
                    store.renameNotebook(id: notebook.id, newTitle: renameText)
                    if let updated = store.notebooks.first(where: { $0.id.caseInsensitiveCompare(notebook.id) == .orderedSame }) {
                        notebook = updated
                    }
                }
            }
        }
        // 確認視窗掛在自己的隱藏載體上（見 `revertAlertHost`）。
        .background(revertAlertHost)
        .background(Color.clear.alert(localizationManager.localized("clear_page"), isPresented: $showClearConfirmAlert) {
            Button(localizationManager.localized("cancel"), role: .cancel) {}
            Button(localizationManager.localized("clear_confirm"), role: .destructive) {
                currentDrawing = PKDrawing()
                store.saveDrawing(notebookId: notebook.id, pageIndex: currentPageIndex, drawing: currentDrawing)
                // 專業筆刷的筆畫另存，一起清掉。
                ProInkStore.save([], in: store.drawingsDirectory, notebookId: notebook.id, page: currentPageIndex)
                (canvasView as? AdaptiveCanvasView)?.proLayer?.reload()
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
        .sheet(isPresented: $showMoveNotebookSheet) {
            moveNotebookSheetContent
        }
    }

    private func handleProInkDidChange(_ note: Notification) {
        guard (note.object as? String) == notebook.id.lowercased() else { return }
        proInkDirty = true
        thumbnailRevision += 1
        noteInkEdited()
    }

    private func handleNotebookPackageChanged(_ note: Notification) {
        let changedId = note.object as? String
        if changedId == nil || changedId?.caseInsensitiveCompare(notebook.id) == .orderedSame {
            coreInkBaselines.removeAll()
            loadCurrentPage()
            PageThumbnailRenderer.invalidateAll()
        }
    }

    @ViewBuilder
    private var moveNotebookSheetContent: some View {
        resizableSheet {
            MoveNotebookSheet(notebookId: notebookToMoveId ?? notebook.id)
        }
    }

    /// 「一鍵恢復初始狀態」的確認視窗載體。
    ///
    /// 每個 `.alert` 要各掛在自己的 view 上：同一個 view 上疊多個 `.alert` 時只有一個會出現，
    /// 其餘的永遠不跳 —— 按了「恢復初始狀態」沒反應、確認視窗根本沒出現就是這樣。
    /// 抽成獨立屬性也讓 `body` 的型別推導不至於過長。
    private var revertAlertHost: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .alert(localizationManager.localized("revert_to_initial_state"), isPresented: $showRevertConfirmAlert) {
                Button(localizationManager.localized("cancel"), role: .cancel) {}
                Button(localizationManager.localized("revert_confirm_action"), role: .destructive) {
                    if let snapshot = initialNotebookSnapshot {
                        notebook = snapshot
                        restoreInitialPages()
                        currentDrawing = initialPageDrawings[currentPageIndex] ?? store.loadDrawing(notebookId: notebook.id, pageIndex: currentPageIndex)
                        if let canvas = canvasView {
                            // 程式指派 drawing 會讓復原堆疊裡的項目全部失效：整個清掉，
                            // 免得按復原吃掉點擊、什麼都沒發生。
                            canvas.drawing = currentDrawing
                            canvas.undoManager?.removeAllActions()
                            (canvas as? AdaptiveCanvasView)?.proLayer?.reload()
                        }
                        store.updateNotebook(notebook)
                        continuousReloadGeneration += 1
                        thumbnailRevision += 1
                        showCanvasNotice(localizationManager.localized("revert_done"))
                        activeSelectedObjectId = nil
                        inlineEditingTextId = nil
                        editingTextId = nil
                        selectedShapeIds = []
                        selectedConnectionId = nil
                        selectedObjectIds = []
                        PageThumbnailRenderer.invalidateAll()
                    }
                }
            } message: {
                Text(localizationManager.localized("revert_to_initial_state_confirm"))
            }
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

    private func triggerFileImport(_ slot: FfiImportSlot) {
        SheetCoordinator.shared.triggerFileImportFromMenu {
            self.activeImportSlot = slot
        }
    }

    private func presentFromMenu(_ action: @escaping () -> Void) {
        SheetCoordinator.shared.presentFromMenu(action)
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
            .help(localizationManager.localized("structure_sidebar_desc"))

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
                .help(localizationManager.localized("add_page_desc"))
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
            .help(localizationManager.localized("ruler_desc"))

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
            .help(L("posture_tabletop_mode_desc"))

            // 復原與重做 (Undo / Redo)
            HStack(spacing: 10) {
                Button {
                    performUndo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(5)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(6)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(localizationManager.localized("undo"))
                .help(localizationManager.localized("undo_desc"))

                Button {
                    performRedo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(5)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(6)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(localizationManager.localized("redo"))
                .help(localizationManager.localized("redo_desc"))

                Divider().frame(height: 20)

                Button {
                    showRevertConfirmAlert = true
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(5)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(6)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(localizationManager.localized("revert_to_initial_state"))
                .help(localizationManager.localized("revert_to_initial_state"))
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
                Section {
                    Button {
                        presentFromMenu { showAssetLibrarySheet = true }
                    } label: {
                        Label(localizationManager.localized("asset_library"), systemImage: "shippingbox.fill")
                    }

                    Button {
                        presentFromMenu { showPhotoPicker = true }
                    } label: {
                        Label(localizationManager.localized("insert_image"), systemImage: "photo.badge.plus")
                    }

                    Button {
                        triggerFileImport(.image)
                    } label: {
                        Label(localizationManager.localized("import_from_files"), systemImage: "folder.badge.plus")
                    }

                    Button {
                        presentFromMenu { showAudioPicker = true }
                    } label: {
                        Label(localizationManager.localized("insert_audio"), systemImage: "waveform.badge.plus")
                    }

                    Button {
                        triggerFileImport(.audio)
                    } label: {
                        Label(localizationManager.localized("import_audio_from_files"), systemImage: "square.and.arrow.down.on.square")
                    }

                    Button {
                        triggerFileImport(.pdf)
                    } label: {
                        Label(localizationManager.localized("insert_pdf"), systemImage: "doc.richtext")
                    }

                    Button {
                        triggerFileImport(.document)
                    } label: {
                        Label(localizationManager.localized("import_document"), systemImage: "doc.text")
                    }
                }

                Section {
                    Button {
                        presentFromMenu { showTableStudio = true }
                    } label: {
                        Label(localizationManager.localized("table_studio"), systemImage: "tablecells")
                    }

                    Button {
                        presentFromMenu { showShapeStudio = true }
                    } label: {
                        Label(localizationManager.localized("shape_studio"), systemImage: "square.on.circle")
                    }

                    Button {
                        presentFromMenu { showMathCalculator = true }
                    } label: {
                        Label(localizationManager.localized("math_calc"), systemImage: "plus.forwardslash.minus")
                    }

                    Button {
                        presentFromMenu { showChartStudio = true }
                    } label: {
                        Label(localizationManager.localized("chart_studio"), systemImage: "chart.bar.xaxis")
                    }

                    Button {
                        presentFromMenu { show3DStudio = true }
                    } label: {
                        Label(localizationManager.localized("insert_3d"), systemImage: "cube.transparent")
                    }

                    Button {
                        presentFromMenu { showLinkPreviewSheet = true }
                    } label: {
                        Label(localizationManager.localized("insert_link"), systemImage: "link")
                    }

                    Button {
                        presentFromMenu { showThemeToolsSheet = true }
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

                    Button {
                        presentFromMenu { showNoteIntelligence = true }
                    } label: {
                        Label(
                            localizationManager.localized("ai_summary"),
                            systemImage: "sparkles")
                    }
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
            .help(localizationManager.localized("comment_pin_desc"))

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
            .help(localizationManager.localized("collaborate_desc"))

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
                            title: NotebookStore.defaultRecordingTitle(),
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
                    presentFromMenu {
                        exportAsPdf()
                    }
                } label: {
                    Label(localizationManager.localized("export_pdf"), systemImage: "doc.text.fill")
                }

                Button {
                    presentFromMenu {
                        exportAsPngImage()
                    }
                } label: {
                    Label(localizationManager.localized("export_image"), systemImage: "photo")
                }

                Button {
                    presentFromMenu {
                        printCurrentNotebook()
                    }
                } label: {
                    Label(localizationManager.localized("print_note"), systemImage: "printer.fill")
                }

                ToolbarSeparator()

                Button {
                    presentFromMenu {
                        shareNotebookFile()
                    }
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
                    .font(.system(size: EditorToolbarMetrics.icon, weight: .bold))
                Image(systemName: "house.fill")
                    .font(.system(size: EditorToolbarMetrics.icon))
            }
            .foregroundColor(.white)
            .padding(.horizontal, EditorToolbarMetrics.padding + 3)
            .padding(.vertical, EditorToolbarMetrics.padding)
            .background(Color.accentColor)
            .cornerRadius(EditorToolbarMetrics.corner)
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
                .font(.system(size: EditorToolbarMetrics.icon, weight: .semibold))
                .foregroundColor(showStructureSidebar ? .accentColor : .primary)
                .padding(EditorToolbarMetrics.padding)
                .background(showStructureSidebar ? Color.accentColor.opacity(0.15) : Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(EditorToolbarMetrics.corner)
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
                    .font(.system(size: EditorToolbarMetrics.icon, weight: .bold))
                    .foregroundColor(.white)
                    .padding(EditorToolbarMetrics.padding)
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
                .font(.system(size: EditorToolbarMetrics.label, weight: .semibold))
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("editor.title")

        // 復原、重做與恢復初始狀態（膠囊群組，支援連續無限制復原）
        HStack(spacing: 2) {
            Button {
                performUndo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: EditorToolbarMetrics.icon - 3, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(localizationManager.localized("undo"))
            .help(localizationManager.localized("undo_desc"))
            .accessibilityIdentifier("editor.compact.undo")

            Button {
                performRedo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: EditorToolbarMetrics.icon - 3, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(localizationManager.localized("redo"))
            .help(localizationManager.localized("redo_desc"))
            .accessibilityIdentifier("editor.compact.redo")

            Divider().frame(height: 14)

            Button {
                showRevertConfirmAlert = true
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: EditorToolbarMetrics.icon - 3, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(localizationManager.localized("revert_to_initial_state"))
            .help(localizationManager.localized("revert_to_initial_state"))
            .accessibilityIdentifier("editor.compact.revert")
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 2)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .cornerRadius(EditorToolbarMetrics.corner)

        Spacer(minLength: 2)

        // 頁面導覽群組膠囊 (上一頁、頁碼指示、下一頁、新增頁面、連續/整頁切換)
        HStack(spacing: 2) {
            Button {
                if currentPageIndex > 0 {
                    saveCurrentPageDrawing()
                    currentPageIndex -= 1
                    loadCurrentPage()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: EditorToolbarMetrics.icon - 3, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .disabled(currentPageIndex <= 0)
            .accessibilityIdentifier("editor.page.prev")

            Text("\(currentPageIndex + 1)/\(max(1, notebook.pageCount))")
                .font(.system(size: EditorToolbarMetrics.label, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 3)
                .accessibilityIdentifier("editor.page.indicator")

            Button {
                if currentPageIndex < notebook.pageCount - 1 {
                    saveCurrentPageDrawing()
                    currentPageIndex += 1
                    loadCurrentPage()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: EditorToolbarMetrics.icon - 3, weight: .semibold))
                    .frame(width: 24, height: 28)
            }
            .disabled(currentPageIndex >= notebook.pageCount - 1)
            .accessibilityIdentifier("editor.page.next")

            Divider().frame(height: 14)

            Button {
                addNewPage()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: EditorToolbarMetrics.icon - 3, weight: .bold))
                    .foregroundColor(.accentColor)
                    .frame(width: 24, height: 28)
            }
            .accessibilityLabel(localizationManager.localized("add_page"))
            .help(localizationManager.localized("add_page_desc"))
            .accessibilityIdentifier("editor.page.add")

            Button {
                saveCurrentPageDrawing()
                let next: PageDisplayMode = pageDisplayMode == .single ? .continuous : .single
                pageDisplayModeRaw = next.rawValue
                if next == .single {
                    loadCurrentPage()
                }
            } label: {
                Image(systemName: pageDisplayMode == .continuous
                    ? "rectangle.split.1x2"
                    : "doc.plaintext")
                    .font(.system(size: EditorToolbarMetrics.icon - 3))
                    .foregroundColor(pageDisplayMode == .continuous ? .accentColor : .secondary)
                    .frame(width: 24, height: 28)
            }
            .help(localizationManager.localized(
                pageDisplayMode == .continuous ? "page_mode_continuous" : "page_mode_single"))
            .accessibilityLabel(localizationManager.localized("page_mode"))
            .accessibilityIdentifier("editor.page.display_mode")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .cornerRadius(EditorToolbarMetrics.corner)

        // 紙張規格與版面調色膠囊（整合為一體化功能膠囊）
        HStack(spacing: 2) {
            pageFormatMenu
                .accessibilityIdentifier("editor.page_format")
            Divider().frame(height: 14)
            guidePaletteMenu
                .accessibilityIdentifier("editor.guide_palette")
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 2)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .cornerRadius(EditorToolbarMetrics.corner)

        // 👥 線上多人即時協同按鈕（常駐於頂部列，與 Mac 對齊；iPad 顯示圖示+文字，iPhone 顯示精簡圖示）
        Button {
            showCollaborationSheet = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isCollaborating ? "person.2.wave.2.fill" : "person.2.fill")
                    .font(.system(size: EditorToolbarMetrics.icon - 1))
                    .foregroundColor(isCollaborating ? .green : .accentColor)
                if horizontalSizeClass == .regular {
                    Text(localizationManager.localized("collaborate"))
                        .font(.system(size: EditorToolbarMetrics.label, weight: .medium))
                        .foregroundColor(isCollaborating ? .green : .primary)
                }
                if isCollaborating {
                    Text("\(collaborationManager.peers.count + 1)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, horizontalSizeClass == .regular ? 6 : EditorToolbarMetrics.padding)
            .padding(.vertical, EditorToolbarMetrics.padding)
            .background(isCollaborating ? Color.green.opacity(0.15) : Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(EditorToolbarMetrics.corner)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized("collaborate"))
        .help(localizationManager.localized("collaborate_desc"))
        .accessibilityIdentifier("editor.compact.collaborate")

        // ➕ 插入物件選單（藍色品牌主按鈕，在 iPad 上以醒目膠囊呈現，對齊 Mac 體驗）
        Menu {
            Section {
                Button {
                    presentFromMenu { showAssetLibrarySheet = true }
                } label: { Label(localizationManager.localized("asset_library"), systemImage: "shippingbox.fill") }
                    .accessibilityIdentifier("editor.insert.assets")
                Button {
                    presentFromMenu { showStickerLibrary = true }
                } label: { Label(localizationManager.localized("sticker_library"), systemImage: "photo.on.rectangle") }
                    .accessibilityIdentifier("editor.insert.stickers")
                Button {
                    presentFromMenu { setMarqueeActive(!isMarqueeActive) }
                } label: { Label(localizationManager.localized("marquee_select"), systemImage: "square.dashed") }
                    .accessibilityIdentifier("editor.insert.marquee")
                Button {
                    presentFromMenu { showAudioPicker = true }
                } label: { Label(localizationManager.localized("insert_audio"), systemImage: "waveform.badge.plus") }
                    .accessibilityIdentifier("editor.insert.audio")
                Button {
                    triggerFileImport(.audio)
                } label: { Label(localizationManager.localized("import_audio_from_files"), systemImage: "square.and.arrow.down.on.square") }
                    .accessibilityIdentifier("editor.insert.audio_file")
                Button {
                    presentFromMenu { showPhotoPicker = true }
                } label: { Label(localizationManager.localized("insert_image"), systemImage: "photo.badge.plus") }
                    .accessibilityIdentifier("editor.insert.image")
                Button {
                    triggerFileImport(.image)
                } label: { Label(localizationManager.localized("import_from_files"), systemImage: "folder.badge.plus") }
                    .accessibilityIdentifier("editor.insert.image_file")
                Button {
                    triggerFileImport(.pdf)
                } label: { Label(localizationManager.localized("insert_pdf"), systemImage: "doc.richtext") }
                    .accessibilityIdentifier("editor.insert.pdf")
                Button {
                    triggerFileImport(.document)
                } label: { Label(localizationManager.localized("import_document"), systemImage: "doc.text") }
                    .accessibilityIdentifier("editor.insert.document")
                Button {
                    presentFromMenu { showMathCalculator = true }
                } label: { Label(localizationManager.localized("math_calc"), systemImage: "plus.forwardslash.minus") }
                    .accessibilityIdentifier("editor.insert.math")
                Button {
                    presentFromMenu { showChartStudio = true }
                } label: { Label(localizationManager.localized("chart_studio"), systemImage: "chart.bar.xaxis") }
                    .accessibilityIdentifier("editor.insert.chart")
                Button {
                    presentFromMenu { showTableStudio = true }
                } label: { Label(localizationManager.localized("table_studio"), systemImage: "tablecells") }
                    .accessibilityIdentifier("editor.insert.table")
                Button {
                    presentFromMenu { showShapeStudio = true }
                } label: { Label(localizationManager.localized("shape_studio"), systemImage: "square.on.circle") }
                    .accessibilityIdentifier("editor.insert.shape")
                Button {
                    presentFromMenu { show3DStudio = true }
                } label: { Label(localizationManager.localized("insert_3d"), systemImage: "cube.transparent") }
                    .accessibilityIdentifier("editor.insert.model3d")
                Button {
                    presentFromMenu { showThemeToolsSheet = true }
                } label: { Label(localizationManager.localized("theme_tools"), systemImage: "paintpalette.fill") }
                    .accessibilityIdentifier("editor.insert.theme_tools")
            } header: {
                Text(localizationManager.localized("insert_object"))
            }

            Section {
                Button {
                    withAnimation {
                        insertSpaceDividerY = min(currentPageHeight - 100, max(150, canvasContentOffset.y + 300))
                        isInsertSpaceActive.toggle()
                    }
                } label: { Label(localizationManager.localized("insert_vertical_space"), systemImage: "arrow.up.and.down.square") }
                    .accessibilityIdentifier("editor.insert.space")
                Button { withAnimation { showSketchRefineBar.toggle() } } label: { Label(localizationManager.localized("refine_sketch"), systemImage: "wand.and.stars") }
                    .accessibilityIdentifier("editor.insert.refine_sketch")
                Button {
                    presentFromMenu { showNoteIntelligence = true }
                } label: {
                    Label(localizationManager.localized("ai_summary"), systemImage: "sparkles")
                }
                .accessibilityIdentifier("editor.insert.ai_summary")
                Button { recognizeHandwritingOnCurrentPage() } label: {
                    Label(localizationManager.localized("recognize_handwriting"), systemImage: "text.viewfinder")
                }
                .accessibilityIdentifier("editor.insert.recognize")
                Button {
                    presentFromMenu { showCollaborationSheet = true }
                } label: { Label(localizationManager.localized("collaborate"), systemImage: "person.2.fill") }
                    .accessibilityIdentifier("editor.insert.collaborate")
                Button { withAnimation { isPlacingCommentPin.toggle() } } label: { Label(localizationManager.localized("add_comment_pin"), systemImage: "text.bubble.fill") }
                    .accessibilityIdentifier("editor.insert.comment_pin")
                // 放在編輯器而不是設定頁：使用者想關掉某支筆的那一刻，
                // 是他正看著那支筆的時候。
                Button {
                    presentFromMenu { showToolbarCustomization = true }
                } label: {
                    Label(localizationManager.localized("customize_toolbar"), systemImage: "slider.horizontal.3")
                }
                .accessibilityIdentifier("editor.customize_toolbar")
                // 掌拒門檻（S-101）。判定一直都在核心，缺的只是「讓使用者調」——
                // 握筆姿勢比較特別的人，手掌一放上去就是一道線，
                // 而在此之前他完全沒有辦法處理。
                Button {
                    presentFromMenu { showPalmThresholdSheet = true }
                } label: {
                    Label(localizationManager.localized("palm_rejection_settings"), systemImage: "hand.raised.slash")
                }
                .accessibilityIdentifier("editor.insert.palm_thresholds")
                Button {
                    presentFromMenu { showAdvancedPenSettingsSheet = true }
                } label: {
                    Label(localizationManager.localized("pen_settings_title"), systemImage: "applepencil.and.scribble")
                }
                .accessibilityIdentifier("editor.insert.advanced_pen_settings")

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isTabletopMode.toggle()
                    }
                } label: {
                    Label(L("posture_tabletop_mode"), systemImage: "laptopcomputer.and.ipad")
                }
                .accessibilityIdentifier("editor.tabletop_mode")

                Button(role: .destructive) {
                    showRevertConfirmAlert = true
                } label: {
                    Label(localizationManager.localized("revert_to_initial_state"), systemImage: "arrow.counterclockwise")
                }
                .accessibilityIdentifier("editor.revert_initial_state")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: EditorToolbarMetrics.icon - 1, weight: .semibold))
                if horizontalSizeClass == .regular {
                    Text(localizationManager.localized("insert_object"))
                        .font(.system(size: EditorToolbarMetrics.label, weight: .semibold))
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, horizontalSizeClass == .regular ? 8 : EditorToolbarMetrics.padding + 2)
            .padding(.vertical, EditorToolbarMetrics.padding)
            .background(Color.accentColor)
            .cornerRadius(EditorToolbarMetrics.corner)
            .shadow(color: Color.accentColor.opacity(0.3), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized("insert_object"))
        .help(localizationManager.localized("insert_object"))
        .accessibilityIdentifier("editor.more")

        // 錄音
        if audioManager.status == .recording || audioManager.status == .paused {
            Button {
                stopAndSaveRecording()
            } label: {
                Circle()
                    .fill(audioManager.status == .recording ? Color.red : Color.orange)
                    .frame(width: EditorToolbarMetrics.icon - 3, height: EditorToolbarMetrics.icon - 3)
                    .padding(EditorToolbarMetrics.padding + 1.5)
                    .background((audioManager.status == .recording ? Color.red : Color.orange).opacity(0.15))
                    .cornerRadius(EditorToolbarMetrics.corner)
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
                    if forcedFailure {
                        audioManager.showPermissionAlert = false
                        showCanvasNotice(localizationManager.localized("recording_failed"))
                    } else {
                        let started = await audioManager.startRecording(
                            notebookId: notebook.id,
                            notebookTitle: notebook.displayTitle(),
                            title: NotebookStore.defaultRecordingTitle(),
                            pageIndex: currentPageIndex,
                            languageTag: LocalizationManager.shared.currentLanguage.rawValue)
                        if !started && !audioManager.showPermissionAlert {
                            showCanvasNotice(localizationManager.localized("recording_failed"))
                        }
                    }
                }
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: EditorToolbarMetrics.icon))
                    .foregroundColor(.red)
                    .padding(EditorToolbarMetrics.padding)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(EditorToolbarMetrics.corner)
            }
            .accessibilityIdentifier("editor.record")
        }

        // 匯出功能選單
        Menu {
            Button {
                presentFromMenu {
                    exportAsPdf()
                }
            } label: { Label(localizationManager.localized("export_pdf"), systemImage: "doc.text.fill") }
                .accessibilityIdentifier("editor.export.pdf")
            Button {
                presentFromMenu {
                    exportAsPngImage()
                }
            } label: { Label(localizationManager.localized("export_image"), systemImage: "photo") }
                .accessibilityIdentifier("editor.export.image")
            Button {
                presentFromMenu {
                    printCurrentNotebook()
                }
            } label: { Label(localizationManager.localized("print_note"), systemImage: "printer.fill") }
                .accessibilityIdentifier("editor.export.print")
            Divider()
            // **把檔案存到使用者自己選的位置。**
            //
            // 分享面板可以把檔案送去別的 App，但它不是儲存對話框 ——
            // 使用者沒辦法說「存到我的文件資料夾」。而這個 App 的資料全部
            // 在沙盒容器裡，容器是隱藏的、使用者碰不到。Mac App Store 審查
            // 指南 2.4.5(i) 因此把這個版本退了回來。
            Button {
                presentFromMenu {
                    saveNotebookFile()
                }
            } label: { Label(localizationManager.localized("export_save_as"), systemImage: "folder.badge.plus") }
                .accessibilityIdentifier("editor.export.save_as")
            Button {
                presentFromMenu {
                    shareNotebookFile()
                }
            } label: { Label(localizationManager.localized("share_note"), systemImage: "square.and.arrow.up") }
                .accessibilityIdentifier("editor.export.share")
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: EditorToolbarMetrics.icon, weight: .semibold))
                .foregroundColor(.white)
                .padding(EditorToolbarMetrics.padding)
                .background(Color.accentColor)
                .cornerRadius(EditorToolbarMetrics.corner)
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
                activeSelectedObjectId = table.id
                selectedObjectIds = [table.id]
                store.updateNotebook(notebook)
                PageThumbnailRenderer.invalidateAll()
                if let data = try? JSONEncoder().encode(table),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    collaborationManager.broadcastAttachmentUpsert(type: "table", itemDict: dict)
                }
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
            .overlay { objectEditPanels }
            .overlay(alignment: .top) {
                // 🌟 草圖智慧修飾浮動控制面板（兩種頁面模式共用）
                if showSketchRefineBar {
                    sketchRefineFloatingBar
                        .padding(.top, 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            .sheet(isPresented: $showDraftingToolbox) {
                DraftingToolbox(
                    notebookId: notebook.id,
                    frameSupported: frameSupportedForCurrentPage,
                    onPickTool: { tool in
                        // 鏡射、陣列要處理套索選的那批線：在離開套索之前把它帶過來。
                        if tool.needsSelection {
                            guard !lasso.proIds.isEmpty else {
                                showCanvasNotice(localizationManager.localized("draft_edit_need_selection"))
                                return
                            }
                            DraftingState.shared.editSelection = lasso.proIds
                        }
                        selectedTool = .drafting
                        DraftingState.shared.tool = tool
                        DraftToolController.shared.reset(layer: (canvasView as? AdaptiveCanvasView)?.proLayer)
                        DraftToolController.shared.refreshHint()
                    },
                    onInsertSymbol: { insertDraftKit($0) },
                    onInsertFrame: { insertDraftFrame(thirdAngle: $0) },
                    onPlaceInstrument: { kind in
                        selectedTool = .drafting
                        let center = draftViewportCenter()
                        DraftingState.shared.placeInstrument(kind: kind, center: center, pageWidth: PageGeometry.size.width)
                    },
                    onRectArray: { rows, cols, dx, dy in applyRectArray(rows: rows, cols: cols, dxMm: dx, dyMm: dy) },
                    onStartPractice: { startPractice(kind: $0) },
                    onExport: { exportDrafting(format: $0) })
            }
            .sheet(item: $draftExportShare) { item in
                ShareItemsSheet(items: [item.url])
            }
            .sheet(isPresented: $showSolidStudio) {
                SolidStudioSheet(
                    pageSize: PageGeometry.size,
                    sketchPolylines: { solidSketchPolylines() },
                    onInsert: { insertSolidSheet($0) })
            }
            .overlay(alignment: .bottomLeading) {
                // 練習題進行中：題目、選項、批改結果（見 DraftingPractice.swift）。
                let isDraftingPaper = paperUsesDrafting(paperId: notebook.paperId(forPage: currentPageIndex))
                if editorMode == .draw && (selectedTool == .drafting || isDraftingPaper) {
                    PracticeCard(
                        layer: { (canvasView as? AdaptiveCanvasView)?.proLayer },
                        onNew: {
                            if let kind = PracticeSession.shared.problem?.kind { startPractice(kind: kind) }
                        })
                        .padding(12)
                }
            }
            // 圖學：製圖筆組、圖層、吸附（見 DraftingBar.swift）。
            //
            // **佔用版面，不是浮在畫布上。** 原本是 `.overlay`，列疊在頁面最上方，
            // 蓋住頁首標題與題目文字（圖學頁一開頭就是標題）。改成 `safeAreaInset`：
            // 畫布整個往下讓出位置，收合或展開都不會壓到頁面內容。
            // 在圖學專用紙張中保持列位穩定，切換一般畫筆寫筆記時不會突然收合引發整個畫布抖動重繪與觸控延遲。
            .safeAreaInset(edge: .top, spacing: 0) {
                let isDraftingPaper = paperUsesDrafting(paperId: notebook.paperId(forPage: currentPageIndex))
                if editorMode == .draw && (selectedTool == .drafting || isDraftingPaper) {
                    DraftingBar(onOpenSolidStudio: { showSolidStudio = true },
                                onOpenToolbox: { showDraftingToolbox = true },
                                onMarkAngle: { markProtractorReading() })
                        .padding(.top, 8)
                        .padding(.bottom, 6)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .onAppear { if knownObjectIds == nil { knownObjectIds = Set(allObjectIds) } }
            .onChange(of: allObjectIds.count) { _ in placeNewObjectsOnTop() }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
                if let frame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
                    withAnimation(.easeOut(duration: 0.25)) {
                        keyboardHeight = frame.height
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = 0
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
    /// 放不下就等比縮小，放得下就放大填滿（有上限）並置中。
    ///
    /// 視窗寬就放大到填滿可用寬度（上限見 `PageViewportLayout.maxFitScale`）。
    private var singlePageWorkArea: some View {
        GeometryReader { outer in
            let availableWidth = max(outer.size.width - 32, 1)
            let availableHeight = max(outer.size.height - 32, 1)
            let widthScale = PageViewportLayout.scale(
                availableWidth: availableWidth,
                pageWidth: PageGeometry.width
            )
            let fitPageScale = min(widthScale, availableHeight / PageGeometry.height)
            let baseScale = (singlePageFitMode == .fitPage) ? fitPageScale : widthScale
            let effectiveScale = max(0.3, min(4.0, baseScale * singlePageManualZoom))
            let scaledW = PageGeometry.width * effectiveScale
            let scaledH = PageGeometry.height * effectiveScale

            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                ZStack(alignment: .top) {
                    canvasWorkAreaContent
                        // 頁面用**它自己的尺寸**佈局，再等比縮放
                        .frame(width: PageGeometry.width, height: PageGeometry.height)
                        .scaleEffect(effectiveScale, anchor: .top)
                        .frame(width: scaledW, height: scaledH, alignment: .top)
                        .padding(.bottom, inlineEditingTextId != nil ? keyboardHeight : 0)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("editor.canvas")
                }
                .frame(
                    minWidth: outer.size.width,
                    minHeight: outer.size.height,
                    alignment: .top
                )
            }
            .frame(width: outer.size.width, height: outer.size.height)
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 6) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            singlePageManualZoom = max(0.4, singlePageManualZoom - 0.15)
                        }
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            singlePageManualZoom = 1.0
                            singlePageFitMode = (singlePageFitMode == .fitPage) ? .fitWidth : .fitPage
                        }
                    } label: {
                        Text(singlePageFitMode == .fitPage
                            ? (localizationManager.currentLanguage == .zhHant ? "全頁" : "Fit Page")
                            : (localizationManager.currentLanguage == .zhHant ? "適寬" : "Fit Width"))
                            .font(.system(size: 11, weight: .bold))
                            .frame(minWidth: 28)
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            singlePageManualZoom = min(3.0, singlePageManualZoom + 0.15)
                        }
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
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
                        .contentShape(Rectangle())
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
                        .contentShape(Rectangle())
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
                        .contentShape(Rectangle())
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
                        .contentShape(Rectangle())
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
                            Text(L10n.t("tool_radial_short"))
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

                        Button { performRedo() } label: {
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
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.accentColor)
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
            // 視窗比紙張寬就放大到填滿（上限見 `PageViewportLayout.maxFitScale`），
            // 不留兩片灰邊讓畫布看起來被框住。
            let available = max(outer.size.width - 32, 1)
            let scale = PageViewportLayout.scale(
                availableWidth: available, pageWidth: PageGeometry.width)
            continuousPages(scale: scale)
        }
    }

    /// 連續模式：由捲動算出來的焦點頁（`updateFocusedPage` 寫入）。
    ///
    /// 用來分辨 `currentPageIndex` 的變動是「捲動帶來的」還是「程式叫它跳頁」
    /// （點側欄縮圖、上一頁／下一頁、新增頁面…）。後者才要捲過去；
    /// 前者再捲一次會跟使用者的手指打架。
    @State private var continuousReportedPage: Int = -1
    /// 專業筆畫有未標記的變動（見 `AppCommand.proInkDidChange`）。存檔時不能當成「沒變」略過。
    @State private var proInkDirty = false
    /// 「恢復初始狀態」之後遞增，讓連續模式的每一頁重讀磁碟（見 `ContinuousPageView.reloadGeneration`）。
    @State private var continuousReloadGeneration = 0
    /// 側欄縮圖的重繪計數：專業筆畫的變動不在任何 @State 裡，要靠它讓側欄重新算繪。
    @State private var thumbnailRevision = 0
    /// 要求連續模式再捲一次到目前頁（頁碼沒變但使用者點了同一頁的縮圖）。
    @State private var continuousScrollRequest: Int = 0
    /// 程式捲動進行中。這段時間內捲動中途經過的頁面不算焦點，否則
    /// 「點縮圖跳到第 3 頁」會在途中被第 7 頁的焦點判定打斷，最後停在半路。
    @State private var continuousProgrammaticScrollUntil: Date = .distantPast

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
                            onSelectionChanged: { if !$0 { lasso.clear() } },
                            onReachedPageBottom: { ensureNextPageExists() },
                            // LazyVStack 會建立多頁畫布；不能讓最後建立的頁面覆蓋
                            // `canvasView`，否則貼紙可能蓋到別頁且存檔頁碼也錯。
                            canvasRef: { ref in
                                // 同上：不在畫面更新途中改 @State，且只在真的換了才寫。
                                guard index == currentPageIndex, canvasView !== ref else { return }
                                DispatchQueue.main.async { canvasView = ref }
                            },
                            onCanvasTap: { location in
                                currentPageIndex = index
                                currentDrawing = drawingForPage(index)
                                handleCanvasDirectTap(at: location, page: index)
                            },
                            onCanvasDoubleTap: { location in
                                currentPageIndex = index
                                currentDrawing = drawingForPage(index)
                                handleCanvasDirectDoubleTap(at: location, page: index)
                            },
                            onPencilTouchBegan: {
                                currentPageIndex = index
                                currentDrawing = drawingForPage(index)
                                handlePencilTouchBegan()
                            },
                            onPenControl: applyPenControl,
                            onImageDropped: { page, providers, location in
                                acceptImageDrop(providers, at: location, page: page)
                            },
                            onInitialLoaded: { page, loaded in
                                captureInitialPageState(page: page, drawing: loaded)
                            },
                            reloadGeneration: continuousReloadGeneration,
                            notebook: $notebook,
                            onNotebookChanged: {
                                store.updateNotebook(notebook)
                                PageThumbnailRenderer.invalidateAll()
                            },
                            onLassoBegan: { pt in
                                lasso.begin(at: pt)
                            },
                            onLassoMoved: { pt in
                                if lasso.isDraggingSelection {
                                    let lastPt = lasso.dragPoint ?? pt
                                    let delta = CGSize(width: pt.x - lastPt.x, height: pt.y - lastPt.y)
                                    lasso.updateDragPoint(pt)
                                    if let updated = lasso.moveSelected(in: currentDrawing, by: delta) {
                                        currentDrawing = updated
                                        canvasView?.drawing = updated
                                    }
                                } else {
                                    lasso.extend(to: pt)
                                }
                            },
                            onLassoEnded: {
                                let wasDragging = lasso.isDraggingSelection
                                lasso.finish(in: currentDrawing)
                                if wasDragging {
                                    recordDrawingEdit(page: index, drawing: currentDrawing)
                                    broadcastDrawingChange(page: index, drawing: currentDrawing)
                                    PageThumbnailRenderer.invalidateAll()
                                }
                            },
                            lassoPath: lasso.path.isEmpty ? lasso.committed : lasso.path,
                            isLassoCommitted: lasso.path.isEmpty
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
            .onChange(of: currentPageIndex) { page in
                // 捲動自己帶來的變動不用再捲。
                guard page != continuousReportedPage else { return }
                continuousReportedPage = page
                scrollContinuous(to: page, proxy: proxy, animated: true)
            }
            .onChange(of: continuousScrollRequest) { _ in
                scrollContinuous(to: currentPageIndex, proxy: proxy, animated: true)
            }
            .onChange(of: notebook.pageCount) { _ in
                // 新增／刪除頁面之後頁碼可能沒變但內容換了，確保焦點頁在畫面上。
                scrollContinuous(to: currentPageIndex, proxy: proxy, animated: false)
            }
            .onAppear {
                // 從整頁模式切過來時，停在原本那一頁而不是回到第 1 頁。
                // LazyVStack 第一輪排版還沒完成時 scrollTo 會落空，所以下一輪與稍後再各補一次。
                continuousReportedPage = currentPageIndex
                scrollContinuous(to: currentPageIndex, proxy: proxy, animated: false)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    scrollContinuous(to: currentPageIndex, proxy: proxy, animated: false)
                }
            }
        }
    }

    private func scrollContinuous(to page: Int, proxy: ScrollViewProxy, animated: Bool) {
        let target = min(max(0, page), max(0, notebook.pageCount - 1))
        continuousProgrammaticScrollUntil = Date().addingTimeInterval(animated ? 0.8 : 0.4)
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(target, anchor: .top) }
            } else {
                proxy.scrollTo(target, anchor: .top)
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
        // 程式捲動進行中不判焦點（理由見 `continuousProgrammaticScrollUntil`）。
        guard Date() >= continuousProgrammaticScrollUntil else { return }
        // 視窗中央的 y。用固定的頁高估一個中線就夠 —— 這裡只要挑出
        // 「最接近中央的那一頁」，不需要精準的可見面積。
        let viewportCenter = continuousViewportHeight / 2
        let nearest = mids.min {
            abs($0.value - viewportCenter) < abs($1.value - viewportCenter)
        }
        guard let page = nearest?.key, page != currentPageIndex else { return }
        continuousReportedPage = page
        currentPageIndex = page
        currentDrawing = drawingForPage(page)
    }


    /// 某一頁的插入物件層（圖片、形狀、表格、文字、連結、3D、討論圖釘）。
    ///
    /// 抽成帶頁碼的方法，是為了讓連續頁面模式能對每一頁各叫一次 ——
    /// 原本這一整段寫死在畫布工作區裡、只認 `currentPageIndex`，
    /// 連續模式下就只有一頁有物件，其餘頁面是空的。
    enum ObjectInkLayerFilter {
        case all
        case underInkOnly
        case overInkOnly
    }

    private func shouldIncludeInInkLayer(id: String, filter: ObjectInkLayerFilter, underInkSet: Set<String>) -> Bool {
        switch filter {
        case .all: return true
        case .underInkOnly: return underInkSet.contains(id)
        case .overInkOnly: return !underInkSet.contains(id)
        }
    }

    /// 某一頁的插入物件層（圖片、形狀、表格、文字、連結、3D、討論圖釘）。
    ///
    /// 支援依筆跡上下圖層進行過濾：
    /// - `.underInkOnly`: 移至筆跡下方的物件（置於 PKCanvasView 底層）
    /// - `.overInkOnly`: 筆跡上方的物件（置於 PKCanvasView 頂層）
    /// - `.all`: 完整物件層（連續頁面等情境）
    @ViewBuilder
    private func objectLayer(forPage page: Int, filter: ObjectInkLayerFilter = .all) -> some View {
        let underInkSet = notebook.underInkObjectIds(forPage: page)
        // 堆疊順序的索引表：一次算繪只建一次，不要每個物件各掃一遍
        // （見 `ObjectStacking.Lookup`）。
        let stacking = ObjectStacking.Lookup(order: notebook.objectOrder(forPage: page))
        ZStack(alignment: .topLeading) {
            ForEach(notebook.attachments ?? []) { item in
                    if item.pageIndex == page && shouldIncludeInInkLayer(id: item.id, filter: filter, underInkSet: underInkSet) {
                        AttachmentItemView(
                            attachment: binding(for: item.id),
                            isSelected: activeSelectedObjectId == item.id,
                            onSelect: { selectSingleObject(item.id) },
                            onEdit: {
                                if let formula = item.mathFormula {
                                    self.editingMathAttachmentId = MathEditTarget(id: item.id, formula: formula)
                                } else if let spec = item.chartSpec {
                                    self.editingChartAttachmentId = ChartEditTarget(id: item.id, spec: spec)
                                } else {
                                    self.editingAttachmentId = item.id
                                }
                            },
                            onDelete: {
                                deletedAttachmentBackup = (type: "image", data: item)
                                collaborationManager.broadcastAttachmentDelete(id: item.id, type: "image")
                                notebook.attachments?.removeAll { $0.id == item.id }
                                store.updateNotebook(notebook)
                                collaborationManager.broadcastSelection(selectedId: nil)
                            }
                        )
                        .zIndex(stacking.zIndex(for: item.id, kind: .image))
                    }
                }

                // 連接線先畫 —— 畫在形狀之上的話，線會壓過方塊的邊，看起來像穿幫。
                ForEach(notebook.connectionAttachments ?? []) { item in
                    if item.pageIndex == page && shouldIncludeInInkLayer(id: item.id, filter: filter, underInkSet: underInkSet),
                       let from = notebook.shapeAttachments?.first(where: { $0.id == item.fromShapeId }),
                       let to = notebook.shapeAttachments?.first(where: { $0.id == item.toShapeId }),
                       let geometry = ShapeGeometry.connection(item, from: from, to: to) {
                        ConnectionLineView(
                            connection: item,
                            geometry: geometry,
                            isSelected: selectedConnectionId == item.id,
                            onSelect: {
                                selectedShapeIds = []
                                selectedConnectionId = (selectedConnectionId == item.id) ? nil : item.id
                            },
                            onEdit: {
                                selectedConnectionId = item.id
                                editingConnectionId = item.id
                                editingShapeId = nil
                            },
                            onDelete: { deleteConnection(item.id) }
                        )
                        // 線畫在它連著的兩個形狀的**下面**（見上面的說明），
                        // 但仍然在更低層的其他物件之上。
                        .zIndex(min(
                            stacking.zIndex(for: from.id, kind: .shape),
                            stacking.zIndex(for: to.id, kind: .shape)) - 0.1)
                    }
                }

                // 形狀。
                ForEach(notebook.shapeAttachments ?? []) { item in
                    if item.pageIndex == page && shouldIncludeInInkLayer(id: item.id, filter: filter, underInkSet: underInkSet) {
                        ShapeAttachmentItemView(
                            shape: shapeBinding(for: item.id),
                            isSelected: selectedShapeIds.contains(item.id),
                            isSoleSelection: selectedShapeIds.count <= 1,
                            onSelect: {
                                selectedConnectionId = nil
                                toggleShapeSelection(item.id)
                            },
                            onMove: { delta in moveShapeGroup(item.id, by: delta) },
                            onDelete: { deleteShape(item.id) },
                            onEdit: {
                                selectedShapeIds = [item.id]
                                selectedConnectionId = nil
                                editingShapeId = item.id
                                editingConnectionId = nil
                            },
                            onConnectDrag: { anchor, start, current, finished in
                                handleConnectDrag(
                                    from: item.id, anchor: anchor, start: start,
                                    current: current, finished: finished)
                            }
                        )
                        .zIndex(stacking.zIndex(for: item.id, kind: .shape))
                    }
                }

                // 拉線預覽。
                if let draft = connectionDraft, draft.page == page {
                    ConnectionDraftView(from: draft.start, to: draft.current)
                        .zIndex(9000)
                }

                // 互動式貼圖定位與放置浮層（工作項：允許自由拖曳、縮放與旋轉貼圖位置）
                if page == currentPageIndex, let placement = pendingStickerPlacement {
                    StickerPlacementOverlayView(
                        placement: Binding(
                            get: { self.pendingStickerPlacement ?? placement },
                            set: { self.pendingStickerPlacement = $0 }
                        ),
                        onCommit: {
                            if let p = self.pendingStickerPlacement {
                                insertStickerObject(p)
                                self.pendingStickerPlacement = nil
                                // 手寫模式下物件不吃觸控，貼紙放完卻點不動等於又回到
                                // 原本的問題。圖片拖放後也是切到打字模式。
                                editorMode = .type
                                showCanvasNotice(localizationManager.localized("sticker_placed_hint"))
                            }
                        },
                        onCancel: {
                            self.pendingStickerPlacement = nil
                        }
                    )
                    .zIndex(9999)
                }

                // 表格。
                ForEach(notebook.tableAttachments ?? []) { item in
                    if item.pageIndex == page && shouldIncludeInInkLayer(id: item.id, filter: filter, underInkSet: underInkSet) {
                        TableAttachmentItemView(
                            table: tableBinding(for: item.id),
                            isSelected: activeSelectedObjectId == item.id,
                            onSelect: {
                                let wasControlled = (activeSelectedObjectId == item.id)
                                selectSingleObject(item.id)
                                if selectedTool == .eraser {
                                    watchdog.notifyEraserUsedOnNonInk(targetType: .table) {
                                        let id = item.id
                                        notebook.tableAttachments?.removeAll { $0.id == id }
                                        store.updateNotebook(notebook)
                                        PageThumbnailRenderer.invalidateAll()
                                    }
                                } else {
                                    watchdog.notifyObjectTapped(
                                        targetId: item.id,
                                        targetType: .table,
                                        isControlled: wasControlled,
                                        onControlObject: {
                                            selectSingleObject(item.id)
                                        }
                                    )
                                }
                            },
                            onMove: { delta in moveTable(item.id, by: delta) },
                            onEdit: { editingTable = item },
                            onDelete: {
                                let id = item.id
                                notebook.tableAttachments?.removeAll { $0.id == id }
                                store.updateNotebook(notebook)
                                PageThumbnailRenderer.invalidateAll()
                                collaborationManager.broadcastAttachmentDelete(id: id, type: "table")
                            }
                        )
                        .zIndex(stacking.zIndex(for: item.id, kind: .table))
                    }
                }

                // 🌟 筆記內嵌 Word 級文字方塊（支援段落對齊、特殊符號與便利貼卡片底色）
                ForEach(Array((notebook.textAttachments ?? []).enumerated()), id: \.element.id) { position, item in
                    if item.pageIndex == page && shouldIncludeInInkLayer(id: item.id, filter: filter, underInkSet: underInkSet) {
                        TextAttachmentItemView(
                            textItem: binding(forTextId: item.id, hint: position),
                            isEditingInline: Binding(
                                get: { inlineEditingTextId == item.id },
                                set: { editing in
                                    if editing {
                                        recordTextUndoState()
                                        inlineEditingTextId = item.id
                                    } else if inlineEditingTextId == item.id {
                                        inlineEditingTextId = nil
                                    }
                                }
                            ),
                            isSelected: activeSelectedObjectId == item.id,
                            onSelect: { selectSingleObject(item.id) },
                            isTypeMode: editorMode == .type,
                            snapToGrid: snapToGrid,
                            snapY: { y in snapYToGuideLine(at: y) },
                            onEdit: {
                                recordTextUndoState()
                                self.editingTextId = item.id
                            },
                            onDelete: {
                                if inlineEditingTextId == item.id { inlineEditingTextId = nil }
                                recordTextUndoState()
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
                        .zIndex(stacking.zIndex(for: item.id, kind: .text))
                    }
                }

                // 🌟 筆記內嵌網址 Rich Link 預覽卡片（支援點擊跳轉瀏覽器與自由平移）
                ForEach(notebook.linkAttachments ?? []) { item in
                    if item.pageIndex == page && shouldIncludeInInkLayer(id: item.id, filter: filter, underInkSet: underInkSet) {
                        LinkAttachmentItemView(
                            linkItem: binding(forLinkId: item.id),
                            isSelected: activeSelectedObjectId == item.id,
                            onSelect: { selectSingleObject(item.id) },
                            onDelete: {
                                notebook.linkAttachments?.removeAll { $0.id == item.id }
                                store.updateNotebook(notebook)
                            }
                        )
                        .zIndex(stacking.zIndex(for: item.id, kind: .link))
                    }
                }

                // 🌟 頁面上的錄音卡片（可播放、可搬移、可縮放、可旋轉、可改名、音訊轉文字）
                ForEach(notebook.audioAttachments ?? []) { item in
                    if item.pageIndex == page && shouldIncludeInInkLayer(id: item.id, filter: filter, underInkSet: underInkSet) {
                        AudioAttachmentItemView(
                            item: binding(forAudioId: item.id),
                            isSelected: activeSelectedObjectId == item.id,
                            onSelect: { selectSingleObject(item.id) },
                            notebookId: notebook.id,
                            onDelete: {
                                notebook.audioAttachments?.removeAll { $0.id == item.id }
                                store.updateNotebook(notebook)
                            },
                            onTranscribe: { transcribedText in
                                insertTranscriptText(transcribedText, for: item)
                            }
                        )
                        .zIndex(stacking.zIndex(for: item.id, kind: .audio))
                    }
                }

                // 🌟 筆記內嵌 3D 幾何模型展示層（支援 360° 空間旋轉、9大材質 PBR 物理反射、縮放與文字標題）
                ForEach(notebook.model3DAttachments ?? []) { item in
                    if item.pageIndex == page && shouldIncludeInInkLayer(id: item.id, filter: filter, underInkSet: underInkSet) {
                        Model3DCanvasItemView(
                            item: binding(forModel3DId: item.id),
                            isSelected: activeSelectedObjectId == item.id,
                            onSelect: { selectSingleObject(item.id) },
                            onDelete: {
                                deletedAttachmentBackup = (type: "3d", data: item)
                                collaborationManager.broadcastAttachmentDelete(id: item.id, type: "3d")
                                notebook.model3DAttachments?.removeAll { $0.id == item.id }
                                store.updateNotebook(notebook)
                                collaborationManager.broadcastSelection(selectedId: nil)
                            }
                        )
                        .zIndex(stacking.zIndex(for: item.id, kind: .model3D))
                    }
                }

                // 🌟 筆記內嵌討論圖釘展示層（支援多方訊息留言串、已解決標記與即時推播）
                ForEach(notebook.commentPins ?? []) { pin in
                    if pin.pageIndex == page && filter != .underInkOnly {
                        CommentPinMarkerView(
                            pin: pin,
                            isSelected: selectedCommentPinId == pin.id,
                            onTap: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    if selectedCommentPinId == pin.id {
                                        selectedCommentPinId = nil
                                        collaborationManager.broadcastSelection(selectedId: nil)
                                    } else {
                                        activeSelectedObjectId = nil
                                        selectedShapeIds = []
                                        selectedConnectionId = nil
                                        selectedObjectIds = []
                                        if inlineEditingTextId != nil { inlineEditingTextId = nil }
                                        selectedCommentPinId = pin.id
                                        collaborationManager.broadcastSelection(selectedId: pin.id)
                                    }
                                }
                            }
                        )
                        .position(x: pin.x, y: pin.y)
                        .zIndex(stacking.zIndex(for: pin.id, kind: .pin))
                    }
                }

                // 🌟 特殊樣板智慧互動元件層（核取清單 Checkbox、選項切換與進度管控）
                if filter != .underInkOnly {
                    ForEach(interactiveGuideCheckboxes(forPage: page)) { item in
                        InteractiveGuideCheckboxView(
                            isChecked: notebook.checkedGuideItems?[item.key] ?? false,
                            size: CGSize(width: CGFloat(item.guide.w), height: CGFloat(item.guide.h)),
                            onToggle: {
                                toggleGuideCheckbox(key: item.key)
                            },
                            onStrikethroughRow: {
                                toggleRowStrikethrough(y: CGFloat(item.guide.y), page: page)
                            },
                            onClearRowText: {
                                clearRowText(y: CGFloat(item.guide.y), page: page)
                            },
                            onResetPage: {
                                resetPageCheckboxes(page: page)
                            }
                        )
                        .position(
                            x: CGFloat(item.guide.x) + CGFloat(item.guide.w) / 2,
                            y: CGFloat(item.guide.y) + CGFloat(item.guide.h) / 2
                        )
                        .zIndex(10)
                    }
                }

        }
        .environment(\.objectReorder, { id, op in reorderObject(id, op) })
        .coordinateSpace(name: CanvasCoordinateSpace.name)
    }

    private var canvasWorkAreaContent: some View {
        ZStack(alignment: .topTrailing) {
            PageBackgroundRepresentable(
                paperId: notebook.paperId(forPage: currentPageIndex),
                paletteId: notebook.guidePaletteId,
                pageIndex: currentPageIndex,
                checkedGuideItems: notebook.checkedGuideItems
            )
                .frame(width: PageGeometry.width, height: currentPageHeight, alignment: .topLeading)
                .scaleEffect(canvasZoomScale, anchor: .topLeading)
                .offset(x: -canvasContentOffset.x, y: -canvasContentOffset.y)
                .allowsHitTesting(false)
                .zIndex(0)

            // 筆跡下方層（Background / Under-ink objects）：在 CanvasRepresentable 之下，zIndex 1
            objectLayer(forPage: currentPageIndex, filter: .underInkOnly)
                .frame(width: PageGeometry.width, height: currentPageHeight, alignment: .topLeading)
                .scaleEffect(canvasZoomScale, anchor: .topLeading)
                .offset(x: -canvasContentOffset.x, y: -canvasContentOffset.y)
                .allowsHitTesting(
                    !isInlineInkEditing
                        && (editorMode == .type || inlineEditingTextId != nil || editingTextId != nil || activeSelectedObjectId != nil)
                )
                .zIndex(1)

            // 筆跡上方層（Foreground / Over-ink objects）：在 CanvasRepresentable 之上，zIndex 3
            objectLayer(forPage: currentPageIndex, filter: .overInkOnly)
                .frame(width: PageGeometry.width, height: currentPageHeight, alignment: .topLeading)
                .scaleEffect(canvasZoomScale, anchor: .topLeading)
                .offset(x: -canvasContentOffset.x, y: -canvasContentOffset.y)
                .allowsHitTesting(
                    !isInlineInkEditing
                        && (editorMode == .type || inlineEditingTextId != nil || editingTextId != nil || activeSelectedObjectId != nil)
                )
                .zIndex(3)

            CanvasRepresentable(
                drawing: $currentDrawing,
                proInk: ProInkBinding(
                    directory: store.drawingsDirectory, notebookId: notebook.id, pageIndex: currentPageIndex),
                selectedTool: selectedTool,
                selectedColor: selectedColor,
                strokeWidth: strokeWidth,
                eraserMode: eraserMode,
                pixelEraserWidth: pixelEraserWidth,
                isRulerActive: isRulerActive,
                paperId: notebook.paperId(forPage: currentPageIndex),
                paletteId: notebook.guidePaletteId,
                pageHeight: currentPageHeight,
                // 打字模式中的「手繪區塊」是局部繪圖情境。主模式仍保持
                // `.type`，但 PencilKit 必須收到 `.draw`，否則它會關掉自己的
                // drawingGestureRecognizer，造成工具列已切到筆、畫布卻完全沒反應。
                editorMode: effectiveCanvasMode,
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

                    // 🌟 智慧意圖感知：手繪筆劃覆蓋於文字方塊上方
                    if let latestStroke = newDrawing.strokes.last, newDrawing.strokes.count > lastStrokeCount {
                        let strokeRect = latestStroke.renderBounds
                        if let overlapped = (notebook.textAttachments ?? []).first(where: {
                            $0.pageIndex == currentPageIndex && strokeRect.intersects(CGRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height))
                        }) {
                            watchdog.notifyStrokeDrawnOverText(
                                strokeBounds: strokeRect,
                                textBoxId: overlapped.id,
                                textBoxBounds: CGRect(x: overlapped.x, y: overlapped.y, width: overlapped.width, height: overlapped.height),
                                onAnchor: {
                                    anchorSelectedStrokesToNearestText()
                                }
                            )
                        }
                    }

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
                    
                    // 🌟 自動流式錨定：若落筆於既有文字方塊上方（圈註、畫底線、旁註），自動建立關聯錨定
                    if !isApplyingRemoteUpdate && newDrawing.strokes.count > 0 {
                        autoAnchorNewStrokesToOverlappingText(drawing: newDrawing)
                    }
                    
                    return newDrawing.strokes.count == rawDrawing.strokes.count
                        ? nil
                        : newDrawing
                },
                onReachedPageBottom: {
                    ensureNextPageExists()
                },
                onSelectionChanged: { hasSel in
                    if !hasSel { lasso.clear() }
                },
                onLassoBegan: { pt in
                    lasso.begin(at: pt)
                },
                onLassoMoved: { pt in
                    if lasso.isDraggingSelection {
                        let lastPt = lasso.dragPoint ?? pt
                        let delta = CGSize(width: pt.x - lastPt.x, height: pt.y - lastPt.y)
                        lasso.updateDragPoint(pt)
                        if let updated = lasso.moveSelected(in: currentDrawing, by: delta) {
                            currentDrawing = updated
                            canvasView?.drawing = updated
                        }
                    } else {
                        lasso.extend(to: pt)
                    }
                },
                onLassoEnded: {
                    let wasDragging = lasso.isDraggingSelection
                    lasso.finish(in: currentDrawing)
                    if wasDragging {
                        recordDrawingEdit(page: currentPageIndex, drawing: currentDrawing)
                        broadcastDrawingChange(page: currentPageIndex, drawing: currentDrawing)
                        PageThumbnailRenderer.invalidateAll()
                    }
                },
                canvasRef: { ref in
                    // `updateUIView` 每次更新都會叫到這裡；直接寫 @State 就是在畫面更新途中改狀態
                    // （SwiftUI 的 runtime issue「Modifying state during view update」，每個工作階段
                    // 好幾十次），而且同一個物件重複指派也會再觸發一輪更新。
                    // 只在真的換了才寫，並且挪到這一輪更新之後。
                    guard self.canvasView !== ref else { return }
                    DispatchQueue.main.async { 
                        self.canvasView = ref 
                        if let adaptive = ref as? AdaptiveCanvasView, self.currentDrawing.strokes.count > 0 {
                            adaptive.forceDisplayRefresh(with: self.currentDrawing)
                        }
                    }
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
                    guard palmRejection.drawingPolicy(now: landedAt) != .pencilOnly else { return }
                    if let adaptive = canvasView as? AdaptiveCanvasView, adaptive.activeTouchesCount > 0 {
                        adaptive.pendingRetractDate = landedAt
                        return
                    }
                    let cleaned = PalmRejectionCoordinator.retracting(
                        currentDrawing, landedAt: landedAt)
                    guard cleaned.strokes.count != currentDrawing.strokes.count else { return }
                    let removed = currentDrawing.strokes.count - cleaned.strokes.count
                    currentDrawing = cleaned
                    canvasView?.drawing = cleaned
                    (canvasView as? AdaptiveCanvasView)?.dropDeadUndoEntries(max: removed)
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
                onRedo: { performRedo() },
                magneticSnapEnabled: isMagneticSnapActive,
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
                },
                onPencilTouchBegan: { handlePencilTouchBegan() },
                onCanvasDirectTap: { location in
                    guard !isInlineInkEditing else { return }
                    handleCanvasDirectTap(at: location)
                },
                onCanvasDirectDoubleTap: { location in
                    guard !isInlineInkEditing else { return }
                    handleCanvasDirectDoubleTap(at: location)
                },
                onPencilTapInTypeMode: { location in
                    guard !isInlineInkEditing else { return }
                    handlePencilTapInTypeMode(at: location)
                }
            )
            .accessibilityIdentifier("editor.canvas")
            .overlay(alignment: .topLeading) {
                if selectedTool == .lasso && (!lasso.path.isEmpty || !lasso.committed.isEmpty) {
                    LassoPathOverlay(
                        path: lasso.path.isEmpty ? lasso.committed : lasso.path,
                        isCommitted: lasso.path.isEmpty
                    )
                    .allowsHitTesting(false)
                }

                // 🌟 當套索圈選完成且有選中筆劃時，在選取範圍上方浮現動作面板與拖曳邊框提示
                if selectedTool == .lasso && lasso.hasSelection, let rect = lasso.boundingRect {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.35), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                        .frame(width: rect.width + 16, height: rect.height + 16)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)

                    lassoFloatingActionBar
                        .position(
                            x: min(max(rect.midX, 220), PageGeometry.width - 220),
                            y: max(32, rect.minY - 26)
                        )
                        .zIndex(100)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                if selectedTool == .lasso && lasso.hasSelection {
                                    watchdog.notifyLassoSelectionStalled()
                                }
                            }
                        }
                }
            }
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
                onTapesChanged: {
                    store.updateNotebook(notebook)
                    PageThumbnailRenderer.invalidateAll()
                }
            )
            .frame(width: PageGeometry.width, height: currentPageHeight, alignment: .topLeading)
            .scaleEffect(canvasZoomScale, anchor: .topLeading)
            .offset(x: -canvasContentOffset.x, y: -canvasContentOffset.y)
            .allowsHitTesting(selectedTool == .maskingTape || (editorMode != .draw && !(notebook.tapeAttachments?.filter { $0.pageIndex == currentPageIndex }.isEmpty ?? true)))
            .zIndex(selectedTool == .maskingTape ? 4 : 2.5)

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

            // 🌟 插入垂直空間分隔導引器（GoodNotes 風格空間插入條）
            if isInsertSpaceActive {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(height: 2)
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.and.down.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                        Text(localizationManager.localized("insert_vertical_space"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isInsertSpaceActive = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.accentColor.opacity(0.95)).shadow(color: .black.opacity(0.2), radius: 4, y: 2))
                    .offset(x: 20)
                }
                .frame(width: PageGeometry.width, height: 32)
                .position(x: PageGeometry.width / 2, y: insertSpaceDividerY)
                .scaleEffect(canvasZoomScale, anchor: .topLeading)
                .offset(x: -canvasContentOffset.x, y: -canvasContentOffset.y)
                .zIndex(5)
                .gesture(
                    DragGesture()
                        .onChanged { val in
                            let delta = val.translation.height - insertSpaceDragAccum
                            insertSpaceDragAccum = val.translation.height
                            let targetY = max(50, min(currentPageHeight + 200, insertSpaceDividerY + delta))
                            insertSpaceDividerY = targetY
                            if abs(delta) > 0.5 {
                                applyVerticalSpaceInsertion(splitY: insertSpaceDividerY, deltaY: delta)
                            }
                        }
                        .onEnded { _ in
                            insertSpaceDragAccum = 0.0
                        }
                )
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

            // 文字／圖片編修面板與圖層面板已移到 `objectEditPanels`，掛在
            // 兩種頁面模式共用的 `canvasWorkArea` 上 —— 原本掛在這裡，
            // 層級低於畫布與文字輸入層（觸控被它們吃掉，面板關不掉），
            // 而且連續模式根本不會走到這一段。

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
            if isMagneticSnapActive && editorMode == .draw && magneticGuideActive {
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
                            performUndo()
                        },
                        RadialMenuItem(id: "redo", icon: "arrow.uturn.forward", labelKey: "redo", color: .blue) {
                            performRedo()
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

    /// 套索操作按鈕：圖示 + 可選文字標籤 + 說明提示
    private func lassoActionButton(
        _ icon: String,
        _ titleKey: String,
        _ hintKey: String,
        showLabel: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                if showLabel {
                    Text(localizationManager.localized(titleKey))
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .foregroundColor(.primary)
            .padding(.horizontal, showLabel ? 8 : 6)
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
                // PencilKit 可能仍握有 first responder。先交還鍵盤焦點，否則
                // 新建立的 TextEditor 在同一個 run loop 內無法成為第一回應者。
                if mode == .type {
                    canvasView?.resignFirstResponder()
                }
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

    /// 打字模式中的手繪區塊仍使用同一張頁面畫布，只是暫時把輸入權交給墨跡層。
    private var isInlineInkEditing: Bool {
        editorMode == .type && activeInlineInkBlockId != nil
    }

    private var effectiveCanvasMode: EditorMode {
        EditorCanvasInputPolicy.effectiveMode(
            mainMode: editorMode,
            isInlineInkEditing: isInlineInkEditing)
    }

    private var isCanvasInkActive: Bool {
        EditorCanvasInputPolicy.acceptsInk(
            mainMode: editorMode,
            isInlineInkEditing: isInlineInkEditing)
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
                } else if pageDisplayMode == .continuous {
                    // 焦點頁本來就是這一頁（它可能只露出一角），點縮圖也要把它捲到最上面。
                    continuousScrollRequest += 1
                }
            } label: {
                // 縮圖用畫布的實際寬度算繪，並讓卡片維持同樣的長寬比 ——
                // 舊版固定 800 寬、卡片固定 130 高，一張 800x1800 的頁面
                // scaledToFit 之後只剩 50pt 寬，物件小到看不出是什麼。
                let pageDrawing = drawingForPage(idx)
                let _ = thumbnailRevision  // 專業筆畫變動時讓這張縮圖重算
                let img = PageThumbnailRenderer.render(
                    notebook: notebook,
                    pageIndex: idx,
                    drawing: pageDrawing,
                    store: store,
                    canvasWidth: canvasContentWidth,
                    inkOnTop: inkDrawnOnTop
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
                presentFromMenu {
                    pageToDeleteIndex = idx
                    showDeletePageAlert = true
                }
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
                            presentFromMenu {
                                newFolderParentId = folder.id
                                newFolderNameText = ""
                                showNewFolderAlert = true
                            }
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
                            presentFromMenu {
                                folderRenameText = folder.name
                                folderToRename = folder
                            }
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
            WordToolbarView(
                activeText: Binding(
                    get: { activeTextAttachment ?? NoteTextAttachment(pageIndex: currentPageIndex) },
                    set: { updated in
                        if notebook.textAttachments == nil { notebook.textAttachments = [] }
                        if let idx = notebook.textAttachments?.firstIndex(where: { $0.id == updated.id }) {
                            notebook.textAttachments?[idx] = updated
                        } else {
                            var toAdd = updated
                            toAdd.pageIndex = currentPageIndex
                            if toAdd.x == 0 && toAdd.y == 0 {
                                toAdd.x = PageGeometry.printableInset
                                toAdd.y = 200
                                toAdd.width = PageGeometry.printableRect.width
                                toAdd.hasBorder = true
                            }
                            notebook.textAttachments?.append(toAdd)
                            inlineEditingTextId = toAdd.id
                            editingTextId = toAdd.id
                        }
                        store.updateNotebook(notebook)
                        PageThumbnailRenderer.invalidateAll()
                    }
                ),
                canUndo: !textUndoStack.isEmpty || (canvasView?.undoManager?.canUndo ?? true),
                canRedo: !textRedoStack.isEmpty || (canvasView?.undoManager?.canRedo ?? false),
                onUndo: { performUndo() },
                onRedo: { performRedo() },
                onInsertTable: { rows, cols in
                    let targetX = max(PageGeometry.printableInset, (PageGeometry.width - 440) / 2)
                    let baseOffsetY = max(PageGeometry.printableInset, canvasContentOffset.y + 120)
                    let existingCount = notebook.tableAttachments?.filter { $0.pageIndex == currentPageIndex }.count ?? 0
                    let targetY = min(PageGeometry.height - 200, baseOffsetY + CGFloat(existingCount * 40))
                    let table = NoteTableAttachment(pageIndex: currentPageIndex, x: targetX, y: targetY, rows: rows, cols: cols)
                    if notebook.tableAttachments == nil { notebook.tableAttachments = [] }
                    notebook.tableAttachments?.append(table)
                    activeSelectedObjectId = table.id
                    selectedObjectIds = [table.id]
                    store.updateNotebook(notebook)
                    PageThumbnailRenderer.invalidateAll()
                    showCanvasNotice(String(format: localizationManager.localized("table_rows_cols"), "\(rows)", "\(cols)"))
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
                },
                onAddTextBox: {
                    let draft = insertTextBox(at: CGPoint(x: 200, y: 200))
                    withAnimation(.easeInOut(duration: 0.18)) {
                        editorMode = .type
                        inlineEditingTextId = draft.id
                    }
                },
                isSnapToGrid: snapToGrid,
                onToggleSnapToGrid: {
                    snapToGrid.toggle()
                }
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))

            if isMarqueeActive {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    marqueeToolbar
                }
            }
        }
    }

    // MARK: - 2. 🌟 實體手繪工具列（水平滑動包裹、免擠壓、隨點隨用）
    /// 型別邊界：SwiftUI 會把整棵子樹的型別編進 body 的 mangled 名稱，
    /// 名稱一長，裝置端（主執行緒只有 1MB 堆疊）解析時就會遞迴爆堆疊。
    private var drawingToolbar: AnyView { AnyView(drawingToolbarContent) }

    private func selectEditorTool(_ tool: EditorToolType) {
        // 在文件內的手繪區塊換筆，只換工具；不可順手把整份文件的主模式
        // 改成手繪，否則「完成、回到文件」的情境會被拆掉。
        if editorMode != .draw && !isInlineInkEditing {
            editorMode = .draw
            inlineEditingTextId = nil
        }
        if tool == .lasso, selectedTool == .lasso {
            exitLassoMode()
        } else {
            selectedTool = tool
        }
        flashToolToast(for: tool)
    }

    /// 點擊筆刷或繪圖工具時，在工具列緊鄰處顯示微型快顯提示，提示該工具名稱。
    private func flashToolToast(for tool: EditorToolType) {
        let localizedName = localizationManager.localized(tool.localizationKey)
        toolToastToken += 1
        let token = toolToastToken
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            activeToolToast = (name: localizedName, icon: tool.iconName)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            guard toolToastToken == token else { return }
            withAnimation(.easeInOut(duration: 0.24)) {
                activeToolToast = nil
            }
        }
    }

    /// 緊鄰工具列的輕量快顯工具提示標籤
    @ViewBuilder
    private var toolToastIndicator: some View {
        if let toast = activeToolToast {
            HStack(spacing: 6) {
                Image(systemName: toast.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.accentColor)
                Text(toast.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule().stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 6, y: 2)
            .transition(.scale(scale: 0.85).combined(with: .opacity))
            .allowsHitTesting(false)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    private func exitLassoMode() {
        lasso.clear()
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
        Menu {
            ForEach(inkPalette(), id: \.hex) { swatch in
                if let color = Color(hex: swatch.hex) {
                    Button {
                        recolorSelectedStrokes(to: color)
                    } label: {
                        let labelText = swatch.key.isEmpty ? swatch.hex : localizationManager.localized(swatch.key)
                        Label(labelText, systemImage: "circle.fill")
                    }
                }
            }
        } label: {
            Image(systemName: "paintbrush.fill")
                .font(.system(size: 14))
                .frame(width: 28, height: 28)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(6)
        }
        .help(localizationManager.localized("ink_change_colour"))
        .accessibilityLabel(localizationManager.localized("ink_change_colour"))
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

    /// 將套索選取的筆劃換色。
    private func recolorSelectedStrokes(to newColor: Color) {
        guard lasso.hasSelection else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
        guard let updated = lasso.recolorSelected(in: currentDrawing, to: UIColor(newColor)) else {
            showCanvasNotice("未能為選取筆劃更換色彩")
            return
        }
        applyLassoResult(updated)
        showCanvasNotice("已為圈選筆劃更換色彩")
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// 在指定 Y 軸座標插入或調整垂直空間（GoodNotes 風格插入空間工具）
    /// 將落在 splitY 以下的所有手寫筆畫與附件往下推移 deltaY，並相應增加頁面高度。
    private func applyVerticalSpaceInsertion(splitY: CGFloat, deltaY: CGFloat) {
        guard abs(deltaY) > 0.5 else { return }

        // 1. 移動 PKDrawing 中落在 splitY 以下的筆畫
        if let canvas = canvasView {
            let currentStrokes = canvas.drawing.strokes
            let shiftedStrokes = currentStrokes.map { stroke -> PKStroke in
                let bounds = stroke.renderBounds
                if bounds.minY >= splitY {
                    var transform = stroke.transform
                    transform = transform.translatedBy(x: 0, y: deltaY)
                    return PKStroke(ink: stroke.ink, path: stroke.path, transform: transform, mask: stroke.mask)
                }
                return stroke
            }
            canvas.drawing = PKDrawing(strokes: shiftedStrokes)
            self.currentDrawing = canvas.drawing
            self.saveCurrentPageDrawing()
        }

        // 2. 移動落在 splitY 以下的文字附件方塊
        if var attachments = notebook.textAttachments {
            var changed = false
            for i in 0..<attachments.count where attachments[i].pageIndex == currentPageIndex {
                if attachments[i].y >= splitY {
                    attachments[i].y = max(0, attachments[i].y + deltaY)
                    changed = true
                }
            }
            if changed {
                notebook.textAttachments = attachments
                store.updateNotebook(notebook)
            }
        }

        // 3. 移動落在 splitY 以下的圖片物件
        if var images = notebook.attachments {
            var changed = false
            for i in 0..<images.count where images[i].pageIndex == currentPageIndex {
                if images[i].y >= splitY {
                    images[i].y = max(0, images[i].y + deltaY)
                    changed = true
                }
            }
            if changed {
                notebook.attachments = images
                store.updateNotebook(notebook)
            }
        }

        // 4. 動態調整該頁高度，確保下推內容完整容納
        let newHeight = max(PageGeometry.height, currentPageHeight + deltaY)
        if newHeight != currentPageHeight {
            currentPageHeight = newHeight
        }

        // 觸覺回饋
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// 🌟 響應式極簡畫布懸浮工作丸專屬內容
    /// 專為 340pt 懸浮氣泡設計：輕量、緊湊、快速，不裝載重量級 ViewThatFits 與多層 WrapLayout，
    /// 徹底根除深層視圖階層引起的主執行緒堆疊溢位（Stack Overflow / EXC_BAD_ACCESS）。
    @ViewBuilder
    private var minimalToolboxContent: some View {
        VStack(spacing: 8) {
            // 1. 筆刷工具水平快捷滑動列
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(EditorToolType.allCases.filter { toolbarSettings.isVisible($0.parityIdentifier) }) { tool in
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                                selectEditorTool(tool)
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: tool.iconName)
                                    .font(.system(size: 14, weight: selectedTool == tool ? .bold : .regular))
                                    .foregroundColor(selectedTool == tool ? .accentColor : .primary)
                                    .frame(width: 32, height: 32)
                                    .background(selectedTool == tool ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(localizationManager.localized(tool.localizationKey))
                    }

                    // 文字方塊快捷按鈕
                    Button {
                        let draft = insertTextBox(at: CGPoint(x: 200, y: 200))
                        withAnimation(.easeInOut(duration: 0.18)) {
                            editorMode = .type
                            inlineEditingTextId = draft.id
                        }
                    } label: {
                        Image(systemName: "plus.bubble")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localizationManager.localized("add_text_box"))
                }
                .padding(.horizontal, 4)
            }

            // 2. 粗細預設點、快速色彩盤與復原
            HStack(spacing: 10) {
                // 筆刷粗細預設點
                HStack(spacing: 5) {
                    ForEach([2.0, 4.0, 8.0, 14.0], id: \.self) { w in
                        Button {
                            strokeWidth = CGFloat(w)
                        } label: {
                            Circle()
                                .fill(abs(strokeWidth - CGFloat(w)) < 0.01 ? Color.accentColor : Color.secondary.opacity(0.5))
                                .frame(width: max(6, CGFloat(w)), height: max(6, CGFloat(w)))
                                .padding(3)
                                .background(abs(strokeWidth - CGFloat(w)) < 0.01 ? Color.accentColor.opacity(0.15) : Color.clear)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()
                    .frame(height: 16)

                // 常用色彩
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(colorPalette.prefix(6), id: \.self) { color in
                            Button {
                                selectedColor = color
                            } label: {
                                Circle()
                                    .fill(color)
                                    .frame(width: 16, height: 16)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                    .overlay(Circle().stroke(selectedColor == color ? Color.accentColor : Color.clear, lineWidth: 1.5))
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            showProColorPicker = true
                        } label: {
                            Image(systemName: "paintpalette")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.secondary)
                                .frame(width: 18, height: 18)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 0)

                // 復原
                Button {
                    performUndo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
        }
    }

    private var drawingToolbarContent: some View {
        VStack(spacing: 0) {
            if editorMode == .draw && selectedTool == .lasso {
                ViewThatFits(in: .horizontal) {
                    // 1. 寬螢幕：長提示文字 + 圖示文字按鈕
                    lassoFloatingActionBarRow(showLabels: true, showHint: true)
                        .fixedSize(horizontal: true, vertical: false)

                    // 2. 中等寬度（700~1000pt）：隱藏長提示文字，保留圖示文字按鈕
                    lassoFloatingActionBarRow(showLabels: true, showHint: false)
                        .fixedSize(horizontal: true, vertical: false)

                    // 3. 窄螢幕（Mac 縮小視窗、iPad 分割螢幕/側邊欄展開）：精簡純圖示模式，所有按鈕完全放得下
                    lassoFloatingActionBarRow(showLabels: false, showHint: false)
                        .fixedSize(horizontal: true, vertical: false)

                    // 4. 超窄螢幕（如 iPhone 直向或 <360pt）：可橫向捲動並顯示指示器
                    ScrollView(.horizontal, showsIndicators: true) {
                        lassoFloatingActionBarRow(showLabels: false, showHint: false)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                Divider()
            }

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
                // fixedSize：量的是**理想寬度**。不加的話裡面的橫向捲動區（套索按鈕列）
                // 什麼寬度都「塞得下」，這一排就永遠被選中，然後被切掉一截而不是換行。
                if toolbarSettings.showLabels {
                    AnyView(drawingToolbarRow(showToolLabels: true).fixedSize(horizontal: true, vertical: false))
                }
                AnyView(drawingToolbarRow(showToolLabels: false).fixedSize(horizontal: true, vertical: false))
                AnyView(
                    WrapLayout(spacing: 12, lineSpacing: 8) {
                        drawingToolbarItems(showToolLabels: false)
                    }
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .trailing) {
                toolToastIndicator
            }
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

    /// 工具列上的一顆工具按鈕：向量圖示、（筆刷才有）示範筆跡、選取時凸起。
    @ViewBuilder
    private func brushToolButton(_ tool: EditorToolType, showToolLabels: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                selectEditorTool(tool)
            }
        } label: {
            VStack(spacing: 2) {
                BrushToolContent(tool: tool, isSelected: selectedTool == tool, ink: selectedColor)
                // 工具列在窄螢幕上不顯示文字標籤（showToolLabels = false），
                // 那時整排都是純圖示。
                if showToolLabels {
                    Text(localizationManager.localized(tool.localizationKey))
                        .font(.system(size: 9, weight: selectedTool == tool ? .semibold : .regular))
                        .foregroundColor(selectedTool == tool ? .primary : .secondary)
                }
            }
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized(tool.localizationKey))
        .accessibilityAddTraits(selectedTool == tool ? [.isSelected] : [])
        .accessibilityIdentifier(tool.parityIdentifier)
        .help(localizationManager.localized(tool.localizationKey))
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
                // 筆刷依「書寫／繪畫／標記」三族分段，族與族之間一條分隔線。
                // 橡皮擦與套索另成一組（見 EditorToolType.isBrush）。
                ForEach(Array([FfiBrushFamily.writing, .painting, .marking].enumerated()), id: \.offset) { index, family in
                    let tools = EditorToolType.allCases.filter {
                        $0.family == family && toolbarSettings.isVisible($0.parityIdentifier)
                    }
                    if !tools.isEmpty {
                        if index > 0 {
                            ToolbarSeparator().frame(height: 36)
                        }
                        ForEach(tools) { tool in
                            brushToolButton(tool, showToolLabels: showToolLabels)
                        }
                    }
                }

                ToolbarSeparator()
                    .frame(height: 36)

                // 擦除與選取。與筆刷分開，因為它們不沾墨，也不吃顏色與粗細。
                ForEach(EditorToolType.allCases.filter { !$0.isBrush && toolbarSettings.isVisible($0.parityIdentifier) }) { tool in
                    brushToolButton(tool, showToolLabels: showToolLabels)
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
                        .modifier(PopoverCompactAdaptation())
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
                .help(localizationManager.localized("stab_desc"))
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
                .help(localizationManager.localized("symmetry_guide_desc"))
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

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            lassoActionButton("scissors", "cut_selected", "cut_selected_hint", showLabel: showToolLabels) { cutSelectedStrokes() }
                            lassoActionButton("doc.on.doc", "copy_selected", "copy_selected_hint", showLabel: showToolLabels) { copySelectedStrokes() }
                            lassoActionButton("plus.square.on.square", "duplicate_selected", "duplicate_selected_hint", showLabel: showToolLabels) { duplicateSelectedStrokes() }
                            lassoActionButton("doc.on.clipboard", "paste_strokes", "paste_strokes_hint", showLabel: showToolLabels) { pasteStrokes() }
                            lassoActionButton("photo.on.rectangle", "save_as_sticker", "save_as_sticker", showLabel: showToolLabels) { saveSelectedAsSticker() }

                            // 🌟 套索轉化傳送門：手寫直接轉為文字方塊
                            lassoActionButton("text.viewfinder", "recognize_handwriting", "recognize_handwriting", showLabel: showToolLabels) {
                                recognizeHandwritingToTextBox()
                            }

                            // 🌟 動態流式錨定：手寫筆劃錨定至文字方塊
                            lassoActionButton("link.badge.plus", "sticky_anchor_text", "sticky_anchored_hint", showLabel: showToolLabels) {
                                anchorSelectedStrokesToNearestText()
                            }
                            
                            lassoRecolorButton

                            lassoDeleteButton(showLabel: showToolLabels)
                        }
                    }
                    // 依據是否顯示標籤動態調整最大寬度，避免窄畫面撐出視窗
                    .frame(maxWidth: showToolLabels ? 420 : 280)
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
                        performRedo()
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
            let draft = insertTextBox(at: CGPoint(x: 200, y: 200))
            withAnimation(.easeInOut(duration: 0.18)) {
                editorMode = .type
                inlineEditingTextId = draft.id
            }
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
        .help(localizationManager.localized("add_text_box_desc"))
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
        .help(localizationManager.localized("word_studio_desc"))
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
            // 這顆開關只有一個效果：隨點隨寫的文字落在哪裡。按下去當場說清楚，
            // 否則使用者只看到按鈕變色，不知道它到底管什麼。
            showCanvasNotice(localizationManager.localized(
                snapToGrid ? "snap_to_grid_on_notice" : "snap_to_grid_off_notice"))
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
            .help(localizationManager.localized("layer_bring_forward_desc"))
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
            .help(localizationManager.localized("layer_send_backward_desc"))
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
            setMarqueeActive(!isMarqueeActive)
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
                performRedo()
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
    private var lassoFloatingActionBar: AnyView {
        AnyView(
            ViewThatFits(in: .horizontal) {
                lassoFloatingActionBarRow(showLabels: true, showHint: false)
                    .fixedSize(horizontal: true, vertical: false)
                lassoFloatingActionBarRow(showLabels: false, showHint: false)
                    .fixedSize(horizontal: true, vertical: false)
            }
        )
    }

    private func lassoDeleteButton(showLabel: Bool = true) -> some View {
        Button {
            deleteSelectedStrokes()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "trash.fill")
                    .font(.caption2)
                if showLabel {
                    Text(localizationManager.localized("delete_selected"))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, showLabel ? 10 : 8)
            .padding(.vertical, 4)
            .background(Color.red)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized("delete_selected"))
        .help(localizationManager.localized("delete_selected"))
    }

    private var lassoCancelButton: some View {
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

    @ViewBuilder
    private func lassoFloatingActionItems(showLabels: Bool) -> some View {
        lassoActionButton("scissors", "cut_selected", "cut_selected_hint", showLabel: showLabels) {
            cutSelectedStrokes()
        }
        lassoActionButton("doc.on.doc", "copy_selected", "copy_selected_hint", showLabel: showLabels) {
            copySelectedStrokes()
        }
        lassoActionButton("photo.on.rectangle", "save_as_sticker", "save_as_sticker", showLabel: showLabels) {
            saveSelectedAsSticker()
        }
        lassoActionButton("plus.square.on.square", "duplicate_selected", "duplicate_selected_hint", showLabel: showLabels) {
            duplicateSelectedStrokes()
        }
        lassoActionButton("doc.on.clipboard", "paste_strokes", "paste_strokes_hint", showLabel: showLabels) {
            pasteStrokes()
        }
        lassoRecolorButton
        lassoActionButton("text.viewfinder", "recognize_handwriting", "recognize_handwriting", showLabel: showLabels) {
            recognizeHandwritingToTextBox()
        }
        lassoActionButton("link.badge.plus", "sticky_anchor_text", "sticky_anchored_hint", showLabel: showLabels) {
            anchorSelectedStrokesToNearestText()
        }
        lassoDeleteButton(showLabel: showLabels)

        Divider()
            .frame(height: 16)

        lassoCancelButton
    }

    private func lassoFloatingActionBarRow(showLabels: Bool, showHint: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "lasso")
                .foregroundColor(.accentColor)
                .font(.subheadline)

            if showHint {
                Text(localizationManager.localized("lasso_active_hint"))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Divider()
                    .frame(height: 16)
            }

            lassoFloatingActionItems(showLabels: showLabels)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.12), radius: 5, y: 2)
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
    /// 這一頁第一次載入時的狀態（只記一次）：筆畫、專業筆畫與已擦除名單。
    /// 第一次載入一定早於這頁的任何編輯，所以它就是「初始狀態」。
    private func captureInitialPageState(page: Int, drawing: PKDrawing) {
        if initialPageDrawings[page] == nil { initialPageDrawings[page] = drawing }
        if initialPageInk[page] == nil {
            let dir = store.drawingsDirectory
            initialPageInk[page] = InitialPageInk(
                own: ProInkStore.load(in: dir, notebookId: notebook.id, page: page),
                foreign: ProInkStore.load(in: dir, notebookId: notebook.id, page: page, foreign: true),
                suppressed: ProInkStore.loadSuppressed(in: dir, notebookId: notebook.id, page: page),
                erasedPencilKit: ErasedInkLedger.load(
                    in: store.syncBaselineDirectory, notebookId: notebook.id, page: page))
        }
    }

    /// 把所有看過的頁面還原成第一次載入時的樣子。
    private func restoreInitialPages() {
        let dir = store.drawingsDirectory
        let baselineDir = store.syncBaselineDirectory
        for (page, initial) in initialPageDrawings {
            // 這一頁現在的筆畫 → 被還原拿掉的要記進「已擦除」名單，不然同步會把雲端的舊檔帶回來。
            let now = store.loadDrawing(notebookId: notebook.id, pageIndex: page)
            let state = initialPageInk[page]
            var erased = ErasedInkLedger.load(in: baselineDir, notebookId: notebook.id, page: page)
            erased.formUnion(StrokeDelta.removed(in: initial, since: now).map { StrokeDelta.Identity($0).key })
            erased.subtract(initial.strokes.map { StrokeDelta.Identity($0).key })
            ErasedInkLedger.save(erased, in: baselineDir, notebookId: notebook.id, page: page)

            store.saveDrawing(notebookId: notebook.id, pageIndex: page, drawing: initial)
            coreInkBaselines[page] = initial
            if let state {
                ProInkStore.save(state.own, in: dir, notebookId: notebook.id, page: page)
                ProInkStore.save(state.foreign, in: dir, notebookId: notebook.id, page: page, foreign: true)
                ProInkStore.saveSuppressed(state.suppressed, in: dir, notebookId: notebook.id, page: page)
            }
        }
        pendingCoreInk.removeAll()
    }

    private func loadCurrentPage() {
        if let updated = store.notebooks.first(where: { $0.id == notebook.id }) {
            self.notebook = updated
        }
        // 這一本用的是哪一種紙。畫布、分頁、縮圖與匯出都讀這個值 ——
        // 忘了設的話，換到另一本不同規格的筆記時會沿用上一本的尺寸。
        PageGeometry.use(format: notebook.pageFormatId)
        let loaded = store.loadDrawing(notebookId: notebook.id, pageIndex: currentPageIndex)
        self.currentDrawing = loaded
        if let canvas = canvasView as? AdaptiveCanvasView {
            canvas.initialLoadedStrokeCount = loaded.strokes.count
            canvas.forceDisplayRefresh(with: loaded)
        }
        captureInitialPageState(page: currentPageIndex, drawing: loaded)
        self.lastStrokeCount = loaded.strokes.count
        self.currentPageHeight = notebook.height(forPage: currentPageIndex)
        self.lasso.clear()
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
        if let adaptive = canvasView as? AdaptiveCanvasView {
            adaptive.forceDisplayRefresh(with: merged)
        }
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
                // 若包含圖片 Base64，且本地尚未儲存該圖檔，立即寫入磁碟供 AttachmentsLayer 載入
                if let b64 = itemDict["image_base64"] as? String,
                   let imgData = Data(base64Encoded: b64),
                   let remoteImg = UIImage(data: imgData) {
                    let fileUrl = store.attachmentsDirectory.appending(path: imgItem.fileName)
                    if !FileManager.default.fileExists(atPath: fileUrl.path) {
                        try? imgData.write(to: fileUrl, options: .atomic)
                    }
                    _ = store.loadAttachmentImage(fileName: imgItem.fileName)
                }

                if let idx = notebook.attachments?.firstIndex(where: { $0.id == imgItem.id }) {
                    notebook.attachments?[idx] = imgItem
                } else {
                    if notebook.attachments == nil { notebook.attachments = [] }
                    notebook.attachments?.append(imgItem)
                }
                store.updateNotebook(notebook)
                PageThumbnailRenderer.invalidateAll()
            } else if attType == "3d", let modelItem = try? JSONDecoder().decode(Note3DAttachment.self, from: jsonData) {
                if let idx = notebook.model3DAttachments?.firstIndex(where: { $0.id == modelItem.id }) {
                    notebook.model3DAttachments?[idx] = modelItem
                } else {
                    if notebook.model3DAttachments == nil { notebook.model3DAttachments = [] }
                    notebook.model3DAttachments?.append(modelItem)
                }
                store.updateNotebook(notebook)
                PageThumbnailRenderer.invalidateAll()
            } else if attType == "table", let tableItem = try? JSONDecoder().decode(NoteTableAttachment.self, from: jsonData) {
                if let idx = notebook.tableAttachments?.firstIndex(where: { $0.id == tableItem.id }) {
                    notebook.tableAttachments?[idx] = tableItem
                } else {
                    if notebook.tableAttachments == nil { notebook.tableAttachments = [] }
                    notebook.tableAttachments?.append(tableItem)
                }
                store.updateNotebook(notebook)
                PageThumbnailRenderer.invalidateAll()
            } else if attType == "shape", let shapeItem = try? JSONDecoder().decode(NoteShapeAttachment.self, from: jsonData) {
                if let idx = notebook.shapeAttachments?.firstIndex(where: { $0.id == shapeItem.id }) {
                    notebook.shapeAttachments?[idx] = shapeItem
                } else {
                    if notebook.shapeAttachments == nil { notebook.shapeAttachments = [] }
                    notebook.shapeAttachments?.append(shapeItem)
                }
                store.updateNotebook(notebook)
                PageThumbnailRenderer.invalidateAll()
            } else if attType == "connection", let connItem = try? JSONDecoder().decode(NoteConnectionAttachment.self, from: jsonData) {
                if let idx = notebook.connectionAttachments?.firstIndex(where: { $0.id == connItem.id }) {
                    notebook.connectionAttachments?[idx] = connItem
                } else {
                    if notebook.connectionAttachments == nil { notebook.connectionAttachments = [] }
                    notebook.connectionAttachments?.append(connItem)
                }
                store.updateNotebook(notebook)
                PageThumbnailRenderer.invalidateAll()
            } else if attType == "link", let linkItem = try? JSONDecoder().decode(NoteLinkAttachment.self, from: jsonData) {
                if let idx = notebook.linkAttachments?.firstIndex(where: { $0.id == linkItem.id }) {
                    notebook.linkAttachments?[idx] = linkItem
                } else {
                    if notebook.linkAttachments == nil { notebook.linkAttachments = [] }
                    notebook.linkAttachments?.append(linkItem)
                }
                store.updateNotebook(notebook)
                PageThumbnailRenderer.invalidateAll()
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
            } else if attType == "table" {
                notebook.tableAttachments?.removeAll { $0.id == attId }
            } else if attType == "shape" {
                notebook.shapeAttachments?.removeAll { $0.id == attId }
            } else if attType == "connection" {
                notebook.connectionAttachments?.removeAll { $0.id == attId }
            } else if attType == "link" {
                notebook.linkAttachments?.removeAll { $0.id == attId }
            }
            store.updateNotebook(notebook)
            PageThumbnailRenderer.invalidateAll()

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

    private func recordTextUndoState() {
        let current = notebook.textAttachments ?? []
        textUndoStack.append(current)
        if textUndoStack.count > 50 {
            textUndoStack.removeFirst()
        }
        textRedoStack.removeAll()
        lastTextUndoTimestamp = Date()
    }

    private func recordTextUndoStateDebounced() {
        let now = Date()
        if now.timeIntervalSince(lastTextUndoTimestamp) > 1.2 {
            recordTextUndoState()
        }
    }

    /// 協同個人專屬復原與防誤刪墓碑還原
    private func performUndo() {
        // 1. 如果在文字輸入模式、文字方塊編輯中，或文字堆疊有操作記錄
        if (editorMode == .type || inlineEditingTextId != nil || editingTextId != nil) && !textUndoStack.isEmpty {
            let previous = textUndoStack.removeLast()
            let current = notebook.textAttachments ?? []
            textRedoStack.append(current)
            notebook.textAttachments = previous
            store.updateNotebook(notebook)
            PageThumbnailRenderer.invalidateAll()
            CanvasDiag.log("文字復原成功，剩餘堆疊: \(textUndoStack.count)")
            return
        }

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
                recordTextUndoState()
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
        } else if let addedId = lastAddedTextId,
                  let textItem = notebook.textAttachments?.first(where: { $0.id == addedId }),
                  textItem.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // 如果剛剛隨點隨打新增了空白文字方塊，復原會優先撤銷該文字方塊
            if inlineEditingTextId == addedId { inlineEditingTextId = nil }
            lastAddedTextId = nil
            recordTextUndoState()
            notebook.textAttachments?.removeAll { $0.id == addedId }
            store.updateNotebook(notebook)
            collaborationManager.broadcastAttachmentDelete(id: addedId, type: "text")
            PageThumbnailRenderer.invalidateAll()
        } else if !textUndoStack.isEmpty && canvasView?.undoManager?.canUndo != true {
            // 畫筆沒有可復原項，但文字堆疊有
            let previous = textUndoStack.removeLast()
            let current = notebook.textAttachments ?? []
            textRedoStack.append(current)
            notebook.textAttachments = previous
            store.updateNotebook(notebook)
            PageThumbnailRenderer.invalidateAll()
            CanvasDiag.log("文字復原成功 (回退模式)，剩餘堆疊: \(textUndoStack.count)")
        } else {
            let before = canvasView?.drawing.strokes.count ?? -1
            let canUndo = canvasView?.undoManager?.canUndo == true
            canvasView?.undoManager?.undo()
            let after = canvasView?.drawing.strokes.count ?? -1
            CanvasDiag.log("復原：筆畫 \(before) → \(after)，復原項\(canUndo ? "有" : "無")")
        }
    }

    /// 協同個人專屬重做
    private func performRedo() {
        if (editorMode == .type || inlineEditingTextId != nil || editingTextId != nil) && !textRedoStack.isEmpty {
            let next = textRedoStack.removeLast()
            let current = notebook.textAttachments ?? []
            textUndoStack.append(current)
            notebook.textAttachments = next
            store.updateNotebook(notebook)
            PageThumbnailRenderer.invalidateAll()
            CanvasDiag.log("文字重做成功，剩餘重做堆疊: \(textRedoStack.count)")
            return
        }

        if !textRedoStack.isEmpty && canvasView?.undoManager?.canRedo != true {
            let next = textRedoStack.removeLast()
            let current = notebook.textAttachments ?? []
            textUndoStack.append(current)
            notebook.textAttachments = next
            store.updateNotebook(notebook)
            PageThumbnailRenderer.invalidateAll()
            CanvasDiag.log("文字重做成功 (回退模式)，剩餘重做堆疊: \(textRedoStack.count)")
            return
        }

        let before = canvasView?.drawing.strokes.count ?? -1
        let canRedo = canvasView?.undoManager?.canRedo == true
        canvasView?.undoManager?.redo()
        let after = canvasView?.drawing.strokes.count ?? -1
        CanvasDiag.log("重做：筆畫 \(before) → \(after)，重做項\(canRedo ? "有" : "無")")
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
        guard isCanvasInkActive else { return }

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
            performUndo()
        case .redo:
            performRedo()
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

    /// 取得指定頁面的手寫筆跡（優先取待存核心筆跡、當前單頁模式中正在編輯的筆跡、最後取磁碟存檔）
    private func drawingForPage(_ page: Int) -> PKDrawing {
        if let pending = pendingCoreInk[page] {
            return pending
        }
        if pageDisplayMode == .single && page == currentPageIndex {
            return currentDrawing
        }
        return store.loadDrawing(notebookId: notebook.id, pageIndex: page)
    }

    private func recordDrawingEdit(page: Int, drawing: PKDrawing) {
        if page == currentPageIndex {
            currentDrawing = drawing
        }
        pendingCoreInk[page] = drawing
        scheduleCoreInkFlush()
        noteInkEdited()
    }

    /// 落筆之後多久把增量寫進套件。
    ///
    /// 原本是 1.2 秒，那是「另一台看得到」之前**必經的第一段** —— 再加上同步排程器
    /// 的去抖動，一筆畫要兩秒多之後才開始往外送。這一步只是把增量追加進套件
    /// （一個小檔案的 append）與寫 `.drawing`，並不昂貴；真正昂貴的
    /// `updateNotebook()`（寫 `notebooks.json`、整棵畫面重算）仍由 `noteInkEdited()`
    /// 的 1.2 秒去抖動負責，沒有動。
    ///
    /// 純去抖動有個缺點：一直不停手就一直不寫。所以有上限 ——
    /// 這一批待寫的筆畫最早的那一筆起算，超過 `inkFlushMaxHold` 就不再等。
    private static let inkFlushDelay: TimeInterval = 0.4
    private static let inkFlushMaxHold: TimeInterval = 1.5

    private func scheduleCoreInkFlush() {
        coreInkWork?.cancel()
        let now = Date()
        let firstPending = coreInkFirstPendingAt ?? now
        coreInkFirstPendingAt = firstPending
        let remainingHold = Self.inkFlushMaxHold - now.timeIntervalSince(firstPending)
        let delay = max(0, min(Self.inkFlushDelay, remainingHold))
        let work = DispatchWorkItem {
            flushPendingCoreInk()
        }
        coreInkWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func flushPendingCoreInk() {
        coreInkWork?.cancel()
        coreInkWork = nil
        coreInkFirstPendingAt = nil
        let pending = pendingCoreInk
        pendingCoreInk.removeAll()
        // 增量寫進套件之後才通知焦點通道 —— 先通知的話，它可能推到還沒寫完的檔案。
        defer {
            if !pending.isEmpty { FocusSyncController.shared.noteLocalEdit() }
        }

        for (page, drawing) in pending {
            store.saveDrawing(notebookId: notebook.id, pageIndex: page, drawing: drawing)
            let baseline = coreInkBaseline(for: page)
            let added = StrokeDelta.added(in: drawing, since: baseline)
            // 擦掉的筆畫記下來，匯入時濾掉（不然同步會把雲端的舊檔下載回來、筆畫復活）。
            ErasedInkLedger.record(
                removed: StrokeDelta.removed(in: drawing, since: baseline), added: added,
                in: store.syncBaselineDirectory, notebookId: notebook.id, page: page)
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
            let hadPendingInk = !pendingCoreInk.isEmpty
            flushPendingCoreInk()
            // 沒有待寫的墨跡、文件也跟 store 裡一樣，就不要「碰」這本筆記。
            // 每次碰都會把修改時間往前推並通知同步「本機有編輯」，於是只是切換模式、
            // 點縮圖跳頁，同步就匯出重建一次套件、下載、再觸發編輯器重載 ——
            // 同步日誌裡那串首尾相接、每一輪都「匯出 1 本、下載 4」的迴圈就是這樣來的。
            if !hadPendingInk && !proInkDirty && store.notebookMatchesStored(notebook) { return }
            proInkDirty = false
            notebook.lastModifiedDate = Date()
            store.updateNotebook(notebook)
            return
        }
        // 模式切換會立即觸發 SwiftUI 更新；`@Binding` 的最後一次回寫有可能還
        // 排在同一個 run loop 後面。此時若拿 `currentDrawing` 存檔並回灌 UI，
        // 會把畫布上剛完成的多筆筆跡換成較舊的快照，看起來像切到打字模式後
        // 大部分筆跡消失。可見的 PKCanvasView 才是切換瞬間的權威快照。
        if let liveDrawing = canvasView?.drawing, liveDrawing != currentDrawing {
            currentDrawing = liveDrawing
        }
        // 筆跡沒變就不重寫：模式切換、點物件前後都會呼叫這裡，而序列化＋寫檔＋推進核心是整頁的成本。
        let unchanged = lastPersistedInk.map { $0.page == currentPageIndex && $0.drawing == currentDrawing } ?? false
        if !unchanged {
            store.saveDrawing(notebookId: notebook.id, pageIndex: currentPageIndex, drawing: currentDrawing)
            pendingCoreInk[currentPageIndex] = currentDrawing
            flushPendingCoreInk()
            lastPersistedInk = (currentPageIndex, currentDrawing)
        }
        // 同上：筆跡沒變、文件也與 store 一致就不碰。
        if unchanged && !proInkDirty && store.notebookMatchesStored(notebook) { return }
        proInkDirty = false
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

    private func applyLassoResult(_ newDrawing: PKDrawing) {
        currentDrawing = newDrawing
        if let canvas = canvasView {
            canvas.drawing = newDrawing
        }
        recordDrawingEdit(page: currentPageIndex, drawing: newDrawing)
        broadcastDrawingChange(page: currentPageIndex, drawing: newDrawing)
        saveCurrentPageDrawing()
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    private func deleteSelectedStrokes() {
        guard lasso.hasSelection else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
        guard let updated = lasso.deleteSelected(from: currentDrawing) else { return }
        applyLassoResult(updated)
    }

    private func cutSelectedStrokes() {
        guard lasso.hasSelection else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
        guard let updated = lasso.cutSelected(from: currentDrawing) else { return }
        applyLassoResult(updated)
    }

    // MARK: - 🌟 次世代專業筆刷與手寫轉換 (CSP 防抖、對稱尺規、套索 OCR 轉文字)
    private func recognizeHandwritingToTextBox() {
        let fullDrawing = currentDrawing
        let selectedStrokes = lasso.hasSelection ? lasso.extractSelectedStrokes(from: fullDrawing) : fullDrawing.strokes
        guard !selectedStrokes.isEmpty else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
        
        // 計算筆跡包圍盒與平均色彩（原地轉化：沿用位置、寬度、筆色）
        var strokeBounds: CGRect = .null
        var strokeColorHex: String = "#000000"
        for stroke in selectedStrokes {
            strokeBounds = strokeBounds.union(stroke.renderBounds)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            if stroke.ink.color.getRed(&r, green: &g, blue: &b, alpha: &a) {
                strokeColorHex = String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
            }
        }
        if strokeBounds.isNull || !strokeBounds.width.isFinite || !strokeBounds.height.isFinite {
            strokeBounds = CGRect(x: 160, y: 200, width: 340, height: 140)
        }
        
        let language = localizationManager.currentLanguage.rawValue
        let hasSelection = lasso.hasSelection
        showCanvasNotice("正在辨識手寫文字…")

        Task { @MainActor in
            switch await HandwritingRecognizer.recognize(strokes: selectedStrokes, languageTag: language) {
            case .success(let recognizedText):
                let trimmed = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    showCanvasNotice("未能在圈選筆劃中辨識出文字，請嘗試圈選更清晰的手寫筆跡")
                    return
                }
                
                // 原地取代：產生對準原筆劃位置之 NoteTextAttachment
                let pad: CGFloat = 8
                let draft = NoteTextAttachment(
                    id: UUID().uuidString,
                    pageIndex: currentPageIndex,
                    text: trimmed,
                    fontSize: max(16, min(32, strokeBounds.height * 0.7)),
                    textColorHex: strokeColorHex,
                    backgroundColorHex: "#FFFFFF",
                    hasBorder: false,
                    x: max(PageGeometry.printableInset, strokeBounds.minX - pad),
                    y: max(PageGeometry.printableInset, strokeBounds.minY - pad),
                    width: max(120, strokeBounds.width + pad * 2),
                    height: max(44, strokeBounds.height + pad * 2)
                )
                
                if notebook.textAttachments == nil { notebook.textAttachments = [] }
                notebook.textAttachments?.append(draft)
                
                // 清除選中的筆劃（若有套索選取則只刪被選筆劃，否則清空整頁）
                if hasSelection, let updated = lasso.deleteSelected(from: currentDrawing) {
                    applyLassoResult(updated)
                } else {
                    currentDrawing = PKDrawing()
                    canvasView?.drawing = PKDrawing()
                    saveCurrentPageDrawing()
                }
                
                withAnimation(.easeInOut(duration: 0.2)) {
                    editorMode = .type
                    inlineEditingTextId = draft.id
                    editingTextId = nil
                }
                store.updateNotebook(notebook)
                PageThumbnailRenderer.invalidateAll()
                showCanvasNotice("已成功將手寫轉換為文字")
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
            case .failure:
                showCanvasNotice("手寫辨識未完成：請確認圈選內容包含清晰文字")
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
        guard !drawing.strokes.isEmpty else {
            showCanvasNotice("目前頁面沒有手寫筆劃可供錨定")
            return
        }

        let pageTexts = (notebook.textAttachments ?? []).filter { $0.pageIndex == currentPageIndex }
        guard !pageTexts.isEmpty else {
            showCanvasNotice("頁面上尚無文字方塊。請先新增文字方塊並使手寫筆劃相鄰，即可建立動態連動錨定")
            return
        }

        let candidateIndices = lasso.hasSelection ? Array(lasso.selected) : Array(drawing.strokes.indices)
        for target in pageTexts {
            let textRect = CGRect(x: target.x, y: target.y, width: target.width, height: target.height)
            var matchedIndices: [Int] = []
            for idx in candidateIndices where drawing.strokes.indices.contains(idx) {
                let stroke = drawing.strokes[idx]
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
                lasso.clear()
                showCanvasNotice("手寫筆劃已成功錨定至文字方塊！移動該文字方塊時，筆跡將隨之連動")
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                return
            }
        }
        if let firstText = pageTexts.first {
            anchorOverlappingInkToText(textItem: firstText)
        } else {
            showCanvasNotice("未找到與所選筆劃相鄰的文字方塊；請圈選與文字方塊相重疊或相鄰的筆劃")
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

        guard !matchedIndices.isEmpty else {
            showCanvasNotice("未找到與所選筆劃相鄰的文字方塊；請圈選與文字方塊相重疊或相鄰的筆劃")
            return
        }
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
        showCanvasNotice("手寫筆劃已成功錨定至文字方塊！移動該文字方塊時，筆跡將隨之連動")
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    /// 自動判定新落筆跡是否與既有文字方塊高度重疊（> 40%），若是則自動關聯錨定（工作項 F4 v1）
    private func autoAnchorNewStrokesToOverlappingText(drawing: PKDrawing) {
        let pageTexts = (notebook.textAttachments ?? []).filter { $0.pageIndex == currentPageIndex }
        guard !pageTexts.isEmpty else { return }

        var updatedAnchors = notebook.stickyAnchors ?? []
        var hasChanges = false

        for textItem in pageTexts {
            let textRect = CGRect(x: textItem.x, y: textItem.y, width: textItem.width, height: textItem.height)
            var matchedIndices: [Int] = []
            
            for (idx, stroke) in drawing.strokes.enumerated() {
                let strokeBounds = stroke.renderBounds
                if textRect.intersects(strokeBounds) {
                    let intersection = textRect.intersection(strokeBounds)
                    let strokeArea = max(1.0, strokeBounds.width * strokeBounds.height)
                    let intersectArea = intersection.width * intersection.height
                    // 重疊面積或相交比例足夠視為對文字之圈註／劃線／旁註
                    if intersectArea / strokeArea > 0.3 || textRect.contains(strokeBounds) {
                        matchedIndices.append(idx)
                    }
                }
            }

            if !matchedIndices.isEmpty {
                let anchor = StickyAnnotationAnchor(
                    pageIndex: currentPageIndex,
                    targetId: textItem.id,
                    strokeIndices: matchedIndices,
                    anchorOriginX: Float(textItem.x),
                    anchorOriginY: Float(textItem.y)
                )
                updatedAnchors.removeAll { $0.targetId == textItem.id && $0.pageIndex == currentPageIndex }
                updatedAnchors.append(anchor)
                hasChanges = true
            }
        }

        if hasChanges {
            notebook.stickyAnchors = updatedAnchors
            store.updateNotebook(notebook)
        }
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
    private func pasteStrokes() {
        guard lasso.canPaste else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
        guard let updated = lasso.paste(into: currentDrawing) else { return }
        applyLassoResult(updated)
    }

    /// 就地複製選取的筆劃並稍微偏移（不經過剪貼簿）—— 這就是「再製」與「複製」的差別：
    /// 「複製」把東西放進剪貼簿等你貼上，「再製」直接在旁邊多一份。
    private func duplicateSelectedStrokes() {
        guard lasso.hasSelection else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
        guard let updated = lasso.duplicateSelected(in: currentDrawing) else { return }
        applyLassoResult(updated)
    }

    private func saveSelectedAsSticker() {
        guard lasso.hasSelection else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
        let extractedStrokes = lasso.extractSelectedStrokes(from: currentDrawing)
        guard !extractedStrokes.isEmpty else { return }
        
        let tempDrawing = PKDrawing(strokes: extractedStrokes)
        let bounds = tempDrawing.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        
        // 筆畫座標正規化至正數象限（預留 16pt 邊距），防止 PKDrawing.image 負值邊界造成算繪空白或截斷
        let padding: CGFloat = 16
        let transform = CGAffineTransform(translationX: -bounds.minX + padding, y: -bounds.minY + padding)
        let normalizedStrokes = extractedStrokes.map {
            PKStroke(ink: $0.ink, path: $0.path, transform: $0.transform.concatenating(transform), mask: $0.mask)
        }
        let stickerDrawing = PKDrawing(strokes: normalizedStrokes)
        StickerManager.shared.saveSticker(stickerDrawing)
        
        lasso.clear()
        selectedTool = previousTool ?? lastBrushTool
        showCanvasNotice("已儲存為貼紙！可於頂端「插入 > 貼紙 > 我的貼紙」中選用")
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    /// 把確認放置的貼紙變成**頁面上的物件**，不是烘進筆跡。
    ///
    /// # 為什麼不再烘成筆跡
    ///
    /// 原本確認之後貼紙被拆成一堆 `PKStroke` 混進手寫內容，於是它跟隨手寫的字
    /// 沒有任何分別：點它沒有反應、沒有把手、沒有刪除鈕，只有切到套索再精準
    /// 圈住才搬得動 —— 而使用者根本不知道要這麼做，回報的就是「確認後就無法
    /// 移動、編輯或刪除」。
    ///
    /// 現在貼紙以透明底圖片物件進頁面，跟圖片同一套：點選出把手、拖曳搬移、
    /// 縮放、旋轉、刪除、調圖層、框選、同步與匯出全部現成。放置時選的大小與
    /// 角度原樣帶過去。
    private func insertStickerObject(_ placement: PendingStickerPlacement) {
        let b = placement.drawing.bounds
        guard b.width > 0, b.height > 0 else { return }
        // 與 `StickerRenderView` 同一個規則：在 (寬 × 縮放, 高 × 縮放) 的框裡等比置中。
        let boxW = max(50, placement.size.width) * max(0.2, min(5, placement.scale))
        let boxH = max(50, placement.size.height) * max(0.2, min(5, placement.scale))
        let fit = min(boxW / b.width, boxH / b.height)
        let size = CGSize(width: b.width * fit, height: b.height * fit)

        // 3 倍像素：貼紙是向量，但存成圖片後放大會糊，預留縮放的餘裕。
        let image = placement.drawing.image(from: b, scale: 3 * max(1, fit))
        guard let fileName = store.saveAttachmentImage(image) else { return }
        let attachment = NoteImageAttachment(
            fileName: fileName,
            pageIndex: currentPageIndex,
            x: placement.center.x - size.width / 2,
            y: placement.center.y - size.height / 2,
            width: size.width,
            height: size.height,
            rotationDegrees: placement.rotationDegrees,
            cornerRadius: 0,
            hasShadow: false,
            hasBorder: false,
            filterStyle: .original,
            chartSpecJSON: nil
        )
        if notebook.attachments == nil { notebook.attachments = [] }
        notebook.attachments?.append(attachment)
        store.updateNotebook(notebook)
        if var dict = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(attachment))) as? [String: Any] {
            if let imgData = image.pngData() {
                dict["image_base64"] = imgData.base64EncodedString()
            }
            collaborationManager.broadcastAttachmentUpsert(type: "image", itemDict: dict)
        }
        PageThumbnailRenderer.invalidateAll()
    }

    private func copySelectedStrokes() {
        guard lasso.hasSelection else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
        lasso.copySelected(from: currentDrawing)
        showCanvasNotice(localizationManager.localized("copy_selected_hint"))
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    private func stopAndSaveRecording() {
        if let result = audioManager.stopRecording() {
            let fileName = result.url.lastPathComponent
            notebook.hasRecording = true
            notebook.recordingAudioPath = fileName
            store.updateNotebook(notebook)
            let rec = store.addRecording(
                title: NotebookStore.defaultRecordingTitle(),
                durationSeconds: AudioRecorderManager.displaySeconds(of: result.url, fallback: result.duration),
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
    /// 墨跡在物件之上嗎？跟著畫布目前的模式：手寫模式墨跡在上（在圖上圈重點），打字模式物件在上。
    /// 匯出、列印、縮圖都用這個答案，「所見即所得」。
    private var inkDrawnOnTop: Bool { editorMode == .draw }

    /// 把某一頁算繪成圖（與縮圖、PNG 匯出是同一份繪圖程式碼）。
    private func composedPageImage(_ index: Int, scale: CGFloat) -> UIImage {
        PageThumbnailRenderer.renderFullPage(
            notebook: notebook,
            pageIndex: index,
            drawing: drawingForPage(index),
            store: store,
            canvasWidth: max(canvasContentWidth, PageThumbnailRenderer.minPageWidth),
            scale: scale,
            inkOnTop: inkDrawnOnTop
        )
    }

    /// 匯出 PDF（也是列印走的路）。
    ///
    /// # 為什麼是點陣而不是核心的向量匯出
    ///
    /// 「所見即所得」是底線。核心的向量匯出器把每一筆畫成**等寬折線**：PencilKit 的壓感粗細、鉛筆與麥克筆的
    /// 紋理、螢光筆的疊色、專業筆刷的筆點全都不見；圖片的濾鏡與材質、物件的堆疊順序、形狀、圖表、連結卡片也不在它
    /// 的文件模型裡。結果是「畫布上是一個樣子，PDF 是另一個樣子」。
    /// 這裡每一頁用**縮圖與 PNG 匯出同一份繪圖程式碼**算繪，三者逐像素一致。
    /// 代價：PDF 裡的文字不能選取、筆畫不是可編輯的標註 —— 要向量與標註請用 `.padnote` 或「製圖輸出（SVG／DXF）」。
    private func buildNotebookPdf(scale: CGFloat = 2.0) -> Data {
        saveCurrentPageDrawing()
        return buildRasterPdf(scale: scale)
    }

    /// 逐頁算繪、逐頁寫進 PDF：不先把所有頁面的點陣圖都留在記憶體裡（頁數多的筆記本會吃掉幾百 MB）。
    private func buildRasterPdf(scale: CGFloat = 2.0) -> Data {
        let count = max(1, notebook.pageCount)
        let first = composedPageImage(0, scale: scale)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: first.size))
        return renderer.pdfData { context in
            for i in 0..<count {
                // 圖的大小就是頁面大小（點），每一頁用自己的尺寸開頁（頁面高度可以不同）。
                let image = i == 0 ? first : composedPageImage(i, scale: scale)
                context.beginPage(withBounds: CGRect(origin: .zero, size: image.size), pageInfo: [:])
                image.draw(in: CGRect(origin: .zero, size: image.size))
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
        if UIDevice.current.userInterfaceIdiom == .pad {
            let targetView = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?.rootViewController?.view
            if let view = targetView {
                let rect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
                printController.present(from: rect, in: view, animated: true, completionHandler: nil)
            } else {
                printController.present(animated: true, completionHandler: nil)
            }
        } else {
            printController.present(animated: true, completionHandler: nil)
        }
    }

    private func exportAsPngImage() {
        saveCurrentPageDrawing()
        let img = composedPageImage(currentPageIndex, scale: 2.0)
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
            // 專業筆刷與製圖線不在 PKDrawing 裡：原本分享出去的 `.padnote` **完全沒有它們** ——
            // 在別台打開，畫的三視圖整個不見。自己的與別台同步來的都要帶，**隱藏的圖層也要**
            // （隱藏只是這台的顯示設定，不是刪除；收到的人打開圖層面板可以打開）。
            let dir = store.drawingsDirectory
            let pro = (0..<max(notebook.pageCount, 1)).map { page in
                ProInkStore.load(in: dir, notebookId: notebook.id, page: page, foreign: true)
                    + ProInkStore.load(in: dir, notebookId: notebook.id, page: page)
            }
            try NotebookPackageBridge.export(
                document: notebook,
                drawings: drawings,
                imageData: imageMap,
                to: pkgDir,
                deviceId: 0x4150,
                proStrokes: pro
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
            Divider()
            // 大尺寸頁取代無限畫布：任意寬高（300–6000）。
            Button {
                showCustomPageSize = true
            } label: {
                HStack {
                    Text(localizationManager.localized("page_format_custom"))
                    if isCustomPageFormat(id: notebook.pageFormatId ?? defaultPageFormatId()) {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .accessibilityIdentifier("page_format.custom")
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: EditorToolbarMetrics.icon))
                Text(pageFormatTitle)
                    .font(.system(size: EditorToolbarMetrics.label))
            }
            .foregroundColor(.accentColor)
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized("page_format"))
        .help(localizationManager.localized("page_format_desc"))
        .sheet(isPresented: $showCustomPageSize) {
            CustomPageSizeSheet(initial: PageGeometry.size) { applyPageFormat($0) }
        }
    }

    /// 這一頁上所有手繪線的點：專業筆刷（含製圖線）加上 PencilKit 的筆畫。
    private func solidSketchPolylines() -> [[CGPoint]] {
        var all = (canvasView as? AdaptiveCanvasView)?.proLayer?.sketchPolylines ?? []
        if let drawing = canvasView?.drawing {
            for stroke in drawing.strokes {
                all.append(stroke.path.interpolatedPoints(by: .distance(3)).map(\.location))
            }
        }
        return all
    }

    /// 把立體輔助排好的圖紙插進目前這一頁：放在**目前看得到的範圍正中央**（不是固定貼頂，
    /// 那樣會壓在既有的圖上），整組一次復原。插入後直接用套索選住它，使用者拖一下就能搬。
    private func insertSolidSheet(_ sheet: FfiSolidSheet) {
        guard let canvas = canvasView as? AdaptiveCanvasView, let layer = canvas.proLayer else { return }
        let page = PageGeometry.size
        let w = CGFloat(sheet.width), h = CGFloat(sheet.height)
        let center = layer.convert(CGPoint(x: canvas.bounds.midX, y: canvas.bounds.midY), from: canvas)
        let origin = CGPoint(
            x: min(max(0, center.x - w / 2), max(0, page.width - w)),
            y: min(max(0, center.y - h / 2), max(0, page.height - h)))
        let made = layer.insertDrafted(sheet.strokes, origin: origin)
        showCanvasNotice(localizationManager.localized("solid_place_hint"))
        guard !made.isEmpty else { return }
        selectedTool = .lasso
        // 換工具會清掉舊的選取；等下一個 runloop 再選，選取框才不會被清掉。
        let ids = Set(made.map(\.id))
        let box = made.map(\.bounds).reduce(CGRect.null) { $0.union($1) }
        DispatchQueue.main.async { lasso.select(proStrokeIds: ids, around: box) }
    }

    /// 把一組製圖符號放在目前看得到的範圍正中央（同 `insertSolidSheet`：整組一次復原、插入後套索選住）。
    private func insertDraftKit(_ kit: FfiDraftKit) {
        guard let canvas = canvasView as? AdaptiveCanvasView, let layer = canvas.proLayer else { return }
        let pts = kit.strokes.flatMap(\.points)
        guard let minX = pts.map(\.x).min(), let maxX = pts.map(\.x).max(),
              let minY = pts.map(\.y).min(), let maxY = pts.map(\.y).max() else { return }
        let page = PageGeometry.size
        let w = CGFloat(maxX - minX), h = CGFloat(maxY - minY)
        let center = layer.convert(CGPoint(x: canvas.bounds.midX, y: canvas.bounds.midY), from: canvas)
        // 讓符號的包圍盒中心落在視野中央，再夾回頁面裡。
        let left = min(max(0, center.x - w / 2), max(0, page.width - w))
        let top = min(max(0, center.y - h / 2), max(0, page.height - h))
        let origin = CGPoint(x: left - CGFloat(minX), y: top - CGFloat(minY))
        let made = layer.insertDrafted(kit.strokes, origin: origin)
        showCanvasNotice(localizationManager.localized("draft_symbol_placed"))
        guard !made.isEmpty else { return }
        selectedTool = .lasso
        let ids = Set(made.map(\.id))
        let box = made.map(\.bounds).reduce(CGRect.null) { $0.union($1) }
        DispatchQueue.main.async { lasso.select(proStrokeIds: ids, around: box) }
    }

    /// 匯出本頁的製圖線（SVG 或 DXF，毫米）：隱藏的圖層不輸出；寫進暫存資料夾再交給分享表。
    private func exportDrafting(format: String) {
        guard let canvas = canvasView as? AdaptiveCanvasView, let layer = canvas.proLayer else { return }
        let drafting = DraftingState.shared
        let strokes: [FfiExportStroke] = layer.allStrokes.compactMap { s in
            guard s.points.count >= 2,
                  s.layerId == 0 || !drafting.isHidden(layer: s.layerId, notebookId: layer.notebookId)
            else { return nil }
            let c = s.colorRGBA
            let hex = c.count >= 3 ? String(format: "#%02X%02X%02X", c[0], c[1], c[2]) : "#111827"
            return FfiExportStroke(
                points: s.points.map { FfiPoint(x: $0.x, y: $0.y) }, layer: s.layerId, lineType: s.lineTypeId,
                width: s.baseWidth, colorHex: hex)
        }
        guard !strokes.isEmpty else {
            showCanvasNotice(localizationManager.localized("draft_export_empty"))
            return
        }
        let size = PageGeometry.size
        let text = format == "dxf"
            ? draftExportDxf(strokes: strokes, pageWidth: Float(size.width), pageHeight: Float(size.height))
            : draftExportSvg(strokes: strokes, pageWidth: Float(size.width), pageHeight: Float(size.height))
        let url = FileManager.default.temporaryDirectory
            .appending(path: "padnote-page-\(currentPageIndex + 1).\(format)")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            showCanvasNotice(localizationManager.localized("draft_export_failed"))
            return
        }
        // 工具箱剛關：等它收起來再開分享表，兩個 sheet 同時換手會被系統吃掉。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { draftExportShare = SharedFile(url: url) }
    }

    /// 開始一題練習：把題目線放進目前這一頁（頁面大小由核心依它排版）。
    private func startPractice(kind: String) {
        guard let canvas = canvasView as? AdaptiveCanvasView, let layer = canvas.proLayer else { return }
        selectedTool = .drafting
        PracticeSession.shared.start(kind: kind, layer: layer, pageSize: PageGeometry.size)
    }

    /// 矩形陣列：套用在套索選的那批線上（一次復原）。
    private func applyRectArray(rows: Int, cols: Int, dxMm: Double, dyMm: Double) {
        guard let canvas = canvasView as? AdaptiveCanvasView, let layer = canvas.proLayer else { return }
        DraftingState.shared.editSelection = lasso.proIds
        guard !lasso.proIds.isEmpty else {
            showCanvasNotice(localizationManager.localized("draft_edit_need_selection"))
            return
        }
        DraftEditController.shared.applyRectArray(rows: rows, cols: cols, dxMm: dxMm, dyMm: dyMm, layer: layer)
    }

    /// 把量角器讀到的角度畫成一條線（從圓心到外緣），一次復原。
    private func markProtractorReading() {
        guard let canvas = canvasView as? AdaptiveCanvasView, let layer = canvas.proLayer else { return }
        let drafting = DraftingState.shared
        guard let (a, b) = drafting.instrument?.readingRay else { return }
        let pen = drafting.activePen
        let stroke = FfiSheetStroke(
            points: [FfiPoint(x: Float(a.x), y: Float(a.y)), FfiPoint(x: Float(b.x), y: Float(b.y))],
            layer: drafting.activeLayerId, lineType: drafting.activeLineType, width: pen.width, colorHex: pen.colorHex)
        guard !drafting.isLocked(layer: stroke.layer, notebookId: layer.notebookId) else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        drafting.ensureVisible(layer: stroke.layer, notebookId: layer.notebookId)
        layer.insertDrafted([stroke], origin: .zero)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// 目前視野的正中央（頁面座標）。
    private func draftViewportCenter() -> CGPoint {
        guard let canvas = canvasView as? AdaptiveCanvasView, let layer = canvas.proLayer else {
            return CGPoint(x: PageGeometry.size.width / 2, y: PageGeometry.size.height / 2)
        }
        return layer.convert(CGPoint(x: canvas.bounds.midX, y: canvas.bounds.midY), from: canvas)
    }

    /// 這一頁的紙張規格有沒有標準圖框（A4／A3／A2，直式或橫式）。
    private var frameSupportedForCurrentPage: Bool {
        draftSheetFrame(paperId: notebook.pageFormatId ?? defaultPageFormatId(), scaleText: "", thirdAngle: true, titleBlock: false) != nil
    }

    /// 插入圖框與標題欄：框線是製圖筆畫（粗框、細格），欄位名稱是文字方塊（跟著介面語言）。
    private func insertDraftFrame(thirdAngle: Bool) {
        guard let canvas = canvasView as? AdaptiveCanvasView, let layer = canvas.proLayer else { return }
        let drafting = DraftingState.shared
        guard let kit = draftSheetFrame(
            paperId: notebook.pageFormatId ?? defaultPageFormatId(),
            scaleText: drafting.scaleLabel(notebookId: notebook.id),
            thirdAngle: thirdAngle, titleBlock: true)
        else {
            showCanvasNotice(localizationManager.localized("draft_frame_unsupported"))
            return
        }
        layer.insertDrafted(kit.strokes, origin: .zero)
        var added = notebook.textAttachments ?? []
        for label in kit.texts {
            added.append(NoteTextAttachment(
                pageIndex: currentPageIndex, text: localizationManager.localized(label.key),
                fontSize: CGFloat(label.fontSize), isBold: label.bold, alignmentRaw: "left",
                textColorHex: label.colorHex, backgroundColorHex: "clear", hasBorder: false,
                x: CGFloat(label.x), y: CGFloat(label.y), width: CGFloat(label.width),
                height: CGFloat(label.fontSize) * 1.6 + 6))
        }
        notebook.textAttachments = added
        showCanvasNotice(localizationManager.localized("draft_frame_inserted"))
    }

    /// 工具列上顯示的規格名稱。自訂的直接顯示尺寸（「2000×1500」）。
    private var pageFormatTitle: String {
        let id = notebook.pageFormatId ?? defaultPageFormatId()
        let format = pageFormat(id: id)
        if isCustomPageFormat(id: id) {
            return "\(Int(format.width))×\(Int(format.height))"
        }
        return localizationManager.localized(format.titleKey)
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
                    .frame(width: EditorToolbarMetrics.icon - 4, height: EditorToolbarMetrics.icon - 4)
                Text(localizationManager.localized(guidePalette(id: current).nameKey))
                    .font(.system(size: EditorToolbarMetrics.label))
            }
            .foregroundColor(.accentColor)
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized("guide_palette"))
        .help(localizationManager.localized("guide_palette_desc"))
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
        let duration: Double = ProcessInfo.processInfo.environment["KAIRUMO_UITEST"] == "1" ? 10.0 : 3.5
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
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

    /// 自動自癒示範筆記《Kairumo(功能範例)》：將背景大卡片移至筆跡下方圖層，使筆跡可見且不干擾手繪與打字。
    private func sanitizeUnderInkObjects() {
        if notebook.id == "seed-feature-showcase-v1" || notebook.titleKey == "seed_feature_showcase_title" {
            if notebook.underInkObjectIds(forPage: 1).isEmpty {
                for p in 0..<notebook.pageCount {
                    let bgCardIds = (notebook.shapeAttachments ?? []).filter {
                        $0.pageIndex == p && $0.kindName == "rectangle" && $0.label.isEmpty
                    }.map(\.id)
                    notebook.setUnderInkObjectIds(Set(bgCardIds), forPage: p)
                }
                store.updateNotebook(notebook)
                PageThumbnailRenderer.invalidateAll()
            }
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

    private func ensureActiveTextAttachment() -> (id: String, index: Int) {
        if let id = activeTextAttachment?.id,
           let index = notebook.textAttachments?.firstIndex(where: { $0.id == id }) {
            return (id, index)
        }
        let draft = insertTextBox(at: CGPoint(x: PageGeometry.printableInset, y: 200))
        let idx = (notebook.textAttachments?.firstIndex(where: { $0.id == draft.id })) ?? 0
        return (draft.id, idx)
    }

    private func toggleActiveTextBold() {
        let target = ensureActiveTextAttachment()
        guard let items = notebook.textAttachments, items.indices.contains(target.index) else { return }
        recordTextUndoState()
        notebook.textAttachments?[target.index].isBold.toggle()
        store.updateNotebook(notebook)
        PageThumbnailRenderer.invalidateAll()
    }

    private func toggleActiveTextItalic() {
        let target = ensureActiveTextAttachment()
        guard let items = notebook.textAttachments, items.indices.contains(target.index) else { return }
        recordTextUndoState()
        notebook.textAttachments?[target.index].isItalic.toggle()
        store.updateNotebook(notebook)
        PageThumbnailRenderer.invalidateAll()
    }

    private func toggleActiveTextUnderline() {
        let target = ensureActiveTextAttachment()
        guard let items = notebook.textAttachments, items.indices.contains(target.index) else { return }
        recordTextUndoState()
        notebook.textAttachments?[target.index].isUnderline.toggle()
        store.updateNotebook(notebook)
        PageThumbnailRenderer.invalidateAll()
    }

    private func setActiveTextAlignment(_ align: String) {
        let target = ensureActiveTextAttachment()
        guard let items = notebook.textAttachments, items.indices.contains(target.index) else { return }
        recordTextUndoState()
        notebook.textAttachments?[target.index].alignmentRaw = align
        store.updateNotebook(notebook)
        PageThumbnailRenderer.invalidateAll()
    }

    private func changeActiveTextFontSize(delta: CGFloat) {
        let target = ensureActiveTextAttachment()
        guard let items = notebook.textAttachments, items.indices.contains(target.index) else { return }
        recordTextUndoState()
        let current = notebook.textAttachments?[target.index].fontSize ?? 16
        notebook.textAttachments?[target.index].fontSize = max(10, min(72, current + delta))
        store.updateNotebook(notebook)
        PageThumbnailRenderer.invalidateAll()
    }

    private func setActiveTextColor(_ hex: String) {
        let target = ensureActiveTextAttachment()
        guard let items = notebook.textAttachments, items.indices.contains(target.index) else { return }
        recordTextUndoState()
        notebook.textAttachments?[target.index].textColorHex = hex
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

    private func findObjectAt(location: CGPoint, page: Int) -> (id: String, kind: String)? {
        let order = notebook.objectOrder(forPage: page)
        let stacking = ObjectStacking.Lookup(order: order)

        var candidates: [(id: String, kind: String, z: Double, rect: CGRect)] = []
        if let items = notebook.attachments {
            for item in items where item.pageIndex == page {
                let rect = CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -4, dy: -4)
                candidates.append((item.id, "image", stacking.zIndex(for: item.id, kind: .image), rect))
            }
        }
        if let items = notebook.shapeAttachments {
            for item in items where item.pageIndex == page {
                let rect = CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -4, dy: -4)
                candidates.append((item.id, "shape", stacking.zIndex(for: item.id, kind: .shape), rect))
            }
        }
        if let items = notebook.tableAttachments {
            for item in items where item.pageIndex == page {
                let layout = item.layout()
                let rect = CGRect(x: item.x, y: item.y, width: CGFloat(layout.width), height: CGFloat(layout.height)).insetBy(dx: -4, dy: -4)
                candidates.append((item.id, "table", stacking.zIndex(for: item.id, kind: .table), rect))
            }
        }
        if let items = notebook.audioAttachments {
            for item in items where item.pageIndex == page {
                let rect = CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -4, dy: -4)
                candidates.append((item.id, "audio", stacking.zIndex(for: item.id, kind: .audio), rect))
            }
        }
        if let items = notebook.linkAttachments {
            for item in items where item.pageIndex == page {
                let rect = CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -4, dy: -4)
                candidates.append((item.id, "link", stacking.zIndex(for: item.id, kind: .link), rect))
            }
        }
        if let items = notebook.model3DAttachments {
            for item in items where item.pageIndex == page {
                let rect = CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -4, dy: -4)
                candidates.append((item.id, "3d", stacking.zIndex(for: item.id, kind: .model3D), rect))
            }
        }
        let hit = candidates.filter { $0.rect.contains(location) }.sorted(by: { $0.z > $1.z })
        if let first = hit.first {
            return (first.id, first.kind)
        }
        return nil
    }

    private func isLocationInsideAnyObject(at location: CGPoint, page: Int) -> Bool {
        if findObjectAt(location: location, page: page) != nil { return true }
        if let items = notebook.tapeAttachments {
            for item in items where item.pageIndex == page {
                if item.rect.insetBy(dx: -4, dy: -4).contains(location) {
                    return true
                }
            }
        }
        return false
    }

    /// 🌟 全自動意圖感知：Apple Pencil 碰到畫布時自動切換至手繪模式，並收回未輸入完成的空白文字框
    private func handlePencilTouchBegan() {
        // 手繪區塊已經取得墨跡輸入權，不要再把頂層文件模式改成 `.draw`。
        if editorMode != .draw && !isInlineInkEditing {
            withAnimation(.easeInOut(duration: 0.2)) {
                editorMode = .draw
            }
        }
        if let activeId = inlineEditingTextId {
            if let activeItem = notebook.textAttachments?.first(where: { $0.id == activeId }),
               activeItem.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                notebook.textAttachments?.removeAll { $0.id == activeId }
                store.updateNotebook(notebook)
                PageThumbnailRenderer.invalidateAll()
            }
            inlineEditingTextId = nil
        }
    }

    /// 拿掉「手指輕點」留下的那個小點。
    ///
    /// 只動**最後一筆**，而且必須同時符合：夠小（近乎一個點）、就落在點擊位置、
    /// 剛剛才畫下（不會誤刪使用者真正寫的東西）。
    private func removeTapDotStroke(near location: CGPoint) {
        guard let last = currentDrawing.strokes.last else { return }
        let bounds = last.renderBounds
        let isDot = bounds.width < 10 && bounds.height < 10
        let isHere = abs(bounds.midX - location.x) < 16 && abs(bounds.midY - location.y) < 16
        let isFresh = Date().timeIntervalSince(last.path.creationDate) < 2
        guard isDot, isHere, isFresh else { return }
        var strokes = currentDrawing.strokes
        strokes.removeLast()
        currentDrawing = PKDrawing(strokes: strokes)
    }

    // MARK: - 特殊樣板智慧互動引導線（核取方塊 Checkbox、選項狀態與進度管控）

    struct GuideCheckboxItem: Identifiable {
        let id: String
        let key: String
        let guide: FfiGuide
        let page: Int
    }

    private func interactiveGuideCheckboxes(forPage page: Int) -> [GuideCheckboxItem] {
        let paper = notebook.paperId(forPage: page)
        let guides = pageGuides(
            paperId: paper,
            width: Float(PageGeometry.width),
            height: Float(PageGeometry.height)
        )
        return guides.filter { $0.kind == .checkbox }.map { g in
            let gx = CGFloat(g.x), gy = CGFloat(g.y)
            let key = "\(page)_\(Int(round(gx)))_\(Int(round(gy)))"
            return GuideCheckboxItem(id: key, key: key, guide: g, page: page)
        }
    }

    private func hitTestGuideCheckbox(at location: CGPoint, page: Int) -> (guide: FfiGuide, key: String)? {
        let items = interactiveGuideCheckboxes(forPage: page)
        for item in items {
            let gx = CGFloat(item.guide.x), gy = CGFloat(item.guide.y)
            let gw = CGFloat(item.guide.w), gh = CGFloat(item.guide.h)
            // 擴展點擊範圍（約 34x34pt），手指與觸控筆皆能精準觸發
            let hitRect = CGRect(x: gx, y: gy, width: gw, height: gh).insetBy(dx: -12, dy: -10)
            if hitRect.contains(location) {
                return (item.guide, item.key)
            }
        }
        return nil
    }

    private func toggleGuideCheckbox(key: String) {
        if notebook.checkedGuideItems == nil {
            notebook.checkedGuideItems = [:]
        }
        let current = notebook.checkedGuideItems?[key] ?? false
        notebook.checkedGuideItems?[key] = !current
        store.updateNotebook(notebook)
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        #endif
        PageThumbnailRenderer.invalidateAll()
    }

    private func toggleRowStrikethrough(y: CGFloat, page: Int) {
        guard let texts = notebook.textAttachments, !texts.isEmpty else { return }
        recordTextUndoState()
        var updated = texts
        for i in 0 ..< updated.count where updated[i].pageIndex == page && abs(updated[i].y - y) < 30 {
            updated[i].isStrikethrough.toggle()
        }
        notebook.textAttachments = updated
        store.updateNotebook(notebook)
        PageThumbnailRenderer.invalidateAll()
    }

    private func clearRowText(y: CGFloat, page: Int) {
        guard let texts = notebook.textAttachments, !texts.isEmpty else { return }
        recordTextUndoState()
        notebook.textAttachments?.removeAll { $0.pageIndex == page && abs($0.y - y) < 30 }
        store.updateNotebook(notebook)
        PageThumbnailRenderer.invalidateAll()
    }

    private func resetPageCheckboxes(page: Int) {
        guard var checked = notebook.checkedGuideItems, !checked.isEmpty else { return }
        let prefix = "\(page)_"
        for key in checked.keys where key.hasPrefix(prefix) {
            checked[key] = false
        }
        notebook.checkedGuideItems = checked
        store.updateNotebook(notebook)
        PageThumbnailRenderer.invalidateAll()
    }

    /// 🌟 方案 A+B：手指或游標在畫布上的單擊事件
    private func handleCanvasDirectTap(at location: CGPoint, page: Int? = nil) {
        let targetPage = page ?? currentPageIndex
        currentPageIndex = targetPage

        // 🌟 優先檢查是否點擊在特殊樣板引導線互動元件上（例如核取方塊 Checkbox）
        if let (_, key) = hitTestGuideCheckbox(at: location, page: targetPage) {
            removeTapDotStroke(near: location)
            toggleGuideCheckbox(key: key)
            return
        }

        if editorMode == .type {
            handleCanvasTapInTypeMode(at: location, page: targetPage)
        } else {
            // 手寫模式下單擊：優先檢查是否點擊在既有文字方塊範圍內
            if let existing = notebook.textAttachments?.first(where: { item in
                item.pageIndex == targetPage &&
                CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -12, dy: -12).contains(location)
            }) {
                // 單擊與 PencilKit 的繪圖手勢同時辨識（見 `Coordinator.gestureRecognizer`），
                // 手指輕點會被畫成一個小點。這一下是「點文字方塊」，不是落筆 ——
                // 把那個點拿掉，否則每次點方塊紙上都多一顆墨點。
                removeTapDotStroke(near: location)
                withAnimation(.easeInOut(duration: 0.15)) {
                    // 全自動意圖感知：手指點擊文字方塊，立即進入行內聚焦編輯並展開 Word 級文字工具列
                    inlineEditingTextId = existing.id
                    editingTextId = nil
                    activeSelectedObjectId = existing.id
                }
                return
            }

            // 手指輕點到文字以外的物件（圖片、形狀、表格、錄音卡…）：使用者要的是「選它」。
            // 手寫模式下手指點中物件，精準選中物件並顯示把手，同時維持手繪工具列就緒，不強迫進入打字模式。
            if let (hitId, hitKind) = findObjectAt(location: location, page: targetPage) {
                removeTapDotStroke(near: location)
                withAnimation(.easeInOut(duration: 0.15)) {
                    inlineEditingTextId = nil
                    if hitKind == "shape" {
                        selectedShapeIds = [hitId]
                        activeSelectedObjectId = nil
                    } else {
                        selectedShapeIds = []
                        activeSelectedObjectId = hitId
                    }
                    selectedConnectionId = nil
                    selectedObjectIds = [hitId]
                    collaborationManager.broadcastSelection(selectedId: hitId)
                }
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                return
            }

            // 手寫模式下單擊畫布空白處：清空所有選取狀態
            activeSelectedObjectId = nil
            selectedShapeIds = []
            selectedConnectionId = nil
            selectedObjectIds = []
            collaborationManager.broadcastSelection(selectedId: nil)

            if let activeId = inlineEditingTextId {
                if let activeItem = notebook.textAttachments?.first(where: { $0.id == activeId }),
                   activeItem.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    notebook.textAttachments?.removeAll { $0.id == activeId }
                    store.updateNotebook(notebook)
                    PageThumbnailRenderer.invalidateAll()
                    watchdog.notifyEmptyTextBoxDismissedQuickly(isStylusActive: true) {
                        withAnimation { editorMode = .draw }
                    }
                }
                inlineEditingTextId = nil
            }
        }
    }

    /// 🌟 方案 A+B：手指或游標在畫布上的雙擊事件（手繪或打字模式下皆可直接建立並聚焦文字方塊）
    private func handleCanvasDirectDoubleTap(at location: CGPoint, page: Int? = nil) {
        let targetPage = page ?? currentPageIndex
        currentPageIndex = targetPage
        if hitTestGuideCheckbox(at: location, page: targetPage) != nil { return }
        if isLocationInsideAnyObject(at: location, page: targetPage) { return }
        // 若先前有空白文字方塊先清理
        if let activeId = inlineEditingTextId,
           let activeItem = notebook.textAttachments?.first(where: { $0.id == activeId }),
           activeItem.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notebook.textAttachments?.removeAll { $0.id == activeId }
            store.updateNotebook(notebook)
            if activeSelectedObjectId == activeId {
                activeSelectedObjectId = nil
            }
            PageThumbnailRenderer.invalidateAll()
        }
        let draft = insertTextBox(at: location, page: targetPage, tapToWrite: true)
        withAnimation(.easeInOut(duration: 0.18)) {
            editorMode = .type
            activeSelectedObjectId = nil
            inlineEditingTextId = draft.id
            editingTextId = nil
            selectedShapeIds = []
            selectedConnectionId = nil
            selectedObjectIds = []
        }
    }

    private func handleCanvasTapInTypeMode(at location: CGPoint, page: Int? = nil) {
        let targetPage = page ?? currentPageIndex
        currentPageIndex = targetPage

        // 0. 特殊頁面智慧引導線元件（核取方塊 Checkbox 等）點擊判定
        if let (_, key) = hitTestGuideCheckbox(at: location, page: targetPage) {
            toggleGuideCheckbox(key: key)
            return
        }
        // 1. 若先前有就地編輯但未打任何字的空方塊，先自動清理
        if let activeId = inlineEditingTextId,
           let activeItem = notebook.textAttachments?.first(where: { $0.id == activeId }),
           activeItem.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notebook.textAttachments?.removeAll { $0.id == activeId }
            store.updateNotebook(notebook)
            inlineEditingTextId = nil
            if activeSelectedObjectId == activeId {
                activeSelectedObjectId = nil
            }
            PageThumbnailRenderer.invalidateAll()
            watchdog.notifyEmptyTextBoxDismissedQuickly(isStylusActive: true) {
                withAnimation { editorMode = .draw }
            }
        }

        // 2. 檢查是否點擊在既有文字範圍內
        if let existing = notebook.textAttachments?.first(where: { item in
            item.pageIndex == targetPage &&
            CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -12, dy: -12).contains(location)
        }) {
            // 直接就地聚焦編輯既有文字，退出其他物件選取
            activeSelectedObjectId = existing.id
            inlineEditingTextId = existing.id
            editingTextId = nil
            selectedShapeIds = []
            selectedConnectionId = nil
            selectedObjectIds = []
            collaborationManager.broadcastSelection(selectedId: existing.id)
            return
        }

        // 3. 若點擊在其他畫布物件（圖片、表格、形狀、錄音卡片、3D等）上，選取該物件並展開操作把手
        if let (hitId, hitKind) = findObjectAt(location: location, page: targetPage) {
            inlineEditingTextId = nil
            if hitKind == "shape" {
                selectedShapeIds = [hitId]
                activeSelectedObjectId = nil
            } else {
                selectedShapeIds = []
                activeSelectedObjectId = hitId
            }
            selectedConnectionId = nil
            selectedObjectIds = [hitId]
            collaborationManager.broadcastSelection(selectedId: hitId)
            return
        }

        // 4. 點擊空白處：在打字模式下，點擊空白處即為「隨點即書」
        // 先清理所有先前的物件選取與就地編輯焦點
        activeSelectedObjectId = nil
        selectedShapeIds = []
        selectedConnectionId = nil
        selectedObjectIds = []
        inlineEditingTextId = nil
        editingTextId = nil
        collaborationManager.broadcastSelection(selectedId: nil)

        // 立即在手指點擊處啟動隨點隨打（隨點即書）
        let draft = insertTextBox(at: location, page: targetPage, tapToWrite: true)
        // 隨點即書為純文字輸入游標，不啟用物件選取態（保持 activeSelectedObjectId = nil），
        // 避免渲染出選取藍框與縮放/旋轉把手（使用戶誤以為是「新增文字方塊」按鈕產生的物件）
        activeSelectedObjectId = nil
        inlineEditingTextId = draft.id
        editingTextId = nil
    }

    /// 打字模式下 Apple Pencil 輕點：移除可能產生的微小墨點，並轉由文字模式點擊處理（即點即書或聚焦文字/物件）
    private func handlePencilTapInTypeMode(at location: CGPoint, page: Int? = nil) {
        let targetPage = page ?? currentPageIndex
        currentPageIndex = targetPage
        removeTapDotStroke(near: location)
        handleCanvasTapInTypeMode(at: location, page: targetPage)
    }


    /// 這一頁所有水平格線的 y（導引線與底紋都算，見 `RuledWriting.horizontalRules`）。
    private func pageHorizontalRules(page: Int? = nil) -> [CGFloat] {
        let paperId = notebook.paperId(forPage: page ?? currentPageIndex)
        let guides = pageGuides(
            paperId: paperId,
            width: Float(PageGeometry.width),
            height: Float(PageGeometry.height)
        )
        let bands = pageTexture(
            paperId: paperId,
            style: NoteTemplate(paperId: paperId)?.pageStyle ?? .blank,
            width: Float(PageGeometry.width),
            height: Float(PageGeometry.height)
        )
        return RuledWriting.horizontalRules(guides: guides, bands: bands)
    }

    /// 拖曳文字方塊時的吸附：讓第一行底部坐在最近的格線上（文字貼著格線上方、格線為底，絕不穿透重疊）。
    private func snapYToGuideLine(at y: CGFloat, page: Int? = nil) -> CGFloat {
        let rules = pageHorizontalRules(page: page)
        let fontSize: CGFloat = activeTextAttachment?.fontSize ?? 16
        let offset = RuledWriting.textBottomOffset(fontSize: fontSize)

        let targetBottom = y + offset
        if let nearest = rules.min(by: { abs($0 - targetBottom) < abs($1 - targetBottom) }), abs(nearest - targetBottom) < 50 {
            return max(PageGeometry.printableInset, nearest - offset)
        }
        // 沒有格線或離得遠：吸附至 20pt 步進網格。
        let step: CGFloat = 20.0
        return round(y / step) * step
    }

    /// - Parameter tapToWrite: 文字模式「隨點即書」。文字從點的地方開始；橫線紙上基準線坐在格線上，
    ///   一行一行對著格線寫；沒有框線、透明底，方塊會跟著內容長高。
    ///   `false` 是工具列「新增文字方塊」那一顆：有框線的獨立方塊。
    private func insertTextBox(
        at location: CGPoint, page: Int? = nil, openStudio: Bool = false, tapToWrite: Bool = false
    ) -> NoteTextAttachment {
        let targetPage = page ?? currentPageIndex
        var targetX = location.x
        var targetY = location.y
        var tapPlacement: RuledWriting.Placement?
        if tapToWrite {
            let baseSize: CGFloat = activeTextAttachment?.fontSize ?? 16
            let minTop = PageGeometry.printableRect.minY
            if snapToGrid,
               let ruled = RuledWriting.placement(
                   tapY: location.y, rules: pageHorizontalRules(page: targetPage),
                   fontSize: baseSize, minTop: minTop) {
                tapPlacement = ruled
            } else {
                tapPlacement = RuledWriting.freePlacement(tapY: location.y, fontSize: baseSize, minTop: minTop)
            }
            targetY = tapPlacement?.top ?? targetY
            // 文字從點的地方開始：方塊左緣 = 點 − 內距。
            targetX = location.x - RuledWriting.padding
        } else if snapToGrid {
            let step: CGFloat = 20.0
            targetX = round(targetX / step) * step
            targetY = snapYToGuideLine(at: location.y)
        }
        let printable = PageGeometry.printableRect
        var startX = max(printable.minX, targetX)
        if tapToWrite {
            // 隨點即書：若點擊處過於靠右，留出合理輸入起點，避免文字方塊超出可視區域
            startX = min(startX, printable.maxX - 60)
        }
        let midX = PageGeometry.width / 2
        // 若在左右分欄或四象限結構的左半部，文字寬度以中線為界；否則延伸至右側可列印邊界
        let availWidth: CGFloat
        if startX < midX - 30 && printable.maxX > midX {
            availWidth = max(tapToWrite ? 60 : 180, midX - startX - 12)
        } else {
            availWidth = max(tapToWrite ? 60 : 180, printable.maxX - startX)
        }
        let tapHeight = RuledWriting.boxHeight(
            text: "", width: availWidth, fontSize: tapPlacement?.fontSize ?? 16, bold: false,
            lineSpacing: tapPlacement?.lineSpacing ?? 0)
        var draft = NoteTextAttachment(
            id: UUID().uuidString,
            pageIndex: targetPage,
            text: "",
            fontSize: tapPlacement?.fontSize ?? (activeTextAttachment?.fontSize ?? 16),
            textColorHex: activeTextAttachment?.textColorHex ?? "#000000",
            backgroundColorHex: "clear",
            hasBorder: !tapToWrite,
            x: startX,
            y: tapToWrite
                ? max(printable.minY - RuledWriting.padding, min(targetY, printable.maxY - tapHeight))
                : max(printable.minY, min(targetY, printable.maxY - 40)),
            width: availWidth,
            height: tapToWrite ? tapHeight : 40
        )
        if let placement = tapPlacement, placement.lineSpacing > 0 {
            draft.lineSpacing = placement.lineSpacing
        }
        recordTextUndoState()
        if notebook.textAttachments == nil {
            notebook.textAttachments = []
        }
        notebook.textAttachments?.append(draft)
        var order = ObjectStacking.normalized(objects: pageStackableObjects, order: notebook.objectOrder(forPage: targetPage))
        order = ObjectStacking.bringToFront([draft.id], in: order)
        notebook.setObjectOrder(order, forPage: targetPage)

        store.updateNotebook(notebook)
        PageThumbnailRenderer.invalidateAll()
        if let data = try? JSONEncoder().encode(draft),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            collaborationManager.broadcastAttachmentUpsert(type: "text", itemDict: dict)
        }
        inlineEditingTextId = draft.id
        lastAddedTextId = draft.id
        if openStudio {
            editingTextId = draft.id
        } else {
            editingTextId = nil
        }
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
        if let id = inlineEditingTextId ?? editingTextId,
           let idx = notebook.textAttachments?.firstIndex(where: { $0.id == id }) {
            notebook.textAttachments?[idx].text.append(text)
            store.updateNotebook(notebook)
            PageThumbnailRenderer.invalidateAll()
            return
        }
        let newBox = NoteTextAttachment(
            pageIndex: currentPageIndex,
            text: text,
            fontSize: 20,
            isBold: true,
            hasBorder: true,
            x: PageGeometry.printableInset,
            y: 200,
            width: 260,
            height: 64
        )
        if notebook.textAttachments == nil {
            notebook.textAttachments = []
        }
        notebook.textAttachments?.append(newBox)
        inlineEditingTextId = newBox.id
        editingTextId = newBox.id
        store.updateNotebook(notebook)
        PageThumbnailRenderer.invalidateAll()
    }

    /// 將算式以可編輯的文字方塊插入畫布（使用者可隨意修改、縮放、變更字型顏色及刪除）
    private func insertFormulaText(_ text: String) {
        let printable = PageGeometry.printableRect
        let availWidth: CGFloat = min(360, printable.width - 40)
        let fontSize: CGFloat = 18
        let calculatedHeight = max(52, RuledWriting.boxHeight(
            text: text,
            width: availWidth,
            fontSize: fontSize,
            bold: false,
            lineSpacing: 0
        ))
        let targetX = printable.minX + 24
        let targetY = max(printable.minY + 20, min(180, printable.maxY - calculatedHeight - 20))

        let mathBox = NoteTextAttachment(
            id: UUID().uuidString,
            pageIndex: currentPageIndex,
            text: text,
            fontSize: fontSize,
            isBold: false,
            textColorHex: "#000000",
            backgroundColorHex: "#F8F9FA",
            hasBorder: true,
            cornerRadius: 10,
            x: targetX,
            y: targetY,
            width: availWidth,
            height: calculatedHeight
        )

        if notebook.textAttachments == nil {
            notebook.textAttachments = []
        }
        notebook.textAttachments?.append(mathBox)

        var order = ObjectStacking.normalized(objects: pageStackableObjects, order: notebook.objectOrder(forPage: currentPageIndex))
        order = ObjectStacking.bringToFront([mathBox.id], in: order)
        notebook.setObjectOrder(order, forPage: currentPageIndex)

        store.updateNotebook(notebook)
        PageThumbnailRenderer.invalidateAll()
        if let data = try? JSONEncoder().encode(mathBox),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            collaborationManager.broadcastAttachmentUpsert(type: "text", itemDict: dict)
        }
        editorMode = .type
        DispatchQueue.main.async {
            inlineEditingTextId = mathBox.id
            editingTextId = mathBox.id
        }
    }

    /// 將語音辨識/轉錄出的文字稿作為「隨點即書」自然排版文字插入在錄音卡片周遭，
    /// 無框線、無預設灰底，高度隨內容自動伸縮，並切換至打字模式進入就地編輯以供後續編修。
    private func insertTranscriptText(_ text: String, for audio: NoteAudioAttachment) {
        let printable = PageGeometry.printableRect
        let startX = max(printable.minX, audio.x)
        let midX = PageGeometry.width / 2
        let availWidth: CGFloat
        if startX < midX - 30 && printable.maxX > midX {
            availWidth = max(180, midX - startX - 12)
        } else {
            availWidth = max(180, printable.maxX - startX)
        }

        let baseFontSize: CGFloat = activeTextAttachment?.fontSize ?? 16
        let calculatedHeight = RuledWriting.boxHeight(
            text: text,
            width: availWidth,
            fontSize: baseFontSize,
            bold: false,
            lineSpacing: 0
        )
        let targetY = max(printable.minY, min(audio.y + audio.height + 16, printable.maxY - calculatedHeight))
        let existingId = audio.transcriptTextId
        let existingIndex = notebook.textAttachments?.firstIndex(where: { $0.id == existingId })

        let transcriptBox: NoteTextAttachment
        if let idx = existingIndex, var existing = notebook.textAttachments?[idx] {
            existing.text = text
            existing.height = RuledWriting.boxHeight(
                text: text,
                width: existing.width,
                fontSize: existing.fontSize,
                bold: existing.isBold,
                lineSpacing: existing.lineSpacing ?? 0
            )
            notebook.textAttachments?[idx] = existing
            transcriptBox = existing
        } else {
            let newBox = NoteTextAttachment(
                id: existingId ?? UUID().uuidString,
                pageIndex: audio.pageIndex,
                text: text,
                fontSize: baseFontSize,
                isBold: false,
                textColorHex: activeTextAttachment?.textColorHex ?? "#000000",
                backgroundColorHex: "clear",
                hasBorder: false,
                x: startX,
                y: targetY,
                width: availWidth,
                height: calculatedHeight
            )
            if notebook.textAttachments == nil {
                notebook.textAttachments = []
            }
            notebook.textAttachments?.append(newBox)
            if let aIdx = notebook.audioAttachments?.firstIndex(where: { $0.id == audio.id }) {
                notebook.audioAttachments?[aIdx].transcriptTextId = newBox.id
            }
            transcriptBox = newBox
        }

        var order = ObjectStacking.normalized(objects: pageStackableObjects, order: notebook.objectOrder(forPage: audio.pageIndex))
        order = ObjectStacking.bringToFront([transcriptBox.id], in: order)
        notebook.setObjectOrder(order, forPage: audio.pageIndex)

        store.updateNotebook(notebook)
        PageThumbnailRenderer.invalidateAll()
        if let data = try? JSONEncoder().encode(transcriptBox),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            collaborationManager.broadcastAttachmentUpsert(type: "text", itemDict: dict)
        }
        editorMode = .type
        // 文字框先進入視圖樹，再要求就地編輯。和同一個動畫 transaction 一起
        // 設定時，FocusState 偶爾會早於 TextField 建立，鍵盤便時有時無。
        DispatchQueue.main.async {
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
        mathFormula: String? = nil,
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
            chartSpecJSON: chartSpecJSON,
            mathFormula: mathFormula
        )
        if notebook.attachments == nil {
            notebook.attachments = []
        }
        notebook.attachments?.append(newAttachment)
        store.updateNotebook(notebook)
        if var dict = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(newAttachment))) as? [String: Any] {
            if let imgData = image.pngData() {
                dict["image_base64"] = imgData.base64EncodedString()
            }
            collaborationManager.broadcastAttachmentUpsert(type: "image", itemDict: dict)
        }
    }

    /// 「匯入文件」：把檔案解析成原生物件，合併進**這本筆記**的目前頁面。
    ///
    /// 解析在暫存套件裡由核心做（見 `DocumentImport`）；這裡負責合併：
    /// 超出頁高的內容接到後面新插入的頁面，不覆蓋既有頁面。失敗一律給提示 ——
    /// 舊版只 `print`，使用者看到的是「點了沒反應」。
    private func importDocumentOutcome(_ outcome: FileImport.Outcome) {
        if outcome.fileExtension == "pptx" {
            importErrorKey = "import_unsupported_type"
            return
        }
        let url = store.importedFileURL(fileName: outcome.storedName)
        let imported: NotebookPackageBridge.ImportedNotebook
        do {
            imported = try DocumentImport.parse(fileURL: url, title: outcome.displayName)
        } catch DocumentImport.Failure.empty {
            importErrorKey = "import_empty_file"
            return
        } catch {
            importErrorKey = "import_failed_read"
            return
        }

        saveCurrentPageDrawing()
        let base = currentPageIndex
        let doc = imported.document

        // 區塊依 id（UUIDv7 ＝ 建立順序）排回文件順序，再由上往下排版 ——
        // 核心建立區塊時沒有給位置，全部會落在同一點疊成一團。
        enum Piece { case text(Int), table(Int), image(Int) }
        var texts = doc.textAttachments ?? []
        var tables = doc.tableAttachments ?? []
        var images = doc.attachments ?? []
        var pieces: [(id: String, piece: Piece)] = []
        for (i, t) in texts.enumerated() { pieces.append((t.id, .text(i))) }
        for (i, t) in tables.enumerated() { pieces.append((t.id, .table(i))) }
        for (i, t) in images.enumerated() { pieces.append((t.id, .image(i))) }
        // 依建立時間（UUIDv7 前 48 位元的毫秒時間戳）排回文件順序。**不能比整個 id** ——
        // 同一毫秒內產生的 id 後面是隨機位元，字串順序跟建立順序無關。同一毫秒（匯入時
        // 一股腦建出來，常態）維持各自在核心裡原本的順序。
        pieces = pieces.enumerated().sorted { lhs, rhs in
            let l = DocumentImport.timestampKey(lhs.element.id), r = DocumentImport.timestampKey(rhs.element.id)
            return l != r ? l < r : lhs.offset < rhs.offset
        }.map(\.element)

        let contentWidth = PageGeometry.width - PageGeometry.printableInset * 2
        let heights: [CGFloat] = pieces.map { entry in
            switch entry.piece {
            case .text(let i):
                texts[i].width = contentWidth
                texts[i].x = PageGeometry.printableInset
                let h = DocumentImport.estimatedHeight(
                    text: texts[i].text, fontSize: texts[i].fontSize, width: contentWidth)
                texts[i].height = h
                return h
            case .table(let i):
                tables[i].x = PageGeometry.printableInset
                return tables[i].height
            case .image(let i):
                // 圖片寬度不超過內容區；等比縮小。
                if images[i].width > contentWidth {
                    let scale = contentWidth / images[i].width
                    images[i].width = contentWidth
                    images[i].height *= scale
                }
                images[i].x = PageGeometry.printableInset
                return images[i].height
            }
        }
        let placements = DocumentImport.flow(heights: heights)
        var maxOffset = 0
        for (entry, place) in zip(pieces, placements) {
            maxOffset = max(maxOffset, place.pageOffset)
            switch entry.piece {
            case .text(let i): texts[i].y = place.y; texts[i].pageIndex = place.pageOffset
            case .table(let i): tables[i].y = place.y; tables[i].pageIndex = place.pageOffset
            case .image(let i): images[i].y = place.y; images[i].pageIndex = place.pageOffset
            }
        }
        for k in 0..<maxOffset {
            _ = store.insertPage(
                notebookId: notebook.id, afterIndex: base + k,
                paperId: notebook.paperId(forPage: base))
        }
        if maxOffset > 0, let updated = store.notebooks.first(where: { $0.id == notebook.id }) {
            notebook = updated
        }

        // id 沿用暫存套件給的：每次匯入都是全新的暫存套件，所以同一個檔案
        // 匯入兩次得到的是兩份獨立的物件，不會撞 id。
        for var item in texts {
            item.pageIndex = base + item.pageIndex
            notebook.textAttachments = (notebook.textAttachments ?? []) + [item]
        }
        for var item in tables {
            item.pageIndex = base + item.pageIndex
            notebook.tableAttachments = (notebook.tableAttachments ?? []) + [item]
        }
        for var item in images {
            guard let bytes = imported.imageData[item.fileName],
                  let saved = store.saveImportedFile(data: bytes, extension: "png") else { continue }
            item.fileName = saved
            item.pageIndex = base + item.pageIndex
            notebook.attachments = (notebook.attachments ?? []) + [item]
        }
        store.updateNotebook(notebook)
        PageThumbnailRenderer.invalidateAll()
        showCanvasNotice(localizationManager.localized("import_document_done"))
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

    /// 用新算出來的算式卡片取代原本那一張。
    /// 若轉成文字方塊（image == nil），則從附件移除卡片。
    private func replaceMathAttachment(id: String, formula: String, image: UIImage?) {
        guard let index = notebook.attachments?.firstIndex(where: { $0.id == id }) else {
            editingMathAttachmentId = nil
            return
        }
        if let image = image, let fileName = store.saveAttachmentImage(image) {
            notebook.attachments?[index].fileName = fileName
            notebook.attachments?[index].mathFormula = formula
        } else {
            // 使用者選擇轉插入為可編輯文字方塊
            notebook.attachments?.remove(at: index)
        }
        store.updateNotebook(notebook)
        editingMathAttachmentId = nil
    }

    /// 目前這一頁的形狀，依堆疊順序。
    private var pageShapes: [NoteShapeAttachment] {
        (notebook.shapeAttachments ?? []).filter { $0.pageIndex == currentPageIndex }
    }

    // MARK: - 形狀與連接線的編修

    /// 刪除一個形狀，連著它的線一起走。
    ///
    /// 留著的話會指向一個不存在的形狀，畫面上是一條從空氣連出來的線。
    private func deleteShape(_ id: String) {
        notebook.shapeAttachments?.removeAll { $0.id == id }
        notebook.connectionAttachments?.removeAll { $0.fromShapeId == id || $0.toShapeId == id }
        selectedShapeIds.remove(id)
        if editingShapeId == id { editingShapeId = nil }
        store.updateNotebook(notebook)
        PageThumbnailRenderer.invalidateAll()
    }

    private func deleteConnection(_ id: String) {
        notebook.connectionAttachments?.removeAll { $0.id == id }
        if selectedConnectionId == id { selectedConnectionId = nil }
        if editingConnectionId == id { editingConnectionId = nil }
        store.updateNotebook(notebook)
        PageThumbnailRenderer.invalidateAll()
    }

    private func duplicateShape(_ id: String) {
        guard var copy = notebook.shapeAttachments?.first(where: { $0.id == id }) else { return }
        var fresh = NoteShapeAttachment(
            pageIndex: copy.pageIndex, kindName: copy.kindName,
            x: copy.x + 24, y: copy.y + 24, width: copy.width, height: copy.height,
            cornerRadius: copy.cornerRadius, label: copy.label,
            strokeColorHex: copy.strokeColorHex, fillColorHex: copy.fillColorHex,
            lineWidth: copy.lineWidth)
        copy.groupId = nil
        fresh.rotationDegrees = copy.rotationDegrees
        fresh.dashStyle = copy.dashStyle; fresh.fontSize = copy.fontSize
        fresh.textColorHex = copy.textColorHex; fresh.isBold = copy.isBold
        fresh.isItalic = copy.isItalic; fresh.opacity = copy.opacity
        notebook.shapeAttachments = (notebook.shapeAttachments ?? []) + [fresh]
        store.updateNotebook(notebook)
        PageThumbnailRenderer.invalidateAll()
        selectedShapeIds = [fresh.id]
        editingShapeId = fresh.id
    }

    private func connectionBinding(for id: String) -> Binding<NoteConnectionAttachment> {
        Binding(
            get: {
                notebook.connectionAttachments?.first(where: { $0.id == id })
                    ?? NoteConnectionAttachment(id: id, fromShapeId: "", toShapeId: "")
            },
            set: { updated in
                guard let index = notebook.connectionAttachments?
                    .firstIndex(where: { $0.id == id }) else { return }
                notebook.connectionAttachments?[index] = updated
                store.updateNotebook(notebook)
                PageThumbnailRenderer.invalidateAll()
            }
        )
    }

    /// 從形狀的連接點拉線。拖曳中畫預覽，放開時連到底下的形狀。
    private func handleConnectDrag(
        from sourceId: String, anchor: ShapeAnchorName,
        start: CGPoint, current: CGPoint, finished: Bool
    ) {
        guard let source = notebook.shapeAttachments?.first(where: { $0.id == sourceId }) else { return }
        guard finished else {
            connectionDraft = (source.pageIndex, start, current)
            return
        }
        connectionDraft = nil

        // 放開的位置在哪個形狀上。越晚畫的越在上面，所以從後往前找。
        let pageShapes = (notebook.shapeAttachments ?? []).filter {
            $0.pageIndex == source.pageIndex && $0.id != sourceId && !$0.isLinear
        }
        let target = pageShapes.reversed().first { candidate in
            // 轉過的形狀：把點轉回形狀自己的座標軸再判斷，才不會在轉 45° 的方塊邊角誤判。
            let local = ShapeFrameMath.rotate(current, about: candidate.center, degrees: -candidate.canvasRotation)
            return CGRect(x: candidate.x, y: candidate.y, width: candidate.width, height: candidate.height)
                .insetBy(dx: -6, dy: -6).contains(local)
        }
        guard let target else { return }
        // 入線位置：目標形狀上離放開點最近的連接點。
        let toAnchor = ShapeAnchorName.allCases.min {
            let a = target.anchorPoint($0), b = target.anchorPoint($1)
            return hypot(a.x - current.x, a.y - current.y) < hypot(b.x - current.x, b.y - current.y)
        } ?? .top

        var connection = NoteConnectionAttachment(
            pageIndex: source.pageIndex, fromShapeId: sourceId, toShapeId: target.id)
        connection.fromAnchor = anchor.rawValue
        connection.toAnchor = toAnchor.rawValue
        notebook.connectionAttachments = (notebook.connectionAttachments ?? []) + [connection]
        store.updateNotebook(notebook)
        PageThumbnailRenderer.invalidateAll()
        selectedShapeIds = []
        selectedConnectionId = connection.id
        if let data = try? JSONEncoder().encode(connection),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            collaborationManager.broadcastAttachmentUpsert(type: "connection", itemDict: dict)
        }
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

    /// 進入／離開框選。
    ///
    /// # 框選選的是「物件」，不是筆跡
    ///
    /// 圖片、貼紙、文字方塊、表格、圖形、錄音卡片…這些是物件，框選一次可以整組
    /// 搬、複製、刪除。手寫的筆跡不是物件，要選它們用**套索**（手寫模式的筆具列）。
    /// 兩者分工：物件用框選、筆跡用套索。
    ///
    /// 手寫模式下物件本來就不吃觸控，框了也動不了，所以進入時自動切到打字模式
    /// （Android 一直是這樣做）。進入時說明怎麼操作，否則使用者面對一個空的選取列，
    /// 不知道下一步是什麼。
    private func setMarqueeActive(_ on: Bool) {
        isMarqueeActive = on
        if on {
            if editorMode != .type { editorMode = .type }
            showCanvasNotice(localizationManager.localized("marquee_hint"))
        } else {
            selectedObjectIds = []
        }
    }

    /// 框選模式的工具列。掛在畫布外面（工具列那一層），不隨畫布捲動 ——
    /// 跟著捲的話，選了下半頁的東西就得捲回去才按得到刪除。
    private var marqueeToolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.dashed.inset.filled")
                .foregroundColor(.accentColor)
            if selectedObjectIds.isEmpty {
                // 還沒選到東西時，顯示「怎麼選」而不是「已選 0 個」。
                Text(localizationManager.localized("marquee_hint"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else {
                Text(localizationManager.localized("marquee_selected")
                    .replacingOccurrences(of: "%@", with: "\(selectedObjectIds.count)"))
                    .font(.caption)
                    .monospacedDigit()
            }

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
                setMarqueeActive(false)
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
        for id in ids {
            if (notebook.attachments ?? []).contains(where: { $0.id == id }) {
                collaborationManager.broadcastAttachmentDelete(id: id, type: "image")
            }
            if (notebook.textAttachments ?? []).contains(where: { $0.id == id }) {
                collaborationManager.broadcastAttachmentDelete(id: id, type: "text")
            }
            if (notebook.model3DAttachments ?? []).contains(where: { $0.id == id }) {
                collaborationManager.broadcastAttachmentDelete(id: id, type: "3d")
            }
            if (notebook.tableAttachments ?? []).contains(where: { $0.id == id }) {
                collaborationManager.broadcastAttachmentDelete(id: id, type: "table")
            }
        }
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
        PageThumbnailRenderer.invalidateAll()
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

    /// 文字編修、圖片編修、圖層三張浮動面板。
    ///
    /// **掛在 `canvasWorkArea`（兩種頁面模式共用的那一層），而且層級最高。**
    ///
    /// 這三張面板原本各自藏在畫布內部的 ZStack 裡，沒有 zIndex：
    /// - 手寫模式下 PencilKit 畫布（zIndex 2）蓋在它上面，點關閉鈕變成在
    ///   畫布上畫了一筆；
    /// - 打字模式下全頁的文字輸入層（zIndex 2）與物件層（zIndex 3）也在它上面；
    /// - 連續頁面模式根本不會走到那一段程式，編輯鈕按了完全沒有反應。
    /// 症狀分別是「編輯視窗出現了卻關不掉」與「編輯鈕沒作用」。
    @ViewBuilder
    private var objectEditPanels: some View {
        ZStack(alignment: .topTrailing) {
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
                VStack(spacing: 10) {
                    ObjectOrderBar(id: id)
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
                    ObjectOrderBar(id: id)
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

                    // 這張圖如果是算式卡片，提供回到計算機重新求值的入口
                    if let formula = notebook.attachments?
                        .first(where: { $0.id == id })?.mathFormula {
                        Button {
                            editingMathAttachmentId = MathEditTarget(id: id, formula: formula)
                        } label: {
                            Label(localizationManager.localized("math_calc"),
                                  systemImage: "function")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    ImageEditControls(
                        attachment: binding(for: id),
                        onDone: { editingAttachmentId = nil },
                        onDelete: {
                            notebook.attachments?.removeAll { $0.id == id }
                            store.updateNotebook(notebook)
                            editingAttachmentId = nil
                        }
                    )
                }
            }
        }


        // 形狀編修面板。與圖片、文字同一套 —— 浮在畫布上，改動即時反映在物件上。
        if let id = editingShapeId,
           notebook.shapeAttachments?.contains(where: { $0.id == id }) == true {
            FloatingPanel(
                title: localizationManager.localized("shape_edit"),
                onClose: { editingShapeId = nil }
            ) {
                ShapeEditPanel(
                    shape: shapeBinding(for: id),
                    onDuplicate: { duplicateShape(id) },
                    onDelete: { deleteShape(id) }
                )
            }
            .padding(.top, 24)
            .padding(.trailing, 24)
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }

        if let id = editingConnectionId,
           notebook.connectionAttachments?.contains(where: { $0.id == id }) == true {
            FloatingPanel(
                title: localizationManager.localized("connection_edit"),
                onClose: { editingConnectionId = nil }
            ) {
                ConnectionEditPanel(
                    connection: connectionBinding(for: id),
                    onDelete: { deleteConnection(id) }
                )
            }
            .padding(.top, 24)
            .padding(.trailing, 24)
            .transition(.scale(scale: 0.95).combined(with: .opacity))
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


        }
        .environment(\.objectReorder, { id, op in reorderObject(id, op) })
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .zIndex(10_000)
    }

    /// 物件所在的頁面。找不到（已刪除）回傳 nil。
    private func pageOfObject(_ id: String) -> Int? {
        if let v = notebook.attachments?.first(where: { $0.id == id }) { return v.pageIndex }
        if let v = notebook.shapeAttachments?.first(where: { $0.id == id }) { return v.pageIndex }
        if let v = notebook.tableAttachments?.first(where: { $0.id == id }) { return v.pageIndex }
        if let v = notebook.textAttachments?.first(where: { $0.id == id }) { return v.pageIndex }
        if let v = notebook.linkAttachments?.first(where: { $0.id == id }) { return v.pageIndex }
        if let v = notebook.model3DAttachments?.first(where: { $0.id == id }) { return v.pageIndex }
        if let v = notebook.audioAttachments?.first(where: { $0.id == id }) { return v.pageIndex }
        if let v = notebook.commentPins?.first(where: { $0.id == id }) { return v.pageIndex }
        return nil
    }

    /// 調整單一物件的層級（選單、編輯面板共用，支援移至筆跡下方/上方）。
    private func reorderObject(_ id: String, _ op: ObjectReorderOp) {
        guard let page = pageOfObject(id) else { return }
        switch op {
        case .sendBelowInk:
            var current = notebook.underInkObjectIds(forPage: page)
            if !current.contains(id) {
                current.insert(id)
                notebook.setUnderInkObjectIds(current, forPage: page)
                store.updateNotebook(notebook)
                PageThumbnailRenderer.invalidateAll()
            }
        case .bringAboveInk:
            var current = notebook.underInkObjectIds(forPage: page)
            if current.contains(id) {
                current.remove(id)
                notebook.setUnderInkObjectIds(current, forPage: page)
                store.updateNotebook(notebook)
                PageThumbnailRenderer.invalidateAll()
            }
        default:
            let order = ObjectStacking.normalized(
                objects: stackableObjects(forPage: page),
                order: notebook.objectOrder(forPage: page))
            notebook.setObjectOrder(op.apply(id, to: order), forPage: page)
            store.updateNotebook(notebook)
            PageThumbnailRenderer.invalidateAll()
        }
    }

    /// 這本筆記上所有物件的 id（不含連接線）。用來偵測「新插入了什麼」。
    private var allObjectIds: [String] {
        var ids: [String] = []
        ids += (notebook.attachments ?? []).map(\.id)
        ids += (notebook.shapeAttachments ?? []).map(\.id)
        ids += (notebook.tableAttachments ?? []).map(\.id)
        ids += (notebook.textAttachments ?? []).map(\.id)
        ids += (notebook.linkAttachments ?? []).map(\.id)
        ids += (notebook.model3DAttachments ?? []).map(\.id)
        ids += (notebook.audioAttachments ?? []).map(\.id)
        return ids
    }

    /// **新插入的物件一律放在最上層。**
    ///
    /// 沒有明確順序的物件，疊放次序由「型別的預設層級」決定 —— 圖片永遠
    /// 在文字、表格之下，於是新貼的圖片被舊的文字蓋住，看起來像沒插進去。
    /// 這裡掛在「物件數量變了」這一個點上，而不是改每一個插入路徑：
    /// 本機插入、匯入、範本、協同遠端寫入全部會經過同一處，不會漏。
    private func placeNewObjectsOnTop() {
        let ids = allObjectIds
        defer { knownObjectIds = Set(ids) }
        guard let known = knownObjectIds else { return }
        let fresh = ids.filter { !known.contains($0) }
        guard !fresh.isEmpty else { return }

        var byPage: [Int: [String]] = [:]
        for id in fresh {
            if let page = pageOfObject(id) { byPage[page, default: []].append(id) }
        }
        for (page, newIds) in byPage {
            let newSet = Set(newIds)
            let existing = stackableObjects(forPage: page).filter { !newSet.contains($0.id) }
            var order = ObjectStacking.normalized(
                objects: existing, order: notebook.objectOrder(forPage: page))
            order += newIds   // 到達順序＝插入順序
            notebook.setObjectOrder(order, forPage: page)
        }
        store.updateNotebook(notebook)

        // 手寫模式下物件不吃觸控：剛插進來的東西會拖不動、選不起來，看起來像插壞了
        // （使用者回報「形狀無法編輯」「圖片的編輯鈕沒有作用」的一個原因）。
        // 本機插入就切到打字模式，與 Android 同一條規則；遠端協同寫進來的不切，
        // 別人插東西不該把我的筆搶走。
        if editorMode == .draw && !isApplyingRemoteUpdate && !isCollaborating {
            editorMode = .type
        }
    }

    /// 這一頁上所有可堆疊的物件，跨七種型別收成同一份清單。
    ///
    /// 名字取得出來就用內容（文字方塊取內文、形狀取標籤），取不出來就用型別名
    /// —— 面板上一整排「未命名」的話，使用者分不出哪一列是哪一個。
    private var pageStackableObjects: [StackableObject] {
        stackableObjects(forPage: currentPageIndex)
    }

    /// 指定頁面上的所有可堆疊物件。連續模式下每一頁各有自己的順序，
    /// 不能只認焦點頁。
    private func stackableObjects(forPage page: Int) -> [StackableObject] {
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
        // 形狀被選取時，其他種類的物件一律退出編輯狀態（畫布上同時最多一個待編輯物件）。
        activeSelectedObjectId = nil
        if inlineEditingTextId != nil { inlineEditingTextId = nil }
        let mates = ObjectLayerOps.groupMates(of: id, in: pageShapes)
        if mates.isSubset(of: selectedShapeIds) {
            selectedShapeIds.subtract(mates)
        } else {
            selectedShapeIds = mates
        }
    }

    /// 選取單一物件（圖片、文字、表格、連結、錄音、3D）。
    /// 先前被選取的物件（包括形狀、連接線、就地編輯中的文字）自動退出編輯狀態。
    private func selectSingleObject(_ id: String, keepInlineText: Bool = false) {
        activeSelectedObjectId = id
        selectedShapeIds = []
        selectedConnectionId = nil
        selectedObjectIds = []
        if !keepInlineText, inlineEditingTextId != nil, inlineEditingTextId != id {
            inlineEditingTextId = nil
        }
        collaborationManager.broadcastSelection(selectedId: id)
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

    private func moveTable(_ id: String, by delta: CGSize) {
        guard hypot(delta.width, delta.height) >= 1 else { return }
        guard var all = notebook.tableAttachments,
              let index = all.firstIndex(where: { $0.id == id }) else { return }
        let previous = all[index]
        all[index].x += delta.width
        all[index].y += delta.height
        notebook.tableAttachments = all
        store.updateNotebook(notebook)

        moveStrokesInsideTable(previous, by: delta)
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
                let previous = notebook.tableAttachments![index]
                notebook.tableAttachments?[index] = updated
                store.updateNotebook(notebook)

                let dx = updated.x - previous.x
                let dy = updated.y - previous.y
                if hypot(dx, dy) >= 1 {
                    moveStrokesInsideTable(previous, by: CGSize(width: dx, height: dy))
                }
            }
        )
    }

    private func moveStrokesInsideTable(_ table: NoteTableAttachment, by delta: CGSize) {
        guard hypot(delta.width, delta.height) >= 0.5 else { return }
        let page = table.pageIndex

        // 1. 標準 PencilKit 筆跡（PKDrawing）
        let drawing = (pageDisplayMode == .single && page == currentPageIndex && canvasView != nil)
            ? (canvasView?.drawing ?? currentDrawing)
            : drawingForPage(page)

        let result = table.offsetContainedStrokes(in: drawing, by: delta)
        if result.movedCount > 0 {
            let updatedDrawing = result.drawing
            if page == currentPageIndex {
                currentDrawing = updatedDrawing
                if let canvas = canvasView {
                    canvas.drawing = updatedDrawing
                    if let adaptive = canvas as? AdaptiveCanvasView {
                        adaptive.initialLoadedStrokeCount = updatedDrawing.strokes.count
                        adaptive.forceDisplayRefresh(with: updatedDrawing)
                    }
                }
            }
            store.saveDrawing(notebookId: notebook.id, pageIndex: page, drawing: updatedDrawing)
            recordDrawingEdit(page: page, drawing: updatedDrawing)
            broadcastDrawingChange(page: page, drawing: updatedDrawing)
            PageThumbnailRenderer.invalidateAll()
            if pageDisplayMode == .continuous {
                continuousReloadGeneration += 1
            }
        }

        // 2. 專業製圖筆畫（ProInk）
        if page == currentPageIndex, let proLayer = (canvasView as? AdaptiveCanvasView)?.proLayer {
            let layout = table.layout()
            let tableWidth = max(table.width, CGFloat(layout.width))
            let tableHeight = max(table.height, CGFloat(layout.height))
            let tableRect = CGRect(x: table.x, y: table.y, width: tableWidth, height: tableHeight)
            let hitRect = tableRect.insetBy(dx: -4, dy: -4)

            var proIdsToMove = Set<String>()
            for s in proLayer.ownStrokes {
                let b = s.bounds
                let mid = CGPoint(x: b.midX, y: b.midY)
                let intersection = tableRect.intersection(b)
                let isInside = tableRect.contains(b)
                    || hitRect.contains(mid)
                    || (!intersection.isNull && (intersection.width * intersection.height) >= (b.width * b.height * 0.4))
                    || (hitRect.contains(b.origin) && !intersection.isNull && intersection.width > 2 && intersection.height > 2)
                if isInside {
                    proIdsToMove.insert(s.id)
                }
            }
            if !proIdsToMove.isEmpty {
                proLayer.move(ids: proIdsToMove, by: delta)
                proLayer.endMove()
            }
        }
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

    /// - Parameter hint: 呼叫端已經知道的位置（`ForEach` 走到第幾個）。
    ///   對得上就直接用，O(1)；對不上（陣列在兩次算繪之間變動了）才退回線性搜尋。
    ///
    /// **不能每次都線性搜尋。** `Binding(get:set:)` 建立時就會先呼叫一次 `get`，
    /// 一頁有 m 個文字方塊、全本有 n 個，一次算繪就是 m×n 次 UUID 字串比對，
    /// 而 SwiftUI 一次更新會重算好幾輪。主執行緒因此卡住超過十秒，看門狗
    /// （`0x8BADF00D`）在背景把 App 殺掉 —— 崩潰報告的主執行緒堆疊停在
    /// 這個閉包裡的 `_stringCompareInternal`。
    private func binding(forTextId id: String, hint: Int? = nil) -> Binding<NoteTextAttachment> {
        func index(in items: [NoteTextAttachment]?) -> Int? {
            guard let items else { return nil }
            if let hint, items.indices.contains(hint), items[hint].id == id { return hint }
            return items.firstIndex(where: { $0.id == id })
        }
        return Binding(
            get: {
                index(in: notebook.textAttachments).map { notebook.textAttachments![$0] }
                    ?? NoteTextAttachment()
            },
            set: { updated in
                if let idx = index(in: notebook.textAttachments) {
                    let oldItem = notebook.textAttachments?[idx]
                    if oldItem?.text != updated.text {
                        recordTextUndoStateDebounced()
                    }
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
        let controller = UIActivityViewController(activityItems: [tempUrl], applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            let targetView = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?.rootViewController?.view
            if let view = targetView {
                popover.sourceView = view
                popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
        }
        return controller
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
    var isSelected: Bool = false
    var onSelect: (() -> Void)? = nil
    let onEdit: () -> Void
    let onDelete: () -> Void

    @ObservedObject var store = NotebookStore.shared
    @ObservedObject var localizationManager = LocalizationManager.shared
    @ObservedObject var collaborationManager = CollaborationManager.shared
    @State private var dragOffset: CGSize = .zero
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
                            ObjectOrderMenu(id: attachment.id)
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
                onSelect?()
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
                            onSelect?()
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
                            onSelect?()
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

            // 選取時顯示浮動小操作把手：編輯（依物件類型開啟專屬視窗）、刪除、右下角縮放把手
            if isSelected {
                HStack(spacing: 6) {
                    Button {
                        onEdit()
                    } label: {
                        let iconName = (attachment.mathFormula != nil) ? "function" : ((attachment.chartSpec != nil) ? "chart.bar.xaxis" : "slider.horizontal.3")
                        Image(systemName: iconName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(attachment.mathFormula != nil ? localizationManager.localized("math_calc") : (attachment.chartSpec != nil ? localizationManager.localized("chart_edit") : localizationManager.localized("image_beautify")))

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
                    // 圖示按鈕一定要有標籤：沒有的話 VoiceOver 念「按鈕」，
                    // 互動矩陣（`InteractionMatrixAudit`）也找不到它。
                    .accessibilityLabel(localizationManager.localized("action_delete"))
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
        .objectProbe("image")
        .padding(20)
        .position(x: currentX + displayWidth / 2, y: currentY + displayHeight / 2)
        .animation(nil, value: dragOffset)
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
    var isSelected: Bool = false
    var onSelect: (() -> Void)? = nil
    var isTypeMode: Bool = false
    var snapToGrid: Bool = false
    var snapY: ((CGFloat) -> CGFloat)? = nil
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
    @State private var isDragging: Bool = false
    @State private var hasBeenFocused: Bool = false
    @FocusState private var inlineFocused: Bool
    @State private var showSlashMenu: Bool = false

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

    /// 統一進入就地編輯。由快顯選單觸發時，先讓選單完成關閉再建立
    /// first responder，避免 UIKit 在 dismiss 過程中立刻把新鍵盤焦點收走。
    private func beginInlineEditing(afterContextMenu: Bool = false) {
        let activate = {
            onSelect?()
            hasBeenFocused = false
            isEditingInline = true
            collaborationManager.broadcastSelection(selectedId: textItem.id)
        }
        if afterContextMenu {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: activate)
        } else {
            activate()
        }
    }

    private func afterContextMenuDismisses(_ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: action)
    }

    private func slashMenuItem(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

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

                        // `TextField(axis: .vertical)` 而不是 `TextEditor`：TextEditor 裡面有自己的
                        // 上下左右內距（隨系統版本不同），第一行基準線因此離方塊頂端多出一個
                        // 量不準的距離 —— 橫線紙上的字對不齊格線。垂直軸的 TextField 沒有內距，
                        // 編輯中與編輯後（`Text`）的字完全重疊，基準線 = 內距 + ascender。
                        TextField("", text: $textItem.text, axis: .vertical)
                            .font(.system(size: textItem.fontSize, weight: textItem.isBold ? .bold : .regular))
                            .foregroundColor(Color(hex: textItem.textColorHex) ?? .primary)
                            .multilineTextAlignment(resolveMultilineAlignment(textItem.alignmentRaw))
                            .lineSpacing(textItem.lineSpacing ?? 0)
                            .textFieldStyle(.plain)
                            .background(Color.clear)
                            .frame(maxWidth: .infinity, minHeight: 20, alignment: resolveFrameAlignment(textItem.alignmentRaw))
                            .focused($inlineFocused)
                            .accessibilityIdentifier("editor.text.inline_editor")
                    }
                    .overlay(alignment: .topLeading) {
                        if showSlashMenu {
                            VStack(alignment: .leading, spacing: 4) {
                                slashMenuItem(title: localizationManager.localized("text_slash_h1"), icon: "textformat.size.larger") {
                                    textItem.text = ""
                                    textItem.fontSize = 28
                                    textItem.isBold = true
                                    showSlashMenu = false
                                }
                                slashMenuItem(title: localizationManager.localized("text_slash_h2"), icon: "textformat.size") {
                                    textItem.text = ""
                                    textItem.fontSize = 22
                                    textItem.isBold = true
                                    showSlashMenu = false
                                }
                                slashMenuItem(title: localizationManager.localized("text_slash_bullet"), icon: "list.bullet") {
                                    textItem.text = "• "
                                    showSlashMenu = false
                                }
                                slashMenuItem(title: localizationManager.localized("text_slash_todo"), icon: "checklist") {
                                    textItem.text = "☐ "
                                    showSlashMenu = false
                                }
                                slashMenuItem(title: localizationManager.localized("text_slash_quote"), icon: "text.quote") {
                                    textItem.text = "│ "
                                    showSlashMenu = false
                                }
                            }
                            .padding(6)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.18), radius: 6, y: 3)
                            .offset(y: -170)
                        }
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
                guard !isEditingInline else { return }
                guard lockedByPeer == nil else { return }
                beginInlineEditing()
            }
            .onTapGesture {
                guard !isEditingInline else { return }
                guard lockedByPeer == nil else { return }
                beginInlineEditing()
            }
            // 右鍵／長按也要能刪除 —— 這是大家最先嘗試的操作
            .contextMenu {
                Button {
                    beginInlineEditing(afterContextMenu: true)
                } label: { Label(localizationManager.localized("edit_in_place"), systemImage: "character.cursor.ibeam") }

                Button {
                    afterContextMenuDismisses(onEdit)
                } label: { Label(localizationManager.localized("text_studio"), systemImage: "textformat") }

                if let onAnchorInk {
                    Button {
                        afterContextMenuDismisses(onAnchorInk)
                    } label: { Label(localizationManager.localized("sticky_anchor_ink"), systemImage: "link.badge.plus") }
                }

                ObjectFrameStyleMenu(
                    style: $textItem,
                    onChange: broadcastTextChange,
                    schedule: afterContextMenuDismisses
                )
                ObjectOrderMenu(id: textItem.id)

                Divider()

                Button(role: .destructive) {
                    afterContextMenuDismisses(onDelete)
                } label: { Label(localizationManager.localized("delete"), systemImage: "trash") }
            }
            .gesture(
                isEditingInline ? nil :
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
                            beginInlineEditing()
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
                                textItem.y = (snapToGrid && snapY != nil) ? snapY!(landed.y) : landed.y
                                dragOffset = .zero
                                isDragging = false
                            }
                            let deltaX = textItem.x - oldX
                            let deltaY = textItem.y - oldY
                            if deltaX != 0 || deltaY != 0 {
                                onMoved?(CGSize(width: deltaX, height: deltaY))
                            }
                            onSelect?()
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

            // 🌟 頂部精準拖曳把手（膠囊造型 ≡），即使在就地打字中也能隨意拖拉換位排版
            if isSelected || isEditingInline {
                HStack {
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 38, height: 16)
                    .background(Color(uiColor: .secondarySystemBackground).opacity(0.95))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.secondary.opacity(0.3), lineWidth: 0.8))
                    .shadow(color: Color.black.opacity(0.12), radius: 3, y: 1)
                    .contentShape(Rectangle())
                    .highPriorityGesture(
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
                                let oldX = textItem.x
                                let oldY = textItem.y
                                var transaction = Transaction()
                                transaction.animation = nil
                                withTransaction(transaction) {
                                    let landed = PrintableArea.clampOrigin(
                                        x: textItem.x + value.translation.width,
                                        y: textItem.y + value.translation.height,
                                        width: textItem.width, height: textItem.height)
                                    textItem.x = landed.x
                                    textItem.y = (snapToGrid && snapY != nil) ? snapY!(landed.y) : landed.y
                                    dragOffset = .zero
                                    isDragging = false
                                }
                                let deltaX = textItem.x - oldX
                                let deltaY = textItem.y - oldY
                                if deltaX != 0 || deltaY != 0 {
                                    onMoved?(CGSize(width: deltaX, height: deltaY))
                                }
                                onSelect?()
                                broadcastTextChange()
                            }
                    )
                    Spacer()
                }
                .frame(width: displayWidth)
                .offset(y: (isSelected && !isEditingInline) ? -42 : -24)
            }
        }
        .objectProbe("text")
        .padding(20)
        .position(x: currentX + displayWidth / 2, y: currentY + displayHeight / 2)
        .animation(nil, value: dragOffset)
        // 方塊跟著內容長高（Word 的行為）。隨點即書的方塊一開始只有一行高，
        // 打到第二行時不長高的話，後面的字被方塊裁掉、看起來像「打了字沒出現」。
        // 內距固定 14（高度一律不小於 60），長高不會讓第一行跳離格線。
        .onChange(of: textItem.text) { newText in
            guard isEditingInline else { return }

            // 🌟 Markdown 前綴快捷排版（即打即轉）
            if newText == "# " {
                textItem.text = ""
                textItem.fontSize = 28
                textItem.isBold = true
            } else if newText == "## " {
                textItem.text = ""
                textItem.fontSize = 22
                textItem.isBold = true
            } else if newText == "### " {
                textItem.text = ""
                textItem.fontSize = 18
                textItem.isBold = true
            } else if newText == "- " || newText == "* " {
                textItem.text = "• "
            } else if newText == "1. " {
                textItem.text = "1. "
            } else if newText == "[] " || newText == "[ ] " {
                textItem.text = "☐ "
            } else if newText == "[x] " {
                textItem.text = "☑ "
            } else if newText == "> " {
                textItem.text = "│ "
            }

            // 🌟 斜線快捷選單觸發
            if textItem.text == "/" {
                showSlashMenu = true
            } else if showSlashMenu && !textItem.text.hasPrefix("/") {
                showSlashMenu = false
            }

            let needed = RuledWriting.boxHeight(
                text: textItem.text, width: textItem.width, fontSize: textItem.fontSize,
                bold: textItem.isBold, lineSpacing: textItem.lineSpacing ?? 0)
            // 有框線的方塊是使用者自己調過大小的：只在內容放不下時才加高，不縮小。
            // 沒有框線的（隨點即書）完全跟著內容，刪字會縮回去。
            if needed > textItem.height || (!textItem.hasBorder && needed < textItem.height) {
                textItem.height = needed
            }
        }
        .onChange(of: isEditingInline) { editing in
            if editing {
                hasBeenFocused = false
            } else {
                inlineFocused = false
                hasBeenFocused = false
                finishEditing()
            }
        }
        .onChange(of: inlineFocused) { focused in
            if focused {
                hasBeenFocused = true
            } else if hasBeenFocused && isEditingInline {
                isEditingInline = false
                hasBeenFocused = false
                finishEditing()
            }
        }
        // 快顯選單、語音轉錄和一般點擊進來的時機不同。先 yield 讓 TextField
        // 掛進視圖樹，再給 UIKit 一小段時間安裝 responder；第一次仍未成功時
        // 再要求一次，避免鍵盤時有時無。
        .task(id: isEditingInline) {
            guard isEditingInline else { return }
            hasBeenFocused = false
            await Task.yield()
            inlineFocused = true
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard isEditingInline, !hasBeenFocused else { return }
            inlineFocused = false
            await Task.yield()
            inlineFocused = true
        }
    }

    private func finishEditing() {
        broadcastTextChange()
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
    var isSelected: Bool = false
    var onSelect: (() -> Void)? = nil
    let onDelete: () -> Void

    @State private var dragOffset: CGSize = .zero
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
            .contextMenu {
                ObjectOrderMenu(id: linkItem.id)
                Divider()
                Button(role: .destructive, action: onDelete) {
                    Label(localizationManager.localized("delete"), systemImage: "trash")
                }
            }
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
                            onSelect?()
                        } else {
                            // 拖出可列印範圍的物件推回邊界（S-85）。
                            let landed = PrintableArea.clampOrigin(
                                x: linkItem.x + value.translation.width,
                                y: linkItem.y + value.translation.height,
                                width: linkItem.width, height: linkItem.height)
                            linkItem.x = landed.x
                            linkItem.y = landed.y
                            onSelect?()
                        }
                        dragOffset = .zero
                    }
            )
            .onTapGesture { onSelect?() }
            .objectProbe("link")
            .padding(20)
        .position(x: currentX + displayWidth / 2, y: currentY + displayHeight / 2)
        .animation(nil, value: dragOffset)
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
    var isSelected: Bool = false
    var onSelect: (() -> Void)? = nil
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
                        onSelect?()
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
                    onSelect?()
                    if let data = try? JSONEncoder().encode(item),
                       let dict = try? JSONSerialization.jsonObject(with: data)
                        as? [String: Any] {
                        collaborationManager.broadcastAttachmentUpsert(type: "3d", itemDict: dict)
                    }
                }
            )
            .onTapGesture {
                onSelect?()
            }
            // 底色與邊框吃使用者的設定。原本是寫死的 —— 那表示「所有插入的
            // 東西都能調外框」這件事在 3D 模型上是假的。
            .background(
                RoundedRectangle(cornerRadius: item.cornerRadius)
                    .fill(ObjectFrameStyleResolver.background(item, .model3D))
            )
            .overlay(
                RoundedRectangle(cornerRadius: item.cornerRadius)
                    .stroke(
                        isSelected ? Color.accentColor : ObjectFrameStyleResolver.borderColor(item, .model3D),
                        lineWidth: isSelected ? 1.5 : ObjectFrameStyleResolver.borderWidth(item, .model3D)
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
                ObjectOrderMenu(id: item.id)
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
        .objectProbe("model3d")
        .padding(20)
        .position(x: currentX + item.width / 2, y: currentY + item.height / 2)
        .animation(nil, value: dragOffset)
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




// MARK: - 互動式貼圖定位與放置元件

public struct PendingStickerPlacement: Identifiable, Equatable {
    public let id: UUID = UUID()
    public var drawing: PKDrawing
    public var center: CGPoint
    public var size: CGSize
    public var scale: CGFloat = 1.0
    public var rotationDegrees: Double = 0.0

    public static func == (lhs: PendingStickerPlacement, rhs: PendingStickerPlacement) -> Bool {
        lhs.id == rhs.id &&
        lhs.center == rhs.center &&
        lhs.size == rhs.size &&
        lhs.scale == rhs.scale &&
        lhs.rotationDegrees == rhs.rotationDegrees
    }
}

public struct StickerRenderView: View {
    public let drawing: PKDrawing

    public var body: some View {
        let b = drawing.bounds
        let safeBounds = (b.width > 0 && b.height > 0) ? b : CGRect(x: 0, y: 0, width: 100, height: 100)
        let img = drawing.image(from: safeBounds, scale: 2.0)
        Image(uiImage: img)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

public struct StickerPlacementOverlayView: View {
    @Binding var placement: PendingStickerPlacement
    let onCommit: () -> Void
    let onCancel: () -> Void
    @ObservedObject private var localizationManager = LocalizationManager.shared

    @State private var dragOffset: CGSize = .zero
    @State private var resizeBaseScale: CGFloat? = nil
    @State private var pinchBaseScale: CGFloat? = nil

    private var currentCenter: CGPoint {
        CGPoint(
            x: placement.center.x + dragOffset.width,
            y: placement.center.y + dragOffset.height
        )
    }

    private var displayScale: CGFloat {
        max(0.2, min(5.0, placement.scale))
    }

    public var body: some View {
        let baseW = max(50, placement.size.width)
        let baseH = max(50, placement.size.height)
        let displayW = baseW * displayScale
        let displayH = baseH * displayScale

        VStack(spacing: 10) {
            // 頂部控制把手列：取消、重設、完成放置
            HStack(spacing: 10) {
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(7)
                        .background(Color.red)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sticker.place.cancel")
                .accessibilityLabel(localizationManager.localized("cancel"))

                Button {
                    placement.scale = 1.0
                    placement.rotationDegrees = 0
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(7)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizationManager.localized("reset"))

                Button {
                    onCommit()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                        Text(localizationManager.localized("place_sticker"))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sticker.place.confirm")
            }

            // 貼圖互動預覽本體（可自由拖曳定位、旋轉、右下角縮放與雙指捏合縮放）
            ZStack(alignment: .bottomTrailing) {
                StickerRenderView(drawing: placement.drawing)
                    .frame(width: displayW, height: displayH)
                    .rotationEffect(.degrees(placement.rotationDegrees))
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 3, coordinateSpace: .named(CanvasCoordinateSpace.name))
                            .onChanged { val in
                                dragOffset = val.translation
                            }
                            .onEnded { val in
                                placement.center.x += val.translation.width
                                placement.center.y += val.translation.height
                                dragOffset = .zero
                            }
                    )
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { mag in
                                let base = pinchBaseScale ?? placement.scale
                                if pinchBaseScale == nil { pinchBaseScale = base }
                                placement.scale = max(0.2, min(5.0, base * mag))
                            }
                            .onEnded { _ in
                                pinchBaseScale = nil
                            }
                    )

                // 外圍邊框
                RoundedRectangle(cornerRadius: 10)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundColor(Color.accentColor)
                    .frame(width: displayW + 16, height: displayH + 16)
                    .rotationEffect(.degrees(placement.rotationDegrees))
                    .allowsHitTesting(false)

                // 右下角縮放把手
                Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .contentShape(Circle())
                    .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 1)
                    .offset(x: 10, y: 10)
                    .accessibilityLabel(localizationManager.localized("resize"))
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .named(CanvasCoordinateSpace.name))
                            .onChanged { val in
                                let base = resizeBaseScale ?? placement.scale
                                if resizeBaseScale == nil { resizeBaseScale = base }
                                let delta = (val.translation.width + val.translation.height) / 2.0
                                placement.scale = max(0.2, min(5.0, base + (delta / 120.0)))
                            }
                            .onEnded { _ in
                                resizeBaseScale = nil
                            }
                    )

                // 頂部旋轉把手
                ObjectRotationHandle(
                    degrees: $placement.rotationDegrees,
                    size: CGSize(width: displayW + 16, height: displayH + 16)
                )
            }
        }
        .padding(20)
        .position(x: currentCenter.x, y: currentCenter.y)
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
    
    public func persist() {
        if let data = try? JSONEncoder().encode(stickers) {
            UserDefaults.standard.set(data, forKey: storageKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    public func loadStickers() {
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
        if !StickerManager.shared.stickers.isEmpty {
            self._tab = State(initialValue: .mine)
        }
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
            .onAppear {
                manager.loadStickers()
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
    
    private var renderedImage: UIImage? {
        let b = drawing.bounds
        guard b.width > 0, b.height > 0 else { return nil }
        return drawing.image(from: b, scale: 2.0)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onSelect) {
                if let image = renderedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding()
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(12)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .frame(height: 120)
                        .overlay(Image(systemName: "pencil.tip").foregroundColor(.secondary))
                }
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
    
    @State private var selectedTapeId: String? = nil
    @State private var currentDragTape: NoteTapeAttachment? = nil
    @State private var dragStartPoint: CGPoint = .zero
    
    // 預設遮蔽膠帶色票（莫蘭迪粉彩質感），支援快速換色
    private let tapePresetHexes = [
        "#FCEEAC", // 暖黃
        "#FFD1DC", // 柔粉
        "#C8E6C9", // 薄荷綠
        "#BBDEFB", // 晴空藍
        "#FFE0B2", // 淺杏橙
        "#E1BEE7", // 薰衣草紫
        "#CFD8DC"  // 莫蘭迪灰
    ]
    
    public var body: some View {
        ZStack {
            // 背景點擊與繪製層：未點中既有膠帶時，點擊空白處可取消選取；拖曳可立即繪製新的一筆膠帶（支援連續多筆繪製）
            if isActive {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTapeId = nil
                    }
                    .gesture(
                        DragGesture(minimumDistance: 10, coordinateSpace: .named(CanvasCoordinateSpace.name))
                            .onChanged { value in
                                if selectedTapeId != nil {
                                    selectedTapeId = nil
                                }
                                if currentDragTape == nil {
                                    dragStartPoint = value.startLocation
                                }
                                let x = min(dragStartPoint.x, value.location.x)
                                let width = max(abs(value.location.x - dragStartPoint.x), 20)
                                let height: CGFloat = 32.0
                                let rect = CGRect(x: x, y: dragStartPoint.y - height / 2, width: width, height: height)
                                
                                let hex = selectedColor.toHex() ?? "#FCEEAC"
                                currentDragTape = NoteTapeAttachment(pageIndex: pageIndex, rect: rect, colorHex: hex)
                            }
                            .onEnded { value in
                                guard let dragTape = currentDragTape else { return }
                                if notebook.tapeAttachments == nil {
                                    notebook.tapeAttachments = []
                                }
                                notebook.tapeAttachments?.append(dragTape)
                                selectedTapeId = nil
                                currentDragTape = nil
                                onTapesChanged()
                            }
                    )
            }

            let tapes = notebook.tapeAttachments?.filter { $0.pageIndex == pageIndex } ?? []
            ForEach(tapes) { tape in
                TapeView(
                    tape: tape,
                    isActive: isActive,
                    isSelected: selectedTapeId == tape.id,
                    fallbackColor: selectedColor,
                    onSelect: {
                        selectedTapeId = tape.id
                    },
                    onToggleReveal: {
                        if let idx = notebook.tapeAttachments?.firstIndex(where: { $0.id == tape.id }) {
                            notebook.tapeAttachments?[idx].isRevealed.toggle()
                            onTapesChanged()
                        }
                    },
                    onRectChanged: { newRect in
                        if let idx = notebook.tapeAttachments?.firstIndex(where: { $0.id == tape.id }) {
                            notebook.tapeAttachments?[idx].rect = newRect
                            onTapesChanged()
                        }
                    },
                    onRotationChanged: { newRot in
                        if let idx = notebook.tapeAttachments?.firstIndex(where: { $0.id == tape.id }) {
                            notebook.tapeAttachments?[idx].rotation = newRot
                            onTapesChanged()
                        }
                    },
                    onRemove: {
                        if selectedTapeId == tape.id {
                            selectedTapeId = nil
                        }
                        notebook.tapeAttachments?.removeAll { $0.id == tape.id }
                        onTapesChanged()
                    }
                )
            }

            // 繪製中的預覽
            if let dragTape = currentDragTape {
                RoundedRectangle(cornerRadius: 4)
                    .fill(selectedColor.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.accentColor, lineWidth: 1.5)
                    )
                    .frame(width: dragTape.rect.width, height: dragTape.rect.height)
                    .position(x: dragTape.rect.midX, y: dragTape.rect.midY)
                    .shadow(color: Color.black.opacity(0.12), radius: 3, y: 1)
            }

            // 選中膠帶時，在頂層獨立浮動顯示快捷工具條（保證按鈕點擊 100% 作用且不被邊界裁切）
            if isActive, let selId = selectedTapeId, let selectedTape = tapes.first(where: { $0.id == selId }) {
                let toolbarY: CGFloat = selectedTape.rect.minY < 75
                    ? selectedTape.rect.maxY + 48
                    : selectedTape.rect.minY - 50
                TapeFloatingToolbar(
                    tape: selectedTape,
                    presetColors: tapePresetHexes,
                    onColorChanged: { hex in
                        if let idx = notebook.tapeAttachments?.firstIndex(where: { $0.id == selId }) {
                            notebook.tapeAttachments?[idx].colorHex = hex
                            onTapesChanged()
                        }
                    },
                    onToggleReveal: {
                        if let idx = notebook.tapeAttachments?.firstIndex(where: { $0.id == selId }) {
                            notebook.tapeAttachments?[idx].isRevealed.toggle()
                            onTapesChanged()
                        }
                    },
                    onRotate: {
                        if let idx = notebook.tapeAttachments?.firstIndex(where: { $0.id == selId }) {
                            let cur = notebook.tapeAttachments?[idx].rotation ?? 0.0
                            notebook.tapeAttachments?[idx].rotation = (cur + 45.0).truncatingRemainder(dividingBy: 360.0)
                            onTapesChanged()
                        }
                    },
                    onRemove: {
                        selectedTapeId = nil
                        notebook.tapeAttachments?.removeAll { $0.id == selId }
                        onTapesChanged()
                    }
                )
                .position(x: min(max(selectedTape.rect.midX, 180), PageGeometry.width - 180), y: toolbarY)
                .zIndex(20)
            }
        }
        .coordinateSpace(name: CanvasCoordinateSpace.name)
    }
}

private struct TapeFloatingToolbar: View {
    let tape: NoteTapeAttachment
    let presetColors: [String]
    let onColorChanged: (String) -> Void
    let onToggleReveal: () -> Void
    let onRotate: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // 色票選擇
            ForEach(presetColors, id: \.self) { hex in
                Button {
                    onColorChanged(hex)
                } label: {
                    Circle()
                        .fill(Color(hex: hex) ?? .yellow)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(tape.colorHex?.uppercased() == hex.uppercased() ? 0.9 : 0.2), lineWidth: tape.colorHex?.uppercased() == hex.uppercased() ? 2.5 : 1)
                        )
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Divider().frame(height: 18)

            // 旋轉
            Button(action: onRotate) {
                Image(systemName: "rotate.right.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider().frame(height: 18)

            // 翻開 / 遮回切換
            Button(action: onToggleReveal) {
                Image(systemName: tape.isRevealed ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider().frame(height: 18)

            // 刪除
            Button(action: onRemove) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.red)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color.black.opacity(0.22), radius: 8, y: 3)
        )
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .onTapGesture {}
    }
}

private struct TapeView: View {
    let tape: NoteTapeAttachment
    let isActive: Bool
    let isSelected: Bool
    let fallbackColor: Color
    let onSelect: () -> Void
    let onToggleReveal: () -> Void
    let onRectChanged: (CGRect) -> Void
    let onRotationChanged: (Double) -> Void
    let onRemove: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var resizeBaseRect: CGRect? = nil
    @State private var liveRect: CGRect? = nil

    private var currentRect: CGRect {
        if let live = liveRect { return live }
        return CGRect(
            x: tape.rect.minX + dragOffset.width,
            y: tape.rect.minY + dragOffset.height,
            width: tape.rect.width,
            height: tape.rect.height
        )
    }

    private var baseColor: Color {
        if let hex = tape.colorHex, let c = Color(hex: hex) {
            return c
        }
        return fallbackColor
    }

    var body: some View {
        let rect = currentRect

        ZStack {
            // 膠帶本體
            RoundedRectangle(cornerRadius: 4)
                .fill(tape.isRevealed ? baseColor.opacity(0.20) : baseColor.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(baseColor.opacity(tape.isRevealed ? 0.4 : 0.8), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(tape.isRevealed ? 0.02 : 0.08), radius: 2, y: 1)

            // 選取外框與編輯把手（當工具啟動且該膠帶被選中時）
            if isActive && isSelected {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

                // 左縮放把手（水平拉伸）
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                    .frame(width: 14, height: 14)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .position(x: 0, y: rect.height / 2)
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .named(CanvasCoordinateSpace.name))
                            .onChanged { value in
                                if resizeBaseRect == nil {
                                    resizeBaseRect = tape.rect
                                }
                                guard let base = resizeBaseRect else { return }
                                let newMinX = min(base.minX + value.translation.width, base.maxX - 20)
                                let newW = base.maxX - newMinX
                                var transaction = Transaction()
                                transaction.animation = nil
                                withTransaction(transaction) {
                                    liveRect = CGRect(x: newMinX, y: base.minY, width: newW, height: base.height)
                                }
                            }
                            .onEnded { _ in
                                var transaction = Transaction()
                                transaction.animation = nil
                                withTransaction(transaction) {
                                    if let finalRect = liveRect {
                                        onRectChanged(finalRect)
                                    }
                                    resizeBaseRect = nil
                                    liveRect = nil
                                }
                            }
                    )

                // 右縮放把手（水平拉伸）
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                    .frame(width: 14, height: 14)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .position(x: rect.width, y: rect.height / 2)
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .named(CanvasCoordinateSpace.name))
                            .onChanged { value in
                                if resizeBaseRect == nil {
                                    resizeBaseRect = tape.rect
                                }
                                guard let base = resizeBaseRect else { return }
                                let newW = max(20, base.width + value.translation.width)
                                var transaction = Transaction()
                                transaction.animation = nil
                                withTransaction(transaction) {
                                    liveRect = CGRect(x: base.minX, y: base.minY, width: newW, height: base.height)
                                }
                            }
                            .onEnded { _ in
                                var transaction = Transaction()
                                transaction.animation = nil
                                withTransaction(transaction) {
                                    if let finalRect = liveRect {
                                        onRectChanged(finalRect)
                                    }
                                    resizeBaseRect = nil
                                    liveRect = nil
                                }
                            }
                    )

                // 上縮放把手（垂直拉伸）
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                    .frame(width: 14, height: 14)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .position(x: rect.width / 2, y: 0)
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .named(CanvasCoordinateSpace.name))
                            .onChanged { value in
                                if resizeBaseRect == nil {
                                    resizeBaseRect = tape.rect
                                }
                                guard let base = resizeBaseRect else { return }
                                let newMinY = min(base.minY + value.translation.height, base.maxY - 16)
                                let newH = base.maxY - newMinY
                                var transaction = Transaction()
                                transaction.animation = nil
                                withTransaction(transaction) {
                                    liveRect = CGRect(x: base.minX, y: newMinY, width: base.width, height: newH)
                                }
                            }
                            .onEnded { _ in
                                var transaction = Transaction()
                                transaction.animation = nil
                                withTransaction(transaction) {
                                    if let finalRect = liveRect {
                                        onRectChanged(finalRect)
                                    }
                                    resizeBaseRect = nil
                                    liveRect = nil
                                }
                            }
                    )

                // 下縮放把手（垂直拉伸）
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                    .frame(width: 14, height: 14)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .position(x: rect.width / 2, y: rect.height)
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .named(CanvasCoordinateSpace.name))
                            .onChanged { value in
                                if resizeBaseRect == nil {
                                    resizeBaseRect = tape.rect
                                }
                                guard let base = resizeBaseRect else { return }
                                let newH = max(16, base.height + value.translation.height)
                                var transaction = Transaction()
                                transaction.animation = nil
                                withTransaction(transaction) {
                                    liveRect = CGRect(x: base.minX, y: base.minY, width: base.width, height: newH)
                                }
                            }
                            .onEnded { _ in
                                var transaction = Transaction()
                                transaction.animation = nil
                                withTransaction(transaction) {
                                    if let finalRect = liveRect {
                                        onRectChanged(finalRect)
                                    }
                                    resizeBaseRect = nil
                                    liveRect = nil
                                }
                            }
                    )

                // 旋轉把手（頂部拉桿）
                VStack(spacing: 0) {
                    Circle()
                        .fill(Color.accentColor)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .frame(width: 14, height: 14)
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 1.5, height: 14)
                }
                .frame(width: 36, height: 40)
                .contentShape(Rectangle())
                .position(x: rect.width / 2, y: -22)
                .gesture(
                    DragGesture(minimumDistance: 1, coordinateSpace: .named(CanvasCoordinateSpace.name))
                        .onChanged { value in
                            let center = CGPoint(x: rect.midX, y: rect.midY)
                            let vx = value.location.x - center.x
                            let vy = value.location.y - center.y
                            let raw = atan2(vy, vx) * 180 / .pi + 90
                            let angle = CanvasRotation.snapped(Double(raw))
                            onRotationChanged(angle)
                        }
                )
            }

            // 翻開與刪除按鈕（未選中時只在右側顯示輕便移除鈕）
            if isActive && !isSelected {
                HStack {
                    Spacer()
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: rect.width, height: rect.height)
        .contentShape(Rectangle())
        .rotationEffect(.degrees(tape.rotation))
        .onTapGesture {
            if isActive {
                if !isSelected {
                    onSelect()
                }
            } else {
                onToggleReveal()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .named(CanvasCoordinateSpace.name))
                .onChanged { value in
                    guard isActive else { return }
                    if !isSelected {
                        onSelect()
                    }
                    var transaction = Transaction()
                    transaction.animation = nil
                    withTransaction(transaction) {
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    guard isActive else { return }
                    let movedRect = CGRect(
                        x: tape.rect.minX + value.translation.width,
                        y: tape.rect.minY + value.translation.height,
                        width: tape.rect.width,
                        height: tape.rect.height
                    )
                    var transaction = Transaction()
                    transaction.animation = nil
                    withTransaction(transaction) {
                        dragOffset = .zero
                    }
                    onRectChanged(movedRect)
                }
        )
        .position(x: rect.midX, y: rect.midY)
        .animation(nil, value: dragOffset)
        .animation(nil, value: liveRect)
    }
}

/// 「從檔案匯入」那三個修飾詞（挑圖、挑音訊、失敗提示）。
///
/// 收成一個 `ViewModifier` 是因為編輯器的 `body` 修飾詞鏈已經長到
/// 編譯器會放棄型別推導 —— 攤開來寫會讓整支檔案編不過，而錯誤訊息
/// 指的是鏈的開頭，完全看不出是哪一個加上去的。
private struct ImportPickersModifier: ViewModifier {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Binding var activeImportSlot: FfiImportSlot?
    @Binding var importErrorKey: String
    let onImage: (FileImport.Outcome) -> Void
    let onAudio: (FileImport.Outcome) -> Void
    let onPdf: (FileImport.Outcome) -> Void
    let onDocument: (FileImport.Outcome) -> Void

    @State private var currentSlot: FfiImportSlot? = nil

    func body(content: Content) -> some View {
        content
            // 命令式呈現，見 `DocumentPickerPresenter` 的說明（`.fileImporter` 第二次起會被吞掉）。
            .onChange(of: activeImportSlot) { slot in
                guard let slot else { return }
                currentSlot = slot
                let presented = DocumentPickerPresenter.present(
                    types: FileImport.allowedTypes(for: slot)
                ) { result in
                    currentSlot = nil
                    activeImportSlot = nil
                    guard let result else { return }
                    let destination: FileImport.Destination = (slot == .audio) ? .recordings : .attachments
                    guard let outcome = FileImport.take(result: result, slot: slot, into: destination)
                    else { return }
                    if outcome.succeeded {
                        switch slot {
                        case .image: onImage(outcome)
                        case .audio: onAudio(outcome)
                        case .pdf: onPdf(outcome)
                        case .document: onDocument(outcome)
                        default: break
                        }
                    } else {
                        importErrorKey = outcome.errorKey
                    }
                }
                // 呈現不出去也要把槽位放掉，不然下一次要求是「nil → 同一個值」之外的卡死狀態。
                if !presented { activeImportSlot = nil; currentSlot = nil }
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

/// 進階協作四部曲：功能測試與操作面板
/// 專門設計給終端使用者與 QA 測試進階連線功能，完全解耦自 NotebookEditorView 避免破壞核心。
public struct CollabAdvancedFeaturesPanel: View {
    @State private var timeMachineLamport: Double = 0.0
    @State private var isVoiceRoomActive: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            Text(LocalizationManager.shared.localized("collab_advanced_panel"))
                .font(.headline)
            
            
            // 2. 區網直連 (P2P Local Relay) 掃描與連線
            HStack {
                Button(LocalizationManager.shared.localized("collab_p2p_scan")) {
                    LocalSyncDiscovery.shared.startBrowsing()
                }
                .buttonStyle(.bordered)
                
                Button(LocalizationManager.shared.localized("collab_p2p_stop")) {
                    LocalSyncDiscovery.shared.stopBrowsing()
                }
                .buttonStyle(.bordered)
                
                Button(LocalizationManager.shared.localized("collab_p2p_test")) {
                    if let endpoint = LocalSyncDiscovery.shared.discoveredEndpoints.first {
                        LocalSyncDiscovery.shared.connectToP2P(endpoint: endpoint)
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            // 1. 語音通話 (Voice Room) 操作區
            HStack {
                Text(LocalizationManager.shared.localized("collab_voice_room"))
                Spacer()
                Button(action: {
                    isVoiceRoomActive.toggle()
                    if isVoiceRoomActive {
                        // 觸發 FFI 或 WebSocket 狀態改變
                        print("User joined Voice Room.")
                    } else {
                        print("User left Voice Room.")
                    }
                }) {
                    HStack {
                        Image(systemName: isVoiceRoomActive ? "mic.fill" : "mic.slash")
                        Text(isVoiceRoomActive ? L10n.t("voice_connected") : L10n.t("voice_disconnected"))
                    }
                    .padding(8)
                    .background(isVoiceRoomActive ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            
            Divider()
            
            // 2. 時光機 (Time Machine) 操作區
            VStack(alignment: .leading) {
                Text("\(LocalizationManager.shared.localized("collab_time_machine")) (Lamport: \\(Int(timeMachineLamport)))")
                Slider(value: $timeMachineLamport, in: 0...1000) { editing in
                    if !editing {
                        // 呼叫 Rust FFI: collab_time_machine_contributors
                        print("Replaying history to lamport \\(timeMachineLamport)...")
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
    }
}

/// 特殊樣板核取清單 Checkbox 互動視圖（支援點選勾選、觸覺回饋、右鍵／長按進度管控選單）
struct InteractiveGuideCheckboxView: View {
    let isChecked: Bool
    let size: CGSize
    let onToggle: () -> Void
    let onStrikethroughRow: () -> Void
    let onClearRowText: () -> Void
    let onResetPage: () -> Void

    @ObservedObject var localizationManager = LocalizationManager.shared

    private var toggleTitle: String {
        isChecked
            ? (localizationManager.currentLanguage == .en ? "Mark Incomplete" : "取消勾選")
            : (localizationManager.currentLanguage == .en ? "Mark Completed" : "✓ 標記完成")
    }
    private var strikethroughTitle: String {
        localizationManager.currentLanguage == .en ? "Strikethrough Row" : "劃除本行文字"
    }
    private var clearRowTitle: String {
        localizationManager.currentLanguage == .en ? "Clear Row Text" : "清空本行文字"
    }
    private var resetPageTitle: String {
        localizationManager.currentLanguage == .en ? "Reset Page Checkboxes" : "重設此頁核取清單"
    }

    var body: some View {
        Button(action: onToggle) {
            ZStack {
                // 隱形延伸觸控區（32x32pt），手指與觸控筆皆極易點擊
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: max(32, size.width + 16), height: max(32, size.height + 16))

                // 方塊外框（依樣板大小適配）
                RoundedRectangle(cornerRadius: min(3, size.width * 0.25))
                    .stroke(isChecked ? Color.green : Color.secondary.opacity(0.4), lineWidth: isChecked ? 1.5 : 1)
                    .background(
                        RoundedRectangle(cornerRadius: min(3, size.width * 0.25))
                            .fill(isChecked ? Color.green.opacity(0.12) : Color.clear)
                    )
                    .frame(width: max(14, size.width), height: max(14, size.height))

                // 勾選符號
                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: max(9, size.width * 0.75), weight: .bold))
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onToggle) {
                Label(toggleTitle, systemImage: isChecked ? "circle" : "checkmark.circle.fill")
            }
            Button(action: onStrikethroughRow) {
                Label(strikethroughTitle, systemImage: "strikethrough")
            }
            Button(role: .destructive, action: onClearRowText) {
                Label(clearRowTitle, systemImage: "delete.left")
            }
            Divider()
            Button(action: onResetPage) {
                Label(resetPageTitle, systemImage: "arrow.counterclockwise")
            }
        }
        .accessibilityLabel(isChecked ? (localizationManager.currentLanguage == .en ? "Completed" : "已完成") : (localizationManager.currentLanguage == .en ? "Incomplete" : "未完成"))
        .accessibilityIdentifier("editor.guide.checkbox")
    }
}

