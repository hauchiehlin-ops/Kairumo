//! 音檔的中繼資訊（工作項 S-42）。
//!
//! # 為什麼在核心，不在各平台做
//!
//! 「這段錄音多長」在 Apple 端可以問 AVFoundation、在 Android 端可以問
//! MediaMetadataRetriever —— 但那是兩份實作，而兩份實作遲早會對不起來。
//! 錄音卡片上寫的長度是**同一份資料**，兩個平台顯示不同的數字，使用者
//! 會以為同步壞了。
//!
//! 而且格式是我們自己寫的（`padnote-audio::OggOpusWriter`），granule 的
//! 語意與 pre-skip 的處理只有這裡最清楚。

/// 一段 Ogg-Opus 有多長（秒，四捨五入）。認不出來時回 0。
///
/// 回 0 而不是丟錯：長度是**顯示用**的資訊，讀不出來時卡片上寫 `00:00`
/// 仍然播得出聲音 —— 為了一個顯示欄位讓插入失敗，代價完全不對等。
#[uniffi::export]
pub fn audio_duration_seconds(bytes: Vec<u8>) -> u32 {
    match padnote_audio::ogg_opus_duration_us(&bytes) {
        // 四捨五入到秒：截斷的話 1.9 秒會顯示成 00:01，
        // 而使用者對照播放器看到的是 00:02。
        Some(us) => ((us + 500_000) / 1_000_000) as u32,
        None => 0,
    }
}

/// 一段錄音的中繼資訊。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiAudioInfo {
    /// 取樣率（固定 16 kHz，與編碼端一致）。
    pub sample_rate: u32,
    /// 長度（微秒）。讀不出來時為 0。
    pub duration_us: u64,
}

/// 串流解碼器（R1）。
///
/// # 為什麼要串流，而不是一個「解開整個檔案」的函式
///
/// 一小時錄音壓縮後約 14 MB，**解出來的 PCM 卻是 230 MB**
/// （16 kHz 單聲道 f32）。一次全解再送過 FFI，等於在手機上一次配置
/// 230 MB 並且整份複製到平台端 —— App 會直接被系統收掉。
///
/// 所以播放端是「跟我們要一小段」：`next_chunk` 每次回傳幾千個樣本，
/// 播放器排進緩衝區，播完再要下一段。
///
/// # 為什麼 iOS 需要這個
///
/// `AVAudioPlayer` **播不動 Ogg-Opus**，AVFoundation 也沒有內建的 Opus
/// 解碼器。Android 的 MediaPlayer 解得了，所以只有 Apple 端會用到它 ——
/// 但解碼放在核心，兩邊聽到的才保證是同一段聲音。
#[derive(uniffi::Object)]
pub struct FfiAudioDecoder {
    inner: std::sync::Mutex<padnote_audio::OggOpusDecoder>,
    info: FfiAudioInfo,
}

impl std::fmt::Debug for FfiAudioDecoder {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("FfiAudioDecoder")
            .field("info", &self.info)
            .finish()
    }
}

/// 開一個錄音來解碼。讀不到或不是合法的 Ogg-Opus 時回 `None`。
///
/// 回 `None` 而不是丟錯：播不出來是一個要顯示給使用者看的狀態，
/// 不是一個要往上拋的例外。
///
/// 寫成自由函式而不是建構子，是因為 **UniFFI 的建構子不能回
/// `Option<Arc<Self>>`** —— 它要求回傳型別就是 `Self` 或 `Arc<Self>`。
/// 為了這個限制改成丟錯的話，每個呼叫端都要多包一層 try。
#[uniffi::export]
pub fn audio_decoder_open(path: String) -> Option<std::sync::Arc<FfiAudioDecoder>> {
    let bytes = std::fs::read(&path).ok()?;
    FfiAudioDecoder::from_bytes(bytes)
}

#[uniffi::export]
impl FfiAudioDecoder {
    /// 解出下一段 PCM（16 kHz 單聲道 f32）。空陣列表示已經到結尾。
    ///
    /// `max_samples` 是上限，不是保證 —— 結尾那一段會比較短。
    pub fn next_chunk(&self, max_samples: u32) -> Vec<f32> {
        let mut guard = self.inner.lock().unwrap();
        guard
            .next_chunk(max_samples.max(1) as usize)
            .ok()
            .flatten()
            .unwrap_or_default()
    }

    pub fn info(&self) -> FfiAudioInfo {
        self.info.clone()
    }
}

impl FfiAudioDecoder {
    fn from_bytes(bytes: Vec<u8>) -> Option<std::sync::Arc<Self>> {
        let duration_us = padnote_audio::ogg_opus_duration_us(&bytes).unwrap_or(0);
        let decoder = padnote_audio::OggOpusDecoder::new(bytes).ok()?;
        let info = FfiAudioInfo {
            sample_rate: decoder.sample_rate(),
            duration_us,
        };
        Some(std::sync::Arc::new(Self {
            inner: std::sync::Mutex::new(decoder),
            info,
        }))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rubbish_reports_zero_rather_than_failing() {
        // 長度讀不出來不該讓插入失敗 —— 見上面的說明。
        assert_eq!(audio_duration_seconds(b"not audio".to_vec()), 0);
        assert_eq!(audio_duration_seconds(Vec::new()), 0);
    }

    fn sample_recording(frames: usize) -> Vec<u8> {
        let mut out = Vec::new();
        {
            let mut enc = padnote_audio::OpusEncoder::new().expect("encoder");
            let mut writer =
                padnote_audio::ogg::OggOpusWriter::with_pre_skip(&mut out, 9, enc.lookahead_48k())
                    .expect("writer");
            let pcm: Vec<f32> = (0..frames * 320)
                .map(|i| (i as f32 * 0.05).sin() * 0.4)
                .collect();
            for packet in enc.encode(&pcm).expect("encode") {
                writer.push(packet).expect("packet");
            }
            writer.finish().expect("finish");
        }
        out
    }

    #[test]
    fn the_decoder_streams_instead_of_returning_everything_at_once() {
        // 一次全解會在手機上一次配置幾百 MB，App 會被系統收掉。
        let decoder = FfiAudioDecoder::from_bytes(sample_recording(50)).expect("decoder");
        let first = decoder.next_chunk(1024);
        assert_eq!(first.len(), 1024, "應該剛好給滿一段");

        let mut total = first.len();
        loop {
            let chunk = decoder.next_chunk(1024);
            if chunk.is_empty() {
                break;
            }
            total += chunk.len();
        }
        // 50 個音框 × 320 樣本，扣掉前視延遲那一小段。
        assert!(total > 15_000 && total <= 16_000, "總共解出 {total} 個樣本");
    }

    #[test]
    fn the_reported_duration_matches_the_samples_that_come_out() {
        // 對不起來的話，播放進度條會跟實際聲音脫節 ——
        // 使用者看到的是「播完了但進度條還沒到底」。
        let decoder = FfiAudioDecoder::from_bytes(sample_recording(100)).expect("decoder");
        let info = decoder.info();
        assert_eq!(info.sample_rate, 16_000);

        let mut total = 0usize;
        loop {
            let chunk = decoder.next_chunk(4096);
            if chunk.is_empty() {
                break;
            }
            total += chunk.len();
        }
        let from_samples = total as u64 * 1_000_000 / info.sample_rate as u64;
        assert!(
            info.duration_us.abs_diff(from_samples) < 50_000,
            "標頭說 {} µs，解出來是 {from_samples} µs",
            info.duration_us
        );
    }

    #[test]
    fn a_file_that_is_not_audio_is_not_a_crash() {
        // 雲端來的檔案是不可信輸入。panic 會穿過 FFI 變成整個 App 閃退。
        let decoder = FfiAudioDecoder::from_bytes(b"definitely not ogg".to_vec());
        // 建得起來（Ogg 讀不到頁就是沒有封包），但解不出任何東西。
        if let Some(d) = decoder {
            assert!(d.next_chunk(1024).is_empty());
        }
    }

    #[test]
    fn a_missing_file_reports_none_rather_than_throwing() {
        assert!(audio_decoder_open("/no/such/recording.opus".into()).is_none());
    }

    #[test]
    fn a_two_second_recording_reports_two_seconds() {
        let mut out = Vec::new();
        {
            let mut writer = padnote_audio::OggOpusWriter::new(&mut out, 7).expect("writer");
            for _ in 0..100 {
                writer.push(vec![0u8; 8]).expect("packet");
            }
            writer.finish().expect("finish");
        }
        assert_eq!(audio_duration_seconds(out), 2);
    }
}
