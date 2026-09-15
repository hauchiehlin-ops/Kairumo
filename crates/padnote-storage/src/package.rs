//! `.padnote` 套件的開啟、建立與頁面存取（format-spec §2）。

use crate::blob::BlobStore;
use crate::manifest::Manifest;
use padnote_doc::{DocOp, Uuid};
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
    DocOps(String),
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
            Self::DocOps(m) => write!(f, "文件操作日誌損毀：{m}"),
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
    /// 這台裝置的識別碼，寫入筆畫檔名用。
    ///
    /// 預設 0 是為了讓既有的呼叫端（與測試）不用全部改；真正在用的路徑
    /// 會透過 [`NotebookPackage::with_device`] 設定成裝置實際的 id。
    device: u32,
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
        let pkg = Self {
            root,
            manifest,
            device: 0,
        };
        pkg.write_manifest()?;
        Ok(pkg)
    }

    /// 指定這台裝置的識別碼。**多裝置同步時必須設定** ——
    /// 沒設定的話兩台裝置都會寫進 `…-00000000.strokes`，又回到互相覆蓋。
    #[must_use]
    pub fn with_device(mut self, device: u32) -> Self {
        self.device = device;
        self
    }

    pub fn device(&self) -> u32 {
        self.device
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
        Ok(Self {
            root,
            manifest,
            device: 0,
        })
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

    /// 這台裝置要寫入的筆畫檔。
    ///
    /// # 為什麼檔名裡要有 device
    ///
    /// 架構不變式 1 是「每台裝置只寫自己 `device_id` 的檔案」—— 有了它，
    /// 檔案層級的衝突在數學上不可能發生，同步就只是把檔案湊在一起。
    /// `doc/ops/` 一直都遵守這條，但筆畫檔原本是 `ink/<page>.strokes`，
    /// **每一頁一個檔、與裝置無關**。兩台裝置在同一頁上寫字，就會寫同一個
    /// 檔名 —— 放進共用資料夾同步時，後到的那份會蓋掉先到的，
    /// 使用者的手寫**就這樣不見了**，而且沒有任何錯誤訊息。
    fn ink_write_path(&self, page: Uuid) -> PathBuf {
        self.root
            .join(format!("ink/{page}-{:08x}.strokes", self.device))
    }

    /// 這一頁所有裝置的筆畫檔，含舊版的 `ink/<page>.strokes`。
    ///
    /// 舊檔必須繼續讀得到：使用者手上已經有那種檔案了。
    fn ink_read_paths(&self, page: Uuid) -> Vec<PathBuf> {
        let dir = self.root.join("ink");
        let prefix = format!("{page}");
        let mut paths = Vec::new();

        let legacy = dir.join(format!("{prefix}.strokes"));
        if legacy.exists() {
            paths.push(legacy);
        }

        if let Ok(entries) = fs::read_dir(&dir) {
            for entry in entries.flatten() {
                let name = entry.file_name().to_string_lossy().into_owned();
                if let Some(stem) = name.strip_suffix(".strokes")
                    && let Some(rest) = stem.strip_prefix(&prefix)
                    && rest.starts_with('-')
                {
                    paths.push(entry.path());
                }
            }
        }
        // 固定順序：同一份資料在任何裝置上讀出來的結果必須一樣。
        paths.sort();
        paths
    }

    /// 追加筆畫記錄。**append-only** —— 既有位元組永不被修改（ADR-0002）。
    pub fn append_ink(&self, page: Uuid, records: &[InkRecord]) -> Result<(), StorageError> {
        if records.is_empty() {
            return Ok(());
        }
        let path = self.ink_write_path(page);
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

    /// 這一頁的全部筆畫記錄 —— **所有裝置的檔案串起來**。
    ///
    /// 串接的順序不影響結果：`materialize` 會先收齊墓碑再過濾，
    /// 所以「刪除」出現在「新增」之前也不會出錯。
    pub fn read_ink(&self, page: Uuid) -> Result<Vec<InkRecord>, StorageError> {
        let mut out = Vec::new();
        for path in self.ink_read_paths(page) {
            let bytes = fs::read(&path)?;
            out.extend(StrokeReader::new(&bytes)?.read_all()?);
        }
        Ok(out)
    }

    // ---- 文件操作日誌（format-spec §6.1）----

    /// 追加一批文件操作。
    ///
    /// 檔名為 `<lamport:016x>-<device:08x>.oplog`：Lamport 時戳固定寬度前置
    /// ⇒ **檔名字典序即因果序**，掃描目錄即得套用順序，不需要額外的索引檔
    /// （少一個可能損毀的單點）。裝置 id 在檔名裡 ⇒ 兩台裝置永不寫同一個檔。
    pub fn append_doc_ops(
        &self,
        lamport: u64,
        device: u32,
        ops: &[DocOp],
    ) -> Result<PathBuf, StorageError> {
        let dir = self.root.join("doc/ops");
        fs::create_dir_all(&dir)?;
        let path = dir.join(format!("{lamport:016x}-{device:08x}.oplog"));

        let bytes = padnote_doc::ops::encode(ops);
        use std::io::Write;
        fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(&path)?
            .write_all(&bytes)?;
        Ok(path)
    }

    /// 磁碟上已經用過的最大 lamport（取自檔名）。沒有任何 oplog 時回 0。
    ///
    /// # 為什麼需要它
    ///
    /// 檔名就是因果序：[`read_doc_ops`] 依字典序讀檔，等於依 lamport 讀。
    /// 但開啟既有筆記本時若把計數器歸零，第二次開啟寫出來的第一個操作又會
    /// 叫 `...0001.oplog` —— 它會被 **append 進第一次開啟時建立的那個檔**，
    /// 於是重播時它排在 `...0002` 之前。
    ///
    /// 對「附加」類的操作（新增筆畫、插入文字）看不出問題；但對**整份取代**
    /// 類的操作（`SetNotebookMeta`、`SetBlockAppearance`、`SetBlockPosition`）
    /// 就是災難：新寫的值先被套用，接著被舊檔裡的舊值蓋掉。使用者看到的是
    /// 「改了、也存了，重開卻變回去」，而且沒有任何錯誤訊息。
    pub fn max_doc_lamport(&self) -> u64 {
        let dir = self.root.join("doc/ops");
        let Ok(entries) = fs::read_dir(&dir) else {
            return 0;
        };
        entries
            .filter_map(Result::ok)
            .filter_map(|e| {
                let path = e.path();
                if path.extension().is_some_and(|x| x == "oplog") {
                    let stem = path.file_stem()?.to_str()?;
                    // 檔名格式：{lamport:016x}-{device:08x}
                    u64::from_str_radix(stem.split('-').next()?, 16).ok()
                } else {
                    None
                }
            })
            .max()
            .unwrap_or(0)
    }

    /// 依因果序讀出全部文件操作。
    pub fn read_doc_ops(&self) -> Result<Vec<DocOp>, StorageError> {
        let dir = self.root.join("doc/ops");
        if !dir.exists() {
            return Ok(Vec::new());
        }

        let mut files: Vec<PathBuf> = fs::read_dir(&dir)?
            .filter_map(Result::ok)
            .map(|e| e.path())
            .filter(|p| p.extension().is_some_and(|e| e == "oplog"))
            .collect();
        files.sort(); // 字典序 = 因果序

        let mut out = Vec::new();
        for f in files {
            let bytes = fs::read(&f)?;
            out.extend(
                padnote_doc::ops::decode(&bytes)
                    .map_err(|e| StorageError::DocOps(e.to_string()))?,
            );
        }
        Ok(out)
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
            // 檔名可能是舊版的 `<page>.strokes` 或新版的 `<page>-<device>.strokes`。
            if let Some(stem) = name.strip_suffix(".strokes") {
                let page_part = stem.split_once('-').map_or(stem, |_| {
                    // UUID 本身也含 '-'，所以要從**最後一個** '-' 切
                    stem.rsplit_once('-').map_or(stem, |(head, _)| head)
                });
                if let Some(id) = parse_uuid(page_part) {
                    out.push(id);
                }
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
    fn doc_ops_persist_and_replay_in_causal_order() {
        let root = tmp("docops");
        let pkg = NotebookPackage::create(&root, "t", 1).unwrap();

        // 故意以非遞增的 lamport 寫入，驗證讀取時會依序排好
        pkg.append_doc_ops(
            5,
            0xB2,
            &[DocOp::SetTitle {
                title: "第三".into(),
            }],
        )
        .unwrap();
        pkg.append_doc_ops(
            1,
            0xA1,
            &[DocOp::SetTitle {
                title: "第一".into(),
            }],
        )
        .unwrap();
        pkg.append_doc_ops(
            3,
            0xA1,
            &[DocOp::SetTitle {
                title: "第二".into(),
            }],
        )
        .unwrap();

        let titles: Vec<String> = pkg
            .read_doc_ops()
            .unwrap()
            .into_iter()
            .map(|op| match op {
                DocOp::SetTitle { title } => title,
                _ => unreachable!(),
            })
            .collect();
        assert_eq!(titles, ["第一", "第二", "第三"], "檔名字典序必須等於因果序");
    }

    #[test]
    fn doc_ops_append_within_the_same_file() {
        let root = tmp("docappend");
        let pkg = NotebookPackage::create(&root, "t", 1).unwrap();
        let a = pkg
            .append_doc_ops(
                1,
                0xA1,
                &[DocOp::RemoveBlock {
                    id: Uuid::from_bytes([1; 16]),
                }],
            )
            .unwrap();
        let b = pkg
            .append_doc_ops(
                1,
                0xA1,
                &[DocOp::RemoveBlock {
                    id: Uuid::from_bytes([2; 16]),
                }],
            )
            .unwrap();

        assert_eq!(a, b, "同一 lamport+device 應寫入同一個檔");
        assert_eq!(pkg.read_doc_ops().unwrap().len(), 2, "append 不得覆寫");
    }

    #[test]
    fn two_devices_never_share_an_oplog_file() {
        let root = tmp("docdevices");
        let pkg = NotebookPackage::create(&root, "t", 1).unwrap();
        let a = pkg
            .append_doc_ops(7, 0xA1, &[DocOp::SetTitle { title: "a".into() }])
            .unwrap();
        let b = pkg
            .append_doc_ops(7, 0xB2, &[DocOp::SetTitle { title: "b".into() }])
            .unwrap();
        assert_ne!(a, b, "同 lamport 不同裝置必須是不同檔案");
        assert_eq!(pkg.read_doc_ops().unwrap().len(), 2);
    }

    #[test]
    fn reading_ops_from_fresh_package_is_empty() {
        let root = tmp("docempty");
        let pkg = NotebookPackage::create(&root, "t", 1).unwrap();
        assert!(pkg.read_doc_ops().unwrap().is_empty());
    }

    #[test]
    fn corrupted_oplog_is_reported_not_skipped() {
        // 靜默略過損毀的 oplog 會讓使用者以為只是「某些內容不見了」。
        let root = tmp("doccorrupt");
        let pkg = NotebookPackage::create(&root, "t", 1).unwrap();
        fs::write(
            root.join("doc/ops/0000000000000001-000000a1.oplog"),
            [200u8],
        )
        .unwrap();

        assert!(matches!(pkg.read_doc_ops(), Err(StorageError::DocOps(_))));
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
