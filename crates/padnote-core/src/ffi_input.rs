//! 輸入仲裁的 FFI（S-36）。
//!
//! 平台層每收到一個觸控事件就呼叫 [`InkArbiter::handle`]，
//! 依回傳的結果決定要畫、當手勢、還是忽略。
//!
//! **`retract` 不能忽略。** 使用者的自然動作是手掌先碰螢幕、筆才落下，
//! 此時手掌那一筆已經開始畫了。平台層必須依 `retract` 收回那些筆畫 ——
//! 不處理的話掌拒只擋得住一半的情況。

use padnote_input::{
    ArbiterConfig, InputMode, Phase, PointerArbiter, PointerEvent, PointerKind, PressureAction,
    PressureCurve, Verdict,
};
use std::sync::Mutex;

#[derive(Clone, Copy, Debug, uniffi::Enum)]
pub enum FfiPointerKind {
    Pen,
    Eraser,
    Finger,
    Mouse,
    Unknown,
}

impl From<FfiPointerKind> for PointerKind {
    fn from(k: FfiPointerKind) -> Self {
        match k {
            FfiPointerKind::Pen => Self::Pen,
            FfiPointerKind::Eraser => Self::Eraser,
            FfiPointerKind::Finger => Self::Finger,
            FfiPointerKind::Mouse => Self::Mouse,
            FfiPointerKind::Unknown => Self::Unknown,
        }
    }
}

#[derive(Clone, Copy, Debug, uniffi::Enum)]
pub enum FfiPhase {
    Began,
    Moved,
    Ended,
    Cancelled,
}

impl From<FfiPhase> for Phase {
    fn from(p: FfiPhase) -> Self {
        match p {
            FfiPhase::Began => Self::Began,
            FfiPhase::Moved => Self::Moved,
            FfiPhase::Ended => Self::Ended,
            FfiPhase::Cancelled => Self::Cancelled,
        }
    }
}

#[derive(Clone, Copy, Debug, uniffi::Enum)]
pub enum FfiVerdict {
    /// 採納為墨跡。
    Draw,
    /// 視為手勢（平移／縮放／捲動）。
    Gesture,
    /// 手掌或誤觸，忽略。
    Reject,
}

/// 平台層轉換後的指標事件。
#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct FfiPointerEvent {
    /// 同一次接觸從 Began 到 Ended 保持不變。
    pub id: u64,
    pub kind: FfiPointerKind,
    pub phase: FfiPhase,
    pub x: f32,
    pub y: f32,
    /// 0–1。沒有壓感時填 0.5。
    pub pressure: f32,
    /// 接觸面積的長半徑（點）。**平台不提供時填 0** ——
    /// 填 0 表示未知，不會因此被判成手掌。
    pub contact_radius: f32,
    pub timestamp_us: u64,
}

/// 仲裁結果。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiDecision {
    pub verdict: FfiVerdict,
    /// **必須處理**：要收回的筆畫 id（手掌先落、筆後落的情況）。
    pub retract: Vec<u64>,
}

#[derive(Clone, Copy, Debug, uniffi::Enum)]
pub enum FfiInputMode {
    /// 筆與手指都能書寫。
    PenAndFinger,
    /// 只有筆能書寫，手指一律當手勢。**掌拒最可靠的模式。**
    PenOnly,
    /// 只有手指能書寫（沒有筆的裝置）。
    FingerOnly,
}

/// 壓感要觸發什麼（決策 D-08）。
#[derive(Clone, Copy, Debug, uniffi::Enum)]
pub enum FfiPressureAction {
    /// 調變線寬。**預設** —— 使用者對「筆」的既有預期。
    StrokeWidth,
    Opacity,
    WidthAndOpacity,
    /// 重壓叫出快顯工具列。不設為預設：用力寫字的人會不斷誤觸。
    QuickToolbar,
    None,
}

impl From<FfiPressureAction> for PressureAction {
    fn from(a: FfiPressureAction) -> Self {
        match a {
            FfiPressureAction::StrokeWidth => Self::StrokeWidth,
            FfiPressureAction::Opacity => Self::Opacity,
            FfiPressureAction::WidthAndOpacity => Self::WidthAndOpacity,
            FfiPressureAction::QuickToolbar => Self::QuickToolbar,
            FfiPressureAction::None => Self::None,
        }
    }
}

/// 掌拒與輸入分流。每個書寫視圖持有一個。
#[derive(Debug, Default, uniffi::Object)]
pub struct InkArbiter {
    inner: Mutex<PointerArbiter>,
    pressure: Mutex<(PressureAction, PressureCurve)>,
}

#[uniffi::export]
impl InkArbiter {
    #[uniffi::constructor]
    pub fn new() -> Self {
        Self::default()
    }

    /// 餵入一個事件並取得決定。
    pub fn handle(&self, event: FfiPointerEvent) -> FfiDecision {
        let e = PointerEvent {
            id: event.id,
            kind: event.kind.into(),
            phase: event.phase.into(),
            x: event.x,
            y: event.y,
            pressure: event.pressure,
            contact_radius: event.contact_radius,
            timestamp_us: event.timestamp_us,
        };
        let d = self.lock().handle(&e);
        FfiDecision {
            verdict: match d.verdict {
                Verdict::Draw => FfiVerdict::Draw,
                Verdict::Gesture => FfiVerdict::Gesture,
                Verdict::Reject => FfiVerdict::Reject,
            },
            retract: d.retract,
        }
    }

    pub fn set_mode(&self, mode: FfiInputMode) {
        self.lock().set_mode(match mode {
            FfiInputMode::PenAndFinger => InputMode::PenAndFinger,
            FfiInputMode::PenOnly => InputMode::PenOnly,
            FfiInputMode::FingerOnly => InputMode::FingerOnly,
        });
    }

    /// 調整掌拒門檻。
    ///
    /// `palm_radius`：超過此接觸半徑視為手掌（預設 22 點）。
    /// `retract_window_ms`：筆落下時回溯撤銷的時間窗（預設 500 ms）。
    ///
    /// ⚠️ 預設值都是**起點值**，需在實機以真實書寫姿勢調整。
    pub fn set_palm_thresholds(&self, palm_radius: f32, retract_window_ms: u32) {
        let mut a = self.lock();
        let config = ArbiterConfig {
            palm_radius,
            retract_window_us: u64::from(retract_window_ms) * 1_000,
            ..*a.config()
        };
        *a = PointerArbiter::new(config);
    }

    pub fn is_pen_down(&self) -> bool {
        self.lock().is_pen_down()
    }

    /// 切換頁面或視圖時呼叫。
    pub fn reset(&self) {
        self.lock().reset();
    }

    // ---- 壓感（D-08）----

    pub fn set_pressure_action(&self, action: FfiPressureAction) {
        self.pressure.lock().expect("壓感設定鎖中毒").0 = action.into();
    }

    /// 調整壓感曲線。
    ///
    /// `floor`：壓力為 0 時的輸出比例。**必須 > 0**，否則輕觸完全看不見。
    /// `gamma`：< 1 讓輕壓更敏感，> 1 讓重壓更明顯。
    pub fn set_pressure_curve(&self, floor: f32, gamma: f32) {
        self.pressure.lock().expect("壓感設定鎖中毒").1 = PressureCurve {
            floor,
            gamma,
            ..PressureCurve::default()
        };
    }

    /// 把原始壓力換算成線寬比例。
    pub fn width_scale(&self, pressure: f32) -> f32 {
        let (action, curve) = *self.pressure.lock().expect("壓感設定鎖中毒");
        if action.affects_width() {
            curve.apply(pressure)
        } else {
            1.0
        }
    }

    /// 把原始壓力換算成濃度比例。
    pub fn opacity_scale(&self, pressure: f32) -> f32 {
        let (action, curve) = *self.pressure.lock().expect("壓感設定鎖中毒");
        if action.affects_opacity() {
            curve.apply(pressure)
        } else {
            1.0
        }
    }

    /// 是否構成「重壓」手勢（僅在設定為快顯工具列時有意義）。
    pub fn is_deep_press(&self, pressure: f32) -> bool {
        let (action, curve) = *self.pressure.lock().expect("壓感設定鎖中毒");
        action.needs_deep_press() && curve.is_deep_press(pressure)
    }
}

impl InkArbiter {
    fn lock(&self) -> std::sync::MutexGuard<'_, PointerArbiter> {
        self.inner.lock().expect("仲裁器鎖中毒")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ev(id: u64, kind: FfiPointerKind, phase: FfiPhase, t: u64, radius: f32) -> FfiPointerEvent {
        FfiPointerEvent {
            id,
            kind,
            phase,
            x: 100.0,
            y: 100.0,
            pressure: 0.5,
            contact_radius: radius,
            timestamp_us: t,
        }
    }

    #[test]
    fn palm_landing_before_the_pen_is_retracted_across_the_boundary() {
        // 最常見也最難的情況必須跨過 FFI 邊界仍然成立。
        let a = InkArbiter::new();
        let first = a.handle(ev(1, FfiPointerKind::Finger, FfiPhase::Began, 0, 10.0));
        assert!(matches!(first.verdict, FfiVerdict::Draw));

        let pen = a.handle(ev(2, FfiPointerKind::Pen, FfiPhase::Began, 200_000, 2.0));
        assert!(matches!(pen.verdict, FfiVerdict::Draw));
        assert_eq!(pen.retract, vec![1], "平台層必須收回手掌那一筆");
    }

    #[test]
    fn large_contact_is_rejected() {
        let a = InkArbiter::new();
        let d = a.handle(ev(1, FfiPointerKind::Finger, FfiPhase::Began, 0, 30.0));
        assert!(matches!(d.verdict, FfiVerdict::Reject));
    }

    #[test]
    fn unknown_contact_radius_does_not_reject() {
        // 平台不提供面積時填 0，不該因此無法書寫。
        let a = InkArbiter::new();
        let d = a.handle(ev(1, FfiPointerKind::Finger, FfiPhase::Began, 0, 0.0));
        assert!(matches!(d.verdict, FfiVerdict::Draw));
    }

    #[test]
    fn pen_only_mode_turns_finger_into_gesture() {
        let a = InkArbiter::new();
        a.set_mode(FfiInputMode::PenOnly);
        let d = a.handle(ev(1, FfiPointerKind::Finger, FfiPhase::Began, 0, 10.0));
        assert!(matches!(d.verdict, FfiVerdict::Gesture), "還是要能捲動");
    }

    #[test]
    fn thresholds_are_configurable() {
        let a = InkArbiter::new();
        a.set_palm_thresholds(50.0, 100);
        // 半徑 30 在新門檻下不再是手掌
        let d = a.handle(ev(1, FfiPointerKind::Finger, FfiPhase::Began, 0, 30.0));
        assert!(matches!(d.verdict, FfiVerdict::Draw));
    }

    #[test]
    fn default_pressure_affects_width_not_opacity() {
        let a = InkArbiter::new();
        assert!(a.width_scale(0.2) < a.width_scale(0.9));
        assert_eq!(a.opacity_scale(0.2), 1.0, "預設不調變濃度");
    }

    #[test]
    fn light_pressure_is_still_visible() {
        let a = InkArbiter::new();
        assert!(a.width_scale(0.0) > 0.3, "零壓也要看得見");
    }

    #[test]
    fn pressure_action_none_disables_modulation() {
        let a = InkArbiter::new();
        a.set_pressure_action(FfiPressureAction::None);
        assert_eq!(a.width_scale(0.1), 1.0);
        assert_eq!(a.width_scale(1.0), 1.0);
    }

    #[test]
    fn deep_press_only_fires_for_quick_toolbar() {
        let a = InkArbiter::new();
        assert!(!a.is_deep_press(0.95), "預設不該觸發快顯工具列");

        a.set_pressure_action(FfiPressureAction::QuickToolbar);
        assert!(a.is_deep_press(0.95));
        assert!(!a.is_deep_press(0.5));
    }

    #[test]
    fn reset_clears_pen_state() {
        let a = InkArbiter::new();
        a.handle(ev(1, FfiPointerKind::Pen, FfiPhase::Began, 0, 2.0));
        assert!(a.is_pen_down());
        a.reset();
        assert!(!a.is_pen_down());
    }
}
