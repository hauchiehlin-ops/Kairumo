//! 混合斷詞：CJK 走 bigram，拉丁與數字走詞邊界。
//!
//! 中文沒有空白分隔，用空白切會整句變成一個 token。bigram 把「線性代數」
//! 切成「線性」「性代」「代數」，查「代數」就命中 —— 不需要詞典，
//! 也不怕「特徵值」這類未登錄詞被切錯。

/// 是否為需要 bigram 處理的字元（CJK 統一表意文字、擴展區、假名、諺文）。
pub fn is_cjk(c: char) -> bool {
    matches!(c as u32,
        0x3040..=0x30FF   // 平假名、片假名
        | 0x3400..=0x4DBF // CJK 擴展 A
        | 0x4E00..=0x9FFF // CJK 基本區
        | 0xAC00..=0xD7AF // 諺文音節
        | 0xF900..=0xFAFF // 相容表意文字
        | 0x20000..=0x2FA1F // 擴展 B–F
    )
}

/// 切出可索引的 token，全部轉小寫。
///
/// - CJK：相鄰兩字組成 bigram；單獨一個 CJK 字也會產出（否則單字查詢會落空）
/// - 拉丁/數字：以非字母數字為邊界切詞
/// - 其他（標點、空白）：丟棄
pub fn tokenize(text: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut latin = String::new();
    let mut cjk_run: Vec<char> = Vec::new();

    let flush_latin = |buf: &mut String, out: &mut Vec<String>| {
        if !buf.is_empty() {
            out.push(std::mem::take(buf));
        }
    };
    let flush_cjk = |run: &mut Vec<char>, out: &mut Vec<String>| {
        match run.len() {
            0 => {}
            // 單字成詞，否則查「我」會找不到
            1 => out.push(run[0].to_string()),
            _ => {
                for w in run.windows(2) {
                    out.push(w.iter().collect());
                }
            }
        }
        run.clear();
    };

    for c in text.chars() {
        if is_cjk(c) {
            flush_latin(&mut latin, &mut out);
            cjk_run.push(c);
        } else if c.is_alphanumeric() {
            flush_cjk(&mut cjk_run, &mut out);
            latin.extend(c.to_lowercase());
        } else {
            flush_latin(&mut latin, &mut out);
            flush_cjk(&mut cjk_run, &mut out);
        }
    }
    flush_latin(&mut latin, &mut out);
    flush_cjk(&mut cjk_run, &mut out);
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn chinese_is_split_into_bigrams() {
        assert_eq!(tokenize("線性代數"), ["線性", "性代", "代數"]);
    }

    #[test]
    fn single_chinese_char_is_indexable() {
        // 沒有這條，查單字會全部落空。
        assert_eq!(tokenize("我"), ["我"]);
    }

    #[test]
    fn latin_words_split_on_boundaries_and_lowercase() {
        assert_eq!(
            tokenize("Hello, World! Rust_2026"),
            ["hello", "world", "rust", "2026"]
        );
    }

    #[test]
    fn mixed_chinese_english_splits_at_the_boundary() {
        // C9 中英夾雜是核心場景
        assert_eq!(tokenize("用 Rust 寫程式"), ["用", "rust", "寫程", "程式"]);
    }

    #[test]
    fn punctuation_is_dropped_but_breaks_runs() {
        // 標點必須斷開 bigram，否則「開會。明天」會產生跨句的假詞「會明」
        let t = tokenize("開會。明天");
        assert!(
            !t.contains(&"會明".to_string()),
            "跨標點不得組成 bigram：{t:?}"
        );
        assert_eq!(t, ["開會", "明天"]);
    }

    #[test]
    fn empty_and_whitespace_yield_nothing() {
        assert!(tokenize("").is_empty());
        assert!(tokenize("   \n\t ").is_empty());
        assert!(tokenize("。、！？").is_empty());
    }

    #[test]
    fn japanese_kana_is_treated_as_cjk() {
        assert_eq!(tokenize("ひらがな"), ["ひら", "らが", "がな"]);
    }
}
