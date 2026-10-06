//! 正投影與隱藏線：把立體投到畫面上，區分看得見的線（實線）與被擋住的線（虛線）。
//!
//! # 演算法
//!
//! 1. 挑出這個視角下**該畫的邊**：特徵邊（相鄰兩面夾角大於 25°）加上輪廓邊（一面朝向觀看者、
//!    一面背向）。圓柱的側壁是 48 片小平面，片與片之間不是特徵邊，但左右兩條輪廓邊要畫。
//! 2. 沿每條邊取樣，從取樣點朝觀看者發一條射線；撞到任何一個面就是被擋住。
//!    實體是柱體、面不多，逐面測試就夠快；可見／不可見的交界用二分法精修。
//! 3. 投影到畫面，把重疊的共線線段合併 —— 看得見的蓋掉看不見的（背面的邊常常正好
//!    藏在前面的邊後面，不合併的話虛線會疊在實線上）。

use crate::geom::{self, P2, P3};
use crate::solid::{Face, Mesh, Solid};

fn dot(a: P3, b: P3) -> f32 {
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
}

fn cross(a: P3, b: P3) -> P3 {
    [
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    ]
}

fn norm(a: P3) -> P3 {
    let l = dot(a, a).sqrt().max(1e-9);
    [a[0] / l, a[1] / l, a[2] / l]
}

/// 正投影攝影機。`yaw`、`pitch` 單位是度。
///
/// 觀看者位於 `(sin yaw·cos pitch, sin pitch, cos yaw·cos pitch)` 的方向看向原點：
/// `(0, 0)` 是正視圖，`(90, 0)` 是右側視圖，`(0, 90)` 是俯視圖。
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Camera {
    pub yaw: f32,
    pub pitch: f32,
    /// 畫面縮放。等角圖用真實軸長（×√(3/2)），其餘是 1。
    pub scale: f32,
}

/// 標準視圖。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum StandardView {
    Front,
    Top,
    Right,
    Left,
    Back,
    Bottom,
    Iso,
}

impl Camera {
    pub fn standard(view: StandardView) -> Camera {
        let (yaw, pitch, scale) = match view {
            StandardView::Front => (0.0, 0.0, 1.0),
            StandardView::Top => (0.0, 90.0, 1.0),
            StandardView::Right => (90.0, 0.0, 1.0),
            StandardView::Left => (-90.0, 0.0, 1.0),
            StandardView::Back => (180.0, 0.0, 1.0),
            StandardView::Bottom => (0.0, -90.0, 1.0),
            // 35.264° = atan(1/√2)：三個軸等長縮短的角度。
            StandardView::Iso => (45.0, 35.264_39, 1.224_744_9),
        };
        Camera { yaw, pitch, scale }
    }

    /// 任意角度（旋轉對照用）。
    pub fn free(yaw: f32, pitch: f32) -> Camera {
        Camera {
            yaw,
            pitch: pitch.clamp(-90.0, 90.0),
            scale: 1.0,
        }
    }

    /// 觀看者方向、畫面右向、畫面上向。
    pub fn basis(&self) -> (P3, P3, P3) {
        let (y, p) = (self.yaw.to_radians(), self.pitch.to_radians());
        let d = [y.sin() * p.cos(), p.sin(), y.cos() * p.cos()];
        let f = [-d[0], -d[1], -d[2]];
        // 俯視／仰視時世界的「上」與視線平行，改用 ∓Z：
        // 俯視圖的畫面上方是物體的後方（−Z），仰視圖相反。
        let up_hint = if self.pitch > 89.5 {
            [0.0, 0.0, -1.0]
        } else if self.pitch < -89.5 {
            [0.0, 0.0, 1.0]
        } else {
            [0.0, 1.0, 0.0]
        };
        let right = norm(cross(f, up_hint));
        let up = cross(right, f);
        (d, right, up)
    }

    pub fn project(&self, p: P3) -> P2 {
        let (_, r, u) = self.basis();
        (dot(p, r) * self.scale, dot(p, u) * self.scale)
    }
}

/// 投影後的一條線。
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Line2 {
    pub a: P2,
    pub b: P2,
    /// 被擋住（畫成隱藏線）。
    pub hidden: bool,
}

/// 一個視圖的所有線。
#[derive(Clone, Debug, Default)]
pub struct View {
    pub lines: Vec<Line2>,
}

impl View {
    pub fn bounds(&self) -> Option<(P2, P2)> {
        let pts: Vec<P2> = self.lines.iter().flat_map(|l| [l.a, l.b]).collect();
        geom::bounds(&pts)
    }

    pub fn visible(&self) -> impl Iterator<Item = &Line2> {
        self.lines.iter().filter(|l| !l.hidden)
    }

    pub fn hidden(&self) -> impl Iterator<Item = &Line2> {
        self.lines.iter().filter(|l| l.hidden)
    }
}

/// 特徵邊的門檻：相鄰兩面法向量夾角超過約 25°。
const FEATURE_COS: f32 = 0.906;
const FACING_TOL: f32 = 1e-3;

fn facing(face: &Face, d: P3) -> i8 {
    let s = dot(face.normal, d);
    if s > FACING_TOL {
        1
    } else if s < -FACING_TOL {
        -1
    } else {
        0
    }
}

/// 射線 `o + t·d`（`t > 0`）有沒有撞到某個面。
fn ray_hits(mesh: &Mesh, o: P3, d: P3) -> bool {
    for f in &mesh.faces {
        let nd = dot(f.normal, d);
        if nd.abs() < 1e-6 {
            continue;
        }
        let t = (f.plane_d - dot(f.normal, o)) / nd;
        if t <= 0.0 {
            continue;
        }
        let hit = [o[0] + d[0] * t, o[1] + d[1] * t, o[2] + d[2] * t];
        // 丟掉法向量最大的那一軸，在剩下的平面上做奇偶測試。
        let ax = (0..3)
            .max_by(|&a, &b| {
                f.normal[a]
                    .abs()
                    .partial_cmp(&f.normal[b].abs())
                    .unwrap_or(std::cmp::Ordering::Equal)
            })
            .unwrap_or(2);
        let (i, j) = match ax {
            0 => (1, 2),
            1 => (0, 2),
            _ => (0, 1),
        };
        let p = (hit[i], hit[j]);
        let rings: Vec<Vec<P2>> = f
            .rings
            .iter()
            .map(|r| r.iter().map(|v| (v[i], v[j])).collect())
            .collect();
        let refs: Vec<&[P2]> = rings.iter().map(|r| r.as_slice()).collect();
        if geom::point_in_rings(p, &refs) {
            return true;
        }
    }
    false
}

fn lerp3(a: P3, b: P3, t: f32) -> P3 {
    [
        a[0] + (b[0] - a[0]) * t,
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
    ]
}

/// 立體在這個視角下的線。
pub fn project(solid: &Solid, cam: &Camera) -> View {
    let dims = solid.dims();
    project_mesh(
        &solid.mesh(),
        cam,
        dims[0].max(dims[1]).max(dims[2]).max(1.0),
    )
}

/// 網格在這個視角下的線。`size` 是物體的概略大小，用來決定取樣密度與誤差。
pub fn project_mesh(mesh: &Mesh, cam: &Camera, size: f32) -> View {
    let (d, _, _) = cam.basis();
    let eps = size * 1e-3;

    let mut raw: Vec<Line2> = Vec::new();
    for e in &mesh.edges {
        let (f0, f1) = (&mesh.faces[e.faces[0]], &mesh.faces[e.faces[1]]);
        let feature = dot(f0.normal, f1.normal) < FEATURE_COS;
        let silhouette = facing(f0, d) != facing(f1, d);
        if !feature && !silhouette && !e.always {
            continue;
        }
        let (pa, pb) = (cam.project(e.a), cam.project(e.b));
        if geom::dist(pa, pb) < 1e-3 {
            // 與視線平行的邊，投影成一個點。
            continue;
        }
        let len3 = geom::dist((e.a[0], e.a[1]), (e.b[0], e.b[1])).max((e.a[2] - e.b[2]).abs());
        let n = ((len3 / size * 80.0).ceil() as usize).clamp(8, 160);
        let hidden_at = |t: f32| -> bool {
            let q = lerp3(e.a, e.b, t);
            let o = [q[0] + d[0] * eps, q[1] + d[1] * eps, q[2] + d[2] * eps];
            ray_hits(mesh, o, d)
        };
        // 取樣、找出狀態變化的區間，再二分法精修交界。
        let states: Vec<bool> = (0..=n).map(|i| hidden_at(i as f32 / n as f32)).collect();
        let mut cuts = vec![0.0f32];
        for i in 0..n {
            if states[i] != states[i + 1] {
                let (mut lo, mut hi) = (i as f32 / n as f32, (i + 1) as f32 / n as f32);
                let lo_state = states[i];
                for _ in 0..14 {
                    let mid = (lo + hi) * 0.5;
                    if hidden_at(mid) == lo_state {
                        lo = mid;
                    } else {
                        hi = mid;
                    }
                }
                cuts.push((lo + hi) * 0.5);
            }
        }
        cuts.push(1.0);
        let mut state = states[0];
        for w in cuts.windows(2) {
            if w[1] - w[0] > 1e-5 {
                let (a, b) = (
                    cam.project(lerp3(e.a, e.b, w[0])),
                    cam.project(lerp3(e.a, e.b, w[1])),
                );
                raw.push(Line2 {
                    a,
                    b,
                    hidden: state,
                });
            }
            state = !state;
        }
    }
    View {
        lines: merge_lines(raw, size * 2e-3),
    }
}

/// 把共線且重疊的線段合併；看得見的蓋掉看不見的。
pub fn merge_lines(lines: Vec<Line2>, tol: f32) -> Vec<Line2> {
    struct Seg {
        t0: f32,
        t1: f32,
        hidden: bool,
    }
    struct Cluster {
        dir: P2,
        rho: f32,
        origin: P2,
        segs: Vec<Seg>,
    }
    let mut clusters: Vec<Cluster> = Vec::new();
    for l in lines {
        let (dx, dy) = (l.b.0 - l.a.0, l.b.1 - l.a.1);
        let len = (dx * dx + dy * dy).sqrt();
        if len < 1e-6 {
            continue;
        }
        let mut dir = (dx / len, dy / len);
        let mut a = l.a;
        let mut b = l.b;
        // 近乎垂直的線（dir.0 在 1e-3 以內）一律朝上，否則 ±1e-6 的雜訊會讓同一條線分到兩個方向。
        if dir.0 < -1e-3 || (dir.0.abs() <= 1e-3 && dir.1 < 0.0) {
            dir = (-dir.0, -dir.1);
            std::mem::swap(&mut a, &mut b);
        }
        let nrm = (-dir.1, dir.0);
        let rho = a.0 * nrm.0 + a.1 * nrm.1;
        let found = clusters.iter_mut().find(|c| {
            (c.dir.0 * dir.1 - c.dir.1 * dir.0).abs() < 2e-3
                && (c.dir.0 * dir.0 + c.dir.1 * dir.1) > 0.0
                && (c.rho - rho).abs() < tol
        });
        let cluster = match found {
            Some(c) => c,
            None => {
                clusters.push(Cluster {
                    dir,
                    rho,
                    origin: a,
                    segs: Vec::new(),
                });
                clusters.last_mut().unwrap()
            }
        };
        let t = |p: P2| {
            (p.0 - cluster.origin.0) * cluster.dir.0 + (p.1 - cluster.origin.1) * cluster.dir.1
        };
        let (mut t0, mut t1) = (t(a), t(b));
        if t0 > t1 {
            std::mem::swap(&mut t0, &mut t1);
        }
        cluster.segs.push(Seg {
            t0,
            t1,
            hidden: l.hidden,
        });
    }

    fn union(mut iv: Vec<(f32, f32)>, tol: f32) -> Vec<(f32, f32)> {
        iv.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap_or(std::cmp::Ordering::Equal));
        let mut out: Vec<(f32, f32)> = Vec::new();
        for (a, b) in iv {
            match out.last_mut() {
                Some(last) if a <= last.1 + tol => last.1 = last.1.max(b),
                _ => out.push((a, b)),
            }
        }
        out
    }
    fn subtract(from: &[(f32, f32)], cut: &[(f32, f32)]) -> Vec<(f32, f32)> {
        let mut out = Vec::new();
        for &(a, b) in from {
            let mut cur = a;
            for &(c, d) in cut {
                if d <= cur || c >= b {
                    continue;
                }
                if c > cur {
                    out.push((cur, c));
                }
                cur = cur.max(d);
            }
            if cur < b {
                out.push((cur, b));
            }
        }
        out
    }

    let mut out = Vec::new();
    for c in clusters {
        let vis = union(
            c.segs
                .iter()
                .filter(|s| !s.hidden)
                .map(|s| (s.t0, s.t1))
                .collect(),
            tol,
        );
        let hid = union(
            c.segs
                .iter()
                .filter(|s| s.hidden)
                .map(|s| (s.t0, s.t1))
                .collect(),
            tol,
        );
        let hid = subtract(&hid, &vis);
        let at = |t: f32| (c.origin.0 + c.dir.0 * t, c.origin.1 + c.dir.1 * t);
        for (a, b) in vis {
            if b - a > tol * 0.5 {
                out.push(Line2 {
                    a: at(a),
                    b: at(b),
                    hidden: false,
                });
            }
        }
        for (a, b) in hid {
            if b - a > tol * 0.5 {
                out.push(Line2 {
                    a: at(a),
                    b: at(b),
                    hidden: true,
                });
            }
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::solid::preset;

    fn box_solid() -> Solid {
        Solid::new(preset("rect", 40.0, 30.0).unwrap(), 20.0)
    }

    fn count(v: &View) -> (usize, usize) {
        (v.visible().count(), v.hidden().count())
    }

    fn assert_bounds(v: &View, w: f32, h: f32) {
        let (lo, hi) = v.bounds().unwrap();
        assert!(((hi.0 - lo.0) - w).abs() < 0.05, "寬 {} ≠ {w}", hi.0 - lo.0);
        assert!(((hi.1 - lo.1) - h).abs() < 0.05, "高 {} ≠ {h}", hi.1 - lo.1);
    }

    #[test]
    fn a_box_front_view_is_a_plain_rectangle() {
        let v = project(&box_solid(), &Camera::standard(StandardView::Front));
        assert_eq!(count(&v), (4, 0), "{:?}", v.lines);
        assert_bounds(&v, 40.0, 30.0);
    }

    #[test]
    fn a_box_top_view_is_width_by_depth() {
        let v = project(&box_solid(), &Camera::standard(StandardView::Top));
        assert_eq!(count(&v), (4, 0));
        assert_bounds(&v, 40.0, 20.0);
    }

    #[test]
    fn a_box_right_view_is_depth_by_height() {
        let v = project(&box_solid(), &Camera::standard(StandardView::Right));
        assert_eq!(count(&v), (4, 0));
        assert_bounds(&v, 20.0, 30.0);
    }

    #[test]
    fn a_cube_in_isometric_shows_nine_visible_and_three_hidden_edges() {
        let cube = Solid::new(preset("rect", 30.0, 30.0).unwrap(), 30.0);
        let v = project(&cube, &Camera::standard(StandardView::Iso));
        assert_eq!(count(&v), (9, 3), "{:?}", v.lines);
    }

    #[test]
    fn iso_axes_keep_their_true_length() {
        // 等角圖的三個軸都是真實長度（×√(3/2) 之後）。
        let cam = Camera::standard(StandardView::Iso);
        let o = cam.project([0.0, 0.0, 0.0]);
        for axis in [[10.0, 0.0, 0.0], [0.0, 10.0, 0.0], [0.0, 0.0, 10.0]] {
            let p = cam.project(axis);
            let len = geom::dist(o, p);
            assert!((len - 10.0).abs() < 0.01, "{axis:?} → {len}");
        }
        // X 軸往右下 30°，Z 軸往左下 30°，Y 軸直直向上。
        let x = cam.project([10.0, 0.0, 0.0]);
        let z = cam.project([0.0, 0.0, 10.0]);
        let y = cam.project([0.0, 10.0, 0.0]);
        assert!(x.0 > 0.0 && x.1 < 0.0 && ((x.1 / x.0).atan().to_degrees() + 30.0).abs() < 0.1);
        assert!(z.0 < 0.0 && z.1 < 0.0);
        assert!(y.0.abs() < 0.01 && y.1 > 0.0);
    }

    #[test]
    fn an_l_prism_right_view_has_the_step_line() {
        let l = Solid::new(preset("l_shape", 60.0, 50.0).unwrap(), 20.0);
        let v = project(&l, &Camera::standard(StandardView::Right));
        // 外框 4 條 + 台階那一條橫線。
        assert_eq!(count(&v).0, 5, "{:?}", v.lines);
    }

    #[test]
    fn a_hole_shows_as_hidden_lines_in_the_side_view() {
        let ring = Solid::new(preset("ring", 60.0, 60.0).unwrap(), 20.0);
        let side = project(&ring, &Camera::standard(StandardView::Right));
        assert_eq!(count(&side).0, 4, "外框 {:?}", side.lines);
        // 孔的上下緣：兩條隱藏線，長度＝深度。
        let hidden: Vec<&Line2> = side.hidden().collect();
        assert_eq!(hidden.len(), 2, "{hidden:?}");
        for l in hidden {
            assert!((geom::dist(l.a, l.b) - 20.0).abs() < 0.2);
        }
        // 正視圖：外圓內圓都看得見，沒有隱藏線。
        let front = project(&ring, &Camera::standard(StandardView::Front));
        assert_eq!(count(&front).1, 0);
        assert_eq!(count(&front).0, 96);
    }

    #[test]
    fn a_cylinder_side_view_is_a_plain_rectangle() {
        let c = Solid::new(preset("circle", 40.0, 40.0).unwrap(), 30.0);
        let v = project(&c, &Camera::standard(StandardView::Right));
        assert_eq!(count(&v), (4, 0), "{:?}", v.lines);
        assert_bounds(&v, 30.0, 40.0);
    }

    #[test]
    fn opposite_views_are_mirrors_with_swapped_hidden_lines() {
        // 一個非對稱零件：前面看得到的，後面看會變成隱藏。
        let l = Solid::new(preset("l_shape", 60.0, 50.0).unwrap(), 20.0);
        let front = project(&l, &Camera::standard(StandardView::Front));
        let back = project(&l, &Camera::standard(StandardView::Back));
        assert_eq!(count(&front), count(&back));
    }

    #[test]
    fn free_rotation_agrees_with_the_standard_views() {
        let s = box_solid();
        let a = project(&s, &Camera::standard(StandardView::Right));
        let b = project(&s, &Camera::free(90.0, 0.0));
        assert_eq!(count(&a), count(&b));
    }

    #[test]
    fn merging_lets_visible_cover_hidden() {
        let lines = vec![
            Line2 {
                a: (0.0, 0.0),
                b: (10.0, 0.0),
                hidden: true,
            },
            Line2 {
                a: (0.0, 0.0),
                b: (6.0, 0.0),
                hidden: false,
            },
        ];
        let m = merge_lines(lines, 0.01);
        let hid: Vec<_> = m.iter().filter(|l| l.hidden).collect();
        let vis: Vec<_> = m.iter().filter(|l| !l.hidden).collect();
        assert_eq!(vis.len(), 1);
        assert_eq!(hid.len(), 1);
        assert!((hid[0].a.0 - 6.0).abs() < 0.01 && (hid[0].b.0 - 10.0).abs() < 0.01);
    }
}
