//! 互通相關的 FFI（S-41 / S-42，ADR-0008 / ADR-0009）。

use padnote_embed::{EmbedFormat, Interaction, Limitations};

/// 一個格式的能力與限制。
///
/// UI 在匯入對話框顯示這些 —— **讓使用者按下前就知道會失去什麼**，
/// 而不是事後才發現東西不見了。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FormatInfo {
    /// `docx` / `xlsx` / `pptx` / `md` / `json` / `pdf`
    pub format: String,
    /// `preview` / `editable` / `linked`
    pub interaction: String,
    pub is_editable: bool,
    /// **明確不支援**的項目，逐條顯示給使用者。
    pub limitations: Vec<String>,
}

/// 查詢某個副檔名的格式資訊。無法辨識時回傳 `None`。
#[uniffi::export]
pub fn format_info(extension: String) -> Option<FormatInfo> {
    let f = EmbedFormat::from_extension(&extension)?;
    Some(FormatInfo {
        format: format!("{f:?}").to_lowercase(),
        interaction: match f.default_interaction() {
            Interaction::Preview => "preview",
            Interaction::Editable => "editable",
            Interaction::Linked => "linked",
        }
        .into(),
        is_editable: f.is_editable(),
        limitations: Limitations::for_format(f)
            .iter()
            .map(ToString::to_string)
            .collect(),
    })
}

/// 可匯入的所有格式。
#[uniffi::export]
pub fn supported_import_formats() -> Vec<FormatInfo> {
    ["docx", "xlsx", "pptx", "md", "json", "pdf"]
        .into_iter()
        .filter_map(|e| format_info(e.into()))
        .collect()
}

// ---- PDF 標註（S-42）----

/// 頁面座標與 PDF 使用者空間的對應。
///
/// ⚠️ 兩者的 Y 軸方向相反。忘記翻轉的結果是標註上下顛倒，
/// 而且**在自己的 App 裡看起來正常** —— 只有在別的 App 打開才會發現。
#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct FfiPageMapping {
    /// PDF 頁面高度（點）。
    pub page_height: f32,
    /// 頁面座標對 PDF 點的比例。
    pub scale: f32,
}

impl From<FfiPageMapping> for padnote_pdf::PageMapping {
    fn from(m: FfiPageMapping) -> Self {
        Self {
            page_height: m.page_height,
            scale: m.scale,
        }
    }
}

/// 一個 PDF 標註（供匯入匯出互通）。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiPdfAnnotation {
    /// PDF 的 `/Subtype`：`Ink` / `Highlight` / `Underline` / …
    pub subtype: String,
    pub page_index: u32,
    /// 扁平化的路徑點（x0, y0, x1, y1, …），PDF 使用者空間。
    pub ink_path: Vec<f32>,
    /// RGB 0–1。**PDF 的 `/C` 是 0–1 不是 0–255。**
    pub color: Vec<f32>,
    pub opacity: f32,
    pub width: f32,
    pub contents: String,
}

/// 頁面座標 → PDF 使用者空間。
#[uniffi::export]
pub fn page_point_to_pdf(mapping: FfiPageMapping, x: f32, y: f32) -> Vec<f32> {
    let (px, py) = padnote_pdf::PageMapping::from(mapping).to_pdf(x, y);
    vec![px, py]
}

/// PDF 使用者空間 → 頁面座標。
#[uniffi::export]
pub fn pdf_point_to_page(mapping: FfiPageMapping, x: f32, y: f32) -> Vec<f32> {
    let (px, py) = padnote_pdf::PageMapping::from(mapping).to_page(x, y);
    vec![px, py]
}

/// 從矩形算出 Highlight 標註的 `QuadPoints`。
///
/// 順序是**左上、右上、左下、右下** —— 不是順時針也不是逆時針。
/// 寫錯的話部分檢視器會顯示成扭曲的四邊形。
#[uniffi::export]
pub fn highlight_quad_points(
    mapping: FfiPageMapping,
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,
) -> Vec<f32> {
    padnote_pdf::quad_points_for_rect(x0, y0, x1, y1, &mapping.into()).to_vec()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn mapping() -> FfiPageMapping {
        FfiPageMapping {
            page_height: 842.0,
            scale: 1.0,
        }
    }

    #[test]
    fn format_info_exposes_limitations() {
        let info = format_info("xlsx".into()).unwrap();
        assert!(info.is_editable);
        assert!(
            info.limitations.iter().any(|l| l.contains("巨集")),
            "使用者要在匯入前知道巨集不支援"
        );
    }

    #[test]
    fn pptx_is_reported_as_preview_only() {
        let info = format_info("pptx".into()).unwrap();
        assert!(!info.is_editable);
        assert_eq!(info.interaction, "preview");
        assert!(info.limitations.iter().any(|l| l.contains("僅預覽")));
    }

    #[test]
    fn unknown_extension_returns_none() {
        assert!(format_info("exe".into()).is_none());
    }

    #[test]
    fn all_supported_formats_are_listed() {
        let all = supported_import_formats();
        assert_eq!(all.len(), 6);
        assert!(all.iter().any(|f| f.format == "docx"));
    }

    #[test]
    fn y_axis_flips_across_the_boundary() {
        // 這是 PDF 互通最常見的錯誤，必須在 FFI 層也正確。
        assert_eq!(page_point_to_pdf(mapping(), 100.0, 0.0), vec![100.0, 842.0]);
        assert_eq!(pdf_point_to_page(mapping(), 100.0, 842.0), vec![100.0, 0.0]);
    }

    #[test]
    fn coordinate_conversion_round_trips() {
        let p = page_point_to_pdf(mapping(), 123.0, 456.0);
        let back = pdf_point_to_page(mapping(), p[0], p[1]);
        assert!((back[0] - 123.0).abs() < 1e-4 && (back[1] - 456.0).abs() < 1e-4);
    }

    #[test]
    fn quad_points_have_eight_values_in_pdf_order() {
        let q = highlight_quad_points(mapping(), 10.0, 20.0, 110.0, 40.0);
        assert_eq!(q.len(), 8);
        let (top, bottom) = (822.0, 802.0);
        assert_eq!(q, vec![10.0, top, 110.0, top, 10.0, bottom, 110.0, bottom]);
    }
}
