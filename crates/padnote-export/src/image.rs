//! 圖片匯出引擎（工作項：單頁/圖片匯出完整 App 入口）。
//!
//! 將單一頁面渲染並編碼為標準 PNG 格式位元組流。
//!
//! ## 特色
//! 1. **支援 Retina 高解析度**：可傳入 `scale` 參數（如 1.0x, 2.0x, 3.0x），支援超高畫質輸出。
//! 2. **精確幾何抗鋸齒光柵化**：利用 `padnote_ink::geometry::distance_to_segment`
//!    對平滑後的 Catmull-Rom 取樣路徑進行厚線渲染與 Alpha 混色。
//! 3. **完整底紋與背景支援**：包含空白、橫線、網格、康乃爾線等。

use crate::pdf::ExportError;
use padnote_doc::{Page, PageTemplate};
use padnote_ink::Stroke;
use padnote_ink::geometry::distance_to_segment;
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
pub fn to_png(
    page: &Page,
    strokes: &[Stroke],
    _blobs: Option<&BlobStore>,
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

    // 3. 編碼為 PNG
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
                    let alpha_factor = (1.0 - (dist - (radius - 1.0)).clamp(0.0, 1.0))
                        * (color[3] as f32 / 255.0);
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
        let max_y = (p0y.max(p1y) + radius + 1.0).ceil().min((height - 1) as f32) as i32;

        for y in min_y..=max_y {
            for x in min_x..=max_x {
                let dist = distance_to_segment(
                    (x as f32 + 0.5, y as f32 + 0.5),
                    (p0x, p0y),
                    (p1x, p1y),
                );
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
            &ImageExportOptions {
                scale: 0.5,
                include_background: false,
            },
        )
        .unwrap();

        assert_eq!(&png[0..8], &[137, 80, 78, 71, 13, 10, 26, 10]);
    }
}
