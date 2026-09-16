//! 本機資料夾 provider（D11 之後定位為手動備份／匯入匯出備援）。
//!
//! 這些工具本身就在做檔案同步；Padnote 只要把 append-only 不變式守好即可。
//!
//! # iCloud Drive 也走這一條（S-19）
//!
//! iCloud 的 ubiquity container 就是一個檔案系統路徑，所以不需要另一個
//! provider —— 平台層把容器路徑交進來即可。**唯一的差別是「檔案可能還沒下載」**：
//! iCloud 會把沒下載的檔案換成一個叫 `.原檔名.icloud` 的佔位檔，原檔案不存在。
//!
//! 不處理佔位檔的話，`list()` 會把 `.log-0.bin.icloud` 當成一個真的檔案回報 ——
//! 那個名字不在因果序上，同步引擎讀它會拿到一段 plist 而不是 chunk。
//! 所以這裡把佔位檔還原成**邏輯檔名**，讀取時回 `NotMaterialized`，
//! 讓平台層去呼叫 `startDownloadingUbiquitousItem` 再重試。

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
        let mut f = match fs::File::open(&p) {
            Ok(f) => f,
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
                // 檔案不在，但 iCloud 的佔位檔在 ⇒ 還沒下載，不是不存在。
                // 兩者要分開：上層看到 NotFound 會當成「沒這個東西」而跳過，
                // 看到 NotMaterialized 才會去觸發下載然後重試。
                if placeholder_for(&p).exists() {
                    return Err(SyncError::NotMaterialized(path.into()));
                }
                return Err(SyncError::NotFound(path.into()));
            }
            Err(e) => return Err(SyncError::Io(e)),
        };
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

/// 某個檔案對應的 iCloud 佔位檔路徑（`dir/.name.icloud`）。
fn placeholder_for(path: &Path) -> PathBuf {
    let name = path
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_default();
    path.with_file_name(format!(".{name}.icloud"))
}

/// 佔位檔名 → 邏輯檔名。不是佔位檔就回 `None`。
///
/// iCloud 的規則是「前面加一個點、後面加 `.icloud`」。只檢查副檔名是不夠的：
/// 使用者自己建一個叫 `notes.icloud` 的檔案時不該被當成佔位檔而改名。
fn logical_name(file_name: &str) -> Option<String> {
    let inner = file_name.strip_prefix('.')?.strip_suffix(".icloud")?;
    if inner.is_empty() {
        return None;
    }
    Some(inner.to_string())
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
            name.clone()
        } else {
            format!("{prefix}/{name}")
        };
        if meta.is_dir() {
            collect_recursive(&entry.path(), &path, out)?;
        } else if meta.is_file() {
            match logical_name(&name) {
                // iCloud 佔位檔：回報**邏輯檔名**，大小未知填 0。
                // 大小是給增量拉取用的；還沒下載的檔案本來就拉不了，
                // 填一個假的數字只會讓上層以為讀得到。
                Some(real_name) => {
                    let logical = if prefix.is_empty() {
                        real_name
                    } else {
                        format!("{prefix}/{real_name}")
                    };
                    out.push(RemoteEntry {
                        path: logical,
                        size: 0,
                    });
                }
                None => out.push(RemoteEntry {
                    path,
                    size: meta.len(),
                }),
            }
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
    fn an_icloud_placeholder_is_listed_under_its_real_name() {
        // 不還原名字的話，`.log-0.bin.icloud` 會被當成一個真的檔案回報。
        // 那個名字不在因果序上，而且讀它會拿到一段 plist 而不是 chunk。
        let root = tmp("icloud-list");
        fs::create_dir_all(root.join("sync/dev1")).unwrap();
        fs::write(root.join("sync/dev1/.log-0.bin.icloud"), b"<plist/>").unwrap();

        let p = LocalFolderProvider::new(&root);
        let listed = p.list("sync").unwrap();
        assert_eq!(listed.len(), 1);
        assert_eq!(listed[0].path, "sync/dev1/log-0.bin");
        // 還沒下載，大小未知 —— 填一個假數字只會讓上層以為讀得到。
        assert_eq!(listed[0].size, 0);
    }

    #[test]
    fn reading_a_placeholder_says_not_materialized_not_not_found() {
        // 這兩個要分開：NotFound 會讓上層當成「沒這個東西」而跳過，
        // NotMaterialized 才會去觸發下載然後重試。
        let root = tmp("icloud-read");
        fs::create_dir_all(root.join("sync/dev1")).unwrap();
        fs::write(root.join("sync/dev1/.log-0.bin.icloud"), b"<plist/>").unwrap();

        let p = LocalFolderProvider::new(&root);
        assert!(matches!(
            p.get_range("sync/dev1/log-0.bin", 0..10),
            Err(SyncError::NotMaterialized(_))
        ));
        // 真的不存在的仍然是 NotFound。
        assert!(matches!(
            p.get_range("sync/dev1/never.bin", 0..10),
            Err(SyncError::NotFound(_))
        ));
    }

    #[test]
    fn a_downloaded_file_wins_over_its_leftover_placeholder() {
        // 下載完成之後佔位檔可能還在。此時要讀真的那一份。
        let root = tmp("icloud-both");
        fs::create_dir_all(root.join("sync/dev1")).unwrap();
        fs::write(root.join("sync/dev1/log-0.bin"), b"real").unwrap();
        fs::write(root.join("sync/dev1/.log-0.bin.icloud"), b"<plist/>").unwrap();

        let p = LocalFolderProvider::new(&root);
        assert_eq!(p.get_range("sync/dev1/log-0.bin", 0..4).unwrap(), b"real");
    }

    #[test]
    fn a_users_own_dot_icloud_file_is_not_mistaken_for_a_placeholder() {
        // 只看副檔名的話，使用者自己建的 `notes.icloud` 會被改名成 `notes`。
        let root = tmp("icloud-userfile");
        fs::create_dir_all(root.join("docs")).unwrap();
        fs::write(root.join("docs/notes.icloud"), b"mine").unwrap();

        let p = LocalFolderProvider::new(&root);
        let listed = p.list("docs").unwrap();
        assert_eq!(listed[0].path, "docs/notes.icloud");
        assert_eq!(listed[0].size, 4);
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
