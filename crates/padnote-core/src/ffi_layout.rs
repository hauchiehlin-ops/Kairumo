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
/// 使用者拖動界線時，側欄能縮到多窄、拉到多寬。
///
/// 下限 200：再窄的話頁面縮圖小到看不出是哪一頁，而側欄存在的理由就是
/// 「用看的翻到第 9 頁」。上限 520：側欄比一張 A4 縮圖還寬之後，多出來的
/// 空間只是留白，而畫布被它吃掉了。
const SIDEBAR_MIN_WIDTH: f32 = 200.0;
const SIDEBAR_MAX_WIDTH: f32 = 520.0;

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

/// 使用者拖動界線之後的側欄寬度。
///
/// # 為什麼要夾
///
/// 拖曳沒有天然的終點：手指往左滑到底，側欄變成 0 寬，裡面的東西全部
/// 不見，而使用者不會知道那是「拖過頭」還是「壞了」；往右滑到底，
/// 畫布被擠成一條縫。兩端都要有停住的地方。
///
/// **內容那一側的下限優先於側欄的下限。** 視窗本來就窄的時候，寧可側欄
/// 只有最小寬度，也不要讓畫布小於能寫字的寬度 —— 畫布才是這個畫面的主體。
#[uniffi::export]
pub fn sidebar_clamp_width(desired: f32, total: f32) -> f32 {
    if !desired.is_finite() || !total.is_finite() {
        return SIDEBAR_WIDTH;
    }
    let ceiling = (total - MIN_CONTENT_BESIDE_SIDEBAR).min(SIDEBAR_MAX_WIDTH);
    if ceiling <= SIDEBAR_MIN_WIDTH {
        return SIDEBAR_MIN_WIDTH;
    }
    desired.clamp(SIDEBAR_MIN_WIDTH, ceiling)
}

/// 側欄可拖動的範圍，給平台層畫拖曳把手用。
#[uniffi::export]
pub fn sidebar_width_bounds() -> Vec<f32> {
    vec![SIDEBAR_MIN_WIDTH, SIDEBAR_MAX_WIDTH]
}

/// 側欄內文字要放大多少倍。
///
/// 側欄變寬時只有縮圖跟著變大、文字維持原樣的話，一條 500pt 寬的側欄上會
/// 出現 9pt 的頁碼 —— 看起來不是「寬敞」，是「沒排版」。所以字跟著走。
///
/// 上下限比寬度的比例保守（0.9–1.3）：字級是可讀性，不是比例尺，
/// 等比放大會讓最寬的時候變成大字報。
#[uniffi::export]
pub fn sidebar_content_scale(width: f32) -> f32 {
    if !width.is_finite() || width <= 0.0 {
        return 1.0;
    }
    (width / SIDEBAR_WIDTH).clamp(0.9, 1.3)
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

    #[test]
    fn dragging_the_divider_stops_at_both_ends() {
        let total = 1200.0;
        assert_eq!(sidebar_clamp_width(0.0, total), 200.0);
        assert_eq!(sidebar_clamp_width(-500.0, total), 200.0);
        assert_eq!(sidebar_clamp_width(9999.0, total), 520.0);
        assert_eq!(sidebar_clamp_width(360.0, total), 360.0);
    }

    #[test]
    fn the_canvas_keeps_its_minimum_before_the_sidebar_does() {
        // 820 寬：側欄拉到 520 的話畫布只剩 300，寫不了字。上限被壓到 340。
        let w = sidebar_clamp_width(520.0, 820.0);
        assert_eq!(w, 340.0);
        assert!(820.0 - w >= 480.0);
    }

    #[test]
    fn a_window_too_narrow_to_share_falls_back_to_the_minimum() {
        // 這種寬度本來就不該並排（sidebar_is_inline 是 false），
        // 但寬度仍然要是一個能用的數字，不能是 0 或負數。
        for total in [320.0, 500.0, 600.0] {
            assert_eq!(sidebar_clamp_width(400.0, total), 200.0);
        }
    }

    #[test]
    fn a_nonsense_width_never_leaks_out() {
        assert_eq!(sidebar_clamp_width(f32::NAN, 1200.0), 280.0);
        assert_eq!(sidebar_clamp_width(300.0, f32::NAN), 280.0);
        assert_eq!(sidebar_content_scale(f32::NAN), 1.0);
        assert_eq!(sidebar_content_scale(0.0), 1.0);
    }

    #[test]
    fn the_text_grows_with_the_sidebar_but_not_without_limit() {
        assert_eq!(sidebar_content_scale(280.0), 1.0);
        assert!(sidebar_content_scale(200.0) < 1.0);
        assert!(sidebar_content_scale(420.0) > 1.0);
        // 520 是最寬的側欄，字級不該超過 1.3 倍。
        assert_eq!(sidebar_content_scale(520.0), 1.3);
    }
}
