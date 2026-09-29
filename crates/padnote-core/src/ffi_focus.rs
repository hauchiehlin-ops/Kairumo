//! 秒同步的平台介面：焦點通道排程、每本筆記本一把鎖、區網直連。
//!
//! 策略與協定都在 [`padnote_sync`]（[`padnote_sync::focus`]、
//! [`padnote_sync::gate::NotebookLocks`]、[`padnote_sync::lan`]），這裡只是
//! 一層帶鎖的門面，讓 Swift 與 Kotlin 共用**同一份**節奏與協定 ——
//! 各寫一份的話，使用者看到的不是「策略不同」，是「Android 比較慢」。
//!
//! 平台層要做的事：
//!
//! 1. **焦點**：打開／離開一本筆記時呼叫 [`FfiFocusLane::set_focus`]；
//!    存檔完成呼叫 [`FfiFocusLane::note_local_edit`]。
//! 2. **計時器**：依 [`FfiFocusLane::next_due_in_ms`] 醒來，問
//!    [`FfiFocusLane::poll`]；有事就拿 [`notebook_lock_try_enter`]，
//!    匯出（若 `push`）→ [`crate::ffi_gdrive::FfiSyncSession::focus_round`]
//!    → 匯入，最後 [`FfiFocusLane::finish`]。
//! 3. **區網**：Bonjour / NSD 只負責「發現」，把位址交給
//!    [`FfiLanNode::connect`]；其餘全在核心。

use std::path::Path;
use std::sync::{Arc, Mutex, OnceLock};

use padnote_sync::focus::{FocusLane, FocusOutcome};
use padnote_sync::gate::{GateDecision, NotebookLocks};
use padnote_sync::lan::{LanFile, LanKind, LanNode, LanStore};

use crate::ffi_sync_gate::FfiSyncGrant;

// ── 焦點通道排程 ──────────────────────────────────────────────

/// 一輪焦點同步的結果。
#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum FfiFocusOutcome {
    /// 成功，這一輪沒有拉到對方的東西。
    Success,
    /// 成功，而且**拉到了對方的東西**（下載數 > 0）——
    /// 那是「對方正在寫」唯一可靠的證據，排程器會改用快檔。
    Pulled,
    /// 網路不通、5xx、逾時。
    Transient,
    /// 權杖失效。
    NeedsReauth,
    /// 這本筆記本正被整庫那條通道處理（鎖沒拿到）。
    Busy,
}

impl From<FfiFocusOutcome> for FocusOutcome {
    fn from(o: FfiFocusOutcome) -> Self {
        match o {
            FfiFocusOutcome::Success => Self::Success { pulled: false },
            FfiFocusOutcome::Pulled => Self::Success { pulled: true },
            FfiFocusOutcome::Transient => Self::Transient,
            FfiFocusOutcome::NeedsReauth => Self::NeedsReauth,
            FfiFocusOutcome::Busy => Self::Busy,
        }
    }
}

/// 這一輪要做什麼。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiFocusRun {
    pub notebook_id: String,
    /// 本機有還沒推的寫入，要先把工作副本匯出進套件。`false` 時匯出可以整段跳過。
    pub push: bool,
}

/// 焦點通道排程器。整個 App 共用一個。
#[derive(Debug, uniffi::Object)]
pub struct FfiFocusLane {
    inner: Mutex<FocusLane>,
}

#[uniffi::export]
impl FfiFocusLane {
    #[uniffi::constructor]
    pub fn create() -> Arc<Self> {
        Arc::new(Self {
            inner: Mutex::new(FocusLane::new()),
        })
    }

    /// 現在開著哪一本。`None` = 沒有（回到首頁、進背景）。
    /// `now_ms` 用單調時鐘，**不要用牆上時間**。
    pub fn set_focus(&self, notebook_id: Option<String>, now_ms: u64) {
        self.inner
            .lock()
            .unwrap()
            .set_focus(notebook_id.as_deref(), now_ms);
    }

    pub fn focused(&self) -> Option<String> {
        self.inner.lock().unwrap().focused().map(str::to_string)
    }

    /// 焦點筆記本存檔完成。**要在落盤之後**呼叫，否則會推到還沒寫完的檔案。
    pub fn note_local_edit(&self, now_ms: u64) {
        self.inner.lock().unwrap().note_local_edit(now_ms);
    }

    /// 有跡象顯示對方剛動過（區網對端收到東西、App 進前景）—— 不等輪詢週期。
    pub fn note_remote_hint(&self, now_ms: u64) {
        self.inner.lock().unwrap().note_remote_hint(now_ms);
    }

    pub fn note_signed_in(&self, now_ms: u64) {
        self.inner.lock().unwrap().note_signed_in(now_ms);
    }

    /// 現在該不該跑。回 `Some` 就開始，並在結束時呼叫 [`Self::finish`]。
    pub fn poll(&self, now_ms: u64) -> Option<FfiFocusRun> {
        self.inner
            .lock()
            .unwrap()
            .poll(now_ms)
            .map(|run| FfiFocusRun {
                notebook_id: run.notebook_id,
                push: run.push,
            })
    }

    /// 一輪跑完。`notebook_id` 是這一輪處理的那一本 —— 跑的途中切走的話，
    /// 結果不會套用在新的那一本身上。
    pub fn finish(&self, notebook_id: String, outcome: FfiFocusOutcome, now_ms: u64) {
        self.inner
            .lock()
            .unwrap()
            .finish(&notebook_id, outcome.into(), now_ms);
    }

    /// 距離下一次該起跑還有多久（毫秒）。`u64::MAX` = 沒有待辦。
    pub fn next_due_in_ms(&self, now_ms: u64) -> u64 {
        self.inner
            .lock()
            .unwrap()
            .next_due_in_ms(now_ms)
            .unwrap_or(u64::MAX)
    }

    pub fn is_running(&self) -> bool {
        self.inner.lock().unwrap().is_running()
    }

    pub fn is_blocked_on_auth(&self) -> bool {
        self.inner.lock().unwrap().is_blocked_on_auth()
    }

    pub fn has_unpushed_edits(&self) -> bool {
        self.inner.lock().unwrap().has_unpushed_edits()
    }
}

/// 焦點通道的輪詢間隔（毫秒）。給介面顯示與測試用。
#[uniffi::export]
pub fn focus_poll_interval_ms() -> u64 {
    padnote_sync::focus::FOCUS_POLL_MS
}

/// 焦點通道本機寫入之後的去抖動（毫秒）。
#[uniffi::export]
pub fn focus_debounce_ms() -> u64 {
    padnote_sync::focus::FOCUS_DEBOUNCE_MS
}

/// **對使用者的承諾**：一邊寫完，另一邊最久多久看得到（毫秒，不含網路時間）。
#[uniffi::export]
pub fn focus_worst_case_visible_latency_ms() -> u64 {
    padnote_sync::focus::worst_case_visible_latency_ms()
}

// ── 每本筆記本一把鎖 ──────────────────────────────────────────

fn locks() -> &'static Mutex<NotebookLocks> {
    static LOCKS: OnceLock<Mutex<NotebookLocks>> = OnceLock::new();
    LOCKS.get_or_init(|| Mutex::new(NotebookLocks::new()))
}

/// 鎖住一本筆記本的套件目錄。焦點通道與整庫通道**都要**在動這本之前拿。
///
/// 拿不到就**跳過，不排隊**：同步是冪等的，另一條通道正在處理它，
/// 下一輪自然會看到結果。
#[uniffi::export]
pub fn notebook_lock_try_enter(notebook_id: String, label: String, now_ms: u64) -> FfiSyncGrant {
    let mut locks = locks()
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    match locks.try_enter(&notebook_id, &label, now_ms) {
        GateDecision::Entered { ticket } => FfiSyncGrant {
            granted: true,
            ticket,
            holder: label,
            held_ms: 0,
            took_over: false,
        },
        GateDecision::TookOver {
            ticket,
            previous,
            held_ms,
        } => FfiSyncGrant {
            granted: true,
            ticket,
            holder: previous,
            held_ms,
            took_over: true,
        },
        GateDecision::Busy { holder, held_ms } => FfiSyncGrant {
            granted: false,
            ticket: 0,
            holder,
            held_ms,
            took_over: false,
        },
    }
}

/// 放鎖。票號對不上就什麼也不做（回傳 `false`）。
#[uniffi::export]
pub fn notebook_lock_leave(notebook_id: String, ticket: u64) -> bool {
    locks()
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
        .leave(&notebook_id, ticket)
}

// ── 區網直連 ──────────────────────────────────────────────────

/// 平台要實作的宿主：告訴核心「現在開著哪一本」「套件在哪」，
/// 並接收「收到東西了」的通知。
#[uniffi::export(with_foreign)]
pub trait FfiLanHost: Send + Sync {
    fn focused_notebook(&self) -> Option<String>;
    /// 這本筆記本的套件目錄。沒有這本就回 `None`（區網不建立整本筆記）。
    fn package_path(&self, notebook_id: String) -> Option<String>;
    /// 一批檔案收完並寫進套件了。平台要把套件匯入回畫面。
    /// **從核心的網路執行緒呼叫，不要在這裡做重活** —— 丟到自己的佇列。
    fn on_received(&self, notebook_id: String, files: u32);
    /// 連線的對端數量變了。
    fn on_peers_changed(&self, count: u32);
}

#[derive(Clone, Debug, thiserror::Error, uniffi::Error)]
pub enum FfiLanError {
    #[error("金鑰長度不對（要 32 位元組）")]
    BadKey,
    #[error("起不了區網節點：{detail}")]
    Start { detail: String },
}

/// 把套件目錄接成區網通道的儲存。
struct PackageLanStore {
    host: Arc<dyn FfiLanHost>,
    device_id: u32,
}

impl PackageLanStore {
    fn open(&self, notebook_id: &str) -> Option<padnote_storage::NotebookPackage> {
        let path = self.host.package_path(notebook_id.to_string())?;
        padnote_storage::NotebookPackage::open(Path::new(&path)).ok()
    }
}

/// 筆跡檔名 `<頁>-<裝置 8 位十六進位>.strokes` 裡的裝置 id。舊版
/// `<頁>.strokes` 沒有裝置，回 `None`。
fn ink_device_of_name(name: &str) -> Option<u32> {
    let stem = name.strip_suffix(".strokes")?;
    let (_, hex) = stem.rsplit_once('-')?;
    // 頁面 UUID 自己也有連字號，所以只認結尾剛好 8 位十六進位的。
    if hex.len() != 8 {
        return None;
    }
    u32::from_str_radix(hex, 16).ok()
}

/// 筆跡檔名的白名單：來自網路，不可信。
fn ink_name_is_safe(name: &str) -> bool {
    !name.is_empty()
        && name.ends_with(".strokes")
        && !name.contains(['/', '\\', '\0'])
        && !name.contains("..")
}

impl LanStore for PackageLanStore {
    fn focused_notebook(&self) -> Option<String> {
        self.host.focused_notebook()
    }

    fn list(&self, notebook_id: &str) -> Option<Vec<LanFile>> {
        let package = self.open(notebook_id)?;
        let mut files = Vec::new();
        for (name, size) in package.doc_op_files().ok()? {
            files.push(LanFile {
                kind: LanKind::Ops,
                name,
                size,
            });
        }
        for (name, size) in package.ink_files().ok().unwrap_or_default() {
            files.push(LanFile {
                kind: LanKind::Ink,
                name,
                size,
            });
        }
        Some(files)
    }

    fn accepts(&self, notebook_id: &str, kind: LanKind, name: &str) -> bool {
        // 自己這台寫的，本機才是權威。
        let own = match kind {
            LanKind::Ops => padnote_storage::parse_oplog_name(name).map(|(_, device)| device),
            LanKind::Ink => ink_device_of_name(name),
        };
        if own == Some(self.device_id) {
            return false;
        }
        // 被本機壓實吃掉的碎檔不再拿回來（見 sync_notebook_ops 的同一條規則）。
        if kind == LanKind::Ops
            && let Some(package) = self.open(notebook_id)
        {
            if let Some((remote_lamport, dev)) = padnote_storage::parse_oplog_name(name)
                && let Ok(files) = package.doc_op_files()
            {
                let local_max = files
                    .iter()
                    .filter_map(|(n, _)| padnote_storage::parse_oplog_name(n))
                    .filter(|(_, d)| *d == dev)
                    .map(|(l, _)| l)
                    .max()
                    .unwrap_or(0);
                let local_size = files
                    .iter()
                    .find(|(n, _)| *n == name)
                    .map(|(_, s)| *s)
                    .unwrap_or(0);
                if remote_lamport <= local_max && local_size == 0 {
                    return false;
                }
            }
            if let Ok(text) =
                std::fs::read_to_string(package.root().join("doc/ops/compaction.tombstones"))
            {
                let key = padnote_sync::paths::canonical_name(name);
                if text
                    .lines()
                    .any(|line| padnote_sync::paths::canonical_name(line.trim()) == key)
                {
                    return false;
                }
            }
        }
        true
    }

    fn read(&self, notebook_id: &str, kind: LanKind, name: &str) -> Option<Vec<u8>> {
        let package = self.open(notebook_id)?;
        match kind {
            LanKind::Ops => package.read_doc_op_file(name).ok(),
            LanKind::Ink if ink_name_is_safe(name) => package.read_ink_file(name).ok(),
            LanKind::Ink => None,
        }
    }

    fn write(&self, notebook_id: &str, kind: LanKind, name: &str, bytes: &[u8]) -> bool {
        let Some(package) = self.open(notebook_id) else {
            return false;
        };
        // 只收比本機長的：append-only ⇒ 較長者是超集。這裡再驗一次 ——
        // 「要」與「收」之間本機可能已經寫了東西（自己那台的編輯器、Drive 下載）。
        let local = match kind {
            LanKind::Ops => package
                .doc_op_files()
                .ok()
                .and_then(|f| f.into_iter().find(|(n, _)| n == name).map(|(_, s)| s)),
            LanKind::Ink => package
                .ink_files()
                .ok()
                .and_then(|f| f.into_iter().find(|(n, _)| n == name).map(|(_, s)| s)),
        }
        .unwrap_or(0);
        if bytes.len() as u64 <= local {
            return false;
        }
        match kind {
            LanKind::Ops => package.write_doc_op_file(name, bytes).is_ok(),
            LanKind::Ink if ink_name_is_safe(name) => package.write_ink_file(name, bytes).is_ok(),
            LanKind::Ink => false,
        }
    }

    fn on_received(&self, notebook_id: &str, files: u32) {
        self.host.on_received(notebook_id.to_string(), files);
    }

    fn on_peers_changed(&self, count: u32) {
        self.host.on_peers_changed(count);
    }
}

/// 區網節點。整個 App 共用一個；登入 Google 之後拿到區網金鑰才建立。
#[derive(Debug, uniffi::Object)]
pub struct FfiLanNode {
    node: LanNode,
}

#[uniffi::export]
impl FfiLanNode {
    /// 開始監聽。平台要把 [`Self::port`] 與 [`Self::tag_hex`]、
    /// 裝置 id 註冊到 Bonjour / NSD。
    #[uniffi::constructor]
    pub fn start(
        key: Vec<u8>,
        device_id: u32,
        host: Arc<dyn FfiLanHost>,
    ) -> Result<Arc<Self>, FfiLanError> {
        let key: [u8; 32] = key.try_into().map_err(|_| FfiLanError::BadKey)?;
        let store = Arc::new(PackageLanStore { host, device_id });
        let node = LanNode::start(key, device_id, store).map_err(|e| FfiLanError::Start {
            detail: e.to_string(),
        })?;
        Ok(Arc::new(Self { node }))
    }

    pub fn port(&self) -> u16 {
        self.node.port()
    }

    /// 金鑰標籤（十六進位）。放進廣播的 TXT 記錄，讓別的帳號的裝置在發現階段就略過。
    pub fn tag_hex(&self) -> String {
        self.node.tag_hex()
    }

    /// 平台發現了一台裝置。**可以重複呼叫** —— 已連線或該由對方主動連的會直接略過。
    pub fn connect(&self, peer_device: u32, host: String, port: u16) {
        self.node.connect(peer_device, &host, port);
    }

    /// 這本筆記本剛存檔（並匯出進套件）—— 告訴所有對端。
    pub fn announce(&self, notebook_id: String) {
        self.node.announce(&notebook_id);
    }

    pub fn peer_count(&self) -> u32 {
        self.node.peer_count()
    }

    pub fn stop(&self) {
        self.node.stop();
    }
}

/// 某個發現到的對端該不該由我主動連。
#[uniffi::export]
pub fn lan_should_initiate(my_device: u32, peer_device: u32) -> bool {
    padnote_sync::lan::should_initiate(my_device, peer_device)
}

/// 區網服務在 Bonjour / NSD 的類型（`_kairumo-sync._tcp`）。
#[uniffi::export]
pub fn lan_service_type() -> String {
    "_kairumo-sync._tcp".to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ink_device_is_read_from_the_last_eight_hex_digits() {
        assert_eq!(
            ink_device_of_name("0e0b8bd2-3f2a-4b9e-9c11-aabbccddeeff-0000002a.strokes"),
            Some(0x2a)
        );
        // 舊版沒有裝置：頁面 UUID 的最後一段是 12 位，不是 8 位。
        assert_eq!(
            ink_device_of_name("0e0b8bd2-3f2a-4b9e-9c11-aabbccddeeff.strokes"),
            None
        );
    }

    #[test]
    fn ink_names_from_the_network_are_whitelisted() {
        assert!(ink_name_is_safe("page-0000002a.strokes"));
        assert!(!ink_name_is_safe("../page.strokes"));
        assert!(!ink_name_is_safe("a/b.strokes"));
        assert!(!ink_name_is_safe("page.oplog"));
        assert!(!ink_name_is_safe(""));
    }

    #[test]
    fn a_short_key_is_rejected() {
        struct Nobody;
        impl FfiLanHost for Nobody {
            fn focused_notebook(&self) -> Option<String> {
                None
            }
            fn package_path(&self, _: String) -> Option<String> {
                None
            }
            fn on_received(&self, _: String, _: u32) {}
            fn on_peers_changed(&self, _: u32) {}
        }
        assert!(matches!(
            FfiLanNode::start(vec![1, 2, 3], 1, Arc::new(Nobody)),
            Err(FfiLanError::BadKey)
        ));
    }

    #[test]
    fn notebook_locks_are_exclusive_per_notebook() {
        let first = notebook_lock_try_enter("focus-test-nb".into(), "focus".into(), 0);
        assert!(first.granted);
        let second = notebook_lock_try_enter("FOCUS-TEST-NB".into(), "full".into(), 5);
        assert!(!second.granted);
        assert_eq!(second.holder, "focus");
        assert!(notebook_lock_leave("focus-test-nb".into(), first.ticket));
        assert!(notebook_lock_try_enter("focus-test-nb".into(), "full".into(), 10).granted);
        // 收尾：不留鎖給別的測試。
        let held = notebook_lock_try_enter("other-nb".into(), "x".into(), 0);
        assert!(held.granted);
        notebook_lock_leave("other-nb".into(), held.ticket);
    }

    #[test]
    fn the_lane_facade_round_trips() {
        let lane = FfiFocusLane::create();
        lane.set_focus(Some("nb".into()), 0);
        let run = lane.poll(0).expect("剛聚焦就拉");
        assert!(!run.push);
        lane.finish(run.notebook_id, FfiFocusOutcome::Pulled, 10);
        assert_eq!(
            lane.next_due_in_ms(10),
            padnote_sync::focus::FOCUS_ACTIVE_POLL_MS
        );
    }
}
