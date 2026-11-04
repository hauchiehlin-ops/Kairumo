//! 紙張底紋：方格、橫線、點陣、五線譜、等角軸測。
//!
//! # 為什麼這一層也下沉了
//!
//! 版面（`ffi_guides`）早就在核心，底紋卻留在兩端各寫一次，理由是量：
//! 5mm 點陣在 A4 上是兩千多個點，一顆顆送過 FFI 只是浪費。
//!
//! 那個理由是對的，**結論卻錯了** —— 實際量過兩端的數字：
//!
//! | 底紋 | Apple | Android |
//! |---|---|---|
//! | 方格間距 | 28 | 24 |
//! | 點陣間距 | 20 | 16 |
//! | 橫線起點 | y=60、左右各留 30 | y=32、貼齊紙邊 |
//! | 五線譜 | 行距 9、組距 96 | 行距 10、組距 48 |
//! | 等角軸測 | 有 | 沒有 |
//!
//! 同一本筆記在兩台裝置上，「寫在第幾行」「第幾格」根本對不起來，而這
//! 是使用者拿方格紙的唯一理由。康乃爾更明顯：Apple 的分區線由版面畫、
//! Android 又自己畫了一次，於是 Android 上是兩條線疊在不同位置。
//!
//! # 送格子，不送點
//!
//! 折衷是送**格子的描述**而不是格子本身：一條「band」是「第一個圖元 ＋
//! 兩個位移向量 ＋ 兩個次數」。點陣是一個 band（40×50），不是兩千筆資料；
//! 平台端只有一個兩層迴圈，認得兩種圖元。新增一種底紋是改這個檔案，
//! 兩邊同時就有 —— 也不會再各自飄。

use crate::ffi::PageStyle;
use crate::ffi_guides::FfiGuideTone;

/// 底紋圖元的種類。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiTextureKind {
    /// 線段：從 (x, y) 到 (x + w, y + h)。
    Line,
    /// 圓點：圓心 (x, y)，直徑 `w`。
    Dot,
}

/// 一族重複的圖元。
///
/// 畫法（兩端一模一樣的十行）：
///
/// ```text
/// for i in 0..count:
///     for j in 0..count2:
///         px = x + step_x * i + step2_x * j
///         py = y + step_y * i + step2_y * j
///         Line → (px, py) 到 (px + w, py + h)
///         Dot  → 圓心 (px, py)、直徑 w
/// ```
///
/// 座標與長度都是**頁面單位**（與 `standard_page_size` 同一套），平台
/// 乘上自己的縮放倍率就好。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiTextureBand {
    pub kind: FfiTextureKind,
    pub x: f32,
    pub y: f32,
    /// `Line` 是線段位移量；`Dot` 是直徑。
    pub w: f32,
    /// `Line` 是線段位移量；`Dot` 不用。
    pub h: f32,
    pub step_x: f32,
    pub step_y: f32,
    pub count: u32,
    /// 第二軸。不需要時是 0／0／1。
    pub step2_x: f32,
    pub step2_y: f32,
    pub count2: u32,
    /// 線寬。`Dot` 不用。
    pub weight: f32,
    /// 輕重。顏色仍然是平台的事（深色模式）。
    pub tone: FfiGuideTone,
}

fn band(kind: FfiTextureKind, tone: FfiGuideTone, weight: f32) -> FfiTextureBand {
    FfiTextureBand {
        kind,
        x: 0.0,
        y: 0.0,
        w: 0.0,
        h: 0.0,
        step_x: 0.0,
        step_y: 0.0,
        count: 0,
        step2_x: 0.0,
        step2_y: 0.0,
        count2: 1,
        weight,
        tone,
    }
}

/// 從 `first` 開始、每隔 `step` 一條，在 `limit` 之內排得下幾條。
fn fit(first: f32, step: f32, limit: f32) -> u32 {
    if step <= 0.0 || first >= limit {
        return 0;
    }
    (((limit - first) / step).floor() as i64 + 1).max(0) as u32
}

/// 這張紙的底紋。
///
/// `style` 是存在使用者檔案裡的那六種之一；`paper_id` 用來加上**不屬於
/// 那六種**的材質（目前只有等角軸測 —— 它的紙是 `Blank`，卻鋪滿 30° 斜線）。
///
/// 認不得的識別字就照 `style` 畫：未知的紙是一張乾淨的紙，不是錯誤畫面。
#[uniffi::export]
pub fn page_texture(
    paper_id: String,
    style: PageStyle,
    width: f32,
    height: f32,
) -> Vec<FfiTextureBand> {
    let w = width.max(1.0);
    let h = height.max(1.0);
    let mut out: Vec<FfiTextureBand> = Vec::new();

    match style {
        PageStyle::Blank => {}

        PageStyle::Lined => {
            // 行高 32、左右各留 30：與 Apple 端一致。留白是為了讓橫線
            // 不要貼著紙邊 —— 裝訂邊寫不了字。
            let step = 32.0;
            let inset = 30.0;
            let first = 60.0;
            out.push(FfiTextureBand {
                x: inset,
                y: first,
                w: w - inset * 2.0,
                step_y: step,
                count: fit(first, step, h - 1.0),
                ..band(FfiTextureKind::Line, FfiGuideTone::Light, 1.0)
            });
        }

        PageStyle::Grid => {
            let step = 28.0;
            out.push(FfiTextureBand {
                x: step,
                h,
                step_x: step,
                count: fit(step, step, w - 1.0),
                ..band(FfiTextureKind::Line, FfiGuideTone::Hairline, 1.0)
            });
            out.push(FfiTextureBand {
                y: step,
                w,
                step_y: step,
                count: fit(step, step, h - 1.0),
                ..band(FfiTextureKind::Line, FfiGuideTone::Hairline, 1.0)
            });
        }

        PageStyle::Dotted => {
            // 一個 band 就是整面點陣：兩個軸、兩個次數。
            let step = 20.0;
            out.push(FfiTextureBand {
                x: step,
                y: step,
                w: 2.0,
                step_x: step,
                count: fit(step, step, w - 1.0),
                step2_y: step,
                count2: fit(step, step, h - 1.0),
                ..band(FfiTextureKind::Dot, FfiGuideTone::Hairline, 0.0)
            });
        }

        PageStyle::Cornell => {
            // 三條分區線由版面（`page_guides`）畫，這裡只鋪主筆記欄的橫線 ——
            // 兩邊都畫的話會是兩條線落在不同位置（Android 上看得到）。
            let step = 32.0;
            let left = w * 0.3;
            let first = 60.0;
            let bottom = h * 0.8;
            out.push(FfiTextureBand {
                x: left,
                y: first,
                w: w - left - 30.0,
                step_y: step,
                count: fit(first, step, bottom - 1.0),
                ..band(FfiTextureKind::Line, FfiGuideTone::Light, 1.0)
            });
        }

        PageStyle::MusicStaff => {
            // 五條一組：組是第一軸（`count`），組裡那五條是第二軸。
            let line_gap = 9.0;
            let group_gap = 96.0;
            let top = 90.0;
            let inset = 40.0;
            out.push(FfiTextureBand {
                x: inset,
                y: top,
                w: w - inset * 2.0,
                step_y: group_gap,
                count: fit(top, group_gap, h - 40.0 - 1.0),
                step2_y: line_gap,
                count2: 5,
                ..band(FfiTextureKind::Line, FfiGuideTone::Light, 1.0)
            });
        }
    }

    if paper_id == "isometric" {
        push_isometric(&mut out, w, h);
    }
    out
}

/// 30° 等角軸測：直線加上左右兩族斜線。
///
/// 它不是 `PageStyle` 的成員（那張紙存下來是 `Blank`），但它確實是一種
/// 鋪滿整頁的材質 —— Apple 端本來就有，Android 端完全沒有。
fn push_isometric(out: &mut Vec<FfiTextureBand>, w: f32, h: f32) {
    let step = 36.0;
    let slope = 0.577_35_f32; // tan(30°)
    let rise = w * slope;
    let v_step = step * slope * 2.0;

    out.push(FfiTextureBand {
        h,
        step_x: step,
        count: fit(0.0, step, w - 1.0),
        ..band(FfiTextureKind::Line, FfiGuideTone::Hairline, 0.8)
    });
    // 往右下：起點從紙的上方外側開始，最後一條落在下緣。
    out.push(FfiTextureBand {
        y: -rise,
        w,
        h: rise,
        step_y: v_step,
        count: fit(-rise, v_step, h),
        ..band(FfiTextureKind::Line, FfiGuideTone::Hairline, 0.8)
    });
    // 往右上。
    out.push(FfiTextureBand {
        w,
        h: -rise,
        step_y: v_step,
        count: fit(0.0, v_step, h + rise),
        ..band(FfiTextureKind::Line, FfiGuideTone::Hairline, 0.8)
    });
}

// ---- 吸附格線 -------------------------------------------------------------

/// 物件吸附用的格子：兩軸各一個間距與起點（頁面座標）。
///
/// 從**這張紙真正畫出來的底紋**推出來 —— 方格紙吸到方格線、點陣紙吸到點、
/// 橫線紙只吸行線（x 軸退回預設步距）。以前兩端各寫死 20pt，與紙上的格子
/// 對不起來：「吸附格線」開著，物件卻停在格子中間。
#[derive(Clone, Copy, Debug, PartialEq, uniffi::Record)]
pub struct FfiSnapGrid {
    pub step_x: f32,
    pub step_y: f32,
    pub origin_x: f32,
    pub origin_y: f32,
}

/// 紙上沒有可用的格子時的步距（空白紙、等角軸測）。與舊版文字方塊的 20pt 相同。
pub const DEFAULT_SNAP_STEP: f32 = 20.0;
/// 比這個還密的線（五線譜的 9pt 線距）不拿來吸 —— 每移一點就跳一格，等於沒吸。
const MIN_SNAP_STEP: f32 = 12.0;

#[uniffi::export]
pub fn page_snap_grid(paper_id: String, style: PageStyle, width: f32, height: f32) -> FfiSnapGrid {
    let mut x: Option<(f32, f32)> = None;
    let mut y: Option<(f32, f32)> = None;
    let take = |slot: &mut Option<(f32, f32)>, step: f32, origin: f32| {
        if step < MIN_SNAP_STEP {
            return;
        }
        if slot.is_none_or(|(s, _)| step < s) {
            *slot = Some((step, origin));
        }
    };
    for b in page_texture(paper_id, style, width, height) {
        for (sx, sy, n) in [(b.step_x, b.step_y, b.count), (b.step2_x, b.step2_y, b.count2)] {
            if n < 2 {
                continue;
            }
            if sx.abs() > 0.0 && sy == 0.0 {
                take(&mut x, sx.abs(), b.x);
            } else if sy.abs() > 0.0 && sx == 0.0 {
                take(&mut y, sy.abs(), b.y);
            }
        }
    }
    let (step_x, origin_x) = x.unwrap_or((DEFAULT_SNAP_STEP, 0.0));
    let (step_y, origin_y) = y.unwrap_or((DEFAULT_SNAP_STEP, 0.0));
    FfiSnapGrid { step_x, step_y, origin_x, origin_y }
}

/// 把物件的左上角吸到最近的格點。步距 ≤ 0 的軸不動。
#[uniffi::export]
pub fn snap_origin_to_grid(x: f32, y: f32, grid: FfiSnapGrid) -> crate::ffi_shapes::FfiPoint {
    fn snap(v: f32, step: f32, origin: f32) -> f32 {
        if step <= 0.0 || !v.is_finite() {
            return v;
        }
        origin + ((v - origin) / step).round() * step
    }
    crate::ffi_shapes::FfiPoint {
        x: snap(x, grid.step_x, grid.origin_x),
        y: snap(y, grid.step_y, grid.origin_y),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const W: f32 = 800.0;
    const H: f32 = 1132.0;

    #[test]
    fn blank_has_no_texture() {
        assert!(page_texture("blank".into(), PageStyle::Blank, W, H).is_empty());
    }

    #[test]
    fn grid_is_two_bands_that_stay_on_the_page() {
        let bands = page_texture("grid".into(), PageStyle::Grid, W, H);
        assert_eq!(bands.len(), 2);
        for b in &bands {
            assert!(b.count > 0);
            let last_x = b.x + b.step_x * (b.count - 1) as f32;
            let last_y = b.y + b.step_y * (b.count - 1) as f32;
            assert!(last_x <= W, "最後一條線跑出紙的右邊：{last_x}");
            assert!(last_y <= H, "最後一條線跑到紙的下面：{last_y}");
        }
    }

    #[test]
    fn dots_are_one_band_not_two_thousand_items() {
        let bands = page_texture("dot_grid_fine".into(), PageStyle::Dotted, W, H);
        assert_eq!(bands.len(), 1);
        let b = &bands[0];
        assert_eq!(b.kind, FfiTextureKind::Dot);
        // 一個 band 描述了整面：兩軸相乘才是實際的點數。
        assert!(b.count * b.count2 > 1000, "{} × {}", b.count, b.count2);
    }

    #[test]
    fn music_staff_groups_five_lines_each() {
        let bands = page_texture("music".into(), PageStyle::MusicStaff, W, H);
        assert_eq!(bands.len(), 1);
        assert_eq!(bands[0].count2, 5);
        assert!(bands[0].count >= 8);
    }

    #[test]
    fn cornell_only_rules_the_note_column() {
        let bands = page_texture("cornell".into(), PageStyle::Cornell, W, H);
        assert_eq!(bands.len(), 1);
        // 分區線是版面的事，橫線不得越過左欄與底部總結欄。
        assert!(bands[0].x > W * 0.29);
        let last_y = bands[0].y + bands[0].step_y * (bands[0].count - 1) as f32;
        assert!(last_y < H * 0.8);
    }

    #[test]
    fn isometric_adds_three_families_on_a_blank_page() {
        let plain = page_texture("blank".into(), PageStyle::Blank, W, H);
        let iso = page_texture("isometric".into(), PageStyle::Blank, W, H);
        assert!(plain.is_empty());
        assert_eq!(iso.len(), 3);
        assert!(iso.iter().all(|b| b.count > 0));
    }

    #[test]
    fn snap_grid_follows_the_paper() {
        let grid = page_snap_grid("grid".into(), PageStyle::Grid, 600.0, 800.0);
        assert_eq!((grid.step_x, grid.step_y), (28.0, 28.0));
        let p = snap_origin_to_grid(40.0, 71.0, grid);
        assert_eq!((p.x, p.y), (28.0, 84.0));

        let dots = page_snap_grid("dot".into(), PageStyle::Dotted, 600.0, 800.0);
        assert_eq!((dots.step_x, dots.step_y), (20.0, 20.0));

        // 橫線紙：y 吸到行線（起點 60、行高 32），x 退回預設步距。
        let lined = page_snap_grid("lined".into(), PageStyle::Lined, 600.0, 800.0);
        assert_eq!((lined.step_y, lined.origin_y), (32.0, 60.0));
        assert_eq!(lined.step_x, DEFAULT_SNAP_STEP);
        let p = snap_origin_to_grid(13.0, 100.0, lined);
        assert_eq!((p.x, p.y), (20.0, 92.0));

        let blank = page_snap_grid("blank".into(), PageStyle::Blank, 600.0, 800.0);
        assert_eq!((blank.step_x, blank.step_y), (DEFAULT_SNAP_STEP, DEFAULT_SNAP_STEP));
    }
}
