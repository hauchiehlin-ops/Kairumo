//! 工具清單與分組。

use padnote_i18n::Key;
use serde::{Deserialize, Serialize};

/// 一個工具。
/// `Ord` 是為了讓設定用 `BTreeSet` 儲存 —— 序列化後順序穩定，
/// 偏好檔的 diff 才不會每次都變。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Debug, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Tool {
    // 筆類
    FountainPen,
    BallPoint,
    Highlighter,
    Pencil,
    // 編輯
    Eraser,
    Lasso,
    // 插入
    Text,
    Image,
    Shape,
    Table,
    Embed,
    StickerLibrary,
    // 歷程
    Undo,
    Redo,
    // 進階（預設隱藏）
    Ruler,
    MaskingTape,
    ShapeRecognition,
    ZoomWrite,
    LaserPointer,
    Record,
}

impl Tool {
    /// 顯示名稱的 i18n 鍵。
    pub fn label_key(self) -> Key {
        match self {
            Self::FountainPen => Key::ToolFountainPen,
            Self::BallPoint => Key::ToolBallPoint,
            Self::Highlighter => Key::ToolHighlighter,
            Self::Pencil => Key::ToolPencil,
            Self::Eraser => Key::ToolEraser,
            Self::Lasso => Key::ToolLasso,
            Self::Text => Key::ToolText,
            Self::Image => Key::ToolImage,
            Self::Shape | Self::ShapeRecognition => Key::ToolShape,
            Self::Table | Self::Embed => Key::Import,
            Self::StickerLibrary => Key::ToolImage, // Reuse Image key or add new one
            Self::MaskingTape => Key::ToolHighlighter, // Reuse Highlighter key or add new one
            Self::Undo => Key::ToolUndo,
            Self::Redo => Key::ToolRedo,
            Self::Ruler | Self::ZoomWrite | Self::LaserPointer => Key::ToolShape,
            Self::Record => Key::Record,
        }
    }

    /// 是否預設顯示。
    ///
    /// 預設精簡是刻意的 —— 工具列塞滿反而找不到東西。
    /// 進階工具（尺規、放大書寫框、雷射筆）由使用者自行開啟。
    pub fn shown_by_default(self) -> bool {
        !matches!(
            self,
            Self::Pencil
                | Self::Ruler
                | Self::ShapeRecognition
                | Self::ZoomWrite
                | Self::LaserPointer
                | Self::Table
                | Self::Embed
                | Self::StickerLibrary
                | Self::MaskingTape
        )
    }

    /// 所屬分組。
    pub fn group(self) -> ToolGroup {
        match self {
            Self::FountainPen | Self::BallPoint | Self::Highlighter | Self::Pencil | Self::MaskingTape => {
                ToolGroup::Pens
            }
            Self::Eraser | Self::Lasso | Self::Ruler | Self::ShapeRecognition | Self::ZoomWrite => {
                ToolGroup::Edit
            }
            Self::Text | Self::Image | Self::Shape | Self::Table | Self::Embed | Self::StickerLibrary => ToolGroup::Insert,
            Self::Undo | Self::Redo => ToolGroup::History,
            Self::LaserPointer | Self::Record => ToolGroup::Extras,
        }
    }
}

/// 工具分組。
#[derive(Clone, Copy, PartialEq, Eq, Debug, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ToolGroup {
    Pens,
    Edit,
    Insert,
    History,
    Extras,
}

impl ToolGroup {
    pub const ALL: [Self; 5] = [
        Self::Pens,
        Self::Edit,
        Self::Insert,
        Self::History,
        Self::Extras,
    ];

    pub fn label_key(self) -> Key {
        match self {
            Self::Pens => Key::GroupPens,
            Self::Edit => Key::GroupEdit,
            Self::Insert => Key::GroupInsert,
            Self::History => Key::GroupHistory,
            Self::Extras => Key::GroupExtras,
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
        Tool::FountainPen,
        Tool::BallPoint,
        Tool::Highlighter,
        Tool::Pencil,
        Tool::MaskingTape,
        Tool::Eraser,
        Tool::Lasso,
        Tool::Ruler,
        Tool::ShapeRecognition,
        Tool::ZoomWrite,
        Tool::Text,
        Tool::Image,
        Tool::Shape,
        Tool::Table,
        Tool::Embed,
        Tool::StickerLibrary,
        Tool::Undo,
        Tool::Redo,
        Tool::LaserPointer,
        Tool::Record,
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
    fn defaults_are_lean_not_exhaustive() {
        // 工具列塞滿反而找不到東西。
        let shown = all_tools().iter().filter(|t| t.shown_by_default()).count();
        let total = all_tools().len();
        assert!(shown < total, "應有工具預設隱藏");
        assert!(shown >= 8, "預設也不能太少，實得 {shown}");
    }

    #[test]
    fn advanced_tools_are_hidden_by_default() {
        for t in [Tool::Ruler, Tool::ZoomWrite, Tool::LaserPointer] {
            assert!(!t.shown_by_default(), "{t:?} 不該預設顯示");
        }
    }

    #[test]
    fn core_writing_tools_are_always_visible_by_default() {
        // 拿到 App 第一件事就是寫字 —— 筆與橡皮擦不能藏起來。
        for t in [Tool::FountainPen, Tool::Eraser, Tool::Undo] {
            assert!(t.shown_by_default(), "{t:?} 必須預設顯示");
        }
    }

    #[test]
    fn tool_order_is_stable() {
        // 順序改變會讓使用者的肌肉記憶失效。
        assert_eq!(all_tools()[0], Tool::FountainPen);
        assert_eq!(all_tools().len(), 20);
    }

    #[test]
    fn serialisation_uses_stable_names() {
        // 設定要存進偏好檔，用 snake_case 名稱而非數字索引 ——
        // 數字會在新增工具時錯位。
        let json = serde_json::to_string(&Tool::Highlighter).unwrap();
        assert_eq!(json, "\"highlighter\"");
        assert_eq!(
            serde_json::from_str::<Tool>("\"highlighter\"").unwrap(),
            Tool::Highlighter
        );
    }
}
