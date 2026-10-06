//! 筆畫轉 SVG 路徑（功能 H3）。
//!
//! SVG 是向量的，縮放無損，且任何瀏覽器與繪圖軟體都能開 —— 比匯出 PNG
//! 更符合「資料帶得走」的承諾。

use padnote_ink::{Stroke, geometry::half_width};

/// 把一筆畫轉成 SVG `<path>` 的 `d` 屬性。
///
/// 用可變寬度的外框多邊形（outline）而非單一折線，這樣壓感造成的粗細變化
/// 才能保留 —— 折線 + `stroke-width` 只能有固定寬度。
pub fn stroke_to_svg_path(stroke: &Stroke, subdivisions: usize) -> String {
    let path = stroke.render_path(subdivisions);
    if path.len() < 2 {
        // 單點畫成一個小圓。
        if let Some(&(x, y)) = path.first() {
            let r = half_width(stroke.tool, stroke.base_width, stroke.points[0].pressure);
            return format!(
                "M {x} {y} m -{r} 0 a {r} {r} 0 1 0 {d} 0 a {r} {r} 0 1 0 -{d} 0 Z",
                d = r * 2.0
            );
        }
        return String::new();
    }

    // 製圖線型（隱藏線、中心線、假想線）：依圖樣切成一段一段，每一段各自一個外框，
    // 全部放在同一個 `d` 裡（多個子路徑）。製圖線等寬，壓力取平均。
    let pattern = padnote_ink::LineType::from_id(stroke.line_type).pattern();
    if !pattern.is_empty() {
        let mean =
            stroke.points.iter().map(|p| p.pressure).sum::<f32>() / stroke.points.len() as f32;
        let hw = half_width(stroke.tool, stroke.base_width, mean);
        return padnote_ink::dash_runs(&path, pattern)
            .iter()
            .filter(|run| run.len() >= 2)
            .map(|run| outline_d(run, |_| hw))
            .collect::<Vec<_>>()
            .join(" ");
    }

    // 壓感取樣點數與插值後的路徑點數不同，用比例對應回原始取樣。
    let pressure_at = |i: usize| -> f32 {
        let ratio = i as f32 / (path.len().max(2) - 1) as f32;
        let idx = ((ratio * (stroke.points.len() - 1) as f32).round() as usize)
            .min(stroke.points.len() - 1);
        stroke.points[idx].pressure
    };
    outline_d(&path, |i| {
        half_width(stroke.tool, stroke.base_width, pressure_at(i))
    })
}

/// 沿折線的左右兩側偏移 `hw(i)`，圍成一個封閉外框。
fn outline_d(path: &[(f32, f32)], hw: impl Fn(usize) -> f32) -> String {
    let mut left = Vec::with_capacity(path.len());
    let mut right = Vec::with_capacity(path.len());

    for i in 0..path.len() {
        let prev = path[i.saturating_sub(1)];
        let next = path[(i + 1).min(path.len() - 1)];
        let (dx, dy) = (next.0 - prev.0, next.1 - prev.1);
        let len = (dx * dx + dy * dy).sqrt();
        let (nx, ny) = if len > 1e-5 {
            (-dy / len, dx / len)
        } else {
            (0.0, 1.0)
        };
        let w = hw(i);
        let (x, y) = path[i];
        left.push((x + nx * w, y + ny * w));
        right.push((x - nx * w, y - ny * w));
    }

    let mut d = String::new();
    for (i, (x, y)) in left.iter().enumerate() {
        d.push_str(&format!(
            "{} {x:.2} {y:.2} ",
            if i == 0 { "M" } else { "L" }
        ));
    }
    for (x, y) in right.iter().rev() {
        d.push_str(&format!("L {x:.2} {y:.2} "));
    }
    d.push('Z');
    d
}

#[cfg(test)]
mod tests {
    use super::*;
    use padnote_doc::{NotebookTime, Uuid};
    use padnote_ink::{InkPoint, Tool};

    fn stroke(points: Vec<InkPoint>) -> Stroke {
        Stroke {
            id: Uuid::from_bytes([1; 16]),
            started_at: NotebookTime::ZERO,
            tool: Tool::FountainPen,
            color_rgba8: [0, 0, 0, 255],
            base_width: 4.0,
            points,
            layer: 0,
            line_type: 0,
        }
    }

    #[test]
    fn a_hidden_line_exports_as_separate_dashes_and_a_solid_one_as_one_outline() {
        let pts: Vec<InkPoint> = (0..=50)
            .map(|i| InkPoint {
                x: i as f32 * 2.0,
                y: 10.0,
                pressure: 0.6,
                tilt: 0.0,
                azimuth: 0.0,
                dt_us: 1000,
                roll: 0.0,
            })
            .collect();
        let solid = stroke(pts.clone());
        let mut hidden = stroke(pts);
        hidden.line_type = 1;
        let one = stroke_to_svg_path(&solid, 2);
        let dashed = stroke_to_svg_path(&hidden, 2);
        assert_eq!(one.matches('Z').count(), 1);
        // 100 單位、圖樣 12+4：7 段。
        assert_eq!(dashed.matches('Z').count(), 7, "{dashed}");
    }

    #[test]
    fn produces_a_closed_outline() {
        let d = stroke_to_svg_path(
            &stroke(vec![
                InkPoint::new(0.0, 0.0, 0.5, 0),
                InkPoint::new(100.0, 0.0, 1.0, 8_000),
            ]),
            2,
        );
        assert!(d.starts_with("M "), "必須以 moveto 起始");
        assert!(d.ends_with('Z'), "外框必須封閉，否則填色會漏");
        assert!(d.contains('L'));
    }

    #[test]
    fn single_point_becomes_a_dot() {
        let d = stroke_to_svg_path(&stroke(vec![InkPoint::new(5.0, 5.0, 1.0, 0)]), 2);
        assert!(d.contains('a'), "單點應畫成圓弧而非空字串：{d}");
    }

    #[test]
    fn empty_stroke_produces_nothing() {
        assert!(stroke_to_svg_path(&stroke(vec![]), 2).is_empty());
    }

    #[test]
    fn pressure_variation_changes_outline_width() {
        // 固定寬度折線做不到這件事，這正是用 outline 的理由。
        let varying = stroke_to_svg_path(
            &stroke(vec![
                InkPoint::new(0.0, 0.0, 0.0, 0),
                InkPoint::new(50.0, 0.0, 1.0, 8_000),
            ]),
            0,
        );
        let uniform = stroke_to_svg_path(
            &stroke(vec![
                InkPoint::new(0.0, 0.0, 1.0, 0),
                InkPoint::new(50.0, 0.0, 1.0, 8_000),
            ]),
            0,
        );
        assert_ne!(varying, uniform, "壓感變化必須反映在外框上");
    }
}
