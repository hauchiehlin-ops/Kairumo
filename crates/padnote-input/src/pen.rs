//! 筆身上的按鍵、擠壓與雙擊要做什麼（工作項 S-40 / S-67）。
//!
//! # 為什麼這張表在核心
//!
//! 與掌拒（[`crate::arbiter`]）、壓感語意（[`crate::pressure`]，決策 D-08）
//! 同一個理由：**這是一張會被使用者改、而且兩個平台必須一致的對應表。**
//!
//! 硬體事件本身各平台不同，這件事沒辦法統一：
//!
//! | 實體動作 | 哪裡來的 |
//! |---|---|
//! | 雙擊筆桿 | 觸控筆的硬體特性，作業系統直接給一個事件 |
//! | 擠壓筆桿 | 同上，較新的筆才有 |
//! | 筆桿側鍵 | 指標事件上的一個按鍵位元 |
//! | 反向筆頭 | 指標事件上的工具類型直接變成橡皮擦 |
//!
//! 但**「按下去要發生什麼」不該各寫一套**。在 Swift 與 Kotlin 各寫一次的
//! 結果，是同一支筆在兩台裝置上行為不同 —— 而使用者買的是同一支筆。
//!
//! 這個模組只決定到 [`PenOutcome`] 為止。把 outcome 換成「哪一支筆刷」是
//! 平台的事：Apple 有九種工具、Android 有六種，工具列舉統一不了，
//! 硬統一只會逼其中一邊多出幾個按不到的工具。
//!
//! # 為什麼「放開」要分成兩種
//!
//! 側鍵是**按著**的（放開就回到原本那支筆），雙擊是**切換**的（再敲一次
//! 才切回來）。做成同一種的話，兩邊都會錯：側鍵做成切換，使用者碰一下
//! 側鍵之後筆就一直是橡皮擦；雙擊做成按著，那根本沒有「按著」可言。
//!
//! # 實機校準
//!
//! 下面的預設值是**起點值**，不是量出來的。側鍵事件要實體觸控筆才發得
//! 出來（模擬器沒有，`adb input` 送不出 `buttonState`），數位板還要接上
//! 才知道它把哪顆鍵送成哪個位元。見 TODO 的 S-40 / A-14 / H4。

use std::collections::BTreeMap;

/// 筆身上的一個實體動作。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Debug, Hash)]
pub enum PenControl {
    /// 雙擊筆桿。
    DoubleTap,
    /// 擠壓筆桿。
    Squeeze,
    /// 筆桿主鍵。多數主動式觸控筆只有這一顆；數位板筆通常是靠近筆尖那顆。
    BarrelPrimary,
    /// 筆桿次鍵。兩顆鍵的筆才有。
    BarrelSecondary,
    /// 把筆倒過來用。
    Invert,
}

impl PenControl {
    /// 這個動作是「按著」還是「切換」。
    ///
    /// 按著的放開就還原；切換的要再做一次才還原。搞混的後果見模組說明。
    pub fn is_momentary(self) -> bool {
        matches!(
            self,
            Self::BarrelPrimary | Self::BarrelSecondary | Self::Invert
        )
    }

    pub fn all() -> [PenControl; 5] {
        [
            Self::DoubleTap,
            Self::Squeeze,
            Self::BarrelPrimary,
            Self::BarrelSecondary,
            Self::Invert,
        ]
    }

    /// 設定檔裡的鍵名。**改了會讓既有設定讀不回來**，不要改。
    pub fn key(self) -> &'static str {
        match self {
            Self::DoubleTap => "double_tap",
            Self::Squeeze => "squeeze",
            Self::BarrelPrimary => "barrel_primary",
            Self::BarrelSecondary => "barrel_secondary",
            Self::Invert => "invert",
        }
    }

    pub fn from_key(key: &str) -> Option<Self> {
        Self::all().into_iter().find(|c| c.key() == key)
    }
}

/// 使用者可以指派給某個實體動作的行為。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Debug, Default, Hash)]
pub enum PenAction {
    /// 什麼也不做。使用者刻意關掉。
    #[default]
    None,
    /// 切成橡皮擦（放開／再做一次回到原本那支筆刷）。
    Eraser,
    /// 直接切回最後用過的筆刷。
    LastBrush,
    /// 打開筆刷設定（粗細與顏色）。
    InkAttributes,
    /// 套索選取。
    Lasso,
    Undo,
    Redo,
    /// 開關尺規。
    Ruler,
}

impl PenAction {
    pub fn key(self) -> &'static str {
        match self {
            Self::None => "none",
            Self::Eraser => "eraser",
            Self::LastBrush => "last_brush",
            Self::InkAttributes => "ink_attributes",
            Self::Lasso => "lasso",
            Self::Undo => "undo",
            Self::Redo => "redo",
            Self::Ruler => "ruler",
        }
    }

    pub fn from_key(key: &str) -> Option<Self> {
        [
            Self::None,
            Self::Eraser,
            Self::LastBrush,
            Self::InkAttributes,
            Self::Lasso,
            Self::Undo,
            Self::Redo,
            Self::Ruler,
        ]
        .into_iter()
        .find(|a| a.key() == key)
    }

    /// 這個行為會不會把目前的工具換掉。
    ///
    /// 會換掉的，在「按著」的控制項放開時要還原回去；
    /// 不會換掉的（undo、打開面板）放開時什麼也不必做。
    fn changes_tool(self) -> bool {
        matches!(self, Self::Eraser | Self::LastBrush | Self::Lasso)
    }
}

/// 平台要執行的事。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum PenOutcome {
    /// 不用動。
    Nothing,
    UseEraser,
    /// 回到最後用過的**筆刷**（不是上一個工具 —— 上一個工具可能是套索）。
    UseLastBrush,
    UseLasso,
    ShowInkAttributes,
    Undo,
    Redo,
    ToggleRuler,
}

/// 呼叫時的當下狀態。
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub struct PenState {
    /// 目前選中的是橡皮擦。
    pub erasing: bool,
    /// 目前選中的是套索。
    pub lassoing: bool,
}

/// 實體動作 → 行為的對應表。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct PenControlMap {
    entries: BTreeMap<PenControl, PenAction>,
    /// 讀進來時不認得的鍵。**原樣保留**（與自訂筆參數同一個規則，D-04）：
    /// 舊版讀到新版寫的設定，不認得的鍵要原封不動存回去，否則使用者在舊
    /// 裝置上開一次設定，新的指派就被靜靜清空了。
    unknown: BTreeMap<String, String>,
}

impl Default for PenControlMap {
    /// 預設值。**都是起點值，不是量出來的。**
    ///
    /// - 雙擊 → 橡皮擦：那是使用者對「雙擊筆桿」既有的預期，系統設定裡的
    ///   預設也是它。
    /// - 擠壓 → 筆刷設定：擠壓在系統層的預設是叫出工具面板，跟著走。
    /// - 主鍵 → 橡皮擦：多數手寫 App 的側鍵就是橡皮擦，使用者的預期已經在那裡。
    /// - 次鍵 → 套索：兩顆鍵的筆，第二顆習慣上是「選取」。**不指派 undo**
    ///   —— 誤觸 undo 會**刪掉東西**，而誤觸選取不會。預設值要選誤觸代價小的那個。
    /// - 倒過來 → 橡皮擦：那支筆的另一端本來就畫成橡皮擦的樣子。
    fn default() -> Self {
        let mut entries = BTreeMap::new();
        entries.insert(PenControl::DoubleTap, PenAction::Eraser);
        entries.insert(PenControl::Squeeze, PenAction::InkAttributes);
        entries.insert(PenControl::BarrelPrimary, PenAction::Eraser);
        entries.insert(PenControl::BarrelSecondary, PenAction::Lasso);
        entries.insert(PenControl::Invert, PenAction::Eraser);
        Self {
            entries,
            unknown: BTreeMap::new(),
        }
    }
}

impl PenControlMap {
    pub fn action(&self, control: PenControl) -> PenAction {
        self.entries.get(&control).copied().unwrap_or_default()
    }

    pub fn set(&mut self, control: PenControl, action: PenAction) {
        self.entries.insert(control, action);
    }

    /// 這個動作現在要做什麼。
    ///
    /// - `pressed`：「按著」的控制項用它區分按下與放開。切換型的控制項
    ///   一律傳 `true`（放開沒有意義）。
    /// - `state`：目前選中的工具，用來決定切換要往哪一邊走。
    ///
    /// 回傳 [`PenOutcome::Nothing`] 表示什麼也不用做 —— 一次書寫會產生上百
    /// 個移動事件，全部都回報一個動作的話，上層狀態每秒被寫幾十次。
    pub fn outcome(&self, control: PenControl, pressed: bool, state: PenState) -> PenOutcome {
        let action = self.action(control);

        if control.is_momentary() && !pressed {
            // 放開。只還原「會換掉工具」的行為，而且只在它真的換過的時候。
            //
            // **不能無條件切回筆刷**：使用者自己在工具列上選了橡皮擦，
            // 然後碰了一下側鍵，放開時把他的橡皮擦換掉是錯的。呼叫端記得
            // 自己有沒有切過（平台層的 `stylusHeldEraser`），這裡只負責
            // 「如果要還原，還原成什麼」。
            return if action.changes_tool() {
                PenOutcome::UseLastBrush
            } else {
                PenOutcome::Nothing
            };
        }

        match action {
            PenAction::None => PenOutcome::Nothing,
            PenAction::Eraser => {
                if control.is_momentary() {
                    // 按著：已經是橡皮擦就不用再切一次。
                    if state.erasing {
                        PenOutcome::Nothing
                    } else {
                        PenOutcome::UseEraser
                    }
                } else if state.erasing {
                    PenOutcome::UseLastBrush
                } else {
                    PenOutcome::UseEraser
                }
            }
            PenAction::Lasso => {
                if control.is_momentary() {
                    if state.lassoing {
                        PenOutcome::Nothing
                    } else {
                        PenOutcome::UseLasso
                    }
                } else if state.lassoing {
                    PenOutcome::UseLastBrush
                } else {
                    PenOutcome::UseLasso
                }
            }
            PenAction::LastBrush => PenOutcome::UseLastBrush,
            PenAction::InkAttributes => PenOutcome::ShowInkAttributes,
            PenAction::Undo => PenOutcome::Undo,
            PenAction::Redo => PenOutcome::Redo,
            PenAction::Ruler => PenOutcome::ToggleRuler,
        }
    }

    /// 存成 `鍵=值` 的一行，逐項以 `;` 分隔。
    ///
    /// 不用 JSON：這是五個字串對，兩個平台都要讀寫，而 JSON 會把「不認得的
    /// 鍵要原樣保留」變成一件要小心處理的事。這個格式裡不認得的鍵就是
    /// 一個沒人看的字串對，原樣帶著走不需要任何額外程式。
    pub fn encode(&self) -> String {
        let mut parts: Vec<String> = self
            .entries
            .iter()
            .map(|(c, a)| format!("{}={}", c.key(), a.key()))
            .collect();
        parts.extend(self.unknown.iter().map(|(k, v)| format!("{k}={v}")));
        parts.sort();
        parts.join(";")
    }

    /// 讀回來。壞掉的項目**個別忽略**，不是整份回預設 ——
    /// 一個拼錯的鍵不該把使用者其他四項設定一起清掉。
    pub fn decode(text: &str) -> Self {
        let mut map = Self::default();
        for part in text.split(';') {
            let part = part.trim();
            if part.is_empty() {
                continue;
            }
            let Some((key, value)) = part.split_once('=') else {
                continue;
            };
            match (PenControl::from_key(key), PenAction::from_key(value)) {
                (Some(control), Some(action)) => {
                    map.entries.insert(control, action);
                }
                // 認得的控制項配上不認得的行為：保留原字串。新版加了一個
                // 行為、使用者選了它，然後用舊版開一次 —— 不保留的話那個
                // 指派就沒了。
                (control, _) => {
                    map.unknown.insert(key.to_string(), value.to_string());
                    if let Some(control) = control {
                        map.entries.remove(&control);
                    }
                }
            }
        }
        map
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn brush() -> PenState {
        PenState::default()
    }

    fn erasing() -> PenState {
        PenState {
            erasing: true,
            lassoing: false,
        }
    }

    #[test]
    fn a_held_button_switches_on_press_and_restores_on_release() {
        let m = PenControlMap::default();
        assert_eq!(
            m.outcome(PenControl::BarrelPrimary, true, brush()),
            PenOutcome::UseEraser
        );
        assert_eq!(
            m.outcome(PenControl::BarrelPrimary, false, erasing()),
            PenOutcome::UseLastBrush
        );
    }

    #[test]
    fn holding_a_button_down_does_not_keep_reswitching() {
        // 一次書寫上百個移動事件，每個都回報的話上層狀態每秒被寫幾十次。
        let m = PenControlMap::default();
        assert_eq!(
            m.outcome(PenControl::BarrelPrimary, true, erasing()),
            PenOutcome::Nothing
        );
    }

    #[test]
    fn a_double_tap_toggles_instead_of_being_held() {
        let m = PenControlMap::default();
        assert_eq!(
            m.outcome(PenControl::DoubleTap, true, brush()),
            PenOutcome::UseEraser
        );
        // 再敲一次切回來 —— 這正是與側鍵不同的地方。
        assert_eq!(
            m.outcome(PenControl::DoubleTap, true, erasing()),
            PenOutcome::UseLastBrush
        );
    }

    #[test]
    fn releasing_a_button_that_did_not_change_the_tool_does_nothing() {
        // 次鍵指成 undo 的人，放開時不該被切到某支筆刷。
        let mut m = PenControlMap::default();
        m.set(PenControl::BarrelSecondary, PenAction::Undo);
        assert_eq!(
            m.outcome(PenControl::BarrelSecondary, true, brush()),
            PenOutcome::Undo
        );
        assert_eq!(
            m.outcome(PenControl::BarrelSecondary, false, brush()),
            PenOutcome::Nothing
        );
    }

    #[test]
    fn turning_a_control_off_really_turns_it_off() {
        let mut m = PenControlMap::default();
        m.set(PenControl::DoubleTap, PenAction::None);
        assert_eq!(
            m.outcome(PenControl::DoubleTap, true, brush()),
            PenOutcome::Nothing
        );
    }

    #[test]
    fn the_default_for_a_second_barrel_button_is_not_destructive() {
        // 誤觸 undo 會刪掉東西，誤觸選取不會。預設值要選誤觸代價小的。
        assert_ne!(
            PenControlMap::default().action(PenControl::BarrelSecondary),
            PenAction::Undo
        );
    }

    #[test]
    fn every_control_has_a_default() {
        let m = PenControlMap::default();
        for control in PenControl::all() {
            assert_ne!(
                m.action(control),
                PenAction::None,
                "{:?} 沒有預設行為 —— 那支筆上的那顆鍵會按了沒反應",
                control
            );
        }
    }

    #[test]
    fn settings_survive_a_round_trip() {
        let mut m = PenControlMap::default();
        m.set(PenControl::Squeeze, PenAction::Undo);
        m.set(PenControl::Invert, PenAction::None);
        assert_eq!(PenControlMap::decode(&m.encode()), m);
    }

    #[test]
    fn an_unknown_action_is_kept_instead_of_being_silently_dropped() {
        // 新版加了一個行為、使用者選了它，然後用舊版開一次設定 ——
        // 不保留的話那個指派就沒了，而使用者不會知道。
        let decoded = PenControlMap::decode("double_tap=teleport;squeeze=undo");
        assert!(
            decoded.encode().contains("double_tap=teleport"),
            "不認得的指派被丟掉了：{}",
            decoded.encode()
        );
        assert_eq!(decoded.action(PenControl::Squeeze), PenAction::Undo);
    }

    #[test]
    fn one_broken_entry_does_not_wipe_the_others() {
        let decoded = PenControlMap::decode("barrel_primary=lasso;;garbage;squeeze=redo");
        assert_eq!(decoded.action(PenControl::BarrelPrimary), PenAction::Lasso);
        assert_eq!(decoded.action(PenControl::Squeeze), PenAction::Redo);
        // 沒提到的維持預設，不是變成 None。
        assert_eq!(decoded.action(PenControl::Invert), PenAction::Eraser);
    }

    #[test]
    fn momentary_and_latching_controls_are_not_mixed_up() {
        for control in PenControl::all() {
            let held = matches!(
                control,
                PenControl::BarrelPrimary | PenControl::BarrelSecondary | PenControl::Invert
            );
            assert_eq!(control.is_momentary(), held, "{control:?} 的按法分類錯了");
        }
    }
}
