//! 圖例元件：地圖、圖表著色後，在旁邊寫「哪個顏色代表什麼」。
//!
//! # 為什麼在核心
//!
//! 圖例是一個**有格式的文字方塊**：標題粗體，每行開頭一個色塊「■」接說明。
//! 色塊的位置以 UTF-16 碼元計（逐字格式 `runs` 的單位，見 RichText），兩端各算
//! 一次就是兩份會漂移的偏移量計算 —— 尤其中文、泰文、emoji 的長度一錯，色塊就會
//! 染到說明文字上。核心算一次，兩端照著建方塊。

/// 圖例色塊（UTF-16 偏移與長度）。
#[derive(Clone, Debug, PartialEq, uniffi::Record)]
pub struct FfiLegendRun {
    pub start: u32,
    pub length: u32,
    /// `#RRGGBB`。空字串 = 粗體標題（不改顏色）。
    pub color_hex: String,
    pub bold: bool,
}

/// 一個圖例方塊的內容。
#[derive(Clone, Debug, PartialEq, uniffi::Record)]
pub struct FfiLegendBox {
    pub text: String,
    pub runs: Vec<FfiLegendRun>,
    /// 建議高度（點），依行數與字級。
    pub height: f32,
}

/// 色塊符號。
const SWATCH: &str = "■";

/// 預設色票：地圖著色最常用、彼此易分的五色。
#[uniffi::export]
pub fn legend_default_colors() -> Vec<String> {
    ["#E53935", "#FB8C00", "#FDD835", "#43A047", "#1E88E5"]
        .iter()
        .map(|s| s.to_string())
        .collect()
}

fn utf16_len(s: &str) -> u32 {
    s.encode_utf16().count() as u32
}

/// 組一個圖例：`title` 一行（粗體），之後每個 `labels[i]` 一行，前面是 `colors[i]` 的色塊。
///
/// 顏色比說明少時循環使用；空的說明照樣保留一行（使用者稍後自己填）。
#[uniffi::export]
pub fn legend_box(
    title: String,
    labels: Vec<String>,
    colors: Vec<String>,
    font_size: f32,
) -> FfiLegendBox {
    let colors = if colors.is_empty() {
        legend_default_colors()
    } else {
        colors
    };
    let mut text = String::new();
    let mut runs = Vec::new();
    let mut lines = 0u32;
    if !title.is_empty() {
        runs.push(FfiLegendRun {
            start: 0,
            length: utf16_len(&title),
            color_hex: String::new(),
            bold: true,
        });
        text.push_str(&title);
        lines += 1;
    }
    for (i, label) in labels.iter().enumerate() {
        if !text.is_empty() {
            text.push('\n');
        }
        runs.push(FfiLegendRun {
            start: utf16_len(&text),
            length: utf16_len(SWATCH),
            color_hex: colors[i % colors.len()].clone(),
            bold: false,
        });
        text.push_str(SWATCH);
        text.push(' ');
        text.push_str(label);
        lines += 1;
    }
    let size = if font_size.is_finite() && font_size > 0.0 {
        font_size
    } else {
        16.0
    };
    FfiLegendBox {
        text,
        runs,
        height: lines.max(1) as f32 * size * 1.5 + 16.0,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn swatches_sit_at_the_start_of_each_line_in_utf16_units() {
        let b = legend_box(
            "圖例".into(),
            vec!["溫帶 🌲".into(), "寒帶".into()],
            vec!["#111111".into(), "#222222".into()],
            16.0,
        );
        assert_eq!(b.text, "圖例\n■ 溫帶 🌲\n■ 寒帶");
        let units: Vec<u16> = b.text.encode_utf16().collect();
        let sw = SWATCH.encode_utf16().next().unwrap();
        assert!(b.runs[0].bold && b.runs[0].start == 0 && b.runs[0].length == 2);
        for r in &b.runs[1..] {
            assert_eq!(units[r.start as usize], sw);
            assert_eq!(units[r.start as usize - 1], '\n' as u16);
        }
        assert_eq!(b.runs[2].color_hex, "#222222");
        // emoji 佔兩個碼元：第二個色塊的位置必須算進去。
        assert_eq!(b.runs[2].start, 3 + 2 + 5 + 1);
    }

    #[test]
    fn colors_cycle_and_empty_colors_fall_back_to_defaults() {
        let b = legend_box(
            String::new(),
            vec!["a".into(), "b".into(), "c".into()],
            vec![],
            0.0,
        );
        assert_eq!(b.runs.len(), 3);
        assert_eq!(b.runs[0].start, 0);
        assert_eq!(b.runs[0].color_hex, legend_default_colors()[0]);
        let c = legend_box(
            String::new(),
            vec!["a".into(), "b".into()],
            vec!["#000000".into()],
            16.0,
        );
        assert_eq!(c.runs[1].color_hex, "#000000");
        assert!(c.height > 0.0);
    }
}
