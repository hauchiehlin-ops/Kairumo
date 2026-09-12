//! 內容定址的 blob 儲存（format-spec §2）。
//!
//! 路徑為 `media/blobs/<前2碼>/<sha256>`。內容定址帶來三個好處：
//! 1. **天然去重** —— 同一張圖插入 10 次只佔一份空間
//! 2. **同步免比對** —— 檔名即內容雜湊，存在即最新，不需要版本協商
//! 3. **完整性自證** —— 讀取時重算雜湊即可偵測損毀

use sha2::{Digest, Sha256};
use std::fmt;
use std::fs;
use std::path::{Path, PathBuf};

/// blob 的內容雜湊。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct BlobId([u8; 32]);

impl BlobId {
    pub fn of(data: &[u8]) -> Self {
        let mut h = Sha256::new();
        h.update(data);
        Self(h.finalize().into())
    }

    pub fn from_hex(s: &str) -> Option<Self> {
        if s.len() != 64 {
            return None;
        }
        let mut out = [0u8; 32];
        for (i, chunk) in s.as_bytes().chunks(2).enumerate() {
            let hex = std::str::from_utf8(chunk).ok()?;
            out[i] = u8::from_str_radix(hex, 16).ok()?;
        }
        Some(Self(out))
    }

    /// 套件內的相對路徑。前 2 個 hex 字元分桶，避免單一目錄塞進數萬個檔案
    /// （在 iCloud Drive 與部分檔案系統上會嚴重拖慢列目錄）。
    pub fn relative_path(&self) -> String {
        let hex = self.to_string();
        format!("media/blobs/{}/{hex}", &hex[..2])
    }

    pub fn as_bytes(&self) -> &[u8; 32] {
        &self.0
    }
}

impl fmt::Display for BlobId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        for b in &self.0 {
            write!(f, "{b:02x}")?;
        }
        Ok(())
    }
}

impl fmt::Debug for BlobId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "BlobId({})", &self.to_string()[..12])
    }
}

#[derive(Debug)]
pub struct BlobStore {
    root: PathBuf,
}

#[derive(Debug)]
pub enum BlobError {
    NotFound(BlobId),
    /// 讀出的內容與檔名宣告的雜湊不符 —— 檔案已損毀。
    Corrupted {
        expected: BlobId,
        actual: BlobId,
    },
    Io(std::io::Error),
}

impl fmt::Display for BlobError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::NotFound(id) => write!(f, "找不到 blob：{id}"),
            Self::Corrupted { expected, actual } => {
                write!(f, "blob 損毀：期望 {expected}，實得 {actual}")
            }
            Self::Io(e) => write!(f, "IO 錯誤：{e}"),
        }
    }
}

impl std::error::Error for BlobError {}

impl From<std::io::Error> for BlobError {
    fn from(e: std::io::Error) -> Self {
        Self::Io(e)
    }
}

impl BlobStore {
    pub fn new(package_root: impl Into<PathBuf>) -> Self {
        Self {
            root: package_root.into(),
        }
    }

    fn path_of(&self, id: BlobId) -> PathBuf {
        self.root.join(id.relative_path())
    }

    /// 寫入並回傳內容雜湊。已存在時直接回傳（**去重，不重複寫入**）。
    pub fn put(&self, data: &[u8]) -> Result<BlobId, BlobError> {
        let id = BlobId::of(data);
        let path = self.path_of(id);
        if path.exists() {
            return Ok(id);
        }
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }

        // 先寫暫存檔再 rename：避免中途當機留下半個 blob 卻頂著正確的檔名。
        let tmp = path.with_extension("tmp");
        fs::write(&tmp, data)?;
        fs::rename(&tmp, &path)?;
        Ok(id)
    }

    /// 讀取並**驗證完整性**。雜湊不符時回報 `Corrupted` 而非回傳壞資料。
    pub fn get(&self, id: BlobId) -> Result<Vec<u8>, BlobError> {
        let path = self.path_of(id);
        let data = fs::read(&path).map_err(|e| match e.kind() {
            std::io::ErrorKind::NotFound => BlobError::NotFound(id),
            _ => BlobError::Io(e),
        })?;

        let actual = BlobId::of(&data);
        if actual != id {
            return Err(BlobError::Corrupted {
                expected: id,
                actual,
            });
        }
        Ok(data)
    }

    pub fn contains(&self, id: BlobId) -> bool {
        self.path_of(id).exists()
    }

    /// 列出所有 blob。供 GC 與完整性掃描使用。
    pub fn list(&self) -> Result<Vec<BlobId>, BlobError> {
        let dir = self.root.join("media/blobs");
        if !dir.exists() {
            return Ok(Vec::new());
        }
        let mut out = Vec::new();
        for bucket in fs::read_dir(&dir)? {
            let bucket = bucket?;
            if !bucket.file_type()?.is_dir() {
                continue;
            }
            for entry in fs::read_dir(bucket.path())? {
                let name = entry?.file_name();
                if let Some(id) = BlobId::from_hex(&name.to_string_lossy()) {
                    out.push(id);
                }
            }
        }
        out.sort();
        Ok(out)
    }

    /// 刪除未被引用的 blob。
    ///
    /// ⚠️ `referenced` 必須是**完整**的引用集合。漏掉任何一個都會造成資料遺失，
    /// 因此呼叫端必須掃過所有頁面、所有版本歷史後才呼叫。
    pub fn collect_garbage(&self, referenced: &[BlobId]) -> Result<usize, BlobError> {
        let keep: std::collections::HashSet<BlobId> = referenced.iter().copied().collect();
        let mut removed = 0;
        for id in self.list()? {
            if !keep.contains(&id) {
                fs::remove_file(self.path_of(id))?;
                removed += 1;
            }
        }
        Ok(removed)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tmp(name: &str) -> PathBuf {
        let d = std::env::temp_dir().join(format!("padnote-blob-{name}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&d);
        fs::create_dir_all(&d).unwrap();
        d
    }

    #[test]
    fn same_content_yields_same_id() {
        assert_eq!(BlobId::of(b"hello"), BlobId::of(b"hello"));
        assert_ne!(BlobId::of(b"hello"), BlobId::of(b"hello "));
    }

    #[test]
    fn hex_roundtrips() {
        let id = BlobId::of(b"padnote");
        assert_eq!(BlobId::from_hex(&id.to_string()), Some(id));
        assert_eq!(BlobId::from_hex("tooshort"), None);
        assert_eq!(BlobId::from_hex(&"z".repeat(64)), None);
    }

    #[test]
    fn path_is_bucketed_by_first_two_hex_chars() {
        let id = BlobId::of(b"x");
        let p = id.relative_path();
        let hex = id.to_string();
        assert_eq!(p, format!("media/blobs/{}/{hex}", &hex[..2]));
    }

    #[test]
    fn put_deduplicates_identical_content() {
        let store = BlobStore::new(tmp("dedup"));
        let a = store.put(b"same image bytes").unwrap();
        let b = store.put(b"same image bytes").unwrap();
        assert_eq!(a, b);
        assert_eq!(store.list().unwrap().len(), 1, "相同內容只該存一份");
    }

    #[test]
    fn get_returns_what_was_put() {
        let store = BlobStore::new(tmp("get"));
        let data = vec![0xABu8; 10_000];
        let id = store.put(&data).unwrap();
        assert_eq!(store.get(id).unwrap(), data);
    }

    #[test]
    fn detects_corruption_instead_of_returning_bad_data() {
        let root = tmp("corrupt");
        let store = BlobStore::new(&root);
        let id = store.put(b"original").unwrap();

        // 模擬磁碟損毀或同步工具寫壞
        fs::write(root.join(id.relative_path()), b"tampered").unwrap();

        assert!(
            matches!(store.get(id), Err(BlobError::Corrupted { .. })),
            "必須偵測到損毀，絕不回傳壞資料"
        );
    }

    #[test]
    fn missing_blob_is_not_found_not_io_error() {
        let store = BlobStore::new(tmp("missing"));
        let id = BlobId::of(b"never stored");
        assert!(matches!(store.get(id), Err(BlobError::NotFound(_))));
        assert!(!store.contains(id));
    }

    #[test]
    fn gc_removes_only_unreferenced() {
        let store = BlobStore::new(tmp("gc"));
        let keep = store.put(b"still used").unwrap();
        let drop1 = store.put(b"orphan a").unwrap();
        let _drop2 = store.put(b"orphan b").unwrap();

        let removed = store.collect_garbage(&[keep]).unwrap();
        assert_eq!(removed, 2);
        assert!(store.contains(keep));
        assert!(!store.contains(drop1));
    }

    #[test]
    fn gc_with_empty_reference_set_clears_all() {
        // 這個行為很危險但正確 —— 測試存在是為了讓呼叫端看到後果。
        let store = BlobStore::new(tmp("gc-all"));
        store.put(b"a").unwrap();
        store.put(b"b").unwrap();
        assert_eq!(store.collect_garbage(&[]).unwrap(), 2);
    }
}
