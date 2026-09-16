//! 形狀基本型（工作項 S-47）。
//!
//! 涵蓋一般繪圖形狀與 **ISO 5807 / ANSI 的流程圖符號** ——
//! 那些符號有標準語意（菱形＝判斷、平行四邊形＝輸入輸出），
//! 使用者看得懂才有意義，因此不自創圖形。
//!
//! ## 所有形狀都以外框 + 種類定義
//! 不存頂點座標，而是**存外框與種類、需要時才算出輪廓**。理由與
//! ADR-0010 相同：縮放時只改外框，輪廓重新計算，不會累積浮點誤差。

use padnote_ink::Rect;

/// 形狀種類。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ShapeKind {
    // ---- 一般形狀 ----
    Rectangle,
    RoundedRectangle,
    Ellipse,
    Triangle,
    Diamond,
    Pentagon,
    Hexagon,
    Star,
    // ---- 流程圖（ISO 5807）----
    /// 處理步驟（矩形）
    Process,
    /// 判斷（菱形）
    Decision,
    /// 起點／終點（圓角矩形）
    Terminator,
    /// 資料輸入輸出（平行四邊形）
    Data,
    /// 文件（底部波浪）
    Document,
    /// 資料庫（圓柱）
    Database,
    /// 預備／初始化（六邊形）
    Preparation,
    /// 人工輸入（梯形）
    ManualInput,
    /// 連接點（圓形）
    Connector,
    // ---- 流程圖（ISO 5807 續）----
    /// 人工作業（倒梯形）
    ManualOperation,
    /// 延遲（右側半圓）
    Delay,
    /// 已儲存資料（左側內凹的圓弧）
    StoredData,
    /// 彙整（向下三角）
    Merge,
    /// 抽取（向上三角）
    Extract,
    /// 跨頁連接（向下的五邊形）
    OffPageConnector,
    /// 顯示（左凹右凸）
    Display,
    /// 打孔紙帶（上下波浪）
    PunchedTape,
    /// 打孔卡（右上缺角）
    PunchedCard,
    /// 對照（蝴蝶結）
    Collate,
    // ---- 一般形狀（續）----
    RightTriangle,
    Parallelogram,
    Trapezoid,
    Heptagon,
    Octagon,
    Cross,
    Chevron,
    ArrowBlockRight,
    ArrowBlockLeft,
    ArrowBlockUp,
    ArrowBlockDown,
    Cloud,
    Heart,
    Bolt,
    Moon,
    Teardrop,
    LShape,
    Star4,
    Star6,
    Star8,
    Sun,
    Banner,
    SpeechBubble,
    Plaque,
    Pie,
    // ---- 線與箭頭 ----
    Line,
    Arrow,
    DoubleArrow,
}

impl ShapeKind {
    /// 是否為線狀（只有起點終點，沒有面積）。
    pub fn is_linear(self) -> bool {
        matches!(self, Self::Line | Self::Arrow | Self::DoubleArrow)
    }

    /// 是否為流程圖符號。UI 可據此分組顯示。
    pub fn is_flowchart(self) -> bool {
        matches!(
            self,
            Self::Process
                | Self::Decision
                | Self::Terminator
                | Self::Data
                | Self::Document
                | Self::Database
                | Self::Preparation
                | Self::ManualInput
                | Self::Connector
                | Self::ManualOperation
                | Self::Delay
                | Self::StoredData
                | Self::Merge
                | Self::Extract
                | Self::OffPageConnector
                | Self::Display
                | Self::PunchedTape
                | Self::PunchedCard
                | Self::Collate
        )
    }

    /// 標準語意說明。流程圖符號的意義是固定的，UI 應該顯示出來 ——
    /// 使用者未必記得菱形是判斷。
    pub fn semantic(self) -> Option<&'static str> {
        Some(match self {
            Self::Process => "處理步驟",
            Self::Decision => "判斷",
            Self::Terminator => "起點／終點",
            Self::Data => "資料輸入／輸出",
            Self::Document => "文件",
            Self::Database => "資料庫",
            Self::Preparation => "預備／初始化",
            Self::ManualInput => "人工輸入",
            Self::Connector => "連接點",
            Self::ManualOperation => "人工作業",
            Self::Delay => "延遲",
            Self::StoredData => "已儲存資料",
            Self::Merge => "彙整",
            Self::Extract => "抽取",
            Self::OffPageConnector => "跨頁連接",
            Self::Display => "顯示",
            Self::PunchedTape => "打孔紙帶",
            Self::PunchedCard => "打孔卡",
            Self::Collate => "對照",
            _ => return None,
        })
    }

    /// 是否能在內部放文字。線狀形狀不行。
    pub fn accepts_text(self) -> bool {
        !self.is_linear()
    }
}

/// 連接點位置。連接線接在這裡。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Anchor {
    Top,
    Right,
    Bottom,
    Left,
    Center,
}

impl Anchor {
    pub const SIDES: [Self; 4] = [Self::Top, Self::Right, Self::Bottom, Self::Left];

    /// 對向的連接點。自動選路時用來讓線從合理的一側出發。
    pub fn opposite(self) -> Self {
        match self {
            Self::Top => Self::Bottom,
            Self::Bottom => Self::Top,
            Self::Left => Self::Right,
            Self::Right => Self::Left,
            Self::Center => Self::Center,
        }
    }
}

/// 一個形狀。
#[derive(Clone, Copy, Debug)]
pub struct Shape {
    pub kind: ShapeKind,
    pub bounds: Rect,
    /// 圓角半徑（僅圓角矩形與起終點使用）。
    pub corner_radius: f32,
    /// 繞自身中心的旋轉角度（度，順時針）。
    ///
    /// **`bounds` 永遠是未旋轉的軸對齊矩形。** 旋轉只在取點時套用
    /// （`anchor_point` / `outline`）—— 把旋轉烘進 bounds 的話，
    /// 每轉一次就會把外框撐大一點，連轉幾次圖形會自己長大。
    pub rotation_degrees: f32,
}

impl Shape {
    pub fn new(kind: ShapeKind, bounds: Rect) -> Self {
        Self {
            kind,
            bounds,
            // 圓角預設取較短邊的 1/6，縮放時比例才會一致。
            corner_radius: bounds.width().min(bounds.height()) / 6.0,
            rotation_degrees: 0.0,
        }
    }

    pub fn center(&self) -> (f32, f32) {
        (
            (self.bounds.min_x + self.bounds.max_x) / 2.0,
            (self.bounds.min_y + self.bounds.max_y) / 2.0,
        )
    }

    /// 圖形是否偏離正向。
    pub fn is_rotated(&self) -> bool {
        (self.rotation_degrees % 360.0).abs() > f32::EPSILON
    }

    /// 把一個點繞圖形中心旋轉。
    fn rotate_about_center(&self, (x, y): (f32, f32)) -> (f32, f32) {
        if !self.is_rotated() {
            return (x, y);
        }
        let (cx, cy) = self.center();
        let rad = self.rotation_degrees.to_radians();
        let (sin, cos) = rad.sin_cos();
        let (dx, dy) = (x - cx, y - cy);
        (cx + dx * cos - dy * sin, cy + dx * sin + dy * cos)
    }

    /// 連接點的座標。
    ///
    /// 圖形轉過之後，連接點也要跟著轉到旋轉後的那條邊上 ——
    /// 否則線會接在圖形外面的空氣中，而且角度越大離得越遠。
    pub fn anchor_point(&self, anchor: Anchor) -> (f32, f32) {
        let (cx, cy) = self.center();
        let b = self.bounds;
        let local = match anchor {
            Anchor::Top => (cx, b.min_y),
            Anchor::Right => (b.max_x, cy),
            Anchor::Bottom => (cx, b.max_y),
            Anchor::Left => (b.min_x, cy),
            Anchor::Center => (cx, cy),
        };
        self.rotate_about_center(local)
    }

    /// 輪廓多邊形。曲線（橢圓、圓柱、文件的波浪）以線段近似。
    ///
    /// `segments` 控制曲線的細緻度。渲染用高值、命中測試用低值即可。
    /// 輪廓多邊形。**不套用旋轉。**
    ///
    /// 旋轉刻意留給平台做，理由有三個，每一個都是實際會壞的：
    ///
    /// 1. 圖形上的文字標籤是平台自己畫的。核心只轉輪廓的話，
    ///    方塊轉了、裡面的字還是正的。
    /// 2. 平台把輪廓畫在一個 `width × height` 的畫布裡。轉過的輪廓會超出
    ///    那個範圍被裁掉 —— 45° 時四個角會直接消失。
    /// 3. 平台對整個視圖套旋轉時，點擊測試也會跟著轉（SwiftUI 的
    ///    `rotationEffect`、Compose 的 `graphicsLayer` 都是）。核心先轉一次、
    ///    平台再轉一次，就是轉兩次。
    ///
    /// `anchor_point` 則相反，**必須**套用旋轉：連接線畫在兩個不同圖形之間，
    /// 端點一定要是畫布座標。
    pub fn outline(&self, segments: usize) -> Vec<(f32, f32)> {
        let b = self.bounds;
        let (w, h) = (b.width(), b.height());
        let (cx, cy) = self.center();
        let n = segments.max(8);

        match self.kind {
            ShapeKind::Rectangle | ShapeKind::Process => rect_points(b),

            ShapeKind::RoundedRectangle | ShapeKind::Terminator => {
                rounded_rect(b, self.corner_radius.min(w / 2.0).min(h / 2.0), n)
            }

            ShapeKind::Ellipse | ShapeKind::Connector => (0..n)
                .map(|i| {
                    let t = i as f32 / n as f32 * std::f32::consts::TAU;
                    (cx + w / 2.0 * t.cos(), cy + h / 2.0 * t.sin())
                })
                .collect(),

            ShapeKind::Triangle => vec![(cx, b.min_y), (b.max_x, b.max_y), (b.min_x, b.max_y)],

            ShapeKind::Diamond | ShapeKind::Decision => {
                vec![(cx, b.min_y), (b.max_x, cy), (cx, b.max_y), (b.min_x, cy)]
            }

            // 平行四邊形：上下邊各偏移寬度的 1/5
            ShapeKind::Data => {
                let d = w / 5.0;
                vec![
                    (b.min_x + d, b.min_y),
                    (b.max_x, b.min_y),
                    (b.max_x - d, b.max_y),
                    (b.min_x, b.max_y),
                ]
            }

            // 梯形（上窄下寬）
            ShapeKind::ManualInput => {
                let d = w / 5.0;
                vec![
                    (b.min_x + d, b.min_y),
                    (b.max_x - d, b.min_y),
                    (b.max_x, b.max_y),
                    (b.min_x, b.max_y),
                ]
            }

            ShapeKind::Pentagon => regular_polygon(cx, cy, w / 2.0, h / 2.0, 5),
            ShapeKind::Hexagon | ShapeKind::Preparation => {
                regular_polygon(cx, cy, w / 2.0, h / 2.0, 6)
            }

            ShapeKind::Star => (0..10)
                .map(|i| {
                    let t = i as f32 / 10.0 * std::f32::consts::TAU - std::f32::consts::FRAC_PI_2;
                    let r = if i % 2 == 0 { 1.0 } else { 0.4 };
                    (cx + w / 2.0 * r * t.cos(), cy + h / 2.0 * r * t.sin())
                })
                .collect(),

            // 文件：上緣與左右為直線，底部是波浪
            ShapeKind::Document => {
                let wave_h = h / 8.0;
                let mut p = vec![
                    (b.min_x, b.min_y),
                    (b.max_x, b.min_y),
                    (b.max_x, b.max_y - wave_h),
                ];
                for i in 0..=n {
                    let t = i as f32 / n as f32;
                    let x = b.max_x - w * t;
                    let y = b.max_y - wave_h + wave_h * (t * std::f32::consts::TAU).sin();
                    p.push((x, y));
                }
                p.push((b.min_x, b.min_y));
                p
            }

            // 圓柱：上下各一個橢圓弧
            ShapeKind::Database => {
                let ry = h / 8.0;
                let mut p = Vec::with_capacity(n * 2 + 4);
                for i in 0..=n {
                    let t = std::f32::consts::PI * i as f32 / n as f32;
                    p.push((cx - w / 2.0 * t.cos(), b.min_y + ry - ry * t.sin()));
                }
                p.push((b.max_x, b.max_y - ry));
                for i in 0..=n {
                    let t = std::f32::consts::PI * i as f32 / n as f32;
                    p.push((cx + w / 2.0 * t.cos(), b.max_y - ry + ry * t.sin()));
                }
                p.push((b.min_x, b.min_y + ry));
                p
            }

            // ---- 一般形狀（續）----
            ShapeKind::RightTriangle => {
                vec![(b.min_x, b.min_y), (b.max_x, b.max_y), (b.min_x, b.max_y)]
            }

            // 平行四邊形與 Data 的偏移量一致 —— 兩者在視覺上就是同一個形狀，
            // 差別只在語意（一個是流程圖符號，一個是一般圖形）。
            ShapeKind::Parallelogram => {
                let d = w / 5.0;
                vec![
                    (b.min_x + d, b.min_y),
                    (b.max_x, b.min_y),
                    (b.max_x - d, b.max_y),
                    (b.min_x, b.max_y),
                ]
            }

            // 梯形（上窄下寬）。ManualInput 是流程圖裡的同形狀。
            ShapeKind::Trapezoid => {
                let d = w / 5.0;
                vec![
                    (b.min_x + d, b.min_y),
                    (b.max_x - d, b.min_y),
                    (b.max_x, b.max_y),
                    (b.min_x, b.max_y),
                ]
            }

            ShapeKind::Heptagon => regular_polygon(cx, cy, w / 2.0, h / 2.0, 7),
            ShapeKind::Octagon => regular_polygon(cx, cy, w / 2.0, h / 2.0, 8),

            // 十字：橫豎兩條各佔三分之一。
            ShapeKind::Cross => {
                let tx = w / 3.0;
                let ty = h / 3.0;
                vec![
                    (b.min_x + tx, b.min_y),
                    (b.max_x - tx, b.min_y),
                    (b.max_x - tx, b.min_y + ty),
                    (b.max_x, b.min_y + ty),
                    (b.max_x, b.max_y - ty),
                    (b.max_x - tx, b.max_y - ty),
                    (b.max_x - tx, b.max_y),
                    (b.min_x + tx, b.max_y),
                    (b.min_x + tx, b.max_y - ty),
                    (b.min_x, b.max_y - ty),
                    (b.min_x, b.min_y + ty),
                    (b.min_x + tx, b.min_y + ty),
                ]
            }

            // V 形箭號（流程／階段圖常用）。
            ShapeKind::Chevron => {
                let d = w / 4.0;
                vec![
                    (b.min_x, b.min_y),
                    (b.max_x - d, b.min_y),
                    (b.max_x, cy),
                    (b.max_x - d, b.max_y),
                    (b.min_x, b.max_y),
                    (b.min_x + d, cy),
                ]
            }

            // 箭頭方塊：桿身佔一半高（或寬），頭部佔三分之一長。
            ShapeKind::ArrowBlockRight => {
                let head = w / 3.0;
                let shaft = h / 4.0;
                vec![
                    (b.min_x, cy - shaft),
                    (b.max_x - head, cy - shaft),
                    (b.max_x - head, b.min_y),
                    (b.max_x, cy),
                    (b.max_x - head, b.max_y),
                    (b.max_x - head, cy + shaft),
                    (b.min_x, cy + shaft),
                ]
            }
            ShapeKind::ArrowBlockLeft => {
                let head = w / 3.0;
                let shaft = h / 4.0;
                vec![
                    (b.max_x, cy - shaft),
                    (b.min_x + head, cy - shaft),
                    (b.min_x + head, b.min_y),
                    (b.min_x, cy),
                    (b.min_x + head, b.max_y),
                    (b.min_x + head, cy + shaft),
                    (b.max_x, cy + shaft),
                ]
            }
            ShapeKind::ArrowBlockUp => {
                let head = h / 3.0;
                let shaft = w / 4.0;
                vec![
                    (cx - shaft, b.max_y),
                    (cx - shaft, b.min_y + head),
                    (b.min_x, b.min_y + head),
                    (cx, b.min_y),
                    (b.max_x, b.min_y + head),
                    (cx + shaft, b.min_y + head),
                    (cx + shaft, b.max_y),
                ]
            }
            ShapeKind::ArrowBlockDown => {
                let head = h / 3.0;
                let shaft = w / 4.0;
                vec![
                    (cx - shaft, b.min_y),
                    (cx - shaft, b.max_y - head),
                    (b.min_x, b.max_y - head),
                    (cx, b.max_y),
                    (b.max_x, b.max_y - head),
                    (cx + shaft, b.max_y - head),
                    (cx + shaft, b.min_y),
                ]
            }

            // 雲朵：沿著外框走一圈，半徑用正弦擾動做出圓弧的凹凸。
            // 用擾動而不是接五個圓弧：接圓弧要處理相交，而相交點算錯時
            // 雲會多出一條穿過中間的線。
            ShapeKind::Cloud => (0..n * 2)
                .map(|i| {
                    let t = i as f32 / (n * 2) as f32 * std::f32::consts::TAU;
                    let bumps = 1.0 + 0.12 * (t * 7.0).sin() + 0.06 * (t * 3.0).cos();
                    (
                        cx + w / 2.0 * 0.86 * bumps * t.cos(),
                        cy + h / 2.0 * 0.82 * bumps * t.sin(),
                    )
                })
                .collect(),

            // 心形：標準參數式，再縮放到外框。
            ShapeKind::Heart => (0..=n * 2)
                .map(|i| {
                    let t = i as f32 / (n * 2) as f32 * std::f32::consts::TAU;
                    let x = 16.0 * t.sin().powi(3);
                    let y = -(13.0 * t.cos()
                        - 5.0 * (2.0 * t).cos()
                        - 2.0 * (3.0 * t).cos()
                        - (4.0 * t).cos());
                    (cx + w / 2.0 * x / 17.0, cy + h / 2.0 * y / 17.0)
                })
                .collect(),

            // 閃電。
            ShapeKind::Bolt => vec![
                (cx - w * 0.10, b.min_y),
                (b.max_x - w * 0.15, b.min_y),
                (cx + w * 0.02, cy - h * 0.05),
                (b.max_x - w * 0.25, cy - h * 0.05),
                (b.min_x + w * 0.20, b.max_y),
                (cx - w * 0.02, cy + h * 0.10),
                (b.min_x + w * 0.22, cy + h * 0.10),
            ],

            // 月牙：外圈半圓 + 內凹的弧，接成一條封閉折線。
            ShapeKind::Moon => {
                let mut p = Vec::with_capacity(n * 2 + 2);
                for i in 0..=n {
                    let t =
                        -std::f32::consts::FRAC_PI_2 + std::f32::consts::PI * i as f32 / n as f32;
                    p.push((cx + w / 2.0 * t.cos(), cy + h / 2.0 * t.sin()));
                }
                for i in 0..=n {
                    let t =
                        std::f32::consts::FRAC_PI_2 - std::f32::consts::PI * i as f32 / n as f32;
                    p.push((
                        cx + w / 2.0 * 0.45 * t.cos() - w * 0.08,
                        cy + h / 2.0 * t.sin(),
                    ));
                }
                p
            }

            // 水滴：上尖下圓。
            //
            // 圓弧要**跳過頂端那一段**，否則尖端會被圓自己蓋掉，
            // 畫出來是一顆壓扁的橢圓（實測看過）。
            ShapeKind::Teardrop => {
                let ccy = b.min_y + h * 0.62;
                let ry = h * 0.38;
                let gap = 0.55_f32; // 頂端要讓出來的弧度
                let start = -std::f32::consts::FRAC_PI_2 + gap;
                let sweep = std::f32::consts::TAU - gap * 2.0;
                let mut p = vec![(cx, b.min_y)];
                for i in 0..=n {
                    let t = start + sweep * i as f32 / n as f32;
                    p.push((cx + w / 2.0 * t.cos(), ccy + ry * t.sin()));
                }
                p
            }

            // L 形。
            ShapeKind::LShape => {
                let tx = w / 3.0;
                let ty = h / 3.0;
                vec![
                    (b.min_x, b.min_y),
                    (b.min_x + tx, b.min_y),
                    (b.min_x + tx, b.max_y - ty),
                    (b.max_x, b.max_y - ty),
                    (b.max_x, b.max_y),
                    (b.min_x, b.max_y),
                ]
            }

            ShapeKind::Star4 => star_points(cx, cy, w / 2.0, h / 2.0, 4, 0.38),
            ShapeKind::Star6 => star_points(cx, cy, w / 2.0, h / 2.0, 6, 0.55),
            ShapeKind::Star8 => star_points(cx, cy, w / 2.0, h / 2.0, 8, 0.62),
            ShapeKind::Sun => star_points(cx, cy, w / 2.0, h / 2.0, 12, 0.68),

            // 旗幟／緞帶：下緣中間有一個 V 形缺口。
            ShapeKind::Banner => {
                let notch = h / 4.0;
                vec![
                    (b.min_x, b.min_y),
                    (b.max_x, b.min_y),
                    (b.max_x, b.max_y),
                    (cx, b.max_y - notch),
                    (b.min_x, b.max_y),
                ]
            }

            // 對話框：圓角本體 + 左下角的尾巴，一條折線走完。
            //
            // 不是「先做圓角矩形再把尾巴插進去」—— 那要猜插在折線的哪一段，
            // 而猜錯的時候尾巴會長在右邊或直接穿過方框。順著邊走一圈最單純。
            ShapeKind::SpeechBubble => {
                let body_bottom = b.min_y + h * 0.76;
                let body_h = body_bottom - b.min_y;
                let r = (w.min(body_h) / 6.0).min(body_h / 2.0).min(w / 2.0);
                let seg = (n / 4).max(3);
                let mut p: Vec<(f32, f32)> = Vec::new();
                let arc = |p: &mut Vec<(f32, f32)>, ox: f32, oy: f32, from: f32| {
                    for i in 0..=seg {
                        let t = from + std::f32::consts::FRAC_PI_2 * i as f32 / seg as f32;
                        p.push((ox + r * t.cos(), oy + r * t.sin()));
                    }
                };
                // 左上 → 右上 → 右下
                arc(&mut p, b.min_x + r, b.min_y + r, std::f32::consts::PI);
                arc(
                    &mut p,
                    b.max_x - r,
                    b.min_y + r,
                    std::f32::consts::FRAC_PI_2 * 3.0,
                );
                arc(&mut p, b.max_x - r, body_bottom - r, 0.0);
                // 下緣往左走到尾巴的右腳
                p.push((b.min_x + w * 0.38, body_bottom));
                p.push((b.min_x + w * 0.20, b.max_y)); // 尾巴尖端
                p.push((b.min_x + w * 0.26, body_bottom));
                // 左下角
                arc(
                    &mut p,
                    b.min_x + r,
                    body_bottom - r,
                    std::f32::consts::FRAC_PI_2,
                );
                p
            }

            // 匾額：四個角**向內凹**的圓弧。
            //
            // 圓心放在往內縮 d 的那個點上，弧朝外走 —— 圓心放在角上的話
            // 凹口會反過來變成圓角，看起來就只是一個圓角矩形。
            ShapeKind::Plaque => {
                let d = w.min(h) / 5.0;
                let seg = (n / 4).max(3);
                // (圓心, 起始角)。順序是左上 → 右上 → 右下 → 左下，
                // 每一段都逆著角走 90°，接起來才是一圈。
                let arcs = [
                    ((b.min_x + d, b.min_y + d), std::f32::consts::PI),
                    (
                        (b.max_x - d, b.min_y + d),
                        std::f32::consts::FRAC_PI_2 * 3.0,
                    ),
                    ((b.max_x - d, b.max_y - d), 0.0),
                    ((b.min_x + d, b.max_y - d), std::f32::consts::FRAC_PI_2),
                ];
                let mut p = Vec::with_capacity(seg * 4 + 4);
                for ((ox, oy), start) in arcs {
                    for i in 0..=seg {
                        let t = start + std::f32::consts::FRAC_PI_2 * i as f32 / seg as f32;
                        p.push((ox + d * t.cos(), oy + d * t.sin()));
                    }
                }
                p
            }

            // 圓餅（四分之三圓）。
            ShapeKind::Pie => {
                let mut p = vec![(cx, cy)];
                let sweep = std::f32::consts::TAU * 0.75;
                for i in 0..=n {
                    let t = -std::f32::consts::FRAC_PI_2 + sweep * i as f32 / n as f32;
                    p.push((cx + w / 2.0 * t.cos(), cy + h / 2.0 * t.sin()));
                }
                p
            }

            // ---- 流程圖（續）----

            // 人工作業：倒梯形（上寬下窄）。
            ShapeKind::ManualOperation => {
                let d = w / 5.0;
                vec![
                    (b.min_x, b.min_y),
                    (b.max_x, b.min_y),
                    (b.max_x - d, b.max_y),
                    (b.min_x + d, b.max_y),
                ]
            }

            // 延遲：右側半圓。
            ShapeKind::Delay => {
                let mut p = vec![(b.min_x, b.min_y), (cx, b.min_y)];
                for i in 0..=n {
                    let t =
                        -std::f32::consts::FRAC_PI_2 + std::f32::consts::PI * i as f32 / n as f32;
                    p.push((cx + w / 2.0 * t.cos(), cy + h / 2.0 * t.sin()));
                }
                p.push((b.min_x, b.max_y));
                p
            }

            // 已儲存資料：左側內凹的圓弧。
            ShapeKind::StoredData => {
                let rx = w / 8.0;
                let mut p = vec![(b.min_x + rx, b.min_y), (b.max_x - rx, b.min_y)];
                for i in 0..=n {
                    let t =
                        -std::f32::consts::FRAC_PI_2 + std::f32::consts::PI * i as f32 / n as f32;
                    p.push((b.max_x - rx + rx * t.cos(), cy + h / 2.0 * t.sin()));
                }
                p.push((b.min_x + rx, b.max_y));
                for i in 0..=n {
                    let t =
                        std::f32::consts::FRAC_PI_2 - std::f32::consts::PI * i as f32 / n as f32;
                    p.push((b.min_x + rx + rx * t.cos(), cy - h / 2.0 * t.sin()));
                }
                p
            }

            ShapeKind::Merge => vec![(b.min_x, b.min_y), (b.max_x, b.min_y), (cx, b.max_y)],
            ShapeKind::Extract => vec![(cx, b.min_y), (b.max_x, b.max_y), (b.min_x, b.max_y)],

            // 跨頁連接：向下的五邊形。
            ShapeKind::OffPageConnector => {
                let d = h / 3.0;
                vec![
                    (b.min_x, b.min_y),
                    (b.max_x, b.min_y),
                    (b.max_x, b.max_y - d),
                    (cx, b.max_y),
                    (b.min_x, b.max_y - d),
                ]
            }

            // 顯示：左凹右凸。
            ShapeKind::Display => {
                let d = w / 6.0;
                let mut p = vec![(b.min_x + d, b.min_y), (b.max_x - d, b.min_y)];
                for i in 0..=n {
                    let t =
                        -std::f32::consts::FRAC_PI_2 + std::f32::consts::PI * i as f32 / n as f32;
                    p.push((b.max_x - d + d * t.cos(), cy + h / 2.0 * t.sin()));
                }
                p.push((b.min_x + d, b.max_y));
                p.push((b.min_x, cy));
                p
            }

            // 打孔紙帶：上下都是波浪。
            ShapeKind::PunchedTape => {
                let wave = h / 8.0;
                let mut p = Vec::with_capacity(n * 2 + 2);
                for i in 0..=n {
                    let t = i as f32 / n as f32;
                    p.push((
                        b.min_x + w * t,
                        b.min_y + wave - wave * (t * std::f32::consts::TAU).sin(),
                    ));
                }
                for i in 0..=n {
                    let t = i as f32 / n as f32;
                    p.push((
                        b.max_x - w * t,
                        b.max_y - wave + wave * (t * std::f32::consts::TAU).sin(),
                    ));
                }
                p
            }

            // 打孔卡：右上缺一角。
            ShapeKind::PunchedCard => {
                let d = w.min(h) / 4.0;
                vec![
                    (b.min_x, b.min_y),
                    (b.max_x - d, b.min_y),
                    (b.max_x, b.min_y + d),
                    (b.max_x, b.max_y),
                    (b.min_x, b.max_y),
                ]
            }

            // 對照：蝴蝶結（上下兩個三角形相接）。
            ShapeKind::Collate => vec![
                (b.min_x, b.min_y),
                (b.max_x, b.min_y),
                (cx, cy),
                (b.max_x, b.max_y),
                (b.min_x, b.max_y),
                (cx, cy),
            ],

            // 線狀：從左上到右下
            ShapeKind::Line | ShapeKind::Arrow | ShapeKind::DoubleArrow => {
                vec![(b.min_x, b.min_y), (b.max_x, b.max_y)]
            }
        }
    }

    /// 點是否在形狀內（射線法）。線狀形狀改用距離判定。
    pub fn contains(&self, x: f32, y: f32, tolerance: f32) -> bool {
        if self.kind.is_linear() {
            let p = self.outline(2);
            return padnote_ink::distance_to_segment((x, y), p[0], p[1]) <= tolerance;
        }
        // 先用外框粗篩
        if !self.bounds.inflate(tolerance).contains_point(x, y) {
            return false;
        }
        point_in_polygon(x, y, &self.outline(32))
    }
}

/// 尖角星。`points` 是尖角數，`inner` 是內半徑相對外半徑的比例。
fn star_points(cx: f32, cy: f32, rx: f32, ry: f32, points: usize, inner: f32) -> Vec<(f32, f32)> {
    let total = points * 2;
    (0..total)
        .map(|i| {
            let t = i as f32 / total as f32 * std::f32::consts::TAU - std::f32::consts::FRAC_PI_2;
            let r = if i % 2 == 0 { 1.0 } else { inner };
            (cx + rx * r * t.cos(), cy + ry * r * t.sin())
        })
        .collect()
}

fn rect_points(b: Rect) -> Vec<(f32, f32)> {
    vec![
        (b.min_x, b.min_y),
        (b.max_x, b.min_y),
        (b.max_x, b.max_y),
        (b.min_x, b.max_y),
    ]
}

fn rounded_rect(b: Rect, r: f32, segments: usize) -> Vec<(f32, f32)> {
    let per_corner = (segments / 4).max(2);
    let corners = [
        (b.max_x - r, b.min_y + r, -std::f32::consts::FRAC_PI_2, 0.0),
        (b.max_x - r, b.max_y - r, 0.0, std::f32::consts::FRAC_PI_2),
        (
            b.min_x + r,
            b.max_y - r,
            std::f32::consts::FRAC_PI_2,
            std::f32::consts::PI,
        ),
        (
            b.min_x + r,
            b.min_y + r,
            std::f32::consts::PI,
            1.5 * std::f32::consts::PI,
        ),
    ];

    let mut p = Vec::with_capacity(per_corner * 4);
    for (cx, cy, a0, a1) in corners {
        for i in 0..=per_corner {
            let t = a0 + (a1 - a0) * i as f32 / per_corner as f32;
            p.push((cx + r * t.cos(), cy + r * t.sin()));
        }
    }
    p
}

fn regular_polygon(cx: f32, cy: f32, rx: f32, ry: f32, sides: usize) -> Vec<(f32, f32)> {
    (0..sides)
        .map(|i| {
            let t = i as f32 / sides as f32 * std::f32::consts::TAU - std::f32::consts::FRAC_PI_2;
            (cx + rx * t.cos(), cy + ry * t.sin())
        })
        .collect()
}

/// 射線法：從該點往右射一條線，數穿過多邊形邊的次數。奇數在內、偶數在外。
fn point_in_polygon(x: f32, y: f32, poly: &[(f32, f32)]) -> bool {
    let mut inside = false;
    let n = poly.len();
    for i in 0..n {
        let (x1, y1) = poly[i];
        let (x2, y2) = poly[(i + 1) % n];
        if (y1 > y) != (y2 > y) && x < (x2 - x1) * (y - y1) / (y2 - y1) + x1 {
            inside = !inside;
        }
    }
    inside
}

#[cfg(test)]
mod tests {
    use super::*;

    fn rect() -> Rect {
        Rect::new(0.0, 0.0, 100.0, 60.0)
    }

    #[test]
    fn flowchart_symbols_carry_their_standard_meaning() {
        // 流程圖符號的語意是標準的，UI 應該顯示 —— 使用者未必記得菱形是判斷。
        assert_eq!(ShapeKind::Decision.semantic(), Some("判斷"));
        assert_eq!(ShapeKind::Data.semantic(), Some("資料輸入／輸出"));
        assert_eq!(
            ShapeKind::Rectangle.semantic(),
            None,
            "一般形狀沒有固定語意"
        );
    }

    #[test]
    fn linear_shapes_are_classified_correctly() {
        assert!(ShapeKind::Arrow.is_linear());
        assert!(!ShapeKind::Arrow.accepts_text(), "線上放不了文字");
        assert!(!ShapeKind::Process.is_linear());
        assert!(ShapeKind::Process.accepts_text());
    }

    #[test]
    fn every_shape_produces_a_usable_outline() {
        // 新增形狀卻忘記實作輪廓，這條會抓到。
        for kind in [
            ShapeKind::Rectangle,
            ShapeKind::RoundedRectangle,
            ShapeKind::Ellipse,
            ShapeKind::Triangle,
            ShapeKind::Diamond,
            ShapeKind::Pentagon,
            ShapeKind::Hexagon,
            ShapeKind::Star,
            ShapeKind::Process,
            ShapeKind::Decision,
            ShapeKind::Terminator,
            ShapeKind::Data,
            ShapeKind::Document,
            ShapeKind::Database,
            ShapeKind::Preparation,
            ShapeKind::ManualInput,
            ShapeKind::Connector,
            ShapeKind::Line,
            ShapeKind::Arrow,
            ShapeKind::DoubleArrow,
        ] {
            let outline = Shape::new(kind, rect()).outline(16);
            assert!(outline.len() >= 2, "{kind:?} 的輪廓點太少");
            assert!(
                outline.iter().all(|(x, y)| x.is_finite() && y.is_finite()),
                "{kind:?} 的輪廓含非法座標"
            );
        }
    }

    #[test]
    fn outlines_stay_within_the_bounds() {
        // 輪廓超出外框的話，選取框與實際圖形會對不上。
        for kind in [
            ShapeKind::Ellipse,
            ShapeKind::Diamond,
            ShapeKind::Hexagon,
            ShapeKind::Database,
            ShapeKind::Document,
            ShapeKind::Star,
        ] {
            let b = rect();
            for (x, y) in Shape::new(kind, b).outline(32) {
                assert!(
                    x >= b.min_x - 0.01 && x <= b.max_x + 0.01,
                    "{kind:?} 的 x={x} 超出外框"
                );
                assert!(
                    y >= b.min_y - 0.01 && y <= b.max_y + 0.01,
                    "{kind:?} 的 y={y} 超出外框"
                );
            }
        }
    }

    #[test]
    fn anchors_sit_on_the_bounding_box_edges() {
        let s = Shape::new(ShapeKind::Process, rect());
        assert_eq!(s.anchor_point(Anchor::Top), (50.0, 0.0));
        assert_eq!(s.anchor_point(Anchor::Right), (100.0, 30.0));
        assert_eq!(s.anchor_point(Anchor::Bottom), (50.0, 60.0));
        assert_eq!(s.anchor_point(Anchor::Left), (0.0, 30.0));
        assert_eq!(s.anchor_point(Anchor::Center), (50.0, 30.0));
    }

    #[test]
    fn hit_testing_respects_the_actual_outline_not_the_bounding_box() {
        // 菱形的四個角落在外框內但不在圖形內 —— 用外框判定會讓點擊很不準。
        let d = Shape::new(ShapeKind::Diamond, rect());
        assert!(d.contains(50.0, 30.0, 0.0), "中心應命中");
        assert!(!d.contains(2.0, 2.0, 0.0), "左上角在外框內但不在菱形內");
    }

    #[test]
    fn ellipse_corners_are_outside() {
        let e = Shape::new(ShapeKind::Ellipse, rect());
        assert!(e.contains(50.0, 30.0, 0.0));
        assert!(!e.contains(1.0, 1.0, 0.0));
    }

    #[test]
    fn linear_shapes_use_distance_based_hit_testing() {
        let a = Shape::new(ShapeKind::Arrow, rect());
        assert!(a.contains(50.0, 30.0, 2.0), "線上應命中");
        assert!(!a.contains(10.0, 55.0, 2.0), "遠離線段不該命中");
    }

    #[test]
    fn corner_radius_scales_with_the_shape() {
        // 固定半徑會讓小圖形看起來全圓、大圖形看起來方正。
        let small = Shape::new(ShapeKind::Terminator, Rect::new(0.0, 0.0, 30.0, 18.0));
        let large = Shape::new(ShapeKind::Terminator, Rect::new(0.0, 0.0, 300.0, 180.0));
        assert!(large.corner_radius > small.corner_radius * 5.0);
    }

    #[test]
    fn anchor_opposites_are_symmetric() {
        for a in Anchor::SIDES {
            assert_eq!(a.opposite().opposite(), a);
        }
        assert_eq!(Anchor::Center.opposite(), Anchor::Center);
    }

    #[test]
    fn degenerate_bounds_do_not_panic() {
        let flat = Rect::new(10.0, 10.0, 10.0, 10.0);
        for kind in [
            ShapeKind::Ellipse,
            ShapeKind::RoundedRectangle,
            ShapeKind::Database,
        ] {
            let outline = Shape::new(kind, flat).outline(16);
            assert!(outline.iter().all(|(x, y)| x.is_finite() && y.is_finite()));
        }
    }
}

#[cfg(test)]
mod rotation_tests {
    use super::*;

    fn square() -> Shape {
        Shape::new(
            ShapeKind::Rectangle,
            Rect {
                min_x: 0.0,
                min_y: 0.0,
                max_x: 100.0,
                max_y: 100.0,
            },
        )
    }

    fn close(a: (f32, f32), b: (f32, f32)) -> bool {
        (a.0 - b.0).abs() < 0.01 && (a.1 - b.1).abs() < 0.01
    }

    #[test]
    fn unrotated_anchors_are_unchanged() {
        let s = square();
        assert!(close(s.anchor_point(Anchor::Top), (50.0, 0.0)));
        assert!(close(s.anchor_point(Anchor::Right), (100.0, 50.0)));
    }

    #[test]
    fn rotating_90_moves_top_anchor_to_the_right_edge() {
        // 這是整個功能的重點：轉了之後「上」那個連接點要落在視覺上的右邊，
        // 不是還留在原來的位置。留在原位的話線會接到圖形外面的空氣中。
        let mut s = square();
        s.rotation_degrees = 90.0;
        assert!(close(s.anchor_point(Anchor::Top), (100.0, 50.0)));
        assert!(close(s.anchor_point(Anchor::Right), (50.0, 100.0)));
    }

    #[test]
    fn center_anchor_never_moves() {
        let mut s = square();
        s.rotation_degrees = 37.0;
        assert!(close(s.anchor_point(Anchor::Center), (50.0, 50.0)));
    }

    #[test]
    fn rotation_does_not_grow_the_bounds() {
        // bounds 永遠是未旋轉的軸對齊矩形。把旋轉烘進 bounds 的話，
        // 連轉幾次圖形會自己愈長愈大。
        let mut s = square();
        let before = s.bounds;
        s.rotation_degrees = 45.0;
        let _ = s.outline(16);
        assert_eq!(s.bounds.width(), before.width());
        assert_eq!(s.bounds.height(), before.height());
    }

    #[test]
    fn outline_is_never_rotated() {
        // 責任劃分：輪廓交給平台轉（標籤要一起轉、畫布不能裁掉四個角），
        // 連接點由核心轉（線畫在兩個圖形之間，要畫布座標）。
        // 兩邊都轉 = 轉兩次，圖形會歪到別的地方去。
        let mut s = square();
        let before = s.outline(16);
        s.rotation_degrees = 45.0;
        assert_eq!(s.outline(16), before, "outline 不該套用旋轉");
        // 但連接點要轉。
        assert!(!close(s.anchor_point(Anchor::Top), (50.0, 0.0)));
    }
}
