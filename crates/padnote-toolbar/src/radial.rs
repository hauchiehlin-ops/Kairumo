//! 飛梭工具盤（徑向快捷盤）的槽位。
//!
//! # 為什麼放在核心
//!
//! 工具盤上有哪幾格、順序如何，是使用者的設定，而且**會跟著帳號跑**（與工具列同一份 JSON）。
//! 兩端各存一份的話，在 iPad 上排好的工具盤，到 Android 又回到出廠的八格。
//! 哪些動作能放、最多幾格、排到不合法時怎麼收斂，也只寫這一次 —— 兩端的設定畫面只負責畫。
//!
//! # 能放什麼
//!
//! 工具列上的每一支筆與模式、復原／重做，再加上三個不在工具列上的快捷動作
//! （進階調色、平滑防抖開關、手寫／打字切換）。**「清除本頁」刻意不能放**：
//! 工具盤是用甩的、盲切的，誤觸率比工具列高，不該有一格是「一甩就清掉整頁」。

use crate::tools::Tool;
use serde::{Deserialize, Serialize};

/// 工具盤最少、最多幾格。少於兩格就不是「選單」了；多於八格每一格的扇區太窄，甩不準。
pub const RADIAL_MIN: usize = 2;
pub const RADIAL_MAX: usize = 8;

/// 能放進飛梭工具盤的一個動作。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Debug, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RadialAction {
    Pen,
    BallPoint,
    Fineliner,
    Brush,
    Calligraphy,
    Pencil,
    Charcoal,
    Crayon,
    Airbrush,
    OilPaint,
    Watercolor,
    Marker,
    Highlighter,
    Eraser,
    Lasso,
    MaskingTape,
    Drafting,
    Undo,
    Redo,
    /// 打開進階調色。
    Color,
    /// 平滑防抖開／關。
    Stabilizer,
    /// 手寫模式 ↔ 打字模式。
    ToggleMode,
}

impl RadialAction {
    /// 全部能放的動作，依設定畫面的列出順序（先筆、再模式、再歷程、最後快捷動作）。
    pub const ALL: [RadialAction; 22] = [
        Self::Pen,
        Self::BallPoint,
        Self::Fineliner,
        Self::Brush,
        Self::Calligraphy,
        Self::Pencil,
        Self::Charcoal,
        Self::Crayon,
        Self::Airbrush,
        Self::OilPaint,
        Self::Watercolor,
        Self::Marker,
        Self::Highlighter,
        Self::Eraser,
        Self::Lasso,
        Self::MaskingTape,
        Self::Drafting,
        Self::Undo,
        Self::Redo,
        Self::Color,
        Self::Stabilizer,
        Self::ToggleMode,
    ];

    /// 出廠的八格 —— 就是自訂功能上線前兩端寫死的那八格，順序也一樣。
    /// 沒動過設定的人，工具盤不能變。
    pub const DEFAULT: [RadialAction; 8] = [
        Self::Pen,
        Self::Highlighter,
        Self::Eraser,
        Self::Lasso,
        Self::Undo,
        Self::Redo,
        Self::Color,
        Self::Stabilizer,
    ];

    /// 對應的工具列工具（快捷動作沒有）。
    pub fn tool(self) -> Option<Tool> {
        Some(match self {
            Self::Pen => Tool::Pen,
            Self::BallPoint => Tool::BallPoint,
            Self::Fineliner => Tool::Fineliner,
            Self::Brush => Tool::Brush,
            Self::Calligraphy => Tool::Calligraphy,
            Self::Pencil => Tool::Pencil,
            Self::Charcoal => Tool::Charcoal,
            Self::Crayon => Tool::Crayon,
            Self::Airbrush => Tool::Airbrush,
            Self::OilPaint => Tool::OilPaint,
            Self::Watercolor => Tool::Watercolor,
            Self::Marker => Tool::Marker,
            Self::Highlighter => Tool::Highlighter,
            Self::Eraser => Tool::Eraser,
            Self::Lasso => Tool::Lasso,
            Self::MaskingTape => Tool::MaskingTape,
            Self::Drafting => Tool::Drafting,
            Self::Undo => Tool::Undo,
            Self::Redo => Tool::Redo,
            Self::Color | Self::Stabilizer | Self::ToggleMode => return None,
        })
    }

    /// 跨平台識別字（設定畫面的無障礙識別字與 UI 測試用）。
    ///
    /// 寫成 `match` 而不是插值，理由同 `Tool::parity_identifier`。
    pub fn parity_identifier(self) -> &'static str {
        match self {
            Self::Pen => "radial.pen",
            Self::BallPoint => "radial.ballpoint",
            Self::Fineliner => "radial.fineliner",
            Self::Brush => "radial.brush",
            Self::Calligraphy => "radial.calligraphy",
            Self::Pencil => "radial.pencil",
            Self::Charcoal => "radial.charcoal",
            Self::Crayon => "radial.crayon",
            Self::Airbrush => "radial.airbrush",
            Self::OilPaint => "radial.oilpaint",
            Self::Watercolor => "radial.watercolor",
            Self::Marker => "radial.marker",
            Self::Highlighter => "radial.highlighter",
            Self::Eraser => "radial.eraser",
            Self::Lasso => "radial.lasso",
            Self::MaskingTape => "radial.maskingTape",
            Self::Drafting => "radial.drafting",
            Self::Undo => "radial.undo",
            Self::Redo => "radial.redo",
            Self::Color => "radial.color",
            Self::Stabilizer => "radial.stabilizer",
            Self::ToggleMode => "radial.toggleMode",
        }
    }
}

/// 把一份槽位清單收斂成合法的：去掉重複（留第一個）、超過上限的截掉。
/// 少於下限時回 `None` —— 呼叫端保留原本的設定，不要讓工具盤只剩一格或空的。
pub fn normalized(slots: &[RadialAction]) -> Option<Vec<RadialAction>> {
    let mut out: Vec<RadialAction> = Vec::with_capacity(RADIAL_MAX);
    for s in slots {
        if !out.contains(s) {
            out.push(*s);
        }
        if out.len() == RADIAL_MAX {
            break;
        }
    }
    (out.len() >= RADIAL_MIN).then_some(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_is_the_eight_slots_both_platforms_shipped() {
        // 自訂功能上線那天，沒動過設定的人工具盤不能變。
        use RadialAction::*;
        assert_eq!(
            RadialAction::DEFAULT,
            [
                Pen,
                Highlighter,
                Eraser,
                Lasso,
                Undo,
                Redo,
                Color,
                Stabilizer
            ]
        );
    }

    #[test]
    fn clear_page_can_never_be_a_slot() {
        // 工具盤是用甩的，不該有一格是「一甩就清掉整頁」。
        assert!(
            RadialAction::ALL
                .iter()
                .all(|a| a.tool() != Some(Tool::ClearPage))
        );
    }

    #[test]
    fn every_toolbar_tool_except_clear_page_is_offered() {
        for t in crate::tools::all_tools() {
            if t == Tool::ClearPage {
                continue;
            }
            assert!(
                RadialAction::ALL.iter().any(|a| a.tool() == Some(t)),
                "{t:?} 不能放進飛梭工具盤"
            );
        }
    }

    #[test]
    fn identifiers_are_unique() {
        let mut ids: Vec<&str> = RadialAction::ALL
            .iter()
            .map(|a| a.parity_identifier())
            .collect();
        ids.sort_unstable();
        ids.dedup();
        assert_eq!(ids.len(), RadialAction::ALL.len());
    }

    #[test]
    fn normalizing_drops_duplicates_and_caps_at_eight() {
        use RadialAction::*;
        let got = normalized(&[Pen, Pen, Eraser]).unwrap();
        assert_eq!(got, vec![Pen, Eraser]);
        let many: Vec<RadialAction> = RadialAction::ALL.to_vec();
        assert_eq!(normalized(&many).unwrap().len(), RADIAL_MAX);
    }

    #[test]
    fn fewer_than_two_slots_is_rejected() {
        use RadialAction::*;
        assert!(normalized(&[Pen]).is_none());
        assert!(normalized(&[Pen, Pen]).is_none(), "去重之後只剩一格");
        assert!(normalized(&[]).is_none());
    }
}
