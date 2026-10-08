//
//  LassoSelection.swift
//  Kairumo
//
//  套索選取狀態機與幾何判定（Apple 端）。
//
//  # 為什麼不用 PKLassoTool 的私有介面
//
//  PencilKit 的 PKLassoTool 未向開發者開放公開的選取筆劃查詢與程式化剪下/複製 API。
//  依賴私有 _hasSelection 與向 PKTiledView 發送 UIResponderStandardEditActions 在
//  SwiftUI 按鈕點擊（失去 first responder）與不同系統版本/Catalyst 下會全面失效。
//  此處收回自行管理選取狀態、核心幾何判定（lassoEncloses）與 PKDrawing.strokes 的公開變更，
//  確保跨平台規則完全一致、按鈕端口 100% 正常作用。
//

import PencilKit
import SwiftUI

#if canImport(PadnoteCore)
import PadnoteCore
#endif

/// 套索的狀態機。
@MainActor
final class LassoSelection: ObservableObject {

    /// 使用者正在畫的那一圈（畫布座標）。空的表示沒有在圈。
    @Published private(set) var path: [CGPoint] = []
    /// 圈完之後選到的筆畫在 `PKDrawing.strokes` 裡的索引。
    @Published private(set) var selected: IndexSet = []
    /// 選好之後那一圈仍然畫在畫面上，讓使用者看得到選取範圍。
    @Published private(set) var committed: [CGPoint] = []

    /// 拖曳選取狀態
    @Published private(set) var isDraggingSelection: Bool = false
    private var dragLastPoint: CGPoint? = nil

    /// 剪貼簿（保留 PKStroke）。
    private var clipboard: [PKStroke] = []

    /// 選取拖曳回呼
    var onDragSelection: ((CGSize) -> Void)?

    /// 專業筆畫（製圖線）的選取。PencilKit 的筆畫用索引，它們用 id。
    @Published private(set) var proIds: Set<String> = []
    private var proClipboard: [ProStroke] = []
    /// 目前這一頁的專業筆畫層。
    var proHost: () -> ProInkLayerView? = { nil }

    var hasSelection: Bool { !selected.isEmpty || !proIds.isEmpty }
    var canPaste: Bool { !clipboard.isEmpty || !proClipboard.isEmpty }

    // MARK: - 圈選生命週期

    func begin(at point: CGPoint) {
        if hasSelection && isPointInsideCommitted(point) {
            isDraggingSelection = true
            dragLastPoint = point
            return
        }
        isDraggingSelection = false
        dragLastPoint = nil
        path = [point]
        selected = []
        proIds = []
        committed = []
    }

    func extend(to point: CGPoint) {
        if isDraggingSelection {
            guard let last = dragLastPoint else { return }
            let delta = CGSize(width: point.x - last.x, height: point.y - last.y)
            dragLastPoint = point
            onDragSelection?(delta)
            return
        }
        // 太近的點不收：避免抖動過密
        if let last = path.last,
           abs(last.x - point.x) < 2, abs(last.y - point.y) < 2 {
            return
        }
        path.append(point)
    }

    /// 放開手指／筆尖：封閉多邊形並透過核心幾何計算選中哪些筆畫。
    func finish(in drawing: PKDrawing) {
        if isDraggingSelection {
            isDraggingSelection = false
            dragLastPoint = nil
            proHost()?.endMove()
            return
        }
        defer { path = [] }
        guard path.count >= 3 else {
            selected = []
            proIds = []
            committed = []
            return
        }
        let polygon = path.flatMap { [Float($0.x), Float($0.y)] }
        let polyPts = path
        var picked = IndexSet()
        for (index, stroke) in drawing.strokes.enumerated() {
            let points = Self.samplePoints(of: stroke)
            if lassoEncloses(polygon: polygon, points: points) {
                picked.insert(index)
            } else if Self.isStrokeEnclosedTolerant(stroke: stroke, in: polyPts) {
                picked.insert(index)
            }
        }
        selected = picked
        proIds = proHost()?.strokeIds(enclosedBy: polygon) ?? []
        committed = (picked.isEmpty && proIds.isEmpty) ? [] : path
    }

    /// 寬容度判定：當一般筆畫取樣點較多時，只要超過 55% 取樣點在套索圈內，或中心點在圈內且至少 35% 點在圈內，即視為選中。
    private static func isStrokeEnclosedTolerant(stroke: PKStroke, in polygon: [CGPoint]) -> Bool {
        guard polygon.count >= 3 else { return false }
        let totalCount = stroke.path.count
        guard totalCount > 0 else { return false }
        let step = max(1, totalCount / 30)
        var insideCount = 0
        var sampledCount = 0
        for i in stride(from: 0, to: totalCount, by: step) {
            let pt = stroke.path[i].location.applying(stroke.transform)
            sampledCount += 1
            if isPointInPolygon(pt, polygon: polygon) {
                insideCount += 1
            }
        }
        guard sampledCount > 0 else { return false }
        let ratio = Double(insideCount) / Double(sampledCount)
        if ratio >= 0.55 { return true }
        let bounds = stroke.renderBounds
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        if isPointInPolygon(center, polygon: polygon) && ratio >= 0.35 {
            return true
        }
        return false
    }

    private static func isPointInPolygon(_ p: CGPoint, polygon: [CGPoint]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let pi = polygon[i]
            let pj = polygon[j]
            if ((pi.y > p.y) != (pj.y > p.y)) &&
               (p.x < (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y) + pi.x) {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    /// 程式直接選定一批專業筆畫（例如剛插入的立體圖紙），並畫出選取框，
    /// 讓使用者馬上能拖著搬到想放的位置。
    func select(proStrokeIds ids: Set<String>, around bounds: CGRect) {
        guard !ids.isEmpty else { return }
        path = []
        selected = []
        proIds = ids
        let r = bounds.insetBy(dx: -8, dy: -8)
        committed = [
            CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
            CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY),
        ]
    }

    func clear() {
        path = []
        selected = []
        proIds = []
        committed = []
        isDraggingSelection = false
        dragLastPoint = nil
    }

    /// 一條筆畫的取樣點，套用 transform。
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

    /// 射線法判定點是否落在圈選多邊形內部
    private func isPointInsideCommitted(_ p: CGPoint) -> Bool {
        guard committed.count >= 3 else { return false }
        var inside = false
        var j = committed.count - 1
        for i in 0..<committed.count {
            let pi = committed[i]
            let pj = committed[j]
            if ((pi.y > p.y) != (pj.y > p.y)) &&
               (p.x < (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y) + pi.x) {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    // MARK: - 動作作用端口

    func copySelected(from drawing: PKDrawing) {
        clipboard = selected.compactMap { index in
            drawing.strokes.indices.contains(index) ? drawing.strokes[index] : nil
        }
        proClipboard = proHost()?.strokes(ids: proIds) ?? []
    }

    func deleteSelected(from drawing: PKDrawing) -> PKDrawing? {
        guard hasSelection else { return nil }
        if !proIds.isEmpty { proHost()?.delete(ids: proIds) }
        var strokes = drawing.strokes
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

    func duplicateSelected(in drawing: PKDrawing) -> PKDrawing? {
        guard hasSelection else { return nil }
        let copies = selected.compactMap { index -> PKStroke? in
            guard drawing.strokes.indices.contains(index) else { return nil }
            return Self.offset(drawing.strokes[index], by: Self.duplicateOffset)
        }
        if !proIds.isEmpty, let host = proHost() {
            host.add(copies: host.strokes(ids: proIds), offset: Self.duplicateOffset)
        }
        guard !copies.isEmpty || !proIds.isEmpty else { return nil }
        clear()
        return PKDrawing(strokes: drawing.strokes + copies)
    }

    func paste(into drawing: PKDrawing) -> PKDrawing? {
        guard canPaste else { return nil }
        if !proClipboard.isEmpty { proHost()?.add(copies: proClipboard, offset: Self.duplicateOffset) }
        let pasted = clipboard.map { Self.offset($0, by: Self.duplicateOffset) }
        clear()
        return PKDrawing(strokes: drawing.strokes + pasted)
    }

    func moveSelected(in drawing: PKDrawing, by delta: CGSize) -> PKDrawing? {
        guard hasSelection else { return nil }
        var strokes = drawing.strokes
        for index in selected where strokes.indices.contains(index) {
            strokes[index] = Self.offset(strokes[index], by: delta)
        }
        if !proIds.isEmpty { proHost()?.move(ids: proIds, by: delta) }
        committed = committed.map { CGPoint(x: $0.x + delta.width, y: $0.y + delta.height) }
        return PKDrawing(strokes: strokes)
    }

    func recolorSelected(in drawing: PKDrawing, to newColor: UIColor) -> PKDrawing? {
        guard hasSelection else { return nil }
        var strokes = drawing.strokes
        for idx in selected where strokes.indices.contains(idx) {
            let oldStroke = strokes[idx]
            let newInk = PKInk(oldStroke.ink.inkType, color: newColor)
            strokes[idx] = PKStroke(ink: newInk, path: oldStroke.path, transform: oldStroke.transform, mask: oldStroke.mask)
        }
        return PKDrawing(strokes: strokes)
    }

    func extractSelectedStrokes(from drawing: PKDrawing) -> [PKStroke] {
        return selected.compactMap { idx in
            drawing.strokes.indices.contains(idx) ? drawing.strokes[idx] : nil
        }
    }

    private static let duplicateOffset = CGSize(width: 24, height: 24)

    private static func offset(_ stroke: PKStroke, by delta: CGSize) -> PKStroke {
        var moved = stroke
        moved.transform = stroke.transform.concatenating(
            CGAffineTransform(translationX: delta.width, y: delta.height))
        return moved
    }
}

/// 圈選中與圈選後的那一圈虛線疊層。
struct LassoPathOverlay: View {
    let path: [CGPoint]
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
            Color.accentColor.opacity(isCommitted ? 0.75 : 0.95),
            style: StrokeStyle(
                lineWidth: 1.8,
                lineCap: .round,
                lineJoin: .round,
                dash: [7, 5]
            )
        )
        .allowsHitTesting(false)
    }
}
