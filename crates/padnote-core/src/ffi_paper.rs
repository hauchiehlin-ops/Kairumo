//! 紙張目錄：主題分類 → 可選的紙張樣板。
//!
//! # 為什麼在核心
//!
//! 這份清單原本只存在於 `apple/Sources/NotebookStore.swift` 的 `NoteTemplate`
//! 裡，Android 的「新增筆記」對話框**完全沒有紙張可選** —— 同一個 App 在
//! 兩台裝置上，一邊能選康乃爾格式、一邊只能拿到空白紙。註解攔不住這件事，
//! 所以清單、順序、語系鍵與紙張樣式一律由這裡供應，兩端只負責畫。
//!
//! # 為什麼識別字是英文，而不是沿用 Apple 的中文 rawValue
//!
//! Apple 的 `NoteTemplate` rawValue 是中文字面值，而且**已經寫進使用者的
//! `notebooks_v1.json`**，動不得。所以這裡另外給一組與語言無關的 `id`，
//! 由平台層自行對應到既有的持久化值 —— 核心不碰別人已經落盤的東西。

use crate::ffi::PageStyle;

/// 紙張的主題分類。順序即顯示順序。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiPaperTheme {
    /// 通用基礎：只有底紋的那幾張。
    General,
    /// 筆記方法：康乃爾、四象限、大綱這一類**有結構的記法**。
    ///
    /// 這些原本混在「通用基礎」裡（只有康乃爾一種），而使用者要找的其實是
    /// 「我想用哪一種記法」—— 那是一個問題，不是十三張紙裡挑一張。
    Method,
    /// 規劃排程：月、週、日與時間軸。
    Planner,
    /// 清單追蹤：待辦、勾選、習慣與進度表。
    Tracker,
    /// 美學視覺
    Aesthetic,
    /// 工程製程
    Engineering,
    /// 數位體驗
    Digital,
}

/// 一種紙張樣板。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiPaperTemplate {
    /// 與語言無關的識別字。平台層用它對應到自己的持久化值。
    pub id: String,
    /// 顯示名稱的語系鍵。
    pub title_key: String,
    /// 說明文字的語系鍵。
    pub desc_key: String,
    /// SF Symbol 名稱（Apple）。
    pub icon_apple: String,
    /// Material 圖示名稱（Android）。
    pub icon_android: String,
    /// 這張紙的底紋。
    pub page_style: PageStyle,
    /// 所屬主題。
    pub theme: FfiPaperTheme,
}

/// 全部主題，順序即顯示順序。
#[uniffi::export]
pub fn paper_themes() -> Vec<FfiPaperTheme> {
    vec![
        FfiPaperTheme::General,
        FfiPaperTheme::Method,
        FfiPaperTheme::Planner,
        FfiPaperTheme::Tracker,
        FfiPaperTheme::Aesthetic,
        FfiPaperTheme::Engineering,
        FfiPaperTheme::Digital,
    ]
}

/// 主題標題的語系鍵。與 [`crate::ffi_theme_tools::theme_tab_key`] 用同一組鍵，
/// 因為畫布上的「主題工具」分頁與這裡講的是同一件事。
#[uniffi::export]
pub fn paper_theme_key(theme: FfiPaperTheme) -> String {
    match theme {
        FfiPaperTheme::General => "theme_general",
        FfiPaperTheme::Method => "theme_method",
        FfiPaperTheme::Planner => "theme_planner",
        FfiPaperTheme::Tracker => "theme_tracker",
        FfiPaperTheme::Aesthetic => "theme_aesthetic",
        FfiPaperTheme::Engineering => "theme_engineering",
        FfiPaperTheme::Digital => "theme_digital",
    }
    .to_string()
}

/// 主題圖示（Apple / Android）。
#[uniffi::export]
pub fn paper_theme_icons(theme: FfiPaperTheme) -> Vec<String> {
    let (apple, android) = match theme {
        FfiPaperTheme::General => ("doc.text", "Description"),
        FfiPaperTheme::Method => ("square.split.1x2", "ViewQuilt"),
        FfiPaperTheme::Planner => ("calendar", "CalendarMonth"),
        FfiPaperTheme::Tracker => ("checklist", "Checklist"),
        FfiPaperTheme::Aesthetic => ("paintpalette.fill", "Palette"),
        FfiPaperTheme::Engineering => ("ruler.fill", "Straighten"),
        FfiPaperTheme::Digital => ("macbook.and.iphone", "PhoneIphone"),
    };
    vec![apple.to_string(), android.to_string()]
}

fn entry(
    id: &str,
    key: &str,
    icon_apple: &str,
    icon_android: &str,
    page_style: PageStyle,
    theme: FfiPaperTheme,
) -> FfiPaperTemplate {
    FfiPaperTemplate {
        id: id.to_string(),
        title_key: key.to_string(),
        desc_key: format!("{key}_desc"),
        icon_apple: icon_apple.to_string(),
        icon_android: icon_android.to_string(),
        page_style,
        theme,
    }
}

/// 全部紙張樣板，依主題順序排列。
///
/// # 為什麼一張紙只帶 `page_style`，版面卻在別的地方
///
/// `page_style` 是**底紋**（方格、點陣、橫線），會落盤、而且是重複的材質；
/// 版面（康乃爾的三個區塊、四象限的十字）是**結構**，由
/// [`crate::ffi_guides::page_guides`] 用同一個 `id` 供應。分開的理由是量：
/// 5mm 點陣在 A4 上是兩千多個點，把它們一顆顆送過 FFI 只是浪費。
#[uniffi::export]
pub fn paper_templates() -> Vec<FfiPaperTemplate> {
    use FfiPaperTheme::{Aesthetic, Digital, Engineering, General, Method, Planner, Tracker};
    vec![
        // 通用基礎
        entry("blank", "tmpl_blank", "doc.plaintext", "Article", PageStyle::Blank, General),
        entry("grid", "tmpl_grid", "circle.grid.3x3", "GridOn", PageStyle::Grid, General),
        entry("lined", "tmpl_lined", "line.horizontal.3", "Notes", PageStyle::Lined, General),
        entry(
            "dot_grid_fine", "tmpl_dot_grid_fine", "circle.dotted", "BlurOn",
            PageStyle::Dotted, General,
        ),
        // 筆記方法
        entry("cornell", "tmpl_cornell", "sidebar.left", "ViewSidebar", PageStyle::Cornell, Method),
        entry(
            "cornell_grid", "tmpl_cornell_grid", "square.split.1x2", "ViewSidebar",
            PageStyle::Grid, Method,
        ),
        entry(
            "quadrant", "tmpl_quadrant", "square.split.2x2", "GridView",
            PageStyle::Blank, Method,
        ),
        entry(
            "outline", "tmpl_outline", "list.bullet.indent", "FormatIndentIncrease",
            PageStyle::Blank, Method,
        ),
        entry(
            "two_column", "tmpl_two_column", "rectangle.split.2x1", "VerticalSplit",
            PageStyle::Blank, Method,
        ),
        entry(
            "qa", "tmpl_qa", "questionmark.bubble", "QuestionAnswer",
            PageStyle::Blank, Method,
        ),
        entry("kwl", "tmpl_kwl", "rectangle.split.3x1", "ViewColumn", PageStyle::Blank, Method),
        entry(
            "mind_map", "tmpl_mind_map", "point.topleft.down.curvedto.point.bottomright.up",
            "AccountTree", PageStyle::Dotted, Method,
        ),
        // 規劃排程
        entry(
            "monthly_grid", "tmpl_monthly_grid", "calendar", "CalendarMonth",
            PageStyle::Blank, Planner,
        ),
        entry(
            "weekly_columns", "tmpl_weekly_columns", "calendar.day.timeline.left",
            "ViewWeek", PageStyle::Blank, Planner,
        ),
        entry(
            "daily_schedule", "tmpl_daily_schedule", "clock", "Schedule",
            PageStyle::Blank, Planner,
        ),
        entry(
            "timeline_24h", "tmpl_timeline_24h", "clock.badge", "AccessTime",
            PageStyle::Blank, Planner,
        ),
        entry(
            "study_planner", "tmpl_study_planner", "book", "MenuBook",
            PageStyle::Blank, Planner,
        ),
        entry(
            "project_timeline", "tmpl_project_timeline", "chart.bar.doc.horizontal",
            "Timeline", PageStyle::Blank, Planner,
        ),
        // 清單追蹤
        entry(
            "todo_list", "tmpl_todo_list", "checklist", "Checklist",
            PageStyle::Blank, Tracker,
        ),
        entry(
            "checklist_two", "tmpl_checklist_two", "checklist.checked", "FactCheck",
            PageStyle::Blank, Tracker,
        ),
        entry(
            "habit_month", "tmpl_habit_month", "square.grid.4x3.fill", "EventRepeat",
            PageStyle::Blank, Tracker,
        ),
        entry(
            "assignment_tracker", "tmpl_assignment_tracker", "tray.full", "Assignment",
            PageStyle::Blank, Tracker,
        ),
        entry(
            "chore_roster", "tmpl_chore_roster", "house", "CleaningServices",
            PageStyle::Blank, Tracker,
        ),
        entry(
            "challenge_21", "tmpl_challenge_21", "flag.checkered", "EmojiEvents",
            PageStyle::Blank, Tracker,
        ),
        // 美學視覺
        entry(
            "golden_ratio", "tmpl_golden_ratio", "camera.metering.center.weighted",
            "CropFree", PageStyle::Blank, Aesthetic,
        ),
        entry(
            "moodboard", "tmpl_moodboard", "rectangle.split.2x2", "Dashboard",
            PageStyle::Blank, Aesthetic,
        ),
        // 工程製程
        entry(
            "blueprint", "tmpl_blueprint", "square.grid.3x3.square", "Engineering",
            PageStyle::Grid, Engineering,
        ),
        entry(
            "isometric", "tmpl_isometric", "cube.transparent", "ViewInAr",
            PageStyle::Grid, Engineering,
        ),
        entry(
            "orthographic", "tmpl_orthographic", "square.split.2x2", "Window",
            PageStyle::Blank, Engineering,
        ),
        // 數位體驗
        entry(
            "mobile_wireframe", "tmpl_mobile_wireframe", "iphone", "PhoneAndroid",
            PageStyle::Blank, Digital,
        ),
        entry(
            "web_grid", "tmpl_web_grid", "macwindow", "Laptop", PageStyle::Grid, Digital,
        ),
        entry(
            "user_journey", "tmpl_user_journey", "arrow.triangle.branch", "AccountTree",
            PageStyle::Blank, Digital,
        ),
    ]
}

/// 某個主題底下的紙張。
#[uniffi::export]
pub fn paper_templates_for_theme(theme: FfiPaperTheme) -> Vec<FfiPaperTemplate> {
    paper_templates()
        .into_iter()
        .filter(|t| t.theme == theme)
        .collect()
}

/// 筆記本中繼資料裡存的樣板值 → 紙張 id。
///
/// # 為什麼需要轉換
///
/// Apple 的 `NoteTemplate` rawValue 是**中文字面值**，而且已經寫進使用者的
/// 檔案與同步中繼資料（`NotebookMeta.template`），動不得。Android 讀到那個
/// 字串時要知道它是哪一張紙 —— 在 Android 那邊再手抄一份中文對照表，
/// 就是第二份會漂移的東西。
///
/// 新加的樣板沒有這個包袱：它們的存檔值就是 id，原樣通過。
/// 認不得的一律回 `blank` —— 未知的底紋比沒有底紋更難解釋。
#[uniffi::export]
pub fn paper_id_from_stored(raw: String) -> String {
    let legacy = match raw.as_str() {
        "空白紙張" => Some("blank"),
        "方格點陣" => Some("grid"),
        "橫線筆記" => Some("lined"),
        "康乃爾" => Some("cornell"),
        "極細點陣 (5mm)" => Some("dot_grid_fine"),
        "黃金比例與三分構圖" => Some("golden_ratio"),
        "情緒板與色卡矩陣" => Some("moodboard"),
        "工程藍圖坐標紙" => Some("blueprint"),
        "30° 等角立體軸測網格" => Some("isometric"),
        "三視圖與剖面範本" => Some("orthographic"),
        "行動端線框 (8pt Grid)" => Some("mobile_wireframe"),
        "響應式 Web 12 欄網格" => Some("web_grid"),
        "使用者旅程與流程圖" => Some("user_journey"),
        _ => None,
    };
    if let Some(id) = legacy {
        return id.to_string();
    }
    if paper_templates().iter().any(|t| t.id == raw) {
        return raw;
    }
    "blank".to_string()
}

/// 文件範本的 `pageStyle` 欄位 → 該用哪一張紙。
///
/// # 為什麼需要這個
///
/// 「文件範本」（簽、契約、會議紀錄）與「紙張」是兩個獨立的選擇，於是
/// 實機上出現過一份公文「簽」鋪在**行動端線框**紙上：本文底下壓著兩個
/// 手機外框。文件範本的 JSON 本來就帶著它要的 `pageStyle`，兩端卻都只
/// 解析、不使用。選了文件範本就以它為準，紙張的選擇讓位。
///
/// 認不得的字串一律回空白紙 —— 未知的底紋比沒有底紋更難解釋。
#[uniffi::export]
pub fn doc_template_paper_id(page_style: &str) -> String {
    match page_style {
        "lined" => "lined",
        "grid" => "grid",
        "dotted" => "dot_grid_fine",
        "cornell" => "cornell",
        _ => "blank",
    }
    .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_chinese_legacy_values_still_resolve() {
        // 這十三個字串就在使用者的檔案裡。對不回來的話，那本筆記重開之後
        // 版面會變成空白紙 —— 而使用者沒有做過任何事。
        assert_eq!(paper_id_from_stored("康乃爾".into()), "cornell");
        assert_eq!(paper_id_from_stored("30° 等角立體軸測網格".into()), "isometric");
        assert_eq!(paper_id_from_stored("行動端線框 (8pt Grid)".into()), "mobile_wireframe");
        // 新的樣板存的就是 id，原樣通過。
        assert_eq!(paper_id_from_stored("quadrant".into()), "quadrant");
        assert_eq!(paper_id_from_stored("habit_month".into()), "habit_month");
        // 認不得的回空白紙，不是 panic。
        assert_eq!(paper_id_from_stored("".into()), "blank");
        assert_eq!(paper_id_from_stored("no_such_thing".into()), "blank");
    }

    #[test]
    fn every_template_belongs_to_a_listed_theme() {
        let themes = paper_themes();
        for t in paper_templates() {
            assert!(themes.contains(&t.theme), "{} 的主題不在清單裡", t.id);
        }
    }

    #[test]
    fn themes_partition_the_catalog() {
        let total: usize = paper_themes()
            .into_iter()
            .map(|t| paper_templates_for_theme(t).len())
            .sum();
        assert_eq!(total, paper_templates().len());
    }

    #[test]
    fn every_theme_has_at_least_one_paper() {
        // 空的主題會讓分頁點下去一片空白，而使用者無從得知那是不是壞了。
        for t in paper_themes() {
            assert!(!paper_templates_for_theme(t).is_empty(), "{t:?} 沒有任何紙張");
        }
    }

    #[test]
    fn ids_are_unique() {
        let mut ids: Vec<String> = paper_templates().into_iter().map(|t| t.id).collect();
        ids.sort();
        let before = ids.len();
        ids.dedup();
        assert_eq!(ids.len(), before);
    }

    #[test]
    fn doc_template_styles_all_resolve_to_a_real_paper() {
        // document-templates.json 目前只用到這三種；認不得的一律退回空白。
        let ids: Vec<String> = paper_templates().into_iter().map(|t| t.id).collect();
        for style in ["blank", "lined", "grid", "dotted", "cornell", "無此樣式"] {
            let id = doc_template_paper_id(style);
            assert!(ids.contains(&id), "{style} 對到不存在的紙張 {id}");
        }
        assert_eq!(doc_template_paper_id("無此樣式"), "blank");
    }
}

// MARK: - 常用樣板

/// 記住的常用樣板上限。
///
/// 三個：再多就不是「常用」而是第二份清單了，而使用者打開這個視窗的目的
/// 通常是「再來一份跟上次一樣的」。
pub const RECENT_TEMPLATE_LIMIT: u32 = 3;

/// 常用樣板的上限。常數不會過 FFI，所以另外開一個函式給平台層問。
#[uniffi::export]
pub fn recent_template_limit() -> u32 {
    RECENT_TEMPLATE_LIMIT
}

/// 把剛套用的樣板放到最前面，回傳新的常用清單。
///
/// # 為什麼這條規則在核心
///
/// 「去重、最近的在前、只留三個」聽起來不值得共用，但它是**會落盤的順序**：
/// 兩端各寫一份的結果是同一台裝置換個平台打開，常用樣板的順序不一樣。
/// 而且去重漏掉時的症狀很醜 —— 連續建三本同樣的筆記，常用清單就被同一個
/// 樣板佔滿。
#[uniffi::export]
pub fn recent_templates_push(existing: Vec<String>, id: String, limit: u32) -> Vec<String> {
    if id.is_empty() {
        return existing;
    }
    let cap = limit.max(1) as usize;
    let mut out = Vec::with_capacity(cap);
    out.push(id.clone());
    for item in existing {
        if item == id || item.is_empty() {
            continue;
        }
        if out.len() >= cap {
            break;
        }
        out.push(item);
    }
    out
}

#[cfg(test)]
mod recent_tests {
    use super::*;

    fn v(items: &[&str]) -> Vec<String> {
        items.iter().map(|s| s.to_string()).collect()
    }

    #[test]
    fn the_newest_goes_first() {
        let out = recent_templates_push(v(&["a", "b"]), "c".into(), 3);
        assert_eq!(out, v(&["c", "a", "b"]));
    }

    #[test]
    fn using_one_again_moves_it_up_instead_of_duplicating_it() {
        // 漏掉去重的症狀：連續建三本同樣的筆記，常用清單被同一個樣板佔滿。
        let out = recent_templates_push(v(&["a", "b", "c"]), "c".into(), 3);
        assert_eq!(out, v(&["c", "a", "b"]));
    }

    #[test]
    fn it_never_grows_past_the_limit() {
        let out = recent_templates_push(v(&["a", "b", "c"]), "d".into(), 3);
        assert_eq!(out, v(&["d", "a", "b"]));
    }

    #[test]
    fn an_empty_id_changes_nothing() {
        // 「不套用任何樣板」也會走到這裡，那一次不該擠掉別人。
        let out = recent_templates_push(v(&["a"]), String::new(), 3);
        assert_eq!(out, v(&["a"]));
    }

    #[test]
    fn a_zero_limit_still_keeps_one() {
        let out = recent_templates_push(v(&[]), "a".into(), 0);
        assert_eq!(out, v(&["a"]));
    }
}

// MARK: - 頁面規格

/// 一種紙張規格。
///
/// 尺寸是**點**（1/72 吋），與 PDF 的單位一致 —— 匯出時不必再換算一次，
/// 而每多一次換算就多一個四捨五入的機會。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiPageFormat {
    /// 與語言無關的識別字。會寫進使用者的筆記，不能改。
    pub id: String,
    /// 顯示名稱的語系鍵。
    pub title_key: String,
    pub width: f32,
    pub height: f32,
}

fn format(id: &str, key: &str, width: f32, height: f32) -> FfiPageFormat {
    FfiPageFormat {
        id: id.to_string(),
        title_key: key.to_string(),
        width,
        height,
    }
}

/// 全部規格，順序即顯示順序。
///
/// # 為什麼在核心
///
/// 頁面尺寸同時決定三件事：畫布多大、分頁在哪裡斷、匯出的 PDF 多大。
/// 這三件事分別在兩個平台的三個地方實作 —— 尺寸各寫一份的話，
/// 「畫布上看到的」與「匯出的」會對不起來，而那種偏差沒有人會在開發時發現
/// （那正是 `standard_page_size` 當初被放進核心的理由）。
///
/// A4 放第一個：它是預設，也是絕大多數人列印時要的東西。
#[uniffi::export]
pub fn page_formats() -> Vec<FfiPageFormat> {
    vec![
        // A4 210 × 297 mm。800 × 1132 是既有的 `standard_page_size`，
        // 已經寫進所有現存筆記裡，所以 A4 直式必須**原封不動**沿用它。
        format("a4", "page_format_a4", 800.0, 1132.0),
        format("a4_landscape", "page_format_a4_landscape", 1132.0, 800.0),
        // A5 148 × 210 mm，等比縮到與 A4 同一個比例。
        format("a5", "page_format_a5", 566.0, 800.0),
        // US Letter 8.5 × 11 吋。
        format("letter", "page_format_letter", 800.0, 1035.0),
        format("letter_landscape", "page_format_letter_landscape", 1035.0, 800.0),
        // US Legal 8.5 × 14 吋。
        format("legal", "page_format_legal", 800.0, 1318.0),
        // 簡報用的 16:9。
        format("slide_16_9", "page_format_slide", 1280.0, 720.0),
        // 正方形：社群圖卡與速寫。
        format("square", "page_format_square", 900.0, 900.0),
    ]
}

/// 依識別字取規格。認不得就回 A4 —— 舊筆記沒有這個欄位，
/// 而它們全部都是用 A4 的尺寸寫的。
#[uniffi::export]
pub fn page_format(id: String) -> FfiPageFormat {
    page_formats()
        .into_iter()
        .find(|f| f.id == id)
        .unwrap_or_else(|| page_formats().remove(0))
}

/// 預設規格的識別字。
#[uniffi::export]
pub fn default_page_format_id() -> String {
    "a4".to_string()
}

#[cfg(test)]
mod format_tests {
    use super::*;

    #[test]
    fn a4_is_first_and_matches_the_existing_page_size() {
        // **這一條不能改。** 800 × 1132 已經寫進所有現存筆記的座標裡，
        // 動它就是把每一本舊筆記的內容位置一起移掉。
        let first = &page_formats()[0];
        assert_eq!(first.id, "a4");
        assert_eq!((first.width, first.height), (800.0, 1132.0));
        assert_eq!(default_page_format_id(), "a4");
    }

    #[test]
    fn an_unknown_id_falls_back_to_a4_instead_of_a_zero_sized_page() {
        // 舊筆記沒有這個欄位。回一個零尺寸的頁面會讓畫布整個消失。
        let fallback = page_format("沒這種規格".into());
        assert_eq!(fallback.id, "a4");
        assert!(fallback.width > 0.0 && fallback.height > 0.0);
    }

    #[test]
    fn every_format_has_a_positive_size_and_a_unique_id() {
        let mut ids: Vec<String> = Vec::new();
        for f in page_formats() {
            assert!(f.width > 0.0 && f.height > 0.0, "{} 的尺寸不合法", f.id);
            assert!(!ids.contains(&f.id), "{} 重複", f.id);
            ids.push(f.id);
        }
    }

    #[test]
    fn landscape_is_the_portrait_size_turned_round() {
        let portrait = page_format("a4".into());
        let landscape = page_format("a4_landscape".into());
        assert_eq!(portrait.width, landscape.height);
        assert_eq!(portrait.height, landscape.width);
    }
}
