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

    // MARK: - 精選圖庫資料集（涵蓋機構、3C、汽車、家具、五金、數位）
    private func seedLibraryItems() {
        var list: [AssetItem] = []

        // 1. 機構設計 (Mechanism)
        list.append(AssetItem(
            id: "mech_01",
            title: "漸開線正齒輪組 (Spur Gears)",
            category: .mechanism,
            sourceType: .physicalSpec,
            specsSummary: "模數 M2.0、24T/48T 減速比 1:2、壓力角 20°、JIS 2 級精度",
            materialSuggestion: "SCM440 鉻鉬合金鋼 / 滲碳淬火 HRC 58-62",
            dimensionsMm: "Ø52 x 15 mm / Ø100 x 15 mm",
            fileSizeMB: 1.8,
            drawingCode: "gear_pair"
        ))
        list.append(AssetItem(
            id: "mech_02",
            title: "平面圓柱滾子軸承 (Cylindrical Roller Bearing)",
            category: .mechanism,
            sourceType: .physicalSpec,
            specsSummary: "ISO 15 標準、基本動額定負荷 42.5kN、徑向高剛性承載",
            materialSuggestion: "高碳鉻軸承鋼 GCr15 / 保持架黃銅 H62",
            dimensionsMm: "Ø30 (內) x Ø62 (外) x 16 (寬) mm",
            fileSizeMB: 2.1,
            drawingCode: "bearing_iso"
        ))
        list.append(AssetItem(
            id: "mech_03",
            title: "精密微型滾珠螺桿滑軌 (Linear Guide & Carriage)",
            category: .mechanism,
            sourceType: .physicalSpec,
            specsSummary: "四方向等負荷規格、導程 5mm、走行動態平行度 < 0.003mm",
            materialSuggestion: "SUJ2 軸承鋼導軌 + 不鏽鋼封蓋",
            dimensionsMm: "軌寬 15mm x 長 250mm x 高 28mm",
            fileSizeMB: 3.2,
            drawingCode: "linear_guide"
        ))
        list.append(AssetItem(
            id: "mech_04",
            title: "等徑盤形凸輪連桿機構 (Disk Cam & Follower)",
            category: .mechanism,
            sourceType: .physicalSpec,
            specsSummary: "簡諧運動輪廓線、行程 20mm、最大推力角 28°",
            materialSuggestion: "S45C 中碳鋼 / 高週波熱處理 HRC 50",
            dimensionsMm: "基圓 Ø60 mm / 最大升程 20 mm",
            fileSizeMB: 2.4,
            drawingCode: "cam_follower"
        ))
        list.append(AssetItem(
            id: "mech_05",
            title: "NEMA 17 混合式步進馬達 (Stepper Motor)",
            category: .mechanism,
            sourceType: .physicalSpec,
            specsSummary: "步距角 1.8°、保持扭矩 45N·cm、雙極 4 線驅動",
            materialSuggestion: "矽鋼片定子 + 鋁合金端蓋 + 釹鐵硼轉子",
            dimensionsMm: "42 x 42 x 40 mm / 軸徑 Ø5 mm",
            fileSizeMB: 2.7,
            drawingCode: "stepper_motor"
        ))
        list.append(AssetItem(
            id: "mech_06",
            title: "動態外骨骼關節連桿 (Exoskeleton Biomechanical Joint)",
            category: .mechanism,
            sourceType: .aiConcept,
            specsSummary: "仿生雙心瞬時迴轉軸心、減輕人體膝關節垂直負荷 35%",
            materialSuggestion: "Ti-6Al-4V 鈦合金 3D 列印拓撲優化結構",
            dimensionsMm: "140 x 85 x 35 mm",
            fileSizeMB: 4.5,
            drawingCode: "ai_exoskeleton"
        ))

        // 2. 實體產品 - 3C 電子 (Electronics 3C)
        list.append(AssetItem(
            id: "elec_01",
            title: "旗艦手機鋁合金中框結構 (Smartphone Uni-Frame)",
            category: .electronics3C,
            sourceType: .physicalSpec,
            specsSummary: "CNC 五軸精雕加工、注塑天線斷差 < 0.02mm、四角耐衝擊微倒角",
            materialSuggestion: "AL7075 航空鋁合金 / 表面微米級陽極噴砂",
            dimensionsMm: "160.8 x 78.1 x 7.8 mm",
            fileSizeMB: 2.9,
            drawingCode: "phone_chassis"
        ))
        list.append(AssetItem(
            id: "elec_02",
            title: "真無線降噪耳機聲學腔體 (TWS Acoustic Earbud)",
            category: .electronics3C,
            sourceType: .physicalSpec,
            specsSummary: "人體耳甲腔 3D 拓撲曲面、雙洩壓閥微孔陣列、10mm 鍍鈹動圈架構",
            materialSuggestion: "醫學級 PC-ABS 複合材料 / 親膚奈米塗層",
            dimensionsMm: "24.5 x 21.2 x 18.0 mm",
            fileSizeMB: 2.2,
            drawingCode: "earbud_acoustic"
        ))
        list.append(AssetItem(
            id: "elec_03",
            title: "大光圈相機鏡頭光學鏡組 (Camera Optical Lens Assembly)",
            category: .electronics3C,
            sourceType: .physicalSpec,
            specsSummary: "9 群 12 枚光學鏡片、內建線性磁浮對焦馬達、金屬卡口防塵密封圈",
            materialSuggestion: "ED 低色散玻璃 + 鎂鋁合金鏡筒",
            dimensionsMm: "Ø78 x 長 95 mm / 濾鏡口徑 Ø67mm",
            fileSizeMB: 3.8,
            drawingCode: "camera_lens"
        ))
        list.append(AssetItem(
            id: "elec_04",
            title: "75% 客製化機械鍵盤 Gasket 結構 (Mechanical Keyboard)",
            category: .electronics3C,
            sourceType: .physicalSpec,
            specsSummary: "矽膠襯墊減震限位、FR4 沉金定位板、消音底棉與電池夾層",
            materialSuggestion: "上下蓋 6063 鋁合金 CNC / 表面電泳工藝",
            dimensionsMm: "320 x 140 x 38 mm",
            fileSizeMB: 3.4,
            drawingCode: "keyboard_gasket"
        ))
        list.append(AssetItem(
            id: "elec_05",
            title: "曲面未來感智慧座艙 HUD (Curved Cyber Cockpit HUD)",
            category: .electronics3C,
            sourceType: .aiConcept,
            specsSummary: "Micro-OLED 光學投射模組、全息光波導視網膜顯示、眼球追蹤感測",
            materialSuggestion: "半透明光學聚碳酸酯 + 陶瓷散熱背板",
            dimensionsMm: "220 x 120 x 45 mm",
            fileSizeMB: 4.8,
            drawingCode: "ai_hud_display"
        ))

        // 3. 實體產品 - 汽車載具 (Automotive)
        list.append(AssetItem(
            id: "auto_01",
            title: "跑車空氣動力學流線側影 (Sports Car Aerodynamic Profile)",
            category: .automotive,
            sourceType: .physicalSpec,
            specsSummary: "風阻係數 Cd 0.24、後輪拱主動導流氣道、下壓力擴散底盤佈局",
            materialSuggestion: "碳纖維乾碳成型 (Dry Carbon Pre-preg)",
            dimensionsMm: "4680 x 1980 x 1240 mm / 軸距 2720mm",
            fileSizeMB: 3.6,
            drawingCode: "car_silhouette"
        ))
        list.append(AssetItem(
            id: "auto_02",
            title: "五輻雙柱鍛造運動輪框 (Forged Monoblock Wheel Rim)",
            category: .automotive,
            sourceType: .physicalSpec,
            specsSummary: "一體萬噸鍛造成型、輕量化挖肉結構、通過 JWL/VIA 強化衝擊驗證",
            materialSuggestion: "6061-T6 鍛造鋁合金 / 亮黑拉絲透明漆",
            dimensionsMm: "20 吋 x 9.5J / PCD 5x114.3 / ET+35",
            fileSizeMB: 2.8,
            drawingCode: "wheel_rim"
        ))
        list.append(AssetItem(
            id: "auto_03",
            title: "雙 A 臂獨立懸吊機構 (Double Wishbone Suspension)",
            category: .automotive,
            sourceType: .physicalSpec,
            specsSummary: "幾何防傾傾角補償、高壓氮氣倒插式避震器、球接頭防塵套",
            materialSuggestion: "鍛造鋁合金控制臂 + 鉻鉬鋼避震彈簧",
            dimensionsMm: "輪距支撐跨距 580 mm / 行程 120 mm",
            fileSizeMB: 3.5,
            drawingCode: "suspension_geometry"
        ))
        list.append(AssetItem(
            id: "auto_04",
            title: "三輻運動賽車方向盤 (Sport Steering Wheel)",
            category: .automotive,
            sourceType: .physicalSpec,
            specsSummary: "D型平底人體工學拇指托、背部磁吸式碳纖維換檔撥片、多功能滾輪",
            materialSuggestion: "義大利 Alcantara 翻毛皮包覆 + 骨架鎂合金",
            dimensionsMm: "外徑 Ø360 mm / 握把截面 34 x 28 mm",
            fileSizeMB: 2.6,
            drawingCode: "steering_wheel"
        ))
        list.append(AssetItem(
            id: "auto_05",
            title: "純電滑板底盤電池模組架構 (EV Skateboard Chassis)",
            category: .automotive,
            sourceType: .physicalSpec,
            specsSummary: "CTP 無模組化高能量密度電池包、前後雙永磁同步電機、一體化壓鑄件",
            materialSuggestion: "熱成型超高強度鋼 1500MPa + 鋁合金壓鑄",
            dimensionsMm: "長 3400 x 寬 1600 x 厚 140 mm",
            fileSizeMB: 4.2,
            drawingCode: "ev_chassis"
        ))
        list.append(AssetItem(
            id: "auto_06",
            title: "未來星際懸浮穿梭載具 (Futuristic Orbital Shuttle)",
            category: .automotive,
            sourceType: .aiConcept,
            specsSummary: "向量離子推進噴口、多面體隱形耐熱外殼、環形重力偏轉艙",
            materialSuggestion: "耐熱石墨烯複合塗層 + 氣凝膠超低溫絕熱層",
            dimensionsMm: "6800 x 3800 x 2200 mm",
            fileSizeMB: 5.2,
            drawingCode: "ai_orbital_shuttle"
        ))

        // 4. 實體產品 - 工業家具 (Furniture)
        list.append(AssetItem(
            id: "furn_01",
            title: "經典伊姆斯休閒躺椅 (Eames Lounge Chair Geometry)",
            category: .furniture,
            sourceType: .physicalSpec,
            specsSummary: "五層熱壓成型曲木膠合板、15° 仰角人體脊椎舒壓弧度、五星金屬旋轉腳",
            materialSuggestion: "北美胡桃木貼皮曲木 + 頂級苯染半包覆牛皮",
            dimensionsMm: "840 x 850 x 840 mm / 座高 400 mm",
            fileSizeMB: 3.1,
            drawingCode: "eames_chair"
        ))
        list.append(AssetItem(
            id: "furn_02",
            title: "人體工學升降辦公桌幾何 (Height-Adjustable Standing Desk)",
            category: .furniture,
            sourceType: .physicalSpec,
            specsSummary: "雙馬達靜音三節升降柱、遇阻回退感應、升降範圍 620-1270mm",
            materialSuggestion: "冷軋碳素鋼桌腿 + 環保防刮美耐皿實木芯桌面",
            dimensionsMm: "1400 x 700 x (620-1270) mm",
            fileSizeMB: 2.7,
            drawingCode: "standing_desk"
        ))
        list.append(AssetItem(
            id: "furn_03",
            title: "包浩斯懸臂可調護眼檯燈 (Bauhaus Cantilever Task Lamp)",
            category: .furniture,
            sourceType: .physicalSpec,
            specsSummary: "四連桿平行阻尼關節平衡機構、無可視頻閃環形光源、隱藏式走線",
            materialSuggestion: "陽極氧化消光鋁管 + 重心下沉式壓鑄鋅底座",
            dimensionsMm: "懸臂展長 780 mm / 底座 Ø200 mm",
            fileSizeMB: 2.3,
            drawingCode: "task_lamp"
        ))
        list.append(AssetItem(
            id: "furn_04",
            title: "北歐極簡模組收納櫃 (Modular Credenza)",
            category: .furniture,
            sourceType: .physicalSpec,
            specsSummary: "45° 倒角隱藏拉手、緩衝滑軌抽屜、模組化自由堆疊插榫",
            materialSuggestion: "天然白橡木實木框架 + 環保水性漆塗裝",
            dimensionsMm: "1600 x 420 x 750 mm",
            fileSizeMB: 2.5,
            drawingCode: "modular_credenza"
        ))

        // 5. 五金零件 (Hardware & Fasteners)
        list.append(AssetItem(
            id: "hard_01",
            title: "ISO 4762 內六角圓柱頭螺栓 (Hex Socket Head Cap Screw)",
            category: .hardware,
            sourceType: .physicalSpec,
            specsSummary: "M6x25、螺距 1.0mm、強度等級 12.9 級、六角穴對邊 S=5mm",
            materialSuggestion: "SCM435 合金鋼 / 表面發黑防銹處理",
            dimensionsMm: "頭徑 Ø10 x 頭高 6 x 牙長 25 mm",
            fileSizeMB: 1.4,
            drawingCode: "hex_bolt"
        ))
        list.append(AssetItem(
            id: "hard_02",
            title: "DIN 7991 沉頭內六角螺釘 (Countersunk Flat Head Screw)",
            category: .hardware,
            sourceType: .physicalSpec,
            specsSummary: "M5x16、90° 沉頭錐角、裝配後與板金表面完全齊平",
            materialSuggestion: "SUS304 不鏽鋼 / 鈍化防腐蝕處理",
            dimensionsMm: "頭徑 Ø10 (90°) x 全長 16 mm",
            fileSizeMB: 1.3,
            drawingCode: "countersunk_screw"
        ))
        list.append(AssetItem(
            id: "hard_03",
            title: "六角法蘭面防鬆螺母 (Hex Flange Lock Nut)",
            category: .hardware,
            sourceType: .physicalSpec,
            specsSummary: "M8、底面鋸齒狀防滑脫條紋、8 級預載防鬆抗振",
            materialSuggestion: "碳素結構鋼 / 環保鍍鋅 (RoHS 認證)",
            dimensionsMm: "法蘭外徑 Ø18 x 六角厚度 8 mm",
            fileSizeMB: 1.2,
            drawingCode: "flange_nut"
        ))
        list.append(AssetItem(
            id: "hard_04",
            title: "封閉型抽芯盲鉚釘 (Closed-End Blind Rivet)",
            category: .hardware,
            sourceType: .physicalSpec,
            specsSummary: "Ø4.0 x 12mm、高氣密防水防漏、剪切強度 2200N、拉伸強度 2800N",
            materialSuggestion: "5052 鋁合金釘體 + 碳鋼釘芯",
            dimensionsMm: "釘套 Ø4.0 x 長 12 mm / 鉚接厚度 4-7mm",
            fileSizeMB: 1.1,
            drawingCode: "blind_rivet"
        ))
        list.append(AssetItem(
            id: "hard_05",
            title: "圓柱螺旋壓縮彈簧 (Helical Compression Spring)",
            category: .hardware,
            sourceType: .physicalSpec,
            specsSummary: "線徑 d=2.0mm、外徑 D=16mm、自由長度 L0=50mm、彈簧剛度 k=4.2N/mm",
            materialSuggestion: "SWP-B 琴鋼線 / 表面化學鍍鎳",
            dimensionsMm: "外徑 Ø16 x 節距 6.5 x 自由長 50 mm",
            fileSizeMB: 1.5,
            drawingCode: "compression_spring"
        ))
        list.append(AssetItem(
            id: "hard_06",
            title: "90° 強化沖壓直角固定角鐵 (Heavy-Duty L-Bracket)",
            category: .hardware,
            sourceType: .physicalSpec,
            specsSummary: "厚度 3.0mm、加強筋抗彎折衝壓、四孔 M5 沉頭安裝位",
            materialSuggestion: "Q235 冷軋板沖壓 / 烤漆防鏽處理",
            dimensionsMm: "50 x 50 x 40 x 厚 3.0 mm",
            fileSizeMB: 1.6,
            drawingCode: "bracket_l"
        ))

        // 6. 數位產品 (Digital Assets & Wireframes)
        list.append(AssetItem(
            id: "digi_01",
            title: "旗艦智慧型手機 UI 向量線框 (Phone Wireframe Outline)",
            category: .digital,
            sourceType: .physicalSpec,
            specsSummary: "標準 19.5:9 螢幕長寬比、動態島開孔引導、44pt 導航列安全邊界",
            materialSuggestion: "向量 Wireframe 線稿規格",
            dimensionsMm: "393 x 852 pt (向量縮放)",
            fileSizeMB: 1.2,
            drawingCode: "wireframe_phone"
        ))
        list.append(AssetItem(
            id: "digi_02",
            title: "平板手繪多視窗佈局 (Tablet Multi-Window Grid)",
            category: .digital,
            sourceType: .physicalSpec,
            specsSummary: "4:3 比例工作區、分屏多工側邊欄、底部 Dock 快捷欄指示線",
            materialSuggestion: "向量 Wireframe 線稿規格",
            dimensionsMm: "1024 x 768 pt (向量縮放)",
            fileSizeMB: 1.4,
            drawingCode: "wireframe_tablet"
        ))
        list.append(AssetItem(
            id: "digi_03",
            title: "極簡瀏覽器視窗框架 (Browser Window Frame)",
            category: .digital,
            sourceType: .physicalSpec,
            specsSummary: "頂部紅黃綠三色控制按鈕、網址列膠囊外框、標籤頁分頁列",
            materialSuggestion: "向量 Wireframe 線稿規格",
            dimensionsMm: "1280 x 800 pt (向量縮放)",
            fileSizeMB: 1.3,
            drawingCode: "wireframe_browser"
        ))
        list.append(AssetItem(
            id: "digi_04",
            title: "行動端 8 種核心手勢符號包 (UX Gesture Annotations)",
            category: .digital,
            sourceType: .physicalSpec,
            specsSummary: "包含單擊 (Tap)、雙擊、長按、滑動 (Swipe)、旋轉、縮放等手勢路徑",
            materialSuggestion: "向量 Wireframe 線稿規格",
            dimensionsMm: "一套 8 個符號，支援獨立拆分插入",
            fileSizeMB: 1.5,
            drawingCode: "wireframe_gestures"
        ))

        // 7. 美學視覺 - 構圖與黃金分割 (Aesthetic Composition)
        list.append(AssetItem(
            id: "aes_comp_01",
            title: "黃金螺旋對數構圖尺標 (Golden Spiral Logarithmic Guide)",
            category: .aestheticComposition,
            sourceType: .physicalSpec,
            specsSummary: "黃金比例 phi=1.618033、費氏數列方格、向心對稱引導線",
            materialSuggestion: "精密光學刻度尺 / 向量比例規格",
            dimensionsMm: "1:1.618 (動態向量縮放)",
            fileSizeMB: 1.2,
            drawingCode: "golden_spiral"
        ))
        list.append(AssetItem(
            id: "aes_comp_02",
            title: "經典攝影三分法則九宮格 (Rule of Thirds Grid)",
            category: .aestheticComposition,
            sourceType: .physicalSpec,
            specsSummary: "4 個視覺焦點交叉點、上中下水平分割、左中右垂直平衡",
            materialSuggestion: "16:9 比例畫幅視覺輔助規",
            dimensionsMm: "16:9 / 3:2 向量縮放",
            fileSizeMB: 1.1,
            drawingCode: "rule_of_thirds"
        ))
        list.append(AssetItem(
            id: "aes_comp_03",
            title: "動態對稱菱形構圖引導 (Dynamic Symmetry Armatures)",
            category: .aestheticComposition,
            sourceType: .physicalSpec,
            specsSummary: "巴洛克對角線、反對角線交點、古典大師繪畫構圖幾何網",
            materialSuggestion: "構圖比例規 / 幾何分割網格",
            dimensionsMm: "1:1.414 (銀根矩形)",
            fileSizeMB: 1.3,
            drawingCode: "dynamic_symmetry"
        ))

        // 8. 美學視覺 - 字體排印與度量 (Typography & Metrics)
        list.append(AssetItem(
            id: "typo_01",
            title: "拉丁字體排印五線度量基準 (Type Anatomy Baseline Metrics)",
            category: .typography,
            sourceType: .physicalSpec,
            specsSummary: "包含 Cap Height、x-Height、Baseline、Ascender、Descender 基準線",
            materialSuggestion: "DIN 1451 / OpenType 字符度量規格",
            dimensionsMm: "48pt 參考字級 / 500pt 寬",
            fileSizeMB: 1.4,
            drawingCode: "type_anatomy"
        ))
        list.append(AssetItem(
            id: "typo_02",
            title: "中文字型永字八法九宮格 (Chinese Glyph 9-Grid Calligraphy)",
            category: .typography,
            sourceType: .physicalSpec,
            specsSummary: "米字格、九宮格、筆畫重心平衡、外圓內方筆勢軌跡",
            materialSuggestion: "向量書法教學標註規格",
            dimensionsMm: "100 x 100 mm",
            fileSizeMB: 1.3,
            drawingCode: "yong_eight_strokes"
        ))
        list.append(AssetItem(
            id: "typo_03",
            title: "版面編排字級模矩比例尺 (Modular Type Scale 1.250)",
            category: .typography,
            sourceType: .physicalSpec,
            specsSummary: "Major Third 等比倍率字級階梯 (12, 16, 20, 25, 31, 39, 48pt) 視覺對比",
            materialSuggestion: "印刷排版基準規格",
            dimensionsMm: "寬 360 x 高 240 pt",
            fileSizeMB: 1.2,
            drawingCode: "modular_type_scale"
        ))

        // 9. 美學視覺 - 視覺紋樣與裝飾 (Design Motifs)
        list.append(AssetItem(
            id: "motif_01",
            title: "包浩斯幾何構成裝飾組 (Bauhaus Geometric Motif Set)",
            category: .designMotifs,
            sourceType: .physicalSpec,
            specsSummary: "純粹圓形、三角形、正方形色彩交集與抽象網格組合",
            materialSuggestion: "向量幾何裝飾組標本",
            dimensionsMm: "200 x 200 mm",
            fileSizeMB: 1.5,
            drawingCode: "bauhaus_motif"
        ))
        list.append(AssetItem(
            id: "motif_02",
            title: "參數化 Voronoi 泰森多邊形紋樣 (Parametric Voronoi Cellular)",
            category: .designMotifs,
            sourceType: .physicalSpec,
            specsSummary: "自然生長仿生多孔結構、自適應點陣分佈、輕量化吸能骨架",
            materialSuggestion: "3D 打印尼龍 SLS / 幾何孔洞",
            dimensionsMm: "180 x 180 x 厚 2.5 mm",
            fileSizeMB: 2.2,
            drawingCode: "voronoi_pattern"
        ))
        list.append(AssetItem(
            id: "motif_03",
            title: "未來賽博賽道光軌幾何 (Cyberpunk Vector Circuit Tracks)",
            category: .designMotifs,
            sourceType: .aiConcept,
            specsSummary: "45° 折線電路軌跡、端點測試點標籤、高科技光感線框",
            materialSuggestion: "AI 概念渲染 / 向量幾何",
            dimensionsMm: "300 x 200 pt",
            fileSizeMB: 2.0,
            drawingCode: "cyber_circuit"
        ))

        // 10. 工程製程 - 模具成型與拔模 (Tooling & Molding)
        list.append(AssetItem(
            id: "mold_01",
            title: "注塑模具 1.5° 拔模角與分模線剖面 (Draft Angle & Parting Line)",
            category: .toolingMolding,
            sourceType: .physicalSpec,
            specsSummary: "凸模 (Core) 與凹模 (Cavity) 拔模公差、防止拉傷脫模結構",
            materialSuggestion: "P20 / 718H 預硬模具鋼結構",
            dimensionsMm: "250 x 150 x 120 mm",
            fileSizeMB: 2.8,
            drawingCode: "draft_angle_mold"
        ))
        list.append(AssetItem(
            id: "mold_02",
            title: "塑膠件均勻壁厚與加強筋規範 (Plastic Rib & Wall Ratio)",
            category: .toolingMolding,
            sourceType: .physicalSpec,
            specsSummary: "主壁厚 T=2.5mm、加強筋厚度 0.6T (1.5mm)、根部圓角 R=0.5T",
            materialSuggestion: "ABS / PC 注塑防縮水變形準則",
            dimensionsMm: "160 x 80 x 30 mm",
            fileSizeMB: 1.9,
            drawingCode: "plastic_rib_ratio"
        ))
        list.append(AssetItem(
            id: "mold_03",
            title: "螺絲自攻牙注塑凸柱結構 (Boss Tower & Gusset)",
            category: .toolingMolding,
            sourceType: .physicalSpec,
            specsSummary: "內徑 d=2.8mm (適用 M3 自攻螺絲)、外徑 2.5d、基座三角支撐筋",
            materialSuggestion: "POM / PA66 工程塑料凸柱",
            dimensionsMm: "Ø7.0 x 高 15.0 mm",
            fileSizeMB: 1.6,
            drawingCode: "boss_tower"
        ))

        // 11. 工程製程 - 鈑金折彎與 CNC 清角 (Sheet Metal & CNC)
        list.append(AssetItem(
            id: "sheet_01",
            title: "鈑金 90° V 型折彎 K-Factor 計算展開圖 (Sheet Metal Bend Deduction)",
            category: .sheetMetalCNC,
            sourceType: .physicalSpec,
            specsSummary: "板厚 t=2.0mm、折彎內角 R=2.0mm、中性層 K=0.42 展開長度補償",
            materialSuggestion: "SPCC 冷軋鋼板 / 展開標註",
            dimensionsMm: "展開長度 124.5 mm / 折彎 90°",
            fileSizeMB: 2.1,
            drawingCode: "sheetmetal_bend"
        ))
        list.append(AssetItem(
            id: "sheet_02",
            title: "CNC 銑削內直角狗骨狀清角結構 (Dogbone Fillet Relief)",
            category: .sheetMetalCNC,
            sourceType: .physicalSpec,
            specsSummary: "消除端銑刀 Ø3.0mm 內角死區殘留、確保矩形嵌件完美密合裝配",
            materialSuggestion: "AL6061-T6 銑削加工規格",
            dimensionsMm: "嵌件槽 40 x 40 mm / 刀徑 Ø3",
            fileSizeMB: 1.7,
            drawingCode: "cnc_dogbone"
        ))
        list.append(AssetItem(
            id: "sheet_03",
            title: "沖孔自鉚壓鉚螺母柱 (PEM Self-Clinching Standoff)",
            category: .sheetMetalCNC,
            sourceType: .physicalSpec,
            specsSummary: "底板沖孔 Ø5.4mm、齒紋沉頭冷擠壓鎖入板金、拉拔扭矩達 4.8Nm",
            materialSuggestion: "鍍鋅碳鋼 M3 / 板厚 1.5mm",
            dimensionsMm: "M3 x 六角外徑 7.0 x 長 10 mm",
            fileSizeMB: 1.4,
            drawingCode: "pem_standoff"
        ))

        // 12. 工程製程 - 表面處理與色彩光澤 (Surface Finishing)
        list.append(AssetItem(
            id: "surf_01",
            title: "陽極氧化膜厚與表面噴砂目數對照 (Anodizing Sandblast Grade)",
            category: .surfaceFinishing,
            sourceType: .physicalSpec,
            specsSummary: "120# ~ 320# 鋯砂啞光打磨、15µm 二級陽極氧化皮膜、耐鹽霧 96h",
            materialSuggestion: "6000 系列鋁合金表面處理",
            dimensionsMm: "樣板標本 100 x 50 x 厚 2.0 mm",
            fileSizeMB: 2.4,
            drawingCode: "anodizing_spec"
        ))
        list.append(AssetItem(
            id: "surf_02",
            title: "表面粗糙度 Ra 算術平均標註規 (Surface Roughness Ra Scale)",
            category: .surfaceFinishing,
            sourceType: .physicalSpec,
            specsSummary: "Ra 0.8 (精密精銑)、Ra 1.6 (普通精加工)、Ra 3.2 (粗加工粗糙度)",
            materialSuggestion: "ISO 1302 標準幾何表面符號",
            dimensionsMm: "標準測量基準長度 0.8 mm",
            fileSizeMB: 1.8,
            drawingCode: "roughness_ra"
        ))

        // 13. 工程製程 - 氣壓油壓與管路 (Pneumatics & Piping)
        list.append(AssetItem(
            id: "pipe_01",
            title: "雙作用氣動滑台氣缸規格 (Dual-Acting Air Cylinder)",
            category: .pneumaticsPiping,
            sourceType: .physicalSpec,
            specsSummary: "缸徑 Ø16mm、標準行程 50mm、雙導軌抗扭轉、兩端磁簧感測槽",
            materialSuggestion: "硬質陽極氧化鋁合金缸體",
            dimensionsMm: "長 125 x 寬 44 x 高 28 mm",
            fileSizeMB: 2.6,
            drawingCode: "pneumatic_cylinder"
        ))
        list.append(AssetItem(
            id: "pipe_02",
            title: "快插式直角節流閥管路接頭 (One-Touch Speed Controller)",
            category: .pneumaticsPiping,
            sourceType: .physicalSpec,
            specsSummary: "外螺紋 R1/8、外接 PU 管徑 Ø6mm、刻度旋鈕精確控制氣流量",
            materialSuggestion: "黃銅鍍鎳 + POM 釋放環",
            dimensionsMm: "長 32 x 寬 24 x 高 28 mm",
            fileSizeMB: 1.5,
            drawingCode: "push_in_fitting"
        ))

        // 14. 數位體驗 - 跨平台 UI 規範 (Cross-Platform UI)
        list.append(AssetItem(
            id: "ui_01",
            title: "iOS 與 Material 3 雙系統導航列對照 (Dual-OS Navbar Specs)",
            category: .crossPlatformUI,
            sourceType: .physicalSpec,
            specsSummary: "iOS Large Title 96pt vs Android TopAppBar 64pt、邊距與觸控熱區",
            materialSuggestion: "向量 UI 規範 Wireframe",
            dimensionsMm: "393 x 120 pt 跨系統標準",
            fileSizeMB: 1.5,
            drawingCode: "dual_os_navbar"
        ))
        list.append(AssetItem(
            id: "ui_02",
            title: "底部操作卡片 Bottom Sheet 手勢容器 (Modal Bottom Sheet)",
            category: .crossPlatformUI,
            sourceType: .physicalSpec,
            specsSummary: "頂部 Grabber 抓手把柄 (36x5pt)、半展開/全展開錨點、背景遮罩",
            materialSuggestion: "通用行動端浮動視窗規範",
            dimensionsMm: "393 x 480 pt (可滑動)",
            fileSizeMB: 1.6,
            drawingCode: "bottom_sheet_ui"
        ))

        // 15. 數位體驗 - 動效與微互動 (UX Motion)
        list.append(AssetItem(
            id: "motion_01",
            title: "三次貝茲曲線動效時間函數 (Cubic Bezier Easing Curves)",
            category: .uxMotion,
            sourceType: .physicalSpec,
            specsSummary: "標準 Ease-In-Out (0.42, 0, 0.58, 1) 與彈性 Overshoot 曲線圖標",
            materialSuggestion: "CSS / Swift 動畫時間對應曲率",
            dimensionsMm: "坐標系 300 x 200 pt",
            fileSizeMB: 1.4,
            drawingCode: "cubic_bezier_curve"
        ))
        list.append(AssetItem(
            id: "motion_02",
            title: "彈簧阻尼系統動態示意 (Spring Mass Damper Physics)",
            category: .uxMotion,
            sourceType: .physicalSpec,
            specsSummary: "阻尼比 ζ=0.75 臨界阻尼、剛度係數 Stiffness 與衰減振幅包絡線",
            materialSuggestion: "iOS Spatial Physics 模型圖示",
            dimensionsMm: "波形坐標寬 320 x 高 180 pt",
            fileSizeMB: 1.6,
            drawingCode: "spring_physics"
        ))

        // 16. 數位體驗 - 資訊架構 (Information Architecture)
        list.append(AssetItem(
            id: "ia_01",
            title: "階層式站點地圖與樹狀導航節點 (Sitemap Hierarchy Tree)",
            category: .infoArchitecture,
            sourceType: .physicalSpec,
            specsSummary: "首頁根節點、一級頻道模組、次級頁面父子繼承關係線",
            materialSuggestion: "IA 資訊架構標準向量符號",
            dimensionsMm: "480 x 260 pt (樹狀拓撲)",
            fileSizeMB: 1.7,
            drawingCode: "sitemap_tree"
        ))
        list.append(AssetItem(
            id: "ia_02",
            title: "使用者狀態機躍遷流程圖 (User Journey State Machine)",
            category: .infoArchitecture,
            sourceType: .physicalSpec,
            specsSummary: "起始態、條件分支 (If/Else)、等待非同步回調、終止態符號",
            materialSuggestion: "UX 流程與邏輯架構圖",
            dimensionsMm: "400 x 240 pt 泳道圖形",
            fileSizeMB: 1.8,
            drawingCode: "state_machine_flow"
        ))

        // 17. 數位體驗 - 設計規範 (Design Tokens)
        list.append(AssetItem(
            id: "token_01",
            title: "8pt 空間網格與間距度量尺 (8-Point Grid Spacing Scale)",
            category: .designTokens,
            sourceType: .physicalSpec,
            specsSummary: "4, 8, 12, 16, 24, 32, 48, 64pt 空間級數與原子排版基準",
            materialSuggestion: "Design System 間距原子規範",
            dimensionsMm: "長 360 x 寬 180 pt",
            fileSizeMB: 1.3,
            drawingCode: "spacing_8pt_grid"
        ))
        list.append(AssetItem(
            id: "token_02",
            title: "設計語意色彩層級與對比度矩陣 (Semantic Color Tokens WCAG)",
            category: .designTokens,
            sourceType: .physicalSpec,
            specsSummary: "Surface, Primary, On-Surface, Error 與 WCAG AAA (7:1) 對比度驗證",
            materialSuggestion: "色彩規範與無障礙標準規格",
            dimensionsMm: "360 x 220 pt 矩陣視圖",
            fileSizeMB: 1.5,
            drawingCode: "semantic_color_tokens"
        ))

        self.items = list
        updateItemStates()
    }

    // MARK: - 高解析度實體工業線圖/概念圖向量產生器
    /// 將圖庫項目渲染為畫布適用的高品質 UIImage
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
            currentIsDark = isDark
            defer { currentStyle = .blueprint; currentIsDark = false }
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
            let subtitle = "\(item.title)  [\(item.dimensionsMm)]"
            (subtitle as NSString).draw(at: CGPoint(x: 26, y: 360), withAttributes: attrs)
        }
    }

    // MARK: - 繪圖小工具

    /// 目前這次算繪使用的樣式。
    ///
    /// 用實例屬性而非逐一傳參數：輔助函式在 58 個案例裡被呼叫數百次，
    /// 每個都多帶一個參數只會讓繪圖程式更難讀。`AssetLibraryManager` 是
    /// `@MainActor`，算繪從頭到尾在同一執行緒同步完成，不會有交錯問題。
    private var currentStyle: AssetRenderStyle = .blueprint
    private var currentIsDark: Bool = false

    /// 實物模式的填色。線框模式回傳 nil（不填）。
    private var fillColor: UIColor? {
        guard currentStyle == .solid else { return nil }
        return currentIsDark
            ? UIColor.cyan.withAlphaComponent(0.22)
            : UIColor(red: 0.42, green: 0.58, blue: 0.82, alpha: 0.30)
    }

    /// 封閉路徑：實物模式先填色再描邊，線框模式只描邊。
    private func fillAndStroke(_ cg: CGContext, _ path: CGPath) {
        if let fill = fillColor {
            cg.addPath(path)
            cg.setFillColor(fill.cgColor)
            cg.fillPath()
        }
        cg.addPath(path)
        cg.strokePath()
    }

    private func stroke(_ cg: CGContext, rounded rect: CGRect, radius: CGFloat) {
        fillAndStroke(cg, UIBezierPath(roundedRect: rect, cornerRadius: radius).cgPath)
    }

    /// 折線。`closed` 為 true 時首尾相連（封閉者在實物模式會填色）。
    private func polyline(_ cg: CGContext, _ pts: [CGPoint], closed: Bool = false) {
        guard let first = pts.first else { return }
        if closed {
            let path = CGMutablePath()
            path.move(to: first)
            for p in pts.dropFirst() { path.addLine(to: p) }
            path.closeSubpath()
            fillAndStroke(cg, path)
            return
        }
        cg.move(to: first)
        for p in pts.dropFirst() { cg.addLine(to: p) }
        cg.strokePath()
    }

    private func ellipse(_ cg: CGContext, _ rect: CGRect) {
        fillAndStroke(cg, UIBezierPath(ovalIn: rect).cgPath)
    }

    /// 以中心點與半徑畫圓。
    private func circle(_ cg: CGContext, _ center: CGPoint, _ radius: CGFloat) {
        ellipse(cg, CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
    }

    /// 螺紋鋸齒側視輪廓，用在螺釘與鉚釘。
    private func threadProfile(_ cg: CGContext, x: CGFloat, top: CGFloat, bottom: CGFloat, halfWidth: CGFloat, pitch: CGFloat) {
        var y = top
        var left = true
        var pts: [CGPoint] = []
        while y <= bottom {
            pts.append(CGPoint(x: x + (left ? -halfWidth : halfWidth), y: y))
            left.toggle()
            y += pitch
        }
        polyline(cg, pts)
    }

    private func drawObjectGraphics(code: String, cg: CGContext, isDark: Bool) {
        let strokeColor = isDark ? UIColor.cyan : UIColor(red: 0.1, green: 0.3, blue: 0.65, alpha: 1.0)
        let accentColor = isDark ? UIColor.systemPink : UIColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1.0)

        cg.setStrokeColor(strokeColor.cgColor)
        cg.setLineWidth(2.5)

        switch code {
        case "gear_pair":
            // 繪製嚙合雙齒輪組
            ellipse(cg, CGRect(x: 70, y: 120, width: 120, height: 120))
            ellipse(cg, CGRect(x: 110, y: 160, width: 40, height: 40))
            for i in 0..<12 {
                let angle = CGFloat(i) * (.pi / 6)
                let x1 = 130 + cos(angle) * 60
                let y1 = 180 + sin(angle) * 60
                let x2 = 130 + cos(angle) * 72
                let y2 = 180 + sin(angle) * 72
                cg.move(to: CGPoint(x: x1, y: y1))
                cg.addLine(to: CGPoint(x: x2, y: y2))
            }
            // 大齒輪
            ellipse(cg, CGRect(x: 180, y: 110, width: 160, height: 160))
            ellipse(cg, CGRect(x: 230, y: 160, width: 60, height: 60))
            for i in 0..<18 {
                let angle = CGFloat(i) * (.pi / 9)
                let x1 = 260 + cos(angle) * 80
                let y1 = 190 + sin(angle) * 80
                let x2 = 260 + cos(angle) * 94
                let y2 = 190 + sin(angle) * 94
                cg.move(to: CGPoint(x: x1, y: y1))
                cg.addLine(to: CGPoint(x: x2, y: y2))
            }
            cg.strokePath()

        case "bearing_iso":
            // 軸承內外環與滾子陣列
            ellipse(cg, CGRect(x: 100, y: 75, width: 200, height: 200))
            ellipse(cg, CGRect(x: 140, y: 115, width: 120, height: 120))
            for i in 0..<8 {
                let angle = CGFloat(i) * (.pi / 4)
                let rx = 200 + cos(angle) * 80 - 15
                let ry = 175 + sin(angle) * 80 - 15
                ellipse(cg, CGRect(x: rx, y: ry, width: 30, height: 30))
            }
            cg.strokePath()

        case "phone_chassis":
            // 手機鋁框圓角四邊與三鏡頭模組
            let phoneRect = CGRect(x: 120, y: 50, width: 160, height: 260)
            let phonePath = UIBezierPath(roundedRect: phoneRect, cornerRadius: 24)
            cg.addPath(phonePath.cgPath)
            cg.strokePath()
            // 螢幕安全線
            let innerRect = CGRect(x: 130, y: 65, width: 140, height: 230)
            let innerPath = UIBezierPath(roundedRect: innerRect, cornerRadius: 18)
            cg.setLineWidth(1.2)
            cg.addPath(innerPath.cgPath)
            cg.strokePath()
            // 動態島
            let island = CGRect(x: 175, y: 72, width: 50, height: 12)
            let islandPath = UIBezierPath(roundedRect: island, cornerRadius: 6)
            cg.addPath(islandPath.cgPath)
            cg.strokePath()

        case "car_silhouette":
            // 流線跑車車身線條
            cg.move(to: CGPoint(x: 50, y: 220))
            cg.addCurve(to: CGPoint(x: 110, y: 170), control1: CGPoint(x: 70, y: 210), control2: CGPoint(x: 85, y: 175))
            cg.addCurve(to: CGPoint(x: 200, y: 130), control1: CGPoint(x: 140, y: 160), control2: CGPoint(x: 170, y: 135))
            cg.addCurve(to: CGPoint(x: 310, y: 165), control1: CGPoint(x: 240, y: 125), control2: CGPoint(x: 280, y: 140))
            cg.addCurve(to: CGPoint(x: 355, y: 220), control1: CGPoint(x: 330, y: 180), control2: CGPoint(x: 345, y: 205))
            cg.addLine(to: CGPoint(x: 300, y: 220))
            // 前後輪拱
            cg.addArc(center: CGPoint(x: 270, y: 220), radius: 30, startAngle: 0, endAngle: .pi, clockwise: true)
            cg.addLine(to: CGPoint(x: 160, y: 220))
            cg.addArc(center: CGPoint(x: 130, y: 220), radius: 30, startAngle: 0, endAngle: .pi, clockwise: true)
            cg.addLine(to: CGPoint(x: 50, y: 220))
            cg.strokePath()
            // 輪框
            ellipse(cg, CGRect(x: 105, y: 195, width: 50, height: 50))
            ellipse(cg, CGRect(x: 245, y: 195, width: 50, height: 50))

        case "eames_chair":
            // 包浩斯休閒椅
            cg.move(to: CGPoint(x: 120, y: 130))
            cg.addCurve(to: CGPoint(x: 200, y: 110), control1: CGPoint(x: 140, y: 115), control2: CGPoint(x: 170, y: 110))
            cg.addCurve(to: CGPoint(x: 260, y: 160), control1: CGPoint(x: 230, y: 110), control2: CGPoint(x: 250, y: 140))
            cg.addCurve(to: CGPoint(x: 250, y: 210), control1: CGPoint(x: 265, y: 180), control2: CGPoint(x: 260, y: 200))
            cg.addCurve(to: CGPoint(x: 170, y: 230), control1: CGPoint(x: 230, y: 225), control2: CGPoint(x: 200, y: 230))
            cg.strokePath()
            // 旋轉金屬底座五星腳
            cg.move(to: CGPoint(x: 200, y: 230))
            cg.addLine(to: CGPoint(x: 200, y: 270))
            cg.move(to: CGPoint(x: 140, y: 290))
            cg.addLine(to: CGPoint(x: 200, y: 270))
            cg.addLine(to: CGPoint(x: 260, y: 290))
            cg.strokePath()

        case "hex_bolt":
            // 內六角螺栓
            let head = CGRect(x: 150, y: 80, width: 100, height: 60)
            cg.stroke(head)
            // 螺桿
            let body = CGRect(x: 165, y: 140, width: 70, height: 140)
            cg.stroke(body)
            // 螺牙斜線
            var y: CGFloat = 150
            while y < 270 {
                cg.move(to: CGPoint(x: 165, y: y))
                cg.addLine(to: CGPoint(x: 235, y: y + 8))
                y += 12
            }
            cg.strokePath()
            // 頭部內六角孔引導
            ellipse(cg, CGRect(x: 180, y: 95, width: 40, height: 30))

        case "golden_spiral":
            // 黃金螺旋與費氏矩形分割
            let r0 = CGRect(x: 80, y: 80, width: 240, height: 148.3)
            cg.stroke(r0)
            cg.move(to: CGPoint(x: 228.3, y: 80))
            cg.addLine(to: CGPoint(x: 228.3, y: 228.3))
            cg.move(to: CGPoint(x: 228.3, y: 171.7))
            cg.addLine(to: CGPoint(x: 320, y: 171.7))
            cg.strokePath()
            // 黃金對數螺線
            cg.move(to: CGPoint(x: 80, y: 228.3))
            cg.addCurve(to: CGPoint(x: 228.3, y: 80), control1: CGPoint(x: 80, y: 146.4), control2: CGPoint(x: 146.4, y: 80))
            cg.addCurve(to: CGPoint(x: 320, y: 171.7), control1: CGPoint(x: 279, y: 80), control2: CGPoint(x: 320, y: 121))
            cg.addCurve(to: CGPoint(x: 263.3, y: 228.3), control1: CGPoint(x: 320, y: 203), control2: CGPoint(x: 295, y: 228.3))
            cg.strokePath()

        case "rule_of_thirds":
            // 九宮格三分法則
            let gridRect = CGRect(x: 70, y: 80, width: 260, height: 180)
            cg.stroke(gridRect)
            cg.setLineWidth(1.0)
            // 兩條垂直線
            cg.move(to: CGPoint(x: 156.6, y: 80)); cg.addLine(to: CGPoint(x: 156.6, y: 260))
            cg.move(to: CGPoint(x: 243.3, y: 80)); cg.addLine(to: CGPoint(x: 243.3, y: 260))
            // 兩條水平線
            cg.move(to: CGPoint(x: 70, y: 140)); cg.addLine(to: CGPoint(x: 330, y: 140))
            cg.move(to: CGPoint(x: 70, y: 200)); cg.addLine(to: CGPoint(x: 330, y: 200))
            cg.strokePath()
            // 4 個黃金焦點交點圓環
            let points = [CGPoint(x: 156.6, y: 140), CGPoint(x: 243.3, y: 140), CGPoint(x: 156.6, y: 200), CGPoint(x: 243.3, y: 200)]
            for pt in points {
                ellipse(cg, CGRect(x: pt.x - 7, y: pt.y - 7, width: 14, height: 14))
            }

        case "dynamic_symmetry":
            // 動態對稱巴洛克對角線
            let rootRect = CGRect(x: 70, y: 70, width: 260, height: 184)
            cg.stroke(rootRect)
            // 主對角線與次對角線
            cg.move(to: CGPoint(x: 70, y: 254)); cg.addLine(to: CGPoint(x: 330, y: 70))
            cg.move(to: CGPoint(x: 70, y: 70)); cg.addLine(to: CGPoint(x: 330, y: 254))
            // 垂直倒數互補線
            cg.move(to: CGPoint(x: 70, y: 70)); cg.addLine(to: CGPoint(x: 220, y: 254))
            cg.move(to: CGPoint(x: 330, y: 254)); cg.addLine(to: CGPoint(x: 180, y: 70))
            cg.strokePath()

        case "type_anatomy":
            // 字體五線譜與度量
            let linesY: [CGFloat] = [90, 120, 160, 210, 250]
            for (idx, y) in linesY.enumerated() {
                cg.setLineWidth(idx == 3 ? 2.0 : 1.0)
                cg.move(to: CGPoint(x: 60, y: y)); cg.addLine(to: CGPoint(x: 340, y: y))
                cg.strokePath()
            }
            // 字符示意輪廓 'H' 與 'p'
            cg.stroke(CGRect(x: 90, y: 120, width: 60, height: 90))
            ellipse(cg, CGRect(x: 180, y: 160, width: 50, height: 50))
            cg.move(to: CGPoint(x: 180, y: 160)); cg.addLine(to: CGPoint(x: 180, y: 250))
            cg.strokePath()

        case "yong_eight_strokes":
            // 永字八法九宮米字格
            let miRect = CGRect(x: 100, y: 70, width: 200, height: 200)
            cg.stroke(miRect)
            cg.setLineWidth(1.0)
            cg.move(to: CGPoint(x: 100, y: 170)); cg.addLine(to: CGPoint(x: 300, y: 170))
            cg.move(to: CGPoint(x: 200, y: 70)); cg.addLine(to: CGPoint(x: 200, y: 270))
            cg.move(to: CGPoint(x: 100, y: 70)); cg.addLine(to: CGPoint(x: 300, y: 270))
            cg.move(to: CGPoint(x: 100, y: 270)); cg.addLine(to: CGPoint(x: 300, y: 70))
            cg.strokePath()
            // 永字主筆骨架
            cg.setLineWidth(3.0)
            ellipse(cg, CGRect(x: 195, y: 85, width: 10, height: 16))
            cg.move(to: CGPoint(x: 130, y: 125)); cg.addLine(to: CGPoint(x: 270, y: 125))
            cg.move(to: CGPoint(x: 200, y: 125)); cg.addLine(to: CGPoint(x: 200, y: 235))
            cg.addLine(to: CGPoint(x: 175, y: 215)) // 鉤
            cg.move(to: CGPoint(x: 200, y: 170)); cg.addLine(to: CGPoint(x: 140, y: 230)) // 撇
            cg.move(to: CGPoint(x: 200, y: 180)); cg.addLine(to: CGPoint(x: 265, y: 240)) // 捺
            cg.strokePath()

        case "modular_type_scale":
            // 字級比例模矩階梯
            var y: CGFloat = 80
            let sizes: [CGFloat] = [36, 28, 22, 18, 14, 11]
            for sz in sizes {
                cg.stroke(CGRect(x: 80, y: y, width: sz * 6.5, height: sz))
                y += sz + 10
            }
            cg.strokePath()

        case "bauhaus_motif":
            // 包浩斯三原形幾何構成
            ellipse(cg, CGRect(x: 80, y: 90, width: 110, height: 110)) // 圓
            cg.stroke(CGRect(x: 150, y: 140, width: 100, height: 100)) // 方
            cg.move(to: CGPoint(x: 260, y: 90))
            cg.addLine(to: CGPoint(x: 320, y: 200))
            cg.addLine(to: CGPoint(x: 200, y: 200))
            cg.closePath() // 三角
            cg.strokePath()

        case "voronoi_pattern":
            // 泰森多邊形網格
            let centers = [CGPoint(x: 140, y: 120), CGPoint(x: 220, y: 110), CGPoint(x: 180, y: 180), CGPoint(x: 120, y: 220), CGPoint(x: 260, y: 210)]
            for c in centers {
                ellipse(cg, CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8))
            }
            // 連線網格
            cg.move(to: CGPoint(x: 140, y: 120)); cg.addLine(to: CGPoint(x: 220, y: 110))
            cg.addLine(to: CGPoint(x: 260, y: 210)); cg.addLine(to: CGPoint(x: 180, y: 180))
            cg.addLine(to: CGPoint(x: 120, y: 220)); cg.addLine(to: CGPoint(x: 140, y: 120))
            cg.move(to: CGPoint(x: 180, y: 180)); cg.addLine(to: CGPoint(x: 140, y: 120))
            cg.move(to: CGPoint(x: 180, y: 180)); cg.addLine(to: CGPoint(x: 220, y: 110))
            cg.strokePath()

        case "cyber_circuit":
            // 45° 印刷電路軌跡
            cg.move(to: CGPoint(x: 80, y: 120)); cg.addLine(to: CGPoint(x: 160, y: 120))
            cg.addLine(to: CGPoint(x: 210, y: 170)); cg.addLine(to: CGPoint(x: 290, y: 170))
            cg.move(to: CGPoint(x: 110, y: 240)); cg.addLine(to: CGPoint(x: 180, y: 240))
            cg.addLine(to: CGPoint(x: 230, y: 190)); cg.addLine(to: CGPoint(x: 310, y: 190))
            cg.strokePath()
            let pads = [CGPoint(x: 80, y: 120), CGPoint(x: 290, y: 170), CGPoint(x: 110, y: 240), CGPoint(x: 310, y: 190)]
            for p in pads {
                ellipse(cg, CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12))
            }

        case "draft_angle_mold":
            // 注塑模具拔模角與分模線
            cg.move(to: CGPoint(x: 100, y: 80)); cg.addLine(to: CGPoint(x: 300, y: 80))
            cg.addLine(to: CGPoint(x: 285, y: 180)); cg.addLine(to: CGPoint(x: 115, y: 180))
            cg.closePath()
            // 分模線 PL
            cg.setLineWidth(1.0)
            cg.move(to: CGPoint(x: 70, y: 180)); cg.addLine(to: CGPoint(x: 330, y: 180))
            cg.strokePath()
            // 下模凹模
            cg.setLineWidth(2.5)
            cg.move(to: CGPoint(x: 115, y: 180)); cg.addLine(to: CGPoint(x: 130, y: 260))
            cg.addLine(to: CGPoint(x: 270, y: 260)); cg.addLine(to: CGPoint(x: 285, y: 180))
            cg.strokePath()

        case "plastic_rib_ratio":
            // 塑膠主壁厚與加強筋 (Rib)
            cg.stroke(CGRect(x: 80, y: 220, width: 240, height: 35)) // 主壁厚 T
            cg.stroke(CGRect(x: 185, y: 100, width: 30, height: 120)) // 筋 0.6T
            // 根部圓角
            ellipse(cg, CGRect(x: 177, y: 212, width: 16, height: 16))
            ellipse(cg, CGRect(x: 207, y: 212, width: 16, height: 16))

        case "boss_tower":
            // 自攻牙注塑螺絲柱
            cg.stroke(CGRect(x: 160, y: 80, width: 80, height: 140)) // 外柱
            cg.stroke(CGRect(x: 180, y: 80, width: 40, height: 100)) // 螺絲沉孔
            // 基座三角支撐筋
            cg.move(to: CGPoint(x: 160, y: 140)); cg.addLine(to: CGPoint(x: 110, y: 220)); cg.addLine(to: CGPoint(x: 160, y: 220))
            cg.move(to: CGPoint(x: 240, y: 140)); cg.addLine(to: CGPoint(x: 290, y: 220)); cg.addLine(to: CGPoint(x: 240, y: 220))
            cg.stroke(CGRect(x: 90, y: 220, width: 220, height: 25)) // 底板
            cg.strokePath()

        case "sheetmetal_bend":
            // 鈑金折彎 90° 剖面與 K-Factor 中性層
            cg.move(to: CGPoint(x: 80, y: 110)); cg.addLine(to: CGPoint(x: 200, y: 110))
            cg.addLine(to: CGPoint(x: 200, y: 240)); cg.addLine(to: CGPoint(x: 230, y: 240))
            cg.addLine(to: CGPoint(x: 230, y: 80)); cg.addLine(to: CGPoint(x: 80, y: 80))
            cg.closePath()
            cg.strokePath()
            // 中性層虛線
            cg.setLineWidth(1.2)
            cg.move(to: CGPoint(x: 80, y: 95)); cg.addLine(to: CGPoint(x: 215, y: 95))
            cg.addLine(to: CGPoint(x: 215, y: 240))
            cg.strokePath()

        case "cnc_dogbone":
            // CNC 銑削狗骨狀清角
            let pocket = CGRect(x: 120, y: 90, width: 160, height: 160)
            cg.stroke(pocket)
            // 四個角狗骨圓孔
            let r: CGFloat = 12
            ellipse(cg, CGRect(x: 120 - r/2, y: 90 - r/2, width: r, height: r))
            ellipse(cg, CGRect(x: 280 - r/2, y: 90 - r/2, width: r, height: r))
            ellipse(cg, CGRect(x: 120 - r/2, y: 250 - r/2, width: r, height: r))
            ellipse(cg, CGRect(x: 280 - r/2, y: 250 - r/2, width: r, height: r))

        case "pem_standoff":
            // 壓鉚螺母柱
            cg.stroke(CGRect(x: 155, y: 90, width: 90, height: 40)) // 六角法蘭頭
            cg.stroke(CGRect(x: 165, y: 130, width: 70, height: 120)) // 圓柱主體
            cg.stroke(CGRect(x: 180, y: 90, width: 40, height: 160)) // 貫穿內螺紋
            cg.strokePath()

        case "anodizing_spec":
            // 陽極氧化皮膜剖面與微孔陣列
            cg.stroke(CGRect(x: 80, y: 140, width: 240, height: 120)) // 鋁基材
            cg.stroke(CGRect(x: 80, y: 90, width: 240, height: 50)) // 氧化皮膜層
            // 微孔陣列線條
            var px: CGFloat = 100
            while px < 310 {
                cg.move(to: CGPoint(x: px, y: 90)); cg.addLine(to: CGPoint(x: px, y: 135))
                px += 18
            }
            cg.strokePath()

        case "roughness_ra":
            // 表面粗糙度微觀起伏
            cg.move(to: CGPoint(x: 80, y: 160))
            for i in 0..<8 {
                let xBase = 80 + CGFloat(i) * 30
                cg.addLine(to: CGPoint(x: xBase + 15, y: (i % 2 == 0) ? 120 : 200))
                cg.addLine(to: CGPoint(x: xBase + 30, y: 160))
            }
            cg.strokePath()
            // Ra 中心平均線
            cg.setLineWidth(1.0)
            cg.move(to: CGPoint(x: 70, y: 160)); cg.addLine(to: CGPoint(x: 330, y: 160))
            cg.strokePath()

        case "pneumatic_cylinder":
            // 氣壓滑台雙導軌氣缸
            cg.stroke(CGRect(x: 110, y: 120, width: 180, height: 90)) // 氣缸主體
            cg.stroke(CGRect(x: 70, y: 135, width: 40, height: 15)) // 活塞軸
            cg.stroke(CGRect(x: 70, y: 180, width: 40, height: 15)) // 下導軌
            cg.stroke(CGRect(x: 60, y: 110, width: 15, height: 110)) // 前安裝承板
            ellipse(cg, CGRect(x: 130, y: 105, width: 14, height: 14)) // 氣孔 A
            ellipse(cg, CGRect(x: 250, y: 105, width: 14, height: 14)) // 氣孔 B
            cg.strokePath()

        case "push_in_fitting":
            // 直角快插接頭
            cg.stroke(CGRect(x: 130, y: 130, width: 80, height: 60)) // 彎頭主體
            cg.stroke(CGRect(x: 150, y: 190, width: 40, height: 60)) // 螺紋接口
            cg.stroke(CGRect(x: 210, y: 140, width: 50, height: 40)) // 快插套筒
            cg.strokePath()

        case "dual_os_navbar":
            // 跨平台導航列 (iOS vs Android)
            cg.stroke(CGRect(x: 70, y: 90, width: 120, height: 150)) // iOS 大標題列
            cg.stroke(CGRect(x: 210, y: 120, width: 120, height: 120)) // Android TopAppBar
            // 導航圖標與分隔指示
            ellipse(cg, CGRect(x: 85, y: 105, width: 12, height: 12))
            ellipse(cg, CGRect(x: 225, y: 135, width: 12, height: 12))

        case "bottom_sheet_ui":
            // 底部操作卡片 Bottom Sheet
            let cardRect = CGRect(x: 90, y: 120, width: 220, height: 180)
            let cardPath = UIBezierPath(roundedRect: cardRect, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 20, height: 20))
            cg.addPath(cardPath.cgPath)
            cg.strokePath()
            // 頂部抓手 Grabber
            let grabber = CGRect(x: 175, y: 135, width: 50, height: 6)
            let grabberPath = UIBezierPath(roundedRect: grabber, cornerRadius: 3)
            cg.addPath(grabberPath.cgPath)
            cg.fillPath()

        case "cubic_bezier_curve":
            // 三次貝茲時間曲線
            let box = CGRect(x: 80, y: 80, width: 240, height: 180)
            cg.stroke(box)
            // S 形貝茲曲線
            cg.move(to: CGPoint(x: 80, y: 260))
            cg.addCurve(to: CGPoint(x: 320, y: 80), control1: CGPoint(x: 160, y: 260), control2: CGPoint(x: 240, y: 80))
            cg.strokePath()
            // 控制桿手柄
            cg.setLineWidth(1.0)
            cg.move(to: CGPoint(x: 80, y: 260)); cg.addLine(to: CGPoint(x: 160, y: 260))
            ellipse(cg, CGRect(x: 156, y: 256, width: 8, height: 8))
            cg.move(to: CGPoint(x: 320, y: 80)); cg.addLine(to: CGPoint(x: 240, y: 80))
            ellipse(cg, CGRect(x: 236, y: 76, width: 8, height: 8))
            cg.strokePath()

        case "spring_physics":
            // 阻尼彈簧衰減正弦波
            cg.move(to: CGPoint(x: 70, y: 160))
            var sx: CGFloat = 70
            while sx <= 330 {
                let t = (sx - 70) / 260
                let amplitude = 80 * exp(-3.0 * t)
                let sy = 160 - amplitude * sin(t * .pi * 8)
                cg.addLine(to: CGPoint(x: sx, y: sy))
                sx += 4
            }
            cg.strokePath()

        case "sitemap_tree":
            // 資訊架構樹
            cg.stroke(CGRect(x: 160, y: 80, width: 80, height: 40)) // 根節點
            cg.stroke(CGRect(x: 80, y: 180, width: 65, height: 35))
            cg.stroke(CGRect(x: 167, y: 180, width: 65, height: 35))
            cg.stroke(CGRect(x: 255, y: 180, width: 65, height: 35))
            // 樹狀連線
            cg.move(to: CGPoint(x: 200, y: 120)); cg.addLine(to: CGPoint(x: 200, y: 150))
            cg.move(to: CGPoint(x: 112, y: 150)); cg.addLine(to: CGPoint(x: 287, y: 150))
            cg.move(to: CGPoint(x: 112, y: 150)); cg.addLine(to: CGPoint(x: 112, y: 180))
            cg.move(to: CGPoint(x: 200, y: 150)); cg.addLine(to: CGPoint(x: 200, y: 180))
            cg.move(to: CGPoint(x: 287, y: 150)); cg.addLine(to: CGPoint(x: 287, y: 180))
            cg.strokePath()

        case "state_machine_flow":
            // 狀態機躍遷流程
            let s1 = CGRect(x: 80, y: 140, width: 70, height: 50)
            let s2 = CGRect(x: 250, y: 140, width: 70, height: 50)
            let p1 = UIBezierPath(roundedRect: s1, cornerRadius: 10)
            let p2 = UIBezierPath(roundedRect: s2, cornerRadius: 10)
            cg.addPath(p1.cgPath); cg.strokePath()
            cg.addPath(p2.cgPath); cg.strokePath()
            // 雙向箭頭
            cg.move(to: CGPoint(x: 150, y: 155)); cg.addLine(to: CGPoint(x: 250, y: 155))
            cg.move(to: CGPoint(x: 250, y: 175)); cg.addLine(to: CGPoint(x: 150, y: 175))
            cg.strokePath()

        case "spacing_8pt_grid":
            // 8pt 空間尺度網格
            let gridSizes: [CGFloat] = [8, 16, 24, 32, 48, 64]
            var gx: CGFloat = 70
            for gs in gridSizes {
                cg.stroke(CGRect(x: gx, y: 180 - gs, width: gs, height: gs))
                gx += gs + 8
                if gx > 320 { break }
            }
            cg.strokePath()

        case "semantic_color_tokens":
            // 語意色彩 Token 矩陣
            let cols = [
                CGRect(x: 80, y: 90, width: 105, height: 60),
                CGRect(x: 215, y: 90, width: 105, height: 60),
                CGRect(x: 80, y: 180, width: 105, height: 60),
                CGRect(x: 215, y: 180, width: 105, height: 60)
            ]
            for c in cols {
                let cp = UIBezierPath(roundedRect: c, cornerRadius: 8)
                cg.addPath(cp.cgPath)
                cg.strokePath()
            }

        // ---- 機構設計 ----

        case "linear_guide":
            // 滾珠螺桿滑軌：側視導軌 + 跨座滑塊 + 螺桿
            stroke(cg, rounded: CGRect(x: 45, y: 205, width: 310, height: 34), radius: 4)
            polyline(cg, [CGPoint(x: 45, y: 222), CGPoint(x: 355, y: 222)])
            // 滑塊本體
            stroke(cg, rounded: CGRect(x: 150, y: 178, width: 110, height: 88), radius: 8)
            // 滑塊內的四方向滾珠循環列
            for row in 0..<2 {
                for col in 0..<4 {
                    circle(cg, CGPoint(x: 168 + CGFloat(col) * 25, y: 198 + CGFloat(row) * 48), 6)
                }
            }
            // 螺桿與導程牙形
            cg.setLineWidth(1.4)
            threadProfile(cg, x: 200, top: 100, bottom: 170, halfWidth: 14, pitch: 10)
            polyline(cg, [CGPoint(x: 186, y: 100), CGPoint(x: 186, y: 170)])
            polyline(cg, [CGPoint(x: 214, y: 100), CGPoint(x: 214, y: 170)])
            cg.setLineWidth(2.5)
            // 安裝孔
            for i in 0..<4 {
                circle(cg, CGPoint(x: 75 + CGFloat(i) * 83, y: 222), 5)
            }

        case "cam_follower":
            // 盤形凸輪 + 滾子從動件
            let camCenter = CGPoint(x: 165, y: 215)
            circle(cg, camCenter, 16)
            // 等徑盤形凸輪輪廓（簡諧升程：基圓半徑 + 正弦升程）
            var camPts: [CGPoint] = []
            for deg in stride(from: 0, through: 360, by: 6) {
                let a = CGFloat(deg) * .pi / 180
                let lift: CGFloat = 26 * (1 - cos(a)) / 2
                let r = 58 + lift
                camPts.append(CGPoint(x: camCenter.x + cos(a) * r, y: camCenter.y + sin(a) * r))
            }
            polyline(cg, camPts, closed: true)
            // 滾子從動件與導桿
            circle(cg, CGPoint(x: 165, y: 122), 16)
            polyline(cg, [CGPoint(x: 165, y: 106), CGPoint(x: 165, y: 62)])
            stroke(cg, rounded: CGRect(x: 148, y: 56, width: 34, height: 18), radius: 3)
            // 行程標註
            cg.setLineWidth(1.2)
            cg.setStrokeColor(accentColor.cgColor)
            polyline(cg, [CGPoint(x: 255, y: 96), CGPoint(x: 255, y: 122)])
            polyline(cg, [CGPoint(x: 249, y: 96), CGPoint(x: 261, y: 96)])
            polyline(cg, [CGPoint(x: 249, y: 122), CGPoint(x: 261, y: 122)])
            cg.setStrokeColor(strokeColor.cgColor)
            cg.setLineWidth(2.5)

        case "stepper_motor":
            // NEMA 17 正視：方形機殼 + 中心凸台 + 四角安裝孔
            stroke(cg, rounded: CGRect(x: 110, y: 95, width: 180, height: 180), radius: 14)
            circle(cg, CGPoint(x: 200, y: 185), 36)
            circle(cg, CGPoint(x: 200, y: 185), 12)
            for dx in [-1.0, 1.0] {
                for dy in [-1.0, 1.0] {
                    circle(cg, CGPoint(x: 200 + CGFloat(dx) * 62, y: 185 + CGFloat(dy) * 62), 8)
                }
            }
            // D 形軸切邊
            polyline(cg, [CGPoint(x: 191, y: 176), CGPoint(x: 191, y: 194)])
            // 雙極四線出線
            cg.setLineWidth(1.5)
            for i in 0..<4 {
                let y = 292 + CGFloat(i) * 5
                polyline(cg, [CGPoint(x: 175 + CGFloat(i) * 4, y: 275), CGPoint(x: 150, y: y)])
            }
            cg.setLineWidth(2.5)

        case "ai_exoskeleton":
            // 外骨骼膝關節：大腿護具、仿生雙心瞬時軸、小腿護具與線性致動器
            stroke(cg, rounded: CGRect(x: 136, y: 62, width: 88, height: 30), radius: 12)
            polyline(cg, [CGPoint(x: 146, y: 92), CGPoint(x: 152, y: 164)])
            polyline(cg, [CGPoint(x: 214, y: 92), CGPoint(x: 208, y: 164)])
            // 雙心瞬時迴轉軸（兩個不同心的樞軸，仿生膝關節的關鍵特徵）
            stroke(cg, rounded: CGRect(x: 140, y: 164, width: 80, height: 48), radius: 14)
            circle(cg, CGPoint(x: 162, y: 180), 10)
            circle(cg, CGPoint(x: 198, y: 196), 10)
            polyline(cg, [CGPoint(x: 162, y: 180), CGPoint(x: 198, y: 196)])
            // 小腿護具
            polyline(cg, [CGPoint(x: 152, y: 212), CGPoint(x: 158, y: 278)])
            polyline(cg, [CGPoint(x: 208, y: 212), CGPoint(x: 202, y: 278)])
            stroke(cg, rounded: CGRect(x: 150, y: 278, width: 60, height: 26), radius: 10)
            // 足底板
            polyline(cg, [CGPoint(x: 150, y: 304), CGPoint(x: 246, y: 304)])
            // 並聯線性致動器
            stroke(cg, rounded: CGRect(x: 244, y: 96, width: 28, height: 74), radius: 8)
            polyline(cg, [CGPoint(x: 258, y: 170), CGPoint(x: 258, y: 214)])
            circle(cg, CGPoint(x: 258, y: 222), 9)
            polyline(cg, [CGPoint(x: 258, y: 96), CGPoint(x: 214, y: 78)])
            polyline(cg, [CGPoint(x: 258, y: 222), CGPoint(x: 208, y: 212)])

        case "earbud_acoustic":
            // TWS 耳機剖面：耳甲腔體、10mm 動圈、出音導管與矽膠耳塞
            ellipse(cg, CGRect(x: 104, y: 96, width: 132, height: 124))
            // 10mm 鍍鈹動圈單體
            circle(cg, CGPoint(x: 170, y: 158), 40)
            circle(cg, CGPoint(x: 170, y: 158), 16)
            // 出音導管（往耳道方向的錐狀收口）
            polyline(cg, [CGPoint(x: 228, y: 128), CGPoint(x: 300, y: 176)])
            polyline(cg, [CGPoint(x: 220, y: 186), CGPoint(x: 292, y: 224)])
            polyline(cg, [CGPoint(x: 300, y: 176), CGPoint(x: 292, y: 224)])
            // 矽膠耳塞（傘狀）
            cg.move(to: CGPoint(x: 300, y: 176))
            cg.addQuadCurve(to: CGPoint(x: 292, y: 224), control: CGPoint(x: 350, y: 200))
            cg.strokePath()
            // 柄部（收音麥克風臂）
            stroke(cg, rounded: CGRect(x: 128, y: 208, width: 30, height: 92), radius: 15)
            circle(cg, CGPoint(x: 143, y: 284), 7)
            // 雙洩壓閥微孔陣列
            cg.setLineWidth(1.2)
            for i in 0..<6 {
                circle(cg, CGPoint(x: 178 + CGFloat(i % 3) * 11, y: 224 + CGFloat(i / 3) * 11), 3)
            }
            cg.setLineWidth(2.5)

        case "camera_lens":
            // 鏡頭光學剖面：鏡筒、雙凸／雙凹鏡片群、光軸與金屬卡口
            stroke(cg, rounded: CGRect(x: 88, y: 116, width: 212, height: 138), radius: 8)
            // 鏡片群：正透鏡（雙凸）與負透鏡（雙凹）交錯
            let elements: [(CGFloat, CGFloat)] = [
                (116, 16), (146, -11), (176, 20), (206, -9), (236, 14), (268, 18)
            ]
            for (x, bulge) in elements {
                let top = CGPoint(x: x, y: 132)
                let bottom = CGPoint(x: x, y: 238)
                cg.move(to: top)
                cg.addQuadCurve(to: bottom, control: CGPoint(x: x + bulge, y: 185))
                cg.strokePath()
                cg.move(to: top)
                cg.addQuadCurve(to: bottom, control: CGPoint(x: x - bulge, y: 185))
                cg.strokePath()
            }
            // 光軸中心線
            cg.saveGState()
            cg.setLineWidth(1.0)
            cg.setLineDash(phase: 0, lengths: [10, 5, 3, 5])
            polyline(cg, [CGPoint(x: 70, y: 185), CGPoint(x: 336, y: 185)])
            cg.restoreGState()
            cg.setLineWidth(2.5)
            // 金屬卡口法蘭與防塵密封圈
            polyline(cg, [CGPoint(x: 300, y: 100), CGPoint(x: 300, y: 270)])
            polyline(cg, [CGPoint(x: 300, y: 100), CGPoint(x: 324, y: 100)])
            polyline(cg, [CGPoint(x: 300, y: 270), CGPoint(x: 324, y: 270)])
            polyline(cg, [CGPoint(x: 324, y: 100), CGPoint(x: 324, y: 270)])
            // 對焦環滾花
            cg.setLineWidth(1.4)
            for i in 0..<10 {
                polyline(cg, [
                    CGPoint(x: 120 + CGFloat(i) * 9, y: 116),
                    CGPoint(x: 120 + CGFloat(i) * 9, y: 130)
                ])
            }
            cg.setLineWidth(2.5)

        case "keyboard_gasket":
            // 75% 配列：外殼、定位板與鍵位陣列
            stroke(cg, rounded: CGRect(x: 40, y: 128, width: 320, height: 145), radius: 10)
            stroke(cg, rounded: CGRect(x: 50, y: 138, width: 300, height: 125), radius: 6)
            cg.setLineWidth(1.2)
            // 功能列
            for i in 0..<16 {
                stroke(cg, rounded: CGRect(x: 57 + CGFloat(i) * 18.3, y: 144, width: 15, height: 15), radius: 2)
            }
            // 主鍵區四列
            for row in 0..<4 {
                let offset: CGFloat = [0, 5, 9, 14][row]
                let count = [15, 14, 13, 12][row]
                for col in 0..<count {
                    stroke(cg, rounded: CGRect(
                        x: 57 + offset + CGFloat(col) * 18.3,
                        y: 164 + CGFloat(row) * 19,
                        width: 15,
                        height: 16
                    ), radius: 2)
                }
            }
            cg.setLineWidth(2.5)
            // Gasket 矽膠襯墊位置
            cg.setStrokeColor(accentColor.cgColor)
            cg.setLineWidth(3.5)
            for i in 0..<4 {
                polyline(cg, [
                    CGPoint(x: 70 + CGFloat(i) * 78, y: 128),
                    CGPoint(x: 110 + CGFloat(i) * 78, y: 128)
                ])
                polyline(cg, [
                    CGPoint(x: 70 + CGFloat(i) * 78, y: 273),
                    CGPoint(x: 110 + CGFloat(i) * 78, y: 273)
                ])
            }
            cg.setStrokeColor(strokeColor.cgColor)
            cg.setLineWidth(2.5)

        case "ai_hud_display":
            // 曲面座艙 HUD：弧形投影面 + 準星 + 資料區塊
            cg.move(to: CGPoint(x: 60, y: 150))
            cg.addQuadCurve(to: CGPoint(x: 340, y: 150), control: CGPoint(x: 200, y: 100))
            cg.addLine(to: CGPoint(x: 340, y: 250))
            cg.addQuadCurve(to: CGPoint(x: 60, y: 250), control: CGPoint(x: 200, y: 200))
            cg.closePath()
            cg.strokePath()
            // 中央準星
            circle(cg, CGPoint(x: 200, y: 188), 30)
            circle(cg, CGPoint(x: 200, y: 188), 6)
            polyline(cg, [CGPoint(x: 160, y: 188), CGPoint(x: 182, y: 188)])
            polyline(cg, [CGPoint(x: 218, y: 188), CGPoint(x: 240, y: 188)])
            polyline(cg, [CGPoint(x: 200, y: 148), CGPoint(x: 200, y: 170)])
            polyline(cg, [CGPoint(x: 200, y: 206), CGPoint(x: 200, y: 228)])
            // 左右資料條
            cg.setLineWidth(1.5)
            for i in 0..<5 {
                let w: CGFloat = [44, 34, 40, 28, 36][i]
                polyline(cg, [CGPoint(x: 74, y: 168 + CGFloat(i) * 12), CGPoint(x: 74 + w, y: 168 + CGFloat(i) * 12)])
                polyline(cg, [CGPoint(x: 326 - w, y: 168 + CGFloat(i) * 12), CGPoint(x: 326, y: 168 + CGFloat(i) * 12)])
            }
            cg.setLineWidth(2.5)
            // 眼球追蹤感測模組
            ellipse(cg, CGRect(x: 176, y: 274, width: 48, height: 24))
            circle(cg, CGPoint(x: 200, y: 286), 6)

        // ---- 汽車載具 ----

        case "wheel_rim":
            // 五輻雙柱鍛造輪框正視
            let hub = CGPoint(x: 200, y: 190)
            circle(cg, hub, 122)
            circle(cg, hub, 108)
            circle(cg, hub, 40)
            circle(cg, hub, 14)
            // 五組雙柱輻條
            for i in 0..<5 {
                let a = CGFloat(i) * (2 * .pi / 5) - .pi / 2
                for side in [-1.0, 1.0] {
                    let spread = CGFloat(side) * 0.13
                    polyline(cg, [
                        CGPoint(x: hub.x + cos(a + spread * 2.2) * 38, y: hub.y + sin(a + spread * 2.2) * 38),
                        CGPoint(x: hub.x + cos(a + spread) * 106, y: hub.y + sin(a + spread) * 106)
                    ])
                }
            }
            // PCD 5x114.3 螺栓孔
            for i in 0..<5 {
                let a = CGFloat(i) * (2 * .pi / 5) - .pi / 2
                circle(cg, CGPoint(x: hub.x + cos(a) * 27, y: hub.y + sin(a) * 27), 6)
            }

        case "suspension_geometry":
            // 雙 A 臂懸吊：上下 A 臂、轉向節、倒插式避震與輪胎輪廓
            // 車身側固定基準
            cg.setLineWidth(3.0)
            polyline(cg, [CGPoint(x: 62, y: 104), CGPoint(x: 62, y: 268)])
            cg.setLineWidth(2.5)
            // 上 A 臂（較短）
            polyline(cg, [CGPoint(x: 62, y: 128), CGPoint(x: 214, y: 150)])
            polyline(cg, [CGPoint(x: 62, y: 152), CGPoint(x: 214, y: 150)])
            // 下 A 臂（較長）
            polyline(cg, [CGPoint(x: 62, y: 232), CGPoint(x: 238, y: 250)])
            polyline(cg, [CGPoint(x: 62, y: 256), CGPoint(x: 238, y: 250)])
            // 轉向節（直立柱）
            cg.setLineWidth(3.0)
            polyline(cg, [CGPoint(x: 214, y: 150), CGPoint(x: 238, y: 250)])
            cg.setLineWidth(2.5)
            // 上下球接頭
            circle(cg, CGPoint(x: 214, y: 150), 9)
            circle(cg, CGPoint(x: 238, y: 250), 9)
            // 倒插式避震器：兩側筒身 + 內部螺旋彈簧
            polyline(cg, [CGPoint(x: 134, y: 92), CGPoint(x: 134, y: 240)])
            polyline(cg, [CGPoint(x: 174, y: 92), CGPoint(x: 174, y: 240)])
            polyline(cg, [CGPoint(x: 134, y: 92), CGPoint(x: 174, y: 92)])
            cg.setLineWidth(1.8)
            var coil: [CGPoint] = []
            var cy: CGFloat = 104
            var left = true
            while cy <= 232 {
                coil.append(CGPoint(x: left ? 136 : 172, y: cy))
                left.toggle()
                cy += 11
            }
            polyline(cg, coil)
            cg.setLineWidth(2.5)
            polyline(cg, [CGPoint(x: 134, y: 240), CGPoint(x: 174, y: 240)])
            polyline(cg, [CGPoint(x: 154, y: 240), CGPoint(x: 226, y: 250)])
            // 輪胎與輪輞
            cg.setLineWidth(1.6)
            circle(cg, CGPoint(x: 292, y: 200), 74)
            cg.setLineWidth(2.5)
            circle(cg, CGPoint(x: 292, y: 200), 44)
            circle(cg, CGPoint(x: 292, y: 200), 12)
            polyline(cg, [CGPoint(x: 238, y: 250), CGPoint(x: 292, y: 200)])

        case "steering_wheel":
            // D 型平底三輻方向盤：以點列組出上緣圓弧 + 下緣平底的環形輪圈
            let wheelC = CGPoint(x: 200, y: 186)
            let outerR: CGFloat = 112
            let innerR: CGFloat = 86
            // 平底切在 y = cy + 78 → 對應角度 asin(78/r)
            let cutDeg = Double(asin(78 / outerR)) * 180 / .pi
            var rimOuter: [CGPoint] = []
            var deg = cutDeg
            while deg >= -(360 - (180 - cutDeg)) {
                let a = CGFloat(deg) * .pi / 180
                rimOuter.append(CGPoint(x: wheelC.x + cos(a) * outerR, y: wheelC.y + sin(a) * outerR))
                deg -= 4
            }
            var rimInner: [CGPoint] = []
            deg = -(360 - (180 - cutDeg))
            while deg <= cutDeg {
                let a = CGFloat(deg) * .pi / 180
                rimInner.append(CGPoint(x: wheelC.x + cos(a) * innerR, y: wheelC.y + sin(a) * innerR))
                deg += 4
            }
            polyline(cg, rimOuter + rimInner, closed: true)
            // 中央氣囊蓋
            stroke(cg, rounded: CGRect(x: 164, y: 158, width: 72, height: 58), radius: 14)
            // 三輻（左、右、下）
            cg.setLineWidth(6.0)
            polyline(cg, [CGPoint(x: 164, y: 176), CGPoint(x: 116, y: 168)])
            polyline(cg, [CGPoint(x: 236, y: 176), CGPoint(x: 284, y: 168)])
            polyline(cg, [CGPoint(x: 200, y: 216), CGPoint(x: 200, y: 262)])
            cg.setLineWidth(2.5)
            // 拇指托
            stroke(cg, rounded: CGRect(x: 96, y: 132, width: 24, height: 54), radius: 10)
            stroke(cg, rounded: CGRect(x: 280, y: 132, width: 24, height: 54), radius: 10)
            // 背部碳纖維換檔撥片
            cg.setLineWidth(1.8)
            polyline(cg, [CGPoint(x: 128, y: 108), CGPoint(x: 156, y: 94)])
            polyline(cg, [CGPoint(x: 272, y: 108), CGPoint(x: 244, y: 94)])
            cg.setLineWidth(2.5)

        case "ev_chassis":
            // 滑板底盤俯視：外框、CTP 電池包、雙電機與四輪
            stroke(cg, rounded: CGRect(x: 78, y: 92, width: 244, height: 200), radius: 24)
            stroke(cg, rounded: CGRect(x: 96, y: 128, width: 208, height: 128), radius: 10)
            // CTP 無模組電芯陣列
            cg.setLineWidth(1.2)
            for row in 0..<4 {
                for col in 0..<10 {
                    stroke(cg, rounded: CGRect(
                        x: 103 + CGFloat(col) * 20,
                        y: 135 + CGFloat(row) * 30,
                        width: 16,
                        height: 25
                    ), radius: 2)
                }
            }
            cg.setLineWidth(2.5)
            // 前後永磁同步電機
            circle(cg, CGPoint(x: 200, y: 110), 16)
            circle(cg, CGPoint(x: 200, y: 274), 16)
            // 四輪
            for pos in [CGPoint(x: 68, y: 128), CGPoint(x: 332, y: 128), CGPoint(x: 68, y: 256), CGPoint(x: 332, y: 256)] {
                stroke(cg, rounded: CGRect(x: pos.x - 12, y: pos.y - 26, width: 24, height: 52), radius: 8)
            }

        case "ai_orbital_shuttle":
            // 多面體隱形外殼 + 向量離子推進 + 環形重力艙
            polyline(cg, [
                CGPoint(x: 200, y: 68), CGPoint(x: 276, y: 140), CGPoint(x: 296, y: 232),
                CGPoint(x: 200, y: 286), CGPoint(x: 104, y: 232), CGPoint(x: 124, y: 140)
            ], closed: true)
            polyline(cg, [CGPoint(x: 200, y: 68), CGPoint(x: 200, y: 286)])
            polyline(cg, [CGPoint(x: 124, y: 140), CGPoint(x: 276, y: 140)])
            polyline(cg, [CGPoint(x: 104, y: 232), CGPoint(x: 296, y: 232)])
            // 駕駛艙
            ellipse(cg, CGRect(x: 176, y: 96, width: 48, height: 36))
            // 環形重力偏轉艙
            ellipse(cg, CGRect(x: 96, y: 176, width: 208, height: 56))
            // 向量離子噴口
            for x in [166.0, 200.0, 234.0] {
                polyline(cg, [
                    CGPoint(x: CGFloat(x) - 12, y: 286),
                    CGPoint(x: CGFloat(x) - 18, y: 312),
                    CGPoint(x: CGFloat(x) + 18, y: 312),
                    CGPoint(x: CGFloat(x) + 12, y: 286)
                ])
            }

        // ---- 工業家具 ----

        case "standing_desk":
            // 升降桌：桌板 + 雙三節升降柱 + 腳座 + 行程標註
            stroke(cg, rounded: CGRect(x: 58, y: 104, width: 284, height: 18), radius: 4)
            // 三節柱（兩側）
            for baseX in [112.0, 258.0] {
                let x = CGFloat(baseX)
                stroke(cg, rounded: CGRect(x: x - 17, y: 122, width: 34, height: 70), radius: 3)
                stroke(cg, rounded: CGRect(x: x - 13, y: 192, width: 26, height: 56), radius: 3)
                stroke(cg, rounded: CGRect(x: x - 9, y: 248, width: 18, height: 42), radius: 3)
                stroke(cg, rounded: CGRect(x: x - 44, y: 290, width: 88, height: 14), radius: 4)
            }
            // 橫樑
            polyline(cg, [CGPoint(x: 112, y: 150), CGPoint(x: 258, y: 150)])
            // 升降行程箭頭
            cg.setStrokeColor(accentColor.cgColor)
            cg.setLineWidth(1.6)
            polyline(cg, [CGPoint(x: 188, y: 176), CGPoint(x: 188, y: 268)])
            polyline(cg, [CGPoint(x: 182, y: 184), CGPoint(x: 188, y: 174), CGPoint(x: 194, y: 184)])
            polyline(cg, [CGPoint(x: 182, y: 260), CGPoint(x: 188, y: 270), CGPoint(x: 194, y: 260)])
            cg.setStrokeColor(strokeColor.cgColor)
            cg.setLineWidth(2.5)

        case "task_lamp":
            // 包浩斯懸臂燈：底座 + 四連桿平行臂 + 環形燈罩
            ellipse(cg, CGRect(x: 96, y: 278, width: 116, height: 26))
            polyline(cg, [CGPoint(x: 154, y: 278), CGPoint(x: 154, y: 214)])
            // 四連桿平行臂（下臂）
            polyline(cg, [CGPoint(x: 154, y: 214), CGPoint(x: 236, y: 146)])
            polyline(cg, [CGPoint(x: 164, y: 224), CGPoint(x: 246, y: 156)])
            // 上臂
            polyline(cg, [CGPoint(x: 236, y: 146), CGPoint(x: 300, y: 196)])
            polyline(cg, [CGPoint(x: 246, y: 156), CGPoint(x: 310, y: 206)])
            // 阻尼關節
            circle(cg, CGPoint(x: 158, y: 218), 11)
            circle(cg, CGPoint(x: 241, y: 151), 11)
            // 環形無頻閃光源
            circle(cg, CGPoint(x: 305, y: 216), 30)
            circle(cg, CGPoint(x: 305, y: 216), 18)

        case "modular_credenza":
            // 模組收納櫃：上下兩模組、45° 倒角拉手、插榫與細腳
            stroke(cg, rounded: CGRect(x: 66, y: 112, width: 268, height: 76), radius: 4)
            stroke(cg, rounded: CGRect(x: 66, y: 188, width: 268, height: 76), radius: 4)
            // 分割門片
            polyline(cg, [CGPoint(x: 200, y: 112), CGPoint(x: 200, y: 188)])
            polyline(cg, [CGPoint(x: 156, y: 188), CGPoint(x: 156, y: 264)])
            polyline(cg, [CGPoint(x: 244, y: 188), CGPoint(x: 244, y: 264)])
            // 45° 倒角隱藏拉手
            cg.setLineWidth(1.6)
            for handle in [
                CGRect(x: 96, y: 146, width: 70, height: 10),
                CGRect(x: 234, y: 146, width: 70, height: 10),
                CGRect(x: 92, y: 220, width: 48, height: 10)
            ] {
                polyline(cg, [
                    CGPoint(x: handle.minX, y: handle.maxY),
                    CGPoint(x: handle.minX + 8, y: handle.minY),
                    CGPoint(x: handle.maxX, y: handle.minY)
                ])
            }
            cg.setLineWidth(2.5)
            // 模組插榫
            for x in [110.0, 200.0, 290.0] {
                circle(cg, CGPoint(x: CGFloat(x), y: 188), 5)
            }
            // 細腳
            polyline(cg, [CGPoint(x: 92, y: 264), CGPoint(x: 84, y: 300)])
            polyline(cg, [CGPoint(x: 308, y: 264), CGPoint(x: 316, y: 300)])

        // ---- 五金零件 ----

        case "countersunk_screw":
            // DIN 7991 沉頭螺釘側視 + 內六角頂視
            polyline(cg, [
                CGPoint(x: 108, y: 118), CGPoint(x: 292, y: 118),
                CGPoint(x: 232, y: 166), CGPoint(x: 168, y: 166)
            ], closed: true)
            // 90° 錐角標註
            cg.setLineWidth(1.2)
            cg.setStrokeColor(accentColor.cgColor)
            polyline(cg, [CGPoint(x: 200, y: 118), CGPoint(x: 168, y: 166)])
            polyline(cg, [CGPoint(x: 200, y: 118), CGPoint(x: 232, y: 166)])
            cg.setStrokeColor(strokeColor.cgColor)
            cg.setLineWidth(2.5)
            // 螺桿與螺紋
            polyline(cg, [CGPoint(x: 168, y: 166), CGPoint(x: 168, y: 286)])
            polyline(cg, [CGPoint(x: 232, y: 166), CGPoint(x: 232, y: 286)])
            polyline(cg, [CGPoint(x: 168, y: 286), CGPoint(x: 232, y: 286)])
            cg.setLineWidth(1.4)
            threadProfile(cg, x: 200, top: 176, bottom: 280, halfWidth: 32, pitch: 13)
            cg.setLineWidth(2.5)
            // 內六角孔（頂視）
            var hexPts: [CGPoint] = []
            for i in 0..<6 {
                let a = CGFloat(i) * .pi / 3 - .pi / 6
                hexPts.append(CGPoint(x: 200 + cos(a) * 20, y: 90 + sin(a) * 20))
            }
            polyline(cg, hexPts, closed: true)

        case "flange_nut":
            // 六角法蘭螺母：頂視六角 + 法蘭圓 + 側視鋸齒
            circle(cg, CGPoint(x: 200, y: 148), 74)
            var nutPts: [CGPoint] = []
            for i in 0..<6 {
                let a = CGFloat(i) * .pi / 3
                nutPts.append(CGPoint(x: 200 + cos(a) * 54, y: 148 + sin(a) * 54))
            }
            polyline(cg, nutPts, closed: true)
            circle(cg, CGPoint(x: 200, y: 148), 26)
            // 內螺紋示意
            cg.setLineWidth(1.2)
            circle(cg, CGPoint(x: 200, y: 148), 22)
            cg.setLineWidth(2.5)
            // 側視：法蘭面與底部防滑鋸齒
            polyline(cg, [
                CGPoint(x: 126, y: 262), CGPoint(x: 146, y: 236),
                CGPoint(x: 254, y: 236), CGPoint(x: 274, y: 262)
            ], closed: true)
            cg.setLineWidth(1.4)
            var teeth: [CGPoint] = []
            var tx: CGFloat = 128
            var up = false
            while tx <= 272 {
                teeth.append(CGPoint(x: tx, y: up ? 262 : 270))
                up.toggle()
                tx += 9
            }
            polyline(cg, teeth)
            cg.setLineWidth(2.5)

        case "blind_rivet":
            // 封閉型抽芯盲鉚釘：法蘭頭、鉚體、封閉端與抽芯桿
            polyline(cg, [
                CGPoint(x: 130, y: 112), CGPoint(x: 270, y: 112),
                CGPoint(x: 270, y: 130), CGPoint(x: 130, y: 130)
            ], closed: true)
            // 鉚體
            polyline(cg, [CGPoint(x: 172, y: 130), CGPoint(x: 172, y: 252)])
            polyline(cg, [CGPoint(x: 228, y: 130), CGPoint(x: 228, y: 252)])
            // 封閉端（半圓收口，這正是「封閉型」的特徵）
            cg.move(to: CGPoint(x: 172, y: 252))
            cg.addArc(center: CGPoint(x: 200, y: 252), radius: 28, startAngle: .pi, endAngle: 0, clockwise: true)
            cg.strokePath()
            // 抽芯桿與斷裂槽
            polyline(cg, [CGPoint(x: 200, y: 112), CGPoint(x: 200, y: 64)])
            cg.setLineWidth(1.4)
            polyline(cg, [CGPoint(x: 192, y: 96), CGPoint(x: 208, y: 96)])
            cg.setLineWidth(2.5)
            circle(cg, CGPoint(x: 200, y: 60), 7)
            // 被鉚接板材
            cg.setLineWidth(1.6)
            polyline(cg, [CGPoint(x: 92, y: 130), CGPoint(x: 308, y: 130)])
            polyline(cg, [CGPoint(x: 92, y: 158), CGPoint(x: 308, y: 158)])
            cg.setLineWidth(2.5)

        case "compression_spring":
            // 圓柱螺旋壓縮彈簧側視：閉合並磨平的兩端 + 中段等節距
            let springTop: CGFloat = 84
            let springBottom: CGFloat = 288
            let coils = 9
            let pitch = (springBottom - springTop) / CGFloat(coils)
            let outerR: CGFloat = 62
            for i in 0...coils {
                let y = springTop + CGFloat(i) * pitch
                // 以扁橢圓近似一圈線圈的側視投影
                ellipse(cg, CGRect(
                    x: 200 - outerR,
                    y: y - 9,
                    width: outerR * 2,
                    height: 18
                ))
            }
            // 兩端磨平座圈
            cg.setLineWidth(3.0)
            polyline(cg, [CGPoint(x: 138, y: springTop - 9), CGPoint(x: 262, y: springTop - 9)])
            polyline(cg, [CGPoint(x: 138, y: springBottom + 9), CGPoint(x: 262, y: springBottom + 9)])
            cg.setLineWidth(2.5)
            // 自由長度 L0 標註
            cg.setStrokeColor(accentColor.cgColor)
            cg.setLineWidth(1.2)
            polyline(cg, [CGPoint(x: 296, y: springTop - 9), CGPoint(x: 296, y: springBottom + 9)])
            polyline(cg, [CGPoint(x: 290, y: springTop - 9), CGPoint(x: 302, y: springTop - 9)])
            polyline(cg, [CGPoint(x: 290, y: springBottom + 9), CGPoint(x: 302, y: springBottom + 9)])
            cg.setStrokeColor(strokeColor.cgColor)
            cg.setLineWidth(2.5)

        case "bracket_l":
            // 90° 角鐵等角視：兩片直角板 + 加強筋 + 四孔
            polyline(cg, [
                CGPoint(x: 96, y: 176), CGPoint(x: 176, y: 132), CGPoint(x: 176, y: 268),
                CGPoint(x: 96, y: 312)
            ], closed: true)
            polyline(cg, [
                CGPoint(x: 176, y: 132), CGPoint(x: 306, y: 132), CGPoint(x: 306, y: 268),
                CGPoint(x: 176, y: 268)
            ], closed: true)
            // 加強筋
            polyline(cg, [CGPoint(x: 176, y: 200), CGPoint(x: 244, y: 132)])
            polyline(cg, [CGPoint(x: 176, y: 200), CGPoint(x: 176, y: 268)])
            // 四個 M5 沉頭孔
            for c in [CGPoint(x: 130, y: 208), CGPoint(x: 130, y: 264),
                      CGPoint(x: 250, y: 172), CGPoint(x: 250, y: 228)] {
                circle(cg, c, 10)
                cg.setLineWidth(1.2)
                circle(cg, c, 15)
                cg.setLineWidth(2.5)
            }

        // ---- 數位產品線框 ----

        case "wireframe_phone":
            // 19.5:9 手機線框 + 動態島 + 安全邊界
            stroke(cg, rounded: CGRect(x: 138, y: 46, width: 124, height: 270), radius: 22)
            stroke(cg, rounded: CGRect(x: 146, y: 54, width: 108, height: 254), radius: 16)
            // 動態島
            stroke(cg, rounded: CGRect(x: 178, y: 62, width: 44, height: 12), radius: 6)
            // 44pt 導航列安全界線
            cg.setLineWidth(1.2)
            cg.setStrokeColor(accentColor.cgColor)
            polyline(cg, [CGPoint(x: 146, y: 90), CGPoint(x: 254, y: 90)])
            polyline(cg, [CGPoint(x: 146, y: 282), CGPoint(x: 254, y: 282)])
            cg.setStrokeColor(strokeColor.cgColor)
            // 內容佔位
            for i in 0..<4 {
                stroke(cg, rounded: CGRect(x: 156, y: 102 + CGFloat(i) * 42, width: 88, height: 32), radius: 4)
            }
            cg.setLineWidth(2.5)
            // Home indicator
            stroke(cg, rounded: CGRect(x: 176, y: 296, width: 48, height: 5), radius: 2.5)

        case "wireframe_tablet":
            // 4:3 平板分屏多工佈局
            stroke(cg, rounded: CGRect(x: 58, y: 76, width: 284, height: 216), radius: 16)
            stroke(cg, rounded: CGRect(x: 68, y: 86, width: 264, height: 196), radius: 10)
            // 分屏分隔線
            polyline(cg, [CGPoint(x: 222, y: 86), CGPoint(x: 222, y: 252)])
            // 側邊欄
            cg.setLineWidth(1.4)
            for i in 0..<5 {
                stroke(cg, rounded: CGRect(x: 78, y: 96 + CGFloat(i) * 26, width: 60, height: 18), radius: 3)
            }
            // 右側工作區
            stroke(cg, rounded: CGRect(x: 232, y: 96, width: 90, height: 60), radius: 4)
            for i in 0..<3 {
                polyline(cg, [CGPoint(x: 232, y: 170 + CGFloat(i) * 16), CGPoint(x: 322, y: 170 + CGFloat(i) * 16)])
            }
            cg.setLineWidth(2.5)
            // 底部 Dock
            stroke(cg, rounded: CGRect(x: 128, y: 256, width: 144, height: 26), radius: 13)
            for i in 0..<5 {
                circle(cg, CGPoint(x: 148 + CGFloat(i) * 26, y: 269), 7)
            }

        case "wireframe_browser":
            // 瀏覽器視窗：三色控制鈕 + 網址膠囊 + 分頁列
            stroke(cg, rounded: CGRect(x: 46, y: 92, width: 308, height: 212), radius: 10)
            polyline(cg, [CGPoint(x: 46, y: 156), CGPoint(x: 354, y: 156)])
            // 紅黃綠控制鈕
            let lights: [UIColor] = isDark
                ? [.systemRed, .systemYellow, .systemGreen]
                : [.systemRed, .systemOrange, .systemGreen]
            for (i, c) in lights.enumerated() {
                cg.setFillColor(c.cgColor)
                cg.fillEllipse(in: CGRect(x: 60 + CGFloat(i) * 20, y: 102, width: 12, height: 12))
            }
            // 分頁
            cg.setLineWidth(1.4)
            stroke(cg, rounded: CGRect(x: 130, y: 98, width: 84, height: 22), radius: 5)
            stroke(cg, rounded: CGRect(x: 218, y: 98, width: 84, height: 22), radius: 5)
            // 網址膠囊
            stroke(cg, rounded: CGRect(x: 62, y: 128, width: 276, height: 20), radius: 10)
            // 內容骨架
            stroke(cg, rounded: CGRect(x: 62, y: 170, width: 130, height: 82), radius: 5)
            for i in 0..<5 {
                polyline(cg, [CGPoint(x: 204, y: 180 + CGFloat(i) * 17), CGPoint(x: 338, y: 180 + CGFloat(i) * 17)])
            }
            for i in 0..<3 {
                polyline(cg, [CGPoint(x: 62, y: 268 + CGFloat(i) * 14), CGPoint(x: 338, y: 268 + CGFloat(i) * 14)])
            }
            cg.setLineWidth(2.5)

        case "wireframe_gestures":
            // 8 種核心手勢符號（2 列 x 4 欄）
            let cols: [CGFloat] = [86, 162, 238, 314]
            let rows: [CGFloat] = [136, 244]
            cg.setLineWidth(2.0)
            for (idx, center) in rows.flatMap({ r in cols.map { CGPoint(x: $0, y: r) } }).enumerated() {
                // 指尖
                circle(cg, center, 13)
                switch idx {
                case 0: // 單擊：單圈擴散
                    circle(cg, center, 24)
                case 1: // 雙擊：雙圈
                    circle(cg, center, 22)
                    circle(cg, center, 30)
                case 2: // 長按：虛線圈
                    cg.saveGState()
                    cg.setLineDash(phase: 0, lengths: [4, 4])
                    circle(cg, center, 26)
                    cg.restoreGState()
                case 3: // 滑動：右向箭頭
                    polyline(cg, [CGPoint(x: center.x + 16, y: center.y), CGPoint(x: center.x + 44, y: center.y)])
                    polyline(cg, [
                        CGPoint(x: center.x + 36, y: center.y - 7),
                        CGPoint(x: center.x + 46, y: center.y),
                        CGPoint(x: center.x + 36, y: center.y + 7)
                    ])
                case 4: // 旋轉：弧線帶箭頭
                    cg.addArc(center: center, radius: 26, startAngle: -.pi * 0.8, endAngle: .pi * 0.5, clockwise: false)
                    cg.strokePath()
                    polyline(cg, [
                        CGPoint(x: center.x - 4, y: center.y + 20),
                        CGPoint(x: center.x, y: center.y + 30),
                        CGPoint(x: center.x + 8, y: center.y + 24)
                    ])
                case 5: // 縮放（外張）：對角雙箭頭
                    polyline(cg, [CGPoint(x: center.x - 30, y: center.y - 30), CGPoint(x: center.x - 14, y: center.y - 14)])
                    polyline(cg, [CGPoint(x: center.x + 30, y: center.y + 30), CGPoint(x: center.x + 14, y: center.y + 14)])
                    polyline(cg, [CGPoint(x: center.x - 30, y: center.y - 30), CGPoint(x: center.x - 30, y: center.y - 18)])
                    polyline(cg, [CGPoint(x: center.x - 30, y: center.y - 30), CGPoint(x: center.x - 18, y: center.y - 30)])
                case 6: // 拖曳：虛線軌跡
                    cg.saveGState()
                    cg.setLineDash(phase: 0, lengths: [5, 4])
                    polyline(cg, [CGPoint(x: center.x - 26, y: center.y + 26), CGPoint(x: center.x + 26, y: center.y - 22)])
                    cg.restoreGState()
                default: // 雙指
                    circle(cg, CGPoint(x: center.x + 22, y: center.y + 8), 13)
                }
            }
            cg.setLineWidth(2.5)

        default:
            // 預設立體透視立方幾何
            cg.move(to: CGPoint(x: 200, y: 90))
            cg.addLine(to: CGPoint(x: 300, y: 145))
            cg.addLine(to: CGPoint(x: 300, y: 255))
            cg.addLine(to: CGPoint(x: 200, y: 310))
            cg.addLine(to: CGPoint(x: 100, y: 255))
            cg.addLine(to: CGPoint(x: 100, y: 145))
            cg.closePath()
            cg.strokePath()

            cg.move(to: CGPoint(x: 200, y: 90))
            cg.addLine(to: CGPoint(x: 200, y: 200))
            cg.addLine(to: CGPoint(x: 300, y: 145))
            cg.move(to: CGPoint(x: 200, y: 200))
            cg.addLine(to: CGPoint(x: 100, y: 145))
            cg.strokePath()
        }

        // 尺寸引線裝飾 (Dimension Callout Arrows)
        //
        // 只在線框（藍圖）模式畫。實物模式是要貼進筆記當成一個物件用的，
        // 帶著工程標註反而變成雜訊。
        guard currentStyle == .blueprint else { return }
        cg.setStrokeColor(accentColor.cgColor)
        cg.setLineWidth(1.2)
        cg.move(to: CGPoint(x: 50, y: 320))
        cg.addLine(to: CGPoint(x: 350, y: 320))
        cg.move(to: CGPoint(x: 50, y: 315))
        cg.addLine(to: CGPoint(x: 50, y: 325))
        cg.move(to: CGPoint(x: 350, y: 315))
        cg.addLine(to: CGPoint(x: 350, y: 325))
        cg.strokePath()
    }
}
