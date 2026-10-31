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
#[derive(Clone, Debug)]
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
    /// 筆桿傾角（弧度，0 = 垂直）。炭筆、蠟筆與毛筆側著畫時筆觸變寬（側鋒）。
    tilt: f32,
    /// 筆桿方位角（弧度）。
    azimuth: f32,
    /// 筆桿繞自身軸旋轉角（弧度）。
    roll: f32,
    /// 行進速度（頁面單位／毫秒）。噴槍走得慢就噴得多；毛筆疾細徐粗。
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
        azimuth: p.azimuth,
        roll: p.roll,
        speed: 1.0,
        heading,
        progress,
    }
}

/// 筆畫進度（`Sample::progress`）怎麼算。
#[derive(Clone, Copy, Debug)]
enum Progress {
    /// 整筆已知：走過的長度 ÷ 總長。
    Total(f32),
    /// 正在畫、總長未知：走過的長度 ÷ 參考長度，封頂在 [`LIVE_PROGRESS_CAP`]。
    /// 不封頂的話，筆畫還沒寫完就先套上收筆出鋒、顏料用盡 —— 而且算過的筆點會隨總長一直變。
    Live(f32),
}

/// 即時筆畫的進度上限：停在筆畫「中段」，起筆的入鋒照常，收筆效果留到抬筆再算。
const LIVE_PROGRESS_CAP: f32 = 0.5;

impl Progress {
    fn at(self, walked: f32) -> f32 {
        match self {
            Self::Total(total) => (walked / total).clamp(0.0, 1.0),
            Self::Live(reference) => (walked / reference).clamp(0.0, LIVE_PROGRESS_CAP),
        }
    }
}

/// 沿折線每隔 `spacing` 取一個樣，**一段一段餵**。
///
/// 狀態（上一段剩下的距離、走過的長度、方向）都留在這裡，所以整筆一次算完與
/// 邊畫邊算（每來幾個點算一次）取到的是同一串樣本 —— 即時筆畫靠它只算新增的那一段。
#[derive(Clone, Debug)]
struct Sampler {
    spacing: f32,
    progress: Progress,
    /// 上一段剩下、還沒走到下一個取樣位置的距離
    carried: f32,
    walked: f32,
    heading: f32,
    /// 上一個取出的樣本（位置與速度）：決定尾端要不要補最後一點。
    last: Option<(f32, f32, f32)>,
}

impl Sampler {
    fn new(spacing: f32, progress: Progress) -> Self {
        Self {
            spacing,
            progress,
            carried: 0.0,
            walked: 0.0,
            heading: 0.0,
            last: None,
        }
    }

    fn segment(&mut self, a: InkPoint, b: InkPoint, emit: &mut impl FnMut(Sample)) {
        let seg = ((b.x - a.x).powi(2) + (b.y - a.y).powi(2)).sqrt();
        if seg <= f32::EPSILON {
            return;
        }
        self.heading = (b.y - a.y).atan2(b.x - a.x);
        // 這一段的速度：距離 ÷ 時間（`dt_us` 是距前一點的微秒差）。沒有時間資訊就當作中速。
        let speed = if b.dt_us > 0 {
            (seg / (b.dt_us as f32 / 1000.0)).clamp(0.02, 20.0)
        } else {
            1.0
        };
        let spacing = self.spacing;
        let mut at = if self.last.is_none() {
            0.0
        } else {
            spacing - self.carried
        };
        while at <= seg {
            let t = at / seg;
            let s = Sample {
                x: a.x + (b.x - a.x) * t,
                y: a.y + (b.y - a.y) * t,
                pressure: a.pressure + (b.pressure - a.pressure) * t,
                tilt: a.tilt + (b.tilt - a.tilt) * t,
                azimuth: a.azimuth + (b.azimuth - a.azimuth) * t,
                roll: a.roll + (b.roll - a.roll) * t,
                speed,
                heading: self.heading,
                progress: self.progress.at(self.walked + at),
            };
            self.last = Some((s.x, s.y, s.speed));
            emit(s);
            at += spacing;
        }
        self.carried = seg - (at - spacing);
        self.walked += seg;
    }

    /// 最後一點：離上一個樣本夠遠（或一個樣本都還沒有）才補上。
    fn trailing(&self, last: InkPoint, progress: f32) -> Option<Sample> {
        if self
            .last
            .is_none_or(|(x, y, _)| (x - last.x).hypot(y - last.y) > self.spacing * 0.25)
        {
            let mut s = point_sample(last, self.heading, progress);
            s.speed = self.last.map_or(1.0, |(_, _, speed)| speed);
            Some(s)
        } else {
            None
        }
    }
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
    if tool == Tool::Brush
        && let Some(dot) = chinese_brush_dot(points, base_width)
    {
        return dot;
    }
    let mut emitter = Emitter::new(tool, base_width, &mut rng);
    let mut out = Vec::new();
    // 單點或原地不動：只取那一點。
    let total: f32 = points
        .windows(2)
        .map(|w| ((w[1].x - w[0].x).powi(2) + (w[1].y - w[0].y).powi(2)).sqrt())
        .sum();
    if points.len() == 1 || total <= f32::EPSILON {
        emitter.emit(point_sample(points[0], 0.0, 0.0), &mut out);
        return out;
    }
    let spacing = emitter.spacing().max(total / MAX_DABS as f32).max(0.05);
    let mut sampler = Sampler::new(spacing, Progress::Total(total));
    for w in points.windows(2) {
        sampler.segment(w[0], w[1], &mut |s| emitter.emit(s, &mut out));
    }
    if let Some(s) = sampler.trailing(points[points.len() - 1], 1.0) {
        emitter.emit(s, &mut out);
    }
    out
}

/// 正在畫的一筆：**邊畫邊算**筆點陣，每次只算新來的那一段。
///
/// 整筆重算的成本隨筆畫長度增加：寫得越久、越快，每一幀要重算的筆點越多，
/// 筆跡就越追不上筆尖（實機回報「寫得越快、後面的字出現得越慢」）。這裡把取樣與筆刷
/// 的狀態留著，新點進來只算新的段落，已經算出的筆點**定案、不再變動** ——
/// 各平台可以把它們直接畫進畫面，不必每幀重畫整筆。
///
/// 與 [`dabs`] 的差別只在「還不知道筆畫多長」：
/// - 進度以參考長度計、停在中段（見 [`Progress::Live`]），收筆出鋒與顏料用盡等抬筆後由 [`dabs`] 整筆重算；
/// - 亂數只取第一點（[`dabs`] 還混了點數，點數一變全部顆粒都會重抖）。
#[derive(Clone, Debug)]
pub struct LiveDabs {
    tool: Tool,
    base_width: f32,
    line: LineState,
    stroke: Option<LiveStroke>,
}

#[derive(Clone, Debug)]
struct LiveStroke {
    emitter: Emitter,
    sampler: Sampler,
    last_point: InkPoint,
}

impl LiveDabs {
    pub fn new(tool: Tool, base_width: f32, line_type: LineType) -> Self {
        Self {
            tool,
            base_width,
            line: LineState::new(line_type),
            stroke: None,
        }
    }

    /// 自繪引擎畫得出這支筆嗎？畫不出來的話 [`push`](Self::push) 與 [`preview`](Self::preview) 永遠是空的。
    fn active(&self) -> bool {
        self.tool.is_custom_engine() && self.base_width > 0.0
    }

    /// 餵入真實的取樣點，回傳**新定案**的筆點（之前回傳過的不會再出現、也不會再變）。
    pub fn push(&mut self, points: &[InkPoint]) -> Vec<Dab> {
        let mut out = Vec::new();
        if !self.active() || points.is_empty() {
            return out;
        }
        let mut rest = points;
        if self.stroke.is_none() {
            let first = points[0];
            let mut rng = Rng::new(seed_of(&points[..1]));
            let emitter = Emitter::new(self.tool, self.base_width, &mut rng);
            let reference = (self.base_width * 48.0).max(96.0);
            let sampler = Sampler::new(emitter.spacing().max(0.05), Progress::Live(reference));
            self.stroke = Some(LiveStroke {
                emitter,
                sampler,
                last_point: first,
            });
            rest = &points[1..];
        }
        let Some(stroke) = self.stroke.as_mut() else {
            return out;
        };
        for &p in rest {
            let a = stroke.last_point;
            let emitter = &mut stroke.emitter;
            stroke
                .sampler
                .segment(a, p, &mut |s| emitter.emit(s, &mut out));
            stroke.last_point = p;
        }
        self.line.apply(out)
    }

    /// 尚未定案的尾巴：最後一個樣本到筆尖（含預測點）。**不改變狀態** —— 每一幀換一份。
    pub fn preview(&self, predicted: &[InkPoint]) -> Vec<Dab> {
        let mut out = Vec::new();
        let Some(live) = self.stroke.as_ref() else {
            return out;
        };
        let mut stroke = live.clone();
        let line = self.line.clone();
        for &p in predicted {
            let a = stroke.last_point;
            let emitter = &mut stroke.emitter;
            stroke
                .sampler
                .segment(a, p, &mut |s| emitter.emit(s, &mut out));
            stroke.last_point = p;
        }
        let progress = stroke.sampler.progress.at(stroke.sampler.walked);
        if let Some(s) = stroke.sampler.trailing(stroke.last_point, progress) {
            stroke.emitter.emit(s, &mut out);
        }
        line.apply_in_place(out)
    }
}

/// 工程線型的走法（見 [`apply_line_type`]），可以一段一段餵。
#[derive(Clone, Debug)]
struct LineState {
    pattern: &'static [f32],
    step: usize,
    left: f32,
    prev: Option<(f32, f32)>,
}

impl LineState {
    fn new(line_type: LineType) -> Self {
        let pattern = line_type.pattern();
        Self {
            pattern,
            step: 0,
            left: pattern.first().copied().unwrap_or(0.0),
            prev: None,
        }
    }

    fn apply(&mut self, dabs: Vec<Dab>) -> Vec<Dab> {
        if self.pattern.is_empty() || dabs.is_empty() {
            return dabs;
        }
        let mut out = Vec::with_capacity(dabs.len());
        for dab in dabs {
            let prev = self.prev.unwrap_or((dab.x, dab.y));
            let mut travel = ((dab.x - prev.0).powi(2) + (dab.y - prev.1).powi(2)).sqrt();
            self.prev = Some((dab.x, dab.y));
            while travel > self.left {
                travel -= self.left;
                self.step = (self.step + 1) % self.pattern.len();
                self.left = self.pattern[self.step];
            }
            self.left -= travel;
            if self.step.is_multiple_of(2) {
                out.push(dab);
            }
        }
        out
    }

    fn apply_in_place(mut self, dabs: Vec<Dab>) -> Vec<Dab> {
        self.apply(dabs)
    }
}

/// 依工程線型挖掉間隔：沿筆畫的**累積長度**走圖樣，「空」的那段不畫。
///
/// 實線原樣回傳。圖樣從筆畫起點重新開始 —— 手繪的線每一條都從「畫」開始，
/// 與製圖規範一致（線的端點是畫的，不是空的）。
pub fn apply_line_type(dabs: Vec<Dab>, line_type: LineType) -> Vec<Dab> {
    LineState::new(line_type).apply(dabs)
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

/// 每支筆刷「拿到一個樣本、吐出筆點」的狀態。整筆一次算與邊畫邊算共用同一份。
#[derive(Clone, Debug)]
struct Emitter {
    kind: EmitterKind,
    /// 起筆積墨：第一個筆點前面再墊一個稍大的（針筆、毛筆、書法筆）。
    first_dab_pending: bool,
}

#[derive(Clone, Debug)]
enum EmitterKind {
    Fineliner {
        r: f32,
    },
    ChineseBrush(ChineseBrush),
    Calligraphy {
        long: f32,
        short: f32,
        default_nib: f32,
    },
    Charcoal {
        base: f32,
        spacing: f32,
        rng: Rng,
    },
    Crayon {
        base: f32,
        spacing: f32,
        seed: f32,
        rng: Rng,
    },
    Airbrush {
        radius: f32,
        spacing: f32,
        rng: Rng,
    },
    OilPaint(OilPaint),
    /// 不是自繪引擎的筆：什麼都不畫。
    None,
}

impl Emitter {
    fn new(tool: Tool, width: f32, rng: &mut Rng) -> Self {
        let kind = match tool {
            Tool::Fineliner => EmitterKind::Fineliner {
                r: (width * 0.5 * 0.6).max(0.4),
            },
            Tool::Brush => EmitterKind::ChineseBrush(ChineseBrush::new(width, rng.clone())),
            Tool::Calligraphy => EmitterKind::Calligraphy {
                long: width * 0.5 * 1.4,
                short: (width * 0.5 * 0.16).max(0.3),
                default_nib: 40.0f32.to_radians(),
            },
            Tool::Charcoal => {
                let base = width * 0.5;
                EmitterKind::Charcoal {
                    base,
                    spacing: (base * 0.2).max(0.55),
                    rng: rng.clone(),
                }
            }
            Tool::Crayon => {
                let base = width * 0.5;
                let seed = rng.unit() * 1000.0;
                EmitterKind::Crayon {
                    base,
                    spacing: (base * 0.17).max(0.55),
                    seed,
                    rng: rng.clone(),
                }
            }
            Tool::Airbrush => {
                let radius = width * 0.5 * 1.3;
                EmitterKind::Airbrush {
                    radius,
                    spacing: (radius * 0.12).max(0.5),
                    rng: rng.clone(),
                }
            }
            Tool::OilPaint => EmitterKind::OilPaint(OilPaint::new(width, rng)),
            _ => EmitterKind::None,
        };
        let first_dab_pending = matches!(
            kind,
            EmitterKind::Fineliner { .. }
                | EmitterKind::ChineseBrush(_)
                | EmitterKind::Calligraphy { .. }
        );
        Self {
            kind,
            first_dab_pending,
        }
    }

    /// 取樣間距。
    fn spacing(&self) -> f32 {
        match &self.kind {
            EmitterKind::Fineliner { r } => r * 0.35,
            EmitterKind::ChineseBrush(b) => (b.base * 0.18).max(0.35),
            EmitterKind::Calligraphy { short, .. } => short.max(0.4),
            EmitterKind::Charcoal { spacing, .. }
            | EmitterKind::Crayon { spacing, .. }
            | EmitterKind::Airbrush { spacing, .. } => *spacing,
            EmitterKind::OilPaint(o) => (o.bristle_r * 0.55).max(0.5),
            EmitterKind::None => 1.0,
        }
    }

    fn emit(&mut self, s: Sample, out: &mut Vec<Dab>) {
        let start = out.len();
        match &mut self.kind {
            EmitterKind::Fineliner { r } => out.push(Dab {
                x: s.x,
                y: s.y,
                rx: *r,
                ry: *r,
                angle: 0.0,
                alpha: 1.0,
                softness: 0.0,
                shade: 0.0,
            }),
            EmitterKind::ChineseBrush(b) => b.emit(s, out),
            EmitterKind::Calligraphy {
                long,
                short,
                default_nib,
            } => {
                let p = s.pressure.clamp(0.0, 1.0);
                let k = 0.58 + 0.58 * p.powf(0.85);
                let nib = if s.roll.abs() > 0.01 {
                    s.roll
                } else {
                    *default_nib
                };
                out.push(Dab {
                    x: s.x,
                    y: s.y,
                    rx: *long * k,
                    ry: *short * (0.85 + 0.30 * p),
                    angle: nib,
                    alpha: (0.88 + 0.12 * p).min(1.0),
                    softness: 0.0,
                    shade: -0.08 * p,
                });
            }
            EmitterKind::Charcoal { base, spacing, rng } => charcoal(s, *base, *spacing, rng, out),
            EmitterKind::Crayon {
                base,
                spacing,
                seed,
                rng,
            } => crayon(s, *base, *spacing, *seed, rng, out),
            EmitterKind::Airbrush { radius, rng, .. } => airbrush(s, *radius, rng, out),
            EmitterKind::OilPaint(o) => o.emit(s, out),
            EmitterKind::None => {}
        }
        if self.first_dab_pending && out.len() > start {
            self.first_dab_pending = false;
            let first = out[start];
            let lead = match &self.kind {
                EmitterKind::Fineliner { r } => Dab {
                    rx: *r * 1.18,
                    ry: *r * 1.18,
                    ..first
                },
                EmitterKind::Calligraphy { .. } => Dab {
                    rx: first.rx * 1.12,
                    ry: first.ry * 1.5,
                    ..first
                },
                // 起筆藏鋒蓄墨點（使起筆第一點更具立體墨韻）
                _ => Dab {
                    rx: first.rx * 1.14,
                    ry: first.ry * 1.14,
                    alpha: (first.alpha * 0.95).clamp(0.1, 1.0),
                    ..first
                },
            };
            out.insert(start, lead);
        }
    }
}

/// 東方軟毫毛筆「側」法（瓜子點）：單點或極短點觸，自動生成由尖入肚的 42° 水滴形筆觸。
/// 不是點觸回傳 `None`，照一般筆畫算。
fn chinese_brush_dot(points: &[InkPoint], width: f32) -> Option<Vec<Dab>> {
    let base = (width * 0.5).max(0.45);
    let total_len: f32 = points
        .windows(2)
        .map(|w| ((w[1].x - w[0].x).powi(2) + (w[1].y - w[0].y).powi(2)).sqrt())
        .sum();

    // 「側」法（點）：單點或極短點觸，自動生成由尖入肚的 42° 瓜子點（水滴形筆觸）
    if points.len() == 1 || total_len <= base * 0.35 {
        let p0 = points[0];
        let p = p0.pressure.clamp(0.15, 1.0);
        let belly = base * (0.45 + 1.15 * p.powf(1.2));
        let angle = if p0.azimuth.abs() > 0.01 {
            p0.azimuth
        } else {
            42.0f32.to_radians()
        };
        let (dx, dy) = (angle.cos(), angle.sin());
        let steps = [
            (-0.32, 0.28, 0.24, 0.92, 0.06),
            (-0.14, 0.55, 0.48, 0.96, 0.08),
            (0.04, 0.88, 0.76, 1.00, 0.10),
            (0.20, 1.05, 0.92, 0.98, 0.12),
            (0.30, 0.78, 0.74, 0.90, 0.16),
        ];
        return Some(
            steps
                .into_iter()
                .map(|(offset, rx_k, ry_k, alpha, softness)| Dab {
                    x: p0.x + dx * belly * offset,
                    y: p0.y + dy * belly * offset,
                    rx: (belly * rx_k).max(0.25),
                    ry: (belly * ry_k).max(0.25),
                    angle,
                    alpha,
                    softness,
                    shade: -0.08 * p,
                })
                .collect(),
        );
    }
    None
}

/// 東方軟毫毛筆（永字八法物理筆觸引擎：側、勒、努、趯、策、掠、啄、磔）。
///
/// - **側（瓜子點）**：單點輕觸或極短落筆時，自動由左上入鋒細尖向右下頓筆鋪毫收圓肚，形成水滴狀瓜子點（見 [`chinese_brush_dot`]）；
/// - **軟毫大跨度壓感（0.14x ~ 1.85x）**：非線性 S 曲線，輕觸游絲細鋒、重按筆肚飽滿鋪開；
/// - **起筆藏鋒／頓筆與折釵股**：入筆微駐與轉折夾角處自動微頓蓄墨；
/// - **行筆中鋒骨力（勒、努）與疾掠飛白（策、掠、啄）**：中速沉穩渾厚，高速疾掠時筆肚收勁並沿紙紋分岔出飛白絲紋；
/// - **收筆出鋒 vs 垂露（趯、策、掠、磔）**：尾段加速掠出時指數收尖出鋒，慢速駐收則成圓潤垂露；
/// - **側鋒鋪毫**：筆桿傾斜（`tilt`）時筆肚橫向鋪寬。
#[derive(Clone, Debug)]
struct ChineseBrush {
    base: f32,
    rng: Rng,
    /// 上一個樣本的行進方向；第一個樣本沿用自己的方向（轉折量為 0）。
    prev_heading: Option<f32>,
    idx: usize,
}

impl ChineseBrush {
    fn new(width: f32, rng: Rng) -> Self {
        Self {
            base: (width * 0.5).max(0.45),
            rng,
            prev_heading: None,
            idx: 0,
        }
    }

    fn emit(&mut self, s: Sample, out: &mut Vec<Dab>) {
        let base = self.base;
        let idx = self.idx;
        let rng = &mut self.rng;
        let mut prev_heading = self.prev_heading.unwrap_or(s.heading);
        {
            let p = s.pressure.clamp(0.0, 1.0);
            // 軟毫非線性壓感：極輕觸 0.14x（毫尖游絲），重按 1.85x（筆肚徹底鋪開）
            let pressure_belly = 0.14 + 1.71 * p.powf(1.32);

            // 行筆速度骨力：慢速駐留渾厚（1.18x），高速疾掠勁瘦（0.68x）
            let vel_factor = (1.16 - 0.11 * (s.speed - 1.0)).clamp(0.68, 1.18);

            // 轉折頓挫（折釵股）：計算方向變化量，轉折處自動微頓加粗
            let mut turn_diff = (s.heading - prev_heading).abs();
            if turn_diff > std::f32::consts::PI {
                turn_diff = std::f32::consts::TAU - turn_diff;
            }
            prev_heading = s.heading;
            let corner_boost = if idx > 0 && turn_diff > 0.35 {
                1.0 + (turn_diff / std::f32::consts::PI).clamp(0.0, 0.32)
            } else {
                1.0
            };

            // 起筆藏鋒／頓筆與收筆出鋒（趯、策、掠、啄、磔）或垂露
            let envelope = if s.progress < 0.08 {
                let t = (s.progress / 0.08).clamp(0.0, 1.0);
                // 慢速入筆形成飽滿頓筆頭；快速露鋒由尖漸入
                let entry_floor = if s.speed < 0.9 { 0.72 } else { 0.28 };
                entry_floor + (1.0 - entry_floor) * smooth(t)
            } else if s.progress > 0.78 {
                let rem = ((1.0 - s.progress) / 0.22).clamp(0.0, 1.0);
                // 尾段加速掠出或輕壓時指數出鋒（懸針／撇捺鋒芒）；慢速重按則收成圓潤垂露
                if s.speed > 1.15 || p < 0.38 {
                    (rem.powf(1.65)).max(0.06)
                } else {
                    0.52 + 0.48 * smooth(rem)
                }
            } else {
                1.0
            };

            // 側鋒鋪毫：筆桿傾斜時橫向展開
            let tilt_spread = side_of_stick(s.tilt, 0.85);
            let r_core = (base * pressure_belly * vel_factor * corner_boost * envelope).max(0.22);
            let rx = (r_core * (1.12 + 0.18 * p)).max(0.25);
            let ry = (r_core * tilt_spread * 0.92).max(0.22);

            // 疾掠飛白（高速或長筆尾段枯筆時，紙紋凸起處留白、凹谷留墨）
            let dry_ness =
                ((s.speed - 2.0) * 0.22 + (s.progress - 0.65).max(0.0) * 0.55).clamp(0.0, 0.75);
            let grain = paper_grain(s.x, s.y);
            let core_alpha = if dry_ness > 0.15 && grain > (1.05 - dry_ness * 0.55) {
                (0.45 + 0.45 * p) * (1.0 - dry_ness * 0.65)
            } else {
                (0.84 + 0.16 * p).min(1.0)
            };

            // 主筆肚中鋒筆點（側鋒時結合筆桿方位角 `azimuth` 偏轉筆肚）
            let dab_angle = if s.tilt > 0.25 && s.azimuth.abs() > 0.01 {
                s.heading * 0.75 + s.azimuth * 0.25
            } else {
                s.heading
            };
            out.push(Dab {
                x: s.x,
                y: s.y,
                rx,
                ry,
                angle: dab_angle,
                alpha: core_alpha.clamp(0.08, 1.0),
                softness: (0.08 + 0.08 * (1.0 - p)).clamp(0.04, 0.22),
                shade: (-0.06 - 0.12 * p * corner_boost).clamp(-1.0, 1.0),
            });

            // 副毫與飛白絲紋：重壓鋪毫或高速飛白時，在筆肚兩側產生毫芒分縷質感
            if p > 0.35 || dry_ness > 0.12 {
                let (nx, ny) = (-s.heading.sin(), s.heading.cos());
                for side in [-1.0f32, 1.0f32] {
                    let jitter = 0.55 + 0.25 * rng.unit();
                    let off = side * ry * jitter * 0.65;
                    let (bx, by) = (s.x + nx * off, s.y + ny * off);
                    let bg = paper_grain(bx, by);
                    if dry_ness > 0.12 && bg > (0.88 - dry_ness * 0.45) {
                        continue;
                    }
                    let bristle_r = (ry * (0.28 + 0.18 * p)).max(0.18);
                    out.push(Dab {
                        x: bx,
                        y: by,
                        rx: (rx * 0.75).max(0.22),
                        ry: bristle_r,
                        angle: s.heading,
                        alpha: (core_alpha * (0.55 + 0.35 * (1.0 - dry_ness))).clamp(0.05, 1.0),
                        softness: 0.14,
                        shade: (0.06 - 0.14 * p).clamp(-1.0, 1.0),
                    });
                }
            }
        }
        self.prev_heading = Some(prev_heading);
        self.idx += 1;
    }
}

/// 炭筆：顆粒**沿著紙的紋理**積下來。
///
/// - 紙纖維的凹谷才吃得到炭 —— 輕壓只有最深的谷有顆粒，重壓才連成一片；
/// - 筆觸邊緣是毛的（越靠邊越稀）；
/// - 側著拿（傾角大）是整支炭條的側面在畫，筆觸變得很寬；
/// - 周圍飄一圈極淡的炭粉。
fn charcoal(s: Sample, base: f32, spacing: f32, rng: &mut Rng, out: &mut Vec<Dab>) {
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

/// 蠟筆：蠟**積在紙的凸起上**，凹谷留白；重壓才把縫填滿、帶一點蠟的光澤。
///
/// 跟炭筆最大的差別：蠟是不透明的、顆粒較大，而且順著筆畫方向有一條一條的**條紋**
/// （蠟筆尖有微小的缺口，拖過去留下平行的紋）。
fn crayon(s: Sample, base: f32, spacing: f32, seed: f32, rng: &mut Rng, out: &mut Vec<Dab>) {
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

/// 噴槍：很淡的柔邊大圓疊成漸層，外加細碎的噴點。**走得慢噴得多** —— 停在原地會越來越濃。
fn airbrush(s: Sample, radius: f32, rng: &mut Rng, out: &mut Vec<Dab>) {
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

/// 油畫筆：九根鬃毛橫跨筆寬，每根各有深淺與沾顏料的量，拖出一條條有**厚度**的紋 ——
/// 每根鬃毛留下的顏料有受光與背光的一側（亮邊、暗邊），看起來像堆起來的顏料。
/// 顏料會用完：筆畫越到尾巴越乾，**乾刷**時紙的紋理露出來。
#[derive(Clone, Debug)]
struct OilPaint {
    half: f32,
    bristle_r: f32,
    bristles: Vec<(f32, f32, f32)>,
}

impl OilPaint {
    fn new(width: f32, rng: &mut Rng) -> Self {
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
        Self {
            half,
            bristle_r,
            bristles,
        }
    }

    fn emit(&mut self, s: Sample, out: &mut Vec<Dab>) {
        let (half, bristle_r, bristles) = (self.half, self.bristle_r, &self.bristles);
        let p = pressure_scale(s.pressure);
        let (nx, ny) = (-s.heading.sin(), s.heading.cos());
        // 起筆收筆時筆觸較窄。
        let ends = (s.progress.min(1.0 - s.progress) * 12.0).clamp(0.4, 1.0);
        // 顏料越畫越少。
        let depletion = 1.0 - 0.6 * s.progress.powf(1.5);
        for &(t, shade, load) in bristles.iter() {
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
}

#[cfg(test)]
pub(crate) fn golden_strokes() -> Vec<Vec<InkPoint>> {
    let mut out = Vec::new();
    // 單點、原地不動、短點、正常曲線、快速長筆、含傾角與旋轉的筆。
    out.push(vec![InkPoint::new(40.0, 40.0, 0.6, 0)]);
    out.push(vec![
        InkPoint::new(40.0, 40.0, 0.6, 0),
        InkPoint::new(40.0, 40.0, 0.7, 8_000),
    ]);
    out.push(vec![
        InkPoint::new(40.0, 40.0, 0.6, 0),
        InkPoint::new(41.0, 40.5, 0.7, 8_000),
    ]);
    out.push(
        (0..40)
            .map(|i| {
                let t = i as f32 * 0.21;
                InkPoint::new(
                    30.0 + i as f32 * 4.5,
                    80.0 + t.sin() * 14.0,
                    0.2 + 0.7 * (t * 0.5).sin().abs(),
                    8_000,
                )
            })
            .collect(),
    );
    out.push(
        (0..120)
            .map(|i| {
                let t = i as f32 * 0.09;
                InkPoint::new(
                    20.0 + t.cos() * 90.0 + i as f32 * 2.0,
                    200.0 + (t * 1.7).sin() * 60.0,
                    0.9 - 0.006 * i as f32,
                    2_000 + (i % 7) as u32 * 900,
                )
            })
            .collect(),
    );
    out.push(
        (0..30)
            .map(|i| {
                let mut p =
                    InkPoint::new(300.0 + i as f32 * 3.0, 300.0 - i as f32 * 2.0, 0.55, 4_000);
                p.tilt = 0.9;
                p.azimuth = 1.2;
                p.roll = 0.4 + i as f32 * 0.01;
                p
            })
            .collect(),
    );
    out
}

#[cfg(test)]
pub(crate) fn golden_hash(d: &[Dab]) -> u64 {
    let mut h: u64 = 0xcbf2_9ce4_8422_2325;
    let mut eat = |v: f32| {
        for b in v.to_bits().to_le_bytes() {
            h ^= b as u64;
            h = h.wrapping_mul(0x0100_0000_01b3);
        }
    };
    eat(d.len() as f32);
    for x in d {
        eat(x.x);
        eat(x.y);
        eat(x.rx);
        eat(x.ry);
        eat(x.angle);
        eat(x.alpha);
        eat(x.softness);
        eat(x.shade);
    }
    h
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

    const CUSTOM: [Tool; 7] = [
        Tool::Brush,
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
        for tool in [Tool::Brush, Tool::Fineliner, Tool::Calligraphy] {
            let d = dabs(tool, &line(10, 0.8), 8.0);
            assert!(
                d[0].rx > d[1].rx || d[0].ry > d[1].ry,
                "{tool:?} 起筆沒有積墨"
            );
        }
    }

    #[test]
    fn chinese_brush_models_eight_methods_of_yong() {
        // 1. 「側」法（瓜子點）：單點落筆產生由細尖入圓肚的水滴點群，而非單一呆板圓點
        let dot = dabs(Tool::Brush, &[InkPoint::new(30.0, 30.0, 0.75, 0)], 10.0);
        assert!(dot.len() >= 4, "單點應展開為瓜子點筆群：{}", dot.len());
        assert!(
            dot[3].rx > dot[0].rx * 2.5,
            "瓜子點應由細尖（{}）漸入飽滿筆肚（{}）",
            dot[0].rx,
            dot[3].rx
        );

        // 2. 軟毫大跨度壓感：重按與輕提的筆觸寬度跨度遠大於硬筆
        let light = dabs(Tool::Brush, &line(16, 0.08), 10.0);
        let heavy = dabs(Tool::Brush, &line(16, 0.95), 10.0);
        let max_light = light.iter().map(|d| d.ry).fold(0.0f32, f32::max);
        let max_heavy = heavy.iter().map(|d| d.ry).fold(0.0f32, f32::max);
        assert!(
            max_heavy > max_light * 4.5,
            "軟毫毛筆重壓（{max_heavy}）應顯著寬於輕提游絲（{max_light}）"
        );

        // 3. 收筆出鋒（掠、策、趯）：快速收筆尾端指數收尖
        let fast_flick: Vec<InkPoint> = (0..18)
            .map(|i| {
                let p = if i < 12 { 0.75 } else { 0.15 };
                let dt = if i < 12 { 10_000 } else { 1_500 };
                InkPoint::new(10.0 + i as f32 * 6.0, 40.0, p, dt)
            })
            .collect();
        let flick_dabs = dabs(Tool::Brush, &fast_flick, 10.0);
        let mid_rx = flick_dabs[flick_dabs.len() / 3].rx;
        let tip_rx = flick_dabs.last().unwrap().rx;
        assert!(
            tip_rx < mid_rx * 0.45,
            "出鋒尾端（{tip_rx}）應比行筆中段（{mid_rx}）銳利收尖"
        );
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

#[cfg(test)]
mod streaming_tests {
    use super::*;

    const CUSTOM: [Tool; 7] = [
        Tool::Brush,
        Tool::Fineliner,
        Tool::Charcoal,
        Tool::Crayon,
        Tool::Airbrush,
        Tool::OilPaint,
        Tool::Calligraphy,
    ];

    /// 整筆算繪的輸出在「改成串流」前後逐位元相同 —— 既有筆記裡的筆畫不會因此換一個樣子。
    #[test]
    fn final_dabs_are_bit_identical_to_the_pre_streaming_engine() {
        let golden: [(Tool, [u64; 6]); 7] = [
            (
                Tool::Brush,
                [
                    0x29ce3b01a0c45c71,
                    0x29ce3b01a0c45c71,
                    0x29ce3b01a0c45c71,
                    0xc95882e36852ac82,
                    0x3b32ab7ed1108d44,
                    0x8392f5e87e5a1181,
                ],
            ),
            (
                Tool::Fineliner,
                [
                    0x7174058e97c1be71,
                    0x7174058e97c1be71,
                    0x5b96666b627b1d87,
                    0x783cd6fba23a78dd,
                    0xde5767b251da6524,
                    0xd4f0aefabe197162,
                ],
            ),
            (
                Tool::Charcoal,
                [
                    0xeaec0b180c05e34b,
                    0xcc2512769bcf65ef,
                    0x5e67875c2928023d,
                    0x202677c36c04e62f,
                    0x9e713406299ee3ca,
                    0x41eb0138824a6202,
                ],
            ),
            (
                Tool::Crayon,
                [
                    0x19265d4c9dd257cf,
                    0x963381c64b05743f,
                    0x170df11ee93067b4,
                    0x25caf8b659281cd0,
                    0xa83955023c3fff4a,
                    0x918804e24d2172e5,
                ],
            ),
            (
                Tool::Airbrush,
                [
                    0xe0924533e4feaaf2,
                    0xe9fd5b86c74d7ce8,
                    0xe6848997fb369688,
                    0xd5aff35882dff4a5,
                    0xb17826d4b8e00fea,
                    0x6392bb69a1f94c67,
                ],
            ),
            (
                Tool::OilPaint,
                [
                    0xe9319a1550d5517e,
                    0x039859c609d98e5f,
                    0x4f00a62d5cf2a310,
                    0xf227b07b6778b051,
                    0x556f71d6743073b6,
                    0x342c3c27782ca2cd,
                ],
            ),
            (
                Tool::Calligraphy,
                [
                    0x9cb2556f523a8279,
                    0x9cb2556f523a8279,
                    0xde7f2e5350e54d90,
                    0xf267f45f91f24716,
                    0x8de0e44f22b82b1f,
                    0xe51db775ccb74d1c,
                ],
            ),
        ];
        let strokes = golden_strokes();
        for (tool, hashes) in golden {
            for (stroke, want) in strokes.iter().zip(hashes) {
                assert_eq!(
                    golden_hash(&dabs(tool, stroke, 7.0)),
                    want,
                    "{tool:?} 整筆算繪的結果變了"
                );
            }
        }
    }

    fn feed(live: &mut LiveDabs, points: &[InkPoint], chunk: usize) -> Vec<Dab> {
        let mut out = Vec::new();
        for part in points.chunks(chunk.max(1)) {
            out.extend(live.push(part));
        }
        out
    }

    /// 一次餵一點、一次餵一把、一次餵全部，定案的筆點都一樣 —— 觸控事件怎麼合併都不影響筆跡。
    #[test]
    fn settled_dabs_do_not_depend_on_how_the_points_arrive() {
        for stroke in golden_strokes() {
            for tool in CUSTOM {
                for line in [LineType::Solid, LineType::Center] {
                    let all = feed(&mut LiveDabs::new(tool, 7.0, line), &stroke, usize::MAX);
                    for chunk in [1, 3, 7] {
                        let got = feed(&mut LiveDabs::new(tool, 7.0, line), &stroke, chunk);
                        assert_eq!(
                            got, all,
                            "{tool:?} {line:?} 每次 {chunk} 點：定案的筆點不同"
                        );
                    }
                }
            }
        }
    }

    /// 預覽不改狀態：預覽幾次、預測點是什麼，之後定案的筆點都一樣。
    #[test]
    fn preview_never_changes_what_gets_settled() {
        let stroke = &golden_strokes()[4];
        for tool in CUSTOM {
            let plain = feed(&mut LiveDabs::new(tool, 7.0, LineType::Solid), stroke, 4);
            let mut live = LiveDabs::new(tool, 7.0, LineType::Solid);
            let mut got = Vec::new();
            for part in stroke.chunks(4) {
                got.extend(live.push(part));
                let last = part[part.len() - 1];
                let guess = [InkPoint::new(last.x + 40.0, last.y - 25.0, 0.5, 4_000)];
                let a = live.preview(&guess);
                assert_eq!(a, live.preview(&guess), "{tool:?} 同一份預覽算兩次不同");
            }
            assert_eq!(got, plain, "{tool:?} 預覽影響了定案的筆點");
        }
    }

    /// 即時筆點（定案＋預覽）都貼著真實軌跡走：不會有從起點拉到筆尖的直線、也不會跑到別處。
    #[test]
    fn live_dabs_stay_on_the_path() {
        let stroke = &golden_strokes()[3];
        for tool in CUSTOM {
            let mut live = LiveDabs::new(tool, 7.0, LineType::Solid);
            for (n, part) in stroke.chunks(5).enumerate() {
                let mut shown = live.push(part);
                shown.extend(live.preview(&[]));
                let seen = &stroke[..((n + 1) * 5).min(stroke.len())];
                for d in &shown {
                    let near = seen
                        .windows(2)
                        .map(|w| distance_to_segment(d.x, d.y, w[0], w[1]))
                        .fold(f32::MAX, f32::min)
                        .min((d.x - seen[0].x).hypot(d.y - seen[0].y));
                    assert!(
                        near < 7.0 * 3.0,
                        "{tool:?} 即時筆點離軌跡太遠：{d:?}（{near}）"
                    );
                }
            }
        }
    }

    fn distance_to_segment(px: f32, py: f32, a: InkPoint, b: InkPoint) -> f32 {
        let (dx, dy) = (b.x - a.x, b.y - a.y);
        let l2 = dx * dx + dy * dy;
        let t = if l2 < 1e-6 {
            0.0
        } else {
            (((px - a.x) * dx + (py - a.y) * dy) / l2).clamp(0.0, 1.0)
        };
        (px - (a.x + t * dx)).hypot(py - (a.y + t * dy))
    }

    /// 剛落筆、筆還沒動：預覽要畫出一個點，不能空白。
    #[test]
    fn a_fresh_touch_shows_a_dot_before_the_pen_moves() {
        for tool in CUSTOM {
            let mut live = LiveDabs::new(tool, 7.0, LineType::Solid);
            let settled = live.push(&[InkPoint::new(50.0, 50.0, 0.6, 0)]);
            assert!(settled.is_empty());
            assert!(!live.preview(&[]).is_empty(), "{tool:?} 落筆當下看不到墨點");
        }
    }

    /// 原生筆刷（PencilKit／平台自己畫的）不產生自繪筆點。
    #[test]
    fn native_tools_stream_nothing() {
        let mut live = LiveDabs::new(Tool::FountainPen, 7.0, LineType::Solid);
        assert!(live.push(&golden_strokes()[3]).is_empty());
        assert!(live.preview(&[]).is_empty());
    }
}
