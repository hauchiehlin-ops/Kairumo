//! 收音前處理與品質量測。
//!
//! 三個彼此獨立的小東西，全是純 DSP、不需要模型、兩個平台共用同一份：
//!
//! - [`AdaptiveVad`]：會追蹤**背景噪音底線**的能量式語音偵測。固定門檻法在教室裡有兩種死法 ——
//!   冷氣聲比門檻大（整場都被當成語音），遠處講者比門檻小（整場都被當成靜音）。
//!   自適應版本把門檻定在「噪音底線之上」，兩種情況都撐得住。Android 的 `ort` 沒有預編譯二進位，
//!   沒有 Silero 可用，這就是它的 VAD。
//! - [`QualityMeter`]：錄音當下便宜地累計電平、削波與噪音底線，結束時給一句人話的判斷
//!   （太小聲／爆音／背景太吵），讓使用者知道**下次該把裝置靠近講者**。
//! - [`high_pass_80hz`]：80 Hz 高通，濾掉冷氣、桌面震動的低頻隆隆聲，幾乎沒有副作用。

use crate::pipeline::VoiceActivityDetector;

// ───────────────────────── 自適應 VAD ─────────────────────────

/// 追蹤噪音底線的能量式 VAD（以 20 ms 左右的音框為單位餵入）。
#[derive(Debug)]
pub struct AdaptiveVad {
    floor: f32,
    speaking: bool,
    /// 目前這一段連續「語音」的音框數。
    run: u32,
    /// 語音結束後的殘留（hangover）音框數，避免詞與詞之間被切斷。
    hang: u32,
}

/// 絕對下限：再安靜的房間，低於這個 RMS 都不算語音（約 -46 dBFS）。
const ABS_MIN: f32 = 0.005;
/// 語音要比噪音底線大幾倍（≈ +9.5 dB）。
const MARGIN: f32 = 3.0;
/// 連續「語音」超過這麼多音框（約 3 秒）仍然沒停 —— 多半是持續性的噪音，讓底線慢慢爬上去。
const STUCK_FRAMES: u32 = 150;
const HANGOVER_FRAMES: u32 = 8;

impl Default for AdaptiveVad {
    fn default() -> Self {
        Self::new()
    }
}

impl AdaptiveVad {
    pub fn new() -> Self {
        Self {
            floor: ABS_MIN / MARGIN,
            speaking: false,
            run: 0,
            hang: 0,
        }
    }

    /// 目前估計的噪音底線（RMS）。測試與診斷用。
    pub fn noise_floor(&self) -> f32 {
        self.floor
    }

    fn threshold(&self) -> f32 {
        (self.floor * MARGIN).max(ABS_MIN)
    }
}

impl VoiceActivityDetector for AdaptiveVad {
    fn is_speech(&mut self, frame: &[f32]) -> bool {
        if frame.is_empty() {
            return false;
        }
        let rms = (frame.iter().map(|s| s * s).sum::<f32>() / frame.len() as f32).sqrt();
        let loud = rms > self.threshold();

        if loud {
            self.run += 1;
            self.hang = HANGOVER_FRAMES;
            // 語音期間底線不動 —— 否則講話本身會把底線墊高。
            // 例外：持續太久不停的，多半是風扇／冷氣，讓底線緩緩追上去。
            if self.run > STUCK_FRAMES {
                self.floor += (rms - self.floor) * 0.01;
            }
        } else {
            self.run = 0;
            // 靜音：底線快速往下、慢速往上。
            if rms < self.floor {
                self.floor += (rms - self.floor) * 0.1;
            } else {
                self.floor += (rms - self.floor) * 0.02;
            }
            self.floor = self.floor.max(ABS_MIN / MARGIN / 4.0);
        }

        if loud {
            self.speaking = true;
        } else if self.hang > 0 {
            self.hang -= 1;
        } else {
            self.speaking = false;
        }
        self.speaking
    }
}

// ───────────────────────── 品質量測 ─────────────────────────

/// 一份錄音的品質判斷。
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct QualityReport {
    pub duration_s: f32,
    /// 說話時的電平（音框響度第 90 百分位，dBFS）。
    pub speech_dbfs: f32,
    /// 背景噪音底線（第 10 百分位，dBFS）。
    pub noise_floor_dbfs: f32,
    /// 兩者之差。越大越好；低於約 15 dB 時語音辨識明顯變差。
    pub snr_db: f32,
    /// 削波（|x| ≥ 0.99）取樣所占比例。
    pub clipped_fraction: f32,
    pub verdict: QualityVerdict,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum QualityVerdict {
    /// 沒什麼可說的。
    Good,
    /// 太短，不下判斷。
    TooShort,
    /// 整體太小聲：多半是離講者太遠。
    TooQuiet,
    /// 有爆音：輸入太大或太靠近。
    Clipping,
    /// 背景噪音太高、訊噪比低。
    Noisy,
}

const FRAME: usize = 320;
const BINS: usize = 91; // -90 .. 0 dBFS，1 dB 一格

/// 錄音當下累計：每個取樣只做幾次乘加，可以放在即時路徑上。
#[derive(Clone, Debug)]
pub struct QualityMeter {
    hist: [u32; BINS],
    frames: u32,
    samples: u64,
    clipped: u64,
    carry: Vec<f32>,
}

impl Default for QualityMeter {
    fn default() -> Self {
        Self::new()
    }
}

fn to_dbfs(rms: f32) -> f32 {
    20.0 * rms.max(1e-6).log10()
}

impl QualityMeter {
    pub fn new() -> Self {
        Self {
            hist: [0; BINS],
            frames: 0,
            samples: 0,
            clipped: 0,
            carry: Vec::with_capacity(FRAME),
        }
    }

    pub fn feed(&mut self, pcm: &[f32]) {
        for &s in pcm {
            self.samples += 1;
            if s.abs() >= 0.99 {
                self.clipped += 1;
            }
            self.carry.push(s);
            if self.carry.len() == FRAME {
                let rms = (self.carry.iter().map(|x| x * x).sum::<f32>() / FRAME as f32).sqrt();
                let bin = (to_dbfs(rms) + 90.0).clamp(0.0, (BINS - 1) as f32) as usize;
                self.hist[bin] += 1;
                self.frames += 1;
                self.carry.clear();
            }
        }
    }

    fn percentile(&self, p: f32) -> f32 {
        let target = ((self.frames as f32) * p).ceil().max(1.0) as u32;
        let mut seen = 0;
        for (i, &c) in self.hist.iter().enumerate() {
            seen += c;
            if seen >= target {
                return i as f32 - 90.0;
            }
        }
        0.0
    }

    pub fn report(&self) -> QualityReport {
        let duration_s = self.samples as f32 / 16_000.0;
        let speech = self.percentile(0.90);
        let floor = self.percentile(0.10);
        let snr = speech - floor;
        let clipped_fraction = if self.samples == 0 {
            0.0
        } else {
            self.clipped as f32 / self.samples as f32
        };
        let verdict = if duration_s < 5.0 {
            QualityVerdict::TooShort
        } else if clipped_fraction > 0.001 {
            QualityVerdict::Clipping
        } else if speech < -45.0 {
            QualityVerdict::TooQuiet
        } else if snr < 15.0 {
            QualityVerdict::Noisy
        } else {
            QualityVerdict::Good
        };
        QualityReport {
            duration_s,
            speech_dbfs: speech,
            noise_floor_dbfs: floor,
            snr_db: snr,
            clipped_fraction,
            verdict,
        }
    }
}

// ───────────────────────── 高通 ─────────────────────────

/// 80 Hz 二階 Butterworth 高通（16 kHz）。原地處理。
pub fn high_pass_80hz(pcm: &mut [f32]) {
    // 係數由雙線性轉換算出（fc = 80 Hz, fs = 16 kHz, Q = 1/√2）。
    let fs = 16_000.0_f32;
    let fc = 80.0_f32;
    let w0 = 2.0 * std::f32::consts::PI * fc / fs;
    let alpha = w0.sin() / (2.0 * std::f32::consts::FRAC_1_SQRT_2);
    let cosw = w0.cos();
    let a0 = 1.0 + alpha;
    let b0 = (1.0 + cosw) / 2.0 / a0;
    let b1 = -(1.0 + cosw) / a0;
    let b2 = b0;
    let a1 = -2.0 * cosw / a0;
    let a2 = (1.0 - alpha) / a0;
    let (mut x1, mut x2, mut y1, mut y2) = (0.0_f32, 0.0_f32, 0.0_f32, 0.0_f32);
    for s in pcm.iter_mut() {
        let x0 = *s;
        let y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
        x2 = x1;
        x1 = x0;
        y2 = y1;
        y1 = y0;
        *s = y0;
    }
}

#[cfg(test)]
#[allow(clippy::chunks_exact_to_as_chunks)] // 測試裡的區塊大小是常數，不需要 as_chunks 的型別收益
mod tests {
    use super::*;
    use crate::pipeline::EnergyVad;

    /// 確定性的偽隨機（不引入 rand 相依）。
    struct Lcg(u32);
    impl Lcg {
        fn next(&mut self) -> f32 {
            self.0 = self.0.wrapping_mul(1664525).wrapping_add(1013904223);
            (self.0 >> 8) as f32 / (1u32 << 24) as f32 * 2.0 - 1.0
        }
    }

    fn noise(rng: &mut Lcg, n: usize, amp: f32) -> Vec<f32> {
        (0..n).map(|_| rng.next() * amp).collect()
    }

    /// 類語音：400 Hz 載波加雜訊，整體 RMS ≈ amp/√2。
    fn voice(rng: &mut Lcg, n: usize, amp: f32) -> Vec<f32> {
        (0..n)
            .map(|i| {
                let t = i as f32 / 16_000.0;
                (t * 400.0 * 2.0 * std::f32::consts::PI).sin() * amp * 0.9 + rng.next() * amp * 0.1
            })
            .collect()
    }

    fn rate(vad: &mut dyn VoiceActivityDetector, pcm: &[f32]) -> f32 {
        let frames = pcm.chunks_exact(FRAME);
        let total = frames.len() as f32;
        let hit = pcm.chunks_exact(FRAME).filter(|f| vad.is_speech(f)).count() as f32;
        hit / total
    }

    #[test]
    fn steady_hum_louder_than_a_fixed_threshold_is_not_speech() {
        let mut rng = Lcg(1);
        let hum = noise(&mut rng, 16_000 * 12, 0.12); // RMS ≈ 0.07，遠大於舊的固定門檻 0.02
        let mut fixed = EnergyVad { threshold: 0.02 };
        assert!(
            rate(&mut fixed, &hum) > 0.95,
            "前提：固定門檻會把整段當語音"
        );
        let mut adaptive = AdaptiveVad::new();
        // 前幾秒底線還在爬；看後半段。
        let _ = rate(&mut adaptive, &hum[..16_000 * 6]);
        let tail = rate(&mut adaptive, &hum[16_000 * 6..]);
        assert!(tail < 0.05, "穩定噪音被當成語音：{tail}");
    }

    #[test]
    fn quiet_distant_speech_is_detected_where_a_fixed_threshold_misses_it() {
        let mut rng = Lcg(2);
        let mut pcm = Vec::new();
        for _ in 0..6 {
            pcm.extend(noise(&mut rng, 16_000, 0.002));
            pcm.extend(voice(&mut rng, 16_000, 0.03)); // RMS ≈ 0.02，貼著固定門檻
        }
        let speech_only: Vec<f32> = pcm
            .chunks(16_000)
            .skip(1)
            .step_by(2)
            .flatten()
            .copied()
            .collect();
        let mut fixed = EnergyVad { threshold: 0.05 };
        assert!(
            rate(&mut fixed, &speech_only) < 0.1,
            "前提：這個音量在固定門檻下聽不到"
        );
        let mut adaptive = AdaptiveVad::new();
        let mut hit = 0usize;
        let mut total = 0usize;
        for (i, sec) in pcm.chunks_exact(16_000).enumerate() {
            let is_voice = i % 2 == 1;
            for f in sec.chunks_exact(FRAME) {
                let v = adaptive.is_speech(f);
                if is_voice {
                    total += 1;
                    hit += usize::from(v);
                }
            }
        }
        assert!(
            hit as f32 / total as f32 > 0.85,
            "遠處講者沒被偵測到：{hit}/{total}"
        );
    }

    #[test]
    fn speech_over_hum_is_found_and_the_gaps_are_not() {
        let mut rng = Lcg(3);
        let mut adaptive = AdaptiveVad::new();
        // 暖機 5 秒純噪音。
        let _ = rate(&mut adaptive, &noise(&mut rng, 16_000 * 5, 0.08));
        let mut talk_hit = 0.0;
        let mut gap_hit = 0.0;
        for _ in 0..4 {
            gap_hit += rate(&mut adaptive, &noise(&mut rng, 16_000, 0.08));
            talk_hit += rate(&mut adaptive, &voice(&mut rng, 16_000, 0.5));
        }
        assert!(
            talk_hit / 4.0 > 0.9,
            "噪音上的說話沒被偵測到：{}",
            talk_hit / 4.0
        );
        assert!(
            gap_hit / 4.0 < 0.25,
            "說話間隙被當成語音：{}",
            gap_hit / 4.0
        );
    }

    #[test]
    fn long_speech_does_not_raise_the_floor_much() {
        let mut rng = Lcg(4);
        let mut adaptive = AdaptiveVad::new();
        let _ = rate(&mut adaptive, &noise(&mut rng, 16_000 * 3, 0.004));
        let before = adaptive.noise_floor();
        let _ = rate(&mut adaptive, &voice(&mut rng, 16_000 * 2, 0.3));
        assert!(adaptive.noise_floor() < before * 2.0, "講話把底線墊高了");
    }

    #[test]
    fn meter_flags_clipping_quiet_and_noisy_recordings() {
        let mut rng = Lcg(5);
        // 爆音
        let mut m = QualityMeter::new();
        let mut loud = voice(&mut rng, 16_000 * 8, 1.4);
        for s in &mut loud {
            *s = s.clamp(-1.0, 1.0);
        }
        m.feed(&loud);
        assert_eq!(m.report().verdict, QualityVerdict::Clipping);
        // 太小聲
        let mut m = QualityMeter::new();
        m.feed(&voice(&mut rng, 16_000 * 8, 0.002));
        assert_eq!(m.report().verdict, QualityVerdict::TooQuiet);
        // 噪音：說話與噪音幾乎一樣大
        let mut m = QualityMeter::new();
        for _ in 0..8 {
            m.feed(&noise(&mut rng, 8_000, 0.2));
            m.feed(&voice(&mut rng, 8_000, 0.25));
        }
        assert_eq!(m.report().verdict, QualityVerdict::Noisy);
        // 良好：說話明顯高於底線
        let mut m = QualityMeter::new();
        for _ in 0..10 {
            m.feed(&noise(&mut rng, 8_000, 0.004));
            m.feed(&voice(&mut rng, 24_000, 0.25));
        }
        let r = m.report();
        assert_eq!(r.verdict, QualityVerdict::Good, "{r:?}");
        assert!(r.snr_db > 25.0);
        // 太短不下判斷
        let mut m = QualityMeter::new();
        m.feed(&voice(&mut rng, 16_000, 0.3));
        assert_eq!(m.report().verdict, QualityVerdict::TooShort);
    }

    #[test]
    fn high_pass_removes_rumble_and_keeps_speech_band() {
        let n = 16_000 * 2;
        let tone = |hz: f32| -> Vec<f32> {
            (0..n)
                .map(|i| (i as f32 / 16_000.0 * hz * 2.0 * std::f32::consts::PI).sin())
                .collect()
        };
        let rms =
            |v: &[f32]| (v[n / 2..].iter().map(|s| s * s).sum::<f32>() / (n / 2) as f32).sqrt();
        let mut low = tone(30.0);
        let mut mid = tone(1000.0);
        high_pass_80hz(&mut low);
        high_pass_80hz(&mut mid);
        assert!(rms(&low) < 0.2, "30 Hz 隆隆聲沒有被壓掉：{}", rms(&low));
        assert!(rms(&mid) > 0.69, "1 kHz 人聲頻段被削弱了：{}", rms(&mid));
    }
}
