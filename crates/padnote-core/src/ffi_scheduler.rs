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

    /// 距離下一次起跑還有多久。`u64::MAX` 表示沒有待辦。
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

    /// 停在「要重新登入」。介面應該顯示登入提示，而不是「同步失敗」。
    pub fn is_blocked_on_auth(&self) -> bool {
        self.inner.lock().unwrap().is_blocked_on_auth()
    }
}

/// 前景心跳的建議間隔（毫秒）。平台層照這個值設計時器。
#[uniffi::export]
pub fn sync_periodic_interval_ms() -> u64 {
    padnote_sync::scheduler::PERIODIC_MS
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
