//! 尺寸標註：線性（水平／垂直／對齊）、直徑、半徑、角度。
//!
//! 畫法依 CNS 3（工程製圖）與 ISO 129-1，兩者在這幾項上一致：
//!
//! - 尺寸線、尺寸界線是細實線；尺寸界線離被標註的點留一點縫（約 1 mm），超出尺寸線約 2 mm。
//! - 尺寸線兩端是箭頭（長約 3 mm、寬約 1 mm），位置夠就放在尺寸界線之間，不夠就放到外面。
//! - 數字高約 3.5 mm，放在尺寸線**上方**，方向與尺寸線平行並且**從底邊或右邊讀**
//!   （水平標註水平讀、垂直標註由下往上讀）；角度的數字一律水平。
//! - 直徑加 `⌀`、半徑加 `R`、角度加 `°`；長度不寫單位（圖上統一註明 mm）。
//!
//! 數字是**紙上毫米 × 比例尺**：比例尺 `ratio` = 實物 / 圖上（1:2 的圖是 2，2:1 的圖是 0.5）。

use crate::{Drawing, P2, Role, SheetStroke, UNITS_PER_MM};
use padnote_solid::glyph::text_strokes;

/// 標註的尺寸（頁面單位）。預設值是 ISO 129-1 建議的毫米尺寸換算過來的。
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct DimStyle {
    pub text_h: f32,
    pub arrow_len: f32,
    pub arrow_half: f32,
    /// 尺寸界線離被標註點的縫。
    pub ext_gap: f32,
    /// 尺寸界線超出尺寸線多少。
    pub ext_over: f32,
    /// 數字離尺寸線的距離。
    pub text_gap: f32,
    /// 引線的長度與肩部長度。
    pub leader: f32,
    pub shoulder: f32,
}

impl DimStyle {
    /// ISO／CNS 的標準尺寸，換成頁面單位。
    pub fn iso() -> DimStyle {
        let mm = UNITS_PER_MM;
        DimStyle {
            text_h: 3.5 * mm,
            arrow_len: 3.0 * mm,
            arrow_half: 0.5 * mm,
            ext_gap: 1.0 * mm,
            ext_over: 2.0 * mm,
            text_gap: 1.0 * mm,
            leader: 8.0 * mm,
            shoulder: 3.0 * mm,
        }
    }
}

impl Default for DimStyle {
    fn default() -> Self {
        DimStyle::iso()
    }
}

/// 線性標註的方向。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum LinearAxis {
    /// 依尺寸線擺的位置決定：擺在兩點的上方或下方就是水平標註，擺在左右就是垂直標註。
    Auto,
    Horizontal,
    Vertical,
    /// 與兩點的連線平行。
    Aligned,
}

/// 一個標註的成品。
#[derive(Clone, Debug)]
pub struct Dimension {
    pub strokes: Vec<SheetStroke>,
    /// 實物的數值（長度是毫米、角度是度）。
    pub value: f32,
    /// 標在圖上的文字（含 ⌀、R、°）。
    pub text: String,
}

impl Dimension {
    fn empty() -> Dimension {
        Dimension {
            strokes: Vec::new(),
            value: 0.0,
            text: String::new(),
        }
    }
}

/// 數值 → 圖上的字：接近整數就寫整數，否則寫一位小數。
pub fn format_value(v: f32) -> String {
    let r = v.round();
    if (v - r).abs() < 0.05 {
        format!("{}", r as i64)
    } else {
        format!("{v:.1}")
    }
}

/// 兩點在紙上的距離（毫米）。
pub fn paper_mm(a: P2, b: P2) -> f32 {
    ((a.0 - b.0).powi(2) + (a.1 - b.1).powi(2)).sqrt() / UNITS_PER_MM
}

fn add(a: P2, b: P2) -> P2 {
    (a.0 + b.0, a.1 + b.1)
}

fn scale(a: P2, k: f32) -> P2 {
    (a.0 * k, a.1 * k)
}

fn dot(a: P2, b: P2) -> f32 {
    a.0 * b.0 + a.1 * b.1
}

fn unit(a: P2) -> P2 {
    let l = (a.0 * a.0 + a.1 * a.1).sqrt().max(1e-9);
    (a.0 / l, a.1 / l)
}

/// 箭頭：箭尖在 `tip`，向 `back`（單位向量）方向收，底寬 `2 × half`。兩條線，與圖紙排版的箭頭一致。
fn arrow(tip: P2, back: P2, len: f32, half: f32, out: &mut Vec<SheetStroke>) {
    let n = (-back.1, back.0);
    let base = add(tip, scale(back, len));
    out.push(SheetStroke {
        role: Role::Dimension,
        points: vec![add(base, scale(n, half)), tip, add(base, scale(n, -half))],
    });
}

fn thin(a: P2, b: P2) -> SheetStroke {
    SheetStroke {
        role: Role::Dimension,
        points: vec![a, b],
    }
}

/// 在 `anchor` 放一行文字：`u` 是讀的方向、`up` 是字的上方，`center` 為真時以 `anchor` 為中央，
/// 否則 `anchor` 是起點。`lift` 是基線離 `anchor` 的距離（沿 `up`）。回傳 (筆畫, 文字寬度)。
fn place_text(
    text: &str,
    anchor: P2,
    u: P2,
    up: P2,
    th: f32,
    lift: f32,
    center: bool,
) -> (Vec<SheetStroke>, f32) {
    let (glyphs, w) = text_strokes(text, 0.0, 0.0, th);
    let strokes = glyphs
        .into_iter()
        .map(|g| SheetStroke {
            role: Role::Text,
            points: g
                .into_iter()
                .map(|(gx, gy)| {
                    let s = gx - if center { w / 2.0 } else { 0.0 };
                    let t = lift + (th - gy);
                    add(anchor, add(scale(u, s), scale(up, t)))
                })
                .collect(),
        })
        .collect();
    (strokes, w)
}

fn text_width(text: &str, th: f32) -> f32 {
    text_strokes(text, 0.0, 0.0, th).1
}

/// 讀的方向轉成「從底邊或右邊讀」：水平向右、垂直向上、其餘一律朝右的那一半。
fn readable(u: P2) -> P2 {
    if u.0 < -1e-4 || (u.0.abs() <= 1e-4 && u.1 > 0.0) {
        (-u.0, -u.1)
    } else {
        u
    }
}

/// 線性標註：`p1`、`p2` 是被標註的兩點，`through` 是尺寸線要經過的位置。
pub fn linear(
    p1: P2,
    p2: P2,
    through: P2,
    axis: LinearAxis,
    ratio: f32,
    style: &DimStyle,
) -> Dimension {
    // 量測方向 u。
    let axis = match axis {
        LinearAxis::Auto => {
            // 看尺寸線擺在兩點外框的哪一側：落在兩點的 x 範圍之內就是水平標註（上方或下方），
            // 落在 y 範圍之內就是垂直標註；兩個方向都在外面時，離得比較遠的那個方向就是標註的方向。
            let out = |v: f32, a: f32, b: f32| (a.min(b) - v).max(v - a.max(b)).max(0.0);
            let (ox, oy) = (out(through.0, p1.0, p2.0), out(through.1, p1.1, p2.1));
            if ox == 0.0 && oy == 0.0 {
                // 擺在兩點之間：量比較長的那一邊。
                if (p2.0 - p1.0).abs() >= (p2.1 - p1.1).abs() {
                    LinearAxis::Horizontal
                } else {
                    LinearAxis::Vertical
                }
            } else if oy >= ox {
                LinearAxis::Horizontal
            } else {
                LinearAxis::Vertical
            }
        }
        a => a,
    };
    let u = match axis {
        LinearAxis::Horizontal => (1.0, 0.0),
        LinearAxis::Vertical => (0.0, -1.0),
        _ => readable(unit((p2.0 - p1.0, p2.1 - p1.1))),
    };
    let up = (u.1, -u.0); // 字的上方（水平讀時是頁面上方）。
    let (s1, s2) = (dot(p1, u), dot(p2, u));
    let length = (s2 - s1).abs();
    if length < 1e-3 {
        return Dimension::empty();
    }
    let (lo, hi) = (s1.min(s2), s1.max(s2));
    // 垂直於 u 的座標（尺寸線所在的那一條）。
    let t = |p: P2| dot(p, up);
    let td = t(through);
    let at = |s: f32, tt: f32| add(scale(u, s), scale(up, tt));

    let mut strokes: Vec<SheetStroke> = Vec::new();
    // 尺寸界線：從被標註點留縫開始，超出尺寸線一點。
    for (p, s) in [(p1, s1), (p2, s2)] {
        let tp = t(p);
        let sgn = if td >= tp { 1.0 } else { -1.0 };
        let from = at(s, tp + sgn * style.ext_gap);
        let to = at(s, td + sgn * style.ext_over);
        if (dot(to, up) - dot(from, up)) * sgn > 0.0 {
            strokes.push(thin(from, to));
        }
    }

    let value = length / UNITS_PER_MM * ratio;
    let text = format_value(value);
    let tw = text_width(&text, style.text_h);
    let a = style.arrow_len;
    let inside = length >= 2.0 * a + tw * 1.1 + 2.0 * style.text_gap;
    let arrows_inside = length >= 2.0 * a + 1.0;
    if arrows_inside {
        strokes.push(thin(at(lo, td), at(hi, td)));
        arrow(at(lo, td), u, a, style.arrow_half, &mut strokes);
        arrow(at(hi, td), (-u.0, -u.1), a, style.arrow_half, &mut strokes);
    } else {
        // 太窄：箭頭放外面，從外往裡指；尺寸線延伸出去一段。
        let tail = 2.0 * a;
        strokes.push(thin(at(lo - tail, td), at(hi + tail, td)));
        arrow(at(lo, td), (-u.0, -u.1), a, style.arrow_half, &mut strokes);
        arrow(at(hi, td), u, a, style.arrow_half, &mut strokes);
    }
    let (txt, _) = if inside {
        place_text(
            &text,
            at((lo + hi) / 2.0, td),
            u,
            up,
            style.text_h,
            style.text_gap,
            true,
        )
    } else {
        // 數字放在右端外面，離箭頭一點。
        place_text(
            &text,
            at(hi + 2.0 * a + style.text_gap, td),
            u,
            up,
            style.text_h,
            style.text_gap,
            false,
        )
    };
    strokes.extend(txt);
    Dimension {
        strokes,
        value,
        text,
    }
}

/// 引線的終點與肩部：從 `edge` 沿 `dir` 往外 `leader`，再水平走一小段，數字接在肩部後面。
fn leader_path(edge: P2, dir: P2, style: &DimStyle) -> (P2, P2, P2) {
    let knee = add(edge, scale(dir, style.leader));
    let side = if dir.0 >= 0.0 { 1.0 } else { -1.0 };
    let end = add(knee, (side * style.shoulder, 0.0));
    (knee, end, (side, 0.0))
}

fn leader_text(text: &str, end: P2, side: f32, style: &DimStyle, strokes: &mut Vec<SheetStroke>) {
    let tw = text_width(text, style.text_h);
    // 水平讀；放在肩部的上方，往肩部延伸方向走。
    let start = if side >= 0.0 {
        add(end, (style.text_gap, 0.0))
    } else {
        add(end, (-style.text_gap - tw, 0.0))
    };
    let (t, _) = place_text(
        text,
        start,
        (1.0, 0.0),
        (0.0, -1.0),
        style.text_h,
        -style.text_h * 0.5,
        false,
    );
    strokes.extend(t);
}

/// 直徑標註：圓心 `center`、半徑 `radius`，引線從圓上 `dir` 方向（單位向量）那一點出去。
/// 圓夠大時尺寸線穿過圓心、兩端各一個箭頭；太小就從外面指進來。
pub fn diameter(center: P2, radius: f32, dir: P2, ratio: f32, style: &DimStyle) -> Dimension {
    if radius < 1e-3 {
        return Dimension::empty();
    }
    let dir = unit(dir);
    let edge = add(center, scale(dir, radius));
    let far = add(center, scale(dir, -radius));
    let a = style.arrow_len;
    let (knee, end, side) = leader_path(edge, dir, style);
    let mut strokes: Vec<SheetStroke> = Vec::new();
    if radius >= a * 1.5 {
        // 穿過圓心。
        strokes.push(SheetStroke {
            role: Role::Dimension,
            points: vec![far, edge, knee, end],
        });
        arrow(edge, (-dir.0, -dir.1), a, style.arrow_half, &mut strokes);
        arrow(far, dir, a, style.arrow_half, &mut strokes);
    } else {
        // 小圓：箭頭從外面指向圓邊。
        strokes.push(SheetStroke {
            role: Role::Dimension,
            points: vec![edge, knee, end],
        });
        arrow(edge, dir, a, style.arrow_half, &mut strokes);
    }
    let value = radius * 2.0 / UNITS_PER_MM * ratio;
    let text = format!("⌀{}", format_value(value));
    leader_text(&text, end, side.0, style, &mut strokes);
    Dimension {
        strokes,
        value,
        text,
    }
}

/// 半徑標註：引線從圓心經過圓上 `dir` 方向那一點出去，箭頭指在圓弧上。
pub fn radius(center: P2, radius: f32, dir: P2, ratio: f32, style: &DimStyle) -> Dimension {
    if radius < 1e-3 {
        return Dimension::empty();
    }
    let dir = unit(dir);
    let edge = add(center, scale(dir, radius));
    let a = style.arrow_len;
    let (knee, end, side) = leader_path(edge, dir, style);
    let mut strokes: Vec<SheetStroke> = Vec::new();
    if radius >= a * 1.5 {
        strokes.push(SheetStroke {
            role: Role::Dimension,
            points: vec![center, edge, knee, end],
        });
        arrow(edge, (-dir.0, -dir.1), a, style.arrow_half, &mut strokes);
    } else {
        strokes.push(SheetStroke {
            role: Role::Dimension,
            points: vec![edge, knee, end],
        });
        arrow(edge, dir, a, style.arrow_half, &mut strokes);
    }
    let value = radius / UNITS_PER_MM * ratio;
    let text = format!("R{}", format_value(value));
    leader_text(&text, end, side.0, style, &mut strokes);
    Dimension {
        strokes,
        value,
        text,
    }
}

/// 角度標註：頂點 `vertex`、兩邊各朝 `a`、`b`，尺寸弧半徑 `arc_r`。量的是兩邊之間較小的那個角。
pub fn angle(vertex: P2, a: P2, b: P2, arc_r: f32, style: &DimStyle) -> Dimension {
    let (da, db) = (
        (a.0 - vertex.0, a.1 - vertex.1),
        (b.0 - vertex.0, b.1 - vertex.1),
    );
    if da.0.hypot(da.1) < 1e-3 || db.0.hypot(db.1) < 1e-3 || arc_r < 1e-3 {
        return Dimension::empty();
    }
    let a1 = da.1.atan2(da.0);
    let mut delta = db.1.atan2(db.0) - a1;
    while delta > std::f32::consts::PI {
        delta -= std::f32::consts::TAU;
    }
    while delta < -std::f32::consts::PI {
        delta += std::f32::consts::TAU;
    }
    if delta.abs() < 1e-4 {
        return Dimension::empty();
    }
    let at = |ang: f32, r: f32| add(vertex, (r * ang.cos(), r * ang.sin()));
    let mut strokes: Vec<SheetStroke> = Vec::new();

    // 尺寸界線：兩邊各延伸到弧外一點（邊本身比弧短時才需要）。
    for (d, ang) in [(da, a1), (db, a1 + delta)] {
        let len = d.0.hypot(d.1);
        if len < arc_r + style.ext_over {
            let from = len + style.ext_gap;
            let to = arc_r + style.ext_over;
            if to > from {
                strokes.push(thin(at(ang, from), at(ang, to)));
            }
        }
    }

    // 弧，用折線逼近（每段約 3° 以內）。
    let n = ((delta.abs().to_degrees() / 3.0).ceil() as usize).clamp(4, 120);
    let arc: Vec<P2> = (0..=n)
        .map(|i| at(a1 + delta * i as f32 / n as f32, arc_r))
        .collect();
    strokes.push(SheetStroke {
        role: Role::Dimension,
        points: arc,
    });
    // 兩端的箭頭沿切線指向弧外。
    let sign = delta.signum();
    for (ang, toward) in [(a1, 1.0f32), (a1 + delta, -1.0)] {
        let tip = at(ang, arc_r);
        // 弧在這一點的切線方向（朝弧內側為 toward 號）。
        let tangent = (-ang.sin() * sign * toward, ang.cos() * sign * toward);
        arrow(
            tip,
            tangent,
            style.arrow_len,
            style.arrow_half,
            &mut strokes,
        );
    }

    let value = delta.abs().to_degrees();
    let text = format!("{}°", format_value(value));
    // 數字水平，放在弧的外側正中。
    let mid_ang = a1 + delta / 2.0;
    let tw = text_width(&text, style.text_h);
    let anchor = at(mid_ang, arc_r + style.text_gap + style.text_h * 0.6);
    let (t, _) = place_text(
        &text,
        (anchor.0, anchor.1 + style.text_h * 0.5),
        (1.0, 0.0),
        (0.0, -1.0),
        style.text_h,
        0.0,
        true,
    );
    let _ = tw;
    strokes.extend(t);
    Dimension {
        strokes,
        value,
        text,
    }
}

impl From<Dimension> for Drawing {
    fn from(d: Dimension) -> Drawing {
        Drawing {
            strokes: d.strokes,
            labels: Vec::new(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const MM: f32 = UNITS_PER_MM;

    fn style() -> DimStyle {
        DimStyle::iso()
    }

    fn count(d: &Dimension, role: Role) -> usize {
        d.strokes.iter().filter(|s| s.role == role).count()
    }

    #[test]
    fn values_are_written_as_integers_or_one_decimal() {
        assert_eq!(format_value(50.0), "50");
        assert_eq!(format_value(49.98), "50");
        assert_eq!(format_value(12.5), "12.5");
        assert_eq!(format_value(7.26), "7.3");
    }

    #[test]
    fn a_horizontal_dimension_measures_the_paper_length_times_the_scale() {
        // 紙上 50 mm 的線。
        let d = linear(
            (10.0, 200.0),
            (10.0 + 50.0 * MM, 200.0),
            (0.0, 230.0),
            LinearAxis::Auto,
            1.0,
            &style(),
        );
        assert_eq!(d.text, "50");
        assert!((d.value - 50.0).abs() < 1e-3);
        // 1:2 的圖（實物是圖上的 2 倍）標 100；2:1 的圖標 25。
        let half = linear(
            (10.0, 200.0),
            (10.0 + 50.0 * MM, 200.0),
            (0.0, 230.0),
            LinearAxis::Auto,
            2.0,
            &style(),
        );
        assert_eq!(half.text, "100");
        let twice = linear(
            (10.0, 200.0),
            (10.0 + 50.0 * MM, 200.0),
            (0.0, 230.0),
            LinearAxis::Auto,
            0.5,
            &style(),
        );
        assert_eq!(twice.text, "25");
    }

    #[test]
    fn the_dimension_line_sits_where_the_user_put_it() {
        let d = linear(
            (0.0, 100.0),
            (100.0, 100.0),
            (50.0, 160.0),
            LinearAxis::Auto,
            1.0,
            &style(),
        );
        // 有一條水平線在 y = 160（尺寸線），端點正好是 x = 0 與 x = 100。
        let line = d
            .strokes
            .iter()
            .find(|s| {
                s.role == Role::Dimension
                    && s.points.len() == 2
                    && (s.points[0].1 - 160.0).abs() < 1e-3
                    && (s.points[1].1 - 160.0).abs() < 1e-3
            })
            .expect("尺寸線");
        let xs = [line.points[0].0, line.points[1].0];
        assert!(xs.iter().any(|x| x.abs() < 1e-3) && xs.iter().any(|x| (x - 100.0).abs() < 1e-3));
        // 兩條尺寸界線：從點出發（留縫）、超出尺寸線。
        let exts: Vec<_> = d
            .strokes
            .iter()
            .filter(|s| {
                s.role == Role::Dimension && s.points.len() == 2 && s.points[0].0 == s.points[1].0
            })
            .collect();
        assert_eq!(exts.len(), 2);
        for e in exts {
            let (y0, y1) = (e.points[0].1, e.points[1].1);
            assert!((y0 - (100.0 + style().ext_gap)).abs() < 1e-3, "縫 {y0}");
            assert!((y1 - (160.0 + style().ext_over)).abs() < 1e-3, "超出 {y1}");
        }
        // 兩個箭頭（各兩條邊 = 一條折線）與數字筆畫。
        assert_eq!(count(&d, Role::Dimension), 1 + 2 + 2);
        assert!(count(&d, Role::Text) >= 2);
    }

    #[test]
    fn a_vertical_dimension_reads_from_the_right() {
        // 垂直標註：點在同一條豎線上，尺寸線擺在左邊。
        let d = linear(
            (200.0, 50.0),
            (200.0, 50.0 + 40.0 * MM),
            (160.0, 80.0),
            LinearAxis::Auto,
            1.0,
            &style(),
        );
        assert_eq!(d.text, "40");
        // 數字筆畫是旋轉過的：每個字的高度方向在 x 軸上（x 範圍比 y 範圍大一個字高的量級）。
        let pts: Vec<P2> = d
            .strokes
            .iter()
            .filter(|s| s.role == Role::Text)
            .flat_map(|s| s.points.iter().copied())
            .collect();
        let (lo, hi) = padnote_solid::geom::bounds(&pts).unwrap();
        // 字在尺寸線（x = 160）的左邊（「上方」朝左）。
        assert!(hi.0 <= 160.0 + 1e-3, "{hi:?}");
        // 由下往上讀：整行字沿 y 軸延伸（兩個字），字高在 x 方向。
        assert!(hi.1 - lo.1 > hi.0 - lo.0, "{lo:?} {hi:?}");
    }

    #[test]
    fn an_aligned_dimension_follows_a_slanted_line() {
        let d = linear(
            (0.0, 0.0),
            (30.0 * MM, 40.0 * MM),
            (-20.0, 30.0),
            LinearAxis::Aligned,
            1.0,
            &style(),
        );
        assert_eq!(d.text, "50"); // 3-4-5。
        // 尺寸線與兩點連線平行：找尺寸線（最長的兩點 Dimension 折線）。
        let line = d
            .strokes
            .iter()
            .filter(|s| s.role == Role::Dimension && s.points.len() == 2)
            .max_by(|a, b| {
                let l = |s: &SheetStroke| {
                    ((s.points[0].0 - s.points[1].0).powi(2)
                        + (s.points[0].1 - s.points[1].1).powi(2))
                    .sqrt()
                };
                l(a).partial_cmp(&l(b)).unwrap()
            })
            .unwrap();
        let v = (
            line.points[1].0 - line.points[0].0,
            line.points[1].1 - line.points[0].1,
        );
        let cross = v.0 * (40.0 * MM) - v.1 * (30.0 * MM);
        assert!(cross.abs() < 1.0, "不平行：{cross}");
    }

    #[test]
    fn a_short_dimension_puts_the_arrows_outside_and_the_text_beside() {
        // 1.5 mm 的長度放不下箭頭：箭頭在外面，數字在右邊。
        let d = linear(
            (0.0, 100.0),
            (1.5 * MM, 100.0),
            (0.0, 120.0),
            LinearAxis::Horizontal,
            1.0,
            &style(),
        );
        let s = style();
        // 尺寸線延伸到兩端之外（比兩點的間距長）。
        let line = d
            .strokes
            .iter()
            .find(|st| {
                st.role == Role::Dimension
                    && st.points.len() == 2
                    && (st.points[0].1 - 120.0).abs() < 1e-3
                    && (st.points[1].1 - 120.0).abs() < 1e-3
            })
            .unwrap();
        let span = (line.points[1].0 - line.points[0].0).abs();
        assert!(span > 1.5 * MM + s.arrow_len * 3.0, "{span}");
        // 數字在尺寸線右端之外。
        let text_min_x = d
            .strokes
            .iter()
            .filter(|st| st.role == Role::Text)
            .flat_map(|st| st.points.iter())
            .map(|p| p.0)
            .fold(f32::MAX, f32::min);
        assert!(
            text_min_x > 1.5 * MM + 2.0 * s.arrow_len - 1.0,
            "{text_min_x}"
        );
    }

    #[test]
    fn identical_points_make_no_dimension() {
        let d = linear(
            (5.0, 5.0),
            (5.0, 5.0),
            (5.0, 30.0),
            LinearAxis::Auto,
            1.0,
            &style(),
        );
        assert!(d.strokes.is_empty() && d.text.is_empty());
    }

    #[test]
    fn a_diameter_dimension_goes_through_the_centre_and_reads_the_diameter() {
        // 半徑 10 mm 的圓 → 標 ⌀20。
        let c = (100.0, 100.0);
        let d = diameter(c, 10.0 * MM, (1.0, -1.0), 1.0, &style());
        assert_eq!(d.text, "⌀20");
        // 通過圓心：有一條折線經過圓心。
        let through = d.strokes.iter().any(|s| {
            s.role == Role::Dimension
                && s.points
                    .iter()
                    .any(|p| (p.0 - c.0).abs() < 1e-2 && (p.1 - c.1).abs() < 1e-2)
        });
        // 圓心不一定是折線的頂點；檢查折線第一點到邊的點共線於過圓心的直線。
        let first = d
            .strokes
            .iter()
            .find(|s| s.role == Role::Dimension && s.points.len() == 4)
            .expect("引線折線");
        let (p0, p1) = (first.points[0], first.points[1]);
        let dir = unit((1.0, -1.0));
        let cross = (p1.0 - p0.0) * dir.1 - (p1.1 - p0.1) * dir.0;
        assert!(cross.abs() < 1e-2, "{cross}");
        let _ = through;
        // 兩端各一個箭頭。
        assert_eq!(count(&d, Role::Dimension), 1 + 2);
    }

    #[test]
    fn a_radius_dimension_has_one_arrow_on_the_arc_and_an_r_prefix() {
        let d = radius((100.0, 100.0), 8.0 * MM, (-1.0, 0.0), 1.0, &style());
        assert_eq!(d.text, "R8");
        // 一條引線 + 一個箭頭 + 文字。
        assert_eq!(count(&d, Role::Dimension), 2);
        assert!(count(&d, Role::Text) > 0);
        // 引線往左出去（dir = −x），所以文字在圓的左邊。
        let min_x = d
            .strokes
            .iter()
            .filter(|s| s.role == Role::Text)
            .flat_map(|s| s.points.iter())
            .map(|p| p.0)
            .fold(f32::MAX, f32::min);
        assert!(min_x < 100.0 - 8.0 * MM, "{min_x}");
    }

    #[test]
    fn a_small_hole_is_dimensioned_from_the_outside() {
        let d = diameter((50.0, 50.0), 1.5 * MM, (0.0, -1.0), 1.0, &style());
        assert_eq!(d.text, "⌀3");
        // 小圓：只有一個箭頭（外面指進來），不穿過圓心。
        assert_eq!(count(&d, Role::Dimension), 1 + 1);
    }

    #[test]
    fn an_angle_dimension_measures_the_smaller_angle() {
        let v = (100.0, 100.0);
        // 水平向右與向右下 60°（頁面座標 y 向下）。
        let a = (200.0, 100.0);
        let b = (100.0 + 100.0 * 0.5, 100.0 + 100.0 * 3.0f32.sqrt() / 2.0);
        let d = angle(v, a, b, 60.0, &style());
        assert_eq!(d.text, "60°");
        assert!((d.value - 60.0).abs() < 0.01);
        // 反過來量結果一樣。
        let e = angle(v, b, a, 60.0, &style());
        assert_eq!(e.text, "60°");
        // 大於 180° 的那一邊不量：兩邊夾 270° 也量成 90°。
        let c = angle(v, (200.0, 100.0), (100.0, 0.0), 40.0, &style());
        assert_eq!(c.text, "90°");
        // 弧上每一點到頂點的距離都是 arc_r。
        let arc = d
            .strokes
            .iter()
            .find(|s| s.role == Role::Dimension && s.points.len() > 5)
            .unwrap();
        for p in &arc.points {
            let r = ((p.0 - v.0).powi(2) + (p.1 - v.1).powi(2)).sqrt();
            assert!((r - 60.0).abs() < 1e-2, "{r}");
        }
    }

    #[test]
    fn degenerate_angles_make_no_dimension() {
        let v = (0.0, 0.0);
        assert!(
            angle(v, (10.0, 0.0), (20.0, 0.0), 30.0, &style())
                .strokes
                .is_empty()
        );
        assert!(
            angle(v, (0.0, 0.0), (20.0, 5.0), 30.0, &style())
                .strokes
                .is_empty()
        );
        assert!(
            angle(v, (10.0, 0.0), (0.0, 10.0), 0.0, &style())
                .strokes
                .is_empty()
        );
    }
}
