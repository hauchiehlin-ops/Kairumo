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

/// 事後轉錄的前處理選項。
///
/// 預設（[`default_transcribe_options`]）：高通、AGC、VAD 切段開，**降噪關**。
/// 降噪常讓辨識變差（見 `padnote-denoise`），只給「重新轉錄」時使用者自己選；
/// 要改成預設開，必須先有 `padnote-bench asr-ab` 的真實教室 A/B 結果。
#[derive(uniffi::Record, Clone, Copy, Debug, PartialEq, Eq)]
pub struct FfiTranscribeOptions {
    /// 80 Hz 高通（冷氣、桌面震動的隆隆聲）。
    pub high_pass: bool,
    /// 慢速自動增益（遠處講者）。
    pub agc: bool,
    /// 先用 VAD 切出有人聲的段落，只送那些進 Whisper（抑制幻聽與重複迴圈）。
    pub vad_segment: bool,
    /// RNNoise 降噪。**預設關**。
    pub denoise: bool,
}

impl Default for FfiTranscribeOptions {
    fn default() -> Self {
        let p = padnote_asr::PrepOptions::default();
        Self {
            high_pass: p.high_pass,
            agc: p.agc,
            vad_segment: p.vad_segment,
            denoise: false,
        }
    }
}

impl FfiTranscribeOptions {
    fn prep(self) -> padnote_asr::PrepOptions {
        padnote_asr::PrepOptions {
            high_pass: self.high_pass,
            agc: self.agc,
            vad_segment: self.vad_segment,
        }
    }
}

/// 平台取預設值用（兩個平台都從核心拿，不各自寫死）。
#[uniffi::export]
pub fn default_transcribe_options() -> FfiTranscribeOptions {
    FfiTranscribeOptions::default()
}

/// 與引擎無關的轉錄流程：（可選）降噪 → 高通 → VAD 切段 → AGC → 逐段送進引擎。
///
/// 拆出來是為了能用假引擎測 —— Whisper 模型 574 MB，CI 與本機都沒有。
#[cfg_attr(not(feature = "asr-whisper"), allow(dead_code))]
pub(crate) fn transcribe_with_engine<E: padnote_asr::AsrEngine + ?Sized>(
    engine: &mut E,
    pcm_16k_mono: &[f32],
    options: FfiTranscribeOptions,
) -> Result<Vec<FfiTranscribeSegment>, FfiAsrError> {
    let denoised;
    let input: &[f32] = if options.denoise {
        denoised = padnote_denoise::rnnoise_16k(pcm_16k_mono);
        &denoised
    } else {
        pcm_16k_mono
    };
    let segments = padnote_asr::transcribe_segmented(engine, input, options.prep())
        .map_err(|e| FfiAsrError::Backend(e.to_string()))?;
    Ok(segments
        .into_iter()
        .map(|s| FfiTranscribeSegment {
            text: s.text,
            start_ms: s.start_us / 1000,
            end_ms: s.end_us / 1000,
            confidence: s.confidence,
        })
        .collect())
}

#[cfg_attr(not(feature = "asr-whisper"), allow(dead_code))]
fn join_text(segs: &[FfiTranscribeSegment]) -> String {
    segs.iter()
        .map(|s| s.text.as_str())
        .collect::<Vec<_>>()
        .join(" ")
}

/// 用預設前處理轉錄（高通 + VAD 切段 + AGC，不降噪）。
#[uniffi::export]
pub fn whisper_transcribe_pcm(
    model_path: String,
    pcm_16k_mono: Vec<f32>,
    language: Option<String>,
) -> Result<FfiTranscribeResult, FfiAsrError> {
    whisper_transcribe_pcm_with(
        model_path,
        pcm_16k_mono,
        language,
        FfiTranscribeOptions::default(),
    )
}

/// 指定前處理的轉錄。「重新轉錄（降噪後再辨識）」走這裡，`options.denoise = true`。
#[uniffi::export]
pub fn whisper_transcribe_pcm_with(
    model_path: String,
    pcm_16k_mono: Vec<f32>,
    language: Option<String>,
    options: FfiTranscribeOptions,
) -> Result<FfiTranscribeResult, FfiAsrError> {
    if pcm_16k_mono.is_empty() {
        return Err(FfiAsrError::InvalidAudio("音訊資料長度為零".to_string()));
    }

    #[cfg(feature = "asr-whisper")]
    {
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
        // 切段後每段 ≤ 28 秒；區塊設成 30 秒，一段就是一次完整的辨識，
        // 不會再被引擎自己的 3 秒區塊從句子中間切開。
        engine.set_chunk_seconds(30.0);

        let ffi_segs = transcribe_with_engine(&mut engine, &pcm_16k_mono, options)?;
        Ok(FfiTranscribeResult {
            text: join_text(&ffi_segs),
            language: lang,
            segments: ffi_segs,
        })
    }

    #[cfg(not(feature = "asr-whisper"))]
    {
        let _ = model_path;
        let _ = language;
        let _ = options;
        Err(FfiAsrError::Backend(
            "此平台版本未啟用 Whisper 語音引擎".to_string(),
        ))
    }
}

#[cfg(test)]
mod prep_tests {
    use super::*;
    use padnote_asr::{AsrEngine, AsrError, AsrSegment};

    /// 假引擎：每次 `finish` 回一段「seg<N>」，時間戳相對所有已餵入取樣。
    #[derive(Debug, Default)]
    struct Fake {
        pending: usize,
        total: usize,
        calls: Vec<usize>,
    }

    impl AsrEngine for Fake {
        fn feed(&mut self, pcm: &[f32]) -> Result<Vec<AsrSegment>, AsrError> {
            self.pending += pcm.len();
            Ok(Vec::new())
        }
        fn finish(&mut self) -> Result<Vec<AsrSegment>, AsrError> {
            if self.pending == 0 {
                return Ok(Vec::new());
            }
            let start = self.total as u64 * 1_000_000 / 16_000;
            self.total += self.pending;
            self.calls.push(self.pending);
            self.pending = 0;
            Ok(vec![AsrSegment {
                text: format!("seg{}", self.calls.len()),
                start_us: start,
                end_us: self.total as u64 * 1_000_000 / 16_000,
                confidence: 0.9,
                is_final: true,
            }])
        }
        fn languages(&self) -> &[&str] {
            &["zh"]
        }
    }

    fn tone(secs: f32, amp: f32) -> Vec<f32> {
        (0..(16_000.0 * secs) as usize)
            .map(|i| {
                let t = i as f32 / 16_000.0;
                let env = 0.2 + 0.8 * (t * 4.0 * std::f32::consts::PI).sin().abs();
                (t * 200.0 * 2.0 * std::f32::consts::PI).sin() * amp * env
            })
            .collect()
    }

    #[test]
    fn defaults_are_hpf_agc_vad_without_denoise() {
        let o = default_transcribe_options();
        assert!(o.high_pass && o.agc && o.vad_segment);
        assert!(!o.denoise, "降噪未經 A/B 驗證，不可預設開啟");
    }

    #[test]
    fn silence_produces_no_text_instead_of_a_hallucination() {
        let pcm = vec![0.0_f32; 16_000 * 30];
        let mut engine = Fake::default();
        let segs =
            transcribe_with_engine(&mut engine, &pcm, FfiTranscribeOptions::default()).unwrap();
        assert!(segs.is_empty());
        assert!(engine.calls.is_empty(), "靜音被送進了 Whisper");
    }

    #[test]
    fn speech_is_sent_per_span_with_millisecond_timestamps_on_the_full_timeline() {
        let mut pcm = vec![0.0_f32; 16_000 * 10];
        pcm.extend(tone(3.0, 0.3)); // 10–13 s
        pcm.extend(vec![0.0_f32; 16_000 * 10]);
        let mut engine = Fake::default();
        let segs =
            transcribe_with_engine(&mut engine, &pcm, FfiTranscribeOptions::default()).unwrap();
        assert_eq!(segs.len(), 1);
        assert!(
            (9_600..=10_100).contains(&segs[0].start_ms),
            "{:?}",
            segs[0]
        );
        assert!((12_900..=13_400).contains(&segs[0].end_ms), "{:?}", segs[0]);
        assert_eq!(join_text(&segs), "seg1");
    }

    #[test]
    fn denoise_branch_runs_only_when_asked() {
        let mut pcm = vec![0.0_f32; 16_000 * 2];
        pcm.extend(tone(2.0, 0.3));
        pcm.extend(vec![0.0_f32; 16_000 * 2]);
        let mut a = Fake::default();
        let mut b = Fake::default();
        let off = transcribe_with_engine(&mut a, &pcm, FfiTranscribeOptions::default()).unwrap();
        let on = transcribe_with_engine(
            &mut b,
            &pcm,
            FfiTranscribeOptions {
                denoise: true,
                ..FfiTranscribeOptions::default()
            },
        )
        .unwrap();
        // 兩條路都要能產出結果（降噪不應把整段人聲吃掉）。
        assert_eq!(off.len(), 1);
        assert_eq!(on.len(), 1);
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
