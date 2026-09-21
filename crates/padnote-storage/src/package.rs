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
    Archive(String),
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
            Self::Archive(m) => write!(f, "封裝壓縮錯誤：{m}"),
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

/// 只壓實自己那幾個檔的結果，帶明確的涵蓋名單。
#[derive(Clone, Debug)]
pub struct CompactOutcome {
    /// 壓實後的檔名。
    pub compacted_name: String,
    /// 被它吃掉、已經從本機刪除的碎檔名單。**雲端要刪的就是這幾個，
    /// 不要自己推論。**
    pub absorbed: Vec<String>,
}

/// Oplog 壓實的結果。
#[derive(Clone, Debug)]
pub struct CompactResult {
    /// 被合併並刪除的舊碎檔數（0 表示未達門檻，未執行壓實）。
    pub merged_files: usize,
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

    /// 列出錄音檔：`(檔名, 位元組數)`。
    ///
    /// 錄音檔是 `media/audio/<uuid>.opus` —— uuid 命名所以唯一，
    /// 但**錄製中會變長**，所以同步時要比長度而不是只看存在與否。
    pub fn audio_files(&self) -> Result<Vec<(String, u64)>, StorageError> {
        let dir = self.root.join("media/audio");
        if !dir.exists() {
            return Ok(Vec::new());
        }
        let mut out: Vec<(String, u64)> = fs::read_dir(&dir)?
            .filter_map(Result::ok)
            .filter(|e| e.path().extension().is_some_and(|x| x == "opus"))
            .filter_map(|e| {
                let name = e.file_name().to_str()?.to_string();
                if crate::atomic::is_temp_name(&name) {
                    return None;
                }
                Some((name, e.metadata().ok()?.len()))
            })
            .collect();
        out.sort();
        Ok(out)
    }

    pub fn read_audio_file(&self, name: &str) -> Result<Vec<u8>, StorageError> {
        Ok(fs::read(self.audio_path(name)?)?)
    }

    pub fn write_audio_file(&self, name: &str, bytes: &[u8]) -> Result<(), StorageError> {
        let path = self.audio_path(name)?;
        // 原子寫入：寫到一半的錄音在對面看起來是一個「比較短但合法」的檔案，
        // 而同步的規則正是「較長的是超集」—— 它會被當成舊版本，不是壞檔。
        crate::atomic::write_atomic(&path, bytes)?;
        Ok(())
    }

    /// 檔名從雲端來，當成不可信輸入（理由同 [`Self::doc_op_path`]）。
    fn audio_path(&self, name: &str) -> Result<PathBuf, StorageError> {
        let looks_safe = !name.is_empty()
            && name.ends_with(".opus")
            && !name.contains('/')
            && !name.contains('\\')
            && !name.contains("..");
        if !looks_safe {
            return Err(StorageError::DocOps(format!("不合法的錄音檔名：{name}")));
        }
        Ok(self.root.join("media/audio").join(name))
    }

    /// 列出 oplog 檔案：`(檔名, 位元組數)`，依因果序（＝檔名字典序）。
    ///
    /// 同步用得到：oplog 檔是**同步的自然單位** —— 檔名編碼了
    /// `(lamport, device)`，所以天生唯一、不可變、而且字典序就是套用順序。
    /// 不需要另外設計 chunk 格式，也不會有「兩台裝置寫同一個檔」的問題。
    pub fn doc_op_files(&self) -> Result<Vec<(String, u64)>, StorageError> {
        let dir = self.root.join("doc/ops");
        if !dir.exists() {
            return Ok(Vec::new());
        }
        let mut out: Vec<(String, u64)> = fs::read_dir(&dir)?
            .filter_map(Result::ok)
            .filter(|e| e.path().extension().is_some_and(|x| x == "oplog"))
            .filter_map(|e| {
                let name = e.file_name().to_str()?.to_string();
                // 原子寫入的臨時檔不是同步單位 —— 算進去的話，對面會下載到
                // 一個永遠不會完成的檔案。
                if crate::atomic::is_temp_name(&name) {
                    return None;
                }
                let size = e.metadata().ok()?.len();
                Some((name, size))
            })
            .collect();
        out.sort();
        Ok(out)
    }

    /// 壓實本機 oplog 碎檔。
    ///
    /// 當**這台裝置**的碎檔數 `>= threshold` 時，把所有屬於此裝置的碎檔
    /// 合併成一個大檔（使用最大 lamport 為新檔名），再刪除舊碎檔。
    ///
    /// # 設計原則
    /// - **依裝置後綴分組壓實碎檔**（支援所有裝置，包括 open 後 device 為 0 的情況）
    /// - **原子性**：先寫臨時檔，成功後原子 rename，刪除舊檔
    /// - **直接拼接原始位元組**（不 decode/re-encode），因為 oplog frame 是自洽的
    /// - 壓實後的檔名：`<max_lamport:016x>-<device:08x>.oplog`
    pub fn compact_doc_ops(&self, threshold: usize) -> Result<CompactResult, StorageError> {
        let dir = self.root.join("doc/ops");
        if !dir.exists() {
            return Ok(CompactResult { merged_files: 0 });
        }

        // 收集所有 .oplog 碎檔，依裝置後綴（例如 "-00000001.oplog"）分組
        let mut files_by_device: std::collections::BTreeMap<String, Vec<PathBuf>> =
            std::collections::BTreeMap::new();

        if let Ok(entries) = fs::read_dir(&dir) {
            for entry in entries.filter_map(Result::ok) {
                let path = entry.path();
                let file_name = match path.file_name().and_then(|n| n.to_str()) {
                    Some(name) if name.ends_with(".oplog") => name,
                    _ => continue,
                };
                if let Some(pos) = file_name.rfind('-') {
                    let suffix = &file_name[pos..];
                    files_by_device
                        .entry(suffix.to_string())
                        .or_default()
                        .push(path);
                }
            }
        }

        let mut total_merged = 0;
        for (device_suffix, mut own_files) in files_by_device {
            if own_files.len() < threshold {
                continue;
            }
            own_files.sort(); // 字典序 = 因果序

            let max_lamport_hex = own_files
                .last()
                .and_then(|p| p.file_stem())
                .and_then(|s| s.to_str())
                .and_then(|s| s.split('-').next())
                .unwrap_or("0000000000000000");

            let compacted_name = format!("{max_lamport_hex}{device_suffix}");
            let compacted_path = dir.join(&compacted_name);

            let mut merged = Vec::new();
            for f in &own_files {
                let bytes = fs::read(f)?;
                merged.extend_from_slice(&bytes);
            }

            crate::atomic::write_atomic(&compacted_path, &merged)?;

            for f in &own_files {
                if f != &compacted_path {
                    let _ = fs::remove_file(f);
                }
            }
            total_merged += own_files.len();
        }

        Ok(CompactResult {
            merged_files: total_merged,
        })
    }

    /// 只壓實**這台裝置自己**的 oplog 碎檔，並明確回報它吃掉了哪幾個。
    ///
    /// # 為什麼要有「只壓實自己的」這個版本
    ///
    /// 壓實之後，雲端上那些已經被涵蓋的舊碎檔就該刪掉，否則雲端會無限累積，
    /// 新裝置第一次同步要下載幾百個檔案。問題是**怎麼確定某個雲端碎檔真的
    /// 被涵蓋了**。
    ///
    /// 舊的做法是推論：「它的 lamport 小於本機該裝置的最大 lamport，
    /// 所以一定已經在壓實檔裡」。那個推論會錯 —— 本機可能根本沒下載過那個
    /// 碎檔（例如只拿到 0005 和 0010，中間的 0007 還在路上），於是刪掉的是
    /// 一份**本機從來沒有過**的操作。刪完就再也回不來了。
    ///
    /// 正確的規則只有一條：**只有寫那個檔的裝置，才知道自己壓實了哪幾個**。
    /// 所以這個函式回傳明確的名單，呼叫端照名單刪，不做任何推論。
    /// 這同時維持了架構不變式 1（每台裝置只寫／只刪自己 `device_id` 的檔案）。
    pub fn compact_own_doc_ops(
        &self,
        threshold: usize,
        device: u32,
    ) -> Result<Option<CompactOutcome>, StorageError> {
        let dir = self.root.join("doc/ops");
        if !dir.exists() {
            return Ok(None);
        }
        let suffix = format!("-{device:08x}.oplog");
        let mut own: Vec<String> = fs::read_dir(&dir)?
            .filter_map(Result::ok)
            .filter_map(|e| e.file_name().to_str().map(str::to_string))
            .filter(|name| name.ends_with(&suffix) && !crate::atomic::is_temp_name(name))
            .collect();
        if own.len() < threshold {
            return Ok(None);
        }
        own.sort(); // 字典序 = 因果序

        let max_lamport_hex = own
            .last()
            .and_then(|n| n.split('-').next())
            .unwrap_or("0000000000000000")
            .to_string();
        let compacted_name = format!("{max_lamport_hex}-{device:08x}.oplog");

        let mut merged = Vec::new();
        for name in &own {
            merged.extend_from_slice(&fs::read(dir.join(name))?);
        }
        crate::atomic::write_atomic(&dir.join(&compacted_name), &merged)?;

        let mut absorbed = Vec::new();
        for name in &own {
            if name == &compacted_name {
                continue;
            }
            let _ = fs::remove_file(dir.join(name));
            absorbed.push(name.clone());
        }
        Ok(Some(CompactOutcome {
            compacted_name,
            absorbed,
        }))
    }

    /// 讀一個 oplog 檔的原始位元組。
    pub fn read_doc_op_file(&self, name: &str) -> Result<Vec<u8>, StorageError> {
        let path = self.doc_op_path(name)?;
        Ok(fs::read(path)?)
    }

    /// 寫入一個從別台裝置同步下來的 oplog 檔。
    ///
    /// **整檔覆寫，不是 append。** 這些檔案在來源端是不可變的（同一個檔名
    /// 永遠是同一份內容，只可能變長），所以覆寫是安全且冪等的；
    /// append 反而會在重複同步時把內容寫兩次。
    pub fn write_doc_op_file(&self, name: &str, bytes: &[u8]) -> Result<(), StorageError> {
        let path = self.doc_op_path(name)?;
        // 原子寫入，理由見 `crate::atomic`：半個 oplog 檔是一個**合法的**
        // append-only 前綴，對面不會察覺有問題，只會把它當成比較舊的版本。
        crate::atomic::write_atomic(&path, bytes)?;
        Ok(())
    }

    /// 檢查並組出 oplog 檔的路徑。
    ///
    /// **檔名是從雲端來的，要當成不可信輸入。** 不擋的話，一個叫
    /// `../../../../etc/passwd` 的檔名會讓同步寫到套件外面去。
    fn doc_op_path(&self, name: &str) -> Result<PathBuf, StorageError> {
        let looks_safe = !name.is_empty()
            && name.ends_with(".oplog")
            && !name.contains('/')
            && !name.contains('\\')
            && !name.contains("..");
        if !looks_safe {
            return Err(StorageError::DocOps(format!("不合法的 oplog 檔名：{name}")));
        }
        Ok(self.root.join("doc/ops").join(name))
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

/// 把一個 `.padnote` 套件目錄壓縮打包成單一檔案（format-spec §2、工作項 S-94）。
///
/// 格式為標準 ZIP 容器：包含 `manifest.json`、`doc/`、`ink/`、`media/` 等。
/// 本機衍生的 `index/` 目錄不打包（可安全重建）。
pub fn archive_package(package_dir: &Path, out_file: &Path) -> Result<(), StorageError> {
    if !package_dir.is_dir() {
        return Err(StorageError::NotAPackage(package_dir.to_path_buf()));
    }
    if !package_dir.join("manifest.json").is_file() {
        return Err(StorageError::NotAPackage(package_dir.to_path_buf()));
    }

    if let Some(parent) = out_file.parent() {
        fs::create_dir_all(parent)?;
    }

    let tmp_out = out_file.with_extension("tmp_zip");
    {
        let file = fs::File::create(&tmp_out)?;
        let mut zip = zip::ZipWriter::new(file);
        let options = zip::write::SimpleFileOptions::default()
            .compression_method(zip::CompressionMethod::Deflated);

        fn add_dir_to_zip<W: std::io::Write + std::io::Seek>(
            zip: &mut zip::ZipWriter<W>,
            options: zip::write::SimpleFileOptions,
            root: &Path,
            dir: &Path,
        ) -> Result<(), StorageError> {
            for entry in fs::read_dir(dir)? {
                let entry = entry?;
                let path = entry.path();
                let file_name = entry.file_name();
                let name_str = file_name.to_string_lossy();

                if name_str.starts_with('.') || (dir == root && name_str == "index") {
                    continue;
                }

                let rel_path = path
                    .strip_prefix(root)
                    .map_err(|e| StorageError::Archive(e.to_string()))?;
                let rel_str = rel_path.to_string_lossy().replace('\\', "/");

                if path.is_dir() {
                    zip.add_directory(&rel_str, options)
                        .map_err(|e| StorageError::Archive(e.to_string()))?;
                    add_dir_to_zip(zip, options, root, &path)?;
                } else if path.is_file() {
                    zip.start_file(&rel_str, options)
                        .map_err(|e| StorageError::Archive(e.to_string()))?;
                    let mut f = fs::File::open(&path)?;
                    std::io::copy(&mut f, zip)?;
                }
            }
            Ok(())
        }

        add_dir_to_zip(&mut zip, options, package_dir, package_dir)?;
        zip.finish()
            .map_err(|e| StorageError::Archive(e.to_string()))?;
    }

    fs::rename(&tmp_out, out_file)?;
    Ok(())
}

/// 將單一打包檔案解壓縮還原為 `.padnote` 目錄套件。
pub fn extract_package(archive_file: &Path, out_dir: &Path) -> Result<(), StorageError> {
    let file = fs::File::open(archive_file)?;
    let mut archive =
        zip::ZipArchive::new(file).map_err(|e| StorageError::Archive(e.to_string()))?;

    fs::create_dir_all(out_dir)?;

    for i in 0..archive.len() {
        let mut file = archive
            .by_index(i)
            .map_err(|e| StorageError::Archive(e.to_string()))?;
        let enclosed_name = file
            .enclosed_name()
            .ok_or_else(|| StorageError::Archive("路徑包含非法穿越".into()))?
            .to_path_buf();
        let out_path = out_dir.join(enclosed_name);

        if file.is_dir() {
            fs::create_dir_all(&out_path)?;
        } else {
            if let Some(parent) = out_path.parent() {
                fs::create_dir_all(parent)?;
            }
            let mut out_file = fs::File::create(&out_path)?;
            std::io::copy(&mut file, &mut out_file)?;
        }
    }

    if !out_dir.join("manifest.json").is_file() {
        return Err(StorageError::NotAPackage(out_dir.to_path_buf()));
    }

    Ok(())
}

#[cfg(test)]
mod tests {

    #[test]
    fn oplog_files_are_listed_in_causal_order() {
        let root = tmp("oplog-order");
        let pkg = NotebookPackage::create(&root, "t", 1).unwrap();
        pkg.append_doc_ops(
            2,
            0xAA,
            &[DocOp::SetTitle {
                title: "二".into()
            }],
        )
        .unwrap();
        pkg.append_doc_ops(
            1,
            0xBB,
            &[DocOp::SetTitle {
                title: "一".into()
            }],
        )
        .unwrap();

        let files: Vec<String> = pkg
            .doc_op_files()
            .unwrap()
            .into_iter()
            .map(|(n, _)| n)
            .collect();
        // 檔名字典序即因果序 —— lamport 1 要排在 2 前面，與寫入順序無關。
        assert_eq!(files.len(), 2);
        assert!(files[0].starts_with("0000000000000001"), "{files:?}");
        assert!(files[1].starts_with("0000000000000002"), "{files:?}");
    }

    #[test]
    fn an_oplog_file_survives_a_round_trip() {
        let source_root = tmp("oplog-src");
        let source = NotebookPackage::create(&source_root, "t", 1).unwrap();
        source
            .append_doc_ops(
                1,
                0xAA,
                &[DocOp::SetTitle {
                    title: "來源".into(),
                }],
            )
            .unwrap();
        let (name, _) = source.doc_op_files().unwrap().remove(0);
        let bytes = source.read_doc_op_file(&name).unwrap();

        // 模擬同步到另一台裝置。
        let target_root = tmp("oplog-dst");
        let target = NotebookPackage::create(&target_root, "t", 2).unwrap();
        target.write_doc_op_file(&name, &bytes).unwrap();
        let ops = target.read_doc_ops().unwrap();
        assert!(matches!(&ops[..], [DocOp::SetTitle { title }] if title == "來源"));
    }

    #[test]
    fn writing_the_same_file_twice_does_not_duplicate_its_contents() {
        // 同步可能重複送同一個檔。用 append 的話內容會寫兩次，
        // 重播之後每個操作都套用兩遍。
        let source_root = tmp("oplog-dup-src");
        let source = NotebookPackage::create(&source_root, "t", 1).unwrap();
        source
            .append_doc_ops(
                1,
                0xAA,
                &[DocOp::SetTitle {
                    title: "一次".into(),
                }],
            )
            .unwrap();
        let (name, _) = source.doc_op_files().unwrap().remove(0);
        let bytes = source.read_doc_op_file(&name).unwrap();

        let target_root = tmp("oplog-dup-dst");
        let target = NotebookPackage::create(&target_root, "t", 2).unwrap();
        target.write_doc_op_file(&name, &bytes).unwrap();
        target.write_doc_op_file(&name, &bytes).unwrap();
        assert_eq!(target.read_doc_ops().unwrap().len(), 1);
    }

    #[test]
    fn a_malicious_filename_cannot_escape_the_package() {
        // 檔名是從雲端來的，要當成不可信輸入。不擋的話，一個叫
        // `../../..` 的檔名會讓同步寫到套件外面去。
        let root = tmp("oplog-evil");
        let pkg = NotebookPackage::create(&root, "t", 1).unwrap();
        for bad in [
            "../../../../tmp/evil.oplog",
            "doc/ops/nested.oplog",
            "..oplog",
            "plain.txt",
            "",
        ] {
            assert!(
                pkg.write_doc_op_file(bad, b"x").is_err(),
                "{bad} 應該被擋下"
            );
        }
    }

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

    #[test]
    fn package_archive_and_extract_roundtrips() {
        let root = tmp("archive-src");
        let pkg = NotebookPackage::create(&root, "封裝筆記", 1).unwrap();
        let page = Uuid::from_bytes([0x12; 16]);
        pkg.append_ink(page, &[InkRecord::Add(stroke(1))]).unwrap();
        drop(pkg);

        let zip_file = root.parent().unwrap().join("test_note.padnote");
        archive_package(&root, &zip_file).unwrap();
        assert!(zip_file.is_file());

        let extract_dir = tmp("archive-dst");
        extract_package(&zip_file, &extract_dir).unwrap();

        let reopened = NotebookPackage::open(&extract_dir).unwrap();
        assert_eq!(reopened.manifest().title, "封裝筆記");
        assert_eq!(reopened.read_ink(page).unwrap().len(), 1);

        let _ = fs::remove_file(zip_file);
    }

    #[test]
    fn compacting_only_touches_this_devices_own_fragments() {
        // 壓實別台裝置的碎檔，等於代替它決定「這些可以刪了」——
        // 而本機可能根本沒拿到它全部的碎檔。
        use padnote_doc::ops::DocOp;
        let root = tmp("compact-own");
        let pkg = NotebookPackage::create(&root, "t", 1).unwrap();
        for lamport in 1..=6u64 {
            pkg.append_doc_ops(lamport, 0xAA, &[DocOp::SetTitle { title: "a".into() }])
                .unwrap();
        }
        for lamport in 10..=13u64 {
            pkg.append_doc_ops(lamport, 0xBB, &[DocOp::SetTitle { title: "b".into() }])
                .unwrap();
        }

        let outcome = pkg.compact_own_doc_ops(5, 0xAA).unwrap().unwrap();
        assert_eq!(outcome.compacted_name, "0000000000000006-000000aa.oplog");
        assert_eq!(outcome.absorbed.len(), 5, "自己的五個碎檔該被吃掉");

        let names: Vec<String> = pkg
            .doc_op_files()
            .unwrap()
            .into_iter()
            .map(|(n, _)| n)
            .collect();
        // 別台裝置的四個檔一個都不能少。
        assert_eq!(names.iter().filter(|n| n.ends_with("-000000bb.oplog")).count(), 4);
        assert_eq!(names.iter().filter(|n| n.ends_with("-000000aa.oplog")).count(), 1);
    }

    #[test]
    fn compaction_below_the_threshold_does_nothing() {
        use padnote_doc::ops::DocOp;
        let root = tmp("compact-below");
        let pkg = NotebookPackage::create(&root, "t", 1).unwrap();
        for lamport in 1..=3u64 {
            pkg.append_doc_ops(lamport, 0xAA, &[DocOp::SetTitle { title: "a".into() }])
                .unwrap();
        }
        assert!(pkg.compact_own_doc_ops(5, 0xAA).unwrap().is_none());
        assert_eq!(pkg.doc_op_files().unwrap().len(), 3);
    }

    #[test]
    fn compaction_keeps_every_operation() {
        // 壓實是位元組拼接。掉一個 frame 的症狀是「同步之後少了幾筆」。
        use padnote_doc::ops::DocOp;
        let root = tmp("compact-keeps");
        let pkg = NotebookPackage::create(&root, "t", 1).unwrap();
        for lamport in 1..=6u64 {
            pkg.append_doc_ops(
                lamport,
                0xAA,
                &[DocOp::SetTitle {
                    title: format!("t{lamport}"),
                }],
            )
            .unwrap();
        }
        let before = pkg.read_doc_ops().unwrap().len();
        pkg.compact_own_doc_ops(5, 0xAA).unwrap().unwrap();
        assert_eq!(pkg.read_doc_ops().unwrap().len(), before);
    }

    #[test]
    fn compact_doc_ops_groups_by_device_and_works_when_opened_with_device_zero() {
        let root = tmp("compact-device-zero");
        let pkg = NotebookPackage::create(&root, "壓實測試", 1).unwrap();
        // 寫入 6 個 device 0x42 的 oplog 檔
        for i in 1..=6 {
            pkg.append_doc_ops(
                i,
                0x42,
                &[padnote_doc::DocOp::SetTitle {
                    title: format!("t{i}"),
                }],
            )
            .unwrap();
        }
        drop(pkg);

        // 使用 NotebookPackage::open 打開（此時 self.device 為 0）
        let reopened = NotebookPackage::open(&root).unwrap();
        assert_eq!(reopened.device(), 0);
        let res = reopened.compact_doc_ops(5).unwrap();
        assert_eq!(res.merged_files, 6);

        // 檢查壓實後只剩 1 個 oplog 檔
        let files = reopened.doc_op_files().unwrap();
        assert_eq!(files.len(), 1);
        assert_eq!(files[0].0, "0000000000000006-00000042.oplog");
    }
}
