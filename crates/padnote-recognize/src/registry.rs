//! 引擎註冊表與 fallback 鏈（功能 D1、決策 D2）。
//!
//! 手寫辨識是**可選增強**，不是核心依賴。即使所有引擎都不可用，
//! 手寫／打字／錄音轉文字三大需求仍然成立 —— 這是對 `architecture.md`
//! 缺口 #1（開源中文 HWR 不存在）的風險隔離。

use crate::{Candidate, HwrBackend, HwrEngine, HwrError, RecognitionStroke};

/// 引擎目前是否可用。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum Availability {
    Ready,
    /// 系統框架存在但使用者尚未授予權限。
    NeedsPermission,
    /// 需要先下載語言模型（ML Kit 依語言下載）。
    NeedsDownload {
        size_bytes: u64,
    },
    /// 此平台沒有這個後端。
    Unsupported,
}

impl Availability {
    pub fn is_usable(&self) -> bool {
        matches!(self, Self::Ready)
    }

    /// 使用者能否透過一個動作讓它變成可用 —— 「引擎與權限中心」據此顯示按鈕。
    pub fn is_actionable(&self) -> bool {
        matches!(self, Self::NeedsPermission | Self::NeedsDownload { .. })
    }
}

/// 已註冊的一個引擎。
pub struct RegisteredEngine {
    pub backend: HwrBackend,
    pub availability: Availability,
    engine: Option<Box<dyn HwrEngine>>,
}

impl std::fmt::Debug for RegisteredEngine {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("RegisteredEngine")
            .field("backend", &self.backend)
            .field("availability", &self.availability)
            .field("loaded", &self.engine.is_some())
            .finish()
    }
}

impl RegisteredEngine {
    pub fn new(
        backend: HwrBackend,
        availability: Availability,
        engine: Option<Box<dyn HwrEngine>>,
    ) -> Self {
        Self {
            backend,
            availability,
            engine,
        }
    }

    /// 不可用的後端不該被登記為可用 —— 這個檢查避免 fallback 鏈選到空殼。
    fn usable(&self) -> bool {
        self.availability.is_usable() && self.engine.is_some()
    }
}

/// 依優先序排列的引擎鏈。
#[derive(Debug, Default)]
pub struct HwrRegistry {
    engines: Vec<RegisteredEngine>,
}

impl HwrRegistry {
    pub fn new() -> Self {
        Self::default()
    }

    /// 依平台預設順序註冊。先註冊的優先。
    pub fn register(&mut self, engine: RegisteredEngine) {
        self.engines.push(engine);
    }

    pub fn engines(&self) -> &[RegisteredEngine] {
        &self.engines
    }

    /// 目前會被使用的後端。全部不可用時回傳 `None`。
    pub fn active_backend(&self, lang: &str) -> Option<HwrBackend> {
        self.engines
            .iter()
            .find(|e| e.usable() && supports(e, lang))
            .map(|e| e.backend)
    }

    /// 依序嘗試每個可用引擎，直到有一個成功。
    ///
    /// 失敗就往下一個試，而不是整個放棄 —— 例如 Apple Vision 對某些語言
    /// 回報不支援時，還有開源的 OCR fallback 可用。
    pub fn recognize(
        &self,
        strokes: &[RecognitionStroke],
        lang: &str,
    ) -> Result<Vec<Candidate>, HwrError> {
        let mut last_error = None;

        for reg in self.engines.iter().filter(|e| e.usable()) {
            let Some(engine) = &reg.engine else { continue };
            if !supports(reg, lang) {
                continue;
            }
            match engine.recognize(strokes, lang) {
                Ok(c) if !c.is_empty() => return Ok(c),
                // 空結果視同失敗，繼續往下試
                Ok(_) => last_error = Some(HwrError::Backend("無候選結果".into())),
                Err(e) => last_error = Some(e),
            }
        }

        Err(last_error.unwrap_or(HwrError::UnsupportedLanguage(lang.to_string())))
    }

    /// 是否有任何引擎可用。UI 據此決定要不要顯示「手寫轉文字」按鈕。
    pub fn any_available(&self) -> bool {
        self.engines.iter().any(RegisteredEngine::usable)
    }

    /// 需要使用者處理的引擎（權限或下載）。
    pub fn actionable(&self) -> Vec<&RegisteredEngine> {
        self.engines
            .iter()
            .filter(|e| e.availability.is_actionable())
            .collect()
    }
}

fn supports(reg: &RegisteredEngine, lang: &str) -> bool {
    reg.engine
        .as_ref()
        .is_some_and(|e| e.languages().contains(&lang))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[derive(Debug)]
    struct FakeEngine {
        langs: Vec<&'static str>,
        result: Result<Vec<Candidate>, &'static str>,
    }

    impl HwrEngine for FakeEngine {
        fn recognize(&self, _: &[RecognitionStroke], _: &str) -> Result<Vec<Candidate>, HwrError> {
            self.result
                .clone()
                .map_err(|e| HwrError::Backend(e.to_string()))
        }
        fn supports_streaming(&self) -> bool {
            false
        }
        fn languages(&self) -> &[&str] {
            &self.langs
        }
    }

    fn ok_engine(text: &str, langs: Vec<&'static str>) -> Box<dyn HwrEngine> {
        Box::new(FakeEngine {
            langs,
            result: Ok(vec![Candidate {
                text: text.into(),
                confidence: 0.9,
            }]),
        })
    }

    fn failing_engine(langs: Vec<&'static str>) -> Box<dyn HwrEngine> {
        Box::new(FakeEngine {
            langs,
            result: Err("後端壞了"),
        })
    }

    fn strokes() -> Vec<RecognitionStroke> {
        vec![RecognitionStroke {
            points: vec![(0.0, 0.0), (10.0, 10.0)],
            started_at_us: 0,
        }]
    }

    #[test]
    fn first_usable_engine_wins() {
        let mut r = HwrRegistry::new();
        r.register(RegisteredEngine::new(
            HwrBackend::AppleVision,
            Availability::Ready,
            Some(ok_engine("主要引擎", vec!["zh-Hant"])),
        ));
        r.register(RegisteredEngine::new(
            HwrBackend::OcrFallback,
            Availability::Ready,
            Some(ok_engine("備援引擎", vec!["zh-Hant"])),
        ));

        assert_eq!(
            r.recognize(&strokes(), "zh-Hant").unwrap()[0].text,
            "主要引擎"
        );
        assert_eq!(r.active_backend("zh-Hant"), Some(HwrBackend::AppleVision));
    }

    #[test]
    fn falls_through_when_primary_errors() {
        // 主要引擎壞掉不該讓整個功能消失 —— 還有開源備援可用。
        let mut r = HwrRegistry::new();
        r.register(RegisteredEngine::new(
            HwrBackend::AppleVision,
            Availability::Ready,
            Some(failing_engine(vec!["zh-Hant"])),
        ));
        r.register(RegisteredEngine::new(
            HwrBackend::OcrFallback,
            Availability::Ready,
            Some(ok_engine("備援結果", vec!["zh-Hant"])),
        ));

        assert_eq!(
            r.recognize(&strokes(), "zh-Hant").unwrap()[0].text,
            "備援結果"
        );
    }

    #[test]
    fn empty_result_is_treated_as_failure_and_falls_through() {
        let mut r = HwrRegistry::new();
        r.register(RegisteredEngine::new(
            HwrBackend::AppleVision,
            Availability::Ready,
            Some(Box::new(FakeEngine {
                langs: vec!["zh-Hant"],
                result: Ok(vec![]),
            })),
        ));
        r.register(RegisteredEngine::new(
            HwrBackend::OcrFallback,
            Availability::Ready,
            Some(ok_engine("備援", vec!["zh-Hant"])),
        ));

        assert_eq!(r.recognize(&strokes(), "zh-Hant").unwrap()[0].text, "備援");
    }

    #[test]
    fn skips_engines_that_do_not_support_the_language() {
        let mut r = HwrRegistry::new();
        r.register(RegisteredEngine::new(
            HwrBackend::AppleVision,
            Availability::Ready,
            Some(ok_engine("英文引擎", vec!["en-US"])),
        ));
        r.register(RegisteredEngine::new(
            HwrBackend::OcrFallback,
            Availability::Ready,
            Some(ok_engine("中文引擎", vec!["zh-Hant"])),
        ));

        assert_eq!(
            r.recognize(&strokes(), "zh-Hant").unwrap()[0].text,
            "中文引擎"
        );
        assert_eq!(r.active_backend("en-US"), Some(HwrBackend::AppleVision));
    }

    #[test]
    fn unavailable_engines_are_never_selected() {
        // 註冊了但沒授權的引擎不該被 fallback 鏈選中。
        let mut r = HwrRegistry::new();
        r.register(RegisteredEngine::new(
            HwrBackend::AppleVision,
            Availability::NeedsPermission,
            Some(ok_engine("不該被用到", vec!["zh-Hant"])),
        ));
        r.register(RegisteredEngine::new(
            HwrBackend::OcrFallback,
            Availability::Ready,
            Some(ok_engine("應該用這個", vec!["zh-Hant"])),
        ));

        assert_eq!(
            r.recognize(&strokes(), "zh-Hant").unwrap()[0].text,
            "應該用這個"
        );
    }

    #[test]
    fn registry_without_any_usable_engine_reports_it_clearly() {
        // 三大核心需求不受影響，但 UI 需要知道要隱藏「轉文字」按鈕。
        let mut r = HwrRegistry::new();
        r.register(RegisteredEngine::new(
            HwrBackend::MlKitInk,
            Availability::Unsupported,
            None,
        ));

        assert!(!r.any_available());
        assert!(r.active_backend("zh-Hant").is_none());
        assert!(r.recognize(&strokes(), "zh-Hant").is_err());
    }

    #[test]
    fn actionable_engines_are_surfaced_for_the_permission_center() {
        let mut r = HwrRegistry::new();
        r.register(RegisteredEngine::new(
            HwrBackend::AppleVision,
            Availability::NeedsPermission,
            None,
        ));
        r.register(RegisteredEngine::new(
            HwrBackend::MlKitInk,
            Availability::NeedsDownload {
                size_bytes: 5_000_000,
            },
            None,
        ));
        r.register(RegisteredEngine::new(
            HwrBackend::SelfHosted,
            Availability::Unsupported,
            None,
        ));

        let actionable = r.actionable();
        assert_eq!(actionable.len(), 2, "Unsupported 不該出現在可行動清單");
    }

    #[test]
    fn availability_classification() {
        assert!(Availability::Ready.is_usable());
        assert!(!Availability::Ready.is_actionable());
        assert!(Availability::NeedsPermission.is_actionable());
        assert!(Availability::NeedsDownload { size_bytes: 1 }.is_actionable());
        assert!(!Availability::Unsupported.is_actionable());
    }
}
