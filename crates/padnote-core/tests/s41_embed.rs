//! **S-41：Office 文件的嵌入與編輯**（ADR-0009 / 決策 D-10）
//!
//! 驗證兩件事：
//! 1. **可編輯格式真的可編輯** —— 解析成原生區塊，能像自己打的字一樣改
//! 2. **原始檔一律保留** —— 解析必然失真，使用者要能拿回原本的東西

use padnote_core::app::NotebookSession;
use padnote_core::doc::{BlockKind, TextStyle, Uuid};

fn tmp(name: &str) -> std::path::PathBuf {
    let d = std::env::temp_dir().join(format!("padnote-s41-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    d
}

fn session(name: &str) -> NotebookSession {
    NotebookSession::create(tmp(name), "測試", 1_757_635_200_000, 0xA1).unwrap()
}

fn fixture(name: &str) -> std::path::PathBuf {
    std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .join(format!("../padnote-embed/fixtures/{name}"))
}

fn blocks(s: &NotebookSession, page: Uuid) -> Vec<BlockKind> {
    s.notebook()
        .page(page)
        .unwrap()
        .blocks()
        .iter()
        .map(|b| b.kind.clone())
        .collect()
}

#[test]
fn docx_becomes_editable_native_blocks() {
    let mut s = session("docx");
    let page = s.first_page().unwrap();
    s.import_embedded(page, fixture("sample.docx")).unwrap();

    let texts: Vec<(String, TextStyle)> = blocks(&s, page)
        .into_iter()
        .filter_map(|k| match k {
            BlockKind::Text { content, style } => Some((content, style)),
            _ => None,
        })
        .collect();

    assert!(
        texts
            .iter()
            .any(|(c, st)| c == "線性代數 第三週" && *st == TextStyle::Heading1),
        "標題應成為原生區塊：{texts:?}"
    );
    assert!(
        texts
            .iter()
            .any(|(c, _)| c.contains("設 A 為方陣") && c.contains("Av = λv")),
        "跨 run 的段落應接起來"
    );
    assert!(
        texts.iter().any(|(_, st)| *st == TextStyle::Bullet),
        "清單應保留"
    );
}

#[test]
fn imported_docx_text_is_actually_editable() {
    // 「可編輯」不能只是宣稱 —— 要真的能改。
    let mut s = session("docx-edit");
    let page = s.first_page().unwrap();
    s.import_embedded(page, fixture("sample.docx")).unwrap();

    let block_id = s
        .notebook()
        .page(page)
        .unwrap()
        .blocks()
        .iter()
        .find(|b| matches!(&b.kind, BlockKind::Text { content, .. } if content.contains("特徵值")))
        .map(|b| b.id)
        .expect("應有該區塊");

    s.insert_text(block_id, 0, "【重點】").unwrap();
    assert!(
        s.block_text(block_id).unwrap().starts_with("【重點】"),
        "匯入的文字必須能編輯"
    );
}

#[test]
fn xlsx_becomes_an_editable_table_object() {
    // 需求 2：試算表要變成畫布上的表格物件，而不是一段唯讀文字。
    let mut s = session("xlsx");
    let page = s.first_page().unwrap();
    s.import_embedded(page, fixture("sample.xlsx")).unwrap();

    let titles: String = blocks(&s, page)
        .iter()
        .filter_map(|k| match k {
            BlockKind::Text { content, .. } => Some(content.clone()),
            _ => None,
        })
        .collect();
    assert!(titles.contains("採購清單"), "工作表名稱應成為標題");

    let table = blocks(&s, page)
        .into_iter()
        .find_map(|k| match k {
            BlockKind::Table {
                rows,
                cols,
                cells,
                header_row,
                ..
            } => Some((rows, cols, cells, header_row)),
            _ => None,
        })
        .expect("試算表應展開成表格物件");
    let (rows, cols, cells, header_row) = table;

    assert_eq!(
        cells.len() as u32,
        rows * cols,
        "儲存格數量必須等於 列 × 欄"
    );
    assert!(header_row, "第一列全是文字，應判為表頭");
    assert!(cells.iter().any(|c| c == "筆記本"), "內容：{cells:?}");
    assert!(cells.iter().any(|c| c == "610"), "公式的計算結果應保留");
}

#[test]
fn table_cells_can_be_edited_and_persist() {
    let mut s = session("xlsx-edit");
    let page = s.first_page().unwrap();
    let id = s
        .insert_table(
            page,
            2,
            2,
            vec!["項目".into(), "數量".into(), "筆記本".into(), "3".into()],
            true,
        )
        .unwrap();

    s.set_table_cell(id, 1, 1, "7").unwrap();
    // 越界要報錯，不能靜默吞掉。
    assert!(s.set_table_cell(id, 9, 0, "x").is_err());

    let cells = blocks(&s, page)
        .into_iter()
        .find_map(|k| match k {
            BlockKind::Table { cells, .. } => Some(cells),
            _ => None,
        })
        .unwrap();
    assert_eq!(cells[3], "7", "編輯後的值：{cells:?}");
}

#[test]
fn the_original_file_is_always_preserved() {
    // 解析必然失真。使用者要能拿回原本的東西。
    let mut s = session("preserve");
    let page = s.first_page().unwrap();
    s.import_embedded(page, fixture("sample.docx")).unwrap();

    let blob = blocks(&s, page)
        .into_iter()
        .find_map(|k| match k {
            BlockKind::Embedded { blob, .. } => Some(blob),
            _ => None,
        })
        .expect("應有嵌入區塊記錄原檔");

    let stored = s
        .package()
        .blobs()
        .get(padnote_storage::BlobId::from_hex(&blob).unwrap())
        .unwrap();
    let original = std::fs::read(fixture("sample.docx")).unwrap();
    assert_eq!(stored, original, "原檔必須位元級保留");
}

#[test]
fn embedded_content_is_searchable() {
    let mut s = session("search");
    let page = s.first_page().unwrap();
    s.import_embedded(page, fixture("sample.xlsx")).unwrap();
    assert!(!s.search("筆記本", 10).is_empty(), "嵌入內容應可搜尋");
}

#[test]
fn embedded_documents_survive_a_reopen() {
    let mut s = session("reopen");
    let page = s.first_page().unwrap();
    s.import_embedded(page, fixture("sample.docx")).unwrap();

    let root = s.package().root().to_path_buf();
    drop(s);

    let reopened = NotebookSession::open(&root, 0xA1).unwrap();
    let has_embedded = reopened
        .notebook()
        .pages()
        .iter()
        .flat_map(|p| p.blocks())
        .any(|b| matches!(b.kind, BlockKind::Embedded { .. }));
    assert!(has_embedded, "嵌入區塊必須持久化");
    assert!(!reopened.search("線性", 10).is_empty(), "索引也要重建");
}

#[test]
fn unsupported_format_is_rejected_clearly() {
    let mut s = session("unsupported");
    let page = s.first_page().unwrap();
    let bad = tmp("unsupported").join("thing.exe");
    std::fs::create_dir_all(bad.parent().unwrap()).unwrap();
    std::fs::write(&bad, b"x").unwrap();

    let err = s.import_embedded(page, &bad).unwrap_err();
    assert!(err.to_string().contains("不支援"), "{err}");
}

#[test]
fn importing_to_a_missing_page_is_rejected() {
    let mut s = session("badpage");
    assert!(
        s.import_embedded(Uuid::now_v7(), fixture("sample.docx"))
            .is_err()
    );
}
