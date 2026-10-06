//! 剖面：假想把立體沿一個面切開、移走靠近觀看者的那一半，看切口與切口後面的東西。
//!
//! # 製圖慣例
//!
//! - **切口**畫剖面線（45° 平行細實線），而且只畫在**實體有材料**的地方 —— 孔的位置是空的，不畫。
//! - 切口後面看得見的邊畫粗實線；看不見的隱藏線**省略**（剖視圖不畫隱藏線）。
//! - **階梯剖面**：切面由幾段平行的平面接成，轉折處在剖視圖上**不畫線**，
//!   整體當成同一個切面。
//! - **旋轉剖面**：切面由兩段相交的平面組成，第二段**轉到**與第一段同一個平面再投影。
//!
//! # 支援哪些切法
//!
//! 立體是柱體，所以切面分兩種：**平行於輪廓**（正視圖方向的全剖面）與
//! **垂直於輪廓**（沿著 XY 平面上的一條折線切下去，包含上述三種）。
//! 斜切（切面同時斜向深度與輪廓）不支援 —— 柱體上很少需要，而且得做真正的多面體布林運算。

use crate::geom::{self, P2, P3};
use crate::solid::{Edge, Face, FaceKind, Solid, mesh_from_rings};
use crate::view::{Camera, Line2, StandardView, View, project_mesh};

/// 把這一段幾何轉到另一個位置（旋轉剖面用）：繞 `pivot` 轉 `angle` 弧度。
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Unfold {
    pub pivot: P2,
    pub angle: f32,
}

/// 切面路徑上的一段（在輪廓所在的 XY 平面上）。
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Leg {
    pub a: P2,
    pub b: P2,
    /// 階梯剖面的轉折段：用來連接兩段平行切面，不產生切口。
    pub connector: bool,
    pub unfold: Option<Unfold>,
}

#[derive(Clone, Debug, PartialEq)]
pub enum Cut {
    /// 平行於輪廓的切面，在深度 `z`（`−depth..=0`）處切開，從正面看。
    Parallel { z: f32 },
    /// 垂直於輪廓的切面。`viewer` 是從物體指向觀看者的單位向量（在 XY 平面上）。
    Path { legs: Vec<Leg>, viewer: P2 },
}

fn extent_along(solid: &Solid, dir: P2) -> (f32, f32) {
    let (mut lo, mut hi) = (f32::MAX, f32::MIN);
    for p in &solid.profile.outer {
        let s = p.0 * dir.0 + p.1 * dir.1;
        lo = lo.min(s);
        hi = hi.max(s);
    }
    (lo, hi)
}

fn unit(angle_deg: f32) -> (P2, P2) {
    let a = angle_deg.to_radians();
    let dir = (a.cos(), a.sin());
    (dir, (-dir.1, dir.0))
}

fn reach(solid: &Solid) -> f32 {
    let (w, h) = solid.profile.size();
    (w * w + h * h).sqrt() * 2.0 + 10.0
}

impl Cut {
    /// 單一平面全剖面。`angle_deg` 是切線在 XY 平面上的方向（0° 水平、90° 垂直），
    /// `offset` 是切線在包圍盒內的位置（0…1，0.5 在正中），`flip` 反轉觀看方向。
    pub fn full(solid: &Solid, angle_deg: f32, offset: f32, flip: bool) -> Cut {
        let (dir, n) = unit(angle_deg);
        let (lo, hi) = extent_along(solid, n);
        let s = lo + (hi - lo) * offset.clamp(0.0, 1.0);
        let l = reach(solid);
        let origin = (n.0 * s, n.1 * s);
        Cut::Path {
            legs: vec![Leg {
                a: (origin.0 - dir.0 * l, origin.1 - dir.1 * l),
                b: (origin.0 + dir.0 * l, origin.1 + dir.1 * l),
                connector: false,
                unfold: None,
            }],
            viewer: if flip { (-n.0, -n.1) } else { n },
        }
    }

    /// 階梯剖面：先沿 `offset1` 的線切，到 `step`（沿切線方向的位置，0…1）轉到 `offset2` 的平行線繼續切。
    pub fn stepped(
        solid: &Solid,
        angle_deg: f32,
        offset1: f32,
        offset2: f32,
        step: f32,
        flip: bool,
    ) -> Cut {
        let (dir, n) = unit(angle_deg);
        let (lo, hi) = extent_along(solid, n);
        let (tlo, thi) = extent_along(solid, dir);
        let s1 = lo + (hi - lo) * offset1.clamp(0.0, 1.0);
        let s2 = lo + (hi - lo) * offset2.clamp(0.0, 1.0);
        let ts = tlo + (thi - tlo) * step.clamp(0.0, 1.0);
        let l = reach(solid);
        let at = |s: f32, t: f32| (n.0 * s + dir.0 * t, n.1 * s + dir.1 * t);
        Cut::Path {
            legs: vec![
                Leg {
                    a: at(s1, -l),
                    b: at(s1, ts),
                    connector: false,
                    unfold: None,
                },
                Leg {
                    a: at(s1, ts),
                    b: at(s2, ts),
                    connector: true,
                    unfold: None,
                },
                Leg {
                    a: at(s2, ts),
                    b: at(s2, l),
                    connector: false,
                    unfold: None,
                },
            ],
            viewer: if flip { (-n.0, -n.1) } else { n },
        }
    }

    /// 旋轉剖面：兩段平面相交於 `pivot`（包圍盒內的比例位置），第二段相對第一段轉 `delta_deg`，
    /// 投影時把第二段轉回與第一段同一個平面。
    pub fn rotated(solid: &Solid, angle_deg: f32, pivot: P2, delta_deg: f32, flip: bool) -> Cut {
        let (w, h) = solid.profile.size();
        let pv = (w * pivot.0.clamp(0.0, 1.0), h * pivot.1.clamp(0.0, 1.0));
        let (dir_a, n_a) = unit(angle_deg);
        let (dir_b, _) = unit(angle_deg + delta_deg);
        let l = reach(solid);
        Cut::Path {
            legs: vec![
                Leg {
                    a: (pv.0 - dir_a.0 * l, pv.1 - dir_a.1 * l),
                    b: pv,
                    connector: false,
                    unfold: None,
                },
                Leg {
                    a: pv,
                    b: (pv.0 + dir_b.0 * l, pv.1 + dir_b.1 * l),
                    connector: false,
                    unfold: Some(Unfold {
                        pivot: pv,
                        angle: -delta_deg.to_radians(),
                    }),
                },
            ],
            viewer: if flip { (-n_a.0, -n_a.1) } else { n_a },
        }
    }

    /// 平行於輪廓的全剖面；`depth_frac` 0 在前面、1 在後面。
    pub fn parallel(solid: &Solid, depth_frac: f32) -> Cut {
        Cut::Parallel {
            z: -solid.depth * depth_frac.clamp(0.0, 1.0),
        }
    }

    /// 切面在**正視圖**上留下的線（階梯剖面含轉折段）。平行切面沒有。
    pub fn plan_lines(&self) -> Vec<(P2, P2)> {
        match self {
            Cut::Parallel { .. } => Vec::new(),
            Cut::Path { legs, .. } => legs.iter().map(|l| (l.a, l.b)).collect(),
        }
    }

    /// 剖視圖用的攝影機。
    pub fn camera(&self) -> Camera {
        match self {
            Cut::Parallel { .. } => Camera::standard(StandardView::Front),
            Cut::Path { viewer, .. } => camera_for_dir(*viewer),
        }
    }
}

/// 觀看者在 XY 平面上的方向 → 攝影機。(1,0) 是右側視圖、(0,1) 是俯視圖。
pub fn camera_for_dir(viewer: P2) -> Camera {
    let len = (viewer.0 * viewer.0 + viewer.1 * viewer.1).sqrt().max(1e-9);
    let (vx, vy) = (viewer.0 / len, viewer.1 / len);
    let pitch = vy.asin().to_degrees();
    if pitch > 89.5 {
        return Camera::standard(StandardView::Top);
    }
    if pitch < -89.5 {
        return Camera::standard(StandardView::Bottom);
    }
    Camera {
        yaw: if vx >= 0.0 { 90.0 } else { -90.0 },
        pitch,
        scale: 1.0,
    }
}

/// 剖視圖。
#[derive(Clone, Debug)]
pub struct SectionView {
    pub camera: Camera,
    /// 看得見的線（剖視圖沒有隱藏線）。
    pub lines: Vec<Line2>,
    /// 剖面線。
    pub hatch: Vec<(P2, P2)>,
}

/// Sutherland–Hodgman：保留 `(p − origin)·n ≤ 0` 那一側。
fn clip_ring(ring: &[P2], origin: P2, n: P2) -> Vec<P2> {
    let side = |p: P2| (p.0 - origin.0) * n.0 + (p.1 - origin.1) * n.1;
    let mut out = Vec::new();
    let m = ring.len();
    for i in 0..m {
        let (a, b) = (ring[i], ring[(i + 1) % m]);
        let (sa, sb) = (side(a), side(b));
        if sa <= 0.0 {
            out.push(a);
        }
        if (sa < 0.0 && sb > 0.0) || (sa > 0.0 && sb < 0.0) {
            let t = sa / (sa - sb);
            out.push((a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t));
        }
    }
    out
}

fn rotate_about(p: P2, pivot: P2, angle: f32) -> P2 {
    let r = geom::rotate((p.0 - pivot.0, p.1 - pivot.1), angle);
    (pivot.0 + r.0, pivot.1 + r.1)
}

/// 投影到畫面上的切口矩形 `(u0, u1, v0, v1)`。
#[derive(Clone, Copy, Debug)]
struct Rect {
    u0: f32,
    u1: f32,
    v0: f32,
    v1: f32,
}

fn rect_ring(r: &Rect) -> Vec<P2> {
    vec![(r.u0, r.v0), (r.u1, r.v0), (r.u1, r.v1), (r.u0, r.v1)]
}

/// 合併相接的矩形（階梯剖面兩段切口在轉折處相接，那裡不該有線）。
fn merge_rects(mut rects: Vec<Rect>, tol: f32) -> Vec<Rect> {
    rects.sort_by(|a, b| {
        (a.v0, a.v1, a.u0)
            .partial_cmp(&(b.v0, b.v1, b.u0))
            .unwrap_or(std::cmp::Ordering::Equal)
    });
    let mut out: Vec<Rect> = Vec::new();
    // 先按 v 範圍分群、再按 u 排序合併；也處理「u 範圍相同、v 相接」（垂直方向的階梯）。
    for r in rects {
        if let Some(last) = out.last_mut() {
            let same_v = (last.v0 - r.v0).abs() < tol && (last.v1 - r.v1).abs() < tol;
            if same_v && r.u0 <= last.u1 + tol {
                last.u1 = last.u1.max(r.u1);
                continue;
            }
        }
        out.push(r);
    }
    // 第二輪：u 範圍相同、v 相接。
    out.sort_by(|a, b| {
        (a.u0, a.u1, a.v0)
            .partial_cmp(&(b.u0, b.u1, b.v0))
            .unwrap_or(std::cmp::Ordering::Equal)
    });
    let mut merged: Vec<Rect> = Vec::new();
    for r in out {
        if let Some(last) = merged.last_mut() {
            let same_u = (last.u0 - r.u0).abs() < tol && (last.u1 - r.u1).abs() < tol;
            if same_u && r.v0 <= last.v1 + tol {
                last.v1 = last.v1.max(r.v1);
                continue;
            }
        }
        merged.push(r);
    }
    merged
}

/// 剖視圖。`hatch_spacing` 是剖面線的間距（頁面單位）。
pub fn section_view(solid: &Solid, cut: &Cut, hatch_spacing: f32) -> SectionView {
    let cam = cut.camera();
    let depth = solid.depth;
    let dims = solid.dims();
    let size = dims[0].max(dims[1]).max(dims[2]).max(1.0);
    let tol = size * 1e-3;
    let angle = std::f32::consts::FRAC_PI_4;

    match cut {
        Cut::Parallel { .. } => {
            // 切開之後從正面看：整個輪廓就是切口，後面什麼也看不到。
            let rings = solid.profile.rings();
            let mut lines = Vec::new();
            for r in &rings {
                let n = r.len();
                for i in 0..n {
                    lines.push(Line2 {
                        a: r[i],
                        b: r[(i + 1) % n],
                        hidden: false,
                    });
                }
            }
            SectionView {
                camera: cam,
                lines,
                hatch: geom::hatch(&rings, angle, hatch_spacing),
            }
        }
        Cut::Path { legs, viewer } => {
            // 切口矩形（含旋轉剖面的展開）。
            let mut walls: Vec<(P2, P2)> = Vec::new(); // 展開後的牆底線兩端
            for leg in legs.iter().filter(|l| !l.connector) {
                let len = geom::dist(leg.a, leg.b);
                if len < 1e-6 {
                    continue;
                }
                let dir = ((leg.b.0 - leg.a.0) / len, (leg.b.1 - leg.a.1) / len);
                for (t0, t1) in geom::line_inside_intervals(leg.a, dir, &solid.profile.rings()) {
                    let (t0, t1) = (t0.max(0.0), t1.min(len));
                    if t1 - t0 <= 1e-4 {
                        continue;
                    }
                    let mut p0 = (leg.a.0 + dir.0 * t0, leg.a.1 + dir.1 * t0);
                    let mut p1 = (leg.a.0 + dir.0 * t1, leg.a.1 + dir.1 * t1);
                    if let Some(u) = leg.unfold {
                        p0 = rotate_about(p0, u.pivot, u.angle);
                        p1 = rotate_about(p1, u.pivot, u.angle);
                    }
                    walls.push((p0, p1));
                }
            }
            let rects: Vec<Rect> = walls
                .iter()
                .map(|(p0, p1)| {
                    let corners = [
                        cam.project([p0.0, p0.1, 0.0]),
                        cam.project([p1.0, p1.1, 0.0]),
                        cam.project([p1.0, p1.1, -depth]),
                        cam.project([p0.0, p0.1, -depth]),
                    ];
                    let (lo, hi) = geom::bounds(&corners).unwrap_or(((0.0, 0.0), (0.0, 0.0)));
                    Rect {
                        u0: lo.0,
                        u1: hi.0,
                        v0: lo.1,
                        v1: hi.1,
                    }
                })
                .collect();
            let rects = merge_rects(rects, tol);

            let mut hatch = Vec::new();
            for r in &rects {
                hatch.extend(geom::hatch(&[&rect_ring(r)], angle, hatch_spacing));
            }

            let single = legs.len() == 1 && !legs[0].connector && legs[0].unfold.is_none();
            let lines = if single {
                beyond_view(solid, &legs[0], *viewer, &cam, size)
            } else {
                // 階梯與旋轉：只畫切口的外框（切口後面的形狀依製圖慣例由使用者補）。
                let mut v = Vec::new();
                for r in &rects {
                    let ring = rect_ring(r);
                    for i in 0..4 {
                        v.push(Line2 {
                            a: ring[i],
                            b: ring[(i + 1) % 4],
                            hidden: false,
                        });
                    }
                }
                v
            };
            SectionView {
                camera: cam,
                lines,
                hatch,
            }
        }
    }
}

/// 單一平面全剖面：切掉靠觀看者那一半，投影剩下的那一半（含切口牆）。
fn beyond_view(solid: &Solid, leg: &Leg, viewer: P2, cam: &Camera, size: f32) -> Vec<Line2> {
    let depth = solid.depth;
    let origin = leg.a;
    let on_line =
        |p: P2| ((p.0 - origin.0) * viewer.0 + (p.1 - origin.1) * viewer.1).abs() < size * 1e-3;

    let rings: Vec<Vec<P2>> = solid
        .profile
        .rings()
        .into_iter()
        .map(|r| clip_ring(r, origin, viewer))
        .filter(|r| r.len() >= 3)
        .collect();
    let mut mesh = mesh_from_rings(&rings, depth, &|p, q| on_line(p) && on_line(q));
    if mesh.faces.is_empty() {
        return Vec::new();
    }

    // 切口牆：只在實體有材料的區間。
    let len = geom::dist(leg.a, leg.b).max(1e-6);
    let dir = ((leg.b.0 - leg.a.0) / len, (leg.b.1 - leg.a.1) / len);
    for (t0, t1) in geom::line_inside_intervals(leg.a, dir, &solid.profile.rings()) {
        let (t0, t1) = (t0.max(0.0), t1.min(len));
        if t1 - t0 <= 1e-4 {
            continue;
        }
        let p0 = (leg.a.0 + dir.0 * t0, leg.a.1 + dir.1 * t0);
        let p1 = (leg.a.0 + dir.0 * t1, leg.a.1 + dir.1 * t1);
        let normal: P3 = [viewer.0, viewer.1, 0.0];
        let w = mesh.faces.len();
        mesh.faces.push(Face {
            rings: vec![vec![
                [p0.0, p0.1, 0.0],
                [p1.0, p1.1, 0.0],
                [p1.0, p1.1, -depth],
                [p0.0, p0.1, -depth],
            ]],
            normal,
            plane_d: viewer.0 * origin.0 + viewer.1 * origin.1,
            kind: FaceKind::Side,
        });
        mesh.edges.push(Edge {
            a: [p0.0, p0.1, 0.0],
            b: [p1.0, p1.1, 0.0],
            faces: [0, w],
            always: true,
        });
        mesh.edges.push(Edge {
            a: [p0.0, p0.1, -depth],
            b: [p1.0, p1.1, -depth],
            faces: [1, w],
            always: true,
        });
        mesh.edges.push(Edge {
            a: [p0.0, p0.1, 0.0],
            b: [p0.0, p0.1, -depth],
            faces: [w, w],
            always: true,
        });
        mesh.edges.push(Edge {
            a: [p1.0, p1.1, 0.0],
            b: [p1.0, p1.1, -depth],
            faces: [w, w],
            always: true,
        });
    }

    let v: View = project_mesh(&mesh, cam, size);
    v.lines.into_iter().filter(|l| !l.hidden).collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::solid::preset;

    fn washer() -> Solid {
        Solid::new(preset("ring", 60.0, 60.0).unwrap(), 20.0)
    }

    fn in_hole(p: P2) -> bool {
        // 洞的半徑是 15、圓心 (30, 30)。
        geom::dist(p, (30.0, 30.0)) < 14.5
    }

    #[test]
    fn a_vertical_full_section_hatches_only_where_there_is_material() {
        // 沿 x = 30 切（angle 90°、offset 0.5），翻面從 +X 看：右側視圖的方向。
        let s = washer();
        let cut = Cut::full(&s, 90.0, 0.5, true);
        let sv = section_view(&s, &cut, 2.0);
        assert!(!sv.hatch.is_empty());
        // 右視圖：u = −z（0…20）、v = y。洞在 y ∈ (15, 45)，剖面線不能出現在那裡。
        for (a, b) in &sv.hatch {
            for p in [a, b] {
                assert!(p.0 > -0.01 && p.0 < 20.01, "u 超出深度範圍：{p:?}");
                assert!(p.1 < 15.01 || p.1 > 44.99, "剖面線跑進洞裡：{p:?}");
            }
        }
        // 兩塊材料（y 0…15 與 45…60）都有剖面線。
        assert!(sv.hatch.iter().any(|(a, _)| a.1 < 15.0));
        assert!(sv.hatch.iter().any(|(a, _)| a.1 > 45.0));
    }

    #[test]
    fn the_section_view_has_no_hidden_lines() {
        let s = washer();
        let sv = section_view(&s, &Cut::full(&s, 90.0, 0.5, true), 2.0);
        assert!(sv.lines.iter().all(|l| !l.hidden));
        // 兩塊切口：上下各兩條橫線 + 左右兩條貫穿的直線（孔的內壁輪廓接在中間）。
        assert_eq!(sv.lines.len(), 6, "{:?}", sv.lines);
    }

    #[test]
    fn viewing_from_the_other_side_mirrors_the_section() {
        let s = washer();
        let right = section_view(&s, &Cut::full(&s, 90.0, 0.5, false), 2.0);
        let left = section_view(&s, &Cut::full(&s, 90.0, 0.5, true), 2.0);
        assert!(!left.hatch.is_empty());
        assert!(left.camera != right.camera);
        // 兩邊剖面線的總長一樣：只是鏡射。
        let total = |sv: &SectionView| {
            sv.hatch
                .iter()
                .map(|(a, b)| geom::dist(*a, *b))
                .sum::<f32>()
        };
        assert!((total(&left) - total(&right)).abs() < 1.0);
    }

    #[test]
    fn a_parallel_section_hatches_the_profile_without_the_hole() {
        let s = washer();
        let sv = section_view(&s, &Cut::parallel(&s, 0.5), 2.0);
        assert!(!sv.hatch.is_empty());
        for (a, b) in &sv.hatch {
            for p in [a, b] {
                assert!(!in_hole(*p), "剖面線跑進洞裡：{p:?}");
            }
        }
        // 外框 + 洞的外框都看得見。
        assert_eq!(sv.lines.len(), 96);
    }

    #[test]
    fn a_stepped_section_merges_the_cut_across_the_step() {
        // 四個孔的板子：先沿 x = 0.25w 切到 y = 0.5h，再轉到 x = 0.75w 切到頂。
        let s = Solid::new(preset("plate_holes", 80.0, 60.0).unwrap(), 10.0);
        let (w, _h) = s.profile.size();
        let off1 = 0.25;
        let off2 = 0.75;
        let cut = Cut::stepped(&s, 90.0, off1, off2, 0.5, false);
        // 轉折段不產生切口，總共三條切口矩形：
        // [0, 0.3h−r]、[0.3h+r, 0.7h−r]（跨過轉折處合併）、[0.7h+r, h]。
        let sv = section_view(&s, &cut, 3.0);
        // 每個矩形 4 條邊，合併後的線條數 = 3 × 4。
        assert_eq!(sv.lines.len(), 12, "{:?}", sv.lines);
        assert!(w > 0.0);
        assert!(!sv.hatch.is_empty());
    }

    #[test]
    fn a_rotated_section_unfolds_the_second_leg_onto_the_first() {
        // 一個長方塊，以中心為轉軸、第二段轉 30°。
        let s = Solid::new(preset("rect", 80.0, 60.0).unwrap(), 10.0);
        let cut = Cut::rotated(&s, 90.0, (0.5, 0.5), 30.0, false);
        let sv = section_view(&s, &cut, 3.0);
        assert!(!sv.hatch.is_empty());
        // 展開之後兩段接成一條連續的切口，總長 ≈ 第一段 30 + 第二段 30/cos(30°)（斜向穿過方塊）。
        let (lo, hi) =
            geom::bounds(&sv.lines.iter().flat_map(|l| [l.a, l.b]).collect::<Vec<_>>()).unwrap();
        let vspan = hi.1 - lo.1;
        assert!(vspan > 55.0, "展開後的切口長度 {vspan}");
        // 連續：只有一個矩形（外框 4 條線）。
        assert_eq!(sv.lines.len(), 4, "{:?}", sv.lines);
    }

    #[test]
    fn a_cut_beyond_the_solid_removes_it_or_shows_it_whole() {
        let s = Solid::new(preset("rect", 40.0, 30.0).unwrap(), 10.0);
        let far = |viewer: P2| Cut::Path {
            legs: vec![Leg {
                a: (500.0, -100.0),
                b: (500.0, 100.0),
                connector: false,
                unfold: None,
            }],
            viewer,
        };
        // 觀看者在切面外側（+X，物體在 x < 500）：整個物體都在切面後面，原樣看得到，沒有切口。
        let whole = section_view(&s, &far((1.0, 0.0)), 2.0);
        assert!(whole.hatch.is_empty());
        assert_eq!(whole.lines.len(), 4);
        // 觀看者在另一側：整個物體被移走，什麼都沒有。
        let gone = section_view(&s, &far((-1.0, 0.0)), 2.0);
        assert!(gone.lines.is_empty() && gone.hatch.is_empty());
    }

    #[test]
    fn the_cut_line_shows_up_on_the_front_view() {
        let s = washer();
        let cut = Cut::full(&s, 90.0, 0.5, false);
        let lines = cut.plan_lines();
        assert_eq!(lines.len(), 1);
        let (a, b) = lines[0];
        assert!(
            (a.0 - 30.0).abs() < 0.01 && (b.0 - 30.0).abs() < 0.01,
            "垂直線 x = 30"
        );
    }

    #[test]
    fn camera_directions_match_the_standard_views() {
        assert_eq!(
            camera_for_dir((1.0, 0.0)),
            Camera::standard(StandardView::Right)
        );
        assert_eq!(
            camera_for_dir((-1.0, 0.0)),
            Camera::standard(StandardView::Left)
        );
        assert_eq!(
            camera_for_dir((0.0, 1.0)),
            Camera::standard(StandardView::Top)
        );
        assert_eq!(
            camera_for_dir((0.0, -1.0)),
            Camera::standard(StandardView::Bottom)
        );
    }
}
