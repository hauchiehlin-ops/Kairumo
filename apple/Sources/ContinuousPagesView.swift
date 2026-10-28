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
    var isObjectActive: Bool = false

    /// 這一頁是不是目前的焦點頁。插入物件、工具列動作都以焦點頁為準。
    let isFocused: Bool
    /// 這一頁的物件層，由呼叫端提供（它才拿得到那一大串 binding 與 callback）。
    let objectLayer: () -> ObjectLayer
    var underInkObjectLayer: (() -> AnyView)? = nil
    var overInkObjectLayer: (() -> AnyView)? = nil
    var isUnderInkPointPassThrough: ((_ point: CGPoint, _ page: Int, _ event: UIEvent?) -> Bool)? = nil
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
    /// 別台同步進來：只把磁碟上的新內容**合併**進這一頁的筆跡，不重建畫布（見 `mergeReloaded`）。
    /// 重建畫布會整頁白一下，寫到一半的那一筆也跟著不見 —— 同步每幾秒就一次，不能這樣做。
    var inkReloadGeneration: Int = 0
    /// 物件（文字、圖片、形狀……）改了：只重建物件層，不碰畫布。
    var objectGeneration: Int = 0
    /// 同步重讀：給這一頁畫面上的筆跡，回傳與磁碟合併後的結果。沒給就直接讀磁碟。
    var mergeReloaded: ((Int, PKDrawing) -> PKDrawing)? = nil
    /// 第一次載入用的筆跡（還沒寫出去的那一份優先）。沒給就直接讀磁碟。
    var initialDrawing: ((Int) -> PKDrawing)? = nil
    @Binding var notebook: NotebookDocument
    var onNotebookChanged: (() -> Void)? = nil
    var onLassoBegan: ((CGPoint) -> Void)? = nil
    var onLassoMoved: ((CGPoint) -> Void)? = nil
    var onLassoEnded: (() -> Void)? = nil
    /// 長按叫出飛梭工具盤（window 座標）。回傳 true 表示已處理。
    var onPressAndHold: ((CGPoint) -> Bool)? = nil
    /// 套索的圈、選取框與快顯工具列（頁面座標，由呼叫端畫）。只畫在焦點頁。
    var lassoDecoration: (() -> AnyView)? = nil

    @State private var drawing: PKDrawing
    @State private var loaded: Bool
    @State private var isDropTargeted = false

    init(
        pageIndex: Int,
        notebookId: String,
        paperId: String,
        paletteId: String?,
        store: NotebookStore,
        selectedTool: EditorToolType,
        selectedColor: Color,
        strokeWidth: CGFloat,
        isRulerActive: Bool,
        editorMode: EditorMode,
        eraserMode: EraserMode = .stroke,
        pixelEraserWidth: CGFloat = 20.0,
        palmRejection: PalmRejectionCoordinator?,
        isObjectActive: Bool = false,
        isFocused: Bool,
        @ViewBuilder objectLayer: @escaping () -> ObjectLayer,
        underInkObjectLayer: (() -> AnyView)? = nil,
        overInkObjectLayer: (() -> AnyView)? = nil,
        isUnderInkPointPassThrough: ((_ point: CGPoint, _ page: Int, _ event: UIEvent?) -> Bool)? = nil,
        onDrawingChanged: @escaping (Int, PKDrawing) -> Void,
        onSelectionChanged: @escaping (Bool) -> Void,
        onReachedPageBottom: @escaping () -> Void,
        canvasRef: @escaping (PKCanvasView) -> Void,
        onCanvasTap: ((CGPoint) -> Void)? = nil,
        onCanvasDoubleTap: ((CGPoint) -> Void)? = nil,
        onPencilTouchBegan: (() -> Void)? = nil,
        onPenControl: ((FfiPenControl, Bool) -> Void)? = nil,
        onImageDropped: ((Int, [NSItemProvider], CGPoint) -> Bool)? = nil,
        onInitialLoaded: ((Int, PKDrawing) -> Void)? = nil,
        reloadGeneration: Int = 0,
        inkReloadGeneration: Int = 0,
        objectGeneration: Int = 0,
        mergeReloaded: ((Int, PKDrawing) -> PKDrawing)? = nil,
        initialDrawing: ((Int) -> PKDrawing)? = nil,
        notebook: Binding<NotebookDocument>,
        onNotebookChanged: (() -> Void)? = nil,
        onLassoBegan: ((CGPoint) -> Void)? = nil,
        onLassoMoved: ((CGPoint) -> Void)? = nil,
        onLassoEnded: (() -> Void)? = nil,
        onPressAndHold: ((CGPoint) -> Bool)? = nil,
        lassoDecoration: (() -> AnyView)? = nil
    ) {
        self.pageIndex = pageIndex
        self.notebookId = notebookId
        self.paperId = paperId
        self.paletteId = paletteId
        self.store = store
        self.selectedTool = selectedTool
        self.selectedColor = selectedColor
        self.strokeWidth = strokeWidth
        self.isRulerActive = isRulerActive
        self.editorMode = editorMode
        self.eraserMode = eraserMode
        self.pixelEraserWidth = pixelEraserWidth
        self.palmRejection = palmRejection
        self.isObjectActive = isObjectActive
        self.isFocused = isFocused
        self.objectLayer = objectLayer
        self.underInkObjectLayer = underInkObjectLayer
        self.overInkObjectLayer = overInkObjectLayer
        self.isUnderInkPointPassThrough = isUnderInkPointPassThrough
        self.onDrawingChanged = onDrawingChanged
        self.onSelectionChanged = onSelectionChanged
        self.onReachedPageBottom = onReachedPageBottom
        self.canvasRef = canvasRef
        self.onCanvasTap = onCanvasTap
        self.onCanvasDoubleTap = onCanvasDoubleTap
        self.onPencilTouchBegan = onPencilTouchBegan
        self.onPenControl = onPenControl
        self.onImageDropped = onImageDropped
        self.onInitialLoaded = onInitialLoaded
        self.reloadGeneration = reloadGeneration
        self.inkReloadGeneration = inkReloadGeneration
        self.objectGeneration = objectGeneration
        self.mergeReloaded = mergeReloaded
        self.initialDrawing = initialDrawing
        self._notebook = notebook
        self.onNotebookChanged = onNotebookChanged
        self.onLassoBegan = onLassoBegan
        self.onLassoMoved = onLassoMoved
        self.onLassoEnded = onLassoEnded
        self.onPressAndHold = onPressAndHold
        self.lassoDecoration = lassoDecoration

        let initDrawing = initialDrawing?(pageIndex) ?? store.loadDrawing(notebookId: notebookId, pageIndex: pageIndex)
        self._drawing = State(initialValue: initDrawing)
        self._loaded = State(initialValue: true)
    }

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

            if let underInk = underInkObjectLayer {
                underInk()
                    .frame(width: PageGeometry.width, height: PageGeometry.height, alignment: .topLeading)
                    .allowsHitTesting(editorMode == .type || isObjectActive)
                    .id(objectGeneration)
                    .zIndex(1)
            }

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
                hitPassThroughCheck: { point, event in
                    isUnderInkPointPassThrough?(point, pageIndex, event) ?? false
                },
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
                // 套索不限焦點頁：在哪一頁圈就圈哪一頁，由呼叫端在 began 時把焦點切過來。
                // 以前只收焦點頁的，在別頁圈下去完全沒有反應，也不會出工具列。
                onLassoBegan: { pt in onLassoBegan?(pt) },
                onLassoMoved: { pt in onLassoMoved?(pt) },
                onLassoEnded: { onLassoEnded?() },
                canvasRef: { canvas in canvasRef(canvas) },
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
                },
                onPressAndHold: onPressAndHold,
                proReloadToken: inkReloadGeneration
            )
            .id(reloadGeneration)
            .frame(width: PageGeometry.width, height: PageGeometry.height, alignment: .topLeading)
            .allowsHitTesting(true)
            .zIndex(2)

            Group {
                if let overInk = overInkObjectLayer {
                    overInk()
                        .frame(width: PageGeometry.width, height: PageGeometry.height, alignment: .topLeading)
                        .allowsHitTesting(editorMode == .type || isObjectActive)
                        .zIndex(3)
                } else {
                    objectLayer()
                        .frame(width: PageGeometry.width, height: PageGeometry.height, alignment: .topLeading)
                        .allowsHitTesting(editorMode == .type || isObjectActive)
                        .zIndex(3)
                }
            }
            .id(objectGeneration)
            .overlay(alignment: .topLeading) {
                if selectedTool == .lasso && isFocused, let lassoDecoration {
                    lassoDecoration()
                }
            }

            MaskingTapeOverlayView(
                notebook: $notebook,
                pageIndex: pageIndex,
                isActive: isFocused && selectedTool == .maskingTape && editorMode == .draw,
                selectedColor: selectedColor,
                onTapesChanged: {
                    onNotebookChanged?()
                }
            )
            .frame(width: PageGeometry.width, height: PageGeometry.height, alignment: .topLeading)
            .allowsHitTesting((isFocused && selectedTool == .maskingTape && editorMode == .draw) || (editorMode != .draw && !(notebook.tapeAttachments?.filter { $0.pageIndex == pageIndex }.isEmpty ?? true)))
            .zIndex((isFocused && selectedTool == .maskingTape && editorMode == .draw) ? 4 : 2.5)
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
        .clipped()
        .background(
            Rectangle()
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
        )
        .overlay(
            // 焦點頁描一圈，使用者才知道現在插入的東西會落在哪一頁。
            Rectangle()
                .strokeBorder(
                    isFocused ? Color.accentColor.opacity(0.45) : Color.secondary.opacity(0.18),
                    lineWidth: isFocused ? 1.5 : 1
                )
        )
        .overlay(alignment: .bottomTrailing) {
            Text("\(pageIndex + 1)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(6)
        }
        .onAppear {
            if loaded {
                onInitialLoaded?(pageIndex, drawing)
            }
        }
        .task(id: loaded) {
            // 只載一次。每次重繪都載的話，正在寫的那一頁會被硬碟上的舊版覆蓋。
            guard !loaded else {
                onInitialLoaded?(pageIndex, drawing)
                return
            }
            drawing = initialDrawing?(pageIndex) ?? store.loadDrawing(notebookId: notebookId, pageIndex: pageIndex)
            loaded = true
            onInitialLoaded?(pageIndex, drawing)
        }
        .onChange(of: reloadGeneration) { _ in
            drawing = store.loadDrawing(notebookId: notebookId, pageIndex: pageIndex)
        }
        .onChange(of: inkReloadGeneration) { _ in
            guard loaded else { return }
            drawing = mergeReloaded?(pageIndex, drawing)
                ?? store.loadDrawing(notebookId: notebookId, pageIndex: pageIndex)
        }
    }
}


/// 連續模式用的座標空間名稱。
enum ContinuousPagesSpace {
    static let name = "kairumoContinuousPages"
}

/// 每一頁在捲動容器裡的中線 y。用來挑出焦點頁。
struct PageFocusPreferenceKey: PreferenceKey {
    // profile-scope: device PreferenceKey 的預設值常數
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}


/// 畫布觸控與導航手勢狀態互斥鎖（Apple）。
///
/// # 為什麼要有
///
/// 在手繪或打字模式、固定或連續頁面下，使用者拿 Apple Pencil 移動頁面或使用雙指移動／縮放頁面時，
/// 觸控點可能落在未鎖定的物件（文字方塊、形狀、圖片、表格等）上。
/// 若沒有全域互斥鎖，物件身上的單指拖曳手勢會搶先辨識，導致物件跟著雙指移動或縮放而移位。
/// 此鎖在雙指操作或頁面捲動期間，全面凍結所有未選取或非目標物件的拖曳手勢。
// profile-scope: device 裝置共用手勢互斥鎖
public final class CanvasTouchState {
    // profile-scope: device 畫布導航（雙指平移或縮放）進行中旗標
    public static var isCanvasNavigating: Bool = false

    // profile-scope: device 畫面上活躍的直接觸控數量
    public static var activeDirectTouches: Int = 0

    /// 是否允許物件拖曳（當導航進行中或多指同時按住時嚴格禁止拖動物件）
    public static var canDragObject: Bool {
        !isCanvasNavigating && activeDirectTouches < 2
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
        g.cancelsTouchesInView = true
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
            CanvasTouchState.isCanvasNavigating = true
            stopMomentum()
            scrollView = enclosingScrollView()
            lastTranslationY = 0
            if let canvas {
                drawingWasEnabled = canvas.drawingGestureRecognizer.isEnabled
                canvas.drawingGestureRecognizer.isEnabled = false
                (canvas as? AdaptiveCanvasView)?.cancelInFlightStrokesForNavigation()
            }
            scrollView?.panGestureRecognizer.isEnabled = false
        case .changed:
            let y = g.translation(in: nil).y
            scroll(by: -(y - lastTranslationY))
            lastTranslationY = y
        case .ended, .cancelled, .failed:
            CanvasTouchState.isCanvasNavigating = false
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

    // 與畫布自己的手勢同時辨識 —— 不然落筆手勢（含 PencilKit 與專業筆刷 ProStrokeGestureRecognizer）一開始，這個就永遠起不來。
    // 但絕不與子視圖中的物件拖曳手勢同時辨識，避免雙指捲動時拖曳到底下的未鎖定物件。
    func gestureRecognizer(
        _ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        if let canvas = canvas {
            if other === canvas.drawingGestureRecognizer || other.view === canvas {
                return true
            }
        }
        let sv = scrollView ?? enclosingScrollView()
        if let sv, other === sv.panGestureRecognizer {
            scrollView = sv
            return true
        }
        return false
    }
}
