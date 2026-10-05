//! 製圖吸附：長按後把手繪筆畫「釘」成直線、圓、矩形，或鎖在特定角度的折線。
//!
//! 圖形辨識沿用 [`refine_stroke`]（與「圖形美化」同一套門檻，兩個平台一致）；
//! 這裡補的是製圖才需要的兩件事：
//!
//! 1. **角度鎖定**：直線的方向吸到最近的 `step_deg` 倍數（15／30／45／90）。
//! 2. **折線**：沒被辨識成任何圖形、但開了角度鎖定時，用 Douglas–Peucker 抓出轉折點，
//!    每一段的方向都吸到角度倍數 —— 三視圖的外框、投射轉折線都是這種線。
//!
//! 輸出與輸入**等長**（理由同 `refine`：平台層要逐點抄回壓感與時間戳）。

use crate::refine::{RefinedKind, refine_stroke};

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum SnapKind {
    /// 沒動：不像任何圖形，也沒開角度鎖定（或太短）。
    None,
    Line,
    Polyline,
    Ellipse,
    Rectangle,
    Triangle,
}

#[derive(Clone, Debug)]
pub struct Snapped {
    pub kind: SnapKind,
    pub points: Vec<(f32, f32)>,
}

fn dist(a: (f32, f32), b: (f32, f32)) -> f32 {
    ((a.0 - b.0).powi(2) + (a.1 - b.1).powi(2)).sqrt()
}

/// 把方向 `(dx, dy)` 吸到 `step_deg` 的倍數，長度不變。`step_deg <= 0` 不動。
pub fn snap_direction(dx: f32, dy: f32, step_deg: f32) -> (f32, f32) {
    if step_deg <= 0.0 {
        return (dx, dy);
    }
    let len = (dx * dx + dy * dy).sqrt();
    if len < 1e-4 {
        return (dx, dy);
    }
    let step = step_deg.to_radians();
    let a = (dy.atan2(dx) / step).round() * step;
    // 消掉 cos(90°) 之類留下的 1e-8 級雜訊，水平／垂直才會是真正的水平／垂直。
    let c = a.cos();
    let s = a.sin();
    (
        if c.abs() < 1e-6 { 0.0 } else { c * len },
        if s.abs() < 1e-6 { 0.0 } else { s * len },
    )
}

/// 沿折線（頂點 `verts`）取 `n` 個等距點。
fn resample(verts: &[(f32, f32)], n: usize) -> Vec<(f32, f32)> {
    if verts.len() < 2 || n < 2 {
        return vec![verts.first().copied().unwrap_or((0.0, 0.0)); n];
    }
    let total: f32 = verts.windows(2).map(|w| dist(w[0], w[1])).sum();
    if total < 1e-4 {
        return vec![verts[0]; n];
    }
    let mut out = Vec::with_capacity(n);
    let mut seg = 0;
    let mut seg_start = 0.0;
    for i in 0..n {
        let target = total * i as f32 / (n - 1) as f32;
        while seg + 2 < verts.len() && seg_start + dist(verts[seg], verts[seg + 1]) < target {
            seg_start += dist(verts[seg], verts[seg + 1]);
            seg += 1;
        }
        let len = dist(verts[seg], verts[seg + 1]).max(1e-6);
        let t = ((target - seg_start) / len).clamp(0.0, 1.0);
        out.push((
            verts[seg].0 + (verts[seg + 1].0 - verts[seg].0) * t,
            verts[seg].1 + (verts[seg + 1].1 - verts[seg].1) * t,
        ));
    }
    out
}

fn rdp(points: &[(f32, f32)], tol: f32, keep: &mut Vec<bool>, lo: usize, hi: usize) {
    if hi <= lo + 1 {
        return;
    }
    let (a, b) = (points[lo], points[hi]);
    let len = dist(a, b).max(1e-6);
    let (mut worst, mut idx) = (0.0, lo);
    for (i, &p) in points.iter().enumerate().take(hi).skip(lo + 1) {
        let d = ((b.0 - a.0) * (a.1 - p.1) - (a.0 - p.0) * (b.1 - a.1)).abs() / len;
        if d > worst {
            worst = d;
            idx = i;
        }
    }
    if worst > tol {
        keep[idx] = true;
        rdp(points, tol, keep, lo, idx);
        rdp(points, tol, keep, idx, hi);
    }
}

/// 轉折點。`tol` 是容許的最大偏離（頁面單位）。
fn corners(points: &[(f32, f32)], tol: f32) -> Vec<(f32, f32)> {
    let mut keep = vec![false; points.len()];
    keep[0] = true;
    *keep.last_mut().unwrap() = true;
    rdp(points, tol, &mut keep, 0, points.len() - 1);
    points
        .iter()
        .zip(keep)
        .filter_map(|(p, k)| k.then_some(*p))
        .collect()
}

/// 吸附一筆。
///
/// - 辨識成圓／橢圓／矩形／三角形：照 [`refine_stroke`] 完全採用。
/// - 辨識成直線或箭頭：成為一條直線，終點方向吸到 `angle_step_deg` 的倍數。
/// - 都不是、而且 `angle_step_deg > 0`：抓轉折點、每一段方向吸角、起點不動，
///   後面的頂點依序接上去（總是連續的折線）。
/// - 其餘回傳 [`SnapKind::None`]，點原樣不動。
pub fn snap_stroke(points: &[(f32, f32)], angle_step_deg: f32) -> Snapped {
    let untouched = || Snapped {
        kind: SnapKind::None,
        points: points.to_vec(),
    };
    if points.len() < 3 {
        return untouched();
    }
    let chord = dist(points[0], *points.last().unwrap());
    let path: f32 = points.windows(2).map(|w| dist(w[0], w[1])).sum();
    // 短到只是個點或輕觸：不是圖形。
    if path < 12.0 {
        return untouched();
    }

    let refined = refine_stroke(points, 1.0);
    match refined.kind {
        RefinedKind::Line | RefinedKind::Arrow => {
            let (dx, dy) = snap_direction(
                points.last().unwrap().0 - points[0].0,
                points.last().unwrap().1 - points[0].1,
                angle_step_deg,
            );
            let end = (points[0].0 + dx, points[0].1 + dy);
            return Snapped {
                kind: SnapKind::Line,
                points: resample(&[points[0], end], points.len()),
            };
        }
        RefinedKind::Ellipse => {
            return Snapped {
                kind: SnapKind::Ellipse,
                points: refined.points,
            };
        }
        RefinedKind::Rectangle => {
            return Snapped {
                kind: SnapKind::Rectangle,
                points: refined.points,
            };
        }
        RefinedKind::Triangle => {
            return Snapped {
                kind: SnapKind::Triangle,
                points: refined.points,
            };
        }
        RefinedKind::Freehand => {}
    }

    if angle_step_deg <= 0.0 {
        return untouched();
    }
    // 差不多是直的（辨識門檻之外的長弧線不算）：當成直線。
    if path > 0.0 && chord / path > 0.93 {
        let (dx, dy) = snap_direction(
            points.last().unwrap().0 - points[0].0,
            points.last().unwrap().1 - points[0].1,
            angle_step_deg,
        );
        let end = (points[0].0 + dx, points[0].1 + dy);
        return Snapped {
            kind: SnapKind::Line,
            points: resample(&[points[0], end], points.len()),
        };
    }
    let verts = corners(points, (path * 0.03).clamp(4.0, 14.0));
    if verts.len() < 3 {
        return untouched();
    }
    let mut chain = vec![verts[0]];
    for w in verts.windows(2) {
        let (dx, dy) = snap_direction(w[1].0 - w[0].0, w[1].1 - w[0].1, angle_step_deg);
        let last = *chain.last().unwrap();
        chain.push((last.0 + dx, last.1 + dy));
    }
    Snapped {
        kind: SnapKind::Polyline,
        points: resample(&chain, points.len()),
    }
}

/// 把折線依線型圖樣切成「畫」的那些段（匯出用：PNG 與 SVG 不能像 PDF 那樣直接設虛線）。
///
/// `pattern` 是「畫、空、畫、空…」的長度（頁面單位），從筆畫起點重新開始，與螢幕上
/// 的筆點陣（`apply_line_type`）同一個規則。空圖樣（實線）回傳整條折線。
pub fn dash_runs(path: &[(f32, f32)], pattern: &[f32]) -> Vec<Vec<(f32, f32)>> {
    if path.len() < 2 || pattern.len() < 2 || pattern.iter().any(|v| *v <= 0.0) {
        return vec![path.to_vec()];
    }
    let mut runs: Vec<Vec<(f32, f32)>> = Vec::new();
    let mut current: Vec<(f32, f32)> = Vec::new();
    let (mut idx, mut left) = (0usize, pattern[0]);
    let drawing = |i: usize| i.is_multiple_of(2);
    if drawing(idx) {
        current.push(path[0]);
    }
    for w in path.windows(2) {
        let (a, b) = (w[0], w[1]);
        let seg = dist(a, b);
        if seg < 1e-6 {
            continue;
        }
        let mut walked = 0.0;
        while seg - walked > left {
            walked += left;
            let t = walked / seg;
            let p = (a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t);
            if drawing(idx) {
                current.push(p);
                runs.push(std::mem::take(&mut current));
            } else {
                current.push(p);
            }
            idx += 1;
            left = pattern[idx % pattern.len()];
        }
        left -= seg - walked;
        if drawing(idx) {
            current.push(b);
        }
    }
    if drawing(idx) && current.len() >= 2 {
        runs.push(current);
    }
    runs
}

#[cfg(test)]
mod tests {
    use super::*;

    fn line(x0: f32, y0: f32, x1: f32, y1: f32, n: usize) -> Vec<(f32, f32)> {
        (0..n)
            .map(|i| {
                let t = i as f32 / (n - 1) as f32;
                (x0 + (x1 - x0) * t, y0 + (y1 - y0) * t)
            })
            .collect()
    }

    #[test]
    fn dash_runs_follow_the_pattern_from_the_start() {
        let path = vec![(0.0, 0.0), (100.0, 0.0)];
        let runs = dash_runs(&path, &[12.0, 4.0]);
        // 100 / 16 = 6 組完整 + 4 餘下：第 7 段畫 4。
        assert_eq!(runs.len(), 7);
        assert!((runs[0][0].0).abs() < 1e-3 && (runs[0].last().unwrap().0 - 12.0).abs() < 1e-3);
        assert!((runs[1][0].0 - 16.0).abs() < 1e-3);
        assert!(
            (runs[6][0].0 - 96.0).abs() < 1e-3 && (runs[6].last().unwrap().0 - 100.0).abs() < 1e-3
        );
    }

    #[test]
    fn dash_runs_carry_over_corners_and_solid_lines_stay_whole() {
        let l = vec![(0.0, 0.0), (10.0, 0.0), (10.0, 20.0)];
        let runs = dash_runs(&l, &[12.0, 4.0]);
        // 第一段畫 12：走 10 到轉角、再往上 2。
        assert_eq!(runs[0].len(), 3);
        assert!((runs[0][2].1 - 2.0).abs() < 1e-3);
        assert_eq!(dash_runs(&l, &[]).len(), 1);
    }

    #[test]
    fn direction_snaps_to_the_nearest_multiple() {
        let (dx, dy) = snap_direction(100.0, 8.0, 15.0); // 約 4.6° → 0°
        assert!((dy).abs() < 1e-3 && (dx - 100.3).abs() < 1.0);
        let (dx, dy) = snap_direction(100.0, 62.0, 30.0); // 約 31.8° → 30°
        let a = dy.atan2(dx).to_degrees();
        assert!((a - 30.0).abs() < 0.01, "{a}");
        // 長度不變。
        let len = (dx * dx + dy * dy).sqrt();
        assert!((len - (100.0f32 * 100.0 + 62.0 * 62.0).sqrt()).abs() < 0.01);
    }

    #[test]
    fn step_zero_leaves_the_direction_alone() {
        assert_eq!(snap_direction(3.0, 4.0, 0.0), (3.0, 4.0));
    }

    #[test]
    fn a_slightly_crooked_line_becomes_exactly_horizontal_at_90() {
        let mut pts = line(10.0, 10.0, 210.0, 22.0, 40);
        pts[20].1 += 3.0;
        let out = snap_stroke(&pts, 90.0);
        assert_eq!(out.kind, SnapKind::Line);
        assert_eq!(out.points.len(), pts.len());
        assert!(out.points.iter().all(|p| (p.1 - 10.0).abs() < 0.01));
    }

    #[test]
    fn output_length_always_matches_input() {
        let mut pts = line(0.0, 0.0, 100.0, 0.0, 30);
        pts.extend(line(100.0, 0.0, 100.0, 80.0, 30));
        let out = snap_stroke(&pts, 15.0);
        assert_eq!(out.points.len(), pts.len());
    }

    #[test]
    fn an_l_shaped_stroke_becomes_a_right_angle_polyline() {
        // 手抖的 L：先往右、再往下，轉角不是正好 90°。
        let mut pts = line(20.0, 20.0, 140.0, 26.0, 30);
        pts.extend(line(140.0, 26.0, 134.0, 120.0, 30));
        let out = snap_stroke(&pts, 90.0);
        assert_eq!(out.kind, SnapKind::Polyline);
        let first = out.points[0];
        let last = *out.points.last().unwrap();
        // 前面一段全是水平、後面一段全是垂直（轉角的索引會隨吸角後的長度移動，不去釘它）。
        assert!(
            out.points[..20].iter().all(|p| (p.1 - first.1).abs() < 0.5),
            "第一段水平"
        );
        assert!(
            out.points[40..].iter().all(|p| (p.0 - last.0).abs() < 0.5),
            "第二段垂直"
        );
    }

    #[test]
    fn freehand_without_angle_lock_is_not_touched() {
        let pts: Vec<(f32, f32)> = (0..40)
            .map(|i| {
                let t = i as f32 / 39.0;
                (t * 120.0, (t * 9.0).sin() * 30.0)
            })
            .collect();
        let out = snap_stroke(&pts, 0.0);
        assert_eq!(out.kind, SnapKind::None);
        assert_eq!(out.points, pts);
    }

    #[test]
    fn a_dot_is_not_a_shape() {
        let pts = vec![(5.0, 5.0), (5.5, 5.0), (5.0, 5.5)];
        assert_eq!(snap_stroke(&pts, 15.0).kind, SnapKind::None);
    }

    #[test]
    fn a_wobbly_circle_snaps_to_an_ellipse() {
        let pts: Vec<(f32, f32)> = (0..60)
            .map(|i| {
                let a = i as f32 / 59.0 * std::f32::consts::TAU;
                let r = 50.0 + if i % 2 == 0 { 2.0 } else { -2.0 };
                (100.0 + r * a.cos(), 100.0 + r * a.sin())
            })
            .collect();
        assert_eq!(snap_stroke(&pts, 15.0).kind, SnapKind::Ellipse);
    }
}
