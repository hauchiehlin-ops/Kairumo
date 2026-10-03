//! 神經網路降噪（RNNoise），**只作為「重新轉錄」的選用分支**。
//!
//! # 為什麼不預設開
//!
//! 降噪後的訊號對人耳比較好聽，但會留下人工痕跡；Whisper／Paraformer 是在含噪音的
//! 資料上訓練的，實務上常見「聽起來變乾淨、錯字率反而上升」。所以：
//!
//! - 錄音檔永遠保存原始訊號，這裡只產生**給辨識用的副本**；
//! - 只有使用者在「重新轉錄」時主動選了「降噪後再辨識」才會用到；
//! - 要升為預設，**必須**先用 `padnote-bench` 的 `asr-ab` 在真實教室／會議室做 A/B，
//!   每個場景的 CER 都沒有變差、而且至少一個場景穩定下降（見
//!   `docs/plans/recording-quality.md` 第四節）。
//!
//! # 取樣率
//!
//! RNNoise 只吃 48 kHz（每框 480 取樣、16-bit 刻度）。App 全線是 16 kHz，
//! 所以前後各做一次 ×3 的升／降取樣（視窗化 sinc 低通），並把濾波器與
//! RNNoise 本身一框的延遲扣回來，輸出與輸入逐點對齊、長度相同。
//!
//! # 為什麼是 RNNoise 而不是 DeepFilterNet
//!
//! 兩者都在評估清單上。RNNoise（nnnoiseless）是純 Rust、無模型檔、約 100 KB 權重
//! 編進二進位，四個平台都能直接編；DeepFilterNet 品質較好但需要 tract 推論與
//! 數 MB 的模型，先用便宜的那個把 A/B 流程跑通，資料說值得再換。

use nnnoiseless::DenoiseState;

const FRAME_48K: usize = DenoiseState::FRAME_SIZE; // 480
const RATIO: usize = 3;
/// 低通 FIR 的長度（奇數，線性相位，群延遲 = (N-1)/2）。
const TAPS: usize = 63;
const FIR_DELAY: usize = (TAPS - 1) / 2;
/// RNNoise 的重疊相加帶來一框的延遲。
const RNNOISE_DELAY: usize = FRAME_48K;

/// 16 kHz 單聲道 f32（-1..1）→ 降噪後的同長度副本。
#[allow(clippy::chunks_exact_to_as_chunks)]
pub fn rnnoise_16k(pcm: &[f32]) -> Vec<f32> {
    if pcm.is_empty() {
        return Vec::new();
    }
    let fir = lowpass_fir();

    // 1. 升取樣：插零 ×3 → 低通（增益 ×3 補回插零損失），換成 16-bit 刻度。
    //    尾端多補一些，讓所有延遲扣掉之後長度仍然足夠。
    let total_delay = 2 * FIR_DELAY + RNNOISE_DELAY;
    let n48 = pcm.len() * RATIO + total_delay + FRAME_48K;
    let mut stuffed = vec![0.0_f32; n48];
    for (i, &s) in pcm.iter().enumerate() {
        stuffed[i * RATIO] = s * RATIO as f32 * 32_767.0;
    }
    let up = convolve(&stuffed, &fir);

    // 2. RNNoise，一框 480。
    let mut state = DenoiseState::new();
    let mut den = vec![0.0_f32; up.len()];
    let mut frame_out = [0.0_f32; FRAME_48K];
    for (inp, out) in up
        .chunks_exact(FRAME_48K)
        .zip(den.chunks_exact_mut(FRAME_48K))
    {
        state.process_frame(&mut frame_out, inp);
        out.copy_from_slice(&frame_out);
    }

    // 3. 降取樣前的抗混疊低通，扣掉延遲後每 3 點取 1 點。
    let filtered = convolve(&den, &fir);
    (0..pcm.len())
        .map(|i| {
            let v = filtered
                .get(i * RATIO + total_delay)
                .copied()
                .unwrap_or(0.0);
            (v / 32_767.0).clamp(-1.0, 1.0)
        })
        .collect()
}

/// 截止 7.2 kHz（48 kHz 取樣）的 Blackman 視窗 sinc 低通，直流增益 1。
fn lowpass_fir() -> [f32; TAPS] {
    let fc = 7_200.0_f64 / 48_000.0;
    let mut h = [0.0_f64; TAPS];
    let m = (TAPS - 1) as f64;
    for (n, v) in h.iter_mut().enumerate() {
        let k = n as f64 - m / 2.0;
        let sinc = if k == 0.0 {
            2.0 * fc
        } else {
            (2.0 * std::f64::consts::PI * fc * k).sin() / (std::f64::consts::PI * k)
        };
        let w = 0.42 - 0.5 * (2.0 * std::f64::consts::PI * n as f64 / m).cos()
            + 0.08 * (4.0 * std::f64::consts::PI * n as f64 / m).cos();
        *v = sinc * w;
    }
    let sum: f64 = h.iter().sum();
    let mut out = [0.0_f32; TAPS];
    for (o, v) in out.iter_mut().zip(h) {
        *o = (v / sum) as f32;
    }
    out
}

/// 因果卷積，輸出長度與輸入相同（延遲 = FIR_DELAY）。
fn convolve(x: &[f32], h: &[f32; TAPS]) -> Vec<f32> {
    let mut y = vec![0.0_f32; x.len()];
    for (n, out) in y.iter_mut().enumerate() {
        let mut acc = 0.0_f32;
        let kmax = TAPS.min(n + 1);
        for (k, &hk) in h.iter().enumerate().take(kmax) {
            acc += hk * x[n - k];
        }
        *out = acc;
    }
    y
}

#[cfg(test)]
mod tests {
    use super::*;

    struct Lcg(u32);
    impl Lcg {
        fn next(&mut self) -> f32 {
            self.0 = self.0.wrapping_mul(1664525).wrapping_add(1013904223);
            (self.0 >> 8) as f32 / (1u32 << 24) as f32 * 2.0 - 1.0
        }
    }

    fn rms(v: &[f32]) -> f32 {
        (v.iter().map(|s| s * s).sum::<f32>() / v.len().max(1) as f32).sqrt()
    }

    #[test]
    fn output_has_the_same_length() {
        for n in [1, 100, 16_000, 16_001] {
            assert_eq!(rnnoise_16k(&vec![0.0; n]).len(), n);
        }
        assert!(rnnoise_16k(&[]).is_empty());
    }

    #[test]
    fn steady_noise_is_attenuated() {
        let mut rng = Lcg(1);
        let noise: Vec<f32> = (0..16_000 * 4).map(|_| rng.next() * 0.05).collect();
        let out = rnnoise_16k(&noise);
        // 看後半段（RNNoise 前幾百毫秒在適應）。
        let before = rms(&noise[32_000..]);
        let after = rms(&out[32_000..]);
        assert!(
            after < before * 0.5,
            "穩定噪音沒被壓下來：{before} → {after}"
        );
    }

    #[test]
    fn output_is_time_aligned_with_input() {
        // 一段 1 秒的「類語音」（有基頻與諧波）夾在靜音中間：輸出的起點要對得上。
        let mut pcm = vec![0.0_f32; 16_000 * 3];
        for (i, s) in pcm[16_000..32_000].iter_mut().enumerate() {
            let t = i as f32 / 16_000.0;
            let f0 = 150.0;
            *s = (1..8)
                .map(|h| (t * f0 * h as f32 * 2.0 * std::f32::consts::PI).sin() / h as f32)
                .sum::<f32>()
                * 0.2;
        }
        let out = rnnoise_16k(&pcm);
        let onset = |v: &[f32]| v.iter().position(|s| s.abs() > 0.02).unwrap_or(usize::MAX);
        let (a, b) = (onset(&pcm), onset(&out));
        assert!(
            (a as i64 - b as i64).abs() <= 160,
            "輸出與輸入沒有對齊：輸入起點 {a}，輸出起點 {b}"
        );
        // 而且確實保留了有聲段落（沒有整段被當成噪音吃掉）。
        assert!(rms(&out[20_000..30_000]) > rms(&pcm[20_000..30_000]) * 0.3);
    }
}
