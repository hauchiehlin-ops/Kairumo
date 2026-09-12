//! 語音開關的遲滯邏輯。
//!
//! 刻意與模型推論分離：這段邏輯決定了分段品質，而且**不需要模型就能完整測試**。

/// 雙門檻遲滯（hysteresis）。
///
/// 用單一門檻會在機率貼近門檻時來回跳動（flapping），把一句話切成一堆碎片。
/// Silero 官方建議的做法是：**開始說話的門檻高於停止說話的門檻**。
#[derive(Clone, Copy, Debug)]
pub struct SpeechGate {
    /// 從靜音轉為語音所需的機率。
    pub start_threshold: f32,
    /// 從語音轉回靜音所需**低於**的機率。必須小於 `start_threshold`。
    pub stop_threshold: f32,
    speaking: bool,
}

impl Default for SpeechGate {
    fn default() -> Self {
        // Silero 官方推薦值。
        Self::new(0.5, 0.35)
    }
}

impl SpeechGate {
    pub fn new(start_threshold: f32, stop_threshold: f32) -> Self {
        debug_assert!(
            stop_threshold <= start_threshold,
            "停止門檻必須低於開始門檻，否則遲滯失效"
        );
        Self {
            start_threshold,
            stop_threshold,
            speaking: false,
        }
    }

    pub fn is_speaking(&self) -> bool {
        self.speaking
    }

    /// 餵入一個機率，回傳目前是否判定為語音。
    pub fn update(&mut self, probability: f32) -> bool {
        self.speaking = if self.speaking {
            probability >= self.stop_threshold
        } else {
            probability >= self.start_threshold
        };
        self.speaking
    }

    pub fn reset(&mut self) {
        self.speaking = false;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn requires_the_higher_threshold_to_start() {
        let mut g = SpeechGate::default();
        assert!(!g.update(0.4), "0.4 低於開始門檻 0.5");
        assert!(g.update(0.6));
    }

    #[test]
    fn holds_speech_through_dips_above_the_stop_threshold() {
        // 這正是遲滯的目的：講話中的短暫低點不該把句子切斷。
        let mut g = SpeechGate::default();
        g.update(0.9);
        assert!(g.update(0.4), "0.4 高於停止門檻 0.35，應維持語音狀態");
        assert!(g.update(0.36));
    }

    #[test]
    fn stops_below_the_lower_threshold() {
        let mut g = SpeechGate::default();
        g.update(0.9);
        assert!(!g.update(0.2));
    }

    #[test]
    fn single_threshold_would_flap_but_hysteresis_does_not() {
        // 機率在 0.45/0.55 之間震盪：單門檻 0.5 會切出一堆碎片。
        let mut g = SpeechGate::default();
        g.update(0.9); // 先進入語音

        let mut transitions = 0;
        let mut last = true;
        for p in [0.45, 0.55, 0.45, 0.55, 0.45, 0.55] {
            let now = g.update(p);
            if now != last {
                transitions += 1;
            }
            last = now;
        }
        assert_eq!(transitions, 0, "遲滯區間內不該有任何狀態切換");
    }

    #[test]
    fn reset_returns_to_silence() {
        let mut g = SpeechGate::default();
        g.update(0.9);
        assert!(g.is_speaking());
        g.reset();
        assert!(!g.is_speaking());
    }

    #[test]
    fn extreme_probabilities_behave() {
        let mut g = SpeechGate::default();
        assert!(g.update(1.0));
        assert!(!g.update(0.0));
    }
}
