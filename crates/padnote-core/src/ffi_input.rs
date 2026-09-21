//! 輸入仲裁的 FFI（S-36）。
//!
//! 平台層每收到一個觸控事件就呼叫 [`InkArbiter::handle`]，
//! 依回傳的結果決定要畫、當手勢、還是忽略。
//!
//! **`retract` 不能忽略。** 使用者的自然動作是手掌先碰螢幕、筆才落下，
//! 此時手掌那一筆已經開始畫了。平台層必須依 `retract` 收回那些筆畫 ——
//! 不處理的話掌拒只擋得住一半的情況。

use padnote_input::{
    ArbiterConfig, InputMode, PenAction, PenControl, PenControlMap, PenOutcome, PenState, Phase,
    PointerArbiter, PointerEvent, PointerKind, PressureAction, PressureCurve, Verdict,
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
    /// 筆懸停在螢幕上方但尚未接觸。
    ///
    /// 兩個用途：顯示落筆預覽、**提前啟動掌拒**
    /// （筆在上方時手掌往往已經貼上螢幕了）。
    Hover,
    HoverEnded,
}

impl From<FfiPhase> for Phase {
    fn from(p: FfiPhase) -> Self {
        match p {
            FfiPhase::Began => Self::Began,
            FfiPhase::Moved => Self::Moved,
            FfiPhase::Ended => Self::Ended,
            FfiPhase::Cancelled => Self::Cancelled,
            FfiPhase::Hover => Self::Hover,
            FfiPhase::HoverEnded => Self::HoverEnded,
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
    /// 懸停 —— 顯示落筆預覽，不產生筆跡。
    Hover,
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
                Verdict::Hover => FfiVerdict::Hover,
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

    /// 調整掌拒門檻。**兩個值都會被夾制到 [`palm_threshold_limits`] 的範圍內。**
    ///
    /// `palm_radius`：超過此接觸半徑視為手掌（預設 22 點）。
    /// `retract_window_ms`：筆落下時回溯撤銷的時間窗（預設 500 **毫秒**）。
    ///
    /// # 為什麼要夾制
    ///
    /// 這裡的單位是毫秒，而核心內部的欄位叫 `retract_window_us`（微秒）。
    /// Android 的呼叫端照著核心的預設值抄，傳了 `500_000` —— 那是 500 **秒**。
    /// 後果不是「設定沒生效」，而是使用者用手指寫了幾分鐘、筆一落下，
    /// **過去八分鐘的手指筆畫被整批收回**，而且沒有任何錯誤訊息。
    ///
    /// 夾制擋不住寫錯單位，但擋得住寫錯單位的**代價**：最壞情況從
    /// 「八分鐘的東西沒了」變成「收回窗比預期長一點」。
    ///
    /// ⚠️ 預設值都是**起點值**，需在實機以真實書寫姿勢調整。
    pub fn set_palm_thresholds(&self, palm_radius: f32, retract_window_ms: u32) {
        let mut a = self.lock();
        let config = ArbiterConfig {
            palm_radius: palm_radius_clamped(palm_radius),
            retract_window_us: u64::from(palm_retract_ms_clamped(retract_window_ms)) * 1_000,
            ..*a.config()
        };
        *a = PointerArbiter::new(config);
    }

    pub fn is_pen_down(&self) -> bool {
        self.lock().is_pen_down()
    }

    /// 筆是否懸停在螢幕上方。
    pub fn is_pen_hovering(&self) -> bool {
        self.lock().is_pen_hovering()
    }

    /// 懸停位置 `[x, y]`，供 UI 畫落筆預覽。未懸停時為 `None`。
    pub fn hover_position(&self) -> Option<Vec<f32>> {
        self.lock().hover_position().map(|(x, y)| vec![x, y])
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
    fn hover_crosses_the_boundary_with_position() {
        let a = InkArbiter::new();
        let mut e = ev(1, FfiPointerKind::Pen, FfiPhase::Hover, 0, 2.0);
        e.x = 150.0;
        e.y = 250.0;

        let d = a.handle(e);
        assert!(matches!(d.verdict, FfiVerdict::Hover));
        assert!(a.is_pen_hovering());
        assert_eq!(a.hover_position(), Some(vec![150.0, 250.0]));
    }

    #[test]
    fn hover_engages_palm_rejection_early() {
        // 不畫出來再收回，比畫出來再收回好。
        let a = InkArbiter::new();
        a.handle(ev(1, FfiPointerKind::Pen, FfiPhase::Hover, 0, 2.0));

        let d = a.handle(ev(2, FfiPointerKind::Finger, FfiPhase::Began, 10_000, 10.0));
        assert!(matches!(d.verdict, FfiVerdict::Reject));
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

// ── 筆身控制項（工作項 S-40 / S-67）─────────────────────────────

/// 筆身上的一個實體動作。
#[derive(Clone, Copy, Debug, uniffi::Enum)]
pub enum FfiPenControl {
    DoubleTap,
    Squeeze,
    BarrelPrimary,
    BarrelSecondary,
    Invert,
}

impl From<FfiPenControl> for PenControl {
    fn from(c: FfiPenControl) -> Self {
        match c {
            FfiPenControl::DoubleTap => Self::DoubleTap,
            FfiPenControl::Squeeze => Self::Squeeze,
            FfiPenControl::BarrelPrimary => Self::BarrelPrimary,
            FfiPenControl::BarrelSecondary => Self::BarrelSecondary,
            FfiPenControl::Invert => Self::Invert,
        }
    }
}

/// 可以指派給筆身動作的行為。
#[derive(Clone, Copy, Debug, uniffi::Enum)]
pub enum FfiPenAction {
    None,
    Eraser,
    LastBrush,
    InkAttributes,
    Lasso,
    Undo,
    Redo,
    Ruler,
}

impl From<FfiPenAction> for PenAction {
    fn from(a: FfiPenAction) -> Self {
        match a {
            FfiPenAction::None => Self::None,
            FfiPenAction::Eraser => Self::Eraser,
            FfiPenAction::LastBrush => Self::LastBrush,
            FfiPenAction::InkAttributes => Self::InkAttributes,
            FfiPenAction::Lasso => Self::Lasso,
            FfiPenAction::Undo => Self::Undo,
            FfiPenAction::Redo => Self::Redo,
            FfiPenAction::Ruler => Self::Ruler,
        }
    }
}

impl From<PenAction> for FfiPenAction {
    fn from(a: PenAction) -> Self {
        match a {
            PenAction::None => Self::None,
            PenAction::Eraser => Self::Eraser,
            PenAction::LastBrush => Self::LastBrush,
            PenAction::InkAttributes => Self::InkAttributes,
            PenAction::Lasso => Self::Lasso,
            PenAction::Undo => Self::Undo,
            PenAction::Redo => Self::Redo,
            PenAction::Ruler => Self::Ruler,
        }
    }
}

/// 平台要執行的事。
#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum FfiPenOutcome {
    Nothing,
    UseEraser,
    UseLastBrush,
    UseLasso,
    ShowInkAttributes,
    Undo,
    Redo,
    ToggleRuler,
}

impl From<PenOutcome> for FfiPenOutcome {
    fn from(o: PenOutcome) -> Self {
        match o {
            PenOutcome::Nothing => Self::Nothing,
            PenOutcome::UseEraser => Self::UseEraser,
            PenOutcome::UseLastBrush => Self::UseLastBrush,
            PenOutcome::UseLasso => Self::UseLasso,
            PenOutcome::ShowInkAttributes => Self::ShowInkAttributes,
            PenOutcome::Undo => Self::Undo,
            PenOutcome::Redo => Self::Redo,
            PenOutcome::ToggleRuler => Self::ToggleRuler,
        }
    }
}

/// 筆身動作的對應表。
///
/// 兩個平台共用這一份 —— 硬體事件各平台不同（雙擊、擠壓、側鍵位元、
/// 反向筆頭），但「按下去要發生什麼」不該各寫一套。各寫一套的結果是
/// 同一支筆在兩台裝置上行為不同，而使用者買的是同一支筆。
#[derive(Debug, Default, uniffi::Object)]
pub struct PenControls {
    inner: Mutex<PenControlMap>,
}

#[uniffi::export]
impl PenControls {
    #[uniffi::constructor]
    pub fn new() -> Self {
        Self::default()
    }

    /// 從存下來的設定還原。壞掉的項目個別忽略，不是整份回預設。
    #[uniffi::constructor]
    pub fn decode(text: String) -> Self {
        Self {
            inner: Mutex::new(PenControlMap::decode(&text)),
        }
    }

    /// 存起來。**不認得的指派會原樣帶著走**（D-04 的規則）。
    pub fn encode(&self) -> String {
        self.lock().encode()
    }

    pub fn action(&self, control: FfiPenControl) -> FfiPenAction {
        self.lock().action(control.into()).into()
    }

    pub fn set_action(&self, control: FfiPenControl, action: FfiPenAction) {
        self.lock().set(control.into(), action.into());
    }

    /// 這個動作現在要做什麼。
    ///
    /// `pressed` 只對「按著」的控制項（側鍵、反向筆頭）有意義；
    /// 雙擊與擠壓一律傳 true。
    pub fn outcome(
        &self,
        control: FfiPenControl,
        pressed: bool,
        erasing: bool,
        lassoing: bool,
    ) -> FfiPenOutcome {
        self.lock()
            .outcome(control.into(), pressed, PenState { erasing, lassoing })
            .into()
    }

    /// 這個控制項是「按著」還是「切換」。設定畫面要用它決定怎麼說明。
    pub fn is_momentary(&self, control: FfiPenControl) -> bool {
        PenControl::from(control).is_momentary()
    }
}

impl PenControls {
    fn lock(&self) -> std::sync::MutexGuard<'_, PenControlMap> {
        self.inner.lock().expect("筆身設定鎖中毒")
    }
}

#[cfg(test)]
mod pen_tests {
    use super::*;

    #[test]
    fn the_ffi_layer_agrees_with_the_core() {
        let c = PenControls::new();
        assert_eq!(
            c.outcome(FfiPenControl::BarrelPrimary, true, false, false),
            FfiPenOutcome::UseEraser
        );
        assert_eq!(
            c.outcome(FfiPenControl::BarrelPrimary, false, true, false),
            FfiPenOutcome::UseLastBrush
        );
    }

    #[test]
    fn settings_survive_the_round_trip_through_the_ffi() {
        let c = PenControls::new();
        c.set_action(FfiPenControl::Squeeze, FfiPenAction::Undo);
        let restored = PenControls::decode(c.encode());
        assert!(matches!(
            restored.action(FfiPenControl::Squeeze),
            FfiPenAction::Undo
        ));
    }

    #[test]
    fn the_platforms_are_told_which_controls_are_held() {
        // 平台拿這個決定要不要處理「放開」。分類錯的話，側鍵會變成切換，
        // 使用者碰一下就永遠停在橡皮擦。
        let c = PenControls::new();
        assert!(c.is_momentary(FfiPenControl::BarrelPrimary));
        assert!(!c.is_momentary(FfiPenControl::DoubleTap));
        assert!(!c.is_momentary(FfiPenControl::Squeeze));
    }
}

// ---- 掌拒門檻的範圍與預設（工作項 S-101）----
//
// 這些數字放在核心，是因為兩個平台的設定畫面都要用到它們：滑桿的兩端、
// 「恢復預設」的值、以及寫進 `DeviceSettings` 之前的夾制。
// 各抄一份的話，兩邊的滑桿範圍遲早不一樣，而使用者不會知道為什麼
// 同一個數字在另一台裝置上效果不同。

/// 掌拒門檻的可調範圍與預設值。
#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct FfiPalmLimits {
    pub default_radius_dp: f32,
    /// 手指也能書寫時的預設半徑。比僅限筆時鬆 ——
    /// 手指的接觸半徑本來就比筆尖大，用同一個門檻會把正常的手寫當成手掌。
    pub finger_mode_radius_dp: f32,
    pub min_radius_dp: f32,
    pub max_radius_dp: f32,
    pub default_retract_ms: u32,
    pub min_retract_ms: u32,
    pub max_retract_ms: u32,
}

/// 範圍的由來：
///
/// - **半徑 8–60 dp。** 低於 8 連筆尖都會被當成手掌（S Pen 的接觸半徑約
///   3–6 dp，但手指最小也有 8 以上）；高於 60 等於整隻手掌都放行。
/// - **收回窗 100–3000 ms。** 低於 100 收不到「手掌先碰、筆才落下」那一瞬間
///   （那正是它存在的理由）；高於 3 秒就會開始吃掉使用者真的想留下的東西。
#[uniffi::export]
pub fn palm_threshold_limits() -> FfiPalmLimits {
    FfiPalmLimits {
        default_radius_dp: 22.0,
        finger_mode_radius_dp: 40.0,
        min_radius_dp: 8.0,
        max_radius_dp: 60.0,
        default_retract_ms: 500,
        min_retract_ms: 100,
        max_retract_ms: 3_000,
    }
}

#[uniffi::export]
pub fn palm_radius_clamped(dp: f32) -> f32 {
    let l = palm_threshold_limits();
    if dp.is_nan() {
        return l.default_radius_dp;
    }
    dp.clamp(l.min_radius_dp, l.max_radius_dp)
}

#[uniffi::export]
pub fn palm_retract_ms_clamped(ms: u32) -> u32 {
    let l = palm_threshold_limits();
    ms.clamp(l.min_retract_ms, l.max_retract_ms)
}

#[cfg(test)]
mod palm_limit_tests {
    use super::*;

    /// **這一項釘住的是一次真的資料遺失。**
    ///
    /// Android 照著核心內部的 `retract_window_us: 500_000` 抄，把 500_000
    /// 傳給一個以毫秒為單位的參數 —— 500 秒。使用者用手指寫了幾分鐘、
    /// 筆一落下，過去八分鐘的筆畫被當成手掌整批收回。
    #[test]
    fn a_microsecond_value_passed_as_milliseconds_cannot_eat_the_users_work() {
        assert_eq!(palm_retract_ms_clamped(500_000), 3_000);
    }

    #[test]
    fn the_defaults_are_inside_the_range() {
        let l = palm_threshold_limits();
        assert_eq!(
            palm_radius_clamped(l.default_radius_dp),
            l.default_radius_dp
        );
        assert_eq!(
            palm_retract_ms_clamped(l.default_retract_ms),
            l.default_retract_ms
        );
    }

    /// NaN 夾制的結果是 NaN，所以要特別擋 —— 一個 NaN 半徑會讓
    /// 每一次比較都是 false，掌拒就整個失效而沒有人會發現。
    #[test]
    fn a_nan_radius_falls_back_to_the_default() {
        assert_eq!(
            palm_radius_clamped(f32::NAN),
            palm_threshold_limits().default_radius_dp
        );
    }
}

// ---- 墨跡延遲預算（一致性閘門 4）----
//
// 這兩個數字原本只寫在 `docs/TODO.md` 的 H1 裡：
// 「中位數 ≤9ms 且 p95 ≤12ms = Go；>12ms = 改用 PencilKit」。
//
// 寫在文件裡的數字沒有人會被它擋下來。放進核心之後，兩端的延遲量測
// （`InkLatencyMeter`）比對的是同一組值，而且值一改，一致性向量就會紅 ——
// 那正是「我們把承諾放寬了」該被看見的那一刻。

/// 墨跡延遲的預算（微秒）。
#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct FfiInkLatencyBudget {
    /// 中位數上限。
    pub median_us: u64,
    /// 第 95 百分位上限。**超過它代表自建墨跡引擎不成立**（見 TODO 的 H1）。
    pub p95_us: u64,
}

#[uniffi::export]
pub fn ink_latency_budget() -> FfiInkLatencyBudget {
    FfiInkLatencyBudget {
        median_us: 9_000,
        p95_us: 12_000,
    }
}

/// 一組量測結果是否符合預算。
///
/// 兩端各自判斷的話，遲早有一邊寫成 `<` 另一邊寫成 `<=`，
/// 然後同一支筆在兩台裝置上得到不同的結論。
#[uniffi::export]
pub fn ink_latency_meets_budget(median_us: u64, p95_us: u64) -> bool {
    let b = ink_latency_budget();
    median_us <= b.median_us && p95_us <= b.p95_us
}

#[cfg(test)]
mod ink_budget_tests {
    use super::*;

    #[test]
    fn the_boundary_is_inclusive() {
        // 邊界值算通過。寫成 `<` 的話，剛好打在 9.0/12.0 的裝置會被判失敗，
        // 而那個差別會讓兩個平台對同一支筆得到不同結論。
        assert!(ink_latency_meets_budget(9_000, 12_000));
        assert!(!ink_latency_meets_budget(9_001, 12_000));
        assert!(!ink_latency_meets_budget(9_000, 12_001));
    }
}
