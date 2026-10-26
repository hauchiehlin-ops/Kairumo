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

    /// 選到的筆畫實際佔的範圍（含 transform）。套索只圈到一筆的五成多也算選中，
    /// 筆畫會露出圈外；拖曳命中與工具列位置要用「圈 ∪ 筆畫」才不會抓不到露出去的那段。
    @Published private(set) var strokeBounds: CGRect? = nil

    /// 剪貼簿（保留 PKStroke）。要 @Published：剪下之後選取清空，畫面要靠它決定還要不要顯示「貼上」。
    @Published private var clipboard: [PKStroke] = []
    /// 剪貼簿是剪下來的（原位貼回）還是複製的（錯開一點貼，看得出是新的一份）。
    private var clipboardFromCut = false

    /// 選取拖曳回呼
    var onDragSelection: ((CGSize) -> Void)?

    /// 專業筆畫（製圖線）的選取。PencilKit 的筆畫用索引，它們用 id。
    @Published private(set) var proIds: Set<String> = []
    @Published private var proClipboard: [ProStroke] = []
    /// 目前這一頁的專業筆畫層。
    var proHost: () -> ProInkLayerView? = { nil }

    /// 畫布物件（貼紙、圖片、形狀、文字方塊、表格等）的套索選取 ID 集合。
    @Published private(set) var objectIds: Set<String> = []
    @Published private var hasObjectClipboard: Bool = false
    var objectCandidates: () -> [(id: String, frame: CGRect)] = { [] }
    var onMoveObjects: (Set<String>, CGSize) -> Void = { _, _ in }
    var onCommitMoveObjects: (Set<String>) -> Void = { _ in }
    var onDeleteObjects: (Set<String>) -> Void = { _ in }
    var onCopyObjects: (Set<String>) -> Void = { _ in }
    var onCutObjects: (Set<String>) -> Void = { _ in }
    var onDuplicateObjects: (Set<String>) -> Set<String> = { _ in [] }
    var onPasteObjects: () -> Set<String> = { [] }

    var hasSelection: Bool { !selected.isEmpty || !proIds.isEmpty || !objectIds.isEmpty }
    var canPaste: Bool { !clipboard.isEmpty || !proClipboard.isEmpty || hasObjectClipboard }

    var boundingRect: CGRect? {
        guard let loop = committedRect else { return strokeBounds }
        guard let strokes = strokeBounds else { return loop }
        return loop.union(strokes)
    }

    private var committedRect: CGRect? {
        guard !committed.isEmpty else { return nil }
        var minX = committed[0].x, maxX = committed[0].x
        var minY = committed[0].y, maxY = committed[0].y
        for p in committed {
            minX = min(minX, p.x)
            maxX = max(maxX, p.x)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    var dragPoint: CGPoint? { dragLastPoint }

    func updateDragPoint(_ point: CGPoint) {
        dragLastPoint = point
    }

    // MARK: - 圈選生命週期

    func begin(at point: CGPoint) {
        if hasSelection && (isPointInsideCommitted(point) || boundingRect?.insetBy(dx: -16, dy: -16).contains(point) == true) {
            isDraggingSelection = true
            dragLastPoint = point
            return
        }
        isDraggingSelection = false
        dragLastPoint = nil
        path = [point]
        selected = []
        proIds = []
        objectIds = []
        committed = []
        strokeBounds = nil
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

    /// 放開手指／筆尖：封閉多邊形並透過核心幾何計算選中哪些筆畫與物件。
    func finish(in drawing: PKDrawing) {
        if isDraggingSelection {
            isDraggingSelection = false
            dragLastPoint = nil
            proHost()?.endMove()
            if !objectIds.isEmpty {
                onCommitMoveObjects(objectIds)
            }
            return
        }
        defer { path = [] }
        guard path.count >= 3 else {
            selected = []
            proIds = []
            objectIds = []
            committed = []
            strokeBounds = nil
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
        var pickedObjects = Set<String>()
        var objectFrames: [CGRect] = []
        for candidate in objectCandidates() {
            if Self.isRectEnclosed(candidate.frame, in: polyPts) {
                pickedObjects.insert(candidate.id)
                objectFrames.append(candidate.frame)
            }
        }
        objectIds = pickedObjects
        committed = (picked.isEmpty && proIds.isEmpty && pickedObjects.isEmpty) ? [] : path
        strokeBounds = Self.bounds(
            of: picked,
            in: drawing.strokes,
            pro: proHost()?.strokes(ids: proIds) ?? [],
            objectFrames: objectFrames
        )
    }

    /// 選取筆畫（含專業筆畫与畫布物件）的聯集外框。
    private static func bounds(
        of indices: IndexSet,
        in strokes: [PKStroke],
        pro: [ProStroke],
        objectFrames: [CGRect] = []
    ) -> CGRect? {
        var rect: CGRect? = nil
        for i in indices where strokes.indices.contains(i) {
            let b = strokes[i].renderBounds
            rect = rect.map { $0.union(b) } ?? b
        }
        for s in pro {
            rect = rect.map { $0.union(s.bounds) } ?? s.bounds
        }
        for f in objectFrames {
            rect = rect.map { $0.union(f) } ?? f
        }
        return rect
    }

    /// 把一批剛產生的筆畫（再製、貼上的結果）設成目前選取，並用它們的外框當選取框，
    /// 讓使用者馬上能拖走 —— 不然新的一份疊在原物件上，再圈一次會連原物件一起圈到。
    private func selectNew(
        indices: IndexSet,
        proIds newPro: Set<String>,
        objectIds newObj: Set<String> = [],
        in strokes: [PKStroke]
    ) {
        path = []
        selected = indices
        proIds = newPro
        objectIds = newObj
        let objFrames = objectCandidates().filter { newObj.contains($0.id) }.map(\.frame)
        strokeBounds = Self.bounds(
            of: indices,
            in: strokes,
            pro: proHost()?.strokes(ids: newPro) ?? [],
            objectFrames: objFrames
        )
        if let r = strokeBounds?.insetBy(dx: -8, dy: -8) {
            committed = [
                CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
                CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY),
            ]
        } else {
            committed = []
        }
    }

    /// 跨頁搬移完成後，更新套索在目標頁的選取狀態
    func finishCrossPageMove(
        newIndices: IndexSet,
        newPro: Set<String> = [],
        newObj: Set<String> = [],
        in strokes: [PKStroke]
    ) {
        selectNew(indices: newIndices, proIds: newPro, objectIds: newObj, in: strokes)
    }

    /// 判定畫布物件（貼紙、形狀、圖片、文字方塊等）外框是否被套索圈中。
    private static func isRectEnclosed(_ rect: CGRect, in polygon: [CGPoint]) -> Bool {
        guard polygon.count >= 3, rect.width > 0, rect.height > 0 else { return false }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let samplePoints = [
            center,
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.midX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.midY),
            CGPoint(x: rect.midX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.midY),
        ]
        var insideCount = 0
        for pt in samplePoints {
            if isPointInPolygon(pt, polygon: polygon) {
                insideCount += 1
            }
        }
        if insideCount >= 5 { return true }
        if isPointInPolygon(center, polygon: polygon) && insideCount >= 3 { return true }
        return false
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
        objectIds = []
        strokeBounds = bounds
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
        objectIds = []
        committed = []
        strokeBounds = nil
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
        if !objectIds.isEmpty {
            onCopyObjects(objectIds)
            hasObjectClipboard = true
        } else {
            hasObjectClipboard = false
        }
        clipboardFromCut = false
    }

    func deleteSelected(from drawing: PKDrawing) -> PKDrawing? {
        guard hasSelection else { return nil }
        if !proIds.isEmpty { proHost()?.delete(ids: proIds) }
        if !objectIds.isEmpty { onDeleteObjects(objectIds) }
        var strokes = drawing.strokes
        for index in selected.sorted(by: >) where strokes.indices.contains(index) {
            strokes.remove(at: index)
        }
        clear()
        return PKDrawing(strokes: strokes)
    }

    func cutSelected(from drawing: PKDrawing) -> PKDrawing? {
        clipboard = selected.compactMap { index in
            drawing.strokes.indices.contains(index) ? drawing.strokes[index] : nil
        }
        proClipboard = proHost()?.strokes(ids: proIds) ?? []
        let cutObjs = objectIds
        objectIds = []
        if !cutObjs.isEmpty {
            onCutObjects(cutObjs)
            hasObjectClipboard = true
        } else {
            hasObjectClipboard = false
        }
        clipboardFromCut = true
        if !proIds.isEmpty { proHost()?.delete(ids: proIds) }
        var strokes = drawing.strokes
        for index in selected.sorted(by: >) where strokes.indices.contains(index) {
            strokes.remove(at: index)
        }
        clear()
        return PKDrawing(strokes: strokes)
    }

    func duplicateSelected(in drawing: PKDrawing) -> PKDrawing? {
        guard hasSelection else { return nil }
        let copies = selected.compactMap { index -> PKStroke? in
            guard drawing.strokes.indices.contains(index) else { return nil }
            return Self.offset(drawing.strokes[index], by: Self.duplicateOffset)
        }
        var newPro: Set<String> = []
        if !proIds.isEmpty, let host = proHost() {
            newPro = host.add(copies: host.strokes(ids: proIds), offset: Self.duplicateOffset)
        }
        var newObj: Set<String> = []
        if !objectIds.isEmpty {
            newObj = onDuplicateObjects(objectIds)
        }
        guard !copies.isEmpty || !newPro.isEmpty || !newObj.isEmpty else { return nil }
        let strokes = drawing.strokes + copies
        // 再製出來的那一份是新的獨立物件，直接選著它（不是清掉選取、讓它疊在原物件上）。
        selectNew(
            indices: IndexSet(drawing.strokes.count..<strokes.count),
            proIds: newPro,
            objectIds: newObj,
            in: strokes
        )
        return PKDrawing(strokes: strokes)
    }

    func paste(into drawing: PKDrawing) -> PKDrawing? {
        guard canPaste else { return nil }
        // 剪下的原位貼回；複製的錯開一點，看得出是新的一份。
        let offset = clipboardFromCut ? .zero : Self.duplicateOffset
        var newPro: Set<String> = []
        if !proClipboard.isEmpty, let host = proHost() {
            newPro = host.add(copies: proClipboard, offset: offset)
        }
        var newObj: Set<String> = []
        if hasObjectClipboard {
            newObj = onPasteObjects()
        }
        let pasted = clipboard.map { Self.offset($0, by: offset) }
        let strokes = drawing.strokes + pasted
        // 貼上之後選著貼上的那一份，馬上能拖到想放的位置。
        selectNew(
            indices: IndexSet(drawing.strokes.count..<strokes.count),
            proIds: newPro,
            objectIds: newObj,
            in: strokes
        )
        // 同一份再貼一次就不要再疊在同一個位置。
        clipboardFromCut = false
        return PKDrawing(strokes: strokes)
    }

    func moveSelected(in drawing: PKDrawing, by delta: CGSize) -> PKDrawing? {
        guard hasSelection else { return nil }
        guard abs(delta.width) > 0.01 || abs(delta.height) > 0.01 else { return nil }
        var strokes = drawing.strokes
        for index in selected where strokes.indices.contains(index) {
            strokes[index] = Self.offset(strokes[index], by: delta)
        }
        if !proIds.isEmpty { proHost()?.move(ids: proIds, by: delta) }
        if !objectIds.isEmpty { onMoveObjects(objectIds, delta) }
        committed = committed.map { CGPoint(x: $0.x + delta.width, y: $0.y + delta.height) }
        strokeBounds = strokeBounds?.offsetBy(dx: delta.width, dy: delta.height)
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

    /// 選到的專業筆畫（炭筆、蠟筆、書法筆…）。它們不在 `PKDrawing` 裡，
    /// 辨識手寫只看 `extractSelectedStrokes` 的話，用這幾支筆寫的字會被當成「什麼都沒選」。
    func extractSelectedProStrokes() -> [ProStroke] {
        guard !proIds.isEmpty else { return [] }
        return proHost()?.strokes(ids: proIds) ?? []
    }

    private static let duplicateOffset = CGSize(width: 24, height: 24)

    /// 位移一筆。**要建一筆新的 `PKStroke`**，不能在原本那筆上改 `transform`：
    /// PencilKit 以筆畫身分比對哪些區塊要重畫，同一身分只改 transform 時，畫布只重畫
    /// 一部分區塊（甚至不重畫）—— 選取框跟著手指走，畫面上的筆跡卻留在原地或斷成幾截，
    /// 而資料（縮圖）其實已經移過去了。
    static func offset(_ stroke: PKStroke, by delta: CGSize) -> PKStroke {
        let t = stroke.transform.concatenating(
            CGAffineTransform(translationX: delta.width, y: delta.height))
        let controlPoints = stroke.path.map { pt in
            PKStrokePoint(
                location: pt.location.applying(t),
                timeOffset: pt.timeOffset,
                size: pt.size,
                opacity: pt.opacity,
                force: pt.force,
                azimuth: pt.azimuth,
                altitude: pt.altitude
            )
        }
        let newPath = PKStrokePath(controlPoints: controlPoints, creationDate: stroke.path.creationDate)
        var newMask: UIBezierPath? = nil
        if let mask = stroke.mask?.copy() as? UIBezierPath {
            mask.apply(t)
            newMask = mask
        }
        return PKStroke(ink: stroke.ink, path: newPath, transform: .identity, mask: newMask)
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
