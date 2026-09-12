//! 多語系與工具列設定的 FFI（S-49 / S-50，需求 4 與 5）。
//!
//! ## 為什麼字串表放在 Rust 而不是各平台的 .strings / strings.xml
//! 放平台端就會有五份要各自維護的表，漏翻譯只有在跑到那一頁時才發現。
//! 放在 core 且以固定長度陣列表達，**少一個語言就編不過**。
//!
//! ## 為什麼工具列設定是可變物件而非純函式
//! 設定要跨畫面共享並持久化。平台層拿到一個 handle，改完呼叫
//! [`FfiToolbar::to_json`] 存進自己的偏好儲存區 —— core 不碰檔案，
//! 因為偏好檔的位置是平台慣例（UserDefaults / SharedPreferences）。

use std::sync::Mutex;

use padnote_i18n::{Locale, catalog};
use padnote_toolbar::{Placement, Tool, ToolGroup, ToolbarConfig};

#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiLocale {
    English,
    TraditionalChinese,
    SimplifiedChinese,
    Japanese,
    Korean,
    Thai,
}

impl From<FfiLocale> for Locale {
    fn from(l: FfiLocale) -> Self {
        match l {
            FfiLocale::English => Self::English,
            FfiLocale::TraditionalChinese => Self::TraditionalChinese,
            FfiLocale::SimplifiedChinese => Self::SimplifiedChinese,
            FfiLocale::Japanese => Self::Japanese,
            FfiLocale::Korean => Self::Korean,
            FfiLocale::Thai => Self::Thai,
        }
    }
}

impl From<Locale> for FfiLocale {
    fn from(l: Locale) -> Self {
        match l {
            Locale::English => Self::English,
            Locale::TraditionalChinese => Self::TraditionalChinese,
            Locale::SimplifiedChinese => Self::SimplifiedChinese,
            Locale::Japanese => Self::Japanese,
            Locale::Korean => Self::Korean,
            Locale::Thai => Self::Thai,
        }
    }
}

/// 語言選單的一個項目。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiLocaleInfo {
    pub locale: FfiLocale,
    /// BCP-47 標籤。
    pub tag: String,
    /// 該語言自己的名字 —— 語言選單要用母語顯示，
    /// 否則看不懂目前語言的人找不到自己的語言。
    pub endonym: String,
}

/// 支援的語言清單，英文在最前（預設）。
#[uniffi::export]
pub fn supported_locales() -> Vec<FfiLocaleInfo> {
    Locale::ALL
        .iter()
        .map(|l| FfiLocaleInfo {
            locale: (*l).into(),
            tag: l.tag().to_string(),
            endonym: l.endonym().to_string(),
        })
        .collect()
}

/// 由系統語言標籤挑語言。無法對應時回傳英文（預設）。
#[uniffi::export]
pub fn locale_for_tag(tag: String) -> FfiLocale {
    Locale::from_tag_or_default(&tag).into()
}

/// 一組已在地化的按鈕文字。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiToolInfo {
    pub tool: FfiTool,
    pub label: String,
    pub group: FfiToolGroup,
    pub visible: bool,
}

/// 一個分組與其工具。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiToolGroupInfo {
    pub group: FfiToolGroup,
    pub label: String,
    pub tools: Vec<FfiToolInfo>,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiTool {
    FountainPen,
    BallPoint,
    Highlighter,
    Pencil,
    Eraser,
    Lasso,
    Text,
    Image,
    Shape,
    Table,
    Embed,
    Undo,
    Redo,
    Ruler,
    ShapeRecognition,
    ZoomWrite,
    LaserPointer,
    Record,
}

impl From<FfiTool> for Tool {
    fn from(t: FfiTool) -> Self {
        match t {
            FfiTool::FountainPen => Self::FountainPen,
            FfiTool::BallPoint => Self::BallPoint,
            FfiTool::Highlighter => Self::Highlighter,
            FfiTool::Pencil => Self::Pencil,
            FfiTool::Eraser => Self::Eraser,
            FfiTool::Lasso => Self::Lasso,
            FfiTool::Text => Self::Text,
            FfiTool::Image => Self::Image,
            FfiTool::Shape => Self::Shape,
            FfiTool::Table => Self::Table,
            FfiTool::Embed => Self::Embed,
            FfiTool::Undo => Self::Undo,
            FfiTool::Redo => Self::Redo,
            FfiTool::Ruler => Self::Ruler,
            FfiTool::ShapeRecognition => Self::ShapeRecognition,
            FfiTool::ZoomWrite => Self::ZoomWrite,
            FfiTool::LaserPointer => Self::LaserPointer,
            FfiTool::Record => Self::Record,
        }
    }
}

impl From<Tool> for FfiTool {
    fn from(t: Tool) -> Self {
        match t {
            Tool::FountainPen => Self::FountainPen,
            Tool::BallPoint => Self::BallPoint,
            Tool::Highlighter => Self::Highlighter,
            Tool::Pencil => Self::Pencil,
            Tool::Eraser => Self::Eraser,
            Tool::Lasso => Self::Lasso,
            Tool::Text => Self::Text,
            Tool::Image => Self::Image,
            Tool::Shape => Self::Shape,
            Tool::Table => Self::Table,
            Tool::Embed => Self::Embed,
            Tool::Undo => Self::Undo,
            Tool::Redo => Self::Redo,
            Tool::Ruler => Self::Ruler,
            Tool::ShapeRecognition => Self::ShapeRecognition,
            Tool::ZoomWrite => Self::ZoomWrite,
            Tool::LaserPointer => Self::LaserPointer,
            Tool::Record => Self::Record,
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiToolGroup {
    Pens,
    Edit,
    Insert,
    History,
    Extras,
}

impl From<FfiToolGroup> for ToolGroup {
    fn from(g: FfiToolGroup) -> Self {
        match g {
            FfiToolGroup::Pens => Self::Pens,
            FfiToolGroup::Edit => Self::Edit,
            FfiToolGroup::Insert => Self::Insert,
            FfiToolGroup::History => Self::History,
            FfiToolGroup::Extras => Self::Extras,
        }
    }
}

impl From<ToolGroup> for FfiToolGroup {
    fn from(g: ToolGroup) -> Self {
        match g {
            ToolGroup::Pens => Self::Pens,
            ToolGroup::Edit => Self::Edit,
            ToolGroup::Insert => Self::Insert,
            ToolGroup::History => Self::History,
            ToolGroup::Extras => Self::Extras,
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiPlacement {
    Top,
    Bottom,
    Left,
    Right,
    Collapsed,
}

impl From<FfiPlacement> for Placement {
    fn from(p: FfiPlacement) -> Self {
        match p {
            FfiPlacement::Top => Self::Top,
            FfiPlacement::Bottom => Self::Bottom,
            FfiPlacement::Left => Self::Left,
            FfiPlacement::Right => Self::Right,
            FfiPlacement::Collapsed => Self::Collapsed,
        }
    }
}

impl From<Placement> for FfiPlacement {
    fn from(p: Placement) -> Self {
        match p {
            Placement::Top => Self::Top,
            Placement::Bottom => Self::Bottom,
            Placement::Left => Self::Left,
            Placement::Right => Self::Right,
            Placement::Collapsed => Self::Collapsed,
        }
    }
}

/// 工具列設定的 handle。
///
/// 內含 `Mutex`：UniFFI 的物件可能被多執行緒觸及，
/// 而設定的讀寫都很短，鎖的代價可以忽略。
#[derive(Debug, uniffi::Object)]
pub struct FfiToolbar {
    inner: Mutex<ToolbarConfig>,
    locale: Mutex<Locale>,
}

#[uniffi::export]
impl FfiToolbar {
    /// 以某語言的預設值建立。
    #[uniffi::constructor]
    pub fn new(locale: FfiLocale) -> Self {
        let locale: Locale = locale.into();
        Self {
            inner: Mutex::new(ToolbarConfig::for_locale(locale)),
            locale: Mutex::new(locale),
        }
    }

    /// 從先前存下的 JSON 還原。損毀的內容會回到預設值而非失敗 ——
    /// 偏好設定壞掉不該讓應用程式開不起來。
    #[uniffi::constructor]
    pub fn from_json(locale: FfiLocale, json: String) -> Self {
        Self {
            inner: Mutex::new(ToolbarConfig::from_json(&json)),
            locale: Mutex::new(locale.into()),
        }
    }

    /// 切換介面語言。標籤會在下次查詢時重新取得。
    pub fn set_locale(&self, locale: FfiLocale) {
        *self.locale.lock().unwrap() = locale.into();
    }

    pub fn locale(&self) -> FfiLocale {
        (*self.locale.lock().unwrap()).into()
    }

    /// 目前顯示中的工具，依分組排列 —— 這是畫工具列要的資料。
    pub fn visible_groups(&self) -> Vec<FfiToolGroupInfo> {
        let locale = *self.locale.lock().unwrap();
        let cfg = self.inner.lock().unwrap();
        cfg.visible_tools()
            .into_iter()
            .map(|(g, tools)| group_info(g, tools, &cfg, locale))
            .collect()
    }

    /// 全部工具（含隱藏的），供「自訂工具列」設定畫面使用。
    pub fn all_groups(&self) -> Vec<FfiToolGroupInfo> {
        let locale = *self.locale.lock().unwrap();
        let cfg = self.inner.lock().unwrap();
        padnote_toolbar::all_groups()
            .into_iter()
            .map(|(g, tools)| group_info(g, tools, &cfg, locale))
            .collect()
    }

    pub fn is_visible(&self, tool: FfiTool) -> bool {
        self.inner.lock().unwrap().is_visible(tool.into())
    }

    pub fn set_visible(&self, tool: FfiTool, visible: bool) {
        self.inner.lock().unwrap().set_visible(tool.into(), visible);
    }

    pub fn placement(&self) -> FfiPlacement {
        self.inner.lock().unwrap().placement.into()
    }

    pub fn set_placement(&self, placement: FfiPlacement) {
        self.inner.lock().unwrap().placement = placement.into();
    }

    pub fn show_labels(&self) -> bool {
        self.inner.lock().unwrap().show_labels
    }

    pub fn set_show_labels(&self, show: bool) {
        self.inner.lock().unwrap().show_labels = show;
    }

    pub fn set_group_order(&self, order: Vec<FfiToolGroup>) {
        self.inner
            .lock()
            .unwrap()
            .set_group_order(order.into_iter().map(Into::into).collect());
    }

    /// 回到出廠設定。
    pub fn reset(&self) {
        self.inner.lock().unwrap().reset();
    }

    /// 序列化供平台端持久化。
    pub fn to_json(&self) -> String {
        self.inner.lock().unwrap().to_json()
    }
}

fn group_info(
    group: ToolGroup,
    tools: Vec<Tool>,
    cfg: &ToolbarConfig,
    locale: Locale,
) -> FfiToolGroupInfo {
    FfiToolGroupInfo {
        group: group.into(),
        label: catalog::text(group.label_key(), locale).to_string(),
        tools: tools
            .into_iter()
            .map(|t| FfiToolInfo {
                tool: t.into(),
                label: catalog::text(t.label_key(), locale).to_string(),
                group: group.into(),
                visible: cfg.is_visible(t),
            })
            .collect(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_locale_reaches_the_platform_layer() {
        let list = supported_locales();
        assert_eq!(list.len(), padnote_i18n::LOCALE_COUNT);
        assert_eq!(list[0].tag, "en", "英文必須是第一個（預設）");
        for l in &list {
            assert!(!l.endonym.is_empty(), "{} 缺母語名稱", l.tag);
        }
    }

    #[test]
    fn every_tool_survives_the_round_trip() {
        for t in padnote_toolbar::tools::all_tools() {
            let there: FfiTool = t.into();
            assert_eq!(Tool::from(there), t, "{t:?} 轉換不對稱");
        }
    }

    #[test]
    fn labels_change_with_the_locale() {
        let tb = FfiToolbar::new(FfiLocale::English);
        let en = tb.all_groups();
        tb.set_locale(FfiLocale::Japanese);
        let ja = tb.all_groups();
        assert_ne!(
            en[0].tools[0].label, ja[0].tools[0].label,
            "切換語言後標籤沒變，表示語言沒有真的傳到查表"
        );
        assert!(!ja[0].label.is_empty());
    }

    #[test]
    fn visibility_survives_a_save_and_reload() {
        let tb = FfiToolbar::new(FfiLocale::TraditionalChinese);
        tb.set_visible(FfiTool::Ruler, true);
        tb.set_placement(FfiPlacement::Left);
        let json = tb.to_json();

        let back = FfiToolbar::from_json(FfiLocale::TraditionalChinese, json);
        assert!(back.is_visible(FfiTool::Ruler));
        assert_eq!(back.placement(), FfiPlacement::Left);
    }

    #[test]
    fn visible_groups_is_a_subset_of_all_groups() {
        let tb = FfiToolbar::new(FfiLocale::English);
        let visible: usize = tb.visible_groups().iter().map(|g| g.tools.len()).sum();
        let all: usize = tb.all_groups().iter().map(|g| g.tools.len()).sum();
        assert!(visible < all, "預設應該有工具是隱藏的：{visible} / {all}");
        assert!(visible > 0);
    }

    #[test]
    fn long_text_languages_default_to_icons_only() {
        // 泰文標籤明顯比英文長，預設開文字會爆版。
        assert!(!FfiToolbar::new(FfiLocale::Thai).show_labels());
        assert!(FfiToolbar::new(FfiLocale::English).show_labels());
    }
}
