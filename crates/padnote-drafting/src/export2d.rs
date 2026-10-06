//! 2D 匯出：SVG 與 DXF。
//!
//! 輸入是頁面上的筆畫（圖層、線型、筆寬、顏色、點）；輸出是**以毫米為單位**的檔案，
//! 所以在 CAD 或向量軟體裡開起來的尺寸就是紙上量得的尺寸（A4 寬 210 mm）。
//!
//! - SVG：每個圖層一個 `<g>`，線型換成 `stroke-dasharray`。
//! - DXF：R12（AC1009）的 ASCII，POLYLINE／VERTEX —— 最舊也最通用，AutoCAD、LibreCAD、
//!   Fusion 360、SolidWorks 都讀得進。圖層與線型（HIDDEN、CENTER、PHANTOM）都定義好。
//!
//! 座標：頁面是 y 向下，CAD 是 y 向上，所以 DXF 的 y 以頁面高度翻轉；SVG 維持 y 向下。

use crate::edit::simplify;
use crate::{P2, UNITS_PER_MM};

/// 一筆要匯出的筆畫。
#[derive(Clone, Debug, PartialEq)]
pub struct ExportStroke {
    pub points: Vec<P2>,
    /// 製圖圖層（0 一般筆跡、1 底層、2 中層、3 頂層）。
    pub layer: u8,
    /// 線型（0 實線、1 隱藏線、2 中心線、3 假想線）。
    pub line_type: u8,
    /// 筆寬（頁面單位）。
    pub width: f32,
    pub color: (u8, u8, u8),
}

/// 線型的圖樣（頁面單位，亮、暗交替）。與 `padnote-ink` 的 `LineType::pattern` 同一份。
fn pattern(line_type: u8) -> &'static [f32] {
    padnote_ink::LineType::from_id(line_type).pattern()
}

fn mm(v: f32) -> f32 {
    v / UNITS_PER_MM
}

fn num(v: f32) -> String {
    let s = format!("{v:.4}");
    let s = s.trim_end_matches('0').trim_end_matches('.');
    if s == "-0" || s.is_empty() {
        "0".into()
    } else {
        s.into()
    }
}

/// 簡化之後的點：製圖線是每 4 單位一個取樣點的共線點，匯出成幾個頂點就夠；
/// 手繪線留 0.15 單位的精度。
fn reduced(points: &[P2], layer: u8) -> Vec<P2> {
    simplify(points, if layer == 0 { 0.15 } else { 0.3 })
}

fn layer_name(layer: u8) -> &'static str {
    match layer {
        1 => "GIVEN",
        2 => "AUX",
        3 => "ANSWER",
        _ => "HAND",
    }
}

fn linetype_name(line_type: u8) -> &'static str {
    match line_type {
        1 => "HIDDEN",
        2 => "CENTER",
        3 => "PHANTOM",
        _ => "CONTINUOUS",
    }
}

// MARK: - SVG

pub fn to_svg(strokes: &[ExportStroke], page_w: f32, page_h: f32) -> String {
    let (w, h) = (mm(page_w), mm(page_h));
    let mut s = String::new();
    s.push_str("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
    s.push_str(&format!(
        "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"{}mm\" height=\"{}mm\" viewBox=\"0 0 {} {}\">\n",
        num(w),
        num(h),
        num(w),
        num(h)
    ));
    for layer in 0u8..=3 {
        let group: Vec<&ExportStroke> = strokes
            .iter()
            .filter(|st| st.layer.min(3) == layer && st.points.len() >= 2)
            .collect();
        if group.is_empty() {
            continue;
        }
        s.push_str(&format!(
            "  <g id=\"layer-{}\" fill=\"none\" stroke-linecap=\"round\" stroke-linejoin=\"round\">\n",
            layer_name(layer).to_lowercase()
        ));
        for st in group {
            let pts = reduced(&st.points, st.layer)
                .iter()
                .map(|p| format!("{},{}", num(mm(p.0)), num(mm(p.1))))
                .collect::<Vec<_>>()
                .join(" ");
            let dash = pattern(st.line_type);
            let dash_attr = if dash.is_empty() {
                String::new()
            } else {
                format!(
                    " stroke-dasharray=\"{}\"",
                    dash.iter()
                        .map(|d| num(mm(*d)))
                        .collect::<Vec<_>>()
                        .join(" ")
                )
            };
            s.push_str(&format!(
                "    <polyline points=\"{pts}\" stroke=\"#{:02X}{:02X}{:02X}\" stroke-width=\"{}\"{dash_attr}/>\n",
                st.color.0,
                st.color.1,
                st.color.2,
                num(mm(st.width).max(0.05)),
            ));
        }
        s.push_str("  </g>\n");
    }
    s.push_str("</svg>\n");
    s
}

// MARK: - DXF

struct Dxf {
    out: String,
}

impl Dxf {
    fn pair(&mut self, code: i32, value: impl std::fmt::Display) {
        self.out.push_str(&format!("{code}\n{value}\n"));
    }
}

/// AutoCAD 色號：頂層黑／白（7）、中層藍（5）、底層灰（8）、一般筆跡 7。
fn aci(layer: u8) -> i32 {
    match layer {
        1 => 8,
        2 => 5,
        _ => 7,
    }
}

pub fn to_dxf(strokes: &[ExportStroke], page_w: f32, page_h: f32) -> String {
    let _ = page_w;
    let mut d = Dxf { out: String::new() };
    // 標頭。
    d.pair(0, "SECTION");
    d.pair(2, "HEADER");
    d.pair(9, "$ACADVER");
    d.pair(1, "AC1009");
    d.pair(9, "$MEASUREMENT");
    d.pair(70, 1);
    d.pair(0, "ENDSEC");
    // 表：線型與圖層。
    d.pair(0, "SECTION");
    d.pair(2, "TABLES");
    d.pair(0, "TABLE");
    d.pair(2, "LTYPE");
    d.pair(70, 4);
    for lt in 0u8..=3 {
        let pat = pattern(lt);
        d.pair(0, "LTYPE");
        d.pair(2, linetype_name(lt));
        d.pair(70, 0);
        d.pair(3, linetype_name(lt));
        d.pair(72, 65);
        d.pair(73, pat.len());
        let total: f32 = pat.iter().map(|v| mm(*v)).sum();
        d.pair(40, num(total));
        for (i, v) in pat.iter().enumerate() {
            // 正值是線、負值是空隙（偶數索引是線）。
            d.pair(49, num(if i % 2 == 0 { mm(*v) } else { -mm(*v) }));
        }
    }
    d.pair(0, "ENDTAB");
    d.pair(0, "TABLE");
    d.pair(2, "LAYER");
    d.pair(70, 4);
    for layer in [0u8, 1, 2, 3] {
        d.pair(0, "LAYER");
        d.pair(2, layer_name(layer));
        d.pair(70, 0);
        d.pair(62, aci(layer));
        d.pair(6, "CONTINUOUS");
    }
    d.pair(0, "ENDTAB");
    d.pair(0, "ENDSEC");
    // 圖元。
    d.pair(0, "SECTION");
    d.pair(2, "ENTITIES");
    for st in strokes.iter().filter(|st| st.points.len() >= 2) {
        let pts = reduced(&st.points, st.layer);
        if pts.len() < 2 {
            continue;
        }
        let name = layer_name(st.layer.min(3));
        let width = num(mm(st.width).max(0.05));
        d.pair(0, "POLYLINE");
        d.pair(8, name);
        d.pair(6, linetype_name(st.line_type));
        d.pair(62, aci(st.layer));
        d.pair(66, 1);
        d.pair(10, 0);
        d.pair(20, 0);
        d.pair(30, 0);
        d.pair(70, 0);
        d.pair(40, &width);
        d.pair(41, &width);
        for p in &pts {
            d.pair(0, "VERTEX");
            d.pair(8, name);
            d.pair(10, num(mm(p.0)));
            d.pair(20, num(mm(page_h - p.1)));
            d.pair(30, 0);
        }
        d.pair(0, "SEQEND");
        d.pair(8, name);
    }
    d.pair(0, "ENDSEC");
    d.pair(0, "EOF");
    d.out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn stroke(points: Vec<P2>, layer: u8, line_type: u8, width: f32) -> ExportStroke {
        ExportStroke {
            points,
            layer,
            line_type,
            width,
            color: (0x11, 0x18, 0x27),
        }
    }

    fn sample() -> Vec<ExportStroke> {
        vec![
            stroke(vec![(0.0, 0.0), (100.0 * UNITS_PER_MM, 0.0)], 3, 0, 2.6), // 100 mm 的粗實線
            stroke(
                vec![
                    (0.0, 10.0 * UNITS_PER_MM),
                    (100.0 * UNITS_PER_MM, 10.0 * UNITS_PER_MM),
                ],
                3,
                1,
                1.4,
            ), // 隱藏線
            stroke(vec![(10.0, 10.0), (10.0, 50.0)], 2, 0, 1.0),              // 中層輔助線
            stroke(vec![(5.0, 5.0)], 3, 0, 1.0),                              // 單點：略過
        ]
    }

    #[test]
    fn svg_is_in_millimetres_with_one_group_per_layer_and_dashes_for_hidden_lines() {
        let svg = to_svg(&sample(), 800.0, 1132.0);
        assert!(svg.contains("width=\"210mm\""), "{svg}");
        assert!(svg.contains("viewBox=\"0 0 "));
        assert_eq!(svg.matches("<polyline").count(), 3, "單點的筆畫不輸出");
        assert!(svg.contains("id=\"layer-answer\"") && svg.contains("id=\"layer-aux\""));
        assert!(!svg.contains("layer-hand"), "沒有一般筆跡就沒有那一組");
        // 100 mm 的線：x 從 0 到 100。
        assert!(svg.contains("points=\"0,0 100,0\""), "{svg}");
        // 隱藏線有 dasharray、實線沒有。
        let hidden = svg
            .lines()
            .find(|l| l.contains("stroke-dasharray"))
            .expect("隱藏線要有虛線圖樣");
        assert!(hidden.contains("points=\"0,10 100,10\""));
        assert_eq!(svg.matches("stroke-dasharray").count(), 1);
        assert!(svg.contains("stroke=\"#111827\""));
        assert!(svg.trim_end().ends_with("</svg>"));
    }

    #[test]
    fn svg_keeps_a_dense_straight_stroke_as_two_points() {
        let dense: Vec<P2> = (0..=100).map(|i| (i as f32 * 4.0, 20.0)).collect();
        let svg = to_svg(&[stroke(dense, 3, 0, 2.6)], 800.0, 600.0);
        let line = svg.lines().find(|l| l.contains("<polyline")).unwrap();
        assert_eq!(
            line.matches(',').count(),
            2,
            "共線的小段合成兩個頂點：{line}"
        );
    }

    #[test]
    fn dxf_is_well_formed_r12_with_layers_linetypes_and_flipped_millimetre_coordinates() {
        let dxf = to_dxf(&sample(), 800.0, 1132.0);
        let lines: Vec<&str> = dxf.lines().collect();
        assert_eq!(lines.len() % 2, 0, "群組碼與值要成對");
        assert_eq!(&lines[lines.len() - 2..], ["0", "EOF"]);
        assert!(dxf.contains("AC1009"));
        // 四個線型、四個圖層都定義了。
        for lt in ["CONTINUOUS", "HIDDEN", "CENTER", "PHANTOM"] {
            assert!(dxf.contains(&format!("2\n{lt}\n")), "缺線型 {lt}");
        }
        for layer in ["HAND", "GIVEN", "AUX", "ANSWER"] {
            assert!(
                dxf.contains(&format!("2\n{layer}\n70\n0\n")),
                "缺圖層 {layer}"
            );
        }
        // 三個有效筆畫 → 三個 POLYLINE、三個 SEQEND。
        assert_eq!(dxf.matches("0\nPOLYLINE\n").count(), 3);
        assert_eq!(dxf.matches("0\nSEQEND\n").count(), 3);
        assert_eq!(dxf.matches("0\nVERTEX\n").count(), 6);
        // 頁面 (0,0)（左上）→ CAD (0, 高度)：1132 單位 = 297.15 mm。
        let first_vertex = dxf.split("0\nVERTEX\n").nth(1).unwrap();
        assert!(
            first_vertex.contains("10\n0\n20\n297.15\n"),
            "{first_vertex}"
        );
        // 隱藏線的圖元用 HIDDEN 線型。
        assert!(dxf.contains("6\nHIDDEN\n62\n7\n"));
    }

    #[test]
    fn dxf_linetype_dashes_are_positive_for_the_line_and_negative_for_the_gap_in_millimetres() {
        let dxf = to_dxf(&[], 800.0, 600.0);
        let hidden = dxf.split("2\nHIDDEN\n").nth(1).unwrap();
        // 隱藏線圖樣 [12, 4] 頁面單位（每 mm 800/210 單位）→ 3.15 mm 線、−1.05 mm 空隙。
        assert!(hidden.contains("73\n2\n"));
        assert!(hidden.contains("49\n3.15\n49\n-1.05\n"), "{hidden}");
    }

    #[test]
    fn empty_input_still_produces_valid_files() {
        let svg = to_svg(&[], 800.0, 600.0);
        assert!(svg.contains("<svg") && !svg.contains("<polyline"));
        let dxf = to_dxf(&[], 800.0, 600.0);
        assert!(dxf.ends_with("0\nEOF\n"));
        assert_eq!(dxf.matches("0\nPOLYLINE\n").count(), 0);
    }
}
