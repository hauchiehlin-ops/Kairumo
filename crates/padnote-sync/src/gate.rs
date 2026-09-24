//! 同步互斥閘 —— **整個行程同一時間只准跑一輪同步**。
//!
//! # 為什麼要有這個
//!
//! 同步的每個入口原本各自帶一個旗標：Apple 有三顆按鈕各一個
//! （`homeGoogleSyncing`、兩個不同畫面裡的 `isGoogleSyncing`），Android 有
//! 四個入口（自動同步、`SyncWorker`、兩個手動）。排程器自己也有一個
//! `running`。
//!
//! 那些旗標只擋得住「同一顆按鈕連按兩下」—— 它們彼此不認識。自動同步
//! 正在跑的時候按下「立即同步」，兩輪就並行了，而症狀完全不像併發：
//!
//! * **「找不到：/upload/drive/v3/files/…」** —— 兩輪各自為同一本筆記開了
//!   可續傳上傳工作階段，先完成的那一輪把檔案換掉，另一輪手上的工作階段
//!   網址就失效了。看起來像 Drive 弄丟了檔案。
//! * **「blob … 下載後雜湊不符」** —— 一輪正在下載某個 blob，另一輪同時
//!   把同名的 blob 換掉，下載回來的內容自然對不上索引裡的雜湊。看起來
//!   像傳輸損毀。
//!
//! 兩個都會被誤診成「雲端有問題」，而真因在自己家裡。
//!
//! # 為什麼放在核心
//!
//! 放在核心 = 兩端共用同一把鎖，行為一定一致。各寫一份的話，下一個新增
//! 的入口只會補上其中一邊。

/// 卡住多久之後可以被接手。
///
/// 純粹是保險絲：沒有它的話，一輪跑到一半被系統殺掉（Android 的
/// `SyncWorker` 被回收、iOS 背景時間用完）就會把閘永遠鎖住，從此再也
/// 不能同步，而且**沒有任何錯誤訊息** —— 那比併發更難查。
///
/// 十分鐘遠大於正常一輪（實測幾秒到一分鐘），短到使用者不會放棄。
pub const STALE_TAKEOVER_MS: u64 = 10 * 60_000;

/// 要一把鎖的結果。
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GateDecision {
    /// 拿到了。跑完要用這張票 [`SyncGate::leave`]。
    Entered { ticket: u64 },
    /// 已經有一輪在跑 —— 這次**跳過**，不是排隊。
    ///
    /// 跳過是對的：同步本來就是冪等的，晚一點那輪會把事情做完。排隊只會
    /// 讓使用者連按五下之後看著五輪排隊跑完。
    Busy { holder: String, held_ms: u64 },
    /// 上一輪卡太久，接手。
    TookOver {
        ticket: u64,
        previous: String,
        held_ms: u64,
    },
}

/// 同步互斥閘。
#[derive(Debug, Default)]
pub struct SyncGate {
    holder: Option<Holder>,
    next_ticket: u64,
}

#[derive(Clone, Debug)]
struct Holder {
    label: String,
    since_ms: u64,
    ticket: u64,
}

impl SyncGate {
    pub fn new() -> Self {
        Self::default()
    }

    /// 試著拿鎖。`label` 是給人看的（哪個入口），會出現在日誌裡。
    pub fn try_enter(&mut self, label: &str, now_ms: u64) -> GateDecision {
        if let Some(current) = self.holder.clone() {
            let held_ms = now_ms.saturating_sub(current.since_ms);
            if held_ms < STALE_TAKEOVER_MS {
                return GateDecision::Busy {
                    holder: current.label,
                    held_ms,
                };
            }
            let ticket = self.issue(label, now_ms);
            return GateDecision::TookOver {
                ticket,
                previous: current.label,
                held_ms,
            };
        }
        GateDecision::Entered {
            ticket: self.issue(label, now_ms),
        }
    }

    /// 放鎖。
    ///
    /// **票號要對得上才放。** 被接手的那一輪如果還活著，它跑完也會來放鎖
    /// —— 不比對票號的話，它會把接手者的鎖放掉，於是又回到兩輪並行，
    /// 而且這次是保險絲自己造成的。
    pub fn leave(&mut self, ticket: u64) -> bool {
        match &self.holder {
            Some(current) if current.ticket == ticket => {
                self.holder = None;
                true
            }
            _ => false,
        }
    }

    /// 現在是誰拿著（沒人拿著就是 `None`）。
    pub fn holder(&self) -> Option<&str> {
        self.holder.as_ref().map(|h| h.label.as_str())
    }

    fn issue(&mut self, label: &str, now_ms: u64) -> u64 {
        self.next_ticket = self.next_ticket.wrapping_add(1);
        let ticket = self.next_ticket;
        self.holder = Some(Holder {
            label: label.to_string(),
            since_ms: now_ms,
            ticket,
        });
        ticket
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ticket_of(decision: &GateDecision) -> u64 {
        match decision {
            GateDecision::Entered { ticket } | GateDecision::TookOver { ticket, .. } => *ticket,
            GateDecision::Busy { .. } => panic!("沒拿到鎖，哪來的票：{decision:?}"),
        }
    }

    #[test]
    fn first_caller_gets_in() {
        let mut gate = SyncGate::new();
        assert!(matches!(
            gate.try_enter("auto", 0),
            GateDecision::Entered { .. }
        ));
        assert_eq!(gate.holder(), Some("auto"));
    }

    /// 這就是使用者踩到的那一條：自動同步在跑，手動按下去。
    #[test]
    fn manual_tap_during_auto_sync_is_skipped() {
        let mut gate = SyncGate::new();
        let auto = gate.try_enter("auto", 0);
        let manual = gate.try_enter("manual", 1_500);
        assert_eq!(
            manual,
            GateDecision::Busy {
                holder: "auto".to_string(),
                held_ms: 1_500,
            }
        );
        // 第一輪跑完之後才輪得到。
        assert!(gate.leave(ticket_of(&auto)));
        assert!(matches!(
            gate.try_enter("manual", 2_000),
            GateDecision::Entered { .. }
        ));
    }

    #[test]
    fn stuck_round_is_taken_over_after_the_fuse_blows() {
        let mut gate = SyncGate::new();
        gate.try_enter("worker", 0);
        assert!(matches!(
            gate.try_enter("manual", STALE_TAKEOVER_MS - 1),
            GateDecision::Busy { .. }
        ));
        assert_eq!(
            gate.try_enter("manual", STALE_TAKEOVER_MS),
            GateDecision::TookOver {
                ticket: 2,
                previous: "worker".to_string(),
                held_ms: STALE_TAKEOVER_MS,
            }
        );
        assert_eq!(gate.holder(), Some("manual"));
    }

    /// 被接手的那一輪醒過來放鎖，不可以把接手者的鎖放掉。
    #[test]
    fn a_taken_over_round_cannot_release_the_new_holder() {
        let mut gate = SyncGate::new();
        let stale = ticket_of(&gate.try_enter("worker", 0));
        let fresh = ticket_of(&gate.try_enter("manual", STALE_TAKEOVER_MS));

        assert!(!gate.leave(stale), "舊票不該放得掉新鎖");
        assert_eq!(gate.holder(), Some("manual"));

        assert!(gate.leave(fresh));
        assert_eq!(gate.holder(), None);
    }

    #[test]
    fn leaving_twice_is_harmless() {
        let mut gate = SyncGate::new();
        let ticket = ticket_of(&gate.try_enter("auto", 0));
        assert!(gate.leave(ticket));
        assert!(!gate.leave(ticket));
        assert_eq!(gate.holder(), None);
    }

    /// 放掉之後再拿，票號不會重複 —— 否則舊票會意外對上新鎖。
    #[test]
    fn tickets_are_not_reused() {
        let mut gate = SyncGate::new();
        let first = ticket_of(&gate.try_enter("a", 0));
        gate.leave(first);
        let second = ticket_of(&gate.try_enter("b", 1));
        assert_ne!(first, second);
    }
}
