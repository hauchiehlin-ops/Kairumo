//! 主題專屬工具的資料目錄。
//!
//! 三個主題（美學視覺、工程製程、數位體驗）各自提供一組「按一下就插進畫布」
//! 的素材：配色卡、工程標註、材料規格、線框元件、互動流程標籤。
//!
//! # 為什麼在核心
//!
//! 這些原本全部寫死在 `apple/Sources/ThemeSpecificToolsView.swift` 裡，
//! Android 完全沒有。而且那份資料有兩個問題，一併在這裡修掉：
//!
//! 1. **寫死繁體中文**。材料名稱、線框元件名、手勢標籤都是中文字面值，
//!    在一個已經翻成六國語系的面板裡出現一整區中文。這裡一律給**語系鍵**，
//!    由平台層查表。
//! 2. **插入的是圖片**。使用者回報過「插入主題工具後不知道怎麼利用，
//!    因為它只是一張圖片，也不能編輯」。所以這裡對每一項都標明它應該
//!    插成什麼（[`FfiThemeInsertKind`]）—— 能用文字表達的一律插文字方塊，
//!    之後改得動數字、字級與顏色。
//!
//! 核心只提供**資料**，不畫任何東西：繪製是平台的事，資料不是。

/// 主題分類。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiThemeTab {
    /// 美學視覺
    Aesthetic,
    /// 工程製程
    Engineering,
    /// 數位體驗
    Digital,
}

/// 分頁標題的語系鍵。
#[uniffi::export]
pub fn theme_tab_key(tab: FfiThemeTab) -> String {
    match tab {
        FfiThemeTab::Aesthetic => "theme_aesthetic",
        FfiThemeTab::Engineering => "theme_engineering",
        FfiThemeTab::Digital => "theme_digital",
    }
    .to_string()
}

/// 全部分頁，順序即顯示順序。
#[uniffi::export]
pub fn theme_tabs() -> Vec<FfiThemeTab> {
    vec![
        FfiThemeTab::Aesthetic,
        FfiThemeTab::Engineering,
        FfiThemeTab::Digital,
    ]
}

/// 插入之後在畫布上是什麼東西。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiThemeInsertKind {
    /// 文字方塊。可以就地改字、換字級、縮放、旋轉。
    TextBox,
    /// 由平台算繪的圖形卡片。只有純視覺、沒有文字可編輯的項目才用這個。
    Card,
}

/// 一組配色卡。
///
/// 與 [`crate::ffi::designer_palette`] 不同：那是**選色**用的 8 色盤，
/// 這是插進畫布當**構圖參考**的 5 色卡，兩者用途不同，不要合併。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiThemePalette {
    /// 配色名稱的語系鍵。
    pub name_key: String,
    /// 5 個色碼，順序即顯示順序。
    pub hexes: Vec<String>,
}

/// 一個可插入的素材。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiThemeItem {
    /// 顯示名稱的語系鍵。
    pub title_key: String,
    /// 與語言無關的前綴或符號（尺寸標註、emoji…）。沒有就是空字串。
    ///
    /// 平台層插入時把它接在查表得到的文字前面 —— 這樣同一個項目在
    /// 日文介面插進去就是日文，而符號不變。
    pub symbol: String,
    pub kind: FfiThemeInsertKind,
}

/// 材料規格卡。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiThemeMaterial {
    /// 材料牌號。**這一項刻意不走語系鍵**：SUS304、AL6061-T6 是國際通用的
    /// 材料代號，翻譯它反而讓工程師認不出來。
    pub designation: String,
    /// 特性標籤的語系鍵。
    pub trait_key: String,
    /// 工藝指標的語系鍵。
    pub spec_key: String,
}

/// 美學：可插入的配色卡。
#[uniffi::export]
pub fn theme_palettes() -> Vec<FfiThemePalette> {
    vec![
        FfiThemePalette {
            name_key: "theme_palette_trend".into(),
            hexes: hexes(&["#F79477", "#6EA6D1", "#F2C473", "#619E8A", "#525473"]),
        },
        FfiThemePalette {
            name_key: "theme_palette_morandi".into(),
            hexes: hexes(&["#C7C2BD", "#AEAB9E", "#94A19E", "#B8A8A6", "#7D7B75"]),
        },
        FfiThemePalette {
            name_key: "theme_palette_bauhaus".into(),
            hexes: hexes(&["#D9332E", "#1F59AD", "#F5C226", "#2E2E2E", "#EBE6D9"]),
        },
        FfiThemePalette {
            name_key: "theme_palette_cyberpunk".into(),
            hexes: hexes(&["#FF007A", "#00F5FF", "#8C1FF2", "#FCE800", "#120D26"]),
        },
    ]
}

/// 工程：尺寸與公差標註。
///
/// `symbol` 就是要插進畫布的字串本身 —— 這些是製圖符號與數值，
/// 與語言無關，`title_key` 只用在面板上告訴使用者那是什麼。
#[uniffi::export]
pub fn theme_dimension_callouts() -> Vec<FfiThemeItem> {
    [
        ("dimension_callout_linear", "↔ 120.0 ±0.05 mm"),
        ("dimension_callout_diameter", "Ø 48.0 H7 mm"),
        ("dimension_callout_radius", "R 12.5 mm"),
        ("dimension_callout_flatness", "⏥ 0.02 A"),
        ("dimension_callout_balloon1", "① —"),
        ("dimension_callout_balloon2", "② —"),
    ]
    .into_iter()
    .map(|(key, symbol)| FfiThemeItem {
        title_key: key.into(),
        symbol: symbol.into(),
        // 一律文字方塊。插成圖片的話 120.0 與 ±0.05 都改不了，
        // 而一張改不了數字的標註等於沒有用（使用者回報過）。
        kind: FfiThemeInsertKind::TextBox,
    })
    .collect()
}

/// 工程：材料與工藝規格卡。
#[uniffi::export]
pub fn theme_materials() -> Vec<FfiThemeMaterial> {
    [
        ("SUS304", "material_sus304_trait", "material_sus304_spec"),
        ("AL6061-T6", "material_al6061_trait", "material_al6061_spec"),
        ("PC+ABS", "material_pcabs_trait", "material_pcabs_spec"),
        ("POM", "material_pom_trait", "material_pom_spec"),
        ("SKD11", "material_skd11_trait", "material_skd11_spec"),
    ]
    .into_iter()
    .map(|(designation, trait_key, spec_key)| FfiThemeMaterial {
        designation: designation.into(),
        trait_key: trait_key.into(),
        spec_key: spec_key.into(),
    })
    .collect()
}

/// 數位：UI 線框元件。
///
/// 這些是**圖形**，沒有可編輯的文字內容，所以是唯一插成卡片的一類。
/// `symbol` 是平台算繪時用的元件代號。
#[uniffi::export]
pub fn theme_wireframes() -> Vec<FfiThemeItem> {
    [
        ("wireframe_navbar", "navbar"),
        ("wireframe_tabbar", "tabbar"),
        ("wireframe_button", "button"),
        ("wireframe_input", "input"),
        ("wireframe_card", "card"),
        ("wireframe_modal", "modal"),
    ]
    .into_iter()
    .map(|(key, code)| FfiThemeItem {
        title_key: key.into(),
        symbol: code.into(),
        kind: FfiThemeInsertKind::Card,
    })
    .collect()
}

/// 數位：互動與流程標籤。
#[uniffi::export]
pub fn theme_gestures() -> Vec<FfiThemeItem> {
    [
        ("gesture_tap", "👉"),
        ("gesture_swipe", "👈"),
        ("gesture_long_press", "⏱️"),
        ("gesture_decision", "◇"),
        ("gesture_loading", "↻"),
        ("gesture_success", "✅"),
    ]
    .into_iter()
    .map(|(key, emoji)| FfiThemeItem {
        title_key: key.into(),
        symbol: emoji.into(),
        kind: FfiThemeInsertKind::TextBox,
    })
    .collect()
}

fn hexes(list: &[&str]) -> Vec<String> {
    list.iter().map(|s| s.to_string()).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_palette_has_five_valid_colours() {
        let palettes = theme_palettes();
        assert_eq!(palettes.len(), 4);
        for p in palettes {
            assert_eq!(p.hexes.len(), 5, "{} 的顏色數不對", p.name_key);
            for hex in &p.hexes {
                assert!(hex.starts_with('#') && hex.len() == 7, "壞的色碼：{hex}");
            }
        }
    }

    #[test]
    fn every_label_is_a_key_not_literal_text() {
        // 這是整個模組存在的主要理由之一：原本那些名稱是寫死的繁體中文。
        // 鍵一律是 ASCII 小寫加底線，混進中文字就會在這裡當場失敗。
        let keys: Vec<String> = theme_palettes()
            .into_iter()
            .map(|p| p.name_key)
            .chain(
                theme_dimension_callouts()
                    .into_iter()
                    .chain(theme_wireframes())
                    .chain(theme_gestures())
                    .map(|i| i.title_key),
            )
            .chain(
                theme_materials()
                    .into_iter()
                    .flat_map(|m| [m.trait_key, m.spec_key]),
            )
            .collect();
        assert!(!keys.is_empty());
        for key in keys {
            assert!(
                key.chars()
                    .all(|c| c.is_ascii_lowercase() || c == '_' || c.is_ascii_digit()),
                "不是語系鍵：{key}"
            );
        }
    }

    #[test]
    fn dimension_callouts_insert_editable_text() {
        // 使用者回報：「插入主題工具後不知道怎麼利用，因為它只是一張圖片，
        // 也不能編輯」。標註一旦變成點陣圖，數字就改不了。
        for item in theme_dimension_callouts() {
            assert_eq!(item.kind, FfiThemeInsertKind::TextBox, "{}", item.title_key);
            assert!(!item.symbol.is_empty());
        }
    }

    #[test]
    fn material_designations_are_not_translated() {
        // SUS304 翻成中文反而讓工程師認不出來 —— 牌號是國際代號，不是介面文字。
        for m in theme_materials() {
            assert!(
                m.designation.is_ascii(),
                "牌號不該被在地化：{}",
                m.designation
            );
        }
    }

    #[test]
    fn tabs_and_their_keys_line_up() {
        let tabs = theme_tabs();
        assert_eq!(tabs.len(), 3);
        for tab in tabs {
            assert!(theme_tab_key(tab).starts_with("theme_"));
        }
    }
}
