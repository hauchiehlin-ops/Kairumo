//! 筆畫資料結構與二進位序列化。
//! 規格：`docs/format-spec.md` §5。
//!
//! **核心設計**：儲存原始取樣點，不做破壞性平滑。Catmull-Rom 擬合、寬度調變、
//! 抗鋸齒全在渲染期進行。理由是未來換渲染演算法或訓練 HWR 模型時，歷史筆記
//! 能回溯受益 —— 競品多存已擬合的貝茲曲線，資訊一去不回。

pub mod align;
pub mod brush;
pub mod codec;
pub mod draft;
pub mod fill;
pub mod geometry;
pub mod refine;
pub mod streamline;

pub use align::{Alignment, SnapResult, align, distribute, snap};
pub use brush::{Dab, apply_line_type, dabs, dabs_styled};
pub use codec::{StrokeReader, StrokeWriter};
pub use draft::{SnapKind, Snapped, snap_direction, snap_stroke};
pub use fill::{FillOptions, FillResult, smart_fill};
pub use geometry::{
    Rect, distance_to_segment, half_width, half_width_dynamic, simplify, smooth_path,
};
pub use padnote_doc::Affine2;
use padnote_doc::{NotebookTime, Uuid};
pub use refine::{Refined, RefinedKind, refine_stroke};
pub use streamline::{
    PressureCurve, StreamlineTracker, apply_ink_tension, apply_streamline, apply_taper,
};

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
    /// 毛筆（彈性筆頭、強烈壓感）
    Brush = 5,
    /// 麥克筆（固定筆寬、色料飽和）
    Marker = 6,
    /// 水彩筆（半透擴散、隨壓感混色）
    Watercolor = 7,
    // ---- 自繪引擎的專業筆刷（見 `brush.rs`）：兩端都用同一份筆點陣算繪 ----
    /// 針筆（等寬細線）
    Fineliner = 8,
    /// 炭筆（粗糙顆粒、輕壓淡重壓濃）
    Charcoal = 9,
    /// 蠟筆（蠟質、紙紋留白）
    Crayon = 10,
    /// 噴槍（柔邊、疊加漸層）
    Airbrush = 11,
    /// 油畫筆（多根鬃毛、色澤深淺不一）
    OilPaint = 12,
    /// 書法扁頭筆（固定角度的扁筆頭，橫細豎粗）
    Calligraphy = 13,
}

impl Tool {
    pub fn from_id(id: u16) -> Option<Self> {
        Some(match id {
            1 => Self::FountainPen,
            2 => Self::BallPoint,
            3 => Self::Highlighter,
            4 => Self::Pencil,
            5 => Self::Brush,
            6 => Self::Marker,
            7 => Self::Watercolor,
            8 => Self::Fineliner,
            9 => Self::Charcoal,
            10 => Self::Crayon,
            11 => Self::Airbrush,
            12 => Self::OilPaint,
            13 => Self::Calligraphy,
            _ => return None,
        })
    }

    /// 寬度是否隨壓感變化。
    pub fn is_pressure_sensitive(self) -> bool {
        matches!(
            self,
            Self::FountainPen
                | Self::Pencil
                | Self::Brush
                | Self::Watercolor
                | Self::Charcoal
                | Self::Crayon
                | Self::Airbrush
                | Self::OilPaint
                | Self::Calligraphy
        )
    }

    /// 是否由自繪引擎（`brush.rs` 的筆點陣）算繪。
    ///
    /// PencilKit 與 Android 的既有筆刷各有自己的算繪；這幾支在兩端**沒有原生對應**，
    /// 所以由核心算出同一份筆點陣，兩端只負責把橢圓畫出來 —— 同一筆在兩台裝置上長得一樣。
    pub fn is_custom_engine(self) -> bool {
        matches!(
            self,
            Self::Fineliner
                | Self::Charcoal
                | Self::Crayon
                | Self::Airbrush
                | Self::OilPaint
                | Self::Calligraphy
        )
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
    /// 筆桿沿自身軸線的旋轉角，0–2π 弧度。
    ///
    /// **多數筆回報不出來，那時候固定是 0。** 用得到它的是扁頭筆
    /// （書法筆、麥克筆）—— 轉動筆桿會改變筆觸的寬窄方向，而那是壓感與
    /// 傾角都表達不了的一個維度。
    ///
    /// 存在**延伸區塊**裡而不是取樣點本體（見 `codec.rs` 的 `EXT_ROLL`）：
    /// 無條件多寫 2 bytes/點會讓所有人的檔案大 12.5%，而其中絕大多數的值
    /// 都是 0。
    pub roll: f32,
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
            roll: 0.0,
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
    /// 製圖圖層（0 = 沒有圖層，一般筆畫）。1 底層（原題）、2 中層（輔助線）、3 頂層（答案）。
    /// 存在延伸區塊（`codec.rs` 的 `EXT_DRAFT`）：舊裝置讀得開、只是看不到圖層。
    pub layer: u8,
    /// 工程線型（見 [`LineType`]）。0 = 實線。
    pub line_type: u8,
}

/// 工程製圖的線型。筆點陣在展開時依線型挖掉「間隔」，兩端算繪同一份。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
#[repr(u8)]
pub enum LineType {
    /// 實線（粗實線、細實線都是它，差別在筆寬）。
    Solid = 0,
    /// 隱藏線：細虛線。
    Hidden = 1,
    /// 中心線：細的長短交替的點劃線。
    Center = 2,
    /// 假想線：雙點劃線。
    Phantom = 3,
}

impl LineType {
    pub fn from_id(id: u8) -> Self {
        match id {
            1 => Self::Hidden,
            2 => Self::Center,
            3 => Self::Phantom,
            _ => Self::Solid,
        }
    }

    /// 圖樣：「畫、空、畫、空…」交替的長度（頁面單位；800 單位約 A4 的 210 mm，
    /// 1 單位 ≈ 0.26 mm）。實線回空陣列。
    pub fn pattern(self) -> &'static [f32] {
        match self {
            Self::Solid => &[],
            // 虛線：畫 3 mm、空 1 mm。
            Self::Hidden => &[12.0, 4.0],
            // 點劃線：長畫 12 mm、空 1.5 mm、短畫 1.5 mm、空 1.5 mm。
            Self::Center => &[46.0, 6.0, 5.0, 6.0],
            // 雙點劃線：長畫、空、短畫、空、短畫、空。
            Self::Phantom => &[46.0, 6.0, 5.0, 6.0, 5.0, 6.0],
        }
    }
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
            layer: 0,
            line_type: 0,
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
