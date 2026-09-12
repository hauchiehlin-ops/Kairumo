//! 筆記本文件模型：頁面樹與內容區塊。
//!
//! 設計成 **CRDT 友善**：所有變更都是可交換的操作，順序無關。
//! 筆畫**不在這裡** —— 它們走 append-only 串流（ADR-0002），本模型只持有引用。

use crate::{NotebookTime, Uuid};
use std::collections::BTreeMap;

/// 頁面底紋（功能 E5）。
#[derive(Clone, PartialEq, Eq, Debug, Default)]
pub enum PageTemplate {
    #[default]
    Blank,
    Lined,
    Grid,
    Dotted,
    Cornell,
    MusicStaff,
    /// 匯入的 PDF 某一頁當底
    Pdf {
        blob: String,
        page_index: u32,
    },
    /// 使用者自訂圖片模板（E6）
    Custom {
        blob: String,
    },
}

/// 頁面排版模式。
///
/// 兩種都給 —— Notability 只有連續捲動、Goodnotes 只有分頁，
/// 但速記與手帳是兩種不同的心智模型（功能 A7）。
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub enum LayoutMode {
    #[default]
    Paged,
    Continuous,
}

/// 內容區塊。手寫與打字在同一份文件內共存（功能 B1）。
#[derive(Clone, Debug)]
pub enum BlockKind {
    /// 富文本（B2）
    Text { content: String, style: TextStyle },
    /// 圖片／掃描（E4），指向內容定址 blob
    Image {
        blob: String,
        width: f32,
        height: f32,
    },
    /// 轉錄逐字稿（C2），與時間軸綁定
    Transcript { session: Uuid, text: String },
    /// PDF 標註層的錨點（E2）
    PdfAnnotation { page_index: u32, text: String },
    /// 嵌入的外部文件（ADR-0009 / 決策 D-10）。
    ///
    /// `interaction` 決定呈現方式：`preview` 渲染為圖像、
    /// `editable` 已被拆成原生區塊（此處僅保留原檔供「開啟原始檔」）、
    /// `linked` 只存連結。
    Embedded {
        /// 原始檔的內容定址雜湊。**原檔一律保留** ——
        /// 解析失真時使用者還能拿回原本的東西。
        blob: String,
        /// `docx` / `xlsx` / `pptx` / `pdf`
        format: String,
        /// `preview` / `editable` / `linked`
        interaction: String,
        /// 供搜尋與離線顯示的純文字快照。
        text: String,
    },
}

#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub enum TextStyle {
    #[default]
    Body,
    Heading1,
    Heading2,
    Heading3,
    Bullet,
    Numbered,
    Todo {
        done: bool,
    },
    Quote,
    Code,
}

#[derive(Clone, Debug)]
pub struct Block {
    pub id: Uuid,
    pub kind: BlockKind,
    /// 頁面座標。`None` 表示隨文流排版而非絕對定位。
    pub position: Option<(f32, f32)>,
    /// 建立時刻，落在統一時間軸上（B6 版本回溯的依據）。
    pub created_at: NotebookTime,
}

impl Block {
    /// 可被索引的純文字。沒有文字內容的區塊回傳 `None`。
    pub fn searchable_text(&self) -> Option<&str> {
        match &self.kind {
            BlockKind::Text { content, .. } => Some(content),
            BlockKind::Transcript { text, .. } => Some(text),
            BlockKind::PdfAnnotation { text, .. } => Some(text),
            BlockKind::Embedded { text, .. } => Some(text),
            BlockKind::Image { .. } => None,
        }
    }

    /// 引用到的 blob（供 GC 計算引用集合）。
    pub fn referenced_blob(&self) -> Option<&str> {
        match &self.kind {
            BlockKind::Image { blob, .. } | BlockKind::Embedded { blob, .. } => Some(blob),
            _ => None,
        }
    }
}

#[derive(Clone, Debug)]
pub struct Page {
    pub id: Uuid,
    pub template: PageTemplate,
    /// 頁面尺寸（點）。A4 直式約 595×842。
    pub size: (f32, f32),
    blocks: Vec<Block>,
}

impl Page {
    pub fn new(id: Uuid, template: PageTemplate) -> Self {
        Self {
            id,
            template,
            size: (595.0, 842.0),
            blocks: Vec::new(),
        }
    }

    pub fn blocks(&self) -> &[Block] {
        &self.blocks
    }

    pub fn add_block(&mut self, block: Block) {
        self.blocks.push(block);
    }

    pub fn remove_block(&mut self, id: Uuid) -> Option<Block> {
        let pos = self.blocks.iter().position(|b| b.id == id)?;
        Some(self.blocks.remove(pos))
    }

    pub fn block_mut(&mut self, id: Uuid) -> Option<&mut Block> {
        self.blocks.iter_mut().find(|b| b.id == id)
    }

    /// 移動區塊到新位置（重新排序）。超出範圍時夾到尾端。
    pub fn move_block(&mut self, id: Uuid, to: usize) -> bool {
        let Some(from) = self.blocks.iter().position(|b| b.id == id) else {
            return false;
        };
        let block = self.blocks.remove(from);
        self.blocks.insert(to.min(self.blocks.len()), block);
        true
    }

    pub fn referenced_blobs(&self) -> Vec<&str> {
        self.blocks
            .iter()
            .filter_map(|b| b.referenced_blob())
            .collect()
    }
}

/// 一本筆記本。
#[derive(Clone, Debug)]
pub struct Notebook {
    pub id: Uuid,
    pub title: String,
    pub layout: LayoutMode,
    pages: Vec<Page>,
    /// 頁面 id → 索引，避免每次查找都掃全部。
    page_index: BTreeMap<Uuid, usize>,
}

impl Notebook {
    pub fn new(id: Uuid, title: impl Into<String>) -> Self {
        Self {
            id,
            title: title.into(),
            layout: LayoutMode::default(),
            pages: Vec::new(),
            page_index: BTreeMap::new(),
        }
    }

    pub fn pages(&self) -> &[Page] {
        &self.pages
    }

    pub fn page_count(&self) -> usize {
        self.pages.len()
    }

    pub fn page(&self, id: Uuid) -> Option<&Page> {
        self.page_index.get(&id).map(|&i| &self.pages[i])
    }

    pub fn page_mut(&mut self, id: Uuid) -> Option<&mut Page> {
        let i = *self.page_index.get(&id)?;
        self.pages.get_mut(i)
    }

    pub fn add_page(&mut self, page: Page) {
        self.page_index.insert(page.id, self.pages.len());
        self.pages.push(page);
    }

    /// 插入頁面到指定位置。
    pub fn insert_page(&mut self, at: usize, page: Page) {
        self.pages.insert(at.min(self.pages.len()), page);
        self.reindex();
    }

    pub fn remove_page(&mut self, id: Uuid) -> Option<Page> {
        let i = *self.page_index.get(&id)?;
        let page = self.pages.remove(i);
        self.reindex();
        Some(page)
    }

    pub fn move_page(&mut self, id: Uuid, to: usize) -> bool {
        let Some(&from) = self.page_index.get(&id) else {
            return false;
        };
        let page = self.pages.remove(from);
        self.pages.insert(to.min(self.pages.len()), page);
        self.reindex();
        true
    }

    fn reindex(&mut self) {
        self.page_index = self
            .pages
            .iter()
            .enumerate()
            .map(|(i, p)| (p.id, i))
            .collect();
    }

    /// 全筆記本引用到的 blob。**GC 前必須用這個算引用集合，漏一個就是資料遺失。**
    pub fn referenced_blobs(&self) -> Vec<String> {
        let mut out: Vec<String> = self
            .pages
            .iter()
            .flat_map(|p| {
                p.referenced_blobs()
                    .into_iter()
                    .map(str::to_string)
                    .chain(match &p.template {
                        PageTemplate::Pdf { blob, .. } | PageTemplate::Custom { blob } => {
                            Some(blob.clone())
                        }
                        _ => None,
                    })
            })
            .collect();
        out.sort();
        out.dedup();
        out
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn uid(b: u8) -> Uuid {
        Uuid::from_bytes([b; 16])
    }

    fn text_block(b: u8, content: &str) -> Block {
        Block {
            id: uid(b),
            kind: BlockKind::Text {
                content: content.into(),
                style: TextStyle::Body,
            },
            position: None,
            created_at: NotebookTime::from_micros(u64::from(b) * 1_000_000),
        }
    }

    fn image_block(b: u8, blob: &str) -> Block {
        Block {
            id: uid(b),
            kind: BlockKind::Image {
                blob: blob.into(),
                width: 100.0,
                height: 100.0,
            },
            position: Some((10.0, 20.0)),
            created_at: NotebookTime::ZERO,
        }
    }

    #[test]
    fn pages_are_addressable_after_insertion() {
        let mut nb = Notebook::new(uid(0), "測試");
        nb.add_page(Page::new(uid(1), PageTemplate::Lined));
        nb.add_page(Page::new(uid(2), PageTemplate::Grid));

        assert_eq!(nb.page_count(), 2);
        assert_eq!(nb.page(uid(2)).unwrap().template, PageTemplate::Grid);
        assert!(nb.page(uid(99)).is_none());
    }

    #[test]
    fn removing_a_page_keeps_the_rest_addressable() {
        // 索引沒重建的話，刪除中間頁會讓後面的頁面全部錯位。
        let mut nb = Notebook::new(uid(0), "t");
        for i in 1..=3 {
            nb.add_page(Page::new(uid(i), PageTemplate::Blank));
        }
        nb.remove_page(uid(1));

        assert_eq!(nb.page_count(), 2);
        assert_eq!(nb.page(uid(2)).unwrap().id, uid(2));
        assert_eq!(nb.page(uid(3)).unwrap().id, uid(3));
        assert!(nb.page(uid(1)).is_none());
    }

    #[test]
    fn move_page_reorders_and_keeps_index_correct() {
        let mut nb = Notebook::new(uid(0), "t");
        for i in 1..=3 {
            nb.add_page(Page::new(uid(i), PageTemplate::Blank));
        }
        assert!(nb.move_page(uid(3), 0));

        assert_eq!(
            nb.pages().iter().map(|p| p.id).collect::<Vec<_>>(),
            vec![uid(3), uid(1), uid(2)]
        );
        assert_eq!(nb.page(uid(1)).unwrap().id, uid(1));
    }

    #[test]
    fn move_page_beyond_end_clamps() {
        let mut nb = Notebook::new(uid(0), "t");
        nb.add_page(Page::new(uid(1), PageTemplate::Blank));
        nb.add_page(Page::new(uid(2), PageTemplate::Blank));
        assert!(nb.move_page(uid(1), 999));
        assert_eq!(nb.pages().last().unwrap().id, uid(1));
    }

    #[test]
    fn insert_page_places_at_position() {
        let mut nb = Notebook::new(uid(0), "t");
        nb.add_page(Page::new(uid(1), PageTemplate::Blank));
        nb.add_page(Page::new(uid(3), PageTemplate::Blank));
        nb.insert_page(1, Page::new(uid(2), PageTemplate::Blank));

        assert_eq!(
            nb.pages().iter().map(|p| p.id).collect::<Vec<_>>(),
            vec![uid(1), uid(2), uid(3)]
        );
    }

    #[test]
    fn blocks_can_be_added_reordered_and_removed() {
        let mut page = Page::new(uid(1), PageTemplate::Blank);
        page.add_block(text_block(10, "第一"));
        page.add_block(text_block(11, "第二"));
        page.add_block(text_block(12, "第三"));

        assert!(page.move_block(uid(12), 0));
        assert_eq!(page.blocks()[0].id, uid(12));

        assert!(page.remove_block(uid(11)).is_some());
        assert_eq!(page.blocks().len(), 2);
        assert!(page.remove_block(uid(99)).is_none());
    }

    #[test]
    fn searchable_text_covers_text_transcript_and_annotations() {
        assert_eq!(
            text_block(1, "打字內容").searchable_text(),
            Some("打字內容")
        );

        let transcript = Block {
            id: uid(2),
            kind: BlockKind::Transcript {
                session: uid(9),
                text: "轉錄內容".into(),
            },
            position: None,
            created_at: NotebookTime::ZERO,
        };
        assert_eq!(transcript.searchable_text(), Some("轉錄內容"));

        // 圖片沒有文字 —— OCR 結果是另外一筆記錄，不混在這裡。
        assert_eq!(image_block(3, "blob1").searchable_text(), None);
    }

    #[test]
    fn referenced_blobs_include_templates_and_images() {
        // GC 漏掉任何一個引用就是資料遺失，模板底圖最容易被忘記。
        let mut nb = Notebook::new(uid(0), "t");

        let mut p1 = Page::new(
            uid(1),
            PageTemplate::Pdf {
                blob: "pdf-blob".into(),
                page_index: 0,
            },
        );
        p1.add_block(image_block(10, "image-blob"));
        nb.add_page(p1);

        let p2 = Page::new(
            uid(2),
            PageTemplate::Custom {
                blob: "template-blob".into(),
            },
        );
        nb.add_page(p2);

        assert_eq!(
            nb.referenced_blobs(),
            vec!["image-blob", "pdf-blob", "template-blob"]
        );
    }

    #[test]
    fn duplicate_blob_references_are_deduplicated() {
        let mut nb = Notebook::new(uid(0), "t");
        let mut p = Page::new(uid(1), PageTemplate::Blank);
        p.add_block(image_block(10, "same"));
        p.add_block(image_block(11, "same"));
        nb.add_page(p);
        assert_eq!(nb.referenced_blobs(), vec!["same"]);
    }

    #[test]
    fn both_layout_modes_are_representable() {
        // A7：速記（連續）與手帳（分頁）是兩種心智模型，兩種都要支援。
        let mut nb = Notebook::new(uid(0), "t");
        assert_eq!(nb.layout, LayoutMode::Paged);
        nb.layout = LayoutMode::Continuous;
        assert_eq!(nb.layout, LayoutMode::Continuous);
    }
}
