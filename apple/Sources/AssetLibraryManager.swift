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
    }

    /// 總計本機已下載容量 (MB)
    public var totalDownloadedSizeMB: Double {
        items.filter { downloadedItemIds.contains($0.id) }
            .reduce(0.0) { $0 + $1.fileSizeMB }
    }

    /// 檢查是否已下載
    public func isDownloaded(_ id: String) -> Bool {
        downloadedItemIds.contains(id)
    }

    /// 隨需下載指定素材
    public func downloadItem(id: String) {
        guard !downloadedItemIds.contains(id), !downloadingItemIds.contains(id) else { return }
        downloadingItemIds.insert(id)

        // 模擬即時網路下載
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.downloadingItemIds.remove(id)
            self.downloadedItemIds.insert(id)
            self.saveDownloadedState()
            self.updateItemStates()
        }
    }

    /// 一鍵下載指定主題包
    public func downloadCategory(_ category: AssetCategory) {
        let targets = items.filter { (category == .all || $0.category == category) && !downloadedItemIds.contains($0.id) }
        for it in targets {
            downloadingItemIds.insert(it.id)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            for it in targets {
                self.downloadingItemIds.remove(it.id)
                self.downloadedItemIds.insert(it.id)
            }
            self.saveDownloadedState()
            self.updateItemStates()
        }
    }

    /// 移除指定素材之本機快取
    public func removeItem(id: String) {
        downloadedItemIds.remove(id)
        saveDownloadedState()
        updateItemStates()
    }

    /// 一鍵清除所有素材快取（釋放本機硬碟空間）
    public func clearAllCache() {
        downloadedItemIds.removeAll()
        saveDownloadedState()
        updateItemStates()
    }

    private func updateItemStates() {
        for i in 0..<items.count {
            items[i].isDownloaded = downloadedItemIds.contains(items[i].id)
        }
    }

    private func loadDownloadedState() {
        if let saved = UserDefaults.standard.array(forKey: downloadedDefaultsKey) as? [String] {
            self.downloadedItemIds = Set(saved)
        } else {
            // 預設內建 4 項精選實體物件（方便使用者離線立即可用）
            self.downloadedItemIds = ["mech_01", "elec_01", "hard_01", "digi_01"]
        }
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
    public func renderItemImage(for item: AssetItem) -> UIImage {
        let size = CGSize(width: 400, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            let cg = ctx.cgContext
            let rect = CGRect(origin: .zero, size: size)

            // 背景卡片底色
            let isDark = (item.sourceType == .aiConcept)
            if isDark {
                let darkColor = UIColor(red: 0.1, green: 0.12, blue: 0.18, alpha: 1.0)
                cg.setFillColor(darkColor.cgColor)
                cg.fill(rect)

                // 科技網格背景
                cg.setStrokeColor(UIColor.cyan.withAlphaComponent(0.12).cgColor)
                cg.setLineWidth(1.0)
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
            } else {
                let lightColor = UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1.0)
                cg.setFillColor(lightColor.cgColor)
                cg.fill(rect)

                // 工程坐標網格
                cg.setStrokeColor(UIColor.systemBlue.withAlphaComponent(0.1).cgColor)
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

            // 繪製各物件專屬精確線條
            drawObjectGraphics(code: item.drawingCode, cg: cg, isDark: isDark)

            // 底部標註規格小標題欄
            let titleBox = CGRect(x: 16, y: 350, width: 368, height: 36)
            cg.setFillColor((isDark ? UIColor.black.withAlphaComponent(0.6) : UIColor.white.withAlphaComponent(0.85)).cgColor)
            let path = UIBezierPath(roundedRect: titleBox, cornerRadius: 6)
            cg.addPath(path.cgPath)
            cg.fillPath()

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .bold),
                .foregroundColor: isDark ? UIColor.cyan : UIColor(red: 0.05, green: 0.35, blue: 0.75, alpha: 1.0)
            ]
            let subtitle = "\(item.title)  [\(item.dimensionsMm)]"
            (subtitle as NSString).draw(at: CGPoint(x: 26, y: 360), withAttributes: attrs)
        }
    }

    private func drawObjectGraphics(code: String, cg: CGContext, isDark: Bool) {
        let strokeColor = isDark ? UIColor.cyan : UIColor(red: 0.1, green: 0.3, blue: 0.65, alpha: 1.0)
        let accentColor = isDark ? UIColor.systemPink : UIColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1.0)

        cg.setStrokeColor(strokeColor.cgColor)
        cg.setLineWidth(2.5)

        switch code {
        case "gear_pair":
            // 繪製嚙合雙齒輪組
            cg.strokeEllipse(in: CGRect(x: 70, y: 120, width: 120, height: 120))
            cg.strokeEllipse(in: CGRect(x: 110, y: 160, width: 40, height: 40))
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
            cg.strokeEllipse(in: CGRect(x: 180, y: 110, width: 160, height: 160))
            cg.strokeEllipse(in: CGRect(x: 230, y: 160, width: 60, height: 60))
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
            cg.strokeEllipse(in: CGRect(x: 100, y: 75, width: 200, height: 200))
            cg.strokeEllipse(in: CGRect(x: 140, y: 115, width: 120, height: 120))
            for i in 0..<8 {
                let angle = CGFloat(i) * (.pi / 4)
                let rx = 200 + cos(angle) * 80 - 15
                let ry = 175 + sin(angle) * 80 - 15
                cg.strokeEllipse(in: CGRect(x: rx, y: ry, width: 30, height: 30))
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
            cg.strokeEllipse(in: CGRect(x: 105, y: 195, width: 50, height: 50))
            cg.strokeEllipse(in: CGRect(x: 245, y: 195, width: 50, height: 50))

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
            cg.strokeEllipse(in: CGRect(x: 180, y: 95, width: 40, height: 30))

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
                cg.strokeEllipse(in: CGRect(x: pt.x - 7, y: pt.y - 7, width: 14, height: 14))
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
            cg.strokeEllipse(in: CGRect(x: 180, y: 160, width: 50, height: 50))
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
            cg.strokeEllipse(in: CGRect(x: 195, y: 85, width: 10, height: 16))
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
            cg.strokeEllipse(in: CGRect(x: 80, y: 90, width: 110, height: 110)) // 圓
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
                cg.strokeEllipse(in: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8))
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
                cg.strokeEllipse(in: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12))
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
            cg.strokeEllipse(in: CGRect(x: 177, y: 212, width: 16, height: 16))
            cg.strokeEllipse(in: CGRect(x: 207, y: 212, width: 16, height: 16))

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
            cg.strokeEllipse(in: CGRect(x: 120 - r/2, y: 90 - r/2, width: r, height: r))
            cg.strokeEllipse(in: CGRect(x: 280 - r/2, y: 90 - r/2, width: r, height: r))
            cg.strokeEllipse(in: CGRect(x: 120 - r/2, y: 250 - r/2, width: r, height: r))
            cg.strokeEllipse(in: CGRect(x: 280 - r/2, y: 250 - r/2, width: r, height: r))

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
            cg.strokeEllipse(in: CGRect(x: 130, y: 105, width: 14, height: 14)) // 氣孔 A
            cg.strokeEllipse(in: CGRect(x: 250, y: 105, width: 14, height: 14)) // 氣孔 B
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
            cg.strokeEllipse(in: CGRect(x: 85, y: 105, width: 12, height: 12))
            cg.strokeEllipse(in: CGRect(x: 225, y: 135, width: 12, height: 12))

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
            cg.strokeEllipse(in: CGRect(x: 156, y: 256, width: 8, height: 8))
            cg.move(to: CGPoint(x: 320, y: 80)); cg.addLine(to: CGPoint(x: 240, y: 80))
            cg.strokeEllipse(in: CGRect(x: 236, y: 76, width: 8, height: 8))
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
