//! 文字工作室的符號盤（工作項 S-63）。
//!
//! # 為什麼這幾個陣列放在核心
//!
//! 它們只是靜態字串，看起來像純 UI 資料。但兩個平台各寫一份的後果，
//! 這個專案已經踩過好幾次：**兩邊會慢慢分岔**。症狀會是「iPad 上插得到
//! 的那個符號，在 Android 上找不到」—— 而且沒有人會發現，因為兩邊各自
//! 看起來都很完整。
//!
//! 放在這裡之後，加一個符號就是兩個平台一起加。與 `ffi_link`、
//! `ffi_math` 同一個判斷：**只要兩邊要給出同一個答案，答案就放核心。**
//!
//! # 為什麼不放 i18n 目錄
//!
//! 符號不是譯文。`※`、`∑`、`Ⅶ` 在六個語系下都是同一個字元，放進字串表
//! 會逼譯者去「翻譯」一堆不該翻的東西，而且每加一個符號就多六個鍵。

/// 符號的分類。
#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum FfiSymbolCategory {
    /// 特殊符號（箭頭、星號、版權…）。
    Special,
    /// 標點符號（全形引號、書名號、破折號…）。
    Punctuation,
    /// 數學符號（運算子、集合、希臘字母）。
    Math,
    /// 羅馬數字（大寫與小寫）。
    Roman,
}

/// 某一類符號的完整清單，順序固定。
///
/// 順序固定是刻意的：使用者會記住「星號在左上角第一個」。每次啟動順序都
/// 不一樣的話，這個面板就只能一個一個找。
#[uniffi::export]
pub fn symbol_palette(category: FfiSymbolCategory) -> Vec<String> {
    let items: &[&str] = match category {
        FfiSymbolCategory::Special => &[
            "★", "☆", "✓", "✗", "▲", "▼", "◆", "◇", "●", "○", "→", "←", "↑", "↓", "⇄", "⇒", "※",
            "§", "¶", "©", "®", "™", "℃", "℉", "♥", "♦",
        ],
        FfiSymbolCategory::Punctuation => &[
            "「", "」", "『", "』", "《", "》", "〈", "〉", "【", "】", "〔", "〕", "——", "……",
            "～", "·", "；", "：", "？！", "\u{201C}", "\u{201D}", "\u{2018}", "\u{2019}",
        ],
        FfiSymbolCategory::Math => &[
            "±", "×", "÷", "≠", "≈", "≤", "≥", "∑", "∏", "√", "∫", "∂", "∞", "∈", "∉", "⊂", "⊆",
            "∪", "∩", "α", "β", "γ", "θ", "λ", "π", "σ", "ω", "Δ", "Ω", "°",
        ],
        FfiSymbolCategory::Roman => &[
            "Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ", "Ⅴ", "Ⅵ", "Ⅶ", "Ⅷ", "Ⅸ", "Ⅹ", "Ⅺ", "Ⅻ", "ⅰ", "ⅱ", "ⅲ", "ⅳ", "ⅴ",
            "ⅵ", "ⅶ", "ⅷ", "ⅸ", "ⅹ",
        ],
    };
    items.iter().map(|s| (*s).to_string()).collect()
}

/// 四個分類，依面板上的顯示順序。
#[uniffi::export]
pub fn symbol_categories() -> Vec<FfiSymbolCategory> {
    vec![
        FfiSymbolCategory::Special,
        FfiSymbolCategory::Punctuation,
        FfiSymbolCategory::Math,
        FfiSymbolCategory::Roman,
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_category_has_symbols() {
        for category in symbol_categories() {
            assert!(
                !symbol_palette(category).is_empty(),
                "{category:?} 這一類是空的 —— 面板上會出現一個沒有東西的分頁"
            );
        }
    }

    #[test]
    fn no_category_contains_duplicates() {
        // 同一個符號出現兩次，使用者會以為自己看錯了。
        for category in symbol_categories() {
            let list = symbol_palette(category);
            let mut sorted = list.clone();
            sorted.sort();
            sorted.dedup();
            assert_eq!(sorted.len(), list.len(), "{category:?} 裡有重複的符號");
        }
    }

    #[test]
    fn nothing_is_blank_or_whitespace() {
        // 空字串在面板上是一顆按不出東西的空格子。
        for category in symbol_categories() {
            for symbol in symbol_palette(category) {
                assert!(!symbol.trim().is_empty(), "{category:?} 裡有空白項目");
            }
        }
    }

    #[test]
    fn the_curly_quotes_are_the_typographic_ones() {
        // 這四個很容易被打成半形的 " 與 '。打錯的話，使用者插進去的是
        // 程式碼引號而不是中文排版用的引號，而兩者在畫面上很像。
        let marks = symbol_palette(FfiSymbolCategory::Punctuation);
        for expected in ["\u{201C}", "\u{201D}", "\u{2018}", "\u{2019}"] {
            assert!(marks.contains(&expected.to_string()), "缺了 {expected}");
        }
        assert!(!marks.contains(&"\"".to_string()), "不該有半形雙引號");
    }
}
