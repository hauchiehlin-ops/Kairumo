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

/// 80 Hz 二階 Butterworth 高通（16 kHz），**帶狀態**：串流處理時跨呼叫不會在
/// 區塊邊界產生喀聲。一次性處理整段可用 [`high_pass_80hz`]。
#[derive(Clone, Debug)]
pub struct HighPass80 {
    b0: f32,
    b1: f32,
    b2: f32,
    a1: f32,
    a2: f32,
    x1: f32,
    x2: f32,
    y1: f32,
    y2: f32,
}

impl Default for HighPass80 {
    fn default() -> Self {
        Self::new()
    }
}

impl HighPass80 {
    pub fn new() -> Self {
        // 係數由雙線性轉換算出（fc = 80 Hz, fs = 16 kHz, Q = 1/√2）。
        let fs = 16_000.0_f32;
        let fc = 80.0_f32;
        let w0 = 2.0 * std::f32::consts::PI * fc / fs;
        let alpha = w0.sin() / (2.0 * std::f32::consts::FRAC_1_SQRT_2);
        let cosw = w0.cos();
        let a0 = 1.0 + alpha;
        let b0 = (1.0 + cosw) / 2.0 / a0;
        Self {
            b0,
            b1: -(1.0 + cosw) / a0,
            b2: b0,
            a1: -2.0 * cosw / a0,
            a2: (1.0 - alpha) / a0,
            x1: 0.0,
            x2: 0.0,
            y1: 0.0,
            y2: 0.0,
        }
    }

    /// 原地處理。
    pub fn process(&mut self, pcm: &mut [f32]) {
        for s in pcm.iter_mut() {
            let x0 = *s;
            let y0 = self.b0 * x0 + self.b1 * self.x1 + self.b2 * self.x2
                - self.a1 * self.y1
                - self.a2 * self.y2;
            self.x2 = self.x1;
            self.x1 = x0;
            self.y2 = self.y1;
            self.y1 = y0;
            *s = y0;
        }
    }
}

/// 80 Hz 二階 Butterworth 高通（16 kHz）。原地處理一整段。
pub fn high_pass_80hz(pcm: &mut [f32]) {
    HighPass80::new().process(pcm);
}

// ───────────────────────── 慢速 AGC ─────────────────────────

/// 說話時的目標電平（RMS ≈ -26 dBFS）。
const AGC_TARGET_RMS: f32 = 0.05;
/// 最多放大 +18 dB：遠處講者拉得起來，但不會把安靜房間的嘶聲拉成主角。
const AGC_MAX_GAIN: f32 = 7.94;
/// 最多衰減 -6 dB。
const AGC_MIN_GAIN: f32 = 0.5;
/// 每個 20 ms 音框往目標靠近的比例。增益**上升**慢（約 3 秒），
/// **下降**快（約 0.5 秒）—— 突然變大聲時要先避免削波。
const AGC_RISE: f32 = 0.0067;
const AGC_FALL: f32 = 0.04;
const AGC_FRAME: usize = 320;

/// 慢速自動增益（只給**辨識**用，不改寫存檔的音訊）。
///
/// # 為什麼要慢、為什麼只在說話時調
///
/// 快速 AGC 會在每個停頓把增益拉滿，背景噪音跟著被放大 —— 辨識模型聽到的
/// 是「一陣一陣變大聲的冷氣」。這裡只有在 [`AdaptiveVad`] 判定為語音的音框
/// 才更新增益，靜音時維持原值；而且上升時間是秒級，只追「講者整體離得遠」
/// 這種慢變化，不追字與字之間的起伏。
#[derive(Debug)]
pub struct SlowAgc {
    gain: f32,
    vad: AdaptiveVad,
    frame: Vec<f32>,
}

impl Default for SlowAgc {
    fn default() -> Self {
        Self::new()
    }
}

impl SlowAgc {
    pub fn new() -> Self {
        Self {
            gain: 1.0,
            vad: AdaptiveVad::new(),
            frame: Vec::with_capacity(AGC_FRAME),
        }
    }

    /// 目前的增益（線性）。測試與診斷用。
    pub fn gain(&self) -> f32 {
        self.gain
    }

    /// 原地處理。增益在每個 20 ms 音框結束時更新，套用到下一段取樣。
    pub fn process(&mut self, pcm: &mut [f32]) {
        for s in pcm.iter_mut() {
            self.frame.push(*s);
            if self.frame.len() == AGC_FRAME {
                self.update_gain();
                self.frame.clear();
            }
            // 套用增益後硬限幅：增益只會慢慢變，所以這裡幾乎不會真的動到。
            *s = (*s * self.gain).clamp(-0.99, 0.99);
        }
    }

    fn update_gain(&mut self) {
        if !self.vad.is_speech(&self.frame) {
            return;
        }
        let rms = (self.frame.iter().map(|x| x * x).sum::<f32>() / AGC_FRAME as f32).sqrt();
        if rms <= 1e-6 {
            return;
        }
        let desired = (AGC_TARGET_RMS / rms).clamp(AGC_MIN_GAIN, AGC_MAX_GAIN);
        let rate = if desired < self.gain {
            AGC_FALL
        } else {
            AGC_RISE
        };
        // 在對數域移動，放大與衰減對稱。
        let next = self.gain.ln() + (desired.ln() - self.gain.ln()) * rate;
        self.gain = next.exp().clamp(AGC_MIN_GAIN, AGC_MAX_GAIN);
        // 削波保護：套用新增益後這個音框的峰值會超過上限，就立刻降下來。
        let peak = self.frame.iter().fold(0.0_f32, |m, x| m.max(x.abs()));
        if peak * self.gain > 0.95 {
            self.gain = (0.95 / peak).max(AGC_MIN_GAIN);
        }
    }
}

// ───────────────────────── 事後轉錄：VAD 切段 ─────────────────────────

/// 切段用的音框（20 ms）。
const SEG_FRAME: usize = 320;
/// 每段前後各多留的音框數（240 ms）：避免第一個字的子音、最後一個字的尾音被切掉。
const SEG_PAD_FRAMES: usize = 12;
/// 兩段之間的靜音短於這個（800 ms）就合併 —— 同一句話裡的換氣不該被切開。
const SEG_MERGE_GAP_FRAMES: usize = 40;
/// 真正有聲的音框少於這個（200 ms）的段落丟掉：多半是敲桌、咳嗽。
const SEG_MIN_VOICED_FRAMES: usize = 10;
/// 一段的長度上限（28 秒）。Whisper 的注意力窗是 30 秒，超過就會在中間被硬切。
const SEG_MAX_FRAMES: usize = 1_400;
/// 太長要切時，在最後這麼多音框（6 秒）裡找最安靜的地方下刀。
const SEG_SPLIT_SEARCH_FRAMES: usize = 300;
/// 絕對下限（≈ -56 dBFS）：低於這個的一律當成靜音。
const SEG_ABS_MIN_RMS: f32 = 0.0015;

/// 找出一段（已錄完的）音訊裡有人聲的區間，以取樣索引表示。
///
/// # 為什麼不直接用串流的 [`AdaptiveVad`]
///
/// 事後轉錄手上已經有整段音訊，可以先看完再決定門檻：噪音底線取整段音框
/// 響度的**第 3 百分位**（排除數位靜音），門檻定在底線之上約 +9.5 dB。串流版本
/// 開頭要花幾秒學習底線，短片段（即時轉錄送來的 5 秒段落）會吃虧。
///
/// 取這麼低的百分位是因為即時轉錄送來的段落**幾乎整段都是說話**：取第 10
/// 百分位的話底線會落在語音上，整段被判成「沒有人聲」（測試實際踩到過）。
/// 連續講話裡字與字的間隙通常仍超過 3%；平穩的冷氣聲則每個音框都差不多大，
/// 第 3 百分位就是它自己，門檻自然在它之上。
///
/// 回傳空陣列代表**整段沒有人聲** —— 呼叫端不該把它送進 Whisper，那正是
/// 「謝謝收看」這類幻聽的來源。
pub fn speech_spans(pcm: &[f32]) -> Vec<std::ops::Range<usize>> {
    let rms: Vec<f32> = pcm
        .chunks(SEG_FRAME)
        .map(|f| (f.iter().map(|s| s * s).sum::<f32>() / f.len().max(1) as f32).sqrt())
        .collect();
    if rms.is_empty() {
        return Vec::new();
    }
    let mut sorted: Vec<f32> = rms.iter().copied().filter(|&r| r > 1e-5).collect();
    if sorted.is_empty() {
        return Vec::new(); // 整段都是數位靜音
    }
    sorted.sort_by(|a, b| a.total_cmp(b));
    let floor = sorted[(sorted.len() - 1) * 3 / 100];
    let threshold = (floor * MARGIN).max(SEG_ABS_MIN_RMS);
    let voiced: Vec<bool> = rms.iter().map(|&r| r > threshold).collect();

    // 1. 連續有聲的音框 → 區間（音框索引），間隔短的合併。
    let mut runs: Vec<(usize, usize, usize)> = Vec::new(); // (start, end, voiced_count)
    let mut i = 0;
    while i < voiced.len() {
        if !voiced[i] {
            i += 1;
            continue;
        }
        let start = i;
        while i < voiced.len() && voiced[i] {
            i += 1;
        }
        let count = i - start;
        match runs.last_mut() {
            Some(last) if start - last.1 <= SEG_MERGE_GAP_FRAMES => {
                last.1 = i;
                last.2 += count;
            }
            _ => runs.push((start, i, count)),
        }
    }

    // 2. 去掉太短的、前後加邊、太長的在安靜處切開。
    let total = rms.len();
    let mut out: Vec<std::ops::Range<usize>> = Vec::new();
    for (start, end, count) in runs {
        if count < SEG_MIN_VOICED_FRAMES {
            continue;
        }
        let mut s = start.saturating_sub(SEG_PAD_FRAMES);
        let e = (end + SEG_PAD_FRAMES).min(total);
        // 加邊之後可能與前一段重疊：直接併進去。
        if let Some(last) = out.last_mut()
            && s <= last.end
        {
            s = last.start;
            out.pop();
        }
        while e - s > SEG_MAX_FRAMES {
            let lo = s + SEG_MAX_FRAMES - SEG_SPLIT_SEARCH_FRAMES;
            let hi = s + SEG_MAX_FRAMES;
            let cut = (lo..hi)
                .min_by(|&a, &b| rms[a].total_cmp(&rms[b]))
                .unwrap_or(hi);
            out.push(s..cut);
            s = cut;
        }
        out.push(s..e);
    }

    out.into_iter()
        .map(|r| (r.start * SEG_FRAME)..(r.end * SEG_FRAME).min(pcm.len()))
        .filter(|r| !r.is_empty())
        .collect()
}

/// 事後轉錄前要做哪些前處理。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct PrepOptions {
    /// 80 Hz 高通（去冷氣、桌面震動的隆隆聲）。
    pub high_pass: bool,
    /// 慢速 AGC（遠處講者）。
    pub agc: bool,
    /// 用 VAD 切出有人聲的段落，只把那些送進引擎。
    pub vad_segment: bool,
}

impl Default for PrepOptions {
    /// 預設：高通、AGC、VAD 切段全開。三者都是純 DSP、不會產生「模型幻覺」。
    /// 降噪（RNNoise）**不在這裡**：它可能讓辨識變差，只作為重新轉錄的選項。
    fn default() -> Self {
        Self {
            high_pass: true,
            agc: true,
            vad_segment: true,
        }
    }
}

impl PrepOptions {
    /// 全關 —— 與舊行為相同（整段原樣送進去），A/B 的對照組。
    pub fn raw() -> Self {
        Self {
            high_pass: false,
            agc: false,
            vad_segment: false,
        }
    }
}

/// 套用 [`PrepOptions`] 的訊號處理部分（高通、AGC），回傳處理後的副本。
pub fn condition(pcm: &[f32], opts: PrepOptions) -> Vec<f32> {
    let mut out = pcm.to_vec();
    if opts.high_pass {
        high_pass_80hz(&mut out);
    }
    if opts.agc {
        SlowAgc::new().process(&mut out);
    }
    out
}

/// 事後轉錄：前處理 → VAD 切段 → 逐段送進引擎 → 時間戳換回整段的時間軸。
///
/// 每一段都是 `feed` 之後立刻 `finish`，所以引擎看到的永遠是一句完整的話，
/// 不會被它自己的區塊長度從中間切開；整段沒有人聲時**一個字也不送**。
///
/// `pcm` 必須是 16 kHz 單聲道。
#[allow(clippy::single_range_in_vec_init)]
pub fn transcribe_segmented<E: crate::AsrEngine + ?Sized>(
    engine: &mut E,
    pcm: &[f32],
    opts: PrepOptions,
) -> Result<Vec<crate::AsrSegment>, crate::AsrError> {
    let mut audio = pcm.to_vec();
    if opts.high_pass {
        high_pass_80hz(&mut audio);
    }
    // 在高通之後、AGC 之前判斷：AGC 會改變相對電平，門檻該看原本的訊噪比。
    let spans = if opts.vad_segment {
        speech_spans(&audio)
    } else {
        vec![0..audio.len()]
    };
    if opts.agc {
        SlowAgc::new().process(&mut audio);
    }

    let us = |samples: usize| samples as u64 * 1_000_000 / 16_000;
    let mut out = Vec::new();
    // 引擎回傳的時間戳是「相對它被餵過的所有取樣」，記下每段開始前已經餵了多少。
    let mut fed = 0usize;
    for span in spans {
        let slice = &audio[span.clone()];
        let mut segs = engine.feed(slice)?;
        segs.extend(engine.finish()?);
        let fed_us = us(fed);
        let span_us = us(span.start);
        for mut s in segs {
            s.start_us = s.start_us.saturating_sub(fed_us) + span_us;
            s.end_us = s.end_us.saturating_sub(fed_us) + span_us;
            out.push(s);
        }
        fed += slice.len();
    }
    Ok(out)
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

    #[test]
    fn streaming_high_pass_matches_one_shot() {
        let mut rng = Lcg(6);
        let pcm = voice(&mut rng, 16_000, 0.3);
        let mut whole = pcm.clone();
        high_pass_80hz(&mut whole);
        let mut hp = HighPass80::new();
        let mut chunked = pcm.clone();
        for c in chunked.chunks_mut(777) {
            hp.process(c);
        }
        assert_eq!(whole, chunked, "分塊處理在邊界產生了差異");
    }

    #[test]
    fn slow_agc_lifts_distant_speech_but_not_silence() {
        let mut rng = Lcg(7);
        // 遠處講者：RMS ≈ 0.007（-43 dBFS）
        let mut far = Vec::new();
        for _ in 0..10 {
            far.extend(noise(&mut rng, 8_000, 0.001));
            far.extend(voice(&mut rng, 24_000, 0.01));
        }
        let mut agc = SlowAgc::new();
        agc.process(&mut far);
        assert!(agc.gain() > 3.0, "遠處講者沒有被拉起來：{}", agc.gain());
        assert!(agc.gain() <= AGC_MAX_GAIN);

        // 只有安靜的底噪：增益不動（不會把嘶聲拉成主角）。
        let mut hiss = noise(&mut rng, 16_000 * 10, 0.001);
        let mut agc = SlowAgc::new();
        agc.process(&mut hiss);
        assert!(
            (agc.gain() - 1.0).abs() < 1e-3,
            "靜音時增益被改了：{}",
            agc.gain()
        );
    }

    #[test]
    fn slow_agc_never_clips_loud_speech() {
        let mut rng = Lcg(8);
        let mut pcm = Vec::new();
        for _ in 0..5 {
            pcm.extend(voice(&mut rng, 32_000, 0.01));
            pcm.extend(voice(&mut rng, 16_000, 0.9)); // 突然很大聲
        }
        let mut agc = SlowAgc::new();
        agc.process(&mut pcm);
        let peak = pcm.iter().fold(0.0_f32, |m, x| m.max(x.abs()));
        assert!(peak <= 0.99);
    }

    /// 假引擎：記下被餵了什麼；每次 `finish` 回傳一段涵蓋這次餵入的文字，
    /// 時間戳依 `AsrEngine` 的約定是「相對所有已餵入的取樣」。
    #[derive(Debug, Default)]
    struct FakeEngine {
        pending: usize,
        total: usize,
        calls: Vec<usize>,
    }

    impl crate::AsrEngine for FakeEngine {
        fn feed(&mut self, pcm: &[f32]) -> Result<Vec<crate::AsrSegment>, crate::AsrError> {
            self.pending += pcm.len();
            Ok(Vec::new())
        }
        fn finish(&mut self) -> Result<Vec<crate::AsrSegment>, crate::AsrError> {
            if self.pending == 0 {
                return Ok(Vec::new());
            }
            let start = self.total;
            self.total += self.pending;
            self.calls.push(self.pending);
            self.pending = 0;
            let us = |s: usize| s as u64 * 1_000_000 / 16_000;
            Ok(vec![crate::AsrSegment {
                text: format!("seg{}", self.calls.len()),
                start_us: us(start),
                end_us: us(self.total),
                confidence: 1.0,
                is_final: true,
            }])
        }
        fn languages(&self) -> &[&str] {
            &["zh"]
        }
    }

    #[test]
    fn silence_or_steady_hum_is_never_sent_to_the_engine() {
        let mut rng = Lcg(9);
        for pcm in [
            vec![0.0_f32; 16_000 * 20],
            noise(&mut rng, 16_000 * 20, 0.0005),
            noise(&mut rng, 16_000 * 20, 0.1), // 很大聲但平穩的冷氣
        ] {
            let mut engine = FakeEngine::default();
            let out = transcribe_segmented(&mut engine, &pcm, PrepOptions::default()).unwrap();
            assert!(out.is_empty(), "沒有人聲卻產生了文字：{out:?}");
            assert!(
                engine.calls.is_empty(),
                "沒有人聲卻送進了引擎：{:?}",
                engine.calls
            );
        }
    }

    #[test]
    fn speech_islands_are_sent_separately_with_original_timestamps() {
        let mut rng = Lcg(10);
        let mut pcm = Vec::new();
        pcm.extend(noise(&mut rng, 16_000 * 5, 0.003)); // 0–5 s 靜音
        pcm.extend(voice(&mut rng, 16_000 * 3, 0.3)); //   5–8 s 說話
        pcm.extend(noise(&mut rng, 16_000 * 10, 0.003)); // 8–18 s 靜音
        pcm.extend(voice(&mut rng, 16_000 * 2, 0.3)); //   18–20 s 說話
        pcm.extend(noise(&mut rng, 16_000 * 4, 0.003));

        let mut engine = FakeEngine::default();
        let out = transcribe_segmented(&mut engine, &pcm, PrepOptions::default()).unwrap();
        assert_eq!(out.len(), 2, "{out:?}");
        // 送進引擎的總長遠小於整段（靜音沒有送）。
        let sent: usize = engine.calls.iter().sum();
        assert!(sent < 16_000 * 7, "送了太多靜音：{sent}");
        // 時間戳換回整段的時間軸（容許前後加邊 240 ms 與音框對齊）。
        let near = |us: u64, s: f32| (us as f32 / 1e6 - s).abs() < 0.35;
        assert!(near(out[0].start_us, 5.0), "{:?}", out[0]);
        assert!(near(out[0].end_us, 8.0), "{:?}", out[0]);
        assert!(near(out[1].start_us, 18.0), "{:?}", out[1]);
        assert!(near(out[1].end_us, 20.0), "{:?}", out[1]);
    }

    #[test]
    fn long_speech_is_split_below_the_whisper_window() {
        let mut rng = Lcg(11);
        let mut pcm = Vec::new();
        // 70 秒連續講話，每 4 秒有 300 ms 換氣（比合併門檻短，不會自然斷開）。
        for _ in 0..17 {
            pcm.extend(voice(&mut rng, 16_000 * 4 - 4_800, 0.3));
            pcm.extend(noise(&mut rng, 4_800, 0.003));
        }
        let spans = speech_spans(&pcm);
        assert!(spans.len() >= 3, "{spans:?}");
        for s in &spans {
            assert!(s.len() <= SEG_MAX_FRAMES * SEG_FRAME, "超過 28 秒：{s:?}");
        }
        let covered: usize = spans.iter().map(|s| s.len()).sum();
        assert!(covered as f32 > pcm.len() as f32 * 0.95, "切段漏掉了說話");
    }

    #[test]
    fn a_live_segment_that_is_all_speech_is_kept() {
        // 即時轉錄送來的 5 秒段落常常整段都在講話、沒有任何停頓。
        // 真實語音有音節起伏（約 4 Hz）；用包絡模擬。
        let mut rng = Lcg(13);
        let pcm: Vec<f32> = (0..16_000 * 5)
            .map(|i| {
                let t = i as f32 / 16_000.0;
                let env = 0.15 + 0.85 * (t * 4.0 * std::f32::consts::PI).sin().abs();
                ((t * 220.0 * 2.0 * std::f32::consts::PI).sin() * 0.9 + rng.next() * 0.1)
                    * 0.3
                    * env
            })
            .collect();
        let spans = speech_spans(&pcm);
        let covered: usize = spans.iter().map(|s| s.len()).sum();
        assert!(
            covered as f32 > pcm.len() as f32 * 0.9,
            "整段說話被丟掉了：{spans:?}"
        );
    }

    #[test]
    fn raw_options_send_the_whole_clip_once() {
        let mut rng = Lcg(12);
        let pcm = noise(&mut rng, 16_000 * 3, 0.0005);
        let mut engine = FakeEngine::default();
        let out = transcribe_segmented(&mut engine, &pcm, PrepOptions::raw()).unwrap();
        assert_eq!(engine.calls, vec![pcm.len()]);
        assert_eq!(out.len(), 1);
        assert_eq!(out[0].start_us, 0);
    }
}
