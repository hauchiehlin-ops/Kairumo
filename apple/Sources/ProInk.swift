//
//  ProInk.swift
//  Kairumo
//
//  專業筆刷（針筆、炭筆、蠟筆、噴槍、油畫筆、書法扁頭筆）的 Apple 端：資料、儲存、算繪、輸入。
//
//  # 為什麼不用 PencilKit
//
//  PencilKit 只有固定的幾種墨水，畫不出炭筆的顆粒、蠟筆的紙紋、噴槍的柔邊或油畫筆的鬃毛。
//  這幾支筆改由核心展開成「筆點陣」（`brushDabs`，見 `padnote-ink/src/brush.rs`），
//  這裡只負責把橢圓畫出來 —— Android 畫的是同一份筆點陣，所以同一筆在兩台裝置上長得一樣。
//
//  # 它怎麼與 PencilKit 並存
//
//  - 選了專業筆刷：PencilKit 的落筆手勢暫時關掉，改由 `ProStrokeGestureRecognizer` 收筆。
//  - 選了橡皮擦：兩邊同時收，PencilKit 擦它的、這裡擦專業筆畫（整筆擦除）。
//  - 復原／重做：登記進畫布**同一個** `UndoManager`，跟 PencilKit 的筆畫交錯得起來，
//    編輯器所有復原按鈕不必改。
//  - 儲存：每頁一個 JSON（與 `.drawing` 同一個資料夾）。別台裝置的筆畫另存一份，
//    匯出只寫自己的（見 `ProInkStore`），與 PencilKit 筆畫「扣掉別人的」是同一個道理。

import CoreGraphics
import Foundation
import UIKit

// MARK: - 資料

struct ProPoint: Codable, Hashable, Sendable {
    var x: Float
    var y: Float
    var pressure: Float
    var tilt: Float
    var azimuth: Float
    var dtUs: UInt32
    var roll: Float = 0
}

struct ProStroke: Codable, Identifiable, Hashable, Sendable {
    var id: String = UUID().uuidString
    /// `ProInk.name(of:)` 的結果，例如 `"charcoal"`。存字串而不是數字：新增筆刷時不會錯位。
    var tool: String
    var colorRGBA: [UInt8]
    var baseWidth: Float
    /// 混合模式：normal / multiply / screen
    var blendMode: String = "normal"
    var points: [ProPoint]

    /// 內容指紋：同步時分辨「這是不是同一筆」。
    ///
    /// 核心每次匯出都會替筆畫重新發 id，所以不能靠 id 認；位置取到 0.1 個頁面單位，
    /// 夠細到分得開兩筆不同的線，又粗到經過核心格式的量化之後仍然一致。
    var contentKey: String {
        guard let first = points.first, let last = points.last else { return "\(tool)|empty" }
        func q(_ v: Float) -> Int { Int((v * 10).rounded()) }
        return "\(tool)|\(colorRGBA.map(String.init).joined(separator: ","))|\(points.count)|\(q(first.x)),\(q(first.y))|\(q(last.x)),\(q(last.y))"
    }

    var bounds: CGRect {
        guard let first = points.first else { return .null }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in points {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        // 外擴一個筆寬（噴槍與油畫筆的筆點比基準寬度大）。
        let pad = CGFloat(baseWidth) * 1.6 + 2
        return CGRect(x: CGFloat(minX), y: CGFloat(minY),
                      width: CGFloat(maxX - minX), height: CGFloat(maxY - minY))
            .insetBy(dx: -pad, dy: -pad)
    }
}

extension ProStroke {
    /// 從核心的筆畫還原。不是自繪引擎筆刷的回 `nil`。
    init?(from full: FullStroke) {
        guard let name = ProInk.name(of: full.tool) else { return nil }
        self.init(
            tool: name,
            colorRGBA: Array(full.colorRgba),
            baseWidth: full.baseWidth,
            points: full.points.map {
                ProPoint(x: $0.x, y: $0.y, pressure: $0.pressure, tilt: $0.tilt,
                         azimuth: $0.azimuth, dtUs: $0.dtUs, roll: $0.roll)
            })
    }
}

extension Notification.Name {
    /// 同步把別台裝置的專業筆畫寫進了磁碟。畫著那一頁的層要重讀。
    /// `userInfo["notebookId"]` 是筆記本 id。
    static let kairumoProInkChangedOnDisk = Notification.Name("kairumo.proink.changedOnDisk")
}

enum ProInk {
    static func kind(named name: String) -> ToolKind? {
        switch name {
        case "fineliner": return .fineliner
        case "charcoal": return .charcoal
        case "crayon": return .crayon
        case "airbrush": return .airbrush
        case "oilpaint": return .oilPaint
        case "calligraphy": return .calligraphy
        default: return nil
        }
    }

    static func name(of kind: ToolKind) -> String? {
        switch kind {
        case .fineliner: return "fineliner"
        case .charcoal: return "charcoal"
        case .crayon: return "crayon"
        case .airbrush: return "airbrush"
        case .oilPaint: return "oilpaint"
        case .calligraphy: return "calligraphy"
        default: return nil
        }
    }

    static func strokePoints(_ points: [ProPoint]) -> [StrokePoint] {
        points.map {
            StrokePoint(x: $0.x, y: $0.y, pressure: $0.pressure, tilt: $0.tilt,
                        azimuth: $0.azimuth, dtUs: $0.dtUs, roll: $0.roll)
        }
    }
}

// MARK: - 儲存

/// 每頁兩個檔案：自己的筆畫，與同步下載下來的別台裝置的筆畫。
///
/// 分開存的原因與 PencilKit 筆畫的 baseline 相同：匯出只能寫**自己的**，
/// 把別人的複製一份掛在自己名下，下一輪合併就會看到兩份。
enum ProInkStore {
    private nonisolated static func url(_ directory: URL, _ notebookId: String, _ page: Int, foreign: Bool) -> URL {
        directory.appending(path: "\(notebookId)_p\(page).\(foreign ? "proink-foreign" : "proink").json")
    }

    nonisolated static func load(in directory: URL, notebookId: String, page: Int, foreign: Bool = false) -> [ProStroke] {
        guard let data = try? Data(contentsOf: url(directory, notebookId, page, foreign: foreign)),
              let strokes = try? JSONDecoder().decode([ProStroke].self, from: data)
        else { return [] }
        return strokes
    }

    nonisolated static func save(_ strokes: [ProStroke], in directory: URL, notebookId: String, page: Int, foreign: Bool = false) {
        let file = url(directory, notebookId, page, foreign: foreign)
        if strokes.isEmpty {
            try? FileManager.default.removeItem(at: file)
            return
        }
        guard let data = try? JSONEncoder().encode(strokes) else { return }
        try? data.write(to: file, options: .atomic)
    }

    /// 檔案時間，同步用來判斷「工作副本是不是比套件新」。
    nonisolated static func modified(in directory: URL, notebookId: String, page: Int) -> Date? {
        let values = try? url(directory, notebookId, page, foreign: false)
            .resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate
    }
}

// MARK: - 算繪

enum ProInkRenderer {
    /// 一筆畫的筆點陣（已算好）。
    struct Cached {
        let dabs: [FfiDab]
        let bounds: CGRect
    }

    static func cache(for stroke: ProStroke) -> Cached? {
        guard let kind = ProInk.kind(named: stroke.tool) else { return nil }
        let dabs = brushDabs(tool: kind, baseWidth: stroke.baseWidth, points: ProInk.strokePoints(stroke.points))
        return Cached(dabs: dabs, bounds: stroke.bounds)
    }

    /// 把一筆畫的筆點畫進 `ctx`，只畫碰得到 `clip` 的那些。
    static func draw(_ cached: Cached, color rgba: [UInt8], in ctx: CGContext, clip: CGRect) {
        guard rgba.count == 4 else { return }
        let base = (r: CGFloat(rgba[0]) / 255, g: CGFloat(rgba[1]) / 255, b: CGFloat(rgba[2]) / 255)
        let strokeAlpha = CGFloat(rgba[3]) / 255
        for dab in cached.dabs {
            let rx = CGFloat(dab.rx), ry = CGFloat(dab.ry)
            let reach = max(rx, ry)
            guard CGFloat(dab.x) + reach >= clip.minX, CGFloat(dab.x) - reach <= clip.maxX,
                  CGFloat(dab.y) + reach >= clip.minY, CGFloat(dab.y) - reach <= clip.maxY
            else { continue }

            // 明暗：向白或向黑偏最多 35%。
            let s = CGFloat(dab.shade)
            let target: CGFloat = s >= 0 ? 1 : 0
            let k = abs(s) * 0.35
            let r = base.r + (target - base.r) * k
            let g = base.g + (target - base.g) * k
            let b = base.b + (target - base.b) * k
            let alpha = CGFloat(dab.alpha) * strokeAlpha

            ctx.saveGState()
            ctx.translateBy(x: CGFloat(dab.x), y: CGFloat(dab.y))
            ctx.rotate(by: CGFloat(dab.angle))
            if dab.softness > 0.3 {
                // Stamp 筆刷紋理引擎：高斯漸層柔邊印章（Gaussian Stamp）
                let colors = [
                    UIColor(red: r, green: g, blue: b, alpha: alpha).cgColor,
                    UIColor(red: r, green: g, blue: b, alpha: alpha * 0.55).cgColor,
                    UIColor(red: r, green: g, blue: b, alpha: 0.0).cgColor,
                ] as CFArray
                let locations: [CGFloat] = [0.0, 0.45, 1.0]
                if let space = CGColorSpace(name: CGColorSpace.sRGB),
                   let gradient = CGGradient(colorsSpace: space, colors: colors, locations: locations) {
                    ctx.scaleBy(x: 1.0, y: ry / max(rx, 0.001))
                    ctx.drawRadialGradient(
                        gradient,
                        startCenter: .zero,
                        startRadius: 0,
                        endCenter: .zero,
                        endRadius: rx,
                        options: .drawsAfterEndLocation
                    )
                } else {
                    ctx.setFillColor(red: r, green: g, blue: b, alpha: alpha)
                    ctx.fillEllipse(in: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
                }
            } else {
                ctx.setFillColor(red: r, green: g, blue: b, alpha: alpha)
                ctx.fillEllipse(in: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
            }
            ctx.restoreGState()
        }
    }
}

// MARK: - 畫布上的一層

/// 疊在 `PKCanvasView` 上的專業筆畫層。
///
/// 座標系與 PencilKit 的筆畫相同（頁面座標）。縮放由 `AdaptiveCanvasView` 設 `transform`，
/// 所以這裡一律用自己的座標，不必管目前縮放幾倍。
final class ProInkLayerView: UIView {
    /// 這一頁的識別。換頁時由外面重設並重新載入。
    private(set) var notebookId = ""
    private(set) var pageIndex = 0
    private var directory: URL?

    private(set) var ownStrokes: [ProStroke] = []
    private var foreignStrokes: [ProStroke] = []
    private var cache: [String: ProInkRenderer.Cached] = [:]

    /// 正在畫的那一筆。
    private var live: ProStroke?
    private var liveCache: ProInkRenderer.Cached?

    /// 畫完一筆、擦掉、復原時通知外面（存檔之外的事，例如更新「有未同步的修改」）。
    var onChanged: (() -> Void)?
    var undoManagerProvider: (() -> UndoManager?)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        layer.drawsAsynchronously = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(diskChanged(_:)),
            name: .kairumoProInkChangedOnDisk, object: nil)
    }

    @objc private func diskChanged(_ note: Notification) {
        guard let id = note.userInfo?["notebookId"] as? String,
              id.caseInsensitiveCompare(notebookId) == .orderedSame else { return }
        reload()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    var allStrokes: [ProStroke] { foreignStrokes + ownStrokes }

    // MARK: 載入與儲存

    func load(directory: URL, notebookId: String, pageIndex: Int) {
        guard self.directory != directory || self.notebookId != notebookId || self.pageIndex != pageIndex else { return }
        self.directory = directory
        self.notebookId = notebookId
        self.pageIndex = pageIndex
        reload()
    }

    /// 從磁碟重讀（換頁、同步匯入、清除頁面之後）。
    func reload() {
        guard let directory else { return }
        ownStrokes = ProInkStore.load(in: directory, notebookId: notebookId, page: pageIndex)
        foreignStrokes = ProInkStore.load(in: directory, notebookId: notebookId, page: pageIndex, foreign: true)
        cache.removeAll()
        setNeedsDisplay()
    }

    private func persist() {
        guard let directory else { return }
        ProInkStore.save(ownStrokes, in: directory, notebookId: notebookId, page: pageIndex)
        onChanged?()
    }

    // MARK: 繪製

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        for stroke in allStrokes where stroke.bounds.intersects(rect) {
            guard let cached = cachedDabs(for: stroke) else { continue }
            ctx.saveGState()
            if stroke.blendMode == "multiply" {
                ctx.setBlendMode(.multiply)
            } else if stroke.blendMode == "screen" {
                ctx.setBlendMode(.screen)
            } else {
                ctx.setBlendMode(.normal)
            }
            ProInkRenderer.draw(cached, color: stroke.colorRGBA, in: ctx, clip: rect)
            ctx.restoreGState()
        }
        if let live, let liveCache {
            ctx.saveGState()
            if live.blendMode == "multiply" {
                ctx.setBlendMode(.multiply)
            } else if live.blendMode == "screen" {
                ctx.setBlendMode(.screen)
            } else {
                ctx.setBlendMode(.normal)
            }
            ProInkRenderer.draw(liveCache, color: live.colorRGBA, in: ctx, clip: rect)
            ctx.restoreGState()
        }
    }

    private func cachedDabs(for stroke: ProStroke) -> ProInkRenderer.Cached? {
        if let hit = cache[stroke.id] { return hit }
        guard let made = ProInkRenderer.cache(for: stroke) else { return nil }
        cache[stroke.id] = made
        return made
    }

    // MARK: 畫一筆

    func beginStroke(tool: ToolKind, color: [UInt8], width: Float, at point: ProPoint) {
        guard let name = ProInk.name(of: tool) else { return }
        live = ProStroke(tool: name, colorRGBA: color, baseWidth: width, points: [point])
        refreshLive(dirtyAround: [point])
    }

    func extendStroke(with points: [ProPoint]) {
        guard var stroke = live, !points.isEmpty else { return }
        stroke.points.append(contentsOf: points)
        live = stroke
        refreshLive(dirtyAround: points)
    }

    func endStroke() {
        guard var stroke = live else { return }
        live = nil
        liveCache = nil
        if stroke.points.count >= 3 {
            let pts = stroke.points.map {
                StrokePoint(x: $0.x, y: $0.y, pressure: $0.pressure, tilt: $0.tilt, azimuth: $0.azimuth, dtUs: $0.dtUs, roll: $0.roll)
            }
            let smoothed = streamlineSmoothPoints(points: pts, amount: 0.35, gamma: 1.0, taper: 0.20, tension: 0.30)
            stroke.points = smoothed.map {
                ProPoint(x: $0.x, y: $0.y, pressure: $0.pressure, tilt: $0.tilt, azimuth: $0.azimuth, dtUs: $0.dtUs, roll: $0.roll)
            }
        }
        ownStrokes.append(stroke)
        setNeedsDisplay(stroke.bounds)
        persist()
        registerUndo(removing: stroke.id)
    }

    func cancelStroke() {
        let area = live?.bounds
        live = nil
        liveCache = nil
        if let area { setNeedsDisplay(area) }
    }

    private func refreshLive(dirtyAround points: [ProPoint]) {
        guard let stroke = live else { return }
        liveCache = ProInkRenderer.cache(for: stroke)
        // 噴槍與油畫筆的筆點比基準寬度大，髒矩形要外擴；新舊點都要涵蓋，
        // 否則新筆點蓋住的舊筆點邊緣會留下殘影。
        let tail = Array(stroke.points.suffix(points.count + 2))
        let area = ProStroke(tool: stroke.tool, colorRGBA: stroke.colorRGBA,
                             baseWidth: stroke.baseWidth, points: tail).bounds
        setNeedsDisplay(area)
    }

    // MARK: 擦除

    /// 擦掉碰到 `path` 的專業筆畫（整筆擦除）。回傳擦了幾筆。
    @discardableResult
    func erase(along path: [CGPoint], radius: CGFloat) -> Int {
        guard !path.isEmpty else { return 0 }
        var hit: [ProStroke] = []
        for stroke in ownStrokes where touches(stroke, path: path, radius: radius) {
            hit.append(stroke)
        }
        guard !hit.isEmpty else { return 0 }
        let ids = Set(hit.map(\.id))
        ownStrokes.removeAll { ids.contains($0.id) }
        for stroke in hit { setNeedsDisplay(stroke.bounds) }
        persist()
        registerUndo(restoring: hit)
        return hit.count
    }

    private func touches(_ stroke: ProStroke, path: [CGPoint], radius: CGFloat) -> Bool {
        let reach = radius + CGFloat(stroke.baseWidth) * 0.5
        guard stroke.bounds.insetBy(dx: -radius, dy: -radius).contains(where: path) else { return false }
        for p in stroke.points {
            for q in path where hypot(CGFloat(p.x) - q.x, CGFloat(p.y) - q.y) <= reach { return true }
        }
        return false
    }

    // MARK: 復原／重做

    private func registerUndo(removing id: String) {
        guard let manager = undoManagerProvider?() else { return }
        manager.registerUndo(withTarget: self) { layer in
            guard let stroke = layer.ownStrokes.first(where: { $0.id == id }) else { return }
            layer.ownStrokes.removeAll { $0.id == id }
            layer.setNeedsDisplay(stroke.bounds)
            layer.persist()
            layer.registerUndo(restoring: [stroke])
        }
    }

    private func registerUndo(restoring strokes: [ProStroke]) {
        guard let manager = undoManagerProvider?() else { return }
        manager.registerUndo(withTarget: self) { layer in
            layer.ownStrokes.append(contentsOf: strokes)
            for stroke in strokes { layer.setNeedsDisplay(stroke.bounds) }
            layer.persist()
            for stroke in strokes { layer.registerUndo(removing: stroke.id) }
        }
    }
}

private extension CGRect {
    /// 路徑上有沒有任何一點落在這個矩形裡。
    func contains(where path: [CGPoint]) -> Bool {
        path.contains { self.contains($0) }
    }
}

// MARK: - 輸入

/// 收專業筆刷的筆跡（單指或 Apple Pencil）與橡皮擦的軌跡。
///
/// 兩指以上一律放手給捲動與縮放 —— 看到第二根手指就取消目前這一筆。
final class ProStrokeGestureRecognizer: UIGestureRecognizer {
    enum Mode { case draw, erase }

    var mode: Mode = .draw
    /// 手指是否能畫。政策是 `.pencilOnly` 時只收 Apple Pencil。
    var allowsFingerDrawing: () -> Bool = { true }
    weak var layerView: ProInkLayerView?
    var tool: () -> ToolKind? = { nil }
    var color: () -> [UInt8] = { [0, 0, 0, 255] }
    var width: () -> Float = { 4 }
    var eraserRadius: () -> CGFloat = { 10 }

    private var tracked: UITouch?
    private var lastTimestamp: TimeInterval = 0
    private var erasePath: [CGPoint] = []

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let layerView else { state = .failed; return }
        if tracked != nil {
            // 第二根手指：這不是書寫，是捲動或縮放。
            cancelCurrent()
            state = .cancelled
            return
        }
        guard touches.count == 1, let touch = touches.first,
              touch.type == .pencil || allowsFingerDrawing()
        else { state = .failed; return }

        tracked = touch
        lastTimestamp = touch.timestamp
        let point = makePoint(touch, in: layerView, dt: 0)
        state = .began
        switch mode {
        case .draw:
            guard let tool = tool() else { state = .failed; return }
            layerView.beginStroke(tool: tool, color: color(), width: width(), at: point)
        case .erase:
            erasePath = [CGPoint(x: CGFloat(point.x), y: CGFloat(point.y))]
            layerView.erase(along: erasePath, radius: eraserRadius())
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let layerView, let touch = tracked, touches.contains(touch) else { return }
        // 合併觸控（coalesced）才有完整的取樣率；預測觸控不收 —— 那是視覺補償，不是真實輸入。
        let samples = event.coalescedTouches(for: touch) ?? [touch]
        var points: [ProPoint] = []
        for sample in samples {
            let dt = UInt32(max(0, (sample.timestamp - lastTimestamp) * 1_000_000))
            lastTimestamp = sample.timestamp
            points.append(makePoint(sample, in: layerView, dt: dt))
        }
        switch mode {
        case .draw:
            layerView.extendStroke(with: points)
        case .erase:
            let path = points.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
            erasePath.append(contentsOf: path)
            layerView.erase(along: path, radius: eraserRadius())
        }
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = tracked, touches.contains(touch) else { return }
        if mode == .draw { layerView?.endStroke() }
        tracked = nil
        erasePath = []
        state = .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = tracked, touches.contains(touch) else { return }
        cancelCurrent()
        state = .cancelled
    }

    override func reset() {
        tracked = nil
        erasePath = []
    }

    private func cancelCurrent() {
        if mode == .draw { layerView?.cancelStroke() }
        tracked = nil
        erasePath = []
    }

    private func makePoint(_ touch: UITouch, in view: UIView, dt: UInt32) -> ProPoint {
        let location = touch.preciseLocation(in: view)
        let pressure: Float
        if touch.type == .pencil || touch.maximumPossibleForce > 0, touch.force > 0 {
            pressure = Float(min(1, max(0, touch.force / max(touch.maximumPossibleForce, 0.0001))))
        } else {
            // 手指與滑鼠沒有壓力：給一個中段值，筆畫才不會細到看不見。
            pressure = 0.6
        }
        let tilt = touch.type == .pencil ? Float(.pi / 2 - touch.altitudeAngle) : 0
        let azimuth = touch.type == .pencil ? Float(touch.azimuthAngle(in: view)) : 0
        let roll: Float = {
            if #available(iOS 17.5, *), touch.type == .pencil { return Float(touch.rollAngle) }
            return 0
        }()
        return ProPoint(x: Float(location.x), y: Float(location.y), pressure: pressure,
                        tilt: tilt, azimuth: azimuth < 0 ? azimuth + 2 * .pi : azimuth, dtUs: dt, roll: roll)
    }
}
