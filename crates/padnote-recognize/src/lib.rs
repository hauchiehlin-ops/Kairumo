//! 辨識引擎：手寫辨識（HWR）與 OCR。
//!
//! **架構決策 D2**：接受 Apple Vision / ML Kit 等免費非開源系統 API 作為例外。
//! 兩者皆為純裝置端、免費、**免申請 API key**，僅需權限授予。
//!
//! HWR 被刻意隔離為「可選增強」：即使完全不可用，手寫／打字／錄音轉文字
//! 三大核心需求仍然成立。這是對 `architecture.md` 缺口 #1 的風險隔離。

pub mod registry;

pub use registry::{Availability, HwrRegistry, RegisteredEngine};

use std::fmt::Debug;

/// 手寫辨識引擎。實作依平台選擇，見 `HwrBackend`。
pub trait HwrEngine: Send + Sync + Debug {
    /// 輸入筆畫的取樣點序列，回傳候選文字（信心由高到低）。
    fn recognize(
        &self,
        strokes: &[RecognitionStroke],
        lang: &str,
    ) -> Result<Vec<Candidate>, HwrError>;

    /// 是否支援邊寫邊出候選（D2：即時轉寫並可當下修正）。
    fn supports_streaming(&self) -> bool;

    fn languages(&self) -> &[&str];
}

/// 供辨識用的精簡筆畫表示（不含壓感/傾斜，辨識模型通常不需要）。
#[derive(Clone, Debug)]
pub struct RecognitionStroke {
    pub points: Vec<(f32, f32)>,
    pub started_at_us: u64,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Candidate {
    pub text: String,
    pub confidence: f32,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum HwrBackend {
    /// Apple Vision —— Phase 1 (iPadOS/macOS) 預設。免費、免 key、離線。
    AppleVision,
    /// ML Kit Digital Ink —— Phase 2 (Android) 預設。免費、免 key、離線。
    MlKitInk,
    /// 筆畫轉圖 → PP-OCRv5。品質較差但 100% 開源，全平台可用的底線方案。
    OcrFallback,
    /// 自訓開源模型（P3，見 architecture.md 缺口 #1）。
    SelfHosted,
}

impl HwrBackend {
    /// 是否為開源實作。`false` 者屬於 D2 明示接受的例外。
    pub fn is_open_source(self) -> bool {
        matches!(self, Self::OcrFallback | Self::SelfHosted)
    }

    /// 是否需要使用者申請 API key。
    ///
    /// **全部為 `false`** —— Apple Vision 與 ML Kit Digital Ink 皆為純裝置端
    /// 系統框架，不需註冊或金鑰。「引擎與權限中心」(I1) 只需引導權限授予。
    pub fn requires_api_key(self) -> bool {
        false
    }

    /// 各平台的預設後端。
    pub fn default_for_platform() -> Self {
        if cfg!(target_vendor = "apple") {
            Self::AppleVision
        } else if cfg!(target_os = "android") {
            Self::MlKitInk
        } else {
            Self::OcrFallback
        }
    }
}

#[derive(Debug)]
pub enum HwrError {
    BackendUnavailable(HwrBackend),
    UnsupportedLanguage(String),
    Backend(String),
}

impl std::fmt::Display for HwrError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::BackendUnavailable(b) => write!(f, "辨識後端不可用：{b:?}"),
            Self::UnsupportedLanguage(l) => write!(f, "不支援的語言：{l}"),
            Self::Backend(m) => write!(f, "後端錯誤：{m}"),
        }
    }
}

impl std::error::Error for HwrError {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn no_hwr_backend_requires_an_api_key() {
        // 對應 D2 的更正：系統 API 免申請、免 key。
        for b in [
            HwrBackend::AppleVision,
            HwrBackend::MlKitInk,
            HwrBackend::OcrFallback,
            HwrBackend::SelfHosted,
        ] {
            assert!(!b.requires_api_key(), "{b:?} 不應需要 API key");
        }
    }

    #[test]
    fn system_backends_are_the_declared_non_open_source_exception() {
        assert!(!HwrBackend::AppleVision.is_open_source());
        assert!(!HwrBackend::MlKitInk.is_open_source());
        assert!(HwrBackend::OcrFallback.is_open_source());
    }

    #[test]
    fn apple_targets_default_to_vision() {
        if cfg!(target_vendor = "apple") {
            assert_eq!(HwrBackend::default_for_platform(), HwrBackend::AppleVision);
        }
    }
}
