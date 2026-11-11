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
    /// 本機身分。**換掉 `id` 就是做了一筆新的筆畫**（複本、鏡射、陣列），所以 `coreId` 一併歸零 ——
    /// 複本若沿用原本的套件身分，匯出時兩筆會寫成同一個 id，擦掉其中一筆另一筆也跟著消失。
    var id: String = UUID().uuidString { didSet { if id != oldValue { coreId = nil } } }
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
    /// 寫進套件時用的**身分**；`nil` 表示就用 `id`。
    ///
    /// `id` 是這台裝置上復原／重做、選取認的身分，不能變。但筆畫一旦被匯出，它在套件裡的 id
    /// 就是別台裝置對它寫墓碑（擦掉、改圖層）時指的東西 —— 墓碑一旦上傳就**不能撤銷**。
    /// 所以已經匯出過的筆畫被擦掉又復原、被搬動或改圖層時，要換一個新的套件身分
    /// （`coreId`），本機的 `id` 照舊。
    var coreId: String? = nil

    /// 套件裡這一筆的身分（小寫，與核心一致）。
    var packageId: String { (coreId ?? id).lowercased() }

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
        // id 用核心的筆畫 id：別台的筆畫在本機就以同一個身分出現，擦掉／改圖層才寫得出對得上的墓碑。
        self.init(
            id: full.id.lowercased(),
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
        case "brush": return .brush
        case "fineliner": return .fineliner
        case "charcoal": return .charcoal
        case "crayon": return .crayon
        case "airbrush": return .airbrush
        case "oilpaint": return .oilPaint
        case "calligraphy": return .calligraphy
        // ADR-0015 階段 5：原本由 PencilKit 畫的六支筆，改由核心筆點陣（`pens.rs`）算繪。
        case "pen": return .fountainPen
        case "ballpoint": return .ballPoint
        case "pencil": return .pencil
        case "marker": return .marker
        case "highlighter": return .highlighter
        case "watercolor": return .watercolor
        default: return nil
        }
    }

    static func name(of kind: ToolKind) -> String? {
        switch kind {
        case .brush: return "brush"
        case .fineliner: return "fineliner"
        case .charcoal: return "charcoal"
        case .crayon: return "crayon"
        case .airbrush: return "airbrush"
        case .oilPaint: return "oilpaint"
        case .calligraphy: return "calligraphy"
        case .fountainPen: return "pen"
        case .ballPoint: return "ballpoint"
        case .pencil: return "pencil"
        case .marker: return "marker"
        case .highlighter: return "highlighter"
        case .watercolor: return "watercolor"
        }
    }

    /// 工具列的「粗細」換成這支筆的基準寬度。
    ///
    /// 原本 PencilKit 的各支筆各有倍率與下限（鋼筆 ×1.1、原子筆 ×0.65、麥克筆 ×2.8……），
    /// 換成自繪引擎之後沿用，使用者換版本後同一個粗細看起來差不多。
    static func baseWidth(for tool: EditorToolType, strokeWidth: CGFloat) -> CGFloat {
        // 係數表在核心（`tool_base_width`），與 Android 共用：同一個數字在兩個平台畫出一樣粗。
        let kind: ToolKind
        switch tool {
        case .pen: kind = .fountainPen
        case .ballpoint: kind = .ballPoint
        case .fineliner: kind = .fineliner
        case .pencil: kind = .pencil
        case .calligraphy: kind = .calligraphy
        case .charcoal: kind = .charcoal
        case .crayon: kind = .crayon
        case .oilpaint: kind = .oilPaint
        case .brush: kind = .brush
        case .watercolor: kind = .watercolor
        case .airbrush: kind = .airbrush
        case .marker: kind = .marker
        case .highlighter: kind = .highlighter
        default: return max(1.0, strokeWidth) * 1.2
        }
        return CGFloat(toolBaseWidth(tool: kind, size: Float(strokeWidth)))
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
/// 專業筆畫的**同步帳本**，每頁一份。
///
/// # 為什麼需要
///
/// 筆畫檔只追加（見 `StrokeDelta`）：同步看的是檔案大小，**只有變大的檔案才會傳出去**。
/// 擦掉、搬動、改圖層如果只是從這台的筆畫檔裡拿掉，檔案變小，雲端那份較大的舊檔反而會被下載回來 ——
/// 別台看不到變化，原作者那台也不知道線被動過。
///
/// 所以「動過」要變成**追加的墓碑**：匯出時把被擦掉的筆畫連同 `Remove(id)` 一起寫出
/// （自己的筆畫寫 `Add` + `Remove`，別台的只寫 `Remove`），檔案只會變大。
/// 這份帳本記的就是「還要寫墓碑的 id」，以及上一次匯出寫出了哪些自己的筆畫
/// （匯入時用它認出「這一筆是被別台擦掉的」）。
struct ProInkLedger: Codable, Equatable, Sendable {
    struct Retired: Codable, Equatable, Sendable {
        /// 套件裡的筆畫 id（小寫）。
        var coreId: String
        /// 自己的筆畫：匯出時要連 `Add` 一起寫，檔案才不會變小。別台的筆畫為 `nil`（只寫墓碑）。
        var stroke: ProStroke?
        /// 墓碑已經寫進套件（之後就不能再讓同一個 id 復活）。
        var exported: Bool
        /// 別台的筆畫被擦掉時它的內容指紋。升級前匯入的別台筆畫，本機認得的 id 不是核心的 id，
        /// 匯出時改用內容指紋到套件裡找出真正的 id。
        var contentKey: String? = nil
        /// 用內容指紋額外找到的核心 id（墓碑要一併寫）。`nil` = 還沒找過。
        var extraIds: [String]? = nil
    }

    /// 擦掉的一筆 PencilKit 筆畫（自己的）。連資料一起留著：匯出時要寫 `Add` 再寫 `Remove`。
    struct PKRetired: Codable, Equatable, Sendable {
        var id: String
        /// 只含這一筆的 `PKDrawing` 資料。
        var drawing: Data
    }

    var retired: [Retired] = []
    /// 上一次匯出寫出的、自己的活筆畫的套件 id。
    var exportedIds: [String] = []

    /// 帳本格式版本。< 2 = 升級前：這一頁的筆畫還沒用穩定身分寫出過，匯出要強制重寫並讓檔案變大。
    var schema = 0
    /// 擦掉的自己的 PencilKit 筆畫（見 `PKInkSync`）。**永遠留著**：每次匯出都整個重寫自己的筆畫檔，
    /// 少寫一筆墓碑，別台下載到新檔就會讓那一筆復活。
    var pkRetiredOwn: [PKRetired] = []
    /// 別台的筆畫被這台擦掉時寫出的墓碑 id（PencilKit 與升級前的專業筆畫）。同樣永遠留著。
    var foreignTombstones: [String] = []
    /// 每個「內容 × 第幾筆」被擦掉過幾次。套件身分含這個數字：擦掉又復原的筆畫要拿新的身分，
    /// 已上傳的墓碑撤不掉。
    var pkGen: [String: Int] = [:]

    var isEmpty: Bool {
        retired.isEmpty && exportedIds.isEmpty && schema == 0 && pkRetiredOwn.isEmpty
            && foreignTombstones.isEmpty && pkGen.isEmpty
    }

    init(retired: [Retired] = [], exportedIds: [String] = []) {
        self.retired = retired
        self.exportedIds = exportedIds
    }

    // 舊版帳本的 JSON 沒有後來加的欄位，一律用預設值讀進來。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        retired = try c.decodeIfPresent([Retired].self, forKey: .retired) ?? []
        exportedIds = try c.decodeIfPresent([String].self, forKey: .exportedIds) ?? []
        schema = try c.decodeIfPresent(Int.self, forKey: .schema) ?? 0
        pkRetiredOwn = try c.decodeIfPresent([PKRetired].self, forKey: .pkRetiredOwn) ?? []
        foreignTombstones = try c.decodeIfPresent([String].self, forKey: .foreignTombstones) ?? []
        pkGen = try c.decodeIfPresent([String: Int].self, forKey: .pkGen) ?? [:]
    }

    private enum Keys: String, CodingKey {
        case retired, exportedIds, schema, pkRetiredOwn, foreignTombstones, pkGen
    }
}

enum ProInkStore {
    /// 帳本與筆畫快取的讀改寫要互斥：編輯器（主執行緒）與匯出（背景）都會改它。
    /// 使用 NSRecursiveLock 避免 updateLedger 閉包內部再次呼叫 load 等方法時發生同一執行緒死鎖。
    private nonisolated static let ledgerLock = NSRecursiveLock()
    // profile-scope: profile 以完整檔案路徑（含設定檔專屬目錄）為鍵，不同設定檔不會共用同一項目
    private nonisolated(unsafe) static var strokesCache: [String: (modDate: Date?, strokes: [ProStroke])] = [:]
    // profile-scope: profile 以完整檔案路徑前綴為鍵，快取修改時間避免每次 SwiftUI body 重算都觸發磁碟 stat 系統呼叫
    private nonisolated(unsafe) static var modifiedCache: [String: Date?] = [:]
    // 記憶體帳本快取，避免每筆抬筆同步從磁碟讀取與解碼 JSON
    private nonisolated(unsafe) static var ledgerCache: [String: ProInkLedger] = [:]

    private nonisolated static func pageCacheKey(_ directory: URL, _ notebookId: String, _ page: Int) -> String {
        "\(directory.path)/\(notebookId.lowercased())_p\(page)"
    }

    nonisolated static func invalidateModifiedCache(notebookId: String? = nil) {
        ledgerLock.lock()
        if let id = notebookId?.lowercased() {
            modifiedCache = modifiedCache.filter { !$0.key.contains("/\(id)_p") }
            ledgerCache = ledgerCache.filter { !$0.key.contains("/\(id)_p") }
        } else {
            modifiedCache.removeAll()
            ledgerCache.removeAll()
        }
        ledgerLock.unlock()
    }

    /// 這本筆記的逐頁檔案換了頁碼（搬頁、插入、刪除頁）：以頁碼為鍵的記憶體快取全部作廢。
    ///
    /// 帳本、檔案時間與版本號都以「頁碼」為鍵，檔案改名之後它們還指著舊頁碼的內容 ——
    /// 搬到第 1 頁的那一頁會套上原本第 1 頁的擦除帳本。筆畫快取以路徑＋修改時間比對，
    /// 而改名保留修改時間，時間解析度粗的檔案系統上可能誤判命中，一併清掉。
    /// 版本號不歸零而是 +1：歸零會讓縮圖快取鍵退回某個舊值。
    nonisolated static func invalidatePageCaches(notebookId: String) {
        let marker = "/\(notebookId.lowercased())_p"
        ledgerLock.lock()
        modifiedCache = modifiedCache.filter { !$0.key.contains(marker) }
        ledgerCache = ledgerCache.filter { !$0.key.contains(marker) }
        strokesCache = strokesCache.filter { !$0.key.lowercased().contains(marker) }
        for key in revisions.keys where key.contains(marker) { revisions[key, default: 0] += 1 }
        ledgerLock.unlock()
    }

    private nonisolated static func ledgerURL(_ directory: URL, _ notebookId: String, _ page: Int) -> URL {
        directory.appending(path: "\(notebookId)_p\(page).proink-ledger.json")
    }

    nonisolated static func loadLedger(in directory: URL, notebookId: String, page: Int) -> ProInkLedger {
        ledgerLock.lock(); defer { ledgerLock.unlock() }
        return readLedger(directory, notebookId, page)
    }

    private nonisolated static func readLedger(_ directory: URL, _ notebookId: String, _ page: Int) -> ProInkLedger {
        let key = pageCacheKey(directory, notebookId, page)
        if let hit = ledgerCache[key] { return hit }
        guard let data = try? Data(contentsOf: ledgerURL(directory, notebookId, page)),
              let ledger = try? JSONDecoder().decode(ProInkLedger.self, from: data)
        else {
            let empty = ProInkLedger()
            ledgerCache[key] = empty
            return empty
        }
        ledgerCache[key] = ledger
        return ledger
    }

    /// 讀、改、寫一次完成。回傳 `body` 的結果。
    @discardableResult
    nonisolated static func updateLedger<T>(
        in directory: URL, notebookId: String, page: Int, _ body: (inout ProInkLedger) -> T
    ) -> T {
        ledgerLock.lock(); defer { ledgerLock.unlock() }
        let key = pageCacheKey(directory, notebookId, page)
        var ledger = readLedger(directory, notebookId, page)
        let before = ledger
        let result = body(&ledger)
        if ledger != before {
            ledgerCache[key] = ledger
            let file = ledgerURL(directory, notebookId, page)
            if ledger.isEmpty {
                try? FileManager.default.removeItem(at: file)
            } else if let data = try? JSONEncoder().encode(ledger) {
                try? data.write(to: file, options: .atomic)
            }
            modifiedCache.removeValue(forKey: key)
        }
        return result
    }

    /// 還有墓碑沒寫進套件（匯出要判成「有變動」）。
    nonisolated static func hasUnexportedRetirements(in directory: URL, notebookId: String, page: Int) -> Bool {
        loadLedger(in: directory, notebookId: notebookId, page: page).retired.contains { !$0.exported }
    }

    private nonisolated static func url(_ directory: URL, _ notebookId: String, _ page: Int, foreign: Bool) -> URL {
        directory.appending(path: "\(notebookId)_p\(page).\(foreign ? "proink-foreign" : "proink").json")
    }

    private nonisolated static func binURL(for jsonURL: URL) -> URL {
        jsonURL.appendingPathExtension("bin")
    }

    /// 緊湊二進位格式序列化（KPB1），避免數萬筆畫開啟時解析數十 MB JSON 文字造成秒級阻塞。
    private nonisolated static func encodeBinary(_ strokes: [ProStroke], jsonByteSize: UInt64) -> Data {
        var data = Data()
        data.reserveCapacity(16 + strokes.count * 128)
        let magic: UInt32 = 0x3142504B // "KPB1"
        var leMagic = magic.littleEndian
        var leJsonSize = jsonByteSize.littleEndian
        var leCount = UInt32(strokes.count).littleEndian
        withUnsafeBytes(of: &leMagic) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &leJsonSize) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &leCount) { data.append(contentsOf: $0) }

        func appendString(_ s: String) {
            let utf8 = Array(s.utf8)
            var len = UInt16(min(utf8.count, Int(UInt16.max))).littleEndian
            withUnsafeBytes(of: &len) { data.append(contentsOf: $0) }
            data.append(contentsOf: utf8.prefix(Int(UInt16.max)))
        }

        for s in strokes {
            appendString(s.id)
            appendString(s.coreId ?? "")
            appendString(s.tool)
            appendString(s.blendMode)
            let c0 = s.colorRGBA.count > 0 ? s.colorRGBA[0] : 0
            let c1 = s.colorRGBA.count > 1 ? s.colorRGBA[1] : 0
            let c2 = s.colorRGBA.count > 2 ? s.colorRGBA[2] : 0
            let c3 = s.colorRGBA.count > 3 ? s.colorRGBA[3] : 255
            data.append(contentsOf: [c0, c1, c2, c3])
            var bw = s.baseWidth.bitPattern.littleEndian
            withUnsafeBytes(of: &bw) { data.append(contentsOf: $0) }
            if let l = s.layer {
                data.append(contentsOf: [1, l])
            } else {
                data.append(contentsOf: [0, 0])
            }
            if let lt = s.lineType {
                data.append(contentsOf: [1, lt])
            } else {
                data.append(contentsOf: [0, 0])
            }
            var ptCount = UInt32(s.points.count).littleEndian
            withUnsafeBytes(of: &ptCount) { data.append(contentsOf: $0) }
            for p in s.points {
                var x = p.x.bitPattern.littleEndian
                var y = p.y.bitPattern.littleEndian
                var pr = p.pressure.bitPattern.littleEndian
                var ti = p.tilt.bitPattern.littleEndian
                var az = p.azimuth.bitPattern.littleEndian
                var dt = p.dtUs.littleEndian
                var ro = p.roll.bitPattern.littleEndian
                withUnsafeBytes(of: &x) { data.append(contentsOf: $0) }
                withUnsafeBytes(of: &y) { data.append(contentsOf: $0) }
                withUnsafeBytes(of: &pr) { data.append(contentsOf: $0) }
                withUnsafeBytes(of: &ti) { data.append(contentsOf: $0) }
                withUnsafeBytes(of: &az) { data.append(contentsOf: $0) }
                withUnsafeBytes(of: &dt) { data.append(contentsOf: $0) }
                withUnsafeBytes(of: &ro) { data.append(contentsOf: $0) }
            }
        }
        return data
    }

    private nonisolated static func decodeBinary(_ data: Data, expectedJsonByteSize: UInt64) -> [ProStroke]? {
        guard data.count >= 16 else { return nil }
        return data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> [ProStroke]? in
            guard let base = raw.baseAddress else { return nil }
            var offset = 0
            func readU32() -> UInt32? {
                guard offset + 4 <= raw.count else { return nil }
                let v = base.advanced(by: offset).assumingMemoryBound(to: UInt32.self).pointee
                offset += 4
                return UInt32(littleEndian: v)
            }
            func readU64() -> UInt64? {
                guard offset + 8 <= raw.count else { return nil }
                var v: UInt64 = 0
                memcpy(&v, base.advanced(by: offset), 8)
                offset += 8
                return UInt64(littleEndian: v)
            }
            func readU16() -> UInt16? {
                guard offset + 2 <= raw.count else { return nil }
                var v: UInt16 = 0
                memcpy(&v, base.advanced(by: offset), 2)
                offset += 2
                return UInt16(littleEndian: v)
            }
            func readString() -> String? {
                guard let len = readU16() else { return nil }
                let count = Int(len)
                guard offset + count <= raw.count else { return nil }
                let str = String(
                    decoding: UnsafeBufferPointer(
                        start: base.advanced(by: offset).assumingMemoryBound(to: UInt8.self),
                        count: count
                    ),
                    as: UTF8.self
                )
                offset += count
                return str
            }
            guard let magic = readU32(), magic == 0x3142504B,
                  let jsonSize = readU64(), jsonSize == expectedJsonByteSize,
                  let strokeCount = readU32()
            else { return nil }

            var strokes: [ProStroke] = []
            strokes.reserveCapacity(Int(strokeCount))
            for _ in 0..<strokeCount {
                guard let id = readString(),
                      let coreIdRaw = readString(),
                      let tool = readString(),
                      let blendMode = readString(),
                      offset + 12 <= raw.count
                else { return nil }
                let ptr = base.advanced(by: offset).assumingMemoryBound(to: UInt8.self)
                let rgba: [UInt8] = [ptr[0], ptr[1], ptr[2], ptr[3]]
                offset += 4
                guard let bwBits = readU32() else { return nil }
                let baseWidth = Float(bitPattern: bwBits)
                let p2 = base.advanced(by: offset).assumingMemoryBound(to: UInt8.self)
                let hasLayer = p2[0] != 0
                let layerVal = p2[1]
                let hasLineType = p2[2] != 0
                let lineTypeVal = p2[3]
                offset += 4
                guard let ptCount = readU32() else { return nil }
                let nPts = Int(ptCount)
                guard offset + nPts * 28 <= raw.count else { return nil }
                var points: [ProPoint] = []
                points.reserveCapacity(nPts)
                for _ in 0..<nPts {
                    let x = Float(bitPattern: readU32()!)
                    let y = Float(bitPattern: readU32()!)
                    let pr = Float(bitPattern: readU32()!)
                    let ti = Float(bitPattern: readU32()!)
                    let az = Float(bitPattern: readU32()!)
                    let dt = readU32()!
                    let ro = Float(bitPattern: readU32()!)
                    points.append(ProPoint(x: x, y: y, pressure: pr, tilt: ti, azimuth: az, dtUs: dt, roll: ro))
                }
                strokes.append(ProStroke(
                    id: id,
                    tool: tool,
                    colorRGBA: rgba,
                    baseWidth: baseWidth,
                    blendMode: blendMode,
                    points: points,
                    layer: hasLayer ? layerVal : nil,
                    lineType: hasLineType ? lineTypeVal : nil,
                    coreId: coreIdRaw.isEmpty ? nil : coreIdRaw
                ))
            }
            return strokes
        }
    }

    nonisolated static func load(in directory: URL, notebookId: String, page: Int, foreign: Bool = false) -> [ProStroke] {
        let file = url(directory, notebookId, page, foreign: foreign)
        let key = file.path
        // 還在排隊寫檔的那一份才是最新的（磁碟上可能是舊的，甚至還沒有檔案）。
        ledgerLock.lock()
        if let pending = pendingWrites[key] {
            ledgerLock.unlock()
            return pending.strokes
        }
        ledgerLock.unlock()
        let resValues = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let modDate = resValues?.contentModificationDate
        let fileSize = UInt64(resValues?.fileSize ?? 0)
        ledgerLock.lock()
        if modDate == nil {
            strokesCache.removeValue(forKey: key)
            ledgerLock.unlock()
            return []
        }
        if let cached = strokesCache[key], cached.modDate == modDate {
            ledgerLock.unlock()
            return cached.strokes
        }
        ledgerLock.unlock()
        let binFile = binURL(for: file)
        if fileSize > 0,
           let binData = try? Data(contentsOf: binFile, options: .mappedIfSafe),
           let fastStrokes = decodeBinary(binData, expectedJsonByteSize: fileSize) {
            ledgerLock.lock()
            strokesCache[key] = (modDate, fastStrokes)
            ledgerLock.unlock()
            return fastStrokes
        }
        guard let data = try? Data(contentsOf: file),
              let strokes = try? JSONDecoder().decode([ProStroke].self, from: data)
        else { return [] }
        let actualSize = UInt64(data.count)
        ledgerLock.lock()
        strokesCache[key] = (modDate, strokes)
        ledgerLock.unlock()
        if strokes.count > 16 {
            writeQueue.async {
                let binData = encodeBinary(strokes, jsonByteSize: actualSize)
                try? binData.write(to: binFile, options: .atomic)
            }
        }
        return strokes
    }

    nonisolated static func save(_ strokes: [ProStroke], in directory: URL, notebookId: String, page: Int, foreign: Bool = false) {
        let file = url(directory, notebookId, page, foreign: foreign)
        // 與排隊中的背景寫入走同一條佇列：否則較舊的那一份可能晚一步寫完、蓋掉這一份。
        writeQueue.sync {
            ledgerLock.lock()
            pendingWorkItems[file.path]?.cancel()
            pendingWorkItems.removeValue(forKey: file.path)
            pendingWrites.removeValue(forKey: file.path)
            ledgerLock.unlock()
            write(strokes, to: file, directory: directory, notebookId: notebookId, page: page)
        }
        bumpRevision(directory, notebookId, page)
    }

    /// 畫完一筆就要存，但**不能在主執行緒上等**：整頁筆畫編成 JSON 的成本隨頁面上的筆畫數增加，
    /// 寫得越多、每一次抬筆卡得越久 —— 下一筆的開頭就跟著延遲（實機回報「後面的字出現得越來越慢」）。
    ///
    /// 這裡只把最新的一份記在記憶體（`load` 立刻讀得到），編碼與寫檔交給背景序列佇列並去抖動 1.2 秒；
    /// 連續運筆期間完全不執行整頁 JSON 序列化與磁碟 I/O，停筆或換頁／退背景時只寫最後一份。
    nonisolated static func saveDeferred(_ strokes: [ProStroke], in directory: URL, notebookId: String, page: Int) {
        let file = url(directory, notebookId, page, foreign: false)
        let key = file.path
        let pKey = pageCacheKey(directory, notebookId, page)
        let now = Date()
        ledgerLock.lock()
        pendingGeneration &+= 1
        let generation = pendingGeneration
        pendingWrites[key] = (generation, strokes, file, directory, notebookId, page)
        pendingModifiedDates[pKey] = now
        modifiedCache[pKey] = now
        revisions[pKey, default: 0] += 1
        pendingWorkItems[key]?.cancel()
        let work = DispatchWorkItem {
            ledgerLock.lock()
            pendingWorkItems.removeValue(forKey: key)
            guard let latest = pendingWrites[key] else {
                ledgerLock.unlock()
                return   // 已經被後面那一次（或同步存檔）寫掉了
            }
            ledgerLock.unlock()
            write(latest.strokes, to: latest.file, directory: latest.directory, notebookId: latest.notebookId, page: latest.page)
            ledgerLock.lock()
            if pendingWrites[key]?.generation == latest.generation {
                pendingWrites.removeValue(forKey: key)
                pendingModifiedDates.removeValue(forKey: pKey)
            }
            ledgerLock.unlock()
        }
        pendingWorkItems[key] = work
        ledgerLock.unlock()
        writeQueue.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    /// 等排隊中的寫入做完（進背景、要讀磁碟上的檔案之前）。不可在寫入佇列上呼叫。
    nonisolated static func flushPendingWrites() {
        writeQueue.sync {
            ledgerLock.lock()
            let allPending = Array(pendingWrites.values)
            for item in pendingWorkItems.values { item.cancel() }
            pendingWorkItems.removeAll()
            pendingWrites.removeAll()
            pendingModifiedDates.removeAll()
            ledgerLock.unlock()
            for item in allPending {
                write(item.strokes, to: item.file, directory: item.directory, notebookId: item.notebookId, page: item.page)
            }
        }
    }

    /// 這本筆記還有沒有排隊中、尚未寫出的自繪筆畫存檔（只查記憶體，不碰磁碟）。
    ///
    /// 頁面結構變動（插入、刪除、搬頁）會改逐頁檔案的頁碼：排隊中的存檔是照**舊頁碼**排的，
    /// 搬完檔案才寫出去，就會把原本那一頁的筆畫寫進新插進來的那一頁（協同時實際發生過：
    /// 對方新增一頁的同時這台剛寫完一筆，多出一頁「只有筆跡、沒有文字方塊」的複本）。
    nonisolated static func hasPendingWrites(notebookId: String) -> Bool {
        let id = notebookId.lowercased()
        ledgerLock.lock(); defer { ledgerLock.unlock() }
        return pendingWrites.values.contains { $0.notebookId.lowercased() == id }
    }

    private nonisolated static func hasPendingWrite(_ directory: URL, _ notebookId: String, _ page: Int) -> Bool {
        let key = url(directory, notebookId, page, foreign: false).path
        ledgerLock.lock(); defer { ledgerLock.unlock() }
        return pendingWrites[key] != nil
    }

    private nonisolated static let writeQueue = DispatchQueue(label: "kairumo.proink.writer", qos: .utility)
    // profile-scope: profile 以完整檔案路徑為鍵，不同設定檔不會共用同一項目
    private nonisolated(unsafe) static var pendingWrites: [String: (generation: UInt64, strokes: [ProStroke], file: URL, directory: URL, notebookId: String, page: Int)] = [:]
    // profile-scope: profile 以完整檔案路徑為鍵，管理去抖動延遲寫入工作項目
    private nonisolated(unsafe) static var pendingWorkItems: [String: DispatchWorkItem] = [:]
    // profile-scope: profile 以完整檔案路徑前綴為鍵，記錄待寫入筆畫的記憶體修改時間
    private nonisolated(unsafe) static var pendingModifiedDates: [String: Date] = [:]
    private nonisolated(unsafe) static var pendingGeneration: UInt64 = 0
    // profile-scope: profile 以完整檔案路徑前綴為鍵
    private nonisolated(unsafe) static var revisions: [String: Int] = [:]

    /// 這一頁專業筆畫（自己的、別台的、已擦除名單）的版本號：任何一份存檔就 +1。
    /// 縮圖的快取鍵要有它 —— 原本只看 PencilKit 的筆畫，畫或擦專業筆刷時縮圖完全不換。
    nonisolated static func revision(in directory: URL, notebookId: String, page: Int) -> Int {
        ledgerLock.lock(); defer { ledgerLock.unlock() }
        return revisions[pageCacheKey(directory, notebookId, page)] ?? 0
    }

    private nonisolated static func bumpRevision(_ directory: URL, _ notebookId: String, _ page: Int) {
        ledgerLock.lock()
        revisions[pageCacheKey(directory, notebookId, page), default: 0] += 1
        ledgerLock.unlock()
    }

    /// 只在寫入佇列上呼叫。
    private nonisolated static func write(_ strokes: [ProStroke], to file: URL, directory: URL, notebookId: String, page: Int) {
        let key = file.path
        let binFile = binURL(for: file)
        if strokes.isEmpty {
            try? FileManager.default.removeItem(at: file)
            try? FileManager.default.removeItem(at: binFile)
            ledgerLock.lock()
            strokesCache.removeValue(forKey: key)
            modifiedCache.removeValue(forKey: pageCacheKey(directory, notebookId, page))
            ledgerLock.unlock()
            return
        }
        guard let data = try? JSONEncoder().encode(strokes) else { return }
        try? data.write(to: file, options: .atomic)
        let binData = encodeBinary(strokes, jsonByteSize: UInt64(data.count))
        try? binData.write(to: binFile, options: .atomic)
        let modDate = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        ledgerLock.lock()
        strokesCache[key] = (modDate, strokes)
        modifiedCache.removeValue(forKey: pageCacheKey(directory, notebookId, page))
        ledgerLock.unlock()
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
        // 檔案時間要反映剛畫的那一筆：還在排隊的話先等它寫完。
        if hasPendingWrite(directory, notebookId, page) { flushPendingWrites() }
        let pKey = pageCacheKey(directory, notebookId, page)
        ledgerLock.lock()
        if let hit = modifiedCache[pKey] {
            ledgerLock.unlock()
            return hit
        }
        ledgerLock.unlock()
        let own = (try? url(directory, notebookId, page, foreign: false)
            .resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        // 帳本也算：筆畫全擦光時自己的檔案被刪掉，只剩帳本記得「有墓碑要寫」。
        let ledger = (try? ledgerURL(directory, notebookId, page)
            .resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        let result: Date?
        switch (own, ledger) {
        case let (a?, b?): result = max(a, b)
        case let (a?, nil): result = a
        case let (nil, b?): result = b
        default: result = nil
        }
        ledgerLock.lock()
        modifiedCache[pKey] = result
        ledgerLock.unlock()
        return result
    }
}

// MARK: - 算繪

enum ProInkRenderer {
    /// 一筆畫的筆點陣（已算好）。
    struct Cached {
        let dabs: [FfiDab]
        let bounds: CGRect

        /// 套索拖曳時直接平移快取筆點與邊界，避免在 60-240Hz 拖曳幀中反覆呼叫 Rust FFI 重算千萬個高斯筆點。
        func translated(by delta: CGSize) -> Cached {
            let dx = Float(delta.width)
            let dy = Float(delta.height)
            let moved = dabs.map { dab in
                FfiDab(
                    x: dab.x + dx,
                    y: dab.y + dy,
                    rx: dab.rx,
                    ry: dab.ry,
                    angle: dab.angle,
                    alpha: dab.alpha,
                    softness: dab.softness,
                    shade: dab.shade
                )
            }
            return Cached(dabs: moved, bounds: bounds.offsetBy(dx: delta.width, dy: delta.height))
        }
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
    private static let sRGBSpace: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

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

        // 麥克筆、螢光筆：整筆是同一層墨，自己重疊的地方不該變深 ——
        // 筆點一律不透明，畫進透明圖層，整層再以核心給的群組不透明度疊上去（乘法混色）。
        let groupAlpha = ProInk.kind(named: toolName).map { CGFloat(brushGroupAlpha(tool: $0)) } ?? 1
        let isGroup = groupAlpha < 1
        if isGroup {
            ctx.saveGState()
            ctx.setBlendMode(.multiply)
            ctx.setAlpha(groupAlpha)
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        }
        defer {
            if isGroup {
                ctx.endTransparencyLayer()
                ctx.restoreGState()
            }
        }

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

            let angle = CGFloat(dab.angle)
            let isRotated = abs(angle) > 0.05 && abs(rx - ry) > 0.2

            if isRotated {
                ctx.saveGState()
                ctx.translateBy(x: CGFloat(dab.x), y: CGFloat(dab.y))
                ctx.rotate(by: angle)

                if dab.softness > 0.3 {
                    ctx.setFillColor(red: r, green: g, blue: b, alpha: alpha * 0.45)
                    ctx.fillEllipse(in: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
                    ctx.setFillColor(red: r, green: g, blue: b, alpha: alpha * 0.55)
                    ctx.fillEllipse(in: CGRect(x: -rx * 0.65, y: -ry * 0.65, width: rx * 1.3, height: ry * 1.3))
                } else {
                    ctx.setFillColor(red: r, green: g, blue: b, alpha: alpha)
                    ctx.fillEllipse(in: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
                }
                ctx.restoreGState()
            } else {
                let rect = CGRect(x: CGFloat(dab.x) - rx, y: CGFloat(dab.y) - ry, width: rx * 2, height: ry * 2)
                if dab.softness > 0.3 {
                    ctx.setFillColor(red: r, green: g, blue: b, alpha: alpha * 0.45)
                    ctx.fillEllipse(in: rect)
                    ctx.setFillColor(red: r, green: g, blue: b, alpha: alpha * 0.55)
                    ctx.fillEllipse(in: CGRect(x: CGFloat(dab.x) - rx * 0.65, y: CGFloat(dab.y) - ry * 0.65, width: rx * 1.3, height: ry * 1.3))
                } else {
                    ctx.setFillColor(red: r, green: g, blue: b, alpha: alpha)
                    ctx.fillEllipse(in: rect)
                }
            }
        }
    }
}

// MARK: - 磁碟與記憶體雙層印章點陣快取（Disk & Memory Dab Cache）

// profile-scope: profile 筆劃印章快取（隨使用中設定檔切換清空）
enum ProInkDabCache {
    private static let lock = NSLock()
    // profile-scope: profile 筆劃印章記憶體快取（隨設定檔切換由 resetForProfileSwitch 清空）
    private static var memoryCache: [String: ProInkRenderer.Cached] = [:]
    private static let maxMemoryEntries = 4096
    // profile-scope: profile 已確認建立的磁碟快取目錄路徑（隨設定檔切換由 resetForProfileSwitch 清空）
    private static var ensuredDiskDirPath: String?

    static func resetForProfileSwitch() {
        lock.lock()
        memoryCache.removeAll()
        ensuredDiskDirPath = nil
        lock.unlock()
    }

    private static var diskCacheDirectory: URL {
        let base: URL
        if let root = ProfileContext.activeCachesRoot {
            base = root
        } else {
            base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appending(path: "Kairumo", directoryHint: .isDirectory)
        }
        let dir = base.appending(path: "ProInkDabs", directoryHint: .isDirectory)
        let dirPath = dir.path
        lock.lock()
        let alreadyEnsured = (ensuredDiskDirPath == dirPath)
        lock.unlock()
        if !alreadyEnsured {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            lock.lock()
            ensuredDiskDirPath = dirPath
            lock.unlock()
        }
        return dir
    }

    static func cacheKey(for stroke: ProStroke) -> String {
        var hasher = Hasher()
        hasher.combine(stroke.tool)
        hasher.combine(stroke.baseWidth)
        hasher.combine(stroke.lineTypeId)
        hasher.combine(stroke.points.count)
        let step = max(1, stroke.points.count / 16)
        for i in stride(from: 0, to: stroke.points.count, by: step) {
            let p = stroke.points[i]
            hasher.combine(p.x)
            hasher.combine(p.y)
            hasher.combine(p.pressure)
        }
        if let last = stroke.points.last {
            hasher.combine(last.x)
            hasher.combine(last.y)
        }
        return String(format: "%016lx", UInt64(bitPattern: Int64(hasher.finalize())))
    }

    /// 只看記憶體（不讀磁碟）。主執行緒上要判斷「現成有沒有」時用這個。
    static func peek(for stroke: ProStroke) -> ProInkRenderer.Cached? {
        let key = cacheKey(for: stroke)
        lock.lock(); defer { lock.unlock() }
        return memoryCache[key]
    }

    static func get(for stroke: ProStroke) -> ProInkRenderer.Cached? {
        let key = cacheKey(for: stroke)
        lock.lock()
        if let hit = memoryCache[key] {
            lock.unlock()
            return hit
        }
        lock.unlock()

        let file = diskCacheDirectory.appending(path: "\(key).dab")
        guard let data = try? Data(contentsOf: file), data.count >= 24 else { return nil }
        guard data.prefix(4).elementsEqual([0x44, 0x41, 0x42, 0x31]) else { return nil }
        let count = data.subdata(in: 20..<24).withUnsafeBytes { $0.load(as: UInt32.self) }
        guard data.count == 24 + Int(count) * 32 else { return nil }

        let boundsRect = data.subdata(in: 4..<20).withUnsafeBytes { ptr -> CGRect in
            let f = ptr.bindMemory(to: Float.self)
            return CGRect(x: CGFloat(f[0]), y: CGFloat(f[1]), width: CGFloat(f[2] - f[0]), height: CGFloat(f[3] - f[1]))
        }
        let dabs = data.subdata(in: 24..<data.count).withUnsafeBytes { ptr in
            Array(ptr.bindMemory(to: FfiDab.self))
        }
        let cached = ProInkRenderer.Cached(dabs: dabs, bounds: boundsRect)
        lock.lock()
        if memoryCache.count >= maxMemoryEntries {
            memoryCache.removeAll()
        }
        memoryCache[key] = cached
        lock.unlock()
        return cached
    }

    static func set(_ cached: ProInkRenderer.Cached, for stroke: ProStroke) {
        let key = cacheKey(for: stroke)
        lock.lock()
        if memoryCache.count >= maxMemoryEntries {
            memoryCache.removeAll()
        }
        memoryCache[key] = cached
        lock.unlock()

        DispatchQueue.global(qos: .utility).async {
            var data = Data(capacity: 24 + cached.dabs.count * 32)
            data.append(contentsOf: [0x44, 0x41, 0x42, 0x31]) // "DAB1"
            let bounds = cached.bounds
            var bFloats: [Float] = [Float(bounds.minX), Float(bounds.minY), Float(bounds.maxX), Float(bounds.maxY)]
            data.append(Data(bytes: &bFloats, count: 16))
            var count = UInt32(cached.dabs.count)
            data.append(Data(bytes: &count, count: 4))
            var dabs = cached.dabs
            data.append(Data(bytes: &dabs, count: dabs.count * 32))

            let dir = diskCacheDirectory
            let file = dir.appending(path: "\(key).dab")
            let tmp = dir.appending(path: "\(key).tmp")
            try? data.write(to: tmp, options: .atomic)
            _ = try? FileManager.default.replaceItemAt(file, withItemAt: tmp)
        }
    }

    // orphan-ok: ProInkDabCache 背景預熱輔助函式，提供大量專業筆畫在進入視口前非同步載入記憶體
    static func prewarm(strokes: [ProStroke], onComplete: (() -> Void)? = nil) {
        guard !strokes.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            var didCompute = false
            for stroke in strokes {
                if get(for: stroke) == nil {
                    if let computed = ProInkRenderer.cache(for: stroke) {
                        set(computed, for: stroke)
                        didCompute = true
                    }
                }
            }
            if didCompute, let onComplete {
                DispatchQueue.main.async(execute: onComplete)
            }
        }
    }
}



// MARK: - 畫布上的一層

/// 專責即時繪製當前這一筆（含預測觸控點與對齊導引線）的輕量頂層視圖。
/// 與承載整頁歷史筆畫的 `ProInkLayerView` 分離，確保手指／Apple Pencil 移動時不必重繪整頁既有筆畫，
/// 並以同步呈現（`drawsAsynchronously = false`）達到零延遲跟手性。
private final class LiveProStrokeOverlayView: UIView {
    var liveStroke: ProStroke?
    /// 整筆重算的那一份（製圖線、吸附後的圖形）。
    var liveCache: ProInkRenderer.Cached?
    /// 邊畫邊算（`LiveBrushStroke`）：已定案的筆點只會往後接，不再重算；
    /// 預覽是筆尖附近尚未定案的一小段，每一幀整份換掉。兩者有值時取代 `liveCache`。
    var settledDabs: [FfiDab] = []
    var previewDabs: [FfiDab] = []
    var isStreaming = false
    var alignGuides: [[CGPoint]] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        layer.drawsAsynchronously = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
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
        if let live = liveStroke, isStreaming || liveCache != nil {
            ctx.saveGState()
            if live.blendMode == "multiply" {
                ctx.setBlendMode(.multiply)
            } else if live.blendMode == "screen" {
                ctx.setBlendMode(.screen)
            } else {
                ctx.setBlendMode(.normal)
            }
            let rgba = ProInkRenderer.displayColor(
                live.colorRGBA,
                dark: traitCollection.userInterfaceStyle == .dark
            )
            if isStreaming {
                ProInkRenderer.draw(.init(dabs: settledDabs, bounds: .null), toolName: live.tool, color: rgba, in: ctx, clip: rect)
                ProInkRenderer.draw(.init(dabs: previewDabs, bounds: .null), toolName: live.tool, color: rgba, in: ctx, clip: rect)
            } else if let liveCache {
                ProInkRenderer.draw(liveCache, toolName: live.tool, color: rgba, in: ctx, clip: rect)
            }
            ctx.restoreGState()
        }
    }
}

/// 疊在 `PKCanvasView` 上的專業筆畫層。
///
/// 座標系與 PencilKit 的筆畫相同（頁面座標）。縮放由 `AdaptiveCanvasView` 設 `transform`，
/// 所以這裡一律用自己的座標，不必管目前縮放幾倍。
/// 協同的掛點（見 CollabLiveInk.swift 與 `NotebookEditorView+Collab`）。
///
/// 自繪引擎本身不認識協同：這裡只把「書寫中的點」交出去，以及讓外面把別台的筆畫放進來。
/// 沒有人在聽時 `liveHandler` 是 `nil`，書寫路徑上不多做任何事。
enum ProInkCollab {
    /// 書寫中的點。`phase` 0＝落筆（附這一筆的外觀）、1＝新增的點、2＝結束（含取消）。
    // profile-scope: device 只在協同房間開著時由編輯器掛上，離開即清空
    nonisolated(unsafe) static var liveHandler: (@MainActor (_ notebookId: String, _ page: Int, _ phase: Int,
                                                            _ stroke: ProStroke?, _ points: [ProPoint]) -> Void)?

    /// 線上協同跨頁編輯守門：落筆或擦除前檢查是否允許在該頁編輯（若別頁有人先下筆則回 `false`）。
    // profile-scope: device 只在協同房間開著時由編輯器掛上，離開即清空
    nonisolated(unsafe) static var canBeginEdit: (@MainActor (_ notebookId: String, _ page: Int) -> Bool)?

    /// 畫面上正在顯示的頁（別台的筆畫進來時，畫面上那一頁直接更新，不必整頁重讀）。
    // profile-scope: device 弱參照，只記目前存活的畫布圖層
    nonisolated(unsafe) static var liveLayers = NSHashTable<ProInkLayerView>.weakObjects()

    /// 跨頁編輯被更高優先權的遠端成員搶先時，取消本機正在進行中的筆畫。
    @MainActor
    static func cancelActiveStrokes(notebookId: String) {
        for view in liveLayers.allObjects
        where view.notebookId.caseInsensitiveCompare(notebookId) == .orderedSame {
            view.cancelStroke()
        }
    }

    /// 別台即時送來的筆畫：加入 `added`、移除 `removedIds`（套件 id）。
    ///
    /// 畫面上有這一頁就交給那個圖層（只重畫變動的範圍）；沒有就直接改「別台筆畫」檔。
    /// 已經擦掉（墓碑、已擦除名單）的筆畫**不會被加回來**（I3）。
    /// 頁面結構變了：畫面上這本筆記的每一個自繪圖層都從磁碟重讀（它們以頁碼認自己是哪一頁）。
    @MainActor
    static func reloadLayers(notebookId: String) {
        for view in liveLayers.allObjects
        where view.notebookId.caseInsensitiveCompare(notebookId) == .orderedSame {
            view.reload()
        }
    }

    @MainActor
    static func applyRemote(directory: URL, notebookId: String, page: Int,
                            added: [ProStroke], removedIds: Set<String>) {
        let matching = liveLayers.allObjects.filter {
            $0.notebookId.caseInsensitiveCompare(notebookId) == .orderedSame && $0.pageIndex == page
                && $0.directory == directory
        }
        // 同一頁可能同時有好幾個圖層（單頁畫布＋連續模式快取著的畫布）。以前交給「第一個」——
        // 若那是畫面外的那一個，筆畫只進了檔案（縮圖看得到），畫面上的畫布卻沒有。
        // 交給畫面上的那一個，其餘的從磁碟重讀。
        //
        // **畫面外的圖層不能當依據**：它記得的是它最後一次載入時的內容，之後在別的畫布上寫進這一頁的
        // 筆畫它都不知道（最常見的是剛打開筆記時建立、之後被捲出畫面的第一頁）。以前沒有畫面上的圖層時
        // 交給它：要擦的筆畫它手上沒有 → 什麼都沒刪、檔案也沒動；它若有加入，還會把它那份舊的別台筆畫
        // 整份寫回檔案 —— 已擦掉的又回來（實機：雲端協作時房主擦掉協作者的字，協作者那台第一頁永遠擦不掉、
        // 斷線重連後舊筆跡累積出現，後面幾頁正常）。沒有畫面上的圖層時一律直接改檔案，再讓每個圖層重讀。
        if let view = matching.first(where: { $0.window != nil }) {
            view.applyRemote(added: added, removedIds: removedIds)
            // 畫面上的圖層照理有最新的內容；萬一檔案裡還留著要擦的筆畫（圖層與檔案不一致），也一併拿掉。
            if !removedIds.isEmpty, stillOnDisk(removedIds, directory: directory, notebookId: notebookId, page: page) {
                applyRemoteOnDisk(directory: directory, notebookId: notebookId, page: page, added: [], removedIds: removedIds)
                view.reload()
            }
            for other in matching where other !== view { other.reload() }
            return
        }
        applyRemoteOnDisk(directory: directory, notebookId: notebookId, page: page, added: added, removedIds: removedIds)
        for view in matching { view.reload() }
    }

    /// 這幾筆是否還在這一頁的檔案裡（自己的或別台的）。讀的是記憶體快取或排隊中的那一份。
    @MainActor
    private static func stillOnDisk(_ ids: Set<String>, directory: URL, notebookId: String, page: Int) -> Bool {
        ProInkStore.load(in: directory, notebookId: notebookId, page: page).contains { ids.contains($0.packageId) }
            || ProInkStore.load(in: directory, notebookId: notebookId, page: page, foreign: true)
                .contains { ids.contains($0.packageId) }
    }

    /// 直接改那一頁的「別台筆畫」檔（不經畫面上的圖層）。頁面結構調整中用：那時圖層的頁碼還是調整前的。
    @MainActor
    static func applyRemoteOnDisk(directory: URL, notebookId: String, page: Int,
                                  added: [ProStroke], removedIds: Set<String>) {
        var foreign = ProInkStore.load(in: directory, notebookId: notebookId, page: page, foreign: true)
        var own = ProInkStore.load(in: directory, notebookId: notebookId, page: page)
        let blocked = ProInkCollab.blockedIds(directory: directory, notebookId: notebookId, page: page)
        let suppressed = ProInkStore.loadSuppressed(in: directory, notebookId: notebookId, page: page)
        var known = Set((foreign + own).map(\.packageId))
        var changed = false
        var ownChanged = false
        if !removedIds.isEmpty {
            let before = foreign.count
            let gone = foreign.filter { removedIds.contains($0.packageId) }
            foreign.removeAll { removedIds.contains($0.packageId) }
            if !gone.isEmpty {
                ProInkStore.saveSuppressed(suppressed.union(gone.map(\.contentKey)),
                                           in: directory, notebookId: notebookId, page: page)
            }
            changed = changed || foreign.count != before
            // 別人擦掉的是**這台自己的**筆畫：也要拿掉（與畫面上的圖層 `applyRemote` 相同）。
            // 以前這條路只刪「別台筆畫」：房主不在那一頁時，協作者擦掉房主畫的字，
            // 其他協作者都消失了、房主這台卻留著（實機回報）。墓碑由擦掉的那台寫，這裡不再寫一次。
            let ownBefore = own.count
            own.removeAll { removedIds.contains($0.packageId) }
            if own.count != ownBefore {
                ProInkStore.saveDeferred(own, in: directory, notebookId: notebookId, page: page)
                ownChanged = true
            }
        }
        for stroke in added where !known.contains(stroke.packageId) && !blocked.contains(stroke.packageId)
            && !suppressed.contains(stroke.contentKey) {
            foreign.append(stroke)
            known.insert(stroke.packageId)
            changed = true
        }
        guard changed || ownChanged else { return }
        if changed {
            ProInkStore.save(foreign, in: directory, notebookId: notebookId, page: page, foreign: true)
        }
        NotificationCenter.default.post(name: AppCommand.proInkDidChange, object: notebookId.lowercased())
    }

    /// 這一頁已經擦掉、不能再出現的套件 id（帳本裡的墓碑）。
    nonisolated static func blockedIds(directory: URL, notebookId: String, page: Int) -> Set<String> {
        let ledger = ProInkStore.loadLedger(in: directory, notebookId: notebookId, page: page)
        // 加上協同擦除的永久墓碑：帳本裡的會在匯出後清掉，別人擦掉的「我的」筆畫帳本根本沒記
        // （見 `CollabInkTombstones`）。
        return Set(ledger.retired.map(\.coreId) + ledger.foreignTombstones.map { $0.lowercased() })
            .union(CollabInkTombstones.all(directory: directory, notebookId: notebookId))
    }
}

final class ProInkLayerView: UIView {
    /// 流線防抖強度：書寫中的即時筆點與抬筆後的整筆平滑共用（兩邊不同就會在抬筆時變形）。與 Android 相同。
    static let liveStreamline: Float = 0.35

    /// 這一頁的識別。換頁時由外面重設並重新載入。
    private(set) var notebookId = ""
    private(set) var pageIndex = 0
    private(set) var directory: URL?

    private(set) var ownStrokes: [ProStroke] = []
    private var foreignStrokes: [ProStroke] = []


    /// 正在畫的那一筆。
    private var live: ProStroke?
    private var liveCache: ProInkRenderer.Cached?
    /// 邊畫邊算的筆點陣（一般筆畫）。製圖線（會靠邊、對齊、吸附而改寫點列）不用它，照舊整筆重算。
    private var liveBrush: LiveBrushStroke?
    private var lastPredictedArea: CGRect = .null
    private let liveOverlayView = LiveProStrokeOverlayView()

    // MARK: 非同步烘焙與收筆交接（即時響應：主執行緒不做整頁筆畫運算）

    /// 超過這個筆畫數的整頁重建（換頁、第一次畫）改在背景烘焙；少的同步做完，沒有視覺延遲。
    private static let asyncBakeThreshold = 12
    private static let bakeQueue = DispatchQueue(label: "kairumo.proink.bake", qos: .userInitiated)
    private var bakeToken = BakeToken()
    private var inFlightBake: (ids: [String], pageKey: String, dark: Bool, size: CGSize)?
    /// 收筆時筆點陣還沒算好的那一筆：算好之前即時疊加層繼續顯示它，算好才交接給底層。
    private var pendingHandoff: ProStroke?

    /// 每筆的外框（`ProStroke.bounds` 要掃過全部筆點，擦除與局部重畫每次都問會變成 O(筆畫數 × 筆點數)）。
    /// 以 id 為鍵，並用「筆點數＋頭尾點＋筆寬」當簽章：搬動、改寫之後簽章會變，快取自動失效。
    private var boundsCache: [String: (sig: Int, rect: CGRect)] = [:]

    private func cachedBounds(_ stroke: ProStroke) -> CGRect {
        var h = Hasher()
        h.combine(stroke.points.count)
        h.combine(stroke.baseWidth)
        if let f = stroke.points.first { h.combine(f.x); h.combine(f.y) }
        if let l = stroke.points.last { h.combine(l.x); h.combine(l.y) }
        let sig = h.finalize()
        if let hit = boundsCache[stroke.id], hit.sig == sig { return hit.rect }
        let rect = stroke.bounds
        boundsCache[stroke.id] = (sig, rect)
        return rect
    }

    /// 已烘焙的序列與目前序列只差「被拿掉／插進來」的幾筆（其餘相對順序不變）時，回傳要局部重畫的範圍；
    /// 否則 `nil`（整頁重建）。擦掉一筆因此只重畫那一筆的範圍，不必把整頁幾百筆重貼一遍。
    private func patchRegion(baked: [String], ordered: [ProStroke]) -> CGRect? {
        let ids = ordered.map(\.id)
        guard ids.count != baked.count else { return nil }
        let removal = ids.count < baked.count
        let longer = removal ? baked : ids
        let shorter = removal ? ids : baked
        var j = 0
        var differing: [Int] = []
        for (i, id) in longer.enumerated() {
            if j < shorter.count, shorter[j] == id { j += 1 } else { differing.append(i) }
        }
        guard j == shorter.count, !differing.isEmpty, differing.count <= 8 else { return nil }
        var region = CGRect.null
        for i in differing {
            if removal {
                guard let known = boundsCache[longer[i]] else { return nil }
                region = region.union(known.rect)
            } else {
                region = region.union(cachedBounds(ordered[i]))
            }
        }
        return region.isNull ? nil : region
    }

    /// 局部重畫：清掉 `region`，把與它相交的筆畫依序重貼進去。範圍對齊到整數像素（否則邊緣會留半透明殘影）。
    private func patchBacking(_ ctx: CGContext, ordered: [ProStroke], region: CGRect, scale: CGFloat, isDark: Bool, fullBounds: CGRect) {
        let inflated = region.insetBy(dx: -1, dy: -1)
        let x0 = floor(inflated.minX * scale) / scale, y0 = floor(inflated.minY * scale) / scale
        let x1 = ceil(inflated.maxX * scale) / scale, y1 = ceil(inflated.maxY * scale) / scale
        let r = CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0).intersection(fullBounds)
        guard !r.isNull else { return }
        ctx.saveGState()
        ctx.clip(to: r)
        ctx.clear(r)
        for stroke in ordered where cachedBounds(stroke).intersects(r) {
            guard let cached = cachedDabs(for: stroke) else { continue }
            ctx.saveGState()
            ctx.setBlendMode(stroke.blendMode == "multiply" ? .multiply : (stroke.blendMode == "screen" ? .screen : .normal))
            ProInkRenderer.draw(cached, toolName: stroke.tool, color: ProInkRenderer.displayColor(stroke.colorRGBA, dark: isDark), in: ctx, clip: r)
            ctx.restoreGState()
        }
        ctx.restoreGState()
        bakedStrokeIds = ordered.map(\.id)
        bakedStrokeCount = ordered.count
    }

    /// 捲出畫面的頁：丟掉純快取性質的算繪資源（整頁烘焙點陣、視圖自己的點陣），回來時自動在背景重烘。
    /// 連續模式的頁面一旦建立就不會被系統回收，不丟的話每捲過一頁就多留十幾 MB。
    func releaseRenderResources() {
        guard pendingHandoff == nil, live == nil else { return }
        invalidateBackingStore()
        boundsCache.removeAll()
        layer.contents = nil
    }

    /// 回到畫面：重畫一次（烘焙點陣已被丟掉時會在背景重建）。
    func resumeRendering() {
        setNeedsDisplay()
    }

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
        // 禁用非同步繪製（drawsAsynchronously = false）：
        // drawsAsynchronously 會導致 CoreAnimation 在主執行緒 CATransaction::commit 中
        // 透過 dispatch_sync 同步等待 CA::CG::Queue，而 PencilKit 背景佇列（draw-previews）
        // 同時向主執行緒 dispatch_sync，造成兩端互鎖並引發 Watchdog 0x8BADF00D 強殺。
        layer.drawsAsynchronously = false
        liveOverlayView.frame = bounds
        liveOverlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(liveOverlayView)
        NotificationCenter.default.addObserver(
            self, selector: #selector(diskChanged(_:)),
            name: .kairumoProInkChangedOnDisk, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(draftingChanged), name: .kairumoDraftingChanged, object: nil)
    }

    /// 圖層顯示／鎖定改了：整層重畫（只是不畫某些筆畫，筆點快取不必清）。
    @objc private func draftingChanged() {
        invalidateBackingStore()
        invalidateAlignAnchors()
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
        ProInkCollab.liveLayers.add(self)
        reload()
    }

    /// 別台即時送來的筆畫（見 `ProInkCollab.applyRemote`）。只重畫變動的範圍。
    func applyRemote(added: [ProStroke], removedIds: Set<String>) {
        guard let directory else { return }
        var dirty: [CGRect] = []
        var foreignChanged = false
        if !removedIds.isEmpty {
            let gone = foreignStrokes.filter { removedIds.contains($0.packageId) }
            if !gone.isEmpty {
                foreignStrokes.removeAll { removedIds.contains($0.packageId) }
                dirty += gone.map(\.bounds)
                foreignChanged = true
                var keys = ProInkStore.loadSuppressed(in: directory, notebookId: notebookId, page: pageIndex)
                keys.formUnion(gone.map(\.contentKey))
                ProInkStore.saveSuppressed(keys, in: directory, notebookId: notebookId, page: pageIndex)
            }
            // 別人擦掉的是**我的**筆畫：從我這裡拿掉。墓碑由擦掉的那台寫，這裡不再寫一次。
            let mine = ownStrokes.filter { removedIds.contains($0.packageId) }
            if !mine.isEmpty {
                ownStrokes.removeAll { removedIds.contains($0.packageId) }
                for stroke in mine { strokeSnapshot.removeValue(forKey: stroke.id) }
                tombstonedIds.formUnion(mine.map(\.packageId))
                dirty += mine.map(\.bounds)
                ProInkStore.saveDeferred(ownStrokes, in: directory, notebookId: notebookId, page: pageIndex)
            }
        }
        let known = Set(allStrokes.map(\.packageId))
        let blocked = ProInkCollab.blockedIds(directory: directory, notebookId: notebookId, page: pageIndex)
            .union(tombstonedIds)
        let suppressed = ProInkStore.loadSuppressed(in: directory, notebookId: notebookId, page: pageIndex)
        let fresh = added.filter {
            !known.contains($0.packageId) && !blocked.contains($0.packageId) && !suppressed.contains($0.contentKey)
        }
        if !fresh.isEmpty {
            foreignStrokes.append(contentsOf: fresh)
            foreignChanged = true
        }
        guard foreignChanged || !dirty.isEmpty else { return }
        if foreignChanged {
            ProInkStore.save(foreignStrokes, in: directory, notebookId: notebookId, page: pageIndex, foreign: true)
        }
        for rect in dirty { setNeedsDisplay(rect) }
        if !fresh.isEmpty {
            // 筆點陣在背景算好再畫（`draw(rect)` 裡不做同步運算）。
            ProInkDabCache.prewarm(strokes: fresh) { [weak self] in
                guard let self else { return }
                for stroke in fresh { self.setNeedsDisplay(stroke.bounds) }
            }
        }
        onChanged?()
        NotificationCenter.default.post(name: AppCommand.proInkDidChange, object: notebookId.lowercased())
    }

    /// 從磁碟重讀（換頁、同步匯入、清除頁面之後）。
    func reload() {
        guard let directory else { return }
        flushPendingHandoff()
        invalidateBackingStore()
        ProInkStore.invalidateModifiedCache(notebookId: notebookId)
        ownStrokes = ProInkStore.load(in: directory, notebookId: notebookId, page: pageIndex)
        foreignStrokes = ProInkStore.load(in: directory, notebookId: notebookId, page: pageIndex, foreign: true)
        strokeSnapshot = Dictionary(ownStrokes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        setNeedsDisplay()
    }

    /// 上一次存檔時自己的筆畫（以本機 `id` 為鍵）。存檔時與現在比對，找出被拿掉／加回來的筆畫，
    /// 對應地更新同步帳本（見 `ProInkLedger`）。
    private var strokeSnapshot: [String: ProStroke] = [:]

    /// 把「筆畫消失／重新出現」記進同步帳本。**每個改動自己筆畫的路徑都會經過 `persist`**，
    /// 所以放在這裡一處就涵蓋擦除、復原、重做、套索刪除、清頁 —— 不必在每個入口各補一次。
    ///
    /// - 消失的筆畫：若它**已經匯出過**（上一次匯出寫出了它），要寫墓碑，記進帳本（帶著整筆資料，
    ///   匯出時才寫得出 `Add`，檔案才不會變小）。沒匯出過的不必：別台從來沒看過它。
    /// - 以同一個本機 `id` 重新出現的筆畫（復原擦除）：墓碑還沒寫出去就撤掉；
    ///   **已經寫出去的墓碑撤不掉**，這一筆改用新的套件身分。
    private func reconcileLedger() {
        guard let directory else { return }
        let current = Dictionary(ownStrokes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let removed = strokeSnapshot.values.filter { current[$0.id] == nil }
        let appeared = ownStrokes.indices.filter { strokeSnapshot[ownStrokes[$0].id] == nil }
        if !removed.isEmpty || !appeared.isEmpty {
            ProInkStore.updateLedger(in: directory, notebookId: notebookId, page: pageIndex) { ledger in
                let exported = Set(ledger.exportedIds)
                for old in removed {
                    let cid = old.packageId
                    guard exported.contains(cid), !ledger.retired.contains(where: { $0.coreId == cid }) else { continue }
                    ledger.retired.append(.init(coreId: cid, stroke: old, exported: false))
                }
                for i in appeared {
                    let cid = ownStrokes[i].packageId
                    guard let at = ledger.retired.firstIndex(where: { $0.coreId == cid }) else { continue }
                    if ledger.retired[at].exported {
                        ownStrokes[i].coreId = UUID().uuidString.lowercased()
                    } else {
                        ledger.retired.remove(at: at)
                    }
                }
            }
        }
        strokeSnapshot = Dictionary(ownStrokes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// 已經匯出過的筆畫被**就地改動**（搬動、改圖層）：舊的那個樣子要寫墓碑，這一筆換新的套件身分 ——
    /// 否則同一個 id 的內容變了、檔案大小卻沒變，別台永遠收不到。
    private func retireForModification(ids: Set<String>) {
        guard let directory, !ids.isEmpty else { return }
        ProInkStore.updateLedger(in: directory, notebookId: notebookId, page: pageIndex) { ledger in
            let exported = Set(ledger.exportedIds)
            for i in ownStrokes.indices where ids.contains(ownStrokes[i].id) {
                guard let old = strokeSnapshot[ownStrokes[i].id] else { continue }
                let cid = old.packageId
                guard exported.contains(cid), !ledger.retired.contains(where: { $0.coreId == cid }) else { continue }
                ledger.retired.append(.init(coreId: cid, stroke: old, exported: false))
                ownStrokes[i].coreId = UUID().uuidString.lowercased()
            }
        }
    }

    /// 這一輪（從開啟到關閉）已經寫成墓碑的套件 id。復原把同一筆加回來時要換新 id ——
    /// 墓碑永遠優先（ADR-0015 I3），沿用舊 id 的話加回來的那一筆在每一台都看不見。
    /// 復原只能撤銷這一輪的動作，所以記在記憶體裡就夠了。
    private var tombstonedIds: Set<String> = []

    /// 這個套件 id 已經被擦掉過（這個圖層記得的，或協同擦除的永久墓碑）：再放回來要換新 id，
    /// 否則別台以墓碑擋下，兩邊從此不一致（I3）。
    private func isTombstoned(_ packageId: String) -> Bool {
        if tombstonedIds.contains(packageId) { return true }
        guard let directory else { return false }
        return CollabInkTombstones.contains(packageId, directory: directory, notebookId: notebookId)
    }

    private func persist() {
        invalidateAlignAnchors()
        guard let directory else { return }
        let before = strokeSnapshot
        reconcileLedger()
        let events = takeEvents(since: before)
        if let sink = InkEventSink.sink(for: notebookId) {
            sink.proEdited(page: pageIndex, removedIds: events.removed, added: events.added)
            // 墓碑確實寫出去了才記：之後把同一筆加回來要換新 id。
            tombstonedIds.formUnion(events.removed)
        }
        if !events.removed.isEmpty {
            setNeedsDisplay()
        }
        ProInkStore.saveDeferred(ownStrokes, in: directory, notebookId: notebookId, page: pageIndex)
        onChanged?()
        NotificationCenter.default.post(name: AppCommand.proInkDidChange, object: notebookId.lowercased())
    }

    /// 單筆新增專用 O(1) 持久化快徑（`endStroke` 專用）：
    /// 免除每次抬筆對整頁數百筆歷史筆畫執行 `reconcileLedger` 與 `takeEvents` 的 O(N × M) 逐點比對，
    /// 徹底消除連續書寫時隨筆畫數量增加而累積的抬筆延遲。
    private func persistAppendedStroke(_ stroke: ProStroke) {
        invalidateAlignAnchors()
        guard let directory else { return }
        var addedStroke = stroke
        if isTombstoned(addedStroke.packageId), !ownStrokes.isEmpty {
            let newCoreId = UUID().uuidString.lowercased()
            ownStrokes[ownStrokes.count - 1].coreId = newCoreId
            addedStroke = ownStrokes[ownStrokes.count - 1]
        }
        strokeSnapshot[addedStroke.id] = addedStroke
        if let sink = InkEventSink.sink(for: notebookId) {
            sink.proEdited(page: pageIndex, removedIds: [], added: [addedStroke])
        }
        ProInkStore.saveDeferred(ownStrokes, in: directory, notebookId: notebookId, page: pageIndex)
        onChanged?()
        NotificationCenter.default.post(name: AppCommand.proInkDidChange, object: notebookId.lowercased())
    }

    /// 與上一次存檔相比，這一次的事件（ADR-0015 I2）：消失的 → 擦掉；新出現的 → 加入；
    /// **內容變了的（搬動、改圖層…）→ 擦掉舊 id、以新 id 加入**，不改寫既有記錄。
    private func takeEvents(since before: [String: ProStroke]) -> (removed: [String], added: [ProStroke]) {
        var removed: [String] = []
        var added: [ProStroke] = []
        var present = Set<String>()
        for i in ownStrokes.indices {
            let stroke = ownStrokes[i]
            present.insert(stroke.id)
            if let old = before[stroke.id] {
                guard old != stroke else { continue }
                removed.append(old.packageId)
                if stroke.packageId == old.packageId || isTombstoned(stroke.packageId) {
                    ownStrokes[i].coreId = UUID().uuidString.lowercased()
                }
                added.append(ownStrokes[i])
            } else {
                if isTombstoned(stroke.packageId) {
                    ownStrokes[i].coreId = UUID().uuidString.lowercased()
                }
                added.append(ownStrokes[i])
            }
        }
        for (id, old) in before where !present.contains(id) {
            removed.append(old.packageId)
        }
        if !added.isEmpty {
            // 換了套件身分的筆畫：快照跟著換，下一次比對才不會再當成改動。
            strokeSnapshot = Dictionary(ownStrokes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        }
        return (removed, added)
    }

    // MARK: 繪製

    /// 深色模式下頁面是深色的：近黑的墨水（製圖的「頂」「底」層）會看不見，
    /// 就像 PencilKit 會把深色墨水在深色模式反相，這裡也把近黑的色提亮。
    /// 只影響畫面與縮圖；存檔與匯出仍是原色（匯出的紙是白的）。
    private func displayColor(_ rgba: [UInt8]) -> [UInt8] {
        ProInkRenderer.displayColor(rgba, dark: traitCollection.userInterfaceStyle == .dark)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            invalidateBackingStore()
            setNeedsDisplay()
        }
    }

    // MARK: - 增量烘焙底圖（Incremental Backing Store）
    private var backingImage: UIImage?
    private var backingContext: CGContext?
    private var bakedStrokeCount: Int = 0
    private var bakedStrokeIds: [String] = []
    private var lastPageKey: String = ""
    private var lastDarkMode: Bool = false
    private var lastBackingBounds: CGSize = .zero

    private func invalidateBackingStore() {
        bakeToken.cancel()
        inFlightBake = nil
        backingImage = nil
        backingContext = nil
        bakedStrokeCount = 0
        bakedStrokeIds.removeAll()
        lastPageKey = ""
        lastBackingBounds = .zero
    }

    private func startAsyncBake(ordered: [ProStroke], size: CGSize, scale: CGFloat, isDark: Bool, pageKey: String) {
        bakeToken.cancel()
        let token = BakeToken()
        bakeToken = token
        let ids = ordered.map(\.id)
        inFlightBake = (ids, pageKey, isDark, size)
        nonisolated(unsafe) let strokes = ordered
        Self.bakeQueue.async { [weak self] in
            let baked = Self.bake(strokes, size: size, scale: scale, isDark: isDark, token: token)
            nonisolated(unsafe) let result = baked
            DispatchQueue.main.async {
                guard let self, !token.isCancelled else { return }
                self.inFlightBake = nil
                guard let (ctx, image) = result else {
                    // 背景建不出來（記憶體不足等）：退回同步路徑，下一次繪製會自己重建。
                    self.lastPageKey = pageKey
                    self.setNeedsDisplay()
                    return
                }
                self.backingContext = ctx
                self.backingImage = UIImage(cgImage: image, scale: scale, orientation: .up)
                self.bakedStrokeIds = ids
                self.bakedStrokeCount = ids.count
                self.lastPageKey = pageKey
                self.lastDarkMode = isDark
                self.lastBackingBounds = size
                self.setNeedsDisplay()
            }
        }
    }

    /// 整頁烘焙（背景執行緒）：與 `ensureBackingContext` / `updateBackingStore` 的同步路徑畫法一致。
    nonisolated private static func bake(_ strokes: [ProStroke], size: CGSize, scale: CGFloat, isDark: Bool, token: BakeToken) -> (CGContext, CGImage)? {
        let pixelWidth = Int(ceil(size.width * scale))
        let pixelHeight = Int(ceil(size.height * scale))
        guard pixelWidth > 0, pixelHeight > 0,
              let ctx = CGContext(data: nil, width: pixelWidth, height: pixelHeight, bitsPerComponent: 8,
                                  bytesPerRow: pixelWidth * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.translateBy(x: 0, y: CGFloat(pixelHeight))
        ctx.scaleBy(x: scale, y: -scale)
        let full = CGRect(origin: .zero, size: size)
        for (i, stroke) in strokes.enumerated() {
            if i % 32 == 0, token.isCancelled { return nil }
            let cached = ProInkDabCache.get(for: stroke) ?? {
                guard let made = ProInkRenderer.cache(for: stroke) else { return nil }
                ProInkDabCache.set(made, for: stroke)
                return made
            }()
            guard let cached else { continue }
            ctx.saveGState()
            ctx.setBlendMode(stroke.blendMode == "multiply" ? .multiply : (stroke.blendMode == "screen" ? .screen : .normal))
            ProInkRenderer.draw(cached, toolName: stroke.tool, color: ProInkRenderer.displayColor(stroke.colorRGBA, dark: isDark), in: ctx, clip: full)
            ctx.restoreGState()
        }
        guard !token.isCancelled, let image = ctx.makeImage() else { return nil }
        return (ctx, image)
    }

    /// 收筆交接完成：底層畫上這一筆，疊加層清掉（同一個 CA 交易，不會閃）。
    private func completeHandoff(_ id: String) {
        guard let p = pendingHandoff, p.id == id else { return }
        pendingHandoff = nil
        let area = p.bounds.insetBy(dx: -24, dy: -24)
        setNeedsDisplay(p.bounds)
        liveOverlayView.liveStroke = nil
        liveOverlayView.liveCache = nil
        liveOverlayView.isStreaming = false
        liveOverlayView.settledDabs.removeAll(keepingCapacity: true)
        liveOverlayView.previewDabs.removeAll()
        liveOverlayView.setNeedsDisplay(area)
    }

    /// 還有一筆在等交接就現在做完（下一筆開始、換頁、重載之前）。極少需要同步補算。
    private func flushPendingHandoff() {
        guard let p = pendingHandoff else { return }
        if ProInkDabCache.peek(for: p) == nil, let made = ProInkRenderer.cache(for: p) {
            ProInkDabCache.set(made, for: p)
        }
        completeHandoff(p.id)
    }

    private func ensureBackingContext(size: CGSize, scale: CGFloat) -> CGContext? {
        let pixelWidth = Int(ceil(size.width * scale))
        let pixelHeight = Int(ceil(size.height * scale))
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }
        if let existing = backingContext,
           existing.width == pixelWidth,
           existing.height == pixelHeight {
            return existing
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: pixelWidth * 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        // 設定標準 UIKit 頂端對齊座標系（Y 軸向下，點為單位）
        ctx.translateBy(x: 0, y: CGFloat(pixelHeight))
        ctx.scaleBy(x: scale, y: -scale)
        backingContext = ctx
        bakedStrokeCount = 0
        bakedStrokeIds.removeAll()
        backingImage = nil
        return ctx
    }

    private func updateBackingStore(with ordered: [ProStroke], fullBounds: CGRect) {
        guard fullBounds.width > 0, fullBounds.height > 0 else { return }
        let scale = window?.screen.scale ?? UIScreen.main.scale
        guard let bCtx = ensureBackingContext(size: fullBounds.size, scale: scale) else { return }

        let isDark = traitCollection.userInterfaceStyle == .dark
        let pageKey = "\(notebookId)_\(pageIndex)"
        var needsFullRebuild = false

        if pageKey != lastPageKey || isDark != lastDarkMode || fullBounds.size != lastBackingBounds || bakedStrokeCount > ordered.count || (bakedStrokeCount > 0 && ordered.isEmpty) {
            needsFullRebuild = true
        } else {
            // 檢查已烘焙筆劃是否與當前筆劃序列完全吻合（防止中間筆畫被擦除、搬動或圖層屬性變更）
            for i in 0..<bakedStrokeIds.count {
                if bakedStrokeIds[i] != ordered[i].id {
                    needsFullRebuild = true
                    break
                }
            }
        }

        // 只差幾筆被擦掉／放回來：局部重畫就好。
        if needsFullRebuild, inFlightBake == nil, bakedStrokeCount > 0,
           pageKey == lastPageKey, isDark == lastDarkMode, fullBounds.size == lastBackingBounds,
           let region = patchRegion(baked: bakedStrokeIds, ordered: ordered) {
            PerfProbe.shared.count(.backingPatch)
            patchBacking(bCtx, ordered: ordered, region: region, scale: scale, isDark: isDark, fullBounds: fullBounds)
            needsFullRebuild = false
        }

        if needsFullRebuild {
            // 同一份已經在背景烘焙：等它完成（尾端新筆畫由 `draw` 直接補畫）。內容已經不是當初那份就作廢重來。
            if let flight = inFlightBake {
                let sameInputs = flight.pageKey == pageKey && flight.dark == isDark && flight.size == fullBounds.size
                if sameInputs, ordered.count >= flight.ids.count,
                   !zip(ordered, flight.ids).contains(where: { $0.id != $1 }) {
                    return
                }
                bakeToken.cancel()
                inFlightBake = nil
            }
            PerfProbe.shared.count(.backingFullRebuild)
            // 換頁（或第一次建立）且筆畫多：整頁烘焙放到背景，主執行緒不等。
            if pageKey != lastPageKey, ordered.count > Self.asyncBakeThreshold {
                startAsyncBake(ordered: ordered, size: fullBounds.size, scale: scale, isDark: isDark, pageKey: pageKey)
                return
            }
            bCtx.saveGState()
            bCtx.clear(CGRect(origin: .zero, size: fullBounds.size))
            bCtx.restoreGState()
            bakedStrokeCount = 0
            bakedStrokeIds.removeAll()
            lastPageKey = pageKey
            lastDarkMode = isDark
            lastBackingBounds = fullBounds.size
        }

        // 增量烘焙：只繪製新加入的筆劃（O(1) 增量成本，絕不隨筆劃數增多而累積延遲）
        while bakedStrokeCount < ordered.count {
            let stroke = ordered[bakedStrokeCount]
            if let cached = cachedDabs(for: stroke) {
                bCtx.saveGState()
                if stroke.blendMode == "multiply" {
                    bCtx.setBlendMode(.multiply)
                } else if stroke.blendMode == "screen" {
                    bCtx.setBlendMode(.screen)
                } else {
                    bCtx.setBlendMode(.normal)
                }
                ProInkRenderer.draw(cached, toolName: stroke.tool, color: displayColor(stroke.colorRGBA), in: bCtx, clip: fullBounds)
                bCtx.restoreGState()
            }
            bakedStrokeIds.append(stroke.id)
            bakedStrokeCount += 1
        }

        if let cgImg = bCtx.makeImage() {
            backingImage = UIImage(cgImage: cgImg, scale: scale, orientation: .up)
        }
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let drafting = DraftingState.shared
        let ordered = drafting.drawOrder(allStrokes, notebookId: notebookId)

        updateBackingStore(with: ordered, fullBounds: bounds)
        backingImage?.draw(in: bounds)
        // 背景烘焙進行中：烘焙開始之後才加入的筆畫直接畫上去，剛畫完的字不會等烘焙。
        if let flight = inFlightBake {
            let dark = traitCollection.userInterfaceStyle == .dark
            for stroke in ordered.dropFirst(flight.ids.count) where stroke.bounds.intersects(rect) {
                guard let cached = cachedDabs(for: stroke) else { continue }
                ctx.saveGState()
                ctx.setBlendMode(stroke.blendMode == "multiply" ? .multiply : (stroke.blendMode == "screen" ? .screen : .normal))
                ProInkRenderer.draw(cached, toolName: stroke.tool, color: ProInkRenderer.displayColor(stroke.colorRGBA, dark: dark), in: ctx, clip: rect)
                ctx.restoreGState()
            }
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
    }

    private func syncLiveOverlay(invalidating rect: CGRect? = nil) {
        liveOverlayView.liveStroke = live
        liveOverlayView.liveCache = liveCache
        liveOverlayView.isStreaming = live != nil && liveBrush != nil
        liveOverlayView.alignGuides = alignGuides
        if let rect, !rect.isNull {
            liveOverlayView.setNeedsDisplay(rect)
        } else {
            liveOverlayView.setNeedsDisplay()
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

    private var cachedAlignAnchors: [FfiPoint]?

    func invalidateAlignAnchors() {
        cachedAlignAnchors = nil
    }

    /// 對齊用的點：看得見的筆畫的端點與短折線的轉折點（上限 600 個，免得大頁面拖慢）。
    private func alignAnchors() -> [FfiPoint] {
        if let cached = cachedAlignAnchors { return cached }
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
        cachedAlignAnchors = out
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
        if !dirty.isNull {
            syncLiveOverlay(invalidating: dirty.insetBy(dx: -6, dy: -6))
        } else {
            syncLiveOverlay()
        }
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
        if let hit = ProInkDabCache.get(for: stroke) { return hit }
        guard let made = ProInkRenderer.cache(for: stroke) else { return nil }
        ProInkDabCache.set(made, for: stroke)
        return made
    }

    // MARK: 畫一筆

    func beginStroke(tool: ToolKind, color: [UInt8], width: Float, at point: ProPoint,
                     layer: UInt8 = 0, lineType: UInt8 = 0) {
        guard let name = ProInk.name(of: tool) else { return }
        flushPendingHandoff()
        CanvasTouchState.noteInkActivity()
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
        ProInkCollab.liveHandler?(notebookId, pageIndex, 0, live, [point])
        snapState = nil
        resetLiveBrush()
        if layer == 0, let kind = ProInk.kind(named: name) {
            // 書寫中就套用抬筆後同一組流線防抖（與 Android `InkCanvas` 相同）：畫面上的形狀就是存檔的形狀，
            // 抬筆時不再重新變形。製圖線（線型非 0）照舊不平滑。
            liveBrush = lineType == 0
                ? LiveBrushStroke.newSmoothed(tool: kind, baseWidth: width, lineType: lineType,
                                              streamline: Self.liveStreamline, gamma: 1.0)
                : LiveBrushStroke(tool: kind, baseWidth: width, lineType: lineType)
        }
        lastPredictedArea = .null
        refreshLive(dirtyAround: [point])
    }

    func extendStroke(with points: [ProPoint], predicted: [ProPoint] = []) {
        guard var stroke = live, !points.isEmpty else { return }
        CanvasTouchState.noteInkActivity()
        ProInkCollab.liveHandler?(notebookId, pageIndex, 1, nil, points)
        // 吸附之後：直線跟著手指的終點走（角度鎖定照樣生效）；其他圖形定型，不再變。
        if let snap = snapState {
            guard snap.kind == .line, let end = points.last else { return }
            let area = stroke.bounds
            let (dx, dy) = Self.snapped(dx: end.x - snap.origin.x, dy: end.y - snap.origin.y, step: snap.angleStep)
            stroke.points = Self.lineSamples(from: snap.origin, toX: snap.origin.x + dx, y: snap.origin.y + dy, count: snap.count)
            live = stroke
            liveCache = ProInkRenderer.cache(for: stroke)
            syncLiveOverlay(invalidating: area.union(stroke.bounds))
            return
        }
        if let lock = edgeLock, let first = stroke.points.first, var end = points.last {
            let foot = InstrumentModel.footOnLine(CGPoint(x: CGFloat(end.x), y: CGFloat(end.y)), lock.a, lock.b)
            end.x = Float(foot.x); end.y = Float(foot.y)
            let area = stroke.bounds
            stroke.points = Self.lineSamples(from: first, toX: end.x, y: end.y, count: 24)
            live = stroke
            liveCache = ProInkRenderer.cache(for: stroke)
            syncLiveOverlay(invalidating: area.union(stroke.bounds))
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
        refreshLive(dirtyAround: points, predicted: stroke.layerId == 0 ? predicted : [])
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
        let area = stroke.bounds.union(lastPredictedArea)
        lastPredictedArea = .null
        for (i, p) in result.points.enumerated() {
            stroke.points[i].x = p.x
            stroke.points[i].y = p.y
        }
        live = stroke
        snapState = SnapState(kind: result.kind, origin: stroke.points[0], angleStep: angleStep,
                              count: stroke.points.count)
        resetLiveBrush()   // 點列被改寫了：之後整筆重算
        liveCache = ProInkRenderer.cache(for: stroke)
        syncLiveOverlay(invalidating: area.union(stroke.bounds))
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
        PerfProbe.shared.measure(.strokeEnd) { endStrokeBody() }
    }

    private func endStrokeBody() {
        guard var stroke = live else { return }
        ProInkCollab.liveHandler?(notebookId, pageIndex, 2, nil, [])
        let liveArea = stroke.bounds.union(lastPredictedArea)
        lastPredictedArea = .null
        guard !stroke.points.isEmpty else {
            live = nil
            liveCache = nil
            resetLiveBrush()
            syncLiveOverlay(invalidating: liveArea)
            return
        }
        // 製圖線要的是等寬、不收尖、不圓角：不做平滑。
        if stroke.points.count >= 3, stroke.layerId == 0, stroke.lineTypeId == 0 {
            let pts = stroke.points.map {
                StrokePoint(x: $0.x, y: $0.y, pressure: $0.pressure, tilt: $0.tilt, azimuth: $0.azimuth, dtUs: $0.dtUs, roll: $0.roll)
            }
            let prefs = ProfileDefaults.current
            let rawGamma = prefs.object(forKey: "kairumo.pen.pressureGamma") != nil
                ? Double(prefs.float(forKey: "kairumo.pen.pressureGamma"))
                : 1.0
            let gamma = Float(max(0.4, min(2.2, rawGamma)))
            let smoothed = streamlineSmoothPoints(points: pts, amount: Self.liveStreamline, gamma: gamma, taper: 0.22, tension: 0.38)
            stroke.points = smoothed.map {
                ProPoint(x: $0.x, y: $0.y, pressure: $0.pressure, tilt: $0.tilt, azimuth: $0.azimuth, dtUs: $0.dtUs, roll: $0.roll)
            }
        }
        snapState = nil
        edgeLock = nil
        tailSnapped = false
        setGuides([])
        ownStrokes.append(stroke)
        if ProInkDabCache.peek(for: stroke) != nil {
            // 筆點陣現成：立刻交接。
            setNeedsDisplay(stroke.bounds)
            live = nil
            liveCache = nil
            resetLiveBrush()
            syncLiveOverlay(invalidating: liveArea)
        } else {
            // 筆點陣（Rust FFI）放到背景算，主執行緒收筆只做 O(1) 的記帳。
            // 算好之前，即時疊加層繼續顯示這一筆（尾端的預測預覽先清掉），算好才交接給底層 ——
            // 畫面上筆畫不會消失，也不會在 `draw(rect)` 裡臨時同步運算。
            pendingHandoff = stroke
            live = nil
            liveCache = nil
            liveBrush = nil
            liveOverlayView.previewDabs.removeAll()
            liveOverlayView.setNeedsDisplay(liveArea.isNull ? stroke.bounds : liveArea)
            let id = stroke.id
            nonisolated(unsafe) let s = stroke
            BackgroundScheduler.shared.submit(.interactive) {
                if ProInkDabCache.peek(for: s) == nil, let made = ProInkRenderer.cache(for: s) {
                    ProInkDabCache.set(made, for: s)
                }
                DispatchQueue.main.async { [weak self] in self?.completeHandoff(id) }
            }
        }

        persistAppendedStroke(stroke)
        registerUndo(removing: stroke.id)
    }

    func cancelStroke() {
        if live != nil { ProInkCollab.liveHandler?(notebookId, pageIndex, 2, nil, []) }
        let area = live?.bounds.union(lastPredictedArea)
        lastPredictedArea = .null
        snapState = nil
        edgeLock = nil
        tailSnapped = false
        setGuides([])
        live = nil
        liveCache = nil
        resetLiveBrush()
        syncLiveOverlay(invalidating: area)
    }

    private func resetLiveBrush() {
        liveBrush = nil
        liveOverlayView.settledDabs.removeAll(keepingCapacity: true)
        liveOverlayView.previewDabs.removeAll()
    }

    private static func strokePoint(_ p: ProPoint) -> StrokePoint {
        StrokePoint(x: p.x, y: p.y, pressure: p.pressure, tilt: p.tilt, azimuth: p.azimuth, dtUs: p.dtUs, roll: p.roll)
    }

    private func refreshLive(dirtyAround points: [ProPoint], predicted: [ProPoint] = []) {
        guard let stroke = live else { return }
        if let brush = liveBrush {
            // 只算新來的這幾點：已定案的筆點直接接在後面，不必每一幀整筆重算（筆畫越長越慢的根源）。
            liveOverlayView.settledDabs.append(contentsOf: brush.append(points: points.map(Self.strokePoint)))
            liveOverlayView.previewDabs = brush.preview(predicted: predicted.map(Self.strokePoint))
            liveCache = nil
        } else {
            var displayStroke = stroke
            displayStroke.points.append(contentsOf: predicted)
            liveCache = ProInkRenderer.cache(for: displayStroke)
        }
        // 噴槍與油畫筆的筆點比基準寬度大，髒矩形要外擴；新舊點與預測點都要涵蓋，
        // 否則新筆點蓋住的舊筆點邊緣或上一幀預測尾端會留下殘影。
        let tail = Array(stroke.points.suffix(points.count + 2)) + predicted
        let newArea = ProStroke(tool: stroke.tool, colorRGBA: stroke.colorRGBA,
                                baseWidth: stroke.baseWidth, points: tail).bounds
        let dirtyArea = newArea.union(lastPredictedArea)
        if !predicted.isEmpty {
            let predTail = Array(stroke.points.suffix(2)) + predicted
            lastPredictedArea = ProStroke(tool: stroke.tool, colorRGBA: stroke.colorRGBA,
                                          baseWidth: stroke.baseWidth, points: predTail).bounds
        } else {
            lastPredictedArea = .null
        }
        syncLiveOverlay(invalidating: dirtyArea)
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

    /// 擦掉別台的筆畫：從畫面與檔案拿掉，指紋記進「已擦除」名單（舊版相容）、**並在帳本記一筆墓碑**，
    /// 下次匯出就寫進自己的筆畫檔 —— 別台與原作者那台才會一起消失這一筆。可復原。
    private func removeForeign(_ strokes: [ProStroke], registersUndo: Bool = true) {
        guard let directory else { return }
        let ids = Set(strokes.map(\.id))
        foreignStrokes.removeAll { ids.contains($0.id) }
        for stroke in strokes { setNeedsDisplay(stroke.bounds) }
        var keys = ProInkStore.loadSuppressed(in: directory, notebookId: notebookId, page: pageIndex)
        keys.formUnion(strokes.map(\.contentKey))
        ProInkStore.saveSuppressed(keys, in: directory, notebookId: notebookId, page: pageIndex)
        ProInkStore.updateLedger(in: directory, notebookId: notebookId, page: pageIndex) { ledger in
            for stroke in strokes {
                let cid = stroke.id.lowercased()
                if !ledger.retired.contains(where: { $0.coreId == cid }) {
                    ledger.retired.append(.init(coreId: cid, stroke: nil, exported: false, contentKey: stroke.contentKey))
                }
            }
        }
        ProInkStore.save(foreignStrokes, in: directory, notebookId: notebookId, page: pageIndex, foreign: true)
        // 別台的筆畫：擦的當下就寫墓碑（ADR-0015 I2），不等匯出。
        if let sink = InkEventSink.sink(for: notebookId) {
            let packageIds = strokes.map(\.packageId)
            sink.proEdited(page: pageIndex, removedIds: packageIds, added: [])
            tombstonedIds.formUnion(packageIds)
        }
        onChanged?()
        NotificationCenter.default.post(name: AppCommand.proInkDidChange, object: notebookId.lowercased())
        if registersUndo { registerForeignUndo(restoring: strokes) }
    }

    /// 把擦掉的別台筆畫放回來（復原）。回傳**改成自己的複本**的那幾筆的 id。
    ///
    /// 墓碑還沒寫進套件：撤掉帳本那一筆，原樣放回外來區。
    /// 墓碑已經上傳：別台那邊那一筆**永遠消失了**，撤不掉 —— 改在自己名下放一筆內容相同的新筆畫。
    @discardableResult
    private func restoreForeign(_ strokes: [ProStroke]) -> Set<String> {
        guard let directory else { return [] }
        var plain: [ProStroke] = []
        var copies: [ProStroke] = []
        ProInkStore.updateLedger(in: directory, notebookId: notebookId, page: pageIndex) { ledger in
            for stroke in strokes {
                let cid = stroke.id.lowercased()
                // 墓碑已經寫進套件（匯出過，或擦的當下就寫了）：撤不掉，改在自己名下放一筆新的。
                if isTombstoned(cid)
                    || ledger.retired.firstIndex(where: { $0.coreId == cid }).map({ ledger.retired[$0].exported }) == true {
                    var copy = stroke
                    copy.id = UUID().uuidString
                    copies.append(copy)
                } else {
                    ledger.retired.removeAll { $0.coreId == cid && !$0.exported }
                    plain.append(stroke)
                }
            }
        }
        foreignStrokes.append(contentsOf: plain)
        ownStrokes.append(contentsOf: copies)
        for stroke in strokes { setNeedsDisplay(stroke.bounds) }
        var keys = ProInkStore.loadSuppressed(in: directory, notebookId: notebookId, page: pageIndex)
        keys.subtract(plain.map(\.contentKey))
        ProInkStore.saveSuppressed(keys, in: directory, notebookId: notebookId, page: pageIndex)
        ProInkStore.save(foreignStrokes, in: directory, notebookId: notebookId, page: pageIndex, foreign: true)
        if !copies.isEmpty { persist() }
        onChanged?()
        NotificationCenter.default.post(name: AppCommand.proInkDidChange, object: notebookId.lowercased())
        return Set(copies.map(\.id))
    }

    private func registerForeignUndo(restoring strokes: [ProStroke]) {
        guard let manager = undoManagerProvider?() else { return }
        manager.registerUndo(withTarget: self) { layer in
            let copyIds = layer.restoreForeign(strokes)
            if copyIds.isEmpty {
                layer.registerForeignRedo(removing: strokes)
            } else {
                // 放回來的是自己的複本：重做 = 再把複本擦掉。
                layer.registerGroupRedoRemoving(ids: copyIds)
            }
        }
    }

    /// 重做：把這幾筆自己的筆畫拿掉（復原擦除別台筆畫、而墓碑已寫出時放回來的複本）。
    private func registerGroupRedoRemoving(ids: Set<String>) {
        guard let manager = undoManagerProvider?() else { return }
        manager.registerUndo(withTarget: self) { layer in
            let hit = layer.ownStrokes.filter { ids.contains($0.id) }
            layer.ownStrokes.removeAll { ids.contains($0.id) }
            for s in hit { layer.setNeedsDisplay(s.bounds) }
            layer.persist()
            layer.registerUndo(restoring: hit)
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
        guard cachedBounds(stroke).insetBy(dx: -reach, dy: -reach).contains(where: path) else { return false }
        let reachSq = reach * reach
        let pts = stroke.points
        if pts.isEmpty { return false }
        if pts.count == 1 {
            let p = pts[0]
            for q in path {
                let dx = CGFloat(p.x) - q.x
                let dy = CGFloat(p.y) - q.y
                if dx * dx + dy * dy <= reachSq { return true }
            }
            return false
        }
        for q in path {
            for i in 0..<(pts.count - 1) {
                let p1 = pts[i]
                let p2 = pts[i + 1]
                let dx = CGFloat(p2.x - p1.x)
                let dy = CGFloat(p2.y - p1.y)
                let l2 = dx * dx + dy * dy
                let distSq: CGFloat
                if l2 < 1e-6 {
                    let dpx = q.x - CGFloat(p1.x)
                    let dpy = q.y - CGFloat(p1.y)
                    distSq = dpx * dpx + dpy * dpy
                } else {
                    let t = max(0, min(1, ((q.x - CGFloat(p1.x)) * dx + (q.y - CGFloat(p1.y)) * dy) / l2))
                    let projX = CGFloat(p1.x) + t * dx
                    let projY = CGFloat(p1.y) + t * dy
                    let dpx = q.x - projX
                    let dpy = q.y - projY
                    distSq = dpx * dpx + dpy * dpy
                }
                if distSq <= reachSq { return true }
            }
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

    /// 被多邊形圈住（含寬容度判定）、而且圖層動得了（沒隱藏沒鎖定）的筆畫（含本機與外來同步筆畫）。
    func strokeIds(enclosedBy polygon: [Float]) -> Set<String> {
        let drafting = DraftingState.shared
        var polyPoints: [CGPoint] = []
        polyPoints.reserveCapacity(polygon.count / 2)
        var idx = 0
        while idx + 1 < polygon.count {
            polyPoints.append(CGPoint(x: CGFloat(polygon[idx]), y: CGFloat(polygon[idx + 1])))
            idx += 2
        }
        var ids = Set<String>()
        for s in allStrokes where drafting.canEdit(layer: s.layerId, notebookId: notebookId) {
            let flat = s.points.flatMap { [$0.x, $0.y] }
            if lassoEncloses(polygon: polygon, points: flat) || Self.isProStrokeEnclosedTolerant(s, in: polyPoints) {
                ids.insert(s.id)
            }
        }
        return ids
    }

    private static func isProStrokeEnclosedTolerant(_ stroke: ProStroke, in polygon: [CGPoint]) -> Bool {
        guard polygon.count >= 3, !stroke.points.isEmpty else { return false }
        let totalCount = stroke.points.count
        let step = max(1, totalCount / 30)
        var insideCount = 0
        var sampledCount = 0
        for i in stride(from: 0, to: totalCount, by: step) {
            let pt = CGPoint(x: CGFloat(stroke.points[i].x), y: CGFloat(stroke.points[i].y))
            sampledCount += 1
            if isPointInPolygon(pt, polygon: polygon) {
                insideCount += 1
            }
        }
        guard sampledCount > 0 else { return false }
        let ratio = Double(insideCount) / Double(sampledCount)
        if ratio >= 0.55 { return true }
        let b = stroke.bounds
        let center = CGPoint(x: b.midX, y: b.midY)
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

    /// 若套索搬動到外來同步筆畫，先收編為本機筆畫（移除外來區並附加新套件身分），確保搬動與存檔一致。
    private func promoteForeignIfNeeded(ids: Set<String>) {
        let foreignHit = foreignStrokes.filter { ids.contains($0.id) }
        guard !foreignHit.isEmpty else { return }
        removeForeign(foreignHit, registersUndo: false)
        for s in foreignHit {
            var copy = s
            copy.coreId = UUID().uuidString.lowercased()
            ownStrokes.append(copy)
        }
    }

    private var moveIds: Set<String> = []
    private var moveTotal = CGSize.zero

    /// 拖曳搬移：過程中只改記憶體與畫面，放手（`endMove`）才存檔、登記一次復原。
    func move(ids: Set<String>, by delta: CGSize) {
        guard delta != .zero else { return }
        promoteForeignIfNeeded(ids: ids)
        moveIds = ids
        moveTotal.width += delta.width
        moveTotal.height += delta.height
        var dirtyRect = CGRect.null
        for i in ownStrokes.indices where ids.contains(ownStrokes[i].id) {
            let strokeId = ownStrokes[i].id
            let oldBounds = ownStrokes[i].bounds
            dirtyRect = dirtyRect.union(oldBounds)
            for k in ownStrokes[i].points.indices {
                ownStrokes[i].points[k].x += Float(delta.width)
                ownStrokes[i].points[k].y += Float(delta.height)
            }
            if let existing = ProInkDabCache.get(for: ownStrokes[i]) {
                ProInkDabCache.set(existing.translated(by: delta), for: ownStrokes[i])
            }
            dirtyRect = dirtyRect.union(ownStrokes[i].bounds)
        }
        if !dirtyRect.isNull {
            setNeedsDisplay(dirtyRect.insetBy(dx: -8, dy: -8))
        }
    }

    func endMove() {
        guard !moveIds.isEmpty else { return }
        let ids = moveIds, total = moveTotal
        moveIds = []
        moveTotal = .zero
        retireForModification(ids: ids)
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
            layer.retireForModification(ids: ids)
            layer.persist()
            layer.registerMoveUndo(ids: ids, delta: CGSize(width: -delta.width, height: -delta.height))
        }
    }

    func delete(ids: Set<String>) {
        let foreignHit = foreignStrokes.filter { ids.contains($0.id) }
        if !foreignHit.isEmpty {
            removeForeign(foreignHit)
        }
        let hit = ownStrokes.filter { ids.contains($0.id) }
        guard !hit.isEmpty else { return }
        ownStrokes.removeAll { ids.contains($0.id) }
        for s in hit { setNeedsDisplay(s.bounds) }
        persist()
        registerUndo(restoring: hit)
    }

    func strokes(ids: Set<String>) -> [ProStroke] { allStrokes.filter { ids.contains($0.id) } }

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
    /// 封閉區域填色：在 `point`（頁面座標）找出這一頁筆畫圍成的封閉區域，用麥克筆掃滿（整組一次復原）。
    /// 計算在核心（`fill_region_paths`，與 Android 共用）。找不到封閉區域時回 `false`、什麼都不加。
    func fillRegion(at point: CGPoint, color: [UInt8], width: Float, paperId: String = "blank") -> Bool {
        // 邊界 = 這一頁的筆跡 ＋ 紙上的引導線（空白地圖的國界不是筆跡）。與 Android 相同。
        let outlines = allStrokes.filter { !$0.points.isEmpty }.map { stroke in
            FfiFillOutline(points: stroke.points.map { FfiPoint(x: $0.x, y: $0.y) }, width: stroke.baseWidth)
        } + paperFillOutlines(paperId: paperId, width: Float(PageGeometry.width), height: Float(PageGeometry.height))
        let paths = fillRegionPaths(seedX: Float(point.x), seedY: Float(point.y), outlines: outlines, brushWidth: width)
        guard !paths.isEmpty, let marker = ProInk.name(of: .marker) else { return false }
        let made: [ProStroke] = paths.compactMap { path in
            // 路徑只有轉折點：補成每 4 個單位一點，筆點陣才連續。
            var points: [ProPoint] = []
            for (a, b) in zip(path, path.dropFirst()) {
                let steps = max(1, Int((hypot(b.x - a.x, b.y - a.y) / 4).rounded(.up)))
                for k in 0..<steps {
                    let t = Float(k) / Float(steps)
                    points.append(ProPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t,
                                           pressure: 0.5, tilt: 0, azimuth: 0, dtUs: 8_000))
                }
            }
            if let last = path.last {
                points.append(ProPoint(x: last.x, y: last.y, pressure: 0.5, tilt: 0, azimuth: 0, dtUs: 8_000))
            }
            guard points.count >= 2 else { return nil }
            return ProStroke(tool: marker, colorRGBA: color, baseWidth: width, points: points)
        }
        return !insert(copies: made).isEmpty
    }

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
        // 鎖定與隱藏的圖層**也能改**：改圖層本身就是搬動的動作，使用者要把線搬出鎖定的圖層
        // 或把隱藏圖層裡的線救出來，正是靠這個（鎖定只擋「畫」與「擦」）。
        var best: (index: Int, distance: CGFloat)?
        for (i, stroke) in strokes.enumerated() {
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
            let restoredCopies = layer.restoreForeign([original])
            // 重做：再改一次同一筆。原筆畫的墓碑已經寫出時，放回來的是自己的複本，重做就是改它的圖層。
            manager.registerUndo(withTarget: layer) { again in
                if let restored = restoredCopies.first {
                    again.setLayer(target, ofStroke: restored)
                    again.registerLayerUndo(strokeId: restored, previous: original.layerId)
                } else {
                    again.redoForeignReassign(original: original, to: target, copyId: copyId)
                }
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
        retireForModification(ids: [id])
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
    /// 系統的選單（`Menu`／`UIContextMenuInteraction`）正開著或正在關閉。
    /// 只看視窗第一層：選單容器就掛在那裡，成本是幾個子視圖的類別名稱比對。
    static func isDismissingMenu(in window: UIWindow?) -> Bool {
        guard let window else { return false }
        return window.subviews.contains { NSStringFromClass(type(of: $0)).contains("ContextMenu") }
    }

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
    /// 橡皮擦軌跡：落筆與拖曳時回報觸控點（畫布座標），抬筆／取消時回報 `nil`。
    ///
    /// 畫布用它把「橡皮擦實際涵蓋範圍」的圓圈畫在手指／筆尖底下。只靠懸停的話，
    /// 一碰到螢幕圓圈就消失（而且沒有懸停硬體的 iPad 與手指從來看不到）——
    /// 使用者看到的只剩系統的十字，判斷不了自己正在擦多大一塊。
    var onEraserTrack: ((CGPoint?) -> Void)?
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
    /// 壓感下限與曲線：落筆時讀一次。每個取樣點（Pencil 每秒 240 個）都去讀偏好設定是白花的主執行緒時間。
    private var pressureFloor: Float = 0.15
    private var pressureGamma: Float = 1.0
    private var erasePath: [CGPoint] = []
    /// 手指智慧力道模擬（Smart Finger Dynamics）狀態：初始觸控半徑、前一點位置、平滑壓感與點序。
    private var initialTouchRadius: CGFloat = 0
    private var lastSampleLocation: CGPoint?
    private var smoothedFingerPressure: Float = 0.56
    private var strokeSampleIndex: Int = 0

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
        // 選單（例如「插入」）還開著時點畫布：那一下是「關掉選單」，不是書寫。
        // 以前會在點下去的地方留下一個墨點（實測）。選單關閉的動畫期間它還在視窗裡，這裡就認得出來。
        if Self.isDismissingMenu(in: view?.window) { state = .failed; return }

        tracked = touch
        lastTimestamp = touch.timestamp
        let prefs = ProfileDefaults.current
        let rawFloor = prefs.object(forKey: "kairumo.pen.pressureFloor") != nil
            ? Double(prefs.float(forKey: "kairumo.pen.pressureFloor"))
            : 0.15
        let rawGamma = prefs.object(forKey: "kairumo.pen.pressureGamma") != nil
            ? Double(prefs.float(forKey: "kairumo.pen.pressureGamma"))
            : 1.0
        pressureFloor = Float(max(0.0, min(0.5, rawFloor)))
        pressureGamma = Float(max(0.4, min(2.2, rawGamma)))
        initialTouchRadius = max(touch.majorRadius, 4.0)
        lastSampleLocation = nil
        smoothedFingerPressure = 0.54
        strokeSampleIndex = 0
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
        if (mode == .draw || mode == .erase),
           ProInkCollab.canBeginEdit?(layerView.notebookId, layerView.pageIndex) == false {
            tracked = nil
            state = .failed
            return
        }
        state = .began
        switch mode {
        case .draw:
            guard let tool = tool() else { state = .failed; return }
            beginDrawing(tool: tool, at: point, in: layerView)
        case .erase:
            ProInkCollab.liveHandler?(layerView.notebookId, layerView.pageIndex, 0, nil, [point])
            erasePath = [CGPoint(x: CGFloat(point.x), y: CGFloat(point.y))]
            layerView.erase(along: erasePath, radius: eraserRadius())
            if let view { onEraserTrack?(touch.location(in: view)) }
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
            guard let tool = tool(),
                  ProInkCollab.canBeginEdit?(layerView.notebookId, layerView.pageIndex) != false else {
                pendingBegin = nil
                tracked = nil
                state = .failed
                return
            }
            beginDrawing(tool: tool, at: pending.point, in: layerView)
            pendingBegin = nil
            state = .began
        }
        // 合併觸控（coalesced）才有完整的取樣率；預測觸控（predicted）僅供當幀畫面前端視覺補償，不寫入真實筆畫點列。
        let samples = event.coalescedTouches(for: touch) ?? [touch]
        var points: [ProPoint] = []
        for sample in samples {
            let dt = UInt32(max(0, (sample.timestamp - lastTimestamp) * 1_000_000))
            lastTimestamp = sample.timestamp
            points.append(makePoint(sample, in: layerView, dt: dt))
        }
        switch mode {
        case .draw:
            var predictedPoints: [ProPoint] = []
            if let predicted = event.predictedTouches(for: touch), !predicted.isEmpty {
                var predTime = lastTimestamp
                for pTouch in predicted.prefix(3) {
                    let dt = UInt32(max(0, (pTouch.timestamp - predTime) * 1_000_000))
                    predTime = max(predTime, pTouch.timestamp)
                    predictedPoints.append(makePoint(pTouch, in: layerView, dt: dt, isPrediction: true))
                }
            }
            layerView.extendStroke(with: points, predicted: predictedPoints)
            if let last = points.last { rearmHold(at: CGPoint(x: CGFloat(last.x), y: CGFloat(last.y))) }
        case .erase:
            ProInkCollab.liveHandler?(layerView.notebookId, layerView.pageIndex, 1, nil, points)
            let path = points.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
            erasePath.append(contentsOf: path)
            layerView.erase(along: path, radius: eraserRadius())
            if let view { onEraserTrack?(touch.location(in: view)) }
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
        if mode == .erase {
            if let layerView { ProInkCollab.liveHandler?(layerView.notebookId, layerView.pageIndex, 2, nil, []) }
            onEraserTrack?(nil)
        }
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
        if mode == .erase, let layerView {
            ProInkCollab.liveHandler?(layerView.notebookId, layerView.pageIndex, 2, nil, [])
        }
        cancelCurrent()
        state = .cancelled
    }

    override func reset() {
        if mode == .erase, tracked != nil { onEraserTrack?(nil) }
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
        if mode == .erase { onEraserTrack?(nil) }
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

    private func makePoint(_ touch: UITouch, in view: UIView, dt: UInt32, isPrediction: Bool = false) -> ProPoint {
        let location = touch.preciseLocation(in: view)
        let floorVal = pressureFloor
        let gammaVal = pressureGamma

        let pressure: Float
        if touch.type == .pencil || touch.maximumPossibleForce > 0, touch.force > 0 {
            let raw = Float(min(1, max(0, touch.force / max(touch.maximumPossibleForce, 0.0001))))
            let curved = powf(raw, gammaVal)
            pressure = min(1, max(0.02, floorVal * 0.45 + (1 - floorVal * 0.45) * curved))
        } else {
            // 方案二：手指書寫「智慧力道模擬引擎（Smart Finger Dynamics）」
            // 結合 (1) 指腹接觸面積變化 (majorRadius)、(2) 行筆速度（疾細徐粗 / 駐筆頓挫）、(3) 起筆入鋒包絡線
            let radiusRatio = Float(max(0.65, min(1.55, touch.majorRadius / max(initialTouchRadius, 4.0))))
            let areaDelta = (radiusRatio - 1.0) * 0.48
            let velAdjust: Float
            if let prev = lastSampleLocation, dt > 0 {
                let dist = Float(hypot(location.x - prev.x, location.y - prev.y))
                let dtMs = max(1.0, Float(dt) / 1000.0)
                let speed = dist / dtMs // pt/ms
                if speed < 0.45 {
                    // 慢速駐筆／轉折頓挫：自動加粗蓄墨
                    velAdjust = (0.45 - speed) * 0.42
                } else {
                    // 快速疾掠／撇捺出鋒：自動收細勁瘦
                    velAdjust = -min(0.32, (speed - 0.45) * 0.15)
                }
            } else {
                velAdjust = 0.06 // 落筆第一點微頓
            }
            let entryRamp = min(1.0, 0.78 + Float(strokeSampleIndex) * 0.08)
            let target = min(0.96, max(0.16, (0.58 + areaDelta + velAdjust) * entryRamp))
            let blended = smoothedFingerPressure * 0.42 + target * 0.58
            if !isPrediction {
                smoothedFingerPressure = blended
            }
            let curved = powf(blended, gammaVal)
            pressure = min(0.98, max(0.12, floorVal * 0.35 + (1 - floorVal * 0.35) * curved))
        }
        if !isPrediction {
            lastSampleLocation = location
            strokeSampleIndex += 1
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


/// 背景烘焙的取消旗標（可跨執行緒）。
final class BakeToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
}
