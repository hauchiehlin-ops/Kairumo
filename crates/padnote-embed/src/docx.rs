//! `.docx` 匯入（可編輯，ADR-0009）。
//!
//! 支援段落、標題、清單、粗斜體。**不支援**分欄、浮動圖文、追蹤修訂、
//! 頁首頁尾、註腳 —— 見 [`crate::Limitations`]。
//!
//! 解析結果直接映射成 `ImportedDocument`，與 Markdown／JSON 匯入共用同一條
//! 落地路徑（S-39 建立的中介表示）。

use crate::EmbedError;
use padnote_doc::TextStyle;
use padnote_export::{ImportedBlock, ImportedDocument};
use std::path::Path;

/// 從 `.docx` 解析出可編輯的文件。
pub fn import_docx(path: impl AsRef<Path>) -> Result<ImportedDocument, EmbedError> {
    let path = path.as_ref();
    let bytes = std::fs::read(path).map_err(|e| match e.kind() {
        std::io::ErrorKind::NotFound => EmbedError::NotFound(path.display().to_string()),
        _ => EmbedError::Malformed(e.to_string()),
    })?;
    import_docx_bytes(&bytes)
}

pub fn import_docx_bytes(bytes: &[u8]) -> Result<ImportedDocument, EmbedError> {
    let doc = docx_rs::read_docx(bytes).map_err(|e| EmbedError::Malformed(e.to_string()))?;

    let mut out = ImportedDocument::default();
    for child in &doc.document.children {
        let docx_rs::DocumentChild::Paragraph(p) = child else {
            // 表格等其他結構本版不處理 —— 明示於 Limitations。
            continue;
        };
        let text = paragraph_text(p);
        if text.trim().is_empty() {
            continue;
        }
        let style = paragraph_style(p);

        // 第一個 Heading1 當標題，與 Markdown 匯入的行為一致。
        if style == TextStyle::Heading1 && out.title.is_empty() && out.blocks.is_empty() {
            out.title = text;
        } else {
            out.blocks.push(ImportedBlock::Text {
                content: text,
                style,
            });
        }
    }
    Ok(out)
}

/// 取出段落的純文字。
///
/// 一個段落可能被切成多個 run（粗體、斜體各自成 run），必須全部接起來 ——
/// 只讀第一個 run 會讓句子殘缺，這是最容易犯的錯。
fn paragraph_text(p: &docx_rs::Paragraph) -> String {
    let mut s = String::new();
    for child in &p.children {
        if let docx_rs::ParagraphChild::Run(run) = child {
            for rc in &run.children {
                if let docx_rs::RunChild::Text(t) = rc {
                    s.push_str(&t.text);
                }
            }
        }
    }
    s.trim().to_string()
}

fn paragraph_style(p: &docx_rs::Paragraph) -> TextStyle {
    // 清單優先於樣式名稱：帶編號的段落即使套了標題樣式，仍是清單項目。
    if p.property.numbering_property.is_some() {
        return TextStyle::Bullet;
    }
    match p.property.style.as_ref().map(|s| s.val.as_str()) {
        Some("Heading1" | "heading 1" | "Title") => TextStyle::Heading1,
        Some("Heading2" | "heading 2") => TextStyle::Heading2,
        Some("Heading3" | "heading 3") => TextStyle::Heading3,
        Some("Quote" | "IntenseQuote") => TextStyle::Quote,
        Some("ListParagraph") => TextStyle::Bullet,
        _ => TextStyle::Body,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample() -> ImportedDocument {
        let p = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("fixtures/sample.docx");
        import_docx(p).expect("應能解析測試檔")
    }

    #[test]
    fn reads_the_title_from_heading1() {
        assert_eq!(sample().title, "線性代數 第三週");
    }

    #[test]
    fn preserves_paragraph_styles() {
        let d = sample();
        let styles: Vec<TextStyle> = d
            .blocks
            .iter()
            .map(|b| match b {
                ImportedBlock::Text { style, .. } => *style,
                _ => TextStyle::Body,
            })
            .collect();
        assert!(styles.contains(&TextStyle::Heading2), "應保留二階標題");
        assert!(styles.contains(&TextStyle::Bullet), "應辨識清單");
    }

    #[test]
    fn joins_multiple_runs_into_one_paragraph() {
        // 粗體會讓段落被切成多個 run。只讀第一個會讓句子殘缺 ——
        // 這是解析 docx 最容易犯的錯。
        let d = sample();
        let joined = d.blocks.iter().any(|b| {
            matches!(
                b,
                ImportedBlock::Text { content, .. }
                    if content.contains("設 A 為方陣") && content.contains("Av = λv")
            )
        });
        assert!(joined, "跨 run 的句子必須接起來：{:?}", d.blocks);
    }

    #[test]
    fn skips_empty_paragraphs() {
        assert!(sample().blocks.iter().all(
            |b| !matches!(b, ImportedBlock::Text { content, .. } if content.trim().is_empty())
        ));
    }

    #[test]
    fn missing_file_reports_clearly() {
        let err = import_docx("/definitely/not/here.docx").unwrap_err();
        assert!(matches!(err, EmbedError::NotFound(_)));
    }

    #[test]
    fn garbage_input_is_rejected_not_panicking() {
        assert!(matches!(
            import_docx_bytes(b"this is not a docx"),
            Err(EmbedError::Malformed(_))
        ));
    }

    #[test]
    fn numbered_paragraphs_beat_style_names() {
        // 帶編號的段落即使套了標題樣式，仍是清單項目。
        let d = sample();
        let bullets = d
            .blocks
            .iter()
            .filter(|b| {
                matches!(
                    b,
                    ImportedBlock::Text {
                        style: TextStyle::Bullet,
                        ..
                    }
                )
            })
            .count();
        assert_eq!(bullets, 2, "測試檔有兩個清單項目");
    }
}
