//! 排版：把三視圖、等角圖、剖視圖、投射線、中心線排進一張圖紙，輸出成一組折線。
//!
//! # 為什麼輸出「折線＋角色」而不是畫好的筆畫
//!
//! 線的**角色**（可見輪廓、隱藏線、中心線、投射線、剖面線…）決定它畫在哪一層、用什麼線型與筆寬。
//! 那張對照表是核心的製圖筆組（`ffi_draft.rs`），不是這個 crate 的事 —— 這裡只說
//! 「這是一條隱藏線」，由呼叫端換成實際的圖層與筆。
//!
//! # 座標
//!
//! 輸出是**頁面座標**（原點在左上、y 向下），已經縮放到 `fit` 的範圍內；呼叫端加上位置偏移即可。

use crate::geom::{self, P2};
use crate::section::{Cut, SectionView, section_view};
use crate::solid::Solid;
use crate::view::{Camera, Line2, StandardView, View, project};

/// 線的角色。
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Role {
    /// 看得見的輪廓：粗實線。
    Visible,
    /// 被擋住的邊：隱藏線。
    Hidden,
    /// 圓孔、圓柱的中心線。
    Center,
    /// 視圖之間的投射線：中層淺藍細線。
    Projection,
    /// 剖面線。
    Hatch,
    /// 剖面位置線（畫在正視圖上）。
    CutLine,
    /// 剖面位置線兩端的粗短線（箭頭方向 = 觀看方向）。
    CutEnd,
}

#[derive(Clone, Debug)]
pub struct SheetStroke {
    pub role: Role,
    pub points: Vec<P2>,
}

/// 第一角法或第三角法。台灣與美國用第三角，歐陸與中國用第一角。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Convention {
    ThirdAngle,
    FirstAngle,
}

#[derive(Clone, Debug)]
pub struct SheetOptions {
    pub convention: Convention,
    pub include_iso: bool,
    pub projection_lines: bool,
    pub center_lines: bool,
    pub section: Option<Cut>,
    /// 排進這個範圍（頁面單位）。
    pub fit: P2,
    /// 剖面線間距（頁面單位，縮放之後的）。
    pub hatch_spacing: f32,
}

impl Default for SheetOptions {
    fn default() -> Self {
        SheetOptions {
            convention: Convention::ThirdAngle,
            include_iso: true,
            projection_lines: true,
            center_lines: true,
            section: None,
            fit: (600.0, 600.0),
            hatch_spacing: 6.0,
        }
    }
}

#[derive(Clone, Debug)]
pub struct Sheet {
    pub strokes: Vec<SheetStroke>,
    /// 圖紙一個模型單位對應幾個頁面單位。
    pub scale: f32,
    pub width: f32,
    pub height: f32,
}

/// 一個擺好位置的視圖（單位座標，y 向上）。
struct Placed {
    lines: Vec<Line2>,
    hatch: Vec<(P2, P2)>,
    /// 視圖的左下角（單位座標）。
    origin: P2,
    /// 視圖內容的左下角（視圖自己座標系）。
    lo: P2,
    size: P2,
}

impl Placed {
    fn from_view(v: &View, origin: P2) -> Placed {
        let (lo, hi) = v.bounds().unwrap_or(((0.0, 0.0), (0.0, 0.0)));
        Placed {
            lines: v.lines.clone(),
            hatch: Vec::new(),
            origin,
            lo,
            size: (hi.0 - lo.0, hi.1 - lo.1),
        }
    }

    fn from_section(sv: &SectionView, origin: P2) -> Placed {
        let mut pts: Vec<P2> = sv.lines.iter().flat_map(|l| [l.a, l.b]).collect();
        pts.extend(sv.hatch.iter().flat_map(|h| [h.0, h.1]));
        let (lo, hi) = geom::bounds(&pts).unwrap_or(((0.0, 0.0), (0.0, 0.0)));
        Placed {
            lines: sv.lines.clone(),
            hatch: sv.hatch.clone(),
            origin,
            lo,
            size: (hi.0 - lo.0, hi.1 - lo.1),
        }
    }

    fn map(&self, p: P2) -> P2 {
        (
            p.0 - self.lo.0 + self.origin.0,
            p.1 - self.lo.1 + self.origin.1,
        )
    }
}

/// 剖面位置線只畫在正視圖的包圍盒（外擴一點）之內。
fn clip_to_rect(a: P2, b: P2, lo: P2, hi: P2) -> Option<(P2, P2)> {
    // Liang–Barsky。
    let (dx, dy) = (b.0 - a.0, b.1 - a.1);
    let (mut t0, mut t1) = (0.0f32, 1.0f32);
    for (p, q) in [
        (-dx, a.0 - lo.0),
        (dx, hi.0 - a.0),
        (-dy, a.1 - lo.1),
        (dy, hi.1 - a.1),
    ] {
        if p.abs() < 1e-9 {
            if q < 0.0 {
                return None;
            }
        } else {
            let r = q / p;
            if p < 0.0 {
                t0 = t0.max(r);
            } else {
                t1 = t1.min(r);
            }
            if t0 > t1 {
                return None;
            }
        }
    }
    Some((
        (a.0 + dx * t0, a.1 + dy * t0),
        (a.0 + dx * t1, a.1 + dy * t1),
    ))
}

/// 投射線要對齊的座標：圓取左、中、右；多邊形取所有頂點。
fn key_coords(solid: &Solid) -> (Vec<f32>, Vec<f32>) {
    let (mut xs, mut ys) = (Vec::new(), Vec::new());
    for ring in solid.profile.rings() {
        if let Some((c, r)) = geom::ring_as_circle(ring) {
            xs.extend([c.0 - r, c.0, c.0 + r]);
            ys.extend([c.1 - r, c.1, c.1 + r]);
        } else {
            for p in ring {
                xs.push(p.0);
                ys.push(p.1);
            }
        }
    }
    let dedupe = |mut v: Vec<f32>| {
        v.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
        v.dedup_by(|a, b| (*a - *b).abs() < 0.5);
        v
    };
    (dedupe(xs), dedupe(ys))
}

/// 組一張圖紙。
pub fn compose(solid: &Solid, opts: &SheetOptions) -> Sheet {
    let [w, h, d] = solid.dims();
    let biggest = w.max(h).max(d).max(1.0);
    let gap = biggest * 0.28;
    let ext = (biggest * 0.08).max(3.0);
    let third = opts.convention == Convention::ThirdAngle;

    // 視圖。有剖面時，對應的視圖換成剖視圖。
    let section_viewer = match &opts.section {
        Some(Cut::Path { viewer, .. }) => Some(*viewer),
        _ => None,
    };
    let parallel_cut = matches!(opts.section, Some(Cut::Parallel { .. }));
    let top_is_section = section_viewer.is_some_and(|v| v.1.abs() > v.0.abs());
    let right_is_section = section_viewer.is_some_and(|v| v.1.abs() <= v.0.abs());

    let section = opts
        .section
        .as_ref()
        .map(|c| section_view(solid, c, opts.hatch_spacing_in_model(w, h, d, opts.fit)));

    let mut front = Placed::from_view(
        &project(solid, &Camera::standard(StandardView::Front)),
        (0.0, 0.0),
    );
    if let (true, Some(sv)) = (parallel_cut, &section) {
        front = Placed::from_section(sv, (0.0, 0.0));
    }
    // 第三角法：俯視圖在上、右視圖在右；第一角法：俯視圖在下、右視圖在左。
    let top_origin = if third {
        (0.0, h + gap)
    } else {
        (0.0, -gap - d)
    };
    let right_origin = if third {
        (w + gap, 0.0)
    } else {
        (-gap - d, 0.0)
    };
    let top = match (&section, top_is_section) {
        (Some(sv), true) => Placed::from_section(sv, top_origin),
        _ => Placed::from_view(
            &project(solid, &Camera::standard(StandardView::Top)),
            top_origin,
        ),
    };
    let right = match (&section, right_is_section) {
        (Some(sv), true) => Placed::from_section(sv, right_origin),
        _ => Placed::from_view(
            &project(solid, &Camera::standard(StandardView::Right)),
            right_origin,
        ),
    };
    let iso = opts.include_iso.then(|| {
        let v = project(solid, &Camera::standard(StandardView::Iso));
        Placed::from_view(&v, (w + gap, h + gap))
    });

    let mut placed: Vec<&Placed> = vec![&front, &top, &right];
    if let Some(i) = &iso {
        placed.push(i);
    }

    // 單位座標下的所有線（連同投射線、中心線、剖面位置線）。
    let mut strokes: Vec<(Role, Vec<P2>)> = Vec::new();
    for p in &placed {
        for l in &p.lines {
            strokes.push((
                if l.hidden {
                    Role::Hidden
                } else {
                    Role::Visible
                },
                vec![p.map(l.a), p.map(l.b)],
            ));
        }
        for (a, b) in &p.hatch {
            strokes.push((Role::Hatch, vec![p.map(*a), p.map(*b)]));
        }
    }

    if opts.projection_lines {
        let (xs, ys) = key_coords(solid);
        for x in xs {
            let (y0, y1) = if third { (h, h + gap) } else { (0.0, -gap) };
            strokes.push((Role::Projection, vec![(x, y0), (x, y1)]));
        }
        for y in ys {
            let (x0, x1) = if third { (w, w + gap) } else { (0.0, -gap) };
            strokes.push((Role::Projection, vec![(x0, y), (x1, y)]));
        }
    }

    if opts.center_lines {
        for ring in solid.profile.rings() {
            if let Some((c, r)) = geom::ring_as_circle(ring) {
                let reach = r + ext;
                // 正視圖：十字。
                strokes.push((Role::Center, vec![(c.0 - reach, c.1), (c.0 + reach, c.1)]));
                strokes.push((Role::Center, vec![(c.0, c.1 - reach), (c.0, c.1 + reach)]));
                // 俯視圖：軸線沿深度方向。
                if !top_is_section {
                    strokes.push((
                        Role::Center,
                        vec![
                            (c.0, top.origin.1 - ext),
                            (c.0, top.origin.1 + top.size.1 + ext),
                        ],
                    ));
                }
                // 右視圖。
                if !right_is_section {
                    strokes.push((
                        Role::Center,
                        vec![
                            (right.origin.0 - ext, c.1),
                            (right.origin.0 + right.size.0 + ext, c.1),
                        ],
                    ));
                }
            }
        }
    }

    // 剖面位置線：畫在正視圖上。
    if let Some(cut) = &opts.section {
        let lo = (-ext, -ext);
        let hi = (w + ext, h + ext);
        let clipped: Vec<(P2, P2)> = cut
            .plan_lines()
            .iter()
            .filter_map(|(a, b)| clip_to_rect(*a, *b, lo, hi))
            .collect();
        for (a, b) in &clipped {
            strokes.push((Role::CutLine, vec![*a, *b]));
        }
        // 兩端的粗短線，朝觀看方向。
        if let (Some(first), Some(last), Cut::Path { viewer, .. }) =
            (clipped.first(), clipped.last(), cut)
        {
            let tick = ext * 1.2;
            for p in [first.0, last.1] {
                strokes.push((
                    Role::CutEnd,
                    vec![p, (p.0 + viewer.0 * tick, p.1 + viewer.1 * tick)],
                ));
            }
        }
    }

    // 整體範圍 → 縮放與翻轉成頁面座標。
    let all_pts: Vec<P2> = strokes
        .iter()
        .flat_map(|(_, p)| p.iter().copied())
        .collect();
    let (lo, hi) = geom::bounds(&all_pts).unwrap_or(((0.0, 0.0), (1.0, 1.0)));
    let (tw, th) = ((hi.0 - lo.0).max(1.0), (hi.1 - lo.1).max(1.0));
    let scale = (opts.fit.0 / tw).min(opts.fit.1 / th);
    let to_page = |p: P2| ((p.0 - lo.0) * scale, (hi.1 - p.1) * scale);
    Sheet {
        strokes: strokes
            .into_iter()
            .map(|(role, pts)| SheetStroke {
                role,
                points: pts.into_iter().map(to_page).collect(),
            })
            .collect(),
        scale,
        width: tw * scale,
        height: th * scale,
    }
}

impl SheetOptions {
    /// 剖面線間距換算成模型單位（先估一個縮放，使成品的間距接近 `hatch_spacing`）。
    fn hatch_spacing_in_model(&self, w: f32, h: f32, d: f32, fit: P2) -> f32 {
        let gap = w.max(h).max(d) * 0.28;
        let tw = w + gap + d + w.max(h) * 0.5;
        let th = h + gap + d;
        let scale = (fit.0 / tw.max(1.0)).min(fit.1 / th.max(1.0)).max(1e-3);
        (self.hatch_spacing / scale).max(0.5)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::solid::preset;

    fn count(sheet: &Sheet, role: Role) -> usize {
        sheet.strokes.iter().filter(|s| s.role == role).count()
    }

    fn cube() -> Solid {
        Solid::new(preset("rect", 40.0, 40.0).unwrap(), 40.0)
    }

    #[test]
    fn a_cube_sheet_has_three_views_and_an_iso() {
        let sheet = compose(&cube(), &SheetOptions::default());
        // 三個視圖各 4 條 + 等角 9 條可見；隱藏線只有等角的 3 條。
        assert_eq!(count(&sheet, Role::Visible), 4 * 3 + 9);
        assert_eq!(count(&sheet, Role::Hidden), 3);
        assert_eq!(count(&sheet, Role::Hatch), 0);
    }

    #[test]
    fn the_sheet_fits_in_the_target_area() {
        let opts = SheetOptions {
            fit: (500.0, 400.0),
            ..SheetOptions::default()
        };
        let sheet = compose(&cube(), &opts);
        assert!(
            sheet.width <= 500.5 && sheet.height <= 400.5,
            "{}x{}",
            sheet.width,
            sheet.height
        );
        // 至少有一個方向貼齊邊界。
        assert!(sheet.width > 499.0 || sheet.height > 399.0);
        for s in &sheet.strokes {
            for p in &s.points {
                assert!(
                    p.0 > -0.5 && p.0 < 500.5 && p.1 > -0.5 && p.1 < 400.5,
                    "{p:?}"
                );
            }
        }
    }

    #[test]
    fn projection_lines_connect_the_views() {
        let sheet = compose(&cube(), &SheetOptions::default());
        // 方塊的關鍵座標：x = 0、40；y = 0、40 → 各 2 條。
        assert_eq!(count(&sheet, Role::Projection), 4);
        let none = compose(
            &cube(),
            &SheetOptions {
                projection_lines: false,
                ..SheetOptions::default()
            },
        );
        assert_eq!(count(&none, Role::Projection), 0);
    }

    #[test]
    fn circles_get_centre_lines_in_every_view() {
        let ring = Solid::new(preset("ring", 60.0, 60.0).unwrap(), 20.0);
        let sheet = compose(&ring, &SheetOptions::default());
        // 外圓與孔各一個圓：每個 = 正視圖 2 條（十字）+ 俯視 1 + 右視 1。
        assert_eq!(count(&sheet, Role::Center), 2 * 4);
    }

    #[test]
    fn the_l_prism_front_view_is_where_it_should_be_in_both_conventions() {
        // L 形外框：正視圖是 L；俯視圖與右視圖是矩形。第三角法的正視圖在左下，第一角法在右下。
        let l = Solid::new(preset("l_shape", 60.0, 50.0).unwrap(), 20.0);
        let opts = |c| SheetOptions {
            convention: c,
            include_iso: false,
            projection_lines: false,
            center_lines: false,
            ..SheetOptions::default()
        };
        // 底邊：頁面 y 最大的橫線裡最長的那一條是正視圖的底（60），右視圖的底只有 20。
        let find_front = |s: &Sheet| -> f32 {
            let horizontals: Vec<&SheetStroke> = s
                .strokes
                .iter()
                .filter(|k| k.points[0].1 == k.points[1].1)
                .collect();
            let bottom_y = horizontals
                .iter()
                .map(|k| k.points[0].1)
                .fold(f32::MIN, f32::max);
            let longest = horizontals
                .iter()
                .filter(|k| (k.points[0].1 - bottom_y).abs() < 0.01)
                .max_by(|a, b| {
                    (a.points[1].0 - a.points[0].0)
                        .abs()
                        .partial_cmp(&(b.points[1].0 - b.points[0].0).abs())
                        .unwrap()
                })
                .unwrap();
            (longest.points[0].0 + longest.points[1].0) / 2.0
        };
        let third = compose(&l, &opts(Convention::ThirdAngle));
        let first = compose(&l, &opts(Convention::FirstAngle));
        assert!(
            find_front(&third) < third.width / 2.0,
            "第三角法：正視圖在左側"
        );
        assert!(
            find_front(&first) > first.width / 2.0,
            "第一角法：正視圖在右側"
        );
    }

    #[test]
    fn a_section_replaces_the_matching_view_and_adds_hatch() {
        let ring = Solid::new(preset("ring", 60.0, 60.0).unwrap(), 20.0);
        let opts = SheetOptions {
            section: Some(Cut::full(&ring, 90.0, 0.5, true)),
            ..SheetOptions::default()
        };
        let sheet = compose(&ring, &opts);
        assert!(count(&sheet, Role::Hatch) > 0);
        assert_eq!(count(&sheet, Role::CutLine), 1);
        assert_eq!(count(&sheet, Role::CutEnd), 2);
        // 剖視圖取代了右視圖：右視圖的隱藏線（孔）不會再出現。
        let plain = compose(&ring, &SheetOptions::default());
        assert!(count(&sheet, Role::Hidden) < count(&plain, Role::Hidden));
    }

    #[test]
    fn a_parallel_section_replaces_the_front_view() {
        let ring = Solid::new(preset("ring", 60.0, 60.0).unwrap(), 20.0);
        let opts = SheetOptions {
            section: Some(Cut::parallel(&ring, 0.5)),
            ..SheetOptions::default()
        };
        let sheet = compose(&ring, &opts);
        assert!(count(&sheet, Role::Hatch) > 0);
    }

    #[test]
    fn clipping_keeps_the_part_inside_the_box() {
        let r = clip_to_rect((-100.0, 5.0), (100.0, 5.0), (0.0, 0.0), (10.0, 10.0)).unwrap();
        assert!((r.0.0).abs() < 1e-3 && (r.1.0 - 10.0).abs() < 1e-3);
        assert!(clip_to_rect((-100.0, 50.0), (100.0, 50.0), (0.0, 0.0), (10.0, 10.0)).is_none());
    }
}
