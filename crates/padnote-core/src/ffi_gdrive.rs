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
//! - [`FfiSyncSession::sync_metadata`]：設定與筆記本清單
//!   （`settings/global.json`、`notebooks/index.json`）。整包讀寫、逐欄位合併。
//! - [`FfiSyncSession::sync_notebook`]：一本筆記本的**內容**與媒體。
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
use padnote_sync::remote_index::{RemoteFile, RemoteIndex};
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
    /// DELETE 雲端檔案。
    fn delete(&self, url: String) -> Result<(), FfiDriveError>;

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

    fn delete(&self, url: &str) -> Result<(), SyncError> {
        Ok(self.0.delete(url.to_string())?)
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
/// 只有 [`FfiSyncSession::sync_metadata`] 會呼叫它 —— 分成兩層是因為
/// session 那一層要拿著自己的 `GDriveProvider`（裡面有暖好的 file id 快取），
/// 而合併規則不該知道那件事。
fn sync_metadata_with(
    drive: &GDriveProvider<ForeignHttp>,
    local_settings_json: String,
    local_index_json: String,
) -> FfiCloudSyncResult {
    let remote_settings = match read_or_empty(drive, SETTINGS_PATH) {
        Ok(v) => v,
        Err(e) => return FfiCloudSyncResult::failed(local_settings_json, local_index_json, e),
    };
    let remote_index = match read_or_empty(drive, INDEX_PATH) {
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

/// 本機碎檔累積到幾個就壓實一次。
///
/// 太大會讓雲端累積大量小檔（新裝置第一次同步要下載幾百個）；
/// 太小則每寫幾筆就重寫一個大檔，浪費頻寬。
const COMPACT_THRESHOLD: usize = 5;

/// 一輪同步最多刪幾個雲端檔案。刪除也是 HTTP 往返，不設上限的話，
/// 一本累積很久的筆記本會把整輪同步拖到逾時。
const MAX_DELETIONS_PER_SYNC: usize = 20;

/// 一本筆記本的雲端 oplog 目錄。
///
/// 路徑一律由 `padnote_sync::paths` 產生 —— 自己拼字串的話，大小寫或
/// Unicode 正規化差一點點，兩台裝置就會寫到不同的檔案而且沒有任何錯誤。
fn notebook_ops_prefix(notebook_id: &str) -> String {
    padnote_sync::paths::notebook_ops_prefix(notebook_id)
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
    /// **不致命、但使用者該知道的事。**
    ///
    /// 在這之前只有「成功」與「整本失敗」兩種結局。於是雲端上一個壞掉的
    /// blob（上傳到一半留下的殘骸，名字對、內容截斷）會讓**整本筆記**的
    /// 同步中止 —— 那一本裡的筆跡、錄音、文字全部停住，而訊息只說某個
    /// blob 雜湊不符，看起來像傳輸壞掉。
    ///
    /// 一個媒體檔拿不回來，不該是「這本筆記不能同步」的理由。
    pub warnings: Vec<String>,
}

/// 雲端某個前綴底下的檔案：`短檔名 → 檔案`。
///
/// 索引已經建立好時**一次 HTTP 都不打** —— 這就是「沒變動的就不要花時間
/// 去動它」真正成立的地方。索引還沒建立（舊流程、或剛重建失敗）時退回
/// 逐前綴列舉，行為與以前一樣，只是慢。
fn remote_entries(
    drive: &GDriveProvider<ForeignHttp>,
    index: &RemoteIndex,
    prefix: &str,
) -> Result<std::collections::BTreeMap<String, RemoteFile>, SyncError> {
    if !index.needs_rebuild() {
        return Ok(index.entries_under(prefix));
    }
    let entries = drive.list(prefix)?;
    Ok(entries
        .into_iter()
        .filter_map(|e| {
            let name = e.path.rsplit('/').next()?.to_string();
            Some((
                padnote_sync::paths::canonical_name(&name),
                RemoteFile {
                    // 走舊路徑時還不知道 file id；空字串表示「存取時要自己查」。
                    id: String::new(),
                    name: e.path.clone(),
                    size: e.size,
                },
            ))
        })
        .collect())
}

/// 上傳一個檔案，回傳它的 file id。
///
/// 已經知道 id 就直接 PATCH 上去 —— 舊流程每次上傳前都要再 `files.list`
/// 一次去找 id，那是同步時間裡最不值得的一段。
fn upload_file(
    drive: &GDriveProvider<ForeignHttp>,
    existing: Option<&RemoteFile>,
    path: &str,
    bytes: &[u8],
) -> Result<String, SyncError> {
    match existing {
        Some(file) if !file.id.is_empty() => {
            match drive.put_to_id(&file.id, bytes) {
                Ok(()) => Ok(file.id.clone()),
                // 雲端快照中的 file_id 可能在遠端已被刪除或重置（回傳 404 NotFound）。
                // 此時絕不能使整本筆記同步失敗，應自動回退為 create_and_upload 重建該檔案。
                Err(SyncError::NotFound(_)) => drive.create_and_upload(path, bytes),
                Err(e) => Err(e),
            }
        }
        // 雲端已經有這個名字但 id 未知（舊路徑）：用路徑上傳，它會自己查。
        Some(file) => {
            drive.put(&file.name, bytes)?;
            Ok(String::new())
        }
        None => drive.create_and_upload(path, bytes),
    }
}

fn download_file(
    drive: &GDriveProvider<ForeignHttp>,
    file: &RemoteFile,
) -> Result<Vec<u8>, SyncError> {
    if file.id.is_empty() {
        drive.get_all(&file.name)
    } else {
        match drive.get_all_by_id(&file.id) {
            Ok(bytes) => Ok(bytes),
            Err(SyncError::NotFound(_)) => drive.get_all(&file.name),
            Err(e) => Err(e),
        }
    }
}

/// 同步一本筆記本的 oplog 檔。
///
/// # 刪除一定排在上傳之後
///
/// 壓實之後，雲端上被涵蓋的舊碎檔要刪掉，否則雲端會無限累積。
/// 但**先刪再傳**的話，中間斷網、逾時或 App 被系統殺掉，那些操作就只剩
/// 本機這一份 —— 雲端沒有、另一台裝置永遠拿不到。這是一個真的會掉資料的
/// 順序錯誤，而且它不會有任何錯誤訊息。
///
/// 而且只刪**自己這台裝置**壓實掉的那幾個，名單由
/// [`padnote_storage::NotebookPackage::compact_own_doc_ops`] 明確給出。
/// 舊版是用「lamport 比本機最大值小」去推論的，那個推論在本機還沒下載到
/// 中間某個碎檔時會錯，而錯的代價是刪掉一份本機從來沒有過的操作。
fn sync_notebook_ops(
    drive: &GDriveProvider<ForeignHttp>,
    index: &mut RemoteIndex,
    package_path: &str,
    notebook_id: &str,
    device_id: u32,
) -> FfiNotebookSyncResult {
    let package = match padnote_storage::NotebookPackage::open(std::path::Path::new(package_path)) {
        Ok(p) => p,
        Err(e) => return notebook_failed(format!("開不了套件：{e}")),
    };

    // 壓實只碰自己的檔。device_id 為 0 表示呼叫端沒給（舊 API），
    // 那就不壓實也不刪任何雲端檔案 —— 不確定擁有權時，寧可讓雲端多留幾個檔。
    // 壓實可能切成好幾段（里程碑的界線不能跨 —— 見 `split_at_barriers`），
    // 所以回來的是一份清單而不是單一結果。
    let compaction = if device_id != 0 {
        package
            .compact_own_doc_ops(COMPACT_THRESHOLD, device_id)
            .unwrap_or_default()
    } else {
        Vec::new()
    };

    let local = match package.doc_op_files() {
        Ok(files) => files,
        Err(e) => return notebook_failed(format!("讀不到本機 oplog：{e}")),
    };
    let prefix = notebook_ops_prefix(notebook_id);
    let remote = match remote_entries(drive, index, &prefix) {
        Ok(entries) => entries,
        Err(e) => return from_sync_error(e),
    };

    // ── 上傳 ────────────────────────────────────────────────
    //
    // 比長度而不是只看「有沒有」：`append_doc_ops` 在同一個 lamport 上是
    // **追加**，所以一個已經上傳過的檔仍然可能變長。
    let mut uploaded = 0u32;
    for (name, size) in &local {
        let key = padnote_sync::paths::canonical_name(name);
        let existing = remote.get(&key);
        if *size <= existing.map_or(0, |f| f.size) {
            continue;
        }
        let bytes = match package.read_doc_op_file(name) {
            Ok(b) => b,
            Err(padnote_storage::StorageError::Io(ref e))
                if e.kind() == std::io::ErrorKind::NotFound =>
            {
                continue;
            }
            Err(e) => return notebook_failed(format!("讀不到 {name}：{e}")),
        };
        let path = padnote_sync::paths::notebook_op_file(notebook_id, name);
        match upload_file(drive, existing, &path, &bytes) {
            Ok(id) => {
                if !id.is_empty() {
                    index.note_upload(&path, &id, bytes.len() as u64);
                }
            }
            Err(e) => return from_sync_error(e),
        }
        uploaded += 1;
    }

    // ── 上傳成功之後，才刪雲端上被自己壓實掉的碎檔 ──────────────
    if let Ok(content) = std::fs::read(package.root().join("doc/ops/compaction.tombstones")) {
        let text = String::from_utf8_lossy(&content);
        for line in text.lines() {
            let name = line.trim();
            if name.is_empty() {
                continue;
            }
            let path = padnote_sync::paths::notebook_op_file(notebook_id, name);
            let key = padnote_sync::paths::canonical_name(name);
            if let Some(file) = remote.get(&key) {
                let target = if file.id.is_empty() {
                    path.clone()
                } else {
                    file.name.clone()
                };
                // 如果索引裡面根本沒有這個檔案（代表雲端本來就沒有，或是已經被 changes.list 刪除），
                // 就不需要發送無謂的 HTTP DELETE 請求。這避免了在清理大量檔案時產生不必要的 API 呼叫。
                let canonical = padnote_sync::paths::canonical_path(&target);
                if index.files.contains_key(&canonical) {
                    let _ = CloudProvider::delete(drive, &target);
                }
            }
            index.note_delete(&path);
        }
        let _ = std::fs::remove_file(package.root().join("doc/ops/compaction.tombstones"));
    }

    for outcome in &compaction {
        let compacted_key = padnote_sync::paths::canonical_name(&outcome.compacted_name);
        let local_compacted_size = local
            .iter()
            .find(|(n, _)| padnote_sync::paths::canonical_name(n) == compacted_key)
            .map(|(_, s)| *s)
            .unwrap_or(0);
        // 雲端那一份必須**確實涵蓋**本機的壓實檔，才准刪它吃掉的碎檔。
        // 這一輪剛上傳過就一定成立；沒上傳（雲端本來就更長）也成立。
        let covered = uploaded > 0
            || remote
                .get(&compacted_key)
                .is_some_and(|f| f.size >= local_compacted_size);
        if covered {
            for name in outcome.absorbed.iter().take(MAX_DELETIONS_PER_SYNC) {
                let path = padnote_sync::paths::notebook_op_file(notebook_id, name);
                let key = padnote_sync::paths::canonical_name(name);
                if let Some(file) = remote.get(&key) {
                    let target = if file.id.is_empty() {
                        path.clone()
                    } else {
                        file.name.clone()
                    };
                    let _ = CloudProvider::delete(drive, &target);
                }
                index.note_delete(&path);
            }
        }
    }

    // ── 下載 ────────────────────────────────────────────────
    let local_by_key: std::collections::BTreeMap<String, u64> = local
        .iter()
        .map(|(n, s)| (padnote_sync::paths::canonical_name(n), *s))
        .collect();
    let mut downloaded = 0u32;
    for (name, file) in &remote {
        let local_size = local_by_key.get(name).copied().unwrap_or(0);
        if file.size <= local_size {
            continue;
        }
        let bytes = match download_file(drive, file) {
            Ok(b) => b,
            // 對面剛好把它壓實掉了：這一輪拿不到不是錯誤，下一輪會拿到
            // 涵蓋它的那個檔。當成失敗的話，整輪同步會停在這裡。
            Err(SyncError::NotFound(_)) => continue,
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
        warnings: Vec::new(),
    }
}

/// 同步一本筆記本的內容。
///
/// **只有測試在用。** 正式路徑走 [`FfiSyncSession::sync_notebook`]。
#[cfg(test)]
fn gdrive_sync_notebook(
    http: Arc<dyn FfiDriveHttp>,
    package_path: String,
    notebook_id: String,
) -> FfiNotebookSyncResult {
    let drive = GDriveProvider::new(ForeignHttp(http));
    let mut index = RemoteIndex::default();
    sync_notebook_ops(&drive, &mut index, &package_path, &notebook_id, 0)
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
/// 錄音上傳的節流門檻。
///
/// 錄音檔在**錄製中會一直變長**，而每次上傳都是整檔重傳。P2 之後前景每 12 秒
/// 拉一次，不節流的話，一段 30 MB 的錄音會在錄製期間被整檔重傳好幾十次。
///
/// 規則：長度還在成長時，成長不到這個量就先不傳；**長度穩定下來（錄完了）
/// 就一定傳**。只看門檻的話，最後那一小段永遠傳不出去，而雲端上那份會
/// 少掉結尾 —— 使用者會說「同步過去的錄音被截斷了」。
const AUDIO_GROWTH_THRESHOLD: u64 = 1024 * 1024;

/// 上一輪看到的本機檔案長度，用來判斷「還在成長」還是「已經穩定」。
type SeenSizes = std::collections::BTreeMap<String, u64>;

fn sync_notebook_media(
    drive: &GDriveProvider<ForeignHttp>,
    index: &mut RemoteIndex,
    seen: &mut SeenSizes,
    package_path: &str,
    notebook_id: &str,
) -> FfiNotebookSyncResult {
    let root = std::path::Path::new(package_path);
    let package = match padnote_storage::NotebookPackage::open(root) {
        Ok(p) => p,
        Err(e) => return notebook_failed(format!("開不了套件：{e}")),
    };

    let mut uploaded = 0u32;
    let mut downloaded = 0u32;
    // 不致命、但使用者該知道的事（例如雲端上一個壞掉的 blob）。
    let mut warnings: Vec<String> = Vec::new();

    // ── 媒體墓碑（先同步這個）────────────────────────────────
    //
    // **順序不能反。** 要先知道哪些東西已經死了，才知道等一下哪些不該傳、
    // 哪些不該抓。反過來的話，這一輪還是會把別台刪掉的錄音抓回來，
    // 要到下一輪才收斂 —— 而使用者看到的是「刪掉的東西閃了一下又出現」。
    let tombstone_prefix = padnote_sync::media_tombstone::tombstones_prefix(notebook_id);
    let remote_tombstones = match remote_entries(drive, index, &tombstone_prefix) {
        Ok(entries) => entries,
        Err(e) => return from_sync_error(e),
    };
    // 先把別台的拉下來（墓碑只會長大，所以無條件合併是安全的）。
    for (name, file) in &remote_tombstones {
        let device = name.trim_end_matches(".json");
        let bytes = match download_file(drive, file) {
            Ok(b) => b,
            Err(SyncError::NotFound(_)) => continue,
            Err(e) => return from_sync_error(e),
        };
        let incoming = padnote_sync::MediaTombstones::from_json(&String::from_utf8_lossy(&bytes));
        let mut merged = padnote_sync::MediaTombstones::from_json(
            &package.read_media_tombstone(device).unwrap_or_default(),
        );
        merged.merge(&incoming);
        if let Err(e) = package.write_media_tombstone(device, &merged.to_json()) {
            warnings.push(format!("寫不進墓碑 {device}：{e}"));
        }
    }
    let tombstones = merged_tombstones(&package);
    // **別台刪掉的，這台也要跟著刪。**
    //
    // 只做到「不下載」是不夠的：B 已經有那段錄音了，不刪的話它就一直留在
    // B 上，而 A 那邊早就不見了 —— 兩台看到的東西不一樣，使用者說的
    // 「無法處於真正同步狀態」就是這個。
    if let Ok(local) = package.audio_files() {
        for (name, _) in local.iter().filter(|(n, _)| tombstones.contains(n)) {
            if let Err(e) = package.delete_audio_file(name) {
                warnings.push(format!("刪不掉本機的錄音 {name}：{e}"));
            }
        }
    }
    // 再把這台自己那一份傳上去。**只寫自己的** —— 沿用 oplog 的不變式，
    // 沒有跨裝置寫入競爭，雲端硬碟不會判定為修改衝突。
    if let Ok(files) = package.media_tombstone_files() {
        for (file_name, _) in files {
            let device = file_name.trim_end_matches(".json");
            if device != package.device().to_string() {
                continue;
            }
            let Ok(json) = package.read_media_tombstone(device) else {
                continue;
            };
            let path = padnote_sync::media_tombstone::tombstone_file(notebook_id, device);
            let key = padnote_sync::paths::canonical_name(&file_name);
            let existing = remote_tombstones.get(&key);
            if existing.map_or(0, |f| f.size) as usize >= json.len() {
                continue;
            }
            match upload_file(drive, existing, &path, json.as_bytes()) {
                Ok(file_id) => {
                    if !file_id.is_empty() {
                        index.note_upload(&path, &file_id, json.len() as u64);
                    }
                    uploaded += 1;
                }
                Err(e) => return from_sync_error(e),
            }
        }
    }

    // ── 圖片 blob（內容定址）──────────────────────────────────
    let blobs = package.blobs();
    let local_blobs = match blobs.list() {
        Ok(ids) => ids,
        Err(e) => return notebook_failed(format!("列不出 blob：{e}")),
    };
    let blob_prefix = padnote_sync::paths::notebook_blobs_prefix(notebook_id);
    let remote_blobs = match remote_entries(drive, index, &blob_prefix) {
        Ok(entries) => entries,
        Err(e) => return from_sync_error(e),
    };

    for id in &local_blobs {
        let name = id.to_string();
        let key = padnote_sync::paths::canonical_name(&name);
        if remote_blobs.contains_key(&key) {
            continue;
        }
        let bytes = match blobs.get(*id) {
            Ok(b) => b,
            // 本機這一份壞了（雜湊對不上）。不要上傳 —— 把壞資料推上雲端，
            // 其他裝置也會跟著壞。
            Err(e) => return notebook_failed(format!("blob {name} 損毀：{e}")),
        };
        let path = padnote_sync::paths::notebook_blob_file(notebook_id, &name);
        match drive.create_and_upload(&path, &bytes) {
            Ok(file_id) => index.note_upload(&path, &file_id, bytes.len() as u64),
            Err(e) => return from_sync_error(e),
        }
        uploaded += 1;
    }

    let local_blob_names: std::collections::BTreeSet<String> = local_blobs
        .iter()
        .map(|id| padnote_sync::paths::canonical_name(&id.to_string()))
        .collect();
    for (name, file) in &remote_blobs {
        if local_blob_names.contains(name) {
            continue;
        }
        let bytes = match download_file(drive, file) {
            Ok(b) => b,
            Err(SyncError::NotFound(_)) => continue,
            Err(e) => {
                warnings.push(format!("下載 blob {name} 失敗：{e}，將在下一輪重試"));
                continue;
            }
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
            // **不致命。**
            //
            // 原本這裡是 `return notebook_failed(...)` —— 整本筆記的同步
            // 就此中止，那一本裡的筆跡、錄音、文字全部停住，而訊息只說
            // 某個 blob 雜湊不符，看起來像傳輸壞掉。雲端上留著一個上傳到
            // 一半的殘骸（名字對、內容截斷）就會造成這個結果，而且**每一輪
            // 都會再撞一次**，那本筆記從此再也同步不了。
            //
            // 一個媒體檔拿不回來，不該是「這本筆記不能同步」的理由。
            // 記成警告，其餘照常。
            Some(_) => warnings.push(format!("blob {name} 下載後雜湊不符，已略過")),
            // 不是合法的 blob 名字：別人放進來的檔案，跳過就好。
            None => continue,
        }
    }

    // ── 錄音（uuid 命名，錄製中會變長）────────────────────────
    let local_audio = match package.audio_files() {
        Ok(files) => files,
        Err(e) => return notebook_failed(format!("列不出錄音：{e}")),
    };
    let audio_prefix = padnote_sync::paths::notebook_audio_prefix(notebook_id);
    let remote_audio = match remote_entries(drive, index, &audio_prefix) {
        Ok(entries) => entries,
        Err(e) => return from_sync_error(e),
    };

    for (name, size) in &local_audio {
        let key = padnote_sync::paths::canonical_name(name);
        // 本機還留著、但已經有墓碑：別台刪掉而這台還沒清乾淨。不要傳上去。
        if tombstones.contains(name) {
            continue;
        }
        let existing = remote_audio.get(&key);
        let remote_size = existing.map_or(0, |f| f.size);
        if *size <= remote_size {
            continue;
        }
        // 還在錄的那一段：成長不到門檻就先不傳，等它穩定或長夠多。
        // 「穩定」＝這一輪看到的長度與上一輪相同 ⇒ 錄完了，一定要傳。
        let previous = seen.insert(key.clone(), *size);
        // **第一次看到不算「還在成長」。** 不知道就傳 —— 反過來假設的話，
        // 一段錄完很久的短錄音會在重開 App 之後永遠不上傳。
        let still_growing = matches!(previous, Some(p) if p != *size);
        if still_growing && size.saturating_sub(remote_size) < AUDIO_GROWTH_THRESHOLD {
            continue;
        }
        let bytes = match package.read_audio_file(name) {
            Ok(b) => b,
            Err(padnote_storage::StorageError::Io(ref e))
                if e.kind() == std::io::ErrorKind::NotFound =>
            {
                continue;
            }
            Err(e) => return notebook_failed(format!("讀不到錄音 {name}：{e}")),
        };
        let path = padnote_sync::paths::notebook_audio_file(notebook_id, name);
        match upload_file(drive, existing, &path, &bytes) {
            Ok(file_id) => {
                if !file_id.is_empty() {
                    index.note_upload(&path, &file_id, bytes.len() as u64);
                }
            }
            Err(e) => return from_sync_error(e),
        }
        uploaded += 1;
    }

    let local_audio_sizes: std::collections::BTreeMap<String, u64> = local_audio
        .iter()
        .map(|(n, s)| (padnote_sync::paths::canonical_name(n), *s))
        .collect();
    for (name, file) in &remote_audio {
        // **刪掉的不可以抓回來。**
        //
        // 原本的條件只有「遠端比本機長就下載」，而使用者刪掉之後本機是 0
        // —— 於是每同步一次就復活一次。刪除是明確的事件（墓碑），不是
        // 從「檔案不見了」推論出來的。
        if tombstones.contains(name) {
            // 順便把雲端那一份也收掉，否則別台每一輪都要重新判斷一次，
            // 而且雲端會一直留著使用者以為已經刪掉的錄音。
            if let Err(e) = drive.delete_by_id(&file.id) {
                warnings.push(format!("刪不掉雲端的錄音 {name}：{e}"));
            } else {
                index.note_delete(&padnote_sync::paths::notebook_audio_file(notebook_id, name));
            }
            continue;
        }
        if file.size <= local_audio_sizes.get(name).copied().unwrap_or(0) {
            continue;
        }
        let bytes = match download_file(drive, file) {
            Ok(b) => b,
            Err(SyncError::NotFound(_)) => continue,
            Err(e) => {
                warnings.push(format!("下載錄音 {name} 失敗：{e}，將在下一輪重試"));
                continue;
            }
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
        warnings,
    }
}

/// 同步一本筆記本的媒體檔。**只有測試在用**，正式路徑走
/// [`FfiSyncSession::sync_notebook`]（它會把 oplog 與媒體一起做完）。
#[cfg(test)]
fn gdrive_sync_media(
    http: Arc<dyn FfiDriveHttp>,
    package_path: String,
    notebook_id: String,
) -> FfiNotebookSyncResult {
    let drive = GDriveProvider::new(ForeignHttp(http));
    let mut index = RemoteIndex::default();
    let mut seen = SeenSizes::new();
    sync_notebook_media(&drive, &mut index, &mut seen, &package_path, &notebook_id)
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
/// **只有測試在用。** 正式路徑走 [`FfiSyncSession::clone_notebook`]。
#[cfg(test)]
fn gdrive_clone_notebook(
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

    let drive = GDriveProvider::new(ForeignHttp(http));
    let mut index = RemoteIndex::default();
    let ops = sync_notebook_ops(&drive, &mut index, &package_path, &notebook_id, 0);
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
    let mut seen = SeenSizes::new();
    let media = sync_notebook_media(&drive, &mut index, &mut seen, &package_path, &notebook_id);
    FfiNotebookSyncResult {
        ok: media.ok,
        uploaded: ops.uploaded + media.uploaded,
        downloaded: ops.downloaded + media.downloaded,
        error: media.error,
        needs_reauth: media.needs_reauth,
        warnings: Vec::new(),
    }
}

// ── 同步工作階段（P1）──────────────────────────────────────────────

/// 一次重新整理雲端快照的結果。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiRefreshResult {
    pub ok: bool,
    /// 這一輪有幾筆變更。0 表示雲端完全沒動 —— 上層可以直接跳過整輪同步。
    pub changed: u32,
    /// 走了全量重建（第一次、或游標過期）。
    pub full_rebuild: bool,
    /// 目前快照裡有幾個檔案。給「同步醫生」畫面看的。
    pub tracked_files: u32,
    pub error: String,
    pub needs_reauth: bool,
}

/// 同步狀態的一份快照，給「同步醫生」畫面用（P4）。
///
/// # 為什麼需要它
///
/// 出問題時使用者（與我們）能看到的只有一串日誌。日誌回答得了
/// 「發生過什麼」，回答不了**「現在是什麼狀態」**：游標建立了沒？
/// 快照裡有幾個檔案？哪幾本還沒推上去？卡在哪一步？
///
/// 這些欄位由核心算，所以兩個平台顯示的是同一組數字 ——
/// 各自湊一份的話，比對兩台裝置的畫面時會得到互相矛盾的結論。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiSyncDiagnostics {
    /// 變更游標已建立。false 表示下一輪會走全量重建（唯一的慢路徑）。
    pub has_cursor: bool,
    /// 雲端快照裡追蹤了幾個檔案。
    pub tracked_files: u32,
    /// 還有差異、下一輪要碰的筆記本 id。**完全在本機算，零 HTTP。**
    pub pending_notebooks: Vec<String>,
    /// 檢查了幾本。`tracked - pending` 就是這一輪會被跳過的數量。
    pub checked_notebooks: u32,
}

/// 帶著雲端快照的同步工作階段。
///
/// # 為什麼要有這個物件
///
/// 舊流程每同步一本筆記本就打一次 `files.list`，**不管有沒有變動**。
/// 50 本筆記 = 50 次往返，而其中 49 次的答案是「沒事」。
///
/// 這個物件握著一份 [`RemoteIndex`]：一次 `changes.list` 更新它，
/// 之後所有「要上傳什麼、要下載什麼、這本要不要碰」的判斷**全部在本機算，
/// 零 HTTP**。這就是「沒變動的就不要再花時間去動它」真正成立的地方。
///
/// 快照要由平台層持久化（[`Self::index_json`]），否則每次開 App 都要
/// 重建一次基準。
/// 雲端檔案歸屬稽核的結果。
///
/// 回答的是「追蹤的這幾千個檔案裡，有多少是活的」—— 在這之前沒有人
/// 答得出來。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCloudAudit {
    /// 屬於活著的筆記本。
    pub live: u32,
    /// 屬於已刪除（有墓碑）的筆記本 —— **可以回收**。
    pub deleted: u32,
    /// 路徑形狀對，但這台裝置的索引裡沒有這個 id。
    ///
    /// **不是垃圾**：多半是另一台裝置剛建立、索引還沒拉到。只回報。
    pub unknown: u32,
    /// 不符合任何已知形狀。
    pub foreign: u32,
    /// 索引檔本身。
    pub index: u32,
    /// 沒見過的筆記本 id（對應 `unknown`）。
    pub unknown_notebooks: Vec<String>,
    /// 可回收的檔案路徑。
    pub collectable: Vec<String>,
}

/// 稽核雲端上的每一個檔案：它屬於誰、還需不需要。
///
/// **純計算，一次 HTTP 都不打** —— 兩份輸入都是平台層本來就存著的快照。
#[uniffi::export]
pub fn cloud_audit(remote_index_json: String, library_index_json: String) -> FfiCloudAudit {
    let remote = RemoteIndex::from_json(&remote_index_json);
    let library = padnote_sync::library::LibraryIndex::from_json(&library_index_json);
    let paths: Vec<&str> = remote.files.keys().map(String::as_str).collect();
    let result = padnote_sync::audit::audit(paths, &library);
    FfiCloudAudit {
        live: result.count(padnote_sync::audit::FileClass::Live),
        deleted: result.count(padnote_sync::audit::FileClass::Deleted),
        unknown: result.count(padnote_sync::audit::FileClass::Unknown),
        foreign: result.count(padnote_sync::audit::FileClass::Foreign),
        index: result.count(padnote_sync::audit::FileClass::Index),
        unknown_notebooks: result.unknown_notebooks.into_iter().collect(),
        collectable: result.collectable,
    }
}

/// 這本筆記本所有裝置的媒體墓碑合併起來。
fn merged_tombstones(package: &padnote_storage::NotebookPackage) -> padnote_sync::MediaTombstones {
    let mut out = padnote_sync::MediaTombstones::new();
    let Ok(files) = package.media_tombstone_files() else {
        return out;
    };
    for (name, _) in files {
        let device = name.trim_end_matches(".json");
        if let Ok(json) = package.read_media_tombstone(device) {
            out.merge(&padnote_sync::MediaTombstones::from_json(&json));
        }
    }
    out
}

/// **刪除一段錄音，並留下墓碑。**
///
/// 平台層刪錄音一律走這裡。只刪檔案的話，同步看到「遠端有、本機沒有」
/// 就會把它抓回來 —— 刪除永遠刪不掉，每同步一次復活一次。
#[uniffi::export]
pub fn media_delete_audio(package_path: String, name: String) -> String {
    let root = std::path::Path::new(&package_path);
    let package = match padnote_storage::NotebookPackage::open(root) {
        Ok(p) => p,
        Err(e) => return format!("開不了套件：{e}"),
    };
    if let Err(e) = package.delete_audio_file(&name) {
        return format!("刪不掉錄音 {name}：{e}");
    }
    let device = package.device().to_string();
    let mut own =
        padnote_sync::MediaTombstones::from_json(&match package.read_media_tombstone(&device) {
            Ok(json) => json,
            Err(e) => return format!("讀不到墓碑：{e}"),
        });
    // Lamport 借用文件操作那一條時鐘 —— 它本來就隨每次編輯往前走，而且
    // 已經是跨裝置單調的。另外養一條只會多一個要對齊的東西。
    let lamport = package.max_doc_lamport().saturating_add(1);
    own.mark(&name, lamport, &device);
    match package.write_media_tombstone(&device, &own.to_json()) {
        Ok(()) => String::new(),
        Err(e) => format!("寫不進墓碑：{e}"),
    }
}

/// [`FfiSyncSession::collect_garbage`] 的結果。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiGcResult {
    pub ok: bool,
    /// 回收掉幾個檔案。
    pub deleted: u32,
    /// 刪不掉幾個。下一輪會再試。
    pub failed: u32,
    /// 第一個問題。全部成功時是空字串。
    pub error: String,
}

/// [`FfiSyncSession::wipe_cloud`] 的結果。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiWipeResult {
    /// 全部刪乾淨了沒。
    pub ok: bool,
    /// 刪掉幾個。
    pub deleted: u32,
    /// 刪不掉幾個。**不是零的話雲端是半清空的狀態**，要再跑一次。
    pub failed: u32,
    /// 第一個刪不掉的檔案與原因。全部成功時是空字串。
    pub error: String,
    pub needs_reauth: bool,
}

#[derive(Debug, uniffi::Object)]
pub struct FfiSyncSession {
    drive: GDriveProvider<ForeignHttp>,
    index: std::sync::Mutex<RemoteIndex>,
    /// 上一輪看到的本機錄音長度。用來分辨「還在錄」與「錄完了」，
    /// 見 [`AUDIO_GROWTH_THRESHOLD`]。**不持久化** —— 重開 App 之後
    /// 多傳一次而已，沒有正確性問題。
    seen_sizes: std::sync::Mutex<SeenSizes>,
}

#[uniffi::export]
impl FfiSyncSession {
    /// `remote_index_json` 是上次存下來的快照；空字串表示還沒有。
    #[uniffi::constructor]
    pub fn create(http: Arc<dyn FfiDriveHttp>, remote_index_json: String) -> Arc<Self> {
        Arc::new(Self {
            drive: GDriveProvider::new(ForeignHttp(http)),
            index: std::sync::Mutex::new(RemoteIndex::from_json(&remote_index_json)),
            seen_sizes: std::sync::Mutex::new(SeenSizes::new()),
        })
    }

    /// **把這個帳號在雲端的同步資料整個刪掉。**
    ///
    /// # 這是不可逆的
    ///
    /// 只存在雲端的內容（某台裝置改完之後就再也沒打開過的）會一起消失。
    /// 呼叫端**必須**先讓使用者確認，而且要講清楚刪的是什麼。
    ///
    /// # 為什麼需要它
    ///
    /// 資料放在 Drive 的 `appDataFolder`，那是隱藏區 —— 使用者在
    /// drive.google.com 的檔案列表裡**看不到也刪不掉**。唯一的手動路徑是
    /// Drive 設定 →「管理應用程式」→「刪除隱藏的應用程式資料」，而那條
    /// 路徑只清雲端：本機的遠端快照還指著已經不存在的檔案，下一輪同步
    /// 會拿著一份幻覺去比對。所以重置要由 App 來做，兩邊一起清。
    ///
    /// # 回傳
    ///
    /// 刪掉的檔案數。**刪不掉的不會讓整件事失敗** —— 半途停下來留下的是
    /// 一個更難解釋的狀態（清一半的雲端）。刪不掉的數量另外回報。
    pub fn wipe_cloud(&self) -> FfiWipeResult {
        let files = match self.drive.list_all_remote() {
            Ok(files) => files,
            Err(e) => {
                let needs_reauth = matches!(e, SyncError::PermissionDenied(_));
                return FfiWipeResult {
                    ok: false,
                    deleted: 0,
                    failed: 0,
                    error: format!("列不出雲端檔案：{e}"),
                    needs_reauth,
                };
            }
        };
        let deleted = std::sync::atomic::AtomicU32::new(0);
        let failed = std::sync::atomic::AtomicU32::new(0);
        let first_error = std::sync::Mutex::new(String::new());

        // 平行刪除以加速 25000 個檔案的清除
        let thread_count = 8;
        let chunk_size = (files.len() / thread_count).max(1);
        let chunks: Vec<_> = files.chunks(chunk_size).collect();

        std::thread::scope(|s| {
            for chunk in chunks {
                let deleted_ref = &deleted;
                let failed_ref = &failed;
                let first_error_ref = &first_error;

                s.spawn(move || {
                    for file in chunk {
                        match self.drive.delete_by_id(&file.id) {
                            Ok(()) => {
                                deleted_ref.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                            }
                            Err(e) => {
                                failed_ref.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                                let mut err = first_error_ref.lock().unwrap();
                                if err.is_empty() {
                                    *err = format!("{}：{e}", file.name);
                                }
                            }
                        }
                    }
                });
            }
        });

        let deleted = deleted.load(std::sync::atomic::Ordering::Relaxed);
        let failed = failed.load(std::sync::atomic::Ordering::Relaxed);
        let first_error = first_error.into_inner().unwrap();
        // 本機的快照也要一起歸零，否則下一輪會拿著一份「雲端還有這些檔案」
        // 的幻覺去比對，而那比什麼都沒清更難查。
        *self.index.lock().unwrap() = RemoteIndex::from_json("");
        *self.seen_sizes.lock().unwrap() = SeenSizes::new();
        FfiWipeResult {
            ok: failed == 0,
            deleted,
            failed,
            error: first_error,
            needs_reauth: false,
        }
    }

    /// **回收已刪除筆記本留在雲端的檔案。**
    ///
    /// # 安全前提是「索引夠新」，不是「墓碑夠舊」
    ///
    /// 直覺會想加一條「墓碑放滿 N 天才回收」。但墓碑只有 Lamport 計數、
    /// 沒有牆上時鐘，量不出年紀 —— 而且那條規則要防的事其實不會發生：
    /// 墓碑一旦進了雲端索引，任何裝置**合併之後**都會收斂到刪除
    /// （墓碑在同一時戳上優先），所以沒有人會把檔案再傳回來。
    ///
    /// 真正的前提是**這一輪的快照要是可信的**。快照還沒建立時
    /// （`needs_rebuild`）我們對雲端的認識是空的，那時候「沒看到的東西」
    /// 一律不能當成垃圾 —— 所以直接拒絕執行。
    ///
    /// # 絕不碰的東西
    ///
    /// 只刪 [`padnote_sync::audit::FileClass::Deleted`]。`Unknown`（索引裡
    /// 沒有這個 id）永遠不刪 —— 那多半是另一台裝置剛建立、這台還沒拉到
    /// 索引，刪掉等於把別台剛寫的東西吃掉。
    pub fn collect_garbage(&self, library_index_json: String) -> FfiGcResult {
        if self.index.lock().unwrap().needs_rebuild() {
            return FfiGcResult {
                ok: false,
                deleted: 0,
                failed: 0,
                error: "雲端快照還沒建立，這一輪不知道雲端上有什麼 —— 先同步一次再回收".to_string(),
            };
        }
        let library = padnote_sync::library::LibraryIndex::from_json(&library_index_json);
        let targets: Vec<String> = {
            let index = self.index.lock().unwrap();
            let paths: Vec<&str> = index.files.keys().map(String::as_str).collect();
            padnote_sync::audit::audit(paths, &library).collectable
        };

        let mut deleted = 0u32;
        let mut failed = 0u32;
        let mut first_error = String::new();
        for path in &targets {
            let file_id = {
                let index = self.index.lock().unwrap();
                index.get(path).map(|f| f.id.clone())
            };
            let Some(file_id) = file_id else { continue };
            match self.drive.delete_by_id(&file_id) {
                Ok(()) => {
                    self.index.lock().unwrap().note_delete(path);
                    deleted += 1;
                }
                Err(e) => {
                    failed += 1;
                    if first_error.is_empty() {
                        first_error = format!("{path}：{e}");
                    }
                }
            }
        }
        FfiGcResult {
            ok: failed == 0,
            deleted,
            failed,
            error: first_error,
        }
    }

    /// 目前的快照。**平台層每輪同步後都要存回去。**
    pub fn index_json(&self) -> String {
        self.index.lock().unwrap().to_json()
    }

    /// 快照裡有幾個檔案。
    pub fn tracked_files(&self) -> u32 {
        self.index.lock().unwrap().len() as u32
    }

    /// 快照還沒建立（下一次 refresh 會走全量列舉）。
    pub fn needs_rebuild(&self) -> bool {
        self.index.lock().unwrap().needs_rebuild()
    }

    /// 把雲端的變動拉進快照。**一輪同步只需要呼叫這一次。**
    ///
    /// 沒有游標時走全量列舉建立基準；有游標時走 `changes.list`，
    /// 沒有變動就是一次空回應。游標過期（Drive 回 410）會自動退回重建。
    ///
    /// **這個方法會同步地等平台的 HTTP 回來，不要在主執行緒呼叫。**
    pub fn refresh(&self) -> FfiRefreshResult {
        let needs_rebuild = self.index.lock().unwrap().needs_rebuild();
        if needs_rebuild {
            return self.rebuild();
        }
        let token = self.index.lock().unwrap().page_token.clone();
        match self.drive.fetch_changes(&token) {
            Ok(batch) => {
                let mut index = self.index.lock().unwrap();
                let changed = batch.changes.len() as u32;
                for change in &batch.changes {
                    index.apply(
                        &change.file_id,
                        change.name.as_deref(),
                        change.size,
                        change.gone,
                    );
                }
                index.page_token = batch.new_token;
                FfiRefreshResult {
                    ok: true,
                    changed,
                    full_rebuild: false,
                    tracked_files: index.len() as u32,
                    error: String::new(),
                    needs_reauth: false,
                }
            }
            // 游標過期是正常的（Drive 大約保留數週）。退回重建一次，
            // 那是唯一的慢路徑，而且自我修復。
            Err(e) if padnote_sync::gdrive::is_cursor_expired(&e) => self.rebuild(),
            Err(e) => refresh_failed(e),
        }
    }

    /// 這本筆記本有沒有事要做。**完全在本機算，一次 HTTP 都不打。**
    ///
    /// 這是整個改善的重點：使用者要的「沒變動的就不要再花時間去動它」，
    /// 在舊流程裡做不到 —— 要知道有沒有變動就得先問雲端，而問本身就是成本。
    ///
    /// 快照還沒建立時一律回 true（不知道就別跳過）。
    pub fn notebook_needs_sync(&self, package_path: String, notebook_id: String) -> bool {
        let index = self.index.lock().unwrap();
        notebook_differs(&index, &package_path, &notebook_id)
    }

    /// 同步一本筆記本的 oplog 與媒體。
    ///
    /// `device_id` 是這台裝置的 id：壓實與雲端清理**只碰自己的檔案**。
    ///
    /// **這個方法會同步地等平台的 HTTP 回來，不要在主執行緒呼叫。**
    pub fn sync_notebook(
        &self,
        package_path: String,
        notebook_id: String,
        device_id: u32,
    ) -> FfiNotebookSyncResult {
        let mut index = self.index.lock().unwrap();
        let ops = sync_notebook_ops(
            &self.drive,
            &mut index,
            &package_path,
            &notebook_id,
            device_id,
        );
        if !ops.ok {
            return ops;
        }
        // 媒體接在 oplog 之後。順序很重要：oplog 裡的 AddImage 會指向一個
        // blob id，媒體還沒到的話，那一頁會有一個指向不存在檔案的圖片區塊。
        let mut seen = self.seen_sizes.lock().unwrap();
        let media = sync_notebook_media(
            &self.drive,
            &mut index,
            &mut seen,
            &package_path,
            &notebook_id,
        );
        FfiNotebookSyncResult {
            ok: media.ok,
            uploaded: ops.uploaded + media.uploaded,
            downloaded: ops.downloaded + media.downloaded,
            error: media.error,
            needs_reauth: media.needs_reauth,
            warnings: Vec::new(),
        }
    }

    /// 把一本只存在於雲端的筆記本整本抓下來。
    pub fn clone_notebook(
        &self,
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
        let result = {
            let mut index = self.index.lock().unwrap();
            sync_notebook_ops(&self.drive, &mut index, &package_path, &notebook_id, 0)
        };
        if !result.ok {
            let _ = std::fs::remove_dir_all(root);
            return result;
        }
        // 只有 manifest 的空殼比沒有更糟：下一輪看到目錄存在就會跳過重抓，
        // 使用者得到一本永遠打不開的筆記。
        let has_ops = padnote_storage::NotebookPackage::open(root)
            .map(|p| !p.doc_op_files().unwrap_or_default().is_empty())
            .unwrap_or(false);
        if !has_ops {
            let _ = std::fs::remove_dir_all(root);
            return notebook_failed(
                "雲端尚無此筆記本之操作記錄，已清理暫存等待來源端上傳".to_string(),
            );
        }
        let media = {
            let mut index = self.index.lock().unwrap();
            let mut seen = self.seen_sizes.lock().unwrap();
            sync_notebook_media(
                &self.drive,
                &mut index,
                &mut seen,
                &package_path,
                &notebook_id,
            )
        };
        FfiNotebookSyncResult {
            ok: media.ok,
            uploaded: result.uploaded + media.uploaded,
            downloaded: result.downloaded + media.downloaded,
            error: media.error,
            needs_reauth: media.needs_reauth,
            warnings: Vec::new(),
        }
    }

    /// 中繼資料（設定 + 筆記本索引）。
    ///
    /// **這個方法會同步地等平台的 HTTP 回來，不要在主執行緒呼叫。**
    pub fn sync_metadata(
        &self,
        local_settings_json: String,
        local_index_json: String,
    ) -> FfiCloudSyncResult {
        sync_metadata_with(&self.drive, local_settings_json, local_index_json)
    }
}

impl FfiSyncSession {
    /// 全量列舉重建基準。**先拿游標再列舉** —— 順序反過來的話，
    /// 列舉期間發生的變動會落在游標之前，永遠補不回來。
    fn rebuild(&self) -> FfiRefreshResult {
        let token = match self.drive.start_page_token() {
            Ok(t) => t,
            Err(e) => return refresh_failed(e),
        };
        let files = match self.drive.list_all_remote() {
            Ok(f) => f,
            Err(e) => return refresh_failed(e),
        };
        let mut index = self.index.lock().unwrap();
        let count = files.len() as u32;
        index.replace_files(files);
        index.page_token = token;
        FfiRefreshResult {
            ok: true,
            changed: count,
            full_rebuild: true,
            tracked_files: index.len() as u32,
            error: String::new(),
            needs_reauth: false,
        }
    }
}

/// 同步狀態快照（P4「同步醫生」）。**零 HTTP、也不需要權杖。**
///
/// 診斷畫面在**網路不通的時候最需要**，所以它不能依賴一個要先去換權杖
/// 的工作階段。這裡吃的是平台存下來的快照 JSON。
///
/// `package_paths` 與 `notebook_ids` 一一對應。長度不同時以較短的為準 ——
/// 診斷畫面不該因為呼叫端少傳一個而整個掛掉。
#[uniffi::export]
pub fn sync_diagnose(
    remote_index_json: String,
    package_paths: Vec<String>,
    notebook_ids: Vec<String>,
) -> FfiSyncDiagnostics {
    let index = RemoteIndex::from_json(&remote_index_json);
    diagnose_index(&index, package_paths, notebook_ids)
}

fn diagnose_index(
    index: &RemoteIndex,
    package_paths: Vec<String>,
    notebook_ids: Vec<String>,
) -> FfiSyncDiagnostics {
    let pairs: Vec<(String, String)> = package_paths.into_iter().zip(notebook_ids).collect();
    let checked = pairs.len() as u32;
    let pending: Vec<String> = pairs
        .into_iter()
        .filter(|(path, id)| notebook_differs(index, path, id))
        .map(|(_, id)| id)
        .collect();
    FfiSyncDiagnostics {
        has_cursor: !index.needs_rebuild(),
        tracked_files: index.len() as u32,
        pending_notebooks: pending,
        checked_notebooks: checked,
    }
}

/// 這本筆記本與雲端快照有沒有差異。**完全在本機算。**
///
/// 快照還沒建立時一律回 true —— 不知道就別跳過。
fn notebook_differs(index: &RemoteIndex, package_path: &str, notebook_id: &str) -> bool {
    if index.needs_rebuild() {
        return true;
    }
    let Ok(package) = padnote_storage::NotebookPackage::open(std::path::Path::new(package_path))
    else {
        return true;
    };
    if differs(
        &package.doc_op_files().unwrap_or_default(),
        &index.entries_under(&notebook_ops_prefix(notebook_id)),
    ) {
        return true;
    }
    if differs(
        &package.audio_files().unwrap_or_default(),
        &index.entries_under(&padnote_sync::paths::notebook_audio_prefix(notebook_id)),
    ) {
        return true;
    }
    // blob 是內容定址的，只看名字在不在。
    let local_blobs: std::collections::BTreeSet<String> = package
        .blobs()
        .list()
        .unwrap_or_default()
        .iter()
        .map(|id| padnote_sync::paths::canonical_name(&id.to_string()))
        .collect();
    let remote_blobs: std::collections::BTreeSet<String> = index
        .entries_under(&padnote_sync::paths::notebook_blobs_prefix(notebook_id))
        .into_keys()
        .collect();
    local_blobs != remote_blobs
}

fn refresh_failed(error: SyncError) -> FfiRefreshResult {
    let needs_reauth = matches!(error, SyncError::PermissionDenied(_));
    FfiRefreshResult {
        ok: false,
        changed: 0,
        full_rebuild: false,
        tracked_files: 0,
        error: error.to_string(),
        needs_reauth,
    }
}

/// 本機的一組 `(檔名, 長度)` 與雲端快照有沒有差異。
///
/// 兩個方向都要看：本機比較長要上傳，雲端比較長要下載。
fn differs(
    local: &[(String, u64)],
    remote: &std::collections::BTreeMap<String, RemoteFile>,
) -> bool {
    let local_map: std::collections::BTreeMap<String, u64> = local
        .iter()
        .map(|(n, s)| (padnote_sync::paths::canonical_name(n), *s))
        .collect();
    for (name, size) in &local_map {
        if *size > remote.get(name).map_or(0, |f| f.size) {
            return true;
        }
    }
    for (name, file) in remote {
        if file.size > local_map.get(name).copied().unwrap_or(0) {
            return true;
        }
    }
    false
}

fn notebook_failed(error: String) -> FfiNotebookSyncResult {
    FfiNotebookSyncResult {
        ok: false,
        uploaded: 0,
        downloaded: 0,
        error,
        needs_reauth: false,
        warnings: Vec::new(),
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
        warnings: Vec::new(),
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
        /// 每一次寫入／刪除碰到的索引。`changes.list` 的游標就是這個
        /// 序列的長度 —— 與真的 Drive 一樣，游標之後的變更才會回傳。
        log: std::sync::Mutex<Vec<usize>>,
        /// 打了幾次 HTTP。**同步的成本就是這個數字**，所以要測得到。
        calls: std::sync::atomic::AtomicUsize,
    }

    impl FakeDrive {
        fn hit(&self) {
            self.calls
                .fetch_add(1, std::sync::atomic::Ordering::Relaxed);
        }

        fn call_count(&self) -> usize {
            self.calls.load(std::sync::atomic::Ordering::Relaxed)
        }

        fn reset_calls(&self) {
            self.calls.store(0, std::sync::atomic::Ordering::Relaxed);
        }

        fn note_change(&self, index: usize) {
            self.log.lock().unwrap().push(index);
        }

        /// `changes.list` 的回應。
        fn changes_since(&self, token: &str) -> String {
            let from: usize = token.parse().unwrap_or(0);
            let log = self.log.lock().unwrap();
            let files = self.files.lock().unwrap();
            let mut seen = std::collections::BTreeSet::new();
            let mut out = Vec::new();
            for index in log.iter().skip(from) {
                if !seen.insert(*index) {
                    continue;
                }
                let Some((name, data)) = files.get(*index) else {
                    continue;
                };
                if name.is_empty() {
                    out.push(format!(r#"{{"fileId":"id-{index}","removed":true}}"#));
                } else {
                    out.push(format!(
                        r#"{{"fileId":"id-{index}","removed":false,"file":{{"id":"id-{index}","name":"{name}","size":"{}","trashed":false}}}}"#,
                        data.len()
                    ));
                }
            }
            format!(
                r#"{{"changes":[{}],"newStartPageToken":"{}"}}"#,
                out.join(","),
                log.len()
            )
        }

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
            url: String,
            query: Vec<FfiQueryParam>,
        ) -> Result<String, FfiDriveError> {
            self.hit();
            if url.ends_with("changes/startPageToken") {
                return Ok(format!(
                    r#"{{"startPageToken":"{}"}}"#,
                    self.log.lock().unwrap().len()
                ));
            }
            if url.ends_with("/changes") {
                return Ok(self.changes_since(Self::query(&query, "pageToken")));
            }
            let q = Self::query(&query, "q").to_string();
            let files = self.files.lock().unwrap();
            // **索引要用全域的**，不是過濾後的序號 —— 讀取那一側是照
            // `files` 的位置去取的。用過濾後的序號會讓查詢一縮小就取到別的檔，
            // 而症狀是「下載回來的 blob 雜湊不符」，看起來像傳輸壞掉。
            let entries: Vec<String> = files
                .iter()
                .enumerate()
                .filter(|(_, (name, _))| {
                    if name.is_empty() {
                        return false;
                    }
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
            self.hit();
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
            self.hit();
            let value: serde_json::Value = serde_json::from_str(&body_json).unwrap();
            let name = value["name"].as_str().unwrap().to_string();
            let index = {
                let mut files = self.files.lock().unwrap();
                files.push((name, Vec::new()));
                files.len() - 1
            };
            self.note_change(index);
            Ok(format!(r#"{{"id":"id-{index}"}}"#))
        }

        fn patch_bytes(&self, url: String, data: Vec<u8>) -> Result<(), FfiDriveError> {
            self.write_at(&url, data)
        }

        fn delete(&self, url: String) -> Result<(), FfiDriveError> {
            self.hit();
            let index: usize = url
                .split("files/id-")
                .nth(1)
                .and_then(|s| s.split('?').next())
                .and_then(|s| s.parse().ok())
                .ok_or(FfiDriveError::NotFound { path: url.clone() })?;
            {
                let mut files = self.files.lock().unwrap();
                if let Some(slot) = files.get_mut(index) {
                    slot.0.clear();
                    slot.1.clear();
                }
            }
            self.note_change(index);
            Ok(())
        }

        fn start_resumable(&self, url: String, _body: String) -> Result<String, FfiDriveError> {
            self.hit();
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
            self.hit();
            let index: usize = url
                .split("files/id-")
                .nth(1)
                .and_then(|s| s.split('?').next())
                .and_then(|s| s.parse().ok())
                .ok_or(FfiDriveError::NotFound {
                    path: url.to_string(),
                })?;
            let ok = {
                let mut files = self.files.lock().unwrap();
                match files.get_mut(index) {
                    Some(slot) => {
                        slot.1 = data;
                        true
                    }
                    None => false,
                }
            };
            if ok {
                self.note_change(index);
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

    // ── P1：用變更游標取代全量列舉 ────────────────────────────────

    /// 建 n 本筆記本，各寫一筆操作，回傳 `(id, 套件路徑)`。
    fn many_packages(tag: &str, n: usize) -> Vec<(String, std::path::PathBuf)> {
        use padnote_doc::ops::DocOp;
        (0..n)
            .map(|i| {
                let id = format!("nb{i:04}");
                let root = tmp_package(&format!("{tag}-{i}"), 0xAA);
                let mut pkg = padnote_storage::NotebookPackage::open(&root).unwrap();
                pkg.append_doc_ops(
                    1,
                    0xAA,
                    &[DocOp::SetTitle {
                        title: format!("n{i}"),
                    }],
                )
                .unwrap();
                (id, root)
            })
            .collect()
    }

    #[test]
    fn the_doctor_reports_which_notebooks_still_have_work() {
        // 出問題時能看到的只有一串日誌。日誌答得出「發生過什麼」，
        // 答不出「現在是什麼狀態」—— 而那才是下一步要根據的東西。
        use padnote_doc::ops::DocOp;
        let fake = Arc::new(FakeDrive::default());
        let http: Arc<dyn FfiDriveHttp> = fake.clone();
        let books = many_packages("doctor", 3);

        let session = FfiSyncSession::create(http, String::new());
        let before = sync_diagnose(
            session.index_json(),
            books
                .iter()
                .map(|(_, r)| r.to_string_lossy().into())
                .collect(),
            books.iter().map(|(id, _)| id.clone()).collect(),
        );
        assert!(!before.has_cursor, "還沒 refresh 就不該宣稱有游標");
        assert_eq!(
            before.pending_notebooks.len(),
            3,
            "不知道狀態時一律當成要同步"
        );

        assert!(session.refresh().ok);
        for (id, root) in &books {
            assert!(
                session
                    .sync_notebook(root.to_string_lossy().into(), id.clone(), 0xAA)
                    .ok
            );
        }
        session.refresh();

        let after = sync_diagnose(
            session.index_json(),
            books
                .iter()
                .map(|(_, r)| r.to_string_lossy().into())
                .collect(),
            books.iter().map(|(id, _)| id.clone()).collect(),
        );
        assert!(after.has_cursor);
        assert!(after.tracked_files > 0);
        assert_eq!(after.checked_notebooks, 3);
        assert!(after.pending_notebooks.is_empty(), "全部同步過了還說有待辦");

        // 再改一本，它就該單獨出現在待辦裡。
        let mut pkg = padnote_storage::NotebookPackage::open(&books[1].1).unwrap();
        pkg.append_doc_ops(
            5,
            0xAA,
            &[DocOp::SetTitle {
                title: "改過".into(),
            }],
        )
        .unwrap();
        let changed = sync_diagnose(
            session.index_json(),
            books
                .iter()
                .map(|(_, r)| r.to_string_lossy().into())
                .collect(),
            books.iter().map(|(id, _)| id.clone()).collect(),
        );
        assert_eq!(changed.pending_notebooks, vec![books[1].0.clone()]);
    }

    #[test]
    fn a_round_with_nothing_to_do_costs_exactly_one_http_call() {
        // **這條測試就是 P1 的目的本身。**
        //
        // 舊流程每同步一本筆記本就打一次 `files.list`，不管有沒有變動 ——
        // 20 本筆記 = 20 次往返，而其中 20 次的答案都是「沒事」。
        // 使用者要的「沒變動的就不要花時間去動它」在那個結構下做不到。
        //
        // 現在：一次 `changes.list`，其餘全部在本機算。
        let fake = Arc::new(FakeDrive::default());
        let http: Arc<dyn FfiDriveHttp> = fake.clone();
        let books = many_packages("cheap", 20);

        // 第一輪：建立基準 + 全部上傳。
        let session = FfiSyncSession::create(http.clone(), String::new());
        assert!(session.refresh().ok);
        for (id, root) in &books {
            let r = session.sync_notebook(root.to_string_lossy().into(), id.clone(), 0xAA);
            assert!(r.ok, "{}", r.error);
        }
        let saved = session.index_json();

        // 第二輪：全新的 session（模擬重開 App），帶著存下來的快照。
        let session2 = FfiSyncSession::create(http.clone(), saved);
        fake.reset_calls();
        let refreshed = session2.refresh();
        assert!(refreshed.ok, "{}", refreshed.error);
        assert!(!refreshed.full_rebuild, "帶著游標就不該再全量重建");

        for (id, root) in &books {
            assert!(
                !session2.notebook_needs_sync(root.to_string_lossy().into(), id.clone()),
                "沒變動的筆記本 {id} 不該被判定為要同步"
            );
        }

        assert_eq!(
            fake.call_count(),
            1,
            "20 本筆記、什麼都沒變，整輪只該打一次 HTTP（changes.list）"
        );
    }

    #[test]
    fn only_the_notebook_that_changed_needs_work() {
        // 另一台裝置改了一本，其餘 19 本一個位元組都不該碰。
        use padnote_doc::ops::DocOp;
        let fake = Arc::new(FakeDrive::default());
        let http: Arc<dyn FfiDriveHttp> = fake.clone();
        let books = many_packages("onechanged", 20);

        let session = FfiSyncSession::create(http.clone(), String::new());
        assert!(session.refresh().ok);
        for (id, root) in &books {
            assert!(
                session
                    .sync_notebook(root.to_string_lossy().into(), id.clone(), 0xAA)
                    .ok
            );
        }

        // 另一台裝置（0xBB）改了第 7 本。
        let other_root = tmp_package("onechanged-other", 0xBB);
        let mut other = padnote_storage::NotebookPackage::open(&other_root).unwrap();
        other
            .append_doc_ops(
                9,
                0xBB,
                &[DocOp::SetTitle {
                    title: "來自另一台".into(),
                }],
            )
            .unwrap();
        let other_session = FfiSyncSession::create(http.clone(), String::new());
        assert!(other_session.refresh().ok);
        assert!(
            other_session
                .sync_notebook(
                    other_root.to_string_lossy().into(),
                    books[7].0.clone(),
                    0xBB
                )
                .ok
        );

        // 回到第一台：refresh 之後只有第 7 本要動。
        session.refresh();
        let needs: Vec<&String> = books
            .iter()
            .filter(|(id, root)| {
                session.notebook_needs_sync(root.to_string_lossy().into(), id.clone())
            })
            .map(|(id, _)| id)
            .collect();
        assert_eq!(needs, vec![&books[7].0], "只有被改過的那一本該要同步");
    }

    #[test]
    fn a_deleted_cloud_file_disappears_from_the_snapshot() {
        // 刪除的變更只給 fileId。反查不到就會留下幽靈項目，
        // 而幽靈項目會讓同步以為雲端還有那個檔、然後一直想下載它。
        let fake = Arc::new(FakeDrive::default());
        let http: Arc<dyn FfiDriveHttp> = fake.clone();
        let books = many_packages("deleted", 1);
        let session = FfiSyncSession::create(http.clone(), String::new());
        assert!(session.refresh().ok);
        assert!(
            session
                .sync_notebook(
                    books[0].1.to_string_lossy().into(),
                    books[0].0.clone(),
                    0xAA
                )
                .ok
        );
        session.refresh();
        let before = session.tracked_files();
        assert!(before > 0);

        // 從雲端刪掉那個 oplog 檔。
        fake.delete("https://x/files/id-0".into()).unwrap();
        session.refresh();
        assert_eq!(session.tracked_files(), before - 1, "刪除沒有反映到快照");
    }

    #[test]
    fn an_expired_cursor_falls_back_to_a_full_rebuild() {
        // Drive 的游標大約保留數週。過期是正常事件，不是錯誤 ——
        // 當成錯誤的話，久沒開的裝置會永遠同步不了。
        #[derive(Debug)]
        struct ExpiredCursor(Arc<FakeDrive>);
        impl FfiDriveHttp for ExpiredCursor {
            fn get_json(
                &self,
                url: String,
                query: Vec<FfiQueryParam>,
            ) -> Result<String, FfiDriveError> {
                if url.ends_with("/changes") {
                    return Err(FfiDriveError::Backend {
                        detail: "HTTP 410 pageToken expired".into(),
                    });
                }
                self.0.get_json(url, query)
            }
            fn get_bytes(
                &self,
                url: String,
                range: Option<FfiByteRange>,
            ) -> Result<Vec<u8>, FfiDriveError> {
                self.0.get_bytes(url, range)
            }
            fn post_json(&self, url: String, body: String) -> Result<String, FfiDriveError> {
                self.0.post_json(url, body)
            }
            fn patch_bytes(&self, url: String, data: Vec<u8>) -> Result<(), FfiDriveError> {
                self.0.patch_bytes(url, data)
            }
            fn delete(&self, url: String) -> Result<(), FfiDriveError> {
                self.0.delete(url)
            }
            fn start_resumable(&self, url: String, b: String) -> Result<String, FfiDriveError> {
                self.0.start_resumable(url, b)
            }
            fn put_bytes(&self, url: String, data: Vec<u8>) -> Result<(), FfiDriveError> {
                self.0.put_bytes(url, data)
            }
        }

        let fake = Arc::new(FakeDrive::default());
        let books = many_packages("expired", 1);
        let warm: Arc<dyn FfiDriveHttp> = fake.clone();
        let session = FfiSyncSession::create(warm, String::new());
        assert!(session.refresh().ok);
        assert!(
            session
                .sync_notebook(
                    books[0].1.to_string_lossy().into(),
                    books[0].0.clone(),
                    0xAA
                )
                .ok
        );
        let saved = session.index_json();

        let expiring: Arc<dyn FfiDriveHttp> = Arc::new(ExpiredCursor(fake.clone()));
        let session2 = FfiSyncSession::create(expiring, saved);
        let result = session2.refresh();
        assert!(result.ok, "游標過期不該讓整輪同步失敗：{}", result.error);
        assert!(result.full_rebuild, "應該退回全量重建");
        assert!(result.tracked_files > 0);
    }

    #[test]
    fn a_broken_snapshot_rebuilds_instead_of_failing() {
        let fake = Arc::new(FakeDrive::default());
        let http: Arc<dyn FfiDriveHttp> = fake.clone();
        let session = FfiSyncSession::create(http, "{{{壞掉的 JSON".into());
        assert!(session.needs_rebuild());
        let result = session.refresh();
        assert!(result.ok);
        assert!(result.full_rebuild);
    }

    // ── P3：刪除一定排在上傳之後 ──────────────────────────────────

    #[test]
    fn compacted_fragments_are_only_deleted_after_the_compacted_file_is_uploaded() {
        // **這是一個真的會掉資料的順序錯誤的回歸測試。**
        //
        // 舊流程是：壓實 → 列舉 → **刪掉雲端被涵蓋的舊碎檔** → 上傳。
        // 中間斷網、逾時或被系統殺掉，那些操作就只剩本機這一份 ——
        // 雲端沒有、另一台裝置永遠拿不到，而且沒有任何錯誤訊息。
        use padnote_doc::ops::DocOp;

        /// 上傳一律失敗的假 Drive：模擬「刪完之後、傳到一半斷線」。
        #[derive(Debug)]
        struct UploadFails(Arc<FakeDrive>);
        impl FfiDriveHttp for UploadFails {
            fn get_json(
                &self,
                url: String,
                query: Vec<FfiQueryParam>,
            ) -> Result<String, FfiDriveError> {
                self.0.get_json(url, query)
            }
            fn get_bytes(
                &self,
                url: String,
                range: Option<FfiByteRange>,
            ) -> Result<Vec<u8>, FfiDriveError> {
                self.0.get_bytes(url, range)
            }
            fn post_json(&self, url: String, body: String) -> Result<String, FfiDriveError> {
                self.0.post_json(url, body)
            }
            fn patch_bytes(&self, _url: String, _data: Vec<u8>) -> Result<(), FfiDriveError> {
                Err(FfiDriveError::Backend {
                    detail: "斷線".into(),
                })
            }
            fn delete(&self, url: String) -> Result<(), FfiDriveError> {
                self.0.delete(url)
            }
            fn start_resumable(&self, url: String, b: String) -> Result<String, FfiDriveError> {
                self.0.start_resumable(url, b)
            }
            fn put_bytes(&self, _url: String, _data: Vec<u8>) -> Result<(), FfiDriveError> {
                Err(FfiDriveError::Backend {
                    detail: "斷線".into(),
                })
            }
        }

        let fake = Arc::new(FakeDrive::default());
        let root = tmp_package("delete-order", 0xAA);
        let mut pkg = padnote_storage::NotebookPackage::open(&root).unwrap();
        for lamport in 1..=6u64 {
            pkg.append_doc_ops(
                lamport,
                0xAA,
                &[DocOp::SetTitle {
                    title: format!("t{lamport}"),
                }],
            )
            .unwrap();
        }

        // 第一輪成功：六個碎檔都上了雲端。
        let ok_http: Arc<dyn FfiDriveHttp> = fake.clone();
        let session = FfiSyncSession::create(ok_http, String::new());
        assert!(session.refresh().ok);
        // device 0 ⇒ 不壓實，六個檔原樣上傳。
        assert!(
            session
                .sync_notebook(root.to_string_lossy().into(), "nb1".into(), 0)
                .ok
        );
        let cloud_before = fake
            .files
            .lock()
            .unwrap()
            .iter()
            .filter(|(n, _)| n.ends_with(".oplog"))
            .count();
        assert_eq!(cloud_before, 6);

        // 第二輪：壓實會發生，但上傳全部失敗。
        let failing: Arc<dyn FfiDriveHttp> = Arc::new(UploadFails(fake.clone()));
        let session2 = FfiSyncSession::create(failing, session.index_json());
        let result = session2.sync_notebook(root.to_string_lossy().into(), "nb1".into(), 0xAA);
        assert!(!result.ok, "上傳失敗就該回報失敗");

        let cloud_after = fake
            .files
            .lock()
            .unwrap()
            .iter()
            .filter(|(n, _)| n.ends_with(".oplog"))
            .count();
        assert_eq!(
            cloud_after, 6,
            "上傳還沒成功就刪掉雲端的碎檔 = 那幾筆操作只剩本機一份"
        );
    }

    #[test]
    fn a_device_never_deletes_another_devices_fragments() {
        // 只有寫那個檔的裝置知道自己壓實了哪幾個。舊版是用
        // 「lamport 比本機最大值小」去推論的，而本機可能根本沒下載過
        // 中間那個碎檔 —— 刪掉的是一份本機從來沒有過的操作。
        use padnote_doc::ops::DocOp;
        let fake = Arc::new(FakeDrive::default());
        let http: Arc<dyn FfiDriveHttp> = fake.clone();

        // 另一台裝置（0xBB）在雲端留下幾個碎檔。
        let other_root = tmp_package("foreign-frag-other", 0xBB);
        let mut other = padnote_storage::NotebookPackage::open(&other_root).unwrap();
        for lamport in 1..=3u64 {
            other
                .append_doc_ops(lamport, 0xBB, &[DocOp::SetTitle { title: "b".into() }])
                .unwrap();
        }
        let s_other = FfiSyncSession::create(http.clone(), String::new());
        assert!(s_other.refresh().ok);
        assert!(
            s_other
                .sync_notebook(other_root.to_string_lossy().into(), "nb1".into(), 0xBB)
                .ok
        );

        // 本機這一台（0xAA）寫很多自己的碎檔，然後同步。
        let root = tmp_package("foreign-frag-mine", 0xAA);
        let mut pkg = padnote_storage::NotebookPackage::open(&root).unwrap();
        for lamport in 10..=16u64 {
            pkg.append_doc_ops(lamport, 0xAA, &[DocOp::SetTitle { title: "a".into() }])
                .unwrap();
        }
        let session = FfiSyncSession::create(http.clone(), String::new());
        assert!(session.refresh().ok);
        let r = session.sync_notebook(root.to_string_lossy().into(), "nb1".into(), 0xAA);
        assert!(r.ok, "{}", r.error);

        let remaining_foreign = fake
            .files
            .lock()
            .unwrap()
            .iter()
            .filter(|(n, _)| n.ends_with("-000000bb.oplog"))
            .count();
        assert_eq!(remaining_foreign, 3, "別台裝置的碎檔一個都不該被刪");
    }

    #[test]
    fn a_device_cleans_up_its_own_compacted_fragments() {
        // 反面：自己的碎檔壓實並上傳成功之後，雲端那幾個要清掉，
        // 否則雲端無限累積，新裝置第一次同步要下載幾百個檔案。
        use padnote_doc::ops::DocOp;
        let fake = Arc::new(FakeDrive::default());
        let http: Arc<dyn FfiDriveHttp> = fake.clone();

        let root = tmp_package("own-cleanup", 0xAA);
        let mut pkg = padnote_storage::NotebookPackage::open(&root).unwrap();
        for lamport in 1..=6u64 {
            pkg.append_doc_ops(lamport, 0xAA, &[DocOp::SetTitle { title: "a".into() }])
                .unwrap();
        }
        // 先把六個碎檔原樣推上雲端（device 0 ⇒ 不壓實）。
        let s0 = FfiSyncSession::create(http.clone(), String::new());
        assert!(s0.refresh().ok);
        assert!(
            s0.sync_notebook(root.to_string_lossy().into(), "nb1".into(), 0)
                .ok
        );

        // 再以自己的 device id 同步一次：壓實 → 上傳 → 清掉自己的舊碎檔。
        let s1 = FfiSyncSession::create(http.clone(), s0.index_json());
        let r = s1.sync_notebook(root.to_string_lossy().into(), "nb1".into(), 0xAA);
        assert!(r.ok, "{}", r.error);

        let live: Vec<String> = fake
            .files
            .lock()
            .unwrap()
            .iter()
            .filter(|(n, _)| n.ends_with(".oplog"))
            .map(|(n, _)| n.clone())
            .collect();
        assert_eq!(live.len(), 1, "壓實之後雲端只該留一個：{live:?}");
        assert!(live[0].ends_with("0000000000000006-000000aa.oplog"));
    }

    #[test]
    fn compaction_does_not_lose_operations_across_two_devices() {
        // 壓實 + 清理之後，另一台裝置仍然要拿得到全部操作。
        // 這是整組刪除規則的最終驗收。
        use padnote_doc::ops::DocOp;
        let fake = Arc::new(FakeDrive::default());
        let http: Arc<dyn FfiDriveHttp> = fake.clone();

        let a_root = tmp_package("noloss-a", 0xAA);
        let mut a = padnote_storage::NotebookPackage::open(&a_root).unwrap();
        for lamport in 1..=6u64 {
            a.append_doc_ops(
                lamport,
                0xAA,
                &[DocOp::SetTitle {
                    title: format!("a{lamport}"),
                }],
            )
            .unwrap();
        }
        let sa = FfiSyncSession::create(http.clone(), String::new());
        assert!(sa.refresh().ok);
        assert!(
            sa.sync_notebook(a_root.to_string_lossy().into(), "nb1".into(), 0)
                .ok
        );
        // 第二輪壓實並清理雲端。
        assert!(
            sa.sync_notebook(a_root.to_string_lossy().into(), "nb1".into(), 0xAA)
                .ok
        );

        let b_root = tmp_package("noloss-b", 0xBB);
        let sb = FfiSyncSession::create(http.clone(), String::new());
        assert!(sb.refresh().ok);
        let r = sb.sync_notebook(b_root.to_string_lossy().into(), "nb1".into(), 0xBB);
        assert!(r.ok, "{}", r.error);

        let b = padnote_storage::NotebookPackage::open(&b_root).unwrap();
        let titles: Vec<String> = b
            .read_doc_ops()
            .unwrap()
            .into_iter()
            .filter_map(|op| match op {
                DocOp::SetTitle { title } => Some(title),
                _ => None,
            })
            .collect();
        for lamport in 1..=6u64 {
            assert!(
                titles.contains(&format!("a{lamport}")),
                "壓實之後少了第 {lamport} 筆操作：{titles:?}"
            );
        }
    }

    #[test]
    fn two_devices_converge_on_notebook_content() {
        // 這是內容層同步的主測試：A 寫、B 寫，各自同步一輪之後，
        // 兩邊都該看得到對方的 oplog 檔。
        use padnote_doc::ops::DocOp;

        let cloud: Arc<dyn FfiDriveHttp> = Arc::new(FakeDrive::default());

        let a_root = tmp_package("conv-a", 0xAA);
        let mut a = padnote_storage::NotebookPackage::open(&a_root).unwrap();
        a.append_doc_ops(
            1,
            0xAA,
            &[DocOp::SetTitle {
                title: "A 寫的".into(),
            }],
        )
        .unwrap();

        let b_root = tmp_package("conv-b", 0xBB);
        let mut b = padnote_storage::NotebookPackage::open(&b_root).unwrap();
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
        let mut a = padnote_storage::NotebookPackage::open(&a_root).unwrap();
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
        let mut pkg = padnote_storage::NotebookPackage::open(&root).unwrap();
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
    fn a_recording_still_being_written_is_not_re_uploaded_every_round() {
        // 錄音檔在錄製中會一直變長，而每次上傳都是整檔重傳。
        // P2 之後前景每 12 秒拉一次 —— 不節流的話，一段 30 MB 的錄音
        // 會在錄製期間被整檔重傳好幾十次。
        let fake = Arc::new(FakeDrive::default());
        let http: Arc<dyn FfiDriveHttp> = fake.clone();
        let root = tmp_package("media-throttle", 0xAA);
        let pkg = padnote_storage::NotebookPackage::open(&root).unwrap();
        let name = "33333333-3333-3333-3333-333333333333.opus";
        let path: String = root.to_string_lossy().into();

        let session = FfiSyncSession::create(http, String::new());
        assert!(session.refresh().ok);

        pkg.write_audio_file(name, &vec![0u8; 1000]).unwrap();
        assert_eq!(
            session
                .sync_notebook(path.clone(), "nb1".into(), 0xAA)
                .uploaded,
            1,
            "第一次一定要傳"
        );

        // 還在錄：每一輪都長一點點，但都不到門檻。
        for extra in 1..=3usize {
            pkg.write_audio_file(name, &vec![0u8; 1000 + extra * 100])
                .unwrap();
            assert_eq!(
                session
                    .sync_notebook(path.clone(), "nb1".into(), 0xAA)
                    .uploaded,
                0,
                "錄製中的小幅成長不該整檔重傳"
            );
        }

        // 錄完了：長度穩定下來，這一輪一定要傳 ——
        // 只看門檻的話，最後那一小段永遠傳不出去，雲端那份會少掉結尾。
        assert_eq!(
            session
                .sync_notebook(path.clone(), "nb1".into(), 0xAA)
                .uploaded,
            1,
            "長度穩定＝錄完了，一定要傳"
        );
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

    /// 重置要把**雲端和本機快照一起**清乾淨。
    ///
    /// 只清雲端的話（那正是使用者手動刪隱藏資料會得到的狀態），本機還留著
    /// 一份「雲端有這些檔案」的快照，下一輪同步拿著幻覺去比對 —— 那比
    /// 什麼都沒清更難查。
    #[test]
    fn wiping_the_cloud_also_clears_the_local_snapshot() {
        let fake = FakeDrive::default();
        for i in 0..3 {
            fake.files
                .lock()
                .unwrap()
                .push((format!("notebooks/nb1/ops/dev-{i}.bin"), vec![1, 2, 3]));
        }
        let cloud: Arc<dyn FfiDriveHttp> = Arc::new(fake);
        let session = FfiSyncSession::create(cloud, String::new());

        // 先建立快照，確認它真的看得到那三個檔案。
        assert!(session.refresh().ok);
        assert_eq!(session.tracked_files(), 3);

        let wiped = session.wipe_cloud();
        assert!(wiped.ok, "{}", wiped.error);
        assert_eq!(wiped.deleted, 3);
        assert_eq!(wiped.failed, 0);

        // 本機快照歸零 —— 下一輪會重新建立基準，而不是拿著幻覺去比對。
        assert_eq!(session.tracked_files(), 0);
        assert!(session.needs_rebuild());
    }

    /// 雲端本來就是空的：不是錯誤，也不該炸掉。
    /// 回收只動「有墓碑」的那些，**而且絕不碰沒見過的**。
    #[test]
    fn garbage_collection_removes_deleted_notebooks_but_spares_unseen_ones() {
        let fake = FakeDrive::default();
        for path in [
            "notebooks/gone/doc/ops/dev-a.bin",
            "notebooks/gone/media/blobs/x",
            "notebooks/live/doc/ops/dev-a.bin",
            "notebooks/mystery/doc/ops/dev-b.bin",
        ] {
            fake.files.lock().unwrap().push((path.to_string(), vec![1]));
        }
        let cloud: Arc<dyn FfiDriveHttp> = Arc::new(fake);
        let session = FfiSyncSession::create(cloud, String::new());
        assert!(session.refresh().ok);
        assert_eq!(session.tracked_files(), 4);

        // 索引：live 活著、gone 有墓碑、mystery 完全沒提到。
        let mut library = padnote_sync::library::LibraryIndex::default();
        for (id, deleted) in [("live", false), ("gone", true)] {
            library.upsert(padnote_sync::library::LibraryItem {
                id: id.to_string(),
                kind: padnote_sync::library::ItemKind::Notebook,
                title: id.to_string(),
                parent_id: None,
                lamport: 1,
                device: "dev-a".to_string(),
                deleted,
            });
        }

        let result = session.collect_garbage(library.to_json());
        assert!(result.ok, "{}", result.error);
        assert_eq!(result.deleted, 2, "只有 gone 的兩個檔案該被回收");

        // live 與 mystery 都要還在。mystery 那一條是安全底線：
        // 它多半是另一台裝置剛建立、這台還沒拉到索引。
        assert_eq!(session.tracked_files(), 2);
    }

    /// 快照還沒建立時，我們對雲端的認識是空的 —— 那時候什麼都不能回收。
    #[test]
    fn garbage_collection_refuses_to_run_without_a_snapshot() {
        let cloud: Arc<dyn FfiDriveHttp> = Arc::new(FakeDrive::default());
        let session = FfiSyncSession::create(cloud, String::new());
        // 沒有 refresh() —— 快照還沒建立。
        let result = session.collect_garbage("{}".to_string());
        assert!(!result.ok);
        assert_eq!(result.deleted, 0);
        assert!(result.error.contains("還沒建立"), "{}", result.error);
    }

    /// **刪掉的錄音會復活。**（使用者 2026-09-25 回報「一直無法真正同步」）
    ///
    /// 下載那一段的條件是「遠端有、本機沒有就抓回來」。使用者刪掉一段錄音
    /// 之後本機長度變成 0，下一輪同步就把它從雲端抓回來 —— 刪除永遠刪不掉，
    /// 而且每同步一次就復活一次。
    ///
    /// 這正是 `library.rs` 開頭警告的那個錯誤（刪除必須是明確事件，不能從
    /// 「檔案不見了」推論），只是媒體檔這一層還沒有墓碑。
    ///
    #[test]
    fn a_deleted_recording_does_not_come_back() {
        let cloud: Arc<dyn FfiDriveHttp> = Arc::new(FakeDrive::default());
        let root = tmp_package("audio-del", 0xA1);
        let name = "11111111-1111-1111-1111-111111111111.opus";
        {
            let pkg = padnote_storage::NotebookPackage::open(&root).unwrap();
            pkg.write_audio_file(name, b"A-audio").unwrap();
        }
        let path: String = root.to_string_lossy().into();

        // 傳上去。
        let first = gdrive_sync_media(cloud.clone(), path.clone(), "nb1".into());
        assert!(first.ok, "{}", first.error);
        assert_eq!(first.uploaded, 1);

        // 使用者把它刪掉。**一定要走留墓碑的那條路**，只刪檔案是不夠的。
        let err = media_delete_audio(path.clone(), name.to_string());
        assert!(err.is_empty(), "{err}");

        // 再同步一次 —— **不可以把它抓回來**。
        let second = gdrive_sync_media(cloud, path, "nb1".into());
        assert!(second.ok, "{}", second.error);
        assert_eq!(second.downloaded, 0, "刪掉的錄音不可以被抓回來");

        let pkg = padnote_storage::NotebookPackage::open(&root).unwrap();
        assert!(
            pkg.audio_files().unwrap().is_empty(),
            "刪掉的錄音復活了 —— 刪除沒有傳播"
        );
    }

    /// **使用者要的那件事：A 刪掉的錄音，B 上也要不見。**
    ///
    /// 這是 2026-09-25 那條時間線的媒體版本。索引層本來就會傳播刪除
    /// （`library::user_scenario` 四條測試），媒體層在這之前不會。
    #[test]
    fn deleting_a_recording_on_one_device_removes_it_on_the_other() {
        let cloud: Arc<dyn FfiDriveHttp> = Arc::new(FakeDrive::default());
        let name = "22222222-2222-2222-2222-222222222222.opus";

        let a_root = tmp_package("tomb-a", 0xA1);
        let b_root = tmp_package("tomb-b", 0xB2);
        let a_path: String = a_root.to_string_lossy().into();
        let b_path: String = b_root.to_string_lossy().into();

        // A 錄了一段並傳上去。
        padnote_storage::NotebookPackage::open(&a_root)
            .unwrap()
            .write_audio_file(name, b"A-audio")
            .unwrap();
        assert!(gdrive_sync_media(cloud.clone(), a_path.clone(), "nb1".into()).ok);

        // B 同步，拿到那段錄音。
        let b_first = gdrive_sync_media(cloud.clone(), b_path.clone(), "nb1".into());
        assert!(b_first.ok, "{}", b_first.error);
        assert_eq!(
            padnote_storage::NotebookPackage::open(&b_root)
                .unwrap()
                .audio_files()
                .unwrap()
                .len(),
            1,
            "B 要先拿得到才談得上刪除"
        );

        // A 刪掉它，同步。
        let err = media_delete_audio(a_path.clone(), name.to_string());
        assert!(err.is_empty(), "{err}");
        let a_second = gdrive_sync_media(cloud.clone(), a_path, "nb1".into());
        assert!(a_second.ok, "{}", a_second.error);

        // B 再同步一次 —— **那段錄音要消失**。
        let b_second = gdrive_sync_media(cloud, b_path, "nb1".into());
        assert!(b_second.ok, "{}", b_second.error);
        let b_after = padnote_storage::NotebookPackage::open(&b_root).unwrap();
        assert!(
            b_after.audio_files().unwrap().is_empty(),
            "A 刪掉的錄音在 B 上還在 —— 刪除沒有傳播：{:?}",
            b_after.audio_files().unwrap()
        );
    }

    #[test]
    fn wiping_an_empty_cloud_is_fine() {
        let cloud: Arc<dyn FfiDriveHttp> = Arc::new(FakeDrive::default());
        let session = FfiSyncSession::create(cloud, String::new());
        let wiped = session.wipe_cloud();
        assert!(wiped.ok);
        assert_eq!(wiped.deleted, 0);
        assert_eq!(wiped.failed, 0);
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

        // **不致命。** 一個媒體檔拿不回來，不該是「這本筆記不能同步」的
        // 理由 —— 原本這裡是整本中止，於是雲端上一個上傳到一半的殘骸就
        // 讓那本筆記的筆跡、錄音、文字全部停住，而且每一輪都再撞一次。
        assert!(
            result.ok,
            "壞掉的 blob 不該讓整本筆記失敗：{}",
            result.error
        );
        assert_eq!(
            result.warnings.len(),
            1,
            "要留下一條看得見的警告：{:?}",
            result.warnings
        );
        assert!(
            result.warnings[0].contains("雜湊不符"),
            "{:?}",
            result.warnings
        );

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
