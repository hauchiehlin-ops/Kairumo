//! 驗證專案實際使用的 `models/manifest.json`。
//!
//! 這個測試把文件與程式綁在一起：清單寫錯、URL 用了 http、或忘了填雜湊，
//! CI 就會擋下來，而不是等到使用者下載失敗才發現。

use padnote_models::{DownloadError, Downloader, Fetcher, ModelCatalog, RangeRequest};

fn manifest() -> ModelCatalog {
    let path = concat!(env!("CARGO_MANIFEST_DIR"), "/../../models/manifest.json");
    let text = std::fs::read_to_string(path).expect("models/manifest.json 必須存在");
    ModelCatalog::parse(&text).expect("models/manifest.json 必須是合法 JSON")
}

#[test]
fn manifest_parses_and_has_entries() {
    let c = manifest();
    assert!(c.models.len() >= 5, "清單不該是空的");
    assert!(c.get("silero-vad").is_some());
    assert!(c.get("qwen3-4b-instruct-q4").is_some());
}

#[test]
fn every_url_is_https() {
    for m in &manifest().models {
        assert!(
            m.url.starts_with("https://"),
            "{} 使用了非 HTTPS 的來源：{}",
            m.id,
            m.url
        );
    }
}

#[test]
fn every_entry_declares_a_size_and_capability() {
    for m in &manifest().models {
        assert!(m.size_bytes > 0, "{} 未宣告大小", m.id);
        assert!(!m.required_for.is_empty(), "{} 未宣告用途", m.id);
        assert!(!m.license.is_empty(), "{} 未宣告授權", m.id);
    }
}

#[test]
fn pending_hashes_block_download_instead_of_passing_silently() {
    // 本測試最重要的一條：尚未確認雜湊的模型必須**下載不下來**，
    // 而不是靜默通過然後載入一個來路不明的檔案。
    struct NeverCalled;
    impl Fetcher for NeverCalled {
        fn fetch(&self, _: &RangeRequest) -> Result<Vec<u8>, String> {
            panic!("雜湊未確認的模型不該發出網路請求");
        }
    }

    let c = manifest();
    let pending: Vec<String> = c.malformed().iter().map(|m| m.id.clone()).collect();
    assert!(
        !pending.is_empty(),
        "目前應仍有待確認的雜湊（見 TODO.md H3）"
    );

    let d = Downloader::new(std::env::temp_dir().join("padnote-manifest-test"));
    for id in &pending {
        let entry = c.get(id).unwrap();
        assert!(
            matches!(
                d.download(entry, &NeverCalled),
                Err(DownloadError::Malformed(_))
            ),
            "{id} 的雜湊未確認，必須被拒絕"
        );
    }
}

#[test]
fn capabilities_referenced_by_the_app_are_covered() {
    // 程式裡用到的能力字串必須在清單裡找得到對應模型，
    // 否則使用者會看到「需要下載模型」卻沒有東西可下載。
    let c = manifest();
    for capability in ["asr.zh", "asr.multilingual", "ocr", "llm.summary"] {
        assert!(
            !c.for_capability(capability).is_empty(),
            "能力 {capability} 沒有對應的模型"
        );
    }
}
