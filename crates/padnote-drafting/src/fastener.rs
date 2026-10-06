//! 標準件的簡化畫法（ISO 4014 六角螺栓、ISO 4032 六角螺帽、ISO 7089 平墊圈），依 M 規格查表。
//!
//! `size_mm` 是螺紋的公稱直徑 d（M6 就是 6），取最接近的規格；螺栓另有長度。
//! 定位點是**側視圖的軸線與承面（頭部底面／螺帽底面／墊圈底面）的交點**；上視圖放在側視圖的右邊。

use crate::symbols::{SymbolParams, circle};
use crate::{Drawing, P2, Role, UNITS_PER_MM};

/// (d, 對邊寬 s, 螺栓頭高 k, 螺帽高 m, 墊圈外徑, 墊圈內徑, 墊圈厚)
const TABLE: [(f32, f32, f32, f32, f32, f32, f32); 10] = [
    (3.0, 5.5, 2.0, 2.4, 7.0, 3.2, 0.5),
    (4.0, 7.0, 2.8, 3.2, 9.0, 4.3, 0.8),
    (5.0, 8.0, 3.5, 4.7, 10.0, 5.3, 1.0),
    (6.0, 10.0, 4.0, 5.2, 12.0, 6.4, 1.6),
    (8.0, 13.0, 5.3, 6.8, 16.0, 8.4, 1.6),
    (10.0, 16.0, 6.4, 8.4, 20.0, 10.5, 2.0),
    (12.0, 18.0, 7.5, 10.8, 24.0, 13.0, 2.5),
    (16.0, 24.0, 10.0, 14.8, 30.0, 17.0, 3.0),
    (20.0, 30.0, 12.5, 18.0, 37.0, 21.0, 3.0),
    (24.0, 36.0, 15.0, 21.5, 44.0, 25.0, 4.0),
];

/// 取最接近的規格。
pub fn spec(d_mm: f32) -> (f32, f32, f32, f32, f32, f32, f32) {
    *TABLE
        .iter()
        .min_by(|a, b| {
            (a.0 - d_mm)
                .abs()
                .partial_cmp(&(b.0 - d_mm).abs())
                .unwrap_or(std::cmp::Ordering::Equal)
        })
        .unwrap_or(&TABLE[3])
}

fn hexagon(c: P2, circumradius: f32) -> Vec<P2> {
    (0..=6)
        .map(|i| {
            let a = i as f32 * std::f32::consts::FRAC_PI_3;
            (c.0 + circumradius * a.cos(), c.1 + circumradius * a.sin())
        })
        .collect()
}

fn rect(x0: f32, y0: f32, x1: f32, y1: f32) -> Vec<P2> {
    vec![(x0, y0), (x1, y0), (x1, y1), (x0, y1), (x0, y0)]
}

/// 六角螺栓：側視圖（頭在上、螺桿往下）＋上視圖。
pub fn bolt(p: &SymbolParams) -> Drawing {
    let (d, s, k, ..) = spec(p.size_mm);
    let m = UNITS_PER_MM;
    let (d, s, k) = (d * m, s * m, k * m);
    let e = s / 0.866_025_4; // 對角寬
    let len = p.length_mm.clamp(6.0, 200.0) * m;
    let thread = ((2.0 * d / m + 6.0) * m).min(len);
    let mut dr = Drawing::default();
    // 頭：向上長。三條垂直線把三個可見面分開（中間那面寬 e/2，兩邊各 e/4）。
    dr.polyline(Role::Visible, rect(-e / 2.0, -k, e / 2.0, 0.0));
    for x in [-e / 4.0, e / 4.0] {
        dr.line(Role::Dimension, (x, -k), (x, 0.0));
    }
    // 螺桿：往下 `len`。
    dr.line(Role::Visible, (-d / 2.0, 0.0), (-d / 2.0, len));
    dr.line(Role::Visible, (d / 2.0, 0.0), (d / 2.0, len));
    // 末端倒角。
    let c = d * 0.1;
    dr.polyline(
        Role::Visible,
        vec![
            (-d / 2.0, len - c),
            (-d / 2.0 + c, len),
            (d / 2.0 - c, len),
            (d / 2.0, len - c),
        ],
    );
    // 螺紋：小徑細線、牙長終止線（粗）。
    let minor = d * 0.82 / 2.0;
    let top = len - thread;
    dr.line(Role::Dimension, (-minor, top), (-minor, len - c));
    dr.line(Role::Dimension, (minor, top), (minor, len - c));
    dr.line(Role::Visible, (-d / 2.0, top), (d / 2.0, top));
    dr.line(Role::Center, (0.0, -k - d * 0.4), (0.0, len + d * 0.4));
    // 上視圖：六角形＋倒角圓＋螺桿圓，放在右邊。
    let c0 = (e + d * 1.2, -k / 2.0);
    dr.polyline(Role::Visible, hexagon(c0, e / 2.0));
    dr.polyline(Role::Dimension, circle(c0, s / 2.0, 36));
    dr.polyline(Role::Dimension, circle(c0, d / 2.0 * 0.82, 30));
    dr.line(Role::Center, (c0.0 - e * 0.7, c0.1), (c0.0 + e * 0.7, c0.1));
    dr.line(Role::Center, (c0.0, c0.1 - e * 0.7), (c0.0, c0.1 + e * 0.7));
    dr
}

/// 六角螺帽：側視圖（底面在定位點）＋上視圖。
pub fn nut(p: &SymbolParams) -> Drawing {
    let (d, s, _, hn, ..) = spec(p.size_mm);
    let m = UNITS_PER_MM;
    let (d, s, hn) = (d * m, s * m, hn * m);
    let e = s / 0.866_025_4;
    let mut dr = Drawing::default();
    dr.polyline(Role::Visible, rect(-e / 2.0, -hn, e / 2.0, 0.0));
    for x in [-e / 4.0, e / 4.0] {
        dr.line(Role::Dimension, (x, -hn), (x, 0.0));
    }
    // 內螺紋在側視圖是隱藏線。
    dr.line(Role::Hidden, (-d / 2.0, -hn), (-d / 2.0, 0.0));
    dr.line(Role::Hidden, (d / 2.0, -hn), (d / 2.0, 0.0));
    dr.line(Role::Center, (0.0, -hn - d * 0.4), (0.0, d * 0.4));
    let c0 = (e / 2.0 + d * 1.2 + e / 2.0, -hn / 2.0);
    dr.polyline(Role::Visible, hexagon(c0, e / 2.0));
    dr.polyline(Role::Dimension, circle(c0, s / 2.0, 36));
    // 內螺紋端視圖：小徑粗圓、大徑 3/4 細弧。
    dr.polyline(Role::Visible, circle(c0, d / 2.0 * 0.82, 30));
    dr.polyline(
        Role::Dimension,
        crate::symbols::arc(c0, d / 2.0, 0.0, 3.0 * std::f32::consts::FRAC_PI_2, 30),
    );
    dr.line(Role::Center, (c0.0 - e * 0.7, c0.1), (c0.0 + e * 0.7, c0.1));
    dr.line(Role::Center, (c0.0, c0.1 - e * 0.7), (c0.0, c0.1 + e * 0.7));
    dr
}

/// 平墊圈：側視圖（孔是隱藏線）＋上視圖。
pub fn washer(p: &SymbolParams) -> Drawing {
    let (_, _, _, _, od, id, th) = spec(p.size_mm);
    let m = UNITS_PER_MM;
    let (od, id, th) = (od * m, id * m, th * m);
    let mut dr = Drawing::default();
    dr.polyline(Role::Visible, rect(-od / 2.0, -th, od / 2.0, 0.0));
    dr.line(Role::Hidden, (-id / 2.0, -th), (-id / 2.0, 0.0));
    dr.line(Role::Hidden, (id / 2.0, -th), (id / 2.0, 0.0));
    dr.line(Role::Center, (0.0, -th - id * 0.4), (0.0, id * 0.4));
    let c0 = (od / 2.0 + od * 0.6 + od / 2.0, -th / 2.0);
    dr.polyline(Role::Visible, circle(c0, od / 2.0, 40));
    dr.polyline(Role::Visible, circle(c0, id / 2.0, 30));
    dr.line(
        Role::Center,
        (c0.0 - od * 0.7, c0.1),
        (c0.0 + od * 0.7, c0.1),
    );
    dr.line(
        Role::Center,
        (c0.0, c0.1 - od * 0.7),
        (c0.0, c0.1 + od * 0.7),
    );
    dr
}

#[cfg(test)]
mod tests {
    use super::*;

    fn params(d: f32, len: f32) -> SymbolParams {
        SymbolParams {
            size_mm: d,
            length_mm: len,
            ..SymbolParams::default()
        }
    }

    #[test]
    fn the_nearest_standard_size_is_used() {
        assert_eq!(spec(6.0).0, 6.0);
        assert_eq!(spec(6.9).0, 6.0);
        assert_eq!(spec(7.2).0, 8.0);
        assert_eq!(spec(100.0).0, 24.0);
        assert_eq!(spec(0.5).0, 3.0);
    }

    #[test]
    fn an_m8_bolt_has_the_iso_head_and_the_requested_length() {
        let dr = bolt(&params(8.0, 30.0));
        let m = UNITS_PER_MM;
        // 頭高 5.3 mm、對邊 13 mm。
        let head = &dr.strokes[0].points;
        let h = (head[0].1 - head[2].1).abs() / m;
        assert!((h - 5.3).abs() < 1e-2, "{h}");
        // 螺桿底部在 y = 30 mm，兩條粗線從承面一路到底。
        let max_y = dr
            .strokes
            .iter()
            .filter(|s| s.role == Role::Visible)
            .flat_map(|s| s.points.iter())
            .map(|p| p.1)
            .fold(f32::MIN, f32::max);
        assert!((max_y / m - 30.0).abs() < 1e-2, "{}", max_y / m);
        // 上視圖的六角形：七個點（閉合），外接圓半徑 = e/2 = 13/√3 mm。
        let hex = dr.strokes.iter().find(|s| s.points.len() == 7).unwrap();
        let c = (
            (hex.points[0].0 + hex.points[3].0) / 2.0,
            (hex.points[0].1 + hex.points[3].1) / 2.0,
        );
        let r = ((hex.points[0].0 - c.0).powi(2) + (hex.points[0].1 - c.1).powi(2)).sqrt() / m;
        assert!((r - 13.0 / 3.0f32.sqrt()).abs() < 0.05, "{r}");
    }

    #[test]
    fn a_short_bolt_is_threaded_all_the_way() {
        // 螺紋長度 2d+6 = 22 mm 超過桿長 10 mm：牙長終止線就是承面（y = 0）。
        let dr = bolt(&params(8.0, 10.0));
        let end_line = dr.strokes.iter().find(|s| {
            s.role == Role::Visible
                && s.points.len() == 2
                && s.points[0].1 == s.points[1].1
                && s.points[0].0 < s.points[1].0
                && s.points[0].1.abs() < 1e-3
        });
        assert!(end_line.is_some());
    }

    #[test]
    fn a_nut_and_a_washer_follow_their_tables() {
        let m = UNITS_PER_MM;
        let n = nut(&params(10.0, 0.0));
        let h = (n.strokes[0].points[0].1 - n.strokes[0].points[2].1).abs() / m;
        assert!((h - 8.4).abs() < 1e-2, "{h}");
        // 螺帽的內螺紋在側視圖是隱藏線。
        assert!(n.strokes.iter().any(|s| s.role == Role::Hidden));
        let w = washer(&params(6.0, 0.0));
        let width = (w.strokes[0].points[0].0 - w.strokes[0].points[1].0).abs() / m;
        let thick = (w.strokes[0].points[0].1 - w.strokes[0].points[2].1).abs() / m;
        assert!((width - 12.0).abs() < 1e-2 && (thick - 1.6).abs() < 1e-2);
    }

    #[test]
    fn nothing_here_is_nan() {
        for d in [3.0, 6.0, 24.0] {
            for dr in [
                bolt(&params(d, 40.0)),
                nut(&params(d, 0.0)),
                washer(&params(d, 0.0)),
            ] {
                for s in &dr.strokes {
                    assert!(s.points.iter().all(|p| p.0.is_finite() && p.1.is_finite()));
                }
            }
        }
    }
}
