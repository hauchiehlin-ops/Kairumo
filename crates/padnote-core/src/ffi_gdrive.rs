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
    fn get_bytes(&self, url: String, range: Option<FfiByteRange>)
    -> Result<Vec<u8>, FfiDriveError>;
    /// POST 一段 JSON，回應也是 JSON 字串。
    fn post_json(&self, url: String, body_json: String) -> Result<String, FfiDriveError>;
    /// PATCH 原始位元組（上傳檔案內容，**小檔用**）。
    fn patch_bytes(&self, url: String, data: Vec<u8>) -> Result<(), FfiDriveError>;

    /// 開一個可續傳上傳的工作階段，回傳工作階段 URI。
    ///
    /// Drive 把那個 URI 放在**回應標頭 `Location`** 裡，不是 body ——
    /// 所以只有平台層做得到，核心看不到標頭。
    ///
    /// 為什麼需要它：Drive 單次上傳上限 5 MB，而手機照片的 blob 存的是
    /// **原始位元組**（只有顯示尺寸被縮小），3–8 MB 是常態。
    fn start_resumable(&self, url: String, body_json: String) -> Result<String, FfiDriveError>;

    /// 把位元組 PUT 到可續傳的工作階段 URI。
    fn put_bytes(&self, url: String, data: Vec<u8>) -> Result<(), FfiDriveError>;
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

    fn post_json(
        &self,
        url: &str,
        body: &serde_json::Value,
    ) -> Result<serde_json::Value, SyncError> {
        let text = self.0.post_json(url.to_string(), body.to_string())?;
        serde_json::from_str(&text)
            .map_err(|e| SyncError::Backend(format!("Drive 回應不是合法 JSON：{e}")))
    }

    fn patch_bytes(&self, url: &str, data: &[u8]) -> Result<(), SyncError> {
        Ok(self.0.patch_bytes(url.to_string(), data.to_vec())?)
    }

    fn start_resumable(&self, url: &str, body: &serde_json::Value) -> Result<String, SyncError> {
        Ok(self.0.start_resumable(url.to_string(), body.to_string())?)
    }

    fn put_bytes(&self, url: &str, data: &[u8]) -> Result<(), SyncError> {
        Ok(self.0.put_bytes(url.to_string(), data.to_vec())?)
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

    if push_settings && let Err(e) = drive.put(SETTINGS_PATH, merged_settings.as_bytes()) {
        return FfiCloudSyncResult::failed(merged_settings, merged_index, e);
    }
    if push_index && let Err(e) = drive.put(INDEX_PATH, merged_index.as_bytes()) {
        return FfiCloudSyncResult::failed(merged_settings, merged_index, e);
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
    let package = match padnote_storage::NotebookPackage::open(std::path::Path::new(&package_path))
    {
        Ok(p) => p,
        Err(e) => return notebook_failed(format!("開不了套件：{e}")),
    };
    // 上傳前先做 oplog 壓實：當本機碎檔超過 50 個時，合併以大幅減少 HTTP PUT 次數
    let _ = package.compact_doc_ops(50);
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

/// 同步一本筆記本的**媒體檔**（圖片 blob 與錄音）。
///
/// # 兩種媒體的同步方式不一樣，因為它們的命名保證不一樣
///
/// - **blob 是內容定址的**（檔名＝SHA-256）。同名必定同內容，所以
///   「對面有沒有這個名字」就是完整的判斷，連長度都不必比。
///   下載回來會**驗雜湊**：對不上就丟掉，不要把壞資料寫進套件。
/// - **錄音是 uuid 命名的**，而且**錄製中會變長**。所以要比長度，
///   只看存在與否的話，一段還在錄的音永遠只會同步到第一次的長度。
///
/// **這個函式會同步地等平台的 HTTP 回來，不要在主執行緒呼叫。**
#[uniffi::export]
pub fn gdrive_sync_media(
    http: Arc<dyn FfiDriveHttp>,
    package_path: String,
    notebook_id: String,
) -> FfiNotebookSyncResult {
    let root = std::path::Path::new(&package_path);
    let package = match padnote_storage::NotebookPackage::open(root) {
        Ok(p) => p,
        Err(e) => return notebook_failed(format!("開不了套件：{e}")),
    };
    let drive = GDriveProvider::new(ForeignHttp(http));

    let mut uploaded = 0u32;
    let mut downloaded = 0u32;

    // ── 圖片 blob（內容定址）──────────────────────────────────
    let blobs = package.blobs();
    let local_blobs = match blobs.list() {
        Ok(ids) => ids,
        Err(e) => return notebook_failed(format!("列不出 blob：{e}")),
    };
    let blob_prefix = format!("notebooks/{notebook_id}/media/blobs");
    let remote_blobs: std::collections::BTreeSet<String> = match drive.list(&blob_prefix) {
        Ok(entries) => entries
            .into_iter()
            .filter_map(|e| Some(e.path.rsplit('/').next()?.to_string()))
            .collect(),
        Err(e) => return from_sync_error(e),
    };

    for id in &local_blobs {
        let name = id.to_string();
        if remote_blobs.contains(&name) {
            continue;
        }
        let bytes = match blobs.get(*id) {
            Ok(b) => b,
            // 本機這一份壞了（雜湊對不上）。不要上傳 —— 把壞資料推上雲端，
            // 其他裝置也會跟著壞。
            Err(e) => return notebook_failed(format!("blob {name} 損毀：{e}")),
        };
        if let Err(e) = drive.put(&format!("{blob_prefix}/{name}"), &bytes) {
            return from_sync_error(e);
        }
        uploaded += 1;
    }

    let local_blob_names: std::collections::BTreeSet<String> =
        local_blobs.iter().map(|id| id.to_string()).collect();
    for name in &remote_blobs {
        if local_blob_names.contains(name) {
            continue;
        }
        let bytes = match drive.get_all(&format!("{blob_prefix}/{name}")) {
            Ok(b) => b,
            Err(e) => return from_sync_error(e),
        };
        // **驗雜湊。** blob 的檔名就是內容的雜湊，所以對不上就代表
        // 傳輸壞了或有人動過手腳。直接 put 的話，壞資料會被存在
        // 「它自己的雜湊」底下，而我們要的那一個仍然不存在 ——
        // 同步看起來成功了，圖片卻永遠出不來。
        let expected = padnote_storage::BlobId::from_hex(name);
        match expected {
            Some(id) if padnote_storage::BlobId::of(&bytes) == id => {
                if let Err(e) = blobs.put(&bytes) {
                    return notebook_failed(format!("寫不進 blob {name}：{e}"));
                }
                downloaded += 1;
            }
            Some(_) => return notebook_failed(format!("blob {name} 下載後雜湊不符")),
            // 不是合法的 blob 名字：別人放進來的檔案，跳過就好。
            None => continue,
        }
    }

    // ── 錄音（uuid 命名，錄製中會變長）────────────────────────
    let local_audio = match package.audio_files() {
        Ok(files) => files,
        Err(e) => return notebook_failed(format!("列不出錄音：{e}")),
    };
    let audio_prefix = format!("notebooks/{notebook_id}/media/audio");
    let remote_audio: std::collections::BTreeMap<String, u64> = match drive.list(&audio_prefix) {
        Ok(entries) => entries
            .into_iter()
            .filter_map(|e| Some((e.path.rsplit('/').next()?.to_string(), e.size)))
            .collect(),
        Err(e) => return from_sync_error(e),
    };

    for (name, size) in &local_audio {
        if *size <= remote_audio.get(name).copied().unwrap_or(0) {
            continue;
        }
        let bytes = match package.read_audio_file(name) {
            Ok(b) => b,
            Err(e) => return notebook_failed(format!("讀不到錄音 {name}：{e}")),
        };
        if let Err(e) = drive.put(&format!("{audio_prefix}/{name}"), &bytes) {
            return from_sync_error(e);
        }
        uploaded += 1;
    }

    let local_audio_sizes: std::collections::BTreeMap<&str, u64> =
        local_audio.iter().map(|(n, s)| (n.as_str(), *s)).collect();
    for (name, remote_size) in &remote_audio {
        if *remote_size <= local_audio_sizes.get(name.as_str()).copied().unwrap_or(0) {
            continue;
        }
        let bytes = match drive.get_all(&format!("{audio_prefix}/{name}")) {
            Ok(b) => b,
            Err(e) => return from_sync_error(e),
        };
        if let Err(e) = package.write_audio_file(name, &bytes) {
            return notebook_failed(format!("寫不進錄音 {name}：{e}"));
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

/// 把一本**只存在於雲端**的筆記本抓下來。
///
/// # 為什麼需要另一個函式
///
/// `gdrive_sync_notebook` 第一件事就是 `NotebookPackage::open`，而另一台裝置
/// 新建的筆記本在本機**連目錄都沒有** —— 它會直接以「開不了套件」失敗。
/// 結果是：索引同步成功，清單上出現了那本筆記的標題，點進去卻是空的，
/// 而且每一輪同步都重複一樣的失敗。
///
/// 所以「本機還沒有」必須是一條明確的路徑：先照標題建一個空套件，
/// 再走一般的下載流程。
///
/// 已經存在時**不會覆蓋**，直接當成一般同步 —— 重跑這個函式是安全的。
///
/// **這個函式會同步地等平台的 HTTP 回來，不要在主執行緒呼叫。**
#[uniffi::export]
pub fn gdrive_clone_notebook(
    http: Arc<dyn FfiDriveHttp>,
    package_path: String,
    notebook_id: String,
    title: String,
    now_unix_ms: u64,
) -> FfiNotebookSyncResult {
    let root = std::path::Path::new(&package_path);
    if padnote_storage::NotebookPackage::open(root).is_err()
        && let Err(e) = padnote_storage::NotebookPackage::create(root, &title, now_unix_ms)
    {
        return notebook_failed(format!("建不了套件：{e}"));
    }

    let ops = gdrive_sync_notebook(http.clone(), package_path.clone(), notebook_id.clone());
    if !ops.ok {
        let _ = std::fs::remove_dir_all(root);
        return ops;
    }

    // 檢查 clone 下來的套件是否真正擁有 ops 操作記錄。
    // 如果雲端尚無任何 ops 檔（例如來源端設備尚未上傳完成），絕不能留下只有 manifest 的空殼目錄，
    // 否則後續匯入會因「沒有任何頁面」失敗，且下次同步會因目錄已存在而跳過重抓。
    let package = match padnote_storage::NotebookPackage::open(root) {
        Ok(p) => p,
        Err(e) => {
            let _ = std::fs::remove_dir_all(root);
            return notebook_failed(format!("開不了套件：{e}"));
        }
    };
    let op_files = package.doc_op_files().unwrap_or_default();
    if op_files.is_empty() {
        let _ = std::fs::remove_dir_all(root);
        return notebook_failed("雲端尚無此筆記本之操作記錄，已清理暫存等待來源端上傳".to_string());
    }

    // 媒體接在 oplog 之後，理由與平台那一側相同：oplog 裡的 AddImage 會指向
    // 一個 blob id，媒體還沒到的話那一頁是一個指向不存在檔案的圖片區塊。
    let media = gdrive_sync_media(http, package_path, notebook_id);
    FfiNotebookSyncResult {
        ok: media.ok,
        uploaded: ops.uploaded + media.uploaded,
        downloaded: ops.downloaded + media.downloaded,
        error: media.error,
        needs_reauth: media.needs_reauth,
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
        fn get_json(
            &self,
            _url: String,
            query: Vec<FfiQueryParam>,
        ) -> Result<String, FfiDriveError> {
            let q = Self::query(&query, "q").to_string();
            let files = self.files.lock().unwrap();
            // **索引要用全域的**，不是過濾後的序號 —— 讀取那一側是照
            // `files` 的位置去取的。用過濾後的序號會讓查詢一縮小就取到別的檔，
            // 而症狀是「下載回來的 blob 雜湊不符」，看起來像傳輸壞掉。
            let entries: Vec<String> = files
                .iter()
                .enumerate()
                .filter(|(_, (name, _))| {
                    if let Some(rest) = q.split("name = '").nth(1) {
                        name == rest.trim_end_matches('\'')
                    } else if let Some(rest) = q.split("name contains '").nth(1) {
                        name.contains(rest.trim_end_matches('\''))
                    } else {
                        true
                    }
                })
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
            self.write_at(&url, data)
        }

        fn start_resumable(&self, url: String, _body: String) -> Result<String, FfiDriveError> {
            // 真的 Drive 會回一個新的工作階段 URI；這裡把檔案 id 帶著就夠，
            // 後面的 put_bytes 才找得到要寫哪一個。
            Ok(format!("{url}&resumable-session=1"))
        }

        fn put_bytes(&self, url: String, data: Vec<u8>) -> Result<(), FfiDriveError> {
            self.write_at(&url, data)
        }
    }

    impl FakeDrive {
        fn write_at(&self, url: &str, data: Vec<u8>) -> Result<(), FfiDriveError> {
            let index: usize = url
                .split("files/id-")
                .nth(1)
                .and_then(|s| s.split('?').next())
                .and_then(|s| s.parse().ok())
                .ok_or(FfiDriveError::NotFound {
                    path: url.to_string(),
                })?;
            let mut files = self.files.lock().unwrap();
            if let Some(slot) = files.get_mut(index) {
                slot.1 = data;
                Ok(())
            } else {
                Err(FfiDriveError::NotFound {
                    path: url.to_string(),
                })
            }
        }
    }

    fn tmp_package(name: &str, device: u64) -> std::path::PathBuf {
        let root =
            std::env::temp_dir().join(format!("padnote-gdrive-{name}-{}", std::process::id()));
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
        a.append_doc_ops(
            1,
            0xAA,
            &[DocOp::SetTitle {
                title: "A 寫的".into(),
            }],
        )
        .unwrap();

        let b_root = tmp_package("conv-b", 0xBB);
        let b = padnote_storage::NotebookPackage::open(&b_root).unwrap();
        b.append_doc_ops(
            2,
            0xBB,
            &[DocOp::SetTitle {
                title: "B 寫的".into(),
            }],
        )
        .unwrap();

        // A 先同步：上傳自己的，雲端還沒有別人的。
        let first =
            gdrive_sync_notebook(cloud.clone(), a_root.to_string_lossy().into(), "nb1".into());
        assert!(first.ok, "{}", first.error);
        assert_eq!(first.uploaded, 1);
        assert_eq!(first.downloaded, 0);

        // B 同步：上傳自己的，並拿到 A 的。
        let second =
            gdrive_sync_notebook(cloud.clone(), b_root.to_string_lossy().into(), "nb1".into());
        assert!(second.ok, "{}", second.error);
        assert_eq!(second.uploaded, 1);
        assert_eq!(second.downloaded, 1, "應該要拿到 A 的那一份");

        // A 再同步一次，拿到 B 的。
        let third =
            gdrive_sync_notebook(cloud.clone(), a_root.to_string_lossy().into(), "nb1".into());
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
    fn a_notebook_that_only_exists_in_the_cloud_can_be_cloned() {
        // 另一台裝置新建的筆記本：本機連套件目錄都沒有。
        // 這條路以前是斷的 —— 索引同步成功、清單上有標題，點進去卻是空的。
        use padnote_doc::ops::DocOp;

        let cloud: Arc<dyn FfiDriveHttp> = Arc::new(FakeDrive::default());

        let a_root = tmp_package("clone-a", 0xAA);
        let a = padnote_storage::NotebookPackage::open(&a_root).unwrap();
        a.append_doc_ops(
            1,
            0xAA,
            &[DocOp::SetTitle {
                title: "A 新建的".into(),
            }],
        )
        .unwrap();
        let pushed = gdrive_sync_notebook(
            cloud.clone(),
            a_root.to_string_lossy().into(),
            "nb-new".into(),
        );
        assert!(pushed.ok, "{}", pushed.error);

        // B 完全沒有這個目錄。
        let b_root =
            std::env::temp_dir().join(format!("padnote-gdrive-clone-b-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&b_root);

        // 一般的同步在這裡會失敗 —— 那正是要修的東西。
        let refused = gdrive_sync_notebook(
            cloud.clone(),
            b_root.to_string_lossy().into(),
            "nb-new".into(),
        );
        assert!(!refused.ok, "沒有套件時本來就不該假裝成功");

        let cloned = gdrive_clone_notebook(
            cloud.clone(),
            b_root.to_string_lossy().into(),
            "nb-new".into(),
            "A 新建的".into(),
            1_700_000_000_000,
        );
        assert!(cloned.ok, "{}", cloned.error);
        assert_eq!(cloned.downloaded, 1, "應該把 A 的那一份抓下來");

        let b = padnote_storage::NotebookPackage::open(&b_root).unwrap();
        assert_eq!(b.doc_op_files().unwrap().len(), 1);

        // 再跑一次不該重建、也不該重抓 —— 重跑要是安全的。
        let again = gdrive_clone_notebook(
            cloud,
            b_root.to_string_lossy().into(),
            "nb-new".into(),
            "A 新建的".into(),
            1_700_000_000_000,
        );
        assert!(again.ok, "{}", again.error);
        assert_eq!(again.downloaded, 0);
        assert_eq!(again.uploaded, 0);
    }

    #[test]
    fn cloning_empty_cloud_notebook_cleans_up_and_fails() {
        let cloud: Arc<dyn FfiDriveHttp> = Arc::new(FakeDrive::default());
        let root = tmp_package("empty-cloud", 0xBB);
        let _ = std::fs::remove_dir_all(&root);

        // 雲端只有資料夾或完全無 ops 檔案，clone 不應留下空目錄，且應回傳錯誤
        let cloned = gdrive_clone_notebook(
            cloud,
            root.to_string_lossy().into(),
            "empty-nb".into(),
            "空筆記".into(),
            1_700_000_000_000,
        );
        assert!(!cloned.ok, "雲端沒有任何 ops 時不應成功");
        assert!(!root.exists(), "失敗時必須清理建立的臨時套件目錄");
    }

    #[test]
    fn syncing_twice_uploads_nothing_the_second_time() {
        // 每次同步都重傳一次的話，Drive 的配額與使用者的流量都白白消耗，
        // 而且活動紀錄裡會出現一堆沒有意義的寫入。
        use padnote_doc::ops::DocOp;

        let cloud: Arc<dyn FfiDriveHttp> = Arc::new(FakeDrive::default());
        let root = tmp_package("idem", 0xAA);
        let pkg = padnote_storage::NotebookPackage::open(&root).unwrap();
        pkg.append_doc_ops(
            1,
            0xAA,
            &[DocOp::SetTitle {
                title: "一".into()
            }],
        )
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
    fn media_converges_across_two_devices() {
        let cloud: Arc<dyn FfiDriveHttp> = Arc::new(FakeDrive::default());

        let a_root = tmp_package("media-a", 0xAA);
        let a = padnote_storage::NotebookPackage::open(&a_root).unwrap();
        let a_blob = a.blobs().put("A 的圖片位元組".as_bytes()).unwrap();
        a.write_audio_file("11111111-1111-1111-1111-111111111111.opus", b"A-audio")
            .unwrap();

        let b_root = tmp_package("media-b", 0xBB);
        let b = padnote_storage::NotebookPackage::open(&b_root).unwrap();
        let b_blob = b.blobs().put("B 的圖片位元組".as_bytes()).unwrap();

        let a_path: String = a_root.to_string_lossy().into();
        let b_path: String = b_root.to_string_lossy().into();

        let first = gdrive_sync_media(cloud.clone(), a_path.clone(), "nb1".into());
        assert!(first.ok, "{}", first.error);
        assert_eq!(first.uploaded, 2, "一個 blob 加一段錄音");

        let second = gdrive_sync_media(cloud.clone(), b_path.clone(), "nb1".into());
        assert!(second.ok, "{}", second.error);
        assert_eq!(second.uploaded, 1);
        assert_eq!(second.downloaded, 2, "要拿到 A 的 blob 與錄音");

        let third = gdrive_sync_media(cloud.clone(), a_path, "nb1".into());
        assert!(third.ok, "{}", third.error);
        assert_eq!(third.downloaded, 1, "要拿到 B 的 blob");

        // 兩邊都拿得到對方的圖片，而且內容正確（get 會驗雜湊）。
        let a_after = padnote_storage::NotebookPackage::open(&a_root).unwrap();
        let b_after = padnote_storage::NotebookPackage::open(&b_root).unwrap();
        assert_eq!(
            a_after.blobs().get(b_blob).unwrap(),
            "B 的圖片位元組".as_bytes()
        );
        assert_eq!(
            b_after.blobs().get(a_blob).unwrap(),
            "A 的圖片位元組".as_bytes()
        );
        assert_eq!(
            b_after
                .read_audio_file("11111111-1111-1111-1111-111111111111.opus")
                .unwrap(),
            b"A-audio"
        );
    }

    #[test]
    fn media_sync_is_idempotent() {
        let cloud: Arc<dyn FfiDriveHttp> = Arc::new(FakeDrive::default());
        let root = tmp_package("media-idem", 0xAA);
        let pkg = padnote_storage::NotebookPackage::open(&root).unwrap();
        pkg.blobs().put("一張圖".as_bytes()).unwrap();

        let path: String = root.to_string_lossy().into();
        assert_eq!(
            gdrive_sync_media(cloud.clone(), path.clone(), "nb1".into()).uploaded,
            1
        );

        let again = gdrive_sync_media(cloud, path, "nb1".into());
        assert!(again.ok);
        assert_eq!(again.uploaded, 0, "沒有變動就不該重傳");
        assert_eq!(again.downloaded, 0, "自己剛傳的不該再抓回來");
    }

    #[test]
    fn a_growing_recording_is_re_uploaded() {
        // 錄音檔在錄製中會變長。只看「對面有沒有這個名字」的話，
        // 一段還在錄的音永遠只會同步到第一次的長度。
        let cloud: Arc<dyn FfiDriveHttp> = Arc::new(FakeDrive::default());
        let root = tmp_package("media-grow", 0xAA);
        let pkg = padnote_storage::NotebookPackage::open(&root).unwrap();
        let name = "22222222-2222-2222-2222-222222222222.opus";
        pkg.write_audio_file(name, b"short").unwrap();

        let path: String = root.to_string_lossy().into();
        assert_eq!(
            gdrive_sync_media(cloud.clone(), path.clone(), "nb1".into()).uploaded,
            1
        );

        pkg.write_audio_file(name, b"short-plus-more-audio")
            .unwrap();
        let after = gdrive_sync_media(cloud, path, "nb1".into());
        assert_eq!(after.uploaded, 1, "變長之後要再傳一次");
    }

    #[test]
    fn a_corrupted_blob_from_the_cloud_is_rejected() {
        // blob 的檔名就是內容的雜湊。對不上代表傳輸壞了或有人動過手腳。
        //
        // 不驗的話，壞資料會被存在「它自己的雜湊」底下，而我們要的那一個
        // 仍然不存在 —— 同步看起來成功了，圖片卻永遠出不來。
        let fake = FakeDrive::default();
        let fake_name = padnote_storage::BlobId::of("正確內容".as_bytes()).to_string();
        fake.files.lock().unwrap().push((
            format!("notebooks/nb1/media/blobs/{fake_name}"),
            "被掉包的內容".as_bytes().to_vec(),
        ));
        let cloud: Arc<dyn FfiDriveHttp> = Arc::new(fake);

        let root = tmp_package("media-corrupt", 0xAA);
        let result = gdrive_sync_media(cloud, root.to_string_lossy().into(), "nb1".into());
        assert!(!result.ok);
        assert!(result.error.contains("雜湊不符"), "{}", result.error);

        // 而且不可以把壞資料留在套件裡。
        let pkg = padnote_storage::NotebookPackage::open(&root).unwrap();
        assert!(pkg.blobs().list().unwrap().is_empty());
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

        let offline = FfiCloudSyncResult::failed(
            "{}".into(),
            "{}".into(),
            SyncError::Backend("offline".into()),
        );
        assert!(
            !offline.needs_reauth,
            "網路問題重試就好，不要叫使用者重新登入"
        );
    }
}
