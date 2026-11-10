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

/// 把填色多邊形換成「麥克筆掃滿」的筆畫路徑（頁面座標）：間距不超過筆寬的水平掃描線。
///
/// 為什麼用筆畫而不是新的「填色物件」：筆畫是兩個平台現成的資料（同一套筆點陣算繪、同步、復原、擦除），
/// 不用為填色另立一種會跨平台分岔的物件。用麥克筆（同一層墨、重疊不加深）掃，畫出來就是一整塊均勻的顏色。
///
/// # 不溢出邊界
///
/// 筆有寬度：沿著邊界描一圈、或掃描線端點剛好落在邊界上，筆的一半就畫到區域外面
/// （實測在空白地圖上填色，紅色溢出國界約半個筆寬）。所以每條掃描線取的是
/// 「`y − r`、`y`、`y + r` 三條線都在裡面」的那一段，再兩端各縮 `r`（`r` = 半個筆寬）——
/// 筆的圓頭整個落在區域內。代價是貼著斜邊會留一點點白，比畫出界好看。
///
/// `reach` 是筆**畫出來**離中心線最遠的距離、`step` 是掃描線間距（要小於筆畫出來的最窄厚度）。
/// 兩者分開給，是因為同一支筆在兩個平台的算繪不一樣寬（見 `padnote_core::fill_region_paths`）。
pub fn fill_scan_paths(polygon: &[(f32, f32)], reach: f32, step: f32) -> Vec<Vec<(f32, f32)>> {
    let mut out = Vec::new();
    if polygon.len() < 3 || reach <= 0.0 || step <= 0.0 {
        return out;
    }
    let r = reach;
    let (min_y, max_y) = polygon.iter().fold((f32::MAX, f32::MIN), |(lo, hi), p| {
        (lo.min(p.1), hi.max(p.1))
    });
    // 某一條水平線落在多邊形裡面的區段（由左到右）。
    let spans = |y: f32| -> Vec<(f32, f32)> {
        let mut xs: Vec<f32> = Vec::new();
        let n = polygon.len();
        for i in 0..n {
            let (x1, y1) = polygon[i];
            let (x2, y2) = polygon[(i + 1) % n];
            // 半開區間：頂點剛好在掃描線上時只算一次。
            if (y1 <= y && y < y2) || (y2 <= y && y < y1) {
                xs.push(x1 + (y - y1) / (y2 - y1) * (x2 - x1));
            }
        }
        xs.sort_by(|a, b| a.total_cmp(b));
        // 兩兩成對（進、出）。
        xs.as_chunks::<2>().0.iter().map(|p| (p[0], p[1])).collect()
    };
    // 區段 (a, b) 與另一條線上「重疊最多的那一段」的交集。沒有重疊回 None。
    let clip = |(a, b): (f32, f32), other: &[(f32, f32)]| -> Option<(f32, f32)> {
        other
            .iter()
            .map(|&(c, d)| (a.max(c), b.min(d)))
            .filter(|(lo, hi)| hi > lo)
            .max_by(|x, y| (x.1 - x.0).total_cmp(&(y.1 - y.0)))
    };
    let step = step.max(0.5);
    let mut y = min_y + r;
    if y >= max_y - r {
        // 比筆還窄的一條：只掃中間那一列。
        y = (min_y + max_y) * 0.5;
    }
    loop {
        let above = spans(y - r);
        let below = spans(y + r);
        for span in spans(y) {
            let Some(span) = clip(span, &above).and_then(|s| clip(s, &below)) else {
                continue;
            };
            let (a, b) = (span.0 + r, span.1 - r);
            // 比筆短的段不畫：在窄縫裡畫出來只是一顆圓點，實測看起來是一串墨漬，比留白難看。
            if b - a >= 2.0 * r {
                out.push(vec![(a, y), (b, y)]);
            }
        }
        y += step;
        if y > max_y - r {
            break;
        }
    }
    out
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

    #[test]
    fn scan_paths_cover_a_square_and_stay_inside() {
        let square = vec![(0.0, 0.0), (100.0, 0.0), (100.0, 100.0), (0.0, 100.0)];
        let paths = super::fill_scan_paths(&square, 5.0, 7.0);
        // 每條掃描線一段。
        assert!(paths.len() > 10, "掃描線太少：{}", paths.len());
        // 連筆的寬度（半徑 5）都要在方塊裡：不會畫出界。
        for path in &paths {
            for &(x, y) in path {
                assert!(
                    (5.0..=95.0).contains(&x) && (5.0..=95.0).contains(&y),
                    "筆畫出界：({x},{y})"
                );
            }
        }
        // 相鄰掃描線的間距不超過筆寬：不會留白縫。
        let ys: Vec<f32> = paths.iter().map(|p| p[0].1).collect();
        for w in ys.windows(2) {
            assert!(w[1] - w[0] <= 10.0, "掃描線間距過大");
        }
    }

    #[test]
    fn scan_paths_split_concave_rows() {
        // U 形：中間那一列被切成左右兩段，不會畫過缺口。
        let u = vec![
            (0.0, 0.0),
            (30.0, 0.0),
            (30.0, 60.0),
            (70.0, 60.0),
            (70.0, 0.0),
            (100.0, 0.0),
            (100.0, 100.0),
            (0.0, 100.0),
        ];
        let paths = super::fill_scan_paths(&u, 3.0, 4.2);
        let row = paths.iter().filter(|p| (p[0].1 - 30.0).abs() < 3.0).count();
        assert!(row >= 2, "凹進去的那一列應該切成兩段");
        for p in &paths {
            let (x0, y) = p[0];
            let x1 = p[1].0;
            if y < 60.0 {
                assert!(!(x0 < 40.0 && x1 > 60.0), "掃描線穿過了 U 形的缺口");
            }
        }
    }
}
