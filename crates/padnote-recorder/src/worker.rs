//! 轉錄 worker：把待辨識的語音段送進 `AsrEngine`，產出落在筆記本時間軸上的詞。
//!
//! 與 `RecordingPipeline` 分離，執行在**低優先權的背景執行緒**上
//! （`architecture.md` §6.2 第三原則：寧可轉錄慢，不可寫字卡）。
//!
//! ## 失敗處理
//! 轉錄失敗**不會**讓錄音失敗。音檔早已落地，這裡只是重試計數加一；
//! 超過上限後改為人工觸發，避免無限耗電。

use crate::pipeline::PendingSegment;
use padnote_asr::{AsrEngine, AsrError, TranscriptionState};
use padnote_doc::{TranscriptWord, Uuid};

/// 一次處理的結果。
#[derive(Clone, Debug, Default)]
pub struct WorkerOutcome {
    pub words: Vec<TranscriptWord>,
    /// 成功轉錄的段數。
    pub completed: usize,
    /// 失敗但仍可重試的段數。
    pub retryable: usize,
    /// 失敗且已放棄的段數（需要人工觸發）。
    pub abandoned: usize,
}

/// 一個待處理項目及其重試狀態。
#[derive(Clone, Debug)]
struct Job {
    pending: PendingSegment,
    state: TranscriptionState,
}

/// 轉錄 worker。
#[derive(Debug)]
pub struct TranscriptionWorker {
    jobs: Vec<Job>,
    /// 已完成的段數，供監控。
    completed_total: u64,
}

impl Default for TranscriptionWorker {
    fn default() -> Self {
        Self::new()
    }
}

impl TranscriptionWorker {
    pub fn new() -> Self {
        Self {
            jobs: Vec::new(),
            completed_total: 0,
        }
    }

    pub fn enqueue(&mut self, segments: impl IntoIterator<Item = PendingSegment>) {
        self.jobs.extend(segments.into_iter().map(|pending| Job {
            pending,
            state: TranscriptionState::Pending,
        }));
    }

    pub fn pending_count(&self) -> usize {
        self.jobs.len()
    }

    pub fn completed_total(&self) -> u64 {
        self.completed_total
    }

    /// 處理佇列中的工作。
    ///
    /// `engine` 由呼叫端提供，因此可以在低記憶體時改用較小的模型，
    /// 或在使用者關閉轉錄時完全不呼叫。
    pub fn run(&mut self, engine: &mut dyn AsrEngine) -> WorkerOutcome {
        let mut outcome = WorkerOutcome::default();
        let mut remaining = Vec::new();

        for mut job in std::mem::take(&mut self.jobs) {
            if !job.state.is_resumable() {
                outcome.abandoned += 1;
                continue;
            }

            match transcribe(engine, &job.pending) {
                Ok(words) => {
                    outcome.words.extend(words);
                    outcome.completed += 1;
                    self.completed_total += 1;
                }
                Err(_) => {
                    // 音檔早已落地，失敗只是重試計數加一。
                    let attempts = match job.state {
                        TranscriptionState::Failed { attempts } => attempts + 1,
                        _ => 1,
                    };
                    job.state = TranscriptionState::Failed { attempts };
                    if job.state.is_resumable() {
                        outcome.retryable += 1;
                        remaining.push(job);
                    } else {
                        outcome.abandoned += 1;
                    }
                }
            }
        }

        self.jobs = remaining;
        outcome
    }

    /// 重置已放棄的工作，供使用者手動重試。
    pub fn retry_abandoned(&mut self) {
        for job in &mut self.jobs {
            job.state = TranscriptionState::Pending;
        }
    }
}

/// 把一段語音送進引擎，並把時間戳換算到筆記本時間軸。
fn transcribe(
    engine: &mut dyn AsrEngine,
    pending: &PendingSegment,
) -> Result<Vec<TranscriptWord>, AsrError> {
    let mut segments = engine.feed(&pending.segment.samples)?;
    segments.extend(engine.finish()?);

    let base = pending.notebook_start();
    Ok(segments
        .into_iter()
        .filter(|s| !s.text.trim().is_empty())
        .map(|s| TranscriptWord {
            text: s.text,
            // 引擎回報的是相對本段的偏移；加上段落在筆記本時間軸的起點。
            start: base.saturating_add_micros(s.start_us),
            end: base.saturating_add_micros(s.end_us),
            confidence: s.confidence,
        })
        .collect())
}

/// 這批詞對應的錄音 session。
pub fn session_of(pending: &PendingSegment) -> Uuid {
    pending.session
}

#[cfg(test)]
mod tests {
    use super::*;
    use padnote_asr::{AsrSegment, Segment};
    use padnote_doc::NotebookTime;

    #[derive(Debug)]
    struct FakeEngine {
        /// 每次 `feed` 回傳的結果；`None` 代表失敗。
        responses: Vec<Option<Vec<AsrSegment>>>,
        calls: usize,
    }

    impl FakeEngine {
        fn always(text: &str, start_us: u64, end_us: u64) -> Self {
            Self {
                responses: vec![Some(vec![AsrSegment {
                    text: text.into(),
                    start_us,
                    end_us,
                    confidence: 0.9,
                    is_final: true,
                }])],
                calls: 0,
            }
        }

        fn always_failing() -> Self {
            Self {
                responses: vec![None],
                calls: 0,
            }
        }
    }

    impl AsrEngine for FakeEngine {
        fn feed(&mut self, _: &[f32]) -> Result<Vec<AsrSegment>, AsrError> {
            let i = self.calls.min(self.responses.len() - 1);
            self.calls += 1;
            match &self.responses[i] {
                Some(s) => Ok(s.clone()),
                None => Err(AsrError::Backend("模型爆炸".into())),
            }
        }
        fn finish(&mut self) -> Result<Vec<AsrSegment>, AsrError> {
            Ok(Vec::new())
        }
        fn languages(&self) -> &[&str] {
            &["zh"]
        }
    }

    fn pending(session_start_us: u64, segment_start_us: u64) -> PendingSegment {
        PendingSegment {
            session: Uuid::from_bytes([1; 16]),
            session_start: NotebookTime::from_micros(session_start_us),
            segment: Segment {
                start_us: segment_start_us,
                end_us: segment_start_us + 1_000_000,
                samples: vec![0.1; 16_000],
            },
        }
    }

    #[test]
    fn words_land_on_the_notebook_timeline() {
        // 錄音從筆記本時間 10 秒開始，段落在錄音內的 3 秒，
        // 詞在段落內的 0.5 秒 ⇒ 筆記本時間 13.5 秒。
        let mut w = TranscriptionWorker::new();
        w.enqueue([pending(10_000_000, 3_000_000)]);

        let mut engine = FakeEngine::always("特徵值", 500_000, 800_000);
        let out = w.run(&mut engine);

        assert_eq!(out.completed, 1);
        assert_eq!(out.words.len(), 1);
        assert_eq!(out.words[0].text, "特徵值");
        assert_eq!(out.words[0].start, NotebookTime::from_micros(13_500_000));
        assert_eq!(out.words[0].end, NotebookTime::from_micros(13_800_000));
    }

    #[test]
    fn failure_keeps_the_job_for_retry() {
        // 音檔早已落地；轉錄失敗只是重試計數加一，不該丟掉任何東西。
        let mut w = TranscriptionWorker::new();
        w.enqueue([pending(0, 0)]);

        let mut engine = FakeEngine::always_failing();
        let out = w.run(&mut engine);

        assert_eq!(out.completed, 0);
        assert_eq!(out.retryable, 1);
        assert_eq!(w.pending_count(), 1, "工作必須留著重試");
    }

    #[test]
    fn repeated_failures_are_eventually_abandoned() {
        // 無限重試會把電池耗光。
        let mut w = TranscriptionWorker::new();
        w.enqueue([pending(0, 0)]);
        let mut engine = FakeEngine::always_failing();

        for _ in 0..10 {
            w.run(&mut engine);
        }
        assert_eq!(w.pending_count(), 0, "超過重試上限後應停止");
    }

    #[test]
    fn abandoned_jobs_can_be_retried_manually() {
        let mut w = TranscriptionWorker::new();
        w.enqueue([pending(0, 0)]);

        let mut failing = FakeEngine::always_failing();
        w.run(&mut failing);
        assert_eq!(w.pending_count(), 1);

        w.retry_abandoned();
        let mut working = FakeEngine::always("成功了", 0, 100_000);
        assert_eq!(w.run(&mut working).completed, 1);
    }

    #[test]
    fn empty_transcription_results_are_filtered_out() {
        // 模型對靜音常回傳空字串或空白，那些不該變成筆記內容。
        let mut w = TranscriptionWorker::new();
        w.enqueue([pending(0, 0)]);

        let mut engine = FakeEngine::always("   ", 0, 100_000);
        let out = w.run(&mut engine);

        assert_eq!(out.completed, 1, "算成功處理");
        assert!(out.words.is_empty(), "但不該產生空白詞");
    }

    #[test]
    fn multiple_segments_are_processed_in_order() {
        let mut w = TranscriptionWorker::new();
        w.enqueue([pending(0, 0), pending(0, 5_000_000)]);

        let mut engine = FakeEngine::always("字", 0, 100_000);
        let out = w.run(&mut engine);

        assert_eq!(out.completed, 2);
        assert_eq!(w.completed_total(), 2);
        assert!(out.words[1].start > out.words[0].start);
    }

    #[test]
    fn empty_queue_is_a_noop() {
        let mut w = TranscriptionWorker::new();
        let mut engine = FakeEngine::always("x", 0, 1);
        let out = w.run(&mut engine);
        assert_eq!(out.completed, 0);
        assert!(out.words.is_empty());
    }
}
