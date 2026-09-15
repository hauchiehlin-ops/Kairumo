//
//  AssetLibraryManager.swift
//  Kairumo
//
//  三大主題實體素材圖庫隨需下載與快取管理員
//  內容涵蓋：機構設計、3C 電子、汽車載具、工業家具、五金零件與數位線框
//  以「實體規格圖 (Physical Specs)」為主（>75%），「AI 概念渲染 (AI Concepts)」為輔
//

import SwiftUI
import UIKit

/// 圖庫核心主題分類（涵蓋機構、3C、汽車、家具、五金、數位，以及三大主題深度擴充）
public enum AssetCategory: String, CaseIterable, Identifiable, Codable {
    case all = "全部"

    // 經典實體產業大類
    case mechanism = "機構設計"
    case electronics3C = "3C 電子"
    case automotive = "汽車載具"
    case furniture = "工業家具"
    case hardware = "五金零件"
    case digital = "數位產品"

    // 美學視覺擴充 (Aesthetic & Visual)
    case aestheticComposition = "美學構圖與黃金比例"
    case typography = "字體排印與版面網格"
    case designMotifs = "造型語彙與工藝紋樣"

    // 工程製程擴充 (Engineering & Manufacturing)
    case toolingMolding = "模具與注塑成型"
    case sheetMetalCNC = "鈑金折彎與 CNC 加工"
    case surfaceFinishing = "表面處理與材料工藝"
    case pneumaticsPiping = "機構傳動與流體管路"

    // 數位體驗擴充 (Digital UX & UI)
    case crossPlatformUI = "跨平台系統標準件"
    case uxMotion = "互動手勢與動效軌跡"
    case infoArchitecture = "資訊架構與服務流程"
    case designTokens = "設計系統原子元件"

    public var id: String { rawValue }

    public var themeCategory: NoteThemeCategory? {
        switch self {
        case .all:
            return nil
        case .furniture, .aestheticComposition, .typography, .designMotifs:
            return .aesthetic
        case .mechanism, .electronics3C, .automotive, .hardware, .toolingMolding, .sheetMetalCNC, .surfaceFinishing, .pneumaticsPiping:
            return .engineering
        case .digital, .crossPlatformUI, .uxMotion, .infoArchitecture, .designTokens:
            return .digital
        }
    }

    public var iconName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .mechanism: return "gearshape.2.fill"
        case .electronics3C: return "laptopcomputer.and.iphone"
        case .automotive: return "car.fill"
        case .furniture: return "chair.lounge.fill"
        case .hardware: return "wrench.and.screwdriver.fill"
        case .digital: return "macwindow"

        case .aestheticComposition: return "camera.metering.center.weighted"
        case .typography: return "textformat.size"
        case .designMotifs: return "circle.hexagongrid.fill"

        case .toolingMolding: return "cube.transparent.fill"
        case .sheetMetalCNC: return "scissors"
        case .surfaceFinishing: return "sparkle"
        case .pneumaticsPiping: return "point.topleft.down.curvedto.point.bottomright.up"

        case .crossPlatformUI: return "rectangle.portrait.on.rectangle.portrait.angled"
        case .uxMotion: return "hand.tap.fill"
        case .infoArchitecture: return "arrow.triangle.branch"
        case .designTokens: return "puzzlepiece.fill"
        }
    }

    public var localizationKey: String {
        switch self {
        case .all: return "cat_all"
        case .mechanism: return "cat_mechanism"
        case .electronics3C: return "cat_electronics"
        case .automotive: return "cat_automotive"
        case .furniture: return "cat_furniture"
        case .hardware: return "cat_hardware"
        case .digital: return "cat_digital"

        case .aestheticComposition: return "cat_aesthetic_comp"
        case .typography: return "cat_typography"
        case .designMotifs: return "cat_design_motifs"

        case .toolingMolding: return "cat_tooling_molding"
        case .sheetMetalCNC: return "cat_sheetmetal_cnc"
        case .surfaceFinishing: return "cat_surface_finishing"
        case .pneumaticsPiping: return "cat_pneumatics_piping"

        case .crossPlatformUI: return "cat_crossplatform_ui"
        case .uxMotion: return "cat_ux_motion"
        case .infoArchitecture: return "cat_info_arch"
        case .designTokens: return "cat_design_tokens"
        }
    }
}

/// 素材來源型態（實體規格線稿 vs AI 視覺概念）
public enum AssetSourceType: String, CaseIterable, Identifiable, Codable {
    case physicalSpec = "實體規格圖"
    case aiConcept = "AI 概念渲染"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .physicalSpec: return "cube.fill"
        case .aiConcept: return "sparkles"
        }
    }

    public var localizationKey: String {
        switch self {
        case .physicalSpec: return "filter_physical"
        case .aiConcept: return "filter_ai"
        }
    }
}

/// 圖庫單一物件模型
public struct AssetItem: Identifiable, Codable, Hashable {
    public let id: String
    public let title: String
    public let category: AssetCategory
    public let sourceType: AssetSourceType
    public let specsSummary: String
    public let materialSuggestion: String
    public let dimensionsMm: String
    public let fileSizeMB: Double
    public var isDownloaded: Bool
    public let drawingCode: String

    public init(
        id: String,
        title: String,
        category: AssetCategory,
        sourceType: AssetSourceType,
        specsSummary: String,
        materialSuggestion: String,
        dimensionsMm: String,
        fileSizeMB: Double,
        isDownloaded: Bool = false,
        drawingCode: String
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.sourceType = sourceType
        self.specsSummary = specsSummary
        self.materialSuggestion = materialSuggestion
        self.dimensionsMm = dimensionsMm
        self.fileSizeMB = fileSizeMB
        self.isDownloaded = isDownloaded
        self.drawingCode = drawingCode
    }
}

/// 素材圖庫管理員（提供單件隨需下載、整類主題下載、快取清除與本機容量統計）
@MainActor
public final class AssetLibraryManager: ObservableObject {
    public static let shared = AssetLibraryManager()

    @Published public var items: [AssetItem] = []
    @Published public var downloadedItemIds: Set<String> = []
    @Published public var downloadingItemIds: Set<String> = []

    private let downloadedDefaultsKey = "Kairumo_Downloaded_Asset_Ids_v1"

    private init() {
        loadDownloadedState()
        seedLibraryItems()
        reconcileWithDisk()
        updateItemStates()
    }

    /// 素材快取目錄。
    ///
    /// 素材是由向量繪圖程式在本機算繪出來的，沒有遠端伺服器可下載 ——
    /// 所謂「下載」實際上是**算繪並落盤**。以前這裡只是跑一個 0.6 秒的計時器把
    /// 布林值翻成 true，容量數字也是寫死的，畫面上那句「已下載 4 (7.3 MB)」
    /// 完全是假的。現在真的產出 PNG 檔，容量也照實際位元組數回報。
    public var assetsDirectory: URL {
        let dir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AssetLibrary", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    public func fileURL(for id: String) -> URL {
        assetsDirectory.appendingPathComponent("\(id).png")
    }

    /// 各素材實際佔用的位元組數（僅已落盤者）。
    @Published public private(set) var cachedSizes: [String: Int] = [:]

    /// 總計本機已快取容量 (MB)，來自真實檔案大小。
    public var totalDownloadedSizeMB: Double {
        Double(cachedSizes.values.reduce(0, +)) / 1_048_576.0
    }

    /// 單一素材的實際大小 (MB)。尚未落盤時回傳 nil。
    public func cachedSizeMB(for id: String) -> Double? {
        guard let bytes = cachedSizes[id] else { return nil }
        return Double(bytes) / 1_048_576.0
    }

    /// 檢查是否已落盤。以**檔案是否存在**為準，而不是只看旗標 ——
    /// 使用者可能從系統層把 Documents 清掉。
    public func isDownloaded(_ id: String) -> Bool {
        downloadedItemIds.contains(id)
    }

    /// 算繪並落盤指定素材。
    public func downloadItem(id: String) {
        guard !downloadedItemIds.contains(id), !downloadingItemIds.contains(id) else { return }
        guard let item = items.first(where: { $0.id == id }) else { return }
        downloadingItemIds.insert(id)

        Task { @MainActor in
            let bytes = await self.materialize(item)
            self.downloadingItemIds.remove(id)
            guard bytes > 0 else { return }
            self.downloadedItemIds.insert(id)
            self.cachedSizes[id] = bytes
            self.saveDownloadedState()
            self.updateItemStates()
        }
    }

    /// 一鍵算繪整個主題包。
    public func downloadCategory(_ category: AssetCategory) {
        let targets = items.filter {
            (category == .all || $0.category == category) && !downloadedItemIds.contains($0.id)
        }
        guard !targets.isEmpty else { return }
        for it in targets { downloadingItemIds.insert(it.id) }

        Task { @MainActor in
            for it in targets {
                let bytes = await self.materialize(it)
                self.downloadingItemIds.remove(it.id)
                if bytes > 0 {
                    self.downloadedItemIds.insert(it.id)
                    self.cachedSizes[it.id] = bytes
                }
            }
            self.saveDownloadedState()
            self.updateItemStates()
        }
    }

    /// 把素材算繪成 PNG 寫進快取目錄，回傳實際位元組數（失敗為 0）。
    ///
    /// 算繪在主執行緒完成（UIGraphics 需要），寫檔丟到背景 —— 一次算 50 幾張的
    /// 「下載本類全部」若整包同步跑會卡住畫面。
    private func materialize(_ item: AssetItem) async -> Int {
        let image = renderItemImage(for: item)
        let url = fileURL(for: item.id)
        return await Task.detached(priority: .utility) {
            guard let data = image.pngData() else { return 0 }
            do {
                try data.write(to: url, options: .atomic)
                return data.count
            } catch {
                return 0
            }
        }.value
    }

    /// 讀回已落盤的素材。
    public func cachedImage(for id: String) -> UIImage? {
        UIImage(contentsOfFile: fileURL(for: id).path)
    }

    /// 移除指定素材之本機快取
    public func removeItem(id: String) {
        try? FileManager.default.removeItem(at: fileURL(for: id))
        downloadedItemIds.remove(id)
        cachedSizes.removeValue(forKey: id)
        saveDownloadedState()
        updateItemStates()
    }

    /// 一鍵清除所有素材快取（釋放本機硬碟空間）
    public func clearAllCache() {
        for id in downloadedItemIds {
            try? FileManager.default.removeItem(at: fileURL(for: id))
        }
        downloadedItemIds.removeAll()
        cachedSizes.removeAll()
        saveDownloadedState()
        updateItemStates()
    }

    /// 以磁碟上的實際檔案為準，重建已快取清單與容量統計。
    private func reconcileWithDisk() {
        var present: Set<String> = []
        var sizes: [String: Int] = [:]
        for id in downloadedItemIds {
            let url = fileURL(for: id)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int {
                present.insert(id)
                sizes[id] = size
            }
        }
        downloadedItemIds = present
        cachedSizes = sizes
        saveDownloadedState()
    }

    private func updateItemStates() {
        for i in 0..<items.count {
            items[i].isDownloaded = downloadedItemIds.contains(items[i].id)
        }
    }

    private func loadDownloadedState() {
        if let saved = UserDefaults.standard.array(forKey: downloadedDefaultsKey) as? [String] {
            self.downloadedItemIds = Set(saved)
        }
        // 已下載清單一律以磁碟實況為準；舊版會預先塞 4 個 id 假裝已下載，
        // 但那些檔案從來不存在。
    }

    private func saveDownloadedState() {
        UserDefaults.standard.set(Array(downloadedItemIds), forKey: downloadedDefaultsKey)
    }

    // MARK: - 圖庫資料集

    /// 目錄來自**核心** `assetItems()`。
    ///
    /// 原本這裡是 680 行寫死的陣列，Android 沒有對應品。下沉之後兩個平台
    /// 看到的是同一批素材、同樣的分類與同樣的規格 —— 而且新增一件素材
    /// 只要改核心一個地方，不會出現「iPad 上有、手機上沒有」。
    private func seedLibraryItems() {
        items = assetItems().map { core in
            AssetItem(
                id: core.id,
                title: core.title,
                category: AssetCategory(core: core.category),
                sourceType: core.source == .physicalSpec ? .physicalSpec : .aiConcept,
                specsSummary: core.specs,
                materialSuggestion: core.material,
                dimensionsMm: core.dimensions,
                fileSizeMB: Double(core.fileSizeMb),
                drawingCode: core.drawingCode
            )
        }
    }

    // MARK: - 高解析度實體工業線圖/概念圖向量產生器
    /// 將圖庫項目渲染為畫布適用的高品質 UIImage
    /// 目前這次算繪使用的樣式。
    ///
    /// 用實例屬性而非逐一傳參數：`drawObjectGraphics` 與它的呼叫端之間隔著
    /// 一個 `UIGraphicsImageRenderer` 的 closure，多帶兩個參數只是噪音。
    /// `AssetLibraryManager` 是 `@MainActor`，算繪從頭到尾在同一執行緒同步
    /// 完成，不會有交錯問題。
    private var currentStyle: AssetRenderStyle = .blueprint

    /// 素材算繪樣式。
    public enum AssetRenderStyle: String, CaseIterable, Codable {
        /// 工程線框：藍圖風格，只有線條。
        case blueprint
        /// 實物：填色 + 投影，看起來像一個實際的物件而非圖紙。
        case solid
    }

    /// 算繪素材圖。
    ///
    /// 分兩段做：幾何先畫在**透明**圖層上，再決定要不要鋪底圖。這樣「背景透明」
    /// 不是把底色塗成白色再挖掉，而是真的從來沒畫過底 —— 貼進筆記頁面時不會
    /// 壓住底下的手寫線條或紙張紋理。
    ///
    /// - Parameters:
    ///   - style: 線框或實物。
    ///   - transparent: true 時不畫方格底與標題欄，輸出可直接疊在畫布上。
    public func renderItemImage(
        for item: AssetItem,
        style: AssetRenderStyle = .blueprint,
        transparent: Bool = false
    ) -> UIImage {
        let size = CGSize(width: 400, height: 400)
        let isDark = (item.sourceType == .aiConcept) && !transparent

        // --- 第一段：只有幾何，背景全透明 ---
        let artFormat = UIGraphicsImageRendererFormat.default()
        artFormat.opaque = false
        let art = UIGraphicsImageRenderer(size: size, format: artFormat).image { ctx in
            currentStyle = style
            defer { currentStyle = .blueprint }
            drawObjectGraphics(code: item.drawingCode, cg: ctx.cgContext, isDark: isDark)
        }

        // --- 第二段：合成 ---
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            let rect = CGRect(origin: .zero, size: size)

            if !transparent {
                if isDark {
                    cg.setFillColor(UIColor(red: 0.1, green: 0.12, blue: 0.18, alpha: 1.0).cgColor)
                    cg.fill(rect)
                    cg.setStrokeColor(UIColor.cyan.withAlphaComponent(0.12).cgColor)
                } else {
                    cg.setFillColor(UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1.0).cgColor)
                    cg.fill(rect)
                    cg.setStrokeColor(UIColor.systemBlue.withAlphaComponent(0.1).cgColor)
                }
                cg.setLineWidth(0.8)
                var x: CGFloat = 20
                while x < 400 {
                    cg.move(to: CGPoint(x: x, y: 0))
                    cg.addLine(to: CGPoint(x: x, y: 400))
                    x += 20
                }
                var y: CGFloat = 20
                while y < 400 {
                    cg.move(to: CGPoint(x: 0, y: y))
                    cg.addLine(to: CGPoint(x: 400, y: y))
                    y += 20
                }
                cg.strokePath()
            }

            // 實物模式加一道整體投影，讓物件從紙面上「浮起來」。
            // 對整張圖層下陰影而不是逐個形狀，否則內部細節線也會各自投影，糊成一片。
            if style == .solid {
                cg.saveGState()
                cg.setShadow(
                    offset: CGSize(width: 0, height: 6),
                    blur: 14,
                    color: UIColor.black.withAlphaComponent(transparent ? 0.28 : 0.18).cgColor
                )
                art.draw(in: rect)
                cg.restoreGState()
            } else {
                art.draw(in: rect)
            }

            guard !transparent else { return }

            // 底部標註規格小標題欄
            let titleBox = CGRect(x: 16, y: 350, width: 368, height: 36)
            cg.setFillColor((isDark ? UIColor.black.withAlphaComponent(0.6) : UIColor.white.withAlphaComponent(0.85)).cgColor)
            cg.addPath(UIBezierPath(roundedRect: titleBox, cornerRadius: 6).cgPath)
            cg.fillPath()

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .bold),
                .foregroundColor: isDark ? UIColor.cyan : UIColor(red: 0.05, green: 0.35, blue: 0.75, alpha: 1.0)
            ]
            let key = "asset_\(item.id)_title"
            let localizedTitle = LocalizationManager.shared.localizedUnsafe(key)
            let subtitle = "\((localizedTitle == key ? item.title : localizedTitle))  [\(item.dimensionsMm)]"
            (subtitle as NSString).draw(at: CGPoint(x: 26, y: 360), withAttributes: attrs)
        }
    }

    // MARK: - 線圖繪製

    /// 把核心給的路徑畫進 CoreGraphics。
    ///
    /// **圖形本身在核心**（`assetDrawing()`）。原本這裡是 1,200 行的
    /// CoreGraphics 程式碼，58 件素材各一段；Android 要畫出同樣的圖就得
    /// 再寫一份 Compose 版，而兩份繪圖程式必然會漂移 —— 沒有任何測試
    /// 抓得到「同一件素材在兩個平台上長得不一樣」。
    ///
    /// 現在這裡只認得路徑指令，不知道自己畫的是齒輪還是螺栓。
    private func drawObjectGraphics(code: String, cg: CGContext, isDark: Bool) {
        let palette = assetPalette(style: currentStyle == .solid ? .solid : .blueprint, dark: isDark)
        let strokeColor = UIColor(hexString: palette.strokeHex) ?? .systemBlue
        let accentColor = UIColor(hexString: palette.accentHex) ?? .systemRed
        let fillColor = UIColor(hexString: palette.fillHex)

        var paths = assetDrawing(code: code)
        // 尺寸引線只在線框模式出現：實物模式是要貼進筆記當一個物件用的，
        // 帶著工程標註反而變成雜訊。
        if currentStyle == .blueprint {
            paths += assetDimensionCallout()
        }

        for item in paths {
            let path = cgPath(from: item.segs)
            cg.saveGState()
            cg.setLineWidth(CGFloat(item.width))
            cg.setStrokeColor((item.accent ? accentColor : strokeColor).cgColor)
            if item.dashed {
                cg.setLineDash(phase: 0, lengths: [5, 4])
            }
            // 指定填色（瀏覽器線框的紅黃綠）優先於風格填色，而且**線框模式也填** ——
            // 那三顆點就是靠顏色辨識的，少了顏色只是三個一樣的圈圈。
            if let override = UIColor(hexString: item.fillOverrideHex) {
                cg.addPath(path)
                cg.setFillColor(override.cgColor)
                cg.fillPath()
            } else if item.fillable, currentStyle == .solid, let fill = fillColor {
                cg.addPath(path)
                cg.setFillColor(fill.cgColor)
                cg.fillPath()
            }
            cg.addPath(path)
            cg.strokePath()
            cg.restoreGState()
        }
    }

    /// 路徑指令 → `CGPath`。
    private func cgPath(from segs: [FfiPathSeg]) -> CGPath {
        let path = CGMutablePath()
        for s in segs {
            let point = CGPoint(x: CGFloat(s.x), y: CGFloat(s.y))
            switch s.verb {
            case .move:
                path.move(to: point)
            case .line:
                path.addLine(to: point)
            case .curve:
                path.addCurve(
                    to: point,
                    control1: CGPoint(x: CGFloat(s.c1x), y: CGFloat(s.c1y)),
                    control2: CGPoint(x: CGFloat(s.c2x), y: CGFloat(s.c2y))
                )
            case .close:
                path.closeSubpath()
            }
        }
        return path
    }
}

extension AssetCategory {
    /// 核心的分類 → Apple 端的列舉。
    ///
    /// 兩份列舉刻意保持**同名同序**，所以這裡是逐一對照而不是靠 rawValue ——
    /// rawValue 是給人看的中文字串，之後要在地化時會換掉。
    init(core: FfiAssetCategory) {
        switch core {
        case .mechanism: self = .mechanism
        case .electronics3C: self = .electronics3C
        case .automotive: self = .automotive
        case .furniture: self = .furniture
        case .hardware: self = .hardware
        case .digital: self = .digital
        case .aestheticComposition: self = .aestheticComposition
        case .typography: self = .typography
        case .designMotifs: self = .designMotifs
        case .toolingMolding: self = .toolingMolding
        case .sheetMetalCnc: self = .sheetMetalCNC
        case .surfaceFinishing: self = .surfaceFinishing
        case .pneumaticsPiping: self = .pneumaticsPiping
        case .crossPlatformUi: self = .crossPlatformUI
        case .uxMotion: self = .uxMotion
        case .infoArchitecture: self = .infoArchitecture
        case .designTokens: self = .designTokens
        }
    }
}
