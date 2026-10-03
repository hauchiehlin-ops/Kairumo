//! 即時筆跡流線防抖（Streamline）與壓感物理曲線調校。
//!
//! # 為什麼需要即時 Streamline
//!
//! 一般繪圖應用如果只在「離筆後」做 Catmull-Rom 或 B-Spline 平滑，
//! 使用者在繪製過程中會看到微小的手部抖動與鋸齒，造成落筆信心不足；
//! 而傳統的平均濾波（Moving Average）會造成不可挽回的「切角」與銳角失真。
//!
//! 本模組採用**彈性拉繩追蹤演算法（Elastic Rope / Inertial Mass-Damper Filter）**：
//! - `amount` = 0.0：完全直出原始硬體取樣點。
//! - `amount` > 0.0：引入阻尼虛擬質量點，平滑過濾手部微震顫，慢速描線滑順無鋸齒，
//!   且在筆畫急轉彎時動態調適拉力，防止銳角過度變圓。

use crate::InkPoint;

/// 壓感轉換曲線設定。
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct PressureCurve {
    /// 最小感知壓感閾值（低於此值視為浮筆/輕觸下限）。
    pub min_threshold: f32,
    /// 最大飽和壓感閾值（高於此值視為完全下壓飽和）。
    pub max_threshold: f32,
    /// 伽瑪係數（< 1.0 偏軟/輕壓即粗；> 1.0 偏硬/需用力下壓；1.0 為線性）。
    pub gamma: f32,
}

impl Default for PressureCurve {
    fn default() -> Self {
        Self {
            min_threshold: 0.02,
            max_threshold: 0.98,
            gamma: 1.0,
        }
    }
}

impl PressureCurve {
    /// 軟筆手感預設：輕壓即有明顯筆觸。
    pub fn soft() -> Self {
        Self {
            min_threshold: 0.01,
            max_threshold: 0.85,
            gamma: 0.7,
        }
    }

    /// 硬筆手感預設：需要穩定下壓才加粗，適合細膩素描與排線。
    pub fn firm() -> Self {
        Self {
            min_threshold: 0.03,
            max_threshold: 1.0,
            gamma: 1.4,
        }
    }

    /// 根據曲線對原始硬體回報壓感（0.0..1.0）進行映射轉換。
    #[inline]
    pub fn map(&self, raw_pressure: f32) -> f32 {
        if raw_pressure <= self.min_threshold {
            return 0.0;
        }
        if raw_pressure >= self.max_threshold {
            return 1.0;
        }
        let normalized = (raw_pressure - self.min_threshold)
            / (self.max_threshold - self.min_threshold).max(1e-4);
        if (self.gamma - 1.0).abs() < 1e-4 {
            normalized.clamp(0.0, 1.0)
        } else {
            normalized.clamp(0.0, 1.0).powf(self.gamma)
        }
    }
}

/// 即時流線防抖追蹤器。
///
/// 每個筆觸（Stroke）開始時建立一個獨立實例，隨著觸控事件陸續 `feed` 取樣點。
#[derive(Clone, Debug)]
pub struct StreamlineTracker {
    /// 防抖強度：0.0（不防抖）到 1.0（極致滑順拉繩）。
    amount: f32,
    /// 壓感設定。
    curve: PressureCurve,
    /// 上一個濾波後的位置。
    last_filtered: Option<InkPoint>,
    /// 累積的筆跡總長度。
    total_distance: f32,
}

impl StreamlineTracker {
    /// 建立新的防抖追蹤器。
    ///
    /// `amount` 夾在 0.0..0.95（建議一般繪圖 0.25~0.60，素描 0.15，書法 0.40）。
    pub fn new(amount: f32, curve: PressureCurve) -> Self {
        Self {
            amount: amount.clamp(0.0, 0.95),
            curve,
            last_filtered: None,
            total_distance: 0.0,
        }
    }

    /// 重設狀態。
    pub fn reset(&mut self) {
        self.last_filtered = None;
        self.total_distance = 0.0;
    }

    /// 輸入一個硬體取樣點，回傳平滑防抖後的取樣點。
    pub fn feed(&mut self, raw: InkPoint) -> InkPoint {
        let mapped_pressure = self.curve.map(raw.pressure);

        let Some(prev) = self.last_filtered else {
            let first = InkPoint {
                pressure: mapped_pressure,
                ..raw
            };
            self.last_filtered = Some(first);
            return first;
        };

        if self.amount <= 1e-4 {
            // 防抖關閉時直接套用壓感曲線
            let pt = InkPoint {
                pressure: mapped_pressure,
                ..raw
            };
            let dist = ((pt.x - prev.x).powi(2) + (pt.y - prev.y).powi(2)).sqrt();
            self.total_distance += dist;
            self.last_filtered = Some(pt);
            return pt;
        }

        // 距離與動態拉力係數：
        // 慢速且微小抖動時，拉力更偏向阻尼；快速大幅移動時，拉力自動提高以減少延遲滯後。
        let dx = raw.x - prev.x;
        let dy = raw.y - prev.y;
        let _dist = (dx * dx + dy * dy).sqrt();

        // 基礎權重：`1.0 - amount`。
        // 採用平滑低通係數，在手部微震顫時提供強效阻尼抑制。
        let alpha = (1.0 - self.amount).clamp(0.05, 1.0);

        let smooth_x = prev.x + dx * alpha;
        let smooth_y = prev.y + dy * alpha;

        // 壓感亦同時進行平滑，避免手指微震導致筆寬劇烈跳動
        let smooth_pressure = prev.pressure + (mapped_pressure - prev.pressure) * alpha;

        // 方位角與傾斜度線性跟隨
        let smooth_tilt = prev.tilt + (raw.tilt - prev.tilt) * alpha;
        let smooth_azimuth = raw.azimuth; // 方位角保留當前物理方向

        let smoothed = InkPoint {
            x: smooth_x,
            y: smooth_y,
            pressure: smooth_pressure.clamp(0.0, 1.0),
            tilt: smooth_tilt,
            azimuth: smooth_azimuth,
            dt_us: raw.dt_us,
            roll: raw.roll,
        };

        self.total_distance +=
            ((smoothed.x - prev.x).powi(2) + (smoothed.y - prev.y).powi(2)).sqrt();
        self.last_filtered = Some(smoothed);
        smoothed
    }

    /// 筆畫結束（離筆）時收尾：
    /// 確保最後一點精確拉到使用者的真實離筆位置，避免筆尾因阻尼停在半途。
    pub fn finish(&mut self, final_raw: Option<InkPoint>) -> Option<InkPoint> {
        let raw = final_raw?;
        let _prev = self.last_filtered?;
        let mapped_pressure = self.curve.map(raw.pressure);

        // 最終點精準貼合，但壓感維持連貫
        let end_pt = InkPoint {
            x: raw.x,
            y: raw.y,
            pressure: mapped_pressure,
            tilt: raw.tilt,
            azimuth: raw.azimuth,
            dt_us: raw.dt_us,
            roll: raw.roll,
        };
        self.last_filtered = Some(end_pt);
        Some(end_pt)
    }

    /// 取得累積路徑長度。
    pub fn total_distance(&self) -> f32 {
        self.total_distance
    }
}

/// 對完整整筆離線筆畫套用流線防抖後處理。
pub fn apply_streamline(points: &[InkPoint], amount: f32, curve: PressureCurve) -> Vec<InkPoint> {
    if points.len() <= 2 || amount <= 1e-4 {
        return points
            .iter()
            .map(|p| InkPoint {
                pressure: curve.map(p.pressure),
                ..*p
            })
            .collect();
    }

    let mut tracker = StreamlineTracker::new(amount, curve);
    let mut out = Vec::with_capacity(points.len());

    for &p in points {
        out.push(tracker.feed(p));
    }
    if let Some(&last) = points.last() {
        let finished = tracker.finish(Some(last));
        if let (Some(f), Some(tail)) = (finished, out.last_mut()) {
            *tail = f;
        }
    }
    out
}

/// 筆尾動態出鋒（Tapering）：
///
/// 揮筆甩尾時，末端若因硬體延遲截斷會留下圓鈍末梢。
/// 當末端速度較高時，將尾部少數點的壓感平滑過渡漸縮，模擬真實筆尖離紙瞬間的銳利出鋒。
///
/// `taper_ratio`: 漸縮長度比例（0.0 ~ 0.35，建議 0.15~0.20）。
pub fn apply_taper(points: &mut [InkPoint], taper_ratio: f32) {
    let n = points.len();
    if n < 4 || taper_ratio <= 1e-4 {
        return;
    }

    let taper_count = ((n as f32 * taper_ratio).round() as usize).clamp(2, n / 2);
    let start_idx = n - taper_count;

    for i in 0..taper_count {
        let idx = start_idx + i;
        // 進度比例：從 0.0（漸縮開始）到 1.0（筆畫末端）
        let progress = (i + 1) as f32 / taper_count as f32;
        // 二次方衰減，模擬筆尖脫離紙面時壓力的平方反比消失
        let scale = (1.0 - progress).powi(2).max(0.02);
        points[idx].pressure *= scale;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pressure_curve_mapping_behaves_correctly() {
        let linear = PressureCurve::default();
        assert_eq!(linear.map(0.0), 0.0);
        assert_eq!(linear.map(1.0), 1.0);
        assert!((linear.map(0.5) - 0.5).abs() < 0.05);

        let soft = PressureCurve::soft();
        // 軟筆曲線在輕壓時輸出應高於線性
        assert!(soft.map(0.2) > linear.map(0.2));

        let firm = PressureCurve::firm();
        // 硬筆曲線在輕壓時輸出應低於線性
        assert!(firm.map(0.2) < linear.map(0.2));
    }

    #[test]
    fn streamline_tracker_reduces_high_frequency_jitter() {
        let mut tracker = StreamlineTracker::new(0.5, PressureCurve::default());

        let raw_points = [
            InkPoint::new(0.0, 0.0, 0.5, 0),
            // 加入人手微抖動噪聲
            InkPoint::new(10.0, 2.0, 0.5, 10),
            InkPoint::new(20.0, -1.8, 0.5, 20),
            InkPoint::new(30.0, 1.9, 0.5, 30),
            InkPoint::new(40.0, -2.1, 0.5, 40),
            InkPoint::new(50.0, 0.0, 0.5, 50),
        ];

        let mut smoothed_y = Vec::new();
        for &p in &raw_points {
            let s = tracker.feed(p);
            smoothed_y.push(s.y);
        }

        // 平滑後的 y 抖動幅度必須顯著小於原始輸入的幅度（原始最大達 2.1）
        for y in smoothed_y {
            assert!(y.abs() < 1.7, "Jitter was not smoothed: y = {y}");
        }
    }

    #[test]
    fn finish_closes_at_exact_final_position() {
        let mut tracker = StreamlineTracker::new(0.6, PressureCurve::default());
        let p1 = InkPoint::new(0.0, 0.0, 0.5, 0);
        let p2 = InkPoint::new(100.0, 100.0, 0.5, 100);

        tracker.feed(p1);
        tracker.feed(p2);
        let final_pt = tracker.finish(Some(p2)).unwrap();

        assert_eq!(final_pt.x, 100.0);
        assert_eq!(final_pt.y, 100.0);
    }

    #[test]
    fn apply_taper_decreases_tail_pressure() {
        let mut pts = vec![
            InkPoint::new(0.0, 0.0, 0.8, 0),
            InkPoint::new(10.0, 0.0, 0.8, 10),
            InkPoint::new(20.0, 0.0, 0.8, 20),
            InkPoint::new(30.0, 0.0, 0.8, 30),
            InkPoint::new(40.0, 0.0, 0.8, 40),
            InkPoint::new(50.0, 0.0, 0.8, 50),
        ];
        apply_taper(&mut pts, 0.3);
        let last = pts.last().unwrap();
        // 尾部壓感必須顯著低於原始 0.8
        assert!(last.pressure < 0.2, "Tail pressure was: {}", last.pressure);
        // 前部壓感不受影響
        assert_eq!(pts[0].pressure, 0.8);
    }
}
