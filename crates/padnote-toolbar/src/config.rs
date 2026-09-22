//! 工具列設定的持久化與還原。

use crate::tools::{Tool, ToolGroup, all_tools};
use serde::de::IgnoredAny;
use serde::{Deserialize, Deserializer, Serialize};
use std::collections::BTreeSet;

/// 認得就收下，不認得就跳過（而不是讓整筆失敗）。
///
/// 這份設定**會同步到別台裝置**，而那台可能還是舊版。新版多一支工具之後，
/// 舊版讀到不認得的名字時若整份設定回到預設，使用者看到的是
/// 「我在 iPad 上關掉的筆，在 Mac 上又全部冒出來」—— 而他沒有動過設定。
#[derive(Deserialize)]
#[serde(untagged)]
enum Lenient<T> {
    Known(T),
    Unknown(IgnoredAny),
}

fn lenient_visible<'de, D: Deserializer<'de>>(d: D) -> Result<BTreeSet<Tool>, D::Error> {
    Ok(Vec::<Lenient<Tool>>::deserialize(d)?
        .into_iter()
        .filter_map(|e| match e {
            Lenient::Known(t) => Some(t),
            Lenient::Unknown(_) => None,
        })
        .collect())
}

fn lenient_groups<'de, D: Deserializer<'de>>(d: D) -> Result<Vec<ToolGroup>, D::Error> {
    Ok(Vec::<Lenient<ToolGroup>>::deserialize(d)?
        .into_iter()
        .filter_map(|e| match e {
            Lenient::Known(g) => Some(g),
            Lenient::Unknown(_) => None,
        })
        .collect())
}

fn default_visible() -> BTreeSet<Tool> {
    all_tools()
        .into_iter()
        .filter(|t| t.shown_by_default())
        .collect()
}

fn default_group_order() -> Vec<ToolGroup> {
    ToolGroup::ALL.to_vec()
}

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
    #[serde(default)]
    pub placement: Placement,
    /// 顯示中的工具。
    #[serde(default = "default_visible", deserialize_with = "lenient_visible")]
    visible: BTreeSet<Tool>,
    /// 分組顯示順序。
    #[serde(default = "default_group_order", deserialize_with = "lenient_groups")]
    group_order: Vec<ToolGroup>,
    /// 是否顯示文字標籤（而非只有圖示）。
    ///
    /// 泰文與日文的字串常比英文長 30–50%，這些語言下預設關閉比較安全。
    #[serde(default)]
    pub show_labels: bool,
}

impl Default for ToolbarConfig {
    fn default() -> Self {
        Self {
            placement: Placement::default(),
            visible: default_visible(),
            group_order: default_group_order(),
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

    /// 藏起某支工具之後，目前選中的該換成哪一支。
    ///
    /// 使用者可以把正在用的筆關掉 —— 那之後畫面上**沒有任何按鈕是亮的**，
    /// 而畫布還在用那支筆。他看到的是「我的筆不見了，但寫出來還是原本那支」。
    ///
    /// 規則沉在核心而不是各寫一份：兩端對「關掉正在用的工具」的反應
    /// 不一樣的話，同一個帳號在兩台裝置上會得到兩種結果。
    ///
    /// 全部都藏起來時回傳原本那支 —— 使用者有權清空工具列專心書寫，
    /// 那時候繼續用目前的筆是唯一說得通的行為。
    pub fn tool_after_hiding(&self, current: Tool) -> Tool {
        if self.is_visible(current) {
            return current;
        }
        // 先找同類的：關掉螢光筆該換一支筆，而不是跳到橡皮擦。
        all_tools()
            .into_iter()
            .find(|t| t.is_brush() == current.is_brush() && self.is_visible(*t))
            .or_else(|| all_tools().into_iter().find(|t| self.is_visible(*t)))
            .unwrap_or(current)
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
    fn defaults_show_everything_that_is_on_screen_today() {
        // 「自訂工具列」上線那天，使用者的工具列不能少任何一顆按鈕。
        let c = ToolbarConfig::default();
        for t in all_tools() {
            assert!(c.is_visible(t), "{t:?} 預設就不見了");
        }
    }

    #[test]
    fn tools_can_be_toggled() {
        let mut c = ToolbarConfig::default();
        c.set_visible(Tool::Watercolor, false);
        assert!(!c.is_visible(Tool::Watercolor));

        c.set_visible(Tool::Watercolor, true);
        assert!(c.is_visible(Tool::Watercolor));
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
    fn hiding_a_tool_you_are_not_using_changes_nothing() {
        let mut c = ToolbarConfig::default();
        c.set_visible(Tool::Watercolor, false);
        assert_eq!(c.tool_after_hiding(Tool::Pen), Tool::Pen);
    }

    #[test]
    fn hiding_the_tool_in_use_moves_to_another_of_the_same_kind() {
        // 關掉正在用的螢光筆，該換一支筆 —— 不是跳到橡皮擦。
        let mut c = ToolbarConfig::default();
        c.set_visible(Tool::Highlighter, false);
        let next = c.tool_after_hiding(Tool::Highlighter);
        assert!(next.is_brush(), "換成了 {next:?}");
        assert_eq!(next, Tool::Pen);

        // 反過來也一樣：關掉橡皮擦不該讓使用者突然開始畫畫。
        c.set_visible(Tool::Eraser, false);
        let next = c.tool_after_hiding(Tool::Eraser);
        assert!(!next.is_brush(), "換成了 {next:?}");
    }

    #[test]
    fn hiding_the_last_of_a_kind_falls_back_to_whatever_is_left() {
        let mut c = ToolbarConfig::default();
        for t in all_tools().into_iter().filter(|t| !t.is_brush()) {
            c.set_visible(t, false);
        }
        // 模式全關了，還在用套索 —— 只能換成筆。
        assert!(c.tool_after_hiding(Tool::Lasso).is_brush());
    }

    #[test]
    fn an_empty_toolbar_keeps_the_current_tool() {
        // 使用者有權把工具列清空（專心書寫）。那時候畫布不該換筆。
        let mut c = ToolbarConfig::default();
        for t in all_tools() {
            c.set_visible(t, false);
        }
        assert!(c.visible_tools().is_empty());
        assert_eq!(c.tool_after_hiding(Tool::Marker), Tool::Marker);
    }

    #[test]
    fn reset_restores_defaults() {
        // 使用者改壞了要回得去。
        let mut c = ToolbarConfig::default();
        c.set_visible(Tool::Pen, false);
        c.placement = Placement::Left;

        c.reset();
        assert!(c.is_visible(Tool::Pen));
        assert_eq!(c.placement, Placement::Bottom);
    }

    #[test]
    fn config_round_trips_through_json() {
        let mut c = ToolbarConfig {
            placement: Placement::Right,
            ..Default::default()
        };
        c.set_visible(Tool::MaskingTape, false);
        c.show_labels = true;

        let back = ToolbarConfig::from_json(&c.to_json());
        assert_eq!(back.placement, Placement::Right);
        assert!(!back.is_visible(Tool::MaskingTape));
        assert!(back.show_labels);
    }

    #[test]
    fn an_unknown_tool_in_the_json_does_not_wipe_the_whole_config() {
        // 這份 JSON **會同步到別台裝置**，而那台可能是舊版 App。
        // 新版新增一支工具之後，舊版讀到不認得的名字時若整份設定回到預設，
        // 使用者會看到「我在 iPad 上關掉的筆，在 Mac 上又全部冒出來」。
        let json = r#"{"placement":"left","visible":["pen","time_machine"],"group_order":["pens"],"show_labels":true}"#;
        let c = ToolbarConfig::from_json(json);
        assert_eq!(c.placement, Placement::Left, "整份設定被丟掉了");
        assert!(c.is_visible(Tool::Pen));
        assert!(!c.is_visible(Tool::Eraser), "不在清單上的工具不該冒出來");
    }

    #[test]
    fn corrupt_config_falls_back_to_defaults() {
        // 設定檔損毀不該讓 App 開不起來。
        let c = ToolbarConfig::from_json("{ not json");
        assert!(c.is_visible(Tool::Pen));
        assert_eq!(c.placement, Placement::Bottom);
    }

    #[test]
    fn long_text_languages_default_to_icons_only() {
        // 泰文與日文的字串常比英文長 30–50%，帶標籤的按鈕會爆版。
        assert!(!ToolbarConfig::for_locale(Locale::Thai).show_labels);
        assert!(!ToolbarConfig::for_locale(Locale::Japanese).show_labels);
        assert!(ToolbarConfig::for_locale(Locale::English).show_labels);
    }
}
