//! 里程碑快照（時光機）—— 工作項 S-99。
//!
//! # 為什麼不是「把整份筆記複製一份」
//!
//! Apple 端原本的做法是把 `NotebookDocument` 編成 JSON、把每一頁的
//! `PKDrawing` 編成 Data，整包存成一個 `.snapshot` 檔。那份實作有三個問題，
//! 而且三個都只有在跨平台或多裝置時才會浮出來：
//!
//! 1. **不可攜。** `PKDrawing` 是 Apple 的私有格式，Android 讀不出來。
//!    在 iPad 上建的快照，換到 Android 就是一個打不開的檔。
//! 2. **與同步互斥。** 還原的做法是「整份覆蓋」，但這個專案的筆記本是
//!    append-only 的 CRDT（ADR-0002）—— 覆蓋等於把另一台裝置同時寫進來的
//!    東西默默吃掉，而且沒有任何衝突訊號。
//! 3. **體積隨內容線性成長。** 每建一次快照就多一份完整副本。
//!
//! # 這裡的做法：快照是「歷史上的一刀」，不是副本
//!
//! 筆記本的狀態完全由 oplog 決定，而 oplog 的每個檔案都帶著
//! `(lamport, device)`。所以「那個時候的樣子」可以只用一組**向量時鐘**表示：
//! 「device 1 寫到 lamport 7、device 2 寫到 lamport 3」。筆畫同理 ——
//! `ink/<page>-<device>.strokes` 是純追加，記下「那時候有幾筆」就夠了。
//!
//! 快照因此是**常數大小**（每台裝置幾個位元組），而且兩個平台讀的是同一組
//! 數字，不是某一邊的私有格式。
//!
//! # 還原也是一筆 op，不是一次覆蓋
//!
//! 還原寫進 oplog 的是 [`DocOp::RestoreMilestone`]，它說的是
//! 「**遮蔽**區間 `(cut, upto]` 之內的操作」。既有的位元組一個都沒被改動，
//! 所以同步的「較長的是超集」仍然成立，其他裝置收到這一筆之後會算出
//! 同樣的結果。
//!
//! 用「區間」而不是「大於 cut 就遮蔽」是必要的：還原之後繼續寫的東西
//! lamport 一定比 cut 大，若只看下界，使用者還原完再寫的字會立刻消失。
//! `upto` 記的是**下手還原的那一刻**已經存在的上界，區間之外的一律保留。
//!
//! # 還原一定可以反悔
//!
//! [`RestoreMilestone`] 本身也是 oplog 裡的一筆，也會被後來的還原遮蔽。
//! 所以上層在執行還原**之前**必須先自動建一個里程碑（見
//! `padnote-core` 的 `milestone_restore`）—— 還原到那一個，就等於取消這次還原。
//! 少了這一步，時光機就變成單向的，而那是一個沒有錯誤訊息的資料遺失。

use crate::Uuid;
use crate::ops::DocOp;
use std::collections::BTreeMap;

/// 文件操作的向量時鐘：`device -> 已寫到的最大 lamport`。
pub type DocClock = BTreeMap<u32, u64>;

/// 筆畫的向量時鐘：`(page, device) -> 已寫入的記錄筆數`。
pub type InkClock = BTreeMap<(Uuid, u32), u32>;

/// 歷史上的一刀。
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct MilestoneCut {
    pub doc: DocClock,
    pub ink: InkClock,
}

impl MilestoneCut {
    /// 這台裝置在這一刀時寫到哪個 lamport（沒寫過就是 0）。
    pub fn doc_at(&self, device: u32) -> u64 {
        self.doc.get(&device).copied().unwrap_or(0)
    }

    /// 這一頁、這台裝置在這一刀時有幾筆記錄。
    pub fn ink_at(&self, page: Uuid, device: u32) -> u32 {
        self.ink.get(&(page, device)).copied().unwrap_or(0)
    }
}

/// oplog 裡的一筆，帶著它的來源座標。
///
/// `lamport` 與 `device` 取自檔名 —— 見 `padnote-storage` 的 `append_doc_ops`。
#[derive(Clone, Debug)]
pub struct OpEntry {
    pub lamport: u64,
    pub device: u32,
    pub op: DocOp,
}

/// 一個具名的里程碑。
#[derive(Clone, Debug, PartialEq)]
pub struct Milestone {
    pub id: Uuid,
    pub title: String,
    pub creator: String,
    /// Unix epoch 毫秒。**不是** `NotebookTime` ——
    /// 這是要顯示給人看的掛鐘時間，筆記本時間軸的原點對使用者沒有意義。
    pub created_unix_ms: u64,
    pub cut: MilestoneCut,
    /// 上層執行還原時自動建立的（見模組說明）。UI 可以把它收在
    /// 「自動」分組裡，免得使用者自己命名的里程碑被淹沒。
    pub automatic: bool,
}

/// 一次還原的遮蔽區間。
#[derive(Clone, Debug)]
struct Suppression {
    lamport: u64,
    device: u32,
    cut: MilestoneCut,
    upto: MilestoneCut,
}

impl Suppression {
    /// 這一筆文件操作落在遮蔽區間內嗎？
    fn hides_doc(&self, lamport: u64, device: u32) -> bool {
        lamport > self.cut.doc_at(device) && lamport <= self.upto.doc_at(device)
    }

    /// 這一筆筆畫記錄（第 `index` 筆，從 0 起算）落在遮蔽區間內嗎？
    fn hides_ink(&self, page: Uuid, device: u32, index: u32) -> bool {
        index >= self.cut.ink_at(page, device) && index < self.upto.ink_at(page, device)
    }
}

/// 解析結果。
#[derive(Debug)]
pub struct Resolved {
    /// 已經濾掉被遮蔽者的操作序列，可直接重播。
    pub ops: Vec<DocOp>,
    /// 全部里程碑，新的在前。
    pub milestones: Vec<Milestone>,
    /// 生效中的還原，供 [`visible_ink_indices`] 使用。
    suppressions: Vec<Suppression>,
}

impl Resolved {
    /// 這一頁、這台裝置的哪幾筆筆畫記錄還看得見。
    ///
    /// 回傳的是**索引**而不是記錄本身：呼叫端手上才有真正的位元組，
    /// 而把記錄搬進來只是為了過濾一次，不值得多一次複製。
    pub fn visible_ink_indices(&self, page: Uuid, device: u32, count: u32) -> Vec<u32> {
        (0..count)
            .filter(|i| {
                !self
                    .suppressions
                    .iter()
                    .any(|s| s.hides_ink(page, device, *i))
            })
            .collect()
    }

    /// 完全沒有任何還原時為真 —— 呼叫端可以走不過濾的快路徑。
    pub fn is_pristine(&self) -> bool {
        self.suppressions.is_empty()
    }
}

/// 把帶座標的 oplog 解析成「目前看得到的操作」與里程碑清單。
///
/// `entries` 必須已經照 `(lamport, device)` 排好 —— `padnote-storage`
/// 依檔名字典序讀檔，字典序就是這個順序。
pub fn resolve(entries: Vec<OpEntry>) -> Resolved {
    // 第一步：找出**生效中**的還原。
    //
    // 還原遮蔽的是比它早的東西，所以一個還原會不會被取消，只取決於比它
    // **晚**的還原。從最晚的往回看，每一個都問「已經確定生效的那些有沒有
    // 遮到我」—— 沒有才算數。這樣一趟就定下來，不需要疊代到收斂。
    let mut candidates: Vec<Suppression> = entries
        .iter()
        .filter_map(|e| match &e.op {
            DocOp::RestoreMilestone { cut, upto, .. } => Some(Suppression {
                lamport: e.lamport,
                device: e.device,
                cut: cut.clone(),
                upto: upto.clone(),
            }),
            _ => None,
        })
        .collect();
    candidates.sort_by_key(|s| (s.lamport, s.device));

    let mut suppressions: Vec<Suppression> = Vec::new();
    for cand in candidates.into_iter().rev() {
        if suppressions
            .iter()
            .any(|s| s.hides_doc(cand.lamport, cand.device))
        {
            continue; // 這次還原已經被後來的還原取消掉了
        }
        suppressions.push(cand);
    }

    // 第二步：過濾操作、收集里程碑。
    let mut ops = Vec::with_capacity(entries.len());
    let mut milestones = Vec::new();
    for e in entries {
        // 里程碑標記**永遠不遮蔽**。它只是一個名字加一組數字，留著才有
        // 「還原完再還原回去」的路；遮掉它等於把時光機變成單向的。
        if let DocOp::MarkMilestone {
            id,
            title,
            creator,
            created_unix_ms,
            cut,
            automatic,
        } = &e.op
        {
            milestones.push(Milestone {
                id: *id,
                title: title.clone(),
                creator: creator.clone(),
                created_unix_ms: *created_unix_ms,
                cut: cut.clone(),
                automatic: *automatic,
            });
            continue;
        }
        if matches!(e.op, DocOp::RestoreMilestone { .. }) {
            continue; // 還原本身不是狀態變更，效果已經體現在過濾上
        }
        if matches!(e.op, DocOp::BatchOrigin { .. }) {
            continue; // 只是座標標記，`padnote-storage` 讀的時候就用掉了
        }
        if suppressions
            .iter()
            .any(|s| s.hides_doc(e.lamport, e.device))
        {
            continue;
        }
        ops.push(e.op);
    }
    milestones.sort_by_key(|m| std::cmp::Reverse(m.created_unix_ms));

    Resolved {
        ops,
        milestones,
        suppressions,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn uuid(b: u8) -> Uuid {
        Uuid::from_bytes([b; 16])
    }

    fn title(lamport: u64, device: u32, t: &str) -> OpEntry {
        OpEntry {
            lamport,
            device,
            op: DocOp::SetTitle { title: t.into() },
        }
    }

    fn clock(pairs: &[(u32, u64)]) -> MilestoneCut {
        MilestoneCut {
            doc: pairs.iter().copied().collect(),
            ink: BTreeMap::new(),
        }
    }

    fn mark(lamport: u64, device: u32, id: u8, cut: MilestoneCut) -> OpEntry {
        OpEntry {
            lamport,
            device,
            op: DocOp::MarkMilestone {
                id: uuid(id),
                title: format!("m{id}"),
                creator: "測試".into(),
                created_unix_ms: 1_000 + id as u64,
                cut,
                automatic: false,
            },
        }
    }

    fn restore(
        lamport: u64,
        device: u32,
        id: u8,
        cut: MilestoneCut,
        upto: MilestoneCut,
    ) -> OpEntry {
        OpEntry {
            lamport,
            device,
            op: DocOp::RestoreMilestone {
                milestone: uuid(id),
                cut,
                upto,
            },
        }
    }

    fn titles(r: &Resolved) -> Vec<String> {
        r.ops
            .iter()
            .filter_map(|o| match o {
                DocOp::SetTitle { title } => Some(title.clone()),
                _ => None,
            })
            .collect()
    }

    #[test]
    fn without_restores_everything_survives() {
        let r = resolve(vec![title(1, 1, "甲"), title(2, 1, "乙")]);
        assert_eq!(titles(&r), ["甲", "乙"]);
        assert!(r.is_pristine());
    }

    #[test]
    fn restore_hides_only_the_interval() {
        // 在 lamport 1 之後建里程碑，寫到 3，然後還原回去，再寫第 5 筆。
        let r = resolve(vec![
            title(1, 1, "甲"),
            mark(2, 1, 1, clock(&[(1, 1)])),
            title(3, 1, "乙"),
            restore(4, 1, 1, clock(&[(1, 1)]), clock(&[(1, 3)])),
            title(5, 1, "丙"),
        ]);
        // 「乙」在區間內被遮蔽；「丙」在還原之後寫的，必須留著 ——
        // 少了 upto 上界的話，使用者還原完再打的字會當場消失。
        assert_eq!(titles(&r), ["甲", "丙"]);
    }

    #[test]
    fn a_later_restore_undoes_an_earlier_one() {
        // 這是「還原可以反悔」的那條路：還原前先自動建 m2，
        // 之後還原到 m2 就把第一次還原本身遮掉，「乙」因此回來。
        let r = resolve(vec![
            title(1, 1, "甲"),
            mark(2, 1, 1, clock(&[(1, 1)])),
            title(3, 1, "乙"),
            mark(4, 1, 2, clock(&[(1, 3)])),
            restore(5, 1, 1, clock(&[(1, 1)]), clock(&[(1, 4)])),
            restore(6, 1, 2, clock(&[(1, 3)]), clock(&[(1, 5)])),
        ]);
        assert_eq!(titles(&r), ["甲", "乙"]);
    }

    #[test]
    fn marks_survive_a_restore_that_covers_them() {
        // 里程碑標記本身不被遮蔽 —— 否則還原之後清單會縮短，
        // 使用者就再也找不到路走回來。
        let r = resolve(vec![
            mark(1, 1, 1, clock(&[])),
            mark(2, 1, 2, clock(&[(1, 1)])),
            restore(3, 1, 1, clock(&[]), clock(&[(1, 2)])),
        ]);
        assert_eq!(r.milestones.len(), 2);
    }

    #[test]
    fn another_devices_later_work_is_untouched() {
        // 裝置 2 在 lamport 3 寫的東西，不在裝置 1 的還原區間裡 ——
        // 還原自己的歷史不該把別人同時寫進來的東西吃掉。
        let r = resolve(vec![
            title(1, 1, "甲"),
            title(3, 2, "他人"),
            restore(4, 1, 1, clock(&[(1, 0)]), clock(&[(1, 1)])),
        ]);
        assert_eq!(titles(&r), ["他人"]);
    }

    #[test]
    fn ink_indices_are_filtered_by_the_same_interval() {
        let page = uuid(9);
        let cut = MilestoneCut {
            doc: [(1, 0)].into_iter().collect(),
            ink: [((page, 1), 2)].into_iter().collect(),
        };
        let upto = MilestoneCut {
            doc: [(1, 1)].into_iter().collect(),
            ink: [((page, 1), 5)].into_iter().collect(),
        };
        let r = resolve(vec![restore(2, 1, 1, cut, upto)]);
        // 0、1 在快照裡；2–4 是之後畫的，遮掉；5 以後是還原之後畫的，留著。
        assert_eq!(r.visible_ink_indices(page, 1, 7), [0, 1, 5, 6]);
    }
}
