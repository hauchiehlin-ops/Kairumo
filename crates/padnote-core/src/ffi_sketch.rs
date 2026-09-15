//! 草圖美化的平台介面。
//!
//! 演算法在 [`padnote_ink::refine`]，這裡只做型別轉換。
//! 平台層負責把美化後的座標接回自己的筆畫物件（PencilKit 的 `PKStroke`、
//! Android 的 `InkStroke`），壓感與時間戳逐點沿用原筆畫 —— 所以核心保證
//! 輸出點數與輸入相同。

use padnote_ink::refine::{RefinedKind, refine_stroke};

use crate::ffi_shapes::FfiPoint;

/// 辨識結果。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiRefinedKind {
    /// 沒認出特定圖形，只做了平滑。
    Freehand,
    Line,
    Ellipse,
    Rectangle,
}

impl From<RefinedKind> for FfiRefinedKind {
    fn from(kind: RefinedKind) -> Self {
        match kind {
            RefinedKind::Freehand => Self::Freehand,
            RefinedKind::Line => Self::Line,
            RefinedKind::Ellipse => Self::Ellipse,
            RefinedKind::Rectangle => Self::Rectangle,
        }
    }
}

/// 美化後的一筆。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiRefinedStroke {
    pub kind: FfiRefinedKind,
    /// 與輸入等長。平台層可以放心地用同一個索引去拿原筆畫的壓感。
    pub points: Vec<FfiPoint>,
}

/// 美化一筆手繪筆畫。
///
/// `intensity` 0…1（超出會夾住）：0 完全不動，1 完全採用辨識出來的圖形。
/// 建議值 0.85 —— 夠直，但還看得出是手畫的。
#[uniffi::export]
pub fn sketch_refine_stroke(points: Vec<FfiPoint>, intensity: f32) -> FfiRefinedStroke {
    let input: Vec<(f32, f32)> = points.iter().map(|p| (p.x, p.y)).collect();
    let refined = refine_stroke(&input, intensity);
    FfiRefinedStroke {
        kind: refined.kind.into(),
        points: refined.points.into_iter().map(FfiPoint::from).collect(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn circle(n: usize, jitter: f32) -> Vec<FfiPoint> {
        (0..n)
            .map(|i| {
                let a = (i as f32 / n as f32) * std::f32::consts::TAU;
                let w = if i % 2 == 0 { jitter } else { -jitter };
                FfiPoint {
                    x: 100.0 + (60.0 + w) * a.cos(),
                    y: 100.0 + (60.0 + w) * a.sin(),
                }
            })
            .collect()
    }

    #[test]
    fn the_ffi_keeps_point_order_and_count() {
        // 換型別時把 x/y 弄反或少一個點，畫出來是另一個圖形，
        // 而核心的單元測試看不到這一層。
        let input = circle(40, 4.0);
        let out = sketch_refine_stroke(input.clone(), 1.0);
        assert_eq!(out.kind, FfiRefinedKind::Ellipse);
        assert_eq!(out.points.len(), input.len());
        // 起點角度為 0，所以應落在圓心右側：x 大、y 約等於圓心。
        assert!(out.points[0].x > 100.0);
        assert!((out.points[0].y - 100.0).abs() < 1.0);
    }

    #[test]
    fn an_empty_stroke_does_not_panic() {
        // 擦除或極短點擊真的會給空陣列（Apple 端註解記過這件事）。
        let out = sketch_refine_stroke(Vec::new(), 0.85);
        assert!(out.points.is_empty());
        assert_eq!(out.kind, FfiRefinedKind::Freehand);
    }
}
