//! 虛擬尺規：直尺、丁字尺、三角板（45° 與 30°-60°）、量角器、圓規的圓弧。
//!
//! 尺規畫在頁面上，**尺寸是真實毫米**（頁面單位 = 毫米 × [`UNITS_PER_MM`]），放大縮小時刻度跟著走 ——
//! 所以紙上用它量出來的長度，與印出來的一致。
//!
//! 這裡只算幾何：外框、刻度、數字標籤，以及**可以靠著畫線的邊**（`edges`）。
//! 位置與旋轉由平台管（拖曳與旋轉鈕）；筆畫靠近邊時，平台用 [`snap_to_edges`]
//! 把筆跡投影到那條邊上，所以畫出來的線一定是直的、而且貼著尺。

use crate::{P2, UNITS_PER_MM};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum InstrumentKind {
    Ruler,
    TSquare,
    SetSquare45,
    SetSquare30,
    Protractor,
}

pub const KINDS: [InstrumentKind; 5] = [
    InstrumentKind::Ruler,
    InstrumentKind::TSquare,
    InstrumentKind::SetSquare45,
    InstrumentKind::SetSquare30,
    InstrumentKind::Protractor,
];

impl InstrumentKind {
    pub fn id(self) -> &'static str {
        match self {
            InstrumentKind::Ruler => "ruler",
            InstrumentKind::TSquare => "t_square",
            InstrumentKind::SetSquare45 => "set_square_45",
            InstrumentKind::SetSquare30 => "set_square_30",
            InstrumentKind::Protractor => "protractor",
        }
    }

    pub fn from_id(id: &str) -> Option<InstrumentKind> {
        KINDS.iter().copied().find(|k| k.id() == id)
    }
}

/// 一個刻度。
#[derive(Clone, Debug, PartialEq)]
pub struct Tick {
    pub a: P2,
    pub b: P2,
    /// 0 = 一般、1 = 中、2 = 長（附數字）。
    pub weight: u8,
    pub label: Option<String>,
    /// 數字放的位置（刻度長刻線的內側端點）。
    pub label_at: P2,
}

#[derive(Clone, Debug)]
pub struct Geometry {
    /// 外框（閉合折線，可有多條：例如三角板的內挖空）。
    pub outline: Vec<Vec<P2>>,
    pub ticks: Vec<Tick>,
    /// 靠著畫線的邊。
    pub edges: Vec<(P2, P2)>,
    /// 只能沿垂直方向移動（丁字尺貼著頁面左緣滑）。
    pub vertical_only: bool,
    /// 外框的概略包圍盒大小（頁面單位），給平台排版與命中測試。
    pub width: f32,
    pub height: f32,
    /// 讀數的圓心（量角器的圓心，尺自己的座標）。沒有讀數功能的尺是 `None`。
    pub reading_center: Option<P2>,
}

fn scale_pt(p: P2) -> P2 {
    (p.0 * UNITS_PER_MM, p.1 * UNITS_PER_MM)
}

fn mm_poly(points: &[P2]) -> Vec<P2> {
    points.iter().map(|p| scale_pt(*p)).collect()
}

/// 直線的一排刻度：從 `start` 起沿 `dir`（單位向量）、每 1 mm 一格，長度 `len_mm`；
/// 刻線朝 `inward`（單位向量）延伸。`label_every` mm 一個數字（以 `label_div` 換算，例如 10 mm → 1 cm）。
fn linear_ticks(
    start: P2,
    dir: P2,
    inward: P2,
    len_mm: f32,
    label_every: u32,
    label_div: f32,
    out: &mut Vec<Tick>,
) {
    let n = len_mm.floor() as u32;
    for i in 0..=n {
        let weight = if i % label_every == 0 {
            2
        } else if i % 5 == 0 {
            1
        } else {
            0
        };
        let length = match weight {
            2 => 5.0,
            1 => 3.5,
            _ => 2.0,
        };
        let base = (
            start.0 + dir.0 * i as f32 * UNITS_PER_MM,
            start.1 + dir.1 * i as f32 * UNITS_PER_MM,
        );
        let tip = (
            base.0 + inward.0 * length * UNITS_PER_MM,
            base.1 + inward.1 * length * UNITS_PER_MM,
        );
        out.push(Tick {
            a: base,
            b: tip,
            weight,
            label: (weight == 2).then(|| format!("{}", (i as f32 / label_div).round() as i64)),
            label_at: (
                base.0 + inward.0 * 6.0 * UNITS_PER_MM,
                base.1 + inward.1 * 6.0 * UNITS_PER_MM,
            ),
        });
    }
}

/// 尺規的幾何。`size_mm` 是主要長度（直尺的長、三角板的長邊、量角器的半徑，丁字尺會自動貼滿頁寬）。
/// 原點在尺的**左上角**（量角器也一樣，圓心在底邊中點，見 `reading_center`）；y 向下。
pub fn geometry(kind: InstrumentKind, size_mm: f32, page_width: f32) -> Geometry {
    let size = size_mm.clamp(40.0, 400.0);
    match kind {
        InstrumentKind::Ruler => {
            let w = 28.0;
            let outline = vec![mm_poly(&[
                (0.0, 0.0),
                (size, 0.0),
                (size, w),
                (0.0, w),
                (0.0, 0.0),
            ])];
            let mut ticks = Vec::new();
            linear_ticks(
                (0.0, 0.0),
                (1.0, 0.0),
                (0.0, 1.0),
                size,
                10,
                10.0,
                &mut ticks,
            );
            Geometry {
                outline,
                ticks,
                edges: vec![(scale_pt((0.0, 0.0)), scale_pt((size, 0.0)))],
                vertical_only: false,
                width: size * UNITS_PER_MM,
                height: w * UNITS_PER_MM,
                reading_center: None,
            }
        }
        InstrumentKind::TSquare => {
            let len = page_width.max(100.0);
            let blade_h = 16.0;
            let head_w = 18.0;
            let head_h = 70.0;
            let mut ticks = Vec::new();
            let len_mm = len / UNITS_PER_MM;
            linear_ticks(
                (0.0, 0.0),
                (1.0, 0.0),
                (0.0, 1.0),
                len_mm,
                10,
                10.0,
                &mut ticks,
            );
            // 丁字尺的尺身是整個頁寬（頁面單位），頭在左緣。
            let outline = vec![
                vec![
                    (0.0, 0.0),
                    (len, 0.0),
                    (len, blade_h * UNITS_PER_MM),
                    (0.0, blade_h * UNITS_PER_MM),
                    (0.0, 0.0),
                ],
                mm_poly(&[
                    (-head_w, -(head_h - blade_h) / 2.0),
                    (0.0, -(head_h - blade_h) / 2.0),
                    (0.0, (head_h + blade_h) / 2.0),
                    (-head_w, (head_h + blade_h) / 2.0),
                    (-head_w, -(head_h - blade_h) / 2.0),
                ]),
            ];
            Geometry {
                outline,
                ticks,
                edges: vec![((0.0, 0.0), (len, 0.0))],
                vertical_only: true,
                width: len,
                height: blade_h * UNITS_PER_MM,
                reading_center: None,
            }
        }
        InstrumentKind::SetSquare45 => {
            // 等腰直角：兩股各 size，直角在左下。三邊都能靠；其中一股有 mm 刻度。
            let a = (0.0, 0.0);
            let b = (0.0, size);
            let c = (size, size);
            let outline = vec![mm_poly(&[a, b, c, a]), {
                // 內挖空（三角形，縮 25%）。
                let k = size * 0.28;
                mm_poly(&[
                    (k * 0.7, k * 1.9),
                    (k * 0.7, size - k * 0.8),
                    (size - k * 1.9, size - k * 0.8),
                    (k * 0.7, k * 1.9),
                ])
            }];
            let mut ticks = Vec::new();
            // 下股（底邊）的刻度：往內（上）長。
            linear_ticks(
                scale_pt(b),
                (1.0, 0.0),
                (0.0, -1.0),
                size,
                10,
                10.0,
                &mut ticks,
            );
            Geometry {
                outline,
                ticks,
                edges: vec![
                    (scale_pt(a), scale_pt(b)),
                    (scale_pt(b), scale_pt(c)),
                    (scale_pt(a), scale_pt(c)),
                ],
                vertical_only: false,
                width: size * UNITS_PER_MM,
                height: size * UNITS_PER_MM,
                reading_center: None,
            }
        }
        InstrumentKind::SetSquare30 => {
            // 30°-60°-90°：長股 size（水平底邊）、短股 size/√3（垂直），直角在左下，30° 在右下。
            let short = size / 3.0f32.sqrt();
            let a = (0.0, 0.0);
            let b = (0.0, short);
            let c = (size, short);
            let outline = vec![mm_poly(&[a, b, c, a])];
            let mut ticks = Vec::new();
            linear_ticks(
                scale_pt(b),
                (1.0, 0.0),
                (0.0, -1.0),
                size,
                10,
                10.0,
                &mut ticks,
            );
            Geometry {
                outline,
                ticks,
                edges: vec![
                    (scale_pt(a), scale_pt(b)),
                    (scale_pt(b), scale_pt(c)),
                    (scale_pt(a), scale_pt(c)),
                ],
                vertical_only: false,
                width: size * UNITS_PER_MM,
                height: short * UNITS_PER_MM,
                reading_center: None,
            }
        }
        InstrumentKind::Protractor => {
            // 半圓量角器：半徑 `size`（但不超過 90 mm 才好用），圓心在底邊中點 = 原點。
            let r = size.min(90.0);
            let ru = r * UNITS_PER_MM;
            let mut arc: Vec<P2> = (0..=90)
                .map(|i| {
                    let t = std::f32::consts::PI * i as f32 / 90.0;
                    (-ru * t.cos(), -ru * t.sin())
                })
                .collect();
            arc.push((-ru, 0.0));
            let outline = vec![{
                let mut v = vec![(-ru, 0.0), (ru, 0.0)];
                v.extend(arc.iter().skip(1).rev().copied().take(0));
                v.extend((0..=90).map(|i| {
                    let t = std::f32::consts::PI * i as f32 / 90.0;
                    (ru * t.cos(), -ru * t.sin())
                }));
                v.push((-ru, 0.0));
                v
            }];
            let mut ticks = Vec::new();
            for deg in 0..=180u32 {
                let weight = if deg % 10 == 0 {
                    2
                } else if deg % 5 == 0 {
                    1
                } else {
                    0
                };
                let length = match weight {
                    2 => 6.0,
                    1 => 4.0,
                    _ => 2.5,
                } * UNITS_PER_MM;
                let t = deg as f32 * std::f32::consts::PI / 180.0;
                let (c, s) = (t.cos(), t.sin());
                let base = (ru * c, -ru * s);
                let tip = ((ru - length) * c, -(ru - length) * s);
                ticks.push(Tick {
                    a: base,
                    b: tip,
                    weight,
                    label: (weight == 2).then(|| format!("{deg}")),
                    label_at: (
                        (ru - length - 5.0 * UNITS_PER_MM) * c,
                        -(ru - length - 5.0 * UNITS_PER_MM) * s,
                    ),
                });
            }
            // 原點移到左上角（與其他尺一致）：圓心在 (ru, ru)。
            let shift = |q: P2| (q.0 + ru, q.1 + ru);
            Geometry {
                outline: outline
                    .into_iter()
                    .map(|ring| ring.into_iter().map(shift).collect())
                    .collect(),
                ticks: ticks
                    .into_iter()
                    .map(|t| Tick {
                        a: shift(t.a),
                        b: shift(t.b),
                        label_at: shift(t.label_at),
                        ..t
                    })
                    .collect(),
                edges: vec![(shift((-ru, 0.0)), shift((ru, 0.0)))],
                vertical_only: false,
                width: 2.0 * ru,
                height: ru,
                reading_center: Some((ru, ru)),
            }
        }
    }
}

/// 量角器的讀數：從圓心 `center` 看 `p` 的角度（度，0° 在右端、逆時針到 180° 在左端；尺自己的座標，y 向下）。
/// 在底邊以下（讀不到的半邊）回 `None`；貼著底邊的容差 0.5 單位。
pub fn protractor_angle(center: P2, p: P2) -> Option<f32> {
    let dx = p.0 - center.0;
    let dy = center.1 - p.1;
    if dx.hypot(dy) < 1e-3 || dy < -0.5 {
        return None;
    }
    Some(dy.max(0.0).atan2(dx).to_degrees())
}

/// 把 `p` 投影到線段 `(a, b)` 上（夾在兩端之內）。
pub fn project_to_segment(p: P2, a: P2, b: P2) -> P2 {
    let (dx, dy) = (b.0 - a.0, b.1 - a.1);
    let len2 = dx * dx + dy * dy;
    if len2 < 1e-9 {
        return a;
    }
    let t = (((p.0 - a.0) * dx + (p.1 - a.1) * dy) / len2).clamp(0.0, 1.0);
    (a.0 + dx * t, a.1 + dy * t)
}

/// `p` 離哪一條邊最近（`band` 之內）：回傳 (邊的索引, 投影點)。都不夠近回 `None`。
pub fn snap_to_edges(p: P2, edges: &[(P2, P2)], band: f32) -> Option<(usize, P2)> {
    let mut best: Option<(usize, P2, f32)> = None;
    for (i, &(a, b)) in edges.iter().enumerate() {
        let q = project_to_segment(p, a, b);
        let d = ((q.0 - p.0).powi(2) + (q.1 - p.1).powi(2)).sqrt();
        if d <= band && best.is_none_or(|(_, _, bd)| d < bd) {
            best = Some((i, q, d));
        }
    }
    best.map(|(i, q, _)| (i, q))
}

/// 把整條折線釘在一條邊上：每個點投影到該邊（夾在兩端內）。
pub fn constrain_to_edge(points: &[P2], edge: (P2, P2)) -> Vec<P2> {
    points
        .iter()
        .map(|&p| project_to_segment(p, edge.0, edge.1))
        .collect()
}

/// 圓規：圓心 `c`、半徑 `r`，從 `start` 弧度掃過 `sweep` 弧度（可為負）的圓弧折線。
/// 每段約 2°（半徑很小時放寬，免得點太密）。
pub fn arc_points(c: P2, r: f32, start: f32, sweep: f32) -> Vec<P2> {
    if r <= 0.0 || !sweep.is_finite() || sweep.abs() < 1e-5 {
        return Vec::new();
    }
    let step = (2.0f32.to_radians()).max(1.0 / r.max(1.0));
    let n = ((sweep.abs() / step).ceil() as usize).clamp(2, 720);
    (0..=n)
        .map(|i| {
            let a = start + sweep * i as f32 / n as f32;
            (c.0 + r * a.cos(), c.1 + r * a.sin())
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn len(a: P2, b: P2) -> f32 {
        ((a.0 - b.0).powi(2) + (a.1 - b.1).powi(2)).sqrt()
    }

    #[test]
    fn a_ruler_is_in_real_millimetres() {
        let g = geometry(InstrumentKind::Ruler, 150.0, 800.0);
        // 150 mm 長、一條可靠的邊。
        assert!((g.width / UNITS_PER_MM - 150.0).abs() < 1e-3);
        assert_eq!(g.edges.len(), 1);
        assert!((len(g.edges[0].0, g.edges[0].1) / UNITS_PER_MM - 150.0).abs() < 1e-3);
        // 刻度：151 條（0 到 150，每 mm 一條）；每 10 mm 有數字（0…15 共 16 個）。
        assert_eq!(g.ticks.len(), 151);
        let labels: Vec<&str> = g.ticks.iter().filter_map(|t| t.label.as_deref()).collect();
        assert_eq!(labels.len(), 16);
        assert_eq!(labels[0], "0");
        assert_eq!(labels[15], "15");
        // 相鄰兩條刻線的間距正好 1 mm。
        assert!((len(g.ticks[0].a, g.ticks[1].a) / UNITS_PER_MM - 1.0).abs() < 1e-3);
        // 長刻線比中刻線長、中刻線比短刻線長。
        let tl = |w: u8| {
            g.ticks
                .iter()
                .find(|t| t.weight == w)
                .map(|t| len(t.a, t.b))
                .unwrap()
        };
        assert!(tl(2) > tl(1) && tl(1) > tl(0));
    }

    #[test]
    fn the_t_square_spans_the_page_and_only_slides_vertically() {
        let g = geometry(InstrumentKind::TSquare, 100.0, 800.0);
        assert!(g.vertical_only);
        assert!((g.edges[0].1.0 - 800.0).abs() < 1e-3, "尺身貼滿頁寬");
        assert_eq!(g.edges[0].0.1, g.edges[0].1.1, "邊是水平的");
        assert_eq!(g.outline.len(), 2, "尺身加尺頭");
    }

    #[test]
    fn set_squares_have_the_right_angles() {
        let angle = |a: P2, vertex: P2, b: P2| {
            let (u, v) = (
                (a.0 - vertex.0, a.1 - vertex.1),
                (b.0 - vertex.0, b.1 - vertex.1),
            );
            (u.0 * v.1 - u.1 * v.0)
                .abs()
                .atan2(u.0 * v.0 + u.1 * v.1)
                .to_degrees()
        };
        let g45 = geometry(InstrumentKind::SetSquare45, 120.0, 800.0);
        let tri = &g45.outline[0];
        assert!((angle(tri[0], tri[1], tri[2]) - 90.0).abs() < 0.01, "直角");
        assert!((angle(tri[1], tri[2], tri[0]) - 45.0).abs() < 0.01);
        let g30 = geometry(InstrumentKind::SetSquare30, 120.0, 800.0);
        let t = &g30.outline[0];
        assert!((angle(t[0], t[1], t[2]) - 90.0).abs() < 0.01);
        assert!(
            (angle(t[1], t[2], t[0]) - 30.0).abs() < 0.01,
            "長股那一端是 30°"
        );
        assert_eq!(g30.edges.len(), 3);
    }

    #[test]
    fn a_protractor_marks_every_degree_with_labels_every_ten() {
        let g = geometry(InstrumentKind::Protractor, 70.0, 800.0);
        assert_eq!(g.ticks.len(), 181);
        let labels: Vec<&str> = g.ticks.iter().filter_map(|t| t.label.as_deref()).collect();
        assert_eq!(labels.len(), 19);
        assert_eq!(labels[0], "0");
        assert_eq!(labels[18], "180");
        // 原點在左上角、圓心在底邊中點：外框包圍盒從 (0,0) 開始。
        let c = g.reading_center.expect("量角器有讀數圓心");
        assert!((c.0 - g.width / 2.0).abs() < 1e-3 && (c.1 - g.height).abs() < 1e-3);
        let pts: Vec<P2> = g.outline.iter().flatten().copied().collect();
        let min_x = pts.iter().map(|q| q.0).fold(f32::MAX, f32::min);
        let min_y = pts.iter().map(|q| q.1).fold(f32::MAX, f32::min);
        assert!(min_x.abs() < 1e-2 && min_y.abs() < 1e-2);
        // 90° 的刻線正好在圓心正上方。
        let t90 = &g.ticks[90];
        assert!((t90.a.0 - c.0).abs() < 1e-2 && t90.a.1 < c.1);
        // 底邊是一條水平線，通過圓心。
        let e = g.edges[0];
        assert!(e.0.1 == c.1 && e.1.1 == c.1 && e.0.0 < c.0 && e.1.0 > c.0);
        // 其他尺沒有讀數功能。
        assert!(
            geometry(InstrumentKind::Ruler, 100.0, 800.0)
                .reading_center
                .is_none()
        );
    }

    #[test]
    fn the_protractor_reads_angles_from_its_center() {
        let c = (100.0, 100.0);
        let near = |a: Option<f32>, b: f32| (a.unwrap() - b).abs() < 1e-3;
        assert!(near(protractor_angle(c, (200.0, 100.0)), 0.0), "右端 0°");
        assert!(near(protractor_angle(c, (100.0, 0.0)), 90.0), "正上方 90°");
        assert!(near(protractor_angle(c, (0.0, 100.0)), 180.0), "左端 180°");
        assert!(near(protractor_angle(c, (200.0, 0.0)), 45.0));
        assert!(near(protractor_angle(c, (0.0, 0.0)), 135.0));
        // 在底邊以下讀不到；剛好貼著底邊的容差內算 0°／180°。
        assert!(protractor_angle(c, (150.0, 140.0)).is_none());
        assert!(near(protractor_angle(c, (150.0, 100.3)), 0.0));
        // 圓心本身沒有方向。
        assert!(protractor_angle(c, c).is_none());
    }

    #[test]
    fn a_stroke_near_an_edge_snaps_onto_it_and_is_straightened() {
        let edges = [((0.0, 100.0), (200.0, 100.0)), ((0.0, 0.0), (0.0, 200.0))];
        // 離水平邊 4 個單位：吸在水平邊上。
        let (i, q) = snap_to_edges((80.0, 104.0), &edges, 10.0).unwrap();
        assert_eq!(i, 0);
        assert_eq!(q, (80.0, 100.0));
        // 太遠：沒有。
        assert!(snap_to_edges((80.0, 130.0), &edges, 10.0).is_none());
        // 夾在兩端之內：超出邊的端點就停在端點。
        let (_, end) = snap_to_edges((230.0, 102.0), &edges, 40.0).unwrap();
        assert_eq!(end, (200.0, 100.0));
        // 整條手抖的線被釘直。
        let wobbly = [(10.0, 96.0), (60.0, 107.0), (130.0, 99.0), (190.0, 110.0)];
        let straight = constrain_to_edge(&wobbly, edges[0]);
        assert!(straight.iter().all(|p| p.1 == 100.0));
        assert!((straight[1].0 - 60.0).abs() < 1e-3);
    }

    #[test]
    fn the_nearest_edge_wins() {
        let edges = [
            ((0.0, 100.0), (200.0, 100.0)),
            ((0.0, 106.0), (200.0, 106.0)),
        ];
        let (i, _) = snap_to_edges((50.0, 105.0), &edges, 10.0).unwrap();
        assert_eq!(i, 1);
    }

    #[test]
    fn a_compass_arc_stays_on_the_circle_and_sweeps_the_requested_angle() {
        let c = (300.0, 400.0);
        let pts = arc_points(c, 80.0, 0.0, std::f32::consts::FRAC_PI_2);
        assert!(pts.len() >= 40, "每 2° 一點，90° 至少 45 點");
        for p in &pts {
            assert!((len(*p, c) - 80.0).abs() < 1e-3);
        }
        assert!((pts[0].0 - 380.0).abs() < 1e-3 && (pts[0].1 - 400.0).abs() < 1e-3);
        let last = pts.last().unwrap();
        assert!((last.0 - 300.0).abs() < 1e-3 && (last.1 - 480.0).abs() < 1e-3);
        // 反方向掃（負角度）。
        let back = arc_points(c, 80.0, 0.0, -std::f32::consts::FRAC_PI_2);
        assert!((back.last().unwrap().1 - 320.0).abs() < 1e-3);
        // 整圈閉合；零半徑或零角度回空。
        let full = arc_points(c, 50.0, 0.0, std::f32::consts::TAU);
        assert!(len(full[0], *full.last().unwrap()) < 1e-2);
        assert!(arc_points(c, 0.0, 0.0, 1.0).is_empty());
        assert!(arc_points(c, 10.0, 0.0, 0.0).is_empty());
    }

    #[test]
    fn kinds_round_trip_through_their_ids() {
        for k in KINDS {
            assert_eq!(InstrumentKind::from_id(k.id()), Some(k));
        }
        assert_eq!(InstrumentKind::from_id("nope"), None);
    }
}
