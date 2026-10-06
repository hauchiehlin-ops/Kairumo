//! 玻璃盒展開：把三個投影面從立體周圍的玻璃盒「掀開」成平面圖紙的動畫。
//!
//! 立體在盒子裡；三個視圖畫在盒子的三個面上（正視圖、俯視圖、右視圖）。展開就是把頂面與右面
//! 各繞著與正面共用的那條稜轉 90°，直到三個面都落在正面所在的平面上 —— 這就是三視圖的
//! 版面為什麼是那個樣子，而且投影法決定哪些面在物體的哪一側：
//!
//! | | 正視圖畫在 | 俯視圖畫在 | 右視圖畫在 | 展開之後 |
//! |---|---|---|---|---|
//! | 第三角法 | 物體**前面**的面 | 物體**上面**的面 | 物體**右邊**的面 | 俯視在上、右視在右 |
//! | 第一角法 | 物體**後面**的面 | 物體**下面**的面 | 物體**左邊**的面 | 俯視在下、右視在左 |
//!
//! 座標與立體相同：x 向右、y 向上、z 朝向正視圖的觀看者（前面 z = 0，往 −z 拉伸）。
//! `t` 是展開的進度：0 = 盒子闔著（視圖在各自的面上），1 = 全部攤平。

use crate::geom::{P2, P3};
use crate::sheet::Convention;
use crate::solid::Solid;
use crate::view::{Camera, StandardView, project};

/// 線的種類。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum GlassKind {
    /// 投影面的邊框。
    Frame,
    /// 立體本身的稜線。
    Object,
    /// 視圖上看得見的線。
    Visible,
    /// 視圖上的隱藏線。
    Hidden,
    /// 從立體的角落投射到各面的線（闔著的時候才有意義，隨展開淡出）。
    Projection,
}

#[derive(Clone, Copy, Debug)]
pub struct GlassLine {
    pub a: P3,
    pub b: P3,
    pub kind: GlassKind,
}

/// 三個視圖面。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Plane {
    Front,
    Top,
    Right,
}

/// 把一個視圖的點（該視圖自己的座標 `(u, v)`）放到玻璃盒上，`t` 是展開進度。
///
/// 視圖座標與 [`crate::view`] 的標準攝影機一致：
/// 正視 `(u, v) = (x, y)`；俯視 `(u, v) = (x, −z)`；右視 `(u, v) = (−z, y)`。
pub fn place(plane: Plane, convention: Convention, dims: P3, uv: P2, t: f32) -> P3 {
    let (w, h, d) = (dims[0], dims[1], dims[2]);
    let (u, v) = uv;
    let th = std::f32::consts::FRAC_PI_2 * t.clamp(0.0, 1.0);
    let (s, c) = th.sin_cos();
    match (convention, plane) {
        // 正面不動：第三角在 z = 0，第一角在 z = −d。
        (Convention::ThirdAngle, Plane::Front) => [u, v, 0.0],
        (Convention::FirstAngle, Plane::Front) => [u, v, -d],
        // 第三角：頂面繞 (y = h, z = 0) 的稜往上掀；右面繞 (x = w, z = 0) 的稜往右掀。
        (Convention::ThirdAngle, Plane::Top) => [u, h + v * s, -v * c],
        (Convention::ThirdAngle, Plane::Right) => [w + u * s, v, -u * c],
        // 第一角：底面繞 (y = 0, z = −d) 的稜往下掀；左面繞 (x = 0, z = −d) 的稜往左掀。
        // 離稜的距離：俯視圖的 v = 0 是物體的前面（離稜最遠 d），v = d 是後面（貼著稜）。
        (Convention::FirstAngle, Plane::Top) => {
            let r = d - v;
            [u, -r * s, -d + r * c]
        }
        (Convention::FirstAngle, Plane::Right) => {
            let r = d - u;
            [-r * s, v, -d + r * c]
        }
    }
}

fn plane_view(plane: Plane) -> StandardView {
    match plane {
        Plane::Front => StandardView::Front,
        Plane::Top => StandardView::Top,
        Plane::Right => StandardView::Right,
    }
}

/// 一個視圖面的外框（視圖座標的矩形）。
fn plane_rect(plane: Plane, dims: P3) -> [P2; 4] {
    let (w, h, d) = (dims[0], dims[1], dims[2]);
    let (a, b) = match plane {
        Plane::Front => (w, h),
        Plane::Top => (w, d),
        Plane::Right => (d, h),
    };
    [(0.0, 0.0), (a, 0.0), (a, b), (0.0, b)]
}

/// 立體在 `t` 時的全部 3D 線：盒面框、立體稜線、三個視圖的線、投射線。
pub fn lines_3d(solid: &Solid, convention: Convention, t: f32) -> Vec<GlassLine> {
    let dims = solid.dims();
    let mut out: Vec<GlassLine> = Vec::new();
    // 立體本身的稜線（只取夾角夠大的特徵邊；平面上的三角化線不算）。
    let mesh = solid.mesh();
    let cos_limit = 25f32.to_radians().cos();
    for e in &mesh.edges {
        let (n0, n1) = (mesh.faces[e.faces[0]].normal, mesh.faces[e.faces[1]].normal);
        let dot = n0[0] * n1[0] + n0[1] * n1[1] + n0[2] * n1[2];
        if e.always || dot < cos_limit {
            out.push(GlassLine {
                a: e.a,
                b: e.b,
                kind: GlassKind::Object,
            });
        }
    }
    for plane in [Plane::Front, Plane::Top, Plane::Right] {
        // 外框。
        let rect = plane_rect(plane, dims);
        for i in 0..4 {
            out.push(GlassLine {
                a: place(plane, convention, dims, rect[i], t),
                b: place(plane, convention, dims, rect[(i + 1) % 4], t),
                kind: GlassKind::Frame,
            });
        }
        // 視圖的線。
        let view = project(solid, &Camera::standard(plane_view(plane)));
        for l in &view.lines {
            out.push(GlassLine {
                a: place(plane, convention, dims, l.a, t),
                b: place(plane, convention, dims, l.b, t),
                kind: if l.hidden {
                    GlassKind::Hidden
                } else {
                    GlassKind::Visible
                },
            });
        }
    }
    // 投射線：包圍盒的八個角各投到三個面（闔著時從角落到面；展開之後仍連著，隨進度淡出由呼叫端處理）。
    for &x in &[0.0, dims[0]] {
        for &y in &[0.0, dims[1]] {
            for &z in &[0.0, -dims[2]] {
                let corner = [x, y, z];
                for (plane, uv) in [
                    (Plane::Front, (x, y)),
                    (Plane::Top, (x, -z)),
                    (Plane::Right, (-z, y)),
                ] {
                    out.push(GlassLine {
                        a: corner,
                        b: place(plane, convention, dims, uv, t),
                        kind: GlassKind::Projection,
                    });
                }
            }
        }
    }
    out
}

/// 一格動畫：線已用 `camera` 投到畫面（y 向上）。
#[derive(Clone, Debug)]
pub struct Frame {
    pub lines: Vec<(P2, P2, GlassKind)>,
}

pub fn frame(solid: &Solid, convention: Convention, t: f32, camera: &Camera) -> Frame {
    Frame {
        lines: lines_3d(solid, convention, t)
            .into_iter()
            .map(|l| (camera.project(l.a), camera.project(l.b), l.kind))
            .collect(),
    }
}

/// 整段動畫要用的畫面範圍（取幾個進度的聯集）：動畫中畫面不會忽大忽小。
pub fn bounds(solid: &Solid, convention: Convention, camera: &Camera) -> (P2, P2) {
    let (mut lo, mut hi) = ((f32::MAX, f32::MAX), (f32::MIN, f32::MIN));
    // 取樣夠密（每 1/40），畫面的邊界才不會被中間幾格超出；呼叫端再留一點邊。
    for k in 0..=40 {
        let f = frame(solid, convention, k as f32 / 40.0, camera);
        for (a, b, kind) in f.lines {
            // 投射線不算：它們延伸得很遠、也只在闔著時有意思。
            if kind == GlassKind::Projection {
                continue;
            }
            for p in [a, b] {
                lo = (lo.0.min(p.0), lo.1.min(p.1));
                hi = (hi.0.max(p.0), hi.1.max(p.1));
            }
        }
    }
    (lo, hi)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::solid::preset;

    const DIMS: P3 = [40.0, 30.0, 20.0];

    fn dist3(a: P3, b: P3) -> f32 {
        ((a[0] - b[0]).powi(2) + (a[1] - b[1]).powi(2) + (a[2] - b[2]).powi(2)).sqrt()
    }

    fn near3(a: P3, b: P3) -> bool {
        dist3(a, b) < 1e-3
    }

    #[test]
    fn closed_box_puts_each_view_on_its_own_plane() {
        // 第三角：正面 z = 0、頂面 y = h、右面 x = w。
        let c = Convention::ThirdAngle;
        assert!(near3(
            place(Plane::Front, c, DIMS, (10.0, 5.0), 0.0),
            [10.0, 5.0, 0.0]
        ));
        assert!(near3(
            place(Plane::Top, c, DIMS, (10.0, 5.0), 0.0),
            [10.0, 30.0, -5.0]
        ));
        assert!(near3(
            place(Plane::Right, c, DIMS, (5.0, 12.0), 0.0),
            [40.0, 12.0, -5.0]
        ));
        // 第一角：後面 z = −d、底面 y = 0、左面 x = 0。
        let f = Convention::FirstAngle;
        assert!(near3(
            place(Plane::Front, f, DIMS, (10.0, 5.0), 0.0),
            [10.0, 5.0, -20.0]
        ));
        assert!(near3(
            place(Plane::Top, f, DIMS, (10.0, 5.0), 0.0),
            [10.0, 0.0, -5.0]
        ));
        assert!(near3(
            place(Plane::Right, f, DIMS, (5.0, 12.0), 0.0),
            [0.0, 12.0, -5.0]
        ));
    }

    #[test]
    fn fully_unfolded_layout_is_the_standard_three_view_sheet() {
        // 第三角：俯視圖在正視圖正上方（y 從 h 到 h + d）、右視圖在正右方（x 從 w 到 w + d），全部 z = 0。
        let c = Convention::ThirdAngle;
        let top_near = place(Plane::Top, c, DIMS, (10.0, 0.0), 1.0); // v = 0：貼著稜
        let top_far = place(Plane::Top, c, DIMS, (10.0, 20.0), 1.0);
        assert!(near3(top_near, [10.0, 30.0, 0.0]) && near3(top_far, [10.0, 50.0, 0.0]));
        let right_near = place(Plane::Right, c, DIMS, (0.0, 12.0), 1.0);
        let right_far = place(Plane::Right, c, DIMS, (20.0, 12.0), 1.0);
        assert!(near3(right_near, [40.0, 12.0, 0.0]) && near3(right_far, [60.0, 12.0, 0.0]));
        // 第一角：全部落在 z = −d；俯視圖在正視圖下方（y 從 0 往下到 −d）、右視圖在左邊（x 從 0 往左到 −d）。
        let f = Convention::FirstAngle;
        let top_back = place(Plane::Top, f, DIMS, (10.0, 20.0), 1.0); // v = d：貼著稜（物體的後面）
        let top_front = place(Plane::Top, f, DIMS, (10.0, 0.0), 1.0); //  v = 0：物體的前面，離稜最遠
        assert!(near3(top_back, [10.0, 0.0, -20.0]) && near3(top_front, [10.0, -20.0, -20.0]));
        let r_back = place(Plane::Right, f, DIMS, (20.0, 12.0), 1.0);
        let r_front = place(Plane::Right, f, DIMS, (0.0, 12.0), 1.0);
        assert!(near3(r_back, [0.0, 12.0, -20.0]) && near3(r_front, [-20.0, 12.0, -20.0]));
    }

    #[test]
    fn unfolding_is_a_rigid_rotation_so_distances_inside_a_plane_never_change() {
        for conv in [Convention::ThirdAngle, Convention::FirstAngle] {
            for plane in [Plane::Top, Plane::Right] {
                let (p, q): (P2, P2) = ((3.0, 4.0), (17.0, 9.0));
                let want = ((p.0 - q.0).powi(2) + (p.1 - q.1).powi(2)).sqrt();
                for k in 0..=10 {
                    let t = k as f32 / 10.0;
                    let d = dist3(
                        place(plane, conv, DIMS, p, t),
                        place(plane, conv, DIMS, q, t),
                    );
                    assert!(
                        (d - want).abs() < 1e-3,
                        "{conv:?} {plane:?} t={t}: {d} ≠ {want}"
                    );
                }
            }
        }
    }

    #[test]
    fn the_hinge_edge_stays_put_for_the_whole_animation() {
        // 第三角：頂面貼著正面的那條稜（v = 0）永遠在 (x, h, 0)；右面的稜（u = 0）永遠在 (w, y, 0)。
        let c = Convention::ThirdAngle;
        for k in 0..=10 {
            let t = k as f32 / 10.0;
            assert!(near3(
                place(Plane::Top, c, DIMS, (12.0, 0.0), t),
                [12.0, 30.0, 0.0]
            ));
            assert!(near3(
                place(Plane::Right, c, DIMS, (0.0, 8.0), t),
                [40.0, 8.0, 0.0]
            ));
        }
        // 第一角：鉸鏈在後面板的下緣與左緣（z = −d）。
        let f = Convention::FirstAngle;
        for k in 0..=10 {
            let t = k as f32 / 10.0;
            assert!(near3(
                place(Plane::Top, f, DIMS, (12.0, 20.0), t),
                [12.0, 0.0, -20.0]
            ));
            assert!(near3(
                place(Plane::Right, f, DIMS, (20.0, 8.0), t),
                [0.0, 8.0, -20.0]
            ));
        }
    }

    #[test]
    fn the_unfolded_views_are_the_same_lines_the_standard_projection_gives() {
        // t = 1 時，正視圖的線 = 立體的正視圖在 z = 0 平面上（第三角）。
        let solid = Solid::new(preset("l_shape", 40.0, 30.0).unwrap(), 20.0);
        let lines = lines_3d(&solid, Convention::ThirdAngle, 1.0);
        let view = project(&solid, &Camera::standard(StandardView::Front));
        let vis: Vec<_> = lines
            .iter()
            .filter(|l| l.kind == GlassKind::Visible && l.a[2] == 0.0 && l.b[2] == 0.0)
            .collect();
        assert!(vis.len() >= view.visible().count(), "正視圖的實線都在");
        // 全部攤平：除了立體稜線與投射線，所有線的 z 都是 0。
        for l in lines.iter().filter(|l| {
            matches!(
                l.kind,
                GlassKind::Frame | GlassKind::Visible | GlassKind::Hidden
            )
        }) {
            assert!(
                l.a[2].abs() < 1e-3 && l.b[2].abs() < 1e-3,
                "{:?} 沒有攤平",
                l.kind
            );
        }
        // 闔著時，頂面與右面的線不在 z = 0 上（它們立著）。
        let closed = lines_3d(&solid, Convention::ThirdAngle, 0.0);
        assert!(
            closed
                .iter()
                .any(|l| l.kind == GlassKind::Visible && l.a[2] < -1.0)
        );
    }

    #[test]
    fn frames_project_to_the_screen_and_the_bounds_hold_the_whole_animation() {
        let solid = Solid::new(preset("rect", 40.0, 30.0).unwrap(), 20.0);
        let cam = Camera::free(30.0, 25.0);
        let (lo, hi) = bounds(&solid, Convention::ThirdAngle, &cam);
        assert!(hi.0 > lo.0 && hi.1 > lo.1);
        for k in 0..=10 {
            let f = frame(&solid, Convention::ThirdAngle, k as f32 / 10.0, &cam);
            assert!(!f.lines.is_empty());
            for (a, b, kind) in &f.lines {
                if *kind == GlassKind::Projection {
                    continue;
                }
                for p in [a, b] {
                    assert!(
                        p.0 >= lo.0 - 1e-3
                            && p.0 <= hi.0 + 1e-3
                            && p.1 >= lo.1 - 1e-3
                            && p.1 <= hi.1 + 1e-3,
                        "k={k} {p:?} 超出範圍"
                    );
                }
            }
        }
    }

    #[test]
    fn every_frame_has_all_the_line_kinds_the_picture_needs() {
        let solid = Solid::new(preset("u_shape", 40.0, 30.0).unwrap(), 20.0);
        let f = lines_3d(&solid, Convention::ThirdAngle, 0.5);
        for kind in [
            GlassKind::Frame,
            GlassKind::Object,
            GlassKind::Visible,
            GlassKind::Hidden,
            GlassKind::Projection,
        ] {
            assert!(f.iter().any(|l| l.kind == kind), "缺 {kind:?}");
        }
        // 三個面各一個外框（12 條）。
        assert_eq!(f.iter().filter(|l| l.kind == GlassKind::Frame).count(), 12);
        // 八個角各投到三個面。
        assert_eq!(
            f.iter().filter(|l| l.kind == GlassKind::Projection).count(),
            24
        );
    }
}
