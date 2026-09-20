//! 端側語音辨識 FFI 介面（工作項 S-95）。
//!
//! 整合 `padnote-asr-whisper`，為現有錄音檔或即時音訊提供端側轉錄、
//! 自動語言偵測與智慧標點還原。

#[derive(uniffi::Record, Clone, Debug)]
pub struct FfiTranscribeSegment {
    pub text: String,
    pub start_ms: u64,
    pub end_ms: u64,
    pub confidence: f32,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct FfiTranscribeResult {
    pub text: String,
    pub language: String,
    pub segments: Vec<FfiTranscribeSegment>,
}

#[derive(uniffi::Error, thiserror::Error, Debug)]
pub enum FfiAsrError {
    #[error("模型檔案不存在或無法載入: {0}")]
    ModelNotLoaded(String),
    #[error("轉錄處理失敗: {0}")]
    Backend(String),
    #[error("音訊資料無效: {0}")]
    InvalidAudio(String),
}

#[uniffi::export]
pub fn whisper_is_model_available(model_path: String) -> bool {
    let p = std::path::Path::new(&model_path);
    if let Ok(meta) = std::fs::metadata(p) {
        meta.is_file() && meta.len() > 100_000_000
    } else {
        false
    }
}

#[uniffi::export]
pub fn whisper_transcribe_pcm(
    model_path: String,
    pcm_16k_mono: Vec<f32>,
    language: Option<String>,
) -> Result<FfiTranscribeResult, FfiAsrError> {
    if pcm_16k_mono.is_empty() {
        return Err(FfiAsrError::InvalidAudio("音訊資料長度為零".to_string()));
    }

    #[cfg(feature = "asr")]
    {
        use padnote_asr::AsrEngine;
        let lang = language.unwrap_or_else(|| "auto".to_string());

        let mut engine = padnote_asr_whisper::WhisperEngine::load(&model_path, &lang)
            .map_err(|e| FfiAsrError::ModelNotLoaded(e.to_string()))?;

        // 饋入完整的 16kHz PCM 資料
        let mut segments = engine
            .feed(&pcm_16k_mono)
            .map_err(|e| FfiAsrError::Backend(e.to_string()))?;

        let finish_segments = engine
            .finish()
            .map_err(|e| FfiAsrError::Backend(e.to_string()))?;
        segments.extend(finish_segments);

        let ffi_segs: Vec<FfiTranscribeSegment> = segments
            .into_iter()
            .map(|s| FfiTranscribeSegment {
                text: s.text,
                start_ms: s.start_us / 1000,
                end_ms: s.end_us / 1000,
                confidence: s.confidence,
            })
            .collect();

        let full_text = ffi_segs
            .iter()
            .map(|s| s.text.as_str())
            .collect::<Vec<_>>()
            .join(" ");

        Ok(FfiTranscribeResult {
            text: full_text,
            language: lang,
            segments: ffi_segs,
        })
    }

    #[cfg(not(feature = "asr"))]
    {
        let _ = model_path;
        let _ = language;
        Err(FfiAsrError::Backend(
            "此平台版本未啟用 ASR 語音引擎".to_string(),
        ))
    }
}
