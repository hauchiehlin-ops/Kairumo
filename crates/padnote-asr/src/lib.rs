//! 語音管線：Opus 錄製 → VAD → 串流 ASR → 標點還原 → 繁體轉換。
//! 架構：`docs/architecture.md` §6。
//!
//! **不可妥協的原則**（來自 Notability 的失敗教訓）：
//! 1. 音檔永遠先落地；轉錄是衍生物，失敗可無限重試，絕不因此丟音訊。
//! 2. 轉錄任務可中斷、可續傳，狀態存 SQLite。
//! 3. ASR 執行緒優先權必須低於 UI/墨跡執行緒 —— 寧可轉錄慢，不可寫字卡。

pub mod pipeline;

pub use pipeline::{
    EnergyVad, RingBuffer, Segment, SegmentQueue, Segmenter, VoiceActivityDetector,
};

use std::fmt::Debug;

/// 串流 ASR 引擎。實作可為 Paraformer-zh、SenseVoice、Whisper-turbo。
///
/// 設計為可插拔：M0/S2 的 CER 實測結果決定預設引擎，`cargo` feature 切換。
pub trait AsrEngine: Send + Sync + Debug {
    /// 餵入 16kHz 單聲道 f32 PCM。回傳本次產生的結果（可能為空）。
    fn feed(&mut self, pcm_16k_mono: &[f32]) -> Result<Vec<AsrSegment>, AsrError>;

    /// 音訊結束，沖出殘餘緩衝。
    fn finish(&mut self) -> Result<Vec<AsrSegment>, AsrError>;

    fn languages(&self) -> &[&str];
}

/// 一段辨識結果。`is_final=false` 為部分結果，UI 以灰字顯示。
#[derive(Clone, Debug)]
pub struct AsrSegment {
    pub text: String,
    /// 相對本次 ASR session 起點的微秒偏移；呼叫端負責換算到筆記本時間軸。
    pub start_us: u64,
    pub end_us: u64,
    pub confidence: f32,
    pub is_final: bool,
}

#[derive(Debug)]
pub enum AsrError {
    ModelNotLoaded,
    UnsupportedLanguage(String),
    Backend(String),
}

impl std::fmt::Display for AsrError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::ModelNotLoaded => write!(f, "模型尚未下載或載入"),
            Self::UnsupportedLanguage(l) => write!(f, "不支援的語言：{l}"),
            Self::Backend(m) => write!(f, "後端錯誤：{m}"),
        }
    }
}

impl std::error::Error for AsrError {}

/// 轉錄任務狀態。持久化於 SQLite，使 App 被殺或當機後能續跑。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum TranscriptionState {
    Pending,
    /// 已處理到音檔的此偏移（微秒）—— 續傳的斷點。
    InProgress {
        processed_us: u64,
    },
    Done,
    /// 失敗可重試；音檔始終保留。
    Failed {
        attempts: u32,
    },
}

impl TranscriptionState {
    /// 是否應排入工作佇列。失敗超過 5 次改為人工觸發，避免無限耗電。
    pub fn is_resumable(self) -> bool {
        match self {
            Self::Pending | Self::InProgress { .. } => true,
            Self::Failed { attempts } => attempts < 5,
            Self::Done => false,
        }
    }

    pub fn resume_offset_us(self) -> u64 {
        match self {
            Self::InProgress { processed_us } => processed_us,
            _ => 0,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn failed_tasks_retry_until_cap() {
        assert!(TranscriptionState::Failed { attempts: 4 }.is_resumable());
        assert!(!TranscriptionState::Failed { attempts: 5 }.is_resumable());
    }

    #[test]
    fn in_progress_resumes_from_checkpoint() {
        let s = TranscriptionState::InProgress {
            processed_us: 42_000_000,
        };
        assert!(s.is_resumable());
        assert_eq!(s.resume_offset_us(), 42_000_000);
    }

    #[test]
    fn done_is_not_requeued() {
        assert!(!TranscriptionState::Done.is_resumable());
    }
}
