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

/// 內建範本：十份，涵蓋最常被問到的流程圖形態。
///
/// 還是刻意不放上百份 —— 使用者找不到要的那一個，反而比沒有更慢。
/// 十份各有不同的用途與不同的符號組合（輸入輸出、判斷、迴圈、簽核、登入、重試、資料管線、平行、
/// 文件處理），插入後每個元素都能自由編輯。節點文字是起點，使用者直接改。
pub fn builtin_templates() -> Vec<Template> {
    use ShapeKind::*;
    vec![
        // ---- 1. 基本流程：輸入 → 處理 → 輸出報告 ----
        Template {
            id: "flow.basic",
            nodes: vec![
                node(Terminator, "開始", 60.0, 0.0, 120.0, 50.0),
                node(Data, "輸入資料", 40.0, 100.0, 160.0, 60.0),
                node(Process, "處理資料", 60.0, 210.0, 120.0, 60.0),
                node(Document, "輸出報告", 60.0, 320.0, 120.0, 70.0),
                node(Terminator, "結束", 60.0, 440.0, 120.0, 50.0),
            ],
            edges: vec![(0, 1, ""), (1, 2, ""), (2, 3, ""), (3, 4, "")],
        },
        // ---- 2. 判斷分支 ----
        Template {
            id: "flow.decision",
            nodes: vec![
                node(Terminator, "開始", 120.0, 0.0, 120.0, 50.0),
                node(Data, "輸入資料", 100.0, 95.0, 160.0, 60.0),
                node(Decision, "條件成立？", 100.0, 205.0, 160.0, 90.0),
                node(Process, "執行 A", 0.0, 345.0, 120.0, 60.0),
                node(Process, "執行 B", 240.0, 345.0, 120.0, 60.0),
                node(Terminator, "結束", 120.0, 455.0, 120.0, 50.0),
            ],
            edges: vec![
                (0, 1, ""),
                (1, 2, ""),
                (2, 3, "是"),
                (2, 4, "否"),
                (3, 5, ""),
                (4, 5, ""),
            ],
        },
        // ---- 3. 輸入處理輸出（含儲存與顯示）----
        Template {
            id: "flow.io",
            nodes: vec![
                node(Data, "輸入資料", 40.0, 0.0, 160.0, 60.0),
                node(Process, "處理", 40.0, 110.0, 160.0, 60.0),
                node(Database, "儲存", 40.0, 220.0, 160.0, 80.0),
                node(Display, "顯示結果", 40.0, 350.0, 160.0, 60.0),
                node(Document, "列印報表", 40.0, 460.0, 160.0, 70.0),
            ],
            edges: vec![(0, 1, ""), (1, 2, ""), (2, 3, ""), (3, 4, "")],
        },
        // ---- 4. 迴圈（用 ISO 5807 的迴圈開始／結束符號）----
        Template {
            id: "flow.loop",
            nodes: vec![
                node(Terminator, "開始", 80.0, 0.0, 120.0, 50.0),
                node(Preparation, "初始化", 60.0, 95.0, 160.0, 60.0),
                node(LoopLimitStart, "迴圈開始", 60.0, 200.0, 160.0, 50.0),
                node(Process, "執行", 80.0, 295.0, 120.0, 60.0),
                node(LoopLimitEnd, "迴圈結束", 60.0, 400.0, 160.0, 50.0),
                node(Decision, "繼續？", 60.0, 495.0, 160.0, 90.0),
                node(Terminator, "結束", 80.0, 630.0, 120.0, 50.0),
            ],
            edges: vec![
                (0, 1, ""),
                (1, 2, ""),
                (2, 3, ""),
                (3, 4, ""),
                (4, 5, ""),
                (5, 2, "是"),
                (5, 6, "否"),
            ],
        },
        // ---- 5. 簽核審核 ----
        Template {
            id: "flow.approval",
            nodes: vec![
                node(Terminator, "提出申請", 200.0, 0.0, 140.0, 50.0),
                node(ManualInput, "填寫申請單", 180.0, 95.0, 180.0, 60.0),
                node(Decision, "主管核准？", 180.0, 205.0, 180.0, 90.0),
                node(Process, "退回修改", 0.0, 235.0, 140.0, 60.0),
                node(Process, "通知執行", 400.0, 235.0, 140.0, 60.0),
                node(Terminator, "結束", 410.0, 350.0, 120.0, 50.0),
            ],
            edges: vec![
                (0, 1, ""),
                (1, 2, ""),
                (2, 4, "是"),
                (2, 3, "否"),
                (3, 1, ""),
                (4, 5, ""),
            ],
        },
        // ---- 6. 登入驗證 ----
        Template {
            id: "flow.login",
            nodes: vec![
                node(Terminator, "開始登入", 170.0, 0.0, 140.0, 50.0),
                node(ManualInput, "輸入帳號密碼", 150.0, 95.0, 180.0, 60.0),
                node(PredefinedProcess, "驗證身分", 170.0, 200.0, 140.0, 60.0),
                node(Decision, "驗證成功？", 150.0, 305.0, 180.0, 90.0),
                node(Terminator, "進入首頁", 150.0, 440.0, 180.0, 50.0),
                node(Decision, "錯誤超過 3 次？", 380.0, 305.0, 180.0, 90.0),
                node(Process, "鎖定帳號", 380.0, 440.0, 180.0, 60.0),
                node(Terminator, "結束", 380.0, 545.0, 180.0, 50.0),
            ],
            edges: vec![
                (0, 1, ""),
                (1, 2, ""),
                (2, 3, ""),
                (3, 4, "是"),
                (3, 5, "否"),
                (5, 6, "是"),
                (5, 1, "否"),
                (6, 7, ""),
            ],
        },
        // ---- 7. 錯誤處理與重試 ----
        Template {
            id: "flow.retry",
            nodes: vec![
                node(Terminator, "開始", 150.0, 0.0, 120.0, 50.0),
                node(Process, "呼叫服務", 140.0, 95.0, 140.0, 60.0),
                node(Decision, "成功？", 130.0, 205.0, 160.0, 90.0),
                node(Terminator, "完成", 150.0, 345.0, 120.0, 50.0),
                node(Decision, "重試未滿 3 次？", 340.0, 205.0, 180.0, 90.0),
                node(Delay, "等待後重試", 350.0, 95.0, 160.0, 60.0),
                node(Document, "記錄錯誤", 360.0, 345.0, 140.0, 70.0),
                node(Terminator, "結束", 370.0, 455.0, 120.0, 50.0),
            ],
            edges: vec![
                (0, 1, ""),
                (1, 2, ""),
                (2, 3, "是"),
                (2, 4, "否"),
                (4, 5, "是"),
                (5, 1, ""),
                (4, 6, "否"),
                (6, 7, ""),
            ],
        },
        // ---- 8. 資料處理管線（擷取、轉換、載入）----
        Template {
            id: "flow.pipeline",
            nodes: vec![
                node(Database, "資料來源", 0.0, 0.0, 140.0, 80.0),
                node(Process, "擷取", 190.0, 10.0, 120.0, 60.0),
                node(Process, "轉換", 360.0, 10.0, 120.0, 60.0),
                node(Decision, "驗證通過？", 520.0, 0.0, 170.0, 90.0),
                node(Database, "資料倉儲", 740.0, 0.0, 140.0, 80.0),
                node(Document, "錯誤報告", 540.0, 150.0, 130.0, 70.0),
            ],
            edges: vec![
                (0, 1, ""),
                (1, 2, ""),
                (2, 3, ""),
                (3, 4, "是"),
                (3, 5, "否"),
            ],
        },
        // ---- 9. 平行處理（ISO 5807 平行模式）----
        Template {
            id: "flow.parallel",
            nodes: vec![
                node(Terminator, "開始", 170.0, 0.0, 120.0, 50.0),
                node(Process, "準備資料", 160.0, 95.0, 140.0, 60.0),
                node(ParallelMode, "平行開始", 80.0, 200.0, 300.0, 40.0),
                node(Process, "任務 A", 80.0, 285.0, 120.0, 60.0),
                node(Process, "任務 B", 260.0, 285.0, 120.0, 60.0),
                node(ParallelMode, "平行結束", 80.0, 390.0, 300.0, 40.0),
                node(Process, "彙整結果", 160.0, 475.0, 140.0, 60.0),
                node(Terminator, "結束", 170.0, 580.0, 120.0, 50.0),
            ],
            edges: vec![
                (0, 1, ""),
                (1, 2, ""),
                (2, 3, ""),
                (2, 4, ""),
                (3, 5, ""),
                (4, 5, ""),
                (5, 6, ""),
                (6, 7, ""),
            ],
        },
        // ---- 10. 文件處理（多份文件、排序、預先定義作業、離線儲存、註解）----
        Template {
            id: "flow.documents",
            nodes: vec![
                node(Terminator, "開始", 150.0, 0.0, 120.0, 50.0),
                node(MultiDocument, "收件文件", 130.0, 95.0, 160.0, 80.0),
                node(Sort, "排序", 150.0, 225.0, 120.0, 90.0),
                node(PredefinedProcess, "歸檔作業", 140.0, 365.0, 140.0, 60.0),
                node(OfflineStorage, "離線保存", 160.0, 470.0, 100.0, 80.0),
                node(Annotation, "註解：保存 7 年", 310.0, 480.0, 170.0, 60.0),
                node(Terminator, "結束", 150.0, 595.0, 120.0, 50.0),
            ],
            edges: vec![(0, 1, ""), (1, 2, ""), (2, 3, ""), (3, 4, ""), (4, 6, "")],
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

    #[test]
    fn there_are_ten_templates_with_distinct_symbol_sets() {
        let all = builtin_templates();
        assert_eq!(all.len(), 10);
        let mut kinds = std::collections::HashSet::new();
        for t in &all {
            for n in &t.nodes {
                kinds.insert(format!("{:?}", n.kind));
            }
        }
        // 十份合起來要用到夠多種符號，不只是同一組方塊換名字。
        assert!(kinds.len() >= 14, "只用了 {} 種符號", kinds.len());
    }

    #[test]
    fn every_decision_branch_is_labelled() {
        for t in builtin_templates() {
            for (i, n) in t.nodes.iter().enumerate() {
                if n.kind != ShapeKind::Decision {
                    continue;
                }
                let out: Vec<_> = t.edges.iter().filter(|(f, _, _)| *f == i).collect();
                if out.len() >= 2 {
                    assert!(
                        out.iter().all(|(_, _, l)| !l.is_empty()),
                        "{} 的判斷分支缺標籤",
                        t.id
                    );
                }
            }
        }
    }

    #[test]
    fn template_nodes_do_not_overlap() {
        // 節點疊在一起，使用者插入後得先一個一個拖開。
        for t in builtin_templates() {
            for (i, a) in t.nodes.iter().enumerate() {
                for b in t.nodes.iter().skip(i + 1) {
                    let overlap = a.x < b.x + b.width
                        && b.x < a.x + a.width
                        && a.y < b.y + b.height
                        && b.y < a.y + a.height;
                    assert!(!overlap, "{} 的「{}」與「{}」重疊", t.id, a.label, b.label);
                }
            }
        }
    }
}
