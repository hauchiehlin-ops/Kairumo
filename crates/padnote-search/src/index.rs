//! 倒排索引與查詢。
//!
//! 支援**增量更新** —— 使用者邊寫邊建索引，不能每次都全量重建。

use crate::tokenizer::tokenize;
use std::collections::{BTreeMap, BTreeSet, HashMap};

/// 索引內容的來源。讓 UI 能顯示「這個命中來自轉錄／手寫／PDF」。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Debug, Hash)]
pub enum Source {
    /// 打字輸入
    Text,
    /// 錄音轉錄（C2）
    Transcript,
    /// 手寫辨識（D1/D3）
    Handwriting,
    /// PDF 內嵌文字層
    PdfText,
    /// 掃描件 OCR（D4）
    Ocr,
}

impl Source {
    /// 排序權重。打字文字最可信，OCR 與手寫辨識可能有誤，排後面。
    pub fn rank_weight(self) -> f32 {
        match self {
            Self::Text => 1.0,
            Self::PdfText => 0.9,
            Self::Transcript => 0.8,
            Self::Handwriting => 0.6,
            Self::Ocr => 0.5,
        }
    }
}

/// 被索引的一個單位（一頁的一個內容區塊）。
#[derive(Clone, PartialEq, Eq, PartialOrd, Ord, Debug, Hash)]
pub struct DocId {
    pub notebook: String,
    pub page: String,
    pub block: String,
}

impl DocId {
    pub fn new(notebook: &str, page: &str, block: &str) -> Self {
        Self {
            notebook: notebook.into(),
            page: page.into(),
            block: block.into(),
        }
    }
}

#[derive(Clone, Debug)]
pub struct Hit {
    pub doc: DocId,
    pub source: Source,
    pub score: f32,
    /// 命中處的原文片段，供 UI 顯示。
    pub snippet: String,
}

#[derive(Clone, Debug)]
struct Entry {
    source: Source,
    text: String,
    token_count: usize,
}

/// 本機倒排索引。
#[derive(Debug, Default)]
pub struct SearchIndex {
    /// token → 出現的文件集合
    postings: HashMap<String, BTreeSet<DocId>>,
    /// 文件 → 內容
    docs: BTreeMap<DocId, Entry>,
}

impl SearchIndex {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn len(&self) -> usize {
        self.docs.len()
    }

    pub fn is_empty(&self) -> bool {
        self.docs.is_empty()
    }

    /// 新增或取代一份文件。重複 `insert` 同一個 `DocId` 等於更新，
    /// 舊 token 會被正確移除 —— 這是增量更新不洩漏的關鍵。
    pub fn insert(&mut self, doc: DocId, source: Source, text: &str) {
        self.remove(&doc);

        let tokens = tokenize(text);
        for t in &tokens {
            self.postings
                .entry(t.clone())
                .or_default()
                .insert(doc.clone());
        }
        self.docs.insert(
            doc,
            Entry {
                source,
                text: text.to_string(),
                token_count: tokens.len(),
            },
        );
    }

    pub fn remove(&mut self, doc: &DocId) {
        let Some(old) = self.docs.remove(doc) else {
            return;
        };
        for t in tokenize(&old.text) {
            if let Some(set) = self.postings.get_mut(&t) {
                set.remove(doc);
                // 空的 posting list 要清掉，否則長期使用會累積成記憶體洩漏。
                if set.is_empty() {
                    self.postings.remove(&t);
                }
            }
        }
    }

    /// 移除整頁的所有區塊（刪除頁面時使用）。
    pub fn remove_page(&mut self, notebook: &str, page: &str) {
        let victims: Vec<DocId> = self
            .docs
            .keys()
            .filter(|d| d.notebook == notebook && d.page == page)
            .cloned()
            .collect();
        for d in victims {
            self.remove(&d);
        }
    }

    /// 查詢。所有 token 都必須命中（AND 語意）。
    ///
    /// AND 而非 OR：使用者打「線性代數」時要的是同時含這些字的筆記，
    /// OR 會把只含「數」的筆記也撈進來，噪音太大。
    pub fn search(&self, query: &str, limit: usize) -> Vec<Hit> {
        let tokens = tokenize(query);
        if tokens.is_empty() {
            return Vec::new();
        }

        // 從最稀有的 token 開始交集，候選集縮得最快。
        let mut lists: Vec<&BTreeSet<DocId>> = Vec::with_capacity(tokens.len());
        for t in &tokens {
            match self.postings.get(t) {
                Some(set) => lists.push(set),
                None => return Vec::new(), // 任一 token 無人使用 ⇒ AND 必定落空
            }
        }
        lists.sort_by_key(|s| s.len());

        let mut candidates: BTreeSet<DocId> = lists[0].clone();
        for list in &lists[1..] {
            candidates.retain(|d| list.contains(d));
            if candidates.is_empty() {
                return Vec::new();
            }
        }

        let mut hits: Vec<Hit> = candidates
            .into_iter()
            .filter_map(|doc| {
                let entry = self.docs.get(&doc)?;
                Some(Hit {
                    score: self.score(entry, &tokens),
                    snippet: snippet_around(&entry.text, query),
                    source: entry.source,
                    doc,
                })
            })
            .collect();

        hits.sort_by(|a, b| b.score.total_cmp(&a.score).then_with(|| a.doc.cmp(&b.doc)));
        hits.truncate(limit);
        hits
    }

    /// 詞頻 ÷ 文件長度，再乘上來源可信度權重。
    ///
    /// 除以長度是必要的：否則一份很長的轉錄稿會因為湊巧多提到幾次而永遠排第一。
    fn score(&self, entry: &Entry, tokens: &[String]) -> f32 {
        let doc_tokens = tokenize(&entry.text);
        let matches = doc_tokens.iter().filter(|t| tokens.contains(t)).count();
        let norm = (entry.token_count.max(1) as f32).sqrt();
        (matches as f32 / norm) * entry.source.rank_weight()
    }
}

/// 取命中位置附近的片段。找不到原字串時退回開頭。
fn snippet_around(text: &str, query: &str) -> String {
    const RADIUS: usize = 24;
    let chars: Vec<char> = text.chars().collect();

    let center = text
        .find(query)
        .map(|byte_idx| text[..byte_idx].chars().count())
        .unwrap_or(0);

    let start = center.saturating_sub(RADIUS);
    let end = (center + RADIUS).min(chars.len());
    let mut s: String = chars[start..end].iter().collect();
    if start > 0 {
        s.insert(0, '…');
    }
    if end < chars.len() {
        s.push('…');
    }
    s
}

#[cfg(test)]
mod tests {
    use super::*;

    fn doc(page: &str, block: &str) -> DocId {
        DocId::new("nb1", page, block)
    }

    fn populated() -> SearchIndex {
        let mut idx = SearchIndex::new();
        idx.insert(
            doc("p1", "b1"),
            Source::Text,
            "線性代數的特徵值與特徵向量是這章的重點",
        );
        idx.insert(
            doc("p2", "b1"),
            Source::Transcript,
            "今天我們要講的是線性代數裡面的矩陣運算",
        );
        idx.insert(doc("p3", "b1"), Source::Handwriting, "微積分的極限定義");
        idx.insert(doc("p4", "b1"), Source::Text, "用 Rust 實作倒排索引");
        idx
    }

    #[test]
    fn finds_chinese_substring_without_a_dictionary() {
        let hits = populated().search("代數", 10);
        assert_eq!(hits.len(), 2);
        assert!(
            hits.iter()
                .all(|h| h.doc.page == "p1" || h.doc.page == "p2")
        );
    }

    #[test]
    fn and_semantics_excludes_partial_matches() {
        // 「微積分」只在 p3；「線性」不在 p3 ⇒ 交集為空
        assert!(populated().search("線性 微積分", 10).is_empty());
    }

    #[test]
    fn unknown_term_returns_nothing() {
        assert!(populated().search("量子力學", 10).is_empty());
    }

    #[test]
    fn searches_across_all_sources() {
        let idx = populated();
        assert_eq!(idx.search("矩陣", 10)[0].source, Source::Transcript);
        assert_eq!(idx.search("極限", 10)[0].source, Source::Handwriting);
    }

    #[test]
    fn typed_text_outranks_handwriting_for_equal_relevance() {
        let mut idx = SearchIndex::new();
        idx.insert(doc("p1", "b1"), Source::Handwriting, "特徵值");
        idx.insert(doc("p2", "b1"), Source::Text, "特徵值");

        let hits = idx.search("特徵值", 10);
        assert_eq!(hits[0].source, Source::Text, "打字文字應優先於手寫辨識");
    }

    #[test]
    fn long_documents_do_not_dominate_by_length() {
        let mut idx = SearchIndex::new();
        idx.insert(doc("short", "b"), Source::Text, "特徵值");
        idx.insert(
            doc("long", "b"),
            Source::Text,
            &format!("{}特徵值{}", "無關內容".repeat(50), "更多雜訊".repeat(50)),
        );
        assert_eq!(
            idx.search("特徵值", 10)[0].doc.page,
            "short",
            "短而精準的文件應排前面"
        );
    }

    #[test]
    fn reinsert_replaces_instead_of_duplicating() {
        let mut idx = SearchIndex::new();
        let d = doc("p1", "b1");
        idx.insert(d.clone(), Source::Text, "舊的內容講的是拓樸");
        idx.insert(d.clone(), Source::Text, "新的內容講的是代數");

        assert_eq!(idx.len(), 1);
        assert!(idx.search("拓樸", 10).is_empty(), "舊 token 必須被清除");
        assert_eq!(idx.search("代數", 10).len(), 1);
    }

    #[test]
    fn remove_clears_empty_posting_lists() {
        let mut idx = SearchIndex::new();
        let d = doc("p1", "b1");
        idx.insert(d.clone(), Source::Text, "唯一內容");
        idx.remove(&d);

        assert!(idx.is_empty());
        assert!(
            idx.postings.is_empty(),
            "空 posting list 未清除會造成記憶體洩漏"
        );
    }

    #[test]
    fn remove_page_clears_all_its_blocks() {
        let mut idx = SearchIndex::new();
        idx.insert(doc("p1", "b1"), Source::Text, "第一塊");
        idx.insert(doc("p1", "b2"), Source::Text, "第二塊");
        idx.insert(doc("p2", "b1"), Source::Text, "別頁");

        idx.remove_page("nb1", "p1");
        assert_eq!(idx.len(), 1);
        assert!(idx.search("第一塊", 10).is_empty());
        assert_eq!(idx.search("別頁", 10).len(), 1);
    }

    #[test]
    fn removing_absent_doc_is_a_noop() {
        let mut idx = populated();
        let before = idx.len();
        idx.remove(&doc("nonexistent", "b"));
        assert_eq!(idx.len(), before);
    }

    #[test]
    fn mixed_language_query_works() {
        let mut idx = SearchIndex::new();
        idx.insert(doc("p1", "b1"), Source::Text, "我們用 Rust 寫核心邏輯");
        assert_eq!(idx.search("rust", 10).len(), 1, "英文查詢應忽略大小寫");
        assert_eq!(idx.search("核心", 10).len(), 1);
    }

    #[test]
    fn snippet_shows_context_around_the_hit() {
        let mut idx = SearchIndex::new();
        idx.insert(
            doc("p1", "b1"),
            Source::Transcript,
            &format!(
                "{}關鍵字在這裡{}",
                "前面很多字".repeat(10),
                "後面也很多".repeat(10)
            ),
        );
        let s = &idx.search("關鍵字", 10)[0].snippet;
        assert!(s.contains("關鍵字"), "片段必須包含命中內容：{s}");
        assert!(s.starts_with('…') && s.ends_with('…'), "兩端應有省略標記");
    }

    #[test]
    fn limit_is_respected() {
        let mut idx = SearchIndex::new();
        for i in 0..20 {
            idx.insert(doc(&format!("p{i}"), "b"), Source::Text, "重複的內容");
        }
        assert_eq!(idx.search("重複", 5).len(), 5);
    }

    #[test]
    fn empty_query_returns_nothing() {
        assert!(populated().search("", 10).is_empty());
        assert!(populated().search("！？。", 10).is_empty());
    }
}
