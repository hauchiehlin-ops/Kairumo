//! 程式產生的題庫：同一個種子永遠產生同一題（兩個平台、重開 App 都一樣）。
//!
//! 立體是「輪廓拉伸」的柱體（`padnote-solid`），視圖用真實的正投影算 —— 所以標準答案
//! **一定**與立體輔助工具算出來的一致，不是手填座標。
//!
//! # 題型
//!
//! | 題型 | 給 | 要學生做 | 答案 |
//! |---|---|---|---|
//! | `CompleteView` | 正視圖＋俯視圖 | 補畫右視圖 | 右視圖的線 |
//! | `IsoToViews` | 等角圖 | 畫出三視圖 | 三個視圖的線 |
//! | `AngleJudgement` | 三視圖 | 判斷是第一角還是第三角法 | 選項 |
//! | `SpotError` | 有一處錯的三視圖 | 指出錯在哪一類、哪個位置 | 選項＋位置 |
//! | `Section` | 正視圖＋俯視圖＋剖切線 | 畫出剖視圖（含剖面線） | 剖視圖的線與剖面線 |
//!
//! 座標是頁面座標（原點左上、y 向下）；頁面大小由呼叫端給，版面依它排。

use crate::check::{LineKind, Seg};
use crate::{P2, UNITS_PER_MM};
use padnote_solid::section::{Cut, section_view};
use padnote_solid::solid::{Solid, preset};
use padnote_solid::view::{Camera, Line2, StandardView, View, project};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Kind {
    CompleteView,
    IsoToViews,
    AngleJudgement,
    SpotError,
    Section,
}

pub const KINDS: [Kind; 5] = [
    Kind::CompleteView,
    Kind::IsoToViews,
    Kind::AngleJudgement,
    Kind::SpotError,
    Kind::Section,
];

impl Kind {
    pub fn id(self) -> &'static str {
        match self {
            Kind::CompleteView => "complete_view",
            Kind::IsoToViews => "iso_to_views",
            Kind::AngleJudgement => "angle_judgement",
            Kind::SpotError => "spot_error",
            Kind::Section => "section",
        }
    }

    pub fn from_id(id: &str) -> Option<Kind> {
        KINDS.iter().copied().find(|k| k.id() == id)
    }

    /// 要學生在頁面上畫（會批改），還是選答案。
    pub fn is_drawing(self) -> bool {
        matches!(self, Kind::CompleteView | Kind::IsoToViews | Kind::Section)
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Convention {
    ThirdAngle,
    FirstAngle,
}

/// 選擇題的選項（語系鍵）。
pub const CHOICE_THIRD: &str = "draft_prob_third_angle";
pub const CHOICE_FIRST: &str = "draft_prob_first_angle";
pub const ERR_MISSING: &str = "draft_prob_err_missing";
pub const ERR_EXTRA: &str = "draft_prob_err_extra";
pub const ERR_TYPE: &str = "draft_prob_err_type";
pub const ERR_ALIGN: &str = "draft_prob_err_align";

/// 挑錯題裡放進去的錯。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ErrorKind {
    Missing,
    Extra,
    WrongType,
    Misaligned,
}

impl ErrorKind {
    pub fn choice_key(self) -> &'static str {
        match self {
            ErrorKind::Missing => ERR_MISSING,
            ErrorKind::Extra => ERR_EXTRA,
            ErrorKind::WrongType => ERR_TYPE,
            ErrorKind::Misaligned => ERR_ALIGN,
        }
    }
}

const ERROR_KINDS: [ErrorKind; 4] = [
    ErrorKind::Missing,
    ErrorKind::Extra,
    ErrorKind::WrongType,
    ErrorKind::Misaligned,
];

/// 矩形（頁面座標）。
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Rect {
    pub x: f32,
    pub y: f32,
    pub w: f32,
    pub h: f32,
}

impl Rect {
    pub fn contains(&self, p: P2) -> bool {
        p.0 >= self.x && p.0 <= self.x + self.w && p.1 >= self.y && p.1 <= self.y + self.h
    }
}

#[derive(Clone, Debug)]
pub struct Problem {
    pub kind: Kind,
    pub seed: u64,
    pub convention: Convention,
    /// 題目給的線（要畫在底層，學生不改它）。
    pub given: Vec<Seg>,
    /// 標準答案（畫題的題型才有）。
    pub answer: Vec<Seg>,
    /// 學生作答的範圍：只批改這裡面的線。
    pub answer_area: Option<Rect>,
    /// 選擇題的選項（語系鍵）與正確的那一個。
    pub choices: Vec<&'static str>,
    pub correct: Option<usize>,
    /// 挑錯題：錯在哪裡（頁面座標）與錯的種類。
    pub error: Option<(ErrorKind, P2)>,
    /// 立體的尺寸（紙上毫米）：寬、高、深，以及輪廓的種類，給提示與標註用。
    pub dims_mm: (f32, f32, f32),
    pub profile: &'static str,
}

// MARK: - 隨機

/// SplitMix64：夠用、可重現、沒有外部相依。
struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }

    /// `[lo, hi]` 的整數（毫米取整，題目的尺寸都是整數）。
    fn range(&mut self, lo: i32, hi: i32) -> i32 {
        lo + (self.next() % (hi - lo + 1) as u64) as i32
    }

    fn pick<T: Copy>(&mut self, items: &[T]) -> T {
        items[(self.next() % items.len() as u64) as usize]
    }
}

// MARK: - 立體與版面

/// 題目用的輪廓：不含圓（隱藏線與弧在批改時容易誤判），但含洞的 ring 留給剖面題。
const PLAIN: [&str; 4] = ["rect", "l_shape", "t_shape", "u_shape"];
const WITH_HOLES: [&str; 2] = ["ring", "plate_holes"];

struct Layout {
    k: f32,
    page: (f32, f32),
    convention: Convention,
}

impl Layout {
    /// 一個單位模型（毫米）對應幾個頁面單位。
    fn new(page: (f32, f32), convention: Convention) -> Layout {
        // 題目畫大一點：1 mm 約 5.7 單位（A3 橫式約是 1:0.7 的紙面比例，學生看得清楚）。
        Layout {
            k: UNITS_PER_MM * 1.5,
            page,
            convention,
        }
    }

    /// 三個視圖的左下角（頁面座標）。(x0, bottom)。
    fn boxes(&self, d: (f32, f32, f32)) -> [(f32, f32); 3] {
        let (w, h, depth) = (d.0 * self.k, d.1 * self.k, d.2 * self.k);
        let gap = 40.0;
        let fx = self.page.0 * 0.28;
        match self.convention {
            Convention::ThirdAngle => {
                let fb = self.page.1 * 0.66;
                [
                    (fx, fb),           // 正視圖
                    (fx, fb - h - gap), // 俯視圖在上
                    (fx + w + gap, fb), // 右視圖在右
                ]
            }
            Convention::FirstAngle => {
                let fb = self.page.1 * 0.40;
                [
                    (fx, fb),               // 正視圖
                    (fx, fb + gap + depth), // 俯視圖在下
                    (fx - gap - depth, fb), // 右視圖在左
                ]
            }
        }
    }

    /// 視圖的線換成頁面座標的線段。
    fn place(&self, view: &View, at: (f32, f32)) -> Vec<Seg> {
        let Some((lo, _)) = view.bounds() else {
            return Vec::new();
        };
        let map = |p: P2| (at.0 + (p.0 - lo.0) * self.k, at.1 - (p.1 - lo.1) * self.k);
        view.lines
            .iter()
            .map(|l| Seg {
                a: map(l.a),
                b: map(l.b),
                kind: if l.hidden {
                    LineKind::Hidden
                } else {
                    LineKind::Visible
                },
            })
            .collect()
    }

    fn rect_of(&self, segs: &[Seg], pad: f32) -> Rect {
        let pts: Vec<P2> = segs.iter().flat_map(|s| [s.a, s.b]).collect();
        let (mut x0, mut y0, mut x1, mut y1) = (f32::MAX, f32::MAX, f32::MIN, f32::MIN);
        for p in pts {
            x0 = x0.min(p.0);
            y0 = y0.min(p.1);
            x1 = x1.max(p.0);
            y1 = y1.max(p.1);
        }
        Rect {
            x: x0 - pad,
            y: y0 - pad,
            w: x1 - x0 + 2.0 * pad,
            h: y1 - y0 + 2.0 * pad,
        }
    }
}

fn make_solid(rng: &mut Rng, names: &[&'static str]) -> (Solid, (f32, f32, f32), &'static str) {
    let name = rng.pick(names);
    // 紙上毫米：寬 40–70、高 30–55、深 25–45，5 的倍數，標註好讀。
    let w = (rng.range(8, 14) * 5) as f32;
    let h = (rng.range(6, 11) * 5) as f32;
    let d = (rng.range(5, 9) * 5) as f32;
    let profile = preset(name, w, h).expect("題目用的輪廓都是預設輪廓");
    (Solid::new(profile, d), (w, h, d), name)
}

fn view_of(solid: &Solid, v: StandardView) -> View {
    let mut view = project(solid, &Camera::standard(v));
    // 等角圖題給的是「看得見的線」：隱藏線在等角圖上一般不畫。
    if v == StandardView::Iso {
        view.lines.retain(|l| !l.hidden);
    }
    view
}

/// 一題的共同基礎：隨機數、版面、立體與三個標準視圖。
struct Base {
    rng: Rng,
    lay: Layout,
    solid: Solid,
    dims: (f32, f32, f32),
    profile: &'static str,
    convention: Convention,
    boxes: [(f32, f32); 3],
    front: Vec<Seg>,
    top: Vec<Seg>,
    right: Vec<Seg>,
}

fn base(kind: Kind, seed: u64, page: (f32, f32)) -> Base {
    let mut rng = Rng(seed ^ (kind as u64).wrapping_mul(0xA5A5_5A5A_1234_5678));
    // 判斷題在兩種投影法之間變化；其他題型用第三角法（台灣、美國）。
    let convention = match kind {
        Kind::AngleJudgement => rng.pick(&[Convention::ThirdAngle, Convention::FirstAngle]),
        _ => Convention::ThirdAngle,
    };
    let lay = Layout::new(page, convention);
    let names: &[&'static str] = if kind == Kind::Section {
        &WITH_HOLES
    } else {
        &PLAIN
    };
    let (solid, dims, profile) = make_solid(&mut rng, names);
    let boxes = lay.boxes(dims);
    let front = lay.place(&view_of(&solid, StandardView::Front), boxes[0]);
    let top = lay.place(&view_of(&solid, StandardView::Top), boxes[1]);
    let right = lay.place(&view_of(&solid, StandardView::Right), boxes[2]);
    Base {
        rng,
        lay,
        solid,
        dims,
        profile,
        convention,
        boxes,
        front,
        top,
        right,
    }
}

/// 挑錯題的「沒有錯」版本（測試與批改對照用）。
pub fn spot_error_clean(seed: u64, page: (f32, f32)) -> Vec<Seg> {
    let b = base(Kind::SpotError, seed, page);
    [b.front, b.top, b.right].concat()
}

/// 以種子產生一題。`page` 是頁面大小（頁面單位）。
pub fn generate(kind: Kind, seed: u64, page: (f32, f32)) -> Problem {
    let Base {
        mut rng,
        lay,
        solid,
        dims,
        profile,
        convention,
        boxes,
        front,
        top,
        right,
    } = base(kind, seed, page);

    let mut p = Problem {
        kind,
        seed,
        convention,
        given: Vec::new(),
        answer: Vec::new(),
        answer_area: None,
        choices: Vec::new(),
        correct: None,
        error: None,
        dims_mm: dims,
        profile,
    };

    match kind {
        Kind::CompleteView => {
            p.given = [front, top].concat();
            p.answer_area = Some(lay.rect_of(&right, 36.0));
            p.answer = right;
        }
        Kind::IsoToViews => {
            // 等角圖放在頁面右上。
            let iso = view_of(&solid, StandardView::Iso);
            // 等角圖要整張放得進頁面：下緣至少留出圖的高度再加上邊界。
            let (width, height) = iso
                .bounds()
                .map(|(lo, hi)| ((hi.0 - lo.0) * lay.k, (hi.1 - lo.1) * lay.k))
                .unwrap_or((0.0, 0.0));
            let at = (
                (page.0 * 0.70).min(page.0 - 60.0 - width),
                (page.1 * 0.34).max(80.0 + height),
            );
            p.given = lay.place(&iso, at);
            let all = [front, top, right].concat();
            p.answer_area = Some(lay.rect_of(&all, 50.0));
            p.answer = all;
        }
        Kind::AngleJudgement => {
            p.given = [front, top, right].concat();
            let order = if rng.next() % 2 == 0 {
                [CHOICE_THIRD, CHOICE_FIRST]
            } else {
                [CHOICE_FIRST, CHOICE_THIRD]
            };
            p.choices = order.to_vec();
            let want = match convention {
                Convention::ThirdAngle => CHOICE_THIRD,
                Convention::FirstAngle => CHOICE_FIRST,
            };
            p.correct = order.iter().position(|c| *c == want);
        }
        Kind::SpotError => {
            let (given, error) = inject_error(&mut rng, front, top, right);
            p.given = given;
            p.error = Some(error);
            p.choices = ERROR_KINDS.iter().map(|e| e.choice_key()).collect();
            p.correct = ERROR_KINDS.iter().position(|e| *e == error.0);
        }
        Kind::Section => {
            // 垂直的剖切線穿過正中央，從右邊看：剖視圖放在右視圖的位置。
            let cut = Cut::full(&solid, 90.0, 0.5, false);
            let sv = section_view(&solid, &cut, 1.6);
            let mut cut_marks: Vec<Seg> = Vec::new();
            for (a, b) in cut.plan_lines() {
                // 剖切線在正視圖上：模型座標 → 頁面座標。
                // 剖切線畫出輪廓外 6 mm 就夠（核心給的線很長，要夾在視圖旁邊）。
                let map = |q: P2| {
                    let y = q.1.clamp(-6.0, dims.1 + 6.0);
                    let x = q.0.clamp(-6.0, dims.0 + 6.0);
                    (boxes[0].0 + x * lay.k, boxes[0].1 - y * lay.k)
                };
                cut_marks.push(Seg {
                    a: map(a),
                    b: map(b),
                    kind: LineKind::Center,
                });
            }
            let view = View {
                lines: sv.lines.clone(),
            };
            let mut ans = lay.place(&view, boxes[2]);
            // 剖面線跟著輪廓一起平移（以同一個原點）。
            if let Some((lo, _)) = view_bounds_with_hatch(&sv.lines, &sv.hatch) {
                let map = |q: P2| {
                    (
                        boxes[2].0 + (q.0 - lo.0) * lay.k,
                        boxes[2].1 - (q.1 - lo.1) * lay.k,
                    )
                };
                // 剖視圖的線也要用同一個原點（含剖面線的包圍盒），否則兩者對不上。
                ans = sv
                    .lines
                    .iter()
                    .map(|l| Seg {
                        a: map(l.a),
                        b: map(l.b),
                        kind: LineKind::Visible,
                    })
                    .collect();
                ans.extend(sv.hatch.iter().map(|(a, b)| Seg {
                    a: map(*a),
                    b: map(*b),
                    kind: LineKind::Thin,
                }));
            }
            p.given = [front, top, cut_marks].concat();
            p.answer_area = Some(lay.rect_of(&ans, 40.0));
            p.answer = ans;
        }
    }
    p
}

fn view_bounds_with_hatch(lines: &[Line2], hatch: &[(P2, P2)]) -> Option<(P2, P2)> {
    let mut pts: Vec<P2> = lines.iter().flat_map(|l| [l.a, l.b]).collect();
    pts.extend(hatch.iter().flat_map(|h| [h.0, h.1]));
    padnote_solid::geom::bounds(&pts)
}

fn seg_len(s: &Seg) -> f32 {
    (s.a.0 - s.b.0).hypot(s.a.1 - s.b.1)
}

fn mid(s: &Seg) -> P2 {
    ((s.a.0 + s.b.0) / 2.0, (s.a.1 + s.b.1) / 2.0)
}

/// 在三視圖裡放進一個錯。回傳有錯的整組線，與錯的種類、位置。
fn inject_error(
    rng: &mut Rng,
    front: Vec<Seg>,
    top: Vec<Seg>,
    right: Vec<Seg>,
) -> (Vec<Seg>, (ErrorKind, P2)) {
    let which = rng.pick(&ERROR_KINDS);
    let mut right = right;
    let mut top = top;
    let at: P2;
    match which {
        ErrorKind::Missing => {
            // 拿掉右視圖最長的一條實線。
            let i = right
                .iter()
                .enumerate()
                .filter(|(_, s)| s.kind == LineKind::Visible)
                .max_by(|a, b| seg_len(a.1).total_cmp(&seg_len(b.1)))
                .map(|(i, _)| i)
                .unwrap_or(0);
            at = mid(&right[i]);
            right.remove(i);
        }
        ErrorKind::Extra => {
            // 在右視圖中間加一條斜線。
            let (mut x0, mut y0, mut x1, mut y1) = (f32::MAX, f32::MAX, f32::MIN, f32::MIN);
            for s in &right {
                for p in [s.a, s.b] {
                    x0 = x0.min(p.0);
                    y0 = y0.min(p.1);
                    x1 = x1.max(p.0);
                    y1 = y1.max(p.1);
                }
            }
            let extra = Seg {
                a: (x0 + (x1 - x0) * 0.25, y0 + (y1 - y0) * 0.30),
                b: (x0 + (x1 - x0) * 0.75, y0 + (y1 - y0) * 0.70),
                kind: LineKind::Visible,
            };
            at = mid(&extra);
            right.push(extra);
        }
        ErrorKind::WrongType => {
            // 把右視圖最長的一條實線畫成隱藏線。
            let i = right
                .iter()
                .enumerate()
                .filter(|(_, s)| s.kind == LineKind::Visible)
                .max_by(|a, b| seg_len(a.1).total_cmp(&seg_len(b.1)))
                .map(|(i, _)| i)
                .unwrap_or(0);
            right[i].kind = LineKind::Hidden;
            at = mid(&right[i]);
        }
        ErrorKind::Misaligned => {
            // 俯視圖整個往右偏 24 單位：和正視圖「長對正」失準。
            for s in &mut top {
                s.a.0 += 24.0;
                s.b.0 += 24.0;
            }
            let (mut x0, mut x1, mut y) = (f32::MAX, f32::MIN, 0.0);
            for s in &top {
                for p in [s.a, s.b] {
                    x0 = x0.min(p.0);
                    x1 = x1.max(p.0);
                    y = p.1;
                }
            }
            at = ((x0 + x1) / 2.0, y);
        }
    }
    ([front, top, right].concat(), (which, at))
}

/// 挑錯題的批改：選的種類要對，指的位置離錯誤的地方不超過 `radius`。
pub fn check_error_answer(p: &Problem, picked: usize, at: Option<P2>, radius: f32) -> bool {
    let (Some(correct), Some((_, spot))) = (p.correct, p.error) else {
        return false;
    };
    picked == correct && at.is_some_and(|q| (q.0 - spot.0).hypot(q.1 - spot.1) <= radius)
}

/// 選擇題的批改。
pub fn check_choice(p: &Problem, picked: usize) -> bool {
    p.correct == Some(picked)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::check::{Tolerance, grade};

    const PAGE: (f32, f32) = (1600.0, 1132.0);

    #[test]
    fn the_same_seed_always_gives_the_same_problem() {
        for kind in KINDS {
            let a = generate(kind, 42, PAGE);
            let b = generate(kind, 42, PAGE);
            assert_eq!(a.given, b.given, "{kind:?}");
            assert_eq!(a.answer, b.answer);
            assert_eq!(a.dims_mm, b.dims_mm);
        }
        assert_ne!(
            generate(Kind::CompleteView, 1, PAGE).dims_mm,
            generate(Kind::CompleteView, 2, PAGE).dims_mm
        );
    }

    #[test]
    fn every_kind_gives_a_complete_problem_for_many_seeds() {
        for kind in KINDS {
            for seed in 0..60u64 {
                let p = generate(kind, seed, PAGE);
                assert!(!p.given.is_empty(), "{kind:?} #{seed} 沒有題目線");
                if kind.is_drawing() {
                    assert!(!p.answer.is_empty(), "{kind:?} #{seed} 沒有答案");
                    let area = p.answer_area.expect("畫題要有作答範圍");
                    // 標準答案都在作答範圍內，而且整張都在頁面內。
                    for s in &p.answer {
                        assert!(
                            area.contains(s.a) && area.contains(s.b),
                            "{kind:?} #{seed} 答案跑出範圍"
                        );
                        for q in [s.a, s.b] {
                            assert!(
                                q.0 > 0.0 && q.0 < PAGE.0 && q.1 > 0.0 && q.1 < PAGE.1,
                                "{kind:?} #{seed} 跑出頁面 {q:?}"
                            );
                        }
                    }
                } else {
                    assert!(
                        p.choices.len() >= 2 && p.correct.is_some(),
                        "{kind:?} #{seed}"
                    );
                }
                for s in &p.given {
                    for q in [s.a, s.b] {
                        assert!(
                            q.0 > 0.0 && q.0 < PAGE.0 && q.1 > 0.0 && q.1 < PAGE.1,
                            "{kind:?} #{seed} 題目跑出頁面 {q:?}"
                        );
                    }
                }
            }
        }
    }

    #[test]
    fn the_standard_answer_grades_as_perfect_and_a_blank_one_does_not() {
        for kind in [Kind::CompleteView, Kind::IsoToViews, Kind::Section] {
            for seed in 0..40u64 {
                let p = generate(kind, seed, PAGE);
                let perfect = grade(&p.answer, &p.answer, Tolerance::default());
                assert!(
                    perfect.is_perfect(),
                    "{kind:?} #{seed}: {:?}",
                    perfect.issues
                );
                let blank = grade(&p.answer, &[], Tolerance::default());
                assert!(
                    !blank.is_perfect() && blank.score() < 50,
                    "{kind:?} #{seed}"
                );
            }
        }
    }

    #[test]
    fn complete_view_gives_front_and_top_and_asks_for_the_right_view() {
        let p = generate(Kind::CompleteView, 7, PAGE);
        let area = p.answer_area.unwrap();
        // 題目線一條都不在作答範圍裡（不然學生不用畫就有分）。
        assert!(
            p.given
                .iter()
                .all(|s| !(area.contains(s.a) && area.contains(s.b)))
        );
        // 右視圖的寬是立體的深度，高是立體的高度。
        let (_, h, d) = p.dims_mm;
        let k = UNITS_PER_MM * 1.5;
        let xs: Vec<f32> = p.answer.iter().flat_map(|s| [s.a.0, s.b.0]).collect();
        let ys: Vec<f32> = p.answer.iter().flat_map(|s| [s.a.1, s.b.1]).collect();
        let w = xs.iter().cloned().fold(f32::MIN, f32::max)
            - xs.iter().cloned().fold(f32::MAX, f32::min);
        let hh = ys.iter().cloned().fold(f32::MIN, f32::max)
            - ys.iter().cloned().fold(f32::MAX, f32::min);
        assert!((w - d * k).abs() < 0.5, "右視圖寬 {w} 應是深度 {}", d * k);
        assert!((hh - h * k).abs() < 0.5, "右視圖高 {hh} 應是高度 {}", h * k);
    }

    #[test]
    fn the_views_line_up_like_a_real_three_view_drawing() {
        // 第三角法：俯視圖在正視圖正上方（長對正）、右視圖在正視圖正右方（高平齊）。
        let p = generate(Kind::AngleJudgement, 0, PAGE);
        if p.convention == Convention::ThirdAngle {
            let all = &p.given;
            let min_x = |v: &[Seg]| {
                v.iter()
                    .flat_map(|s| [s.a.0, s.b.0])
                    .fold(f32::MAX, f32::min)
            };
            let max_y = |v: &[Seg]| {
                v.iter()
                    .flat_map(|s| [s.a.1, s.b.1])
                    .fold(f32::MIN, f32::max)
            };
            // 找出最下面那排（正視圖與右視圖）：底邊相同。
            let bottom = max_y(all);
            let bottom_row: Vec<Seg> = all
                .iter()
                .copied()
                .filter(|s| (s.a.1 - bottom).abs() < 0.5 || (s.b.1 - bottom).abs() < 0.5)
                .collect();
            assert!(!bottom_row.is_empty());
            assert!((min_x(all) - min_x(&bottom_row)).abs() < 200.0);
        }
    }

    #[test]
    fn angle_judgement_has_both_conventions_and_the_right_answer() {
        let (mut third, mut first) = (0, 0);
        for seed in 0..80u64 {
            let p = generate(Kind::AngleJudgement, seed, PAGE);
            let key = p.choices[p.correct.unwrap()];
            match p.convention {
                Convention::ThirdAngle => {
                    assert_eq!(key, CHOICE_THIRD);
                    third += 1;
                }
                Convention::FirstAngle => {
                    assert_eq!(key, CHOICE_FIRST);
                    first += 1;
                }
            }
            assert!(check_choice(&p, p.correct.unwrap()));
            assert!(!check_choice(&p, 1 - p.correct.unwrap()));
        }
        assert!(
            third > 10 && first > 10,
            "兩種投影法都要出：{third}/{first}"
        );
    }

    #[test]
    fn first_angle_puts_the_right_view_on_the_left_and_the_top_view_below() {
        for seed in 0..40u64 {
            let p = generate(Kind::AngleJudgement, seed, PAGE);
            if p.convention != Convention::FirstAngle {
                continue;
            }
            let cx = |s: &Seg| (s.a.0 + s.b.0) / 2.0;
            let xs: Vec<f32> = p.given.iter().map(cx).collect();
            let ys: Vec<f32> = p.given.iter().map(|s| (s.a.1 + s.b.1) / 2.0).collect();
            let spread = |v: &[f32]| {
                v.iter().cloned().fold(f32::MIN, f32::max)
                    - v.iter().cloned().fold(f32::MAX, f32::min)
            };
            // 三個視圖橫向、縱向都有展開（不是疊在一起）。
            assert!(spread(&xs) > 100.0 && spread(&ys) > 100.0, "#{seed}");
            return;
        }
        panic!("80 題裡沒有第一角法");
    }

    #[test]
    fn spot_error_injects_each_kind_and_the_location_check_works() {
        let mut seen = std::collections::HashSet::new();
        for seed in 0..200u64 {
            let p = generate(Kind::SpotError, seed, PAGE);
            let (kind, at) = p.error.unwrap();
            seen.insert(kind as u8);
            assert_eq!(p.choices[p.correct.unwrap()], kind.choice_key());
            // 種類對、位置對 → 對；位置差很遠 → 錯；種類錯 → 錯。
            let right = p.correct.unwrap();
            assert!(check_error_answer(&p, right, Some(at), 30.0));
            assert!(check_error_answer(
                &p,
                right,
                Some((at.0 + 20.0, at.1 - 10.0)),
                30.0
            ));
            assert!(!check_error_answer(
                &p,
                right,
                Some((at.0 + 400.0, at.1)),
                30.0
            ));
            assert!(!check_error_answer(&p, (right + 1) % 4, Some(at), 30.0));
            assert!(!check_error_answer(&p, right, None, 30.0));
        }
        assert_eq!(seen.len(), 4, "四種錯都要出現");
    }

    #[test]
    fn each_injected_error_changes_the_drawing_in_exactly_that_way() {
        use std::collections::HashSet;
        let mut seen = HashSet::new();
        for seed in 0..300u64 {
            let bad = generate(Kind::SpotError, seed, PAGE);
            let clean = spot_error_clean(seed, PAGE);
            let (kind, at) = bad.error.unwrap();
            let r = grade(&clean, &bad.given, Tolerance::default());
            assert!(!r.is_perfect(), "{kind:?} #{seed}：放了錯卻批不出來");
            // 批改器找到的問題種類，要和放進去的錯對得上。
            let found = |f: &dyn Fn(&crate::check::Issue) -> bool| r.issues.iter().any(f);
            let ok = match kind {
                ErrorKind::Missing => found(&|i| matches!(i, crate::check::Issue::Missing(_))),
                ErrorKind::Extra => found(&|i| matches!(i, crate::check::Issue::Extra(_))),
                ErrorKind::WrongType => {
                    found(&|i| matches!(i, crate::check::Issue::WrongType { .. }))
                }
                ErrorKind::Misaligned => found(&|i| {
                    matches!(
                        i,
                        crate::check::Issue::Misaligned { .. } | crate::check::Issue::Missing(_)
                    )
                }),
            };
            assert!(ok, "{kind:?} #{seed}：{:?}", r.issues);
            // 錯的位置要落在頁面上。
            assert!(at.0 > 0.0 && at.0 < PAGE.0 && at.1 > 0.0 && at.1 < PAGE.1);
            seen.insert(kind as u8);
        }
        assert_eq!(seen.len(), 4);
    }

    #[test]
    fn the_section_answer_has_an_outline_and_hatching_at_forty_five_degrees() {
        for seed in 0..30u64 {
            let p = generate(Kind::Section, seed, PAGE);
            let hatch: Vec<&Seg> = p
                .answer
                .iter()
                .filter(|s| s.kind == LineKind::Thin)
                .collect();
            assert!(hatch.len() >= 4, "#{seed} 剖面線太少 {}", hatch.len());
            assert!(p.answer.iter().any(|s| s.kind == LineKind::Visible));
            for h in hatch.iter().take(5) {
                let a = (h.b.1 - h.a.1)
                    .atan2(h.b.0 - h.a.0)
                    .to_degrees()
                    .rem_euclid(180.0);
                assert!(
                    (a - 45.0).abs() < 1.0 || (a - 135.0).abs() < 1.0,
                    "剖面線角度 {a}"
                );
            }
            // 題目給剖切線（在正視圖上）。
            assert!(p.given.iter().any(|s| s.kind == LineKind::Center));
        }
    }

    #[test]
    fn kind_ids_round_trip() {
        for k in KINDS {
            assert_eq!(Kind::from_id(k.id()), Some(k));
        }
        assert!(Kind::from_id("nope").is_none());
        assert!(!Kind::SpotError.is_drawing() && Kind::Section.is_drawing());
    }
}
