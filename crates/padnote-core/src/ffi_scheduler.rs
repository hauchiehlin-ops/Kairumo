//! 同步排程器的平台介面（P2）。
//!
//! 策略全部在 [`padnote_sync::scheduler`]，這裡只是一層帶鎖的門面。
//! 兩個平台共用同一個物件 ⇒ **節奏一定一樣**。各寫一份的話，
//! 使用者看到的不是「排程策略不同」，是「Android 比較慢」。
//!
//! 平台層要做的只有三件事：
//!
//! 1. 發生事情時呼叫 [`FfiSyncScheduler::request`]（進前景、存檔、
//!    網路恢復、登入完成、按下立即同步）。
//! 2. 計時器或背景任務醒來時呼叫 [`FfiSyncScheduler::tick`]，
//!    接著問 [`FfiSyncScheduler::should_start`]。
//! 3. 跑完一輪呼叫 [`FfiSyncScheduler::finish`]。

use std::sync::{Arc, Mutex};

use padnote_sync::scheduler::{SyncOutcome, SyncScheduler, SyncTrigger};

/// 觸發同步的事件。
#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum FfiSyncTrigger {
    /// 使用者按了「立即同步」。
    Manual,
    /// App 進到前景。
    Foreground,
    /// 登入完成。
    SignedIn,
    /// 網路恢復。
    NetworkRegained,
    /// 本機存檔。**會去抖動**，不會每一筆都推。
    LocalEdit,
    /// 前景週期。
    Periodic,
    /// 背景任務叫醒。
    Background,
}

impl From<FfiSyncTrigger> for SyncTrigger {
    fn from(t: FfiSyncTrigger) -> Self {
        match t {
            FfiSyncTrigger::Manual => Self::Manual,
            FfiSyncTrigger::Foreground => Self::Foreground,
            FfiSyncTrigger::SignedIn => Self::SignedIn,
            FfiSyncTrigger::NetworkRegained => Self::NetworkRegained,
            FfiSyncTrigger::LocalEdit => Self::LocalEdit,
            FfiSyncTrigger::Periodic => Self::Periodic,
            FfiSyncTrigger::Background => Self::Background,
        }
    }
}

/// 一輪同步的結果。
#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum FfiSyncOutcome {
    Success,
    /// 網路不通、5xx、逾時 —— 退避後重試。
    Transient,
    /// 權杖失效 —— 停下來等使用者重新登入。
    NeedsReauth,
}

impl From<FfiSyncOutcome> for SyncOutcome {
    fn from(o: FfiSyncOutcome) -> Self {
        match o {
            FfiSyncOutcome::Success => Self::Success,
            FfiSyncOutcome::Transient => Self::Transient,
            FfiSyncOutcome::NeedsReauth => Self::NeedsReauth,
        }
    }
}

/// 排程器。整個 App 共用一個。
#[derive(Debug, uniffi::Object)]
pub struct FfiSyncScheduler {
    inner: Mutex<SyncScheduler>,
}

#[uniffi::export]
impl FfiSyncScheduler {
    #[uniffi::constructor]
    pub fn create() -> Arc<Self> {
        Arc::new(Self {
            inner: Mutex::new(SyncScheduler::new()),
        })
    }

    /// 收到一個觸發。`now_ms` 用單調時鐘（Apple 的 `uptimeNanoseconds`、
    /// Android 的 `SystemClock.elapsedRealtime`）—— **不要用牆上時間**，
    /// 使用者改時區或系統校時會讓排程整個亂掉。
    pub fn request(&self, trigger: FfiSyncTrigger, now_ms: u64) {
        self.inner.lock().unwrap().request(trigger.into(), now_ms);
    }

    /// 計時器心跳：時間到了就自己排一輪週期性拉取。
    pub fn tick(&self, now_ms: u64) {
        self.inner.lock().unwrap().tick(now_ms);
    }

    /// 現在該不該起跑。回 true 就開始，並在結束時呼叫 [`Self::finish`]。
    pub fn should_start(&self, now_ms: u64) -> bool {
        self.inner.lock().unwrap().should_start(now_ms)
    }

    pub fn finish(&self, outcome: FfiSyncOutcome, now_ms: u64) {
        self.inner.lock().unwrap().finish(outcome.into(), now_ms);
    }

    /// 跑完一輪，並告知**這一輪有沒有變動**（上傳、下載或新增任何東西）。
    ///
    /// 週期觸發的一輪成功而且沒有變動，排程器就安靜下來、不再排週期性同步，
    /// 直到下一個事件。平台層應該用這個而不是 [`Self::finish`]。
    pub fn finish_round(&self, outcome: FfiSyncOutcome, changed: bool, now_ms: u64) {
        self.inner
            .lock()
            .unwrap()
            .finish_round(outcome.into(), changed, now_ms);
    }

    /// 這一輪**真的拉到了對方的東西**（下載數或新筆記本 > 0）。
    ///
    /// 跟 `finish(.success)` 不一樣：一輪跑完通常什麼也沒變，那是常態。
    /// 只有真的拉到東西才代表對方正在寫，而那是唯一值得把節奏加快到
    /// 三秒的時候 —— 拿「跑完一輪」當證據的話，快檔會永遠開著。
    pub fn note_remote_change(&self, now_ms: u64) {
        self.inner.lock().unwrap().note_remote_change(now_ms);
    }

    /// 現在這一刻的輪詢間隔（毫秒）。平台層不需要據此重設計時器 ——
    /// 心跳照 [`sync_heartbeat_interval_ms`] 跑，由排程器擋掉太早的那些。
    /// 這個方法是給介面顯示與測試用的。
    pub fn current_period_ms(&self, now_ms: u64) -> u64 {
        self.inner.lock().unwrap().current_period_ms(now_ms)
    }

    /// 距離下一次起跑還有多久。`u64::MAX` 表示沒有待辦。
    pub fn next_due_in_ms(&self, now_ms: u64) -> u64 {
        self.inner
            .lock()
            .unwrap()
            .next_due_in_ms(now_ms)
            .unwrap_or(u64::MAX)
    }

    /// 已休眠：安靜之後連續兩次守望掃描（8 分鐘一次）都沒有變化。
    /// 平台該停掉同步的計時器與背景排程；下一次 [`Self::request`] 會叫醒，
    /// 平台在 `request` 之後要重新啟動它們。
    pub fn is_dormant(&self) -> bool {
        self.inner.lock().unwrap().is_dormant()
    }

    pub fn is_running(&self) -> bool {
        self.inner.lock().unwrap().is_running()
    }

    /// 停在「要重新登入」。介面應該顯示登入提示，而不是「同步失敗」。
    pub fn is_blocked_on_auth(&self) -> bool {
        self.inner.lock().unwrap().is_blocked_on_auth()
    }
}

/// 基準輪詢間隔（毫秒）。這是**節奏**，不是心跳頻率 ——
/// 平台層要設計時器的話用 [`sync_heartbeat_interval_ms`]。
#[uniffi::export]
pub fn sync_periodic_interval_ms() -> u64 {
    padnote_sync::scheduler::PERIODIC_MS
}

/// 安靜之後的守望掃描間隔（毫秒，8 分鐘）。
#[uniffi::export]
pub fn sync_watch_scan_interval_ms() -> u64 {
    padnote_sync::scheduler::WATCH_SCAN_MS
}

/// 前景心跳的間隔（毫秒）。平台層照這個值設計時器。
///
/// 它等於**最快的那一檔**：心跳只是「問一下」，真正的節奏由
/// [`FfiSyncScheduler::tick`] 內部依當下狀態決定。心跳比最快檔慢的話，
/// 快檔永遠跑不出來 —— 三秒的設定會被十二秒的計時器吃掉。
#[uniffi::export]
pub fn sync_heartbeat_interval_ms() -> u64 {
    padnote_sync::scheduler::HEARTBEAT_MS
}

/// 本機存檔後的去抖動時間（毫秒）。
///
/// 測試用它確認 FFI 這一層沒有把去抖動吃掉。平台層不需要它 ——
/// 節奏是排程器的事，平台只負責「發生了什麼」與「現在該不該跑」。
#[cfg(test)]
fn sync_debounce_ms() -> u64 {
    padnote_sync::scheduler::DEBOUNCE_MS
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_ffi_layer_keeps_the_debounce() {
        let s = FfiSyncScheduler::create();
        s.request(FfiSyncTrigger::LocalEdit, 0);
        assert!(!s.should_start(100));
        assert!(s.should_start(sync_debounce_ms()));
    }

    #[test]
    fn reauth_is_visible_to_the_ui() {
        // 介面要能分辨「等一下再試」與「請去登入」——
        // 混在一起的話，使用者會盯著一句沒有用的「同步失敗」。
        let s = FfiSyncScheduler::create();
        s.request(FfiSyncTrigger::Manual, 0);
        s.should_start(0);
        s.finish(FfiSyncOutcome::NeedsReauth, 0);
        assert!(s.is_blocked_on_auth());
        s.request(FfiSyncTrigger::SignedIn, 1);
        assert!(!s.is_blocked_on_auth());
    }

    #[test]
    fn no_pending_work_reports_max() {
        let s = FfiSyncScheduler::create();
        assert_eq!(s.next_due_in_ms(0), u64::MAX);
    }
}

#[cfg(test)]
mod quiet_crosses_the_ffi {
    use super::*;

    #[test]
    fn an_unchanged_periodic_round_settles_the_scheduler_across_the_ffi() {
        // FFI 這一層漏掉 `finish_round` 的話，「沒變動就停」在兩個平台上都不存在。
        let s = FfiSyncScheduler::create();
        s.request(FfiSyncTrigger::Foreground, 0);
        assert!(s.should_start(0));
        s.finish_round(FfiSyncOutcome::Success, false, 0);
        let p = sync_periodic_interval_ms();
        s.tick(p);
        assert!(s.should_start(p));
        s.finish_round(FfiSyncOutcome::Success, false, p);
        s.tick(3 * p);
        assert_eq!(
            s.next_due_in_ms(3 * p),
            u64::MAX,
            "安靜之後還在排一分鐘週期"
        );
        s.note_remote_change(3 * p);
        s.tick(3 * p);
        assert!(s.should_start(3 * p), "收到對方的東西之後沒有重新開始");
    }

    #[test]
    fn two_empty_watch_scans_put_the_scheduler_to_sleep_across_the_ffi() {
        let s = FfiSyncScheduler::create();
        s.request(FfiSyncTrigger::Foreground, 0);
        assert!(s.should_start(0));
        s.finish_round(FfiSyncOutcome::Success, false, 0);
        let p = sync_periodic_interval_ms();
        let w = sync_watch_scan_interval_ms();
        let mut t = p;
        s.tick(t);
        assert!(s.should_start(t));
        s.finish_round(FfiSyncOutcome::Success, false, t);
        for _ in 0..2 {
            assert!(!s.is_dormant());
            t += w;
            s.tick(t);
            assert!(s.should_start(t), "守望掃描沒有排");
            s.finish_round(FfiSyncOutcome::Success, false, t);
        }
        assert!(s.is_dormant());
        s.request(FfiSyncTrigger::LocalEdit, t + 1);
        assert!(!s.is_dormant(), "事件沒有叫醒");
    }

    #[test]
    fn the_heartbeat_is_never_slower_than_the_period() {
        assert!(sync_heartbeat_interval_ms() <= sync_periodic_interval_ms());
    }
}
