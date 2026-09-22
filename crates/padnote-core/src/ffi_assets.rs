//! 素材圖庫的目錄。
//!
//! # 為什麼在核心
//!
//! 這 58 件技術素材原本只存在於 `apple/Sources/AssetLibraryManager.swift`，
//! Android 完全沒有這個功能。清單本身是**資料**，不是介面 —— 放在核心才能
//! 保證兩個平台看到同一批素材、同樣的分類與同樣的規格。
//!
//! # 這些欄位是什麼語言
//!
//! `title` 是繁體中文字面值，只當作**查詢用的原文**與翻譯缺漏時的退路；
//! 兩端 UI 顯示的都是 i18n 鍵 `asset_<id>_title`（Apple `AssetLibraryView.swift`、
//! Android `AssetLibrarySheet.kt` 各有一份同樣的 fallback 邏輯）。
//!
//! `specs` / `material` / `dimensions` 則刻意寫成**語言中性**：能用符號表達的
//! 一律用工程圖上本來就國際通用的記法（`Ø d D B W L H m i α P ∥ Ra HRC kN N·m`）
//! 與材料代號（SCM440、SUJ2、Ti-6Al-4V、SPCC…）；設計類素材（`digi_*`
//! `typo_*` `ui_*` `motion_*` `token_*`）的術語本身就是英文（cap height、
//! ease-in-out、WCAG AAA），照原樣保留。這樣六國語系不必各翻一份，
//! 也避免隨手翻出看起來像中文的外文。
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
///
/// 刻意沿用 Apple 端 `AssetCategory.localizationKey` 原本那組 `cat_*` 鍵，
/// 不另造一套 —— 同一個分類名稱翻兩次，遲早會出現兩個不一樣的譯法。
#[uniffi::export]
pub fn asset_category_key(category: FfiAssetCategory) -> String {
    match category {
        FfiAssetCategory::Mechanism => "cat_mechanism",
        FfiAssetCategory::Electronics3C => "cat_electronics",
        FfiAssetCategory::Automotive => "cat_automotive",
        FfiAssetCategory::Furniture => "cat_furniture",
        FfiAssetCategory::Hardware => "cat_hardware",
        FfiAssetCategory::Digital => "cat_digital",
        FfiAssetCategory::AestheticComposition => "cat_aesthetic_comp",
        FfiAssetCategory::Typography => "cat_typography",
        FfiAssetCategory::DesignMotifs => "cat_design_motifs",
        FfiAssetCategory::ToolingMolding => "cat_tooling_molding",
        FfiAssetCategory::SheetMetalCNC => "cat_sheetmetal_cnc",
        FfiAssetCategory::SurfaceFinishing => "cat_surface_finishing",
        FfiAssetCategory::PneumaticsPiping => "cat_pneumatics_piping",
        FfiAssetCategory::CrossPlatformUI => "cat_crossplatform_ui",
        FfiAssetCategory::UxMotion => "cat_ux_motion",
        FfiAssetCategory::InfoArchitecture => "cat_info_arch",
        FfiAssetCategory::DesignTokens => "cat_design_tokens",
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
    asset_items()
        .into_iter()
        .filter(|i| i.category == category)
        .collect()
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
        "m 2.0 · 24T/48T · i 1:2 · α 20° · JIS 2",
        "SCM440 · HRC 58–62",
        "Ø52 × 15 mm / Ø100 × 15 mm",
        1.8,
        "gear_pair",
    ),
    (
        "mech_02",
        "平面圓柱滾子軸承 (Cylindrical Roller Bearing)",
        FfiAssetCategory::Mechanism,
        FfiAssetSource::PhysicalSpec,
        "ISO 15 · C 42.5 kN",
        "GCr15 · H62",
        "d 30 × D 62 × B 16 mm",
        2.1,
        "bearing_iso",
    ),
    (
        "mech_03",
        "精密微型滾珠螺桿滑軌 (Linear Guide & Carriage)",
        FfiAssetCategory::Mechanism,
        FfiAssetSource::PhysicalSpec,
        "4-way · P 5 mm · ∥ ≤ 0.003 mm",
        "SUJ2 / SUS304",
        "W 15 × L 250 × H 28 mm",
        3.2,
        "linear_guide",
    ),
    (
        "mech_04",
        "等徑盤形凸輪連桿機構 (Disk Cam & Follower)",
        FfiAssetCategory::Mechanism,
        FfiAssetSource::PhysicalSpec,
        "SHM profile · stroke 20 mm · α max 28°",
        "S45C · HRC 50",
        "Ø60 base · 20 mm lift",
        2.4,
        "cam_follower",
    ),
    (
        "mech_05",
        "NEMA 17 混合式步進馬達 (Stepper Motor)",
        FfiAssetCategory::Mechanism,
        FfiAssetSource::PhysicalSpec,
        "1.8°/step · 45 N·cm · bipolar 4-wire",
        "Si-steel / Al / NdFeB",
        "42 × 42 × 40 mm · shaft Ø5 mm",
        2.7,
        "stepper_motor",
    ),
    (
        "mech_06",
        "動態外骨骼關節連桿 (Exoskeleton Biomechanical Joint)",
        FfiAssetCategory::Mechanism,
        FfiAssetSource::AiConcept,
        "bi-centric pivot · −35 % knee load",
        "Ti-6Al-4V · 3D-printed",
        "140 × 85 × 35 mm",
        4.5,
        "ai_exoskeleton",
    ),
    (
        "elec_01",
        "旗艦手機鋁合金中框結構 (Smartphone Uni-Frame)",
        FfiAssetCategory::Electronics3C,
        FfiAssetSource::PhysicalSpec,
        "5-axis CNC · step ≤ 0.02 mm · chamfered corners",
        "AL7075 · anodised",
        "160.8 × 78.1 × 7.8 mm",
        2.9,
        "phone_chassis",
    ),
    (
        "elec_02",
        "真無線降噪耳機聲學腔體 (TWS Acoustic Earbud)",
        FfiAssetCategory::Electronics3C,
        FfiAssetSource::PhysicalSpec,
        "concha-fit 3D surface · 2 vents · Ø10 mm driver",
        "PC-ABS (medical)",
        "24.5 × 21.2 × 18.0 mm",
        2.2,
        "earbud_acoustic",
    ),
    (
        "elec_03",
        "大光圈相機鏡頭光學鏡組 (Camera Optical Lens Assembly)",
        FfiAssetCategory::Electronics3C,
        FfiAssetSource::PhysicalSpec,
        "12 elements / 9 groups · linear AF · sealed mount",
        "ED glass / Mg-Al",
        "Ø78 × 95 mm · filter Ø67 mm",
        3.8,
        "camera_lens",
    ),
    (
        "elec_04",
        "75% 客製化機械鍵盤 Gasket 結構 (Mechanical Keyboard)",
        FfiAssetCategory::Electronics3C,
        FfiAssetSource::PhysicalSpec,
        "silicone damping · FR4 ENIG plate · acoustic foam",
        "6063 Al · CNC · e-coat",
        "320 × 140 × 38 mm",
        3.4,
        "keyboard_gasket",
    ),
    (
        "elec_05",
        "曲面未來感智慧座艙 HUD (Curved Cyber Cockpit HUD)",
        FfiAssetCategory::Electronics3C,
        FfiAssetSource::AiConcept,
        "Micro-OLED · waveguide · eye tracking",
        "optical PC / ceramic",
        "220 × 120 × 45 mm",
        4.8,
        "ai_hud_display",
    ),
    (
        "auto_01",
        "跑車空氣動力學流線側影 (Sports Car Aerodynamic Profile)",
        FfiAssetCategory::Automotive,
        FfiAssetSource::PhysicalSpec,
        "Cd 0.24 · rear-arch duct · diffuser floor",
        "dry carbon pre-preg",
        "4680 × 1980 × 1240 mm · WB 2720 mm",
        3.6,
        "car_silhouette",
    ),
    (
        "auto_02",
        "五輻雙柱鍛造運動輪框 (Forged Monoblock Wheel Rim)",
        FfiAssetCategory::Automotive,
        FfiAssetSource::PhysicalSpec,
        "single-piece forged · JWL/VIA",
        "6061-T6 forged",
        "20 in × 9.5J · PCD 5×114.3 · ET +35",
        2.8,
        "wheel_rim",
    ),
    (
        "auto_03",
        "雙 A 臂獨立懸吊機構 (Double Wishbone Suspension)",
        FfiAssetCategory::Automotive,
        FfiAssetSource::PhysicalSpec,
        "anti-roll geometry · N₂ inverted damper",
        "forged Al / Cr-Mo spring",
        "track span 580 mm · stroke 120 mm",
        3.5,
        "suspension_geometry",
    ),
    (
        "auto_04",
        "三輻運動賽車方向盤 (Sport Steering Wheel)",
        FfiAssetCategory::Automotive,
        FfiAssetSource::PhysicalSpec,
        "D-shape · magnetic carbon paddles · roller",
        "Alcantara / Mg frame",
        "Ø360 mm · grip 34 × 28 mm",
        2.6,
        "steering_wheel",
    ),
    (
        "auto_05",
        "純電滑板底盤電池模組架構 (EV Skateboard Chassis)",
        FfiAssetCategory::Automotive,
        FfiAssetSource::PhysicalSpec,
        "CTP pack · dual PMSM · single-piece casting",
        "1500 MPa steel + Al casting",
        "3400 × 1600 × 140 mm",
        4.2,
        "ev_chassis",
    ),
    (
        "auto_06",
        "未來星際懸浮穿梭載具 (Futuristic Orbital Shuttle)",
        FfiAssetCategory::Automotive,
        FfiAssetSource::AiConcept,
        "vector ion thrusters · faceted shell · ring bay",
        "graphene coat / aerogel",
        "6800 × 3800 × 2200 mm",
        5.2,
        "ai_orbital_shuttle",
    ),
    (
        "furn_01",
        "經典伊姆斯休閒躺椅 (Eames Lounge Chair Geometry)",
        FfiAssetCategory::Furniture,
        FfiAssetSource::PhysicalSpec,
        "5-ply moulded plywood · 15° recline · 5-star base",
        "walnut veneer / aniline leather",
        "840 × 850 × 840 mm · seat 400 mm",
        3.1,
        "eames_chair",
    ),
    (
        "furn_02",
        "人體工學升降辦公桌幾何 (Height-Adjustable Standing Desk)",
        FfiAssetCategory::Furniture,
        FfiAssetSource::PhysicalSpec,
        "dual motor · 3-stage · anti-collision",
        "cold-rolled steel / melamine",
        "1400 × 700 × 620–1270 mm",
        2.7,
        "standing_desk",
    ),
    (
        "furn_03",
        "包浩斯懸臂可調護眼檯燈 (Bauhaus Cantilever Task Lamp)",
        FfiAssetCategory::Furniture,
        FfiAssetSource::PhysicalSpec,
        "4-bar damped arm · flicker-free ring · hidden wiring",
        "anodised Al / Zn base",
        "reach 780 mm · base Ø200 mm",
        2.3,
        "task_lamp",
    ),
    (
        "furn_04",
        "北歐極簡模組收納櫃 (Modular Credenza)",
        FfiAssetCategory::Furniture,
        FfiAssetSource::PhysicalSpec,
        "45° recessed pull · soft-close · stackable",
        "solid white oak / waterborne",
        "1600 × 420 × 750 mm",
        2.5,
        "modular_credenza",
    ),
    (
        "hard_01",
        "ISO 4762 內六角圓柱頭螺栓 (Hex Socket Head Cap Screw)",
        FfiAssetCategory::Hardware,
        FfiAssetSource::PhysicalSpec,
        "M6 × 25 · P 1.0 · class 12.9 · hex S 5 mm",
        "SCM435 · black oxide",
        "head Ø10 × 6 · thread 25 mm",
        1.4,
        "hex_bolt",
    ),
    (
        "hard_02",
        "DIN 7991 沉頭內六角螺釘 (Countersunk Flat Head Screw)",
        FfiAssetCategory::Hardware,
        FfiAssetSource::PhysicalSpec,
        "M5 × 16 · 90° countersunk · flush",
        "SUS304 · passivated",
        "head Ø10 (90°) × 16 mm",
        1.3,
        "countersunk_screw",
    ),
    (
        "hard_03",
        "六角法蘭面防鬆螺母 (Hex Flange Lock Nut)",
        FfiAssetCategory::Hardware,
        FfiAssetSource::PhysicalSpec,
        "M8 · serrated flange · class 8",
        "carbon steel · Zn (RoHS)",
        "flange Ø18 × hex 8 mm",
        1.2,
        "flange_nut",
    ),
    (
        "hard_04",
        "封閉型抽芯盲鉚釘 (Closed-End Blind Rivet)",
        FfiAssetCategory::Hardware,
        FfiAssetSource::PhysicalSpec,
        "Ø4.0 × 12 mm · shear 2200 N · tensile 2800 N",
        "5052 Al body / steel mandrel",
        "Ø4.0 × 12 mm · grip 4–7 mm",
        1.1,
        "blind_rivet",
    ),
    (
        "hard_05",
        "圓柱螺旋壓縮彈簧 (Helical Compression Spring)",
        FfiAssetCategory::Hardware,
        FfiAssetSource::PhysicalSpec,
        "d 2.0 · D 16 · L₀ 50 · k 4.2 N/mm",
        "SWP-B · electroless Ni",
        "Ø16 × pitch 6.5 × L₀ 50 mm",
        1.5,
        "compression_spring",
    ),
    (
        "hard_06",
        "90° 強化沖壓直角固定角鐵 (Heavy-Duty L-Bracket)",
        FfiAssetCategory::Hardware,
        FfiAssetSource::PhysicalSpec,
        "t 3.0 mm · ribbed · 4 × M5 countersunk",
        "Q235 · powder-coated",
        "50 × 50 × 40 · t 3.0 mm",
        1.6,
        "bracket_l",
    ),
    (
        "digi_01",
        "旗艦智慧型手機 UI 向量線框 (Phone Wireframe Outline)",
        FfiAssetCategory::Digital,
        FfiAssetSource::PhysicalSpec,
        "19.5:9 · dynamic island cut-out · 44 pt safe area",
        "vector wireframe",
        "393 × 852 pt (scalable)",
        1.2,
        "wireframe_phone",
    ),
    (
        "digi_02",
        "平板手繪多視窗佈局 (Tablet Multi-Window Grid)",
        FfiAssetCategory::Digital,
        FfiAssetSource::PhysicalSpec,
        "4:3 workspace · split-view sidebar · dock guides",
        "vector wireframe",
        "1024 × 768 pt (scalable)",
        1.4,
        "wireframe_tablet",
    ),
    (
        "digi_03",
        "極簡瀏覽器視窗框架 (Browser Window Frame)",
        FfiAssetCategory::Digital,
        FfiAssetSource::PhysicalSpec,
        "traffic-light controls · pill address bar · tab strip",
        "vector wireframe",
        "1280 × 800 pt (scalable)",
        1.3,
        "wireframe_browser",
    ),
    (
        "digi_04",
        "行動端 8 種核心手勢符號包 (UX Gesture Annotations)",
        FfiAssetCategory::Digital,
        FfiAssetSource::PhysicalSpec,
        "tap · double-tap · long-press · swipe · rotate · pinch",
        "vector wireframe",
        "8 symbols · separable",
        1.5,
        "wireframe_gestures",
    ),
    (
        "aes_comp_01",
        "黃金螺旋對數構圖尺標 (Golden Spiral Logarithmic Guide)",
        FfiAssetCategory::AestheticComposition,
        FfiAssetSource::PhysicalSpec,
        "φ 1.618033 · Fibonacci squares · centripetal guides",
        "optical scale / vector",
        "1:1.618 (scalable)",
        1.2,
        "golden_spiral",
    ),
    (
        "aes_comp_02",
        "經典攝影三分法則九宮格 (Rule of Thirds Grid)",
        FfiAssetCategory::AestheticComposition,
        FfiAssetSource::PhysicalSpec,
        "4 focal intersections · 3 × 3 division",
        "16:9 framing guide",
        "16:9 / 3:2 (scalable)",
        1.1,
        "rule_of_thirds",
    ),
    (
        "aes_comp_03",
        "動態對稱菱形構圖引導 (Dynamic Symmetry Armatures)",
        FfiAssetCategory::AestheticComposition,
        FfiAssetSource::PhysicalSpec,
        "baroque diagonals · classical grid",
        "composition grid",
        "1:1.414 (silver rectangle)",
        1.3,
        "dynamic_symmetry",
    ),
    (
        "typo_01",
        "拉丁字體排印五線度量基準 (Type Anatomy Baseline Metrics)",
        FfiAssetCategory::Typography,
        FfiAssetSource::PhysicalSpec,
        "cap height · x-height · baseline · ascender · descender",
        "DIN 1451 / OpenType metrics",
        "48 pt sample · 500 pt wide",
        1.4,
        "type_anatomy",
    ),
    (
        "typo_02",
        "中文字型永字八法九宮格 (Chinese Glyph 9-Grid Calligraphy)",
        FfiAssetCategory::Typography,
        FfiAssetSource::PhysicalSpec,
        "mi-grid · 9-square grid · stroke balance",
        "calligraphy guide (vector)",
        "100 × 100 mm",
        1.3,
        "yong_eight_strokes",
    ),
    (
        "typo_03",
        "版面編排字級模矩比例尺 (Modular Type Scale 1.250)",
        FfiAssetCategory::Typography,
        FfiAssetSource::PhysicalSpec,
        "major third: 12, 16, 20, 25, 31, 39, 48 pt",
        "typographic scale",
        "360 × 240 pt",
        1.2,
        "modular_type_scale",
    ),
    (
        "motif_01",
        "包浩斯幾何構成裝飾組 (Bauhaus Geometric Motif Set)",
        FfiAssetCategory::DesignMotifs,
        FfiAssetSource::PhysicalSpec,
        "circle · triangle · square intersections + grid",
        "geometric ornament set",
        "200 × 200 mm",
        1.5,
        "bauhaus_motif",
    ),
    (
        "motif_02",
        "參數化 Voronoi 泰森多邊形紋樣 (Parametric Voronoi Cellular)",
        FfiAssetCategory::DesignMotifs,
        FfiAssetSource::PhysicalSpec,
        "bio-porous lattice · adaptive cells · energy-absorbing",
        "SLS nylon · 3D-printed",
        "180 × 180 × t 2.5 mm",
        2.2,
        "voronoi_pattern",
    ),
    (
        "motif_03",
        "未來賽博賽道光軌幾何 (Cyberpunk Vector Circuit Tracks)",
        FfiAssetCategory::DesignMotifs,
        FfiAssetSource::AiConcept,
        "45° trace routing · test-point labels · wireframe",
        "AI concept / vector",
        "300 × 200 pt",
        2.0,
        "cyber_circuit",
    ),
    (
        "mold_01",
        "注塑模具 1.5° 拔模角與分模線剖面 (Draft Angle & Parting Line)",
        FfiAssetCategory::ToolingMolding,
        FfiAssetSource::PhysicalSpec,
        "core / cavity draft · anti-scuff ejection",
        "P20 / 718H pre-hardened",
        "250 × 150 × 120 mm",
        2.8,
        "draft_angle_mold",
    ),
    (
        "mold_02",
        "塑膠件均勻壁厚與加強筋規範 (Plastic Rib & Wall Ratio)",
        FfiAssetCategory::ToolingMolding,
        FfiAssetSource::PhysicalSpec,
        "T 2.5 mm · rib 0.6T (1.5 mm) · fillet R 0.5T",
        "ABS / PC moulding rules",
        "160 × 80 × 30 mm",
        1.9,
        "plastic_rib_ratio",
    ),
    (
        "mold_03",
        "螺絲自攻牙注塑凸柱結構 (Boss Tower & Gusset)",
        FfiAssetCategory::ToolingMolding,
        FfiAssetSource::PhysicalSpec,
        "d 2.8 mm (M3 self-tapping) · OD 2.5d · 3 gussets",
        "POM / PA66 boss",
        "Ø7.0 × H 15.0 mm",
        1.6,
        "boss_tower",
    ),
    (
        "sheet_01",
        "鈑金 90° V 型折彎 K-Factor 計算展開圖 (Sheet Metal Bend Deduction)",
        FfiAssetCategory::SheetMetalCNC,
        FfiAssetSource::PhysicalSpec,
        "t 2.0 · inner R 2.0 · K 0.42",
        "SPCC · flat-pattern",
        "flat length 124.5 mm · bend 90°",
        2.1,
        "sheetmetal_bend",
    ),
    (
        "sheet_02",
        "CNC 銑削內直角狗骨狀清角結構 (Dogbone Fillet Relief)",
        FfiAssetCategory::SheetMetalCNC,
        FfiAssetSource::PhysicalSpec,
        "relief for Ø3.0 end mill · square insert fit",
        "AL6061-T6 milling",
        "pocket 40 × 40 mm · tool Ø3",
        1.7,
        "cnc_dogbone",
    ),
    (
        "sheet_03",
        "沖孔自鉚壓鉚螺母柱 (PEM Self-Clinching Standoff)",
        FfiAssetCategory::SheetMetalCNC,
        FfiAssetSource::PhysicalSpec,
        "pilot Ø5.4 mm · knurled press-fit · torque 4.8 N·m",
        "Zn carbon steel M3 · t 1.5 mm",
        "M3 · hex 7.0 × L 10 mm",
        1.4,
        "pem_standoff",
    ),
    (
        "surf_01",
        "陽極氧化膜厚與表面噴砂目數對照 (Anodizing Sandblast Grade)",
        FfiAssetCategory::SurfaceFinishing,
        FfiAssetSource::PhysicalSpec,
        "120#–320# zirconia blast · 15 µm anodise · 96 h salt spray",
        "6000-series Al finish",
        "sample 100 × 50 × t 2.0 mm",
        2.4,
        "anodizing_spec",
    ),
    (
        "surf_02",
        "表面粗糙度 Ra 算術平均標註規 (Surface Roughness Ra Scale)",
        FfiAssetCategory::SurfaceFinishing,
        FfiAssetSource::PhysicalSpec,
        "Ra 0.8 · Ra 1.6 · Ra 3.2",
        "ISO 1302 surface symbols",
        "sampling length 0.8 mm",
        1.8,
        "roughness_ra",
    ),
    (
        "pipe_01",
        "雙作用氣動滑台氣缸規格 (Dual-Acting Air Cylinder)",
        FfiAssetCategory::PneumaticsPiping,
        FfiAssetSource::PhysicalSpec,
        "bore Ø16 · stroke 50 mm · twin guide · reed slots",
        "hard-anodised Al",
        "125 × 44 × 28 mm",
        2.6,
        "pneumatic_cylinder",
    ),
    (
        "pipe_02",
        "快插式直角節流閥管路接頭 (One-Touch Speed Controller)",
        FfiAssetCategory::PneumaticsPiping,
        FfiAssetSource::PhysicalSpec,
        "R1/8 male · PU Ø6 mm · metered knob",
        "Ni-plated brass / POM",
        "32 × 24 × 28 mm",
        1.5,
        "push_in_fitting",
    ),
    (
        "ui_01",
        "iOS 與 Material 3 雙系統導航列對照 (Dual-OS Navbar Specs)",
        FfiAssetCategory::CrossPlatformUI,
        FfiAssetSource::PhysicalSpec,
        "iOS large title 96 pt vs Android top app bar 64 pt",
        "UI spec wireframe",
        "393 × 120 pt",
        1.5,
        "dual_os_navbar",
    ),
    (
        "ui_02",
        "底部操作卡片 Bottom Sheet 手勢容器 (Modal Bottom Sheet)",
        FfiAssetCategory::CrossPlatformUI,
        FfiAssetSource::PhysicalSpec,
        "grabber 36 × 5 pt · half / full detents · scrim",
        "mobile sheet spec",
        "393 × 480 pt",
        1.6,
        "bottom_sheet_ui",
    ),
    (
        "motion_01",
        "三次貝茲曲線動效時間函數 (Cubic Bezier Easing Curves)",
        FfiAssetCategory::UxMotion,
        FfiAssetSource::PhysicalSpec,
        "ease-in-out (0.42, 0, 0.58, 1) · overshoot",
        "CSS / Swift timing curves",
        "300 × 200 pt",
        1.4,
        "cubic_bezier_curve",
    ),
    (
        "motion_02",
        "彈簧阻尼系統動態示意 (Spring Mass Damper Physics)",
        FfiAssetCategory::UxMotion,
        FfiAssetSource::PhysicalSpec,
        "ζ 0.75 · stiffness · decay envelope",
        "spring physics model",
        "320 × 180 pt",
        1.6,
        "spring_physics",
    ),
    (
        "ia_01",
        "階層式站點地圖與樹狀導航節點 (Sitemap Hierarchy Tree)",
        FfiAssetCategory::InfoArchitecture,
        FfiAssetSource::PhysicalSpec,
        "root · channels · parent-child inheritance",
        "IA notation (vector)",
        "480 × 260 pt",
        1.7,
        "sitemap_tree",
    ),
    (
        "ia_02",
        "使用者狀態機躍遷流程圖 (User Journey State Machine)",
        FfiAssetCategory::InfoArchitecture,
        FfiAssetSource::PhysicalSpec,
        "start · if/else · async wait · end",
        "UX flow notation",
        "400 × 240 pt",
        1.8,
        "state_machine_flow",
    ),
    (
        "token_01",
        "8pt 空間網格與間距度量尺 (8-Point Grid Spacing Scale)",
        FfiAssetCategory::DesignTokens,
        FfiAssetSource::PhysicalSpec,
        "4, 8, 12, 16, 24, 32, 48, 64 pt",
        "spacing scale",
        "360 × 180 pt",
        1.3,
        "spacing_8pt_grid",
    ),
    (
        "token_02",
        "設計語意色彩層級與對比度矩陣 (Semantic Color Tokens WCAG)",
        FfiAssetCategory::DesignTokens,
        FfiAssetSource::PhysicalSpec,
        "surface · primary · on-surface · error · WCAG AAA 7:1",
        "colour + a11y spec",
        "360 × 220 pt",
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

    /// 規格三欄必須維持語言中性 —— 一旦有人塞回中文，六國語系就又缺一塊翻譯。
    /// `title` 不在此列：它走 i18n 鍵 `asset_<id>_title`，中文只是原文與退路。
    #[test]
    fn the_spec_columns_stay_language_neutral() {
        for item in asset_items() {
            for (field, value) in [
                ("specs", &item.specs),
                ("material", &item.material),
                ("dimensions", &item.dimensions),
            ] {
                let cjk = value.chars().find(|c| {
                    matches!(*c as u32, 0x3400..=0x4DBF | 0x4E00..=0x9FFF | 0xF900..=0xFAFF)
                        || matches!(*c as u32, 0x3040..=0x30FF | 0xAC00..=0xD7AF)
                });
                assert!(
                    cjk.is_none(),
                    "{} 的 {} 含有 {:?}：{}",
                    item.id,
                    field,
                    cjk.unwrap(),
                    value
                );
            }
        }
    }

    #[test]
    fn every_category_maps_to_a_theme() {
        for category in asset_categories() {
            let key = asset_category_key(category);
            assert!(key.starts_with("cat_"), "壞的語系鍵：{key}");
            // 呼叫得到就代表 match 是窮盡的；漏一個分類編不過。
            let _ = asset_category_theme(category);
        }
    }
}
