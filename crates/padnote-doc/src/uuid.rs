//! 最小 UUIDv7 實作，避免為了 16 bytes 引入外部依賴。
//!
//! UUIDv7 前 48 bit 是 Unix 毫秒，因此**字典序即時間序** —— oplog 與筆畫檔
//! 依賴這個性質做順序掃描。

use std::fmt;

#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Default)]
pub struct Uuid(pub [u8; 16]);

impl Uuid {
    pub const fn from_bytes(b: [u8; 16]) -> Self {
        Self(b)
    }

    pub const fn as_bytes(&self) -> &[u8; 16] {
        &self.0
    }

    /// 產生 UUIDv7：48-bit Unix 毫秒 + 74-bit 隨機。
    pub fn now_v7() -> Self {
        let ms = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis() as u64)
            .unwrap_or(0);
        Self::v7_from_parts(ms, random_u64())
    }

    pub fn v7_from_parts(unix_ms: u64, rand: u64) -> Self {
        let mut b = [0u8; 16];
        b[0..6].copy_from_slice(&unix_ms.to_be_bytes()[2..8]);
        b[6..14].copy_from_slice(&rand.to_be_bytes());
        b[14] = (rand >> 8) as u8;
        b[15] = rand as u8;
        b[6] = (b[6] & 0x0f) | 0x70; // version 7
        b[8] = (b[8] & 0x3f) | 0x80; // variant RFC 4122
        Self(b)
    }
}

/// 以 `RandomState` 取得非密碼學亂數。**不可用於金鑰**，金鑰走
/// `padnote-crypto` 的 CSPRNG。
fn random_u64() -> u64 {
    use std::hash::{BuildHasher, Hasher};
    let mut h = std::collections::hash_map::RandomState::new().build_hasher();
    h.write_usize(std::ptr::addr_of!(h) as usize);
    h.write_u128(
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_nanos())
            .unwrap_or(0),
    );
    h.finish()
}

impl fmt::Debug for Uuid {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{self}")
    }
}

impl fmt::Display for Uuid {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let b = &self.0;
        for (i, byte) in b.iter().enumerate() {
            if matches!(i, 4 | 6 | 8 | 10) {
                f.write_str("-")?;
            }
            write!(f, "{byte:02x}")?;
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn v7_is_lexicographically_time_ordered() {
        let early = Uuid::v7_from_parts(1_000, 0xAAAA_AAAA_AAAA_AAAA);
        let late = Uuid::v7_from_parts(2_000, 0x1111_1111_1111_1111);
        assert!(early < late, "UUIDv7 字典序必須等於時間序");
    }

    #[test]
    fn v7_sets_version_and_variant() {
        let u = Uuid::now_v7();
        assert_eq!(u.0[6] & 0xf0, 0x70, "version 必須是 7");
        assert_eq!(u.0[8] & 0xc0, 0x80, "variant 必須是 RFC 4122");
    }

    #[test]
    fn display_is_canonical_36_chars() {
        let s = Uuid::from_bytes([0x01; 16]).to_string();
        assert_eq!(s.len(), 36);
        assert_eq!(s, "01010101-0101-0101-0101-010101010101");
    }
}
