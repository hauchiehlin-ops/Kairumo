//! 模型清單（`models/MODELS.md` 的機器可讀版本）。

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ModelEntry {
    pub id: String,
    pub url: String,
    /// 主來源連不上時自動改用的鏡像。空字串表示沒有鏡像。
    ///
    /// # 為什麼是自動，不是讓使用者選
    ///
    /// 介面上原本有「從鏡像下載」按鈕，而使用者**不知道自己該選哪個** ——
    /// 他只知道「下載失敗了」。把選擇權交給使用者，等於把一個他沒有資訊
    /// 可以判斷的決定丟給他。
    ///
    /// 換來源之後續傳照樣進行（要求的是同一個位元組區間），而
    /// `finalize` 的大小 + sha256 雙重驗證是安全網：兩邊內容只要有一個
    /// 位元組不同，檔案會被刪掉而不是被當成好的留下來。
    #[serde(default)]
    pub mirror_url: String,
    /// 小寫 hex，64 字元。
    pub sha256: String,
    pub size_bytes: u64,
    /// **權重授權**，與程式碼授權不同（決策 D6）。
    pub license: String,
    /// 哪些能力需要它，例如 `["asr.zh"]`。
    #[serde(default)]
    pub required_for: Vec<String>,
    /// 選用。使用者不會被要求下載它，除非他自己挑了這個引擎。
    ///
    /// 用來把**授權有爭議**的模型擋在預設路徑之外（決策 D-07）：
    /// 它仍然留在清單裡（想用的人挑得到），但第一次開錄音的人不會被
    /// 要求下載一個條款互相衝突的權重。
    #[serde(default)]
    pub optional: bool,
    /// 給人看的說明。不影響任何判斷。
    #[serde(default)]
    pub notes: String,
}

impl ModelEntry {
    /// 清單本身是否格式正確。格式錯的項目不該進到下載流程。
    pub fn is_well_formed(&self) -> bool {
        self.sha256.len() == 64
            && self
                .sha256
                .chars()
                .all(|c| c.is_ascii_hexdigit() && !c.is_ascii_uppercase())
            && self.size_bytes > 0
            && (self.url.starts_with("https://"))
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ModelCatalog {
    pub models: Vec<ModelEntry>,
}

impl ModelCatalog {
    pub fn parse(json: &str) -> Result<Self, String> {
        serde_json::from_str(json).map_err(|e| e.to_string())
    }

    pub fn get(&self, id: &str) -> Option<&ModelEntry> {
        self.models.iter().find(|m| m.id == id)
    }

    /// 提供某個能力的所有模型。
    pub fn for_capability(&self, capability: &str) -> Vec<&ModelEntry> {
        self.models
            .iter()
            .filter(|m| m.required_for.iter().any(|c| c == capability))
            .collect()
    }

    /// 格式有問題的項目。CI 應該擋下非空結果。
    pub fn malformed(&self) -> Vec<&ModelEntry> {
        self.models.iter().filter(|m| !m.is_well_formed()).collect()
    }

    pub fn total_bytes(&self, ids: &[&str]) -> u64 {
        ids.iter()
            .filter_map(|id| self.get(id))
            .map(|m| m.size_bytes)
            .sum()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const SAMPLE: &str = r#"{
      "models": [
        {
          "id": "paraformer-zh",
          "url": "https://huggingface.co/example/model.onnx",
          "sha256": "0000000000000000000000000000000000000000000000000000000000000001",
          "size_bytes": 230686720,
          "license": "Apache-2.0",
          "required_for": ["asr.zh"]
        },
        {
          "id": "silero-vad",
          "url": "https://huggingface.co/example/vad.onnx",
          "sha256": "0000000000000000000000000000000000000000000000000000000000000002",
          "size_bytes": 2097152,
          "license": "MIT",
          "required_for": ["asr.zh", "asr.en"]
        }
      ]
    }"#;

    #[test]
    fn parses_and_looks_up() {
        let c = ModelCatalog::parse(SAMPLE).unwrap();
        assert_eq!(c.models.len(), 2);
        assert_eq!(c.get("silero-vad").unwrap().license, "MIT");
        assert!(c.get("nonexistent").is_none());
    }

    #[test]
    fn finds_models_by_capability() {
        let c = ModelCatalog::parse(SAMPLE).unwrap();
        assert_eq!(c.for_capability("asr.zh").len(), 2);
        assert_eq!(c.for_capability("asr.en").len(), 1);
        assert!(c.for_capability("llm.summary").is_empty());
    }

    #[test]
    fn sums_download_size_before_starting() {
        let c = ModelCatalog::parse(SAMPLE).unwrap();
        assert_eq!(c.total_bytes(&["paraformer-zh", "silero-vad"]), 232_783_872);
        assert_eq!(c.total_bytes(&["nonexistent"]), 0);
    }

    #[test]
    fn detects_malformed_entries() {
        let bad = r#"{"models":[
          {"id":"a","url":"http://insecure.example/m","sha256":"0000000000000000000000000000000000000000000000000000000000000001","size_bytes":1,"license":"MIT"},
          {"id":"b","url":"https://ok.example/m","sha256":"tooshort","size_bytes":1,"license":"MIT"},
          {"id":"c","url":"https://ok.example/m","sha256":"0000000000000000000000000000000000000000000000000000000000000003","size_bytes":0,"license":"MIT"}
        ]}"#;
        let c = ModelCatalog::parse(bad).unwrap();
        let bad_ids: Vec<&str> = c.malformed().iter().map(|m| m.id.as_str()).collect();
        assert_eq!(
            bad_ids,
            ["a", "b", "c"],
            "http、雜湊長度錯、大小為 0 都該被擋"
        );
    }

    #[test]
    fn uppercase_hash_is_rejected_to_keep_comparison_simple() {
        let m = ModelEntry {
            id: "x".into(),
            url: "https://e.example/m".into(),
            sha256: "A".repeat(64),
            size_bytes: 1,
            license: "MIT".into(),
            required_for: vec![],
            optional: false,
            notes: String::new(),
            mirror_url: String::new(),
        };
        assert!(!m.is_well_formed());
    }

    #[test]
    fn rejects_invalid_json() {
        assert!(ModelCatalog::parse("{ not json").is_err());
    }
}
