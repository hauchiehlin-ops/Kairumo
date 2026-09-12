//! **S-39：匯出 → 匯入的往返一致性**
//!
//! 這是匯入功能唯一有意義的驗收：**我們自己匯出的東西，自己要讀得回來**。
//! 做不到這件事，談與其他 App 互通就沒有意義。
//!
//! 對應 ADR-0008 的第二層（Markdown／JSON 雙向）。

use padnote_core::app::NotebookSession;
use padnote_core::doc::{BlockKind, TextStyle};
use padnote_core::export::{ImportedBlock, from_markdown};

fn tmp(name: &str) -> std::path::PathBuf {
    let d = std::env::temp_dir().join(format!("padnote-s39-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    d
}

fn session(name: &str) -> NotebookSession {
    NotebookSession::create(tmp(name), "", 1_757_635_200_000, 0xA1).unwrap()
}

/// 取出所有文字區塊的 (內容, 樣式)。
fn text_blocks(s: &NotebookSession) -> Vec<(String, TextStyle)> {
    s.notebook()
        .pages()
        .iter()
        .flat_map(|p| p.blocks())
        .filter_map(|b| match &b.kind {
            BlockKind::Text { content, style } => Some((content.clone(), *style)),
            _ => None,
        })
        .collect()
}

#[test]
fn every_exported_style_survives_the_round_trip() {
    let mut s = session("roundtrip");
    s.set_title("線性代數 第三週").unwrap();
    let page = s.first_page().unwrap();

    let expected = [
        ("重點整理", TextStyle::Heading2),
        ("特徵值", TextStyle::Heading3),
        ("定義與性質", TextStyle::Body),
        ("可對角化", TextStyle::Bullet),
        ("複習第三章", TextStyle::Todo { done: false }),
        ("已完成習題", TextStyle::Todo { done: true }),
        ("重要的話", TextStyle::Quote),
        ("let x = 1;", TextStyle::Code),
    ];
    for (content, style) in &expected {
        s.add_text_block(page, content, *style).unwrap();
    }

    let markdown = s.export_markdown().unwrap();

    let mut fresh = session("roundtrip-2");
    fresh.import_markdown(&markdown).unwrap();

    let got = text_blocks(&fresh);
    assert_eq!(
        got,
        expected
            .iter()
            .map(|(c, st)| (c.to_string(), *st))
            .collect::<Vec<_>>(),
        "匯出的每一種樣式都必須讀得回來"
    );
}

#[test]
fn title_survives_the_round_trip() {
    let mut s = session("title");
    s.set_title("我的筆記").unwrap();
    s.add_text_block(s.first_page().unwrap(), "內容", TextStyle::Body)
        .unwrap();

    let mut fresh = session("title-2");
    fresh
        .import_markdown(&s.export_markdown().unwrap())
        .unwrap();
    assert_eq!(fresh.notebook().title, "我的筆記");
}

#[test]
fn page_breaks_become_separate_pages() {
    let mut s = session("pages");
    for i in 1..=3 {
        let p = if i == 1 {
            s.first_page().unwrap()
        } else {
            s.add_page(padnote_core::doc::PageTemplate::Blank).unwrap()
        };
        s.add_text_block(p, &format!("第 {i} 頁"), TextStyle::Body)
            .unwrap();
    }

    let markdown = s.export_markdown().unwrap();
    assert_eq!(
        markdown.matches("\n---\n").count(),
        2,
        "3 頁應有 2 條分隔線"
    );

    let mut fresh = session("pages-2");
    fresh.import_markdown(&markdown).unwrap();
    // 匯入時每個分隔線開一頁
    assert_eq!(fresh.notebook().page_count(), 4, "1 初始頁 + 3 匯入頁");
}

#[test]
fn imported_content_is_searchable() {
    // 匯入不只要存進去，還要進索引 —— 否則使用者找不到剛匯入的東西。
    let mut s = session("search");
    s.import_markdown("# 標題\n\n## 特徵值與特徵向量\n\n這是內文")
        .unwrap();
    assert_eq!(s.search("特徵", 10).len(), 1);
}

#[test]
fn imported_content_survives_a_reopen() {
    let mut s = session("persist");
    s.import_markdown("# 標題\n\n- 項目一\n- 項目二").unwrap();
    let root = s.package().root().to_path_buf();
    drop(s);

    let reopened = NotebookSession::open(&root, 0xA1).unwrap();
    let blocks = text_blocks(&reopened);
    assert_eq!(blocks.len(), 2);
    assert_eq!(blocks[0].1, TextStyle::Bullet);
}

#[test]
fn import_adds_rather_than_replaces() {
    // 匯入是「加進來」不是「取代」—— 按錯不該弄丟既有筆記。
    let mut s = session("additive");
    s.add_text_block(s.first_page().unwrap(), "原有內容", TextStyle::Body)
        .unwrap();

    s.import_markdown("匯入的內容").unwrap();

    let contents: Vec<String> = text_blocks(&s).into_iter().map(|(c, _)| c).collect();
    assert!(
        contents.contains(&"原有內容".to_string()),
        "既有內容不得消失"
    );
    assert!(contents.contains(&"匯入的內容".to_string()));
}

#[test]
fn json_import_matches_markdown_import() {
    // 兩種來源應該產生相同的文件結構。
    let mut from_md = session("json-md");
    from_md.import_markdown("## 重點\n\n- 項目").unwrap();

    let mut from_js = session("json-js");
    from_js
        .import_json(
            r#"{"blocks":[
                {"type":"text","style":"heading2","content":"重點"},
                {"type":"text","style":"bullet","content":"項目"}
            ]}"#,
        )
        .unwrap();

    assert_eq!(text_blocks(&from_md), text_blocks(&from_js));
}

#[test]
fn malformed_json_is_rejected_with_a_useful_message() {
    let mut s = session("badjson");
    let err = s
        .import_json(r#"{"blocks":[{"type":"text"}]}"#)
        .unwrap_err();
    assert!(err.to_string().contains("第 0 個區塊"), "{err}");
}

#[test]
fn handwriting_marker_is_not_imported_as_content() {
    // 匯出時手寫會標註成 `> _[手寫內容 — 見 PDF 匯出]_`。
    // 匯入時那應該是引用區塊，而不是被誤認成使用者寫的字。
    let doc = from_markdown("> _[手寫內容 — 見 PDF 匯出]_");
    assert_eq!(doc.blocks.len(), 1);
    assert!(matches!(
        &doc.blocks[0],
        ImportedBlock::Text {
            style: TextStyle::Quote,
            ..
        }
    ));
}
