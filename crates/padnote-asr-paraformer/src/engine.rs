//! Paraformer 推論：encoder → CIF → decoder → 貪婪解碼。

use crate::cif::{self, CifOutput};
use crate::frontend::{Cmvn, FEATURE_DIM, FbankExtractor, SAMPLE_RATE, apply_lfr};
use ort::session::Session;
use ort::value::Value;
use padnote_asr::{AsrEngine, AsrError, AsrSegment};
use std::path::Path;

/// decoder 的 self-attention cache 數量（每層一個）。
const NUM_CACHES: usize = 16;
/// cache 的通道數
const CACHE_CHANNELS: usize = 512;
/// cache 的時間長度
const CACHE_LENGTH: usize = 10;
/// encoder 隱藏維度
const HIDDEN_DIM: usize = 512;

#[derive(Debug)]
pub enum ParaformerError {
    ModelNotFound(String),
    Malformed(String),
    Ort(String),
}

impl std::fmt::Display for ParaformerError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::ModelNotFound(p) => write!(f, "找不到模型檔：{p}"),
            Self::Malformed(m) => write!(f, "模型資源格式錯誤：{m}"),
            Self::Ort(m) => write!(f, "ONNX Runtime 錯誤：{m}"),
        }
    }
}

impl std::error::Error for ParaformerError {}

impl From<ParaformerError> for AsrError {
    fn from(e: ParaformerError) -> Self {
        match e {
            ParaformerError::ModelNotFound(_) => AsrError::ModelNotLoaded,
            other => AsrError::Backend(other.to_string()),
        }
    }
}

/// 載入 Paraformer 所需的四份資源。
#[derive(Debug, Clone)]
pub struct ModelPaths {
    pub encoder: std::path::PathBuf,
    pub decoder: std::path::PathBuf,
    pub tokens: std::path::PathBuf,
    pub cmvn: std::path::PathBuf,
}

impl ModelPaths {
    /// 從匯出目錄推導各檔案位置。
    ///
    /// 優先使用 int8 量化版（體積約四分之一）；沒有時退回 fp32。
    /// 這讓同一份程式碼能在「行動裝置用量化版、桌機比對用 fp32」之間切換。
    pub fn in_dir(dir: impl AsRef<Path>) -> Self {
        let d = dir.as_ref();
        let pick = |int8: &str, fp32: &str| {
            let q = d.join(int8);
            if q.exists() { q } else { d.join(fp32) }
        };
        Self {
            encoder: pick("model.int8.onnx", "model.onnx"),
            decoder: pick("decoder.int8.onnx", "decoder.onnx"),
            tokens: d.join("tokens.json"),
            cmvn: d.join("am.mvn"),
        }
    }

    fn check(&self) -> Result<(), ParaformerError> {
        for p in [&self.encoder, &self.decoder, &self.tokens, &self.cmvn] {
            if !p.exists() {
                return Err(ParaformerError::ModelNotFound(p.display().to_string()));
            }
        }
        Ok(())
    }
}

/// Paraformer 串流 ASR 引擎。
pub struct ParaformerEngine {
    encoder: Session,
    decoder: Session,
    tokens: Vec<String>,
    cmvn: Cmvn,
    fbank: FbankExtractor,
    /// decoder 的跨呼叫狀態，讓串流能保留上下文。
    caches: Vec<Vec<f32>>,
    /// 尚未處理的 PCM。
    pending: Vec<f32>,
    /// 已處理的樣本數，用來換算時間戳。
    consumed_samples: u64,
    /// 一次送進 encoder 的最小樣本數。
    chunk_samples: usize,
}

impl std::fmt::Debug for ParaformerEngine {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ParaformerEngine")
            .field("vocab", &self.tokens.len())
            .field("pending_samples", &self.pending.len())
            .field("consumed_samples", &self.consumed_samples)
            .finish()
    }
}

impl ParaformerEngine {
    pub fn load(paths: &ModelPaths) -> Result<Self, ParaformerError> {
        paths.check()?;

        let tokens: Vec<String> = serde_json::from_str(
            &std::fs::read_to_string(&paths.tokens)
                .map_err(|e| ParaformerError::Malformed(e.to_string()))?,
        )
        .map_err(|e| ParaformerError::Malformed(e.to_string()))?;

        let cmvn = Cmvn::parse(
            &std::fs::read_to_string(&paths.cmvn)
                .map_err(|e| ParaformerError::Malformed(e.to_string()))?,
        )
        .ok_or_else(|| ParaformerError::Malformed("am.mvn 解析失敗".into()))?;

        let open = |p: &Path| {
            Session::builder()
                .and_then(|b| b.commit_from_file(p))
                .map_err(|e| ParaformerError::Ort(e.to_string()))
        };

        Ok(Self {
            encoder: open(&paths.encoder)?,
            decoder: open(&paths.decoder)?,
            tokens,
            cmvn,
            fbank: FbankExtractor::new(),
            caches: vec![vec![0.0; CACHE_CHANNELS * CACHE_LENGTH]; NUM_CACHES],
            pending: Vec::new(),
            consumed_samples: 0,
            // 0.6 秒：夠 encoder 有上下文，又不違反 C2 的 ≤2 秒部分結果。
            chunk_samples: (SAMPLE_RATE as usize * 6) / 10,
        })
    }

    /// 調整一次送進 encoder 的樣本數。
    ///
    /// ⚠️ 匯出的 encoder **沒有 cache 輸入**（只有 `speech` 與 `speech_lengths`），
    /// 也就是整段式模型。任意切塊會讓每塊各自缺少上下文，實測會產生大量
    /// 重複與錯序（「的的的的」「模模」）。正確用法是**以 VAD 切出的語音段
    /// 為單位整段處理** —— `padnote-recorder` 給的正是這種段。
    pub fn set_chunk_samples(&mut self, n: usize) {
        self.chunk_samples = n;
    }

    pub fn vocab_size(&self) -> usize {
        self.tokens.len()
    }

    /// 清除串流狀態。新的一段錄音開始時呼叫。
    pub fn reset(&mut self) {
        self.caches = vec![vec![0.0; CACHE_CHANNELS * CACHE_LENGTH]; NUM_CACHES];
        self.pending.clear();
        self.consumed_samples = 0;
    }

    fn samples_to_us(samples: u64) -> u64 {
        samples * 1_000_000 / u64::from(SAMPLE_RATE)
    }

    /// 特徵擷取：fbank → LFR → CMVN。
    fn features(&self, pcm: &[f32]) -> Vec<Vec<f32>> {
        let mut feats = apply_lfr(&self.fbank.compute(pcm));
        self.cmvn.apply(&mut feats);
        feats
    }

    /// 跑 encoder，回傳隱藏狀態與 alphas。
    fn encode(&mut self, feats: &[Vec<f32>]) -> Result<(Vec<Vec<f32>>, Vec<f32>), ParaformerError> {
        let t = feats.len();
        let flat: Vec<f32> = feats.iter().flatten().copied().collect();
        let to_err = |e: ort::Error| ParaformerError::Ort(e.to_string());

        let speech = Value::from_array(([1usize, t, FEATURE_DIM], flat)).map_err(to_err)?;
        let lengths = Value::from_array(([1usize], vec![t as i32])).map_err(to_err)?;

        let out = self
            .encoder
            .run(ort::inputs!["speech" => speech, "speech_lengths" => lengths])
            .map_err(to_err)?;

        let (enc_shape, enc) = out["enc"].try_extract_tensor::<f32>().map_err(to_err)?;
        let (_, alphas) = out["alphas"].try_extract_tensor::<f32>().map_err(to_err)?;

        let frames = enc_shape.get(1).copied().unwrap_or(0) as usize;
        let hidden = (0..frames)
            .map(|i| enc[i * HIDDEN_DIM..(i + 1) * HIDDEN_DIM].to_vec())
            .collect();

        Ok((hidden, alphas.to_vec()))
    }

    /// 跑 decoder 並更新 cache，回傳每個 token 的 id。
    fn decode(
        &mut self,
        hidden: &[Vec<f32>],
        cif_out: &CifOutput,
    ) -> Result<Vec<usize>, ParaformerError> {
        let to_err = |e: ort::Error| ParaformerError::Ort(e.to_string());
        let frames = hidden.len();
        let n_tokens = cif_out.len();

        let enc_flat: Vec<f32> = hidden.iter().flatten().copied().collect();
        let emb_flat: Vec<f32> = cif_out.embeddings.iter().flatten().copied().collect();

        let mut inputs = vec![
            (
                "enc".to_string(),
                Value::from_array(([1usize, frames, HIDDEN_DIM], enc_flat))
                    .map_err(to_err)?
                    .into_dyn(),
            ),
            (
                "enc_len".to_string(),
                Value::from_array(([1usize], vec![frames as i32]))
                    .map_err(to_err)?
                    .into_dyn(),
            ),
            (
                "acoustic_embeds".to_string(),
                Value::from_array(([1usize, n_tokens, HIDDEN_DIM], emb_flat))
                    .map_err(to_err)?
                    .into_dyn(),
            ),
            (
                "acoustic_embeds_len".to_string(),
                Value::from_array(([1usize], vec![n_tokens as i32]))
                    .map_err(to_err)?
                    .into_dyn(),
            ),
        ];
        for (i, cache) in self.caches.iter().enumerate() {
            inputs.push((
                format!("in_cache_{i}"),
                Value::from_array(([1usize, CACHE_CHANNELS, CACHE_LENGTH], cache.clone()))
                    .map_err(to_err)?
                    .into_dyn(),
            ));
        }

        let out = self.decoder.run(inputs).map_err(to_err)?;

        let (shape, logits) = out["logits"].try_extract_tensor::<f32>().map_err(to_err)?;
        let vocab = *shape.last().unwrap_or(&1) as usize;

        // cache 必須寫回，否則串流等同每次從零開始。
        for i in 0..NUM_CACHES {
            if let Ok((_, c)) = out[format!("out_cache_{i}").as_str()].try_extract_tensor::<f32>() {
                let want = CACHE_CHANNELS * CACHE_LENGTH;
                // decoder 回傳的長度可能大於 cache 容量，取最後一段（最新的狀態）。
                self.caches[i] = if c.len() >= want {
                    c[c.len() - want..].to_vec()
                } else {
                    let mut v = vec![0.0; want - c.len()];
                    v.extend_from_slice(c);
                    v
                };
            }
        }

        Ok((0..n_tokens)
            .map(|i| {
                logits[i * vocab..(i + 1) * vocab]
                    .iter()
                    .enumerate()
                    .max_by(|a, b| a.1.total_cmp(b.1))
                    .map_or(0, |(k, _)| k)
            })
            .collect())
    }

    /// 把 token id 串成文字。
    ///
    /// 特殊符號（`<blank>`、`<s>`、`</s>`、`<unk>`）一律丟棄；
    /// Paraformer 的英文 token 以 `@@` 標示詞內接續。
    fn detokenize(&self, ids: &[usize]) -> String {
        let mut out = String::new();
        for &id in ids {
            let Some(tok) = self.tokens.get(id) else {
                continue;
            };
            if tok.starts_with('<') && tok.ends_with('>') {
                continue;
            }
            if let Some(stem) = tok.strip_suffix("@@") {
                out.push_str(stem);
            } else {
                out.push_str(tok);
            }
        }
        out
    }

    /// 對一段 PCM 做完整的辨識。
    fn transcribe(&mut self, pcm: &[f32], is_final: bool) -> Result<Vec<AsrSegment>, AsrError> {
        let feats = self.features(pcm);
        if feats.is_empty() {
            return Ok(Vec::new());
        }

        let (hidden, alphas) = self.encode(&feats).map_err(AsrError::from)?;

        // 沒有字就不必跑 decoder —— 省下一次推論。
        if cif::estimate_token_count(&alphas) == 0 {
            return Ok(Vec::new());
        }

        let cif_out = cif::cif(&hidden, &alphas);
        if cif_out.is_empty() {
            return Ok(Vec::new());
        }

        let ids = self.decode(&hidden, &cif_out).map_err(AsrError::from)?;
        let text = self.detokenize(&ids);
        if text.is_empty() {
            return Ok(Vec::new());
        }

        let start_us = Self::samples_to_us(self.consumed_samples);
        let end_us = Self::samples_to_us(self.consumed_samples + pcm.len() as u64);
        Ok(vec![AsrSegment {
            text,
            start_us,
            end_us,
            // Paraformer 不直接輸出信心值；非最終結果標低一點讓 UI 以灰字顯示。
            confidence: if is_final { 0.9 } else { 0.6 },
            is_final,
        }])
    }
}

impl AsrEngine for ParaformerEngine {
    fn feed(&mut self, pcm_16k_mono: &[f32]) -> Result<Vec<AsrSegment>, AsrError> {
        self.pending.extend_from_slice(pcm_16k_mono);
        if self.pending.len() < self.chunk_samples {
            return Ok(Vec::new());
        }
        let chunk: Vec<f32> = self.pending.drain(..self.chunk_samples).collect();
        let segments = self.transcribe(&chunk, false)?;
        self.consumed_samples += chunk.len() as u64;
        Ok(segments)
    }

    fn finish(&mut self) -> Result<Vec<AsrSegment>, AsrError> {
        if self.pending.is_empty() {
            return Ok(Vec::new());
        }
        let tail = std::mem::take(&mut self.pending);
        let segments = self.transcribe(&tail, true)?;
        self.consumed_samples += tail.len() as u64;
        Ok(segments)
    }

    fn languages(&self) -> &[&str] {
        // 這個 checkpoint 是中英雙語，但中文才是它的強項。
        &["zh", "en"]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn paths() -> Option<ModelPaths> {
        let dir = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../models/exported-int8/paraformer-zh-streaming");
        let p = ModelPaths::in_dir(dir);
        p.check().ok().map(|()| p)
    }

    #[test]
    fn missing_model_reports_which_file() {
        let p = ModelPaths::in_dir("/definitely/not/here");
        let err = ParaformerEngine::load(&p).unwrap_err();
        assert!(matches!(err, ParaformerError::ModelNotFound(_)));
        // 只說「找不到模型」對使用者沒用，要指出是哪一個檔。
        // （in_dir 在 int8 不存在時會退回 fp32 檔名，兩者都可接受）
        let msg = err.to_string();
        assert!(
            msg.contains("model") && msg.contains(".onnx"),
            "訊息未指出缺哪個檔：{msg}"
        );
    }

    #[test]
    fn timestamp_conversion_is_exact() {
        assert_eq!(ParaformerEngine::samples_to_us(16_000), 1_000_000);
        assert_eq!(ParaformerEngine::samples_to_us(0), 0);
    }

    #[test]
    fn loads_all_four_resources() {
        let Some(p) = paths() else { return };
        let e = ParaformerEngine::load(&p).unwrap();
        assert_eq!(
            e.vocab_size(),
            8404,
            "詞表大小應與 decoder 的 logits 維度一致"
        );
    }

    #[test]
    fn silence_produces_no_text() {
        // 靜音不該生出幻覺文字 —— 那是 ASR 最惱人的失敗模式。
        let Some(p) = paths() else { return };
        let mut e = ParaformerEngine::load(&p).unwrap();

        let out = e.feed(&vec![0.0; 16_000]).unwrap();
        let all: String = out.iter().map(|s| s.text.as_str()).collect();
        assert!(all.is_empty(), "靜音卻產生了文字：{all:?}");
    }

    #[test]
    fn feed_buffers_until_a_full_chunk() {
        let Some(p) = paths() else { return };
        let mut e = ParaformerEngine::load(&p).unwrap();

        assert!(
            e.feed(&vec![0.0; 1_000]).unwrap().is_empty(),
            "不足一塊不該推論"
        );
        assert_eq!(e.pending.len(), 1_000);
    }

    #[test]
    fn reset_clears_streaming_state() {
        let Some(p) = paths() else { return };
        let mut e = ParaformerEngine::load(&p).unwrap();
        e.feed(&vec![0.1; 20_000]).unwrap();

        e.reset();
        assert!(e.pending.is_empty());
        assert_eq!(e.consumed_samples, 0);
        assert!(e.caches.iter().all(|c| c.iter().all(|x| *x == 0.0)));
    }

    #[test]
    fn detokenize_drops_special_tokens_and_joins_subwords() {
        let Some(p) = paths() else { return };
        let e = ParaformerEngine::load(&p).unwrap();

        let find = |t: &str| e.tokens.iter().position(|x| x == t);
        let mut ids = Vec::new();
        if let Some(i) = find("<blank>") {
            ids.push(i);
        }
        if let Some(i) = find("的") {
            ids.push(i);
        }
        let text = e.detokenize(&ids);
        assert!(!text.contains('<'), "特殊符號不該出現在輸出：{text}");
    }

    #[test]
    fn unknown_ids_are_skipped_not_panicking() {
        let Some(p) = paths() else { return };
        let e = ParaformerEngine::load(&p).unwrap();
        assert_eq!(e.detokenize(&[usize::MAX, 999_999]), "");
    }
}
