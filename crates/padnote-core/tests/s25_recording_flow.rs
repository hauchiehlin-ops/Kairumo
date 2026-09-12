//! **S-25：錄音與轉錄的端到端流程**
//!
//! 驗證的不只是「能跑」，而是幾條不可妥協的不變式：
//! 1. 音檔在 `feed_audio` 當下就落地，不等轉錄
//! 2. 轉錄失敗**不影響**音檔完整性
//! 3. 轉錄結果的時間戳落在筆記本時間軸上，C1 跳轉因此成立
//! 4. 音檔是標準 Ogg-Opus，任何播放器都能開

use padnote_core::app::NotebookSession;
use padnote_core::asr::{AsrEngine, AsrError, AsrSegment};
use padnote_core::doc::{NotebookTime, TranscriptWord, Uuid};

/// 假引擎：回傳固定文字，或固定失敗。
#[derive(Debug)]
struct StubEngine {
    text: Option<&'static str>,
}

impl AsrEngine for StubEngine {
    fn feed(&mut self, _: &[f32]) -> Result<Vec<AsrSegment>, AsrError> {
        match self.text {
            Some(t) => Ok(vec![AsrSegment {
                text: t.into(),
                start_us: 0,
                end_us: 500_000,
                confidence: 0.92,
                is_final: true,
            }]),
            None => Err(AsrError::Backend("模型沒載入".into())),
        }
    }
    fn finish(&mut self) -> Result<Vec<AsrSegment>, AsrError> {
        Ok(Vec::new())
    }
    fn languages(&self) -> &[&str] {
        &["zh"]
    }
}

fn tmp(name: &str) -> std::path::PathBuf {
    let d = std::env::temp_dir().join(format!("padnote-s25-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    d
}

fn session(name: &str) -> NotebookSession {
    NotebookSession::create(tmp(name), "線性代數", 1_757_635_200_000, 0xA1).unwrap()
}

/// 有內容的語音訊號。
fn speech(samples: usize) -> Vec<f32> {
    (0..samples).map(|i| (i as f32 * 0.3).sin() * 0.6).collect()
}

fn silence(samples: usize) -> Vec<f32> {
    vec![0.0; samples]
}

fn audio_path(s: &NotebookSession, session_id: Uuid) -> std::path::PathBuf {
    s.package()
        .root()
        .join(format!("media/audio/{session_id}.opus"))
}

#[test]
fn s25_full_flow_recording_to_transcript_to_playback() {
    use padnote_core::recorder::TranscriptionWorker;

    let mut s = session("full");
    let page = s.first_page().unwrap();

    // 錄音從筆記本時間 10 秒開始
    s.advance_time(NotebookTime::from_micros(10_000_000));
    let rec = s.start_recording().unwrap();

    // 1 秒語音 + 1 秒靜音 ⇒ 切出一段
    s.feed_audio(&speech(16_000)).unwrap();
    s.feed_audio(&silence(16_000)).unwrap();

    // 在錄音中途寫一筆字（筆記本時間 13 秒）
    s.advance_time(NotebookTime::from_micros(13_000_000));

    // 背景 worker 處理待轉錄的段
    let mut worker = TranscriptionWorker::new();
    worker.enqueue(s.take_pending_segments());
    let mut engine = StubEngine {
        text: Some("特徵值與特徵向量"),
    };
    let outcome = worker.run(&mut engine);

    assert_eq!(outcome.completed, 1, "應完成一段轉錄");
    assert!(!outcome.words.is_empty());

    // 轉錄結果寫回筆記
    let words: Vec<TranscriptWord> = outcome.words;
    let first_word_time = words[0].start;
    s.add_transcript(page, rec, words).unwrap();

    s.advance_time(NotebookTime::from_micros(20_000_000));
    s.stop_recording().unwrap();

    // --- 不變式 3：轉錄詞落在筆記本時間軸上 ---
    assert!(
        first_word_time >= NotebookTime::from_micros(10_000_000),
        "詞的時間必須在錄音起點之後，實得 {first_word_time:?}"
    );

    // 點轉錄詞 ⇒ 跳回錄音的對應位置（功能 C1）
    let (path, offset) = s
        .timeline()
        .playback_at(first_word_time)
        .map(|(sess, off)| (sess.media_path.clone(), off))
        .expect("轉錄詞必須能對應到錄音位置");
    assert!(path.ends_with(".opus"));
    assert_eq!(
        offset,
        NotebookTime::from_micros(first_word_time.as_micros() - 10_000_000)
    );

    // 轉錄內容可被搜尋
    assert_eq!(s.search("特徵", 10).len(), 1);
}

#[test]
fn s25_audio_lands_before_any_transcription_happens() {
    // 不變式 1：音檔在 feed 當下就有內容，不等任何轉錄。
    let mut s = session("audio-first");
    let rec = s.start_recording().unwrap();

    s.feed_audio(&speech(16_000)).unwrap();
    assert_eq!(s.recorded_audio_us(), 1_000_000, "1 秒音訊應已編碼");

    s.stop_recording().unwrap();

    let bytes = std::fs::read(audio_path(&s, rec)).unwrap();
    assert!(!bytes.is_empty(), "音檔必須有內容");
    assert_eq!(&bytes[0..4], b"OggS");
}

#[test]
fn s25_transcription_failure_does_not_harm_the_audio() {
    use padnote_core::recorder::TranscriptionWorker;

    // 不變式 2：這正是 Notability 最大差評的情境 —— 轉錄失敗不該波及音檔。
    let mut s = session("asr-fails");
    let rec = s.start_recording().unwrap();

    s.feed_audio(&speech(16_000)).unwrap();
    s.feed_audio(&silence(16_000)).unwrap();

    let mut worker = TranscriptionWorker::new();
    worker.enqueue(s.take_pending_segments());
    let mut broken = StubEngine { text: None };
    let outcome = worker.run(&mut broken);

    assert_eq!(outcome.completed, 0);
    assert_eq!(outcome.retryable, 1, "失敗的段必須留著重試");

    s.stop_recording().unwrap();

    let bytes = std::fs::read(audio_path(&s, rec)).unwrap();
    assert!(
        bytes.len() > 1000,
        "音檔必須完整，實得 {} bytes",
        bytes.len()
    );
    assert_eq!(&bytes[0..4], b"OggS");

    // 之後換一個能用的引擎，仍能補上轉錄
    let mut good = StubEngine {
        text: Some("補救成功"),
    };
    assert_eq!(worker.run(&mut good).completed, 1, "重試必須可行");
}

#[test]
fn s25_feeding_without_recording_is_rejected() {
    let mut s = session("not-recording");
    assert!(s.feed_audio(&speech(1_000)).is_err());
    assert_eq!(s.recorded_audio_us(), 0);
}

#[test]
fn s25_backlog_is_reported_while_transcription_lags() {
    let mut s = session("backlog");
    s.start_recording().unwrap();

    s.feed_audio(&speech(16_000)).unwrap();
    s.feed_audio(&silence(16_000)).unwrap();

    assert!(s.transcription_backlog_us() > 0, "應回報轉錄落後");
    s.take_pending_segments();
    assert_eq!(s.transcription_backlog_us(), 0, "取出後應歸零");
}

#[test]
fn s25_audio_file_survives_reopen_and_is_still_linked() {
    let mut s = session("reopen");
    s.advance_time(NotebookTime::from_micros(2_000_000));
    let rec = s.start_recording().unwrap();
    s.feed_audio(&speech(16_000)).unwrap();
    s.advance_time(NotebookTime::from_micros(5_000_000));
    s.stop_recording().unwrap();

    let root = s.package().root().to_path_buf();
    drop(s);

    let reopened = NotebookSession::open(&root, 0xA1).unwrap();
    let sessions = reopened.timeline().sessions();
    assert_eq!(sessions.len(), 1);
    assert_eq!(sessions[0].id, rec);
    assert_eq!(
        sessions[0].ended_at,
        Some(NotebookTime::from_micros(5_000_000))
    );
    assert!(
        root.join(&sessions[0].media_path).exists(),
        "音檔路徑必須仍然有效"
    );
}

#[test]
fn s25_recorded_duration_is_still_queryable_after_stopping() {
    // 停止錄音後 pipeline 被取走，但 UI 仍要顯示「剛錄了 N 秒」。
    let mut s = session("duration-after-stop");
    s.start_recording().unwrap();
    s.feed_audio(&speech(16_000 * 2)).unwrap();
    assert_eq!(s.recorded_audio_us(), 2_000_000);

    s.stop_recording().unwrap();
    assert_eq!(
        s.recorded_audio_us(),
        2_000_000,
        "停止後歸零會讓 UI 顯示錯誤的錄音長度"
    );
}

#[test]
fn s25_multiple_recordings_accumulate() {
    let mut s = session("accumulate");
    for _ in 0..2 {
        s.start_recording().unwrap();
        s.feed_audio(&speech(16_000)).unwrap();
        s.stop_recording().unwrap();
    }
    assert_eq!(s.recorded_audio_us(), 2_000_000, "兩段各 1 秒");
}
