//! 轉錄後處理管線：標點還原 → 簡繁轉換。
//!
//! ASR 吐出的是**沒有標點的簡體中文**。直接顯示給台灣使用者有兩個問題：
//! 讀不了（沒斷句）、看不慣（簡體）。這個模組補上最後兩步。
//!
//! ```text
//! Paraformer ─▶ 無標點簡體 ─▶ ct-punc ─▶ 有標點簡體 ─▶ 簡繁轉換 ─▶ 有標點正體
//! ```
//!
//! ## 順序不可調換
//! ct-punc 的詞表是**簡體**的 —— 471,067 個 token 中不含繁體字。
//! 先轉繁體再標點，大部分字會落到 `<unk>`，標點品質崩壞。
//! 實測：簡體輸入 0/31 未知詞，繁體輸入 3/18。
//!
//! ## 兩者都是可選的
//! 標點模型 269 MB、需另外下載；轉換則是純程式碼。任一缺席時管線會
//! **降級而非失敗** —— 沒有標點的轉錄仍然比沒有轉錄好。

use padnote_asr::{PunctError, PunctuationEngine};
use padnote_doc::TranscriptWord;
use padnote_text::{ChineseConverter, Script};

/// 轉錄後處理。
#[derive(Debug, Default)]
pub struct TranscriptPostProcessor {
    converter: Option<ChineseConverter>,
}

impl TranscriptPostProcessor {
    /// 不做任何轉換。
    pub fn passthrough() -> Self {
        Self { converter: None }
    }

    /// 轉成指定字體。
    pub fn with_script(script: Script) -> Self {
        Self {
            converter: (script != Script::None).then(|| ChineseConverter::new(script)),
        }
    }

    /// 台灣正體（預設）。
    pub fn traditional_tw() -> Self {
        Self::with_script(Script::TraditionalTw)
    }

    pub fn converter_mut(&mut self) -> Option<&mut ChineseConverter> {
        self.converter.as_mut()
    }

    /// 跑完整的後處理。
    ///
    /// `punctuation` 為 `None` 時跳過標點還原 —— 模型未下載時仍應能得到
    /// 可用的轉錄，只是沒有斷句。
    pub fn process(
        &self,
        words: &[TranscriptWord],
        punctuation: Option<&mut dyn PunctuationEngine>,
    ) -> Result<Vec<TranscriptWord>, PunctError> {
        if words.is_empty() {
            return Ok(Vec::new());
        }

        // (1) 在**簡體空間**加標點
        let punctuated = match punctuation {
            Some(engine) => engine.punctuate_words(words)?,
            None => words.to_vec(),
        };

        // (2) 再轉字體。時間戳一路不動。
        let Some(conv) = &self.converter else {
            return Ok(punctuated);
        };
        Ok(convert_preserving_words(&punctuated, conv))
    }

    /// 對純文字做同樣的處理。
    ///
    pub fn process_text(
        &self,
        text: &str,
        punctuation: Option<&mut dyn PunctuationEngine>,
    ) -> Result<String, PunctError> {
        let punctuated = match punctuation {
            Some(engine) => engine.punctuate(text)?,
            None => text.to_string(),
        };
        Ok(match &self.converter {
            Some(c) => c.convert(&punctuated),
            None => punctuated,
        })
    }
}

/// 轉換字體但保留詞的邊界與時間戳。
///
/// **不能逐詞轉換** —— 詞組上下文會消失。ASR 的詞多半是單字，
/// 「下」「周」「三」分開轉，「周」永遠不會變成「週」；
/// 那需要看到整個「下周三」。
///
/// 因此先把整段接起來轉換，再依字數分回各詞。中文的簡繁轉換絕大多數是
/// 1:1 的字數對應，所以這個分法成立；萬一字數變了（少數詞彙替換會），
/// 就退回逐詞轉換 —— 寧可少一點上下文，也不能讓時間戳錯位。
fn convert_preserving_words(
    words: &[TranscriptWord],
    conv: &ChineseConverter,
) -> Vec<TranscriptWord> {
    let joined: String = words.iter().map(|w| w.text.as_str()).collect();
    let converted = conv.convert(&joined);

    let original_chars: usize = words.iter().map(|w| w.text.chars().count()).sum();
    if converted.chars().count() != original_chars {
        // 字數變了，無法安全分割 —— 退回逐詞轉換。
        return words
            .iter()
            .map(|w| TranscriptWord {
                text: conv.convert(&w.text),
                ..w.clone()
            })
            .collect();
    }

    let mut chars = converted.chars();
    words
        .iter()
        .map(|w| TranscriptWord {
            text: chars.by_ref().take(w.text.chars().count()).collect(),
            ..w.clone()
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use padnote_doc::NotebookTime;

    /// 假的標點引擎：在固定位置插入逗號與句號。
    #[derive(Debug)]
    struct FakePunct;

    impl PunctuationEngine for FakePunct {
        fn punctuate(&mut self, text: &str) -> Result<String, PunctError> {
            let chars: Vec<char> = text.chars().collect();
            let mut out = String::new();
            for (i, c) in chars.iter().enumerate() {
                out.push(*c);
                if i + 1 == chars.len() {
                    out.push('。');
                } else if (i + 1) % 5 == 0 {
                    out.push('，');
                }
            }
            Ok(out)
        }
    }

    #[derive(Debug)]
    struct BrokenPunct;

    impl PunctuationEngine for BrokenPunct {
        fn punctuate(&mut self, _: &str) -> Result<String, PunctError> {
            Err(PunctError::ModelNotLoaded)
        }
    }

    fn words(text: &str) -> Vec<TranscriptWord> {
        text.chars()
            .enumerate()
            .map(|(i, c)| TranscriptWord {
                text: c.to_string(),
                start: NotebookTime::from_micros(i as u64 * 200_000),
                end: NotebookTime::from_micros((i as u64 + 1) * 200_000),
                confidence: 0.9,
            })
            .collect()
    }

    fn joined(w: &[TranscriptWord]) -> String {
        w.iter().map(|x| x.text.as_str()).collect()
    }

    #[test]
    fn full_pipeline_punctuates_then_converts() {
        let p = TranscriptPostProcessor::traditional_tw();
        let out = p
            .process(&words("下周三下午三点开会"), Some(&mut FakePunct))
            .unwrap();

        let text = joined(&out);
        assert!(
            text.contains('，') || text.contains('。'),
            "應有標點：{text}"
        );
        assert!(text.contains("週"), "應轉為正體：{text}");
        assert!(!text.contains('周'), "簡體殘留：{text}");
    }

    #[test]
    fn timestamps_survive_the_whole_pipeline() {
        // C1（點文字跳回錄音）完全依賴時間戳不變。
        let input = words("线性代数");
        let out = TranscriptPostProcessor::traditional_tw()
            .process(&input, Some(&mut FakePunct))
            .unwrap();

        assert_eq!(out.len(), input.len());
        for (a, b) in out.iter().zip(&input) {
            assert_eq!(a.start, b.start);
            assert_eq!(a.end, b.end);
        }
    }

    #[test]
    fn works_without_a_punctuation_model() {
        // 標點模型 269 MB，使用者可能還沒下載。
        // 沒有標點的轉錄仍然比沒有轉錄好。
        let out = TranscriptPostProcessor::traditional_tw()
            .process(&words("线性代数"), None)
            .unwrap();
        assert_eq!(joined(&out), "線性代數");
    }

    #[test]
    fn punctuation_failure_propagates_rather_than_silently_dropping_text() {
        // 靜默吞掉錯誤會讓使用者以為模型正常運作。
        let r = TranscriptPostProcessor::traditional_tw()
            .process(&words("测试"), Some(&mut BrokenPunct));
        assert!(r.is_err());
    }

    #[test]
    fn passthrough_changes_nothing() {
        let input = words("线性代数");
        let out = TranscriptPostProcessor::passthrough()
            .process(&input, None)
            .unwrap();
        assert_eq!(joined(&out), "线性代数");
    }

    #[test]
    fn empty_input_is_empty_output() {
        assert!(
            TranscriptPostProcessor::traditional_tw()
                .process(&[], Some(&mut FakePunct))
                .unwrap()
                .is_empty()
        );
    }

    #[test]
    fn text_api_matches_the_word_api() {
        let p = TranscriptPostProcessor::traditional_tw();
        let via_words = joined(
            &p.process(&words("下周三开会"), Some(&mut FakePunct))
                .unwrap(),
        );
        let via_text = p.process_text("下周三开会", Some(&mut FakePunct)).unwrap();
        assert_eq!(via_words, via_text);
    }

    #[test]
    fn phrase_context_survives_word_boundaries() {
        // 逐詞轉換會讓「下」「周」「三」各自轉換，「周」永遠不會變「週」。
        // 這條測試把「整段轉換後再分回」的作法釘住。
        let out = TranscriptPostProcessor::traditional_tw()
            .process(&words("下周三开会"), None)
            .unwrap();
        assert_eq!(joined(&out), "下週三開會");
        assert_eq!(out.len(), 5, "詞的數量不變");
        assert_eq!(out[1].text, "週", "第二個詞應是轉換後的字");
    }

    #[test]
    fn length_changing_conversion_falls_back_safely() {
        // 少數詞彙替換會改變字數。此時寧可少一點上下文，
        // 也不能讓時間戳錯位。
        let mut p = TranscriptPostProcessor::traditional_tw();
        p.converter_mut().unwrap().add_correction("程序", "程式碼");

        let input = words("这个程序");
        let out = p.process(&input, None).unwrap();
        assert_eq!(out.len(), input.len(), "詞數必須不變");
        for (a, b) in out.iter().zip(&input) {
            assert_eq!(a.start, b.start, "時間戳不得錯位");
        }
    }

    #[test]
    fn user_vocabulary_can_be_added() {
        let mut p = TranscriptPostProcessor::traditional_tw();
        p.converter_mut().unwrap().add_correction("程序", "程式");
        let out = p.process(&words("这个程序"), None).unwrap();
        assert_eq!(joined(&out), "這個程式");
    }
}
