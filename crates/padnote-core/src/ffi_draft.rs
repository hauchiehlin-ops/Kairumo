//! 工程製圖（圖學）：圖層、工程線型與製圖筆組。
//!
//! 這些**定義在核心**，兩個平台只負責畫面：圖層有幾層、各叫什麼、每一種製圖筆的線型／
//! 筆寬／預設圖層／顏色 —— 寫在平台層的話，同一本圖學筆記在兩台裝置上會是兩套筆組。
//!
//! # 圖層
//!
//! - **1 底層**：原題三視圖或題目輪廓。
//! - **2 中層**：作圖輔助線、投射轉折線、求交點路徑（淺藍細線）。複習時可以一鍵隱藏。
//! - **3 頂層**：最終答案輪廓線（粗實線）與隱藏線（虛線）。
//! - **0** 不是圖層：一般筆畫（沒有圖層的舊筆記全部是 0），永遠顯示。

use padnote_ink::{InkPoint, LineType, Tool};

use crate::ffi::{StrokePoint, ToolKind};
use crate::ffi_brush::FfiDab;

/// 製圖圖層的定義。
#[derive(Clone, Debug, PartialEq, uniffi::Record)]
pub struct FfiDraftLayer {
    /// 寫進筆畫的圖層編號（1–3）。
    pub id: u8,
    /// 語系鍵，例如 `draft_layer_base`。
    pub name_key: String,
    /// 圖層的代表色（圖層面板上的色塊）。
    pub color_hex: String,
}

/// 一種工程線型。
#[derive(Clone, Debug, PartialEq, uniffi::Record)]
pub struct FfiDraftLineType {
    /// 寫進筆畫的線型編號。
    pub id: u8,
    pub name_key: String,
    /// 「畫、空、畫、空…」交替的長度（頁面單位）。實線是空的。
    pub pattern: Vec<f32>,
}

/// 一支製圖筆：選了它就同時決定線型、筆寬、圖層與顏色。
#[derive(Clone, Debug, PartialEq, uniffi::Record)]
pub struct FfiDraftPen {
    /// 穩定的識別字（存設定、無障礙識別碼都用它）。
    pub id: String,
    pub name_key: String,
    pub line_type: u8,
    pub width: f32,
    /// 這支筆預設畫在哪一層。使用者可以在圖層面板改，改了就覆蓋這個預設。
    pub layer: u8,
    pub color_hex: String,
}

#[uniffi::export]
pub fn draft_layers() -> Vec<FfiDraftLayer> {
    [
        (1u8, "draft_layer_base", "#374151"),
        (2, "draft_layer_aux", "#3B82F6"),
        (3, "draft_layer_top", "#111827"),
    ]
    .into_iter()
    .map(|(id, key, color)| FfiDraftLayer {
        id,
        name_key: key.into(),
        color_hex: color.into(),
    })
    .collect()
}

#[uniffi::export]
pub fn draft_line_types() -> Vec<FfiDraftLineType> {
    [
        (LineType::Solid, "draft_line_solid"),
        (LineType::Hidden, "draft_line_hidden"),
        (LineType::Center, "draft_line_center"),
        (LineType::Phantom, "draft_line_phantom"),
    ]
    .into_iter()
    .map(|(t, key)| FfiDraftLineType {
        id: t as u8,
        name_key: key.into(),
        pattern: t.pattern().to_vec(),
    })
    .collect()
}

/// 製圖筆組。筆寬依制圖規範：粗實線約為細線的 2 倍。
#[uniffi::export]
pub fn draft_pens() -> Vec<FfiDraftPen> {
    let pen = |id: &str, line: LineType, width: f32, layer: u8, color: &str| FfiDraftPen {
        id: id.into(),
        name_key: format!("draft_pen_{id}"),
        line_type: line as u8,
        width,
        layer,
        color_hex: color.into(),
    };
    vec![
        // 頂層：最終答案。
        pen("thick", LineType::Solid, 2.6, 3, "#111827"),
        pen("thin", LineType::Solid, 1.2, 3, "#111827"),
        pen("hidden", LineType::Hidden, 1.4, 3, "#111827"),
        pen("center", LineType::Center, 1.1, 3, "#111827"),
        pen("phantom", LineType::Phantom, 1.1, 3, "#111827"),
        // 中層：作圖輔助線與投射線（淺藍細線）。
        pen("aux", LineType::Solid, 1.0, 2, "#3B82F6"),
        // 底層：原題輪廓。
        pen("given", LineType::Solid, 1.8, 1, "#374151"),
    ]
}

/// 工程線型的穩定編號 → 圖樣。給只拿到編號的平台層用。
#[uniffi::export]
pub fn draft_line_pattern(line_type: u8) -> Vec<f32> {
    LineType::from_id(line_type).pattern().to_vec()
}

/// 把一筆**製圖筆畫**展開成筆點陣（已依線型挖掉間隔）。
///
/// 製圖筆畫一律走針筆（等寬、硬邊），所以 `tool` 通常是 `Fineliner`；
/// 參數留著是為了讓其他自繪筆刷也能帶線型。原生筆刷回傳空陣列，由平台自己畫。
#[uniffi::export]
pub fn brush_dabs_styled(
    tool: ToolKind,
    base_width: f32,
    points: Vec<StrokePoint>,
    line_type: u8,
) -> Vec<FfiDab> {
    let pts: Vec<InkPoint> = points
        .iter()
        .map(|p| InkPoint {
            x: p.x,
            y: p.y,
            pressure: p.pressure,
            tilt: p.tilt,
            azimuth: p.azimuth,
            dt_us: p.dt_us,
            roll: p.roll,
        })
        .collect();
    padnote_ink::dabs_styled(
        Tool::from(tool),
        &pts,
        base_width,
        LineType::from_id(line_type),
    )
    .into_iter()
    .map(Into::into)
    .collect()
}

// MARK: - 圖學套件（一次建出一組筆記本）

/// 套件裡的一本筆記本。
#[derive(Clone, Debug, PartialEq, uniffi::Record)]
pub struct FfiKitNotebook {
    /// 筆記本標題的語系鍵。
    pub title_key: String,
    /// 紙張樣板（`paper_templates()` 的 id）。
    pub paper_id: String,
    /// 頁面規格（`page_formats()` 的 id）。
    pub page_format_id: String,
    pub page_count: u32,
}

/// 一組一起建立的筆記本，例如「圖學」＝課堂筆記＋作圖練習＋錯誤陷阱本。
#[derive(Clone, Debug, PartialEq, uniffi::Record)]
pub struct FfiNotebookKit {
    pub id: String,
    pub title_key: String,
    pub desc_key: String,
    pub notebooks: Vec<FfiKitNotebook>,
}

/// 可建立的套件。兩個平台的「新增筆記本」畫面都讀這一份，
/// 所以同一個套件在兩台裝置上建出來的筆記本一模一樣。
#[uniffi::export]
pub fn notebook_kits() -> Vec<FfiNotebookKit> {
    let nb = |title: &str, paper: &str, format: &str, pages: u32| FfiKitNotebook {
        title_key: title.into(),
        paper_id: paper.into(),
        page_format_id: format.into(),
        page_count: pages,
    };
    vec![FfiNotebookKit {
        id: "drafting".into(),
        title_key: "kit_drafting".into(),
        desc_key: "kit_drafting_desc".into(),
        notebooks: vec![
            // 課堂筆記：康乃爾，左邊寫關鍵字、右邊記步驟。
            nb("kit_drafting_class", "cornell", "a4", 3),
            // 作圖練習：A3 橫式，左欄步驟 ①②③、右邊整片作圖。
            nb("kit_drafting_practice", "drafting_steps", "a3_landscape", 3),
            // 錯誤陷阱本：錯／對畫法並排，底下記口訣。
            nb("kit_drafting_trap", "drafting_trap", "a4", 2),
        ],
    }]
}

/// 這張紙是不是製圖用的：開啟時編輯器會自動選好「圖學」筆組。
#[uniffi::export]
pub fn paper_uses_drafting(paper_id: String) -> bool {
    matches!(
        paper_id.as_str(),
        "blueprint" | "isometric" | "orthographic" | "drafting_steps" | "drafting_trap"
    )
}

/// 吸附結果的種類。
#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum FfiDraftSnapKind {
    /// 沒有吸附：點原樣回傳。
    None,
    Line,
    Polyline,
    Ellipse,
    Rectangle,
    Triangle,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiDraftSnap {
    pub kind: FfiDraftSnapKind,
    /// 與輸入等長，平台層用同一個索引抄回壓感與時間戳。
    pub points: Vec<crate::ffi_shapes::FfiPoint>,
}

/// 長按吸附：把一筆手繪筆畫釘成直線／圓／矩形／三角形，或鎖角度的折線。
///
/// `angle_step_deg` 為 0 表示不鎖角度（直線仍會被扶正，折線不處理）。
#[uniffi::export]
pub fn draft_snap_stroke(
    points: Vec<crate::ffi_shapes::FfiPoint>,
    angle_step_deg: f32,
) -> FfiDraftSnap {
    use padnote_ink::SnapKind;
    let input: Vec<(f32, f32)> = points.iter().map(|p| (p.x, p.y)).collect();
    let out = padnote_ink::snap_stroke(&input, angle_step_deg);
    FfiDraftSnap {
        kind: match out.kind {
            SnapKind::None => FfiDraftSnapKind::None,
            SnapKind::Line => FfiDraftSnapKind::Line,
            SnapKind::Polyline => FfiDraftSnapKind::Polyline,
            SnapKind::Ellipse => FfiDraftSnapKind::Ellipse,
            SnapKind::Rectangle => FfiDraftSnapKind::Rectangle,
            SnapKind::Triangle => FfiDraftSnapKind::Triangle,
        },
        points: out
            .points
            .into_iter()
            .map(|(x, y)| crate::ffi_shapes::FfiPoint { x, y })
            .collect(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_drafting_kit_only_uses_papers_and_formats_that_exist() {
        let papers: Vec<String> = crate::ffi_paper::paper_templates()
            .into_iter()
            .map(|t| t.id)
            .collect();
        let formats: Vec<String> = crate::ffi_paper::page_formats()
            .into_iter()
            .map(|f| f.id)
            .collect();
        for kit in notebook_kits() {
            assert!(!kit.notebooks.is_empty());
            for nb in &kit.notebooks {
                assert!(
                    papers.contains(&nb.paper_id),
                    "{} 的紙張不存在",
                    nb.title_key
                );
                assert!(
                    formats.contains(&nb.page_format_id),
                    "{} 的規格不存在",
                    nb.title_key
                );
                assert!(nb.page_count >= 1);
            }
        }
    }

    #[test]
    fn drafting_papers_are_all_real_templates() {
        let papers: Vec<String> = crate::ffi_paper::paper_templates()
            .into_iter()
            .map(|t| t.id)
            .collect();
        for id in [
            "blueprint",
            "isometric",
            "orthographic",
            "drafting_steps",
            "drafting_trap",
        ] {
            assert!(papers.iter().any(|p| p == id), "{id}");
            assert!(paper_uses_drafting(id.into()));
        }
        assert!(!paper_uses_drafting("cornell".into()));
    }

    #[test]
    fn there_are_three_layers_in_the_order_the_course_uses() {
        let layers = draft_layers();
        assert_eq!(
            layers.iter().map(|l| l.id).collect::<Vec<_>>(),
            vec![1, 2, 3]
        );
        assert_eq!(layers[0].name_key, "draft_layer_base");
        assert_eq!(layers[2].name_key, "draft_layer_top");
    }

    #[test]
    fn every_pen_points_at_a_real_layer_and_line_type() {
        let layers: Vec<u8> = draft_layers().iter().map(|l| l.id).collect();
        let lines: Vec<u8> = draft_line_types().iter().map(|l| l.id).collect();
        for pen in draft_pens() {
            assert!(layers.contains(&pen.layer), "{} 的圖層不存在", pen.id);
            assert!(lines.contains(&pen.line_type), "{} 的線型不存在", pen.id);
            assert!(pen.width > 0.0);
        }
    }

    #[test]
    fn thick_is_about_twice_thin() {
        let pens = draft_pens();
        let width = |id: &str| pens.iter().find(|p| p.id == id).unwrap().width;
        assert!(
            (width("thick") / width("thin") - 2.0).abs() < 0.3,
            "粗實線約為細線的 2 倍"
        );
    }

    #[test]
    fn auxiliary_lines_live_on_the_middle_layer_in_light_blue() {
        let pens = draft_pens();
        let aux = pens.iter().find(|p| p.id == "aux").unwrap();
        assert_eq!(aux.layer, 2);
        assert_eq!(aux.color_hex, "#3B82F6");
    }

    #[test]
    fn a_dashed_pen_produces_fewer_dabs_than_a_solid_one() {
        let points: Vec<StrokePoint> = (0..=20)
            .map(|i| StrokePoint {
                x: i as f32 * 10.0,
                y: 0.0,
                pressure: 0.5,
                tilt: 0.0,
                azimuth: 0.0,
                dt_us: 8_000,
                roll: 0.0,
            })
            .collect();
        let solid = brush_dabs_styled(ToolKind::Fineliner, 1.4, points.clone(), 0);
        let hidden = brush_dabs_styled(ToolKind::Fineliner, 1.4, points, 1);
        assert!(hidden.len() < solid.len());
        assert!(!hidden.is_empty());
    }
}
