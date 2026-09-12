//! Ogg 容器封裝（`format-spec.md` §2：`media/audio/<uuid>.opus`）。
//!
//! 用標準 Ogg-Opus 而非自訂容器，因為**資料要帶得走**：使用者應該能用
//! VLC、ffmpeg、任何播放器打開自己的錄音，不需要 Padnote。
//!
//! 只實作寫入端 —— 播放交給平台原生解碼器（AVFoundation / ExoPlayer）。

use crate::encoder::{AudioError, FRAME_SAMPLES, SAMPLE_RATE_HZ};
use std::io::Write;

const OGG_CAPTURE_PATTERN: &[u8; 4] = b"OggS";
const HEADER_TYPE_BOS: u8 = 0x02; // beginning of stream
const HEADER_TYPE_EOS: u8 = 0x04; // end of stream

/// Opus 解碼器需要的前置樣本數（規格建議值，48 kHz 基準）。
const PRE_SKIP: u16 = 3_840;

/// 寫出 Ogg-Opus 檔案。
///
/// **邊錄邊寫**，不在記憶體累積 —— 一小時錄音累積在記憶體裡，
/// App 被系統回收時就全沒了。
pub struct OggOpusWriter<W: Write> {
    out: W,
    serial: u32,
    page_seq: u32,
    /// 48 kHz 基準的樣本位置（Ogg-Opus 規格固定用 48 kHz 計數，
    /// 即使實際取樣率是 16 kHz）。
    granule: u64,
    packets: Vec<Vec<u8>>,
    finished: bool,
}

impl<W: Write> std::fmt::Debug for OggOpusWriter<W> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("OggOpusWriter")
            .field("serial", &self.serial)
            .field("page_seq", &self.page_seq)
            .field("granule", &self.granule)
            .finish()
    }
}

impl<W: Write> OggOpusWriter<W> {
    /// `serial` 用來區分同一個 Ogg 檔內的多條串流；單一錄音給任意值即可。
    pub fn new(out: W, serial: u32) -> Result<Self, AudioError> {
        let mut w = Self {
            out,
            serial,
            page_seq: 0,
            granule: 0,
            packets: Vec::new(),
            finished: false,
        };
        // OpusHead 與 OpusTags 各自獨立成頁，這是 Ogg-Opus 規格的要求。
        w.write_page(&[&opus_head()], HEADER_TYPE_BOS, 0)?;
        w.write_page(&[&opus_tags()], 0, 0)?;
        Ok(w)
    }

    /// 加入一個編碼好的 Opus 封包（20 ms）。
    pub fn push(&mut self, packet: Vec<u8>) -> Result<(), AudioError> {
        self.packets.push(packet);
        // 每 50 個封包（1 秒）刷一頁。頁太大時中途當機會損失較多。
        if self.packets.len() >= 50 {
            self.flush_packets(0)?;
        }
        Ok(())
    }

    /// 寫出結尾頁。**必須呼叫**，否則播放器讀不到總長度。
    pub fn finish(&mut self) -> Result<(), AudioError> {
        if self.finished {
            return Ok(());
        }
        self.flush_packets(HEADER_TYPE_EOS)?;
        self.finished = true;
        Ok(())
    }

    fn flush_packets(&mut self, header_type: u8) -> Result<(), AudioError> {
        if self.packets.is_empty() && header_type == 0 {
            return Ok(());
        }
        // 每個封包 20 ms；Ogg-Opus 的 granule 固定以 48 kHz 計數。
        let samples_48k = FRAME_SAMPLES as u64 * 48_000 / u64::from(SAMPLE_RATE_HZ);
        self.granule += samples_48k * self.packets.len() as u64;

        let packets = std::mem::take(&mut self.packets);
        let refs: Vec<&[u8]> = packets.iter().map(Vec::as_slice).collect();
        let granule = self.granule;
        self.write_page(&refs, header_type, granule)
    }

    fn write_page(
        &mut self,
        packets: &[&[u8]],
        header_type: u8,
        granule: u64,
    ) -> Result<(), AudioError> {
        let mut segments: Vec<u8> = Vec::new();
        for p in packets {
            let mut remaining = p.len();
            while remaining >= 255 {
                segments.push(255);
                remaining -= 255;
            }
            segments.push(remaining as u8);
        }

        let mut page = Vec::with_capacity(27 + segments.len() + 1024);
        page.extend_from_slice(OGG_CAPTURE_PATTERN);
        page.push(0); // 版本
        page.push(header_type);
        page.extend_from_slice(&granule.to_le_bytes());
        page.extend_from_slice(&self.serial.to_le_bytes());
        page.extend_from_slice(&self.page_seq.to_le_bytes());
        page.extend_from_slice(&0u32.to_le_bytes()); // CRC 佔位
        page.push(segments.len() as u8);
        page.extend_from_slice(&segments);
        for p in packets {
            page.extend_from_slice(p);
        }

        let crc = ogg_crc32(&page);
        page[22..26].copy_from_slice(&crc.to_le_bytes());

        self.out.write_all(&page)?;
        self.page_seq += 1;
        Ok(())
    }
}

fn opus_head() -> Vec<u8> {
    let mut h = Vec::with_capacity(19);
    h.extend_from_slice(b"OpusHead");
    h.push(1); // 版本
    h.push(1); // 聲道數
    h.extend_from_slice(&PRE_SKIP.to_le_bytes());
    h.extend_from_slice(&SAMPLE_RATE_HZ.to_le_bytes()); // 原始取樣率（僅供參考）
    h.extend_from_slice(&0i16.to_le_bytes()); // 輸出增益
    h.push(0); // 聲道映射family
    h
}

fn opus_tags() -> Vec<u8> {
    const VENDOR: &[u8] = b"padnote";
    let mut t = Vec::new();
    t.extend_from_slice(b"OpusTags");
    t.extend_from_slice(&(VENDOR.len() as u32).to_le_bytes());
    t.extend_from_slice(VENDOR);
    t.extend_from_slice(&0u32.to_le_bytes()); // 使用者註解數
    t
}

/// Ogg 用的 CRC-32（多項式 0x04C11DB7，無反轉、無初始/最終 XOR）。
fn ogg_crc32(data: &[u8]) -> u32 {
    let mut crc: u32 = 0;
    for &byte in data {
        crc ^= u32::from(byte) << 24;
        for _ in 0..8 {
            crc = if crc & 0x8000_0000 != 0 {
                (crc << 1) ^ 0x04C1_1DB7
            } else {
                crc << 1
            };
        }
    }
    crc
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::encoder::OpusEncoder;

    fn tone(n: usize) -> Vec<f32> {
        (0..n).map(|i| (i as f32 * 0.1).sin() * 0.5).collect()
    }

    fn write_sample(frames: usize) -> Vec<u8> {
        let mut buf = Vec::new();
        {
            let mut w = OggOpusWriter::new(&mut buf, 0x1234).unwrap();
            let mut enc = OpusEncoder::new().unwrap();
            for packet in enc.encode(&tone(FRAME_SAMPLES * frames)).unwrap() {
                w.push(packet).unwrap();
            }
            w.finish().unwrap();
        }
        buf
    }

    #[test]
    fn produces_a_valid_ogg_container() {
        let buf = write_sample(5);
        assert_eq!(&buf[0..4], OGG_CAPTURE_PATTERN, "必須以 OggS 開頭");
        assert_eq!(buf[5], HEADER_TYPE_BOS, "第一頁必須標記為串流開始");
    }

    #[test]
    fn headers_are_present_and_in_order() {
        // 播放器靠這兩個 header 判斷這是 Opus 串流。
        let buf = write_sample(3);
        let head = buf.windows(8).position(|w| w == b"OpusHead").unwrap();
        let tags = buf.windows(8).position(|w| w == b"OpusTags").unwrap();
        assert!(head < tags, "OpusHead 必須在 OpusTags 之前");
    }

    #[test]
    fn declares_mono_16khz() {
        let buf = write_sample(1);
        let at = buf.windows(8).position(|w| w == b"OpusHead").unwrap();
        assert_eq!(buf[at + 9], 1, "聲道數應為 1");
        let rate = u32::from_le_bytes(buf[at + 12..at + 16].try_into().unwrap());
        assert_eq!(rate, SAMPLE_RATE_HZ);
    }

    #[test]
    fn end_of_stream_is_marked() {
        // 沒有 EOS 標記的話，播放器讀不到總長度，進度條會壞掉。
        let buf = write_sample(4);
        let pages: Vec<usize> = (0..buf.len() - 4)
            .filter(|&i| &buf[i..i + 4] == OGG_CAPTURE_PATTERN)
            .collect();
        let last = *pages.last().unwrap();
        assert_eq!(buf[last + 5] & HEADER_TYPE_EOS, HEADER_TYPE_EOS);
    }

    #[test]
    fn page_sequence_numbers_increment() {
        let buf = write_sample(4);
        let seqs: Vec<u32> = (0..buf.len() - 27)
            .filter(|&i| &buf[i..i + 4] == OGG_CAPTURE_PATTERN)
            .map(|i| u32::from_le_bytes(buf[i + 18..i + 22].try_into().unwrap()))
            .collect();
        assert!(seqs.len() >= 3);
        assert!(
            seqs.windows(2).all(|w| w[1] == w[0] + 1),
            "頁序號必須連續：{seqs:?}"
        );
    }

    #[test]
    fn crc_is_computed_over_the_whole_page() {
        let buf = write_sample(2);
        let crc = u32::from_le_bytes(buf[22..26].try_into().unwrap());
        assert_ne!(crc, 0, "CRC 佔位未被填回");
    }

    #[test]
    fn granule_advances_at_48khz_regardless_of_sample_rate() {
        // Ogg-Opus 規格固定以 48 kHz 計 granule，即使實際錄的是 16 kHz。
        // 搞錯的話播放器顯示的時長會是實際的 1/3。
        let buf = write_sample(50);
        let mut granules = Vec::new();
        for i in 0..buf.len() - 27 {
            if &buf[i..i + 4] == OGG_CAPTURE_PATTERN {
                granules.push(u64::from_le_bytes(buf[i + 6..i + 14].try_into().unwrap()));
            }
        }
        let last = *granules.last().unwrap();
        // 50 個 20ms 音框 = 1 秒 = 48000 個 48kHz 樣本
        assert_eq!(last, 48_000, "1 秒音訊的 granule 應為 48000，實得 {last}");
    }

    #[test]
    fn finish_is_idempotent() {
        let mut w = OggOpusWriter::new(Vec::new(), 1).unwrap();
        w.finish().unwrap();
        let len = w.out.len();
        w.finish().unwrap();
        assert_eq!(w.out.len(), len, "重複 finish 不該再寫出資料");
    }
}
