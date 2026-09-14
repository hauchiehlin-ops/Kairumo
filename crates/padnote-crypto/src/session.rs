//! 即時協同的訊息加密（工作包 WP3）。
//!
//! # 為什麼不是用 `envelope` 那套
//!
//! `envelope` 保護的是**落盤的同步檔案**：XChaCha20-Poly1305 + Argon2id 包裝 DEK，
//! 為長期儲存設計。協同訊息是另一回事 —— 短命、高頻、金鑰放在邀請連結裡。
//!
//! # 為什麼是 AES-256-GCM，而且是這個位元組佈局
//!
//! Apple 版已經上線並穩定運作，它用 CryptoKit 的 `AES.GCM.seal(...).combined`：
//!
//! ```text
//! combined = nonce(12 bytes) || ciphertext || tag(16 bytes)
//! ```
//!
//! Android 要能跟已經在使用者手上的 iOS 版互通，就必須產出**逐位元組相同**的
//! 格式。所以這裡在核心裡實作同一套，讓新平台走核心、Apple 端維持不動 ——
//! 互通性由 `tests/cryptokit_interop.rs` 的跨語言測試把關。

use aes_gcm::aead::{Aead, KeyInit, Payload};
use aes_gcm::{Aes256Gcm, Key, Nonce};
use base64::Engine as _;
use base64::engine::general_purpose::STANDARD as BASE64;

/// CryptoKit 的 `AES.GCM.Nonce` 預設長度
const NONCE_LEN: usize = 12;
/// GCM 標籤長度
const TAG_LEN: usize = 16;

/// 協同房間金鑰（256 位元）。
///
/// 邀請連結裡帶的就是這把金鑰的 base64；中繼點看不到它，
/// 所以中繼只轉發它讀不懂的密文。
#[derive(Clone)]
pub struct SessionKey([u8; 32]);

impl SessionKey {
    /// 產生新的房間金鑰
    pub fn generate() -> Result<Self, SessionCryptoError> {
        let mut bytes = [0u8; 32];
        getrandom::getrandom(&mut bytes).map_err(|_| SessionCryptoError::Random)?;
        Ok(Self(bytes))
    }

    pub fn from_bytes(bytes: [u8; 32]) -> Self {
        Self(bytes)
    }

    /// 從邀請連結裡的 base64 還原
    pub fn from_base64(encoded: &str) -> Result<Self, SessionCryptoError> {
        let raw = BASE64
            .decode(encoded.trim())
            .map_err(|_| SessionCryptoError::InvalidKey)?;
        let bytes: [u8; 32] = raw.try_into().map_err(|_| SessionCryptoError::InvalidKey)?;
        Ok(Self(bytes))
    }

    pub fn to_base64(&self) -> String {
        BASE64.encode(self.0)
    }

    pub fn as_bytes(&self) -> &[u8; 32] {
        &self.0
    }

    /// 加密一段訊息，回傳 CryptoKit `combined` 佈局的位元組。
    pub fn seal(&self, plaintext: &[u8]) -> Result<Vec<u8>, SessionCryptoError> {
        let cipher = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(&self.0));
        let mut nonce_bytes = [0u8; NONCE_LEN];
        getrandom::getrandom(&mut nonce_bytes).map_err(|_| SessionCryptoError::Random)?;
        let nonce = Nonce::from_slice(&nonce_bytes);

        let ciphertext = cipher
            .encrypt(
                nonce,
                Payload {
                    msg: plaintext,
                    aad: &[],
                },
            )
            .map_err(|_| SessionCryptoError::Seal)?;

        // nonce 在前，其餘照 AEAD 的輸出（密文 || 標籤）
        let mut combined = Vec::with_capacity(NONCE_LEN + ciphertext.len());
        combined.extend_from_slice(&nonce_bytes);
        combined.extend_from_slice(&ciphertext);
        Ok(combined)
    }

    /// 解開 CryptoKit `combined` 佈局的位元組。
    pub fn open(&self, combined: &[u8]) -> Result<Vec<u8>, SessionCryptoError> {
        if combined.len() < NONCE_LEN + TAG_LEN {
            return Err(SessionCryptoError::Malformed);
        }
        let (nonce_bytes, body) = combined.split_at(NONCE_LEN);
        let cipher = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(&self.0));
        cipher
            .decrypt(
                Nonce::from_slice(nonce_bytes),
                Payload {
                    msg: body,
                    aad: &[],
                },
            )
            .map_err(|_| SessionCryptoError::Open)
    }

    /// 便利函式：加密後直接給 base64（協同協定裡就是這樣傳的）
    pub fn seal_to_base64(&self, plaintext: &[u8]) -> Result<String, SessionCryptoError> {
        Ok(BASE64.encode(self.seal(plaintext)?))
    }

    /// 便利函式：解開 base64 密文
    pub fn open_from_base64(&self, encoded: &str) -> Result<Vec<u8>, SessionCryptoError> {
        let raw = BASE64
            .decode(encoded.trim())
            .map_err(|_| SessionCryptoError::Malformed)?;
        self.open(&raw)
    }
}

impl std::fmt::Debug for SessionKey {
    /// 金鑰不進日誌。
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("SessionKey(<redacted>)")
    }
}

#[derive(Debug, PartialEq, Eq)]
pub enum SessionCryptoError {
    /// 房間金鑰格式錯誤（需要 base64 的 32 位元組）
    InvalidKey,
    /// 密文長度不足，不可能是有效的訊息
    Malformed,
    /// 加密失敗
    Seal,
    /// 解密失敗（金鑰不符或內容被竄改）
    Open,
    /// 取不到亂數
    Random,
}

impl std::fmt::Display for SessionCryptoError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let msg = match self {
            Self::InvalidKey => "房間金鑰格式錯誤（需要 base64 的 32 位元組）",
            Self::Malformed => "密文長度不足，不可能是有效的訊息",
            Self::Seal => "加密失敗",
            Self::Open => "解密失敗（金鑰不符或內容被竄改）",
            Self::Random => "取不到亂數",
        };
        f.write_str(msg)
    }
}

impl std::error::Error for SessionCryptoError {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trip() {
        let key = SessionKey::generate().unwrap();
        let sealed = key.seal(b"hello collab").unwrap();
        assert_eq!(key.open(&sealed).unwrap(), b"hello collab");
    }

    #[test]
    fn layout_matches_cryptokit_combined() {
        // nonce(12) || ciphertext(len) || tag(16)
        let key = SessionKey::generate().unwrap();
        let plaintext = b"12345";
        let sealed = key.seal(plaintext).unwrap();
        assert_eq!(sealed.len(), NONCE_LEN + plaintext.len() + TAG_LEN);
    }

    #[test]
    fn wrong_key_fails_instead_of_returning_garbage() {
        let sealed = SessionKey::generate().unwrap().seal(b"secret").unwrap();
        let other = SessionKey::generate().unwrap();
        assert_eq!(other.open(&sealed), Err(SessionCryptoError::Open));
    }

    #[test]
    fn truncated_ciphertext_is_rejected() {
        let key = SessionKey::generate().unwrap();
        let sealed = key.seal(b"secret").unwrap();
        assert_eq!(
            key.open(&sealed[..NONCE_LEN + 2]),
            Err(SessionCryptoError::Malformed)
        );
    }

    #[test]
    fn base64_key_round_trip() {
        let key = SessionKey::generate().unwrap();
        let restored = SessionKey::from_base64(&key.to_base64()).unwrap();
        assert_eq!(restored.as_bytes(), key.as_bytes());
    }

    #[test]
    fn debug_does_not_leak_key() {
        let key = SessionKey::generate().unwrap();
        assert_eq!(format!("{key:?}"), "SessionKey(<redacted>)");
    }
}
