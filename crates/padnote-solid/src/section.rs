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
//! 立體是柱體，所以切面分三種：**平行於輪廓**（正視圖方向的全剖面）、
//! **垂直於輪廓**（沿著 XY 平面上的一條折線切下去，包含全剖、階梯、旋轉三種），
//! 以及**斜切面**（[`Cut::Oblique`]：切面含有 XY 平面上的一個方向，並繞它傾斜 —— 同時斜向深度與輪廓）。
//!
//! 斜切面的剖視圖是**實形**：沿著切面的法向量看，切口（畫剖面線）是這個切面截出來的真實形狀，
//! 切口後面看得見的東西也一併畫出。做法是把柱體的網格直接用平面裁掉，不需要通用的布林運算。

use crate::geom::{self, P2, P3};
use crate::solid::{Edge, Face, FaceKind, Solid, mesh_from_rings_ex};
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
    /// 斜切面：通過 `point`、法向量 `normal`（單位向量，指向觀看者）的平面。
    /// 觀看者那一側被移走，沿 `normal` 的反方向看切口（實形）。
    Oblique { point: P3, normal: P3 },
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

    /// 斜切面：切線在 XY 平面上的方向 `angle_deg`、位置 `offset`（0…1）與 [`Cut::full`] 相同，
    /// 再讓切面繞這條切線**傾斜** `tilt_deg`：0° 就是垂直於輪廓的全剖面，90° 是平行於輪廓的剖面，
    /// 中間就是斜切面。平面一律通過深度的正中央。
    pub fn oblique(solid: &Solid, angle_deg: f32, offset: f32, tilt_deg: f32, flip: bool) -> Cut {
        let tilt = tilt_deg.clamp(0.0, 90.0);
        if tilt < 0.25 {
            return Cut::full(solid, angle_deg, offset, flip);
        }
        if tilt > 89.75 {
            return Cut::parallel(solid, 0.5);
        }
        let (_, n) = unit(angle_deg);
        let (lo, hi) = extent_along(solid, n);
        let s = lo + (hi - lo) * offset.clamp(0.0, 1.0);
        let t = tilt.to_radians();
        let mut normal = [n.0 * t.cos(), n.1 * t.cos(), t.sin()];
        let point = [n.0 * s, n.1 * s, -solid.depth * 0.5];
        if flip {
            normal = [-normal[0], -normal[1], -normal[2]];
        }
        Cut::Oblique { point, normal }
    }

    /// 切面在 XY 平面上的「觀看方向」：路徑切面是 `viewer`，斜切面是法向量的水平分量。
    pub fn trace_viewer(&self) -> Option<P2> {
        match self {
            Cut::Parallel { .. } => None,
            Cut::Path { viewer, .. } => Some(*viewer),
            Cut::Oblique { normal, .. } => {
                let l = (normal[0] * normal[0] + normal[1] * normal[1]).sqrt();
                (l > 1e-6).then_some((normal[0] / l, normal[1] / l))
            }
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
            Cut::Oblique { point, normal } => {
                // 切面含有的水平方向：垂直於法向量的水平分量。畫一條夠長的線，排版時再裁到視圖範圍內。
                let l = (normal[0] * normal[0] + normal[1] * normal[1])
                    .sqrt()
                    .max(1e-6);
                let dir = (normal[1] / l, -normal[0] / l);
                const REACH: f32 = 1.0e4;
                vec![(
                    (point[0] - dir.0 * REACH, point[1] - dir.1 * REACH),
                    (point[0] + dir.0 * REACH, point[1] + dir.1 * REACH),
                )]
            }
        }
    }

    /// 剖視圖用的攝影機。
    pub fn camera(&self) -> Camera {
        match self {
            Cut::Parallel { .. } => Camera::standard(StandardView::Front),
            Cut::Path { viewer, .. } => camera_for_dir(*viewer),
            Cut::Oblique { normal, .. } => camera_for_normal(*normal),
        }
    }
}

/// 沿著這個法向量（從物體指向觀看者）看過去的攝影機。
pub fn camera_for_normal(n: P3) -> Camera {
    let l = (n[0] * n[0] + n[1] * n[1] + n[2] * n[2]).sqrt().max(1e-9);
    let (x, y, z) = (n[0] / l, n[1] / l, n[2] / l);
    let pitch = y.clamp(-1.0, 1.0).asin().to_degrees();
    if pitch > 89.5 {
        return Camera::standard(StandardView::Top);
    }
    if pitch < -89.5 {
        return Camera::standard(StandardView::Bottom);
    }
    Camera {
        yaw: x.atan2(z).to_degrees(),
        pitch,
        scale: 1.0,
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
        Cut::Oblique { point, normal } => {
            oblique_view(solid, *point, *normal, hatch_spacing, &cam, size)
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

            // 切口後面的形狀：單一平面、階梯、旋轉都走同一條路（拆成「片」，各管一塊實體）。
            let lines = beyond_path(solid, legs, *viewer, &cam, size);
            SectionView {
                camera: cam,
                lines,
                hatch,
            }
        }
    }
}

fn dot3(a: P3, b: P3) -> f32 {
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
}

/// 把一個三維環裁到 `n·p ≤ c` 那一側（Sutherland–Hodgman）。
fn clip_ring3(ring: &[P3], n: P3, c: f32) -> Vec<P3> {
    let side = |p: P3| dot3(n, p) - c;
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
            out.push([
                a[0] + (b[0] - a[0]) * t,
                a[1] + (b[1] - a[1]) * t,
                a[2] + (b[2] - a[2]) * t,
            ]);
        }
    }
    out
}

/// 用平面裁掉網格：保留 `n·p ≤ c` 那一側。完全被裁掉的面連同它的邊一起消失，
/// 邊只留在還在的那一段。切口（新的面）由呼叫端補上。
fn clip_mesh(mesh: &crate::solid::Mesh, n: P3, c: f32) -> crate::solid::Mesh {
    let mut map: Vec<Option<usize>> = vec![None; mesh.faces.len()];
    let mut faces: Vec<Face> = Vec::new();
    for (i, f) in mesh.faces.iter().enumerate() {
        let mut rings: Vec<Vec<P3>> = Vec::new();
        for (idx, r) in f.rings.iter().enumerate() {
            let cur = clip_ring3(r, n, c);
            if cur.len() >= 3 {
                rings.push(cur);
            } else if idx == 0 {
                rings.clear();
                break;
            }
        }
        if rings.is_empty() {
            continue;
        }
        map[i] = Some(faces.len());
        faces.push(Face {
            rings,
            normal: f.normal,
            plane_d: f.plane_d,
            kind: f.kind,
        });
    }
    let mut edges: Vec<Edge> = Vec::new();
    for e in &mesh.edges {
        let (Some(f0), Some(f1)) = (map[e.faces[0]], map[e.faces[1]]) else {
            continue;
        };
        let (sa, sb) = (dot3(n, e.a) - c, dot3(n, e.b) - c);
        if sa > 0.0 && sb > 0.0 {
            continue;
        }
        let lerp = |t: f32| -> P3 {
            [
                e.a[0] + (e.b[0] - e.a[0]) * t,
                e.a[1] + (e.b[1] - e.a[1]) * t,
                e.a[2] + (e.b[2] - e.a[2]) * t,
            ]
        };
        let (a, b) = if sa <= 0.0 && sb <= 0.0 {
            (e.a, e.b)
        } else if sa <= 0.0 {
            (e.a, lerp(sa / (sa - sb)))
        } else {
            (lerp(sa / (sa - sb)), e.b)
        };
        edges.push(Edge {
            a,
            b,
            faces: [f0, f1],
            always: e.always,
        });
    }
    crate::solid::Mesh { faces, edges }
}

/// 斜切面的剖視圖：沿著切面法向量看，切口是實形，切口後面看得見的東西一併畫出。
fn oblique_view(
    solid: &Solid,
    point: P3,
    normal: P3,
    hatch_spacing: f32,
    cam: &Camera,
    size: f32,
) -> SectionView {
    let l = dot3(normal, normal).sqrt().max(1e-9);
    let n = [normal[0] / l, normal[1] / l, normal[2] / l];
    let c = dot3(n, point);
    let depth = solid.depth;

    // 切口：輪廓上「平面落在 0 ≥ z ≥ −depth」的那一塊，再抬到平面上。
    // 平面高度 z(x, y) = (c − n_xy·p) / n_z 是 (x, y) 的仿射函數，兩個不等式各是一個半平面。
    let mut cut_rings3: Vec<Vec<P3>> = Vec::new();
    if n[2].abs() > 1e-6 {
        let bx = (n[0] / n[2], n[1] / n[2]);
        let alpha = c / n[2];
        // g1 = z ≤ 0 → alpha − b·p ≤ 0；g2 = −depth − z ≤ 0 → −depth − alpha + b·p ≤ 0。
        let halves = [(alpha, (-bx.0, -bx.1)), (-depth - alpha, bx)];
        'rings: for (idx, ring) in solid.profile.rings().into_iter().enumerate() {
            let mut cur = ring.to_vec();
            for (a0, beta) in halves {
                let bb = (beta.0 * beta.0 + beta.1 * beta.1).max(1e-12);
                let origin = (-a0 * beta.0 / bb, -a0 * beta.1 / bb);
                cur = clip_ring(&cur, origin, beta);
            }
            if cur.len() >= 3 {
                cut_rings3.push(
                    cur.iter()
                        .map(|p| [p.0, p.1, (c - n[0] * p.0 - n[1] * p.1) / n[2]])
                        .collect(),
                );
            } else if idx == 0 {
                cut_rings3.clear();
                break 'rings;
            }
        }
    }

    let mut mesh = clip_mesh(&solid.mesh(), n, c);
    if mesh.faces.is_empty() && cut_rings3.is_empty() {
        return SectionView {
            camera: *cam,
            lines: Vec::new(),
            hatch: Vec::new(),
        };
    }
    if !cut_rings3.is_empty() {
        let w = mesh.faces.len();
        for ring in &cut_rings3 {
            let m = ring.len();
            for i in 0..m {
                mesh.edges.push(Edge {
                    a: ring[i],
                    b: ring[(i + 1) % m],
                    faces: [w, w],
                    always: true,
                });
            }
        }
        mesh.faces.push(Face {
            rings: cut_rings3.clone(),
            normal: n,
            plane_d: c,
            kind: FaceKind::Side,
        });
    }

    let view = project_mesh(&mesh, cam, size);
    let rings2: Vec<Vec<P2>> = cut_rings3
        .iter()
        .map(|r| r.iter().map(|p| cam.project(*p)).collect())
        .collect();
    let refs: Vec<&[P2]> = rings2.iter().map(|r| r.as_slice()).collect();
    SectionView {
        camera: *cam,
        lines: view.lines.into_iter().filter(|l| !l.hidden).collect(),
        hatch: if refs.is_empty() {
            Vec::new()
        } else {
            geom::hatch(&refs, std::f32::consts::FRAC_PI_4, hatch_spacing)
        },
    }
}

/// 一段切口（非轉折段）與它負責的那一塊實體。
struct Piece {
    leg: Leg,
    /// 這一段切面朝向觀看者的法向量（旋轉剖面的第二段是第一段轉過來的）。
    #[allow(dead_code)]
    normal: P2,
    /// 保留 `(p − origin)·n ≤ 0` 那一側的半平面：自己的切面，加上與相鄰片的分界。
    clips: Vec<(P2, P2)>,
    /// `clips` 裡屬於「與相鄰片的分界」的那幾個（第一個是自己的切面，不在這裡）。
    lateral: Vec<(P2, P2)>,
}

fn unit2(v: P2) -> P2 {
    let l = (v.0 * v.0 + v.1 * v.1).sqrt().max(1e-9);
    (v.0 / l, v.1 / l)
}

fn on_line(p: P2, origin: P2, n: P2, tol: f32) -> bool {
    ((p.0 - origin.0) * n.0 + (p.1 - origin.1) * n.1).abs() < tol
}

/// 切面路徑拆成「片」。
///
/// - **階梯**：兩段切口之間有轉折段，分界線是轉折段所在、垂直於切口方向的那條線。
/// - **旋轉**：兩段切口相交於轉軸，分界線是兩個法向量的角平分線 ——
///   每一塊實體歸離它較近的那一段切面管。
fn pieces(legs: &[Leg], viewer: P2) -> Vec<Piece> {
    let cuts: Vec<usize> = (0..legs.len()).filter(|&i| !legs[i].connector).collect();
    let normal_of = |l: &Leg| match l.unfold {
        Some(u) => geom::rotate(viewer, -u.angle),
        None => viewer,
    };
    let dir_of = |l: &Leg| unit2((l.b.0 - l.a.0, l.b.1 - l.a.1));
    // 回傳 (前一片保留的半平面, 後一片保留的半平面)。
    let boundary = |p: usize, q: usize| -> ((P2, P2), (P2, P2)) {
        if q > p + 1 {
            // 有轉折段：用轉折段的位置當分界。
            let c = legs[p + 1];
            let dp = dir_of(&legs[p]);
            let dq = dir_of(&legs[q]);
            ((c.a, dp), (c.a, (-dq.0, -dq.1)))
        } else {
            let pv = legs[p].b;
            let (np, nq) = (normal_of(&legs[p]), normal_of(&legs[q]));
            let sum = (np.0 + nq.0, np.1 + nq.1);
            let m = if sum.0 * sum.0 + sum.1 * sum.1 < 1e-8 {
                np
            } else {
                unit2(sum)
            };
            let mut w = (-m.1, m.0);
            let start = legs[p].a;
            if (start.0 - pv.0) * w.0 + (start.1 - pv.1) * w.1 > 0.0 {
                w = (-w.0, -w.1);
            }
            ((pv, w), (pv, (-w.0, -w.1)))
        }
    };
    let mut out = Vec::new();
    for (k, &i) in cuts.iter().enumerate() {
        let leg = legs[i];
        let n = normal_of(&leg);
        let mut clips = vec![(leg.a, n)];
        let mut lateral = Vec::new();
        if k > 0 {
            lateral.push(boundary(cuts[k - 1], i).1);
        }
        if k + 1 < cuts.len() {
            lateral.push(boundary(i, cuts[k + 1]).0);
        }
        clips.extend(lateral.iter().copied());
        out.push(Piece {
            leg,
            normal: n,
            clips,
            lateral,
        });
    }
    out
}

/// 繞 z 軸（過 `pivot`）轉整個網格。
fn rotate_mesh(mesh: &mut crate::solid::Mesh, pivot: P2, angle: f32) {
    let rot = |p: P3| -> P3 {
        let r = rotate_about((p[0], p[1]), pivot, angle);
        [r.0, r.1, p[2]]
    };
    for f in &mut mesh.faces {
        for ring in &mut f.rings {
            for v in ring.iter_mut() {
                *v = rot(*v);
            }
        }
        let n = geom::rotate((f.normal[0], f.normal[1]), angle);
        f.normal = [n.0, n.1, f.normal[2]];
        if let Some(v) = f.rings.first().and_then(|r| r.first()) {
            f.plane_d = f.normal[0] * v[0] + f.normal[1] * v[1] + f.normal[2] * v[2];
        }
    }
    for e in &mut mesh.edges {
        e.a = rot(e.a);
        e.b = rot(e.b);
    }
}

/// 切口後面看得見的線：單一平面、階梯、旋轉剖面都走這裡。
///
/// 每一段切口各自保留「在它後面」的那塊實體（階梯與旋轉剖面還要用分界線把實體分給各段），
/// 旋轉剖面的第二塊再轉回與第一段同一個平面；然後把切口牆補上、一起做隱藏線消除。
fn beyond_path(solid: &Solid, legs: &[Leg], viewer: P2, cam: &Camera, size: f32) -> Vec<Line2> {
    let depth = solid.depth;
    let tol = size * 1e-3;
    let mut mesh = crate::solid::Mesh {
        faces: Vec::new(),
        edges: Vec::new(),
    };
    let pcs = pieces(legs, viewer);

    for pc in &pcs {
        // 外環先被切光，剩下的洞就沒有意義。
        let mut rings: Vec<Vec<P2>> = Vec::new();
        for (idx, r) in solid.profile.rings().into_iter().enumerate() {
            let mut cur = r.to_vec();
            for &(o, n) in &pc.clips {
                cur = clip_ring(&cur, o, n);
            }
            if cur.len() >= 3 {
                rings.push(cur);
            } else if idx == 0 {
                rings.clear();
                break;
            }
        }
        if rings.is_empty() {
            continue;
        }
        // 切面與分界線上的邊不產生側壁：切口牆另外補，分界處不畫線。
        let skip = |p: P2, q: P2| {
            pc.clips
                .iter()
                .any(|&(o, n)| on_line(p, o, n, tol) && on_line(q, o, n, tol))
        };
        // 分界線上人為切出來的頂點不畫垂直線；真的轉角（原輪廓的頂點）照畫。
        let quiet = |p: P2| {
            pc.lateral.iter().any(|&(o, n)| on_line(p, o, n, tol))
                && !solid
                    .profile
                    .rings()
                    .iter()
                    .any(|r| r.iter().any(|v| geom::dist(*v, p) < tol * 2.0))
        };
        let mut piece = mesh_from_rings_ex(&rings, depth, &skip, &quiet);
        if let Some(u) = pc.leg.unfold {
            rotate_mesh(&mut piece, u.pivot, u.angle);
        }
        let offset = mesh.faces.len();
        mesh.faces.extend(piece.faces);
        mesh.edges.extend(piece.edges.into_iter().map(|mut e| {
            e.faces = [e.faces[0] + offset, e.faces[1] + offset];
            e
        }));
    }
    if mesh.faces.is_empty() {
        return Vec::new();
    }

    // 切口牆：只在實體有材料的區間，旋轉剖面的第二段先轉回第一段的平面。
    struct Wall {
        p0: P2,
        p1: P2,
        t0: f32,
        t1: f32,
    }
    let first = pcs.first().map(|p| p.leg).unwrap_or(legs[0]);
    let axis = unit2((first.b.0 - first.a.0, first.b.1 - first.a.1));
    let along = |p: P2| (p.0 - first.a.0) * axis.0 + (p.1 - first.a.1) * axis.1;
    let mut walls: Vec<Wall> = Vec::new();
    for pc in &pcs {
        let leg = pc.leg;
        let len = geom::dist(leg.a, leg.b).max(1e-6);
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
            let (a, b) = (along(p0), along(p1));
            walls.push(Wall {
                p0,
                p1,
                t0: a.min(b),
                t1: a.max(b),
            });
        }
    }
    for (i, wl) in walls.iter().enumerate() {
        let w = mesh.faces.len();
        let d = depth;
        mesh.faces.push(Face {
            rings: vec![vec![
                [wl.p0.0, wl.p0.1, 0.0],
                [wl.p1.0, wl.p1.1, 0.0],
                [wl.p1.0, wl.p1.1, -d],
                [wl.p0.0, wl.p0.1, -d],
            ]],
            normal: [viewer.0, viewer.1, 0.0],
            plane_d: viewer.0 * wl.p0.0 + viewer.1 * wl.p0.1,
            kind: FaceKind::Side,
        });
        let mut edge = |a: P3, b: P3| {
            mesh.edges.push(Edge {
                a,
                b,
                faces: [w, w],
                always: true,
            })
        };
        edge([wl.p0.0, wl.p0.1, 0.0], [wl.p1.0, wl.p1.1, 0.0]);
        edge([wl.p0.0, wl.p0.1, -d], [wl.p1.0, wl.p1.1, -d]);
        // 與相鄰切口牆相接的那一端（階梯的轉折、旋轉的轉軸）不畫豎線：整體是同一個切面。
        let joined_start = walls
            .iter()
            .enumerate()
            .any(|(j, o)| j != i && (o.t1 - wl.t0).abs() < tol);
        let joined_end = walls
            .iter()
            .enumerate()
            .any(|(j, o)| j != i && (o.t0 - wl.t1).abs() < tol);
        let (lo, hi) = if along(wl.p0) <= along(wl.p1) {
            (wl.p0, wl.p1)
        } else {
            (wl.p1, wl.p0)
        };
        if !joined_start {
            edge([lo.0, lo.1, 0.0], [lo.0, lo.1, -d]);
        }
        if !joined_end {
            edge([hi.0, hi.1, 0.0], [hi.0, hi.1, -d]);
        }
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
        // 轉折段不產生切口，三塊切口合起來是一個連續的區域，轉折處（y = 30）不畫線：
        // [0, 0.3h−r]、[0.3h+r, 0.7h−r]（跨過轉折處合併）、[0.7h+r, h]。
        let sv = section_view(&s, &cut, 3.0);
        let horizontals: Vec<f32> = sv
            .lines
            .iter()
            .filter(|l| (l.a.1 - l.b.1).abs() < 1e-3)
            .map(|l| l.a.1)
            .collect();
        // 上下緣 + 四個孔的上下緣，一共六條橫線；沒有轉折處那一條。
        assert_eq!(horizontals.len(), 6, "{:?}", sv.lines);
        assert!(
            horizontals.iter().all(|y| (y - 30.0).abs() > 1.0),
            "轉折處不該有線：{horizontals:?}"
        );
        // 孔的位置沒有切口，空隙裡看到的是切口後面那塊板子：左右兩條貫穿全高的豎線。
        let tall = sv
            .lines
            .iter()
            .filter(|l| (l.a.0 - l.b.0).abs() < 1e-3 && (l.a.1 - l.b.1).abs() > 59.0)
            .count();
        assert_eq!(tall, 2, "{:?}", sv.lines);
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

    fn sorted_lines(sv: &SectionView) -> Vec<(i32, i32, i32, i32)> {
        let q = |v: f32| (v * 100.0).round() as i32;
        let mut v: Vec<(i32, i32, i32, i32)> = sv
            .lines
            .iter()
            .map(|l| {
                let (a, b) = if (l.a.0, l.a.1) <= (l.b.0, l.b.1) {
                    (l.a, l.b)
                } else {
                    (l.b, l.a)
                };
                (q(a.0), q(a.1), q(b.0), q(b.1))
            })
            .collect();
        v.sort_unstable();
        v
    }

    #[test]
    fn a_stepped_section_with_no_step_is_the_same_as_a_full_section() {
        // 兩段切口在同一個位置：階梯剖面退化成全剖面，看到的東西必須完全一樣。
        let s = Solid::new(preset("u_shape", 60.0, 60.0).unwrap(), 12.0);
        let full = section_view(&s, &Cut::full(&s, 90.0, 0.5, false), 2.0);
        let stepped = section_view(&s, &Cut::stepped(&s, 90.0, 0.5, 0.5, 0.5, false), 2.0);
        assert_eq!(sorted_lines(&full), sorted_lines(&stepped));
    }

    #[test]
    fn a_rotated_section_with_no_turn_is_the_same_as_a_full_section() {
        let s = Solid::new(preset("u_shape", 60.0, 60.0).unwrap(), 12.0);
        // 轉軸在 x = 0.5w（與全剖面同一條線），第二段不轉。
        let full = section_view(&s, &Cut::full(&s, 90.0, 0.5, false), 2.0);
        let rotated = section_view(&s, &Cut::rotated(&s, 90.0, (0.5, 0.5), 0.0, false), 2.0);
        assert_eq!(sorted_lines(&full), sorted_lines(&rotated));
    }

    #[test]
    fn a_stepped_section_shows_the_shape_behind_the_cut() {
        // U 形塊：槽在 x ∈ [0.3w, 0.7w]、y ∈ [0.35h, h]。先沿 x = 0.5w 切到 y = 0.6h（切在槽的正中央，
        // 只有槽底那一塊有材料），再轉到 x = 0.85w（右邊的臂）切到頂。
        // 槽的區間 y ∈ [0.35h, 0.6h] 沒有切口，從那裡看進去是槽的右壁 —— 以前階梯剖面不畫這個。
        let s = Solid::new(preset("u_shape", 60.0, 60.0).unwrap(), 12.0);
        let cut = Cut::stepped(&s, 90.0, 0.5, 0.85, 0.6, false);
        let sv = section_view(&s, &cut, 2.0);
        // 預期的六條線：上下緣、槽底（y = 21，切口的上緣）、轉折處（y = 36，右臂切口的下緣），
        // 再加上**貫穿全高的兩條豎線**。後者就是切口後面那塊槽右壁的左右兩邊 ——
        // 以前階梯剖面只畫切口外框，豎線在 y ∈ [21, 36] 這段是斷開的。
        let mut horizontals: Vec<i32> = sv
            .lines
            .iter()
            .filter(|l| (l.a.1 - l.b.1).abs() < 1e-3)
            .map(|l| l.a.1.round() as i32)
            .collect();
        horizontals.sort_unstable();
        assert_eq!(horizontals, vec![0, 21, 36, 60], "{:?}", sv.lines);
        let tall = sv
            .lines
            .iter()
            .filter(|l| (l.a.0 - l.b.0).abs() < 1e-3 && (l.a.1 - l.b.1).abs() > 59.9)
            .count();
        assert_eq!(tall, 2, "{:?}", sv.lines);
        // 沒有任何一條線重複兩次。
        let sorted = sorted_lines(&sv);
        let mut dedup = sorted.clone();
        dedup.dedup();
        assert_eq!(sorted, dedup, "有重複的線");
    }

    #[test]
    fn a_rotated_section_shows_the_shape_behind_the_cut_after_unfolding() {
        // U 形塊，轉軸在 (0.5w, 0.2h)，第二段轉 −30°。手算 / 逐項檢查過的結果：
        // 兩條貫穿全高的豎線、底邊與頂邊，加上切口與槽壁在展開後留下的橫線。
        let s = Solid::new(preset("u_shape", 60.0, 60.0).unwrap(), 12.0);
        let cut = Cut::rotated(&s, 90.0, (0.5, 0.2), -30.0, false);
        let sv = section_view(&s, &cut, 3.0);
        assert!(!sv.hatch.is_empty());
        assert_eq!(sv.lines.len(), 8, "{:?}", sv.lines);
        let (lo, hi) =
            geom::bounds(&sv.lines.iter().flat_map(|l| [l.a, l.b]).collect::<Vec<_>>()).unwrap();
        // 深度方向就是塊的厚度；展開後的長度方向比塊本身（60）更長，因為第二段是斜著穿過去的。
        assert!((hi.0 - lo.0 - 12.0).abs() < 0.1, "{lo:?} {hi:?}");
        assert!(hi.1 - lo.1 > 60.0, "{lo:?} {hi:?}");
        // 以前只畫切口外框：總共只有切口矩形的邊，現在多了切口後面的形狀。
        let tall = sv
            .lines
            .iter()
            .filter(|l| (l.a.0 - l.b.0).abs() < 1e-3 && (l.a.1 - l.b.1).abs() > hi.1 - lo.1 - 0.1)
            .count();
        assert_eq!(tall, 2, "貫穿全高的豎線");
    }

    fn hatch_bounds(sv: &SectionView) -> (P2, P2) {
        geom::bounds(&sv.hatch.iter().flat_map(|h| [h.0, h.1]).collect::<Vec<_>>()).unwrap()
    }

    #[test]
    fn an_oblique_cut_shows_the_true_shape_of_the_cut_face() {
        // 40 × 30 × 20 的塊，切面含 x 方向、繞它傾斜 45°、通過深度正中央：y + z = 5。
        // z ∈ [−20, 0] → y ∈ [5, 25]，切口是 40 寬、沿斜面長 20·√2 ≈ 28.28 的長方形（實形）。
        let s = Solid::new(preset("rect", 40.0, 30.0).unwrap(), 20.0);
        let cut = Cut::oblique(&s, 0.0, 0.5, 45.0, false);
        assert!(matches!(cut, Cut::Oblique { .. }));
        let sv = section_view(&s, &cut, 1.5);
        assert!(!sv.hatch.is_empty());
        let (lo, hi) = hatch_bounds(&sv);
        let (wu, wv) = (hi.0 - lo.0, hi.1 - lo.1);
        // 兩個方向一個是 40、一個是 28.28（哪個在水平方向看攝影機的朝向，兩個都對）。
        let (long, short) = (wu.max(wv), wu.min(wv));
        assert!((long - 40.0).abs() < 1.5, "{wu} × {wv}");
        assert!((short - 28.28).abs() < 1.5, "{wu} × {wv}");
    }

    #[test]
    fn an_oblique_cut_through_a_hole_does_not_hatch_the_hole() {
        // 墊圈：孔在中央。斜切面穿過孔，剖面線在孔的實形裡必須是空的 ——
        // 所以剖面線的段數比同樣大小、沒有孔的圓盤少。
        let washer = Solid::new(preset("ring", 60.0, 60.0).unwrap(), 20.0);
        let disc = Solid::new(preset("circle", 60.0, 60.0).unwrap(), 20.0);
        let a = section_view(&washer, &Cut::oblique(&washer, 0.0, 0.5, 40.0, false), 2.0);
        let b = section_view(&disc, &Cut::oblique(&disc, 0.0, 0.5, 40.0, false), 2.0);
        assert!(!a.hatch.is_empty() && !b.hatch.is_empty());
        let total = |sv: &SectionView| {
            sv.hatch
                .iter()
                .map(|(p, q)| geom::dist(*p, *q))
                .sum::<f32>()
        };
        assert!(
            total(&a) < total(&b) * 0.9,
            "{} vs {}",
            total(&a),
            total(&b)
        );
        // 孔的邊界在切口上也是線。
        assert!(a.lines.len() > b.lines.len() / 2);
    }

    #[test]
    fn the_extreme_tilts_fall_back_to_the_ordinary_cuts() {
        let s = Solid::new(preset("rect", 40.0, 30.0).unwrap(), 20.0);
        assert!(matches!(
            Cut::oblique(&s, 90.0, 0.5, 0.0, false),
            Cut::Path { .. }
        ));
        assert!(matches!(
            Cut::oblique(&s, 90.0, 0.5, 90.0, false),
            Cut::Parallel { .. }
        ));
        assert!(matches!(
            Cut::oblique(&s, 90.0, 0.5, 30.0, false),
            Cut::Oblique { .. }
        ));
    }

    #[test]
    fn flipping_an_oblique_cut_looks_from_the_other_side() {
        let s = Solid::new(preset("rect", 40.0, 30.0).unwrap(), 20.0);
        let a = section_view(&s, &Cut::oblique(&s, 0.0, 0.5, 45.0, false), 1.5);
        let b = section_view(&s, &Cut::oblique(&s, 0.0, 0.5, 45.0, true), 1.5);
        assert!(a.camera != b.camera);
        assert!(!b.hatch.is_empty());
        // 兩邊的切口實形一樣大。
        let (la, ha) = hatch_bounds(&a);
        let (lb, hb) = hatch_bounds(&b);
        let area = |lo: P2, hi: P2| (hi.0 - lo.0) * (hi.1 - lo.1);
        assert!((area(la, ha) - area(lb, hb)).abs() < 40.0);
    }

    #[test]
    fn an_oblique_cut_that_misses_the_solid_shows_it_whole_or_nothing() {
        let s = Solid::new(preset("rect", 40.0, 30.0).unwrap(), 20.0);
        // 平面遠在塊的外面。
        let far = |normal: P3| Cut::Oblique {
            point: [0.0, 500.0, -10.0],
            normal,
        };
        let r = 0.5f32.sqrt();
        // 觀看者那一側被移走：法向量朝 +y、平面在 y = 500 之外 → 塊在平面後面，原樣留下，沒有切口。
        let whole = section_view(&s, &far([0.0, r, r]), 1.5);
        assert!(whole.hatch.is_empty() && !whole.lines.is_empty());
        let gone = section_view(&s, &far([0.0, -r, -r]), 1.5);
        assert!(gone.hatch.is_empty() && gone.lines.is_empty());
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
