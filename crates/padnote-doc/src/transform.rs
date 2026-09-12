//! 2D 仿射變換（ADR-0010）。
//!
//! 物件持有變換矩陣，**取樣點永不改寫**。理由見 ADR-0002／ADR-0010：
//! 直接改寫座標會讓「存原始取樣點」的性質消失，而且反覆縮放會累積
//! 浮點誤差，筆跡逐漸走樣。

/// 2×3 仿射矩陣（row-major）：
///
/// ```text
/// | a  c  tx |
/// | b  d  ty |
/// ```
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Affine2 {
    pub a: f32,
    pub b: f32,
    pub c: f32,
    pub d: f32,
    pub tx: f32,
    pub ty: f32,
}

impl Default for Affine2 {
    fn default() -> Self {
        Self::IDENTITY
    }
}

impl Affine2 {
    pub const IDENTITY: Self = Self {
        a: 1.0,
        b: 0.0,
        c: 0.0,
        d: 1.0,
        tx: 0.0,
        ty: 0.0,
    };

    pub fn translate(dx: f32, dy: f32) -> Self {
        Self {
            tx: dx,
            ty: dy,
            ..Self::IDENTITY
        }
    }

    pub fn scale(sx: f32, sy: f32) -> Self {
        Self {
            a: sx,
            d: sy,
            ..Self::IDENTITY
        }
    }

    pub fn rotate(radians: f32) -> Self {
        let (s, c) = radians.sin_cos();
        Self {
            a: c,
            b: s,
            c: -s,
            d: c,
            tx: 0.0,
            ty: 0.0,
        }
    }

    /// 以 `(cx, cy)` 為中心縮放。物件縮放時使用者期待的是這個，
    /// 而不是以原點縮放（那會讓物件同時飛走）。
    pub fn scale_around(sx: f32, sy: f32, cx: f32, cy: f32) -> Self {
        // 先把中心移到原點、縮放、再移回去。順序寫反會讓中心跟著飛走。
        Self::translate(-cx, -cy)
            .then(&Self::scale(sx, sy))
            .then(&Self::translate(cx, cy))
    }

    /// 以 `(cx, cy)` 為中心旋轉。
    pub fn rotate_around(radians: f32, cx: f32, cy: f32) -> Self {
        Self::translate(-cx, -cy)
            .then(&Self::rotate(radians))
            .then(&Self::translate(cx, cy))
    }

    /// 先套用 `self`，再套用 `other`。
    ///
    /// 命名刻意是 `then` 而不是 `mul` —— 矩陣乘法的順序是最常見的錯誤來源，
    /// 用時間順序命名讓呼叫端不必記住是左乘還右乘。
    pub fn then(&self, other: &Self) -> Self {
        Self {
            a: other.a * self.a + other.c * self.b,
            b: other.b * self.a + other.d * self.b,
            c: other.a * self.c + other.c * self.d,
            d: other.b * self.c + other.d * self.d,
            tx: other.a * self.tx + other.c * self.ty + other.tx,
            ty: other.b * self.tx + other.d * self.ty + other.ty,
        }
    }

    pub fn apply(&self, x: f32, y: f32) -> (f32, f32) {
        (
            self.a * x + self.c * y + self.tx,
            self.b * x + self.d * y + self.ty,
        )
    }

    pub fn determinant(&self) -> f32 {
        self.a * self.d - self.b * self.c
    }

    /// 反矩陣。退化（行列式為 0）時回傳 `None` —— 那代表物件被壓成一條線，
    /// 此時命中測試無從進行。
    pub fn inverse(&self) -> Option<Self> {
        let det = self.determinant();
        if det.abs() < 1e-9 {
            return None;
        }
        let inv = 1.0 / det;
        Some(Self {
            a: self.d * inv,
            b: -self.b * inv,
            c: -self.c * inv,
            d: self.a * inv,
            tx: (self.c * self.ty - self.d * self.tx) * inv,
            ty: (self.b * self.tx - self.a * self.ty) * inv,
        })
    }

    /// 變換一個軸對齊矩形的四個角，回傳新的軸對齊外框
    /// `(min_x, min_y, max_x, max_y)`。
    ///
    /// 旋轉後的矩形不再是軸對齊的，因此必須取**四個角**的外框 ——
    /// 只變換兩個對角是常見錯誤，旋轉時會得到錯的框。
    pub fn apply_bounds(
        &self,
        min_x: f32,
        min_y: f32,
        max_x: f32,
        max_y: f32,
    ) -> (f32, f32, f32, f32) {
        let corners = [
            self.apply(min_x, min_y),
            self.apply(max_x, min_y),
            self.apply(min_x, max_y),
            self.apply(max_x, max_y),
        ];
        corners.iter().fold(
            (f32::MAX, f32::MAX, f32::MIN, f32::MIN),
            |(a, b, c, d), (x, y)| (a.min(*x), b.min(*y), c.max(*x), d.max(*y)),
        )
    }

    pub fn is_identity(&self) -> bool {
        (self.a - 1.0).abs() < 1e-6
            && self.b.abs() < 1e-6
            && self.c.abs() < 1e-6
            && (self.d - 1.0).abs() < 1e-6
            && self.tx.abs() < 1e-6
            && self.ty.abs() < 1e-6
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::f32::consts::FRAC_PI_2;

    fn close(a: (f32, f32), b: (f32, f32)) -> bool {
        (a.0 - b.0).abs() < 1e-4 && (a.1 - b.1).abs() < 1e-4
    }

    #[test]
    fn identity_changes_nothing() {
        assert_eq!(Affine2::IDENTITY.apply(3.0, 4.0), (3.0, 4.0));
        assert!(Affine2::IDENTITY.is_identity());
    }

    #[test]
    fn translate_moves_points() {
        assert_eq!(Affine2::translate(10.0, -5.0).apply(1.0, 1.0), (11.0, -4.0));
    }

    #[test]
    fn scale_around_center_keeps_the_center_fixed() {
        // 以原點縮放會讓物件飛走 —— 使用者期待的是原地放大。
        let t = Affine2::scale_around(2.0, 2.0, 50.0, 50.0);
        assert!(close(t.apply(50.0, 50.0), (50.0, 50.0)), "中心必須不動");
        assert!(close(t.apply(60.0, 50.0), (70.0, 50.0)));
    }

    #[test]
    fn rotate_around_center_keeps_the_center_fixed() {
        let t = Affine2::rotate_around(FRAC_PI_2, 10.0, 10.0);
        assert!(close(t.apply(10.0, 10.0), (10.0, 10.0)));
        assert!(close(t.apply(20.0, 10.0), (10.0, 20.0)), "90 度旋轉");
    }

    #[test]
    fn then_applies_in_time_order() {
        // 先平移再縮放 ≠ 先縮放再平移。命名為 `then` 就是為了避免這個錯誤。
        let a = Affine2::translate(10.0, 0.0).then(&Affine2::scale(2.0, 1.0));
        let b = Affine2::scale(2.0, 1.0).then(&Affine2::translate(10.0, 0.0));

        assert!(close(a.apply(0.0, 0.0), (20.0, 0.0)), "先平移再縮放");
        assert!(close(b.apply(0.0, 0.0), (10.0, 0.0)), "先縮放再平移");
    }

    #[test]
    fn inverse_undoes_the_transform() {
        let t = Affine2::translate(5.0, 3.0)
            .then(&Affine2::scale(2.0, 3.0))
            .then(&Affine2::rotate(0.7));
        let inv = t.inverse().expect("可逆");

        let p = (12.0, -7.0);
        let round = inv.apply(t.apply(p.0, p.1).0, t.apply(p.0, p.1).1);
        assert!(close(round, p), "反變換必須還原：{round:?}");
    }

    #[test]
    fn degenerate_transform_has_no_inverse() {
        // 物件被壓成一條線時無法做命中測試。
        assert!(Affine2::scale(0.0, 1.0).inverse().is_none());
        assert!(Affine2::scale(1.0, 0.0).inverse().is_none());
    }

    #[test]
    fn rotated_bounds_use_all_four_corners() {
        // 只變換兩個對角是常見錯誤，旋轉時會得到錯的框。
        let (min_x, min_y, max_x, max_y) =
            Affine2::rotate(FRAC_PI_2).apply_bounds(0.0, 0.0, 10.0, 4.0);

        assert!((max_x - min_x - 4.0).abs() < 1e-4, "旋轉 90 度後寬高互換");
        assert!((max_y - min_y - 10.0).abs() < 1e-4);
    }

    #[test]
    fn repeated_scaling_stays_within_bounded_error() {
        // ADR-0010 的核心：反覆縮放只改矩陣，取樣點永遠不動。
        //
        // 矩陣本身會累積浮點誤差，但誤差是**有界的**（只來自 200 次乘法）。
        // 若改為直接改寫座標，誤差會隨每次縮放疊加到資料上且無法回復 ——
        // 這正是不改寫取樣點的理由。
        let mut t = Affine2::IDENTITY;
        for _ in 0..100 {
            t = t.then(&Affine2::scale(1.01, 1.01));
        }
        for _ in 0..100 {
            t = t.then(&Affine2::scale(1.0 / 1.01, 1.0 / 1.01));
        }

        let source = (123.456_f32, 789.012_f32);
        let p = t.apply(source.0, source.1);
        let relative = ((p.0 - source.0) / source.0)
            .abs()
            .max(((p.1 - source.1) / source.1).abs());
        assert!(relative < 1e-5, "相對誤差 {relative:e} 過大：{p:?}");
    }

    #[test]
    fn determinant_reflects_area_change() {
        assert!((Affine2::scale(2.0, 3.0).determinant() - 6.0).abs() < 1e-5);
        assert!(
            (Affine2::rotate(1.0).determinant() - 1.0).abs() < 1e-5,
            "旋轉不改變面積"
        );
    }
}
