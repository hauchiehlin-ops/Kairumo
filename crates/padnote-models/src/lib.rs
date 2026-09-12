//! 模型按需下載（決策 D4、功能 I2）。
//!
//! Whisper-turbo ~800MB、Qwen3-4B ~2.5GB，塞不進 App Bundle。託管在
//! Hugging Face / GitHub Releases 這類**靜態空間**，維持「零後端」。
//!
//! 三個不可妥協的性質：
//! 1. **SHA-256 驗證** —— 下錯或被中間人替換的模型不得載入
//! 2. **斷點續傳** —— 2.5GB 在行動網路下必然會中斷
//! 3. **可刪除** —— 使用者要能釋放空間（I2）

pub mod catalog;
pub mod download;

pub use catalog::{ModelCatalog, ModelEntry};
pub use download::{DownloadError, DownloadState, Downloader, Fetcher, RangeRequest};
