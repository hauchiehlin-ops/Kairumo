//! 物件吸附（S-38，需求 5）。
//!
//! **純幾何**：算出來的是「該套用什麼位移」，不直接改動任何座標。
//! 因此吸附可以被復原，也不破壞原始取樣點。
//!
//! # 對齊與分佈不在這裡
//!
//! 它們在 `padnote_shapes::align`，那是兩邊平台實際在用的那一份。
//! 這裡原本也有一套（`Alignment` / `align` / `distribute`），沒有任何
//! 呼叫端 —— 核心裡放兩種「靠左」的定義，只是讓下一個人有五成機率接錯。

use crate::geometry::Rect;

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
