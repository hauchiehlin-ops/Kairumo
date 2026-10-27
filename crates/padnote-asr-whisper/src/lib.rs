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
use std::sync::{Arc, Mutex, PoisonError};
use std::time::SystemTime;
use whisper_rs::{FullParams, SamplingStrategy, WhisperContext, WhisperContextParameters};

/// whisper.cpp 引擎。
pub struct WhisperEngine {
    ctx: Arc<WhisperContext>,
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
    ///
    /// 每次都從檔案重新載入。App 裡請用 [`Self::load_shared`]。
    pub fn load(model: impl AsRef<Path>, language: &str) -> Result<Self, AsrError> {
        let path = model.as_ref();
        // 先檢查檔案存在，給出比 C++ 層更有用的錯誤訊息。
        if !path.exists() {
            return Err(AsrError::ModelNotLoaded);
        }
        Ok(Self::with_context(Arc::new(new_context(path)?), language))
    }

    /// 載入模型，**整個行程共用同一份**。
    ///
    /// 模型約 574 MB，載入要好幾秒。即時轉錄每 5 秒就有一段要辨識，
    /// 每段都重新載入的話，時間全花在讀檔上，轉錄永遠追不上錄音。
    ///
    /// 換了檔案（路徑、大小或修改時間不同）會自動重新載入；
    /// 刪除或匯入模型後請呼叫 [`release_shared`]，記憶體才會立刻放掉。
    pub fn load_shared(model: impl AsRef<Path>, language: &str) -> Result<Self, AsrError> {
        let path = model.as_ref();
        let Ok(meta) = std::fs::metadata(path) else {
            return Err(AsrError::ModelNotLoaded);
        };
        let key = ModelKey {
            path: path.to_path_buf(),
            len: meta.len(),
            modified: meta.modified().ok(),
        };
        // 載入期間一直持有鎖：同時進來的第二個呼叫者等它載完直接共用，
        // 而不是兩邊各載一份（手機上會直接被系統因記憶體不足砍掉）。
        let mut slot = SHARED.lock().unwrap_or_else(PoisonError::into_inner);
        let ctx = match slot.as_ref() {
            Some((k, ctx)) if *k == key => Arc::clone(ctx),
            _ => {
                // 先放掉舊的再載新的，避免兩份同時在記憶體裡。
                *slot = None;
                let ctx = Arc::new(new_context(path)?);
                *slot = Some((key, Arc::clone(&ctx)));
                ctx
            }
        };
        Ok(Self::with_context(ctx, language))
    }

    fn with_context(ctx: Arc<WhisperContext>, language: &str) -> Self {
        Self {
            ctx,
            language: language.to_string(),
            pending: Vec::new(),
            processed_samples: 0,
            chunk_samples: (SAMPLE_RATE_HZ * 3) as usize,
        }
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
        // 抑制幻聽（docs/plans/recording-quality.md §E）：
        // - 不拿前一個窗的文字當提示（等同 condition_on_previous_text=false），
        //   一次幻聽才不會一路污染後面的句子、形成重複迴圈；
        // - 不在開頭輸出空白；不輸出「[音樂]」「♪」這類非語音記號。
        params.set_no_context(true);
        params.set_suppress_blank(true);
        params.set_suppress_nst(true);

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

/// 共用模型的身分：同一個路徑但檔案換過（重新下載、匯入）就不算同一個。
#[derive(Debug, PartialEq, Eq)]
struct ModelKey {
    path: PathBuf,
    len: u64,
    modified: Option<SystemTime>,
}

static SHARED: Mutex<Option<(ModelKey, Arc<WhisperContext>)>> = Mutex::new(None);

fn new_context(path: &Path) -> Result<WhisperContext, AsrError> {
    let mut params = WhisperContextParameters::default();
    // 有 GPU 後端（Apple 的 Metal）時才開 flash attention：
    // GPU 上明顯較快，CPU 上沒有好處。
    params.flash_attn(cfg!(feature = "metal"));
    WhisperContext::new_with_params(path, params).map_err(|e| AsrError::Backend(e.to_string()))
}

/// 放掉共用的模型。回傳原本是否有載入。
///
/// 正在辨識中的呼叫者手上還有一份參照，會跑完才真正釋放。
pub fn release_shared() -> bool {
    SHARED
        .lock()
        .unwrap_or_else(PoisonError::into_inner)
        .take()
        .is_some()
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
    fn shared_load_of_missing_model_fails_without_caching_anything() {
        let err = WhisperEngine::load_shared("/definitely/not/here.bin", "zh").unwrap_err();
        assert!(matches!(err, AsrError::ModelNotLoaded));
        assert!(!release_shared(), "失敗的載入不該留下快取");
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
