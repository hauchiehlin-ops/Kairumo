//! 同步編排（`architecture.md` §4.2）。
//!
//! ```text
//! 本機編輯 → 寫 local oplog（<1ms）→ 標記 dirty
//! 背景     → 1. 壓縮 + 加密本機增量 → 上傳到自己的 chunk
//!            2. 拉取其他 device 的增量
//!            3. 解密 → 套用 → 通知 UI
//! ```
//!
//! 這一層只負責**時序與檔案佈局**，收斂性由 CRDT 語意保證（S3 已驗證）。

use crate::oplog::{DeviceId, LamportClock};
use crate::provider::{CloudProvider, SyncError};
use padnote_crypto::Dek;
use std::collections::BTreeMap;

/// 每筆推送在 chunk 內的框架標頭長度（`u32` 長度前綴）。
///
/// **沒有框架就會有這個 bug**：兩次 push 之間只 pull 一次時，讀到的位元組範圍
/// 會橫跨兩個獨立的密文塊，解密必然失敗。長度前綴讓讀取端能正確切分。
pub const FRAME_HEADER_LEN: usize = 4;

/// 單一 chunk 的大小上限。
///
/// 太小會讓 Google Drive 這類不支援 append 的 provider 產生大量小檔；
/// 太大則讓增量拉取失去意義。4 MiB 是折衷。
pub const CHUNK_SIZE_LIMIT: u64 = 4 * 1024 * 1024;

/// 同步狀態。持久化於本機 SQLite，讓 App 重啟後不必重拉全部資料。
#[derive(Clone, Debug, Default)]
pub struct SyncCursors {
    /// 遠端檔案路徑 → 已讀取的位元組數。
    read: BTreeMap<String, u64>,
}

impl SyncCursors {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn position(&self, path: &str) -> u64 {
        self.read.get(path).copied().unwrap_or(0)
    }

    pub fn advance(&mut self, path: &str, to: u64) {
        let entry = self.read.entry(path.to_string()).or_insert(0);
        // 永不倒退 —— 遠端檔案變短代表被竄改或損毀，不是正常的同步事件。
        *entry = (*entry).max(to);
    }

    pub fn tracked_paths(&self) -> impl Iterator<Item = &str> {
        self.read.keys().map(String::as_str)
    }
}

/// 一批待套用的遠端變更。
#[derive(Debug)]
pub struct PulledBatch {
    pub device: DeviceId,
    pub path: String,
    pub payload: Vec<u8>,
}

#[derive(Debug)]
pub struct SyncEngine<P: CloudProvider> {
    provider: P,
    device: DeviceId,
    clock: LamportClock,
    cursors: SyncCursors,
    /// `None` 表示未加密（`Encryption::None`）。
    dek: Option<Dek>,
    /// 目前寫入中的 chunk 序號（僅在不支援 append 時使用）。
    current_chunk: u32,
    /// 是否已經從雲端接續過序號。見 [`SyncEngine::resume_chunk_seq`]。
    chunk_seq_resumed: bool,
}

impl<P: CloudProvider> SyncEngine<P> {
    pub fn new(provider: P, device: DeviceId, dek: Option<Dek>) -> Self {
        Self {
            provider,
            device,
            clock: LamportClock::default(),
            cursors: SyncCursors::new(),
            dek,
            current_chunk: 0,
            chunk_seq_resumed: false,
        }
    }

    pub fn with_cursors(mut self, cursors: SyncCursors) -> Self {
        self.cursors = cursors;
        self
    }

    pub fn cursors(&self) -> &SyncCursors {
        &self.cursors
    }

    pub fn device(&self) -> DeviceId {
        self.device
    }

    fn own_prefix(&self) -> String {
        format!("sync/{}", self.device)
    }

    fn chunk_path(&self, seq: u32) -> String {
        format!("{}/log-{seq}.bin", self.own_prefix())
    }

    /// 推送本機變更。
    ///
    /// 支援 append 的 provider 直接接在同一個檔案後面；不支援的（Google Drive）
    /// 則開新檔 —— 兩者都維持 append-only 不變式。
    pub fn push(&mut self, payload: &[u8]) -> Result<String, SyncError> {
        self.clock.tick();

        let path = if self.provider.supports_native_append() {
            let p = self.chunk_path(self.current_chunk);
            // 同一個 chunk 太大時換新檔，讓增量拉取仍然有效率。
            if self.size_of(&p)? >= CHUNK_SIZE_LIMIT {
                self.current_chunk += 1;
                self.chunk_path(self.current_chunk)
            } else {
                p
            }
        } else {
            // **序號要從雲端接續，不能從 0 重來。**
            //
            // 不接續的話，重開 App 之後第一次推送又會寫 `log-1.bin`，
            // 把上一個 session 的第一塊直接蓋掉 —— 而且沒有任何錯誤：
            // 檔案數不變、上傳成功、cursors 也對得上，只是內容沒了。
            // 只有不支援 append 的 provider（Google Drive）會踩到，
            // 因為 append 那條路是接在後面而不是覆寫。
            self.resume_chunk_seq()?;
            self.current_chunk += 1;
            self.chunk_path(self.current_chunk)
        };

        let sealed = self.seal(payload, &path)?;
        let mut body = (sealed.len() as u32).to_le_bytes().to_vec();
        body.extend_from_slice(&sealed);

        if self.provider.supports_native_append() {
            self.provider.append(&path, &body)?;
        } else {
            self.provider.put(&path, &body)?;
        }

        // 自己寫的內容不需要再拉回來。
        let size = self.size_of(&path)?;
        self.cursors.advance(&path, size);
        Ok(path)
    }

    /// 拉取所有**其他**裝置的新增內容。
    ///
    /// 跳過自己的檔案：本機狀態已經是最新的，重拉只是浪費頻寬與電力。
    pub fn pull(&mut self) -> Result<Vec<PulledBatch>, SyncError> {
        let mut out = Vec::new();
        let own = self.own_prefix();

        for entry in self.provider.list("sync")? {
            // 跳過自己：本機已是最新，重拉只是浪費頻寬與電力。
            if entry.path.starts_with(&own) {
                continue;
            }
            let Some(device) = device_from_path(&entry.path) else {
                continue;
            };
            let from = self.cursors.position(&entry.path);
            if from >= entry.size {
                continue; // 已讀完
            }

            let raw = self.provider.get_range(&entry.path, from..entry.size)?;
            let (frames, consumed) = split_frames(&raw);

            for frame in frames {
                out.push(PulledBatch {
                    device,
                    path: entry.path.clone(),
                    payload: self.open(frame, &entry.path)?,
                });
            }

            // 只推進到**完整框架**的邊界。寫到一半就當機的尾巴留待下次補齊，
            // 而不是把半個框架當成損毀資料丟掉。
            self.cursors.advance(&entry.path, from + consumed as u64);
        }
        Ok(out)
    }

    /// 從雲端找出這台裝置已經寫到第幾號 chunk。
    ///
    /// 只做一次（之後靠記憶體裡的計數），所以不會每次推送都多一趟列舉。
    fn resume_chunk_seq(&mut self) -> Result<(), SyncError> {
        if self.chunk_seq_resumed {
            return Ok(());
        }
        let prefix = self.own_prefix();
        let highest = self
            .provider
            .list(&prefix)?
            .into_iter()
            .filter_map(|entry| chunk_seq_from_path(&entry.path))
            .max()
            .unwrap_or(0);
        self.current_chunk = self.current_chunk.max(highest);
        self.chunk_seq_resumed = true;
        Ok(())
    }

    fn size_of(&self, path: &str) -> Result<u64, SyncError> {
        let parent = path.rsplit_once('/').map(|(p, _)| p).unwrap_or("");
        Ok(self
            .provider
            .list(parent)?
            .into_iter()
            .find(|e| e.path == path)
            .map_or(0, |e| e.size))
    }

    fn seal(&self, payload: &[u8], path: &str) -> Result<Vec<u8>, SyncError> {
        match &self.dek {
            // AAD 綁路徑，防止把 A 檔的密文搬到 B 檔的位置。
            Some(dek) => dek
                .seal(payload, path.as_bytes())
                .map_err(|e| SyncError::Backend(e.to_string())),
            None => Ok(payload.to_vec()),
        }
    }

    fn open(&self, raw: &[u8], path: &str) -> Result<Vec<u8>, SyncError> {
        match &self.dek {
            Some(dek) => dek
                .open(raw, path.as_bytes())
                .map_err(|e| SyncError::Backend(e.to_string())),
            None => Ok(raw.to_vec()),
        }
    }
}

/// 切出完整框架，回傳 (框架們, 已消耗的位元組數)。
fn split_frames(data: &[u8]) -> (Vec<&[u8]>, usize) {
    let mut frames = Vec::new();
    let mut pos = 0;
    while pos + FRAME_HEADER_LEN <= data.len() {
        let len =
            u32::from_le_bytes(data[pos..pos + FRAME_HEADER_LEN].try_into().unwrap()) as usize;
        let end = pos + FRAME_HEADER_LEN + len;
        if end > data.len() {
            break; // 框架不完整，留到下次
        }
        frames.push(&data[pos + FRAME_HEADER_LEN..end]);
        pos = end;
    }
    (frames, pos)
}

/// 從 `sync/<device_id>/log-N.bin` 取出 device id。
/// `sync/<device>/log-<seq>.bin` → `seq`。認不得的檔名回 `None`。
fn chunk_seq_from_path(path: &str) -> Option<u32> {
    path.rsplit('/')
        .next()?
        .strip_prefix("log-")?
        .strip_suffix(".bin")?
        .parse()
        .ok()
}

fn device_from_path(path: &str) -> Option<DeviceId> {
    let mut parts = path.split('/');
    if parts.next()? != "sync" {
        return None;
    }
    let hex = parts.next()?;
    if hex.len() != 8 {
        return None;
    }
    u32::from_str_radix(hex, 16).ok().map(DeviceId)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::local::LocalFolderProvider;
    use std::path::PathBuf;

    fn tmp(name: &str) -> PathBuf {
        let d = std::env::temp_dir().join(format!("padnote-eng-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        std::fs::create_dir_all(&d).unwrap();
        d
    }

    fn engine(root: &PathBuf, id: u32, dek: Option<Dek>) -> SyncEngine<LocalFolderProvider> {
        SyncEngine::new(LocalFolderProvider::new(root), DeviceId(id), dek)
    }

    /// 不支援 append 的 provider（Google Drive 就是這一種）。
    ///
    /// 既有的測試全都用 `LocalFolderProvider`，而它**支援** append ——
    /// 所以不支援 append 的那條路一行都沒有被測到，重啟覆寫的 bug
    /// 才會一直躺在那裡。
    #[derive(Debug, Default, Clone)]
    struct NoAppendProvider {
        files: std::sync::Arc<std::sync::Mutex<BTreeMap<String, Vec<u8>>>>,
    }

    impl CloudProvider for NoAppendProvider {
        fn list(&self, prefix: &str) -> Result<Vec<crate::provider::RemoteEntry>, SyncError> {
            Ok(self
                .files
                .lock()
                .unwrap()
                .iter()
                .filter(|(p, _)| p.starts_with(prefix))
                .map(|(p, d)| crate::provider::RemoteEntry {
                    path: p.clone(),
                    size: d.len() as u64,
                })
                .collect())
        }
        fn get_range(&self, path: &str, range: std::ops::Range<u64>) -> Result<Vec<u8>, SyncError> {
            let files = self.files.lock().unwrap();
            let data = files.get(path).ok_or(SyncError::NotFound(path.into()))?;
            let start = (range.start as usize).min(data.len());
            let end = (range.end as usize).min(data.len());
            Ok(data[start..end].to_vec())
        }
        fn append(&self, _path: &str, _data: &[u8]) -> Result<(), SyncError> {
            Err(SyncError::Backend("不支援 append".into()))
        }
        fn put(&self, path: &str, data: &[u8]) -> Result<(), SyncError> {
            self.files.lock().unwrap().insert(path.to_string(), data.to_vec());
            Ok(())
        }
        fn supports_native_append(&self) -> bool {
            false
        }
    }

    #[test]
    fn restarting_does_not_overwrite_the_previous_sessions_chunks() {
        // **這是一個真的資料遺失 bug 的回歸測試。**
        //
        // 序號原本從 0 重來，所以重開 App 之後第一次推送又寫 `log-1.bin`，
        // 把上一個 session 的第一塊直接蓋掉 —— 沒有任何錯誤：檔案數不變、
        // 上傳成功、cursors 也對得上，只是內容沒了。
        let cloud = NoAppendProvider::default();

        let mut first = SyncEngine::new(cloud.clone(), DeviceId(1), None);
        first.push(b"session-1-a").unwrap();
        first.push(b"session-1-b").unwrap();

        // 重啟：全新的 engine，同一個雲端。
        let mut second = SyncEngine::new(cloud.clone(), DeviceId(1), None);
        second.push(b"session-2-a").unwrap();

        let files = cloud.files.lock().unwrap();
        assert_eq!(files.len(), 3, "三次推送就該有三個檔案，被蓋掉才會少");
        assert!(files.contains_key("sync/00000001/log-1.bin"));
        assert!(files.contains_key("sync/00000001/log-2.bin"));
        assert!(files.contains_key("sync/00000001/log-3.bin"));
    }

    #[test]
    fn another_device_sees_everything_written_before_a_restart() {
        // 上一個測試證明檔案還在；這個證明**內容真的讀得回來**。
        let cloud = NoAppendProvider::default();

        let mut a1 = SyncEngine::new(cloud.clone(), DeviceId(1), None);
        a1.push(b"before-restart").unwrap();
        let mut a2 = SyncEngine::new(cloud.clone(), DeviceId(1), None);
        a2.push(b"after-restart").unwrap();

        let mut b = SyncEngine::new(cloud.clone(), DeviceId(2), None);
        let payloads: Vec<Vec<u8>> = b.pull().unwrap().into_iter().map(|p| p.payload).collect();
        assert!(payloads.contains(&b"before-restart".to_vec()), "重啟前的內容不見了");
        assert!(payloads.contains(&b"after-restart".to_vec()));
    }

    #[test]
    fn chunk_sequence_is_parsed_from_the_path() {
        assert_eq!(chunk_seq_from_path("sync/00000001/log-7.bin"), Some(7));
        // 認不得的檔名不要當成 0 —— 那會讓接續邏輯以為還沒寫過任何東西。
        assert_eq!(chunk_seq_from_path("sync/00000001/notes.txt"), None);
        assert_eq!(chunk_seq_from_path("sync/00000001/log-.bin"), None);
    }

    #[test]
    fn push_writes_under_own_device_prefix() {
        let root = tmp("prefix");
        let mut e = engine(&root, 0xA1, None);
        let path = e.push(b"payload").unwrap();
        assert_eq!(path, "sync/000000a1/log-0.bin");
    }

    #[test]
    fn pull_sees_other_devices_but_not_itself() {
        let root = tmp("pull");
        let mut a = engine(&root, 0xA1, None);
        let mut b = engine(&root, 0xB2, None);

        a.push(b"from a").unwrap();
        b.push(b"from b").unwrap();

        let got_by_a = a.pull().unwrap();
        assert_eq!(got_by_a.len(), 1, "只該看到對方的");
        assert_eq!(got_by_a[0].device, DeviceId(0xB2));
        assert_eq!(got_by_a[0].payload, b"from b");
    }

    #[test]
    fn pull_is_incremental() {
        let root = tmp("incremental");
        let mut a = engine(&root, 0xA1, None);
        let mut b = engine(&root, 0xB2, None);

        b.push(b"first").unwrap();
        assert_eq!(a.pull().unwrap().len(), 1);

        // 沒有新東西時不該重複拉
        assert!(a.pull().unwrap().is_empty(), "已讀過的內容不該重拉");

        b.push(b"second").unwrap();
        let batch = a.pull().unwrap();
        assert_eq!(batch.len(), 1);
        assert_eq!(batch[0].payload, b"second", "只該拿到新增的部分");
    }

    #[test]
    fn cursors_never_go_backwards() {
        // 遠端變短代表被竄改或損毀，不是正常同步事件。
        let mut c = SyncCursors::new();
        c.advance("p", 100);
        c.advance("p", 50);
        assert_eq!(c.position("p"), 100);
    }

    #[test]
    fn cursors_can_be_restored_to_skip_replay() {
        let root = tmp("restore");
        let mut b = engine(&root, 0xB2, None);
        b.push(b"already seen").unwrap();

        let saved = {
            let mut a = engine(&root, 0xA1, None);
            a.pull().unwrap();
            a.cursors().clone()
        };

        // 新的 engine 帶著存下來的游標開機 ⇒ 不重播
        let mut restarted = engine(&root, 0xA1, None).with_cursors(saved);
        assert!(
            restarted.pull().unwrap().is_empty(),
            "重啟後不該重拉已套用的內容"
        );
    }

    #[test]
    fn encrypted_payload_is_unreadable_on_disk() {
        let root = tmp("encrypted");
        let dek = Dek::generate().unwrap();

        let mut a = engine(&root, 0xA1, Some(dek.clone()));
        a.push("機密筆記內容".as_bytes()).unwrap();

        let raw = std::fs::read(root.join("sync/000000a1/log-0.bin")).unwrap();
        assert!(
            !raw.windows(6).any(|w| w == "機密".as_bytes()),
            "明文不得出現在雲端檔案中"
        );

        let mut b = engine(&root, 0xB2, Some(dek));
        assert_eq!(b.pull().unwrap()[0].payload, "機密筆記內容".as_bytes());
    }

    #[test]
    fn device_without_the_key_cannot_read() {
        let root = tmp("wrongkey");
        let mut a = engine(&root, 0xA1, Some(Dek::generate().unwrap()));
        a.push(b"secret").unwrap();

        let mut b = engine(&root, 0xB2, Some(Dek::generate().unwrap()));
        assert!(b.pull().is_err(), "沒有正確 DEK 不該讀得出來");
    }

    #[test]
    fn multiple_pushes_before_one_pull_are_all_recovered() {
        // 沒有框架化時這個測試會失敗：讀取範圍橫跨兩個密文塊，解密必然出錯。
        let root = tmp("multi");
        let dek = Dek::generate().unwrap();
        let mut a = engine(&root, 0xA1, Some(dek.clone()));
        let mut b = engine(&root, 0xB2, Some(dek));

        a.push(b"first").unwrap();
        a.push(b"second").unwrap();
        a.push(b"third").unwrap();

        let got: Vec<Vec<u8>> = b.pull().unwrap().into_iter().map(|p| p.payload).collect();
        assert_eq!(
            got,
            vec![b"first".to_vec(), b"second".to_vec(), b"third".to_vec()]
        );
    }

    #[test]
    fn partial_frame_is_retried_not_discarded() {
        // 寫到一半當機留下的半個框架，必須等它補齊而不是當成損毀丟掉。
        let (frames, consumed) = split_frames(&[3, 0, 0, 0, b'a', b'b']);
        assert!(frames.is_empty());
        assert_eq!(consumed, 0, "不完整的框架不得推進游標");

        let complete = [3u8, 0, 0, 0, b'a', b'b', b'c', 99];
        let (frames, consumed) = split_frames(&complete);
        assert_eq!(frames, vec![&b"abc"[..]]);
        assert_eq!(consumed, 7, "只消耗完整的部分");
    }

    #[test]
    fn device_id_parses_from_path() {
        assert_eq!(
            device_from_path("sync/7c4e9b12/log-0.bin"),
            Some(DeviceId(0x7c4e9b12))
        );
        assert_eq!(device_from_path("ops/0000-aaaa.oplog"), None);
        assert_eq!(device_from_path("sync/short/log-0.bin"), None);
    }

    #[test]
    fn three_devices_each_see_the_other_two() {
        let root = tmp("three");
        let mut a = engine(&root, 0xA1, None);
        let mut b = engine(&root, 0xB2, None);
        let mut c = engine(&root, 0xC3, None);

        a.push(b"a").unwrap();
        b.push(b"b").unwrap();
        c.push(b"c").unwrap();

        for (e, expect) in [
            (&mut a, [b"b", b"c"]),
            (&mut b, [b"a", b"c"]),
            (&mut c, [b"a", b"b"]),
        ] {
            let mut got: Vec<Vec<u8>> = e.pull().unwrap().into_iter().map(|p| p.payload).collect();
            got.sort();
            assert_eq!(got, expect.map(|x| x.to_vec()).to_vec());
        }
    }
}
