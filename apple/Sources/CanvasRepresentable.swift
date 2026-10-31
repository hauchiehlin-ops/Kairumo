//
//  CanvasRepresentable.swift
//  Kairumo
//
//  自適應畫布與 PencilKit / 向量背景協調器（架構模組化 P2）。
//

import SwiftUI
import PencilKit
import UIKit

#if canImport(PadnoteCore)
import PadnoteCore
#endif

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
        if other is PencilIntentObserver || other.name == CanvasRepresentable.Coordinator.directTapName {
            return true
        }
        // 橡皮擦：PencilKit 與我們同時收。畫筆：PencilKit 的落筆手勢已經關掉，沒有要並存的。
        return pro.mode == .erase
    }
}

/// 橡皮擦專用觸控追蹤器：專門在選用橡皮擦時，跟隨 Apple Pencil 或手指在螢幕上即時繪製 1:1 擦除範圍指示圓圈。
///
/// 特色：
/// 1. 永遠不攔截、不取消任何其他手勢（cancelsTouchesInView = false），完全不干擾 PencilKit 與專業筆畫的擦除運作。
/// 2. `canBePrevented(by:)` 回傳 false：不論 PencilKit 內部 drawingGestureRecognizer 如何判定，都不會被取消。
/// 3. `canPrevent(_:)` 回傳 false：不阻擋任何手勢。
/// 4. `shouldRecognizeSimultaneouslyWith` 回傳 true：與一切手勢（含 PencilKit）完全並存。
final class EraserTrackingGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    var onTrack: ((CGPoint?) -> Void)?
    var allowsFinger: () -> Bool = { true }

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first(where: { $0.type == .pencil || allowsFinger() }) else {
            state = .failed
            return
        }
        state = .began
        onTrack?(touch.location(in: view))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first(where: { $0.type == .pencil || allowsFinger() }) else { return }
        state = .changed
        onTrack?(touch.location(in: view))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        onTrack?(nil)
        state = .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        onTrack?(nil)
        state = .cancelled
    }

    override func reset() {
        super.reset()
        onTrack?(nil)
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf other: UIGestureRecognizer
    ) -> Bool {
        false
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy other: UIGestureRecognizer
    ) -> Bool {
        false
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

    override init(frame: CGRect) {
        super.init(frame: frame)
        // 畫布自身為 UIScrollView，設為 false 可消除起筆 150ms 判定等待，實現即書即顯
        delaysContentTouches = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        delaysContentTouches = false
    }

    private let internalUndoManager = UndoManager()
    override var undoManager: UndoManager? {
        super.undoManager ?? internalUndoManager
    }
    override var canBecomeFirstResponder: Bool { true }
    var initialLoadedStrokeCount: Int = 0
    weak var directSingleTap: UITapGestureRecognizer?
    weak var directDoubleTap: UITapGestureRecognizer?

    // MARK: - Hold-to-Snap 筆尖停留成形監測（第二階段：幾何停頓轉正）
    private var pencilDwellWorkItem: DispatchWorkItem?
    private var lastPencilLocation: CGPoint = .zero
    private var lastPencilMoveUptime: TimeInterval = 0
    var lastStrokeHadHoldDwell: Bool = false
    var onHoldDwellTriggered: (() -> Void)?
    private(set) var activePencilIsDown: Bool = false

    private func schedulePencilDwellTimer(after delay: TimeInterval = EditorCanvasInputPolicy.holdToSnapMinDuration) {
        pencilDwellWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pencilDwellWorkItem = nil
            // 若在計時期間筆尖仍有移動，僅依剩餘時間補排一次，避免在 240Hz touchesMoved 中每幀取消並重建 DispatchWorkItem。
            let elapsed = ProcessInfo.processInfo.systemUptime - self.lastPencilMoveUptime
            let remaining = EditorCanvasInputPolicy.holdToSnapMinDuration - elapsed
            if remaining > 0.02 {
                self.schedulePencilDwellTimer(after: remaining)
                return
            }
            // 落筆後還沒畫就停住 —— 那是「長按叫飛梭工具盤」，不是畫完停住要轉正。
            guard self.pencilMovedSinceDown else { return }
            self.lastStrokeHadHoldDwell = true
            self.onHoldDwellTriggered?()
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
        }
        pencilDwellWorkItem = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + delay,
            execute: work
        )
    }

    // MARK: - 長按叫出飛梭工具盤
    //
    // 筆尖或單指落在畫布上、**還沒移動**就停住 `pressHoldDuration` 秒，於落點彈出飛梭工具盤。
    // 與 Hold-to-Snap 不衝突：那個是「畫了一段之後停住」，這個是「落下就停住」，
    // 以「落下後有沒有移動過」區分；時間也刻意比 Hold-to-Snap 長，避免誤觸。
    //
    // 用手勢辨識器、不用 touchesBegan 計時：PencilKit 的繪圖手勢一辨識，畫布本身就會收到
    // touchesCancelled，計時跟著作廢 —— 實測長按只留下一個點，工具盤從來沒出現過。
    // 辨識器設成與繪圖手勢同時辨識，兩邊都拿得到這一下觸控。

    /// 回傳 true 表示呼叫端已打開工具盤（座標是 window 座標）。
    var onPressAndHold: ((CGPoint) -> Bool)? {
        didSet {
            if onPressAndHold != nil, pressHoldRecognizer.view == nil {
                addGestureRecognizer(pressHoldRecognizer)
            }
            pressHoldRecognizer.isEnabled = onPressAndHold != nil
        }
    }
    static let pressHoldDuration: TimeInterval = 0.55
    private static let pressHoldMaxJitter: CGFloat = 8
    /// 筆尖落下後動過沒有（Hold-to-Snap 只在畫過一段之後才算）。
    private var pencilMovedSinceDown = false

    private final class PressHoldDelegate: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }
    }
    private let pressHoldDelegate = PressHoldDelegate()

    private lazy var pressHoldRecognizer: UILongPressGestureRecognizer = {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handlePressHold(_:)))
        gesture.minimumPressDuration = Self.pressHoldDuration
        gesture.allowableMovement = Self.pressHoldMaxJitter
        gesture.numberOfTouchesRequired = 1
        gesture.cancelsTouchesInView = false
        gesture.delaysTouchesBegan = false
        gesture.delaysTouchesEnded = false
        gesture.delegate = pressHoldDelegate
        return gesture
    }()

    @objc private func handlePressHold(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let handler = onPressAndHold else { return }
        guard handler(gesture.location(in: nil)) else { return }
        cancelInFlightStrokesForNavigation()
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    /// 兩指捲動或長按選單啟動時，立即取消進行中的單指落筆、套索追蹤與停頓計時，
    /// 避免捲動頁面時手勢互鎖或殘留墨點。
    func cancelInFlightStrokesForNavigation() {
        pencilDwellWorkItem?.cancel()
        lastStrokeHadHoldDwell = false
        cancelLassoTracking()
        if drawingGestureRecognizer.isEnabled {
            drawingGestureRecognizer.isEnabled = false
            drawingGestureRecognizer.isEnabled = true
        }
        if let pro = proGesture, pro.isEnabled {
            pro.isEnabled = false
            pro.isEnabled = true
        }
    }

    /// 這一頁的高度（由 SwiftUI 端更新）
    /// 判定觸控點是否應穿透畫布至底層（筆跡下方物件層，使已選取或文字模式下的下層物件能順暢接收手勢）
    var hitPassThroughCheck: ((CGPoint, UIEvent?) -> Bool)? = nil

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

    private var lastPointerTool: EditorToolType?
    private var lastPointerStrokeWidth: CGFloat?

    func refreshPointer(for tool: EditorToolType, strokeWidth: CGFloat) {
        guard tool != lastPointerTool || abs((lastPointerStrokeWidth ?? 0) - strokeWidth) > 0.05 else { return }
        lastPointerTool = tool
        lastPointerStrokeWidth = strokeWidth
        brushPointerPath = BrushCursor.path(for: tool, strokeWidth: strokeWidth)
        pointerInteractions.forEach { $0.invalidate() }
    }

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
    private var eraserTracker: EraserTrackingGestureRecognizer?

    /// 橡皮擦寬度（頁面座標，與 PencilKit 橡皮擦、專業筆畫擦除半徑同一個值）。
    var eraserWidth: CGFloat = 20
    /// 螢幕上的橡皮擦直徑：頁面寬度 × 縮放倍率。畫布放大時擦掉的頁面範圍不變，螢幕上的圓要跟著變大。
    var eraserScreenDiameter: CGFloat { eraserWidth * max(zoomScale, 0.01) }
    /// 正在用橡皮擦擦（手指或筆尖貼在螢幕上）。
    private var isEraserTracking = false

    /// 擦除中把範圍圓圈畫在觸控點底下；`nil` 收起。
    func trackEraser(_ point: CGPoint?) {
        guard let preview = hoverPreview else { return }
        if let point {
            isEraserTracking = true
            let previewPoint = convert(point, to: preview)
            preview.showEraser(at: previewPoint, diameter: eraserScreenDiameter)
        } else {
            isEraserTracking = false
            preview.hideEraser()
        }
    }

    func installHoverPreviewIfNeeded(coordinator: PenHoverCoordinator) {
        guard hoverPreview == nil else { return }
        let preview = PenHoverPreviewView(frame: bounds)
        preview.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // 加在畫布的**最上層**：筆頭預覽被墨跡蓋住就失去意義了。
        // 它 `isUserInteractionEnabled = false`，不會擋到書寫。
        addSubview(preview)
        hoverPreview = preview
        coordinator.attach(to: self, preview: preview)

        let tracker = EraserTrackingGestureRecognizer()
        tracker.onTrack = { [weak self] point in self?.trackEraser(point) }
        tracker.allowsFinger = { [weak self] in self?.proAllowsFinger() ?? true }
        tracker.isEnabled = false
        addGestureRecognizer(tracker)
        eraserTracker = tracker
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
        mode: ProMode, directory: URL?, notebookId: String, pageIndex: Int,
        pencilOnly: Bool = false, allowsPencilKitDrawing: Bool = true, claimsSingleTouch: Bool = false
    ) {
        let layer = installProLayerIfNeeded()
        if let directory {
            layer.load(directory: directory, notebookId: notebookId, pageIndex: pageIndex)
        }
        guard let gesture = proGesture else { return }
        switch mode {
        case .off:
            eraserTracker?.isEnabled = false
            gesture.isEnabled = false
            gesture.deferUntilMoved = false
            drawingGestureRecognizer.isEnabled = allowsPencilKitDrawing
            if claimsSingleTouch { overridePan() } else { restorePan() }
        case .draw:
            eraserTracker?.isEnabled = false
            gesture.mode = .draw
            gesture.cancelsTouchesInView = true
            // 打字模式：只收 Pencil，而且要真的動了才落墨 —— 輕點是「放游標」，不該留墨點。
            gesture.deferUntilMoved = pencilOnly
            gesture.isEnabled = true
            drawingGestureRecognizer.isEnabled = false
            // 打字模式下單指要能捲動，不能把捲動改成兩指。
            if pencilOnly { restorePan() } else { overridePan() }
        case .erase:
            eraserTracker?.isEnabled = true
            gesture.mode = .erase
            gesture.cancelsTouchesInView = false
            gesture.deferUntilMoved = false
            gesture.isEnabled = true
            drawingGestureRecognizer.isEnabled = allowsPencilKitDrawing
            if claimsSingleTouch { overridePan() } else { restorePan() }
        case .reassign, .marker, .tool:
            eraserTracker?.isEnabled = false
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

    func enclosingScrollView() -> UIScrollView? {
        var view = self.superview
        while let v = view {
            if let sv = v as? UIScrollView, !(sv is PKCanvasView) { return sv }
            view = v.superview
        }
        return nil
    }

    /// 套索模式下，一根手指要拿來圈選，捲動改成兩指。
    ///
    /// 畫布本身是 UIScrollView，單頁模式下它的捲動手勢（單指）與套索的拖曳手勢互搶；
    /// 連續模式下外層的 ScrollView 也由單指驅動，若不限制外層捲動為雙指，
    /// 單指／Apple Pencil 畫圈拖曳時外層 ScrollView 會立即搶先開始捲動並送出 touchesCancelled 取消套索。
    private var savedPanTouchesForLasso: Int?
    private weak var savedEnclosingScrollViewForLasso: UIScrollView?
    private var savedEnclosingPanTouchesForLasso: Int?

    func setLassoClaimsSingleTouch(_ on: Bool) {
        if on {
            if savedPanTouchesForLasso == nil {
                savedPanTouchesForLasso = panGestureRecognizer.minimumNumberOfTouches
            }
            panGestureRecognizer.minimumNumberOfTouches = 2
            if let sv = enclosingScrollView() {
                if savedEnclosingPanTouchesForLasso == nil {
                    savedEnclosingPanTouchesForLasso = sv.panGestureRecognizer.minimumNumberOfTouches
                    savedEnclosingScrollViewForLasso = sv
                }
                sv.panGestureRecognizer.minimumNumberOfTouches = 2
            }
        } else {
            if let saved = savedPanTouchesForLasso {
                panGestureRecognizer.minimumNumberOfTouches = saved
                savedPanTouchesForLasso = nil
            }
            if let sv = savedEnclosingScrollViewForLasso ?? enclosingScrollView(),
               let saved = savedEnclosingPanTouchesForLasso {
                sv.panGestureRecognizer.minimumNumberOfTouches = saved
                savedEnclosingScrollViewForLasso = nil
                savedEnclosingPanTouchesForLasso = nil
            }
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
        gesture.delaysTouchesBegan = false
        gesture.delaysTouchesEnded = false
        gesture.layerView = layer
        gesture.tool = { [weak self] in self?.proTool }
        gesture.color = { [weak self] in self?.proColor ?? [0, 0, 0, 255] }
        gesture.width = { [weak self] in self?.proWidth ?? 4 }
        gesture.eraserRadius = { [weak self] in self?.proEraserRadius ?? 10 }
        gesture.onEraserTrack = { [weak self] point in self?.trackEraser(point) }
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

    // MARK: 落筆中不換筆跡

    /// PencilKit 正在收一筆（落筆到抬筆），由 delegate 的 `canvasViewDidBegin/EndUsingTool` 維護。
    ///
    /// 這段期間任何程式指派 `drawing` 都會把**正在寫的那一筆**取消掉 —— 使用者看到的是
    /// 「筆尖碰到紙、畫出來的線不見了」或「整頁空白一下」。同步重讀、換頁讀檔、補畫……
    /// 這些都得等這一筆抬起來再做（見 `whenInkIdle`）。
    ///
    /// 不能用 `activeTouchesCount` 判斷：繪圖手勢一辨識就把觸控從這個 view 取消
    /// （`touchesCancelled`），計數歸零的時候筆其實還在紙上。
    private var isInkingActive = false
    private var inkingBeganAt = Date.distantPast
    private var inkIdleWork: [() -> Void] = []
    private var inkIdleRecheckScheduled = false

    /// 一筆畫最長算多久。超過就當成「結束的通知漏掉了」—— 卡在「落筆中」的話，
    /// 換頁、同步進來的筆跡會一直等下去，畫布停在舊的內容上，之後存檔就存錯頁。
    private static let maxStrokeDuration: TimeInterval = 8

    var isInking: Bool {
        let state = drawingGestureRecognizer.state
        if state == .began || state == .changed { return true }
        return isInkingActive && Date().timeIntervalSince(inkingBeganAt) < Self.maxStrokeDuration
    }

    func inkingBegan() {
        isInkingActive = true
        inkingBeganAt = Date()
    }

    func inkingEnded() {
        isInkingActive = false
        activePencilIsDown = false
        runInkIdleWork()
        checkPageBottomAfterInking()
    }

    private func checkPageBottomAfterInking() {
        let maxY = self.drawing.bounds.maxY
        if maxY > 0 && maxY + 200 > PageGeometry.height {
            (self.delegate as? CanvasRepresentable.Coordinator)?.parent.onReachedPageBottom?()
        }
    }

    /// 不在落筆就馬上做；在落筆就等這一筆抬起來。
    func whenInkIdle(_ work: @escaping () -> Void) {
        if isInking {
            inkIdleWork.append(work)
            scheduleInkIdleRecheck()
        } else {
            work()
        }
    }

    /// 保險：不只靠「結束」的通知。等著的事每一小段時間再看一次，筆一離開就做。
    private func scheduleInkIdleRecheck() {
        guard !inkIdleRecheckScheduled else { return }
        inkIdleRecheckScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            self.inkIdleRecheckScheduled = false
            if self.isInking {
                self.scheduleInkIdleRecheck()
            } else {
                self.isInkingActive = false
                self.runInkIdleWork()
            }
        }
    }

    private func runInkIdleWork() {
        guard !isInking, !inkIdleWork.isEmpty else { return }
        let work = inkIdleWork
        inkIdleWork.removeAll()
        work.forEach { $0() }
    }
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
            handler(.began, lassoPageLocation(of: first))
            return
        }
        guard let tracked = lassoTouch, touches.contains(tracked) else { return }
        handler(state, lassoPageLocation(of: tracked))
        if state != .changed { lassoTouch = nil }
    }

    /// 套索點要用**頁面座標**（與 `PKDrawing` 的筆畫同一套）。scroll view 自己的座標是
    /// 放大後的，直接拿來比對的話，縮放不是 1 時圈到的是別的位置 —— 有的筆畫選得到、
    /// 有的選不到，拖曳的位移也跟手指對不上。
    private func lassoPageLocation(of touch: UITouch) -> CGPoint {
        let loc = touch.location(in: self)
        let scale = max(zoomScale, 0.01)
        return CGPoint(x: loc.x / scale, y: loc.y / scale)
    }

    /// 中止進行中的套索追蹤（長按叫出飛梭工具盤時）。
    func cancelLassoTracking() {
        guard lassoTouch != nil else { return }
        lassoTouch = nil
        lassoTouchHandler?(.cancelled, .zero)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // 手勢辨識器比 view 先收到 touchesBegan：擦除中的範圍圓圈這時已經畫上去了，不能在這裡收掉。
        if !isEraserTracking { hoverPreview?.hide() }
        if lassoTouchHandler != nil {
            if let sv = enclosingScrollView(), sv.panGestureRecognizer.minimumNumberOfTouches < 2 {
                if savedEnclosingPanTouchesForLasso == nil {
                    savedEnclosingPanTouchesForLasso = sv.panGestureRecognizer.minimumNumberOfTouches
                    savedEnclosingScrollViewForLasso = sv
                }
                sv.panGestureRecognizer.minimumNumberOfTouches = 2
            }
        }
        forwardLasso(touches, .began)
        if touches.contains(where: { $0.type == .pencil }) {
            activePencilIsDown = true
        }
        activeTouchesCount += touches.count
        CanvasTouchState.activeDirectTouches = activeTouchesCount
        // 多指同時著地（例如雙指縮放或平移）時，第一指著地初期可能已向畫布起筆；
        // 偵測到 >= 2 指時立即取消進行中的單指起筆，杜絕雙指手勢結束後留下一點小墨點。
        // 但若為 Apple Pencil 運筆（或手掌側貼於螢幕），絕不可取消進行中的 Apple Pencil 筆跡！
        let hasPencilTouch = touches.contains(where: { $0.type == .pencil }) || activePencilIsDown || isInking
        if activeTouchesCount >= 2 && !hasPencilTouch {
            cancelInFlightStrokesForNavigation()
        }
        for touch in touches {
            if touch.type == .pencil {
                lastPencilLocation = touch.location(in: self)
                lastPencilMoveUptime = ProcessInfo.processInfo.systemUptime
                lastStrokeHadHoldDwell = false
                pencilMovedSinceDown = false
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
                lastPencilMoveUptime = ProcessInfo.processInfo.systemUptime
                lastStrokeHadHoldDwell = false
                pencilMovedSinceDown = true
                if pencilDwellWorkItem == nil {
                    schedulePencilDwellTimer()
                }
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
            activePencilIsDown = false
            pencilDwellWorkItem?.cancel()
            pencilDwellWorkItem = nil
        }
        activeTouchesCount = max(0, activeTouchesCount - touches.count)
        CanvasTouchState.activeDirectTouches = activeTouchesCount
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
            activePencilIsDown = false
            pencilDwellWorkItem?.cancel()
            pencilDwellWorkItem = nil
            lastStrokeHadHoldDwell = false
        }
        activeTouchesCount = max(0, activeTouchesCount - touches.count)
        CanvasTouchState.activeDirectTouches = activeTouchesCount
        super.touchesCancelled(touches, with: event)
        checkPendingRetract()
    }

    private func checkPendingRetract() {
        // 保險：萬一沒收到 `canvasViewDidEndUsingTool`（被別的手勢取消時），手放開之後也要把等著的事做完。
        if activeTouchesCount == 0, !inkIdleWork.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.activeTouchesCount == 0 else { return }
                if self.drawingGestureRecognizer.state != .began && self.drawingGestureRecognizer.state != .changed {
                    self.isInkingActive = false
                }
                self.runInkIdleWork()
            }
        }
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

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let check = hitPassThroughCheck, check(point, event) {
            return nil
        }
        return super.hitTest(point, with: event)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        delaysContentTouches = false
        configureEnclosingScrollView()
        if window != nil {
            refreshInitialRenderIfNeeded()
        }
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        delaysContentTouches = false
        configureEnclosingScrollView()
    }

    /// 外層 ScrollView（單頁模式或連續模式容器）預設 delaysContentTouches 為 true，
    /// 會在落筆初期扣押觸控 150ms 判定捲動，造成「不是即書即顯示」的起筆遲滯感。
    /// 設為 false 能直接消除此延遲，而 canCancelContentTouches 仍保持 true，不影響兩指或正常滑動捲動。
    private func configureEnclosingScrollView() {
        panGestureRecognizer.delaysTouchesBegan = false
        panGestureRecognizer.delaysTouchesEnded = false
        drawingGestureRecognizer.delaysTouchesBegan = false
        drawingGestureRecognizer.delaysTouchesEnded = false
        var parent = superview
        while let p = parent {
            if let sv = p as? UIScrollView, !(sv is PKCanvasView) {
                sv.delaysContentTouches = false
                sv.panGestureRecognizer.delaysTouchesBegan = false
                sv.panGestureRecognizer.delaysTouchesEnded = false
            }
            parent = p.superview
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        syncContentSize()
        refreshInitialRenderIfNeeded()
        hoverPreview?.frame = bounds
        if let preview = hoverPreview {
            bringSubviewToFront(preview)
        }
    }

    /// 重開舊筆記本時，載入的筆跡要使用者點一下畫布才會出現。
    ///
    /// `makeUIView` 在畫布進入視窗、有尺寸**之前**就指派了 `drawing`，PencilKit 在那個時間點
    /// 畫出來的是空的貼圖，之後內容沒變就不會重畫（縮圖用另一條路畫，所以縮圖是對的）。
    /// 畫布第一次有了視窗與尺寸之後，把同一份 `drawing` 再指派一次，強迫它重畫。
    /// 要包在 `isProgrammaticUpdate` 裡：不然 delegate 會把這份當成使用者的編輯存回去。
    private var didInitialRefresh = false

    /// 套索動作（拖曳、再製、貼上、刪除）改完筆跡後換上畫布。
    ///
    /// 直接 `canvas.drawing = x` 有兩個問題：delegate 會把每一次拖曳位移當成一次使用者
    /// 編輯（存檔、協同廣播、可列印範圍檢查全部跑一遍）；而且 PencilKit 在連續快速換
    /// `drawing` 時會漏掉重畫 —— 選取框跟著手指走，畫面上的筆跡卻停在半路，
    /// 看起來就是「拖不動」。這裡包在 `isProgrammaticUpdate` 裡換上，並強迫重畫。
    func showEditedDrawing(_ newDrawing: PKDrawing) {
        if drawingGestureRecognizer.isEnabled && lassoTouchHandler != nil {
            drawingGestureRecognizer.isEnabled = false
        }
        isInkingActive = false
        let coordinator = delegate as? CanvasRepresentable.Coordinator
        coordinator?.isProgrammaticUpdate = true
        self.drawing = newDrawing
        coordinator?.isProgrammaticUpdate = false
        // 畫布綁定的那一份也要一起換。連續頁面模式每一頁有自己的 `@State drawing`，
        // 不換的話下一次 `updateUIView` 會用舊的那份把畫布蓋回去 —— 筆跡跳回原位。
        coordinator?.publish(newDrawing)
        Self.invalidateCanvasTiles(in: self)
    }

    /// 收回「點選」順手畫下的墨點（判準見 `TapDotRetraction`），收掉了才呼叫 `onRetracted`。
    ///
    /// 直接改**這張畫布**：連續模式每頁有自己的畫布與 `@State drawing`，只改編輯器的
    /// `currentDrawing` 碰不到它 —— 原本的做法在連續模式下點完墨點照樣留在紙上。
    /// 點擊成立時墨點可能還沒交給畫布（PencilKit 稍後才收筆），所以等落筆結束再看，
    /// 沒找到就隔一小段再試；`tappedAt` 固定，之後才寫下的筆畫不會被當成墨點。
    func retractTapDots(
        near location: CGPoint, tappedAt: Date = Date(), maxCount: Int = 1,
        onRetracted: @escaping (PKDrawing) -> Void
    ) {
        attemptTapDotRetraction(location, tappedAt, maxCount, retriesLeft: 4, onRetracted)
    }

    private func attemptTapDotRetraction(
        _ location: CGPoint, _ tappedAt: Date, _ maxCount: Int, retriesLeft: Int,
        _ onRetracted: @escaping (PKDrawing) -> Void
    ) {
        whenInkIdle { [weak self] in
            guard let self else { return }
            let before = self.drawing
            let cleaned = TapDotRetraction.retracting(
                before, near: location, tappedAt: tappedAt, maxCount: maxCount)
            let removed = before.strokes.count - cleaned.strokes.count
            guard removed > 0 else {
                guard retriesLeft > 0 else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
                    self?.attemptTapDotRetraction(
                        location, tappedAt, maxCount, retriesLeft: retriesLeft - 1, onRetracted)
                }
                return
            }
            let coordinator = self.delegate as? CanvasRepresentable.Coordinator
            coordinator?.isProgrammaticUpdate = true
            self.drawing = cleaned
            coordinator?.isProgrammaticUpdate = false
            // 與掌拒收回同一個做法：PencilKit 為那顆點登記的復原項已經失效，拿掉，
            // 否則按一次復原「什麼都沒變」。
            self.dropDeadUndoEntries(max: removed)
            coordinator?.publish(cleaned)
            // 下一筆要照常判斷是不是新筆畫（磁吸、成形靠筆數變多來認）。
            if let coordinator, coordinator.lastStrokeCountBeforeRefine > cleaned.strokes.count {
                coordinator.lastStrokeCountBeforeRefine = cleaned.strokes.count
            }
            onRetracted(cleaned)
        }
    }

    private static func invalidateCanvasTiles(in view: UIView) {
        view.setNeedsDisplay()
        view.layer.setNeedsDisplay()
        for subview in view.subviews {
            invalidateCanvasTiles(in: subview)
        }
    }

    /// 強制畫布立即重新刷出指定筆跡（若無傳入則取畫布既有 drawing），無需使用者落筆點擊觸發
    ///
    /// **落筆中不做**：這時指派會把正在寫的那一筆取消。綁定那一份由 `updateUIView` 等抬筆後再換上。
    /// 下一輪補畫時只在**畫布內容沒變**的情況下重新指派同一份 —— 原本是無條件把當時抓的那一份
    /// 再指派一次：這中間使用者剛好寫完一筆的話，那一筆就被舊的快照蓋掉（看起來是「寫好的字
    /// 消失，過一會兒又出現」：綁定裡還有它，下一次 `updateUIView` 又把它放回來）。
    func forceDisplayRefresh(with newDrawing: PKDrawing? = nil) {
        guard !isInking else { return }
        let coordinator = delegate as? CanvasRepresentable.Coordinator
        let target = newDrawing ?? self.drawing
        guard target.strokes.count > 0 else { return }
        if self.drawing != target {
            coordinator?.isProgrammaticUpdate = true
            self.drawing = target
            coordinator?.isProgrammaticUpdate = false
            coordinator?.noteCanvasShows(target)
        }
        if ProcessInfo.processInfo.environment["KAIRUMO_UITEST"] == "1" {
            self.accessibilityValue = CanvasRepresentable.testReadout(self)
        }
        Self.invalidateCanvasTiles(in: self)
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
        // 堆疊頂端是物件的復原項（CanvasObjectHistory）就停：那不是筆畫，「復原一次看畫面有沒有變」
        // 的判斷對它不成立，會把使用者真正的一步（例如搬圖）當成失效項吃掉。
        while dropped < max, manager.canUndo, manager.undoActionName != CanvasObjectHistory.actionName {
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

    func resetInitialRefreshFlag() {
        didInitialRefresh = false
    }

    private func refreshInitialRenderIfNeeded() {
        guard !didInitialRefresh, window != nil, bounds.width > 1, bounds.height > 1 else { return }
        let strokeCount = max(drawing.strokes.count, initialLoadedStrokeCount)
        guard strokeCount > 0 else { return }
        didInitialRefresh = true
        guard activeTouchesCount == 0, !isInking else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self, self.window != nil, self.activeTouchesCount == 0, !self.isInking else { return }
            CanvasDiag.log("初次補畫重新指派 drawing（\(self.drawing.strokes.count) 筆）")
            let coordinator = self.delegate as? CanvasRepresentable.Coordinator
            let current = self.drawing
            guard current.strokes.count > 0 else { return }
            coordinator?.isProgrammaticUpdate = true
            self.drawing = PKDrawing()
            self.drawing = current
            coordinator?.isProgrammaticUpdate = false
            self.setNeedsDisplay()
            for subview in self.subviews {
                subview.setNeedsDisplay()
            }
            if ProcessInfo.processInfo.environment["KAIRUMO_UITEST"] == "1" {
                self.accessibilityValue = CanvasRepresentable.testReadout(self)
            }
        }
    }

    /// 把整頁（或指定倍率）顯示在可視區內，並回到頁面左上角。
    ///
    /// 與捏合縮放是兩件事：捏合看「某個區域」，這個看「整頁」。
    func applyPageZoom(_ target: PageViewportLayout.ZoomTarget) {
        let scale = PageViewportLayout.zoomScale(
            for: target,
            viewport: CGSize(width: bounds.width, height: bounds.height),
            page: CGSize(width: PageGeometry.width, height: max(pageContentHeight, 1)),
            range: minimumZoomScale...max(maximumZoomScale, minimumZoomScale))
        setZoomScale(scale, animated: true)
        setContentOffset(.zero, animated: true)
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
    /// 判定觸控點是否應穿透畫布至底層（筆跡下方物件層）
    var hitPassThroughCheck: ((CGPoint, UIEvent?) -> Bool)? = nil
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
    /// 筆尖或單指落下停住不動：叫出飛梭工具盤（window 座標）。回傳 true 表示已處理。
    var onPressAndHold: ((CGPoint) -> Bool)? = nil
    /// 外面要求專業筆畫層從磁碟重讀（別台同步進來）時加一。只重讀那一層，不重建畫布。
    var proReloadToken: Int = 0

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
        canvas.clipsToBounds = false
        canvas.delaysContentTouches = false
        canvas.hitPassThroughCheck = hitPassThroughCheck
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
        context.coordinator.lastSyncedDrawing = drawing
        context.coordinator.lastProReloadToken = proReloadToken

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
            let tool = coordinator.parent.selectedTool
            let width = (tool == .eraser) ? coordinator.parent.pixelEraserWidth : coordinator.parent.strokeWidth
            return BrushCursor.path(
                for: tool,
                strokeWidth: width)
        }
        context.coordinator.penHover.currentColor = { [weak coordinator = context.coordinator] in
            guard let coordinator else { return .label }
            if coordinator.parent.selectedTool == .eraser {
                return UIColor.secondaryLabel
            }
            return UIColor(coordinator.parent.selectedColor)
        }
        context.coordinator.penHover.eraserDiameter = { [weak coordinator = context.coordinator, weak canvas] in
            guard let coordinator, coordinator.parent.selectedTool == .eraser else { return nil }
            return coordinator.parent.pixelEraserWidth * max(canvas?.zoomScale ?? 1, 0.01)
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
        canvas.eraserWidth = pixelEraserWidth
        canvas.refreshPointer(for: selectedTool, strokeWidth: pointerWidth(zoom: canvas.zoomScale))
        canvas.pageContentHeight = PageGeometry.height
        canvas.contentSize = CGSize(width: max(canvas.bounds.width, 1), height: canvas.pageContentHeight)

        // 嵌入底層背景樣板視圖（隨畫布滾動）
        
        // 🌟 新增手勢：雙指點擊復原、三指點擊重做、三指上下滑動換頁
        let twoFingerTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTwoFingerTap(_:)))
        twoFingerTap.numberOfTouchesRequired = 2
        twoFingerTap.delaysTouchesBegan = false
        twoFingerTap.delaysTouchesEnded = false
        twoFingerTap.cancelsTouchesInView = false
        twoFingerTap.delegate = context.coordinator
        canvas.addGestureRecognizer(twoFingerTap)
        
        let threeFingerTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleThreeFingerTap(_:)))
        threeFingerTap.numberOfTouchesRequired = 3
        threeFingerTap.delaysTouchesBegan = false
        threeFingerTap.delaysTouchesEnded = false
        threeFingerTap.cancelsTouchesInView = false
        threeFingerTap.delegate = context.coordinator
        canvas.addGestureRecognizer(threeFingerTap)
        
        let swipeUp = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleThreeFingerSwipeUp(_:)))
        swipeUp.numberOfTouchesRequired = 3
        swipeUp.direction = .up
        swipeUp.delaysTouchesBegan = false
        swipeUp.delaysTouchesEnded = false
        swipeUp.cancelsTouchesInView = false
        swipeUp.delegate = context.coordinator
        canvas.addGestureRecognizer(swipeUp)
        
        let swipeDown = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleThreeFingerSwipeDown(_:)))
        swipeDown.numberOfTouchesRequired = 3
        swipeDown.direction = .down
        swipeDown.delaysTouchesBegan = false
        swipeDown.delaysTouchesEnded = false
        swipeDown.cancelsTouchesInView = false
        swipeDown.delegate = context.coordinator
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

        // 🌟 方案 A+B：手指／游標／Pencil 單擊與雙擊手勢（支援 direct / indirectPointer / pencil 全輸入型態）
        // 點擊事件由 handleCanvasDirectTap 依落點判斷：若落在物件上則選取物件並收回可能落下的墨點；
        // 若手寫模式下落在空白處則正常視為筆跡（不收回），雙擊則就地開文字框。
        let initialTapTypes: [NSNumber] = [
            NSNumber(value: UITouch.TouchType.direct.rawValue),
            NSNumber(value: UITouch.TouchType.indirectPointer.rawValue),
            NSNumber(value: UITouch.TouchType.pencil.rawValue)
        ]

        let directSingleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDirectSingleTap(_:)))
        directSingleTap.numberOfTapsRequired = 1
        directSingleTap.allowedTouchTypes = initialTapTypes
        directSingleTap.cancelsTouchesInView = false
        directSingleTap.delaysTouchesBegan = false
        directSingleTap.delaysTouchesEnded = false
        directSingleTap.name = Coordinator.directTapName
        directSingleTap.delegate = context.coordinator

        let directDoubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDirectDoubleTap(_:)))
        directDoubleTap.numberOfTapsRequired = 2
        directDoubleTap.allowedTouchTypes = initialTapTypes
        directDoubleTap.cancelsTouchesInView = false
        directDoubleTap.delaysTouchesBegan = false
        directDoubleTap.delaysTouchesEnded = false
        directDoubleTap.name = Coordinator.directTapName
        directDoubleTap.delegate = context.coordinator
        directSingleTap.require(toFail: directDoubleTap)

        canvas.addGestureRecognizer(directDoubleTap)
        canvas.addGestureRecognizer(directSingleTap)
        canvas.directSingleTap = directSingleTap
        canvas.directDoubleTap = directDoubleTap

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
        // 套索只在手繪模式接管觸控。切到打字模式時工具還停在套索的話，原本照樣把單指觸控與
        // 捲動搶走：即點即書、點選與單指捲動全部失效（Android 實機回報的同一個邏輯漏洞）。
        let lassoOwnsTouches = selectedTool == .lasso && editorMode == .draw
        if let adaptive = uiView as? AdaptiveCanvasView {
            adaptive.setLassoClaimsSingleTouch(lassoOwnsTouches)
            adaptive.lassoTouchHandler = lassoOwnsTouches
                ? { [weak coordinator = context.coordinator] state, point in
                    coordinator?.handleLassoTouch(state, point)
                } : nil
            adaptive.onPressAndHold = onPressAndHold == nil ? nil : { [weak coordinator = context.coordinator] point in
                coordinator?.parent.onPressAndHold?(point) ?? false
            }
        }
        // 模式切換時要跟著改 —— 只在 makeUIView 設的話，從連續切回整頁
        // 會得到一個捲不動的畫布（SwiftUI 會重用同一個 UIView）。
        // 套索模式下單頁畫布的捲動手勢要讓出來，否則套索的拖曳辨識不起來。
        let wantsScroll = isScrollEnabled && !lassoOwnsTouches
        if uiView.isScrollEnabled != wantsScroll {
            uiView.isScrollEnabled = wantsScroll
            uiView.alwaysBounceVertical = wantsScroll
            uiView.showsVerticalScrollIndicator = wantsScroll
        }
        // 打字模式關閉落筆手勢（從根源杜絕留下墨點），手繪模式才開放。
        // 套索、遮蔽膠帶與掃描翻譯筆模式下亦關閉繪圖手勢，確保所有碰觸皆由自定義物件層全權接收。
        let gestureOn = EditorCanvasInputPolicy.drawingGestureEnabled(effectiveMode: editorMode) && (selectedTool != .lasso) && (selectedTool != .maskingTape) && (selectedTool != .translationPen)
        if uiView.drawingGestureRecognizer.isEnabled != gestureOn {
            uiView.drawingGestureRecognizer.isEnabled = gestureOn
        }
        let targetPolicy = resolvedPolicy()
        if uiView.drawingPolicy != targetPolicy {
            uiView.drawingPolicy = targetPolicy
        }
        if let adaptive = uiView as? AdaptiveCanvasView {
            let tapTypes: [NSNumber] = [
                NSNumber(value: UITouch.TouchType.direct.rawValue),
                NSNumber(value: UITouch.TouchType.indirectPointer.rawValue),
                NSNumber(value: UITouch.TouchType.pencil.rawValue)
            ]
            adaptive.directSingleTap?.allowedTouchTypes = tapTypes
            adaptive.directDoubleTap?.allowedTouchTypes = tapTypes
        }
        // 連續模式（畫布自己不捲）且手指會畫圖時，兩指捲動由我們自己接管；
        // `.pencilOnly` 時手指不畫，外層捲動單指就能動，不必（也不該）再轉發。
        if let adaptive = uiView as? AdaptiveCanvasView {
            adaptive.twoFingerScroll.setEnabled(
                !isScrollEnabled && (targetPolicy == .anyInput || lassoOwnsTouches || selectedTool == .maskingTape || selectedTool == .translationPen), on: adaptive)
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
            adaptive.hitPassThroughCheck = hitPassThroughCheck
            adaptive.onPencilTouchBegan = onPencilTouchBegan
            adaptive.installPointerInteractionIfNeeded(delegate: context.coordinator)
            adaptive.eraserWidth = pixelEraserWidth
            adaptive.refreshPointer(for: selectedTool, strokeWidth: pointerWidth(zoom: adaptive.zoomScale))
        }

        // 綁定被外面換過（換頁、讀檔、同步、套索、復原……）才動畫布；見 `lastSyncedDrawing`。
        let coordinator = context.coordinator
        if drawing != coordinator.lastSyncedDrawing {
            if uiView.drawing == drawing {
                coordinator.lastSyncedDrawing = drawing
            } else if let adaptive = uiView as? AdaptiveCanvasView, adaptive.isInking {
                // 正在寫：現在換會把寫到一半的那一筆取消。抬筆再換，並補上這一筆。
                CanvasDiag.log("落筆中收到外部筆跡（\(drawing.strokes.count) 筆），延後到抬筆")
                coordinator.deferExternal(drawing, on: adaptive)
            } else {
                CanvasDiag.log("updateUIView 換上外部筆跡：畫布 \(uiView.drawing.strokes.count) 筆 → \(drawing.strokes.count) 筆")
                coordinator.applyExternal(drawing, to: uiView)
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
        // 專業筆畫層：外面要求重讀（別台同步進來）時重讀，落筆中等抬筆。
        if proReloadToken != coordinator.lastProReloadToken {
            coordinator.lastProReloadToken = proReloadToken
            if let adaptive = uiView as? AdaptiveCanvasView {
                adaptive.whenInkIdle { [weak adaptive] in adaptive?.proLayer?.reload() }
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

    /// 游標要用的寬度（螢幕點）。
    ///
    /// 橡皮擦：兩種模式都用使用者在工具列選的擦除寬度（原本筆劃模式寫死 24，拉滑桿游標完全不變），
    /// 並乘上縮放倍率 —— 畫布放大兩倍時，同一塊擦除範圍在螢幕上也是兩倍大。
    func pointerWidth(zoom: CGFloat) -> CGFloat {
        selectedTool == .eraser ? pixelEraserWidth * max(zoom, 0.01) : strokeWidth
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
            let widthFactor: CGFloat = selectedTool == .brush ? 1.65 : 1.4
            adaptive.proWidth = Float(max(1.2, strokeWidth * widthFactor))
            adaptive.proLayerId = 0
            adaptive.proLineType = 0
            adaptive.proSnapStep = nil
        }
        // 與 PencilKit 橡皮擦同一個寬度（兩種模式皆是），螢幕上的圓圈才與實際擦除範圍一比一。
        adaptive.proEraserRadius = max(4, pixelEraserWidth / 2)
        adaptive.proAllowsFinger = { [palmRejection] in
            if fingerRule == false { return false }
            return (palmRejection?.drawingPolicy(now: Date()) ?? .anyInput) == .anyInput
        }
        let allowsPencilKitDrawing = EditorCanvasInputPolicy.drawingGestureEnabled(effectiveMode: editorMode)
            && (selectedTool != .lasso)
            && (selectedTool != .maskingTape)
            && (selectedTool != .translationPen)
        adaptive.configurePro(
            mode: mode, directory: proInk?.directory,
            notebookId: proInk?.notebookId ?? "", pageIndex: proInk?.pageIndex ?? 0,
            pencilOnly: fingerRule == false,
            allowsPencilKitDrawing: allowsPencilKitDrawing,
            claimsSingleTouch: selectedTool == .lasso && editorMode == .draw)
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

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let canvas = gestureRecognizer.view as? AdaptiveCanvasView else { return true }
            if gestureRecognizer is UISwipeGestureRecognizer || (gestureRecognizer as? UITapGestureRecognizer)?.numberOfTouchesRequired ?? 1 >= 2 {
                // Apple Pencil 正在落筆或畫布處於手繪中，多指手勢嚴格拒絕接收觸控
                if touch.type == .pencil || canvas.isInking || canvas.activePencilIsDown {
                    return false
                }
                // 手掌側貼於螢幕之接觸面半徑（majorRadius 通常 > 20-30pt），過大視為掌心誤觸
                if touch.majorRadius > 24.0 {
                    return false
                }
            }
            return true
        }

        // orphan-ok: UIGestureRecognizerDelegate 系統回呼（書寫中阻擋雙指/三指點擊與滑動防跳頁）
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let canvas = gestureRecognizer.view as? AdaptiveCanvasView else { return true }
            if gestureRecognizer is UISwipeGestureRecognizer || (gestureRecognizer as? UITapGestureRecognizer)?.numberOfTouchesRequired ?? 1 >= 2 {
                if canvas.isInking || canvas.activePencilIsDown {
                    return false
                }
            }
            return true
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
            let point = Self.pageLocation(of: gesture, in: canvas)
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

        // unused-param-ok: UIScrollViewDelegate 回呼協定簽章由 UIKit 定死
        // orphan-ok: UIScrollViewDelegate 由系統 UIKit 呼叫的回呼
        func scrollViewWillBeginZooming(_: UIScrollView, with _: UIView?) {
            CanvasTouchState.isCanvasNavigating = true
        }

        // unused-param-ok: UIScrollViewDelegate 回呼協定簽章由 UIKit 定死
        // orphan-ok: UIScrollViewDelegate 由系統 UIKit 呼叫的回呼
        func scrollViewDidEndZooming(_: UIScrollView, with _: UIView?, atScale _: CGFloat) {
            CanvasTouchState.isCanvasNavigating = false
        }

        // orphan-ok: UIScrollViewDelegate 由系統 UIKit 呼叫的回呼
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            if scrollView.panGestureRecognizer.numberOfTouches >= 2 {
                CanvasTouchState.isCanvasNavigating = true
            }
        }

        // unused-param-ok: UIScrollViewDelegate 回呼協定簽章由 UIKit 定死
        // orphan-ok: UIScrollViewDelegate 由系統 UIKit 呼叫的回呼
        func scrollViewDidEndDragging(_: UIScrollView, decelerate: Bool) {
            if !decelerate {
                CanvasTouchState.isCanvasNavigating = false
            }
        }

        // unused-param-ok: UIScrollViewDelegate 回呼協定簽章由 UIKit 定死
        // orphan-ok: UIScrollViewDelegate 由系統 UIKit 呼叫的回呼
        func scrollViewDidEndDecelerating(_: UIScrollView) {
            CanvasTouchState.isCanvasNavigating = false
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            if let adaptive = scrollView as? AdaptiveCanvasView {
                adaptive.syncProLayerGeometry()
                // 橡皮擦游標要跟著縮放變大變小，否則放大後游標比實際擦除範圍小。
                adaptive.refreshPointer(for: parent.selectedTool, strokeWidth: parent.pointerWidth(zoom: scrollView.zoomScale))
            }
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

        // MARK: 畫布與綁定之間誰是新的

        /// 畫布與綁定上一次「講好」的那一份筆跡：畫布發布出去的，或從綁定換上畫布的。
        ///
        /// `updateUIView` 原本只比「畫布 ≠ 綁定」就把綁定那份換上畫布。可是綁定常常只是**比較舊**
        /// —— 剛寫完的那一筆還沒經過 delegate 寫回去、或是別的狀態先觸發了一輪更新 ——
        /// 於是剛寫好的字被舊快照蓋掉，等下一次回寫才又出現（「筆跡先消失再出現」）。
        ///
        /// 現在只有**綁定真的被外面換過**（≠ 這一份）才動畫布；綁定還是這一份、畫布卻不一樣，
        /// 代表畫布比較新（使用者剛寫的），什麼都不做，等 delegate 發布。
        var lastSyncedDrawing: PKDrawing?
        var lastProReloadToken = 0
        /// 落筆中收到的外部筆跡（同步、讀檔……），等抬筆再換上，見 `deferExternal`。
        private var deferredExternal: PKDrawing?
        private var deferredBase: PKDrawing?

        /// 把畫布的內容寫回綁定。
        func publish(_ drawing: PKDrawing) {
            lastSyncedDrawing = drawing
            parent.drawing = drawing
        }

        /// 畫布已經顯示這一份（程式直接指派過的）。
        func noteCanvasShows(_ drawing: PKDrawing) {
            if parent.drawing == drawing { lastSyncedDrawing = drawing }
        }

        /// 把外面給的筆跡換上畫布（不經 delegate、不當成使用者的編輯）。
        func applyExternal(_ drawing: PKDrawing, to canvas: PKCanvasView) {
            isProgrammaticUpdate = true
            canvas.drawing = drawing
            isProgrammaticUpdate = false
            lastSyncedDrawing = drawing
            if let adaptive = canvas as? AdaptiveCanvasView {
                adaptive.initialLoadedStrokeCount = drawing.strokes.count
                adaptive.forceDisplayRefresh(with: drawing)
            }
        }

        /// 落筆中收到外部筆跡：記下來，抬筆後換上，**並把這段期間寫的筆畫補進去**。
        ///
        /// 外面那一份是在這一筆之前算出來的，直接換上會把剛寫的字蓋掉。基準是落筆前講好的那一份：
        /// 畫布比它多出來的就是使用者這段期間寫的。
        func deferExternal(_ drawing: PKDrawing, on canvas: AdaptiveCanvasView) {
            if deferredExternal == nil { deferredBase = lastSyncedDrawing ?? PKDrawing() }
            deferredExternal = drawing
            let page = parent.proInk?.pageIndex
            canvas.whenInkIdle { [weak self, weak canvas] in
                guard let self, let canvas, let external = self.deferredExternal else { return }
                let base = self.deferredBase ?? PKDrawing()
                self.deferredExternal = nil
                self.deferredBase = nil
                // 等的這段期間換了頁：那一份已經不是這張畫布的了，新頁的由 `updateUIView` 換上。
                guard self.parent.proInk?.pageIndex == page else { return }
                let written = StrokeDelta.added(in: canvas.drawing, since: base)
                let fresh = StrokeDelta.added(in: PKDrawing(strokes: written), since: external)
                let merged = fresh.isEmpty ? external : PKDrawing(strokes: external.strokes + fresh)
                CanvasDiag.log("抬筆後換上延後的外部筆跡：\(external.strokes.count) 筆＋這段期間寫的 \(fresh.count) 筆")
                self.applyExternal(merged, to: canvas)
                self.publish(merged)
                if !fresh.isEmpty { _ = self.parent.onDrawingChanged?(merged) }
            }
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            (canvasView as? AdaptiveCanvasView)?.inkingBegan()
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            // `canvasViewDrawingDidChange` 可能在這之後才到：排到下一輪，確保這一筆已經發布。
            DispatchQueue.main.async { [weak canvasView] in
                (canvasView as? AdaptiveCanvasView)?.inkingEnded()
            }
        }

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
               !manager.isUndoing, !manager.isRedoing,
               manager.undoActionName != CanvasObjectHistory.actionName {
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
                coordinator.publish(target)
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
            publish(effective)

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
                    self.publish(canvasView.drawing)
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
            let isCurrentlyInking = (canvasView as? AdaptiveCanvasView)?.isInking ?? false
            if !isCurrentlyInking && maxY > 0 && maxY + 200 > PageGeometry.height {
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
            let curveMultiplier = pressureFeelWidthScale()
            switch parent.selectedTool {
            case .brush, .fineliner, .calligraphy, .charcoal, .crayon, .airbrush, .oilpaint:
                // 專業筆刷（含永字八法軟毫毛筆）由自繪引擎收筆（ProInk.swift），PencilKit 的落筆手勢在這時是關著的。
                // 這裡只放一支不會被用到的筆，讓畫布手上永遠有個合法的工具。
                canvas.tool = PKInkingTool(.pen, color: uiColor, width: max(1, parent.strokeWidth))

            case .pen:
                // 鋼筆：墨水充沛飽滿、帶有自然流暢的下筆壓力與速度過渡
                canvas.tool = PKInkingTool(.pen, color: uiColor, width: max(2.0, parent.strokeWidth * 1.1 * curveMultiplier))

            case .ballpoint:
                // 原子筆：恆定寬度、均勻工整、俐落乾脆之機械單線
                if #available(iOS 17.0, *) {
                    canvas.tool = PKInkingTool(.monoline, color: uiColor, width: max(1.2, parent.strokeWidth * 0.65))
                } else {
                    canvas.tool = PKInkingTool(.pen, color: uiColor, width: max(1.2, parent.strokeWidth * 0.65))
                }

            case .marker:
                // 麥克筆：厚實方形斜切筆觸、高飽和厚重墨水（Alpha 0.85）、設計草圖與手繪上色
                canvas.tool = PKInkingTool(.marker, color: uiColor.withAlphaComponent(0.85), width: max(8.0, parent.strokeWidth * 2.8 * curveMultiplier))

            case .highlighter:
                // 螢光筆：半透明寬扁筆刷（Alpha 0.35），重點標記不遮蔽底層筆跡
                canvas.tool = PKInkingTool(.marker, color: uiColor.withAlphaComponent(0.35), width: max(18.0, parent.strokeWidth * 3.8))

            case .pencil:
                // 鉛筆：石墨微顆粒磨砂質感、側鋒陰影素描
                canvas.tool = PKInkingTool(.pencil, color: uiColor.withAlphaComponent(0.85), width: max(2.0, parent.strokeWidth * 1.3 * curveMultiplier))

            case .watercolor:
                // 水彩筆：濕潤水墨層疊擴散與暈染效果
                if #available(iOS 17.0, *) {
                    canvas.tool = PKInkingTool(.watercolor, color: uiColor.withAlphaComponent(0.55), width: max(8.0, parent.strokeWidth * 2.4 * curveMultiplier))
                } else {
                    canvas.tool = PKInkingTool(.marker, color: uiColor.withAlphaComponent(0.5), width: max(8.0, parent.strokeWidth * 2.0 * curveMultiplier))
                }

            case .eraser:
                switch parent.eraserMode {
                case .stroke:
                    // 筆劃橡皮擦也吃寬度（iOS 16.4+）：碰到圓圈範圍內的整條筆劃就擦掉，與畫面上的圓一致。
                    if #available(iOS 16.4, *) {
                        canvas.tool = PKEraserTool(.vector, width: parent.pixelEraserWidth)
                    } else {
                        canvas.tool = PKEraserTool(.vector)
                    }
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

            case .maskingTape, .translationPen:
                // 遮蔽膠帶與掃描翻譯筆：自定義覆蓋層物件，不應指派為 PKLassoTool，
                // 以免與套索工具混淆。畫布在工具啟動時停用繪畫筆刷以確保手勢完全由覆蓋層接收。
                break
            }
        }

        /// 依據使用者設定的壓感曲線（`pressureFloor` 與 `pressureGamma`）計算 PencilKit 筆刷的等效筆寬倍率。
        private func pressureFeelWidthScale() -> CGFloat {
            let prefs = ProfileDefaults.current
            let floor = prefs.object(forKey: "kairumo.pen.pressureFloor") != nil
                ? Double(prefs.float(forKey: "kairumo.pen.pressureFloor"))
                : 0.15
            let gamma = prefs.object(forKey: "kairumo.pen.pressureGamma") != nil
                ? Double(prefs.float(forKey: "kairumo.pen.pressureGamma"))
                : 1.0
            let clampedFloor = max(0.0, min(0.5, floor))
            let clampedGamma = max(0.5, min(2.2, gamma))
            let midResponse = pow(0.65, clampedGamma - 1.0) * (0.92 + 0.55 * clampedFloor)
            return CGFloat(max(0.75, min(1.35, midResponse)))
        }

        /// 從 ProfileDefaults 讀取使用者設定的壓感曲線並確認範圍合法。
        func applyPressureCurve() {
            let prefs = ProfileDefaults.current
            if prefs.object(forKey: "kairumo.pen.pressureFloor") != nil {
                let floor = Double(prefs.float(forKey: "kairumo.pen.pressureFloor"))
                prefs.set(Float(max(0.0, min(0.5, floor))), forKey: "kairumo.pen.pressureFloor")
            }
            if prefs.object(forKey: "kairumo.pen.pressureGamma") != nil {
                let gamma = Double(prefs.float(forKey: "kairumo.pen.pressureGamma"))
                prefs.set(Float(max(0.5, min(2.2, gamma))), forKey: "kairumo.pen.pressureGamma")
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

