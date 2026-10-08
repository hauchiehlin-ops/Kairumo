//
//  ContinuousPagesView.swift
//  Kairumo
//
//  連續頁面模式：一路往下捲，不必按上一頁／下一頁。
//
//  # 為什麼是「加一個模式」而不是改造原本的畫布
//
//  整頁模式的那條路（單一 `CanvasRepresentable` ＋ `currentPageIndex`）
//  綁著存檔、協同 oplog、掌拒、套索與捲軸比例，是這個 App 最沒有本錢壞掉
//  的一段。所以這裡**完全不動它** —— 連續模式是另一棵視圖樹，共用同一組
//  元件（`CanvasRepresentable`、`objectLayer(forPage:)`），單頁模式的行為
//  一個位元都沒變。
//
//  # 頁面高度是固定的，所以捲動很單純
//
//  P-01 已經把頁面尺寸釘在 800 × 1132（來源在核心）。連續模式因此只是
//  「把 N 個固定高度的頁面疊起來」，不需要任何新的座標換算。
//

import PencilKit
import UniformTypeIdentifiers
import SwiftUI

/// 頁面顯示模式。
public enum PageDisplayMode: String, CaseIterable {
    /// 一次一頁，用上一頁／下一頁切換（預設）。
    case single
    /// 所有頁面接續排列，一路往下捲。
    case continuous
}

/// 連續模式裡的一頁：自己的畫布 ＋ 自己的物件層。
///
/// 筆跡各自載入與存檔。共用一份 `PKDrawing` 的話，在第 7 頁寫的筆畫會被
/// 寫進第 1 頁的檔案裡 —— 那是資料損毀，不是顯示問題。
struct ContinuousPageView<ObjectLayer: View>: View {
    let pageIndex: Int
    let notebookId: String
    let paperId: String
    let paletteId: String?
    let store: NotebookStore

    let selectedTool: EditorToolType
    let selectedColor: Color
    let strokeWidth: CGFloat
    let isRulerActive: Bool
    let editorMode: EditorMode
    var eraserMode: EraserMode = .stroke
    var pixelEraserWidth: CGFloat = 20.0
    let palmRejection: PalmRejectionCoordinator?

    /// 這一頁是不是目前的焦點頁。插入物件、工具列動作都以焦點頁為準。
    let isFocused: Bool
    /// 這一頁的物件層，由呼叫端提供（它才拿得到那一大串 binding 與 callback）。
    let objectLayer: () -> ObjectLayer
    /// 筆跡有變動時通知呼叫端（協同廣播用）。
    let onDrawingChanged: (Int, PKDrawing) -> Void
    /// 套索選取狀態。只有焦點頁回報 —— 每一頁都報的話，捲過別頁就會把
    /// 焦點頁的選取狀態蓋掉，工具列的按鈕跟著閃。
    let onSelectionChanged: (Bool) -> Void
    /// 寫到這一頁的底部。最後一頁時要準備下一頁。
    let onReachedPageBottom: () -> Void
    /// 這一頁的畫布實體。焦點頁的才交出去（undo／草圖美化要用）。
    let canvasRef: (PKCanvasView) -> Void
    var onCanvasTap: ((CGPoint) -> Void)? = nil
    var onCanvasDoubleTap: ((CGPoint) -> Void)? = nil
    var onPencilTouchBegan: (() -> Void)? = nil
    /// Apple Pencil 雙擊筆桿（工作項 S-67）。只有焦點頁回報 —— 每一頁都報的話，
    /// 一次雙擊會被當成好幾次，工具在筆與橡皮擦之間跳回原地。
    var onPenControl: ((FfiPenControl, Bool) -> Void)? = nil
    /// 有圖片拖到這一頁上（工作項 S-68）。落點是**這一頁的**座標。
    var onImageDropped: ((Int, [NSItemProvider], CGPoint) -> Bool)? = nil
    /// 這一頁第一次載入完（筆跡剛從磁碟讀進來、還沒有任何編輯）。
    /// 呼叫端用它記下「初始狀態」—— 連續模式的頁面不經過整頁模式的換頁，
    /// 沒有這一步，「一鍵恢復初始狀態」就不知道這些頁面原本長什麼樣。
    var onInitialLoaded: ((Int, PKDrawing) -> Void)? = nil
    /// 呼叫端要求整頁重讀（恢復初始狀態之後）。數字一變，畫布連同專業筆畫層重建、筆跡重新從磁碟載入。
    var reloadGeneration: Int = 0
    @Binding var notebook: NotebookDocument
    var onNotebookChanged: (() -> Void)? = nil
    var onLassoBegan: ((CGPoint) -> Void)? = nil
    var onLassoMoved: ((CGPoint) -> Void)? = nil
    var onLassoEnded: (() -> Void)? = nil
    var lassoPath: [CGPoint] = []
    var isLassoCommitted: Bool = true

    @State private var drawing = PKDrawing()
    @State private var loaded = false
    @State private var isDropTargeted = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            PageBackgroundRepresentable(
                paperId: paperId,
                paletteId: paletteId,
                pageIndex: pageIndex,
                checkedGuideItems: notebook.checkedGuideItems
            )
                .frame(width: PageGeometry.width, height: PageGeometry.height, alignment: .topLeading)
                .allowsHitTesting(false)
                .zIndex(0)

            objectLayer()
                .frame(width: PageGeometry.width, height: PageGeometry.height, alignment: .topLeading)
                .allowsHitTesting(editorMode == .type)
                .zIndex(editorMode == .type ? 3 : 1)

            CanvasRepresentable(
                drawing: $drawing,
                proInk: ProInkBinding(
                    directory: store.drawingsDirectory, notebookId: notebookId, pageIndex: pageIndex),
                selectedTool: selectedTool,
                selectedColor: selectedColor,
                strokeWidth: strokeWidth,
                eraserMode: eraserMode,
                pixelEraserWidth: pixelEraserWidth,
                isRulerActive: isRulerActive,
                paperId: paperId,
                paletteId: paletteId,
                pageHeight: PageGeometry.height,
                editorMode: editorMode,
                // 裡層不捲 —— 外面那個 ScrollView 才是捲動的主體。
                isScrollEnabled: false,
                onDrawingChanged: { updated -> PKDrawing? in
                    onDrawingChanged(pageIndex, updated)
                    // 連續模式不做可列印範圍的收回（整頁模式才做），
                    // 所以沒有要修正的東西。
                    return nil
                },
                onReachedPageBottom: { if isFocused { onReachedPageBottom() } },
                onSelectionChanged: { hasSelection in
                    if isFocused { onSelectionChanged(hasSelection) }
                },
                onLassoBegan: { pt in if isFocused { onLassoBegan?(pt) } },
                onLassoMoved: { pt in if isFocused { onLassoMoved?(pt) } },
                onLassoEnded: { if isFocused { onLassoEnded?() } },
                canvasRef: { canvas in if isFocused { canvasRef(canvas) } },
                palmRejection: palmRejection,
                onPenControl: { control, pressed in
                    if isFocused { onPenControl?(control, pressed) }
                },
                onPencilTouchBegan: {
                    if isFocused { onPencilTouchBegan?() }
                },
                onCanvasDirectTap: { location in
                    onCanvasTap?(location)
                },
                onCanvasDirectDoubleTap: { location in
                    onCanvasDoubleTap?(location)
                },
                onPencilTapInTypeMode: { location in
                    onCanvasTap?(location)
                }
            )
            .id(reloadGeneration)
            .frame(width: PageGeometry.width, height: PageGeometry.height, alignment: .topLeading)
            .allowsHitTesting(true)
            .zIndex(editorMode == .draw ? 2 : 1)
            .overlay(alignment: .topLeading) {
                if selectedTool == .lasso && isFocused && !lassoPath.isEmpty {
                    LassoPathOverlay(
                        path: lassoPath,
                        isCommitted: isLassoCommitted
                    )
                    .allowsHitTesting(false)
                }
            }

            MaskingTapeOverlayView(
                notebook: $notebook,
                pageIndex: pageIndex,
                isActive: isFocused && selectedTool == .maskingTape,
                selectedColor: selectedColor,
                onTapesChanged: {
                    onNotebookChanged?()
                }
            )
            .frame(width: PageGeometry.width, height: PageGeometry.height, alignment: .topLeading)
            .allowsHitTesting((isFocused && selectedTool == .maskingTape) || (editorMode != .draw && !(notebook.tapeAttachments?.filter { $0.pageIndex == pageIndex }.isEmpty ?? true)))
            .zIndex((isFocused && selectedTool == .maskingTape) ? 4 : 2.5)
        }
        .coordinateSpace(name: CanvasCoordinateSpace.name)
        .contentShape(Rectangle())
        // 拖到哪一頁就插到哪一頁 —— 連續模式下每一頁都是自己的落點。
        .onDrop(of: [.image], isTargeted: $isDropTargeted) { providers, location in
            onImageDropped?(pageIndex, providers, location) ?? false
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                    .background(Color.accentColor.opacity(0.08))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: PageGeometry.width, height: PageGeometry.height)
        .background(Color(uiColor: .systemBackground))
        .overlay(
            // 焦點頁描一圈，使用者才知道現在插入的東西會落在哪一頁。
            Rectangle()
                .strokeBorder(
                    isFocused ? Color.accentColor.opacity(0.45) : Color.secondary.opacity(0.18),
                    lineWidth: isFocused ? 1.5 : 1
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
        .overlay(alignment: .bottomTrailing) {
            Text("\(pageIndex + 1)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(6)
        }
        .task(id: loaded) {
            // 只載一次。每次重繪都載的話，正在寫的那一頁會被硬碟上的舊版覆蓋。
            guard !loaded else { return }
            drawing = store.loadDrawing(notebookId: notebookId, pageIndex: pageIndex)
            loaded = true
            onInitialLoaded?(pageIndex, drawing)
        }
        .onChange(of: reloadGeneration) { _ in
            drawing = store.loadDrawing(notebookId: notebookId, pageIndex: pageIndex)
        }
    }
}


/// 連續模式用的座標空間名稱。
enum ContinuousPagesSpace {
    static let name = "kairumoContinuousPages"
}

/// 每一頁在捲動容器裡的中線 y。用來挑出焦點頁。
struct PageFocusPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}


/// 連續模式下的兩指捲動。
///
/// # 為什麼不能交給系統
///
/// 連續模式的頁面是一個外層 `ScrollView` 裡的多張畫布，畫布自己不捲（`isScrollEnabled = false`）。
/// `.anyInput` 時手指會畫圖，所以「兩指捲動」得靠外層捲動手勢搶贏畫布的落筆手勢 ——
/// 而那是**競賽**：第一指落下的瞬間畫布就開始畫了，第二指有沒有及時趕上、外層手勢能不能接手，
/// 取決於兩指落下的時間差。結果就是使用者回報的「時好時壞」：有時捲得動，有時畫出一道線，有時兩者都沒有。
///
/// 這裡改成確定性的做法：畫布上掛一個**兩指**拖曳手勢，一認得就
/// ① 關掉畫布的落筆手勢（會把第一指已經畫的那一筆取消）、
/// ② 關掉外層捲動自己的手勢（免得兩邊各捲一次，速度變兩倍）、
/// ③ 自己改外層的 `contentOffset`，放開時用速度做慣性減速。
final class TwoFingerScrollForwarder: NSObject, UIGestureRecognizerDelegate {
    private weak var canvas: PKCanvasView?
    private weak var scrollView: UIScrollView?
    private var drawingWasEnabled = true
    private var lastTranslationY: CGFloat = 0
    private var displayLink: CADisplayLink?
    private var velocity: CGFloat = 0
    private var lastTick: CFTimeInterval = 0

    private lazy var recognizer: UIPanGestureRecognizer = {
        let g = UIPanGestureRecognizer(target: self, action: #selector(handle(_:)))
        g.minimumNumberOfTouches = 2
        g.maximumNumberOfTouches = 2
        g.cancelsTouchesInView = false
        g.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        g.delegate = self
        return g
    }()

    /// 掛上或拿掉。畫布重用時（單頁／連續互換）要拿掉，否則單頁模式會跟畫布自己的捲動搶。
    func setEnabled(_ on: Bool, on canvas: PKCanvasView) {
        self.canvas = canvas
        if on {
            if recognizer.view !== canvas { canvas.addGestureRecognizer(recognizer) }
        } else {
            if recognizer.view != nil { recognizer.view?.removeGestureRecognizer(recognizer) }
            stopMomentum()
        }
    }

    private func enclosingScrollView() -> UIScrollView? {
        var view = canvas?.superview
        while let v = view {
            if let sv = v as? UIScrollView, !(sv is PKCanvasView) { return sv }
            view = v.superview
        }
        return nil
    }

    @objc private func handle(_ g: UIPanGestureRecognizer) {
        switch g.state {
        case .began:
            stopMomentum()
            scrollView = enclosingScrollView()
            lastTranslationY = 0
            if let canvas {
                drawingWasEnabled = canvas.drawingGestureRecognizer.isEnabled
                canvas.drawingGestureRecognizer.isEnabled = false
            }
            scrollView?.panGestureRecognizer.isEnabled = false
        case .changed:
            let y = g.translation(in: nil).y
            scroll(by: -(y - lastTranslationY))
            lastTranslationY = y
        case .ended, .cancelled, .failed:
            let v = -g.velocity(in: nil).y
            finish()
            if g.state == .ended { startMomentum(velocity: v) }
        default:
            break
        }
    }

    private func finish() {
        if let canvas { canvas.drawingGestureRecognizer.isEnabled = drawingWasEnabled }
        scrollView?.panGestureRecognizer.isEnabled = true
    }

    private func scroll(by dy: CGFloat) {
        guard let sv = scrollView else { return }
        let minY = -sv.adjustedContentInset.top
        let maxY = max(minY, sv.contentSize.height - sv.bounds.height + sv.adjustedContentInset.bottom)
        let y = min(max(sv.contentOffset.y + dy, minY), maxY)
        sv.contentOffset = CGPoint(x: sv.contentOffset.x, y: y)
    }

    private func startMomentum(velocity: CGFloat) {
        guard abs(velocity) > 80, scrollView != nil else { return }
        self.velocity = velocity
        lastTick = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        let dt = min(now - lastTick, 0.05)
        lastTick = now
        // 與 UIScrollView 的 normal 減速率同一個量級：每毫秒剩 0.998。
        velocity *= CGFloat(pow(0.998, dt * 1000))
        scroll(by: velocity * CGFloat(dt))
        if abs(velocity) < 20 { stopMomentum() }
    }

    private func stopMomentum() {
        displayLink?.invalidate()
        displayLink = nil
    }

    // 與畫布自己的手勢同時辨識 —— 不然落筆手勢一開始，這個就永遠起不來。
    func gestureRecognizer(
        _ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool { true }
}
