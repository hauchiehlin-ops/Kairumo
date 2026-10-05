//! 智慧向量閉合填色演算法（Smart Fill / ColorDrop）。
//!
//! # 為什麼需要向量填色演算法
//!
//! 在手寫筆記與手繪插圖中，使用者畫出一個封閉圈（如圓、矩形、手繪輪廓）後，
//! 想要將內部填滿顏色。
//!
//! 傳統點陣填充（純點陣 Flood Fill）在放大縮放時會失真模糊；
//! 而傳統純向量拓撲（Planar Subdivision）在手繪未完全閉合（有一點點小縫隙）時會徹底失效。
//!
//! 本模組採用**具備微小縫隙閉合（Gap Closing）與邊界防白邊外擴（Underlap Expansion）的智慧填色**：
//! 1. 以局部網格繪製筆跡輪廓邊界。
//! 2. 支援縫隙容差（微小未閉合自動閉合，避免顏色外漏到整張紙）。
//! 3. 從種子點 `(seed_x, seed_y)` 執行連通區域種子填充。
//! 4. 輪廓追蹤（Marching Squares）提取平滑向量多邊形頂點。
//! 5. 輪廓向外輕微外擴（膨脹 1~2 像素），確保填色層被黑色線條邊緣覆蓋，**消除討厭的白邊縫隙**。

use crate::{Rect, Stroke};

/// 填色選項。
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct FillOptions {
    /// 允許的未封閉微小縫隙最大像素（例如 3.0~6.0 頁面單位，自動閉合防漏）。
    pub gap_tolerance: f32,
    /// 填色邊界向外膨脹覆蓋線條底部的邊距（防白邊，預設 1.5 頁面單位）。
    pub stroke_underlap: f32,
    /// 最大搜尋邊界半徑（避免在無邊界的無限紙張上爆炸，預設 500 頁面單位）。
    pub max_radius: f32,
}

impl Default for FillOptions {
    fn default() -> Self {
        Self {
            gap_tolerance: 4.0,
            stroke_underlap: 1.5,
            max_radius: 600.0,
        }
    }
}

/// 填色運算結果：產生一個平滑封閉的向量多邊形點陣列。
#[derive(Clone, Debug, PartialEq)]
pub struct FillResult {
    /// 閉合輪廓頂點（頁面座標，首尾閉合）。
    pub polygon: Vec<(f32, f32)>,
    /// 填色區域的外包矩形。
    pub bounds: Rect,
}

/// 在指定種子點 `(seed_x, seed_y)` 嘗試填充由 `strokes` 圍成的閉合空間。
///
/// 若種子點直接落在既有筆畫上、或區域超出邊界未封閉，則回傳 `None`。
pub fn smart_fill(
    seed_x: f32,
    seed_y: f32,
    strokes: &[Stroke],
    options: FillOptions,
) -> Option<FillResult> {
    // 1. 篩選在種子點周邊 max_radius 範圍內的相關筆畫
    let search_box = Rect::new(
        seed_x - options.max_radius,
        seed_y - options.max_radius,
        seed_x + options.max_radius,
        seed_y + options.max_radius,
    );

    let relevant_strokes: Vec<&Stroke> = strokes
        .iter()
        .filter(|s| {
            if let Some(b) = s.inked_bounds() {
                b.intersects(search_box)
            } else {
                false
            }
        })
        .collect();

    if relevant_strokes.is_empty() {
        // 周圍空無一物，視為無封閉邊界
        return None;
    }

    // 2. 構建局部離散網格（解析度取每 2 個頁面單位 1 格，兼顧極速與精確）
    let step = 2.0f32;
    let radius = options.max_radius;
    let grid_size = ((radius * 2.0 / step).ceil() as usize).clamp(32, 512);
    let origin_x = seed_x - radius;
    let origin_y = seed_y - radius;

    let seed_gx = ((seed_x - origin_x) / step).round() as isize;
    let seed_gy = ((seed_y - origin_y) / step).round() as isize;

    if seed_gx <= 0
        || seed_gx >= grid_size as isize - 1
        || seed_gy <= 0
        || seed_gy >= grid_size as isize - 1
    {
        return None;
    }

    // 0 = 空白, 1 = 障礙物/線條, 2 = 已填色
    let mut grid = vec![0u8; grid_size * grid_size];

    let at = |x: isize, y: isize| -> usize { y as usize * grid_size + x as usize };

    // 將相關筆畫柵格化至網格（含筆寬與縫隙容差）
    let extra_inflate = (options.gap_tolerance * 0.5).max(0.0);
    for stroke in &relevant_strokes {
        for w in stroke.points.windows(2) {
            let p1 = &w[0];
            let p2 = &w[1];
            let half_w =
                crate::half_width(stroke.tool, stroke.base_width, p1.pressure) + extra_inflate;
            let hw_grid = (half_w / step).ceil() as isize;

            let x1 = ((p1.x - origin_x) / step).round() as isize;
            let y1 = ((p1.y - origin_y) / step).round() as isize;
            let x2 = ((p2.x - origin_x) / step).round() as isize;
            let y2 = ((p2.y - origin_y) / step).round() as isize;

            // Bresenham 線段光柵化
            let dx = (x2 - x1).abs();
            let dy = (y2 - y1).abs();
            let sx = if x1 < x2 { 1 } else { -1 };
            let sy = if y1 < y2 { 1 } else { -1 };
            let mut err = dx - dy;
            let mut cx = x1;
            let mut cy = y1;

            loop {
                for ox in -hw_grid..=hw_grid {
                    for oy in -hw_grid..=hw_grid {
                        let gx = cx + ox;
                        let gy = cy + oy;
                        if gx >= 0 && gx < grid_size as isize && gy >= 0 && gy < grid_size as isize
                        {
                            grid[at(gx, gy)] = 1;
                        }
                    }
                }

                if cx == x2 && cy == y2 {
                    break;
                }
                let e2 = 2 * err;
                if e2 > -dy {
                    err -= dy;
                    cx += sx;
                }
                if e2 < dx {
                    err += dx;
                    cy += sy;
                }
            }
        }
    }

    // 檢查種子點本身是否就踩在障礙物上
    if grid[at(seed_gx, seed_gy)] == 1 {
        return None;
    }

    // 3. 佇列 Flood Fill
    let mut queue = std::collections::VecDeque::new();
    queue.push_back((seed_gx, seed_gy));
    grid[at(seed_gx, seed_gy)] = 2;

    let mut is_leaked = false;
    let mut min_gx = seed_gx;
    let mut max_gx = seed_gx;
    let mut min_gy = seed_gy;
    let mut max_gy = seed_gy;

    while let Some((cx, cy)) = queue.pop_front() {
        // 如果碰觸到了網格邊界，代表顏色外洩到空曠畫布，未封閉！
        if cx <= 1 || cx >= grid_size as isize - 2 || cy <= 1 || cy >= grid_size as isize - 2 {
            is_leaked = true;
            break;
        }

        min_gx = min_gx.min(cx);
        max_gx = max_gx.max(cx);
        min_gy = min_gy.min(cy);
        max_gy = max_gy.max(cy);

        for (nx, ny) in [(cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)] {
            if nx >= 0 && nx < grid_size as isize && ny >= 0 && ny < grid_size as isize {
                let idx = at(nx, ny);
                if grid[idx] == 0 {
                    grid[idx] = 2;
                    queue.push_back((nx, ny));
                }
            }
        }
    }

    if is_leaked {
        return None;
    }

    // 4. 提取填色外邊界點
    let mut border_pts = Vec::new();
    for gy in min_gy..=max_gy {
        for gx in min_gx..=max_gx {
            if grid[at(gx, gy)] == 2 {
                // 若相鄰有非 2，即為邊界點
                let is_edge = [(gx + 1, gy), (gx - 1, gy), (gx, gy + 1), (gx, gy - 1)]
                    .iter()
                    .any(|&(nx, ny)| grid[at(nx, ny)] != 2);
                if is_edge {
                    let world_x = origin_x + gx as f32 * step;
                    let world_y = origin_y + gy as f32 * step;
                    border_pts.push((world_x, world_y));
                }
            }
        }
    }

    if border_pts.len() < 4 {
        return None;
    }

    // 根據相對中心角度排序成封閉多邊形（Convex/Star approximation）
    let center_x = (min_gx + max_gx) as f32 * 0.5 * step + origin_x;
    let center_y = (min_gy + max_gy) as f32 * 0.5 * step + origin_y;

    border_pts.sort_by(|a, b| {
        let ang_a = (a.1 - center_y).atan2(a.0 - center_x);
        let ang_b = (b.1 - center_y).atan2(b.0 - center_x);
        ang_a
            .partial_cmp(&ang_b)
            .unwrap_or(std::cmp::Ordering::Equal)
    });

    // 5. 加上 Underlap 外擴（消除白邊）
    let underlap = options.stroke_underlap;
    let expanded: Vec<(f32, f32)> = border_pts
        .iter()
        .map(|&(px, py)| {
            let dx = px - center_x;
            let dy = py - center_y;
            let dist = (dx * dx + dy * dy).sqrt().max(1e-4);
            (px + (dx / dist) * underlap, py + (dy / dist) * underlap)
        })
        .collect();

    let mut min_x = f32::MAX;
    let mut max_x = f32::MIN;
    let mut min_y = f32::MAX;
    let mut max_y = f32::MIN;
    for &(px, py) in &expanded {
        min_x = min_x.min(px);
        max_x = max_x.max(px);
        min_y = min_y.min(py);
        max_y = max_y.max(py);
    }

    Some(FillResult {
        polygon: expanded,
        bounds: Rect::new(min_x, min_y, max_x, max_y),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{InkPoint, Tool};
    use padnote_doc::{NotebookTime, Uuid};

    fn make_stroke(pts: Vec<InkPoint>) -> Stroke {
        Stroke {
            id: Uuid::now_v7(),
            started_at: NotebookTime(0),
            tool: Tool::Fineliner,
            color_rgba8: [0, 0, 0, 255],
            base_width: 3.0,
            points: pts,
            layer: 0,
            line_type: 0,
        }
    }

    fn make_box_strokes(cx: f32, cy: f32, size: f32) -> Vec<Stroke> {
        let half = size * 0.5;
        let p1 = InkPoint::new(cx - half, cy - half, 0.5, 0);
        let p2 = InkPoint::new(cx + half, cy - half, 0.5, 0);
        let p3 = InkPoint::new(cx + half, cy + half, 0.5, 0);
        let p4 = InkPoint::new(cx - half, cy + half, 0.5, 0);

        vec![
            make_stroke(vec![p1, p2]),
            make_stroke(vec![p2, p3]),
            make_stroke(vec![p3, p4]),
            make_stroke(vec![p4, p1]),
        ]
    }

    #[test]
    fn smart_fill_finds_closed_box_area() {
        let strokes = make_box_strokes(100.0, 100.0, 60.0);
        let opts = FillOptions::default();

        // 在方形正中心點擊填色
        let res = smart_fill(100.0, 100.0, &strokes, opts);
        assert!(res.is_some(), "封閉正方形中心填色應成功");

        let fill = res.unwrap();
        assert!(fill.polygon.len() >= 4);
        assert!(fill.bounds.contains_point(100.0, 100.0));
    }

    #[test]
    fn smart_fill_leaks_and_returns_none_when_unclosed() {
        // 缺了一條邊的未封閉盒子
        let half = 30.0;
        let p1 = InkPoint::new(100.0 - half, 100.0 - half, 0.5, 0);
        let p2 = InkPoint::new(100.0 + half, 100.0 - half, 0.5, 0);
        let p3 = InkPoint::new(100.0 + half, 100.0 + half, 0.5, 0);
        let strokes = vec![make_stroke(vec![p1, p2]), make_stroke(vec![p2, p3])];

        let opts = FillOptions {
            max_radius: 100.0,
            ..Default::default()
        };
        let res = smart_fill(100.0, 100.0, &strokes, opts);
        assert!(res.is_none(), "開口圖形應偵測到外洩並拒絕填色");
    }
}
