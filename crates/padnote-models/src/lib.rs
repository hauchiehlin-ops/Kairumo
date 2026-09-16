//! 模型按需下載（決策 D4、功能 I2）。
//!
//! Whisper-turbo ~800MB、Qwen3-4B ~2.5GB，塞不進 App Bundle。託管在
//! Hugging Face / GitHub Releases 這類**靜態空間**，維持「零後端」。
//!
//! 三個不可妥協的性質：
//! 1. **SHA-256 驗證** —— 下錯或被中間人替換的模型不得載入
//! 2. **斷點續傳** —— 2.5GB 在行動網路下必然會中斷
//! 3. **可刪除** —— 使用者要能釋放空間（I2）

/// 預設的語音辨識模型（決策 D-07）。
///
/// # 為什麼是 Whisper 而不是 Paraformer + ct-punc
///
/// 三個理由，按重要性排：
///
/// 1. **授權乾淨。** Whisper 的權重是 MIT，只有一條通路。Paraformer 與
///    ct-punc 的權重同時經由 HuggingFace（Apache-2.0）與 FunASR GitHub 的
///    `MODEL_LICENSE v1.1`（「僅供參考與學習」、含授權自動終止條款）散布，
///    兩者條款互相衝突 —— 而 ct-punc 那一邊**連 repo 內的授權原文都沒有**，
///    只有 model card 上的一個標籤。詳見 `models/LICENSE-AUDIT.md`。
/// 2. **Whisper 自己就會標點**，所以 ct-punc 整個不需要了 —— 293 MB 的下載
///    與那條授權最弱的鏈一起消失。中文轉錄沒有標點等於沒用（功能 C5 是 P0），
///    用一個會標點的模型解決，比用兩個模型接起來穩。
/// 3. **一個模型覆蓋六個語系。** Paraformer 只做中文；介面有六種語言，
///    另外五種原本就得回頭找 Whisper。
///
/// 代價說清楚：Paraformer 是串流模型，Whisper 不是。但目前的整合**本來就是
/// 段級**（VAD 段，上限 5 秒，見 S-32），所以今天並沒有真的失去串流。
///
/// Paraformer 沒有被移除 —— 它那一邊的授權證據是這一對裡最強的
/// （repo 內含 Apache-2.0 全文），仍可由使用者自行選用。
pub const DEFAULT_ASR_MODEL: &str = "whisper-large-v3-turbo-q5";

/// 預設的摘要模型。
pub const DEFAULT_LLM_MODEL: &str = "qwen3-4b-instruct-q4";

pub mod catalog;
pub mod download;
pub mod provenance;

pub use catalog::{ModelCatalog, ModelEntry};
pub use download::{DownloadError, DownloadState, Downloader, Fetcher, RangeRequest};
pub use provenance::{LicenseEvidence, Provenance, ProvenanceError};
