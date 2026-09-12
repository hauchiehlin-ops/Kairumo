//! PDF 文件抽象。

use std::fmt;

#[derive(Debug)]
pub enum PdfError {
    NotAPdf,
    /// 加密且未提供密碼。
    PasswordRequired,
    PageOutOfRange {
        requested: u32,
        total: u32,
    },
    Backend(String),
}

impl fmt::Display for PdfError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::NotAPdf => write!(f, "不是有效的 PDF 檔"),
            Self::PasswordRequired => write!(f, "這份 PDF 需要密碼"),
            Self::PageOutOfRange { requested, total } => {
                write!(f, "頁碼 {requested} 超出範圍（共 {total} 頁）")
            }
            Self::Backend(m) => write!(f, "PDF 引擎錯誤：{m}"),
        }
    }
}

impl std::error::Error for PdfError {}

/// PDF 內的一段文字及其位置。
///
/// 有真正的文字層才能做**選取與 highlight**（功能 E2）。競品有些是用畫線
/// 模擬螢光筆，選不到字也搜不到 —— 那不算 PDF 標註。
#[derive(Clone, Debug, PartialEq)]
pub struct TextSpan {
    pub text: String,
    /// PDF 座標系（原點左下，單位 point）。
    pub rect: (f32, f32, f32, f32),
}

#[derive(Clone, Debug, PartialEq)]
pub struct PdfPage {
    pub index: u32,
    /// 頁面尺寸（point）。
    pub size: (f32, f32),
    /// 頁面旋轉角度，必為 0/90/180/270。
    pub rotation: u16,
}

impl PdfPage {
    /// 套用旋轉後的顯示尺寸。90/270 度時寬高互換 —— 忘記這件事會讓橫向
    /// 掃描件顯示成被壓扁的直式。
    pub fn display_size(&self) -> (f32, f32) {
        match self.rotation {
            90 | 270 => (self.size.1, self.size.0),
            _ => self.size,
        }
    }

    /// PDF 座標（原點左下）轉頁面座標（原點左上）。
    ///
    /// 兩個座標系 Y 軸相反。標註位置偏移的 bug 幾乎都出在這裡。
    pub fn pdf_to_page(&self, x: f32, y: f32) -> (f32, f32) {
        (x, self.size.1 - y)
    }

    pub fn page_to_pdf(&self, x: f32, y: f32) -> (f32, f32) {
        (x, self.size.1 - y)
    }
}

/// PDF 文件。實作以 PDFium 為後端。
pub trait PdfDocument: Send + Sync + fmt::Debug {
    fn page_count(&self) -> u32;

    fn page(&self, index: u32) -> Result<PdfPage, PdfError>;

    /// 取出文字層。掃描件沒有文字層時回傳空 —— 那是 OCR（D4）的工作。
    fn text_spans(&self, index: u32) -> Result<Vec<TextSpan>, PdfError>;

    /// 渲染一頁為 RGBA8。`scale` 為相對原始尺寸的倍率。
    fn render(&self, index: u32, scale: f32) -> Result<Vec<u8>, PdfError>;
}

#[cfg(test)]
mod tests {
    use super::*;

    fn page(rotation: u16) -> PdfPage {
        PdfPage {
            index: 0,
            size: (595.0, 842.0),
            rotation,
        }
    }

    #[test]
    fn rotation_swaps_dimensions() {
        assert_eq!(page(0).display_size(), (595.0, 842.0));
        assert_eq!(page(180).display_size(), (595.0, 842.0));
        assert_eq!(page(90).display_size(), (842.0, 595.0));
        assert_eq!(page(270).display_size(), (842.0, 595.0));
    }

    #[test]
    fn coordinate_conversion_flips_y() {
        // 標註位置偏移的 bug 幾乎都出在這裡。
        let p = page(0);
        assert_eq!(
            p.pdf_to_page(100.0, 0.0),
            (100.0, 842.0),
            "PDF 底部 = 頁面頂部的對面"
        );
        assert_eq!(p.pdf_to_page(100.0, 842.0), (100.0, 0.0));
    }

    #[test]
    fn coordinate_conversion_roundtrips() {
        let p = page(0);
        let (x, y) = p.pdf_to_page(123.0, 456.0);
        assert_eq!(p.page_to_pdf(x, y), (123.0, 456.0));
    }

    #[test]
    fn errors_are_specific_enough_to_act_on() {
        // 「PDF 壞了」對使用者沒用；「需要密碼」才能引導下一步。
        assert!(PdfError::PasswordRequired.to_string().contains("密碼"));
        assert!(
            PdfError::PageOutOfRange {
                requested: 600,
                total: 500
            }
            .to_string()
            .contains("500")
        );
    }
}
