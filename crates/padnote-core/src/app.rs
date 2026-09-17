//! 應用層操作：把 storage / doc / ink / asr / search 串成使用者看得到的行為。
//!
//! 這一層的存在理由是**時序正確性**。例如「開始錄音」必須先落盤音檔、
//! 再建立 session、最後才啟動轉錄 —— 順序錯了就會出現「轉錄成功但音檔沒了」
//! 這種最糟的失敗模式（Notability 的教訓）。

use padnote_doc::{
    Affine2, AudioSession, Block, BlockKind, CellSpan, ConnectionObject, DocOp, Notebook,
    NotebookTime, ObjectNode, ObjectTree, Page, PageTemplate, ShapeObject, TextCrdt, TextEditor,
    TextStyle, Timeline, TranscriptWord, Uuid,
};
use padnote_export::{MarkdownOptions, to_markdown};
use padnote_ink::{InkRecord, Stroke, materialize};
use padnote_recorder::{FeedOutcome, PendingSegment, RecorderError, RecordingPipeline};
use padnote_search::{DocId, SearchIndex, Source};
use padnote_storage::{NotebookPackage, StorageError};
use std::fmt;
use std::fs::File;
use std::io::BufWriter;

#[derive(Debug)]
pub enum AppError {
    Storage(StorageError),
    /// 已在錄音中又要求開始錄音。
    AlreadyRecording,
    NotRecording,
    PageNotFound(Uuid),
    BlockNotFound(Uuid),
    Recorder(RecorderError),
    Export(padnote_export::ExportError),
}

impl fmt::Display for AppError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Storage(e) => write!(f, "{e}"),
            Self::AlreadyRecording => write!(f, "已經在錄音中"),
            Self::NotRecording => write!(f, "目前沒有錄音"),
            Self::PageNotFound(id) => write!(f, "找不到頁面：{id}"),
            Self::BlockNotFound(id) => write!(f, "找不到區塊：{id}"),
            Self::Recorder(e) => write!(f, "{e}"),
            Self::Export(e) => write!(f, "{e}"),
        }
    }
}

impl std::error::Error for AppError {}

impl From<padnote_export::ExportError> for AppError {
    fn from(e: padnote_export::ExportError) -> Self {
        Self::Export(e)
    }
}

impl From<RecorderError> for AppError {
    fn from(e: RecorderError) -> Self {
        Self::Recorder(e)
    }
}

impl From<StorageError> for AppError {
    fn from(e: StorageError) -> Self {
        Self::Storage(e)
    }
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum RecordingState {
    Idle,
    Recording {
        session: Uuid,
        started_at: NotebookTime,
    },
}

/// 一個開啟中的筆記本工作階段。
///
/// 所有變更都會**立即追加到文件 op-log 並落盤**（S-23）。在此之前只有筆畫
/// 會持久化，頁面與區塊關掉 App 就沒了。
#[derive(Debug)]
pub struct NotebookSession {
    package: NotebookPackage,
    notebook: Notebook,
    timeline: Timeline,
    index: SearchIndex,
    recording: RecordingState,
    /// 單調遞增的筆記本時間。由平台層以 monotonic clock 餵入。
    now: NotebookTime,
    /// 本裝置識別碼。進 oplog 檔名，保證兩台裝置永不寫同一個檔。
    device: u32,
    /// Lamport 時戳，決定 oplog 檔名的因果序。
    lamport: u64,
    /// 每個文字區塊的 CRDT 狀態（ADR-0004）。
    texts: std::collections::HashMap<Uuid, TextCrdt>,
    editor: TextEditor,
    /// 錄音中的管線。**不持有 ASR 引擎** —— 轉錄由外部 worker 負責，
    /// 因此轉錄慢或失敗都不可能影響錄音（S-25）。
    pipeline: Option<RecordingPipeline<BufWriter<File>>>,
    /// 本次開啟期間累計寫入的音訊時長。
    ///
    /// 獨立於 `pipeline` 保存 —— 停止錄音後 pipeline 會被取走，
    /// 但 UI 仍需要知道剛剛錄了多久。
    recorded_audio_us: u64,
    /// Silero VAD 模型路徑。未設定時退回能量門檻法。
    vad_model: Option<std::path::PathBuf>,
    /// 每一頁的物件樹（ADR-0010）。群組與變換住在這裡，
    /// **筆畫資料完全不動**。
    objects: std::collections::HashMap<Uuid, ObjectTree>,
}

impl NotebookSession {
    pub fn create(
        root: impl Into<std::path::PathBuf>,
        title: &str,
        now_unix_ms: u64,
        device: u32,
    ) -> Result<Self, AppError> {
        let mut session = Self::create_empty(root, title, now_unix_ms, device)?;
        session.record(vec![DocOp::AddPage {
            id: Uuid::now_v7(),
            template: PageTemplate::Lined,
            index: 0,
        }])?;
        Ok(session)
    }

    /// 建立一本**沒有任何頁**的筆記本。
    ///
    /// # 為什麼需要這個
    ///
    /// `create` 會自動給第一頁，對「開一本新筆記」是對的。但重建套件時
    /// （匯出、同步）頁面必須沿用既有的 id，那個自動產生的頁就成了多餘的 ——
    /// 而「先加一頁、再把它移掉」在多裝置合併時不保證互相抵銷：兩台裝置各自的
    /// Add/Remove 交錯之後，可能留下一頁空白，而且每次同步都再多一頁。
    ///
    /// 不產生它，就沒有需要抵銷的東西。
    pub fn create_empty(
        root: impl Into<std::path::PathBuf>,
        title: &str,
        now_unix_ms: u64,
        device: u32,
    ) -> Result<Self, AppError> {
        // 筆畫檔名要帶 device，兩台裝置才不會寫同一個檔（架構不變式 1）。
        let package = NotebookPackage::create(root, title, now_unix_ms)?.with_device(device);
        let id = Uuid::now_v7();
        let session = Self {
            package,
            notebook: Notebook::new(id, title),
            timeline: Timeline::new(),
            index: SearchIndex::new(),
            recording: RecordingState::Idle,
            now: NotebookTime::ZERO,
            device,
            lamport: 0,
            texts: Default::default(),
            editor: TextEditor::new(device),
            pipeline: None,
            recorded_audio_us: 0,
            vad_model: None,
            objects: Default::default(),
        };
        Ok(session)
    }

    /// 開啟既有筆記本並重播 op-log。
    ///
    /// 重播而非讀快照：op-log 是唯一的事實來源，快照只是最佳化（尚未實作）。
    pub fn open(root: impl Into<std::path::PathBuf>, device: u32) -> Result<Self, AppError> {
        let package = NotebookPackage::open(root)?.with_device(device);
        let title = package.manifest().title.clone();
        let mut session = Self {
            package,
            notebook: Notebook::new(Uuid::now_v7(), title),
            timeline: Timeline::new(),
            index: SearchIndex::new(),
            recording: RecordingState::Idle,
            now: NotebookTime::ZERO,
            device,
            lamport: 0,
            texts: Default::default(),
            editor: TextEditor::new(device),
            pipeline: None,
            recorded_audio_us: 0,
            vad_model: None,
            objects: Default::default(),
        };

        // **計數器要從磁碟接續，不能從 0 重來。**
        //
        // 從 0 重來的話，這一次開啟寫出的第一個操作又叫 `...0001.oplog`，
        // 被 append 進第一次開啟時建立的那個檔 —— 重播時它排在 `...0002`
        // 之前，於是新值先套用、再被舊檔裡的舊值蓋掉。
        //
        // 對「附加」類操作（新增筆畫、插入文字）看不出來，所以這個 bug 藏得很深；
        // 但對**整份取代**類（SetNotebookMeta / SetBlockAppearance /
        // SetBlockPosition）就是靜默的資料回退：使用者改了、也存了，重開卻變回去。
        session.lamport = session.package.max_doc_lamport();

        let ops = session.package.read_doc_ops()?;
        session.replay(&ops);
        Ok(session)
    }

    /// 記錄一批操作：**先落盤、再套用**。
    ///
    /// 順序很重要 —— 先套用再落盤的話，中途當機會讓記憶體與磁碟不一致，
    /// 而使用者看到的是「有效果但沒存到」。
    fn record(&mut self, ops: Vec<DocOp>) -> Result<(), AppError> {
        if ops.is_empty() {
            return Ok(());
        }
        self.lamport += 1;
        self.package
            .append_doc_ops(self.lamport, self.device, &ops)?;
        self.replay(&ops);
        Ok(())
    }

    /// 套用來自其他裝置的操作（同步）。不再落盤 —— 呼叫端負責寫入。
    pub fn apply_remote(&mut self, ops: &[DocOp]) {
        self.replay(ops);
    }

    fn replay(&mut self, ops: &[DocOp]) {
        for op in ops {
            self.apply_one(op);
        }
    }

    fn apply_one(&mut self, op: &DocOp) {
        match op {
            DocOp::SetTitle { title } => self.notebook.title = title.clone(),
            DocOp::SetNotebookMeta { json } => self.notebook.meta = Some(json.clone()),

            DocOp::AddPage {
                id,
                template,
                index,
            } => {
                // 同一個頁 id 只能存在一頁。
                //
                // 兩台裝置同步之後，雙方的 oplog 都可能帶著同一頁的 AddPage
                // （各自建立時都寫了一筆）。不去重的話合併後會變成兩頁 ——
                // 使用者看到的是一本頁數莫名變兩倍的筆記，而且內容各半。
                if self.notebook.page(*id).is_none() {
                    self.notebook
                        .insert_page(*index as usize, Page::new(*id, template.clone()));
                }
            }
            DocOp::RemovePage { id } => {
                self.notebook.remove_page(*id);
                self.index
                    .remove_page(&self.notebook.id.to_string(), &id.to_string());
            }
            DocOp::MovePage { id, index } => {
                // 頁不在（別台裝置刪掉了）就什麼也不做 —— 重播別人的
                // oplog 時這是正常情況，不是錯誤。
                self.notebook.move_page(*id, *index as usize);
            }

            DocOp::AddTextBlock {
                page,
                id,
                style,
                created_at,
            } => {
                self.texts.insert(*id, TextCrdt::new());
                self.add_block_to_page(
                    *page,
                    Block {
                        id: *id,
                        kind: BlockKind::Text {
                            content: String::new(),
                            style: *style,
                        },
                        position: None,
                        appearance: None,
                        created_at: *created_at,
                    },
                );
            }
            DocOp::AddTranscriptBlock {
                page,
                id,
                session,
                text,
                created_at,
            } => {
                self.add_block_to_page(
                    *page,
                    Block {
                        id: *id,
                        kind: BlockKind::Transcript {
                            session: *session,
                            text: text.clone(),
                        },
                        position: None,
                        appearance: None,
                        created_at: *created_at,
                    },
                );
                self.reindex_block(*page, *id, text, Source::Transcript);
            }
            DocOp::AddImageBlock {
                page,
                id,
                blob,
                width,
                height,
                created_at,
            } => {
                self.add_block_to_page(
                    *page,
                    Block {
                        id: *id,
                        kind: BlockKind::Image {
                            blob: blob.clone(),
                            width: *width,
                            height: *height,
                        },
                        position: None,
                        appearance: None,
                        created_at: *created_at,
                    },
                );
            }
            DocOp::AddTableBlock {
                page,
                id,
                rows,
                cols,
                cells,
                header_row,
                created_at,
            } => {
                // 尺寸與內容長度不符時補齊／截斷 —— 遠端 op 不可信，
                // 但丟掉整個表格對使用者來說比補幾格空白更糟。
                let want = (*rows as usize) * (*cols as usize);
                let mut cells = cells.clone();
                cells.resize(want, String::new());
                let text = cells.join(" ");
                self.add_block_to_page(
                    *page,
                    Block {
                        id: *id,
                        kind: BlockKind::Table {
                            rows: *rows,
                            cols: *cols,
                            cells,
                            header_row: *header_row,
                            merged_cells: Vec::new(),
                        },
                        position: None,
                        appearance: None,
                        created_at: *created_at,
                    },
                );
                self.reindex_block(*page, *id, &text, Source::Text);
            }
            DocOp::SetTableCell { id, row, col, text } => {
                if let Some(page) = self.page_of_block(*id)
                    && let Some(b) = self.notebook.page_mut(page).and_then(|p| p.block_mut(*id))
                    && let BlockKind::Table {
                        rows, cols, cells, ..
                    } = &mut b.kind
                    && *row < *rows
                    && *col < *cols
                    && let Some(slot) = cells.get_mut((*row * *cols + *col) as usize)
                {
                    *slot = text.clone();
                    let joined = cells.join(" ");
                    self.reindex_block(page, *id, &joined, Source::Text);
                }
            }
            DocOp::InsertTableRow { id, index, cells } => {
                self.apply_table_row_insert(*id, *index, cells.clone());
            }
            DocOp::DeleteTableRow { id, index } => {
                self.apply_table_row_delete(*id, *index);
            }
            DocOp::InsertTableColumn { id, index, cells } => {
                self.apply_table_column_insert(*id, *index, cells.clone());
            }
            DocOp::DeleteTableColumn { id, index } => {
                self.apply_table_column_delete(*id, *index);
            }
            DocOp::MergeTableCells { id, span } => {
                self.apply_table_merge(*id, span.clone());
            }
            DocOp::UnmergeTableCell { id, row, col } => {
                self.apply_table_unmerge(*id, *row, *col);
            }
            DocOp::AddEmbeddedBlock {
                page,
                id,
                blob,
                format,
                interaction,
                text,
                created_at,
            } => {
                self.add_block_to_page(
                    *page,
                    Block {
                        id: *id,
                        kind: BlockKind::Embedded {
                            blob: blob.clone(),
                            format: format.clone(),
                            interaction: interaction.clone(),
                            text: text.clone(),
                        },
                        position: None,
                        appearance: None,
                        created_at: *created_at,
                    },
                );
                self.reindex_block(*page, *id, text, Source::Text);
            }
            DocOp::RemoveBlock { id } => {
                self.texts.remove(id);
                if let Some(page) = self.page_of_block(*id) {
                    if let Some(p) = self.notebook.page_mut(page) {
                        p.remove_block(*id);
                    }
                    self.index.remove(&DocId::new(
                        &self.notebook.id.to_string(),
                        &page.to_string(),
                        &id.to_string(),
                    ));
                }
            }
            DocOp::SetBlockStyle { id, style } => {
                if let Some(page) = self.page_of_block(*id)
                    && let Some(b) = self.notebook.page_mut(page).and_then(|p| p.block_mut(*id))
                    && let BlockKind::Text { style: s, .. } = &mut b.kind
                {
                    *s = *style;
                }
            }

            DocOp::SetPageSize { id, width, height } => {
                if let Some(page) = self.notebook.page_mut(*id) {
                    page.size = (*width, *height);
                }
            }

            DocOp::SetBlockAppearance { id, json } => {
                if let Some(page) = self.page_of_block(*id)
                    && let Some(b) = self.notebook.page_mut(page).and_then(|p| p.block_mut(*id))
                {
                    b.appearance = Some(json.clone());
                }
            }

            DocOp::SetBlockPosition { id, x, y } => {
                if let Some(page) = self.page_of_block(*id)
                    && let Some(b) = self.notebook.page_mut(page).and_then(|p| p.block_mut(*id))
                {
                    b.position = Some((*x, *y));
                }
            }

            DocOp::TextEdit { block, op } => {
                // 讓本地時鐘追上遠端，避免重連後產生撞號的 OpId。
                self.editor.observe(op.id());
                let crdt = self.texts.entry(*block).or_default();
                crdt.apply(op.clone());
                let text = crdt.text();
                self.sync_text_block(*block, text);
            }

            DocOp::StartAudio {
                id,
                started_at,
                media_path,
            } => {
                self.timeline.add_session(AudioSession {
                    id: *id,
                    started_at: *started_at,
                    ended_at: None,
                    media_path: media_path.clone(),
                });
                self.recording = RecordingState::Recording {
                    session: *id,
                    started_at: *started_at,
                };
            }
            DocOp::EndAudio { id, ended_at } => {
                self.close_session(*id, *ended_at);
                self.recording = RecordingState::Idle;
            }
            DocOp::AddObject {
                page,
                id,
                kind,
                transform,
            } => {
                let tree = self.objects.entry(*page).or_default();
                tree.insert(ObjectNode {
                    id: *id,
                    kind: kind.clone(),
                    transform: *transform,
                });
            }
            DocOp::AddShapeObject {
                page,
                id,
                shape,
                transform,
            } => {
                let tree = self.objects.entry(*page).or_default();
                tree.insert(ObjectNode {
                    id: *id,
                    kind: padnote_doc::ObjectKind::Shape(shape.clone()),
                    transform: *transform,
                });
            }
            DocOp::AddConnectionObject {
                page,
                id,
                connection,
                transform,
            } => {
                let tree = self.objects.entry(*page).or_default();
                tree.insert(ObjectNode {
                    id: *id,
                    kind: padnote_doc::ObjectKind::Connection(connection.clone()),
                    transform: *transform,
                });
            }
            DocOp::RemoveObject { id } => {
                for tree in self.objects.values_mut() {
                    tree.remove(*id);
                }
            }
            DocOp::SetZIndex { id, index } => {
                for tree in self.objects.values_mut() {
                    // 索引可能來自物件更多的較新版本；set_z_index 自己會夾住上界。
                    let _ = tree.set_z_index(*id, *index as usize);
                }
            }
            DocOp::SetObjectTransform { id, transform } => {
                for tree in self.objects.values_mut() {
                    let _ = tree.set_transform(*id, *transform);
                }
            }
            DocOp::Group {
                page,
                group_id,
                members,
            } => {
                // 重播時忽略失敗：成員可能已被刪除，或來源是較新的版本。
                // 靜默忽略比中斷整個重播好 —— 使用者寧可少一個群組，
                // 也不要整本筆記打不開。
                let _ = self
                    .objects
                    .entry(*page)
                    .or_default()
                    .group(*group_id, members);
            }
            DocOp::Ungroup { id } => {
                for tree in self.objects.values_mut() {
                    let _ = tree.ungroup(*id);
                }
            }
            DocOp::AddWord {
                text,
                start,
                end,
                confidence,
            } => {
                self.timeline.add_word(TranscriptWord {
                    text: text.clone(),
                    start: *start,
                    end: *end,
                    confidence: *confidence,
                });
            }
        }
    }

    fn add_block_to_page(&mut self, page: Uuid, block: Block) {
        if let Some(p) = self.notebook.page_mut(page) {
            p.add_block(block);
        }
    }

    fn page_of_block(&self, block: Uuid) -> Option<Uuid> {
        self.notebook
            .pages()
            .iter()
            .find(|p| p.blocks().iter().any(|b| b.id == block))
            .map(|p| p.id)
    }

    /// 文字 CRDT 變動後，同步區塊內容與搜尋索引。
    fn sync_text_block(&mut self, block: Uuid, text: String) {
        let Some(page) = self.page_of_block(block) else {
            return;
        };
        if let Some(b) = self
            .notebook
            .page_mut(page)
            .and_then(|p| p.block_mut(block))
            && let BlockKind::Text { content, .. } = &mut b.kind
        {
            *content = text.clone();
        }
        self.reindex_block(page, block, &text, Source::Text);
    }

    fn reindex_block(&mut self, page: Uuid, block: Uuid, text: &str, source: Source) {
        let doc = DocId::new(
            &self.notebook.id.to_string(),
            &page.to_string(),
            &block.to_string(),
        );
        if text.is_empty() {
            self.index.remove(&doc);
        } else {
            self.index.insert(doc, source, text);
        }
    }

    fn with_table_mut<R>(
        &mut self,
        id: Uuid,
        f: impl FnOnce(&mut u32, &mut u32, &mut Vec<String>, &mut Vec<CellSpan>) -> R,
    ) -> Option<(Uuid, R)> {
        let page = self.page_of_block(id)?;
        let block = self.notebook.page_mut(page)?.block_mut(id)?;
        let BlockKind::Table {
            rows,
            cols,
            cells,
            merged_cells,
            ..
        } = &mut block.kind
        else {
            return None;
        };
        let out = f(rows, cols, cells, merged_cells);
        Some((page, out))
    }

    fn reindex_table(&mut self, page: Uuid, id: Uuid) {
        let Some(text) = self
            .notebook
            .page(page)
            .and_then(|p| p.blocks().iter().find(|b| b.id == id))
            .and_then(Block::table_text)
        else {
            return;
        };
        self.reindex_block(page, id, &text, Source::Text);
    }

    fn apply_table_row_insert(&mut self, id: Uuid, index: u32, mut incoming: Vec<String>) {
        if let Some((page, ())) = self.with_table_mut(id, |rows, cols, cells, spans| {
            let cols_usize = *cols as usize;
            let at = index.min(*rows);
            incoming.resize(cols_usize, String::new());
            incoming.truncate(cols_usize);
            cells.splice(
                (at as usize * cols_usize)..(at as usize * cols_usize),
                incoming,
            );
            *rows += 1;
            for span in spans {
                if span.row >= at {
                    span.row += 1;
                } else if at < span.row.saturating_add(span.row_span) {
                    span.row_span += 1;
                }
            }
        }) {
            self.reindex_table(page, id);
        }
    }

    fn apply_table_row_delete(&mut self, id: Uuid, index: u32) {
        if let Some((page, ())) = self.with_table_mut(id, |rows, cols, cells, spans| {
            if index >= *rows {
                return;
            }
            let cols_usize = *cols as usize;
            let start = index as usize * cols_usize;
            cells.drain(start..start + cols_usize);
            *rows -= 1;
            spans.retain_mut(|span| {
                if span.row > index {
                    span.row -= 1;
                    true
                } else if index < span.row.saturating_add(span.row_span) {
                    if span.row_span > 1 {
                        span.row_span -= 1;
                        true
                    } else {
                        false
                    }
                } else {
                    true
                }
            });
        }) {
            self.reindex_table(page, id);
        }
    }

    fn apply_table_column_insert(&mut self, id: Uuid, index: u32, mut incoming: Vec<String>) {
        if let Some((page, ())) = self.with_table_mut(id, |rows, cols, cells, spans| {
            let at = index.min(*cols);
            incoming.resize(*rows as usize, String::new());
            incoming.truncate(*rows as usize);
            let old_cols = *cols as usize;
            let new_cols = old_cols + 1;
            let mut next = Vec::with_capacity((*rows as usize) * new_cols);
            // incoming 在上面已 resize + truncate 成剛好 rows 長，可直接迭代。
            for (r, cell) in incoming.iter().enumerate() {
                let row_start = r * old_cols;
                next.extend_from_slice(&cells[row_start..row_start + at as usize]);
                next.push(cell.clone());
                next.extend_from_slice(&cells[row_start + at as usize..row_start + old_cols]);
            }
            *cells = next;
            *cols += 1;
            for span in spans {
                if span.col >= at {
                    span.col += 1;
                } else if at < span.col.saturating_add(span.col_span) {
                    span.col_span += 1;
                }
            }
        }) {
            self.reindex_table(page, id);
        }
    }

    fn apply_table_column_delete(&mut self, id: Uuid, index: u32) {
        if let Some((page, ())) = self.with_table_mut(id, |rows, cols, cells, spans| {
            if index >= *cols {
                return;
            }
            let old_cols = *cols as usize;
            let mut next = Vec::with_capacity((*rows as usize) * old_cols.saturating_sub(1));
            for r in 0..*rows as usize {
                let row_start = r * old_cols;
                for c in 0..old_cols {
                    if c as u32 != index {
                        next.push(cells[row_start + c].clone());
                    }
                }
            }
            *cells = next;
            *cols -= 1;
            spans.retain_mut(|span| {
                if span.col > index {
                    span.col -= 1;
                    true
                } else if index < span.col.saturating_add(span.col_span) {
                    if span.col_span > 1 {
                        span.col_span -= 1;
                        true
                    } else {
                        false
                    }
                } else {
                    true
                }
            });
        }) {
            self.reindex_table(page, id);
        }
    }

    fn apply_table_merge(&mut self, id: Uuid, span: CellSpan) {
        let _ = self.with_table_mut(id, |rows, cols, _, spans| {
            if span.row >= *rows
                || span.col >= *cols
                || span.row_span == 0
                || span.col_span == 0
                || span.row.saturating_add(span.row_span) > *rows
                || span.col.saturating_add(span.col_span) > *cols
            {
                return;
            }
            spans.retain(|s| !(s.row == span.row && s.col == span.col));
            if span.row_span > 1 || span.col_span > 1 {
                spans.push(span);
            }
        });
    }

    fn apply_table_unmerge(&mut self, id: Uuid, row: u32, col: u32) {
        let _ = self.with_table_mut(id, |_, _, _, spans| {
            spans.retain(|s| !(s.row == row && s.col == col));
        });
    }

    fn close_session(&mut self, session: Uuid, at: NotebookTime) {
        let mut rebuilt = Timeline::new();
        for s in self.timeline.sessions() {
            let mut s = s.clone();
            if s.id == session && s.ended_at.is_none() {
                s.ended_at = Some(at);
            }
            rebuilt.add_session(s);
        }
        for w in self
            .timeline
            .words_in(NotebookTime::ZERO, NotebookTime(u64::MAX))
        {
            rebuilt.add_word(w.clone());
        }
        self.timeline = rebuilt;
    }

    pub fn notebook(&self) -> &Notebook {
        &self.notebook
    }

    pub fn timeline(&self) -> &Timeline {
        &self.timeline
    }

    pub fn recording_state(&self) -> RecordingState {
        self.recording
    }

    /// 平台層每次有事件時推進時間軸。**必須單調遞增**。
    pub fn advance_time(&mut self, to: NotebookTime) {
        self.now = self.now.max(to);
    }

    pub fn now(&self) -> NotebookTime {
        self.now
    }

    // ---- 頁面 ----

    pub fn add_page(&mut self, template: PageTemplate) -> Result<Uuid, AppError> {
        let id = Uuid::now_v7();
        let index = self.notebook.page_count() as u32;
        self.record(vec![DocOp::AddPage {
            id,
            template,
            index,
        }])?;
        Ok(id)
    }

    /// 用指定的 id 新增一頁。已經存在同 id 的頁時什麼也不做。
    ///
    /// # 為什麼需要指定 id
    ///
    /// 每次重建筆記本都隨機生一批頁面 id 的話，兩台裝置的頁**永遠不會收斂** ——
    /// 合併之後不是一頁有兩邊的內容，而是變成兩頁，而且每同步一趟就再多一批。
    /// 頁面身分必須跟著筆記走，不是跟著某一次匯出走。
    pub fn add_page_with_id(&mut self, id: Uuid, template: PageTemplate) -> Result<(), AppError> {
        if self.notebook.page(id).is_some() {
            return Ok(());
        }
        let index = self.notebook.page_count() as u32;
        self.record(vec![DocOp::AddPage {
            id,
            template,
            index,
        }])
    }

    pub fn remove_page(&mut self, id: Uuid) -> Result<(), AppError> {
        self.record(vec![DocOp::RemovePage { id }])
    }

    /// 把某一頁搬到 `index`（S-87）。
    ///
    /// 頁不存在就什麼也不做 —— 不記一筆搬動不存在的頁的操作，
    /// 那只會讓別台裝置重播時多做一次無效的工作。
    pub fn move_page(&mut self, id: Uuid, index: u32) -> Result<(), AppError> {
        if self.notebook.page(id).is_none() {
            return Ok(());
        }
        self.record(vec![DocOp::MovePage { id, index }])
    }

    pub fn set_title(&mut self, title: &str) -> Result<(), AppError> {
        self.record(vec![DocOp::SetTitle {
            title: title.to_string(),
        }])
    }

    pub fn first_page(&self) -> Option<Uuid> {
        self.notebook.pages().first().map(|p| p.id)
    }

    // ---- 手寫 ----

    /// 寫入一筆畫。**立即落盤** —— 使用者抬筆那一刻資料就已經安全。
    pub fn add_stroke(&mut self, page: Uuid, mut stroke: Stroke) -> Result<(), AppError> {
        if self.notebook.page(page).is_none() {
            return Err(AppError::PageNotFound(page));
        }
        stroke.started_at = self.now;
        self.package.append_ink(page, &[InkRecord::Add(stroke)])?;
        Ok(())
    }

    /// 擦除。追加墓碑而非刪除位元組（ADR-0002）。
    pub fn erase_stroke(&mut self, page: Uuid, stroke: Uuid) -> Result<(), AppError> {
        self.package
            .append_ink(page, &[InkRecord::Remove(stroke)])?;
        Ok(())
    }

    pub fn visible_strokes(&self, page: Uuid) -> Result<Vec<Stroke>, AppError> {
        Ok(materialize(&self.package.read_ink(page)?))
    }

    // ---- 文字 ----

    /// 建立文字區塊。內容透過 CRDT 操作寫入，因此一開始就是可協同編輯的。
    pub fn add_text_block(
        &mut self,
        page: Uuid,
        content: &str,
        style: TextStyle,
    ) -> Result<Uuid, AppError> {
        if self.notebook.page(page).is_none() {
            return Err(AppError::PageNotFound(page));
        }
        let id = Uuid::now_v7();
        let mut ops = vec![DocOp::AddTextBlock {
            page,
            id,
            style,
            created_at: self.now,
        }];

        if !content.is_empty() {
            let empty = TextCrdt::new();
            ops.extend(
                self.editor
                    .insert(&empty, 0, content)
                    .into_iter()
                    .map(|op| DocOp::TextEdit { block: id, op }),
            );
        }
        self.record(ops)?;
        Ok(id)
    }

    /// 在文字區塊的第 `index` 個字元位置插入文字。
    pub fn insert_text(&mut self, block: Uuid, index: usize, s: &str) -> Result<(), AppError> {
        let crdt = self
            .texts
            .get(&block)
            .ok_or(AppError::BlockNotFound(block))?;
        let ops = self.editor.insert(crdt, index, s);
        self.record(
            ops.into_iter()
                .map(|op| DocOp::TextEdit { block, op })
                .collect(),
        )
    }

    /// 刪除文字區塊中從 `index` 起的 `count` 個字元。
    pub fn delete_text(&mut self, block: Uuid, index: usize, count: usize) -> Result<(), AppError> {
        let crdt = self
            .texts
            .get(&block)
            .ok_or(AppError::BlockNotFound(block))?;
        let ops = self.editor.delete(crdt, index, count);
        self.record(
            ops.into_iter()
                .map(|op| DocOp::TextEdit { block, op })
                .collect(),
        )
    }

    pub fn block_text(&self, block: Uuid) -> Option<String> {
        self.texts.get(&block).map(TextCrdt::text)
    }

    pub fn set_block_style(&mut self, block: Uuid, style: TextStyle) -> Result<(), AppError> {
        self.record(vec![DocOp::SetBlockStyle { id: block, style }])
    }

    /// 設定頁面尺寸（點）。長畫布就是靠這個落盤的。
    pub fn set_page_size(&mut self, page: Uuid, width: f32, height: f32) -> Result<(), AppError> {
        if self.notebook.page(page).is_none() {
            return Err(AppError::PageNotFound(page));
        }
        self.record(vec![DocOp::SetPageSize {
            id: page,
            width,
            height,
        }])
    }

    /// 設定區塊的外觀（平台自訂的 JSON）。
    ///
    /// 核心不解讀內容 —— 它只確保這些值跨得過平台與重開。
    pub fn set_block_appearance(&mut self, block: Uuid, json: &str) -> Result<(), AppError> {
        if self.page_of_block(block).is_none() {
            return Err(AppError::BlockNotFound(block));
        }
        self.record(vec![DocOp::SetBlockAppearance {
            id: block,
            json: json.to_string(),
        }])
    }

    /// 設定筆記本層級的平台中繼資料（平台自訂的 JSON）。
    ///
    /// 核心不解讀內容。語意是整份取代 —— 合併不是核心的工作，因為核心看不懂內容。
    pub fn set_notebook_meta(&mut self, json: &str) -> Result<(), AppError> {
        self.record(vec![DocOp::SetNotebookMeta {
            json: json.to_string(),
        }])
    }

    /// 設定區塊在頁面上的絕對座標。
    pub fn set_block_position(&mut self, block: Uuid, x: f32, y: f32) -> Result<(), AppError> {
        if self.page_of_block(block).is_none() {
            return Err(AppError::BlockNotFound(block));
        }
        self.record(vec![DocOp::SetBlockPosition { id: block, x, y }])
    }

    pub fn remove_block(&mut self, block: Uuid) -> Result<(), AppError> {
        self.record(vec![DocOp::RemoveBlock { id: block }])
    }

    /// 插入圖片。`blob` 為內容定址雜湊（由 `package().blobs().put()` 取得）。
    pub fn add_image_block(
        &mut self,
        page: Uuid,
        blob: &str,
        width: f32,
        height: f32,
    ) -> Result<Uuid, AppError> {
        if self.notebook.page(page).is_none() {
            return Err(AppError::PageNotFound(page));
        }
        let id = Uuid::now_v7();
        self.record(vec![DocOp::AddImageBlock {
            page,
            id,
            blob: blob.to_string(),
            width,
            height,
            created_at: self.now,
        }])?;
        Ok(id)
    }

    // ---- 錄音 ----

    /// 開始錄音。
    ///
    /// 音檔路徑先確定並建立 session，**再**由平台層開始寫入音訊 ——
    /// 順序顛倒會讓當機時出現「有轉錄但沒音檔」。
    pub fn start_recording(&mut self) -> Result<Uuid, AppError> {
        if matches!(self.recording, RecordingState::Recording { .. }) {
            return Err(AppError::AlreadyRecording);
        }
        let session = Uuid::now_v7();
        let media_path = format!("media/audio/{session}.opus");

        // 音檔路徑先建立、檔案先開好，**再**記錄 session。
        // 顛倒的話，當機時會留下「有 session 記錄但沒有音檔」的孤兒。
        let full = self.package.root().join(&media_path);
        if let Some(parent) = full.parent() {
            std::fs::create_dir_all(parent).map_err(|e| AppError::Storage(StorageError::Io(e)))?;
        }
        let file = File::create(&full).map_err(|e| AppError::Storage(StorageError::Io(e)))?;

        self.pipeline = Some(RecordingPipeline::new(
            BufWriter::new(file),
            session,
            self.now,
            self.build_vad(),
        )?);

        self.record(vec![DocOp::StartAudio {
            id: session,
            started_at: self.now,
            media_path,
        }])?;
        Ok(session)
    }

    /// 設定 Silero VAD 模型（S-26）。未設定時退回能量門檻法。
    ///
    /// 模型由 `padnote-models` 的下載器取得。設定後於**下一次**開始錄音時生效。
    pub fn set_vad_model(&mut self, path: impl Into<std::path::PathBuf>) {
        self.vad_model = Some(path.into());
    }

    /// 目前是否會使用 Silero VAD。
    ///
    /// `false` 代表退回能量門檻法 —— **有背景噪音時會把冷氣聲當成語音**，
    /// UI 應該讓使用者知道轉錄分段品質會下降。
    pub fn uses_neural_vad(&self) -> bool {
        self.vad_model.as_ref().is_some_and(|p| p.exists())
    }

    /// 建立 VAD。模型缺失或載入失敗時**降級而非失敗** ——
    /// 錄音本身不該因為 VAD 用不了就停擺（S-25 的音檔優先原則）。
    fn build_vad(&self) -> Box<dyn padnote_asr::VoiceActivityDetector> {
        // `asr` feature 關閉時（Android 第一版）沒有 Silero，
        // 直接用內建的能量式 VAD —— 錄音本身照常運作，只是分段較粗。
        #[cfg(feature = "asr")]
        if let Some(path) = &self.vad_model
            && let Ok(vad) = padnote_vad_silero::SileroVad::load(path)
        {
            return Box::new(vad);
        }
        Box::new(padnote_recorder::default_vad())
    }

    /// 餵入麥克風取樣。
    ///
    /// **音檔在此同步落地**；轉錄只是把語音段放進佇列，由外部 worker 取用。
    /// 因此轉錄再慢也不會拖累錄音（S-25）。
    pub fn feed_audio(&mut self, pcm_16k_mono: &[f32]) -> Result<FeedOutcome, AppError> {
        let Some(p) = self.pipeline.as_mut() else {
            return Err(AppError::NotRecording);
        };
        Ok(p.feed(pcm_16k_mono)?)
    }

    /// 取出待轉錄的語音段，交給背景 worker。
    pub fn take_pending_segments(&mut self) -> Vec<PendingSegment> {
        self.pipeline
            .as_mut()
            .map(RecordingPipeline::take_segments)
            .unwrap_or_default()
    }

    /// 轉錄落後的音訊時長。UI 顯示「轉錄落後 N 秒」。
    pub fn transcription_backlog_us(&self) -> u64 {
        self.pipeline
            .as_ref()
            .map_or(0, RecordingPipeline::backlog_us)
    }

    /// 已寫入音檔的時長。與 `timeline()` 的 session 長度不同 ——
    /// 這個反映的是**實際落盤**的音訊，停止錄音後仍然可查。
    pub fn recorded_audio_us(&self) -> u64 {
        self.recorded_audio_us
            + self
                .pipeline
                .as_ref()
                .map_or(0, RecordingPipeline::recorded_duration_us)
    }

    pub fn stop_recording(&mut self) -> Result<Uuid, AppError> {
        let RecordingState::Recording { session, .. } = self.recording else {
            return Err(AppError::NotRecording);
        };
        // 先沖出音檔的殘餘與 Ogg 結尾頁，再記錄結束事件。
        if let Some(mut p) = self.pipeline.take() {
            p.finish()?;
            self.recorded_audio_us += p.recorded_duration_us();
        }
        self.record(vec![DocOp::EndAudio {
            id: session,
            ended_at: self.now,
        }])?;
        Ok(session)
    }

    /// 寫入一段轉錄結果。時間戳已在筆記本時間軸上。
    pub fn add_transcript(
        &mut self,
        page: Uuid,
        session: Uuid,
        words: Vec<TranscriptWord>,
    ) -> Result<Uuid, AppError> {
        if self.notebook.page(page).is_none() {
            return Err(AppError::PageNotFound(page));
        }
        let text: String = words.iter().map(|w| w.text.as_str()).collect();
        let id = Uuid::now_v7();

        let mut ops = vec![DocOp::AddTranscriptBlock {
            page,
            id,
            session,
            text,
            created_at: self.now,
        }];
        ops.extend(words.into_iter().map(|w| DocOp::AddWord {
            text: w.text,
            start: w.start,
            end: w.end,
            confidence: w.confidence,
        }));

        self.record(ops)?;
        Ok(id)
    }

    /// **功能 C1**：點一筆畫，跳回當時的錄音位置。
    pub fn playback_for_stroke(&self, stroke: &Stroke) -> Option<(String, NotebookTime)> {
        self.timeline
            .playback_at(stroke.started_at)
            .map(|(s, offset)| (s.media_path.clone(), offset))
    }

    // ---- 搜尋與匯出 ----

    pub fn search(&self, query: &str, limit: usize) -> Vec<padnote_search::Hit> {
        self.index.search(query, limit)
    }

    /// 索引手寫辨識結果（功能 D3）。辨識是非同步的，所以獨立於 `add_stroke`。
    pub fn index_handwriting(&mut self, page: Uuid, stroke: Uuid, text: &str) {
        self.index.insert(
            DocId::new(
                &self.notebook.id.to_string(),
                &page.to_string(),
                &stroke.to_string(),
            ),
            Source::Handwriting,
            text,
        );
    }

    // ---- 物件（ADR-0010）----

    /// 某一頁的物件樹。
    pub fn objects(&self, page: Uuid) -> Option<&ObjectTree> {
        self.objects.get(&page)
    }

    pub fn object(&self, page: Uuid, id: Uuid) -> Option<&ObjectNode> {
        self.objects.get(&page)?.get(id)
    }

    /// 把筆畫收成一個物件，讓它能被群組與變換。
    pub fn create_stroke_object(
        &mut self,
        page: Uuid,
        strokes: Vec<Uuid>,
    ) -> Result<Uuid, AppError> {
        if self.notebook.page(page).is_none() {
            return Err(AppError::PageNotFound(page));
        }
        let id = Uuid::now_v7();
        self.record(vec![DocOp::AddObject {
            page,
            id,
            kind: padnote_doc::ObjectKind::Strokes(strokes),
            transform: Affine2::IDENTITY,
        }])?;
        Ok(id)
    }

    pub fn insert_shape(&mut self, page: Uuid, shape: ShapeObject) -> Result<Uuid, AppError> {
        if self.notebook.page(page).is_none() {
            return Err(AppError::PageNotFound(page));
        }
        let id = Uuid::now_v7();
        self.record(vec![DocOp::AddShapeObject {
            page,
            id,
            shape,
            transform: Affine2::IDENTITY,
        }])?;
        Ok(id)
    }

    pub fn insert_connection(
        &mut self,
        page: Uuid,
        connection: ConnectionObject,
    ) -> Result<Uuid, AppError> {
        if self.notebook.page(page).is_none() {
            return Err(AppError::PageNotFound(page));
        }
        let has_endpoint = |id| {
            self.objects
                .get(&page)
                .is_some_and(|tree| tree.get(id).is_some())
        };
        if !has_endpoint(connection.from) || !has_endpoint(connection.to) {
            return Err(AppError::BlockNotFound(connection.from));
        }
        let id = Uuid::now_v7();
        self.record(vec![DocOp::AddConnectionObject {
            page,
            id,
            connection,
            transform: Affine2::IDENTITY,
        }])?;
        Ok(id)
    }

    /// 群組多個物件。
    pub fn group_objects(&mut self, page: Uuid, members: Vec<Uuid>) -> Result<Uuid, AppError> {
        let group_id = Uuid::now_v7();
        self.record(vec![DocOp::Group {
            page,
            group_id,
            members,
        }])?;
        Ok(group_id)
    }

    /// 移除一個物件（形狀、連接線、筆畫物件或群組）。
    ///
    /// 沒有它的話，平台插得進形狀卻刪不掉 —— 使用者插錯一個就永遠留在那裡。
    pub fn remove_object(&mut self, id: Uuid) -> Result<(), AppError> {
        self.record(vec![DocOp::RemoveObject { id }])
    }

    pub fn ungroup(&mut self, id: Uuid) -> Result<(), AppError> {
        self.record(vec![DocOp::Ungroup { id }])
    }

    /// 把物件移到同層內的某個位置（需求 1）。
    pub fn set_z_index(&mut self, id: Uuid, index: usize) -> Result<(), AppError> {
        self.record(vec![DocOp::SetZIndex {
            id,
            index: index as u32,
        }])
    }

    /// 移到同層最上層。
    ///
    /// 目標索引在**這裡**算好再記錄，而不是記「移到最上層」——
    /// 詳見 `DocOp::SetZIndex` 的說明。
    pub fn bring_to_front(&mut self, page: Uuid, id: Uuid) -> Result<(), AppError> {
        let last = self.sibling_count(page, id).saturating_sub(1);
        self.set_z_index(id, last)
    }

    /// 移到同層最下層。
    pub fn send_to_back(&mut self, id: Uuid) -> Result<(), AppError> {
        self.set_z_index(id, 0)
    }

    /// 上移一層。
    pub fn bring_forward(&mut self, page: Uuid, id: Uuid) -> Result<(), AppError> {
        let now = self.z_index(page, id).ok_or(AppError::BlockNotFound(id))?;
        let last = self.sibling_count(page, id).saturating_sub(1);
        self.set_z_index(id, (now + 1).min(last))
    }

    /// 下移一層。
    pub fn send_backward(&mut self, page: Uuid, id: Uuid) -> Result<(), AppError> {
        let now = self.z_index(page, id).ok_or(AppError::BlockNotFound(id))?;
        self.set_z_index(id, now.saturating_sub(1))
    }

    /// 物件在同層中的位置。
    pub fn z_index(&self, page: Uuid, id: Uuid) -> Option<usize> {
        self.objects.get(&page)?.z_index(id)
    }

    fn sibling_count(&self, page: Uuid, id: Uuid) -> usize {
        self.objects.get(&page).map_or(0, |t| t.sibling_count(id))
    }

    /// 變更物件的變換。**不改寫任何取樣點**（ADR-0010）。
    pub fn transform_object(&mut self, id: Uuid, transform: Affine2) -> Result<(), AppError> {
        self.record(vec![DocOp::SetObjectTransform { id, transform }])
    }

    // ---- 匯入（S-39 / ADR-0008 第二層）----

    /// 匯入一份解析好的文件。
    ///
    /// 每個分頁符開一頁。**不覆蓋現有內容** —— 匯入是「加進來」不是「取代」，
    /// 使用者按錯不該弄丟既有筆記。
    pub fn import_document(
        &mut self,
        doc: &padnote_export::ImportedDocument,
    ) -> Result<Vec<Uuid>, AppError> {
        use padnote_export::ImportedBlock;

        if !doc.title.is_empty() && self.notebook.title.is_empty() {
            self.set_title(&doc.title)?;
        }

        let mut pages = Vec::new();
        let mut current = self.add_page(PageTemplate::Blank)?;
        pages.push(current);

        for block in &doc.blocks {
            match block {
                ImportedBlock::PageBreak => {
                    current = self.add_page(PageTemplate::Blank)?;
                    pages.push(current);
                }
                ImportedBlock::Text { content, style } => {
                    self.add_text_block(current, content, *style)?;
                }
                ImportedBlock::Image { source, .. } => {
                    // 圖片內容由呼叫端先放進 blob store；這裡只記引用。
                    self.add_image_block(current, source, 0.0, 0.0)?;
                }
            }
        }
        Ok(pages)
    }

    /// 匯入 Markdown。
    pub fn import_markdown(&mut self, text: &str) -> Result<Vec<Uuid>, AppError> {
        let doc = padnote_export::from_markdown(text);
        self.import_document(&doc)
    }

    /// 匯入 JSON。
    pub fn import_json(&mut self, text: &str) -> Result<Vec<Uuid>, AppError> {
        let doc = padnote_export::from_json(text)
            .map_err(|e| AppError::Storage(StorageError::MalformedManifest(e)))?;
        self.import_document(&doc)
    }

    // ---- 嵌入文件（S-41 / ADR-0009）----

    /// 匯入外部文件到指定頁面。
    ///
    /// 依 ADR-0009 的互動層級決定行為：
    /// - **可編輯格式**（docx／xlsx／md／json）→ 解析成**原生區塊**，
    ///   使用者能像自己打的字一樣編輯、搜尋、同步
    /// - **僅預覽格式**（pptx／pdf）→ 建立嵌入區塊，由平台原生元件渲染
    ///
    /// **原始檔一律存進 blob** —— 解析必然失真，使用者要能拿回原本的東西。
    pub fn import_embedded(
        &mut self,
        page: Uuid,
        path: impl AsRef<std::path::Path>,
    ) -> Result<Uuid, AppError> {
        use padnote_embed::{EmbedFormat, Interaction};

        let path = path.as_ref();
        if self.notebook.page(page).is_none() {
            return Err(AppError::PageNotFound(page));
        }
        let format = EmbedFormat::from_path(path).ok_or_else(|| {
            AppError::Storage(StorageError::MalformedManifest(format!(
                "不支援的格式：{}",
                path.display()
            )))
        })?;

        // 原檔先落地。解析失敗也要留著。
        let bytes = std::fs::read(path).map_err(|e| AppError::Storage(StorageError::Io(e)))?;
        let blob = self
            .package
            .blobs()
            .put(&bytes)
            .map_err(|e| AppError::Storage(StorageError::MalformedManifest(e.to_string())))?
            .to_string();

        let (interaction, text) = self.extract_embedded(format, path, &bytes)?;

        let id = Uuid::now_v7();
        self.record(vec![DocOp::AddEmbeddedBlock {
            page,
            id,
            blob,
            format: format!("{format:?}").to_lowercase(),
            interaction: match interaction {
                Interaction::Preview => "preview",
                Interaction::Editable => "editable",
                Interaction::Linked => "linked",
            }
            .to_string(),
            text,
            created_at: self.now,
        }])?;

        // 可編輯格式另外拆成原生區塊，讓它真的能編輯。
        if format.is_editable() {
            self.expand_editable(page, format, path, &bytes)?;
        }
        Ok(id)
    }

    /// 取出供搜尋與離線顯示的純文字快照。
    fn extract_embedded(
        &self,
        format: padnote_embed::EmbedFormat,
        path: &std::path::Path,
        bytes: &[u8],
    ) -> Result<(padnote_embed::Interaction, String), AppError> {
        use padnote_embed::EmbedFormat;

        let text = match format {
            EmbedFormat::Docx => padnote_embed::import_docx_bytes(bytes)
                .map(|d| {
                    std::iter::once(d.title.clone())
                        .chain(d.blocks.iter().filter_map(|b| match b {
                            padnote_export::ImportedBlock::Text { content, .. } => {
                                Some(content.clone())
                            }
                            _ => None,
                        }))
                        .collect::<Vec<_>>()
                        .join("\n")
                })
                .unwrap_or_default(),
            EmbedFormat::Xlsx => padnote_embed::import_xlsx(path)
                .map(|sheets| {
                    sheets
                        .iter()
                        .map(padnote_embed::Sheet::to_markdown)
                        .collect::<Vec<_>>()
                        .join("\n")
                })
                .unwrap_or_default(),
            // 只知道張數；內容由平台原生元件渲染。
            EmbedFormat::Pptx => padnote_embed::import_pptx(path)
                .map(|d| format!("簡報（{} 張投影片）", d.slide_count))
                .unwrap_or_else(|e| format!("簡報（無法讀取：{e}）")),
            EmbedFormat::Markdown => String::from_utf8_lossy(bytes).into_owned(),
            EmbedFormat::Json | EmbedFormat::Pdf => String::new(),
        };
        Ok((format.default_interaction(), text))
    }

    /// 把可編輯格式拆成原生區塊。
    fn expand_editable(
        &mut self,
        page: Uuid,
        format: padnote_embed::EmbedFormat,
        path: &std::path::Path,
        bytes: &[u8],
    ) -> Result<(), AppError> {
        use padnote_embed::EmbedFormat;

        match format {
            EmbedFormat::Docx => {
                if let Ok(doc) = padnote_embed::import_docx_bytes(bytes) {
                    self.append_imported_blocks(page, &doc)?;
                }
            }
            EmbedFormat::Xlsx => {
                // 試算表展開成畫布上的表格物件（需求 2）—— 每格都能編輯、
                // 整塊都能搬動。編輯儲存格會取代公式：要編輯公式就得實作
                // 公式引擎，那是另一個產品。
                if let Ok(sheets) = padnote_embed::import_xlsx(path) {
                    for sheet in sheets {
                        self.add_text_block(page, &sheet.name, TextStyle::Heading3)?;
                        self.add_sheet_as_table(page, &sheet)?;
                    }
                }
            }
            EmbedFormat::Markdown => {
                let doc = padnote_export::from_markdown(&String::from_utf8_lossy(bytes));
                self.append_imported_blocks(page, &doc)?;
            }
            EmbedFormat::Json => {
                if let Ok(doc) = padnote_export::from_json(&String::from_utf8_lossy(bytes)) {
                    self.append_imported_blocks(page, &doc)?;
                }
            }
            EmbedFormat::Pptx | EmbedFormat::Pdf => {}
        }
        Ok(())
    }

    /// 把一張工作表變成畫布上的表格物件。
    fn add_sheet_as_table(
        &mut self,
        page: Uuid,
        sheet: &padnote_embed::Sheet,
    ) -> Result<Uuid, AppError> {
        let rows = sheet.row_count();
        let cols = sheet.column_count();
        // 列長不齊的工作表要補成矩形，否則索引會錯位。
        let mut cells = Vec::with_capacity(rows * cols);
        for r in 0..rows {
            for c in 0..cols {
                cells.push(
                    sheet
                        .cell(r, c)
                        .map(|x| x.value.display())
                        .unwrap_or_default(),
                );
            }
        }
        // 第一列全是文字時視為表頭 —— 這是試算表最常見的慣例。
        let header_row = rows > 1
            && (0..cols).all(|c| {
                matches!(
                    sheet.cell(0, c).map(|x| &x.value),
                    Some(padnote_embed::CellValue::Text(_)) | None
                )
            });
        self.insert_table(page, rows as u32, cols as u32, cells, header_row)
    }

    /// 在頁面上插入表格（需求 2：試算表圖形可嵌入且可編輯）。
    pub fn insert_table(
        &mut self,
        page: Uuid,
        rows: u32,
        cols: u32,
        cells: Vec<String>,
        header_row: bool,
    ) -> Result<Uuid, AppError> {
        if self.notebook.page(page).is_none() {
            return Err(AppError::PageNotFound(page));
        }
        let mut cells = cells;
        cells.resize((rows as usize) * (cols as usize), String::new());
        let id = Uuid::now_v7();
        self.record(vec![DocOp::AddTableBlock {
            page,
            id,
            rows,
            cols,
            cells,
            header_row,
            created_at: self.now,
        }])?;
        Ok(id)
    }

    /// 改寫單一儲存格。越界索引回傳錯誤而非靜默忽略 ——
    /// 呼叫端該知道自己寫進了黑洞。
    pub fn set_table_cell(
        &mut self,
        block: Uuid,
        row: u32,
        col: u32,
        text: &str,
    ) -> Result<(), AppError> {
        let ok = self
            .page_of_block(block)
            .and_then(|p| self.notebook.page(p))
            .and_then(|p| p.blocks().iter().find(|b| b.id == block))
            .is_some_and(|b| match b.kind {
                BlockKind::Table { rows, cols, .. } => row < rows && col < cols,
                _ => false,
            });
        if !ok {
            return Err(AppError::BlockNotFound(block));
        }
        self.record(vec![DocOp::SetTableCell {
            id: block,
            row,
            col,
            text: text.to_string(),
        }])
    }

    pub fn insert_table_row(
        &mut self,
        block: Uuid,
        index: u32,
        cells: Vec<String>,
    ) -> Result<(), AppError> {
        let (rows, _) = self.table_dims(block)?;
        if index > rows {
            return Err(AppError::BlockNotFound(block));
        }
        self.record(vec![DocOp::InsertTableRow {
            id: block,
            index,
            cells,
        }])
    }

    pub fn delete_table_row(&mut self, block: Uuid, index: u32) -> Result<(), AppError> {
        let (rows, _) = self.table_dims(block)?;
        if index >= rows {
            return Err(AppError::BlockNotFound(block));
        }
        self.record(vec![DocOp::DeleteTableRow { id: block, index }])
    }

    pub fn insert_table_column(
        &mut self,
        block: Uuid,
        index: u32,
        cells: Vec<String>,
    ) -> Result<(), AppError> {
        let (_, cols) = self.table_dims(block)?;
        if index > cols {
            return Err(AppError::BlockNotFound(block));
        }
        self.record(vec![DocOp::InsertTableColumn {
            id: block,
            index,
            cells,
        }])
    }

    pub fn delete_table_column(&mut self, block: Uuid, index: u32) -> Result<(), AppError> {
        let (_, cols) = self.table_dims(block)?;
        if index >= cols {
            return Err(AppError::BlockNotFound(block));
        }
        self.record(vec![DocOp::DeleteTableColumn { id: block, index }])
    }

    pub fn merge_table_cells(
        &mut self,
        block: Uuid,
        row: u32,
        col: u32,
        row_span: u32,
        col_span: u32,
    ) -> Result<(), AppError> {
        let (rows, cols) = self.table_dims(block)?;
        if row >= rows
            || col >= cols
            || row_span == 0
            || col_span == 0
            || row.saturating_add(row_span) > rows
            || col.saturating_add(col_span) > cols
        {
            return Err(AppError::BlockNotFound(block));
        }
        self.record(vec![DocOp::MergeTableCells {
            id: block,
            span: CellSpan {
                row,
                col,
                row_span,
                col_span,
            },
        }])
    }

    pub fn unmerge_table_cell(&mut self, block: Uuid, row: u32, col: u32) -> Result<(), AppError> {
        self.table_dims(block)?;
        self.record(vec![DocOp::UnmergeTableCell {
            id: block,
            row,
            col,
        }])
    }

    fn table_dims(&self, block: Uuid) -> Result<(u32, u32), AppError> {
        self.page_of_block(block)
            .and_then(|p| self.notebook.page(p))
            .and_then(|p| p.blocks().iter().find(|b| b.id == block))
            .and_then(|b| match b.kind {
                BlockKind::Table { rows, cols, .. } => Some((rows, cols)),
                _ => None,
            })
            .ok_or(AppError::BlockNotFound(block))
    }

    fn append_imported_blocks(
        &mut self,
        page: Uuid,
        doc: &padnote_export::ImportedDocument,
    ) -> Result<(), AppError> {
        use padnote_export::ImportedBlock;

        if !doc.title.is_empty() {
            self.add_text_block(page, &doc.title, TextStyle::Heading1)?;
        }
        for block in &doc.blocks {
            match block {
                ImportedBlock::Text { content, style } => {
                    self.add_text_block(page, content, *style)?;
                }
                ImportedBlock::Image { source, .. } => {
                    self.add_image_block(page, source, 0.0, 0.0)?;
                }
                // 嵌入時不另開新頁 —— 使用者選的是「插進這一頁」。
                ImportedBlock::PageBreak => {}
            }
        }
        Ok(())
    }

    /// 供平台層存取底層套件（例如寫入 blob）。
    pub fn package(&self) -> &NotebookPackage {
        &self.package
    }

    pub fn export_markdown(&self) -> Result<String, AppError> {
        let ink_pages = self.package.ink_pages()?;
        Ok(to_markdown(
            &self.notebook,
            &ink_pages,
            &MarkdownOptions::default(),
        ))
    }

    /// 匯出整份筆記本為 PDF 位元組流（工作項 S-18 / S-43）。
    pub fn export_pdf(
        &self,
        options: &padnote_export::PdfExportOptions,
    ) -> Result<Vec<u8>, AppError> {
        let mut strokes_map = std::collections::HashMap::new();
        for page in self.notebook.pages() {
            if let Ok(strokes) = self.visible_strokes(page.id) {
                strokes_map.insert(page.id, strokes);
            }
        }
        let blobs = self.package.blobs();
        Ok(padnote_export::to_pdf(
            &self.notebook,
            &strokes_map,
            Some(&blobs),
            options,
        )?)
    }

    /// 匯出指定頁面為單頁 PDF 位元組流。
    pub fn export_page_pdf(&self, page_id: Uuid) -> Result<Vec<u8>, AppError> {
        let strokes = self.visible_strokes(page_id)?;
        let blobs = self.package.blobs();
        Ok(padnote_export::page_to_pdf(
            &self.notebook,
            page_id,
            &strokes,
            Some(&blobs),
            &padnote_export::PdfExportOptions::default(),
        )?)
    }

    /// 匯出指定頁面為高解析度 PNG 圖片位元組流（支援 PDFium 向量排版雙軌渲染與自動回退）。
    pub fn export_page_png(&self, page_id: Uuid, scale: f32) -> Result<Vec<u8>, AppError> {
        let page = self
            .notebook
            .page(page_id)
            .ok_or(AppError::PageNotFound(page_id))?;
        let strokes = self.visible_strokes(page_id)?;
        let blobs = self.package.blobs();

        // 第一軌：嘗試使用 PDFium 渲染全頁向量（包含文字排版、表格、圖片與向量筆畫抗鋸齒）
        let pdf_opt = padnote_export::PdfExportOptions {
            include_background_template: true,
            include_annotations: false,
            page_range: None,
            compress_streams: false,
        };
        if let Ok(_pdf_bytes) =
            padnote_export::page_to_pdf(&self.notebook, page_id, &strokes, Some(&blobs), &pdf_opt)
        {
            // `pdf` feature 關閉時（Android 第一版沒有 libpdfium）直接跳過，
            // 由下面的純 Rust 光柵化 fallback 接手。
            #[cfg(feature = "pdf")]
            {
                use padnote_pdf::PdfDocument;
                if let Ok(doc) = padnote_pdf_pdfium::PdfiumDocument::from_bytes(_pdf_bytes, None)
                    && let Ok(rgba) = doc.render(0, scale)
                {
                    let (orig_w, orig_h) = page.size;
                    let target_w = ((orig_w * scale).round() as u32).max(1);
                    let target_h = ((orig_h * scale).round() as u32).max(1);
                    if let Ok(png_bytes) = padnote_export::encode_png(&rgba, target_w, target_h) {
                        return Ok(png_bytes);
                    }
                }
            }
        }

        // 第二軌：純 Rust 幾何抗鋸齒光柵化引擎（零外部相依 fallback）
        let opt = padnote_export::ImageExportOptions {
            scale,
            include_background: true,
        };
        // 形狀與連接線住在物件樹裡，不在 page.blocks() 中 —— 不傳進去的話
        // 縮圖上會少掉整張流程圖（工作項 S-57）。
        Ok(padnote_export::to_png(
            page,
            &strokes,
            Some(&blobs),
            self.objects.get(&page_id),
            &opt,
        )?)
    }

    /// 產出列印專用資料（工作項 S-55）。`page_id` 為 `None` 時列印整份筆記本。
    pub fn print_data(&self, page_id: Option<Uuid>) -> Result<Vec<u8>, AppError> {
        match page_id {
            Some(pid) => self.export_page_pdf(pid),
            None => self.export_pdf(&padnote_export::PdfExportOptions::default()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use padnote_doc::TextStyle;
    use padnote_ink::{InkPoint, Tool};

    fn tmp(name: &str) -> std::path::PathBuf {
        let d = std::env::temp_dir().join(format!("padnote-app-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        d
    }

    fn session(name: &str) -> NotebookSession {
        NotebookSession::create(tmp(name), "線性代數", 1_757_635_200_000, 0xA1).unwrap()
    }

    /// **重開之後改的東西不可以被舊值蓋回去。**
    ///
    /// 這是實際踩到的資料回退：`lamport` 在 `open()` 時被設成 0，於是第二次
    /// 開啟寫出的第一個操作又叫 `...0001.oplog`，被 append 進第一次開啟建立的
    /// 那個檔。重播依檔名字典序，所以新值先套用、再被 `...0002` 裡的舊值蓋掉。
    ///
    /// 症狀：在 Android 上新增討論圖釘，存檔回報成功、當下讀得回來，
    /// 離開再進來就不見了 —— 而磁碟上明明有那筆資料。
    #[test]
    fn edits_made_after_reopening_survive_the_next_reopen() {
        let dir = tmp("lamport-regression");
        let device = 0xA1;

        // 第一次開啟：寫兩次 meta，製造出 0001 與 0002 兩個檔。
        {
            let mut s = NotebookSession::create(&dir, "筆記", 1_757_635_200_000, device).unwrap();
            s.set_notebook_meta(r#"{"v":1}"#).unwrap();
            s.set_notebook_meta(r#"{"v":2}"#).unwrap();
        }

        // 第二次開啟：再寫一次。lamport 沒接續的話，這一筆會被塞進 0001。
        {
            let mut s = NotebookSession::open(&dir, device).unwrap();
            assert_eq!(s.notebook().meta.clone(), Some(r#"{"v":2}"#.to_string()));
            s.set_notebook_meta(r#"{"v":3}"#).unwrap();
            assert_eq!(s.notebook().meta.clone(), Some(r#"{"v":3}"#.to_string()));
        }

        // 第三次開啟：必須看到 v3。看到 v2 就代表新值被舊檔蓋掉了。
        {
            let s = NotebookSession::open(&dir, device).unwrap();
            assert_eq!(
                s.notebook().meta.clone(),
                Some(r#"{"v":3}"#.to_string()),
                "重開之後的修改被舊的 oplog 蓋回去了"
            );
        }
    }

    /// 計數器要從磁碟接續，不可以歸零。
    #[test]
    fn lamport_resumes_from_disk_on_open() {
        let dir = tmp("lamport-resume");
        let device = 0xA1;
        {
            let mut s = NotebookSession::create(&dir, "筆記", 1_757_635_200_000, device).unwrap();
            s.set_notebook_meta(r#"{"a":1}"#).unwrap();
            s.set_notebook_meta(r#"{"a":2}"#).unwrap();
            s.set_notebook_meta(r#"{"a":3}"#).unwrap();
        }
        let s = NotebookSession::open(&dir, device).unwrap();
        assert!(
            s.lamport >= 3,
            "開啟後 lamport 應接續磁碟上的值，實得 {}",
            s.lamport
        );
    }

    /// 同一個頁 id 只能存在一頁。
    ///
    /// 兩台裝置同步之後，雙方的 oplog 都可能帶著同一頁的 `AddPage`（各自建立時
    /// 都寫了一筆）。不去重的話合併後頁數會變兩倍，內容各半 —— 使用者看到的
    /// 是一本莫名多出一堆頁的筆記，而且沒有任何錯誤訊息。
    #[test]
    fn applying_the_same_add_page_twice_yields_one_page() {
        let mut s = session("dedup-add-page");
        let before = s.notebook().page_count();
        let id = Uuid::now_v7();
        let op = DocOp::AddPage {
            id,
            template: PageTemplate::Blank,
            index: 0,
        };
        s.apply_remote(&[op.clone(), op]);
        assert_eq!(s.notebook().page_count(), before + 1);
    }

    /// 去重是依 id，不是依位置 —— 不同 id 的頁當然各自成頁。
    #[test]
    fn different_page_ids_still_create_separate_pages() {
        let mut s = session("dedup-distinct-pages");
        let before = s.notebook().page_count();
        s.apply_remote(&[
            DocOp::AddPage {
                id: Uuid::now_v7(),
                template: PageTemplate::Blank,
                index: 0,
            },
            DocOp::AddPage {
                id: Uuid::now_v7(),
                template: PageTemplate::Blank,
                index: 0,
            },
        ]);
        assert_eq!(s.notebook().page_count(), before + 2);
    }

    fn stroke() -> Stroke {
        Stroke {
            id: Uuid::now_v7(),
            started_at: NotebookTime::ZERO,
            tool: Tool::FountainPen,
            color_rgba8: [0, 0, 0, 255],
            base_width: 2.0,
            points: vec![
                InkPoint::new(0.0, 0.0, 0.5, 0),
                InkPoint::new(10.0, 10.0, 0.8, 8_000),
            ],
        }
    }

    fn word(text: &str, start: u64, end: u64) -> TranscriptWord {
        TranscriptWord {
            text: text.into(),
            start: NotebookTime(start),
            end: NotebookTime(end),
            confidence: 0.95,
        }
    }

    /// 關掉再開，內容必須完整還原。
    fn reopen(session: NotebookSession) -> NotebookSession {
        let root = session.package().root().to_path_buf();
        drop(session);
        NotebookSession::open(root, 0xA1).unwrap()
    }

    #[test]
    fn new_notebook_has_a_first_page() {
        let s = session("new");
        assert_eq!(s.notebook().page_count(), 1);
        assert!(s.first_page().is_some());
    }

    #[test]
    fn strokes_persist_immediately() {
        // 抬筆那一刻資料就該安全 —— 不等任何 flush。
        let mut s = session("persist");
        let page = s.first_page().unwrap();
        s.add_stroke(page, stroke()).unwrap();
        assert_eq!(s.visible_strokes(page).unwrap().len(), 1);
    }

    #[test]
    fn stroke_gets_current_timeline_position() {
        let mut s = session("time");
        let page = s.first_page().unwrap();
        s.advance_time(NotebookTime(5_000_000));
        s.add_stroke(page, stroke()).unwrap();

        assert_eq!(
            s.visible_strokes(page).unwrap()[0].started_at,
            NotebookTime(5_000_000)
        );
    }

    #[test]
    fn erasing_appends_a_tombstone_rather_than_deleting() {
        let mut s = session("erase");
        let page = s.first_page().unwrap();
        let st = stroke();
        let id = st.id;
        s.add_stroke(page, st).unwrap();
        s.erase_stroke(page, id).unwrap();

        assert!(s.visible_strokes(page).unwrap().is_empty());
        // 原始記錄仍在檔案裡，版本回溯才可能
        assert_eq!(s.package.read_ink(page).unwrap().len(), 2);
    }

    #[test]
    fn writing_to_a_missing_page_is_rejected() {
        let mut s = session("badpage");
        assert!(matches!(
            s.add_stroke(Uuid::now_v7(), stroke()),
            Err(AppError::PageNotFound(_))
        ));
    }

    #[test]
    fn time_never_goes_backwards() {
        let mut s = session("mono");
        s.advance_time(NotebookTime(1_000));
        s.advance_time(NotebookTime(500));
        assert_eq!(s.now(), NotebookTime(1_000), "時間軸必須單調遞增");
    }

    #[test]
    fn recording_lifecycle() {
        let mut s = session("record");
        assert_eq!(s.recording_state(), RecordingState::Idle);

        s.advance_time(NotebookTime(1_000_000));
        let id = s.start_recording().unwrap();
        assert!(
            matches!(s.recording_state(), RecordingState::Recording { session, .. } if session == id)
        );

        assert!(matches!(
            s.start_recording(),
            Err(AppError::AlreadyRecording)
        ));

        s.advance_time(NotebookTime(9_000_000));
        assert_eq!(s.stop_recording().unwrap(), id);
        assert_eq!(s.recording_state(), RecordingState::Idle);
        assert!(matches!(s.stop_recording(), Err(AppError::NotRecording)));
    }

    #[test]
    fn stopped_session_has_a_duration() {
        let mut s = session("duration");
        s.advance_time(NotebookTime(1_000_000));
        s.start_recording().unwrap();
        s.advance_time(NotebookTime(4_000_000));
        s.stop_recording().unwrap();

        assert_eq!(s.timeline().recorded_duration(), NotebookTime(3_000_000));
    }

    #[test]
    fn c1_tapping_a_stroke_finds_the_audio_position() {
        // 這是整個產品最核心的功能：Notability 的殺手鐧，Goodnotes 完全沒有。
        let mut s = session("c1");
        let page = s.first_page().unwrap();

        s.advance_time(NotebookTime(1_000_000));
        s.start_recording().unwrap();

        s.advance_time(NotebookTime(4_500_000));
        s.add_stroke(page, stroke()).unwrap();

        s.advance_time(NotebookTime(10_000_000));
        s.stop_recording().unwrap();

        let st = &s.visible_strokes(page).unwrap()[0];
        let (path, offset) = s.playback_for_stroke(st).expect("應找得到錄音");

        assert!(path.ends_with(".opus"));
        assert_eq!(offset, NotebookTime(3_500_000), "錄音開始後 3.5 秒寫的字");
    }

    #[test]
    fn stroke_written_outside_any_recording_has_no_playback() {
        let mut s = session("noplay");
        let page = s.first_page().unwrap();
        s.advance_time(NotebookTime(1_000_000));
        s.add_stroke(page, stroke()).unwrap();

        let st = &s.visible_strokes(page).unwrap()[0];
        assert!(s.playback_for_stroke(st).is_none());
    }

    #[test]
    fn transcripts_are_searchable() {
        let mut s = session("searchtx");
        let page = s.first_page().unwrap();
        let sess = s.start_recording().unwrap();

        s.add_transcript(
            page,
            sess,
            vec![
                word("線性", 1_000_000, 1_500_000),
                word("代數", 1_500_000, 2_000_000),
            ],
        )
        .unwrap();

        let hits = s.search("代數", 10);
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].source, Source::Transcript);
    }

    #[test]
    fn typed_text_and_handwriting_are_both_searchable() {
        let mut s = session("searchmix");
        let page = s.first_page().unwrap();

        s.add_text_block(page, "打字的筆記內容", TextStyle::Body)
            .unwrap();
        s.index_handwriting(page, Uuid::now_v7(), "手寫的筆記內容");

        assert_eq!(s.search("筆記", 10).len(), 2);
        // 打字應排在手寫辨識之前（辨識可能有誤）
        assert_eq!(s.search("筆記", 10)[0].source, Source::Text);
    }

    #[test]
    fn transcript_words_land_on_the_notebook_timeline() {
        let mut s = session("txtimeline");
        let page = s.first_page().unwrap();
        let sess = s.start_recording().unwrap();
        s.add_transcript(page, sess, vec![word("特徵值", 3_000_000, 3_800_000)])
            .unwrap();

        let found = s
            .timeline()
            .words_in(NotebookTime(2_000_000), NotebookTime(4_000_000));
        assert_eq!(found.len(), 1);
        assert_eq!(found[0].text, "特徵值");
    }

    // ---- 持久化（S-23）----

    #[test]
    fn pages_and_text_survive_a_reopen() {
        // 在此之前頁面與區塊只活在記憶體裡，關掉 App 就沒了。
        let mut s = session("persist-doc");
        let page = s.first_page().unwrap();
        let block = s
            .add_text_block(page, "線性代數的特徵值", TextStyle::Heading2)
            .unwrap();
        let extra = s.add_page(PageTemplate::Cornell).unwrap();
        s.set_title("改過的標題").unwrap();

        let s = reopen(s);

        assert_eq!(s.notebook().title, "改過的標題");
        assert_eq!(s.notebook().page_count(), 2);
        assert!(s.notebook().page(page).is_some());
        assert_eq!(
            s.notebook().page(extra).unwrap().template,
            PageTemplate::Cornell
        );
        assert_eq!(s.block_text(block).as_deref(), Some("線性代數的特徵值"));
    }

    #[test]
    fn search_index_is_rebuilt_on_reopen() {
        let mut s = session("persist-index");
        let page = s.first_page().unwrap();
        s.add_text_block(page, "矩陣運算的重點", TextStyle::Body)
            .unwrap();

        let s = reopen(s);
        assert_eq!(s.search("矩陣", 10).len(), 1, "索引必須從 op-log 重建");
    }

    #[test]
    fn recording_sessions_and_transcripts_survive_a_reopen() {
        let mut s = session("persist-audio");
        let page = s.first_page().unwrap();

        s.advance_time(NotebookTime(1_000_000));
        let sess = s.start_recording().unwrap();
        s.advance_time(NotebookTime(4_500_000));
        s.add_stroke(page, stroke()).unwrap();
        s.add_transcript(page, sess, vec![word("特徵值", 3_000_000, 3_800_000)])
            .unwrap();
        s.advance_time(NotebookTime(10_000_000));
        s.stop_recording().unwrap();

        let s = reopen(s);

        // C1 的跳轉關係必須在重開後仍然成立
        let st = &s.visible_strokes(page).unwrap()[0];
        let (_, offset) = s.playback_for_stroke(st).expect("重開後仍應找得到錄音");
        assert_eq!(offset, NotebookTime(3_500_000));

        assert_eq!(s.timeline().recorded_duration(), NotebookTime(9_000_000));
        assert_eq!(s.search("特徵", 10).len(), 1);
        assert_eq!(
            s.recording_state(),
            RecordingState::Idle,
            "重開後不該是錄音中"
        );
    }

    #[test]
    fn text_edits_replay_in_order() {
        let mut s = session("persist-edits");
        let page = s.first_page().unwrap();
        let block = s.add_text_block(page, "線性數", TextStyle::Body).unwrap();

        s.insert_text(block, 2, "代").unwrap();
        assert_eq!(s.block_text(block).as_deref(), Some("線性代數"));

        s.delete_text(block, 0, 2).unwrap();
        assert_eq!(s.block_text(block).as_deref(), Some("代數"));

        let s = reopen(s);
        assert_eq!(
            s.block_text(block).as_deref(),
            Some("代數"),
            "編輯歷史必須完整重播"
        );
    }

    #[test]
    fn removed_block_stays_removed_after_reopen() {
        // 墓碑要寫進 op-log，否則重播時被刪的東西會復活。
        let mut s = session("persist-remove");
        let page = s.first_page().unwrap();
        let keep = s.add_text_block(page, "保留", TextStyle::Body).unwrap();
        let drop_it = s.add_text_block(page, "刪除", TextStyle::Body).unwrap();
        s.remove_block(drop_it).unwrap();

        let s = reopen(s);
        assert_eq!(s.notebook().page(page).unwrap().blocks().len(), 1);
        assert_eq!(s.block_text(keep).as_deref(), Some("保留"));
        assert!(s.block_text(drop_it).is_none(), "被刪的區塊不該復活");
        assert!(s.search("刪除", 10).is_empty(), "索引也要跟著清掉");
    }

    #[test]
    fn images_and_blob_references_survive() {
        let mut s = session("persist-image");
        let page = s.first_page().unwrap();
        let blob = s.package().blobs().put(b"image bytes").unwrap().to_string();
        s.add_image_block(page, &blob, 640.0, 480.0).unwrap();

        let s = reopen(s);
        assert_eq!(s.notebook().referenced_blobs(), vec![blob.clone()]);
        assert_eq!(
            s.package()
                .blobs()
                .get(padnote_storage::BlobId::from_hex(&blob).unwrap())
                .unwrap(),
            b"image bytes"
        );
    }

    #[test]
    fn editing_a_missing_block_is_rejected() {
        let mut s = session("badblock");
        assert!(matches!(
            s.insert_text(Uuid::now_v7(), 0, "x"),
            Err(AppError::BlockNotFound(_))
        ));
    }

    #[test]
    fn remote_ops_apply_without_being_written_again() {
        // 同步拉到的操作由 sync 層負責落盤，session 只負責套用。
        let mut s = session("remote");
        let page = s.first_page().unwrap();

        let remote_block = Uuid::now_v7();
        s.apply_remote(&[DocOp::AddTextBlock {
            page,
            id: remote_block,
            style: TextStyle::Body,
            created_at: NotebookTime::ZERO,
        }]);

        assert!(s.block_text(remote_block).is_some());
        assert_eq!(
            s.notebook().page(page).unwrap().blocks().len(),
            1,
            "遠端區塊要出現在頁面上"
        );
    }

    #[test]
    fn export_includes_text_and_flags_handwriting() {
        let mut s = session("export");
        let page = s.first_page().unwrap();
        s.add_text_block(page, "重點整理", TextStyle::Heading2)
            .unwrap();
        s.add_stroke(page, stroke()).unwrap();

        let md = s.export_markdown().unwrap();
        assert!(md.contains("# 線性代數"));
        assert!(md.contains("## 重點整理"));
        assert!(md.contains("手寫內容"), "手寫不可被靜默省略");
    }
}
