//! 工具列設定的持久化與還原。

use crate::tools::{Tool, ToolGroup, all_tools};
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;

/// 工具列位置。
///
/// 可移動是刻意的：Goodnotes 的工具列頂部固定，
/// **左撇子與橫向書寫時會擋手**。
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Placement {
    Top,
    #[default]
    Bottom,
    Left,
    Right,
    /// 收合成單一浮動按鈕。
    Collapsed,
}

/// 使用者的工具列設定。
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ToolbarConfig {
    pub placement: Placement,
    /// 顯示中的工具。
    visible: BTreeSet<Tool>,
    /// 分組顯示順序。
    group_order: Vec<ToolGroup>,
    /// 是否顯示文字標籤（而非只有圖示）。
    ///
    /// 泰文與日文的字串常比英文長 30–50%，這些語言下預設關閉比較安全。
    pub show_labels: bool,
}

impl Default for ToolbarConfig {
    fn default() -> Self {
        Self {
            placement: Placement::default(),
            visible: all_tools()
                .into_iter()
                .filter(|t| t.shown_by_default())
                .collect(),
            group_order: ToolGroup::ALL.to_vec(),
            show_labels: false,
        }
    }
}

impl ToolbarConfig {
    /// 依語言調整預設值。
    pub fn for_locale(locale: padnote_i18n::Locale) -> Self {
        Self {
            // 文字偏長的語言預設只顯示圖示，避免按鈕爆版。
            show_labels: !locale.tends_to_be_long(),
            ..Self::default()
        }
    }

    pub fn is_visible(&self, tool: Tool) -> bool {
        self.visible.contains(&tool)
    }

    pub fn set_visible(&mut self, tool: Tool, visible: bool) {
        if visible {
            self.visible.insert(tool);
        } else {
            self.visible.remove(&tool);
        }
    }

    /// 顯示中的工具，依分組順序排列。
    pub fn visible_tools(&self) -> Vec<(ToolGroup, Vec<Tool>)> {
        self.group_order
            .iter()
            .filter_map(|g| {
                let tools: Vec<Tool> = g
                    .tools()
                    .into_iter()
                    .filter(|t| self.visible.contains(t))
                    .collect();
                // 空的分組不顯示，否則會出現沒有內容的分隔線。
                (!tools.is_empty()).then_some((*g, tools))
            })
            .collect()
    }

    /// 調整分組順序。未列出的分組接在後面 ——
    /// 漏掉某個分組不該讓它消失。
    pub fn set_group_order(&mut self, order: Vec<ToolGroup>) {
        let mut seen: Vec<ToolGroup> = Vec::with_capacity(ToolGroup::ALL.len());
        for g in order.into_iter().chain(ToolGroup::ALL) {
            if !seen.contains(&g) {
                seen.push(g);
            }
        }
        self.group_order = seen;
    }

    /// 還原為預設。**使用者改壞了要回得去。**
    pub fn reset(&mut self) {
        *self = Self::default();
    }

    pub fn to_json(&self) -> String {
        serde_json::to_string(self).unwrap_or_default()
    }

    /// 從偏好檔載入。
    ///
    /// 解析失敗時回傳預設而非錯誤 —— 設定檔損毀不該讓 App 開不起來。
    pub fn from_json(text: &str) -> Self {
        serde_json::from_str(text).unwrap_or_default()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use padnote_i18n::Locale;

    #[test]
    fn defaults_show_the_core_tools() {
        let c = ToolbarConfig::default();
        assert!(c.is_visible(Tool::FountainPen));
        assert!(c.is_visible(Tool::Eraser));
        assert!(!c.is_visible(Tool::LaserPointer), "進階工具預設隱藏");
    }

    #[test]
    fn tools_can_be_toggled() {
        let mut c = ToolbarConfig::default();
        c.set_visible(Tool::LaserPointer, true);
        assert!(c.is_visible(Tool::LaserPointer));

        c.set_visible(Tool::FountainPen, false);
        assert!(!c.is_visible(Tool::FountainPen));
    }

    #[test]
    fn empty_groups_are_not_shown() {
        // 沒有內容的分組會在 UI 留下一條沒意義的分隔線。
        let mut c = ToolbarConfig::default();
        for t in ToolGroup::History.tools() {
            c.set_visible(t, false);
        }
        assert!(
            !c.visible_tools()
                .iter()
                .any(|(g, _)| *g == ToolGroup::History),
            "空分組不該出現"
        );
    }

    #[test]
    fn group_order_is_respected() {
        let mut c = ToolbarConfig::default();
        c.set_group_order(vec![ToolGroup::History, ToolGroup::Pens]);

        let order: Vec<ToolGroup> = c.visible_tools().into_iter().map(|(g, _)| g).collect();
        assert_eq!(order[0], ToolGroup::History);
        assert_eq!(order[1], ToolGroup::Pens);
    }

    #[test]
    fn omitted_groups_are_appended_not_dropped() {
        // 漏掉某個分組不該讓它消失。
        let mut c = ToolbarConfig::default();
        c.set_group_order(vec![ToolGroup::History]);

        let groups: Vec<ToolGroup> = c.visible_tools().into_iter().map(|(g, _)| g).collect();
        assert!(groups.contains(&ToolGroup::Pens), "未列出的分組仍要顯示");
    }

    #[test]
    fn duplicate_groups_in_order_are_ignored() {
        let mut c = ToolbarConfig::default();
        c.set_group_order(vec![ToolGroup::Pens, ToolGroup::Pens, ToolGroup::Edit]);

        let count = c
            .visible_tools()
            .iter()
            .filter(|(g, _)| *g == ToolGroup::Pens)
            .count();
        assert_eq!(count, 1);
    }

    #[test]
    fn reset_restores_defaults() {
        // 使用者改壞了要回得去。
        let mut c = ToolbarConfig::default();
        c.set_visible(Tool::FountainPen, false);
        c.placement = Placement::Left;

        c.reset();
        assert!(c.is_visible(Tool::FountainPen));
        assert_eq!(c.placement, Placement::Bottom);
    }

    #[test]
    fn config_round_trips_through_json() {
        let mut c = ToolbarConfig {
            placement: Placement::Right,
            ..Default::default()
        };
        c.set_visible(Tool::Ruler, true);
        c.show_labels = true;

        let back = ToolbarConfig::from_json(&c.to_json());
        assert_eq!(back.placement, Placement::Right);
        assert!(back.is_visible(Tool::Ruler));
        assert!(back.show_labels);
    }

    #[test]
    fn corrupt_config_falls_back_to_defaults() {
        // 設定檔損毀不該讓 App 開不起來。
        let c = ToolbarConfig::from_json("{ not json");
        assert!(c.is_visible(Tool::FountainPen));
        assert_eq!(c.placement, Placement::Bottom);
    }

    #[test]
    fn long_text_languages_default_to_icons_only() {
        // 泰文與日文的字串常比英文長 30–50%，帶標籤的按鈕會爆版。
        assert!(!ToolbarConfig::for_locale(Locale::Thai).show_labels);
        assert!(!ToolbarConfig::for_locale(Locale::Japanese).show_labels);
        assert!(ToolbarConfig::for_locale(Locale::English).show_labels);
    }

    #[test]
    fn hiding_everything_is_allowed_and_safe() {
        // 使用者有權把工具列清空（專心書寫）。不該 panic 或自動補回來。
        let mut c = ToolbarConfig::default();
        for t in all_tools() {
            c.set_visible(t, false);
        }
        assert!(c.visible_tools().is_empty());
    }
}
