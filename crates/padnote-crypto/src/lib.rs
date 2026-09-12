//! 端對端加密（功能 G6–G8、`format-spec.md` §3、§7.1）。
//!
//! 資料會放進**使用者自己的 Google Drive / iCloud**。雲端供應商、同步工具、
//! 任何拿到檔案的人都不該讀得懂內容 —— 這不是加分項，是把資料交出去的前提。
//!
//! ## 信封加密
//! ```text
//! 使用者密語 ──Argon2id(m=64MiB,t=3)──▶ KEK ──包裹──▶ DEK（隨機 256-bit）
//!                                                      │
//!                                  每個 chunk：XChaCha20-Poly1305(DEK, 隨機 nonce)
//! ```
//! 用信封而非直接以密語加密內容，換密語時只要重新包裹 DEK，
//! **不必重新加密整本筆記**。
//!
//! ## ⚠️ 無後端 = 無金鑰託管
//! 忘記密語且遺失復原碼 ⇒ **資料永久無法還原**。這是 D5 的必然後果，
//! 因此 `recovery` 模組強制在建立時產生復原碼。

pub mod envelope;
pub mod recovery;

pub use envelope::{CryptoError, Dek, Envelope, KdfParams};
pub use recovery::{RecoveryCode, RecoveryError};
