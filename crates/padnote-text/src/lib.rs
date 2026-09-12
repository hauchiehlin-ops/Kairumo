//! 中文文字後處理：簡體轉繁體（台灣正體）。
//!
//! ## 為什麼需要這一層
//! Paraformer 與 ct-punc 都是**簡體中文**模型，輸出是簡體。對台灣使用者
//! 直接顯示簡體等於不能用。完整的中文管線是：
//!
//! ```text
//! Paraformer（簡體）→ ct-punc（簡體空間加標點）→ 本模組（轉繁體）
//! ```
//!
//! 順序不可調換 —— ct-punc 的詞表是簡體的，先轉繁體會產生大量 `<unk>`。
//!
//! ## ⚠️ 授權：必須關掉 zhconv 的預設 feature
//! `zhconv` 的 `Cargo.toml` 宣告 `license = "GPL-2.0-or-later"`，但那是因為
//! **預設綁了 MediaWiki 的轉換表**（GPL-2.0-or-later）。其 README 明確說明：
//!
//! > The library itself is licensed under MIT OR Apache-2.0 … BUT it may bundle
//! > conversion tables from MediaWiki … For MIT compatibility, disable the
//! > default `mediawiki` feature and enable `opencc`.
//!
//! 因此本專案用 `default-features = false, features = ["opencc"]`，
//! 綁的是 OpenCC 詞典（Apache-2.0）。
//! **直接 `cargo add zhconv` 會把 GPL 拉進來。**
//!
//! ## 已知限制
//! OpenCC 表在某些上下文會誤判（見 [`CORRECTIONS`]）。本模組以專案維護的
//! 修正表補救，每一條都有對應測試。這不是完整解法 —— 完整的 s2twp 需要
//! 原生 libopencc，列為待決策。

pub mod convert;

pub use convert::{CORRECTIONS, ChineseConverter, Script};
