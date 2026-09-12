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

    // 壓感取樣點數與插值後的路徑點數不同，用比例對應回原始取樣。
    let pressure_at = |i: usize| -> f32 {
        let ratio = i as f32 / (path.len().max(2) - 1) as f32;
        let idx = ((ratio * (stroke.points.len() - 1) as f32).round() as usize)
            .min(stroke.points.len() - 1);
        stroke.points[idx].pressure
    };

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
        let hw = half_width(stroke.tool, stroke.base_width, pressure_at(i));
        let (x, y) = path[i];
        left.push((x + nx * hw, y + ny * hw));
        right.push((x - nx * hw, y - ny * hw));
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
        }
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
