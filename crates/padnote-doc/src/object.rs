//! 物件樹：群組、變換、階層（ADR-0010）。
//!
//! ## 核心約束：取樣點永不改寫
//! 物件持有仿射變換，渲染與命中測試時把變換**套用在讀取端**。
//! 直接改寫座標會讓 ADR-0002 的「存原始取樣點」性質消失，
//! 而且反覆縮放會累積浮點誤差，筆跡逐漸走樣。
//!
//! ## 群組是「引用」不是「搬移」
//! 群組只記錄成員 id，筆畫仍留在原本的 `ink/<page>.strokes` 串流裡。
//! 解散群組只是刪掉群組節點 —— **不需要搬動任何筆畫資料**，
//! 因此群組／解散是 O(1) 且完全可逆，也維持 append-only 不變式。

use crate::{Affine2, Uuid};
use std::collections::HashMap;

/// Persisted shape kinds. This mirrors the geometry crate without making the
/// document model depend on the drawing engine.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ShapeKind {
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

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct ObjectRect {
    pub min_x: f32,
    pub min_y: f32,
    pub max_x: f32,
    pub max_y: f32,
}

#[derive(Clone, Debug, PartialEq)]
pub struct ShapeObject {
    pub kind: ShapeKind,
    pub bounds: ObjectRect,
    pub corner_radius: f32,
    pub text: String,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Anchor {
    Top,
    Right,
    Bottom,
    Left,
    Center,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum RouteStyle {
    Straight,
    Orthogonal,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum EndCap {
    None,
    Arrow,
    HollowArrow,
    Circle,
    Diamond,
}

#[derive(Clone, Debug, PartialEq)]
pub struct ConnectionObject {
    pub from: Uuid,
    pub to: Uuid,
    pub from_anchor: Anchor,
    pub to_anchor: Anchor,
    pub route: RouteStyle,
    pub start_cap: EndCap,
    pub end_cap: EndCap,
    pub label: String,
}

/// 物件的內容。
#[derive(Clone, Debug, PartialEq)]
pub enum ObjectKind {
    /// 一組筆畫。
    Strokes(Vec<Uuid>),
    /// 一個內容區塊（文字、圖片、轉錄…）。
    Block(Uuid),
    /// 群組，成員是其他物件。
    Group(Vec<Uuid>),
    /// 原生形狀（S-52）。
    Shape(ShapeObject),
    /// 依附於兩個物件的連接線（S-52）。
    Connection(ConnectionObject),
}

#[derive(Clone, Debug)]
pub struct ObjectNode {
    pub id: Uuid,
    pub kind: ObjectKind,
    /// 相對**父物件**的變換。世界變換是從根到此節點的累積。
    pub transform: Affine2,
}

impl ObjectNode {
    pub fn strokes(id: Uuid, strokes: Vec<Uuid>) -> Self {
        Self {
            id,
            kind: ObjectKind::Strokes(strokes),
            transform: Affine2::IDENTITY,
        }
    }

    pub fn group(id: Uuid, members: Vec<Uuid>) -> Self {
        Self {
            id,
            kind: ObjectKind::Group(members),
            transform: Affine2::IDENTITY,
        }
    }

    pub fn shape(id: Uuid, shape: ShapeObject) -> Self {
        Self {
            id,
            kind: ObjectKind::Shape(shape),
            transform: Affine2::IDENTITY,
        }
    }

    pub fn connection(id: Uuid, connection: ConnectionObject) -> Self {
        Self {
            id,
            kind: ObjectKind::Connection(connection),
            transform: Affine2::IDENTITY,
        }
    }

    pub fn members(&self) -> &[Uuid] {
        match &self.kind {
            ObjectKind::Group(m) => m,
            _ => &[],
        }
    }
}

#[derive(Debug, PartialEq, Eq)]
pub enum ObjectError {
    NotFound(Uuid),
    /// 群組自己或形成迴圈。
    WouldCycle,
    /// 物件已經屬於另一個群組。
    AlreadyGrouped(Uuid),
}

impl std::fmt::Display for ObjectError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NotFound(id) => write!(f, "找不到物件：{id}"),
            Self::WouldCycle => write!(f, "群組會形成迴圈"),
            Self::AlreadyGrouped(id) => write!(f, "物件已屬於其他群組：{id}"),
        }
    }
}

impl std::error::Error for ObjectError {}

/// 一頁的物件樹。
#[derive(Debug, Default)]
pub struct ObjectTree {
    nodes: HashMap<Uuid, ObjectNode>,
    /// 子 → 父。根層物件不在這張表裡。
    parent: HashMap<Uuid, Uuid>,
    /// 根層物件，維持 z 序。
    roots: Vec<Uuid>,
}

impl ObjectTree {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn len(&self) -> usize {
        self.nodes.len()
    }

    pub fn is_empty(&self) -> bool {
        self.nodes.is_empty()
    }

    pub fn roots(&self) -> &[Uuid] {
        &self.roots
    }

    pub fn get(&self, id: Uuid) -> Option<&ObjectNode> {
        self.nodes.get(&id)
    }

    pub fn parent_of(&self, id: Uuid) -> Option<Uuid> {
        self.parent.get(&id).copied()
    }

    pub fn insert(&mut self, node: ObjectNode) {
        let id = node.id;
        if !self.nodes.contains_key(&id) {
            self.roots.push(id);
        }
        self.nodes.insert(id, node);
    }

    /// 移除物件。群組被移除時，**成員升到原群組的層級**而不是一起消失 ——
    /// 刪除群組不該連內容一起刪掉，那是使用者最不預期的行為。
    pub fn remove(&mut self, id: Uuid) -> Option<ObjectNode> {
        let node = self.nodes.remove(&id)?;
        let grandparent = self.parent.remove(&id);

        for m in node.members() {
            match grandparent {
                Some(g) => {
                    self.parent.insert(*m, g);
                    if let Some(ObjectKind::Group(members)) =
                        self.nodes.get_mut(&g).map(|n| &mut n.kind)
                    {
                        members.push(*m);
                    }
                }
                None => {
                    self.parent.remove(m);
                    self.roots.push(*m);
                }
            }
        }
        self.roots.retain(|r| *r != id);
        if let Some(g) = grandparent
            && let Some(ObjectKind::Group(members)) = self.nodes.get_mut(&g).map(|n| &mut n.kind)
        {
            members.retain(|m| *m != id);
        }
        Some(node)
    }

    /// 把多個物件收進一個新群組。
    pub fn group(&mut self, group_id: Uuid, members: &[Uuid]) -> Result<(), ObjectError> {
        for m in members {
            if !self.nodes.contains_key(m) {
                return Err(ObjectError::NotFound(*m));
            }
            if let Some(p) = self.parent.get(m) {
                return Err(ObjectError::AlreadyGrouped(*p));
            }
            if *m == group_id {
                return Err(ObjectError::WouldCycle);
            }
        }

        self.nodes
            .insert(group_id, ObjectNode::group(group_id, members.to_vec()));
        for m in members {
            self.parent.insert(*m, group_id);
            self.roots.retain(|r| r != m);
        }
        self.roots.push(group_id);
        Ok(())
    }

    /// 解散群組，成員回到原群組的層級。
    pub fn ungroup(&mut self, group_id: Uuid) -> Result<Vec<Uuid>, ObjectError> {
        let node = self
            .nodes
            .get(&group_id)
            .ok_or(ObjectError::NotFound(group_id))?;
        let members: Vec<Uuid> = node.members().to_vec();

        // 群組的變換要往下傳給成員，否則解散後位置會跳掉。
        let group_transform = node.transform;
        for m in &members {
            if let Some(child) = self.nodes.get_mut(m) {
                child.transform = child.transform.then(&group_transform);
            }
        }
        self.remove(group_id);
        Ok(members)
    }

    // ---- z 序（S-46）----
    //
    // `roots` 的順序**就是**繪製順序：索引 0 最底層，最後一個在最上面。
    // 群組內的成員順序同理。

    /// 物件在同層中的位置。
    pub fn z_index(&self, id: Uuid) -> Option<usize> {
        self.siblings_of(id)?.iter().position(|x| *x == id)
    }

    /// 同層的物件序列（含自己）。
    /// 與 `id` 同層的物件數量（含自己）。
    ///
    /// 「移到最上層」要知道上界，而上界是**同層**的數量，
    /// 不是整棵樹的數量 —— 群組裡的物件只在群組內排序。
    pub fn sibling_count(&self, id: Uuid) -> usize {
        self.siblings_of(id).map_or(0, Vec::len)
    }

    fn siblings_of(&self, id: Uuid) -> Option<&Vec<Uuid>> {
        match self.parent.get(&id) {
            Some(p) => match &self.nodes.get(p)?.kind {
                ObjectKind::Group(members) => Some(members),
                _ => None,
            },
            None => self.roots.contains(&id).then_some(&self.roots),
        }
    }

    fn siblings_mut(&mut self, id: Uuid) -> Option<&mut Vec<Uuid>> {
        match self.parent.get(&id).copied() {
            Some(p) => match &mut self.nodes.get_mut(&p)?.kind {
                ObjectKind::Group(members) => Some(members),
                _ => None,
            },
            None => self.roots.contains(&id).then_some(&mut self.roots),
        }
    }

    /// 移到同層的指定位置。
    ///
    /// **只在同層內移動** —— 跨層移動等於改變父子關係，那是 group／ungroup
    /// 的職責。混在一起會讓 z 序調整意外改變群組結構。
    pub fn set_z_index(&mut self, id: Uuid, index: usize) -> Result<(), ObjectError> {
        let siblings = self.siblings_mut(id).ok_or(ObjectError::NotFound(id))?;
        let Some(from) = siblings.iter().position(|x| *x == id) else {
            return Err(ObjectError::NotFound(id));
        };
        let item = siblings.remove(from);
        siblings.insert(index.min(siblings.len()), item);
        Ok(())
    }

    /// 移到最上層。
    pub fn bring_to_front(&mut self, id: Uuid) -> Result<(), ObjectError> {
        let last = self.siblings_of(id).ok_or(ObjectError::NotFound(id))?.len();
        self.set_z_index(id, last)
    }

    /// 移到最底層。
    pub fn send_to_back(&mut self, id: Uuid) -> Result<(), ObjectError> {
        self.set_z_index(id, 0)
    }

    /// 往上一層。
    pub fn bring_forward(&mut self, id: Uuid) -> Result<(), ObjectError> {
        let i = self.z_index(id).ok_or(ObjectError::NotFound(id))?;
        self.set_z_index(id, i + 1)
    }

    /// 往下一層。
    pub fn send_backward(&mut self, id: Uuid) -> Result<(), ObjectError> {
        let i = self.z_index(id).ok_or(ObjectError::NotFound(id))?;
        self.set_z_index(id, i.saturating_sub(1))
    }

    /// 依繪製順序展開所有葉節點（由底到頂）。
    ///
    /// 渲染時照這個順序畫，覆蓋關係才會正確。
    pub fn draw_order(&self) -> Vec<(Uuid, Affine2)> {
        self.roots.iter().flat_map(|r| self.flatten(*r)).collect()
    }

    pub fn set_transform(&mut self, id: Uuid, transform: Affine2) -> Result<(), ObjectError> {
        self.nodes
            .get_mut(&id)
            .map(|n| n.transform = transform)
            .ok_or(ObjectError::NotFound(id))
    }

    /// 從根到此節點的累積變換。
    ///
    /// 巢狀群組時，變換沿路徑相乘。
    pub fn world_transform(&self, id: Uuid) -> Affine2 {
        let mut chain = Vec::new();
        let mut cursor = Some(id);
        // 由下往上收集，避免遞迴。
        while let Some(c) = cursor {
            let Some(node) = self.nodes.get(&c) else {
                break;
            };
            chain.push(node.transform);
            cursor = self.parent.get(&c).copied();
        }
        // 由上往下相乘：父的變換先套用。
        chain
            .into_iter()
            .rev()
            .fold(Affine2::IDENTITY, |acc, t| t.then(&acc))
    }

    /// 展開成所有葉節點（筆畫與區塊）的 id 與其世界變換。
    pub fn flatten(&self, id: Uuid) -> Vec<(Uuid, Affine2)> {
        let mut out = Vec::new();
        self.flatten_into(id, Affine2::IDENTITY, &mut out);
        out
    }

    fn flatten_into(&self, id: Uuid, inherited: Affine2, out: &mut Vec<(Uuid, Affine2)>) {
        let Some(node) = self.nodes.get(&id) else {
            return;
        };
        let world = node.transform.then(&inherited);
        match &node.kind {
            ObjectKind::Group(members) => {
                for m in members {
                    self.flatten_into(*m, world, out);
                }
            }
            ObjectKind::Strokes(strokes) => {
                out.extend(strokes.iter().map(|s| (*s, world)));
            }
            ObjectKind::Block(b) => out.push((*b, world)),
            ObjectKind::Shape(_) | ObjectKind::Connection(_) => out.push((id, world)),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn uid(b: u8) -> Uuid {
        Uuid::from_bytes([b; 16])
    }

    fn rect() -> ObjectRect {
        ObjectRect {
            min_x: 10.0,
            min_y: 20.0,
            max_x: 110.0,
            max_y: 80.0,
        }
    }

    fn tree_with_two() -> (ObjectTree, Uuid, Uuid) {
        let mut t = ObjectTree::new();
        let (a, b) = (uid(1), uid(2));
        t.insert(ObjectNode::strokes(a, vec![uid(10)]));
        t.insert(ObjectNode::strokes(b, vec![uid(11)]));
        (t, a, b)
    }

    #[test]
    fn grouping_moves_members_out_of_the_roots() {
        let (mut t, a, b) = tree_with_two();
        assert_eq!(t.roots().len(), 2);

        t.group(uid(100), &[a, b]).unwrap();
        assert_eq!(t.roots(), &[uid(100)]);
        assert_eq!(t.parent_of(a), Some(uid(100)));
    }

    #[test]
    fn grouping_does_not_move_stroke_data() {
        // 群組只記錄 id —— 這是 O(1) 且可逆的關鍵。
        let (mut t, a, b) = tree_with_two();
        t.group(uid(100), &[a, b]).unwrap();

        let node = t.get(a).unwrap();
        assert_eq!(
            node.kind,
            ObjectKind::Strokes(vec![uid(10)]),
            "筆畫引用不變"
        );
    }

    #[test]
    fn ungroup_returns_members_to_the_parent_level() {
        let (mut t, a, b) = tree_with_two();
        t.group(uid(100), &[a, b]).unwrap();

        let members = t.ungroup(uid(100)).unwrap();
        assert_eq!(members.len(), 2);
        assert!(t.get(uid(100)).is_none());
        assert!(t.parent_of(a).is_none());
        assert_eq!(t.roots().len(), 2);
    }

    #[test]
    fn ungroup_pushes_the_group_transform_down() {
        // 不往下傳的話，解散後物件會跳回原位 —— 使用者會覺得東西亂跑。
        let (mut t, a, b) = tree_with_two();
        t.group(uid(100), &[a, b]).unwrap();
        t.set_transform(uid(100), Affine2::translate(50.0, 20.0))
            .unwrap();

        t.ungroup(uid(100)).unwrap();
        let moved = t.get(a).unwrap().transform.apply(0.0, 0.0);
        assert_eq!(moved, (50.0, 20.0), "群組的位移必須留在成員身上");
    }

    #[test]
    fn removing_a_group_keeps_its_members() {
        // 刪除群組連內容一起刪是使用者最不預期的行為。
        let (mut t, a, b) = tree_with_two();
        t.group(uid(100), &[a, b]).unwrap();

        t.remove(uid(100));
        assert!(t.get(a).is_some(), "成員不該跟著消失");
        assert!(t.get(b).is_some());
        assert_eq!(t.roots().len(), 2);
    }

    #[test]
    fn world_transform_composes_through_nesting() {
        let (mut t, a, b) = tree_with_two();
        t.group(uid(100), &[a, b]).unwrap();
        t.group(uid(200), &[uid(100)]).unwrap();

        t.set_transform(uid(200), Affine2::translate(100.0, 0.0))
            .unwrap();
        t.set_transform(uid(100), Affine2::translate(0.0, 50.0))
            .unwrap();
        t.set_transform(a, Affine2::translate(5.0, 5.0)).unwrap();

        let w = t.world_transform(a);
        assert_eq!(w.apply(0.0, 0.0), (105.0, 55.0), "三層變換必須累加");
    }

    #[test]
    fn flatten_yields_leaves_with_world_transforms() {
        let (mut t, a, b) = tree_with_two();
        t.group(uid(100), &[a, b]).unwrap();
        t.set_transform(uid(100), Affine2::translate(10.0, 0.0))
            .unwrap();

        let leaves = t.flatten(uid(100));
        assert_eq!(leaves.len(), 2, "兩個筆畫物件各一個筆畫");
        for (_, transform) in &leaves {
            assert_eq!(transform.apply(0.0, 0.0), (10.0, 0.0));
        }
    }

    #[test]
    fn shapes_and_connections_are_persistent_leaves() {
        let mut t = ObjectTree::new();
        let a = uid(1);
        let b = uid(2);
        let c = uid(3);
        t.insert(ObjectNode::shape(
            a,
            ShapeObject {
                kind: ShapeKind::Process,
                bounds: rect(),
                corner_radius: 6.0,
                text: "輸入".into(),
            },
        ));
        t.insert(ObjectNode::shape(
            b,
            ShapeObject {
                kind: ShapeKind::Decision,
                bounds: rect(),
                corner_radius: 0.0,
                text: "確認".into(),
            },
        ));
        t.insert(ObjectNode::connection(
            c,
            ConnectionObject {
                from: a,
                to: b,
                from_anchor: Anchor::Right,
                to_anchor: Anchor::Left,
                route: RouteStyle::Orthogonal,
                start_cap: EndCap::None,
                end_cap: EndCap::Arrow,
                label: "是".into(),
            },
        ));

        assert_eq!(
            t.draw_order().iter().map(|(id, _)| *id).collect::<Vec<_>>(),
            vec![a, b, c]
        );
    }

    // ---- z 序（S-46）----

    #[test]
    fn insertion_order_is_the_draw_order() {
        let (t, a, b) = tree_with_two();
        assert_eq!(t.z_index(a), Some(0), "先插入的在底層");
        assert_eq!(t.z_index(b), Some(1));
    }

    #[test]
    fn sibling_count_is_per_layer_not_whole_tree() {
        let (mut t, a, b) = tree_with_two();
        let c = uid(3);
        t.insert(ObjectNode::strokes(c, vec![uid(12)]));
        t.group(uid(100), &[a, b]).unwrap();
        // 根層現在是 c 與群組；群組內是 a 與 b。
        assert_eq!(t.sibling_count(c), 2, "根層應有 c 與群組");
        assert_eq!(t.sibling_count(a), 2, "群組內應有 a 與 b");
    }

    #[test]
    fn bring_to_front_and_send_to_back() {
        let (mut t, a, b) = tree_with_two();
        t.bring_to_front(a).unwrap();
        assert_eq!(t.roots(), &[b, a]);

        t.send_to_back(a).unwrap();
        assert_eq!(t.roots(), &[a, b]);
    }

    #[test]
    fn stepwise_reordering() {
        let mut t = ObjectTree::new();
        let ids: Vec<Uuid> = (1..=3).map(uid).collect();
        for id in &ids {
            t.insert(ObjectNode::strokes(*id, vec![]));
        }

        t.bring_forward(ids[0]).unwrap();
        assert_eq!(t.roots(), &[ids[1], ids[0], ids[2]]);

        t.send_backward(ids[0]).unwrap();
        assert_eq!(t.roots(), &[ids[0], ids[1], ids[2]]);
    }

    #[test]
    fn reordering_at_the_edges_is_a_noop_not_an_error() {
        // 最上層再往上、最下層再往下，都不該報錯 ——
        // 使用者連按按鈕時不該跳出錯誤訊息。
        let (mut t, a, b) = tree_with_two();
        t.send_backward(a).unwrap();
        assert_eq!(t.roots(), &[a, b]);

        t.bring_to_front(b).unwrap();
        t.bring_forward(b).unwrap();
        assert_eq!(t.roots(), &[a, b]);
    }

    #[test]
    fn z_order_works_inside_groups() {
        let (mut t, a, b) = tree_with_two();
        t.group(uid(100), &[a, b]).unwrap();

        assert_eq!(t.z_index(a), Some(0), "群組內也有 z 序");
        t.bring_to_front(a).unwrap();
        assert_eq!(t.get(uid(100)).unwrap().members(), &[b, a]);
    }

    #[test]
    fn reordering_does_not_change_grouping() {
        // z 序只在同層內移動。跨層移動是 group/ungroup 的職責，
        // 混在一起會讓調整順序意外改變群組結構。
        let (mut t, a, b) = tree_with_two();
        t.group(uid(100), &[a, b]).unwrap();
        t.bring_to_front(a).unwrap();

        assert_eq!(t.parent_of(a), Some(uid(100)), "父子關係不變");
        assert_eq!(t.roots(), &[uid(100)]);
    }

    #[test]
    fn draw_order_follows_the_root_sequence() {
        let (mut t, a, _b) = tree_with_two();
        let order: Vec<Uuid> = t.draw_order().into_iter().map(|(id, _)| id).collect();
        assert_eq!(order, vec![uid(10), uid(11)], "底層先畫");

        t.bring_to_front(a).unwrap();
        let order: Vec<Uuid> = t.draw_order().into_iter().map(|(id, _)| id).collect();
        assert_eq!(order, vec![uid(11), uid(10)], "調整後順序要跟著變");
    }

    #[test]
    fn reordering_an_unknown_object_errors() {
        let mut t = ObjectTree::new();
        assert_eq!(
            t.bring_to_front(uid(99)),
            Err(ObjectError::NotFound(uid(99)))
        );
        assert!(t.z_index(uid(99)).is_none());
    }

    #[test]
    fn cannot_group_an_object_twice() {
        let (mut t, a, b) = tree_with_two();
        t.group(uid(100), &[a, b]).unwrap();
        assert_eq!(
            t.group(uid(200), &[a]),
            Err(ObjectError::AlreadyGrouped(uid(100)))
        );
    }

    #[test]
    fn cannot_group_a_missing_object() {
        let (mut t, a, _) = tree_with_two();
        assert_eq!(
            t.group(uid(100), &[a, uid(99)]),
            Err(ObjectError::NotFound(uid(99)))
        );
    }

    #[test]
    fn cannot_group_into_itself() {
        let (mut t, a, _) = tree_with_two();
        assert_eq!(t.group(a, &[a]), Err(ObjectError::WouldCycle));
    }

    #[test]
    fn transform_on_missing_object_is_an_error() {
        let mut t = ObjectTree::new();
        assert_eq!(
            t.set_transform(uid(99), Affine2::IDENTITY),
            Err(ObjectError::NotFound(uid(99)))
        );
    }

    #[test]
    fn world_transform_of_unknown_object_is_identity() {
        assert!(ObjectTree::new().world_transform(uid(1)).is_identity());
    }
}
