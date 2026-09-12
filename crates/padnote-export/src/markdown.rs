//! 匯出為 Markdown（功能 H2）。
//!
//! 手寫 App 幾乎都沒有這個能力。Markdown 讓筆記能進 Obsidian、進 git、
//! 進任何文字工具 —— 這正是 Obsidian 使用者最看重的東西。

use padnote_doc::{BlockKind, LayoutMode, Notebook, PageTemplate, TextStyle};

#[derive(Clone, Debug)]
pub struct MarkdownOptions {
    /// 每頁之間插入 `---` 分隔線。連續捲動模式下通常不需要。
    pub page_separators: bool,
    /// 是否含轉錄逐字稿。
    pub include_transcripts: bool,
    /// 圖片連結的前綴目錄。
    pub asset_prefix: String,
    /// 頁面標題格式，`{n}` 會被頁碼取代。空字串表示不輸出頁標題。
    pub page_heading: String,
}

impl Default for MarkdownOptions {
    fn default() -> Self {
        Self {
            page_separators: true,
            include_transcripts: true,
            asset_prefix: "assets".into(),
            page_heading: String::new(),
        }
    }
}

/// 把筆記本轉成 Markdown。
///
/// 筆畫無法用 Markdown 表示，因此會被標註為 `> _[手寫內容 — 見 PDF 匯出]_`
/// 而非靜默省略 —— **讓使用者知道有東西沒帶過來，比假裝完整重要**。
pub fn to_markdown(
    notebook: &Notebook,
    ink_pages: &[padnote_doc::Uuid],
    opts: &MarkdownOptions,
) -> String {
    let mut out = String::new();

    if !notebook.title.is_empty() {
        out.push_str(&format!("# {}\n\n", notebook.title));
    }

    let separators = opts.page_separators && notebook.layout == LayoutMode::Paged;

    for (i, page) in notebook.pages().iter().enumerate() {
        if separators && i > 0 {
            out.push_str("\n---\n\n");
        }
        if !opts.page_heading.is_empty() {
            let heading = opts.page_heading.replace("{n}", &(i + 1).to_string());
            out.push_str(&format!("## {heading}\n\n"));
        }

        if let PageTemplate::Pdf { page_index, .. } = &page.template {
            out.push_str(&format!("> _[PDF 底稿 第 {} 頁]_\n\n", page_index + 1));
        }

        for block in page.blocks() {
            match &block.kind {
                BlockKind::Text { content, style } => {
                    out.push_str(&render_text(content, *style));
                }
                BlockKind::Image { blob, .. } => {
                    out.push_str(&format!("![]({}/{blob})\n\n", opts.asset_prefix));
                }
                BlockKind::Transcript { text, .. } if opts.include_transcripts => {
                    // 用引用區塊標示這是轉錄而非手打，避免日後分不清來源。
                    for line in text.lines() {
                        out.push_str(&format!("> {line}\n"));
                    }
                    out.push('\n');
                }
                BlockKind::Transcript { .. } => {}
                BlockKind::PdfAnnotation { text, page_index } => {
                    out.push_str(&format!("> **p.{}**：{text}\n\n", page_index + 1));
                }
            }
        }

        if ink_pages.contains(&page.id) {
            out.push_str("> _[手寫內容 — 見 PDF 匯出]_\n\n");
        }
    }

    // 收尾：壓掉多餘空行，但保留段落間的單一空行。
    while out.ends_with("\n\n\n") {
        out.pop();
    }
    out
}

fn render_text(content: &str, style: TextStyle) -> String {
    match style {
        TextStyle::Body => format!("{content}\n\n"),
        TextStyle::Heading1 => format!("# {content}\n\n"),
        TextStyle::Heading2 => format!("## {content}\n\n"),
        TextStyle::Heading3 => format!("### {content}\n\n"),
        TextStyle::Bullet => format!("- {content}\n"),
        TextStyle::Numbered => format!("1. {content}\n"),
        TextStyle::Todo { done } => {
            format!("- [{}] {content}\n", if done { "x" } else { " " })
        }
        TextStyle::Quote => format!("> {content}\n\n"),
        TextStyle::Code => format!("```\n{content}\n```\n\n"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use padnote_doc::{Block, NotebookTime, Page, Uuid};

    fn uid(b: u8) -> Uuid {
        Uuid::from_bytes([b; 16])
    }

    fn block(id: u8, kind: BlockKind) -> Block {
        Block {
            id: uid(id),
            kind,
            position: None,
            created_at: NotebookTime::ZERO,
        }
    }

    fn text(id: u8, content: &str, style: TextStyle) -> Block {
        block(
            id,
            BlockKind::Text {
                content: content.into(),
                style,
            },
        )
    }

    fn notebook_with(blocks: Vec<Block>) -> Notebook {
        let mut nb = Notebook::new(uid(0), "我的筆記");
        let mut p = Page::new(uid(1), PageTemplate::Blank);
        for b in blocks {
            p.add_block(b);
        }
        nb.add_page(p);
        nb
    }

    #[test]
    fn renders_title_and_body() {
        let md = to_markdown(
            &notebook_with(vec![text(1, "第一段內容", TextStyle::Body)]),
            &[],
            &MarkdownOptions::default(),
        );
        assert!(md.starts_with("# 我的筆記\n\n"));
        assert!(md.contains("第一段內容"));
    }

    #[test]
    fn renders_every_text_style() {
        let nb = notebook_with(vec![
            text(1, "大標", TextStyle::Heading1),
            text(2, "中標", TextStyle::Heading2),
            text(3, "項目", TextStyle::Bullet),
            text(4, "未完成", TextStyle::Todo { done: false }),
            text(5, "已完成", TextStyle::Todo { done: true }),
            text(6, "引用", TextStyle::Quote),
            text(7, "let x = 1;", TextStyle::Code),
        ]);
        let md = to_markdown(&nb, &[], &MarkdownOptions::default());

        assert!(md.contains("# 大標"));
        assert!(md.contains("## 中標"));
        assert!(md.contains("- 項目"));
        assert!(md.contains("- [ ] 未完成"));
        assert!(md.contains("- [x] 已完成"));
        assert!(md.contains("> 引用"));
        assert!(md.contains("```\nlet x = 1;\n```"));
    }

    #[test]
    fn transcripts_are_marked_as_quotes_not_plain_text() {
        // 不標示來源的話，日後分不清哪些是自己打的、哪些是機器聽的。
        let nb = notebook_with(vec![block(
            1,
            BlockKind::Transcript {
                session: uid(9),
                text: "今天要講的是線性代數".into(),
            },
        )]);
        let md = to_markdown(&nb, &[], &MarkdownOptions::default());
        assert!(md.contains("> 今天要講的是線性代數"));
    }

    #[test]
    fn transcripts_can_be_excluded() {
        let nb = notebook_with(vec![block(
            1,
            BlockKind::Transcript {
                session: uid(9),
                text: "逐字稿".into(),
            },
        )]);
        let opts = MarkdownOptions {
            include_transcripts: false,
            ..Default::default()
        };
        assert!(!to_markdown(&nb, &[], &opts).contains("逐字稿"));
    }

    #[test]
    fn multiline_transcript_quotes_every_line() {
        let nb = notebook_with(vec![block(
            1,
            BlockKind::Transcript {
                session: uid(9),
                text: "第一行\n第二行".into(),
            },
        )]);
        let md = to_markdown(&nb, &[], &MarkdownOptions::default());
        assert!(md.contains("> 第一行\n> 第二行"));
    }

    #[test]
    fn handwriting_is_flagged_not_silently_dropped() {
        // 靜默省略會讓使用者以為匯出是完整的 —— 那是最糟的失敗模式。
        let nb = notebook_with(vec![]);
        let md = to_markdown(&nb, &[uid(1)], &MarkdownOptions::default());
        assert!(md.contains("手寫內容"), "必須明示有內容沒帶過來");
    }

    #[test]
    fn pages_without_ink_are_not_flagged() {
        let nb = notebook_with(vec![text(1, "只有打字", TextStyle::Body)]);
        assert!(!to_markdown(&nb, &[], &MarkdownOptions::default()).contains("手寫內容"));
    }

    #[test]
    fn images_link_through_asset_prefix() {
        let nb = notebook_with(vec![block(
            1,
            BlockKind::Image {
                blob: "abc123".into(),
                width: 10.0,
                height: 10.0,
            },
        )]);
        let opts = MarkdownOptions {
            asset_prefix: "media".into(),
            ..Default::default()
        };
        assert!(to_markdown(&nb, &[], &opts).contains("![](media/abc123)"));
    }

    #[test]
    fn page_separators_appear_between_pages_only() {
        let mut nb = Notebook::new(uid(0), "t");
        for i in 1..=3 {
            let mut p = Page::new(uid(i), PageTemplate::Blank);
            p.add_block(text(i + 10, &format!("第 {i} 頁"), TextStyle::Body));
            nb.add_page(p);
        }
        let md = to_markdown(&nb, &[], &MarkdownOptions::default());
        assert_eq!(md.matches("\n---\n").count(), 2, "3 頁應有 2 條分隔線");
    }

    #[test]
    fn continuous_layout_suppresses_separators() {
        // 連續捲動模式下本來就沒有頁的概念，硬加分隔線反而破壞閱讀。
        let mut nb = Notebook::new(uid(0), "t");
        nb.layout = LayoutMode::Continuous;
        for i in 1..=2 {
            let mut p = Page::new(uid(i), PageTemplate::Blank);
            p.add_block(text(i + 10, "內容", TextStyle::Body));
            nb.add_page(p);
        }
        assert!(!to_markdown(&nb, &[], &MarkdownOptions::default()).contains("\n---\n"));
    }

    #[test]
    fn page_headings_are_numbered_when_requested() {
        let mut nb = Notebook::new(uid(0), "t");
        nb.add_page(Page::new(uid(1), PageTemplate::Blank));
        nb.add_page(Page::new(uid(2), PageTemplate::Blank));

        let opts = MarkdownOptions {
            page_heading: "第 {n} 頁".into(),
            ..Default::default()
        };
        let md = to_markdown(&nb, &[], &opts);
        assert!(md.contains("## 第 1 頁"));
        assert!(md.contains("## 第 2 頁"));
    }

    #[test]
    fn pdf_backed_pages_note_their_source() {
        let mut nb = Notebook::new(uid(0), "t");
        nb.add_page(Page::new(
            uid(1),
            PageTemplate::Pdf {
                blob: "b".into(),
                page_index: 4,
            },
        ));
        assert!(to_markdown(&nb, &[], &MarkdownOptions::default()).contains("第 5 頁"));
    }

    #[test]
    fn empty_notebook_yields_just_the_title() {
        let nb = Notebook::new(uid(0), "空筆記");
        assert_eq!(
            to_markdown(&nb, &[], &MarkdownOptions::default()),
            "# 空筆記\n\n"
        );
    }
}
