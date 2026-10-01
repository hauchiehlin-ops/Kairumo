//! 專業筆刷的自繪引擎：把一筆畫算成**筆點陣**（dab）。
//!
//! # 為什麼是筆點陣
//!
//! PencilKit 與 Android 的繪圖 API 都畫不出炭筆、蠟筆、噴槍、油畫筆這些質地。
//! 與其各端各寫一份「差不多」的算繪（寫完兩端長得不一樣），不如由核心把筆畫
//! 展開成一串簡單的橢圓 —— 位置、半徑、角度、透明度、邊緣柔度、明暗 ——
//! 兩端只需要把橢圓畫出來。**同一筆在 iPad 與 Android 上因此是同一張圖。**
//!
//! # 決定性
//!
//! 顆粒與鬃毛的亂數取自筆畫本身（第一點座標與點數），沒有全域狀態、沒有時間。
//! 同一筆畫算幾次、在哪台裝置算，結果逐位元相同；筆畫同步到另一台之後不會「重新抖一次」。

use crate::{InkPoint, Tool};

/// 一個筆點。座標為頁面座標。
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Dab {
    pub x: f32,
    pub y: f32,
    /// 橢圓半徑（未旋轉時的 x 向與 y 向）。
    pub rx: f32,
    pub ry: f32,
    /// 橢圓旋轉角（弧度）。
    pub angle: f32,
    /// 0–1，疊乘在筆畫顏色的不透明度上。
    pub alpha: f32,
    /// 0 = 硬邊，1 = 全柔邊（中心最實、向外漸淡）。
    pub softness: f32,
    /// -1 = 暗一階，0 = 原色，+1 = 亮一階。油畫筆用它做鬃毛深淺。
    pub shade: f32,
}

/// 單一筆畫最多產生的筆點數。超過就拉大間距，而不是截斷 —— 截斷會讓長線突然中斷。
const MAX_DABS: usize = 60_000;

/// 決定性亂數（splitmix64）。
struct Rng(u64);

impl Rng {
    fn new(seed: u64) -> Self {
        Self(seed ^ 0x9E37_79B9_7F4A_7C15)
    }

    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }

    /// 0.0–1.0
    fn unit(&mut self) -> f32 {
        (self.next() >> 40) as f32 / (1u64 << 24) as f32
    }

    /// -1.0–1.0
    fn signed(&mut self) -> f32 {
        self.unit() * 2.0 - 1.0
    }
}

/// 沿路徑重新取樣後的一個位置，屬性已內插。
#[derive(Clone, Copy)]
struct Sample {
    x: f32,
    y: f32,
    pressure: f32,
    /// 行進方向（弧度）。
    heading: f32,
    /// 0–1，沿整筆畫的進度。
    progress: f32,
}

fn seed_of(points: &[InkPoint]) -> u64 {
    let first = points
        .first()
        .copied()
        .unwrap_or(InkPoint::new(0.0, 0.0, 0.0, 0));
    let a = (first.x * 64.0) as i64 as u64;
    let b = (first.y * 64.0) as i64 as u64;
    a.wrapping_mul(0x1000_0000_01B3) ^ b.rotate_left(21) ^ (points.len() as u64).rotate_left(42)
}

/// 沿折線每隔 `spacing` 取一個樣。第一點與最後一點一定取。
fn resample(points: &[InkPoint], spacing: f32) -> Vec<Sample> {
    let mut out = Vec::new();
    if points.is_empty() {
        return out;
    }
    if points.len() == 1 {
        let p = points[0];
        out.push(Sample {
            x: p.x,
            y: p.y,
            pressure: p.pressure,
            heading: 0.0,
            progress: 0.0,
        });
        return out;
    }
    let mut total = 0.0f32;
    for w in points.windows(2) {
        total += ((w[1].x - w[0].x).powi(2) + (w[1].y - w[0].y).powi(2)).sqrt();
    }
    if total <= f32::EPSILON {
        let p = points[0];
        out.push(Sample {
            x: p.x,
            y: p.y,
            pressure: p.pressure,
            heading: 0.0,
            progress: 0.0,
        });
        return out;
    }
    let spacing = spacing.max(total / MAX_DABS as f32).max(0.05);
    let mut carried = 0.0f32; // 上一段剩下、還沒走到下一個取樣位置的距離
    let mut walked = 0.0f32;
    let mut heading = 0.0f32;
    for w in points.windows(2) {
        let (a, b) = (w[0], w[1]);
        let seg = ((b.x - a.x).powi(2) + (b.y - a.y).powi(2)).sqrt();
        if seg <= f32::EPSILON {
            continue;
        }
        heading = (b.y - a.y).atan2(b.x - a.x);
        let mut at = if out.is_empty() {
            0.0
        } else {
            spacing - carried
        };
        while at <= seg {
            let t = at / seg;
            out.push(Sample {
                x: a.x + (b.x - a.x) * t,
                y: a.y + (b.y - a.y) * t,
                pressure: a.pressure + (b.pressure - a.pressure) * t,
                heading,
                progress: ((walked + at) / total).clamp(0.0, 1.0),
            });
            at += spacing;
        }
        carried = seg - (at - spacing);
        walked += seg;
    }
    let last = points[points.len() - 1];
    if out
        .last()
        .is_none_or(|s| (s.x - last.x).hypot(s.y - last.y) > spacing * 0.25)
    {
        out.push(Sample {
            x: last.x,
            y: last.y,
            pressure: last.pressure,
            heading,
            progress: 1.0,
        });
    }
    out
}

fn pressure_scale(p: f32) -> f32 {
    0.35 + 0.65 * p.clamp(0.0, 1.0)
}

/// 把一筆畫展開成筆點陣。
///
/// `base_width` 是筆畫的基準寬度（頁面單位）。非自繪引擎的筆刷回傳空陣列 ——
/// 它們由各平台的原生算繪處理。
pub fn dabs(tool: Tool, points: &[InkPoint], base_width: f32) -> Vec<Dab> {
    if !tool.is_custom_engine() || points.is_empty() || base_width <= 0.0 {
        return Vec::new();
    }
    let mut rng = Rng::new(seed_of(points));
    match tool {
        Tool::Fineliner => fineliner(points, base_width),
        Tool::Calligraphy => calligraphy(points, base_width),
        Tool::Charcoal => charcoal(points, base_width, &mut rng),
        Tool::Crayon => crayon(points, base_width, &mut rng),
        Tool::Airbrush => airbrush(points, base_width, &mut rng),
        Tool::OilPaint => oil_paint(points, base_width, &mut rng),
        _ => Vec::new(),
    }
}

/// 針筆：等寬、硬邊、不受壓感影響。
fn fineliner(points: &[InkPoint], width: f32) -> Vec<Dab> {
    let r = (width * 0.5 * 0.6).max(0.4);
    resample(points, r * 0.35)
        .into_iter()
        .map(|s| Dab {
            x: s.x,
            y: s.y,
            rx: r,
            ry: r,
            angle: 0.0,
            alpha: 1.0,
            softness: 0.0,
            shade: 0.0,
        })
        .collect()
}

/// 書法扁頭筆：固定 40° 的扁橢圓。筆畫方向與筆頭夾角越大越粗，所以橫細豎粗。
fn calligraphy(points: &[InkPoint], width: f32) -> Vec<Dab> {
    let long = width * 0.5 * 1.4;
    let short = (width * 0.5 * 0.16).max(0.3);
    let nib = 40.0f32.to_radians();
    resample(points, short.max(0.4))
        .into_iter()
        .map(|s| {
            let k = 0.75 + 0.25 * s.pressure.clamp(0.0, 1.0);
            Dab {
                x: s.x,
                y: s.y,
                rx: long * k,
                ry: short,
                angle: nib,
                alpha: 1.0,
                softness: 0.0,
                shade: 0.0,
            }
        })
        .collect()
}

/// 炭筆：沿筆跡撒下大量小顆粒，輕壓稀疏而淡、重壓密而濃。
fn charcoal(points: &[InkPoint], width: f32, rng: &mut Rng) -> Vec<Dab> {
    let radius = width * 0.5;
    let mut out = Vec::new();
    for s in resample(points, (radius * 0.35).max(0.5)) {
        let p = pressure_scale(s.pressure);
        let reach = radius * (0.6 + 0.6 * p);
        let grains = (3.0 + 7.0 * p) as usize;
        for _ in 0..grains {
            let a = rng.unit() * std::f32::consts::TAU;
            let d = rng.unit().sqrt() * reach;
            let size = (radius * (0.06 + 0.16 * rng.unit())).max(0.25);
            out.push(Dab {
                x: s.x + a.cos() * d,
                y: s.y + a.sin() * d,
                rx: size,
                ry: size * (0.6 + 0.4 * rng.unit()),
                angle: rng.unit() * std::f32::consts::PI,
                alpha: (0.12 + 0.5 * rng.unit()) * (0.45 + 0.55 * p),
                softness: 0.15,
                shade: -0.25 * rng.unit(),
            });
        }
    }
    out
}

/// 蠟筆：蠟質飽滿、被紙紋咬掉一部分（約三成的顆粒留白）。
fn crayon(points: &[InkPoint], width: f32, rng: &mut Rng) -> Vec<Dab> {
    let radius = width * 0.5;
    let mut out = Vec::new();
    for s in resample(points, (radius * 0.3).max(0.5)) {
        let p = pressure_scale(s.pressure);
        let grains = (5.0 + 9.0 * p) as usize;
        for _ in 0..grains {
            // 輕壓時紙紋留白更多。
            if rng.unit() > 0.55 + 0.4 * p {
                continue;
            }
            let a = rng.unit() * std::f32::consts::TAU;
            let d = rng.unit().sqrt() * radius * (0.7 + 0.4 * p);
            let size = (radius * (0.16 + 0.2 * rng.unit())).max(0.4);
            out.push(Dab {
                x: s.x + a.cos() * d,
                y: s.y + a.sin() * d,
                rx: size,
                ry: size,
                angle: 0.0,
                alpha: 0.7 + 0.3 * rng.unit(),
                softness: 0.05,
                shade: 0.1 * rng.signed(),
            });
        }
    }
    out
}

/// 噴槍：很淡的柔邊大圓層層疊加成漸層，外加零星噴點。
fn airbrush(points: &[InkPoint], width: f32, rng: &mut Rng) -> Vec<Dab> {
    let radius = width * 0.5 * 1.3;
    let mut out = Vec::new();
    for s in resample(points, (radius * 0.18).max(0.5)) {
        let p = pressure_scale(s.pressure);
        out.push(Dab {
            x: s.x,
            y: s.y,
            rx: radius * (0.7 + 0.5 * p),
            ry: radius * (0.7 + 0.5 * p),
            angle: 0.0,
            alpha: 0.07 + 0.05 * p,
            softness: 1.0,
            shade: 0.0,
        });
        if rng.unit() < 0.5 {
            let a = rng.unit() * std::f32::consts::TAU;
            let d = rng.unit().sqrt() * radius * 1.4;
            let size = (radius * 0.04 * (1.0 + rng.unit())).max(0.25);
            out.push(Dab {
                x: s.x + a.cos() * d,
                y: s.y + a.sin() * d,
                rx: size,
                ry: size,
                angle: 0.0,
                alpha: 0.35 * rng.unit() + 0.1,
                softness: 0.0,
                shade: 0.0,
            });
        }
    }
    out
}

/// 油畫筆：七根鬃毛橫跨筆寬，各自的深淺與濃度略有差異，沿行進方向拖出條紋。
fn oil_paint(points: &[InkPoint], width: f32, rng: &mut Rng) -> Vec<Dab> {
    const BRISTLES: usize = 7;
    let half = width * 0.5;
    let bristle_r = (width / BRISTLES as f32 * 0.75).max(0.5);
    // 每根鬃毛固定的偏移、深淺、濃度（整筆不變，才會拖出連續的條紋）。
    let bristles: Vec<(f32, f32, f32)> = (0..BRISTLES)
        .map(|i| {
            let t = i as f32 / (BRISTLES - 1) as f32 * 2.0 - 1.0;
            (t, rng.signed() * 0.45, 0.78 + 0.22 * rng.unit())
        })
        .collect();
    let mut out = Vec::new();
    for s in resample(points, (bristle_r * 0.5).max(0.5)) {
        let p = pressure_scale(s.pressure);
        // 垂直於行進方向。
        let (nx, ny) = (-s.heading.sin(), s.heading.cos());
        // 起筆收筆時筆觸較窄。
        let ends = (s.progress.min(1.0 - s.progress) * 12.0).clamp(0.4, 1.0);
        for &(t, shade, alpha) in &bristles {
            let off = t * half * (0.5 + 0.5 * p) * ends;
            out.push(Dab {
                x: s.x + nx * off,
                y: s.y + ny * off,
                rx: bristle_r * (0.6 + 0.4 * p),
                ry: bristle_r * (0.6 + 0.4 * p),
                angle: 0.0,
                alpha,
                softness: 0.1,
                shade,
            });
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn line(n: usize, pressure: f32) -> Vec<InkPoint> {
        (0..n)
            .map(|i| {
                InkPoint::new(
                    10.0 + i as f32 * 8.0,
                    50.0 + (i as f32 * 0.7).sin() * 6.0,
                    pressure,
                    8_000,
                )
            })
            .collect()
    }

    const CUSTOM: [Tool; 6] = [
        Tool::Fineliner,
        Tool::Charcoal,
        Tool::Crayon,
        Tool::Airbrush,
        Tool::OilPaint,
        Tool::Calligraphy,
    ];

    #[test]
    fn native_brushes_produce_no_dabs() {
        for t in [
            Tool::FountainPen,
            Tool::BallPoint,
            Tool::Pencil,
            Tool::Brush,
            Tool::Marker,
            Tool::Highlighter,
            Tool::Watercolor,
        ] {
            assert!(!t.is_custom_engine());
            assert!(
                dabs(t, &line(10, 0.5), 6.0).is_empty(),
                "{t:?} 不該由自繪引擎處理"
            );
        }
    }

    #[test]
    fn every_custom_brush_draws_something_near_the_path() {
        let pts = line(20, 0.7);
        for t in CUSTOM {
            let d = dabs(t, &pts, 8.0);
            assert!(!d.is_empty(), "{t:?} 沒有產生任何筆點");
            for dab in &d {
                assert!(
                    dab.x >= -10.0 && dab.x <= 10.0 + 19.0 * 8.0 + 10.0,
                    "{t:?} 筆點跑到路徑之外：{dab:?}"
                );
                assert!(
                    (0.0..=1.0).contains(&dab.alpha),
                    "{t:?} alpha 越界：{dab:?}"
                );
                assert!(dab.rx > 0.0 && dab.ry > 0.0, "{t:?} 半徑非正：{dab:?}");
            }
        }
    }

    #[test]
    fn the_same_stroke_always_renders_the_same_dabs() {
        let pts = line(15, 0.6);
        for t in CUSTOM {
            assert_eq!(
                dabs(t, &pts, 7.0),
                dabs(t, &pts, 7.0),
                "{t:?} 同一筆畫算兩次結果不同 —— 兩台裝置會長得不一樣"
            );
        }
    }

    #[test]
    fn pressure_changes_charcoal_density_and_airbrush_size() {
        let light = line(20, 0.1);
        let heavy = line(20, 1.0);
        assert!(dabs(Tool::Charcoal, &heavy, 8.0).len() > dabs(Tool::Charcoal, &light, 8.0).len());
        let r = |p: &[InkPoint]| dabs(Tool::Airbrush, p, 8.0)[0].rx;
        assert!(r(&heavy) > r(&light));
    }

    #[test]
    fn fineliner_ignores_pressure() {
        let a = dabs(Tool::Fineliner, &line(10, 0.1), 6.0);
        let b = dabs(Tool::Fineliner, &line(10, 1.0), 6.0);
        assert_eq!(a[0].rx, b[0].rx);
    }

    #[test]
    fn calligraphy_is_thin_across_the_nib_and_thick_along_it() {
        let d = dabs(Tool::Calligraphy, &line(5, 1.0), 10.0);
        assert!(d[0].rx > d[0].ry * 4.0, "扁筆頭長短軸比太小：{:?}", d[0]);
    }

    #[test]
    fn degenerate_strokes_do_not_panic() {
        for t in CUSTOM {
            assert!(
                !dabs(t, &[InkPoint::new(5.0, 5.0, 0.5, 0)], 6.0).is_empty(),
                "{t:?} 單點（點一下）應該留下一個印記"
            );
            let same = vec![InkPoint::new(5.0, 5.0, 0.5, 0); 4];
            let _ = dabs(t, &same, 6.0);
            assert!(dabs(t, &[], 6.0).is_empty());
            assert!(dabs(t, &line(5, 0.5), 0.0).is_empty());
        }
    }

    #[test]
    fn a_very_long_stroke_is_thinned_not_truncated() {
        let pts: Vec<InkPoint> = (0..200)
            .map(|i| InkPoint::new(i as f32 * 500.0, 0.0, 0.8, 8_000))
            .collect();
        for t in CUSTOM {
            let d = dabs(t, &pts, 10.0);
            let last = d.last().unwrap();
            assert!(last.x > 99_000.0, "{t:?} 長線被截斷在 {}", last.x);
        }
    }
}
