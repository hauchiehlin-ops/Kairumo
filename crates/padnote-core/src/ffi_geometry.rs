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

// MARK: - 編輯區域

/// 可列印區域（頁面往內縮一圈）。
///
/// # 為什麼這個判斷要在核心
///
/// 頁面上畫出來的那一圈虛線，意思是「這裡面才會被印出來 / 匯出」。
/// 在此之前那條線**只是畫出來好看** —— Apple 端的 `fitsInPage` 與 `clamp`
/// 寫好了卻從來沒有人呼叫，Android 端根本沒有。使用者把東西放到框線外，
/// 畫布上看得到、匯出的 PDF 裡卻不見了，而且沒有任何提示。
///
/// 判斷放在核心，兩端才會用同一條界線 —— 各寫一份的結果是同一個物件在
/// 一邊被擋下、在另一邊被放行。
#[uniffi::export]
pub fn printable_rect(page_width: f32, page_height: f32, inset: f32) -> FfiRect {
    // 內縮大到把頁面吃光時退回整頁：回傳一個負寬高的矩形會讓所有判斷都錯。
    let safe = inset.max(0.0).min(page_width / 2.0).min(page_height / 2.0);
    FfiRect {
        min_x: safe,
        min_y: safe,
        max_x: (page_width - safe).max(safe),
        max_y: (page_height - safe).max(safe),
    }
}

/// 這個矩形是不是整個落在可列印區域裡。
#[uniffi::export]
pub fn is_within_printable(rect: FfiRect, page_width: f32, page_height: f32, inset: f32) -> bool {
    let area = printable_rect(page_width, page_height, inset);
    rect.min_x >= area.min_x
        && rect.min_y >= area.min_y
        && rect.max_x <= area.max_x
        && rect.max_y <= area.max_y
}

/// 這個矩形是不是**整個**在可列印區域之外。
///
/// 與 [`is_within_printable`] 不是互補的：跨在界線上的矩形兩者都是 false。
/// 分成兩個問題是因為處理方式不同 —— 完全在外面的東西印不出來也匯不出去，
/// 留著只會讓使用者以為它存在；跨在界線上的還看得見大半，直接刪掉太粗暴。
#[uniffi::export]
pub fn is_outside_printable(rect: FfiRect, page_width: f32, page_height: f32, inset: f32) -> bool {
    let area = printable_rect(page_width, page_height, inset);
    rect.max_x <= area.min_x
        || rect.min_x >= area.max_x
        || rect.max_y <= area.min_y
        || rect.min_y >= area.max_y
}

/// 把矩形夾進可列印區域。
///
/// 比區域還大的物件夾不進去 —— 那種情況只縮到區域大小，而不是讓它溢出去。
/// 溢出的部分在匯出時會被裁掉，而使用者看不到自己丟了什麼。
#[uniffi::export]
pub fn clamp_to_printable(rect: FfiRect, page_width: f32, page_height: f32, inset: f32) -> FfiRect {
    let area = printable_rect(page_width, page_height, inset);
    let w = (rect.max_x - rect.min_x)
        .min(area.max_x - area.min_x)
        .max(0.0);
    let h = (rect.max_y - rect.min_y)
        .min(area.max_y - area.min_y)
        .max(0.0);
    let x = rect
        .min_x
        .clamp(area.min_x, (area.max_x - w).max(area.min_x));
    let y = rect
        .min_y
        .clamp(area.min_y, (area.max_y - h).max(area.min_y));
    FfiRect {
        min_x: x,
        min_y: y,
        max_x: x + w,
        max_y: y + h,
    }
}

#[cfg(test)]
mod printable_tests {
    use super::*;

    const W: f32 = 800.0;
    const H: f32 = 1132.0;
    const INSET: f32 = 24.0;

    fn rect(x: f32, y: f32, w: f32, h: f32) -> FfiRect {
        FfiRect {
            min_x: x,
            min_y: y,
            max_x: x + w,
            max_y: y + h,
        }
    }

    #[test]
    fn the_area_is_the_page_minus_one_inset_on_each_side() {
        let area = printable_rect(W, H, INSET);
        assert_eq!(area.min_x, 24.0);
        assert_eq!(area.max_x, 776.0);
        assert_eq!(area.max_y, 1108.0);
    }

    #[test]
    fn a_silly_inset_does_not_produce_a_negative_area() {
        // 負寬高的矩形會讓後面每一個判斷都反過來。
        let area = printable_rect(W, H, 9_999.0);
        assert!(area.max_x >= area.min_x);
        assert!(area.max_y >= area.min_y);
    }

    #[test]
    fn inside_outside_and_straddling_are_three_different_answers() {
        let inside = rect(100.0, 100.0, 200.0, 200.0);
        let outside = rect(790.0, 100.0, 50.0, 50.0);
        let straddling = rect(760.0, 100.0, 50.0, 50.0);

        assert!(is_within_printable(inside, W, H, INSET));
        assert!(!is_outside_printable(inside, W, H, INSET));

        assert!(!is_within_printable(outside, W, H, INSET));
        assert!(is_outside_printable(outside, W, H, INSET));

        // 跨在界線上：兩個問題的答案都是「不是」。
        assert!(!is_within_printable(straddling, W, H, INSET));
        assert!(!is_outside_printable(straddling, W, H, INSET));
    }

    #[test]
    fn clamping_moves_it_back_without_changing_its_size() {
        let clamped = clamp_to_printable(rect(790.0, 1120.0, 100.0, 100.0), W, H, INSET);
        assert_eq!(clamped.max_x - clamped.min_x, 100.0);
        assert_eq!(clamped.max_y - clamped.min_y, 100.0);
        assert!(is_within_printable(clamped, W, H, INSET));
    }

    #[test]
    fn something_bigger_than_the_page_shrinks_instead_of_overflowing() {
        let clamped = clamp_to_printable(rect(-500.0, -500.0, 5_000.0, 5_000.0), W, H, INSET);
        assert!(is_within_printable(clamped, W, H, INSET));
        assert_eq!(clamped.min_x, 24.0);
        assert_eq!(clamped.max_x, 776.0);
    }
}
