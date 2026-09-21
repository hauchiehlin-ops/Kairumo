//! 加密套件的框架格式（H-CRYPTO）。
//!
//! # 為什麼是逐框加密，不是整檔加密
//!
//! 同步的正確性建立在 `doc/ops/*.oplog` 是 **append-only** 之上：
//! 同一個檔名只會變長，較長的那一份是超集。
//!
//! 整檔加密會打破它 —— 每次追加都得把整個檔案重新加密一次，
//! 而新的密文與舊的**一個位元組都不一樣**（nonce 換了）。
//! 檔案仍然會變長，所以「較長的是超集」勉強還成立，
//! 但每寫一筆字就要重傳整個檔案，而且壓實不能再靠位元組拼接。
//!
//! 逐框加密則完全保住那條不變式：
//!
//! ```text
//! [4 bytes 長度 (u32 LE)][sealed][4 bytes 長度][sealed]...
//! ```
//!
//! 每一批操作自己密封成一個框架，追加就是接在後面。
//! **壓實仍然只是把位元組接起來** —— 不需要解密，也就不需要密碼。
//!
//! # AAD 綁檔名
//!
//! 密封時把檔名當作附加驗證資料。少了它，把 A 檔的密文搬到 B 檔的位置
//! 仍然解得開 —— 內容雖然還是讀不懂，但重排本身就足以破壞資料。

use padnote_crypto::envelope::{CryptoError, Dek};

/// 框架的長度前綴位元組數。
pub const FRAME_HEADER_LEN: usize = 4;

/// 把一批位元組密封成一個框架（含長度前綴）。
pub fn seal_frame(dek: &Dek, plaintext: &[u8], aad: &[u8]) -> Result<Vec<u8>, CryptoError> {
    let sealed = dek.seal(plaintext, aad)?;
    let mut out = Vec::with_capacity(FRAME_HEADER_LEN + sealed.len());
    out.extend_from_slice(&(sealed.len() as u32).to_le_bytes());
    out.extend_from_slice(&sealed);
    Ok(out)
}

/// 切出完整框架，回傳 `(框架們, 已消耗的位元組數)`。
///
/// **不完整的尾巴不消耗。** 寫到一半當機留下的半個框架要等它補齊，
/// 而不是被當成損毀資料丟掉。
pub fn split_frames(data: &[u8]) -> (Vec<&[u8]>, usize) {
    let mut frames = Vec::new();
    let mut pos = 0;
    while pos + FRAME_HEADER_LEN <= data.len() {
        let len = u32::from_le_bytes(
            data[pos..pos + FRAME_HEADER_LEN]
                .try_into()
                .expect("剛量過長度"),
        ) as usize;
        let end = pos + FRAME_HEADER_LEN + len;
        if end > data.len() {
            break;
        }
        frames.push(&data[pos + FRAME_HEADER_LEN..end]);
        pos = end;
    }
    (frames, pos)
}

/// 解開一個檔案裡的所有框架，把明文接起來。
///
/// 任何一個框架解不開就整個失敗 —— 回傳一部分內容的話，
/// 上層會把它當成「這本筆記只有這些」，而使用者看到的是內容莫名其妙變少。
pub fn open_frames(dek: &Dek, data: &[u8], aad: &[u8]) -> Result<Vec<u8>, CryptoError> {
    let (frames, _) = split_frames(data);
    let mut out = Vec::new();
    for frame in frames {
        out.extend_from_slice(&dek.open(frame, aad)?);
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn dek() -> Dek {
        Dek::generate().expect("產生 DEK")
    }

    #[test]
    fn a_sealed_frame_opens_back_to_the_same_bytes() {
        let k = dek();
        let sealed = seal_frame(&k, b"hello ops", b"0001.oplog").unwrap();
        assert_eq!(
            open_frames(&k, &sealed, b"0001.oplog").unwrap(),
            b"hello ops"
        );
    }

    #[test]
    fn appending_a_frame_keeps_everything_before_it_byte_for_byte() {
        // **這就是逐框加密的理由。** 整檔加密的話，追加一批操作會讓
        // 前面所有位元組全部改變，而同步的「較長的是超集」就只剩巧合。
        let k = dek();
        let first = seal_frame(&k, b"batch-1", b"f").unwrap();
        let second = seal_frame(&k, b"batch-2", b"f").unwrap();
        let mut file = first.clone();
        file.extend_from_slice(&second);
        assert_eq!(&file[..first.len()], &first[..], "前面那一段被動到了");
        assert_eq!(open_frames(&k, &file, b"f").unwrap(), b"batch-1batch-2");
    }

    #[test]
    fn concatenating_two_files_is_a_valid_compaction() {
        // 壓實只是把位元組接起來 —— **不需要解密，也就不需要密碼**。
        // 需要密碼的話，背景同步在鎖定狀態下就完全動不了。
        let k = dek();
        let a = seal_frame(&k, b"a", b"f").unwrap();
        let b = seal_frame(&k, b"b", b"f").unwrap();
        let merged = [a, b].concat();
        assert_eq!(open_frames(&k, &merged, b"f").unwrap(), b"ab");
    }

    #[test]
    fn a_half_written_frame_is_left_for_next_time() {
        let k = dek();
        let mut sealed = seal_frame(&k, b"whole", b"f").unwrap();
        sealed.truncate(sealed.len() - 3);
        let (frames, consumed) = split_frames(&sealed);
        assert!(frames.is_empty());
        assert_eq!(consumed, 0, "不完整的框架不得被消耗");
    }

    #[test]
    fn a_frame_moved_to_another_file_does_not_open() {
        // AAD 綁檔名。少了它，把 A 檔的密文搬到 B 檔仍然解得開 ——
        // 內容讀不懂，但重排本身就足以破壞資料。
        let k = dek();
        let sealed = seal_frame(&k, b"secret", b"a.oplog").unwrap();
        assert!(open_frames(&k, &sealed, b"b.oplog").is_err());
    }

    #[test]
    fn another_key_cannot_open_it() {
        let sealed = seal_frame(&dek(), b"secret", b"f").unwrap();
        assert!(open_frames(&dek(), &sealed, b"f").is_err());
    }

    #[test]
    fn rubbish_does_not_panic() {
        let k = dek();
        // 長度前綴說有一百萬位元組，實際上沒有。
        let mut evil = 1_000_000u32.to_le_bytes().to_vec();
        evil.extend_from_slice(b"short");
        let (frames, consumed) = split_frames(&evil);
        assert!(frames.is_empty());
        assert_eq!(consumed, 0);
        assert!(open_frames(&k, &evil, b"f").unwrap().is_empty());
    }
}
