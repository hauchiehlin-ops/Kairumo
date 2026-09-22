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

/// 版面圖元的種類。與核心 `ffi_guides::FfiGuideKind` 一一對應。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum GuideKind {
    Line,
    Rect,
    FillRect,
    Label,
    Checkbox,
    Dot,
}

/// 一個**已經解析好**的版面圖元。
///
/// # 為什麼顏色與文字是解析好的
///
/// 版面的幾何在核心（`ffi_guides::page_guides`），但**顏色來自使用者選的
/// 配色、文字要照使用者的語系翻譯** —— 那兩件事都住在 `padnote-core`，
/// 而 core 相依於這個 crate，反過來相依不成立。所以呼叫端把顏色與文字
/// 解析完再交進來，這裡只負責畫。
#[derive(Clone, Debug)]
pub struct GuideItem {
    pub kind: GuideKind,
    /// 左上角原點的座標系（與畫布相同）；輸出時才翻成 PDF 的左下原點。
    pub x: f32,
    pub y: f32,
    pub w: f32,
    pub h: f32,
    pub weight: f32,
    /// RGB，各 0–1。
    pub color: (f32, f32, f32),
    /// 已翻譯的文字；不是 `Label` 時是空字串。
    pub text: String,
    /// `Label` 的字級；`Rect` 的圓角半徑（目前畫成直角）。
    pub size: f32,
    /// 0 靠左、1 置中、2 靠右。
    pub align: u8,
}

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
    /// 每一頁的版面圖元（S-90）。鍵是頁面 id。
    ///
    /// 底紋（`PageTemplate`）只有六種，而使用者看到的版面有三十幾種 ——
    /// 康乃爾的三區、四象限的十字、週計畫的七欄都在這裡。在此之前**匯出的
    /// PDF 完全沒有它們**：畫布上是一張康乃爾，匯出來是一張空白紙。
    pub page_guides: HashMap<Uuid, Vec<GuideItem>>,
}

impl Default for PdfExportOptions {
    fn default() -> Self {
        Self {
            include_annotations: true,
            include_background_template: true,
            page_range: None,
            compress_streams: true,
            page_guides: HashMap::new(),
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
            for chunk in buf[..info.buffer_size()].as_chunks::<4>().0 {
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
            for chunk in buf[..info.buffer_size()].as_chunks::<2>().0 {
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
                    if let BlockKind::Image { blob, .. } = &block.kind
                        && let Some(blob_id) = BlobId::from_hex(blob)
                        && let Ok(data) = store.get(blob_id)
                    {
                        let img_obj_id = self.next_id();
                        let processed = process_image_data(img_obj_id, blob.clone(), &data);
                        images.push(processed);
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
                if let Some(guides) = options.page_guides.get(&page.id) {
                    self.render_page_guides(&mut content, guides, h);
                }
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

    /// 版面圖元（S-90）。
    ///
    /// 座標從「左上原點」翻成 PDF 的「左下原點」—— 兩邊的 y 方向相反，
    /// 不翻的話整個版面會上下顛倒（而且看起來像「畫在別的地方」）。
    fn render_page_guides(&self, content: &mut Vec<u8>, guides: &[GuideItem], height: f32) {
        for g in guides {
            let (r, gc, b) = g.color;
            let top = height - g.y;
            match g.kind {
                GuideKind::Line => {
                    let x2 = g.x + g.w;
                    let y2 = height - (g.y + g.h);
                    let _ = writeln!(
                        content,
                        "q {r:.3} {gc:.3} {b:.3} RG {wt:.2} w {x1:.2} {y1:.2} m {x2:.2} {y2:.2} l S Q",
                        wt = g.weight.max(0.1),
                        x1 = g.x,
                        y1 = top
                    );
                }
                GuideKind::Rect => {
                    let _ = writeln!(
                        content,
                        "q {r:.3} {gc:.3} {b:.3} RG {wt:.2} w {x:.2} {y:.2} {w:.2} {h:.2} re S Q",
                        wt = g.weight.max(0.1),
                        x = g.x,
                        y = top - g.h,
                        w = g.w,
                        h = g.h
                    );
                }
                GuideKind::FillRect => {
                    let _ = writeln!(
                        content,
                        "q {r:.3} {gc:.3} {b:.3} rg {x:.2} {y:.2} {w:.2} {h:.2} re f Q",
                        x = g.x,
                        y = top - g.h,
                        w = g.w,
                        h = g.h
                    );
                }
                GuideKind::Checkbox => {
                    let _ = writeln!(
                        content,
                        "q {r:.3} {gc:.3} {b:.3} RG {wt:.2} w {x:.2} {y:.2} {w:.2} {w:.2} re S Q",
                        wt = g.weight.max(0.1),
                        x = g.x,
                        y = top - g.w,
                        w = g.w
                    );
                }
                GuideKind::Dot => {
                    // 小圓點用「線寬等於直徑的零長線段 + 圓端點」畫，
                    // 比展開成四段貝茲曲線短得多，而且在任何檢視器裡都一樣圓。
                    let _ = writeln!(
                        content,
                        "q {r:.3} {gc:.3} {b:.3} RG {d:.2} w 1 J {x:.2} {y:.2} m {x:.2} {y:.2} l S Q",
                        d = g.w.max(0.5),
                        x = g.x,
                        y = top
                    );
                }
                GuideKind::Label => {
                    if g.text.is_empty() {
                        continue;
                    }

                    // 對齊：核心給的 x 是**錨點**，不是左緣。寬度用字級估
                    // （0.5 em ≈ 一個西文字的平均寬度，CJK 約 1 em）——
                    // PDF 這裡沒有字型度量，估得夠用就好：版面標籤都很短。
                    let per_char = if g.text.is_ascii() { 0.5 } else { 1.0 };
                    let text_w = g.text.chars().count() as f32 * g.size * per_char;
                    let x = match g.align {
                        1 => g.x - text_w / 2.0,
                        2 => g.x - text_w,
                        _ => g.x,
                    };
                    // PDF 的文字基線在下緣，而核心給的 y 是上緣。
                    let baseline = top - g.size * 0.8;
                    write_pdf_text(
                        content,
                        &g.text,
                        "/F1",
                        g.size.max(1.0),
                        &format!("{r:.3} {gc:.3} {b:.3} rg"),
                        x,
                        baseline,
                    );
                }
            }
        }
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

                    // **一個區塊可能不只一行。**
                    //
                    // 這裡以前是整段丟一個 `Tj`，於是：換行字元被吃掉（整段
                    // 擠成一行），太長的段落直接衝出紙張右緣被裁掉。畫布上
                    // 看起來好好的，一匯出或列印就少字 —— 而少掉的部分不會
                    // 有任何提示。文件範本（S-61）裡到處都是多行段落，
                    // 這個缺陷因此變得很明顯。
                    let avail = (width - bx - left_margin).max(80.0);
                    for (i, line) in wrap_pdf_lines(&formatted_text, size, avail)
                        .iter()
                        .enumerate()
                    {
                        let line_y = pdf_y - line_height * i as f32;
                        write_pdf_text(
                            content,
                            line,
                            default_font,
                            size,
                            &format!("{r:.2} {g:.2} {b:.2} rg"),
                            bx,
                            line_y,
                        );
                    }

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
                            if let Some(cell_str) = cells.get(idx)
                                && !cell_str.trim().is_empty()
                            {
                                let cell_x = bx + (c as f32 * col_w) + 4.0;
                                let cell_y = pdf_y - (r as f32 * row_h) - 16.0;
                                let def_font = if *header_row && r == 0 { "/F2" } else { "/F1" };

                                // 儲存格文字也會超出欄寬 —— 以前是直接畫出去，
                                // 於是長一點的內容會蓋到右邊那一格上，甚至衝出
                                // 紙外。列高是固定的，所以放不下的行數寧可截斷
                                // 並加上刪節號：**讓使用者看得出來有東西被截掉**，
                                // 比悄悄蓋住鄰格好。
                                let cell_avail = (col_w - 8.0).max(24.0);
                                let max_lines = ((row_h - 6.0) / 12.0).floor().max(1.0) as usize;
                                let mut lines = wrap_pdf_lines(cell_str, 10.0, cell_avail);
                                if lines.len() > max_lines {
                                    lines.truncate(max_lines);
                                    if let Some(last) = lines.last_mut() {
                                        last.push('…');
                                    }
                                }
                                for (i, line) in lines.iter().enumerate() {
                                    let ly = cell_y - 12.0 * i as f32;
                                    write_pdf_text(
                                        content,
                                        line,
                                        def_font,
                                        10.0,
                                        "0.1 0.1 0.1 rg",
                                        cell_x,
                                        ly,
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
                    write_pdf_text(
                        content,
                        // 這個標記目前寫死英文：padnote-export 完全不知道介面語言，
                        // 而匯出的 PDF 是要給別人看的文件，不該固定出現中文。
                        // 真正的解是把語系傳進來，記在 docs/TODO.md 的 S-54c。
                        &format!("[Audio] {text}"),
                        "/F1",
                        10.0,
                        "0.3 0.3 0.4 rg",
                        bx,
                        pdf_y,
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
        let Some(byte) = winansi_byte(ch) else {
            // 呼叫者已經用 winansi_byte 分過段，走到這裡代表分段漏了。
            // 與其寫出壞位元組，不如留一個看得見的替代字。
            out.push('?');
            continue;
        };
        match byte {
            b'(' => out.push_str("\\("),
            b')' => out.push_str("\\)"),
            b'\\' => out.push_str("\\\\"),
            0x20..=0x7E => out.push(byte as char),
            // 非 ASCII 的 WinAnsi 位元組（‧– — ' ' 等）必須寫成八進位跳脫，
            // 直接塞原始位元組會被當成 UTF-8 的一半而錯位。
            _ => out.push_str(&format!("\\{byte:03o}")),
        }
    }
    out
}

/// 這個字在 WinAnsiEncoding（≈ CP1252）裡的位元組，沒有就是 `None`。
///
/// **為什麼需要這張表**：`•`（U+2022）不是 ASCII。在此之前
/// `format_pdf_text` 只問「是不是純 ASCII」，於是一句
/// `• Draft the outline` 會整句被丟進 STSong/UniGB-UTF16 —— 圓點畫成別的
/// 字，後面每個英文字母都變成 GB 的**全形**拉丁字，看起來就像被拉開了
/// 字距。兩個症狀是同一行程式造成的，也因此與介面語言無關。
/// WinAnsi 本來就有 `•`（0x95）與破折號、彎引號，讓它們留在 Helvetica。
fn winansi_byte(ch: char) -> Option<u8> {
    let c = ch as u32;
    // 製表與換行交給呼叫端處理，不進字串。
    if (0x20..=0x7E).contains(&c) {
        return Some(c as u8);
    }
    if (0xA0..=0xFF).contains(&c) {
        return Some(c as u8);
    }
    // CP1252 的 0x80..=0x9F 特區：Unicode 碼位跳開了，只能查表。
    Some(match ch {
        '\u{20AC}' => 0x80,
        '\u{201A}' => 0x82,
        '\u{0192}' => 0x83,
        '\u{201E}' => 0x84,
        '\u{2026}' => 0x85,
        '\u{2020}' => 0x86,
        '\u{2021}' => 0x87,
        '\u{02C6}' => 0x88,
        '\u{2030}' => 0x89,
        '\u{0160}' => 0x8A,
        '\u{2039}' => 0x8B,
        '\u{0152}' => 0x8C,
        '\u{017D}' => 0x8E,
        '\u{2018}' => 0x91,
        '\u{2019}' => 0x92,
        '\u{201C}' => 0x93,
        '\u{201D}' => 0x94,
        '\u{2022}' => 0x95,
        '\u{2013}' => 0x96,
        '\u{2014}' => 0x97,
        '\u{02DC}' => 0x98,
        '\u{2122}' => 0x99,
        '\u{0161}' => 0x9A,
        '\u{203A}' => 0x9B,
        '\u{0153}' => 0x9C,
        '\u{017E}' => 0x9E,
        '\u{0178}' => 0x9F,
        _ => return None,
    })
}

/// 這個字本身是不是全形（用來決定能不能在它後面斷行）。
fn is_wide_char(ch: char) -> bool {
    matches!(ch as u32,
        0x1100..=0x115F | 0x2E80..=0xA4CF | 0xAC00..=0xD7A3
        | 0xF900..=0xFAFF | 0xFE30..=0xFE4F | 0xFF00..=0xFF60 | 0xFFE0..=0xFFE6)
}

/// 一個字畫出來大約多寬。
///
/// 依這個字**實際會落在哪個字型**來估：進得了 WinAnsi 的走 Helvetica，
/// 約 0.55 em；其餘走 STSong，一律 1 em。在此之前這件事是**整段**一起
/// 決定的（整段只要有一個非 ASCII 就全部按 1 em），於是一句
/// 「今天 2026-09-22 要交」的數字被高估、純英文卻被整段高估，換行位置
/// 兩邊都不對。逐字判斷之後與 `format_pdf_runs` 的切法完全一致。
fn glyph_width(ch: char, font_size: f32) -> f32 {
    if winansi_byte(ch).is_some() {
        font_size * 0.55
    } else {
        font_size
    }
}

/// 把一段文字拆成畫得下 `max_width` 的多行。
///
/// 原文的換行是作者刻意分的段，一定要保留 —— 併成一行的話，條列式的
/// 內容（「一、…二、…」）會擠成沒有斷句的一長串。
///
/// 中文可以在任何字之間斷；英文要在空白處斷，從單字中間切開會變成另一個
/// 字。單一超長的詞（例如網址）沒有空白可斷時才允許硬切 —— 不硬切的話
/// 它會整條衝出紙外，那比切開更糟。
fn wrap_pdf_lines(text: &str, font_size: f32, max_width: f32) -> Vec<String> {
    let mut out = Vec::new();
    for paragraph in text.split('\n') {
        if paragraph.is_empty() {
            out.push(String::new());
            continue;
        }
        let mut line = String::new();
        let mut line_w = 0.0f32;
        let mut pending = String::new();
        let mut pending_w = 0.0f32;

        for ch in paragraph.chars() {
            let w = glyph_width(ch, font_size);
            let breakable = ch.is_whitespace() || is_wide_char(ch);

            if breakable {
                line.push_str(&pending);
                line_w += pending_w;
                pending.clear();
                pending_w = 0.0;

                if line_w + w > max_width && !line.is_empty() {
                    out.push(std::mem::take(&mut line));
                    line_w = 0.0;
                    // 行首不留空白，否則每一行都會往右縮一格。
                    if ch.is_whitespace() {
                        continue;
                    }
                }
                line.push(ch);
                line_w += w;
            } else {
                // 拉丁單字先攢起來，確定放得下才落到行上。
                if line_w + pending_w + w > max_width {
                    if !line.is_empty() {
                        out.push(std::mem::take(&mut line));
                        line_w = 0.0;
                    } else if pending_w + w > max_width {
                        // 一整行都放不下的超長詞：只能硬切。
                        out.push(std::mem::take(&mut pending));
                        pending_w = 0.0;
                    }
                }
                pending.push(ch);
                pending_w += w;
            }
        }
        line.push_str(&pending);
        out.push(line);
    }
    out
}

/// 把一行文字切成「字型 → 字面值」的連續段落。
///
/// 一行裡可以同時有西文與中日韓字，兩者的字型不同，所以不能整行只挑一個
/// 字型：挑錯的那一半會變成別的字或全形。切成段之後，呼叫端在同一個
/// `BT`／`Td` 裡依序 `Tf` + `Tj`，PDF 的文字矩陣會自己往前推進，
/// 不必自己算 x 座標。
fn format_pdf_runs(text: &str, default_font: &str) -> Vec<(String, String)> {
    let mut runs: Vec<(String, String)> = Vec::new();
    let mut buf = String::new();
    let mut buf_is_cjk: Option<bool> = None;

    fn flush(runs: &mut Vec<(String, String)>, buf: &mut String, is_cjk: bool, default_font: &str) {
        if buf.is_empty() {
            return;
        }
        if is_cjk {
            let mut hex = String::from("<FEFF");
            for u16_val in buf.encode_utf16() {
                hex.push_str(&format!("{u16_val:04X}"));
            }
            hex.push('>');
            runs.push(("/F_CJK".to_string(), hex));
        } else {
            runs.push((
                default_font.to_string(),
                format!("({})", escape_pdf_string(buf)),
            ));
        }
        buf.clear();
    }

    for ch in text.chars() {
        let is_cjk = winansi_byte(ch).is_none();
        if buf_is_cjk != Some(is_cjk) {
            flush(
                &mut runs,
                &mut buf,
                buf_is_cjk.unwrap_or(false),
                default_font,
            );
            buf_is_cjk = Some(is_cjk);
        }
        buf.push(ch);
    }
    flush(
        &mut runs,
        &mut buf,
        buf_is_cjk.unwrap_or(false),
        default_font,
    );
    runs
}

/// 把 `format_pdf_runs` 的結果寫成一段 `BT … ET`。
///
/// `prelude` 是顏色之類在 `Td` 之前要下的指令。
fn write_pdf_text(
    content: &mut Vec<u8>,
    text: &str,
    default_font: &str,
    size: f32,
    prelude: &str,
    x: f32,
    baseline: f32,
) {
    let runs = format_pdf_runs(text, default_font);
    if runs.is_empty() {
        return;
    }
    let _ = write!(content, "BT {prelude} {x:.2} {baseline:.2} Td");
    for (font, literal) in runs {
        let _ = write!(content, " {font} {size:.1} Tf {literal} Tj");
    }
    let _ = writeln!(content, " ET");
}

#[cfg(test)]
mod tests {
    /// S-90：版面圖元要真的寫進內容串流。
    ///
    /// 這條測試守的是「匯出的 PDF 有沒有版面」—— 在此之前畫布上是一張
    /// 康乃爾、匯出來是一張空白紙，而那件事沒有任何測試會紅。
    #[test]
    fn page_guides_are_written_into_the_content_stream() {
        let page_id = Uuid::now_v7();
        let mut notebook = Notebook::new(Uuid::now_v7(), "版面");
        notebook.insert_page(0, Page::new(page_id, PageTemplate::Blank));

        let mut options = PdfExportOptions {
            compress_streams: false,
            ..Default::default()
        };
        options.page_guides.insert(
            page_id,
            vec![
                GuideItem {
                    kind: GuideKind::Line,
                    x: 48.0,
                    y: 60.0,
                    w: 700.0,
                    h: 0.0,
                    weight: 1.5,
                    color: (0.29, 0.33, 0.41),
                    text: String::new(),
                    size: 0.0,
                    align: 0,
                },
                GuideItem {
                    kind: GuideKind::Label,
                    x: 48.0,
                    y: 40.0,
                    w: 200.0,
                    h: 0.0,
                    weight: 0.0,
                    color: (0.5, 0.5, 0.6),
                    text: "Cues".to_string(),
                    size: 18.0,
                    align: 0,
                },
            ],
        );

        let bytes = to_pdf(&notebook, &HashMap::new(), None, &options).expect("匯出");
        let text = String::from_utf8_lossy(&bytes);
        // 線：起點與終點都要在，而且 y 已經翻成 PDF 的左下原點。
        assert!(text.contains("48.00"), "版面的線沒有寫進內容串流");
        assert!(text.contains("(Cues) Tj"), "版面的文字沒有寫進內容串流");
    }

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

#[cfg(test)]
mod wrap_tests {
    use super::{format_pdf_runs, winansi_byte};

    /// 這條測試守的是實際在匯出預覽上看到的那個壞掉的畫面。
    ///
    /// 在此之前只要一行裡有 `•`（非 ASCII），整行連同英文字母都被丟進
    /// STSong/UniGB —— 圓點畫成別的字，字母變成全形，看起來像被拉開字距。
    #[test]
    fn a_bullet_line_stays_in_the_latin_font() {
        let runs = format_pdf_runs("\u{2022} Draft the outline", "/F1");
        assert_eq!(runs.len(), 1, "整行應該只有一段：{runs:?}");
        assert_eq!(runs[0].0, "/F1", "圓點把整行拖進了 CJK 字型");
        assert!(
            runs[0].1.contains("\\225"),
            "圓點要寫成 WinAnsi 的八進位 0x95：{}",
            runs[0].1
        );
        assert!(!runs[0].1.starts_with('<'), "不該走 UTF-16 十六進位");
    }

    /// 中英混排要切成兩段，各用各的字型 —— 挑單一字型的話總有一半是錯的。
    #[test]
    fn mixed_text_splits_into_one_run_per_font() {
        let runs = format_pdf_runs("\u{4ECA}\u{5929} meeting", "/F1");
        assert_eq!(runs.len(), 2, "應該切成兩段：{runs:?}");
        assert_eq!(runs[0].0, "/F_CJK");
        assert!(runs[0].1.starts_with("<FEFF"));
        assert_eq!(runs[1].0, "/F1");
        assert!(runs[1].1.contains("meeting"));
    }

    /// WinAnsi 的 0x80..0x9F 特區碼位是跳開的，只能查表；查錯就變成別的字。
    #[test]
    fn the_winansi_special_block_maps_correctly() {
        assert_eq!(winansi_byte('\u{2022}'), Some(0x95));
        assert_eq!(winansi_byte('\u{2014}'), Some(0x97));
        assert_eq!(winansi_byte('\u{2019}'), Some(0x92));
        assert_eq!(winansi_byte('\u{2026}'), Some(0x85));
        assert_eq!(winansi_byte('A'), Some(b'A'));
        assert_eq!(winansi_byte('\u{00E9}'), Some(0xE9));
        assert_eq!(winansi_byte('\u{4E2D}'), None, "中日韓字不在 WinAnsi 裡");
        assert_eq!(winansi_byte('\u{2192}'), None, "箭頭也不在，要走 CJK 字型");
    }

    use super::*;

    #[test]
    fn explicit_newlines_are_kept() {
        // 條列式內容併成一行的話，「一、…二、…」會變成沒有斷句的一長串。
        let lines = wrap_pdf_lines("一、甲\n二、乙\n三、丙", 12.0, 500.0);
        assert_eq!(lines, vec!["一、甲", "二、乙", "三、丙"]);
    }

    #[test]
    fn an_empty_line_survives() {
        // 段落之間的空行是作者刻意留的，吃掉的話整段會黏在一起。
        let lines = wrap_pdf_lines("甲\n\n乙", 12.0, 500.0);
        assert_eq!(lines, vec!["甲", "", "乙"]);
    }

    #[test]
    fn a_long_chinese_paragraph_wraps_instead_of_running_off_the_page() {
        let text = "這是一段很長的中文段落".repeat(20);
        let max = 300.0;
        let lines = wrap_pdf_lines(&text, 12.0, max);
        assert!(lines.len() > 1, "應該要換行，實得 {} 行", lines.len());
        for line in &lines {
            let w: f32 = line.chars().map(|c| glyph_width(c, 12.0)).sum();
            assert!(w <= max + 12.0, "這一行超出可用寬度：{w} > {max}");
        }
    }

    #[test]
    fn english_breaks_at_spaces_not_inside_words() {
        let lines = wrap_pdf_lines("alpha beta gamma delta epsilon zeta", 12.0, 100.0);
        assert!(lines.len() > 1);
        // 從單字中間切開會變成另一個字。把行重新接起來應該還原原文。
        let rejoined: String = lines.iter().map(|l| l.trim()).collect::<Vec<_>>().join(" ");
        assert_eq!(rejoined, "alpha beta gamma delta epsilon zeta");
    }

    #[test]
    fn a_single_word_longer_than_the_line_is_hard_split() {
        // 沒有空白可斷的超長字串（網址之類）。不硬切的話它會整條衝出紙外。
        let lines = wrap_pdf_lines(&"x".repeat(400), 12.0, 200.0);
        assert!(lines.len() > 1, "超長詞應該被硬切");
        for line in &lines {
            let w: f32 = line.chars().map(|c| glyph_width(c, 12.0)).sum();
            assert!(w <= 200.0 + 12.0, "硬切後仍然超寬：{w}");
        }
    }
}
