//! 多國語系（工作項 S-50）。
//!
//! 支援六種語言：**英文（預設）**、繁體中文、簡體中文、日文、韓文、泰文。
//!
//! ## 設計核心：型別系統強制完整
//! 每個字串是一個 `[&str; LOCALE_COUNT]` 陣列 —— **少填一種語言就編譯不過**。
//!
//! 多數 i18n 方案用 key→map，漏翻譯要等執行期才發現（或永遠不發現，
//! 因為 fallback 會悄悄顯示英文）。這裡把它變成編譯期錯誤。
//!
//! ## 為什麼英文是預設
//! 英文是唯一能讓其他五種語言的使用者「至少看得懂大概」的語言。
//! 缺翻譯時退回英文，比退回中文對日韓泰使用者友善。

pub mod catalog;

pub use catalog::{Key, text};

/// 支援的語言。
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default, Hash)]
pub enum Locale {
    /// 英文。**預設與 fallback 語言。**
    #[default]
    English,
    /// 繁體中文（台灣）
    TraditionalChinese,
    /// 簡體中文
    SimplifiedChinese,
    Japanese,
    Korean,
    Thai,
}

/// 語言數量。字串表的陣列長度，**改這個數字會讓所有字串編譯失敗**，
/// 強迫補上新語言的翻譯。
pub const LOCALE_COUNT: usize = 6;

impl Locale {
    pub const ALL: [Self; LOCALE_COUNT] = [
        Self::English,
        Self::TraditionalChinese,
        Self::SimplifiedChinese,
        Self::Japanese,
        Self::Korean,
        Self::Thai,
    ];

    /// 字串表中的索引。
    pub const fn index(self) -> usize {
        match self {
            Self::English => 0,
            Self::TraditionalChinese => 1,
            Self::SimplifiedChinese => 2,
            Self::Japanese => 3,
            Self::Korean => 4,
            Self::Thai => 5,
        }
    }

    /// BCP 47 標籤。
    pub const fn tag(self) -> &'static str {
        match self {
            Self::English => "en",
            Self::TraditionalChinese => "zh-Hant",
            Self::SimplifiedChinese => "zh-Hans",
            Self::Japanese => "ja",
            Self::Korean => "ko",
            Self::Thai => "th",
        }
    }

    /// 語言自己的名稱。
    ///
    /// 語言選單要用**該語言自己的寫法** —— 看不懂目前介面語言的使用者，
    /// 才找得到自己的語言。
    pub const fn endonym(self) -> &'static str {
        match self {
            Self::English => "English",
            Self::TraditionalChinese => "繁體中文",
            Self::SimplifiedChinese => "简体中文",
            Self::Japanese => "日本語",
            Self::Korean => "한국어",
            Self::Thai => "ไทย",
        }
    }

    /// 從系統語言標籤解析。
    ///
    /// 比對由細到粗：先看完整標籤，再看語言子標籤。
    /// 中文特別處理 —— `zh-TW`、`zh-HK`、`zh-MO` 都該給繁體。
    pub fn from_tag(tag: &str) -> Option<Self> {
        let lower = tag.to_ascii_lowercase().replace('_', "-");

        if lower.starts_with("zh") {
            return Some(
                if lower.contains("hant")
                    || lower.contains("-tw")
                    || lower.contains("-hk")
                    || lower.contains("-mo")
                {
                    Self::TraditionalChinese
                } else {
                    Self::SimplifiedChinese
                },
            );
        }
        Some(match lower.split('-').next()? {
            "en" => Self::English,
            "ja" => Self::Japanese,
            "ko" => Self::Korean,
            "th" => Self::Thai,
            _ => return None,
        })
    }

    /// 解析系統語言，無法辨識時退回英文。
    pub fn from_tag_or_default(tag: &str) -> Self {
        Self::from_tag(tag).unwrap_or_default()
    }

    /// 此語言的文字是否偏長。
    ///
    /// 泰文與日文的字串常比英文長 30–50%，固定寬度的按鈕會被撐爆或截斷。
    /// UI 應據此讓工具列標籤改用圖示或允許換行。
    pub fn tends_to_be_long(self) -> bool {
        matches!(self, Self::Thai | Self::Japanese)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn english_is_the_default() {
        // 英文是唯一能讓其他五種語言的使用者至少看懂大概的語言。
        assert_eq!(Locale::default(), Locale::English);
        assert_eq!(Locale::English.index(), 0);
    }

    #[test]
    fn all_locales_have_distinct_indices() {
        let mut seen: Vec<usize> = Locale::ALL.iter().map(|l| l.index()).collect();
        seen.sort_unstable();
        seen.dedup();
        assert_eq!(seen.len(), LOCALE_COUNT);
        assert_eq!(seen, (0..LOCALE_COUNT).collect::<Vec<_>>());
    }

    #[test]
    fn chinese_variants_map_correctly() {
        // zh-TW / zh-HK / zh-MO 都該給繁體。用 zh 開頭一律給簡體是常見錯誤。
        for tag in ["zh-TW", "zh-Hant", "zh-HK", "zh_MO", "zh-Hant-TW"] {
            assert_eq!(
                Locale::from_tag(tag),
                Some(Locale::TraditionalChinese),
                "{tag}"
            );
        }
        for tag in ["zh-CN", "zh", "zh-Hans", "zh-SG"] {
            assert_eq!(
                Locale::from_tag(tag),
                Some(Locale::SimplifiedChinese),
                "{tag}"
            );
        }
    }

    #[test]
    fn region_subtags_are_ignored_for_other_languages() {
        assert_eq!(Locale::from_tag("en-GB"), Some(Locale::English));
        assert_eq!(Locale::from_tag("ja-JP"), Some(Locale::Japanese));
        assert_eq!(Locale::from_tag("th-TH"), Some(Locale::Thai));
    }

    #[test]
    fn unknown_languages_fall_back_to_english() {
        assert_eq!(Locale::from_tag("de-DE"), None);
        assert_eq!(Locale::from_tag_or_default("de-DE"), Locale::English);
        assert_eq!(Locale::from_tag_or_default(""), Locale::English);
    }

    #[test]
    fn endonyms_are_written_in_their_own_language() {
        // 語言選單要用該語言自己的寫法 —— 否則使用者找不到自己的語言。
        assert_eq!(Locale::Japanese.endonym(), "日本語");
        assert_eq!(Locale::Korean.endonym(), "한국어");
        assert_eq!(Locale::Thai.endonym(), "ไทย");
        assert_eq!(Locale::TraditionalChinese.endonym(), "繁體中文");
    }

    #[test]
    fn tags_are_valid_bcp47() {
        for l in Locale::ALL {
            let t = l.tag();
            assert!(!t.is_empty());
            assert!(t.chars().all(|c| c.is_ascii_alphanumeric() || c == '-'));
            assert_eq!(Locale::from_tag(t), Some(l), "{t} 應能解析回自己");
        }
    }

    #[test]
    fn long_text_languages_are_flagged_for_layout() {
        // 泰文與日文常比英文長 30–50%，固定寬度按鈕會爆版。
        assert!(Locale::Thai.tends_to_be_long());
        assert!(!Locale::English.tends_to_be_long());
    }
}
