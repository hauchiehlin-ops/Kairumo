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

/// 前景時多久拉一次（**沒有跡象顯示對方在動**時的基準）。
///
/// P1 之後這是**一個** HTTP 請求（`changes.list`），沒有變動就是空回應，
/// 所以 12 秒不貴。舊結構下這個頻率會把 Drive 的配額打爆。
pub const PERIODIC_MS: u64 = 12_000;

/// **對方正在寫**的時候多久拉一次。
///
/// # 為什麼要分快慢兩檔
///
/// 固定 12 秒的問題不是它太慢，是它**在最該快的時候也只有 12 秒**。
/// 兩個人（或同一個人的兩台裝置）正在來回改同一本筆記時，每一次
/// 都要等最多 12 秒才看得到對方 —— 那個體感就是「這個同步不是即時的」。
///
/// 反過來，三小時沒有人動的時候，12 秒一次的輪詢是純粹的耗電與配額。
///
/// 3 秒是「對話節奏」的上限：再久使用者就會開始重整、開始懷疑。
/// 再短的話一輪還沒回來下一輪就排上了，而那只會讓請求互相排隊。
pub const ACTIVE_PERIODIC_MS: u64 = 3_000;

/// 距離上一次「真的有拉到東西」多久之內算**對方正在寫**。
///
/// 90 秒而不是 10 秒：使用者在兩台裝置之間切換、思考、寫一段話的節奏
/// 是以分鐘計的。窗口太短的話，他停下來想三十秒，快檔就掉回慢檔，
/// 而他繼續寫的那一刻又要等 12 秒。
pub const ACTIVE_WINDOW_MS: u64 = 90_000;

/// 完全沒有動靜多久之後改用省電節奏。
pub const IDLE_AFTER_MS: u64 = 10 * 60_000;

/// 省電節奏下多久拉一次。
///
/// 這一檔只在**本機十分鐘沒有編輯、遠端十分鐘沒有變動**時生效。
/// 那種情況下 12 秒拉一次換到的是零 —— 而手機的電池是有限的。
///
/// 使用者回到 App（`Foreground`）或寫任何東西（`LocalEdit`）都會立刻
/// 跳回快檔，所以這一檔不會讓他「等很久才同步」。
pub const IDLE_PERIODIC_MS: u64 = 60_000;

/// **對使用者的承諾**：一邊寫完，另一邊最久多久看得到（毫秒）。
///
/// # 為什麼要有一個獨立的數字
///
/// `DEBOUNCE_MS` 與 `PERIODIC_MS` 是實作參數 —— 它們可以為了省電、
/// 省配額被調整，而每一次調整都會改變使用者實際感受到的「即時」。
/// 在此之前沒有任何東西盯著那個總和：把 `PERIODIC_MS` 從 12 秒改成 60 秒
/// 是一行改動，CI 全綠，而「即時同步」就這樣悄悄變成「一分鐘後同步」。
///
/// 這個常數把承諾寫成數字，[`worst_case_visible_latency_ms`] 算出實際的
/// 最壞情況，測試比對兩者。放寬承諾**仍然做得到**，但要改這一行 ——
/// 那正是它該被看見的時候。
pub const VISIBLE_LATENCY_BUDGET_MS: u64 = 15_000;

/// 最壞情況下，A 寫完到 B 看得見要多久。
///
/// A 端去抖動之後才推（`DEBOUNCE_MS`），B 端最久要等一輪定期拉取。
/// 兩段相加就是上界 —— 中間的網路時間不算在內，那不是排程器決定得了的。
///
/// **用 `PERIODIC_MS` 而不是 `IDLE_PERIODIC_MS` 是刻意的。** 省電那一檔
/// 只在雙方都十分鐘沒有動靜時生效，而那時候「即時」沒有意義；
/// 任何一邊一動（本機編輯、回到前景、拉到遠端變動）就立刻回到快檔。
/// 拿省電檔去算承諾的話，這個數字會變成 61.5 秒 —— 那是個誠實但沒有用的
/// 數字，它描述的是沒有人在用的情況。
pub const fn worst_case_visible_latency_ms() -> u64 {
    DEBOUNCE_MS + PERIODIC_MS
}

/// 對方正在寫的時候，A 寫完到 B 看得見要多久。
///
/// 這才是使用者在**來回改同一本筆記**時感受到的數字。
pub const fn active_visible_latency_ms() -> u64 {
    DEBOUNCE_MS + ACTIVE_PERIODIC_MS
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
    /// 上一次**真的拉到東西**的時間。快慢檔據此決定。
    ///
    /// 與 `last_finished` 分開：一輪跑完但什麼也沒變（空回應）是常態，
    /// 拿它當「對方在動」的證據的話，快檔會永遠開著。
    last_remote_change: Option<u64>,
    /// 上一次本機編輯的時間。省電檔要兩邊都沒動才生效。
    last_local_edit: Option<u64>,
    /// 這個排程器第一次被叫到的時間。**沒有歷史不等於安靜** ——
    /// 剛開 App 的裝置正是最需要快的那一個，拿「從來沒動過」
    /// 當作省電的理由，會讓對方的編輯要等一分鐘才看得見。
    first_seen: Option<u64>,
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
            last_remote_change: None,
            last_local_edit: None,
            first_seen: None,
        }
    }

    /// 這一輪**真的拉到了東西**。
    ///
    /// 呼叫端在同步帶回遠端變動時呼叫它 —— 那是「對方正在寫」唯一可靠的
    /// 證據。沒有這個訊號的話，排程器分不出「一直在拉但都是空的」與
    /// 「對方正在改」，而那兩種情況該用完全不同的節奏。
    pub fn note_remote_change(&mut self, now_ms: u64) {
        self.first_seen.get_or_insert(now_ms);
        self.last_remote_change = Some(now_ms);
    }

    /// 現在該用哪一種輪詢間隔。
    ///
    /// 三檔，依「有沒有人在動」決定：
    ///
    /// * 剛拉到遠端變動（90 秒內）→ 快檔，對方正在寫
    /// * 本機或遠端十分鐘內有動靜 → 基準檔
    /// * 兩邊都十分鐘沒動 → 省電檔
    ///
    /// 回傳的是毫秒。公開是為了讓平台層能據此設定計時器 ——
    /// 平台端自己猜一個數字的話，兩端的節奏會不一樣。
    pub fn current_period_ms(&self, now_ms: u64) -> u64 {
        let since = |t: Option<u64>| t.map(|v| now_ms.saturating_sub(v));

        // 對方正在寫 —— 這是最該快的時候。
        if since(self.last_remote_change).is_some_and(|gap| gap <= ACTIVE_WINDOW_MS) {
            return ACTIVE_PERIODIC_MS;
        }

        // 兩邊都很久沒動才省電。任何一邊有動靜就維持基準檔 ——
        // 使用者正在寫的時候把節奏放慢，是最糟的省電方式。
        //
        // 「從來沒動過」算進來的是 `first_seen`，不是無限久以前：
        // 一台剛開起來、還沒收到任何東西的裝置，要先照基準檔跑滿
        // 十分鐘，才有資格說自己閒著。
        let last_activity = [
            self.last_local_edit,
            self.last_remote_change,
            self.first_seen,
        ]
        .into_iter()
        .flatten()
        .max();
        match since(last_activity) {
            Some(gap) if gap >= IDLE_AFTER_MS => IDLE_PERIODIC_MS,
            // 連 `first_seen` 都還沒設 —— 還沒開始跑，照基準檔。
            None => PERIODIC_MS,
            Some(_) => PERIODIC_MS,
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
        if trigger == SyncTrigger::LocalEdit {
            self.last_local_edit = Some(now_ms);
        }
        self.first_seen.get_or_insert(now_ms);
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
        self.first_seen.get_or_insert(now_ms);
        if self.blocked_on_auth || self.running || self.due_at.is_some() {
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
mod adaptive_cadence {
    use super::*;

    #[test]
    fn a_fresh_scheduler_uses_the_baseline_not_the_idle_period() {
        // **沒有歷史 ≠ 閒著。** 剛開起來的裝置正是最可能要接收
        // 對方編輯的那一台；把它當成閒置會直接違反
        // `VISIBLE_LATENCY_BUDGET_MS`。
        let mut s = SyncScheduler::new();
        s.tick(0);
        assert_eq!(s.current_period_ms(0), PERIODIC_MS);
        assert_eq!(
            s.current_period_ms(IDLE_AFTER_MS - 1),
            PERIODIC_MS,
            "十分鐘還沒滿就降檔了"
        );
    }

    #[test]
    fn pulling_a_remote_change_switches_to_the_fast_period() {
        // **這是整個改動的重點。** 拉到東西就代表對方正在寫，
        // 而那是最該快的時候 —— 原本這種情況也只有 12 秒。
        let mut s = SyncScheduler::new();
        s.note_remote_change(100_000);
        assert_eq!(s.current_period_ms(100_000), ACTIVE_PERIODIC_MS);
        assert_eq!(
            s.current_period_ms(100_000 + ACTIVE_WINDOW_MS),
            ACTIVE_PERIODIC_MS,
            "窗口邊界上還算在寫"
        );
    }

    #[test]
    fn the_fast_period_expires_after_the_window() {
        let mut s = SyncScheduler::new();
        s.note_remote_change(0);
        // 窗口過了就回基準檔 —— 但還不到省電檔，因為遠端十分鐘內有動過。
        assert_eq!(s.current_period_ms(ACTIVE_WINDOW_MS + 1), PERIODIC_MS);
    }

    #[test]
    fn a_local_edit_keeps_the_baseline_period_not_the_idle_one() {
        // **使用者正在寫的時候把節奏放慢，是最糟的省電方式。**
        let mut s = SyncScheduler::new();
        s.request(SyncTrigger::LocalEdit, 500_000);
        assert_eq!(s.current_period_ms(500_000), PERIODIC_MS);
        assert_eq!(
            s.current_period_ms(500_000 + IDLE_AFTER_MS - 1),
            PERIODIC_MS
        );
    }

    #[test]
    fn both_sides_quiet_for_ten_minutes_drops_to_power_saving() {
        let mut s = SyncScheduler::new();
        s.request(SyncTrigger::LocalEdit, 0);
        s.note_remote_change(0);
        assert_eq!(s.current_period_ms(IDLE_AFTER_MS), IDLE_PERIODIC_MS);
        // 再動一下就立刻回到基準檔。
        s.request(SyncTrigger::LocalEdit, IDLE_AFTER_MS);
        assert_eq!(s.current_period_ms(IDLE_AFTER_MS), PERIODIC_MS);
    }

    #[test]
    fn tick_respects_the_adaptive_period() {
        // 快檔時 tick 要比基準檔早排一輪 —— 只改 `current_period_ms`
        // 而沒有把它接進 `tick` 的話，整個改動等於沒有效果。
        let mut s = SyncScheduler::new();
        s.request(SyncTrigger::Manual, 0);
        assert!(s.should_start(0));
        s.finish(SyncOutcome::Success, 0);
        s.note_remote_change(0);

        s.tick(ACTIVE_PERIODIC_MS - 1);
        assert!(!s.has_pending(), "還沒到快檔的間隔就排了");
        s.tick(ACTIVE_PERIODIC_MS);
        assert!(s.has_pending(), "到了快檔的間隔卻沒有排");
    }

    #[test]
    fn the_active_latency_is_the_number_users_actually_feel() {
        // 來回改同一本筆記時的延遲。這個數字放寬**仍然做得到**，
        // 但要改常數 —— 那正是它該被看見的時候（與
        // `VISIBLE_LATENCY_BUDGET_MS` 同一個理由）。
        assert!(
            active_visible_latency_ms() <= 5_000,
            "對方正在寫時的延遲是 {} ms，超過五秒就不算即時了",
            active_visible_latency_ms()
        );
        assert!(
            active_visible_latency_ms() < worst_case_visible_latency_ms(),
            "快檔沒有比基準檔快，那這個改動沒有意義"
        );
    }

    #[test]
    fn the_idle_period_never_shortens_the_promise() {
        // 省電檔比基準檔慢是刻意的，但它不可以被拿去算承諾 ——
        // 那個數字描述的是沒有人在用的情況。
        // 用 `assert_ne!` + 比較值而不是 `assert!(A > B)`：兩個都是常數，
        // clippy 的 `assertions_on_constants` 會把後者當成「這條斷言在編譯期
        // 就有答案，等於沒測」。這裡要守的是**兩個常數的關係**，所以把關係
        // 算成值再比。
        assert_eq!(
            IDLE_PERIODIC_MS.max(PERIODIC_MS),
            IDLE_PERIODIC_MS,
            "省電檔（{IDLE_PERIODIC_MS}）沒有比基準檔（{PERIODIC_MS}）慢，那它就不是省電檔"
        );
        assert_eq!(
            worst_case_visible_latency_ms(),
            DEBOUNCE_MS + PERIODIC_MS,
            "承諾被改成用省電檔算了"
        );
    }

    #[test]
    fn an_empty_round_does_not_count_as_activity() {
        // 一輪跑完但什麼也沒變是常態。拿它當「對方在動」的證據的話，
        // 快檔會永遠開著 —— 那是把 12 秒改成 3 秒的全時段輪詢，
        // 配額與電池都吃不消。
        let mut s = SyncScheduler::new();
        s.request(SyncTrigger::Manual, 0);
        assert!(s.should_start(0));
        s.finish(SyncOutcome::Success, 0);
        assert_eq!(
            s.current_period_ms(0),
            PERIODIC_MS,
            "空的一輪不該讓節奏變快"
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
