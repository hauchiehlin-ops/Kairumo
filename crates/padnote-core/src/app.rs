//! 應用層操作：把 storage / doc / ink / asr / search 串成使用者看得到的行為。
//!
//! 這一層的存在理由是**時序正確性**。例如「開始錄音」必須先落盤音檔、
//! 再建立 session、最後才啟動轉錄 —— 順序錯了就會出現「轉錄成功但音檔沒了」
//! 這種最糟的失敗模式（Notability 的教訓）。

use padnote_doc::{
    AudioSession, Block, BlockKind, Notebook, NotebookTime, Page, PageTemplate, Timeline,
    TranscriptWord, Uuid,
};
use padnote_export::{MarkdownOptions, to_markdown};
use padnote_ink::{InkRecord, Stroke, materialize};
use padnote_search::{DocId, SearchIndex, Source};
use padnote_storage::{NotebookPackage, StorageError};
use std::fmt;

#[derive(Debug)]
pub enum AppError {
    Storage(StorageError),
    /// 已在錄音中又要求開始錄音。
    AlreadyRecording,
    NotRecording,
    PageNotFound(Uuid),
}

impl fmt::Display for AppError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Storage(e) => write!(f, "{e}"),
            Self::AlreadyRecording => write!(f, "已經在錄音中"),
            Self::NotRecording => write!(f, "目前沒有錄音"),
            Self::PageNotFound(id) => write!(f, "找不到頁面：{id}"),
        }
    }
}

impl std::error::Error for AppError {}

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
#[derive(Debug)]
pub struct NotebookSession {
    package: NotebookPackage,
    notebook: Notebook,
    timeline: Timeline,
    index: SearchIndex,
    recording: RecordingState,
    /// 單調遞增的筆記本時間。由平台層以 monotonic clock 餵入。
    now: NotebookTime,
}

impl NotebookSession {
    pub fn create(
        root: impl Into<std::path::PathBuf>,
        title: &str,
        now_unix_ms: u64,
    ) -> Result<Self, AppError> {
        let package = NotebookPackage::create(root, title, now_unix_ms)?;
        let id = Uuid::now_v7();
        let mut notebook = Notebook::new(id, title);
        notebook.add_page(Page::new(Uuid::now_v7(), PageTemplate::Lined));

        Ok(Self {
            package,
            notebook,
            timeline: Timeline::new(),
            index: SearchIndex::new(),
            recording: RecordingState::Idle,
            now: NotebookTime::ZERO,
        })
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

    pub fn add_page(&mut self, template: PageTemplate) -> Uuid {
        let id = Uuid::now_v7();
        self.notebook.add_page(Page::new(id, template));
        id
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

    pub fn add_text_block(
        &mut self,
        page: Uuid,
        content: &str,
        style: padnote_doc::TextStyle,
    ) -> Result<Uuid, AppError> {
        let id = Uuid::now_v7();
        let block = Block {
            id,
            kind: BlockKind::Text {
                content: content.into(),
                style,
            },
            position: None,
            created_at: self.now,
        };
        let page_ref = self
            .notebook
            .page_mut(page)
            .ok_or(AppError::PageNotFound(page))?;
        page_ref.add_block(block);

        self.index.insert(
            DocId::new(
                &self.notebook.id.to_string(),
                &page.to_string(),
                &id.to_string(),
            ),
            Source::Text,
            content,
        );
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
        self.timeline.add_session(AudioSession {
            id: session,
            started_at: self.now,
            ended_at: None,
            media_path: format!("media/audio/{session}.opus"),
        });
        self.recording = RecordingState::Recording {
            session,
            started_at: self.now,
        };
        Ok(session)
    }

    pub fn stop_recording(&mut self) -> Result<Uuid, AppError> {
        let RecordingState::Recording { session, .. } = self.recording else {
            return Err(AppError::NotRecording);
        };
        // Timeline 內的 session 由 close 更新；此處重建以維持排序不變式。
        let mut rebuilt = Timeline::new();
        for s in self.timeline.sessions() {
            let mut s = s.clone();
            if s.id == session {
                s.ended_at = Some(self.now);
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
        self.recording = RecordingState::Idle;
        Ok(session)
    }

    /// 寫入一段轉錄結果。時間戳已在筆記本時間軸上。
    pub fn add_transcript(
        &mut self,
        page: Uuid,
        session: Uuid,
        words: Vec<TranscriptWord>,
    ) -> Result<Uuid, AppError> {
        let text: String = words.iter().map(|w| w.text.as_str()).collect();
        for w in words {
            self.timeline.add_word(w);
        }

        let id = Uuid::now_v7();
        let block = Block {
            id,
            kind: BlockKind::Transcript {
                session,
                text: text.clone(),
            },
            position: None,
            created_at: self.now,
        };
        self.notebook
            .page_mut(page)
            .ok_or(AppError::PageNotFound(page))?
            .add_block(block);

        self.index.insert(
            DocId::new(
                &self.notebook.id.to_string(),
                &page.to_string(),
                &id.to_string(),
            ),
            Source::Transcript,
            &text,
        );
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
        NotebookSession::create(tmp(name), "線性代數", 1_757_635_200_000).unwrap()
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
