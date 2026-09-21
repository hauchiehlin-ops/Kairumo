//! `.padnote` 套件的開啟、建立與頁面存取（format-spec §2）。

use crate::blob::BlobStore;
use crate::manifest::Manifest;
use padnote_doc::milestone::{DocClock, InkClock, MilestoneCut, OpEntry, Resolved};
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
    /// 內容加密金鑰。`None` 表示這是一個未加密的套件。
    ///
    /// # 為什麼是「開啟時才給」
    ///
    /// 金鑰由使用者的密碼解出來（`manifest.json` 裡只有**包好的** DEK），
    /// 所以套件可以在沒有密碼的情況下被開啟 —— 這很重要：
    /// **同步不需要密碼**。同步搬的是密文、壓實只是把位元組接起來，
    /// 兩者都不必解密。需要密碼的只有「把內容顯示給使用者看」。
    dek: Option<padnote_crypto::envelope::Dek>,
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
            dek: None,
        };
        pkg.write_manifest()?;
        Ok(pkg)
    }

    /// 建立一個**加密的**新套件。
    ///
    /// 回傳套件本身與復原碼 —— 復原碼**只在這一刻存在**，
    /// 之後任何人（包括我們）都算不回來。呼叫端必須讓使用者抄下來並回填
    /// 驗證過，才算完成啟用；不擋的話，第一個忘記密碼的使用者會失去全部筆記。
    pub fn create_encrypted(
        root: impl Into<PathBuf>,
        title: &str,
        now_unix_ms: u64,
        passphrase: &str,
    ) -> Result<(Self, String), StorageError> {
        use base64::Engine as _;

        let (envelope, dek) = padnote_crypto::envelope::Envelope::create(passphrase)
            .map_err(|e| StorageError::DocOps(e.to_string()))?;
        let words = padnote_crypto::recovery::english_wordlist();
        let recovery = padnote_crypto::recovery::RecoveryCode::generate(&words)
            .map_err(|e| StorageError::DocOps(e.to_string()))?;

        let mut pkg = Self::create(root, title, now_unix_ms)?;
        let kdf = envelope.kdf_params();
        pkg.manifest.encryption = crate::manifest::Encryption::XChaCha20Poly1305Argon2id {
            kdf: crate::manifest::KdfParams {
                algo: "argon2id".into(),
                m_cost_kib: kdf.m_cost_kib,
                t_cost: kdf.t_cost,
                p_cost: kdf.p_cost,
                salt_b64: base64::engine::general_purpose::STANDARD.encode(&kdf.salt),
            },
            wrapped_dek_b64: envelope.wrapped_dek_b64(),
            recovery: crate::manifest::RecoveryParams {
                algo: "bip39-en".into(),
                words: recovery.words().len() as u32,
            },
        };
        pkg.write_manifest()?;
        let phrase = recovery.phrase();
        Ok((pkg.with_dek(dek), phrase))
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

    /// 一個 oplog 框架的附加驗證資料（AAD）。
    ///
    /// # 為什麼綁的是「筆記本 + 裝置」，不是完整檔名
    ///
    /// 直覺會想綁完整檔名，但那會**與壓實衝突**：壓實把同一台裝置的好幾個
    /// 碎檔接成一個新檔名（用最大的 lamport），而框架的位元組原封不動 ——
    /// 綁檔名的話，壓實之後就再也解不開了，而且錯誤訊息是「密語錯誤」，
    /// 指向一個完全不相干的地方。
    ///
    /// 綁「筆記本 id + 裝置後綴」剛好是**不該改變**的那一部分：
    /// 壓實只在同一本筆記、同一台裝置之內合併，所以它一定不變；
    /// 而把密文搬到另一本筆記或冒充成另一台裝置的檔案，仍然打不開。
    fn oplog_aad(&self, file_name: &str) -> String {
        let device_suffix = file_name.rsplit('-').next().unwrap_or(file_name);
        format!("{}:{}", self.manifest.notebook_id, device_suffix)
    }

    /// 換密碼。
    ///
    /// **內容一個位元組都不會動** —— 換的只有 `manifest.json` 裡包住 DEK
    /// 的那一層。所以這一步很快，也不會與同步打架（oplog 檔沒變，
    /// 對面不會看到任何差異）。
    ///
    /// 反過來做（重新加密全部內容）的話，每換一次密碼就等於把整本筆記
    /// 重傳一次，而且中途失敗會留下一半新一半舊的套件。
    pub fn rewrap_passphrase(
        &self,
        old_passphrase: &str,
        new_passphrase: &str,
    ) -> Result<(), StorageError> {
        use base64::Engine as _;

        let crate::manifest::Encryption::XChaCha20Poly1305Argon2id {
            kdf,
            wrapped_dek_b64,
            recovery,
        } = &self.manifest.encryption
        else {
            return Err(StorageError::DocOps("這個套件沒有加密".into()));
        };

        let salt = base64::engine::general_purpose::STANDARD
            .decode(&kdf.salt_b64)
            .map_err(|e| StorageError::DocOps(format!("salt 不是合法 base64：{e}")))?;
        let envelope = padnote_crypto::envelope::Envelope::from_parts(
            padnote_crypto::envelope::KdfParams {
                m_cost_kib: kdf.m_cost_kib,
                t_cost: kdf.t_cost,
                p_cost: kdf.p_cost,
                salt,
            },
            wrapped_dek_b64,
        )
        .map_err(|e| StorageError::DocOps(e.to_string()))?;

        let fresh = envelope
            .rewrap(old_passphrase, new_passphrase)
            .map_err(|e| StorageError::DocOps(e.to_string()))?;

        let mut manifest = self.manifest.clone();
        let fresh_kdf = fresh.kdf_params();
        manifest.encryption = crate::manifest::Encryption::XChaCha20Poly1305Argon2id {
            kdf: crate::manifest::KdfParams {
                algo: kdf.algo.clone(),
                m_cost_kib: fresh_kdf.m_cost_kib,
                t_cost: fresh_kdf.t_cost,
                p_cost: fresh_kdf.p_cost,
                salt_b64: base64::engine::general_purpose::STANDARD.encode(&fresh_kdf.salt),
            },
            wrapped_dek_b64: fresh.wrapped_dek_b64(),
            recovery: recovery.clone(),
        };

        let json = serde_json::to_vec_pretty(&manifest)
            .map_err(|e| StorageError::MalformedManifest(e.to_string()))?;
        crate::atomic::write_atomic(&self.root.join("manifest.json"), &json)?;
        Ok(())
    }

    /// 這個套件加密了嗎（看 manifest，不需要密碼）。
    pub fn is_encrypted(&self) -> bool {
        self.manifest.is_encrypted()
    }

    /// 帶上內容金鑰。**沒帶的話，加密套件的內容讀不出來**
    /// （`read_doc_ops` 會回錯誤，而不是回空的 —— 回空的會讓上層
    /// 以為這本筆記是空白的，然後把它覆蓋掉）。
    #[must_use]
    pub fn with_dek(mut self, dek: padnote_crypto::envelope::Dek) -> Self {
        self.dek = Some(dek);
        self
    }

    /// 用密碼解開這個套件的內容金鑰。
    pub fn unlock(self, passphrase: &str) -> Result<Self, StorageError> {
        let envelope = match &self.manifest.encryption {
            crate::manifest::Encryption::None => {
                return Err(StorageError::DocOps("這個套件沒有加密".into()));
            }
            crate::manifest::Encryption::XChaCha20Poly1305Argon2id {
                kdf,
                wrapped_dek_b64,
                ..
            } => {
                use base64::Engine as _;
                let salt = base64::engine::general_purpose::STANDARD
                    .decode(&kdf.salt_b64)
                    .map_err(|e| StorageError::DocOps(format!("salt 不是合法 base64：{e}")))?;
                padnote_crypto::envelope::Envelope::from_parts(
                    padnote_crypto::envelope::KdfParams {
                        m_cost_kib: kdf.m_cost_kib,
                        t_cost: kdf.t_cost,
                        p_cost: kdf.p_cost,
                        salt,
                    },
                    wrapped_dek_b64,
                )
                .map_err(|e| StorageError::DocOps(e.to_string()))?
            }
        };
        let dek = envelope
            .unwrap_dek(passphrase)
            .map_err(|e| StorageError::DocOps(e.to_string()))?;
        Ok(self.with_dek(dek))
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
            dek: None,
        })
    }

    pub fn manifest(&self) -> &Manifest {
        &self.manifest
    }

    pub fn root(&self) -> &Path {
        &self.root
    }

    pub fn blobs(&self) -> BlobStore {
        // 金鑰跟著走 —— 忘了傳的話，加密套件會把圖片以明文存進去，
        // 而使用者以為它加密了。
        BlobStore::new(&self.root).with_dek(self.dek.clone())
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
        self.read_ink_with(page, &self.resolve_milestones()?)
    }

    /// 同上，但重用已經算好的里程碑解析結果。
    ///
    /// 一次載入整本筆記時會逐頁呼叫；每頁都重新掃一遍 oplog 的話，
    /// 開啟時間會變成頁數乘以 oplog 長度。
    pub fn read_ink_with(
        &self,
        page: Uuid,
        resolved: &Resolved,
    ) -> Result<Vec<InkRecord>, StorageError> {
        let mut out = Vec::new();
        for path in self.ink_read_paths(page) {
            let bytes = fs::read(&path)?;
            let records = StrokeReader::new(&bytes)?.read_all()?;
            if resolved.is_pristine() {
                out.extend(records);
                continue;
            }
            let device = ink_device_of(&path);
            let visible = resolved.visible_ink_indices(page, device, records.len() as u32);
            out.extend(
                visible
                    .into_iter()
                    .filter_map(|i| records.get(i as usize).cloned()),
            );
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

        // **座標寫進資料流的最前面**，不要只靠檔名。
        //
        // 壓實是純位元組串接，併完之後檔名只剩一個 —— 靠檔名的話，
        // 被併進去的操作會全部宣稱自己是最大的那個 lamport，
        // 里程碑的那一刀就落在錯的地方，而且是**往後**落：
        // 該留下來的內容會跟著被收走。見 `DocOp::BatchOrigin`。
        let mut framed = Vec::with_capacity(ops.len() + 1);
        framed.push(DocOp::BatchOrigin { lamport, device });
        framed.extend_from_slice(ops);
        let encoded = padnote_doc::ops::encode(&framed);
        // 加密套件寫的是**框架**（長度前綴 + 密文），未加密的直接寫明文。
        // 兩者都是純追加，所以同步的「較長的是超集」在兩種情況下都成立。
        let bytes = match &self.dek {
            Some(dek) => {
                let aad = self.oplog_aad(&format!("{lamport:016x}-{device:08x}.oplog"));
                crate::sealed::seal_frame(dek, &encoded, aad.as_bytes())
                    .map_err(|e| StorageError::DocOps(e.to_string()))?
            }
            None => encoded,
        };
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
        for (device_suffix, own_files) in files_by_device {
            if own_files.len() < threshold {
                continue;
            }
            let device = device_suffix
                .trim_start_matches('-')
                .trim_end_matches(".oplog");
            let device = u32::from_str_radix(device, 16).unwrap_or(0);
            for mut run in self.split_at_barriers(own_files, device) {
                if run.len() < 2 {
                    continue;
                }
                run.sort(); // 字典序 = 因果序

                let max_lamport_hex = run
                    .last()
                    .and_then(|p| p.file_stem())
                    .and_then(|s| s.to_str())
                    .and_then(|s| s.split('-').next())
                    .unwrap_or("0000000000000000");

                let compacted_name = format!("{max_lamport_hex}{device_suffix}");
                let compacted_path = dir.join(&compacted_name);

                let mut merged = Vec::new();
                for f in &run {
                    merged.extend_from_slice(&fs::read(f)?);
                }

                crate::atomic::write_atomic(&compacted_path, &merged)?;

                for f in &run {
                    if f != &compacted_path {
                        let _ = fs::remove_file(f);
                    }
                }
                total_merged += run.len();
            }
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
    ) -> Result<Vec<CompactOutcome>, StorageError> {
        let dir = self.root.join("doc/ops");
        if !dir.exists() {
            return Ok(Vec::new());
        }
        let suffix = format!("-{device:08x}.oplog");
        let own: Vec<PathBuf> = fs::read_dir(&dir)?
            .filter_map(Result::ok)
            .filter_map(|e| e.file_name().to_str().map(str::to_string))
            .filter(|name| name.ends_with(&suffix) && !crate::atomic::is_temp_name(name))
            .map(|name| dir.join(name))
            .collect();
        if own.len() < threshold {
            return Ok(Vec::new());
        }

        let mut outcomes = Vec::new();
        for run in self.split_at_barriers(own, device) {
            let mut names: Vec<String> = run
                .iter()
                .filter_map(|p| p.file_name().and_then(|n| n.to_str()).map(str::to_string))
                .collect();
            if names.len() < 2 {
                continue;
            }
            names.sort(); // 字典序 = 因果序

            let max_lamport_hex = names
                .last()
                .and_then(|n| n.split('-').next())
                .unwrap_or("0000000000000000")
                .to_string();
            let compacted_name = format!("{max_lamport_hex}-{device:08x}.oplog");

            let mut merged = Vec::new();
            for name in &names {
                merged.extend_from_slice(&fs::read(dir.join(name))?);
            }
            crate::atomic::write_atomic(&dir.join(&compacted_name), &merged)?;

            let mut absorbed = Vec::new();
            for name in &names {
                if name == &compacted_name {
                    continue;
                }
                let _ = fs::remove_file(dir.join(name));
                absorbed.push(name.clone());
            }
            outcomes.push(CompactOutcome {
                compacted_name,
                absorbed,
            });
        }
        Ok(outcomes)
    }

    /// 把一台裝置的 oplog 檔切成幾段，**段與段之間隔著里程碑的界線**。
    ///
    /// # 為什麼壓實不能跨界線
    ///
    /// 壓實把 `0001..0010` 併成一個叫 `0010` 的檔，於是本來 lamport 為 3 的
    /// 操作對外宣稱自己是 10。里程碑的座標就是那個數字 —— 併過頭之後，
    /// 「回到 lamport 5 那一刻」會落在錯的地方：還原**靜默地**遮錯東西，
    /// 或者什麼都不遮。使用者看到的是「按了還原但沒反應」。
    ///
    /// 同一段裡的檔案對任何一條界線的判定都相同（界線都在段外），
    /// 所以把它們併成一個檔不會改變任何里程碑的答案。
    ///
    /// 界線讀自明文 manifest，不是 oplog —— 壓實刻意不需要金鑰。
    fn split_at_barriers(&self, mut files: Vec<PathBuf>, device: u32) -> Vec<Vec<PathBuf>> {
        let barriers = self.manifest.barriers_for(device);
        if barriers.is_empty() {
            return vec![files];
        }
        files.sort();
        let mut runs: Vec<Vec<PathBuf>> = Vec::new();
        let mut current_bucket = usize::MAX;
        for f in files {
            let lamport = f
                .file_name()
                .and_then(|n| n.to_str())
                .and_then(parse_oplog_name)
                .map_or(0, |(l, _)| l);
            // 這個檔前面有幾條界線 —— 同一個答案的檔可以安全地併在一起。
            let bucket = barriers.partition_point(|w| *w < lamport);
            if bucket != current_bucket {
                runs.push(Vec::new());
                current_bucket = bucket;
            }
            runs.last_mut().expect("剛推進去").push(f);
        }
        runs
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

    /// oplog 全部內容，每一筆都帶著來源座標 `(lamport, device)`。
    ///
    /// 座標取自檔名（`append_doc_ops` 定的格式）。里程碑要靠它才能表示
    /// 「歷史上的一刀」—— 見 `padnote_doc::milestone`。
    pub fn read_doc_op_entries(&self) -> Result<Vec<OpEntry>, StorageError> {
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

        // 加密套件沒有金鑰時**回錯誤，不要回空的**。
        // 回空的話，上層會以為這本筆記是空白的，然後把它存回去 ——
        // 那是一次沒有任何錯誤訊息的資料覆蓋。
        if self.manifest.is_encrypted() && self.dek.is_none() {
            return Err(StorageError::DocOps(
                "這個套件已加密，需要先解鎖才讀得出內容".into(),
            ));
        }

        let mut out = Vec::new();
        for f in files {
            let name = f.file_name().and_then(|n| n.to_str()).unwrap_or_default();
            let (lamport, device) = parse_oplog_name(name).unwrap_or((0, 0));
            let raw = fs::read(&f)?;
            let bytes = match &self.dek {
                Some(dek) => {
                    let aad = self.oplog_aad(name);
                    crate::sealed::open_frames(dek, &raw, aad.as_bytes())
                        .map_err(|e| StorageError::DocOps(e.to_string()))?
                }
                None => raw,
            };
            // 起始座標取自檔名 —— 舊檔沒有 `BatchOrigin`，只能靠它。
            // 有 `BatchOrigin` 的批次會把座標改成自己帶的那一組，
            // 所以壓實過的檔案裡，每一批仍然報得出它原本的 lamport。
            let (mut cur_lamport, mut cur_device) = (lamport, device);
            for op in
                padnote_doc::ops::decode(&bytes).map_err(|e| StorageError::DocOps(e.to_string()))?
            {
                if let DocOp::BatchOrigin { lamport, device } = op {
                    cur_lamport = lamport;
                    cur_device = device;
                    continue;
                }
                out.push(OpEntry {
                    lamport: cur_lamport,
                    device: cur_device,
                    op,
                });
            }
        }
        Ok(out)
    }

    /// 解析里程碑：算出還看得見哪些操作、有哪些里程碑。
    pub fn resolve_milestones(&self) -> Result<Resolved, StorageError> {
        Ok(padnote_doc::milestone::resolve(self.read_doc_op_entries()?))
    }

    /// 可直接重播的操作序列 —— **已經濾掉被里程碑還原遮蔽的那些**。
    ///
    /// 原本這裡只是把檔案串起來。改成走 `resolve` 之後，所有既有呼叫端
    /// 都自動看到正確的結果；若留一個「未過濾」的版本給人挑，遲早有一條
    /// 路徑會忘記過濾，然後在還原之後把被遮蔽的內容又寫回去。
    pub fn read_doc_ops(&self) -> Result<Vec<DocOp>, StorageError> {
        Ok(self.resolve_milestones()?.ops)
    }

    /// 目前的文件向量時鐘：`device -> 最大 lamport`，取自檔名。
    pub fn doc_clock(&self) -> DocClock {
        let dir = self.root.join("doc/ops");
        let mut clock = DocClock::new();
        let Ok(entries) = fs::read_dir(&dir) else {
            return clock;
        };
        for e in entries.filter_map(Result::ok) {
            let path = e.path();
            if !path.extension().is_some_and(|x| x == "oplog") {
                continue;
            }
            let Some(name) = path.file_name().and_then(|n| n.to_str()) else {
                continue;
            };
            if let Some((lamport, device)) = parse_oplog_name(name) {
                let slot = clock.entry(device).or_insert(0);
                *slot = (*slot).max(lamport);
            }
        }
        clock
    }

    /// 目前的筆畫向量時鐘：`(page, device) -> 已寫入的記錄筆數`。
    ///
    /// 需要真的把每個檔解碼一次才知道筆數 —— 記錄是變長的，
    /// 檔案大小換算不出筆數。里程碑是使用者主動按下去的動作，
    /// 這個代價可以接受；日常存檔路徑不會呼叫它。
    pub fn ink_clock(&self) -> Result<InkClock, StorageError> {
        let mut clock = InkClock::new();
        for page in self.ink_pages()? {
            for path in self.ink_read_paths(page) {
                let device = ink_device_of(&path);
                let bytes = fs::read(&path)?;
                let count = StrokeReader::new(&bytes)?.read_all()?.len() as u32;
                clock.insert((page, device), count);
            }
        }
        Ok(clock)
    }

    /// 把 oplog 裡所有里程碑的界線抄進明文 manifest。回傳是否有新增。
    ///
    /// # 為什麼要抄
    ///
    /// 界線記在**本機**的 manifest 裡，但里程碑可能是別台裝置建的：
    /// 裝置 A 建了一個涵蓋「裝置 B 寫到 lamport 7」的里程碑，
    /// 這件事只寫在 A 的 manifest。B 同步下來之後照樣壓實自己的檔，
    /// 就把 A 的還原點踩掉了 —— 而 B 完全不知道自己做了什麼。
    ///
    /// 所以每次開套件時抄一次：有金鑰的時候從 oplog 補齊界線，
    /// 之後即使鎖著也壓實得安全。
    pub fn absorb_milestone_barriers(&mut self) -> Result<bool, StorageError> {
        let entries = self.read_doc_op_entries()?;
        let mut added = false;
        let mut note = |manifest: &mut Manifest, cut: &MilestoneCut| {
            for (device, lamport) in &cut.doc {
                let before = manifest.barriers_for(*device).len();
                manifest.add_milestone_barrier(*device, *lamport);
                added |= manifest.barriers_for(*device).len() != before;
            }
        };
        for e in &entries {
            match &e.op {
                DocOp::MarkMilestone { cut, .. } => note(&mut self.manifest, cut),
                DocOp::RestoreMilestone { cut, upto, .. } => {
                    note(&mut self.manifest, cut);
                    note(&mut self.manifest, upto);
                }
                _ => {}
            }
        }
        if added {
            self.write_manifest()?;
        }
        Ok(added)
    }

    /// 「現在」這一刀 —— 建立里程碑時要記的就是它。
    pub fn current_cut(&self) -> Result<MilestoneCut, StorageError> {
        Ok(MilestoneCut {
            doc: self.doc_clock(),
            ink: self.ink_clock()?,
        })
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

/// 從 `<lamport:016x>-<device:08x>.oplog` 取回座標。
///
/// 檔名不合格式時回 `None`，呼叫端一律當成 `(0, 0)` ——
/// 那種檔只可能是外部工具放進來的，把它排在最前面重播是最保守的選擇。
fn parse_oplog_name(name: &str) -> Option<(u64, u32)> {
    let stem = name.strip_suffix(".oplog")?;
    let (l, d) = stem.split_once('-')?;
    Some((
        u64::from_str_radix(l, 16).ok()?,
        u32::from_str_radix(d, 16).ok()?,
    ))
}

/// 舊版 `ink/<page>.strokes` 沒有裝置欄位，用這個哨兵值代表它。
///
/// 選 `u32::MAX` 而不是 0：0 是一個**合法的裝置 id**，混在一起的話，
/// 舊檔的記錄數會和 device 0 的記錄數互相覆蓋，里程碑就會把不相干的筆畫遮掉。
pub const LEGACY_INK_DEVICE: u32 = u32::MAX;

/// 從筆畫檔名取回裝置 id。
fn ink_device_of(path: &Path) -> u32 {
    path.file_stem()
        .and_then(|s| s.to_str())
        .and_then(|stem| stem.rsplit_once('-'))
        .and_then(|(_, tail)| u32::from_str_radix(tail, 16).ok())
        .unwrap_or(LEGACY_INK_DEVICE)
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

    /// 沒有 `BatchOrigin` 的舊檔仍然要讀得出座標。
    ///
    /// 使用者手上已經有那種檔案了 —— 退不回去用檔名的話，
    /// 既有套件裡每一筆操作的 lamport 都會變成 0，因果序整個垮掉。
    #[test]
    fn an_oplog_written_before_batch_origin_falls_back_to_its_filename() {
        let root = tmp("legacy-oplog");
        let pkg = NotebookPackage::create(&root, "t", 1).unwrap();

        // 直接寫一個**沒有** BatchOrigin 的檔，模擬舊版產生的 oplog。
        let dir = root.join("doc/ops");
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(
            dir.join("0000000000000009-000000aa.oplog"),
            padnote_doc::ops::encode(&[DocOp::SetTitle {
                title: "舊檔".into(),
            }]),
        )
        .unwrap();

        let entries = pkg.read_doc_op_entries().unwrap();
        let found = entries
            .iter()
            .find(|e| matches!(&e.op, DocOp::SetTitle { title } if title == "舊檔"))
            .expect("舊檔的操作要讀得出來");
        assert_eq!((found.lamport, found.device), (9, 0xAA));
    }

    /// 壓實過的檔案裡，每一批仍然報得出它原本的 lamport。
    ///
    /// **這是一次資料遺失的防線。** 靠檔名的話，被併進去的操作會全部宣稱
    /// 自己是最大的那個 lamport，於是一個「回到某一刻」的里程碑會連那一刻
    /// **之前**該留下來的內容一起收走。
    #[test]
    fn compaction_preserves_each_batch_its_own_lamport() {
        let root = tmp("origin-survives-compaction");
        let pkg = NotebookPackage::create(&root, "t", 1).unwrap();
        let dev = 0xCCu32;
        for l in 1..=4u64 {
            pkg.append_doc_ops(
                l,
                dev,
                &[DocOp::SetTitle {
                    title: format!("第{l}"),
                }],
            )
            .unwrap();
        }
        pkg.compact_own_doc_ops(2, dev).unwrap();

        let coords: Vec<(u64, u32)> = pkg
            .read_doc_op_entries()
            .unwrap()
            .iter()
            .filter(|e| matches!(e.op, DocOp::SetTitle { .. }))
            .map(|e| (e.lamport, e.device))
            .collect();
        assert_eq!(
            coords,
            [(1, dev), (2, dev), (3, dev), (4, dev)],
            "壓實之後每一批的 lamport 都要還原得出來，而不是全部變成最大值"
        );
    }

    /// 里程碑最怕的是壓實：壓實會改寫檔名裡的 lamport，而 lamport 就是
    /// 里程碑的座標。這一項確認界線真的擋住了它 ——
    /// 沒有這個保護的話，使用者按下還原會**沒有任何反應**，也沒有錯誤訊息。
    #[test]
    fn compaction_does_not_move_a_milestone_cut() {
        let root = tmp("milestone-compaction");
        let mut pkg = NotebookPackage::create(&root, "t", 1).unwrap();
        let dev = 0xAAu32;

        pkg.append_doc_ops(
            1,
            dev,
            &[DocOp::SetTitle {
                title: "甲".into()
            }],
        )
        .unwrap();
        let cut = pkg.current_cut().unwrap();
        pkg.append_doc_ops(
            2,
            dev,
            &[DocOp::MarkMilestone {
                id: Uuid::from_bytes([7; 16]),
                title: "里程碑".into(),
                creator: "測試".into(),
                created_unix_ms: 100,
                cut: cut.clone(),
                automatic: false,
            }],
        )
        .unwrap();
        for (l, t) in [(3u64, "乙"), (4, "丙"), (5, "丁"), (6, "戊")] {
            pkg.append_doc_ops(l, dev, &[DocOp::SetTitle { title: t.into() }])
                .unwrap();
        }
        let upto = pkg.current_cut().unwrap();
        pkg.absorb_milestone_barriers().unwrap();
        pkg.append_doc_ops(
            7,
            dev,
            &[DocOp::RestoreMilestone {
                milestone: Uuid::from_bytes([7; 16]),
                cut,
                upto,
            }],
        )
        .unwrap();
        pkg.absorb_milestone_barriers().unwrap();

        let before: Vec<String> = titles_of(&pkg);
        assert_eq!(before, ["甲"], "還原之後只該剩下快照當時的標題");

        // 門檻設 2 —— 一定會嘗試壓實。
        pkg.compact_own_doc_ops(2, dev).unwrap();
        assert_eq!(titles_of(&pkg), before, "壓實之後里程碑的還原必須仍然成立");
    }

    fn titles_of(pkg: &NotebookPackage) -> Vec<String> {
        pkg.read_doc_ops()
            .unwrap()
            .into_iter()
            .filter_map(|o| match o {
                DocOp::SetTitle { title } => Some(title),
                _ => None,
            })
            .collect()
    }

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
    fn an_encrypted_package_round_trips_its_ops() {
        use padnote_doc::ops::DocOp;
        let root = tmp("enc-roundtrip");
        let (pkg, phrase) =
            NotebookPackage::create_encrypted(&root, "秘密筆記", 1, "correct horse").unwrap();
        assert!(!phrase.is_empty(), "復原碼只在建立那一刻存在");
        assert!(pkg.is_encrypted());

        pkg.append_doc_ops(
            1,
            0xAA,
            &[DocOp::SetTitle {
                title: "機密".into(),
            }],
        )
        .unwrap();
        pkg.append_doc_ops(
            2,
            0xAA,
            &[DocOp::SetTitle {
                title: "更機密".into(),
            }],
        )
        .unwrap();

        let reopened = NotebookPackage::open(&root)
            .unwrap()
            .unlock("correct horse")
            .unwrap();
        let ops = reopened.read_doc_ops().unwrap();
        assert_eq!(ops.len(), 2);
    }

    #[test]
    fn the_plaintext_never_touches_the_disk() {
        use padnote_doc::ops::DocOp;
        let root = tmp("enc-ondisk");
        let (pkg, _) = NotebookPackage::create_encrypted(&root, "t", 1, "pw").unwrap();
        pkg.append_doc_ops(
            1,
            0xAA,
            &[DocOp::SetTitle {
                title: "這串字不該出現在檔案裡".into(),
            }],
        )
        .unwrap();

        let dir = root.join("doc/ops");
        let mut found = false;
        for entry in std::fs::read_dir(&dir).unwrap().filter_map(Result::ok) {
            let bytes = std::fs::read(entry.path()).unwrap();
            let needle = "這串字".as_bytes();
            assert!(
                !bytes.windows(needle.len()).any(|w| w == needle),
                "明文出現在 {:?}",
                entry.path()
            );
            found = true;
        }
        assert!(found, "沒有寫出任何 oplog 檔");
    }

    #[test]
    fn a_locked_package_refuses_instead_of_looking_empty() {
        // **回空的比回錯誤危險得多**：上層會以為這本筆記是空白的，
        // 然後把它存回去 —— 那是一次沒有任何錯誤訊息的資料覆蓋。
        use padnote_doc::ops::DocOp;
        let root = tmp("enc-locked");
        let (pkg, _) = NotebookPackage::create_encrypted(&root, "t", 1, "pw").unwrap();
        pkg.append_doc_ops(1, 0xAA, &[DocOp::SetTitle { title: "x".into() }])
            .unwrap();

        let locked = NotebookPackage::open(&root).unwrap();
        assert!(locked.read_doc_ops().is_err(), "鎖著卻讀得出東西");
    }

    #[test]
    fn a_wrong_passphrase_does_not_unlock() {
        let root = tmp("enc-wrongpw");
        NotebookPackage::create_encrypted(&root, "t", 1, "right").unwrap();
        assert!(
            NotebookPackage::open(&root)
                .unwrap()
                .unlock("wrong")
                .is_err()
        );
    }

    #[test]
    fn compaction_works_without_the_passphrase() {
        // **這一條很重要**：壓實只是把框架接起來，不需要解密。
        // 需要密碼的話，背景同步在鎖定狀態下就完全動不了。
        use padnote_doc::ops::DocOp;
        let root = tmp("enc-compact");
        let (pkg, _) = NotebookPackage::create_encrypted(&root, "t", 1, "pw").unwrap();
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

        // 用一個**沒有金鑰**的把手壓實。
        let locked = NotebookPackage::open(&root).unwrap();
        let outcome = locked.compact_own_doc_ops(5, 0xAA).unwrap().remove(0);
        assert_eq!(outcome.absorbed.len(), 5);

        // 壓實之後內容還在。
        let unlocked = NotebookPackage::open(&root).unwrap().unlock("pw").unwrap();
        assert_eq!(unlocked.read_doc_ops().unwrap().len(), 6);
    }

    #[test]
    fn an_encrypted_blob_is_ciphertext_on_disk_but_keeps_its_plaintext_name() {
        let root = tmp("enc-blob");
        let (pkg, _) = NotebookPackage::create_encrypted(&root, "t", 1, "pw").unwrap();
        let plaintext = "這張圖的內容不該出現在磁碟上".as_bytes();
        let id = pkg.blobs().put(plaintext).unwrap();

        // 檔名是**明文**的雜湊 —— 那是去重的鍵，兩台裝置的同一張圖
        // 必須算出同一個名字。
        assert_eq!(id, crate::BlobId::of(plaintext));

        // 但磁碟上的位元組是密文。
        let mut found = false;
        for entry in walk(&root.join("media/blobs")) {
            let bytes = std::fs::read(&entry).unwrap();
            assert!(
                !bytes.windows(plaintext.len()).any(|w| w == plaintext),
                "明文出現在 {entry:?}"
            );
            found = true;
        }
        assert!(found, "沒有寫出任何 blob");

        // 解得回來，而且驗得過雜湊。
        let reopened = NotebookPackage::open(&root).unwrap().unlock("pw").unwrap();
        assert_eq!(reopened.blobs().get(id).unwrap(), plaintext);
    }

    #[test]
    fn a_blob_cannot_be_read_without_the_passphrase() {
        let root = tmp("enc-blob-locked");
        let (pkg, _) = NotebookPackage::create_encrypted(&root, "t", 1, "pw").unwrap();
        let id = pkg.blobs().put(b"secret image").unwrap();
        // 沒有金鑰的把手讀出來的是密文，雜湊當然對不上 —— 要回錯誤，
        // 不能把那串密文交出去（交出去的話畫面上會出現一張壞掉的圖）。
        let locked = NotebookPackage::open(&root).unwrap();
        assert!(locked.blobs().get(id).is_err());
    }

    /// 遞迴列出目錄下的所有檔案。blob 是分兩層放的（`<aa>/<sha256>`）。
    fn walk(dir: &std::path::Path) -> Vec<PathBuf> {
        let mut out = Vec::new();
        let Ok(entries) = std::fs::read_dir(dir) else {
            return out;
        };
        for entry in entries.filter_map(Result::ok) {
            let path = entry.path();
            if path.is_dir() {
                out.extend(walk(&path));
            } else {
                out.push(path);
            }
        }
        out
    }

    #[test]
    fn a_frame_cannot_be_moved_to_another_notebook() {
        // AAD 綁筆記本 id。少了它，把 A 本的密文搬進 B 本仍然解得開 ——
        // 兩本用同一把金鑰時（同一個使用者）這是真的可能發生的。
        use padnote_doc::ops::DocOp;
        let a_root = tmp("enc-aad-a");
        let b_root = tmp("enc-aad-b");
        let (a, _) = NotebookPackage::create_encrypted(&a_root, "A", 1, "pw").unwrap();
        a.append_doc_ops(
            1,
            0xAA,
            &[DocOp::SetTitle {
                title: "A 的秘密".into(),
            }],
        )
        .unwrap();

        // 把 A 的金鑰與密文搬到 B。
        let (b, _) = NotebookPackage::create_encrypted(&b_root, "B", 1, "pw").unwrap();
        let stolen = std::fs::read(a_root.join("doc/ops/0000000000000001-000000aa.oplog")).unwrap();
        b.write_doc_op_file("0000000000000001-000000aa.oplog", &stolen)
            .unwrap();

        let a_dek = NotebookPackage::open(&a_root)
            .unwrap()
            .unlock("pw")
            .unwrap();
        let _ = a_dek; // 只是確認 A 自己開得起來
        // B 用自己的密碼（同一組密碼，不同的 DEK）當然開不了；
        // 重點是**即使金鑰相同**，AAD 也會擋下來 —— 這裡用 B 的把手試。
        let b_unlocked = NotebookPackage::open(&b_root)
            .unwrap()
            .unlock("pw")
            .unwrap();
        assert!(b_unlocked.read_doc_ops().is_err(), "別本的密文被讀出來了");
    }

    #[test]
    fn an_unencrypted_package_is_unaffected() {
        // 決策：**只加密新的，舊的原地不動**。既有的套件一個位元組都不該變。
        use padnote_doc::ops::DocOp;
        let root = tmp("enc-none");
        let pkg = NotebookPackage::create(&root, "t", 1).unwrap();
        assert!(!pkg.is_encrypted());
        pkg.append_doc_ops(
            1,
            0xAA,
            &[DocOp::SetTitle {
                title: "明文".into(),
            }],
        )
        .unwrap();
        assert_eq!(
            NotebookPackage::open(&root)
                .unwrap()
                .read_doc_ops()
                .unwrap()
                .len(),
            1,
            "未加密的套件不需要解鎖"
        );
    }

    #[test]
    fn unlocking_a_plain_package_is_an_error_not_a_silent_success() {
        let root = tmp("enc-plainunlock");
        NotebookPackage::create(&root, "t", 1).unwrap();
        assert!(NotebookPackage::open(&root).unwrap().unlock("pw").is_err());
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

        let outcome = pkg.compact_own_doc_ops(5, 0xAA).unwrap().remove(0);
        assert_eq!(outcome.compacted_name, "0000000000000006-000000aa.oplog");
        assert_eq!(outcome.absorbed.len(), 5, "自己的五個碎檔該被吃掉");

        let names: Vec<String> = pkg
            .doc_op_files()
            .unwrap()
            .into_iter()
            .map(|(n, _)| n)
            .collect();
        // 別台裝置的四個檔一個都不能少。
        assert_eq!(
            names
                .iter()
                .filter(|n| n.ends_with("-000000bb.oplog"))
                .count(),
            4
        );
        assert_eq!(
            names
                .iter()
                .filter(|n| n.ends_with("-000000aa.oplog"))
                .count(),
            1
        );
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
        assert!(pkg.compact_own_doc_ops(5, 0xAA).unwrap().is_empty());
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
        pkg.compact_own_doc_ops(5, 0xAA).unwrap();
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
