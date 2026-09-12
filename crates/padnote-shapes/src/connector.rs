//! 連接線（S-47）。
//!
//! 流程圖的價值在於**線會跟著圖形走**。把箭頭畫成獨立的線，
//! 移動方塊時線就斷了 —— 那只是畫圖，不是流程圖。
//!
//! 因此連接線存的是「從哪個圖形的哪個連接點，到哪個圖形的哪個連接點」，
//! 路徑在渲染時才算出來。

use crate::shape::{Anchor, Shape};

/// 走線方式。
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub enum RouteStyle {
    /// 直線。
    Straight,
    /// 直角折線。流程圖的慣例 —— 直角比斜線容易讀。
    #[default]
    Orthogonal,
}

/// 端點樣式。
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub enum EndCap {
    #[default]
    None,
    Arrow,
    /// 空心箭頭（繼承、泛化）
    HollowArrow,
    Circle,
    Diamond,
}

/// 一條連接線。
#[derive(Clone, Copy, Debug)]
pub struct Connection {
    pub from_anchor: Anchor,
    pub to_anchor: Anchor,
    pub route: RouteStyle,
    pub start_cap: EndCap,
    pub end_cap: EndCap,
}

impl Default for Connection {
    fn default() -> Self {
        Self {
            from_anchor: Anchor::Bottom,
            to_anchor: Anchor::Top,
            route: RouteStyle::default(),
            start_cap: EndCap::None,
            // 流程圖的線幾乎都有方向，預設帶箭頭。
            end_cap: EndCap::Arrow,
        }
    }
}

impl Connection {
    /// 算出連接線的路徑。
    pub fn path(&self, from: &Shape, to: &Shape) -> Vec<(f32, f32)> {
        let start = from.anchor_point(self.from_anchor);
        let end = to.anchor_point(self.to_anchor);

        match self.route {
            RouteStyle::Straight => vec![start, end],
            RouteStyle::Orthogonal => orthogonal(start, self.from_anchor, end, self.to_anchor),
        }
    }

    /// 依兩個圖形的相對位置自動選連接點。
    ///
    /// 使用者拖出一條線時不該還要選「從下面出去、從上面進來」——
    /// 那應該自己判斷。
    pub fn auto_anchors(from: &Shape, to: &Shape) -> (Anchor, Anchor) {
        let (fx, fy) = from.center();
        let (tx, ty) = to.center();
        let (dx, dy) = (tx - fx, ty - fy);

        // 水平距離大就走左右，否則走上下。
        if dx.abs() > dy.abs() {
            if dx > 0.0 {
                (Anchor::Right, Anchor::Left)
            } else {
                (Anchor::Left, Anchor::Right)
            }
        } else if dy > 0.0 {
            (Anchor::Bottom, Anchor::Top)
        } else {
            (Anchor::Top, Anchor::Bottom)
        }
    }

    /// 建立一條自動選點的連接線。
    pub fn between(from: &Shape, to: &Shape) -> Self {
        let (from_anchor, to_anchor) = Self::auto_anchors(from, to);
        Self {
            from_anchor,
            to_anchor,
            ..Self::default()
        }
    }
}

/// 直角折線。
///
/// 從連接點先**往外走一段**再轉彎 —— 直接從邊上轉彎的話，
/// 線會貼著圖形邊緣，看起來像是穿過去的。
fn orthogonal(start: (f32, f32), from: Anchor, end: (f32, f32), to: Anchor) -> Vec<(f32, f32)> {
    /// 離開圖形的最小距離。
    const STUB: f32 = 12.0;

    let s = offset(start, from, STUB);
    let e = offset(end, to, STUB);

    let mut path = vec![start, s];

    // 依出發方向決定先走水平還是垂直。
    let vertical_first = matches!(from, Anchor::Top | Anchor::Bottom);
    if vertical_first {
        let mid_y = (s.1 + e.1) / 2.0;
        path.push((s.0, mid_y));
        path.push((e.0, mid_y));
    } else {
        let mid_x = (s.0 + e.0) / 2.0;
        path.push((mid_x, s.1));
        path.push((mid_x, e.1));
    }

    path.push(e);
    path.push(end);
    dedup(path)
}

fn offset(p: (f32, f32), anchor: Anchor, d: f32) -> (f32, f32) {
    match anchor {
        Anchor::Top => (p.0, p.1 - d),
        Anchor::Bottom => (p.0, p.1 + d),
        Anchor::Left => (p.0 - d, p.1),
        Anchor::Right => (p.0 + d, p.1),
        Anchor::Center => p,
    }
}

/// 去掉重複的相鄰點。折線在兩點對齊時會退化成同一點，
/// 留著會讓渲染端算出零長度的線段。
fn dedup(points: Vec<(f32, f32)>) -> Vec<(f32, f32)> {
    let mut out: Vec<(f32, f32)> = Vec::with_capacity(points.len());
    for p in points {
        if out
            .last()
            .is_none_or(|l| (l.0 - p.0).abs() > 1e-4 || (l.1 - p.1).abs() > 1e-4)
        {
            out.push(p);
        }
    }
    out
}

/// 箭頭的三角形頂點。
///
/// `tip` 是箭尖，`from` 是線上的前一點（決定方向）。
pub fn arrow_head(tip: (f32, f32), from: (f32, f32), size: f32) -> Vec<(f32, f32)> {
    let (dx, dy) = (tip.0 - from.0, tip.1 - from.1);
    let len = (dx * dx + dy * dy).sqrt();
    if len < 1e-5 {
        return Vec::new();
    }
    let (ux, uy) = (dx / len, dy / len);
    // 垂直向量
    let (px, py) = (-uy, ux);
    let base = (tip.0 - ux * size, tip.1 - uy * size);
    let half = size * 0.4;

    vec![
        tip,
        (base.0 + px * half, base.1 + py * half),
        (base.0 - px * half, base.1 - py * half),
    ]
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::shape::ShapeKind;
    use padnote_ink::Rect;

    fn shape_at(x: f32, y: f32) -> Shape {
        Shape::new(ShapeKind::Process, Rect::new(x, y, x + 80.0, y + 40.0))
    }

    #[test]
    fn straight_route_is_two_points() {
        let (a, b) = (shape_at(0.0, 0.0), shape_at(0.0, 200.0));
        let c = Connection {
            route: RouteStyle::Straight,
            ..Connection::default()
        };
        assert_eq!(c.path(&a, &b).len(), 2);
    }

    #[test]
    fn orthogonal_route_only_turns_at_right_angles() {
        // 流程圖的慣例是直角 —— 斜線難讀。
        let (a, b) = (shape_at(0.0, 0.0), shape_at(150.0, 200.0));
        let path = Connection::default().path(&a, &b);

        for w in path.windows(2) {
            let (dx, dy) = (w[1].0 - w[0].0, w[1].1 - w[0].1);
            assert!(
                dx.abs() < 1e-3 || dy.abs() < 1e-3,
                "線段 {w:?} 不是水平也不是垂直"
            );
        }
    }

    #[test]
    fn route_starts_and_ends_at_the_anchors() {
        let (a, b) = (shape_at(0.0, 0.0), shape_at(0.0, 200.0));
        let c = Connection::default();
        let path = c.path(&a, &b);

        assert_eq!(path[0], a.anchor_point(c.from_anchor));
        assert_eq!(*path.last().unwrap(), b.anchor_point(c.to_anchor));
    }

    #[test]
    fn route_leaves_the_shape_before_turning() {
        // 直接從邊上轉彎的話，線會貼著圖形邊緣，看起來像穿過去的。
        let (a, b) = (shape_at(0.0, 0.0), shape_at(150.0, 200.0));
        let path = Connection::default().path(&a, &b);

        let start = path[0];
        let second = path[1];
        assert!(
            (second.1 - start.1).abs() >= 10.0,
            "離開圖形前應先走一小段：{start:?} → {second:?}"
        );
    }

    #[test]
    fn auto_anchors_pick_the_facing_sides() {
        // 使用者拖線時不該還要選從哪一側出去。
        let origin = shape_at(0.0, 0.0);

        let below = shape_at(0.0, 300.0);
        assert_eq!(
            Connection::auto_anchors(&origin, &below),
            (Anchor::Bottom, Anchor::Top)
        );

        let right = shape_at(300.0, 0.0);
        assert_eq!(
            Connection::auto_anchors(&origin, &right),
            (Anchor::Right, Anchor::Left)
        );

        let above = shape_at(0.0, -300.0);
        assert_eq!(
            Connection::auto_anchors(&origin, &above),
            (Anchor::Top, Anchor::Bottom)
        );
    }

    #[test]
    fn connection_follows_the_shapes_when_they_move() {
        // 這是流程圖與「畫一堆線」的差別。
        let a = shape_at(0.0, 0.0);
        let c = Connection::default();

        let near = c.path(&a, &shape_at(0.0, 200.0));
        let far = c.path(&a, &shape_at(0.0, 500.0));

        assert_ne!(near, far, "目標移動後路徑必須跟著變");
        assert_eq!(near[0], far[0], "起點不變");
    }

    #[test]
    fn aligned_shapes_produce_no_zero_length_segments() {
        // 折線在對齊時會退化成同一點，留著會讓渲染算出零長度線段。
        let (a, b) = (shape_at(0.0, 0.0), shape_at(0.0, 200.0));
        let path = Connection::default().path(&a, &b);

        for w in path.windows(2) {
            let d = ((w[1].0 - w[0].0).powi(2) + (w[1].1 - w[0].1).powi(2)).sqrt();
            assert!(d > 1e-3, "出現零長度線段：{w:?}");
        }
    }

    #[test]
    fn arrow_head_points_along_the_line() {
        let head = arrow_head((100.0, 0.0), (0.0, 0.0), 10.0);
        assert_eq!(head.len(), 3);
        assert_eq!(head[0], (100.0, 0.0), "第一點是箭尖");
        // 另外兩點應在箭尖後方
        assert!(head[1].0 < 100.0 && head[2].0 < 100.0);
    }

    #[test]
    fn arrow_head_of_zero_length_line_is_empty() {
        assert!(arrow_head((5.0, 5.0), (5.0, 5.0), 10.0).is_empty());
    }

    #[test]
    fn default_connection_has_an_arrow() {
        // 流程圖的線幾乎都有方向。
        assert_eq!(Connection::default().end_cap, EndCap::Arrow);
        assert_eq!(Connection::default().start_cap, EndCap::None);
    }
}
