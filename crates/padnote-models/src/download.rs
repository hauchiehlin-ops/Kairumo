//! 可續傳、可驗證的下載器。
//!
//! 網路 IO 抽象成 `Fetcher` trait，讓整個續傳與驗證邏輯可以離線完整測試 ——
//! 這些正是最容易寫錯、又最難在真機上重現的地方。

use crate::catalog::ModelEntry;
use sha2::{Digest, Sha256};
use std::fmt;
use std::fs;
use std::io::{Read, Seek, SeekFrom, Write};
use std::path::{Path, PathBuf};

/// 一次範圍請求。
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RangeRequest {
    pub url: String,
    /// 從這個位元組開始（HTTP `Range: bytes=<from>-`）。
    pub from: u64,
}

/// 網路存取抽象。正式實作走 HTTPS；測試用假的。
pub trait Fetcher: Send + Sync {
    /// 取回從 `from` 起的資料。可以只回傳一部分（模擬中斷）。
    fn fetch(&self, req: &RangeRequest) -> Result<Vec<u8>, String>;

    /// 伺服器是否支援 Range 請求。不支援時只能從頭下載。
    fn supports_range(&self) -> bool {
        true
    }
}

#[derive(Debug)]
pub enum DownloadError {
    /// 下載完成但雜湊不符 —— 可能是傳輸損毀或被替換。
    ChecksumMismatch {
        expected: String,
        actual: String,
    },
    /// 下載到的位元組數與清單宣告的不符。
    SizeMismatch {
        expected: u64,
        actual: u64,
    },
    Malformed(String),
    Network(String),
    Io(std::io::Error),
}

impl fmt::Display for DownloadError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::ChecksumMismatch { expected, actual } => write!(
                f,
                "模型校驗失敗：期望 {}…，實得 {}…（檔案已刪除）",
                &expected[..8.min(expected.len())],
                &actual[..8.min(actual.len())]
            ),
            Self::SizeMismatch { expected, actual } => {
                write!(f, "大小不符：期望 {expected} bytes，實得 {actual}")
            }
            Self::Malformed(m) => write!(f, "模型清單格式錯誤：{m}"),
            Self::Network(m) => write!(f, "網路錯誤：{m}"),
            Self::Io(e) => write!(f, "IO 錯誤：{e}"),
        }
    }
}

impl std::error::Error for DownloadError {}

impl From<std::io::Error> for DownloadError {
    fn from(e: std::io::Error) -> Self {
        Self::Io(e)
    }
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum DownloadState {
    NotStarted,
    /// 已下載的位元組數 —— 續傳的斷點。
    Partial {
        downloaded: u64,
    },
    Complete,
}

impl DownloadState {
    pub fn progress_percent(&self, total: u64) -> u8 {
        match self {
            Self::NotStarted => 0,
            Self::Complete => 100,
            Self::Partial { downloaded } if total > 0 => {
                ((*downloaded as f64 / total as f64) * 100.0).min(99.0) as u8
            }
            Self::Partial { .. } => 0,
        }
    }
}

/// 模型下載器。
#[derive(Debug)]
pub struct Downloader {
    root: PathBuf,
}

impl Downloader {
    pub fn new(root: impl Into<PathBuf>) -> Self {
        Self { root: root.into() }
    }

    /// 已驗證完成的模型路徑。
    pub fn model_path(&self, id: &str) -> PathBuf {
        self.root.join(format!("{id}.model"))
    }

    /// 下載中的暫存檔。**完成驗證前絕不改名** —— 這樣中斷留下的半檔不會被
    /// 誤認為可用的模型。
    fn partial_path(&self, id: &str) -> PathBuf {
        self.root.join(format!("{id}.partial"))
    }

    pub fn state(&self, entry: &ModelEntry) -> DownloadState {
        if self.model_path(&entry.id).exists() {
            return DownloadState::Complete;
        }
        match fs::metadata(self.partial_path(&entry.id)) {
            Ok(m) if m.len() > 0 => DownloadState::Partial {
                downloaded: m.len(),
            },
            _ => DownloadState::NotStarted,
        }
    }

    pub fn is_ready(&self, entry: &ModelEntry) -> bool {
        self.state(entry) == DownloadState::Complete
    }

    /// 下載（或續傳）一個模型。
    ///
    /// 回傳 `Ok(None)` 表示本次未完成（網路中斷），進度已保存，再呼叫即續傳。
    pub fn download(
        &self,
        entry: &ModelEntry,
        fetcher: &dyn Fetcher,
    ) -> Result<Option<PathBuf>, DownloadError> {
        if !entry.is_well_formed() {
            return Err(DownloadError::Malformed(entry.id.clone()));
        }
        let final_path = self.model_path(&entry.id);
        if final_path.exists() {
            return Ok(Some(final_path));
        }

        fs::create_dir_all(&self.root)?;
        let partial = self.partial_path(&entry.id);

        // 伺服器不支援 Range 時只能重來，既有的半檔沒有價值。
        let mut downloaded = if fetcher.supports_range() {
            fs::metadata(&partial).map(|m| m.len()).unwrap_or(0)
        } else {
            let _ = fs::remove_file(&partial);
            0
        };

        // 本機檔案比宣告的還大 ⇒ 清單換版或檔案損毀，重來比猜測安全。
        if downloaded > entry.size_bytes {
            let _ = fs::remove_file(&partial);
            downloaded = 0;
        }

        // 主來源連不上就自動改用鏡像，**不問使用者**。
        //
        // 使用者不知道自己該選哪個 —— 他只知道「下載失敗了」。介面上原本有
        // 一顆「從鏡像下載」按鈕，把一個他沒有資訊可以判斷的決定丟給他。
        //
        // 換來源之後續傳照樣進行（要求的是同一個位元組區間）。兩邊內容只要
        // 有一個位元組不同，`finalize` 的大小 + sha256 驗證會把檔案刪掉，
        // 不會把壞模型當成好的留下來。
        //
        // 只換一次，不來回跳：兩邊都連不上就是真的沒網路，繼續輪流試只會
        // 讓使用者多等而已。
        let mut url = entry.url.clone();
        let mut switched_to_mirror = false;

        while downloaded < entry.size_bytes {
            let chunk = match fetcher.fetch(&RangeRequest {
                url: url.clone(),
                from: downloaded,
            }) {
                Ok(chunk) => chunk,
                Err(err) => {
                    if switched_to_mirror || entry.mirror_url.is_empty() {
                        return Err(DownloadError::Network(err));
                    }
                    url = entry.mirror_url.clone();
                    switched_to_mirror = true;
                    continue;
                }
            };

            if chunk.is_empty() {
                // 伺服器沒給資料 —— 保住進度，讓上層稍後重試。
                //
                // 主來源給空的也算一次「連不上」：有些伺服器不回錯誤，
                // 只是安靜地不給資料，而那對使用者來說跟連不上沒有差別。
                if !switched_to_mirror && !entry.mirror_url.is_empty() {
                    url = entry.mirror_url.clone();
                    switched_to_mirror = true;
                    continue;
                }
                return Ok(None);
            }

            // 明示 truncate(false)：續傳靠 seek 定位，截斷會毀掉既有進度。
            let mut f = fs::OpenOptions::new()
                .create(true)
                .write(true)
                .truncate(false)
                .open(&partial)?;
            f.seek(SeekFrom::Start(downloaded))?;
            f.write_all(&chunk)?;
            downloaded += chunk.len() as u64;
        }

        self.finalize(entry, &partial, &final_path)
    }

    /// 驗證後改名。任何一項不符就刪檔 —— 留著壞模型只會在載入時才炸。
    fn finalize(
        &self,
        entry: &ModelEntry,
        partial: &Path,
        final_path: &Path,
    ) -> Result<Option<PathBuf>, DownloadError> {
        let actual_size = fs::metadata(partial)?.len();
        if actual_size != entry.size_bytes {
            let _ = fs::remove_file(partial);
            return Err(DownloadError::SizeMismatch {
                expected: entry.size_bytes,
                actual: actual_size,
            });
        }

        let actual = hash_file(partial)?;
        if actual != entry.sha256 {
            let _ = fs::remove_file(partial);
            return Err(DownloadError::ChecksumMismatch {
                expected: entry.sha256.clone(),
                actual,
            });
        }

        fs::rename(partial, final_path)?;
        Ok(Some(final_path.to_path_buf()))
    }

    /// 刪除模型以釋放空間（功能 I2）。
    pub fn remove(&self, id: &str) -> Result<(), DownloadError> {
        for p in [self.model_path(id), self.partial_path(id)] {
            if p.exists() {
                fs::remove_file(p)?;
            }
        }
        Ok(())
    }

    /// 目前佔用的磁碟空間。
    pub fn disk_usage(&self) -> u64 {
        let Ok(dir) = fs::read_dir(&self.root) else {
            return 0;
        };
        dir.filter_map(Result::ok)
            .filter_map(|e| e.metadata().ok())
            .filter(|m| m.is_file())
            .map(|m| m.len())
            .sum()
    }
}

/// 串流計算雜湊 —— 2.5GB 的模型不能整個讀進記憶體。
fn hash_file(path: &Path) -> Result<String, DownloadError> {
    let mut f = fs::File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buf = vec![0u8; 64 * 1024];
    loop {
        let n = f.read(&mut buf)?;
        if n == 0 {
            break;
        }
        hasher.update(&buf[..n]);
    }
    Ok(hasher
        .finalize()
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    fn tmp(name: &str) -> PathBuf {
        let d = std::env::temp_dir().join(format!("padnote-dl-{name}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&d);
        fs::create_dir_all(&d).unwrap();
        d
    }

    fn sha_hex(data: &[u8]) -> String {
        Sha256::digest(data)
            .iter()
            .map(|b| format!("{b:02x}"))
            .collect()
    }

    fn entry_for(data: &[u8]) -> ModelEntry {
        ModelEntry {
            id: "test-model".into(),
            url: "https://example.com/m.onnx".into(),
            sha256: sha_hex(data),
            size_bytes: data.len() as u64,
            license: "MIT".into(),
            required_for: vec!["asr.zh".into()],
            optional: false,
            notes: String::new(),
            mirror_url: String::new(),
        }
    }

    /// 主來源壞掉、鏡像正常。用來驗自動改用鏡像。
    struct MirrorOnlyFetcher {
        data: Vec<u8>,
        primary: String,
        /// 主來源是回錯誤，還是安靜地回空陣列。兩種都要能觸發改用鏡像。
        primary_is_silent: bool,
        urls: Mutex<Vec<String>>,
    }

    impl Fetcher for MirrorOnlyFetcher {
        fn fetch(&self, req: &RangeRequest) -> Result<Vec<u8>, String> {
            self.urls.lock().unwrap().push(req.url.clone());
            if req.url == self.primary {
                return if self.primary_is_silent {
                    Ok(Vec::new())
                } else {
                    Err("連不上".into())
                };
            }
            let from = req.from as usize;
            if from >= self.data.len() {
                return Ok(Vec::new());
            }
            Ok(self.data[from..].to_vec())
        }

        fn supports_range(&self) -> bool {
            true
        }
    }

    /// 一次最多給 `chunk` 位元組，用來模擬中斷與續傳。
    struct ChunkedFetcher {
        data: Vec<u8>,
        chunk: usize,
        range: bool,
        calls: Mutex<Vec<RangeRequest>>,
    }

    impl ChunkedFetcher {
        fn new(data: &[u8], chunk: usize) -> Self {
            Self {
                data: data.to_vec(),
                chunk,
                range: true,
                calls: Mutex::new(Vec::new()),
            }
        }
    }

    impl Fetcher for ChunkedFetcher {
        fn fetch(&self, req: &RangeRequest) -> Result<Vec<u8>, String> {
            self.calls.lock().unwrap().push(req.clone());
            let from = req.from as usize;
            if from >= self.data.len() {
                return Ok(Vec::new());
            }
            let to = (from + self.chunk).min(self.data.len());
            Ok(self.data[from..to].to_vec())
        }
        fn supports_range(&self) -> bool {
            self.range
        }
    }

    #[test]
    fn downloads_and_verifies() {
        let data = b"model weights here".repeat(100);
        let entry = entry_for(&data);
        let d = Downloader::new(tmp("ok"));

        let path = d
            .download(&entry, &ChunkedFetcher::new(&data, 4096))
            .unwrap();
        assert!(path.is_some());
        assert!(d.is_ready(&entry));
        assert_eq!(fs::read(d.model_path(&entry.id)).unwrap(), data);
    }

    #[test]
    fn resumes_from_the_partial_file() {
        // 2.5GB 在行動網路下必然中斷，續傳不是最佳化而是必需。
        let data = b"0123456789".repeat(50);
        let entry = entry_for(&data);
        let d = Downloader::new(tmp("resume"));

        // 每次只給 100 bytes，共 500 bytes ⇒ 需要多次 fetch
        let fetcher = ChunkedFetcher::new(&data, 100);
        d.download(&entry, &fetcher).unwrap();

        let calls = fetcher.calls.lock().unwrap();
        assert!(calls.len() >= 5, "應分多次取得");
        assert_eq!(calls[0].from, 0);
        assert_eq!(calls[1].from, 100, "第二次必須從斷點續傳");
    }

    #[test]
    fn partial_state_is_visible_between_attempts() {
        let data = b"x".repeat(1000);
        let entry = entry_for(&data);
        let root = tmp("partial");
        let d = Downloader::new(&root);

        // 手動放一個半檔，模擬上次中斷
        fs::write(root.join("test-model.partial"), &data[..300]).unwrap();
        assert_eq!(d.state(&entry), DownloadState::Partial { downloaded: 300 });
        assert_eq!(d.state(&entry).progress_percent(1000), 30);

        let fetcher = ChunkedFetcher::new(&data, 10_000);
        d.download(&entry, &fetcher).unwrap();

        assert_eq!(
            fetcher.calls.lock().unwrap()[0].from,
            300,
            "必須從既有的 300 bytes 續傳，而非重下"
        );
        assert_eq!(d.state(&entry), DownloadState::Complete);
    }

    #[test]
    fn corrupted_download_is_rejected_and_deleted() {
        // 留著壞模型只會在載入時才炸，而且很難診斷。
        let data = b"correct data".to_vec();
        let mut entry = entry_for(&data);
        entry.sha256 = sha_hex(b"different data");
        entry.size_bytes = data.len() as u64;

        let root = tmp("corrupt");
        let d = Downloader::new(&root);
        let err = d
            .download(&entry, &ChunkedFetcher::new(&data, 1000))
            .unwrap_err();

        assert!(matches!(err, DownloadError::ChecksumMismatch { .. }));
        assert!(!root.join("test-model.partial").exists(), "壞檔必須刪除");
        assert!(!d.is_ready(&entry));
    }

    #[test]
    fn size_mismatch_is_caught_before_hashing() {
        let data = b"short".to_vec();
        let mut entry = entry_for(&data);
        entry.size_bytes = 5; // 宣告 5，但伺服器給更多

        let bigger = b"much longer than five".to_vec();
        let d = Downloader::new(tmp("size"));
        let err = d
            .download(&entry, &ChunkedFetcher::new(&bigger, 1000))
            .unwrap_err();

        assert!(matches!(err, DownloadError::SizeMismatch { .. }));
    }

    #[test]
    fn empty_response_preserves_progress_for_retry() {
        // 伺服器暫時沒回應時，不該丟掉已下載的部分。
        struct DeadFetcher;
        impl Fetcher for DeadFetcher {
            fn fetch(&self, _: &RangeRequest) -> Result<Vec<u8>, String> {
                Ok(Vec::new())
            }
        }

        let data = b"y".repeat(500);
        let entry = entry_for(&data);
        let root = tmp("empty");
        fs::write(root.join("test-model.partial"), &data[..200]).unwrap();

        let d = Downloader::new(&root);
        assert_eq!(d.download(&entry, &DeadFetcher).unwrap(), None, "未完成");
        assert_eq!(
            d.state(&entry),
            DownloadState::Partial { downloaded: 200 },
            "進度必須保住"
        );
    }

    #[test]
    fn restarts_when_server_lacks_range_support() {
        let data = b"z".repeat(400);
        let entry = entry_for(&data);
        let root = tmp("norange");
        fs::write(root.join("test-model.partial"), &data[..150]).unwrap();

        let mut fetcher = ChunkedFetcher::new(&data, 10_000);
        fetcher.range = false;

        let d = Downloader::new(&root);
        d.download(&entry, &fetcher).unwrap();
        assert_eq!(
            fetcher.calls.lock().unwrap()[0].from,
            0,
            "不支援 Range 時只能從頭下載"
        );
    }

    #[test]
    fn oversized_partial_is_discarded() {
        // 清單換版或檔案損毀時，重來比猜測安全。
        let data = b"w".repeat(100);
        let entry = entry_for(&data);
        let root = tmp("oversize");
        fs::write(root.join("test-model.partial"), b"x".repeat(500)).unwrap();

        let fetcher = ChunkedFetcher::new(&data, 10_000);
        let d = Downloader::new(&root);
        d.download(&entry, &fetcher).unwrap();
        assert_eq!(fetcher.calls.lock().unwrap()[0].from, 0);
    }

    #[test]
    fn already_complete_download_is_a_noop() {
        let data = b"cached".to_vec();
        let entry = entry_for(&data);
        let root = tmp("cached");
        let d = Downloader::new(&root);
        fs::write(d.model_path(&entry.id), &data).unwrap();

        let fetcher = ChunkedFetcher::new(&data, 10);
        assert!(d.download(&entry, &fetcher).unwrap().is_some());
        assert!(
            fetcher.calls.lock().unwrap().is_empty(),
            "不該重下已有的模型"
        );
    }

    #[test]
    fn malformed_entry_never_reaches_the_network() {
        let mut entry = entry_for(b"x");
        entry.url = "http://insecure.example/m".into();

        let fetcher = ChunkedFetcher::new(b"x", 10);
        let d = Downloader::new(tmp("malformed"));
        assert!(matches!(
            d.download(&entry, &fetcher),
            Err(DownloadError::Malformed(_))
        ));
        assert!(fetcher.calls.lock().unwrap().is_empty());
    }

    #[test]
    fn removal_frees_space() {
        let data = b"big model".repeat(100);
        let entry = entry_for(&data);
        let root = tmp("remove");
        let d = Downloader::new(&root);
        d.download(&entry, &ChunkedFetcher::new(&data, 10_000))
            .unwrap();

        assert!(d.disk_usage() > 0);
        d.remove(&entry.id).unwrap();
        assert_eq!(d.disk_usage(), 0);
        assert_eq!(d.state(&entry), DownloadState::NotStarted);
    }

    #[test]
    fn progress_never_reports_100_until_verified() {
        // 顯示 100% 卻還在驗證會讓使用者以為卡住了。
        assert_eq!(
            DownloadState::Partial { downloaded: 999 }.progress_percent(1000),
            99
        );
        assert_eq!(DownloadState::Complete.progress_percent(1000), 100);
        assert_eq!(DownloadState::NotStarted.progress_percent(1000), 0);
    }

    /// 主來源回錯誤時自動改用鏡像 —— **不問使用者**。
    ///
    /// 介面上原本有一顆「從鏡像下載」按鈕，而使用者不知道自己該選哪個：
    /// 他只知道「下載失敗了」。這條測試守的是「不必問也會成功」。
    #[test]
    fn falls_back_to_the_mirror_when_the_primary_errors() {
        let data = b"weights".repeat(500);
        let mut entry = entry_for(&data);
        entry.mirror_url = "https://mirror.example.com/m.onnx".into();

        let fetcher = MirrorOnlyFetcher {
            data: data.clone(),
            primary: entry.url.clone(),
            primary_is_silent: false,
            urls: Mutex::new(Vec::new()),
        };
        let d = Downloader::new(tmp("mirror-error"));
        let path = d.download(&entry, &fetcher).unwrap();

        assert!(path.is_some(), "改用鏡像之後應該要下載成功");
        let urls = fetcher.urls.lock().unwrap();
        assert_eq!(urls[0], entry.url, "第一次要先試主來源");
        assert!(
            urls[1..].iter().all(|u| *u == entry.mirror_url),
            "換過去之後就不該再回頭試主來源 —— 來回跳只會讓使用者多等"
        );
    }

    /// 主來源安靜地回空陣列（不回錯誤）也要改用鏡像。
    ///
    /// 有些伺服器不回錯誤，只是不給資料。對使用者來說那跟連不上沒有差別，
    /// 而原本的邏輯會把它當成「保住進度，稍後重試」—— 於是永遠不會成功。
    #[test]
    fn falls_back_when_the_primary_goes_quiet() {
        let data = b"weights".repeat(500);
        let mut entry = entry_for(&data);
        entry.mirror_url = "https://mirror.example.com/m.onnx".into();

        let fetcher = MirrorOnlyFetcher {
            data: data.clone(),
            primary: entry.url.clone(),
            primary_is_silent: true,
            urls: Mutex::new(Vec::new()),
        };
        let d = Downloader::new(tmp("mirror-quiet"));
        assert!(d.download(&entry, &fetcher).unwrap().is_some());
    }

    /// 沒有鏡像時行為不變：主來源錯誤就是錯誤。
    #[test]
    fn without_a_mirror_a_primary_error_is_still_an_error() {
        let data = b"weights".repeat(500);
        let entry = entry_for(&data); // mirror_url 是空的
        let fetcher = MirrorOnlyFetcher {
            data,
            primary: entry.url.clone(),
            primary_is_silent: false,
            urls: Mutex::new(Vec::new()),
        };
        let d = Downloader::new(tmp("no-mirror"));
        assert!(matches!(
            d.download(&entry, &fetcher),
            Err(DownloadError::Network(_))
        ));
    }

    /// 鏡像給的內容不一樣時要被擋下來，而不是留一個壞模型。
    #[test]
    fn a_mirror_serving_different_bytes_is_rejected() {
        let real = b"weights".repeat(500);
        let mut entry = entry_for(&real);
        entry.mirror_url = "https://mirror.example.com/m.onnx".into();

        // 大小一樣、內容不同 —— 只有 sha256 擋得住。
        let tampered = b"WEIGHTS".repeat(500);
        let fetcher = MirrorOnlyFetcher {
            data: tampered,
            primary: entry.url.clone(),
            primary_is_silent: false,
            urls: Mutex::new(Vec::new()),
        };
        let d = Downloader::new(tmp("mirror-tampered"));
        assert!(matches!(
            d.download(&entry, &fetcher),
            Err(DownloadError::ChecksumMismatch { .. })
        ));
    }
}
