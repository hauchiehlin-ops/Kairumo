//! 自動批改：把學生畫的線和標準答案比對。
//!
//! 回報四種問題：缺線（Missing）、多線（Extra）、線型錯（WrongType：該畫實線卻畫成隱藏線…）、
//! 沒對齊（Misaligned：線畫對了形狀但整體偏了）。剖面線另外看（有沒有畫、角度對不對）。
//!
//! # 為什麼不是逐筆比
//!
//! 學生畫一條 100 單位的邊，可能一筆畫完，也可能分三段畫、中間重疊。所以比的是**覆蓋**：
//! 標準答案的每條邊，被學生的線沿著它蓋住了幾成。共線的小段合起來算。

use crate::P2;

/// 線的種類（批改只分這幾類；粗細已經換成種類了）。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum LineKind {
    /// 粗實線：看得見的輪廓。
    Visible,
    /// 隱藏線。
    Hidden,
    /// 中心線。
    Center,
    /// 細實線：剖面線。
    Thin,
}

/// 一條線段。
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Seg {
    pub a: P2,
    pub b: P2,
    pub kind: LineKind,
}

/// 把製圖筆的屬性換成線的種類。只收**頂層**（答案層）；中層輔助線、底層原題都不算答案。
///
/// 實線依粗細分：粗實線（≥ 2.0）是輪廓、細實線是剖面線。認不得的線型（假想線）回 `None`。
pub fn classify(layer: u8, line_type: u8, width: f32) -> Option<LineKind> {
    if layer != 3 {
        return None;
    }
    match line_type {
        0 => Some(if width >= 2.0 {
            LineKind::Visible
        } else {
            LineKind::Thin
        }),
        1 => Some(LineKind::Hidden),
        2 => Some(LineKind::Center),
        _ => None,
    }
}

/// 折線 → 線段。
///
/// 先簡化（容差 1 個單位）：筆畫是每隔幾個單位一個取樣點的很多小段，要先把共線的小段合成長線，
/// 否則每一小段都比「雜點」的長度還短，會被當成雜訊略過。
pub fn segments(points: &[P2], kind: LineKind) -> Vec<Seg> {
    let points = &crate::edit::simplify(points, 1.0);
    points
        .windows(2)
        .filter(|w| dist(w[0], w[1]) > 1e-3)
        .map(|w| Seg {
            a: w[0],
            b: w[1],
            kind,
        })
        .collect()
}

/// 批改出來的一個問題。
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Issue {
    /// 標準答案有、學生沒畫（或畫得太少）。
    Missing(Seg),
    /// 學生畫了、標準答案沒有。
    Extra(Seg),
    /// 位置對、線型不對：`expected` 是該有的種類。
    WrongType { drawn: Seg, expected: LineKind },
    /// 形狀對、位置偏了：`dx`、`dy` 是學生的線相對標準的偏移。
    Misaligned { expected: Seg, dx: f32, dy: f32 },
    /// 剖面線畫得太少（沒畫或只畫一點）。
    HatchMissing,
    /// 剖面線的角度不對（容許 8°）。
    HatchAngle { expected_deg: f32, drawn_deg: f32 },
}

#[derive(Clone, Debug, Default)]
pub struct Report {
    pub issues: Vec<Issue>,
    /// 標準答案裡正確畫出的輪廓邊（不含剖面線）。
    pub matched: usize,
    /// 標準答案的輪廓邊總數。
    pub expected: usize,
}

impl Report {
    pub fn is_perfect(&self) -> bool {
        self.issues.is_empty()
    }

    /// 0…100 的分數：每個問題扣分；缺線與多線各扣 1 份、其他各扣 0.5 份。
    pub fn score(&self) -> u32 {
        if self.expected == 0 {
            return if self.issues.is_empty() { 100 } else { 0 };
        }
        let cost: f32 = self
            .issues
            .iter()
            .map(|i| match i {
                Issue::Missing(_) | Issue::Extra(_) | Issue::HatchMissing => 1.0,
                _ => 0.5,
            })
            .sum();
        (100.0 * (1.0 - cost / self.expected as f32))
            .clamp(0.0, 100.0)
            .round() as u32
    }
}

/// 批改設定。
#[derive(Clone, Copy, Debug)]
pub struct Tolerance {
    /// 兩條線算「同一條」的垂直距離（頁面單位）。
    pub near: f32,
    /// 偏移多少以內還算「畫對了形狀只是沒對齊」。
    pub misaligned: f32,
    /// 兩條線算平行的角度（度）。
    pub angle_deg: f32,
}

impl Default for Tolerance {
    fn default() -> Self {
        Tolerance {
            near: 3.5,
            misaligned: 16.0,
            angle_deg: 3.0,
        }
    }
}

fn dist(a: P2, b: P2) -> f32 {
    (a.0 - b.0).hypot(a.1 - b.1)
}

fn len(s: &Seg) -> f32 {
    dist(s.a, s.b)
}

fn dir(s: &Seg) -> Option<P2> {
    let l = len(s);
    (l > 1e-3).then(|| ((s.b.0 - s.a.0) / l, (s.b.1 - s.a.1) / l))
}

/// 線的方向角（度，0…180，不分正反）。
fn angle_deg(s: &Seg) -> f32 {
    let a = (s.b.1 - s.a.1).atan2(s.b.0 - s.a.0).to_degrees();
    a.rem_euclid(180.0)
}

fn angle_diff(a: f32, b: f32) -> f32 {
    let d = (a - b).abs() % 180.0;
    d.min(180.0 - d)
}

/// `d` 蓋住 `e` 的哪一段：回 `e` 上的區間（沿 `e` 的距離），要求 `d` 與 `e` 平行（容許角度）
/// 且垂直距離不超過 `offset`（`d` 兩端點到 `e` 所在直線的距離都不超過）。
fn overlap(e: &Seg, d: &Seg, offset: f32, angle_tol: f32) -> Option<(f32, f32)> {
    let u = dir(e)?;
    if angle_diff(angle_deg(e), angle_deg(d)) > angle_tol {
        return None;
    }
    let n = (-u.1, u.0);
    let perp = |p: P2| (p.0 - e.a.0) * n.0 + (p.1 - e.a.1) * n.1;
    if perp(d.a).abs() > offset || perp(d.b).abs() > offset {
        return None;
    }
    let along = |p: P2| (p.0 - e.a.0) * u.0 + (p.1 - e.a.1) * u.1;
    let (mut s, mut t) = (along(d.a), along(d.b));
    if s > t {
        std::mem::swap(&mut s, &mut t);
    }
    let (s, t) = (s.max(0.0), t.min(len(e)));
    (t - s > 1e-3).then_some((s, t))
}

/// 區間聯集的總長。
fn union_len(mut spans: Vec<(f32, f32)>) -> f32 {
    spans.sort_by(|a, b| a.0.total_cmp(&b.0));
    let (mut total, mut end) = (0.0, f32::MIN);
    for (s, t) in spans {
        let s = s.max(end);
        if t > s {
            total += t - s;
            end = t;
        } else {
            end = end.max(t);
        }
    }
    total
}

/// `e` 被 `drawn` 裡（符合 `pick`）的線蓋住的比例。
fn coverage(
    e: &Seg,
    drawn: &[Seg],
    offset: f32,
    angle_tol: f32,
    pick: impl Fn(&Seg) -> bool,
) -> f32 {
    let spans: Vec<(f32, f32)> = drawn
        .iter()
        .filter(|d| pick(d))
        .filter_map(|d| overlap(e, d, offset, angle_tol))
        .collect();
    union_len(spans) / len(e).max(1e-3)
}

/// 覆蓋到這個比例就算畫出了那條邊。
const COVERED: f32 = 0.85;

/// 學生的線在 `e` 上蓋住的部分的平均偏移（帶正負號：沿 `e` 的左法向為正）。
fn mean_offset(
    e: &Seg,
    drawn: &[Seg],
    offset: f32,
    angle_tol: f32,
    pick: impl Fn(&Seg) -> bool,
) -> Option<(f32, f32)> {
    let u = dir(e)?;
    let n = (-u.1, u.0);
    let mut weight = 0.0;
    let mut sum = 0.0;
    for d in drawn.iter().filter(|d| pick(d)) {
        if overlap(e, d, offset, angle_tol).is_some() {
            let mid = ((d.a.0 + d.b.0) / 2.0, (d.a.1 + d.b.1) / 2.0);
            let off = (mid.0 - e.a.0) * n.0 + (mid.1 - e.a.1) * n.1;
            let w = len(d);
            weight += w;
            sum += off * w;
        }
    }
    (weight > 0.0).then(|| {
        let off = sum / weight;
        (n.0 * off, n.1 * off)
    })
}

/// 批改。`expected` 是標準答案、`drawn` 是學生畫的（都已換成線段與種類）。
pub fn grade(expected: &[Seg], drawn: &[Seg], tol: Tolerance) -> Report {
    let outline = |s: &Seg| s.kind != LineKind::Thin;
    let exp_out: Vec<Seg> = expected.iter().copied().filter(outline).collect();
    let drawn_out: Vec<Seg> = drawn.iter().copied().filter(outline).collect();
    let mut report = Report {
        expected: exp_out.len(),
        ..Report::default()
    };
    // 被解釋過的學生線（正確、線型錯、沒對齊）：不再算多線。
    let mut explained = vec![false; drawn_out.len()];
    let mark = |explained: &mut Vec<bool>, e: &Seg, offset: f32| {
        for (i, d) in drawn_out.iter().enumerate() {
            if overlap(e, d, offset, tol.angle_deg).is_some() {
                explained[i] = true;
            }
        }
    };

    for e in &exp_out {
        let same = coverage(e, &drawn_out, tol.near, tol.angle_deg, |d| d.kind == e.kind);
        if same >= COVERED {
            report.matched += 1;
            mark(&mut explained, e, tol.near);
            continue;
        }
        // 位置對、線型不對。
        let any = coverage(e, &drawn_out, tol.near, tol.angle_deg, |_| true);
        if any >= COVERED {
            let wrong = drawn_out
                .iter()
                .find(|d| d.kind != e.kind && overlap(e, d, tol.near, tol.angle_deg).is_some())
                .copied();
            if let Some(d) = wrong {
                report.issues.push(Issue::WrongType {
                    drawn: d,
                    expected: e.kind,
                });
                mark(&mut explained, e, tol.near);
                continue;
            }
        }
        // 形狀對、位置偏了（同線型的線在容許偏移之內蓋住它）。
        let shifted = coverage(e, &drawn_out, tol.misaligned, tol.angle_deg, |d| {
            d.kind == e.kind
        });
        if shifted >= COVERED {
            let (dx, dy) = mean_offset(e, &drawn_out, tol.misaligned, tol.angle_deg, |d| {
                d.kind == e.kind
            })
            .unwrap_or((0.0, 0.0));
            report.issues.push(Issue::Misaligned {
                expected: *e,
                dx,
                dy,
            });
            mark(&mut explained, e, tol.misaligned);
            continue;
        }
        report.issues.push(Issue::Missing(*e));
    }
    for (i, d) in drawn_out.iter().enumerate() {
        if !explained[i] && len(d) > tol.near * 2.0 {
            report.issues.push(Issue::Extra(*d));
        }
    }

    // 剖面線：有沒有畫夠、角度對不對。
    let exp_hatch: Vec<&Seg> = expected
        .iter()
        .filter(|s| s.kind == LineKind::Thin)
        .collect();
    if !exp_hatch.is_empty() {
        let drawn_hatch: Vec<&Seg> = drawn.iter().filter(|s| s.kind == LineKind::Thin).collect();
        let total = |v: &[&Seg]| v.iter().map(|s| len(s)).sum::<f32>();
        let (te, td) = (total(&exp_hatch), total(&drawn_hatch));
        report.expected += 1;
        if td < te * 0.5 {
            report.issues.push(Issue::HatchMissing);
        } else {
            // 角度：以長度加權的主方向。
            let main = |v: &[&Seg]| {
                let (mut x, mut y) = (0.0f32, 0.0f32);
                for s in v {
                    let a = (2.0 * angle_deg(s)).to_radians();
                    x += len(s) * a.cos();
                    y += len(s) * a.sin();
                }
                y.atan2(x).to_degrees().rem_euclid(360.0) / 2.0
            };
            let (ae, ad) = (main(&exp_hatch), main(&drawn_hatch));
            if angle_diff(ae, ad) > 8.0 {
                report.issues.push(Issue::HatchAngle {
                    expected_deg: ae,
                    drawn_deg: ad,
                });
            } else {
                report.matched += 1;
            }
        }
    }
    report
}

#[cfg(test)]
mod tests {
    use super::*;

    fn seg(a: P2, b: P2, kind: LineKind) -> Seg {
        Seg { a, b, kind }
    }
    fn vis(a: P2, b: P2) -> Seg {
        seg(a, b, LineKind::Visible)
    }

    /// 一個 100×60 的矩形（四條粗實線）。
    fn rect() -> Vec<Seg> {
        vec![
            vis((0.0, 0.0), (100.0, 0.0)),
            vis((100.0, 0.0), (100.0, 60.0)),
            vis((100.0, 60.0), (0.0, 60.0)),
            vis((0.0, 60.0), (0.0, 0.0)),
        ]
    }

    #[test]
    fn classification_uses_the_pen_layer_type_and_width() {
        assert_eq!(classify(3, 0, 2.6), Some(LineKind::Visible));
        assert_eq!(classify(3, 0, 1.2), Some(LineKind::Thin));
        assert_eq!(classify(3, 1, 1.4), Some(LineKind::Hidden));
        assert_eq!(classify(3, 2, 1.1), Some(LineKind::Center));
        assert_eq!(classify(2, 0, 1.0), None, "中層輔助線不算答案");
        assert_eq!(classify(1, 0, 1.8), None, "底層原題不算答案");
        assert_eq!(classify(3, 3, 1.1), None, "假想線不批改");
        assert_eq!(classify(0, 0, 2.6), None, "一般筆跡不是製圖答案");
    }

    #[test]
    fn a_densely_sampled_stroke_is_one_line_not_many_dots() {
        // 一條 200 單位長的線，每 4 單位一個取樣點（筆畫與製圖線都是這樣存的）。
        let dense: Vec<P2> = (0..=50).map(|i| (i as f32 * 4.0, 30.0)).collect();
        let segs = segments(&dense, LineKind::Visible);
        assert_eq!(segs.len(), 1, "共線的小段合成一條");
        assert_eq!((segs[0].a, segs[0].b), ((0.0, 30.0), (200.0, 30.0)));
        // 所以它多畫出來時會被報成多線。
        let r = grade(&rect(), &[rect(), segs].concat(), Tolerance::default());
        assert_eq!(r.issues.len(), 1);
        assert!(matches!(r.issues[0], Issue::Extra(_)));
        // 手抖的線（0.4 的抖動）也合成一條；轉折超過容差的才分段。
        let wobbly: Vec<P2> = (0..=50)
            .map(|i| (i as f32 * 4.0, 30.0 + if i % 2 == 0 { 0.0 } else { 0.4 }))
            .collect();
        assert_eq!(segments(&wobbly, LineKind::Visible).len(), 1);
        let corner: Vec<P2> = (0..=10)
            .map(|i| (i as f32 * 4.0, 0.0))
            .chain((1..=10).map(|i| (40.0, i as f32 * 4.0)))
            .collect();
        assert_eq!(segments(&corner, LineKind::Visible).len(), 2);
    }

    #[test]
    fn an_exact_answer_is_perfect() {
        let r = grade(&rect(), &rect(), Tolerance::default());
        assert!(r.is_perfect(), "{:?}", r.issues);
        assert_eq!((r.matched, r.expected, r.score()), (4, 4, 100));
    }

    #[test]
    fn small_wobble_and_split_strokes_still_count() {
        // 每條邊歪 1.5 單位、而且分成兩段畫、中間重疊。
        let drawn = vec![
            vis((0.0, 1.5), (60.0, 1.0)),
            vis((50.0, 1.0), (100.0, 1.5)),
            vis((101.0, 0.0), (101.0, 60.0)),
            vis((100.0, 59.0), (0.0, 59.5)),
            vis((-1.0, 60.0), (-1.0, 0.0)),
        ];
        let r = grade(&rect(), &drawn, Tolerance::default());
        assert!(r.is_perfect(), "{:?}", r.issues);
    }

    #[test]
    fn a_missing_edge_is_reported_with_the_edge() {
        let mut drawn = rect();
        let gone = drawn.remove(1);
        let r = grade(&rect(), &drawn, Tolerance::default());
        assert_eq!(r.issues, vec![Issue::Missing(gone)]);
        assert_eq!(r.score(), 75);
    }

    #[test]
    fn a_half_drawn_edge_counts_as_missing() {
        let mut drawn = rect();
        drawn[0] = vis((0.0, 0.0), (45.0, 0.0));
        let r = grade(&rect(), &drawn, Tolerance::default());
        assert!(
            r.issues
                .iter()
                .any(|i| matches!(i, Issue::Missing(s) if s.a == (0.0, 0.0)))
        );
    }

    #[test]
    fn an_extra_line_is_reported_but_a_dot_is_ignored() {
        let mut drawn = rect();
        drawn.push(vis((20.0, 10.0), (80.0, 50.0)));
        let r = grade(&rect(), &drawn, Tolerance::default());
        assert_eq!(r.issues.len(), 1);
        assert!(matches!(r.issues[0], Issue::Extra(_)));
        // 一個小點（比容差還短）不算多線。
        let mut dot = rect();
        dot.push(vis((50.0, 30.0), (52.0, 30.0)));
        assert!(grade(&rect(), &dot, Tolerance::default()).is_perfect());
    }

    #[test]
    fn the_wrong_line_type_is_named() {
        // 該是實線的邊畫成了隱藏線。
        let mut drawn = rect();
        drawn[2].kind = LineKind::Hidden;
        let r = grade(&rect(), &drawn, Tolerance::default());
        assert_eq!(r.issues.len(), 1, "{:?}", r.issues);
        assert!(matches!(
            r.issues[0],
            Issue::WrongType {
                expected: LineKind::Visible,
                drawn: Seg {
                    kind: LineKind::Hidden,
                    ..
                }
            }
        ));
        // 反過來：該是隱藏線的畫成實線。
        let want = vec![seg((0.0, 0.0), (80.0, 0.0), LineKind::Hidden)];
        let got = vec![vis((0.0, 0.0), (80.0, 0.0))];
        let r2 = grade(&want, &got, Tolerance::default());
        assert!(matches!(
            r2.issues[0],
            Issue::WrongType {
                expected: LineKind::Hidden,
                ..
            }
        ));
    }

    #[test]
    fn a_shifted_drawing_is_misaligned_not_missing_plus_extra() {
        // 整個圖往右偏 10：每條垂直線都沒對齊，水平線橫向偏移但仍重疊在原線上。
        let drawn: Vec<Seg> = rect()
            .into_iter()
            .map(|s| Seg {
                a: (s.a.0 + 10.0, s.a.1),
                b: (s.b.0 + 10.0, s.b.1),
                ..s
            })
            .collect();
        let r = grade(&rect(), &drawn, Tolerance::default());
        let mis: Vec<_> = r
            .issues
            .iter()
            .filter(|i| matches!(i, Issue::Misaligned { .. }))
            .collect();
        assert!(mis.len() >= 2, "兩條垂直線都要報沒對齊：{:?}", r.issues);
        assert!(
            r.issues.iter().all(|i| !matches!(i, Issue::Extra(_))),
            "沒對齊不該同時算多線：{:?}",
            r.issues
        );
        for i in mis {
            if let Issue::Misaligned { dx, dy, .. } = i {
                assert!(
                    (dx.abs() - 10.0).abs() < 0.5 && dy.abs() < 0.5,
                    "偏移量 {dx},{dy}"
                );
            }
        }
    }

    #[test]
    fn far_away_lines_are_missing_and_extra_not_misaligned() {
        let drawn = vec![vis((300.0, 300.0), (400.0, 300.0))];
        let r = grade(
            &[vis((0.0, 0.0), (100.0, 0.0))],
            &drawn,
            Tolerance::default(),
        );
        assert_eq!(r.issues.len(), 2);
        assert!(matches!(r.issues[0], Issue::Missing(_)));
        assert!(matches!(r.issues[1], Issue::Extra(_)));
    }

    #[test]
    fn hatching_is_checked_for_presence_and_angle() {
        let hatch = |deg: f32, n: usize| -> Vec<Seg> {
            (0..n)
                .map(|i| {
                    let (c, s) = deg.to_radians().sin_cos();
                    let o = i as f32 * 8.0;
                    seg((o, 0.0), (o + 40.0 * s, 40.0 * c), LineKind::Thin)
                })
                .collect()
        };
        // 標準：45° 的剖面線。
        let mut expected = rect();
        expected.extend(hatch(45.0, 10));
        // 沒畫剖面線。
        let r = grade(&expected, &rect(), Tolerance::default());
        assert_eq!(r.issues, vec![Issue::HatchMissing]);
        // 畫了但角度是 90°。
        let mut wrong = rect();
        wrong.extend(hatch(90.0, 10));
        let r = grade(&expected, &wrong, Tolerance::default());
        assert!(
            matches!(r.issues[0], Issue::HatchAngle { .. }),
            "{:?}",
            r.issues
        );
        // 畫對了。
        let mut good = rect();
        good.extend(hatch(45.0, 9));
        assert!(grade(&expected, &good, Tolerance::default()).is_perfect());
    }

    #[test]
    fn an_empty_answer_scores_zero_and_an_empty_key_with_nothing_drawn_is_perfect() {
        let r = grade(&rect(), &[], Tolerance::default());
        assert_eq!(r.issues.len(), 4);
        assert_eq!(r.score(), 0);
        assert!(grade(&[], &[], Tolerance::default()).is_perfect());
    }
}
