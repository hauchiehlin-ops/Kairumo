//! Paraformer 串流 ASR（工作項 S-24）。
//!
//! 模型依 ADR-0006 自行從 `funasr/paraformer-zh-streaming` 匯出。
//! 該 repo 是三個 funasr repo 中**唯一內含完整 Apache-2.0 授權原文**的，
//! 而串流正是功能 C2（邊錄邊出字）需要的形態。
//!
//! ```text
//! PCM ─▶ fbank(80) ─▶ LFR(560) ─▶ CMVN ─▶ encoder ─▶ CIF ─▶ decoder ─▶ tokens
//! ```
//!
//! 各層的職責與驗證方式：
//!
//! | 層 | 模組 | 驗證 |
//! |---|---|---|
//! | 特徵 | [`frontend`] | 與 FunASR 的參考特徵逐點比對 |
//! | 切字 | [`cif`] | 純數學，完整單元測試 |
//! | 推論 | [`engine`] | 需模型檔，缺檔時跳過 |
//! | 整體 | `tests/reference_audio.rs` | 與 FunASR 的 Python 輸出比對 |
//!
//! ## ⚠️ int8 量化會降低中文辨識品質
//!
//! 用 FunASR 官方範例音檔（5.5 秒）比對：
//!
//! ```text
//! FunASR (fp32 PyTorch): 欢迎大家来体验达摩院推出的语音识别模型这ca
//! 本實作 (fp32 ONNX)   : 欢迎大家来体验达摩院推出的语音识别模型
//! 本實作 (int8 ONNX)   : 欢迎大家来体验达摩院推出的语音识别识别模型cia
//! ```
//!
//! **fp32 與參考輸出完全吻合**，證明整條管線正確；int8 則出現重複字
//! （「识别识别」）與結尾雜訊。進一步測試排除嵌入表（只量化 MatMul）
//! 得到**相同的劣化**，且體積幾乎不變（157.4 vs 157.6 MB）——
//! 問題出在量化 transformer 權重本身。
//!
//! | 版本 | 體積 | 品質 |
//! |---|---|---|
//! | fp32 | 825 MB | 與參考吻合 |
//! | int8 | 213 MB | 明顯劣化 |
//!
//! ⚠️ **這是 n=1 的觀察，不是測量。** 單一 5.5 秒樣本不足以下定論，
//! 真正的取捨必須用 `padnote-bench` 的中文測試集（TODO H2）量化後再決定。
//! `ModelPaths::in_dir` 兩種都支援：有 int8 就用 int8，沒有就退回 fp32。

pub mod cif;
pub mod engine;
pub mod frontend;

pub use cif::{CifOutput, cif};
pub use engine::{ParaformerEngine, ParaformerError};
pub use frontend::{Cmvn, FbankExtractor, apply_lfr};
