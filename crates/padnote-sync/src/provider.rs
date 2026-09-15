//! `CloudProvider` 抽象（`architecture.md` §4.3）。
//!
//! D11 之後，正式自動同步主線是 Google Drive `appDataFolder`。
//! 本機資料夾 provider 保留為手動備份、匯入匯出與進階使用者備援。

use std::fmt::Debug;
use std::ops::Range;

/// 雲端上的一個檔案項目。
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RemoteEntry {
    pub path: String,
    pub size: u64,
}

#[derive(Debug)]
pub enum SyncError {
    NotFound(String),
    /// 檔案存在於 iCloud 但尚未下載到本機。
    NotMaterialized(String),
    PermissionDenied(String),
    Io(std::io::Error),
    Backend(String),
}

impl std::fmt::Display for SyncError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NotFound(p) => write!(f, "找不到：{p}"),
            Self::NotMaterialized(p) => write!(f, "檔案尚未從雲端下載：{p}"),
            Self::PermissionDenied(p) => write!(f, "權限不足：{p}"),
            Self::Io(e) => write!(f, "IO 錯誤：{e}"),
            Self::Backend(m) => write!(f, "後端錯誤：{m}"),
        }
    }
}

impl std::error::Error for SyncError {}

impl From<std::io::Error> for SyncError {
    fn from(e: std::io::Error) -> Self {
        Self::Io(e)
    }
}

/// 啞檔案桶介面。雲端不做任何運算，也看不見內容（chunk 已加密）。
pub trait CloudProvider: Send + Sync + Debug {
    /// 依**前綴遞迴**列出檔案（物件儲存語意，非「列單層目錄」）。
    ///
    /// 這點很重要：`list("sync")` 必須回傳 `sync/<device>/log-0.bin`，
    /// 否則同步引擎看不到其他裝置的目錄。
    fn list(&self, prefix: &str) -> Result<Vec<RemoteEntry>, SyncError>;

    /// 增量拉取 —— 避免每次同步重下整個 log。
    fn get_range(&self, path: &str, range: Range<u64>) -> Result<Vec<u8>, SyncError>;

    fn append(&self, path: &str, data: &[u8]) -> Result<(), SyncError>;

    fn put(&self, path: &str, data: &[u8]) -> Result<(), SyncError>;

    /// Google Drive 無 append API ⇒ 回傳 `false`，由上層退化為分塊檔策略
    /// （`format-spec.md` §7.2）。
    fn supports_native_append(&self) -> bool;
}
