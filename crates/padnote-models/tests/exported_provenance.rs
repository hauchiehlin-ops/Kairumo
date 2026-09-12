//! 驗證 `models/exported/` 下自行匯出模型的來源紀錄（ADR-0006 / D-07）。
//!
//! 模型檔本身不入版控（太大），但 **`PROVENANCE.json` 必須入版控** ——
//! 它是授權主張的證據，也是下游核對的依據。
//!
//! 目錄不存在時測試跳過：不是每個開發者都需要跑匯出。

use padnote_models::Provenance;

fn exported_dir() -> std::path::PathBuf {
    std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../models/exported")
}

fn provenances() -> Vec<(String, Provenance)> {
    let dir = exported_dir();
    if !dir.exists() {
        return Vec::new();
    }
    std::fs::read_dir(&dir)
        .unwrap()
        .filter_map(Result::ok)
        .filter_map(|e| {
            let p = e.path().join("PROVENANCE.json");
            p.exists().then(|| {
                let text = std::fs::read_to_string(&p).unwrap();
                (
                    e.file_name().to_string_lossy().into_owned(),
                    Provenance::parse(&text).unwrap_or_else(|err| {
                        panic!("{} 的 PROVENANCE.json 解析失敗：{err}", e.path().display())
                    }),
                )
            })
        })
        .collect()
}

#[test]
fn every_exported_model_has_a_valid_provenance_record() {
    for (name, p) in provenances() {
        if let Err(errs) = p.validate() {
            panic!("{name} 的來源紀錄不完整：{errs:?}");
        }
    }
}

#[test]
fn revisions_are_pinned_to_real_commits() {
    // 用 main 的話來源會浮動，整份紀錄就失去意義。
    for (name, p) in provenances() {
        assert_eq!(
            p.source.revision.len(),
            40,
            "{name} 的 revision 不是完整的 commit sha：{}",
            p.source.revision
        );
        assert!(
            p.source.revision.chars().all(|c| c.is_ascii_hexdigit()),
            "{name} 的 revision 格式錯誤"
        );
    }
}

#[test]
fn every_model_produced_onnx() {
    for (name, p) in provenances() {
        assert!(!p.onnx_artifacts().is_empty(), "{name} 沒有產出任何 ONNX");
    }
}

#[test]
fn license_evidence_strength_is_recorded() {
    // 三個 funasr repo 中只有 paraformer-zh-streaming 內含完整 LICENSE 檔；
    // 其餘只有 model card 的標籤。強度差異必須被記錄，不能一視同仁。
    for (name, _) in provenances() {
        let raw =
            std::fs::read_to_string(exported_dir().join(&name).join("PROVENANCE.json")).unwrap();
        assert!(raw.contains("\"evidence\""), "{name} 未記錄授權證據的種類");
        assert!(
            raw.contains("license_file") || raw.contains("model_card_metadata"),
            "{name} 的授權證據種類不在已知範圍內"
        );
    }
}
