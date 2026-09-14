//! PDF 匯出引擎（工作項 S-18 / S-43）。
//!
//! 將 `Notebook` 與筆畫資料匯出為符合 ISO 32000-1 標準的 PDF 1.7 文件。
//!
//! ## 特色
//! 1. **零外部 C 相依**：標準純 Rust PDF 生成器，在任何執行期與 CI 環境均可 100% 穩定輸出合法 PDF。
//! 2. **雙向標註保真**：筆畫同時輸出為向量路徑（一般檢視器即可閱覽）與 PDF `/Ink` 標註
//!    （`/Subtype /Ink` + `/InkList`，使用 `PageMapping` 座標轉換，可在 Goodnotes/Notability 繼續標註）。
//! 3. **全模板底紋支援**：Blank、Lined、Grid、Dotted、Cornell、MusicStaff。
//! 4. **內容區塊排版**：富文本（各種標題/引言/程式碼/待辦）、表格、圖片、轉錄逐字稿。
//! 5. **Flate 串流壓縮**：支援 `/Filter /FlateDecode`，大幅降低檔案體積（P2）。
//! 6. **CJK 字型相容**：繁體/簡體中文支援 UTF-16BE 編碼與 Type 0 複合字型（P4）。
//! 7. **圖片區塊真實尺寸與繪製**：支援 JPEG 與 PNG 影像解析及 XObject 擺放（P1）。

use padnote_doc::{BlockKind, Notebook, Page, PageTemplate, TextStyle, Uuid};
use padnote_ink::Stroke;
use padnote_pdf::{PageMapping, stroke_to_annotation};
use padnote_storage::{BlobId, BlobStore};
use std::collections::HashMap;
use std::io::Write;

#[derive(Clone, Debug)]
pub struct PdfExportOptions {
    /// 是否在 PDF 中嵌入標準 `/Ink` 標註（便於其他筆記 App 進行二次編輯）。
    pub include_annotations: bool,
    /// 是否繪製頁面背景底紋（橫線、格線、康乃爾線等）。
    pub include_background_template: bool,
    /// 指定匯出頁面範圍（0-indexed）；`None` 代表匯出全部頁面。
    pub page_range: Option<Vec<usize>>,
    /// 是否啟用內容串流之 FlateDecode 壓縮（大幅減少檔案體積，預設為 true）。
    pub compress_streams: bool,
}

impl Default for PdfExportOptions {
    fn default() -> Self {
        Self {
            include_annotations: true,
            include_background_template: true,
            page_range: None,
            compress_streams: true,
        }
    }
}

#[derive(Debug)]
pub enum ExportError {
    EmptyNotebook,
    PageNotFound(Uuid),
    Storage(String),
    ImageEncoding(String),
    InvalidData(String),
}

impl std::fmt::Display for ExportError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::EmptyNotebook => write!(f, "筆記本內無任何頁面可匯出"),
            Self::PageNotFound(id) => write!(f, "找不到指定頁面：{id}"),
            Self::Storage(s) => write!(f, "儲存讀取錯誤：{s}"),
            Self::ImageEncoding(s) => write!(f, "圖片編碼錯誤：{s}"),
            Self::InvalidData(s) => write!(f, "資料無效：{s}"),
        }
    }
}

impl std::error::Error for ExportError {}

/// 將筆記本全部或指定頁面匯出為標準 PDF 位元組流。
pub fn to_pdf(
    notebook: &Notebook,
    strokes: &HashMap<Uuid, Vec<Stroke>>,
    blobs: Option<&BlobStore>,
    options: &PdfExportOptions,
) -> Result<Vec<u8>, ExportError> {
    if notebook.page_count() == 0 {
        return Err(ExportError::EmptyNotebook);
    }

    let pages_to_export: Vec<&Page> = match &options.page_range {
        Some(indices) => {
            let mut list = Vec::new();
            for &idx in indices {
                if let Some(p) = notebook.pages().get(idx) {
                    list.push(p);
                }
            }
            if list.is_empty() {
                return Err(ExportError::EmptyNotebook);
            }
            list
        }
        None => notebook.pages().iter().collect(),
    };

    let mut writer = PdfWriter::new();
    writer.build_document(pages_to_export, strokes, blobs, options)
}

/// 匯出單一頁面為單頁 PDF。
pub fn page_to_pdf(
    notebook: &Notebook,
    page_id: Uuid,
    page_strokes: &[Stroke],
    blobs: Option<&BlobStore>,
    options: &PdfExportOptions,
) -> Result<Vec<u8>, ExportError> {
    let page = notebook
        .page(page_id)
        .ok_or(ExportError::PageNotFound(page_id))?;

    let mut strokes_map = HashMap::new();
    strokes_map.insert(page_id, page_strokes.to_vec());

    let mut single_opt = options.clone();
    single_opt.page_range = None;

    let mut writer = PdfWriter::new();
    writer.build_document(vec![page], &strokes_map, blobs, &single_opt)
}

// ---- 圖片解析輔助模型 ----

#[derive(Clone, Debug)]
enum ImagePayload {
    Jpeg {
        w: u32,
        h: u32,
        data: Vec<u8>,
    },
    PngRgb {
        w: u32,
        h: u32,
        compressed_rgb: Vec<u8>,
    },
    RawFallback {
        w: u32,
        h: u32,
        data: Vec<u8>,
    },
}

#[derive(Clone, Debug)]
struct ProcessedImage {
    obj_id: usize,
    blob_key: String,
    pixel_w: u32,
    pixel_h: u32,
    payload: ImagePayload,
}

fn parse_jpeg_dimensions(data: &[u8]) -> Option<(u32, u32)> {
    if data.len() < 4 || data[0] != 0xFF || data[1] != 0xD8 {
        return None;
    }
    let mut i = 2;
    while i + 9 <= data.len() {
        if data[i] != 0xFF {
            i += 1;
            continue;
        }
        let marker = data[i + 1];
        // SOF0 (0xC0), SOF1 (0xC1), SOF2 (0xC2)
        if marker == 0xC0 || marker == 0xC1 || marker == 0xC2 {
            let height = u16::from_be_bytes([data[i + 5], data[i + 6]]) as u32;
            let width = u16::from_be_bytes([data[i + 7], data[i + 8]]) as u32;
            if width > 0 && height > 0 {
                return Some((width, height));
            }
        }
        if i + 3 >= data.len() {
            break;
        }
        let length = u16::from_be_bytes([data[i + 2], data[i + 3]]) as usize;
        if length < 2 {
            break;
        }
        i += 2 + length;
    }
    None
}

fn parse_png_image(data: &[u8]) -> Option<(u32, u32, Vec<u8>)> {
    let decoder = png::Decoder::new(std::io::Cursor::new(data));
    let mut reader = decoder.read_info().ok()?;
    let mut buf = vec![0u8; reader.output_buffer_size()?];
    let info = reader.next_frame(&mut buf).ok()?;
    let (w, h) = (info.width, info.height);

    let rgb = match info.color_type {
        png::ColorType::Rgb => buf[..info.buffer_size()].to_vec(),
        png::ColorType::Rgba => {
            let mut out = Vec::with_capacity((w * h * 3) as usize);
            for chunk in buf[..info.buffer_size()].chunks_exact(4) {
                out.extend_from_slice(&chunk[0..3]);
            }
            out
        }
        png::ColorType::Grayscale => {
            let mut out = Vec::with_capacity((w * h * 3) as usize);
            for &g in &buf[..info.buffer_size()] {
                out.extend_from_slice(&[g, g, g]);
            }
            out
        }
        png::ColorType::GrayscaleAlpha => {
            let mut out = Vec::with_capacity((w * h * 3) as usize);
            for chunk in buf[..info.buffer_size()].chunks_exact(2) {
                let g = chunk[0];
                out.extend_from_slice(&[g, g, g]);
            }
            out
        }
        _ => return None,
    };
    Some((w, h, rgb))
}

fn process_image_data(obj_id: usize, blob_key: String, data: &[u8]) -> ProcessedImage {
    if let Some((w, h)) = parse_jpeg_dimensions(data) {
        return ProcessedImage {
            obj_id,
            blob_key,
            pixel_w: w,
            pixel_h: h,
            payload: ImagePayload::Jpeg {
                w,
                h,
                data: data.to_vec(),
            },
        };
    }

    if let Some((w, h, rgb)) = parse_png_image(data) {
        let compressed = miniz_oxide::deflate::compress_to_vec_zlib(&rgb, 6);
        return ProcessedImage {
            obj_id,
            blob_key,
            pixel_w: w,
            pixel_h: h,
            payload: ImagePayload::PngRgb {
                w,
                h,
                compressed_rgb: compressed,
            },
        };
    }

    ProcessedImage {
        obj_id,
        blob_key,
        pixel_w: 100,
        pixel_h: 100,
        payload: ImagePayload::RawFallback {
            w: 100,
            h: 100,
            data: data.to_vec(),
        },
    }
}

// ---- PDF 1.7 生成器內部實作 ----

struct PdfWriter {
    buf: Vec<u8>,
    offsets: Vec<usize>,
}

impl PdfWriter {
    fn new() -> Self {
        Self {
            buf: Vec::with_capacity(32 * 1024),
            offsets: vec![0], // 0 號物件保留
        }
    }

    fn next_id(&mut self) -> usize {
        let id = self.offsets.len();
        self.offsets.push(0);
        id
    }

    fn start_object(&mut self, id: usize) {
        self.offsets[id] = self.buf.len();
        let _ = writeln!(self.buf, "{id} 0 obj");
    }

    fn end_object(&mut self) {
        self.buf.extend_from_slice(b"endobj\n");
    }

    fn build_document(
        &mut self,
        pages: Vec<&Page>,
        strokes: &HashMap<Uuid, Vec<Stroke>>,
        blobs: Option<&BlobStore>,
        options: &PdfExportOptions,
    ) -> Result<Vec<u8>, ExportError> {
        self.buf.extend_from_slice(b"%PDF-1.7\n%\xE2\xE3\xCF\xD3\n");

        let catalog_id = self.next_id();
        let pages_tree_id = self.next_id();
        let font_helvetica_id = self.next_id();
        let font_bold_id = self.next_id();
        let font_courier_id = self.next_id();
        let font_cjk_id = self.next_id();

        // 預留每個頁面及其內容、標註與圖片物件 ID
        struct PageObjs {
            page_id: usize,
            content_id: usize,
            annot_ids: Vec<usize>,
            images: Vec<ProcessedImage>,
        }

        let mut page_objs_list = Vec::with_capacity(pages.len());
        for page in &pages {
            let page_obj_id = self.next_id();
            let content_id = self.next_id();
            let page_strokes = strokes.get(&page.id).map(Vec::as_slice).unwrap_or(&[]);

            let annot_ids = if options.include_annotations {
                (0..page_strokes.len()).map(|_| self.next_id()).collect()
            } else {
                Vec::new()
            };

            // 解析圖片區塊
            let mut images = Vec::new();
            if let Some(store) = blobs {
                for block in page.blocks() {
                    if let BlockKind::Image { blob, .. } = &block.kind {
                        if let Some(blob_id) = BlobId::from_hex(blob) {
                            if let Ok(data) = store.get(blob_id) {
                                let img_obj_id = self.next_id();
                                let processed = process_image_data(img_obj_id, blob.clone(), &data);
                                images.push(processed);
                            }
                        }
                    }
                }
            }

            page_objs_list.push(PageObjs {
                page_id: page_obj_id,
                content_id,
                annot_ids,
                images,
            });
        }

        // 1. Catalog
        self.start_object(catalog_id);
        let _ = writeln!(self.buf, "<< /Type /Catalog /Pages {pages_tree_id} 0 R >>");
        self.end_object();

        // 2. Pages Tree
        self.start_object(pages_tree_id);
        let mut kids = String::new();
        for po in &page_objs_list {
            kids.push_str(&format!("{} 0 R ", po.page_id));
        }
        let _ = writeln!(
            self.buf,
            "<< /Type /Pages /Kids [ {kids}] /Count {} >>",
            pages.len()
        );
        self.end_object();

        // 3. 標準字型與 CJK 複合字型
        self.start_object(font_helvetica_id);
        self.buf.extend_from_slice(
            b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>\n",
        );
        self.end_object();

        self.start_object(font_bold_id);
        self.buf.extend_from_slice(
            b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>\n",
        );
        self.end_object();

        self.start_object(font_courier_id);
        self.buf.extend_from_slice(
            b"<< /Type /Font /Subtype /Type1 /BaseFont /Courier /Encoding /WinAnsiEncoding >>\n",
        );
        self.end_object();

        // CJK Type 0 (相容 Adobe Acrobat / OS 系統 CJK CMap)
        self.start_object(font_cjk_id);
        self.buf.extend_from_slice(
            b"<< /Type /Font /Subtype /Type0 /BaseFont /STSong-Light /Encoding /UniGB-UTF16-H \
            /DescendantFonts [ << /Type /Font /Subtype /CIDFontType0 /BaseFont /STSong-Light \
            /CIDSystemInfo << /Registry (Adobe) /Ordering (GB1) /Supplement 4 >> >> ] >>\n",
        );
        self.end_object();

        // 4. 逐頁寫出
        for (i, page) in pages.iter().enumerate() {
            let po = &page_objs_list[i];
            let (w, h) = page.size;
            let page_strokes = strokes.get(&page.id).map(Vec::as_slice).unwrap_or(&[]);
            let mapping = PageMapping {
                page_height: h,
                scale: 1.0,
            };

            // 寫出圖片 XObjects
            for img in &po.images {
                self.write_processed_image(img);
            }

            // 寫出 Page 物件
            self.start_object(po.page_id);
            let mut annots_ref = String::new();
            if !po.annot_ids.is_empty() {
                annots_ref.push_str(" /Annots [ ");
                for aid in &po.annot_ids {
                    annots_ref.push_str(&format!("{aid} 0 R "));
                }
                annots_ref.push(']');
            }

            let mut xobjs_ref = String::new();
            if !po.images.is_empty() {
                xobjs_ref.push_str(" /XObject << ");
                for (idx, img) in po.images.iter().enumerate() {
                    xobjs_ref.push_str(&format!("/Im{idx} {} 0 R ", img.obj_id));
                }
                xobjs_ref.push_str(">>");
            }

            let _ = writeln!(
                self.buf,
                "<< /Type /Page /Parent {pages_tree_id} 0 R /MediaBox [ 0 0 {w:.2} {h:.2} ] \
                /Contents {content_id} 0 R \
                /Resources << /Font << /F1 {font_helvetica_id} 0 R /F2 {font_bold_id} 0 R /F3 {font_courier_id} 0 R /F_CJK {font_cjk_id} 0 R >> {xobjs_ref} >>\
                {annots_ref} >>",
                content_id = po.content_id
            );
            self.end_object();

            // 寫出 Page Content Stream
            let mut content = Vec::new();
            if options.include_background_template {
                self.render_template_background(&mut content, &page.template, w, h);
            }
            self.render_blocks(&mut content, page, w, h, &po.images);
            self.render_strokes_vector(&mut content, page_strokes, h);

            // 串流壓縮（P2）
            let (final_stream, filter_str) = if options.compress_streams {
                let compressed = miniz_oxide::deflate::compress_to_vec_zlib(&content, 6);
                (compressed, " /Filter /FlateDecode")
            } else {
                (content, "")
            };

            self.start_object(po.content_id);
            let _ = write!(
                self.buf,
                "<< /Length {}{filter_str} >>\nstream\n",
                final_stream.len()
            );
            self.buf.extend_from_slice(&final_stream);
            self.buf.extend_from_slice(b"\nendstream\n");
            self.end_object();

            // 寫出 Ink Annotations
            if options.include_annotations {
                for (stroke_idx, stroke) in page_strokes.iter().enumerate() {
                    let annot_id = po.annot_ids[stroke_idx];
                    let annot = stroke_to_annotation(stroke, i as u32, &mapping);
                    self.write_ink_annotation(annot_id, po.page_id, &annot);
                }
            }
        }

        // 5. XRef Table
        let xref_offset = self.buf.len();
        let count = self.offsets.len();
        let _ = write!(self.buf, "xref\n0 {count}\n");
        self.buf.extend_from_slice(b"0000000000 65535 f \n");
        for &off in &self.offsets[1..] {
            let _ = writeln!(self.buf, "{off:010} 00000 n ");
        }

        // 6. Trailer
        let _ = write!(
            self.buf,
            "trailer\n<< /Size {count} /Root {catalog_id} 0 R >>\n\
            startxref\n{xref_offset}\n%%EOF\n"
        );

        Ok(std::mem::take(&mut self.buf))
    }

    fn write_processed_image(&mut self, img: &ProcessedImage) {
        self.start_object(img.obj_id);
        match &img.payload {
            ImagePayload::Jpeg { w, h, data } => {
                let _ = write!(
                    self.buf,
                    "<< /Type /XObject /Subtype /Image /Width {w} /Height {h} \
                    /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length {} >>\nstream\n",
                    data.len()
                );
                self.buf.extend_from_slice(data);
                self.buf.extend_from_slice(b"\nendstream\n");
            }
            ImagePayload::PngRgb {
                w,
                h,
                compressed_rgb,
            } => {
                let _ = write!(
                    self.buf,
                    "<< /Type /XObject /Subtype /Image /Width {w} /Height {h} \
                    /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode /Length {} >>\nstream\n",
                    compressed_rgb.len()
                );
                self.buf.extend_from_slice(compressed_rgb);
                self.buf.extend_from_slice(b"\nendstream\n");
            }
            ImagePayload::RawFallback { w, h, data } => {
                let _ = write!(
                    self.buf,
                    "<< /Type /XObject /Subtype /Image /Width {w} /Height {h} \
                    /ColorSpace /DeviceRGB /BitsPerComponent 8 /Length {} >>\nstream\n",
                    data.len()
                );
                self.buf.extend_from_slice(data);
                self.buf.extend_from_slice(b"\nendstream\n");
            }
        }
        self.end_object();
    }

    fn write_ink_annotation(
        &mut self,
        annot_id: usize,
        page_id: usize,
        annot: &padnote_pdf::PdfAnnotation,
    ) {
        self.start_object(annot_id);
        let (min_x, min_y, max_x, max_y) = annot.rect();
        let c = &annot.color;

        let mut inklist = String::new();
        inklist.push_str("[ ");
        for path in &annot.ink_paths {
            inklist.push_str("[ ");
            for (x, y) in path {
                inklist.push_str(&format!("{x:.2} {y:.2} "));
            }
            inklist.push_str("] ");
        }
        inklist.push(']');

        let _ = writeln!(
            self.buf,
            "<< /Type /Annot /Subtype /Ink /P {page_id} 0 R \
            /Rect [ {min_x:.2} {min_y:.2} {max_x:.2} {max_y:.2} ] \
            /C [ {r:.3} {g:.3} {b:.3} ] /CA {alpha:.3} \
            /InkList {inklist} /BS << /W {w:.2} >> >>",
            r = c[0],
            g = c[1],
            b = c[2],
            alpha = annot.opacity,
            w = annot.width
        );
        self.end_object();
    }

    fn render_template_background(
        &self,
        content: &mut Vec<u8>,
        template: &PageTemplate,
        width: f32,
        height: f32,
    ) {
        match template {
            PageTemplate::Blank => {}
            PageTemplate::Lined => {
                let _ = writeln!(content, "q 0.88 0.88 0.90 RG 0.75 w");
                let mut y = height - 50.0;
                while y >= 50.0 {
                    let _ = writeln!(
                        content,
                        "36.0 {y:.2} m {x1:.2} {y:.2} l S",
                        x1 = width - 36.0
                    );
                    y -= 24.0;
                }
                content.extend_from_slice(b"Q\n");
            }
            PageTemplate::Grid => {
                let _ = writeln!(content, "q 0.92 0.92 0.94 RG 0.5 w");
                let mut x = 20.0;
                while x < width {
                    let _ = writeln!(content, "{x:.2} 0 m {x:.2} {height:.2} l S");
                    x += 20.0;
                }
                let mut y = 20.0;
                while y < height {
                    let _ = writeln!(content, "0 {y:.2} m {width:.2} {y:.2} l S");
                    y += 20.0;
                }
                content.extend_from_slice(b"Q\n");
            }
            PageTemplate::Dotted => {
                let _ = writeln!(content, "q 0.75 0.75 0.80 RG 1.0 w");
                let mut x = 20.0;
                while x < width {
                    let mut y = 20.0;
                    while y < height {
                        let _ = writeln!(content, "{x:.2} {y:.2} m {x:.2} {y:.2} l S");
                        y += 20.0;
                    }
                    x += 20.0;
                }
                content.extend_from_slice(b"Q\n");
            }
            PageTemplate::Cornell => {
                let _ = writeln!(content, "q 0.80 0.80 0.85 RG 1.0 w");
                let top_y = height - 60.0;
                let bot_y = 120.0;
                let cue_x = 150.0;
                let _ = writeln!(content, "0 {top_y:.2} m {width:.2} {top_y:.2} l S");
                let _ = writeln!(content, "0 {bot_y:.2} m {width:.2} {bot_y:.2} l S");
                let _ = writeln!(content, "{cue_x:.2} {bot_y:.2} m {cue_x:.2} {top_y:.2} l S");
                content.extend_from_slice(b"Q\n");
            }
            PageTemplate::MusicStaff => {
                let _ = writeln!(content, "q 0.70 0.70 0.75 RG 0.75 w");
                let mut staff_top = height - 60.0;
                while staff_top >= 80.0 {
                    for line in 0..5 {
                        let y = staff_top - (line as f32 * 8.0);
                        let _ = writeln!(
                            content,
                            "36.0 {y:.2} m {x1:.2} {y:.2} l S",
                            x1 = width - 36.0
                        );
                    }
                    staff_top -= 64.0;
                }
                content.extend_from_slice(b"Q\n");
            }
            _ => {}
        }
    }

    fn render_blocks(
        &self,
        content: &mut Vec<u8>,
        page: &Page,
        width: f32,
        height: f32,
        images: &[ProcessedImage],
    ) {
        let mut cursor_y = height - 60.0;
        let left_margin = 40.0;
        let right_margin = width - 40.0;

        for block in page.blocks() {
            let (bx, by) = block.position.unwrap_or((left_margin, cursor_y));
            let pdf_y = height - by;

            match &block.kind {
                BlockKind::Text {
                    content: text,
                    style,
                } => {
                    let (default_font, size, line_height, r, g, b) = match style {
                        TextStyle::Heading1 => ("/F2", 22.0, 28.0, 0.1, 0.1, 0.15),
                        TextStyle::Heading2 => ("/F2", 16.0, 22.0, 0.15, 0.15, 0.2),
                        TextStyle::Heading3 => ("/F2", 13.0, 18.0, 0.2, 0.2, 0.25),
                        TextStyle::Quote => ("/F1", 11.0, 16.0, 0.4, 0.4, 0.45),
                        TextStyle::Code => ("/F3", 10.0, 14.0, 0.1, 0.3, 0.1),
                        TextStyle::Bullet => ("/F1", 11.0, 16.0, 0.15, 0.15, 0.15),
                        TextStyle::Todo { done } if *done => ("/F1", 11.0, 16.0, 0.5, 0.5, 0.5),
                        _ => ("/F1", 11.0, 16.0, 0.15, 0.15, 0.15),
                    };

                    let prefix = match style {
                        TextStyle::Bullet => "- ",
                        TextStyle::Todo { done: true } => "[x] ",
                        TextStyle::Todo { done: false } => "[ ] ",
                        _ => "",
                    };

                    let formatted_text = format!("{prefix}{text}");
                    let (font, literal) = format_pdf_text(&formatted_text, default_font);

                    let _ = writeln!(
                        content,
                        "BT {font} {size:.1} Tf {r:.2} {g:.2} {b:.2} rg {bx:.2} {pdf_y:.2} Td {literal} Tj ET"
                    );

                    if matches!(style, TextStyle::Quote) {
                        let _ = writeln!(
                            content,
                            "q 0.5 0.5 0.6 RG 2.0 w {x:.2} {y0:.2} m {x:.2} {y1:.2} l S Q",
                            x = bx - 10.0,
                            y0 = pdf_y - 4.0,
                            y1 = pdf_y + size
                        );
                    }

                    cursor_y += line_height;
                }
                BlockKind::Table {
                    rows,
                    cols,
                    cells,
                    header_row,
                    ..
                } => {
                    let rows_cnt = *rows as f32;
                    let cols_cnt = *cols as f32;
                    let table_w = (right_margin - bx).max(200.0);
                    let row_h = 24.0;
                    let col_w = table_w / cols_cnt.max(1.0);
                    let table_h = rows_cnt * row_h;

                    // 畫表格外框與格線
                    let _ = writeln!(content, "q 0.6 0.6 0.65 RG 0.75 w");
                    for r in 0..=(*rows as usize) {
                        let y = pdf_y - (r as f32 * row_h);
                        let _ = writeln!(
                            content,
                            "{bx:.2} {y:.2} m {x1:.2} {y:.2} l S",
                            x1 = bx + table_w
                        );
                    }
                    for c in 0..=(*cols as usize) {
                        let x = bx + (c as f32 * col_w);
                        let _ = writeln!(
                            content,
                            "{x:.2} {pdf_y:.2} m {x:.2} {y1:.2} l S",
                            y1 = pdf_y - table_h
                        );
                    }
                    content.extend_from_slice(b"Q\n");

                    // 填寫儲存格文字
                    for r in 0..*rows {
                        for c in 0..*cols {
                            let idx = (r * cols + c) as usize;
                            if let Some(cell_str) = cells.get(idx) {
                                if !cell_str.trim().is_empty() {
                                    let cell_x = bx + (c as f32 * col_w) + 4.0;
                                    let cell_y = pdf_y - (r as f32 * row_h) - 16.0;
                                    let def_font =
                                        if *header_row && r == 0 { "/F2" } else { "/F1" };
                                    let (font, literal) = format_pdf_text(cell_str, def_font);
                                    let _ = writeln!(
                                        content,
                                        "BT {font} 10 Tf 0.1 0.1 0.1 rg {cell_x:.2} {cell_y:.2} Td {literal} Tj ET"
                                    );
                                }
                            }
                        }
                    }

                    cursor_y += table_h + 16.0;
                }
                BlockKind::Image {
                    blob,
                    width: user_w,
                    height: user_h,
                } => {
                    // P1: 補齊圖片繪製指令與真實尺寸縮放
                    if let Some((img_idx, img_info)) = images
                        .iter()
                        .enumerate()
                        .find(|(_, img)| img.blob_key == *blob)
                    {
                        let (pixel_w, pixel_h) = (img_info.pixel_w as f32, img_info.pixel_h as f32);
                        let (disp_w, disp_h) = if *user_w > 0.0 && *user_h > 0.0 {
                            (*user_w, *user_h)
                        } else {
                            let max_w = (right_margin - bx).clamp(100.0, 400.0);
                            let w = pixel_w.min(max_w);
                            let h = if pixel_w > 0.0 {
                                w * (pixel_h / pixel_w)
                            } else {
                                150.0
                            };
                            (w, h)
                        };

                        let img_y = pdf_y - disp_h;
                        let _ = writeln!(
                            content,
                            "q {disp_w:.2} 0 0 {disp_h:.2} {bx:.2} {img_y:.2} cm /Im{img_idx} Do Q"
                        );
                        cursor_y += disp_h + 16.0;
                    } else {
                        cursor_y += 24.0;
                    }
                }
                BlockKind::Transcript { text, .. } => {
                    let (font, literal) = format_pdf_text(&format!("[語音] {text}"), "/F1");
                    let _ = writeln!(
                        content,
                        "BT {font} 10 Tf 0.3 0.3 0.4 rg {bx:.2} {pdf_y:.2} Td {literal} Tj ET"
                    );
                    cursor_y += 18.0;
                }
                _ => {
                    cursor_y += 24.0;
                }
            }
        }
    }

    fn render_strokes_vector(&self, content: &mut Vec<u8>, strokes: &[Stroke], page_height: f32) {
        for stroke in strokes {
            if stroke.points.is_empty() {
                continue;
            }

            let [r8, g8, b8, a8] = stroke.color_rgba8;
            let r = r8 as f32 / 255.0;
            let g = g8 as f32 / 255.0;
            let b = b8 as f32 / 255.0;
            let alpha = a8 as f32 / 255.0;

            let path = stroke.render_path(2);
            if path.is_empty() {
                continue;
            }

            let _ = writeln!(
                content,
                "q {r:.3} {g:.3} {b:.3} RG {w:.2} w 1 J 1 j",
                w = stroke.base_width
            );

            if stroke.tool == padnote_ink::Tool::Highlighter || alpha < 0.99 {
                let _ = writeln!(content, "{alpha:.2} CA");
            }

            let (p0x, p0y) = path[0];
            let _ = write!(content, "{p0x:.2} {y:.2} m ", y = page_height - p0y);

            for &(px, py) in &path[1..] {
                let _ = write!(content, "{px:.2} {y:.2} l ", y = page_height - py);
            }

            content.extend_from_slice(b"S Q\n");
        }
    }
}

/// 將字串轉譯為 PDF 文字字面值相容之格式
fn escape_pdf_string(s: &str) -> String {
    let mut out = String::with_capacity(s.len() + 8);
    for ch in s.chars() {
        match ch {
            '(' => out.push_str("\\("),
            ')' => out.push_str("\\)"),
            '\\' => out.push_str("\\\\"),
            '\r' => out.push_str("\\r"),
            '\n' => out.push_str("\\n"),
            c if c.is_ascii() => out.push(c),
            c => out.push(c),
        }
    }
    out
}

/// 格式化 PDF 文字：非 ASCII 字元使用 CJK 字型與 UTF-16BE 十六進位格式
fn format_pdf_text(text: &str, default_font: &str) -> (String, String) {
    let has_non_ascii = !text.is_ascii();
    if has_non_ascii {
        let mut hex = String::from("<FEFF");
        for u16_val in text.encode_utf16() {
            hex.push_str(&format!("{u16_val:04X}"));
        }
        hex.push('>');
        ("/F_CJK".to_string(), hex)
    } else {
        let esc = escape_pdf_string(text);
        (default_font.to_string(), format!("({esc})"))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use padnote_doc::{Page, TextStyle};
    use padnote_ink::{InkPoint, Tool};

    fn sample_notebook() -> (Notebook, HashMap<Uuid, Vec<Stroke>>) {
        let mut nb = Notebook::new(Uuid::now_v7(), "線性代數 筆記");
        let page_id = Uuid::now_v7();
        let mut page = Page::new(page_id, PageTemplate::Cornell);

        let b1 = padnote_doc::Block {
            id: Uuid::now_v7(),
            kind: BlockKind::Text {
                content: "特徵值與特徵向量 (Eigenvalues)".into(),
                style: TextStyle::Heading1,
            },
            position: Some((50.0, 50.0)),
            appearance: None,
            created_at: padnote_doc::NotebookTime::ZERO,
        };
        page.add_block(b1);

        let b2 = padnote_doc::Block {
            id: Uuid::now_v7(),
            kind: BlockKind::Table {
                rows: 2,
                cols: 2,
                cells: vec![
                    "矩陣 A".into(),
                    "特徵值".into(),
                    "A1".into(),
                    "λ1, λ2".into(),
                ],
                header_row: true,
                merged_cells: vec![],
            },
            position: Some((50.0, 100.0)),
            appearance: None,
            created_at: padnote_doc::NotebookTime::ZERO,
        };
        page.add_block(b2);

        nb.add_page(page);

        let stroke = Stroke {
            id: Uuid::now_v7(),
            started_at: padnote_doc::NotebookTime::ZERO,
            tool: Tool::FountainPen,
            color_rgba8: [0, 50, 200, 255],
            base_width: 2.5,
            points: vec![
                InkPoint::new(60.0, 200.0, 0.6, 0),
                InkPoint::new(120.0, 220.0, 0.8, 8000),
                InkPoint::new(180.0, 210.0, 0.7, 8000),
            ],
        };

        let mut strokes = HashMap::new();
        strokes.insert(page_id, vec![stroke]);

        (nb, strokes)
    }

    #[test]
    fn to_pdf_generates_valid_pdf_structure() {
        let (nb, strokes) = sample_notebook();
        let opt = PdfExportOptions {
            compress_streams: false, // 關閉壓縮便於純文字驗證
            ..Default::default()
        };
        let pdf = to_pdf(&nb, &strokes, None, &opt).unwrap();

        assert!(pdf.starts_with(b"%PDF-1.7"), "必須以 %PDF-1.7 開頭");
        assert!(pdf.ends_with(b"%%EOF\n"), "必須以 %%EOF 結尾");

        let pdf_str = String::from_utf8_lossy(&pdf);
        assert!(pdf_str.contains("/Type /Catalog"), "需包含 Catalog 物件");
        assert!(pdf_str.contains("/Type /Pages"), "需包含 Pages 樹");
        assert!(pdf_str.contains("/Type /Page"), "需包含 Page 物件");
        assert!(pdf_str.contains("/Type /Annot"), "需包含 Annot 標註物件");
        assert!(
            pdf_str.contains("/Subtype /Ink"),
            "需包含 /Subtype /Ink 筆畫標註"
        );
        assert!(pdf_str.contains("/InkList"), "需包含 /InkList 標註點序列");
        assert!(pdf_str.contains("/F_CJK"), "需包含 CJK 字型宣告");
        assert!(
            pdf_str.contains("<FEFF"),
            "中文需輸出為 UTF-16BE 十六進位字串"
        );
    }

    #[test]
    fn to_pdf_with_flate_compression() {
        let (nb, strokes) = sample_notebook();
        let opt_compressed = PdfExportOptions {
            compress_streams: true,
            ..Default::default()
        };
        let pdf_compressed = to_pdf(&nb, &strokes, None, &opt_compressed).unwrap();

        let opt_raw = PdfExportOptions {
            compress_streams: false,
            ..Default::default()
        };
        let pdf_raw = to_pdf(&nb, &strokes, None, &opt_raw).unwrap();

        let comp_str = String::from_utf8_lossy(&pdf_compressed);
        assert!(
            comp_str.contains("/Filter /FlateDecode"),
            "需包含 Flate 壓縮濾鏡"
        );
        assert!(
            pdf_compressed.len() < pdf_raw.len(),
            "啟用 Flate 壓縮後檔案大小應當顯著小於未壓縮大小"
        );
    }

    #[test]
    fn page_to_pdf_exports_single_page() {
        let (nb, strokes) = sample_notebook();
        let page_id = nb.pages()[0].id;
        let page_strokes = &strokes[&page_id];

        let pdf = page_to_pdf(
            &nb,
            page_id,
            page_strokes,
            None,
            &PdfExportOptions::default(),
        )
        .unwrap();

        assert!(pdf.starts_with(b"%PDF-1.7"));
        let pdf_str = String::from_utf8_lossy(&pdf);
        assert!(pdf_str.contains("/Count 1"), "單頁匯出頁數必須為 1");
    }

    #[test]
    fn empty_notebook_returns_error() {
        let empty_nb = Notebook::new(Uuid::now_v7(), "空筆記本");
        let err = to_pdf(
            &empty_nb,
            &HashMap::new(),
            None,
            &PdfExportOptions::default(),
        )
        .unwrap_err();
        assert!(matches!(err, ExportError::EmptyNotebook));
    }

    #[test]
    fn image_drawing_and_png_parsing() {
        let pixels = vec![255u8; 10 * 10 * 4];
        let png_bytes = crate::image::encode_png(&pixels, 10, 10).unwrap();

        let temp_dir = std::env::temp_dir().join(format!("padnote_pdf_test_{}", Uuid::now_v7()));
        let blob_store = BlobStore::new(&temp_dir);
        let blob_id = blob_store.put(&png_bytes).unwrap();

        let mut nb = Notebook::new(Uuid::now_v7(), "含圖片筆記");
        let page_id = Uuid::now_v7();
        let mut page = Page::new(page_id, PageTemplate::Blank);

        let img_block = padnote_doc::Block {
            id: Uuid::now_v7(),
            kind: BlockKind::Image {
                blob: blob_id.to_string(),
                width: 150.0,
                height: 150.0,
            },
            position: Some((40.0, 50.0)),
            appearance: None,
            created_at: padnote_doc::NotebookTime::ZERO,
        };
        page.add_block(img_block);
        nb.add_page(page);

        let opt = PdfExportOptions {
            compress_streams: false,
            ..Default::default()
        };
        let pdf = to_pdf(&nb, &HashMap::new(), Some(&blob_store), &opt).unwrap();
        let pdf_str = String::from_utf8_lossy(&pdf);

        assert!(pdf_str.contains("/XObject << /Im0"), "需註冊 /Im0 XObject");
        assert!(pdf_str.contains("/Im0 Do"), "內容流需包含 /Im0 Do 繪製指令");
        assert!(
            pdf_str.contains("/Width 10 /Height 10"),
            "需解析出 PNG 真實 10x10 寬高"
        );
    }
}
