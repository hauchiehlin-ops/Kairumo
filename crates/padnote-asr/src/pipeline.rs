//! 錄音到轉錄的管線編排（`docs/architecture.md` §6.1）。
//!
//! ```text
//! 麥克風 → RingBuffer ─┬→ Opus 編碼 → .opus（原始音檔，永不丟）
//!                      └→ 16kHz → VAD → SegmentQueue → ASR worker
//! ```
//!
//! 這一層不碰任何模型，只負責**時序與排程**，因此可完整單元測試 ——
//! 換 ASR 引擎不影響這裡的正確性。

use std::collections::VecDeque;

/// 音訊環形緩衝。
///
/// 滿了就覆蓋最舊的資料。這是刻意的：**寧可丟掉尚未處理的舊音訊，
/// 也不能阻塞錄音執行緒** —— 阻塞會造成實際的音訊掉樣，那是不可回復的損失。
/// （已落盤的 .opus 不受影響，這裡丟的只是待 ASR 處理的副本。）
#[derive(Debug)]
pub struct RingBuffer {
    buf: Vec<f32>,
    write: usize,
    filled: usize,
    /// 因緩衝滿而被覆蓋的樣本數，供監控與告警。
    overruns: u64,
}

impl RingBuffer {
    pub fn with_capacity(samples: usize) -> Self {
        assert!(samples > 0, "容量不得為 0");
        Self {
            buf: vec![0.0; samples],
            write: 0,
            filled: 0,
            overruns: 0,
        }
    }

    pub fn capacity(&self) -> usize {
        self.buf.len()
    }

    pub fn len(&self) -> usize {
        self.filled
    }

    pub fn is_empty(&self) -> bool {
        self.filled == 0
    }

    pub fn overruns(&self) -> u64 {
        self.overruns
    }

    /// 寫入。超過容量的部分會覆蓋最舊資料並累計 `overruns`。
    pub fn push(&mut self, samples: &[f32]) {
        for &s in samples {
            self.buf[self.write] = s;
            self.write = (self.write + 1) % self.buf.len();
            if self.filled == self.buf.len() {
                self.overruns += 1;
            } else {
                self.filled += 1;
            }
        }
    }

    /// 取出最舊的 `n` 個樣本。不足時回傳全部現有的。
    pub fn drain(&mut self, n: usize) -> Vec<f32> {
        let take = n.min(self.filled);
        let start = (self.write + self.buf.len() - self.filled) % self.buf.len();
        let mut out = Vec::with_capacity(take);
        for i in 0..take {
            out.push(self.buf[(start + i) % self.buf.len()]);
        }
        self.filled -= take;
        out
    }
}

/// 語音活動偵測。真實實作為 Silero VAD；此 trait 讓管線可測。
pub trait VoiceActivityDetector: Send + Sync + std::fmt::Debug {
    /// 回傳此音框是否為語音。
    fn is_speech(&mut self, frame: &[f32]) -> bool;
}

/// 以能量為準的參考實作。**僅供測試與極端降級使用** —— 真實環境請用 Silero VAD，
/// 能量法在有背景噪音時會把冷氣聲當成語音。
#[derive(Debug)]
pub struct EnergyVad {
    pub threshold: f32,
}

impl VoiceActivityDetector for EnergyVad {
    fn is_speech(&mut self, frame: &[f32]) -> bool {
        if frame.is_empty() {
            return false;
        }
        let rms = (frame.iter().map(|s| s * s).sum::<f32>() / frame.len() as f32).sqrt();
        rms > self.threshold
    }
}

/// 一段待轉錄的語音。
#[derive(Clone, Debug, PartialEq)]
pub struct Segment {
    /// 相對錄音起點的微秒偏移。
    pub start_us: u64,
    pub end_us: u64,
    pub samples: Vec<f32>,
}

impl Segment {
    pub fn duration_us(&self) -> u64 {
        self.end_us - self.start_us
    }
}

/// VAD 分段狀態機。
///
/// 兩個關鍵參數：
/// - **hangover**：語音結束後再等一段時間才切斷，避免把句中的自然停頓切成兩句
/// - **max_segment**：再長也要強制切斷，否則連續講話會讓首字延遲無限增長
///   （違反 C2 的 ≤2s 部分結果要求）
#[derive(Debug)]
pub struct Segmenter {
    vad: Box<dyn VoiceActivityDetector>,
    frame_samples: usize,
    sample_rate: u32,
    hangover_frames: usize,
    max_segment_samples: usize,

    in_speech: bool,
    silence_run: usize,
    current: Vec<f32>,
    segment_start_us: u64,
    consumed_samples: u64,
}

impl Segmenter {
    pub fn new(
        vad: Box<dyn VoiceActivityDetector>,
        sample_rate: u32,
        frame_ms: u32,
        hangover_ms: u32,
        max_segment_ms: u32,
    ) -> Self {
        let frame_samples = (sample_rate * frame_ms / 1000) as usize;
        Self {
            vad,
            frame_samples: frame_samples.max(1),
            sample_rate,
            hangover_frames: (hangover_ms / frame_ms.max(1)) as usize,
            max_segment_samples: (sample_rate * max_segment_ms / 1000) as usize,
            in_speech: false,
            silence_run: 0,
            current: Vec::new(),
            segment_start_us: 0,
            consumed_samples: 0,
        }
    }

    fn samples_to_us(&self, samples: u64) -> u64 {
        samples * 1_000_000 / u64::from(self.sample_rate)
    }

    /// 餵入音訊，回傳本次切出的完整語音段。
    pub fn feed(&mut self, pcm: &[f32]) -> Vec<Segment> {
        let mut out = Vec::new();
        for frame in pcm.chunks(self.frame_samples) {
            let speech = self.vad.is_speech(frame);

            if speech {
                if !self.in_speech {
                    self.in_speech = true;
                    self.segment_start_us = self.samples_to_us(self.consumed_samples);
                }
                self.silence_run = 0;
                self.current.extend_from_slice(frame);
            } else if self.in_speech {
                self.silence_run += 1;
                // hangover 期間的靜音也要收進去，否則尾音會被切掉。
                self.current.extend_from_slice(frame);
                if self.silence_run > self.hangover_frames {
                    out.push(self.close_segment());
                }
            }

            self.consumed_samples += frame.len() as u64;

            // 強制切斷：連續講話不得讓首字延遲無限增長。
            if self.in_speech && self.current.len() >= self.max_segment_samples {
                out.push(self.close_segment());
            }
        }
        out
    }

    /// 錄音結束，沖出殘餘。
    pub fn finish(&mut self) -> Option<Segment> {
        self.in_speech.then(|| self.close_segment())
    }

    fn close_segment(&mut self) -> Segment {
        let samples = std::mem::take(&mut self.current);
        let end_us = self.segment_start_us + self.samples_to_us(samples.len() as u64);
        self.in_speech = false;
        self.silence_run = 0;
        Segment {
            start_us: self.segment_start_us,
            end_us,
            samples,
        }
    }
}

/// 轉錄工作佇列。
///
/// **排程原則**（`architecture.md` §6.2）：ASR 永遠讓路給 UI 與墨跡。
/// 寧可轉錄慢，不可寫字卡。
#[derive(Debug, Default)]
pub struct SegmentQueue {
    queue: VecDeque<Segment>,
    /// 佇列上限。超過時丟棄**最舊**的待處理段 —— 使用者最在意的是剛講的話。
    capacity: usize,
    dropped: u64,
}

impl SegmentQueue {
    pub fn new(capacity: usize) -> Self {
        Self {
            queue: VecDeque::new(),
            capacity,
            dropped: 0,
        }
    }

    pub fn push(&mut self, s: Segment) {
        if self.capacity > 0 && self.queue.len() >= self.capacity {
            self.queue.pop_front();
            self.dropped += 1;
        }
        self.queue.push_back(s);
    }

    pub fn pop(&mut self) -> Option<Segment> {
        self.queue.pop_front()
    }

    pub fn len(&self) -> usize {
        self.queue.len()
    }

    pub fn is_empty(&self) -> bool {
        self.queue.is_empty()
    }

    /// 被丟棄的段數。非零代表 ASR 跟不上錄音速度，應告警或降級模型。
    pub fn dropped(&self) -> u64 {
        self.dropped
    }

    /// 佇列積壓的音訊總時長。UI 用它顯示「轉錄落後 N 秒」。
    pub fn backlog_us(&self) -> u64 {
        self.queue.iter().map(|s| s.duration_us()).sum()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const SR: u32 = 16_000;

    fn loud(n: usize) -> Vec<f32> {
        vec![0.5; n]
    }
    fn quiet(n: usize) -> Vec<f32> {
        vec![0.0; n]
    }

    fn segmenter(hangover_ms: u32, max_ms: u32) -> Segmenter {
        Segmenter::new(
            Box::new(EnergyVad { threshold: 0.1 }),
            SR,
            20,
            hangover_ms,
            max_ms,
        )
    }

    // ---- RingBuffer ----

    #[test]
    fn ring_buffer_is_fifo() {
        let mut rb = RingBuffer::with_capacity(10);
        rb.push(&[1.0, 2.0, 3.0]);
        assert_eq!(rb.drain(2), vec![1.0, 2.0]);
        assert_eq!(rb.drain(10), vec![3.0]);
        assert!(rb.is_empty());
    }

    #[test]
    fn ring_buffer_overwrites_oldest_rather_than_blocking() {
        // 阻塞錄音執行緒會造成真正的音訊掉樣，那才是不可回復的損失。
        let mut rb = RingBuffer::with_capacity(3);
        rb.push(&[1.0, 2.0, 3.0, 4.0, 5.0]);
        assert_eq!(rb.len(), 3);
        assert_eq!(rb.overruns(), 2);
        assert_eq!(rb.drain(3), vec![3.0, 4.0, 5.0], "應保留最新的");
    }

    #[test]
    fn ring_buffer_wraps_correctly() {
        let mut rb = RingBuffer::with_capacity(4);
        rb.push(&[1.0, 2.0, 3.0]);
        assert_eq!(rb.drain(2), vec![1.0, 2.0]);
        rb.push(&[4.0, 5.0, 6.0]);
        assert_eq!(rb.drain(10), vec![3.0, 4.0, 5.0, 6.0]);
        assert_eq!(rb.overruns(), 0);
    }

    // ---- VAD ----

    #[test]
    fn energy_vad_distinguishes_loud_from_silence() {
        let mut vad = EnergyVad { threshold: 0.1 };
        assert!(vad.is_speech(&loud(320)));
        assert!(!vad.is_speech(&quiet(320)));
        assert!(!vad.is_speech(&[]));
    }

    // ---- Segmenter ----

    #[test]
    fn emits_segment_after_hangover_elapses() {
        let mut seg = segmenter(100, 30_000);
        // 200ms 語音 + 200ms 靜音（> 100ms hangover）
        let mut out = seg.feed(&loud(SR as usize / 5));
        assert!(out.is_empty(), "語音進行中不該切段");

        out = seg.feed(&quiet(SR as usize / 5));
        assert_eq!(out.len(), 1);
        assert_eq!(out[0].start_us, 0);
        assert!(out[0].duration_us() > 200_000, "尾音應被收進段內");
    }

    #[test]
    fn short_pause_does_not_split_a_sentence() {
        // 句中的自然停頓不該被切開，否則轉錄會變成破碎的短句。
        let mut seg = segmenter(300, 30_000);
        seg.feed(&loud(SR as usize / 5));
        let out = seg.feed(&quiet(SR as usize / 10)); // 100ms < 300ms hangover
        assert!(out.is_empty(), "短停頓不該切段");
    }

    #[test]
    fn force_splits_at_max_length() {
        // 沒有這條，連續講話會讓首字延遲無限增長，違反 C2 的 ≤2s 要求。
        let mut seg = segmenter(100, 500);
        let out = seg.feed(&loud(SR as usize * 2)); // 2 秒不間斷
        assert!(out.len() >= 3, "應被強制切成多段，實得 {}", out.len());
    }

    #[test]
    fn silence_only_produces_nothing() {
        let mut seg = segmenter(100, 30_000);
        assert!(seg.feed(&quiet(SR as usize)).is_empty());
        assert!(seg.finish().is_none());
    }

    #[test]
    fn finish_flushes_trailing_speech() {
        // 使用者按下停止時仍在講話 —— 這段不能丟。
        let mut seg = segmenter(1_000, 30_000);
        assert!(seg.feed(&loud(SR as usize / 10)).is_empty());

        let tail = seg.finish().expect("殘餘語音必須沖出");
        assert!(!tail.samples.is_empty());
    }

    #[test]
    fn segment_timestamps_advance_across_segments() {
        let mut seg = segmenter(60, 30_000);
        let mut all = seg.feed(&loud(SR as usize / 10));
        all.extend(seg.feed(&quiet(SR as usize / 5)));
        all.extend(seg.feed(&loud(SR as usize / 10)));
        all.extend(seg.feed(&quiet(SR as usize / 5)));

        assert_eq!(all.len(), 2);
        assert!(
            all[1].start_us > all[0].end_us,
            "第二段必須晚於第一段：{} vs {}",
            all[1].start_us,
            all[0].end_us
        );
    }

    // ---- Queue ----

    fn seg_of(start: u64, dur: u64) -> Segment {
        Segment {
            start_us: start,
            end_us: start + dur,
            samples: vec![0.0; 16],
        }
    }

    #[test]
    fn queue_drops_oldest_when_full() {
        // 使用者最在意剛講的話，積壓時該丟舊的。
        let mut q = SegmentQueue::new(2);
        q.push(seg_of(0, 100));
        q.push(seg_of(100, 100));
        q.push(seg_of(200, 100));

        assert_eq!(q.len(), 2);
        assert_eq!(q.dropped(), 1);
        assert_eq!(q.pop().unwrap().start_us, 100, "最舊的該被丟掉");
    }

    #[test]
    fn backlog_reports_total_pending_audio() {
        let mut q = SegmentQueue::new(10);
        q.push(seg_of(0, 1_000_000));
        q.push(seg_of(1_000_000, 2_000_000));
        assert_eq!(q.backlog_us(), 3_000_000, "UI 要用它顯示『轉錄落後 3 秒』");
    }

    #[test]
    fn unbounded_queue_never_drops() {
        let mut q = SegmentQueue::new(0);
        for i in 0..100 {
            q.push(seg_of(i * 10, 10));
        }
        assert_eq!(q.len(), 100);
        assert_eq!(q.dropped(), 0);
    }
}
