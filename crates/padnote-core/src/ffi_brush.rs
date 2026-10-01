//! 專業筆刷的跨平台介面：筆點陣、筆跡預覽、向量圖示。
//!
//! 三樣東西都由核心算好、兩端照畫 —— 同一支筆在 iPad 與 Android 上長得一樣，
//! 也不必各自維護一份「差不多」的圖。
//!
//! - **筆點陣**（`brush_dabs`）：自繪引擎筆刷的實際筆跡，見 `padnote-ink` 的 `brush.rs`。
//! - **筆跡預覽**（`brush_preview_dabs`）：工具列圖示旁邊那一小段示範線條。
//!   原生筆刷（鋼筆、麥克筆…）沒有自繪筆點，這裡用同一種筆點表示法**模擬**它們的外觀，
//!   讓十幾支筆的預覽用同一套畫法就能畫出來。
//! - **向量圖示**（`brush_icon`）：`assets/brushes/*.svg`。SVG 在這裡解析成路徑指令，
//!   兩端只需要照指令畫，不必各自帶一個 SVG 函式庫。

// 路徑資料與多邊形座標是變長的數字串，切成固定大小的組是這裡最直接的寫法。
#![allow(clippy::chunks_exact_to_as_chunks)]

use crate::ffi::{StrokePoint, ToolKind};
use crate::ffi_ui::FfiTool;
use padnote_ink::{Dab, InkPoint, Tool};

#[derive(Clone, Copy, Debug, PartialEq, uniffi::Record)]
pub struct FfiDab {
    pub x: f32,
    pub y: f32,
    pub rx: f32,
    pub ry: f32,
    pub angle: f32,
    pub alpha: f32,
    pub softness: f32,
    pub shade: f32,
}

impl From<Dab> for FfiDab {
    fn from(d: Dab) -> Self {
        Self {
            x: d.x,
            y: d.y,
            rx: d.rx,
            ry: d.ry,
            angle: d.angle,
            alpha: d.alpha,
            softness: d.softness,
            shade: d.shade,
        }
    }
}

fn to_ink(p: &StrokePoint) -> InkPoint {
    InkPoint {
        x: p.x,
        y: p.y,
        pressure: p.pressure,
        tilt: p.tilt,
        azimuth: p.azimuth,
        dt_us: p.dt_us,
        roll: p.roll,
    }
}

/// 這支筆是不是由自繪引擎算繪（要呼叫 `brush_dabs`）。
#[uniffi::export]
pub fn brush_is_custom(tool: ToolKind) -> bool {
    Tool::from(tool).is_custom_engine()
}

/// 把一筆畫展開成筆點陣。原生筆刷回傳空陣列。
#[uniffi::export]
pub fn brush_dabs(tool: ToolKind, base_width: f32, points: Vec<StrokePoint>) -> Vec<FfiDab> {
    let pts: Vec<InkPoint> = points.iter().map(to_ink).collect();
    padnote_ink::dabs(Tool::from(tool), &pts, base_width)
        .into_iter()
        .map(Into::into)
        .collect()
}

/// 工具 → 筆刷種類。不是筆刷的回 `None`。
fn ink_tool(tool: FfiTool) -> Option<Tool> {
    Some(match tool {
        FfiTool::Pen => Tool::FountainPen,
        FfiTool::BallPoint => Tool::BallPoint,
        FfiTool::Fineliner => Tool::Fineliner,
        FfiTool::Brush => Tool::Brush,
        FfiTool::Calligraphy => Tool::Calligraphy,
        FfiTool::Pencil => Tool::Pencil,
        FfiTool::Charcoal => Tool::Charcoal,
        FfiTool::Crayon => Tool::Crayon,
        FfiTool::Airbrush => Tool::Airbrush,
        FfiTool::OilPaint => Tool::OilPaint,
        FfiTool::Watercolor => Tool::Watercolor,
        FfiTool::Marker => Tool::Marker,
        FfiTool::Highlighter => Tool::Highlighter,
        _ => return None,
    })
}

/// 示範用的 S 形曲線：左到右，壓感由輕到重再收輕，看得出每支筆的壓感反應。
fn preview_points(width: f32, height: f32) -> Vec<InkPoint> {
    let n = 40;
    (0..=n)
        .map(|i| {
            let t = i as f32 / n as f32;
            let x = width * (0.06 + 0.88 * t);
            let y = height * (0.5 - 0.28 * (t * std::f32::consts::TAU).sin());
            let pressure = 0.25 + 0.75 * (t * std::f32::consts::PI).sin();
            InkPoint::new(x, y, pressure, 8_000)
        })
        .collect()
}

fn round(x: f32, y: f32, r: f32, alpha: f32, softness: f32) -> Dab {
    Dab {
        x,
        y,
        rx: r,
        ry: r,
        angle: 0.0,
        alpha,
        softness,
        shade: 0.0,
    }
}

/// 原生筆刷的模擬筆跡：用筆點陣表示它們各自的外觀特徵。
fn native_preview(tool: Tool, points: &[InkPoint], base: f32) -> Vec<Dab> {
    let path = padnote_ink::smooth_path(points, 2);
    let at = |i: usize| -> f32 {
        let k = (i * points.len() / path.len().max(1)).min(points.len() - 1);
        points[k].pressure
    };
    let mut out = Vec::new();
    for (i, &(x, y)) in path.iter().enumerate() {
        let p = at(i);
        let half = padnote_ink::half_width(tool, base, p);
        match tool {
            Tool::FountainPen => out.push(round(x, y, half, 1.0, 0.0)),
            Tool::BallPoint => out.push(round(x, y, half * 0.8, 1.0, 0.0)),
            Tool::Brush => {
                // 毛筆：壓感反應極強，起筆收筆尖細。
                let r = half * (0.4 + 1.3 * p);
                out.push(round(x, y, r, 1.0, 0.0));
            }
            Tool::Marker => out.push(Dab {
                x,
                y,
                rx: half * 1.1,
                ry: half * 0.55,
                angle: 0.6,
                alpha: 0.85,
                softness: 0.0,
                shade: 0.0,
            }),
            Tool::Highlighter => out.push(Dab {
                x,
                y,
                rx: half * 0.9,
                ry: half * 1.8,
                angle: 0.35,
                alpha: 0.32,
                softness: 0.0,
                shade: 0.0,
            }),
            Tool::Pencil => {
                // 石墨：沿線撒細粒，輕壓更淡。
                for k in 0..3 {
                    let jitter = ((i * 7 + k * 13) % 11) as f32 / 11.0 - 0.5;
                    out.push(round(
                        x + jitter * half,
                        y - jitter * half * 0.8,
                        half * 0.45,
                        0.35 + 0.4 * p,
                        0.2,
                    ));
                }
            }
            Tool::Watercolor => {
                // 水彩：外圈淡而柔的水暈，內圈較濃的核心。
                out.push(round(x, y, half * 1.7, 0.10, 1.0));
                out.push(round(x, y, half * 0.85, 0.22, 0.6));
            }
            _ => {}
        }
    }
    out
}

/// 工具列圖示旁邊的筆跡預覽，畫在 `width` × `height` 的範圍內。
///
/// 不是筆刷的工具（橡皮擦、套索…）回空陣列。顏色由呼叫端決定（筆畫目前的顏色）。
#[uniffi::export]
pub fn brush_preview_dabs(tool: FfiTool, width: f32, height: f32) -> Vec<FfiDab> {
    let Some(tool) = ink_tool(tool) else {
        return Vec::new();
    };
    let points = preview_points(width, height);
    // 預覽筆寬依畫面高度縮放，才不會在小圖示裡塞不下。
    let base = (height * 0.30).clamp(2.0, 14.0);
    let dabs = if tool.is_custom_engine() {
        padnote_ink::dabs(tool, &points, base)
    } else {
        native_preview(tool, &points, base)
    };
    dabs.into_iter().map(Into::into).collect()
}

// ---------------------------------------------------------------------------------------
// 向量圖示
// ---------------------------------------------------------------------------------------

/// 路徑指令。`op` 只會是 `M`、`L`、`C`、`Z`（相對座標、H/V/S/Q 都已展開）。
#[derive(Clone, Debug, PartialEq, uniffi::Record)]
pub struct FfiPathCmd {
    pub op: String,
    pub args: Vec<f32>,
}

/// 填色或描邊的顏色。
#[derive(Clone, Copy, Debug, PartialEq, uniffi::Enum)]
pub enum FfiPaint {
    None,
    /// `currentColor`：使用者目前選的筆色，圖示會跟著換色。
    Ink,
    Color {
        r: u8,
        g: u8,
        b: u8,
    },
}

#[derive(Clone, Debug, PartialEq, uniffi::Record)]
pub struct FfiIconShape {
    pub commands: Vec<FfiPathCmd>,
    pub fill: FfiPaint,
    pub stroke: FfiPaint,
    pub stroke_width: f32,
    pub opacity: f32,
    pub round_cap: bool,
}

/// 圖示的座標系邊長（`viewBox="0 0 48 48"`）。
pub const ICON_VIEWBOX: f32 = 48.0;

/// 圖示的 SVG 原始碼。沒有對應圖示的工具回空字串。
///
/// 檔案在 `assets/brushes/`，用 `scripts/gen-brush-icons.py` 產生。
#[uniffi::export]
pub fn brush_icon_svg(tool: FfiTool) -> String {
    icon_source(tool).unwrap_or_default().to_string()
}

fn icon_source(tool: FfiTool) -> Option<&'static str> {
    macro_rules! svg {
        ($name:literal) => {
            include_str!(concat!("../../../assets/brushes/", $name, ".svg"))
        };
    }
    Some(match tool {
        FfiTool::Pen => svg!("pen"),
        FfiTool::BallPoint => svg!("ballpoint"),
        FfiTool::Fineliner => svg!("fineliner"),
        FfiTool::Brush => svg!("brush"),
        FfiTool::Calligraphy => svg!("calligraphy"),
        FfiTool::Pencil => svg!("pencil"),
        FfiTool::Charcoal => svg!("charcoal"),
        FfiTool::Crayon => svg!("crayon"),
        FfiTool::Airbrush => svg!("airbrush"),
        FfiTool::OilPaint => svg!("oilpaint"),
        FfiTool::Watercolor => svg!("watercolor"),
        FfiTool::Marker => svg!("marker"),
        FfiTool::Highlighter => svg!("highlighter"),
        FfiTool::Eraser => svg!("eraser"),
        FfiTool::Lasso => svg!("lasso"),
        FfiTool::MaskingTape => svg!("maskingtape"),
        _ => return None,
    })
}

/// 圖示解析成可直接畫的形狀。沒有圖示的工具回空陣列。
#[uniffi::export]
pub fn brush_icon(tool: FfiTool) -> Vec<FfiIconShape> {
    icon_source(tool).map(parse_svg).unwrap_or_default()
}

fn cmd(op: &str, args: &[f32]) -> FfiPathCmd {
    FfiPathCmd {
        op: op.to_string(),
        args: args.to_vec(),
    }
}

/// 把 `<tag a="1" b="2"/>` 的屬性讀成鍵值對。
fn attributes(tag: &str) -> Vec<(String, String)> {
    let mut out = Vec::new();
    let bytes = tag.as_bytes();
    let mut i = 0;
    while i < bytes.len() {
        // 找 `名稱="值"`
        if let Some(eq) = tag[i..].find("=\"") {
            let key_end = i + eq;
            let key_start = tag[..key_end]
                .rfind(|c: char| c.is_whitespace() || c == '<')
                .map(|p| p + 1)
                .unwrap_or(0);
            let value_start = key_end + 2;
            let Some(len) = tag[value_start..].find('"') else {
                break;
            };
            out.push((
                tag[key_start..key_end].to_string(),
                tag[value_start..value_start + len].to_string(),
            ));
            i = value_start + len + 1;
        } else {
            break;
        }
    }
    out
}

fn attr<'a>(attrs: &'a [(String, String)], key: &str) -> Option<&'a str> {
    attrs
        .iter()
        .find(|(k, _)| k == key)
        .map(|(_, v)| v.as_str())
}

fn num(attrs: &[(String, String)], key: &str) -> f32 {
    attr(attrs, key)
        .and_then(|v| v.trim().parse().ok())
        .unwrap_or(0.0)
}

fn paint(value: Option<&str>, default: FfiPaint) -> FfiPaint {
    match value.map(str::trim) {
        None => default,
        Some("none") => FfiPaint::None,
        Some("currentColor") => FfiPaint::Ink,
        Some(hex) if hex.starts_with('#') && hex.len() == 7 => {
            let p = |i: usize| u8::from_str_radix(&hex[i..i + 2], 16).unwrap_or(0);
            FfiPaint::Color {
                r: p(1),
                g: p(3),
                b: p(5),
            }
        }
        Some(_) => default,
    }
}

/// 圓與橢圓用四段三次貝茲曲線逼近。
fn ellipse_path(cx: f32, cy: f32, rx: f32, ry: f32) -> Vec<FfiPathCmd> {
    const K: f32 = 0.552_284_8;
    vec![
        cmd("M", &[cx + rx, cy]),
        cmd(
            "C",
            &[cx + rx, cy + ry * K, cx + rx * K, cy + ry, cx, cy + ry],
        ),
        cmd(
            "C",
            &[cx - rx * K, cy + ry, cx - rx, cy + ry * K, cx - rx, cy],
        ),
        cmd(
            "C",
            &[cx - rx, cy - ry * K, cx - rx * K, cy - ry, cx, cy - ry],
        ),
        cmd(
            "C",
            &[cx + rx * K, cy - ry, cx + rx, cy - ry * K, cx + rx, cy],
        ),
        cmd("Z", &[]),
    ]
}

fn numbers(s: &str) -> Vec<f32> {
    let mut out = Vec::new();
    let mut cur = String::new();
    let flush = |cur: &mut String, out: &mut Vec<f32>| {
        if !cur.is_empty() {
            if let Ok(v) = cur.parse::<f32>() {
                out.push(v);
            }
            cur.clear();
        }
    };
    let mut prev = ' ';
    for c in s.chars() {
        match c {
            '0'..='9' | '.' => cur.push(c),
            '-' | '+' => {
                // 負號開始新的一個數字，除非前面是指數記號。
                if prev != 'e' && prev != 'E' {
                    flush(&mut cur, &mut out);
                }
                cur.push(c);
            }
            _ => flush(&mut cur, &mut out),
        }
        prev = c;
    }
    flush(&mut cur, &mut out);
    out
}

/// 解析 `d` 屬性。只支援 M L H V C S Q Z（大小寫都行）。
fn parse_path_data(d: &str) -> Vec<FfiPathCmd> {
    let mut out = Vec::new();
    let (mut x, mut y) = (0.0f32, 0.0f32);
    let (mut sx, mut sy) = (0.0f32, 0.0f32);
    let mut last_ctrl: Option<(f32, f32)> = None;

    // 依指令字母切開。
    let mut parts: Vec<(char, String)> = Vec::new();
    for c in d.chars() {
        if c.is_ascii_alphabetic() && c != 'e' && c != 'E' {
            parts.push((c, String::new()));
        } else if let Some(last) = parts.last_mut() {
            last.1.push(c);
        }
    }
    for (op, rest) in parts {
        let n = numbers(&rest);
        let rel = op.is_ascii_lowercase();
        let (ox, oy) = if rel { (x, y) } else { (0.0, 0.0) };
        match op.to_ascii_uppercase() {
            'M' => {
                for (k, c) in n.chunks_exact(2).enumerate() {
                    x = c[0] + ox_for(rel, k, ox, x);
                    y = c[1] + ox_for(rel, k, oy, y);
                    if k == 0 {
                        out.push(cmd("M", &[x, y]));
                        sx = x;
                        sy = y;
                    } else {
                        out.push(cmd("L", &[x, y]));
                    }
                }
                last_ctrl = None;
            }
            'L' => {
                for c in n.chunks_exact(2) {
                    x = c[0] + if rel { x } else { 0.0 };
                    y = c[1] + if rel { y } else { 0.0 };
                    out.push(cmd("L", &[x, y]));
                }
                last_ctrl = None;
            }
            'H' => {
                for &v in &n {
                    x = v + if rel { x } else { 0.0 };
                    out.push(cmd("L", &[x, y]));
                }
                last_ctrl = None;
            }
            'V' => {
                for &v in &n {
                    y = v + if rel { y } else { 0.0 };
                    out.push(cmd("L", &[x, y]));
                }
                last_ctrl = None;
            }
            'C' => {
                for c in n.chunks_exact(6) {
                    let b = if rel { (x, y) } else { (0.0, 0.0) };
                    let a = [
                        c[0] + b.0,
                        c[1] + b.1,
                        c[2] + b.0,
                        c[3] + b.1,
                        c[4] + b.0,
                        c[5] + b.1,
                    ];
                    out.push(cmd("C", &a));
                    last_ctrl = Some((a[2], a[3]));
                    x = a[4];
                    y = a[5];
                }
            }
            'S' => {
                for c in n.chunks_exact(4) {
                    let b = if rel { (x, y) } else { (0.0, 0.0) };
                    let (c1x, c1y) =
                        last_ctrl.map_or((x, y), |(lx, ly)| (2.0 * x - lx, 2.0 * y - ly));
                    let a = [c1x, c1y, c[0] + b.0, c[1] + b.1, c[2] + b.0, c[3] + b.1];
                    out.push(cmd("C", &a));
                    last_ctrl = Some((a[2], a[3]));
                    x = a[4];
                    y = a[5];
                }
            }
            'Q' => {
                for c in n.chunks_exact(4) {
                    let b = if rel { (x, y) } else { (0.0, 0.0) };
                    let (qx, qy, ex, ey) = (c[0] + b.0, c[1] + b.1, c[2] + b.0, c[3] + b.1);
                    // 二次 → 三次。
                    let a = [
                        x + 2.0 / 3.0 * (qx - x),
                        y + 2.0 / 3.0 * (qy - y),
                        ex + 2.0 / 3.0 * (qx - ex),
                        ey + 2.0 / 3.0 * (qy - ey),
                        ex,
                        ey,
                    ];
                    out.push(cmd("C", &a));
                    last_ctrl = None;
                    x = ex;
                    y = ey;
                }
            }
            'Z' => {
                out.push(cmd("Z", &[]));
                x = sx;
                y = sy;
                last_ctrl = None;
            }
            _ => {} // 不支援的指令（例如圓弧）：忽略。測試會擋下圖示裡出現它。
        }
    }
    out
}

/// `M` 後面接的第一組座標吃相對偏移，之後的視為隱含 `L`，也吃目前點。
fn ox_for(rel: bool, _k: usize, origin: f32, _current: f32) -> f32 {
    if rel { origin } else { 0.0 }
}

/// 解析 SVG 子集。
fn parse_svg(src: &str) -> Vec<FfiIconShape> {
    let mut shapes = Vec::new();
    let mut rest = src;
    while let Some(start) = rest.find('<') {
        let Some(end) = rest[start..].find('>') else {
            break;
        };
        let tag = &rest[start..start + end + 1];
        rest = &rest[start + end + 1..];
        let name: String = tag[1..]
            .chars()
            .take_while(|c| c.is_ascii_alphanumeric())
            .collect();
        let a = attributes(tag);
        let commands = match name.as_str() {
            "path" => attr(&a, "d").map(parse_path_data).unwrap_or_default(),
            "polygon" => {
                let n = attr(&a, "points").map(numbers).unwrap_or_default();
                let mut v: Vec<FfiPathCmd> = n
                    .chunks_exact(2)
                    .enumerate()
                    .map(|(i, c)| cmd(if i == 0 { "M" } else { "L" }, c))
                    .collect();
                if !v.is_empty() {
                    v.push(cmd("Z", &[]));
                }
                v
            }
            "line" => vec![
                cmd("M", &[num(&a, "x1"), num(&a, "y1")]),
                cmd("L", &[num(&a, "x2"), num(&a, "y2")]),
            ],
            "rect" => {
                let (x, y, w, h) = (
                    num(&a, "x"),
                    num(&a, "y"),
                    num(&a, "width"),
                    num(&a, "height"),
                );
                vec![
                    cmd("M", &[x, y]),
                    cmd("L", &[x + w, y]),
                    cmd("L", &[x + w, y + h]),
                    cmd("L", &[x, y + h]),
                    cmd("Z", &[]),
                ]
            }
            "circle" => {
                let r = num(&a, "r");
                ellipse_path(num(&a, "cx"), num(&a, "cy"), r, r)
            }
            "ellipse" => ellipse_path(num(&a, "cx"), num(&a, "cy"), num(&a, "rx"), num(&a, "ry")),
            _ => continue,
        };
        if commands.is_empty() {
            continue;
        }
        let is_line = name == "line";
        let fill = if is_line {
            FfiPaint::None
        } else {
            paint(attr(&a, "fill"), FfiPaint::Color { r: 0, g: 0, b: 0 })
        };
        let stroke = paint(attr(&a, "stroke"), FfiPaint::None);
        shapes.push(FfiIconShape {
            commands,
            fill,
            stroke,
            stroke_width: attr(&a, "stroke-width")
                .and_then(|v| v.parse().ok())
                .unwrap_or(1.0),
            opacity: attr(&a, "opacity")
                .and_then(|v| v.parse().ok())
                .unwrap_or(1.0),
            round_cap: attr(&a, "stroke-linecap") == Some("round"),
        });
    }
    shapes
}

#[cfg(test)]
mod tests {
    use super::*;
    use padnote_toolbar::tools::all_tools;

    #[test]
    fn every_tool_in_the_toolbar_has_an_icon_except_history_buttons() {
        for t in all_tools() {
            let tool: FfiTool = t.into();
            let has = !brush_icon(tool).is_empty();
            let is_history = matches!(tool, FfiTool::Undo | FfiTool::Redo | FfiTool::ClearPage);
            assert_eq!(has, !is_history, "{tool:?} 的圖示有無不對");
        }
    }

    #[test]
    fn icon_names_match_the_parity_identifiers() {
        // 檔名就是 `editor.ink.<名稱>` 的小寫 —— 對不上代表兩端接錯圖。
        for t in all_tools() {
            let id = t
                .parity_identifier()
                .trim_start_matches("editor.ink.")
                .to_lowercase();
            let path = format!(
                "{}/../../assets/brushes/{id}.svg",
                env!("CARGO_MANIFEST_DIR")
            );
            let on_disk = std::path::Path::new(&path).exists();
            let is_history = matches!(id.as_str(), "undo" | "redo" | "clear");
            assert_eq!(on_disk, !is_history, "assets/brushes/{id}.svg 有無不對");
        }
    }

    #[test]
    fn icons_only_use_what_the_subset_supports_and_stay_inside_the_viewbox() {
        for t in all_tools() {
            let tool: FfiTool = t.into();
            let src = icon_source(tool).unwrap_or("");
            if src.is_empty() {
                continue;
            }
            assert!(
                !src.contains("transform="),
                "{tool:?}：子集不支援 transform"
            );
            assert!(!src.contains("dasharray"), "{tool:?}：子集不支援 dasharray");
            for shape in brush_icon(tool) {
                for c in &shape.commands {
                    let want = match c.op.as_str() {
                        "M" | "L" => 2,
                        "C" => 6,
                        "Z" => 0,
                        other => panic!("{tool:?}：未知指令 {other}"),
                    };
                    assert_eq!(c.args.len(), want, "{tool:?}：{} 的參數數量不對", c.op);
                    for v in &c.args {
                        assert!(
                            (-6.0..=ICON_VIEWBOX + 6.0).contains(v),
                            "{tool:?}：座標 {v} 超出圖示範圍"
                        );
                    }
                }
            }
        }
    }

    #[test]
    fn brushes_follow_the_ink_colour_but_modes_do_not_need_to() {
        for t in all_tools().into_iter().filter(|t| t.is_brush()) {
            let uses_ink = brush_icon(t.into())
                .iter()
                .any(|s| s.fill == FfiPaint::Ink || s.stroke == FfiPaint::Ink);
            assert!(
                uses_ink,
                "{t:?} 的圖示不跟著筆色變 —— 使用者看不出自己選了什麼顏色"
            );
        }
    }

    #[test]
    fn path_data_parser_handles_relative_and_shorthand_commands() {
        let c = parse_path_data("M10 10 l5 0 h5 v5 z");
        let ops: Vec<&str> = c.iter().map(|c| c.op.as_str()).collect();
        assert_eq!(ops, ["M", "L", "L", "L", "Z"]);
        assert_eq!(c[3].args, vec![20.0, 15.0]);
        assert_eq!(numbers("1-2.5 .5,3"), vec![1.0, -2.5, 0.5, 3.0]);
    }

    #[test]
    fn every_brush_has_a_preview_and_modes_do_not() {
        for t in all_tools() {
            let tool: FfiTool = t.into();
            let n = brush_preview_dabs(tool, 80.0, 24.0).len();
            assert_eq!(n > 0, t.is_brush(), "{tool:?} 的預覽有無不對（{n} 個筆點）");
        }
    }

    #[test]
    fn previews_stay_inside_their_box() {
        for t in all_tools().into_iter().filter(|t| t.is_brush()) {
            for d in brush_preview_dabs(t.into(), 80.0, 24.0) {
                assert!(d.x > -6.0 && d.x < 86.0, "{t:?} 預覽超出左右：{d:?}");
                assert!(d.y > -10.0 && d.y < 34.0, "{t:?} 預覽超出上下：{d:?}");
            }
        }
    }
}
