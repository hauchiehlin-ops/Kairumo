//! UniFFI 門面（工作項 S-12）。
//!
//! Swift 與 Kotlin **只透過這一層**呼叫 Rust core。
//!
//! ## 為什麼要獨立一層，而不直接匯出內部型別
//! 1. FFI 邊界只能傳簡單型別（record/enum/字串/數字）。內部的 `Uuid`、
//!    `NotebookTime`、trait 物件都過不去。
//! 2. 內部重構不該逼著兩個平台的 UI 一起改。這一層是**穩定的契約**。
//! 3. 錯誤要變成各平台慣用的形式（Swift 的 `throws`、Kotlin 的 exception）。
//!
//! ## 執行緒
//! `PadnoteSession` 內含 `Mutex`。UI 執行緒與背景的 ASR／同步執行緒都會碰它，
//! 因此每個方法都短暫持鎖後立刻釋放 —— **絕不在持鎖期間做 IO 以外的長工作**，
//! 否則會卡住墨跡執行緒（違反 J1 的延遲預算）。

use crate::app::{AppError, NotebookSession, RecordingState};
use crate::setup::{Capability, Feature, SetupCenter, Status};
use padnote_doc::{Affine2, NotebookTime, PageTemplate, TextStyle, TranscriptWord, Uuid};
use padnote_ink::{InkPoint, Stroke, Tool};
use std::sync::Mutex;

// ---- 錯誤 ----

#[derive(Debug, uniffi::Error)]
#[uniffi(flat_error)]
pub enum FfiError {
    /// 訊息已在地化，可直接顯示給使用者。
    Failed(String),
}

impl std::fmt::Display for FfiError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Failed(m) => f.write_str(m),
        }
    }
}

impl std::error::Error for FfiError {}

impl From<AppError> for FfiError {
    fn from(e: AppError) -> Self {
        Self::Failed(e.to_string())
    }
}

// ---- 資料型別 ----

#[derive(Clone, Copy, Debug, uniffi::Enum)]
pub enum ToolKind {
    FountainPen,
    BallPoint,
    Highlighter,
    Pencil,
}

impl From<ToolKind> for Tool {
    fn from(t: ToolKind) -> Self {
        match t {
            ToolKind::FountainPen => Tool::FountainPen,
            ToolKind::BallPoint => Tool::BallPoint,
            ToolKind::Highlighter => Tool::Highlighter,
            ToolKind::Pencil => Tool::Pencil,
        }
    }
}

#[derive(Clone, Copy, Debug, uniffi::Enum)]
pub enum PageStyle {
    Blank,
    Lined,
    Grid,
    Dotted,
    Cornell,
    MusicStaff,
}

impl From<PageStyle> for PageTemplate {
    fn from(p: PageStyle) -> Self {
        match p {
            PageStyle::Blank => PageTemplate::Blank,
            PageStyle::Lined => PageTemplate::Lined,
            PageStyle::Grid => PageTemplate::Grid,
            PageStyle::Dotted => PageTemplate::Dotted,
            PageStyle::Cornell => PageTemplate::Cornell,
            PageStyle::MusicStaff => PageTemplate::MusicStaff,
        }
    }
}

#[derive(Clone, Copy, Debug, uniffi::Enum)]
pub enum BlockStyle {
    Body,
    Heading1,
    Heading2,
    Heading3,
    Bullet,
    Quote,
    Code,
    TodoOpen,
    TodoDone,
}

impl From<BlockStyle> for TextStyle {
    fn from(b: BlockStyle) -> Self {
        match b {
            BlockStyle::Body => TextStyle::Body,
            BlockStyle::Heading1 => TextStyle::Heading1,
            BlockStyle::Heading2 => TextStyle::Heading2,
            BlockStyle::Heading3 => TextStyle::Heading3,
            BlockStyle::Bullet => TextStyle::Bullet,
            BlockStyle::Quote => TextStyle::Quote,
            BlockStyle::Code => TextStyle::Code,
            BlockStyle::TodoOpen => TextStyle::Todo { done: false },
            BlockStyle::TodoDone => TextStyle::Todo { done: true },
        }
    }
}

/// 一個觸控取樣點。欄位對應 `InkPoint`（format-spec §5.4）。
///
/// ⚠️ 平台層**不得**把預測筆跡（predicted touches）放進來 ——
/// 那是視覺補償，不是真實輸入。
#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct StrokePoint {
    pub x: f32,
    pub y: f32,
    pub pressure: f32,
    pub tilt: f32,
    pub azimuth: f32,
    /// 距前一點的微秒差。
    pub dt_us: u32,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct SearchResult {
    pub page_id: String,
    pub block_id: String,
    /// `text` / `transcript` / `handwriting` / `pdf` / `ocr`
    pub source: String,
    pub score: f32,
    pub snippet: String,
}

/// 功能 C1 的回傳值：某個時刻對應的錄音位置。
#[derive(Clone, Debug, uniffi::Record)]
pub struct PlaybackPosition {
    /// 相對筆記本根目錄的音檔路徑。
    pub media_path: String,
    /// 音檔內的播放偏移（微秒）。
    pub offset_us: u64,
}

/// 一次 `feed_audio` 的統計。
#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct RecordingStats {
    /// 本次寫進 Opus 檔的音框數。
    pub frames_written: u64,
    /// 本次切出並入列待轉錄的語音段數。
    pub segments_queued: u32,
    /// 累計因佇列滿而丟棄的段數。**非零代表 ASR 跟不上錄音速度**，
    /// UI 應提示使用者改用較小的模型。音檔本身不受影響。
    pub segments_dropped: u64,
    /// 已落盤的音訊總時長。
    pub recorded_us: u64,
    /// 待轉錄的音訊時長。
    pub backlog_us: u64,
}

/// 平台層傳入的轉錄結果。時間戳必須已在筆記本時間軸上。
#[derive(Clone, Debug, uniffi::Record)]
pub struct TranscriptWordInput {
    pub text: String,
    pub start_us: u64,
    pub end_us: u64,
    pub confidence: f32,
}

/// 繪製順序中的一項。
#[derive(Clone, Debug, uniffi::Record)]
pub struct DrawItem {
    pub object_id: String,
    /// 世界變換 `[a, b, c, d, tx, ty]`。
    pub transform: Vec<f32>,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct StrokeSummary {
    pub id: String,
    pub started_at_us: u64,
    pub point_count: u32,
    /// 含筆寬的外框 `[min_x, min_y, max_x, max_y]`，供命中測試與重繪。
    pub bounds: Vec<f32>,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FeatureStatus {
    /// `core_notes` / `recording` / `live_transcription` / …
    pub feature: String,
    pub ready: bool,
    /// 給使用者看的一句話，例如「需要：麥克風、語音模型」。
    pub explanation: String,
}

// ---- Session ----

/// 一個開啟中的筆記本。各平台持有它的參照。
#[derive(Debug, uniffi::Object)]
pub struct PadnoteSession {
    inner: Mutex<NotebookSession>,
    setup: Mutex<SetupCenter>,
}

#[uniffi::export]
impl PadnoteSession {
    /// 建立新筆記本。
    ///
    /// `path` 是 `.padnote` 套件的目錄位置。`device_id` 必須是**這台裝置穩定
    /// 不變**的識別碼（例如 iOS 的 `identifierForVendor` 雜湊後取 32 bit）——
    /// 它會進 oplog 檔名，用來保證兩台裝置永不寫同一個檔。
    #[uniffi::constructor]
    pub fn create(
        path: String,
        title: String,
        now_unix_ms: u64,
        device_id: u32,
    ) -> Result<Self, FfiError> {
        Ok(Self::wrap(NotebookSession::create(
            path,
            &title,
            now_unix_ms,
            device_id,
        )?))
    }

    /// 開啟既有筆記本，重播 op-log 還原全部內容。
    ///
    /// ⚠️ 名稱刻意不叫 `open` —— `open` 是 Swift 的存取修飾關鍵字，
    /// UniFFI 會**靜默略過**該建構子，Swift 端就完全看不到它。
    #[uniffi::constructor]
    pub fn open_existing(path: String, device_id: u32) -> Result<Self, FfiError> {
        Ok(Self::wrap(NotebookSession::open(path, device_id)?))
    }

    /// 推進筆記本時間軸。平台層以 monotonic clock 餵入，**必須單調遞增**。
    pub fn advance_time(&self, notebook_time_us: u64) {
        self.lock()
            .advance_time(NotebookTime::from_micros(notebook_time_us));
    }

    pub fn now_us(&self) -> u64 {
        self.lock().now().as_micros()
    }

    pub fn title(&self) -> String {
        self.lock().notebook().title.clone()
    }

    pub fn page_count(&self) -> u32 {
        self.lock().notebook().page_count() as u32
    }

    pub fn first_page_id(&self) -> Option<String> {
        self.lock().first_page().map(|id| id.to_string())
    }

    pub fn add_page(&self, style: PageStyle) -> Result<String, FfiError> {
        Ok(self.lock().add_page(style.into())?.to_string())
    }

    pub fn set_title(&self, title: String) -> Result<(), FfiError> {
        self.lock().set_title(&title)?;
        Ok(())
    }

    // ---- 手寫 ----

    /// 寫入一筆畫，回傳其 id。時間戳由 core 依當前時間軸填入。
    pub fn add_stroke(
        &self,
        page_id: String,
        tool: ToolKind,
        color_rgba: Vec<u8>,
        base_width: f32,
        points: Vec<StrokePoint>,
    ) -> Result<String, FfiError> {
        let page = parse_uuid(&page_id)?;
        let id = Uuid::now_v7();
        let stroke = Stroke {
            id,
            started_at: NotebookTime::ZERO, // core 會覆寫為當前時間
            tool: tool.into(),
            color_rgba8: to_rgba(&color_rgba),
            base_width,
            points: points.into_iter().map(to_ink_point).collect(),
        };
        self.lock().add_stroke(page, stroke)?;
        Ok(id.to_string())
    }

    pub fn erase_stroke(&self, page_id: String, stroke_id: String) -> Result<(), FfiError> {
        let (page, stroke) = (parse_uuid(&page_id)?, parse_uuid(&stroke_id)?);
        self.lock().erase_stroke(page, stroke)?;
        Ok(())
    }

    /// 目前可見的筆畫摘要。
    ///
    /// 刻意不回傳全部取樣點 —— 一頁數萬個點跨 FFI 邊界會很慢。
    /// 渲染用的原始資料由平台層直接讀 `.strokes` 檔。
    pub fn visible_strokes(&self, page_id: String) -> Result<Vec<StrokeSummary>, FfiError> {
        let page = parse_uuid(&page_id)?;
        Ok(self
            .lock()
            .visible_strokes(page)?
            .into_iter()
            .map(|s| {
                let b = s.inked_bounds();
                StrokeSummary {
                    id: s.id.to_string(),
                    started_at_us: s.started_at.as_micros(),
                    point_count: s.points.len() as u32,
                    bounds: b.map_or_else(Vec::new, |r| vec![r.min_x, r.min_y, r.max_x, r.max_y]),
                }
            })
            .collect())
    }

    // ---- 文字 ----

    pub fn add_text(
        &self,
        page_id: String,
        content: String,
        style: BlockStyle,
    ) -> Result<String, FfiError> {
        let page = parse_uuid(&page_id)?;
        Ok(self
            .lock()
            .add_text_block(page, &content, style.into())?
            .to_string())
    }

    /// 在文字區塊的第 `index` 個**字元**（非位元組）位置插入文字。
    ///
    /// 用字元索引是必要的：UTF-16 或位元組索引都會把中文與 emoji 切壞。
    pub fn insert_text(&self, block_id: String, index: u32, text: String) -> Result<(), FfiError> {
        let block = parse_uuid(&block_id)?;
        self.lock().insert_text(block, index as usize, &text)?;
        Ok(())
    }

    pub fn delete_text(&self, block_id: String, index: u32, count: u32) -> Result<(), FfiError> {
        let block = parse_uuid(&block_id)?;
        self.lock()
            .delete_text(block, index as usize, count as usize)?;
        Ok(())
    }

    pub fn block_text(&self, block_id: String) -> Result<Option<String>, FfiError> {
        Ok(self.lock().block_text(parse_uuid(&block_id)?))
    }

    pub fn remove_block(&self, block_id: String) -> Result<(), FfiError> {
        self.lock().remove_block(parse_uuid(&block_id)?)?;
        Ok(())
    }

    /// 插入圖片。`blob` 為內容定址雜湊。
    pub fn add_image(
        &self,
        page_id: String,
        blob: String,
        width: f32,
        height: f32,
    ) -> Result<String, FfiError> {
        let page = parse_uuid(&page_id)?;
        Ok(self
            .lock()
            .add_image_block(page, &blob, width, height)?
            .to_string())
    }

    /// 把位元組存成內容定址 blob，回傳其雜湊。供 `add_image` 使用。
    pub fn put_blob(&self, bytes: Vec<u8>) -> Result<String, FfiError> {
        self.lock()
            .package()
            .blobs()
            .put(&bytes)
            .map(|id| id.to_string())
            .map_err(|e| FfiError::Failed(e.to_string()))
    }

    // ---- 錄音 ----

    pub fn start_recording(&self) -> Result<String, FfiError> {
        Ok(self.lock().start_recording()?.to_string())
    }

    pub fn stop_recording(&self) -> Result<String, FfiError> {
        Ok(self.lock().stop_recording()?.to_string())
    }

    pub fn is_recording(&self) -> bool {
        matches!(
            self.lock().recording_state(),
            RecordingState::Recording { .. }
        )
    }

    /// 餵入麥克風取樣（16 kHz 單聲道 f32）。
    ///
    /// **音檔在此同步落地**。轉錄只是把語音段入列，由背景 worker 取用 ——
    /// 因此這個呼叫的耗時與 ASR 模型無關，不會拖累錄音執行緒。
    pub fn feed_audio(&self, pcm_16k_mono: Vec<f32>) -> Result<RecordingStats, FfiError> {
        let mut guard = self.lock();
        let out = guard.feed_audio(&pcm_16k_mono)?;
        Ok(RecordingStats {
            frames_written: out.frames_written,
            segments_queued: out.segments_queued as u32,
            segments_dropped: out.segments_dropped,
            recorded_us: guard.recorded_audio_us(),
            backlog_us: guard.transcription_backlog_us(),
        })
    }

    /// 設定 Silero VAD 模型路徑（S-26）。下一次開始錄音時生效。
    ///
    /// 模型由 `padnote-models` 的下載器取得（`silero-vad-v4`，1.8 MB）。
    pub fn set_vad_model(&self, path: String) {
        self.lock().set_vad_model(path);
    }

    /// 目前是否使用神經網路 VAD。
    ///
    /// `false` 代表退回能量門檻法 —— 實測在白噪音下 **100 個音框全部誤判為
    /// 語音**（Silero 為 0 個）。UI 應提示使用者下載模型以改善分段品質。
    pub fn uses_neural_vad(&self) -> bool {
        self.lock().uses_neural_vad()
    }

    /// 已寫入音檔的時長（微秒）。停止錄音後仍可查。
    pub fn recorded_audio_us(&self) -> u64 {
        self.lock().recorded_audio_us()
    }

    /// 轉錄落後的音訊時長。UI 顯示「轉錄落後 N 秒」。
    pub fn transcription_backlog_us(&self) -> u64 {
        self.lock().transcription_backlog_us()
    }

    /// 寫入一批轉錄結果。
    ///
    /// 平台層從背景 worker 取得結果後呼叫。時間戳必須已經在筆記本時間軸上。
    pub fn add_transcript(
        &self,
        page_id: String,
        session_id: String,
        words: Vec<TranscriptWordInput>,
    ) -> Result<String, FfiError> {
        let (page, session) = (parse_uuid(&page_id)?, parse_uuid(&session_id)?);
        let words = words
            .into_iter()
            .map(|w| TranscriptWord {
                text: w.text,
                start: NotebookTime::from_micros(w.start_us),
                end: NotebookTime::from_micros(w.end_us),
                confidence: w.confidence,
            })
            .collect();
        Ok(self
            .lock()
            .add_transcript(page, session, words)?
            .to_string())
    }

    /// **功能 C1**：某個筆記本時刻對應的錄音位置。
    ///
    /// 使用者點一筆畫時，平台層傳入該筆畫的 `started_at_us`。
    pub fn playback_at(&self, notebook_time_us: u64) -> Option<PlaybackPosition> {
        self.lock()
            .timeline()
            .playback_at(NotebookTime::from_micros(notebook_time_us))
            .map(|(s, offset)| PlaybackPosition {
                media_path: s.media_path.clone(),
                offset_us: offset.as_micros(),
            })
    }

    pub fn recorded_duration_us(&self) -> u64 {
        self.lock().timeline().recorded_duration().as_micros()
    }

    // ---- 搜尋與匯出 ----

    pub fn search(&self, query: String, limit: u32) -> Vec<SearchResult> {
        self.lock()
            .search(&query, limit as usize)
            .into_iter()
            .map(|h| SearchResult {
                page_id: h.doc.page,
                block_id: h.doc.block,
                source: source_name(h.source).into(),
                score: h.score,
                snippet: h.snippet,
            })
            .collect()
    }

    /// 手寫辨識完成後回填索引（辨識是非同步的，故獨立於 `add_stroke`）。
    pub fn index_handwriting(
        &self,
        page_id: String,
        stroke_id: String,
        text: String,
    ) -> Result<(), FfiError> {
        let (page, stroke) = (parse_uuid(&page_id)?, parse_uuid(&stroke_id)?);
        self.lock().index_handwriting(page, stroke, &text);
        Ok(())
    }

    // ---- 物件（S-38 / ADR-0010）----

    /// 把筆畫收成一個物件，讓它能被群組與變換。
    pub fn create_stroke_object(
        &self,
        page_id: String,
        stroke_ids: Vec<String>,
    ) -> Result<String, FfiError> {
        let page = parse_uuid(&page_id)?;
        let strokes = stroke_ids
            .iter()
            .map(|s| parse_uuid(s))
            .collect::<Result<Vec<_>, _>>()?;
        Ok(self.lock().create_stroke_object(page, strokes)?.to_string())
    }

    pub fn group_objects(
        &self,
        page_id: String,
        object_ids: Vec<String>,
    ) -> Result<String, FfiError> {
        let page = parse_uuid(&page_id)?;
        let members = object_ids
            .iter()
            .map(|s| parse_uuid(s))
            .collect::<Result<Vec<_>, _>>()?;
        Ok(self.lock().group_objects(page, members)?.to_string())
    }

    /// 解散群組。成員的位置不會跳動 —— 群組的變換會往下傳給它們。
    pub fn ungroup(&self, object_id: String) -> Result<(), FfiError> {
        self.lock().ungroup(parse_uuid(&object_id)?)?;
        Ok(())
    }

    /// 平移物件。**不改寫任何取樣點**（ADR-0010）。
    pub fn translate_object(&self, object_id: String, dx: f32, dy: f32) -> Result<(), FfiError> {
        self.apply_transform(&object_id, Affine2::translate(dx, dy))
    }

    /// 以 `(cx, cy)` 為中心縮放。以原點縮放會讓物件同時飛走。
    pub fn scale_object(
        &self,
        object_id: String,
        sx: f32,
        sy: f32,
        cx: f32,
        cy: f32,
    ) -> Result<(), FfiError> {
        self.apply_transform(&object_id, Affine2::scale_around(sx, sy, cx, cy))
    }

    /// 以 `(cx, cy)` 為中心旋轉（弧度）。
    pub fn rotate_object(
        &self,
        object_id: String,
        radians: f32,
        cx: f32,
        cy: f32,
    ) -> Result<(), FfiError> {
        self.apply_transform(&object_id, Affine2::rotate_around(radians, cx, cy))
    }

    // ---- 堆疊順序（S-46，需求 1）----

    /// 移到同層最上層。
    pub fn bring_to_front(&self, page_id: String, object_id: String) -> Result<(), FfiError> {
        let (page, id) = (parse_uuid(&page_id)?, parse_uuid(&object_id)?);
        self.lock().bring_to_front(page, id)?;
        Ok(())
    }

    /// 移到同層最下層。
    pub fn send_to_back(&self, object_id: String) -> Result<(), FfiError> {
        self.lock().send_to_back(parse_uuid(&object_id)?)?;
        Ok(())
    }

    /// 上移一層。
    pub fn bring_forward(&self, page_id: String, object_id: String) -> Result<(), FfiError> {
        let (page, id) = (parse_uuid(&page_id)?, parse_uuid(&object_id)?);
        self.lock().bring_forward(page, id)?;
        Ok(())
    }

    /// 下移一層。
    pub fn send_backward(&self, page_id: String, object_id: String) -> Result<(), FfiError> {
        let (page, id) = (parse_uuid(&page_id)?, parse_uuid(&object_id)?);
        self.lock().send_backward(page, id)?;
        Ok(())
    }

    /// 物件在同層中的位置。
    pub fn z_index(&self, page_id: String, object_id: String) -> Result<Option<u32>, FfiError> {
        let (page, id) = (parse_uuid(&page_id)?, parse_uuid(&object_id)?);
        Ok(self.lock().z_index(page, id).map(|i| i as u32))
    }

    /// 整頁的繪製順序：由下而上的 `(物件 id, 世界變換)`。
    ///
    /// 這是渲染要的**唯一**順序來源 —— 平台層照著畫就對了，
    /// 不必自己重建樹狀結構。
    pub fn draw_order(&self, page_id: String) -> Result<Vec<DrawItem>, FfiError> {
        let page = parse_uuid(&page_id)?;
        let guard = self.lock();
        Ok(guard
            .objects(page)
            .map(|tree| {
                tree.draw_order()
                    .into_iter()
                    .map(|(id, t)| DrawItem {
                        object_id: id.to_string(),
                        transform: vec![t.a, t.b, t.c, t.d, t.tx, t.ty],
                    })
                    .collect()
            })
            .unwrap_or_default())
    }

    // ---- 表格（S-48，需求 2）----

    /// 插入表格。`cells` 以列為主展開，不足補空白。
    pub fn insert_table(
        &self,
        page_id: String,
        rows: u32,
        cols: u32,
        cells: Vec<String>,
        header_row: bool,
    ) -> Result<String, FfiError> {
        let page = parse_uuid(&page_id)?;
        Ok(self
            .lock()
            .insert_table(page, rows, cols, cells, header_row)?
            .to_string())
    }

    /// 改寫單一儲存格。
    pub fn set_table_cell(
        &self,
        block_id: String,
        row: u32,
        col: u32,
        text: String,
    ) -> Result<(), FfiError> {
        self.lock()
            .set_table_cell(parse_uuid(&block_id)?, row, col, &text)?;
        Ok(())
    }

    /// 物件在頁面上的累積變換，回傳 `[a, b, c, d, tx, ty]`。
    pub fn object_transform(
        &self,
        page_id: String,
        object_id: String,
    ) -> Result<Vec<f32>, FfiError> {
        let (page, object) = (parse_uuid(&page_id)?, parse_uuid(&object_id)?);
        let guard = self.lock();
        let t = guard
            .objects(page)
            .map_or(Affine2::IDENTITY, |tree| tree.world_transform(object));
        Ok(vec![t.a, t.b, t.c, t.d, t.tx, t.ty])
    }

    // ---- 嵌入文件（S-41 / ADR-0009）----

    /// 匯入外部文件。
    ///
    /// 可編輯格式（docx／xlsx／md／json）會解析成**原生區塊**；
    /// 僅預覽格式（pptx／pdf）建立嵌入區塊。
    /// **原始檔一律保留** —— 解析必然失真。
    pub fn import_embedded(&self, page_id: String, path: String) -> Result<String, FfiError> {
        let page = parse_uuid(&page_id)?;
        Ok(self.lock().import_embedded(page, path)?.to_string())
    }

    /// 匯入 Markdown。回傳新建立的頁面 id。
    ///
    /// **加進來而非取代** —— 按錯不該弄丟既有筆記。
    pub fn import_markdown(&self, text: String) -> Result<Vec<String>, FfiError> {
        Ok(self
            .lock()
            .import_markdown(&text)?
            .into_iter()
            .map(|id| id.to_string())
            .collect())
    }

    /// 匯入 JSON。Schema 見 `padnote_export::from_json`。
    pub fn import_json(&self, text: String) -> Result<Vec<String>, FfiError> {
        Ok(self
            .lock()
            .import_json(&text)?
            .into_iter()
            .map(|id| id.to_string())
            .collect())
    }

    pub fn export_markdown(&self) -> Result<String, FfiError> {
        Ok(self.lock().export_markdown()?)
    }

    // ---- 引擎與權限中心（功能 I1）----

    /// 平台層回報某項能力的狀態。
    ///
    /// `capability`：`microphone` / `speech` / `handwriting` / `asr_model` /
    /// `llm_model` / `local_folder` / `icloud` / `google_drive`
    /// `state`：`ready` / `needs_permission` / `denied` / `needs_download` /
    /// `not_configured` / `unsupported`
    pub fn report_capability(&self, capability: String, state: String, size_bytes: u64) {
        let Some(cap) = parse_capability(&capability) else {
            return;
        };
        let status = match state.as_str() {
            "ready" => Status::Ready,
            "needs_permission" => Status::NeedsPermission,
            "denied" => Status::PermissionDenied,
            "needs_download" => Status::NeedsDownload { size_bytes },
            "not_configured" => Status::NotConfigured,
            _ => Status::Unsupported,
        };
        self.setup.lock().expect("setup 鎖中毒").set(cap, status);
    }

    /// 各功能目前能不能用、不能的話缺什麼。設定頁直接畫這個列表。
    pub fn feature_status(&self) -> Vec<FeatureStatus> {
        self.setup
            .lock()
            .expect("setup 鎖中毒")
            .all_readiness()
            .into_iter()
            .map(|r| FeatureStatus {
                feature: feature_name(r.feature).into(),
                ready: r.ready,
                explanation: r.explanation(),
            })
            .collect()
    }

    /// 待下載的總位元組數。空間不足時要先警告使用者。
    pub fn pending_download_bytes(&self) -> u64 {
        self.setup
            .lock()
            .expect("setup 鎖中毒")
            .total_download_bytes()
    }
}

impl PadnoteSession {
    fn apply_transform(&self, object_id: &str, t: Affine2) -> Result<(), FfiError> {
        self.lock().transform_object(parse_uuid(object_id)?, t)?;
        Ok(())
    }

    fn wrap(session: NotebookSession) -> Self {
        Self {
            inner: Mutex::new(session),
            setup: Mutex::new(SetupCenter::new("paraformer-zh", "qwen3-4b-instruct-q4")),
        }
    }

    fn lock(&self) -> std::sync::MutexGuard<'_, NotebookSession> {
        // 鎖中毒代表其他執行緒 panic 過。繼續用髒狀態比明確崩掉更危險。
        self.inner.lock().expect("session 鎖中毒")
    }
}

// ---- 自由函式 ----

/// 本 build 支援的 `.padnote` 格式版本。
#[uniffi::export]
pub fn spec_version() -> u32 {
    crate::SPEC_VERSION
}

/// 這份筆記本能不能用目前的版本開啟（format-spec §8）。
#[uniffi::export]
pub fn can_open(spec_version: u32, min_reader_version: u32) -> bool {
    crate::can_open(spec_version, min_reader_version)
}

// ---- 轉換輔助 ----

fn to_ink_point(p: StrokePoint) -> InkPoint {
    InkPoint {
        x: p.x,
        y: p.y,
        pressure: p.pressure,
        tilt: p.tilt,
        azimuth: p.azimuth,
        dt_us: p.dt_us,
    }
}

/// 不足 4 個位元組時補為不透明黑色，而不是 panic —— FFI 輸入不可信。
fn to_rgba(v: &[u8]) -> [u8; 4] {
    match v.len() {
        4 => [v[0], v[1], v[2], v[3]],
        3 => [v[0], v[1], v[2], 255],
        _ => [0, 0, 0, 255],
    }
}

fn parse_uuid(s: &str) -> Result<Uuid, FfiError> {
    let hex: String = s.chars().filter(|c| *c != '-').collect();
    if hex.len() != 32 {
        return Err(FfiError::Failed(format!("不是合法的 id：{s}")));
    }
    let mut out = [0u8; 16];
    for (i, c) in hex.as_bytes().chunks(2).enumerate() {
        out[i] = std::str::from_utf8(c)
            .ok()
            .and_then(|h| u8::from_str_radix(h, 16).ok())
            .ok_or_else(|| FfiError::Failed(format!("不是合法的 id：{s}")))?;
    }
    Ok(Uuid::from_bytes(out))
}

fn source_name(s: padnote_search::Source) -> &'static str {
    use padnote_search::Source;
    match s {
        Source::Text => "text",
        Source::Transcript => "transcript",
        Source::Handwriting => "handwriting",
        Source::PdfText => "pdf",
        Source::Ocr => "ocr",
    }
}

fn feature_name(f: Feature) -> &'static str {
    match f {
        Feature::CoreNotes => "core_notes",
        Feature::Recording => "recording",
        Feature::LiveTranscription => "live_transcription",
        Feature::HandwritingToText => "handwriting_to_text",
        Feature::AiSummary => "ai_summary",
        Feature::Sync => "sync",
    }
}

fn parse_capability(s: &str) -> Option<Capability> {
    Some(match s {
        "microphone" => Capability::Microphone,
        "speech" => Capability::SpeechPermission,
        "handwriting" => Capability::Handwriting,
        "asr_model" => Capability::AsrModel("paraformer-zh".into()),
        "llm_model" => Capability::LlmModel("qwen3-4b-instruct-q4".into()),
        "local_folder" => Capability::LocalSyncFolder,
        "icloud" => Capability::ICloudDrive,
        "google_drive" => Capability::GoogleDrive,
        _ => return None,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tmp(name: &str) -> String {
        let d = std::env::temp_dir().join(format!("padnote-ffi-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        d.to_string_lossy().into_owned()
    }

    fn session(name: &str) -> PadnoteSession {
        PadnoteSession::create(tmp(name), "線性代數".into(), 1_757_635_200_000, 0xA1).unwrap()
    }

    fn points() -> Vec<StrokePoint> {
        vec![
            StrokePoint {
                x: 0.0,
                y: 0.0,
                pressure: 0.5,
                tilt: 0.0,
                azimuth: 0.0,
                dt_us: 0,
            },
            StrokePoint {
                x: 10.0,
                y: 10.0,
                pressure: 0.8,
                tilt: 0.0,
                azimuth: 0.0,
                dt_us: 8_000,
            },
        ]
    }

    #[test]
    fn session_round_trip_through_the_ffi_surface() {
        let s = session("roundtrip");
        assert_eq!(s.title(), "線性代數");
        assert_eq!(s.page_count(), 1);

        let page = s.first_page_id().unwrap();
        let stroke = s
            .add_stroke(
                page.clone(),
                ToolKind::FountainPen,
                vec![0, 0, 0, 255],
                2.0,
                points(),
            )
            .unwrap();

        let strokes = s.visible_strokes(page.clone()).unwrap();
        assert_eq!(strokes.len(), 1);
        assert_eq!(strokes[0].id, stroke);
        assert_eq!(strokes[0].point_count, 2);
        assert_eq!(strokes[0].bounds.len(), 4);

        s.erase_stroke(page.clone(), stroke).unwrap();
        assert!(s.visible_strokes(page).unwrap().is_empty());
    }

    #[test]
    fn malformed_id_returns_error_instead_of_panicking() {
        // FFI 輸入來自另一個語言，不可信。
        let s = session("badid");
        assert!(
            s.add_stroke(
                "not-a-uuid".into(),
                ToolKind::BallPoint,
                vec![],
                1.0,
                points()
            )
            .is_err()
        );
        assert!(s.visible_strokes("".into()).is_err());
        assert!(s.erase_stroke("zzzz".into(), "zzzz".into()).is_err());
    }

    #[test]
    fn short_color_array_falls_back_instead_of_panicking() {
        assert_eq!(to_rgba(&[]), [0, 0, 0, 255]);
        assert_eq!(to_rgba(&[1, 2, 3]), [1, 2, 3, 255]);
        assert_eq!(to_rgba(&[1, 2, 3, 4]), [1, 2, 3, 4]);
        assert_eq!(to_rgba(&[1, 2, 3, 4, 5]), [0, 0, 0, 255]);
    }

    #[test]
    fn c1_playback_lookup_works_across_the_boundary() {
        let s = session("c1");
        let page = s.first_page_id().unwrap();

        s.advance_time(1_000_000);
        s.start_recording().unwrap();
        assert!(s.is_recording());

        s.advance_time(4_500_000);
        s.add_stroke(
            page.clone(),
            ToolKind::BallPoint,
            vec![0, 0, 0, 255],
            2.0,
            points(),
        )
        .unwrap();

        s.advance_time(10_000_000);
        s.stop_recording().unwrap();
        assert!(!s.is_recording());

        let stroke = &s.visible_strokes(page).unwrap()[0];
        let pos = s.playback_at(stroke.started_at_us).expect("應找得到錄音");
        assert_eq!(pos.offset_us, 3_500_000);
        assert!(pos.media_path.ends_with(".opus"));

        assert_eq!(s.recorded_duration_us(), 9_000_000);
    }

    #[test]
    fn search_reports_its_source() {
        let s = session("search");
        let page = s.first_page_id().unwrap();
        s.add_text(page.clone(), "線性代數筆記".into(), BlockStyle::Body)
            .unwrap();

        let stroke = s
            .add_stroke(
                page.clone(),
                ToolKind::Pencil,
                vec![0, 0, 0, 255],
                2.0,
                points(),
            )
            .unwrap();
        s.index_handwriting(page, stroke, "手寫的線性代數".into())
            .unwrap();

        let hits = s.search("線性".into(), 10);
        assert_eq!(hits.len(), 2);
        assert_eq!(hits[0].source, "text", "打字應排在手寫辨識之前");
        assert!(hits.iter().any(|h| h.source == "handwriting"));
    }

    #[test]
    fn feature_status_starts_with_only_core_notes_ready() {
        // 全新安裝、零權限：手寫與打字就該能用，其他都需要設定。
        let s = session("features");
        let all = s.feature_status();
        assert_eq!(all.len(), 6);

        let core = all.iter().find(|f| f.feature == "core_notes").unwrap();
        assert!(core.ready);
        assert_eq!(core.explanation, "可以使用");

        let transcription = all
            .iter()
            .find(|f| f.feature == "live_transcription")
            .unwrap();
        assert!(!transcription.ready);
        assert!(transcription.explanation.contains("麥克風"));
    }

    #[test]
    fn reporting_capabilities_unblocks_features() {
        let s = session("caps");
        s.report_capability("microphone".into(), "ready".into(), 0);
        assert!(
            s.feature_status()
                .iter()
                .find(|f| f.feature == "recording")
                .unwrap()
                .ready
        );

        s.report_capability("speech".into(), "ready".into(), 0);
        s.report_capability("asr_model".into(), "ready".into(), 0);
        assert!(
            s.feature_status()
                .iter()
                .find(|f| f.feature == "live_transcription")
                .unwrap()
                .ready
        );
    }

    #[test]
    fn unknown_capability_name_is_ignored_not_fatal() {
        let s = session("unknowncap");
        s.report_capability("teleportation".into(), "ready".into(), 0);
        assert_eq!(s.feature_status().len(), 6);
    }

    #[test]
    fn pending_download_size_is_reported() {
        let s = session("download");
        s.report_capability("asr_model".into(), "needs_download".into(), 230_686_720);
        s.report_capability("llm_model".into(), "needs_download".into(), 2_621_440_000);
        assert_eq!(s.pending_download_bytes(), 2_852_126_720);
    }

    #[test]
    fn export_crosses_the_boundary() {
        let s = session("export");
        let page = s.first_page_id().unwrap();
        s.add_text(page.clone(), "重點".into(), BlockStyle::Heading2)
            .unwrap();
        s.add_stroke(
            page,
            ToolKind::FountainPen,
            vec![0, 0, 0, 255],
            2.0,
            points(),
        )
        .unwrap();

        let md = s.export_markdown().unwrap();
        assert!(md.contains("## 重點"));
        assert!(md.contains("手寫內容"));
    }

    #[test]
    fn reopening_restores_everything_through_the_ffi() {
        let path = tmp("ffi-reopen");
        let block_text;
        let page;
        {
            let s =
                PadnoteSession::create(path.clone(), "線性代數".into(), 1_757_635_200_000, 0xA1)
                    .unwrap();
            page = s.first_page_id().unwrap();
            let b = s
                .add_text(page.clone(), "特徵值".into(), BlockStyle::Body)
                .unwrap();
            s.insert_text(b.clone(), 3, "與特徵向量".into()).unwrap();
            block_text = b;
        }

        let reopened = PadnoteSession::open_existing(path, 0xA1).unwrap();
        assert_eq!(reopened.title(), "線性代數");
        assert_eq!(
            reopened.block_text(block_text).unwrap().as_deref(),
            Some("特徵值與特徵向量")
        );
        assert_eq!(reopened.search("特徵".into(), 10).len(), 1);
    }

    #[test]
    fn text_editing_uses_character_indices_not_bytes() {
        // 用位元組索引會把中文切壞 —— 這條測試把它釘死。
        let s = session("charindex");
        let page = s.first_page_id().unwrap();
        let b = s
            .add_text(page, "線性代數".into(), BlockStyle::Body)
            .unwrap();

        s.insert_text(b.clone(), 2, "XX".into()).unwrap();
        assert_eq!(
            s.block_text(b.clone()).unwrap().as_deref(),
            Some("線性XX代數")
        );

        s.delete_text(b.clone(), 2, 2).unwrap();
        assert_eq!(s.block_text(b).unwrap().as_deref(), Some("線性代數"));
    }

    #[test]
    fn blob_and_image_round_trip() {
        let s = session("ffi-image");
        let page = s.first_page_id().unwrap();
        let blob = s.put_blob(b"png bytes".to_vec()).unwrap();
        let img = s.add_image(page, blob, 640.0, 480.0).unwrap();
        assert!(!img.is_empty());
    }

    #[test]
    fn audio_feed_reports_progress_across_the_boundary() {
        let s = session("ffi-audio");
        s.start_recording().unwrap();

        let pcm: Vec<f32> = (0..16_000).map(|i| (i as f32 * 0.3).sin() * 0.6).collect();
        let stats = s.feed_audio(pcm).unwrap();

        assert_eq!(stats.frames_written, 50, "1 秒 = 50 個 20ms 音框");
        assert_eq!(stats.recorded_us, 1_000_000);
        assert_eq!(stats.segments_dropped, 0);
    }

    #[test]
    fn feeding_audio_without_recording_throws() {
        let s = session("ffi-noaudio");
        assert!(s.feed_audio(vec![0.0; 100]).is_err());
    }

    #[test]
    fn transcripts_can_be_written_back_from_the_platform() {
        let s = session("ffi-transcript");
        let page = s.first_page_id().unwrap();
        s.advance_time(1_000_000);
        let rec = s.start_recording().unwrap();

        s.add_transcript(
            page,
            rec,
            vec![TranscriptWordInput {
                text: "特徵值".into(),
                start_us: 3_000_000,
                end_us: 3_800_000,
                confidence: 0.9,
            }],
        )
        .unwrap();

        assert_eq!(s.search("特徵".into(), 10).len(), 1);
        // C1：點轉錄詞跳回錄音的第 2 秒
        let pos = s.playback_at(3_000_000).expect("應對應到錄音");
        assert_eq!(pos.offset_us, 2_000_000);
    }

    #[test]
    fn vad_model_can_be_configured_across_the_boundary() {
        let s = session("ffi-vad");
        assert!(!s.uses_neural_vad(), "預設應為能量門檻法");

        s.set_vad_model("/nonexistent.onnx".into());
        assert!(!s.uses_neural_vad(), "不存在的模型不該被當成可用");
    }

    #[test]
    fn markdown_round_trips_across_the_boundary() {
        let s = session("ffi-import");
        let page = s.first_page_id().unwrap();
        s.add_text(page, "重點整理".into(), BlockStyle::Heading2)
            .unwrap();

        let md = s.export_markdown().unwrap();
        let pages = s.import_markdown(md).unwrap();

        assert!(!pages.is_empty());
        assert_eq!(s.search("重點".into(), 10).len(), 2, "原有的與匯入的各一份");
    }

    #[test]
    fn object_operations_cross_the_boundary() {
        let s = session("ffi-objects");
        let page = s.first_page_id().unwrap();
        let stroke = s
            .add_stroke(
                page.clone(),
                ToolKind::BallPoint,
                vec![0, 0, 0, 255],
                2.0,
                points(),
            )
            .unwrap();

        let obj = s.create_stroke_object(page.clone(), vec![stroke]).unwrap();
        s.translate_object(obj.clone(), 10.0, 20.0).unwrap();

        let t = s.object_transform(page, obj).unwrap();
        assert_eq!(t.len(), 6);
        assert_eq!((t[4], t[5]), (10.0, 20.0), "位移應反映在變換上");
    }

    #[test]
    fn grouping_and_ungrouping_cross_the_boundary() {
        let s = session("ffi-group");
        let page = s.first_page_id().unwrap();

        let mut objects = Vec::new();
        for _ in 0..2 {
            let stroke = s
                .add_stroke(
                    page.clone(),
                    ToolKind::BallPoint,
                    vec![0, 0, 0, 255],
                    2.0,
                    points(),
                )
                .unwrap();
            objects.push(s.create_stroke_object(page.clone(), vec![stroke]).unwrap());
        }

        let group = s.group_objects(page.clone(), objects.clone()).unwrap();
        s.translate_object(group.clone(), 50.0, 0.0).unwrap();

        // 群組的變換要傳到成員身上
        let member = s
            .object_transform(page.clone(), objects[0].clone())
            .unwrap();
        assert_eq!(member[4], 50.0, "成員應繼承群組的位移");

        s.ungroup(group).unwrap();
        let after = s.object_transform(page, objects[0].clone()).unwrap();
        assert_eq!(after[4], 50.0, "解散後位置不該跳動");
    }

    #[test]
    fn malformed_object_id_is_rejected() {
        let s = session("ffi-badobj");
        assert!(s.translate_object("not-a-uuid".into(), 1.0, 1.0).is_err());
    }

    #[test]
    fn version_helpers_are_exported() {
        assert_eq!(spec_version(), crate::SPEC_VERSION);
        assert!(can_open(1, 1));
        assert!(!can_open(99, 99));
    }
}
