//! 模型下載的平台介面（A2，決策 D4）。
//!
//! # 為什麼這一層一直是空的
//!
//! `padnote-models` 早就把清單、SHA-256 驗證、斷點續傳、刪除都寫完了
//! （`docs/TODO.md` 的 S-14），但**沒有任何 `#[uniffi::export]`** ——
//! 於是兩個平台都沒有下載入口，而所有需要模型的功能就一直走降級路徑：
//! Apple 的轉錄永遠退回系統聽寫，Android 的轉錄根本是個空殼。
//!
//! # HTTP 由平台出，與 Drive 同一個判斷
//!
//! 理由寫在 `ffi_gdrive`：把 HTTP 堆疊連進核心會讓行動端的函式庫多幾 MB，
//! 而平台的網路堆疊帶著 Proxy、VPN、憑證釘選與背景傳輸。
//! 這裡只要一個「從第 N 個位元組開始拿」的方法 —— 續傳、驗證、
//! 落地改名全部留在核心。
//!
//! # 清單是編譯進來的
//!
//! `models/manifest.json` 用 `include_str!` 內嵌，不是隨 App 打包的資源檔。
//! 兩個平台因此拿到**逐位元組相同**的清單；各自打包一份的話，
//! 遲早會有一邊忘了更新，而症狀是「同一個模型在兩台裝置上大小不一樣」。

use std::sync::Arc;

/// 內嵌的模型清單。
const MANIFEST_JSON: &str = include_str!("../../../models/manifest.json");

/// 平台要實作的下載器。
///
/// 只有一個方法：從 `from` 這個位元組開始拿一段回來。**可以只回一部分** ——
/// 續傳邏輯在核心，回傳多少都不會弄壞進度。
#[uniffi::export(with_foreign)]
pub trait FfiModelFetcher: Send + Sync {
    /// 取回從 `from` 起的位元組。回空陣列表示這一輪拿不到（留著進度下次再來）。
    fn fetch(&self, url: String, from: u64) -> Result<Vec<u8>, FfiModelError>;

    /// 伺服器支不支援 Range 請求。不支援時核心會從頭下載。
    fn supports_range(&self) -> bool;
}

#[derive(Clone, Debug, thiserror::Error, uniffi::Error)]
pub enum FfiModelError {
    #[error("網路錯誤：{detail}")]
    Network { detail: String },
}

struct ForeignFetcher(Arc<dyn FfiModelFetcher>);

impl padnote_models::download::Fetcher for ForeignFetcher {
    fn fetch(&self, req: &padnote_models::download::RangeRequest) -> Result<Vec<u8>, String> {
        self.0
            .fetch(req.url.clone(), req.from)
            .map_err(|e| e.to_string())
    }

    fn supports_range(&self) -> bool {
        self.0.supports_range()
    }
}

/// 清單上的一個模型。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiModelInfo {
    pub id: String,
    /// 位元組數。清單上的值是**宣告**，下載完會與實際比對。
    pub size_bytes: u64,
    pub license: String,
    /// 這個模型讓哪些能力可用（`asr.zh`、`ocr`、`llm.summary`…）。
    pub required_for: Vec<String>,
    /// 可選的模型：沒有它主要功能仍然能用。
    pub optional: bool,
    pub notes: String,
    /// **這一筆現在可不可以下載。**
    ///
    /// 清單裡雜湊還是 `pending`、或沒有下載網址的項目一律是 false ——
    /// 下載器本來就會拒絕它們，UI 要在按下去之前就講清楚，
    /// 而不是讓使用者等半天再看到一句「模型清單格式錯誤」。
    pub downloadable: bool,
    /// 已經下載好、雜湊也驗過了。
    pub ready: bool,
    /// 已經下載了幾個位元組（續傳用）。
    pub downloaded_bytes: u64,
}

fn catalog() -> padnote_models::catalog::ModelCatalog {
    padnote_models::catalog::ModelCatalog::parse(MANIFEST_JSON).unwrap_or_default()
}

/// 清單上的全部模型，附上這台裝置的下載狀態。
///
/// `root` 是模型要放的目錄（平台自己決定，通常是 App 的私有空間）。
#[uniffi::export]
pub fn model_catalog(root: String) -> Vec<FfiModelInfo> {
    let downloader = padnote_models::download::Downloader::new(&root);
    catalog()
        .models
        .iter()
        .map(|entry| {
            let state = downloader.state(entry);
            FfiModelInfo {
                id: entry.id.clone(),
                size_bytes: entry.size_bytes,
                license: entry.license.clone(),
                required_for: entry.required_for.clone(),
                optional: entry.optional,
                notes: entry.notes.clone(),
                downloadable: entry.is_well_formed(),
                ready: matches!(state, padnote_models::download::DownloadState::Complete),
                downloaded_bytes: match state {
                    padnote_models::download::DownloadState::Partial { downloaded } => downloaded,
                    padnote_models::download::DownloadState::Complete => entry.size_bytes,
                    _ => 0,
                },
            }
        })
        .collect()
}

/// 某個模型在這台裝置上的檔案路徑。**不保證它存在**（先問 `model_catalog`）。
#[uniffi::export]
pub fn model_path(root: String, id: String) -> String {
    padnote_models::download::Downloader::new(&root)
        .model_path(&id)
        .to_string_lossy()
        .into_owned()
}

/// 一次下載的結果。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiModelDownloadResult {
    /// 完成了（檔案已驗證雜湊並改名）。
    pub ok: bool,
    /// 還沒完成，但進度有保住 —— 呼叫端可以稍後再叫一次繼續。
    pub incomplete: bool,
    pub path: String,
    pub error: String,
}

/// 下載（或續傳）一個模型。
///
/// **會同步地等平台的 HTTP 回來，不要在主執行緒呼叫。**
///
/// 雜湊不符時檔案會被刪掉並回報錯誤 —— 留著一個壞掉的模型，
/// 只會在載入時才炸，而那時候使用者已經等完整個下載了。
#[uniffi::export]
pub fn model_download(
    root: String,
    id: String,
    fetcher: Arc<dyn FfiModelFetcher>,
) -> FfiModelDownloadResult {
    let catalog = catalog();
    let Some(entry) = catalog.get(&id) else {
        return FfiModelDownloadResult {
            ok: false,
            incomplete: false,
            path: String::new(),
            error: format!("清單裡沒有這個模型：{id}"),
        };
    };
    let downloader = padnote_models::download::Downloader::new(&root);
    match downloader.download(entry, &ForeignFetcher(fetcher)) {
        Ok(Some(path)) => FfiModelDownloadResult {
            ok: true,
            incomplete: false,
            path: path.to_string_lossy().into_owned(),
            error: String::new(),
        },
        // 伺服器這一輪沒給資料：進度保住了，不是失敗。
        Ok(None) => FfiModelDownloadResult {
            ok: false,
            incomplete: true,
            path: String::new(),
            error: String::new(),
        },
        Err(e) => FfiModelDownloadResult {
            ok: false,
            incomplete: false,
            path: String::new(),
            error: e.to_string(),
        },
    }
}

/// 刪掉一個已下載的模型（含未完成的暫存）。
#[uniffi::export]
pub fn model_remove(root: String, id: String) -> bool {
    padnote_models::download::Downloader::new(&root)
        .remove(&id)
        .is_ok()
}

/// 模型佔了多少磁碟空間。
#[uniffi::export]
pub fn model_disk_usage(root: String) -> u64 {
    padnote_models::download::Downloader::new(&root).disk_usage()
}

/// 某一項能力現在有沒有模型可用（例如 `asr.zh`）。
///
/// 畫面用它決定要顯示「開始轉錄」還是「需要先下載模型」——
/// **不要在按下去之後才發現沒有模型**，那時候使用者已經在等了。
#[uniffi::export]
pub fn model_capability_ready(root: String, capability: String) -> bool {
    let downloader = padnote_models::download::Downloader::new(&root);
    catalog()
        .for_capability(&capability)
        .into_iter()
        .filter(|e| !e.optional)
        .any(|e| downloader.is_ready(e))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_embedded_manifest_parses() {
        // 清單是 `include_str!` 進來的，壞掉的話是**編譯期就該知道**的事，
        // 而不是在使用者按下下載時才變成一份空清單。
        let parsed = padnote_models::catalog::ModelCatalog::parse(MANIFEST_JSON);
        assert!(parsed.is_ok(), "內嵌的 models/manifest.json 解析失敗");
        assert!(!parsed.unwrap().models.is_empty());
    }

    #[test]
    fn entries_without_a_real_hash_are_not_offered_for_download() {
        // 雜湊還是 `pending` 的項目，下載器本來就會拒絕。
        // UI 要在按下去**之前**就知道，而不是讓使用者等半天再看到
        // 一句「模型清單格式錯誤」。
        let root = std::env::temp_dir().join(format!("padnote-models-{}", std::process::id()));
        let all = model_catalog(root.to_string_lossy().into());
        assert!(!all.is_empty());
        for info in &all {
            let entry = catalog().get(&info.id).cloned().expect("清單裡該有");
            assert_eq!(info.downloadable, entry.is_well_formed(), "{}", info.id);
        }
    }

    #[test]
    fn an_unknown_model_is_an_error_not_a_panic() {
        #[derive(Debug)]
        struct Never;
        impl FfiModelFetcher for Never {
            fn fetch(&self, _url: String, _from: u64) -> Result<Vec<u8>, FfiModelError> {
                Ok(Vec::new())
            }
            fn supports_range(&self) -> bool {
                true
            }
        }
        let result = model_download(
            std::env::temp_dir().to_string_lossy().into(),
            "no-such-model".into(),
            Arc::new(Never),
        );
        assert!(!result.ok);
        assert!(result.error.contains("no-such-model"));
    }

    #[test]
    fn a_capability_with_no_downloaded_model_is_not_ready() {
        let root = std::env::temp_dir().join(format!("padnote-cap-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        assert!(!model_capability_ready(
            root.to_string_lossy().into(),
            "asr.zh".into()
        ));
    }
}
