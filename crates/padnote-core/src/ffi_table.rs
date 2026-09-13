//! 表格與物件堆疊／群組的 FFI。
//!
//! # 缺的一直是「讀回來」
//!
//! 表格的寫入操作（插入、逐格改寫、增刪列欄、合併）與物件的堆疊、群組操作
//! 本來就有 FFI。缺的是**讀取**：平台拿不到「這一頁有哪些表格、裡面是什麼」、
//! 「這一頁有哪些物件」。
//!
//! 少了讀取，功能就是單向的：寫得進檔案，畫面上卻列不出來，也就選不到、
//! 編不了。這與圖片區塊、筆記本中繼資料是同一類漏洞 —— 出口只開了一半，
//! 而且在單機測試時完全看不出來。

use padnote_doc::BlockKind;

use crate::ffi::{FfiError, PadnoteSession, parse_uuid};

/// 一張表格的內容。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiTable {
    pub block_id: String,
    pub rows: u32,
    pub cols: u32,
    /// 逐列展開的儲存格文字，長度為 `rows * cols`。
    ///
    /// 用扁平陣列而不是巢狀：增刪欄時只要 splice，巢狀結構要逐列處理
    /// 而且容易出現長度不一致的列 —— 那種錯誤在畫面上是「某一列少一格」。
    pub cells: Vec<String>,
    pub header_row: bool,
    /// 合併儲存格：每一項是 `[row, col, row_span, col_span]`。
    pub merged_cells: Vec<Vec<u32>>,
}

/// 物件的種類。平台用它決定怎麼畫、以及能不能解散群組。
#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum FfiObjectKind {
    Strokes,
    Block,
    Group,
    Shape,
    Connection,
}

/// 物件樹裡的一個節點。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiObject {
    pub id: String,
    pub kind: FfiObjectKind,
    /// 群組成員、或筆畫物件的筆畫 id。其餘種類為空。
    pub members: Vec<String>,
    /// 在同層裡的堆疊順序，0 為最底層。
    pub z_index: u32,
}

#[uniffi::export]
impl PadnoteSession {

    /// 這一頁所有表格區塊的 id，依加入順序。
    pub fn table_block_ids(&self, page_id: String) -> Result<Vec<String>, FfiError> {
        let page = parse_uuid(&page_id)?;
        let guard = self.lock();
        Ok(guard
            .notebook()
            .page(page)
            .map(|p| {
                p.blocks()
                    .iter()
                    .filter(|b| matches!(b.kind, BlockKind::Table { .. }))
                    .map(|b| b.id.to_string())
                    .collect()
            })
            .unwrap_or_default())
    }

    /// 讀回一張表格。不是表格區塊時回 `None`。
    ///
    /// 這是原本缺的那一半：表格寫得進檔案，卻讀不回來 —— 畫面上列不出來，
    /// 也就選不到、編不了。
    pub fn table(&self, block_id: String) -> Result<Option<FfiTable>, FfiError> {
        let id = parse_uuid(&block_id)?;
        let guard = self.lock();
        Ok(guard
            .notebook()
            .pages()
            .iter()
            .flat_map(|p| p.blocks())
            .find(|b| b.id == id)
            .and_then(|b| match &b.kind {
                BlockKind::Table {
                    rows,
                    cols,
                    cells,
                    header_row,
                    merged_cells,
                } => Some(FfiTable {
                    block_id: block_id.clone(),
                    rows: *rows,
                    cols: *cols,
                    cells: cells.clone(),
                    header_row: *header_row,
                    merged_cells: merged_cells
                        .iter()
                        .map(|s| vec![s.row, s.col, s.row_span, s.col_span])
                        .collect(),
                }),
                _ => None,
            }))
    }

    /// 設定物件在同層裡的堆疊位置。
    ///
    /// 帶的是**絕對索引**，不是「上移一層」。相對操作在併發下會疊加：
    /// 兩台裝置各按一次「移到最上層」，合併後會得出誰也沒預期的順序
    /// （`format-spec.md` §6.2 的「堆疊順序」）。
    ///
    /// 圖層面板一次重排整批物件時，就是逐個帶索引進來。
    pub fn set_object_z_index(&self, object_id: String, index: u32) -> Result<(), FfiError> {
        self.lock()
            .set_z_index(parse_uuid(&object_id)?, index as usize)?;
        Ok(())
    }

    /// 依 id 取一個物件節點，不論它在不在最上層。
    ///
    /// [`Self::root_objects`] 只回傳根層的物件。群組之後，成員就不是根物件了 ——
    /// 平台若只看根層，整組形狀會從畫面上消失，而檔案裡其實好端端地存在。
    /// 要走進群組就需要這一支。
    ///
    /// `z_index` 只在同層內有意義；非根層的物件回傳它在所屬層裡的位置。
    pub fn object_node(
        &self,
        page_id: String,
        object_id: String,
    ) -> Result<Option<FfiObject>, FfiError> {
        let page = parse_uuid(&page_id)?;
        let id = parse_uuid(&object_id)?;
        let guard = self.lock();
        let Some(tree) = guard.objects(page) else { return Ok(None) };
        let Some(node) = tree.get(id) else { return Ok(None) };
        Ok(Some(describe_object(node, tree.z_index(id).unwrap_or(0))))
    }

    /// 這一頁最上層的物件，**依堆疊順序**（索引 0 在最底層）。
    pub fn root_objects(&self, page_id: String) -> Result<Vec<FfiObject>, FfiError> {
        let page = parse_uuid(&page_id)?;
        let guard = self.lock();
        let Some(tree) = guard.objects(page) else {
            return Ok(Vec::new());
        };
        Ok(tree
            .roots()
            .iter()
            .enumerate()
            .filter_map(|(index, id)| tree.get(*id).map(|node| describe_object(node, index)))
            .collect())
    }
}


/// 一格算好的位置與已經斷好行的文字。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiTableCell {
    pub row: u32,
    pub col: u32,
    pub row_span: u32,
    pub col_span: u32,
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
    /// 已經斷好行的文字。平台照著畫，**不要自己再斷一次** ——
    /// 各自斷行的話，同一張表在兩台裝置上的高度會不一樣。
    pub lines: Vec<String>,
    pub is_header: bool,
}

/// 一條格線。
#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct FfiTableRule {
    pub x1: f64,
    pub y1: f64,
    pub x2: f64,
    pub y2: f64,
}

/// 算好的表格版面。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiTableLayout {
    pub width: f64,
    pub height: f64,
    pub cells: Vec<FfiTableCell>,
    pub rules: Vec<FfiTableRule>,
    pub column_widths: Vec<f64>,
    pub row_heights: Vec<f64>,
}

/// 把物件樹的節點描述成 FFI 的形狀。
fn describe_object(node: &padnote_doc::ObjectNode, z_index: usize) -> FfiObject {
    FfiObject {
        id: node.id.to_string(),
        kind: match &node.kind {
            padnote_doc::ObjectKind::Strokes(_) => FfiObjectKind::Strokes,
            padnote_doc::ObjectKind::Block(_) => FfiObjectKind::Block,
            padnote_doc::ObjectKind::Group(_) => FfiObjectKind::Group,
            padnote_doc::ObjectKind::Shape(_) => FfiObjectKind::Shape,
            padnote_doc::ObjectKind::Connection(_) => FfiObjectKind::Connection,
        },
        members: match &node.kind {
            padnote_doc::ObjectKind::Strokes(ids) | padnote_doc::ObjectKind::Group(ids) => {
                ids.iter().map(|i| i.to_string()).collect()
            }
            padnote_doc::ObjectKind::Block(id) => vec![id.to_string()],
            _ => Vec::new(),
        },
        z_index: z_index as u32,
    }
}

/// 一個形狀物件的內容。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiShapeObject {
    pub object_id: String,
    pub kind: crate::ffi_shapes::FfiShapeKind,
    pub min_x: f32,
    pub min_y: f32,
    pub max_x: f32,
    pub max_y: f32,
    pub corner_radius: f32,
    pub text: String,
}

#[uniffi::export]
impl PadnoteSession {
    /// 讀回一個形狀物件。不是形狀時回 `None`。
    ///
    /// 與表格是同一類漏洞：`insert_shape` 寫得進去，卻沒有任何出口讀回來 ——
    /// 平台只能把形狀另外存一份在自己的檔案裡，於是它就跨不過平台了。
    pub fn shape_object(
        &self,
        page_id: String,
        object_id: String,
    ) -> Result<Option<FfiShapeObject>, FfiError> {
        let page = parse_uuid(&page_id)?;
        let id = parse_uuid(&object_id)?;
        let guard = self.lock();
        Ok(guard.object(page, id).and_then(|node| match &node.kind {
            padnote_doc::ObjectKind::Shape(shape) => Some(FfiShapeObject {
                object_id: object_id.clone(),
                kind: crate::ffi::from_doc_shape_kind(shape.kind),
                min_x: shape.bounds.min_x,
                min_y: shape.bounds.min_y,
                max_x: shape.bounds.max_x,
                max_y: shape.bounds.max_y,
                corner_radius: shape.corner_radius,
                text: shape.text.clone(),
            }),
            _ => None,
        }))
    }
}

/// 一條連接線物件的內容。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiConnectionObject {
    pub object_id: String,
    pub from_object_id: String,
    pub to_object_id: String,
    pub from_anchor: crate::ffi_shapes::FfiAnchor,
    pub to_anchor: crate::ffi_shapes::FfiAnchor,
    pub route: crate::ffi_shapes::FfiRouteStyle,
    pub start_cap: crate::ffi_shapes::FfiEndCap,
    pub end_cap: crate::ffi_shapes::FfiEndCap,
    pub label: String,
}

#[uniffi::export]
impl PadnoteSession {
    /// 讀回一條連接線。不是連接線時回 `None`。
    ///
    /// 與形狀、表格是同一類漏洞：`insert_connection` 寫得進去卻讀不回來，
    /// 於是連接線只能由平台自己另存一份 —— 換一台裝置打開，流程圖就只剩
    /// 一堆沒有線連起來的方塊。
    pub fn connection_object(
        &self,
        page_id: String,
        object_id: String,
    ) -> Result<Option<FfiConnectionObject>, FfiError> {
        let page = parse_uuid(&page_id)?;
        let id = parse_uuid(&object_id)?;
        let guard = self.lock();
        Ok(guard.object(page, id).and_then(|node| match &node.kind {
            padnote_doc::ObjectKind::Connection(conn) => Some(FfiConnectionObject {
                object_id: object_id.clone(),
                from_object_id: conn.from.to_string(),
                to_object_id: conn.to.to_string(),
                from_anchor: crate::ffi::from_doc_anchor(conn.from_anchor),
                to_anchor: crate::ffi::from_doc_anchor(conn.to_anchor),
                route: crate::ffi::from_doc_route_style(conn.route),
                start_cap: crate::ffi::from_doc_end_cap(conn.start_cap),
                end_cap: crate::ffi::from_doc_end_cap(conn.end_cap),
                label: conn.label.clone(),
            }),
            _ => None,
        }))
    }
}

/// 算出一張表格在指定寬度下的版面。
///
/// 欄寬、列高與斷行都在核心算 —— 兩個平台各算一份的話，同一張表會斷行位置
/// 不同、總高度不同，而表格的高度會影響它底下的東西，整頁版面就分家了。
#[uniffi::export]
pub fn table_layout(
    table: FfiTable,
    width: f64,
    font_size: f64,
) -> FfiTableLayout {
    let merged: Vec<padnote_table::CellSpan> = table
        .merged_cells
        .iter()
        .filter(|s| s.len() >= 4)
        .map(|s| padnote_table::CellSpan {
            row: s[0],
            col: s[1],
            row_span: s[2],
            col_span: s[3],
        })
        .collect();
    let style = padnote_table::TableStyle {
        font_size,
        ..Default::default()
    };
    let laid = padnote_table::layout(
        table.rows,
        table.cols,
        &table.cells,
        table.header_row,
        &merged,
        width,
        style,
    );
    FfiTableLayout {
        width: laid.width,
        height: laid.height,
        cells: laid
            .cells
            .into_iter()
            .map(|c| FfiTableCell {
                row: c.row,
                col: c.col,
                row_span: c.row_span,
                col_span: c.col_span,
                x: c.x,
                y: c.y,
                width: c.width,
                height: c.height,
                lines: c.lines,
                is_header: c.is_header,
            })
            .collect(),
        rules: laid
            .rules
            .into_iter()
            .map(|r| FfiTableRule { x1: r.x1, y1: r.y1, x2: r.x2, y2: r.y2 })
            .collect(),
        column_widths: laid.column_widths,
        row_heights: laid.row_heights,
    }
}

#[cfg(test)]
mod tests {
    use crate::ffi::PadnoteSession;

    fn session(name: &str) -> (PadnoteSession, String) {
        let dir = std::env::temp_dir()
            .join(format!("padnote-table-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        let s = PadnoteSession::create(
            dir.to_string_lossy().into_owned(),
            "表格".into(),
            1_757_635_200_000,
            0xA1,
        )
        .unwrap();
        let page = s.first_page_id().unwrap();
        (s, page)
    }

    // ── 表格讀回來 ──────────────────────────────────────────

    #[test]
    fn a_table_can_be_listed_and_read_back() {
        // 這是原本缺的那一半：寫得進檔案，畫面上卻列不出來，
        // 也就選不到、編不了 —— 功能等於不存在。
        let (s, page) = session("read-back");
        let id = s
            .insert_table(
                page.clone(),
                2,
                2,
                vec!["甲".into(), "乙".into(), "丙".into(), "丁".into()],
                true,
            )
            .unwrap();

        assert_eq!(s.table_block_ids(page).unwrap(), vec![id.clone()]);
        let table = s.table(id).unwrap().expect("表格讀不回來");
        assert_eq!((table.rows, table.cols), (2, 2));
        assert_eq!(table.cells, vec!["甲", "乙", "丙", "丁"]);
        assert!(table.header_row);
    }

    #[test]
    fn short_cell_lists_are_padded_not_truncated() {
        // 少給幾格就少幾格的話，表格會變成一列長一列短。
        let (s, page) = session("pad");
        let id = s.insert_table(page, 2, 3, vec!["只有一格".into()], false).unwrap();
        let table = s.table(id).unwrap().unwrap();
        assert_eq!(table.cells.len(), 6);
        assert_eq!(table.cells[0], "只有一格");
    }

    #[test]
    fn editing_one_cell_leaves_the_others_alone() {
        // 逐格記錄而不是整表覆寫 —— 兩人同時編輯不同格時才不會互相覆蓋。
        let (s, page) = session("one-cell");
        let id = s
            .insert_table(page, 1, 3, vec!["a".into(), "b".into(), "c".into()], false)
            .unwrap();
        s.set_table_cell(id.clone(), 0, 1, "改過".into()).unwrap();

        assert_eq!(s.table(id).unwrap().unwrap().cells, vec!["a", "改過", "c"]);
    }

    #[test]
    fn inserting_a_row_shows_up_when_read_back() {
        let (s, page) = session("insert-row");
        let id = s.insert_table(page, 1, 2, vec!["a".into(), "b".into()], false).unwrap();
        s.insert_table_row(id.clone(), 1, vec!["c".into(), "d".into()]).unwrap();

        let table = s.table(id).unwrap().unwrap();
        assert_eq!(table.rows, 2);
        assert_eq!(table.cells, vec!["a", "b", "c", "d"]);
    }

    #[test]
    fn deleting_a_column_shows_up_when_read_back() {
        let (s, page) = session("delete-col");
        let id = s
            .insert_table(page, 2, 2, vec!["a".into(), "b".into(), "c".into(), "d".into()], false)
            .unwrap();
        s.delete_table_column(id.clone(), 0).unwrap();

        let table = s.table(id).unwrap().unwrap();
        assert_eq!(table.cols, 1);
        assert_eq!(table.cells, vec!["b", "d"]);
    }

    #[test]
    fn merged_cells_come_back_with_their_span() {
        // 跨度沒回來的話，畫出來的是一格一格分開的表，與使用者設定的不一樣。
        let (s, page) = session("merge");
        let id = s.insert_table(page, 2, 2, vec![], false).unwrap();
        s.merge_table_cells(id.clone(), 0, 0, 1, 2).unwrap();

        let table = s.table(id).unwrap().unwrap();
        assert_eq!(table.merged_cells, vec![vec![0, 0, 1, 2]]);
    }

    #[test]
    fn a_text_block_is_not_a_table() {
        // 認錯的話，文字方塊會被當成表格打開。
        let (s, page) = session("not-a-table");
        let text = s
            .add_text(page.clone(), "字".into(), crate::ffi::BlockStyle::Body)
            .unwrap();
        assert!(s.table(text).unwrap().is_none());
        assert!(s.table_block_ids(page).unwrap().is_empty());
    }

    #[test]
    fn a_table_survives_a_reopen() {
        // 只活在記憶體裡的話，關掉 App 表格就沒了。
        let dir = std::env::temp_dir().join(format!("padnote-table-reopen-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        let path = dir.to_string_lossy().into_owned();
        let id = {
            let s = PadnoteSession::create(path.clone(), "表格".into(), 1_757_635_200_000, 0xA1)
                .unwrap();
            let page = s.first_page_id().unwrap();
            s.insert_table(page, 1, 2, vec!["甲".into(), "乙".into()], false).unwrap()
        };

        let reopened = PadnoteSession::open_existing(path, 0xA1).unwrap();
        assert_eq!(reopened.table(id).unwrap().unwrap().cells, vec!["甲", "乙"]);
    }

    #[test]
    fn the_layout_crosses_the_boundary() {
        // 轉換表漏一個欄位，平台那邊就是靜靜地少畫一塊。
        let (s, page) = session("layout-ffi");
        let id = s
            .insert_table(page, 2, 2, vec!["甲".into(), "乙".into(), "丙".into(), "丁".into()], true)
            .unwrap();
        let table = s.table(id).unwrap().unwrap();

        let laid = super::table_layout(table, 400.0, 14.0);
        assert_eq!(laid.cells.len(), 4);
        assert_eq!(laid.column_widths, vec![200.0, 200.0]);
        assert!(laid.height > 0.0);
        assert!(!laid.rules.is_empty(), "格線沒有跨過 FFI");
        assert!(laid.cells[0].is_header);
        assert_eq!(laid.cells[0].lines, vec!["甲"]);
    }

    // ── 形狀讀回來 ──────────────────────────────────────────

    #[test]
    fn a_shape_can_be_read_back() {
        // 與表格是同一類漏洞：寫得進去，卻沒有出口讀回來 —— 平台只能把形狀
        // 另外存一份在自己的檔案裡，於是它就跨不過平台了。
        let (s, page) = session("shape-read-back");
        let id = s
            .insert_shape(
                page.clone(),
                crate::ffi_shapes::FfiShapeKind::Decision,
                10.0,
                20.0,
                110.0,
                80.0,
                4.0,
                "要不要繼續？".into(),
            )
            .unwrap();

        let shape = s.shape_object(page, id.clone()).unwrap().expect("形狀讀不回來");
        assert_eq!(shape.object_id, id);
        assert_eq!(shape.kind, crate::ffi_shapes::FfiShapeKind::Decision);
        assert_eq!((shape.min_x, shape.min_y), (10.0, 20.0));
        assert_eq!((shape.max_x, shape.max_y), (110.0, 80.0));
        assert_eq!(shape.text, "要不要繼續？");
    }

    #[test]
    fn a_shape_survives_a_reopen() {
        // 只活在記憶體裡的話，關掉 App 形狀就沒了。
        let dir = std::env::temp_dir().join(format!("padnote-shape-reopen-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        let path = dir.to_string_lossy().into_owned();
        let (page, id) = {
            let s = PadnoteSession::create(path.clone(), "形狀".into(), 1_757_635_200_000, 0xA1)
                .unwrap();
            let page = s.first_page_id().unwrap();
            let id = s
                .insert_shape(
                    page.clone(),
                    crate::ffi_shapes::FfiShapeKind::Terminator,
                    0.0, 0.0, 100.0, 50.0, 0.0, "開始".into(),
                )
                .unwrap();
            (page, id)
        };

        let reopened = PadnoteSession::open_existing(path, 0xA1).unwrap();
        let shape = reopened.shape_object(page, id).unwrap().expect("重開之後形狀不見了");
        assert_eq!(shape.text, "開始");
        assert_eq!(shape.kind, crate::ffi_shapes::FfiShapeKind::Terminator);
    }

    #[test]
    fn a_shape_can_be_removed() {
        // 插得進去卻刪不掉的話，使用者插錯一個形狀就永遠留在那裡了。
        let (s, page) = session("shape-remove");
        let id = s
            .insert_shape(
                page.clone(),
                crate::ffi_shapes::FfiShapeKind::Process,
                0.0, 0.0, 10.0, 10.0, 0.0, String::new(),
            )
            .unwrap();
        s.remove_object(id.clone()).unwrap();

        assert!(s.shape_object(page.clone(), id).unwrap().is_none());
        assert!(s.root_objects(page).unwrap().is_empty());
    }

    #[test]
    fn a_connection_can_be_read_back() {
        // 讀不回來的話，換一台裝置打開，流程圖就只剩一堆沒有線連起來的方塊。
        let (s, page) = session("connection-read-back");
        let from = s
            .insert_shape(page.clone(), crate::ffi_shapes::FfiShapeKind::Terminator,
                          0.0, 0.0, 100.0, 50.0, 0.0, "開始".into())
            .unwrap();
        let to = s
            .insert_shape(page.clone(), crate::ffi_shapes::FfiShapeKind::Process,
                          200.0, 0.0, 300.0, 50.0, 0.0, "處理".into())
            .unwrap();
        let link = s
            .insert_connection(
                page.clone(), from.clone(), to.clone(),
                crate::ffi_shapes::FfiAnchor::Right,
                crate::ffi_shapes::FfiAnchor::Left,
                crate::ffi_shapes::FfiRouteStyle::Orthogonal,
                crate::ffi_shapes::FfiEndCap::None,
                crate::ffi_shapes::FfiEndCap::Arrow,
                "是".into(),
            )
            .unwrap();

        let conn = s.connection_object(page, link.clone()).unwrap().expect("連接線讀不回來");
        assert_eq!(conn.object_id, link);
        assert_eq!(conn.from_object_id, from);
        assert_eq!(conn.to_object_id, to);
        assert_eq!(conn.label, "是");
        assert_eq!(conn.route, crate::ffi_shapes::FfiRouteStyle::Orthogonal);
        assert_eq!(conn.end_cap, crate::ffi_shapes::FfiEndCap::Arrow);
    }

    #[test]
    fn a_connection_survives_a_reopen() {
        let dir = std::env::temp_dir().join(format!("padnote-conn-reopen-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        let path = dir.to_string_lossy().into_owned();
        let (page, link, from) = {
            let s = PadnoteSession::create(path.clone(), "連線".into(), 1_757_635_200_000, 0xA1)
                .unwrap();
            let page = s.first_page_id().unwrap();
            let a = s.insert_shape(page.clone(), crate::ffi_shapes::FfiShapeKind::Process,
                                   0.0, 0.0, 10.0, 10.0, 0.0, String::new()).unwrap();
            let b = s.insert_shape(page.clone(), crate::ffi_shapes::FfiShapeKind::Process,
                                   50.0, 0.0, 60.0, 10.0, 0.0, String::new()).unwrap();
            let link = s.insert_connection(
                page.clone(), a.clone(), b,
                crate::ffi_shapes::FfiAnchor::Right, crate::ffi_shapes::FfiAnchor::Left,
                crate::ffi_shapes::FfiRouteStyle::Straight,
                crate::ffi_shapes::FfiEndCap::None, crate::ffi_shapes::FfiEndCap::Arrow,
                "標籤".into()).unwrap();
            (page, link, a)
        };

        let reopened = PadnoteSession::open_existing(path, 0xA1).unwrap();
        let conn = reopened.connection_object(page, link).unwrap().expect("重開之後連線不見了");
        assert_eq!(conn.from_object_id, from);
        assert_eq!(conn.label, "標籤");
    }

    #[test]
    fn a_shape_is_not_a_connection() {
        // 認錯的話，形狀會被當成線畫出來。
        let (s, page) = session("shape-not-connection");
        let shape = s.insert_shape(page.clone(), crate::ffi_shapes::FfiShapeKind::Process,
                                   0.0, 0.0, 10.0, 10.0, 0.0, String::new()).unwrap();
        assert!(s.connection_object(page, shape).unwrap().is_none());
    }

    #[test]
    fn a_stroke_object_is_not_a_shape() {
        // 認錯的話，一組筆畫會被當成形狀畫出來。
        let (s, page) = session("shape-not-a-shape");
        let object = s.create_stroke_object(page.clone(), vec![]).unwrap();
        assert!(s.shape_object(page, object).unwrap().is_none());
    }

    // ── 物件列舉 ────────────────────────────────────────────

    #[test]
    fn objects_are_listed_in_stacking_order() {
        // 拿不到「這一頁有哪些物件」，平台就建不出選取與圖層介面 ——
        // 有堆疊操作卻沒有對象可選，等於還是用不到。
        let (s, page) = session("objects-order");
        let first = s.create_stroke_object(page.clone(), vec![]).unwrap();
        let second = s.create_stroke_object(page.clone(), vec![]).unwrap();

        let objects = s.root_objects(page).unwrap();
        assert_eq!(objects.iter().map(|o| o.id.clone()).collect::<Vec<_>>(), vec![first, second]);
        assert_eq!(objects[0].z_index, 0, "先建立的在底層");
        assert_eq!(objects[1].z_index, 1);
    }

    #[test]
    fn reordering_shows_up_in_the_listing() {
        // 列出來的順序跟實際畫出來的不一樣，圖層介面就是錯的。
        let (s, page) = session("objects-reorder");
        let bottom = s.create_stroke_object(page.clone(), vec![]).unwrap();
        let top = s.create_stroke_object(page.clone(), vec![]).unwrap();
        s.bring_to_front(page.clone(), bottom.clone()).unwrap();

        let ids: Vec<String> = s.root_objects(page).unwrap().iter().map(|o| o.id.clone()).collect();
        assert_eq!(ids, vec![top, bottom]);
    }

    #[test]
    fn a_group_reports_its_members() {
        // 成員拿不到的話，介面畫不出「這個群組裡有什麼」，也無從解散。
        let (s, page) = session("objects-group");
        let a = s.create_stroke_object(page.clone(), vec![]).unwrap();
        let b = s.create_stroke_object(page.clone(), vec![]).unwrap();
        let group = s.group_objects(page.clone(), vec![a.clone(), b.clone()]).unwrap();

        let objects = s.root_objects(page).unwrap();
        assert_eq!(objects.len(), 1, "群組之後最上層只剩一個物件");
        assert_eq!(objects[0].id, group);
        assert_eq!(objects[0].kind, super::FfiObjectKind::Group);
        assert_eq!(objects[0].members, vec![a, b]);
    }

    #[test]
    fn ungrouping_puts_the_members_back_on_top_level() {
        let (s, page) = session("objects-ungroup");
        let a = s.create_stroke_object(page.clone(), vec![]).unwrap();
        let b = s.create_stroke_object(page.clone(), vec![]).unwrap();
        let group = s.group_objects(page.clone(), vec![a, b]).unwrap();
        s.ungroup(group).unwrap();

        assert_eq!(s.root_objects(page).unwrap().len(), 2);
    }

    #[test]
    fn setting_an_absolute_z_index_reorders_the_page() {
        // 帶絕對索引而不是「上移一層」：相對操作在併發下會疊加，
        // 兩台裝置各按一次「移到最上層」會得出誰也沒預期的順序。
        let (s, page) = session("z-index-absolute");
        let bottom = s.create_stroke_object(page.clone(), vec![]).unwrap();
        let middle = s.create_stroke_object(page.clone(), vec![]).unwrap();
        let top = s.create_stroke_object(page.clone(), vec![]).unwrap();

        // 把最底下那個直接指到最上層。
        s.set_object_z_index(bottom.clone(), 2).unwrap();

        let ids: Vec<String> = s.root_objects(page).unwrap().iter().map(|o| o.id.clone()).collect();
        assert_eq!(ids, vec![middle, top, bottom]);
    }

    #[test]
    fn an_out_of_range_z_index_is_clamped_not_rejected() {
        // 讀取端必須把越界索引夾到合法範圍，不得拒絕整份 oplog
        // （format-spec §6.2）。整批重排時很容易帶到超出範圍的值。
        let (s, page) = session("z-index-clamp");
        let a = s.create_stroke_object(page.clone(), vec![]).unwrap();
        s.create_stroke_object(page.clone(), vec![]).unwrap();

        s.set_object_z_index(a.clone(), 99).unwrap();

        let ids: Vec<String> = s.root_objects(page).unwrap().iter().map(|o| o.id.clone()).collect();
        assert_eq!(ids.len(), 2, "物件不該因為越界索引而消失");
        assert_eq!(ids[1], a, "越界的索引要夾到最上層");
    }

    #[test]
    fn a_grouped_member_is_still_reachable_by_id() {
        // root_objects 只回傳根層。群組之後成員就不是根物件了 —— 平台若只看
        // 根層，整組形狀會從畫面上消失，而檔案裡其實好端端地存在。
        let (s, page) = session("object-node");
        let a = s.insert_shape(page.clone(), crate::ffi_shapes::FfiShapeKind::Process,
                               0.0, 0.0, 10.0, 10.0, 0.0, "甲".into()).unwrap();
        let b = s.insert_shape(page.clone(), crate::ffi_shapes::FfiShapeKind::Process,
                               50.0, 0.0, 60.0, 10.0, 0.0, "乙".into()).unwrap();
        let group = s.group_objects(page.clone(), vec![a.clone(), b.clone()]).unwrap();

        // 根層只剩群組
        let roots = s.root_objects(page.clone()).unwrap();
        assert_eq!(roots.len(), 1);
        assert_eq!(roots[0].id, group);
        assert_eq!(roots[0].members, vec![a.clone(), b.clone()]);

        // 成員仍然拿得到
        let member = s.object_node(page.clone(), a.clone()).unwrap().expect("群組成員取不到");
        assert_eq!(member.id, a);
        assert_eq!(member.kind, super::FfiObjectKind::Shape);
        // 而且它的內容也還在
        assert_eq!(s.shape_object(page, a).unwrap().unwrap().text, "甲");
    }

    #[test]
    fn asking_for_an_unknown_object_returns_none() {
        let (s, page) = session("object-node-missing");
        let missing = "01920000-0000-7000-8000-0000000000ff";
        assert!(s.object_node(page, missing.into()).unwrap().is_none());
    }

    #[test]
    fn a_page_with_no_objects_lists_nothing() {
        let (s, page) = session("objects-empty");
        assert!(s.root_objects(page).unwrap().is_empty());
    }
}
