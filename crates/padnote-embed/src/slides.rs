//! `.pptx`：**僅預覽，不支援編輯**（ADR-0009）。
//!
//! ## 為什麼不做編輯
//! Rust 生態缺乏成熟的 pptx 解析器。硬做會得到一個排版跑掉、
//! 動畫消失、編輯後無法還原的功能 —— 那比誠實說「只能預覽」更糟。
//!
//! 本模組因此**只做兩件事**：確認檔案是有效的 pptx、取出投影片張數。
//! 實際的渲染交給平台原生元件（iOS 的 QuickLook、Android 的
//! WPS/Google Slides intent、Windows 的 Office 預覽）。

use crate::{EmbedError, EmbedFormat};
use std::path::Path;

/// pptx 的摘要資訊。
#[derive(Clone, Debug, PartialEq)]
pub struct SlideDeck {
    pub slide_count: usize,
}

/// 檢視 pptx。
///
/// **回傳的是摘要，不是內容。** 要編輯請回原生 App ——
/// 這個限制會透過 [`crate::Limitations`] 顯示在匯入對話框裡。
pub fn import_pptx(path: impl AsRef<Path>) -> Result<SlideDeck, EmbedError> {
    let path = path.as_ref();
    let bytes = std::fs::read(path).map_err(|e| match e.kind() {
        std::io::ErrorKind::NotFound => EmbedError::NotFound(path.display().to_string()),
        _ => EmbedError::Malformed(e.to_string()),
    })?;
    inspect_pptx(&bytes)
}

/// OOXML 都是 ZIP。pptx 的投影片在 `ppt/slides/slideN.xml`。
///
/// 不解 XML，只數 ZIP 目錄裡的項目 —— 對「知道有幾張」這個需求已經足夠，
/// 而且不會因為未知的 XML 結構而失敗。
pub fn inspect_pptx(bytes: &[u8]) -> Result<SlideDeck, EmbedError> {
    // ZIP 的本地檔頭魔數
    if bytes.len() < 4 || &bytes[0..2] != b"PK" {
        return Err(EmbedError::Malformed("不是 ZIP 容器，無法作為 pptx".into()));
    }

    // 掃描中央目錄的檔名。不完整解壓 —— 只需要檔名。
    let needle = b"ppt/slides/slide";
    let mut count = 0;
    let mut seen = std::collections::HashSet::new();
    let mut i = 0;
    while i + needle.len() < bytes.len() {
        if &bytes[i..i + needle.len()] == needle {
            // 取到 `.xml` 為止當作名稱，去重（本地檔頭與中央目錄各出現一次）
            let end = bytes[i..]
                .windows(4)
                .position(|w| w == b".xml")
                .map_or(i + needle.len(), |p| i + p + 4);
            if seen.insert(bytes[i..end].to_vec()) {
                count += 1;
            }
            i = end;
        } else {
            i += 1;
        }
    }

    if count == 0 {
        return Err(EmbedError::Unsupported {
            format: EmbedFormat::Pptx,
            reason: "找不到投影片；可能不是 pptx 或已加密",
        });
    }
    Ok(SlideDeck { slide_count: count })
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 用測試用的 docx（同為 OOXML ZIP）驗證「不是 pptx」的路徑。
    fn docx_bytes() -> Vec<u8> {
        std::fs::read(std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("fixtures/sample.docx"))
            .unwrap()
    }

    #[test]
    fn non_zip_input_is_rejected() {
        assert!(matches!(
            inspect_pptx(b"not a zip at all"),
            Err(EmbedError::Malformed(_))
        ));
    }

    #[test]
    fn zip_without_slides_is_reported_as_unsupported() {
        // docx 是合法的 ZIP 但沒有投影片 —— 錯誤要說清楚是哪一種問題。
        let err = inspect_pptx(&docx_bytes()).unwrap_err();
        assert!(matches!(err, EmbedError::Unsupported { .. }));
        assert!(err.to_string().contains("投影片"));
    }

    #[test]
    fn counts_slides_without_parsing_xml() {
        // 合成一個含投影片名稱的 ZIP 骨架。
        let mut bytes = b"PK\x03\x04".to_vec();
        for n in 1..=3 {
            bytes.extend_from_slice(format!("ppt/slides/slide{n}.xml").as_bytes());
            bytes.extend_from_slice(b"\x00\x00");
        }
        assert_eq!(inspect_pptx(&bytes).unwrap().slide_count, 3);
    }

    #[test]
    fn duplicate_entries_are_counted_once() {
        // ZIP 的本地檔頭與中央目錄會各出現一次檔名。
        let mut bytes = b"PK\x03\x04".to_vec();
        for _ in 0..2 {
            bytes.extend_from_slice(b"ppt/slides/slide1.xml\x00");
        }
        assert_eq!(inspect_pptx(&bytes).unwrap().slide_count, 1);
    }

    #[test]
    fn missing_file_reports_clearly() {
        assert!(matches!(
            import_pptx("/definitely/not/here.pptx"),
            Err(EmbedError::NotFound(_))
        ));
    }
}
