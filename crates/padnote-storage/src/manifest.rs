//! `manifest.json` —— 套件中**唯一的明文中繼資料**（format-spec §3）。

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

/// 本 build 支援的格式版本。
///
/// # 為什麼從 1 變成 2（H-OPLOG-COMPAT）
///
/// 這一版的 oplog **每一批都會寫 `DocOp::BatchOrigin`（op 37）**，而
/// `decode` 遇到不認得的 op 類型是**回錯誤**的 —— 錯誤一路傳到
/// `NotebookSession::open`，結果是**整本筆記打不開**，不是「少了某些內容」。
///
/// `format-spec.md` §8 本來就規定「寫入舊讀取器不認得的 op 時要提升
/// `min_reader_version`」。那條規矩**從來沒有真的被執行過** —— 於是現在
/// 的行為是一個看不懂的解碼錯誤，而不是設計中的「拒絕開啟並提示升級」。
///
/// 提升之後，舊版讀到 `min_reader_version = 2` 會在 `can_be_opened` 就
/// 乾淨地拒絕（`package.rs` 已經在檢查了），使用者看到的是「這本筆記需要
/// 較新的版本」，而不是「格式錯誤」。
pub const SPEC_VERSION: u32 = 2;

/// 會寫出 `BatchOrigin`（op 37）的套件，讀取器至少要是這一版。
///
/// 這個常數存在的理由是**讓下一次格式變更有地方掛**：直接寫
/// `min_reader_version = 2` 的話，下一個人新增 op 時不會知道要動哪裡。
pub const READER_VERSION_FOR_BATCH_ORIGIN: u32 = 2;

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
    /// 壓實**不得跨越**的 lamport 界線，逐裝置（工作項 S-99）。
    ///
    /// # 為什麼這件事非記在明文 manifest 不可
    ///
    /// 里程碑用檔名裡的 `(lamport, device)` 當座標。壓實會把
    /// `0001..0010` 併成一個叫 `0010` 的檔 —— 併完之後，本來 lamport 為 3 的
    /// 操作對外宣稱自己是 10，於是「回到 lamport 5 那一刻」這條線就跑到了
    /// 錯的地方：還原**靜默地**失效，或者遮掉不該遮的東西。
    ///
    /// 所以壓實只能在界線**之內**合併。而界線必須是明文的：壓實刻意設計成
    /// 不需要金鑰也能做（見 `compact_own_doc_ops`），若把界線藏在加密的
    /// oplog 裡，鎖著的套件壓實時就會把它們踩掉。
    ///
    /// 這裡只有幾個整數，不洩漏內容 —— manifest 本來就有裝置與時間資訊。
    #[serde(default)]
    pub milestone_barriers: BTreeMap<u32, Vec<u64>>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(tag = "scheme", rename_all = "kebab-case")]
pub enum Encryption {
    #[default]
    None,
    #[serde(rename = "xchacha20poly1305-argon2id")]
    XChaCha20Poly1305Argon2id {
        kdf: KdfParams,
        wrapped_dek_b64: String,
        recovery: RecoveryParams,
    },
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
    /// **用復原碼包住的同一把 DEK**，以及它自己的 KDF 參數。
    ///
    /// # 為什麼原本沒有，以及那有多糟
    ///
    /// 這一欄原本不存在 —— 復原碼是一串與 DEK 完全無關的隨機詞，
    /// manifest 只記了「用哪套字表」與「幾個詞」。於是介面上那句
    /// 「沒有密碼重設。忘記密碼的話，這組碼是**唯一**的後路」是假的：
    /// 那組碼什麼也打不開，而三步驟流程還強迫使用者抄下並回填它。
    ///
    /// 忘記密碼等於永久失去那本筆記，而 App 明確承諾了相反的事。
    ///
    /// `Option` 是為了讀得動舊的套件（那些套件的復原碼是真的沒用）——
    /// 不是為了讓新套件可以不寫。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub wrapped: Option<WrappedDek>,
}

/// 一份用某個密語包住的 DEK，含它自己的 KDF 參數。
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WrappedDek {
    pub kdf: KdfParams,
    pub wrapped_dek_b64: String,
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
            milestone_barriers: BTreeMap::new(),
        }
    }

    /// 目前的讀取器能否安全開啟（format-spec §8）。
    ///
    /// 向前相容：新版檔案只要宣告舊讀取器仍可解析，就允許開啟並忽略未知欄位。
    /// 反之則拒絕 —— 猜測解析會造成靜默的資料損毀。
    pub fn can_be_opened(&self) -> bool {
        self.format == "padnote" && self.min_reader_version <= SPEC_VERSION
    }

    /// 記下一條界線。重複的不會重覆記。
    pub fn add_milestone_barrier(&mut self, device: u32, lamport: u64) {
        let list = self.milestone_barriers.entry(device).or_default();
        if let Err(at) = list.binary_search(&lamport) {
            list.insert(at, lamport);
        }
    }

    /// 這台裝置的界線，由小到大。
    pub fn barriers_for(&self, device: u32) -> &[u64] {
        self.milestone_barriers
            .get(&device)
            .map_or(&[][..], Vec::as_slice)
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
                wrapped: None,
            },
        };
        let json = serde_json::to_string(&m).unwrap();
        assert!(json.contains("xchacha20poly1305-argon2id"));

        let back: Manifest = serde_json::from_str(&json).unwrap();
        assert!(back.is_encrypted());
    }
}
