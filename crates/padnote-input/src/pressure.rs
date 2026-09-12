//! 壓感語意（決策 D-08）。

/// 按壓深度要觸發什麼。使用者可在設定中選擇。
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub enum PressureAction {
    /// 調變線寬。**預設** —— 那是使用者對「筆」的既有預期。
    #[default]
    StrokeWidth,
    /// 調變濃度（透明度）。
    Opacity,
    /// 線寬與濃度同時。
    WidthAndOpacity,
    /// 重壓叫出快顯工具列。
    ///
    /// ⚠️ 不設為預設：用力寫字的人會不斷誤觸。
    QuickToolbar,
    /// 不使用壓感（固定線寬）。
    None,
}

impl PressureAction {
    pub fn affects_width(self) -> bool {
        matches!(self, Self::StrokeWidth | Self::WidthAndOpacity)
    }

    pub fn affects_opacity(self) -> bool {
        matches!(self, Self::Opacity | Self::WidthAndOpacity)
    }

    /// 是否需要偵測「重壓」手勢。
    pub fn needs_deep_press(self) -> bool {
        matches!(self, Self::QuickToolbar)
    }
}

/// 壓感曲線。
///
/// 線性映射會讓輕壓幾乎看不見筆跡，手感很差。曲線把可用範圍往上抬。
#[derive(Clone, Copy, Debug)]
pub struct PressureCurve {
    /// 壓力為 0 時的輸出比例。必須 > 0，否則輕觸完全不顯示。
    pub floor: f32,
    /// 曲線指數。< 1 讓輕壓更敏感，> 1 讓重壓更明顯。
    pub gamma: f32,
    /// 觸發「重壓」的門檻。
    pub deep_press_threshold: f32,
}

impl Default for PressureCurve {
    fn default() -> Self {
        Self {
            floor: 0.35,
            gamma: 1.0,
            deep_press_threshold: 0.85,
        }
    }
}

impl PressureCurve {
    /// 把原始壓力（0–1）映射成輸出比例。
    pub fn apply(&self, pressure: f32) -> f32 {
        let p = pressure.clamp(0.0, 1.0).powf(self.gamma.max(0.01));
        self.floor + (1.0 - self.floor) * p
    }

    pub fn is_deep_press(&self, pressure: f32) -> bool {
        pressure >= self.deep_press_threshold
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn light_touch_is_still_visible() {
        // 線性映射會讓輕壓幾乎看不見 —— 這是手感差的主因。
        let c = PressureCurve::default();
        assert!(c.apply(0.0) > 0.3, "零壓也要看得見：{}", c.apply(0.0));
        assert_eq!(c.apply(1.0), 1.0);
    }

    #[test]
    fn curve_is_monotonic() {
        let c = PressureCurve::default();
        let mut last = -1.0;
        for i in 0..=10 {
            let v = c.apply(i as f32 / 10.0);
            assert!(v > last, "壓感必須單調遞增");
            last = v;
        }
    }

    #[test]
    fn pressure_is_clamped() {
        let c = PressureCurve::default();
        assert_eq!(c.apply(-1.0), c.apply(0.0));
        assert_eq!(c.apply(5.0), c.apply(1.0));
    }

    #[test]
    fn gamma_below_one_boosts_light_pressure() {
        let soft = PressureCurve {
            gamma: 0.5,
            ..Default::default()
        };
        let linear = PressureCurve {
            gamma: 1.0,
            ..Default::default()
        };
        assert!(soft.apply(0.25) > linear.apply(0.25));
    }

    #[test]
    fn deep_press_has_a_threshold() {
        let c = PressureCurve::default();
        assert!(!c.is_deep_press(0.5));
        assert!(c.is_deep_press(0.9));
    }

    #[test]
    fn default_action_is_stroke_width() {
        // 那是使用者對「筆」的既有預期。
        assert_eq!(PressureAction::default(), PressureAction::StrokeWidth);
        assert!(PressureAction::default().affects_width());
        assert!(!PressureAction::default().affects_opacity());
    }

    #[test]
    fn quick_toolbar_is_the_only_action_needing_deep_press() {
        for a in [
            PressureAction::StrokeWidth,
            PressureAction::Opacity,
            PressureAction::WidthAndOpacity,
            PressureAction::None,
        ] {
            assert!(!a.needs_deep_press(), "{a:?} 不該需要重壓偵測");
        }
        assert!(PressureAction::QuickToolbar.needs_deep_press());
    }

    #[test]
    fn none_disables_all_modulation() {
        let a = PressureAction::None;
        assert!(!a.affects_width());
        assert!(!a.affects_opacity());
    }
}
