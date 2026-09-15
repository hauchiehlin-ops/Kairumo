//! 把中繼資料同步到 Google Drive（G-01 收尾，ADR-0011）。
//!
//! 這一層把前面幾塊接起來：`GoogleAuth` 拿到的 access token、
//! `GDriveProvider` 的檔案存取、以及 `settings` / `library` 的合併規則。
//!
//! # HTTP 由平台出，不是核心
//!
//! 一開始是核心直接用 `reqwest` 打網路。那會把整個 rustls 堆疊連進行動端的
//! 函式庫 —— `libpadnote_core.so` 從 8.1 MB 變成 13 MB，每個 ABI 都多 5 MB。
//!
//! 而且那與協同編輯那邊的判斷不一致：`ffi_collab` 已經定下「協定與密碼學在
//! 核心，socket 留在平台層」。HTTP 也一樣是平台的事 —— 平台的網路堆疊還帶著
//! Proxy 設定、VPN、憑證釘選與背景傳輸，那些是 reqwest 拿不到的。
//!
//! 所以這裡走 [`FfiDriveHttp`]：平台實作四個很薄的 HTTP 方法，
//! **查詢字串、分頁、合併規則全部留在核心**（那才是會出錯的地方，也是有測試的地方）。
//!
//! # 兩層：中繼資料與內容
//!
//! - [`gdrive_sync_metadata`]：設定與筆記本清單（`settings/global.json`、
//!   `notebooks/index.json`）。整包讀寫、逐欄位合併。
//! - [`gdrive_sync_notebook`]：一本筆記本的**內容**，以 oplog 檔為單位。
//!
//! # 內容為什麼用 oplog 檔當同步單位，而不是 chunk
//!
//! `doc/ops/<lamport:016x>-<device:08x>.oplog` 這個檔名已經把該有的性質
//! 全部編進去了：
//!
//! - **唯一**：裝置 id 在檔名裡，兩台裝置永遠不會寫同一個檔。
//! - **不可變**：寫完就不再改（同一個 lamport 不會重複使用）。
//! - **有序**：字典序即因果序，下載完照檔名排就是套用順序。
//! - **冪等**：同一個檔名永遠是同一份內容，重複同步覆寫即可。
//!
//! 換句話說，它本來就是一個設計好的同步單位。再包一層 chunk 只是把
//! 「哪些還沒傳」這個問題換個地方問，而且要自己處理框架、序號與游標。
//!
//! `SyncEngine` 的 chunk 那條路仍然在（`sync/<device>/log-N.bin`），
//! 給的是**跨筆記本的增量串流**；這裡走的是逐本筆記的檔案鏡像。
//!
//! # 併發：會收斂，但不是原子的
//!
//! 流程是「讀 → 合併 → 寫」。兩台裝置同時做的話，後寫的那個會蓋掉前一個 ——
//! 前者的改動**不會消失**，因為它本機還留著，下一次同步會再推上去。
//! 所以最終會收斂，但中間可能需要多跑一輪。
//!
//! Drive 沒有條件寫入（if-match），要做到原子就得引入鎖檔，而鎖檔在
//! 離線優先的架構裡是另一類麻煩（誰來解鎖一個再也不會上線的裝置？）。
//! 這個取捨寫在這裡，不要在別處各自重新發明。

use std::sync::Arc;

use padnote_sync::gdrive::{DriveHttp, GDriveProvider};
use padnote_sync::library::{INDEX_PATH, LibraryIndex};
use padnote_sync::provider::{CloudProvider, SyncError};
use padnote_sync::settings::{SETTINGS_PATH, SyncedSettings};

/// 平台要實作的 HTTP。
///
/// 只有四個方法，而且都很薄 —— 帶上 `Authorization: Bearer <token>`、送出去、
/// 把回應原樣交回來。**不要在這裡判斷任何 Drive 的語意**：狀態碼怎麼對應到
/// 錯誤、回應怎麼解析、分頁怎麼跟，全部在核心。
///
/// 錯誤分類很重要：401/403 要回 `PermissionDenied`（上層據此要求重新登入），
/// 404 回 `NotFound`（第一次同步時檔案本來就不存在，那不是錯誤），
/// 其餘回 `Backend`。混在一起的話，使用者會在「該重新登入」時看到
/// 一句沒有用的「同步失敗」。
#[uniffi::export(with_foreign)]
pub trait FfiDriveHttp: Send + Sync {
    /// GET，回應是 JSON 字串。`query` 是已經拆好的參數，平台負責 URL 編碼。
    fn get_json(&self, url: String, query: Vec<FfiQueryParam>) -> Result<String, FfiDriveError>;
    /// GET 原始位元組。`range` 為 None 表示整個檔案。
    fn get_bytes(&self, url: String, range: Option<FfiByteRange>) -> Result<Vec<u8>, FfiDriveError>;
    /// POST 一段 JSON，回應也是 JSON 字串。
    fn post_json(&self, url: String, body_json: String) -> Result<String, FfiDriveError>;
    /// PATCH 原始位元組（上傳檔案內容）。
    fn patch_bytes(&self, url: String, data: Vec<u8>) -> Result<(), FfiDriveError>;
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiQueryParam {
    pub name: String,
    pub value: String,
}

/// 半開區間 `[start, end)`。
///
/// HTTP 的 Range 標頭是**閉區間**，平台層送出去時尾端要減一 ——
/// 少減那個 1 會每次多拉一個位元組，而框架化的 chunk 會因此對不齊。
#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct FfiByteRange {
    pub start: u64,
    pub end: u64,
}

/// 平台回報的錯誤種類。
#[derive(Clone, Debug, thiserror::Error, uniffi::Error)]
pub enum FfiDriveError {
    /// 檔案不存在（HTTP 404）。第一次同步時是正常狀態。
    #[error("找不到：{path}")]
    NotFound { path: String },
    /// 權杖無效或權限不足（HTTP 401/403）。要重新登入。
    #[error("權限不足：{detail}")]
    PermissionDenied { detail: String },
    /// 其他（網路不通、5xx、回應解析失敗）。重試即可。
    #[error("網路或伺服器錯誤：{detail}")]
    Backend { detail: String },
}

impl From<FfiDriveError> for SyncError {
    fn from(error: FfiDriveError) -> Self {
        match error {
            FfiDriveError::NotFound { path } => SyncError::NotFound(path),
            FfiDriveError::PermissionDenied { detail } => SyncError::PermissionDenied(detail),
            FfiDriveError::Backend { detail } => SyncError::Backend(detail),
        }
    }
}

/// 把平台的 HTTP 接成核心 `DriveHttp` 的樣子。
struct ForeignHttp(Arc<dyn FfiDriveHttp>);

impl std::fmt::Debug for ForeignHttp {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        // 不要印內容 —— 平台那邊的物件帶著存取權杖。
        f.debug_struct("ForeignHttp").finish_non_exhaustive()
    }
}

impl DriveHttp for ForeignHttp {
    fn get_json(
        &self,
        url: &str,
        query: &[(String, String)],
    ) -> Result<serde_json::Value, SyncError> {
        let params = query
            .iter()
            .map(|(name, value)| FfiQueryParam {
                name: name.clone(),
                value: value.clone(),
            })
            .collect();
        let text = self.0.get_json(url.to_string(), params)?;
        serde_json::from_str(&text)
            .map_err(|e| SyncError::Backend(format!("Drive 回應不是合法 JSON：{e}")))
    }

    fn get_bytes(
        &self,
        url: &str,
        range: Option<std::ops::Range<u64>>,
    ) -> Result<Vec<u8>, SyncError> {
        let range = range.map(|r| FfiByteRange {
            start: r.start,
            end: r.end,
        });
        Ok(self.0.get_bytes(url.to_string(), range)?)
    }

    fn post_json(&self, url: &str, body: &serde_json::Value) -> Result<serde_json::Value, SyncError> {
        let text = self.0.post_json(url.to_string(), body.to_string())?;
        serde_json::from_str(&text)
            .map_err(|e| SyncError::Backend(format!("Drive 回應不是合法 JSON：{e}")))
    }

    fn patch_bytes(&self, url: &str, data: &[u8]) -> Result<(), SyncError> {
        Ok(self.0.patch_bytes(url.to_string(), data.to_vec())?)
    }
}

/// 一次同步的結果。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCloudSyncResult {
    pub ok: bool,
    /// 合併後的設定 JSON。平台層要存回去 —— 雲端那邊可能有別台裝置的改動。
    pub settings_json: String,
    /// 合併後的索引 JSON。
    pub index_json: String,
    /// 失敗原因（給日誌看，不是給使用者看的文案）。
    pub error: String,
    /// true 表示**要請使用者重新登入**，不是「等一下再試」。
    ///
    /// 與網路錯誤分開：後者重試就好，前者重試一百次也一樣。混在一起會變成
    /// 無限重試的背景迴圈，而使用者只看到「同步失敗」卻不知道該去登入。
    pub needs_reauth: bool,
}

impl FfiCloudSyncResult {
    fn failed(settings: String, index: String, error: SyncError) -> Self {
        let needs_reauth = matches!(error, SyncError::PermissionDenied(_));
        Self {
            ok: false,
            settings_json: settings,
            index_json: index,
            error: error.to_string(),
            needs_reauth,
        }
    }
}

/// 合併之後要不要上傳。
///
/// 分出來是為了測得到：真正的判斷（合併規則、要不要寫回去）不接網路就驗得了，
/// 但寫死在同步函式裡就一行都測不到。
fn merge_settings(local: &str, remote: &str) -> (String, bool) {
    let mut merged = SyncedSettings::from_json(local);
    merged.merge(&SyncedSettings::from_json(remote));
    let merged_json = merged.to_json();
    // 與雲端已經一樣就不要上傳。每次同步都寫一次的話，Drive 上的修改時間
    // 一直在變，而使用者會在 Google 的活動紀錄裡看到一堆沒有意義的寫入。
    let needs_upload = merged_json != SyncedSettings::from_json(remote).to_json();
    (merged_json, needs_upload)
}

fn merge_index(local: &str, remote: &str) -> (String, bool) {
    let mut merged = LibraryIndex::from_json(local);
    merged.merge(&LibraryIndex::from_json(remote));
    let merged_json = merged.to_json();
    let needs_upload = merged_json != LibraryIndex::from_json(remote).to_json();
    (merged_json, needs_upload)
}

/// 讀雲端上的一個檔案。**還沒建立**時回空字串，不是錯誤。
///
/// 第一次同步時這兩個檔案都不存在，那是正常狀態；當成錯誤的話，
/// 新裝置第一次登入就會看到「同步失敗」。
fn read_or_empty<H: padnote_sync::gdrive::DriveHttp>(
    drive: &GDriveProvider<H>,
    path: &str,
) -> Result<String, SyncError> {
    match drive.get_all(path) {
        Ok(bytes) => Ok(String::from_utf8_lossy(&bytes).into_owned()),
        Err(SyncError::NotFound(_)) => Ok(String::new()),
        Err(other) => Err(other),
    }
}

/// 把設定與筆記本索引與雲端同步一輪。
///
/// `http` 由平台提供，裡面已經帶好 `GoogleAuth` 給的存取權杖
/// （必要時它會自己先更新）。
///
/// **這個函式會同步地等平台的 HTTP 回來，不要在主執行緒呼叫。**
#[uniffi::export]
pub fn gdrive_sync_metadata(
    http: Arc<dyn FfiDriveHttp>,
    local_settings_json: String,
    local_index_json: String,
) -> FfiCloudSyncResult {
    let drive = GDriveProvider::new(ForeignHttp(http));

    let remote_settings = match read_or_empty(&drive, SETTINGS_PATH) {
        Ok(v) => v,
        Err(e) => return FfiCloudSyncResult::failed(local_settings_json, local_index_json, e),
    };
    let remote_index = match read_or_empty(&drive, INDEX_PATH) {
        Ok(v) => v,
        Err(e) => return FfiCloudSyncResult::failed(local_settings_json, local_index_json, e),
    };

    let (merged_settings, push_settings) = merge_settings(&local_settings_json, &remote_settings);
    let (merged_index, push_index) = merge_index(&local_index_json, &remote_index);

    if push_settings {
        if let Err(e) = drive.put(SETTINGS_PATH, merged_settings.as_bytes()) {
            return FfiCloudSyncResult::failed(merged_settings, merged_index, e);
        }
    }
    if push_index {
        if let Err(e) = drive.put(INDEX_PATH, merged_index.as_bytes()) {
            return FfiCloudSyncResult::failed(merged_settings, merged_index, e);
        }
    }

    FfiCloudSyncResult {
        ok: true,
        settings_json: merged_settings,
        index_json: merged_index,
        error: String::new(),
        needs_reauth: false,
    }
}

// ── 筆記本內容（oplog 檔鏡像）────────────────────────────────────

/// 一本筆記本的雲端 oplog 目錄。
fn notebook_ops_prefix(notebook_id: &str) -> String {
    format!("notebooks/{notebook_id}/doc/ops")
}

/// 一次筆記本同步的結果。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiNotebookSyncResult {
    pub ok: bool,
    /// 這次上傳了幾個 oplog 檔。
    pub uploaded: u32,
    /// 這次下載了幾個。**大於 0 表示本機內容有變，呼叫端要重開 session**
    /// —— 不重開的話，畫面上還是同步前的樣子，使用者會以為同步沒作用。
    pub downloaded: u32,
    pub error: String,
    pub needs_reauth: bool,
}

/// 同步一本筆記本的內容。
///
/// `package_path` 是本機 `.padnote` 套件的路徑。
///
/// **這個函式會同步地等平台的 HTTP 回來，不要在主執行緒呼叫。**
#[uniffi::export]
pub fn gdrive_sync_notebook(
    http: Arc<dyn FfiDriveHttp>,
    package_path: String,
    notebook_id: String,
) -> FfiNotebookSyncResult {
    let package = match padnote_storage::NotebookPackage::open(std::path::Path::new(&package_path)) {
        Ok(p) => p,
        Err(e) => return notebook_failed(format!("開不了套件：{e}")),
    };
    let local = match package.doc_op_files() {
        Ok(files) => files,
        Err(e) => return notebook_failed(format!("讀不到本機 oplog：{e}")),
    };

    let drive = GDriveProvider::new(ForeignHttp(http));
    let prefix = notebook_ops_prefix(&notebook_id);

    let remote = match drive.list(&prefix) {
        Ok(entries) => entries,
        Err(e) => return from_sync_error(e),
    };
    let remote_by_name: std::collections::BTreeMap<String, u64> = remote
        .into_iter()
        .filter_map(|e| {
            let name = e.path.rsplit('/').next()?.to_string();
            Some((name, e.size))
        })
        .collect();

    // 上傳：雲端沒有的，或者本機這一份比較長的。
    //
    // 比長度而不是只看「有沒有」：`append_doc_ops` 在同一個 lamport 上是
    // **追加**，所以一個已經上傳過的檔仍然可能變長。只看存在與否的話，
    // 後面追加的那幾筆操作永遠傳不出去。
    let mut uploaded = 0u32;
    for (name, size) in &local {
        let remote_size = remote_by_name.get(name).copied().unwrap_or(0);
        if *size <= remote_size {
            continue;
        }
        let bytes = match package.read_doc_op_file(name) {
            Ok(b) => b,
            Err(e) => return notebook_failed(format!("讀不到 {name}：{e}")),
        };
        if let Err(e) = drive.put(&format!("{prefix}/{name}"), &bytes) {
            return from_sync_error(e);
        }
        uploaded += 1;
    }

    // 下載：本機沒有的，或者雲端那一份比較長的。
    let local_by_name: std::collections::BTreeMap<&str, u64> =
        local.iter().map(|(n, s)| (n.as_str(), *s)).collect();
    let mut downloaded = 0u32;
    for (name, remote_size) in &remote_by_name {
        let local_size = local_by_name.get(name.as_str()).copied().unwrap_or(0);
        if *remote_size <= local_size {
            continue;
        }
        let bytes = match drive.get_all(&format!("{prefix}/{name}")) {
            Ok(b) => b,
            Err(e) => return from_sync_error(e),
        };
        // 檔名來自雲端，是不可信輸入 —— `write_doc_op_file` 會擋掉
        // 路徑逃逸（`../`）之類的名字。
        if let Err(e) = package.write_doc_op_file(name, &bytes) {
            return notebook_failed(format!("寫不進 {name}：{e}"));
        }
        downloaded += 1;
    }

    FfiNotebookSyncResult {
        ok: true,
        uploaded,
        downloaded,
        error: String::new(),
        needs_reauth: false,
    }
}

fn notebook_failed(error: String) -> FfiNotebookSyncResult {
    FfiNotebookSyncResult {
        ok: false,
        uploaded: 0,
        downloaded: 0,
        error,
        needs_reauth: false,
    }
}

fn from_sync_error(error: SyncError) -> FfiNotebookSyncResult {
    let needs_reauth = matches!(error, SyncError::PermissionDenied(_));
    FfiNotebookSyncResult {
        ok: false,
        uploaded: 0,
        downloaded: 0,
        error: error.to_string(),
        needs_reauth,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ffi_account_sync::{
        FfiLibraryItem, FfiSyncedField, sync_delete_item, sync_set_setting, sync_upsert_item,
    };

    fn item(id: &str, title: &str, lamport: u64, device: &str) -> FfiLibraryItem {
        FfiLibraryItem {
            id: id.into(),
            is_folder: false,
            title: title.into(),
            parent_id: String::new(),
            lamport,
            device: device.into(),
            deleted: false,
        }
    }

    /// 假的 Drive，直接實作平台那一側的 `FfiDriveHttp`。
    ///
    /// 這樣測到的是**完整路徑**：查詢字串 → 分頁 → ForeignHttp 轉接 →
    /// GDriveProvider → 檔案鏡像。只測合併函式的話，中間任何一段接錯
    /// 都看不出來。
    #[derive(Debug, Default)]
    struct FakeDrive {
        /// 檔名 → 內容。
        files: std::sync::Mutex<Vec<(String, Vec<u8>)>>,
    }

    impl FakeDrive {
        fn query<'a>(params: &'a [FfiQueryParam], key: &str) -> &'a str {
            params
                .iter()
                .find(|p| p.name == key)
                .map(|p| p.value.as_str())
                .unwrap_or("")
        }
    }

    impl FfiDriveHttp for FakeDrive {
        fn get_json(&self, _url: String, query: Vec<FfiQueryParam>) -> Result<String, FfiDriveError> {
            let q = Self::query(&query, "q").to_string();
            let files = self.files.lock().unwrap();
            let matches: Vec<&(String, Vec<u8>)> = files
                .iter()
                .filter(|(name, _)| {
                    if let Some(rest) = q.split("name = '").nth(1) {
                        name == rest.trim_end_matches('\'')
                    } else if let Some(rest) = q.split("name contains '").nth(1) {
                        name.contains(rest.trim_end_matches('\''))
                    } else {
                        true
                    }
                })
                .collect();
            let entries: Vec<String> = matches
                .iter()
                .enumerate()
                .map(|(i, (name, data))| {
                    format!(
                        r#"{{"id":"id-{i}","name":"{name}","size":"{}","modifiedTime":"2026-01-01T00:00:0{}Z"}}"#,
                        data.len(),
                        i % 10
                    )
                })
                .collect();
            Ok(format!(r#"{{"files":[{}]}}"#, entries.join(",")))
        }

        fn get_bytes(
            &self,
            url: String,
            _range: Option<FfiByteRange>,
        ) -> Result<Vec<u8>, FfiDriveError> {
            let index: usize = url
                .split("files/id-")
                .nth(1)
                .and_then(|s| s.split('?').next())
                .and_then(|s| s.parse().ok())
                .ok_or(FfiDriveError::NotFound { path: url.clone() })?;
            let files = self.files.lock().unwrap();
            files
                .get(index)
                .map(|(_, d)| d.clone())
                .ok_or(FfiDriveError::NotFound { path: url })
        }

        fn post_json(&self, _url: String, body_json: String) -> Result<String, FfiDriveError> {
            let value: serde_json::Value = serde_json::from_str(&body_json).unwrap();
            let name = value["name"].as_str().unwrap().to_string();
            let mut files = self.files.lock().unwrap();
            files.push((name, Vec::new()));
            Ok(format!(r#"{{"id":"id-{}"}}"#, files.len() - 1))
        }

        fn patch_bytes(&self, url: String, data: Vec<u8>) -> Result<(), FfiDriveError> {
            let index: usize = url
                .split("files/id-")
                .nth(1)
                .and_then(|s| s.split('?').next())
                .and_then(|s| s.parse().ok())
                .ok_or(FfiDriveError::NotFound { path: url.clone() })?;
            let mut files = self.files.lock().unwrap();
            if let Some(slot) = files.get_mut(index) {
                slot.1 = data;
                Ok(())
            } else {
                Err(FfiDriveError::NotFound { path: url })
            }
        }
    }

    fn tmp_package(name: &str, device: u64) -> std::path::PathBuf {
        let root = std::env::temp_dir()
            .join(format!("padnote-gdrive-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        padnote_storage::NotebookPackage::create(&root, "t", device).unwrap();
        root
    }

    #[test]
    fn two_devices_converge_on_notebook_content() {
        // 這是內容層同步的主測試：A 寫、B 寫，各自同步一輪之後，
        // 兩邊都該看得到對方的 oplog 檔。
        use padnote_doc::ops::DocOp;

        let cloud: Arc<dyn FfiDriveHttp> = Arc::new(FakeDrive::default());

        let a_root = tmp_package("conv-a", 0xAA);
        let a = padnote_storage::NotebookPackage::open(&a_root).unwrap();
        a.append_doc_ops(1, 0xAA, &[DocOp::SetTitle { title: "A 寫的".into() }])
            .unwrap();

        let b_root = tmp_package("conv-b", 0xBB);
        let b = padnote_storage::NotebookPackage::open(&b_root).unwrap();
        b.append_doc_ops(2, 0xBB, &[DocOp::SetTitle { title: "B 寫的".into() }])
            .unwrap();

        // A 先同步：上傳自己的，雲端還沒有別人的。
        let first = gdrive_sync_notebook(
            cloud.clone(),
            a_root.to_string_lossy().into(),
            "nb1".into(),
        );
        assert!(first.ok, "{}", first.error);
        assert_eq!(first.uploaded, 1);
        assert_eq!(first.downloaded, 0);

        // B 同步：上傳自己的，並拿到 A 的。
        let second = gdrive_sync_notebook(
            cloud.clone(),
            b_root.to_string_lossy().into(),
            "nb1".into(),
        );
        assert!(second.ok, "{}", second.error);
        assert_eq!(second.uploaded, 1);
        assert_eq!(second.downloaded, 1, "應該要拿到 A 的那一份");

        // A 再同步一次，拿到 B 的。
        let third = gdrive_sync_notebook(
            cloud.clone(),
            a_root.to_string_lossy().into(),
            "nb1".into(),
        );
        assert!(third.ok, "{}", third.error);
        assert_eq!(third.downloaded, 1);

        // 兩邊的 oplog 檔一模一樣。
        let a_files: Vec<String> = padnote_storage::NotebookPackage::open(&a_root)
            .unwrap()
            .doc_op_files()
            .unwrap()
            .into_iter()
            .map(|(n, _)| n)
            .collect();
        let b_files: Vec<String> = padnote_storage::NotebookPackage::open(&b_root)
            .unwrap()
            .doc_op_files()
            .unwrap()
            .into_iter()
            .map(|(n, _)| n)
            .collect();
        assert_eq!(a_files, b_files, "兩台裝置沒有收斂");
        assert_eq!(a_files.len(), 2);
    }

    #[test]
    fn syncing_twice_uploads_nothing_the_second_time() {
        // 每次同步都重傳一次的話，Drive 的配額與使用者的流量都白白消耗，
        // 而且活動紀錄裡會出現一堆沒有意義的寫入。
        use padnote_doc::ops::DocOp;

        let cloud: Arc<dyn FfiDriveHttp> = Arc::new(FakeDrive::default());
        let root = tmp_package("idem", 0xAA);
        let pkg = padnote_storage::NotebookPackage::open(&root).unwrap();
        pkg.append_doc_ops(1, 0xAA, &[DocOp::SetTitle { title: "一".into() }])
            .unwrap();

        let path: String = root.to_string_lossy().into();
        let first = gdrive_sync_notebook(cloud.clone(), path.clone(), "nb1".into());
        assert_eq!(first.uploaded, 1);

        let second = gdrive_sync_notebook(cloud, path, "nb1".into());
        assert!(second.ok);
        assert_eq!(second.uploaded, 0, "沒有變動就不該重傳");
        assert_eq!(second.downloaded, 0, "自己剛傳的不該再抓回來");
    }

    #[test]
    fn a_missing_package_is_an_error_not_a_panic() {
        let cloud: Arc<dyn FfiDriveHttp> = Arc::new(FakeDrive::default());
        let result = gdrive_sync_notebook(cloud, "/does/not/exist".into(), "nb1".into());
        assert!(!result.ok);
        assert!(!result.needs_reauth, "開不了本機檔案不是授權問題");
    }

    #[test]
    fn a_first_sync_uploads_what_this_device_has() {
        // 第一次同步時雲端什麼都沒有。那是正常狀態，不是錯誤。
        let local = sync_set_setting(
            String::new(),
            FfiSyncedField::Locale,
            "ja".into(),
            1,
            "dev-a".into(),
        );
        let (merged, push) = merge_settings(&local, "");
        assert!(push, "雲端是空的，一定要上傳");
        assert!(merged.contains("\"ja\""));
    }

    #[test]
    fn nothing_is_uploaded_when_both_sides_already_agree() {
        // 每次同步都寫一次的話，Drive 上的修改時間一直在變，
        // 使用者會在 Google 的活動紀錄裡看到一堆沒有意義的寫入。
        let local = sync_upsert_item(String::new(), item("n1", "會議", 1, "dev-a"));
        let (_, push) = merge_index(&local, &local);
        assert!(!push);
    }

    #[test]
    fn the_other_devices_changes_come_back() {
        let mine = sync_upsert_item(String::new(), item("n1", "我的", 1, "dev-a"));
        let theirs = sync_upsert_item(String::new(), item("n2", "他的", 1, "dev-b"));
        let (merged, push) = merge_index(&mine, &theirs);
        assert!(push, "我這邊多了一筆，要推上去");
        assert!(merged.contains("我的") && merged.contains("他的"));
    }

    #[test]
    fn a_deletion_from_the_cloud_is_not_undone() {
        // 另一台刪掉的筆記本，本機還留著活的那一份。合併之後要維持刪除 ——
        // 不然每同步一次就復活一次。
        let live = sync_upsert_item(String::new(), item("n1", "會議", 1, "dev-a"));
        let cloud_deleted = sync_delete_item(live.clone(), "n1".into(), 5, "dev-b".into());
        let (merged, _) = merge_index(&live, &cloud_deleted);
        assert!(merged.contains("\"deleted\": true"), "{merged}");
    }

    #[test]
    fn an_empty_cloud_file_is_not_treated_as_corruption() {
        // Drive 上剛建立、還沒寫入內容的檔案會是空的。
        let local = sync_upsert_item(String::new(), item("n1", "會議", 1, "dev-a"));
        let (merged, push) = merge_index(&local, "");
        assert!(push);
        assert!(merged.contains("n1"));
    }

    #[test]
    fn permission_denied_means_reauth_but_other_errors_do_not() {
        let denied = FfiCloudSyncResult::failed(
            "{}".into(),
            "{}".into(),
            SyncError::PermissionDenied("x".into()),
        );
        assert!(denied.needs_reauth);

        let offline =
            FfiCloudSyncResult::failed("{}".into(), "{}".into(), SyncError::Backend("offline".into()));
        assert!(!offline.needs_reauth, "網路問題重試就好，不要叫使用者重新登入");
    }
}
