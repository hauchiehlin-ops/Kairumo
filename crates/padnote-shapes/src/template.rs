//! 流程圖範本（S-47，需求 3）。
//!
//! 範本是**起點不是終點**：插入後每個元素都能自由編輯、移動、刪除。
//! 這與「圖片範本」的差別在於，插進來的是真正的形狀與連接線，
//! 不是一張看起來像流程圖的圖。

use crate::connector::Connection;
use crate::shape::{Anchor, ShapeKind};

/// 範本中的一個節點。
#[derive(Clone, Debug, PartialEq)]
pub struct TemplateNode {
    pub kind: ShapeKind,
    /// 預設文字。使用者插入後直接改。
    pub label: String,
    /// 相對於範本原點的位置與大小。
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
}

/// 一份範本。
#[derive(Clone, Debug)]
pub struct Template {
    /// 內部識別碼，供在地化查表用（不直接顯示）。
    pub id: &'static str,
    pub nodes: Vec<TemplateNode>,
    /// 連接關係：`(來源節點索引, 目標節點索引, 線上的標籤)`。
    pub edges: Vec<(usize, usize, &'static str)>,
}

impl Template {
    /// 範本的整體尺寸，供插入時置中與縮放。
    pub fn size(&self) -> (f32, f32) {
        self.nodes.iter().fold((0.0f32, 0.0f32), |(w, h), n| {
            (w.max(n.x + n.width), h.max(n.y + n.height))
        })
    }

    /// 每條連接線的預設設定。
    ///
    /// 帶標籤的分支（是／否）用直角走線，比斜線好讀。
    pub fn connections(&self) -> Vec<Connection> {
        self.edges
            .iter()
            .map(|(from, to, _)| {
                let a = &self.nodes[*from];
                let b = &self.nodes[*to];
                // 依相對位置選連接點，與 Connection::auto_anchors 同樣的判準，
                // 但這裡只有矩形資料、還沒有 Shape。
                let (dx, dy) = (b.x - a.x, b.y - a.y);
                let (from_anchor, to_anchor) = if dx.abs() > dy.abs() {
                    if dx > 0.0 {
                        (Anchor::Right, Anchor::Left)
                    } else {
                        (Anchor::Left, Anchor::Right)
                    }
                } else if dy > 0.0 {
                    (Anchor::Bottom, Anchor::Top)
                } else {
                    (Anchor::Top, Anchor::Bottom)
                };
                Connection {
                    from_anchor,
                    to_anchor,
                    ..Connection::default()
                }
            })
            .collect()
    }
}

fn node(kind: ShapeKind, label: &str, x: f32, y: f32, w: f32, h: f32) -> TemplateNode {
    TemplateNode {
        kind,
        label: label.to_string(),
        x,
        y,
        width: w,
        height: h,
    }
}

/// 內建範本。
///
/// 刻意只放**少量、真的會用到**的範本。競品的範本庫動輒上百個，
/// 但使用者找不到要的那一個，反而比沒有更慢。
pub fn builtin_templates() -> Vec<Template> {
    vec![
        // ---- 基本流程 ----
        Template {
            id: "flow.basic",
            nodes: vec![
                node(ShapeKind::Terminator, "開始", 60.0, 0.0, 120.0, 50.0),
                node(ShapeKind::Process, "步驟一", 60.0, 100.0, 120.0, 60.0),
                node(ShapeKind::Process, "步驟二", 60.0, 210.0, 120.0, 60.0),
                node(ShapeKind::Terminator, "結束", 60.0, 320.0, 120.0, 50.0),
            ],
            edges: vec![(0, 1, ""), (1, 2, ""), (2, 3, "")],
        },
        // ---- 判斷分支 ----
        Template {
            id: "flow.decision",
            nodes: vec![
                node(ShapeKind::Terminator, "開始", 120.0, 0.0, 120.0, 50.0),
                node(ShapeKind::Decision, "條件成立？", 100.0, 100.0, 160.0, 90.0),
                node(ShapeKind::Process, "是", 0.0, 240.0, 120.0, 60.0),
                node(ShapeKind::Process, "否", 240.0, 240.0, 120.0, 60.0),
                node(ShapeKind::Terminator, "結束", 120.0, 350.0, 120.0, 50.0),
            ],
            edges: vec![
                (0, 1, ""),
                (1, 2, "是"),
                (1, 3, "否"),
                (2, 4, ""),
                (3, 4, ""),
            ],
        },
        // ---- 輸入處理輸出 ----
        Template {
            id: "flow.io",
            nodes: vec![
                node(ShapeKind::Data, "輸入資料", 40.0, 0.0, 160.0, 60.0),
                node(ShapeKind::Process, "處理", 40.0, 110.0, 160.0, 60.0),
                node(ShapeKind::Database, "儲存", 40.0, 220.0, 160.0, 80.0),
                node(ShapeKind::Data, "輸出結果", 40.0, 350.0, 160.0, 60.0),
            ],
            edges: vec![(0, 1, ""), (1, 2, ""), (2, 3, "")],
        },
        // ---- 迴圈 ----
        Template {
            id: "flow.loop",
            nodes: vec![
                node(ShapeKind::Terminator, "開始", 80.0, 0.0, 120.0, 50.0),
                node(ShapeKind::Preparation, "初始化", 60.0, 100.0, 160.0, 60.0),
                node(ShapeKind::Process, "執行", 80.0, 210.0, 120.0, 60.0),
                node(ShapeKind::Decision, "繼續？", 60.0, 310.0, 160.0, 90.0),
                node(ShapeKind::Terminator, "結束", 80.0, 450.0, 120.0, 50.0),
            ],
            edges: vec![
                (0, 1, ""),
                (1, 2, ""),
                (2, 3, ""),
                (3, 2, "是"),
                (3, 4, "否"),
            ],
        },
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_builtin_template_is_well_formed() {
        for t in builtin_templates() {
            assert!(!t.nodes.is_empty(), "{} 沒有節點", t.id);
            assert!(!t.edges.is_empty(), "{} 沒有連接", t.id);

            for (from, to, _) in &t.edges {
                assert!(*from < t.nodes.len(), "{} 的來源索引越界", t.id);
                assert!(*to < t.nodes.len(), "{} 的目標索引越界", t.id);
                assert_ne!(from, to, "{} 有自我連接", t.id);
            }
        }
    }

    #[test]
    fn templates_have_positive_size() {
        for t in builtin_templates() {
            let (w, h) = t.size();
            assert!(w > 0.0 && h > 0.0, "{} 的尺寸無效", t.id);
        }
    }

    #[test]
    fn nodes_do_not_have_degenerate_dimensions() {
        for t in builtin_templates() {
            for n in &t.nodes {
                assert!(n.width > 0.0 && n.height > 0.0, "{} 的節點尺寸無效", t.id);
            }
        }
    }

    #[test]
    fn flowchart_templates_use_standard_symbols() {
        // 用標準符號使用者才看得懂 —— 這是用範本而非自創圖形的理由。
        let decision = builtin_templates()
            .into_iter()
            .find(|t| t.id == "flow.decision")
            .unwrap();
        assert!(
            decision.nodes.iter().any(|n| n.kind == ShapeKind::Decision),
            "判斷流程必須有菱形"
        );
        assert!(
            decision
                .nodes
                .iter()
                .any(|n| n.kind == ShapeKind::Terminator),
            "必須有起終點符號"
        );
    }

    #[test]
    fn connections_match_the_edge_count() {
        for t in builtin_templates() {
            assert_eq!(t.connections().len(), t.edges.len(), "{}", t.id);
        }
    }

    #[test]
    fn branching_edges_carry_labels() {
        // 判斷的兩條分支必須標示是／否，否則讀不出邏輯。
        let decision = builtin_templates()
            .into_iter()
            .find(|t| t.id == "flow.decision")
            .unwrap();
        let labels: Vec<&str> = decision.edges.iter().map(|(_, _, l)| *l).collect();
        assert!(labels.contains(&"是"));
        assert!(labels.contains(&"否"));
    }

    #[test]
    fn loop_template_has_a_back_edge() {
        let looping = builtin_templates()
            .into_iter()
            .find(|t| t.id == "flow.loop")
            .unwrap();
        assert!(
            looping.edges.iter().any(|(from, to, _)| from > to),
            "迴圈必須有回頭的連接"
        );
    }

    #[test]
    fn template_ids_are_unique() {
        let mut ids: Vec<&str> = builtin_templates().iter().map(|t| t.id).collect();
        let count = ids.len();
        ids.sort_unstable();
        ids.dedup();
        assert_eq!(ids.len(), count, "範本 id 重複");
    }

    #[test]
    fn connections_face_each_other() {
        // 下方的節點應該從上方進入，否則線會繞遠路。
        let basic = builtin_templates()
            .into_iter()
            .find(|t| t.id == "flow.basic")
            .unwrap();
        for c in basic.connections() {
            assert_eq!(c.from_anchor, Anchor::Bottom);
            assert_eq!(c.to_anchor, Anchor::Top);
        }
    }
}
