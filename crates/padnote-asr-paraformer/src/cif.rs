//! CIF（Continuous Integrate-and-Fire）。
//!
//! Paraformer 是**非自迴歸**模型：它不像 Whisper 那樣一個 token 接一個 token 地
//! 生成，而是先決定「這段音訊有幾個字、每個字對應哪些幀」，再一次把所有字
//! 解碼出來。這正是它比 Whisper 快的原因，也是串流的前提。
//!
//! encoder 除了輸出隱藏狀態，還輸出每一幀的權重 `alphas`。CIF 把這些權重
//! 沿時間累加，每當累積量跨過門檻 1.0 就「發射」一個 token 的聲學嵌入 ——
//! 就像水滴累積到一定量才落下。
//!
//! ```text
//! alphas: 0.3  0.5  0.4  0.2  0.7  0.6
//! 累積:   0.3  0.8  1.2↯ 0.4  1.1↯ 0.7
//!                    發射       發射
//! ```
//!
//! 跨過門檻的那一幀會被**拆開**：一部分補完前一個 token，餘量帶到下一個。
//! 這是 CIF 與單純切段的關鍵差異 —— 邊界幀的資訊不會被丟掉或重複計算。

/// 發射門檻。Paraformer 固定用 1.0。
pub const THRESHOLD: f32 = 1.0;

/// CIF 的結果。
#[derive(Debug, Clone, PartialEq)]
pub struct CifOutput {
    /// 每個 token 的聲學嵌入，形狀 `[tokens][hidden]`。
    pub embeddings: Vec<Vec<f32>>,
    /// 每個 token 對應的最後一幀索引，供時間戳對齊使用。
    pub frame_indices: Vec<usize>,
}

impl CifOutput {
    pub fn len(&self) -> usize {
        self.embeddings.len()
    }

    pub fn is_empty(&self) -> bool {
        self.embeddings.is_empty()
    }
}

/// 對 encoder 的輸出跑 CIF。
///
/// - `hidden`：`[frames][hidden_dim]`，encoder 的輸出
/// - `alphas`：`[frames]`，每幀的權重（encoder 另一個輸出）
///
/// 兩者長度不一致時以較短者為準 —— 寧可少解一個字，也不要讀到界外。
pub fn cif(hidden: &[Vec<f32>], alphas: &[f32]) -> CifOutput {
    let frames = hidden.len().min(alphas.len());
    if frames == 0 {
        return CifOutput {
            embeddings: Vec::new(),
            frame_indices: Vec::new(),
        };
    }
    let dim = hidden[0].len();

    let mut embeddings = Vec::new();
    let mut frame_indices = Vec::new();
    let mut integrate = 0.0f32;
    let mut accumulator = vec![0.0f32; dim];

    for t in 0..frames {
        let alpha = alphas[t];
        // 距離下次發射還差多少
        let completion = THRESHOLD - integrate;
        integrate += alpha;

        if integrate >= THRESHOLD {
            // 這一幀被拆成兩半：`completion` 補完目前的 token，
            // 餘量 `alpha - completion` 成為下一個 token 的起點。
            for (a, h) in accumulator.iter_mut().zip(&hidden[t]) {
                *a += completion * h;
            }
            embeddings.push(std::mem::replace(&mut accumulator, vec![0.0; dim]));
            frame_indices.push(t);

            integrate -= THRESHOLD;
            let remainder = alpha - completion;
            for (a, h) in accumulator.iter_mut().zip(&hidden[t]) {
                *a = remainder * h;
            }
        } else {
            for (a, h) in accumulator.iter_mut().zip(&hidden[t]) {
                *a += alpha * h;
            }
        }
    }

    CifOutput {
        embeddings,
        frame_indices,
    }
}

/// 跨呼叫保留的 CIF 狀態（串流用）。
///
/// 沒有這個狀態，每個音訊塊都從 `integrate = 0` 重新開始：
/// 跨塊邊界的字會被切斷，累積量不足門檻的部分直接消失。
/// 實測會產生漏字與重複。
#[derive(Debug, Clone, Default)]
pub struct CifState {
    integrate: f32,
    accumulator: Vec<f32>,
}

impl CifState {
    pub fn new() -> Self {
        Self::default()
    }

    /// 清除狀態。新的一段語音開始時呼叫。
    pub fn reset(&mut self) {
        self.integrate = 0.0;
        self.accumulator.clear();
    }

    /// 目前累積但尚未發射的量。用於判斷是否還有半個字懸在邊界上。
    pub fn pending(&self) -> f32 {
        self.integrate
    }

    /// 處理一塊，保留跨塊狀態。
    pub fn step(&mut self, hidden: &[Vec<f32>], alphas: &[f32]) -> CifOutput {
        let frames = hidden.len().min(alphas.len());
        if frames == 0 {
            return CifOutput {
                embeddings: Vec::new(),
                frame_indices: Vec::new(),
            };
        }
        let dim = hidden[0].len();
        if self.accumulator.len() != dim {
            self.accumulator = vec![0.0; dim];
        }

        let mut embeddings = Vec::new();
        let mut frame_indices = Vec::new();

        for t in 0..frames {
            let alpha = alphas[t];
            let completion = THRESHOLD - self.integrate;
            self.integrate += alpha;

            if self.integrate >= THRESHOLD {
                for (a, h) in self.accumulator.iter_mut().zip(&hidden[t]) {
                    *a += completion * h;
                }
                embeddings.push(std::mem::replace(&mut self.accumulator, vec![0.0; dim]));
                frame_indices.push(t);

                self.integrate -= THRESHOLD;
                let remainder = alpha - completion;
                for (a, h) in self.accumulator.iter_mut().zip(&hidden[t]) {
                    *a = remainder * h;
                }
            } else {
                for (a, h) in self.accumulator.iter_mut().zip(&hidden[t]) {
                    *a += alpha * h;
                }
            }
        }

        CifOutput {
            embeddings,
            frame_indices,
        }
    }
}

/// 依 `alphas` 預估 token 數，不實際計算嵌入。
///
/// 用於在解碼前判斷這段音訊值不值得送進 decoder ——
/// 預估為 0 表示這段沒有語音內容，可以直接跳過，省下一次推論。
pub fn estimate_token_count(alphas: &[f32]) -> usize {
    alphas.iter().sum::<f32>().floor().max(0.0) as usize
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 每幀是一個 one-hot 向量，方便追蹤哪些幀貢獻到哪個 token。
    fn frames(n: usize) -> Vec<Vec<f32>> {
        (0..n)
            .map(|i| {
                let mut v = vec![0.0; n];
                v[i] = 1.0;
                v
            })
            .collect()
    }

    #[test]
    fn fires_when_the_accumulator_crosses_the_threshold() {
        // 0.3 0.5 0.4 → 累積 0.3, 0.8, 1.2 ⇒ 在第 3 幀發射一次
        let out = cif(&frames(3), &[0.3, 0.5, 0.4]);
        assert_eq!(out.len(), 1);
        assert_eq!(out.frame_indices, vec![2]);
    }

    #[test]
    fn does_not_fire_below_the_threshold() {
        let out = cif(&frames(3), &[0.2, 0.3, 0.4]); // 合計 0.9
        assert!(out.is_empty(), "累積量未達門檻不該發射");
    }

    #[test]
    fn boundary_frame_is_split_between_two_tokens() {
        // 這是 CIF 與單純切段的關鍵差異。
        // alphas = [0.6, 0.6, 0.8]，總和 2.0 ⇒ 發射兩次。
        // 第 1 幀累積到 1.2 → 發射，該幀貢獻 0.4 給第一個 token、餘 0.2 帶到下一個。
        let out = cif(&frames(3), &[0.6, 0.6, 0.8]);
        assert_eq!(out.len(), 2);

        let e = &out.embeddings[0];
        assert!((e[0] - 0.6).abs() < 1e-6, "第 0 幀應全額貢獻");
        assert!(
            (e[1] - 0.4).abs() < 1e-6,
            "第 1 幀只貢獻補完的部分，實得 {}",
            e[1]
        );
        assert!(e[2].abs() < 1e-6, "第 2 幀不該貢獻給第一個 token");

        // 第二個 token 拿到第 1 幀的餘量與第 2 幀
        let e2 = &out.embeddings[1];
        assert!(
            (e2[1] - 0.2).abs() < 1e-6,
            "餘量應帶到下一個 token，實得 {}",
            e2[1]
        );
        assert!((e2[2] - 0.8).abs() < 1e-6);
    }

    #[test]
    fn remainder_carries_into_the_next_token() {
        // alphas = [1.5, 0.6]，總和 2.1 ⇒ 發射兩次。
        // 第 0 幀發射後餘量 0.5 帶到第二個 token。
        let out = cif(&frames(2), &[1.5, 0.6]);
        assert_eq!(out.len(), 2);
        assert!(
            (out.embeddings[0][0] - 1.0).abs() < 1e-6,
            "發射時只取到門檻值，多出的部分留給下一個"
        );
        assert!(
            (out.embeddings[1][0] - 0.5).abs() < 1e-6,
            "餘量 0.5 應出現在第二個 token，實得 {}",
            out.embeddings[1][0]
        );
    }

    #[test]
    fn multiple_tokens_fire_in_order() {
        let out = cif(&frames(6), &[0.3, 0.5, 0.4, 0.2, 0.7, 0.6]);
        assert_eq!(out.len(), 2);
        assert_eq!(out.frame_indices, vec![2, 4]);
        assert!(
            out.frame_indices.windows(2).all(|w| w[0] < w[1]),
            "幀索引必須遞增"
        );
    }

    #[test]
    fn a_single_large_alpha_fires_once_not_repeatedly() {
        // 單一極大的 alpha 只該發射一次；重複發射會產生大量重複字。
        let out = cif(&frames(1), &[5.0]);
        assert_eq!(out.len(), 1);
    }

    #[test]
    fn empty_input_yields_nothing() {
        assert!(cif(&[], &[]).is_empty());
        assert!(cif(&frames(3), &[]).is_empty());
    }

    #[test]
    fn mismatched_lengths_use_the_shorter() {
        // 讀到界外會 panic；寧可少解一個字。
        let out = cif(&frames(5), &[0.6, 0.6]);
        assert_eq!(out.len(), 1);
        let out = cif(&frames(2), &[0.6, 0.6, 0.6, 0.6]);
        assert!(out.len() <= 1);
    }

    #[test]
    fn token_count_estimate_matches_actual_firings() {
        for alphas in [
            vec![0.3, 0.5, 0.4, 0.2, 0.7, 0.6],
            vec![1.2, 1.3, 0.9],
            vec![0.1; 25],
        ] {
            let actual = cif(&frames(alphas.len()), &alphas).len();
            let estimate = estimate_token_count(&alphas);
            assert_eq!(
                estimate, actual,
                "預估 {estimate} 與實際 {actual} 不符：{alphas:?}"
            );
        }
    }

    #[test]
    fn silence_estimates_zero_tokens() {
        // 預估為 0 就可以跳過 decoder，省下一次推論。
        assert_eq!(estimate_token_count(&[0.01; 50]), 0);
        assert_eq!(estimate_token_count(&[]), 0);
    }

    #[test]
    fn streaming_state_matches_processing_everything_at_once() {
        // 串流的正確性判準：分塊處理的結果必須等同整段處理。
        let alphas: Vec<f32> = vec![0.3, 0.5, 0.4, 0.2, 0.7, 0.6, 0.3, 0.5];
        let h = frames(alphas.len());

        let whole = cif(&h, &alphas);

        let mut state = CifState::new();
        let mut streamed = Vec::new();
        for (hc, ac) in h.chunks(3).zip(alphas.chunks(3)) {
            streamed.extend(state.step(hc, ac).embeddings);
        }

        assert_eq!(streamed.len(), whole.len(), "分塊與整段的 token 數必須相同");
        for (a, b) in streamed.iter().zip(&whole.embeddings) {
            for (x, y) in a.iter().zip(b) {
                assert!((x - y).abs() < 1e-5, "嵌入內容不一致");
            }
        }
    }

    #[test]
    fn state_carries_partial_accumulation_across_chunks() {
        // 沒有跨塊狀態的話，邊界上累積不足門檻的部分會直接消失。
        let mut state = CifState::new();
        let out = state.step(&frames(2), &[0.4, 0.4]);
        assert!(out.is_empty(), "尚未達門檻");
        assert!((state.pending() - 0.8).abs() < 1e-6, "累積量必須保留");

        let out = state.step(&frames(1), &[0.5]);
        assert_eq!(out.len(), 1, "下一塊應接續發射");
    }

    #[test]
    fn reset_clears_streaming_state() {
        let mut state = CifState::new();
        state.step(&frames(2), &[0.4, 0.4]);
        state.reset();
        assert_eq!(state.pending(), 0.0);
    }

    #[test]
    fn negative_alphas_do_not_underflow() {
        // 量化後的 encoder 可能吐出微小的負值。
        assert_eq!(estimate_token_count(&[-0.5, -0.2]), 0);
        assert!(cif(&frames(2), &[-0.5, -0.2]).is_empty());
    }
}
