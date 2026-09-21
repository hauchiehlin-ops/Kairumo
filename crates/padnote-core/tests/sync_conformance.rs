//! 跨裝置同步的一致性測試（P4 回歸護欄）。
//!
//! # 為什麼需要一個「脾氣壞」的假 Drive
//!
//! 同步的錯誤幾乎都不是邏輯錯，是**對雲端行為的假設錯**。而真的 Drive 的
//! 脾氣沒有一條寫在我們的程式裡：
//!
//! - **檔名可以重複。** 同一個路徑可能對應好幾個 file id（兩台裝置同時建立
//!   同一個名字時就會發生）。取錯一個的症狀是「下載回來的內容對不上」。
//! - **刪除會進垃圾桶**，而且預設查得到。不濾掉的話，已經刪掉的內容會被
//!   當成還在，然後重新拉回來。
//! - **單次上傳上限 5 MB**，超過要走可續傳。不處理的話，使用者一放照片
//!   同步就壞。
//! - **`changes.list` 的游標會過期**（HTTP 410）。當成錯誤的話，久沒開的
//!   裝置會永遠同步不了。
//!
//! 這個檔案把這些脾氣做進假的 Drive 裡，再用**隨機操作序列**跑兩台裝置，
//! 斷言最後收斂。單元測試釘的是單一行為；這裡釘的是「湊在一起還對不對」。

use std::sync::{Arc, Mutex};
use std::sync::atomic::{AtomicUsize, Ordering};

use padnote_core::ffi_gdrive::{
    FfiByteRange, FfiDriveError, FfiDriveHttp, FfiQueryParam, FfiSyncSession,
};
use padnote_doc::ops::DocOp;
use padnote_storage::NotebookPackage;

/// 一個會重現 Drive 真實脾氣的假後端。
#[derive(Debug, Default)]
struct QuirkyDrive {
    /// `(名稱, 內容, 在垃圾桶裡)`。索引即 file id。
    files: Mutex<Vec<(String, Vec<u8>, bool)>>,
    /// 每次寫入／刪除碰到的索引，`changes.list` 的游標就是它的長度。
    log: Mutex<Vec<usize>>,
    calls: AtomicUsize,
    /// 還要讓 `changes.list` 失敗幾次（模擬游標過期）。
    expire_cursor: AtomicUsize,
    /// 單次上傳上限。超過就必須走可續傳，否則回 413。
    simple_upload_limit: usize,
}

impl QuirkyDrive {
    fn new() -> Self {
        Self {
            simple_upload_limit: 4 * 1024 * 1024,
            ..Default::default()
        }
    }

    fn hit(&self) {
        self.calls.fetch_add(1, Ordering::Relaxed);
    }

    fn call_count(&self) -> usize {
        self.calls.load(Ordering::Relaxed)
    }

    fn note(&self, index: usize) {
        self.log.lock().unwrap().push(index);
    }

    fn index_of(url: &str) -> Option<usize> {
        url.split("files/id-")
            .nth(1)?
            .split(['?', '&'])
            .next()?
            .parse()
            .ok()
    }

    fn param<'a>(params: &'a [FfiQueryParam], key: &str) -> &'a str {
        params
            .iter()
            .find(|p| p.name == key)
            .map(|p| p.value.as_str())
            .unwrap_or("")
    }

    /// **同一個名字複製一份**，模擬兩台裝置同時建立同名檔案。
    /// 舊的那一份留著，較新的才是對的 —— 取錯就會讀到空內容。
    fn duplicate(&self, name: &str) {
        let mut files = self.files.lock().unwrap();
        files.push((name.to_string(), Vec::new(), false));
        let index = files.len() - 1;
        drop(files);
        self.note(index);
    }

    /// 把某個名字丟進垃圾桶（不是真的刪掉）。
    fn trash(&self, name: &str) {
        let mut files = self.files.lock().unwrap();
        let mut touched = Vec::new();
        for (i, slot) in files.iter_mut().enumerate() {
            if slot.0 == name {
                slot.2 = true;
                touched.push(i);
            }
        }
        drop(files);
        for i in touched {
            self.note(i);
        }
    }

    fn live_names(&self) -> Vec<String> {
        self.files
            .lock()
            .unwrap()
            .iter()
            .filter(|(name, _, trashed)| !name.is_empty() && !trashed)
            .map(|(name, _, _)| name.clone())
            .collect()
    }

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
            let Some((name, data, trashed)) = files.get(*index) else {
                continue;
            };
            if name.is_empty() {
                out.push(format!(r#"{{"fileId":"id-{index}","removed":true}}"#));
            } else {
                out.push(format!(
                    r#"{{"fileId":"id-{index}","removed":false,"file":{{"id":"id-{index}","name":"{name}","size":"{}","trashed":{trashed}}}}}"#,
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

    fn write_at(&self, url: &str, data: Vec<u8>, resumable: bool) -> Result<(), FfiDriveError> {
        self.hit();
        // 單次上傳超過上限，Drive 回 413 —— 而錯誤訊息完全不會提到
        // 「檔案太大」，看起來像權限或網路問題。
        if !resumable && data.len() > self.simple_upload_limit {
            return Err(FfiDriveError::Backend {
                detail: "HTTP 413 payload too large".into(),
            });
        }
        let index = Self::index_of(url).ok_or(FfiDriveError::NotFound {
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
            self.note(index);
            Ok(())
        } else {
            Err(FfiDriveError::NotFound {
                path: url.to_string(),
            })
        }
    }
}

impl FfiDriveHttp for QuirkyDrive {
    fn get_json(&self, url: String, query: Vec<FfiQueryParam>) -> Result<String, FfiDriveError> {
        self.hit();
        if url.ends_with("changes/startPageToken") {
            return Ok(format!(
                r#"{{"startPageToken":"{}"}}"#,
                self.log.lock().unwrap().len()
            ));
        }
        if url.ends_with("/changes") {
            if self.expire_cursor.load(Ordering::Relaxed) > 0 {
                self.expire_cursor.fetch_sub(1, Ordering::Relaxed);
                return Err(FfiDriveError::Backend {
                    detail: "HTTP 410 pageToken expired".into(),
                });
            }
            return Ok(self.changes_since(Self::param(&query, "pageToken")));
        }
        let q = Self::param(&query, "q").to_string();
        let files = self.files.lock().unwrap();
        let entries: Vec<String> = files
            .iter()
            .enumerate()
            // 垃圾桶裡的不回傳（查詢字串一律帶 `trashed = false`）。
            .filter(|(_, (name, _, trashed))| !name.is_empty() && !trashed)
            .filter(|(_, (name, _, _))| {
                if let Some(rest) = q.split("name = '").nth(1) {
                    name == rest.trim_end_matches('\'')
                } else if let Some(rest) = q.split("name contains '").nth(1) {
                    name.contains(rest.trim_end_matches('\''))
                } else {
                    true
                }
            })
            .map(|(i, (name, data, _))| {
                format!(
                    r#"{{"id":"id-{i}","name":"{name}","size":"{}","modifiedTime":"2026-01-01T00:00:{:02}Z"}}"#,
                    data.len(),
                    i % 60
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
        let index = Self::index_of(&url).ok_or(FfiDriveError::NotFound { path: url.clone() })?;
        let files = self.files.lock().unwrap();
        match files.get(index) {
            Some((name, data, trashed)) if !name.is_empty() && !trashed => Ok(data.clone()),
            _ => Err(FfiDriveError::NotFound { path: url }),
        }
    }

    fn post_json(&self, _url: String, body_json: String) -> Result<String, FfiDriveError> {
        self.hit();
        let value: serde_json::Value = serde_json::from_str(&body_json).unwrap();
        let name = value["name"].as_str().unwrap_or_default().to_string();
        let index = {
            let mut files = self.files.lock().unwrap();
            files.push((name, Vec::new(), false));
            files.len() - 1
        };
        self.note(index);
        Ok(format!(r#"{{"id":"id-{index}"}}"#))
    }

    fn patch_bytes(&self, url: String, data: Vec<u8>) -> Result<(), FfiDriveError> {
        self.write_at(&url, data, false)
    }

    fn delete(&self, url: String) -> Result<(), FfiDriveError> {
        self.hit();
        let index = Self::index_of(&url).ok_or(FfiDriveError::NotFound { path: url.clone() })?;
        {
            let mut files = self.files.lock().unwrap();
            if let Some(slot) = files.get_mut(index) {
                slot.0.clear();
                slot.1.clear();
            }
        }
        self.note(index);
        Ok(())
    }

    fn start_resumable(&self, url: String, _body: String) -> Result<String, FfiDriveError> {
        self.hit();
        Ok(format!("{url}&resumable=1"))
    }

    fn put_bytes(&self, url: String, data: Vec<u8>) -> Result<(), FfiDriveError> {
        self.write_at(&url, data, true)
    }
}

fn package(tag: &str, device: u32) -> std::path::PathBuf {
    let root = std::env::temp_dir().join(format!(
        "padnote-conform-{tag}-{device:08x}-{}",
        std::process::id()
    ));
    let _ = std::fs::remove_dir_all(&root);
    NotebookPackage::create(&root, "t", u64::from(device)).unwrap();
    root
}

fn write_op(root: &std::path::Path, lamport: u64, device: u32, text: &str) {
    NotebookPackage::open(root)
        .unwrap()
        .append_doc_ops(
            lamport,
            device,
            &[DocOp::SetTitle {
                title: text.to_string(),
            }],
        )
        .unwrap();
}

fn titles(root: &std::path::Path) -> std::collections::BTreeSet<String> {
    NotebookPackage::open(root)
        .unwrap()
        .read_doc_ops()
        .unwrap()
        .into_iter()
        .filter_map(|op| match op {
            DocOp::SetTitle { title } => Some(title),
            _ => None,
        })
        .collect()
}

/// 跑到收斂：兩台裝置交替同步，直到誰都沒有事情做。
///
/// 固定跑 N 輪而不是「跑一次就斷言」—— 收斂是**最終**一致，一輪不夠是
/// 正常的（一台推上去、另一台下一輪才拿得到）。
fn settle(
    a: &FfiSyncSession,
    a_root: &std::path::Path,
    b: &FfiSyncSession,
    b_root: &std::path::Path,
    rounds: usize,
) {
    for _ in 0..rounds {
        for (session, root, device) in [
            (a, a_root, 0x0000_00aau32),
            (b, b_root, 0x0000_00bbu32),
        ] {
            let refreshed = session.refresh();
            assert!(refreshed.ok, "refresh 失敗：{}", refreshed.error);
            let path: String = root.to_string_lossy().into();
            let result = session.sync_notebook(path, "nb1".into(), device);
            assert!(result.ok, "同步失敗：{}", result.error);
        }
    }
}

#[test]
fn two_devices_converge_through_a_drive_that_misbehaves() {
    // 隨機操作序列 + 壞脾氣的雲端。單元測試釘的是單一行為，
    // 這裡釘的是「湊在一起還對不對」。
    let drive = Arc::new(QuirkyDrive::new());
    let http: Arc<dyn FfiDriveHttp> = drive.clone();

    let a_root = package("converge", 0xAA);
    let b_root = package("converge", 0xBB);
    let a = FfiSyncSession::create(http.clone(), String::new());
    let b = FfiSyncSession::create(http.clone(), String::new());

    let mut expected = std::collections::BTreeSet::new();
    // 固定種子的偽隨機：失敗時重現得了。用真亂數的話，
    // CI 上偶爾紅一次而本機永遠復現不了。
    let mut seed = 0x2026_0921_u64;
    let mut next = || {
        seed = seed.wrapping_mul(6_364_136_223_846_793_005).wrapping_add(1);
        (seed >> 33) as u32
    };

    for round in 1..=12u64 {
        let roll = next() % 5;
        match roll {
            // A 寫
            0 | 1 => {
                let text = format!("a{round}");
                write_op(&a_root, round, 0xAA, &text);
                expected.insert(text);
            }
            // B 寫
            2 | 3 => {
                let text = format!("b{round}");
                write_op(&b_root, round, 0xBB, &text);
                expected.insert(text);
            }
            // 雲端鬧脾氣
            _ => {
                if let Some(name) = drive.live_names().into_iter().find(|n| n.ends_with(".oplog")) {
                    // 同名重複檔：兩台裝置同時建立同一個名字時真的會發生。
                    drive.duplicate(&name);
                }
                // 游標過期一次：久沒開的裝置會遇到。
                drive.expire_cursor.store(1, Ordering::Relaxed);
            }
        }
        settle(&a, &a_root, &b, &b_root, 2);
    }

    settle(&a, &a_root, &b, &b_root, 3);

    let a_titles = titles(&a_root);
    let b_titles = titles(&b_root);
    assert_eq!(a_titles, b_titles, "兩台裝置沒有收斂");
    for text in &expected {
        assert!(a_titles.contains(text), "少了 {text}：{a_titles:?}");
    }
}

#[test]
fn a_trashed_file_is_not_pulled_back() {
    // Drive 的刪除是丟垃圾桶，而垃圾桶裡的東西預設查得到。
    // 不濾掉的話，已經刪掉的內容會被當成還在，然後重新拉回來。
    let drive = Arc::new(QuirkyDrive::new());
    let http: Arc<dyn FfiDriveHttp> = drive.clone();

    let a_root = package("trash", 0xAA);
    write_op(&a_root, 1, 0xAA, "只有這一筆");
    let a = FfiSyncSession::create(http.clone(), String::new());
    assert!(a.refresh().ok);
    assert!(
        a.sync_notebook(a_root.to_string_lossy().into(), "nb1".into(), 0xAA)
            .ok
    );

    let name = drive
        .live_names()
        .into_iter()
        .find(|n| n.ends_with(".oplog"))
        .expect("雲端應該有一個 oplog");
    drive.trash(&name);

    // 全新的裝置：垃圾桶裡那一份不該被當成還在。
    let b_root = package("trash", 0xBB);
    let b = FfiSyncSession::create(http, String::new());
    assert!(b.refresh().ok);
    assert!(
        b.sync_notebook(b_root.to_string_lossy().into(), "nb1".into(), 0xBB)
            .ok
    );
    assert!(
        titles(&b_root).is_empty(),
        "垃圾桶裡的檔案被當成還在，拉回來了"
    );
}

#[test]
fn a_large_blob_goes_through_the_resumable_path() {
    // Drive 單次上傳上限 5 MB。手機照片 3–8 MB 是常態，所以這不是邊角情況：
    // 不處理的話，使用者一放照片同步就壞，而錯誤訊息看起來像網路問題。
    let drive = Arc::new(QuirkyDrive::new());
    let http: Arc<dyn FfiDriveHttp> = drive.clone();

    let root = package("bigblob", 0xAA);
    let pkg = NotebookPackage::open(&root).unwrap();
    write_op(&root, 1, 0xAA, "有一張大圖");
    let big = vec![7u8; 5 * 1024 * 1024];
    pkg.blobs().put(&big).unwrap();

    let session = FfiSyncSession::create(http.clone(), String::new());
    assert!(session.refresh().ok);
    let result = session.sync_notebook(root.to_string_lossy().into(), "nb1".into(), 0xAA);
    assert!(result.ok, "大檔上傳失敗：{}", result.error);

    // 另一台要拿得回同一份位元組（blob 下載會驗雜湊，錯了會被丟掉）。
    let other = package("bigblob", 0xBB);
    let b = FfiSyncSession::create(http, String::new());
    assert!(b.refresh().ok);
    let pulled = b.sync_notebook(other.to_string_lossy().into(), "nb1".into(), 0xBB);
    assert!(pulled.ok, "{}", pulled.error);
    let blobs = NotebookPackage::open(&other).unwrap();
    assert_eq!(blobs.blobs().list().unwrap().len(), 1, "大 blob 沒有過去");
}

#[test]
fn a_settled_pair_stops_making_requests() {
    // 收斂之後還在打網路 = 每 12 秒白白消耗一次配額與電力。
    let drive = Arc::new(QuirkyDrive::new());
    let http: Arc<dyn FfiDriveHttp> = drive.clone();

    let a_root = package("quiet", 0xAA);
    let b_root = package("quiet", 0xBB);
    write_op(&a_root, 1, 0xAA, "一筆");
    let a = FfiSyncSession::create(http.clone(), String::new());
    let b = FfiSyncSession::create(http, String::new());
    settle(&a, &a_root, &b, &b_root, 3);

    let before = drive.call_count();
    // 什麼都沒變的一輪：只有兩次 changes.list（兩台各一次）。
    a.refresh();
    b.refresh();
    assert!(
        !a.notebook_needs_sync(a_root.to_string_lossy().into(), "nb1".into())
            || !b.notebook_needs_sync(b_root.to_string_lossy().into(), "nb1".into()),
        "收斂之後不該兩邊都還說有事要做"
    );
    assert_eq!(
        drive.call_count() - before,
        2,
        "無變動的一輪，每台裝置只該打一次 HTTP"
    );
}
