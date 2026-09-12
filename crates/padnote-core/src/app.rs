//! 應用層操作：把 storage / doc / ink / asr / search 串成使用者看得到的行為。
//!
//! 這一層的存在理由是**時序正確性**。例如「開始錄音」必須先落盤音檔、
//! 再建立 session、最後才啟動轉錄 —— 順序錯了就會出現「轉錄成功但音檔沒了」
//! 這種最糟的失敗模式（Notability 的教訓）。

use padnote_doc::{
    Affine2, AudioSession, Block, BlockKind, DocOp, Notebook, NotebookTime, ObjectNode, ObjectTree,
    Page, PageTemplate, TextCrdt, TextEditor, TextStyle, Timeline, TranscriptWord, Uuid,
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
        }
    }
}

impl std::error::Error for AppError {}

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
        let package = NotebookPackage::create(root, title, now_unix_ms)?;
        let id = Uuid::now_v7();
        let mut session = Self {
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
        let first = Uuid::now_v7();
        session.record(vec![DocOp::AddPage {
            id: first,
            template: PageTemplate::Lined,
            index: 0,
        }])?;
        Ok(session)
    }

    /// 開啟既有筆記本並重播 op-log。
    ///
    /// 重播而非讀快照：op-log 是唯一的事實來源，快照只是最佳化（尚未實作）。
    pub fn open(root: impl Into<std::path::PathBuf>, device: u32) -> Result<Self, AppError> {
        let package = NotebookPackage::open(root)?;
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

            DocOp::AddPage {
                id,
                template,
                index,
            } => {
                self.notebook
                    .insert_page(*index as usize, Page::new(*id, template.clone()));
            }
            DocOp::RemovePage { id } => {
                self.notebook.remove_page(*id);
                self.index
                    .remove_page(&self.notebook.id.to_string(), &id.to_string());
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
                        },
                        position: None,
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

    pub fn remove_page(&mut self, id: Uuid) -> Result<(), AppError> {
        self.record(vec![DocOp::RemovePage { id }])
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
