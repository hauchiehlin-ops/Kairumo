//! 素材圖庫的線圖。
//!
//! # 為什麼在核心
//!
//! 58 件素材的線圖原本是 1,200 行的 CoreGraphics 程式碼，只存在於 Apple 端。
//! Android 要畫出同樣的圖，只有兩條路：再寫一份 Compose 版（兩份繪圖程式
//! 必然會漂移，而且沒有任何測試抓得到「圖畫得不一樣」），或是把圖形本身
//! 變成**資料**。這裡選後者。
//!
//! 每一件素材是一串路徑（[`FfiDrawPath`]），平台層只要會畫路徑就行 ——
//! 不需要知道那是齒輪還是螺栓。
//!
//! # 座標系
//!
//! 一律畫在 **400 × 400** 的方框裡，原點左上、y 向下（與兩個平台的 2D
//! 繪圖座標一致）。平台層要放進別的尺寸就整體縮放。
//!
//! # 為什麼沒有圓與矩形這兩種基本型
//!
//! 全部都轉成三次貝茲路徑。平台層因此只要實作一個 `Path`，不必再各自處理
//! 圓角矩形的角、橢圓的離心率 —— 那些細節兩邊實作不同就會畫出不同的圖，
//! 而這正是整個模組要消滅的東西。

use std::f32::consts::{PI, TAU};

use crate::ffi_shapes::FfiPoint;

/// 路徑指令。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiPathVerb {
    /// 移動到 `(x, y)`，開始新的一段。
    Move,
    /// 直線到 `(x, y)`。
    Line,
    /// 三次貝茲到 `(x, y)`，控制點 `(c1x, c1y)`、`(c2x, c2y)`。
    Curve,
    /// 封閉目前這一段。
    Close,
}

/// 一個路徑指令。
///
/// 用扁平的欄位而不是巢狀列舉：UniFFI 的列舉附帶值在 Kotlin 端會展開成
/// sealed class，每畫一條線就要 match 一次型別，繪圖迴圈會非常囉嗦。
#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct FfiPathSeg {
    pub verb: FfiPathVerb,
    pub x: f32,
    pub y: f32,
    pub c1x: f32,
    pub c1y: f32,
    pub c2x: f32,
    pub c2y: f32,
}

/// 一條路徑與它的畫法。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiDrawPath {
    pub segs: Vec<FfiPathSeg>,
    /// 線寬。
    pub width: f32,
    /// true 時用強調色（紅／粉）而不是主線色。
    pub accent: bool,
    /// 封閉且可填色。實物風格才會填，線框風格一律只描邊。
    pub fillable: bool,
    /// 虛線。
    pub dashed: bool,
    /// 指定填色 `#RRGGBB`；空字串表示照配色走。
    ///
    /// 只有少數地方需要（瀏覽器線框的紅黃綠控制鈕），但少了它那三顆點
    /// 就只是三個同色的圈圈，認不出是什麼。
    pub fill_override_hex: String,
}

/// 線圖風格。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiAssetRenderStyle {
    /// 工程線框：藍圖風格，只有線條。
    Blueprint,
    /// 實物：封閉路徑填色。
    Solid,
}

/// 線圖用到的顏色。平台層照這個畫，兩邊才會是同一張圖。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiAssetPalette {
    /// 主線色。
    pub stroke_hex: String,
    /// 強調色。
    pub accent_hex: String,
    /// 實物風格的填色（含透明度，`#RRGGBBAA`）。線框風格不填。
    pub fill_hex: String,
    /// 底圖色。
    pub background_hex: String,
    /// 方格線色（含透明度）。
    pub grid_hex: String,
}

/// 取得配色。
///
/// `dark` 對應 Apple 端「AI 概念提案」那一類素材的深色藍圖底 ——
/// 分類本身就是資訊，深色底讓使用者一眼看出那不是既有產品的圖紙。
#[uniffi::export]
pub fn asset_palette(style: FfiAssetRenderStyle, dark: bool) -> FfiAssetPalette {
    let fill = match (style, dark) {
        (FfiAssetRenderStyle::Blueprint, _) => "#00000000",
        (FfiAssetRenderStyle::Solid, true) => "#00FFFF38",
        (FfiAssetRenderStyle::Solid, false) => "#6B94D14D",
    };
    if dark {
        FfiAssetPalette {
            stroke_hex: "#00FFFF".into(),
            accent_hex: "#FF375F".into(),
            fill_hex: fill.into(),
            background_hex: "#1A1F2E".into(),
            grid_hex: "#00FFFF1F".into(),
        }
    } else {
        FfiAssetPalette {
            stroke_hex: "#1A4DA6".into(),
            accent_hex: "#D93333".into(),
            fill_hex: fill.into(),
            background_hex: "#F5F7FC".into(),
            grid_hex: "#007AFF1A".into(),
        }
    }
}

/// 畫布邊長（點）。方格底線每 20 點一條。
#[uniffi::export]
pub fn asset_canvas_size() -> f32 {
    400.0
}

/// 某一個線圖代號的全部路徑。
///
/// 認不得的代號回一個立方體示意圖，**不是空清單也不是錯誤** ——
/// 與 Apple 端的 `default:` 分支相同。目錄與線圖是兩份分開維護的資料，
/// 新增素材時線圖可能還沒畫；那時該顯示一個佔位圖形，不是一格空白。
#[uniffi::export]
pub fn asset_drawing(code: String) -> Vec<FfiDrawPath> {
    draw(&code)
}

/// 藍圖風格底部的尺寸引線裝飾。
///
/// 與圖形分開回傳，因為它只在線框風格出現 —— 實物風格是要貼進筆記當成
/// 一個物件用的，帶著工程標註反而變成雜訊。
#[uniffi::export]
pub fn asset_dimension_callout() -> Vec<FfiDrawPath> {
    let mut b = Builder::new();
    b.accent(true).width(1.2);
    b.poly(&[(50.0, 320.0), (350.0, 320.0)]);
    b.poly(&[(50.0, 315.0), (50.0, 325.0)]);
    b.poly(&[(350.0, 315.0), (350.0, 325.0)]);
    b.finish()
}

/// 有線圖的代號。測試用它確認目錄裡的每一件素材都畫得出東西。
#[uniffi::export]
pub fn asset_drawing_codes() -> Vec<String> {
    CODES.iter().map(|s| s.to_string()).collect()
}

// ── 建構小工具 ──────────────────────────────────────────────────────
//
// 名稱刻意與 Apple 端原本的輔助函式對齊（ellipse / circle / polyline /
// rounded / threadProfile），對照原始程式碼時才看得出哪一行對應哪一行。

const DEFAULT_WIDTH: f32 = 2.5;

/// 橢圓轉貝茲的控制點比例。四段三次貝茲逼近圓的標準常數。
const KAPPA: f32 = 0.5522848;

fn seg(verb: FfiPathVerb, x: f32, y: f32) -> FfiPathSeg {
    FfiPathSeg { verb, x, y, c1x: 0.0, c1y: 0.0, c2x: 0.0, c2y: 0.0 }
}

fn curve_seg(c1: (f32, f32), c2: (f32, f32), to: (f32, f32)) -> FfiPathSeg {
    FfiPathSeg {
        verb: FfiPathVerb::Curve,
        x: to.0,
        y: to.1,
        c1x: c1.0,
        c1y: c1.1,
        c2x: c2.0,
        c2y: c2.1,
    }
}

struct Builder {
    paths: Vec<FfiDrawPath>,
    width: f32,
    accent: bool,
    /// 下一條路徑的填色覆寫。用完即清 —— 覆寫是逐條的，不是模式。
    fill_override: String,
}

impl Builder {
    fn new() -> Self {
        Self {
            paths: Vec::new(),
            width: DEFAULT_WIDTH,
            accent: false,
            fill_override: String::new(),
        }
    }

    /// 對應 `cg.setLineWidth`。
    fn width(&mut self, w: f32) -> &mut Self {
        self.width = w;
        self
    }

    /// 對應 `cg.setStrokeColor(accentColor)` / 切回主線色。
    fn accent(&mut self, on: bool) -> &mut Self {
        self.accent = on;
        self
    }

    fn push(&mut self, segs: Vec<FfiPathSeg>, fillable: bool, dashed: bool) {
        if segs.is_empty() {
            return;
        }
        self.paths.push(FfiDrawPath {
            segs,
            width: self.width,
            accent: self.accent,
            fillable,
            dashed,
            fill_override_hex: std::mem::take(&mut self.fill_override),
        });
    }

    /// 開放折線。
    fn poly(&mut self, pts: &[(f32, f32)]) -> &mut Self {
        if pts.len() < 2 {
            return self;
        }
        let mut segs = vec![seg(FfiPathVerb::Move, pts[0].0, pts[0].1)];
        for p in &pts[1..] {
            segs.push(seg(FfiPathVerb::Line, p.0, p.1));
        }
        self.push(segs, false, false);
        self
    }

    /// 虛線折線。
    fn dash(&mut self, pts: &[(f32, f32)]) -> &mut Self {
        if pts.len() < 2 {
            return self;
        }
        let mut segs = vec![seg(FfiPathVerb::Move, pts[0].0, pts[0].1)];
        for p in &pts[1..] {
            segs.push(seg(FfiPathVerb::Line, p.0, p.1));
        }
        self.push(segs, false, true);
        self
    }

    /// 封閉折線（實物風格會填色）。
    fn shape(&mut self, pts: &[(f32, f32)]) -> &mut Self {
        if pts.len() < 3 {
            return self;
        }
        let mut segs = vec![seg(FfiPathVerb::Move, pts[0].0, pts[0].1)];
        for p in &pts[1..] {
            segs.push(seg(FfiPathVerb::Line, p.0, p.1));
        }
        segs.push(seg(FfiPathVerb::Close, pts[0].0, pts[0].1));
        self.push(segs, true, false);
        self
    }

    /// 只描邊的矩形。
    ///
    /// 沒有「會填色的矩形」版本是刻意的：58 張圖裡的矩形**全部**走
    /// Apple 的 `cg.stroke(rect)`，也就是都不填。多留一個填色版只會讓人
    /// 挑錯邊，而挑錯的後果是實物風格下多出一塊不該有的色塊。
    ///
    /// Apple 端的 `cg.stroke(rect)` 不經過 `fillAndStroke`，所以**實物風格
    /// 也不填色**。照抄那個行為 —— 不然同一張圖在兩個平台上填色的部位不同。
    fn rect_open(&mut self, x: f32, y: f32, w: f32, h: f32) -> &mut Self {
        let segs = vec![
            seg(FfiPathVerb::Move, x, y),
            seg(FfiPathVerb::Line, x + w, y),
            seg(FfiPathVerb::Line, x + w, y + h),
            seg(FfiPathVerb::Line, x, y + h),
            seg(FfiPathVerb::Close, x, y),
        ];
        self.push(segs, false, false);
        self
    }

    /// 圓角矩形。
    fn rounded(&mut self, x: f32, y: f32, w: f32, h: f32, r: f32) -> &mut Self {
        let r = r.min(w / 2.0).min(h / 2.0).max(0.0);
        let k = r * KAPPA;
        let (x1, y1) = (x + w, y + h);
        let segs = vec![
            seg(FfiPathVerb::Move, x + r, y),
            seg(FfiPathVerb::Line, x1 - r, y),
            curve_seg((x1 - r + k, y), (x1, y + r - k), (x1, y + r)),
            seg(FfiPathVerb::Line, x1, y1 - r),
            curve_seg((x1, y1 - r + k), (x1 - r + k, y1), (x1 - r, y1)),
            seg(FfiPathVerb::Line, x + r, y1),
            curve_seg((x + r - k, y1), (x, y1 - r + k), (x, y1 - r)),
            seg(FfiPathVerb::Line, x, y + r),
            curve_seg((x, y + r - k), (x + r - k, y), (x + r, y)),
            seg(FfiPathVerb::Close, x + r, y),
        ];
        self.push(segs, true, false);
        self
    }

    /// 以外接矩形畫橢圓。
    fn ellipse(&mut self, x: f32, y: f32, w: f32, h: f32) -> &mut Self {
        let (rx, ry) = (w / 2.0, h / 2.0);
        let (cx, cy) = (x + rx, y + ry);
        let (kx, ky) = (rx * KAPPA, ry * KAPPA);
        let segs = vec![
            seg(FfiPathVerb::Move, cx, y),
            curve_seg((cx + kx, y), (cx + rx, cy - ky), (cx + rx, cy)),
            curve_seg((cx + rx, cy + ky), (cx + kx, cy + ry), (cx, cy + ry)),
            curve_seg((cx - kx, cy + ry), (cx - rx, cy + ky), (cx - rx, cy)),
            curve_seg((cx - rx, cy - ky), (cx - kx, y), (cx, y)),
            seg(FfiPathVerb::Close, cx, y),
        ];
        self.push(segs, true, false);
        self
    }

    /// 以圓心與半徑畫圓。
    fn circle(&mut self, cx: f32, cy: f32, r: f32) -> &mut Self {
        self.ellipse(cx - r, cy - r, r * 2.0, r * 2.0)
    }

    /// 下一條路徑用指定的填色。
    fn fill_with(&mut self, hex: &str) -> &mut Self {
        self.fill_override = hex.to_string();
        self
    }

    /// 自由路徑：直接餵指令，給貝茲曲線用。
    fn path(&mut self, segs: Vec<FfiPathSeg>) -> &mut Self {
        self.push(segs, false, false);
        self
    }

    /// 螺紋鋸齒側視輪廓，用在螺釘與鉚釘。
    fn thread(&mut self, x: f32, top: f32, bottom: f32, half_width: f32, pitch: f32) -> &mut Self {
        let mut pts = Vec::new();
        let mut y = top;
        let mut left = true;
        while y <= bottom {
            pts.push((if left { x - half_width } else { x + half_width }, y));
            left = !left;
            y += pitch;
        }
        self.poly(&pts)
    }

    fn finish(&mut self) -> Vec<FfiDrawPath> {
        std::mem::take(&mut self.paths)
    }
}

/// 路徑開頭。
fn m(x: f32, y: f32) -> FfiPathSeg {
    seg(FfiPathVerb::Move, x, y)
}

/// 直線。
fn l(x: f32, y: f32) -> FfiPathSeg {
    seg(FfiPathVerb::Line, x, y)
}

/// 三次貝茲。參數順序與 CoreGraphics 的 `addCurve(to:control1:control2:)`
/// **相反**（這裡是 c1, c2, to），對照原始程式碼時要留意。
fn c(c1x: f32, c1y: f32, c2x: f32, c2y: f32, x: f32, y: f32) -> FfiPathSeg {
    curve_seg((c1x, c1y), (c2x, c2y), (x, y))
}

/// 二次貝茲轉三次。CoreGraphics 的 `addQuadCurve` 沒有三次對應品，
/// 但每一條二次貝茲都有唯一的三次表示：控制點取起點／終點往控制點的 2/3 處。
fn q(from: (f32, f32), cx: f32, cy: f32, x: f32, y: f32) -> FfiPathSeg {
    c(
        from.0 + 2.0 / 3.0 * (cx - from.0),
        from.1 + 2.0 / 3.0 * (cy - from.1),
        x + 2.0 / 3.0 * (cx - x),
        y + 2.0 / 3.0 * (cy - y),
        x,
        y,
    )
}

/// 以圓心、半徑、起訖角（度）產生一段圓弧的貝茲近似，接在現有路徑後面。
///
/// 每 90 度一段。CoreGraphics 的 `addArc` 會自動補一條到起點的直線，
/// 這裡的呼叫端自己負責那條線 —— 隱含的行為在兩個平台上不一定相同。
fn arc_segs(cx: f32, cy: f32, r: f32, start_deg: f32, end_deg: f32) -> Vec<FfiPathSeg> {
    let mut out = Vec::new();
    let total = end_deg - start_deg;
    let steps = ((total.abs() / 90.0).ceil() as usize).max(1);
    let step = total / steps as f32;
    let mut a = start_deg;
    for _ in 0..steps {
        let b = a + step;
        let (ar, br) = (a.to_radians(), b.to_radians());
        // 單位圓上的三次貝茲控制點長度。
        let k = (4.0 / 3.0) * ((br - ar) / 4.0).tan();
        let (p0x, p0y) = (cx + r * ar.cos(), cy + r * ar.sin());
        let (p1x, p1y) = (cx + r * br.cos(), cy + r * br.sin());
        out.push(c(
            p0x - k * r * ar.sin(),
            p0y + k * r * ar.cos(),
            p1x + k * r * br.sin(),
            p1y - k * r * br.cos(),
            p1x,
            p1y,
        ));
        a = b;
    }
    out
}

include!("asset_art_shapes.rs");

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ffi_assets::asset_items;
    use std::collections::HashSet;

    #[test]
    fn every_catalogue_item_has_a_drawing() {
        // 目錄與線圖是兩份資料。對不上的話，面板上就會出現一格空白 ——
        // 而那在單看任一份資料時完全看不出來。
        for item in asset_items() {
            let paths = asset_drawing(item.drawing_code.clone());
            assert!(
                !paths.is_empty(),
                "{}（{}）沒有線圖",
                item.id,
                item.drawing_code
            );
        }
    }

    #[test]
    fn no_drawing_escapes_the_canvas() {
        // 座標算錯的話平台層會畫出一條橫跨整個畫布的線，而測試如果只檢查
        // 「有沒有路徑」是抓不到的。留 40 點餘裕給線寬與刻意的出血。
        for code in asset_drawing_codes() {
            for path in asset_drawing(code.clone()) {
                for s in path.segs {
                    for (x, y) in [(s.x, s.y), (s.c1x, s.c1y), (s.c2x, s.c2y)] {
                        assert!(x.is_finite() && y.is_finite(), "{code} 有 NaN 座標");
                        assert!((-40.0..=440.0).contains(&x), "{code} x 超出畫布：{x}");
                        assert!((-40.0..=440.0).contains(&y), "{code} y 超出畫布：{y}");
                    }
                }
            }
        }
    }

    #[test]
    fn every_path_starts_with_a_move() {
        // 沒有起點的路徑在不同繪圖 API 上行為不一樣：有的忽略，有的從
        // 上一條路徑的終點接下去，畫出一條原本不存在的線。
        for code in asset_drawing_codes() {
            for path in asset_drawing(code.clone()) {
                assert_eq!(path.segs[0].verb, FfiPathVerb::Move, "{code} 的路徑沒有起點");
                assert!(path.width > 0.0, "{code} 的線寬是 0");
            }
        }
    }

    #[test]
    fn drawing_codes_are_unique() {
        let mut seen = HashSet::new();
        for code in asset_drawing_codes() {
            assert!(seen.insert(code.clone()), "重複的線圖代號：{code}");
        }
    }

    #[test]
    fn an_unknown_code_falls_back_to_a_placeholder() {
        // 與 Apple 端的 default 分支一致：畫一個立方體，不是留白。
        assert!(!asset_drawing("沒有這個代號".into()).is_empty());
    }

    #[test]
    fn the_dimension_callout_is_accented_and_thin() {
        // 引線要看得出是標註而不是圖形的一部分。
        let paths = asset_dimension_callout();
        assert_eq!(paths.len(), 3);
        for p in paths {
            assert!(p.accent);
            assert!(p.width < 2.0);
        }
    }

    #[test]
    fn a_circle_really_is_round() {
        // 貝茲逼近寫錯（例如 KAPPA 用錯）會讓所有圓變成方角，
        // 而 58 張圖裡幾乎每一張都有圓。
        let mut b = Builder::new();
        b.circle(200.0, 200.0, 100.0);
        let path = &b.finish()[0];
        // 取曲線段的端點，都該落在半徑上。
        for s in &path.segs {
            if s.verb == FfiPathVerb::Curve {
                let d = ((s.x - 200.0).powi(2) + (s.y - 200.0).powi(2)).sqrt();
                assert!((d - 100.0).abs() < 0.01, "端點不在圓上：{d}");
            }
        }
    }

    #[test]
    fn palettes_are_well_formed() {
        for style in [FfiAssetRenderStyle::Blueprint, FfiAssetRenderStyle::Solid] {
            for dark in [true, false] {
                let p = asset_palette(style, dark);
                for hex in [p.stroke_hex, p.accent_hex, p.fill_hex, p.background_hex, p.grid_hex] {
                    assert!(hex.starts_with('#'), "壞的色碼：{hex}");
                    assert!(hex.len() == 7 || hex.len() == 9, "壞的色碼長度：{hex}");
                }
            }
        }
        // 線框風格不填色 —— 填了就不是線框了。
        assert!(asset_palette(FfiAssetRenderStyle::Blueprint, false).fill_hex.ends_with("00"));
    }
}

/// 讓 `FfiPoint` 在這個模組裡不算未使用（平台層會用到同一個型別）。
#[allow(dead_code)]
fn _point_marker(p: FfiPoint) -> f32 {
    p.x
}
