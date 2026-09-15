//! 本機資料夾 provider（D11 之後定位為手動備份／匯入匯出備援）。
//!
//! 這些工具本身就在做檔案同步；Padnote 只要把 append-only 不變式守好即可。

use crate::provider::{CloudProvider, RemoteEntry, SyncError};
use std::fs;
use std::io::{Read, Seek, SeekFrom, Write};
use std::ops::Range;
use std::path::{Path, PathBuf};

#[derive(Debug)]
pub struct LocalFolderProvider {
    root: PathBuf,
}

impl LocalFolderProvider {
    pub fn new(root: impl Into<PathBuf>) -> Self {
        Self { root: root.into() }
    }

    /// 解析並確保路徑不逃出 root（防止惡意或損毀的 manifest 造成越界寫入）。
    fn resolve(&self, path: &str) -> Result<PathBuf, SyncError> {
        if path.contains("..") || Path::new(path).is_absolute() {
            return Err(SyncError::PermissionDenied(path.into()));
        }
        Ok(self.root.join(path))
    }
}

impl CloudProvider for LocalFolderProvider {
    fn list(&self, prefix: &str) -> Result<Vec<RemoteEntry>, SyncError> {
        let dir = self.resolve(prefix)?;
        if !dir.exists() {
            return Ok(Vec::new());
        }
        let mut out = Vec::new();
        collect_recursive(&dir, prefix.trim_end_matches('/'), &mut out)?;
        // 檔名字典序即因果序（format-spec §6.1），排序後即為套用順序。
        out.sort_by(|a, b| a.path.cmp(&b.path));
        Ok(out)
    }

    fn get_range(&self, path: &str, range: Range<u64>) -> Result<Vec<u8>, SyncError> {
        let p = self.resolve(path)?;
        let mut f = fs::File::open(&p).map_err(|e| match e.kind() {
            std::io::ErrorKind::NotFound => SyncError::NotFound(path.into()),
            _ => SyncError::Io(e),
        })?;
        let len = f.metadata()?.len();
        if range.start >= len {
            return Ok(Vec::new());
        }
        let end = range.end.min(len);
        f.seek(SeekFrom::Start(range.start))?;
        let mut buf = vec![0u8; (end - range.start) as usize];
        f.read_exact(&mut buf)?;
        Ok(buf)
    }

    fn append(&self, path: &str, data: &[u8]) -> Result<(), SyncError> {
        let p = self.resolve(path)?;
        if let Some(parent) = p.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(&p)?
            .write_all(data)?;
        Ok(())
    }

    fn put(&self, path: &str, data: &[u8]) -> Result<(), SyncError> {
        let p = self.resolve(path)?;
        if let Some(parent) = p.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(&p, data)?;
        Ok(())
    }

    fn supports_native_append(&self) -> bool {
        true
    }
}

/// 遞迴收集檔案，維持物件儲存的前綴列舉語意。
fn collect_recursive(
    dir: &Path,
    prefix: &str,
    out: &mut Vec<RemoteEntry>,
) -> Result<(), SyncError> {
    for entry in fs::read_dir(dir)? {
        let entry = entry?;
        let meta = entry.metadata()?;
        let name = entry.file_name().to_string_lossy().into_owned();
        let path = if prefix.is_empty() {
            name
        } else {
            format!("{prefix}/{name}")
        };
        if meta.is_dir() {
            collect_recursive(&entry.path(), &path, out)?;
        } else if meta.is_file() {
            out.push(RemoteEntry {
                path,
                size: meta.len(),
            });
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tmp(name: &str) -> PathBuf {
        let d = std::env::temp_dir().join(format!("padnote-test-{name}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&d);
        fs::create_dir_all(&d).unwrap();
        d
    }

    #[test]
    fn append_accumulates_without_rewriting() {
        let root = tmp("append");
        let p = LocalFolderProvider::new(&root);
        p.append("sync/dev1/log-0.bin", b"hello").unwrap();
        p.append("sync/dev1/log-0.bin", b" world").unwrap();
        assert_eq!(
            p.get_range("sync/dev1/log-0.bin", 0..100).unwrap(),
            b"hello world"
        );
    }

    #[test]
    fn get_range_supports_incremental_pull() {
        let root = tmp("range");
        let p = LocalFolderProvider::new(&root);
        p.put("a.bin", b"0123456789").unwrap();
        assert_eq!(p.get_range("a.bin", 4..8).unwrap(), b"4567");
        // 已讀到尾端時回傳空，而非錯誤 —— 同步迴圈的正常終止條件。
        assert!(p.get_range("a.bin", 10..20).unwrap().is_empty());
    }

    #[test]
    fn list_returns_causal_order() {
        let root = tmp("list");
        let p = LocalFolderProvider::new(&root);
        for l in ["0000000000000010", "0000000000000002", "0000000000000100"] {
            p.put(&format!("ops/{l}-aaaaaaaa.oplog"), b"x").unwrap();
        }
        let entries = p.list("ops").unwrap();
        let names: Vec<&str> = entries
            .iter()
            .map(|e| &e.path.rsplit('/').next().unwrap()[..16])
            .collect();
        assert_eq!(
            names,
            ["0000000000000002", "0000000000000010", "0000000000000100"]
        );
    }

    #[test]
    fn list_is_prefix_recursive_not_single_level() {
        // 同步引擎靠這個看到其他裝置的目錄；只列單層會讓 pull 永遠空手而回。
        let root = tmp("recursive");
        let p = LocalFolderProvider::new(&root);
        p.put("sync/000000a1/log-0.bin", b"a").unwrap();
        p.put("sync/000000b2/log-0.bin", b"b").unwrap();

        let paths: Vec<String> = p
            .list("sync")
            .unwrap()
            .into_iter()
            .map(|e| e.path)
            .collect();
        assert_eq!(
            paths,
            ["sync/000000a1/log-0.bin", "sync/000000b2/log-0.bin"]
        );
    }

    #[test]
    fn missing_prefix_is_empty_not_error() {
        let p = LocalFolderProvider::new(tmp("missing"));
        assert!(p.list("nope").unwrap().is_empty());
    }

    #[test]
    fn rejects_path_traversal() {
        let p = LocalFolderProvider::new(tmp("traversal"));
        assert!(matches!(
            p.put("../escape.bin", b"x"),
            Err(SyncError::PermissionDenied(_))
        ));
    }
}
