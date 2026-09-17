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
