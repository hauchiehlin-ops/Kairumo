//! 圖學立體輔助（草圖拉伸、三視圖、等角、剖面）的 FFI。
//!
//! 幾何全在 `padnote-solid`；這裡只做三件事：換型別、把線的**角色**換成製圖筆組裡的
//! 圖層／線型／筆寬（對照表在 `ffi_draft.rs`，兩個平台共用），以及擋掉不合理的輸入。

use padnote_solid::section::Cut;
use padnote_solid::sheet::{Convention, Role, SheetOptions, compose};
use padnote_solid::solid::{PRESETS, Profile, Solid, preset, profile_from_strokes};
use padnote_solid::view::{Camera, project};

use crate::ffi_draft::draft_pens;
use crate::ffi_shapes::FfiPoint;

/// 輪廓：外環加洞。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiSolidProfile {
    pub outer: Vec<FfiPoint>,
    pub holes: Vec<Vec<FfiPoint>>,
    /// 輪廓包圍盒的寬與高（拉伸之前，頁面單位）。
    pub width: f32,
    pub height: f32,
}

fn to_ffi(profile: &Profile) -> FfiSolidProfile {
    let conv = |r: &Vec<(f32, f32)>| r.iter().map(|p| FfiPoint { x: p.0, y: p.1 }).collect();
    let (w, h) = profile.size();
    FfiSolidProfile {
        outer: conv(&profile.outer),
        holes: profile.holes.iter().map(conv).collect(),
        width: w,
        height: h,
    }
}

fn from_ffi(p: &FfiSolidProfile) -> Option<Profile> {
    let conv = |r: &Vec<FfiPoint>| r.iter().map(|q| (q.x, q.y)).collect::<Vec<_>>();
    Profile::new(conv(&p.outer), p.holes.iter().map(conv).collect())
}

/// 預設輪廓的識別字，依 UI 顯示順序。名稱的語系鍵是 `solid_preset_<id>`。
#[uniffi::export]
pub fn solid_presets() -> Vec<String> {
    PRESETS.iter().map(|s| s.to_string()).collect()
}

/// 預設輪廓。`w`、`h` 是包圍盒尺寸（頁面單位）。
#[uniffi::export]
pub fn solid_preset_profile(name: String, w: f32, h: f32) -> Option<FfiSolidProfile> {
    preset(&name, w, h).map(|p| to_ffi(&p))
}

/// 草圖拉伸的第一步：從頁面上的手繪線找出輪廓。
///
/// 最大的封閉線是外環，落在它裡面的封閉線是洞；沒闔起來的線與其他線忽略。
/// 找不到任何封閉線回 `None`。
#[uniffi::export]
pub fn solid_profile_from_strokes(strokes: Vec<Vec<FfiPoint>>) -> Option<FfiSolidProfile> {
    let strokes: Vec<Vec<(f32, f32)>> = strokes
        .iter()
        .map(|s| s.iter().map(|p| (p.x, p.y)).collect())
        .collect();
    profile_from_strokes(&strokes).map(|p| to_ffi(&p))
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum FfiSectionKind {
    /// 不剖。
    None,
    /// 單一平面全剖面（垂直於輪廓）。
    Full,
    /// 階梯剖面。
    Stepped,
    /// 旋轉剖面。
    Rotated,
    /// 平行於輪廓的剖面（取代正視圖）。
    Parallel,
}

/// 剖面參數。用到哪些欄位依 `kind`；其餘忽略。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiSolidSection {
    pub kind: FfiSectionKind,
    /// 切線在 XY 平面上的方向（度）。
    pub angle_deg: f32,
    /// 切線位置（0…1，0.5 在正中）。階梯剖面是第一段。
    pub offset: f32,
    /// 階梯剖面第二段的位置（0…1）。
    pub offset2: f32,
    /// 階梯剖面轉折的位置（沿切線方向，0…1）。
    pub step: f32,
    /// 旋轉剖面的轉軸（包圍盒內的比例）。
    pub pivot_x: f32,
    pub pivot_y: f32,
    /// 旋轉剖面第二段相對第一段轉的角度（度）。
    pub delta_deg: f32,
    /// 反轉觀看方向。
    pub flip: bool,
    /// 平行剖面的深度位置（0 在前面、1 在後面）。
    pub depth_frac: f32,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiSolidSheetOptions {
    /// 第一角法（預設第三角）。
    pub first_angle: bool,
    pub include_iso: bool,
    pub projection_lines: bool,
    pub center_lines: bool,
    pub section: FfiSolidSection,
    /// 排進這個範圍（頁面單位）。
    pub fit_width: f32,
    pub fit_height: f32,
    /// 剖面線間距（頁面單位）。
    pub hatch_spacing: f32,
    /// 標註總長、總高、總深。
    pub dimensions: bool,
    /// 剖面位置線兩端與剖視圖標上「A」「A-A」。
    pub section_label: bool,
}

/// 圖紙上的一條線，已換成製圖筆組的設定。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiSheetStroke {
    pub points: Vec<FfiPoint>,
    /// 製圖圖層（1 底／2 中／3 頂）。
    pub layer: u8,
    /// 工程線型。
    pub line_type: u8,
    pub width: f32,
    pub color_hex: String,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiSolidSheet {
    pub strokes: Vec<FfiSheetStroke>,
    /// 一個模型單位對應幾個頁面單位。
    pub scale: f32,
    pub width: f32,
    pub height: f32,
}

fn cut_from(solid: &Solid, s: &FfiSolidSection) -> Option<Cut> {
    match s.kind {
        FfiSectionKind::None => None,
        FfiSectionKind::Full => Some(Cut::full(solid, s.angle_deg, s.offset, s.flip)),
        FfiSectionKind::Stepped => Some(Cut::stepped(
            solid,
            s.angle_deg,
            s.offset,
            s.offset2,
            s.step,
            s.flip,
        )),
        FfiSectionKind::Rotated => Some(Cut::rotated(
            solid,
            s.angle_deg,
            (s.pivot_x, s.pivot_y),
            s.delta_deg,
            s.flip,
        )),
        FfiSectionKind::Parallel => Some(Cut::parallel(solid, s.depth_frac)),
    }
}

/// 角色 → 製圖筆。
fn pen_for(role: Role) -> &'static str {
    match role {
        Role::Visible | Role::CutEnd => "thick",
        Role::Hidden => "hidden",
        Role::Center | Role::CutLine => "center",
        Role::Projection => "aux",
        Role::Hatch | Role::Dimension | Role::Text => "thin",
    }
}

/// 把一張圖紙排好。輪廓太小、深度不合理時回 `None`。
#[uniffi::export]
pub fn solid_compose_sheet(
    profile: FfiSolidProfile,
    depth: f32,
    options: FfiSolidSheetOptions,
) -> Option<FfiSolidSheet> {
    let profile = from_ffi(&profile)?;
    if !depth.is_finite() || depth < 1.0 || options.fit_width < 20.0 || options.fit_height < 20.0 {
        return None;
    }
    let solid = Solid::new(profile, depth);
    let opts = SheetOptions {
        convention: if options.first_angle {
            Convention::FirstAngle
        } else {
            Convention::ThirdAngle
        },
        include_iso: options.include_iso,
        projection_lines: options.projection_lines,
        center_lines: options.center_lines,
        section: cut_from(&solid, &options.section),
        fit: (options.fit_width, options.fit_height),
        hatch_spacing: options.hatch_spacing.max(1.0),
        dimensions: options.dimensions,
        section_label: options.section_label.then_some('A'),
    };
    let sheet = compose(&solid, &opts);
    let pens = draft_pens();
    let strokes = sheet
        .strokes
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
        .collect();
    Some(FfiSolidSheet {
        strokes,
        scale: sheet.scale,
        width: sheet.width,
        height: sheet.height,
    })
}

// MARK: - 步驟編號（①②③ …）

/// 數字的筆畫骨架，畫在 0…1 的方格裡（y 向下）。手寫風：折線近似曲線。
fn digit_strokes(d: u8) -> Vec<Vec<(f32, f32)>> {
    match d {
        0 => vec![vec![
            (0.5, 0.08),
            (0.28, 0.2),
            (0.22, 0.5),
            (0.28, 0.8),
            (0.5, 0.92),
            (0.72, 0.8),
            (0.78, 0.5),
            (0.72, 0.2),
            (0.5, 0.08),
        ]],
        1 => vec![vec![(0.34, 0.26), (0.56, 0.1), (0.56, 0.92)]],
        2 => vec![vec![
            (0.24, 0.3),
            (0.3, 0.15),
            (0.5, 0.08),
            (0.7, 0.15),
            (0.76, 0.32),
            (0.64, 0.52),
            (0.24, 0.9),
            (0.8, 0.9),
        ]],
        3 => vec![vec![
            (0.24, 0.16),
            (0.5, 0.08),
            (0.72, 0.2),
            (0.68, 0.42),
            (0.44, 0.5),
            (0.7, 0.58),
            (0.76, 0.8),
            (0.5, 0.92),
            (0.22, 0.84),
        ]],
        4 => vec![vec![(0.64, 0.92), (0.64, 0.08), (0.2, 0.66), (0.84, 0.66)]],
        5 => vec![vec![
            (0.76, 0.1),
            (0.3, 0.1),
            (0.26, 0.47),
            (0.5, 0.4),
            (0.72, 0.5),
            (0.78, 0.72),
            (0.55, 0.92),
            (0.24, 0.85),
        ]],
        6 => vec![vec![
            (0.7, 0.1),
            (0.4, 0.3),
            (0.26, 0.6),
            (0.3, 0.85),
            (0.52, 0.93),
            (0.74, 0.8),
            (0.72, 0.58),
            (0.5, 0.5),
            (0.3, 0.62),
        ]],
        7 => vec![vec![(0.22, 0.1), (0.78, 0.1), (0.42, 0.92)]],
        8 => vec![vec![
            (0.5, 0.5),
            (0.28, 0.4),
            (0.3, 0.2),
            (0.5, 0.08),
            (0.7, 0.2),
            (0.72, 0.4),
            (0.5, 0.5),
            (0.24, 0.65),
            (0.26, 0.85),
            (0.5, 0.93),
            (0.74, 0.85),
            (0.76, 0.65),
            (0.5, 0.5),
        ]],
        _ => vec![vec![
            (0.3, 0.9),
            (0.6, 0.7),
            (0.74, 0.4),
            (0.7, 0.15),
            (0.48, 0.07),
            (0.26, 0.2),
            (0.28, 0.42),
            (0.5, 0.5),
            (0.7, 0.38),
        ]],
    }
}

/// 步驟編號標記：一個圓圈裡面一個數字（1–99），畫在**中層**輔助線的淺藍細線筆上。
///
/// 圓心 `(cx, cy)`、半徑 `radius`（頁面單位）。回傳的每一筆都是製圖筆畫，平台層一次插入、
/// 一次復原。
#[uniffi::export]
pub fn draft_step_marker(number: u32, cx: f32, cy: f32, radius: f32) -> Vec<FfiSheetStroke> {
    let number = number.clamp(1, 99);
    let radius = radius.clamp(4.0, 80.0);
    let pens = draft_pens();
    let Some(pen) = pens.iter().find(|p| p.id == "aux") else {
        return Vec::new();
    };
    let make = |points: Vec<(f32, f32)>| FfiSheetStroke {
        points: points
            .into_iter()
            .map(|p| FfiPoint { x: p.0, y: p.1 })
            .collect(),
        layer: pen.layer,
        line_type: pen.line_type,
        width: pen.width,
        color_hex: pen.color_hex.clone(),
    };
    let mut out = Vec::new();
    // 圓圈：24 點，闔起來。
    out.push(make(
        (0..=24)
            .map(|i| {
                let a = i as f32 / 24.0 * std::f32::consts::TAU;
                (cx + radius * a.cos(), cy + radius * a.sin())
            })
            .collect(),
    ));
    // 數字：一位數佔圓內 55%，兩位數各佔 36%、並排。
    let digits: Vec<u8> = if number >= 10 {
        vec![(number / 10) as u8, (number % 10) as u8]
    } else {
        vec![number as u8]
    };
    let box_h = radius * 1.15;
    let box_w = if digits.len() == 1 {
        radius * 0.95
    } else {
        radius * 0.7
    };
    let total_w = box_w * digits.len() as f32;
    for (i, d) in digits.iter().enumerate() {
        let x0 = cx - total_w / 2.0 + box_w * i as f32;
        let y0 = cy - box_h / 2.0;
        for stroke in digit_strokes(*d) {
            out.push(make(
                stroke
                    .into_iter()
                    .map(|(u, v)| (x0 + u * box_w, y0 + v * box_h))
                    .collect(),
            ));
        }
    }
    out
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiSolidLine {
    pub ax: f32,
    pub ay: f32,
    pub bx: f32,
    pub by: f32,
    pub hidden: bool,
}

/// 任意視角的單一視圖（旋轉對照用）。座標已縮放並平移到 `0…fit` 內，y 向下。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiSolidView {
    pub lines: Vec<FfiSolidLine>,
    pub width: f32,
    pub height: f32,
}

/// 從任意角度看立體。`yaw` 繞垂直軸、`pitch` 抬高（度）。
#[uniffi::export]
pub fn solid_view(
    profile: FfiSolidProfile,
    depth: f32,
    yaw_deg: f32,
    pitch_deg: f32,
    fit_width: f32,
    fit_height: f32,
) -> Option<FfiSolidView> {
    let profile = from_ffi(&profile)?;
    if !depth.is_finite() || depth < 1.0 {
        return None;
    }
    let solid = Solid::new(profile, depth);
    let view = project(&solid, &Camera::free(yaw_deg, pitch_deg));
    let (lo, hi) = view.bounds()?;
    let (tw, th) = ((hi.0 - lo.0).max(1.0), (hi.1 - lo.1).max(1.0));
    let scale = (fit_width.max(1.0) / tw).min(fit_height.max(1.0) / th);
    let map = |p: (f32, f32)| ((p.0 - lo.0) * scale, (hi.1 - p.1) * scale);
    Some(FfiSolidView {
        lines: view
            .lines
            .iter()
            .map(|l| {
                let (a, b) = (map(l.a), map(l.b));
                FfiSolidLine {
                    ax: a.0,
                    ay: a.1,
                    bx: b.0,
                    by: b.1,
                    hidden: l.hidden,
                }
            })
            .collect(),
        width: tw * scale,
        height: th * scale,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn options(kind: FfiSectionKind) -> FfiSolidSheetOptions {
        FfiSolidSheetOptions {
            first_angle: false,
            include_iso: true,
            projection_lines: true,
            center_lines: true,
            section: FfiSolidSection {
                kind,
                angle_deg: 90.0,
                offset: 0.5,
                offset2: 0.7,
                step: 0.5,
                pivot_x: 0.5,
                pivot_y: 0.5,
                delta_deg: 30.0,
                flip: true,
                depth_frac: 0.5,
            },
            fit_width: 600.0,
            fit_height: 500.0,
            hatch_spacing: 6.0,
            dimensions: false,
            section_label: false,
        }
    }

    #[test]
    fn every_preset_composes_a_sheet_with_drafting_pens() {
        for id in solid_presets() {
            let p = solid_preset_profile(id.clone(), 80.0, 60.0).unwrap_or_else(|| panic!("{id}"));
            let sheet = solid_compose_sheet(p, 40.0, options(FfiSectionKind::None)).unwrap();
            assert!(!sheet.strokes.is_empty(), "{id}");
            for s in &sheet.strokes {
                assert!((1..=3).contains(&s.layer), "{id}: 圖層 {}", s.layer);
                assert!(s.width > 0.0 && s.points.len() >= 2);
            }
        }
    }

    #[test]
    fn hidden_lines_use_the_dashed_pen_and_projection_lines_the_aux_layer() {
        let p = solid_preset_profile("ring".into(), 60.0, 60.0).unwrap();
        let sheet = solid_compose_sheet(p, 20.0, options(FfiSectionKind::None)).unwrap();
        assert!(
            sheet
                .strokes
                .iter()
                .any(|s| s.line_type == 1 && s.layer == 3),
            "隱藏線"
        );
        assert!(
            sheet
                .strokes
                .iter()
                .any(|s| s.line_type == 2 && s.layer == 3),
            "中心線"
        );
        assert!(sheet.strokes.iter().any(|s| s.layer == 2), "投射線在中層");
    }

    #[test]
    fn every_section_kind_adds_hatch_lines() {
        let p = solid_preset_profile("plate_holes".into(), 80.0, 60.0).unwrap();
        for kind in [
            FfiSectionKind::Full,
            FfiSectionKind::Stepped,
            FfiSectionKind::Rotated,
            FfiSectionKind::Parallel,
        ] {
            let plain =
                solid_compose_sheet(p.clone(), 20.0, options(FfiSectionKind::None)).unwrap();
            let cut = solid_compose_sheet(p.clone(), 20.0, options(kind)).unwrap();
            assert!(cut.strokes.len() > plain.strokes.len(), "{kind:?}");
        }
    }

    #[test]
    fn nonsense_input_is_refused_not_crashed() {
        let p = solid_preset_profile("rect".into(), 40.0, 40.0).unwrap();
        assert!(solid_compose_sheet(p.clone(), 0.0, options(FfiSectionKind::None)).is_none());
        assert!(solid_compose_sheet(p.clone(), f32::NAN, options(FfiSectionKind::None)).is_none());
        let empty = FfiSolidProfile {
            outer: vec![],
            holes: vec![],
            width: 0.0,
            height: 0.0,
        };
        assert!(solid_compose_sheet(empty, 10.0, options(FfiSectionKind::None)).is_none());
        assert!(solid_preset_profile("沒這種".into(), 10.0, 10.0).is_none());
    }

    #[test]
    fn a_sketch_extrudes_end_to_end() {
        // 手繪一個闔起來的矩形 → 輪廓 → 三視圖。
        let mut s = Vec::new();
        for i in 0..=20 {
            s.push(FfiPoint {
                x: i as f32 * 5.0,
                y: 0.0,
            });
        }
        for i in 1..=15 {
            s.push(FfiPoint {
                x: 100.0,
                y: i as f32 * 5.0,
            });
        }
        for i in 1..=20 {
            s.push(FfiPoint {
                x: 100.0 - i as f32 * 5.0,
                y: 75.0,
            });
        }
        for i in 1..15 {
            s.push(FfiPoint {
                x: 0.0,
                y: 75.0 - i as f32 * 5.0,
            });
        }
        let profile = solid_profile_from_strokes(vec![s]).expect("闔起來的線");
        assert!((profile.width - 100.0).abs() < 2.0 && (profile.height - 75.0).abs() < 2.0);
        let sheet = solid_compose_sheet(profile, 50.0, options(FfiSectionKind::None)).unwrap();
        assert!(!sheet.strokes.is_empty());
    }

    #[test]
    fn step_markers_are_a_circle_plus_digit_strokes_on_the_aux_layer() {
        let one = draft_step_marker(1, 100.0, 100.0, 14.0);
        let twelve = draft_step_marker(12, 100.0, 100.0, 14.0);
        assert_eq!(one.len(), 2, "圈 + 一筆");
        assert_eq!(twelve.len(), 3, "圈 + 兩個數字各一筆");
        for s in one.iter().chain(&twelve) {
            assert_eq!(s.layer, 2, "步驟編號在中層，跟輔助線一起隱藏");
            for p in &s.points {
                assert!(
                    (p.x - 100.0).abs() <= 14.5 && (p.y - 100.0).abs() <= 14.5,
                    "{p:?}"
                );
            }
        }
        // 超出範圍被夾住，不 panic。
        assert!(!draft_step_marker(0, 0.0, 0.0, 1.0).is_empty());
        assert!(!draft_step_marker(5000, 0.0, 0.0, 999.0).is_empty());
        // 九個一位數都有字形。
        for n in 1..=9 {
            assert!(draft_step_marker(n, 0.0, 0.0, 10.0).len() >= 2, "{n}");
        }
    }

    #[test]
    fn rotating_the_view_changes_the_lines() {
        let p = solid_preset_profile("l_shape".into(), 60.0, 50.0).unwrap();
        let front = solid_view(p.clone(), 20.0, 0.0, 0.0, 300.0, 300.0).unwrap();
        let iso = solid_view(p, 20.0, 45.0, 35.0, 300.0, 300.0).unwrap();
        assert_ne!(front.lines.len(), iso.lines.len());
        for l in iso.lines.iter().chain(front.lines.iter()) {
            for v in [l.ax, l.ay, l.bx, l.by] {
                assert!((-0.5..=300.5).contains(&v), "{v}");
            }
        }
    }
}
