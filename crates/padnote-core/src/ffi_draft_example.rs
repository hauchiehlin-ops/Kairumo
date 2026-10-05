//! 範例筆記《圖學範例》的內容：三視圖輔助線求交點，一步一步畫。
//!
//! # 為什麼內容在核心
//!
//! 這本筆記要示範「圖層」：底層是原題、中層是輔助線與步驟編號、頂層是答案，最後一頁
//! 示範把中層隱藏。兩個平台各自生一份座標的話，同一個範例在兩台裝置上會長得不一樣，
//! 而且改一個尺寸要改兩次。所以核心一次算好每一頁的筆畫與文字，平台只負責寫進自己的儲存。
//!
//! 幾何用的是 `padnote-solid` 的真實投影（不是手填座標），所以範例的答案**一定**與
//! 立體輔助工具算出來的右視圖一致。

use padnote_solid::solid::{Solid, preset};
use padnote_solid::view::{Camera, StandardView, View, project};

use crate::ffi_draft::draft_pens;
use crate::ffi_shapes::FfiPoint;
use crate::ffi_solid::{FfiSheetStroke, draft_step_marker};

/// 範例頁上的一段文字。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiExampleText {
    /// 語系鍵。
    pub key: String,
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub font_size: f32,
    pub bold: bool,
    pub color_hex: String,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiExamplePage {
    pub strokes: Vec<FfiSheetStroke>,
    pub texts: Vec<FfiExampleText>,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiDraftingExample {
    /// 範例用的頁面規格與紙張。
    pub page_format_id: String,
    pub paper_id: String,
    /// 筆記本標題的語系鍵。
    pub title_key: String,
    pub pages: Vec<FfiExamplePage>,
}

// ---- 版面（頁面座標，y 向下；A3 橫式 1600 × 1132）----

const W: f32 = 400.0;
const H: f32 = 300.0;
const D: f32 = 200.0;
const GAP: f32 = 110.0;
const FRONT_X: f32 = 140.0;
const FRONT_BOTTOM: f32 = 940.0;

/// 視圖在頁面上的方框（左、下）。
#[derive(Clone, Copy)]
struct Box2 {
    x0: f32,
    bottom: f32,
}

fn front_box() -> Box2 {
    Box2 {
        x0: FRONT_X,
        bottom: FRONT_BOTTOM,
    }
}
fn top_box() -> Box2 {
    Box2 {
        x0: FRONT_X,
        bottom: FRONT_BOTTOM - H - GAP,
    }
}
fn right_box() -> Box2 {
    Box2 {
        x0: FRONT_X + W + GAP,
        bottom: FRONT_BOTTOM,
    }
}

fn stroke(pen_id: &str, points: Vec<(f32, f32)>) -> Option<FfiSheetStroke> {
    let pens = draft_pens();
    let pen = pens.iter().find(|p| p.id == pen_id)?;
    Some(FfiSheetStroke {
        points: points
            .into_iter()
            .map(|p| FfiPoint { x: p.0, y: p.1 })
            .collect(),
        layer: pen.layer,
        line_type: pen.line_type,
        width: pen.width,
        color_hex: pen.color_hex.clone(),
    })
}

/// 視圖的線 → 頁面筆畫。`visible_pen`／`hidden_pen` 決定畫在哪一層。
fn view_strokes(view: &View, b: Box2, visible_pen: &str, hidden_pen: &str) -> Vec<FfiSheetStroke> {
    let Some((lo, _)) = view.bounds() else {
        return Vec::new();
    };
    let map = |p: (f32, f32)| (b.x0 + (p.0 - lo.0), b.bottom - (p.1 - lo.1));
    view.lines
        .iter()
        .filter_map(|l| {
            stroke(
                if l.hidden { hidden_pen } else { visible_pen },
                vec![map(l.a), map(l.b)],
            )
        })
        .collect()
}

fn text(
    key: &str,
    x: f32,
    y: f32,
    width: f32,
    size: f32,
    bold: bool,
    color: &str,
) -> FfiExampleText {
    FfiExampleText {
        key: key.into(),
        x,
        y,
        width,
        font_size: size,
        bold,
        color_hex: color.into(),
    }
}

fn title_texts(subtitle_key: &str) -> Vec<FfiExampleText> {
    vec![
        text(
            "drafting_example_title",
            FRONT_X,
            60.0,
            1100.0,
            30.0,
            true,
            "#111827",
        ),
        text(subtitle_key, FRONT_X, 112.0, 1100.0, 17.0, false, "#374151"),
    ]
}

/// 輔助線與步驟編號。`upto` 是做到第幾步（1…4）。
fn aux_strokes(upto: u32) -> Vec<FfiSheetStroke> {
    let (t, r) = (top_box(), right_box());
    let (x_front_right, y_top_front, y_top_back) = (FRONT_X + W, t.bottom, t.bottom - D);
    let (x_r0, x_r1) = (r.x0, r.x0 + D);
    let mut out = Vec::new();
    let marker = |n: u32, cx: f32, cy: f32| draft_step_marker(n, cx, cy, 15.0);

    // ① 45° 轉向線：從 (右視圖左緣, 俯視圖前緣) 到 (右視圖右緣, 俯視圖後緣)。
    if upto >= 1 {
        out.extend(stroke("aux", vec![(x_r0, y_top_front), (x_r1, y_top_back)]));
        out.extend(marker(
            1,
            (x_r0 + x_r1) / 2.0 + 34.0,
            (y_top_front + y_top_back) / 2.0 + 34.0,
        ));
    }
    // ② 俯視圖前後緣向右的水平投射線，碰到 45° 線為止。
    if upto >= 2 {
        out.extend(stroke(
            "aux",
            vec![(x_front_right, y_top_front), (x_r0, y_top_front)],
        ));
        out.extend(stroke(
            "aux",
            vec![(x_front_right, y_top_back), (x_r1, y_top_back)],
        ));
        out.extend(marker(2, x_front_right + 50.0, y_top_back - 28.0));
    }
    // ③ 從 45° 線上的交點向下的垂直線，決定右視圖的深度。
    if upto >= 3 {
        out.extend(stroke(
            "aux",
            vec![(x_r0, y_top_front), (x_r0, FRONT_BOTTOM)],
        ));
        out.extend(stroke(
            "aux",
            vec![(x_r1, y_top_back), (x_r1, FRONT_BOTTOM)],
        ));
        out.extend(marker(3, x_r1 + 34.0, y_top_back + 60.0));
    }
    // ④ 正視圖各高度向右的水平線，決定右視圖的高度。
    if upto >= 4 {
        let floor = FRONT_BOTTOM - H * 0.35;
        for y in [FRONT_BOTTOM - H, floor, FRONT_BOTTOM] {
            out.extend(stroke("aux", vec![(x_front_right, y), (x_r1, y)]));
        }
        out.extend(marker(4, x_front_right + 55.0, FRONT_BOTTOM - H - 26.0));
    }
    out
}

fn solid() -> Solid {
    Solid::new(preset("u_shape", W, H).expect("內建輪廓"), D)
}

fn given_strokes() -> Vec<FfiSheetStroke> {
    let s = solid();
    let mut out = view_strokes(
        &project(&s, &Camera::standard(StandardView::Front)),
        front_box(),
        "given",
        "given",
    );
    out.extend(view_strokes(
        &project(&s, &Camera::standard(StandardView::Top)),
        top_box(),
        "given",
        "given",
    ));
    out
}

fn answer_strokes(b: Box2) -> Vec<FfiSheetStroke> {
    view_strokes(
        &project(&solid(), &Camera::standard(StandardView::Right)),
        b,
        "thick",
        "hidden",
    )
}

/// 陷阱頁：左邊把被擋住的邊畫成實線（錯），右邊畫成虛線（對）。
fn trap_page() -> FfiExamplePage {
    let s = solid();
    let right_view = project(&s, &Camera::standard(StandardView::Right));
    let wrong_box = Box2 {
        x0: 220.0,
        bottom: 800.0,
    };
    let right_box = Box2 {
        x0: 820.0,
        bottom: 800.0,
    };
    let mut strokes = answer_strokes(right_box);
    // 錯誤版本：同一組線，但隱藏線一律畫成粗實線。
    strokes.extend(view_strokes(&right_view, wrong_box, "thick", "thick"));
    let mut texts = title_texts("drafting_example_trap_sub");
    texts.push(text(
        "drafting_example_wrong",
        220.0,
        850.0,
        480.0,
        18.0,
        true,
        "#B91C1C",
    ));
    texts.push(text(
        "drafting_example_right",
        820.0,
        850.0,
        480.0,
        18.0,
        true,
        "#047857",
    ));
    texts.push(text(
        "drafting_example_trap_rule",
        220.0,
        940.0,
        1100.0,
        17.0,
        false,
        "#374151",
    ));
    FfiExamplePage { strokes, texts }
}

/// 《圖學範例》的完整內容。
#[uniffi::export]
pub fn drafting_example() -> FfiDraftingExample {
    let mut pages = Vec::new();

    // 1 題目：原題在底層，右視圖留白。
    let mut texts = title_texts("drafting_example_p1_sub");
    texts.push(text(
        "drafting_example_p1_hint",
        980.0,
        330.0,
        540.0,
        16.0,
        false,
        "#374151",
    ));
    pages.push(FfiExamplePage {
        strokes: given_strokes(),
        texts,
    });

    // 2、3 輔助線一步一步加（中層）。
    for (upto, sub, key) in [
        (2u32, "drafting_example_p2_sub", "drafting_example_s12"),
        (4, "drafting_example_p3_sub", "drafting_example_s34"),
    ] {
        let mut strokes = given_strokes();
        strokes.extend(aux_strokes(upto));
        let mut texts = title_texts(sub);
        texts.push(text(key, 980.0, 330.0, 540.0, 17.0, false, "#1E3A8A"));
        pages.push(FfiExamplePage { strokes, texts });
    }

    // 4 答案（頂層）：粗實線與虛線，輔助線還在。
    let mut strokes = given_strokes();
    strokes.extend(aux_strokes(4));
    strokes.extend(answer_strokes(right_box()));
    strokes.extend(draft_step_marker(
        5,
        right_box().x0 + D + 40.0,
        FRONT_BOTTOM - H - 24.0,
        15.0,
    ));
    let mut texts = title_texts("drafting_example_p4_sub");
    texts.push(text(
        "drafting_example_s5",
        980.0,
        330.0,
        540.0,
        17.0,
        false,
        "#1E3A8A",
    ));
    pages.push(FfiExamplePage { strokes, texts });

    // 5 收尾：同樣的圖，教人把中層隱藏。
    let mut strokes = given_strokes();
    strokes.extend(aux_strokes(4));
    strokes.extend(answer_strokes(right_box()));
    let mut texts = title_texts("drafting_example_p5_sub");
    texts.push(text(
        "drafting_example_p5_body",
        980.0,
        330.0,
        540.0,
        17.0,
        false,
        "#374151",
    ));
    pages.push(FfiExamplePage { strokes, texts });

    // 6 錯誤陷阱。
    pages.push(trap_page());

    FfiDraftingExample {
        page_format_id: "a3_landscape".into(),
        paper_id: "blueprint".into(),
        title_key: "drafting_example_notebook".into(),
        pages,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn layers(page: &FfiExamplePage) -> Vec<u8> {
        let mut v: Vec<u8> = page.strokes.iter().map(|s| s.layer).collect();
        v.sort_unstable();
        v.dedup();
        v
    }

    #[test]
    fn the_example_has_six_pages_on_a3_landscape() {
        let ex = drafting_example();
        assert_eq!(ex.pages.len(), 6);
        assert_eq!(ex.page_format_id, "a3_landscape");
        assert!(
            crate::ffi_paper::page_formats()
                .iter()
                .any(|f| f.id == ex.page_format_id)
        );
        assert!(
            crate::ffi_paper::paper_templates()
                .iter()
                .any(|p| p.id == ex.paper_id)
        );
    }

    #[test]
    fn the_layers_build_up_page_by_page() {
        let ex = drafting_example();
        assert_eq!(layers(&ex.pages[0]), vec![1], "題目頁只有底層");
        assert_eq!(layers(&ex.pages[1]), vec![1, 2], "加了輔助線");
        assert_eq!(layers(&ex.pages[2]), vec![1, 2]);
        assert_eq!(layers(&ex.pages[3]), vec![1, 2, 3], "答案在頂層");
        assert_eq!(layers(&ex.pages[4]), vec![1, 2, 3]);
    }

    #[test]
    fn the_answer_has_a_dashed_hidden_line_and_the_aux_layer_can_be_hidden_cleanly() {
        let ex = drafting_example();
        let answer = &ex.pages[3];
        let hidden = answer
            .strokes
            .iter()
            .filter(|s| s.layer == 3 && s.line_type == 1)
            .count();
        assert_eq!(hidden, 1, "U 形槽的底邊從右邊看是被擋住的：一條虛線");
        // 隱藏中層之後剩下的線（底層＋頂層）不含任何輔助線或步驟編號。
        assert!(
            answer
                .strokes
                .iter()
                .filter(|s| s.layer != 2)
                .all(|s| s.layer == 1 || s.layer == 3)
        );
    }

    #[test]
    fn every_stroke_and_text_stays_on_the_page_and_off_the_title_block() {
        let ex = drafting_example();
        for (i, page) in ex.pages.iter().enumerate() {
            for s in &page.strokes {
                for p in &s.points {
                    assert!(
                        p.x > 20.0 && p.x < 1580.0 && p.y > 20.0 && p.y < 1112.0,
                        "第 {i} 頁 {p:?}"
                    );
                    // 藍圖紙右下角的標題欄（x > 0.62w、y > 0.9h）。
                    assert!(
                        !(p.x > 0.62 * 1600.0 && p.y > 0.9 * 1132.0),
                        "第 {i} 頁的線蓋到標題欄 {p:?}"
                    );
                }
            }
            for t in &page.texts {
                assert!(
                    t.x >= 0.0 && t.x + t.width <= 1600.0 && t.y < 1100.0,
                    "第 {i} 頁文字 {}",
                    t.key
                );
            }
        }
    }

    #[test]
    fn the_trap_page_draws_the_same_view_twice_with_different_hidden_lines() {
        let ex = drafting_example();
        let trap = &ex.pages[5];
        let dashed = trap.strokes.iter().filter(|s| s.line_type == 1).count();
        assert_eq!(dashed, 1, "只有「對」的那一邊有虛線");
    }

    #[test]
    fn every_text_key_is_in_the_ui_strings() {
        let ui = include_str!("../../../i18n/ui-strings.json");
        let ex = drafting_example();
        let keys = ex
            .pages
            .iter()
            .flat_map(|p| p.texts.iter().map(|t| t.key.clone()))
            .chain(std::iter::once(ex.title_key.clone()));
        for k in keys {
            assert!(ui.contains(&format!("\"{k}\"")), "缺語系鍵 {k}");
        }
    }
}
