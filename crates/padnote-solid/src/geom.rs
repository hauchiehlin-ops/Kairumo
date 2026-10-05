//! 平面幾何的小工具：面積、點在多邊形內、簡化折線、線與環的交點。
//!
//! 全部用 `f32`：頁面座標本來就是 `f32`，而製圖的精度（0.01 個頁面單位 ≈ 0.003 mm）遠低於它的有效位數。

pub type P2 = (f32, f32);
pub type P3 = [f32; 3];

pub const EPS: f32 = 1e-4;

pub fn dist(a: P2, b: P2) -> f32 {
    ((a.0 - b.0).powi(2) + (a.1 - b.1).powi(2)).sqrt()
}

/// 有號面積。逆時針（y 向上）為正。
pub fn signed_area(ring: &[P2]) -> f32 {
    let n = ring.len();
    let mut a = 0.0;
    for i in 0..n {
        let (p, q) = (ring[i], ring[(i + 1) % n]);
        a += p.0 * q.1 - q.0 * p.1;
    }
    a * 0.5
}

pub fn perimeter(ring: &[P2]) -> f32 {
    let n = ring.len();
    (0..n).map(|i| dist(ring[i], ring[(i + 1) % n])).sum()
}

pub fn centroid_of_points(ring: &[P2]) -> P2 {
    let n = ring.len().max(1) as f32;
    let (sx, sy) = ring.iter().fold((0.0, 0.0), |a, p| (a.0 + p.0, a.1 + p.1));
    (sx / n, sy / n)
}

pub fn bounds(points: &[P2]) -> Option<(P2, P2)> {
    let first = *points.first()?;
    let mut lo = first;
    let mut hi = first;
    for p in points {
        lo = (lo.0.min(p.0), lo.1.min(p.1));
        hi = (hi.0.max(p.0), hi.1.max(p.1));
    }
    Some((lo, hi))
}

/// 點在單一環內（奇偶規則）。
pub fn point_in_ring(p: P2, ring: &[P2]) -> bool {
    let mut inside = false;
    let n = ring.len();
    let mut j = n - 1;
    for i in 0..n {
        let (a, b) = (ring[i], ring[j]);
        if (a.1 > p.1) != (b.1 > p.1) && p.0 < (b.0 - a.0) * (p.1 - a.1) / (b.1 - a.1) + a.0 {
            inside = !inside;
        }
        j = i;
    }
    inside
}

/// 點在「外環＋洞」圍出的區域內：奇偶規則對所有環一起算，洞自然被挖掉。
pub fn point_in_rings(p: P2, rings: &[&[P2]]) -> bool {
    rings.iter().filter(|r| point_in_ring(p, r)).count() % 2 == 1
}

/// Douglas–Peucker 簡化封閉環。回傳的環不重複起點。
pub fn simplify_ring(ring: &[P2], tol: f32) -> Vec<P2> {
    if ring.len() <= 3 {
        return ring.to_vec();
    }
    // 以環上相距最遠的兩點當錨，各自簡化一半。
    let (mut ai, mut bi, mut best) = (0, 0, -1.0f32);
    for (i, p) in ring.iter().enumerate() {
        let d = dist(*p, ring[0]);
        if d > best {
            best = d;
            ai = 0;
            bi = i;
        }
    }
    if bi == ai {
        return ring.to_vec();
    }
    let half1: Vec<P2> = ring[ai..=bi].to_vec();
    let mut half2: Vec<P2> = ring[bi..].to_vec();
    half2.push(ring[0]);
    let mut out = simplify_open(&half1, tol);
    out.pop();
    let mut tail = simplify_open(&half2, tol);
    tail.pop();
    out.extend(tail);
    out
}

/// Douglas–Peucker 簡化開放折線，保留首尾。
pub fn simplify_open(points: &[P2], tol: f32) -> Vec<P2> {
    if points.len() < 3 {
        return points.to_vec();
    }
    let mut keep = vec![false; points.len()];
    keep[0] = true;
    *keep.last_mut().unwrap() = true;
    rdp(points, tol, &mut keep, 0, points.len() - 1);
    points
        .iter()
        .zip(keep)
        .filter_map(|(p, k)| k.then_some(*p))
        .collect()
}

fn rdp(points: &[P2], tol: f32, keep: &mut [bool], lo: usize, hi: usize) {
    if hi <= lo + 1 {
        return;
    }
    let (a, b) = (points[lo], points[hi]);
    let len = dist(a, b).max(1e-6);
    let (mut worst, mut idx) = (0.0, lo);
    for (i, &p) in points.iter().enumerate().take(hi).skip(lo + 1) {
        let d = ((b.0 - a.0) * (a.1 - p.1) - (a.0 - p.0) * (b.1 - a.1)).abs() / len;
        if d > worst {
            worst = d;
            idx = i;
        }
    }
    if worst > tol {
        keep[idx] = true;
        rdp(points, tol, keep, lo, idx);
        rdp(points, tol, keep, idx, hi);
    }
}

/// 直線 `p + t·dir`（`dir` 是單位向量）與環的所有交點參數 `t`，由小到大。
pub fn line_ring_hits(p: P2, dir: P2, ring: &[P2]) -> Vec<f32> {
    let mut hits = Vec::new();
    let n = ring.len();
    // 法向量：用「點到線的有號距離」判斷邊跨不跨線。
    let nrm = (-dir.1, dir.0);
    let side = |q: P2| (q.0 - p.0) * nrm.0 + (q.1 - p.1) * nrm.1;
    for i in 0..n {
        let (a, b) = (ring[i], ring[(i + 1) % n]);
        let (sa, sb) = (side(a), side(b));
        // 半開區間規則：頂點剛好壓在線上時只算一次。
        if (sa > 0.0) != (sb > 0.0) {
            let u = sa / (sa - sb);
            let q = (a.0 + (b.0 - a.0) * u, a.1 + (b.1 - a.1) * u);
            hits.push((q.0 - p.0) * dir.0 + (q.1 - p.1) * dir.1);
        }
    }
    hits.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
    hits
}

/// 直線落在區域（外環＋洞）內的區間 `[(t0, t1)]`。
pub fn line_inside_intervals(p: P2, dir: P2, rings: &[&[P2]]) -> Vec<(f32, f32)> {
    let mut hits: Vec<f32> = rings
        .iter()
        .flat_map(|r| line_ring_hits(p, dir, r))
        .collect();
    hits.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
    hits.chunks_exact(2)
        .filter(|c| c[1] - c[0] > EPS)
        .map(|c| (c[0], c[1]))
        .collect()
}

/// 兩個環是不是「幾乎是圓」。是的話回傳圓心與半徑。
pub fn ring_as_circle(ring: &[P2]) -> Option<(P2, f32)> {
    if ring.len() < 16 {
        return None;
    }
    let c = centroid_of_points(ring);
    let rs: Vec<f32> = ring.iter().map(|p| dist(*p, c)).collect();
    let mean = rs.iter().sum::<f32>() / rs.len() as f32;
    if mean < EPS {
        return None;
    }
    let dev = rs.iter().map(|r| (r - mean).abs()).fold(0.0, f32::max);
    (dev / mean < 0.03).then_some((c, mean))
}

pub fn rotate(p: P2, angle: f32) -> P2 {
    let (s, c) = angle.sin_cos();
    (p.0 * c - p.1 * s, p.0 * s + p.1 * c)
}

/// 用 45° 平行線填滿由 `rings` 圍出的區域（奇偶規則）。
///
/// `angle` 是線的方向（弧度），`spacing` 是相鄰線的垂直距離。
/// 回傳線段兩端；每條線只在區域內才畫。
pub fn hatch(rings: &[&[P2]], angle: f32, spacing: f32) -> Vec<(P2, P2)> {
    let all: Vec<P2> = rings.iter().flat_map(|r| r.iter().copied()).collect();
    let Some((lo, hi)) = bounds(&all) else {
        return Vec::new();
    };
    if spacing <= EPS {
        return Vec::new();
    }
    let dir = (angle.cos(), angle.sin());
    let nrm = (-dir.1, dir.0);
    // 把外框四角投到法向，得到掃描範圍。
    let corners = [lo, (hi.0, lo.1), hi, (lo.0, hi.1)];
    let (mut smin, mut smax) = (f32::MAX, f32::MIN);
    for c in corners {
        let s = c.0 * nrm.0 + c.1 * nrm.1;
        smin = smin.min(s);
        smax = smax.max(s);
    }
    let mut out = Vec::new();
    // 從 spacing 的整數倍開始：相鄰區域的剖面線才會對齊成同一組。
    let mut s = (smin / spacing).ceil() * spacing;
    while s <= smax {
        let origin = (nrm.0 * s, nrm.1 * s);
        for (t0, t1) in line_inside_intervals(origin, dir, rings) {
            out.push((
                (origin.0 + dir.0 * t0, origin.1 + dir.1 * t0),
                (origin.0 + dir.0 * t1, origin.1 + dir.1 * t1),
            ));
        }
        s += spacing;
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn square(x: f32, y: f32, s: f32) -> Vec<P2> {
        vec![(x, y), (x + s, y), (x + s, y + s), (x, y + s)]
    }

    #[test]
    fn area_sign_follows_orientation() {
        let ccw = square(0.0, 0.0, 10.0);
        assert!((signed_area(&ccw) - 100.0).abs() < 1e-3);
        let cw: Vec<P2> = ccw.iter().rev().copied().collect();
        assert!((signed_area(&cw) + 100.0).abs() < 1e-3);
    }

    #[test]
    fn holes_are_excluded_by_even_odd() {
        let outer = square(0.0, 0.0, 10.0);
        let hole = square(4.0, 4.0, 2.0);
        let rings: Vec<&[P2]> = vec![&outer, &hole];
        assert!(point_in_rings((1.0, 1.0), &rings));
        assert!(!point_in_rings((5.0, 5.0), &rings));
        assert!(!point_in_rings((20.0, 5.0), &rings));
    }

    #[test]
    fn a_line_through_a_holed_plate_has_two_intervals() {
        let outer = square(0.0, 0.0, 10.0);
        let hole = square(4.0, 4.0, 2.0);
        let rings: Vec<&[P2]> = vec![&outer, &hole];
        // y = 5 的水平線：穿過洞，應在 x∈[0,4] 與 [6,10] 兩段。
        let iv = line_inside_intervals((-5.0, 5.0), (1.0, 0.0), &rings);
        assert_eq!(iv.len(), 2);
        assert!((iv[0].0 - 5.0).abs() < 1e-3 && (iv[0].1 - 9.0).abs() < 1e-3);
        assert!((iv[1].0 - 11.0).abs() < 1e-3 && (iv[1].1 - 15.0).abs() < 1e-3);
    }

    #[test]
    fn a_line_through_a_vertex_counts_once() {
        let outer = square(0.0, 0.0, 10.0);
        let rings: Vec<&[P2]> = vec![&outer];
        // 剛好從角點擦過：不該算出奇數個交點而讓區間配錯對。
        let hits = line_ring_hits((-1.0, 10.0), (1.0, 0.0), &outer);
        assert_eq!(hits.len() % 2, 0, "{hits:?}");
        let _ = rings;
    }

    #[test]
    fn simplifying_a_dense_square_gives_four_corners() {
        let mut dense = Vec::new();
        for i in 0..20 {
            dense.push((i as f32 * 5.0, 0.0));
        }
        for i in 0..20 {
            dense.push((100.0, i as f32 * 5.0));
        }
        for i in 0..20 {
            dense.push((100.0 - i as f32 * 5.0, 100.0));
        }
        for i in 0..20 {
            dense.push((0.0, 100.0 - i as f32 * 5.0));
        }
        let s = simplify_ring(&dense, 1.0);
        assert_eq!(s.len(), 4, "{s:?}");
    }

    #[test]
    fn a_regular_polygon_is_a_circle_and_a_square_is_not() {
        let circ: Vec<P2> = (0..48)
            .map(|i| {
                let a = i as f32 / 48.0 * std::f32::consts::TAU;
                (10.0 * a.cos() + 3.0, 10.0 * a.sin() - 2.0)
            })
            .collect();
        let (c, r) = ring_as_circle(&circ).unwrap();
        assert!((c.0 - 3.0).abs() < 0.01 && (c.1 + 2.0).abs() < 0.01 && (r - 10.0).abs() < 0.2);
        assert!(ring_as_circle(&square(0.0, 0.0, 10.0)).is_none());
    }

    #[test]
    fn hatching_a_square_fills_it_with_parallel_lines() {
        let outer = square(0.0, 0.0, 10.0);
        let lines = hatch(&[&outer], std::f32::consts::FRAC_PI_4, 2.0);
        assert!(lines.len() >= 6, "{}", lines.len());
        for (a, b) in &lines {
            // 每條線都在方形內，斜率 1。
            for p in [a, b] {
                assert!(p.0 > -0.01 && p.0 < 10.01 && p.1 > -0.01 && p.1 < 10.01);
            }
            assert!(((b.1 - a.1) - (b.0 - a.0)).abs() < 1e-2);
        }
    }

    #[test]
    fn hatching_skips_the_hole() {
        let outer = square(0.0, 0.0, 10.0);
        let hole = square(3.0, 3.0, 4.0);
        let lines = hatch(&[&outer, &hole], 0.0, 1.0);
        // 水平線穿過洞時被切成兩段。
        let through = lines
            .iter()
            .filter(|(a, _)| (a.1 - 5.0).abs() < 1e-3)
            .count();
        assert_eq!(through, 2);
    }
}
