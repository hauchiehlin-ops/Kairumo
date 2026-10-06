//! 圖學的二維製圖工具（`padnote-drafting`）給平台用的介面：尺寸標註、符號、圖框與標題欄。
//!
//! 輸出一律是**製圖筆畫**（`FfiSheetStroke`：角色已經換成圖層、線型、筆寬與顏色）加上要放文字方塊的
//! 標籤（`FfiExampleText`，語系鍵）。平台用現有的「插入圖紙」流程落地 —— 放在視野中央、自動套索選住、
//! 一次復原。幾何與數字都在核心算，兩個平台畫出來完全相同。

use padnote_drafting::dim::{self, DimStyle, LinearAxis};
use padnote_drafting::frame::{self, FrameOptions};
use padnote_drafting::symbols::{self, SymbolParams};
use padnote_drafting::{Drawing, UNITS_PER_MM};

use crate::ffi_draft::draft_pens;
use crate::ffi_draft_example::FfiExampleText;
use crate::ffi_shapes::FfiPoint;
use crate::ffi_solid::{FfiSheetStroke, pen_for};

/// 製圖成品：折線（已換成製圖筆）＋文字標籤。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiDraftKit {
    pub strokes: Vec<FfiSheetStroke>,
    pub texts: Vec<FfiExampleText>,
}

/// 一個標註：筆畫、標在圖上的文字、實物的數值（長度是毫米、角度是度）。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiDimension {
    pub strokes: Vec<FfiSheetStroke>,
    pub text: String,
    pub value: f32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum FfiDimAxis {
    /// 依尺寸線擺的位置決定水平或垂直。
    Auto,
    Horizontal,
    Vertical,
    /// 與兩點連線平行。
    Aligned,
}

/// 比例尺選項：`ratio` = 實物 / 圖上（1:2 → 2，2:1 → 0.5）。
#[derive(Clone, Debug, PartialEq, uniffi::Record)]
pub struct FfiDraftScale {
    pub label: String,
    pub ratio: f32,
}

/// 符號的參數。用到哪些欄位依符號而定；其餘忽略。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiSymbolParams {
    pub size_mm: f32,
    pub text: String,
    pub rotation_deg: f32,
    pub other_side: bool,
    pub all_around: bool,
    pub field: bool,
    pub diameter: bool,
    /// 幾何公差的基準字母，例如 `"AB"`。
    pub datums: String,
    pub length_mm: f32,
}

/// 符號清單的一項。
#[derive(Clone, Debug, PartialEq, uniffi::Record)]
pub struct FfiDraftSymbolInfo {
    pub id: String,
    /// 分組：surface／weld／thread／gdt／mark／fastener。
    pub group: String,
    /// 語系鍵 `draft_sym_<id>`。
    pub name_key: String,
}

fn kit_strokes(d: &Drawing) -> Vec<FfiSheetStroke> {
    let pens = draft_pens();
    d.strokes
        .iter()
        .filter_map(|s| {
            let pen = pens.iter().find(|p| p.id == pen_for(s.role))?;
            Some(FfiSheetStroke {
                points: s
                    .points
                    .iter()
                    .map(|p| FfiPoint { x: p.0, y: p.1 })
                    .collect(),
                layer: pen.layer,
                line_type: pen.line_type,
                width: pen.width,
                color_hex: pen.color_hex.clone(),
            })
        })
        .collect()
}

fn kit_from(d: &Drawing) -> FfiDraftKit {
    FfiDraftKit {
        strokes: kit_strokes(d),
        texts: d
            .labels
            .iter()
            .map(|l| FfiExampleText {
                key: l.key.clone(),
                x: l.x,
                y: l.y,
                width: l.width,
                font_size: l.size,
                bold: l.bold,
                color_hex: "#111827".into(),
            })
            .collect(),
    }
}

fn dimension_from(d: dim::Dimension) -> Option<FfiDimension> {
    if d.strokes.is_empty() {
        return None;
    }
    let strokes = kit_strokes(&Drawing {
        strokes: d.strokes,
        labels: Vec::new(),
    });
    Some(FfiDimension {
        strokes,
        text: d.text,
        value: d.value,
    })
}

fn p(a: FfiPoint) -> (f32, f32) {
    (a.x, a.y)
}

/// 頁面單位／毫米（A4 寬 210 mm = 800 單位；所有紙張規格同一個比例）。
#[uniffi::export]
pub fn draft_units_per_mm() -> f32 {
    UNITS_PER_MM
}

/// 常用的比例尺（工程製圖課常用：縮小、原尺寸、放大）。
#[uniffi::export]
pub fn draft_scales() -> Vec<FfiDraftScale> {
    [
        ("1:1", 1.0),
        ("1:2", 2.0),
        ("1:5", 5.0),
        ("1:10", 10.0),
        ("1:20", 20.0),
        ("1:50", 50.0),
        ("2:1", 0.5),
        ("5:1", 0.2),
        ("10:1", 0.1),
    ]
    .into_iter()
    .map(|(label, ratio)| FfiDraftScale {
        label: label.into(),
        ratio,
    })
    .collect()
}

/// 線性標註：`p1`、`p2` 是被標註的兩點，`through` 是尺寸線要經過的位置。兩點重合回 `None`。
#[uniffi::export]
pub fn draft_dim_linear(
    p1: FfiPoint,
    p2: FfiPoint,
    through: FfiPoint,
    axis: FfiDimAxis,
    ratio: f32,
) -> Option<FfiDimension> {
    let axis = match axis {
        FfiDimAxis::Auto => LinearAxis::Auto,
        FfiDimAxis::Horizontal => LinearAxis::Horizontal,
        FfiDimAxis::Vertical => LinearAxis::Vertical,
        FfiDimAxis::Aligned => LinearAxis::Aligned,
    };
    dimension_from(dim::linear(
        p(p1),
        p(p2),
        p(through),
        axis,
        ratio.max(1e-3),
        &DimStyle::iso(),
    ))
}

/// 直徑標註：圓心、半徑，引線從圓上 `dir` 方向那一點出去。
#[uniffi::export]
pub fn draft_dim_diameter(
    center: FfiPoint,
    radius: f32,
    dir: FfiPoint,
    ratio: f32,
) -> Option<FfiDimension> {
    dimension_from(dim::diameter(
        p(center),
        radius,
        p(dir),
        ratio.max(1e-3),
        &DimStyle::iso(),
    ))
}

/// 半徑標註。
#[uniffi::export]
pub fn draft_dim_radius(
    center: FfiPoint,
    radius: f32,
    dir: FfiPoint,
    ratio: f32,
) -> Option<FfiDimension> {
    dimension_from(dim::radius(
        p(center),
        radius,
        p(dir),
        ratio.max(1e-3),
        &DimStyle::iso(),
    ))
}

/// 角度標註：頂點、兩邊各朝 `a`、`b`，尺寸弧半徑 `arc_radius`。
#[uniffi::export]
pub fn draft_dim_angle(
    vertex: FfiPoint,
    a: FfiPoint,
    b: FfiPoint,
    arc_radius: f32,
) -> Option<FfiDimension> {
    dimension_from(dim::angle(
        p(vertex),
        p(a),
        p(b),
        arc_radius,
        &DimStyle::iso(),
    ))
}

/// 符號清單。
#[uniffi::export]
pub fn draft_symbol_catalog() -> Vec<FfiDraftSymbolInfo> {
    symbols::CATALOG
        .iter()
        .map(|(id, group)| FfiDraftSymbolInfo {
            id: (*id).into(),
            group: (*group).into(),
            name_key: format!("draft_sym_{id}"),
        })
        .collect()
}

/// 一個符號：定位點放在 `anchor`。認不得的識別字回 `None`。
#[uniffi::export]
pub fn draft_symbol(id: String, anchor: FfiPoint, params: FfiSymbolParams) -> Option<FfiDraftKit> {
    let params = SymbolParams {
        size_mm: params.size_mm,
        text: params.text,
        rotation_deg: params.rotation_deg,
        other_side: params.other_side,
        all_around: params.all_around,
        field: params.field,
        diameter: params.diameter,
        datums: params.datums.chars().collect(),
        length_mm: params.length_mm,
    };
    symbols::make(&id, p(anchor), &params).map(|d| kit_from(&d))
}

/// 圖框與標題欄。`paper_id` 是 `page_formats` 的識別字（a4、a3、a3_landscape、a2…）；
/// 認不得的紙張（含自訂尺寸）回 `None`。座標以紙的左上角為原點。
#[uniffi::export]
pub fn draft_sheet_frame(
    paper_id: String,
    scale_text: String,
    third_angle: bool,
    title_block: bool,
) -> Option<FfiDraftKit> {
    let (width_mm, height_mm) = frame::paper_mm(&paper_id)?;
    let d = frame::sheet(&FrameOptions {
        width_mm,
        height_mm,
        margin_mm: 10.0,
        binding_mm: 25.0,
        title_block,
        scale_text,
        third_angle,
    });
    (!d.strokes.is_empty()).then(|| kit_from(&d))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn pt(x: f32, y: f32) -> FfiPoint {
        FfiPoint { x, y }
    }

    fn params() -> FfiSymbolParams {
        FfiSymbolParams {
            size_mm: 3.5,
            text: "Ra 1.6".into(),
            rotation_deg: 0.0,
            other_side: false,
            all_around: false,
            field: false,
            diameter: false,
            datums: String::new(),
            length_mm: 20.0,
        }
    }

    #[test]
    fn a_dimension_comes_back_as_drafting_strokes_with_the_value() {
        let m = draft_units_per_mm();
        let d = draft_dim_linear(
            pt(10.0, 100.0),
            pt(10.0 + 40.0 * m, 100.0),
            pt(0.0, 130.0),
            FfiDimAxis::Auto,
            1.0,
        )
        .unwrap();
        assert_eq!(d.text, "40");
        assert!((d.value - 40.0).abs() < 1e-3);
        // 尺寸線與數字都用細線、在頂層。
        assert!(d.strokes.iter().all(|s| s.layer == 3 && s.line_type == 0));
        assert!(
            d.strokes
                .iter()
                .all(|s| s.points.len() >= 2 && s.width > 0.0)
        );
        // 兩點重合就沒有標註。
        assert!(
            draft_dim_linear(
                pt(5.0, 5.0),
                pt(5.0, 5.0),
                pt(5.0, 30.0),
                FfiDimAxis::Auto,
                1.0
            )
            .is_none()
        );
    }

    #[test]
    fn the_scale_ratio_changes_the_number_and_a_bad_ratio_is_clamped() {
        let m = draft_units_per_mm();
        let at = |ratio: f32| {
            draft_dim_linear(
                pt(0.0, 0.0),
                pt(25.0 * m, 0.0),
                pt(10.0, 20.0),
                FfiDimAxis::Horizontal,
                ratio,
            )
            .unwrap()
            .text
        };
        assert_eq!(at(1.0), "25");
        assert_eq!(at(2.0), "50");
        assert_eq!(at(0.5), "12.5");
        // 0 或負的比例尺不會算出 0 或 NaN。
        assert!(!at(0.0).is_empty() && !at(-3.0).is_empty());
    }

    #[test]
    fn diameter_radius_and_angle_dimensions_have_their_prefixes() {
        let m = draft_units_per_mm();
        let dia = draft_dim_diameter(pt(100.0, 100.0), 10.0 * m, pt(1.0, -1.0), 1.0).unwrap();
        assert_eq!(dia.text, "⌀20");
        let rad = draft_dim_radius(pt(100.0, 100.0), 10.0 * m, pt(-1.0, 0.0), 1.0).unwrap();
        assert_eq!(rad.text, "R10");
        let ang = draft_dim_angle(pt(0.0, 0.0), pt(100.0, 0.0), pt(0.0, 100.0), 50.0).unwrap();
        assert_eq!(ang.text, "90°");
        assert!(draft_dim_diameter(pt(0.0, 0.0), 0.0, pt(1.0, 0.0), 1.0).is_none());
    }

    #[test]
    fn every_catalogue_symbol_can_be_made_through_the_ffi() {
        let cat = draft_symbol_catalog();
        assert!(cat.len() >= 30);
        for info in &cat {
            let kit = draft_symbol(info.id.clone(), pt(200.0, 200.0), params())
                .unwrap_or_else(|| panic!("{}", info.id));
            assert!(!kit.strokes.is_empty(), "{}", info.id);
            assert_eq!(info.name_key, format!("draft_sym_{}", info.id));
        }
        assert!(draft_symbol("nope".into(), pt(0.0, 0.0), params()).is_none());
    }

    #[test]
    fn a_gdt_frame_through_the_ffi_carries_tolerance_and_datums() {
        let mut prm = params();
        prm.text = "0.05".into();
        prm.diameter = true;
        prm.datums = "AB".into();
        let with = draft_symbol("gdt_position".into(), pt(0.0, 0.0), prm.clone()).unwrap();
        prm.datums.clear();
        let without = draft_symbol("gdt_position".into(), pt(0.0, 0.0), prm).unwrap();
        assert!(with.strokes.len() > without.strokes.len());
    }

    #[test]
    fn the_sheet_frame_has_a_title_block_with_language_keys() {
        let kit = draft_sheet_frame("a3_landscape".into(), "1:2".into(), true, true).unwrap();
        assert!(!kit.strokes.is_empty());
        assert!(kit.texts.iter().any(|t| t.key == "draft_tb_title"));
        assert!(kit.texts.iter().all(|t| t.font_size > 0.0 && t.width > 0.0));
        // 框線用粗實線（頂層）、格線用細線。
        assert!(kit.strokes.iter().any(|s| s.width > 2.0));
        assert!(kit.strokes.iter().any(|s| s.width < 1.5));
        // 沒有標題欄就沒有標籤。
        let plain = draft_sheet_frame("a4".into(), String::new(), true, false).unwrap();
        assert!(plain.texts.is_empty());
        // 認不得的紙張（含自訂尺寸）沒有圖框。
        assert!(draft_sheet_frame("custom_900x700".into(), String::new(), true, true).is_none());
    }

    #[test]
    fn the_scale_presets_cover_reduction_full_size_and_enlargement() {
        let s = draft_scales();
        assert!(s.iter().any(|x| x.label == "1:1" && x.ratio == 1.0));
        assert!(s.iter().any(|x| x.ratio > 1.0));
        assert!(s.iter().any(|x| x.ratio < 1.0));
        assert!(s.iter().all(|x| x.ratio > 0.0));
    }
}
