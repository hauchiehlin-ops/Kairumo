//! Google Drive `appDataFolder` provider（ADR-0011 / WP31）。
//!
//! # 這個檔案原本沒有被編譯
//!
//! 它早就存在，但 `lib.rs` 裡沒有 `pub mod gdrive;` —— 所以**從來沒有進過
//! 編譯**，裡面的 `unimplemented!()`、少掉的分頁、沒有跳脫的查詢字串
//! 全都沒有人發現。加進模組樹是這次修正的第一步，也是最重要的一步：
//! 沒被編譯的程式碼不是「還沒用到」，是「不知道會不會動」。
//!
//! # 為什麼 HTTP 被抽成 trait
//!
//! Drive 的行為有一半在**查詢字串與分頁**上：前綴怎麼轉成 `q=`、名稱裡的
//! 單引號怎麼跳脫、`nextPageToken` 有沒有跟到底。這些不接網路就驗得了，
//! 但只要 HTTP 寫死在方法裡就一行都測不到。抽一層之後，測試用假的 Drive
//! 就能把這些邏輯釘住。
//!
//! # Drive 的檔名是路徑
//!
//! `appDataFolder` 底下不建真的資料夾，整條路徑（含斜線）就是檔名，
//! 與 `format-spec.md` §7.0 的佈局一致。Drive 允許檔名重複，所以
//! **同一個路徑可能對應多個檔案 id**；這裡一律取最新修改的那一個，
//! 並且忽略在垃圾桶裡的。

use crate::provider::{CloudProvider, RemoteEntry, SyncError};
use serde_json::{Value, json};
use std::collections::{HashMap, HashSet};
use std::fmt::Debug;
use std::ops::Range;
use std::sync::Mutex;

const FILES_URL: &str = "https://www.googleapis.com/drive/v3/files";
const UPLOAD_URL: &str = "https://www.googleapis.com/upload/drive/v3/files";
const CHANGES_URL: &str = "https://www.googleapis.com/drive/v3/changes";
const CHANGES_START_TOKEN_URL: &str = "https://www.googleapis.com/drive/v3/changes/startPageToken";

/// Drive 單次上傳（`uploadType=media`）的大小上限是 5 MB。
///
/// 超過就必須走可續傳上傳。手機拍的照片很容易 3–8 MB，而 blob 存的是
/// **原始位元組**（只有顯示尺寸被縮小），所以這不是邊角情況 ——
/// 不處理的話，使用者一放照片同步就壞。
///
/// 門檻取 4 MiB 留一點餘裕：Drive 算的是整個請求，不只是內容。
pub const SIMPLE_UPLOAD_LIMIT: usize = 4 * 1024 * 1024;

/// Drive REST 呼叫。抽出來是為了讓查詢與分頁邏輯測得到，見模組說明。
pub trait DriveHttp: Send + Sync + Debug {
    fn get_json(&self, url: &str, query: &[(String, String)]) -> Result<Value, SyncError>;
    fn get_bytes(&self, url: &str, range: Option<Range<u64>>) -> Result<Vec<u8>, SyncError>;
    fn post_json(&self, url: &str, body: &Value) -> Result<Value, SyncError>;
    fn patch_bytes(&self, url: &str, data: &[u8]) -> Result<(), SyncError>;
    fn delete(&self, url: &str) -> Result<(), SyncError>;

    /// 開一個可續傳上傳的工作階段，回傳工作階段 URI。
    ///
    /// Drive 把那個 URI 放在**回應標頭 `Location`** 裡，不是 body ——
    /// 所以這一步只有平台層做得到（核心看不到標頭）。
    fn start_resumable(&self, url: &str, body: &Value) -> Result<String, SyncError>;

    /// 把位元組 PUT 到可續傳的工作階段 URI。
    fn put_bytes(&self, url: &str, data: &[u8]) -> Result<(), SyncError>;
}

/// Drive 查詢字串裡的字面值跳脫。
///
/// `q=name = 'foo'` 的單引號與反斜線都要跳脫。不跳脫的話，一個含有單引號
/// 的路徑會讓整個查詢語法錯誤 —— Drive 回 400，而錯誤訊息完全不會提到
/// 是哪一個檔名害的。
pub fn escape_drive_literal(value: &str) -> String {
    value.replace('\\', "\\\\").replace('\'', "\\'")
}

/// 列出某個前綴底下的檔案時用的 `q`。
///
/// **一律加 `trashed = false`。** 使用者（或另一台裝置）刪掉的檔案會留在
/// 垃圾桶裡，Drive 預設還是查得到；不濾掉的話，已經刪除的 chunk 會被
/// 當成還在，同步引擎就會重新拉回已經刪掉的內容。
pub fn list_query(prefix: &str) -> String {
    if prefix.is_empty() {
        "'appDataFolder' in parents and trashed = false".to_string()
    } else {
        format!(
            "'appDataFolder' in parents and trashed = false and name contains '{}'",
            escape_drive_literal(prefix)
        )
    }
}

/// 找特定路徑（= 完整檔名）時用的 `q`。
pub fn exact_query(path: &str) -> String {
    format!(
        "'appDataFolder' in parents and trashed = false and name = '{}'",
        escape_drive_literal(path)
    )
}

/// Drive 的 `files.list` 回應 → `RemoteEntry`。
///
/// `name contains` 是**子字串**比對，不是前綴：查 `sync` 也會撈到
/// `notebooks/x/resync.bin`。所以拿回來之後還要自己用 `starts_with` 再濾一次。
fn entries_from(page: &Value, prefix: &str) -> Vec<RemoteEntry> {
    let prefix_lower = prefix.to_lowercase();
    page.get("files")
        .and_then(Value::as_array)
        .map(|files| {
            files
                .iter()
                .filter_map(|f| {
                    let name = f.get("name")?.as_str()?.to_string();
                    if !name.to_lowercase().starts_with(&prefix_lower) {
                        return None;
                    }
                    // size 在 Drive 是字串（JSON 的數字精度不夠放 64 位元）。
                    // 資料夾與 Google 原生文件沒有 size，當成 0。
                    let size = f
                        .get("size")
                        .and_then(Value::as_str)
                        .and_then(|s| s.parse::<u64>().ok())
                        .unwrap_or(0);
                    Some(RemoteEntry { path: name, size })
                })
                .collect()
        })
        .unwrap_or_default()
}

/// `changes.list` 回來的一筆變更。
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DriveChange {
    pub file_id: String,
    /// 刪除的變更**沒有名字**，只有 id。
    pub name: Option<String>,
    pub size: u64,
    /// 被刪除或丟進垃圾桶。
    pub gone: bool,
}

/// 一次 `changes.list` 的結果。
#[derive(Clone, Debug, Default)]
pub struct DriveChangeBatch {
    pub changes: Vec<DriveChange>,
    /// 下一次要用的游標。
    pub new_token: String,
}

/// 游標過期（Drive 回 410）。要退回一次全量列舉重建基準。
///
/// 只認 410：網路錯誤或 5xx 也當成過期的話，一次斷網就會觸發全量重建，
/// 而那正是我們想避開的昂貴路徑。
pub fn is_cursor_expired(error: &SyncError) -> bool {
    matches!(error, SyncError::Backend(detail) if detail.contains("410"))
}

/// Google Drive Provider。
#[derive(Debug)]
pub struct GDriveProvider<H: DriveHttp> {
    http: H,
    id_cache: Mutex<HashMap<String, String>>,
    deleted_paths: Mutex<HashSet<String>>,
}

impl<H: DriveHttp> GDriveProvider<H> {
    pub fn new(http: H) -> Self {
        Self {
            http,
            id_cache: Mutex::new(HashMap::new()),
            deleted_paths: Mutex::new(HashSet::new()),
        }
    }

    /// 逐頁把某個查詢的所有結果收齊。
    ///
    /// **分頁一定要跟到底。** Drive 預設一頁 100 筆；不跟 `nextPageToken`
    /// 的話，超過 100 個檔案之後就會安靜地少拉東西 —— 沒有錯誤、沒有警告，
    /// 只是同步永遠缺一塊。
    fn list_all(&self, q: &str, fields: &str) -> Result<Vec<Value>, SyncError> {
        let mut out = Vec::new();
        let mut page_token: Option<String> = None;
        loop {
            let mut query = vec![
                ("spaces".to_string(), "appDataFolder".to_string()),
                ("q".to_string(), q.to_string()),
                ("pageSize".to_string(), "1000".to_string()),
                (
                    "fields".to_string(),
                    format!("nextPageToken, files({fields})"),
                ),
            ];
            if let Some(token) = &page_token {
                query.push(("pageToken".to_string(), token.clone()));
            }
            let page = self.http.get_json(FILES_URL, &query)?;
            out.push(page.clone());
            match page.get("nextPageToken").and_then(Value::as_str) {
                Some(token) if !token.is_empty() => page_token = Some(token.to_string()),
                _ => break,
            }
        }
        Ok(out)
    }

    /// 路徑 → 檔案 id。同名多份時取最後修改的那一個。
    fn find_file_id(&self, path: &str) -> Result<String, SyncError> {
        let lower = path.to_lowercase();
        if self.deleted_paths.lock().unwrap().contains(path)
            || self.deleted_paths.lock().unwrap().contains(&lower)
        {
            return Err(SyncError::NotFound(path.to_string()));
        }
        {
            let cache = self.id_cache.lock().unwrap();
            if let Some(id) = cache.get(path).or_else(|| cache.get(&lower)) {
                return Ok(id.clone());
            }
        }
        let pages = self.list_all(&exact_query(path), "id, modifiedTime")?;
        let mut best: Option<(String, String)> = None;
        for page in pages {
            for f in page
                .get("files")
                .and_then(Value::as_array)
                .cloned()
                .unwrap_or_default()
            {
                let Some(id) = f.get("id").and_then(Value::as_str) else {
                    continue;
                };
                let modified = f
                    .get("modifiedTime")
                    .and_then(Value::as_str)
                    .unwrap_or("")
                    .to_string();
                // RFC 3339 的時間字串字典序即時間序，可以直接比。
                match &best {
                    Some((_, best_time)) if *best_time >= modified => {}
                    _ => best = Some((id.to_string(), modified)),
                }
            }
        }
        if let Some((ref id, _)) = best {
            let mut cache = self.id_cache.lock().unwrap();
            cache.insert(path.to_string(), id.clone());
            cache.insert(lower.clone(), id.clone());
        }
        best.map(|(id, _)| id).ok_or_else(|| {
            let mut del = self.deleted_paths.lock().unwrap();
            del.insert(path.to_string());
            del.insert(lower);
            SyncError::NotFound(path.to_string())
        })
    }

    /// 整個檔案的內容。
    ///
    /// 同步的中繼資料（`settings/global.json`、`notebooks/index.json`）都很小，
    /// 分段拉沒有意義。而且用 `get_range(0..u64::MAX)` 會送出一個
    /// Drive 不接受的 Range 標頭 —— 那種錯誤看起來像「檔案壞了」。
    pub fn get_all(&self, path: &str) -> Result<Vec<u8>, SyncError> {
        let file_id = self.find_file_id(path)?;
        self.http
            .get_bytes(&format!("{FILES_URL}/{file_id}?alt=media"), None)
    }

    /// 刪除雲端檔案。
    pub fn delete(&self, path: &str) -> Result<(), SyncError> {
        let lower = path.to_lowercase();
        if self.deleted_paths.lock().unwrap().contains(path)
            || self.deleted_paths.lock().unwrap().contains(&lower)
        {
            return Ok(());
        }
        let file_id = match self.find_file_id(path) {
            Ok(id) => id,
            Err(SyncError::NotFound(_)) => {
                let mut del = self.deleted_paths.lock().unwrap();
                del.insert(path.to_string());
                del.insert(lower);
                return Ok(());
            }
            Err(e) => return Err(e),
        };
        match self.delete_by_id(&file_id) {
            Ok(()) | Err(SyncError::NotFound(_)) => {}
            Err(e) => return Err(e),
        }
        {
            let mut cache = self.id_cache.lock().unwrap();
            cache.remove(path);
            cache.remove(&lower);
        }
        {
            let mut del = self.deleted_paths.lock().unwrap();
            del.insert(path.to_string());
            del.insert(lower);
        }
        Ok(())
    }

    /// 依 file_id 刪除雲端檔案。
    pub fn delete_by_id(&self, file_id: &str) -> Result<(), SyncError> {
        let url = format!("{FILES_URL}/{file_id}");
        self.http.delete(&url)
    }

    // ── 變更游標（P1：用 changes.list 取代全量列舉）────────────────
    //
    // 舊流程每同步一本筆記本就打一次 `files.list`，**不管有沒有變動**。
    // 「沒變動的就不要動它」在那個結構下做不到：要知道有沒有變動就得先問，
    // 而問本身就是主要成本。Drive 的 changes API 把「問」變成一次請求。

    /// 取得目前的變更游標。之後的 `changes.list` 從這裡開始往後看。
    ///
    /// **要先拿游標再做全量列舉**，順序反過來的話，列舉期間發生的變動
    /// 會落在游標之前，永遠補不回來。
    pub fn start_page_token(&self) -> Result<String, SyncError> {
        let page = self.http.get_json(
            CHANGES_START_TOKEN_URL,
            &[("spaces".to_string(), "appDataFolder".to_string())],
        )?;
        page.get("startPageToken")
            .and_then(Value::as_str)
            .map(str::to_string)
            .ok_or_else(|| SyncError::Backend("Drive 沒有回傳 startPageToken".into()))
    }

    /// 全量列出 `appDataFolder` 底下的所有檔案。**只在重建基準時用。**
    pub fn list_all_remote(&self) -> Result<Vec<crate::remote_index::RemoteFile>, SyncError> {
        let pages = self.list_all(
            "'appDataFolder' in parents and trashed = false",
            "id, name, size",
        )?;
        let mut out = Vec::new();
        let mut cache = self.id_cache.lock().unwrap();
        for page in &pages {
            for f in page
                .get("files")
                .and_then(Value::as_array)
                .cloned()
                .unwrap_or_default()
            {
                let (Some(id), Some(name)) = (
                    f.get("id").and_then(Value::as_str),
                    f.get("name").and_then(Value::as_str),
                ) else {
                    continue;
                };
                let size = f
                    .get("size")
                    .and_then(Value::as_str)
                    .and_then(|v| v.parse::<u64>().ok())
                    .unwrap_or(0);
                cache.insert(name.to_string(), id.to_string());
                cache.insert(name.to_lowercase(), id.to_string());
                out.push(crate::remote_index::RemoteFile {
                    id: id.to_string(),
                    name: name.to_string(),
                    size,
                });
            }
        }
        Ok(out)
    }

    /// 從 `token` 之後的所有變更，並回傳下一次要用的游標。
    ///
    /// 分頁一樣要跟到底；`newStartPageToken` 只會出現在最後一頁。
    pub fn fetch_changes(&self, token: &str) -> Result<DriveChangeBatch, SyncError> {
        let mut out = Vec::new();
        let mut cursor = token.to_string();
        loop {
            let query = vec![
                ("pageToken".to_string(), cursor.clone()),
                ("spaces".to_string(), "appDataFolder".to_string()),
                ("includeRemoved".to_string(), "true".to_string()),
                ("pageSize".to_string(), "1000".to_string()),
                (
                    "fields".to_string(),
                    "nextPageToken, newStartPageToken, changes(fileId, removed, file(id, name, size, trashed))"
                        .to_string(),
                ),
            ];
            let page = self.http.get_json(CHANGES_URL, &query)?;
            for change in page
                .get("changes")
                .and_then(Value::as_array)
                .cloned()
                .unwrap_or_default()
            {
                let file_id = change
                    .get("fileId")
                    .and_then(Value::as_str)
                    .unwrap_or_default()
                    .to_string();
                if file_id.is_empty() {
                    continue;
                }
                let removed = change
                    .get("removed")
                    .and_then(Value::as_bool)
                    .unwrap_or(false);
                let file = change.get("file");
                let name = file
                    .and_then(|f| f.get("name"))
                    .and_then(Value::as_str)
                    .map(str::to_string);
                let size = file
                    .and_then(|f| f.get("size"))
                    .and_then(Value::as_str)
                    .and_then(|v| v.parse::<u64>().ok())
                    .unwrap_or(0);
                // 垃圾桶要當成刪除，理由與 `list_query` 加 `trashed = false` 相同。
                let trashed = file
                    .and_then(|f| f.get("trashed"))
                    .and_then(Value::as_bool)
                    .unwrap_or(false);
                if let (Some(name), false) = (name.as_deref(), removed || trashed) {
                    let mut cache = self.id_cache.lock().unwrap();
                    cache.insert(name.to_string(), file_id.clone());
                    cache.insert(name.to_lowercase(), file_id.clone());
                }
                out.push(DriveChange {
                    file_id,
                    name,
                    size,
                    gone: removed || trashed,
                });
            }
            if let Some(next) = page.get("nextPageToken").and_then(Value::as_str)
                && !next.is_empty()
            {
                cursor = next.to_string();
                continue;
            }
            let new_token = page
                .get("newStartPageToken")
                .and_then(Value::as_str)
                .unwrap_or(&cursor)
                .to_string();
            return Ok(DriveChangeBatch {
                changes: out,
                new_token,
            });
        }
    }

    /// 把已知的 `路徑 → file id` 先塞進快取。
    ///
    /// 有了它，上傳前那一次 `files.list` 就完全不必打 —— 舊流程每上傳一個
    /// 檔案就多一次往返，而那是同步時間裡最不值得的一段。
    pub fn prime_id(&self, path: &str, file_id: &str) {
        let mut cache = self.id_cache.lock().unwrap();
        cache.insert(path.to_string(), file_id.to_string());
        cache.insert(path.to_lowercase(), file_id.to_string());
        let mut del = self.deleted_paths.lock().unwrap();
        del.remove(path);
        del.remove(&path.to_lowercase());
    }

    /// 依 file id 直接讀整個檔案，不先查 id。
    pub fn get_all_by_id(&self, file_id: &str) -> Result<Vec<u8>, SyncError> {
        self.http
            .get_bytes(&format!("{FILES_URL}/{file_id}?alt=media"), None)
    }

    /// 上傳到一個**已知的** file id。
    pub fn put_to_id(&self, file_id: &str, data: &[u8]) -> Result<(), SyncError> {
        if data.len() <= SIMPLE_UPLOAD_LIMIT {
            return self
                .http
                .patch_bytes(&format!("{UPLOAD_URL}/{file_id}?uploadType=media"), data);
        }
        let session = self.http.start_resumable(
            &format!("{UPLOAD_URL}/{file_id}?uploadType=resumable"),
            &json!({}),
        )?;
        self.http.put_bytes(&session, data)
    }

    /// 建立一個新檔案並上傳，回傳它的 file id。
    ///
    /// 與 [`Self::put_new`] 的差別只在**回傳 id** —— 呼叫端要把它記進
    /// `RemoteIndex`，否則下一輪又得去查一次。
    pub fn create_and_upload(&self, path: &str, data: &[u8]) -> Result<String, SyncError> {
        let created = self.http.post_json(
            FILES_URL,
            &json!({ "name": path, "parents": ["appDataFolder"] }),
        )?;
        let file_id = created
            .get("id")
            .and_then(Value::as_str)
            .map(str::to_string)
            .ok_or_else(|| SyncError::Backend(format!("建立 {path} 之後 Drive 沒有回傳 id")))?;
        self.prime_id(path, &file_id);
        self.put_to_id(&file_id, data)?;
        Ok(file_id)
    }

    /// 直接建立並上傳全新檔案（已知遠端不存在），省去每次上傳前 find_file_id 的 HTTP GET 查詢。
    pub fn put_new(&self, path: &str, data: &[u8]) -> Result<(), SyncError> {
        let lower = path.to_lowercase();
        let created = self.http.post_json(
            FILES_URL,
            &json!({ "name": path, "parents": ["appDataFolder"] }),
        )?;
        let file_id = created
            .get("id")
            .and_then(Value::as_str)
            .map(str::to_string)
            .ok_or_else(|| SyncError::Backend(format!("建立 {path} 之後 Drive 沒有回傳 id")))?;
        {
            let mut cache = self.id_cache.lock().unwrap();
            cache.insert(path.to_string(), file_id.clone());
            cache.insert(lower.clone(), file_id.clone());
        }
        {
            let mut del = self.deleted_paths.lock().unwrap();
            del.remove(path);
            del.remove(&lower);
        }
        if data.len() <= SIMPLE_UPLOAD_LIMIT {
            let url = format!("{UPLOAD_URL}/{file_id}?uploadType=media");
            return self.http.patch_bytes(&url, data);
        }
        let session = self.http.start_resumable(
            &format!("{UPLOAD_URL}/{file_id}?uploadType=resumable"),
            &json!({}),
        )?;
        self.http.put_bytes(&session, data)
    }
}

impl<H: DriveHttp> CloudProvider for GDriveProvider<H> {
    fn delete(&self, path: &str) -> Result<(), SyncError> {
        GDriveProvider::delete(self, path)
    }
    fn list(&self, prefix: &str) -> Result<Vec<RemoteEntry>, SyncError> {
        let pages = self.list_all(&list_query(prefix), "id, name, size")?;

        // Populate cache
        let mut cache = self.id_cache.lock().unwrap();
        for page in &pages {
            if let Some(files) = page.get("files").and_then(Value::as_array) {
                for f in files {
                    if let (Some(id), Some(name)) = (
                        f.get("id").and_then(Value::as_str),
                        f.get("name").and_then(Value::as_str),
                    ) {
                        cache.insert(name.to_string(), id.to_string());
                        cache.insert(name.to_lowercase(), id.to_string());
                    }
                }
            }
        }

        Ok(pages
            .iter()
            .flat_map(|page| entries_from(page, prefix))
            .collect())
    }

    fn get_range(&self, path: &str, range: Range<u64>) -> Result<Vec<u8>, SyncError> {
        let file_id = self.find_file_id(path)?;
        let url = format!("{FILES_URL}/{file_id}?alt=media");
        self.http.get_bytes(&url, Some(range))
    }

    fn append(&self, path: &str, _data: &[u8]) -> Result<(), SyncError> {
        // Drive 沒有 append API。回錯誤而不是 `unimplemented!()` ——
        // panic 會穿過 FFI 變成整個 App 閃退，而這只是一個「該走另一條路」
        // 的狀況：`supports_native_append()` 已經回 false，上層應該改用
        // 分塊檔策略（format-spec §7.2）。
        Err(SyncError::Backend(format!(
            "Google Drive 不支援 append（{path}）；請改用分塊檔策略"
        )))
    }

    fn put(&self, path: &str, data: &[u8]) -> Result<(), SyncError> {
        let lower = path.to_lowercase();
        let file_id = match self.find_file_id(path) {
            Ok(id) => id,
            Err(SyncError::NotFound(_)) => {
                let created = self.http.post_json(
                    FILES_URL,
                    &json!({ "name": path, "parents": ["appDataFolder"] }),
                )?;
                let id = created
                    .get("id")
                    .and_then(Value::as_str)
                    .map(str::to_string)
                    .ok_or_else(|| {
                        SyncError::Backend(format!("建立 {path} 之後 Drive 沒有回傳 id"))
                    })?;
                {
                    let mut cache = self.id_cache.lock().unwrap();
                    cache.insert(path.to_string(), id.clone());
                    cache.insert(lower.clone(), id.clone());
                }
                {
                    let mut del = self.deleted_paths.lock().unwrap();
                    del.remove(path);
                    del.remove(&lower);
                }
                id
            }
            // 找不到以外的錯誤（權限、網路）不該被當成「那就新建一個」——
            // 那會在每次暫時失敗時多產生一個重複檔。
            Err(other) => return Err(other),
        };
        if data.len() <= SIMPLE_UPLOAD_LIMIT {
            let url = format!("{UPLOAD_URL}/{file_id}?uploadType=media");
            match self.http.patch_bytes(&url, data) {
                Ok(()) => return Ok(()),
                Err(SyncError::NotFound(_)) => {
                    let mut cache = self.id_cache.lock().unwrap();
                    cache.remove(path);
                    cache.remove(&lower);
                    return self.put_new(path, data);
                }
                Err(other) => return Err(other),
            }
        }
        // 大檔走可續傳。用單次上傳的話 Drive 直接回 413，
        // 而錯誤訊息不會說是「檔案太大」——看起來像權限或網路問題。
        let session = self.http.start_resumable(
            &format!("{UPLOAD_URL}/{file_id}?uploadType=resumable"),
            &json!({}),
        )?;
        self.http.put_bytes(&session, data)
    }

    fn put_new(&self, path: &str, data: &[u8]) -> Result<(), SyncError> {
        GDriveProvider::put_new(self, path, data)
    }

    fn supports_native_append(&self) -> bool {
        false
    }
}

// ── 真正打網路的實作 ────────────────────────────────────────────────

/// 以 `reqwest` 的阻塞式 client 呼叫 Drive。
pub struct ReqwestDriveHttp {
    client: reqwest::blocking::Client,
    access_token: String,
}

impl Debug for ReqwestDriveHttp {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        // **不要印 token。** Debug 會進日誌，而存取權杖等同帳號密碼。
        f.debug_struct("ReqwestDriveHttp").finish_non_exhaustive()
    }
}

impl ReqwestDriveHttp {
    pub fn new(access_token: String) -> Self {
        Self {
            client: reqwest::blocking::Client::new(),
            access_token,
        }
    }

    fn bearer(&self) -> String {
        format!("Bearer {}", self.access_token)
    }

    /// HTTP 狀態 → `SyncError`。
    ///
    /// 401／403 要與「其他錯誤」分開：權杖過期是可以靠重新授權解決的，
    /// 把它混進 `Backend` 之後，UI 只能顯示一句「同步失敗」而不會提示登入。
    fn status_error(status: reqwest::StatusCode, path: &str) -> SyncError {
        match status.as_u16() {
            401 | 403 => SyncError::PermissionDenied(format!("{path}（HTTP {status}）")),
            404 => SyncError::NotFound(path.to_string()),
            _ => SyncError::Backend(format!("Drive API {status}：{path}")),
        }
    }
}

impl DriveHttp for ReqwestDriveHttp {
    fn get_json(&self, url: &str, query: &[(String, String)]) -> Result<Value, SyncError> {
        let resp = self
            .client
            .get(url)
            .header(reqwest::header::AUTHORIZATION, self.bearer())
            .query(query)
            .send()
            .map_err(|e| SyncError::Backend(e.to_string()))?;
        if !resp.status().is_success() {
            return Err(Self::status_error(resp.status(), url));
        }
        resp.json().map_err(|e| SyncError::Backend(e.to_string()))
    }

    fn get_bytes(&self, url: &str, range: Option<Range<u64>>) -> Result<Vec<u8>, SyncError> {
        let mut req = self
            .client
            .get(url)
            .header(reqwest::header::AUTHORIZATION, self.bearer());
        if let Some(r) = range {
            // HTTP 的 Range 是閉區間，Rust 的 Range 是半開 —— 尾端要減一。
            // 少減這個 1，每次都會多拉一個位元組，而框架化的 chunk
            // 會因此對不齊。
            req = req.header(
                reqwest::header::RANGE,
                format!("bytes={}-{}", r.start, r.end.saturating_sub(1)),
            );
        }
        let resp = req.send().map_err(|e| SyncError::Backend(e.to_string()))?;
        if !resp.status().is_success() {
            return Err(Self::status_error(resp.status(), url));
        }
        resp.bytes()
            .map(|b| b.to_vec())
            .map_err(|e| SyncError::Backend(e.to_string()))
    }

    fn post_json(&self, url: &str, body: &Value) -> Result<Value, SyncError> {
        let resp = self
            .client
            .post(url)
            .header(reqwest::header::AUTHORIZATION, self.bearer())
            .json(body)
            .send()
            .map_err(|e| SyncError::Backend(e.to_string()))?;
        if !resp.status().is_success() {
            return Err(Self::status_error(resp.status(), url));
        }
        resp.json().map_err(|e| SyncError::Backend(e.to_string()))
    }

    fn start_resumable(&self, url: &str, body: &Value) -> Result<String, SyncError> {
        let resp = self
            .client
            .post(url)
            .header(reqwest::header::AUTHORIZATION, self.bearer())
            .json(body)
            .send()
            .map_err(|e| SyncError::Backend(e.to_string()))?;
        if !resp.status().is_success() {
            return Err(Self::status_error(resp.status(), url));
        }
        resp.headers()
            .get(reqwest::header::LOCATION)
            .and_then(|v| v.to_str().ok())
            .map(str::to_string)
            .ok_or_else(|| SyncError::Backend("可續傳上傳沒有回傳 Location".into()))
    }

    fn put_bytes(&self, url: &str, data: &[u8]) -> Result<(), SyncError> {
        let resp = self
            .client
            .put(url)
            .header(reqwest::header::AUTHORIZATION, self.bearer())
            .header(reqwest::header::CONTENT_TYPE, "application/octet-stream")
            .body(data.to_vec())
            .send()
            .map_err(|e| SyncError::Backend(e.to_string()))?;
        if !resp.status().is_success() {
            return Err(Self::status_error(resp.status(), url));
        }
        Ok(())
    }

    fn patch_bytes(&self, url: &str, data: &[u8]) -> Result<(), SyncError> {
        let resp = self
            .client
            .patch(url)
            .header(reqwest::header::AUTHORIZATION, self.bearer())
            .header(reqwest::header::CONTENT_TYPE, "application/octet-stream")
            .body(data.to_vec())
            .send()
            .map_err(|e| SyncError::Backend(e.to_string()))?;
        if !resp.status().is_success() {
            return Err(Self::status_error(resp.status(), url));
        }
        Ok(())
    }

    fn delete(&self, url: &str) -> Result<(), SyncError> {
        let resp = self
            .client
            .delete(url)
            .header(reqwest::header::AUTHORIZATION, self.bearer())
            .send()
            .map_err(|e| SyncError::Backend(e.to_string()))?;
        if !resp.status().is_success() && resp.status().as_u16() != 404 {
            return Err(Self::status_error(resp.status(), url));
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    /// 假的 Drive：記得檔案內容，也記得被問過哪些查詢。
    #[derive(Debug, Default)]
    struct FakeDrive {
        /// 路徑 → 內容。
        files: Mutex<Vec<(String, Vec<u8>)>>,
        /// 每一次 `files.list` 的查詢參數，供測試檢查分頁與 q。
        queries: Mutex<Vec<Vec<(String, String)>>>,
        /// 一頁幾筆，用來逼出分頁。
        page_size: usize,
        patched: Mutex<Vec<(String, Vec<u8>)>>,
        /// 走可續傳上傳的那些：(工作階段 URI, 位元組數)。
        put_large: Mutex<Vec<(String, usize)>>,
        created: Mutex<Vec<String>>,
    }

    impl FakeDrive {
        fn with(files: &[(&str, &[u8])], page_size: usize) -> Self {
            Self {
                files: Mutex::new(
                    files
                        .iter()
                        .map(|(p, d)| (p.to_string(), d.to_vec()))
                        .collect(),
                ),
                page_size,
                ..Default::default()
            }
        }

        /// 極簡的 `q` 解析：只認得這個模組自己會產生的兩種形式。
        fn matches(&self, q: &str, name: &str) -> bool {
            if let Some(rest) = q.split("name = '").nth(1) {
                let wanted = rest.trim_end_matches('\'');
                return name == wanted.replace("\\'", "'").replace("\\\\", "\\");
            }
            if let Some(rest) = q.split("name contains '").nth(1) {
                let needle = rest.trim_end_matches('\'');
                return name.to_lowercase().contains(
                    &needle
                        .replace("\\'", "'")
                        .replace("\\\\", "\\")
                        .to_lowercase(),
                );
            }
            true
        }
    }

    impl DriveHttp for FakeDrive {
        fn get_json(&self, _url: &str, query: &[(String, String)]) -> Result<Value, SyncError> {
            self.queries.lock().unwrap().push(query.to_vec());
            let get = |k: &str| {
                query
                    .iter()
                    .find(|(a, _)| a == k)
                    .map(|(_, v)| v.clone())
                    .unwrap_or_default()
            };
            let q = get("q");
            let files = self.files.lock().unwrap();
            let hits: Vec<_> = files.iter().filter(|(n, _)| self.matches(&q, n)).collect();

            let offset: usize = get("pageToken").parse().unwrap_or(0);
            let end = (offset + self.page_size).min(hits.len());
            let page: Vec<Value> = hits[offset..end]
                .iter()
                .enumerate()
                .map(|(i, (n, d))| {
                    json!({
                        "id": format!("id-{}", offset + i),
                        "name": n,
                        "size": d.len().to_string(),
                        "modifiedTime": format!("2026-01-{:02}T00:00:00Z", offset + i + 1),
                    })
                })
                .collect();
            let mut out = json!({ "files": page });
            if end < hits.len() {
                out["nextPageToken"] = json!(end.to_string());
            }
            Ok(out)
        }

        fn get_bytes(&self, url: &str, range: Option<Range<u64>>) -> Result<Vec<u8>, SyncError> {
            let id: usize = url
                .split("files/id-")
                .nth(1)
                .and_then(|s| s.split('?').next())
                .and_then(|s| s.parse().ok())
                .ok_or_else(|| SyncError::NotFound(url.to_string()))?;
            let files = self.files.lock().unwrap();
            let (_, data) = files.get(id).ok_or(SyncError::NotFound(url.into()))?;
            Ok(match range {
                Some(r) => {
                    let start = (r.start as usize).min(data.len());
                    let end = (r.end as usize).min(data.len());
                    data[start..end].to_vec()
                }
                None => data.clone(),
            })
        }

        fn post_json(&self, _url: &str, body: &Value) -> Result<Value, SyncError> {
            let name = body["name"].as_str().unwrap().to_string();
            let mut files = self.files.lock().unwrap();
            files.push((name.clone(), Vec::new()));
            self.created.lock().unwrap().push(name);
            Ok(json!({ "id": format!("id-{}", files.len() - 1) }))
        }

        fn patch_bytes(&self, url: &str, data: &[u8]) -> Result<(), SyncError> {
            self.patched
                .lock()
                .unwrap()
                .push((url.to_string(), data.to_vec()));
            if let Some(id_str) = url.split("files/id-").nth(1)
                && let Ok(idx) = id_str.split('?').next().unwrap_or("").parse::<usize>()
            {
                let mut files = self.files.lock().unwrap();
                if idx < files.len() {
                    files[idx].1 = data.to_vec();
                }
            }
            Ok(())
        }

        fn delete(&self, url: &str) -> Result<(), SyncError> {
            if let Some(id_str) = url.split("files/id-").nth(1)
                && let Ok(idx) = id_str.split('?').next().unwrap_or("").parse::<usize>()
            {
                let mut files = self.files.lock().unwrap();
                if idx < files.len() {
                    files[idx].1.clear();
                }
            }
            Ok(())
        }

        fn start_resumable(&self, url: &str, _body: &Value) -> Result<String, SyncError> {
            Ok(format!("{url}&session=1"))
        }

        fn put_bytes(&self, url: &str, data: &[u8]) -> Result<(), SyncError> {
            self.put_large
                .lock()
                .unwrap()
                .push((url.to_string(), data.len()));
            Ok(())
        }
    }

    #[test]
    fn listing_follows_every_page() {
        // 不跟 nextPageToken 的話，超過一頁之後會安靜地少拉東西 ——
        // 沒有錯誤、沒有警告，只是同步永遠缺一塊。
        let files: Vec<(String, Vec<u8>)> = (0..250)
            .map(|i| (format!("sync/dev-a/log-{i:04}.bin"), vec![0u8; i]))
            .collect();
        let refs: Vec<(&str, &[u8])> = files
            .iter()
            .map(|(a, b)| (a.as_str(), b.as_slice()))
            .collect();
        let drive = GDriveProvider::new(FakeDrive::with(&refs, 100));
        let listed = drive.list("sync/").unwrap();
        assert_eq!(listed.len(), 250);
    }

    #[test]
    fn listing_is_a_prefix_match_not_a_substring_match() {
        // Drive 的 `name contains` 是子字串比對。只靠它的話，
        // 查 `sync/` 會撈到 `notebooks/n1/resync/`，那不是同一回事。
        let drive = GDriveProvider::new(FakeDrive::with(
            &[
                ("sync/dev-a/log-0.bin", b"a"),
                ("notebooks/n1/resync/log-0.bin", b"b"),
            ],
            100,
        ));
        let listed = drive.list("sync/").unwrap();
        assert_eq!(listed.len(), 1);
        assert_eq!(listed[0].path, "sync/dev-a/log-0.bin");
    }

    #[test]
    fn every_query_excludes_the_trash() {
        // 別台裝置刪掉的檔案會留在垃圾桶，Drive 預設還查得到。
        // 不濾掉的話，已經刪除的內容會被同步引擎拉回來。
        assert!(list_query("sync/").contains("trashed = false"));
        assert!(list_query("").contains("trashed = false"));
        assert!(exact_query("settings/global.json").contains("trashed = false"));
    }

    #[test]
    fn names_with_quotes_do_not_break_the_query() {
        // 含單引號的路徑不跳脫的話，整個查詢語法錯誤，Drive 回 400，
        // 而錯誤訊息完全不會提到是哪一個檔名害的。
        let q = exact_query("notebooks/it's mine/manifest.json");
        assert!(q.contains("it\\'s mine"), "{q}");
        assert_eq!(escape_drive_literal(r"a\b'c"), r"a\\b\'c");
    }

    #[test]
    fn size_comes_back_as_a_number_even_though_drive_sends_a_string() {
        let drive =
            GDriveProvider::new(FakeDrive::with(&[("settings/global.json", b"12345")], 100));
        let listed = drive.list("settings/").unwrap();
        assert_eq!(listed[0].size, 5);
    }

    #[test]
    fn get_range_asks_for_a_half_open_range() {
        let drive = GDriveProvider::new(FakeDrive::with(
            &[("sync/dev-a/log-0.bin", b"0123456789")],
            100,
        ));
        assert_eq!(
            drive.get_range("sync/dev-a/log-0.bin", 2..5).unwrap(),
            b"234"
        );
    }

    #[test]
    fn put_creates_once_then_updates_in_place() {
        let drive = GDriveProvider::new(FakeDrive::with(&[], 100));
        drive.put("settings/global.json", b"first").unwrap();
        drive.put("settings/global.json", b"second").unwrap();
        // 第二次不可以再建一個同名檔 —— Drive 允許重名，重複建立之後
        // 兩台裝置會各自讀到不同的那一份。
        assert_eq!(drive.http.created.lock().unwrap().len(), 1);
        let patched = drive.http.patched.lock().unwrap();
        assert_eq!(patched.len(), 2);
        assert_eq!(patched[1].1, b"second");
    }

    #[test]
    fn get_all_reads_the_whole_file() {
        let drive = GDriveProvider::new(FakeDrive::with(
            &[("notebooks/index.json", b"{\"items\":{}}")],
            100,
        ));
        assert_eq!(
            drive.get_all("notebooks/index.json").unwrap(),
            b"{\"items\":{}}"
        );
    }

    #[test]
    fn a_large_file_goes_through_the_resumable_path() {
        // Drive 的單次上傳上限是 5 MB。手機照片很容易超過，而 blob 存的是
        // **原始位元組** —— 用單次上傳的話 Drive 回 413，錯誤訊息還不會說
        // 是「檔案太大」，看起來像權限或網路問題。
        let drive = GDriveProvider::new(FakeDrive::with(&[], 100));
        let big = vec![7u8; SIMPLE_UPLOAD_LIMIT + 1];
        drive.put("notebooks/n1/media/blobs/abc", &big).unwrap();

        assert!(
            drive.http.patched.lock().unwrap().is_empty(),
            "大檔不該走單次上傳"
        );
        let large = drive.http.put_large.lock().unwrap();
        assert_eq!(large.len(), 1);
        assert_eq!(large[0].1, big.len());
        assert!(
            large[0].0.contains("uploadType=resumable"),
            "{}",
            large[0].0
        );
    }

    #[test]
    fn a_small_file_still_uses_the_simple_upload() {
        // 小檔走可續傳只是多一趟往返。
        let drive = GDriveProvider::new(FakeDrive::with(&[], 100));
        drive.put("settings/global.json", b"{}").unwrap();
        assert_eq!(drive.http.patched.lock().unwrap().len(), 1);
        assert!(drive.http.put_large.lock().unwrap().is_empty());
    }

    #[test]
    fn append_returns_an_error_instead_of_panicking() {
        // 原本是 `unimplemented!()`：panic 會穿過 FFI 變成整個 App 閃退，
        // 而這只是一個「該走另一條路」的狀況。
        let drive = GDriveProvider::new(FakeDrive::with(&[], 100));
        assert!(!drive.supports_native_append());
        let err = drive.append("sync/dev-a/log-0.bin", b"x").unwrap_err();
        assert!(matches!(err, SyncError::Backend(_)));
    }

    #[test]
    fn a_missing_file_is_not_found_rather_than_a_backend_error() {
        // 上層要靠這個分辨「還沒有這個檔」與「同步壞了」。
        let drive = GDriveProvider::new(FakeDrive::with(&[], 100));
        assert!(matches!(
            drive.get_range("sync/dev-a/log-0.bin", 0..1),
            Err(SyncError::NotFound(_))
        ));
    }

    #[test]
    fn duplicate_names_resolve_to_the_newest() {
        // Drive 允許同名檔。取錯一份的症狀是「同步回來的是舊內容」，
        // 而且每次還可能不一樣。
        let drive = GDriveProvider::new(FakeDrive::with(
            &[
                ("settings/global.json", b"old"),
                ("settings/global.json", b"new"),
            ],
            100,
        ));
        assert_eq!(
            drive.get_range("settings/global.json", 0..3).unwrap(),
            b"new"
        );
    }

    #[test]
    fn delete_removes_file_from_drive() {
        let drive = GDriveProvider::new(FakeDrive::with(
            &[("notebooks/nb1/doc/ops/0001-dev.oplog", b"test-op")],
            100,
        ));
        assert!(drive.delete("notebooks/nb1/doc/ops/0001-dev.oplog").is_ok());
        // 刪除後快取被清除，且記錄在 deleted_paths
        assert!(drive.id_cache.lock().unwrap().is_empty());
        assert!(
            drive
                .deleted_paths
                .lock()
                .unwrap()
                .contains("notebooks/nb1/doc/ops/0001-dev.oplog")
        );
        // 再次刪除或查詢該路徑直接命中快取 NotFound，不再次發起任何網路請求
        assert!(drive.delete("notebooks/nb1/doc/ops/0001-dev.oplog").is_ok());
        assert!(matches!(
            drive.get_all("notebooks/nb1/doc/ops/0001-dev.oplog"),
            Err(SyncError::NotFound(_))
        ));
    }

    #[test]
    fn put_new_directly_creates_without_searching() {
        let fake = FakeDrive::with(&[], 100);
        let drive = GDriveProvider::new(fake);
        let path = "notebooks/nb1/media/blobs/abcdef.png";
        assert!(drive.put_new(path, b"image-data").is_ok());
        // 建立了新檔案並加入快取，且 deleted_paths 中被移除
        assert!(drive.id_cache.lock().unwrap().contains_key(path));
        assert_eq!(drive.get_all(path).unwrap(), b"image-data");
    }

    #[test]
    fn listing_is_case_insensitive_for_notebook_uuids() {
        let fake = FakeDrive::with(
            &[("notebooks/B62B0B1F-ADF4-4FF7/doc/ops/0001-dev.oplog", b"op")],
            100,
        );
        let drive = GDriveProvider::new(fake);
        // 以小寫 prefix 查詢，應能成功列出大寫 UUID 的遠端檔案
        let entries = drive.list("notebooks/b62b0b1f-adf4-4ff7/doc/ops").unwrap();
        assert_eq!(entries.len(), 1);
        assert_eq!(
            entries[0].path,
            "notebooks/B62B0B1F-ADF4-4FF7/doc/ops/0001-dev.oplog"
        );
    }
}
