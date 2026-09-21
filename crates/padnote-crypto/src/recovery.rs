//! 復原碼（功能 G7）。
//!
//! 無後端 ⇒ 沒有「忘記密碼」信件，沒有客服能救。復原碼是**唯一**的後路，
//! 因此必須在建立加密時就強制產生並要求使用者抄寫確認。
//!
//! 採 BIP39 風格：熵 + SHA-256 校驗和 → 助記詞。校驗和讓抄錯字當場就被抓到，
//! 而不是等到真的要救資料時才發現。
//!
//! 詞表以參數傳入；官方 BIP39 英文 2048 詞表由 [`english_wordlist`] 提供，
//! 內嵌在二進位裡（`third_party/bip39/english.txt`）。
//!
//! **詞表不能隨版本改。** 換掉一個字，所有既有的復原碼就再也解不開 ——
//! 而那是使用者唯一的後路。

use sha2::{Digest, Sha256};
use std::fmt;

/// 詞表必須的大小（2^11，每個詞編碼 11 bit）。
pub const WORDLIST_LEN: usize = 2048;

/// 官方 BIP39 英文詞表（來源與雜湊見 `third_party/bip39/README.md`）。
const ENGLISH_WORDLIST: &str = include_str!("../../../third_party/bip39/english.txt");

/// 官方 BIP39 英文詞表，2048 個詞。
///
/// 每次呼叫都會切一次字串，但那只發生在產生或驗證復原碼的時候 ——
/// 一個使用者一輩子大概做兩次。
pub fn english_wordlist() -> Vec<&'static str> {
    ENGLISH_WORDLIST.split_whitespace().collect()
}

#[derive(Debug)]
pub enum RecoveryError {
    /// 詞表大小不是 2048。
    BadWordlist(usize),
    /// 熵長度不被支援（只接受 16 或 32 bytes ⇒ 12 或 24 詞）。
    BadEntropyLength(usize),
    UnknownWord(String),
    WrongWordCount(usize),
    /// 校驗和不符 —— 通常是抄錯字或順序錯了。
    ChecksumMismatch,
}

impl fmt::Display for RecoveryError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadWordlist(n) => write!(f, "詞表必須是 {WORDLIST_LEN} 個詞，實得 {n}"),
            Self::BadEntropyLength(n) => write!(f, "熵長度須為 16 或 32 bytes，實得 {n}"),
            Self::UnknownWord(w) => write!(f, "無法辨識的詞：{w}"),
            Self::WrongWordCount(n) => write!(f, "詞數須為 12 或 24，實得 {n}"),
            Self::ChecksumMismatch => write!(f, "復原碼校驗失敗，請檢查是否抄錯字或順序有誤"),
        }
    }
}

impl std::error::Error for RecoveryError {}

/// 一組復原碼。
#[derive(Clone, PartialEq, Eq)]
pub struct RecoveryCode {
    words: Vec<String>,
    entropy: Vec<u8>,
}

// 復原碼等同金鑰，不得出現在 log 中。
impl fmt::Debug for RecoveryCode {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "RecoveryCode({} words, <redacted>)", self.words.len())
    }
}

impl RecoveryCode {
    /// 從熵產生復原碼。16 bytes ⇒ 12 詞；32 bytes ⇒ 24 詞。
    pub fn from_entropy(entropy: &[u8], wordlist: &[&str]) -> Result<Self, RecoveryError> {
        if wordlist.len() != WORDLIST_LEN {
            return Err(RecoveryError::BadWordlist(wordlist.len()));
        }
        if !matches!(entropy.len(), 16 | 32) {
            return Err(RecoveryError::BadEntropyLength(entropy.len()));
        }

        // 校驗和取 SHA-256 的前 entropy_bits/32 個 bit。
        let checksum_bits = entropy.len() * 8 / 32;
        let hash = Sha256::digest(entropy);

        let mut bits: Vec<bool> = entropy
            .iter()
            .flat_map(|b| (0..8).rev().map(move |i| (b >> i) & 1 == 1))
            .collect();
        for i in 0..checksum_bits {
            bits.push((hash[i / 8] >> (7 - i % 8)) & 1 == 1);
        }

        let words = bits
            .chunks(11)
            .map(|c| {
                let idx = c.iter().fold(0usize, |acc, &b| (acc << 1) | usize::from(b));
                wordlist[idx].to_string()
            })
            .collect();

        Ok(Self {
            words,
            entropy: entropy.to_vec(),
        })
    }

    /// 產生新的 24 詞復原碼（256-bit 熵）。
    pub fn generate(wordlist: &[&str]) -> Result<Self, RecoveryError> {
        let mut entropy = [0u8; 32];
        getrandom::getrandom(&mut entropy).expect("系統亂數來源不可用");
        Self::from_entropy(&entropy, wordlist)
    }

    /// 解析使用者輸入的復原碼，並驗證校驗和。
    pub fn parse(input: &str, wordlist: &[&str]) -> Result<Self, RecoveryError> {
        if wordlist.len() != WORDLIST_LEN {
            return Err(RecoveryError::BadWordlist(wordlist.len()));
        }

        let words: Vec<String> = input
            .split_whitespace()
            .map(|w| w.trim().to_lowercase())
            .filter(|w| !w.is_empty())
            .collect();

        if !matches!(words.len(), 12 | 24) {
            return Err(RecoveryError::WrongWordCount(words.len()));
        }

        let mut bits = Vec::with_capacity(words.len() * 11);
        for w in &words {
            let idx = wordlist
                .iter()
                .position(|x| *x == w)
                .ok_or_else(|| RecoveryError::UnknownWord(w.clone()))?;
            for i in (0..11).rev() {
                bits.push((idx >> i) & 1 == 1);
            }
        }

        let entropy_bits = words.len() * 11 * 32 / 33;
        let entropy: Vec<u8> = bits[..entropy_bits]
            .chunks(8)
            .map(|c| c.iter().fold(0u8, |acc, &b| (acc << 1) | u8::from(b)))
            .collect();

        // 重算校驗和比對。抄錯一個字就會在這裡被抓到。
        let expected = Self::from_entropy(&entropy, wordlist)?;
        if expected.words != words {
            return Err(RecoveryError::ChecksumMismatch);
        }
        Ok(expected)
    }

    pub fn words(&self) -> &[String] {
        &self.words
    }

    pub fn entropy(&self) -> &[u8] {
        &self.entropy
    }

    /// 供使用者抄寫的呈現形式。
    pub fn phrase(&self) -> String {
        self.words.join(" ")
    }
}

#[cfg(test)]
mod wordlist_tests {
    use super::*;

    #[test]
    fn the_embedded_wordlist_is_the_official_one() {
        let words = english_wordlist();
        assert_eq!(words.len(), WORDLIST_LEN, "詞表長度不對");
        assert_eq!(words[0], "abandon");
        assert_eq!(words[WORDLIST_LEN - 1], "zoo");
    }

    #[test]
    fn every_word_is_unique() {
        // 重複的字會讓同一個助記詞對應到兩個索引 —— 解出來的熵就錯了，
        // 而錯誤只會在真的要救資料時出現。
        let words = english_wordlist();
        let unique: std::collections::BTreeSet<&str> = words.iter().copied().collect();
        assert_eq!(unique.len(), WORDLIST_LEN);
    }

    #[test]
    fn the_first_four_letters_identify_a_word() {
        // BIP39 的設計保證：前四個字母即可唯一辨識。
        // 使用者抄到一半看不清後面幾個字母時，這一點救得回來。
        let words = english_wordlist();
        let prefixes: std::collections::BTreeSet<String> = words
            .iter()
            .map(|w| w.chars().take(4).collect::<String>())
            .collect();
        assert_eq!(prefixes.len(), WORDLIST_LEN, "有前四字母相同的字");
    }

    #[test]
    fn a_generated_code_round_trips_through_the_official_wordlist() {
        let words = english_wordlist();
        let code = RecoveryCode::generate(&words).expect("產生復原碼");
        let parsed = RecoveryCode::parse(&code.phrase(), &words).expect("解析復原碼");
        assert_eq!(parsed.entropy(), code.entropy());
    }

    #[test]
    fn a_typo_is_caught_by_the_checksum() {
        // 校驗和的意義就是「抄錯字當場被抓到」，而不是等到要救資料時。
        let words = english_wordlist();
        let code = RecoveryCode::generate(&words).expect("產生復原碼");
        let mut parts: Vec<String> = code.words().to_vec();
        // 換掉第一個字（換成一個一定不同的）。
        parts[0] = if parts[0] == "abandon" {
            "ability".into()
        } else {
            "abandon".into()
        };
        assert!(RecoveryCode::parse(&parts.join(" "), &words).is_err());
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 測試詞表：`w0`..`w2047`。正式版用官方 BIP39 詞表。
    fn wordlist() -> Vec<String> {
        (0..WORDLIST_LEN).map(|i| format!("w{i}")).collect()
    }

    fn refs(v: &[String]) -> Vec<&str> {
        v.iter().map(String::as_str).collect()
    }

    #[test]
    fn generates_24_words_from_256_bits() {
        let wl = wordlist();
        let code = RecoveryCode::from_entropy(&[0xABu8; 32], &refs(&wl)).unwrap();
        assert_eq!(code.words().len(), 24);
    }

    #[test]
    fn generates_12_words_from_128_bits() {
        let wl = wordlist();
        let code = RecoveryCode::from_entropy(&[0x5Au8; 16], &refs(&wl)).unwrap();
        assert_eq!(code.words().len(), 12);
    }

    #[test]
    fn roundtrips_through_phrase() {
        let wl = wordlist();
        let original = RecoveryCode::from_entropy(&[0x11u8; 32], &refs(&wl)).unwrap();
        let parsed = RecoveryCode::parse(&original.phrase(), &refs(&wl)).unwrap();
        assert_eq!(parsed.entropy(), original.entropy());
    }

    #[test]
    fn detects_a_single_mistyped_word() {
        // 這正是校驗和存在的理由 —— 抄錯要當場發現，不是等到救資料時。
        let wl = wordlist();
        let code = RecoveryCode::from_entropy(&[0x22u8; 32], &refs(&wl)).unwrap();

        let mut words = code.words().to_vec();
        words[5] = if words[5] == "w0" {
            "w1".into()
        } else {
            "w0".into()
        };

        assert!(matches!(
            RecoveryCode::parse(&words.join(" "), &refs(&wl)),
            Err(RecoveryError::ChecksumMismatch)
        ));
    }

    #[test]
    fn detects_swapped_word_order() {
        let wl = wordlist();
        let code = RecoveryCode::from_entropy(&[0x33u8; 32], &refs(&wl)).unwrap();
        let mut words = code.words().to_vec();
        words.swap(0, 1);

        assert!(
            RecoveryCode::parse(&words.join(" "), &refs(&wl)).is_err(),
            "順序錯誤必須被偵測"
        );
    }

    #[test]
    fn rejects_unknown_word() {
        let wl = wordlist();
        let code = RecoveryCode::from_entropy(&[0x44u8; 32], &refs(&wl)).unwrap();
        let mut words = code.words().to_vec();
        words[0] = "definitely-not-in-the-list".into();

        assert!(matches!(
            RecoveryCode::parse(&words.join(" "), &refs(&wl)),
            Err(RecoveryError::UnknownWord(_))
        ));
    }

    #[test]
    fn rejects_wrong_word_count() {
        let wl = wordlist();
        assert!(matches!(
            RecoveryCode::parse("w0 w1 w2", &refs(&wl)),
            Err(RecoveryError::WrongWordCount(3))
        ));
    }

    #[test]
    fn tolerates_extra_whitespace_and_case() {
        let wl = wordlist();
        let code = RecoveryCode::from_entropy(&[0x55u8; 32], &refs(&wl)).unwrap();
        let messy = format!("  {}  ", code.phrase().to_uppercase().replace(' ', "   "));
        assert!(
            RecoveryCode::parse(&messy, &refs(&wl)).is_ok(),
            "使用者抄寫的空白與大小寫不該造成失敗"
        );
    }

    #[test]
    fn rejects_bad_entropy_length() {
        let wl = wordlist();
        assert!(matches!(
            RecoveryCode::from_entropy(&[0u8; 20], &refs(&wl)),
            Err(RecoveryError::BadEntropyLength(20))
        ));
    }

    #[test]
    fn rejects_wrong_sized_wordlist() {
        let short: Vec<&str> = vec!["a", "b"];
        assert!(matches!(
            RecoveryCode::from_entropy(&[0u8; 32], &short),
            Err(RecoveryError::BadWordlist(2))
        ));
    }

    #[test]
    fn generated_codes_differ() {
        let wl = wordlist();
        let a = RecoveryCode::generate(&refs(&wl)).unwrap();
        let b = RecoveryCode::generate(&refs(&wl)).unwrap();
        assert_ne!(a.phrase(), b.phrase());
    }

    #[test]
    fn debug_does_not_leak_the_phrase() {
        let wl = wordlist();
        let code = RecoveryCode::from_entropy(&[0x66u8; 32], &refs(&wl)).unwrap();
        let s = format!("{code:?}");
        assert!(!s.contains(&code.words()[0]), "復原碼不得出現在除錯輸出");
    }
}
