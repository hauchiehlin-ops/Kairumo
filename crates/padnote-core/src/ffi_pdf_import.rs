//! 把一份 PDF 整份匯入成筆記內頁：每一頁 PDF 放在哪裡、算繪成多大。
//!
//! # 為什麼要有上限
//!
//! 原本的做法是「PDF 頁面點數 × 2」直接算繪。那對 A4（595×842 點）沒問題，
//! 但掃描器輸出的 PDF 常把 mediaBox 寫成**像素**（300 dpi 的 A4 是
//! 2480×3508）——乘 2 之後是 4960×7016、一張 139 MB 的點陣圖。實測
//! （iPad 模擬器）：按下確定後主執行緒做了兩次這個大小的 PNG 編碼，
//! 介面停住好幾秒；在實機上更久，而且整份匯入時每一頁都來一次。
//!
//! 算繪大小應該由**它在筆記裡顯示多大**決定，不是由 PDF 宣稱自己多大決定。
//! 這裡依內頁大小算出放置框，再乘上顯示倍率，最後夾在像素上限之內。
//!
//! # 為什麼在核心
//!
//! 兩端放置的位置要一致：同一份 PDF 在 iPad 匯入、在 Android 打開，
//! 頁面不能一邊貼齊、一邊偏一截。

/// 一頁 PDF 在筆記內頁上的位置（內頁座標，點）與算繪像素大小。
#[derive(Clone, Copy, Debug, PartialEq, uniffi::Record)]
pub struct FfiPdfPagePlacement {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
    pub pixel_width: u32,
    pub pixel_height: u32,
}

/// 算繪結果長邊的上限（像素）。
///
/// 3072 已經比 iPad Pro 13 吋的長邊（2752）大；再大只是浪費記憶體與同步流量，
/// 放大看也不會更清楚多少。
pub const PDF_RENDER_MAX_EDGE: u32 = 3072;

/// 算繪結果總像素的上限（約 600 萬像素 ≈ 24 MB 的 RGBA）。
pub const PDF_RENDER_MAX_PIXELS: u64 = 6_000_000;

/// 一頁 PDF 要放在內頁的哪裡、算繪成多大。
///
/// - 等比縮放到**整個內頁**放得下的最大尺寸（不留邊）。
/// - 水平置中，**貼齊上緣**：直式 PDF 在直式內頁上幾乎填滿；橫式的投影片
///   在直式內頁上則會在下方留出一塊空白，正好拿來寫筆記。
/// - `render_scale` 是顯示倍率（2.0 ≈ Retina）。結果夾在
///   [`PDF_RENDER_MAX_EDGE`] 與 [`PDF_RENDER_MAX_PIXELS`] 之內。
///
/// 尺寸不合理（零、負數、NaN）回 `None`，平台端略過那一頁並告訴使用者。
#[uniffi::export]
pub fn pdf_page_placement(
    source_width: f32,
    source_height: f32,
    page_width: f32,
    page_height: f32,
    render_scale: f32,
) -> Option<FfiPdfPagePlacement> {
    let valid = |v: f32| v.is_finite() && v > 0.0;
    if !valid(source_width) || !valid(source_height) || !valid(page_width) || !valid(page_height) {
        return None;
    }
    let scale = if valid(render_scale) {
        render_scale
    } else {
        1.0
    };

    let fit = (page_width / source_width).min(page_height / source_height);
    let width = source_width * fit;
    let height = source_height * fit;
    let x = (page_width - width) / 2.0;

    let mut px_w = (width * scale) as f64;
    let mut px_h = (height * scale) as f64;
    let edge = px_w.max(px_h);
    if edge > PDF_RENDER_MAX_EDGE as f64 {
        let k = PDF_RENDER_MAX_EDGE as f64 / edge;
        px_w *= k;
        px_h *= k;
    }
    let area = px_w * px_h;
    if area > PDF_RENDER_MAX_PIXELS as f64 {
        let k = (PDF_RENDER_MAX_PIXELS as f64 / area).sqrt();
        px_w *= k;
        px_h *= k;
    }

    Some(FfiPdfPagePlacement {
        x,
        y: 0.0,
        width,
        height,
        pixel_width: (px_w.round() as u32).max(1),
        pixel_height: (px_h.round() as u32).max(1),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a4_pdf_fills_an_a4_page() {
        let p = pdf_page_placement(595.0, 842.0, 595.0, 842.0, 2.0).unwrap();
        assert_eq!((p.x, p.y, p.width, p.height), (0.0, 0.0, 595.0, 842.0));
        assert_eq!((p.pixel_width, p.pixel_height), (1190, 1684));
    }

    #[test]
    fn a_scanner_pdf_measured_in_pixels_is_not_rendered_at_35_megapixels() {
        // 回報的卡頓：2480×3508 的 mediaBox × 2 = 4960×7016。
        let p = pdf_page_placement(2480.0, 3508.0, 800.0, 1131.0, 2.0).unwrap();
        assert!((p.width - 799.6).abs() < 1.0 && (p.height - 1131.0).abs() < 0.01);
        assert!(p.pixel_width <= PDF_RENDER_MAX_EDGE && p.pixel_height <= PDF_RENDER_MAX_EDGE);
        assert!((p.pixel_width as u64) * (p.pixel_height as u64) <= PDF_RENDER_MAX_PIXELS + 4096);
        // 放置框照內頁算，不是照 PDF 宣稱的大小。
        assert_eq!((p.pixel_width, p.pixel_height), (1599, 2262));
    }

    #[test]
    fn a_landscape_slide_is_centered_and_top_aligned_on_a_portrait_page() {
        let p = pdf_page_placement(960.0, 540.0, 800.0, 1131.0, 2.0).unwrap();
        assert_eq!(p.width, 800.0);
        assert_eq!(p.height, 450.0);
        assert_eq!((p.x, p.y), (0.0, 0.0));
        let tall = pdf_page_placement(500.0, 2000.0, 800.0, 1000.0, 2.0).unwrap();
        assert_eq!(tall.height, 1000.0);
        assert_eq!(tall.x, (800.0 - 250.0) / 2.0);
    }

    #[test]
    fn huge_pages_are_capped_by_edge_and_area() {
        let p = pdf_page_placement(1000.0, 1000.0, 6000.0, 6000.0, 2.0).unwrap();
        assert!(p.pixel_width <= PDF_RENDER_MAX_EDGE);
        assert!((p.pixel_width as u64) * (p.pixel_height as u64) <= PDF_RENDER_MAX_PIXELS + 4096);
    }

    #[test]
    fn nonsense_sizes_are_rejected() {
        assert!(pdf_page_placement(0.0, 842.0, 595.0, 842.0, 2.0).is_none());
        assert!(pdf_page_placement(595.0, f32::NAN, 595.0, 842.0, 2.0).is_none());
        assert!(pdf_page_placement(595.0, 842.0, -1.0, 842.0, 2.0).is_none());
        // 倍率不合理就當 1。
        let p = pdf_page_placement(595.0, 842.0, 595.0, 842.0, 0.0).unwrap();
        assert_eq!(p.pixel_width, 595);
    }
}
