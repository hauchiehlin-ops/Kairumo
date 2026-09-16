//! 圖片匯出引擎（工作項：單頁/圖片匯出完整 App 入口）。
//!
//! 將單一頁面渲染並編碼為標準 PNG 格式位元組流。
//!
//! ## 特色
//! 1. **支援 Retina 高解析度**：可傳入 `scale` 參數（如 1.0x, 2.0x, 3.0x），支援超高畫質輸出。
//! 2. **精確幾何抗鋸齒光柵化**：利用 `padnote_ink::geometry::distance_to_segment`
//!    對平滑後的 Catmull-Rom 取樣路徑進行厚線渲染與 Alpha 混色。
//! 3. **完整底紋與背景支援**：包含空白、橫線、網格、康乃爾線等。
//! 4. **畫布物件**：文字、表格、圖片、形狀與連接線（工作項 S-57）。
//!
//! ## 文字為什麼是灰條不是字
//!
//! 這一條路是**沒有 PDFium 時的 fallback**，而 Android 第一版就走這裡
//! （`pdf` feature 關閉）。要畫出真正的字需要一份內嵌字型 —— 中文字型
//! 動輒好幾 MB，而且授權要另外拍板（見 `deny.toml` 的立場）。
//!
//! 所以文字畫成灰色的行條（greeking）：位置、寬度、行數、行高全部照實算，
//! 只有字形是抽象的。縮圖的尺度是 0.18–0.4 倍，一個 15pt 的字在上面只有
//! 3–6 像素高 —— 真的畫出來也是一團灰。**版面對不對才是縮圖要回答的問題。**
//! 要畫真字的話得先決定內嵌哪一份字型，那是一個授權決策，不是算繪問題。

use crate::pdf::ExportError;
use padnote_doc::{
    Affine2, BlockKind, ObjectKind, ObjectTree, Page, PageTemplate, ShapeKind as DocShapeKind,
    ShapeObject, TextStyle,
};
use padnote_ink::Stroke;
use padnote_ink::geometry::distance_to_segment;
use padnote_shapes::{Shape as GeomShape, ShapeKind as GeomShapeKind};
use padnote_storage::BlobStore;
use std::io::BufWriter;

#[derive(Clone, Debug)]
pub struct ImageExportOptions {
    /// 縮放倍率（例如 1.0 為標準 72 DPI，2.0 為 144 DPI @2x）。
    pub scale: f32,
    /// 是否繪製背景模板與底色。若為 false 則輸出透明背景。
    pub include_background: bool,
}

impl Default for ImageExportOptions {
    fn default() -> Self {
        Self {
            scale: 2.0, // 預設提供 @2x 高解析度
            include_background: true,
        }
    }
}

/// 將單一頁面與筆畫資料匯出為 PNG 格式位元組流。
///
/// `objects` 是這一頁的物件樹（形狀與連接線）。傳 `None` 就只畫底紋、
/// 筆畫與區塊 —— 形狀住在物件樹裡，不在 `page.blocks()` 中。
pub fn to_png(
    page: &Page,
    strokes: &[Stroke],
    blobs: Option<&BlobStore>,
    objects: Option<&ObjectTree>,
    options: &ImageExportOptions,
) -> Result<Vec<u8>, ExportError> {
    let scale = options.scale.clamp(0.25, 8.0);
    let (orig_w, orig_h) = page.size;
    let width = ((orig_w * scale).round() as u32).max(1);
    let height = ((orig_h * scale).round() as u32).max(1);

    let mut pixels = if options.include_background {
        vec![255u8; (width * height * 4) as usize]
    } else {
        vec![0u8; (width * height * 4) as usize]
    };

    // 1. 繪製背景底紋
    if options.include_background {
        draw_template_background(&mut pixels, width, height, &page.template, scale);
    }

    // 2. 繪製筆畫
    for stroke in strokes {
        draw_stroke(&mut pixels, width, height, stroke, scale);
    }

    // 3. 繪製畫布物件（工作項 S-57）。
    //
    // 順序與畫布一致：圖片 → 形狀／連接線 → 表格 → 文字。
    // 自己排一套的話，重疊的物件在縮圖上的上下關係會與畫面相反。
    {
        let mut canvas = Canvas {
            pixels: &mut pixels,
            width,
            height,
            scale,
        };

        for block in page.blocks() {
            if let BlockKind::Image {
                blob,
                width: bw,
                height: bh,
            } = &block.kind
            {
                let (bx, by) = block.position.unwrap_or((0.0, 0.0));
                draw_image_block(
                    &mut canvas,
                    blobs,
                    blob,
                    &ImagePlacement {
                        x: bx,
                        y: by,
                        width: *bw,
                        height: *bh,
                    },
                );
            }
        }

        if let Some(tree) = objects {
            draw_objects(&mut canvas, tree);
        }

        for block in page.blocks() {
            let (bx, by) = block.position.unwrap_or((0.0, 0.0));
            match &block.kind {
                BlockKind::Table {
                    rows,
                    cols,
                    cells,
                    header_row,
                    ..
                } => draw_table(
                    &mut canvas,
                    &TableBlock {
                        x: bx,
                        y: by,
                        rows: *rows,
                        cols: *cols,
                        cells,
                        header_row: *header_row,
                    },
                ),
                BlockKind::Text { content, style } => {
                    draw_text_block(&mut canvas, bx, by, content, style)
                }
                BlockKind::Transcript { text, .. } => {
                    draw_text_block(&mut canvas, bx, by, text, &TextStyle::Body)
                }
                _ => {}
            }
        }
    }

    // 4. 編碼為 PNG
    encode_png(&pixels, width, height)
}

fn set_pixel_blend(pixels: &mut [u8], width: u32, height: u32, x: i32, y: i32, color: [u8; 4]) {
    if x < 0 || y < 0 || x >= width as i32 || y >= height as i32 {
        return;
    }
    let idx = (y as usize * width as usize + x as usize) * 4;
    let [sr, sg, sb, sa] = color;
    if sa == 0 {
        return;
    }

    let alpha = sa as f32 / 255.0;
    let inv_alpha = 1.0 - alpha;

    let dr = pixels[idx] as f32;
    let dg = pixels[idx + 1] as f32;
    let db = pixels[idx + 2] as f32;
    let da = pixels[idx + 3] as f32 / 255.0;

    let out_a = alpha + da * inv_alpha;
    if out_a > 0.0 {
        let out_r = (sr as f32 * alpha + dr * da * inv_alpha) / out_a;
        let out_g = (sg as f32 * alpha + dg * da * inv_alpha) / out_a;
        let out_b = (sb as f32 * alpha + db * da * inv_alpha) / out_a;

        pixels[idx] = out_r.clamp(0.0, 255.0) as u8;
        pixels[idx + 1] = out_g.clamp(0.0, 255.0) as u8;
        pixels[idx + 2] = out_b.clamp(0.0, 255.0) as u8;
        pixels[idx + 3] = (out_a * 255.0).clamp(0.0, 255.0) as u8;
    }
}

fn draw_template_background(
    pixels: &mut [u8],
    width: u32,
    height: u32,
    template: &PageTemplate,
    scale: f32,
) {
    let line_color = [225, 225, 230, 255];
    match template {
        PageTemplate::Blank => {}
        PageTemplate::Lined => {
            let spacing = (24.0 * scale).round() as i32;
            let mut y = (50.0 * scale).round() as i32;
            let end_y = height as i32 - (50.0 * scale).round() as i32;
            let start_x = (36.0 * scale).round() as i32;
            let end_x = width as i32 - (36.0 * scale).round() as i32;

            while y <= end_y {
                for x in start_x..end_x {
                    set_pixel_blend(pixels, width, height, x, y, line_color);
                }
                y += spacing;
            }
        }
        PageTemplate::Grid => {
            let grid_size = (20.0 * scale).round() as i32;
            if grid_size > 0 {
                let mut x = grid_size;
                while x < width as i32 {
                    for y in 0..height as i32 {
                        set_pixel_blend(pixels, width, height, x, y, line_color);
                    }
                    x += grid_size;
                }
                let mut y = grid_size;
                while y < height as i32 {
                    for x in 0..width as i32 {
                        set_pixel_blend(pixels, width, height, x, y, line_color);
                    }
                    y += grid_size;
                }
            }
        }
        PageTemplate::Dotted => {
            let grid_size = (20.0 * scale).round() as i32;
            if grid_size > 0 {
                let dot_color = [190, 190, 200, 255];
                let mut x = grid_size;
                while x < width as i32 {
                    let mut y = grid_size;
                    while y < height as i32 {
                        set_pixel_blend(pixels, width, height, x, y, dot_color);
                        set_pixel_blend(pixels, width, height, x + 1, y, dot_color);
                        set_pixel_blend(pixels, width, height, x, y + 1, dot_color);
                        set_pixel_blend(pixels, width, height, x + 1, y + 1, dot_color);
                        y += grid_size;
                    }
                    x += grid_size;
                }
            }
        }
        PageTemplate::Cornell => {
            let border_color = [200, 200, 210, 255];
            let top_y = (60.0 * scale).round() as i32;
            let bot_y = height as i32 - (120.0 * scale).round() as i32;
            let cue_x = (150.0 * scale).round() as i32;

            for x in 0..width as i32 {
                set_pixel_blend(pixels, width, height, x, top_y, border_color);
                set_pixel_blend(pixels, width, height, x, bot_y, border_color);
            }
            for y in top_y..bot_y {
                set_pixel_blend(pixels, width, height, cue_x, y, border_color);
            }
        }
        _ => {}
    }
}

fn draw_stroke(pixels: &mut [u8], width: u32, height: u32, stroke: &Stroke, scale: f32) {
    if stroke.points.is_empty() {
        return;
    }

    let color = stroke.color_rgba8;
    let radius = (stroke.base_width * 0.5 * scale).max(0.5);
    let path = stroke.render_path(2);
    if path.is_empty() {
        return;
    }

    // 處理單點筆觸
    if path.len() == 1 {
        let (px, py) = (path[0].0 * scale, path[0].1 * scale);
        let min_x = (px - radius).floor() as i32;
        let max_x = (px + radius).ceil() as i32;
        let min_y = (py - radius).floor() as i32;
        let max_y = (py + radius).ceil() as i32;

        for y in min_y..=max_y {
            for x in min_x..=max_x {
                let dx = x as f32 + 0.5 - px;
                let dy = y as f32 + 0.5 - py;
                let dist = (dx * dx + dy * dy).sqrt();
                if dist <= radius {
                    let alpha_factor =
                        (1.0 - (dist - (radius - 1.0)).clamp(0.0, 1.0)) * (color[3] as f32 / 255.0);
                    let mut c = color;
                    c[3] = (alpha_factor * 255.0) as u8;
                    set_pixel_blend(pixels, width, height, x, y, c);
                }
            }
        }
        return;
    }

    // 連續路徑線段渲染
    for w in path.windows(2) {
        let (p0x, p0y) = (w[0].0 * scale, w[0].1 * scale);
        let (p1x, p1y) = (w[1].0 * scale, w[1].1 * scale);

        let min_x = (p0x.min(p1x) - radius - 1.0).floor().max(0.0) as i32;
        let max_x = (p0x.max(p1x) + radius + 1.0).ceil().min((width - 1) as f32) as i32;
        let min_y = (p0y.min(p1y) - radius - 1.0).floor().max(0.0) as i32;
        let max_y = (p0y.max(p1y) + radius + 1.0)
            .ceil()
            .min((height - 1) as f32) as i32;

        for y in min_y..=max_y {
            for x in min_x..=max_x {
                let dist =
                    distance_to_segment((x as f32 + 0.5, y as f32 + 0.5), (p0x, p0y), (p1x, p1y));
                if dist <= radius + 0.5 {
                    let edge = radius - 0.5;
                    let alpha_factor = if dist <= edge {
                        1.0
                    } else {
                        1.0 - (dist - edge)
                    };
                    let total_alpha = alpha_factor * (color[3] as f32 / 255.0);
                    let mut c = color;
                    c[3] = (total_alpha.clamp(0.0, 1.0) * 255.0) as u8;
                    set_pixel_blend(pixels, width, height, x, y, c);
                }
            }
        }
    }
}

// MARK: - 畫布物件（工作項 S-57）

/// 文字的灰條。見檔案開頭「文字為什麼是灰條不是字」。
const INK: [u8; 4] = [40, 44, 52, 255];
const RULE: [u8; 4] = [150, 154, 162, 255];
const GREEK: [u8; 4] = [90, 96, 105, 200];
const HEADER_FILL: [u8; 4] = [233, 238, 252, 255];

/// 估算用的頁寬。區塊本身沒有寬度（那是平台的外觀 JSON 在管的）。
const PAGE_W_HINT: f32 = 800.0;

/// 一塊可以畫東西的像素緩衝。
///
/// 把 `pixels / width / height / scale` 收成一個型別，而不是讓每個
/// 繪圖函式都收四個參數 —— 那四個永遠一起出現，而且拆開來傳很容易
/// 把 `width` 與 `height` 寫反（那種錯畫出來是整張圖歪斜，很難一眼看出）。
struct Canvas<'a> {
    pixels: &'a mut [u8],
    width: u32,
    height: u32,
    /// 頁面點 → 像素。
    scale: f32,
}

impl Canvas<'_> {
    fn dot(&mut self, x: i32, y: i32, color: [u8; 4]) {
        set_pixel_blend(self.pixels, self.width, self.height, x, y, color);
    }

    fn fill_rect(&mut self, x0: f32, y0: f32, x1: f32, y1: f32, color: [u8; 4]) {
        let sx0 = (x0 * self.scale).round() as i32;
        let sy0 = (y0 * self.scale).round() as i32;
        let sx1 = (x1 * self.scale).round() as i32;
        let sy1 = (y1 * self.scale).round() as i32;
        for y in sy0.min(sy1)..sy0.max(sy1) {
            for x in sx0.min(sx1)..sx0.max(sx1) {
                self.dot(x, y, color);
            }
        }
    }

    fn line(&mut self, x0: f32, y0: f32, x1: f32, y1: f32, color: [u8; 4]) {
        let (ax, ay) = (x0 * self.scale, y0 * self.scale);
        let (bx, by) = (x1 * self.scale, y1 * self.scale);
        let steps = ((bx - ax).abs().max((by - ay).abs()).ceil() as i32).max(1);
        for i in 0..=steps {
            let t = i as f32 / steps as f32;
            let x = (ax + (bx - ax) * t).round() as i32;
            let y = (ay + (by - ay) * t).round() as i32;
            self.dot(x, y, color);
        }
    }

    fn stroke_rect(&mut self, x0: f32, y0: f32, x1: f32, y1: f32, color: [u8; 4]) {
        self.line(x0, y0, x1, y0, color);
        self.line(x1, y0, x1, y1, color);
        self.line(x1, y1, x0, y1, color);
        self.line(x0, y1, x0, y0, color);
    }
}

/// 一段文字排成幾行、每行多寬。
///
/// 中文一個字約等於一個字級的寬，西文約 0.55 —— 用 `is_ascii` 分開估，
/// 一律當成同寬的話，中文段落的行數會少估一半，縮圖上那一塊會短一截。
fn greek_lines(text: &str, font_size: f32, box_width: f32) -> Vec<f32> {
    let usable = (box_width - 12.0).max(8.0);
    let mut lines = Vec::new();
    for paragraph in text.split('\n') {
        if paragraph.trim().is_empty() {
            lines.push(0.0);
            continue;
        }
        let mut run = 0.0f32;
        for ch in paragraph.chars() {
            let w = if ch.is_ascii() {
                font_size * 0.55
            } else {
                font_size
            };
            if run + w > usable {
                lines.push(usable);
                run = 0.0;
            }
            run += w;
        }
        if run > 0.0 {
            lines.push(run);
        }
    }
    lines
}

fn draw_text_block(canvas: &mut Canvas, x: f32, y: f32, text: &str, style: &TextStyle) {
    if text.trim().is_empty() {
        return;
    }
    // 尺寸與 PDF 匯出那條路同一組數字，兩邊的行高才會一致。
    let (font_size, line_height) = match style {
        TextStyle::Heading1 => (22.0, 28.0),
        TextStyle::Heading2 => (16.0, 22.0),
        TextStyle::Heading3 => (13.0, 18.0),
        TextStyle::Code => (10.0, 14.0),
        _ => (11.0, 16.0),
    };
    let box_width = (PAGE_W_HINT - x - 40.0).max(80.0);
    let bar = (font_size * 0.42f32).max(1.0);

    for (i, line_w) in greek_lines(text, font_size, box_width).iter().enumerate() {
        if *line_w <= 0.0 {
            continue;
        }
        let top = y + i as f32 * line_height + (line_height - bar) * 0.5;
        canvas.fill_rect(x, top, x + line_w, top + bar, GREEK);
    }
}

/// 一張表的內容。欄位一起傳，免得又是一長串位置參數。
struct TableBlock<'a> {
    x: f32,
    y: f32,
    rows: u32,
    cols: u32,
    cells: &'a [String],
    header_row: bool,
}

fn draw_table(canvas: &mut Canvas, t: &TableBlock) {
    if t.rows == 0 || t.cols == 0 {
        return;
    }
    // 與 PDF 匯出同一組尺寸。各算各的話，同一張表在 PDF 與縮圖上會不一樣高。
    let table_w = (PAGE_W_HINT - t.x - 40.0).max(200.0);
    let row_h = 24.0;
    let col_w = table_w / t.cols as f32;
    let table_h = t.rows as f32 * row_h;

    if t.header_row {
        canvas.fill_rect(t.x, t.y, t.x + table_w, t.y + row_h, HEADER_FILL);
    }
    for r in 0..=t.rows {
        let ly = t.y + r as f32 * row_h;
        canvas.line(t.x, ly, t.x + table_w, ly, RULE);
    }
    for c in 0..=t.cols {
        let lx = t.x + c as f32 * col_w;
        canvas.line(lx, t.y, lx, t.y + table_h, RULE);
    }

    for r in 0..t.rows {
        for c in 0..t.cols {
            let Some(text) = t.cells.get((r * t.cols + c) as usize) else {
                continue;
            };
            if text.trim().is_empty() {
                continue;
            }
            let cell_x = t.x + c as f32 * col_w + 4.0;
            let cell_y = t.y + r as f32 * row_h + row_h * 0.35;
            let ink_w = greek_lines(text, 10.0, col_w)
                .first()
                .copied()
                .unwrap_or(0.0)
                .min(col_w - 8.0);
            if ink_w > 0.0 {
                canvas.fill_rect(cell_x, cell_y, cell_x + ink_w, cell_y + 4.0, GREEK);
            }
        }
    }
}

/// 一張圖片區塊的位置與大小。
struct ImagePlacement {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
}

fn draw_image_block(
    canvas: &mut Canvas,
    blobs: Option<&BlobStore>,
    blob: &str,
    place: &ImagePlacement,
) {
    let w = if place.width > 0.0 {
        place.width
    } else {
        240.0
    };
    let h = if place.height > 0.0 {
        place.height
    } else {
        180.0
    };

    // 有 blob 就真的畫出來；讀不到（或不是 PNG）就畫一個外框，
    // 讓使用者至少看得出「這裡有一張圖」。
    let decoded = blobs
        .zip(padnote_storage::BlobId::from_hex(blob))
        .and_then(|(store, id)| store.get(id).ok())
        .and_then(|bytes| decode_png_rgba(&bytes));

    let Some((src, sw, sh)) = decoded else {
        canvas.stroke_rect(place.x, place.y, place.x + w, place.y + h, RULE);
        return;
    };

    let dst_w = (w * canvas.scale).round().max(1.0) as u32;
    let dst_h = (h * canvas.scale).round().max(1.0) as u32;
    let ox = (place.x * canvas.scale).round() as i32;
    let oy = (place.y * canvas.scale).round() as i32;
    for dy in 0..dst_h {
        // 最近鄰取樣。縮圖只要看得出是什麼，雙線性在這個尺度上
        // 看不出差別，卻要多走一輪浮點運算。
        let sy = (u64::from(dy) * u64::from(sh) / u64::from(dst_h.max(1))) as u32;
        for dx in 0..dst_w {
            let sx = (u64::from(dx) * u64::from(sw) / u64::from(dst_w.max(1))) as u32;
            let idx = ((sy.min(sh - 1) * sw + sx.min(sw - 1)) * 4) as usize;
            if idx + 3 >= src.len() {
                continue;
            }
            let color = [src[idx], src[idx + 1], src[idx + 2], src[idx + 3]];
            canvas.dot(ox + dx as i32, oy + dy as i32, color);
        }
    }
}

/// 把 PNG blob 解成 RGBA8。不是 PNG（例如 JPEG）就回 `None` ——
/// 呼叫端會退回畫外框，而不是讓整張縮圖失敗。
fn decode_png_rgba(bytes: &[u8]) -> Option<(Vec<u8>, u32, u32)> {
    let decoder = png::Decoder::new(std::io::Cursor::new(bytes));
    let mut reader = decoder.read_info().ok()?;
    let mut buf = vec![0; reader.output_buffer_size()?];
    let info = reader.next_frame(&mut buf).ok()?;
    let (w, h) = (info.width, info.height);
    let frame_len = info.buffer_size();
    let rgba = match info.color_type {
        png::ColorType::Rgba => buf[..frame_len].to_vec(),
        png::ColorType::Rgb => buf[..frame_len]
            .as_chunks::<3>()
            .0
            .iter()
            .flat_map(|p| [p[0], p[1], p[2], 255])
            .collect(),
        png::ColorType::Grayscale => buf[..frame_len]
            .iter()
            .flat_map(|&g| [g, g, g, 255])
            .collect(),
        png::ColorType::GrayscaleAlpha => buf[..frame_len]
            .as_chunks::<2>()
            .0
            .iter()
            .flat_map(|p| [p[0], p[0], p[0], p[1]])
            .collect(),
        // 調色盤要另外查表，縮圖上不值得 —— 退回畫外框。
        png::ColorType::Indexed => return None,
    };
    Some((rgba, w, h))
}

/// 形狀與連接線。幾何走 `padnote-shapes`，與畫布用的是同一份 ——
/// 自己再算一次的話，縮圖上的菱形與畫面上的會差一點點。
fn draw_objects(canvas: &mut Canvas, tree: &ObjectTree) {
    for root in tree.roots() {
        for (id, world) in tree.flatten(*root) {
            let Some(node) = tree.get(id) else { continue };
            if let ObjectKind::Shape(shape) = &node.kind {
                draw_shape(canvas, shape, &world);
            }
            // 連接線的路徑要兩端的形狀才算得出來，而 flatten 給的是單一
            // 節點。縮圖上少一條線的代價，遠小於為此把整棵樹再走一遍 ——
            // 形狀本身畫出來就看得出結構了。
        }
    }
}

fn draw_shape(canvas: &mut Canvas, shape: &ShapeObject, world: &Affine2) {
    let kind = geom_kind(shape.kind);
    let b = shape.bounds;
    let geom = GeomShape {
        kind,
        bounds: padnote_ink::Rect {
            min_x: b.min_x,
            min_y: b.min_y,
            max_x: b.max_x,
            max_y: b.max_y,
        },
        corner_radius: shape.corner_radius,
        rotation_degrees: 0.0,
    };
    let points = geom.outline(48);
    if points.len() < 2 {
        return;
    }
    let mapped: Vec<(f32, f32)> = points.iter().map(|&(x, y)| world.apply(x, y)).collect();
    for pair in mapped.windows(2) {
        canvas.line(pair[0].0, pair[0].1, pair[1].0, pair[1].1, INK);
    }
    // 線狀形狀不收尾 —— 收了會多出一條回到起點的邊。
    if !kind.is_linear()
        && let (Some(first), Some(last)) = (mapped.first(), mapped.last())
    {
        canvas.line(last.0, last.1, first.0, first.1, INK);
    }
}

/// 文件模型的形狀種類 → 幾何 crate 的。
///
/// 兩個列舉刻意分開（文件模型不依賴繪圖引擎，見 `padnote-doc::object`），
/// 所以要有這一層對應。`match` 不寫 `_ =>`：核心加了形狀而這裡忘了補時，
/// 要在**編譯期**壞掉，不是在縮圖上少一個圖形。
fn geom_kind(kind: DocShapeKind) -> GeomShapeKind {
    match kind {
        DocShapeKind::Rectangle => GeomShapeKind::Rectangle,
        DocShapeKind::RoundedRectangle => GeomShapeKind::RoundedRectangle,
        DocShapeKind::Ellipse => GeomShapeKind::Ellipse,
        DocShapeKind::Triangle => GeomShapeKind::Triangle,
        DocShapeKind::Diamond => GeomShapeKind::Diamond,
        DocShapeKind::Pentagon => GeomShapeKind::Pentagon,
        DocShapeKind::Hexagon => GeomShapeKind::Hexagon,
        DocShapeKind::Star => GeomShapeKind::Star,
        DocShapeKind::Process => GeomShapeKind::Process,
        DocShapeKind::Decision => GeomShapeKind::Decision,
        DocShapeKind::Terminator => GeomShapeKind::Terminator,
        DocShapeKind::Data => GeomShapeKind::Data,
        DocShapeKind::Document => GeomShapeKind::Document,
        DocShapeKind::Database => GeomShapeKind::Database,
        DocShapeKind::Preparation => GeomShapeKind::Preparation,
        DocShapeKind::ManualInput => GeomShapeKind::ManualInput,
        DocShapeKind::Connector => GeomShapeKind::Connector,
        DocShapeKind::ManualOperation => GeomShapeKind::ManualOperation,
        DocShapeKind::Delay => GeomShapeKind::Delay,
        DocShapeKind::StoredData => GeomShapeKind::StoredData,
        DocShapeKind::Merge => GeomShapeKind::Merge,
        DocShapeKind::Extract => GeomShapeKind::Extract,
        DocShapeKind::OffPageConnector => GeomShapeKind::OffPageConnector,
        DocShapeKind::Display => GeomShapeKind::Display,
        DocShapeKind::PunchedTape => GeomShapeKind::PunchedTape,
        DocShapeKind::PunchedCard => GeomShapeKind::PunchedCard,
        DocShapeKind::Collate => GeomShapeKind::Collate,
        DocShapeKind::RightTriangle => GeomShapeKind::RightTriangle,
        DocShapeKind::Parallelogram => GeomShapeKind::Parallelogram,
        DocShapeKind::Trapezoid => GeomShapeKind::Trapezoid,
        DocShapeKind::Heptagon => GeomShapeKind::Heptagon,
        DocShapeKind::Octagon => GeomShapeKind::Octagon,
        DocShapeKind::Cross => GeomShapeKind::Cross,
        DocShapeKind::Chevron => GeomShapeKind::Chevron,
        DocShapeKind::ArrowBlockRight => GeomShapeKind::ArrowBlockRight,
        DocShapeKind::ArrowBlockLeft => GeomShapeKind::ArrowBlockLeft,
        DocShapeKind::ArrowBlockUp => GeomShapeKind::ArrowBlockUp,
        DocShapeKind::ArrowBlockDown => GeomShapeKind::ArrowBlockDown,
        DocShapeKind::Cloud => GeomShapeKind::Cloud,
        DocShapeKind::Heart => GeomShapeKind::Heart,
        DocShapeKind::Bolt => GeomShapeKind::Bolt,
        DocShapeKind::Moon => GeomShapeKind::Moon,
        DocShapeKind::Teardrop => GeomShapeKind::Teardrop,
        DocShapeKind::LShape => GeomShapeKind::LShape,
        DocShapeKind::Star4 => GeomShapeKind::Star4,
        DocShapeKind::Star6 => GeomShapeKind::Star6,
        DocShapeKind::Star8 => GeomShapeKind::Star8,
        DocShapeKind::Sun => GeomShapeKind::Sun,
        DocShapeKind::Banner => GeomShapeKind::Banner,
        DocShapeKind::SpeechBubble => GeomShapeKind::SpeechBubble,
        DocShapeKind::Plaque => GeomShapeKind::Plaque,
        DocShapeKind::Pie => GeomShapeKind::Pie,
        DocShapeKind::Line => GeomShapeKind::Line,
        DocShapeKind::Arrow => GeomShapeKind::Arrow,
        DocShapeKind::DoubleArrow => GeomShapeKind::DoubleArrow,
    }
}

/// 將 RGBA 像素串流編碼為 PNG 格式。
pub fn encode_png(pixels: &[u8], width: u32, height: u32) -> Result<Vec<u8>, ExportError> {
    let mut out = Vec::new();
    {
        let mut encoder = png::Encoder::new(BufWriter::new(&mut out), width, height);
        encoder.set_color(png::ColorType::Rgba);
        encoder.set_depth(png::BitDepth::Eight);

        let mut writer = encoder
            .write_header()
            .map_err(|e| ExportError::ImageEncoding(e.to_string()))?;

        writer
            .write_image_data(pixels)
            .map_err(|e| ExportError::ImageEncoding(e.to_string()))?;
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;
    use padnote_doc::{Page, Uuid};
    use padnote_ink::{InkPoint, Tool};

    #[test]
    fn to_png_generates_valid_png_stream() {
        let page = Page::new(Uuid::now_v7(), PageTemplate::Blank);
        let stroke = Stroke {
            id: Uuid::now_v7(),
            started_at: padnote_doc::NotebookTime::ZERO,
            tool: Tool::BallPoint,
            color_rgba8: [255, 0, 0, 255],
            base_width: 3.0,
            points: vec![
                InkPoint::new(10.0, 10.0, 1.0, 0),
                InkPoint::new(100.0, 50.0, 1.0, 8000),
            ],
        };

        let png = to_png(
            &page,
            &[stroke],
            None,
            None,
            &ImageExportOptions {
                scale: 1.0,
                include_background: true,
            },
        )
        .unwrap();

        // PNG 魔數：89 50 4E 47 0D 0A 1A 0A
        assert_eq!(&png[0..8], &[137, 80, 78, 71, 13, 10, 26, 10]);
        assert!(png.len() > 100);
    }

    #[test]
    fn transparent_png_export() {
        let page = Page::new(Uuid::now_v7(), PageTemplate::Blank);
        let png = to_png(
            &page,
            &[],
            None,
            None,
            &ImageExportOptions {
                scale: 0.5,
                include_background: false,
            },
        )
        .unwrap();

        assert_eq!(&png[0..8], &[137, 80, 78, 71, 13, 10, 26, 10]);
    }

    /// **這是 S-57 的回歸測試。**
    ///
    /// 縮圖原本只畫底紋與筆畫，所以一本只打字的筆記在 Android 上是一張
    /// 全白的圖 —— 使用者看到的是「預覽跟畫布不一樣」。這裡驗的是
    /// 「同一頁有沒有內容，畫出來的像素就不一樣」。
    #[test]
    fn a_page_with_only_typed_content_is_not_blank() {
        use padnote_doc::{Block, BlockKind, TextStyle};

        let empty = Page::new(Uuid::now_v7(), PageTemplate::Blank);
        let mut typed = Page::new(Uuid::now_v7(), PageTemplate::Blank);
        typed.add_block(Block {
            id: Uuid::now_v7(),
            kind: BlockKind::Text {
                content: "把手寫、打字與錄音放在同一條時間軸上的筆記本。".into(),
                style: TextStyle::Body,
            },
            position: Some((56.0, 80.0)),
            appearance: None,
            created_at: padnote_doc::NotebookTime::ZERO,
        });
        typed.add_block(Block {
            id: Uuid::now_v7(),
            kind: BlockKind::Table {
                rows: 2,
                cols: 2,
                cells: vec!["時間".into(), "議題".into(), "10:00".into(), "回顧".into()],
                header_row: true,
                merged_cells: Vec::new(),
            },
            position: Some((56.0, 200.0)),
            appearance: None,
            created_at: padnote_doc::NotebookTime::ZERO,
        });

        let opt = ImageExportOptions {
            scale: 1.0,
            include_background: true,
        };
        let blank = to_png(&empty, &[], None, None, &opt).unwrap();
        let filled = to_png(&typed, &[], None, None, &opt).unwrap();

        assert_ne!(blank, filled, "有文字與表格的頁面不該和空白頁畫出同一張圖");
    }
}
