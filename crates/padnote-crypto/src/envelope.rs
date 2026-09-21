//! 信封加密實作。

use argon2::{Algorithm, Argon2, Params, Version};
use base64::Engine;
use base64::engine::general_purpose::STANDARD as B64;
use chacha20poly1305::aead::{Aead, KeyInit, Payload};
use chacha20poly1305::{XChaCha20Poly1305, XNonce};
use std::fmt;

/// XChaCha20-Poly1305 的 nonce 長度。
pub const NONCE_LEN: usize = 24;
/// Poly1305 認證標籤長度。
pub const TAG_LEN: usize = 16;

/// 資料加密金鑰。**絕不序列化明文** —— 只以被 KEK 包裹的形式落盤。
#[derive(Clone)]
pub struct Dek([u8; 32]);

impl Dek {
    pub fn generate() -> Result<Self, CryptoError> {
        let mut key = [0u8; 32];
        getrandom::getrandom(&mut key).map_err(|e| CryptoError::Random(e.to_string()))?;
        Ok(Self(key))
    }

    pub fn from_bytes(b: [u8; 32]) -> Self {
        Self(b)
    }

    fn cipher(&self) -> XChaCha20Poly1305 {
        XChaCha20Poly1305::new((&self.0).into())
    }
}

// 避免金鑰在 log、panic 訊息、除錯輸出裡外洩。
impl fmt::Debug for Dek {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("Dek(<redacted>)")
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct KdfParams {
    pub m_cost_kib: u32,
    pub t_cost: u32,
    pub p_cost: u32,
    pub salt: Vec<u8>,
}

impl KdfParams {
    /// format-spec §3 的預設值。64MiB 記憶體成本讓 GPU 暴力破解代價高昂。
    pub fn recommended() -> Result<Self, CryptoError> {
        let mut salt = vec![0u8; 16];
        getrandom::getrandom(&mut salt).map_err(|e| CryptoError::Random(e.to_string()))?;
        Ok(Self {
            m_cost_kib: 65_536,
            t_cost: 3,
            p_cost: 1,
            salt,
        })
    }

    fn derive_kek(&self, passphrase: &str) -> Result<[u8; 32], CryptoError> {
        let params = Params::new(self.m_cost_kib, self.t_cost, self.p_cost, Some(32))
            .map_err(|e| CryptoError::Kdf(e.to_string()))?;
        let argon = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);

        let mut kek = [0u8; 32];
        argon
            .hash_password_into(passphrase.as_bytes(), &self.salt, &mut kek)
            .map_err(|e| CryptoError::Kdf(e.to_string()))?;
        Ok(kek)
    }
}

#[derive(Debug)]
pub enum CryptoError {
    /// 密語錯誤，或密文/標籤被竄改。**兩者刻意不區分** —— 區分會洩漏資訊。
    DecryptionFailed,
    Kdf(String),
    Random(String),
    Malformed(String),
}

impl fmt::Display for CryptoError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::DecryptionFailed => write!(f, "解密失敗：密語錯誤或資料已被竄改"),
            Self::Kdf(m) => write!(f, "金鑰匯出失敗：{m}"),
            Self::Random(m) => write!(f, "亂數來源失敗：{m}"),
            Self::Malformed(m) => write!(f, "資料格式錯誤：{m}"),
        }
    }
}

impl std::error::Error for CryptoError {}

/// 被 KEK 包裹的 DEK，可安全寫進 `manifest.json`。
#[derive(Clone, Debug)]
pub struct Envelope {
    pub kdf: KdfParams,
    wrapped_dek: Vec<u8>,
}

impl Envelope {
    /// 以密語包裹一把新的 DEK。
    pub fn create(passphrase: &str) -> Result<(Self, Dek), CryptoError> {
        let kdf = KdfParams::recommended()?;
        let dek = Dek::generate()?;
        let wrapped = wrap(&kdf.derive_kek(passphrase)?, &dek.0)?;
        Ok((
            Self {
                kdf,
                wrapped_dek: wrapped,
            },
            dek,
        ))
    }

    /// 以密語解出 DEK。
    pub fn unwrap_dek(&self, passphrase: &str) -> Result<Dek, CryptoError> {
        let kek = self.kdf.derive_kek(passphrase)?;
        let plain = unwrap(&kek, &self.wrapped_dek)?;
        let key: [u8; 32] = plain
            .try_into()
            .map_err(|_| CryptoError::Malformed("DEK 長度錯誤".into()))?;
        Ok(Dek::from_bytes(key))
    }

    /// 換密語：重新包裹同一把 DEK。
    ///
    /// **不重新加密任何內容** —— 這正是用信封的理由。
    pub fn rewrap(&self, old_passphrase: &str, new_passphrase: &str) -> Result<Self, CryptoError> {
        let dek = self.unwrap_dek(old_passphrase)?;
        let kdf = KdfParams::recommended()?;
        Ok(Self {
            wrapped_dek: wrap(&kdf.derive_kek(new_passphrase)?, &dek.0)?,
            kdf,
        })
    }

    /// 包裝金鑰時用的 KDF 參數。**要原樣寫進 `manifest.json`** ——
    /// 少寫或寫錯任何一項，同一組密碼就推不出同一把 KEK，
    /// 而使用者看到的是「密碼錯誤」，但他的密碼其實是對的。
    pub fn kdf_params(&self) -> &KdfParams {
        &self.kdf
    }

    pub fn wrapped_dek_b64(&self) -> String {
        B64.encode(&self.wrapped_dek)
    }

    pub fn from_parts(kdf: KdfParams, wrapped_dek_b64: &str) -> Result<Self, CryptoError> {
        Ok(Self {
            kdf,
            wrapped_dek: B64
                .decode(wrapped_dek_b64)
                .map_err(|e| CryptoError::Malformed(e.to_string()))?,
        })
    }
}

fn wrap(kek: &[u8; 32], plaintext: &[u8]) -> Result<Vec<u8>, CryptoError> {
    let cipher = XChaCha20Poly1305::new(kek.into());
    let mut nonce = [0u8; NONCE_LEN];
    getrandom::getrandom(&mut nonce).map_err(|e| CryptoError::Random(e.to_string()))?;

    let ct = cipher
        .encrypt(XNonce::from_slice(&nonce), plaintext)
        .map_err(|_| CryptoError::DecryptionFailed)?;

    let mut out = nonce.to_vec();
    out.extend_from_slice(&ct);
    Ok(out)
}

fn unwrap(kek: &[u8; 32], data: &[u8]) -> Result<Vec<u8>, CryptoError> {
    if data.len() < NONCE_LEN + TAG_LEN {
        return Err(CryptoError::Malformed("資料過短".into()));
    }
    let (nonce, ct) = data.split_at(NONCE_LEN);
    XChaCha20Poly1305::new(kek.into())
        .decrypt(XNonce::from_slice(nonce), ct)
        .map_err(|_| CryptoError::DecryptionFailed)
}

impl Dek {
    /// 加密一個同步 chunk（format-spec §7.1）。
    ///
    /// `aad` 綁定 chunk 的路徑，防止攻擊者把 A 檔的密文搬到 B 檔的位置
    /// —— 內容雖然仍讀不懂，但重排本身就能破壞資料。
    pub fn seal(&self, plaintext: &[u8], aad: &[u8]) -> Result<Vec<u8>, CryptoError> {
        let mut nonce = [0u8; NONCE_LEN];
        getrandom::getrandom(&mut nonce).map_err(|e| CryptoError::Random(e.to_string()))?;

        let ct = self
            .cipher()
            .encrypt(
                XNonce::from_slice(&nonce),
                Payload {
                    msg: plaintext,
                    aad,
                },
            )
            .map_err(|_| CryptoError::DecryptionFailed)?;

        let mut out = nonce.to_vec();
        out.extend_from_slice(&ct);
        Ok(out)
    }

    pub fn open(&self, sealed: &[u8], aad: &[u8]) -> Result<Vec<u8>, CryptoError> {
        if sealed.len() < NONCE_LEN + TAG_LEN {
            return Err(CryptoError::Malformed("chunk 過短".into()));
        }
        let (nonce, ct) = sealed.split_at(NONCE_LEN);
        self.cipher()
            .decrypt(XNonce::from_slice(nonce), Payload { msg: ct, aad })
            .map_err(|_| CryptoError::DecryptionFailed)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 測試用的低成本參數。正式路徑一律用 `recommended()`。
    fn fast_kdf() -> KdfParams {
        KdfParams {
            m_cost_kib: 64,
            t_cost: 1,
            p_cost: 1,
            salt: vec![7u8; 16],
        }
    }

    fn fast_envelope(pass: &str) -> (Envelope, Dek) {
        let kdf = fast_kdf();
        let dek = Dek::from_bytes([42u8; 32]);
        let wrapped = wrap(&kdf.derive_kek(pass).unwrap(), &dek.0).unwrap();
        (
            Envelope {
                kdf,
                wrapped_dek: wrapped,
            },
            dek,
        )
    }

    #[test]
    fn chunk_roundtrips() {
        let dek = Dek::generate().unwrap();
        let plain = b"oplog chunk contents";
        let sealed = dek.seal(plain, b"sync/devA/log-0.bin").unwrap();

        assert_ne!(&sealed[NONCE_LEN..], plain, "密文不得等於明文");
        assert_eq!(dek.open(&sealed, b"sync/devA/log-0.bin").unwrap(), plain);
    }

    #[test]
    fn same_plaintext_encrypts_differently_each_time() {
        // nonce 重複會讓 XChaCha20 的金鑰流重用，是災難性的。
        let dek = Dek::generate().unwrap();
        let a = dek.seal(b"same", b"aad").unwrap();
        let b = dek.seal(b"same", b"aad").unwrap();
        assert_ne!(a, b, "每次加密都必須用新的 nonce");
    }

    #[test]
    fn moving_a_chunk_to_another_path_is_rejected() {
        // AAD 綁定路徑：重排檔案本身就能破壞資料，即使內容讀不懂。
        let dek = Dek::generate().unwrap();
        let sealed = dek.seal(b"data", b"sync/devA/log-0.bin").unwrap();
        assert!(matches!(
            dek.open(&sealed, b"sync/devB/log-0.bin"),
            Err(CryptoError::DecryptionFailed)
        ));
    }

    #[test]
    fn tampering_is_detected() {
        let dek = Dek::generate().unwrap();
        let mut sealed = dek.seal(b"important", b"aad").unwrap();
        let last = sealed.len() - 1;
        sealed[last] ^= 0xFF;

        assert!(matches!(
            dek.open(&sealed, b"aad"),
            Err(CryptoError::DecryptionFailed)
        ));
    }

    #[test]
    fn wrong_key_cannot_open() {
        let a = Dek::generate().unwrap();
        let b = Dek::generate().unwrap();
        let sealed = a.seal(b"secret", b"aad").unwrap();
        assert!(b.open(&sealed, b"aad").is_err());
    }

    #[test]
    fn truncated_chunk_is_malformed_not_a_panic() {
        let dek = Dek::generate().unwrap();
        assert!(matches!(
            dek.open(&[0u8; 5], b"aad"),
            Err(CryptoError::Malformed(_))
        ));
    }

    #[test]
    fn envelope_unwraps_with_correct_passphrase() {
        let (env, dek) = fast_envelope("正確的密語");
        let recovered = env.unwrap_dek("正確的密語").unwrap();

        // 用同一把 DEK 加解密驗證確實相同
        let sealed = dek.seal(b"x", b"a").unwrap();
        assert_eq!(recovered.open(&sealed, b"a").unwrap(), b"x");
    }

    #[test]
    fn envelope_rejects_wrong_passphrase() {
        let (env, _) = fast_envelope("正確");
        assert!(matches!(
            env.unwrap_dek("錯誤"),
            Err(CryptoError::DecryptionFailed)
        ));
    }

    #[test]
    fn rewrap_changes_passphrase_without_touching_content() {
        let (env, dek) = fast_envelope("舊密語");
        let content = "既有內容".as_bytes();
        let sealed = dek.seal(content, b"aad").unwrap();

        // 以低成本 KDF 重新包裹同一把 DEK（等同 rewrap 的語意，但測試不跑滿 Argon2）
        let rewrapped = Envelope {
            kdf: fast_kdf(),
            wrapped_dek: wrap(&fast_kdf().derive_kek("新密語").unwrap(), &dek.0).unwrap(),
        };

        // 關鍵：舊內容一個位元組都沒重新加密，仍能用新密語取回的 DEK 解開。
        let dek2 = rewrapped.unwrap_dek("新密語").unwrap();
        assert_eq!(dek2.open(&sealed, b"aad").unwrap(), content);
        assert!(env.unwrap_dek("舊密語").is_ok(), "舊信封本身不受影響");
    }

    #[test]
    fn dek_debug_does_not_leak_key_material() {
        let dek = Dek::from_bytes([0xAB; 32]);
        let s = format!("{dek:?}");
        assert!(!s.contains("ab"), "金鑰不得出現在除錯輸出：{s}");
        assert!(s.contains("redacted"));
    }

    #[test]
    fn wrapped_dek_survives_base64_roundtrip() {
        let (env, _) = fast_envelope("pass");
        let restored = Envelope::from_parts(env.kdf.clone(), &env.wrapped_dek_b64()).unwrap();
        assert!(restored.unwrap_dek("pass").is_ok());
    }
}
