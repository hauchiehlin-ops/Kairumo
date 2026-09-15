//! 形狀基本型（工作項 S-47）。
//!
//! 涵蓋一般繪圖形狀與 **ISO 5807 / ANSI 的流程圖符號** ——
//! 那些符號有標準語意（菱形＝判斷、平行四邊形＝輸入輸出），
//! 使用者看得懂才有意義，因此不自創圖形。
//!
//! ## 所有形狀都以外框 + 種類定義
//! 不存頂點座標，而是**存外框與種類、需要時才算出輪廓**。理由與
//! ADR-0010 相同：縮放時只改外框，輪廓重新計算，不會累積浮點誤差。

use padnote_ink::Rect;

/// 形狀種類。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ShapeKind {
    // ---- 一般形狀 ----
    Rectangle,
    RoundedRectangle,
    Ellipse,
    Triangle,
    Diamond,
    Pentagon,
    Hexagon,
    Star,
    // ---- 流程圖（ISO 5807）----
    /// 處理步驟（矩形）
    Process,
    /// 判斷（菱形）
    Decision,
    /// 起點／終點（圓角矩形）
    Terminator,
    /// 資料輸入輸出（平行四邊形）
    Data,
    /// 文件（底部波浪）
    Document,
    /// 資料庫（圓柱）
    Database,
    /// 預備／初始化（六邊形）
    Preparation,
    /// 人工輸入（梯形）
    ManualInput,
    /// 連接點（圓形）
    Connector,
    // ---- 線與箭頭 ----
    Line,
    Arrow,
    DoubleArrow,
}

impl ShapeKind {
    /// 是否為線狀（只有起點終點，沒有面積）。
    pub fn is_linear(self) -> bool {
        matches!(self, Self::Line | Self::Arrow | Self::DoubleArrow)
    }

    /// 是否為流程圖符號。UI 可據此分組顯示。
    pub fn is_flowchart(self) -> bool {
        matches!(
            self,
            Self::Process
                | Self::Decision
                | Self::Terminator
                | Self::Data
                | Self::Document
                | Self::Database
                | Self::Preparation
                | Self::ManualInput
                | Self::Connector
        )
    }

    /// 標準語意說明。流程圖符號的意義是固定的，UI 應該顯示出來 ——
    /// 使用者未必記得菱形是判斷。
    pub fn semantic(self) -> Option<&'static str> {
        Some(match self {
            Self::Process => "處理步驟",
            Self::Decision => "判斷",
            Self::Terminator => "起點／終點",
            Self::Data => "資料輸入／輸出",
            Self::Document => "文件",
            Self::Database => "資料庫",
            Self::Preparation => "預備／初始化",
            Self::ManualInput => "人工輸入",
            Self::Connector => "連接點",
            _ => return None,
        })
    }

    /// 是否能在內部放文字。線狀形狀不行。
    pub fn accepts_text(self) -> bool {
        !self.is_linear()
    }
}

/// 連接點位置。連接線接在這裡。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Anchor {
    Top,
    Right,
    Bottom,
    Left,
    Center,
}

impl Anchor {
    pub const SIDES: [Self; 4] = [Self::Top, Self::Right, Self::Bottom, Self::Left];

    /// 對向的連接點。自動選路時用來讓線從合理的一側出發。
    pub fn opposite(self) -> Self {
        match self {
            Self::Top => Self::Bottom,
            Self::Bottom => Self::Top,
            Self::Left => Self::Right,
            Self::Right => Self::Left,
            Self::Center => Self::Center,
        }
    }
}

/// 一個形狀。
#[derive(Clone, Copy, Debug)]
pub struct Shape {
    pub kind: ShapeKind,
    pub bounds: Rect,
    /// 圓角半徑（僅圓角矩形與起終點使用）。
    pub corner_radius: f32,
    /// 繞自身中心的旋轉角度（度，順時針）。
    ///
    /// **`bounds` 永遠是未旋轉的軸對齊矩形。** 旋轉只在取點時套用
    /// （`anchor_point` / `outline`）—— 把旋轉烘進 bounds 的話，
    /// 每轉一次就會把外框撐大一點，連轉幾次圖形會自己長大。
    pub rotation_degrees: f32,
}

impl Shape {
    pub fn new(kind: ShapeKind, bounds: Rect) -> Self {
        Self {
            kind,
            bounds,
            // 圓角預設取較短邊的 1/6，縮放時比例才會一致。
            corner_radius: bounds.width().min(bounds.height()) / 6.0,
            rotation_degrees: 0.0,
        }
    }

    pub fn center(&self) -> (f32, f32) {
        (
            (self.bounds.min_x + self.bounds.max_x) / 2.0,
            (self.bounds.min_y + self.bounds.max_y) / 2.0,
        )
    }

    /// 圖形是否偏離正向。
    pub fn is_rotated(&self) -> bool {
        (self.rotation_degrees % 360.0).abs() > f32::EPSILON
    }

    /// 把一個點繞圖形中心旋轉。
    fn rotate_about_center(&self, (x, y): (f32, f32)) -> (f32, f32) {
        if !self.is_rotated() {
            return (x, y);
        }
        let (cx, cy) = self.center();
        let rad = self.rotation_degrees.to_radians();
        let (sin, cos) = rad.sin_cos();
        let (dx, dy) = (x - cx, y - cy);
        (cx + dx * cos - dy * sin, cy + dx * sin + dy * cos)
    }

    /// 連接點的座標。
    ///
    /// 圖形轉過之後，連接點也要跟著轉到旋轉後的那條邊上 ——
    /// 否則線會接在圖形外面的空氣中，而且角度越大離得越遠。
    pub fn anchor_point(&self, anchor: Anchor) -> (f32, f32) {
        let (cx, cy) = self.center();
        let b = self.bounds;
        let local = match anchor {
            Anchor::Top => (cx, b.min_y),
            Anchor::Right => (b.max_x, cy),
            Anchor::Bottom => (cx, b.max_y),
            Anchor::Left => (b.min_x, cy),
            Anchor::Center => (cx, cy),
        };
        self.rotate_about_center(local)
    }

    /// 輪廓多邊形。曲線（橢圓、圓柱、文件的波浪）以線段近似。
    ///
    /// `segments` 控制曲線的細緻度。渲染用高值、命中測試用低值即可。
    /// 輪廓多邊形。**不套用旋轉。**
    ///
    /// 旋轉刻意留給平台做，理由有三個，每一個都是實際會壞的：
    ///
    /// 1. 圖形上的文字標籤是平台自己畫的。核心只轉輪廓的話，
    ///    方塊轉了、裡面的字還是正的。
    /// 2. 平台把輪廓畫在一個 `width × height` 的畫布裡。轉過的輪廓會超出
    ///    那個範圍被裁掉 —— 45° 時四個角會直接消失。
    /// 3. 平台對整個視圖套旋轉時，點擊測試也會跟著轉（SwiftUI 的
    ///    `rotationEffect`、Compose 的 `graphicsLayer` 都是）。核心先轉一次、
    ///    平台再轉一次，就是轉兩次。
    ///
    /// `anchor_point` 則相反，**必須**套用旋轉：連接線畫在兩個不同圖形之間，
    /// 端點一定要是畫布座標。
    pub fn outline(&self, segments: usize) -> Vec<(f32, f32)> {
        let b = self.bounds;
        let (w, h) = (b.width(), b.height());
        let (cx, cy) = self.center();
        let n = segments.max(8);

        match self.kind {
            ShapeKind::Rectangle | ShapeKind::Process => rect_points(b),

            ShapeKind::RoundedRectangle | ShapeKind::Terminator => {
                rounded_rect(b, self.corner_radius.min(w / 2.0).min(h / 2.0), n)
            }

            ShapeKind::Ellipse | ShapeKind::Connector => (0..n)
                .map(|i| {
                    let t = i as f32 / n as f32 * std::f32::consts::TAU;
                    (cx + w / 2.0 * t.cos(), cy + h / 2.0 * t.sin())
                })
                .collect(),

            ShapeKind::Triangle => vec![(cx, b.min_y), (b.max_x, b.max_y), (b.min_x, b.max_y)],

            ShapeKind::Diamond | ShapeKind::Decision => {
                vec![(cx, b.min_y), (b.max_x, cy), (cx, b.max_y), (b.min_x, cy)]
            }

            // 平行四邊形：上下邊各偏移寬度的 1/5
            ShapeKind::Data => {
                let d = w / 5.0;
                vec![
                    (b.min_x + d, b.min_y),
                    (b.max_x, b.min_y),
                    (b.max_x - d, b.max_y),
                    (b.min_x, b.max_y),
                ]
            }

            // 梯形（上窄下寬）
            ShapeKind::ManualInput => {
                let d = w / 5.0;
                vec![
                    (b.min_x + d, b.min_y),
                    (b.max_x - d, b.min_y),
                    (b.max_x, b.max_y),
                    (b.min_x, b.max_y),
                ]
            }

            ShapeKind::Pentagon => regular_polygon(cx, cy, w / 2.0, h / 2.0, 5),
            ShapeKind::Hexagon | ShapeKind::Preparation => {
                regular_polygon(cx, cy, w / 2.0, h / 2.0, 6)
            }

            ShapeKind::Star => (0..10)
                .map(|i| {
                    let t = i as f32 / 10.0 * std::f32::consts::TAU - std::f32::consts::FRAC_PI_2;
                    let r = if i % 2 == 0 { 1.0 } else { 0.4 };
                    (cx + w / 2.0 * r * t.cos(), cy + h / 2.0 * r * t.sin())
                })
                .collect(),

            // 文件：上緣與左右為直線，底部是波浪
            ShapeKind::Document => {
                let wave_h = h / 8.0;
                let mut p = vec![
                    (b.min_x, b.min_y),
                    (b.max_x, b.min_y),
                    (b.max_x, b.max_y - wave_h),
                ];
                for i in 0..=n {
                    let t = i as f32 / n as f32;
                    let x = b.max_x - w * t;
                    let y = b.max_y - wave_h + wave_h * (t * std::f32::consts::TAU).sin();
                    p.push((x, y));
                }
                p.push((b.min_x, b.min_y));
                p
            }

            // 圓柱：上下各一個橢圓弧
            ShapeKind::Database => {
                let ry = h / 8.0;
                let mut p = Vec::with_capacity(n * 2 + 4);
                for i in 0..=n {
                    let t = std::f32::consts::PI * i as f32 / n as f32;
                    p.push((cx - w / 2.0 * t.cos(), b.min_y + ry - ry * t.sin()));
                }
                p.push((b.max_x, b.max_y - ry));
                for i in 0..=n {
                    let t = std::f32::consts::PI * i as f32 / n as f32;
                    p.push((cx + w / 2.0 * t.cos(), b.max_y - ry + ry * t.sin()));
                }
                p.push((b.min_x, b.min_y + ry));
                p
            }

            // 線狀：從左上到右下
            ShapeKind::Line | ShapeKind::Arrow | ShapeKind::DoubleArrow => {
                vec![(b.min_x, b.min_y), (b.max_x, b.max_y)]
            }
        }
    }

    /// 點是否在形狀內（射線法）。線狀形狀改用距離判定。
    pub fn contains(&self, x: f32, y: f32, tolerance: f32) -> bool {
        if self.kind.is_linear() {
            let p = self.outline(2);
            return padnote_ink::distance_to_segment((x, y), p[0], p[1]) <= tolerance;
        }
        // 先用外框粗篩
        if !self.bounds.inflate(tolerance).contains_point(x, y) {
            return false;
        }
        point_in_polygon(x, y, &self.outline(32))
    }
}

fn rect_points(b: Rect) -> Vec<(f32, f32)> {
    vec![
        (b.min_x, b.min_y),
        (b.max_x, b.min_y),
        (b.max_x, b.max_y),
        (b.min_x, b.max_y),
    ]
}

fn rounded_rect(b: Rect, r: f32, segments: usize) -> Vec<(f32, f32)> {
    let per_corner = (segments / 4).max(2);
    let corners = [
        (b.max_x - r, b.min_y + r, -std::f32::consts::FRAC_PI_2, 0.0),
        (b.max_x - r, b.max_y - r, 0.0, std::f32::consts::FRAC_PI_2),
        (
            b.min_x + r,
            b.max_y - r,
            std::f32::consts::FRAC_PI_2,
            std::f32::consts::PI,
        ),
        (
            b.min_x + r,
            b.min_y + r,
            std::f32::consts::PI,
            1.5 * std::f32::consts::PI,
        ),
    ];

    let mut p = Vec::with_capacity(per_corner * 4);
    for (cx, cy, a0, a1) in corners {
        for i in 0..=per_corner {
            let t = a0 + (a1 - a0) * i as f32 / per_corner as f32;
            p.push((cx + r * t.cos(), cy + r * t.sin()));
        }
    }
    p
}

fn regular_polygon(cx: f32, cy: f32, rx: f32, ry: f32, sides: usize) -> Vec<(f32, f32)> {
    (0..sides)
        .map(|i| {
            let t = i as f32 / sides as f32 * std::f32::consts::TAU - std::f32::consts::FRAC_PI_2;
            (cx + rx * t.cos(), cy + ry * t.sin())
        })
        .collect()
}

/// 射線法：從該點往右射一條線，數穿過多邊形邊的次數。奇數在內、偶數在外。
fn point_in_polygon(x: f32, y: f32, poly: &[(f32, f32)]) -> bool {
    let mut inside = false;
    let n = poly.len();
    for i in 0..n {
        let (x1, y1) = poly[i];
        let (x2, y2) = poly[(i + 1) % n];
        if (y1 > y) != (y2 > y) && x < (x2 - x1) * (y - y1) / (y2 - y1) + x1 {
            inside = !inside;
        }
    }
    inside
}

#[cfg(test)]
mod tests {
    use super::*;

    fn rect() -> Rect {
        Rect::new(0.0, 0.0, 100.0, 60.0)
    }

    #[test]
    fn flowchart_symbols_carry_their_standard_meaning() {
        // 流程圖符號的語意是標準的，UI 應該顯示 —— 使用者未必記得菱形是判斷。
        assert_eq!(ShapeKind::Decision.semantic(), Some("判斷"));
        assert_eq!(ShapeKind::Data.semantic(), Some("資料輸入／輸出"));
        assert_eq!(
            ShapeKind::Rectangle.semantic(),
            None,
            "一般形狀沒有固定語意"
        );
    }

    #[test]
    fn linear_shapes_are_classified_correctly() {
        assert!(ShapeKind::Arrow.is_linear());
        assert!(!ShapeKind::Arrow.accepts_text(), "線上放不了文字");
        assert!(!ShapeKind::Process.is_linear());
        assert!(ShapeKind::Process.accepts_text());
    }

    #[test]
    fn every_shape_produces_a_usable_outline() {
        // 新增形狀卻忘記實作輪廓，這條會抓到。
        for kind in [
            ShapeKind::Rectangle,
            ShapeKind::RoundedRectangle,
            ShapeKind::Ellipse,
            ShapeKind::Triangle,
            ShapeKind::Diamond,
            ShapeKind::Pentagon,
            ShapeKind::Hexagon,
            ShapeKind::Star,
            ShapeKind::Process,
            ShapeKind::Decision,
            ShapeKind::Terminator,
            ShapeKind::Data,
            ShapeKind::Document,
            ShapeKind::Database,
            ShapeKind::Preparation,
            ShapeKind::ManualInput,
            ShapeKind::Connector,
            ShapeKind::Line,
            ShapeKind::Arrow,
            ShapeKind::DoubleArrow,
        ] {
            let outline = Shape::new(kind, rect()).outline(16);
            assert!(outline.len() >= 2, "{kind:?} 的輪廓點太少");
            assert!(
                outline.iter().all(|(x, y)| x.is_finite() && y.is_finite()),
                "{kind:?} 的輪廓含非法座標"
            );
        }
    }

    #[test]
    fn outlines_stay_within_the_bounds() {
        // 輪廓超出外框的話，選取框與實際圖形會對不上。
        for kind in [
            ShapeKind::Ellipse,
            ShapeKind::Diamond,
            ShapeKind::Hexagon,
            ShapeKind::Database,
            ShapeKind::Document,
            ShapeKind::Star,
        ] {
            let b = rect();
            for (x, y) in Shape::new(kind, b).outline(32) {
                assert!(
                    x >= b.min_x - 0.01 && x <= b.max_x + 0.01,
                    "{kind:?} 的 x={x} 超出外框"
                );
                assert!(
                    y >= b.min_y - 0.01 && y <= b.max_y + 0.01,
                    "{kind:?} 的 y={y} 超出外框"
                );
            }
        }
    }

    #[test]
    fn anchors_sit_on_the_bounding_box_edges() {
        let s = Shape::new(ShapeKind::Process, rect());
        assert_eq!(s.anchor_point(Anchor::Top), (50.0, 0.0));
        assert_eq!(s.anchor_point(Anchor::Right), (100.0, 30.0));
        assert_eq!(s.anchor_point(Anchor::Bottom), (50.0, 60.0));
        assert_eq!(s.anchor_point(Anchor::Left), (0.0, 30.0));
        assert_eq!(s.anchor_point(Anchor::Center), (50.0, 30.0));
    }

    #[test]
    fn hit_testing_respects_the_actual_outline_not_the_bounding_box() {
        // 菱形的四個角落在外框內但不在圖形內 —— 用外框判定會讓點擊很不準。
        let d = Shape::new(ShapeKind::Diamond, rect());
        assert!(d.contains(50.0, 30.0, 0.0), "中心應命中");
        assert!(!d.contains(2.0, 2.0, 0.0), "左上角在外框內但不在菱形內");
    }

    #[test]
    fn ellipse_corners_are_outside() {
        let e = Shape::new(ShapeKind::Ellipse, rect());
        assert!(e.contains(50.0, 30.0, 0.0));
        assert!(!e.contains(1.0, 1.0, 0.0));
    }

    #[test]
    fn linear_shapes_use_distance_based_hit_testing() {
        let a = Shape::new(ShapeKind::Arrow, rect());
        assert!(a.contains(50.0, 30.0, 2.0), "線上應命中");
        assert!(!a.contains(10.0, 55.0, 2.0), "遠離線段不該命中");
    }

    #[test]
    fn corner_radius_scales_with_the_shape() {
        // 固定半徑會讓小圖形看起來全圓、大圖形看起來方正。
        let small = Shape::new(ShapeKind::Terminator, Rect::new(0.0, 0.0, 30.0, 18.0));
        let large = Shape::new(ShapeKind::Terminator, Rect::new(0.0, 0.0, 300.0, 180.0));
        assert!(large.corner_radius > small.corner_radius * 5.0);
    }

    #[test]
    fn anchor_opposites_are_symmetric() {
        for a in Anchor::SIDES {
            assert_eq!(a.opposite().opposite(), a);
        }
        assert_eq!(Anchor::Center.opposite(), Anchor::Center);
    }

    #[test]
    fn degenerate_bounds_do_not_panic() {
        let flat = Rect::new(10.0, 10.0, 10.0, 10.0);
        for kind in [
            ShapeKind::Ellipse,
            ShapeKind::RoundedRectangle,
            ShapeKind::Database,
        ] {
            let outline = Shape::new(kind, flat).outline(16);
            assert!(outline.iter().all(|(x, y)| x.is_finite() && y.is_finite()));
        }
    }
}

#[cfg(test)]
mod rotation_tests {
    use super::*;

    fn square() -> Shape {
        Shape::new(
            ShapeKind::Rectangle,
            Rect {
                min_x: 0.0,
                min_y: 0.0,
                max_x: 100.0,
                max_y: 100.0,
            },
        )
    }

    fn close(a: (f32, f32), b: (f32, f32)) -> bool {
        (a.0 - b.0).abs() < 0.01 && (a.1 - b.1).abs() < 0.01
    }

    #[test]
    fn unrotated_anchors_are_unchanged() {
        let s = square();
        assert!(close(s.anchor_point(Anchor::Top), (50.0, 0.0)));
        assert!(close(s.anchor_point(Anchor::Right), (100.0, 50.0)));
    }

    #[test]
    fn rotating_90_moves_top_anchor_to_the_right_edge() {
        // 這是整個功能的重點：轉了之後「上」那個連接點要落在視覺上的右邊，
        // 不是還留在原來的位置。留在原位的話線會接到圖形外面的空氣中。
        let mut s = square();
        s.rotation_degrees = 90.0;
        assert!(close(s.anchor_point(Anchor::Top), (100.0, 50.0)));
        assert!(close(s.anchor_point(Anchor::Right), (50.0, 100.0)));
    }

    #[test]
    fn center_anchor_never_moves() {
        let mut s = square();
        s.rotation_degrees = 37.0;
        assert!(close(s.anchor_point(Anchor::Center), (50.0, 50.0)));
    }

    #[test]
    fn rotation_does_not_grow_the_bounds() {
        // bounds 永遠是未旋轉的軸對齊矩形。把旋轉烘進 bounds 的話，
        // 連轉幾次圖形會自己愈長愈大。
        let mut s = square();
        let before = s.bounds;
        s.rotation_degrees = 45.0;
        let _ = s.outline(16);
        assert_eq!(s.bounds.width(), before.width());
        assert_eq!(s.bounds.height(), before.height());
    }

    #[test]
    fn outline_is_never_rotated() {
        // 責任劃分：輪廓交給平台轉（標籤要一起轉、畫布不能裁掉四個角），
        // 連接點由核心轉（線畫在兩個圖形之間，要畫布座標）。
        // 兩邊都轉 = 轉兩次，圖形會歪到別的地方去。
        let mut s = square();
        let before = s.outline(16);
        s.rotation_degrees = 45.0;
        assert_eq!(s.outline(16), before, "outline 不該套用旋轉");
        // 但連接點要轉。
        assert!(!close(s.anchor_point(Anchor::Top), (50.0, 0.0)));
    }
}
