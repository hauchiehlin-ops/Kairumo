//! 圖表規格 —— 使用者編輯的那份資料。
//!
//! 以 JSON 在平台與核心之間往返，並**原樣存進筆記檔**（走
//! `SetBlockAppearance`）。存的是規格不是圖片，所以隨時能重新編修。

use serde::{Deserialize, Serialize};

/// 圖表類型。
///
/// 種類刻意涵蓋 Office 使用者會預期的那幾種 —— 只有長條／折線／圓餅三種的話，
/// 大多數真實的表格畫不出想要的樣子。
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ChartKind {
    /// 直立長條
    Bar,
    /// 堆疊長條
    StackedBar,
    /// 水平長條（類別名稱很長時唯一可讀的選擇）
    HorizontalBar,
    /// 折線
    Line,
    /// 平滑折線
    SmoothLine,
    /// 區域
    Area,
    /// 堆疊區域
    StackedArea,
    /// 圓餅
    Pie,
    /// 環圈
    Doughnut,
    /// 散佈
    Scatter,
    /// 雷達
    Radar,
}

impl ChartKind {
    /// 這種圖是否有直角座標軸。圓餅與雷達沒有。
    pub fn has_cartesian_axes(self) -> bool {
        !matches!(self, Self::Pie | Self::Doughnut | Self::Radar)
    }

    /// 這種圖是否把多個資料數列疊加。
    pub fn is_stacked(self) -> bool {
        matches!(self, Self::StackedBar | Self::StackedArea)
    }

    /// 這種圖是否只畫第一個數列。
    ///
    /// 圓餅與環圈用一個數列的各項當扇形 —— 丟第二個數列進去沒有意義，
    /// 而默默把它畫上去會得到一個誰也看不懂的圖。
    pub fn uses_single_series(self) -> bool {
        matches!(self, Self::Pie | Self::Doughnut)
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum LegendPosition {
    None,
    Top,
    Bottom,
    Right,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum LabelPosition {
    None,
    /// 長條頂端外側、折線點上方
    Outside,
    /// 長條內側（堆疊圖唯一可讀的位置）
    Inside,
    Center,
}

/// 一個座標軸。
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct AxisSpec {
    pub title: String,
    pub show_line: bool,
    pub show_ticks: bool,
    pub show_labels: bool,
    pub show_grid: bool,
    /// 固定最小值。`None` 由資料決定。
    pub min: Option<f64>,
    pub max: Option<f64>,
    /// 刻度間距。`None` 由「好看的數字」演算法決定。
    pub step: Option<f64>,
}

impl Default for AxisSpec {
    fn default() -> Self {
        Self {
            title: String::new(),
            show_line: true,
            show_ticks: true,
            show_labels: true,
            show_grid: false,
            min: None,
            max: None,
            step: None,
        }
    }
}

/// 一個資料數列。
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Series {
    pub name: String,
    pub values: Vec<f64>,
    /// `#RRGGBB`。空字串代表用預設色盤依序取色。
    pub color_hex: String,
    /// 只對混合圖有意義：這個數列要用哪種畫法。
    pub kind_override: Option<ChartKind>,
}

/// 一張圖表的完整規格。
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct ChartSpec {
    pub kind: ChartKind,
    pub title: String,
    /// 類別名稱（X 軸）。長度不足時以空字串補齊。
    pub categories: Vec<String>,
    pub series: Vec<Series>,

    pub legend: LegendPosition,
    pub data_labels: LabelPosition,
    /// 資料標籤的小數位數。
    pub label_decimals: u32,

    pub x_axis: AxisSpec,
    pub y_axis: AxisSpec,

    /// 長條佔類別寬度的比例（0.1–1.0）。Excel 的「類別間距」反過來講同一件事。
    pub bar_width_ratio: f64,
    /// 環圈的內徑比例（0.0–0.9）。只對 `Doughnut` 有意義。
    pub doughnut_hole_ratio: f64,
}

impl Default for ChartSpec {
    fn default() -> Self {
        Self {
            kind: ChartKind::Bar,
            title: String::new(),
            categories: Vec::new(),
            series: Vec::new(),
            legend: LegendPosition::Bottom,
            data_labels: LabelPosition::None,
            label_decimals: 0,
            x_axis: AxisSpec::default(),
            y_axis: AxisSpec {
                show_grid: true,
                ..AxisSpec::default()
            },
            bar_width_ratio: 0.7,
            doughnut_hole_ratio: 0.55,
        }
    }
}

#[derive(Debug, PartialEq, Eq)]
pub enum SpecError {
    /// JSON 解析失敗。
    Malformed(String),
    /// 沒有任何資料數列。
    NoSeries,
    /// 所有數列都是空的。
    NoValues,
}

impl std::fmt::Display for SpecError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Malformed(m) => write!(f, "圖表設定格式錯誤：{m}"),
            Self::NoSeries => write!(f, "圖表沒有任何資料數列"),
            Self::NoValues => write!(f, "圖表的資料數列都是空的"),
        }
    }
}

impl std::error::Error for SpecError {}

impl ChartSpec {
    pub fn from_json(json: &str) -> Result<Self, SpecError> {
        serde_json::from_str(json).map_err(|e| SpecError::Malformed(e.to_string()))
    }

    pub fn to_json(&self) -> String {
        serde_json::to_string(self).unwrap_or_else(|_| "{}".into())
    }

    /// 實際會被畫出來的數列。
    ///
    /// 圓餅與環圈只吃第一個 —— 丟第二個進去沒有意義，而默默畫上去會得到
    /// 一個誰也看不懂的圖。
    pub fn effective_series(&self) -> &[Series] {
        if self.kind.uses_single_series() {
            &self.series[..self.series.len().min(1)]
        } else {
            &self.series
        }
    }

    /// 最長的數列有幾個點。
    pub fn point_count(&self) -> usize {
        self.series
            .iter()
            .map(|s| s.values.len())
            .max()
            .unwrap_or(0)
    }

    pub fn validate(&self) -> Result<(), SpecError> {
        if self.series.is_empty() {
            return Err(SpecError::NoSeries);
        }
        if self.point_count() == 0 {
            return Err(SpecError::NoValues);
        }
        Ok(())
    }

    /// 第 `index` 個類別的名稱。缺的時候用序號補 —— 留空白會讓軸看起來壞掉。
    pub fn category(&self, index: usize) -> String {
        self.categories
            .get(index)
            .filter(|s| !s.is_empty())
            .cloned()
            .unwrap_or_else(|| (index + 1).to_string())
    }

    /// 第 `index` 個數列的顏色。
    pub fn series_color(&self, index: usize) -> String {
        match self.series.get(index) {
            Some(s) if !s.color_hex.is_empty() => s.color_hex.clone(),
            _ => palette_color(index),
        }
    }

    /// 圓餅／環圈第 `index` 塊的顏色。
    ///
    /// 刻意**不**走 [`Self::series_color`]：那裡的 index 是數列編號，而這裡的
    /// index 是同一個數列裡的第幾項。混用的話第二塊扇形會拿到第二個數列的
    /// 顏色 —— 而那個數列根本沒有被畫出來。
    pub fn slice_color(&self, index: usize) -> String {
        palette_color(index)
    }
}

/// 依序取色盤的顏色，超過就繞回來。
pub fn palette_color(index: usize) -> String {
    DEFAULT_PALETTE[index % DEFAULT_PALETTE.len()].to_string()
}

/// 預設色盤。
///
/// 相鄰的顏色刻意拉開色相差 —— 相近的顏色在長條圖上分不出是哪個數列，
/// 列印成灰階時更是完全一樣。
pub const DEFAULT_PALETTE: &[&str] = &[
    "#1E6FD9", "#E8710A", "#1E8E3E", "#D93025", "#9334E6", "#00838F", "#C2185B", "#5D4037",
];
