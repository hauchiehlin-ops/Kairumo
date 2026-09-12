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

/// 圖庫核心主題分類
public enum AssetCategory: String, CaseIterable, Identifiable, Codable {
    case all = "全部"
    case mechanism = "機構設計"
    case electronics3C = "3C 電子"
    case automotive = "汽車載具"
    case furniture = "工業家具"
    case hardware = "五金零件"
    case digital = "數位產品"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .mechanism: return "gearshape.2.fill"
        case .electronics3C: return "laptopcomputer.and.iphone"
        case .automotive: return "car.fill"
        case .furniture: return "chair.lounge.fill"
        case .hardware: return "wrench.and.screwdriver.fill"
        case .digital: return "macwindow"
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
