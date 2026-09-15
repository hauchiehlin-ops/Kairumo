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
use std::fmt::Debug;
use std::ops::Range;

const FILES_URL: &str = "https://www.googleapis.com/drive/v3/files";
const UPLOAD_URL: &str = "https://www.googleapis.com/upload/drive/v3/files";

/// Drive REST 呼叫。抽出來是為了讓查詢與分頁邏輯測得到，見模組說明。
pub trait DriveHttp: Send + Sync + Debug {
    fn get_json(&self, url: &str, query: &[(String, String)]) -> Result<Value, SyncError>;
    fn get_bytes(&self, url: &str, range: Option<Range<u64>>) -> Result<Vec<u8>, SyncError>;
    fn post_json(&self, url: &str, body: &Value) -> Result<Value, SyncError>;
    fn patch_bytes(&self, url: &str, data: &[u8]) -> Result<(), SyncError>;
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
    page.get("files")
        .and_then(Value::as_array)
        .map(|files| {
            files
                .iter()
                .filter_map(|f| {
                    let name = f.get("name")?.as_str()?.to_string();
                    if !name.starts_with(prefix) {
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

/// Google Drive Provider。
#[derive(Debug)]
pub struct GDriveProvider<H: DriveHttp> {
    http: H,
}

impl<H: DriveHttp> GDriveProvider<H> {
    pub fn new(http: H) -> Self {
        Self { http }
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
        best.map(|(id, _)| id)
            .ok_or_else(|| SyncError::NotFound(path.to_string()))
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
}


impl<H: DriveHttp> CloudProvider for GDriveProvider<H> {
    fn list(&self, prefix: &str) -> Result<Vec<RemoteEntry>, SyncError> {
        let pages = self.list_all(&list_query(prefix), "id, name, size")?;
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
        let file_id = match self.find_file_id(path) {
            Ok(id) => id,
            Err(SyncError::NotFound(_)) => {
                let created = self.http.post_json(
                    FILES_URL,
                    &json!({ "name": path, "parents": ["appDataFolder"] }),
                )?;
                created
                    .get("id")
                    .and_then(Value::as_str)
                    .map(str::to_string)
                    .ok_or_else(|| {
                        SyncError::Backend(format!("建立 {path} 之後 Drive 沒有回傳 id"))
                    })?
            }
            // 找不到以外的錯誤（權限、網路）不該被當成「那就新建一個」——
            // 那會在每次暫時失敗時多產生一個重複檔。
            Err(other) => return Err(other),
        };
        let url = format!("{UPLOAD_URL}/{file_id}?uploadType=media");
        self.http.patch_bytes(&url, data)
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
        let resp = req
            .send()
            .map_err(|e| SyncError::Backend(e.to_string()))?;
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
                return name.contains(&needle.replace("\\'", "'").replace("\\\\", "\\"));
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
        let drive = GDriveProvider::new(FakeDrive::with(&[("settings/global.json", b"12345")], 100));
        let listed = drive.list("settings/").unwrap();
        assert_eq!(listed[0].size, 5);
    }

    #[test]
    fn get_range_asks_for_a_half_open_range() {
        let drive =
            GDriveProvider::new(FakeDrive::with(&[("sync/dev-a/log-0.bin", b"0123456789")], 100));
        assert_eq!(drive.get_range("sync/dev-a/log-0.bin", 2..5).unwrap(), b"234");
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
        assert_eq!(drive.get_all("notebooks/index.json").unwrap(), b"{\"items\":{}}");
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
            &[("settings/global.json", b"old"), ("settings/global.json", b"new")],
            100,
        ));
        assert_eq!(drive.get_range("settings/global.json", 0..3).unwrap(), b"new");
    }
}
