//! 產生 `.docx` 測試檔。
//!
//! 手工組的最小 OOXML 不被 `docx-rs` 接受（缺 styles/numbering 等部件），
//! 因此用它自己產生 —— 這同時也驗證了寫入與讀取的往返。
//!
//! ```bash
//! cargo run -p padnote-embed --example make_fixtures
//! ```

use docx_rs::*;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let out = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("fixtures/sample.docx");
    let file = std::fs::File::create(&out)?;

    Docx::new()
        .add_paragraph(
            Paragraph::new()
                .add_run(Run::new().add_text("線性代數 第三週"))
                .style("Heading1"),
        )
        .add_paragraph(
            Paragraph::new().add_run(Run::new().add_text("特徵值與特徵向量是本章重點。")),
        )
        .add_paragraph(
            Paragraph::new()
                .add_run(Run::new().add_text("定義"))
                .style("Heading2"),
        )
        // 刻意切成三個 run（模擬粗體造成的分割）—— 解析時必須接回同一段
        .add_paragraph(
            Paragraph::new()
                .add_run(Run::new().add_text("設 A 為方陣，"))
                .add_run(Run::new().add_text("若存在非零向量 v").bold())
                .add_run(Run::new().add_text(" 使得 Av = λv。")),
        )
        .add_paragraph(
            Paragraph::new()
                .add_run(Run::new().add_text("可對角化"))
                .numbering(NumberingId::new(1), IndentLevel::new(0)),
        )
        .add_paragraph(
            Paragraph::new()
                .add_run(Run::new().add_text("特徵多項式"))
                .numbering(NumberingId::new(1), IndentLevel::new(0)),
        )
        .build()
        .pack(file)?;

    println!("已產生 {}", out.display());
    Ok(())
}
