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
    /// 通用基礎
    General,
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
#[uniffi::export]
pub fn paper_templates() -> Vec<FfiPaperTemplate> {
    use FfiPaperTheme::{Aesthetic, Digital, Engineering, General};
    vec![
        // 通用基礎
        entry("blank", "tmpl_blank", "doc.plaintext", "Article", PageStyle::Blank, General),
        entry("grid", "tmpl_grid", "circle.grid.3x3", "GridOn", PageStyle::Grid, General),
        entry("lined", "tmpl_lined", "line.horizontal.3", "Notes", PageStyle::Lined, General),
        entry("cornell", "tmpl_cornell", "sidebar.left", "ViewSidebar", PageStyle::Cornell, General),
        // 美學視覺
        entry(
            "dot_grid_fine", "tmpl_dot_grid_fine", "circle.dotted", "BlurOn",
            PageStyle::Dotted, Aesthetic,
        ),
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
