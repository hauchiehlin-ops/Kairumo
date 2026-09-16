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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rubbish_reports_zero_rather_than_failing() {
        // 長度讀不出來不該讓插入失敗 —— 見上面的說明。
        assert_eq!(audio_duration_seconds(b"not audio".to_vec()), 0);
        assert_eq!(audio_duration_seconds(Vec::new()), 0);
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
