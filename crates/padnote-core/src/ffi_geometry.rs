//! 對齊、吸附與變換的 FFI（S-38）。
//!
//! 這些都是**純函式**：輸入外框、輸出位移。不持有狀態，
//! 因此平台層可以在拖曳的每一幀呼叫而不必擔心同步。

use padnote_ink::{Alignment, Rect, align, distribute, snap};

/// 軸對齊矩形。
#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct FfiRect {
    pub min_x: f32,
    pub min_y: f32,
    pub max_x: f32,
    pub max_y: f32,
}

impl From<FfiRect> for Rect {
    fn from(r: FfiRect) -> Self {
        Self::new(r.min_x, r.min_y, r.max_x, r.max_y)
    }
}

/// 位移量。
#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct FfiDelta {
    pub dx: f32,
    pub dy: f32,
}

#[derive(Clone, Copy, Debug, uniffi::Enum)]
pub enum FfiAlignment {
    Left,
    HorizontalCenter,
    Right,
    Top,
    VerticalCenter,
    Bottom,
}

impl From<FfiAlignment> for Alignment {
    fn from(a: FfiAlignment) -> Self {
        match a {
            FfiAlignment::Left => Self::Left,
            FfiAlignment::HorizontalCenter => Self::HorizontalCenter,
            FfiAlignment::Right => Self::Right,
            FfiAlignment::Top => Self::Top,
            FfiAlignment::VerticalCenter => Self::VerticalCenter,
            FfiAlignment::Bottom => Self::Bottom,
        }
    }
}

/// 吸附結果。
#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct FfiSnap {
    pub dx: f32,
    pub dy: f32,
    /// 水平方向是否吸附。UI 據此畫垂直輔助線。
    pub snapped_x: bool,
    /// 垂直方向是否吸附。UI 據此畫水平輔助線。
    pub snapped_y: bool,
}

/// 算出把每個物件對齊所需的位移。
///
/// 基準是**所有物件的整體外框**，不是第一個 —— 以某一個為基準會讓結果
/// 取決於選取順序，使用者無從預期。
#[uniffi::export]
pub fn align_objects(bounds: Vec<FfiRect>, how: FfiAlignment) -> Vec<FfiDelta> {
    let rects: Vec<Rect> = bounds.into_iter().map(Into::into).collect();
    align(&rects, how.into())
        .into_iter()
        .map(|(dx, dy)| FfiDelta { dx, dy })
        .collect()
}

/// 平均分佈物件間距。**頭尾不動** —— 使用者的心智模型是「把中間的排整齊」。
#[uniffi::export]
pub fn distribute_objects(bounds: Vec<FfiRect>, horizontal: bool) -> Vec<FfiDelta> {
    let rects: Vec<Rect> = bounds.into_iter().map(Into::into).collect();
    distribute(&rects, horizontal)
        .into_iter()
        .map(|(dx, dy)| FfiDelta { dx, dy })
        .collect()
}

/// 把 `moving` 吸附到其他物件的邊緣與中心，或吸附到網格。
///
/// `grid` 傳 0 表示不使用網格吸附。物件吸附的優先序高於網格。
///
/// 已經對齊時 `snapped_*` 仍為 true 但位移為 0 —— UI 應據此顯示輔助線，
/// 讓使用者知道「這兩個是對齊的」。
#[uniffi::export]
pub fn snap_object(moving: FfiRect, targets: Vec<FfiRect>, grid: f32, threshold: f32) -> FfiSnap {
    let rects: Vec<Rect> = targets.into_iter().map(Into::into).collect();
    let r = snap(
        moving.into(),
        &rects,
        (grid > 0.0).then_some(grid),
        threshold,
    );
    FfiSnap {
        dx: r.delta.0,
        dy: r.delta.1,
        snapped_x: r.snapped_x,
        snapped_y: r.snapped_y,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn r(x: f32, y: f32, w: f32, h: f32) -> FfiRect {
        FfiRect {
            min_x: x,
            min_y: y,
            max_x: x + w,
            max_y: y + h,
        }
    }

    #[test]
    fn alignment_crosses_the_boundary() {
        let d = align_objects(
            vec![r(50.0, 0.0, 10.0, 10.0), r(20.0, 20.0, 10.0, 10.0)],
            FfiAlignment::Left,
        );
        assert_eq!(d[0].dx, -30.0);
        assert_eq!(d[1].dx, 0.0);
    }

    #[test]
    fn distribution_keeps_outer_items_fixed() {
        let d = distribute_objects(
            vec![
                r(0.0, 0.0, 10.0, 10.0),
                r(15.0, 0.0, 10.0, 10.0),
                r(100.0, 0.0, 10.0, 10.0),
            ],
            true,
        );
        assert_eq!(d[0].dx, 0.0);
        assert_eq!(d[2].dx, 0.0);
        assert_ne!(d[1].dx, 0.0);
    }

    #[test]
    fn snapping_reports_axes_separately() {
        // UI 只有 x 吸附時不該畫水平輔助線。
        let s = snap_object(
            r(102.0, 500.0, 10.0, 10.0),
            vec![r(100.0, 0.0, 10.0, 10.0)],
            0.0,
            5.0,
        );
        assert!(s.snapped_x);
        assert!(!s.snapped_y);
        assert_eq!(s.dx, -2.0);
    }

    #[test]
    fn grid_of_zero_disables_grid_snapping() {
        let s = snap_object(r(102.0, 300.0, 10.0, 10.0), vec![], 0.0, 5.0);
        assert!(!s.snapped_x && !s.snapped_y);
    }

    #[test]
    fn grid_snapping_works_when_enabled() {
        let s = snap_object(r(102.0, 300.0, 10.0, 10.0), vec![], 50.0, 5.0);
        assert!(s.snapped_x);
        assert_eq!(s.dx, -2.0);
    }

    #[test]
    fn empty_input_is_safe() {
        assert!(align_objects(vec![], FfiAlignment::Left).is_empty());
        assert!(distribute_objects(vec![], true).is_empty());
    }
}
