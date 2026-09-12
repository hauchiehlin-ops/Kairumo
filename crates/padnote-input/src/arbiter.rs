//! 指標仲裁：決定每個觸控是墨跡、手勢，還是手掌。

use std::collections::HashMap;

/// 平台對這個指標的分類。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum PointerKind {
    /// 主動式觸控筆（Apple Pencil、S Pen、MPP…）。平台能明確辨識。
    Pen,
    /// 筆的橡皮擦端。
    Eraser,
    Finger,
    Mouse,
    /// 平台沒給分類。多半是被動式觸控筆，與手指同等對待。
    Unknown,
}

impl PointerKind {
    /// 平台是否明確指出這是筆。這是最強的訊號，有就直接採信。
    pub fn is_stylus(self) -> bool {
        matches!(self, Self::Pen | Self::Eraser)
    }
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Phase {
    Began,
    Moved,
    Ended,
    /// 被系統取消（來電、手勢接管…）。
    Cancelled,
    /// 筆懸停在螢幕上方但**尚未接觸**（Apple Pencil Pro／Pencil 2 於 M2 iPad、
    /// S Pen 的 Air View、Windows 的 hover）。
    ///
    /// 兩個用途：
    /// 1. 顯示落筆預覽 —— 使用者看得到筆尖會落在哪
    /// 2. **提前啟動掌拒** —— 筆在上方時手掌往往已經貼上螢幕了
    Hover,
    /// 筆離開懸停範圍。
    HoverEnded,
}

/// 平台層轉換後的統一指標事件。
#[derive(Clone, Copy, Debug)]
pub struct PointerEvent {
    /// 同一次接觸的識別碼，從 Began 到 Ended 保持不變。
    pub id: u64,
    pub kind: PointerKind,
    pub phase: Phase,
    pub x: f32,
    pub y: f32,
    /// 0–1。非筆輸入沒有壓感時填 0.5。
    pub pressure: f32,
    /// 接觸面積的長半徑（點）。手掌遠大於筆尖。
    /// 平台不提供時填 0（表示未知，不參與判定）。
    pub contact_radius: f32,
    pub timestamp_us: u64,
}

/// 仲裁結果。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Verdict {
    /// 採納為墨跡。
    Draw,
    /// 視為手勢（平移、縮放、捲動）。
    Gesture,
    /// 手掌或誤觸，忽略。
    Reject,
    /// 懸停 —— 顯示落筆預覽，不產生筆跡。
    Hover,
}

/// 一次仲裁的完整決定。
#[derive(Clone, Debug, PartialEq)]
pub struct Decision {
    pub verdict: Verdict,
    /// **需要事後撤銷的筆畫 id。**
    ///
    /// 使用者的自然動作是手掌先碰到螢幕、筆才落下。手掌那一筆此時
    /// 已經開始畫了，因此筆落下時必須能收回。
    /// 沒有這個機制，掌拒只能擋住「筆之後」的誤觸 ——
    /// 擋不住最常見的那一種。
    pub retract: Vec<u64>,
}

impl Decision {
    fn plain(verdict: Verdict) -> Self {
        Self {
            verdict,
            retract: Vec::new(),
        }
    }
}

/// 書寫模式。
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub enum InputMode {
    /// 筆與手指都可書寫。手指適合沒有筆的時候。
    #[default]
    PenAndFinger,
    /// 只有筆能書寫，手指一律當手勢。**掌拒最可靠的模式。**
    PenOnly,
    /// 只有手指能書寫（沒有筆的裝置）。
    FingerOnly,
}

#[derive(Clone, Copy, Debug)]
pub struct ArbiterConfig {
    pub mode: InputMode,
    /// 接觸半徑超過此值視為手掌（點）。
    ///
    /// 筆尖約 1–3 點，指尖約 8–15 點，手掌側緣通常 > 25 點。
    /// 取 22 留一點餘裕，避免把粗指頭誤判成手掌。
    pub palm_radius: f32,
    /// 筆抬起後的保護期（微秒）。
    ///
    /// 手掌通常比筆**晚**離開螢幕。這段期間內新出現的觸控仍視為手掌。
    pub pen_grace_us: u64,
    /// 回溯撤銷的時間窗（微秒）。
    ///
    /// 筆落下時，這段時間內開始的非筆筆畫會被收回。
    /// 太短擋不住手掌先落；太長會誤收使用者真正想畫的手指筆畫。
    pub retract_window_us: u64,
    /// 同時幾根手指視為手勢。
    pub gesture_finger_count: usize,
    /// 筆懸停時是否提前啟動掌拒。
    ///
    /// 筆在螢幕上方時，使用者的手掌往往已經貼上去了。提前啟動能擋掉
    /// 「手掌先落」的一大部分，讓回溯撤銷少被用到 ——
    /// **不畫出來再收回，比畫出來再收回好**。
    pub palm_reject_on_hover: bool,
}

impl Default for ArbiterConfig {
    fn default() -> Self {
        Self {
            mode: InputMode::default(),
            palm_radius: 22.0,
            pen_grace_us: 300_000,
            retract_window_us: 500_000,
            gesture_finger_count: 2,
            palm_reject_on_hover: true,
        }
    }
}

#[derive(Clone, Copy, Debug)]
struct Track {
    kind: PointerKind,
    started_at_us: u64,
    verdict: Verdict,
}

/// 指標仲裁器。
///
/// 每個事件進來回傳一個 [`Decision`]。呼叫端依 `verdict` 決定要畫、
/// 要當手勢、還是忽略；並依 `retract` 收回先前誤判的筆畫。
#[derive(Debug)]
pub struct PointerArbiter {
    config: ArbiterConfig,
    active: HashMap<u64, Track>,
    /// 筆目前是否按著。
    pen_down: bool,
    /// 筆最後一次抬起的時間。
    pen_lifted_at_us: Option<u64>,
    /// 筆目前是否懸停在螢幕上方。
    pen_hovering: bool,
    /// 懸停位置，供 UI 畫落筆預覽。
    hover_position: Option<(f32, f32)>,
}

impl Default for PointerArbiter {
    fn default() -> Self {
        Self::new(ArbiterConfig::default())
    }
}

impl PointerArbiter {
    pub fn new(config: ArbiterConfig) -> Self {
        Self {
            config,
            active: HashMap::new(),
            pen_down: false,
            pen_lifted_at_us: None,
            pen_hovering: false,
            hover_position: None,
        }
    }

    pub fn config(&self) -> &ArbiterConfig {
        &self.config
    }

    pub fn set_mode(&mut self, mode: InputMode) {
        self.config.mode = mode;
    }

    /// 目前被採納為墨跡的指標數。
    pub fn drawing_count(&self) -> usize {
        self.active
            .values()
            .filter(|t| t.verdict == Verdict::Draw)
            .count()
    }

    pub fn is_pen_down(&self) -> bool {
        self.pen_down
    }

    /// 筆是否懸停在螢幕上方。
    pub fn is_pen_hovering(&self) -> bool {
        self.pen_hovering
    }

    /// 懸停位置，供 UI 畫落筆預覽。筆未懸停時為 `None`。
    pub fn hover_position(&self) -> Option<(f32, f32)> {
        self.hover_position
    }

    /// 清空狀態。切換頁面或視圖時呼叫。
    pub fn reset(&mut self) {
        self.active.clear();
        self.pen_down = false;
        self.pen_lifted_at_us = None;
        self.pen_hovering = false;
        self.hover_position = None;
    }

    /// 餵入一個事件並取得決定。
    pub fn handle(&mut self, e: &PointerEvent) -> Decision {
        match e.phase {
            Phase::Began => self.on_began(e),
            Phase::Moved => self.on_moved(e),
            Phase::Ended | Phase::Cancelled => self.on_ended(e),
            Phase::Hover => self.on_hover(e),
            Phase::HoverEnded => self.on_hover_ended(e),
        }
    }

    fn on_hover(&mut self, e: &PointerEvent) -> Decision {
        // 只有筆能懸停。手指的「懸停」在多數平台上不存在，
        // 就算有也不該觸發預覽。
        if !e.kind.is_stylus() {
            return Decision::plain(Verdict::Reject);
        }
        self.pen_hovering = true;
        self.hover_position = Some((e.x, e.y));

        // 筆已經在上方 —— 提前收回可疑的筆畫，不要等它落下。
        // 不畫出來再收回，比畫出來再收回好。
        let retract = if self.config.palm_reject_on_hover {
            self.retract_suspects(e.timestamp_us)
        } else {
            Vec::new()
        };

        Decision {
            verdict: Verdict::Hover,
            retract,
        }
    }

    fn on_hover_ended(&mut self, _e: &PointerEvent) -> Decision {
        self.pen_hovering = false;
        self.hover_position = None;
        Decision::plain(Verdict::Hover)
    }

    fn on_began(&mut self, e: &PointerEvent) -> Decision {
        // 筆落下 —— 最強的訊號，直接採信，並回溯撤銷可疑的筆畫。
        if e.kind.is_stylus() {
            self.pen_down = true;
            self.pen_lifted_at_us = None;
            let retract = self.retract_suspects(e.timestamp_us);
            self.track(e, Verdict::Draw);
            return Decision {
                verdict: Verdict::Draw,
                retract,
            };
        }

        let verdict = self.classify_non_stylus(e);
        self.track(e, verdict);
        Decision::plain(verdict)
    }

    /// 非筆輸入的判定。
    fn classify_non_stylus(&self, e: &PointerEvent) -> Verdict {
        // 滑鼠不會有手掌問題，也不該被模式擋掉。
        if e.kind == PointerKind::Mouse {
            return match self.config.mode {
                InputMode::PenOnly => Verdict::Gesture,
                _ => Verdict::Draw,
            };
        }

        // 接觸面積過大 —— 手掌。這個判定優先於模式。
        if e.contact_radius > 0.0 && e.contact_radius > self.config.palm_radius {
            return Verdict::Reject;
        }

        // 筆正按著、剛抬起不久、或懸停在上方 —— 同時出現的觸控幾乎必然是手掌。
        // 手掌通常比筆**晚**離開螢幕，因此抬起後仍有保護期；
        // 而筆懸停時手掌往往已經貼上螢幕了。
        if self.pen_down
            || self.within_pen_grace(e.timestamp_us)
            || (self.config.palm_reject_on_hover && self.pen_hovering)
        {
            return Verdict::Reject;
        }

        match self.config.mode {
            InputMode::PenOnly => Verdict::Gesture,
            InputMode::FingerOnly | InputMode::PenAndFinger => {
                // 多指同時 —— 手勢，不是書寫。
                //
                // **只計入被採納的觸控**：已判為手掌的接觸不該推高指數，
                // 否則「手掌 + 一根手指」會被誤判成雙指手勢。
                let fingers = self
                    .active
                    .values()
                    .filter(|t| {
                        t.verdict != Verdict::Reject
                            && matches!(t.kind, PointerKind::Finger | PointerKind::Unknown)
                    })
                    .count();
                if fingers + 1 >= self.config.gesture_finger_count {
                    Verdict::Gesture
                } else {
                    Verdict::Draw
                }
            }
        }
    }

    fn within_pen_grace(&self, now_us: u64) -> bool {
        self.pen_lifted_at_us
            .is_some_and(|t| now_us.saturating_sub(t) < self.config.pen_grace_us)
    }

    /// 筆落下時，收回時間窗內開始的非筆筆畫。
    fn retract_suspects(&mut self, now_us: u64) -> Vec<u64> {
        let window = self.config.retract_window_us;
        let mut ids: Vec<u64> = self
            .active
            .iter()
            .filter(|(_, t)| {
                t.verdict == Verdict::Draw
                    && !t.kind.is_stylus()
                    && t.kind != PointerKind::Mouse
                    && now_us.saturating_sub(t.started_at_us) <= window
            })
            .map(|(id, _)| *id)
            .collect();
        ids.sort_unstable();

        for id in &ids {
            if let Some(t) = self.active.get_mut(id) {
                t.verdict = Verdict::Reject;
            }
        }
        ids
    }

    fn on_moved(&mut self, e: &PointerEvent) -> Decision {
        // 移動中面積變大 —— 手掌壓平了，改判。
        if !e.kind.is_stylus()
            && e.kind != PointerKind::Mouse
            && e.contact_radius > self.config.palm_radius
            && let Some(t) = self.active.get_mut(&e.id)
            && t.verdict == Verdict::Draw
        {
            t.verdict = Verdict::Reject;
            return Decision {
                verdict: Verdict::Reject,
                retract: vec![e.id],
            };
        }

        // 已判定的指標維持原判 —— 中途改判會讓筆畫斷掉。
        Decision::plain(
            self.active
                .get(&e.id)
                .map_or(Verdict::Reject, |t| t.verdict),
        )
    }

    fn on_ended(&mut self, e: &PointerEvent) -> Decision {
        let verdict = self
            .active
            .remove(&e.id)
            .map_or(Verdict::Reject, |t| t.verdict);

        if e.kind.is_stylus() {
            self.pen_down = self.active.values().any(|t| t.kind.is_stylus());
            if !self.pen_down {
                self.pen_lifted_at_us = Some(e.timestamp_us);
            }
        }
        Decision::plain(verdict)
    }

    fn track(&mut self, e: &PointerEvent, verdict: Verdict) {
        self.active.insert(
            e.id,
            Track {
                kind: e.kind,
                started_at_us: e.timestamp_us,
                verdict,
            },
        );
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ev(id: u64, kind: PointerKind, phase: Phase, t_us: u64) -> PointerEvent {
        PointerEvent {
            id,
            kind,
            phase,
            x: 100.0,
            y: 100.0,
            pressure: 0.5,
            contact_radius: match kind {
                PointerKind::Pen | PointerKind::Eraser => 2.0,
                PointerKind::Finger => 10.0,
                _ => 0.0,
            },
            timestamp_us: t_us,
        }
    }

    fn palm(id: u64, phase: Phase, t_us: u64) -> PointerEvent {
        PointerEvent {
            contact_radius: 30.0,
            ..ev(id, PointerKind::Finger, phase, t_us)
        }
    }

    #[test]
    fn pen_always_draws() {
        let mut a = PointerArbiter::default();
        let d = a.handle(&ev(1, PointerKind::Pen, Phase::Began, 0));
        assert_eq!(d.verdict, Verdict::Draw);
        assert!(a.is_pen_down());
    }

    #[test]
    fn large_contact_is_rejected_as_palm() {
        let mut a = PointerArbiter::default();
        assert_eq!(
            a.handle(&palm(1, Phase::Began, 0)).verdict,
            Verdict::Reject,
            "接觸面積過大應判為手掌"
        );
    }

    #[test]
    fn finger_is_rejected_while_pen_is_down() {
        let mut a = PointerArbiter::default();
        a.handle(&ev(1, PointerKind::Pen, Phase::Began, 0));
        assert_eq!(
            a.handle(&ev(2, PointerKind::Finger, Phase::Began, 1_000))
                .verdict,
            Verdict::Reject,
            "筆按著時的觸控幾乎必然是手掌"
        );
    }

    #[test]
    fn palm_landing_before_the_pen_is_retracted() {
        // **這是最常見也最難的情況**：手掌先碰到螢幕，筆才落下。
        // 沒有回溯撤銷，掌拒擋不住這一種。
        let mut a = PointerArbiter::default();

        let first = a.handle(&ev(1, PointerKind::Finger, Phase::Began, 0));
        assert_eq!(first.verdict, Verdict::Draw, "當下無從得知這是手掌");

        let pen = a.handle(&ev(2, PointerKind::Pen, Phase::Began, 200_000));
        assert_eq!(pen.verdict, Verdict::Draw);
        assert_eq!(pen.retract, vec![1], "筆落下時必須收回手掌那一筆");
    }

    #[test]
    fn retraction_respects_the_time_window() {
        // 很久以前畫的手指筆畫是使用者真的要畫的，不能收回。
        let mut a = PointerArbiter::default();
        a.handle(&ev(1, PointerKind::Finger, Phase::Began, 0));

        let pen = a.handle(&ev(2, PointerKind::Pen, Phase::Began, 5_000_000));
        assert!(pen.retract.is_empty(), "超出時間窗不該收回");
    }

    #[test]
    fn mouse_strokes_are_never_retracted() {
        // 滑鼠不會有手掌問題。
        let mut a = PointerArbiter::default();
        a.handle(&ev(1, PointerKind::Mouse, Phase::Began, 0));
        let pen = a.handle(&ev(2, PointerKind::Pen, Phase::Began, 100_000));
        assert!(pen.retract.is_empty());
    }

    #[test]
    fn finger_is_still_rejected_shortly_after_the_pen_lifts() {
        // 手掌通常比筆**晚**離開螢幕。
        let mut a = PointerArbiter::default();
        a.handle(&ev(1, PointerKind::Pen, Phase::Began, 0));
        a.handle(&ev(1, PointerKind::Pen, Phase::Ended, 1_000_000));

        assert_eq!(
            a.handle(&ev(2, PointerKind::Finger, Phase::Began, 1_100_000))
                .verdict,
            Verdict::Reject,
            "保護期內仍應拒絕"
        );
    }

    #[test]
    fn finger_draws_again_after_the_grace_period() {
        let mut a = PointerArbiter::default();
        a.handle(&ev(1, PointerKind::Pen, Phase::Began, 0));
        a.handle(&ev(1, PointerKind::Pen, Phase::Ended, 1_000_000));

        assert_eq!(
            a.handle(&ev(2, PointerKind::Finger, Phase::Began, 2_000_000))
                .verdict,
            Verdict::Draw,
            "保護期過後手指應能書寫"
        );
    }

    #[test]
    fn pen_only_mode_turns_finger_into_gesture() {
        let mut a = PointerArbiter::new(ArbiterConfig {
            mode: InputMode::PenOnly,
            ..Default::default()
        });
        assert_eq!(
            a.handle(&ev(1, PointerKind::Finger, Phase::Began, 0))
                .verdict,
            Verdict::Gesture,
            "僅筆模式下手指應是手勢而非忽略 —— 使用者還是要能捲動"
        );
    }

    #[test]
    fn two_fingers_are_a_gesture_not_two_strokes() {
        let mut a = PointerArbiter::default();
        assert_eq!(
            a.handle(&ev(1, PointerKind::Finger, Phase::Began, 0))
                .verdict,
            Verdict::Draw
        );
        assert_eq!(
            a.handle(&ev(2, PointerKind::Finger, Phase::Began, 10_000))
                .verdict,
            Verdict::Gesture,
            "第二根手指代表縮放或平移"
        );
    }

    #[test]
    fn verdict_does_not_flip_mid_stroke() {
        // 中途改判會讓筆畫斷成兩截。
        let mut a = PointerArbiter::default();
        a.handle(&ev(1, PointerKind::Finger, Phase::Began, 0));
        for t in 1..5 {
            assert_eq!(
                a.handle(&ev(1, PointerKind::Finger, Phase::Moved, t * 10_000))
                    .verdict,
                Verdict::Draw
            );
        }
    }

    #[test]
    fn growing_contact_area_mid_stroke_is_reclassified() {
        // 手掌落下時可能只碰到一小塊，壓平後面積才變大。
        let mut a = PointerArbiter::default();
        a.handle(&ev(1, PointerKind::Finger, Phase::Began, 0));

        let d = a.handle(&palm(1, Phase::Moved, 50_000));
        assert_eq!(d.verdict, Verdict::Reject);
        assert_eq!(d.retract, vec![1], "已畫的部分要收回");
    }

    #[test]
    fn unknown_contact_radius_does_not_trigger_palm_rejection() {
        // 平台不提供面積時填 0，不該因此把所有觸控都當手掌。
        let mut a = PointerArbiter::default();
        let e = PointerEvent {
            contact_radius: 0.0,
            ..ev(1, PointerKind::Finger, Phase::Began, 0)
        };
        assert_eq!(a.handle(&e).verdict, Verdict::Draw);
    }

    #[test]
    fn eraser_end_is_treated_as_a_stylus() {
        let mut a = PointerArbiter::default();
        assert_eq!(
            a.handle(&ev(1, PointerKind::Eraser, Phase::Began, 0))
                .verdict,
            Verdict::Draw
        );
        assert!(a.is_pen_down());
    }

    #[test]
    fn cancelled_pointers_release_pen_state() {
        let mut a = PointerArbiter::default();
        a.handle(&ev(1, PointerKind::Pen, Phase::Began, 0));
        a.handle(&ev(1, PointerKind::Pen, Phase::Cancelled, 100_000));
        assert!(!a.is_pen_down());
    }

    #[test]
    fn drawing_count_tracks_accepted_pointers() {
        let mut a = PointerArbiter::default();
        a.handle(&ev(1, PointerKind::Finger, Phase::Began, 0));
        assert_eq!(a.drawing_count(), 1);
        a.handle(&palm(2, Phase::Began, 10_000));
        assert_eq!(a.drawing_count(), 1, "手掌不計入");
        a.handle(&ev(1, PointerKind::Finger, Phase::Ended, 20_000));
        assert_eq!(a.drawing_count(), 0);
    }

    #[test]
    fn hover_reports_position_without_drawing() {
        let mut a = PointerArbiter::default();
        let mut e = ev(1, PointerKind::Pen, Phase::Hover, 0);
        e.x = 150.0;
        e.y = 250.0;

        let d = a.handle(&e);
        assert_eq!(d.verdict, Verdict::Hover, "懸停不該產生筆跡");
        assert!(a.is_pen_hovering());
        assert_eq!(a.hover_position(), Some((150.0, 250.0)));
        assert!(!a.is_pen_down(), "懸停不等於落筆");
    }

    #[test]
    fn hover_engages_palm_rejection_early() {
        // 筆在螢幕上方時手掌往往已經貼上去了。提前擋掉比事後收回好 ——
        // **不畫出來再收回，比畫出來再收回好**。
        let mut a = PointerArbiter::default();
        a.handle(&ev(1, PointerKind::Pen, Phase::Hover, 0));

        assert_eq!(
            a.handle(&ev(2, PointerKind::Finger, Phase::Began, 10_000))
                .verdict,
            Verdict::Reject,
            "筆懸停時的觸控應直接擋掉"
        );
    }

    #[test]
    fn hover_retracts_strokes_that_already_started() {
        // 手掌先落、筆才抬到螢幕上方 —— 此時就該收回，不必等筆落下。
        let mut a = PointerArbiter::default();
        a.handle(&ev(1, PointerKind::Finger, Phase::Began, 0));

        let d = a.handle(&ev(2, PointerKind::Pen, Phase::Hover, 100_000));
        assert_eq!(d.retract, vec![1], "懸停就該收回可疑筆畫");
    }

    #[test]
    fn hover_can_be_disabled_for_palm_rejection() {
        // 某些裝置的懸停偵測不穩，使用者可以關掉這個行為。
        let mut a = PointerArbiter::new(ArbiterConfig {
            palm_reject_on_hover: false,
            ..Default::default()
        });
        a.handle(&ev(1, PointerKind::Pen, Phase::Hover, 0));

        assert_eq!(
            a.handle(&ev(2, PointerKind::Finger, Phase::Began, 10_000))
                .verdict,
            Verdict::Draw
        );
    }

    #[test]
    fn hover_ending_clears_the_preview() {
        let mut a = PointerArbiter::default();
        a.handle(&ev(1, PointerKind::Pen, Phase::Hover, 0));
        a.handle(&ev(1, PointerKind::Pen, Phase::HoverEnded, 100_000));

        assert!(!a.is_pen_hovering());
        assert!(a.hover_position().is_none());
    }

    #[test]
    fn finger_hover_is_ignored() {
        // 手指的「懸停」在多數平台不存在，就算有也不該觸發預覽。
        let mut a = PointerArbiter::default();
        let d = a.handle(&ev(1, PointerKind::Finger, Phase::Hover, 0));
        assert_eq!(d.verdict, Verdict::Reject);
        assert!(!a.is_pen_hovering());
    }

    #[test]
    fn hover_then_touch_still_draws() {
        // 懸停之後真的落筆，當然要畫。
        let mut a = PointerArbiter::default();
        a.handle(&ev(1, PointerKind::Pen, Phase::Hover, 0));
        assert_eq!(
            a.handle(&ev(1, PointerKind::Pen, Phase::Began, 50_000))
                .verdict,
            Verdict::Draw
        );
    }

    #[test]
    fn reset_clears_everything() {
        let mut a = PointerArbiter::default();
        a.handle(&ev(1, PointerKind::Pen, Phase::Began, 0));
        a.reset();
        assert!(!a.is_pen_down());
        assert!(!a.is_pen_hovering());
        assert!(a.hover_position().is_none());
        assert_eq!(a.drawing_count(), 0);
    }

    #[test]
    fn finger_only_mode_still_rejects_palms() {
        // 沒有筆的裝置仍然需要掌拒。
        let mut a = PointerArbiter::new(ArbiterConfig {
            mode: InputMode::FingerOnly,
            ..Default::default()
        });
        assert_eq!(a.handle(&palm(1, Phase::Began, 0)).verdict, Verdict::Reject);
        assert_eq!(
            a.handle(&ev(2, PointerKind::Finger, Phase::Began, 10_000))
                .verdict,
            Verdict::Draw
        );
    }
}
