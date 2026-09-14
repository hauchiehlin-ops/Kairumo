//! 數字製圖的 FFI。
//!
//! # 為什麼規格走 JSON、幾何走結構
//!
//! 進去的 [`ChartSpec`] 是 JSON 字串，出來的版面是具型別的結構。這不是偷懶：
//!
//! - 規格是**存進筆記檔的東西**（走 `set_block_appearance`）。平台兩邊本來就
//!   要能讀寫這份 JSON，把它再鏡射成一套 FFI 結構只會多出一組會漂移的定義；
//!   而且日後規格加欄位時，不需要動 FFI、不需要重新產生綁定、舊版也還打得開。
//! - 幾何是**畫圖時每一幀都要用的東西**。那必須是具型別的結構，字串解析放在
//!   繪製迴圈裡太慢，也讓平台層有機會各自解錯。
//!
//! 平台層拿到版面之後只負責「把這些形狀畫出來」，不做任何換算。

use padnote_chart::{ChartLayout, ChartSpec, LayoutError, TextAlign, layout};

/// 一條線段（格線、軸線、雷達的射線）。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiChartLine {
    pub x1: f64,
    pub y1: f64,
    pub x2: f64,
    pub y2: f64,
}

/// 文字的對齊方式。
#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum FfiTextAlign {
    Leading,
    Center,
    Trailing,
}

impl From<TextAlign> for FfiTextAlign {
    fn from(a: TextAlign) -> Self {
        match a {
            TextAlign::Leading => Self::Leading,
            TextAlign::Center => Self::Center,
            TextAlign::Trailing => Self::Trailing,
        }
    }
}

/// 軸上的一個刻度：刻度線本身，加上它的標籤該畫在哪。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiChartTick {
    pub x: f64,
    pub y: f64,
    pub x2: f64,
    pub y2: f64,
    pub label: String,
    pub label_x: f64,
    pub label_y: f64,
    pub align: FfiTextAlign,
}

/// 一根長條。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiChartBar {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
    pub series_index: u32,
    pub point_index: u32,
    pub color_hex: String,
    pub value: f64,
}

/// 折線、區域或雷達輪廓上的一個頂點。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiChartPoint {
    pub x: f64,
    pub y: f64,
    pub series_index: u32,
    pub point_index: u32,
    /// 使用者輸入的原始值（堆疊圖不是累加後的值）。點選命中測試時要顯示這個。
    pub value: f64,
}

/// 一條折線或一塊區域。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiChartPolyline {
    pub points: Vec<FfiChartPoint>,
    pub series_index: u32,
    pub color_hex: String,
    /// 要以平滑曲線連接頂點（平台各自用 Catmull-Rom 轉貝茲）。
    pub smooth: bool,
    /// 有值代表要填色到這條 y；`None` 代表只畫線。
    pub fill_to_y: Option<f64>,
    pub show_markers: bool,
}

/// 圓餅或環圈的一塊。角度以弧度計，0 指正上方、順時針為正。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiChartSlice {
    pub center_x: f64,
    pub center_y: f64,
    pub radius: f64,
    /// 環圈的內徑；圓餅為 0。
    pub inner_radius: f64,
    pub start_angle: f64,
    pub end_angle: f64,
    pub point_index: u32,
    pub color_hex: String,
    pub value: f64,
    pub fraction: f64,
}

/// 圖例的一項。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiChartLegendEntry {
    pub swatch_x: f64,
    pub swatch_y: f64,
    pub swatch_size: f64,
    pub text_x: f64,
    pub text_y: f64,
    pub text: String,
    pub color_hex: String,
}

/// 一段要畫的文字。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiChartLabel {
    pub x: f64,
    pub y: f64,
    pub text: String,
    pub font_size: f64,
    pub align: FfiTextAlign,
    /// 空字串代表用平台的前景色（才能跟著深淺色模式走）。
    pub color_hex: String,
    /// 旋轉角，弧度。Y 軸標題是 -π/2。
    pub rotation: f64,
}

/// 一張算好的圖。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiChartLayout {
    pub width: f64,
    pub height: f64,
    pub plot_x: f64,
    pub plot_y: f64,
    pub plot_width: f64,
    pub plot_height: f64,

    pub grid_lines: Vec<FfiChartLine>,
    pub axis_lines: Vec<FfiChartLine>,
    pub x_ticks: Vec<FfiChartTick>,
    pub y_ticks: Vec<FfiChartTick>,

    pub bars: Vec<FfiChartBar>,
    pub polylines: Vec<FfiChartPolyline>,
    pub scatter_points: Vec<FfiChartPoint>,
    pub slices: Vec<FfiChartSlice>,
    /// 雷達的同心格線，每一圈是一串頂點。
    pub radar_rings: Vec<Vec<FfiChartPoint>>,
    pub radar_spokes: Vec<FfiChartLine>,

    pub legend: Vec<FfiChartLegendEntry>,
    pub labels: Vec<FfiChartLabel>,
}

/// 圖表算不出來的原因。
///
/// 欄位叫 `reason` 而不是 `message`：UniFFI 產生的 Kotlin 錯誤繼承自
/// `Throwable`，而 `Throwable` 已經有一個 `message` —— 撞名會讓 Kotlin 端
/// 整份綁定編不過。
#[derive(Debug, uniffi::Error)]
pub enum FfiChartError {
    /// 圖表設定讀不懂。訊息可以直接顯示給使用者。
    BadSpec { reason: String },
    /// 畫布小到放不下圖表。
    TooSmall { reason: String },
}

impl std::fmt::Display for FfiChartError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::BadSpec { reason } | Self::TooSmall { reason } => write!(f, "{reason}"),
        }
    }
}

impl std::error::Error for FfiChartError {}

impl From<LayoutError> for FfiChartError {
    fn from(e: LayoutError) -> Self {
        match e {
            LayoutError::TooSmall => Self::TooSmall {
                reason: e.to_string(),
            },
            LayoutError::Spec(_) => Self::BadSpec {
                reason: e.to_string(),
            },
        }
    }
}

fn convert(l: ChartLayout) -> FfiChartLayout {
    let line = |g: padnote_chart::GridLine| FfiChartLine {
        x1: g.x1,
        y1: g.y1,
        x2: g.x2,
        y2: g.y2,
    };
    let tick = |t: padnote_chart::TickMark| FfiChartTick {
        x: t.x,
        y: t.y,
        x2: t.x2,
        y2: t.y2,
        label: t.label,
        label_x: t.label_x,
        label_y: t.label_y,
        align: t.align.into(),
    };
    let point = |p: padnote_chart::PlotPoint| FfiChartPoint {
        x: p.x,
        y: p.y,
        series_index: p.series_index as u32,
        point_index: p.point_index as u32,
        value: p.value,
    };

    FfiChartLayout {
        width: l.width,
        height: l.height,
        plot_x: l.plot_x,
        plot_y: l.plot_y,
        plot_width: l.plot_width,
        plot_height: l.plot_height,
        grid_lines: l.grid_lines.into_iter().map(line).collect(),
        axis_lines: l.axis_lines.into_iter().map(line).collect(),
        x_ticks: l.x_ticks.into_iter().map(tick).collect(),
        y_ticks: l.y_ticks.into_iter().map(tick).collect(),
        bars: l
            .bars
            .into_iter()
            .map(|b| FfiChartBar {
                x: b.x,
                y: b.y,
                width: b.width,
                height: b.height,
                series_index: b.series_index as u32,
                point_index: b.point_index as u32,
                color_hex: b.color_hex,
                value: b.value,
            })
            .collect(),
        polylines: l
            .polylines
            .into_iter()
            .map(|p| FfiChartPolyline {
                points: p.points.into_iter().map(point).collect(),
                series_index: p.series_index as u32,
                color_hex: p.color_hex,
                smooth: p.smooth,
                fill_to_y: p.fill_to_y,
                show_markers: p.show_markers,
            })
            .collect(),
        scatter_points: l.scatter_points.into_iter().map(point).collect(),
        slices: l
            .slices
            .into_iter()
            .map(|s| FfiChartSlice {
                center_x: s.center_x,
                center_y: s.center_y,
                radius: s.radius,
                inner_radius: s.inner_radius,
                start_angle: s.start_angle,
                end_angle: s.end_angle,
                point_index: s.point_index as u32,
                color_hex: s.color_hex,
                value: s.value,
                fraction: s.fraction,
            })
            .collect(),
        radar_rings: l
            .radar_rings
            .into_iter()
            .map(|r| r.into_iter().map(point).collect())
            .collect(),
        radar_spokes: l.radar_spokes.into_iter().map(line).collect(),
        legend: l
            .legend
            .into_iter()
            .map(|e| FfiChartLegendEntry {
                swatch_x: e.swatch_x,
                swatch_y: e.swatch_y,
                swatch_size: e.swatch_size,
                text_x: e.text_x,
                text_y: e.text_y,
                text: e.text,
                color_hex: e.color_hex,
            })
            .collect(),
        labels: l
            .labels
            .into_iter()
            .map(|t| FfiChartLabel {
                x: t.x,
                y: t.y,
                text: t.text,
                font_size: t.font_size,
                align: t.align.into(),
                color_hex: t.color_hex,
                rotation: t.rotation,
            })
            .collect(),
    }
}

/// 把圖表設定算成幾何。
///
/// `spec_json` 是存在區塊外觀裡的那份設定（見 `set_block_appearance`）。
/// 兩個平台傳同一份設定、同一個尺寸進來，就會拿到位元相同的版面。
#[uniffi::export]
pub fn chart_layout(
    spec_json: String,
    width: f64,
    height: f64,
) -> Result<FfiChartLayout, FfiChartError> {
    let spec = ChartSpec::from_json(&spec_json).map_err(|e| FfiChartError::BadSpec {
        reason: e.to_string(),
    })?;
    Ok(convert(layout(&spec, width, height)?))
}

/// 這份設定能不能畫出圖來。
///
/// 給編輯介面用：使用者把最後一列資料刪掉時，要先擋下來再說，而不是讓畫布
/// 忽然變成空白。
#[uniffi::export]
pub fn chart_spec_is_drawable(spec_json: String) -> bool {
    ChartSpec::from_json(&spec_json)
        .map(|s| s.validate().is_ok())
        .unwrap_or(false)
}

/// 一份可以直接畫的預設設定。
///
/// 新插入的圖表要馬上看得到東西 —— 空白的圖表看起來像壞掉了，使用者不會知道
/// 接下來該做什麼。
#[uniffi::export]
pub fn chart_default_spec_json() -> String {
    ChartSpec {
        kind: padnote_chart::ChartKind::Bar,
        categories: vec!["Q1".into(), "Q2".into(), "Q3".into(), "Q4".into()],
        series: vec![padnote_chart::Series {
            name: String::new(),
            values: vec![32.0, 48.0, 27.0, 55.0],
            ..Default::default()
        }],
        ..Default::default()
    }
    .to_json()
}

/// 預設色盤的第 `index` 色。
///
/// 編輯介面的取色器要跟畫出來的顏色一致，所以取色器也走這裡，不要各自寫一份
/// 色碼 —— 抄第二份的那一刻就開始漂移了。
#[uniffi::export]
pub fn chart_palette_color(index: u32) -> String {
    padnote_chart::palette_color(index as usize)
}

/// 預設色盤有幾色。
#[uniffi::export]
pub fn chart_palette_count() -> u32 {
    padnote_chart::DEFAULT_PALETTE.len() as u32
}

#[cfg(test)]
mod tests {
    use super::*;

    fn spec_json() -> String {
        r#"{
            "kind": "bar",
            "title": "季度營收",
            "categories": ["Q1", "Q2"],
            "series": [{"name": "北區", "values": [10, 20]}],
            "dataLabels": "outside"
        }"#
        .into()
    }

    #[test]
    fn layout_crosses_the_boundary_intact() {
        // 轉換表漏一個欄位，平台那邊就是靜靜地少畫一塊 —— 不會有任何錯誤。
        let l = chart_layout(spec_json(), 480.0, 320.0).unwrap();
        assert_eq!(l.bars.len(), 2);
        assert_eq!(l.legend.len(), 1);
        assert!(!l.y_ticks.is_empty(), "Y 軸刻度沒有跨過 FFI");
        assert!(!l.grid_lines.is_empty(), "格線沒有跨過 FFI");
        assert!(
            l.labels.iter().any(|t| t.text == "季度營收"),
            "標題沒有跨過 FFI"
        );
        assert!(
            l.labels.iter().any(|t| t.text == "10"),
            "資料標籤沒有跨過 FFI"
        );
    }

    #[test]
    fn pie_geometry_crosses_the_boundary() {
        let json = r#"{"kind":"pie","series":[{"values":[1,1,2]}]}"#.to_string();
        let l = chart_layout(json, 400.0, 400.0).unwrap();
        assert_eq!(l.slices.len(), 3);
        assert!((l.slices[2].fraction - 0.5).abs() < 1e-9);
    }

    #[test]
    fn radar_rings_cross_the_boundary() {
        let json = r#"{"kind":"radar","categories":["a","b","c"],"series":[{"values":[1,2,3]}]}"#
            .to_string();
        let l = chart_layout(json, 400.0, 400.0).unwrap();
        assert_eq!(l.radar_spokes.len(), 3);
        assert!(l.radar_rings.iter().all(|r| r.len() == 3));
    }

    #[test]
    fn a_malformed_spec_reports_a_readable_reason() {
        let err = chart_layout("{ not json".into(), 400.0, 300.0).unwrap_err();
        assert!(matches!(err, FfiChartError::BadSpec { .. }));
        assert!(!err.to_string().is_empty(), "錯誤訊息會直接顯示給使用者");
    }

    #[test]
    fn a_tiny_canvas_is_reported_separately_from_a_bad_spec() {
        // 兩者在介面上的處置完全不同：一個要請使用者改資料，一個只是把圖拉大。
        let err = chart_layout(spec_json(), 10.0, 10.0).unwrap_err();
        assert!(matches!(err, FfiChartError::TooSmall { .. }));
    }

    #[test]
    fn the_default_spec_is_drawable() {
        // 新插入的圖表必須馬上看得到東西，空白的圖表看起來像壞掉了。
        let json = chart_default_spec_json();
        assert!(chart_spec_is_drawable(json.clone()));
        assert!(!chart_layout(json, 400.0, 300.0).unwrap().bars.is_empty());
    }

    #[test]
    fn an_empty_spec_is_not_drawable() {
        assert!(!chart_spec_is_drawable(r#"{"series":[]}"#.into()));
        assert!(!chart_spec_is_drawable("garbage".into()));
    }

    #[test]
    fn the_palette_is_shared_with_the_platforms() {
        // 取色器抄第二份色碼的那一刻就開始漂移了。
        assert!(chart_palette_count() >= 8);
        assert!(chart_palette_color(0).starts_with('#'));
        assert_eq!(
            chart_palette_color(0),
            chart_palette_color(chart_palette_count()),
            "色盤要繞回來"
        );
    }
}
