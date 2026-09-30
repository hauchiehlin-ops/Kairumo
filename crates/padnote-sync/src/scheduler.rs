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
pub const DEBOUNCE_MS: u64 = 1_000;

/// 前景時多久整庫同步一次。
///
/// **一分鐘，而且只在「上一輪還有東西」時才繼續。** 以前有三檔（3 秒／12 秒／60 秒）
/// 依「有沒有人在動」自適應，實測在使用者操作後的活躍模式裡每秒一輪，
/// 每輪都要讀索引與 `changes.list` —— 在真實 Google Drive 上是持續的請求量，
/// 吃配額也吃電。現在只有一檔：60 秒。
///
/// 開著的那一本另有焦點通道與區網直連（秒同步），不靠這一檔。
pub const PERIODIC_MS: u64 = 60_000;

/// **安靜之後的守望掃描間隔**：8 分鐘。
///
/// 週期同步發現沒有變動而安靜下來之後，程式只要還在運行（前景或背景），
/// 每 8 分鐘掃一次（索引 + `changes.list`，就是一輪整庫同步；沒有變動時
/// 那只是兩三個請求），有變化就重新開始週期同步。**連續兩次掃描都沒有變化**
/// 就進入休眠（[`SyncScheduler::is_dormant`]）：平台停掉同步的計時器與背景排程，
/// 直到下一個事件（進前景、存檔、登入、網路恢復、手動、別的通道收到東西）才重新啟動。
pub const WATCH_SCAN_MS: u64 = 8 * 60_000;

/// 前景心跳的間隔。**心跳只是「問一下」，不是輪詢頻率** ——
/// 真正的節奏是 [`PERIODIC_MS`]，由 [`SyncScheduler::tick`] 擋掉太早的那些。
/// 心跳夠密才不會讓 60 秒的週期實際變成 60～120 秒。
pub const HEARTBEAT_MS: u64 = 5_000;

/// **對使用者的承諾**：整庫那條通道上，一邊寫完，另一邊最久多久看得到（毫秒）。
///
/// 去抖動 + 一個週期 + 一個心跳的抖動。開著的那一本走焦點通道，
/// 不受這個數字限制。
pub const VISIBLE_LATENCY_BUDGET_MS: u64 = 70_000;

/// 最壞情況下，A 寫完到 B（整庫通道）看得見要多久。
///
/// 網路時間不算在內，那不是排程器決定得了的。
pub const fn worst_case_visible_latency_ms() -> u64 {
    DEBOUNCE_MS + PERIODIC_MS + HEARTBEAT_MS
}

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
    /// **已安靜下來**：一輪由週期觸發的同步發現與上一輪相比沒有任何變動。
    /// 之後不再排週期性同步，直到有事件（進前景、存檔、登入、網路恢復、
    /// 手動、背景喚醒、別的通道收到對方的東西）才重新開始。
    settled: bool,
    /// 安靜之後，連續沒有變化的守望掃描次數（[`WATCH_SCAN_MS`]）。
    quiet_scans: u32,
    /// **休眠**：連續兩次守望掃描都沒有變化。不再排任何週期同步，
    /// 平台可以停掉計時器與背景排程；下一個事件就會叫醒。
    dormant: bool,
    /// 目前排著的那一輪是不是**只**由週期觸發。只有這種輪才有資格讓排程器安靜下來 ——
    /// 開機、存檔那一輪本來就該跑，它沒有變動不代表「跟上一分鐘相比沒有變動」。
    pending_periodic: bool,
    /// 正在跑的這一輪是不是週期觸發（起跑時從 `pending_periodic` 帶過來）。
    running_periodic: bool,
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
            settled: false,
            quiet_scans: 0,
            dormant: false,
            pending_periodic: false,
            running_periodic: false,
        }
    }

    /// 回到活躍：清掉「安靜」與「休眠」。任何事件都走這裡。
    fn wake(&mut self) {
        self.settled = false;
        self.quiet_scans = 0;
        self.dormant = false;
    }

    /// 別的通道（焦點通道、區網直連）**真的收到了對方的東西**。
    ///
    /// 對方在動，整庫這條通道也該重新開始週期性同步 ——
    /// 不然其他筆記本的變動會一直等到下一個事件。
    pub fn note_remote_change(&mut self, _now_ms: u64) {
        self.wake();
    }

    /// 現在的間隔：活躍時 [`PERIODIC_MS`]，安靜之後 [`WATCH_SCAN_MS`]。
    pub fn current_period_ms(&self, _now_ms: u64) -> u64 {
        if self.settled {
            WATCH_SCAN_MS
        } else {
            PERIODIC_MS
        }
    }

    /// 已休眠：連續兩次守望掃描都沒有變化。平台該停掉計時器與背景排程，
    /// 下一個事件（`request`）會自動叫醒 —— 平台在 `request` 之後要重新啟動它們。
    pub fn is_dormant(&self) -> bool {
        self.dormant
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
        if trigger == SyncTrigger::Periodic {
            // 已經排著別的原因的話，那一輪照跑，而且不算「純週期」。
            if self.due_at.is_none() {
                self.pending_periodic = true;
            }
        } else {
            self.wake();
            self.pending_periodic = false;
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
                self.running_periodic = std::mem::take(&mut self.pending_periodic);
                true
            }
            _ => false,
        }
    }

    /// 一輪跑完了，**不知道有沒有變動**（當作有）。
    pub fn finish(&mut self, outcome: SyncOutcome, now_ms: u64) {
        self.finish_round(outcome, true, now_ms);
    }

    /// 一輪跑完了。`changed` 是這一輪有沒有上傳、下載或新增任何東西。
    ///
    /// 週期觸發的一輪成功而且沒有變動 → 安靜下來，不再排下一個週期。
    pub fn finish_round(&mut self, outcome: SyncOutcome, changed: bool, now_ms: u64) {
        self.running = false;
        self.last_finished = Some(now_ms);
        let was_periodic = std::mem::take(&mut self.running_periodic);
        match outcome {
            SyncOutcome::Success => {
                self.failures = 0;
                if changed {
                    self.wake();
                } else if was_periodic {
                    if self.settled {
                        // 又一次守望掃描，還是沒有變化。
                        self.quiet_scans += 1;
                        if self.quiet_scans >= 2 {
                            self.dormant = true;
                        }
                    } else {
                        self.settled = true;
                        self.quiet_scans = 0;
                    }
                }
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
        if self.blocked_on_auth || self.running || self.due_at.is_some() || self.dormant {
            return;
        }
        let elapsed = match self.last_finished {
            Some(last) => now_ms.saturating_sub(last),
            // 還沒跑過任何一輪：立刻排一次。
            None => u64::MAX,
        };
        if elapsed >= self.current_period_ms(now_ms) {
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
mod quiet_after_an_unchanged_minute {
    use super::*;

    fn run_round(s: &mut SyncScheduler, at: u64, changed: bool) {
        assert!(s.should_start(at), "{at} ms 時該起跑卻沒有");
        s.finish_round(SyncOutcome::Success, changed, at);
    }

    #[test]
    fn a_periodic_round_that_finds_nothing_stops_the_periodic_syncing() {
        let mut s = SyncScheduler::new();
        s.request(SyncTrigger::Foreground, 0);
        run_round(&mut s, 0, false);
        // 一分鐘後再問一次。
        s.tick(PERIODIC_MS);
        run_round(&mut s, PERIODIC_MS, false);
        // 跟上一分鐘相比沒有變動 → 安靜：一分鐘的週期停了，改成每 8 分鐘守望掃描一次。
        for k in 2..8 {
            s.tick(PERIODIC_MS + k * PERIODIC_MS);
            assert!(
                !s.should_start(PERIODIC_MS + k * PERIODIC_MS),
                "已經安靜了還在排第 {k} 個一分鐘週期"
            );
        }
    }

    #[test]
    fn a_quiet_scheduler_scans_every_eight_minutes_and_sleeps_after_two_empty_scans() {
        let mut s = SyncScheduler::new();
        s.request(SyncTrigger::Foreground, 0);
        run_round(&mut s, 0, false);
        s.tick(PERIODIC_MS);
        run_round(&mut s, PERIODIC_MS, false); // 安靜
        let mut t = PERIODIC_MS;

        // 第一次守望掃描：8 分鐘後，不早。
        s.tick(t + WATCH_SCAN_MS - 1);
        assert!(!s.has_pending(), "守望掃描提早了");
        t += WATCH_SCAN_MS;
        s.tick(t);
        run_round(&mut s, t, false);
        assert!(!s.is_dormant(), "只有一次掃描沒變化就休眠了");

        // 第二次：再 8 分鐘。連續兩次都沒變化 → 休眠。
        s.tick(t + WATCH_SCAN_MS - 1);
        assert!(!s.has_pending());
        t += WATCH_SCAN_MS;
        s.tick(t);
        run_round(&mut s, t, false);
        assert!(s.is_dormant(), "連續兩次掃描沒變化卻沒有休眠");

        // 休眠之後不再排任何同步。
        for k in 1..50 {
            s.tick(t + k * WATCH_SCAN_MS);
            assert!(!s.has_pending(), "休眠之後還在排");
        }
    }

    #[test]
    fn a_scan_that_finds_something_restarts_the_minute_cycle() {
        let mut s = SyncScheduler::new();
        s.request(SyncTrigger::Foreground, 0);
        run_round(&mut s, 0, false);
        s.tick(PERIODIC_MS);
        run_round(&mut s, PERIODIC_MS, false);
        let t = PERIODIC_MS + WATCH_SCAN_MS;
        s.tick(t);
        run_round(&mut s, t, true);
        assert!(!s.is_dormant());
        // 又回到一分鐘週期。
        s.tick(t + PERIODIC_MS);
        assert!(s.has_pending(), "掃描有變化之後沒有回到一分鐘週期");
    }

    #[test]
    fn an_event_wakes_a_dormant_scheduler() {
        let mut s = SyncScheduler::new();
        s.request(SyncTrigger::Foreground, 0);
        run_round(&mut s, 0, false);
        let mut t = 0;
        for _ in 0..3 {
            t += if t == 0 { PERIODIC_MS } else { WATCH_SCAN_MS };
            s.tick(t);
            run_round(&mut s, t, false);
        }
        assert!(s.is_dormant());
        s.request(SyncTrigger::Foreground, t + 1);
        assert!(!s.is_dormant(), "事件沒有叫醒休眠的排程器");
        assert!(s.should_start(t + 1));
    }

    #[test]
    fn the_launch_round_alone_does_not_settle_it() {
        // 開機那一輪沒變動，不代表「跟上一分鐘相比沒有變動」——
        // 還是要再看一個週期。
        let mut s = SyncScheduler::new();
        s.request(SyncTrigger::Foreground, 0);
        run_round(&mut s, 0, false);
        s.tick(PERIODIC_MS - 1);
        assert!(!s.has_pending(), "沒到一分鐘就排了");
        s.tick(PERIODIC_MS);
        assert!(s.has_pending(), "開機那一輪之後沒有再看一個週期");
    }

    #[test]
    fn a_periodic_round_that_finds_something_keeps_it_going() {
        let mut s = SyncScheduler::new();
        s.request(SyncTrigger::Foreground, 0);
        run_round(&mut s, 0, false);
        s.tick(PERIODIC_MS);
        run_round(&mut s, PERIODIC_MS, true);
        s.tick(2 * PERIODIC_MS);
        assert!(s.has_pending(), "上一輪有變動，下一分鐘還要再看");
    }

    #[test]
    fn any_event_wakes_it_up_again() {
        for trigger in [
            SyncTrigger::Foreground,
            SyncTrigger::LocalEdit,
            SyncTrigger::NetworkRegained,
            SyncTrigger::Manual,
            SyncTrigger::Background,
        ] {
            let mut s = SyncScheduler::new();
            s.request(SyncTrigger::Foreground, 0);
            run_round(&mut s, 0, false);
            s.tick(PERIODIC_MS);
            run_round(&mut s, PERIODIC_MS, false);
            let t = 10 * PERIODIC_MS;
            s.request(trigger, t);
            assert!(s.should_start(t + DEBOUNCE_MS), "{trigger:?} 沒有喚醒");
            s.finish_round(SyncOutcome::Success, false, t + DEBOUNCE_MS);
            // 事件那一輪沒變動，仍要再看一個週期才能安靜。
            s.tick(t + DEBOUNCE_MS + PERIODIC_MS);
            assert!(s.has_pending(), "{trigger:?} 之後沒有再看一個週期");
        }
    }

    #[test]
    fn a_remote_change_seen_by_another_channel_wakes_it_up() {
        let mut s = SyncScheduler::new();
        s.request(SyncTrigger::Foreground, 0);
        run_round(&mut s, 0, false);
        s.tick(PERIODIC_MS);
        run_round(&mut s, PERIODIC_MS, false);
        s.tick(5 * PERIODIC_MS);
        assert!(!s.has_pending());
        s.note_remote_change(5 * PERIODIC_MS);
        s.tick(5 * PERIODIC_MS);
        assert!(s.has_pending(), "焦點通道收到對方的東西，整庫沒有重新開始");
    }

    #[test]
    fn a_failed_round_never_settles_it() {
        let mut s = SyncScheduler::new();
        s.request(SyncTrigger::Foreground, 0);
        run_round(&mut s, 0, false);
        s.tick(PERIODIC_MS);
        assert!(s.should_start(PERIODIC_MS));
        s.finish_round(SyncOutcome::Transient, false, PERIODIC_MS);
        // 失敗要退避重試，不是「安靜」。
        assert!(s.has_pending(), "失敗之後沒有排重試");
    }

    #[test]
    fn the_heartbeat_is_much_finer_than_the_period() {
        // 心跳太慢的話，60 秒的週期會實際變成 60～120 秒。
        // 兩個都是常數：算成值再比，避免 clippy 的 `assertions_on_constants`。
        assert_eq!(
            (PERIODIC_MS / HEARTBEAT_MS).min(6),
            6,
            "心跳（{HEARTBEAT_MS}）相對週期（{PERIODIC_MS}）太粗"
        );
    }
}

#[cfg(test)]
mod tests {

    /// **「即時」要是一個數字，不是一個形容詞。**
    ///
    /// 這一項模擬兩台裝置：A 在 t=0 寫完，B 在背景定期拉。
    /// 量出「A 寫完 → B 真的拉到」的最壞時間，比對承諾。
    ///
    /// 沒有這一項的話，把 `PERIODIC_MS` 從 12 秒改成 60 秒是一行改動、
    /// CI 全綠，而「即時同步」悄悄變成「一分鐘後同步」。
    #[test]
    fn an_edit_reaches_the_other_device_inside_the_promised_budget() {
        let mut a = SyncScheduler::new();
        let mut b = SyncScheduler::new();

        // B 從 t=0 就在跑定期拉取。**要先讓它把開機那一次拉完**，
        // 否則它手上一直有一筆待辦，迴圈第一次問就說「現在就拉」——
        // 那樣量到的是 0，不管 PERIODIC_MS 設成多少都會過。
        b.tick(0);
        assert!(b.should_start(0), "開機第一次應該立刻拉");
        b.finish(SyncOutcome::Success, 0);

        // A 在 t=0 寫完。
        a.request(SyncTrigger::LocalEdit, 0);

        // A 什麼時候開始推？
        let mut push_at = None;
        for t in 0..=DEBOUNCE_MS {
            if a.should_start(t) {
                push_at = Some(t);
                break;
            }
        }
        let push_at = push_at.expect("去抖動之後一定要推出去");
        a.finish(SyncOutcome::Success, push_at);

        // B 什麼時候拉到？從 A 推上去之後算起的下一次定期拉取。
        let mut pull_at = None;
        for t in push_at..=(push_at + PERIODIC_MS + 1) {
            b.tick(t);
            if b.should_start(t) {
                pull_at = Some(t);
                break;
            }
        }
        let pull_at = pull_at.expect("定期拉取一定要發生");

        assert!(
            pull_at <= VISIBLE_LATENCY_BUDGET_MS,
            "A 寫完到 B 看得見花了 {pull_at} ms，超過承諾的 \
             {VISIBLE_LATENCY_BUDGET_MS} ms。\
             如果是刻意放寬，改 VISIBLE_LATENCY_BUDGET_MS —— \
             那一行改動就是「我們把即時的定義放寬了」。"
        );
    }

    /// 承諾與實作參數要對得起來。
    #[test]
    fn the_promise_covers_the_implementation() {
        assert!(
            worst_case_visible_latency_ms() <= VISIBLE_LATENCY_BUDGET_MS,
            "去抖動 {DEBOUNCE_MS} + 定期拉取 {PERIODIC_MS} = {} ms，\
             已經超出承諾的 {VISIBLE_LATENCY_BUDGET_MS} ms",
            worst_case_visible_latency_ms()
        );
    }
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
