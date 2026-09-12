//! 信封加密與金鑰管理（`docs/format-spec.md` §3、§7.1）。
//!
//! 方案：Argon2id(m=64MiB, t=3) 匯出 KEK → 包裹隨機 DEK；
//! chunk 以 XChaCha20-Poly1305 加密。復原碼為 BIP39 24 字。
//!
//! TODO(M3/WP21)。
