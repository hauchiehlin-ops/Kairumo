//! PDF 標註的雙向保真（工作項 S-42，ADR-0008 第一層）。
//!
//! ## 為什麼這是互通的核心
//! 市調的 10 款競品**全部都能讀寫 PDF 標註**。專有格式各家不通、
//! 也沒有人會讀 `.padnote`，因此 PDF 是唯一真正雙向的交換途徑。
//!
//! 「匯出成 PDF」不等於互通 —— 把筆跡烤進頁面圖像的話，
//! 對方只能看不能改。**要互通就必須寫成標準的 PDF annotation。**
//!
//! ## 座標系差異是最大的陷阱
//! | 系統 | 原點 | Y 軸 |
//! |---|---|---|
//! | Padnote 頁面座標 | 左上 | 向下 |
//! | PDF 使用者空間 | 左下 | 向上 |
//!
//! 忘記翻轉 Y 的結果是標註上下顛倒，而且**在自己的 App 裡看起來正常** ——
//! 因為匯出與匯入用了同一個錯誤的轉換。只有在別的 App 打開才會發現。
//! 因此本模組的往返測試刻意同時檢查**絕對座標**，而不只是往返一致。

use padnote_doc::NotebookTime;
use padnote_ink::{InkPoint, Stroke, Tool};

/// PDF 標註類型（PDF 32000-1 §12.5.6）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum AnnotationKind {
    /// 手寫筆跡。對應 `/Subtype /Ink`。
    Ink,
    /// 螢光筆。對應 `/Subtype /Highlight`。
    Highlight,
    Underline,
    StrikeOut,
    Squiggly,
    /// 便利貼。對應 `/Subtype /Text`。
    Note,
    /// 文字方塊。對應 `/Subtype /FreeText`。
    FreeText,
}

impl AnnotationKind {
    /// PDF 的 `/Subtype` 名稱。
    pub fn subtype(self) -> &'static str {
        match self {
            Self::Ink => "Ink",
            Self::Highlight => "Highlight",
            Self::Underline => "Underline",
            Self::StrikeOut => "StrikeOut",
            Self::Squiggly => "Squiggly",
            Self::Note => "Text",
            Self::FreeText => "FreeText",
        }
    }

    pub fn from_subtype(s: &str) -> Option<Self> {
        Some(match s {
            "Ink" => Self::Ink,
            "Highlight" => Self::Highlight,
            "Underline" => Self::Underline,
            "StrikeOut" => Self::StrikeOut,
            "Squiggly" => Self::Squiggly,
            "Text" => Self::Note,
            "FreeText" => Self::FreeText,
            _ => return None,
        })
    }

    /// 是否使用 `QuadPoints`（文字標記類標註）。
    pub fn uses_quad_points(self) -> bool {
        matches!(
            self,
            Self::Highlight | Self::Underline | Self::StrikeOut | Self::Squiggly
        )
    }
}

/// 一個 PDF 標註。
#[derive(Clone, Debug, PartialEq)]
pub struct PdfAnnotation {
    pub kind: AnnotationKind,
    /// 頁碼（0 起算）。
    pub page_index: u32,
    /// PDF 使用者空間的筆畫路徑（`/InkList`）。`Ink` 類型使用。
    pub ink_paths: Vec<Vec<(f32, f32)>>,
    /// PDF 使用者空間的四點座標（`/QuadPoints`）。文字標記類使用。
    pub quad_points: Vec<[f32; 8]>,
    /// RGB 0–1（PDF 的 `/C` 是 0–1 不是 0–255）。
    pub color: [f32; 3],
    /// 不透明度（`/CA`）。
    pub opacity: f32,
    /// 線寬（`/BS /W`）。
    pub width: f32,
    /// 註記內容（`/Contents`）。
    pub contents: String,
}

impl PdfAnnotation {
    /// 邊界框（`/Rect`）。
    ///
    /// PDF 要求 `/Rect` 必須包住整個標註，否則部分檢視器會裁掉超出的部分。
    /// 因此線寬也要算進去。
    pub fn rect(&self) -> (f32, f32, f32, f32) {
        let mut bounds: Option<(f32, f32, f32, f32)> = None;
        let mut extend = |x: f32, y: f32| {
            bounds = Some(match bounds {
                Some((a, b, c, d)) => (a.min(x), b.min(y), c.max(x), d.max(y)),
                None => (x, y, x, y),
            });
        };

        for path in &self.ink_paths {
            for (x, y) in path {
                extend(*x, *y);
            }
        }
        for q in &self.quad_points {
            for i in 0..4 {
                extend(q[i * 2], q[i * 2 + 1]);
            }
        }

        let pad = self.width / 2.0;
        bounds.map_or((0.0, 0.0, 0.0, 0.0), |(a, b, c, d)| {
            (a - pad, b - pad, c + pad, d + pad)
        })
    }
}

/// 頁面座標（左上原點、Y 向下）與 PDF 使用者空間（左下原點、Y 向上）的轉換。
///
/// **這是 PDF 標註最常見的錯誤來源。** 忘記翻轉 Y 會讓標註上下顛倒，
/// 而且在自己的 App 裡看起來正常 —— 因為匯出與匯入用了同一個錯誤的轉換。
#[derive(Clone, Copy, Debug)]
pub struct PageMapping {
    /// PDF 頁面高度（點）。
    pub page_height: f32,
    /// 頁面座標對 PDF 點的比例。1.0 表示 1 頁面單位 = 1 PDF 點。
    pub scale: f32,
}

impl PageMapping {
    pub fn new(page_height: f32) -> Self {
        Self {
            page_height,
            scale: 1.0,
        }
    }

    /// 頁面座標 → PDF 使用者空間。
    pub fn to_pdf(&self, x: f32, y: f32) -> (f32, f32) {
        (x * self.scale, self.page_height - y * self.scale)
    }

    /// PDF 使用者空間 → 頁面座標。
    pub fn to_page(&self, x: f32, y: f32) -> (f32, f32) {
        (x / self.scale, (self.page_height - y) / self.scale)
    }
}

/// 把筆畫轉成 PDF 的 Ink 標註。
///
/// 用 `/Ink` 而非把筆跡烤進頁面：**烤進去對方只能看不能改**，
/// 那不叫互通。
pub fn stroke_to_annotation(stroke: &Stroke, page_index: u32, map: &PageMapping) -> PdfAnnotation {
    let path: Vec<(f32, f32)> = stroke.points.iter().map(|p| map.to_pdf(p.x, p.y)).collect();

    PdfAnnotation {
        // 螢光筆在 PDF 裡也是 Ink —— `/Highlight` 需要文字層的 QuadPoints，
        // 而手繪的螢光筆並不貼齊文字。用半透明的 Ink 才能忠實重現形狀。
        kind: AnnotationKind::Ink,
        page_index,
        ink_paths: vec![path],
        quad_points: Vec::new(),
        color: [
            f32::from(stroke.color_rgba8[0]) / 255.0,
            f32::from(stroke.color_rgba8[1]) / 255.0,
            f32::from(stroke.color_rgba8[2]) / 255.0,
        ],
        opacity: f32::from(stroke.color_rgba8[3]) / 255.0,
        width: stroke.base_width * map.scale,
        contents: String::new(),
    }
}

/// 把 PDF 的 Ink 標註轉回筆畫。
///
/// 壓感、傾斜、時間戳在 PDF 裡沒有對應欄位，**必然遺失** ——
/// 這是 PDF 互通的固有代價，不是實作缺陷。壓感填中間值讓線寬均勻。
pub fn annotation_to_strokes(
    annotation: &PdfAnnotation,
    map: &PageMapping,
    id_source: impl Fn() -> padnote_doc::Uuid,
) -> Vec<Stroke> {
    if annotation.kind != AnnotationKind::Ink {
        return Vec::new();
    }
    annotation
        .ink_paths
        .iter()
        .filter(|p| !p.is_empty())
        .map(|path| Stroke {
            id: id_source(),
            started_at: NotebookTime::ZERO,
            tool: if annotation.opacity < 0.9 {
                Tool::Highlighter
            } else {
                Tool::BallPoint
            },
            color_rgba8: [
                (annotation.color[0] * 255.0).round() as u8,
                (annotation.color[1] * 255.0).round() as u8,
                (annotation.color[2] * 255.0).round() as u8,
                (annotation.opacity * 255.0).round() as u8,
            ],
            base_width: annotation.width / map.scale,
            points: path
                .iter()
                .map(|(x, y)| {
                    let (px, py) = map.to_page(*x, *y);
                    // PDF 沒有壓感與時間資訊，填中間值讓線寬均勻。
                    InkPoint::new(px, py, 0.5, 0)
                })
                .collect(),
        })
        .collect()
}

/// 從文字區塊的矩形產生 Highlight 標註的 `QuadPoints`。
///
/// PDF 的 QuadPoints 順序是**左上、右上、左下、右下** ——
/// 不是順時針也不是逆時針。順序寫錯的話部分檢視器會顯示成扭曲的四邊形。
pub fn quad_points_for_rect(x0: f32, y0: f32, x1: f32, y1: f32, map: &PageMapping) -> [f32; 8] {
    let (lx, ty) = map.to_pdf(x0, y0);
    let (rx, by) = map.to_pdf(x1, y1);
    [lx, ty, rx, ty, lx, by, rx, by]
}

#[cfg(test)]
mod tests {
    use super::*;
    use padnote_doc::Uuid;

    const PAGE_HEIGHT: f32 = 842.0; // A4

    fn map() -> PageMapping {
        PageMapping::new(PAGE_HEIGHT)
    }

    fn stroke() -> Stroke {
        Stroke {
            id: Uuid::from_bytes([1; 16]),
            started_at: NotebookTime::from_micros(1_000_000),
            tool: Tool::BallPoint,
            color_rgba8: [255, 0, 0, 255],
            base_width: 3.0,
            points: vec![
                InkPoint::new(100.0, 50.0, 0.5, 0),
                InkPoint::new(200.0, 150.0, 0.8, 8_000),
            ],
        }
    }

    #[test]
    fn y_axis_is_flipped_between_the_two_coordinate_systems() {
        // 忘記翻轉 Y 是 PDF 標註最常見的錯誤，而且在自己的 App 裡看不出來。
        let m = map();
        assert_eq!(m.to_pdf(100.0, 0.0), (100.0, 842.0), "頁面頂端 = PDF 頂端");
        assert_eq!(m.to_pdf(100.0, 842.0), (100.0, 0.0), "頁面底端 = PDF 原點");
    }

    #[test]
    fn coordinate_mapping_round_trips() {
        let m = map();
        let (x, y) = m.to_pdf(123.0, 456.0);
        let back = m.to_page(x, y);
        assert!((back.0 - 123.0).abs() < 1e-4 && (back.1 - 456.0).abs() < 1e-4);
    }

    #[test]
    fn stroke_becomes_an_ink_annotation_with_absolute_coordinates() {
        // 只測往返一致是不夠的 —— 匯出與匯入用同一個錯誤轉換時往返仍會通過。
        let a = stroke_to_annotation(&stroke(), 0, &map());

        assert_eq!(a.kind, AnnotationKind::Ink);
        assert_eq!(a.ink_paths.len(), 1);
        assert_eq!(a.ink_paths[0][0], (100.0, 792.0), "842 - 50 = 792");
        assert_eq!(a.ink_paths[0][1], (200.0, 692.0));
    }

    #[test]
    fn colour_is_converted_to_the_pdf_zero_to_one_range() {
        // PDF 的 /C 是 0–1 不是 0–255。填錯會變成全白或超出範圍。
        let a = stroke_to_annotation(&stroke(), 0, &map());
        assert_eq!(a.color, [1.0, 0.0, 0.0]);
        assert_eq!(a.opacity, 1.0);
    }

    #[test]
    fn stroke_round_trips_through_the_annotation() {
        let original = stroke();
        let a = stroke_to_annotation(&original, 0, &map());
        let back = annotation_to_strokes(&a, &map(), Uuid::now_v7);

        assert_eq!(back.len(), 1);
        assert_eq!(back[0].points.len(), original.points.len());
        for (got, want) in back[0].points.iter().zip(&original.points) {
            assert!((got.x - want.x).abs() < 1e-3, "x 應還原");
            assert!((got.y - want.y).abs() < 1e-3, "y 應還原");
        }
        assert_eq!(back[0].color_rgba8, original.color_rgba8);
        assert!((back[0].base_width - original.base_width).abs() < 1e-4);
    }

    #[test]
    fn pressure_and_timing_are_lost_and_that_is_expected() {
        // PDF 沒有對應欄位。這是互通的固有代價，不是實作缺陷 ——
        // 寫成測試是為了讓下一個人知道這不是 bug。
        let a = stroke_to_annotation(&stroke(), 0, &map());
        let back = annotation_to_strokes(&a, &map(), Uuid::now_v7);

        assert!(
            back[0].points.iter().all(|p| p.pressure == 0.5),
            "壓感填中間值"
        );
        assert_eq!(back[0].started_at, NotebookTime::ZERO, "時間戳無從還原");
    }

    #[test]
    fn translucent_annotations_come_back_as_highlighter() {
        let mut s = stroke();
        s.color_rgba8 = [255, 255, 0, 128];
        let a = stroke_to_annotation(&s, 0, &map());
        let back = annotation_to_strokes(&a, &map(), Uuid::now_v7);
        assert_eq!(back[0].tool, Tool::Highlighter);
    }

    #[test]
    fn rect_includes_the_stroke_width() {
        // /Rect 沒包住整個標註時，部分檢視器會裁掉超出的部分。
        let a = stroke_to_annotation(&stroke(), 0, &map());
        let (x0, y0, x1, y1) = a.rect();
        assert!(x0 < 100.0 && y0 < 692.0, "邊界要往外擴半個線寬");
        assert!(x1 > 200.0 && y1 > 792.0);
    }

    #[test]
    fn quad_points_follow_the_pdf_ordering() {
        // PDF 的順序是左上、右上、左下、右下 —— 不是順時針也不是逆時針。
        let q = quad_points_for_rect(10.0, 20.0, 110.0, 40.0, &map());
        let (top, bottom) = (842.0 - 20.0, 842.0 - 40.0);
        assert_eq!(q, [10.0, top, 110.0, top, 10.0, bottom, 110.0, bottom]);
    }

    #[test]
    fn subtype_names_round_trip() {
        for k in [
            AnnotationKind::Ink,
            AnnotationKind::Highlight,
            AnnotationKind::Underline,
            AnnotationKind::StrikeOut,
            AnnotationKind::Squiggly,
            AnnotationKind::Note,
            AnnotationKind::FreeText,
        ] {
            assert_eq!(AnnotationKind::from_subtype(k.subtype()), Some(k));
        }
        assert_eq!(
            AnnotationKind::from_subtype("Widget"),
            None,
            "未知類型不該誤判"
        );
    }

    #[test]
    fn text_markup_kinds_use_quad_points() {
        assert!(AnnotationKind::Highlight.uses_quad_points());
        assert!(AnnotationKind::Underline.uses_quad_points());
        assert!(
            !AnnotationKind::Ink.uses_quad_points(),
            "Ink 用 InkList 不是 QuadPoints"
        );
    }

    #[test]
    fn non_ink_annotations_produce_no_strokes() {
        let a = PdfAnnotation {
            kind: AnnotationKind::Highlight,
            page_index: 0,
            ink_paths: Vec::new(),
            quad_points: vec![[0.0; 8]],
            color: [1.0, 1.0, 0.0],
            opacity: 0.5,
            width: 0.0,
            contents: String::new(),
        };
        assert!(annotation_to_strokes(&a, &map(), Uuid::now_v7).is_empty());
    }

    #[test]
    fn empty_paths_are_skipped() {
        let a = PdfAnnotation {
            kind: AnnotationKind::Ink,
            page_index: 0,
            ink_paths: vec![Vec::new(), vec![(1.0, 2.0)]],
            quad_points: Vec::new(),
            color: [0.0; 3],
            opacity: 1.0,
            width: 1.0,
            contents: String::new(),
        };
        assert_eq!(annotation_to_strokes(&a, &map(), Uuid::now_v7).len(), 1);
    }

    #[test]
    fn scaling_is_applied_in_both_directions() {
        let m = PageMapping {
            page_height: 842.0,
            scale: 2.0,
        };
        let (x, y) = m.to_pdf(50.0, 100.0);
        assert_eq!((x, y), (100.0, 642.0));
        let back = m.to_page(x, y);
        assert!((back.0 - 50.0).abs() < 1e-4 && (back.1 - 100.0).abs() < 1e-4);
    }
}
