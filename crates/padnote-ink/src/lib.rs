//! 筆畫資料結構與二進位序列化。
//! 規格：`docs/format-spec.md` §5。
//!
//! **核心設計**：儲存原始取樣點，不做破壞性平滑。Catmull-Rom 擬合、寬度調變、
//! 抗鋸齒全在渲染期進行。理由是未來換渲染演算法或訓練 HWR 模型時，歷史筆記
//! 能回溯受益 —— 競品多存已擬合的貝茲曲線，資訊一去不回。

pub mod align;
pub mod codec;
pub mod geometry;
pub mod refine;

pub use align::{Alignment, SnapResult, align, distribute, snap};
pub use codec::{StrokeReader, StrokeWriter};
pub use geometry::{Rect, distance_to_segment, half_width, simplify, smooth_path};
pub use refine::{Refined, RefinedKind, refine_stroke};
pub use padnote_doc::Affine2;
use padnote_doc::{NotebookTime, Uuid};

/// 筆刷類型（format-spec §5.3）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
#[repr(u16)]
pub enum Tool {
    /// 壓感寬度
    FountainPen = 1,
    /// 固定寬度
    BallPoint = 2,
    /// 乘法混色、扁筆頭
    Highlighter = 3,
    /// 紋理
    Pencil = 4,
}

impl Tool {
    pub fn from_id(id: u16) -> Option<Self> {
        Some(match id {
            1 => Self::FountainPen,
            2 => Self::BallPoint,
            3 => Self::Highlighter,
            4 => Self::Pencil,
            _ => return None,
        })
    }

    /// 寬度是否隨壓感變化。
    pub fn is_pressure_sensitive(self) -> bool {
        matches!(self, Self::FountainPen | Self::Pencil)
    }
}

/// 一個取樣點（format-spec §5.4，序列化後 16 bytes）。
///
/// 座標為**頁面座標**而非螢幕座標，因此縮放無損。
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct InkPoint {
    pub x: f32,
    pub y: f32,
    /// 0.0–1.0
    pub pressure: f32,
    /// 0–π/2 弧度
    pub tilt: f32,
    /// 0–2π 弧度
    pub azimuth: f32,
    /// 距前一點的微秒差
    pub dt_us: u32,
}

impl InkPoint {
    pub fn new(x: f32, y: f32, pressure: f32, dt_us: u32) -> Self {
        Self {
            x,
            y,
            pressure,
            tilt: 0.0,
            azimuth: 0.0,
            dt_us,
        }
    }
}

/// 一筆畫。
#[derive(Clone, Debug)]
pub struct Stroke {
    pub id: Uuid,
    /// 筆記本時間軸上的落筆時刻 —— 與音訊共用座標系，是 C1 跳轉的依據。
    pub started_at: NotebookTime,
    pub tool: Tool,
    pub color_rgba8: [u8; 4],
    pub base_width: f32,
    pub points: Vec<InkPoint>,
}

impl Stroke {
    /// 書寫總時長。
    pub fn duration(&self) -> NotebookTime {
        NotebookTime(self.points.iter().map(|p| u64::from(p.dt_us)).sum())
    }

    /// 軸對齊外框 `(min_x, min_y, max_x, max_y)`，供 dirty rect 與套索選取使用。
    pub fn bounds(&self) -> Option<(f32, f32, f32, f32)> {
        let first = self.points.first()?;
        let mut b = (first.x, first.y, first.x, first.y);
        for p in &self.points[1..] {
            b.0 = b.0.min(p.x);
            b.1 = b.1.min(p.y);
            b.2 = b.2.max(p.x);
            b.3 = b.3.max(p.y);
        }
        Some(b)
    }
}

/// 筆畫檔中的一筆記錄。
///
/// 擦除**不刪除位元組**，而是追加 `Remove` 墓碑，藉此維持 append-only 不變式
/// （format-spec §5.2），同時讓時間軸重播與版本回溯成為可能。
#[derive(Clone, Debug)]
pub enum InkRecord {
    Add(Stroke),
    Remove(Uuid),
}

/// 套用一串記錄，得到目前可見的筆畫。
pub fn materialize(records: &[InkRecord]) -> Vec<Stroke> {
    let tombstones: std::collections::HashSet<Uuid> = records
        .iter()
        .filter_map(|r| match r {
            InkRecord::Remove(id) => Some(*id),
            InkRecord::Add(_) => None,
        })
        .collect();

    records
        .iter()
        .filter_map(|r| match r {
            InkRecord::Add(s) if !tombstones.contains(&s.id) => Some(s.clone()),
            _ => None,
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn stroke(id_byte: u8) -> Stroke {
        Stroke {
            id: Uuid::from_bytes([id_byte; 16]),
            started_at: NotebookTime(1_000_000),
            tool: Tool::FountainPen,
            color_rgba8: [0, 0, 0, 255],
            base_width: 2.0,
            points: vec![
                InkPoint::new(0.0, 0.0, 0.5, 0),
                InkPoint::new(10.0, 5.0, 0.8, 8_000),
                InkPoint::new(-3.0, 20.0, 0.6, 8_000),
            ],
        }
    }

    #[test]
    fn tombstone_hides_stroke_regardless_of_order() {
        let s = stroke(1);
        let id = s.id;
        let records = vec![InkRecord::Add(s), InkRecord::Remove(id)];
        assert!(materialize(&records).is_empty());

        // 墓碑先於新增也必須成立 —— 同步時記錄順序無法保證。
        let s2 = stroke(1);
        let reordered = vec![InkRecord::Remove(id), InkRecord::Add(s2)];
        assert!(
            materialize(&reordered).is_empty(),
            "墓碑與新增的套用順序必須可交換，否則同步無法收斂"
        );
    }

    #[test]
    fn bounds_covers_all_points() {
        let b = stroke(1).bounds().unwrap();
        assert_eq!(b, (-3.0, 0.0, 10.0, 20.0));
    }

    #[test]
    fn duration_sums_point_deltas() {
        assert_eq!(stroke(1).duration().as_micros(), 16_000);
    }

    #[test]
    fn empty_stroke_has_no_bounds() {
        let mut s = stroke(1);
        s.points.clear();
        assert!(s.bounds().is_none());
    }

    #[test]
    fn tool_roundtrips_through_id() {
        for t in [
            Tool::FountainPen,
            Tool::BallPoint,
            Tool::Highlighter,
            Tool::Pencil,
        ] {
            assert_eq!(Tool::from_id(t as u16), Some(t));
        }
        assert_eq!(Tool::from_id(999), None, "未知 tool_id 不應誤判");
    }
}
