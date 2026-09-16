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
    Ellipse,
    Rectangle,
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

    let closed = start_end < diag * 0.28;
    if !closed || count < 10 {
        return None;
    }

    let cx = (min_x + max_x) / 2.0;
    let cy = (min_y + max_y) / 2.0;
    let rx = width / 2.0;
    let ry = height / 2.0;

    // **兩種圖形一起評分，取誤差小的那個。**
    //
    // 原本（Apple 端）是先測橢圓、過門檻就收工，測不過才測矩形。問題是
    // 那個門檻（平均正規化半徑誤差 < 0.28）連**矩形也過得了** —— 軸對齊
    // 矩形的平均誤差算出來約 0.15。結果畫一個方框，美化之後變成橢圓，
    // 矩形那一段幾乎是死碼。這裡改成兩邊都算成「離理想輪廓多遠 ÷ 對角線」，
    // 同一個尺度上直接比大小，誰近算誰。
    let ellipse_err = ellipse_error(points, cx, cy, rx, ry) / diag;
    let rect_err = rectangle_error(points, min_x, max_x, min_y, max_y) / diag;

    // 兩邊都不像就別硬套。門檻是相對於對角線的比例，所以與圖形大小無關。
    const MAX_FIT_ERROR: f32 = 0.06;
    if ellipse_err.min(rect_err) > MAX_FIT_ERROR {
        return None;
    }

    if ellipse_err <= rect_err {
        let is_circle = (width - height).abs() / width.max(height) < 0.22;
        let (fx, fy) = if is_circle {
            let r = (rx + ry) / 2.0;
            (r, r)
        } else {
            (rx, ry)
        };
        return Some((RefinedKind::Ellipse, ellipse_points(cx, cy, fx, fy, count)));
    }

    Some((
        RefinedKind::Rectangle,
        rectangle_points(min_x, max_x, min_y, max_y, count),
    ))
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
    fn a_tiny_scribble_is_not_snapped_to_a_shape() {
        // 對角線 20 點以下不辨識：簽名上的小圈圈不該全部變成正圓。
        let pts = circle(20, 0.0)
            .iter()
            .map(|&(x, y)| ((x - 100.0) * 0.1 + 100.0, (y - 100.0) * 0.1 + 100.0))
            .collect::<Vec<_>>();
        assert_eq!(refine_stroke(&pts, 1.0).kind, RefinedKind::Freehand);
    }
}
