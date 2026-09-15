//! 形狀、連接線與流程圖範本的 FFI（S-47，需求 3）。
//!
//! 這層刻意只做**幾何計算**：輸入形狀描述、輸出多邊形點列。
//! 渲染（筆刷、填色、陰影）留在平台層，因為那必須用原生繪圖 API
//! 才能拿到硬體加速與正確的次像素品質。

use padnote_ink::Rect;
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

const ALL_KINDS: [ShapeKind; 20] = [
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
