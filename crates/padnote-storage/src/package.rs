//! `.padnote` 套件的開啟、建立與頁面存取（format-spec §2）。

use crate::blob::BlobStore;
use crate::manifest::Manifest;
use padnote_doc::Uuid;
use padnote_ink::{InkRecord, StrokeReader, StrokeWriter, codec::CodecError};
use std::fmt;
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug)]
pub enum StorageError {
    NotAPackage(PathBuf),
    /// 檔案要求比本 build 更新的讀取器（format-spec §8）。
    UnsupportedVersion {
        required: u32,
        supported: u32,
    },
    MalformedManifest(String),
    Ink(CodecError),
    Io(std::io::Error),
}

impl fmt::Display for StorageError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::NotAPackage(p) => write!(f, "不是 .padnote 套件：{}", p.display()),
            Self::UnsupportedVersion {
                required,
                supported,
            } => write!(
                f,
                "此筆記本需要版本 {required} 的讀取器，本程式為 {supported}，請升級"
            ),
            Self::MalformedManifest(m) => write!(f, "manifest 解析失敗：{m}"),
            Self::Ink(e) => write!(f, "筆畫檔錯誤：{e}"),
            Self::Io(e) => write!(f, "IO 錯誤：{e}"),
        }
    }
}

impl std::error::Error for StorageError {}

impl From<std::io::Error> for StorageError {
    fn from(e: std::io::Error) -> Self {
        Self::Io(e)
    }
}

impl From<CodecError> for StorageError {
    fn from(e: CodecError) -> Self {
        Self::Ink(e)
    }
}

/// 一份開啟中的筆記本。
#[derive(Debug)]
pub struct NotebookPackage {
    root: PathBuf,
    manifest: Manifest,
}

impl NotebookPackage {
    /// 建立新套件。目錄必須不存在或為空。
    pub fn create(
        root: impl Into<PathBuf>,
        title: &str,
        now_unix_ms: u64,
    ) -> Result<Self, StorageError> {
        let root = root.into();
        fs::create_dir_all(&root)?;
        for sub in ["doc/ops", "ink", "media/audio", "media/blobs", "sync"] {
            fs::create_dir_all(root.join(sub))?;
        }

        let manifest = Manifest::new(Uuid::now_v7().to_string(), title.to_string(), now_unix_ms);
        let pkg = Self { root, manifest };
        pkg.write_manifest()?;
        Ok(pkg)
    }

    pub fn open(root: impl Into<PathBuf>) -> Result<Self, StorageError> {
        let root = root.into();
        let manifest_path = root.join("manifest.json");
        if !manifest_path.exists() {
            return Err(StorageError::NotAPackage(root));
        }

        let text = fs::read_to_string(&manifest_path)?;
        let manifest: Manifest = serde_json::from_str(&text)
            .map_err(|e| StorageError::MalformedManifest(e.to_string()))?;

        // 拒絕而非猜測 —— 靜默解析未知格式會造成資料損毀。
        if !manifest.can_be_opened() {
            return Err(StorageError::UnsupportedVersion {
                required: manifest.min_reader_version,
                supported: crate::manifest::SPEC_VERSION,
            });
        }
        Ok(Self { root, manifest })
    }

    pub fn manifest(&self) -> &Manifest {
        &self.manifest
    }

    pub fn root(&self) -> &Path {
        &self.root
    }

    pub fn blobs(&self) -> BlobStore {
        BlobStore::new(&self.root)
    }

    pub fn set_title(&mut self, title: &str) -> Result<(), StorageError> {
        self.manifest.title = title.to_string();
        self.write_manifest()
    }

    fn write_manifest(&self) -> Result<(), StorageError> {
        let json = serde_json::to_string_pretty(&self.manifest)
            .map_err(|e| StorageError::MalformedManifest(e.to_string()))?;

        // 原子寫入：manifest 損毀會讓整本筆記打不開，不能容忍寫到一半當機。
        let path = self.root.join("manifest.json");
        let tmp = path.with_extension("json.tmp");
        fs::write(&tmp, json)?;
        fs::rename(&tmp, &path)?;
        Ok(())
    }

    // ---- 筆畫 ----

    fn ink_path(&self, page: Uuid) -> PathBuf {
        self.root.join(format!("ink/{page}.strokes"))
    }

    /// 追加筆畫記錄。**append-only** —— 既有位元組永不被修改（ADR-0002）。
    pub fn append_ink(&self, page: Uuid, records: &[InkRecord]) -> Result<(), StorageError> {
        if records.is_empty() {
            return Ok(());
        }
        let path = self.ink_path(page);
        let exists = path.exists();

        let mut writer = StrokeWriter::new(page);
        for r in records {
            writer.push(r);
        }
        let bytes = writer.into_bytes();

        use std::io::Write;
        if exists {
            // 已存在時跳過 32 bytes 檔頭，只接記錄。
            let mut f = fs::OpenOptions::new().append(true).open(&path)?;
            f.write_all(&bytes[padnote_ink::codec::HEADER_LEN..])?;
        } else {
            fs::create_dir_all(path.parent().unwrap())?;
            fs::write(&path, &bytes)?;
        }
        Ok(())
    }

    pub fn read_ink(&self, page: Uuid) -> Result<Vec<InkRecord>, StorageError> {
        let path = self.ink_path(page);
        if !path.exists() {
            return Ok(Vec::new());
        }
        let bytes = fs::read(&path)?;
        Ok(StrokeReader::new(&bytes)?.read_all()?)
    }

    /// 列出所有有筆畫的頁面。
    pub fn ink_pages(&self) -> Result<Vec<Uuid>, StorageError> {
        let dir = self.root.join("ink");
        if !dir.exists() {
            return Ok(Vec::new());
        }
        let mut out = Vec::new();
        for entry in fs::read_dir(&dir)? {
            let name = entry?.file_name().to_string_lossy().into_owned();
            if let Some(stem) = name.strip_suffix(".strokes")
                && let Some(id) = parse_uuid(stem)
            {
                out.push(id);
            }
        }
        out.sort();
        Ok(out)
    }
}

fn parse_uuid(s: &str) -> Option<Uuid> {
    let hex: String = s.chars().filter(|c| *c != '-').collect();
    if hex.len() != 32 {
        return None;
    }
    let mut out = [0u8; 16];
    for (i, c) in hex.as_bytes().chunks(2).enumerate() {
        out[i] = u8::from_str_radix(std::str::from_utf8(c).ok()?, 16).ok()?;
    }
    Some(Uuid::from_bytes(out))
}

#[cfg(test)]
mod tests {
    use super::*;
    use padnote_doc::NotebookTime;
    use padnote_ink::{InkPoint, Stroke, Tool, materialize};

    fn tmp(name: &str) -> PathBuf {
        let d = std::env::temp_dir().join(format!("padnote-pkg-{name}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&d);
        d
    }

    fn stroke(seed: u8) -> Stroke {
        Stroke {
            id: Uuid::from_bytes([seed; 16]),
            started_at: NotebookTime::from_micros(1_000_000 * u64::from(seed)),
            tool: Tool::FountainPen,
            color_rgba8: [0, 0, 0, 255],
            base_width: 2.0,
            points: vec![
                InkPoint::new(0.0, 0.0, 0.5, 0),
                InkPoint::new(10.0, 10.0, 0.7, 8_000),
            ],
        }
    }

    #[test]
    fn create_then_open_roundtrips() {
        let root = tmp("create");
        let pkg = NotebookPackage::create(&root, "線性代數", 1_757_635_200_000).unwrap();
        let id = pkg.manifest().notebook_id.clone();
        drop(pkg);

        let reopened = NotebookPackage::open(&root).unwrap();
        assert_eq!(reopened.manifest().notebook_id, id);
        assert_eq!(reopened.manifest().title, "線性代數");
    }

    #[test]
    fn create_lays_out_spec_directories() {
        let root = tmp("layout");
        NotebookPackage::create(&root, "t", 1).unwrap();
        for sub in ["doc/ops", "ink", "media/audio", "media/blobs", "sync"] {
            assert!(root.join(sub).is_dir(), "缺少 {sub}");
        }
        assert!(root.join("manifest.json").is_file());
    }

    #[test]
    fn opening_non_package_is_clear_error() {
        let root = tmp("notpkg");
        fs::create_dir_all(&root).unwrap();
        assert!(matches!(
            NotebookPackage::open(&root),
            Err(StorageError::NotAPackage(_))
        ));
    }

    #[test]
    fn refuses_package_requiring_newer_reader() {
        let root = tmp("newer");
        NotebookPackage::create(&root, "t", 1).unwrap();

        let path = root.join("manifest.json");
        let mut m: Manifest = serde_json::from_str(&fs::read_to_string(&path).unwrap()).unwrap();
        m.min_reader_version = 99;
        fs::write(&path, serde_json::to_string(&m).unwrap()).unwrap();

        assert!(matches!(
            NotebookPackage::open(&root),
            Err(StorageError::UnsupportedVersion { required: 99, .. })
        ));
    }

    #[test]
    fn ink_appends_across_separate_calls() {
        let root = tmp("ink-append");
        let pkg = NotebookPackage::create(&root, "t", 1).unwrap();
        let page = Uuid::from_bytes([0xAB; 16]);

        // 分三次寫入，模擬使用者陸續書寫
        pkg.append_ink(page, &[InkRecord::Add(stroke(1))]).unwrap();
        pkg.append_ink(page, &[InkRecord::Add(stroke(2))]).unwrap();
        pkg.append_ink(page, &[InkRecord::Remove(stroke(1).id)])
            .unwrap();

        let records = pkg.read_ink(page).unwrap();
        assert_eq!(records.len(), 3, "append 不得覆寫既有記錄");

        let visible = materialize(&records);
        assert_eq!(visible.len(), 1);
        assert_eq!(visible[0].id, stroke(2).id);
    }

    #[test]
    fn reading_page_without_ink_is_empty_not_error() {
        let root = tmp("ink-empty");
        let pkg = NotebookPackage::create(&root, "t", 1).unwrap();
        assert!(pkg.read_ink(Uuid::now_v7()).unwrap().is_empty());
    }

    #[test]
    fn lists_pages_that_have_ink() {
        let root = tmp("ink-list");
        let pkg = NotebookPackage::create(&root, "t", 1).unwrap();
        let p1 = Uuid::from_bytes([1; 16]);
        let p2 = Uuid::from_bytes([2; 16]);
        pkg.append_ink(p1, &[InkRecord::Add(stroke(1))]).unwrap();
        pkg.append_ink(p2, &[InkRecord::Add(stroke(2))]).unwrap();

        let pages = pkg.ink_pages().unwrap();
        assert_eq!(pages, vec![p1, p2]);
    }

    #[test]
    fn blobs_are_shared_through_the_package() {
        let root = tmp("blobs");
        let pkg = NotebookPackage::create(&root, "t", 1).unwrap();
        let id = pkg.blobs().put(b"image bytes").unwrap();
        assert_eq!(pkg.blobs().get(id).unwrap(), b"image bytes");
    }

    #[test]
    fn title_change_survives_reopen() {
        let root = tmp("title");
        let mut pkg = NotebookPackage::create(&root, "舊標題", 1).unwrap();
        pkg.set_title("新標題").unwrap();
        drop(pkg);
        assert_eq!(
            NotebookPackage::open(&root).unwrap().manifest().title,
            "新標題"
        );
    }
}
