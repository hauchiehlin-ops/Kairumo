//! 嵌入文件：Office 與 Google 三件套（工作項 S-41，ADR-0009 / 決策 D-10）。
//!
//! ## 三種互動層級
//! | 層級 | 行為 | 適用 |
//! |---|---|---|
//! | `Preview` | 渲染為圖像，可縮放可標註，**不可改內容** | 簡報、複雜排版 |
//! | `Editable` | 在筆記內直接編輯 | 試算表、純文字文件 |
//! | `Linked` | 只存連結與快照 | 大型或高保真需求 |
//!
//! ## ⚠️ 可編輯不等於完整相容
//! 我們不是要做 Office 的替代品。**往返保真不保證** ——
//! 匯入後編輯再匯出，複雜排版會流失。UI 必須明示這一點，
//! 不能讓使用者以為可以拿 Padnote 當 Office 用。
//!
//! 明確不支援的項目見 [`Limitations`]。

pub mod docx;
pub mod sheet;
pub mod slides;

pub use docx::{import_docx, import_docx_bytes};
pub use sheet::{Cell, CellValue, Sheet, import_xlsx};
pub use slides::import_pptx;

use std::path::Path;

/// 嵌入文件的互動層級（ADR-0009）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Interaction {
    Preview,
    Editable,
    Linked,
}

/// 支援的嵌入格式。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum EmbedFormat {
    Docx,
    Xlsx,
    Pptx,
    Markdown,
    Json,
    Pdf,
}

impl EmbedFormat {
    /// 從副檔名判斷格式。
    pub fn from_extension(ext: &str) -> Option<Self> {
        Some(match ext.to_ascii_lowercase().as_str() {
            "docx" => Self::Docx,
            "xlsx" => Self::Xlsx,
            "pptx" => Self::Pptx,
            "md" | "markdown" => Self::Markdown,
            "json" => Self::Json,
            "pdf" => Self::Pdf,
            _ => return None,
        })
    }

    pub fn from_path(path: impl AsRef<Path>) -> Option<Self> {
        Self::from_extension(path.as_ref().extension()?.to_str()?)
    }

    /// 此格式的預設互動層級（ADR-0009）。
    pub fn default_interaction(self) -> Interaction {
        match self {
            // 本來就是文字，可直接編輯
            Self::Markdown | Self::Json => Interaction::Editable,
            // 值與基本格式可編輯；巨集與樞紐不支援
            Self::Xlsx => Interaction::Editable,
            // 段落與基本樣式可編輯；複雜排版不保證
            Self::Docx => Interaction::Editable,
            // 版面保真優先，編輯請回原生 App
            Self::Pptx => Interaction::Preview,
            // PDF 走既有的標註路徑（S-42）
            Self::Pdf => Interaction::Preview,
        }
    }

    pub fn is_editable(self) -> bool {
        self.default_interaction() == Interaction::Editable
    }
}

/// 此格式**明確不支援**的項目。
///
/// 這些字串會顯示在匯入對話框裡 —— 讓使用者在按下匯入前就知道會失去什麼，
/// 而不是事後才發現東西不見了。
#[derive(Debug)]
pub struct Limitations;

impl Limitations {
    pub fn for_format(format: EmbedFormat) -> &'static [&'static str] {
        match format {
            EmbedFormat::Docx => &["分欄", "浮動圖文", "追蹤修訂", "頁首頁尾", "註腳"],
            EmbedFormat::Xlsx => &["巨集", "樞紐分析", "圖表", "條件式格式", "資料驗證"],
            EmbedFormat::Pptx => &["編輯（僅預覽）", "動畫", "轉場", "備忘稿"],
            EmbedFormat::Markdown | EmbedFormat::Json => &[],
            EmbedFormat::Pdf => &["表單欄位", "數位簽章"],
        }
    }
}

#[derive(Debug)]
pub enum EmbedError {
    NotFound(String),
    /// 格式可辨識但本版不支援解析。
    Unsupported {
        format: EmbedFormat,
        reason: &'static str,
    },
    Malformed(String),
}

impl std::fmt::Display for EmbedError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NotFound(p) => write!(f, "找不到檔案：{p}"),
            Self::Unsupported { format, reason } => {
                write!(f, "{format:?} 目前不支援：{reason}")
            }
            Self::Malformed(m) => write!(f, "檔案格式錯誤：{m}"),
        }
    }
}

impl std::error::Error for EmbedError {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extension_maps_to_format() {
        assert_eq!(EmbedFormat::from_extension("docx"), Some(EmbedFormat::Docx));
        assert_eq!(EmbedFormat::from_extension("XLSX"), Some(EmbedFormat::Xlsx));
        assert_eq!(
            EmbedFormat::from_extension("md"),
            Some(EmbedFormat::Markdown)
        );
        assert_eq!(EmbedFormat::from_extension("exe"), None);
    }

    #[test]
    fn path_without_extension_is_none() {
        assert_eq!(EmbedFormat::from_path("/tmp/noext"), None);
    }

    #[test]
    fn pptx_is_preview_only() {
        // ADR-0009：Rust 生態缺成熟的 pptx 解析器，硬做會是個做不好的功能。
        assert_eq!(
            EmbedFormat::Pptx.default_interaction(),
            Interaction::Preview
        );
        assert!(!EmbedFormat::Pptx.is_editable());
        assert!(Limitations::for_format(EmbedFormat::Pptx).contains(&"編輯（僅預覽）"));
    }

    #[test]
    fn documents_and_sheets_are_editable() {
        assert!(EmbedFormat::Docx.is_editable());
        assert!(EmbedFormat::Xlsx.is_editable());
    }

    #[test]
    fn every_editable_format_declares_its_limitations() {
        // 使用者要在按下匯入前就知道會失去什麼。
        for f in [EmbedFormat::Docx, EmbedFormat::Xlsx] {
            assert!(
                !Limitations::for_format(f).is_empty(),
                "{f:?} 必須明示不支援的項目"
            );
        }
    }

    #[test]
    fn plain_text_formats_have_no_limitations() {
        assert!(Limitations::for_format(EmbedFormat::Markdown).is_empty());
        assert!(Limitations::for_format(EmbedFormat::Json).is_empty());
    }
}
