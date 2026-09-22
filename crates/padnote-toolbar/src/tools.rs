//! 工具清單與分組。
//!
//! # 這份清單描述的是**畫面上真的有的那一排按鈕**
//!
//! 原本這裡有二十個項目（尺規、放大書寫框、雷射筆、貼紙庫、表格、嵌入…），
//! 而兩個平台實際出貨的繪圖工具列只有十支筆刷／模式加上三顆歷程按鈕。
//! 兩份清單沒有任何一方對照另一方，於是：
//!
//! * 核心知道「雷射筆」，但按下去沒有東西 —— 那個功能從來沒做
//! * 核心不知道「毛筆／麥克筆／水彩／遮蔽膠帶」，而那四支天天在用
//!
//! 照原本的清單做「自訂工具列」，結果會是一個設定畫面裡有一半的開關
//! 控制不到任何東西，另一半使用者真正想關掉的按鈕又關不掉 ——
//! 正是這個專案一直在清的那種 bug。
//!
//! 所以清單改成以**核心畫面規格的 `editor.inktools`** 為準
//! （`ffi_screens.rs`，兩端的 `parityIdentifier` 都對著它）。
//! 插入類（圖片、表格、圖表…）不在這裡：它們在「插入」選單，
//! 是另一個介面，不是這排工具列。

use padnote_i18n::Key;
use serde::{Deserialize, Serialize};

/// 繪圖工具列上的一個項目。
///
/// `Ord` 是為了讓設定用 `BTreeSet` 儲存 —— 序列化後順序穩定，
/// 偏好檔的 diff 才不會每次都變。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Debug, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Tool {
    // 筆刷。七支，順序與兩端工具列一致。
    Pen,
    BallPoint,
    Brush,
    Marker,
    Highlighter,
    Pencil,
    Watercolor,
    // 模式。不沾墨，也不吃顏色與粗細。
    Eraser,
    Lasso,
    MaskingTape,
    // 歷程。
    Undo,
    Redo,
    ClearPage,
}

impl Tool {
    /// 顯示名稱的 i18n 鍵。
    pub fn label_key(self) -> Key {
        match self {
            Self::Pen => Key::ToolFountainPen,
            Self::BallPoint => Key::ToolBallPoint,
            Self::Brush => Key::ToolBrush,
            Self::Marker => Key::ToolMarker,
            Self::Highlighter => Key::ToolHighlighter,
            Self::Pencil => Key::ToolPencil,
            Self::Watercolor => Key::ToolWatercolor,
            Self::Eraser => Key::ToolEraser,
            Self::Lasso => Key::ToolLasso,
            Self::MaskingTape => Key::ToolMaskingTape,
            Self::Undo => Key::ToolUndo,
            Self::Redo => Key::ToolRedo,
            Self::ClearPage => Key::ToolClearPage,
        }
    }

    /// 跨平台對照用的識別字，與畫面規格 `editor.inktools` 逐字相同。
    ///
    /// 寫成 `match` 而不是插值：兩端的無障礙識別字也是這樣寫的
    /// （理由見 `EditorToolType.parityIdentifier`），三處對得起來，
    /// 少一支工具會在對照閘門紅掉而不是安靜地漏掉。
    pub fn parity_identifier(self) -> &'static str {
        match self {
            Self::Pen => "editor.ink.pen",
            Self::BallPoint => "editor.ink.ballpoint",
            Self::Brush => "editor.ink.brush",
            Self::Marker => "editor.ink.marker",
            Self::Highlighter => "editor.ink.highlighter",
            Self::Pencil => "editor.ink.pencil",
            Self::Watercolor => "editor.ink.watercolor",
            Self::Eraser => "editor.ink.eraser",
            Self::Lasso => "editor.ink.lasso",
            Self::MaskingTape => "editor.ink.maskingTape",
            Self::Undo => "editor.ink.undo",
            Self::Redo => "editor.ink.redo",
            Self::ClearPage => "editor.ink.clear",
        }
    }

    /// 是不是筆刷（會沾墨、吃顏色與粗細）。
    ///
    /// 橡皮擦、套索、遮蔽膠帶與歷程按鈕都不是。
    pub fn is_brush(self) -> bool {
        matches!(
            self,
            Self::Pen
                | Self::BallPoint
                | Self::Brush
                | Self::Marker
                | Self::Highlighter
                | Self::Pencil
                | Self::Watercolor
        )
    }

    /// 是否預設顯示。
    ///
    /// **全部都顯示。** 原本這裡讓一部分工具預設隱藏，理由是「工具列塞滿
    /// 反而找不到東西」—— 那個理由本身沒錯，但現在有個更硬的限制：
    /// 這十三顆按鈕**現在就在使用者的畫面上**。讓「自訂工具列」這個新設定
    /// 帶著一組精簡預設上線，等於升級之後有人的筆不見了，而他沒有動過任何設定。
    ///
    /// 精簡是使用者自己按出來的結果，不是我們替他決定的起點。
    pub fn shown_by_default(self) -> bool {
        true
    }

    /// 所屬分組。
    pub fn group(self) -> ToolGroup {
        if self.is_brush() {
            return ToolGroup::Pens;
        }
        match self {
            Self::Eraser | Self::Lasso | Self::MaskingTape => ToolGroup::Edit,
            _ => ToolGroup::History,
        }
    }
}

/// 工具分組。
#[derive(Clone, Copy, PartialEq, Eq, Debug, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ToolGroup {
    Pens,
    Edit,
    History,
}

impl ToolGroup {
    pub const ALL: [Self; 3] = [Self::Pens, Self::Edit, Self::History];

    pub fn label_key(self) -> Key {
        match self {
            Self::Pens => Key::GroupPens,
            Self::Edit => Key::GroupEdit,
            Self::History => Key::GroupHistory,
        }
    }

    /// 此分組的所有工具，依固定順序。
    pub fn tools(self) -> Vec<Tool> {
        all_tools()
            .into_iter()
            .filter(|t| t.group() == self)
            .collect()
    }
}

/// 所有工具，依分組與組內順序排列。
pub fn all_tools() -> Vec<Tool> {
    vec![
        Tool::Pen,
        Tool::BallPoint,
        Tool::Brush,
        Tool::Marker,
        Tool::Highlighter,
        Tool::Pencil,
        Tool::Watercolor,
        Tool::Eraser,
        Tool::Lasso,
        Tool::MaskingTape,
        Tool::Undo,
        Tool::Redo,
        Tool::ClearPage,
    ]
}

/// 所有分組及其工具。
pub fn all_groups() -> Vec<(ToolGroup, Vec<Tool>)> {
    ToolGroup::ALL.into_iter().map(|g| (g, g.tools())).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_tool_belongs_to_exactly_one_group() {
        let total: usize = ToolGroup::ALL.iter().map(|g| g.tools().len()).sum();
        assert_eq!(total, all_tools().len(), "有工具沒分組或被重複計入");
    }

    #[test]
    fn every_tool_has_a_label() {
        // 沒有標籤的工具在 UI 上會是空白按鈕。
        for t in all_tools() {
            let label = padnote_i18n::text(t.label_key(), padnote_i18n::Locale::English);
            assert!(!label.is_empty(), "{t:?} 沒有標籤");
        }
    }

    #[test]
    fn labels_are_not_shared_between_different_tools() {
        // 原本 Shape 與 ShapeRecognition 共用一個鍵，Table 與 Embed 借用
        // 「匯入」—— 設定畫面上就會出現兩排一模一樣的字，使用者分不出
        // 自己在關哪一個。
        let mut labels: Vec<&str> = all_tools()
            .into_iter()
            .map(|t| padnote_i18n::text(t.label_key(), padnote_i18n::Locale::English))
            .collect();
        let before = labels.len();
        labels.sort_unstable();
        labels.dedup();
        assert_eq!(before, labels.len(), "有工具共用同一個標籤：{labels:?}");
    }

    #[test]
    fn the_list_matches_the_shipped_toolbar() {
        // 這份清單存在的唯一理由，是它與畫面上那排按鈕一一對應。
        // 對不上的話，「自訂工具列」就會出現關不掉的按鈕與控制不到的開關。
        let ids: Vec<&str> = all_tools()
            .into_iter()
            .map(|t| t.parity_identifier())
            .collect();
        assert_eq!(
            ids,
            vec![
                "editor.ink.pen",
                "editor.ink.ballpoint",
                "editor.ink.brush",
                "editor.ink.marker",
                "editor.ink.highlighter",
                "editor.ink.pencil",
                "editor.ink.watercolor",
                "editor.ink.eraser",
                "editor.ink.lasso",
                "editor.ink.maskingTape",
                "editor.ink.undo",
                "editor.ink.redo",
                "editor.ink.clear",
            ]
        );
    }

    #[test]
    fn identifiers_are_unique() {
        let mut ids: Vec<&str> = all_tools()
            .into_iter()
            .map(|t| t.parity_identifier())
            .collect();
        let before = ids.len();
        ids.sort_unstable();
        ids.dedup();
        assert_eq!(before, ids.len(), "識別字重複");
    }

    #[test]
    fn nothing_is_hidden_before_the_user_touches_anything() {
        // 升級之後有人的筆不見了，而他沒有動過任何設定 —— 不可以。
        assert!(all_tools().iter().all(|t| t.shown_by_default()));
    }

    #[test]
    fn brushes_and_modes_are_told_apart() {
        // 橡皮擦與套索不吃顏色與粗細；把它們當成筆會讓色票對它們亮著。
        assert!(Tool::Pen.is_brush());
        assert!(Tool::Watercolor.is_brush());
        assert!(!Tool::Eraser.is_brush());
        assert!(!Tool::Lasso.is_brush());
        assert!(!Tool::MaskingTape.is_brush());
        assert!(!Tool::Undo.is_brush());
    }

    #[test]
    fn tool_order_is_stable() {
        // 順序改變會讓使用者的肌肉記憶失效。
        assert_eq!(all_tools()[0], Tool::Pen);
        assert_eq!(all_tools().len(), 13);
    }

    #[test]
    fn serialisation_uses_stable_names() {
        // 設定要存進偏好檔**而且會同步到別台裝置**，用 snake_case 名稱
        // 而非數字索引 —— 數字會在新增工具時錯位。
        let json = serde_json::to_string(&Tool::Highlighter).unwrap();
        assert_eq!(json, "\"highlighter\"");
        assert_eq!(
            serde_json::from_str::<Tool>("\"highlighter\"").unwrap(),
            Tool::Highlighter
        );
        assert_eq!(
            serde_json::to_string(&Tool::MaskingTape).unwrap(),
            "\"masking_tape\""
        );
    }
}
