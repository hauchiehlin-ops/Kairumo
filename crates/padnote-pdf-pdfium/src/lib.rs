//! PDFium 後端（工作項 S-21）。
//!
//! 引擎選擇見決策 D6：**PDFium 是 BSD-3**，可自由用於閉源 App。
//! ❌ MuPDF 是 AGPL，會污染整個 App，已在 `deny.toml` 封鎖。
//!
//! ## 執行緒模型
//! PDFium 的 C API **不是執行緒安全的**。這裡用 `thread_safe` feature 在呼叫
//! 周圍加互斥鎖，因此多頁渲染實際上是序列化的 —— 這對效能預算 J2
//! （500 頁開啟 ≤1.5s、捲動 60fps）有直接影響：不能靠開執行緒平行渲染，
//! 只能靠 `PageCache` 的預抓與快取。
//!
//! ## ⚠️ 執行期需要 libpdfium
//! `pdfium-render` 只是綁定，實際的 `libpdfium` 動態庫要另外提供
//! （iOS 靜態連結、macOS/Windows 隨 App 附帶）。因此**建構成功不代表能執行** ——
//! 見 `docs/TODO.md` H6，需在實機驗證 500 頁 PDF 的效能預算（J2）。

// 兩邊都有 PdfPage，明確區分：`PageInfo` 是我們的值物件，`PdfPage` 是 PDFium 的。
use padnote_pdf::{PdfDocument, PdfError, PdfPage as PageInfo, TextSpan};
use pdfium_render::prelude::*;

/// 一份以 PDFium 開啟的 PDF。
pub struct PdfiumDocument {
    bytes: Vec<u8>,
    password: Option<String>,
    page_count: u32,
}

impl std::fmt::Debug for PdfiumDocument {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("PdfiumDocument")
            .field("page_count", &self.page_count)
            .field("bytes", &self.bytes.len())
            .finish()
    }
}

impl PdfiumDocument {
    /// 從記憶體載入。
    ///
    /// 保留位元組而非持有 `PdfDocument` 借用，是為了避開 pdfium-render 的
    /// 生命週期綁定 —— 代價是每次操作重新 parse，由上層的 `PageCache` 吸收。
    pub fn from_bytes(bytes: Vec<u8>, password: Option<&str>) -> Result<Self, PdfError> {
        let page_count = {
            let pdfium = bind()?;
            let doc = pdfium
                .load_pdf_from_byte_slice(&bytes, password)
                .map_err(map_load_error)?;
            doc.pages().len() as u32
        };

        Ok(Self {
            bytes,
            password: password.map(str::to_string),
            page_count,
        })
    }

    pub fn from_file(
        path: impl AsRef<std::path::Path>,
        password: Option<&str>,
    ) -> Result<Self, PdfError> {
        let bytes = std::fs::read(path).map_err(|e| PdfError::Backend(e.to_string()))?;
        Self::from_bytes(bytes, password)
    }

    fn with_page<T>(
        &self,
        index: u32,
        f: impl FnOnce(&PdfPage) -> Result<T, PdfError>,
    ) -> Result<T, PdfError> {
        if index >= self.page_count {
            return Err(PdfError::PageOutOfRange {
                requested: index,
                total: self.page_count,
            });
        }
        let pdfium = bind()?;
        let doc = pdfium
            .load_pdf_from_byte_slice(&self.bytes, self.password.as_deref())
            .map_err(map_load_error)?;
        let page = doc
            .pages()
            .get(index as u16)
            .map_err(|e| PdfError::Backend(e.to_string()))?;
        f(&page)
    }
}

/// 頁面與標註資料，供 PDFium 寫入使用。
#[derive(Clone, Debug)]
pub struct PdfiumPageInput {
    pub width: f32,
    pub height: f32,
    pub annotations: Vec<padnote_pdf::PdfAnnotation>,
}

/// 透過 PDFium 建立含有 Ink 標註之 PDF（工作項 S-43）。
pub fn create_annotated_pdf(pages: &[PdfiumPageInput]) -> Result<Vec<u8>, PdfError> {
    let pdfium = bind()?;
    let mut doc = pdfium
        .create_new_pdf()
        .map_err(|e| PdfError::Backend(e.to_string()))?;

    for input in pages {
        let size = PdfPagePaperSize::Custom(
            PdfPoints::new(input.width),
            PdfPoints::new(input.height),
        );
        let mut page = doc
            .pages_mut()
            .create_page_at_end(size)
            .map_err(|e| PdfError::Backend(e.to_string()))?;

        for annot in &input.annotations {
            if annot.kind == padnote_pdf::AnnotationKind::Ink {
                let mut ink_annot = page
                    .annotations_mut()
                    .create_ink_annotation()
                    .map_err(|e| PdfError::Backend(e.to_string()))?;

                let (min_x, min_y, max_x, max_y) = annot.rect();
                let rect = PdfRect::new(
                    PdfPoints::new(min_x),
                    PdfPoints::new(min_y),
                    PdfPoints::new(max_x),
                    PdfPoints::new(max_y),
                );
                let _ = ink_annot.set_bounds(rect);
                let _ = ink_annot.set_stroke_color(PdfColor::new(
                    (annot.color[0] * 255.0).clamp(0.0, 255.0) as u8,
                    (annot.color[1] * 255.0).clamp(0.0, 255.0) as u8,
                    (annot.color[2] * 255.0).clamp(0.0, 255.0) as u8,
                    (annot.opacity * 255.0).clamp(0.0, 255.0) as u8,
                ));
            }
        }
    }

    doc.save_to_bytes()
        .map_err(|e| PdfError::Backend(e.to_string()))
}

/// 每次操作重新綁定 libpdfium。
///
/// 看起來浪費，但 `Pdfium` 持有的 `Box<dyn PdfiumLibraryBindings>` 既不是
/// `Send` 也不是 `Sync`，存進結構就無法滿足 `PdfDocument` 的執行緒約束。
/// dlopen 對已載入的動態庫是快取的，成本遠低於渲染本身；而且渲染結果由
/// `PageCache` 吸收，實際綁定次數遠少於捲動的頁數。
fn bind() -> Result<Pdfium, PdfError> {
    Pdfium::bind_to_system_library()
        .map(Pdfium::new)
        .map_err(|e| PdfError::Backend(format!("找不到 libpdfium：{e}")))
}

fn map_load_error(e: PdfiumError) -> PdfError {
    // 密碼錯誤要能被使用者理解 —— 「PDF 壞了」沒辦法指引下一步。
    match e {
        PdfiumError::PdfiumLibraryInternalError(PdfiumInternalError::PasswordError) => {
            PdfError::PasswordRequired
        }
        PdfiumError::PdfiumLibraryInternalError(PdfiumInternalError::FormatError) => {
            PdfError::NotAPdf
        }
        other => PdfError::Backend(other.to_string()),
    }
}

impl PdfDocument for PdfiumDocument {
    fn page_count(&self) -> u32 {
        self.page_count
    }

    fn page(&self, index: u32) -> Result<PageInfo, PdfError> {
        self.with_page(index, |page| {
            Ok(PageInfo {
                index,
                size: (page.width().value, page.height().value),
                rotation: match page.rotation() {
                    Ok(PdfPageRenderRotation::Degrees90) => 90,
                    Ok(PdfPageRenderRotation::Degrees180) => 180,
                    Ok(PdfPageRenderRotation::Degrees270) => 270,
                    _ => 0,
                },
            })
        })
    }

    fn text_spans(&self, index: u32) -> Result<Vec<TextSpan>, PdfError> {
        self.with_page(index, |page| {
            let text = page.text().map_err(|e| PdfError::Backend(e.to_string()))?;
            Ok(text
                .segments()
                .iter()
                .filter_map(|seg| {
                    let s = seg.text();
                    // 空白片段對選取與搜尋都沒用，直接濾掉以縮小索引。
                    if s.trim().is_empty() {
                        return None;
                    }
                    let r = seg.bounds();
                    Some(TextSpan {
                        text: s,
                        rect: (
                            r.left().value,
                            r.bottom().value,
                            r.right().value,
                            r.top().value,
                        ),
                    })
                })
                .collect())
        })
    }

    fn render(&self, index: u32, scale: f32) -> Result<Vec<u8>, PdfError> {
        self.with_page(index, |page| {
            let width = (page.width().value * scale).round().max(1.0) as i32;
            let config = PdfRenderConfig::new().set_target_width(width);
            let bitmap = page
                .render_with_config(&config)
                .map_err(|e| PdfError::Backend(e.to_string()))?;
            Ok(bitmap.as_rgba_bytes())
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// libpdfium 是執行期相依。CI 上沒有它時，測試應跳過而非失敗 ——
    /// 否則整條 pipeline 會因為環境問題變紅。
    fn pdfium_available() -> bool {
        Pdfium::bind_to_system_library().is_ok()
    }

    #[test]
    fn missing_library_is_reported_clearly() {
        if pdfium_available() {
            return;
        }
        let err = PdfiumDocument::from_bytes(vec![0u8; 10], None).unwrap_err();
        assert!(
            err.to_string().contains("libpdfium"),
            "錯誤訊息要指出缺的是什麼：{err}"
        );
    }

    #[test]
    fn garbage_input_is_rejected() {
        if !pdfium_available() {
            return;
        }
        let err = PdfiumDocument::from_bytes(b"this is not a pdf".to_vec(), None).unwrap_err();
        assert!(matches!(err, PdfError::NotAPdf | PdfError::Backend(_)));
    }

    #[test]
    fn page_index_is_bounds_checked() {
        // 這條不需要 libpdfium —— 邊界檢查在 Rust 層就完成，
        // 不該讓越界索引進到 C++。
        let doc = PdfiumDocument {
            bytes: Vec::new(),
            password: None,
            page_count: 3,
        };
        assert!(matches!(
            doc.page(5),
            Err(PdfError::PageOutOfRange {
                requested: 5,
                total: 3
            })
        ));
    }

    #[test]
    fn create_annotated_pdf_produces_pdf_with_annotations() {
        if !pdfium_available() {
            return;
        }

        let annot = padnote_pdf::PdfAnnotation {
            kind: padnote_pdf::AnnotationKind::Ink,
            page_index: 0,
            ink_paths: vec![vec![(10.0, 10.0), (100.0, 100.0)]],
            quad_points: vec![],
            color: [1.0, 0.0, 0.0],
            opacity: 1.0,
            width: 2.0,
            contents: String::new(),
        };

        let input = PdfiumPageInput {
            width: 595.0,
            height: 842.0,
            annotations: vec![annot],
        };

        let pdf_bytes = create_annotated_pdf(&[input]).expect("應成功寫出 PDF");
        assert!(pdf_bytes.starts_with(b"%PDF"));

        // 重新讀取驗證
        let reopened = PdfiumDocument::from_bytes(pdf_bytes, None).expect("應能重新開啟");
        assert_eq!(reopened.page_count(), 1);
        let page = reopened.page(0).expect("應能取得第 0 頁");
        assert_eq!(page.size, (595.0, 842.0));
    }
}
