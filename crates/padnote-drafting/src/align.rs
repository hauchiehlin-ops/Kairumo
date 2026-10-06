//! 投影對齊輔助：畫三視圖時的「長對正、高平齊、寬相等」。
//!
//! 製圖課三視圖的核心規則：
//! - **長對正**：正視圖與俯視圖的 x 座標對齊（垂直的投射線）；
//! - **高平齊**：正視圖與右視圖的 y 座標對齊（水平的投射線）；
//! - **寬相等**：俯視圖與右視圖的深度相等，靠一條 **45° 轉折線**傳遞 ——
//!   俯視圖上的點水平拉到 45° 線、再垂直拉到右視圖。
//!
//! 這裡不知道哪一塊是哪個視圖：它只看「游標附近有沒有哪個既有線的端點／轉折點，讓游標的 x 或 y 與它對齊」，
//! 以及（設了 45° 轉折點之後）「游標的 x 或 y 有沒有等於某個點經 45° 線傳遞過來的值」。
//! 找到就把游標吸過去，並回傳要畫出來的**對齊線**（淡藍虛線）讓使用者看到為什麼吸在那裡。

use crate::P2;

/// 對齊線的種類。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum GuideKind {
    /// 與某點的 x 相同（垂直線）：長對正。
    Vertical,
    /// 與某點的 y 相同（水平線）：高平齊。
    Horizontal,
    /// 經 45° 轉折線傳遞：寬相等。折線 = 來源點 → 45° 線上的轉折 → 游標。
    Transfer,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Guide {
    pub kind: GuideKind,
    pub points: Vec<P2>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct AlignResult {
    /// 吸附之後的位置（沒吸到就是原來的游標）。
    pub point: P2,
    pub guides: Vec<Guide>,
}

/// 一個吸附候選：把游標的某一軸吸到 `value`，附帶要畫的對齊線。
struct Candidate {
    value: f32,
    delta: f32,
    guide: Guide,
}

/// 45° 轉折點 `pivot` 的傳遞：回傳（右視圖 x 候選, 俯視圖 y 候選）所對應的來源值。
///
/// 第三角法（台灣、美國）：俯視圖在正視圖上方、右視圖在右方 ——
/// 俯視圖上「在 pivot 上方 d 處」的點，對應右視圖「在 pivot 右方 d 處」。
/// 第一角法鏡像：俯視圖在下方、右視圖在左方。
fn transfer_x(a: P2, pivot: P2, third_angle: bool) -> f32 {
    if third_angle {
        pivot.0 + (pivot.1 - a.1)
    } else {
        pivot.0 - (a.1 - pivot.1)
    }
}

fn transfer_y(a: P2, pivot: P2, third_angle: bool) -> f32 {
    if third_angle {
        pivot.1 - (a.0 - pivot.0)
    } else {
        pivot.1 + (pivot.0 - a.0)
    }
}

/// 找游標的對齊位置。
///
/// - `anchors`：既有線的端點與轉折點。
/// - `pivot`：45° 轉折點（沒設就只做垂直與水平對齊）。
/// - `tol`：吸附距離（頁面單位）。
pub fn align(
    cursor: P2,
    anchors: &[P2],
    pivot: Option<P2>,
    third_angle: bool,
    tol: f32,
) -> AlignResult {
    let mut xs: Vec<Candidate> = Vec::new();
    let mut ys: Vec<Candidate> = Vec::new();
    for &a in anchors {
        // 游標就在來源點上：不是對齊，是重合 —— 交給端點吸附處理。
        if (a.0 - cursor.0).abs() < 1e-3 && (a.1 - cursor.1).abs() < 1e-3 {
            continue;
        }
        let dx = (a.0 - cursor.0).abs();
        if dx <= tol {
            xs.push(Candidate {
                value: a.0,
                delta: dx,
                guide: Guide {
                    kind: GuideKind::Vertical,
                    points: vec![a, (a.0, cursor.1)],
                },
            });
        }
        let dy = (a.1 - cursor.1).abs();
        if dy <= tol {
            ys.push(Candidate {
                value: a.1,
                delta: dy,
                guide: Guide {
                    kind: GuideKind::Horizontal,
                    points: vec![a, (cursor.0, a.1)],
                },
            });
        }
        if let Some(o) = pivot {
            // 寬相等：只有在 pivot 的「俯視圖側」的點才有意義（第三角在上方、第一角在下方）。
            let above = if third_angle { a.1 < o.1 } else { a.1 > o.1 };
            if above {
                let tx = transfer_x(a, o, third_angle);
                let d = (tx - cursor.0).abs();
                if d <= tol {
                    // 來源點 → 水平拉到 45° 線 → 垂直拉到游標。
                    let corner = (tx, a.1);
                    xs.push(Candidate {
                        value: tx,
                        delta: d,
                        guide: Guide {
                            kind: GuideKind::Transfer,
                            points: vec![a, corner, (tx, cursor.1)],
                        },
                    });
                }
            }
            let right = if third_angle { a.0 > o.0 } else { a.0 < o.0 };
            if right {
                let ty = transfer_y(a, o, third_angle);
                let d = (ty - cursor.1).abs();
                if d <= tol {
                    let corner = (a.0, ty);
                    ys.push(Candidate {
                        value: ty,
                        delta: d,
                        guide: Guide {
                            kind: GuideKind::Transfer,
                            points: vec![a, corner, (cursor.0, ty)],
                        },
                    });
                }
            }
        }
    }
    let best = |mut v: Vec<Candidate>| {
        v.sort_by(|a, b| {
            a.delta
                .partial_cmp(&b.delta)
                .unwrap_or(std::cmp::Ordering::Equal)
        });
        v.into_iter().next()
    };
    let (bx, by) = (best(xs), best(ys));
    let point = (
        bx.as_ref().map_or(cursor.0, |c| c.value),
        by.as_ref().map_or(cursor.1, |c| c.value),
    );
    // 兩軸都吸附之後，要重畫對齊線的終點（游標已經移到吸附位置）。
    let mut guides = Vec::new();
    if let Some(mut c) = bx {
        if let Some(end) = c.guide.points.last_mut() {
            *end = (c.value, point.1);
        }
        guides.push(c.guide);
    }
    if let Some(mut c) = by {
        if let Some(end) = c.guide.points.last_mut() {
            *end = (point.0, c.value);
        }
        guides.push(c.guide);
    }
    AlignResult { point, guides }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_cursor_near_the_same_x_snaps_to_it_and_draws_a_vertical_guide() {
        // 俯視圖的一個角在 (200, 100)；正視圖上游標在 (203, 400)：長對正。
        let r = align((203.0, 400.0), &[(200.0, 100.0)], None, true, 8.0);
        assert_eq!(r.point, (200.0, 400.0));
        assert_eq!(r.guides.len(), 1);
        assert_eq!(r.guides[0].kind, GuideKind::Vertical);
        assert_eq!(r.guides[0].points, vec![(200.0, 100.0), (200.0, 400.0)]);
    }

    #[test]
    fn a_cursor_near_the_same_y_snaps_to_it_and_draws_a_horizontal_guide() {
        let r = align((600.0, 396.0), &[(200.0, 400.0)], None, true, 8.0);
        assert_eq!(r.point, (600.0, 400.0));
        assert_eq!(r.guides[0].kind, GuideKind::Horizontal);
    }

    #[test]
    fn both_axes_can_snap_at_once_to_different_anchors() {
        let anchors = [(200.0, 100.0), (500.0, 400.0)];
        let r = align((203.0, 404.0), &anchors, None, true, 8.0);
        assert_eq!(r.point, (200.0, 400.0));
        assert_eq!(r.guides.len(), 2);
        // 兩條線都在吸附後的位置收尾。
        assert!(
            r.guides
                .iter()
                .all(|g| *g.points.last().unwrap() == (200.0, 400.0))
        );
    }

    #[test]
    fn nothing_near_means_nothing_snaps() {
        let r = align((300.0, 300.0), &[(100.0, 100.0)], None, true, 8.0);
        assert_eq!(r.point, (300.0, 300.0));
        assert!(r.guides.is_empty());
    }

    #[test]
    fn the_nearest_anchor_wins_on_each_axis() {
        let anchors = [(204.0, 0.0), (199.0, 50.0)];
        let r = align((200.0, 400.0), &anchors, None, true, 8.0);
        assert_eq!(r.point.0, 199.0, "199 離 200 比 204 近");
    }

    #[test]
    fn the_cursor_sitting_on_an_anchor_is_not_an_alignment() {
        let r = align((200.0, 100.0), &[(200.0, 100.0)], None, true, 8.0);
        assert!(r.guides.is_empty());
    }

    #[test]
    fn a_top_view_point_is_carried_to_the_right_view_through_the_45_degree_line() {
        // 第三角法：轉折點在 (400, 500)。俯視圖的點在 (300, 380)，在轉折點上方 120。
        // 傳遞之後右視圖的 x = 400 + 120 = 520：游標在 (518, 700) 就該吸到 x = 520。
        let pivot = Some((400.0, 500.0));
        let r = align((518.0, 700.0), &[(300.0, 380.0)], pivot, true, 8.0);
        assert_eq!(r.point.0, 520.0);
        let g = r
            .guides
            .iter()
            .find(|g| g.kind == GuideKind::Transfer)
            .expect("傳遞線");
        // 來源 → 水平拉到 45° 線（x = 520, y = 380）→ 垂直拉到游標。
        assert_eq!(g.points[0], (300.0, 380.0));
        assert_eq!(g.points[1], (520.0, 380.0));
        assert_eq!(*g.points.last().unwrap(), (520.0, 700.0));
    }

    #[test]
    fn a_right_view_point_is_carried_back_up_to_the_top_view() {
        // 右視圖的點在 (550, 650)，在轉折點右方 150 → 俯視圖的 y = 500 − 150 = 350。
        let pivot = Some((400.0, 500.0));
        let r = align((250.0, 353.0), &[(550.0, 650.0)], pivot, true, 8.0);
        assert_eq!(r.point.1, 350.0);
        assert!(r.guides.iter().any(|g| g.kind == GuideKind::Transfer));
    }

    #[test]
    fn the_first_angle_convention_mirrors_the_transfer() {
        // 第一角法：俯視圖在轉折點下方、右視圖在左方。俯視圖的點在轉折點下方 120 → 右視圖在左方 120。
        let pivot = Some((400.0, 500.0));
        let r = align((283.0, 100.0), &[(350.0, 620.0)], pivot, false, 8.0);
        assert_eq!(r.point.0, 280.0);
        // 同一個點在第三角法下不會被傳遞（它在轉折點下方）。
        let third = align((283.0, 100.0), &[(350.0, 620.0)], pivot, true, 8.0);
        assert!(third.guides.iter().all(|g| g.kind != GuideKind::Transfer));
    }

    #[test]
    fn without_a_pivot_there_is_no_transfer() {
        let r = align((520.0, 700.0), &[(300.0, 380.0)], None, true, 8.0);
        assert!(r.guides.is_empty());
    }
}
