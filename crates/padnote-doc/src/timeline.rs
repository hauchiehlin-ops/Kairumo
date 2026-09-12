//! 統一時間軸（`docs/format-spec.md` §4）。
//!
//! 單一座標系 `NotebookTime`（自 manifest 的 `time_origin_unix_us` 起算的微秒）
//! 讓「點筆畫跳回當時錄音」退化成一次區間查詢。

use crate::Uuid;

/// 筆記本時間軸上的一個時刻，單位微秒。
///
/// 取自 monotonic clock，**不受系統時鐘調整影響**。u64 微秒可表示約 58 萬年。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug, Default)]
pub struct NotebookTime(pub u64);

impl NotebookTime {
    pub const ZERO: Self = Self(0);

    pub const fn from_micros(us: u64) -> Self {
        Self(us)
    }

    pub const fn as_micros(self) -> u64 {
        self.0
    }

    pub const fn as_millis(self) -> u64 {
        self.0 / 1_000
    }

    pub const fn as_secs_f64(self) -> f64 {
        self.0 as f64 / 1_000_000.0
    }

    /// 飽和加法：時間軸永不回捲。
    pub const fn saturating_add_micros(self, us: u64) -> Self {
        Self(self.0.saturating_add(us))
    }
}

/// 一段錄音。可與其他 session 重疊（例如補錄）。
#[derive(Clone, Debug)]
pub struct AudioSession {
    pub id: Uuid,
    pub started_at: NotebookTime,
    /// 錄音中時為 `None`。
    pub ended_at: Option<NotebookTime>,
    /// 相對筆記本根目錄的音檔路徑，如 `media/audio/<uuid>.opus`。
    pub media_path: String,
}

impl AudioSession {
    pub fn contains(&self, t: NotebookTime) -> bool {
        t >= self.started_at && self.ended_at.is_none_or(|e| t < e)
    }

    /// 此時刻對應到音檔內的播放偏移。
    pub fn offset_of(&self, t: NotebookTime) -> Option<NotebookTime> {
        self.contains(t)
            .then(|| NotebookTime(t.0 - self.started_at.0))
    }
}

/// 轉錄出的一個詞。
///
/// **時間戳記在筆記本時間軸上，而非音檔內偏移**（format-spec §4.1）。
/// 這讓使用者剪輯或合併錄音後，筆跡↔文字↔音訊的對應仍然成立。
#[derive(Clone, Debug)]
pub struct TranscriptWord {
    pub text: String,
    pub start: NotebookTime,
    pub end: NotebookTime,
    /// ASR 信心值 0.0–1.0；用於 UI 以灰字顯示低信心結果。
    pub confidence: f32,
}

/// 時間軸索引：把「某時刻在錄什麼」「某區間有哪些詞」變成便宜的查詢。
#[derive(Debug, Default)]
pub struct Timeline {
    sessions: Vec<AudioSession>,
    words: Vec<TranscriptWord>,
}

impl Timeline {
    pub fn new() -> Self {
        Self::default()
    }

    /// 插入並維持依 `started_at` 排序，使查詢可用二分搜尋。
    pub fn add_session(&mut self, s: AudioSession) {
        let pos = self
            .sessions
            .partition_point(|x| x.started_at <= s.started_at);
        self.sessions.insert(pos, s);
    }

    pub fn add_word(&mut self, w: TranscriptWord) {
        let pos = self.words.partition_point(|x| x.start <= w.start);
        self.words.insert(pos, w);
    }

    pub fn sessions(&self) -> &[AudioSession] {
        &self.sessions
    }

    /// C1：給定一個筆畫的落筆時刻，找出當時正在錄的 session 與播放偏移。
    ///
    /// session 可能重疊；回傳**最晚開始**的那個（最貼近使用者當下的錄音）。
    pub fn playback_at(&self, t: NotebookTime) -> Option<(&AudioSession, NotebookTime)> {
        self.sessions
            .iter()
            .rev()
            .find(|s| s.contains(t))
            .map(|s| (s, NotebookTime(t.0 - s.started_at.0)))
    }

    /// C4：取出某時間區間內的轉錄詞（半開區間 `[from, to)`）。
    pub fn words_in(&self, from: NotebookTime, to: NotebookTime) -> &[TranscriptWord] {
        let lo = self.words.partition_point(|w| w.start < from);
        let hi = self.words.partition_point(|w| w.start < to);
        &self.words[lo..hi]
    }

    /// 錄音總時長（已結束的 session 相加）。
    pub fn recorded_duration(&self) -> NotebookTime {
        NotebookTime(
            self.sessions
                .iter()
                .filter_map(|s| s.ended_at.map(|e| e.0 - s.started_at.0))
                .sum(),
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn session(start: u64, end: Option<u64>) -> AudioSession {
        AudioSession {
            id: Uuid::now_v7(),
            started_at: NotebookTime(start),
            ended_at: end.map(NotebookTime),
            media_path: "media/audio/x.opus".into(),
        }
    }

    fn word(text: &str, start: u64, end: u64) -> TranscriptWord {
        TranscriptWord {
            text: text.into(),
            start: NotebookTime(start),
            end: NotebookTime(end),
            confidence: 0.9,
        }
    }

    #[test]
    fn stroke_time_maps_to_audio_offset() {
        let mut tl = Timeline::new();
        tl.add_session(session(1_000_000, Some(5_000_000)));

        // 筆畫在 3.5s 落筆 → 應對應音檔內 2.5s
        let (_, offset) = tl.playback_at(NotebookTime(3_500_000)).expect("應在錄音中");
        assert_eq!(offset.as_micros(), 2_500_000);
    }

    #[test]
    fn time_outside_any_session_has_no_playback() {
        let mut tl = Timeline::new();
        tl.add_session(session(1_000_000, Some(2_000_000)));
        assert!(tl.playback_at(NotebookTime(500_000)).is_none());
        assert!(
            tl.playback_at(NotebookTime(2_000_000)).is_none(),
            "區間右開"
        );
    }

    #[test]
    fn overlapping_sessions_prefer_latest_started() {
        let mut tl = Timeline::new();
        tl.add_session(session(0, Some(10_000_000)));
        let later = session(4_000_000, Some(8_000_000));
        let later_id = later.id;
        tl.add_session(later);

        let (s, offset) = tl.playback_at(NotebookTime(5_000_000)).unwrap();
        assert_eq!(s.id, later_id, "重疊時應選最晚開始的 session");
        assert_eq!(offset.as_micros(), 1_000_000);
    }

    #[test]
    fn ongoing_session_contains_future_time() {
        let mut tl = Timeline::new();
        tl.add_session(session(1_000_000, None));
        assert!(tl.playback_at(NotebookTime(999_999_999)).is_some());
    }

    #[test]
    fn words_in_range_is_half_open() {
        let mut tl = Timeline::new();
        tl.add_word(word("線性", 1_000_000, 1_500_000));
        tl.add_word(word("代數", 1_500_000, 2_000_000));
        tl.add_word(word("特徵值", 3_000_000, 3_800_000));

        let got = tl.words_in(NotebookTime(1_000_000), NotebookTime(3_000_000));
        assert_eq!(
            got.iter().map(|w| w.text.as_str()).collect::<Vec<_>>(),
            ["線性", "代數"]
        );
    }

    #[test]
    fn words_inserted_out_of_order_stay_sorted() {
        let mut tl = Timeline::new();
        tl.add_word(word("後", 5_000_000, 5_500_000));
        tl.add_word(word("先", 1_000_000, 1_500_000));
        tl.add_word(word("中", 3_000_000, 3_500_000));

        let all = tl.words_in(NotebookTime::ZERO, NotebookTime(u64::MAX));
        assert_eq!(
            all.iter().map(|w| w.text.as_str()).collect::<Vec<_>>(),
            ["先", "中", "後"]
        );
    }

    #[test]
    fn recorded_duration_sums_finished_sessions_only() {
        let mut tl = Timeline::new();
        tl.add_session(session(0, Some(2_000_000)));
        tl.add_session(session(3_000_000, Some(4_000_000)));
        tl.add_session(session(9_000_000, None)); // 錄音中，不計入
        assert_eq!(tl.recorded_duration().as_micros(), 3_000_000);
    }
}
