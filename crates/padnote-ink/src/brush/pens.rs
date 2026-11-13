//! ADR-0015 階段 5：書寫與標記類筆刷（鋼筆、原子筆、鉛筆、麥克筆、螢光筆、水彩筆）的筆點陣。
//!
//! 這六支筆原本由各平台的原生繪圖（PencilKit、Android Canvas）各畫各的，外觀因此不同，
//! 筆畫也沒有穩定身分。這裡把它們也展開成筆點陣：兩端只負責把橢圓畫出來，
//! 同一筆在 iPad 與 Android 上是同一張圖。
//!
//! # 手感參數集中在 [`PenTuning`]
//!
//! 壓感曲線、速度變細、收筆長度、顆粒門檻……全部是這個檔案頂端的常數，
//! 實機試寫後只需要改這一處，不必動各支筆的算法。
//!
//! # 群組不透明度
//!
//! 麥克筆與螢光筆整筆是**同一層墨**：自己跟自己重疊的地方不該變深（真的螢光筆也不會）。
//! 所以筆點本身的 `alpha` 一律是 1，整筆畫完再以 [`group_alpha`] 一次疊上去
//! （平台用透明圖層／離屏緩衝實作）。

use super::{Dab, Rng, Sample, paper_grain, smooth};
use crate::Tool;

/// 手感參數。數值都是「頁面單位」或無單位倍率。
#[derive(Debug)]
pub struct PenTuning;

impl PenTuning {
    /// 壓感曲線的指數：> 1 = 輕壓時更細、需要壓重才變粗；< 1 = 反之。
    pub const PRESSURE_GAMMA: f32 = 1.0;
    /// 壓感的最細比例（壓力 0 時的寬度 ÷ 滿壓寬度）。
    pub const PRESSURE_FLOOR: f32 = 0.35;
    /// 鋼筆：走得快時筆畫收細的力道（0 = 不受速度影響）。
    pub const FOUNTAIN_SPEED_THIN: f32 = 0.18;
    /// 鋼筆：寬度對上一個樣本的黏性（0–1，越大越平滑、反應越慢）。
    pub const FOUNTAIN_SMOOTHING: f32 = 0.50;
    /// 鋼筆：收筆出鋒佔整筆長度的比例。
    pub const FOUNTAIN_TAPER: f32 = 0.12;
    /// 原子筆：壓感只影響寬度的幅度（原子筆幾乎等寬）。
    pub const BALLPOINT_PRESSURE_AMOUNT: f32 = 0.18;
    /// 鉛筆：輕壓時能碰到紙紋的門檻下限／上限。
    pub const PENCIL_TOOTH_MIN: f32 = 0.22;
    pub const PENCIL_TOOTH_MAX: f32 = 0.92;
    /// 麥克筆筆頭的扁率與角度。
    pub const MARKER_FLATNESS: f32 = 0.42;
    pub const MARKER_ANGLE: f32 = 0.45;
    /// 螢光筆筆頭的高度倍率與角度。
    pub const HIGHLIGHTER_HEIGHT: f32 = 1.8;
    pub const HIGHLIGHTER_ANGLE: f32 = 0.35;
    /// 群組不透明度（見模組說明）。
    pub const MARKER_GROUP_ALPHA: f32 = 0.74;
    pub const HIGHLIGHTER_GROUP_ALPHA: f32 = 0.35;
}

/// 這支筆整筆畫完之後再疊上的不透明度。其他筆為 1。
pub fn group_alpha(tool: Tool) -> f32 {
    match tool {
        Tool::Marker => PenTuning::MARKER_GROUP_ALPHA,
        Tool::Highlighter => PenTuning::HIGHLIGHTER_GROUP_ALPHA,
        _ => 1.0,
    }
}

/// 是否為本模組負責的筆刷。
pub fn handles(tool: Tool) -> bool {
    matches!(
        tool,
        Tool::FountainPen
            | Tool::BallPoint
            | Tool::Pencil
            | Tool::Marker
            | Tool::Highlighter
            | Tool::Watercolor
    )
}

fn curve(p: f32) -> f32 {
    let p = p.clamp(0.0, 1.0).powf(PenTuning::PRESSURE_GAMMA);
    PenTuning::PRESSURE_FLOOR + (1.0 - PenTuning::PRESSURE_FLOOR) * p
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

#[derive(Clone, Debug)]
pub(super) struct PenEmitter {
    tool: Tool,
    base: f32,
    rng: Rng,
    /// 鋼筆：上一個樣本的半寬（平滑用）。
    last_r: Option<f32>,
}

impl PenEmitter {
    pub(super) fn new(tool: Tool, width: f32, rng: Rng) -> Self {
        Self {
            tool,
            base: (width * 0.5).max(0.3),
            rng,
            last_r: None,
        }
    }

    pub(super) fn spacing(&self) -> f32 {
        let s = match self.tool {
            Tool::BallPoint => self.base * 0.42,
            Tool::Pencil => self.base * 0.28,
            Tool::Watercolor => self.base * 0.16,
            Tool::Marker | Tool::Highlighter => self.base * 0.22,
            _ => self.base * 0.25,
        };
        s.max(0.3)
    }

    pub(super) fn emit(&mut self, s: Sample, out: &mut Vec<Dab>) {
        let base = self.base;
        match self.tool {
            Tool::FountainPen => {
                let thin = 1.0 - PenTuning::FOUNTAIN_SPEED_THIN * (s.speed - 1.0).clamp(-1.0, 4.0);
                let p = curve(s.pressure);
                // 鋼筆金屬筆尖彈性割角：縱向運筆下壓厚實，橫向運筆收細（橫細豎粗）
                let angle_mod = 0.65 + 0.62 * s.heading.sin().abs();
                let mut r = base * p * thin.clamp(0.48, 1.15) * angle_mod;
                if s.progress < 0.05 {
                    let t = (s.progress / 0.05).clamp(0.0, 1.0);
                    r *= 0.65 + 0.35 * smooth(t);
                }
                if s.progress > 1.0 - PenTuning::FOUNTAIN_TAPER {
                    let rem = ((1.0 - s.progress) / PenTuning::FOUNTAIN_TAPER).clamp(0.0, 1.0);
                    r *= 0.25 + 0.75 * smooth(rem);
                }
                if let Some(prev) = self.last_r {
                    r = prev * PenTuning::FOUNTAIN_SMOOTHING
                        + r * (1.0 - PenTuning::FOUNTAIN_SMOOTHING);
                }
                self.last_r = Some(r);
                // 鋼筆墨韻蓄墨（Ink Shading）：慢速或筆劃末梢墨水微沉暈染
                let shade = if s.speed < 0.6 || s.progress > 0.90 {
                    -0.16
                } else {
                    -0.04 * s.pressure
                };
                out.push(Dab {
                    x: s.x,
                    y: s.y,
                    rx: r.max(0.25),
                    ry: (r * 0.85).max(0.22),
                    angle: s.heading,
                    alpha: 1.0,
                    softness: 0.0,
                    shade,
                });
            }
            Tool::BallPoint => {
                let p = s.pressure.clamp(0.0, 1.0);
                let k = 1.0 - PenTuning::BALLPOINT_PRESSURE_AMOUNT
                    + PenTuning::BALLPOINT_PRESSURE_AMOUNT * p;
                let r = (base * 0.72 * k).max(0.2);
                // 鎢鋼滾珠油性墨膏：即使等速直線也保留微灰油光潤澤，重壓才趨近深飽和
                let alpha = 0.38 + 0.44 * p.powf(0.9);
                out.push(Dab {
                    x: s.x,
                    y: s.y,
                    rx: r,
                    ry: r,
                    angle: 0.0,
                    alpha,
                    softness: 0.12,
                    shade: 0.14 * (1.0 - p),
                });
            }
            Tool::Pencil => {
                let p = s.pressure.clamp(0.0, 1.0);
                let tilt_factor = 1.0 + 1.5 * s.tilt.sin().clamp(0.0, 1.0);
                // 1. 紙紋調制石墨筆脊（Grain-Modulated Graphite Spine）：即使無傾角也呈現紙紋顆粒與鉛灰質地
                let core_r = (base * 0.44 * (0.68 + 0.32 * p) * tilt_factor).max(0.28);
                let spine_grain = paper_grain(s.x, s.y);
                let core_alpha = ((0.36 + 0.42 * p) * (1.0 - 0.55 * spine_grain)
                    / (0.85 + 0.15 * tilt_factor))
                    .clamp(0.14, 0.85);
                out.push(Dab {
                    x: s.x,
                    y: s.y,
                    rx: core_r,
                    ry: core_r * if s.tilt > 0.35 { 0.72 } else { 0.92 },
                    angle: s.azimuth,
                    alpha: core_alpha,
                    softness: if s.tilt > 0.35 { 0.28 } else { 0.16 },
                    shade: 0.28, // 石墨特有的深鉛灰色微反光色階
                });
                // 2. 邊緣微觀石墨顆粒（Graphite Tooth）：在筆脊兩側紙紋凸起處留下自然摩擦碎屑
                let reach = core_r * 1.85;
                let tooth = PenTuning::PENCIL_TOOTH_MIN
                    + (PenTuning::PENCIL_TOOTH_MAX - PenTuning::PENCIL_TOOTH_MIN) * p;
                let count = ((reach * 2.5).ceil() as usize).clamp(3, 8);
                for _ in 0..count {
                    let ang = self.rng.unit() * std::f32::consts::TAU;
                    let rr = core_r * 0.55 + (reach - core_r * 0.55) * self.rng.unit().sqrt();
                    let (px, py) = (s.x + ang.cos() * rr, s.y + ang.sin() * rr);
                    let g = paper_grain(px, py);
                    if g > tooth {
                        continue;
                    }
                    let depth = 1.0 - g / tooth;
                    let size = (0.36 + 0.34 * self.rng.unit()) * (base / 2.0).clamp(0.45, 1.3);
                    out.push(Dab {
                        x: px,
                        y: py,
                        rx: size,
                        ry: size,
                        angle: 0.0,
                        alpha: (0.24 + 0.50 * depth) * (0.35 + 0.65 * p),
                        softness: 0.14,
                        shade: 0.24,
                    });
                }
            }
            Tool::Marker => out.push(Dab {
                x: s.x,
                y: s.y,
                rx: base * 1.1,
                ry: base * 1.1 * PenTuning::MARKER_FLATNESS,
                angle: PenTuning::MARKER_ANGLE,
                alpha: 1.0,
                softness: 0.0,
                shade: 0.0,
            }),
            Tool::Highlighter => out.push(Dab {
                x: s.x,
                y: s.y,
                rx: base * 0.9,
                ry: base * PenTuning::HIGHLIGHTER_HEIGHT,
                angle: PenTuning::HIGHLIGHTER_ANGLE,
                alpha: 1.0,
                softness: 0.0,
                shade: 0.0,
            }),
            Tool::Watercolor => {
                let p = s.pressure.clamp(0.0, 1.0);
                // 走得慢水分聚得多：暈得開、顏色深。
                let wet = (1.3 - 0.25 * s.speed).clamp(0.6, 1.3);
                let r = base * (0.92 + 0.52 * p) * wet;
                // 1. 中心水潤擴散層
                out.push(round(s.x, s.y, r, (0.08 + 0.14 * p) * wet, 0.82));
                // 2. 咖啡環邊緣效應（Coffee-Ring Effect）：水分蒸發時外緣色素沉積深色水漬圈
                out.push(Dab {
                    x: s.x,
                    y: s.y,
                    rx: r * 0.96,
                    ry: r * 0.96,
                    angle: 0.0,
                    alpha: (0.14 + 0.16 * p) * wet,
                    softness: 0.35,
                    shade: -0.12,
                });
            }
            _ => {}
        }
    }
}
