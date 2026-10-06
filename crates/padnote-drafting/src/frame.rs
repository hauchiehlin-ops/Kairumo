//! 圖框與標題欄（CNS 3／ISO 5457、ISO 7200 的精神，欄位用中文課程常見的那幾個）。
//!
//! - 圖框是粗實線，離紙邊 10 mm（裝訂邊 25 mm 在左），四邊中點各有一個對中記號。
//! - 標題欄在圖框的**右下角**，寬 180 mm（紙不夠寬就縮到圖框寬度）、高 36 mm，三列：
//!   圖名／比例／單位；班級／學號／姓名／日期；課程／投影法符號／評分。
//! - 欄位的**名稱**是語系鍵的文字標籤（由平台翻成使用者語言）；欄位的**內容**留白給使用者手寫，
//!   只有比例、單位與投影法符號是筆畫（跟著比例尺與第三／第一角法設定）。

use crate::symbols::{arc, circle, text_at};
use crate::{Drawing, P2, Role, TextLabel, UNITS_PER_MM};

#[derive(Clone, Debug, PartialEq)]
pub struct FrameOptions {
    pub width_mm: f32,
    pub height_mm: f32,
    /// 圖框離紙邊（上、右、下）。
    pub margin_mm: f32,
    /// 左邊的裝訂邊。
    pub binding_mm: f32,
    pub title_block: bool,
    /// 比例欄預填的文字，例如 `1:1`。
    pub scale_text: String,
    /// 第三角法（台灣與美國）；否則第一角法。
    pub third_angle: bool,
}

impl FrameOptions {
    pub fn a3_landscape() -> FrameOptions {
        FrameOptions {
            width_mm: 420.0,
            height_mm: 297.0,
            margin_mm: 10.0,
            binding_mm: 25.0,
            title_block: true,
            scale_text: "1:1".into(),
            third_angle: true,
        }
    }
}

/// 紙張識別字 → (寬, 高) 毫米。與 `page_formats` 的識別字一致。
pub fn paper_mm(id: &str) -> Option<(f32, f32)> {
    Some(match id {
        "a4" => (210.0, 297.0),
        "a4_landscape" => (297.0, 210.0),
        "a3" => (297.0, 420.0),
        "a3_landscape" => (420.0, 297.0),
        "a2" => (420.0, 594.0),
        "a2_landscape" => (594.0, 420.0),
        _ => return None,
    })
}

/// 標題欄的欄位：(語系鍵, x0, x1) 相對於標題欄寬度的比例，三列。
const ROW1: [(&str, f32, f32); 3] = [
    ("draft_tb_title", 0.0, 100.0 / 180.0),
    ("draft_tb_scale", 100.0 / 180.0, 140.0 / 180.0),
    ("draft_tb_unit", 140.0 / 180.0, 1.0),
];
const ROW2: [(&str, f32, f32); 4] = [
    ("draft_tb_class", 0.0, 0.25),
    ("draft_tb_id", 0.25, 0.5),
    ("draft_tb_name", 0.5, 0.75),
    ("draft_tb_date", 0.75, 1.0),
];
const ROW3: [(&str, f32, f32); 3] = [
    ("draft_tb_course", 0.0, 80.0 / 180.0),
    ("draft_tb_projection", 80.0 / 180.0, 130.0 / 180.0),
    ("draft_tb_score", 130.0 / 180.0, 1.0),
];

fn rect(x0: f32, y0: f32, x1: f32, y1: f32) -> Vec<P2> {
    vec![(x0, y0), (x1, y0), (x1, y1), (x0, y1), (x0, y0)]
}

/// ISO 5456-2 的投影法符號：截頭圓錐的側視圖＋它的左視圖（兩個同心圓）。
/// 第一角法：圓錐在左、圓在右；第三角法：圓在左、圓錐在右。畫在 `(x, y)`（左上角）、高 `h` 的格子裡。
pub fn projection_symbol(d: &mut Drawing, x: f32, y: f32, h: f32, third_angle: bool) {
    let cy = y + h / 2.0;
    let big = h * 0.5;
    let small = h * 0.27;
    let cone_w = h * 1.25;
    let circles_cx_in_cone = |x0: f32| (x0 + big, cy);
    // 圓錐：大端在左。
    let cone = |d: &mut Drawing, x0: f32| {
        d.polyline(
            Role::Visible,
            vec![
                (x0, cy - big),
                (x0 + cone_w, cy - small),
                (x0 + cone_w, cy + small),
                (x0, cy + big),
                (x0, cy - big),
            ],
        );
        d.line(
            Role::Center,
            (x0 - h * 0.15, cy),
            (x0 + cone_w + h * 0.15, cy),
        );
    };
    let rings = |d: &mut Drawing, x0: f32| {
        let c = circles_cx_in_cone(x0);
        d.polyline(Role::Visible, circle(c, big, 32));
        d.polyline(Role::Visible, circle(c, small, 24));
        d.line(
            Role::Center,
            (c.0 - big - h * 0.12, c.1),
            (c.0 + big + h * 0.12, c.1),
        );
        d.line(
            Role::Center,
            (c.0, c.1 - big - h * 0.12),
            (c.0, c.1 + big + h * 0.12),
        );
    };
    let gap = h * 0.35;
    if third_angle {
        rings(d, x);
        cone(d, x + 2.0 * big + gap);
    } else {
        cone(d, x);
        rings(d, x + cone_w + gap);
    }
}

/// 投影法符號的總寬（`projection_symbol` 用同樣的算法）。
pub fn projection_symbol_width(h: f32) -> f32 {
    h * 1.25 + h * 0.35 + h
}

/// 一張圖框（含標題欄）。座標以紙的左上角為原點。
pub fn sheet(opts: &FrameOptions) -> Drawing {
    let mut d = Drawing::default();
    let m = UNITS_PER_MM;
    let (w, h) = (opts.width_mm * m, opts.height_mm * m);
    let (left, top) = (opts.binding_mm.max(opts.margin_mm) * m, opts.margin_mm * m);
    let (right, bottom) = (w - opts.margin_mm * m, h - opts.margin_mm * m);
    if right - left < 40.0 * m || bottom - top < 40.0 * m {
        return d;
    }
    d.polyline(Role::Visible, rect(left, top, right, bottom));

    // 四邊中點的對中記號：從紙邊進到圖框內 5 mm。
    let mid = ((left + right) / 2.0, (top + bottom) / 2.0);
    let tick = 5.0 * m;
    d.line(Role::Visible, (mid.0, top - 0.0), (mid.0, top + tick));
    d.line(Role::Visible, (mid.0, bottom - tick), (mid.0, bottom));
    d.line(Role::Visible, (left, mid.1), (left + tick, mid.1));
    d.line(Role::Visible, (right - tick, mid.1), (right, mid.1));

    if !opts.title_block {
        return d;
    }
    let tb_w = (180.0 * m).min(right - left);
    let row_h = 12.0 * m;
    let (x0, y0) = (right - tb_w, bottom - 3.0 * row_h);
    // 外框用粗線，內格用細線。
    d.polyline(Role::Visible, rect(x0, y0, right, bottom));
    for r in 1..3 {
        let y = y0 + r as f32 * row_h;
        d.line(Role::Dimension, (x0, y), (right, y));
    }
    let label_size = 2.6 * m;
    let value_h = 4.5 * m;
    let cell = |row: usize, key: &str, f0: f32, f1: f32, d: &mut Drawing| {
        let (cx0, cx1) = (x0 + f0 * tb_w, x0 + f1 * tb_w);
        let cy0 = y0 + row as f32 * row_h;
        if f0 > 0.0 {
            d.line(Role::Dimension, (cx0, cy0), (cx0, cy0 + row_h));
        }
        d.labels.push(TextLabel {
            key: key.into(),
            x: cx0 + 0.8 * m,
            y: cy0 + 0.6 * m,
            width: cx1 - cx0 - 1.6 * m,
            size: label_size,
            bold: false,
        });
        (cx0, cx1, cy0)
    };
    for (key, f0, f1) in ROW1 {
        let (cx0, _cx1, cy0) = cell(0, key, f0, f1, &mut d);
        match key {
            "draft_tb_scale" if !opts.scale_text.is_empty() => {
                text_at(
                    &mut d,
                    &opts.scale_text,
                    cx0 + 2.0 * m,
                    cy0 + row_h - value_h - 1.5 * m,
                    value_h,
                );
            }
            "draft_tb_unit" => {
                text_at(
                    &mut d,
                    "mm",
                    cx0 + 2.0 * m,
                    cy0 + row_h - value_h - 1.5 * m,
                    value_h,
                );
            }
            _ => {}
        }
    }
    for (key, f0, f1) in ROW2 {
        cell(1, key, f0, f1, &mut d);
    }
    for (key, f0, f1) in ROW3 {
        let (cx0, cx1, cy0) = cell(2, key, f0, f1, &mut d);
        if key == "draft_tb_projection" {
            let sh = 7.5 * m;
            let sw = projection_symbol_width(sh);
            let sx = cx0 + ((cx1 - cx0) - sw) / 2.0;
            projection_symbol(&mut d, sx, cy0 + row_h - sh - 1.2 * m, sh, opts.third_angle);
        }
    }
    let _ = arc;
    d
}

#[cfg(test)]
mod tests {
    use super::*;

    fn bounds(d: &Drawing) -> (P2, P2) {
        d.bounds().unwrap()
    }

    #[test]
    fn the_frame_is_inset_from_the_paper_with_a_wider_binding_margin() {
        let o = FrameOptions::a3_landscape();
        let d = sheet(&o);
        let m = UNITS_PER_MM;
        let frame = &d.strokes[0].points;
        assert_eq!(frame.first(), frame.last());
        let (lo, hi) = bounds(&d);
        // 左邊 25 mm、其餘 10 mm。
        assert!(
            (lo.0 / m - 25.0).abs() < 1e-2 && (lo.1 / m - 10.0).abs() < 1e-2,
            "{lo:?}"
        );
        assert!(
            (hi.0 / m - (420.0 - 10.0)).abs() < 1e-2 && (hi.1 / m - (297.0 - 10.0)).abs() < 1e-2,
            "{hi:?}"
        );
    }

    #[test]
    fn the_title_block_sits_in_the_bottom_right_corner_and_is_180_by_36_mm() {
        let o = FrameOptions::a3_landscape();
        let d = sheet(&o);
        let m = UNITS_PER_MM;
        // 標題欄外框是第二條粗線。
        let tb = d
            .strokes
            .iter()
            .filter(|s| s.role == Role::Visible && s.points.len() == 5)
            .nth(1)
            .expect("標題欄外框");
        let xs: Vec<f32> = tb.points.iter().map(|p| p.0).collect();
        let ys: Vec<f32> = tb.points.iter().map(|p| p.1).collect();
        let (x0, x1) = (
            xs.iter().cloned().fold(f32::MAX, f32::min),
            xs.iter().cloned().fold(f32::MIN, f32::max),
        );
        let (y0, y1) = (
            ys.iter().cloned().fold(f32::MAX, f32::min),
            ys.iter().cloned().fold(f32::MIN, f32::max),
        );
        assert!(((x1 - x0) / m - 180.0).abs() < 1e-2);
        assert!(((y1 - y0) / m - 36.0).abs() < 1e-2);
        assert!(
            (x1 / m - 410.0).abs() < 1e-2 && (y1 / m - 287.0).abs() < 1e-2,
            "貼著圖框右下角"
        );
    }

    #[test]
    fn every_field_has_a_label_with_a_language_key() {
        let d = sheet(&FrameOptions::a3_landscape());
        let keys: Vec<&str> = d.labels.iter().map(|l| l.key.as_str()).collect();
        for k in [
            "draft_tb_title",
            "draft_tb_scale",
            "draft_tb_unit",
            "draft_tb_class",
            "draft_tb_id",
            "draft_tb_name",
            "draft_tb_date",
            "draft_tb_course",
            "draft_tb_projection",
            "draft_tb_score",
        ] {
            assert!(keys.contains(&k), "{k}");
        }
        // 標籤都落在標題欄裡。
        let m = UNITS_PER_MM;
        for l in &d.labels {
            assert!(l.x / m > 230.0 && l.y / m > 250.0, "{l:?}");
            assert!(l.width > 0.0 && l.size > 0.0);
        }
    }

    #[test]
    fn the_scale_cell_is_prefilled_and_the_projection_symbol_follows_the_convention() {
        let mut o = FrameOptions::a3_landscape();
        o.scale_text = "1:2".into();
        let text = |d: &Drawing| d.strokes.iter().filter(|s| s.role == Role::Text).count();
        // "1:2" 是 1、冒號兩點、2；"mm" 是 m 與 m。
        let with = sheet(&o);
        o.scale_text.clear();
        let without = sheet(&o);
        assert!(text(&with) > text(&without));
        // 第三角法與第一角法：符號鏡像，筆畫數相同但圓錐的位置左右互換。
        let third = sheet(&FrameOptions {
            third_angle: true,
            ..FrameOptions::a3_landscape()
        });
        let first = sheet(&FrameOptions {
            third_angle: false,
            ..FrameOptions::a3_landscape()
        });
        assert_eq!(third.strokes.len(), first.strokes.len());
        let cone_x = |d: &Drawing| {
            // 圓錐是唯一 5 個點、4 邊都不是水平垂直的……用它的第一個點取代：找大端左邊緣最小 x。
            d.strokes
                .iter()
                .filter(|s| s.role == Role::Visible && s.points.len() == 5)
                .skip(2)
                .map(|s| s.points.iter().map(|p| p.0).fold(f32::MAX, f32::min))
                .next()
                .unwrap()
        };
        let ring_x = |d: &Drawing| {
            d.strokes
                .iter()
                .filter(|s| s.role == Role::Visible && s.points.len() > 20)
                .map(|s| s.points.iter().map(|p| p.0).fold(f32::MAX, f32::min))
                .fold(f32::MAX, f32::min)
        };
        assert!(
            cone_x(&first) < ring_x(&first),
            "第一角法：圓錐在左、圓在右"
        );
        assert!(
            ring_x(&third) < cone_x(&third),
            "第三角法：圓在左、圓錐在右"
        );
    }

    #[test]
    fn a_frame_without_a_title_block_has_only_the_border_and_centre_marks() {
        let o = FrameOptions {
            title_block: false,
            ..FrameOptions::a3_landscape()
        };
        let d = sheet(&o);
        assert_eq!(d.strokes.len(), 1 + 4);
        assert!(d.labels.is_empty());
    }

    #[test]
    fn a_sheet_too_small_to_hold_a_frame_makes_nothing() {
        let o = FrameOptions {
            width_mm: 50.0,
            height_mm: 50.0,
            ..FrameOptions::a3_landscape()
        };
        assert!(sheet(&o).strokes.is_empty());
    }

    #[test]
    fn a4_portrait_shrinks_the_title_block_to_the_frame_width() {
        let o = FrameOptions {
            width_mm: 210.0,
            height_mm: 297.0,
            ..FrameOptions::a3_landscape()
        };
        let d = sheet(&o);
        let (lo, hi) = bounds(&d);
        let m = UNITS_PER_MM;
        // 圖框寬 210 − 25 − 10 = 175 < 180：標題欄不會超出圖框。
        assert!(lo.0 / m >= 25.0 - 1e-2 && hi.0 / m <= 200.0 + 1e-2);
        assert!(paper_mm("a3_landscape") == Some((420.0, 297.0)));
        assert!(paper_mm("letter").is_none());
    }
}
