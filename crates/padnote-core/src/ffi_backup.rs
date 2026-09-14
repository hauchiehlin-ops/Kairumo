//! 個人資料備份與一鍵復原。
//!
//! # 為什麼容器格式寫在核心
//!
//! 備份檔要能在任何一台裝置上還原 —— iPad 上做的備份，換到 Android 也要開得起來。
//! 兩個平台各寫一份格式的話，那件事第一天就不成立。所以容器、索引、
//! 校驗全部在這裡，平台層只負責「哪些檔案要進去」與「使用者按了什麼」。
//!
//! # 容器佈局
//!
//! ```text
//! "KAIRBAK\0"        8 bytes   魔術字
//! version            u16       格式版本
//! reserved           u16
//! index_len          u32       索引 JSON 的長度
//! index              JSON      每個項目的路徑、大小、SHA-256，以及平台設定
//! payload            bytes     依索引順序連續排列的檔案內容
//! digest             32 bytes  上述全部內容的 SHA-256
//! ```
//!
//! # 為什麼每個檔案都要自己的雜湊
//!
//! 只有整體雜湊的話，備份檔壞掉時只知道「壞了」，不知道壞在哪 ——
//! 而使用者最想問的正是「我的筆記還在嗎」。逐檔雜湊讓還原時能明確說出
//! 哪幾個檔案不可信，其餘照樣救回來。

use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};

const MAGIC: &[u8; 8] = b"KAIRBAK\0";
const VERSION: u16 = 1;
const HEADER_LEN: usize = 16;
const DIGEST_LEN: usize = 32;

#[derive(Debug, uniffi::Error)]
pub enum BackupError {
    NotABackup,
    /// 讀取器不支援的版本 —— 必須拒絕而非猜測解析。
    UnsupportedVersion {
        found: u16,
        supported: u16,
    },
    Corrupt(String),
    Io(String),
}

impl std::fmt::Display for BackupError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NotABackup => write!(f, "不是 Kairumo 備份檔"),
            Self::UnsupportedVersion { found, supported } => write!(
                f,
                "備份檔版本 {found} 比這個版本的 App 新（支援到 {supported}），請先更新 App"
            ),
            Self::Corrupt(m) => write!(f, "備份檔已損毀：{m}"),
            Self::Io(m) => write!(f, "讀寫失敗：{m}"),
        }
    }
}

impl std::error::Error for BackupError {}

impl From<std::io::Error> for BackupError {
    fn from(e: std::io::Error) -> Self {
        Self::Io(e.to_string())
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct Index {
    created_unix_ms: u64,
    app_version: String,
    /// 平台自己的設定（Apple 的 UserDefaults、Android 的 SharedPreferences）。
    /// 核心不解讀它的內容，只負責原樣搬運。
    settings_json: String,
    entries: Vec<IndexEntry>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct IndexEntry {
    path: String,
    size: u64,
    sha256: String,
}

/// 備份檔的內容摘要。還原之前先給使用者看這個。
#[derive(Clone, Debug, uniffi::Record)]
pub struct BackupInfo {
    pub created_unix_ms: u64,
    pub app_version: String,
    pub file_count: u32,
    pub total_bytes: u64,
    pub settings_json: String,
    /// 整體校驗是否通過。`false` 時仍可嘗試還原，但要明確警告使用者。
    pub digest_ok: bool,
}

/// 一次還原的結果。
#[derive(Clone, Debug, uniffi::Record)]
pub struct RestoreReport {
    pub restored: Vec<String>,
    /// 雜湊對不上而**沒有**寫入的檔案。寧可少一個檔，也不要用壞掉的內容
    /// 覆蓋掉使用者現有的資料。
    pub corrupted: Vec<String>,
    pub settings_json: String,
}

// ---- 建立 ----

/// 把一個目錄打包成備份檔。
///
/// `settings_json` 由平台層提供（自己的設定），核心原樣搬運不解讀。
#[uniffi::export]
pub fn create_backup(
    source_dir: String,
    out_path: String,
    app_version: String,
    settings_json: String,
    now_unix_ms: u64,
) -> Result<BackupInfo, BackupError> {
    let source = PathBuf::from(&source_dir);
    let mut entries = Vec::new();
    let mut payload = Vec::new();

    for path in walk(&source)? {
        let relative = path
            .strip_prefix(&source)
            .map_err(|e| BackupError::Io(e.to_string()))?
            .to_string_lossy()
            .replace('\\', "/");
        // 備份檔不要把自己包進去（輸出檔可能就放在來源目錄裡）。
        if path == Path::new(&out_path) {
            continue;
        }
        let bytes = fs::read(&path)?;
        entries.push(IndexEntry {
            path: relative,
            size: bytes.len() as u64,
            sha256: hex(&Sha256::digest(&bytes)),
        });
        payload.extend_from_slice(&bytes);
    }

    let index = Index {
        created_unix_ms: now_unix_ms,
        app_version,
        settings_json,
        entries,
    };
    let index_bytes =
        serde_json::to_vec(&index).map_err(|e| BackupError::Corrupt(e.to_string()))?;

    let mut out = Vec::with_capacity(HEADER_LEN + index_bytes.len() + payload.len() + DIGEST_LEN);
    out.extend_from_slice(MAGIC);
    out.extend_from_slice(&VERSION.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&(index_bytes.len() as u32).to_le_bytes());
    out.extend_from_slice(&index_bytes);
    out.extend_from_slice(&payload);
    let digest = Sha256::digest(&out);
    out.extend_from_slice(&digest);

    if let Some(parent) = Path::new(&out_path).parent() {
        fs::create_dir_all(parent)?;
    }
    // 先寫暫存檔再改名：中途失敗時不會留下一個**看起來像備份**的半成品，
    // 那種檔案比沒有備份更危險。
    let tmp = format!("{out_path}.partial");
    {
        let mut f = fs::File::create(&tmp)?;
        f.write_all(&out)?;
        f.sync_all()?;
    }
    fs::rename(&tmp, &out_path)?;

    Ok(BackupInfo {
        created_unix_ms: index.created_unix_ms,
        app_version: index.app_version.clone(),
        file_count: index.entries.len() as u32,
        total_bytes: index.entries.iter().map(|e| e.size).sum(),
        settings_json: index.settings_json.clone(),
        digest_ok: true,
    })
}

// ---- 檢視 ----

/// 讀出備份檔的摘要，不還原任何東西。
#[uniffi::export]
pub fn inspect_backup(path: String) -> Result<BackupInfo, BackupError> {
    let bytes = fs::read(&path)?;
    let (index, _payload, digest_ok) = parse(&bytes)?;
    Ok(BackupInfo {
        created_unix_ms: index.created_unix_ms,
        app_version: index.app_version.clone(),
        file_count: index.entries.len() as u32,
        total_bytes: index.entries.iter().map(|e| e.size).sum(),
        settings_json: index.settings_json.clone(),
        digest_ok,
    })
}

// ---- 還原 ----

/// 把備份檔的內容寫回目錄。
///
/// 逐檔驗雜湊：對不上的**不寫入**並列進 `corrupted`。寧可少一個檔，
/// 也不要用壞掉的內容覆蓋掉使用者現有的資料。
#[uniffi::export]
pub fn restore_backup(path: String, dest_dir: String) -> Result<RestoreReport, BackupError> {
    let bytes = fs::read(&path)?;
    let (index, payload, _digest_ok) = parse(&bytes)?;

    let dest = PathBuf::from(&dest_dir);
    fs::create_dir_all(&dest)?;

    let mut report = RestoreReport {
        restored: Vec::new(),
        corrupted: Vec::new(),
        settings_json: index.settings_json.clone(),
    };

    let mut offset = 0usize;
    for entry in &index.entries {
        let end = offset + entry.size as usize;
        if end > payload.len() {
            report.corrupted.push(entry.path.clone());
            break;
        }
        let slice = &payload[offset..end];
        offset = end;

        if hex(&Sha256::digest(slice)) != entry.sha256 {
            report.corrupted.push(entry.path.clone());
            continue;
        }
        // 路徑不可信：備份檔可能來自別處，`../` 會寫到目錄之外。
        let Some(target) = safe_join(&dest, &entry.path) else {
            report.corrupted.push(entry.path.clone());
            continue;
        };
        if let Some(parent) = target.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(&target, slice)?;
        report.restored.push(entry.path.clone());
    }

    Ok(report)
}

// ---- 內部 ----

fn parse(bytes: &[u8]) -> Result<(Index, &[u8], bool), BackupError> {
    if bytes.len() < HEADER_LEN + DIGEST_LEN || &bytes[..8] != MAGIC {
        return Err(BackupError::NotABackup);
    }
    let version = u16::from_le_bytes([bytes[8], bytes[9]]);
    if version > VERSION {
        return Err(BackupError::UnsupportedVersion {
            found: version,
            supported: VERSION,
        });
    }
    let index_len = u32::from_le_bytes([bytes[12], bytes[13], bytes[14], bytes[15]]) as usize;
    let index_end = HEADER_LEN + index_len;
    if index_end + DIGEST_LEN > bytes.len() {
        return Err(BackupError::Corrupt("索引長度超出檔案".into()));
    }

    let index: Index = serde_json::from_slice(&bytes[HEADER_LEN..index_end])
        .map_err(|e| BackupError::Corrupt(format!("索引解析失敗：{e}")))?;

    let body_end = bytes.len() - DIGEST_LEN;
    let payload = &bytes[index_end..body_end];
    let digest_ok = hex(&Sha256::digest(&bytes[..body_end])) == hex(&bytes[body_end..]);

    Ok((index, payload, digest_ok))
}

/// 把相對路徑接到目錄下，拒絕任何會跳出目錄的路徑。
fn safe_join(base: &Path, relative: &str) -> Option<PathBuf> {
    let mut out = base.to_path_buf();
    for part in relative.split('/') {
        if part.is_empty() || part == "." {
            continue;
        }
        if part == ".." || part.contains('\\') {
            return None;
        }
        out.push(part);
    }
    if out == base { None } else { Some(out) }
}

fn walk(dir: &Path) -> Result<Vec<PathBuf>, BackupError> {
    let mut out = Vec::new();
    if !dir.is_dir() {
        return Ok(out);
    }
    let mut stack = vec![dir.to_path_buf()];
    while let Some(current) = stack.pop() {
        for entry in fs::read_dir(&current)? {
            let path = entry?.path();
            if path.is_dir() {
                stack.push(path);
            } else if path.is_file() {
                out.push(path);
            }
        }
    }
    // 固定順序：同一份資料做出來的備份檔要一樣，才比對得出差異。
    out.sort();
    Ok(out)
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tmp(name: &str) -> PathBuf {
        let d = std::env::temp_dir().join(format!("padnote-backup-{name}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&d);
        fs::create_dir_all(&d).unwrap();
        d
    }

    fn seed(dir: &Path) {
        fs::write(dir.join("notebooks_v1.json"), b"[{\"id\":\"a\"}]").unwrap();
        fs::create_dir_all(dir.join("Drawings")).unwrap();
        fs::write(dir.join("Drawings/a_p0.drawing"), b"stroke-bytes").unwrap();
        fs::create_dir_all(dir.join("Recordings")).unwrap();
        fs::write(dir.join("Recordings/r1.opus"), b"audio").unwrap();
    }

    #[test]
    fn a_backup_round_trips_every_file() {
        let root = tmp("roundtrip");
        let source = root.join("Documents");
        fs::create_dir_all(&source).unwrap();
        seed(&source);

        let archive = root.join("backup.kairumobackup");
        let info = create_backup(
            source.to_string_lossy().into(),
            archive.to_string_lossy().into(),
            "2.3.4".into(),
            "{\"lang\":\"zh-Hant\"}".into(),
            1_757_635_200_000,
        )
        .unwrap();
        assert_eq!(info.file_count, 3);

        let dest = root.join("Restored");
        let report = restore_backup(
            archive.to_string_lossy().into(),
            dest.to_string_lossy().into(),
        )
        .unwrap();

        assert_eq!(report.restored.len(), 3);
        assert!(report.corrupted.is_empty());
        assert_eq!(
            fs::read(dest.join("Drawings/a_p0.drawing")).unwrap(),
            b"stroke-bytes"
        );
        assert_eq!(fs::read(dest.join("Recordings/r1.opus")).unwrap(), b"audio");
    }

    #[test]
    fn platform_settings_come_back_untouched() {
        // 設定是平台自己的東西，核心不解讀 —— 但一定要原樣還回去，
        // 不然使用者復原之後語言、筆刷、資料夾名稱全部重來。
        let root = tmp("settings");
        let source = root.join("Documents");
        fs::create_dir_all(&source).unwrap();
        seed(&source);

        let archive = root.join("b.kairumobackup");
        let settings = "{\"kairumo.notebooks.rootFolderName\":\"我的筆記\"}";
        create_backup(
            source.to_string_lossy().into(),
            archive.to_string_lossy().into(),
            "2.3.4".into(),
            settings.into(),
            1,
        )
        .unwrap();

        let info = inspect_backup(archive.to_string_lossy().into()).unwrap();
        assert_eq!(info.settings_json, settings);
    }

    #[test]
    fn inspecting_does_not_restore_anything() {
        // 使用者要能先看看「這是什麼時候的備份、裡面有幾個檔」再決定要不要復原。
        let root = tmp("inspect");
        let source = root.join("Documents");
        fs::create_dir_all(&source).unwrap();
        seed(&source);

        let archive = root.join("b.kairumobackup");
        create_backup(
            source.to_string_lossy().into(),
            archive.to_string_lossy().into(),
            "2.3.4".into(),
            "{}".into(),
            1_757_635_200_000,
        )
        .unwrap();

        let info = inspect_backup(archive.to_string_lossy().into()).unwrap();
        assert_eq!(info.created_unix_ms, 1_757_635_200_000);
        assert_eq!(info.app_version, "2.3.4");
        assert!(info.digest_ok);
        assert!(info.total_bytes > 0);
    }

    #[test]
    fn a_tampered_file_is_reported_and_not_written() {
        // 寧可少一個檔，也不要用壞掉的內容覆蓋掉使用者現有的資料。
        let root = tmp("tamper");
        let source = root.join("Documents");
        fs::create_dir_all(&source).unwrap();
        fs::write(source.join("a.json"), b"AAAAAAAA").unwrap();
        fs::write(source.join("b.json"), b"BBBBBBBB").unwrap();

        let archive = root.join("b.kairumobackup");
        create_backup(
            source.to_string_lossy().into(),
            archive.to_string_lossy().into(),
            "2.3.4".into(),
            "{}".into(),
            1,
        )
        .unwrap();

        // 動一個位元組
        let mut bytes = fs::read(&archive).unwrap();
        let len = bytes.len();
        bytes[len - DIGEST_LEN - 1] ^= 0xFF;
        fs::write(&archive, &bytes).unwrap();

        let dest = root.join("Restored");
        let report = restore_backup(
            archive.to_string_lossy().into(),
            dest.to_string_lossy().into(),
        )
        .unwrap();

        assert_eq!(report.corrupted.len(), 1, "被動過的那個檔要被指出來");
        assert_eq!(report.restored.len(), 1, "其餘的照樣救回來");
    }

    #[test]
    fn a_tampered_archive_fails_the_overall_digest() {
        let root = tmp("digest");
        let source = root.join("Documents");
        fs::create_dir_all(&source).unwrap();
        fs::write(source.join("a.json"), b"AAAA").unwrap();

        let archive = root.join("b.kairumobackup");
        create_backup(
            source.to_string_lossy().into(),
            archive.to_string_lossy().into(),
            "2.3.4".into(),
            "{}".into(),
            1,
        )
        .unwrap();

        let mut bytes = fs::read(&archive).unwrap();
        let len = bytes.len();
        bytes[len - DIGEST_LEN - 1] ^= 0xFF;
        fs::write(&archive, &bytes).unwrap();

        assert!(
            !inspect_backup(archive.to_string_lossy().into())
                .unwrap()
                .digest_ok
        );
    }

    #[test]
    fn a_random_file_is_rejected_instead_of_half_restored() {
        let root = tmp("notbackup");
        let junk = root.join("photo.jpg");
        fs::write(&junk, b"not a backup at all").unwrap();
        assert!(matches!(
            inspect_backup(junk.to_string_lossy().into()),
            Err(BackupError::NotABackup)
        ));
    }

    #[test]
    fn a_newer_format_is_refused_rather_than_guessed() {
        // 猜著解析新版格式的後果是還原出一堆看起來正常、其實錯位的檔案。
        let root = tmp("newer");
        let source = root.join("Documents");
        fs::create_dir_all(&source).unwrap();
        fs::write(source.join("a.json"), b"A").unwrap();
        let archive = root.join("b.kairumobackup");
        create_backup(
            source.to_string_lossy().into(),
            archive.to_string_lossy().into(),
            "2.3.4".into(),
            "{}".into(),
            1,
        )
        .unwrap();

        let mut bytes = fs::read(&archive).unwrap();
        bytes[8] = 99; // 假裝是版本 99
        fs::write(&archive, &bytes).unwrap();

        assert!(matches!(
            inspect_backup(archive.to_string_lossy().into()),
            Err(BackupError::UnsupportedVersion { found: 99, .. })
        ));
    }

    #[test]
    fn paths_cannot_escape_the_destination() {
        // 備份檔可能來自別處。`../` 能寫到目錄之外就是一個可以覆蓋
        // 使用者其他檔案的漏洞。
        assert!(safe_join(Path::new("/tmp/dest"), "../evil").is_none());
        assert!(safe_join(Path::new("/tmp/dest"), "a/../../evil").is_none());
        assert!(safe_join(Path::new("/tmp/dest"), "Drawings/ok.drawing").is_some());
    }

    #[test]
    fn an_empty_source_still_produces_a_valid_backup() {
        // 新使用者第一次按備份就是這個情況，不該當掉。
        let root = tmp("empty");
        let source = root.join("Documents");
        fs::create_dir_all(&source).unwrap();
        let archive = root.join("b.kairumobackup");
        let info = create_backup(
            source.to_string_lossy().into(),
            archive.to_string_lossy().into(),
            "2.3.4".into(),
            "{}".into(),
            1,
        )
        .unwrap();
        assert_eq!(info.file_count, 0);
        assert!(
            inspect_backup(archive.to_string_lossy().into())
                .unwrap()
                .digest_ok
        );
    }

    #[test]
    fn no_partial_file_is_left_behind() {
        // 半成品的備份檔比沒有備份更危險 —— 使用者會以為自己有備份。
        let root = tmp("partial");
        let source = root.join("Documents");
        fs::create_dir_all(&source).unwrap();
        seed(&source);
        let archive = root.join("b.kairumobackup");
        create_backup(
            source.to_string_lossy().into(),
            archive.to_string_lossy().into(),
            "2.3.4".into(),
            "{}".into(),
            1,
        )
        .unwrap();
        assert!(!root.join("b.kairumobackup.partial").exists());
    }
}
