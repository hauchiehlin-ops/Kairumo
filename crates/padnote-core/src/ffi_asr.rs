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

/// 依介面語言決定轉錄結果要用哪種中文字體。
///
/// # 為什麼要有這個
///
/// Whisper 的中文輸出多半是簡體，不管使用者的介面是不是繁體。轉出來的字
/// 放在一份繁體介面的筆記裡，讀起來像是別人貼進來的。核心早就有簡繁轉換器
/// （`padnote-text`），只是單次轉錄沒有人去呼叫它 —— 兩個平台各自轉的話
/// 遲早對不上，所以出口放在這裡。
///
/// 規則：繁體介面（台灣／香港）轉成對應正體；其餘介面一律原樣回傳
/// （簡體介面本來就是簡體，其他語言沒有中文可轉）。
#[uniffi::export]
pub fn localize_transcript_script(text: String, ui_language: String) -> String {
    use padnote_text::{ChineseConverter, Script};
    let tag = ui_language.replace('_', "-").to_ascii_lowercase();
    let script = if tag.starts_with("zh-hk") || tag.starts_with("zh-mo") {
        Script::TraditionalHk
    } else if tag.starts_with("zh-hant") || tag.starts_with("zh-tw") {
        Script::TraditionalTw
    } else {
        Script::None
    };
    if script == Script::None || !ChineseConverter::looks_simplified(&text) {
        return text;
    }
    ChineseConverter::new(script).convert(&text)
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

    #[cfg(feature = "asr-whisper")]
    {
        use padnote_asr::AsrEngine;
        // Whisper 只認 ISO 639-1（`zh`），不認 BCP-47（`zh-Hant`）。平台端傳的是
        // 介面語言標籤，取主語言子標籤；字體由 `localize_transcript_script` 另外處理。
        let lang = language
            .as_deref()
            .and_then(|l| l.split(['-', '_']).next())
            .filter(|l| !l.is_empty())
            .map(str::to_ascii_lowercase)
            .unwrap_or_else(|| "auto".to_string());

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

    #[cfg(not(feature = "asr-whisper"))]
    {
        let _ = model_path;
        let _ = language;
        Err(FfiAsrError::Backend(
            "此平台版本未啟用 Whisper 語音引擎".to_string(),
        ))
    }
}

#[cfg(test)]
mod script_tests {
    use super::localize_transcript_script as f;

    #[test]
    fn traditional_ui_converts_simplified_transcript() {
        assert_eq!(f("语音识别".into(), "zh-Hant".into()), "語音識別");
        assert_eq!(f("语音识别".into(), "zh_TW".into()), "語音識別");
    }

    #[test]
    fn other_ui_languages_are_untouched() {
        assert_eq!(f("语音识别".into(), "zh-Hans".into()), "语音识别");
        assert_eq!(f("hello".into(), "en".into()), "hello");
    }

    #[test]
    fn already_traditional_is_stable() {
        assert_eq!(f("語音識別".into(), "zh-Hant".into()), "語音識別");
    }
}
