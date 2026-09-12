//! 物件對齊與吸附（S-38，需求 5）。
//!
//! 兩者都是**純幾何**：算出來的是「該套用什麼位移」，
//! 不直接改動任何座標。因此對齊可以被復原，也不破壞原始取樣點。

use crate::geometry::Rect;

/// 對齊基準。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Alignment {
    Left,
    HorizontalCenter,
    Right,
    Top,
    VerticalCenter,
    Bottom,
}

impl Alignment {
    /// 這個對齊方式是否只影響水平方向。UI 據此決定要畫哪條輔助線。
    pub fn is_horizontal(self) -> bool {
        matches!(self, Self::Left | Self::HorizontalCenter | Self::Right)
    }
}

/// 算出把每個物件對齊所需的位移量。
///
/// 基準取**所有物件的整體外框**，而不是第一個或最後一個物件 ——
/// 以某一個物件為基準會讓結果取決於選取順序，使用者無從預期。
pub fn align(bounds: &[Rect], how: Alignment) -> Vec<(f32, f32)> {
    if bounds.is_empty() {
        return Vec::new();
    }
    let group = bounds
        .iter()
        .skip(1)
        .fold(bounds[0], |acc, r| acc.union(*r));

    bounds
        .iter()
        .map(|r| match how {
            Alignment::Left => (group.min_x - r.min_x, 0.0),
            Alignment::Right => (group.max_x - r.max_x, 0.0),
            Alignment::HorizontalCenter => (
                (group.min_x + group.max_x) / 2.0 - (r.min_x + r.max_x) / 2.0,
                0.0,
            ),
            Alignment::Top => (0.0, group.min_y - r.min_y),
            Alignment::Bottom => (0.0, group.max_y - r.max_y),
            Alignment::VerticalCenter => (
                0.0,
                (group.min_y + group.max_y) / 2.0 - (r.min_y + r.max_y) / 2.0,
            ),
        })
        .collect()
}

/// 平均分佈物件之間的間距。
///
/// 頭尾兩個物件不動 —— 使用者的心智模型是「把中間的排整齊」，
/// 而不是「整組跟著移動」。
pub fn distribute(bounds: &[Rect], horizontal: bool) -> Vec<(f32, f32)> {
    if bounds.len() < 3 {
        // 兩個以下沒有「中間」可以分佈。
        return vec![(0.0, 0.0); bounds.len()];
    }

    let mut order: Vec<usize> = (0..bounds.len()).collect();
    order.sort_by(|&i, &j| {
        let (a, b) = if horizontal {
            (bounds[i].min_x, bounds[j].min_x)
        } else {
            (bounds[i].min_y, bounds[j].min_y)
        };
        a.total_cmp(&b)
    });

    let first = &bounds[order[0]];
    let last = &bounds[order[order.len() - 1]];
    let span = if horizontal {
        last.max_x - first.min_x
    } else {
        last.max_y - first.min_y
    };
    let occupied: f32 = order
        .iter()
        .map(|&i| {
            if horizontal {
                bounds[i].width()
            } else {
                bounds[i].height()
            }
        })
        .sum();
    let gap = (span - occupied) / (order.len() - 1) as f32;

    let mut deltas = vec![(0.0, 0.0); bounds.len()];
    let mut cursor = if horizontal { first.min_x } else { first.min_y };

    for &i in &order {
        let r = &bounds[i];
        let (current, size) = if horizontal {
            (r.min_x, r.width())
        } else {
            (r.min_y, r.height())
        };
        let delta = cursor - current;
        deltas[i] = if horizontal {
            (delta, 0.0)
        } else {
            (0.0, delta)
        };
        cursor += size + gap;
    }
    deltas
}

/// 吸附目標。
#[derive(Clone, Copy, PartialEq, Debug)]
pub struct SnapResult {
    /// 建議的位移量。
    pub delta: (f32, f32),
    /// 水平方向是否吸附。UI 據此顯示對齊輔助線。
    pub snapped_x: bool,
    pub snapped_y: bool,
}

/// 把 `moving` 吸附到 `targets` 的邊緣與中心，或吸附到網格。
///
/// `threshold` 是吸附距離（點）。超過就不吸附 ——
/// 門檻太大會讓物件「黏住」不放，使用者會覺得失控。
pub fn snap(moving: Rect, targets: &[Rect], grid: Option<f32>, threshold: f32) -> SnapResult {
    let mut best_x: Option<(f32, f32)> = None; // (距離, 位移)
    let mut best_y: Option<(f32, f32)> = None;

    let consider = |best: &mut Option<(f32, f32)>, from: f32, to: f32| {
        let d = (to - from).abs();
        if d <= threshold && best.is_none_or(|(bd, _)| d < bd) {
            *best = Some((d, to - from));
        }
    };

    let mx = [
        moving.min_x,
        (moving.min_x + moving.max_x) / 2.0,
        moving.max_x,
    ];
    let my = [
        moving.min_y,
        (moving.min_y + moving.max_y) / 2.0,
        moving.max_y,
    ];

    for t in targets {
        let tx = [t.min_x, (t.min_x + t.max_x) / 2.0, t.max_x];
        let ty = [t.min_y, (t.min_y + t.max_y) / 2.0, t.max_y];
        for &from in &mx {
            for &to in &tx {
                consider(&mut best_x, from, to);
            }
        }
        for &from in &my {
            for &to in &ty {
                consider(&mut best_y, from, to);
            }
        }
    }

    // 網格吸附的優先序低於物件吸附 —— 對齊到別的物件比對齊到隱形網格有意義。
    if let Some(g) = grid.filter(|g| *g > 0.0) {
        if best_x.is_none() {
            consider(&mut best_x, moving.min_x, (moving.min_x / g).round() * g);
        }
        if best_y.is_none() {
            consider(&mut best_y, moving.min_y, (moving.min_y / g).round() * g);
        }
    }

    SnapResult {
        delta: (
            best_x.map_or(0.0, |(_, d)| d),
            best_y.map_or(0.0, |(_, d)| d),
        ),
        snapped_x: best_x.is_some(),
        snapped_y: best_y.is_some(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn r(x: f32, y: f32, w: f32, h: f32) -> Rect {
        Rect::new(x, y, x + w, y + h)
    }

    #[test]
    fn align_left_uses_the_group_bounds_not_the_first_item() {
        // 以第一個物件為基準會讓結果取決於選取順序。
        let items = [r(50.0, 0.0, 10.0, 10.0), r(20.0, 20.0, 10.0, 10.0)];
        let d = align(&items, Alignment::Left);
        assert_eq!(d[0], (-30.0, 0.0), "應對齊到整體最左的 20");
        assert_eq!(d[1], (0.0, 0.0));
    }

    #[test]
    fn align_is_order_independent() {
        let a = [r(50.0, 0.0, 10.0, 10.0), r(20.0, 20.0, 10.0, 10.0)];
        let b = [r(20.0, 20.0, 10.0, 10.0), r(50.0, 0.0, 10.0, 10.0)];
        let da = align(&a, Alignment::Left);
        let db = align(&b, Alignment::Left);
        assert_eq!(da[0], db[1]);
        assert_eq!(da[1], db[0]);
    }

    #[test]
    fn align_center_centres_on_the_group() {
        let items = [r(0.0, 0.0, 10.0, 10.0), r(90.0, 0.0, 10.0, 10.0)];
        let d = align(&items, Alignment::HorizontalCenter);
        // 整體中心 50；各自中心 5 與 95
        assert_eq!(d[0], (45.0, 0.0));
        assert_eq!(d[1], (-45.0, 0.0));
    }

    #[test]
    fn horizontal_alignment_never_moves_vertically() {
        for how in [
            Alignment::Left,
            Alignment::HorizontalCenter,
            Alignment::Right,
        ] {
            assert!(how.is_horizontal());
            let d = align(&[r(0.0, 0.0, 10.0, 10.0), r(30.0, 50.0, 10.0, 10.0)], how);
            assert!(d.iter().all(|(_, dy)| *dy == 0.0), "{how:?} 不該改變 y");
        }
    }

    #[test]
    fn align_of_empty_or_single_is_safe() {
        assert!(align(&[], Alignment::Left).is_empty());
        assert_eq!(
            align(&[r(5.0, 5.0, 1.0, 1.0)], Alignment::Left),
            vec![(0.0, 0.0)]
        );
    }

    #[test]
    fn distribute_keeps_the_outer_items_fixed() {
        // 使用者的心智模型是「把中間的排整齊」，不是整組跟著移動。
        let items = [
            r(0.0, 0.0, 10.0, 10.0),
            r(15.0, 0.0, 10.0, 10.0),
            r(100.0, 0.0, 10.0, 10.0),
        ];
        let d = distribute(&items, true);
        assert_eq!(d[0], (0.0, 0.0), "最左不動");
        assert_eq!(d[2], (0.0, 0.0), "最右不動");
        assert_ne!(d[1], (0.0, 0.0), "中間應被移動");
    }

    #[test]
    fn distribute_makes_gaps_equal() {
        let items = [
            r(0.0, 0.0, 10.0, 10.0),
            r(15.0, 0.0, 10.0, 10.0),
            r(100.0, 0.0, 10.0, 10.0),
        ];
        let d = distribute(&items, true);
        let moved: Vec<f32> = items
            .iter()
            .zip(&d)
            .map(|(r, (dx, _))| r.min_x + dx)
            .collect();
        let gap1 = moved[1] - (moved[0] + 10.0);
        let gap2 = moved[2] - (moved[1] + 10.0);
        assert!((gap1 - gap2).abs() < 1e-4, "間距應相等：{gap1} vs {gap2}");
    }

    #[test]
    fn distribute_needs_at_least_three_items() {
        assert_eq!(distribute(&[r(0.0, 0.0, 1.0, 1.0)], true), vec![(0.0, 0.0)]);
        assert_eq!(
            distribute(&[r(0.0, 0.0, 1.0, 1.0), r(9.0, 0.0, 1.0, 1.0)], true),
            vec![(0.0, 0.0), (0.0, 0.0)]
        );
    }

    #[test]
    fn snap_aligns_edges_within_threshold() {
        let moving = r(102.0, 0.0, 10.0, 10.0);
        let target = r(100.0, 50.0, 10.0, 10.0);
        let s = snap(moving, &[target], None, 5.0);

        assert!(s.snapped_x);
        assert_eq!(s.delta.0, -2.0, "左緣應對齊到 100");
    }

    #[test]
    fn snap_does_nothing_beyond_the_threshold() {
        // 門檻太大會讓物件「黏住」不放，使用者會覺得失控。
        // 兩軸都拉遠，避免無意間對齊。
        let s = snap(
            r(200.0, 300.0, 10.0, 10.0),
            &[r(100.0, 0.0, 10.0, 10.0)],
            None,
            5.0,
        );
        assert!(!s.snapped_x && !s.snapped_y);
        assert_eq!(s.delta, (0.0, 0.0));
    }

    #[test]
    fn already_aligned_objects_still_report_snapping() {
        // 位移為 0 但仍算吸附 —— UI 要據此畫出對齊輔助線，
        // 讓使用者知道「這兩個是對齊的」。
        let s = snap(
            r(300.0, 0.0, 10.0, 10.0),
            &[r(100.0, 0.0, 10.0, 10.0)],
            None,
            5.0,
        );
        assert!(s.snapped_y, "y 已對齊，應顯示輔助線");
        assert_eq!(s.delta.1, 0.0, "已對齊則不需位移");
        assert!(!s.snapped_x);
    }

    #[test]
    fn snap_prefers_the_nearest_target() {
        let moving = r(103.0, 0.0, 10.0, 10.0);
        let near = r(100.0, 0.0, 10.0, 10.0);
        let nearer = r(104.0, 0.0, 10.0, 10.0);
        let s = snap(moving, &[near, nearer], None, 10.0);
        assert_eq!(s.delta.0, 1.0, "應吸到較近的 104");
    }

    #[test]
    fn object_snapping_beats_grid_snapping() {
        // 對齊到別的物件比對齊到隱形網格有意義。
        let moving = r(102.0, 0.0, 10.0, 10.0);
        let s = snap(moving, &[r(100.0, 0.0, 10.0, 10.0)], Some(50.0), 5.0);
        assert_eq!(s.delta.0, -2.0, "應吸到物件而非網格");
    }

    #[test]
    fn grid_snapping_applies_when_no_object_is_near() {
        let s = snap(r(102.0, 0.0, 10.0, 10.0), &[], Some(50.0), 5.0);
        assert!(s.snapped_x);
        assert_eq!(s.delta.0, -2.0, "應吸到網格線 100");
    }

    #[test]
    fn snap_reports_axes_separately_for_guide_lines() {
        // UI 要依此顯示對齊輔助線 —— 只有 x 吸附時不該畫水平線。
        let s = snap(
            r(102.0, 500.0, 10.0, 10.0),
            &[r(100.0, 0.0, 10.0, 10.0)],
            None,
            5.0,
        );
        assert!(s.snapped_x);
        assert!(!s.snapped_y);
    }

    #[test]
    fn snap_with_no_targets_and_no_grid_is_a_noop() {
        let s = snap(r(1.0, 2.0, 3.0, 4.0), &[], None, 10.0);
        assert_eq!(s.delta, (0.0, 0.0));
    }
}
