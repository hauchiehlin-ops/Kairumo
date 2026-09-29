//! **焦點通道**的排程策略（秒同步）。
//!
//! # 為什麼需要第二條通道
//!
//! [`crate::scheduler`] 排的是**整庫一輪**：匯出每一本、`changes.list`、
//! 中繼資料、逐本同步、匯入回工作副本、垃圾回收。那是正確的維護流程，
//! 但它的成本跟筆記本數量成正比、而且一輪跑完才能跑下一輪。
//! 使用者改一個字，要等的是「去抖動 + 輪詢週期 + **整庫這一整輪**」。
//! 把週期調短只會讓整輪更頻繁地空跑，不會讓那一個字更快到。
//!
//! 使用者感受到「同步慢」的場景，幾乎都是**兩台裝置同時開著同一本筆記**。
//! 所以另開一條窄通道，只服務「現在開著的那一本」：
//!
//! * 寫入之後 [`FOCUS_DEBOUNCE_MS`] 就推，不等整庫；
//! * 每 [`FOCUS_POLL_MS`] 問一次雲端（一個 `changes.list` 請求），
//!   有變就只拉這一本；
//! * 其他筆記本仍由整庫那條通道照原節奏處理。
//!
//! 兩條通道共用同一份雲端快照與同一份資料格式，**不共用任何排程狀態**，
//! 互相只靠核心的「每本筆記本一把鎖」避免同時動同一個套件。
//!
//! # 這裡只有純邏輯
//!
//! 沒有時鐘、沒有執行緒、沒有 I/O —— 全部由呼叫端餵時間（單調時鐘），
//! 所以每個時間相依的行為都測得到。

/// 本機寫入之後等多久才推。
///
/// 比整庫通道的 1000ms 短：焦點通道一輪很便宜（一本、只傳差異），
/// 提早推的代價很小；而使用者停手之後的那一秒正是他切去看另一台的時候。
pub const FOCUS_DEBOUNCE_MS: u64 = 250;

/// 連續書寫時**最久**多久一定要推一次。
///
/// 純去抖動有個缺點：使用者一直不停手，就一直不推 —— 另一台看著空白的頁面
/// 等他寫完一整段。上限讓「邊寫邊看」也成立。
pub const FOCUS_MAX_HOLD_MS: u64 = 1_500;

/// 焦點筆記本多久問一次雲端。
///
/// Drive 的 `changes.list` 沒有變動就是空回應，一次幾十到幾百毫秒；
/// 每分鐘 60 次遠低於配額（每使用者每 100 秒 20,000 次）。
pub const FOCUS_POLL_MS: u64 = 1_000;

/// 剛拉到對方的東西之後的輪詢間隔（對方正在寫）。
pub const FOCUS_ACTIVE_POLL_MS: u64 = 700;

/// 距離上次拉到對方的東西多久之內算「對方正在寫」。
pub const FOCUS_ACTIVE_WINDOW_MS: u64 = 30_000;

/// 焦點通道失敗退避的起點與上限。
///
/// 上限只有 15 秒：焦點通道是使用者正看著的東西，退避到一分鐘
/// 就等於「壞了」；而整庫通道自己有一分鐘的退避，兩者互補。
pub const FOCUS_BACKOFF_MIN_MS: u64 = 1_000;
pub const FOCUS_BACKOFF_MAX_MS: u64 = 15_000;

/// **對使用者的承諾**（Drive 路徑）：A 寫完，B 最久多久看得到，
/// 不含網路時間與 Drive 自己的傳播延遲。
///
/// 去抖動 + 一次輪詢。網路時間不算在內，那不是排程器決定得了的。
pub const fn worst_case_visible_latency_ms() -> u64 {
    FOCUS_DEBOUNCE_MS + FOCUS_POLL_MS
}

/// 一輪焦點同步的結果。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FocusOutcome {
    /// 成功。`pulled` 表示這一輪拉到了對方的東西。
    Success { pulled: bool },
    /// 網路不通、5xx、逾時 —— 短退避後重試。
    Transient,
    /// 權杖失效 —— 停下來，等整庫通道或使用者處理登入。
    NeedsReauth,
    /// 這本筆記本正被另一條通道處理（鎖沒拿到）。不算失敗、不退避，
    /// 稍後再問即可。
    Busy,
}

/// 這一輪要做什麼。
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct FocusRun {
    pub notebook_id: String,
    /// 本機有還沒推的寫入 —— 平台要先把工作副本匯出進套件。
    /// `false` 時只是輪詢，匯出可以整段跳過。
    pub push: bool,
}

/// 焦點通道排程器。
#[derive(Clone, Debug, Default)]
pub struct FocusLane {
    notebook: Option<String>,
    /// 有寫入還沒推。
    dirty: bool,
    /// 目前這批寫入最早的時間（[`FOCUS_MAX_HOLD_MS`] 的起點）。
    dirty_since: Option<u64>,
    /// 最近一次寫入的時間（[`FOCUS_DEBOUNCE_MS`] 的起點）。
    last_edit: u64,
    /// 下一次輪詢的時間點。
    next_poll: u64,
    running: bool,
    /// 目前這一輪是不是帶著要推的寫入。失敗時只有它為 true 才把 `dirty` 補回去，
    /// 否則一次純輪詢的失敗會憑空多出一次匯出。
    running_push: bool,
    /// 退避期間：在這個時間點之前，推與拉都不起跑。
    hold_until: u64,
    failures: u32,
    blocked_on_auth: bool,
    last_remote_change: Option<u64>,
}

impl FocusLane {
    pub fn new() -> Self {
        Self::default()
    }

    /// 現在關注哪一本。`None` = 沒有開著的筆記本（回到首頁）。
    ///
    /// 換到新的一本會**立刻**排一次拉取：使用者剛打開它，
    /// 第一件事就是看到對方最新的內容。
    pub fn set_focus(&mut self, notebook_id: Option<&str>, now_ms: u64) {
        if self.notebook.as_deref() == notebook_id {
            return;
        }
        self.notebook = notebook_id.map(str::to_string);
        self.dirty = false;
        self.dirty_since = None;
        self.failures = 0;
        self.hold_until = 0;
        self.next_poll = now_ms;
    }

    pub fn focused(&self) -> Option<&str> {
        self.notebook.as_deref()
    }

    /// 焦點筆記本有本機寫入（存檔完成之後呼叫）。
    pub fn note_local_edit(&mut self, now_ms: u64) {
        if self.notebook.is_none() {
            return;
        }
        self.dirty = true;
        self.dirty_since.get_or_insert(now_ms);
        self.last_edit = now_ms;
    }

    /// 有跡象顯示雲端／對方剛動過（區網對端通知、App 進前景……）。
    /// 立刻排一次拉取，不等下一個輪詢週期。
    pub fn note_remote_hint(&mut self, now_ms: u64) {
        if self.notebook.is_some() {
            self.next_poll = self.next_poll.min(now_ms);
        }
    }

    /// 重新登入了。
    pub fn note_signed_in(&mut self, now_ms: u64) {
        self.blocked_on_auth = false;
        self.failures = 0;
        self.hold_until = 0;
        self.next_poll = now_ms;
    }

    /// 現在該不該跑一輪。回 `Some` 時呼叫端要開跑，結束時呼叫 [`Self::finish`]。
    pub fn poll(&mut self, now_ms: u64) -> Option<FocusRun> {
        if self.running || self.blocked_on_auth || now_ms < self.hold_until {
            return None;
        }
        let notebook = self.notebook.clone()?;
        let push_due = self.dirty && now_ms >= self.push_due_at();
        let poll_due = now_ms >= self.next_poll;
        if !push_due && !poll_due {
            return None;
        }
        self.running = true;
        // 在**起跑時**清掉，而不是結束時：跑的途中又來的寫入
        // 會重新設成 dirty，下一輪接著推。結束時才清的話會把它吃掉。
        let push = self.dirty;
        self.running_push = push;
        if push {
            self.dirty = false;
            self.dirty_since = None;
        }
        Some(FocusRun {
            notebook_id: notebook,
            push,
        })
    }

    /// 一輪跑完。`notebook_id` 是這一輪處理的那一本 ——
    /// 跑的途中使用者切到別本的話，結果不該套用在新的那一本身上。
    pub fn finish(&mut self, notebook_id: &str, outcome: FocusOutcome, now_ms: u64) {
        self.running = false;
        if self.notebook.as_deref() != Some(notebook_id) {
            // 已經換焦點了：這一輪的結論作廢，新的那一本有自己的 `next_poll`。
            return;
        }
        match outcome {
            FocusOutcome::Success { pulled } => {
                self.failures = 0;
                self.hold_until = 0;
                if pulled {
                    self.last_remote_change = Some(now_ms);
                }
                self.next_poll = now_ms + self.poll_interval_ms(now_ms);
            }
            FocusOutcome::Busy => {
                // 另一條通道正在處理它。很快再問，不退避 —— 那不是錯誤。
                self.hold_until = now_ms + FOCUS_DEBOUNCE_MS;
                self.next_poll = self.hold_until;
                self.restore_unpushed(now_ms);
            }
            FocusOutcome::Transient => {
                self.failures = self.failures.saturating_add(1);
                self.hold_until = now_ms + self.backoff_ms();
                self.next_poll = self.hold_until;
                self.restore_unpushed(now_ms);
            }
            FocusOutcome::NeedsReauth => {
                self.blocked_on_auth = true;
                self.restore_unpushed(now_ms);
            }
        }
    }

    /// 距離下一次該起跑還有多久（毫秒）。`None` = 沒有待辦（沒焦點、
    /// 正在跑、或等著登入）。平台拿它設計時器。
    pub fn next_due_in_ms(&self, now_ms: u64) -> Option<u64> {
        if self.notebook.is_none() || self.running || self.blocked_on_auth {
            return None;
        }
        let mut due = self.next_poll;
        if self.dirty {
            due = due.min(self.push_due_at());
        }
        Some(due.max(self.hold_until).saturating_sub(now_ms))
    }

    pub fn is_running(&self) -> bool {
        self.running
    }

    pub fn is_blocked_on_auth(&self) -> bool {
        self.blocked_on_auth
    }

    pub fn has_unpushed_edits(&self) -> bool {
        self.dirty
    }

    /// 現在的輪詢間隔。
    pub fn poll_interval_ms(&self, now_ms: u64) -> u64 {
        match self.last_remote_change {
            Some(t) if now_ms.saturating_sub(t) <= FOCUS_ACTIVE_WINDOW_MS => FOCUS_ACTIVE_POLL_MS,
            _ => FOCUS_POLL_MS,
        }
    }

    /// 這一輪沒推成功（失敗、或鎖被佔著）：寫入還在，要保留。
    /// `poll` 起跑時已經清了 `dirty`，所以這裡補回來。
    fn restore_unpushed(&mut self, now_ms: u64) {
        if self.running_push {
            self.dirty = true;
            self.dirty_since.get_or_insert(now_ms);
            self.last_edit = self.last_edit.max(now_ms);
        }
    }

    /// 寫入最晚在什麼時候一定要推：去抖動與最長持有，取較早的。
    fn push_due_at(&self) -> u64 {
        let debounce = self.last_edit + FOCUS_DEBOUNCE_MS;
        match self.dirty_since {
            Some(since) => debounce.min(since + FOCUS_MAX_HOLD_MS),
            None => debounce,
        }
    }

    fn backoff_ms(&self) -> u64 {
        let shift = self.failures.saturating_sub(1).min(16);
        FOCUS_BACKOFF_MIN_MS
            .saturating_mul(1u64 << shift)
            .min(FOCUS_BACKOFF_MAX_MS)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn focused(now: u64) -> FocusLane {
        let mut lane = FocusLane::new();
        lane.set_focus(Some("nb"), now);
        lane
    }

    #[test]
    fn no_focus_means_no_work() {
        let mut lane = FocusLane::new();
        lane.note_local_edit(0);
        lane.note_remote_hint(0);
        assert_eq!(lane.poll(10_000), None);
        assert_eq!(lane.next_due_in_ms(0), None);
    }

    #[test]
    fn focusing_a_notebook_pulls_immediately() {
        let mut lane = FocusLane::new();
        lane.set_focus(Some("nb"), 5_000);
        let run = lane.poll(5_000).expect("剛打開就要拉一次");
        assert_eq!(run.notebook_id, "nb");
        assert!(!run.push, "沒有本機寫入，只是輪詢");
    }

    #[test]
    fn refocusing_the_same_notebook_does_not_reset_the_schedule() {
        let mut lane = focused(0);
        let run = lane.poll(0).unwrap();
        lane.finish(
            &run.notebook_id,
            FocusOutcome::Success { pulled: false },
            100,
        );
        lane.set_focus(Some("nb"), 200);
        assert_eq!(lane.poll(200), None, "同一本重設焦點不該多拉一次");
    }

    #[test]
    fn a_local_edit_is_pushed_after_the_debounce() {
        let mut lane = focused(0);
        let run = lane.poll(0).unwrap();
        // 下一次輪詢在 1_900，所以 1_000 附近醒來的只可能是「推」。
        lane.finish(
            &run.notebook_id,
            FocusOutcome::Success { pulled: false },
            900,
        );
        lane.note_local_edit(1_000);
        assert_eq!(lane.poll(1_000 + FOCUS_DEBOUNCE_MS - 1), None);
        let run = lane.poll(1_000 + FOCUS_DEBOUNCE_MS).expect("去抖動到了");
        assert!(run.push);
    }

    #[test]
    fn continuous_writing_is_still_pushed_at_the_max_hold() {
        let mut lane = focused(0);
        let run = lane.poll(0).unwrap();
        lane.finish(
            &run.notebook_id,
            FocusOutcome::Success { pulled: false },
            10,
        );
        // 每 100ms 一筆，永遠等不到 250ms 的停手。
        let mut pushed_at = None;
        for step in 0..40u64 {
            let t = 1_000 + step * 100;
            lane.note_local_edit(t);
            if let Some(run) = lane.poll(t) {
                if run.push {
                    pushed_at = Some(t);
                    break;
                }
                lane.finish(&run.notebook_id, FocusOutcome::Success { pulled: false }, t);
            }
        }
        let pushed_at = pushed_at.expect("不停手也要推");
        assert!(pushed_at - 1_000 <= FOCUS_MAX_HOLD_MS);
    }

    #[test]
    fn an_edit_during_a_run_is_pushed_by_the_next_run() {
        let mut lane = focused(0);
        lane.note_local_edit(0);
        let run = lane.poll(FOCUS_DEBOUNCE_MS).unwrap();
        assert!(run.push);
        // 跑的途中又寫了一筆。
        lane.note_local_edit(FOCUS_DEBOUNCE_MS + 10);
        lane.finish(
            &run.notebook_id,
            FocusOutcome::Success { pulled: false },
            FOCUS_DEBOUNCE_MS + 50,
        );
        assert!(lane.has_unpushed_edits(), "跑的途中的寫入不能被吃掉");
        let next = lane
            .poll(FOCUS_DEBOUNCE_MS + 10 + FOCUS_DEBOUNCE_MS)
            .expect("下一輪接著推");
        assert!(next.push);
    }

    #[test]
    fn polls_at_the_focus_interval_when_quiet() {
        let mut lane = focused(0);
        let run = lane.poll(0).unwrap();
        lane.finish(
            &run.notebook_id,
            FocusOutcome::Success { pulled: false },
            100,
        );
        assert_eq!(lane.poll(100 + FOCUS_POLL_MS - 1), None);
        assert!(lane.poll(100 + FOCUS_POLL_MS).is_some());
    }

    #[test]
    fn pulling_something_switches_to_the_faster_interval_for_a_while() {
        let mut lane = focused(0);
        let run = lane.poll(0).unwrap();
        lane.finish(
            &run.notebook_id,
            FocusOutcome::Success { pulled: true },
            100,
        );
        assert_eq!(lane.poll_interval_ms(100), FOCUS_ACTIVE_POLL_MS);
        assert!(lane.poll(100 + FOCUS_ACTIVE_POLL_MS).is_some());
        // 一段時間沒有動靜就回到基準。
        assert_eq!(
            lane.poll_interval_ms(100 + FOCUS_ACTIVE_WINDOW_MS + 1),
            FOCUS_POLL_MS
        );
    }

    #[test]
    fn an_empty_round_does_not_count_as_the_other_side_writing() {
        let mut lane = focused(0);
        for i in 0..5u64 {
            let t = i * 2_000;
            let run = lane.poll(t).unwrap();
            lane.finish(&run.notebook_id, FocusOutcome::Success { pulled: false }, t);
        }
        assert_eq!(lane.poll_interval_ms(10_000), FOCUS_POLL_MS);
    }

    #[test]
    fn a_remote_hint_skips_the_wait() {
        let mut lane = focused(0);
        let run = lane.poll(0).unwrap();
        lane.finish(
            &run.notebook_id,
            FocusOutcome::Success { pulled: false },
            100,
        );
        assert_eq!(lane.poll(200), None);
        lane.note_remote_hint(200);
        assert!(lane.poll(200).is_some(), "對端通知不必等輪詢週期");
    }

    #[test]
    fn failures_back_off_but_keep_the_unpushed_edit() {
        let mut lane = focused(0);
        lane.note_local_edit(0);
        let run = lane.poll(FOCUS_DEBOUNCE_MS).unwrap();
        assert!(run.push);
        lane.finish(&run.notebook_id, FocusOutcome::Transient, 300);
        assert!(lane.has_unpushed_edits(), "推失敗了，寫入還在");
        assert_eq!(lane.poll(300 + FOCUS_BACKOFF_MIN_MS - 1), None);
        assert!(
            lane.poll(300 + FOCUS_BACKOFF_MIN_MS + FOCUS_DEBOUNCE_MS)
                .is_some()
        );
    }

    #[test]
    fn backoff_doubles_and_is_capped() {
        let mut lane = focused(0);
        let mut now = 0u64;
        let mut last = 0u64;
        for _ in 0..12 {
            let run = lane.poll(now).unwrap();
            lane.finish(&run.notebook_id, FocusOutcome::Transient, now);
            let due = lane.next_due_in_ms(now).unwrap();
            assert!(due >= last.min(FOCUS_BACKOFF_MAX_MS));
            assert!(due <= FOCUS_BACKOFF_MAX_MS);
            last = due;
            now += due;
        }
        assert_eq!(last, FOCUS_BACKOFF_MAX_MS);
    }

    #[test]
    fn success_resets_the_backoff() {
        let mut lane = focused(0);
        for i in 0..4u64 {
            let t = i * 20_000;
            let run = lane.poll(t).unwrap();
            lane.finish(&run.notebook_id, FocusOutcome::Transient, t);
        }
        let t = 100_000;
        let run = lane.poll(t).unwrap();
        lane.finish(&run.notebook_id, FocusOutcome::Success { pulled: false }, t);
        assert_eq!(lane.next_due_in_ms(t), Some(FOCUS_POLL_MS));
    }

    #[test]
    fn busy_is_not_a_failure() {
        let mut lane = focused(0);
        let run = lane.poll(0).unwrap();
        lane.finish(&run.notebook_id, FocusOutcome::Busy, 10);
        assert_eq!(lane.next_due_in_ms(10), Some(FOCUS_DEBOUNCE_MS));
        assert!(!lane.is_blocked_on_auth());
    }

    #[test]
    fn needs_reauth_stops_the_lane_until_signed_in() {
        let mut lane = focused(0);
        let run = lane.poll(0).unwrap();
        lane.finish(&run.notebook_id, FocusOutcome::NeedsReauth, 10);
        assert!(lane.is_blocked_on_auth());
        lane.note_local_edit(20);
        assert_eq!(lane.poll(100_000), None, "死權杖不重試");
        lane.note_signed_in(100_000);
        let run = lane.poll(100_000).expect("登入後立刻恢復");
        assert!(run.push, "等待期間的寫入沒有丟");
    }

    #[test]
    fn a_result_for_the_previous_notebook_is_discarded() {
        let mut lane = focused(0);
        let run = lane.poll(0).unwrap();
        // 跑的途中切到別本。
        lane.set_focus(Some("other"), 50);
        lane.finish(&run.notebook_id, FocusOutcome::Transient, 60);
        // 新的一本不該繼承舊的一本的退避。
        let next = lane.poll(60).expect("新焦點立刻拉");
        assert_eq!(next.notebook_id, "other");
    }

    #[test]
    fn leaving_the_notebook_stops_everything() {
        let mut lane = focused(0);
        lane.note_local_edit(0);
        lane.set_focus(None, 10);
        assert_eq!(lane.poll(10_000), None);
        assert_eq!(lane.next_due_in_ms(10_000), None);
    }

    #[test]
    fn the_promise_is_under_two_seconds() {
        // 不含網路時間。改動任何常數時這條會提醒：承諾是給使用者的。
        assert!(worst_case_visible_latency_ms() <= 2_000);
    }
}
