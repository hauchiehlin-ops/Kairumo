//! `.xlsx` 匯入（可編輯，ADR-0009）。
//!
//! 支援值、公式的**計算結果**、基本型別。**不支援**巨集、樞紐分析、圖表、
//! 條件式格式、資料驗證 —— 見 [`crate::Limitations`]。
//!
//! ## 為什麼只讀公式的結果不讀公式本身
//! 要編輯公式就得實作公式引擎，那是另一個產品。我們保留公式字串供顯示，
//! 但**編輯儲存格時公式會被取代為輸入的值** —— 這一點必須在 UI 明示。

use crate::EmbedError;
use calamine::{Data, Reader, open_workbook_auto};
use std::path::Path;

/// 儲存格的值。
#[derive(Clone, Debug, PartialEq)]
pub enum CellValue {
    Empty,
    Text(String),
    Number(f64),
    Bool(bool),
    /// 錯誤值（`#DIV/0!` 之類）。保留字串以便原樣顯示。
    Error(String),
}

impl CellValue {
    /// 顯示用字串。
    pub fn display(&self) -> String {
        match self {
            Self::Empty => String::new(),
            Self::Text(s) => s.clone(),
            // 整數不要顯示成 3.0
            Self::Number(n) if n.fract() == 0.0 && n.abs() < 1e15 => format!("{}", *n as i64),
            Self::Number(n) => n.to_string(),
            Self::Bool(b) => if *b { "TRUE" } else { "FALSE" }.into(),
            Self::Error(e) => e.clone(),
        }
    }

    pub fn is_empty(&self) -> bool {
        matches!(self, Self::Empty)
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct Cell {
    pub value: CellValue,
    /// 原始公式（若有）。**編輯儲存格會讓它消失**。
    pub formula: Option<String>,
}

/// 一張工作表。
#[derive(Clone, Debug, Default)]
pub struct Sheet {
    pub name: String,
    /// `rows[列][欄]`。
    pub rows: Vec<Vec<Cell>>,
}

impl Sheet {
    pub fn row_count(&self) -> usize {
        self.rows.len()
    }

    /// 最寬的一列的欄數。列可能不等長，取最大值才不會漏欄。
    pub fn column_count(&self) -> usize {
        self.rows.iter().map(Vec::len).max().unwrap_or(0)
    }

    pub fn cell(&self, row: usize, col: usize) -> Option<&Cell> {
        self.rows.get(row)?.get(col)
    }

    /// 轉成 Markdown 表格，供匯出與純文字檢視使用。
    pub fn to_markdown(&self) -> String {
        if self.rows.is_empty() {
            return String::new();
        }
        let cols = self.column_count();
        let mut out = String::new();

        for (i, row) in self.rows.iter().enumerate() {
            out.push('|');
            for c in 0..cols {
                let text = row
                    .get(c)
                    .map_or(String::new(), |cell| cell.value.display());
                out.push_str(&format!(" {text} |"));
            }
            out.push('\n');
            // 第一列之後接分隔線
            if i == 0 {
                out.push('|');
                for _ in 0..cols {
                    out.push_str(" --- |");
                }
                out.push('\n');
            }
        }
        out
    }
}

pub fn import_xlsx(path: impl AsRef<Path>) -> Result<Vec<Sheet>, EmbedError> {
    let path = path.as_ref();
    if !path.exists() {
        return Err(EmbedError::NotFound(path.display().to_string()));
    }
    let mut workbook =
        open_workbook_auto(path).map_err(|e| EmbedError::Malformed(e.to_string()))?;

    let names = workbook.sheet_names().to_vec();
    let mut sheets = Vec::with_capacity(names.len());

    for name in names {
        let Ok(range) = workbook.worksheet_range(&name) else {
            continue;
        };
        let formulas = workbook.worksheet_formula(&name).ok();

        let rows = range
            .rows()
            .enumerate()
            .map(|(r, row)| {
                row.iter()
                    .enumerate()
                    .map(|(c, data)| Cell {
                        value: convert(data),
                        formula: formulas
                            .as_ref()
                            .and_then(|f| f.get_value((r as u32, c as u32)))
                            .filter(|s| !s.is_empty())
                            .map(ToString::to_string),
                    })
                    .collect()
            })
            .collect();

        sheets.push(Sheet { name, rows });
    }
    Ok(sheets)
}

fn convert(d: &Data) -> CellValue {
    match d {
        Data::Empty => CellValue::Empty,
        Data::String(s) => CellValue::Text(s.clone()),
        Data::Float(f) => CellValue::Number(*f),
        Data::Int(i) => CellValue::Number(*i as f64),
        Data::Bool(b) => CellValue::Bool(*b),
        Data::Error(e) => CellValue::Error(format!("{e:?}")),
        // 日期與時間本版以顯示字串處理，不做型別轉換。
        other => CellValue::Text(other.to_string()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample() -> Vec<Sheet> {
        let p = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("fixtures/sample.xlsx");
        import_xlsx(p).expect("應能解析測試檔")
    }

    #[test]
    fn reads_sheet_name_and_shape() {
        let s = &sample()[0];
        assert_eq!(s.name, "採購清單");
        assert_eq!(s.row_count(), 4);
        assert_eq!(s.column_count(), 3);
    }

    #[test]
    fn reads_text_and_numbers() {
        let s = &sample()[0];
        assert_eq!(s.cell(0, 0).unwrap().value, CellValue::Text("項目".into()));
        assert_eq!(s.cell(1, 1).unwrap().value, CellValue::Number(3.0));
    }

    #[test]
    fn integers_do_not_display_as_floats() {
        // 「3.0 個筆記本」看起來很蠢。
        assert_eq!(CellValue::Number(3.0).display(), "3");
        assert_eq!(CellValue::Number(2.5).display(), "2.5");
    }

    #[test]
    fn formula_results_are_read() {
        // 我們讀結果不讀公式引擎 —— 要編輯公式就得實作公式引擎，那是另一個產品。
        let s = &sample()[0];
        assert_eq!(s.cell(3, 2).unwrap().value, CellValue::Number(610.0));
    }

    #[test]
    fn formulas_are_preserved_for_display() {
        let s = &sample()[0];
        let cell = s.cell(3, 2).unwrap();
        assert!(
            cell.formula.as_deref().is_some_and(|f| f.contains("B2")),
            "公式字串應保留供顯示：{:?}",
            cell.formula
        );
    }

    #[test]
    fn plain_cells_have_no_formula() {
        assert!(sample()[0].cell(0, 0).unwrap().formula.is_none());
    }

    #[test]
    fn converts_to_a_markdown_table() {
        let md = sample()[0].to_markdown();
        assert!(md.contains("| 項目 | 數量 | 單價 |"));
        assert!(md.contains("| --- | --- | --- |"), "應有表頭分隔線");
        assert!(md.contains("| 筆記本 | 3 | 120 |"));
    }

    #[test]
    fn empty_sheet_produces_empty_markdown() {
        assert_eq!(Sheet::default().to_markdown(), "");
        assert_eq!(Sheet::default().column_count(), 0);
    }

    #[test]
    fn ragged_rows_use_the_widest_column_count() {
        // 列不等長時取最大值，否則會漏欄。
        let s = Sheet {
            name: "x".into(),
            rows: vec![
                vec![Cell {
                    value: CellValue::Text("a".into()),
                    formula: None,
                }],
                vec![
                    Cell {
                        value: CellValue::Text("b".into()),
                        formula: None,
                    },
                    Cell {
                        value: CellValue::Text("c".into()),
                        formula: None,
                    },
                ],
            ],
        };
        assert_eq!(s.column_count(), 2);
        assert!(s.to_markdown().contains("| a |  |"), "短列應補空欄");
    }

    #[test]
    fn missing_file_reports_clearly() {
        assert!(matches!(
            import_xlsx("/definitely/not/here.xlsx"),
            Err(EmbedError::NotFound(_))
        ));
    }

    #[test]
    fn out_of_range_cell_is_none() {
        assert!(sample()[0].cell(99, 99).is_none());
    }
}
