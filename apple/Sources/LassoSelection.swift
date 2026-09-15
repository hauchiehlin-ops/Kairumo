//
//  LassoSelection.swift
//  Kairumo
//
//  自己做的套索選取（Apple）。
//
//  # 為什麼不用 PKLassoTool
//
//  原本是這樣做的，而且**整組功能是壞的** —— 剪下／複製／再製／貼上／刪除
//  五顆按鈕在 Mac 上全部沒有反應。原因有三個，而且同時發生：
//
//  1. 判斷「有沒有選取」靠的是 PencilKit 的**私有選擇器** `_hasSelection`，
//     用 `unsafeBitCast` 硬轉函式指標去呼叫。那是私有 API：審核有風險，
//     而且換一版系統就可能靜靜失效。
//  2. 五個動作是把 `UIResponderStandardEditActions`（cut/copy/paste…）
//     送給名稱裡含 `PKTiledView` 的私有子視圖。送給一個不是 first responder
//     的視圖，那些 action 根本不會被執行。
//  3. Mac Catalyst 的 responder chain 與 PencilKit 的套索實作都與 iOS 不同。
//
//  `PKLassoTool` 的選取狀態沒有公開介面，所以只要選取交給它，就只剩私有 API
//  這條路。這裡把套索收回來自己做：手勢自己收、多邊形自己算、
//  `PKDrawing.strokes` 自己改 —— 全部是公開 API。
//
//  # 判定規則來自核心
//
//  「圈到算不算選到」走核心的 `lassoEncloses`，與 Android 同一段程式碼。
//  各寫一份的話，兩邊遲早會在邊界條件上分岔 —— 而那種差異使用者會描述成
//  「同一個圈選在 iPad 上選得到、在 Android 上選不到」。
//
//  Android 的筆畫寫在核心裡，所以那邊直接用 `lassoSelect`；Apple 編輯中的
//  真相來源是 `PKDrawing`，所以拿點來問。資料來源不同，規則同一條。
//

import PencilKit
import SwiftUI

/// 套索的狀態機。
///
/// 只有兩種狀態：正在圈、或圈好了。沒有「圈到一半但手放開了」——
/// 放開就是圈好。
@MainActor
final class LassoSelection: ObservableObject {

    /// 使用者正在畫的那一圈（畫布座標）。空的表示沒有在圈。
    @Published private(set) var path: [CGPoint] = []
    /// 圈完之後選到的筆畫在 `PKDrawing.strokes` 裡的索引。
    @Published private(set) var selected: IndexSet = []
    /// 選好之後那一圈仍然畫在畫面上，讓使用者看得到選取範圍。
    @Published private(set) var committed: [CGPoint] = []

    /// 剪貼簿。**不用系統剪貼簿**：`PKStroke` 沒有標準的貼上格式，
    /// 而且跨 App 貼過去對方也讀不懂。放在這裡至少「複製→貼上」是會動的。
    private var clipboard: [PKStroke] = []

    var hasSelection: Bool { !selected.isEmpty }
    var canPaste: Bool { !clipboard.isEmpty }

    // MARK: - 圈選

    func begin(at point: CGPoint) {
        path = [point]
        selected = []
        committed = []
    }

    func extend(to point: CGPoint) {
        // 太近的點不收：手指抖動會塞進上千個幾乎重合的點，
        // 而點在不在多邊形裡是 O(頂點數)，那會讓每次判定都變慢。
        if let last = path.last,
           abs(last.x - point.x) < 2, abs(last.y - point.y) < 2 {
            return
        }
        path.append(point)
    }

    /// 放開手指：把圈closed起來，算出選到哪幾筆。
    func finish(in drawing: PKDrawing) {
        defer { path = [] }
        guard path.count >= 3 else {
            // 點一下就放開，不是圈選。清掉，不要留一個看不見的選取狀態。
            selected = []
            committed = []
            return
        }
        let polygon = path.flatMap { [Float($0.x), Float($0.y)] }
        var picked = IndexSet()
        for (index, stroke) in drawing.strokes.enumerated() {
            let points = Self.samplePoints(of: stroke)
            if lassoEncloses(polygon: polygon, points: points) {
                picked.insert(index)
            }
        }
        selected = picked
        // 沒選到東西就不要留著那一圈 —— 畫面上掛著一個空的虛線框，
        // 使用者會以為選取還在。
        committed = picked.isEmpty ? [] : path
    }

    func clear() {
        path = []
        selected = []
        committed = []
    }

    /// 一條筆畫的取樣點，攤平成 `[x0, y0, x1, y1, …]`。
    ///
    /// 用 `stroke.path` 的控制點而不是算繪後的曲線：控制點就足以代表這一筆
    /// 的走向，而算繪一次要展開成上千個點，圈選一次要對整頁做。
    ///
    /// **要套用 `stroke.transform`。** PencilKit 搬移過的筆畫，它的路徑點
    /// 仍然是原本的座標，位移記在 transform 裡 —— 不套的話，被搬過的筆畫
    /// 會用它「本來的位置」去比對，使用者圈了眼前看到的東西卻選不到。
    private static func samplePoints(of stroke: PKStroke) -> [Float] {
        var out: [Float] = []
        out.reserveCapacity(stroke.path.count * 2)
        for point in stroke.path {
            let p = point.location.applying(stroke.transform)
            out.append(Float(p.x))
            out.append(Float(p.y))
        }
        return out
    }

    // MARK: - 動作
    //
    // 五個動作全部只改 `PKDrawing.strokes`，那是公開 API。
    // 回傳新的 drawing，由呼叫端決定什麼時候寫回去與存檔。

    func copySelected(from drawing: PKDrawing) {
        clipboard = selected.compactMap { index in
            drawing.strokes.indices.contains(index) ? drawing.strokes[index] : nil
        }
    }

    /// 刪除選取。回傳新的 drawing；沒有選取時回 nil（呼叫端就不必存檔）。
    func deleteSelected(from drawing: PKDrawing) -> PKDrawing? {
        guard hasSelection else { return nil }
        var strokes = drawing.strokes
        // **由後往前刪。** 由前往後的話，刪掉第 2 筆之後第 5 筆就變成第 4 筆，
        // 後面每一個索引都錯位，結果是刪掉一堆使用者沒選的東西。
        for index in selected.sorted(by: >) where strokes.indices.contains(index) {
            strokes.remove(at: index)
        }
        clear()
        return PKDrawing(strokes: strokes)
    }

    func cutSelected(from drawing: PKDrawing) -> PKDrawing? {
        copySelected(from: drawing)
        return deleteSelected(from: drawing)
    }

    /// 就地複製一份並稍微偏移。
    ///
    /// 這就是「再製」與「複製」的差別：複製把東西放進剪貼簿等你貼上，
    /// 再製直接在旁邊多一份。不偏移的話新的那一份完全蓋在原本上面，
    /// 看起來什麼也沒發生。
    func duplicateSelected(in drawing: PKDrawing) -> PKDrawing? {
        guard hasSelection else { return nil }
        let copies = selected.compactMap { index -> PKStroke? in
            guard drawing.strokes.indices.contains(index) else { return nil }
            return Self.offset(drawing.strokes[index], by: Self.duplicateOffset)
        }
        guard !copies.isEmpty else { return nil }
        clear()
        return PKDrawing(strokes: drawing.strokes + copies)
    }

    /// 貼上剪貼簿裡的筆畫。
    ///
    /// 為什麼要有自己的貼上：PencilKit 的內建選單只在**有選取時**才出現，
    /// 複製完取消選取之後就沒有入口可以貼上了。
    func paste(into drawing: PKDrawing) -> PKDrawing? {
        guard canPaste else { return nil }
        let pasted = clipboard.map { Self.offset($0, by: Self.duplicateOffset) }
        clear()
        return PKDrawing(strokes: drawing.strokes + pasted)
    }

    /// 把選取整體搬移。拖曳選取範圍時用。
    func moveSelected(in drawing: PKDrawing, by delta: CGSize) -> PKDrawing? {
        guard hasSelection else { return nil }
        var strokes = drawing.strokes
        for index in selected where strokes.indices.contains(index) {
            strokes[index] = Self.offset(strokes[index], by: delta)
        }
        // 選取跟著一起走：搬完之後那一圈也要移到新位置，否則虛線框留在
        // 原地，使用者會以為自己把東西搬出選取範圍了。
        committed = committed.map { CGPoint(x: $0.x + delta.width, y: $0.y + delta.height) }
        return PKDrawing(strokes: strokes)
    }

    /// 再製與貼上的偏移量。夠大到看得出是兩份，夠小到還在視野裡。
    private static let duplicateOffset = CGSize(width: 24, height: 24)

    /// 平移一筆。
    ///
    /// 改的是 `transform` 而不是逐點重算：`PKStrokePath` 的點含壓感、
    /// 傾角與時間，重建一次要把每一個欄位抄過去，抄漏一個就是筆跡變樣。
    private static func offset(_ stroke: PKStroke, by delta: CGSize) -> PKStroke {
        var moved = stroke
        moved.transform = stroke.transform.concatenating(
            CGAffineTransform(translationX: delta.width, y: delta.height))
        return moved
    }
}

/// 圈選中與圈選後的那一圈虛線。
///
/// 畫在畫布**上面**，不進 `PKDrawing` —— 進去的話它會被存檔、被匯出、
/// 被同步到另一台裝置，而它只是一個暫時的選取提示。
struct LassoPathOverlay: View {
    let path: [CGPoint]
    /// 圈完之後的樣子（實線改虛線、顏色淡一點）。
    let isCommitted: Bool

    var body: some View {
        Path { shape in
            guard let first = path.first else { return }
            shape.move(to: first)
            for point in path.dropFirst() {
                shape.addLine(to: point)
            }
            if isCommitted {
                shape.closeSubpath()
            }
        }
        .stroke(
            Color.accentColor.opacity(isCommitted ? 0.7 : 0.9),
            style: StrokeStyle(
                lineWidth: 1.5,
                lineCap: .round,
                lineJoin: .round,
                dash: [6, 4]
            )
        )
        .allowsHitTesting(false)
    }
}
