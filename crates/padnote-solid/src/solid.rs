//! 草圖 → 立體：輪廓（外環＋洞）沿深度方向拉伸成一個柱體。
//!
//! # 座標
//!
//! 輪廓畫在 **XY 平面**（x 向右、y 向上），也就是**正視圖**看到的那一面；
//! 柱體往 −Z 拉伸（`z ∈ [−depth, 0]`），所以 `z = 0` 的那一面朝向正視圖的觀看者。
//! 這個約定決定了三視圖的對位（見 [`crate::view`]）。
//!
//! # 為什麼是柱體，不是任意網格
//!
//! 製圖課的題目幾乎都是「一個輪廓拉伸」或它的組合；柱體可以讓剖切與投影都用精確的
//! 二維運算做，不必實作多面體布林運算。真的需要組合時，輪廓本身可以是任意多邊形（凹的、帶洞的）。

use crate::geom::{self, P2, P3};
use padnote_ink::SnapKind;

/// 一個輪廓：一條外環加上零到多個洞。
///
/// 建構後一律**正規化**：外環逆時針、洞順時針，且整體平移到包圍盒左下角為原點。
#[derive(Clone, Debug, PartialEq)]
pub struct Profile {
    pub outer: Vec<P2>,
    pub holes: Vec<Vec<P2>>,
}

impl Profile {
    /// 由外環與洞建立。環少於三點、面積近乎零的都會被丟掉；外環沒了回 `None`。
    pub fn new(outer: Vec<P2>, holes: Vec<Vec<P2>>) -> Option<Profile> {
        let mut outer = dedupe_ring(outer);
        if outer.len() < 3 || geom::signed_area(&outer).abs() < 1e-3 {
            return None;
        }
        if geom::signed_area(&outer) < 0.0 {
            outer.reverse();
        }
        let mut holes: Vec<Vec<P2>> = holes
            .into_iter()
            .map(dedupe_ring)
            .filter(|h| h.len() >= 3 && geom::signed_area(h).abs() > 1e-3)
            .map(|mut h| {
                if geom::signed_area(&h) > 0.0 {
                    h.reverse();
                }
                h
            })
            .collect();
        // 不在外環內的洞沒有意義。
        holes.retain(|h| geom::point_in_ring(geom::centroid_of_points(h), &outer));
        let (lo, _) = geom::bounds(&outer)?;
        let shift = |ring: &mut Vec<P2>| {
            for p in ring.iter_mut() {
                *p = (p.0 - lo.0, p.1 - lo.1);
            }
        };
        shift(&mut outer);
        for h in &mut holes {
            shift(h);
        }
        Some(Profile { outer, holes })
    }

    /// 包圍盒尺寸 `(寬, 高)`。
    pub fn size(&self) -> P2 {
        let (lo, hi) = geom::bounds(&self.outer).unwrap_or(((0.0, 0.0), (0.0, 0.0)));
        (hi.0 - lo.0, hi.1 - lo.1)
    }

    /// 全部的環，外環在最前面。
    pub fn rings(&self) -> Vec<&[P2]> {
        let mut v: Vec<&[P2]> = vec![&self.outer];
        v.extend(self.holes.iter().map(|h| h.as_slice()));
        v
    }

    pub fn area(&self) -> f32 {
        geom::signed_area(&self.outer)
            + self.holes.iter().map(|h| geom::signed_area(h)).sum::<f32>()
    }
}

/// 去掉連續重複點與首尾重複。
fn dedupe_ring(mut ring: Vec<P2>) -> Vec<P2> {
    ring.dedup_by(|a, b| geom::dist(*a, *b) < 1e-3);
    while ring.len() > 1 && geom::dist(ring[0], *ring.last().unwrap()) < 1e-3 {
        ring.pop();
    }
    ring
}

// MARK: - 預設輪廓

/// 預設輪廓的種類。順序即 UI 顯示順序。
pub const PRESETS: [&str; 8] = [
    "rect",
    "circle",
    "hexagon",
    "l_shape",
    "t_shape",
    "u_shape",
    "ring",
    "plate_holes",
];

fn circle_ring(cx: f32, cy: f32, r: f32, n: usize) -> Vec<P2> {
    (0..n)
        .map(|i| {
            let a = i as f32 / n as f32 * std::f32::consts::TAU;
            (cx + r * a.cos(), cy + r * a.sin())
        })
        .collect()
}

/// 預設輪廓。`w`、`h` 是包圍盒大小；認不得的名稱回 `None`。
pub fn preset(name: &str, w: f32, h: f32) -> Option<Profile> {
    let (w, h) = (w.max(1.0), h.max(1.0));
    let r = w.min(h) / 2.0;
    match name {
        "rect" => Profile::new(vec![(0.0, 0.0), (w, 0.0), (w, h), (0.0, h)], vec![]),
        "circle" => Profile::new(circle_ring(w / 2.0, h / 2.0, r, 48), vec![]),
        "hexagon" => {
            let ring = (0..6)
                .map(|i| {
                    let a = i as f32 / 6.0 * std::f32::consts::TAU;
                    (w / 2.0 + w / 2.0 * a.cos(), h / 2.0 + h / 2.0 * a.sin())
                })
                .collect();
            Profile::new(ring, vec![])
        }
        "l_shape" => Profile::new(
            vec![
                (0.0, 0.0),
                (w, 0.0),
                (w, h * 0.4),
                (w * 0.4, h * 0.4),
                (w * 0.4, h),
                (0.0, h),
            ],
            vec![],
        ),
        "t_shape" => Profile::new(
            vec![
                (0.0, h * 0.65),
                (0.0, h),
                (w, h),
                (w, h * 0.65),
                (w * 0.65, h * 0.65),
                (w * 0.65, 0.0),
                (w * 0.35, 0.0),
                (w * 0.35, h * 0.65),
            ],
            vec![],
        ),
        "u_shape" => Profile::new(
            vec![
                (0.0, 0.0),
                (w, 0.0),
                (w, h),
                (w * 0.7, h),
                (w * 0.7, h * 0.35),
                (w * 0.3, h * 0.35),
                (w * 0.3, h),
                (0.0, h),
            ],
            vec![],
        ),
        "ring" => Profile::new(
            circle_ring(w / 2.0, h / 2.0, r, 48),
            vec![circle_ring(w / 2.0, h / 2.0, r * 0.5, 48)],
        ),
        "plate_holes" => {
            let hole_r = (w.min(h) * 0.09).max(1.0);
            let holes = [(0.25, 0.3), (0.75, 0.3), (0.25, 0.7), (0.75, 0.7)]
                .iter()
                .map(|(fx, fy)| circle_ring(w * fx, h * fy, hole_r, 24))
                .collect();
            Profile::new(vec![(0.0, 0.0), (w, 0.0), (w, h), (0.0, h)], holes)
        }
        _ => None,
    }
}

// MARK: - 草圖 → 輪廓

/// 一筆手繪線能不能當成封閉輪廓，能的話回傳整理過的環。
///
/// - 起點與終點要靠得夠近（周長的 12%，至少 6 個頁面單位）：沒闔起來的線不是輪廓。
/// - 先過「吸附」：手抖的圓、矩形、三角形變成規則的圖形，再簡化成頂點少的多邊形。
pub fn ring_from_stroke(points: &[P2]) -> Option<Vec<P2>> {
    if points.len() < 4 {
        return None;
    }
    let perimeter: f32 = points.windows(2).map(|w| geom::dist(w[0], w[1])).sum();
    let gap = geom::dist(points[0], *points.last()?);
    if perimeter < 24.0 || gap > (perimeter * 0.12).max(6.0) {
        return None;
    }
    let snapped = padnote_ink::snap_stroke(points, 15.0);
    let ring_pts = match snapped.kind {
        SnapKind::Ellipse | SnapKind::Rectangle | SnapKind::Triangle | SnapKind::Polyline => {
            snapped.points
        }
        _ => points.to_vec(),
    };
    let b = geom::bounds(&ring_pts)?;
    let diag = geom::dist(b.0, b.1);
    let simplified = if snapped.kind == SnapKind::Ellipse {
        // 圓／橢圓：重新取 48 個等距點，才是漂亮的正多邊形。
        resample_closed(&ring_pts, 48)
    } else {
        geom::simplify_ring(&ring_pts, (diag * 0.012).max(0.8))
    };
    (simplified.len() >= 3 && geom::signed_area(&simplified).abs() > 1.0).then_some(simplified)
}

fn resample_closed(ring: &[P2], n: usize) -> Vec<P2> {
    let total = geom::perimeter(ring);
    if total < 1e-3 {
        return ring.to_vec();
    }
    let mut out = Vec::with_capacity(n);
    let m = ring.len();
    let (mut seg, mut walked) = (0usize, 0.0f32);
    for k in 0..n {
        let target = total * k as f32 / n as f32;
        loop {
            let (a, b) = (ring[seg % m], ring[(seg + 1) % m]);
            let l = geom::dist(a, b);
            if walked + l >= target || seg > 2 * m {
                let t = if l < 1e-6 { 0.0 } else { (target - walked) / l };
                out.push((a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t));
                break;
            }
            walked += l;
            seg += 1;
        }
    }
    out
}

/// 把首尾相接的開放線串成一條。端點相距不超過 `tol` 就接起來（必要時把線反過來）。
///
/// 手繪輪廓常常是**幾條直線**圍成的（四條邊畫四筆），不是一筆闔起來的圈。
fn chain_open_strokes(strokes: &[Vec<P2>], tol: f32) -> Vec<(Vec<P2>, usize)> {
    let mut pool: Vec<Vec<P2>> = strokes.iter().filter(|s| s.len() >= 2).cloned().collect();
    let mut chains: Vec<(Vec<P2>, usize)> = Vec::new();
    while let Some(mut chain) = pool.pop() {
        let mut parts = 1usize;
        loop {
            // 找一條端點接得上這條鏈首或尾的線。
            let head = chain[0];
            let tail = *chain.last().unwrap();
            if geom::dist(head, tail) <= tol {
                break; // 已經闔起來。
            }
            let mut joined = false;
            for i in 0..pool.len() {
                let (a, b) = (pool[i][0], *pool[i].last().unwrap());
                let attach = if geom::dist(tail, a) <= tol {
                    Some((true, false)) // 接在尾巴後面，原方向
                } else if geom::dist(tail, b) <= tol {
                    Some((true, true)) // 接在尾巴後面，反方向
                } else if geom::dist(head, b) <= tol {
                    Some((false, false)) // 接在頭前面，原方向
                } else if geom::dist(head, a) <= tol {
                    Some((false, true)) // 接在頭前面，反方向
                } else {
                    None
                };
                if let Some((at_tail, reversed)) = attach {
                    let mut piece = pool.swap_remove(i);
                    if reversed {
                        piece.reverse();
                    }
                    if at_tail {
                        chain.extend(piece.into_iter().skip(1));
                    } else {
                        piece.pop();
                        piece.extend(chain);
                        chain = piece;
                    }
                    parts += 1;
                    joined = true;
                    break;
                }
            }
            if !joined {
                break;
            }
        }
        chains.push((chain, parts));
    }
    chains
}

/// 一組手繪線 → 輪廓：最大的封閉圖形是外環，落在它裡面的封閉圖形是洞，其餘忽略。
///
/// 「封閉圖形」有兩種：一筆闔起來的線（先吸附成圓／矩形／三角形），或幾條首尾相接、
/// 圍成封閉的線（四條邊畫四筆的矩形）。
pub fn profile_from_strokes(strokes: &[Vec<P2>]) -> Option<Profile> {
    let mut rings: Vec<Vec<P2>> = strokes.iter().filter_map(|s| ring_from_stroke(s)).collect();

    // 沒有一筆闔起來的線，或還有別的線：把開放的線串起來看看能不能闔成圖形。
    let all: Vec<P2> = strokes.iter().flatten().copied().collect();
    if let Some((lo, hi)) = geom::bounds(&all) {
        let tol = (geom::dist(lo, hi) * 0.015).max(8.0);
        for (chain, parts) in chain_open_strokes(strokes, tol) {
            // 單獨一筆的線上面已經處理過了（闔起來的吸附成圖形，沒闔起來的不是輪廓）。
            if parts < 2 || chain.len() < 3 || geom::dist(chain[0], *chain.last().unwrap()) > tol {
                continue;
            }
            let b = geom::bounds(&chain).unwrap_or((lo, hi));
            let simplified = geom::simplify_ring(&chain, (geom::dist(b.0, b.1) * 0.01).max(0.8));
            if simplified.len() >= 3 && geom::signed_area(&simplified).abs() > 1.0 {
                rings.push(simplified);
            }
        }
    }

    rings.sort_by(|a, b| {
        geom::signed_area(b)
            .abs()
            .partial_cmp(&geom::signed_area(a).abs())
            .unwrap_or(std::cmp::Ordering::Equal)
    });
    let outer = rings.first()?.clone();
    let holes: Vec<Vec<P2>> = rings
        .into_iter()
        .skip(1)
        .filter(|r| {
            r.iter().all(|p| geom::point_in_ring(*p, &outer))
                || geom::point_in_ring(geom::centroid_of_points(r), &outer)
        })
        .collect();
    Profile::new(outer, holes)
}

// MARK: - 立體與網格

/// 面的種類。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum FaceKind {
    /// `z = 0`，朝 +Z。
    Front,
    /// `z = −depth`，朝 −Z。
    Back,
    /// 側壁（沿輪廓邊）。
    Side,
}

/// 平面多邊形面。`rings[0]` 是外環，其餘是洞（只有前後兩個蓋面會有洞）。
#[derive(Clone, Debug)]
pub struct Face {
    pub rings: Vec<Vec<P3>>,
    pub normal: P3,
    /// 平面方程 `normal · p = plane_d`。
    pub plane_d: f32,
    pub kind: FaceKind,
}

/// 兩個面共用的一條邊。
#[derive(Clone, Debug)]
pub struct Edge {
    pub a: P3,
    pub b: P3,
    pub faces: [usize; 2],
    /// 不管夾角多平，這條邊一律要畫（剖面的切口邊界）。
    pub always: bool,
}

#[derive(Clone, Debug)]
pub struct Mesh {
    pub faces: Vec<Face>,
    pub edges: Vec<Edge>,
}

/// 輪廓拉伸成的柱體。
#[derive(Clone, Debug)]
pub struct Solid {
    pub profile: Profile,
    pub depth: f32,
}

impl Solid {
    pub fn new(profile: Profile, depth: f32) -> Solid {
        Solid {
            profile,
            depth: depth.max(0.5),
        }
    }

    /// 包圍盒尺寸 `(x, y, z)`。
    pub fn dims(&self) -> P3 {
        let (w, h) = self.profile.size();
        [w, h, self.depth]
    }

    pub fn mesh(&self) -> Mesh {
        let rings: Vec<Vec<P2>> = self
            .profile
            .rings()
            .into_iter()
            .map(|r| r.to_vec())
            .collect();
        mesh_from_rings(&rings, self.depth, &|_, _| false)
    }
}

/// 由環（外環逆時針、洞順時針）拉伸出網格。
///
/// `skip(p, q)` 回傳真的時，環上 `p→q` 這條邊不產生側壁（剖面的切口由呼叫端另外補上）。
/// 第一個環是外環；其餘是洞。沒有任何環就是空網格。
pub fn mesh_from_rings(rings: &[Vec<P2>], depth: f32, skip: &dyn Fn(P2, P2) -> bool) -> Mesh {
    mesh_from_rings_ex(rings, depth, skip, &|_| false)
}

/// 同 [`mesh_from_rings`]，另外 `quiet(p)` 回傳真的時，頂點 `p` 在「只剩一邊側壁」的情況下**不畫**垂直邊。
///
/// 切口邊界上的頂點要畫（那是切口牆的邊）；但剖面被分成幾塊時，分界線上的頂點只是人為切出來的，
/// 隔壁那塊的牆與這塊的牆其實是同一面，畫了就多出一條不存在的線。
pub fn mesh_from_rings_ex(
    rings: &[Vec<P2>],
    depth: f32,
    skip: &dyn Fn(P2, P2) -> bool,
    quiet: &dyn Fn(P2) -> bool,
) -> Mesh {
    let d = depth;
    let mut faces: Vec<Face> = Vec::new();
    let mut edges: Vec<Edge> = Vec::new();
    if rings.is_empty() {
        return Mesh { faces, edges };
    }
    let ring3 = |ring: &[P2], z: f32, rev: bool| -> Vec<P3> {
        let mut v: Vec<P3> = ring.iter().map(|p| [p.0, p.1, z]).collect();
        if rev {
            v.reverse();
        }
        v
    };
    faces.push(Face {
        rings: rings.iter().map(|r| ring3(r, 0.0, false)).collect(),
        normal: [0.0, 0.0, 1.0],
        plane_d: 0.0,
        kind: FaceKind::Front,
    });
    faces.push(Face {
        rings: rings.iter().map(|r| ring3(r, -d, true)).collect(),
        normal: [0.0, 0.0, -1.0],
        plane_d: d,
        kind: FaceKind::Back,
    });

    for ring in rings {
        let n = ring.len();
        // 每條邊對應的側壁編號；被略過的邊沒有。
        let mut wall: Vec<Option<usize>> = vec![None; n];
        for i in 0..n {
            let (p, q) = (ring[i], ring[(i + 1) % n]);
            if skip(p, q) {
                continue;
            }
            let (dx, dy) = (q.0 - p.0, q.1 - p.1);
            let len = (dx * dx + dy * dy).sqrt().max(1e-9);
            // 行進方向的右手邊是實體外側：法向量 = (dy, −dx)。
            let normal = [dy / len, -dx / len, 0.0];
            wall[i] = Some(faces.len());
            faces.push(Face {
                rings: vec![vec![
                    [p.0, p.1, 0.0],
                    [q.0, q.1, 0.0],
                    [q.0, q.1, -d],
                    [p.0, p.1, -d],
                ]],
                normal,
                plane_d: normal[0] * p.0 + normal[1] * p.1,
                kind: FaceKind::Side,
            });
        }
        for i in 0..n {
            let (p, q) = (ring[i], ring[(i + 1) % n]);
            let prev = wall[(i + n - 1) % n];
            if let Some(w) = wall[i] {
                edges.push(Edge {
                    a: [p.0, p.1, 0.0],
                    b: [q.0, q.1, 0.0],
                    faces: [0, w],
                    always: false,
                });
                edges.push(Edge {
                    a: [p.0, p.1, -d],
                    b: [q.0, q.1, -d],
                    faces: [1, w],
                    always: false,
                });
            }
            // 頂點處的垂直邊：兩側壁都在才有「夾角」可言；只剩一邊（另一邊是切口）就一律畫。
            match (prev, wall[i]) {
                (Some(a), Some(b)) => edges.push(Edge {
                    a: [p.0, p.1, 0.0],
                    b: [p.0, p.1, -d],
                    faces: [a, b],
                    always: false,
                }),
                (Some(w), None) | (None, Some(w)) => {
                    if !quiet(p) {
                        edges.push(Edge {
                            a: [p.0, p.1, 0.0],
                            b: [p.0, p.1, -d],
                            faces: [w, w],
                            always: true,
                        })
                    }
                }
                (None, None) => {}
            }
        }
    }
    Mesh { faces, edges }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn profiles_are_normalised() {
        // 順時針外環、逆時針洞、離開原點：建構後應該反過來並平移到原點。
        let outer = vec![(10.0, 10.0), (10.0, 30.0), (30.0, 30.0), (30.0, 10.0)];
        let hole = vec![(15.0, 15.0), (25.0, 15.0), (25.0, 25.0), (15.0, 25.0)];
        let p = Profile::new(outer, vec![hole]).unwrap();
        assert!(geom::signed_area(&p.outer) > 0.0);
        assert!(geom::signed_area(&p.holes[0]) < 0.0);
        assert_eq!(geom::bounds(&p.outer).unwrap().0, (0.0, 0.0));
        assert!((p.area() - (400.0 - 100.0)).abs() < 1e-2);
    }

    #[test]
    fn a_hole_outside_the_outline_is_dropped() {
        let outer = vec![(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 10.0)];
        let far = vec![(50.0, 50.0), (60.0, 50.0), (60.0, 60.0), (50.0, 60.0)];
        assert!(Profile::new(outer, vec![far]).unwrap().holes.is_empty());
    }

    #[test]
    fn degenerate_outlines_are_refused() {
        assert!(Profile::new(vec![(0.0, 0.0), (1.0, 1.0)], vec![]).is_none());
        assert!(Profile::new(vec![(0.0, 0.0), (5.0, 5.0), (10.0, 10.0)], vec![]).is_none());
    }

    #[test]
    fn every_preset_builds() {
        for name in PRESETS {
            let p = preset(name, 60.0, 40.0).unwrap_or_else(|| panic!("{name}"));
            assert!(p.area() > 100.0, "{name}");
        }
        assert!(preset("沒這種", 10.0, 10.0).is_none());
    }

    #[test]
    fn an_extruded_box_has_six_faces_and_twelve_edges() {
        let s = Solid::new(preset("rect", 40.0, 30.0).unwrap(), 20.0);
        let m = s.mesh();
        assert_eq!(m.faces.len(), 6);
        assert_eq!(m.edges.len(), 12);
        // 每個面的法向量都指向外側：從重心沿法向走一步離開實體。
        for f in &m.faces {
            let c: P3 = {
                let ring = &f.rings[0];
                let n = ring.len() as f32;
                [
                    ring.iter().map(|p| p[0]).sum::<f32>() / n,
                    ring.iter().map(|p| p[1]).sum::<f32>() / n,
                    ring.iter().map(|p| p[2]).sum::<f32>() / n,
                ]
            };
            let probe = [
                c[0] + f.normal[0] * 0.5,
                c[1] + f.normal[1] * 0.5,
                c[2] + f.normal[2] * 0.5,
            ];
            let inside = probe[0] > 0.0
                && probe[0] < 40.0
                && probe[1] > 0.0
                && probe[1] < 30.0
                && probe[2] < 0.0
                && probe[2] > -20.0;
            assert!(!inside, "{:?} 的法向量指向實體內側", f.kind);
        }
    }

    #[test]
    fn a_hole_adds_walls_with_inward_facing_normals() {
        let s = Solid::new(preset("ring", 60.0, 60.0).unwrap(), 10.0);
        let m = s.mesh();
        // 洞的牆法向量指向洞心（實體外側 = 洞內）。
        let hole_c = (30.0, 30.0);
        let hole_walls = m
            .faces
            .iter()
            .filter(|f| f.kind == FaceKind::Side)
            .filter(|f| {
                let r = &f.rings[0];
                let mid = ((r[0][0] + r[1][0]) / 2.0, (r[0][1] + r[1][1]) / 2.0);
                geom::dist(mid, hole_c) < 20.0
            })
            .count();
        assert_eq!(hole_walls, 48);
        for f in m.faces.iter().filter(|f| f.kind == FaceKind::Side) {
            let r = &f.rings[0];
            let mid = ((r[0][0] + r[1][0]) / 2.0, (r[0][1] + r[1][1]) / 2.0);
            if geom::dist(mid, hole_c) < 20.0 {
                let to_centre = (hole_c.0 - mid.0, hole_c.1 - mid.1);
                assert!(f.normal[0] * to_centre.0 + f.normal[1] * to_centre.1 > 0.0);
            }
        }
    }

    fn hand_square(jitter: f32) -> Vec<P2> {
        let mut pts = Vec::new();
        let side = 100.0;
        for i in 0..=30 {
            pts.push((i as f32 / 30.0 * side, jitter * ((i % 3) as f32 - 1.0)));
        }
        for i in 1..=30 {
            pts.push((side + jitter, i as f32 / 30.0 * side));
        }
        for i in 1..=30 {
            pts.push((side - i as f32 / 30.0 * side, side - jitter));
        }
        for i in 1..30 {
            pts.push((jitter, side - i as f32 / 30.0 * side));
        }
        pts
    }

    #[test]
    fn a_closed_wobbly_square_becomes_a_four_corner_ring() {
        let ring = ring_from_stroke(&hand_square(1.5)).unwrap();
        assert!(ring.len() <= 6, "{ring:?}");
        assert!((geom::signed_area(&ring).abs() - 10000.0).abs() < 800.0);
    }

    #[test]
    fn an_open_stroke_is_not_a_profile() {
        let open: Vec<P2> = (0..30)
            .map(|i| (i as f32 * 5.0, (i as f32 * 0.3).sin() * 10.0))
            .collect();
        assert!(ring_from_stroke(&open).is_none());
    }

    #[test]
    fn a_circle_stroke_becomes_a_circle_ring() {
        let circle: Vec<P2> = (0..=60)
            .map(|i| {
                let a = i as f32 / 60.0 * std::f32::consts::TAU;
                let r = 50.0 + if i % 2 == 0 { 1.5 } else { -1.5 };
                (100.0 + r * a.cos(), 100.0 + r * a.sin())
            })
            .collect();
        let ring = ring_from_stroke(&circle).unwrap();
        assert_eq!(ring.len(), 48);
        assert!(geom::ring_as_circle(&ring).is_some());
    }

    #[test]
    fn four_separate_lines_that_meet_make_a_rectangle() {
        // 四條邊畫四筆，方向不一致、端點略有誤差。
        let top: Vec<P2> = (0..=10).map(|i| (i as f32 * 10.0, 0.0)).collect();
        let right: Vec<P2> = (0..=8).map(|i| (101.0, i as f32 * 10.0)).collect();
        let bottom: Vec<P2> = (0..=10).map(|i| (100.0 - i as f32 * 10.0, 79.0)).collect();
        let left: Vec<P2> = (0..=8).map(|i| (0.5, 80.0 - i as f32 * 10.0)).collect();
        // 故意打亂順序、反轉其中一條。
        let reversed_left: Vec<P2> = left.iter().rev().copied().collect();
        let p = profile_from_strokes(&[bottom, reversed_left, top, right]).expect("四條線圍成封閉");
        let (w, h) = p.size();
        assert!((w - 101.0).abs() < 3.0 && (h - 80.0).abs() < 3.0, "{w}×{h}");
        assert!(p.outer.len() <= 6, "{:?}", p.outer);
    }

    #[test]
    fn lines_with_a_gap_do_not_close() {
        let a: Vec<P2> = (0..=10).map(|i| (i as f32 * 10.0, 0.0)).collect();
        let b: Vec<P2> = (0..=8).map(|i| (100.0, i as f32 * 10.0)).collect();
        // 第三條離起點很遠：圍不成封閉。
        let c: Vec<P2> = (0..=10).map(|i| (100.0 - i as f32 * 10.0, 80.0)).collect();
        assert!(profile_from_strokes(&[a, b, c]).is_none());
    }

    #[test]
    fn a_u_shape_drawn_as_separate_lines_is_recovered() {
        // U 形外框：六筆線，其中兩條很短。
        let seg = |a: P2, b: P2| -> Vec<P2> {
            (0..=10)
                .map(|i| {
                    let t = i as f32 / 10.0;
                    (a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t)
                })
                .collect()
        };
        let strokes = vec![
            seg((0.0, 0.0), (120.0, 0.0)),
            seg((120.0, 0.0), (120.0, 100.0)),
            seg((120.0, 100.0), (84.0, 100.0)),
            seg((84.0, 100.0), (84.0, 35.0)),
            seg((84.0, 35.0), (36.0, 35.0)),
            seg((36.0, 35.0), (36.0, 100.0)),
            seg((36.0, 100.0), (0.0, 100.0)),
            seg((0.0, 100.0), (0.0, 0.0)),
        ];
        let p = profile_from_strokes(&strokes).expect("U 形");
        assert_eq!(p.outer.len(), 8, "{:?}", p.outer);
        assert!((p.area() - (120.0 * 100.0 - 48.0 * 65.0)).abs() < 50.0);
    }

    #[test]
    fn strokes_inside_the_biggest_one_become_holes() {
        let outer = hand_square(0.5);
        let inner: Vec<P2> = (0..=40)
            .map(|i| {
                let a = i as f32 / 40.0 * std::f32::consts::TAU;
                (50.0 + 15.0 * a.cos(), 50.0 + 15.0 * a.sin())
            })
            .collect();
        let p = profile_from_strokes(&[inner, outer]).unwrap();
        assert_eq!(p.holes.len(), 1);
        assert!(p.area() < 10000.0 - 500.0);
    }
}
