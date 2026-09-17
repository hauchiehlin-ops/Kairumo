//! 版面尺寸級別：一組數字，兩個平台共用。
//!
//! # 為什麼在核心
//!
//! 「內容最大寬度 1040、外距斷點 420/900」這組數字原本在
//! `apple/Sources/DesignSystem.swift` 與 `android/.../ui/DesignSystem.kt`
//! 各有一份 —— 現在是一樣的，而兩份手抄的常數會一樣多久，沒有人知道。
//!
//! 更重要的是**尺寸級別本身兩邊都沒有**。Apple 的編輯器有一條 280pt 的
//! 結構欄並排在畫布旁邊，Android 的編輯器是一個 `Column`，畫布
//! `fillMaxWidth()` —— 於是同一本筆記在平板上，一邊是雙欄工作區，
//! 一邊是把手機版拉寬。而 Android 的主要對象裡有平板與摺疊機。
//!
//! 所以級別、門檻、側欄寬度、一排放幾張卡片，全部從這裡出。
//!
//! # 單位
//!
//! 一律是**與密度無關的邏輯單位**：Apple 的 pt、Android 的 dp。
//! 兩者在這件事上是同一個東西，不要傳像素進來。

/// 可用寬度的級別。門檻取 Material 的 600 / 840，與 iPad 的分割視窗
/// 寬度也對得起來（1/3 分割約 320–375、1/2 約 507–678、全螢幕 ≥ 834）。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiSizeClass {
    /// 手機直向、分割視窗的窄欄。單欄，側欄用覆蓋的。
    Compact,
    /// 手機橫向、小平板、摺疊機闔起來、1/2 分割。
    Medium,
    /// 平板橫向、摺疊機展開、桌機視窗。側欄並排。
    Expanded,
}

/// 一次把版面要用的數字全部算好。
///
/// 分開成好幾個函式的話，平台層會挑著用 —— 用了 `gutter` 忘了
/// `content_max_width`，而那種漏掉只有把畫面叫出來才看得見。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiLayoutMetrics {
    pub size_class: FfiSizeClass,
    /// 內容左右外距。
    pub gutter: f32,
    /// 一般內容的最大寬度；超過就置中留白。
    pub content_max_width: f32,
    /// 以文字為主的內容的最大寬度（比一般更窄，維持可讀行長）。
    pub readable_max_width: f32,
    /// 結構側欄的寬度。
    pub sidebar_width: f32,
    /// 側欄要不要**並排**在內容旁邊。
    ///
    /// false 代表這個寬度塞不下兩欄，側欄要用覆蓋（抽屜）的方式出現 ——
    /// 硬並排的結果是畫布只剩兩指寬，寫字的地方比工具列還窄。
    pub sidebar_is_inline: bool,
    /// 筆記卡片一排放幾張。
    pub note_columns: u32,
}

/// 內容最大寬度。13 吋平板橫向是 1376pt，一列文字橫跨全寬時，
/// 眼睛要掃過 1300pt 才讀完一行 —— 那不是用到了空間，是沒有版面。
const CONTENT_MAX_WIDTH: f32 = 1040.0;
const READABLE_MAX_WIDTH: f32 = 720.0;
/// 結構側欄寬度。與 Apple 端既有的 280 一致，不要另外挑一個數字。
const SIDEBAR_WIDTH: f32 = 280.0;
/// 側欄並排之後，內容至少要留這麼寬才值得並排。
const MIN_CONTENT_BESIDE_SIDEBAR: f32 = 480.0;

/// 這個寬度屬於哪一級。
#[uniffi::export]
pub fn layout_size_class(width: f32) -> FfiSizeClass {
    if width < 600.0 {
        FfiSizeClass::Compact
    } else if width < 840.0 {
        FfiSizeClass::Medium
    } else {
        FfiSizeClass::Expanded
    }
}

/// 依可用寬度決定左右外距。窄螢幕留少一點，寬螢幕留多一點。
#[uniffi::export]
pub fn layout_gutter(width: f32) -> f32 {
    if width < 420.0 {
        12.0
    } else if width < 900.0 {
        16.0
    } else {
        24.0
    }
}

/// 一排放得下幾個至少 `min_item` 寬的項目。
///
/// 與 Apple 的 `GridItem(.adaptive(minimum:))`、Android 的 `DS.columns`
/// 是同一個意思。上限存在的理由：卡片可以無限變寬，但一排十二張
/// 筆記卡片沒有人掃得完。
#[uniffi::export]
pub fn layout_columns(available: f32, min_item: f32, max: u32, gap: f32) -> u32 {
    if available <= 0.0 || min_item <= 0.0 || max == 0 {
        return 1;
    }
    let fit = ((available + gap) / (min_item + gap)).floor();
    (fit.max(1.0) as u32).min(max)
}

/// 版面要用的數字，一次算好。
#[uniffi::export]
pub fn layout_metrics(width: f32) -> FfiLayoutMetrics {
    let size_class = layout_size_class(width);
    let gutter = layout_gutter(width);
    let content = width.min(CONTENT_MAX_WIDTH) - gutter * 2.0;

    // 並排的條件是「扣掉側欄之後，內容還剩得下 480」——
    // 只看級別的話，840 寬的摺疊機會並排出一條 560 的畫布，勉強及格；
    // 但使用者把視窗拉到 700 時級別還是 Medium，卻已經塞不下了。
    // 所以用實際寬度算，不要用級別查表。
    let sidebar_is_inline = width - SIDEBAR_WIDTH >= MIN_CONTENT_BESIDE_SIDEBAR;

    // 筆記卡片：最小 220，最多四排。手機一排、平板橫向四排。
    let note_columns = layout_columns(content.max(0.0), 220.0, 4, 12.0);

    FfiLayoutMetrics {
        size_class,
        gutter,
        content_max_width: CONTENT_MAX_WIDTH,
        readable_max_width: READABLE_MAX_WIDTH,
        sidebar_width: SIDEBAR_WIDTH,
        sidebar_is_inline,
        note_columns,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_thresholds_are_where_we_said_they_are() {
        assert_eq!(layout_size_class(320.0), FfiSizeClass::Compact);
        assert_eq!(layout_size_class(599.9), FfiSizeClass::Compact);
        assert_eq!(layout_size_class(600.0), FfiSizeClass::Medium);
        assert_eq!(layout_size_class(839.9), FfiSizeClass::Medium);
        assert_eq!(layout_size_class(840.0), FfiSizeClass::Expanded);
        assert_eq!(layout_size_class(1376.0), FfiSizeClass::Expanded);
    }

    #[test]
    fn a_phone_never_gets_an_inline_sidebar() {
        // 並排的話畫布只剩兩指寬，寫字的地方比工具列還窄。
        for width in [320.0, 375.0, 414.0, 430.0] {
            assert!(!layout_metrics(width).sidebar_is_inline, "{width} 不該並排");
        }
    }

    #[test]
    fn a_tablet_in_landscape_gets_an_inline_sidebar() {
        for width in [1024.0, 1194.0, 1376.0] {
            assert!(layout_metrics(width).sidebar_is_inline, "{width} 該並排");
        }
    }

    #[test]
    fn the_inline_rule_follows_the_real_width_not_the_class() {
        // 760 是 Medium，但扣掉 280 的側欄只剩 480 —— 剛好及格。
        assert!(layout_metrics(760.0).sidebar_is_inline);
        // 700 也是 Medium，扣掉側欄剩 420，塞不下。
        assert!(!layout_metrics(700.0).sidebar_is_inline);
    }

    #[test]
    fn columns_never_collapse_to_zero_or_explode() {
        assert_eq!(layout_columns(0.0, 220.0, 4, 12.0), 1);
        assert_eq!(layout_columns(-5.0, 220.0, 4, 12.0), 1);
        assert_eq!(layout_columns(100.0, 220.0, 4, 12.0), 1);
        assert_eq!(layout_columns(9999.0, 220.0, 4, 12.0), 4);
        assert_eq!(layout_columns(500.0, 220.0, 4, 12.0), 2);
    }

    #[test]
    fn a_phone_shows_one_column_and_a_wide_tablet_more() {
        assert_eq!(layout_metrics(375.0).note_columns, 1);
        assert!(layout_metrics(1024.0).note_columns >= 3);
        assert!(layout_metrics(1376.0).note_columns >= 3);
    }

    #[test]
    fn the_gutter_grows_with_the_window() {
        assert!(layout_gutter(320.0) < layout_gutter(700.0));
        assert!(layout_gutter(700.0) < layout_gutter(1200.0));
    }

    #[test]
    fn content_never_exceeds_the_readable_cap() {
        // 13 吋平板橫向：內容寬度要被 1040 夾住，不是 1376。
        let m = layout_metrics(1376.0);
        assert_eq!(m.content_max_width, 1040.0);
        assert!(m.readable_max_width < m.content_max_width);
    }
}
