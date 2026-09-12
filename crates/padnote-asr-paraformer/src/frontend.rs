//! Paraformer 的特徵前端：Kaldi 相容 fbank → LFR 堆疊 → CMVN。
//!
//! ```text
//! 16 kHz PCM ─▶ fbank(80 維) ─▶ LFR(m=7, n=6 → 560 維) ─▶ CMVN ─▶ encoder
//! ```
//!
//! ## 為什麼 dither 設為 0
//! FunASR 的預設 `dither=1.0` 會加入隨機抖動，**同一段音訊兩次呼叫的特徵
//! 相差可達 0.27**。對 Padnote 來說這不可接受：同一份錄音重跑轉錄應該得到
//! 相同結果，否則使用者會看到轉錄內容莫名變動，測試也無法迴歸。
//!
//! 代價是失去 dither 對極安靜訊號的數值穩定作用（log(0) 保護），
//! 這裡改以 energy floor 處理。

use rustfft::FftPlanner;
use rustfft::num_complex::Complex32;

pub const SAMPLE_RATE: u32 = 16_000;
pub const N_MELS: usize = 80;
/// 25 ms
pub const FRAME_LENGTH: usize = 400;
/// 10 ms
pub const FRAME_SHIFT: usize = 160;
/// 大於等於 `FRAME_LENGTH` 的 2 的次方
const FFT_SIZE: usize = 512;
const PREEMPHASIS: f32 = 0.97;
/// Kaldi 的預設低頻截止
const LOW_FREQ: f32 = 20.0;
/// log 的下限，避免 log(0)。Kaldi 用 FLT_EPSILON。
const EPSILON: f32 = f32::EPSILON;

/// LFR（low frame rate）：堆疊 m 幀、步長 n。
pub const LFR_M: usize = 7;
pub const LFR_N: usize = 6;
/// LFR 之後的維度
pub const FEATURE_DIM: usize = N_MELS * LFR_M;

/// 赫茲轉梅爾刻度（Kaldi 使用的 1127 係數版本）。
pub fn hz_to_mel(hz: f32) -> f32 {
    1127.0 * (1.0 + hz / 700.0).ln()
}

/// 梅爾刻度轉回赫茲。供測試與除錯使用。
pub fn mel_to_hz(mel: f32) -> f32 {
    700.0 * ((mel / 1127.0).exp() - 1.0)
}

/// 三角梅爾濾波器組。
///
/// 依 Kaldi 的定義：在梅爾刻度上等距切點，每個濾波器覆蓋相鄰三個切點。
fn mel_filterbank() -> Vec<Vec<f32>> {
    let nyquist = SAMPLE_RATE as f32 / 2.0;
    let num_bins = FFT_SIZE / 2 + 1;
    let fft_bin_width = SAMPLE_RATE as f32 / FFT_SIZE as f32;

    let mel_low = hz_to_mel(LOW_FREQ);
    let mel_high = hz_to_mel(nyquist);
    let mel_delta = (mel_high - mel_low) / (N_MELS + 1) as f32;

    (0..N_MELS)
        .map(|m| {
            let left = mel_low + m as f32 * mel_delta;
            let center = left + mel_delta;
            let right = center + mel_delta;

            (0..num_bins)
                .map(|bin| {
                    let mel = hz_to_mel(fft_bin_width * bin as f32);
                    if mel > left && mel < right {
                        if mel <= center {
                            (mel - left) / (center - left)
                        } else {
                            (right - mel) / (right - center)
                        }
                    } else {
                        0.0
                    }
                })
                .collect()
        })
        .collect()
}

/// Kaldi 的 hamming 窗（`periodic=false`）。
fn hamming_window() -> Vec<f32> {
    let a = 2.0 * std::f32::consts::PI / (FRAME_LENGTH - 1) as f32;
    (0..FRAME_LENGTH)
        .map(|i| 0.54 - 0.46 * (a * i as f32).cos())
        .collect()
}

/// Kaldi 相容的 log-mel filterbank 特徵擷取器。
pub struct FbankExtractor {
    window: Vec<f32>,
    filters: Vec<Vec<f32>>,
    fft: std::sync::Arc<dyn rustfft::Fft<f32>>,
}

impl std::fmt::Debug for FbankExtractor {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("FbankExtractor")
            .field("n_mels", &N_MELS)
            .field("fft_size", &FFT_SIZE)
            .finish()
    }
}

impl Default for FbankExtractor {
    fn default() -> Self {
        Self::new()
    }
}

impl FbankExtractor {
    pub fn new() -> Self {
        Self {
            window: hamming_window(),
            filters: mel_filterbank(),
            fft: FftPlanner::new().plan_fft_forward(FFT_SIZE),
        }
    }

    /// 幀數。Kaldi 的 `snip_edges=true`：不足一幀的尾端直接丟棄。
    pub fn num_frames(samples: usize) -> usize {
        if samples < FRAME_LENGTH {
            0
        } else {
            (samples - FRAME_LENGTH) / FRAME_SHIFT + 1
        }
    }

    /// 擷取 80 維 log-mel 特徵，回傳 `[frames][N_MELS]`。
    ///
    /// 輸入為 `[-1, 1]` 範圍的 f32 PCM；內部會依 Kaldi 慣例放大到 int16 尺度
    /// （FunASR 的 `upsacle_samples`）。少了這一步，log 之後會整體偏移約 10.4。
    pub fn compute(&self, pcm: &[f32]) -> Vec<Vec<f32>> {
        let frames = Self::num_frames(pcm.len());
        let mut out = Vec::with_capacity(frames);
        let mut buf = vec![0.0f32; FRAME_LENGTH];
        let mut spectrum = vec![Complex32::new(0.0, 0.0); FFT_SIZE];

        for f in 0..frames {
            let start = f * FRAME_SHIFT;
            // Kaldi 慣例：以 int16 尺度計算
            for (i, b) in buf.iter_mut().enumerate() {
                *b = pcm[start + i] * 32_768.0;
            }

            // 1) 去除直流偏移
            let mean = buf.iter().sum::<f32>() / FRAME_LENGTH as f32;
            for b in buf.iter_mut() {
                *b -= mean;
            }

            // 2) 預強調。第一個樣本用自己當前一個樣本（Kaldi 的作法）。
            let first = buf[0];
            for i in (1..FRAME_LENGTH).rev() {
                buf[i] -= PREEMPHASIS * buf[i - 1];
            }
            buf[0] = first - PREEMPHASIS * first;

            // 3) 加窗
            for (b, w) in buf.iter_mut().zip(&self.window) {
                *b *= w;
            }

            // 4) FFT → 功率譜
            spectrum
                .iter_mut()
                .for_each(|c| *c = Complex32::new(0.0, 0.0));
            for (i, &v) in buf.iter().enumerate() {
                spectrum[i] = Complex32::new(v, 0.0);
            }
            self.fft.process(&mut spectrum);

            let power: Vec<f32> = spectrum[..FFT_SIZE / 2 + 1]
                .iter()
                .map(|c| c.re * c.re + c.im * c.im)
                .collect();

            // 5) 梅爾濾波 + log
            out.push(
                self.filters
                    .iter()
                    .map(|filt| {
                        let e: f32 = filt.iter().zip(&power).map(|(w, p)| w * p).sum();
                        e.max(EPSILON).ln()
                    })
                    .collect(),
            );
        }
        out
    }
}

/// LFR：把連續 `LFR_M` 幀堆疊成一幀，步長 `LFR_N`。
///
/// 目的是降低送進 encoder 的幀率（100 fps → 約 16.7 fps），
/// 大幅減少注意力成本。
///
/// 開頭會重複第一幀 `(LFR_M - 1) / 2` 次作為左側補齊；
/// 結尾不足時重複最後一幀。
pub fn apply_lfr(frames: &[Vec<f32>]) -> Vec<Vec<f32>> {
    if frames.is_empty() {
        return Vec::new();
    }
    let pad = (LFR_M - 1) / 2;
    let mut padded: Vec<&Vec<f32>> = Vec::with_capacity(frames.len() + pad);
    for _ in 0..pad {
        padded.push(&frames[0]);
    }
    padded.extend(frames.iter());

    let total = padded.len();
    // 輸出幀數以**補齊前**的長度計算（FunASR 的作法）。
    // 用補齊後的長度會多出一幀，而 encoder 的 alphas 對齊也會跟著錯位。
    let count = frames.len().div_ceil(LFR_N);
    let mut out = Vec::with_capacity(count);

    for i in 0..count {
        let mut row = Vec::with_capacity(FEATURE_DIM);
        for j in 0..LFR_M {
            let idx = (i * LFR_N + j).min(total - 1);
            row.extend_from_slice(padded[idx]);
        }
        out.push(row);
    }
    out
}

/// CMVN（倒譜均值變異數正規化）參數，來自匯出的 `am.mvn`。
#[derive(Debug, Clone)]
pub struct Cmvn {
    /// 長度為 `FEATURE_DIM`
    pub neg_mean: Vec<f32>,
    /// 長度為 `FEATURE_DIM`
    pub inv_stddev: Vec<f32>,
}

impl Cmvn {
    /// 解析 Kaldi 格式的 `am.mvn`。
    ///
    /// 格式是兩個 `AddShift` / `Rescale` 區塊，各帶一個 `<LearnRateCoef>` 向量。
    pub fn parse(text: &str) -> Option<Self> {
        let mut vectors = Vec::new();
        for line in text.lines() {
            if let (Some(l), Some(r)) = (line.find('['), line.rfind(']')) {
                let v: Vec<f32> = line[l + 1..r]
                    .split_whitespace()
                    .filter_map(|t| t.parse().ok())
                    .collect();
                if v.len() == FEATURE_DIM {
                    vectors.push(v);
                }
            }
        }
        match vectors.len() {
            2 => Some(Self {
                neg_mean: vectors[0].clone(),
                inv_stddev: vectors[1].clone(),
            }),
            _ => None,
        }
    }

    /// 就地套用。`am.mvn` 存的已經是「負均值」與「倒數標準差」，
    /// 因此是加法與乘法，不是減法與除法。
    pub fn apply(&self, features: &mut [Vec<f32>]) {
        for row in features {
            for (i, v) in row.iter_mut().enumerate() {
                *v = (*v + self.neg_mean[i]) * self.inv_stddev[i];
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[derive(serde::Deserialize)]
    struct Reference {
        wav: Vec<f32>,
        fbank80: Vec<Vec<f32>>,
        lfr: Vec<Vec<f32>>,
    }

    fn reference() -> Reference {
        let path = concat!(env!("CARGO_MANIFEST_DIR"), "/fixtures/fbank_reference.json");
        serde_json::from_str(&std::fs::read_to_string(path).expect("缺少參考特徵")).unwrap()
    }

    #[test]
    fn frame_count_matches_kaldi_snip_edges() {
        // 8000 樣本、400 幀長、160 步長 ⇒ (8000-400)/160 + 1 = 48
        assert_eq!(FbankExtractor::num_frames(8_000), 48);
        assert_eq!(FbankExtractor::num_frames(399), 0, "不足一幀應為 0");
        assert_eq!(FbankExtractor::num_frames(400), 1);
    }

    #[test]
    fn fbank_matches_the_funasr_reference() {
        let r = reference();
        let got = FbankExtractor::new().compute(&r.wav);

        assert_eq!(got.len(), r.fbank80.len(), "幀數不符");
        assert_eq!(got[0].len(), N_MELS);

        let mut max_diff = 0.0f32;
        for (g, e) in got.iter().zip(&r.fbank80) {
            for (a, b) in g.iter().zip(e) {
                max_diff = max_diff.max((a - b).abs());
            }
        }
        assert!(
            max_diff < 0.05,
            "與 FunASR 參考特徵的最大差異 {max_diff:.4} 過大"
        );
    }

    #[test]
    fn lfr_matches_the_funasr_reference() {
        let r = reference();
        let got = apply_lfr(&r.fbank80);

        assert_eq!(got.len(), r.lfr.len(), "LFR 幀數不符");
        assert_eq!(got[0].len(), FEATURE_DIM);

        let mut max_diff = 0.0f32;
        for (g, e) in got.iter().zip(&r.lfr) {
            for (a, b) in g.iter().zip(e) {
                max_diff = max_diff.max((a - b).abs());
            }
        }
        assert!(max_diff < 1e-3, "LFR 最大差異 {max_diff:.5}");
    }

    #[test]
    fn extraction_is_deterministic() {
        // FunASR 預設的 dither=1.0 會讓同一輸入產生不同特徵（實測差 0.27）。
        // 轉錄結果必須可重現，因此這裡不加抖動。
        let r = reference();
        let fe = FbankExtractor::new();
        assert_eq!(fe.compute(&r.wav), fe.compute(&r.wav));
    }

    #[test]
    fn empty_and_short_input_produce_no_frames() {
        let fe = FbankExtractor::new();
        assert!(fe.compute(&[]).is_empty());
        assert!(fe.compute(&vec![0.1; 100]).is_empty());
        assert!(apply_lfr(&[]).is_empty());
    }

    #[test]
    fn mel_scale_roundtrips() {
        for hz in [20.0, 440.0, 1000.0, 8000.0] {
            assert!((mel_to_hz(hz_to_mel(hz)) - hz).abs() < 0.01, "hz={hz}");
        }
    }

    #[test]
    fn filterbank_covers_the_spectrum_without_gaps() {
        let fb = mel_filterbank();
        assert_eq!(fb.len(), N_MELS);
        // 每個濾波器都要有非零權重，否則等於少一個頻帶
        for (i, f) in fb.iter().enumerate() {
            assert!(f.iter().any(|w| *w > 0.0), "第 {i} 個濾波器全為零");
        }
    }

    #[test]
    fn cmvn_parses_and_applies() {
        let mean: Vec<String> = (0..FEATURE_DIM).map(|_| "-1.0".into()).collect();
        let scale: Vec<String> = (0..FEATURE_DIM).map(|_| "2.0".into()).collect();
        let text = format!(
            "<AddShift> 560 560\n<LearnRateCoef> 0 [ {} ]\n<Rescale> 560 560\n<LearnRateCoef> 0 [ {} ]\n",
            mean.join(" "),
            scale.join(" ")
        );

        let cmvn = Cmvn::parse(&text).expect("應能解析");
        let mut feats = vec![vec![3.0f32; FEATURE_DIM]];
        cmvn.apply(&mut feats);
        // (3 + (-1)) * 2 = 4
        assert_eq!(feats[0][0], 4.0);
    }

    #[test]
    fn cmvn_rejects_malformed_input() {
        assert!(Cmvn::parse("").is_none());
        assert!(
            Cmvn::parse("<AddShift> [ 1.0 2.0 ]").is_none(),
            "維度不符應拒絕"
        );
    }
}

/// 串流特徵前端：跨呼叫維持 fbank 與 LFR 的邊界狀態。
///
/// 分塊處理有兩個接縫會出錯，兩個都必須用狀態接起來：
///
/// 1. **fbank 的幀邊界**：一幀 400 樣本、步長 160。塊尾不足一幀的樣本
///    若直接丟棄，每個塊邊界都會損失最多 2.4 個幀的音訊。
/// 2. **LFR 的堆疊邊界**：LFR 要看 7 個連續 fbank 幀。塊首若沒有前一塊的
///    尾巴，每個邊界會少堆疊出一幀。
#[derive(Debug)]
pub struct StreamingFrontend {
    extractor: FbankExtractor,
    /// 尚未構成完整一幀的 PCM 尾巴。
    pcm_tail: Vec<f32>,
    /// 供下一塊 LFR 堆疊用的 fbank 幀尾巴。
    frame_tail: Vec<Vec<f32>>,
    /// 是否為第一塊（只有第一塊要做左側補齊）。
    started: bool,
}

impl Default for StreamingFrontend {
    fn default() -> Self {
        Self::new()
    }
}

impl StreamingFrontend {
    pub fn new() -> Self {
        Self {
            extractor: FbankExtractor::new(),
            pcm_tail: Vec::new(),
            frame_tail: Vec::new(),
            started: false,
        }
    }

    pub fn reset(&mut self) {
        self.pcm_tail.clear();
        self.frame_tail.clear();
        self.started = false;
    }

    /// 餵入一塊 PCM，回傳這塊產生的 LFR 特徵。
    pub fn push(&mut self, pcm: &[f32]) -> Vec<Vec<f32>> {
        let mut buf = std::mem::take(&mut self.pcm_tail);
        buf.extend_from_slice(pcm);

        let frames = self.extractor.compute(&buf);
        // 保留未被完整幀消耗的樣本，讓下一塊接得上。
        let consumed = FbankExtractor::num_frames(buf.len()) * FRAME_SHIFT;
        self.pcm_tail = buf[consumed.min(buf.len())..].to_vec();

        if frames.is_empty() {
            return Vec::new();
        }

        // 把上一塊的尾巴接在前面，讓 LFR 能跨塊堆疊。
        let mut all = std::mem::take(&mut self.frame_tail);
        let carried = all.len();
        all.extend(frames);

        // 保留最後 LFR_M-1 幀給下一塊
        let keep = (LFR_M - 1).min(all.len());
        self.frame_tail = all[all.len() - keep..].to_vec();

        let lfr = if self.started {
            // 非第一塊：不做左側補齊，且要跳過由 carried 幀重複產生的部分。
            lfr_without_padding(&all)
        } else {
            self.started = true;
            apply_lfr(&all)
        };

        // carried 幀已經在上一塊輸出過，對應的 LFR 幀要跳掉。
        let skip = carried / LFR_N;
        lfr.into_iter().skip(skip).collect()
    }

    /// 錄音結束：沖出殘餘。
    pub fn finish(&mut self) -> Vec<Vec<f32>> {
        let tail = std::mem::take(&mut self.pcm_tail);
        self.frame_tail.clear();
        if tail.len() < FRAME_LENGTH {
            return Vec::new();
        }
        let frames = self.extractor.compute(&tail);
        apply_lfr(&frames)
    }
}

/// 不做左側補齊的 LFR（串流的非首塊使用）。
fn lfr_without_padding(frames: &[Vec<f32>]) -> Vec<Vec<f32>> {
    if frames.is_empty() {
        return Vec::new();
    }
    let count = frames.len().div_ceil(LFR_N);
    (0..count)
        .map(|i| {
            let mut row = Vec::with_capacity(FEATURE_DIM);
            for j in 0..LFR_M {
                row.extend_from_slice(&frames[(i * LFR_N + j).min(frames.len() - 1)]);
            }
            row
        })
        .collect()
}

#[cfg(test)]
mod streaming_tests {
    use super::*;

    fn noise(n: usize, seed: u64) -> Vec<f32> {
        let mut x = seed;
        (0..n)
            .map(|_| {
                x ^= x << 13;
                x ^= x >> 7;
                x ^= x << 17;
                (x as f32 / u64::MAX as f32 - 0.5) * 0.6
            })
            .collect()
    }

    #[test]
    fn partial_frames_are_carried_across_chunks() {
        // 塊尾不足一幀的樣本若丟棄，每個邊界會損失音訊。
        let mut fe = StreamingFrontend::new();
        let pcm = noise(500, 7);

        fe.push(&pcm[..450]);
        let tail_before = fe.pcm_tail.len();
        assert!(tail_before > 0, "應保留不足一幀的尾巴");

        fe.push(&pcm[450..]);
        assert!(fe.pcm_tail.len() < 500, "尾巴不該無限增長");
    }

    #[test]
    fn chunked_feature_count_approximates_whole() {
        // 分塊與整段的特徵幀數應該接近；差太多代表接縫處掉了東西。
        let pcm = noise(16_000, 11);

        let whole = apply_lfr(&FbankExtractor::new().compute(&pcm)).len();

        let mut fe = StreamingFrontend::new();
        let mut streamed = 0;
        for chunk in pcm.chunks(1_600) {
            streamed += fe.push(chunk).len();
        }
        streamed += fe.finish().len();

        let diff = whole.abs_diff(streamed);
        assert!(
            diff * 5 <= whole,
            "分塊 {streamed} 與整段 {whole} 差異過大（{diff}）"
        );
    }

    #[test]
    fn feature_dimension_is_stable() {
        let mut fe = StreamingFrontend::new();
        for chunk in noise(9_600, 3).chunks(3_200) {
            for row in fe.push(chunk) {
                assert_eq!(row.len(), FEATURE_DIM);
            }
        }
    }

    #[test]
    fn reset_clears_all_boundary_state() {
        let mut fe = StreamingFrontend::new();
        fe.push(&noise(1_000, 5));
        fe.reset();
        assert!(fe.pcm_tail.is_empty());
        assert!(fe.frame_tail.is_empty());
        assert!(!fe.started);
    }

    #[test]
    fn empty_chunks_are_harmless() {
        let mut fe = StreamingFrontend::new();
        assert!(fe.push(&[]).is_empty());
        assert!(fe.finish().is_empty());
    }
}
