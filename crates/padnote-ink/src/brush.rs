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

use crate::{InkPoint, LineType, Tool};

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
    /// 筆桿傾角（弧度，0 = 垂直）。炭筆與蠟筆側著畫時筆觸變寬。
    tilt: f32,
    /// 行進速度（頁面單位／毫秒）。噴槍走得慢就噴得多。
    speed: f32,
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

fn point_sample(p: InkPoint, heading: f32, progress: f32) -> Sample {
    Sample {
        x: p.x,
        y: p.y,
        pressure: p.pressure,
        tilt: p.tilt,
        speed: 1.0,
        heading,
        progress,
    }
}

/// 沿折線每隔 `spacing` 取一個樣。第一點與最後一點一定取。
fn resample(points: &[InkPoint], spacing: f32) -> Vec<Sample> {
    let mut out = Vec::new();
    if points.is_empty() {
        return out;
    }
    if points.len() == 1 {
        out.push(point_sample(points[0], 0.0, 0.0));
        return out;
    }
    let mut total = 0.0f32;
    for w in points.windows(2) {
        total += ((w[1].x - w[0].x).powi(2) + (w[1].y - w[0].y).powi(2)).sqrt();
    }
    if total <= f32::EPSILON {
        out.push(point_sample(points[0], 0.0, 0.0));
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
        // 這一段的速度：距離 ÷ 時間（`dt_us` 是距前一點的微秒差）。沒有時間資訊就當作中速。
        let speed = if b.dt_us > 0 {
            (seg / (b.dt_us as f32 / 1000.0)).clamp(0.02, 20.0)
        } else {
            1.0
        };
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
                tilt: a.tilt + (b.tilt - a.tilt) * t,
                speed,
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
        let mut s = point_sample(last, heading, 1.0);
        s.speed = out.last().map_or(1.0, |o| o.speed);
        out.push(s);
    }
    out
}

fn pressure_scale(p: f32) -> f32 {
    0.35 + 0.65 * p.clamp(0.0, 1.0)
}

// ---------------------------------------------------------------------------------------
// 紙紋
// ---------------------------------------------------------------------------------------

/// 格點上的亂數（0–1）。
fn lattice(ix: i32, iy: i32) -> f32 {
    let mut h = (ix as u32).wrapping_mul(0x85EB_CA6B) ^ (iy as u32).wrapping_mul(0xC2B2_AE35);
    h ^= h >> 15;
    h = h.wrapping_mul(0x2C1B_3C6D);
    h ^= h >> 12;
    h = h.wrapping_mul(0x297A_2D39);
    h ^= h >> 15;
    (h >> 8) as f32 / (1u32 << 24) as f32
}

fn smooth(t: f32) -> f32 {
    t * t * (3.0 - 2.0 * t)
}

fn value_noise(x: f32, y: f32) -> f32 {
    let (ix, iy) = (x.floor(), y.floor());
    let (fx, fy) = (smooth(x - ix), smooth(y - iy));
    let (ix, iy) = (ix as i32, iy as i32);
    let top = lattice(ix, iy) + (lattice(ix + 1, iy) - lattice(ix, iy)) * fx;
    let bottom = lattice(ix, iy + 1) + (lattice(ix + 1, iy + 1) - lattice(ix, iy + 1)) * fx;
    top + (bottom - top) * fy
}

/// 紙的紋理：頁面座標 → 0–1。**低的地方是紙纖維的凹谷，顏料先積在那裡；高的是纖維尖，
/// 輕輕畫過去碰不到。** 真的炭筆與蠟筆的顆粒感就是這樣來的：不是隨機的點，而是紙的形狀。
///
/// 只跟位置有關，所以**同一張紙上兩筆畫重疊的地方顆粒一致**（與真的紙一樣），
/// 而且兩個平台、每次重畫都是同一張紙 —— 沒有全域狀態。
pub fn paper_grain(x: f32, y: f32) -> f32 {
    let fine = value_noise(x * 0.95, y * 0.95);
    let mid = value_noise(x * 0.37 + 17.3, y * 0.37 - 9.1);
    let coarse = value_noise(x * 0.13 - 3.7, y * 0.13 + 5.9);
    let g = 0.5 * fine + 0.33 * mid + 0.17 * coarse;
    // 值雜訊的分佈很窄（集中在 0.5 附近），拉開才有「有的地方碰得到、有的碰不到」的反差。
    ((g - 0.5) * 2.4 + 0.5).clamp(0.0, 1.0)
}

/// 側著畫（傾角大）筆觸變寬的倍數。
fn side_of_stick(tilt: f32, amount: f32) -> f32 {
    1.0 + amount * tilt.sin().clamp(0.0, 1.0)
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

/// 依工程線型挖掉間隔：沿筆畫的**累積長度**走圖樣，「空」的那段不畫。
///
/// 實線原樣回傳。圖樣從筆畫起點重新開始 —— 手繪的線每一條都從「畫」開始，
/// 與製圖規範一致（線的端點是畫的，不是空的）。
pub fn apply_line_type(dabs: Vec<Dab>, line_type: LineType) -> Vec<Dab> {
    let pattern = line_type.pattern();
    if pattern.is_empty() || dabs.is_empty() {
        return dabs;
    }
    let mut out = Vec::with_capacity(dabs.len());
    let (mut step, mut left) = (0usize, pattern[0]);
    let mut prev = (dabs[0].x, dabs[0].y);
    for dab in dabs {
        let mut travel = ((dab.x - prev.0).powi(2) + (dab.y - prev.1).powi(2)).sqrt();
        prev = (dab.x, dab.y);
        while travel > left {
            travel -= left;
            step = (step + 1) % pattern.len();
            left = pattern[step];
        }
        left -= travel;
        if step % 2 == 0 {
            out.push(dab);
        }
    }
    out
}

/// 與 [`dabs`] 相同，再套上工程線型。
pub fn dabs_styled(
    tool: Tool,
    points: &[InkPoint],
    base_width: f32,
    line_type: LineType,
) -> Vec<Dab> {
    apply_line_type(dabs(tool, points, base_width), line_type)
}

/// 針筆：等寬、硬邊、不受壓感影響。**起筆時墨水會積一下**，那一點比線略粗。
fn fineliner(points: &[InkPoint], width: f32) -> Vec<Dab> {
    let r = (width * 0.5 * 0.6).max(0.4);
    let mut out: Vec<Dab> = resample(points, r * 0.35)
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
        .collect();
    if let Some(first) = out.first().copied() {
        out.insert(
            0,
            Dab {
                rx: r * 1.18,
                ry: r * 1.18,
                ..first
            },
        );
    }
    out
}

/// 書法扁頭筆：固定 40° 的扁橢圓。筆畫方向與筆頭夾角越大越粗，所以橫細豎粗。起筆積墨。
fn calligraphy(points: &[InkPoint], width: f32) -> Vec<Dab> {
    let long = width * 0.5 * 1.4;
    let short = (width * 0.5 * 0.16).max(0.3);
    let nib = 40.0f32.to_radians();
    let mut out: Vec<Dab> = resample(points, short.max(0.4))
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
        .collect();
    if let Some(first) = out.first().copied() {
        out.insert(
            0,
            Dab {
                rx: first.rx * 1.12,
                ry: first.ry * 1.5,
                ..first
            },
        );
    }
    out
}

/// 炭筆：顆粒**沿著紙的紋理**積下來。
///
/// - 紙纖維的凹谷才吃得到炭 —— 輕壓只有最深的谷有顆粒，重壓才連成一片；
/// - 筆觸邊緣是毛的（越靠邊越稀）；
/// - 側著拿（傾角大）是整支炭條的側面在畫，筆觸變得很寬；
/// - 周圍飄一圈極淡的炭粉。
fn charcoal(points: &[InkPoint], width: f32, rng: &mut Rng) -> Vec<Dab> {
    let base = width * 0.5;
    let spacing = (base * 0.2).max(0.55);
    let mut out = Vec::new();
    for s in resample(points, spacing) {
        let p = pressure_scale(s.pressure);
        let reach = base * side_of_stick(s.tilt, 1.8) * (0.55 + 0.45 * p);
        let count = ((2.0 * reach * spacing) * 0.95 * (0.5 + 0.8 * p))
            .ceil()
            .clamp(1.0, 60.0) as usize;
        let tooth = 0.18 + 0.78 * p;
        for _ in 0..count {
            let angle = rng.unit() * std::f32::consts::TAU;
            let rr = reach * rng.unit().sqrt();
            // 毛邊：越靠外越容易被丟掉。
            if rng.unit() < (rr / reach).powf(2.6) * 0.92 {
                continue;
            }
            let (px, py) = (s.x + angle.cos() * rr, s.y + angle.sin() * rr);
            let g = paper_grain(px, py);
            if g > tooth {
                continue;
            }
            let depth = 1.0 - g / tooth; // 谷越深、顏料越多
            let size = (0.55 + 0.55 * rng.unit()) * (0.85 + 0.15 * side_of_stick(s.tilt, 1.0));
            out.push(Dab {
                x: px,
                y: py,
                rx: size,
                ry: size * (0.6 + 0.4 * rng.unit()),
                angle: rng.unit() * std::f32::consts::PI,
                alpha: ((0.3 + 0.55 * depth) * (0.55 + 0.45 * p)).min(1.0),
                softness: 0.1,
                shade: -0.12 - 0.22 * depth,
            });
        }
        // 飄散的炭粉。
        if rng.unit() < 0.22 {
            out.push(Dab {
                x: s.x + rng.signed() * reach * 0.6,
                y: s.y + rng.signed() * reach * 0.6,
                rx: reach * 0.9,
                ry: reach * 0.9,
                angle: 0.0,
                alpha: 0.022 * p,
                softness: 1.0,
                shade: 0.0,
            });
        }
    }
    out
}

/// 蠟筆：蠟**積在紙的凸起上**，凹谷留白；重壓才把縫填滿、帶一點蠟的光澤。
///
/// 跟炭筆最大的差別：蠟是不透明的、顆粒較大，而且順著筆畫方向有一條一條的**條紋**
/// （蠟筆尖有微小的缺口，拖過去留下平行的紋）。
fn crayon(points: &[InkPoint], width: f32, rng: &mut Rng) -> Vec<Dab> {
    let base = width * 0.5;
    let spacing = (base * 0.17).max(0.55);
    let seed = rng.unit() * 1000.0;
    let mut out = Vec::new();
    for s in resample(points, spacing) {
        let p = pressure_scale(s.pressure);
        let reach = base * side_of_stick(s.tilt, 0.9) * (0.8 + 0.3 * p);
        let count = ((2.0 * reach * spacing) * 1.5 * (0.6 + 0.7 * p))
            .ceil()
            .clamp(1.0, 70.0) as usize;
        // 垂直於行進方向的座標：條紋沿著它變化。
        let (nx, ny) = (-s.heading.sin(), s.heading.cos());
        for _ in 0..count {
            let along = rng.signed();
            let across = rng.signed() * reach;
            if rng.unit() < (across.abs() / reach).powf(3.0) * 0.9 {
                continue;
            }
            let (px, py) = (
                s.x + nx * across + s.heading.cos() * along * spacing,
                s.y + ny * across + s.heading.sin() * along * spacing,
            );
            // 條紋：垂直方向每隔一格的深淺不同，整筆畫都一樣。
            let q = (px * nx + py * ny) * 1.15 + seed;
            let streak = value_noise(q, seed * 0.37);
            let g = paper_grain(px, py);
            let tooth = 0.3 + 0.6 * p + 0.16 * (streak - 0.5);
            if g > tooth {
                continue;
            }
            let size = 0.8 + 0.7 * rng.unit();
            let shine = if p > 0.82 { 0.1 } else { 0.0 };
            out.push(Dab {
                x: px,
                y: py,
                rx: size,
                ry: size * (0.8 + 0.2 * rng.unit()),
                angle: 0.0,
                alpha: ((0.55 + 0.4 * p) * (0.86 + 0.14 * streak)).min(1.0),
                softness: 0.05,
                shade: -0.06 + 0.12 * (1.0 - g / tooth) + shine,
            });
        }
    }
    out
}

/// 噴槍：很淡的柔邊大圓疊成漸層，外加細碎的噴點。**走得慢噴得多** —— 停在原地會越來越濃。
fn airbrush(points: &[InkPoint], width: f32, rng: &mut Rng) -> Vec<Dab> {
    let radius = width * 0.5 * 1.3;
    let spacing = (radius * 0.12).max(0.5);
    let mut out = Vec::new();
    for s in resample(points, spacing) {
        let p = pressure_scale(s.pressure);
        // 速度 1 約是正常書寫；慢下來最多噴到 1.5 倍，快速掃過只剩 0.35。
        let flow = (1.5 - 0.9 * s.speed).clamp(0.35, 1.5);
        out.push(Dab {
            x: s.x,
            y: s.y,
            rx: radius * (0.7 + 0.5 * p),
            ry: radius * (0.7 + 0.5 * p),
            angle: 0.0,
            alpha: 0.045 * flow * (0.6 + 0.8 * p),
            softness: 1.0,
            shade: 0.0,
        });
        // 噴點：高斯分佈（三個均勻亂數相加），中心密、外圍稀。
        let speckles = (4.0 * flow * (0.4 + p)).round() as usize;
        for _ in 0..speckles {
            let angle = rng.unit() * std::f32::consts::TAU;
            let g = ((rng.unit() + rng.unit() + rng.unit()) / 3.0 - 0.5).abs() * 2.0; // 0–1，偏向 0
            let d = g * radius * 1.35 * (0.6 + 0.6 * p);
            let size = 0.35 + 0.45 * rng.unit();
            out.push(Dab {
                x: s.x + angle.cos() * d,
                y: s.y + angle.sin() * d,
                rx: size,
                ry: size,
                angle: 0.0,
                alpha: 0.2 + 0.35 * rng.unit(),
                softness: 0.0,
                shade: 0.0,
            });
        }
    }
    out
}

/// 油畫筆：九根鬃毛橫跨筆寬，每根各有深淺與沾顏料的量，拖出一條條有**厚度**的紋 ——
/// 每根鬃毛留下的顏料有受光與背光的一側（亮邊、暗邊），看起來像堆起來的顏料。
/// 顏料會用完：筆畫越到尾巴越乾，**乾刷**時紙的紋理露出來。
fn oil_paint(points: &[InkPoint], width: f32, rng: &mut Rng) -> Vec<Dab> {
    const BRISTLES: usize = 9;
    let half = width * 0.5;
    let bristle_r = (width / BRISTLES as f32 * 0.8).max(0.5);
    // 每根鬃毛固定的偏移、深淺、載量（整筆不變，才會拖出連續的條紋）。
    let bristles: Vec<(f32, f32, f32)> = (0..BRISTLES)
        .map(|i| {
            let t = i as f32 / (BRISTLES - 1) as f32 * 2.0 - 1.0;
            (
                t + rng.signed() * 0.06,
                rng.signed() * 0.4,
                0.8 + 0.2 * rng.unit(),
            )
        })
        .collect();
    let mut out = Vec::new();
    for s in resample(points, (bristle_r * 0.55).max(0.5)) {
        let p = pressure_scale(s.pressure);
        let (nx, ny) = (-s.heading.sin(), s.heading.cos());
        // 起筆收筆時筆觸較窄。
        let ends = (s.progress.min(1.0 - s.progress) * 12.0).clamp(0.4, 1.0);
        // 顏料越畫越少。
        let depletion = 1.0 - 0.6 * s.progress.powf(1.5);
        for &(t, shade, load) in &bristles {
            let off = t * half * (0.5 + 0.5 * p) * ends;
            let (x, y) = (s.x + nx * off, s.y + ny * off);
            let paint = (load * depletion * (0.45 + 0.55 * p)).clamp(0.0, 1.0);
            // 乾刷：顏料少的時候，紙纖維的尖端不吃色。
            if paper_grain(x, y) > 0.3 + 0.7 * paint {
                continue;
            }
            let r = bristle_r * (0.6 + 0.4 * p);
            out.push(Dab {
                x,
                y,
                rx: r,
                ry: r,
                angle: 0.0,
                alpha: (0.55 + 0.4 * paint).min(1.0),
                softness: 0.1,
                shade,
            });
            // 厚度：受光的一側亮、背光的一側暗。
            out.push(Dab {
                x: x - nx * r * 0.6,
                y: y - ny * r * 0.6,
                rx: r * 0.45,
                ry: r * 0.45,
                angle: 0.0,
                alpha: 0.34 * paint,
                softness: 0.2,
                shade: (shade + 0.5).min(1.0),
            });
            out.push(Dab {
                x: x + nx * r * 0.6,
                y: y + ny * r * 0.6,
                rx: r * 0.45,
                ry: r * 0.45,
                angle: 0.0,
                alpha: 0.3 * paint,
                softness: 0.2,
                shade: (shade - 0.5).max(-1.0),
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

    // ---- 真實筆的質地 -------------------------------------------------------------

    #[test]
    fn paper_grain_is_deterministic_and_spread_over_the_whole_range() {
        assert_eq!(paper_grain(12.3, 45.6), paper_grain(12.3, 45.6));
        let values: Vec<f32> = (0..4000)
            .map(|i| paper_grain((i % 80) as f32 * 1.7, (i / 80) as f32 * 1.3))
            .collect();
        assert!(values.iter().all(|v| (0.0..=1.0).contains(v)));
        let below_half = values.iter().filter(|v| **v < 0.5).count() as f32 / values.len() as f32;
        assert!(
            (0.3..0.7).contains(&below_half),
            "紙紋的高低要各佔一半左右，實得 {below_half}"
        );
        let low = values.iter().filter(|v| **v < 0.2).count();
        let high = values.iter().filter(|v| **v > 0.8).count();
        assert!(
            low > 100 && high > 100,
            "要有明顯的凹谷與凸尖，否則顆粒感出不來（{low}/{high}）"
        );
    }

    fn mean_grain(dabs: &[Dab]) -> f32 {
        dabs.iter().map(|d| paper_grain(d.x, d.y)).sum::<f32>() / dabs.len() as f32
    }

    #[test]
    fn charcoal_and_crayon_stick_to_the_valleys_of_the_paper() {
        // 顆粒不是隨機撒的：只落在紙纖維的凹谷。所以顆粒中心的紙紋平均值要明顯低於整張紙。
        let pts = line(40, 0.5);
        for tool in [Tool::Charcoal, Tool::Crayon] {
            let d: Vec<Dab> = dabs(tool, &pts, 12.0)
                .into_iter()
                .filter(|d| d.softness < 0.5)
                .collect();
            assert!(d.len() > 200);
            let m = mean_grain(&d);
            assert!(m < 0.4, "{tool:?} 的顆粒沒有選擇紙紋的凹谷（平均 {m}）");
        }
    }

    #[test]
    fn two_strokes_share_the_same_paper() {
        // 同一張紙，兩筆重疊處的顆粒位置一致：不是每筆各自一把亂數。
        // 壓力 0.5：吃色的門檻跟壓力有關，兩筆要在同樣的壓力下比。
        let a = dabs(Tool::Charcoal, &line(20, 0.5), 10.0);
        let mut shifted = line(20, 0.5);
        for p in &mut shifted {
            p.x += 0.37; // 起點不同 → 亂數序列不同
        }
        let b = dabs(Tool::Charcoal, &shifted, 10.0);
        assert!(
            mean_grain(
                &a.iter()
                    .copied()
                    .filter(|d| d.softness < 0.5)
                    .collect::<Vec<_>>()
            ) < 0.4
        );
        assert!(
            mean_grain(
                &b.iter()
                    .copied()
                    .filter(|d| d.softness < 0.5)
                    .collect::<Vec<_>>()
            ) < 0.4
        );
    }

    #[test]
    fn heavier_pressure_fills_more_of_the_paper() {
        for tool in [Tool::Charcoal, Tool::Crayon] {
            let light = dabs(tool, &line(30, 0.1), 12.0)
                .iter()
                .filter(|d| d.softness < 0.5)
                .count();
            let heavy = dabs(tool, &line(30, 1.0), 12.0)
                .iter()
                .filter(|d| d.softness < 0.5)
                .count();
            assert!(
                heavy > light * 2,
                "{tool:?}：重壓 {heavy} 該明顯多於輕壓 {light}"
            );
        }
    }

    #[test]
    fn holding_the_stick_flat_makes_a_wider_mark() {
        fn spread(d: &[Dab]) -> f32 {
            let (lo, hi) = d
                .iter()
                .fold((f32::MAX, f32::MIN), |(l, h), d| (l.min(d.y), h.max(d.y)));
            hi - lo
        }
        let upright = line(30, 0.8);
        let mut flat = line(30, 0.8);
        for p in &mut flat {
            p.tilt = 1.3;
        }
        for tool in [Tool::Charcoal, Tool::Crayon] {
            let a = spread(&dabs(tool, &upright, 10.0));
            let b = spread(&dabs(tool, &flat, 10.0));
            assert!(b > a * 1.3, "{tool:?}：側著畫（{b}）要比直著畫（{a}）寬");
        }
    }

    #[test]
    fn the_airbrush_sprays_more_when_you_go_slowly() {
        let make = |dt_us: u32| -> Vec<InkPoint> {
            (0..20)
                .map(|i| InkPoint::new(10.0 + i as f32 * 4.0, 50.0, 0.7, dt_us))
                .collect()
        };
        let slow = dabs(Tool::Airbrush, &make(40_000), 10.0).len();
        let fast = dabs(Tool::Airbrush, &make(2_000), 10.0).len();
        assert!(slow > fast, "慢（{slow}）應該比快（{fast}）噴得多");
    }

    #[test]
    fn oil_paint_runs_dry_towards_the_end_of_the_stroke() {
        let d = dabs(Tool::OilPaint, &line(60, 0.8), 14.0);
        let n = d.len();
        let first: f32 = d[..n / 3].iter().map(|d| d.alpha).sum();
        let last: f32 = d[n * 2 / 3..].iter().map(|d| d.alpha).sum();
        assert!(
            last < first * 0.9,
            "顏料會越畫越少：開頭 {first}、結尾 {last}"
        );
    }

    #[test]
    fn oil_paint_bristles_have_a_lit_and_a_shaded_side() {
        let d = dabs(Tool::OilPaint, &line(20, 0.8), 14.0);
        assert!(d.iter().any(|d| d.shade > 0.3), "要有受光的亮邊");
        assert!(d.iter().any(|d| d.shade < -0.3), "要有背光的暗邊");
    }

    #[test]
    fn a_pen_that_starts_a_line_leaves_a_slightly_bigger_ink_pool() {
        for tool in [Tool::Fineliner, Tool::Calligraphy] {
            let d = dabs(tool, &line(10, 0.8), 8.0);
            assert!(
                d[0].rx > d[1].rx || d[0].ry > d[1].ry,
                "{tool:?} 起筆沒有積墨"
            );
        }
    }
}

#[cfg(test)]
mod line_type_tests {
    use super::*;

    fn line(len: f32) -> Vec<InkPoint> {
        vec![
            InkPoint::new(0.0, 0.0, 0.5, 0),
            InkPoint::new(len, 0.0, 0.5, 8_000),
        ]
    }

    fn extent(d: &[Dab]) -> Vec<f32> {
        d.iter().map(|d| d.x).collect()
    }

    #[test]
    fn a_solid_line_keeps_every_dab() {
        let all = dabs(Tool::Fineliner, &line(200.0), 1.4);
        let styled = dabs_styled(Tool::Fineliner, &line(200.0), 1.4, LineType::Solid);
        assert_eq!(all.len(), styled.len());
    }

    #[test]
    fn a_hidden_line_has_gaps_the_size_of_the_pattern() {
        let d = dabs_styled(Tool::Fineliner, &line(200.0), 1.4, LineType::Hidden);
        let xs = extent(&d);
        let mut gaps = Vec::new();
        for pair in xs.windows(2) {
            if pair[1] - pair[0] > 2.0 {
                gaps.push(pair[1] - pair[0]);
            }
        }
        assert!(gaps.len() >= 8, "200 單位的虛線要有很多段：{}", gaps.len());
        for g in gaps {
            assert!((3.0..=5.5).contains(&g), "空隙約 4 單位：{g}");
        }
        assert!(
            xs.first().copied().unwrap() < 1.0,
            "線的起點是畫的，不是空的"
        );
    }

    #[test]
    fn a_centre_line_alternates_long_and_short_dashes() {
        let d = dabs_styled(Tool::Fineliner, &line(300.0), 1.0, LineType::Center);
        let xs = extent(&d);
        let mut runs = Vec::new();
        let mut start = xs[0];
        for pair in xs.windows(2) {
            if pair[1] - pair[0] > 2.0 {
                runs.push(pair[0] - start);
                start = pair[1];
            }
        }
        // 長畫約 46、短畫約 5：第一段明顯比第二段長。
        assert!(runs.len() >= 3);
        assert!(runs[0] > runs[1] * 4.0, "長畫與短畫要交替：{runs:?}");
    }

    #[test]
    fn a_phantom_line_has_two_short_dashes_between_long_ones() {
        let d = dabs_styled(Tool::Fineliner, &line(400.0), 1.0, LineType::Phantom);
        let xs = extent(&d);
        let mut segments = 0;
        for pair in xs.windows(2) {
            if pair[1] - pair[0] > 2.0 {
                segments += 1;
            }
        }
        let centre = dabs_styled(Tool::Fineliner, &line(400.0), 1.0, LineType::Center);
        let centre_gaps = extent(&centre)
            .windows(2)
            .filter(|p| p[1] - p[0] > 2.0)
            .count();
        assert!(segments > centre_gaps, "雙點劃線的間隔比單點劃線多");
    }

    #[test]
    fn unknown_ids_fall_back_to_solid() {
        assert_eq!(LineType::from_id(77), LineType::Solid);
    }
}
