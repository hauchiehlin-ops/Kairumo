//! 素材圖庫的目錄。
//!
//! # 為什麼在核心
//!
//! 這 58 件技術素材原本只存在於 `apple/Sources/AssetLibraryManager.swift`，
//! Android 完全沒有這個功能。清單本身是**資料**，不是介面 —— 放在核心才能
//! 保證兩個平台看到同一批素材、同樣的分類與同樣的規格。
//!
//! # 名稱為什麼還是中文
//!
//! `title` / `specs` / `material` 目前是繁體中文字面值，與 Apple 端現況相同。
//! 這些是**技術術語**（「奧氏體防蝕」「滲碳淬火 HRC 58-62」），六國語系的
//! 正確譯法不是逐字翻譯得出來的，隨手翻只會產生看起來像中文的外文。
//! 那件事在 `docs/TODO.md` 記為 S-54b，需要人來處理。
//!
//! 先下沉、後在地化的順序是刻意的：現在兩個平台顯示的內容**完全一致**，
//! 之後把這裡的字串換成語系鍵，兩邊會同時翻好；留在各自平台的話，
//! 翻譯那天要做兩次，而且一定會有一邊漏掉。

/// 素材分類。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiAssetCategory {
    Mechanism,
    Electronics3C,
    Automotive,
    Furniture,
    Hardware,
    Digital,
    AestheticComposition,
    Typography,
    DesignMotifs,
    ToolingMolding,
    SheetMetalCNC,
    SurfaceFinishing,
    PneumaticsPiping,
    CrossPlatformUI,
    UxMotion,
    InfoArchitecture,
    DesignTokens,
}

/// 全部分類，順序即面板上的顯示順序。
#[uniffi::export]
pub fn asset_categories() -> Vec<FfiAssetCategory> {
    vec![
        FfiAssetCategory::Mechanism,
        FfiAssetCategory::Electronics3C,
        FfiAssetCategory::Automotive,
        FfiAssetCategory::Furniture,
        FfiAssetCategory::Hardware,
        FfiAssetCategory::Digital,
        FfiAssetCategory::AestheticComposition,
        FfiAssetCategory::Typography,
        FfiAssetCategory::DesignMotifs,
        FfiAssetCategory::ToolingMolding,
        FfiAssetCategory::SheetMetalCNC,
        FfiAssetCategory::SurfaceFinishing,
        FfiAssetCategory::PneumaticsPiping,
        FfiAssetCategory::CrossPlatformUI,
        FfiAssetCategory::UxMotion,
        FfiAssetCategory::InfoArchitecture,
        FfiAssetCategory::DesignTokens,
    ]
}

/// 分類名稱的語系鍵。
#[uniffi::export]
pub fn asset_category_key(category: FfiAssetCategory) -> String {
    match category {
        FfiAssetCategory::Mechanism => "asset_cat_mechanism",
        FfiAssetCategory::Electronics3C => "asset_cat_electronics3c",
        FfiAssetCategory::Automotive => "asset_cat_automotive",
        FfiAssetCategory::Furniture => "asset_cat_furniture",
        FfiAssetCategory::Hardware => "asset_cat_hardware",
        FfiAssetCategory::Digital => "asset_cat_digital",
        FfiAssetCategory::AestheticComposition => "asset_cat_aestheticcomposition",
        FfiAssetCategory::Typography => "asset_cat_typography",
        FfiAssetCategory::DesignMotifs => "asset_cat_designmotifs",
        FfiAssetCategory::ToolingMolding => "asset_cat_toolingmolding",
        FfiAssetCategory::SheetMetalCNC => "asset_cat_sheetmetalcnc",
        FfiAssetCategory::SurfaceFinishing => "asset_cat_surfacefinishing",
        FfiAssetCategory::PneumaticsPiping => "asset_cat_pneumaticspiping",
        FfiAssetCategory::CrossPlatformUI => "asset_cat_crossplatformui",
        FfiAssetCategory::UxMotion => "asset_cat_uxmotion",
        FfiAssetCategory::InfoArchitecture => "asset_cat_infoarchitecture",
        FfiAssetCategory::DesignTokens => "asset_cat_designtokens",
    }
    .to_string()
}

/// 這個分類屬於哪一個主題（美學／工程／數位）。面板上的主題篩選用得到。
#[uniffi::export]
pub fn asset_category_theme(category: FfiAssetCategory) -> FfiThemeTab {
    match category {
        FfiAssetCategory::Mechanism => FfiThemeTab::Engineering,
        FfiAssetCategory::Electronics3C => FfiThemeTab::Engineering,
        FfiAssetCategory::Automotive => FfiThemeTab::Engineering,
        FfiAssetCategory::Furniture => FfiThemeTab::Aesthetic,
        FfiAssetCategory::Hardware => FfiThemeTab::Engineering,
        FfiAssetCategory::Digital => FfiThemeTab::Digital,
        FfiAssetCategory::AestheticComposition => FfiThemeTab::Aesthetic,
        FfiAssetCategory::Typography => FfiThemeTab::Aesthetic,
        FfiAssetCategory::DesignMotifs => FfiThemeTab::Aesthetic,
        FfiAssetCategory::ToolingMolding => FfiThemeTab::Engineering,
        FfiAssetCategory::SheetMetalCNC => FfiThemeTab::Engineering,
        FfiAssetCategory::SurfaceFinishing => FfiThemeTab::Engineering,
        FfiAssetCategory::PneumaticsPiping => FfiThemeTab::Engineering,
        FfiAssetCategory::CrossPlatformUI => FfiThemeTab::Digital,
        FfiAssetCategory::UxMotion => FfiThemeTab::Digital,
        FfiAssetCategory::InfoArchitecture => FfiThemeTab::Digital,
        FfiAssetCategory::DesignTokens => FfiThemeTab::Digital,
    }
}

/// 素材的來源性質。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiAssetSource {
    /// 依實際規格繪製的工程圖。
    PhysicalSpec,
    /// AI 概念提案，不是既有產品的圖紙。
    AiConcept,
}

/// 一件素材。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiAssetItem {
    pub id: String,
    /// 名稱。見本模組開頭「名稱為什麼還是中文」。
    pub title: String,
    pub category: FfiAssetCategory,
    pub source: FfiAssetSource,
    /// 規格摘要。
    pub specs: String,
    /// 建議材料與處理。
    pub material: String,
    /// 尺寸標註。
    pub dimensions: String,
    /// 圖檔大小（MB）。面板上顯示用，不是真實檔案大小 —— 素材是即時畫出來的。
    pub file_size_mb: f32,
    /// 線圖代號。傳給 [`crate::ffi_asset_art::asset_drawing`] 取得圖形。
    pub drawing_code: String,
}

/// 全部素材。
#[uniffi::export]
pub fn asset_items() -> Vec<FfiAssetItem> {
    RAW.iter()
        .map(|r| FfiAssetItem {
            id: r.0.to_string(),
            title: r.1.to_string(),
            category: r.2,
            source: r.3,
            specs: r.4.to_string(),
            material: r.5.to_string(),
            dimensions: r.6.to_string(),
            file_size_mb: r.7,
            drawing_code: r.8.to_string(),
        })
        .collect()
}

/// 某一個分類的素材。
#[uniffi::export]
pub fn asset_items_in(category: FfiAssetCategory) -> Vec<FfiAssetItem> {
    asset_items().into_iter().filter(|i| i.category == category).collect()
}

/// 關鍵字搜尋：比對名稱、規格與材料，不分大小寫。
///
/// 空字串回全部 —— 搜尋框清空時應該看到整個圖庫，不是一片空白。
#[uniffi::export]
pub fn asset_search(query: String) -> Vec<FfiAssetItem> {
    let q = query.trim().to_lowercase();
    if q.is_empty() {
        return asset_items();
    }
    asset_items()
        .into_iter()
        .filter(|i| {
            i.title.to_lowercase().contains(&q)
                || i.specs.to_lowercase().contains(&q)
                || i.material.to_lowercase().contains(&q)
        })
        .collect()
}

use crate::ffi_theme_tools::FfiThemeTab;

type Row = (
    &'static str,
    &'static str,
    FfiAssetCategory,
    FfiAssetSource,
    &'static str,
    &'static str,
    &'static str,
    f32,
    &'static str,
);

/// 目錄本體。逐筆對應 Apple 端 `seedLibraryItems()` 原本的內容。
static RAW: &[Row] = &[
    (
        "mech_01",
        "漸開線正齒輪組 (Spur Gears)",
        FfiAssetCategory::Mechanism,
        FfiAssetSource::PhysicalSpec,
        "模數 M2.0、24T/48T 減速比 1:2、壓力角 20°、JIS 2 級精度",
        "SCM440 鉻鉬合金鋼 / 滲碳淬火 HRC 58-62",
        "Ø52 x 15 mm / Ø100 x 15 mm",
        1.8,
        "gear_pair",
    ),
    (
        "mech_02",
        "平面圓柱滾子軸承 (Cylindrical Roller Bearing)",
        FfiAssetCategory::Mechanism,
        FfiAssetSource::PhysicalSpec,
        "ISO 15 標準、基本動額定負荷 42.5kN、徑向高剛性承載",
        "高碳鉻軸承鋼 GCr15 / 保持架黃銅 H62",
        "Ø30 (內) x Ø62 (外) x 16 (寬) mm",
        2.1,
        "bearing_iso",
    ),
    (
        "mech_03",
        "精密微型滾珠螺桿滑軌 (Linear Guide & Carriage)",
        FfiAssetCategory::Mechanism,
        FfiAssetSource::PhysicalSpec,
        "四方向等負荷規格、導程 5mm、走行動態平行度 < 0.003mm",
        "SUJ2 軸承鋼導軌 + 不鏽鋼封蓋",
        "軌寬 15mm x 長 250mm x 高 28mm",
        3.2,
        "linear_guide",
    ),
    (
        "mech_04",
        "等徑盤形凸輪連桿機構 (Disk Cam & Follower)",
        FfiAssetCategory::Mechanism,
        FfiAssetSource::PhysicalSpec,
        "簡諧運動輪廓線、行程 20mm、最大推力角 28°",
        "S45C 中碳鋼 / 高週波熱處理 HRC 50",
        "基圓 Ø60 mm / 最大升程 20 mm",
        2.4,
        "cam_follower",
    ),
    (
        "mech_05",
        "NEMA 17 混合式步進馬達 (Stepper Motor)",
        FfiAssetCategory::Mechanism,
        FfiAssetSource::PhysicalSpec,
        "步距角 1.8°、保持扭矩 45N·cm、雙極 4 線驅動",
        "矽鋼片定子 + 鋁合金端蓋 + 釹鐵硼轉子",
        "42 x 42 x 40 mm / 軸徑 Ø5 mm",
        2.7,
        "stepper_motor",
    ),
    (
        "mech_06",
        "動態外骨骼關節連桿 (Exoskeleton Biomechanical Joint)",
        FfiAssetCategory::Mechanism,
        FfiAssetSource::AiConcept,
        "仿生雙心瞬時迴轉軸心、減輕人體膝關節垂直負荷 35%",
        "Ti-6Al-4V 鈦合金 3D 列印拓撲優化結構",
        "140 x 85 x 35 mm",
        4.5,
        "ai_exoskeleton",
    ),
    (
        "elec_01",
        "旗艦手機鋁合金中框結構 (Smartphone Uni-Frame)",
        FfiAssetCategory::Electronics3C,
        FfiAssetSource::PhysicalSpec,
        "CNC 五軸精雕加工、注塑天線斷差 < 0.02mm、四角耐衝擊微倒角",
        "AL7075 航空鋁合金 / 表面微米級陽極噴砂",
        "160.8 x 78.1 x 7.8 mm",
        2.9,
        "phone_chassis",
    ),
    (
        "elec_02",
        "真無線降噪耳機聲學腔體 (TWS Acoustic Earbud)",
        FfiAssetCategory::Electronics3C,
        FfiAssetSource::PhysicalSpec,
        "人體耳甲腔 3D 拓撲曲面、雙洩壓閥微孔陣列、10mm 鍍鈹動圈架構",
        "醫學級 PC-ABS 複合材料 / 親膚奈米塗層",
        "24.5 x 21.2 x 18.0 mm",
        2.2,
        "earbud_acoustic",
    ),
    (
        "elec_03",
        "大光圈相機鏡頭光學鏡組 (Camera Optical Lens Assembly)",
        FfiAssetCategory::Electronics3C,
        FfiAssetSource::PhysicalSpec,
        "9 群 12 枚光學鏡片、內建線性磁浮對焦馬達、金屬卡口防塵密封圈",
        "ED 低色散玻璃 + 鎂鋁合金鏡筒",
        "Ø78 x 長 95 mm / 濾鏡口徑 Ø67mm",
        3.8,
        "camera_lens",
    ),
    (
        "elec_04",
        "75% 客製化機械鍵盤 Gasket 結構 (Mechanical Keyboard)",
        FfiAssetCategory::Electronics3C,
        FfiAssetSource::PhysicalSpec,
        "矽膠襯墊減震限位、FR4 沉金定位板、消音底棉與電池夾層",
        "上下蓋 6063 鋁合金 CNC / 表面電泳工藝",
        "320 x 140 x 38 mm",
        3.4,
        "keyboard_gasket",
    ),
    (
        "elec_05",
        "曲面未來感智慧座艙 HUD (Curved Cyber Cockpit HUD)",
        FfiAssetCategory::Electronics3C,
        FfiAssetSource::AiConcept,
        "Micro-OLED 光學投射模組、全息光波導視網膜顯示、眼球追蹤感測",
        "半透明光學聚碳酸酯 + 陶瓷散熱背板",
        "220 x 120 x 45 mm",
        4.8,
        "ai_hud_display",
    ),
    (
        "auto_01",
        "跑車空氣動力學流線側影 (Sports Car Aerodynamic Profile)",
        FfiAssetCategory::Automotive,
        FfiAssetSource::PhysicalSpec,
        "風阻係數 Cd 0.24、後輪拱主動導流氣道、下壓力擴散底盤佈局",
        "碳纖維乾碳成型 (Dry Carbon Pre-preg)",
        "4680 x 1980 x 1240 mm / 軸距 2720mm",
        3.6,
        "car_silhouette",
    ),
    (
        "auto_02",
        "五輻雙柱鍛造運動輪框 (Forged Monoblock Wheel Rim)",
        FfiAssetCategory::Automotive,
        FfiAssetSource::PhysicalSpec,
        "一體萬噸鍛造成型、輕量化挖肉結構、通過 JWL/VIA 強化衝擊驗證",
        "6061-T6 鍛造鋁合金 / 亮黑拉絲透明漆",
        "20 吋 x 9.5J / PCD 5x114.3 / ET+35",
        2.8,
        "wheel_rim",
    ),
    (
        "auto_03",
        "雙 A 臂獨立懸吊機構 (Double Wishbone Suspension)",
        FfiAssetCategory::Automotive,
        FfiAssetSource::PhysicalSpec,
        "幾何防傾傾角補償、高壓氮氣倒插式避震器、球接頭防塵套",
        "鍛造鋁合金控制臂 + 鉻鉬鋼避震彈簧",
        "輪距支撐跨距 580 mm / 行程 120 mm",
        3.5,
        "suspension_geometry",
    ),
    (
        "auto_04",
        "三輻運動賽車方向盤 (Sport Steering Wheel)",
        FfiAssetCategory::Automotive,
        FfiAssetSource::PhysicalSpec,
        "D型平底人體工學拇指托、背部磁吸式碳纖維換檔撥片、多功能滾輪",
        "義大利 Alcantara 翻毛皮包覆 + 骨架鎂合金",
        "外徑 Ø360 mm / 握把截面 34 x 28 mm",
        2.6,
        "steering_wheel",
    ),
    (
        "auto_05",
        "純電滑板底盤電池模組架構 (EV Skateboard Chassis)",
        FfiAssetCategory::Automotive,
        FfiAssetSource::PhysicalSpec,
        "CTP 無模組化高能量密度電池包、前後雙永磁同步電機、一體化壓鑄件",
        "熱成型超高強度鋼 1500MPa + 鋁合金壓鑄",
        "長 3400 x 寬 1600 x 厚 140 mm",
        4.2,
        "ev_chassis",
    ),
    (
        "auto_06",
        "未來星際懸浮穿梭載具 (Futuristic Orbital Shuttle)",
        FfiAssetCategory::Automotive,
        FfiAssetSource::AiConcept,
        "向量離子推進噴口、多面體隱形耐熱外殼、環形重力偏轉艙",
        "耐熱石墨烯複合塗層 + 氣凝膠超低溫絕熱層",
        "6800 x 3800 x 2200 mm",
        5.2,
        "ai_orbital_shuttle",
    ),
    (
        "furn_01",
        "經典伊姆斯休閒躺椅 (Eames Lounge Chair Geometry)",
        FfiAssetCategory::Furniture,
        FfiAssetSource::PhysicalSpec,
        "五層熱壓成型曲木膠合板、15° 仰角人體脊椎舒壓弧度、五星金屬旋轉腳",
        "北美胡桃木貼皮曲木 + 頂級苯染半包覆牛皮",
        "840 x 850 x 840 mm / 座高 400 mm",
        3.1,
        "eames_chair",
    ),
    (
        "furn_02",
        "人體工學升降辦公桌幾何 (Height-Adjustable Standing Desk)",
        FfiAssetCategory::Furniture,
        FfiAssetSource::PhysicalSpec,
        "雙馬達靜音三節升降柱、遇阻回退感應、升降範圍 620-1270mm",
        "冷軋碳素鋼桌腿 + 環保防刮美耐皿實木芯桌面",
        "1400 x 700 x (620-1270) mm",
        2.7,
        "standing_desk",
    ),
    (
        "furn_03",
        "包浩斯懸臂可調護眼檯燈 (Bauhaus Cantilever Task Lamp)",
        FfiAssetCategory::Furniture,
        FfiAssetSource::PhysicalSpec,
        "四連桿平行阻尼關節平衡機構、無可視頻閃環形光源、隱藏式走線",
        "陽極氧化消光鋁管 + 重心下沉式壓鑄鋅底座",
        "懸臂展長 780 mm / 底座 Ø200 mm",
        2.3,
        "task_lamp",
    ),
    (
        "furn_04",
        "北歐極簡模組收納櫃 (Modular Credenza)",
        FfiAssetCategory::Furniture,
        FfiAssetSource::PhysicalSpec,
        "45° 倒角隱藏拉手、緩衝滑軌抽屜、模組化自由堆疊插榫",
        "天然白橡木實木框架 + 環保水性漆塗裝",
        "1600 x 420 x 750 mm",
        2.5,
        "modular_credenza",
    ),
    (
        "hard_01",
        "ISO 4762 內六角圓柱頭螺栓 (Hex Socket Head Cap Screw)",
        FfiAssetCategory::Hardware,
        FfiAssetSource::PhysicalSpec,
        "M6x25、螺距 1.0mm、強度等級 12.9 級、六角穴對邊 S=5mm",
        "SCM435 合金鋼 / 表面發黑防銹處理",
        "頭徑 Ø10 x 頭高 6 x 牙長 25 mm",
        1.4,
        "hex_bolt",
    ),
    (
        "hard_02",
        "DIN 7991 沉頭內六角螺釘 (Countersunk Flat Head Screw)",
        FfiAssetCategory::Hardware,
        FfiAssetSource::PhysicalSpec,
        "M5x16、90° 沉頭錐角、裝配後與板金表面完全齊平",
        "SUS304 不鏽鋼 / 鈍化防腐蝕處理",
        "頭徑 Ø10 (90°) x 全長 16 mm",
        1.3,
        "countersunk_screw",
    ),
    (
        "hard_03",
        "六角法蘭面防鬆螺母 (Hex Flange Lock Nut)",
        FfiAssetCategory::Hardware,
        FfiAssetSource::PhysicalSpec,
        "M8、底面鋸齒狀防滑脫條紋、8 級預載防鬆抗振",
        "碳素結構鋼 / 環保鍍鋅 (RoHS 認證)",
        "法蘭外徑 Ø18 x 六角厚度 8 mm",
        1.2,
        "flange_nut",
    ),
    (
        "hard_04",
        "封閉型抽芯盲鉚釘 (Closed-End Blind Rivet)",
        FfiAssetCategory::Hardware,
        FfiAssetSource::PhysicalSpec,
        "Ø4.0 x 12mm、高氣密防水防漏、剪切強度 2200N、拉伸強度 2800N",
        "5052 鋁合金釘體 + 碳鋼釘芯",
        "釘套 Ø4.0 x 長 12 mm / 鉚接厚度 4-7mm",
        1.1,
        "blind_rivet",
    ),
    (
        "hard_05",
        "圓柱螺旋壓縮彈簧 (Helical Compression Spring)",
        FfiAssetCategory::Hardware,
        FfiAssetSource::PhysicalSpec,
        "線徑 d=2.0mm、外徑 D=16mm、自由長度 L0=50mm、彈簧剛度 k=4.2N/mm",
        "SWP-B 琴鋼線 / 表面化學鍍鎳",
        "外徑 Ø16 x 節距 6.5 x 自由長 50 mm",
        1.5,
        "compression_spring",
    ),
    (
        "hard_06",
        "90° 強化沖壓直角固定角鐵 (Heavy-Duty L-Bracket)",
        FfiAssetCategory::Hardware,
        FfiAssetSource::PhysicalSpec,
        "厚度 3.0mm、加強筋抗彎折衝壓、四孔 M5 沉頭安裝位",
        "Q235 冷軋板沖壓 / 烤漆防鏽處理",
        "50 x 50 x 40 x 厚 3.0 mm",
        1.6,
        "bracket_l",
    ),
    (
        "digi_01",
        "旗艦智慧型手機 UI 向量線框 (Phone Wireframe Outline)",
        FfiAssetCategory::Digital,
        FfiAssetSource::PhysicalSpec,
        "標準 19.5:9 螢幕長寬比、動態島開孔引導、44pt 導航列安全邊界",
        "向量 Wireframe 線稿規格",
        "393 x 852 pt (向量縮放)",
        1.2,
        "wireframe_phone",
    ),
    (
        "digi_02",
        "平板手繪多視窗佈局 (Tablet Multi-Window Grid)",
        FfiAssetCategory::Digital,
        FfiAssetSource::PhysicalSpec,
        "4:3 比例工作區、分屏多工側邊欄、底部 Dock 快捷欄指示線",
        "向量 Wireframe 線稿規格",
        "1024 x 768 pt (向量縮放)",
        1.4,
        "wireframe_tablet",
    ),
    (
        "digi_03",
        "極簡瀏覽器視窗框架 (Browser Window Frame)",
        FfiAssetCategory::Digital,
        FfiAssetSource::PhysicalSpec,
        "頂部紅黃綠三色控制按鈕、網址列膠囊外框、標籤頁分頁列",
        "向量 Wireframe 線稿規格",
        "1280 x 800 pt (向量縮放)",
        1.3,
        "wireframe_browser",
    ),
    (
        "digi_04",
        "行動端 8 種核心手勢符號包 (UX Gesture Annotations)",
        FfiAssetCategory::Digital,
        FfiAssetSource::PhysicalSpec,
        "包含單擊 (Tap)、雙擊、長按、滑動 (Swipe)、旋轉、縮放等手勢路徑",
        "向量 Wireframe 線稿規格",
        "一套 8 個符號，支援獨立拆分插入",
        1.5,
        "wireframe_gestures",
    ),
    (
        "aes_comp_01",
        "黃金螺旋對數構圖尺標 (Golden Spiral Logarithmic Guide)",
        FfiAssetCategory::AestheticComposition,
        FfiAssetSource::PhysicalSpec,
        "黃金比例 phi=1.618033、費氏數列方格、向心對稱引導線",
        "精密光學刻度尺 / 向量比例規格",
        "1:1.618 (動態向量縮放)",
        1.2,
        "golden_spiral",
    ),
    (
        "aes_comp_02",
        "經典攝影三分法則九宮格 (Rule of Thirds Grid)",
        FfiAssetCategory::AestheticComposition,
        FfiAssetSource::PhysicalSpec,
        "4 個視覺焦點交叉點、上中下水平分割、左中右垂直平衡",
        "16:9 比例畫幅視覺輔助規",
        "16:9 / 3:2 向量縮放",
        1.1,
        "rule_of_thirds",
    ),
    (
        "aes_comp_03",
        "動態對稱菱形構圖引導 (Dynamic Symmetry Armatures)",
        FfiAssetCategory::AestheticComposition,
        FfiAssetSource::PhysicalSpec,
        "巴洛克對角線、反對角線交點、古典大師繪畫構圖幾何網",
        "構圖比例規 / 幾何分割網格",
        "1:1.414 (銀根矩形)",
        1.3,
        "dynamic_symmetry",
    ),
    (
        "typo_01",
        "拉丁字體排印五線度量基準 (Type Anatomy Baseline Metrics)",
        FfiAssetCategory::Typography,
        FfiAssetSource::PhysicalSpec,
        "包含 Cap Height、x-Height、Baseline、Ascender、Descender 基準線",
        "DIN 1451 / OpenType 字符度量規格",
        "48pt 參考字級 / 500pt 寬",
        1.4,
        "type_anatomy",
    ),
    (
        "typo_02",
        "中文字型永字八法九宮格 (Chinese Glyph 9-Grid Calligraphy)",
        FfiAssetCategory::Typography,
        FfiAssetSource::PhysicalSpec,
        "米字格、九宮格、筆畫重心平衡、外圓內方筆勢軌跡",
        "向量書法教學標註規格",
        "100 x 100 mm",
        1.3,
        "yong_eight_strokes",
    ),
    (
        "typo_03",
        "版面編排字級模矩比例尺 (Modular Type Scale 1.250)",
        FfiAssetCategory::Typography,
        FfiAssetSource::PhysicalSpec,
        "Major Third 等比倍率字級階梯 (12, 16, 20, 25, 31, 39, 48pt) 視覺對比",
        "印刷排版基準規格",
        "寬 360 x 高 240 pt",
        1.2,
        "modular_type_scale",
    ),
    (
        "motif_01",
        "包浩斯幾何構成裝飾組 (Bauhaus Geometric Motif Set)",
        FfiAssetCategory::DesignMotifs,
        FfiAssetSource::PhysicalSpec,
        "純粹圓形、三角形、正方形色彩交集與抽象網格組合",
        "向量幾何裝飾組標本",
        "200 x 200 mm",
        1.5,
        "bauhaus_motif",
    ),
    (
        "motif_02",
        "參數化 Voronoi 泰森多邊形紋樣 (Parametric Voronoi Cellular)",
        FfiAssetCategory::DesignMotifs,
        FfiAssetSource::PhysicalSpec,
        "自然生長仿生多孔結構、自適應點陣分佈、輕量化吸能骨架",
        "3D 打印尼龍 SLS / 幾何孔洞",
        "180 x 180 x 厚 2.5 mm",
        2.2,
        "voronoi_pattern",
    ),
    (
        "motif_03",
        "未來賽博賽道光軌幾何 (Cyberpunk Vector Circuit Tracks)",
        FfiAssetCategory::DesignMotifs,
        FfiAssetSource::AiConcept,
        "45° 折線電路軌跡、端點測試點標籤、高科技光感線框",
        "AI 概念渲染 / 向量幾何",
        "300 x 200 pt",
        2.0,
        "cyber_circuit",
    ),
    (
        "mold_01",
        "注塑模具 1.5° 拔模角與分模線剖面 (Draft Angle & Parting Line)",
        FfiAssetCategory::ToolingMolding,
        FfiAssetSource::PhysicalSpec,
        "凸模 (Core) 與凹模 (Cavity) 拔模公差、防止拉傷脫模結構",
        "P20 / 718H 預硬模具鋼結構",
        "250 x 150 x 120 mm",
        2.8,
        "draft_angle_mold",
    ),
    (
        "mold_02",
        "塑膠件均勻壁厚與加強筋規範 (Plastic Rib & Wall Ratio)",
        FfiAssetCategory::ToolingMolding,
        FfiAssetSource::PhysicalSpec,
        "主壁厚 T=2.5mm、加強筋厚度 0.6T (1.5mm)、根部圓角 R=0.5T",
        "ABS / PC 注塑防縮水變形準則",
        "160 x 80 x 30 mm",
        1.9,
        "plastic_rib_ratio",
    ),
    (
        "mold_03",
        "螺絲自攻牙注塑凸柱結構 (Boss Tower & Gusset)",
        FfiAssetCategory::ToolingMolding,
        FfiAssetSource::PhysicalSpec,
        "內徑 d=2.8mm (適用 M3 自攻螺絲)、外徑 2.5d、基座三角支撐筋",
        "POM / PA66 工程塑料凸柱",
        "Ø7.0 x 高 15.0 mm",
        1.6,
        "boss_tower",
    ),
    (
        "sheet_01",
        "鈑金 90° V 型折彎 K-Factor 計算展開圖 (Sheet Metal Bend Deduction)",
        FfiAssetCategory::SheetMetalCNC,
        FfiAssetSource::PhysicalSpec,
        "板厚 t=2.0mm、折彎內角 R=2.0mm、中性層 K=0.42 展開長度補償",
        "SPCC 冷軋鋼板 / 展開標註",
        "展開長度 124.5 mm / 折彎 90°",
        2.1,
        "sheetmetal_bend",
    ),
    (
        "sheet_02",
        "CNC 銑削內直角狗骨狀清角結構 (Dogbone Fillet Relief)",
        FfiAssetCategory::SheetMetalCNC,
        FfiAssetSource::PhysicalSpec,
        "消除端銑刀 Ø3.0mm 內角死區殘留、確保矩形嵌件完美密合裝配",
        "AL6061-T6 銑削加工規格",
        "嵌件槽 40 x 40 mm / 刀徑 Ø3",
        1.7,
        "cnc_dogbone",
    ),
    (
        "sheet_03",
        "沖孔自鉚壓鉚螺母柱 (PEM Self-Clinching Standoff)",
        FfiAssetCategory::SheetMetalCNC,
        FfiAssetSource::PhysicalSpec,
        "底板沖孔 Ø5.4mm、齒紋沉頭冷擠壓鎖入板金、拉拔扭矩達 4.8Nm",
        "鍍鋅碳鋼 M3 / 板厚 1.5mm",
        "M3 x 六角外徑 7.0 x 長 10 mm",
        1.4,
        "pem_standoff",
    ),
    (
        "surf_01",
        "陽極氧化膜厚與表面噴砂目數對照 (Anodizing Sandblast Grade)",
        FfiAssetCategory::SurfaceFinishing,
        FfiAssetSource::PhysicalSpec,
        "120# ~ 320# 鋯砂啞光打磨、15µm 二級陽極氧化皮膜、耐鹽霧 96h",
        "6000 系列鋁合金表面處理",
        "樣板標本 100 x 50 x 厚 2.0 mm",
        2.4,
        "anodizing_spec",
    ),
    (
        "surf_02",
        "表面粗糙度 Ra 算術平均標註規 (Surface Roughness Ra Scale)",
        FfiAssetCategory::SurfaceFinishing,
        FfiAssetSource::PhysicalSpec,
        "Ra 0.8 (精密精銑)、Ra 1.6 (普通精加工)、Ra 3.2 (粗加工粗糙度)",
        "ISO 1302 標準幾何表面符號",
        "標準測量基準長度 0.8 mm",
        1.8,
        "roughness_ra",
    ),
    (
        "pipe_01",
        "雙作用氣動滑台氣缸規格 (Dual-Acting Air Cylinder)",
        FfiAssetCategory::PneumaticsPiping,
        FfiAssetSource::PhysicalSpec,
        "缸徑 Ø16mm、標準行程 50mm、雙導軌抗扭轉、兩端磁簧感測槽",
        "硬質陽極氧化鋁合金缸體",
        "長 125 x 寬 44 x 高 28 mm",
        2.6,
        "pneumatic_cylinder",
    ),
    (
        "pipe_02",
        "快插式直角節流閥管路接頭 (One-Touch Speed Controller)",
        FfiAssetCategory::PneumaticsPiping,
        FfiAssetSource::PhysicalSpec,
        "外螺紋 R1/8、外接 PU 管徑 Ø6mm、刻度旋鈕精確控制氣流量",
        "黃銅鍍鎳 + POM 釋放環",
        "長 32 x 寬 24 x 高 28 mm",
        1.5,
        "push_in_fitting",
    ),
    (
        "ui_01",
        "iOS 與 Material 3 雙系統導航列對照 (Dual-OS Navbar Specs)",
        FfiAssetCategory::CrossPlatformUI,
        FfiAssetSource::PhysicalSpec,
        "iOS Large Title 96pt vs Android TopAppBar 64pt、邊距與觸控熱區",
        "向量 UI 規範 Wireframe",
        "393 x 120 pt 跨系統標準",
        1.5,
        "dual_os_navbar",
    ),
    (
        "ui_02",
        "底部操作卡片 Bottom Sheet 手勢容器 (Modal Bottom Sheet)",
        FfiAssetCategory::CrossPlatformUI,
        FfiAssetSource::PhysicalSpec,
        "頂部 Grabber 抓手把柄 (36x5pt)、半展開/全展開錨點、背景遮罩",
        "通用行動端浮動視窗規範",
        "393 x 480 pt (可滑動)",
        1.6,
        "bottom_sheet_ui",
    ),
    (
        "motion_01",
        "三次貝茲曲線動效時間函數 (Cubic Bezier Easing Curves)",
        FfiAssetCategory::UxMotion,
        FfiAssetSource::PhysicalSpec,
        "標準 Ease-In-Out (0.42, 0, 0.58, 1) 與彈性 Overshoot 曲線圖標",
        "CSS / Swift 動畫時間對應曲率",
        "坐標系 300 x 200 pt",
        1.4,
        "cubic_bezier_curve",
    ),
    (
        "motion_02",
        "彈簧阻尼系統動態示意 (Spring Mass Damper Physics)",
        FfiAssetCategory::UxMotion,
        FfiAssetSource::PhysicalSpec,
        "阻尼比 ζ=0.75 臨界阻尼、剛度係數 Stiffness 與衰減振幅包絡線",
        "iOS Spatial Physics 模型圖示",
        "波形坐標寬 320 x 高 180 pt",
        1.6,
        "spring_physics",
    ),
    (
        "ia_01",
        "階層式站點地圖與樹狀導航節點 (Sitemap Hierarchy Tree)",
        FfiAssetCategory::InfoArchitecture,
        FfiAssetSource::PhysicalSpec,
        "首頁根節點、一級頻道模組、次級頁面父子繼承關係線",
        "IA 資訊架構標準向量符號",
        "480 x 260 pt (樹狀拓撲)",
        1.7,
        "sitemap_tree",
    ),
    (
        "ia_02",
        "使用者狀態機躍遷流程圖 (User Journey State Machine)",
        FfiAssetCategory::InfoArchitecture,
        FfiAssetSource::PhysicalSpec,
        "起始態、條件分支 (If/Else)、等待非同步回調、終止態符號",
        "UX 流程與邏輯架構圖",
        "400 x 240 pt 泳道圖形",
        1.8,
        "state_machine_flow",
    ),
    (
        "token_01",
        "8pt 空間網格與間距度量尺 (8-Point Grid Spacing Scale)",
        FfiAssetCategory::DesignTokens,
        FfiAssetSource::PhysicalSpec,
        "4, 8, 12, 16, 24, 32, 48, 64pt 空間級數與原子排版基準",
        "Design System 間距原子規範",
        "長 360 x 寬 180 pt",
        1.3,
        "spacing_8pt_grid",
    ),
    (
        "token_02",
        "設計語意色彩層級與對比度矩陣 (Semantic Color Tokens WCAG)",
        FfiAssetCategory::DesignTokens,
        FfiAssetSource::PhysicalSpec,
        "Surface, Primary, On-Surface, Error 與 WCAG AAA (7:1) 對比度驗證",
        "色彩規範與無障礙標準規格",
        "360 x 220 pt 矩陣視圖",
        1.5,
        "semantic_color_tokens",
    ),
];

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashSet;

    #[test]
    fn the_catalog_matches_what_apple_ships() {
        // 58 件是 Apple 端目前的數量。少了就是漏抄，多了就是重複 ——
        // 兩種都會讓「兩個平台看到同一批素材」這句話不成立。
        assert_eq!(asset_items().len(), 58);
    }

    #[test]
    fn ids_are_unique_and_every_field_is_filled() {
        let mut seen = HashSet::new();
        for item in asset_items() {
            assert!(seen.insert(item.id.clone()), "重複的 id：{}", item.id);
            assert!(!item.title.is_empty(), "{} 沒有名稱", item.id);
            assert!(!item.specs.is_empty(), "{} 沒有規格", item.id);
            assert!(!item.material.is_empty(), "{} 沒有材料", item.id);
            assert!(!item.dimensions.is_empty(), "{} 沒有尺寸", item.id);
            assert!(!item.drawing_code.is_empty(), "{} 沒有線圖代號", item.id);
            assert!(item.file_size_mb > 0.0, "{} 的大小是 0", item.id);
        }
    }

    #[test]
    fn every_category_has_at_least_one_item() {
        // 空分類在面板上是一個點進去什麼都沒有的頁籤。
        for category in asset_categories() {
            assert!(
                !asset_items_in(category).is_empty(),
                "{category:?} 沒有任何素材"
            );
        }
    }

    #[test]
    fn search_finds_things_and_empty_query_returns_everything() {
        assert_eq!(asset_search(String::new()).len(), asset_items().len());
        assert_eq!(asset_search("   ".into()).len(), asset_items().len());
        // 規格欄位也要搜得到，不是只搜名稱。
        assert!(!asset_search("HRC".into()).is_empty());
        assert!(asset_search("這個字串不會出現在任何素材裡".into()).is_empty());
    }

    #[test]
    fn every_category_maps_to_a_theme() {
        for category in asset_categories() {
            let key = asset_category_key(category);
            assert!(key.starts_with("asset_cat_"), "壞的語系鍵：{key}");
            // 呼叫得到就代表 match 是窮盡的；漏一個分類編不過。
            let _ = asset_category_theme(category);
        }
    }
}
