//! 同步互斥閘的平台介面。
//!
//! 策略在 [`padnote_sync::gate`]，這裡只是一層**行程唯一**的門面。
//! 用全域的原因就是它要擋的東西：同一個行程裡不同入口開出來的同步
//! （自動、背景任務、畫面上那幾顆「立即同步」）彼此不認識，各自帶一個
//! 旗標是擋不住的。詳細的病徵見 `padnote_sync::gate` 的說明。
//!
//! 平台層怎麼用：
//!
//! ```text
//! let grant = sync_gate_try_enter("google-drive:manual", now_ms);
//! if !grant.granted { 記一行日誌就結束，不要排隊 }
//! defer { sync_gate_leave(grant.ticket) }
//! ```

use std::sync::{Mutex, OnceLock};

use padnote_sync::gate::{GateDecision, SyncGate};

fn gate() -> &'static Mutex<SyncGate> {
    static GATE: OnceLock<Mutex<SyncGate>> = OnceLock::new();
    GATE.get_or_init(|| Mutex::new(SyncGate::new()))
}

/// 要鎖的結果。
///
/// 攤平成一個 struct 而不是帶欄位的列舉 —— 兩端的呼叫點只關心
/// 「拿到了沒」，攤平之後 Swift 與 Kotlin 都是兩行就寫完。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiSyncGrant {
    /// 拿到鎖了沒。`false` 就**直接結束這一輪**，不要排隊重試。
    pub granted: bool,
    /// 放鎖要用的票。`granted` 是 false 時沒有意義。
    pub ticket: u64,
    /// 沒拿到時，是誰拿著；接手時，是被接手的那一位。
    pub holder: String,
    /// 對方已經拿著多久（毫秒）。
    pub held_ms: u64,
    /// 是不是因為上一輪卡太久而接手的。接手值得記一行日誌 ——
    /// 它代表有一輪同步死在半路上，那是另一個要查的問題。
    pub took_over: bool,
}

/// 試著拿鎖。`label` 只是給人看的（哪個入口），會出現在日誌裡。
#[uniffi::export]
pub fn sync_gate_try_enter(label: String, now_ms: u64) -> FfiSyncGrant {
    let mut gate = gate()
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    match gate.try_enter(&label, now_ms) {
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
pub fn sync_gate_leave(ticket: u64) -> bool {
    let mut gate = gate()
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    gate.leave(ticket)
}

/// 現在是誰拿著（沒人拿著就是空字串）。給診斷畫面用。
#[uniffi::export]
pub fn sync_gate_holder() -> String {
    let gate = gate()
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    gate.holder().unwrap_or_default().to_string()
}

/// 卡住多久之後可以被接手（毫秒）。
#[uniffi::export]
pub fn sync_gate_stale_takeover_ms() -> u64 {
    padnote_sync::gate::STALE_TAKEOVER_MS
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 全域的東西不能讓各個測試各跑各的 —— 它們共用同一把鎖。
    /// 一條測試從頭到尾走完，順序就是確定的。
    #[test]
    fn the_global_gate_serialises_callers() {
        let first = sync_gate_try_enter("auto".into(), 0);
        assert!(first.granted);

        // 自動同步在跑的時候按「立即同步」—— 跳過，不排隊。
        let manual = sync_gate_try_enter("manual".into(), 1_000);
        assert!(!manual.granted, "第二輪不該拿得到鎖");
        assert_eq!(manual.holder, "auto");
        assert_eq!(manual.held_ms, 1_000);

        // 票號對不上放不掉。
        assert!(!sync_gate_leave(manual.ticket + 12_345));
        assert_eq!(sync_gate_holder(), "auto");

        assert!(sync_gate_leave(first.ticket));
        assert_eq!(sync_gate_holder(), "");

        // 空出來之後才輪得到。
        let after = sync_gate_try_enter("manual".into(), 2_000);
        assert!(after.granted);
        assert!(sync_gate_leave(after.ticket));
    }

    #[test]
    fn stale_takeover_is_exposed() {
        assert_eq!(sync_gate_stale_takeover_ms(), 10 * 60_000);
    }
}
