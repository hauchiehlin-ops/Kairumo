//! 錄音編排（工作項 S-25）。
//!
//! 把 `padnote-audio`（Opus 編碼）、`padnote-asr`（VAD 分段與佇列）、
//! `AsrEngine`（轉錄）串成完整的錄音流程。
//!
//! ```text
//! 麥克風 PCM ─▶ feed()
//!                 │
//!                 ├─1─▶ Opus 編碼 ─▶ Ogg 檔（**同步、立即**）
//!                 │
//!                 └─2─▶ VAD 分段 ─▶ SegmentQueue（僅入列，不辨識）
//!                                        │
//!                                   背景 worker 取出 ─▶ AsrEngine
//! ```
//!
//! ## 為什麼拆成兩個型別
//! `RecordingPipeline` **完全不持有 `AsrEngine`**。這不是風格選擇 ——
//! 它讓「轉錄拖慢錄音」或「轉錄失敗導致丟音訊」在型別層次上就不可能發生。
//! 想在 `feed()` 裡呼叫模型？沒有那個欄位可以呼叫。
//!
//! 這正是 Notability 最大差評（轉錄失敗、15 分鐘音檔等 3 分鐘）的結構性解法。

pub mod pipeline;
pub mod worker;

pub use pipeline::PendingSegment;
pub use pipeline::{FeedOutcome, RecorderError, RecordingPipeline};
pub use worker::{TranscriptionWorker, WorkerOutcome};

/// 預設的語音活動偵測器。
///
/// ⚠️ 目前是能量門檻法，**在有背景噪音時會把冷氣聲當成語音**。
/// 正式版應換成 Silero VAD（模型已在 `models/manifest.json`，見 TODO S-26）。
pub fn default_vad() -> padnote_asr::EnergyVad {
    padnote_asr::EnergyVad { threshold: 0.02 }
}
pub mod mic;
