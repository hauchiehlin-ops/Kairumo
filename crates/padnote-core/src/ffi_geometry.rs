//! 矩形、吸附與可列印區的 FFI（S-38）。
//!
//! 這些都是**純函式**：輸入外框、輸出位移。不持有狀態，
//! 因此平台層可以在拖曳的每一幀呼叫而不必擔心同步。
//!
//! # 對齊與分佈不在這裡
//!
//! 它們在 [`crate::ffi_shapes::align_rects`]，那是**唯一一份**。
//!
//! 這個模組原本也有一份（`align_objects` / `distribute_objects`，走
//! `padnote_ink::align`），而兩邊平台用的一直是 `ffi_shapes` 那份 ——
//! 核心裡躺著第二種「靠左」的定義，沒有任何呼叫端，而且與在用的那份
//! **回傳的東西都不一樣**（位移 vs 新座標）。
//!
//! 那正是這些函式的註解在警告的事：「靠左」有好幾種合理答案（對齊到最左的
//! 物件還是選取範圍？分佈時頭尾動不動？），各寫一份就會各挑一種。
//! 兩份都放在核心並不會比較安全 —— 只是讓下一個人有五成機率接到沒人用的
//! 那一份，而接錯時物件會整批飛到別的位置。

use padnote_ink::{Rect, snap};

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
    fn snapping_with_no_targets_is_safe() {
        // 畫面上只有一個物件時 targets 是空的 —— 那是常態，不是錯誤。
        let s = snap_object(r(10.0, 10.0, 5.0, 5.0), vec![], 0.0, 5.0);
        assert!(!s.snapped_x && !s.snapped_y);
        assert_eq!((s.dx, s.dy), (0.0, 0.0));
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

/// 物件拖曳放開後的落點：落在第幾頁、頁內的左上角。
#[derive(uniffi::Record, Clone, Copy, Debug, PartialEq)]
pub struct FfiPageLanding {
    pub page_index: u32,
    pub min_x: f32,
    pub min_y: f32,
}

/// 連續頁面模式下，把拖曳放開的物件放到它**中心點所在的那一頁**，再夾進那一頁的可列印區域。
///
/// `rect` 是相對於原頁 `page_index` 的座標，可以超出原頁（往下拖進下一頁時 `min_y` 會大於頁高）。
/// 頁與頁之間有 `page_gap` 的間隔（頁面座標），所以第 `k` 頁的頂端在 `k × (頁高 + 間隔)`。
/// 中心點落在間隔裡時歸給比較近的那一頁。結果夾在 `0..page_count` 之內 ——
/// 拖過最後一頁就停在最後一頁，不會憑空多出一頁。
///
/// 只靠夾回原頁（`clamp_to_printable`）的話，物件永遠出不了它出生的那一頁：
/// 拖到下一頁、一放開又彈回原頁底邊。
#[uniffi::export]
pub fn land_on_page(
    rect: FfiRect,
    page_index: u32,
    page_count: u32,
    page_width: f32,
    page_height: f32,
    page_gap: f32,
    inset: f32,
) -> FfiPageLanding {
    let stride = page_height + page_gap.max(0.0);
    let last = page_count.max(1) - 1;
    let from = page_index.min(last) as i64;
    let center_y = (rect.min_y + rect.max_y) / 2.0;
    let shift = if stride > 0.0 && center_y.is_finite() {
        // 以「頁 + 半個間隔」為界：間隔上半歸上一頁，下半歸下一頁。
        ((center_y + page_gap.max(0.0) / 2.0) / stride).floor() as i64
    } else {
        0
    };
    let target = (from + shift).clamp(0, last as i64);
    let dy = (target - from) as f32 * stride;
    let moved = FfiRect {
        min_x: rect.min_x,
        min_y: rect.min_y - dy,
        max_x: rect.max_x,
        max_y: rect.max_y - dy,
    };
    let clamped = clamp_to_printable(moved, page_width, page_height, inset);
    FfiPageLanding {
        page_index: target as u32,
        min_x: clamped.min_x,
        min_y: clamped.min_y,
    }
}

#[cfg(test)]
mod landing_tests {
    use super::*;

    const W: f32 = 800.0;
    const H: f32 = 1132.0;
    const GAP: f32 = 20.0;
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
    fn staying_on_the_page_is_the_old_clamp() {
        let r = rect(100.0, 1050.0, 200.0, 100.0);
        let landing = land_on_page(r, 0, 3, W, H, GAP, INSET);
        assert_eq!(landing.page_index, 0);
        let clamped = clamp_to_printable(r, W, H, INSET);
        assert_eq!(
            (landing.min_x, landing.min_y),
            (clamped.min_x, clamped.min_y)
        );
    }

    #[test]
    fn dragging_the_center_onto_the_next_page_moves_it_there() {
        // 中心在 1132 + 20 + 100 = 第 2 頁頂端往下 100。
        let landing = land_on_page(
            rect(100.0, H + GAP + 50.0, 200.0, 100.0),
            0,
            3,
            W,
            H,
            GAP,
            INSET,
        );
        assert_eq!(landing.page_index, 1);
        assert_eq!(landing.min_x, 100.0);
        assert_eq!(landing.min_y, 50.0);
    }

    #[test]
    fn dragging_up_moves_it_to_the_previous_page() {
        let landing = land_on_page(rect(100.0, -400.0, 200.0, 100.0), 2, 3, W, H, GAP, INSET);
        assert_eq!(landing.page_index, 1);
        assert_eq!(landing.min_y, H + GAP - 400.0);
    }

    #[test]
    fn past_the_last_page_it_stays_on_the_last_page() {
        let landing = land_on_page(rect(100.0, 5.0 * H, 200.0, 100.0), 1, 2, W, H, GAP, INSET);
        assert_eq!(landing.page_index, 1);
        assert_eq!(landing.min_y, H - INSET - 100.0);
        let up = land_on_page(rect(100.0, -5.0 * H, 200.0, 100.0), 0, 2, W, H, GAP, INSET);
        assert_eq!(up.page_index, 0);
        assert_eq!(up.min_y, INSET);
    }

    #[test]
    fn a_center_in_the_gap_goes_to_the_nearer_page() {
        let upper = land_on_page(
            rect(0.0, H + 4.0 - 50.0, 100.0, 100.0),
            0,
            2,
            W,
            H,
            GAP,
            INSET,
        );
        assert_eq!(upper.page_index, 0);
        let lower = land_on_page(
            rect(0.0, H + 16.0 - 50.0, 100.0, 100.0),
            0,
            2,
            W,
            H,
            GAP,
            INSET,
        );
        assert_eq!(lower.page_index, 1);
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
