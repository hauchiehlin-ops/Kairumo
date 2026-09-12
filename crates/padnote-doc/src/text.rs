//! 文字 CRDT（功能 B1/B2，工作項 S-16）。
//!
//! 筆畫用 append-only + 墓碑就能收斂（ADR-0002），但文字不行 ——
//! 「在第 5 個字後面插入」這種位置參照在併發編輯下會錯位。
//!
//! ## 演算法：timestamped insertion tree
//! 每個字元是一個節點，記錄它插在**誰的後面**（origin），而不是「第幾個位置」。
//! 同一個 origin 下的併發插入以 `OpId` 遞減排序。文字 = 前序走訪。
//!
//! 收斂性來自兩個性質：
//! 1. 樹的結構只取決於**操作的集合**，與套用順序無關
//! 2. 兄弟節點的排序依據 `OpId` 這個全序關係
//!
//! ⇒ 任意順序套用同一組操作，結果必然相同。
//!
//! ## 為什麼不用 yrs / Automerge
//! 兩者都很好，但這裡的需求是**純文字**（粗體、標題、待辦這些屬性住在
//! `Block` 層級，不在字元流裡），用不到它們的 rich-text 機制。
//! 自己實作換到的是：與現有 oplog／Lamport 基礎設施一致、零額外相依、
//! 且每一條收斂性質都有測試釘住。若日後需要字元層級屬性，可換成 yrs。

use std::collections::{BTreeMap, HashMap};
use std::fmt;

/// 操作識別碼。`(seq, site)` 的字典序構成全序 —— 兄弟排序靠它。
///
/// `site` 放在後面當 tie-breaker：同一個邏輯時刻的併發操作，
/// 由 site id 決定順序，任何節點算出來的結果都一樣。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct OpId {
    pub seq: u64,
    pub site: u32,
}

impl OpId {
    pub fn new(site: u32, seq: u64) -> Self {
        Self { seq, site }
    }
}

impl fmt::Display for OpId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}@{:08x}", self.seq, self.site)
    }
}

/// 一個文字操作。可交換、冪等。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum TextOp {
    Insert {
        id: OpId,
        /// 插在誰的後面。`None` 表示插在開頭。
        origin: Option<OpId>,
        ch: char,
    },
    /// 墓碑。刪除不移除節點，否則其他人的 origin 參照會斷掉。
    Delete { id: OpId },
}

impl TextOp {
    pub fn id(&self) -> OpId {
        match self {
            Self::Insert { id, .. } | Self::Delete { id } => *id,
        }
    }
}

#[derive(Clone, Debug)]
struct Node {
    ch: char,
    deleted: bool,
}

/// 一個文字區塊的 CRDT 狀態。
#[derive(Clone, Debug, Default)]
pub struct TextCrdt {
    nodes: HashMap<OpId, Node>,
    /// origin → 子節點（依 OpId 遞減排序）。`None` 鍵代表根。
    children: BTreeMap<Option<OpId>, Vec<OpId>>,
    /// origin 尚未抵達的插入操作，等 origin 出現再套用。
    pending: Vec<TextOp>,
    /// 對尚未存在的節點的刪除。同樣必須緩衝，否則會被靜默丟棄。
    pending_deletes: Vec<OpId>,
}

impl TextCrdt {
    pub fn new() -> Self {
        Self::default()
    }

    /// 套用一個操作。**冪等**：重複套用同一個 op 不改變結果。
    pub fn apply(&mut self, op: TextOp) {
        match op {
            TextOp::Insert { id, origin, ch } => {
                if self.nodes.contains_key(&id) {
                    return; // 已套用過
                }
                // origin 還沒到 ⇒ 緩衝。同步時操作抵達順序無法保證。
                if let Some(o) = origin
                    && !self.nodes.contains_key(&o)
                {
                    self.pending.push(TextOp::Insert { id, origin, ch });
                    return;
                }

                self.nodes.insert(id, Node { ch, deleted: false });
                let siblings = self.children.entry(origin).or_default();
                // 遞減排序：後來的併發插入排在前面。任何節點算出來都一樣。
                let pos = siblings.partition_point(|s| *s > id);
                siblings.insert(pos, id);

                self.drain_pending();
            }
            TextOp::Delete { id } => {
                match self.nodes.get_mut(&id) {
                    Some(n) => n.deleted = true,
                    // 刪除先於插入抵達 —— 必須緩衝而非丟棄，否則不收斂。
                    None => self.pending_deletes.push(id),
                }
            }
        }
    }

    pub fn apply_all(&mut self, ops: impl IntoIterator<Item = TextOp>) {
        for op in ops {
            self.apply(op);
        }
    }

    /// 反覆嘗試緩衝中的操作，直到沒有新的可套用。
    fn drain_pending(&mut self) {
        loop {
            let ready: Vec<TextOp> = self
                .pending
                .iter()
                .filter(|op| match op {
                    TextOp::Insert { origin, .. } => {
                        origin.is_none_or(|o| self.nodes.contains_key(&o))
                    }
                    TextOp::Delete { .. } => true,
                })
                .cloned()
                .collect();

            if ready.is_empty() {
                break;
            }
            self.pending.retain(|op| !ready.contains(op));
            for op in ready {
                self.apply(op);
            }
        }

        // 補上曾經早到的刪除
        let landed: Vec<OpId> = self
            .pending_deletes
            .iter()
            .copied()
            .filter(|id| self.nodes.contains_key(id))
            .collect();
        if !landed.is_empty() {
            self.pending_deletes.retain(|id| !landed.contains(id));
            for id in landed {
                if let Some(n) = self.nodes.get_mut(&id) {
                    n.deleted = true;
                }
            }
        }
    }

    /// 目前的文字內容。
    pub fn text(&self) -> String {
        let mut out = String::new();
        self.walk(None, &mut out);
        out
    }

    fn walk(&self, origin: Option<OpId>, out: &mut String) {
        let Some(kids) = self.children.get(&origin) else {
            return;
        };
        for &id in kids {
            if let Some(n) = self.nodes.get(&id)
                && !n.deleted
            {
                out.push(n.ch);
            }
            // 即使被刪除也要走訪子節點 —— 墓碑仍是別人的 origin。
            self.walk(Some(id), out);
        }
    }

    /// 可見字元的 `OpId`，依文字順序排列。編輯 API 靠它把「第 N 個字」
    /// 轉成穩定的 id 參照。
    pub fn visible_ids(&self) -> Vec<OpId> {
        let mut out = Vec::new();
        self.collect_visible(None, &mut out);
        out
    }

    fn collect_visible(&self, origin: Option<OpId>, out: &mut Vec<OpId>) {
        let Some(kids) = self.children.get(&origin) else {
            return;
        };
        for &id in kids {
            if let Some(n) = self.nodes.get(&id)
                && !n.deleted
            {
                out.push(id);
            }
            self.collect_visible(Some(id), out);
        }
    }

    pub fn len(&self) -> usize {
        self.nodes.values().filter(|n| !n.deleted).count()
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    /// 尚未能套用的操作數。非零代表還有 op 在路上；同步完成後應歸零。
    pub fn pending_count(&self) -> usize {
        self.pending.len() + self.pending_deletes.len()
    }
}

/// 本地編輯器：把「在第 N 個字元位置插入／刪除」轉成 CRDT 操作。
///
/// 分開成獨立型別，是為了讓 `TextCrdt` 保持純粹的「套用操作」語意 ——
/// 遠端來的操作永遠不該經過位置換算。
#[derive(Debug)]
pub struct TextEditor {
    site: u32,
    seq: u64,
}

impl TextEditor {
    pub fn new(site: u32) -> Self {
        Self { site, seq: 0 }
    }

    /// 讓本地時鐘至少追上看過的最大 seq，避免重連後產生重複 id。
    pub fn observe(&mut self, id: OpId) {
        self.seq = self.seq.max(id.seq);
    }

    fn next_id(&mut self) -> OpId {
        self.seq += 1;
        OpId::new(self.site, self.seq)
    }

    /// 在可見文字的第 `index` 個位置插入字串。`index == len` 表示接在最後。
    pub fn insert(&mut self, crdt: &TextCrdt, index: usize, s: &str) -> Vec<TextOp> {
        let visible = crdt.visible_ids();
        let mut origin = if index == 0 {
            None
        } else {
            visible.get(index - 1).copied()
        };

        let mut ops = Vec::with_capacity(s.chars().count());
        for ch in s.chars() {
            let id = self.next_id();
            ops.push(TextOp::Insert { id, origin, ch });
            origin = Some(id); // 後續字元接在前一個字元後面
        }
        ops
    }

    /// 刪除從 `index` 起的 `count` 個可見字元。
    pub fn delete(&mut self, crdt: &TextCrdt, index: usize, count: usize) -> Vec<TextOp> {
        crdt.visible_ids()
            .into_iter()
            .skip(index)
            .take(count)
            .map(|id| TextOp::Delete { id })
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn doc(site: u32) -> (TextCrdt, TextEditor) {
        (TextCrdt::new(), TextEditor::new(site))
    }

    fn typed(site: u32, s: &str) -> (TextCrdt, TextEditor, Vec<TextOp>) {
        let (mut c, mut e) = doc(site);
        let ops = e.insert(&c, 0, s);
        c.apply_all(ops.clone());
        (c, e, ops)
    }

    #[test]
    fn sequential_typing_reads_back() {
        let (c, _, _) = typed(1, "線性代數");
        assert_eq!(c.text(), "線性代數");
        assert_eq!(c.len(), 4);
    }

    #[test]
    fn insert_in_the_middle() {
        let (mut c, mut e, _) = typed(1, "線性數");
        let ops = e.insert(&c, 2, "代");
        c.apply_all(ops);
        assert_eq!(c.text(), "線性代數");
    }

    #[test]
    fn insert_at_the_beginning() {
        let (mut c, mut e, _) = typed(1, "代數");
        let ops = e.insert(&c, 0, "線性");
        c.apply_all(ops);
        assert_eq!(c.text(), "線性代數");
    }

    #[test]
    fn delete_removes_from_view_but_keeps_the_node() {
        let (mut c, mut e, _) = typed(1, "線性代數");
        let ops = e.delete(&c, 0, 2);
        c.apply_all(ops);

        assert_eq!(c.text(), "代數");
        assert_eq!(c.len(), 2);
        // 墓碑仍在，否則別人的 origin 參照會斷掉
        assert_eq!(c.nodes.len(), 4);
    }

    #[test]
    fn deleting_a_character_others_reference_keeps_their_text() {
        // 最經典的 CRDT 陷阱：A 刪掉某字，B 同時在那個字後面打字。
        let (mut a, mut ea, ops) = typed(1, "abc");
        let mut b = TextCrdt::new();
        b.apply_all(ops.clone());
        let mut eb = TextEditor::new(2);
        eb.observe(ops.last().unwrap().id());

        let del = ea.delete(&a, 1, 1); // A 刪掉 'b'
        let ins = eb.insert(&b, 2, "X"); // B 在 'b' 後面插入 'X'

        a.apply_all(ins.clone());
        b.apply_all(del.clone());
        a.apply_all(del);
        b.apply_all(ins);

        assert_eq!(a.text(), b.text());
        assert_eq!(a.text(), "aXc", "B 插入的字不該隨 'b' 一起消失");
    }

    #[test]
    fn concurrent_inserts_at_the_same_position_converge() {
        let (mut a, mut ea, base) = typed(1, "ac");
        let mut b = TextCrdt::new();
        b.apply_all(base.clone());
        let mut eb = TextEditor::new(2);
        eb.observe(base.last().unwrap().id());

        // 兩邊各自在本地插入（都看不到對方）
        let from_a = ea.insert(&a, 1, "1");
        a.apply_all(from_a.clone());
        let from_b = eb.insert(&b, 1, "2");
        b.apply_all(from_b.clone());
        assert_eq!(a.text(), "a1c");
        assert_eq!(b.text(), "a2c");

        // 交換操作後必須收斂到同一個結果
        a.apply_all(from_b);
        b.apply_all(from_a);

        assert_eq!(a.text(), b.text(), "併發插入必須收斂");
        assert_eq!(a.len(), 4, "兩個字都要保留，不能有人被覆蓋");
        assert!(a.text().starts_with('a') && a.text().ends_with('c'));
    }

    #[test]
    fn operation_order_does_not_matter() {
        // 這是收斂性的核心：同一組 op，任意順序套用結果相同。
        let (_, mut e) = doc(1);
        let mut src = TextCrdt::new();
        let mut ops = e.insert(&src, 0, "hello");
        src.apply_all(ops.clone());
        ops.extend(e.insert(&src, 5, " world"));

        let mut forward = TextCrdt::new();
        forward.apply_all(ops.clone());

        let mut reversed = TextCrdt::new();
        let mut rev = ops.clone();
        rev.reverse();
        reversed.apply_all(rev);

        assert_eq!(forward.text(), "hello world");
        assert_eq!(reversed.text(), forward.text(), "逆序套用必須得到相同結果");
        assert_eq!(reversed.pending_count(), 0, "所有緩衝的 op 都該被消化");
    }

    #[test]
    fn delete_arriving_before_insert_is_buffered_not_dropped() {
        // 丟棄早到的刪除會讓兩端永久不一致。
        let (_, mut e) = doc(1);
        let src = TextCrdt::new();
        let ins = e.insert(&src, 0, "x");
        let id = ins[0].id();

        let mut c = TextCrdt::new();
        c.apply(TextOp::Delete { id });
        assert_eq!(c.pending_count(), 1);

        c.apply_all(ins);
        assert_eq!(c.text(), "", "早到的刪除必須在插入抵達後生效");
        assert_eq!(c.pending_count(), 0);
    }

    #[test]
    fn applying_the_same_op_twice_is_idempotent() {
        let (mut c, _, ops) = typed(1, "abc");
        c.apply_all(ops.clone());
        c.apply_all(ops);
        assert_eq!(c.text(), "abc", "重複套用不該產生重複字元");
    }

    #[test]
    fn editor_clock_avoids_duplicate_ids_after_reconnect() {
        let (c, _e, _) = typed(1, "abc");
        // 模擬同一個 site 換了新的 editor 實例（App 重啟）
        let mut fresh = TextEditor::new(1);
        for id in c.visible_ids() {
            fresh.observe(id);
        }
        let ops = fresh.insert(&c, 3, "d");
        assert!(
            ops[0].id().seq > 3,
            "新操作的 seq 必須大於已看過的，否則 id 會撞"
        );
    }

    #[test]
    fn empty_document_operations_are_safe() {
        let (c, mut e) = doc(1);
        assert!(c.is_empty());
        assert!(e.delete(&c, 0, 10).is_empty(), "刪除空文件不該 panic");
        assert!(e.insert(&c, 0, "").is_empty());
    }

    #[test]
    fn chinese_characters_are_single_units() {
        // 用 byte index 會把中文切壞 —— 這裡一律以字元為單位。
        let (mut c, mut e, _) = typed(1, "線性代數");
        let ops = e.delete(&c, 1, 1);
        c.apply_all(ops);
        assert_eq!(c.text(), "線代數");
    }
}

/// 文字操作的二進位編碼。
///
/// 操作要進 oplog 才能同步，因此需要穩定的線上格式。刻意不用 JSON：
/// 每個字元一個 op，JSON 的體積開銷在長文件上很可觀。
pub mod codec {
    use super::{OpId, TextOp};

    const KIND_INSERT: u8 = 1;
    const KIND_DELETE: u8 = 2;

    #[derive(Debug, PartialEq, Eq)]
    pub enum TextCodecError {
        Truncated,
        UnknownKind(u8),
        InvalidChar(u32),
    }

    impl std::fmt::Display for TextCodecError {
        fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
            match self {
                Self::Truncated => write!(f, "文字操作資料被截斷"),
                Self::UnknownKind(k) => write!(f, "未知的操作類型：{k}"),
                Self::InvalidChar(c) => write!(f, "非法的 Unicode 碼位：{c}"),
            }
        }
    }

    impl std::error::Error for TextCodecError {}

    fn put_id(out: &mut Vec<u8>, id: OpId) {
        out.extend_from_slice(&id.seq.to_le_bytes());
        out.extend_from_slice(&id.site.to_le_bytes());
    }

    pub fn encode(ops: &[TextOp]) -> Vec<u8> {
        let mut out = Vec::with_capacity(ops.len() * 24);
        for op in ops {
            match op {
                TextOp::Insert { id, origin, ch } => {
                    out.push(KIND_INSERT);
                    put_id(&mut out, *id);
                    match origin {
                        Some(o) => {
                            out.push(1);
                            put_id(&mut out, *o);
                        }
                        None => out.push(0),
                    }
                    out.extend_from_slice(&(*ch as u32).to_le_bytes());
                }
                TextOp::Delete { id } => {
                    out.push(KIND_DELETE);
                    put_id(&mut out, *id);
                }
            }
        }
        out
    }

    pub fn decode(data: &[u8]) -> Result<Vec<TextOp>, TextCodecError> {
        let mut out = Vec::new();
        let mut p = 0usize;

        let take = |n: usize, p: &mut usize| -> Result<&[u8], TextCodecError> {
            let end = p.checked_add(n).ok_or(TextCodecError::Truncated)?;
            let s = data.get(*p..end).ok_or(TextCodecError::Truncated)?;
            *p = end;
            Ok(s)
        };

        while p < data.len() {
            let kind = take(1, &mut p)?[0];
            let id = {
                let b = take(12, &mut p)?;
                OpId {
                    seq: u64::from_le_bytes(b[0..8].try_into().unwrap()),
                    site: u32::from_le_bytes(b[8..12].try_into().unwrap()),
                }
            };
            match kind {
                KIND_DELETE => out.push(TextOp::Delete { id }),
                KIND_INSERT => {
                    let origin = if take(1, &mut p)?[0] == 1 {
                        let b = take(12, &mut p)?;
                        Some(OpId {
                            seq: u64::from_le_bytes(b[0..8].try_into().unwrap()),
                            site: u32::from_le_bytes(b[8..12].try_into().unwrap()),
                        })
                    } else {
                        None
                    };
                    let cp = u32::from_le_bytes(take(4, &mut p)?.try_into().unwrap());
                    let ch = char::from_u32(cp).ok_or(TextCodecError::InvalidChar(cp))?;
                    out.push(TextOp::Insert { id, origin, ch });
                }
                k => return Err(TextCodecError::UnknownKind(k)),
            }
        }
        Ok(out)
    }

    #[cfg(test)]
    mod tests {
        use super::*;
        use crate::text::{TextCrdt, TextEditor};

        #[test]
        fn roundtrips_inserts_and_deletes() {
            let mut c = TextCrdt::new();
            let mut e = TextEditor::new(7);
            let mut ops = e.insert(&c, 0, "線性代數 abc");
            c.apply_all(ops.clone());
            ops.extend(e.delete(&c, 2, 2));

            let decoded = decode(&encode(&ops)).unwrap();
            assert_eq!(decoded, ops);
        }

        #[test]
        fn handles_astral_plane_characters() {
            // emoji 是 4-byte 碼位，用 u16 存會壞掉。
            let mut c = TextCrdt::new();
            let mut e = TextEditor::new(1);
            let ops = e.insert(&c, 0, "筆記 🖋️");
            c.apply_all(ops.clone());

            let mut restored = TextCrdt::new();
            restored.apply_all(decode(&encode(&ops)).unwrap());
            assert_eq!(restored.text(), c.text());
        }

        #[test]
        fn empty_input_yields_no_ops() {
            assert!(decode(&[]).unwrap().is_empty());
            assert!(encode(&[]).is_empty());
        }

        #[test]
        fn truncated_data_is_reported() {
            let mut c = TextCrdt::new();
            let mut e = TextEditor::new(1);
            let ops = e.insert(&c, 0, "x");
            c.apply_all(ops.clone());

            let mut bytes = encode(&ops);
            bytes.truncate(bytes.len() - 3);
            assert_eq!(decode(&bytes), Err(TextCodecError::Truncated));
        }

        #[test]
        fn unknown_kind_is_rejected_not_skipped() {
            let bad = vec![99u8, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0];
            assert_eq!(decode(&bad), Err(TextCodecError::UnknownKind(99)));
        }

        #[test]
        fn invalid_codepoint_is_rejected() {
            let mut bytes = vec![1u8];
            bytes.extend_from_slice(&1u64.to_le_bytes());
            bytes.extend_from_slice(&1u32.to_le_bytes());
            bytes.push(0);
            bytes.extend_from_slice(&0xD800u32.to_le_bytes()); // surrogate，非法
            assert_eq!(decode(&bytes), Err(TextCodecError::InvalidChar(0xD800)));
        }
    }
}
