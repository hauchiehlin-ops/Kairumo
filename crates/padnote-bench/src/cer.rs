//! 字元錯誤率（CER）—— 中文 ASR 的主要品質指標。
//!
//! 中文不以空白分詞，因此用 CER 而非 WER。門檻見 `docs/roadmap.md` M0/S2：
//! 安靜場景 ≤ 8%，嘈雜場景 ≤ 18%。

/// 以字元（Unicode scalar）為單位的 Levenshtein 編輯距離。
pub fn edit_distance(reference: &str, hypothesis: &str) -> usize {
    let r: Vec<char> = reference.chars().collect();
    let h: Vec<char> = hypothesis.chars().collect();
    if r.is_empty() {
        return h.len();
    }

    // 滾動陣列：只保留前一列，記憶體 O(min(n,m))。
    let mut prev: Vec<usize> = (0..=h.len()).collect();
    let mut cur = vec![0usize; h.len() + 1];

    for (i, rc) in r.iter().enumerate() {
        cur[0] = i + 1;
        for (j, hc) in h.iter().enumerate() {
            let sub_cost = usize::from(rc != hc);
            cur[j + 1] = (prev[j] + sub_cost).min(prev[j + 1] + 1).min(cur[j] + 1);
        }
        std::mem::swap(&mut prev, &mut cur);
    }
    prev[h.len()]
}

/// CER = 編輯距離 / 參考文本長度。空參考且空假設時為 0.0。
pub fn cer(reference: &str, hypothesis: &str) -> f64 {
    let ref_len = reference.chars().count();
    if ref_len == 0 {
        return if hypothesis.is_empty() { 0.0 } else { 1.0 };
    }
    edit_distance(reference, hypothesis) as f64 / ref_len as f64
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn identical_text_has_zero_cer() {
        assert_eq!(cer("線性代數特徵值", "線性代數特徵值"), 0.0);
    }

    #[test]
    fn single_substitution_in_chinese() {
        // 7 字中錯 1 字
        let c = cer("線性代數特徵值", "線性代數特徵植");
        assert!((c - 1.0 / 7.0).abs() < 1e-9, "got {c}");
    }

    #[test]
    fn insertion_and_deletion_counted() {
        assert_eq!(edit_distance("abc", "abcd"), 1);
        assert_eq!(edit_distance("abcd", "abc"), 1);
    }

    #[test]
    fn empty_reference_with_output_is_total_error() {
        assert_eq!(cer("", "幻覺輸出"), 1.0);
        assert_eq!(cer("", ""), 0.0);
    }

    #[test]
    fn mixed_chinese_english_counts_by_char() {
        // 中英夾雜是 C9 的重點場景
        assert_eq!(edit_distance("用 Rust 寫", "用 Rust 寫"), 0);
        assert_eq!(edit_distance("用 Rust 寫", "用 Rush 寫"), 1);
    }
}
