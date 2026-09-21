//! Ogg-Opus 解碼（R1）。
//!
//! # 為什麼核心要有解碼器
//!
//! 寫入端一直只做編碼，理由是「播放交給平台原生解碼器」。那句話在 Android
//! 成立（MediaPlayer 解得了 Ogg-Opus），在 **iOS 不成立** ——
//! `AVAudioPlayer` 播不動 Ogg-Opus，AVFoundation 也沒有內建的 Opus 解碼器。
//!
//! 於是 Apple 端只剩兩條路：改用 iOS 播得動的格式（那要改檔案格式規格，
//! 並遷移 Android 既有的錄音），或是核心自己解。選後者的理由是檔案大小：
//! 語音 Opus 32 kbps 一小時約 14 MB，而同步走的是使用者自己的雲端空間。
//!
//! # 記憶體：壓縮的整包讀進來，解出來的串流吐出去
//!
//! 一小時錄音壓縮後約 14 MB，整包放記憶體沒問題。
//! **解出來的 PCM 才是問題**：一小時 16 kHz 單聲道 f32 是 230 MB。
//! 所以這裡串流的是**輸出**，不是輸入 —— 播放器邊播邊要一小段。
//! 一次全解再回傳會讓長錄音直接把 App 撐爆。
//!
//! # 解碼器是有狀態的
//!
//! Opus 的封包不是各自獨立的：解碼器帶著前一個封包的狀態（預測、
//! 重疊相加的尾巴）。所以**同一個 `Decoder` 必須從頭用到尾** ——
//! 每次要新資料就重建一個、再把前面的封包重解一遍，除了是 O(n²)，
//! 每一段的接縫還會有可以聽得出來的爆音。

use crate::encoder::{AudioError, SAMPLE_RATE_HZ};
use audiopus::coder::Decoder;
use audiopus::{Channels, SampleRate};
use std::collections::VecDeque;

const OGG_CAPTURE_PATTERN: &[u8; 4] = b"OggS";

/// Opus 單一封包最長 120 ms。以 48 kHz 計是 5760 個樣本 —— 我們自己的檔案
/// 只會用到 16 kHz/20 ms（320 個），但別的工具轉進來的可能不是。
const MAX_PACKET_SAMPLES: usize = 5_760;

/// Ogg-Opus 的 pre-skip 固定以 48 kHz 計數（規格要求），
/// 換算成我們的取樣率要按比例縮。
const GRANULE_RATE_HZ: u32 = 48_000;

/// Ogg 頁面切封包的狀態。
///
/// **封包可以跨頁**：段長 255 代表「還沒完」，要接下一段，甚至接到下一頁。
/// 我們自己寫出來的檔案不會這樣（32 kbps 的 20 ms 封包只有幾十位元組），
/// 但使用者用 ffmpeg 轉進來的會 —— 不處理的話那些檔案解出來是雜訊，
/// 而不是一個明確的錯誤。
///
/// 狀態與位元組分開放（`next_packet` 收 `bytes` 當參數），
/// 這樣持有它的結構就不必是自我參照的。
#[derive(Debug, Default)]
struct OggPacketCursor {
    offset: usize,
    /// 這一頁已經切出、還沒被取走的完整封包。
    ready: VecDeque<Vec<u8>>,
    /// 跨頁封包已累積的部分。
    partial: Vec<u8>,
}

impl OggPacketCursor {
    /// 下一個完整封包。`None` 表示沒有了。
    fn next_packet(&mut self, bytes: &[u8]) -> Option<Vec<u8>> {
        loop {
            if let Some(packet) = self.ready.pop_front() {
                return Some(packet);
            }
            if !self.read_page(bytes) {
                return None;
            }
        }
    }

    /// 讀一頁，把裡面的完整封包排進 `ready`。回傳 false 表示沒有頁了。
    fn read_page(&mut self, bytes: &[u8]) -> bool {
        // 找下一個頁首。檔案開頭可能有別的東西，硬性要求「第一個位元組
        // 就是頁首」會讓那些檔案完全讀不出來。
        while self.offset + 27 <= bytes.len()
            && &bytes[self.offset..self.offset + 4] != OGG_CAPTURE_PATTERN
        {
            self.offset += 1;
        }
        if self.offset + 27 > bytes.len() {
            return false;
        }

        let segments = bytes[self.offset + 26] as usize;
        let table_start = self.offset + 27;
        let table_end = table_start + segments;
        if table_end > bytes.len() {
            return false;
        }
        let payload_start = table_end;
        let payload_len: usize = bytes[table_start..table_end]
            .iter()
            .map(|&n| n as usize)
            .sum();
        if payload_start + payload_len > bytes.len() {
            return false;
        }

        // **先把 offset 推到下一頁。** 中途離開而沒推進的話，
        // 下一次會從同一頁重新開始，同一段音就被解兩次。
        let lacing_start = table_start;
        let lacing_end = table_end;
        self.offset = payload_start + payload_len;

        let mut cursor = payload_start;
        for i in lacing_start..lacing_end {
            let len = bytes[i] as usize;
            self.partial.extend_from_slice(&bytes[cursor..cursor + len]);
            cursor += len;
            // 段長 255 表示這個封包還沒結束，要接下一段。
            if len != 255 {
                let packet = std::mem::take(&mut self.partial);
                if !packet.is_empty() {
                    self.ready.push_back(packet);
                }
            }
        }
        true
    }
}

/// 一個封包是不是 Opus 的標頭（`OpusHead` / `OpusTags`）。
///
/// 這兩個不是音訊，餵進解碼器會得到錯誤。
fn is_header_packet(packet: &[u8]) -> bool {
    packet.starts_with(b"OpusHead") || packet.starts_with(b"OpusTags")
}

/// 從 `OpusHead` 取 pre-skip。不是那個標頭就回 `None`。
fn pre_skip_of(packet: &[u8]) -> Option<u16> {
    if !packet.starts_with(b"OpusHead") || packet.len() < 12 {
        return None;
    }
    Some(u16::from_le_bytes([packet[10], packet[11]]))
}

/// 串流解碼器：持有整份壓縮位元組，一次吐一小段 PCM。
pub struct OggOpusDecoder {
    bytes: Vec<u8>,
    decoder: Decoder,
    cursor: OggPacketCursor,
    /// 已解出、還沒被取走的樣本。
    decoded: VecDeque<f32>,
    /// 還要丟掉幾個開頭樣本（pre-skip，已換算成本機取樣率）。
    skip_remaining: usize,
    finished: bool,
}

impl std::fmt::Debug for OggOpusDecoder {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("OggOpusDecoder")
            .field("bytes", &self.bytes.len())
            .field("buffered", &self.decoded.len())
            .field("finished", &self.finished)
            .finish()
    }
}

impl OggOpusDecoder {
    /// `bytes` 是整份 `.opus` 檔。
    pub fn new(bytes: Vec<u8>) -> Result<Self, AudioError> {
        let decoder = Decoder::new(SampleRate::Hz16000, Channels::Mono)
            .map_err(|e| AudioError::Opus(e.to_string()))?;
        Ok(Self {
            bytes,
            decoder,
            cursor: OggPacketCursor::default(),
            decoded: VecDeque::new(),
            skip_remaining: 0,
            finished: false,
        })
    }

    /// 取樣率（固定 16 kHz，與編碼端一致）。
    pub fn sample_rate(&self) -> u32 {
        SAMPLE_RATE_HZ
    }

    /// 全部解完了、而且也取完了。
    pub fn is_exhausted(&self) -> bool {
        self.finished && self.decoded.is_empty()
    }

    /// 下一段 PCM，最多 `chunk_samples` 個樣本。`None` 表示結束。
    ///
    /// 這是長錄音該走的路：解出來的 PCM 不會整份留在記憶體裡。
    pub fn next_chunk(&mut self, chunk_samples: usize) -> Result<Option<Vec<f32>>, AudioError> {
        let want = chunk_samples.max(1);
        while self.decoded.len() < want && !self.finished {
            self.decode_one_packet()?;
        }
        if self.decoded.is_empty() {
            return Ok(None);
        }
        let take = want.min(self.decoded.len());
        Ok(Some(self.decoded.drain(..take).collect()))
    }

    /// 解一個封包進佇列。檔案結束時設 `finished`。
    fn decode_one_packet(&mut self) -> Result<(), AudioError> {
        let Some(packet) = self.cursor.next_packet(&self.bytes) else {
            self.finished = true;
            return Ok(());
        };
        if is_header_packet(&packet) {
            if let Some(pre_skip) = pre_skip_of(&packet) {
                // pre-skip 以 48 kHz 計數，換算成我們的取樣率。
                self.skip_remaining =
                    pre_skip as usize * SAMPLE_RATE_HZ as usize / GRANULE_RATE_HZ as usize;
            }
            return Ok(());
        }

        let mut pcm = vec![0f32; MAX_PACKET_SAMPLES];
        let signals = self
            .decoder
            .decode_float(Some(&packet), &mut pcm[..], false)
            .map_err(|e| AudioError::Opus(e.to_string()))?;

        let mut samples = &pcm[..signals];
        // 解碼器開頭那段是暖機用的，不是使用者錄到的聲音。
        // 不丟掉的話每段錄音前面都會多出一小段雜音，而且與顯示的長度差 80 ms。
        if self.skip_remaining > 0 {
            let drop = self.skip_remaining.min(samples.len());
            self.skip_remaining -= drop;
            samples = &samples[drop..];
        }
        self.decoded.extend(samples.iter().copied());
        Ok(())
    }

    /// 全部解出來。**只適合短音檔與測試** —— 長錄音請用 [`Self::next_chunk`]。
    pub fn decode_all(mut self) -> Result<Vec<f32>, AudioError> {
        let mut out = Vec::new();
        while let Some(chunk) = self.next_chunk(4096)? {
            out.extend_from_slice(&chunk);
        }
        Ok(out)
    }
}

/// 解開整份 Ogg-Opus。**只適合短音檔與測試。**
pub fn decode_ogg_opus(bytes: &[u8]) -> Result<Vec<f32>, AudioError> {
    OggOpusDecoder::new(bytes.to_vec())?.decode_all()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::encoder::{FRAME_SAMPLES, OpusEncoder};
    use crate::ogg::{OggOpusWriter, ogg_opus_duration_us};

    /// 一段可辨識的訊號：解碼之後要對得起來，不能只是「有輸出」。
    fn tone(n: usize) -> Vec<f32> {
        (0..n).map(|i| (i as f32 * 0.05).sin() * 0.4).collect()
    }

    /// 與正式錄音走同一條路：pre-skip 取自編碼器，不是寫死的。
    fn encode_tone(frames: usize) -> Vec<u8> {
        let mut buf = Vec::new();
        {
            let mut enc = OpusEncoder::new().unwrap();
            let mut w =
                OggOpusWriter::with_pre_skip(&mut buf, 0x7777, enc.lookahead_48k()).unwrap();
            for packet in enc.encode(&tone(FRAME_SAMPLES * frames)).unwrap() {
                w.push(packet).unwrap();
            }
            w.finish().unwrap();
        }
        buf
    }

    #[test]
    fn the_declared_pre_skip_matches_what_the_encoder_actually_needs() {
        // **這是一個真的會剪掉聲音的 bug 的回歸測試。**
        //
        // 舊版在 OpusHead 裡寫死 3840（80 ms），而那不是 libopus 的前視延遲。
        // 結果是每一段錄音的前 80 ms 被丟掉 —— 而且不只我們自己，
        // 任何照規格實作的播放器（VLC、ffmpeg）都會丟。
        let enc = OpusEncoder::new().unwrap();
        let lookahead = enc.lookahead_48k();
        assert!(
            lookahead > 0 && lookahead < 1_000,
            "前視延遲看起來不合理：{lookahead}"
        );

        let encoded = encode_tone(25);
        // 從檔案裡把 OpusHead 的 pre-skip 讀回來。
        let head = encoded
            .windows(8)
            .position(|w| w == b"OpusHead")
            .expect("找不到 OpusHead");
        let declared = u16::from_le_bytes([encoded[head + 10], encoded[head + 11]]);
        assert_eq!(declared, lookahead, "檔案宣告的 pre-skip 與編碼器對不上");
    }

    #[test]
    fn almost_nothing_is_lost_from_the_front() {
        // 承上：正確的 pre-skip 之下，解出來的樣本數應該非常接近餵進去的。
        // 差距只該是編碼器的前視延遲（約 6.5 ms），不是 80 ms。
        let frames = 50;
        let decoded = decode_ogg_opus(&encode_tone(frames)).unwrap();
        let fed = FRAME_SAMPLES * frames;
        let lost = fed.saturating_sub(decoded.len());
        let lost_ms = lost * 1000 / SAMPLE_RATE_HZ as usize;
        assert!(lost_ms <= 10, "開頭掉了 {lost_ms} ms（{lost} 個樣本）");
    }

    #[test]
    fn a_round_trip_gives_back_roughly_what_went_in() {
        // Opus 是有損的，所以比的是**長度與能量**，不是逐個樣本相等。
        // 逐樣本比較會失敗，而那不代表解碼壞了。
        let frames = 50; // 1 秒
        let encoded = encode_tone(frames);
        let decoded = decode_ogg_opus(&encoded).unwrap();

        let expected = FRAME_SAMPLES * frames;
        assert!(
            decoded.len().abs_diff(expected) <= FRAME_SAMPLES * 2,
            "解出 {} 個樣本，預期約 {expected}",
            decoded.len()
        );

        let energy: f32 = decoded.iter().map(|s| s * s).sum::<f32>() / decoded.len() as f32;
        assert!(
            energy > 0.01,
            "解出來是靜音（能量 {energy}），編碼或解碼掉了東西"
        );
    }

    #[test]
    fn the_decoded_length_matches_what_the_duration_parser_says() {
        // 兩個數字對不起來的話，播放進度條會跟實際聲音脫節 ——
        // 而使用者看到的是「播完了但進度條還沒到底」。
        let encoded = encode_tone(100); // 2 秒
        let decoded = decode_ogg_opus(&encoded).unwrap();
        let from_header = ogg_opus_duration_us(&encoded).unwrap();
        let from_samples = decoded.len() as u64 * 1_000_000 / SAMPLE_RATE_HZ as u64;
        assert!(
            from_header.abs_diff(from_samples) < 40_000,
            "標頭說 {from_header} µs，解出來是 {from_samples} µs"
        );
    }

    #[test]
    fn streaming_gives_the_same_samples_as_decoding_everything() {
        // 分段解與一次解必須完全相同。不同的話代表解碼器狀態在段與段之間
        // 被弄丟了 —— 症狀是每一段的接縫都有爆音。
        let encoded = encode_tone(30);
        let whole = decode_ogg_opus(&encoded).unwrap();

        let mut streamed = Vec::new();
        let mut dec = OggOpusDecoder::new(encoded).unwrap();
        while let Some(chunk) = dec.next_chunk(97).unwrap() {
            streamed.extend_from_slice(&chunk);
        }
        assert_eq!(whole, streamed);
    }

    #[test]
    fn the_pre_skip_is_dropped_exactly_once() {
        // 每個封包都扣一次 pre-skip 的話，聲音會被剪掉一大半。
        let short = decode_ogg_opus(&encode_tone(5)).unwrap();
        let long = decode_ogg_opus(&encode_tone(10)).unwrap();
        let delta = long.len() as i64 - short.len() as i64;
        assert_eq!(
            delta,
            (FRAME_SAMPLES * 5) as i64,
            "多 5 個音框就該多 5 個音框的樣本"
        );
    }

    #[test]
    fn rubbish_does_not_panic() {
        // 雲端來的檔案是不可信輸入。panic 會穿過 FFI 變成整個 App 閃退。
        assert!(decode_ogg_opus(b"not an ogg file").unwrap().is_empty());
        assert!(decode_ogg_opus(&[]).unwrap().is_empty());
        let truncated = {
            let mut e = encode_tone(20);
            e.truncate(e.len() / 2);
            e
        };
        // 截斷的檔案解到哪裡算哪裡，不該炸。
        let _ = decode_ogg_opus(&truncated);
    }

    #[test]
    fn header_packets_are_not_fed_to_the_decoder() {
        // OpusHead / OpusTags 餵進解碼器會回錯誤。整份解得出東西就代表
        // 它們被正確跳過了。
        assert!(!decode_ogg_opus(&encode_tone(10)).unwrap().is_empty());
    }
}
