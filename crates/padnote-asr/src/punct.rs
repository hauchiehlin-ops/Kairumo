//! 標點還原介面（功能 C5，**P0**）。
//!
//! 市調的結論很直接：**中文轉錄沒有標點等於沒用**。ASR 輸出的是一長串沒有
//!斷句的字，讀起來極其吃力，也無法用於摘要或搜尋片段。
//!
//! 實作見 `padnote-punct-ct`。此處只定義介面，讓管線不綁定特定模型。

use padnote_doc::TranscriptWord;
use std::fmt;

#[derive(Debug)]
pub enum PunctError {
    ModelNotLoaded,
    Backend(String),
}

impl fmt::Display for PunctError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::ModelNotLoaded => write!(f, "標點模型尚未下載或載入"),
            Self::Backend(m) => write!(f, "標點還原失敗：{m}"),
        }
    }
}

impl std::error::Error for PunctError {}

/// 標點還原引擎。
pub trait PunctuationEngine: Send + Sync + fmt::Debug {
    /// 對純文字加標點。
    fn punctuate(&mut self, text: &str) -> Result<String, PunctError>;

    /// 對帶時間戳的詞加標點。
    ///
    /// **預設實作會保留時間戳**：標點被接在對應詞的尾端，而不是變成新的詞。
    /// 這很重要 —— 標點若自成一個詞，C1（點文字跳回錄音）就會跳到一個
    /// 沒有聲音的位置。
    fn punctuate_words(
        &mut self,
        words: &[TranscriptWord],
    ) -> Result<Vec<TranscriptWord>, PunctError> {
        if words.is_empty() {
            return Ok(Vec::new());
        }
        let joined: String = words.iter().map(|w| w.text.as_str()).collect();
        let punctuated = self.punctuate(&joined)?;
        Ok(reattach(words, &punctuated))
    }
}

/// 把加了標點的文字對回原本的詞，保留時間戳。
///
/// 逐字比對：標點模型只會**插入**字元、不會改寫或刪除，因此對齊是安全的。
/// 若出現非預期的差異（模型改寫了內容），多餘的字元會被忽略而非錯置 ——
/// 寧可少一個標點，也不要讓時間戳錯位。
pub fn reattach(words: &[TranscriptWord], punctuated: &str) -> Vec<TranscriptWord> {
    let mut out = Vec::with_capacity(words.len());
    let mut chars = punctuated.chars().peekable();

    for w in words {
        let mut text = String::with_capacity(w.text.len() + 3);
        // 先吃掉與原詞相同的字元
        for expected in w.text.chars() {
            match chars.peek() {
                Some(&c) if c == expected => {
                    text.push(c);
                    chars.next();
                }
                // 對不上就保留原字元，不消耗輸出 —— 避免整串錯位。
                _ => text.push(expected),
            }
        }
        // 接著吃掉緊跟在後的標點
        while let Some(&c) = chars.peek() {
            if is_punctuation(c) {
                text.push(c);
                chars.next();
            } else {
                break;
            }
        }
        out.push(TranscriptWord {
            text,
            start: w.start,
            end: w.end,
            confidence: w.confidence,
        });
    }
    out
}

/// 中英文的標點符號。
fn is_punctuation(c: char) -> bool {
    matches!(
        c,
        '，' | '。' | '？' | '、' | '！' | '；' | '：' | ',' | '.' | '?' | '!' | ';' | ':'
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use padnote_doc::NotebookTime;

    fn word(text: &str, start_us: u64) -> TranscriptWord {
        TranscriptWord {
            text: text.into(),
            start: NotebookTime::from_micros(start_us),
            end: NotebookTime::from_micros(start_us + 200_000),
            confidence: 0.9,
        }
    }

    #[test]
    fn punctuation_attaches_to_the_preceding_word() {
        let words = vec![word("开", 0), word("会", 200_000), word("了", 400_000)];
        let out = reattach(&words, "开会，了");

        assert_eq!(out.len(), 3, "詞數不變");
        assert_eq!(out[1].text, "会，", "標點接在前一個詞尾端");
        assert_eq!(out[2].text, "了");
    }

    #[test]
    fn timestamps_are_preserved() {
        // 標點若自成一個詞，C1 會跳到沒有聲音的位置。
        let words = vec![word("是", 1_000_000), word("的", 1_200_000)];
        let out = reattach(&words, "是的。");

        assert_eq!(out[0].start, NotebookTime::from_micros(1_000_000));
        assert_eq!(out[1].start, NotebookTime::from_micros(1_200_000));
        assert_eq!(out[1].end, NotebookTime::from_micros(1_400_000));
        assert_eq!(out[1].text, "的。");
    }

    #[test]
    fn trailing_punctuation_lands_on_the_last_word() {
        let words = vec![word("好", 0)];
        assert_eq!(reattach(&words, "好。")[0].text, "好。");
    }

    #[test]
    fn model_rewriting_content_does_not_shift_timestamps() {
        // 若模型意外改寫了內容，寧可少一個標點也不要讓時間戳錯位。
        let words = vec![word("甲", 0), word("乙", 200_000)];
        let out = reattach(&words, "丙丁。");

        assert_eq!(out.len(), 2);
        assert_eq!(out[0].text, "甲", "原字元保留");
        assert_eq!(out[0].start, NotebookTime::ZERO);
    }

    #[test]
    fn empty_input_is_empty_output() {
        assert!(reattach(&[], "任何東西").is_empty());
    }

    #[test]
    fn multi_char_words_are_handled() {
        // 英文詞是多字元的
        let words = vec![word("Rust", 0), word("很", 400_000), word("快", 600_000)];
        let out = reattach(&words, "Rust，很快。");
        assert_eq!(out[0].text, "Rust，");
        assert_eq!(out[2].text, "快。");
    }

    #[test]
    fn text_without_punctuation_passes_through() {
        let words = vec![word("你", 0), word("好", 200_000)];
        let out = reattach(&words, "你好");
        assert_eq!(out[0].text, "你");
        assert_eq!(out[1].text, "好");
    }

    #[test]
    fn recognizes_both_chinese_and_ascii_punctuation() {
        assert!(is_punctuation('，'));
        assert!(is_punctuation('。'));
        assert!(is_punctuation(','));
        assert!(!is_punctuation('好'));
        assert!(!is_punctuation('a'));
    }
}
