//! 簡繁轉換與修正表。

use zhconv::{Variant, zhconv};

/// 目標字體。
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub enum Script {
    /// 台灣正體（預設）
    #[default]
    TraditionalTw,
    /// 香港繁體
    TraditionalHk,
    /// 一般繁體（不套地區詞）
    Traditional,
    /// 不轉換，保持原樣
    None,
}

impl Script {
    fn variant(self) -> Option<Variant> {
        match self {
            Self::TraditionalTw => Some(Variant::ZhTW),
            Self::TraditionalHk => Some(Variant::ZhHK),
            Self::Traditional => Some(Variant::ZhHant),
            Self::None => None,
        }
    }
}

/// 轉換後的修正表。
///
/// OpenCC 的表在上下文中會出現最長匹配的誤判。最典型的是：
/// 「里面」單獨轉換是對的（→裡面），但在「代數里面」中，
/// 「数里」先被匹配掉，剩下的「面」被單獨轉成「麵」。
///
/// 每一條修正都必須：
/// 1. 是**明確錯誤**，不是風格偏好
/// 2. 有對應的測試案例
/// 3. 夠長以避免誤傷（單字修正幾乎必然誤傷）
pub const CORRECTIONS: &[(&str, &str)] = &[
    // 「面」在方位詞中不該變成食物的「麵」
    ("里麵", "裡面"),
    ("裡麵", "裡面"),
    ("上麵", "上面"),
    ("下麵的", "下面的"),
    ("外麵", "外面"),
    ("前麵", "前面"),
    ("後麵", "後面"),
    ("方麵", "方面"),
    ("麵對", "面對"),
    ("全麵", "全面"),
    // 「發」與「髮」
    ("頭發", "頭髮"),
    // 「板」與「闆」
    ("老板", "老闆"),
];

/// 中文字體轉換器。
#[derive(Debug, Clone)]
pub struct ChineseConverter {
    script: Script,
    /// 額外的使用者詞彙修正，優先於內建 [`CORRECTIONS`]。
    extra: Vec<(String, String)>,
}

impl Default for ChineseConverter {
    fn default() -> Self {
        Self::new(Script::TraditionalTw)
    }
}

impl ChineseConverter {
    pub fn new(script: Script) -> Self {
        Self {
            script,
            extra: Vec::new(),
        }
    }

    pub fn script(&self) -> Script {
        self.script
    }

    /// 加入自訂修正。使用者可以把自己領域的用詞放進來。
    pub fn add_correction(&mut self, from: impl Into<String>, to: impl Into<String>) {
        self.extra.push((from.into(), to.into()));
    }

    /// 轉換文字。
    pub fn convert(&self, text: &str) -> String {
        let Some(variant) = self.script.variant() else {
            return text.to_string();
        };
        if text.is_empty() {
            return String::new();
        }

        let mut out = zhconv(text, variant);
        // 自訂修正先套用，讓使用者能覆寫內建行為。
        for (from, to) in self.extra.iter().map(|(a, b)| (a.as_str(), b.as_str())) {
            if out.contains(from) {
                out = out.replace(from, to);
            }
        }
        for (from, to) in CORRECTIONS {
            if out.contains(from) {
                out = out.replace(from, to);
            }
        }
        out
    }

    /// 是否含有簡體字元。用來判斷要不要跑轉換 ——
    /// 已經是繁體的內容重複轉換只是浪費，也可能引入誤判。
    pub fn looks_simplified(text: &str) -> bool {
        text != zhconv(text, Variant::ZhHant)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tw() -> ChineseConverter {
        ChineseConverter::default()
    }

    #[test]
    fn converts_basic_characters() {
        assert_eq!(tw().convert("线性代数"), "線性代數");
        assert_eq!(tw().convert("机器学习"), "機器學習");
        assert_eq!(tw().convert("语音识别"), "語音識別");
    }

    #[test]
    fn converts_taiwan_specific_week() {
        // OpenCC 表有處理這個；MediaWiki 表沒有。
        assert_eq!(tw().convert("下周三开会"), "下週三開會");
    }

    #[test]
    fn fixes_the_mian_context_error() {
        // 這是換 OpenCC 表之後最明顯的錯誤：
        // 「里面」單獨轉是對的，在「代数里面」中卻變成「里麵」。
        assert_eq!(
            tw().convert("线性代数里面的特征值"),
            "線性代數裡面的特徵值",
            "方位詞的「面」不該變成食物的「麵」"
        );
    }

    #[test]
    fn every_correction_entry_actually_fires() {
        // 修正表裡的死條目只會讓人以為問題解決了。
        let c = tw();
        for (from, to) in CORRECTIONS {
            assert_eq!(c.convert(from), *to, "修正條目 {from} → {to} 沒有生效");
        }
    }

    #[test]
    fn corrections_do_not_break_legitimate_noodles() {
        // 「麵」在食物語境是對的，修正表不該誤傷。
        assert_eq!(tw().convert("面条"), "麵條");
        assert_eq!(tw().convert("拉面很好吃"), "拉麵很好吃");
    }

    #[test]
    fn punctuation_and_ascii_survive() {
        // 這一層跑在標點還原之後，絕不能破壞已加上的標點。
        let out = tw().convert("下周三下午三点在研讨室开会，请大家准时参加。");
        assert!(
            out.contains('，') && out.contains('。'),
            "標點必須保留：{out}"
        );
        assert_eq!(tw().convert("用 Rust 写 API"), "用 Rust 寫 API");
    }

    #[test]
    fn conversion_is_idempotent() {
        // 重複轉換不該繼續改變內容 —— 否則同步時反覆套用會逐漸劣化。
        let c = tw();
        let once = c.convert("今天我们要讲的是线性代数里面的特征值");
        assert_eq!(c.convert(&once), once);
    }

    #[test]
    fn already_traditional_text_is_left_alone() {
        let c = tw();
        let text = "今天我們要講的是線性代數裡面的特徵值";
        assert_eq!(c.convert(text), text);
    }

    #[test]
    fn none_script_is_a_passthrough() {
        let c = ChineseConverter::new(Script::None);
        assert_eq!(c.convert("线性代数"), "线性代数");
    }

    #[test]
    fn user_corrections_take_precedence() {
        let mut c = tw();
        c.add_correction("程序", "程式");
        assert_eq!(c.convert("这个程序"), "這個程式");
    }

    #[test]
    fn detects_simplified_input() {
        assert!(ChineseConverter::looks_simplified("线性代数"));
        assert!(!ChineseConverter::looks_simplified("線性代數"));
        assert!(!ChineseConverter::looks_simplified("Rust"));
    }

    #[test]
    fn empty_input_is_empty_output() {
        assert_eq!(tw().convert(""), "");
    }

    #[test]
    fn hk_variant_differs_from_tw() {
        let hk = ChineseConverter::new(Script::TraditionalHk).convert("下周三");
        let tw_out = tw().convert("下周三");
        assert_eq!(tw_out, "下週三");
        assert!(!hk.is_empty());
    }
}
