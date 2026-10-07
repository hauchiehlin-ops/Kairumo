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
    /// 製圖圖層（1 底／2 中／3 頂）。`nil` 與 0 都是「一般筆跡」。
    /// 存成可省略的欄位：舊筆記的 JSON 沒有這兩個鍵，照樣讀得進來。
    var layer: UInt8? = nil
    /// 工程線型（0 實線、1 隱藏線、2 中心線、3 假想線）。
    var lineType: UInt8? = nil

    var layerId: UInt8 { layer ?? 0 }
    var lineTypeId: UInt8 { lineType ?? 0 }

    /// 內容指紋：同步時分辨「這是不是同一筆」。
    ///
    /// 核心每次匯出都會替筆畫重新發 id，所以不能靠 id 認；位置取到 0.1 個頁面單位，
    /// 夠細到分得開兩筆不同的線，又粗到經過核心格式的量化之後仍然一致。
    var contentKey: String {
        guard let first = points.first, let last = points.last else { return "\(tool)|empty" }
        func q(_ v: Float) -> Int { Int((v * 10).rounded()) }
        // 圖層與線型只在有值時才進指紋：舊筆畫的指紋不變，已同步過的內容不會被當成新的一筆。
        let draft = (layerId != 0 || lineTypeId != 0) ? "|L\(layerId)T\(lineTypeId)" : ""
        return "\(tool)|\(colorRGBA.map(String.init).joined(separator: ","))|\(points.count)|\(q(first.x)),\(q(first.y))|\(q(last.x)),\(q(last.y))\(draft)"
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
            },
            layer: full.layer == 0 ? nil : full.layer,
            lineType: full.lineType == 0 ? nil : full.lineType)
    }
}

extension ProStroke {
    /// 從核心排好的製圖線（三視圖、步驟編號、範例筆記）建一筆。兩點以上才算線。
    ///
    /// 補點到每 4 個頁面單位一點：虛線與點畫線的間隔由筆點陣挖出來，點太稀的話間隔會跟著失準。
    init?(drafted item: FfiSheetStroke, origin: CGPoint = .zero) {
        guard item.points.count >= 2 else { return nil }
        var pts: [ProPoint] = []
        func add(_ x: Float, _ y: Float) {
            pts.append(ProPoint(x: x + Float(origin.x), y: y + Float(origin.y), pressure: 0.6, tilt: 0,
                                azimuth: 0, dtUs: 2000, roll: 0))
        }
        add(item.points[0].x, item.points[0].y)
        for (a, b) in zip(item.points, item.points.dropFirst()) {
            let len = hypot(b.x - a.x, b.y - a.y)
            let n = max(1, Int((len / 4).rounded(.up)))
            for k in 1...n {
                let t = Float(k) / Float(n)
                add(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
            }
        }
        self.init(
            tool: "fineliner", colorRGBA: DraftingState.rgba(fromHex: item.colorHex),
            baseWidth: item.width, points: pts,
            layer: item.layer == 0 ? nil : item.layer,
            lineType: item.lineType == 0 ? nil : item.lineType)
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

    /// 使用者在這台擦掉的「別台的筆畫」的內容指紋。
    ///
    /// 別台的筆畫是同步下載下來的，雲端那一份還在：不記住的話，下一輪匯入又把它
    /// 帶回來，使用者擦掉的東西會「復活」。匯入時用它過濾。
    nonisolated static func loadSuppressed(in directory: URL, notebookId: String, page: Int) -> Set<String> {
        let file = directory.appending(path: "\(notebookId)_p\(page).proink-suppressed.json")
        guard let data = try? Data(contentsOf: file),
              let keys = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(keys)
    }

    nonisolated static func saveSuppressed(_ keys: Set<String>, in directory: URL, notebookId: String, page: Int) {
        let file = directory.appending(path: "\(notebookId)_p\(page).proink-suppressed.json")
        if keys.isEmpty {
            try? FileManager.default.removeItem(at: file)
            return
        }
        guard let data = try? JSONEncoder().encode(keys.sorted()) else { return }
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
        let dabs: [FfiDab]
        if stroke.lineTypeId != 0 {
            // 虛線／點線：核心依線型把間隔挖掉，兩個平台畫出同樣的線。
            dabs = brushDabsStyled(tool: kind, baseWidth: stroke.baseWidth,
                                   points: ProInk.strokePoints(stroke.points), lineType: stroke.lineTypeId)
        } else {
            dabs = brushDabs(tool: kind, baseWidth: stroke.baseWidth, points: ProInk.strokePoints(stroke.points))
        }
        return Cached(dabs: dabs, bounds: stroke.bounds)
    }

    // MARK: - 紋理快取（由 padnote-core FFI 提供）
    private static let grainSize: Int = 128
    private static let grainCGImage: CGImage? = {
        let bytes = brushPaperGrainTexture(width: UInt32(grainSize), height: UInt32(grainSize), scale: 4.0)
        guard bytes.count == grainSize * grainSize else { return nil }
        guard let provider = CGDataProvider(data: bytes as CFData) else { return nil }
        return CGImage(
            width: grainSize,
            height: grainSize,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: grainSize,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }()

    /// 深色底上把近黑的墨水提亮（反相）。
    static func displayColor(_ rgba: [UInt8], dark: Bool) -> [UInt8] {
        guard dark, rgba.count == 4 else { return rgba }
        let lum = (0.299 * Double(rgba[0]) + 0.587 * Double(rgba[1]) + 0.114 * Double(rgba[2])) / 255
        guard lum < 0.35 else { return rgba }
        return [255 - rgba[0], 255 - rgba[1], 255 - rgba[2], rgba[3]]
    }

    /// 把一筆畫的筆點畫進 `ctx`，只畫碰得到 `clip` 的那些。
    static func draw(_ cached: Cached, toolName: String = "", color rgba: [UInt8], in ctx: CGContext, clip: CGRect) {
        guard rgba.count == 4 else { return }
        let base = (r: CGFloat(rgba[0]) / 255, g: CGFloat(rgba[1]) / 255, b: CGFloat(rgba[2]) / 255)
        let strokeAlpha = CGFloat(rgba[3]) / 255
        let needsGrain = (toolName == "charcoal" || toolName == "crayon") && grainCGImage != nil

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

            if needsGrain, let grain = grainCGImage {
                // 炭筆／蠟筆：套用底層紙張孔隙遮罩
                ctx.clip(to: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2), mask: grain)
            }

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

    /// 工具的預覽（標註畫到一半的樣子）與已選的點。不存檔、不進復原；每次更新整組換掉。
    private var overlayStrokes: [ProStroke] = []
    private var overlayMarks: [CGPoint] = []

    /// 製圖：正在畫的線對齊了哪些既有點（虛線導引）、是否靠著尺的邊、尾端是否被對齊吸附過。
    private var alignGuides: [[CGPoint]] = []
    private var edgeLock: (a: CGPoint, b: CGPoint)?
    private var tailSnapped = false

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
        NotificationCenter.default.addObserver(
            self, selector: #selector(draftingChanged), name: .kairumoDraftingChanged, object: nil)
    }

    /// 圖層顯示／鎖定改了：整層重畫（只是不畫某些筆畫，筆點快取不必清）。
    @objc private func draftingChanged() {
        setNeedsDisplay()
        onDraftingChanged?()
    }

    /// 製圖設定或尺規變了（測試讀數要跟著更新；不算內容修改）。
    var onDraftingChanged: (() -> Void)?

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
        NotificationCenter.default.post(name: AppCommand.proInkDidChange, object: notebookId.lowercased())
    }

    // MARK: 繪製

    /// 深色模式下頁面是深色的：近黑的墨水（製圖的「頂」「底」層）會看不見，
    /// 就像 PencilKit 會把深色墨水在深色模式反相，這裡也把近黑的色提亮。
    /// 只影響畫面與縮圖；存檔與匯出仍是原色（匯出的紙是白的）。
    private func displayColor(_ rgba: [UInt8]) -> [UInt8] {
        ProInkRenderer.displayColor(rgba, dark: traitCollection.userInterfaceStyle == .dark)
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let drafting = DraftingState.shared
        let ordered = drafting.drawOrder(allStrokes, notebookId: notebookId)
        for stroke in ordered where stroke.bounds.intersects(rect) {
            guard let cached = cachedDabs(for: stroke) else { continue }
            ctx.saveGState()
            if stroke.blendMode == "multiply" {
                ctx.setBlendMode(.multiply)
            } else if stroke.blendMode == "screen" {
                ctx.setBlendMode(.screen)
            } else {
                ctx.setBlendMode(.normal)
            }
            ProInkRenderer.draw(cached, toolName: stroke.tool, color: displayColor(stroke.colorRGBA), in: ctx, clip: rect)
            ctx.restoreGState()
        }
        for stroke in overlayStrokes where stroke.bounds.intersects(rect) {
            guard let cached = ProInkRenderer.cache(for: stroke) else { continue }
            ProInkRenderer.draw(cached, toolName: stroke.tool, color: displayColor(stroke.colorRGBA), in: ctx, clip: rect)
        }
        for mark in overlayMarks {
            let r: CGFloat = 5
            let dot = CGRect(x: mark.x - r, y: mark.y - r, width: r * 2, height: r * 2)
            guard dot.intersects(rect) else { continue }
            ctx.setStrokeColor(UIColor.systemOrange.cgColor)
            ctx.setLineWidth(1.6)
            ctx.strokeEllipse(in: dot.insetBy(dx: 1, dy: 1))
            ctx.setFillColor(UIColor.systemOrange.withAlphaComponent(0.35).cgColor)
            ctx.fillEllipse(in: dot.insetBy(dx: 1, dy: 1))
        }
        let drafting2 = DraftingState.shared
        if let pivot = drafting2.pivot(notebookId: notebookId, page: pageIndex) {
            ctx.setStrokeColor(UIColor.systemBlue.cgColor)
            ctx.setLineWidth(1.2)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: pivot.x - 9, y: pivot.y)); ctx.addLine(to: CGPoint(x: pivot.x + 9, y: pivot.y))
            ctx.move(to: CGPoint(x: pivot.x, y: pivot.y - 9)); ctx.addLine(to: CGPoint(x: pivot.x, y: pivot.y + 9))
            ctx.strokePath()
            ctx.strokeEllipse(in: CGRect(x: pivot.x - 5, y: pivot.y - 5, width: 10, height: 10))
        }
        if let model = drafting2.instrument, model.bounds.intersects(rect) {
            model.draw(in: ctx, dark: traitCollection.userInterfaceStyle == .dark)
        }
        if !alignGuides.isEmpty {
            ctx.saveGState()
            ctx.setStrokeColor(UIColor.systemBlue.withAlphaComponent(0.85).cgColor)
            ctx.setLineWidth(1)
            ctx.setLineDash(phase: 0, lengths: [6, 4])
            for line in alignGuides where line.count >= 2 {
                ctx.beginPath()
                ctx.move(to: line[0])
                for q in line.dropFirst() { ctx.addLine(to: q) }
                ctx.strokePath()
            }
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
            ProInkRenderer.draw(liveCache, toolName: live.tool, color: displayColor(live.colorRGBA), in: ctx, clip: rect)
            ctx.restoreGState()
        }
    }

    // MARK: 工具覆蓋層（預覽與已選的點）

    /// 換掉整組預覽。傳空陣列就是清掉。
    func setOverlay(strokes: [FfiSheetStroke], marks: [CGPoint]) {
        let old = overlayBounds()
        overlayStrokes = strokes.compactMap { ProStroke(drafted: $0) }
        overlayMarks = marks
        setNeedsDisplay(old.union(overlayBounds()).insetBy(dx: -12, dy: -12))
    }

    func clearOverlay() { setOverlay(strokes: [], marks: []) }

    private func overlayBounds() -> CGRect {
        var box = overlayStrokes.map(\.bounds).reduce(CGRect.null) { $0.union($1) }
        for m in overlayMarks { box = box.union(CGRect(x: m.x - 8, y: m.y - 8, width: 16, height: 16)) }
        return box
    }

    // MARK: 吸附點

    /// 離 `point` 最近的**吸附點**（半徑 `radius` 之內）：筆畫的端點、轉折點，以及圓形筆畫的圓心。
    /// 標註要量準，就得釘在線的端點與圓心上，而不是手指落下的那個點。
    func snapAnchor(near point: CGPoint, radius: CGFloat) -> CGPoint? {
        let drafting = DraftingState.shared
        var best: (CGPoint, CGFloat)?
        func consider(_ p: CGPoint) {
            let d = hypot(p.x - point.x, p.y - point.y)
            if d <= radius, d < (best?.1 ?? .greatestFiniteMagnitude) { best = (p, d) }
        }
        for stroke in allStrokes where stroke.layerId == 0 || !drafting.isHidden(layer: stroke.layerId, notebookId: notebookId) {
            let pts = stroke.points
            guard let first = pts.first, let last = pts.last else { continue }
            guard stroke.bounds.insetBy(dx: -radius, dy: -radius).contains(point) else { continue }
            consider(CGPoint(x: CGFloat(first.x), y: CGFloat(first.y)))
            consider(CGPoint(x: CGFloat(last.x), y: CGFloat(last.y)))
            // 吸附出來的線／多邊形只有幾個點，每個點都是轉折；手繪的長線不是。
            if pts.count <= 12 { for p in pts { consider(CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))) } }
            if let circle = Self.fitCircle(pts.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }) {
                consider(circle.center)
            }
        }
        return best?.0
    }

    // MARK: 投影對齊與尺規靠邊

    private var pageScale: CGFloat { max(transform.a, 0.25) }

    /// 對齊用的點：看得見的筆畫的端點與短折線的轉折點（上限 600 個，免得大頁面拖慢）。
    private func alignAnchors() -> [FfiPoint] {
        let drafting = DraftingState.shared
        var out: [FfiPoint] = []
        for stroke in allStrokes where stroke.layerId == 0 || !drafting.isHidden(layer: stroke.layerId, notebookId: notebookId) {
            let pts = stroke.points
            guard let first = pts.first, let last = pts.last else { continue }
            out.append(FfiPoint(x: first.x, y: first.y))
            out.append(FfiPoint(x: last.x, y: last.y))
            if pts.count <= 12 { for q in pts.dropFirst().dropLast() { out.append(FfiPoint(x: q.x, y: q.y)) } }
            if out.count > 600 { break }
        }
        return out
    }

    /// 把 `p` 對齊既有點；有對齊就記下虛線導引。製圖以外（一般手寫）不介入。
    private func aligned(_ p: CGPoint) -> CGPoint {
        let drafting = DraftingState.shared
        guard drafting.alignEnabled else { return p }
        let result = draftAlign(
            cursor: FfiPoint(x: Float(p.x), y: Float(p.y)), anchors: alignAnchors(),
            pivot: drafting.pivot(notebookId: notebookId, page: pageIndex).map { FfiPoint(x: Float($0.x), y: Float($0.y)) },
            thirdAngle: drafting.thirdAngle, tolerance: Float(8 / pageScale))
        setGuides(result.guides.map { $0.points.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) } })
        return CGPoint(x: CGFloat(result.point.x), y: CGFloat(result.point.y))
    }

    private func setGuides(_ lines: [[CGPoint]]) {
        guard !(lines.isEmpty && alignGuides.isEmpty) else { return }
        var dirty = CGRect.null
        for line in alignGuides + lines { for q in line { dirty = dirty.union(CGRect(origin: q, size: .zero)) } }
        alignGuides = lines
        if !dirty.isNull { setNeedsDisplay(dirty.insetBy(dx: -6, dy: -6)) }
    }

    /// `point` 附近的圓形筆畫（首尾相接、擬合殘差小）：回傳圓心與半徑。
    func circle(near point: CGPoint, radius: CGFloat) -> (center: CGPoint, radius: CGFloat)? {
        var best: ((CGPoint, CGFloat), CGFloat)?
        for stroke in allStrokes {
            let pts = stroke.points.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
            guard stroke.bounds.insetBy(dx: -radius, dy: -radius).contains(point),
                  let fit = Self.fitCircle(pts) else { continue }
            // 點到圓周的距離。
            let d = abs(hypot(point.x - fit.center.x, point.y - fit.center.y) - fit.radius)
            if d <= radius + CGFloat(stroke.baseWidth), d < (best?.1 ?? .greatestFiniteMagnitude) {
                best = ((fit.center, fit.radius), d)
            }
        }
        return best.map { (center: $0.0.0, radius: $0.0.1) }
    }

    /// 閉合的點列擬合成圓（Kåsa 代數法）。不閉合、太小、殘差超過半徑 6% 都回 `nil`。
    static func fitCircle(_ pts: [CGPoint]) -> (center: CGPoint, radius: CGFloat)? {
        guard pts.count >= 8, let first = pts.first, let last = pts.last else { return nil }
        var perimeter: CGFloat = 0
        for i in 1..<pts.count { perimeter += hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y) }
        guard perimeter > 30, hypot(first.x - last.x, first.y - last.y) < perimeter * 0.08 else { return nil }
        // 解 [Σx² Σxy Σx; Σxy Σy² Σy; Σx Σy n] · [A B C] = [Σ(x²+y²)x, Σ(x²+y²)y, Σ(x²+y²)]
        var sx = 0.0, sy = 0.0, sxx = 0.0, syy = 0.0, sxy = 0.0, sz = 0.0, szx = 0.0, szy = 0.0
        let n = Double(pts.count)
        for p in pts {
            let x = Double(p.x), y = Double(p.y), z = x * x + y * y
            sx += x; sy += y; sxx += x * x; syy += y * y; sxy += x * y; sz += z; szx += z * x; szy += z * y
        }
        let m = [[sxx, sxy, sx], [sxy, syy, sy], [sx, sy, n]]
        let b = [szx, szy, sz]
        let det = { (a: [[Double]]) -> Double in
            a[0][0] * (a[1][1] * a[2][2] - a[1][2] * a[2][1])
                - a[0][1] * (a[1][0] * a[2][2] - a[1][2] * a[2][0])
                + a[0][2] * (a[1][0] * a[2][1] - a[1][1] * a[2][0])
        }
        let d = det(m)
        guard abs(d) > 1e-9 else { return nil }
        var sol = [0.0, 0.0, 0.0]
        for k in 0..<3 {
            var mk = m
            for r in 0..<3 { mk[r][k] = b[r] }
            sol[k] = det(mk) / d
        }
        let cx = sol[0] / 2, cy = sol[1] / 2
        let r2 = sol[2] + cx * cx + cy * cy
        guard r2 > 0 else { return nil }
        let r = sqrt(r2)
        // 殘差：每個點到圓周的距離的平均。
        var err = 0.0
        for p in pts { err += abs(hypot(Double(p.x) - cx, Double(p.y) - cy) - r) }
        guard err / n < r * 0.06, r > 4 else { return nil }
        return (CGPoint(x: cx, y: cy), CGFloat(r))
    }

    private func cachedDabs(for stroke: ProStroke) -> ProInkRenderer.Cached? {
        if let hit = cache[stroke.id] { return hit }
        guard let made = ProInkRenderer.cache(for: stroke) else { return nil }
        cache[stroke.id] = made
        return made
    }

    // MARK: 畫一筆

    func beginStroke(tool: ToolKind, color: [UInt8], width: Float, at point: ProPoint,
                     layer: UInt8 = 0, lineType: UInt8 = 0) {
        guard let name = ProInk.name(of: tool) else { return }
        var point = point
        edgeLock = nil
        tailSnapped = false
        if layer != 0 {
            let here = CGPoint(x: CGFloat(point.x), y: CGFloat(point.y))
            if let model = DraftingState.shared.instrument,
               let edge = model.nearestEdge(to: here, band: 14 / pageScale) {
                // 靠著尺的邊起筆：起點釘在邊上，整筆沿著邊走。
                edgeLock = (edge.a, edge.b)
                point.x = Float(edge.foot.x); point.y = Float(edge.foot.y)
            } else {
                let q = aligned(here)
                point.x = Float(q.x); point.y = Float(q.y)
            }
        }
        live = ProStroke(tool: name, colorRGBA: color, baseWidth: width, points: [point],
                         layer: layer == 0 ? nil : layer, lineType: lineType == 0 ? nil : lineType)
        snapState = nil
        refreshLive(dirtyAround: [point])
    }

    func extendStroke(with points: [ProPoint]) {
        guard var stroke = live, !points.isEmpty else { return }
        // 吸附之後：直線跟著手指的終點走（角度鎖定照樣生效）；其他圖形定型，不再變。
        if let snap = snapState {
            guard snap.kind == .line, let end = points.last else { return }
            let area = stroke.bounds
            let (dx, dy) = Self.snapped(dx: end.x - snap.origin.x, dy: end.y - snap.origin.y, step: snap.angleStep)
            stroke.points = Self.lineSamples(from: snap.origin, toX: snap.origin.x + dx, y: snap.origin.y + dy, count: snap.count)
            live = stroke
            setNeedsDisplay(area.union(stroke.bounds))
            liveCache = ProInkRenderer.cache(for: stroke)
            return
        }
        if let lock = edgeLock, let first = stroke.points.first, var end = points.last {
            let foot = InstrumentModel.footOnLine(CGPoint(x: CGFloat(end.x), y: CGFloat(end.y)), lock.a, lock.b)
            end.x = Float(foot.x); end.y = Float(foot.y)
            let area = stroke.bounds
            stroke.points = Self.lineSamples(from: first, toX: end.x, y: end.y, count: 24)
            live = stroke
            setNeedsDisplay(area.union(stroke.bounds))
            liveCache = ProInkRenderer.cache(for: stroke)
            return
        }
        var points = points
        if tailSnapped, !stroke.points.isEmpty { stroke.points.removeLast() }
        tailSnapped = false
        if stroke.layerId != 0, var last = points.last {
            let q = aligned(CGPoint(x: CGFloat(last.x), y: CGFloat(last.y)))
            if !alignGuides.isEmpty {
                last.x = Float(q.x); last.y = Float(q.y)
                points[points.count - 1] = last
                tailSnapped = true
            }
        }
        stroke.points.append(contentsOf: points)
        live = stroke
        refreshLive(dirtyAround: points)
    }

    // MARK: 長按吸附

    private struct SnapState {
        var kind: FfiDraftSnapKind
        var origin: ProPoint
        var angleStep: Float
        var count: Int
    }
    private var snapState: SnapState?
    var isSnapped: Bool { snapState != nil }

    /// 把正在畫的這一筆釘成直線／圓／矩形／三角形／鎖角度的折線。回傳有沒有吸附成功。
    @discardableResult
    func snapLiveStroke(angleStep: Float) -> FfiDraftSnapKind? {
        guard var stroke = live, snapState == nil, stroke.points.count >= 3 else { return nil }
        let input = stroke.points.map { FfiPoint(x: $0.x, y: $0.y) }
        let result = draftSnapStroke(points: input, angleStepDeg: angleStep)
        guard result.kind != .none, result.points.count == stroke.points.count else { return nil }
        let area = stroke.bounds
        for (i, p) in result.points.enumerated() {
            stroke.points[i].x = p.x
            stroke.points[i].y = p.y
        }
        live = stroke
        snapState = SnapState(kind: result.kind, origin: stroke.points[0], angleStep: angleStep,
                              count: stroke.points.count)
        liveCache = ProInkRenderer.cache(for: stroke)
        setNeedsDisplay(area.union(stroke.bounds))
        return result.kind
    }

    private static func snapped(dx: Float, dy: Float, step: Float) -> (Float, Float) {
        guard step > 0 else { return (dx, dy) }
        let len = hypot(dx, dy)
        guard len > 0.0001 else { return (dx, dy) }
        let unit = step * .pi / 180
        let a = (atan2(dy, dx) / unit).rounded() * unit
        let c = cos(a), s = sin(a)
        return (abs(c) < 1e-6 ? 0 : c * len, abs(s) < 1e-6 ? 0 : s * len)
    }

    private static func lineSamples(from o: ProPoint, toX x: Float, y: Float, count: Int) -> [ProPoint] {
        let n = max(count, 2)
        return (0..<n).map { i in
            let t = Float(i) / Float(n - 1)
            var p = o
            p.x = o.x + (x - o.x) * t
            p.y = o.y + (y - o.y) * t
            return p
        }
    }

    func endStroke() {
        guard var stroke = live else { return }
        live = nil
        liveCache = nil
        // 製圖線要的是等寬、不收尖、不圓角：不做平滑。
        if stroke.points.count >= 3, stroke.layerId == 0, stroke.lineTypeId == 0 {
            let pts = stroke.points.map {
                StrokePoint(x: $0.x, y: $0.y, pressure: $0.pressure, tilt: $0.tilt, azimuth: $0.azimuth, dtUs: $0.dtUs, roll: $0.roll)
            }
            let smoothed = streamlineSmoothPoints(points: pts, amount: 0.35, gamma: 1.0, taper: 0.20, tension: 0.30)
            stroke.points = smoothed.map {
                ProPoint(x: $0.x, y: $0.y, pressure: $0.pressure, tilt: $0.tilt, azimuth: $0.azimuth, dtUs: $0.dtUs, roll: $0.roll)
            }
        }
        snapState = nil
        edgeLock = nil
        tailSnapped = false
        setGuides([])
        ownStrokes.append(stroke)
        setNeedsDisplay(stroke.bounds)
        persist()
        registerUndo(removing: stroke.id)
    }

    func cancelStroke() {
        let area = live?.bounds
        snapState = nil
        edgeLock = nil
        tailSnapped = false
        setGuides([])
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
        let drafting = DraftingState.shared
        for stroke in ownStrokes
        where drafting.canEdit(layer: stroke.layerId, notebookId: notebookId) && touches(stroke, path: path, radius: radius) {
            hit.append(stroke)
        }
        // **別台（或舊安裝、重新下載之後）的筆畫也要擦得掉。** 它們看得見，
        // 只擦自己的話使用者會遇到「畫面上有、橡皮擦與復原都碰不到」的筆畫。
        var hitForeign: [ProStroke] = []
        for stroke in foreignStrokes
        where drafting.canEdit(layer: stroke.layerId, notebookId: notebookId) && touches(stroke, path: path, radius: radius) {
            hitForeign.append(stroke)
        }
        guard !hit.isEmpty || !hitForeign.isEmpty else { return 0 }
        if !hit.isEmpty {
            let ids = Set(hit.map(\.id))
            ownStrokes.removeAll { ids.contains($0.id) }
            for stroke in hit { setNeedsDisplay(stroke.bounds) }
            persist()
            registerUndo(restoring: hit)
        }
        if !hitForeign.isEmpty { removeForeign(hitForeign) }
        return hit.count + hitForeign.count
    }

    /// 擦掉別台的筆畫：從畫面與檔案拿掉，指紋記進「已擦除」名單讓下一輪同步不再帶回來。可復原。
    private func removeForeign(_ strokes: [ProStroke], registersUndo: Bool = true) {
        guard let directory else { return }
        let ids = Set(strokes.map(\.id))
        foreignStrokes.removeAll { ids.contains($0.id) }
        for stroke in strokes { setNeedsDisplay(stroke.bounds) }
        var keys = ProInkStore.loadSuppressed(in: directory, notebookId: notebookId, page: pageIndex)
        keys.formUnion(strokes.map(\.contentKey))
        ProInkStore.saveSuppressed(keys, in: directory, notebookId: notebookId, page: pageIndex)
        ProInkStore.save(foreignStrokes, in: directory, notebookId: notebookId, page: pageIndex, foreign: true)
        onChanged?()
        NotificationCenter.default.post(name: AppCommand.proInkDidChange, object: notebookId.lowercased())
        if registersUndo { registerForeignUndo(restoring: strokes) }
    }

    private func restoreForeign(_ strokes: [ProStroke]) {
        guard let directory else { return }
        foreignStrokes.append(contentsOf: strokes)
        for stroke in strokes { setNeedsDisplay(stroke.bounds) }
        var keys = ProInkStore.loadSuppressed(in: directory, notebookId: notebookId, page: pageIndex)
        keys.subtract(strokes.map(\.contentKey))
        ProInkStore.saveSuppressed(keys, in: directory, notebookId: notebookId, page: pageIndex)
        ProInkStore.save(foreignStrokes, in: directory, notebookId: notebookId, page: pageIndex, foreign: true)
        onChanged?()
        NotificationCenter.default.post(name: AppCommand.proInkDidChange, object: notebookId.lowercased())
    }

    private func registerForeignUndo(restoring strokes: [ProStroke]) {
        guard let manager = undoManagerProvider?() else { return }
        manager.registerUndo(withTarget: self) { layer in
            layer.restoreForeign(strokes)
            layer.registerForeignRedo(removing: strokes)
        }
    }

    private func registerForeignRedo(removing strokes: [ProStroke]) {
        guard let manager = undoManagerProvider?() else { return }
        manager.registerUndo(withTarget: self) { layer in
            layer.removeForeign(strokes)
        }
    }

    private func touches(_ stroke: ProStroke, path: [CGPoint], radius: CGFloat) -> Bool {
        let reach = radius + CGFloat(stroke.baseWidth) * 0.5
        guard stroke.bounds.insetBy(dx: -radius, dy: -radius).contains(where: path) else { return false }
        for p in stroke.points {
            for q in path where hypot(CGFloat(p.x) - q.x, CGFloat(p.y) - q.y) <= reach { return true }
        }
        return false
    }

    // MARK: 一次插入一組筆畫（立體輔助的三視圖、步驟編號標記）

    /// 把核心排好的製圖線插進這一頁，原點偏移 `origin`。整組是**一次復原**。
    ///
    /// 線都是兩點的直線時補點到每 4 個頁面單位一點：虛線與點畫線的間隔由筆點陣挖出來，
    /// 點太稀的話間隔會跟著失準。
    @discardableResult
    func insertDrafted(_ items: [FfiSheetStroke], origin: CGPoint) -> [ProStroke] {
        let made = items.compactMap { ProStroke(drafted: $0, origin: origin) }
        guard !made.isEmpty else { return [] }
        ownStrokes.append(contentsOf: made)
        for s in made { setNeedsDisplay(s.bounds) }
        persist()
        registerGroupUndo(inserting: made)
        return made
    }

    private func registerGroupUndo(inserting strokes: [ProStroke]) {
        guard let manager = undoManagerProvider?() else { return }
        let ids = Set(strokes.map(\.id))
        manager.registerUndo(withTarget: self) { layer in
            layer.ownStrokes.removeAll { ids.contains($0.id) }
            for s in strokes { layer.setNeedsDisplay(s.bounds) }
            layer.persist()
            layer.registerGroupRedo(restoring: strokes)
        }
    }

    private func registerGroupRedo(restoring strokes: [ProStroke]) {
        guard let manager = undoManagerProvider?() else { return }
        manager.registerUndo(withTarget: self) { layer in
            layer.ownStrokes.append(contentsOf: strokes)
            for s in strokes { layer.setNeedsDisplay(s.bounds) }
            layer.persist()
            layer.registerGroupUndo(inserting: strokes)
        }
    }

    /// 頁面上所有筆畫的點（立體輔助從裡面找封閉輪廓）。
    ///
    /// 中層（輔助線與步驟編號）不算：步驟編號是一個個小圓圈，會被當成最小的封閉圖形。
    var sketchPolylines: [[CGPoint]] {
        allStrokes.filter { $0.layerId != 2 }
            .map { $0.points.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) } }
    }

    // MARK: 套索（製圖線都是專業筆畫，套索要能選、搬、刪、複製）

    /// 完全被多邊形圈住、而且圖層動得了（沒隱藏沒鎖定）的自己的筆畫。
    func strokeIds(enclosedBy polygon: [Float]) -> Set<String> {
        let drafting = DraftingState.shared
        var ids = Set<String>()
        for s in ownStrokes where drafting.canEdit(layer: s.layerId, notebookId: notebookId) {
            let flat = s.points.flatMap { [$0.x, $0.y] }
            if lassoEncloses(polygon: polygon, points: flat) { ids.insert(s.id) }
        }
        return ids
    }

    private var moveIds: Set<String> = []
    private var moveTotal = CGSize.zero

    /// 拖曳搬移：過程中只改記憶體與畫面，放手（`endMove`）才存檔、登記一次復原。
    func move(ids: Set<String>, by delta: CGSize) {
        moveIds = ids
        moveTotal.width += delta.width
        moveTotal.height += delta.height
        for i in ownStrokes.indices where ids.contains(ownStrokes[i].id) {
            setNeedsDisplay(ownStrokes[i].bounds)
            for k in ownStrokes[i].points.indices {
                ownStrokes[i].points[k].x += Float(delta.width)
                ownStrokes[i].points[k].y += Float(delta.height)
            }
            cache[ownStrokes[i].id] = nil
            setNeedsDisplay(ownStrokes[i].bounds)
        }
    }

    func endMove() {
        guard !moveIds.isEmpty else { return }
        let ids = moveIds, total = moveTotal
        moveIds = []
        moveTotal = .zero
        persist()
        setNeedsDisplay()   // 拖曳途中的局部重畫可能殘留舊位置的像素，放手時整層重畫一次
        registerMoveUndo(ids: ids, delta: total)
    }

    private func registerMoveUndo(ids: Set<String>, delta: CGSize) {
        guard let manager = undoManagerProvider?() else { return }
        manager.registerUndo(withTarget: self) { layer in
            layer.move(ids: ids, by: CGSize(width: -delta.width, height: -delta.height))
            layer.moveIds = []
            layer.moveTotal = .zero
            layer.persist()
            layer.registerMoveUndo(ids: ids, delta: CGSize(width: -delta.width, height: -delta.height))
        }
    }

    func delete(ids: Set<String>) {
        let hit = ownStrokes.filter { ids.contains($0.id) }
        guard !hit.isEmpty else { return }
        ownStrokes.removeAll { ids.contains($0.id) }
        for s in hit { setNeedsDisplay(s.bounds) }
        persist()
        registerUndo(restoring: hit)
    }

    func strokes(ids: Set<String>) -> [ProStroke] { ownStrokes.filter { ids.contains($0.id) } }

    /// 把一組筆畫（新 id）偏移後加進這一頁，一次復原。回傳新筆畫的 id。
    @discardableResult
    func add(copies: [ProStroke], offset: CGSize) -> Set<String> {
        let made: [ProStroke] = copies.map {
            var c = $0
            c.id = UUID().uuidString
            for k in c.points.indices {
                c.points[k].x += Float(offset.width)
                c.points[k].y += Float(offset.height)
            }
            return c
        }
        guard !made.isEmpty else { return [] }
        ownStrokes.append(contentsOf: made)
        for s in made { setNeedsDisplay(s.bounds) }
        persist()
        registerGroupUndo(inserting: made)
        return Set(made.map(\.id))
    }

    // MARK: 編輯工具（修剪、延伸、鏡射、陣列、圓角、偏移）

    /// 離 `point` 最近的一筆（`radius` 之內，圖層看得見才算；`editable` 時鎖住的圖層也排除）。
    /// 疊在一起時取最上面（畫得最晚）的那一筆。
    func strokeNear(_ point: CGPoint, radius: CGFloat, editable: Bool = true) -> ProStroke? {
        let drafting = DraftingState.shared
        var best: (ProStroke, CGFloat)?
        for stroke in ownStrokes {
            if stroke.layerId != 0 {
                if drafting.isHidden(layer: stroke.layerId, notebookId: notebookId) { continue }
                if editable && drafting.isLocked(layer: stroke.layerId, notebookId: notebookId) { continue }
            }
            guard stroke.bounds.insetBy(dx: -radius, dy: -radius).contains(point) else { continue }
            var d = CGFloat.greatestFiniteMagnitude
            if stroke.points.count == 1, let only = stroke.points.first {
                d = hypot(CGFloat(only.x) - point.x, CGFloat(only.y) - point.y)
            }
            for (a, b) in zip(stroke.points, stroke.points.dropFirst()) {
                d = min(d, Self.distance(from: point, toSegment: a, b))
            }
            // 較晚的筆畫（同距離）優先：`<=` 讓後面的蓋過前面的。
            if d <= radius + CGFloat(stroke.baseWidth) * 0.5, d <= (best?.1 ?? .greatestFiniteMagnitude) {
                best = (stroke, d)
            }
        }
        return best?.0
    }

    /// 其他看得見的筆畫（修剪、延伸要對著它們找交點）。
    func polylines(excluding ids: Set<String>) -> [[CGPoint]] {
        let drafting = DraftingState.shared
        return allStrokes.filter {
            !ids.contains($0.id) && ($0.layerId == 0 || !drafting.isHidden(layer: $0.layerId, notebookId: notebookId))
        }.map { $0.points.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) } }
    }

    /// 核心給的折線（頁面座標）→ 筆點。直線段補點到每 4 個頁面單位一點（虛線與點畫線的間隔靠它）。
    static func densify(_ items: [FfiPoint], pressure: Float = 0.6) -> [ProPoint] {
        guard let first = items.first else { return [] }
        var pts: [ProPoint] = []
        func add(_ x: Float, _ y: Float) {
            pts.append(ProPoint(x: x, y: y, pressure: pressure, tilt: 0, azimuth: 0, dtUs: 2000, roll: 0))
        }
        add(first.x, first.y)
        for (a, b) in zip(items, items.dropFirst()) {
            let n = max(1, Int((hypot(b.x - a.x, b.y - a.y) / 4).rounded(.up)))
            for k in 1...n {
                let t = Float(k) / Float(n)
                add(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
            }
        }
        return pts
    }

    /// 以 `base` 的筆、顏色、圖層、線型做一筆新的，點換成 `points`（新 id）。
    func derive(from base: ProStroke, points: [FfiPoint]) -> ProStroke {
        var copy = base
        copy.id = UUID().uuidString
        copy.points = Self.densify(points, pressure: base.points.first?.pressure ?? 0.6)
        return copy
    }

    /// 原來的筆畫換成新的一組，**一次復原**。`ids` 找不到的略過；回傳新筆畫的 id。
    @discardableResult
    func replace(ids: Set<String>, with made: [ProStroke]) -> Set<String> {
        let old = ownStrokes.filter { ids.contains($0.id) }
        guard !old.isEmpty || !made.isEmpty else { return [] }
        swapStrokes(remove: old, add: made)
        registerReplaceUndo(old: old, new: made)
        return Set(made.map(\.id))
    }

    /// 加一組已經做好的筆畫（鏡射、陣列的複本），一次復原。
    @discardableResult
    func insert(copies made: [ProStroke]) -> Set<String> {
        guard !made.isEmpty else { return [] }
        ownStrokes.append(contentsOf: made)
        for s in made { setNeedsDisplay(s.bounds) }
        persist()
        registerGroupUndo(inserting: made)
        return Set(made.map(\.id))
    }

    private func swapStrokes(remove old: [ProStroke], add made: [ProStroke]) {
        let gone = Set(old.map(\.id))
        ownStrokes.removeAll { gone.contains($0.id) }
        ownStrokes.append(contentsOf: made)
        for s in old + made { setNeedsDisplay(s.bounds) }
        persist()
    }

    private func registerReplaceUndo(old: [ProStroke], new: [ProStroke]) {
        guard let manager = undoManagerProvider?() else { return }
        manager.registerUndo(withTarget: self) { layer in
            layer.swapStrokes(remove: new, add: old)
            layer.registerReplaceUndo(old: new, new: old)
        }
    }

    // MARK: 改圖層

    /// 把離 `point` 最近的一筆（鎖定／隱藏的圖層除外）改到 `layer`，線型與顏色不動。
    /// 回傳有沒有改到。可復原。
    ///
    /// **別台裝置同步來的筆畫也能改。** 它們在自己的檔案裡（唯讀的外來區），不能就地改；
    /// 做法與「擦掉別台的筆畫」同一套：外來的那一筆記進「已擦除」名單（本機不再顯示），
    /// 同時在自己名下寫一筆新圖層的複本。一次復原兩件事一起還原。
    @discardableResult
    func reassignLayer(near point: CGPoint, to layer: UInt8, radius: CGFloat = 14) -> Bool {
        let own = nearestStroke(in: ownStrokes, to: point, radius: radius)
        let foreign = nearestStroke(in: foreignStrokes, to: point, radius: radius)
        // 兩邊都有就取比較近的；一樣近取自己的。
        if let own, own.distance <= (foreign?.distance ?? .greatestFiniteMagnitude) {
            let before = ownStrokes[own.index]
            guard before.layerId != layer else { return true }
            setLayer(layer, ofStroke: before.id)
            registerLayerUndo(strokeId: before.id, previous: before.layerId)
            return true
        }
        guard let foreign else { return false }
        let original = foreignStrokes[foreign.index]
        guard original.layerId != layer else { return true }
        var copy = original
        copy.id = UUID().uuidString
        copy.layer = layer == 0 ? nil : layer
        removeForeign([original], registersUndo: false)
        ownStrokes.append(copy)
        setNeedsDisplay(copy.bounds)
        persist()
        registerForeignReassignUndo(original: original, copyId: copy.id, target: layer)
        return true
    }

    /// 在 `strokes` 裡找離 `point` 最近、而且圖層可編輯的一筆。
    private func nearestStroke(in strokes: [ProStroke], to point: CGPoint, radius: CGFloat)
        -> (index: Int, distance: CGFloat)? {
        let drafting = DraftingState.shared
        var best: (index: Int, distance: CGFloat)?
        for (i, stroke) in strokes.enumerated()
        where drafting.canEdit(layer: stroke.layerId, notebookId: notebookId) {
            guard stroke.bounds.insetBy(dx: -radius, dy: -radius).contains(point) else { continue }
            let reach = radius + CGFloat(stroke.baseWidth) * 0.5
            // 點到線段的距離（不是取樣點）：吸附出來的直線取樣點很少。
            var nearest = CGFloat.greatestFiniteMagnitude
            let pts = stroke.points
            if pts.count == 1 {
                nearest = hypot(CGFloat(pts[0].x) - point.x, CGFloat(pts[0].y) - point.y)
            }
            for j in 0..<max(0, pts.count - 1) {
                nearest = min(nearest, Self.distance(from: point, toSegment: pts[j], pts[j + 1]))
            }
            if nearest <= reach, nearest < (best?.distance ?? .greatestFiniteMagnitude) { best = (i, nearest) }
        }
        return best
    }

    /// 復原「別台筆畫改圖層」：拿掉自己名下的複本，把外來的原筆畫放回來。
    private func registerForeignReassignUndo(original: ProStroke, copyId: String, target: UInt8) {
        guard let manager = undoManagerProvider?() else { return }
        manager.registerUndo(withTarget: self) { layer in
            if let i = layer.ownStrokes.firstIndex(where: { $0.id == copyId }) {
                let copy = layer.ownStrokes.remove(at: i)
                layer.setNeedsDisplay(copy.bounds)
                layer.persist()
            }
            layer.restoreForeign([original])
            // 重做：再改一次同一筆。
            manager.registerUndo(withTarget: layer) { again in
                again.redoForeignReassign(original: original, to: target, copyId: copyId)
            }
        }
    }

    private func redoForeignReassign(original: ProStroke, to target: UInt8, copyId: String) {
        guard foreignStrokes.contains(where: { $0.id == original.id }) else { return }
        var copy = original
        copy.id = copyId
        copy.layer = target == 0 ? nil : target
        removeForeign([original], registersUndo: false)
        ownStrokes.append(copy)
        setNeedsDisplay(copy.bounds)
        persist()
        registerForeignReassignUndo(original: original, copyId: copyId, target: target)
    }

    private static func distance(from p: CGPoint, toSegment a: ProPoint, _ b: ProPoint) -> CGFloat {
        let ax = CGFloat(a.x), ay = CGFloat(a.y), dx = CGFloat(b.x) - ax, dy = CGFloat(b.y) - ay
        let len2 = dx * dx + dy * dy
        let t = len2 < 1e-6 ? 0 : max(0, min(1, ((p.x - ax) * dx + (p.y - ay) * dy) / len2))
        return hypot(p.x - (ax + dx * t), p.y - (ay + dy * t))
    }

    private func setLayer(_ layer: UInt8, ofStroke id: String) {
        guard let i = ownStrokes.firstIndex(where: { $0.id == id }) else { return }
        ownStrokes[i].layer = layer == 0 ? nil : layer
        setNeedsDisplay(ownStrokes[i].bounds)
        persist()
    }

    private func registerLayerUndo(strokeId: String, previous: UInt8) {
        guard let manager = undoManagerProvider?() else { return }
        manager.registerUndo(withTarget: self) { view in
            let current = view.ownStrokes.first(where: { $0.id == strokeId })?.layerId ?? 0
            view.setLayer(previous, ofStroke: strokeId)
            view.registerLayerUndo(strokeId: strokeId, previous: current)
        }
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
    enum Mode { case draw, erase, reassign, marker, tool }
    enum ToolPhase { case began, moved, ended, cancelled }

    var mode: Mode = .draw
    /// 手指是否能畫。政策是 `.pencilOnly` 時只收 Apple Pencil。
    var allowsFingerDrawing: () -> Bool = { true }
    weak var layerView: ProInkLayerView?
    var tool: () -> ToolKind? = { nil }
    var color: () -> [UInt8] = { [0, 0, 0, 255] }
    var width: () -> Float = { 4 }
    var eraserRadius: () -> CGFloat = { 10 }
    /// 製圖：這一筆要寫進的圖層與線型。一般筆刷都是 0。
    var drawLayer: () -> UInt8 = { 0 }
    var drawLineType: () -> UInt8 = { 0 }
    /// 長按吸附：回傳角度鎖定（度，0 = 不鎖）；`nil` = 沒開吸附。
    var snapStep: () -> Float? = { nil }
    /// 改圖層模式要改到哪一層。
    var reassignTarget: () -> UInt8 = { 0 }
    /// 步驟編號模式：點哪裡，通知哪裡（頁面座標）。
    var onMarker: ((CGPoint) -> Void)?
    /// 吸附成功時通知（給觸覺回饋與提示）。
    var onSnapped: ((FfiDraftSnapKind) -> Void)?
    /// 圖學工具模式：觸控的每個階段與位置（頁面座標）。
    var onToolTouch: ((ToolPhase, CGPoint) -> Void)?
    private var lastToolPoint = CGPoint.zero
    /// 手指落在尺的身體上（不是靠邊的地方）：這一次拖曳是在搬尺，不是在畫。
    private var draggingInstrument = false
    /// 手指落在量角器的刻度帶：這一次拖曳是在讀角度。
    private var readingInstrument = false
    private var lastInstrumentPoint = CGPoint.zero

    private var holdTimer: Timer?
    private var holdAnchor: CGPoint = .zero
    private static let holdDelay: TimeInterval = 0.55
    private static let holdSlop: CGFloat = 4

    private var tracked: UITouch?
    private var lastTimestamp: TimeInterval = 0
    private var erasePath: [CGPoint] = []

    /// 為真時（打字模式）：筆要真的移動超過門檻才開始落墨。輕點不留墨點。
    var deferUntilMoved = false
    private var pendingBegin: (point: ProPoint, location: CGPoint)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let layerView else { state = .failed; return }
        if tracked != nil {
            // 第二根手指：這不是書寫，是捲動或縮放。
            cancelCurrent()
            state = .cancelled
            return
        }
        // 圖學工具（標註…）、改圖層、步驟編號都是刻意的點選，不是書寫：不受「手指能不能畫」的掌拒政策限制 ——
        // 政策擋的是手掌誤觸留下墨跡，而這些每一步都要使用者明確點下去。
        // （改圖層與步驟編號原本沒列進來：用過 Apple Pencil 之後政策變成 `.pencilOnly`，
        // 手指點下去整個被擋掉 —— 「移到圖層」看起來完全沒作用。）
        guard touches.count == 1, let touch = touches.first,
              touch.type == .pencil || allowsFingerDrawing() || mode == .tool
                  || mode == .reassign || mode == .marker
        else { state = .failed; return }

        tracked = touch
        lastTimestamp = touch.timestamp
        let point = makePoint(touch, in: layerView, dt: 0)
        if mode == .draw, let model = DraftingState.shared.instrument {
            let here = CGPoint(x: CGFloat(point.x), y: CGFloat(point.y))
            let band = 14 / max(layerView.transform.a, 0.25)
            if model.isReadingZone(here), model.nearestEdge(to: here, band: band) == nil {
                readingInstrument = true
                DraftingState.shared.readInstrument(at: here)
                state = .began
                return
            }
            if model.containsBody(here), model.nearestEdge(to: here, band: band) == nil {
                draggingInstrument = true
                lastInstrumentPoint = here
                state = .began
                return
            }
        }
        if deferUntilMoved && mode == .draw {
            guard tool() != nil else { state = .failed; return }
            pendingBegin = (point, touch.location(in: layerView))
            return
        }
        state = .began
        switch mode {
        case .draw:
            guard let tool = tool() else { state = .failed; return }
            beginDrawing(tool: tool, at: point, in: layerView)
        case .erase:
            erasePath = [CGPoint(x: CGFloat(point.x), y: CGFloat(point.y))]
            layerView.erase(along: erasePath, radius: eraserRadius())
        case .reassign:
            let target = reassignTarget()
            let done = layerView.reassignLayer(
                near: CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)), to: target)
            let drafting = DraftingState.shared
            if done {
                let name = drafting.layers.first { $0.id == target }
                    .map { L10n.t($0.nameKey) } ?? ""
                drafting.reassignResult = L10n.f("draft_reassigned", name)
            } else {
                drafting.reassignResult = L10n.t("draft_reassign_miss")
            }
        case .marker:
            onMarker?(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
        case .tool:
            lastToolPoint = CGPoint(x: CGFloat(point.x), y: CGFloat(point.y))
            onToolTouch?(.began, lastToolPoint)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let layerView, let touch = tracked, touches.contains(touch) else { return }
        if readingInstrument {
            DraftingState.shared.readInstrument(at: touch.preciseLocation(in: layerView))
            state = .changed
            return
        }
        if draggingInstrument {
            let here = touch.preciseLocation(in: layerView)
            DraftingState.shared.moveInstrument(by: CGSize(width: here.x - lastInstrumentPoint.x, height: here.y - lastInstrumentPoint.y))
            lastInstrumentPoint = here
            state = .changed
            return
        }
        if let pending = pendingBegin {
            let here = touch.location(in: layerView)
            let moved = hypot(here.x - pending.location.x, here.y - pending.location.y)
            guard moved >= EditorCanvasInputPolicy.pencilTapMaxDistance / 2 else { return }
            guard let tool = tool() else { pendingBegin = nil; state = .failed; return }
            beginDrawing(tool: tool, at: pending.point, in: layerView)
            pendingBegin = nil
            state = .began
        }
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
            if let last = points.last { rearmHold(at: CGPoint(x: CGFloat(last.x), y: CGFloat(last.y))) }
        case .erase:
            let path = points.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
            erasePath.append(contentsOf: path)
            layerView.erase(along: path, radius: eraserRadius())
        case .reassign, .marker:
            break
        case .tool:
            if let last = points.last {
                lastToolPoint = CGPoint(x: CGFloat(last.x), y: CGFloat(last.y))
                onToolTouch?(.moved, lastToolPoint)
            }
        }
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = tracked, touches.contains(touch) else { return }
        if draggingInstrument || readingInstrument {
            draggingInstrument = false
            readingInstrument = false
            tracked = nil
            state = .ended
            return
        }
        if pendingBegin != nil {
            // 沒動過：這是輕點，不是筆畫。
            pendingBegin = nil
            tracked = nil
            state = .failed
            return
        }
        holdTimer?.invalidate()
        if mode == .draw { layerView?.endStroke() }
        if mode == .tool { onToolTouch?(.ended, lastToolPoint) }
        tracked = nil
        erasePath = []
        state = .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = tracked, touches.contains(touch) else { return }
        if pendingBegin != nil {
            pendingBegin = nil
            tracked = nil
            state = .failed
            return
        }
        cancelCurrent()
        state = .cancelled
    }

    override func reset() {
        draggingInstrument = false
        readingInstrument = false
        holdTimer?.invalidate()
        tracked = nil
        erasePath = []
        pendingBegin = nil
    }

    private func cancelCurrent() {
        draggingInstrument = false
        readingInstrument = false
        holdTimer?.invalidate()
        if mode == .tool { onToolTouch?(.cancelled, lastToolPoint) }
        if mode == .draw { layerView?.cancelStroke() }
        tracked = nil
        erasePath = []
    }

    /// 開始一筆：帶上目前的圖層與線型；圖層被鎖住就不畫（畫了也看不到）。
    private func beginDrawing(tool: ToolKind, at point: ProPoint, in layerView: ProInkLayerView) {
        let layer = drawLayer()
        let drafting = DraftingState.shared
        if layer != 0 {
            if drafting.isLocked(layer: layer, notebookId: layerView.notebookId) {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                return
            }
            // 畫在隱藏的圖層上：自動把它顯示出來，不然使用者畫了卻什麼都沒有。
            drafting.ensureVisible(layer: layer, notebookId: layerView.notebookId)
        }
        layerView.beginStroke(tool: tool, color: color(), width: width(), at: point,
                              layer: layer, lineType: drawLineType())
        rearmHold(at: CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
    }

    /// 手停住不動 0.55 秒就吸附；一動就重新計時。
    private func rearmHold(at location: CGPoint) {
        guard snapStep() != nil, layerView?.isSnapped == false else { return }
        if hypot(location.x - holdAnchor.x, location.y - holdAnchor.y) < Self.holdSlop, holdTimer?.isValid == true { return }
        holdAnchor = location
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: Self.holdDelay, repeats: false) { [weak self] _ in
            guard let self, let step = self.snapStep(), let view = self.layerView else { return }
            if let kind = view.snapLiveStroke(angleStep: step) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                self.onSnapped?(kind)
            }
        }
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
