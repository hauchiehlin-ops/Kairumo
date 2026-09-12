//! CT-Transformer 中文標點還原（工作項 S-30，功能 C5 **P0**）。
//!
//! 模型依 ADR-0006 自行從 `funasr/ct-punc` 匯出，int8 量化後 269 MB
//! （量化必須納入 `Gather`，否則占 86% 體積的嵌入表不會被壓縮 —— 見 S-29）。
//!
//! ## ⚠️ 這個模型的詞表是**簡體中文**
//! 471,067 個 token 中僅 1.3% 是單字，其餘是詞與英數字串；且繁體字
//! （線、數、點…）**不在詞表內**，會落到 `<unk>`。
//!
//! 因此正確的管線順序是：
//!
//! ```text
//! Paraformer（輸出簡體）→ ct-punc（簡體空間加標點）→ OpenCC s2twp（轉繁體）
//! ```
//!
//! 實測：簡體輸入 0/31 未知詞、標點正確；繁體輸入 3/18 未知詞、標點仍可用
//! 但品質下降。**先標點、再轉繁體**不是實作細節，是正確性需求。

use ort::session::Session;
use ort::value::Value;
use padnote_asr::{PunctError, PunctuationEngine};
use std::collections::HashMap;
use std::path::Path;

/// 模型輸出的標點類別，順序來自 `config.yaml` 的 `punc_list`。
///
/// 索引 0 是 `<unk>`、1 是「不加標點」，其餘為實際標點。
const PUNCTUATION: [&str; 6] = ["", "", "，", "。", "？", "、"];

/// 一次送進模型的最大 token 數。
///
/// CT-Transformer 是全注意力模型，長度平方成本。一小時的轉錄有上萬字，
/// 整段送進去會爆記憶體，因此分塊處理。
const DEFAULT_CHUNK: usize = 256;

/// 分塊之間重疊的 token 數。
///
/// 沒有重疊的話，切點附近的字看不到後文，標點會系統性地在每個塊尾出錯。
/// 重疊部分的結果取自**前一塊**（它有完整的後文）。
const OVERLAP: usize = 32;

#[derive(Debug)]
pub enum CtPunctError {
    ModelNotFound(String),
    TokensNotFound(String),
    Malformed(String),
    Ort(String),
}

impl std::fmt::Display for CtPunctError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::ModelNotFound(p) => write!(f, "找不到標點模型：{p}"),
            Self::TokensNotFound(p) => write!(f, "找不到詞表：{p}"),
            Self::Malformed(m) => write!(f, "詞表格式錯誤：{m}"),
            Self::Ort(m) => write!(f, "ONNX Runtime 錯誤：{m}"),
        }
    }
}

impl std::error::Error for CtPunctError {}

impl From<CtPunctError> for PunctError {
    fn from(e: CtPunctError) -> Self {
        match e {
            CtPunctError::ModelNotFound(_) | CtPunctError::TokensNotFound(_) => {
                PunctError::ModelNotLoaded
            }
            other => PunctError::Backend(other.to_string()),
        }
    }
}

/// 把文字切成模型認得的 token。
///
/// 中文逐字、英數逐詞（`CharTokenizer` 的實際行為）。空白不產生 token，
/// 但英文詞之間的空白在重組時會被補回。
pub fn tokenize(text: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut ascii_run = String::new();

    for c in text.chars() {
        if c.is_ascii_alphanumeric() || c == '\'' {
            ascii_run.push(c);
        } else {
            if !ascii_run.is_empty() {
                out.push(std::mem::take(&mut ascii_run));
            }
            if !c.is_whitespace() {
                out.push(c.to_string());
            }
        }
    }
    if !ascii_run.is_empty() {
        out.push(ascii_run);
    }
    out
}

/// CT-Transformer 標點模型。
pub struct CtPunctuator {
    session: Session,
    vocab: HashMap<String, i32>,
    unk: i32,
    chunk_size: usize,
}

impl std::fmt::Debug for CtPunctuator {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("CtPunctuator")
            .field("vocab_size", &self.vocab.len())
            .field("chunk_size", &self.chunk_size)
            .finish()
    }
}

impl CtPunctuator {
    /// 載入模型與詞表。
    ///
    /// `tokens` 是匯出時一併產生的 `tokens.json`（471,067 個 token，約 8 MB）。
    pub fn load(model: impl AsRef<Path>, tokens: impl AsRef<Path>) -> Result<Self, CtPunctError> {
        let (model, tokens) = (model.as_ref(), tokens.as_ref());
        if !model.exists() {
            return Err(CtPunctError::ModelNotFound(model.display().to_string()));
        }
        if !tokens.exists() {
            return Err(CtPunctError::TokensNotFound(tokens.display().to_string()));
        }

        let list: Vec<String> = serde_json::from_str(
            &std::fs::read_to_string(tokens).map_err(|e| CtPunctError::Malformed(e.to_string()))?,
        )
        .map_err(|e| CtPunctError::Malformed(e.to_string()))?;

        let vocab: HashMap<String, i32> = list
            .into_iter()
            .enumerate()
            .map(|(i, t)| (t, i as i32))
            .collect();
        let unk = *vocab
            .get("<unk>")
            .ok_or_else(|| CtPunctError::Malformed("詞表缺少 <unk>".into()))?;

        let session = Session::builder()
            .and_then(|b| b.commit_from_file(model))
            .map_err(|e| CtPunctError::Ort(e.to_string()))?;

        Ok(Self {
            session,
            vocab,
            unk,
            chunk_size: DEFAULT_CHUNK,
        })
    }

    pub fn set_chunk_size(&mut self, n: usize) {
        self.chunk_size = n.max(OVERLAP * 2);
    }

    pub fn vocab_size(&self) -> usize {
        self.vocab.len()
    }

    /// 未在詞表內的 token 比例。**繁體輸入會偏高**，可用來提示品質下降。
    pub fn unknown_ratio(&self, text: &str) -> f32 {
        let toks = tokenize(text);
        if toks.is_empty() {
            return 0.0;
        }
        let unknown = toks.iter().filter(|t| !self.vocab.contains_key(*t)).count();
        unknown as f32 / toks.len() as f32
    }

    /// 對一段 token 推論，回傳每個 token 之後要加的標點索引。
    fn infer(&mut self, tokens: &[String]) -> Result<Vec<usize>, CtPunctError> {
        let ids: Vec<i32> = tokens
            .iter()
            .map(|t| *self.vocab.get(t).unwrap_or(&self.unk))
            .collect();
        let n = ids.len();

        let to_err = |e: ort::Error| CtPunctError::Ort(e.to_string());
        let inputs = Value::from_array(([1usize, n], ids)).map_err(to_err)?;
        let lengths = Value::from_array(([1usize], vec![n as i32])).map_err(to_err)?;

        let out = self
            .session
            .run(ort::inputs!["inputs" => inputs, "text_lengths" => lengths])
            .map_err(to_err)?;
        let (shape, logits) = out["logits"].try_extract_tensor::<f32>().map_err(to_err)?;

        let classes = *shape.last().unwrap_or(&1) as usize;
        if classes == 0 {
            return Err(CtPunctError::Ort("logits 維度為 0".into()));
        }

        Ok((0..n)
            .map(|i| {
                let row = &logits[i * classes..(i + 1) * classes];
                row.iter()
                    .enumerate()
                    .max_by(|a, b| a.1.total_cmp(b.1))
                    .map_or(1, |(k, _)| k)
            })
            .collect())
    }

    /// 分塊處理長文本，回傳每個 token 的標點索引。
    fn labels_for(&mut self, tokens: &[String]) -> Result<Vec<usize>, CtPunctError> {
        if tokens.is_empty() {
            return Ok(Vec::new());
        }
        if tokens.len() <= self.chunk_size {
            return self.infer(tokens);
        }

        let mut labels = Vec::with_capacity(tokens.len());
        let step = self.chunk_size - OVERLAP;
        let mut start = 0;

        while start < tokens.len() {
            let end = (start + self.chunk_size).min(tokens.len());
            let chunk_labels = self.infer(&tokens[start..end])?;

            // 重疊區的結果取自前一塊（它看得到完整後文），因此只取新的部分。
            let take_from = if start == 0 { 0 } else { OVERLAP };
            labels.extend_from_slice(&chunk_labels[take_from..]);

            if end == tokens.len() {
                break;
            }
            start += step;
        }
        labels.truncate(tokens.len());
        Ok(labels)
    }
}

impl PunctuationEngine for CtPunctuator {
    fn punctuate(&mut self, text: &str) -> Result<String, PunctError> {
        let tokens = tokenize(text);
        if tokens.is_empty() {
            return Ok(String::new());
        }
        let labels = self.labels_for(&tokens).map_err(PunctError::from)?;

        let mut out = String::with_capacity(text.len() + tokens.len() / 8);
        for (i, tok) in tokens.iter().enumerate() {
            // 英文詞之間補回空白（tokenize 時丟掉了）
            if i > 0 && is_ascii_word(tok) && is_ascii_word(&tokens[i - 1]) {
                out.push(' ');
            }
            out.push_str(tok);
            if let Some(&l) = labels.get(i) {
                out.push_str(PUNCTUATION.get(l).copied().unwrap_or(""));
            }
        }
        Ok(out)
    }
}

fn is_ascii_word(s: &str) -> bool {
    s.chars().all(|c| c.is_ascii_alphanumeric() || c == '\'')
}

/// 從模型目錄推出標點模型與詞表的路徑。
pub fn default_paths(dir: impl AsRef<Path>) -> (std::path::PathBuf, std::path::PathBuf) {
    let d = dir.as_ref();
    (d.join("model.int8.onnx"), d.join("tokens.json"))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn model_dir() -> Option<std::path::PathBuf> {
        let p = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../models/exported-int8/ct-punc");
        let (m, t) = default_paths(&p);
        (m.exists() && t.exists()).then_some(p)
    }

    fn engine() -> Option<CtPunctuator> {
        let dir = model_dir()?;
        let (m, t) = default_paths(&dir);
        Some(CtPunctuator::load(m, t).unwrap())
    }

    // ---- 斷詞（不需要模型）----

    #[test]
    fn chinese_splits_per_character() {
        assert_eq!(tokenize("线性代数"), ["线", "性", "代", "数"]);
    }

    #[test]
    fn ascii_stays_whole() {
        assert_eq!(tokenize("用 Rust 写"), ["用", "Rust", "写"]);
        assert_eq!(tokenize("GPT4 很快"), ["GPT4", "很", "快"]);
    }

    #[test]
    fn whitespace_produces_no_tokens() {
        assert_eq!(tokenize("  \n\t "), Vec::<String>::new());
        assert!(tokenize("").is_empty());
    }

    #[test]
    fn apostrophes_stay_inside_words() {
        assert_eq!(tokenize("don't"), ["don't"]);
    }

    // ---- 模型（缺檔時跳過）----

    #[test]
    fn missing_model_reports_clearly() {
        let err = CtPunctuator::load("/nope.onnx", "/nope.json").unwrap_err();
        assert!(matches!(err, CtPunctError::ModelNotFound(_)));
        assert!(err.to_string().contains("標點模型"));
    }

    #[test]
    fn missing_tokens_reports_clearly() {
        let Some(dir) = model_dir() else { return };
        let (m, _) = default_paths(&dir);
        assert!(matches!(
            CtPunctuator::load(m, "/nope.json"),
            Err(CtPunctError::TokensNotFound(_))
        ));
    }

    #[test]
    fn loads_the_real_model() {
        let Some(e) = engine() else { return };
        assert_eq!(e.vocab_size(), 471_067);
    }

    #[test]
    fn adds_punctuation_to_simplified_chinese() {
        let Some(mut e) = engine() else { return };
        let out = e
            .punctuate("下周三下午三点在研讨室开会请大家准时参加")
            .unwrap();

        assert!(
            out.contains('，') || out.contains('。'),
            "應加入標點，實得：{out}"
        );
        // 原字元不得遺失
        let stripped: String = out.chars().filter(|c| !"，。？、".contains(*c)).collect();
        assert_eq!(stripped, "下周三下午三点在研讨室开会请大家准时参加");
    }

    #[test]
    fn traditional_chinese_has_a_higher_unknown_ratio() {
        // 詞表是簡體的。這條測試把「先標點、再轉繁體」的理由釘住。
        let Some(e) = engine() else { return };
        let simplified = e.unknown_ratio("今天我们要讲的是线性代数");
        let traditional = e.unknown_ratio("今天我們要講的是線性代數");

        assert!(
            traditional > simplified,
            "繁體未知詞比例應較高：繁={traditional:.2} 簡={simplified:.2}"
        );
        assert!(simplified < 0.05, "簡體不該有明顯未知詞：{simplified:.2}");
    }

    #[test]
    fn empty_text_yields_empty_output() {
        let Some(mut e) = engine() else { return };
        assert_eq!(e.punctuate("").unwrap(), "");
        assert_eq!(e.punctuate("   ").unwrap(), "");
    }

    #[test]
    fn long_text_is_chunked_without_losing_characters() {
        // 一小時轉錄有上萬字，整段送進全注意力模型會爆記憶體。
        let Some(mut e) = engine() else { return };
        e.set_chunk_size(64);

        let input = "今天我们要讲的是线性代数里面的特征值和特征向量".repeat(20);
        let out = e.punctuate(&input).unwrap();

        let stripped: String = out.chars().filter(|c| !"，。？、".contains(*c)).collect();
        assert_eq!(
            stripped.chars().count(),
            input.chars().count(),
            "分塊不得遺失字元"
        );
    }

    #[test]
    fn english_words_keep_their_spacing() {
        let Some(mut e) = engine() else { return };
        let out = e.punctuate("we use Rust here").unwrap();
        assert!(
            out.contains("we use Rust here") || out.contains("we use Rust"),
            "實得：{out}"
        );
    }

    #[test]
    fn timestamps_survive_punctuation() {
        use padnote_asr::PunctuationEngine;
        use padnote_doc::{NotebookTime, TranscriptWord};

        let Some(mut e) = engine() else { return };
        let words: Vec<TranscriptWord> = "下周三下午三点开会请准时"
            .chars()
            .enumerate()
            .map(|(i, c)| TranscriptWord {
                text: c.to_string(),
                start: NotebookTime::from_micros(i as u64 * 200_000),
                end: NotebookTime::from_micros((i as u64 + 1) * 200_000),
                confidence: 0.9,
            })
            .collect();

        let out = e.punctuate_words(&words).unwrap();
        assert_eq!(out.len(), words.len(), "詞數不變");
        assert_eq!(out[0].start, words[0].start, "時間戳不變");
        assert!(
            out.iter().any(|w| w.text.chars().count() > 1),
            "至少有一個詞帶上標點"
        );
    }
}
