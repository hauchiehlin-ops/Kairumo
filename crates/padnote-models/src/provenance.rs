//! 自行匯出模型的來源紀錄（ADR-0006 / 決策 D-07）。
//!
//! 「自行匯出」如果只是換個地方拿檔案，就沒有意義。真正的價值在於
//! **把取得當下的授權狀態固定下來並可被檢查**：
//!
//! - 來源 repo 與 **commit revision**（不是 `main`，那會浮動）
//! - 該 repo LICENSE 檔的 SHA-256 —— 對方日後改授權，已匯出的版本仍受當時條款涵蓋
//! - 匯出工具版本 —— 讓匯出可重現
//! - 產出檔案的 SHA-256 —— 讓下游能核對拿到的是同一份東西

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Source {
    pub host: String,
    pub repo: String,
    /// **必須是實際的 commit sha**，不能是 `main` 之類的浮動參照。
    pub revision: String,
    pub url: String,
}

/// 授權證據。**兩種強度不同，必須分開模型化** ——
/// 一視同仁會讓稽核報告失去意義。
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(tag = "evidence", rename_all = "snake_case")]
pub enum LicenseEvidence {
    /// repo 內含完整授權文本。**最強** —— 著作權人在自己的散布通路
    /// 放上完整條款原文。
    LicenseFile {
        file: String,
        url: String,
        /// 取得當下授權原文的雜湊。這是整份紀錄的核心。
        sha256: String,
        bytes: u64,
    },
    /// 只有 model card 的 `license:` 標籤。仍是著作權人的正式宣告
    /// （HF 會顯示在頁面上），但**沒有條款原文**，證據較弱。
    ModelCardMetadata {
        declared_license: String,
        url: String,
        readme_url: String,
        readme_sha256: String,
        /// cardData 的雜湊。
        sha256: String,
        /// README 的位元組數。
        bytes: u64,
    },
}

impl LicenseEvidence {
    /// 宣告的授權名稱。
    pub fn declared(&self) -> Option<&str> {
        match self {
            Self::LicenseFile { .. } => None, // 需讀原文判斷
            Self::ModelCardMetadata {
                declared_license, ..
            } => Some(declared_license),
        }
    }

    /// 是否為最強的證據（完整授權原文）。
    pub fn is_full_text(&self) -> bool {
        matches!(self, Self::LicenseFile { .. })
    }

    fn sha256(&self) -> &str {
        match self {
            Self::LicenseFile { sha256, .. } | Self::ModelCardMetadata { sha256, .. } => sha256,
        }
    }

    /// 授權證據的位元組數。`LicenseFile` 是授權原文長度，
    /// `ModelCardMetadata` 是 README 長度。
    pub fn bytes(&self) -> u64 {
        match self {
            Self::LicenseFile { bytes, .. } | Self::ModelCardMetadata { bytes, .. } => *bytes,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Artifact {
    pub file: String,
    pub sha256: String,
    pub bytes: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Provenance {
    pub model_id: String,
    pub purpose: String,
    #[serde(default)]
    pub capabilities: Vec<String>,
    pub source: Source,
    pub license: LicenseEvidence,
    pub exported_at_utc: String,
    pub exported_by: String,
    #[serde(default)]
    pub tools: std::collections::BTreeMap<String, String>,
    pub artifacts: Vec<Artifact>,
    #[serde(default)]
    pub note: String,
}

/// 紀錄不完整的原因。
#[derive(Debug, PartialEq, Eq)]
pub enum ProvenanceError {
    /// revision 是 `main`/`master` 之類會浮動的參照。
    FloatingRevision(String),
    /// LICENSE 雜湊格式不對。
    BadLicenseHash(String),
    /// 授權檔太小 —— 多半是抓到錯誤頁而不是授權文本。
    ///
    /// 這個檢查的由來：silero 的 HuggingFace URL 需要登入，`curl` 拿到的是
    /// 29 bytes 的 "Invalid username or password"，副檔名還是 `.onnx`。
    SuspiciousLicenseSize(u64),
    /// model card 宣告了授權名稱卻是空的。
    EmptyDeclaredLicense,
    NoArtifacts,
    BadArtifactHash(String),
    MissingToolVersion(String),
}

impl std::fmt::Display for ProvenanceError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::FloatingRevision(r) => {
                write!(f, "revision 必須是實際的 commit sha，不能是浮動參照：{r}")
            }
            Self::BadLicenseHash(h) => write!(f, "授權檔雜湊格式錯誤：{h}"),
            Self::SuspiciousLicenseSize(n) => {
                write!(f, "授權檔只有 {n} bytes，多半不是授權文本而是錯誤頁")
            }
            Self::EmptyDeclaredLicense => write!(f, "model card 未宣告授權名稱"),
            Self::NoArtifacts => write!(f, "沒有任何產出檔案"),
            Self::BadArtifactHash(file) => write!(f, "產出檔案雜湊格式錯誤：{file}"),
            Self::MissingToolVersion(t) => write!(f, "缺少工具版本紀錄：{t}"),
        }
    }
}

impl std::error::Error for ProvenanceError {}

fn is_sha256(s: &str) -> bool {
    s.len() == 64
        && s.chars()
            .all(|c| c.is_ascii_hexdigit() && !c.is_ascii_uppercase())
}

impl Provenance {
    pub fn parse(json: &str) -> Result<Self, String> {
        serde_json::from_str(json).map_err(|e| e.to_string())
    }

    /// 這份紀錄是否足以支撐授權主張。
    pub fn validate(&self) -> Result<(), Vec<ProvenanceError>> {
        let mut errs = Vec::new();

        if matches!(self.source.revision.as_str(), "main" | "master" | "HEAD")
            || self.source.revision.len() < 7
        {
            errs.push(ProvenanceError::FloatingRevision(
                self.source.revision.clone(),
            ));
        }

        if !is_sha256(self.license.sha256()) {
            errs.push(ProvenanceError::BadLicenseHash(
                self.license.sha256().into(),
            ));
        }
        match &self.license {
            // Apache-2.0 全文超過 10 KB；任何小於 200 bytes 的都可疑。
            LicenseEvidence::LicenseFile { bytes, .. } if *bytes < 200 => {
                errs.push(ProvenanceError::SuspiciousLicenseSize(*bytes));
            }
            LicenseEvidence::ModelCardMetadata {
                declared_license, ..
            } if declared_license.trim().is_empty() => {
                errs.push(ProvenanceError::EmptyDeclaredLicense);
            }
            _ => {}
        }

        if self.artifacts.is_empty() {
            errs.push(ProvenanceError::NoArtifacts);
        }
        for a in &self.artifacts {
            if !is_sha256(&a.sha256) {
                errs.push(ProvenanceError::BadArtifactHash(a.file.clone()));
            }
        }

        // 沒有工具版本就無法重現匯出。
        for tool in ["python", "torch", "funasr"] {
            match self.tools.get(tool) {
                Some(v) if !v.starts_with('<') => {}
                _ => errs.push(ProvenanceError::MissingToolVersion(tool.into())),
            }
        }

        if errs.is_empty() { Ok(()) } else { Err(errs) }
    }

    /// 產出中的 ONNX 檔案。
    pub fn onnx_artifacts(&self) -> Vec<&Artifact> {
        self.artifacts
            .iter()
            .filter(|a| a.file.ends_with(".onnx"))
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn valid_json() -> String {
        format!(
            r#"{{
              "model_id": "paraformer-zh",
              "purpose": "中文 ASR 主力引擎",
              "capabilities": ["asr.zh"],
              "source": {{
                "host": "huggingface.co",
                "repo": "funasr/paraformer-zh",
                "revision": "7904416f6cb6290ee7dc0b2ddb2993a9fe4f421a",
                "url": "https://huggingface.co/funasr/paraformer-zh"
              }},
              "license": {{
                "evidence": "license_file",
                "file": "LICENSE",
                "url": "https://huggingface.co/funasr/paraformer-zh/raw/7904416/LICENSE",
                "sha256": "{h}",
                "bytes": 11357
              }},
              "exported_at_utc": "2026-09-12T10:00:00+00:00",
              "exported_by": "scripts/export-funasr-onnx.py",
              "tools": {{ "python": "3.14.6", "torch": "2.14.0", "funasr": "1.2.0" }},
              "artifacts": [
                {{ "file": "model.onnx", "sha256": "{h}", "bytes": 230686720 }}
              ],
              "note": "依 ADR-0006 自行匯出"
            }}"#,
            h = "a".repeat(64)
        )
    }

    fn parsed() -> Provenance {
        Provenance::parse(&valid_json()).unwrap()
    }

    #[test]
    fn accepts_a_complete_record() {
        assert!(parsed().validate().is_ok());
    }

    #[test]
    fn rejects_floating_revision() {
        // 用 main 的話，來源會浮動，整份紀錄就失去意義。
        let mut p = parsed();
        p.source.revision = "main".into();
        let errs = p.validate().unwrap_err();
        assert!(errs.contains(&ProvenanceError::FloatingRevision("main".into())));
    }

    #[test]
    fn rejects_tiny_license_file() {
        // silero 那次拿到的是 29 bytes 的 "Invalid username or password"。
        let mut p = parsed();
        if let LicenseEvidence::LicenseFile { bytes, .. } = &mut p.license {
            *bytes = 29;
        }
        assert!(
            p.validate()
                .unwrap_err()
                .contains(&ProvenanceError::SuspiciousLicenseSize(29))
        );
    }

    #[test]
    fn accepts_model_card_evidence_but_marks_it_weaker() {
        // ct-punc 的 repo 沒有 LICENSE 檔，只有 model card 標籤。
        let json = valid_json().replace(
            r#""evidence": "license_file",
                "file": "LICENSE",
                "url": "https://huggingface.co/funasr/paraformer-zh/raw/7904416/LICENSE",
                "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                "bytes": 11357"#,
            &format!(
                r#""evidence": "model_card_metadata",
                "declared_license": "apache-2.0",
                "url": "https://huggingface.co/api/models/funasr/ct-punc",
                "readme_url": "https://huggingface.co/funasr/ct-punc/raw/abc/README.md",
                "readme_sha256": "{h}",
                "sha256": "{h}",
                "bytes": 2090"#,
                h = "b".repeat(64)
            ),
        );
        let p = Provenance::parse(&json).expect("應能解析 model card 形式");
        assert!(p.validate().is_ok());
        assert!(!p.license.is_full_text(), "必須標記為較弱的證據");
        assert_eq!(p.license.declared(), Some("apache-2.0"));
    }

    #[test]
    fn full_text_evidence_is_marked_as_strongest() {
        assert!(parsed().license.is_full_text());
    }

    #[test]
    fn rejects_missing_tool_versions() {
        // 沒有工具版本就無法重現匯出，也就無法證明產出的來歷。
        let mut p = parsed();
        p.tools.remove("funasr");
        assert!(
            p.validate()
                .unwrap_err()
                .contains(&ProvenanceError::MissingToolVersion("funasr".into()))
        );
    }

    #[test]
    fn rejects_unavailable_tool_placeholder() {
        let mut p = parsed();
        p.tools
            .insert("torch".into(), "<unavailable: no module>".into());
        assert!(
            p.validate()
                .unwrap_err()
                .contains(&ProvenanceError::MissingToolVersion("torch".into()))
        );
    }

    #[test]
    fn rejects_empty_artifacts() {
        let mut p = parsed();
        p.artifacts.clear();
        assert!(
            p.validate()
                .unwrap_err()
                .contains(&ProvenanceError::NoArtifacts)
        );
    }

    #[test]
    fn rejects_malformed_hashes() {
        let mut p = parsed();
        if let LicenseEvidence::LicenseFile { sha256, .. } = &mut p.license {
            *sha256 = "SHORT".into();
        }
        p.artifacts[0].sha256 = "A".repeat(64); // 大寫也不接受
        let errs = p.validate().unwrap_err();
        assert_eq!(errs.len(), 2);
    }

    #[test]
    fn reports_every_problem_at_once() {
        // 一次修完比修一個再跑一次快。
        let mut p = parsed();
        p.source.revision = "main".into();
        if let LicenseEvidence::LicenseFile { bytes, .. } = &mut p.license {
            *bytes = 10;
        }
        p.artifacts.clear();
        assert!(p.validate().unwrap_err().len() >= 3);
    }

    #[test]
    fn finds_onnx_artifacts() {
        let mut p = parsed();
        p.artifacts.push(Artifact {
            file: "config.yaml".into(),
            sha256: "b".repeat(64),
            bytes: 100,
        });
        assert_eq!(p.onnx_artifacts().len(), 1);
        assert_eq!(p.onnx_artifacts()[0].file, "model.onnx");
    }

    #[test]
    fn rejects_invalid_json() {
        assert!(Provenance::parse("{ nope").is_err());
    }
}
