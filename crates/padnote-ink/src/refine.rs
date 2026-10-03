//! 草圖美化：把手繪筆畫辨識成幾何圖形，或做抗抖動平滑。
//!
//! # 為什麼在核心
//!
//! 這一段原本只存在於 `apple/Sources/SketchRefineEngine.swift`，Android 沒有。
//! 它是**純幾何**：輸入一串點、輸出一串點，跟 PencilKit 或 Compose 都沒有關係。
//! 留在平台層的話兩邊會各自調門檻，同一個圓在 iPad 上被拉成正圓、在手機上
//! 還是歪的 —— 而使用者換裝置只會覺得「Android 版比較笨」。
//!
//! # 判定順序（順序有意義）
//!
//! 1. **直線**：起訖點距離幾乎等於路徑總長 —— 走了直線就不會有多餘路程。
//! 2. **閉合**：起訖點靠得夠近才繼續往下判圓與矩形；沒閉合的弧線不該被拉成圓。
//! 3. **圓／橢圓**：各點到中心的正規化半徑接近 1。
//! 4. **矩形**：多數點落在邊界框的四條邊附近。
//!
//! 都不是就走平滑。平滑永遠不會失敗，所以這個函式一定回得出東西。

/// 辨識結果。平台層用它決定要不要提示「已辨識為圓形」之類的訊息。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum RefinedKind {
    /// 沒認出特定圖形，只做了平滑。
    Freehand,
    Line,
    Arrow,
    Ellipse,
    Rectangle,
    Triangle,
}

/// 美化後的筆畫。
#[derive(Clone, Debug)]
pub struct Refined {
    pub kind: RefinedKind,
    /// 與輸入**等長**的點串。
    ///
    /// 等長是刻意的：平台層要把壓感、時間戳、方位角逐點抄回去，
    /// 長度不一樣就得猜要抄哪一個，而猜錯會讓筆畫粗細突然跳動。
    pub points: Vec<(f32, f32)>,
}

fn hypot(dx: f32, dy: f32) -> f32 {
    (dx * dx + dy * dy).sqrt()
}

/// 美化一筆。
///
/// `intensity` 是「往理想圖形靠多少」，0 = 完全不動、1 = 完全採用辨識結果。
/// 超出 0…1 會被夾住 —— 平台層傳進來的常是滑桿值，夾住比回錯誤實用。
///
/// 點數少於 3 的筆畫原樣回傳：兩個點沒有形狀可言。
pub fn refine_stroke(points: &[(f32, f32)], intensity: f32) -> Refined {
    let intensity = intensity.clamp(0.0, 1.0);
    if points.len() < 3 {
        return Refined {
            kind: RefinedKind::Freehand,
            points: points.to_vec(),
        };
    }

    if let Some((kind, target)) = detect_shape(points) {
        return Refined {
            kind,
            points: blend(points, &target, intensity),
        };
    }

    Refined {
        kind: RefinedKind::Freehand,
        points: smooth(points, intensity),
    }
}

/// 邊界框與路徑總長。
fn bounds_and_length(points: &[(f32, f32)]) -> (f32, f32, f32, f32, f32) {
    let mut min_x = f32::INFINITY;
    let mut max_x = f32::NEG_INFINITY;
    let mut min_y = f32::INFINITY;
    let mut max_y = f32::NEG_INFINITY;
    let mut length = 0.0;
    for (i, &(x, y)) in points.iter().enumerate() {
        min_x = min_x.min(x);
        max_x = max_x.max(x);
        min_y = min_y.min(y);
        max_y = max_y.max(y);
        if i > 0 {
            let (px, py) = points[i - 1];
            length += hypot(x - px, y - py);
        }
    }
    (min_x, max_x, min_y, max_y, length)
}

fn detect_shape(points: &[(f32, f32)]) -> Option<(RefinedKind, Vec<(f32, f32)>)> {
    let count = points.len();
    let first = *points.first()?;
    let last = *points.last()?;
    let start_end = hypot(first.0 - last.0, first.1 - last.1);

    let (min_x, max_x, min_y, max_y, total_length) = bounds_and_length(points);
    let width = max_x - min_x;
    let height = max_y - min_y;
    let diag = hypot(width, height);
    // 太小的筆畫不辨識：點一下的小點被拉成正圓會很怪。
    if diag <= 20.0 {
        return None;
    }

    let straight_ratio = start_end / total_length.max(1.0);
    if straight_ratio > 0.88 && count >= 5 {
        return Some((RefinedKind::Line, line_points(first, last, count)));
    }

    // ── 箭頭偵測 ──
    // 使用者常畫一條線並在末端折回兩次或一次形成箭頭（或起點折回）。
    if let Some(arrow_pts) = detect_arrow(points, total_length, diag) {
        return Some((RefinedKind::Arrow, arrow_pts));
    }

    let closed = start_end < diag * 0.28;
    if !closed || count < 10 {
        return None;
    }

    let cx = (min_x + max_x) / 2.0;
    let cy = (min_y + max_y) / 2.0;
    let rx = width / 2.0;
    let ry = height / 2.0;

    // **三種閉合圖形一起評分，取誤差最小的那個。**
    // 圓形/橢圓、矩形、三角形同一個尺度上（離理想輪廓多遠 ÷ 對角線）直接比大小。
    let ellipse_err = ellipse_error(points, cx, cy, rx, ry) / diag;
    let rect_err = rectangle_error(points, min_x, max_x, min_y, max_y) / diag;
    let (tri_err_val, tri_pts_opt) = triangle_fit(points, min_x, max_x, min_y, max_y, diag);
    let tri_err = tri_err_val / diag;

    // 都不像就別硬套。門檻是相對於對角線的比例，所以與圖形大小無關。
    const MAX_FIT_ERROR: f32 = 0.065;
    let best_err = ellipse_err.min(rect_err).min(tri_err);
    if best_err > MAX_FIT_ERROR {
        return None;
    }

    if (best_err - ellipse_err).abs() < 1e-5 {
        let is_circle = (width - height).abs() / width.max(height) < 0.22;
        let (fx, fy) = if is_circle {
            let r = (rx + ry) / 2.0;
            (r, r)
        } else {
            (rx, ry)
        };
        return Some((RefinedKind::Ellipse, ellipse_points(cx, cy, fx, fy, count)));
    }

    if (best_err - rect_err).abs() < 1e-5 {
        return Some((
            RefinedKind::Rectangle,
            rectangle_points(min_x, max_x, min_y, max_y, count),
        ));
    }

    if let Some(tri_pts) = tri_pts_opt {
        return Some((RefinedKind::Triangle, tri_pts));
    }

    None
}

/// 各點離該橢圓輪廓的平均距離（點）。
///
/// 用正規化半徑誤差乘上平均半徑來近似真實距離 —— 精確解要解四次方程式，
/// 而這裡只是要比大小，近似足夠，還便宜很多。
fn ellipse_error(points: &[(f32, f32)], cx: f32, cy: f32, rx: f32, ry: f32) -> f32 {
    let scale = (rx + ry) / 2.0;
    let sum: f32 = points
        .iter()
        .map(|&(x, y)| {
            let dx = (x - cx) / rx.max(1.0);
            let dy = (y - cy) / ry.max(1.0);
            (hypot(dx, dy) - 1.0).abs() * scale
        })
        .sum();
    sum / points.len() as f32
}

/// 各點離邊界框四條邊的平均距離（點）。點在框內時取到最近一條邊的距離。
fn rectangle_error(points: &[(f32, f32)], min_x: f32, max_x: f32, min_y: f32, max_y: f32) -> f32 {
    let sum: f32 = points
        .iter()
        .map(|&(x, y)| {
            (x - min_x)
                .abs()
                .min((x - max_x).abs())
                .min((y - min_y).abs())
                .min((y - max_y).abs())
        })
        .sum();
    sum / points.len() as f32
}

/// 尋找三角形頂點擬合並計算誤差。
fn triangle_fit(
    points: &[(f32, f32)],
    min_x: f32,
    max_x: f32,
    min_y: f32,
    max_y: f32,
    diag: f32,
) -> (f32, Option<Vec<(f32, f32)>>) {
    let simplified = crate::geometry::simplify(points, diag * 0.08);
    // 閉合三角形通常簡化後頂點在 3~5 之間（首尾重複）
    let vertices = if simplified.len() >= 4
        && hypot(
            simplified[0].0 - simplified.last().unwrap().0,
            simplified[0].1 - simplified.last().unwrap().1,
        ) < diag * 0.25
    {
        &simplified[..simplified.len() - 1]
    } else {
        &simplified[..]
    };

    let (v0, v1, v2) = if vertices.len() == 3 {
        (vertices[0], vertices[1], vertices[2])
    } else {
        // 若簡化點數不剛好為 3，找極值三點：離中心最遠的三個角度分佈點
        let cx = (min_x + max_x) / 2.0;
        let cy = (min_y + max_y) / 2.0;
        let mut sorted = points.to_vec();
        sorted.sort_by(|a, b| {
            let da = (a.0 - cx).powi(2) + (a.1 - cy).powi(2);
            let db = (b.0 - cx).powi(2) + (b.1 - cy).powi(2);
            db.partial_cmp(&da).unwrap_or(std::cmp::Ordering::Equal)
        });
        if sorted.len() < 3 {
            return (f32::INFINITY, None);
        }
        let p0 = sorted[0];
        // p1: 離 p0 夠遠的點
        let p1 = match sorted
            .iter()
            .find(|p| hypot(p.0 - p0.0, p.1 - p0.1) > diag * 0.4)
        {
            Some(&p) => p,
            None => return (f32::INFINITY, None),
        };
        // p2: 離 p0 與 p1 的連線最遠的點
        let p2 = match sorted.iter().max_by(|a, b| {
            let da = crate::geometry::distance_to_segment(**a, p0, p1);
            let db = crate::geometry::distance_to_segment(**b, p0, p1);
            da.partial_cmp(&db).unwrap_or(std::cmp::Ordering::Equal)
        }) {
            Some(&p) if crate::geometry::distance_to_segment(p, p0, p1) > diag * 0.25 => p,
            _ => return (f32::INFINITY, None),
        };
        (p0, p1, p2)
    };

    // 計算三角形三邊的平均距離誤差
    let tri_segments = [(v0, v1), (v1, v2), (v2, v0)];
    let sum: f32 = points
        .iter()
        .map(|&p| {
            tri_segments
                .iter()
                .map(|&(a, b)| crate::geometry::distance_to_segment(p, a, b))
                .fold(f32::INFINITY, f32::min)
        })
        .sum();
    let err = sum / points.len() as f32;

    let target = polygon_points(&[v0, v1, v2, v0], points.len());
    (err, Some(target))
}

/// 偵測單筆手繪箭頭（主幹 + 箭頭翼）
fn detect_arrow(points: &[(f32, f32)], _total_length: f32, diag: f32) -> Option<Vec<(f32, f32)>> {
    let count = points.len();
    if count < 10 || diag < 30.0 {
        return None;
    }
    // Ramer-Douglas-Peucker 簡化
    let s = crate::geometry::simplify(points, diag * 0.08);
    // 單筆畫箭頭通常簡化後有 3 到 7 個轉折點：
    if s.len() < 3 || s.len() > 8 {
        return None;
    }

    let first = *points.first()?;
    let last = *points.last()?;

    // 起點與終點距離不應過近（閉合圖形不是箭頭）
    let start_end = hypot(first.0 - last.0, first.1 - last.1);
    if start_end < diag * 0.35 {
        return None;
    }

    // 找離起點最遠的點作為箭頭頂點（若有多個取最早到達者，即主幹終點）
    let (head_idx, &(hx, hy)) = points.iter().enumerate().max_by(|(i_a, a), (i_b, b)| {
        let da = hypot(a.0 - first.0, a.1 - first.1);
        let db = hypot(b.0 - first.0, b.1 - first.1);
        da.partial_cmp(&db)
            .unwrap_or(std::cmp::Ordering::Equal)
            .then_with(|| i_b.cmp(i_a)) // 最早到達頂點的索引
    })?;

    // 箭頭頂點離起點必須佔有足夠比例的主幹長度，且通常在筆畫中後段（25%~90% 處）
    let stem_len = hypot(hx - first.0, hy - first.1);
    if stem_len < diag * 0.70 || head_idx < count * 25 / 100 || head_idx > count * 90 / 100 {
        return None;
    }

    // 檢查前半段（主幹）是否足夠筆直
    let stem_pts = &points[..=head_idx];
    let (_, _, _, _, stem_path_len) = bounds_and_length(stem_pts);
    if stem_len / stem_path_len.max(1.0) < 0.85 {
        return None;
    }

    // 後半段（翼部）長度不應過長（通常為總長 10%~90%）
    let tail_pts = &points[head_idx..];
    let (_, _, _, _, tail_path_len) = bounds_and_length(tail_pts);
    if tail_path_len < stem_len * 0.1 || tail_path_len > stem_len * 1.5 {
        return None;
    }

    // 主幹方向單位向量
    let dx = (hx - first.0) / stem_len;
    let dy = (hy - first.1) / stem_len;

    // 箭頭兩翼的長度與角度（約 25 度 ~ 30 度）
    let wing_len = (stem_len * 0.22).clamp(12.0, 45.0);
    let wing_angle: f32 = 0.45; // ~26 度
    let cos_w = wing_angle.cos();
    let sin_w = wing_angle.sin();

    // 逆向反衝向量 (-dx, -dy) 旋轉
    let w1 = (
        hx + wing_len * (-dx * cos_w - -dy * sin_w),
        hy + wing_len * (-dx * sin_w + -dy * cos_w),
    );
    let w2 = (
        hx + wing_len * (-dx * cos_w + -dy * sin_w),
        hy + wing_len * (dx * sin_w + -dy * cos_w),
    );

    // 檢查末端點是否都在箭頭頭部附近（兩翼展開區域）
    let max_dist_to_head = tail_pts
        .iter()
        .map(|&(x, y)| hypot(x - hx, y - hy))
        .fold(0.0, f32::max);
    if max_dist_to_head > wing_len * 1.8 {
        return None;
    }

    // 理想箭頭折線：起點 -> 箭頭頭部 -> 翼1 -> 箭頭頭部 -> 翼2
    let arrow_skeleton = [first, (hx, hy), w1, (hx, hy), w2];
    Some(polygon_points(&arrow_skeleton, count))
}

fn polygon_points(vertices: &[(f32, f32)], count: usize) -> Vec<(f32, f32)> {
    if vertices.len() < 2 {
        return vec![(0.0, 0.0); count];
    }
    let num_segs = vertices.len() - 1;
    let pts_per_seg = (count / num_segs).max(2);
    let mut out = Vec::with_capacity(num_segs * pts_per_seg);
    for i in 0..num_segs {
        let (x1, y1) = vertices[i];
        let (x2, y2) = vertices[i + 1];
        let limit = if i == num_segs - 1 {
            count.saturating_sub(out.len())
        } else {
            pts_per_seg
        };
        for s in 0..limit {
            let t = s as f32 / limit as f32;
            out.push((x1 + (x2 - x1) * t, y1 + (y2 - y1) * t));
        }
    }
    while out.len() < count {
        out.push(*vertices.last().unwrap());
    }
    out.truncate(count);
    out
}

fn line_points(start: (f32, f32), end: (f32, f32), count: usize) -> Vec<(f32, f32)> {
    (0..count)
        .map(|i| {
            let t = i as f32 / (count - 1) as f32;
            (
                start.0 + (end.0 - start.0) * t,
                start.1 + (end.1 - start.1) * t,
            )
        })
        .collect()
}

fn ellipse_points(cx: f32, cy: f32, rx: f32, ry: f32, count: usize) -> Vec<(f32, f32)> {
    (0..count)
        .map(|i| {
            let angle = (i as f32 / count as f32) * std::f32::consts::TAU;
            (cx + rx * angle.cos(), cy + ry * angle.sin())
        })
        .collect()
}

fn rectangle_points(
    min_x: f32,
    max_x: f32,
    min_y: f32,
    max_y: f32,
    count: usize,
) -> Vec<(f32, f32)> {
    let corners = [
        (min_x, min_y),
        (max_x, min_y),
        (max_x, max_y),
        (min_x, max_y),
        (min_x, min_y),
    ];
    let segment = (count / 4).max(2);
    let mut out = Vec::with_capacity(segment * 4);
    for i in 0..4 {
        let (x1, y1) = corners[i];
        let (x2, y2) = corners[i + 1];
        for s in 0..segment {
            let t = s as f32 / segment as f32;
            out.push((x1 + (x2 - x1) * t, y1 + (y2 - y1) * t));
        }
    }
    out
}

/// 加權移動平均。窗內越遠的點權重越低，所以轉角不會被抹平成圓弧。
fn smooth(points: &[(f32, f32)], intensity: f32) -> Vec<(f32, f32)> {
    if points.len() < 4 {
        return points.to_vec();
    }
    let mut out = points.to_vec();
    let window = 5.min(points.len() / 2);
    for i in 1..points.len() - 1 {
        let start = i.saturating_sub(window);
        let end = (i + window).min(points.len() - 1);
        let mut sx = 0.0;
        let mut sy = 0.0;
        let mut wsum = 0.0;
        // 用 enumerate 而不是索引取值：clippy 的 needless_range_loop 說得對，
        // 而且權重要的是「離中心多遠」，那與索引本身無關。
        for (j, point) in points.iter().enumerate().take(end + 1).skip(start) {
            let dist = (j as f32 - i as f32).abs();
            let weight = (1.0 - dist / (window as f32 + 1.0)).max(0.1);
            sx += point.0 * weight;
            sy += point.1 * weight;
            wsum += weight;
        }
        let (ox, oy) = points[i];
        out[i] = (
            ox * (1.0 - intensity) + (sx / wsum) * intensity,
            oy * (1.0 - intensity) + (sy / wsum) * intensity,
        );
    }
    out
}

/// 把原始點往目標圖形拉。
///
/// 目標點數與原始點數不一定一樣（矩形就不一樣），所以按比例取樣；
/// 輸出長度永遠等於輸入長度，理由見 [`Refined::points`]。
fn blend(original: &[(f32, f32)], target: &[(f32, f32)], intensity: f32) -> Vec<(f32, f32)> {
    let n = original.len();
    let m = target.len();
    original
        .iter()
        .enumerate()
        .map(|(i, &(ox, oy))| {
            let idx = (((i as f32 / n as f32) * m as f32) as usize).min(m - 1);
            let (tx, ty) = target[idx];
            (
                ox * (1.0 - intensity) + tx * intensity,
                oy * (1.0 - intensity) + ty * intensity,
            )
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn circle(n: usize, jitter: f32) -> Vec<(f32, f32)> {
        (0..n)
            .map(|i| {
                let a = (i as f32 / n as f32) * std::f32::consts::TAU;
                let wobble = if i % 2 == 0 { jitter } else { -jitter };
                (
                    100.0 + (60.0 + wobble) * a.cos(),
                    100.0 + (60.0 + wobble) * a.sin(),
                )
            })
            .collect()
    }

    #[test]
    fn a_wobbly_circle_becomes_a_circle() {
        let out = refine_stroke(&circle(40, 4.0), 1.0);
        assert_eq!(out.kind, RefinedKind::Ellipse);
        // 抖動被吃掉：每個點到圓心的距離都一樣（半徑取自邊界框，
        // 所以是 60 + 抖動幅度，不是剛好 60）。
        let r0 = hypot(out.points[0].0 - 100.0, out.points[0].1 - 100.0);
        assert!((r0 - 64.0).abs() < 1.0, "半徑 {r0} 不符邊界框");
        for &(x, y) in &out.points {
            assert!((hypot(x - 100.0, y - 100.0) - r0).abs() < 0.01);
        }
    }

    #[test]
    fn a_shaky_line_becomes_straight() {
        let pts: Vec<(f32, f32)> = (0..20)
            .map(|i| (i as f32 * 10.0, 50.0 + if i % 2 == 0 { 1.5 } else { -1.5 }))
            .collect();
        let out = refine_stroke(&pts, 1.0);
        assert_eq!(out.kind, RefinedKind::Line);
        // 全部落在起訖點連成的那條線上（抖動被吃掉）。
        let (x0, y0) = out.points[0];
        let (x1, y1) = *out.points.last().unwrap();
        for &(x, y) in &out.points {
            let cross = (x - x0) * (y1 - y0) - (y - y0) * (x1 - x0);
            assert!(
                cross.abs() / hypot(x1 - x0, y1 - y0) < 0.01,
                "({x},{y}) 不在線上"
            );
        }
    }

    #[test]
    fn a_rough_rectangle_is_recognised() {
        // 沿著邊界框走一圈，每條邊上帶一點抖動。
        let mut pts = Vec::new();
        for i in 0..15 {
            pts.push((i as f32 * 10.0, if i % 2 == 0 { 0.0 } else { 2.0 }));
        }
        for i in 0..15 {
            pts.push((140.0 + if i % 2 == 0 { 0.0 } else { -2.0 }, i as f32 * 6.0));
        }
        for i in 0..15 {
            pts.push((
                140.0 - i as f32 * 10.0,
                84.0 + if i % 2 == 0 { 0.0 } else { -2.0 },
            ));
        }
        for i in 0..15 {
            pts.push((if i % 2 == 0 { 0.0 } else { 2.0 }, 84.0 - i as f32 * 6.0));
        }
        let out = refine_stroke(&pts, 1.0);
        assert_eq!(out.kind, RefinedKind::Rectangle);
    }

    #[test]
    fn an_open_arc_is_not_turned_into_a_circle() {
        // 只畫半圈。拉成整圓的話使用者畫的弧線會憑空長出另外半邊 ——
        // 「智慧美化」變成「亂改我的圖」。
        let pts: Vec<(f32, f32)> = (0..30)
            .map(|i| {
                let a = (i as f32 / 30.0) * std::f32::consts::PI;
                (100.0 + 60.0 * a.cos(), 100.0 + 60.0 * a.sin())
            })
            .collect();
        let out = refine_stroke(&pts, 1.0);
        assert_eq!(out.kind, RefinedKind::Freehand);
    }

    #[test]
    fn output_length_always_matches_input() {
        // 平台層靠這個逐點抄回壓感與時間戳。
        for pts in [circle(40, 4.0), circle(11, 30.0)] {
            let n = pts.len();
            assert_eq!(refine_stroke(&pts, 0.85).points.len(), n);
        }
    }

    #[test]
    fn zero_intensity_changes_nothing() {
        // 滑桿拉到 0 還在動的話，使用者沒辦法比較「美化前後」。
        let pts = circle(40, 4.0);
        let out = refine_stroke(&pts, 0.0);
        for (a, b) in pts.iter().zip(out.points.iter()) {
            assert!((a.0 - b.0).abs() < 0.001 && (a.1 - b.1).abs() < 0.001);
        }
    }

    #[test]
    fn a_two_point_stroke_is_returned_untouched() {
        let pts = vec![(0.0, 0.0), (10.0, 10.0)];
        assert_eq!(refine_stroke(&pts, 1.0).points, pts);
    }

    #[test]
    fn a_rough_triangle_is_recognised() {
        let mut pts = Vec::new();
        // 底邊 (0, 100) -> (100, 100)
        for i in 0..15 {
            pts.push((
                i as f32 * (100.0 / 14.0),
                100.0 + if i % 2 == 0 { 0.0 } else { 1.5 },
            ));
        }
        // 右邊 (100, 100) -> (50, 10)
        for i in 0..15 {
            let t = i as f32 / 14.0;
            pts.push((
                100.0 + (50.0 - 100.0) * t + if i % 2 == 0 { 0.0 } else { -1.5 },
                100.0 + (10.0 - 100.0) * t,
            ));
        }
        // 左邊 (50, 10) -> (0, 100)
        for i in 0..15 {
            let t = i as f32 / 14.0;
            pts.push((
                50.0 + (0.0 - 50.0) * t + if i % 2 == 0 { 0.0 } else { 1.5 },
                10.0 + (100.0 - 10.0) * t,
            ));
        }
        let out = refine_stroke(&pts, 1.0);
        assert_eq!(out.kind, RefinedKind::Triangle);
    }

    #[test]
    fn a_rough_arrow_is_recognised() {
        let mut pts = Vec::new();
        // 主幹 (0, 50) -> (100, 50)
        for i in 0..20 {
            pts.push((i as f32 * 5.0, 50.0 + if i % 2 == 0 { 0.5 } else { -0.5 }));
        }
        // 箭翼1 (100, 50) -> (85, 35)
        for i in 0..6 {
            let t = i as f32 / 5.0;
            pts.push((100.0 - 15.0 * t, 50.0 - 15.0 * t));
        }
        // 折返至頂點 (85, 35) -> (100, 50)
        for i in 0..6 {
            let t = i as f32 / 5.0;
            pts.push((85.0 + 15.0 * t, 35.0 + 15.0 * t));
        }
        // 箭翼2 (100, 50) -> (85, 65)
        for i in 0..6 {
            let t = i as f32 / 5.0;
            pts.push((100.0 - 15.0 * t, 50.0 + 15.0 * t));
        }
        let out = refine_stroke(&pts, 1.0);
        assert_eq!(out.kind, RefinedKind::Arrow);
    }

    #[test]
    fn a_tiny_scribble_is_not_snapped_to_a_shape() {
        // 對角線 20 點以下不辨識：簽名上的小圈圈不該全部變成正圓。
        let pts = circle(20, 0.0)
            .iter()
            .map(|&(x, y)| ((x - 100.0) * 0.1 + 100.0, (y - 100.0) * 0.1 + 100.0))
            .collect::<Vec<_>>();
        assert_eq!(refine_stroke(&pts, 1.0).kind, RefinedKind::Freehand);
    }
}
