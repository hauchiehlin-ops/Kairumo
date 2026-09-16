//! UniFFI 門面（工作項 S-12）。
//!
//! Swift 與 Kotlin **只透過這一層**呼叫 Rust core。
//!
//! ## 為什麼要獨立一層，而不直接匯出內部型別
//! 1. FFI 邊界只能傳簡單型別（record/enum/字串/數字）。內部的 `Uuid`、
//!    `NotebookTime`、trait 物件都過不去。
//! 2. 內部重構不該逼著兩個平台的 UI 一起改。這一層是**穩定的契約**。
//! 3. 錯誤要變成各平台慣用的形式（Swift 的 `throws`、Kotlin 的 exception）。
//!
//! ## 執行緒
//! `PadnoteSession` 內含 `Mutex`。UI 執行緒與背景的 ASR／同步執行緒都會碰它，
//! 因此每個方法都短暫持鎖後立刻釋放 —— **絕不在持鎖期間做 IO 以外的長工作**，
//! 否則會卡住墨跡執行緒（違反 J1 的延遲預算）。

use crate::app::{AppError, NotebookSession, RecordingState};
use crate::ffi_shapes::{FfiAnchor, FfiEndCap, FfiRouteStyle, FfiShapeKind};
use crate::setup::{Capability, Feature, SetupCenter, Status};
use padnote_doc::{
    Affine2, Anchor, ConnectionObject, EndCap, NotebookTime, ObjectRect, PageTemplate, RouteStyle,
    ShapeKind, ShapeObject, TextStyle, TranscriptWord, Uuid,
};
use padnote_ink::{InkPoint, Stroke, Tool};
use std::sync::Mutex;

// ---- 錯誤 ----

#[derive(Debug, uniffi::Error)]
#[uniffi(flat_error)]
pub enum FfiError {
    /// 訊息已在地化，可直接顯示給使用者。
    Failed(String),
}

impl std::fmt::Display for FfiError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Failed(m) => f.write_str(m),
        }
    }
}

impl std::error::Error for FfiError {}

impl From<AppError> for FfiError {
    fn from(e: AppError) -> Self {
        Self::Failed(e.to_string())
    }
}

// ---- 資料型別 ----

#[derive(Clone, Copy, Debug, uniffi::Enum)]
pub enum ToolKind {
    FountainPen,
    BallPoint,
    Highlighter,
    Pencil,
}

impl From<ToolKind> for Tool {
    fn from(t: ToolKind) -> Self {
        match t {
            ToolKind::FountainPen => Tool::FountainPen,
            ToolKind::BallPoint => Tool::BallPoint,
            ToolKind::Highlighter => Tool::Highlighter,
            ToolKind::Pencil => Tool::Pencil,
        }
    }
}

impl From<Tool> for ToolKind {
    /// 反向轉換是互通用的：`.padnote` 讀回來要能還原成平台的筆刷。
    fn from(t: Tool) -> Self {
        match t {
            Tool::FountainPen => ToolKind::FountainPen,
            Tool::BallPoint => ToolKind::BallPoint,
            Tool::Highlighter => ToolKind::Highlighter,
            Tool::Pencil => ToolKind::Pencil,
        }
    }
}

#[derive(Clone, Copy, Debug, uniffi::Enum)]
pub enum PageStyle {
    Blank,
    Lined,
    Grid,
    Dotted,
    Cornell,
    MusicStaff,
}

impl From<PageStyle> for PageTemplate {
    fn from(p: PageStyle) -> Self {
        match p {
            PageStyle::Blank => PageTemplate::Blank,
            PageStyle::Lined => PageTemplate::Lined,
            PageStyle::Grid => PageTemplate::Grid,
            PageStyle::Dotted => PageTemplate::Dotted,
            PageStyle::Cornell => PageTemplate::Cornell,
            PageStyle::MusicStaff => PageTemplate::MusicStaff,
        }
    }
}

#[derive(Clone, Copy, Debug, uniffi::Enum)]
pub enum BlockStyle {
    Body,
    Heading1,
    Heading2,
    Heading3,
    Bullet,
    Quote,
    Code,
    TodoOpen,
    TodoDone,
}

impl From<BlockStyle> for TextStyle {
    fn from(b: BlockStyle) -> Self {
        match b {
            BlockStyle::Body => TextStyle::Body,
            BlockStyle::Heading1 => TextStyle::Heading1,
            BlockStyle::Heading2 => TextStyle::Heading2,
            BlockStyle::Heading3 => TextStyle::Heading3,
            BlockStyle::Bullet => TextStyle::Bullet,
            BlockStyle::Quote => TextStyle::Quote,
            BlockStyle::Code => TextStyle::Code,
            BlockStyle::TodoOpen => TextStyle::Todo { done: false },
            BlockStyle::TodoDone => TextStyle::Todo { done: true },
        }
    }
}

/// 一個觸控取樣點。欄位對應 `InkPoint`（format-spec §5.4）。
///
/// ⚠️ 平台層**不得**把預測筆跡（predicted touches）放進來 ——
/// 那是視覺補償，不是真實輸入。
#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct StrokePoint {
    pub x: f32,
    pub y: f32,
    pub pressure: f32,
    pub tilt: f32,
    pub azimuth: f32,
    /// 距前一點的微秒差。
    pub dt_us: u32,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct SearchResult {
    pub page_id: String,
    pub block_id: String,
    /// `text` / `transcript` / `handwriting` / `pdf` / `ocr`
    pub source: String,
    pub score: f32,
    pub snippet: String,
}

/// 功能 C1 的回傳值：某個時刻對應的錄音位置。
#[derive(Clone, Debug, uniffi::Record)]
pub struct PlaybackPosition {
    /// 相對筆記本根目錄的音檔路徑。
    pub media_path: String,
    /// 音檔內的播放偏移（微秒）。
    pub offset_us: u64,
}

/// 一次 `feed_audio` 的統計。
#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct RecordingStats {
    /// 本次寫進 Opus 檔的音框數。
    pub frames_written: u64,
    /// 本次切出並入列待轉錄的語音段數。
    pub segments_queued: u32,
    /// 累計因佇列滿而丟棄的段數。**非零代表 ASR 跟不上錄音速度**，
    /// UI 應提示使用者改用較小的模型。音檔本身不受影響。
    pub segments_dropped: u64,
    /// 已落盤的音訊總時長。
    pub recorded_us: u64,
    /// 待轉錄的音訊時長。
    pub backlog_us: u64,
}

/// 平台層傳入的轉錄結果。時間戳必須已在筆記本時間軸上。
#[derive(Clone, Debug, uniffi::Record)]
pub struct TranscriptWordInput {
    pub text: String,
    pub start_us: u64,
    pub end_us: u64,
    pub confidence: f32,
}

/// 繪製順序中的一項。
#[derive(Clone, Debug, uniffi::Record)]
pub struct DrawItem {
    pub object_id: String,
    /// 世界變換 `[a, b, c, d, tx, ty]`。
    pub transform: Vec<f32>,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct StrokeSummary {
    pub id: String,
    pub started_at_us: u64,
    pub point_count: u32,
    /// 含筆寬的外框 `[min_x, min_y, max_x, max_y]`，供命中測試與重繪。
    pub bounds: Vec<f32>,
}

/// 一筆畫的**完整**內容，含每一個取樣點。
///
/// 與 `StrokeSummary` 的分工要說清楚，否則很容易誤用：
/// - `StrokeSummary` 給**渲染與命中測試**，刻意不帶點，一頁數萬個點過 FFI 會很慢。
/// - `FullStroke` 給**互通與遷移**：把 Apple 的 PKDrawing 轉進核心、或把核心的
///   筆畫還原回平台筆刷時，少一個欄位就是資料遺失，所以這裡一個都不能省。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FullStroke {
    pub id: String,
    pub started_at_us: u64,
    pub tool: ToolKind,
    /// RGBA 各 0–255，固定 4 個位元組。
    pub color_rgba: Vec<u8>,
    pub base_width: f32,
    pub points: Vec<StrokePoint>,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FeatureStatus {
    /// `core_notes` / `recording` / `live_transcription` / …
    pub feature: String,
    pub ready: bool,
    /// 給使用者看的一句話，例如「需要：麥克風、語音模型」。
    pub explanation: String,
}

// ---- 應用程式與核心版本資訊 ----

/// 標準頁面尺寸 `[寬, 高]`（點）。
///
/// 平台層**必須**用這個值，不要各自寫一份常數 —— 差一點點的後果就是
/// 「畫布上看到的」與「匯出的」對不起來，而那種偏差沒有人會在開發時發現。
#[uniffi::export]
pub fn standard_page_size() -> Vec<f32> {
    vec![padnote_doc::PAGE_WIDTH, padnote_doc::PAGE_HEIGHT]
}

/// 物件底色調色盤：`[(語系鍵, hex), …]`，由後到前就是選單上的順序。
///
/// # 為什麼這個要放在核心
///
/// 它是**會落盤的資料**，不是單純的樣式偏好：使用者挑了「淡藍」，存進筆記的
/// 是那個 hex。兩個地方各寫一份清單，同一個名字就會對到不同的顏色。
///
/// 實際發生過，而且是在**同一個平台裡**：Apple 的畫布快速選單給 `#E3F2FD`、
/// 文字排版面板給 `#E1F5FE`，都叫「淡藍」。使用者在畫布上挑了藍色，再打開
/// 排版面板，會看到七個色票沒有一個是選中的 —— 他挑的顏色不在清單裡。
/// 灰色同樣有兩個值（`#EEEEEE` / `#F5F5F5`）。
///
/// 「透明」不在這裡：它是哨符（`"clear"`）不是顏色，而且不是每個地方都適用。
#[uniffi::export]
pub fn card_palette() -> Vec<FfiPaletteEntry> {
    [
        ("color_white", "#FFFFFF"),
        ("color_yellow", "#FFF9C4"),
        ("color_green", "#E8F5E9"),
        ("color_pink", "#FCE4EC"),
        ("color_blue", "#E1F5FE"),
        ("color_gray", "#F5F5F5"),
        ("color_black", "#212121"),
    ]
    .into_iter()
    .map(|(key, hex)| FfiPaletteEntry {
        key: key.to_string(),
        hex: hex.to_string(),
    })
    .collect()
}

/// 設計師色盤：`[(語系鍵, hex), …]`，依組別分開。
///
/// 理由同 [`card_palette`] —— 顏色是會落盤的資料。色名走語系鍵，不寫死文字：
/// 原本 Apple 端這 40 個名字全是寫死的繁體中文，日文或英文使用者在一個已經
/// 翻成六國語系的面板裡看到一整面中文。
#[uniffi::export]
pub fn designer_palette(group: FfiPaletteGroup) -> Vec<FfiPaletteEntry> {
    let list: &[(&str, &str)] = match group {
        FfiPaletteGroup::Morandi => &[
            ("hue_oat_gray", "#9E9D89"),
            ("hue_sage_green", "#A3B19B"),
            ("hue_haze_blue", "#8C9DAE"),
            ("hue_milk_tea", "#BAA599"),
            ("hue_warm_almond", "#D8C3A5"),
            ("hue_caramel_pink", "#C5A880"),
            ("hue_gray_cardamom", "#948275"),
            ("hue_premium_gray", "#7F7F7F"),
        ],
        FfiPaletteGroup::Vintage => &[
            ("hue_terracotta", "#8D5B4C"),
            ("hue_caramel_brown", "#C68B59"),
            ("hue_mustard", "#D9A74A"),
            ("hue_retro_teal", "#4A6B6C"),
            ("hue_slate_blue", "#2B4C5A"),
            ("hue_rust_red", "#7D3C3C"),
            ("hue_chestnut", "#5A3D31"),
            ("hue_fallen_leaf", "#96705B"),
        ],
        FfiPaletteGroup::Business => &[
            ("hue_deep_navy", "#1A365D"),
            ("hue_business_blue", "#2B6CB0"),
            ("hue_graphite_blue", "#2C5282"),
            ("hue_fir_green", "#234E52"),
            ("hue_ink_green", "#285E61"),
            ("hue_burgundy", "#742A2A"),
            ("hue_cold_stone", "#4A5568"),
            ("hue_midnight", "#1A202C"),
        ],
        FfiPaletteGroup::Pastel => &[
            ("hue_sakura_pink", "#FFB7B2"),
            ("hue_peach_apricot", "#FFDAC1"),
            ("hue_green_apple", "#E2F0CB"),
            ("hue_mint_green", "#B5EAD7"),
            ("hue_periwinkle", "#C7CEEA"),
            ("hue_lavender", "#E0BBE4"),
            ("hue_grape_gray", "#957DAD"),
            ("hue_rose_dusk", "#D291BC"),
        ],
        FfiPaletteGroup::Neon => &[
            ("hue_electric_magenta", "#FF007F"),
            ("hue_fluoro_cyan", "#00F0FF"),
            ("hue_neon_green", "#39FF14"),
            ("hue_aurora_orange", "#FF6600"),
            ("hue_iridescent_purple", "#BD00FF"),
            ("hue_vivid_yellow", "#FFE600"),
            ("hue_high_energy_red", "#FF0033"),
            ("hue_sky_ultra_blue", "#00E5FF"),
        ],
    };
    list.iter()
        .map(|(key, hex)| FfiPaletteEntry {
            key: (*key).to_string(),
            hex: (*hex).to_string(),
        })
        .collect()
}

/// 設計師色盤的組別。`localization_key` 給平台顯示組名。
#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum FfiPaletteGroup {
    Morandi,
    Vintage,
    Business,
    Pastel,
    Neon,
}

/// 所有組別，依面板上的顯示順序。
#[uniffi::export]
pub fn designer_palette_groups() -> Vec<FfiPaletteGroup> {
    vec![
        FfiPaletteGroup::Morandi,
        FfiPaletteGroup::Vintage,
        FfiPaletteGroup::Business,
        FfiPaletteGroup::Pastel,
        FfiPaletteGroup::Neon,
    ]
}

/// 組名的語系鍵。
#[uniffi::export]
pub fn designer_palette_group_key(group: FfiPaletteGroup) -> String {
    match group {
        FfiPaletteGroup::Morandi => "palette_morandi",
        FfiPaletteGroup::Vintage => "palette_vintage",
        FfiPaletteGroup::Business => "palette_business",
        FfiPaletteGroup::Pastel => "palette_pastel",
        FfiPaletteGroup::Neon => "palette_neon",
    }
    .to_string()
}

/// 邊框顏色調色盤。理由同 [`card_palette`]。
#[uniffi::export]
pub fn border_palette() -> Vec<FfiPaletteEntry> {
    [
        "#8E8E93", "#000000", "#0A84FF", "#34C759", "#FF9500", "#FF3B30", "#AF52DE",
    ]
    .into_iter()
    .map(|hex| FfiPaletteEntry {
        key: String::new(),
        hex: hex.to_string(),
    })
    .collect()
}

/// 調色盤的一格。`key` 是語系鍵（沒有名字時為空字串）。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiPaletteEntry {
    pub key: String,
    pub hex: String,
}

/// 核心引擎與套件版本號（例如 "0.1.4"），與 Cargo.toml 同步。
#[uniffi::export]
pub fn core_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

/// 應用程式基本資訊，供各平台首頁、關於頁與診斷中心使用。
#[derive(Clone, Debug, uniffi::Record)]
pub struct AppInfo {
    pub name: String,
    pub version: String,
    pub build_profile: String,
    pub target_os: String,
    pub target_arch: String,
}

#[uniffi::export]
pub fn app_info() -> AppInfo {
    AppInfo {
        name: "Kairumo".to_string(),
        version: env!("CARGO_PKG_VERSION").to_string(),
        build_profile: if cfg!(debug_assertions) {
            "debug".to_string()
        } else {
            "release".to_string()
        },
        target_os: std::env::consts::OS.to_string(),
        target_arch: std::env::consts::ARCH.to_string(),
    }
}

// ---- Session ----

/// 一個開啟中的筆記本。各平台持有它的參照。
#[derive(Debug, uniffi::Object)]
pub struct PadnoteSession {
    inner: Mutex<NotebookSession>,
    setup: Mutex<SetupCenter>,
}

#[uniffi::export]
impl PadnoteSession {
    /// 建立新筆記本。
    ///
    /// `path` 是 `.padnote` 套件的目錄位置。`device_id` 必須是**這台裝置穩定
    /// 不變**的識別碼（例如 iOS 的 `identifierForVendor` 雜湊後取 32 bit）——
    /// 它會進 oplog 檔名，用來保證兩台裝置永不寫同一個檔。
    #[uniffi::constructor]
    pub fn create(
        path: String,
        title: String,
        now_unix_ms: u64,
        device_id: u32,
    ) -> Result<Self, FfiError> {
        Ok(Self::wrap(NotebookSession::create(
            path,
            &title,
            now_unix_ms,
            device_id,
        )?))
    }

    /// 建立一本**沒有任何頁**的筆記本。
    ///
    /// 重建套件時（匯出、同步）頁面必須沿用既有的 id，`create` 自動給的那一頁
    /// 就成了多餘的。而「先加一頁、再把它移掉」在多裝置合併時不保證互相抵銷 ——
    /// 兩台裝置各自的 Add/Remove 交錯之後可能留下一頁空白，而且每同步一趟再多
    /// 一頁。不產生它，就沒有需要抵銷的東西。
    #[uniffi::constructor]
    pub fn create_empty(
        path: String,
        title: String,
        now_unix_ms: u64,
        device_id: u32,
    ) -> Result<Self, FfiError> {
        Ok(Self::wrap(NotebookSession::create_empty(
            path,
            &title,
            now_unix_ms,
            device_id,
        )?))
    }

    /// 開啟既有筆記本，重播 op-log 還原全部內容。
    ///
    /// ⚠️ 名稱刻意不叫 `open` —— `open` 是 Swift 的存取修飾關鍵字，
    /// UniFFI 會**靜默略過**該建構子，Swift 端就完全看不到它。
    #[uniffi::constructor]
    pub fn open_existing(path: String, device_id: u32) -> Result<Self, FfiError> {
        Ok(Self::wrap(NotebookSession::open(path, device_id)?))
    }

    /// 推進筆記本時間軸。平台層以 monotonic clock 餵入，**必須單調遞增**。
    pub fn advance_time(&self, notebook_time_us: u64) {
        self.lock()
            .advance_time(NotebookTime::from_micros(notebook_time_us));
    }

    pub fn now_us(&self) -> u64 {
        self.lock().now().as_micros()
    }

    pub fn title(&self) -> String {
        self.lock().notebook().title.clone()
    }

    pub fn page_count(&self) -> u32 {
        self.lock().notebook().page_count() as u32
    }

    pub fn first_page_id(&self) -> Option<String> {
        self.lock().first_page().map(|id| id.to_string())
    }

    /// 第 `index` 頁的 id（由 0 起算）。超出範圍時回傳 `None`。
    ///
    /// 沒有這個出口，平台層只拿得到第一頁 —— 多頁筆記根本走不完。
    /// 頁面 id 的產生規則是內部實作，平台層不該去猜。
    pub fn page_id_at(&self, index: u32) -> Option<String> {
        self.lock()
            .notebook()
            .pages()
            .get(index as usize)
            .map(|p| p.id.to_string())
    }

    pub fn add_page(&self, style: PageStyle) -> Result<String, FfiError> {
        Ok(self.lock().add_page(style.into())?.to_string())
    }

    /// 移除一頁。
    ///
    /// 平台原本加得了頁卻移不掉。匯出時若要沿用既有的頁面 id，建立筆記本
    /// 自動產生的那一頁就成了多餘的第一頁 —— 沒有這一支，頁數每次匯出都會多一。
    pub fn remove_page(&self, page_id: String) -> Result<(), FfiError> {
        self.lock().remove_page(parse_uuid(&page_id)?)?;
        Ok(())
    }

    /// 用指定的 id 新增一頁；已經有同 id 的頁時什麼也不做。
    ///
    /// 頁面身分必須跟著筆記走，不是跟著某一次匯出走 —— 每次重建都隨機生一批
    /// id 的話，兩台裝置的頁永遠不會收斂，合併後會變成兩倍的頁數，
    /// 而且每同步一趟就再多一批。
    pub fn add_page_with_id(&self, page_id: String, style: PageStyle) -> Result<(), FfiError> {
        self.lock()
            .add_page_with_id(parse_uuid(&page_id)?, style.into())?;
        Ok(())
    }

    pub fn set_title(&self, title: String) -> Result<(), FfiError> {
        self.lock().set_title(&title)?;
        Ok(())
    }

    /// 取得核心引擎版本號。
    pub fn version(&self) -> String {
        core_version()
    }

    // ---- 手寫 ----

    /// 寫入一筆畫，回傳其 id。時間戳由 core 依當前時間軸填入。
    pub fn add_stroke(
        &self,
        page_id: String,
        tool: ToolKind,
        color_rgba: Vec<u8>,
        base_width: f32,
        points: Vec<StrokePoint>,
    ) -> Result<String, FfiError> {
        let page = parse_uuid(&page_id)?;
        let id = Uuid::now_v7();
        let stroke = Stroke {
            id,
            started_at: NotebookTime::ZERO, // core 會覆寫為當前時間
            tool: tool.into(),
            color_rgba8: to_rgba(&color_rgba),
            base_width,
            points: points.into_iter().map(to_ink_point).collect(),
        };
        self.lock().add_stroke(page, stroke)?;
        Ok(id.to_string())
    }

    pub fn erase_stroke(&self, page_id: String, stroke_id: String) -> Result<(), FfiError> {
        let (page, stroke) = (parse_uuid(&page_id)?, parse_uuid(&stroke_id)?);
        self.lock().erase_stroke(page, stroke)?;
        Ok(())
    }

    /// 目前可見的筆畫摘要。
    ///
    /// 刻意不回傳全部取樣點 —— 一頁數萬個點跨 FFI 邊界會很慢。
    /// 渲染用的原始資料由平台層直接讀 `.strokes` 檔。
    pub fn visible_strokes(&self, page_id: String) -> Result<Vec<StrokeSummary>, FfiError> {
        let page = parse_uuid(&page_id)?;
        Ok(self
            .lock()
            .visible_strokes(page)?
            .into_iter()
            .map(|s| {
                let b = s.inked_bounds();
                StrokeSummary {
                    id: s.id.to_string(),
                    started_at_us: s.started_at.as_micros(),
                    point_count: s.points.len() as u32,
                    bounds: b.map_or_else(Vec::new, |r| vec![r.min_x, r.min_y, r.max_x, r.max_y]),
                }
            })
            .collect())
    }

    /// 某一頁全部可見筆畫的**完整**內容（含取樣點）。
    ///
    /// 這是互通與遷移用的出口，不是渲染路徑 —— 渲染請走 `visible_strokes`。
    /// 沒有這個出口，「iOS 寫的字在 Android 開起來一模一樣」就無從驗證：
    /// 只能比對筆畫數與外框，比不到座標、壓感與時間差。
    pub fn visible_stroke_details(&self, page_id: String) -> Result<Vec<FullStroke>, FfiError> {
        let page = parse_uuid(&page_id)?;
        Ok(self
            .lock()
            .visible_strokes(page)?
            .into_iter()
            .map(to_full_stroke)
            .collect())
    }

    /// 單一筆畫的完整內容。查無此筆畫（或已被擦除）時回傳 `None`。
    pub fn stroke_detail(
        &self,
        page_id: String,
        stroke_id: String,
    ) -> Result<Option<FullStroke>, FfiError> {
        let (page, wanted) = (parse_uuid(&page_id)?, parse_uuid(&stroke_id)?);
        Ok(self
            .lock()
            .visible_strokes(page)?
            .into_iter()
            .find(|s| s.id == wanted)
            .map(to_full_stroke))
    }

    // ---- 套索選取 ----
    //
    // # 為什麼選取要在核心
    //
    // Apple 端原本是拿 `UIResponderStandardEditActions` 去戳 PencilKit 的私有
    // 子視圖（`PKTiledView`），靠它自己的選取狀態做剪下／複製／刪除。那條路
    // 有三個問題，而且是同時發生的：
    //
    // 1. 相依於私有的視圖類別名稱 —— 換一版 iOS 就可能整組失效，而且不會
    //    有任何錯誤，按鈕只是沒反應。
    // 2. 送給不是 first responder 的視圖，那些 action 根本不會被執行。
    // 3. Mac Catalyst 的 responder chain 與 PencilKit 的套索實作都不一樣。
    //
    // 結果就是使用者看到的：**按鈕全部沒有作用。**
    //
    // 更根本的是 Android 完全沒有套索 —— 那條路裡沒有一行是可以共用的。
    // 選取本身是純幾何（點在不在多邊形裡），放進核心兩邊就是同一套。

    /// 被套索圈中的筆畫 id。
    ///
    /// `polygon` 是**頁面座標**下的多邊形，成對排列 `[x0, y0, x1, y1, …]`。
    /// 用扁平陣列而不是點的陣列：跨 FFI 邊界時前者是一次記憶體複製，
    /// 後者要逐一建構結構。
    ///
    /// 判定是「**整條**都在裡面」，與橡皮擦的部分命中不同 ——
    /// 圈到一半的筆畫被選走，使用者會覺得選取很難控制。
    pub fn lasso_select(
        &self,
        page_id: String,
        polygon: Vec<f32>,
    ) -> Result<Vec<String>, FfiError> {
        let page = parse_uuid(&page_id)?;
        let poly = to_polygon(&polygon);
        Ok(self
            .lock()
            .visible_strokes(page)?
            .into_iter()
            .filter(|s| s.is_enclosed_by_polygon(&poly))
            .map(|s| s.id.to_string())
            .collect())
    }

    /// 刪除一組筆畫。
    ///
    /// 一次收一整組而不是讓平台層逐一呼叫：中途失敗時前面那幾筆已經刪掉了，
    /// 使用者看到的是「刪了一半」，而且沒有東西告訴他發生什麼事。
    /// 這裡遇到不存在的 id 直接跳過 —— 它可能剛被另一台裝置刪掉，
    /// 那不是錯誤。
    ///
    /// 回傳的是**真的從畫面上消失的筆數**，不是「呼叫成功幾次」。
    /// `erase_stroke` 本身是冪等的（重複擦只是多一個墓碑，不會失敗），
    /// 所以數「沒有出錯的次數」會把已經不在的那幾筆也算進去 ——
    /// 呼叫端拿它去顯示「已刪除 N 筆」就會報出一個比實際多的數字。
    pub fn lasso_delete(&self, page_id: String, stroke_ids: Vec<String>) -> Result<u32, FfiError> {
        let page = parse_uuid(&page_id)?;
        let visible: std::collections::BTreeSet<String> = self
            .lock()
            .visible_strokes(page)?
            .into_iter()
            .map(|s| s.id.to_string())
            .collect();

        let mut removed = 0u32;
        for id in &stroke_ids {
            if !visible.contains(id) {
                continue;
            }
            let Ok(stroke) = parse_uuid(id) else { continue };
            if self.lock().erase_stroke(page, stroke).is_ok() {
                removed += 1;
            }
        }
        Ok(removed)
    }

    /// 把一組筆畫的完整內容取出來，當成剪貼簿內容。
    ///
    /// 回傳的是 [`FullStroke`]，平台層原樣存著就好，不必看懂內容。
    /// **不放進系統剪貼簿** —— 那是平台的事，而且兩邊的剪貼簿格式不一樣。
    pub fn lasso_copy(
        &self,
        page_id: String,
        stroke_ids: Vec<String>,
    ) -> Result<Vec<FullStroke>, FfiError> {
        let page = parse_uuid(&page_id)?;
        let wanted: std::collections::BTreeSet<String> = stroke_ids.into_iter().collect();
        Ok(self
            .lock()
            .visible_strokes(page)?
            .into_iter()
            .filter(|s| wanted.contains(&s.id.to_string()))
            .map(to_full_stroke)
            .collect())
    }

    /// 把一組筆畫貼到某一頁，整體平移 `(dx, dy)`。回傳新筆畫的 id。
    ///
    /// 「再製」與「貼上」走的是同一個函式，差別只在平台層給不給偏移量：
    /// 再製給一個小偏移（不然新的那一份完全蓋在原本上面，看起來什麼也
    /// 沒發生），貼上通常給 0 或使用者指定的位置。
    pub fn lasso_paste(
        &self,
        page_id: String,
        strokes: Vec<FullStroke>,
        dx: f32,
        dy: f32,
    ) -> Result<Vec<String>, FfiError> {
        let page = parse_uuid(&page_id)?;
        let mut created = Vec::with_capacity(strokes.len());
        for source in strokes {
            // **新的 id，不是原本那個。** 沿用原 id 的話這是一次「更新」
            // 而不是「新增」，同步到另一台裝置會變成把原本那一筆搬走。
            let id = Uuid::now_v7();
            let stroke = padnote_ink::Stroke {
                id,
                started_at: NotebookTime::ZERO,
                tool: source.tool.into(),
                color_rgba8: to_rgba(&source.color_rgba),
                base_width: source.base_width,
                points: source
                    .points
                    .into_iter()
                    .map(|p| {
                        let mut point = to_ink_point(p);
                        point.x += dx;
                        point.y += dy;
                        point
                    })
                    .collect(),
            };
            self.lock().add_stroke(page, stroke)?;
            created.push(id.to_string());
        }
        Ok(created)
    }

    /// 把一組筆畫原地平移。拖曳選取範圍時用。
    ///
    /// 做法是「刪掉再以新座標加回去」—— oplog 沒有「移動筆畫」這種操作，
    /// 而為了拖曳加一種新的 op 會讓每一個讀得懂舊格式的版本都看不懂它。
    /// 代價是 id 會變，所以回傳新的 id，呼叫端要換掉手上那一份選取。
    pub fn lasso_translate(
        &self,
        page_id: String,
        stroke_ids: Vec<String>,
        dx: f32,
        dy: f32,
    ) -> Result<Vec<String>, FfiError> {
        let copied = self.lasso_copy(page_id.clone(), stroke_ids.clone())?;
        self.lasso_delete(page_id.clone(), stroke_ids)?;
        self.lasso_paste(page_id, copied, dx, dy)
    }

    // ---- 文字 ----

    pub fn add_text(
        &self,
        page_id: String,
        content: String,
        style: BlockStyle,
    ) -> Result<String, FfiError> {
        let page = parse_uuid(&page_id)?;
        Ok(self
            .lock()
            .add_text_block(page, &content, style.into())?
            .to_string())
    }

    /// 在文字區塊的第 `index` 個**字元**（非位元組）位置插入文字。
    ///
    /// 用字元索引是必要的：UTF-16 或位元組索引都會把中文與 emoji 切壞。
    pub fn insert_text(&self, block_id: String, index: u32, text: String) -> Result<(), FfiError> {
        let block = parse_uuid(&block_id)?;
        self.lock().insert_text(block, index as usize, &text)?;
        Ok(())
    }

    pub fn delete_text(&self, block_id: String, index: u32, count: u32) -> Result<(), FfiError> {
        let block = parse_uuid(&block_id)?;
        self.lock()
            .delete_text(block, index as usize, count as usize)?;
        Ok(())
    }

    pub fn block_text(&self, block_id: String) -> Result<Option<String>, FfiError> {
        Ok(self.lock().block_text(parse_uuid(&block_id)?))
    }

    /// 設定頁面尺寸（點）。
    ///
    /// Kairumo 的畫布可以向下延長，使用者拉長過的那一頁若沒有把高度寫進檔案，
    /// 另一個平台打開會變回預設高度 —— 內容看起來像被截掉了。
    pub fn set_page_size(&self, page_id: String, width: f32, height: f32) -> Result<(), FfiError> {
        self.lock()
            .set_page_size(parse_uuid(&page_id)?, width, height)?;
        Ok(())
    }

    /// 頁面尺寸 `[width, height]`（點）。查無此頁時回傳 `None`。
    pub fn page_size(&self, page_id: String) -> Result<Option<Vec<f32>>, FfiError> {
        let page = parse_uuid(&page_id)?;
        Ok(self
            .lock()
            .notebook()
            .page(page)
            .map(|p| vec![p.size.0, p.size.1]))
    }

    /// 這一頁所有文字區塊的 id，依加入順序。
    ///
    /// 沒有這個出口，平台層拿得到某個區塊的內容與外觀，卻**列不出有哪些區塊**
    /// —— 也就打不開別的裝置寫進來的文字方塊。
    pub fn text_block_ids(&self, page_id: String) -> Result<Vec<String>, FfiError> {
        let page = parse_uuid(&page_id)?;
        let guard = self.lock();
        Ok(guard
            .notebook()
            .page(page)
            .map(|p| {
                p.blocks()
                    .iter()
                    .filter(|b| matches!(b.kind, padnote_doc::BlockKind::Text { .. }))
                    .map(|b| b.id.to_string())
                    .collect()
            })
            .unwrap_or_default())
    }

    /// 設定筆記本層級的平台中繼資料（平台自訂的 JSON）。
    ///
    /// 核心不解讀內容。放的是「一本筆記的屬性、但核心沒有對應概念」的東西：
    /// 版面樣板、所屬資料夾、討論圖釘、建立時間。少了它，同一本筆記在另一台
    /// 裝置上會變回空白樣板、掉出資料夾、圖釘整串消失。
    pub fn set_notebook_meta(&self, json: String) -> Result<(), FfiError> {
        self.lock().set_notebook_meta(&json)?;
        Ok(())
    }

    /// 筆記本層級的中繼資料 JSON。未設定時回傳 `None`。
    pub fn notebook_meta(&self) -> Option<String> {
        self.lock().notebook().meta.clone()
    }

    /// 區塊引用的 blob 雜湊。沒有 blob 的區塊（文字、表格）回傳 `None`。
    pub fn block_blob_id(&self, block_id: String) -> Result<Option<String>, FfiError> {
        let block = parse_uuid(&block_id)?;
        let guard = self.lock();
        Ok(guard
            .notebook()
            .pages()
            .iter()
            .flat_map(|p| p.blocks())
            .find(|b| b.id == block)
            .and_then(|b| b.referenced_blob())
            .map(|blob| blob.to_string()))
    }

    /// 取回 blob 的位元組。
    ///
    /// 沒有這一支，圖片就是**單向**的：位元組進得去、出不來，另一台裝置打得開
    /// 筆記卻拿不到圖，畫面上會是一格一格的空白。
    pub fn blob_bytes(&self, blob_id: String) -> Result<Vec<u8>, FfiError> {
        let id = padnote_storage::BlobId::from_hex(&blob_id)
            .ok_or_else(|| FfiError::Failed(format!("blob id 無法解析：{blob_id}")))?;
        self.lock()
            .package()
            .blobs()
            .get(id)
            .map_err(|e| FfiError::Failed(e.to_string()))
    }

    /// 這一頁所有圖片區塊的 id，依加入順序。
    ///
    /// 沒有這個出口，圖表就是**單向**的：寫得進 `.padnote`，另一台裝置卻列不出
    /// 有哪些圖片區塊，也就找不到它的圖表設定 —— 使用者會看到一張改不動的圖，
    /// 而設定其實好端端地躺在檔案裡。
    pub fn image_block_ids(&self, page_id: String) -> Result<Vec<String>, FfiError> {
        let page = parse_uuid(&page_id)?;
        let guard = self.lock();
        Ok(guard
            .notebook()
            .page(page)
            .map(|p| {
                p.blocks()
                    .iter()
                    .filter(|b| matches!(b.kind, padnote_doc::BlockKind::Image { .. }))
                    .map(|b| b.id.to_string())
                    .collect()
            })
            .unwrap_or_default())
    }

    /// 圖片區塊的尺寸 `[width, height]`。非圖片區塊回傳 `None`。
    pub fn image_block_size(&self, block_id: String) -> Result<Option<Vec<f32>>, FfiError> {
        let block = parse_uuid(&block_id)?;
        let guard = self.lock();
        Ok(guard
            .notebook()
            .pages()
            .iter()
            .flat_map(|p| p.blocks())
            .find(|b| b.id == block)
            .and_then(|b| match b.kind {
                padnote_doc::BlockKind::Image { width, height, .. } => Some(vec![width, height]),
                _ => None,
            }))
    }

    /// 設定區塊的外觀（平台自訂的 JSON）。
    ///
    /// 核心不解讀內容。兩個平台用同一組鍵名（`format-spec.md` §6.2），
    /// 這樣文字方塊的顏色、邊框與段落設定才跨得過平台 —— 否則使用者在 iPad 上
    /// 設成透明底、加了行距，換到 Android 打開會變回白底無行距。
    pub fn set_block_appearance(&self, block_id: String, json: String) -> Result<(), FfiError> {
        self.lock()
            .set_block_appearance(parse_uuid(&block_id)?, &json)?;
        Ok(())
    }

    /// 區塊的外觀 JSON。未設定時回傳 `None`。
    pub fn block_appearance(&self, block_id: String) -> Result<Option<String>, FfiError> {
        let block = parse_uuid(&block_id)?;
        let guard = self.lock();
        Ok(guard
            .notebook()
            .pages()
            .iter()
            .flat_map(|p| p.blocks())
            .find(|b| b.id == block)
            .and_then(|b| b.appearance.clone()))
    }

    /// 設定區塊在頁面上的絕對座標。
    pub fn set_block_position(&self, block_id: String, x: f32, y: f32) -> Result<(), FfiError> {
        self.lock()
            .set_block_position(parse_uuid(&block_id)?, x, y)?;
        Ok(())
    }

    /// 區塊的絕對座標 `[x, y]`。隨文流排版（未定位）或查無此區塊時回傳 `None`。
    pub fn block_position(&self, block_id: String) -> Result<Option<Vec<f32>>, FfiError> {
        let block = parse_uuid(&block_id)?;
        let guard = self.lock();
        Ok(guard
            .notebook()
            .pages()
            .iter()
            .flat_map(|p| p.blocks())
            .find(|b| b.id == block)
            .and_then(|b| b.position)
            .map(|(x, y)| vec![x, y]))
    }

    pub fn remove_block(&self, block_id: String) -> Result<(), FfiError> {
        self.lock().remove_block(parse_uuid(&block_id)?)?;
        Ok(())
    }

    /// 插入圖片。`blob` 為內容定址雜湊。
    pub fn add_image(
        &self,
        page_id: String,
        blob: String,
        width: f32,
        height: f32,
    ) -> Result<String, FfiError> {
        let page = parse_uuid(&page_id)?;
        Ok(self
            .lock()
            .add_image_block(page, &blob, width, height)?
            .to_string())
    }

    /// 把位元組存成內容定址 blob，回傳其雜湊。供 `add_image` 使用。
    pub fn put_blob(&self, bytes: Vec<u8>) -> Result<String, FfiError> {
        self.lock()
            .package()
            .blobs()
            .put(&bytes)
            .map(|id| id.to_string())
            .map_err(|e| FfiError::Failed(e.to_string()))
    }

    // ---- 錄音 ----

    pub fn start_recording(&self) -> Result<String, FfiError> {
        Ok(self.lock().start_recording()?.to_string())
    }

    pub fn stop_recording(&self) -> Result<String, FfiError> {
        Ok(self.lock().stop_recording()?.to_string())
    }

    pub fn is_recording(&self) -> bool {
        matches!(
            self.lock().recording_state(),
            RecordingState::Recording { .. }
        )
    }

    /// 餵入麥克風取樣（16 kHz 單聲道 f32）。
    ///
    /// **音檔在此同步落地**。轉錄只是把語音段入列，由背景 worker 取用 ——
    /// 因此這個呼叫的耗時與 ASR 模型無關，不會拖累錄音執行緒。
    pub fn feed_audio(&self, pcm_16k_mono: Vec<f32>) -> Result<RecordingStats, FfiError> {
        let mut guard = self.lock();
        let out = guard.feed_audio(&pcm_16k_mono)?;
        Ok(RecordingStats {
            frames_written: out.frames_written,
            segments_queued: out.segments_queued as u32,
            segments_dropped: out.segments_dropped,
            recorded_us: guard.recorded_audio_us(),
            backlog_us: guard.transcription_backlog_us(),
        })
    }

    /// 設定 Silero VAD 模型路徑（S-26）。下一次開始錄音時生效。
    ///
    /// 模型由 `padnote-models` 的下載器取得（`silero-vad-v4`，1.8 MB）。
    pub fn set_vad_model(&self, path: String) {
        self.lock().set_vad_model(path);
    }

    /// 目前是否使用神經網路 VAD。
    ///
    /// `false` 代表退回能量門檻法 —— 實測在白噪音下 **100 個音框全部誤判為
    /// 語音**（Silero 為 0 個）。UI 應提示使用者下載模型以改善分段品質。
    pub fn uses_neural_vad(&self) -> bool {
        self.lock().uses_neural_vad()
    }

    /// 已寫入音檔的時長（微秒）。停止錄音後仍可查。
    pub fn recorded_audio_us(&self) -> u64 {
        self.lock().recorded_audio_us()
    }

    /// 轉錄落後的音訊時長。UI 顯示「轉錄落後 N 秒」。
    pub fn transcription_backlog_us(&self) -> u64 {
        self.lock().transcription_backlog_us()
    }

    /// 寫入一批轉錄結果。
    ///
    /// 平台層從背景 worker 取得結果後呼叫。時間戳必須已經在筆記本時間軸上。
    pub fn add_transcript(
        &self,
        page_id: String,
        session_id: String,
        words: Vec<TranscriptWordInput>,
    ) -> Result<String, FfiError> {
        let (page, session) = (parse_uuid(&page_id)?, parse_uuid(&session_id)?);
        let words = words
            .into_iter()
            .map(|w| TranscriptWord {
                text: w.text,
                start: NotebookTime::from_micros(w.start_us),
                end: NotebookTime::from_micros(w.end_us),
                confidence: w.confidence,
            })
            .collect();
        Ok(self
            .lock()
            .add_transcript(page, session, words)?
            .to_string())
    }

    /// **功能 C1**：某個筆記本時刻對應的錄音位置。
    ///
    /// 使用者點一筆畫時，平台層傳入該筆畫的 `started_at_us`。
    pub fn playback_at(&self, notebook_time_us: u64) -> Option<PlaybackPosition> {
        self.lock()
            .timeline()
            .playback_at(NotebookTime::from_micros(notebook_time_us))
            .map(|(s, offset)| PlaybackPosition {
                media_path: s.media_path.clone(),
                offset_us: offset.as_micros(),
            })
    }

    pub fn recorded_duration_us(&self) -> u64 {
        self.lock().timeline().recorded_duration().as_micros()
    }

    // ---- 搜尋與匯出 ----

    pub fn search(&self, query: String, limit: u32) -> Vec<SearchResult> {
        self.lock()
            .search(&query, limit as usize)
            .into_iter()
            .map(|h| SearchResult {
                page_id: h.doc.page,
                block_id: h.doc.block,
                source: source_name(h.source).into(),
                score: h.score,
                snippet: h.snippet,
            })
            .collect()
    }

    /// 手寫辨識完成後回填索引（辨識是非同步的，故獨立於 `add_stroke`）。
    pub fn index_handwriting(
        &self,
        page_id: String,
        stroke_id: String,
        text: String,
    ) -> Result<(), FfiError> {
        let (page, stroke) = (parse_uuid(&page_id)?, parse_uuid(&stroke_id)?);
        self.lock().index_handwriting(page, stroke, &text);
        Ok(())
    }

    // ---- 物件（S-38 / ADR-0010）----

    /// 把筆畫收成一個物件，讓它能被群組與變換。
    pub fn create_stroke_object(
        &self,
        page_id: String,
        stroke_ids: Vec<String>,
    ) -> Result<String, FfiError> {
        let page = parse_uuid(&page_id)?;
        let strokes = stroke_ids
            .iter()
            .map(|s| parse_uuid(s))
            .collect::<Result<Vec<_>, _>>()?;
        Ok(self.lock().create_stroke_object(page, strokes)?.to_string())
    }

    /// 插入一個原生形狀物件（S-52）。幾何外框以頁面座標表示。
    // UniFFI 的公開介面：改簽章等於同時改掉 Swift 與 Kotlin 兩邊的產生碼。
    #[allow(clippy::too_many_arguments)]
    pub fn insert_shape(
        &self,
        page_id: String,
        kind: FfiShapeKind,
        min_x: f32,
        min_y: f32,
        max_x: f32,
        max_y: f32,
        corner_radius: f32,
        text: String,
    ) -> Result<String, FfiError> {
        let page = parse_uuid(&page_id)?;
        Ok(self
            .lock()
            .insert_shape(
                page,
                ShapeObject {
                    kind: to_doc_shape_kind(kind),
                    bounds: ObjectRect {
                        min_x,
                        min_y,
                        max_x,
                        max_y,
                    },
                    corner_radius,
                    text,
                },
            )?
            .to_string())
    }

    /// 插入依附於兩個物件的連接線（S-52）。
    // UniFFI 的公開介面：改簽章等於同時改掉 Swift 與 Kotlin 兩邊的產生碼。
    #[allow(clippy::too_many_arguments)]
    pub fn insert_connection(
        &self,
        page_id: String,
        from_object_id: String,
        to_object_id: String,
        from_anchor: FfiAnchor,
        to_anchor: FfiAnchor,
        route: FfiRouteStyle,
        start_cap: FfiEndCap,
        end_cap: FfiEndCap,
        label: String,
    ) -> Result<String, FfiError> {
        let page = parse_uuid(&page_id)?;
        Ok(self
            .lock()
            .insert_connection(
                page,
                ConnectionObject {
                    from: parse_uuid(&from_object_id)?,
                    to: parse_uuid(&to_object_id)?,
                    from_anchor: to_doc_anchor(from_anchor),
                    to_anchor: to_doc_anchor(to_anchor),
                    route: to_doc_route_style(route),
                    start_cap: to_doc_end_cap(start_cap),
                    end_cap: to_doc_end_cap(end_cap),
                    label,
                },
            )?
            .to_string())
    }

    pub fn group_objects(
        &self,
        page_id: String,
        object_ids: Vec<String>,
    ) -> Result<String, FfiError> {
        let page = parse_uuid(&page_id)?;
        let members = object_ids
            .iter()
            .map(|s| parse_uuid(s))
            .collect::<Result<Vec<_>, _>>()?;
        Ok(self.lock().group_objects(page, members)?.to_string())
    }

    /// 移除一個物件。
    ///
    /// 平台原本插得進形狀卻刪不掉它 —— 使用者插錯一個形狀就永遠留在那裡了。
    pub fn remove_object(&self, object_id: String) -> Result<(), FfiError> {
        self.lock().remove_object(parse_uuid(&object_id)?)?;
        Ok(())
    }

    /// 解散群組。成員的位置不會跳動 —— 群組的變換會往下傳給它們。
    pub fn ungroup(&self, object_id: String) -> Result<(), FfiError> {
        self.lock().ungroup(parse_uuid(&object_id)?)?;
        Ok(())
    }

    /// 平移物件。**不改寫任何取樣點**（ADR-0010）。
    pub fn translate_object(&self, object_id: String, dx: f32, dy: f32) -> Result<(), FfiError> {
        self.apply_transform(&object_id, Affine2::translate(dx, dy))
    }

    /// 以 `(cx, cy)` 為中心縮放。以原點縮放會讓物件同時飛走。
    pub fn scale_object(
        &self,
        object_id: String,
        sx: f32,
        sy: f32,
        cx: f32,
        cy: f32,
    ) -> Result<(), FfiError> {
        self.apply_transform(&object_id, Affine2::scale_around(sx, sy, cx, cy))
    }

    /// 以 `(cx, cy)` 為中心旋轉（弧度）。
    pub fn rotate_object(
        &self,
        object_id: String,
        radians: f32,
        cx: f32,
        cy: f32,
    ) -> Result<(), FfiError> {
        self.apply_transform(&object_id, Affine2::rotate_around(radians, cx, cy))
    }

    // ---- 堆疊順序（S-46，需求 1）----

    /// 移到同層最上層。
    pub fn bring_to_front(&self, page_id: String, object_id: String) -> Result<(), FfiError> {
        let (page, id) = (parse_uuid(&page_id)?, parse_uuid(&object_id)?);
        self.lock().bring_to_front(page, id)?;
        Ok(())
    }

    /// 移到同層最下層。
    pub fn send_to_back(&self, object_id: String) -> Result<(), FfiError> {
        self.lock().send_to_back(parse_uuid(&object_id)?)?;
        Ok(())
    }

    /// 上移一層。
    pub fn bring_forward(&self, page_id: String, object_id: String) -> Result<(), FfiError> {
        let (page, id) = (parse_uuid(&page_id)?, parse_uuid(&object_id)?);
        self.lock().bring_forward(page, id)?;
        Ok(())
    }

    /// 下移一層。
    pub fn send_backward(&self, page_id: String, object_id: String) -> Result<(), FfiError> {
        let (page, id) = (parse_uuid(&page_id)?, parse_uuid(&object_id)?);
        self.lock().send_backward(page, id)?;
        Ok(())
    }

    /// 物件在同層中的位置。
    pub fn z_index(&self, page_id: String, object_id: String) -> Result<Option<u32>, FfiError> {
        let (page, id) = (parse_uuid(&page_id)?, parse_uuid(&object_id)?);
        Ok(self.lock().z_index(page, id).map(|i| i as u32))
    }

    /// 整頁的繪製順序：由下而上的 `(物件 id, 世界變換)`。
    ///
    /// 這是渲染要的**唯一**順序來源 —— 平台層照著畫就對了，
    /// 不必自己重建樹狀結構。
    pub fn draw_order(&self, page_id: String) -> Result<Vec<DrawItem>, FfiError> {
        let page = parse_uuid(&page_id)?;
        let guard = self.lock();
        Ok(guard
            .objects(page)
            .map(|tree| {
                tree.draw_order()
                    .into_iter()
                    .map(|(id, t)| DrawItem {
                        object_id: id.to_string(),
                        transform: vec![t.a, t.b, t.c, t.d, t.tx, t.ty],
                    })
                    .collect()
            })
            .unwrap_or_default())
    }

    // ---- 表格（S-48，需求 2）----

    /// 插入表格。`cells` 以列為主展開，不足補空白。
    pub fn insert_table(
        &self,
        page_id: String,
        rows: u32,
        cols: u32,
        cells: Vec<String>,
        header_row: bool,
    ) -> Result<String, FfiError> {
        let page = parse_uuid(&page_id)?;
        Ok(self
            .lock()
            .insert_table(page, rows, cols, cells, header_row)?
            .to_string())
    }

    /// 改寫單一儲存格。
    pub fn set_table_cell(
        &self,
        block_id: String,
        row: u32,
        col: u32,
        text: String,
    ) -> Result<(), FfiError> {
        self.lock()
            .set_table_cell(parse_uuid(&block_id)?, row, col, &text)?;
        Ok(())
    }

    pub fn insert_table_row(
        &self,
        block_id: String,
        index: u32,
        cells: Vec<String>,
    ) -> Result<(), FfiError> {
        self.lock()
            .insert_table_row(parse_uuid(&block_id)?, index, cells)?;
        Ok(())
    }

    pub fn delete_table_row(&self, block_id: String, index: u32) -> Result<(), FfiError> {
        self.lock()
            .delete_table_row(parse_uuid(&block_id)?, index)?;
        Ok(())
    }

    pub fn insert_table_column(
        &self,
        block_id: String,
        index: u32,
        cells: Vec<String>,
    ) -> Result<(), FfiError> {
        self.lock()
            .insert_table_column(parse_uuid(&block_id)?, index, cells)?;
        Ok(())
    }

    pub fn delete_table_column(&self, block_id: String, index: u32) -> Result<(), FfiError> {
        self.lock()
            .delete_table_column(parse_uuid(&block_id)?, index)?;
        Ok(())
    }

    pub fn merge_table_cells(
        &self,
        block_id: String,
        row: u32,
        col: u32,
        row_span: u32,
        col_span: u32,
    ) -> Result<(), FfiError> {
        self.lock()
            .merge_table_cells(parse_uuid(&block_id)?, row, col, row_span, col_span)?;
        Ok(())
    }

    pub fn unmerge_table_cell(&self, block_id: String, row: u32, col: u32) -> Result<(), FfiError> {
        self.lock()
            .unmerge_table_cell(parse_uuid(&block_id)?, row, col)?;
        Ok(())
    }

    /// 物件在頁面上的累積變換，回傳 `[a, b, c, d, tx, ty]`。
    pub fn object_transform(
        &self,
        page_id: String,
        object_id: String,
    ) -> Result<Vec<f32>, FfiError> {
        let (page, object) = (parse_uuid(&page_id)?, parse_uuid(&object_id)?);
        let guard = self.lock();
        let t = guard
            .objects(page)
            .map_or(Affine2::IDENTITY, |tree| tree.world_transform(object));
        Ok(vec![t.a, t.b, t.c, t.d, t.tx, t.ty])
    }

    // ---- 嵌入文件（S-41 / ADR-0009）----

    /// 匯入外部文件。
    ///
    /// 可編輯格式（docx／xlsx／md／json）會解析成**原生區塊**；
    /// 僅預覽格式（pptx／pdf）建立嵌入區塊。
    /// **原始檔一律保留** —— 解析必然失真。
    pub fn import_embedded(&self, page_id: String, path: String) -> Result<String, FfiError> {
        let page = parse_uuid(&page_id)?;
        Ok(self.lock().import_embedded(page, path)?.to_string())
    }

    /// 匯入 Markdown。回傳新建立的頁面 id。
    ///
    /// **加進來而非取代** —— 按錯不該弄丟既有筆記。
    pub fn import_markdown(&self, text: String) -> Result<Vec<String>, FfiError> {
        Ok(self
            .lock()
            .import_markdown(&text)?
            .into_iter()
            .map(|id| id.to_string())
            .collect())
    }

    /// 匯入 JSON。Schema 見 `padnote_export::from_json`。
    pub fn import_json(&self, text: String) -> Result<Vec<String>, FfiError> {
        Ok(self
            .lock()
            .import_json(&text)?
            .into_iter()
            .map(|id| id.to_string())
            .collect())
    }

    pub fn export_markdown(&self) -> Result<String, FfiError> {
        Ok(self.lock().export_markdown()?)
    }

    /// 匯出整份筆記本為 PDF 位元組流（工作項 S-18 / S-43）。
    pub fn export_pdf(&self) -> Result<Vec<u8>, FfiError> {
        Ok(self
            .lock()
            .export_pdf(&padnote_export::PdfExportOptions::default())?)
    }

    /// 匯出指定頁面為單頁 PDF 位元組流。
    pub fn export_page_pdf(&self, page_id: String) -> Result<Vec<u8>, FfiError> {
        let page = parse_uuid(&page_id)?;
        Ok(self.lock().export_page_pdf(page)?)
    }

    /// 匯出指定頁面為高解析度 PNG 圖片位元組流。`scale` 為縮放倍率（如 2.0 代表 @2x Retina）。
    pub fn export_page_png(&self, page_id: String, scale: f32) -> Result<Vec<u8>, FfiError> {
        let page = parse_uuid(&page_id)?;
        Ok(self.lock().export_page_png(page, scale)?)
    }

    /// 產出列印專用資料（工作項 S-55）。`page_id` 為 `None` 時列印整份筆記本。
    pub fn print_data(&self, page_id: Option<String>) -> Result<Vec<u8>, FfiError> {
        let page = match page_id {
            Some(s) if !s.trim().is_empty() => Some(parse_uuid(&s)?),
            _ => None,
        };
        Ok(self.lock().print_data(page)?)
    }

    // ---- 引擎與權限中心（功能 I1）----

    /// 平台層回報某項能力的狀態。
    ///
    /// `capability`：`microphone` / `speech` / `handwriting` / `asr_model` /
    /// `llm_model` / `local_folder` / `icloud` / `google_drive`
    /// `state`：`ready` / `needs_permission` / `denied` / `needs_download` /
    /// `not_configured` / `unsupported`
    pub fn report_capability(&self, capability: String, state: String, size_bytes: u64) {
        let Some(cap) = parse_capability(&capability) else {
            return;
        };
        let status = match state.as_str() {
            "ready" => Status::Ready,
            "needs_permission" => Status::NeedsPermission,
            "denied" => Status::PermissionDenied,
            "needs_download" => Status::NeedsDownload { size_bytes },
            "not_configured" => Status::NotConfigured,
            _ => Status::Unsupported,
        };
        self.setup.lock().expect("setup 鎖中毒").set(cap, status);
    }

    /// 各功能目前能不能用、不能的話缺什麼。設定頁直接畫這個列表。
    pub fn feature_status(&self) -> Vec<FeatureStatus> {
        self.setup
            .lock()
            .expect("setup 鎖中毒")
            .all_readiness()
            .into_iter()
            .map(|r| FeatureStatus {
                feature: feature_name(r.feature).into(),
                ready: r.ready,
                explanation: r.explanation(),
            })
            .collect()
    }

    /// 待下載的總位元組數。空間不足時要先警告使用者。
    pub fn pending_download_bytes(&self) -> u64 {
        self.setup
            .lock()
            .expect("setup 鎖中毒")
            .total_download_bytes()
    }
}

impl PadnoteSession {
    fn apply_transform(&self, object_id: &str, t: Affine2) -> Result<(), FfiError> {
        self.lock().transform_object(parse_uuid(object_id)?, t)?;
        Ok(())
    }

    fn wrap(session: NotebookSession) -> Self {
        Self {
            inner: Mutex::new(session),
            setup: Mutex::new(SetupCenter::new("paraformer-zh", "qwen3-4b-instruct-q4")),
        }
    }

    pub(crate) fn lock(&self) -> std::sync::MutexGuard<'_, NotebookSession> {
        // 鎖中毒代表其他執行緒 panic 過。繼續用髒狀態比明確崩掉更危險。
        self.inner.lock().expect("session 鎖中毒")
    }
}

// ---- 自由函式 ----

/// 本 build 支援的 `.padnote` 格式版本。
#[uniffi::export]
pub fn spec_version() -> u32 {
    crate::SPEC_VERSION
}

/// 這份筆記本能不能用目前的版本開啟（format-spec §8）。
#[uniffi::export]
pub fn can_open(spec_version: u32, min_reader_version: u32) -> bool {
    crate::can_open(spec_version, min_reader_version)
}

// ---- 協同訊息加密（工作包 WP3）----
//
// 為什麼放在核心：Apple 版用 CryptoKit 的 AES-256-GCM，Android 若自己再寫一份，
// 兩邊要在同一個房間裡互相解得開就得逐位元組對齊 —— 那是個安靜失敗的來源。
// 這裡讓所有新平台共用同一份實作，格式與已上線的 Apple 版完全相同
// （由 padnote-crypto 的 cryptokit_interop 測試把關）。

/// 產生新的協同房間金鑰，回傳 base64（就是邀請連結裡帶的那一段）。
#[uniffi::export]
pub fn session_key_generate() -> Result<String, FfiError> {
    padnote_crypto::session::SessionKey::generate()
        .map(|k| k.to_base64())
        .map_err(|e| FfiError::Failed(e.to_string()))
}

/// 用房間金鑰加密一段訊息，回傳 base64 密文。
#[uniffi::export]
pub fn session_seal(key_base64: String, plaintext: Vec<u8>) -> Result<String, FfiError> {
    let key = padnote_crypto::session::SessionKey::from_base64(&key_base64)
        .map_err(|e| FfiError::Failed(e.to_string()))?;
    key.seal_to_base64(&plaintext)
        .map_err(|e| FfiError::Failed(e.to_string()))
}

/// 解開 base64 密文。金鑰不符或內容被竄改都會失敗，不會回傳可疑內容。
#[uniffi::export]
pub fn session_open(key_base64: String, sealed_base64: String) -> Result<Vec<u8>, FfiError> {
    let key = padnote_crypto::session::SessionKey::from_base64(&key_base64)
        .map_err(|e| FfiError::Failed(e.to_string()))?;
    key.open_from_base64(&sealed_base64)
        .map_err(|e| FfiError::Failed(e.to_string()))
}

// ---- 轉換輔助 ----

fn to_full_stroke(s: Stroke) -> FullStroke {
    FullStroke {
        id: s.id.to_string(),
        started_at_us: s.started_at.as_micros(),
        tool: s.tool.into(),
        color_rgba: s.color_rgba8.to_vec(),
        base_width: s.base_width,
        points: s.points.into_iter().map(from_ink_point).collect(),
    }
}

fn from_ink_point(p: InkPoint) -> StrokePoint {
    StrokePoint {
        x: p.x,
        y: p.y,
        pressure: p.pressure,
        tilt: p.tilt,
        azimuth: p.azimuth,
        dt_us: p.dt_us,
    }
}

fn to_ink_point(p: StrokePoint) -> InkPoint {
    InkPoint {
        x: p.x,
        y: p.y,
        pressure: p.pressure,
        tilt: p.tilt,
        azimuth: p.azimuth,
        dt_us: p.dt_us,
    }
}

/// 不足 4 個位元組時補為不透明黑色，而不是 panic —— FFI 輸入不可信。
/// 一條路徑的取樣點是否**整條**都在套索多邊形裡。
///
/// # 為什麼要有這個「散裝」版本
///
/// Android 的筆畫寫在核心裡，所以那邊直接用
/// [`PadnoteSession::lasso_select`]。**Apple 不是**：編輯中的真相來源是
/// PencilKit 的 `PKDrawing`，核心 session 只有在匯出／匯入時才會被寫到。
/// 要讓兩邊的「圈到算不算選到」是同一條規則，只能把規則本身開出來，
/// 讓 Apple 拿 `PKStroke` 的點來問。
///
/// 兩個參數都是扁平的 `[x0, y0, x1, y1, …]`。
#[uniffi::export]
pub fn lasso_encloses(polygon: Vec<f32>, points: Vec<f32>) -> bool {
    let poly = to_polygon(&polygon);
    let pts = to_polygon(&points);
    if poly.len() < 3 || pts.is_empty() {
        return false;
    }
    // 借用 Stroke 的判定，確保與 lasso_select 走的是同一段程式碼 ——
    // 各寫一份的話，兩邊遲早會在邊界條件上分岔。
    let stroke = padnote_ink::Stroke {
        id: Uuid::from_bytes([0; 16]),
        started_at: NotebookTime::ZERO,
        tool: padnote_ink::Tool::BallPoint,
        color_rgba8: [0, 0, 0, 255],
        base_width: 1.0,
        points: pts
            .into_iter()
            .map(|(x, y)| InkPoint::new(x, y, 1.0, 0))
            .collect(),
    };
    stroke.is_enclosed_by_polygon(&poly)
}

/// 扁平的 `[x0, y0, x1, y1, …]` 轉成點的陣列。
///
/// 長度是奇數時**丟掉最後那個孤兒座標**，不要當成 `(x, 0)` ——
/// 那會在多邊形上憑空多一個貼著上緣的頂點，選取範圍整個歪掉。
fn to_polygon(flat: &[f32]) -> Vec<(f32, f32)> {
    flat.as_chunks::<2>()
        .0
        .iter()
        .map(|c| (c[0], c[1]))
        .collect()
}

fn to_rgba(v: &[u8]) -> [u8; 4] {
    match v.len() {
        4 => [v[0], v[1], v[2], v[3]],
        3 => [v[0], v[1], v[2], 255],
        _ => [0, 0, 0, 255],
    }
}

/// 從文件模型的形狀種類轉回 FFI 的。
///
/// 讀回形狀時需要它 —— 少了反向對應，`insert_shape` 寫得進去的東西就讀不回來。
pub(crate) fn from_doc_shape_kind(k: ShapeKind) -> FfiShapeKind {
    match k {
        ShapeKind::Rectangle => FfiShapeKind::Rectangle,
        ShapeKind::RoundedRectangle => FfiShapeKind::RoundedRectangle,
        ShapeKind::Ellipse => FfiShapeKind::Ellipse,
        ShapeKind::Triangle => FfiShapeKind::Triangle,
        ShapeKind::Diamond => FfiShapeKind::Diamond,
        ShapeKind::Pentagon => FfiShapeKind::Pentagon,
        ShapeKind::Hexagon => FfiShapeKind::Hexagon,
        ShapeKind::Star => FfiShapeKind::Star,
        ShapeKind::Process => FfiShapeKind::Process,
        ShapeKind::Decision => FfiShapeKind::Decision,
        ShapeKind::Terminator => FfiShapeKind::Terminator,
        ShapeKind::Data => FfiShapeKind::Data,
        ShapeKind::Document => FfiShapeKind::Document,
        ShapeKind::Database => FfiShapeKind::Database,
        ShapeKind::Preparation => FfiShapeKind::Preparation,
        ShapeKind::ManualInput => FfiShapeKind::ManualInput,
        ShapeKind::Connector => FfiShapeKind::Connector,
        ShapeKind::ManualOperation => FfiShapeKind::ManualOperation,
        ShapeKind::Delay => FfiShapeKind::Delay,
        ShapeKind::StoredData => FfiShapeKind::StoredData,
        ShapeKind::Merge => FfiShapeKind::Merge,
        ShapeKind::Extract => FfiShapeKind::Extract,
        ShapeKind::OffPageConnector => FfiShapeKind::OffPageConnector,
        ShapeKind::Display => FfiShapeKind::Display,
        ShapeKind::PunchedTape => FfiShapeKind::PunchedTape,
        ShapeKind::PunchedCard => FfiShapeKind::PunchedCard,
        ShapeKind::Collate => FfiShapeKind::Collate,
        ShapeKind::RightTriangle => FfiShapeKind::RightTriangle,
        ShapeKind::Parallelogram => FfiShapeKind::Parallelogram,
        ShapeKind::Trapezoid => FfiShapeKind::Trapezoid,
        ShapeKind::Heptagon => FfiShapeKind::Heptagon,
        ShapeKind::Octagon => FfiShapeKind::Octagon,
        ShapeKind::Cross => FfiShapeKind::Cross,
        ShapeKind::Chevron => FfiShapeKind::Chevron,
        ShapeKind::ArrowBlockRight => FfiShapeKind::ArrowBlockRight,
        ShapeKind::ArrowBlockLeft => FfiShapeKind::ArrowBlockLeft,
        ShapeKind::ArrowBlockUp => FfiShapeKind::ArrowBlockUp,
        ShapeKind::ArrowBlockDown => FfiShapeKind::ArrowBlockDown,
        ShapeKind::Cloud => FfiShapeKind::Cloud,
        ShapeKind::Heart => FfiShapeKind::Heart,
        ShapeKind::Bolt => FfiShapeKind::Bolt,
        ShapeKind::Moon => FfiShapeKind::Moon,
        ShapeKind::Teardrop => FfiShapeKind::Teardrop,
        ShapeKind::LShape => FfiShapeKind::LShape,
        ShapeKind::Star4 => FfiShapeKind::Star4,
        ShapeKind::Star6 => FfiShapeKind::Star6,
        ShapeKind::Star8 => FfiShapeKind::Star8,
        ShapeKind::Sun => FfiShapeKind::Sun,
        ShapeKind::Banner => FfiShapeKind::Banner,
        ShapeKind::SpeechBubble => FfiShapeKind::SpeechBubble,
        ShapeKind::Plaque => FfiShapeKind::Plaque,
        ShapeKind::Pie => FfiShapeKind::Pie,
        ShapeKind::Line => FfiShapeKind::Line,
        ShapeKind::Arrow => FfiShapeKind::Arrow,
        ShapeKind::DoubleArrow => FfiShapeKind::DoubleArrow,
    }
}

fn to_doc_shape_kind(k: FfiShapeKind) -> ShapeKind {
    match k {
        FfiShapeKind::Rectangle => ShapeKind::Rectangle,
        FfiShapeKind::RoundedRectangle => ShapeKind::RoundedRectangle,
        FfiShapeKind::Ellipse => ShapeKind::Ellipse,
        FfiShapeKind::Triangle => ShapeKind::Triangle,
        FfiShapeKind::Diamond => ShapeKind::Diamond,
        FfiShapeKind::Pentagon => ShapeKind::Pentagon,
        FfiShapeKind::Hexagon => ShapeKind::Hexagon,
        FfiShapeKind::Star => ShapeKind::Star,
        FfiShapeKind::Process => ShapeKind::Process,
        FfiShapeKind::Decision => ShapeKind::Decision,
        FfiShapeKind::Terminator => ShapeKind::Terminator,
        FfiShapeKind::Data => ShapeKind::Data,
        FfiShapeKind::Document => ShapeKind::Document,
        FfiShapeKind::Database => ShapeKind::Database,
        FfiShapeKind::Preparation => ShapeKind::Preparation,
        FfiShapeKind::ManualInput => ShapeKind::ManualInput,
        FfiShapeKind::Connector => ShapeKind::Connector,
        FfiShapeKind::ManualOperation => ShapeKind::ManualOperation,
        FfiShapeKind::Delay => ShapeKind::Delay,
        FfiShapeKind::StoredData => ShapeKind::StoredData,
        FfiShapeKind::Merge => ShapeKind::Merge,
        FfiShapeKind::Extract => ShapeKind::Extract,
        FfiShapeKind::OffPageConnector => ShapeKind::OffPageConnector,
        FfiShapeKind::Display => ShapeKind::Display,
        FfiShapeKind::PunchedTape => ShapeKind::PunchedTape,
        FfiShapeKind::PunchedCard => ShapeKind::PunchedCard,
        FfiShapeKind::Collate => ShapeKind::Collate,
        FfiShapeKind::RightTriangle => ShapeKind::RightTriangle,
        FfiShapeKind::Parallelogram => ShapeKind::Parallelogram,
        FfiShapeKind::Trapezoid => ShapeKind::Trapezoid,
        FfiShapeKind::Heptagon => ShapeKind::Heptagon,
        FfiShapeKind::Octagon => ShapeKind::Octagon,
        FfiShapeKind::Cross => ShapeKind::Cross,
        FfiShapeKind::Chevron => ShapeKind::Chevron,
        FfiShapeKind::ArrowBlockRight => ShapeKind::ArrowBlockRight,
        FfiShapeKind::ArrowBlockLeft => ShapeKind::ArrowBlockLeft,
        FfiShapeKind::ArrowBlockUp => ShapeKind::ArrowBlockUp,
        FfiShapeKind::ArrowBlockDown => ShapeKind::ArrowBlockDown,
        FfiShapeKind::Cloud => ShapeKind::Cloud,
        FfiShapeKind::Heart => ShapeKind::Heart,
        FfiShapeKind::Bolt => ShapeKind::Bolt,
        FfiShapeKind::Moon => ShapeKind::Moon,
        FfiShapeKind::Teardrop => ShapeKind::Teardrop,
        FfiShapeKind::LShape => ShapeKind::LShape,
        FfiShapeKind::Star4 => ShapeKind::Star4,
        FfiShapeKind::Star6 => ShapeKind::Star6,
        FfiShapeKind::Star8 => ShapeKind::Star8,
        FfiShapeKind::Sun => ShapeKind::Sun,
        FfiShapeKind::Banner => ShapeKind::Banner,
        FfiShapeKind::SpeechBubble => ShapeKind::SpeechBubble,
        FfiShapeKind::Plaque => ShapeKind::Plaque,
        FfiShapeKind::Pie => ShapeKind::Pie,
        FfiShapeKind::Line => ShapeKind::Line,
        FfiShapeKind::Arrow => ShapeKind::Arrow,
        FfiShapeKind::DoubleArrow => ShapeKind::DoubleArrow,
    }
}

fn to_doc_anchor(a: FfiAnchor) -> Anchor {
    match a {
        FfiAnchor::Top => Anchor::Top,
        FfiAnchor::Right => Anchor::Right,
        FfiAnchor::Bottom => Anchor::Bottom,
        FfiAnchor::Left => Anchor::Left,
        FfiAnchor::Center => Anchor::Center,
    }
}

fn to_doc_route_style(r: FfiRouteStyle) -> RouteStyle {
    match r {
        FfiRouteStyle::Straight => RouteStyle::Straight,
        FfiRouteStyle::Orthogonal => RouteStyle::Orthogonal,
    }
}

fn to_doc_end_cap(c: FfiEndCap) -> EndCap {
    match c {
        FfiEndCap::None => EndCap::None,
        FfiEndCap::Arrow => EndCap::Arrow,
        FfiEndCap::HollowArrow => EndCap::HollowArrow,
        FfiEndCap::Circle => EndCap::Circle,
        FfiEndCap::Diamond => EndCap::Diamond,
    }
}

/// 從文件模型的錨點轉回 FFI 的。讀回連接線時需要。
pub(crate) fn from_doc_anchor(a: Anchor) -> FfiAnchor {
    match a {
        Anchor::Top => FfiAnchor::Top,
        Anchor::Right => FfiAnchor::Right,
        Anchor::Bottom => FfiAnchor::Bottom,
        Anchor::Left => FfiAnchor::Left,
        Anchor::Center => FfiAnchor::Center,
    }
}

pub(crate) fn from_doc_route_style(r: RouteStyle) -> FfiRouteStyle {
    match r {
        RouteStyle::Straight => FfiRouteStyle::Straight,
        RouteStyle::Orthogonal => FfiRouteStyle::Orthogonal,
    }
}

pub(crate) fn from_doc_end_cap(c: EndCap) -> FfiEndCap {
    match c {
        EndCap::None => FfiEndCap::None,
        EndCap::Arrow => FfiEndCap::Arrow,
        EndCap::HollowArrow => FfiEndCap::HollowArrow,
        EndCap::Circle => FfiEndCap::Circle,
        EndCap::Diamond => FfiEndCap::Diamond,
    }
}

pub(crate) fn parse_uuid(s: &str) -> Result<Uuid, FfiError> {
    let hex: String = s.chars().filter(|c| *c != '-').collect();
    if hex.len() != 32 {
        return Err(FfiError::Failed(format!("不是合法的 id：{s}")));
    }
    let mut out = [0u8; 16];
    for (i, c) in hex.as_bytes().chunks(2).enumerate() {
        out[i] = std::str::from_utf8(c)
            .ok()
            .and_then(|h| u8::from_str_radix(h, 16).ok())
            .ok_or_else(|| FfiError::Failed(format!("不是合法的 id：{s}")))?;
    }
    Ok(Uuid::from_bytes(out))
}

fn source_name(s: padnote_search::Source) -> &'static str {
    use padnote_search::Source;
    match s {
        Source::Text => "text",
        Source::Transcript => "transcript",
        Source::Handwriting => "handwriting",
        Source::PdfText => "pdf",
        Source::Ocr => "ocr",
    }
}

fn feature_name(f: Feature) -> &'static str {
    match f {
        Feature::CoreNotes => "core_notes",
        Feature::Recording => "recording",
        Feature::LiveTranscription => "live_transcription",
        Feature::HandwritingToText => "handwriting_to_text",
        Feature::AiSummary => "ai_summary",
        Feature::Sync => "sync",
    }
}

fn parse_capability(s: &str) -> Option<Capability> {
    Some(match s {
        "microphone" => Capability::Microphone,
        "speech" => Capability::SpeechPermission,
        "handwriting" => Capability::Handwriting,
        "asr_model" => Capability::AsrModel("paraformer-zh".into()),
        "llm_model" => Capability::LlmModel("qwen3-4b-instruct-q4".into()),
        "local_folder" => Capability::LocalSyncFolder,
        "icloud" => Capability::ICloudDrive,
        "google_drive" => Capability::GoogleDrive,
        _ => return None,
    })
}

#[cfg(test)]
mod tests {

    #[test]
    fn palettes_are_unique_and_well_formed() {
        // 重複的 hex 代表選單上會有兩格長得一樣，使用者分不出差別。
        let cards = card_palette();
        let mut seen = std::collections::HashSet::new();
        for entry in &cards {
            assert!(
                entry.hex.starts_with('#') && entry.hex.len() == 7,
                "壞的 hex：{}",
                entry.hex
            );
            assert!(!entry.key.is_empty(), "底色一定要有語系鍵");
            assert!(seen.insert(entry.hex.clone()), "重複的顏色：{}", entry.hex);
        }
        assert!(cards.len() >= 6);

        let borders = border_palette();
        let mut seen = std::collections::HashSet::new();
        for entry in &borders {
            assert!(
                entry.hex.starts_with('#') && entry.hex.len() == 7,
                "壞的 hex：{}",
                entry.hex
            );
            assert!(seen.insert(entry.hex.clone()), "重複的顏色：{}", entry.hex);
        }
    }

    #[test]
    fn designer_palettes_are_complete_and_unique() {
        let mut all = std::collections::HashSet::new();
        for group in designer_palette_groups() {
            let list = designer_palette(group);
            assert_eq!(list.len(), 8, "{group:?} 應該有 8 色");
            assert!(!designer_palette_group_key(group).is_empty());
            for entry in list {
                assert!(
                    entry.hex.starts_with('#') && entry.hex.len() == 7,
                    "壞的 hex：{}",
                    entry.hex
                );
                // 色名一定要是語系鍵，不可以是寫死的文字 —— 原本 40 個名字
                // 全是繁體中文，非中文使用者看到的就是一整面中文。
                assert!(
                    entry.key.starts_with("hue_"),
                    "色名要走語系鍵，實得 {}",
                    entry.key
                );
                assert!(all.insert(entry.hex.clone()), "重複的顏色：{}", entry.hex);
            }
        }
        assert_eq!(all.len(), 40);
    }

    #[test]
    fn card_palette_has_no_sentinel() {
        // "clear" 是哨符不是顏色。混進調色盤的話，走顏色轉換就變成黑色。
        assert!(card_palette().iter().all(|e| e.hex != "clear"));
    }
    use super::*;

    fn tmp(name: &str) -> String {
        let d = std::env::temp_dir().join(format!("padnote-ffi-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        d.to_string_lossy().into_owned()
    }

    fn session(name: &str) -> PadnoteSession {
        PadnoteSession::create(tmp(name), "線性代數".into(), 1_757_635_200_000, 0xA1).unwrap()
    }

    fn points() -> Vec<StrokePoint> {
        vec![
            StrokePoint {
                x: 0.0,
                y: 0.0,
                pressure: 0.5,
                tilt: 0.0,
                azimuth: 0.0,
                dt_us: 0,
            },
            StrokePoint {
                x: 10.0,
                y: 10.0,
                pressure: 0.8,
                tilt: 0.0,
                azimuth: 0.0,
                dt_us: 8_000,
            },
        ]
    }

    #[test]
    fn session_round_trip_through_the_ffi_surface() {
        let s = session("roundtrip");
        assert_eq!(s.title(), "線性代數");
        assert_eq!(s.page_count(), 1);

        let page = s.first_page_id().unwrap();
        let stroke = s
            .add_stroke(
                page.clone(),
                ToolKind::FountainPen,
                vec![0, 0, 0, 255],
                2.0,
                points(),
            )
            .unwrap();

        let strokes = s.visible_strokes(page.clone()).unwrap();
        assert_eq!(strokes.len(), 1);
        assert_eq!(strokes[0].id, stroke);
        assert_eq!(strokes[0].point_count, 2);
        assert_eq!(strokes[0].bounds.len(), 4);

        s.erase_stroke(page.clone(), stroke).unwrap();
        assert!(s.visible_strokes(page).unwrap().is_empty());
    }

    // ---- 套索 ----

    /// 在 `(x, y)` 附近畫一小段線，回傳它的 id。
    fn stroke_at(s: &PadnoteSession, page: &str, x: f32, y: f32) -> String {
        s.add_stroke(
            page.into(),
            ToolKind::BallPoint,
            vec![0, 0, 0, 255],
            2.0,
            vec![
                StrokePoint {
                    x,
                    y,
                    pressure: 0.5,
                    tilt: 0.0,
                    azimuth: 0.0,
                    dt_us: 0,
                },
                StrokePoint {
                    x: x + 5.0,
                    y: y + 5.0,
                    pressure: 0.5,
                    tilt: 0.0,
                    azimuth: 0.0,
                    dt_us: 8_000,
                },
            ],
        )
        .unwrap()
    }

    #[test]
    fn the_lasso_picks_up_only_what_it_encircles() {
        let s = session("lasso-select");
        let page = s.first_page_id().unwrap();
        let inside = stroke_at(&s, &page, 20.0, 20.0);
        let _outside = stroke_at(&s, &page, 500.0, 500.0);

        let picked = s
            .lasso_select(page, vec![0.0, 0.0, 100.0, 0.0, 100.0, 100.0, 0.0, 100.0])
            .unwrap();
        assert_eq!(picked, vec![inside]);
    }

    #[test]
    fn deleting_a_selection_removes_exactly_those_strokes() {
        let s = session("lasso-delete");
        let page = s.first_page_id().unwrap();
        let a = stroke_at(&s, &page, 20.0, 20.0);
        let _b = stroke_at(&s, &page, 500.0, 500.0);

        assert_eq!(s.lasso_delete(page.clone(), vec![a]).unwrap(), 1);
        assert_eq!(
            s.visible_strokes(page).unwrap().len(),
            1,
            "只該刪掉選到的那一筆"
        );
    }

    #[test]
    fn deleting_an_id_that_is_already_gone_is_not_an_error() {
        // 另一台裝置可能剛剛刪掉它。那不是錯誤，也不該讓整組刪除中斷 ——
        // 中斷的話使用者看到的是「刪了一半」。
        let s = session("lasso-delete-twice");
        let page = s.first_page_id().unwrap();
        let a = stroke_at(&s, &page, 20.0, 20.0);

        assert_eq!(s.lasso_delete(page.clone(), vec![a.clone()]).unwrap(), 1);
        assert_eq!(
            s.lasso_delete(page, vec![a, "not-a-uuid".into()]).unwrap(),
            0
        );
    }

    #[test]
    fn pasting_offsets_the_copy_and_gives_it_a_new_id() {
        let s = session("lasso-paste");
        let page = s.first_page_id().unwrap();
        let original = stroke_at(&s, &page, 20.0, 20.0);

        let clip = s.lasso_copy(page.clone(), vec![original.clone()]).unwrap();
        assert_eq!(clip.len(), 1);

        let pasted = s.lasso_paste(page.clone(), clip, 40.0, 0.0).unwrap();
        assert_eq!(pasted.len(), 1);
        // **新 id。** 沿用原本的話，同步到另一台會變成把原本那一筆搬走，
        // 而不是多一份。
        assert_ne!(pasted[0], original);

        let all = s.visible_stroke_details(page).unwrap();
        assert_eq!(all.len(), 2, "原本那一筆要還在");
        let xs: Vec<f32> = all.iter().map(|st| st.points[0].x).collect();
        assert!(
            xs.contains(&20.0) && xs.contains(&60.0),
            "貼上的那一份要平移過：{xs:?}"
        );
    }

    #[test]
    fn translating_keeps_the_stroke_count() {
        // 拖曳是「刪掉再以新座標加回去」。少了這一條，實作寫成「加回去
        // 但忘了刪」的話，每拖一次就多一份，而畫面上看起來只是變粗。
        let s = session("lasso-move");
        let page = s.first_page_id().unwrap();
        let a = stroke_at(&s, &page, 20.0, 20.0);

        let moved = s
            .lasso_translate(page.clone(), vec![a], 100.0, 0.0)
            .unwrap();
        assert_eq!(moved.len(), 1);

        let all = s.visible_stroke_details(page).unwrap();
        assert_eq!(all.len(), 1, "拖曳不該多出一份");
        assert_eq!(all[0].points[0].x, 120.0);
    }

    #[test]
    fn malformed_id_returns_error_instead_of_panicking() {
        // FFI 輸入來自另一個語言，不可信。
        let s = session("badid");
        assert!(
            s.add_stroke(
                "not-a-uuid".into(),
                ToolKind::BallPoint,
                vec![],
                1.0,
                points()
            )
            .is_err()
        );
        assert!(s.visible_strokes("".into()).is_err());
        assert!(s.erase_stroke("zzzz".into(), "zzzz".into()).is_err());
    }

    #[test]
    fn short_color_array_falls_back_instead_of_panicking() {
        assert_eq!(to_rgba(&[]), [0, 0, 0, 255]);
        assert_eq!(to_rgba(&[1, 2, 3]), [1, 2, 3, 255]);
        assert_eq!(to_rgba(&[1, 2, 3, 4]), [1, 2, 3, 4]);
        assert_eq!(to_rgba(&[1, 2, 3, 4, 5]), [0, 0, 0, 255]);
    }

    #[test]
    fn c1_playback_lookup_works_across_the_boundary() {
        let s = session("c1");
        let page = s.first_page_id().unwrap();

        s.advance_time(1_000_000);
        s.start_recording().unwrap();
        assert!(s.is_recording());

        s.advance_time(4_500_000);
        s.add_stroke(
            page.clone(),
            ToolKind::BallPoint,
            vec![0, 0, 0, 255],
            2.0,
            points(),
        )
        .unwrap();

        s.advance_time(10_000_000);
        s.stop_recording().unwrap();
        assert!(!s.is_recording());

        let stroke = &s.visible_strokes(page).unwrap()[0];
        let pos = s.playback_at(stroke.started_at_us).expect("應找得到錄音");
        assert_eq!(pos.offset_us, 3_500_000);
        assert!(pos.media_path.ends_with(".opus"));

        assert_eq!(s.recorded_duration_us(), 9_000_000);
    }

    #[test]
    fn search_reports_its_source() {
        let s = session("search");
        let page = s.first_page_id().unwrap();
        s.add_text(page.clone(), "線性代數筆記".into(), BlockStyle::Body)
            .unwrap();

        let stroke = s
            .add_stroke(
                page.clone(),
                ToolKind::Pencil,
                vec![0, 0, 0, 255],
                2.0,
                points(),
            )
            .unwrap();
        s.index_handwriting(page, stroke, "手寫的線性代數".into())
            .unwrap();

        let hits = s.search("線性".into(), 10);
        assert_eq!(hits.len(), 2);
        assert_eq!(hits[0].source, "text", "打字應排在手寫辨識之前");
        assert!(hits.iter().any(|h| h.source == "handwriting"));
    }

    #[test]
    fn feature_status_starts_with_only_core_notes_ready() {
        // 全新安裝、零權限：手寫與打字就該能用，其他都需要設定。
        let s = session("features");
        let all = s.feature_status();
        assert_eq!(all.len(), 6);

        let core = all.iter().find(|f| f.feature == "core_notes").unwrap();
        assert!(core.ready);
        assert_eq!(core.explanation, "可以使用");

        let transcription = all
            .iter()
            .find(|f| f.feature == "live_transcription")
            .unwrap();
        assert!(!transcription.ready);
        assert!(transcription.explanation.contains("麥克風"));
    }

    #[test]
    fn reporting_capabilities_unblocks_features() {
        let s = session("caps");
        s.report_capability("microphone".into(), "ready".into(), 0);
        assert!(
            s.feature_status()
                .iter()
                .find(|f| f.feature == "recording")
                .unwrap()
                .ready
        );

        s.report_capability("speech".into(), "ready".into(), 0);
        s.report_capability("asr_model".into(), "ready".into(), 0);
        assert!(
            s.feature_status()
                .iter()
                .find(|f| f.feature == "live_transcription")
                .unwrap()
                .ready
        );
    }

    #[test]
    fn unknown_capability_name_is_ignored_not_fatal() {
        let s = session("unknowncap");
        s.report_capability("teleportation".into(), "ready".into(), 0);
        assert_eq!(s.feature_status().len(), 6);
    }

    #[test]
    fn pending_download_size_is_reported() {
        let s = session("download");
        s.report_capability("asr_model".into(), "needs_download".into(), 230_686_720);
        s.report_capability("llm_model".into(), "needs_download".into(), 2_621_440_000);
        assert_eq!(s.pending_download_bytes(), 2_852_126_720);
    }

    #[test]
    fn export_crosses_the_boundary() {
        let s = session("export");
        let page = s.first_page_id().unwrap();
        s.add_text(page.clone(), "重點".into(), BlockStyle::Heading2)
            .unwrap();
        s.add_stroke(
            page.clone(),
            ToolKind::FountainPen,
            vec![0, 0, 0, 255],
            2.0,
            points(),
        )
        .unwrap();

        let md = s.export_markdown().unwrap();
        assert!(md.contains("## 重點"));
        assert!(md.contains("手寫內容"));

        // PDF 匯出
        let pdf = s.export_pdf().unwrap();
        assert!(pdf.starts_with(b"%PDF-1.7"));
        assert!(pdf.ends_with(b"%%EOF\n"));

        // 單頁 PDF 匯出
        let page_pdf = s.export_page_pdf(page.clone()).unwrap();
        assert!(page_pdf.starts_with(b"%PDF-1.7"));

        // 單頁 PNG 匯出
        let png = s.export_page_png(page.clone(), 2.0).unwrap();
        assert_eq!(&png[0..8], &[137, 80, 78, 71, 13, 10, 26, 10]);

        // 列印資料取得
        let print_all = s.print_data(None).unwrap();
        assert!(print_all.starts_with(b"%PDF-1.7"));
        let print_page = s.print_data(Some(page)).unwrap();
        assert!(print_page.starts_with(b"%PDF-1.7"));
    }

    #[test]
    fn reopening_restores_everything_through_the_ffi() {
        let path = tmp("ffi-reopen");
        let block_text;
        let page;
        {
            let s =
                PadnoteSession::create(path.clone(), "線性代數".into(), 1_757_635_200_000, 0xA1)
                    .unwrap();
            page = s.first_page_id().unwrap();
            let b = s
                .add_text(page.clone(), "特徵值".into(), BlockStyle::Body)
                .unwrap();
            s.insert_text(b.clone(), 3, "與特徵向量".into()).unwrap();
            block_text = b;
        }

        let reopened = PadnoteSession::open_existing(path, 0xA1).unwrap();
        assert_eq!(reopened.title(), "線性代數");
        assert_eq!(
            reopened.block_text(block_text).unwrap().as_deref(),
            Some("特徵值與特徵向量")
        );
        assert_eq!(reopened.search("特徵".into(), 10).len(), 1);
    }

    #[test]
    fn text_editing_uses_character_indices_not_bytes() {
        // 用位元組索引會把中文切壞 —— 這條測試把它釘死。
        let s = session("charindex");
        let page = s.first_page_id().unwrap();
        let b = s
            .add_text(page, "線性代數".into(), BlockStyle::Body)
            .unwrap();

        s.insert_text(b.clone(), 2, "XX".into()).unwrap();
        assert_eq!(
            s.block_text(b.clone()).unwrap().as_deref(),
            Some("線性XX代數")
        );

        s.delete_text(b.clone(), 2, 2).unwrap();
        assert_eq!(s.block_text(b).unwrap().as_deref(), Some("線性代數"));
    }

    #[test]
    fn blob_and_image_round_trip() {
        let s = session("ffi-image");
        let page = s.first_page_id().unwrap();
        let blob = s.put_blob(b"png bytes".to_vec()).unwrap();
        let img = s.add_image(page, blob, 640.0, 480.0).unwrap();
        assert!(!img.is_empty());
    }

    #[test]
    fn audio_feed_reports_progress_across_the_boundary() {
        let s = session("ffi-audio");
        s.start_recording().unwrap();

        let pcm: Vec<f32> = (0..16_000).map(|i| (i as f32 * 0.3).sin() * 0.6).collect();
        let stats = s.feed_audio(pcm).unwrap();

        assert_eq!(stats.frames_written, 50, "1 秒 = 50 個 20ms 音框");
        assert_eq!(stats.recorded_us, 1_000_000);
        assert_eq!(stats.segments_dropped, 0);
    }

    #[test]
    fn feeding_audio_without_recording_throws() {
        let s = session("ffi-noaudio");
        assert!(s.feed_audio(vec![0.0; 100]).is_err());
    }

    #[test]
    fn transcripts_can_be_written_back_from_the_platform() {
        let s = session("ffi-transcript");
        let page = s.first_page_id().unwrap();
        s.advance_time(1_000_000);
        let rec = s.start_recording().unwrap();

        s.add_transcript(
            page,
            rec,
            vec![TranscriptWordInput {
                text: "特徵值".into(),
                start_us: 3_000_000,
                end_us: 3_800_000,
                confidence: 0.9,
            }],
        )
        .unwrap();

        assert_eq!(s.search("特徵".into(), 10).len(), 1);
        // C1：點轉錄詞跳回錄音的第 2 秒
        let pos = s.playback_at(3_000_000).expect("應對應到錄音");
        assert_eq!(pos.offset_us, 2_000_000);
    }

    #[test]
    fn vad_model_can_be_configured_across_the_boundary() {
        let s = session("ffi-vad");
        assert!(!s.uses_neural_vad(), "預設應為能量門檻法");

        s.set_vad_model("/nonexistent.onnx".into());
        assert!(!s.uses_neural_vad(), "不存在的模型不該被當成可用");
    }

    #[test]
    fn markdown_round_trips_across_the_boundary() {
        let s = session("ffi-import");
        let page = s.first_page_id().unwrap();
        s.add_text(page, "重點整理".into(), BlockStyle::Heading2)
            .unwrap();

        let md = s.export_markdown().unwrap();
        let pages = s.import_markdown(md).unwrap();

        assert!(!pages.is_empty());
        assert_eq!(s.search("重點".into(), 10).len(), 2, "原有的與匯入的各一份");
    }

    #[test]
    fn object_operations_cross_the_boundary() {
        let s = session("ffi-objects");
        let page = s.first_page_id().unwrap();
        let stroke = s
            .add_stroke(
                page.clone(),
                ToolKind::BallPoint,
                vec![0, 0, 0, 255],
                2.0,
                points(),
            )
            .unwrap();

        let obj = s.create_stroke_object(page.clone(), vec![stroke]).unwrap();
        s.translate_object(obj.clone(), 10.0, 20.0).unwrap();

        let t = s.object_transform(page, obj).unwrap();
        assert_eq!(t.len(), 6);
        assert_eq!((t[4], t[5]), (10.0, 20.0), "位移應反映在變換上");
    }

    #[test]
    fn grouping_and_ungrouping_cross_the_boundary() {
        let s = session("ffi-group");
        let page = s.first_page_id().unwrap();

        let mut objects = Vec::new();
        for _ in 0..2 {
            let stroke = s
                .add_stroke(
                    page.clone(),
                    ToolKind::BallPoint,
                    vec![0, 0, 0, 255],
                    2.0,
                    points(),
                )
                .unwrap();
            objects.push(s.create_stroke_object(page.clone(), vec![stroke]).unwrap());
        }

        let group = s.group_objects(page.clone(), objects.clone()).unwrap();
        s.translate_object(group.clone(), 50.0, 0.0).unwrap();

        // 群組的變換要傳到成員身上
        let member = s
            .object_transform(page.clone(), objects[0].clone())
            .unwrap();
        assert_eq!(member[4], 50.0, "成員應繼承群組的位移");

        s.ungroup(group).unwrap();
        let after = s.object_transform(page, objects[0].clone()).unwrap();
        assert_eq!(after[4], 50.0, "解散後位置不該跳動");
    }

    #[test]
    fn malformed_object_id_is_rejected() {
        let s = session("ffi-badobj");
        assert!(s.translate_object("not-a-uuid".into(), 1.0, 1.0).is_err());
    }

    #[test]
    fn version_helpers_are_exported() {
        assert_eq!(spec_version(), crate::SPEC_VERSION);
        assert!(can_open(1, 1));
        assert!(!can_open(99, 99));
    }

    // ── 頁面身分（兩台裝置的頁要收斂在同一頁）──────────────────

    #[test]
    fn a_page_can_be_created_with_a_given_id() {
        let s = session("page-with-id");
        let id = "01920000-0000-7000-8000-000000000001";
        s.add_page_with_id(id.into(), PageStyle::Grid).unwrap();
        let ids: Vec<String> = (0..s.page_count())
            .filter_map(|i| s.page_id_at(i))
            .collect();
        assert!(
            ids.contains(&id.to_string()),
            "指定 id 建的頁沒有出現：{ids:?}"
        );
    }

    #[test]
    fn creating_the_same_page_twice_is_a_no_op() {
        // 重複匯出會再呼叫一次。變成兩頁的話，每同步一趟就多一批頁。
        let s = session("page-with-id-twice");
        let id = "01920000-0000-7000-8000-000000000002";
        let before = s.page_count();
        s.add_page_with_id(id.into(), PageStyle::Blank).unwrap();
        s.add_page_with_id(id.into(), PageStyle::Blank).unwrap();
        assert_eq!(s.page_count(), before + 1);
    }

    #[test]
    fn an_empty_notebook_starts_with_no_pages() {
        // 重建套件時要沿用既有的頁面 id，自動給的那一頁是多餘的 ——
        // 而「先加再移」在多裝置合併時不保證互相抵銷。
        let s = PadnoteSession::create_empty(
            tmp("create-empty"),
            "空的".into(),
            1_757_635_200_000,
            0xA1,
        )
        .unwrap();
        assert_eq!(s.page_count(), 0);
        assert_eq!(s.first_page_id(), None);
    }

    #[test]
    fn a_normal_notebook_still_starts_with_one_page() {
        // 開一本新筆記時自動給一頁是對的，這個行為不能變。
        let s = session("create-has-page");
        assert_eq!(s.page_count(), 1);
        assert!(s.first_page_id().is_some());
    }

    #[test]
    fn a_page_can_be_removed() {
        // 加得了卻移不掉的話，沿用頁面 id 時自動產生的那一頁會變成多餘的第一頁。
        let s = session("page-remove");
        let first = s.first_page_id().unwrap();
        let id = "01920000-0000-7000-8000-000000000003";
        s.add_page_with_id(id.into(), PageStyle::Blank).unwrap();
        s.remove_page(first).unwrap();

        let ids: Vec<String> = (0..s.page_count())
            .filter_map(|i| s.page_id_at(i))
            .collect();
        assert_eq!(ids, vec![id.to_string()]);
    }

    #[test]
    fn a_malformed_page_id_is_rejected() {
        // 悄悄改用隨機 id 的話，頁面身分就斷了，而且沒有人會知道。
        let s = session("page-with-id-bad");
        assert!(
            s.add_page_with_id("不是 uuid".into(), PageStyle::Blank)
                .is_err()
        );
    }

    // ── 筆記本中繼資料（跨平台來回不掉東西靠它）──────────────

    #[test]
    fn notebook_meta_survives_a_reopen() {
        // 這是「A 裝置寫、B 裝置打開就有」缺的那一塊：樣板、資料夾、圖釘
        // 這些核心沒有對應概念的東西，少了它在另一台裝置上就會整批消失。
        let dir = tmp("meta-reopen");
        let json = r#"{"template":"cornell","folderId":"work"}"#;
        {
            let s = PadnoteSession::create(dir.clone(), "筆記".into(), 1_757_635_200_000, 0xA1)
                .unwrap();
            s.set_notebook_meta(json.into()).unwrap();
            assert_eq!(s.notebook_meta(), Some(json.to_string()));
        }
        let reopened = PadnoteSession::open_existing(dir, 0xA1).unwrap();
        assert_eq!(reopened.notebook_meta(), Some(json.to_string()));
    }

    #[test]
    fn an_unset_notebook_meta_is_none() {
        // `None` 與「空物件」要分得出來：讀到 None 代表這份檔案還沒有中繼資料，
        // 讀到 "{}" 代表有人刻意清空了。
        let s = session("meta-unset");
        assert_eq!(s.notebook_meta(), None);
    }

    #[test]
    fn the_last_write_of_notebook_meta_wins() {
        // 語意是整份取代，不是合併 —— 核心看不懂內容，合不了。
        let s = session("meta-replace");
        s.set_notebook_meta(r#"{"a":1}"#.into()).unwrap();
        s.set_notebook_meta(r#"{"b":2}"#.into()).unwrap();
        assert_eq!(s.notebook_meta(), Some(r#"{"b":2}"#.to_string()));
    }

    #[test]
    fn notebook_meta_is_not_interpreted() {
        // 核心原樣搬運。內容不是 JSON 也照收 —— 解讀是平台的事。
        let s = session("meta-opaque");
        s.set_notebook_meta("不是 JSON".into()).unwrap();
        assert_eq!(s.notebook_meta(), Some("不是 JSON".to_string()));
    }

    // ── blob 的出口（圖片回得來靠它）──────────────────────────

    #[test]
    fn image_bytes_come_back_out() {
        // 位元組進得去、出不來的話，另一台裝置打得開筆記卻拿不到圖，
        // 畫面上會是一格一格的空白。
        let s = session("blob-roundtrip");
        let page = s.first_page_id().unwrap();
        let bytes = vec![0x89, 0x50, 0x4E, 0x47, 1, 2, 3];
        let blob = s.put_blob(bytes.clone()).unwrap();
        let block = s.add_image(page, blob.clone(), 100.0, 80.0).unwrap();

        assert_eq!(s.block_blob_id(block).unwrap(), Some(blob.clone()));
        assert_eq!(s.blob_bytes(blob).unwrap(), bytes);
    }

    #[test]
    fn a_text_block_references_no_blob() {
        let s = session("blob-text");
        let page = s.first_page_id().unwrap();
        let text = s.add_text(page, "字".into(), BlockStyle::Body).unwrap();
        assert_eq!(s.block_blob_id(text).unwrap(), None);
    }

    #[test]
    fn a_bad_blob_id_reports_an_error_instead_of_empty_bytes() {
        // 回空位元組的話，呼叫端會以為那是一張 0 位元組的圖而把它畫成空白。
        let s = session("blob-bad-id");
        assert!(s.blob_bytes("不是雜湊".into()).is_err());
    }

    // ── 圖片區塊的出口（數字製圖靠它才回得來）─────────────────

    fn image_block(s: &PadnoteSession, page: &str, w: f32, h: f32) -> String {
        let blob = s.put_blob(vec![1, 2, 3, 4]).unwrap();
        s.add_image(page.into(), blob, w, h).unwrap()
    }

    #[test]
    fn image_blocks_can_be_listed_back() {
        // 列不出來的話，圖表就是單向的：寫得進檔案，另一台裝置卻找不到它。
        let s = session("image-list");
        let page = s.first_page_id().unwrap();
        let first = image_block(&s, &page, 200.0, 120.0);
        let second = image_block(&s, &page, 90.0, 90.0);

        assert_eq!(s.image_block_ids(page).unwrap(), vec![first, second]);
    }

    #[test]
    fn listing_image_blocks_excludes_text_blocks() {
        let s = session("image-list-excludes-text");
        let page = s.first_page_id().unwrap();
        let text = s
            .add_text(page.clone(), "字".into(), BlockStyle::Body)
            .unwrap();
        let image = image_block(&s, &page, 10.0, 10.0);

        assert_eq!(s.image_block_ids(page.clone()).unwrap(), vec![image]);
        assert_eq!(s.text_block_ids(page).unwrap(), vec![text]);
    }

    #[test]
    fn an_image_block_reports_its_size() {
        // 尺寸拿不回來的話，重新打開的圖表只能猜一個大小，畫出來就不是原樣。
        let s = session("image-size");
        let page = s.first_page_id().unwrap();
        let id = image_block(&s, &page, 420.0, 300.0);

        assert_eq!(s.image_block_size(id).unwrap(), Some(vec![420.0, 300.0]));
    }

    #[test]
    fn a_text_block_has_no_image_size() {
        let s = session("image-size-text");
        let page = s.first_page_id().unwrap();
        let text = s.add_text(page, "字".into(), BlockStyle::Body).unwrap();
        assert_eq!(s.image_block_size(text).unwrap(), None);
    }

    #[test]
    fn a_chart_spec_survives_on_an_image_block() {
        // 這是「圖表跨平台還改得動」的完整來回：寫進去、列出來、讀回設定。
        let s = session("image-chart-appearance");
        let page = s.first_page_id().unwrap();
        let id = image_block(&s, &page, 420.0, 300.0);
        let spec = crate::ffi_chart::chart_default_spec_json();
        s.set_block_appearance(id.clone(), spec.clone()).unwrap();

        let listed = s.image_block_ids(page).unwrap();
        assert_eq!(listed, vec![id.clone()]);
        assert_eq!(s.block_appearance(id).unwrap(), Some(spec));
    }
}
