//! 同步的**排程策略**（P2：即時同步）。
//!
//! # 為什麼策略要在核心
//!
//! 「什麼時候該同步」看起來像平台的事，實際上是行為規格：去抖動多久、
//! 失敗退避多久、同時只能跑幾個、暫時性錯誤與要重新登入怎麼分。
//! 兩邊各寫一份的結果一定是**同一個 App 在兩台裝置上的節奏不一樣** ——
//! 而使用者看到的不是「排程策略不同」，是「Android 比較慢」。
//!
//! 所以這裡只做純邏輯：吃「現在幾點、發生了什麼」，吐「現在該不該跑、
//! 下一次什麼時候叫我」。平台層只負責提供喚醒機制
//! （iOS 的 `BGAppRefreshTask`、Android 的 `WorkManager`、兩邊的計時器與
//! 網路狀態回呼）。
//!
//! # 為什麼不是「每 N 秒跑一次」
//!
//! 舊版根本沒有自動觸發：`runDrive` 只掛在首頁那幾顆按鈕上。
//! 而單純改成固定週期會有兩個問題：寫字的當下每秒都在推送（浪費且拖慢），
//! 以及雲端沒動靜時仍然每次付全部成本。
//!
//! 對的做法是**事件驅動 + 去抖動**：本機寫入後等使用者停手 1.5 秒才推，
//! 拉取則靠一次很便宜的 `changes.list`（P1 之後那是一個請求）。

/// 觸發同步的事件。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SyncTrigger {
    /// 使用者按了「立即同步」。永遠立刻跑。
    Manual,
    /// App 進到前景。
    Foreground,
    /// 登入完成。
    SignedIn,
    /// 網路恢復。
    NetworkRegained,
    /// 本機寫入（存檔）。**要去抖動** —— 使用者還在寫字時每一筆都推
    /// 只是浪費電，而且會拖慢正在編輯的那一本。
    LocalEdit,
    /// 前景的週期性拉取。
    Periodic,
    /// 背景任務（iOS BGTask / Android WorkManager）叫醒。
    Background,
}

impl SyncTrigger {
    /// 這個觸發要不要等去抖動。
    fn debounced(self) -> bool {
        matches!(self, Self::LocalEdit)
    }
}

/// 一輪同步的結果，決定下一次什麼時候再試。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SyncOutcome {
    Success,
    /// 網路不通、5xx、逾時 —— 重試就好。
    Transient,
    /// 權杖失效。**重試一百次也一樣**，要等使用者重新登入。
    NeedsReauth,
}

/// 本機寫入之後等多久才推送。
///
/// 太短會在使用者連續寫字時一直推；太長會讓「即時」名不副實。
/// 1.5 秒是一句話寫完的自然停頓。
pub const DEBOUNCE_MS: u64 = 1_500;

/// 前景時多久拉一次。
///
/// P1 之後這是**一個** HTTP 請求（`changes.list`），沒有變動就是空回應，
/// 所以 12 秒不貴。舊結構下這個頻率會把 Drive 的配額打爆。
pub const PERIODIC_MS: u64 = 12_000;

/// 失敗退避的起點與上限。
pub const BACKOFF_MIN_MS: u64 = 1_000;
pub const BACKOFF_MAX_MS: u64 = 60_000;

/// 同步排程器。**沒有時鐘、沒有執行緒、沒有 I/O** —— 全部由呼叫端餵時間，
/// 所以測得到（時間相依的邏輯不餵時間就只能靠 sleep 去賭）。
#[derive(Clone, Debug)]
pub struct SyncScheduler {
    /// 有一輪在跑。
    running: bool,
    /// 等著跑的最早時間點。`None` 表示沒有待辦。
    due_at: Option<u64>,
    /// 連續失敗次數，決定退避長度。
    failures: u32,
    /// 需要重新登入 —— 在使用者登入之前，除了 `Manual` 與 `SignedIn`
    /// 以外的觸發一律忽略。不擋的話，背景會一直重試一個死權杖，
    /// 而使用者只看到「同步失敗」，不知道該去登入。
    blocked_on_auth: bool,
    /// 上一次跑完的時間，週期性拉取據此計算。
    last_finished: Option<u64>,
}

impl Default for SyncScheduler {
    fn default() -> Self {
        Self::new()
    }
}

impl SyncScheduler {
    pub fn new() -> Self {
        Self {
            running: false,
            due_at: None,
            failures: 0,
            blocked_on_auth: false,
            last_finished: None,
        }
    }

    /// 收到一個觸發。
    pub fn request(&mut self, trigger: SyncTrigger, now_ms: u64) {
        if trigger == SyncTrigger::SignedIn {
            // 重新登入了 —— 解除封鎖並清掉退避。
            self.blocked_on_auth = false;
            self.failures = 0;
        }
        if self.blocked_on_auth && trigger != SyncTrigger::Manual {
            return;
        }
        let due = if trigger.debounced() {
            now_ms + DEBOUNCE_MS
        } else {
            now_ms
        };
        // **取較早的那個。** 反過來的話，使用者一直在寫字就會把
        // 「按了立即同步」無限往後推。
        self.due_at = Some(match self.due_at {
            Some(existing) => existing.min(due),
            None => due,
        });
    }

    /// 現在該不該起跑。回傳 true 時呼叫端要開始一輪，並在結束時呼叫
    /// [`Self::finish`]。
    pub fn should_start(&mut self, now_ms: u64) -> bool {
        if self.running {
            return false;
        }
        match self.due_at {
            Some(due) if due <= now_ms => {
                self.running = true;
                self.due_at = None;
                true
            }
            _ => false,
        }
    }

    /// 一輪跑完了。
    pub fn finish(&mut self, outcome: SyncOutcome, now_ms: u64) {
        self.running = false;
        self.last_finished = Some(now_ms);
        match outcome {
            SyncOutcome::Success => {
                self.failures = 0;
            }
            SyncOutcome::Transient => {
                self.failures = self.failures.saturating_add(1);
                let delay = self.backoff_ms();
                // 已經有更早的待辦就不要往後推。
                let due = now_ms + delay;
                self.due_at = Some(match self.due_at {
                    Some(existing) => existing.min(due),
                    None => due,
                });
            }
            SyncOutcome::NeedsReauth => {
                self.blocked_on_auth = true;
                self.due_at = None;
            }
        }
    }

    /// 前景的心跳。呼叫端每次計時器響就呼叫它，由排程器決定要不要排一輪。
    pub fn tick(&mut self, now_ms: u64) {
        if self.blocked_on_auth || self.running || self.due_at.is_some() {
            return;
        }
        let elapsed = match self.last_finished {
            Some(last) => now_ms.saturating_sub(last),
            // 還沒跑過任何一輪：立刻排一次。
            None => u64::MAX,
        };
        if elapsed >= PERIODIC_MS {
            self.request(SyncTrigger::Periodic, now_ms);
        }
    }

    /// 距離下一次該起跑還有多久（毫秒）。`None` 表示沒有待辦。
    ///
    /// 平台層拿它設計時器 —— 每 100ms 醒來問一次也可以，但那在 iOS 上
    /// 是白白耗電。
    pub fn next_due_in_ms(&self, now_ms: u64) -> Option<u64> {
        if self.running {
            return None;
        }
        self.due_at.map(|due| due.saturating_sub(now_ms))
    }

    pub fn is_running(&self) -> bool {
        self.running
    }

    pub fn is_blocked_on_auth(&self) -> bool {
        self.blocked_on_auth
    }

    pub fn has_pending(&self) -> bool {
        self.due_at.is_some()
    }

    fn backoff_ms(&self) -> u64 {
        let shift = self.failures.saturating_sub(1).min(16);
        BACKOFF_MIN_MS
            .saturating_mul(1u64 << shift)
            .min(BACKOFF_MAX_MS)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_manual_request_runs_immediately() {
        let mut s = SyncScheduler::new();
        s.request(SyncTrigger::Manual, 1_000);
        assert!(s.should_start(1_000));
    }

    #[test]
    fn a_local_edit_waits_for_the_user_to_stop_typing() {
        // 每一筆都推的話，正在編輯的那一本會被自己的同步拖慢。
        let mut s = SyncScheduler::new();
        s.request(SyncTrigger::LocalEdit, 0);
        assert!(!s.should_start(DEBOUNCE_MS - 1));
        assert!(s.should_start(DEBOUNCE_MS));
    }

    #[test]
    fn continuous_edits_do_not_starve_an_explicit_request() {
        // 取較早的那個。反過來的話，使用者一直在寫字就會把
        // 「按了立即同步」無限往後推。
        let mut s = SyncScheduler::new();
        s.request(SyncTrigger::LocalEdit, 0);
        s.request(SyncTrigger::Manual, 100);
        assert!(s.should_start(100), "按下去就要跑");
    }

    #[test]
    fn only_one_round_runs_at_a_time() {
        let mut s = SyncScheduler::new();
        s.request(SyncTrigger::Manual, 0);
        assert!(s.should_start(0));
        s.request(SyncTrigger::Manual, 10);
        assert!(!s.should_start(10), "還在跑就不該再起一輪");
        s.finish(SyncOutcome::Success, 20);
        assert!(s.should_start(20), "跑完之後待辦要接上");
    }

    #[test]
    fn a_transient_failure_backs_off_and_then_retries() {
        let mut s = SyncScheduler::new();
        s.request(SyncTrigger::Manual, 0);
        s.should_start(0);
        s.finish(SyncOutcome::Transient, 0);
        assert!(!s.should_start(BACKOFF_MIN_MS - 1));
        assert!(s.should_start(BACKOFF_MIN_MS));
    }

    #[test]
    fn backoff_grows_but_stops_at_the_ceiling() {
        let mut s = SyncScheduler::new();
        let mut now = 0u64;
        let mut delays = Vec::new();
        for _ in 0..12 {
            s.request(SyncTrigger::Manual, now);
            s.should_start(now);
            s.finish(SyncOutcome::Transient, now);
            let delay = s.next_due_in_ms(now).unwrap();
            delays.push(delay);
            now += delay;
            s.should_start(now);
            s.finish(SyncOutcome::Transient, now);
        }
        assert_eq!(delays[0], BACKOFF_MIN_MS);
        assert!(delays[1] > delays[0]);
        assert!(
            delays.iter().all(|d| *d <= BACKOFF_MAX_MS),
            "退避不該無限成長：{delays:?}"
        );
    }

    #[test]
    fn a_reauth_failure_stops_retrying_until_the_user_signs_in() {
        // 留著一個死權杖一直重試的話，背景會空轉，而使用者只看到
        // 「同步失敗」，不知道該去登入。
        let mut s = SyncScheduler::new();
        s.request(SyncTrigger::Manual, 0);
        s.should_start(0);
        s.finish(SyncOutcome::NeedsReauth, 0);

        s.request(SyncTrigger::Periodic, 1_000);
        s.request(SyncTrigger::LocalEdit, 2_000);
        s.tick(100_000);
        assert!(!s.should_start(100_000), "沒登入就不該一直重試");

        s.request(SyncTrigger::SignedIn, 200_000);
        assert!(s.should_start(200_000), "登入之後要接上");
    }

    #[test]
    fn a_manual_request_still_works_while_blocked_on_auth() {
        // 使用者自己按下去，就讓他得到一個明確的錯誤訊息，
        // 而不是一顆沒有反應的按鈕。
        let mut s = SyncScheduler::new();
        s.request(SyncTrigger::Manual, 0);
        s.should_start(0);
        s.finish(SyncOutcome::NeedsReauth, 0);
        s.request(SyncTrigger::Manual, 10);
        assert!(s.should_start(10));
    }

    #[test]
    fn the_periodic_tick_does_not_pile_up_rounds() {
        let mut s = SyncScheduler::new();
        s.request(SyncTrigger::Manual, 0);
        s.should_start(0);
        s.finish(SyncOutcome::Success, 0);

        s.tick(PERIODIC_MS - 1);
        assert!(!s.should_start(PERIODIC_MS - 1), "還沒到週期就不該跑");
        s.tick(PERIODIC_MS);
        assert!(s.should_start(PERIODIC_MS));
    }

    #[test]
    fn the_first_tick_syncs_straight_away() {
        // 剛開 App：不該先等一個週期才拉。
        let mut s = SyncScheduler::new();
        s.tick(0);
        assert!(s.should_start(0));
    }

    #[test]
    fn nothing_runs_without_a_trigger() {
        let mut s = SyncScheduler::new();
        assert!(!s.should_start(999_999));
        assert_eq!(s.next_due_in_ms(0), None);
    }
}
