//! 原子寫入（P0 共通基準）。
//!
//! # 為什麼半個檔案比沒有檔案更危險
//!
//! 同步的正確性建立在「同一個檔名只會變長，較長的那份是超集」之上。
//! 一個寫到一半就中斷的檔案**完全符合這個描述** —— 它是一個合法的
//! append-only 前綴，長度也真的比較短。所以對面不會察覺有問題，
//! 只會安靜地把它當成「比較舊的版本」，然後用它覆蓋掉正確的內容。
//!
//! Android 的 SAF 與部分檔案系統不保證寫入的原子性，Apple 端在同容器內
//! rename 才是原子的。兩邊唯一共通、都成立的做法是：
//!
//! > 寫到 `<name>.part` → fsync → rename 到 `<name>` → fsync 父目錄
//!
//! rename 在 POSIX 上是原子的，所以讀者看到的永遠是「舊的完整檔」或
//! 「新的完整檔」，不會有中間狀態。
//!
//! fsync 那一步不能省：rename 是原子的，但**它與資料落盤之間沒有順序保證**。
//! 少了 fsync，斷電後可能得到一個名字正確、內容是零的檔案。

use std::fs;
use std::io::Write;
use std::path::Path;

/// 把位元組原子地寫到 `path`。
///
/// 父目錄不存在時會建立。臨時檔與目標**同目錄**（跨檔案系統 rename 會失敗）。
pub fn write_atomic(path: &Path, bytes: &[u8]) -> std::io::Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let tmp = tmp_path(path);
    {
        let mut file = fs::File::create(&tmp)?;
        file.write_all(bytes)?;
        // 資料先落盤，再換名字。反過來的話，斷電後會得到一個
        // 名字正確、內容是零的檔案 —— 而那看起來完全合法。
        file.sync_all()?;
    }
    match fs::rename(&tmp, path) {
        Ok(()) => {}
        Err(e) => {
            let _ = fs::remove_file(&tmp);
            return Err(e);
        }
    }
    // 父目錄的 fsync 讓「這個名字現在指向新的 inode」這件事也落盤。
    // 失敗不致命（某些檔案系統不支援對目錄 fsync），所以不往上拋。
    if let Some(parent) = path.parent()
        && let Ok(dir) = fs::File::open(parent)
    {
        let _ = dir.sync_all();
    }
    Ok(())
}

/// 臨時檔名。**同目錄**，而且帶 `.part` 讓掃描目錄的程式碼認得出來要跳過它。
fn tmp_path(path: &Path) -> std::path::PathBuf {
    let name = path
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("unnamed");
    let pid = std::process::id();
    path.with_file_name(format!(".{name}.{pid}.part"))
}

/// 這個檔名是不是原子寫入留下的臨時檔。
///
/// 列目錄時要跳過 —— 把它算進同步清單的話，對面會下載到一個
/// 永遠不會完成的檔案。
pub fn is_temp_name(name: &str) -> bool {
    name.starts_with('.') && name.ends_with(".part") || name.ends_with(".tmp")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tmp_dir(name: &str) -> std::path::PathBuf {
        let d = std::env::temp_dir().join(format!("padnote-atomic-{name}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&d);
        fs::create_dir_all(&d).unwrap();
        d
    }

    #[test]
    fn writes_the_whole_file() {
        let dir = tmp_dir("whole");
        let path = dir.join("a.oplog");
        write_atomic(&path, b"hello").unwrap();
        assert_eq!(fs::read(&path).unwrap(), b"hello");
    }

    #[test]
    fn creates_missing_parents() {
        let dir = tmp_dir("parents");
        let path = dir.join("doc/ops/a.oplog");
        write_atomic(&path, b"x").unwrap();
        assert!(path.exists());
    }

    #[test]
    fn leaves_no_temp_file_behind() {
        // 留下來的話，下一次列目錄會把它當成一個真的 oplog 檔送上雲端。
        let dir = tmp_dir("notemp");
        write_atomic(&dir.join("a.oplog"), b"x").unwrap();
        let names: Vec<String> = fs::read_dir(&dir)
            .unwrap()
            .filter_map(Result::ok)
            .map(|e| e.file_name().to_string_lossy().into_owned())
            .collect();
        assert_eq!(names, vec!["a.oplog".to_string()]);
    }

    #[test]
    fn overwriting_is_atomic_in_the_sense_that_the_old_content_never_truncates() {
        // 重點不是「寫得進去」，是**不會出現長度介於兩者之間的中間狀態**。
        let dir = tmp_dir("overwrite");
        let path = dir.join("a.oplog");
        write_atomic(&path, b"aaaaaaaaaa").unwrap();
        write_atomic(&path, b"bb").unwrap();
        assert_eq!(fs::read(&path).unwrap(), b"bb");
    }

    #[test]
    fn temp_names_are_recognisable() {
        assert!(is_temp_name(".a.oplog.123.part"));
        assert!(is_temp_name("x.tmp"));
        assert!(!is_temp_name("0000000000000001-000000aa.oplog"));
    }
}
