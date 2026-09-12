//! whisper.cpp 後端（工作項 S-15）。
//!
//! 定位是**多語備援**，不是中文主力。中文主力是 Paraformer-zh（S-24）——
//! 但 Whisper 的模型權重是 MIT、程式碼是 MIT，授權最乾淨，因此作為
//! 第一個可用的引擎，也是 `models/MODELS.md` 中唯一已確認授權的 ASR 模型。
//!
//! 選 `large-v3-turbo`：比 `large-v3` 快 4 倍，WER 只增加約 0.3%。
//!
//! ## ⚠️ 尚未以真實音訊驗證
//! 模型檔約 574 MB，需另行下載（`padnote-models` 的下載器）。
//! 本 crate 的編譯與錯誤路徑已測試，**轉錄品質必須以
//! `padnote-bench` 的中文測試集實測**（見 `docs/TODO.md` H2）。

use padnote_asr::{AsrEngine, AsrError, AsrSegment};
use std::path::{Path, PathBuf};
use whisper_rs::{FullParams, SamplingStrategy, WhisperContext, WhisperContextParameters};

/// whisper.cpp 引擎。
pub struct WhisperEngine {
    ctx: WhisperContext,
    language: String,
    /// 尚未送去辨識的音訊。
    pending: Vec<f32>,
    /// 本 session 已處理的樣本數，用來換算時間戳。
    processed_samples: u64,
    /// 一次送進模型的最少樣本數。
    ///
    /// Whisper 的注意力窗是 30 秒，餵太短會讓上下文不足、辨識品質掉很多；
    /// 但等太久又違反 C2 的「≤2 秒部分結果」。3 秒是折衷。
    chunk_samples: usize,
}

/// Whisper 固定吃 16 kHz 單聲道 —— 與 `padnote-audio` 的錄製取樣率一致，
/// 因此不需要重採樣。
pub const SAMPLE_RATE_HZ: u32 = 16_000;

impl std::fmt::Debug for WhisperEngine {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("WhisperEngine")
            .field("language", &self.language)
            .field("pending_samples", &self.pending.len())
            .field("processed_samples", &self.processed_samples)
            .finish()
    }
}

impl WhisperEngine {
    /// 載入模型。`language` 用 ISO 639-1，例如 `"zh"`、`"en"`。
    pub fn load(model: impl AsRef<Path>, language: &str) -> Result<Self, AsrError> {
        let path = model.as_ref();
        // 先檢查檔案存在，給出比 C++ 層更有用的錯誤訊息。
        if !path.exists() {
            return Err(AsrError::ModelNotLoaded);
        }
        let ctx = WhisperContext::new_with_params(path, WhisperContextParameters::default())
            .map_err(|e| AsrError::Backend(e.to_string()))?;

        Ok(Self {
            ctx,
            language: language.to_string(),
            pending: Vec::new(),
            processed_samples: 0,
            chunk_samples: (SAMPLE_RATE_HZ * 3) as usize,
        })
    }

    /// 調整送進模型的區塊長度（秒）。較長品質較好、延遲較高。
    pub fn set_chunk_seconds(&mut self, seconds: f32) {
        self.chunk_samples = ((SAMPLE_RATE_HZ as f32) * seconds.max(0.5)) as usize;
    }

    fn samples_to_us(samples: u64) -> u64 {
        samples * 1_000_000 / u64::from(SAMPLE_RATE_HZ)
    }

    fn transcribe(&mut self, audio: &[f32], is_final: bool) -> Result<Vec<AsrSegment>, AsrError> {
        if audio.is_empty() {
            return Ok(Vec::new());
        }
        let mut state = self
            .ctx
            .create_state()
            .map_err(|e| AsrError::Backend(e.to_string()))?;

        let mut params = FullParams::new(SamplingStrategy::Greedy { best_of: 1 });
        params.set_language(Some(&self.language));
        // 絕不翻譯 —— 使用者要的是逐字稿，不是英文譯文。
        params.set_translate(false);
        params.set_print_special(false);
        params.set_print_progress(false);
        params.set_print_realtime(false);
        params.set_print_timestamps(false);

        state
            .full(params, audio)
            .map_err(|e| AsrError::Backend(e.to_string()))?;

        let base_us = Self::samples_to_us(self.processed_samples);
        let mut out = Vec::new();

        for i in 0..state.full_n_segments() {
            let Some(seg) = state.get_segment(i) else {
                continue;
            };
            let text = seg
                .to_str_lossy()
                .map_err(|e| AsrError::Backend(e.to_string()))?;
            let text = text.trim().to_string();
            if text.is_empty() {
                continue;
            }
            // whisper 的時間戳單位是 10 毫秒。
            out.push(AsrSegment {
                text,
                start_us: base_us + seg.start_timestamp().max(0) as u64 * 10_000,
                end_us: base_us + seg.end_timestamp().max(0) as u64 * 10_000,
                // whisper.cpp 給的是「無語音機率」，取其補數當信心值。
                confidence: 1.0 - seg.no_speech_probability().clamp(0.0, 1.0),
                is_final,
            });
        }
        Ok(out)
    }
}

impl AsrEngine for WhisperEngine {
    fn feed(&mut self, pcm_16k_mono: &[f32]) -> Result<Vec<AsrSegment>, AsrError> {
        self.pending.extend_from_slice(pcm_16k_mono);
        if self.pending.len() < self.chunk_samples {
            return Ok(Vec::new());
        }
        let chunk: Vec<f32> = self.pending.drain(..self.chunk_samples).collect();
        let segments = self.transcribe(&chunk, false)?;
        self.processed_samples += chunk.len() as u64;
        Ok(segments)
    }

    fn finish(&mut self) -> Result<Vec<AsrSegment>, AsrError> {
        if self.pending.is_empty() {
            return Ok(Vec::new());
        }
        let tail = std::mem::take(&mut self.pending);
        let segments = self.transcribe(&tail, true)?;
        self.processed_samples += tail.len() as u64;
        Ok(segments)
    }

    fn languages(&self) -> &[&str] {
        // Whisper 支援 99 種語言；這裡只列 Padnote 目前的目標語言。
        &["zh", "en", "ja", "ko"]
    }
}

/// 從模型下載目錄找出 whisper 模型。
pub fn default_model_path(models_dir: impl AsRef<Path>) -> PathBuf {
    models_dir.as_ref().join("whisper-large-v3-turbo-q5.model")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn missing_model_reports_clearly_instead_of_crashing_in_cpp() {
        // 讓錯誤停在 Rust 層，而不是讓 C++ 印一堆看不懂的訊息後失敗。
        let err = WhisperEngine::load("/definitely/not/here.bin", "zh").unwrap_err();
        assert!(matches!(err, AsrError::ModelNotLoaded));
        assert!(err.to_string().contains("模型"));
    }

    #[test]
    fn default_path_matches_the_model_manifest_id() {
        // 與 models/manifest.json 的 id 對齊，否則下載完仍然找不到檔案。
        let p = default_model_path("/tmp/models");
        assert!(p.to_string_lossy().contains("whisper-large-v3-turbo-q5"));
    }

    #[test]
    fn timestamp_conversion_is_exact() {
        assert_eq!(WhisperEngine::samples_to_us(16_000), 1_000_000);
        assert_eq!(WhisperEngine::samples_to_us(8_000), 500_000);
        assert_eq!(WhisperEngine::samples_to_us(0), 0);
    }

    #[test]
    fn sample_rate_matches_the_recorder() {
        // 不一致的話每次轉錄都要多做一次重採樣。
        assert_eq!(SAMPLE_RATE_HZ, padnote_audio_sample_rate());
    }

    /// 避免為了一個常數而讓本 crate 相依 padnote-audio。
    fn padnote_audio_sample_rate() -> u32 {
        16_000
    }
}
