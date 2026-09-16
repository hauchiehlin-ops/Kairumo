//! 物件對齊與分佈。
//!
//! # 為什麼放在核心
//!
//! 「靠左對齊」聽起來兩行就寫完，但細節很容易兩邊不一樣：靠左是對齊到最左邊
//! 那個物件的左緣，還是對齊到選取範圍的左緣？置中是用選取範圍的中線，還是用
//! 頁面的中線？平均分佈時頭尾要不要動？
//!
//! 每一個都有合理的兩種答案。兩個平台各自實作，就會各自挑一種 —— 而使用者
//! 在 iPad 上排好的一組方塊，到 Android 上按同一個鈕會得到不同的結果。

/// 一個可對齊的矩形（頁面座標，原點左上）。
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct AlignRect {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
}

impl AlignRect {
    fn max_x(&self) -> f32 {
        self.x + self.width
    }
    fn max_y(&self) -> f32 {
        self.y + self.height
    }
    fn center_x(&self) -> f32 {
        self.x + self.width / 2.0
    }
    fn center_y(&self) -> f32 {
        self.y + self.height / 2.0
    }
}

/// 對齊方式。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AlignMode {
    Left,
    HorizontalCenter,
    Right,
    Top,
    VerticalMiddle,
    Bottom,
    /// 水平等距：頭尾不動，中間的平均分佈。
    DistributeHorizontally,
    /// 垂直等距：頭尾不動，中間的平均分佈。
    DistributeVertically,
}

/// 把一組矩形對齊，回傳每個矩形的**新左上角座標**（順序與輸入相同）。
///
/// 基準是**選取範圍**（所有矩形的聯集外框），不是頁面 —— 使用者選了三個方塊
/// 按「靠左」，期待的是那三個對齊彼此，不是統統飛到頁面左緣。
///
/// 少於兩個矩形時原樣回傳：一個東西無所謂跟誰對齊，而「對齊到頁面」是另一個
/// 功能，不該混在同一個按鈕裡。
pub fn align(rects: &[AlignRect], mode: AlignMode) -> Vec<(f32, f32)> {
    if rects.len() < 2 {
        return rects.iter().map(|r| (r.x, r.y)).collect();
    }

    let min_x = rects.iter().map(|r| r.x).fold(f32::INFINITY, f32::min);
    let max_x = rects
        .iter()
        .map(AlignRect::max_x)
        .fold(f32::NEG_INFINITY, f32::max);
    let min_y = rects.iter().map(|r| r.y).fold(f32::INFINITY, f32::min);
    let max_y = rects
        .iter()
        .map(AlignRect::max_y)
        .fold(f32::NEG_INFINITY, f32::max);
    let center_x = (min_x + max_x) / 2.0;
    let center_y = (min_y + max_y) / 2.0;

    match mode {
        AlignMode::Left => rects.iter().map(|r| (min_x, r.y)).collect(),
        AlignMode::Right => rects.iter().map(|r| (max_x - r.width, r.y)).collect(),
        AlignMode::HorizontalCenter => rects
            .iter()
            .map(|r| (center_x - r.width / 2.0, r.y))
            .collect(),
        AlignMode::Top => rects.iter().map(|r| (r.x, min_y)).collect(),
        AlignMode::Bottom => rects.iter().map(|r| (r.x, max_y - r.height)).collect(),
        AlignMode::VerticalMiddle => rects
            .iter()
            .map(|r| (r.x, center_y - r.height / 2.0))
            .collect(),
        AlignMode::DistributeHorizontally => distribute(rects, true),
        AlignMode::DistributeVertically => distribute(rects, false),
    }
}

/// 等距分佈。
///
/// 依**中心點**排序後，讓相鄰中心點的間距相等；頭尾兩個不動。
///
/// 用中心點而不是邊緣：物件寬度不一樣時，讓邊緣等距看起來反而不平均 ——
/// 那是所有繪圖工具的共同做法。
fn distribute(rects: &[AlignRect], horizontal: bool) -> Vec<(f32, f32)> {
    // 兩個以下無從分佈：頭尾不動，中間沒有東西。
    if rects.len() < 3 {
        return rects.iter().map(|r| (r.x, r.y)).collect();
    }

    let key = |r: &AlignRect| {
        if horizontal {
            r.center_x()
        } else {
            r.center_y()
        }
    };

    let mut indices: Vec<usize> = (0..rects.len()).collect();
    indices.sort_by(|&a, &b| {
        key(&rects[a])
            .partial_cmp(&key(&rects[b]))
            .unwrap_or(std::cmp::Ordering::Equal)
    });

    let first = key(&rects[indices[0]]);
    let last = key(&rects[indices[indices.len() - 1]]);
    let step = (last - first) / (indices.len() - 1) as f32;

    let mut result: Vec<(f32, f32)> = rects.iter().map(|r| (r.x, r.y)).collect();
    for (slot, &index) in indices.iter().enumerate() {
        let target = first + step * slot as f32;
        let r = &rects[index];
        if horizontal {
            result[index].0 = target - r.width / 2.0;
        } else {
            result[index].1 = target - r.height / 2.0;
        }
    }
    result
}

#[cfg(test)]
mod tests {
    use super::*;

    fn r(x: f32, y: f32, w: f32, h: f32) -> AlignRect {
        AlignRect {
            x,
            y,
            width: w,
            height: h,
        }
    }

    #[test]
    fn left_aligns_to_the_leftmost_edge() {
        let rects = [r(30.0, 0.0, 10.0, 10.0), r(10.0, 50.0, 20.0, 10.0)];
        let out = align(&rects, AlignMode::Left);
        assert_eq!(out, vec![(10.0, 0.0), (10.0, 50.0)]);
    }

    #[test]
    fn right_aligns_trailing_edges_not_origins() {
        // 寬度不同，靠右要對齊的是**右緣**。對齊 x 的話寬的那個會凸出去。
        let rects = [r(0.0, 0.0, 10.0, 10.0), r(0.0, 50.0, 40.0, 10.0)];
        let out = align(&rects, AlignMode::Right);
        assert_eq!(out, vec![(30.0, 0.0), (0.0, 50.0)]);
    }

    #[test]
    fn center_uses_the_selection_not_the_page() {
        let rects = [r(0.0, 0.0, 10.0, 10.0), r(90.0, 0.0, 10.0, 10.0)];
        let out = align(&rects, AlignMode::HorizontalCenter);
        // 聯集是 0..100，中線 50 —— 兩個都置中到 45。
        assert_eq!(out, vec![(45.0, 0.0), (45.0, 0.0)]);
    }

    #[test]
    fn vertical_modes_do_not_touch_x() {
        let rects = [r(7.0, 0.0, 10.0, 10.0), r(93.0, 40.0, 10.0, 20.0)];
        for mode in [AlignMode::Top, AlignMode::Bottom, AlignMode::VerticalMiddle] {
            let out = align(&rects, mode);
            assert_eq!(out[0].0, 7.0, "{mode:?} 不該動到 x");
            assert_eq!(out[1].0, 93.0, "{mode:?} 不該動到 x");
        }
    }

    #[test]
    fn a_single_rect_is_left_alone() {
        let rects = [r(5.0, 6.0, 10.0, 10.0)];
        assert_eq!(align(&rects, AlignMode::Left), vec![(5.0, 6.0)]);
    }

    #[test]
    fn distribute_keeps_the_ends_and_evens_the_middle() {
        // 中心點 5 / 40 / 95 → 頭尾不動，中間應落在 50。
        let rects = [
            r(0.0, 0.0, 10.0, 10.0),
            r(35.0, 0.0, 10.0, 10.0),
            r(90.0, 0.0, 10.0, 10.0),
        ];
        let out = align(&rects, AlignMode::DistributeHorizontally);
        assert_eq!(out[0].0, 0.0);
        assert_eq!(out[2].0, 90.0);
        assert!(
            (out[1].0 - 45.0).abs() < 0.01,
            "中間應在 45，實得 {}",
            out[1].0
        );
    }

    #[test]
    fn distribute_works_on_unsorted_input() {
        // 輸入順序與位置無關時，結果必須一樣 —— 不然同一組物件換個選取順序
        // 就得到不同的版面。
        let a = [
            r(0.0, 0.0, 10.0, 10.0),
            r(35.0, 0.0, 10.0, 10.0),
            r(90.0, 0.0, 10.0, 10.0),
        ];
        let b = [
            r(90.0, 0.0, 10.0, 10.0),
            r(0.0, 0.0, 10.0, 10.0),
            r(35.0, 0.0, 10.0, 10.0),
        ];
        let out_a = align(&a, AlignMode::DistributeHorizontally);
        let out_b = align(&b, AlignMode::DistributeHorizontally);
        assert!((out_a[1].0 - out_b[2].0).abs() < 0.01);
    }

    #[test]
    fn distribute_needs_three() {
        let rects = [r(0.0, 0.0, 10.0, 10.0), r(90.0, 0.0, 10.0, 10.0)];
        assert_eq!(
            align(&rects, AlignMode::DistributeHorizontally),
            vec![(0.0, 0.0), (90.0, 0.0)]
        );
    }
}
