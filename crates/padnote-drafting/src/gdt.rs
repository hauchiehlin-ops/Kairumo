//! 幾何公差框（ISO 1101）：特性符號 | 公差值 | 基準字母…
//!
//! 框高是字高的 2 倍；符號格是正方形，公差格依文字寬度，每個基準格也是正方形。
//! 定位點是框的**左邊中央** —— 引線從那裡（或框的任一邊）連到被標註的特徵。

use crate::symbols::{SymbolParams, arc, circle, text_at};
use crate::{Drawing, P2, Role};
use padnote_solid::glyph::text_strokes;

/// 特性符號放進一個方格（`c` 是格中心、`s` 是半尺寸）。回傳是否認得這個種類。
fn symbol(d: &mut Drawing, kind: &str, c: P2, s: f32) -> bool {
    let thin = Role::Dimension;
    let (cx, cy) = c;
    match kind {
        "straightness" => d.line(thin, (cx - s, cy), (cx + s, cy)),
        "flatness" => d.polyline(
            thin,
            vec![
                (cx - s, cy + s * 0.5),
                (cx - s * 0.4, cy - s * 0.5),
                (cx + s, cy - s * 0.5),
                (cx + s * 0.4, cy + s * 0.5),
                (cx - s, cy + s * 0.5),
            ],
        ),
        "circularity" => d.polyline(thin, circle(c, s * 0.8, 24)),
        "cylindricity" => {
            d.polyline(thin, circle(c, s * 0.62, 24));
            d.line(
                thin,
                (cx - s * 1.1, cy + s * 0.9),
                (cx - s * 0.3, cy - s * 0.9),
            );
            d.line(
                thin,
                (cx + s * 0.3, cy + s * 0.9),
                (cx + s * 1.1, cy - s * 0.9),
            );
        }
        "profile_line" => d.polyline(
            thin,
            arc(
                (cx, cy + s * 0.4),
                s,
                std::f32::consts::PI,
                std::f32::consts::TAU,
                20,
            ),
        ),
        "profile_surface" => {
            let mut a = arc(
                (cx, cy + s * 0.4),
                s,
                std::f32::consts::PI,
                std::f32::consts::TAU,
                20,
            );
            let first = a[0];
            a.push(first);
            d.polyline(thin, a);
        }
        "parallelism" => {
            d.line(thin, (cx - s * 0.6, cy + s), (cx + s * 0.2, cy - s));
            d.line(thin, (cx - s * 0.2, cy + s), (cx + s * 0.6, cy - s));
        }
        "perpendicularity" => {
            d.line(thin, (cx - s, cy + s), (cx + s, cy + s));
            d.line(thin, (cx, cy + s), (cx, cy - s));
        }
        "angularity" => {
            d.line(thin, (cx - s, cy + s), (cx + s, cy + s));
            d.line(thin, (cx - s, cy + s), (cx + s * 0.5, cy - s));
        }
        "position" => {
            d.polyline(thin, circle(c, s * 0.8, 24));
            d.line(thin, (cx - s * 1.1, cy), (cx + s * 1.1, cy));
            d.line(thin, (cx, cy - s * 1.1), (cx, cy + s * 1.1));
        }
        "concentricity" => {
            d.polyline(thin, circle(c, s * 0.45, 20));
            d.polyline(thin, circle(c, s * 0.9, 24));
        }
        "symmetry" => {
            d.line(
                thin,
                (cx - s * 0.6, cy - s * 0.55),
                (cx + s * 0.6, cy - s * 0.55),
            );
            d.line(thin, (cx - s, cy), (cx + s, cy));
            d.line(
                thin,
                (cx - s * 0.6, cy + s * 0.55),
                (cx + s * 0.6, cy + s * 0.55),
            );
        }
        "runout" | "total_runout" => {
            let arrow = |d: &mut Drawing, dx: f32| {
                let (a, b) = (
                    (cx - s * 0.8 + dx, cy + s * 0.8),
                    (cx + s * 0.8 + dx, cy - s * 0.8),
                );
                d.line(thin, a, b);
                d.polyline(thin, vec![(b.0 - s * 0.5, b.1), b, (b.0, b.1 + s * 0.5)]);
            };
            if kind == "runout" {
                arrow(d, 0.0);
            } else {
                arrow(d, -s * 0.35);
                arrow(d, s * 0.35);
            }
        }
        _ => return false,
    }
    true
}

/// 一個公差框。`kind` 是 `gdt_` 後面的那段識別字。認不得回 `None`。
pub fn frame(u: f32, p: &SymbolParams, kind: &str) -> Option<Drawing> {
    let mut d = Drawing::default();
    let h = u * 2.0;
    // 先確認符號認得，再畫框。
    let mut sym = Drawing::default();
    if !symbol(&mut sym, kind, (h / 2.0, 0.0), h * 0.3) {
        return None;
    }
    let tol = if p.diameter {
        format!("⌀{}", p.text)
    } else {
        p.text.clone()
    };
    let tol = if tol.is_empty() { "0".to_string() } else { tol };
    let tol_w = text_strokes(&tol, 0.0, 0.0, u).1 + u * 1.2;
    let datums: Vec<char> = p.datums.iter().copied().take(3).collect();

    let mut x = 0.0f32;
    let mut cells: Vec<f32> = vec![0.0, h];
    x += h;
    x += tol_w;
    cells.push(x);
    for _ in &datums {
        x += h;
        cells.push(x);
    }
    let (top, bottom) = (-h / 2.0, h / 2.0);
    d.polyline(
        Role::Dimension,
        vec![(0.0, top), (x, top), (x, bottom), (0.0, bottom), (0.0, top)],
    );
    for &cx in &cells[1..cells.len() - 1] {
        d.line(Role::Dimension, (cx, top), (cx, bottom));
    }
    d.strokes.extend(sym.strokes);
    // 公差值：垂直置中、水平置中。
    let tw = text_strokes(&tol, 0.0, 0.0, u).1;
    text_at(&mut d, &tol, h + (tol_w - tw) / 2.0, -u / 2.0, u);
    for (i, letter) in datums.iter().enumerate() {
        let cx = cells[2] + h * i as f32 + h / 2.0;
        let s = letter.to_string();
        let w = text_strokes(&s, 0.0, 0.0, u).1;
        text_at(&mut d, &s, cx - w / 2.0, -u / 2.0, u);
    }
    Some(d)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::UNITS_PER_MM;

    fn params(text: &str, diameter: bool, datums: &str) -> SymbolParams {
        SymbolParams {
            text: text.into(),
            diameter,
            datums: datums.chars().collect(),
            ..SymbolParams::default()
        }
    }

    const KINDS: [&str; 14] = [
        "straightness",
        "flatness",
        "circularity",
        "cylindricity",
        "profile_line",
        "profile_surface",
        "parallelism",
        "perpendicularity",
        "angularity",
        "position",
        "concentricity",
        "symmetry",
        "runout",
        "total_runout",
    ];

    #[test]
    fn every_characteristic_has_a_frame() {
        let u = 3.5 * UNITS_PER_MM;
        for k in KINDS {
            let d = frame(u, &params("0.05", false, ""), k).unwrap_or_else(|| panic!("{k}"));
            assert!(d.strokes.iter().any(|s| s.role == Role::Text), "{k}");
            assert!(d.strokes.len() > 4, "{k}");
        }
        assert!(frame(u, &params("0.05", false, ""), "nonsense").is_none());
    }

    #[test]
    fn the_frame_is_twice_the_text_height_and_grows_with_the_datums() {
        let u = 3.5 * UNITS_PER_MM;
        let width = |d: &Drawing| {
            let b = d.bounds().unwrap();
            b.1.0 - b.0.0
        };
        let none = frame(u, &params("0.05", false, ""), "position").unwrap();
        let two = frame(u, &params("0.05", false, "AB"), "position").unwrap();
        // 外框的上下緣正好是 ±u。
        let outer = &none.strokes[0].points;
        assert!((outer[0].1 + u).abs() < 1e-3 && (outer[2].1 - u).abs() < 1e-3);
        // 每多一個基準格，框寬多一個框高（2u）。
        assert!((width(&two) - width(&none) - 4.0 * u).abs() < 1.0);
        // 格線：符號格與公差格之間一條、公差格與每個基準格之間各一條。
        let verticals = |d: &Drawing| {
            d.strokes
                .iter()
                .filter(|s| {
                    s.role == Role::Dimension
                        && s.points.len() == 2
                        && s.points[0].0 == s.points[1].0
                        && (s.points[0].1 - s.points[1].1).abs() > 2.0 * u - 1e-2
                })
                .count()
        };
        assert_eq!(verticals(&none), 1);
        assert_eq!(verticals(&two), 3);
    }

    #[test]
    fn a_diameter_zone_prefixes_the_tolerance_with_the_diameter_sign() {
        let u = 3.5 * UNITS_PER_MM;
        let plain = frame(u, &params("0.1", false, ""), "position").unwrap();
        let with = frame(u, &params("0.1", true, ""), "position").unwrap();
        let text_strokes = |d: &Drawing| d.strokes.iter().filter(|s| s.role == Role::Text).count();
        // ⌀ 多一個圓和一條斜線。
        assert_eq!(text_strokes(&with), text_strokes(&plain) + 2);
    }

    #[test]
    fn at_most_three_datums_are_drawn() {
        let u = 3.5 * UNITS_PER_MM;
        let three = frame(u, &params("0.1", false, "ABC"), "position").unwrap();
        let five = frame(u, &params("0.1", false, "ABCDE"), "position").unwrap();
        assert_eq!(three.strokes.len(), five.strokes.len());
    }
}
