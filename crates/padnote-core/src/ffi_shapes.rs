//! 形狀、連接線與流程圖範本的 FFI（S-47，需求 3）。
//!
//! 這層刻意只做**幾何計算**：輸入形狀描述、輸出多邊形點列。
//! 渲染（筆刷、填色、陰影）留在平台層，因為那必須用原生繪圖 API
//! 才能拿到硬體加速與正確的次像素品質。

use padnote_ink::Rect;
use padnote_shapes::align::{AlignMode, AlignRect};
use padnote_shapes::{Anchor, Connection, EndCap, RouteStyle, Shape, ShapeKind, arrow_head};

use crate::ffi_geometry::FfiRect;

/// 形狀種類。順序必須與 [`padnote_shapes::ShapeKind`] 對應。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiShapeKind {
    Rectangle,
    RoundedRectangle,
    Ellipse,
    Triangle,
    Diamond,
    Pentagon,
    Hexagon,
    Star,
    Process,
    Decision,
    Terminator,
    Data,
    Document,
    Database,
    Preparation,
    ManualInput,
    Connector,
    ManualOperation,
    Delay,
    StoredData,
    Merge,
    Extract,
    OffPageConnector,
    Display,
    PunchedTape,
    PunchedCard,
    Collate,
    RightTriangle,
    Parallelogram,
    Trapezoid,
    Heptagon,
    Octagon,
    Cross,
    Chevron,
    ArrowBlockRight,
    ArrowBlockLeft,
    ArrowBlockUp,
    ArrowBlockDown,
    Cloud,
    Heart,
    Bolt,
    Moon,
    Teardrop,
    LShape,
    Star4,
    Star6,
    Star8,
    Sun,
    Banner,
    SpeechBubble,
    Plaque,
    Pie,
    Line,
    Arrow,
    DoubleArrow,
}

impl From<FfiShapeKind> for ShapeKind {
    fn from(k: FfiShapeKind) -> Self {
        match k {
            FfiShapeKind::Rectangle => Self::Rectangle,
            FfiShapeKind::RoundedRectangle => Self::RoundedRectangle,
            FfiShapeKind::Ellipse => Self::Ellipse,
            FfiShapeKind::Triangle => Self::Triangle,
            FfiShapeKind::Diamond => Self::Diamond,
            FfiShapeKind::Pentagon => Self::Pentagon,
            FfiShapeKind::Hexagon => Self::Hexagon,
            FfiShapeKind::Star => Self::Star,
            FfiShapeKind::Process => Self::Process,
            FfiShapeKind::Decision => Self::Decision,
            FfiShapeKind::Terminator => Self::Terminator,
            FfiShapeKind::Data => Self::Data,
            FfiShapeKind::Document => Self::Document,
            FfiShapeKind::Database => Self::Database,
            FfiShapeKind::Preparation => Self::Preparation,
            FfiShapeKind::ManualInput => Self::ManualInput,
            FfiShapeKind::Connector => Self::Connector,
            FfiShapeKind::ManualOperation => Self::ManualOperation,
            FfiShapeKind::Delay => Self::Delay,
            FfiShapeKind::StoredData => Self::StoredData,
            FfiShapeKind::Merge => Self::Merge,
            FfiShapeKind::Extract => Self::Extract,
            FfiShapeKind::OffPageConnector => Self::OffPageConnector,
            FfiShapeKind::Display => Self::Display,
            FfiShapeKind::PunchedTape => Self::PunchedTape,
            FfiShapeKind::PunchedCard => Self::PunchedCard,
            FfiShapeKind::Collate => Self::Collate,
            FfiShapeKind::RightTriangle => Self::RightTriangle,
            FfiShapeKind::Parallelogram => Self::Parallelogram,
            FfiShapeKind::Trapezoid => Self::Trapezoid,
            FfiShapeKind::Heptagon => Self::Heptagon,
            FfiShapeKind::Octagon => Self::Octagon,
            FfiShapeKind::Cross => Self::Cross,
            FfiShapeKind::Chevron => Self::Chevron,
            FfiShapeKind::ArrowBlockRight => Self::ArrowBlockRight,
            FfiShapeKind::ArrowBlockLeft => Self::ArrowBlockLeft,
            FfiShapeKind::ArrowBlockUp => Self::ArrowBlockUp,
            FfiShapeKind::ArrowBlockDown => Self::ArrowBlockDown,
            FfiShapeKind::Cloud => Self::Cloud,
            FfiShapeKind::Heart => Self::Heart,
            FfiShapeKind::Bolt => Self::Bolt,
            FfiShapeKind::Moon => Self::Moon,
            FfiShapeKind::Teardrop => Self::Teardrop,
            FfiShapeKind::LShape => Self::LShape,
            FfiShapeKind::Star4 => Self::Star4,
            FfiShapeKind::Star6 => Self::Star6,
            FfiShapeKind::Star8 => Self::Star8,
            FfiShapeKind::Sun => Self::Sun,
            FfiShapeKind::Banner => Self::Banner,
            FfiShapeKind::SpeechBubble => Self::SpeechBubble,
            FfiShapeKind::Plaque => Self::Plaque,
            FfiShapeKind::Pie => Self::Pie,
            FfiShapeKind::Line => Self::Line,
            FfiShapeKind::Arrow => Self::Arrow,
            FfiShapeKind::DoubleArrow => Self::DoubleArrow,
        }
    }
}

impl From<ShapeKind> for FfiShapeKind {
    fn from(k: ShapeKind) -> Self {
        match k {
            ShapeKind::Rectangle => Self::Rectangle,
            ShapeKind::RoundedRectangle => Self::RoundedRectangle,
            ShapeKind::Ellipse => Self::Ellipse,
            ShapeKind::Triangle => Self::Triangle,
            ShapeKind::Diamond => Self::Diamond,
            ShapeKind::Pentagon => Self::Pentagon,
            ShapeKind::Hexagon => Self::Hexagon,
            ShapeKind::Star => Self::Star,
            ShapeKind::Process => Self::Process,
            ShapeKind::Decision => Self::Decision,
            ShapeKind::Terminator => Self::Terminator,
            ShapeKind::Data => Self::Data,
            ShapeKind::Document => Self::Document,
            ShapeKind::Database => Self::Database,
            ShapeKind::Preparation => Self::Preparation,
            ShapeKind::ManualInput => Self::ManualInput,
            ShapeKind::Connector => Self::Connector,
            ShapeKind::ManualOperation => Self::ManualOperation,
            ShapeKind::Delay => Self::Delay,
            ShapeKind::StoredData => Self::StoredData,
            ShapeKind::Merge => Self::Merge,
            ShapeKind::Extract => Self::Extract,
            ShapeKind::OffPageConnector => Self::OffPageConnector,
            ShapeKind::Display => Self::Display,
            ShapeKind::PunchedTape => Self::PunchedTape,
            ShapeKind::PunchedCard => Self::PunchedCard,
            ShapeKind::Collate => Self::Collate,
            ShapeKind::RightTriangle => Self::RightTriangle,
            ShapeKind::Parallelogram => Self::Parallelogram,
            ShapeKind::Trapezoid => Self::Trapezoid,
            ShapeKind::Heptagon => Self::Heptagon,
            ShapeKind::Octagon => Self::Octagon,
            ShapeKind::Cross => Self::Cross,
            ShapeKind::Chevron => Self::Chevron,
            ShapeKind::ArrowBlockRight => Self::ArrowBlockRight,
            ShapeKind::ArrowBlockLeft => Self::ArrowBlockLeft,
            ShapeKind::ArrowBlockUp => Self::ArrowBlockUp,
            ShapeKind::ArrowBlockDown => Self::ArrowBlockDown,
            ShapeKind::Cloud => Self::Cloud,
            ShapeKind::Heart => Self::Heart,
            ShapeKind::Bolt => Self::Bolt,
            ShapeKind::Moon => Self::Moon,
            ShapeKind::Teardrop => Self::Teardrop,
            ShapeKind::LShape => Self::LShape,
            ShapeKind::Star4 => Self::Star4,
            ShapeKind::Star6 => Self::Star6,
            ShapeKind::Star8 => Self::Star8,
            ShapeKind::Sun => Self::Sun,
            ShapeKind::Banner => Self::Banner,
            ShapeKind::SpeechBubble => Self::SpeechBubble,
            ShapeKind::Plaque => Self::Plaque,
            ShapeKind::Pie => Self::Pie,
            ShapeKind::Line => Self::Line,
            ShapeKind::Arrow => Self::Arrow,
            ShapeKind::DoubleArrow => Self::DoubleArrow,
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiAnchor {
    Top,
    Right,
    Bottom,
    Left,
    Center,
}

impl From<FfiAnchor> for Anchor {
    fn from(a: FfiAnchor) -> Self {
        match a {
            FfiAnchor::Top => Self::Top,
            FfiAnchor::Right => Self::Right,
            FfiAnchor::Bottom => Self::Bottom,
            FfiAnchor::Left => Self::Left,
            FfiAnchor::Center => Self::Center,
        }
    }
}

impl From<Anchor> for FfiAnchor {
    fn from(a: Anchor) -> Self {
        match a {
            Anchor::Top => Self::Top,
            Anchor::Right => Self::Right,
            Anchor::Bottom => Self::Bottom,
            Anchor::Left => Self::Left,
            Anchor::Center => Self::Center,
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiRouteStyle {
    Straight,
    Orthogonal,
}

impl From<FfiRouteStyle> for RouteStyle {
    fn from(r: FfiRouteStyle) -> Self {
        match r {
            FfiRouteStyle::Straight => Self::Straight,
            FfiRouteStyle::Orthogonal => Self::Orthogonal,
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiEndCap {
    None,
    Arrow,
    HollowArrow,
    Circle,
    Diamond,
}

impl From<FfiEndCap> for EndCap {
    fn from(c: FfiEndCap) -> Self {
        match c {
            FfiEndCap::None => Self::None,
            FfiEndCap::Arrow => Self::Arrow,
            FfiEndCap::HollowArrow => Self::HollowArrow,
            FfiEndCap::Circle => Self::Circle,
            FfiEndCap::Diamond => Self::Diamond,
        }
    }
}

impl From<EndCap> for FfiEndCap {
    fn from(c: EndCap) -> Self {
        match c {
            EndCap::None => Self::None,
            EndCap::Arrow => Self::Arrow,
            EndCap::HollowArrow => Self::HollowArrow,
            EndCap::Circle => Self::Circle,
            EndCap::Diamond => Self::Diamond,
        }
    }
}

/// 一個點。UniFFI 沒有 tuple，只能用具名 record。
#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct FfiPoint {
    pub x: f32,
    pub y: f32,
}

impl From<(f32, f32)> for FfiPoint {
    fn from((x, y): (f32, f32)) -> Self {
        Self { x, y }
    }
}

/// 形狀描述。`corner_radius` 為負時採預設值（短邊的 1/6）。
#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct FfiShape {
    pub kind: FfiShapeKind,
    pub bounds: FfiRect,
    pub corner_radius: f32,
    /// 繞自身中心的旋轉角度（度，順時針）。`bounds` 仍是未旋轉的軸對齊矩形。
    pub rotation_degrees: f32,
}

impl From<FfiShape> for Shape {
    fn from(s: FfiShape) -> Self {
        let mut shape = Shape::new(s.kind.into(), Rect::from(s.bounds));
        if s.corner_radius >= 0.0 {
            shape.corner_radius = s.corner_radius;
        }
        shape.rotation_degrees = s.rotation_degrees;
        shape
    }
}

/// 形狀的輪廓多邊形。曲線以 `segments` 段線段近似。
///
/// 回傳的是**閉合前**的點列 —— 是否收尾由平台的繪圖 API 決定
/// （Core Graphics 用 `closePath`，Canvas 用 `closePath()`）。
#[uniffi::export]
pub fn shape_outline(shape: FfiShape, segments: u32) -> Vec<FfiPoint> {
    Shape::from(shape)
        .outline(segments as usize)
        .into_iter()
        .map(Into::into)
        .collect()
}

/// 連接點的座標。
#[uniffi::export]
pub fn shape_anchor_point(shape: FfiShape, anchor: FfiAnchor) -> FfiPoint {
    Shape::from(shape).anchor_point(anchor.into()).into()
}

/// 命中測試。`tolerance` 讓細線與空心形狀也點得到。
#[uniffi::export]
pub fn shape_contains(shape: FfiShape, x: f32, y: f32, tolerance: f32) -> bool {
    Shape::from(shape).contains(x, y, tolerance)
}

/// 形狀的標準語意說明（ISO 5807）。非流程圖符號回傳 `None`。
#[uniffi::export]
pub fn shape_semantic(kind: FfiShapeKind) -> Option<String> {
    ShapeKind::from(kind).semantic().map(str::to_string)
}

/// 線狀形狀（線、箭頭、雙箭頭）的箭頭。非線狀形狀兩端都是空的。
///
/// 為什麼要有這個：平台層拿到的 `shape_outline` 對線狀形狀只有兩個點，
/// 畫出來是一條光禿禿的線 —— 箭頭與線長得一模一樣。箭頭的三角形自己算
/// 也不是不行，但那會變成兩份幾何，Apple 與 Android 的角度稍有出入就
/// 看得出來。和輪廓一樣從核心出。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiArrowHeads {
    /// 起點端的三角形頂點；沒有箭頭時為空。
    pub start: Vec<FfiPoint>,
    /// 終點端的三角形頂點；沒有箭頭時為空。
    pub end: Vec<FfiPoint>,
}

/// 對齊方式。與 `padnote_shapes::AlignMode` 一對一。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiAlignMode {
    Left,
    HorizontalCenter,
    Right,
    Top,
    VerticalMiddle,
    Bottom,
    DistributeHorizontally,
    DistributeVertically,
}

impl From<FfiAlignMode> for AlignMode {
    fn from(m: FfiAlignMode) -> Self {
        match m {
            FfiAlignMode::Left => Self::Left,
            FfiAlignMode::HorizontalCenter => Self::HorizontalCenter,
            FfiAlignMode::Right => Self::Right,
            FfiAlignMode::Top => Self::Top,
            FfiAlignMode::VerticalMiddle => Self::VerticalMiddle,
            FfiAlignMode::Bottom => Self::Bottom,
            FfiAlignMode::DistributeHorizontally => Self::DistributeHorizontally,
            FfiAlignMode::DistributeVertically => Self::DistributeVertically,
        }
    }
}

/// 把一組矩形對齊，回傳每個矩形的**新左上角座標**（順序與輸入相同）。
///
/// 基準是選取範圍，不是頁面 —— 使用者選了三個方塊按「靠左」，期待的是那三個
/// 對齊彼此，不是統統飛到頁面左緣。
///
/// 放在核心而不是兩邊各寫一份：「靠左」的細節有好幾種合理答案（對齊到最左的
/// 物件還是選取範圍？置中用選取範圍還是頁面中線？分佈時頭尾動不動？），
/// 各自實作就會各自挑一種，而使用者在 iPad 上排好的版面到 Android 會跑掉。
#[uniffi::export]
pub fn align_rects(rects: Vec<FfiRect>, mode: FfiAlignMode) -> Vec<FfiPoint> {
    let input: Vec<AlignRect> = rects
        .iter()
        .map(|r| AlignRect {
            x: r.min_x,
            y: r.min_y,
            width: r.max_x - r.min_x,
            height: r.max_y - r.min_y,
        })
        .collect();
    padnote_shapes::align::align(&input, mode.into())
        .into_iter()
        .map(|(x, y)| FfiPoint { x, y })
        .collect()
}

/// 是否為線狀形狀（只有起點與終點，沒有面積）。
///
/// 平台層用它決定路徑要不要收尾：線狀形狀收尾的話，一條線會被
/// 折回成零面積的圖形，某些繪圖 API 乾脆什麼都不畫。
#[uniffi::export]
pub fn shape_is_linear(kind: FfiShapeKind) -> bool {
    ShapeKind::from(kind).is_linear()
}

/// 線狀形狀兩端的箭頭。`size` 是箭頭長度（點）。
#[uniffi::export]
pub fn shape_arrow_heads(shape: FfiShape, size: f32) -> FfiArrowHeads {
    let kind = ShapeKind::from(shape.kind);
    let empty = FfiArrowHeads {
        start: Vec::new(),
        end: Vec::new(),
    };
    if !kind.is_linear() {
        return empty;
    }
    let points = Shape::from(shape).outline(2);
    if points.len() < 2 {
        return empty;
    }
    let (a, b) = (points[0], points[points.len() - 1]);
    let head = |tip: (f32, f32), from: (f32, f32)| -> Vec<FfiPoint> {
        arrow_head(tip, from, size)
            .into_iter()
            .map(Into::into)
            .collect()
    };
    match kind {
        ShapeKind::Arrow => FfiArrowHeads {
            start: Vec::new(),
            end: head(b, a),
        },
        ShapeKind::DoubleArrow => FfiArrowHeads {
            start: head(a, b),
            end: head(b, a),
        },
        // Line 沒有箭頭。
        _ => empty,
    }
}

/// 是否可在形狀內輸入文字。
#[uniffi::export]
pub fn shape_accepts_text(kind: FfiShapeKind) -> bool {
    ShapeKind::from(kind).accepts_text()
}

/// 全部形狀種類，供工具面板列出。
#[uniffi::export]
pub fn all_shape_kinds() -> Vec<FfiShapeKind> {
    ALL_KINDS.iter().copied().map(Into::into).collect()
}

/// 只列流程圖符號。
#[uniffi::export]
pub fn flowchart_shape_kinds() -> Vec<FfiShapeKind> {
    ALL_KINDS
        .iter()
        .filter(|k| k.is_flowchart())
        .copied()
        .map(Into::into)
        .collect()
}

const ALL_KINDS: [ShapeKind; 55] = [
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
    ShapeKind::ManualOperation,
    ShapeKind::Delay,
    ShapeKind::StoredData,
    ShapeKind::Merge,
    ShapeKind::Extract,
    ShapeKind::OffPageConnector,
    ShapeKind::Display,
    ShapeKind::PunchedTape,
    ShapeKind::PunchedCard,
    ShapeKind::Collate,
    ShapeKind::RightTriangle,
    ShapeKind::Parallelogram,
    ShapeKind::Trapezoid,
    ShapeKind::Heptagon,
    ShapeKind::Octagon,
    ShapeKind::Cross,
    ShapeKind::Chevron,
    ShapeKind::ArrowBlockRight,
    ShapeKind::ArrowBlockLeft,
    ShapeKind::ArrowBlockUp,
    ShapeKind::ArrowBlockDown,
    ShapeKind::Cloud,
    ShapeKind::Heart,
    ShapeKind::Bolt,
    ShapeKind::Moon,
    ShapeKind::Teardrop,
    ShapeKind::LShape,
    ShapeKind::Star4,
    ShapeKind::Star6,
    ShapeKind::Star8,
    ShapeKind::Sun,
    ShapeKind::Banner,
    ShapeKind::SpeechBubble,
    ShapeKind::Plaque,
    ShapeKind::Pie,
    ShapeKind::Line,
    ShapeKind::Arrow,
    ShapeKind::DoubleArrow,
];

/// 連接線設定。
#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct FfiConnection {
    pub from_anchor: FfiAnchor,
    pub to_anchor: FfiAnchor,
    pub route: FfiRouteStyle,
    pub start_cap: FfiEndCap,
    pub end_cap: FfiEndCap,
}

impl From<FfiConnection> for Connection {
    fn from(c: FfiConnection) -> Self {
        Self {
            from_anchor: c.from_anchor.into(),
            to_anchor: c.to_anchor.into(),
            route: c.route.into(),
            start_cap: c.start_cap.into(),
            end_cap: c.end_cap.into(),
        }
    }
}

impl From<Connection> for FfiConnection {
    fn from(c: Connection) -> Self {
        Self {
            from_anchor: c.from_anchor.into(),
            to_anchor: c.to_anchor.into(),
            route: match c.route {
                RouteStyle::Straight => FfiRouteStyle::Straight,
                RouteStyle::Orthogonal => FfiRouteStyle::Orthogonal,
            },
            start_cap: c.start_cap.into(),
            end_cap: c.end_cap.into(),
        }
    }
}

/// 連接線的路徑點列。
///
/// 每次移動形狀都要重算 —— 這正是連接線與「畫一條線」的差別。
#[uniffi::export]
pub fn connection_path(conn: FfiConnection, from: FfiShape, to: FfiShape) -> Vec<FfiPoint> {
    Connection::from(conn)
        .path(&Shape::from(from), &Shape::from(to))
        .into_iter()
        .map(Into::into)
        .collect()
}

/// 依兩個形狀的相對位置自動選連接點。
#[uniffi::export]
pub fn connection_between(from: FfiShape, to: FfiShape) -> FfiConnection {
    Connection::between(&Shape::from(from), &Shape::from(to)).into()
}

/// 箭頭三角形的三個頂點。
#[uniffi::export]
pub fn connection_arrow_head(tip: FfiPoint, from: FfiPoint, size: f32) -> Vec<FfiPoint> {
    arrow_head((tip.x, tip.y), (from.x, from.y), size)
        .into_iter()
        .map(Into::into)
        .collect()
}

/// 範本中的一個節點（已換算成畫布座標）。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiTemplateNode {
    pub kind: FfiShapeKind,
    pub label: String,
    pub bounds: FfiRect,
}

/// 範本中的一條連接線。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiTemplateEdge {
    pub from: u32,
    pub to: u32,
    pub label: String,
    pub connection: FfiConnection,
}

/// 一份可插入的範本。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiTemplate {
    pub id: String,
    pub nodes: Vec<FfiTemplateNode>,
    pub edges: Vec<FfiTemplateEdge>,
    pub width: f32,
    pub height: f32,
}

/// 內建流程圖範本清單。
#[uniffi::export]
pub fn flowchart_templates() -> Vec<FfiTemplate> {
    padnote_shapes::builtin_templates()
        .into_iter()
        .map(|t| {
            let (width, height) = t.size();
            let connections = t.connections();
            FfiTemplate {
                id: t.id.to_string(),
                nodes: t
                    .nodes
                    .iter()
                    .map(|n| FfiTemplateNode {
                        kind: n.kind.into(),
                        label: n.label.clone(),
                        bounds: FfiRect {
                            min_x: n.x,
                            min_y: n.y,
                            max_x: n.x + n.width,
                            max_y: n.y + n.height,
                        },
                    })
                    .collect(),
                edges: t
                    .edges
                    .iter()
                    .zip(connections)
                    .map(|((from, to, label), c)| FfiTemplateEdge {
                        from: *from as u32,
                        to: *to as u32,
                        label: (*label).to_string(),
                        connection: c.into(),
                    })
                    .collect(),
                width,
                height,
            }
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn rect(min_x: f32, min_y: f32, max_x: f32, max_y: f32) -> FfiRect {
        FfiRect {
            min_x,
            min_y,
            max_x,
            max_y,
        }
    }

    fn shape(kind: FfiShapeKind) -> FfiShape {
        FfiShape {
            kind,
            bounds: rect(0.0, 0.0, 100.0, 60.0),
            corner_radius: -1.0,
            rotation_degrees: 0.0,
        }
    }

    #[test]
    fn every_kind_survives_the_round_trip() {
        // 兩個 From 實作各寫一次，手滑接錯一個就會被抓到。
        for k in ALL_KINDS {
            let there: FfiShapeKind = k.into();
            assert_eq!(ShapeKind::from(there), k, "{k:?} 轉換不對稱");
        }
    }

    #[test]
    fn all_kinds_covers_the_whole_enum() {
        assert_eq!(
            all_shape_kinds().len(),
            ALL_KINDS.len(),
            "新增形狀時 ALL_KINDS 必須同步更新"
        );
    }

    #[test]
    fn outlines_are_non_degenerate() {
        for k in ALL_KINDS {
            let pts = shape_outline(shape(k.into()), 24);
            assert!(pts.len() >= 2, "{k:?} 的輪廓只有 {} 點", pts.len());
        }
    }

    #[test]
    fn align_rects_crosses_the_ffi_intact() {
        // FFI 這一層只是換個型別，但換錯邊（把 max 當成寬）會讓所有東西
        // 對齊到錯的地方，而那在單元測試裡看不出來 —— 那些測的是核心。
        let rects = vec![
            FfiRect {
                min_x: 30.0,
                min_y: 0.0,
                max_x: 40.0,
                max_y: 10.0,
            },
            FfiRect {
                min_x: 10.0,
                min_y: 50.0,
                max_x: 30.0,
                max_y: 60.0,
            },
        ];
        let out = align_rects(rects, FfiAlignMode::Left);
        assert_eq!(out[0].x, 10.0);
        assert_eq!(out[1].x, 10.0);
        // 靠左不可以動到 y。
        assert_eq!(out[0].y, 0.0);
        assert_eq!(out[1].y, 50.0);
    }

    #[test]
    fn align_rects_preserves_width_when_aligning_right() {
        let rects = vec![
            FfiRect {
                min_x: 0.0,
                min_y: 0.0,
                max_x: 10.0,
                max_y: 10.0,
            },
            FfiRect {
                min_x: 0.0,
                min_y: 50.0,
                max_x: 40.0,
                max_y: 60.0,
            },
        ];
        let out = align_rects(rects, FfiAlignMode::Right);
        // 右緣都要落在 40：窄的那個左上角要退到 30。
        assert_eq!(out[0].x, 30.0);
        assert_eq!(out[1].x, 0.0);
    }

    #[test]
    fn linear_shapes_are_reported_as_linear() {
        // 平台層靠這個判斷路徑要不要收尾。判錯的後果是線狀形狀完全不顯示
        // —— 使用者插入了一個看不見的物件（實際發生過）。
        for k in [
            FfiShapeKind::Line,
            FfiShapeKind::Arrow,
            FfiShapeKind::DoubleArrow,
        ] {
            assert!(shape_is_linear(k), "{k:?} 應為線狀");
        }
        for k in [FfiShapeKind::Process, FfiShapeKind::Ellipse] {
            assert!(!shape_is_linear(k), "{k:?} 不應為線狀");
        }
    }

    #[test]
    fn arrow_heads_match_the_kind() {
        let heads = shape_arrow_heads(shape(FfiShapeKind::Line), 10.0);
        assert!(
            heads.start.is_empty() && heads.end.is_empty(),
            "線不該有箭頭"
        );

        let heads = shape_arrow_heads(shape(FfiShapeKind::Arrow), 10.0);
        assert!(heads.start.is_empty(), "單箭頭的起點端不該有箭頭");
        assert_eq!(heads.end.len(), 3, "箭頭應是三角形");

        let heads = shape_arrow_heads(shape(FfiShapeKind::DoubleArrow), 10.0);
        assert_eq!(heads.start.len(), 3);
        assert_eq!(heads.end.len(), 3);

        // 非線狀形狀問了也不能拿到箭頭，否則橢圓上會冒出一個三角形。
        let heads = shape_arrow_heads(shape(FfiShapeKind::Ellipse), 10.0);
        assert!(heads.start.is_empty() && heads.end.is_empty());
    }

    #[test]
    fn arrow_head_sits_at_the_far_end_of_the_line() {
        let s = FfiShape {
            bounds: rect(0.0, 0.0, 100.0, 100.0),
            ..shape(FfiShapeKind::Arrow)
        };
        let heads = shape_arrow_heads(s, 12.0);
        // 線是左上到右下，箭頭尖端應該落在右下角附近。
        let tip = heads.end[0];
        assert!(
            (tip.x - 100.0).abs() < 0.01 && (tip.y - 100.0).abs() < 0.01,
            "箭頭尖端應在終點，實得 {tip:?}"
        );
    }

    #[test]
    fn templates_reach_the_platform_layer() {
        let ts = flowchart_templates();
        assert!(!ts.is_empty());
        for t in &ts {
            assert!(t.width > 0.0 && t.height > 0.0, "{} 尺寸為零", t.id);
            for e in &t.edges {
                // 索引越界會讓平台層當掉，這裡先擋住。
                assert!(
                    (e.from as usize) < t.nodes.len() && (e.to as usize) < t.nodes.len(),
                    "{} 的邊指向不存在的節點",
                    t.id
                );
            }
        }
    }

    #[test]
    fn connection_path_follows_the_shapes() {
        let a = FfiShape {
            bounds: rect(0.0, 0.0, 100.0, 60.0),
            ..shape(FfiShapeKind::Process)
        };
        let b = FfiShape {
            bounds: rect(0.0, 200.0, 100.0, 260.0),
            ..shape(FfiShapeKind::Process)
        };
        let conn = connection_between(a, b);
        let path = connection_path(conn, a, b);
        let last = path.last().unwrap();
        assert!(
            (last.y - 200.0).abs() < 0.01,
            "線應停在下方形狀的上緣，實得 {last:?}"
        );
    }
}
