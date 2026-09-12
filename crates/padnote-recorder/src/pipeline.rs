//! 錄音管線：PCM 進、Opus 檔與語音段出。**不做任何辨識**。

use padnote_asr::{Segment, SegmentQueue, Segmenter, VoiceActivityDetector};
use padnote_audio::encoder::FRAME_MS;
use padnote_audio::{AudioError, OggOpusWriter, OpusEncoder};
use padnote_doc::{NotebookTime, Uuid};
use std::io::Write;

/// 16 kHz 單聲道 —— 錄製、編碼、VAD、ASR 全線一致，不需要任何重採樣。
pub const SAMPLE_RATE_HZ: u32 = 16_000;

/// VAD 判定為靜音後仍等待的時間。
///
/// 太短會把句中的自然停頓切成兩句；太長則拖累首字延遲。
const HANGOVER_MS: u32 = 400;

/// 語音段的長度上限。
///
/// 這個值直接決定**轉錄延遲**：ASR 是段級處理（見 `padnote-asr-paraformer`
/// 的說明），文字要等整段結束才出得來。連續講話時，使用者最久要等這麼久。
///
/// 取捨：
/// - 太長 → 延遲高，違反 C2 的「≤2 秒部分結果」
/// - 太短 → ASR 看到的上下文少，辨識品質下降
///
/// 5 秒是折衷值。⚠️ **真正的甜蜜點要用 `padnote-bench` 的中文測試集
/// 實測不同長度的 CER 後決定**（TODO H2）。
const MAX_SEGMENT_MS: u32 = 5_000;

/// 佇列上限（段數）。超過代表 ASR 跟不上錄音速度。
const QUEUE_CAPACITY: usize = 64;

#[derive(Debug)]
pub enum RecorderError {
    Audio(AudioError),
    Io(std::io::Error),
}

impl std::fmt::Display for RecorderError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Audio(e) => write!(f, "{e}"),
            Self::Io(e) => write!(f, "IO 錯誤：{e}"),
        }
    }
}

impl std::error::Error for RecorderError {}

impl From<AudioError> for RecorderError {
    fn from(e: AudioError) -> Self {
        Self::Audio(e)
    }
}

impl From<std::io::Error> for RecorderError {
    fn from(e: std::io::Error) -> Self {
        Self::Io(e)
    }
}

/// 一次 `feed()` 的結果。
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct FeedOutcome {
    /// 本次寫進 Opus 檔的音框數。
    pub frames_written: u64,
    /// 本次切出的完整語音段數。
    pub segments_queued: usize,
    /// 因佇列滿而被丟棄的段數（累計）。非零代表 ASR 跟不上。
    pub segments_dropped: u64,
}

/// 錄音管線。
///
/// 型別參數 `W` 是音檔的輸出目標。測試用 `Vec<u8>`，正式用 `BufWriter<File>`。
pub struct RecordingPipeline<W: Write> {
    ogg: OggOpusWriter<W>,
    encoder: OpusEncoder,
    segmenter: Segmenter,
    queue: SegmentQueue,
    session_id: Uuid,
    /// 錄音在筆記本時間軸上的起點（format-spec §4）。
    session_start: NotebookTime,
    finished: bool,
}

impl<W: Write> std::fmt::Debug for RecordingPipeline<W> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("RecordingPipeline")
            .field("session_id", &self.session_id)
            .field("session_start", &self.session_start)
            .field("encoded_us", &self.encoder.encoded_duration_us())
            .field("queued", &self.queue.len())
            .finish()
    }
}

impl<W: Write> RecordingPipeline<W> {
    pub fn new(
        sink: W,
        session_id: Uuid,
        session_start: NotebookTime,
        vad: Box<dyn VoiceActivityDetector>,
    ) -> Result<Self, RecorderError> {
        // serial 取 session id 前 4 bytes，讓 Ogg 串流在檔案層級可辨識。
        let serial = u32::from_le_bytes(session_id.as_bytes()[0..4].try_into().unwrap());

        Ok(Self {
            ogg: OggOpusWriter::new(sink, serial)?,
            encoder: OpusEncoder::new()?,
            segmenter: Segmenter::new(vad, SAMPLE_RATE_HZ, FRAME_MS, HANGOVER_MS, MAX_SEGMENT_MS),
            queue: SegmentQueue::new(QUEUE_CAPACITY),
            session_id,
            session_start,
            finished: false,
        })
    }

    pub fn session_id(&self) -> Uuid {
        self.session_id
    }

    /// 已寫入音檔的時長。
    pub fn recorded_duration_us(&self) -> u64 {
        self.encoder.encoded_duration_us()
    }

    /// 待轉錄的音訊總時長。UI 用它顯示「轉錄落後 N 秒」。
    pub fn backlog_us(&self) -> u64 {
        self.queue.backlog_us()
    }

    /// 語音段的長度上限（微秒）。UI 可用它告訴使用者最久要等多久才看到文字。
    pub fn max_segment_us() -> u64 {
        u64::from(MAX_SEGMENT_MS) * 1_000
    }

    /// 餵入麥克風取樣。
    ///
    /// **順序不可調換**：先把音訊寫進檔案，再做 VAD 分段。
    /// 如果 VAD 或分段出錯，音訊已經安全了。
    pub fn feed(&mut self, pcm: &[f32]) -> Result<FeedOutcome, RecorderError> {
        // (1) 音檔優先落地 —— 這一步失敗才算真正的錄音失敗。
        let packets = self.encoder.encode(pcm)?;
        let frames_written = packets.len() as u64;
        for p in packets {
            self.ogg.push(p)?;
        }

        // (2) 分段只入列，不辨識。辨識由背景 worker 負責。
        let segments = self.segmenter.feed(pcm);
        let segments_queued = segments.len();
        for s in segments {
            self.queue.push(s);
        }

        Ok(FeedOutcome {
            frames_written,
            segments_queued,
            segments_dropped: self.queue.dropped(),
        })
    }

    /// 結束錄音：沖出編碼器殘餘與分段器殘餘，並寫出 Ogg 結尾頁。
    ///
    /// 冪等 —— 重複呼叫不會重複寫入。
    pub fn finish(&mut self) -> Result<FeedOutcome, RecorderError> {
        if self.finished {
            return Ok(FeedOutcome::default());
        }

        let mut frames_written = 0;
        if let Some(tail) = self.encoder.finish()? {
            self.ogg.push(tail)?;
            frames_written += 1;
        }
        self.ogg.finish()?;

        let mut segments_queued = 0;
        if let Some(tail) = self.segmenter.finish() {
            self.queue.push(tail);
            segments_queued += 1;
        }

        self.finished = true;
        Ok(FeedOutcome {
            frames_written,
            segments_queued,
            segments_dropped: self.queue.dropped(),
        })
    }

    /// 取出待轉錄的語音段，交給背景 worker。
    pub fn take_segments(&mut self) -> Vec<PendingSegment> {
        let mut out = Vec::new();
        while let Some(s) = self.queue.pop() {
            out.push(PendingSegment {
                session: self.session_id,
                session_start: self.session_start,
                segment: s,
            });
        }
        out
    }
}

/// 一段待轉錄的語音，帶著換算回筆記本時間軸所需的資訊。
#[derive(Clone, Debug)]
pub struct PendingSegment {
    pub session: Uuid,
    /// 錄音起點在筆記本時間軸上的位置。
    pub session_start: NotebookTime,
    pub segment: Segment,
}

impl PendingSegment {
    /// 這段語音在筆記本時間軸上的起點。
    pub fn notebook_start(&self) -> NotebookTime {
        self.session_start
            .saturating_add_micros(self.segment.start_us)
    }
}

#[cfg(test)]
impl RecordingPipeline<Vec<u8>> {
    /// 取出已寫出的位元組，僅供測試。
    fn ogg_bytes_for_test(&self) -> &[u8] {
        self.ogg.inner()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use padnote_asr::EnergyVad;

    fn vad() -> Box<dyn VoiceActivityDetector> {
        Box::new(EnergyVad { threshold: 0.1 })
    }

    fn pipeline() -> RecordingPipeline<Vec<u8>> {
        RecordingPipeline::new(
            Vec::new(),
            Uuid::from_bytes([0xAB; 16]),
            NotebookTime::from_micros(5_000_000),
            vad(),
        )
        .unwrap()
    }

    fn speech(samples: usize) -> Vec<f32> {
        (0..samples).map(|i| (i as f32 * 0.3).sin() * 0.6).collect()
    }

    fn silence(samples: usize) -> Vec<f32> {
        vec![0.0; samples]
    }

    #[test]
    fn audio_is_written_even_when_there_is_no_speech() {
        // 全靜音時 VAD 不產生任何段，但音檔仍然必須有內容 ——
        // 使用者可能只是聲音太小，那段錄音不該憑空消失。
        let mut p = pipeline();
        let out = p.feed(&silence(16_000)).unwrap();

        assert_eq!(out.segments_queued, 0);
        assert_eq!(out.frames_written, 50, "1 秒 = 50 個 20ms 音框");
        assert_eq!(p.recorded_duration_us(), 1_000_000);
    }

    #[test]
    fn pipeline_holds_no_asr_engine() {
        // 這是 S-25 的核心不變式：管線在型別層次上就無法呼叫模型，
        // 因此「轉錄拖慢錄音」或「轉錄失敗丟音訊」不可能發生。
        // 這條測試用 Debug 輸出作為結構的近似檢查。
        let p = pipeline();
        let dbg = format!("{p:?}");
        assert!(!dbg.contains("engine"), "管線不該持有任何 ASR 引擎：{dbg}");
        assert!(dbg.contains("queued"));
    }

    #[test]
    fn speech_is_segmented_and_queued() {
        let mut p = pipeline();
        p.feed(&speech(16_000 / 2)).unwrap(); // 0.5 秒語音
        let out = p.feed(&silence(16_000 / 2)).unwrap(); // 0.5 秒靜音 > hangover

        assert_eq!(out.segments_queued, 1);
        assert_eq!(p.take_segments().len(), 1);
        assert!(p.take_segments().is_empty(), "取出後佇列應清空");
    }

    #[test]
    fn segment_timestamps_map_onto_the_notebook_timeline() {
        // 錄音從筆記本時間 5 秒開始；段落在錄音內的 0 秒 ⇒ 筆記本時間 5 秒。
        let mut p = pipeline();
        p.feed(&speech(16_000 / 2)).unwrap();
        p.feed(&silence(16_000 / 2)).unwrap();

        let pending = p.take_segments();
        assert_eq!(
            pending[0].notebook_start(),
            NotebookTime::from_micros(5_000_000)
        );
        assert_eq!(pending[0].session, Uuid::from_bytes([0xAB; 16]));
    }

    #[test]
    fn later_segments_have_later_notebook_times() {
        let mut p = pipeline();
        // 第一段
        p.feed(&speech(16_000 / 2)).unwrap();
        p.feed(&silence(16_000)).unwrap();
        // 第二段
        p.feed(&speech(16_000 / 2)).unwrap();
        p.feed(&silence(16_000)).unwrap();

        let pending = p.take_segments();
        assert_eq!(pending.len(), 2);
        assert!(
            pending[1].notebook_start() > pending[0].notebook_start(),
            "第二段必須晚於第一段"
        );
    }

    #[test]
    fn finish_flushes_both_tails() {
        // 使用者按停止時可能還在講話，而且編碼器裡有不足一框的殘餘。
        let mut p = pipeline();
        p.feed(&speech(100)).unwrap(); // 不足一個音框，也不足以觸發分段

        let out = p.finish().unwrap();
        assert_eq!(out.frames_written, 1, "編碼器殘餘必須補齊沖出");
        assert_eq!(out.segments_queued, 1, "分段器殘餘必須沖出");
    }

    #[test]
    fn finish_is_idempotent() {
        let mut p = pipeline();
        p.feed(&speech(16_000)).unwrap();
        p.finish().unwrap();
        assert_eq!(p.finish().unwrap(), FeedOutcome::default());
    }

    #[test]
    fn produces_a_playable_ogg_file() {
        let mut p =
            RecordingPipeline::new(Vec::new(), Uuid::now_v7(), NotebookTime::ZERO, vad()).unwrap();
        p.feed(&speech(16_000)).unwrap();
        p.finish().unwrap();

        let bytes = p.ogg_bytes_for_test();
        assert_eq!(&bytes[0..4], b"OggS");
        assert!(bytes.windows(8).any(|w| w == b"OpusHead"));
    }

    #[test]
    fn backlog_reports_pending_audio_duration() {
        let mut p = pipeline();
        p.feed(&speech(16_000 / 2)).unwrap();
        p.feed(&silence(16_000 / 2)).unwrap();

        assert!(p.backlog_us() > 0, "有段在等轉錄時應回報落後時間");
        p.take_segments();
        assert_eq!(p.backlog_us(), 0);
    }

    #[test]
    fn queue_overflow_drops_oldest_but_keeps_recording() {
        // ASR 完全跟不上時，音檔仍然要繼續寫 —— 掉的只是待辨識的副本。
        let mut p = pipeline();
        for _ in 0..(QUEUE_CAPACITY + 10) {
            p.feed(&speech(16_000 / 2)).unwrap();
            p.feed(&silence(16_000)).unwrap();
        }
        let out = p.feed(&silence(16_000)).unwrap();
        assert!(out.segments_dropped > 0, "應回報有段被丟棄");
        assert!(
            p.recorded_duration_us() > 10_000_000,
            "音檔必須完整，不受佇列溢位影響"
        );
    }
}
