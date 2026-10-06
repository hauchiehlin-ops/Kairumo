//! 製圖符號：表面粗度（ISO 1302）、焊接（ISO 2553）、螺紋表示法（ISO 6410）、
//! 幾何公差框與基準（ISO 1101／5459）、中心記號、零件編號球、標準件（螺栓、螺母、墊圈）。
//!
//! 每個符號都有一個**定位點**（`anchor`）：符號「指著」的那一點，例如表面粗度的符號尖端、
//! 焊接符號的箭頭尖、零件編號的引線尖端。呼叫端把定位點放在要標註的位置即可；
//! `size_mm` 是符號的名義大小（紙上毫米，字高那一類的尺寸）。
//!
//! 輸出的線都帶角色：粗線（可見輪廓）、細線（尺寸線一類）、中心線、文字筆畫 ——
//! 由呼叫端換成實際的製圖筆。

use crate::{Drawing, P2, Role, TextLabel, UNITS_PER_MM};
use padnote_solid::glyph::text_strokes;

/// 符號的參數。用到哪些欄位依符號而定；其餘忽略。
#[derive(Clone, Debug, PartialEq)]
pub struct SymbolParams {
    /// 名義大小（紙上毫米）。
    pub size_mm: f32,
    /// 附帶的文字：表面粗度的 Ra 值、公差值、編號、螺紋規格…
    pub text: String,
    /// 繞定位點旋轉（度，頁面上順時針為正）。
    pub rotation_deg: f32,
    /// 焊接符號：畫在「另一側」（參考線上方）。
    pub other_side: bool,
    /// 焊接符號：環繞焊接（圓圈）。
    pub all_around: bool,
    /// 焊接符號：現場焊接（旗）。
    pub field: bool,
    /// 幾何公差：公差值前面加 ⌀。
    pub diameter: bool,
    /// 幾何公差：基準字母（最多三個）。
    pub datums: Vec<char>,
    /// 螺栓／螺母／墊圈的長度（毫米）。
    pub length_mm: f32,
}

impl Default for SymbolParams {
    fn default() -> Self {
        SymbolParams {
            size_mm: 3.5,
            text: String::new(),
            rotation_deg: 0.0,
            other_side: false,
            all_around: false,
            field: false,
            diameter: false,
            datums: Vec::new(),
            length_mm: 20.0,
        }
    }
}

/// 符號清單：(識別字, 分組)。識別字穩定（存設定、無障礙識別碼、語系鍵 `draft_sym_<id>` 都用它）。
pub const CATALOG: &[(&str, &str)] = &[
    ("surface_basic", "surface"),
    ("surface_machined", "surface"),
    ("surface_no_machining", "surface"),
    ("weld_fillet", "weld"),
    ("weld_vee", "weld"),
    ("weld_square", "weld"),
    ("weld_bevel", "weld"),
    ("weld_plug", "weld"),
    ("thread_external_side", "thread"),
    ("thread_internal_side", "thread"),
    ("thread_external_end", "thread"),
    ("thread_internal_end", "thread"),
    ("gdt_straightness", "gdt"),
    ("gdt_flatness", "gdt"),
    ("gdt_circularity", "gdt"),
    ("gdt_cylindricity", "gdt"),
    ("gdt_profile_line", "gdt"),
    ("gdt_profile_surface", "gdt"),
    ("gdt_parallelism", "gdt"),
    ("gdt_perpendicularity", "gdt"),
    ("gdt_angularity", "gdt"),
    ("gdt_position", "gdt"),
    ("gdt_concentricity", "gdt"),
    ("gdt_symmetry", "gdt"),
    ("gdt_runout", "gdt"),
    ("gdt_total_runout", "gdt"),
    ("datum_feature", "gdt"),
    ("center_mark", "mark"),
    ("balloon", "mark"),
    ("bolt_hex", "fastener"),
    ("nut_hex", "fastener"),
    ("washer", "fastener"),
];

/// 依識別字產生符號。認不得的識別字回 `None`。
pub fn make(id: &str, anchor: P2, params: &SymbolParams) -> Option<Drawing> {
    let u = params.size_mm.clamp(1.0, 40.0) * UNITS_PER_MM;
    let mut d = match id {
        "surface_basic" => surface(u, params, SurfaceKind::Basic),
        "surface_machined" => surface(u, params, SurfaceKind::Machined),
        "surface_no_machining" => surface(u, params, SurfaceKind::NoMachining),
        "weld_fillet" => weld(u, params, WeldKind::Fillet),
        "weld_vee" => weld(u, params, WeldKind::Vee),
        "weld_square" => weld(u, params, WeldKind::Square),
        "weld_bevel" => weld(u, params, WeldKind::Bevel),
        "weld_plug" => weld(u, params, WeldKind::Plug),
        "thread_external_side" => thread_side(u, params, true),
        "thread_internal_side" => thread_side(u, params, false),
        "thread_external_end" => thread_end(u, params, true),
        "thread_internal_end" => thread_end(u, params, false),
        "datum_feature" => datum_feature(u, params),
        "center_mark" => center_mark(u),
        "balloon" => balloon(u, params),
        "bolt_hex" => crate::fastener::bolt(params),
        "nut_hex" => crate::fastener::nut(params),
        "washer" => crate::fastener::washer(params),
        _ => {
            let kind = id.strip_prefix("gdt_")?;
            crate::gdt::frame(u, params, kind)?
        }
    };
    rotate(&mut d, (0.0, 0.0), params.rotation_deg.to_radians());
    d.translate(anchor.0, anchor.1);
    Some(d)
}

/// 繞 `about` 轉 `angle` 弧度（頁面座標 y 向下，所以正角度是順時針）。
pub fn rotate(d: &mut Drawing, about: P2, angle: f32) {
    if angle.abs() < 1e-6 {
        return;
    }
    let (s, c) = angle.sin_cos();
    let f = |p: P2| {
        let (x, y) = (p.0 - about.0, p.1 - about.1);
        (about.0 + x * c - y * s, about.1 + x * s + y * c)
    };
    for st in &mut d.strokes {
        for p in &mut st.points {
            *p = f(*p);
        }
    }
    for l in &mut d.labels {
        let p = f((l.x, l.y));
        l.x = p.0;
        l.y = p.1;
    }
}

/// 一行文字（筆畫字形）放在 `(x, y)` 左上角。
pub(crate) fn text_at(d: &mut Drawing, text: &str, x: f32, y: f32, h: f32) -> f32 {
    let (glyphs, w) = text_strokes(text, x, y, h);
    for g in glyphs {
        d.polyline(Role::Text, g);
    }
    w
}

/// 圓（閉合折線），`n` 段。
pub(crate) fn circle(c: P2, r: f32, n: usize) -> Vec<P2> {
    let mut v: Vec<P2> = (0..=n)
        .map(|i| {
            let a = i as f32 / n as f32 * std::f32::consts::TAU;
            (c.0 + r * a.cos(), c.1 + r * a.sin())
        })
        .collect();
    // 首尾必須是**同一個點**（浮點誤差會讓 sin(2π) 不是 0），閉合的圖形才認得出來。
    if let Some(first) = v.first().copied() {
        *v.last_mut().unwrap() = first;
    }
    v
}

/// 圓弧（`a0` 到 `a1`，弧度，頁面座標）。
pub(crate) fn arc(c: P2, r: f32, a0: f32, a1: f32, n: usize) -> Vec<P2> {
    (0..=n)
        .map(|i| {
            let a = a0 + (a1 - a0) * i as f32 / n as f32;
            (c.0 + r * a.cos(), c.1 + r * a.sin())
        })
        .collect()
}

// ---- 表面粗度 --------------------------------------------------------------

enum SurfaceKind {
    Basic,
    Machined,
    NoMachining,
}

/// 定位點是符號的尖端（碰到表面的那一點），符號往上長。`u` 是字高，符號高度約 `2.4u`。
fn surface(u: f32, p: &SymbolParams, kind: SurfaceKind) -> Drawing {
    let mut d = Drawing::default();
    let h = u * 2.0;
    // 60° 的兩條腿：左腿短、右腿長；「去除材料」把兩腿拉一樣長並用橫線封起來。
    let (sx, sy) = (0.5, 0.866_025_4);
    let right = (h * 1.2 * sx, -h * 1.2 * sy);
    match kind {
        SurfaceKind::Machined => {
            let left = (-h * 1.2 * sx, -h * 1.2 * sy);
            d.polyline(Role::Dimension, vec![left, (0.0, 0.0), right, left]);
        }
        _ => {
            let left = (-h * 0.6 * sx, -h * 0.6 * sy);
            d.polyline(Role::Dimension, vec![left, (0.0, 0.0), right]);
        }
    }
    if matches!(kind, SurfaceKind::NoMachining) {
        // 不去除材料：圓圈頂在兩腿之間。
        let r = h * 0.28;
        d.polyline(Role::Dimension, circle((0.0, -h * 0.62), r, 20));
    }
    if !p.text.is_empty() {
        // 粗糙度值接在長腿的頂端，往右延伸一條水平線，值寫在線上。
        let th = u;
        let w = text_strokes(&p.text, 0.0, 0.0, th).1;
        let foot = (right.0 + th * 0.2, right.1);
        d.line(Role::Dimension, right, (foot.0 + w + th * 0.5, foot.1));
        text_at(&mut d, &p.text, foot.0 + th * 0.2, foot.1 - th * 1.15, th);
    }
    d
}

// ---- 焊接 ------------------------------------------------------------------

enum WeldKind {
    Fillet,
    Vee,
    Square,
    Bevel,
    Plug,
}

/// 箭頭尖在定位點，箭頭線往右上方拉到參考線，參考線水平往右。符號畫在參考線的下方（箭頭側），
/// `other_side` 則畫在上方（另一側）。
fn weld(u: f32, p: &SymbolParams, kind: WeldKind) -> Drawing {
    let mut d = Drawing::default();
    let arrow_len = u * 4.0;
    let ref_len = u * 6.0;
    let tip = (0.0, 0.0);
    let joint = (arrow_len * 0.7, -arrow_len * 0.7);
    let end = (joint.0 + ref_len, joint.1);
    d.line(Role::Dimension, tip, joint);
    d.line(Role::Dimension, joint, end);
    // 箭頭。
    let back = ((joint.0 - tip.0), (joint.1 - tip.1));
    let l = back.0.hypot(back.1);
    let b = (back.0 / l, back.1 / l);
    let n = (-b.1, b.0);
    let (al, ah) = (u * 0.9, u * 0.3);
    let base = (tip.0 + b.0 * al, tip.1 + b.1 * al);
    d.polyline(
        Role::Dimension,
        vec![
            (base.0 + n.0 * ah, base.1 + n.1 * ah),
            tip,
            (base.0 - n.0 * ah, base.1 - n.1 * ah),
        ],
    );
    // 符號：以參考線中央為基準。`s = +1` 往下（箭頭側）、`−1` 往上。
    let s = if p.other_side { -1.0 } else { 1.0 };
    let cx = joint.0 + ref_len * 0.45;
    let y0 = joint.1;
    let k = u * 1.1;
    match kind {
        WeldKind::Fillet => {
            // 直角三角形：直邊在左。
            d.polyline(
                Role::Dimension,
                vec![
                    (cx - k * 0.5, y0),
                    (cx - k * 0.5, y0 + s * k),
                    (cx + k * 0.5, y0),
                ],
            );
        }
        WeldKind::Vee => {
            d.polyline(
                Role::Dimension,
                vec![(cx - k * 0.55, y0), (cx, y0 + s * k), (cx + k * 0.55, y0)],
            );
        }
        WeldKind::Square => {
            d.line(
                Role::Dimension,
                (cx - k * 0.18, y0),
                (cx - k * 0.18, y0 + s * k),
            );
            d.line(
                Role::Dimension,
                (cx + k * 0.18, y0),
                (cx + k * 0.18, y0 + s * k),
            );
        }
        WeldKind::Bevel => {
            d.polyline(
                Role::Dimension,
                vec![
                    (cx - k * 0.4, y0),
                    (cx - k * 0.4, y0 + s * k),
                    (cx + k * 0.4, y0),
                ],
            );
        }
        WeldKind::Plug => {
            d.polyline(
                Role::Dimension,
                vec![
                    (cx - k * 0.6, y0),
                    (cx - k * 0.6, y0 + s * k * 0.8),
                    (cx + k * 0.6, y0 + s * k * 0.8),
                    (cx + k * 0.6, y0),
                ],
            );
        }
    }
    if p.all_around {
        d.polyline(Role::Dimension, circle(joint, u * 0.55, 16));
    }
    if p.field {
        // 現場焊接：旗在轉折點上。
        let pole = (joint.0, joint.1 - u * 1.8);
        d.line(Role::Dimension, joint, pole);
        d.polyline(
            Role::Dimension,
            vec![
                pole,
                (pole.0 + u * 1.2, pole.1 + u * 0.45),
                (pole.0, pole.1 + u * 0.9),
            ],
        );
    }
    if !p.text.is_empty() {
        // 尺寸（焊腳）寫在符號旁邊。
        text_at(
            &mut d,
            &p.text,
            cx - k * 1.8 - u * 2.0,
            y0 + s * k * 0.1 - u * 0.5,
            u,
        );
    }
    d
}

// ---- 螺紋 ------------------------------------------------------------------

/// 螺紋側視圖：定位點在左端軸心，軸向往右 `length_mm`，大徑是 `size_mm` 的 ... 這裡用 `size_mm` 當直徑。
/// 外螺紋：大徑畫粗線、小徑畫細線；內螺紋（剖面）反過來。
fn thread_side(u: f32, p: &SymbolParams, external: bool) -> Drawing {
    let mut d = Drawing::default();
    let dia = u.max(1.0) * 2.0;
    let len = (p.length_mm.max(2.0)) * UNITS_PER_MM;
    let (major, minor) = (dia / 2.0, dia / 2.0 * 0.82);
    let (thick, thin) = (Role::Visible, Role::Dimension);
    let (outer_role, inner_role) = if external {
        (thick, thin)
    } else {
        (thin, thick)
    };
    // 大徑的兩條線與小徑的兩條線；端線（牙底到牙頂）用粗線。
    for sgn in [-1.0, 1.0] {
        d.line(outer_role, (0.0, sgn * major), (len, sgn * major));
        d.line(inner_role, (0.0, sgn * minor), (len, sgn * minor));
    }
    d.line(thick, (len, -minor.max(major)), (len, minor.max(major)));
    // 軸線。
    d.line(Role::Center, (-dia * 0.4, 0.0), (len + dia * 0.4, 0.0));
    if !p.text.is_empty() {
        text_at(&mut d, &p.text, len + dia * 0.2, -dia * 0.5, dia * 0.5);
    }
    d
}

/// 螺紋端視圖：定位點在圓心。外螺紋：大徑粗圓、小徑 3/4 細弧；內螺紋反過來。
fn thread_end(u: f32, p: &SymbolParams, external: bool) -> Drawing {
    let mut d = Drawing::default();
    let dia = u.max(1.0) * 2.0;
    let (major, minor) = (dia / 2.0, dia / 2.0 * 0.82);
    let (full_r, part_r) = if external {
        (major, minor)
    } else {
        (minor, major)
    };
    d.polyline(Role::Visible, circle((0.0, 0.0), full_r, 40));
    // 3/4 圓：缺的那 1/4 在右上角。
    let quarter = std::f32::consts::FRAC_PI_2;
    d.polyline(
        Role::Dimension,
        arc((0.0, 0.0), part_r, 0.0, 3.0 * quarter, 30),
    );
    d.line(Role::Center, (-dia * 0.7, 0.0), (dia * 0.7, 0.0));
    d.line(Role::Center, (0.0, -dia * 0.7), (0.0, dia * 0.7));
    if !p.text.is_empty() {
        text_at(&mut d, &p.text, dia * 0.8, -dia * 0.2, dia * 0.4);
    }
    d
}

// ---- 基準、中心記號、編號球 ---------------------------------------------------

/// 基準：實心三角形（用斜線填滿）、連到方框，框裡是基準字母（`text` 的第一個字元）。
/// 定位點是三角形的頂點（靠在被指定為基準的面上）。
fn datum_feature(u: f32, p: &SymbolParams) -> Drawing {
    let mut d = Drawing::default();
    let tri = u * 1.6;
    // 三角形尖朝下、頂點在原點；底在上方。
    let a = (0.0, 0.0);
    let l = (-tri * 0.5, -tri * 0.87);
    let r = (tri * 0.5, -tri * 0.87);
    d.polyline(Role::Dimension, vec![a, l, r, a]);
    // 填色：兩條細斜線。
    for t in [0.35f32, 0.65] {
        let y = -tri * 0.87 * t;
        let half = tri * 0.5 * t;
        d.line(Role::Dimension, (-half, y), (half, y));
    }
    // 連線與方框。
    let box_w = u * 2.0;
    let top = -tri * 0.87;
    d.line(Role::Dimension, (0.0, top), (0.0, top - u * 1.5));
    let by = top - u * 1.5 - box_w;
    d.polyline(
        Role::Dimension,
        vec![
            (-box_w / 2.0, by),
            (box_w / 2.0, by),
            (box_w / 2.0, by + box_w),
            (-box_w / 2.0, by + box_w),
            (-box_w / 2.0, by),
        ],
    );
    let letter: String = p.text.chars().take(1).collect();
    let letter = if letter.is_empty() {
        "A".into()
    } else {
        letter
    };
    let tw = text_strokes(&letter, 0.0, 0.0, u * 1.2).1;
    text_at(
        &mut d,
        &letter,
        -tw / 2.0,
        by + (box_w - u * 1.2) / 2.0,
        u * 1.2,
    );
    d
}

/// 中心記號：十字，兩臂是中心線；`size_mm` 是單臂長度。
fn center_mark(u: f32) -> Drawing {
    let mut d = Drawing::default();
    let l = u * 2.0;
    d.line(Role::Center, (-l, 0.0), (l, 0.0));
    d.line(Role::Center, (0.0, -l), (0.0, l));
    d
}

/// 零件編號球：定位點是引線的尖端（箭頭點在零件上），圓圈在右上方，圈裡是編號。
fn balloon(u: f32, p: &SymbolParams) -> Drawing {
    let mut d = Drawing::default();
    let r = u * 1.8;
    let c = (u * 3.5, -u * 3.5);
    let dir = (c.0.hypot(c.1), 0.0).0;
    let n = (c.0 / dir, c.1 / dir);
    let edge = (c.0 - n.0 * r, c.1 - n.1 * r);
    d.line(Role::Dimension, (0.0, 0.0), edge);
    d.polyline(Role::Dimension, circle(c, r, 24));
    // 引線尖端用實心小圓點表示（零件在內部時用點、在邊緣時用箭頭 —— 這裡統一用點）。
    d.polyline(Role::Dimension, circle((0.0, 0.0), u * 0.18, 8));
    let text = if p.text.is_empty() { "1" } else { &p.text };
    let tw = text_strokes(text, 0.0, 0.0, u * 1.4).1;
    text_at(&mut d, text, c.0 - tw / 2.0, c.1 - u * 0.7, u * 1.4);
    d
}

/// 供 FFI 與測試共用：符號有沒有附帶文字標籤（目前都是筆畫，沒有）。
pub fn labels(_: &Drawing) -> &[TextLabel] {
    &[]
}

#[cfg(test)]
mod tests {
    use super::*;

    fn all_points(d: &Drawing) -> Vec<P2> {
        d.strokes
            .iter()
            .flat_map(|s| s.points.iter().copied())
            .collect()
    }

    #[test]
    fn every_catalogue_entry_makes_a_non_empty_drawing() {
        for (id, _) in CATALOG {
            let d = make(id, (100.0, 100.0), &SymbolParams::default())
                .unwrap_or_else(|| panic!("{id}"));
            assert!(!d.strokes.is_empty(), "{id}");
            for p in all_points(&d) {
                assert!(p.0.is_finite() && p.1.is_finite(), "{id}");
            }
        }
        assert!(make("no_such_symbol", (0.0, 0.0), &SymbolParams::default()).is_none());
        assert!(make("gdt_nonsense", (0.0, 0.0), &SymbolParams::default()).is_none());
    }

    #[test]
    fn the_anchor_is_where_the_symbol_points() {
        // 表面粗度：尖端（兩腿相會的那一點）正好在定位點。
        let d = make("surface_basic", (200.0, 300.0), &SymbolParams::default()).unwrap();
        let legs = &d.strokes[0].points;
        assert_eq!(legs.len(), 3);
        assert!((legs[1].0 - 200.0).abs() < 1e-3 && (legs[1].1 - 300.0).abs() < 1e-3);
        // 符號往上長（y 比定位點小）。
        assert!(legs[0].1 < 300.0 && legs[2].1 < 300.0);
        // 焊接：箭頭尖在定位點。
        let w = make("weld_fillet", (50.0, 60.0), &SymbolParams::default()).unwrap();
        assert!(w.strokes.iter().any(|s| {
            s.points
                .iter()
                .any(|p| (p.0 - 50.0).abs() < 1e-3 && (p.1 - 60.0).abs() < 1e-3)
        }));
    }

    #[test]
    fn the_machined_symbol_is_a_closed_triangle_and_no_machining_adds_a_circle() {
        let machined = make("surface_machined", (0.0, 0.0), &SymbolParams::default()).unwrap();
        let tri = &machined.strokes[0].points;
        assert_eq!(tri.first(), tri.last());
        assert_eq!(tri.len(), 4);
        let none = make("surface_no_machining", (0.0, 0.0), &SymbolParams::default()).unwrap();
        let basic = make("surface_basic", (0.0, 0.0), &SymbolParams::default()).unwrap();
        assert_eq!(none.strokes.len(), basic.strokes.len() + 1);
    }

    #[test]
    fn a_roughness_value_adds_a_shoulder_line_and_text() {
        let plain = make("surface_basic", (0.0, 0.0), &SymbolParams::default()).unwrap();
        let with = make(
            "surface_basic",
            (0.0, 0.0),
            &SymbolParams {
                text: "Ra 3.2".into(),
                ..SymbolParams::default()
            },
        )
        .unwrap();
        assert!(with.strokes.len() > plain.strokes.len() + 3);
        assert!(with.strokes.iter().any(|s| s.role == Role::Text));
    }

    #[test]
    fn rotation_turns_the_drawing_about_the_anchor() {
        let up = make("center_mark", (100.0, 100.0), &SymbolParams::default()).unwrap();
        let turned = make(
            "center_mark",
            (100.0, 100.0),
            &SymbolParams {
                rotation_deg: 45.0,
                ..SymbolParams::default()
            },
        )
        .unwrap();
        // 十字轉 45° 之後兩條臂都是斜的。
        for s in &turned.strokes {
            let (a, b) = (s.points[0], s.points[1]);
            assert!(((a.0 - b.0).abs() - (a.1 - b.1).abs()).abs() < 1e-2);
        }
        // 長度不變、中心不動。
        let len = |d: &Drawing| {
            d.strokes
                .iter()
                .map(|s| {
                    ((s.points[0].0 - s.points[1].0).powi(2)
                        + (s.points[0].1 - s.points[1].1).powi(2))
                    .sqrt()
                })
                .sum::<f32>()
        };
        assert!((len(&up) - len(&turned)).abs() < 1e-2);
    }

    #[test]
    fn a_thread_side_view_has_thick_major_and_thin_minor_lines_swapped_for_internal() {
        let ext = make("thread_external_side", (0.0, 0.0), &SymbolParams::default()).unwrap();
        let int = make("thread_internal_side", (0.0, 0.0), &SymbolParams::default()).unwrap();
        let by = |d: &Drawing, y: f32| {
            d.strokes
                .iter()
                .find(|s| {
                    s.points.len() == 2
                        && (s.points[0].1 - y).abs() < 1e-3
                        && (s.points[1].1 - y).abs() < 1e-3
                })
                .map(|s| s.role)
        };
        let u = 3.5 * UNITS_PER_MM;
        let major = u * 2.0 / 2.0;
        let minor = major * 0.82;
        assert_eq!(by(&ext, major), Some(Role::Visible));
        assert_eq!(by(&ext, minor), Some(Role::Dimension));
        assert_eq!(by(&int, major), Some(Role::Dimension));
        assert_eq!(by(&int, minor), Some(Role::Visible));
    }

    #[test]
    fn a_thread_end_view_has_a_full_circle_and_a_three_quarter_arc() {
        let d = make("thread_external_end", (0.0, 0.0), &SymbolParams::default()).unwrap();
        let full = d.strokes.iter().find(|s| s.role == Role::Visible).unwrap();
        assert_eq!(full.points.first(), full.points.last());
        let part = d
            .strokes
            .iter()
            .find(|s| s.role == Role::Dimension)
            .unwrap();
        assert_ne!(part.points.first(), part.points.last());
    }

    #[test]
    fn a_balloon_puts_the_number_inside_the_circle() {
        let d = make(
            "balloon",
            (0.0, 0.0),
            &SymbolParams {
                text: "12".into(),
                ..SymbolParams::default()
            },
        )
        .unwrap();
        let text: Vec<P2> = d
            .strokes
            .iter()
            .filter(|s| s.role == Role::Text)
            .flat_map(|s| s.points.iter().copied())
            .collect();
        assert!(!text.is_empty());
        let u = 3.5 * UNITS_PER_MM;
        let c = (u * 3.5, -u * 3.5);
        for p in text {
            assert!(
                ((p.0 - c.0).powi(2) + (p.1 - c.1).powi(2)).sqrt() < u * 1.8,
                "{p:?}"
            );
        }
    }

    #[test]
    fn a_datum_feature_shows_its_letter() {
        let d = make(
            "datum_feature",
            (0.0, 0.0),
            &SymbolParams {
                text: "B".into(),
                ..SymbolParams::default()
            },
        )
        .unwrap();
        assert!(d.strokes.iter().any(|s| s.role == Role::Text));
        // 三角形的頂點在定位點。
        assert!(
            d.strokes[0]
                .points
                .iter()
                .any(|p| p.0.abs() < 1e-3 && p.1.abs() < 1e-3)
        );
    }
}
