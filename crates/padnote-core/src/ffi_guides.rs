//! 版面引導線：一份紙張樣板「除了底紋以外」畫出來的東西。
//!
//! # 為什麼不是各平台各畫一次
//!
//! Apple 端原本用一個 `switch template` 搭配 CoreGraphics，十三種紙就是
//! 十三段手寫的繪圖程式碼；Android 端只畫得出核心 `PageStyle` 那六種底紋，
//! 藍圖標題欄、等角軸測、手機線框那一層**完全沒有**。同一本筆記在兩台
//! 裝置上長得不一樣。
//!
//! 紙張要從十三種長到三十幾種，沿著原路走就是 Apple 多二十段、Android
//! 繼續落後二十段 —— 而其中任何一段畫錯了，只會在那一種紙上看得到。
//!
//! 所以版面改成**資料**：核心回傳一串圖元（線、框、文字、勾選框、點），
//! 平台只認得那幾種圖元怎麼畫。新增一種紙是改這個檔案，兩邊同時就有。
//!
//! # 底紋不走這裡
//!
//! 方格、點陣、橫線仍然是 `PageStyle`，由平台自己鋪。理由是量：5mm 點陣
//! 在 A4 上是兩千多個點，把它們一顆顆送過 FFI 只是浪費。
//! **底紋是重複的材質，引導線是這張紙的結構**，兩者分開。
//!
//! # 座標
//!
//! 對外一律是頁面座標（左上原點，單位與 `standard_page_size` 相同）。
//! 內部用 0–1 的比例寫，最後才乘上實際頁面大小 —— 這樣同一份版面在 A4、
//! A5 與 16:9 上都成立，不必為每一種規格各寫一份。

/// 一個圖元的種類。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiGuideKind {
    /// 從 (x, y) 到 (x + w, y + h) 的直線。
    Line,
    /// 空心矩形。`radius` 用 `size` 欄位帶。
    Rect,
    /// 實心矩形（用來畫標題底色條）。
    FillRect,
    /// 文字。`text_key` 是語系鍵，平台自己翻。
    Label,
    /// 勾選框。`w` 是邊長。
    Checkbox,
    /// 圓點。`w` 是直徑。
    Dot,
}

/// 圖元的輕重。**不是顏色** —— 顏色由平台從自己的設計系統取，
/// 深色模式才不會需要核心也知道現在是不是深色。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiGuideTone {
    /// 最淡的結構線：格線、欄線。
    Hairline,
    /// 一般分隔線。
    Light,
    /// 強調線：區塊邊界、標題底線。
    Accent,
    /// 文字用的顏色（比內容淡，但看得清楚）。
    Muted,
}

/// 一個圖元。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiGuide {
    pub kind: FfiGuideKind,
    pub x: f32,
    pub y: f32,
    /// `Line` 是位移量，`Checkbox`／`Dot` 是邊長／直徑，`Label` 是可用的
    /// 最大寬度（超過就截斷），其餘是寬度。
    ///
    /// **`Label` 的 `x` 是錨點**，由 `align` 決定它是左緣、中心還是右緣 ——
    /// 不是左上角。置中的文字寫成「左上角 + 寬度」的話，呼叫端要自己
    /// 先減一半寬度，而那個減法每個版面各做一次就會有人做錯。
    pub w: f32,
    /// `Line` 是位移量，其餘是高度。
    pub h: f32,
    pub tone: FfiGuideTone,
    /// 線寬。`Label` 不用。
    pub weight: f32,
    /// 文字的語系鍵；沒有文字時是空字串。
    pub text_key: String,
    /// `Label` 的字級；`Rect` 的圓角半徑。
    pub size: f32,
    /// 0 靠左、1 置中、2 靠右。只有 `Label` 用得到。
    pub align: u32,
}

/// 一組版面配色。
///
/// # 為什麼顏色要出現在核心
///
/// 前一版說的是「核心只說輕重，不說顏色」—— 那是對的，當顏色只有「淡一點、
/// 深一點」的時候。使用者現在要**選**配色，而一組配色是六個平台都要拿到
/// 同一份的資料：兩邊各挑各的色票，同一本筆記在兩台裝置上會是兩個顏色。
///
/// 深淺仍然是平台的事：這裡給的是**色相**，平台自己決定在深色模式下要
/// 用多少不透明度。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiGuidePalette {
    pub id: String,
    /// 顯示名稱的語系鍵。
    pub name_key: String,
    /// 主色（區塊界線、標題底線）。`RRGGBB`。
    pub accent_hex: String,
    /// 標題底色條。
    pub band_hex: String,
    /// 格線與欄線。
    pub line_hex: String,
    /// 欄位標題的文字。
    pub text_hex: String,
}

fn palette(id: &str, accent: &str, band: &str, line: &str, text: &str) -> FfiGuidePalette {
    FfiGuidePalette {
        id: id.to_string(),
        name_key: format!("palette_{id}"),
        accent_hex: accent.to_string(),
        band_hex: band.to_string(),
        line_hex: line.to_string(),
        text_hex: text.to_string(),
    }
}

/// 全部配色，順序即顯示順序。第一個是預設。
///
/// 六組都刻意選了**低彩度的線條色 + 更低彩度的底色條**：版面是拿來對齊的
/// 參考，不是內容。一組飽和的橘線畫在紙上，寫上去的字會變成第二顯眼的東西。
#[uniffi::export]
pub fn guide_palettes() -> Vec<FfiGuidePalette> {
    vec![
        // 石墨：中性，跟任何墨色都不打架。
        palette("graphite", "4A5568", "EDF0F4", "8A94A6", "3D4658"),
        palette("indigo", "4C51BF", "EEF0FB", "8890D8", "3C4191"),
        palette("teal", "2C7A7B", "E6F4F4", "6FB0B1", "225C5D"),
        palette("rose", "B83280", "FBEDF5", "D98CBB", "8C2662"),
        palette("amber", "B7791F", "FBF3E4", "D9AE6B", "8A5B17"),
        palette("forest", "2F855A", "E9F5EE", "76B394", "236443"),
    ]
}

/// 依識別字取配色。認不得的回第一組 —— 未知的顏色不該讓版面消失。
#[uniffi::export]
pub fn guide_palette(id: String) -> FfiGuidePalette {
    guide_palettes()
        .into_iter()
        .find(|p| p.id == id)
        .unwrap_or_else(|| guide_palettes().remove(0))
}

// ---- 內部：用 0–1 的比例寫版面 ----

const LEFT: u32 = 0;
const CENTER: u32 = 1;

struct Sheet(Vec<FfiGuide>);

impl Sheet {
    fn new() -> Self {
        Sheet(Vec::new())
    }

    fn push(&mut self, g: FfiGuide) {
        self.0.push(g);
    }

    fn line(&mut self, x1: f32, y1: f32, x2: f32, y2: f32, tone: FfiGuideTone, weight: f32) {
        self.push(FfiGuide {
            kind: FfiGuideKind::Line,
            x: x1,
            y: y1,
            w: x2 - x1,
            h: y2 - y1,
            tone,
            weight,
            text_key: String::new(),
            size: 0.0,
            align: LEFT,
        });
    }

    fn hline(&mut self, x1: f32, x2: f32, y: f32, tone: FfiGuideTone, weight: f32) {
        self.line(x1, y, x2, y, tone, weight);
    }

    fn vline(&mut self, x: f32, y1: f32, y2: f32, tone: FfiGuideTone, weight: f32) {
        self.line(x, y1, x, y2, tone, weight);
    }

    fn rect(&mut self, x: f32, y: f32, w: f32, h: f32, tone: FfiGuideTone, weight: f32) {
        self.push(FfiGuide {
            kind: FfiGuideKind::Rect,
            x,
            y,
            w,
            h,
            tone,
            weight,
            text_key: String::new(),
            size: 0.008,
            align: LEFT,
        });
    }

    fn band(&mut self, x: f32, y: f32, w: f32, h: f32) {
        self.push(FfiGuide {
            kind: FfiGuideKind::FillRect,
            x,
            y,
            w,
            h,
            tone: FfiGuideTone::Hairline,
            weight: 0.0,
            text_key: String::new(),
            size: 0.006,
            align: LEFT,
        });
    }

    /// 文字。`size` 是字級占頁面**寬度**的比例 —— 用高度算的話，
    /// 同一份版面在橫式頁面上的字會突然變小。
    fn label(&mut self, key: &str, x: f32, y: f32, w: f32, size: f32, align: u32) {
        self.push(FfiGuide {
            kind: FfiGuideKind::Label,
            x,
            y,
            w,
            h: 0.0,
            tone: FfiGuideTone::Muted,
            weight: 0.0,
            text_key: key.to_string(),
            size,
            align,
        });
    }

    fn checkbox(&mut self, x: f32, y: f32, side: f32) {
        self.push(FfiGuide {
            kind: FfiGuideKind::Checkbox,
            x,
            y,
            w: side,
            h: side,
            tone: FfiGuideTone::Light,
            weight: 1.0,
            text_key: String::new(),
            size: 0.0,
            align: LEFT,
        });
    }

    /// 等距橫線。`count` 是線的條數（不含起點）。
    fn rows(&mut self, x1: f32, x2: f32, top: f32, bottom: f32, count: u32, tone: FfiGuideTone) {
        if count == 0 {
            return;
        }
        let step = (bottom - top) / count as f32;
        for i in 0..=count {
            self.hline(x1, x2, top + step * i as f32, tone, 1.0);
        }
    }

    /// 等距直線。
    fn cols(&mut self, y1: f32, y2: f32, left: f32, right: f32, count: u32, tone: FfiGuideTone) {
        if count == 0 {
            return;
        }
        let step = (right - left) / count as f32;
        for i in 0..=count {
            self.vline(left + step * i as f32, y1, y2, tone, 1.0);
        }
    }

    /// 標題列：一條底色條 + 文字 + 一條分隔線。整份目錄裡重複最多的組合。
    fn header(&mut self, key: &str, x: f32, y: f32, w: f32) {
        self.band(x, y, w, 0.034);
        self.label(key, x + 0.012, y + 0.023, w, 0.026, LEFT);
        self.hline(x, x + w, y + 0.034, FfiGuideTone::Accent, 1.5);
    }

    fn into_page(self, width: f32, height: f32) -> Vec<FfiGuide> {
        self.0
            .into_iter()
            .map(|g| FfiGuide {
                x: g.x * width,
                y: g.y * height,
                w: match g.kind {
                    // 邊長類的東西用寬度換算，否則在橫式頁面上會被拉成長方形。
                    FfiGuideKind::Checkbox | FfiGuideKind::Dot => g.w * width,
                    _ => g.w * width,
                },
                h: match g.kind {
                    FfiGuideKind::Checkbox | FfiGuideKind::Dot => g.w * width,
                    _ => g.h * height,
                },
                size: match g.kind {
                    FfiGuideKind::Label | FfiGuideKind::Rect => g.size * width,
                    _ => g.size,
                },
                ..g
            })
            .collect()
    }
}

// 版面共用的邊界。上下留得比左右多 —— 頁首頁尾是視覺呼吸，不是浪費。
const M: f32 = 0.06;
const TOP: f32 = 0.05;
const BOT: f32 = 0.955;
const R: f32 = 1.0 - M;

fn title_row(s: &mut Sheet, key: &str) {
    s.label(key, M, TOP, R - M, 0.032, LEFT);
    s.label("guide_date", R - 0.22, TOP, 0.22, 0.024, LEFT);
    s.hline(M, R, TOP + 0.012, FfiGuideTone::Accent, 1.5);
}

/// 一張紙除了底紋以外要畫的東西。
///
/// 認不得的識別字回空陣列 —— 未知的紙就是一張乾淨的紙，
/// 不是一個錯誤畫面。
#[uniffi::export]
pub fn page_guides(paper_id: String, width: f32, height: f32) -> Vec<FfiGuide> {
    if !width.is_finite() || !height.is_finite() || width <= 0.0 || height <= 0.0 {
        return Vec::new();
    }
    let mut s = Sheet::new();
    match paper_id.as_str() {
        // ---- 筆記方法 ----
        "cornell" | "cornell_grid" => {
            title_row(&mut s, "guide_topic");
            let split = M + (R - M) * 0.32;
            let body_top = TOP + 0.05;
            let summary = BOT - 0.13;
            s.vline(split, body_top, summary, FfiGuideTone::Accent, 1.5);
            s.hline(M, R, body_top, FfiGuideTone::Light, 1.0);
            s.hline(M, R, summary, FfiGuideTone::Accent, 1.5);
            s.label("guide_cue", M + 0.012, body_top + 0.026, 0.3, 0.022, LEFT);
            s.label(
                "guide_notes",
                split + 0.012,
                body_top + 0.026,
                0.3,
                0.022,
                LEFT,
            );
            s.label(
                "guide_summary",
                M + 0.012,
                summary + 0.028,
                0.3,
                0.022,
                LEFT,
            );
            if paper_id == "cornell" {
                // 主筆記欄鋪橫線；提示欄不鋪 —— 那一欄是關鍵字，不是句子。
                s.rows(
                    split + 0.01,
                    R,
                    body_top + 0.05,
                    summary - 0.01,
                    22,
                    FfiGuideTone::Hairline,
                );
            }
        }
        "quadrant" => {
            title_row(&mut s, "guide_topic");
            let top = TOP + 0.05;
            let mid_y = (top + BOT) / 2.0;
            let mid_x = (M + R) / 2.0;
            s.vline(mid_x, top, BOT, FfiGuideTone::Accent, 1.5);
            s.hline(M, R, mid_y, FfiGuideTone::Accent, 1.5);
            s.rect(M, top, R - M, BOT - top, FfiGuideTone::Light, 1.0);
            let half = mid_x - M;
            s.header("guide_key_points", M, top, half);
            s.header("guide_questions", mid_x, top, half);
            s.header("guide_decisions", M, mid_y, half);
            s.header("guide_actions", mid_x, mid_y, half);
        }
        "outline" => {
            title_row(&mut s, "guide_topic");
            let top = TOP + 0.05;
            // 三層縮排的導引線。線本身很淡：它是尺，不是框。
            for (i, key) in ["guide_main", "guide_sub", "guide_detail"]
                .iter()
                .enumerate()
            {
                let x = M + 0.06 * i as f32;
                s.vline(x, top, BOT, FfiGuideTone::Hairline, 1.0);
                s.label(key, x + 0.008, top - 0.012, 0.2, 0.018, LEFT);
            }
            s.rows(M, R, top + 0.02, BOT, 26, FfiGuideTone::Hairline);
        }
        "two_column" => {
            title_row(&mut s, "guide_topic");
            let top = TOP + 0.05;
            let mid = (M + R) / 2.0;
            s.header("guide_source", M, top, mid - M - 0.01);
            s.header("guide_my_notes", mid + 0.01, top, R - mid - 0.01);
            s.vline(mid, top, BOT, FfiGuideTone::Light, 1.0);
            s.rows(M, R, top + 0.05, BOT, 24, FfiGuideTone::Hairline);
        }
        "qa" => {
            title_row(&mut s, "guide_topic");
            let top = TOP + 0.06;
            let block = (BOT - top) / 6.0;
            for i in 0..6 {
                let y = top + block * i as f32;
                s.label("guide_question", M, y + 0.022, 0.2, 0.022, LEFT);
                s.hline(M + 0.06, R, y + 0.026, FfiGuideTone::Light, 1.0);
                s.label("guide_answer", M, y + 0.058, 0.2, 0.022, LEFT);
                s.rows(
                    M + 0.06,
                    R,
                    y + 0.062,
                    y + block - 0.014,
                    2,
                    FfiGuideTone::Hairline,
                );
            }
        }
        "kwl" => {
            title_row(&mut s, "guide_topic");
            let top = TOP + 0.05;
            let w = (R - M) / 3.0;
            for (i, key) in ["guide_know", "guide_want", "guide_learned"]
                .iter()
                .enumerate()
            {
                let x = M + w * i as f32;
                s.header(key, x, top, w);
                s.rows(
                    x + 0.008,
                    x + w - 0.008,
                    top + 0.05,
                    BOT,
                    22,
                    FfiGuideTone::Hairline,
                );
                s.vline(x, top, BOT, FfiGuideTone::Light, 1.0);
            }
            s.vline(R, top, BOT, FfiGuideTone::Light, 1.0);
            s.hline(M, R, BOT, FfiGuideTone::Light, 1.0);
        }
        "mind_map" => {
            title_row(&mut s, "guide_topic");
            let cx = 0.5;
            let cy = (TOP + BOT) / 2.0 + 0.02;
            s.rect(cx - 0.14, cy - 0.035, 0.28, 0.07, FfiGuideTone::Accent, 1.5);
            s.label("guide_center_idea", cx, cy + 0.006, 0.28, 0.024, CENTER);
            // 四個方向的分支起點，只給很短的一段 —— 剩下的讓使用者自己長。
            for (dx, dy) in [(-0.2f32, -0.16f32), (0.2, -0.16), (-0.2, 0.16), (0.2, 0.16)] {
                s.line(
                    cx + dx * 0.4,
                    cy + dy * 0.4,
                    cx + dx,
                    cy + dy,
                    FfiGuideTone::Hairline,
                    1.2,
                );
                s.rect(
                    cx + dx - 0.09,
                    cy + dy - 0.025,
                    0.18,
                    0.05,
                    FfiGuideTone::Hairline,
                    1.0,
                );
            }
        }

        // ---- 規劃排程 ----
        "monthly_grid" => {
            title_row(&mut s, "guide_month");
            let top = TOP + 0.05;
            let mid = (M + R) / 2.0;
            for (i, x) in [M, mid + 0.008].iter().enumerate() {
                let w = mid - M - 0.008;
                s.header("guide_day", *x, top, w);
                // 每半頁 16 列，兩半合起來放得下 31 天再加一列備註。
                s.rows(*x, *x + w, top + 0.034, BOT, 16, FfiGuideTone::Hairline);
                s.vline(*x, top, BOT, FfiGuideTone::Light, 1.0);
                s.vline(*x + w, top, BOT, FfiGuideTone::Light, 1.0);
                // 日期欄：靠左一小格。
                s.vline(*x + 0.036, top + 0.034, BOT, FfiGuideTone::Hairline, 1.0);
                let _ = i;
            }
        }
        "weekly_columns" => {
            title_row(&mut s, "guide_week");
            let top = TOP + 0.05;
            let days = [
                "guide_mon",
                "guide_tue",
                "guide_wed",
                "guide_thu",
                "guide_fri",
                "guide_sat",
                "guide_sun",
            ];
            let w = (R - M) / 7.0;
            s.band(M, top, R - M, 0.03);
            for (i, key) in days.iter().enumerate() {
                let x = M + w * i as f32;
                s.label(key, x + w / 2.0, top + 0.021, w, 0.018, CENTER);
                s.vline(x, top, BOT, FfiGuideTone::Light, 1.0);
            }
            s.vline(R, top, BOT, FfiGuideTone::Light, 1.0);
            s.hline(M, R, top + 0.03, FfiGuideTone::Accent, 1.5);
            s.rows(M, R, top + 0.03, BOT, 20, FfiGuideTone::Hairline);
        }
        "daily_schedule" => {
            title_row(&mut s, "guide_date");
            let top = TOP + 0.05;
            s.header("guide_time", M, top, 0.12);
            s.header("guide_task", M + 0.12, top, R - M - 0.12);
            s.vline(M + 0.12, top, BOT, FfiGuideTone::Light, 1.0);
            s.vline(M, top, BOT, FfiGuideTone::Light, 1.0);
            s.vline(R, top, BOT, FfiGuideTone::Light, 1.0);
            // 早上 6 點到晚上 11 點，每半小時一列 = 34 列。
            s.rows(M, R, top + 0.034, BOT, 34, FfiGuideTone::Hairline);
        }
        "timeline_24h" => {
            title_row(&mut s, "guide_date");
            let top = TOP + 0.06;
            let mid = (M + R) / 2.0;
            for (i, key) in ["guide_am", "guide_pm"].iter().enumerate() {
                let x = if i == 0 { M } else { mid + 0.01 };
                let w = mid - M - 0.01;
                s.header(key, x, top, w);
                s.vline(x + 0.075, top + 0.034, BOT, FfiGuideTone::Light, 1.0);
                s.rows(x, x + w, top + 0.034, BOT, 24, FfiGuideTone::Hairline);
                s.vline(x, top, BOT, FfiGuideTone::Light, 1.0);
                s.vline(x + w, top, BOT, FfiGuideTone::Light, 1.0);
            }
        }
        "study_planner" => {
            title_row(&mut s, "guide_date");
            let top = TOP + 0.05;
            // 上：今日目標。下：科目 × 內容 × 完成。
            s.header("guide_goals", M, top, R - M);
            s.rows(M, R, top + 0.034, top + 0.16, 3, FfiGuideTone::Hairline);
            let table = top + 0.2;
            s.header("guide_subject", M, table, 0.2);
            s.header("guide_content", M + 0.2, table, R - M - 0.28);
            s.header("guide_done", R - 0.08, table, 0.08);
            s.vline(M + 0.2, table, BOT - 0.12, FfiGuideTone::Light, 1.0);
            s.vline(R - 0.08, table, BOT - 0.12, FfiGuideTone::Light, 1.0);
            s.vline(M, table, BOT - 0.12, FfiGuideTone::Light, 1.0);
            s.vline(R, table, BOT - 0.12, FfiGuideTone::Light, 1.0);
            let rows = 14;
            s.rows(
                M,
                R,
                table + 0.034,
                BOT - 0.12,
                rows,
                FfiGuideTone::Hairline,
            );
            let step = (BOT - 0.12 - table - 0.034) / rows as f32;
            for i in 0..rows {
                s.checkbox(
                    R - 0.048,
                    table + 0.034 + step * i as f32 + step * 0.28,
                    0.018,
                );
            }
            s.header("guide_review", M, BOT - 0.09, R - M);
            s.rows(M, R, BOT - 0.056, BOT, 1, FfiGuideTone::Hairline);
        }
        "project_timeline" => {
            title_row(&mut s, "guide_project");
            let top = TOP + 0.05;
            s.header("guide_milestone", M, top, 0.3);
            s.header("guide_owner", M + 0.3, top, 0.18);
            s.header("guide_due", M + 0.48, top, R - M - 0.48);
            for x in [M, M + 0.3, M + 0.48, R] {
                s.vline(x, top, BOT, FfiGuideTone::Light, 1.0);
            }
            s.rows(M, R, top + 0.034, BOT, 18, FfiGuideTone::Hairline);
        }

        // ---- 清單追蹤 ----
        "todo_list" => {
            title_row(&mut s, "guide_date");
            let top = TOP + 0.06;
            let rows = 20;
            let step = (BOT - top) / rows as f32;
            for i in 0..rows {
                let y = top + step * i as f32;
                s.checkbox(M, y + step * 0.2, 0.022);
                s.hline(M + 0.05, R, y + step * 0.78, FfiGuideTone::Hairline, 1.0);
            }
        }
        "checklist_two" => {
            title_row(&mut s, "guide_topic");
            let top = TOP + 0.06;
            let mid = (M + R) / 2.0;
            let rows = 20;
            let step = (BOT - top) / rows as f32;
            for (col_x, col_r) in [(M, mid - 0.02), (mid + 0.02, R)] {
                for i in 0..rows {
                    let y = top + step * i as f32;
                    s.checkbox(col_x, y + step * 0.2, 0.02);
                    s.hline(
                        col_x + 0.045,
                        col_r,
                        y + step * 0.78,
                        FfiGuideTone::Hairline,
                        1.0,
                    );
                }
            }
        }
        "habit_month" => {
            title_row(&mut s, "guide_month");
            let top = TOP + 0.08;
            let label_w = 0.24;
            let grid_left = M + label_w;
            let bottom = top + (BOT - top) * 0.62;
            s.label("guide_habit", M, top - 0.012, label_w, 0.02, LEFT);
            s.label(
                "guide_day",
                grid_left,
                top - 0.012,
                R - grid_left,
                0.02,
                LEFT,
            );
            // 31 欄 × 14 列。
            s.cols(top, bottom, grid_left, R, 31, FfiGuideTone::Hairline);
            s.rows(M, R, top, bottom, 14, FfiGuideTone::Hairline);
            s.vline(grid_left, top, bottom, FfiGuideTone::Accent, 1.2);
            s.hline(M, R, top, FfiGuideTone::Accent, 1.2);
            s.header("guide_reflection", M, bottom + 0.03, R - M);
            s.rows(M, R, bottom + 0.064, BOT, 6, FfiGuideTone::Hairline);
        }
        "assignment_tracker" => {
            title_row(&mut s, "guide_topic");
            let top = TOP + 0.05;
            let cols = [M, M + 0.14, M + 0.46, R - 0.1, R];
            s.header("guide_subject", cols[0], top, cols[1] - cols[0]);
            s.header("guide_task", cols[1], top, cols[2] - cols[1]);
            s.header("guide_due", cols[2], top, cols[3] - cols[2]);
            s.header("guide_done", cols[3], top, cols[4] - cols[3]);
            for x in cols {
                s.vline(x, top, BOT, FfiGuideTone::Light, 1.0);
            }
            let rows = 20;
            s.rows(M, R, top + 0.034, BOT, rows, FfiGuideTone::Hairline);
            let step = (BOT - top - 0.034) / rows as f32;
            for i in 0..rows {
                s.checkbox(
                    (cols[3] + cols[4]) / 2.0 - 0.009,
                    top + 0.034 + step * i as f32 + step * 0.25,
                    0.018,
                );
            }
        }
        "chore_roster" => {
            title_row(&mut s, "guide_week");
            let top = TOP + 0.05;
            let task_w = 0.3;
            let grid_left = M + task_w;
            s.header("guide_area", M, top, task_w);
            let days = [
                "guide_mon",
                "guide_tue",
                "guide_wed",
                "guide_thu",
                "guide_fri",
                "guide_sat",
                "guide_sun",
            ];
            let dw = (R - grid_left) / 7.0;
            s.band(grid_left, top, R - grid_left, 0.034);
            for (i, key) in days.iter().enumerate() {
                s.label(
                    key,
                    grid_left + dw * i as f32 + dw / 2.0,
                    top + 0.023,
                    dw,
                    0.016,
                    CENTER,
                );
            }
            s.hline(M, R, top + 0.034, FfiGuideTone::Accent, 1.5);
            s.cols(top, BOT, grid_left, R, 7, FfiGuideTone::Hairline);
            s.vline(M, top, BOT, FfiGuideTone::Light, 1.0);
            s.vline(grid_left, top, BOT, FfiGuideTone::Accent, 1.2);
            s.rows(M, R, top + 0.034, BOT, 22, FfiGuideTone::Hairline);
        }
        "challenge_21" => {
            title_row(&mut s, "guide_topic");
            let top = TOP + 0.07;
            let mid = (M + R) / 2.0;
            // 兩欄各 11 格（第二欄最後一格留白當備註）。
            for (ci, (x, xr)) in [(M, mid - 0.015), (mid + 0.015, R)].iter().enumerate() {
                let rows = 11;
                let step = (BOT - top) / rows as f32;
                for i in 0..rows {
                    let y = top + step * i as f32;
                    s.rect(*x, y, xr - x, step * 0.86, FfiGuideTone::Light, 1.0);
                    s.vline(x + 0.05, y, y + step * 0.86, FfiGuideTone::Hairline, 1.0);
                    s.vline(xr - 0.045, y, y + step * 0.86, FfiGuideTone::Hairline, 1.0);
                }
                if ci == 0 {
                    s.label("guide_day", M, top - 0.014, 0.2, 0.018, LEFT);
                    s.label("guide_task", M + 0.06, top - 0.014, 0.2, 0.018, LEFT);
                }
            }
        }

        // ---- 既有的十三種（原本寫在 Apple 端的繪圖程式碼裡）----
        "moodboard" => {
            let top = TOP;
            let w = (R - M) / 5.0;
            for i in 0..5 {
                s.rect(
                    M + w * i as f32 + 0.008,
                    top,
                    w - 0.016,
                    0.06,
                    FfiGuideTone::Light,
                    1.0,
                );
            }
            s.rect(
                M,
                top + 0.08,
                R - M,
                BOT - top - 0.08,
                FfiGuideTone::Hairline,
                1.0,
            );
        }
        "golden_ratio" => {
            for f in [0.382f32, 0.618] {
                s.vline(f, 0.0, 1.0, FfiGuideTone::Accent, 1.2);
                s.hline(0.0, 1.0, f, FfiGuideTone::Accent, 1.2);
            }
            for f in [1.0f32 / 3.0, 2.0 / 3.0] {
                s.vline(f, 0.0, 1.0, FfiGuideTone::Hairline, 0.8);
                s.hline(0.0, 1.0, f, FfiGuideTone::Hairline, 0.8);
            }
        }
        "blueprint" => {
            s.rect(0.02, 0.015, 0.96, 0.97, FfiGuideTone::Accent, 1.5);
            // 右下角標題欄。
            s.rect(0.62, 0.9, 0.36, 0.085, FfiGuideTone::Accent, 1.5);
            s.hline(0.62, 0.98, 0.928, FfiGuideTone::Light, 1.0);
            s.hline(0.62, 0.98, 0.956, FfiGuideTone::Light, 1.0);
            s.vline(0.76, 0.9, 0.985, FfiGuideTone::Light, 1.0);
        }
        "orthographic" => {
            s.vline(0.5, TOP, BOT, FfiGuideTone::Accent, 1.2);
            s.hline(M, R, (TOP + BOT) / 2.0, FfiGuideTone::Accent, 1.2);
            s.rect(M, TOP, R - M, BOT - TOP, FfiGuideTone::Light, 1.0);
            let half_w = 0.5 - M;
            let half_h = ((TOP + BOT) / 2.0 - TOP).min(0.5);
            s.header("guide_front_view", M, TOP, half_w);
            s.header("guide_top_view", 0.5, TOP, half_w);
            s.header("guide_side_view", M, TOP + half_h, half_w);
            s.header("guide_iso_view", 0.5, TOP + half_h, half_w);
        }
        "mobile_wireframe" => {
            // 兩個手機外框，並排。比例接近 19.5:9。
            let ph = 0.42f32;
            let pw = ph * 0.46;
            for (i, cx) in [0.3f32, 0.7].iter().enumerate() {
                let y = 0.1 + 0.44 * i as f32 * 0.0 + 0.06;
                s.rect(cx - pw / 2.0, y, pw, ph, FfiGuideTone::Accent, 1.5);
                // 狀態列與底部指示條。
                s.hline(
                    cx - pw / 2.0,
                    cx + pw / 2.0,
                    y + 0.028,
                    FfiGuideTone::Hairline,
                    1.0,
                );
                s.hline(
                    cx - pw / 2.0,
                    cx + pw / 2.0,
                    y + ph - 0.03,
                    FfiGuideTone::Hairline,
                    1.0,
                );
            }
            s.label("guide_screen", 0.3, 0.06 - 0.012, 0.2, 0.018, CENTER);
            s.label("guide_screen", 0.7, 0.06 - 0.012, 0.2, 0.018, CENTER);
        }
        "web_grid" => {
            // 12 欄，含左右安全邊距。
            s.cols(TOP, BOT, M, R, 12, FfiGuideTone::Hairline);
            s.vline(M, TOP, BOT, FfiGuideTone::Accent, 1.2);
            s.vline(R, TOP, BOT, FfiGuideTone::Accent, 1.2);
            s.hline(M, R, TOP + 0.06, FfiGuideTone::Light, 1.0);
        }
        "user_journey" => {
            title_row(&mut s, "guide_topic");
            let top = TOP + 0.06;
            let lanes = ["guide_stage", "guide_action", "guide_feeling"];
            let lh = (BOT - top) / 3.0;
            for (i, key) in lanes.iter().enumerate() {
                let y = top + lh * i as f32;
                s.hline(M, R, y, FfiGuideTone::Accent, 1.2);
                s.label(key, M, y + 0.024, 0.2, 0.02, LEFT);
                // 五個節點。
                for j in 0..5 {
                    let cx = M + 0.1 + (R - M - 0.2) / 4.0 * j as f32;
                    s.rect(
                        cx - 0.05,
                        y + 0.04,
                        0.1,
                        lh - 0.07,
                        FfiGuideTone::Hairline,
                        1.0,
                    );
                    if j < 4 {
                        s.hline(
                            cx + 0.05,
                            cx + (R - M - 0.2) / 4.0 - 0.05,
                            y + 0.04 + (lh - 0.07) / 2.0,
                            FfiGuideTone::Hairline,
                            1.0,
                        );
                    }
                }
            }
            s.hline(M, R, BOT, FfiGuideTone::Accent, 1.2);
        }
        // blank / grid / lined / dot_grid_fine / isometric：只有底紋，沒有結構。
        _ => {}
    }
    s.into_page(width, height)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ffi_paper::paper_templates;

    fn guides(id: &str) -> Vec<FfiGuide> {
        page_guides(id.to_string(), 800.0, 1132.0)
    }

    #[test]
    fn an_unknown_paper_is_just_a_clean_sheet() {
        assert!(guides("no_such_paper").is_empty());
        // 只有底紋的那幾種也一樣 —— 空陣列不是錯誤。
        assert!(guides("blank").is_empty());
        assert!(guides("grid").is_empty());
    }

    #[test]
    fn nonsense_page_sizes_never_produce_guides() {
        assert!(page_guides("cornell".into(), 0.0, 1132.0).is_empty());
        assert!(page_guides("cornell".into(), f32::NAN, 1132.0).is_empty());
        assert!(page_guides("cornell".into(), 800.0, -10.0).is_empty());
    }

    #[test]
    fn every_guide_stays_inside_the_page() {
        // 畫到頁面外面的線在畫布上看得到、匯出時被裁掉 —— 那種錯誤只會在
        // 某一種紙上出現，而且要等到有人列印才發現。
        let (w, h) = (800.0f32, 1132.0f32);
        for t in paper_templates() {
            for g in page_guides(t.id.clone(), w, h) {
                let x2 = g.x + g.w;
                let y2 = g.y + g.h;
                let inside = |v: f32, max: f32| v >= -0.6 && v <= max + 0.6;
                // 文字的 x 是錨點、w 只是可用寬度，所以只檢查錨點本身。
                if g.kind == FfiGuideKind::Label {
                    assert!(
                        inside(g.x, w) && inside(g.y, h),
                        "{} 的文字錨點在頁面外",
                        t.id
                    );
                    continue;
                }
                assert!(
                    inside(g.x, w) && inside(x2, w),
                    "{} 的 x 超出頁面：{} → {}",
                    t.id,
                    g.x,
                    x2
                );
                assert!(
                    inside(g.y, h) && inside(y2, h),
                    "{} 的 y 超出頁面：{} → {}",
                    t.id,
                    g.y,
                    y2
                );
            }
        }
    }

    #[test]
    fn a_landscape_page_does_not_stretch_the_checkboxes() {
        // 勾選框用寬度換算邊長，橫式頁面上仍然是正方形。
        for g in page_guides("todo_list".into(), 1132.0, 800.0) {
            if g.kind == FfiGuideKind::Checkbox {
                assert!(
                    (g.w - g.h).abs() < 0.01,
                    "勾選框被拉成長方形：{} x {}",
                    g.w,
                    g.h
                );
            }
        }
    }

    #[test]
    fn labels_always_carry_a_key_and_shapes_never_do() {
        for t in paper_templates() {
            for g in guides(&t.id) {
                match g.kind {
                    FfiGuideKind::Label => {
                        assert!(!g.text_key.is_empty(), "{} 有一個沒有語系鍵的文字", t.id);
                        assert!(g.size > 0.0, "{} 有一個字級為零的文字", t.id);
                    }
                    _ => assert!(g.text_key.is_empty(), "{} 的圖形不該帶文字", t.id),
                }
            }
        }
    }

    #[test]
    fn the_structured_templates_actually_have_structure() {
        // 這一條擋的是「新增了一種紙、忘了給它版面」—— 清單上看得到，
        // 選下去卻是一張白紙。
        for id in [
            "cornell",
            "quadrant",
            "outline",
            "two_column",
            "qa",
            "kwl",
            "mind_map",
            "monthly_grid",
            "weekly_columns",
            "daily_schedule",
            "timeline_24h",
            "study_planner",
            "project_timeline",
            "todo_list",
            "checklist_two",
            "habit_month",
            "assignment_tracker",
            "chore_roster",
            "challenge_21",
        ] {
            assert!(guides(id).len() > 3, "{id} 幾乎沒有版面");
        }
    }

    #[test]
    fn every_palette_is_a_six_digit_hex_and_the_ids_are_unique() {
        let all = guide_palettes();
        assert!(all.len() >= 4);
        let mut ids: Vec<String> = all.iter().map(|p| p.id.clone()).collect();
        ids.sort();
        let before = ids.len();
        ids.dedup();
        assert_eq!(ids.len(), before, "配色的識別字重複了");
        for p in &all {
            for hex in [&p.accent_hex, &p.band_hex, &p.line_hex, &p.text_hex] {
                assert_eq!(hex.len(), 6, "{} 的 {hex} 不是六位十六進位", p.id);
                assert!(
                    hex.chars().all(|c| c.is_ascii_hexdigit()),
                    "{} 的 {hex} 有非十六進位字元",
                    p.id
                );
            }
            assert_eq!(p.name_key, format!("palette_{}", p.id));
        }
    }

    #[test]
    fn an_unknown_palette_falls_back_instead_of_vanishing() {
        assert_eq!(guide_palette("no_such".into()).id, guide_palettes()[0].id);
        assert_eq!(guide_palette(String::new()).id, guide_palettes()[0].id);
        assert_eq!(guide_palette("rose".into()).id, "rose");
    }
}
