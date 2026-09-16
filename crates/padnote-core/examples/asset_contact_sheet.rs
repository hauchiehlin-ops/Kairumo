//! 把 58 件素材的線圖一次全部畫出來，輸出一張 SVG 對照表。
//!
//! # 為什麼要有這個東西
//!
//! 線圖是**資料**（一串路徑指令），所以測試擋得住座標爆掉、擋得住路徑
//! 沒有封閉 —— 但擋不住「畫出來不像齒輪」。那一項只有人眼判斷得了，
//! 而要人一件一件點開 App 去看 58 次，實際上等於不會有人去看。
//!
//! 所以把判斷成本壓到最低：一張圖、一次看完。
//!
//! ```text
//! cargo run -p padnote-core --example asset_contact_sheet -- /tmp/assets.svg
//! ```
//!
//! # 這張圖不能證明什麼
//!
//! 它畫的是**核心產生的路徑**，不是 Apple 或 Android 實際畫出來的畫面。
//! 兩邊的平台層如果把路徑畫錯（線寬、填色、座標縮放），這張圖看不出來。
//! 它要回答的只有一個問題：**這 58 個形狀本身對不對。**

use padnote_core::ffi_asset_art::{FfiAssetRenderStyle, FfiPathVerb, asset_drawing, asset_palette};
use padnote_core::ffi_assets::asset_items;

/// 每一格的邊長（素材畫在 400 × 400 裡，縮到這個大小）。
const CELL: f32 = 200.0;
/// 標題列的高度。兩行，所以要夠高。
const LABEL: f32 = 40.0;
/// 一列幾格。
const COLUMNS: usize = 6;
/// 一行標題最多幾個字。超過就截斷 —— 名稱比格子寬的話會壓到隔壁那一件，
/// 整張表就沒辦法看了。
const LABEL_CHARS: usize = 13;

fn main() {
    let out = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "assets.svg".into());
    let items = asset_items();
    let palette = asset_palette(FfiAssetRenderStyle::Blueprint, false);

    let rows = items.len().div_ceil(COLUMNS);
    let width = COLUMNS as f32 * CELL;
    let height = rows as f32 * (CELL + LABEL);

    let mut svg = format!(
        r##"<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
<rect width="{width}" height="{height}" fill="#ffffff"/>
"##
    );

    for (index, item) in items.iter().enumerate() {
        let col = index % COLUMNS;
        let row = index / COLUMNS;
        let x = col as f32 * CELL;
        let y = row as f32 * (CELL + LABEL);

        // 格線：少了它，相鄰兩件素材的線會看起來像同一張圖。
        svg += &format!(
            r##"<rect x="{x}" y="{y}" width="{CELL}" height="{}" fill="none" stroke="#dddddd"/>
"##,
            CELL + LABEL
        );

        // 素材畫在 400 × 400 裡，縮進格子。
        let scale = CELL / 400.0;
        svg += &format!(r##"<g transform="translate({x},{y}) scale({scale})">"##);
        for path in asset_drawing(item.drawing_code.clone()) {
            let color = if path.accent {
                &palette.accent_hex
            } else {
                &palette.stroke_hex
            };
            let fill = if path.fillable && !path.fill_override_hex.is_empty() {
                path.fill_override_hex.clone()
            } else {
                "none".into()
            };
            let dash = if path.dashed {
                r##" stroke-dasharray="8 6""##
            } else {
                ""
            };
            svg += &format!(
                r##"<path d="{}" fill="{fill}" stroke="{color}" stroke-width="{}"{dash}/>"##,
                to_svg_d(&path.segs),
                path.width
            );
        }
        svg += "</g>\n";

        // 名稱。畫在格子底下，不要壓在圖上。
        //
        // 中文名與英文名分兩行：素材名稱有長到 30 個字的，擠成一行會直接
        // 蓋到隔壁那一件，而中間那幾件會變成一團看不出邊界的字。
        for (line, text) in label_lines(&item.title).iter().enumerate() {
            svg += &format!(
                r##"<text x="{}" y="{}" font-family="sans-serif" font-size="10" text-anchor="middle" fill="#333333">{}</text>
"##,
                x + CELL / 2.0,
                y + CELL + 14.0 + line as f32 * 12.0,
                escape(text)
            );
        }
    }

    svg += "</svg>\n";
    std::fs::write(&out, svg).expect("寫不出檔案");
    println!("{} 件素材 → {out}", items.len());
}

/// 把「中文名 (English name)」拆成兩行，各自截斷。
fn label_lines(title: &str) -> Vec<String> {
    let (zh, en) = match title.split_once(" (") {
        Some((zh, en)) => (zh, en.trim_end_matches(')')),
        None => (title, ""),
    };
    let mut out = vec![clip(zh)];
    if !en.is_empty() {
        out.push(clip(en));
    }
    out
}

fn clip(text: &str) -> String {
    let chars: Vec<char> = text.chars().collect();
    if chars.len() <= LABEL_CHARS {
        return text.to_string();
    }
    chars[..LABEL_CHARS].iter().collect::<String>() + "…"
}

fn to_svg_d(segs: &[padnote_core::ffi_asset_art::FfiPathSeg]) -> String {
    let mut d = String::new();
    for seg in segs {
        match seg.verb {
            FfiPathVerb::Move => d += &format!("M {} {} ", seg.x, seg.y),
            FfiPathVerb::Line => d += &format!("L {} {} ", seg.x, seg.y),
            FfiPathVerb::Curve => {
                d += &format!(
                    "C {} {} {} {} {} {} ",
                    seg.c1x, seg.c1y, seg.c2x, seg.c2y, seg.x, seg.y
                )
            }
            FfiPathVerb::Close => d += "Z ",
        }
    }
    d.trim_end().to_string()
}

/// 名稱會直接進 XML，`&` 與 `<` 要跳脫，否則整張圖打不開。
fn escape(text: &str) -> String {
    text.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
}
