//! Silero VAD 後端（工作項 S-26）。
//!
//! 取代 `padnote-asr::EnergyVad` —— 能量門檻法在有背景噪音時會把冷氣聲
//! 當成語音，真實教室環境下幾乎不可用。
//!
//! ## 為什麼是 ONNX Runtime 而不是純 Rust 的 tract
//! 先試過 `tract-onnx`（純 Rust、零原生相依，最符合專案約束），
//! 但它無法處理 Silero 模型的 `If` 節點 —— v4 與 v5 皆然，
//! then/else 兩個分支的輸出秩不一致，`ToTypedTranslator` 直接失敗。
//!
//! 改用 `ort` 是**更好的架構決定**：同一個執行期之後還要服務
//! Paraformer-zh（S-24）與 PP-OCRv5（D4），一套推論庫服務三個用途，
//! 比每個模型各帶一套划算。
//!
//! ## 模型版本
//! 目前用 **v4**（1.8 MB，MIT）。v5 品質更好但 IO 介面不同，
//! 升級列為 TODO S-28。

pub mod gate;

pub use gate::SpeechGate;

use ort::session::Session;
use ort::value::Value;
use padnote_asr::VoiceActivityDetector;
use std::path::Path;

/// Silero v4 在 16 kHz 下的固定輸入長度。
///
/// 模型**只接受這個長度**，餵別的會出錯。因此本型別內部做緩衝，
/// 讓呼叫端可以用任意音框大小（例如 `Segmenter` 的 20 ms / 320 樣本）。
pub const WINDOW_SAMPLES: usize = 512;

/// LSTM 隱藏狀態維度。
const STATE_DIM: usize = 64;
const STATE_LAYERS: usize = 2;

#[derive(Debug)]
pub enum VadError {
    ModelNotFound(String),
    Ort(String),
}

impl std::fmt::Display for VadError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::ModelNotFound(p) => write!(f, "找不到 VAD 模型：{p}"),
            Self::Ort(m) => write!(f, "ONNX Runtime 錯誤：{m}"),
        }
    }
}

impl std::error::Error for VadError {}

/// Silero VAD。
pub struct SileroVad {
    session: Session,
    /// LSTM 狀態。**必須跨呼叫保留** —— 重置會讓模型失去上下文，
    /// 判斷品質明顯下降。
    h: Vec<f32>,
    c: Vec<f32>,
    /// 尚未湊滿一個推論窗的樣本。
    buffer: Vec<f32>,
    gate: SpeechGate,
    last_probability: f32,
}

impl std::fmt::Debug for SileroVad {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("SileroVad")
            .field("buffered", &self.buffer.len())
            .field("last_probability", &self.last_probability)
            .field("speaking", &self.gate.is_speaking())
            .finish()
    }
}

impl SileroVad {
    pub fn load(model: impl AsRef<Path>) -> Result<Self, VadError> {
        let path = model.as_ref();
        // 先檢查存在，給出比 ORT 更有用的錯誤訊息。
        if !path.exists() {
            return Err(VadError::ModelNotFound(path.display().to_string()));
        }
        let session = Session::builder()
            .and_then(|b| b.commit_from_file(path))
            .map_err(|e| VadError::Ort(e.to_string()))?;

        Ok(Self {
            session,
            h: vec![0.0; STATE_LAYERS * STATE_DIM],
            c: vec![0.0; STATE_LAYERS * STATE_DIM],
            buffer: Vec::with_capacity(WINDOW_SAMPLES * 2),
            gate: SpeechGate::default(),
            last_probability: 0.0,
        })
    }

    /// 調整開始／停止門檻。
    pub fn set_thresholds(&mut self, start: f32, stop: f32) {
        self.gate = SpeechGate::new(start, stop);
    }

    /// 最近一次推論得到的語音機率。UI 可用來畫音量／語音指示。
    pub fn last_probability(&self) -> f32 {
        self.last_probability
    }

    /// 新的一段錄音開始時呼叫：清掉 LSTM 狀態與緩衝。
    pub fn reset(&mut self) {
        self.h.fill(0.0);
        self.c.fill(0.0);
        self.buffer.clear();
        self.gate.reset();
        self.last_probability = 0.0;
    }

    /// 對一個完整的推論窗做推論，回傳語音機率。
    fn infer(&mut self, window: &[f32]) -> Result<f32, VadError> {
        let to_err = |e: ort::Error| VadError::Ort(e.to_string());

        let input = Value::from_array(([1usize, window.len()], window.to_vec())).map_err(to_err)?;
        let sr = Value::from_array(([1usize], vec![16_000i64])).map_err(to_err)?;
        let h = Value::from_array(([STATE_LAYERS, 1usize, STATE_DIM], self.h.clone()))
            .map_err(to_err)?;
        let c = Value::from_array(([STATE_LAYERS, 1usize, STATE_DIM], self.c.clone()))
            .map_err(to_err)?;

        let out = self
            .session
            .run(ort::inputs!["input" => input, "sr" => sr, "h" => h, "c" => c])
            .map_err(to_err)?;

        let (_, prob) = out["output"].try_extract_tensor::<f32>().map_err(to_err)?;
        let probability = prob[0];

        // 狀態必須寫回，否則等同每次都從零開始。
        let (_, hn) = out["hn"].try_extract_tensor::<f32>().map_err(to_err)?;
        let (_, cn) = out["cn"].try_extract_tensor::<f32>().map_err(to_err)?;
        self.h = hn.to_vec();
        self.c = cn.to_vec();

        Ok(probability)
    }
}

impl VoiceActivityDetector for SileroVad {
    /// 判斷這個音框是否為語音。
    ///
    /// 音框長度**不必**等於 `WINDOW_SAMPLES`：不足的部分會累積，
    /// 湊滿才推論；在那之前沿用上一次的判定結果。這讓 `Segmenter`
    /// 可以維持 20 ms 的音框而不必為了 VAD 改變粒度。
    fn is_speech(&mut self, frame: &[f32]) -> bool {
        self.buffer.extend_from_slice(frame);

        while self.buffer.len() >= WINDOW_SAMPLES {
            let window: Vec<f32> = self.buffer.drain(..WINDOW_SAMPLES).collect();
            match self.infer(&window) {
                Ok(p) => {
                    self.last_probability = p;
                    self.gate.update(p);
                }
                // 推論失敗時維持上一次的判定，而不是把整段語音誤判成靜音。
                // 音檔本身不受影響（S-25 的不變式）。
                Err(_) => break,
            }
        }
        self.gate.is_speaking()
    }
}

/// 從模型目錄找出 Silero VAD 模型。
pub fn default_model_path(models_dir: impl AsRef<Path>) -> std::path::PathBuf {
    models_dir.as_ref().join("silero-vad-v4.onnx")
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 測試用模型路徑。缺檔時測試跳過而非失敗 —— 模型是 gitignore 的衍生檔案，
    /// CI 上不一定有。
    fn model() -> Option<std::path::PathBuf> {
        let p = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../models/cache/silero-vad-v4.onnx");
        p.exists().then_some(p)
    }

    fn silence(n: usize) -> Vec<f32> {
        vec![0.0; n]
    }

    /// 多頻率疊加 + 包絡調變，比純正弦更接近人聲的頻譜結構。
    fn voice_like(n: usize) -> Vec<f32> {
        (0..n)
            .map(|i| {
                let t = i as f32 / 16_000.0;
                let env = 0.5 + 0.5 * (t * 2.0 * std::f32::consts::PI * 4.0).sin();
                env * (0.5 * (t * 2.0 * std::f32::consts::PI * 140.0).sin()
                    + 0.3 * (t * 2.0 * std::f32::consts::PI * 420.0).sin()
                    + 0.2 * (t * 2.0 * std::f32::consts::PI * 1_100.0).sin())
            })
            .collect()
    }

    #[test]
    fn missing_model_is_reported_clearly() {
        let err = SileroVad::load("/definitely/not/here.onnx").unwrap_err();
        assert!(matches!(err, VadError::ModelNotFound(_)));
        assert!(err.to_string().contains("VAD 模型"));
    }

    #[test]
    fn loads_the_real_model() {
        let Some(p) = model() else { return };
        assert!(SileroVad::load(p).is_ok());
    }

    #[test]
    fn silence_scores_lower_than_voice() {
        let Some(p) = model() else { return };

        let mut vad = SileroVad::load(&p).unwrap();
        vad.is_speech(&silence(WINDOW_SAMPLES * 4));
        let quiet = vad.last_probability();

        let mut vad = SileroVad::load(&p).unwrap();
        vad.is_speech(&voice_like(WINDOW_SAMPLES * 6));
        let loud = vad.last_probability();

        assert!(loud > quiet, "語音機率 {loud:.4} 應高於靜音 {quiet:.4}");
    }

    #[test]
    fn accepts_frames_smaller_than_the_inference_window() {
        // Segmenter 用 20 ms（320 樣本），模型要 512 —— 緩衝必須正確處理。
        let Some(p) = model() else { return };
        let mut vad = SileroVad::load(p).unwrap();

        // 第一個 320 樣本不足以推論，機率應維持初始值
        vad.is_speech(&voice_like(320));
        assert_eq!(vad.last_probability(), 0.0, "不足一個窗不該推論");

        // 再餵 320 → 共 640 ≥ 512，應觸發一次推論
        vad.is_speech(&voice_like(320));
        assert!(vad.last_probability() > 0.0, "湊滿後必須推論");
    }

    #[test]
    fn state_persists_across_calls() {
        // LSTM 狀態重置會讓模型失去上下文，判斷品質明顯下降。
        let Some(p) = model() else { return };
        let mut vad = SileroVad::load(p).unwrap();

        vad.is_speech(&voice_like(WINDOW_SAMPLES));
        let h_before = vad.h.clone();
        vad.is_speech(&voice_like(WINDOW_SAMPLES));

        assert_ne!(vad.h, h_before, "狀態必須隨推論更新");
        assert!(vad.h.iter().any(|x| *x != 0.0), "狀態不該是全零");
    }

    #[test]
    fn reset_clears_state_and_buffer() {
        let Some(p) = model() else { return };
        let mut vad = SileroVad::load(p).unwrap();
        vad.is_speech(&voice_like(WINDOW_SAMPLES + 100));

        vad.reset();
        assert!(vad.h.iter().all(|x| *x == 0.0));
        assert!(vad.buffer.is_empty());
        assert_eq!(vad.last_probability(), 0.0);
    }

    #[test]
    fn thresholds_are_configurable() {
        let Some(p) = model() else { return };
        let mut vad = SileroVad::load(p).unwrap();
        vad.set_thresholds(0.9, 0.8);
        assert_eq!(vad.gate.start_threshold, 0.9);
    }

    #[test]
    fn default_path_matches_the_manifest_id() {
        let p = default_model_path("/tmp/models");
        assert!(p.to_string_lossy().ends_with("silero-vad-v4.onnx"));
    }
}
