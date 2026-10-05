//! 混合斷詞：CJK 走 bigram，拉丁與數字走詞邊界。
//!
//! 中文沒有空白分隔，用空白切會整句變成一個 token。bigram 把「線性代數」
//! 切成「線性」「性代」「代數」，查「代數」就命中 —— 不需要詞典，
//! 也不怕「特徵值」這類未登錄詞被切錯。

/// 是否為需要 bigram 處理的字元（CJK 統一表意文字、擴展區、假名、諺文、泰文）。
///
/// 泰文和中文一樣**詞與詞之間沒有空白**，一整句會變成一個 token，查其中任何一個詞都落空。
pub fn is_cjk(c: char) -> bool {
    is_thai(c)
        || matches!(c as u32,
            0x3005..=0x3007   // 々 〆 〇（日文疊字、數字零；屬於「字母」類別，不特別處理會被當成西文詞）
            | 0x3040..=0x30FF // 平假名、片假名
            | 0x31F0..=0x31FF // 片假名擴展
            | 0x3400..=0x4DBF // CJK 擴展 A
            | 0x4E00..=0x9FFF // CJK 基本區
            | 0xAC00..=0xD7AF // 諺文音節
            | 0xF900..=0xFAFF // 相容表意文字
            | 0xFF66..=0xFF9F // 半形片假名
            | 0x20000..=0x2FA1F // 擴展 B–F
        )
}

fn is_thai(c: char) -> bool {
    matches!(c as u32, 0x0E01..=0x0E5B)
}

/// 泰文的聲調符號與上下母音（結合符號）：要黏在前一個子音上，自己不能成為一個「字」。
/// 不處理的話它們不屬於字母或數字，會被當成標點，把一個詞從中間切斷。
fn is_thai_mark(c: char) -> bool {
    matches!(c as u32, 0x0E31 | 0x0E34..=0x0E3A | 0x0E47..=0x0E4E)
}

/// 全形英數與符號折成半形（Ａ→A、１→1），讓「ＡＢＣ」與「abc」查得到彼此。
fn fold_width(c: char) -> char {
    match c as u32 {
        0xFF01..=0xFF5E => char::from_u32(c as u32 - 0xFEE0).unwrap_or(c),
        0x3000 => ' ',
        _ => c,
    }
}

/// 切出可索引的 token，全部轉小寫。
///
/// - CJK：相鄰兩字組成 bigram；單獨一個 CJK 字也會產出（否則單字查詢會落空）
/// - 泰文：以「子音＋附著的母音／聲調符號」為一個字，同樣走 bigram
/// - 拉丁/數字：以非字母數字為邊界切詞；全形英數先折成半形
/// - 其他（標點、空白）：丟棄
pub fn tokenize(text: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut latin = String::new();
    // 一個「字」可能由多個碼位組成（泰文的子音加符號），所以是字串。
    let mut cjk_run: Vec<String> = Vec::new();

    let flush_latin = |buf: &mut String, out: &mut Vec<String>| {
        if !buf.is_empty() {
            out.push(std::mem::take(buf));
        }
    };
    let flush_cjk = |run: &mut Vec<String>, out: &mut Vec<String>| {
        match run.len() {
            0 => {}
            // 單字成詞，否則查「我」會找不到
            1 => out.push(run[0].clone()),
            _ => {
                for w in run.windows(2) {
                    out.push(format!("{}{}", w[0], w[1]));
                }
            }
        }
        run.clear();
    };

    for raw in text.chars() {
        let c = fold_width(raw);
        if is_thai_mark(c) {
            // 黏在前一個泰文字上；前面沒有字（孤立的符號）就丟掉。
            if let Some(last) = cjk_run.last_mut() {
                last.push(c);
            }
        } else if is_cjk(c) {
            flush_latin(&mut latin, &mut out);
            cjk_run.push(c.to_string());
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

    #[test]
    fn thai_has_no_spaces_so_it_is_split_like_chinese() {
        // 「การประชุม」（會議）沒有空白可切；整句一個 token 的話，查「ประชุม」找不到。
        let doc = tokenize("การประชุม");
        let query = tokenize("ประชุม");
        assert!(doc.len() > 1, "{doc:?}");
        assert!(query.iter().all(|q| doc.contains(q)), "{query:?} ⊄ {doc:?}");
    }

    #[test]
    fn thai_tone_marks_stay_attached_to_their_consonant() {
        // 「ไม้」= ไ ม ้（้ 是聲調符號）。符號不能把詞切成兩半，也不能自己成為一個 token。
        let t = tokenize("ไม้");
        assert_eq!(t, vec!["ไม้".to_string()]);
        assert!(t.iter().all(|x| !x.starts_with('\u{0E49}')));
        // ไ ม้ เ ท้ า → 五個字、四個 bigram。
        assert_eq!(tokenize("ไม้เท้า").len(), 4);
    }

    #[test]
    fn korean_is_bigrammed_and_a_syllable_query_hits() {
        let doc = tokenize("회의록 작성");
        assert!(doc.contains(&"회의".to_string()) && doc.contains(&"의록".to_string()));
        assert!(
            tokenize("의")
                .iter()
                .all(|q| doc.iter().any(|d| d.contains(q.as_str())))
        );
    }

    #[test]
    fn japanese_iteration_mark_is_not_a_latin_word() {
        // 「人々」の々 は「字母」扱いだが、日本語の一部。
        assert_eq!(tokenize("人々"), ["人々"]);
    }

    #[test]
    fn full_width_latin_matches_half_width() {
        assert_eq!(tokenize("ＡＢＣ　１２３"), tokenize("abc 123"));
    }

    #[test]
    fn half_width_katakana_is_cjk() {
        assert_eq!(tokenize("ｶﾀｶﾅ").len(), 3);
    }
}
