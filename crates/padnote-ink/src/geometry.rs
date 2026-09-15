//! 渲染期幾何運算。
//!
//! **這裡的一切都是衍生資料** —— 持久化的永遠是原始取樣點（ADR-0002）。
//! 平滑、擬合、寬度調變、三角化全在這一層，換演算法不影響既有筆記。
//!
//! 同時供 Apple 的 Metal 管線與其他平台的 wgpu 管線使用，確保跨平台筆跡一致。

use crate::{InkPoint, Stroke, Tool};

/// 軸對齊矩形。
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Rect {
    pub min_x: f32,
    pub min_y: f32,
    pub max_x: f32,
    pub max_y: f32,
}

impl Rect {
    pub fn new(min_x: f32, min_y: f32, max_x: f32, max_y: f32) -> Self {
        Self {
            min_x,
            min_y,
            max_x,
            max_y,
        }
    }

    pub fn from_point(x: f32, y: f32) -> Self {
        Self::new(x, y, x, y)
    }

    pub fn union(self, other: Self) -> Self {
        Self {
            min_x: self.min_x.min(other.min_x),
            min_y: self.min_y.min(other.min_y),
            max_x: self.max_x.max(other.max_x),
            max_y: self.max_y.max(other.max_y),
        }
    }

    pub fn inflate(self, by: f32) -> Self {
        Self {
            min_x: self.min_x - by,
            min_y: self.min_y - by,
            max_x: self.max_x + by,
            max_y: self.max_y + by,
        }
    }

    pub fn intersects(self, other: Self) -> bool {
        self.min_x <= other.max_x
            && other.min_x <= self.max_x
            && self.min_y <= other.max_y
            && other.min_y <= self.max_y
    }

    pub fn contains_point(self, x: f32, y: f32) -> bool {
        x >= self.min_x && x <= self.max_x && y >= self.min_y && y <= self.max_y
    }

    /// 完全包住 `other`。套索選取的「完整包覆」判定。
    pub fn contains_rect(self, other: Self) -> bool {
        self.min_x <= other.min_x
            && self.min_y <= other.min_y
            && self.max_x >= other.max_x
            && self.max_y >= other.max_y
    }

    pub fn width(self) -> f32 {
        self.max_x - self.min_x
    }

    pub fn height(self) -> f32 {
        self.max_y - self.min_y
    }
}

/// 依筆刷與壓感計算半寬。
///
/// 壓感曲線刻意非線性：線性映射會讓輕壓幾乎看不見筆跡，手感很差。
pub fn half_width(tool: Tool, base_width: f32, pressure: f32) -> f32 {
    let p = pressure.clamp(0.0, 1.0);
    let scale = if tool.is_pressure_sensitive() {
        0.35 + 0.65 * p
    } else {
        1.0
    };
    base_width * 0.5 * scale
}

/// Catmull-Rom 樣條插值。`t` 在 0..=1 之間，回傳 `p1` 與 `p2` 之間的點。
pub fn catmull_rom(
    p0: (f32, f32),
    p1: (f32, f32),
    p2: (f32, f32),
    p3: (f32, f32),
    t: f32,
) -> (f32, f32) {
    let t2 = t * t;
    let t3 = t2 * t;
    let f = |a: f32, b: f32, c: f32, d: f32| {
        0.5 * ((2.0 * b)
            + (-a + c) * t
            + (2.0 * a - 5.0 * b + 4.0 * c - d) * t2
            + (-a + 3.0 * b - 3.0 * c + d) * t3)
    };
    (f(p0.0, p1.0, p2.0, p3.0), f(p0.1, p1.1, p2.1, p3.1))
}

/// 把原始取樣點插值成平滑路徑。
///
/// `subdivisions` 是每段插入的中間點數；0 等於不平滑（直接連線）。
pub fn smooth_path(points: &[InkPoint], subdivisions: usize) -> Vec<(f32, f32)> {
    if points.len() < 2 {
        return points.iter().map(|p| (p.x, p.y)).collect();
    }
    if subdivisions == 0 {
        return points.iter().map(|p| (p.x, p.y)).collect();
    }

    let at = |i: isize| -> (f32, f32) {
        let i = i.clamp(0, points.len() as isize - 1) as usize;
        (points[i].x, points[i].y)
    };

    let mut out = Vec::with_capacity(points.len() * (subdivisions + 1));
    for i in 0..points.len() - 1 {
        let (p0, p1, p2, p3) = (
            at(i as isize - 1),
            at(i as isize),
            at(i as isize + 1),
            at(i as isize + 2),
        );
        for s in 0..=subdivisions {
            let t = s as f32 / (subdivisions + 1) as f32;
            out.push(catmull_rom(p0, p1, p2, p3, t));
        }
    }
    out.push(at(points.len() as isize - 1));
    out
}

/// Ramer–Douglas–Peucker 簡化。用於降低儲存與渲染成本。
///
/// ⚠️ **只用於渲染與辨識輸入，永不寫回 `.padnote`**。原始取樣點是資產。
pub fn simplify(points: &[(f32, f32)], epsilon: f32) -> Vec<(f32, f32)> {
    if points.len() < 3 {
        return points.to_vec();
    }
    let mut keep = vec![false; points.len()];
    keep[0] = true;
    keep[points.len() - 1] = true;
    rdp(points, 0, points.len() - 1, epsilon, &mut keep);
    points
        .iter()
        .zip(&keep)
        .filter_map(|(p, &k)| k.then_some(*p))
        .collect()
}

fn rdp(pts: &[(f32, f32)], first: usize, last: usize, eps: f32, keep: &mut [bool]) {
    if last <= first + 1 {
        return;
    }
    let mut max_dist = 0.0;
    let mut index = first;
    for (i, p) in pts.iter().enumerate().take(last).skip(first + 1) {
        let d = perpendicular_distance(*p, pts[first], pts[last]);
        if d > max_dist {
            max_dist = d;
            index = i;
        }
    }
    if max_dist > eps {
        keep[index] = true;
        rdp(pts, first, index, eps, keep);
        rdp(pts, index, last, eps, keep);
    }
}

fn perpendicular_distance(p: (f32, f32), a: (f32, f32), b: (f32, f32)) -> f32 {
    let (dx, dy) = (b.0 - a.0, b.1 - a.1);
    let len_sq = dx * dx + dy * dy;
    if len_sq < 1e-12 {
        return ((p.0 - a.0).powi(2) + (p.1 - a.1).powi(2)).sqrt();
    }
    ((p.0 - a.0) * dy - (p.1 - a.1) * dx).abs() / len_sq.sqrt()
}

/// 點到線段的最短距離。橡皮擦與套索命中測試的基礎。
pub fn distance_to_segment(p: (f32, f32), a: (f32, f32), b: (f32, f32)) -> f32 {
    let (dx, dy) = (b.0 - a.0, b.1 - a.1);
    let len_sq = dx * dx + dy * dy;
    if len_sq < 1e-12 {
        return ((p.0 - a.0).powi(2) + (p.1 - a.1).powi(2)).sqrt();
    }
    // 投影參數夾在 0..1，才是「線段」而非無限延伸的直線。
    let t = (((p.0 - a.0) * dx + (p.1 - a.1) * dy) / len_sq).clamp(0.0, 1.0);
    let proj = (a.0 + t * dx, a.1 + t * dy);
    ((p.0 - proj.0).powi(2) + (p.1 - proj.1).powi(2)).sqrt()
}

/// 點是否在多邊形內（射線法，even-odd）。
///
/// 多邊形視為**自動封閉**：最後一點接回第一點。套索是使用者一筆畫出來的，
/// 起訖點幾乎不會剛好重合，不自動封閉的話那個缺口會讓射線漏出去，
/// 結果是整片選取忽有忽無。
///
/// 邊界上的點算在內（`>=`）：貼著套索邊緣的取樣點被判在外的話，
/// 使用者會看到「明明圈住了卻選不到」。
fn point_in_polygon(p: (f32, f32), polygon: &[(f32, f32)]) -> bool {
    let (x, y) = p;
    let mut inside = false;
    let n = polygon.len();
    let mut j = n - 1;
    for i in 0..n {
        let (xi, yi) = polygon[i];
        let (xj, yj) = polygon[j];
        // 只看跨越水平射線的那些邊。`(yi > y) != (yj > y)` 同時處理了
        // 「邊完全在射線上方／下方」與「水平邊」三種情況。
        if (yi > y) != (yj > y) {
            let t = (y - yi) / (yj - yi);
            if x <= xi + t * (xj - xi) {
                inside = !inside;
            }
        }
        j = i;
    }
    inside
}

impl Stroke {
    /// 外框（含筆寬）。dirty rect 與選取都該用這個，而不是純點外框 —— 否則
    /// 粗筆的邊緣會被裁掉。
    pub fn inked_bounds(&self) -> Option<Rect> {
        let mut rect: Option<Rect> = None;
        for p in &self.points {
            let hw = half_width(self.tool, self.base_width, p.pressure);
            let r = Rect::from_point(p.x, p.y).inflate(hw);
            rect = Some(match rect {
                Some(acc) => acc.union(r),
                None => r,
            });
        }
        rect
    }

    /// 橡皮擦命中測試：擦子圓心 `(x, y)` 半徑 `radius` 是否碰到這一筆。
    pub fn hit_test(&self, x: f32, y: f32, radius: f32) -> bool {
        // 先用外框粗篩，絕大多數筆畫在這裡就被排除。
        match self.inked_bounds() {
            Some(b) if b.inflate(radius).contains_point(x, y) => {}
            _ => return false,
        }

        if self.points.len() == 1 {
            let p = &self.points[0];
            let hw = half_width(self.tool, self.base_width, p.pressure);
            return ((x - p.x).powi(2) + (y - p.y).powi(2)).sqrt() <= radius + hw;
        }

        self.points.windows(2).any(|w| {
            let hw = half_width(self.tool, self.base_width, w[0].pressure);
            distance_to_segment((x, y), (w[0].x, w[0].y), (w[1].x, w[1].y)) <= radius + hw
        })
    }

    /// 套索選取：是否被 `region` 完全包覆。
    ///
    /// 用「完全包覆」而非「相交」，因為部分相交時使用者的意圖通常是不選它 ——
    /// 這與 Goodnotes / Notability 的行為一致。
    pub fn is_enclosed_by(&self, region: Rect) -> bool {
        self.inked_bounds().is_some_and(|b| region.contains_rect(b))
    }

    /// 套索選取：是否被一個**任意多邊形**完全包覆。
    ///
    /// # 為什麼不是只用外框
    ///
    /// [`is_enclosed_by`](Self::is_enclosed_by) 收的是矩形，而使用者畫出來的
    /// 套索幾乎不會是矩形。拿套索的外接矩形去判斷的話，一個 L 形的圈選會把
    /// 凹角外面的筆畫一起選進來 —— 使用者圈了兩團字，結果中間那一團
    /// 沒圈到的也被搬走了。
    ///
    /// # 判定方式
    ///
    /// 筆畫的**每一個取樣點**都要在多邊形內。用點而不是外框：粗筆的外框
    /// 會比實際墨跡大一圈，貼著套索邊緣畫的那一筆會選不到，而使用者明明
    /// 把它整條圈進去了。
    ///
    /// 空的多邊形（少於三個點）一律回 false —— 那是使用者點了一下就放開，
    /// 不是一次圈選。這時回 true 會把整頁選起來。
    pub fn is_enclosed_by_polygon(&self, polygon: &[(f32, f32)]) -> bool {
        if polygon.len() < 3 || self.points.is_empty() {
            return false;
        }
        // 外框粗篩：多邊形的外接矩形都裝不下的，不必逐點算。
        let mut hull = Rect::from_point(polygon[0].0, polygon[0].1);
        for p in &polygon[1..] {
            hull = hull.union(Rect::from_point(p.0, p.1));
        }
        match self.inked_bounds() {
            Some(b) if hull.intersects(b) => {}
            _ => return false,
        }

        self.points
            .iter()
            .all(|p| point_in_polygon((p.x, p.y), polygon))
    }

    /// 平滑後的渲染路徑。
    pub fn render_path(&self, subdivisions: usize) -> Vec<(f32, f32)> {
        smooth_path(&self.points, subdivisions)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::InkPoint;
    use padnote_doc::{NotebookTime, Uuid};

    fn stroke_from(points: Vec<InkPoint>, tool: Tool, base_width: f32) -> Stroke {
        Stroke {
            id: Uuid::from_bytes([1; 16]),
            started_at: NotebookTime::ZERO,
            tool,
            color_rgba8: [0, 0, 0, 255],
            base_width,
            points,
        }
    }

    fn horizontal_line() -> Stroke {
        stroke_from(
            vec![
                InkPoint::new(0.0, 0.0, 1.0, 0),
                InkPoint::new(100.0, 0.0, 1.0, 8_000),
            ],
            Tool::BallPoint,
            4.0,
        )
    }

    /// 一條垂直的短線，畫在 `(x, y0)` 到 `(x, y1)`。
    fn vertical_line(x: f32, y0: f32, y1: f32) -> Stroke {
        stroke_from(
            vec![
                InkPoint::new(x, y0, 1.0, 0),
                InkPoint::new(x, y1, 1.0, 8_000),
            ],
            Tool::BallPoint,
            2.0,
        )
    }

    // ---- 多邊形套索 ----

    #[test]
    fn a_stroke_inside_the_lasso_is_selected() {
        let square = [(-10.0, -10.0), (110.0, -10.0), (110.0, 10.0), (-10.0, 10.0)];
        assert!(horizontal_line().is_enclosed_by_polygon(&square));
    }

    #[test]
    fn a_stroke_outside_the_lasso_is_not() {
        let square = [(200.0, 200.0), (300.0, 200.0), (300.0, 300.0), (200.0, 300.0)];
        assert!(!horizontal_line().is_enclosed_by_polygon(&square));
    }

    #[test]
    fn a_stroke_only_half_inside_is_not_selected() {
        // 與 is_enclosed_by 同一個規則：部分相交時使用者的意圖通常是不選它。
        let square = [(-10.0, -10.0), (50.0, -10.0), (50.0, 10.0), (-10.0, 10.0)];
        assert!(!horizontal_line().is_enclosed_by_polygon(&square));
    }

    #[test]
    fn a_concave_lasso_does_not_grab_what_it_went_around() {
        // **這是矩形版本做不到的事。** L 形的套索：右下那一塊在外框裡面，
        // 但不在多邊形裡面。用外接矩形判斷的話，那裡的筆畫會被一起選走 ——
        // 使用者圈了兩團字，中間沒圈到的那一團也被搬走。
        let l_shape = [
            (0.0, 0.0),
            (100.0, 0.0),
            (100.0, 40.0),
            (40.0, 40.0),
            (40.0, 100.0),
            (0.0, 100.0),
        ];
        // 左上角的直線：在 L 的手臂裡。
        assert!(vertical_line(20.0, 10.0, 30.0).is_enclosed_by_polygon(&l_shape));
        // 右下角的直線：在外接矩形裡，但在 L 的凹角**外面**。
        assert!(!vertical_line(70.0, 60.0, 90.0).is_enclosed_by_polygon(&l_shape));
    }

    #[test]
    fn a_lasso_that_is_not_really_a_lasso_selects_nothing() {
        // 點一下就放開。回 true 的話會把整頁選起來。
        assert!(!horizontal_line().is_enclosed_by_polygon(&[]));
        assert!(!horizontal_line().is_enclosed_by_polygon(&[(0.0, 0.0), (1.0, 1.0)]));
    }

    #[test]
    fn an_open_lasso_still_closes_itself() {
        // 使用者一筆圈出來的套索，起訖點幾乎不會剛好重合。不自動封閉的話，
        // 那個缺口會讓射線漏出去，選取結果忽有忽無。
        let almost_closed = [
            (-10.0, -10.0),
            (110.0, -10.0),
            (110.0, 10.0),
            (-10.0, 10.0),
            (-10.0, -9.0), // 差一點點回到起點
        ];
        assert!(horizontal_line().is_enclosed_by_polygon(&almost_closed));
    }

    // ---- Rect ----

    #[test]
    fn rect_union_and_containment() {
        let a = Rect::new(0.0, 0.0, 10.0, 10.0);
        let b = Rect::new(5.0, 5.0, 20.0, 20.0);
        assert_eq!(a.union(b), Rect::new(0.0, 0.0, 20.0, 20.0));
        assert!(a.intersects(b));
        assert!(!a.contains_rect(b));
        assert!(Rect::new(-1.0, -1.0, 21.0, 21.0).contains_rect(b));
    }

    #[test]
    fn touching_rects_count_as_intersecting() {
        // dirty rect 合併時，邊緣相接必須算相交，否則接縫處會有殘影。
        let a = Rect::new(0.0, 0.0, 10.0, 10.0);
        let b = Rect::new(10.0, 0.0, 20.0, 10.0);
        assert!(a.intersects(b));
    }

    // ---- 寬度 ----

    #[test]
    fn pressure_only_affects_pressure_sensitive_tools() {
        assert_eq!(half_width(Tool::BallPoint, 4.0, 0.1), 2.0);
        assert_eq!(half_width(Tool::BallPoint, 4.0, 1.0), 2.0);

        let light = half_width(Tool::FountainPen, 4.0, 0.0);
        let heavy = half_width(Tool::FountainPen, 4.0, 1.0);
        assert!(heavy > light);
        assert!(light > 0.0, "輕壓仍須看得見筆跡，不可歸零");
    }

    #[test]
    fn pressure_is_clamped() {
        assert_eq!(
            half_width(Tool::FountainPen, 4.0, 5.0),
            half_width(Tool::FountainPen, 4.0, 1.0)
        );
        assert_eq!(
            half_width(Tool::FountainPen, 4.0, -3.0),
            half_width(Tool::FountainPen, 4.0, 0.0)
        );
    }

    // ---- 平滑 ----

    #[test]
    fn smoothing_preserves_endpoints() {
        let pts = vec![
            InkPoint::new(0.0, 0.0, 1.0, 0),
            InkPoint::new(10.0, 20.0, 1.0, 8_000),
            InkPoint::new(30.0, 5.0, 1.0, 8_000),
        ];
        let path = smooth_path(&pts, 4);
        assert_eq!(path.first().unwrap(), &(0.0, 0.0));
        assert_eq!(path.last().unwrap(), &(30.0, 5.0));
        assert!(path.len() > pts.len());
    }

    #[test]
    fn smoothing_a_straight_line_stays_straight() {
        let pts: Vec<InkPoint> = (0..5)
            .map(|i| InkPoint::new(i as f32 * 10.0, 0.0, 1.0, 8_000))
            .collect();
        for (_, y) in smooth_path(&pts, 3) {
            assert!(y.abs() < 1e-4, "直線不該被平滑成曲線，得到 y={y}");
        }
    }

    #[test]
    fn single_point_path_is_passthrough() {
        let pts = vec![InkPoint::new(5.0, 5.0, 1.0, 0)];
        assert_eq!(smooth_path(&pts, 8), vec![(5.0, 5.0)]);
    }

    // ---- 簡化 ----

    #[test]
    fn simplify_drops_collinear_points() {
        let line: Vec<(f32, f32)> = (0..20).map(|i| (i as f32, 0.0)).collect();
        assert_eq!(simplify(&line, 0.1), vec![(0.0, 0.0), (19.0, 0.0)]);
    }

    #[test]
    fn simplify_keeps_significant_corners() {
        let l = vec![(0.0, 0.0), (5.0, 0.0), (10.0, 0.0), (10.0, 10.0)];
        let s = simplify(&l, 0.1);
        assert!(s.contains(&(10.0, 0.0)), "轉角必須保留");
        assert!(!s.contains(&(5.0, 0.0)), "共線中點該被丟棄");
    }

    // ---- 命中測試 ----

    #[test]
    fn eraser_hits_stroke_it_touches() {
        let s = horizontal_line();
        assert!(s.hit_test(50.0, 0.0, 1.0), "正中線上必須命中");
        assert!(s.hit_test(50.0, 3.0, 1.5), "半寬 2 + 擦子 1.5 應涵蓋 y=3");
    }

    #[test]
    fn eraser_misses_distant_stroke() {
        let s = horizontal_line();
        assert!(!s.hit_test(50.0, 50.0, 1.0));
        assert!(!s.hit_test(-50.0, 0.0, 1.0), "線段外的延長線上不該命中");
    }

    #[test]
    fn hit_test_respects_segment_not_infinite_line() {
        // 這是最容易寫錯的地方：用點到直線距離會讓整條延長線都被擦到。
        let s = horizontal_line();
        assert!(!s.hit_test(500.0, 0.0, 2.0));
    }

    #[test]
    fn single_point_dot_is_erasable() {
        let dot = stroke_from(
            vec![InkPoint::new(10.0, 10.0, 1.0, 0)],
            Tool::BallPoint,
            4.0,
        );
        assert!(dot.hit_test(10.0, 10.0, 0.5));
        assert!(!dot.hit_test(30.0, 30.0, 0.5));
    }

    // ---- 套索 ----

    #[test]
    fn lasso_requires_full_enclosure() {
        let s = horizontal_line();
        assert!(s.is_enclosed_by(Rect::new(-10.0, -10.0, 110.0, 10.0)));
        // 只蓋到一半 ⇒ 不選（與 Goodnotes / Notability 行為一致）
        assert!(!s.is_enclosed_by(Rect::new(-10.0, -10.0, 50.0, 10.0)));
    }

    // ---- 外框 ----

    #[test]
    fn inked_bounds_include_stroke_width() {
        let b = horizontal_line().inked_bounds().unwrap();
        // base_width 4 ⇒ 半寬 2
        assert_eq!(b.min_y, -2.0);
        assert_eq!(b.max_y, 2.0);
        assert_eq!(b.min_x, -2.0);
        assert_eq!(b.max_x, 102.0);
    }

    #[test]
    fn empty_stroke_has_no_inked_bounds() {
        let s = stroke_from(vec![], Tool::BallPoint, 4.0);
        assert!(s.inked_bounds().is_none());
        assert!(!s.hit_test(0.0, 0.0, 100.0));
        assert!(!s.is_enclosed_by(Rect::new(-1e6, -1e6, 1e6, 1e6)));
    }

    // ---- 距離 ----

    #[test]
    fn distance_to_degenerate_segment_is_point_distance() {
        let d = distance_to_segment((3.0, 4.0), (0.0, 0.0), (0.0, 0.0));
        assert!((d - 5.0).abs() < 1e-5);
    }
}
