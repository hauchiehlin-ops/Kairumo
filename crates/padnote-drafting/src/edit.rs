//! 編輯運算：修剪、延伸、鏡射、陣列、圓角、偏移。
//!
//! 全部是**折線進、折線出**的純幾何（頁面座標）。平台負責找出使用者點到哪一筆、把結果換回筆畫
//! （沿用原筆畫的筆、圖層、線型）、並把「換掉原來的筆畫」包成一次復原。
//!
//! 手繪的筆畫是很多個小線段；運算一律把它們當折線處理，不假設只有兩個點。

use crate::P2;

const EPS: f32 = 1e-4;

fn sub(a: P2, b: P2) -> P2 {
    (a.0 - b.0, a.1 - b.1)
}
fn add(a: P2, b: P2) -> P2 {
    (a.0 + b.0, a.1 + b.1)
}
fn mul(a: P2, k: f32) -> P2 {
    (a.0 * k, a.1 * k)
}
fn dot(a: P2, b: P2) -> f32 {
    a.0 * b.0 + a.1 * b.1
}
fn cross(a: P2, b: P2) -> f32 {
    a.0 * b.1 - a.1 * b.0
}
fn len(a: P2) -> f32 {
    a.0.hypot(a.1)
}
fn dist(a: P2, b: P2) -> f32 {
    len(sub(a, b))
}
fn unit(a: P2) -> Option<P2> {
    let l = len(a);
    (l > EPS).then(|| (a.0 / l, a.1 / l))
}

/// 去掉連續重複的點。
fn dedup(points: &[P2]) -> Vec<P2> {
    let mut out: Vec<P2> = Vec::with_capacity(points.len());
    for p in points {
        if out.last().is_none_or(|q| dist(*q, *p) > EPS) {
            out.push(*p);
        }
    }
    out
}

/// 折線的總長。
pub fn length(points: &[P2]) -> f32 {
    points.windows(2).map(|w| dist(w[0], w[1])).sum()
}

/// 首尾相接（誤差 0.5 單位內）的折線視為封閉，例如畫好的圓。
pub fn is_closed(points: &[P2]) -> bool {
    points.len() >= 3 && dist(points[0], points[points.len() - 1]) < 0.5
}

/// 兩線段 (a,b)、(c,d) 的交點：回 (交點, 在 ab 上的比例 t, 在 cd 上的比例 u)。平行或沒碰到回 `None`。
pub fn segment_intersection(a: P2, b: P2, c: P2, d: P2) -> Option<(P2, f32, f32)> {
    let r = sub(b, a);
    let s = sub(d, c);
    let denom = cross(r, s);
    if denom.abs() < EPS {
        return None;
    }
    let ac = sub(c, a);
    let t = cross(ac, s) / denom;
    let u = cross(ac, r) / denom;
    let tol = 1e-5;
    if (-tol..=1.0 + tol).contains(&t) && (-tol..=1.0 + tol).contains(&u) {
        Some((add(a, mul(r, t)), t.clamp(0.0, 1.0), u.clamp(0.0, 1.0)))
    } else {
        None
    }
}

/// 點到線段的最近點與距離。
fn closest_on_segment(p: P2, a: P2, b: P2) -> (P2, f32) {
    let ab = sub(b, a);
    let l2 = dot(ab, ab);
    let t = if l2 < EPS {
        0.0
    } else {
        (dot(sub(p, a), ab) / l2).clamp(0.0, 1.0)
    };
    let q = add(a, mul(ab, t));
    (q, dist(p, q))
}

/// 點到折線的最近點：回 (沿折線的距離 s, 最近點, 距離)。
fn closest_on_path(points: &[P2], p: P2) -> Option<(f32, P2, f32)> {
    let mut best: Option<(f32, P2, f32)> = None;
    let mut acc = 0.0;
    for w in points.windows(2) {
        let (q, d) = closest_on_segment(p, w[0], w[1]);
        if best.is_none_or(|b| d < b.2) {
            best = Some((acc + dist(w[0], q), q, d));
        }
        acc += dist(w[0], w[1]);
    }
    best
}

/// 折線上沿路徑距離 s 的點。
fn point_at(points: &[P2], s: f32) -> P2 {
    let mut acc = 0.0;
    for w in points.windows(2) {
        let l = dist(w[0], w[1]);
        if s <= acc + l || std::ptr::eq(&w[1], &points[points.len() - 1]) {
            let t = if l < EPS {
                0.0
            } else {
                ((s - acc) / l).clamp(0.0, 1.0)
            };
            return add(w[0], mul(sub(w[1], w[0]), t));
        }
        acc += l;
    }
    *points.last().unwrap_or(&(0.0, 0.0))
}

/// 折線上從路徑距離 s0 到 s1（s0 ≤ s1）的一段，端點是精確切出來的。
fn sub_path(points: &[P2], s0: f32, s1: f32) -> Vec<P2> {
    let mut out = vec![point_at(points, s0)];
    let mut acc = 0.0;
    for w in points.windows(2) {
        acc += dist(w[0], w[1]);
        if acc > s0 + EPS && acc < s1 - EPS {
            out.push(w[1]);
        }
    }
    out.push(point_at(points, s1));
    dedup(&out)
}

/// 目標折線與所有切割邊的交點，換成沿目標折線的距離，由小到大、去掉重複。
fn crossings(target: &[P2], cutters: &[Vec<P2>]) -> Vec<f32> {
    let mut out = Vec::new();
    let mut acc = 0.0;
    for w in target.windows(2) {
        let l = dist(w[0], w[1]);
        for cutter in cutters {
            for c in cutter.windows(2) {
                if let Some((_, t, _)) = segment_intersection(w[0], w[1], c[0], c[1]) {
                    out.push(acc + t * l);
                }
            }
        }
        acc += l;
    }
    out.sort_by(|a, b| a.total_cmp(b));
    out.dedup_by(|a, b| (*a - *b).abs() < 0.05);
    out
}

/// 修剪：點在 `click` 附近的那一段，從前後最近的交點之間剪掉，剩下的回傳（0、1 或 2 段）。
///
/// - 前後都有交點：中間剪掉，剩前後兩段（封閉的線剩一段繞過接縫的弧）。
/// - 只有一邊有交點：從交點剪到那一端。
/// - 沒有任何交點，或封閉的線只有一個交點：回 `None`（沒有東西可剪）。
pub fn trim(target: &[P2], cutters: &[Vec<P2>], click: P2) -> Option<Vec<Vec<P2>>> {
    let target = dedup(target);
    if target.len() < 2 {
        return None;
    }
    let total = length(&target);
    let hits = crossings(&target, cutters);
    if hits.is_empty() {
        return None;
    }
    let (sc, _, _) = closest_on_path(&target, click)?;
    let closed = is_closed(&target);
    // 封閉線的接縫上的交點在 0 與 total 各出現一次：只留一個。
    let hits: Vec<f32> = if closed {
        hits.into_iter().filter(|s| *s < total - 0.05).collect()
    } else {
        hits
    };
    let lo = hits.iter().copied().rfind(|s| *s <= sc);
    let hi = hits.iter().copied().find(|s| *s > sc);
    let pieces = if closed {
        if hits.len() < 2 {
            return None;
        }
        // 繞過接縫：沒有前一個就用最後一個、沒有後一個就用第一個。
        let lo = lo.unwrap_or(*hits.last().unwrap());
        let hi = hi.unwrap_or(hits[0]);
        if (hi - lo).abs() < 0.05 {
            return None;
        }
        // 留下的是從 hi 往前走到 lo 的弧。
        let mut arc = if hi < lo {
            sub_path(&target, hi, lo)
        } else {
            let mut a = sub_path(&target, hi, total);
            a.extend(sub_path(&target, 0.0, lo));
            dedup(&a)
        };
        if arc.len() < 2 {
            arc.clear();
        }
        vec![arc]
    } else {
        match (lo, hi) {
            (Some(lo), Some(hi)) => vec![sub_path(&target, 0.0, lo), sub_path(&target, hi, total)],
            (Some(lo), None) => vec![sub_path(&target, 0.0, lo)],
            (None, Some(hi)) => vec![sub_path(&target, hi, total)],
            (None, None) => return None,
        }
    };
    Some(
        pieces
            .into_iter()
            .filter(|p| p.len() >= 2 && length(p) > 0.3)
            .collect(),
    )
}

/// 延伸：把 `near` 附近的那一端，沿著末端方向延伸到最近的邊界。碰不到邊界回 `None`。
///
/// 末端方向取離端點至少 `max(6, 2 × 筆寬)` 單位的前一個點，免得手繪線末端的抖動讓方向亂飄。
pub fn extend(target: &[P2], near: P2, boundaries: &[Vec<P2>]) -> Option<Vec<P2>> {
    let t = dedup(target);
    if t.len() < 2 {
        return None;
    }
    let at_end = dist(near, t[t.len() - 1]) <= dist(near, t[0]);
    let path: Vec<P2> = if at_end {
        t.clone()
    } else {
        t.iter().rev().copied().collect()
    };
    let end = *path.last()?;
    let back = path
        .iter()
        .rev()
        .skip(1)
        .find(|q| dist(**q, end) >= 6.0)
        .copied()
        .unwrap_or(path[0]);
    let dir = unit(sub(end, back))?;
    let far = add(end, mul(dir, 4000.0));
    let mut best: Option<(f32, P2)> = None;
    for b in boundaries {
        for seg in b.windows(2) {
            if let Some((q, tt, _)) = segment_intersection(end, far, seg[0], seg[1]) {
                let d = tt * 4000.0;
                if d > 0.5 && best.is_none_or(|x| d < x.0) {
                    best = Some((d, q));
                }
            }
        }
    }
    let (_, hit) = best?;
    let mut out = path;
    out.push(hit);
    if !at_end {
        out.reverse();
    }
    Some(out)
}

/// 對稱軸 a→b 的鏡射。軸太短回原樣。
pub fn mirror(points: &[P2], a: P2, b: P2) -> Vec<P2> {
    let Some(d) = unit(sub(b, a)) else {
        return points.to_vec();
    };
    points
        .iter()
        .map(|p| {
            let v = sub(*p, a);
            let along = mul(d, dot(v, d));
            let perp = sub(v, along);
            add(a, sub(along, perp))
        })
        .collect()
}

/// 矩形陣列：`rows × cols` 份，列距 `dy`、欄距 `dx`；回傳**除了原件以外**的複本。
pub fn array_rect(points: &[P2], rows: u32, cols: u32, dx: f32, dy: f32) -> Vec<Vec<P2>> {
    let mut out = Vec::new();
    for r in 0..rows.max(1) {
        for c in 0..cols.max(1) {
            if r == 0 && c == 0 {
                continue;
            }
            let off = (dx * c as f32, dy * r as f32);
            out.push(points.iter().map(|p| add(*p, off)).collect());
        }
    }
    out
}

/// 繞 `center` 轉 `deg` 度（順時針為正，因為 y 向下）。
pub fn rotate(points: &[P2], center: P2, deg: f32) -> Vec<P2> {
    let (s, c) = deg.to_radians().sin_cos();
    points
        .iter()
        .map(|p| {
            let v = sub(*p, center);
            add(center, (v.0 * c - v.1 * s, v.0 * s + v.1 * c))
        })
        .collect()
}

/// 環形陣列：共 `count` 份均分 `total_deg`（360 = 一整圈、份數均分不重疊）；回傳除了原件以外的複本。
pub fn array_polar(points: &[P2], center: P2, count: u32, total_deg: f32) -> Vec<Vec<P2>> {
    let count = count.max(1);
    if count == 1 {
        return Vec::new();
    }
    // 一整圈：每份 360/count；不到一整圈：頭尾都有，每份 total/(count-1)。
    let step = if (total_deg.abs() - 360.0).abs() < 1e-3 {
        total_deg / count as f32
    } else {
        total_deg / (count - 1) as f32
    };
    (1..count)
        .map(|i| rotate(points, center, step * i as f32))
        .collect()
}

/// 圓角的結果：兩條修短的線與連接它們的圓弧。
#[derive(Clone, Debug)]
pub struct Fillet {
    pub a: Vec<P2>,
    pub b: Vec<P2>,
    pub arc: Vec<P2>,
}

/// 直線折線（所有點都貼著首尾連線）回它的兩端；不是直線回 `None`。
fn as_line(points: &[P2]) -> Option<(P2, P2)> {
    let p = dedup(points);
    let (a, b) = (*p.first()?, *p.last()?);
    if p.len() < 2 || dist(a, b) < 1.0 {
        return None;
    }
    p.iter()
        .all(|q| closest_on_segment(*q, a, b).1 < 0.75)
        .then_some((a, b))
}

/// 圓角：兩條**直線**在 `click1`、`click2` 所指的那一側，用半徑 `radius` 的圓弧接起來。
///
/// 線會自動修短（或延伸）到切點。平行、半徑太大（線不夠長）、不是直線都回 `None`。
pub fn fillet(l1: &[P2], l2: &[P2], radius: f32, click1: P2, click2: P2) -> Option<Fillet> {
    if radius <= EPS {
        return None;
    }
    let (a1, b1) = as_line(l1)?;
    let (a2, b2) = as_line(l2)?;
    let d1 = unit(sub(b1, a1))?;
    let d2 = unit(sub(b2, a2))?;
    let denom = cross(d1, d2);
    if denom.abs() < 1e-3 {
        return None;
    }
    // 兩條直線的交點 P。
    let t = cross(sub(a2, a1), d2) / denom;
    let p = add(a1, mul(d1, t));
    // 各線從 P 往點擊的那一側走。
    let side = |dir: P2, click: P2, a: P2, b: P2| -> Option<P2> {
        let s = dot(sub(click, p), dir);
        if s.abs() > EPS {
            return Some(if s > 0.0 { dir } else { mul(dir, -1.0) });
        }
        // 點正好在 P 上：朝線比較長的那一端。
        let far = if dist(a, p) > dist(b, p) { a } else { b };
        unit(sub(far, p))
    };
    let u1 = side(d1, click1, a1, b1)?;
    let u2 = side(d2, click2, a2, b2)?;
    let cos_theta = dot(u1, u2).clamp(-1.0, 1.0);
    let theta = cos_theta.acos(); // 兩條線夾的角
    if theta < 0.02 || theta > std::f32::consts::PI - 0.02 {
        return None;
    }
    let tangent = radius / (theta / 2.0).tan();
    // 兩條線在那一側都要夠長：離 P 最遠的端點要超過切點。
    let reach = |a: P2, b: P2, u: P2| -> (f32, P2) {
        let (ra, rb) = (dot(sub(a, p), u), dot(sub(b, p), u));
        if ra >= rb { (ra, a) } else { (rb, b) }
    };
    let (r1, e1) = reach(a1, b1, u1);
    let (r2, e2) = reach(a2, b2, u2);
    if r1 < tangent - 0.01 || r2 < tangent - 0.01 {
        return None;
    }
    let t1 = add(p, mul(u1, tangent));
    let t2 = add(p, mul(u2, tangent));
    let bis = unit(add(u1, u2))?;
    let center = add(p, mul(bis, radius / (theta / 2.0).sin()));
    let (s1, s2) = (sub(t1, center), sub(t2, center));
    let start = s1.1.atan2(s1.0);
    let mut sweep = s2.1.atan2(s2.0) - start;
    while sweep > std::f32::consts::PI {
        sweep -= 2.0 * std::f32::consts::PI;
    }
    while sweep < -std::f32::consts::PI {
        sweep += 2.0 * std::f32::consts::PI;
    }
    let arc = crate::instruments::arc_points(center, radius, start, sweep);
    // 弧的兩端用精確的切點，免得取樣誤差讓線與弧之間有縫。
    let mut arc = arc;
    if let Some(f) = arc.first_mut() {
        *f = t1;
    }
    if let Some(l) = arc.last_mut() {
        *l = t2;
    }
    Some(Fillet {
        a: vec![e1, t1],
        b: vec![e2, t2],
        arc,
    })
}

/// 道格拉斯–普克簡化（容差 `tol` 單位）。偏移前先把手繪的密集點收成幾個轉折。
pub fn simplify(points: &[P2], tol: f32) -> Vec<P2> {
    let p = dedup(points);
    if p.len() < 3 {
        return p;
    }
    let (a, b) = (p[0], p[p.len() - 1]);
    let (mut idx, mut worst) = (0, 0.0);
    for (i, q) in p.iter().enumerate().take(p.len() - 1).skip(1) {
        let d = closest_on_segment(*q, a, b).1;
        if d > worst {
            worst = d;
            idx = i;
        }
    }
    if worst <= tol {
        return vec![a, b];
    }
    let mut left = simplify(&p[..=idx], tol);
    let right = simplify(&p[idx..], tol);
    left.pop();
    left.extend(right);
    left
}

/// 偏移：折線往 `side_point` 那一側平移 `distance` 單位，轉角用尖角（miter）接。
///
/// 手繪的密集點先簡化；尖角太長（銳角）時改用斜接，免得線飛出去。封閉的線偏移之後仍然封閉。
pub fn offset(points: &[P2], distance: f32, side_point: P2) -> Option<Vec<P2>> {
    if distance <= EPS {
        return None;
    }
    let closed = is_closed(points);
    let mut p = simplify(points, 0.6);
    if closed && p.len() >= 3 && dist(p[0], p[p.len() - 1]) > EPS {
        let first = p[0];
        *p.last_mut().unwrap() = first;
    }
    if p.len() < 2 {
        return None;
    }
    // 點在哪一側：看離它最近的那段。
    let (seg, _) = p
        .windows(2)
        .enumerate()
        .map(|(i, w)| (i, closest_on_segment(side_point, w[0], w[1]).1))
        .min_by(|a, b| a.1.total_cmp(&b.1))?;
    let dir = unit(sub(p[seg + 1], p[seg]))?;
    let normal = (-dir.1, dir.0);
    let q = closest_on_segment(side_point, p[seg], p[seg + 1]).0;
    let sign = if dot(sub(side_point, q), normal) >= 0.0 {
        1.0
    } else {
        -1.0
    };
    let d = distance * sign;

    // 每一段平移之後的兩個端點。
    let shifted: Vec<(P2, P2)> = p
        .windows(2)
        .filter_map(|w| {
            let u = unit(sub(w[1], w[0]))?;
            let n = (-u.1, u.0);
            Some((add(w[0], mul(n, d)), add(w[1], mul(n, d))))
        })
        .collect();
    if shifted.is_empty() {
        return None;
    }
    let miter_limit = 4.0 * distance;
    let join = |s: (P2, P2), t: (P2, P2)| -> Vec<P2> {
        let r = sub(s.1, s.0);
        let u = sub(t.1, t.0);
        let denom = cross(r, u);
        if denom.abs() > 1e-4 {
            let k = cross(sub(t.0, s.0), u) / denom;
            let m = add(s.0, mul(r, k));
            if dist(m, s.1) <= miter_limit {
                return vec![m];
            }
        }
        vec![s.1, t.0]
    };
    let mut out = vec![shifted[0].0];
    for w in shifted.windows(2) {
        out.extend(join(w[0], w[1]));
    }
    if closed && shifted.len() >= 2 {
        let m = join(*shifted.last().unwrap(), shifted[0]);
        // 封閉：起點與終點都換成接縫處的尖角。
        out[0] = m[0];
        out.extend(m);
        let first = out[0];
        *out.last_mut().unwrap() = first;
    } else {
        out.push(shifted.last().unwrap().1);
    }
    Some(dedup(&out))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn near(a: P2, b: P2) -> bool {
        dist(a, b) < 0.01
    }

    #[test]
    fn segments_intersect_inside_and_not_when_parallel_or_short() {
        let (p, t, u) =
            segment_intersection((0.0, 0.0), (10.0, 0.0), (5.0, -5.0), (5.0, 5.0)).unwrap();
        assert!(near(p, (5.0, 0.0)) && (t - 0.5).abs() < 1e-5 && (u - 0.5).abs() < 1e-5);
        assert!(segment_intersection((0.0, 0.0), (10.0, 0.0), (0.0, 1.0), (10.0, 1.0)).is_none());
        assert!(segment_intersection((0.0, 0.0), (10.0, 0.0), (12.0, -5.0), (12.0, 5.0)).is_none());
    }

    #[test]
    fn trimming_the_middle_keeps_both_ends() {
        let target = vec![(0.0, 0.0), (100.0, 0.0)];
        let cutters = vec![
            vec![(30.0, -10.0), (30.0, 10.0)],
            vec![(70.0, -10.0), (70.0, 10.0)],
        ];
        let pieces = trim(&target, &cutters, (50.0, 0.0)).unwrap();
        assert_eq!(pieces.len(), 2);
        assert!(near(pieces[0][0], (0.0, 0.0)) && near(*pieces[0].last().unwrap(), (30.0, 0.0)));
        assert!(near(pieces[1][0], (70.0, 0.0)) && near(*pieces[1].last().unwrap(), (100.0, 0.0)));
    }

    #[test]
    fn trimming_an_end_removes_up_to_the_nearest_crossing() {
        let target = vec![(0.0, 0.0), (100.0, 0.0)];
        let cutters = vec![vec![(30.0, -10.0), (30.0, 10.0)]];
        // 點在 30 的右邊：右邊整段（到末端）被剪掉。
        let right = trim(&target, &cutters, (80.0, 0.0)).unwrap();
        assert_eq!(right.len(), 1);
        assert!(near(right[0][0], (0.0, 0.0)) && near(*right[0].last().unwrap(), (30.0, 0.0)));
        // 點在左邊：左邊剪掉。
        let left = trim(&target, &cutters, (10.0, 0.0)).unwrap();
        assert!(near(left[0][0], (30.0, 0.0)) && near(*left[0].last().unwrap(), (100.0, 0.0)));
    }

    #[test]
    fn trimming_without_a_crossing_does_nothing() {
        let target = vec![(0.0, 0.0), (100.0, 0.0)];
        assert!(trim(&target, &[vec![(200.0, -10.0), (200.0, 10.0)]], (50.0, 0.0)).is_none());
        assert!(trim(&target, &[], (50.0, 0.0)).is_none());
    }

    #[test]
    fn trimming_follows_a_bent_polyline() {
        // L 形：(0,0)→(50,0)→(50,50)，被 y=25 的橫線在垂直那段切開。
        let target = vec![(0.0, 0.0), (50.0, 0.0), (50.0, 50.0)];
        let cutters = vec![vec![(40.0, 25.0), (60.0, 25.0)]];
        let pieces = trim(&target, &cutters, (50.0, 40.0)).unwrap();
        assert_eq!(pieces.len(), 1);
        assert_eq!(pieces[0].len(), 3, "轉折點留著");
        assert!(near(*pieces[0].last().unwrap(), (50.0, 25.0)));
    }

    #[test]
    fn trimming_a_closed_circle_between_two_crossings_leaves_one_arc() {
        let c = crate::instruments::arc_points((0.0, 0.0), 50.0, 0.0, 2.0 * std::f32::consts::PI);
        // 一條穿過圓的水平線：在 (−50,0)、(50,0) 與圓相交（在接縫 (50,0) 上也算）。
        let cutter = vec![vec![(-80.0, 10.0), (80.0, 10.0)]];
        // 點在上半圓（y 向下，所以 y<0 是上方）：不在剪的那一段上也可以，剪的是點所在的那段。
        let pieces = trim(&c, &cutter, (0.0, 50.0)).unwrap();
        assert_eq!(pieces.len(), 1);
        let arc = &pieces[0];
        // 剩下的弧不經過被點到的那一段（圓的最下方 (0,50)）。
        assert!(arc.iter().all(|q| q.1 < 10.5), "下半圓被剪掉了");
        assert!(length(arc) > 100.0);
    }

    #[test]
    fn extending_runs_the_end_to_the_nearest_boundary() {
        let target = vec![(0.0, 0.0), (40.0, 0.0)];
        let boundaries = vec![
            vec![(100.0, -50.0), (100.0, 50.0)],
            vec![(200.0, -50.0), (200.0, 50.0)],
        ];
        let out = extend(&target, (38.0, 0.0), &boundaries).unwrap();
        assert!(near(*out.last().unwrap(), (100.0, 0.0)), "延到最近的邊界");
        assert!(near(out[0], (0.0, 0.0)));
        // 近的是起點：從起點那頭往反方向延伸。
        let b2 = vec![vec![(-60.0, -50.0), (-60.0, 50.0)]];
        let back = extend(&target, (2.0, 0.0), &b2).unwrap();
        assert!(near(back[0], (-60.0, 0.0)) && near(*back.last().unwrap(), (40.0, 0.0)));
        // 方向上沒有邊界：沒有東西可延。
        assert!(extend(&target, (38.0, 0.0), &[vec![(-10.0, -5.0), (-10.0, 5.0)]]).is_none());
    }

    #[test]
    fn extending_uses_the_overall_direction_not_the_last_jitter() {
        // 末端有 0.5 單位的小抖動：方向仍是大致往右。
        let target = vec![(0.0, 0.0), (20.0, 0.0), (39.0, 0.0), (40.0, 0.4)];
        let out = extend(&target, (40.0, 0.4), &[vec![(100.0, -50.0), (100.0, 50.0)]]).unwrap();
        let end = *out.last().unwrap();
        assert!((end.0 - 100.0).abs() < 0.01 && end.1.abs() < 4.0);
    }

    #[test]
    fn mirroring_reflects_across_any_axis() {
        // 鉛直軸 x = 10。
        let m = mirror(&[(0.0, 0.0), (4.0, 3.0)], (10.0, 0.0), (10.0, 5.0));
        assert!(near(m[0], (20.0, 0.0)) && near(m[1], (16.0, 3.0)));
        // 45° 軸 y = x：(3,1) → (1,3)。
        let d = mirror(&[(3.0, 1.0)], (0.0, 0.0), (7.0, 7.0));
        assert!(near(d[0], (1.0, 3.0)));
        // 鏡射兩次回到原位。
        let back = mirror(&m, (10.0, 0.0), (10.0, 5.0));
        assert!(near(back[1], (4.0, 3.0)));
        // 軸太短：原樣。
        assert_eq!(
            mirror(&[(1.0, 2.0)], (0.0, 0.0), (0.0, 0.0)),
            vec![(1.0, 2.0)]
        );
    }

    #[test]
    fn a_rectangular_array_makes_rows_times_cols_minus_the_original() {
        let copies = array_rect(&[(0.0, 0.0), (10.0, 0.0)], 2, 3, 20.0, 15.0);
        assert_eq!(copies.len(), 5);
        assert!(
            copies.iter().any(|c| near(c[0], (40.0, 15.0))),
            "第二列第三欄"
        );
        assert!(!copies.iter().any(|c| near(c[0], (0.0, 0.0))), "不含原件");
        assert!(array_rect(&[(0.0, 0.0)], 1, 1, 5.0, 5.0).is_empty());
    }

    #[test]
    fn a_polar_array_spreads_copies_around_the_center() {
        // 一整圈 6 份：每份 60°，共 5 個複本；第一份從 (10,0) 轉到 (5, 8.66)。
        let copies = array_polar(&[(10.0, 0.0)], (0.0, 0.0), 6, 360.0);
        assert_eq!(copies.len(), 5);
        assert!(near(copies[0][0], (5.0, 8.660254)));
        assert!(near(copies[2][0], (-10.0, 0.0)), "第三份轉 180°");
        // 不滿一圈：頭尾都有（4 份跨 90° → 每份 30°）。
        let arc = array_polar(&[(10.0, 0.0)], (0.0, 0.0), 4, 90.0);
        assert_eq!(arc.len(), 3);
        assert!(near(arc[2][0], (0.0, 10.0)));
        assert!(array_polar(&[(1.0, 1.0)], (0.0, 0.0), 1, 360.0).is_empty());
    }

    #[test]
    fn a_fillet_joins_two_perpendicular_lines_with_a_quarter_arc() {
        // 水平線 (0,100)→(100,100) 與垂直線 (100,100)→(100,0)：角在 (100,100)。半徑 20。
        let f = fillet(
            &[(0.0, 100.0), (100.0, 100.0)],
            &[(100.0, 100.0), (100.0, 0.0)],
            20.0,
            (30.0, 100.0),
            (100.0, 30.0),
        )
        .unwrap();
        assert!(
            near(*f.a.last().unwrap(), (80.0, 100.0)),
            "水平線在 80 收掉"
        );
        assert!(
            near(*f.b.last().unwrap(), (100.0, 80.0)),
            "垂直線在 80 收掉"
        );
        assert!(near(f.arc[0], (80.0, 100.0)) && near(*f.arc.last().unwrap(), (100.0, 80.0)));
        // 弧上每個點離圓心 (80,80) 都是 20。
        for q in &f.arc {
            assert!((dist(*q, (80.0, 80.0)) - 20.0).abs() < 0.05, "{q:?}");
        }
        // 是四分之一圓：弧長 ≈ π/2 × 20。
        assert!((length(&f.arc) - std::f32::consts::FRAC_PI_2 * 20.0).abs() < 0.2);
    }

    #[test]
    fn a_fillet_extends_lines_that_stop_short_of_the_corner() {
        // 兩條線都沒碰到角 (100,100)：圓角會把它們延伸到切點。
        let f = fillet(
            &[(0.0, 100.0), (60.0, 100.0)],
            &[(100.0, 0.0), (100.0, 60.0)],
            10.0,
            (30.0, 100.0),
            (100.0, 30.0),
        )
        .unwrap();
        // 離 P 最遠的端點是 (0,100)：線從 (0,100) 到切點 (90,100)。
        assert!(near(f.a[0], (0.0, 100.0)) && near(*f.a.last().unwrap(), (90.0, 100.0)));
        assert!(near(f.b[0], (100.0, 0.0)) && near(*f.b.last().unwrap(), (100.0, 90.0)));
    }

    #[test]
    fn a_fillet_refuses_parallel_lines_curves_and_radii_that_do_not_fit() {
        let h1 = [(0.0, 0.0), (100.0, 0.0)];
        let h2 = [(0.0, 50.0), (100.0, 50.0)];
        assert!(
            fillet(&h1, &h2, 10.0, (50.0, 0.0), (50.0, 50.0)).is_none(),
            "平行"
        );
        let curved = [(0.0, 100.0), (50.0, 80.0), (100.0, 100.0)];
        let v = [(100.0, 100.0), (100.0, 0.0)];
        assert!(
            fillet(&curved, &v, 10.0, (20.0, 90.0), (100.0, 50.0)).is_none(),
            "不是直線"
        );
        let a = [(0.0, 100.0), (100.0, 100.0)];
        assert!(
            fillet(&a, &v, 500.0, (30.0, 100.0), (100.0, 30.0)).is_none(),
            "半徑太大"
        );
        assert!(
            fillet(&a, &v, 0.0, (30.0, 100.0), (100.0, 30.0)).is_none(),
            "半徑 0"
        );
    }

    #[test]
    fn simplify_collapses_collinear_points_and_keeps_corners() {
        let dense: Vec<P2> = (0..=20).map(|i| (i as f32 * 5.0, 0.0)).collect();
        assert_eq!(simplify(&dense, 0.5).len(), 2);
        let mut bent = dense.clone();
        bent.extend((1..=10).map(|i| (100.0, i as f32 * 5.0)));
        let s = simplify(&bent, 0.5);
        assert_eq!(s.len(), 3);
        assert!(near(s[1], (100.0, 0.0)));
    }

    #[test]
    fn offsetting_a_line_moves_it_parallel_to_the_chosen_side() {
        let line = [(0.0, 0.0), (100.0, 0.0)];
        let below = offset(&line, 10.0, (50.0, 30.0)).unwrap();
        assert!(near(below[0], (0.0, 10.0)) && near(*below.last().unwrap(), (100.0, 10.0)));
        let above = offset(&line, 10.0, (50.0, -30.0)).unwrap();
        assert!(near(above[0], (0.0, -10.0)));
        assert!(offset(&line, 0.0, (50.0, 5.0)).is_none());
    }

    #[test]
    fn offsetting_a_corner_makes_a_sharp_mitre() {
        // L 形，往內側（右下）偏 10：角從 (100,0) 移到 (90,10)。
        let l = [(0.0, 0.0), (100.0, 0.0), (100.0, 100.0)];
        let inner = offset(&l, 10.0, (50.0, 50.0)).unwrap();
        assert_eq!(inner.len(), 3);
        assert!(
            near(inner[0], (0.0, 10.0))
                && near(inner[1], (90.0, 10.0))
                && near(inner[2], (90.0, 100.0))
        );
        // 往外側偏：角在 (110,−10)。
        let outer = offset(&l, 10.0, (150.0, -50.0)).unwrap();
        assert!(near(outer[1], (110.0, -10.0)));
    }

    #[test]
    fn offsetting_a_closed_square_stays_closed_and_resizes_it() {
        let sq = [
            (0.0, 0.0),
            (100.0, 0.0),
            (100.0, 100.0),
            (0.0, 100.0),
            (0.0, 0.0),
        ];
        let inner = offset(&sq, 10.0, (50.0, 50.0)).unwrap();
        assert!(is_closed(&inner));
        let xs: Vec<f32> = inner.iter().map(|q| q.0).collect();
        assert!((xs.iter().cloned().fold(f32::MAX, f32::min) - 10.0).abs() < 0.01);
        assert!((xs.iter().cloned().fold(f32::MIN, f32::max) - 90.0).abs() < 0.01);
        let outer = offset(&sq, 10.0, (500.0, 500.0)).unwrap();
        assert!(is_closed(&outer));
        let ys: Vec<f32> = outer.iter().map(|q| q.1).collect();
        assert!((ys.iter().cloned().fold(f32::MIN, f32::max) - 110.0).abs() < 0.01);
    }

    #[test]
    fn offsetting_a_dense_hand_drawn_line_does_not_explode() {
        // 300 個點、帶 0.2 的抖動的直線。
        let wobbly: Vec<P2> = (0..300)
            .map(|i| (i as f32, if i % 2 == 0 { 0.0 } else { 0.2 }))
            .collect();
        let out = offset(&wobbly, 8.0, (100.0, 20.0)).unwrap();
        assert!(out.len() <= 4, "簡化之後只剩幾個點：{}", out.len());
        assert!(out.iter().all(|q| (q.1 - 8.0).abs() < 0.6));
    }
}
