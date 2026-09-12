//! Markdown 與 JSON 匯入（工作項 S-39，ADR-0008 第二層）。
//!
//! ## 為什麼這一層存在
//! ADR-0008 把互通策略定為三層。Markdown 是第二層的核心 ——
//! Obsidian 完全相容，Notion 與 OneNote 也都支援 MD 匯入匯出。
//!
//! ## 中介表示
//! 解析器不直接產生 `DocOp`，而是先產生 [`ImportedDocument`]。
//! 這讓解析邏輯**與文件模型解耦**：可以完整測試解析結果，
//! 也讓不同來源（MD／JSON／未來的 docx）共用同一條落地路徑。

use padnote_doc::TextStyle;

/// 解析後的一個區塊。
#[derive(Clone, Debug, PartialEq)]
pub enum ImportedBlock {
    Text {
        content: String,
        style: TextStyle,
    },
    /// 圖片。`source` 可能是相對路徑或 URL，由呼叫端決定如何取得。
    Image {
        source: String,
        alt: String,
    },
    /// 分頁符（Markdown 的 `---`）。
    PageBreak,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct ImportedDocument {
    pub title: String,
    pub blocks: Vec<ImportedBlock>,
}

impl ImportedDocument {
    /// 依分頁符切成多頁。
    pub fn pages(&self) -> Vec<Vec<&ImportedBlock>> {
        let mut pages = vec![Vec::new()];
        for b in &self.blocks {
            if *b == ImportedBlock::PageBreak {
                pages.push(Vec::new());
            } else {
                pages.last_mut().expect("至少有一頁").push(b);
            }
        }
        pages
    }

    pub fn block_count(&self) -> usize {
        self.blocks
            .iter()
            .filter(|b| **b != ImportedBlock::PageBreak)
            .count()
    }
}

/// 解析 Markdown。
///
/// 刻意**不引入完整的 Markdown 函式庫**：我們只需要能還原自己匯出的內容，
/// 加上常見的 CommonMark 子集。引入大型解析器會帶來大量我們不支援的
/// 語法（表格、腳註、HTML 內嵌），反而讓匯入結果難以預期。
pub fn from_markdown(text: &str) -> ImportedDocument {
    let mut doc = ImportedDocument::default();
    let mut paragraph = String::new();
    let mut in_code = false;
    let mut code = String::new();

    let flush_paragraph = |p: &mut String, blocks: &mut Vec<ImportedBlock>| {
        let trimmed = p.trim();
        if !trimmed.is_empty() {
            blocks.push(ImportedBlock::Text {
                content: trimmed.to_string(),
                style: TextStyle::Body,
            });
        }
        p.clear();
    };

    for raw in text.lines() {
        let line = raw.trim_end();

        // 程式碼區塊優先 —— 裡面的 `#` 不是標題。
        if line.trim_start().starts_with("```") {
            if in_code {
                doc.blocks.push(ImportedBlock::Text {
                    content: code.trim_end().to_string(),
                    style: TextStyle::Code,
                });
                code.clear();
            } else {
                flush_paragraph(&mut paragraph, &mut doc.blocks);
            }
            in_code = !in_code;
            continue;
        }
        if in_code {
            code.push_str(line);
            code.push('\n');
            continue;
        }

        let trimmed = line.trim();

        if trimmed.is_empty() {
            flush_paragraph(&mut paragraph, &mut doc.blocks);
            continue;
        }

        // 分頁符
        if trimmed == "---" || trimmed == "***" {
            flush_paragraph(&mut paragraph, &mut doc.blocks);
            doc.blocks.push(ImportedBlock::PageBreak);
            continue;
        }

        // 圖片（整行只有圖片時才視為區塊）
        if let Some(img) = parse_image(trimmed) {
            flush_paragraph(&mut paragraph, &mut doc.blocks);
            doc.blocks.push(img);
            continue;
        }

        if let Some((style, content)) = parse_prefix(trimmed) {
            flush_paragraph(&mut paragraph, &mut doc.blocks);

            // 文件的第一個 H1 當作標題，而不是內容 ——
            // 我們的匯出就是這樣寫的。
            if style == TextStyle::Heading1 && doc.title.is_empty() && doc.blocks.is_empty() {
                doc.title = content.to_string();
            } else {
                doc.blocks.push(ImportedBlock::Text {
                    content: content.to_string(),
                    style,
                });
            }
            continue;
        }

        // 一般段落：同段的多行接起來
        if !paragraph.is_empty() {
            paragraph.push('\n');
        }
        paragraph.push_str(trimmed);
    }

    // 未閉合的程式碼區塊仍要保留內容，不能吞掉。
    if in_code && !code.trim().is_empty() {
        doc.blocks.push(ImportedBlock::Text {
            content: code.trim_end().to_string(),
            style: TextStyle::Code,
        });
    }
    flush_paragraph(&mut paragraph, &mut doc.blocks);
    doc
}

/// 解析行首標記。回傳 `(樣式, 內容)`。
fn parse_prefix(line: &str) -> Option<(TextStyle, &str)> {
    // 待辦要在一般清單之前判斷，否則 `- [ ] x` 會被當成項目符號。
    for (prefix, style) in [
        ("- [x] ", TextStyle::Todo { done: true }),
        ("- [X] ", TextStyle::Todo { done: true }),
        ("- [ ] ", TextStyle::Todo { done: false }),
        ("### ", TextStyle::Heading3),
        ("## ", TextStyle::Heading2),
        ("# ", TextStyle::Heading1),
        ("> ", TextStyle::Quote),
        ("- ", TextStyle::Bullet),
        ("* ", TextStyle::Bullet),
    ] {
        if let Some(rest) = line.strip_prefix(prefix) {
            return Some((style, rest.trim()));
        }
    }

    // 有序清單：`1. `、`12. `
    let digits: String = line.chars().take_while(char::is_ascii_digit).collect();
    if !digits.is_empty()
        && let Some(rest) = line[digits.len()..].strip_prefix(". ")
    {
        return Some((TextStyle::Numbered, rest.trim()));
    }
    None
}

fn parse_image(line: &str) -> Option<ImportedBlock> {
    let rest = line.strip_prefix("![")?;
    let (alt, rest) = rest.split_once("](")?;
    let source = rest.strip_suffix(')')?;
    Some(ImportedBlock::Image {
        source: source.to_string(),
        alt: alt.to_string(),
    })
}

/// JSON 匯入。
///
/// Schema 刻意與 [`ImportedDocument`] 同構，讓其他工具能直接產生我們吃得下的
/// 檔案：
///
/// ```json
/// {
///   "title": "筆記標題",
///   "blocks": [
///     { "type": "text", "style": "heading2", "content": "重點" },
///     { "type": "image", "source": "a.png", "alt": "圖" },
///     { "type": "page_break" }
///   ]
/// }
/// ```
pub fn from_json(text: &str) -> Result<ImportedDocument, String> {
    let value: serde_json::Value = serde_json::from_str(text).map_err(|e| e.to_string())?;

    let title = value
        .get("title")
        .and_then(|v| v.as_str())
        .unwrap_or_default()
        .to_string();

    let mut blocks = Vec::new();
    for (i, b) in value
        .get("blocks")
        .and_then(|v| v.as_array())
        .map(Vec::as_slice)
        .unwrap_or_default()
        .iter()
        .enumerate()
    {
        let kind = b.get("type").and_then(|v| v.as_str()).unwrap_or("text");
        match kind {
            "page_break" => blocks.push(ImportedBlock::PageBreak),
            "image" => blocks.push(ImportedBlock::Image {
                source: b
                    .get("source")
                    .and_then(|v| v.as_str())
                    .ok_or_else(|| format!("第 {i} 個區塊缺少 source"))?
                    .to_string(),
                alt: b
                    .get("alt")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_string(),
            }),
            "text" => blocks.push(ImportedBlock::Text {
                content: b
                    .get("content")
                    .and_then(|v| v.as_str())
                    .ok_or_else(|| format!("第 {i} 個區塊缺少 content"))?
                    .to_string(),
                style: parse_style(b.get("style").and_then(|v| v.as_str()).unwrap_or("body")),
            }),
            other => return Err(format!("第 {i} 個區塊的類型未知：{other}")),
        }
    }
    Ok(ImportedDocument { title, blocks })
}

fn parse_style(name: &str) -> TextStyle {
    match name {
        "heading1" => TextStyle::Heading1,
        "heading2" => TextStyle::Heading2,
        "heading3" => TextStyle::Heading3,
        "bullet" => TextStyle::Bullet,
        "numbered" => TextStyle::Numbered,
        "quote" => TextStyle::Quote,
        "code" => TextStyle::Code,
        "todo" => TextStyle::Todo { done: false },
        "todo_done" => TextStyle::Todo { done: true },
        // 未知樣式退回內文而非失敗 —— 匯入應該盡力而為。
        _ => TextStyle::Body,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn text(content: &str, style: TextStyle) -> ImportedBlock {
        ImportedBlock::Text {
            content: content.into(),
            style,
        }
    }

    #[test]
    fn first_h1_becomes_the_title() {
        // 我們的匯出就是把標題寫成第一個 H1。
        let d = from_markdown("# 線性代數\n\n內文");
        assert_eq!(d.title, "線性代數");
        assert_eq!(d.blocks, vec![text("內文", TextStyle::Body)]);
    }

    #[test]
    fn later_h1_stays_as_content() {
        let d = from_markdown("# 標題\n\n內文\n\n# 第二個大標");
        assert_eq!(d.title, "標題");
        assert!(d.blocks.contains(&text("第二個大標", TextStyle::Heading1)));
    }

    #[test]
    fn parses_every_style_we_export() {
        // 這條把匯入與匯出綁在一起：匯出支援的樣式，匯入都要認得。
        let d =
            from_markdown("## 中標\n### 小標\n- 項目\n1. 編號\n> 引用\n- [ ] 未完成\n- [x] 已完成");
        assert_eq!(
            d.blocks,
            vec![
                text("中標", TextStyle::Heading2),
                text("小標", TextStyle::Heading3),
                text("項目", TextStyle::Bullet),
                text("編號", TextStyle::Numbered),
                text("引用", TextStyle::Quote),
                text("未完成", TextStyle::Todo { done: false }),
                text("已完成", TextStyle::Todo { done: true }),
            ]
        );
    }

    #[test]
    fn todo_is_matched_before_bullet() {
        // `- [ ] x` 若先比對 `- ` 會變成項目符號「[ ] x」。
        let d = from_markdown("- [ ] 待辦");
        assert_eq!(
            d.blocks,
            vec![text("待辦", TextStyle::Todo { done: false })]
        );
    }

    #[test]
    fn code_block_contents_are_not_parsed_as_markdown() {
        // 程式碼裡的 `#` 不是標題。
        let d = from_markdown("```\n# not a heading\n- not a bullet\n```");
        assert_eq!(
            d.blocks,
            vec![text("# not a heading\n- not a bullet", TextStyle::Code)]
        );
    }

    #[test]
    fn unclosed_code_block_keeps_its_content() {
        // 吞掉內容是最糟的失敗方式。
        let d = from_markdown("```\nfn main() {}");
        assert_eq!(d.blocks, vec![text("fn main() {}", TextStyle::Code)]);
    }

    #[test]
    fn horizontal_rule_becomes_a_page_break() {
        let d = from_markdown("第一頁\n\n---\n\n第二頁");
        let pages = d.pages();
        assert_eq!(pages.len(), 2);
        assert_eq!(pages[0].len(), 1);
        assert_eq!(pages[1].len(), 1);
    }

    #[test]
    fn images_are_recognised() {
        let d = from_markdown("![圖說](assets/abc123)");
        assert_eq!(
            d.blocks,
            vec![ImportedBlock::Image {
                source: "assets/abc123".into(),
                alt: "圖說".into()
            }]
        );
    }

    #[test]
    fn consecutive_lines_join_into_one_paragraph() {
        let d = from_markdown("第一行\n第二行\n\n新段落");
        assert_eq!(
            d.blocks,
            vec![
                text("第一行\n第二行", TextStyle::Body),
                text("新段落", TextStyle::Body),
            ]
        );
    }

    #[test]
    fn empty_input_yields_an_empty_document() {
        let d = from_markdown("");
        assert!(d.title.is_empty());
        assert!(d.blocks.is_empty());
        assert_eq!(d.block_count(), 0);
    }

    #[test]
    fn whitespace_only_input_is_empty() {
        assert!(from_markdown("   \n\n  \t\n").blocks.is_empty());
    }

    // ---- JSON ----

    #[test]
    fn json_parses_all_block_types() {
        let d = from_json(
            r#"{"title":"筆記","blocks":[
                {"type":"text","style":"heading2","content":"重點"},
                {"type":"image","source":"a.png","alt":"圖"},
                {"type":"page_break"},
                {"type":"text","content":"內文"}
            ]}"#,
        )
        .unwrap();

        assert_eq!(d.title, "筆記");
        assert_eq!(d.blocks.len(), 4);
        assert_eq!(d.blocks[0], text("重點", TextStyle::Heading2));
        assert_eq!(d.blocks[2], ImportedBlock::PageBreak);
        assert_eq!(d.blocks[3], text("內文", TextStyle::Body), "style 可省略");
    }

    #[test]
    fn json_unknown_style_falls_back_to_body() {
        // 匯入應該盡力而為，不該為了一個未知樣式整份失敗。
        let d = from_json(r#"{"blocks":[{"type":"text","style":"未來的樣式","content":"x"}]}"#)
            .unwrap();
        assert_eq!(d.blocks[0], text("x", TextStyle::Body));
    }

    #[test]
    fn json_reports_which_block_is_malformed() {
        // 只說「解析失敗」對使用者沒用。
        let err = from_json(r#"{"blocks":[{"type":"text"},{"type":"text","content":"ok"}]}"#)
            .unwrap_err();
        assert!(err.contains("第 0 個區塊"), "{err}");

        let err = from_json(r#"{"blocks":[{"type":"未知"}]}"#).unwrap_err();
        assert!(err.contains("未知"), "{err}");
    }

    #[test]
    fn json_tolerates_missing_optional_fields() {
        let d = from_json("{}").unwrap();
        assert!(d.title.is_empty());
        assert!(d.blocks.is_empty());
    }

    #[test]
    fn json_rejects_invalid_syntax() {
        assert!(from_json("{ not json").is_err());
    }
}
