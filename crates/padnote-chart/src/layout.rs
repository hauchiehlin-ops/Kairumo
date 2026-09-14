//! 把 [`ChartSpec`] 算成幾何。
//!
//! 輸出的每一個座標都是「畫布左上角為原點、向右向下為正」的點，平台層直接
//! 拿去畫就好，不需要再做任何換算 —— 換算一旦分散到兩個平台，兩邊遲早會
//! 算出不同的結果。
//!
//! 這裡不碰字型。核心量不到實際的字寬，所以文字的佔位一律用
//! [`estimate_text_width`] 的近似值。重點不是精準，而是**兩個平台用同一個
//! 近似值** —— 各自去問系統字型的話，同一張圖在兩邊的軸就會退到不同位置。

use crate::spec::{ChartKind, ChartSpec, LabelPosition, LegendPosition, SpecError};

/// 一條格線或軸線。
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct GridLine {
    pub x1: f64,
    pub y1: f64,
    pub x2: f64,
    pub y2: f64,
}

/// 軸上的一個刻度。
#[derive(Clone, Debug, PartialEq)]
pub struct TickMark {
    pub x: f64,
    pub y: f64,
    /// 刻度線的另一端。
    pub x2: f64,
    pub y2: f64,
    pub label: String,
    /// 標籤的錨點。
    pub label_x: f64,
    pub label_y: f64,
    pub align: TextAlign,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TextAlign {
    Leading,
    Center,
    Trailing,
}

/// 一根長條。
#[derive(Clone, Debug, PartialEq)]
pub struct PlotBar {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
    pub series_index: usize,
    pub point_index: usize,
    pub color_hex: String,
    pub value: f64,
}

/// 折線／散佈上的一個點。
#[derive(Clone, Debug, PartialEq)]
pub struct PlotPoint {
    pub x: f64,
    pub y: f64,
    pub series_index: usize,
    pub point_index: usize,
    pub value: f64,
}

/// 一條折線或一塊區域。
#[derive(Clone, Debug, PartialEq)]
pub struct PlotPolyline {
    pub points: Vec<PlotPoint>,
    pub series_index: usize,
    pub color_hex: String,
    /// 要不要平滑（以 Catmull-Rom 轉貝茲，平台各自實作）。
    pub smooth: bool,
    /// 要填滿到基線就給基線的 y；`None` 代表只畫線。
    pub fill_to_y: Option<f64>,
    /// 要不要在頂點畫記號。
    pub show_markers: bool,
}

/// 圓餅／環圈的一塊。
#[derive(Clone, Debug, PartialEq)]
pub struct PieSlice {
    pub center_x: f64,
    pub center_y: f64,
    pub radius: f64,
    /// 環圈的內徑；圓餅為 0。
    pub inner_radius: f64,
    /// 起始角，弧度，0 為正上方、順時針為正。
    pub start_angle: f64,
    pub end_angle: f64,
    pub point_index: usize,
    pub color_hex: String,
    pub value: f64,
    /// 佔總和的比例。
    pub fraction: f64,
}

/// 圖例的一項。
#[derive(Clone, Debug, PartialEq)]
pub struct LegendEntry {
    /// 色塊。
    pub swatch_x: f64,
    pub swatch_y: f64,
    pub swatch_size: f64,
    pub text_x: f64,
    pub text_y: f64,
    pub text: String,
    pub color_hex: String,
}

/// 一段要畫的文字（標題、資料標籤、軸標題）。
#[derive(Clone, Debug, PartialEq)]
pub struct TextLabel {
    pub x: f64,
    pub y: f64,
    pub text: String,
    pub font_size: f64,
    pub align: TextAlign,
    /// 空字串代表用平台的前景色。
    pub color_hex: String,
    /// 旋轉角（弧度）。Y 軸標題是 -π/2。
    pub rotation: f64,
}

/// 一張算好的圖。平台層照著畫即可。
#[derive(Clone, Debug, Default)]
pub struct ChartLayout {
    pub width: f64,
    pub height: f64,
    /// 繪圖區（不含標題、軸標籤、圖例）。
    pub plot_x: f64,
    pub plot_y: f64,
    pub plot_width: f64,
    pub plot_height: f64,

    pub grid_lines: Vec<GridLine>,
    pub axis_lines: Vec<GridLine>,
    pub x_ticks: Vec<TickMark>,
    pub y_ticks: Vec<TickMark>,

    pub bars: Vec<PlotBar>,
    pub polylines: Vec<PlotPolyline>,
    pub scatter_points: Vec<PlotPoint>,
    pub slices: Vec<PieSlice>,
    /// 雷達圖的同心格線（每一圈是一串頂點）。
    pub radar_rings: Vec<Vec<PlotPoint>>,
    /// 雷達圖從中心射出的軸。
    pub radar_spokes: Vec<GridLine>,

    pub legend: Vec<LegendEntry>,
    pub labels: Vec<TextLabel>,
}

#[derive(Debug, PartialEq)]
pub enum LayoutError {
    /// 規格本身有問題。
    Spec(SpecError),
    /// 畫布小到放不下任何東西。
    TooSmall,
}

impl std::fmt::Display for LayoutError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Spec(e) => write!(f, "{e}"),
            Self::TooSmall => write!(f, "畫布太小，放不下圖表"),
        }
    }
}

impl std::error::Error for LayoutError {}

const TITLE_FONT: f64 = 17.0;
const AXIS_FONT: f64 = 11.0;
const LABEL_FONT: f64 = 10.0;
const LEGEND_FONT: f64 = 11.0;
const LEGEND_SWATCH: f64 = 10.0;
const TICK_LEN: f64 = 4.0;
const PAD: f64 = 12.0;

/// 估算一段文字的寬度。
///
/// 核心沒有字型資訊，只能近似。CJK 一個字約等於字級的寬度，拉丁字母約 0.55 ——
/// 這個係數不精準，但**兩個平台共用同一個近似值**，所以兩邊的軸會退到同樣的
/// 位置。各自去問系統字型反而會讓同一張圖在兩邊不一樣。
pub fn estimate_text_width(text: &str, font_size: f64) -> f64 {
    text.chars()
        .map(|c| {
            if (c as u32) > 0x2E80 {
                font_size
            } else {
                font_size * 0.55
            }
        })
        .sum()
}

/// 「好看的」刻度間距：1、2、5 的十的次方倍。
///
/// 直接把範圍除以格數會得到 0.3333 這種刻度，軸上就會出現一串沒人想讀的數字。
fn nice_step(raw: f64) -> f64 {
    if raw <= 0.0 || !raw.is_finite() {
        return 1.0;
    }
    let exponent = raw.log10().floor();
    let magnitude = 10f64.powf(exponent);
    let normalized = raw / magnitude;
    let nice = if normalized <= 1.0 {
        1.0
    } else if normalized <= 2.0 {
        2.0
    } else if normalized <= 5.0 {
        5.0
    } else {
        10.0
    };
    nice * magnitude
}

/// 資料的值域。堆疊圖看的是各類別的總和，不是單一數列的最大值。
fn value_range(spec: &ChartSpec) -> (f64, f64) {
    let series = spec.effective_series();
    let mut min = f64::INFINITY;
    let mut max = f64::NEG_INFINITY;

    if spec.kind.is_stacked() {
        for index in 0..spec.point_count() {
            let (mut positive, mut negative) = (0.0, 0.0);
            for s in series {
                let v = s.values.get(index).copied().unwrap_or(0.0);
                if v >= 0.0 {
                    positive += v
                } else {
                    negative += v
                }
            }
            min = min.min(negative);
            max = max.max(positive);
        }
    } else {
        for s in series {
            for &v in &s.values {
                if v.is_finite() {
                    min = min.min(v);
                    max = max.max(v);
                }
            }
        }
    }

    if !min.is_finite() || !max.is_finite() {
        return (0.0, 1.0);
    }
    // 長條圖的基線一定要是 0，否則長條的長度比例會騙人 —— 那是統計圖表
    // 最常見的誤導。折線圖則允許不從 0 起算，因為那裡看的是趨勢。
    if matches!(
        spec.kind,
        ChartKind::Bar
            | ChartKind::StackedBar
            | ChartKind::HorizontalBar
            | ChartKind::Area
            | ChartKind::StackedArea
    ) {
        min = min.min(0.0);
        max = max.max(0.0);
    }
    if (max - min).abs() < f64::EPSILON {
        // 所有值相同：撐開一點，否則等一下會除以零。
        let pad = if max.abs() < f64::EPSILON {
            1.0
        } else {
            max.abs() * 0.5
        };
        min -= pad;
        max += pad;
    }
    (min, max)
}

/// 把值域對齊到好看的刻度，回傳 (下界, 上界, 間距)。
fn axis_scale(spec: &ChartSpec, span_px: f64) -> (f64, f64, f64) {
    let (data_min, data_max) = value_range(spec);
    let min = spec.y_axis.min.unwrap_or(data_min);
    let max_raw = spec.y_axis.max.unwrap_or(data_max);
    let max = if max_raw <= min { min + 1.0 } else { max_raw };

    // 想要的格數由可用像素決定：格子太密會糊成一片。
    let target = (span_px / 48.0).clamp(2.0, 10.0);
    let step = spec
        .y_axis
        .step
        .filter(|s| *s > 0.0)
        .unwrap_or_else(|| nice_step((max - min) / target));

    let lower = (min / step).floor() * step;
    let upper = (max / step).ceil() * step;
    (
        lower,
        if upper <= lower { lower + step } else { upper },
        step,
    )
}

fn format_value(value: f64, decimals: u32) -> String {
    let s = format!("{:.*}", decimals as usize, value);
    // -0 讀起來像錯誤。
    if s.trim_start_matches('-')
        .chars()
        .all(|c| c == '0' || c == '.')
    {
        s.trim_start_matches('-').to_string()
    } else {
        s
    }
}

/// 刻度標籤要幾位小數 —— 間距是 0.5 的時候寫「0」「1」會把中間的刻度寫成重複的數字。
fn tick_decimals(step: f64) -> u32 {
    if step >= 1.0 {
        0
    } else if step >= 0.1 {
        1
    } else if step >= 0.01 {
        2
    } else {
        3
    }
}

/// 算出整張圖的幾何。
///
/// `width` / `height` 是畫布大小（點）。回傳的所有座標都在這個範圍內。
pub fn layout(spec: &ChartSpec, width: f64, height: f64) -> Result<ChartLayout, LayoutError> {
    spec.validate().map_err(LayoutError::Spec)?;
    if width < 60.0 || height < 60.0 {
        return Err(LayoutError::TooSmall);
    }

    let mut out = ChartLayout {
        width,
        height,
        ..Default::default()
    };
    let series = spec.effective_series().to_vec();

    // ── 標題 ──────────────────────────────────────────────
    let mut top = PAD;
    if !spec.title.is_empty() {
        out.labels.push(TextLabel {
            x: width / 2.0,
            y: top + TITLE_FONT,
            text: spec.title.clone(),
            font_size: TITLE_FONT,
            align: TextAlign::Center,
            color_hex: String::new(),
            rotation: 0.0,
        });
        top += TITLE_FONT + PAD;
    }

    // ── 圖例 ──────────────────────────────────────────────
    // 先量出圖例要佔多少，剩下的才是繪圖區。反過來做的話圖例會蓋到圖上。
    let legend_items: Vec<(String, String)> = if spec.kind.uses_single_series() {
        (0..spec.point_count())
            .map(|i| (spec.category(i), spec.slice_color(i)))
            .collect()
    } else {
        series
            .iter()
            .enumerate()
            .map(|(i, s)| {
                let name = if s.name.is_empty() {
                    format!("數列 {}", i + 1)
                } else {
                    s.name.clone()
                };
                (name, spec.series_color(i))
            })
            .collect()
    };

    let mut bottom = height - PAD;
    let mut right = width - PAD;
    let mut left = PAD;

    let legend_width = |items: &[(String, String)]| -> f64 {
        items
            .iter()
            .map(|(t, _)| LEGEND_SWATCH + 5.0 + estimate_text_width(t, LEGEND_FONT))
            .fold(0.0, f64::max)
    };

    match spec.legend {
        LegendPosition::None => {}
        LegendPosition::Right => right -= (legend_width(&legend_items) + PAD).min(width * 0.35),
        LegendPosition::Bottom => bottom -= LEGEND_FONT + PAD,
        LegendPosition::Top => top += LEGEND_FONT + PAD,
    }

    // ── 座標軸留白 ─────────────────────────────────────────
    if spec.kind.has_cartesian_axes() {
        let provisional = (bottom - top).max(40.0);
        let (lo, hi, step) = axis_scale(spec, provisional);
        let decimals = tick_decimals(step);
        let widest = {
            let mut w: f64 = 0.0;
            let mut v = lo;
            while v <= hi + step * 0.5 {
                w = w.max(estimate_text_width(&format_value(v, decimals), AXIS_FONT));
                v += step;
            }
            w
        };
        if spec.y_axis.show_labels {
            left += widest + TICK_LEN + 4.0;
        }
        if !spec.y_axis.title.is_empty() {
            left += AXIS_FONT + 4.0;
        }
        if spec.x_axis.show_labels {
            bottom -= AXIS_FONT + TICK_LEN + 4.0;
        }
        if !spec.x_axis.title.is_empty() {
            bottom -= AXIS_FONT + 4.0;
        }
    }

    if right - left < 20.0 || bottom - top < 20.0 {
        return Err(LayoutError::TooSmall);
    }

    out.plot_x = left;
    out.plot_y = top;
    out.plot_width = right - left;
    out.plot_height = bottom - top;

    match spec.kind {
        ChartKind::Pie | ChartKind::Doughnut => layout_pie(spec, &mut out),
        ChartKind::Radar => layout_radar(spec, &mut out),
        _ => layout_cartesian(spec, &mut out),
    }

    layout_legend(spec, &legend_items, &mut out);
    Ok(out)
}

// ── 直角座標 ────────────────────────────────────────────────

fn layout_cartesian(spec: &ChartSpec, out: &mut ChartLayout) {
    let horizontal = spec.kind == ChartKind::HorizontalBar;
    // 水平長條的「值」沿 x 走，「類別」沿 y 走 —— 兩個方向共用同一段程式，
    // 靠這兩個變數交換。
    let value_span = if horizontal {
        out.plot_width
    } else {
        out.plot_height
    };
    let category_span = if horizontal {
        out.plot_height
    } else {
        out.plot_width
    };

    let (lo, hi, step) = axis_scale(spec, value_span);
    let decimals = tick_decimals(step);
    let to_value_px = |v: f64| -> f64 {
        let t = (v - lo) / (hi - lo);
        if horizontal {
            out.plot_x + t * out.plot_width
        } else {
            // 螢幕的 y 向下增加，值向上增加。
            out.plot_y + out.plot_height - t * out.plot_height
        }
    };

    // 值軸的刻度與格線
    let mut v = lo;
    while v <= hi + step * 0.5 {
        let p = to_value_px(v);
        let text = format_value(v, decimals);
        if horizontal {
            if spec.y_axis.show_grid {
                out.grid_lines.push(GridLine {
                    x1: p,
                    y1: out.plot_y,
                    x2: p,
                    y2: out.plot_y + out.plot_height,
                });
            }
            if spec.x_axis.show_labels {
                out.x_ticks.push(TickMark {
                    x: p,
                    y: out.plot_y + out.plot_height,
                    x2: p,
                    y2: out.plot_y + out.plot_height + TICK_LEN,
                    label: text,
                    label_x: p,
                    label_y: out.plot_y + out.plot_height + TICK_LEN + AXIS_FONT,
                    align: TextAlign::Center,
                });
            }
        } else {
            if spec.y_axis.show_grid {
                out.grid_lines.push(GridLine {
                    x1: out.plot_x,
                    y1: p,
                    x2: out.plot_x + out.plot_width,
                    y2: p,
                });
            }
            if spec.y_axis.show_labels {
                out.y_ticks.push(TickMark {
                    x: out.plot_x,
                    y: p,
                    x2: out.plot_x - TICK_LEN,
                    y2: p,
                    label: text,
                    label_x: out.plot_x - TICK_LEN - 4.0,
                    label_y: p + AXIS_FONT * 0.35,
                    align: TextAlign::Trailing,
                });
            }
        }
        v += step;
    }

    // 軸線
    let baseline = to_value_px(lo.max(0.0).min(hi));
    if spec.x_axis.show_line {
        if horizontal {
            out.axis_lines.push(GridLine {
                x1: out.plot_x,
                y1: out.plot_y + out.plot_height,
                x2: out.plot_x + out.plot_width,
                y2: out.plot_y + out.plot_height,
            });
        } else {
            out.axis_lines.push(GridLine {
                x1: out.plot_x,
                y1: baseline,
                x2: out.plot_x + out.plot_width,
                y2: baseline,
            });
        }
    }
    if spec.y_axis.show_line {
        out.axis_lines.push(GridLine {
            x1: out.plot_x,
            y1: out.plot_y,
            x2: out.plot_x,
            y2: out.plot_y + out.plot_height,
        });
    }

    let count = spec.point_count().max(1);
    let slot = category_span / count as f64;
    let scatter = spec.kind == ChartKind::Scatter;
    // 散佈圖的點落在類別的邊界上（頭尾貼齊），其餘落在類別的中央。
    let category_center = |i: usize| -> f64 {
        let base = if horizontal { out.plot_y } else { out.plot_x };
        if scatter && count > 1 {
            base + category_span * (i as f64 / (count - 1) as f64)
        } else {
            base + slot * (i as f64 + 0.5)
        }
    };

    // 類別軸的標籤
    if (horizontal && spec.y_axis.show_labels) || (!horizontal && spec.x_axis.show_labels) {
        for i in 0..count {
            let c = category_center(i);
            if horizontal {
                out.y_ticks.push(TickMark {
                    x: out.plot_x,
                    y: c,
                    x2: out.plot_x - TICK_LEN,
                    y2: c,
                    label: spec.category(i),
                    label_x: out.plot_x - TICK_LEN - 4.0,
                    label_y: c + AXIS_FONT * 0.35,
                    align: TextAlign::Trailing,
                });
            } else {
                out.x_ticks.push(TickMark {
                    x: c,
                    y: out.plot_y + out.plot_height,
                    x2: c,
                    y2: out.plot_y + out.plot_height + TICK_LEN,
                    label: spec.category(i),
                    label_x: c,
                    label_y: out.plot_y + out.plot_height + TICK_LEN + AXIS_FONT,
                    align: TextAlign::Center,
                });
            }
        }
    }

    // 軸標題
    if !spec.x_axis.title.is_empty() {
        out.labels.push(TextLabel {
            x: out.plot_x + out.plot_width / 2.0,
            y: out.height - PAD,
            text: spec.x_axis.title.clone(),
            font_size: AXIS_FONT,
            align: TextAlign::Center,
            color_hex: String::new(),
            rotation: 0.0,
        });
    }
    if !spec.y_axis.title.is_empty() {
        out.labels.push(TextLabel {
            x: PAD + AXIS_FONT * 0.5,
            y: out.plot_y + out.plot_height / 2.0,
            text: spec.y_axis.title.clone(),
            font_size: AXIS_FONT,
            align: TextAlign::Center,
            color_hex: String::new(),
            rotation: -std::f64::consts::FRAC_PI_2,
        });
    }

    let series = spec.effective_series().to_vec();
    let bar_like = matches!(
        spec.kind,
        ChartKind::Bar | ChartKind::StackedBar | ChartKind::HorizontalBar
    );

    if bar_like {
        let group = slot * spec.bar_width_ratio.clamp(0.1, 1.0);
        let stacked = spec.kind.is_stacked();
        let lanes = if stacked { 1 } else { series.len().max(1) };
        let lane = group / lanes as f64;
        // 堆疊圖要記住每個類別已經疊到哪裡，正負分開往兩邊長。
        let mut stack_positive = vec![0.0f64; count];
        let mut stack_negative = vec![0.0f64; count];

        for (si, s) in series.iter().enumerate() {
            let color = spec.series_color(si);
            for i in 0..count {
                let value = s.values.get(i).copied().unwrap_or(0.0);
                if !value.is_finite() {
                    continue;
                }
                let (from, to) = if stacked {
                    let base = if value >= 0.0 {
                        &mut stack_positive[i]
                    } else {
                        &mut stack_negative[i]
                    };
                    let start = *base;
                    *base += value;
                    (start, *base)
                } else {
                    (lo.max(0.0).min(hi), value)
                };
                let p1 = to_value_px(from);
                let p2 = to_value_px(to);
                let center = category_center(i);
                let lane_start =
                    center - group / 2.0 + lane * if stacked { 0.0 } else { si as f64 };

                let bar = if horizontal {
                    PlotBar {
                        x: p1.min(p2),
                        y: lane_start,
                        width: (p2 - p1).abs(),
                        height: lane,
                        series_index: si,
                        point_index: i,
                        color_hex: color.clone(),
                        value,
                    }
                } else {
                    PlotBar {
                        x: lane_start,
                        y: p1.min(p2),
                        width: lane,
                        height: (p2 - p1).abs(),
                        series_index: si,
                        point_index: i,
                        color_hex: color.clone(),
                        value,
                    }
                };

                if spec.data_labels != LabelPosition::None {
                    let (lx, ly, align) = match (horizontal, spec.data_labels) {
                        (false, LabelPosition::Inside) => (
                            bar.x + bar.width / 2.0,
                            bar.y + LABEL_FONT + 2.0,
                            TextAlign::Center,
                        ),
                        (false, LabelPosition::Center) => (
                            bar.x + bar.width / 2.0,
                            bar.y + bar.height / 2.0 + LABEL_FONT * 0.35,
                            TextAlign::Center,
                        ),
                        (false, _) => (bar.x + bar.width / 2.0, bar.y - 3.0, TextAlign::Center),
                        (true, LabelPosition::Inside) => (
                            bar.x + bar.width - 4.0,
                            bar.y + bar.height / 2.0 + LABEL_FONT * 0.35,
                            TextAlign::Trailing,
                        ),
                        (true, LabelPosition::Center) => (
                            bar.x + bar.width / 2.0,
                            bar.y + bar.height / 2.0 + LABEL_FONT * 0.35,
                            TextAlign::Center,
                        ),
                        (true, _) => (
                            bar.x + bar.width + 4.0,
                            bar.y + bar.height / 2.0 + LABEL_FONT * 0.35,
                            TextAlign::Leading,
                        ),
                    };
                    out.labels.push(TextLabel {
                        x: lx,
                        y: ly,
                        text: format_value(value, spec.label_decimals),
                        font_size: LABEL_FONT,
                        align,
                        color_hex: String::new(),
                        rotation: 0.0,
                    });
                }
                out.bars.push(bar);
            }
        }
        return;
    }

    // 折線／區域／散佈
    let mut stack = vec![0.0f64; count];
    for (si, s) in series.iter().enumerate() {
        let color = spec.series_color(si);
        let mut points = Vec::with_capacity(count);
        for (i, slot) in stack.iter_mut().enumerate() {
            let raw = s.values.get(i).copied().unwrap_or(0.0);
            if !raw.is_finite() {
                continue;
            }
            let value = if spec.kind.is_stacked() {
                *slot += raw;
                *slot
            } else {
                raw
            };
            points.push(PlotPoint {
                x: if horizontal {
                    to_value_px(value)
                } else {
                    category_center(i)
                },
                y: if horizontal {
                    category_center(i)
                } else {
                    to_value_px(value)
                },
                series_index: si,
                point_index: i,
                value: raw,
            });

            if spec.data_labels != LabelPosition::None {
                let p = points.last().unwrap();
                out.labels.push(TextLabel {
                    x: p.x,
                    y: p.y - 5.0,
                    text: format_value(raw, spec.label_decimals),
                    font_size: LABEL_FONT,
                    align: TextAlign::Center,
                    color_hex: String::new(),
                    rotation: 0.0,
                });
            }
        }

        if scatter {
            out.scatter_points.extend(points);
        } else {
            out.polylines.push(PlotPolyline {
                points,
                series_index: si,
                color_hex: color,
                smooth: spec.kind == ChartKind::SmoothLine,
                fill_to_y: matches!(spec.kind, ChartKind::Area | ChartKind::StackedArea)
                    .then_some(baseline),
                show_markers: !matches!(spec.kind, ChartKind::Area | ChartKind::StackedArea),
            });
        }
    }
}

// ── 圓餅／環圈 ──────────────────────────────────────────────

fn layout_pie(spec: &ChartSpec, out: &mut ChartLayout) {
    let Some(series) = spec.effective_series().first() else {
        return;
    };
    // 負值在圓餅圖上沒有意義（扇形沒有「負的角度」），取絕對值。
    let values: Vec<f64> = series
        .values
        .iter()
        .map(|v| if v.is_finite() { v.abs() } else { 0.0 })
        .collect();
    let total: f64 = values.iter().sum();
    if total <= 0.0 {
        return;
    }

    let cx = out.plot_x + out.plot_width / 2.0;
    let cy = out.plot_y + out.plot_height / 2.0;
    let radius = out.plot_width.min(out.plot_height) / 2.0 * 0.9;
    let inner = if spec.kind == ChartKind::Doughnut {
        radius * spec.doughnut_hole_ratio.clamp(0.0, 0.9)
    } else {
        0.0
    };

    let mut angle = 0.0f64;
    for (i, &value) in values.iter().enumerate() {
        let fraction = value / total;
        let sweep = fraction * std::f64::consts::TAU;
        out.slices.push(PieSlice {
            center_x: cx,
            center_y: cy,
            radius,
            inner_radius: inner,
            start_angle: angle,
            end_angle: angle + sweep,
            point_index: i,
            color_hex: spec.slice_color(i),
            value,
            fraction,
        });

        if spec.data_labels != LabelPosition::None {
            let mid = angle + sweep / 2.0;
            // 0 弧度指正上方、順時針為正 —— 平台畫扇形時用同一個約定。
            let r = match spec.data_labels {
                LabelPosition::Outside => radius + 10.0,
                _ => (radius + inner) / 2.0,
            };
            out.labels.push(TextLabel {
                x: cx + r * mid.sin(),
                y: cy - r * mid.cos() + LABEL_FONT * 0.35,
                text: format_value(value, spec.label_decimals),
                font_size: LABEL_FONT,
                align: TextAlign::Center,
                color_hex: String::new(),
                rotation: 0.0,
            });
        }
        angle += sweep;
    }
}

// ── 雷達 ────────────────────────────────────────────────────

fn layout_radar(spec: &ChartSpec, out: &mut ChartLayout) {
    let count = spec.point_count();
    if count < 3 {
        // 兩個軸的雷達圖是一條線，畫出來沒有意義。
        return;
    }
    let cx = out.plot_x + out.plot_width / 2.0;
    let cy = out.plot_y + out.plot_height / 2.0;
    let radius = out.plot_width.min(out.plot_height) / 2.0 * 0.82;
    let (lo, hi, step) = axis_scale(spec, radius);
    let decimals = tick_decimals(step);

    let angle_of = |i: usize| -> f64 { i as f64 / count as f64 * std::f64::consts::TAU };
    let point_at = |i: usize, t: f64| -> (f64, f64) {
        let a = angle_of(i);
        (cx + radius * t * a.sin(), cy - radius * t * a.cos())
    };

    // 同心圈與射線
    let mut v = lo;
    while v <= hi + step * 0.5 {
        let t = (v - lo) / (hi - lo);
        let ring: Vec<PlotPoint> = (0..count)
            .map(|i| {
                let (x, y) = point_at(i, t);
                PlotPoint {
                    x,
                    y,
                    series_index: usize::MAX,
                    point_index: i,
                    value: v,
                }
            })
            .collect();
        out.radar_rings.push(ring);
        if spec.y_axis.show_labels && t > 0.0 {
            out.labels.push(TextLabel {
                x: cx + 4.0,
                y: cy - radius * t,
                text: format_value(v, decimals),
                font_size: AXIS_FONT,
                align: TextAlign::Leading,
                color_hex: String::new(),
                rotation: 0.0,
            });
        }
        v += step;
    }
    for i in 0..count {
        let (x, y) = point_at(i, 1.0);
        out.radar_spokes.push(GridLine {
            x1: cx,
            y1: cy,
            x2: x,
            y2: y,
        });
        if spec.x_axis.show_labels {
            let (lx, ly) = point_at(i, 1.12);
            out.labels.push(TextLabel {
                x: lx,
                y: ly + AXIS_FONT * 0.35,
                text: spec.category(i),
                font_size: AXIS_FONT,
                align: TextAlign::Center,
                color_hex: String::new(),
                rotation: 0.0,
            });
        }
    }

    for (si, s) in spec.effective_series().iter().enumerate() {
        let mut points: Vec<PlotPoint> = (0..count)
            .map(|i| {
                let raw = s.values.get(i).copied().unwrap_or(lo);
                let t = ((raw - lo) / (hi - lo)).clamp(0.0, 1.0);
                let (x, y) = point_at(i, t);
                PlotPoint {
                    x,
                    y,
                    series_index: si,
                    point_index: i,
                    value: raw,
                }
            })
            .collect();
        // 雷達的輪廓要收口，否則最後一段邊不會畫出來。
        if let Some(first) = points.first().cloned() {
            points.push(first);
        }
        out.polylines.push(PlotPolyline {
            points,
            series_index: si,
            color_hex: spec.series_color(si),
            smooth: false,
            fill_to_y: None,
            show_markers: true,
        });
    }
}

// ── 圖例 ────────────────────────────────────────────────────

fn layout_legend(spec: &ChartSpec, items: &[(String, String)], out: &mut ChartLayout) {
    if spec.legend == LegendPosition::None || items.is_empty() {
        return;
    }
    match spec.legend {
        LegendPosition::Right => {
            let x = out.plot_x + out.plot_width + PAD;
            let line = LEGEND_FONT + 6.0;
            let start = out.plot_y + (out.plot_height - line * items.len() as f64) / 2.0;
            for (i, (text, color)) in items.iter().enumerate() {
                let y = start + line * i as f64;
                out.legend.push(LegendEntry {
                    swatch_x: x,
                    swatch_y: y,
                    swatch_size: LEGEND_SWATCH,
                    text_x: x + LEGEND_SWATCH + 5.0,
                    text_y: y + LEGEND_SWATCH * 0.85,
                    text: text.clone(),
                    color_hex: color.clone(),
                });
            }
        }
        LegendPosition::Top | LegendPosition::Bottom => {
            // 橫排置中：先量總寬再回頭算起點，否則圖例會偏一邊。
            let widths: Vec<f64> = items
                .iter()
                .map(|(t, _)| LEGEND_SWATCH + 5.0 + estimate_text_width(t, LEGEND_FONT))
                .collect();
            let total: f64 =
                widths.iter().sum::<f64>() + PAD * (items.len().saturating_sub(1)) as f64;
            let mut x = (out.width - total) / 2.0;
            let y = if spec.legend == LegendPosition::Top {
                out.plot_y - LEGEND_FONT - PAD * 0.5
            } else {
                out.height - PAD - LEGEND_SWATCH
            };
            for (i, (text, color)) in items.iter().enumerate() {
                out.legend.push(LegendEntry {
                    swatch_x: x,
                    swatch_y: y,
                    swatch_size: LEGEND_SWATCH,
                    text_x: x + LEGEND_SWATCH + 5.0,
                    text_y: y + LEGEND_SWATCH * 0.85,
                    text: text.clone(),
                    color_hex: color.clone(),
                });
                x += widths[i] + PAD;
            }
        }
        LegendPosition::None => {}
    }
}
