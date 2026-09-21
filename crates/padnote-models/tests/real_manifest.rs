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
    assert!(c.get("silero-vad-v4").is_some());
    assert!(c.get("qwen3-4b-instruct-q4").is_some());
}

/// 已確認的項目必須真的能下載且雜湊相符。
///
/// 這條測試的由來：原本 silero-vad 的 URL 指向一個需要登入的 HuggingFace
/// 路徑，`curl` 只拿到 29 bytes 的 "Invalid username or password"。
/// 清單裡的 URL 沒被驗證過就等於沒有。
#[test]
fn confirmed_entries_declare_a_real_hash_and_size() {
    for m in manifest().models.iter().filter(|m| m.sha256 != "pending") {
        assert_eq!(m.sha256.len(), 64, "{} 的雜湊長度錯誤", m.id);
        assert!(
            m.size_bytes > 1000,
            "{} 的大小看起來不對：{}",
            m.id,
            m.size_bytes
        );
        assert_ne!(m.license, "pending-review", "{} 已有雜湊卻未確認授權", m.id);
    }
}

#[test]
fn every_url_is_https_or_explicitly_absent() {
    // 空字串代表「還沒有可用的來源」——那是一個**經過查證**的狀態，
    // 而且下載器會拒絕它（`is_well_formed` 要求 https）。
    //
    // 比起留著一個假網址（例如曾經寫過的 `huggingface.co/example/rapidocr`），
    // 空字串誠實得多：假網址會讓人以為只是暫時連不上，而它根本不存在。
    for m in &manifest().models {
        if m.url.is_empty() {
            assert!(
                !m.notes.is_empty(),
                "{} 沒有來源，就必須在 notes 裡說明查證結果",
                m.id
            );
            continue;
        }
        assert!(
            m.url.starts_with("https://"),
            "{} 使用了非 HTTPS 的來源：{}",
            m.id,
            m.url
        );
    }
}

#[test]
fn an_entry_with_a_real_hash_also_has_a_real_url() {
    // 有雜湊卻沒有來源 = 一個永遠下載不了、但看起來可以下載的項目。
    for m in &manifest().models {
        if m.sha256.len() == 64 {
            assert!(
                m.url.starts_with("https://"),
                "{} 有雜湊卻沒有下載來源",
                m.id
            );
        }
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
    for capability in ["asr.zh", "asr.multilingual", "ocr", "llm.summary", "vad"] {
        assert!(
            !c.for_capability(capability).is_empty(),
            "能力 {capability} 沒有對應的模型"
        );
    }
}

#[test]
fn the_default_asr_model_is_the_one_with_a_clean_licence() {
    // 決策 D-07：預設走 Whisper（MIT、單一通路），不是 Paraformer + ct-punc。
    //
    // 這條測試釘住的不是「哪個模型比較好」，而是**預設不會悄悄漂回去**。
    // `ffi.rs` 裡那個常數改掉、或清單裡的 `optional` 被拿掉，都會在這裡紅。
    let c = manifest();
    let default_id = padnote_models::DEFAULT_ASR_MODEL;

    let entry = c
        .get(default_id)
        .unwrap_or_else(|| panic!("預設的語音辨識模型 {default_id} 不在清單裡"));

    assert!(
        entry.license.contains("MIT"),
        "預設模型 {default_id} 的授權是「{}」—— D-07 要的是單一通路、沒有爭議的授權",
        entry.license
    );
    assert!(
        entry.required_for.iter().any(|c| c == "asr.zh"),
        "預設模型要能做中文，否則中文使用者還是會被導去 Paraformer"
    );

    // 授權有爭議的那兩個必須是選用的 —— 不是選用的話，
    // 使用者第一次開錄音就會被要求下載它們。
    for id in ["paraformer-zh", "ct-punct-zh"] {
        let e = c.get(id).unwrap_or_else(|| panic!("{id} 不在清單裡"));
        assert!(
            e.optional,
            "{id} 的授權有雙通路衝突（見 models/LICENSE-AUDIT.md），不能是預設要下載的"
        );
    }
}
