//! `manifest.json` —— 套件中**唯一的明文中繼資料**（format-spec §3）。

use serde::{Deserialize, Serialize};

/// 本 build 支援的格式版本。
pub const SPEC_VERSION: u32 = 1;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Manifest {
    /// 固定為 `"padnote"`，用於辨識檔案類型。
    pub format: String,
    pub spec_version: u32,
    pub notebook_id: String,
    pub created_at_unix_ms: u64,
    /// 時間軸原點。所有 `notebook_time_us` 都相對於此（format-spec §4.1）。
    pub time_origin_unix_us: u64,
    pub title: String,
    /// 低於此版本的讀取器**必須拒絕開啟**，而非嘗試解析。
    pub min_reader_version: u32,
    #[serde(default)]
    pub encryption: Encryption,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "scheme", rename_all = "kebab-case")]
pub enum Encryption {
    None,
    #[serde(rename = "xchacha20poly1305-argon2id")]
    XChaCha20Poly1305Argon2id {
        kdf: KdfParams,
        wrapped_dek_b64: String,
        recovery: RecoveryParams,
    },
}

impl Default for Encryption {
    fn default() -> Self {
        Self::None
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KdfParams {
    pub algo: String,
    pub m_cost_kib: u32,
    pub t_cost: u32,
    pub p_cost: u32,
    pub salt_b64: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecoveryParams {
    pub algo: String,
    pub words: u32,
}

impl Manifest {
    pub fn new(notebook_id: String, title: String, now_unix_ms: u64) -> Self {
        Self {
            format: "padnote".into(),
            spec_version: SPEC_VERSION,
            notebook_id,
            created_at_unix_ms: now_unix_ms,
            time_origin_unix_us: now_unix_ms * 1_000,
            title,
            min_reader_version: SPEC_VERSION,
            encryption: Encryption::None,
        }
    }

    /// 目前的讀取器能否安全開啟（format-spec §8）。
    ///
    /// 向前相容：新版檔案只要宣告舊讀取器仍可解析，就允許開啟並忽略未知欄位。
    /// 反之則拒絕 —— 猜測解析會造成靜默的資料損毀。
    pub fn can_be_opened(&self) -> bool {
        self.format == "padnote" && self.min_reader_version <= SPEC_VERSION
    }

    pub fn is_encrypted(&self) -> bool {
        !matches!(self.encryption, Encryption::None)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample() -> Manifest {
        Manifest::new(
            "0193f2a1".into(),
            "線性代數 第三週".into(),
            1_757_635_200_000,
        )
    }

    #[test]
    fn roundtrips_through_json() {
        let m = sample();
        let json = serde_json::to_string_pretty(&m).unwrap();
        let back: Manifest = serde_json::from_str(&json).unwrap();
        assert_eq!(back.notebook_id, m.notebook_id);
        assert_eq!(back.title, "線性代數 第三週");
        assert_eq!(back.time_origin_unix_us, m.created_at_unix_ms * 1_000);
        assert!(!back.is_encrypted());
    }

    #[test]
    fn unknown_fields_are_ignored_for_forward_compatibility() {
        let json = r#"{
            "format": "padnote", "spec_version": 1, "notebook_id": "x",
            "created_at_unix_ms": 1, "time_origin_unix_us": 1000,
            "title": "t", "min_reader_version": 1,
            "a_field_from_the_future": {"nested": true}
        }"#;
        let m: Manifest = serde_json::from_str(json).expect("未知欄位不應導致失敗");
        assert!(m.can_be_opened());
    }

    #[test]
    fn refuses_file_demanding_newer_reader() {
        let mut m = sample();
        m.min_reader_version = SPEC_VERSION + 1;
        assert!(!m.can_be_opened(), "須拒絕，絕不嘗試解析");
    }

    #[test]
    fn refuses_foreign_format() {
        let mut m = sample();
        m.format = "notability".into();
        assert!(!m.can_be_opened());
    }

    #[test]
    fn encryption_variant_roundtrips() {
        let mut m = sample();
        m.encryption = Encryption::XChaCha20Poly1305Argon2id {
            kdf: KdfParams {
                algo: "argon2id".into(),
                m_cost_kib: 65_536,
                t_cost: 3,
                p_cost: 1,
                salt_b64: "c2FsdA==".into(),
            },
            wrapped_dek_b64: "ZGVr".into(),
            recovery: RecoveryParams {
                algo: "bip39".into(),
                words: 24,
            },
        };
        let json = serde_json::to_string(&m).unwrap();
        assert!(json.contains("xchacha20poly1305-argon2id"));

        let back: Manifest = serde_json::from_str(&json).unwrap();
        assert!(back.is_encrypted());
    }
}
