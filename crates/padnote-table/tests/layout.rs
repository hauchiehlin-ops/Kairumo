//! 表格版面的行為測試。
//!
//! 釘的是「錯了使用者看得出來」的那幾件事：文字被切掉、合併沒生效、
//! 兩台裝置算出不同的高度。

use padnote_table::*;

fn cells(items: &[&str]) -> Vec<String> {
    items.iter().map(|s| s.to_string()).collect()
}

fn simple() -> TableLayout {
    layout(2, 2, &cells(&["甲", "乙", "丙", "丁"]), true, &[], 400.0, TableStyle::default())
}

#[test]
fn every_cell_gets_a_box() {
    let l = simple();
    assert_eq!(l.cells.len(), 4);
}

#[test]
fn columns_share_the_width_evenly() {
    // 依內容自動調欄寬看起來聰明，但同一張表在兩台裝置上輸入不同內容時
    // 欄寬就會不一樣，反而更難對照。
    let l = simple();
    assert_eq!(l.column_widths, vec![200.0, 200.0]);
    assert!((l.cells[0].width - 200.0).abs() < 1e-9);
}

#[test]
fn cells_tile_without_gaps_or_overlap() {
    let l = simple();
    let first = &l.cells[0];
    let second = &l.cells[1];
    assert!((first.x + first.width - second.x).abs() < 1e-9, "兩格之間有縫或重疊");
}

#[test]
fn the_total_height_is_the_sum_of_the_rows() {
    let l = simple();
    assert!((l.height - l.row_heights.iter().sum::<f64>()).abs() < 1e-9);
}

#[test]
fn the_header_row_is_marked() {
    // 表頭沒標出來的話，平台畫不出粗體與底色，表格就只是一堆格子。
    let l = simple();
    assert!(l.cells.iter().filter(|c| c.row == 0).all(|c| c.is_header));
    assert!(l.cells.iter().filter(|c| c.row == 1).all(|c| !c.is_header));
}

#[test]
fn no_header_means_no_marked_cells() {
    let l = layout(2, 2, &cells(&["a", "b", "c", "d"]), false, &[], 400.0, TableStyle::default());
    assert!(l.cells.iter().all(|c| !c.is_header));
}

// ── 斷行 ────────────────────────────────────────────────────

#[test]
fn long_text_wraps_instead_of_overflowing() {
    // 不斷行的話，一整段中文會變成一條衝出格子的長線。
    let long = "這是一段很長很長的說明文字用來測試斷行是否正確運作";
    let l = layout(1, 1, &cells(&[long]), false, &[], 120.0, TableStyle::default());
    assert!(l.cells[0].lines.len() > 1, "沒有斷行");
}

#[test]
fn a_taller_cell_makes_the_whole_row_taller() {
    // 只長高一格的話，同一列的其他格會對不齊。
    let long = "這是一段很長很長的說明文字用來測試列高";
    let l = layout(1, 2, &cells(&[long, "短"]), false, &[], 200.0, TableStyle::default());
    assert!((l.cells[0].height - l.cells[1].height).abs() < 1e-9, "同一列的格子高度不一致");
    assert!(l.row_heights[0] > TableStyle::default().min_row_height);
}

#[test]
fn explicit_line_breaks_are_honoured() {
    let l = layout(1, 1, &cells(&["第一行\n第二行"]), false, &[], 400.0, TableStyle::default());
    assert_eq!(l.cells[0].lines, vec!["第一行", "第二行"]);
}

#[test]
fn an_empty_cell_still_has_height() {
    // 空白列變成一條線的話，使用者會以為那一列不見了。
    let l = layout(1, 1, &cells(&[""]), false, &[], 400.0, TableStyle::default());
    assert!(l.cells[0].height >= TableStyle::default().min_row_height);
    assert_eq!(l.cells[0].lines, vec![""]);
}

// ── 合併 ────────────────────────────────────────────────────

#[test]
fn a_merged_cell_spans_its_neighbours() {
    let merged = [CellSpan { row: 0, col: 0, row_span: 1, col_span: 2 }];
    let l = layout(2, 2, &cells(&["合併", "", "丙", "丁"]), false, &merged, 400.0, TableStyle::default());

    let anchor = l.cells.iter().find(|c| c.row == 0 && c.col == 0).unwrap();
    assert_eq!(anchor.col_span, 2);
    assert!((anchor.width - 400.0).abs() < 1e-9);
}

#[test]
fn covered_cells_are_not_emitted() {
    // 被蓋住的格子若照樣畫出來，合併區上會再出現一條格線 ——
    // 看起來就像合併沒有生效。
    let merged = [CellSpan { row: 0, col: 0, row_span: 1, col_span: 2 }];
    let l = layout(2, 2, &cells(&["合併", "", "丙", "丁"]), false, &merged, 400.0, TableStyle::default());

    assert!(!l.cells.iter().any(|c| c.row == 0 && c.col == 1), "被合併蓋住的格子不該畫出來");
    assert_eq!(l.cells.len(), 3);
}

#[test]
fn a_vertical_merge_spans_rows() {
    let merged = [CellSpan { row: 0, col: 0, row_span: 2, col_span: 1 }];
    let l = layout(2, 2, &cells(&["直的", "乙", "", "丁"]), false, &merged, 400.0, TableStyle::default());

    let anchor = l.cells.iter().find(|c| c.row == 0 && c.col == 0).unwrap();
    assert_eq!(anchor.row_span, 2);
    assert!((anchor.height - (l.row_heights[0] + l.row_heights[1])).abs() < 1e-9);
}

#[test]
fn no_rule_crosses_a_merged_cell() {
    // 格線橫貫的話會從合併區上穿過去。
    let merged = [CellSpan { row: 0, col: 0, row_span: 1, col_span: 2 }];
    let l = layout(2, 2, &cells(&["合併", "", "丙", "丁"]), false, &merged, 400.0, TableStyle::default());

    let anchor = l.cells.iter().find(|c| c.row == 0 && c.col == 0).unwrap();
    let crossing = l.rules.iter().any(|r| {
        r.x1 == r.x2
            && r.x1 > anchor.x + 0.01
            && r.x1 < anchor.x + anchor.width - 0.01
            && r.y1 < anchor.y + anchor.height - 0.01
            && r.y2 > anchor.y + 0.01
    });
    assert!(!crossing, "有格線從合併區上穿過去");
}

// ── 邊界 ────────────────────────────────────────────────────

#[test]
fn a_short_cell_list_is_treated_as_blanks() {
    // 少給幾格就少畫幾格的話，表格會變成一列長一列短。
    let l = layout(2, 2, &cells(&["只有一格"]), false, &[], 400.0, TableStyle::default());
    assert_eq!(l.cells.len(), 4);
    assert_eq!(l.cells[3].lines, vec![""]);
}

#[test]
fn a_zero_sized_table_produces_nothing_instead_of_panicking() {
    assert!(layout(0, 3, &[], false, &[], 400.0, TableStyle::default()).cells.is_empty());
    assert!(layout(3, 0, &[], false, &[], 400.0, TableStyle::default()).cells.is_empty());
    assert!(layout(2, 2, &[], false, &[], 0.0, TableStyle::default()).cells.is_empty());
}

#[test]
fn layout_is_deterministic() {
    // 兩個平台各算一次，結果必須一模一樣 —— 這是把版面放進核心的全部理由。
    assert_eq!(simple(), simple());
}
