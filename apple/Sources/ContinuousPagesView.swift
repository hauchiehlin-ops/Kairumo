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
    let template: NoteTemplate
    let store: NotebookStore

    let selectedTool: EditorToolType
    let selectedColor: Color
    let strokeWidth: CGFloat
    let isRulerActive: Bool
    let editorMode: EditorMode
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
    /// Apple Pencil 雙擊筆桿（工作項 S-67）。只有焦點頁回報 —— 每一頁都報的話，
    /// 一次雙擊會被當成好幾次，工具在筆與橡皮擦之間跳回原地。
    var onPencilTap: ((UIPencilPreferredAction) -> Void)? = nil

    @State private var drawing = PKDrawing()
    @State private var loaded = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            CanvasRepresentable(
                drawing: $drawing,
                selectedTool: selectedTool,
                selectedColor: selectedColor,
                strokeWidth: strokeWidth,
                isRulerActive: isRulerActive,
                template: template,
                pageHeight: PageGeometry.height,
                editorMode: editorMode,
                // 裡層不捲 —— 外面那個 ScrollView 才是捲動的主體。
                isScrollEnabled: false,
                onDrawingChanged: { updated in
                    store.saveDrawing(notebookId: notebookId, pageIndex: pageIndex, drawing: updated)
                    onDrawingChanged(pageIndex, updated)
                },
                onReachedPageBottom: { if isFocused { onReachedPageBottom() } },
                onSelectionChanged: { hasSelection in
                    if isFocused { onSelectionChanged(hasSelection) }
                },
                canvasRef: { canvas in if isFocused { canvasRef(canvas) } },
                palmRejection: palmRejection,
                onPencilTap: { action in if isFocused { onPencilTap?(action) } }
            )

            objectLayer()
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
