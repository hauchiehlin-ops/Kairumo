//! 表格的版面計算。
//!
//! # 為什麼在核心
//!
//! 表格的欄寬、列高與斷行是「內容 → 幾何」的純計算。兩個平台各算一份的話，
//! 同一張表在 iPad 與 Android 上會**斷行位置不同、欄寬不同、總高度不同** ——
//! 而表格的高度會影響它底下的東西，整頁版面就分家了。
//!
//! 文字寬度用的是 [`padnote_chart::estimate_text_width`]：同一個近似值，
//! 兩個平台因此算出同樣的結果。各自去問系統字型反而會不一致。

use padnote_chart::estimate_text_width;

/// 合併儲存格的錨點與跨度。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct CellSpan {
    pub row: u32,
    pub col: u32,
    pub row_span: u32,
    pub col_span: u32,
}

/// 一格的位置與內容。
#[derive(Clone, Debug, PartialEq)]
pub struct CellBox {
    pub row: u32,
    pub col: u32,
    /// 合併時的跨度；未合併為 1。
    pub row_span: u32,
    pub col_span: u32,
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
    /// 已經斷好行的文字。平台照著畫，不要自己再斷一次。
    pub lines: Vec<String>,
    /// 是不是表頭列。
    pub is_header: bool,
}

/// 一條格線。
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Rule {
    pub x1: f64,
    pub y1: f64,
    pub x2: f64,
    pub y2: f64,
}

/// 算好的表格版面。
#[derive(Clone, Debug, Default, PartialEq)]
pub struct TableLayout {
    pub width: f64,
    pub height: f64,
    pub cells: Vec<CellBox>,
    pub rules: Vec<Rule>,
    /// 每一欄的寬度，依序。
    pub column_widths: Vec<f64>,
    /// 每一列的高度，依序。
    pub row_heights: Vec<f64>,
}

/// 排版參數。
#[derive(Clone, Copy, Debug)]
pub struct TableStyle {
    pub font_size: f64,
    /// 儲存格內距。
    pub padding: f64,
    /// 一列至少多高（空白列不該是一條線）。
    pub min_row_height: f64,
    /// 行距倍率。
    pub line_height: f64,
}

impl Default for TableStyle {
    fn default() -> Self {
        Self {
            font_size: 14.0,
            padding: 6.0,
            min_row_height: 28.0,
            line_height: 1.35,
        }
    }
}

/// 被合併蓋住的格子。
///
/// 它們不畫、也不佔位 —— 但**仍然要算得出來**，否則平台會在合併區上再畫一次
/// 格線，看起來就像合併沒有生效。
fn is_covered(row: u32, col: u32, merged: &[CellSpan]) -> bool {
    merged.iter().any(|s| {
        !(s.row == row && s.col == col)
            && row >= s.row
            && row < s.row + s.row_span.max(1)
            && col >= s.col
            && col < s.col + s.col_span.max(1)
    })
}

fn span_at(row: u32, col: u32, merged: &[CellSpan]) -> (u32, u32) {
    merged
        .iter()
        .find(|s| s.row == row && s.col == col)
        .map(|s| (s.row_span.max(1), s.col_span.max(1)))
        .unwrap_or((1, 1))
}

/// 把一段文字按可用寬度斷行。
///
/// 以字元為單位斷，不是以詞 —— 中文沒有空白可以斷，按詞斷的話一整段中文會
/// 變成一條衝出格子的長線。
fn wrap(text: &str, available: f64, font_size: f64) -> Vec<String> {
    if text.is_empty() {
        return vec![String::new()];
    }
    if available <= 0.0 {
        return vec![text.to_string()];
    }
    let mut lines = Vec::new();
    let mut current = String::new();
    let mut width = 0.0;
    for ch in text.chars() {
        if ch == '\n' {
            lines.push(std::mem::take(&mut current));
            width = 0.0;
            continue;
        }
        let w = estimate_text_width(&ch.to_string(), font_size);
        if width + w > available && !current.is_empty() {
            lines.push(std::mem::take(&mut current));
            width = 0.0;
        }
        current.push(ch);
        width += w;
    }
    lines.push(current);
    lines
}

/// 算出表格的版面。
///
/// `cells` 逐列展開，長度應為 `rows * cols`；不足的部分視為空白。
/// 欄寬平均分配 —— 依內容自動調整看起來聰明，但同一張表在兩台裝置上
/// 輸入不同內容時欄寬就會不一樣，反而更難對照。
pub fn layout(
    rows: u32,
    cols: u32,
    cells: &[String],
    header_row: bool,
    merged: &[CellSpan],
    width: f64,
    style: TableStyle,
) -> TableLayout {
    if rows == 0 || cols == 0 || width <= 0.0 {
        return TableLayout::default();
    }

    let column_width = width / cols as f64;
    let column_widths = vec![column_width; cols as usize];

    // 先算每一列要多高：取該列所有格子裡最高的那個。
    let text_at = |row: u32, col: u32| -> &str {
        cells
            .get((row * cols + col) as usize)
            .map(String::as_str)
            .unwrap_or("")
    };
    let line_height = style.font_size * style.line_height;

    let mut row_heights = vec![style.min_row_height; rows as usize];
    for row in 0..rows {
        let mut tallest: f64 = style.min_row_height;
        for col in 0..cols {
            if is_covered(row, col, merged) {
                continue;
            }
            let (row_span, col_span) = span_at(row, col, merged);
            // 跨列的格子不決定單一列的高度 —— 它的內容分散在好幾列上。
            if row_span > 1 {
                continue;
            }
            let available = column_width * col_span as f64 - style.padding * 2.0;
            let lines = wrap(text_at(row, col), available, style.font_size);
            tallest = tallest.max(lines.len() as f64 * line_height + style.padding * 2.0);
        }
        row_heights[row as usize] = tallest;
    }

    let mut y_of = vec![0.0; rows as usize + 1];
    for row in 0..rows as usize {
        y_of[row + 1] = y_of[row] + row_heights[row];
    }
    let height = y_of[rows as usize];

    let mut out = TableLayout {
        width,
        height,
        column_widths,
        row_heights: row_heights.clone(),
        ..Default::default()
    };

    for row in 0..rows {
        for col in 0..cols {
            if is_covered(row, col, merged) {
                continue;
            }
            let (row_span, col_span) = span_at(row, col, merged);
            let last_row = (row + row_span).min(rows) as usize;
            let cell_width = column_width * col_span as f64;
            let cell_height = y_of[last_row] - y_of[row as usize];
            let available = cell_width - style.padding * 2.0;
            out.cells.push(CellBox {
                row,
                col,
                row_span,
                col_span,
                x: column_width * col as f64,
                y: y_of[row as usize],
                width: cell_width,
                height: cell_height,
                lines: wrap(text_at(row, col), available, style.font_size),
                is_header: header_row && row == 0,
            });
        }
    }

    // 格線只畫在**格子的邊界**上，不是整條橫貫 —— 橫貫的話會從合併區上穿過去，
    // 看起來就像合併沒有生效。
    for cell in &out.cells {
        out.rules.push(Rule {
            x1: cell.x,
            y1: cell.y,
            x2: cell.x + cell.width,
            y2: cell.y,
        });
        out.rules.push(Rule {
            x1: cell.x,
            y1: cell.y + cell.height,
            x2: cell.x + cell.width,
            y2: cell.y + cell.height,
        });
        out.rules.push(Rule {
            x1: cell.x,
            y1: cell.y,
            x2: cell.x,
            y2: cell.y + cell.height,
        });
        out.rules.push(Rule {
            x1: cell.x + cell.width,
            y1: cell.y,
            x2: cell.x + cell.width,
            y2: cell.y + cell.height,
        });
    }

    out
}
