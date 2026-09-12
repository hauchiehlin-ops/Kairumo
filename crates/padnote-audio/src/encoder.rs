//! Opus 編碼器封裝。

use audiopus::coder::Encoder;
use audiopus::{Application, Bitrate, Channels, SampleRate};
use std::fmt;

/// 語音錄音的位元率。
///
/// 32 kbps 在單聲道語音上已接近透明；再高只是浪費空間與電力。
/// 一小時約 14 MB，使用者的 iCloud 空間扛得住。
pub const VOICE_BITRATE: i32 = 32_000;

/// ASR 模型幾乎都吃 16 kHz 單聲道，錄製端直接對齊可省一次重採樣。
pub const SAMPLE_RATE_HZ: u32 = 16_000;

/// Opus 的音框必須是 2.5/5/10/20/40/60 ms。20 ms 是語音的慣用值，
/// 也剛好對應 VAD 的處理粒度。
pub const FRAME_MS: u32 = 20;
pub const FRAME_SAMPLES: usize = (SAMPLE_RATE_HZ * FRAME_MS / 1000) as usize;

#[derive(Debug)]
pub enum AudioError {
    Opus(String),
    /// 餵入的樣本數不是合法的 Opus 音框長度。
    BadFrameSize {
        got: usize,
        expected: usize,
    },
    Io(std::io::Error),
}

impl fmt::Display for AudioError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Opus(m) => write!(f, "Opus 編碼失敗：{m}"),
            Self::BadFrameSize { got, expected } => {
                write!(f, "音框長度錯誤：得到 {got} 個樣本，應為 {expected}")
            }
            Self::Io(e) => write!(f, "IO 錯誤：{e}"),
        }
    }
}

impl std::error::Error for AudioError {}

impl From<std::io::Error> for AudioError {
    fn from(e: std::io::Error) -> Self {
        Self::Io(e)
    }
}

/// 16 kHz 單聲道語音編碼器。
pub struct OpusEncoder {
    inner: Encoder,
    /// 不足一個音框的殘餘樣本，等下次補滿。
    tail: Vec<f32>,
    frames_encoded: u64,
}

impl fmt::Debug for OpusEncoder {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("OpusEncoder")
            .field("frames_encoded", &self.frames_encoded)
            .field("pending_samples", &self.tail.len())
            .finish()
    }
}

impl OpusEncoder {
    pub fn new() -> Result<Self, AudioError> {
        // Voip 模式針對語音最佳化：偏重清晰度而非音樂保真。
        let mut inner = Encoder::new(SampleRate::Hz16000, Channels::Mono, Application::Voip)
            .map_err(|e| AudioError::Opus(e.to_string()))?;
        inner
            .set_bitrate(Bitrate::BitsPerSecond(VOICE_BITRATE))
            .map_err(|e| AudioError::Opus(e.to_string()))?;
        Ok(Self {
            inner,
            tail: Vec::with_capacity(FRAME_SAMPLES),
            frames_encoded: 0,
        })
    }

    pub fn frames_encoded(&self) -> u64 {
        self.frames_encoded
    }

    /// 已編碼的音訊長度。
    pub fn encoded_duration_us(&self) -> u64 {
        self.frames_encoded * u64::from(FRAME_MS) * 1_000
    }

    /// 編碼任意長度的 PCM，回傳完整音框的封包。
    ///
    /// 不足一框的殘餘會保留到下次 —— 錄音來的緩衝長度不會剛好對齊音框，
    /// 每次都丟棄殘餘會造成週期性的爆音。
    pub fn encode(&mut self, pcm: &[f32]) -> Result<Vec<Vec<u8>>, AudioError> {
        self.tail.extend_from_slice(pcm);

        let mut packets = Vec::new();
        // 先把完整音框搬出來再編碼，避免同時借用 self.tail 與 self。
        while self.tail.len() >= FRAME_SAMPLES {
            let frame: Vec<f32> = self.tail.drain(..FRAME_SAMPLES).collect();
            packets.push(self.encode_frame(&frame)?);
        }
        Ok(packets)
    }

    /// 錄音結束：把殘餘補靜音湊成一框後沖出。
    ///
    /// 補靜音而非丟棄，因為那裡可能還有使用者最後半個字。
    pub fn finish(&mut self) -> Result<Option<Vec<u8>>, AudioError> {
        if self.tail.is_empty() {
            return Ok(None);
        }
        let mut frame = std::mem::take(&mut self.tail);
        frame.resize(FRAME_SAMPLES, 0.0);
        Ok(Some(self.encode_frame(&frame)?))
    }

    fn encode_frame(&mut self, frame: &[f32]) -> Result<Vec<u8>, AudioError> {
        if frame.len() != FRAME_SAMPLES {
            return Err(AudioError::BadFrameSize {
                got: frame.len(),
                expected: FRAME_SAMPLES,
            });
        }
        // Opus 封包上限 1275 bytes（單聲道 20ms 遠小於此）。
        let mut out = vec![0u8; 1275];
        let n = self
            .inner
            .encode_float(frame, &mut out)
            .map_err(|e| AudioError::Opus(e.to_string()))?;
        out.truncate(n);
        self.frames_encoded += 1;
        Ok(out)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 產生 440 Hz 正弦波，模擬有內容的音訊。
    fn tone(samples: usize) -> Vec<f32> {
        (0..samples)
            .map(|i| {
                (i as f32 * 2.0 * std::f32::consts::PI * 440.0 / SAMPLE_RATE_HZ as f32).sin() * 0.5
            })
            .collect()
    }

    #[test]
    fn encodes_whole_frames() {
        let mut e = OpusEncoder::new().unwrap();
        let packets = e.encode(&tone(FRAME_SAMPLES * 3)).unwrap();

        assert_eq!(packets.len(), 3);
        assert!(packets.iter().all(|p| !p.is_empty()));
        assert_eq!(e.frames_encoded(), 3);
        assert_eq!(e.encoded_duration_us(), 60_000);
    }

    #[test]
    fn partial_frames_are_buffered_not_dropped() {
        // 錄音緩衝不會剛好對齊音框，每次丟殘餘會造成週期性爆音。
        let mut e = OpusEncoder::new().unwrap();

        assert!(e.encode(&tone(100)).unwrap().is_empty(), "不足一框不該輸出");
        assert!(e.encode(&tone(100)).unwrap().is_empty());

        let packets = e.encode(&tone(FRAME_SAMPLES)).unwrap();
        assert_eq!(packets.len(), 1, "湊滿一框後才輸出");
    }

    #[test]
    fn finish_pads_the_tail_instead_of_discarding_it() {
        // 殘餘裡可能還有使用者最後半個字。
        let mut e = OpusEncoder::new().unwrap();
        e.encode(&tone(50)).unwrap();

        let last = e.finish().unwrap();
        assert!(last.is_some(), "殘餘必須被沖出");
        assert_eq!(e.frames_encoded(), 1);
    }

    #[test]
    fn finish_on_empty_encoder_yields_nothing() {
        let mut e = OpusEncoder::new().unwrap();
        assert!(e.finish().unwrap().is_none());
    }

    #[test]
    fn compression_is_substantial() {
        // 一小時 16kHz 未壓縮是 115MB；Opus 32kbps 約 14MB。
        let mut e = OpusEncoder::new().unwrap();
        let seconds = 1;
        let pcm = tone(SAMPLE_RATE_HZ as usize * seconds);
        let raw_bytes = pcm.len() * 2; // 對比 16-bit PCM

        let encoded: usize = e.encode(&pcm).unwrap().iter().map(Vec::len).sum();
        assert!(
            encoded * 4 < raw_bytes,
            "壓縮率不足：{encoded} vs {raw_bytes}"
        );
    }

    #[test]
    fn silence_compresses_smaller_than_speech() {
        let mut a = OpusEncoder::new().unwrap();
        let silence: usize = a
            .encode(&vec![0.0; FRAME_SAMPLES * 10])
            .unwrap()
            .iter()
            .map(Vec::len)
            .sum();

        let mut b = OpusEncoder::new().unwrap();
        let speech: usize = b
            .encode(&tone(FRAME_SAMPLES * 10))
            .unwrap()
            .iter()
            .map(Vec::len)
            .sum();

        assert!(silence < speech, "靜音 {silence} 應小於有聲 {speech}");
    }

    #[test]
    fn frame_size_matches_vad_granularity() {
        // 與 padnote-asr 的 VAD 音框對齊，省一次重新切分。
        assert_eq!(FRAME_SAMPLES, 320);
        assert_eq!(FRAME_MS, 20);
    }

    #[test]
    fn rejects_malformed_frame_directly() {
        let mut e = OpusEncoder::new().unwrap();
        assert!(matches!(
            e.encode_frame(&[0.0; 100]),
            Err(AudioError::BadFrameSize { got: 100, .. })
        ));
    }
}
